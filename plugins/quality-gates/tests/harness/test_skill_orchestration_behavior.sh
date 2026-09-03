#!/usr/bin/env bash
# test_skill_orchestration_behavior.sh — protocol-shape test for SKILL.md.
#
# Asserts the prompt-defined orchestration protocol exists in SKILL.md with
# expected ordering, proximity, and section membership. Does NOT execute
# SKILL.md at runtime; this is a STATIC protocol-shape verifier that replaces
# V7's tautological substring grep (V7 looked for `PASS` token that never
# appeared, so its negative-assertion path was unreachable).
#
# Coverage (spec §5.6.9):
#   - Review gate → Runtime gate dispatch line order monotonic
#   - All 4 reviewer agents present in Review/Runtime gate fan-out (consistency w/ C1)
#   - Review gate iter cap within proximity of AskUserQuestion section
#   - DEVBREW_QUALITY_GATES_RUNTIME_MAX_RESOLUTIONS within 100 lines of Runtime gate dispatch
#   - Retry-path AskUserQuestion block lies between Review gate and Runtime gate

set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILL_MD_REAL="$(cd -- "$SCRIPT_DIR/../.." && pwd)/skills/quality-pipeline/SKILL.md"

test -f "$SKILL_MD_REAL" || { echo "FAIL: SKILL.md not found at $SKILL_MD_REAL"; exit 1; }

# Task 31(무게 감축): Runtime gate 절차 전문이 references/runtime-gate.md 로 분리됐다.
# 이 파일의 모든 검사는 원래 단일 SKILL.md 를 줄 번호로 분석하도록 설계됐으므로,
# 분할 전과 동일한 논리적 문서를 재구성해 그 위에서 돈다 — 그래야 R-init..R9 앵커가
# 여전히 잡힌다. 재구성 실패(포인터 소실 등)는 조용히 원본으로 폴백하지 않고 FAIL 한다.
. "$SCRIPT_DIR/../lib/reconstruct-skill.sh"
if ! SKILL_MD="$(reconstruct_skill_md "$SKILL_MD_REAL")"; then
  echo "FAIL: SKILL.md ↔ references/runtime-gate.md 재구성 실패 (아래 모든 검사가 공허해질 것을 막기 위해 중단)"
  exit 1
fi
trap 'rm -f "$SKILL_MD"' EXIT

fail=0

first_line() {
  # First line number where $1 (extended regex) matches, or "0" if absent.
  local pat="$1"
  awk -v p="$pat" '$0 ~ p { print NR; exit }' "$SKILL_MD" \
    | { read -r n || true; echo "${n:-0}"; }
}

first_line_after() {
  # First line number > $2 where $1 matches, or "0" if absent.
  local pat="$1" after="$2"
  awk -v p="$pat" -v a="$after" '
    NR > a && $0 ~ p { print NR; exit }
  ' "$SKILL_MD" | { read -r n || true; echo "${n:-0}"; }
}

assert_line() {
  local label="$1" line="$2"
  if [[ "$line" -gt 0 ]]; then
    echo "PASS: $label (line $line)"
  else
    echo "FAIL: $label (pattern not found)"
    fail=$((fail + 1))
  fi
}

assert_order() {
  local label="$1" earlier="$2" later="$3"
  if [[ "$earlier" -gt 0 && "$later" -gt 0 && "$earlier" -lt "$later" ]]; then
    echo "PASS: $label (line $earlier < line $later)"
  else
    echo "FAIL: $label (earlier=$earlier later=$later)"
    fail=$((fail + 1))
  fi
}

assert_proximity() {
  local label="$1" a="$2" b="$3" within="$4"
  if [[ "$a" -gt 0 && "$b" -gt 0 ]]; then
    local d
    if [[ "$a" -gt "$b" ]]; then d=$((a - b)); else d=$((b - a)); fi
    if [[ "$d" -le "$within" ]]; then
      echo "PASS: $label (lines $a, $b within $within)"
    else
      echo "FAIL: $label (lines $a, $b distance $d > $within)"
      fail=$((fail + 1))
    fi
  else
    echo "FAIL: $label (a=$a b=$b — missing markers)"
    fail=$((fail + 1))
  fi
}

# Gate dispatch lines.
review_line=$(first_line 'subagent_type.*quality-gates:adversarial')
runtime_line=$(first_line 'subagent_type.*runtime-verifier')

assert_line "Review gate adversarial dispatch"   "$review_line"
assert_line "Runtime gate runtime-verifier dispatch" "$runtime_line"

# Ordering: Review gate < Runtime gate.
assert_order "Review precedes Runtime" "$review_line" "$runtime_line"

# Four reviewer agents in Review / Runtime gate fan-out (consistency with C1 / AC1).
for agent in adversarial test-scope-validator security-reviewer runtime-verifier; do
  if grep -qE "subagent_type[^\"]*\"quality-gates:$agent" "$SKILL_MD"; then
    echo "PASS: $agent dispatch present"
  else
    echo "FAIL: $agent dispatch missing"
    fail=$((fail + 1))
  fi
done

# Review gate iter cap proximity to Review gate section / AskUserQuestion.
# Use FIRST AskUserQuestion at or after the adversarial dispatch (the
# description's top-of-file AskUserQuestion mention is irrelevant; we want the
# Review-gate decision-tool call).
askuser_review_line=$(first_line_after 'AskUserQuestion' "$review_line")
itercap_line=$(first_line 'max_review_iterations')
# Locality bound widened 100→120 in v2.6.0 review-iter3: the Step-1 $effective_diff_scope
# single-source paragraph + scout/dispatch annotations legitimately grew the Review-gate
# region between the iter cap and the decision tool. Still a tight locality sanity check.
# Locality bound 120→160 in v2.13.0 scope-driven-composition: step 3의 Tier B/C
# dispatch 프로즈(codex availability-floor + Tier C 선택 + transparency + graceful)가
# adversarial dispatch와 iter-boundary 결정 사이 영역을 정당하게 키움. 여전히 tight sanity.
assert_proximity "iter cap near Review gate AskUserQuestion" "$askuser_review_line" "$itercap_line" 160

# DEVBREW_QUALITY_GATES_RUNTIME_MAX_RESOLUTIONS near Runtime gate dispatch — use first mention
# AT OR AFTER the Runtime gate dispatch line (the top-of-file "up to ..." preview
# mention is irrelevant; we want the Runtime NEEDS_RESOLUTION section reference).
runtime_max_line=$(first_line_after 'DEVBREW_QUALITY_GATES_RUNTIME_MAX_RESOLUTIONS' "$runtime_line")
assert_proximity "RUNTIME_MAX_RESOLUTIONS near Runtime dispatch" "$runtime_line" "$runtime_max_line" 100

# Retry-path AskUserQuestion (I6) between Review gate dispatch and Runtime gate dispatch.
retry_line=$(first_line 'Retry: error handling|Retry failed')
if [[ "$retry_line" -gt 0 && "$retry_line" -gt "$review_line" && "$retry_line" -lt "$runtime_line" ]]; then
  echo "PASS: Retry block between Review gate ($review_line) and Runtime gate ($runtime_line) at $retry_line"
else
  echo "FAIL: Retry block not between Review gate ($review_line) and Runtime gate ($runtime_line); found at $retry_line"
  fail=$((fail + 1))
fi

# --- v2.2.0 sandbox-executor protocol-shape ---

# create-sandbox must be invoked, and BEFORE the runtime-verifier dispatch.
sandbox_line=$(first_line 'create-sandbox')
assert_line "create-sandbox invoked" "$sandbox_line"
assert_order "create-sandbox precedes runtime-verifier dispatch" "$sandbox_line" "$runtime_line"

# mutation-guard must be invoked AFTER the runtime-verifier dispatch.
#
# 앵커는 **호출 줄**이어야 한다 — 이름 첫 등장이 아니다. 앞 버전은
# `first_line_after 'mutation-guard'` 였는데, 그 이름은 산문에서도 불린다(R5b 가 왜
# 자기 트리에서 도는지를 설명하는 §11 ⑬/S4 문단이 R7 호출보다 **앞선다**). 그러면
# `$guard_line` 이 산문 줄을 가리키고, 아래 3-arg 검사는 실제 호출이 멀쩡한데도 FAIL 을
# 낸다 — 반대 방향(호출에서 인자를 지워도 산문에 `snapshot_digest` 가 있으면 GREEN)이
# 더 나쁘다. 이 파일이 :588 에서 스스로 적어 둔 grep-매치-주석 함정의 같은 사례다.
# 실행 줄만 고르도록 `scripts/` 접두를 같은 줄에서 요구한다.
guard_line=$(first_line_after 'scripts/qg-worktree\.sh" mutation-guard' "$runtime_line")
assert_line "mutation-guard invoked after runtime dispatch" "$guard_line"

# forced_downgrade must be referenced (verdict gating on the guard result).
assert_line "forced_downgrade referenced" "$(first_line 'forced_downgrade')"

# Upfront Execution Plan section present, and before the Review gate dispatch.
upfront_line=$(first_line 'Upfront Execution Plan|Execution Plan')
assert_line "Upfront Execution Plan section present" "$upfront_line"

# requires_decision drives the upfront gate.
assert_line "requires_decision referenced in plan gate" "$(first_line 'requires_decision')"

# Blocked-path routing references the three policies.
assert_line "block policy stop/skip/ask present" "$(first_line 'block_policy|stop / skip / ask|stop/skip/ask')"

# Kill-switch fallback present.
assert_line "runtime sandbox kill switch present" "$(first_line 'DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX')"

# spec_acceptance_criteria threaded to the verifier.
assert_line "spec_acceptance_criteria threaded" "$(first_line 'spec_acceptance_criteria')"

# SKILL 제목의 버전이 **shipped major 와 일치**한다 — 이 플러그인의 모든
# skills/*/SKILL.md 에 대해.
#
# 앞 버전은 quality-pipeline/SKILL.md 제목 하나만 봤다(리터럴 `v2.7.0` 핀의
# 후신). 이 플러그인엔 SKILL.md 가 셋이다 — quality-pipeline(버전 있음) ·
# publishing-pr-understanding(버전 있음) · critiquing-artifacts(버전 없음).
# 한 파일만 보는 락은 나머지 둘에 구조적으로 눈이 멀어, publishing-pr-understanding
# 이 plugin.json bump 뒤에도 제목에 구버전을 그대로 달고 있는 걸 못 잡았다.
#
# 음의 락: 버전을 단 제목은 전부 major 가 shipped 와 같아야 한다. 버전이
# 아예 없는 제목(critiquing-artifacts)은 위반이 아니다 — 무버전 제목은 애초에
# stale 해질 수 없는 모양이라 legal 로 둔다(SKILL.md:136 에서 stale 서술을
# 재버전 대신 삭제로 택한 것과 같은 방향). major 만 재고 minor/patch 는 풀어
# 둔다: major 는 계약이고 minor/patch 는 그렇지 않다.
#
# 양의 락: 음의 락은 제목 전부에서 버전을 지우면 공허하게 통과한다 —
# "틀린 major 를 단 제목이 없다"가 "버전을 단 제목이 없다"로도 참이 되기
# 때문이다. 그래서 적어도 하나의 제목은 여전히 shipped major 를 달아야 한다.
PLUGIN_JSON="$(cd -- "$SCRIPT_DIR/../.." && pwd)/.claude-plugin/plugin.json"
if [ ! -f "$PLUGIN_JSON" ]; then
  echo "FAIL: plugin.json 부재 ($PLUGIN_JSON) — 아래 major 대조가 공허하다"
  fail=1
else
  SHIPPED_MAJOR="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([0-9][0-9]*\)\..*/\1/p' "$PLUGIN_JSON" | head -1)"
  if [ -z "$SHIPPED_MAJOR" ]; then
    echo "FAIL: plugin.json 에서 major 를 못 읽음 — 아래 major 대조가 공허하다"
    fail=1
  else
    SKILLS_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)/skills"
    wrong_major=""
    matching_count=0
    while IFS= read -r skill_file; do
      title_line="$(grep -m1 '^# ' "$skill_file" || true)"
      [ -n "$title_line" ] || continue
      ver="$(printf '%s\n' "$title_line" | sed -n 's/.*(v\([0-9][0-9]*\)\.[0-9][0-9]*\.[0-9][0-9]*).*/\1/p')"
      [ -n "$ver" ] || continue
      if [ "$ver" = "$SHIPPED_MAJOR" ]; then
        matching_count=$((matching_count + 1))
      else
        wrong_major="$wrong_major ${skill_file#"$SKILLS_ROOT"/}(v${ver})"
      fi
    done < <(find "$SKILLS_ROOT" -maxdepth 2 -name 'SKILL.md' | sort)

    if [ -n "$wrong_major" ]; then
      echo "FAIL: SKILL 제목 major 불일치 (shipped v${SHIPPED_MAJOR}) —$wrong_major"
      fail=$((fail + 1))
    else
      echo "PASS: SKILL 제목 중 버전을 단 것은 전부 major == plugin.json major (v${SHIPPED_MAJOR})"
    fi

    if [ "$matching_count" -ge 1 ]; then
      echo "PASS: SKILL 제목 중 ${matching_count}개가 shipped major(v${SHIPPED_MAJOR}) 명시 (양성 대조 — 전부 무버전이면 공허 통과 방지)"
    else
      echo "FAIL: 버전을 단 SKILL 제목이 0개 — 위 음의 락이 공허 통과 중"
      fail=$((fail + 1))
    fi
  fi
fi

# --- v2.2.0 mutation-guard hardening protocol-shape ---

# C-C: the mutation-guard step (R7 since the impact-driven rewrite; R4 before it)
# must route an errored/garbled guard as ≤FAIL, never PASS.
#
# Anchor history: this block used to anchor on `exit 4`, asserted to be "unique to
# the R4 routing table". That premise died when the impact-driven R4 (baseline
# side) introduced a baseline-cache corruption advisory that also says `exit 4`,
# ~184 lines EARLIER than the guard table. The anchor slid backwards and the
# AT/AFTER assertions became satisfiable by R5a¹'s unrelated "surface stderr
# verbatim" sentence — measured: deleting `**stderr verbatim**` from the guard row
# still printed PASS. Two fixes, both required:
#   (a) anchor on the routing table's own heading (`R7 exit-code routing`), and
#       assert the heading EXISTS — if it is renamed, $r7_tbl becomes 0 and every
#       `first_line_after … 0` degenerates into a whole-file search, i.e. the same
#       vacuous-pass failure in a new costume;
#   (b) use BODY-UNIQUE needles for the two row phrases. `**stderr verbatim**`
#       (bold) and `indeterminate ≠ clean` exist only in the table row — the
#       heading's own "an indeterminate guard is never a PASS" would otherwise
#       satisfy a bare `indeterminate` needle (header-satisfiable = no teeth).
#       The bold needle is written `[*][*]…` and NOT `\*\*…`: macOS awk strips the
#       backslash during `-v` assignment, leaving a leading `**` that dies with
#       "illegal primary in regular expression" and yields a silent NO-MATCH.
# `exit 4` / `guard_error` remain existence checks WITHIN R7 (the digest-mismatch
# paragraph below the table repeats both), which is what the base file had.
r7_tbl=$(first_line 'R7 exit-code routing')
assert_line "R7 routing-table anchor present"         "$r7_tbl"
assert_line "R7 routes guard exit 4 as FAIL"          "$(first_line_after 'exit 4' "$r7_tbl")"
assert_line "R7 surfaces guard_error"                 "$(first_line_after 'guard_error' "$r7_tbl")"
assert_line "R7 surfaces guard stderr verbatim"       "$(first_line_after '[*][*]stderr verbatim[*][*]' "$r7_tbl")"
assert_line "R7 never-PASS for indeterminate guard"   "$(first_line_after 'indeterminate ≠ clean' "$r7_tbl")"

# I-A/I-B: fallback caps at SKIP_WITH_EVIDENCE (never PASS) + single runtime_project_dir.
assert_line "runtime_project_dir variable used"      "$(first_line 'runtime_project_dir')"
assert_line "fallback caps at SKIP_WITH_EVIDENCE"    "$(first_line 'SKIP_WITH_EVIDENCE.*never PASS|never PASS.*SKIP_WITH_EVIDENCE')"
# I-B: the R3 dispatch project_dir must NOT hardcode sandbox_dir (use runtime_project_dir).
if grep -qE 'project_dir:[[:space:]]*\\?"\$runtime_project_dir' "$SKILL_MD"; then
  echo "PASS: R3 dispatch uses runtime_project_dir"
else
  echo "FAIL: R3 dispatch does not use runtime_project_dir"
  fail=$((fail + 1))
fi

# I-C: evidence_dir threaded to R3 as a main-repo absolute path that survives R5 discard.
assert_line "evidence_dir threaded to verifier"  "$(first_line 'evidence_dir')"
if grep -qE 'evidence_dir.*\.claude/quality-gates/' "$SKILL_MD"; then
  echo "PASS: evidence_dir uses .claude/quality-gates/ path"
else
  echo "FAIL: evidence_dir path not .claude/quality-gates/"
  fail=$((fail + 1))
fi
assert_line "evidence_dir uses CLAUDE_CODE_SESSION_ID" "$(first_line 'CLAUDE_CODE_SESSION_ID')"

# I-G: retry must re-capture BOTH sandbox_dir AND baseline_sha (new snapshot auto-recorded).
retry_recap_line=$(first_line 're-capture')
assert_line "retry re-capture phrase present" "$retry_recap_line"
if grep -E 're-capture' "$SKILL_MD" | grep -q 'baseline_sha' && \
   grep -E 're-capture' "$SKILL_MD" | grep -q 'sandbox_dir'; then
  echo "PASS: retry re-captures both sandbox_dir and baseline_sha"
else
  echo "FAIL: retry does not re-capture both sandbox_dir + baseline_sha"
  fail=$((fail + 1))
fi

# --- round-2 digest-seal wiring ---

# R5a¹ (formerly R0) must capture snapshot_digest in the R5a¹ section (after the
# "Step R5a¹" heading, before the runtime-verifier dispatch) — NOT the Law-2
# header at the top. Anchored on the line-start bold heading, NOT the bare
# label — a bare 'Step R5a¹' resolves to an earlier prose cross-reference
# (measured: bare label = 174, actual heading = 810), which would degenerate
# this into a whole-file-ish search that can't tell the heading moved.
r5a1_section=$(first_line '^[*][*]Step R5a¹')
# Guard the degenerate case explicitly: if the heading is gone, r5a1_section
# is 0 and `first_line_after … 0` searches the WHOLE FILE from the top — this
# is the exact bug that made the pre-migration :205 lock vacuous (it found
# the top-of-file Law-2 header's own `snapshot_digest` mention at line 53 and
# passed). Measured on this file: without this guard, renaming the R5a¹
# heading away still leaves this assertion GREEN via that top-of-file match.
if [[ "$r5a1_section" -gt 0 ]]; then
  r5a1_digest=$(first_line_after 'snapshot_digest' "$r5a1_section")
else
  r5a1_digest=0
fi
if [[ "$r5a1_digest" -gt 0 && "$r5a1_digest" -lt "$runtime_line" ]]; then
  echo "PASS: R5a¹ captures snapshot_digest (line 3) at $r5a1_digest"
else
  echo "FAIL: R5a¹ does not capture snapshot_digest in the R5a¹ section (found=$r5a1_digest, runtime=$runtime_line, section_heading=$r5a1_section)"
  fail=$((fail + 1))
fi

# Guard call must thread the 3rd arg on the R4 call line itself ($guard_line,
# the first `mutation-guard` AFTER the runtime dispatch) — not the header mention.
if awk -v n="$guard_line" 'NR==n && /snapshot_digest/ {f=1} END{exit !f}' "$SKILL_MD"; then
  echo "PASS: R4 guard call threads snapshot_digest (3-arg) at line $guard_line"
else
  echo "FAIL: R4 guard call (line $guard_line) does not thread snapshot_digest"
  fail=$((fail + 1))
fi

# I-G retry must re-capture snapshot_digest (line 3) in addition to the two existing.
if grep -E 're-capture' "$SKILL_MD" | grep -q 'snapshot_digest'; then
  echo "PASS: retry re-captures snapshot_digest"
else
  echo "FAIL: retry does not re-capture snapshot_digest"
  fail=$((fail + 1))
fi

# --- R2-AC5: Law-3 persona hardening (the bypass escaped because reviewers
#     trusted a verifier-writable artifact; the persona now forces that check).
#     Anchor on the stable literal `verifier-writable`, which BOTH persona edits
#     in Task 6 Step 3 include verbatim. ---
AGENTS_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)/agents"
for p in security-reviewer adversarial; do
  if grep -qi 'verifier-writable' "$AGENTS_DIR/$p.md"; then
    echo "PASS: $p persona has the verifier-writable-artifact check"
  else
    echo "FAIL: $p persona missing the verifier-writable-artifact check"
    fail=$((fail + 1))
  fi
done

# --- v2.3.0 R4: Review-gate findings surfaced before the decision tool ---
# The Surface-findings step (Step 4.5) must precede the iter-boundary
# decision's `findings remain` question. Anchor on the surface-step TEXT,
# NOT the `## Review gate` section heading — a heading always precedes its
# body, so a heading anchor is a tautological PASS (the V7-class defect this
# file was created to avoid). Existence grep alone cannot catch mis-placement.
surface_line=$(first_line 'Surface findings|Step 4\.5')
question_line=$(first_line 'question:.*findings remain')
assert_line "Surface-findings step present" "$surface_line"
assert_line "iter-boundary decision question present" "$question_line"
assert_order "Surface findings precedes iter-boundary decision" "$surface_line" "$question_line"

# --- v2.4.0: Upfront gate-scope decision (Decision 1) ---

# Decision 1 gate-scope question exists: literal `both gates` anchor in a
# question: field, with header `Gate scope`.
gatescope_q=$(first_line 'question:.*both gates')
assert_line "gate-scope question present (anchor 'both gates')" "$gatescope_q"
assert_line "Gate scope header present" "$(first_line 'header:.*Gate scope')"

# Ordering: gate-scope question BEFORE the Review gate dispatch.
assert_order "gate-scope question precedes Review gate dispatch" "$gatescope_q" "$review_line"

# Ordering: gate-scope (Decision 1) question BEFORE the runtime-scope (Decision 2) question.
runtimescope_q=$(first_line 'question:.*Runtime scope')
assert_order "gate-scope question precedes runtime-scope question" "$gatescope_q" "$runtimescope_q"

# Uniqueness: `both gates` appears in exactly one question: line (anchor convention).
bg_count=$(grep -cE 'question:.*both gates' "$SKILL_MD" || true)
if [[ "$bg_count" -eq 1 ]]; then
  echo "PASS: 'both gates' anchor unique (1 question: line)"
else
  echo "FAIL: 'both gates' anchor not unique ($bg_count question: lines)"
  fail=$((fail + 1))
fi

# `gate` domain documents `both`.
assert_line "gate domain documents both" "$(first_line 'gate.*review.*runtime.*both')"

# Precedence advisory: explicit gate= wins over --skip-runtime (no silent conflict).
assert_line "gate= precedence advisory documented" "$(first_line 'gate=.*wins')"

# Dispatch Loop <-> Upfront Execution Plan consistency (round-2 advisory b82e4d19):
# Dispatch Loop step 2 must reference Decision 1 and the short-circuit so the two
# sections cannot drift.
dl_line=$(first_line '## Dispatch Loop')
assert_line "Dispatch Loop section present" "$dl_line"
assert_line "Dispatch Loop references Decision 1" "$(first_line_after 'Decision 1' "$dl_line")"
assert_line "Dispatch Loop references short-circuit" "$(first_line_after 'short-circuit' "$dl_line")"

# --- v2.4.0 review-fix F1: single-gate /qg runtime produces the manifest ---
# /qg runtime bypasses the Dispatch Loop (and thus Decision 2), so the Runtime
# gate itself must produce manifest/approved_surfaces/block_policy for R3
# (now R5a³). Guard: a Step R5a⁰ (formerly R-init — the "R-init" label was
# reused by the impact-driven rewrite for baseline resolution, an unrelated
# step, so this lock MUST move or it silently starts checking the wrong
# section) must run detect-runtime.sh on the single-gate runtime path, BEFORE
# the runtime-verifier (R5a³) dispatch. Anchored on the line-start bold
# heading, NOT the bare label, for the same reason as the R5a¹ lock above.
rg_header=$(first_line '^## Runtime gate')
r5a0_line=$(first_line '^[*][*]Step R5a⁰')
r5a1_bound=$(first_line '^[*][*]Step R5a¹')
assert_line "Runtime gate Step R5a⁰ present" "$r5a0_line"
assert_order "R5a⁰ precedes runtime-verifier dispatch" "$r5a0_line" "$runtime_line"
# Window-bound the detect-runtime search to [rg_header, R5a¹) — an earlier cut of
# this lock searched with NO upper bound at all (`first_line_after` only takes a
# lower bound) and stayed GREEN after deleting the actual detect-runtime.sh call
# from R5a⁰'s body, because it fell through to an unrelated LATER mention
# (`manifest: <output of detect-runtime.sh>` inside R5a³'s dispatch prompt, line
# 879) — measured on this file. Bounding to before R5a¹ closes that.
if [[ "$r5a0_line" -gt 0 && "$r5a1_bound" -gt 0 ]] && \
   awk -v s="$rg_header" -v e="$r5a1_bound" 'NR>s && NR<e && /detect-runtime/ {f=1} END{exit !f}' "$SKILL_MD"; then
  echo "PASS: R5a⁰ runs detect-runtime in the Runtime gate (window $rg_header..$r5a1_bound)"
else
  echo "FAIL: R5a⁰ does not run detect-runtime within its own section (window $rg_header..$r5a1_bound)"
  fail=$((fail + 1))
fi
if awk -v a="$rg_header" -v b="$runtime_line" 'NR>a && NR<b && /single-gate/ {f=1} END{exit !f}' "$SKILL_MD"; then
  echo "PASS: Runtime gate documents the single-gate runtime manifest path"
else
  echo "FAIL: Runtime gate does not document single-gate runtime manifest init"
  fail=$((fail + 1))
fi

# --- v2.4.0 review-fix F2: review-only suppresses "Proceed to Runtime gate" ---
# When gate scope = Review gate only, the iter-boundary AND max-iter decisions
# must NOT offer "Proceed to Runtime gate"; both carry a gate-scope-conditional
# note replacing it with a finalize option.
gsc_count=$(grep -cE 'Gate-scope conditional' "$SKILL_MD" || true)
if [[ "$gsc_count" -ge 2 ]]; then
  echo "PASS: gate-scope-conditional note in iter-boundary + max-iter ($gsc_count)"
else
  echo "FAIL: gate-scope-conditional note missing (found $gsc_count, need >=2)"
  fail=$((fail + 1))
fi
# Anchor on a paren-free substring: macOS awk -v mangles `\(` escapes, so a
# literal-paren regex would fail to match the (present) finalize option text.
assert_line "review-only finalize option present" "$(first_line 'accept findings, finalize')"

# --- v2.4.0 review-fix C4: gate= precedence wired into the skip logic ---
# effective_skip_runtime must be DEFINED (Arguments normalization) AND USED by
# the runtime-skip tests (Dispatch Loop step 4 + Runtime gate "skip this
# section") — otherwise the Decision-1 `gate=` > `--skip-runtime` precedence is
# documented but never governs execution (e.g. `/qg runtime --skip-runtime`
# would silently skip runtime). >=3 references = defined + both skip sites.
esr_count=$(grep -cE 'effective_skip_runtime' "$SKILL_MD" || true)
if [[ "$esr_count" -ge 3 ]]; then
  echo "PASS: effective_skip_runtime wired into the skip logic ($esr_count refs)"
else
  echo "FAIL: effective_skip_runtime under-wired (found $esr_count, need >=3: Arguments + Dispatch step 4 + Runtime gate)"
  fail=$((fail + 1))
fi

# --- v2.4.0 review-fix F7: Review gate clean-exit also honors review-only ---
# The kept=0 clean branches must route via Dispatch Loop step 4 (gate-scope
# check), NOT unconditionally "continue to the Runtime gate" — else a clean
# Review gate under "Review gate only" would run Runtime anyway.
# Anchor on a single-line substring (the full phrase wraps across lines).
assert_line "Review gate clean-exit routes via gate-scope check" "$(first_line 'when gate scope = Review gate only')"

# --- v2.7.0 §5.2-5.4: changes-exist floor (routing removed, integrity kept) ---
# check-review-scope.sh still invoked in the Review gate (call+cache for the floor).
assert_line "check-review-scope.sh invoked" "$(first_line 'check-review-scope.sh')"

# AC12: the model-owned routing honesty norm is present.
assert_line "review-scope ownership honesty norm present" "$(first_line 'You own review-scope resolution')"

# AC5: the Step 4.5 floor keys on the two deterministic inputs — the resolved scope
# file count AND the script-emitted changes_exist (NOT the removed scope_signal).
# Anchor BOTH conditions on a SINGLE line: 'changes_exist == yes' also appears on the
# honesty-norm line (L283), so a lone `first_line 'changes_exist == yes'` would match
# there and pass even if the Step 4.5 floor IF-condition itself regressed. The combined
# 'resolved_scope_file_count == 0 AND …changes_exist == yes' pattern is unique to the
# floor line, so it can only pass when the real floor condition is intact (codex v2.7.0
# review, finding 3).
assert_line "floor keyed on resolved_scope_file_count == 0 AND changes_exist == yes" \
  "$(first_line 'resolved_scope_file_count == 0 AND .*changes_exist == yes')"
assert_line "honest floor label present"                    "$(first_line 'NOT certified clean')"

# AC6: degraded signal still emits a loud fail-open advisory.
assert_line "degraded scope advisory present" "$(first_line 'scope check degraded')"

# 'no scope reviewed' appears in the honesty norm + the floor sub-case + the final
# summary variant → at least 3 occurrences.
floor_count=$(grep -cE 'no scope reviewed' "$SKILL_MD" || true)
if [[ "$floor_count" -ge 3 ]]; then
  echo "PASS: honest floor label in honesty norm + floor + final summary ($floor_count)"
else
  echo "FAIL: honest floor under-applied (found $floor_count, need >=3)"
  fail=$((fail + 1))
fi

# --- v2.7.0 negative guards: the removed routing surface must be GONE ---
# (AC8) empty-scope redirect gate + its question anchor + section + signal value.
for pat in 'review scope is empty' 'Empty-scope redirect' 'empty_scope_with_changes'; do
  n=$(grep -cF "$pat" "$SKILL_MD" || true)
  if [[ "$n" -eq 0 ]]; then
    echo "PASS: removed routing surface absent — '$pat' (0)"
  else
    echo "FAIL: removed routing surface still present — '$pat' ($n)"
    fail=$((fail + 1))
  fi
done
# (AC9) $effective_diff_scope wiring gone; (AC10) scope-redirect kill switch gone;
# (hygiene) the old scope_signal variable gone.
for pat in 'effective_diff_scope' 'DEVBREW_QUALITY_GATES_DISABLE_SCOPE_REDIRECT' 'scope_signal'; do
  n=$(grep -cF "$pat" "$SKILL_MD" || true)
  if [[ "$n" -eq 0 ]]; then
    echo "PASS: removed variable/switch absent — '$pat' (0)"
  else
    echo "FAIL: removed variable/switch still present — '$pat' ($n)"
    fail=$((fail + 1))
  fi
done

# --- v2.6.0 AC11: Runtime scope transparency line — MOVED to the "T1 / AC1 /
# AC2 / M3: 앵커 이전" block near the end of this file (Task 12). The old
# literal 'regardless of Review scope' no longer exists post-rewrite; the new
# anchor is a different sentence with a different uniqueness/position
# contract. Keeping both here and there would drift as soon as either wording
# changes — so this block does not survive, it moves whole. ---

# --- NG6 (restored, independent — fix round R11) ---
# 이 검사는 원래 "v2.10.0 publish-eligible sentinel wiring" 블록 안에서 fs_start/
# fs_end 를 그 블록의 다른 sentinel 서브체크와 공유하고 있었다. sentinel 배선이
# 통째로 삭제되면서 이 검사도 함께 사라졌다 — sentinel 과는 무관한 검사였는데
# 변수 재사용으로만 묶여 있었다. 자기 변수(ng6_block)로 독립 도출해 되살린다:
# 다른 섹션이 지워져도 이 검사는 죽지 않는다.
#
# allowed-tools: 키부터, 다음 top-level frontmatter 키(들여쓰기 없고 '-'로도
# 시작하지 않는 줄) 또는 frontmatter 닫는 '---' 중 먼저 오는 것 앞까지를 뽑는다.
ng6_block="$(awk '/^allowed-tools:/{f=1;next} f&&/^---$/{exit} f&&/^[^ -]/{exit} f{print}' "$SKILL_MD")"

# 양성 증인 먼저 — 도출한 블록이 비어 있지 않고, 알려진 항목(setup-qg.sh 진입점)을
# 담는다. 이게 없으면 앵커가 죽어 $ng6_block 이 빈 문자열이 될 때 아래 부재
# 단언이 공허참으로 통과한다.
if [[ -n "$ng6_block" ]] && grep -qF 'Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-qg.sh:*)' <<<"$ng6_block"; then
  echo "PASS: NG6 양성 증인 — allowed-tools 블록 도출 유효(setup-qg.sh 항목 확인)"
else
  echo "FAIL: NG6 양성 증인 실패 — allowed-tools 블록 도출이 비었거나 앵커가 죽음"; fail=$((fail+1))
fi

# 부재 — allowed-tools 에 standalone `Skill` 항목이 없다 (no skill-nesting).
if grep -qE '^[[:space:]]*-[[:space:]]*Skill[[:space:]]*$' <<<"$ng6_block"; then
  echo "FAIL: quality-pipeline allowed-tools contains Skill (NG6 violation)"; fail=$((fail+1))
else
  echo "PASS: quality-pipeline allowed-tools has no Skill (NG6)"
fi

# ── T48 / AC51: 스텝 락 이전 + 기존 로직 7종이 전부 새 자리를 갖는다 ──
# 자리 없는 기존 로직은 삭제가 아니라 누락이다. 7종을 이름으로 센다.
echo "== 락 이전 검사"
legacy_logic=(
  'detect-runtime.sh'                       # 매니페스트
  'block_policy'                            # zero-click 폴백
  'snapshot_digest'                         # create-sandbox 3줄 파싱
  'quality-gates:test-scope-validator'      # 분류 dispatch
  'spec_acceptance_criteria'                # spec AC 수집
  'quality-gates:runtime-verifier'          # verifier dispatch
  'mutation-guard'                          # Law 2 오라클
)
missing_logic=0
for lg in "${legacy_logic[@]}"; do
  if ! grep -qF "$lg" "$SKILL_MD"; then
    echo "FAIL: 기존 로직 '$lg' 가 새 SKILL.md 에 없음 (자리 없는 로직 = 누락)"
    missing_logic=$((missing_logic + 1))
  fi
done
[[ $missing_logic -eq 0 ]] && echo "PASS: 기존 로직 7종 전부 새 자리에 존재" || fail=$((fail + 1))

# ── /qg iter-1 (pr-test-analyzer, mutation 실측): 신규 스크립트 **배선** 락 ──────
# 실측된 구멍: SKILL.md 에서 다섯 신규 스크립트의 호출 지점 10곳을 **전부 삭제**해도
# bash 스위트 ~110개(기존 red 6 제외) 중 RED 가 **하나도 없었다**. 이 브랜치의 산출물
# 전체가 그 배선인데 그것을 재는 락이 없었다.
#
# 있던 것: (a) 음의 락 — R5a³..R5b 창 안에 run-test-selection.sh 가 0회(어디에도 0회면
# 만족), (b) 파일이 디스크에 존재하고 -x 인지(test_impact_runtime_docs.sh). 둘 다
# "누가 부르는가" 를 재지 않는다. 위 legacy_logic 양의 목록에는 **기존 7종만** 있었다.
#
# 두 가지를 함께 지킨다:
#  1) 전체-파일 grep 금지. 아키텍처 산문(:642)과 R5b 폴백 문단(:894)에도 스크립트
#     이름이 나오므로 whole-file grep 은 호출을 다 지워도 통과한다 — 이 리포의 문서화된
#     grep-matches-a-comment 함정. **소유 스텝의 창** 안에서만 센다.
#  2) needle 에 `scripts/` 접두와 **서브커맨드**를 같은 줄에서 요구한다. 접두는 호출을
#     산문에서 가르고(실측: run-test-selection.sh 7회 중 `scripts/` 동반은 5회),
#     서브커맨드는 "R1a 가 detect 대신 assign 을 부른다" 같은 뒤바뀜까지 잡는다.
#     index() 리터럴 매칭이라 regex 이스케이프 사고가 없다.
echo "== 신규 스크립트 배선 (소유 스텝 창)"
assert_call_in_window() {   # <label> <literal-needle> <start-regex> <end-regex>
  local label="$1" needle="$2" s_pat="$3" e_pat="$4" s e
  s=$(first_line "$s_pat"); e=$(first_line "$e_pat")
  if [[ "$s" -le 0 || "$e" -le 0 || "$s" -ge "$e" ]]; then
    echo "FAIL: $label — 창 앵커 붕괴 (start=$s end=$e; 헤딩 리네임?)"
    fail=$((fail + 1)); return
  fi
  if awk -v s="$s" -v e="$e" -v n="$needle" \
       'NR>s && NR<e && index($0,n) { f=1 } END { exit !f }' "$SKILL_MD"; then
    echo "PASS: $label (창 $s..$e)"
  else
    echo "FAIL: $label — 창 $s..$e 안에 '$needle' 호출 없음"
    fail=$((fail + 1))
  fi
}

assert_call_in_window "R-init 이 resolve-baseline.sh 호출" \
  'scripts/resolve-baseline.sh'            '^[*][*]Step R-init' '^[*][*]Step R1a'
assert_call_in_window "R1a 가 run-test-selection.sh detect 호출" \
  'scripts/run-test-selection.sh" detect'  '^[*][*]Step R1a'    '^[*][*]Step R1b'
assert_call_in_window "R1b 가 run-test-selection.sh assign 호출" \
  'scripts/run-test-selection.sh" assign'  '^[*][*]Step R1b'    '^[*][*]Step R2'
assert_call_in_window "R4 가 baseline-cache.sh get 호출" \
  'scripts/baseline-cache.sh" get'         '^[*][*]Step R4'     '^[*][*]Step R5a⁰'
assert_call_in_window "R4 가 baseline-cache.sh put 호출" \
  'scripts/baseline-cache.sh" put'         '^[*][*]Step R4'     '^[*][*]Step R5a⁰'
assert_call_in_window "R4 가 run-test-selection.sh run 호출 (기준선 측)" \
  'scripts/run-test-selection.sh" run'     '^[*][*]Step R4'     '^[*][*]Step R5a⁰'
assert_call_in_window "R5b 가 run-test-selection.sh run 호출 (HEAD 측)" \
  'scripts/run-test-selection.sh" run'     '^[*][*]Step R5b'    '^[*][*]Step R6'
assert_call_in_window "R5b 가 qg-worktree.sh create-head 호출 (HEAD 축 전용 트리)" \
  'scripts/qg-worktree.sh" create-head'    '^[*][*]Step R5b'    '^[*][*]Step R6'

# ── T89 · AC65 · §11 ⑬ / §6.7 S4 — HEAD 축이 도는 트리 ────────────────────
# 이 브랜치가 파는 것은 *"같은 선택을 두 번 돌려 짝짓는다"* 이고, 그것은 **두 축이 같은
# 종류의 환경**일 때만 성립한다. HEAD 축이 verifier 샌드박스(`$runtime_project_dir`)에서
# 돌면 (a) HEAD 축만 verifier 의 부팅 setup 을 물어 비대칭이 `NEW_REGRESSION` 과
# 구별 불가능한 모양으로 새고, (b) 게이트 자신의 테스트 산출물이 R7 mutation-guard 의
# 검사 대상 트리에 떨어져 거짓 terminal FAIL 을 낸다.
#
# **창은 R5b..R7 이다 — R6 을 포함해야 한다 (/qg iter-7, 리뷰어 2명).** 앞 버전은
# R5b..R6 이었는데, R6 의 flaky 재실행도 `run` 호출이고 **그것이 authoritative** 다.
# 창 밖이라 구조적으로 감사되지 않았고, 실제로 그 라운드의 CRITICAL 이 정확히 거기서
# 났다 — 락이 자기가 지키려던 결함을 볼 수 없는 자리에 서 있었다.
#
# **왜 창 안 `$runtime_project_dir` 0회 로 재지 않는가.** 그 변수는 이 창 안에서
# *정당하게* 등장한다 — 폴백 문단이 "폴백의 `runtime_project_dir` 는 사용자의 실제
# 워킹 트리다" 라고 설명하는 자리다. 0회 락은 지금 당장 RED 이고, 그 문단을 지우면
# GREEN 이 되는 **거꾸로 된 이빨**을 갖는다. 대신 **호출의 인자 자리**를 ∀ 로 잰다.
echo "== R5b·R6 의 HEAD 축 트리 인자"
r5b_s=$(first_line '^[*][*]Step R5b'); r7_s=$(first_line '^[*][*]Step R7')
r6_s=$(first_line '^[*][*]Step R6')
if [[ "$r5b_s" -le 0 || "$r6_s" -le 0 || "$r7_s" -le 0 || "$r5b_s" -ge "$r6_s" || "$r6_s" -ge "$r7_s" ]]; then
  echo "FAIL: HEAD 축 인자 락 — 창 앵커 붕괴 (R5b=$r5b_s R6=$r6_s R7=$r7_s)"
  fail=$((fail + 1))
else
  # sites = 창 안 `run` 호출 줄 수 · good = 다음 줄이 head_tree_dir 인 것
  read -r sites good < <(awk -v s="$r5b_s" -v e="$r7_s" '
    NR>s && NR<e && index($0,"scripts/run-test-selection.sh\" run") { want=NR+1; sites++ }
    want && NR==want { if (index($0,"$head_tree_dir")) good++; want=0 }
    END { print sites+0, good+0 }
  ' "$SKILL_MD")
  # ∃ 짝: 호출이 0개면 ∀ 는 공허하게 참이다. 그리고 **2개 이상**이어야 한다 — R5b 의
  # 본 실행과 R6 의 flaky 재실행. 하나만 요구하면 R6 의 재실행을 통째로 지워도 통과한다.
  if [[ "$sites" -ge 2 && "$good" -eq "$sites" ]]; then
    echo "PASS: R5b·R6 의 run 호출 ${sites}곳 전부가 HEAD 축 트리(\$head_tree_dir)를 받음 (창 $r5b_s..$r7_s)"
  else
    echo "FAIL: HEAD 축 인자 (호출 ${sites}곳(≥2 필요) 중 head_tree_dir 수신 ${good}곳) — 샌드박스로 되돌아갔거나 flaky 재실행이 사라졌는가?"
    fail=$((fail + 1))
  fi
fi

# create-head 의 인자는 **봉인 커밋 B** 여야 한다. `$merge_base` 를 넘기면 HEAD 축이
# 기준선과 같은 커밋에 붙어 차등이 구조적으로 0 이 되는데, 트리는 정상 생성되고 행도
# 정상으로 나오므로 **어떤 degrade 신호도 서지 않는다**.
#
# **∀ 다 (/qg iter-7, pr-test-analyzer).** 앞 버전은 ∃ 여서 — 맞는 호출 하나만 있으면
# `f=1` — 뒤에 `$merge_base` 를 받는 **두 번째** `create-head` 를 덧붙이는 mutation 이
# 통과했다(마지막 대입이 이긴다). 형제 `run` 인자 락은 처음부터 ∀ 였는데 이 락만
# ∃ 였다: 같은 파일 안에서 관례가 갈린 것이 구멍이었다.
read -r ch_sites ch_good < <(awk -v s="$r5b_s" -v e="$r7_s" '
  NR>s && NR<e && index($0,"scripts/qg-worktree.sh\" create-head") { want=NR+1; sites++
    if (index($0,"$baseline_sha")) { good++; want=0 } }
  want && NR==want { if (index($0,"$baseline_sha")) good++; want=0 }
  END { print sites+0, good+0 }
' "$SKILL_MD")
if [[ "$ch_sites" -ge 1 && "$ch_good" -eq "$ch_sites" ]]; then
  echo "PASS: create-head 호출 ${ch_sites}곳 전부가 봉인 커밋(\$baseline_sha)을 받음"
else
  echo "FAIL: create-head 인자 (호출 ${ch_sites}곳 중 baseline_sha 수신 ${ch_good}곳)"
  fail=$((fail + 1))
fi

# HEAD 축 트리 폐기는 **R6 뒤**여야 한다 — R6 의 flaky 재실행이 그 트리를 쓴다.
# R5b 창 안에 `remove "$head_tree_dir"` 가 있으면 그 재실행이 불가능해진다(iter-7 CRITICAL).
rm_in_r5b=$(awk -v s="$r5b_s" -v e="$r6_s" \
  'NR>s && NR<e && index($0,"remove \"$head_tree_dir\"") { c++ } END { print c+0 }' "$SKILL_MD")
rm_in_r6=$(awk -v s="$r6_s" -v e="$r7_s" \
  'NR>s && NR<e && index($0,"remove \"$head_tree_dir\"") { c++ } END { print c+0 }' "$SKILL_MD")
if [[ "$rm_in_r5b" -eq 0 && "$rm_in_r6" -ge 1 ]]; then
  echo "PASS: HEAD 축 트리 폐기가 R6 뒤 (R5b 창 ${rm_in_r5b}회 · R6 창 ${rm_in_r6}회)"
else
  echo "FAIL: HEAD 축 트리 폐기 위치 (R5b 창 ${rm_in_r5b}회(0 이어야) · R6 창 ${rm_in_r6}회(≥1 이어야)) — flaky 재실행이 지워진 트리를 쓴다"
  fail=$((fail + 1))
fi

# R5b 실패 라우팅 — R6/R7 과 같은 규율. `create-head`/`run` 이 죽었을 때 무엇을 할지
# 정의돼 있어야 하고, **폴백 대상 두 변수를 금지**해야 한다.
r5b_route=1
r5b_body=$(awk -v s="$r5b_s" -v e="$r6_s" 'NR>s && NR<e' "$SKILL_MD")
if [[ -z "$r5b_body" ]]; then
  echo "FAIL: R5b 창이 비었다 — 아래 검사가 공허하게 통과할 뻔했다"
  fail=$((fail + 1)); r5b_route=0
fi
if [[ $r5b_route -eq 1 ]]; then
  grep -q 'create-head' <<<"$r5b_body" || r5b_route=0
  grep -q 'unrun' <<<"$r5b_body"       || r5b_route=0
  # 폴백 금지가 명문화됐는가 — 관측 실패 시 두 대체 트리로 새지 말라는 지시
  grep -q '폴백하지 않는다' <<<"$r5b_body" || r5b_route=0
  if [[ $r5b_route -eq 1 ]]; then
    echo "PASS: R5b 실패 라우팅 (create-head 실패 → unrun + degraded · 폴백 금지 명문화)"
  else
    echo "FAIL: R5b 실패 라우팅 없음 — 관측 실패가 음성 결과로 읽힌다"
    fail=$((fail + 1))
  fi
fi

# 재시도 경로: 새 샌드박스는 **새 B** 를 낸다. refresh 된 값으로 create-head 를 다시
# 부르지 않으면 HEAD 축이 고쳐지기 전 코드에 붙는다.
#
# **방향을 잰다, 토큰이 아니라 (/qg iter-7, pr-test-analyzer).** 앞 버전은 그 문단에
# `create-head` 라는 토큰이 있는지만 봤는데 문단이 그 토큰을 여러 번 쓰므로, 지시문을
# *"기존 head_tree_dir 을 그대로 재사용한다"* 로 **반전**해도 통과했다 — 삭제는 잡히고
# 반전은 안 잡히는 락이었다. 이제 재호출 지시(양)와 재사용 지시(음)를 함께 본다.
retry_para=$(awk '/재시도의 R5b/,/^$/' "$SKILL_MD")
if [[ -z "$retry_para" ]]; then
  echo "FAIL: 재시도 문단 앵커 소실 (빈 코퍼스 위에서는 아래 검사가 공허하다)"
  fail=$((fail + 1))
elif ! grep -q 'refresh 된 `baseline_sha` 로 다시 부른다' <<<"$retry_para"; then
  echo "FAIL: 재시도 문단에 'refresh 된 baseline_sha 로 재호출' 지시 없음"
  fail=$((fail + 1))
elif grep -qE '그대로 재사용|재사용한다|그대로 쓴다' <<<"$retry_para"; then
  echo "FAIL: 재시도 문단이 옛 트리 재사용을 지시 — 고쳐지기 전 코드를 HEAD 로 잰다"
  fail=$((fail + 1))
else
  echo "PASS: 재시도 문단이 refresh 재호출을 지시하고 재사용 지시가 0회"
fi

# R6 은 호출이 **둘**이다 — 어댑터별 대조 1회 + `--aggregate` 1회. "창 안에 1개 이상"
# 으로 재면 둘 중 하나를 지워도 나머지가 만족시킨다(실측: 대조 호출만 지운 mutation 이
# GREEN 이었다). 개수와 `--aggregate` 를 따로 잠근다.
assert_call_count_in_window() {   # <label> <literal-needle> <min> <start-regex> <end-regex>
  local label="$1" needle="$2" min="$3" s_pat="$4" e_pat="$5" s e n
  s=$(first_line "$s_pat"); e=$(first_line "$e_pat")
  if [[ "$s" -le 0 || "$e" -le 0 || "$s" -ge "$e" ]]; then
    echo "FAIL: $label — 창 앵커 붕괴 (start=$s end=$e; 헤딩 리네임?)"
    fail=$((fail + 1)); return
  fi
  # 줄 단위 index() 로 센다 — 리터럴 매칭이라 regex 이스케이프 사고가 없고, 각 호출은
  # 자기 줄에 있으므로 "매치된 줄 수 = 호출 수" 가 성립한다. (gsub 은 정규식이라
  # needle 의 `.` 이 임의 문자로 새므로 쓰지 않는다.)
  n=$(awk -v s="$s" -v e="$e" -v nd="$needle" \
        'NR>s && NR<e && index($0,nd) { c++ } END { print c+0 }' "$SKILL_MD")
  if [[ "$n" -ge "$min" ]]; then
    # `${n}` 중괄호 필수 — `$n회` 로 쓰면 macOS bash 3.2 가 한글 `회` 의 선두 바이트를
    # 변수명에 포함시켜 `set -u` 아래서 "n?: unbound variable" 로 죽는다 (실측).
    echo "PASS: $label (${n}회 ≥ $min, 창 $s..$e)"
  else
    echo "FAIL: $label — 창 $s..$e 안에 '$needle' 이 ${n}회 (최소 $min 필요)"
    fail=$((fail + 1))
  fi
}

assert_call_count_in_window "R6 의 diff-test-results.py 호출 2곳(대조+집계) 유지" \
  'scripts/diff-test-results.py' 2         '^[*][*]Step R6'     '^[*][*]Step R7'
assert_call_in_window "R6 이 diff-test-results.py --aggregate 호출 (집계)" \
  'scripts/diff-test-results.py" --aggregate' '^[*][*]Step R6'  '^[*][*]Step R7'
assert_call_in_window "R8 이 check_qa_ledger.py 호출" \
  'scripts/check_qa_ledger.py'             '^[*][*]Step R8'     '^[*][*]Step R9'

# ── T91 · AC66 · §11 ⑱(U3) — 기계 집계값이 원장 대조까지 살아서 도달하는가 ────
# 두 지점이 함께 있어야 대조가 성립한다. 하나만 잠그면 다른 하나를 지워 사슬을 끊을 수
# 있다: R6 이 집계를 파일로 남기지 않으면 R8 이 넘길 것이 없고, R8 이 `--aggregate` 를
# 넘기지 않으면 R6 이 남긴 파일이 아무 데도 안 쓰인다.
#
# 스크립트가 인자를 필수로 만들어 두었으므로 배선이 끊기면 런타임에 exit 2 로 죽는다
# (fail-closed). 그래도 여기서 잠그는 이유는 **조용한 죽음이 아니라 조용한 미배선**을
# 막기 위해서다 — 산문만 남고 호출이 사라지면 아무도 그 게이트를 부르지 않는다.
echo "== R6→R8 집계 전달 사슬"
r6_s=$(first_line '^[*][*]Step R6'); r8_s=$(first_line '^[*][*]Step R8')
r7_s=$(first_line '^[*][*]Step R7'); r9_s=$(first_line '^[*][*]Step R9')
if [[ "$r6_s" -le 0 || "$r7_s" -le 0 || "$r8_s" -le 0 || "$r9_s" -le 0 ]]; then
  echo "FAIL: 집계 사슬 락 — 창 앵커 붕괴 (R6=$r6_s R7=$r7_s R8=$r8_s R9=$r9_s)"
  fail=$((fail + 1))
else
  chain_ok=1
  # ① R6 의 `--aggregate` 호출이 stdout 을 파일로 남긴다
  awk -v s="$r6_s" -v e="$r7_s" '
    NR>s && NR<e && index($0,"diff-test-results.py\" --aggregate") { want=1 }
    want && index($0,"> \"$aggregate_yaml\"") { f=1 }
    END { exit !f }' "$SKILL_MD" \
    || { echo "    R6 이 집계 stdout 을 \$aggregate_yaml 로 남기지 않음"; chain_ok=0; }
  # ② R8 의 게이트 호출이 **그 파일을** --aggregate 로 넘긴다 (호출 줄 또는 이어지는 줄).
  #
  # 두 분기 모두 리터럴 `"$aggregate_yaml"` 을 요구한다 (/qg iter-7, 리뷰어 2명).
  # 앞 버전은 같은-줄 분기가 **토큰 `--aggregate` 만** 요구해서, 호출을 한 줄로 접고
  # `--aggregate "$per_adapter_yaml"` 을 넘기는 mutation 이 통과했다. 그리고 그것은
  # 이론이 아니라 실제 fail-open 이다: `per_adapter()` 도 `attribution_status:` 를 내므로
  # 게이트가 **깨끗하게 파싱해** 어댑터의 `closed` 를 원장의 `closed` 와 대조하고 통과한다
  # — 전사 게이트가 막으려던 바로 그 형태다. 현재 SKILL 이 2줄이라 GREEN 이었던 것이지
  # 락의 이빨 때문이 아니었다.
  awk -v s="$r8_s" -v e="$r9_s" '
    NR>s && NR<e && index($0,"scripts/check_qa_ledger.py") { want=NR+1
      if (index($0,"--aggregate \"$aggregate_yaml\"")) { f=1; want=0 } }
    want && NR==want { if (index($0,"--aggregate \"$aggregate_yaml\"")) f=1; want=0 }
    END { exit !f }' "$SKILL_MD" \
    || { echo "    R8 의 check_qa_ledger 호출이 --aggregate \$aggregate_yaml 을 넘기지 않음"; chain_ok=0; }
  if [[ $chain_ok -eq 1 ]]; then
    echo "PASS: R6 이 집계를 파일로 남기고 R8 이 그것을 --aggregate 로 대조에 넘김"
  else
    echo "FAIL: R6→R8 집계 전달 사슬 (전사 대조가 대조할 원본에 닿지 못한다)"
    fail=$((fail + 1))
  fi
fi

# ── T94 · AC68 · §11 ㉓ — `unclaimed` 집행이 R1b→R8 로 배선돼 있는가 ─────────────
# 사슬이다: R1b 가 `assign` stdout 을 파일로 남기지 않으면 R8 이 넘길 것이 없고, R8 이
# `--assign-rows` 를 넘기지 않으면 그 파일이 아무 데도 안 쓰인다. 배선이 끊기면
# *"`unclaimed` 하나면 `verification: degraded`"* 는 다시 **읽는 기계가 없는 산문**이다.
#
# **세 축을 한 번에 (iter-8 `/qg` 리뷰 — 앞 버전이 세 축 전부에 뚫렸다, 전부 실측):**
#   · **fenced** — ① 이 raw `index()` 라 리다이렉트를 코드에서 지우고 *산문으로* 인용하면
#     통과했다. SKILL 이 정확히 그 fail-open 을 지시하는데도. 이제 ```-fence 안만 본다.
#     같은 수가 반대 위양성(R8 산문의 스크립트 경로 언급이 락을 RED 로)도 닫는다.
#   · **∀** — ① 이 ∃ 라 맞는 호출 뒤에 리다이렉트 없는 두 번째 `assign` 을 덧붙이면
#     통과했다. ② 가 같은 커밋에서 이 공격을 ∀ 로 막아 놓고 ① 은 ∃ 로 남아 있었다.
#   · **중복 인자** — ② 가 "블록이 리터럴을 포함" 만 봐서 `--assign-rows A --assign-rows
#     /dev/null` 이 통과했다(파서가 dict, 마지막이 이긴다). 이제 **정확히 1회**를 센다.
echo "== R1b→R8 unclaimed 집행 사슬"
rinit_s=$(first_line '^[*][*]Step R-init'); r1b_s=$(first_line '^[*][*]Step R1b')
r1a_s=$(first_line '^[*][*]Step R1a'); r2_s=$(first_line '^[*][*]Step R2')
rt_end=$(first_line '^[*][*]Step R9')
if [[ "$rinit_s" -le 0 || "$r1a_s" -le 0 || "$r1b_s" -le 0 || "$r2_s" -le 0 \
      || "$r8_s" -le 0 || "$r9_s" -le 0 || "$rt_end" -le 0 ]]; then
  echo "FAIL: unclaimed 사슬 락 — 창 앵커 붕괴 (R-init=$rinit_s R1a=$r1a_s R1b=$r1b_s R2=$r2_s R8=$r8_s R9=$r9_s)"
  fail=$((fail + 1))
else
  uc_ok=1
  # ① R1b 의 `assign` 호출은 **∀ · fenced · 주석 제거**: 코드 블록 안의 모든 assign 호출이
  #    자기 파이프라인 안에서 **원자적 쓰기 3종**을 갖는다 — `.part` 로 리다이렉트 ·
  #    **`&&` 로 연결된** `mv` · 자기 줄 하나로 선 `pipefail`. 최종 경로로 직접
  #    리다이렉트하면 셸이 **명령 실행 전에** 대상을 절단하므로, 죽은 생산자의 0바이트
  #    파일이 "unclaimed 0건" 과 구분되지 않는다 (실측: 그 입력에 게이트가 exit 0).
  #    그래서 락이 재는 것은 "파일로 간다" 가 아니라
  #    **"실패한 실행이 최종 경로에 파일을 남기지 않는다"** 이다.
  #
  #    **iteration 2 에서 이 assert 가 셋 다 뚫렸다 (전부 실측 생존):**
  #    · fence 는 경계를 닫은 게 아니라 **옮겼다** — 산문 대신 **셸 주석**이 리터럴을
  #      실어 나른다. 리다이렉트를 최종 경로로 되돌리고 `&& true   # 앞 버전: …` 로
  #      옛 리터럴을 주석에 남기면 GREEN. 그래서 누적 전에 주석을 잘라낸다.
  #    · `mv` 의 **존재**만 재고 **조건**을 재지 않았다. `&&` → `;` 로 바꾸면 죽은
  #      생산자의 0바이트 `.part` 가 최종 경로로 승격되고 `assign_rc` 는 `mv` 의 0 이
  #      되어 라우팅 표의 두 팔(non-zero · 파일 부재)이 **둘 다** 깨끗하게 읽힌다.
  #      `.part`+`mv` 는 `&&` 없이는 `.part` 가 아예 없느니만 못하다.
  #    · `pipefail` 이 substring 이라 주석 처리해도 통과했다. 이제 줄 전체로 앵커한다.
  #
  #    **iteration 3 에서 다시 셋이 뚫렸다 (전부 실측 생존, 리뷰어 2명 독립):**
  #    ★ `pipefail` 이 **창-스코프**였다 — `pf` 를 `blk` 누산기 **밖**에서 세니, 그 줄을
  #      같은 창의 *다른* fenced 블록(심지어 `Agent({…})` 블록)으로 옮겨도 GREEN 이었고,
  #      파이프라인 **뒤**로 옮기면 `assign_rc=$?` 가 `set` 의 종료코드(항상 0)를 잡아
  #      라우팅 표 전체가 파일 존재에만 실리는데도 GREEN 이었다. 런타임에서 두 fenced
  #      블록은 **두 번의 `Bash` 호출 = 두 개의 셸**이라 앞 블록의 `pipefail` 은 뒤
  #      블록에 효력이 없다 — 이 커밋이 `qg_paths_for()` 를 지울 때 쓴 바로 그 사실을
  #      락 자신은 인코딩하지 않고 있었다. 이제 **같은 블록 + 파이프라인보다 앞**을 잰다.
  #    ★ `&&` 의 **존재**만 재고 그 `&&` 가 무엇에 묶이는지 안 쟀다 — 리다이렉트와
  #      `&& mv` 사이에 `; true \` 를 끼우면 `&&` 가 `true` 에 묶여 **`mv` 가 무조건**
  #      실행되고, 죽은 생산자의 0바이트가 최종 경로로 승격된다(리터럴은 그대로라 GREEN).
  #      `; true`·`|| :` 를 열거하지 않고 **`blk` 안에 `;` 0건**을 요구한다 — 백슬래시로
  #      이어진 블록에서 `&&` 사슬을 끊는 방법은 이것뿐이고, 블록을 일찍 끝내면 기존
  #      `&& mv` 리터럴 검사가 스스로 RED 가 된다.
  #    ★ **최종 경로로의 직접 리다이렉트**를 안 쟀다 — 진짜 리다이렉트를 최종 경로로
  #      되돌리고 같은 이어짐 안에 decoy `&& : > "$assign_rows_file.part"` 를 남기면 두
  #      리터럴이 다 만족되는데 셸은 명령 전에 최종 경로를 절단한다. AC70 이 만든 "파일
  #      부재" 신호가 파괴된다. 이제 `> "$assign_rows_file"`(닫는 따옴표 포함 — `.part`
  #      형태와 바이트로 구분된다) 0건을 요구한다.
  awk -v s="$r1b_s" -v e="$r2_s" '
    NR>s && NR<e {
      if ($0 ~ /^```/) { fence = !fence; if (fence) fb++; next }
      if (!fence) next
      line = $0; sub(/[[:space:]]*#.*$/, "", line)
      if (line ~ /^[[:space:]]*set -o pipefail[[:space:]]*$/) { pf=1; pf_fb=fb; pf_nr=NR }
      if (!inblk && index(line,"run-test-selection.sh\" assign")) {
        inblk=1; blk=line; blk_fb=fb; blk_nr=NR
      }
      else if (inblk) { blk = blk "\n" line }
      if (inblk && line !~ /\\$/) {
        inblk=0; n++
        if (!index(blk,"> \"$assign_rows_file.part\"")) bad++
        else if (!index(blk,"&& mv -f \"$assign_rows_file.part\" \"$assign_rows_file\"")) bad++
        else if (index(blk,"> \"$assign_rows_file\"")) bad++
        else if (index(blk,";")) bad++
        else if (!(pf && pf_fb == blk_fb && pf_nr < blk_nr)) bad++
      }
    }
    END { exit !(n > 0 && bad == 0 && pf) }' "$SKILL_MD" \
    || { echo "    R1b 의 assign 호출이 원자적 쓰기(.part → mv · 최종경로 직접 리다이렉트 0건 · 사슬 절단 0건 · 같은 블록의 선행 pipefail)를 갖지 않음(또는 코드가 아닌 산문)"; uc_ok=0; }
  # ② R8 의 게이트 호출 **블록 전체**가 두 대조 인자를 **각각 정확히 1회** 넘기고,
  #    그 종료코드를 **삼키지 않는다**. fenced 안만 본다 — 산문의 경로 언급이 블록
  #    시작으로 세어지면 위양성이 된다.
  #    ★ **맨-플래그 카운트(`--assign-rows ` 자체를 1회로)가 이 assert 의 이빨이다.**
  #      iteration 2 실측에서 ① 은 주석 공격에 뚫렸고 ② 는 살아남았는데, 차이는 정확히
  #      이 세 번째 검사였다 — 주석이 실어 나른 플래그가 개수를 2로 만들어 죽는다.
  #      같은 커밋에서 한쪽에만 넣은 idiom 이었다. ① 에도 주석 제거로 대응했다.
  #    ★ **`|` 0건**은 *집행자의 답을 버리는* 축이다(LT6/N1 실측: `|| true` 를 붙여도
  #      GREEN 이었다). 게이트를 옳은 입력에 배선해 놓고 종료코드를 버리면 §11 ㉓ 이 한
  #      스텝 하류에서 재현된다. `|| true`·`|| :` 를 **열거하지 않고** `|` 자체를 금지하는
  #      이유: 삼키는 idiom 은 열거가 안 되지만 파이프·OR-리스트는 `|` 없이 못 쓴다.
  #      알려진 위양성 하나를 **의도적으로 받는다** — `check_qa_ledger.py` 는 positional
  #      생략 시 stdin 을 읽으므로 언젠가 `cat … | check_qa_ledger.py …` 로 바꾸면 RED 다.
  #      그건 fail-closed seam 의 올바른 동작이다(조용한 변경 대신 의도적 락 편집 강제).
  #    ★ **그 "닫힌 술어" 주장은 거짓이었다 (/qg iter-8 iteration 3, F6 — codex 와
  #      silent-failure-hunter 가 서로 다른 모델 계열에서 독립 적발).** `;`-리스트와 `if`
  #      는 파이프도 OR-리스트도 아닌데 똑같이 삼킨다: `… ; true` · `if ! … ; then :; fi`
  #      · `… 2>/dev/null` 셋 다 `|` 0건이면서 GREEN 이었다(마지막 것은 라우팅 문장의
  #      "stderr 를 verbatim 으로 노출" 절반까지 죽인다). 열거를 늘리는 것은 답이 아니다
  #      — 세 번째 열거일 뿐이다. 대신 **구조**를 요구한다: 블록의 첫 줄이 (선행 공백
  #      뒤) `"${CLAUDE_PLUGIN_ROOT}` 로 시작하고(단순 명령 위치), 블록 안에 `;` 도 `|`
  #      도 0건. 백슬래시로 이어진 블록에서 명령을 단순-명령 자리 밖으로 빼내는 방법이
  #      그 둘뿐이라, 하나의 규칙이 `; true`·`|| true`·`if…then`·`! cmd`·명령치환을
  #      함께 죽인다. **`2>` 0건은 별개 축이다** — `cmd 2>/dev/null` 은 종료코드를 삼키지
  #      않지만 라우팅 문장이 요구하는 *"stderr 를 verbatim 으로 노출"* 을 죽인다(실측:
  #      위 세 술어만으로는 GREEN 이었다). 이 블록에서 stderr 리다이렉트는 어떤 형태든
  #      그 요구와 양립하지 않으므로 열거가 아니라 금지다.
  awk -v s="$r8_s" -v e="$r9_s" '
    function count(hay, needle,   c, i, n2) {
      c = 0; n2 = length(needle)
      while ((i = index(hay, needle)) > 0) { c++; hay = substr(hay, i + n2) }
      return c
    }
    NR>s && NR<e {
      if ($0 ~ /^```/) { fence = !fence; next }
      if (!fence) next
      line = $0; sub(/[[:space:]]*#.*$/, "", line)
      if (!inblk && index(line,"scripts/check_qa_ledger.py")) { inblk=1; blk=line; head=line }
      else if (inblk) { blk = blk "\n" line }
      if (inblk && line !~ /\\$/) {
        inblk=0; n++
        if (count(blk,"--aggregate \"$aggregate_yaml\"") != 1) bad++
        else if (count(blk,"--assign-rows \"$assign_rows_file\"") != 1) bad++
        else if (count(blk,"--aggregate ") != 1 || count(blk,"--assign-rows ") != 1) bad++
        else if (index(blk,"|") != 0) bad++
        else if (index(blk,";") != 0) bad++
        else if (index(blk,"2>") != 0) bad++
        else if (head !~ /^[[:space:]]*"\$\{CLAUDE_PLUGIN_ROOT\}/) bad++
      }
    }
    END { exit !(n > 0 && bad == 0) }' "$SKILL_MD" \
    || { echo "    R8 의 check_qa_ledger 호출 블록이 두 대조 인자를 각각 정확히 1회 넘기지 않거나, 종료코드를 삼킨다"; uc_ok=0; }
  # ③ 게이트의 **라우팅 문장**이 존재하고 극성이 뒤집히지 않았다 (양 + 음, LT6/N5 실측).
  #    ②(`|` 0건)는 코드가 종료코드를 *삼키는* 형태만 본다. 그 문장을 지우고 "결과를
  #    참고한다" 로 바꾸면 코드는 그대로인 채 집행이 권고가 된다 — 그것도 GREEN 이었다.
  #    **이 락의 사정거리를 정직하게 적는다: 문장의 *존재와 극성*을 지키지 *준수*를 재지
  #    않는다.** 준수는 어떤 정적 검사로도 못 잰다. 그렇다고 0을 택하면 삭제·반전이라는
  #    잴 수 있는 축까지 버리는 것이고, 이 브랜치는 "내 mutation 이 삭제 축만 흔들었다"로
  #    이미 한 번 물렸다. 형제 락(R5b 라우팅·재시도 방향)이 같은 양+음 모양을 쓴다.
  #    앵커는 **같은 줄 공기(co-occurrence)** 다 — `PASS 로 올리지 않는다` 단독은 이 창에서
  #    body-unique 가 아니라(`unclaimed` 인용 블록에도 있다) 문장을 지워도 GREEN 이 된다.
  #    ★ **부정 스캔은 창 전체가 아니라 그 문장 자기 줄이다 (/qg iter-8 iteration 3, F19).**
  #      창 전체 blacklist 는 두 방향으로 다 틀렸다: (a) 위양성 — R8 창에는 `per_adapter`
  #      개수를 읽기전용 진단이라 적는 정당한 줄이 이미 있어 "advisory" 한 단어면 RED 가
  #      된다(실측). (b) 위음성 — 문장을 지우지 않고 **그 줄 안에서** 약화하는 것이 이
  #      락이 지킨다는 바로 그 극성인데, 창 어디서든 세면 오히려 관계없는 줄에 반응한다.
  #      줄-스코프로 좁히면 두 축이 동시에 개선된다.
  #    ★ **정직한 한계 (실측된 생존, 닫지 않는다):** 문장을 그대로 두고 *뒤에 한 문장을
  #      덧붙여* ("다만 이것은 판단 재료일 뿐이며 최종 verdict 는 당신이 종합해 정한다")
  #      집행을 문서 수준에서 권고로 만드는 mutant 는 어떤 정적 검사로도 못 잡는다 —
  #      금지어를 하나도 안 쓰기 때문이다. 이 락은 *그 문장의 존재와 자기 줄의 극성*까지만
  #      지킨다. 금지어 목록을 늘리는 것은 세 번째 열거일 뿐 이 축을 닫지 못한다.
  awk -v s="$r8_s" -v e="$r9_s" '
    NR>s && NR<e {
      if (index($0,"non-zero 면") && index($0,"PASS 로 올리지 않는다")) {
        pos=1
        if ($0 ~ /참고한다|권고|advisory/) neg++
      }
    }
    END { exit !(pos && neg == 0) }' "$SKILL_MD" \
    || { echo "    R8 게이트의 'non-zero → PASS 불가' 라우팅 문장이 없거나 그 줄에서 권고로 약화됨"; uc_ok=0; }
  if [[ $uc_ok -eq 1 ]]; then
    echo "PASS: R1b 가 남기고 R8 이 --assign-rows 로 집행에 넘김 (∀ · fenced · 정확히 1회)"
  else
    echo "FAIL: R1b→R8 unclaimed 집행 사슬 (집행자가 셀 원본에 닿지 못한다)"
    fail=$((fail + 1))
  fi
fi

# ── T96 · AC69 — 중간 파일이 정말 트리 밖 한 디렉토리에 사는가 ────────────────────
# AC69 의 주장은 셋이다: (a) 여섯 역할 파일이 한 실행-스코프 디렉토리에 산다 ·
# (b) `$project_dir` 밖 · (c) `$evidence_dir` 밖. **(c) 는 (b) 의 부분집합이다** —
# `$evidence_dir = "$project_dir/.claude/quality-gates/<sid>/"` 이므로 금지는 실은 하나다.
#
# **앞 버전이 셋 다 못 쟀다 (iter-8 `/qg` 리뷰, 전부 실측 생존):**
#   · ① 이 ∃ 라 `mktemp` 줄을 남긴 채 뒤에 `qg_run_tmp="$PWD/..."` 를 덧붙이면 통과
#   · ② 가 **같은 줄** 조건이라 `tmproot="$project_dir/.qg"` 한 단계 간접이면 통과
#   · ② 가 토큰 열거라 `TMPDIR="$project_dir/.qg"` 는 아예 보이지 않는다
#   · ③ 이 ∃ + **하드코딩 6-이름 열거**라 일곱 번째 파일을 트리 안에 추가해도 통과
#   ★ 그리고 저자가 ② 의 이빨 증거로 보고한 mutation 은 실제로 ① 이 잡은 것이었다 —
#     ② 의 주장 축은 사실상 미측정이었다.
#
# 그래서 텍스트 락으로 닫을 수 있는 것과 없는 것을 나눈다. **간접은 텍스트로 못 막는다**
# — ④ 의 런타임 containment 가드가 유일하게 간접을 피할 수 없는 집행자이고, 아래 ①②③ 은
# 그 가드가 지워지거나 우회되는 *형태*를 잡는 보조다.
echo "== R-init 중간 파일 custody"
if [[ "$rinit_s" -le 0 || "$r1a_s" -le 0 || "$rt_end" -le 0 ]]; then
  echo "FAIL: 중간 파일 락 — 창 앵커 붕괴 (R-init=$rinit_s R1a=$r1a_s R9=$rt_end)"
  fail=$((fail + 1))
else
  loc_ok=1
  # ① **Runtime 절 전체**의 `qg_run_tmp=` 대입은 **정확히 1개**이고 RHS 가 `$(mktemp -d)` 다.
  #    개수를 세는 것이 재대입 축을 닫는다 (∃ 는 앞의 맞는 것으로 만족한다).
  #    창을 R-init..R1a 로 좁혔던 앞 버전은 **R1a 이후의 재-루팅을 못 봤다**(실측 생존:
  #    Step R4 의 코드 블록에 `qg_run_tmp="$project_dir/.qg"` 를 넣으면 네 sub-assert 가
  #    전부 GREEN — ③b 는 여섯 이름이 여전히 `$qg_run_tmp/` 파생이라 통과하고, 그 뿌리가
  #    이제 봉인 트리 안이다). ③b 를 절 전체로 넓히면서 ① 을 안 넓힌 **비대칭 자체가
  #    구멍**이었다. 런타임 가드는 도움이 안 된다 — 그것은 R-init 에서 원래 mktemp
  #    디렉토리를 상대로 이미 돌았다.
  #    ★ **극성이 둘이라 assert 도 둘이다.** ① 은 요구(뿌리가 `$(mktemp -d)` 로 *코드에*
  #      존재)와 금지(두 번째 대입이 *어디에도* 없음)의 결합이다. 한 덩어리로 두면 둘 중
  #      하나가 반드시 틀린 창을 쓴다 — 요구를 산문까지 세면 문서가 뿌리를 *말하기만* 해도
  #      통과하고(④ 가 뚫렸던 클래스), 금지를 코드로 좁히면 산문 재대입이 빠져나간다.
  # ①-req R-init 창의 **fenced 코드**에 RHS 가 `$(mktemp -d)` 인 대입이 ≥1건.
  awk -v s="$rinit_s" -v e="$r1a_s" '
    NR>s && NR<e {
      if ($0 ~ /^```/) { fence = !fence; next }
      if (!fence) next
      if ($0 ~ /^[[:space:]]*qg_run_tmp=\$\(mktemp -d\)/) ok=1
    }
    END { exit !ok }' "$SKILL_MD" \
    || { echo "    R-init 의 fenced 코드에 qg_run_tmp=\$(mktemp -d) 가 없음(산문만으로는 뿌리가 서지 않는다)"; loc_ok=0; }
  # ①-proh Runtime 절 전체(**산문 포함**)에 `qg_run_tmp=` 대입은 통틀어 1건.
  #        줄머리 앵커라 산문 문장 **안에** backtick 으로 인용된 `qg_run_tmp=` 는 세지
  #        않는다 — 그리고 정말로 대입 지시처럼 읽히는(줄머리에 오는) 산문 줄이라면
  #        RED 가 맞다(소비자가 산문도 실행하는 모델이다).
  #        ★ **실측된 탈출구, 닫지 않고 적는다 (/qg iter-8 iteration 3, F22):** 줄머리
  #          앵커라 `: ; qg_run_tmp="$project_dir"/.qg` 처럼 **줄 중간**에 두면 이 락도
  #          ③a 도(따옴표 위치가 달라 리터럴이 안 맞는다) 지나친다. 여섯 이름은 여전히
  #          `$qg_run_tmp/` 파생이라 ③b·③c 도 GREEN 이다. 이 축을 보는 것은 ④ 의
  #          런타임 가드뿐이고, 그래서 ④ 의 이빨이 이 파일에서 가장 중요하다.
  awk -v s="$rinit_s" -v e="$rt_end" '
    NR>s && NR<e && $0 ~ /^[[:space:]]*qg_run_tmp=/ { n++ }
    END { exit !(n == 1) }' "$SKILL_MD" \
    || { echo "    Runtime 절의 qg_run_tmp 대입이 정확히 1건이 아님(R1a 뒤 재-루팅 포함)"; loc_ok=0; }
  # ② Runtime 절 전체에 `TMPDIR=` 대입이 **0건**. `qg_run_tmp=` 를 키로 하는 어떤 규칙도
  #    이 축을 볼 수 없다 — mktemp 는 TMPDIR 을 존중하므로 이것이 실제 위치를 정한다.
  awk -v s="$rinit_s" -v e="$rt_end" '
    NR>s && NR<e && $0 ~ /(^|[[:space:];])TMPDIR=/ { bad=1 }
    END { exit bad }' "$SKILL_MD" \
    || { echo "    Runtime 절에 TMPDIR= 대입이 있음 — mktemp 의 실제 위치를 트리 안으로 옮길 수 있다"; loc_ok=0; }
  # ③a **값 기반 금지** — Runtime 절 전체에서(산문 포함) 중간 파일의 뿌리를 `$qg_run_tmp`
  #     **밖**으로 잡는 대입을 금지한다.
  #
  #     앞 버전은 "R-init 의 fenced 대입은 전부 `$qg_run_tmp/` 파생" 이라는 **도출된 ∀**
  #     였다. 그것이 이름 열거를 대체했지만 **문법 열거로 재현**했을 뿐이었다 — 대입을
  #     `^[[:space:]]*[a-z_][a-z0-9_]*=` 하나로만 인식해서 `export …` · 대문자 이름 ·
  #     줄 중간 대입 · **창 밖(뒤 스텝) 정의**가 전부 빠져나갔다(4종 실측 생존).
  #     정규식을 넓히는 것은 **세 번째 열거**가 된다: 셸 대입 문법은 무한해서(`declare`·
  #     `local`·`read -r`·배열·`printf -v`·간접 확장) 내가 쓰는 어떤 목록도 시간에
  #     fail-open 이고, 실제보다 강해 보이기만 한다. 그래서 **질문을 문법에서 값으로
  #     바꾼다** — 어떤 문법으로 쓰든 뿌리가 트리 안이면 걸린다.
  #
  #     이것이 닫는 것: 일곱 번째 파일을 `$project_dir`/`$evidence_dir`/`$sandbox_dir`/
  #     `$PWD` 아래에 잡는 모든 형태(`export`·대문자·줄 중간·뒤 스텝) + 두 번째 `mktemp`
  #     뿌리. 닫지 못하는 것: **새 변수를 경유한 한 단계 간접** — 그것은 ④ 의 런타임
  #     가드만 볼 수 있고, 그래서 ④ 가 ③a 보다 중요하다.
  #
  #     술어를 **주체(대입 이름·문법)에서 목적지(경로 뿌리)로 뒤집는다**: fenced 줄이
  #     `=` 를 담고 동시에 트리 안 뿌리를 담으면 걸린다. 대입 이름에도 문법에도 앵커하지
  #     않으므로 `export`·대문자·줄 중간·뒤 스텝 네 mutant 가 **한 술어로** 죽는다.
  #
  #     **fenced 를 유지해야 한다** — R5a¹ 의 산문이 `evidence_dir = "$project_dir/.claude/
  #     quality-gates/$CLAUDE_CODE_SESSION_ID/"` 파생을 **적법하게** 적기 때문이다. fence
  #     필터를 떼면 그 줄이 곧바로 위양성 RED 가 된다.
  #
  #     **줄 번호로 인용하지 않는다 (/qg iter-8 iteration 3, F13).** 앞 버전은 `:680`·
  #     `:1155`·`:1526` 세 줄을 근거로 댔는데 **셋 다 같은 커밋에서 어긋났고**, 특히
  #     `:680` 이 가리키던 `tmproot="$project_dir/.qg"` 산문은 그 커밋이 지워버렸다.
  #     남은 유일한 근거(위의 `evidence_dir` 산문)는 정작 이름이 불리지 않았다 — 즉
  #     `:680` 을 확인하러 간 편집자는 코드를 발견하고 "fence 필터는 불필요" 라고
  #     결론짓게 되어 있었다. 근거는 **무엇인지로** 적고 어디 있는지로 적지 않는다.
  #
  #     **닫히지 않는 것을 성과로 팔지 않는다**: `printf -v name "%s/.qg" "$project_dir"`
  #     나 `read -r name <<< …` 는 `=` 없이 같은 일을 한다. 이 술어는 무한 열거(대입 문법)
  #     를 훨씬 작고 부자연스러운 열거(`=` 없는 경로 구성 idiom)로 바꿀 뿐이고,
  #     **한 단계 간접은 여전히 ④ 의 런타임 가드만 본다.**
  awk -v s="$rinit_s" -v e="$rt_end" '
    NR>s && NR<e {
      if ($0 ~ /^```/) { fence = !fence; next }
      if (!fence) next
      if ($0 !~ /=/) next
      if ($0 ~ /"\$project_dir\// || $0 ~ /"\$evidence_dir\// \
          || $0 ~ /"\$sandbox_dir\// || $0 ~ /"\$PWD\//) bad=1
    }
    END { exit bad }' "$SKILL_MD" \
    || { echo "    Runtime 절 코드에 중간 파일 뿌리를 트리 안(\$project_dir·\$evidence_dir·\$sandbox_dir·\$PWD)으로 잡는 줄이 있음"; loc_ok=0; }
  # ③b **파일 이름 ∀** — 여섯 역할 *파일 이름*의 **모든** 출현이 `$qg_run_tmp/` 바로
  #    뒤에 온다. 창은 Runtime 절 전체.
  #
  #    **왜 변수 대입이 아니라 파일 이름인가.** 앞 버전은 `<이름>=` 대입을 셌고, 그래서
  #    *메커니즘*에 묶여 있었다 — 경로를 변수에 바인딩하는 판본만 잴 수 있고, 사용 지점에
  #    인라인하는 판본은 대입 0건이라 `c > 0` 에서 **락이 올바른 수정을 막는다**. 그 함정은
  #    이 파일이 이미 한 번 밟았다(창을 좁혀 4줄 RED). 파일 이름에 대한 ∀ 는 바인딩이든
  #    인라인이든 산문이든 동일하게 성립하므로 메커니즘 변경에 중립이다.
  #
  #    **그리고 이것이 러너 판별 축을 처음으로 잰다.** 앞 버전은 접두사만 봐서
  #    `expected_units_file="$qg_run_tmp/expected.txt"` — 즉 `-$runner` 판별자를 떨어뜨려
  #    **어댑터별 4종이 한 이름으로 붕괴하는** 원래 결함(CHANGELOG "4종이 한 이름으로
  #    붕괴했다")을 그대로 통과시켰다. 스위트 전체에 이 축의 락이 0건이었다.
  #
  #    극성: 금지 절반(`c == g`, 모든 출현이 파생)은 **산문까지** 덮고, 요구 절반
  #    (`f > 0`, 적어도 한 번은 코드)은 **fenced 안만** 본다. 요구까지 산문을 세면
  #    문서가 파일을 *말하기만* 해도 통과한다 — ④ 가 뚫렸던 바로 그 클래스다.
  #
  #    맨 접두사(`expected-`·`baseline-`·`head-`·`assign-rows`)는 쓰지 않는다:
  #    `--expected-adapters` · `baseline-cache` · `--head-mode` · `--assign-rows` 플래그와
  #    충돌해 위양성이 된다(실측). 전체 파일 이름으로 앵커한다.
  for tok in 'assign-rows.tsv' 'aggregate.yaml' 'expected-$runner.txt' \
             'baseline-$runner.tsv' 'head-$runner.tsv' 'per-adapter-$runner.yaml'; do
    awk -v s="$rinit_s" -v e="$rt_end" -v t="$tok" '
      function count(hay, needle,   c2, i, n2) {
        c2 = 0; n2 = length(needle)
        while ((i = index(hay, needle)) > 0) { c2++; hay = substr(hay, i + n2) }
        return c2
      }
      NR>s && NR<e {
        if ($0 ~ /^```/) { fence = !fence; next }
        c += count($0, t)
        g += count($0, "$qg_run_tmp/" t)
        if (fence) f += count($0, "$qg_run_tmp/" t)
      }
      END { exit !(c > 0 && c == g && f > 0) }' "$SKILL_MD" \
      || { echo "    파일 이름 '$tok' 의 출현 중 \$qg_run_tmp/ 파생이 아닌 것이 있음(또는 코드 출현 0건)"; loc_ok=0; }
  done
  # ③c **생산자 ∧ 소비자** — 여섯 파일마다 fenced 코드에 *쓰는* 자리와 *읽는* 자리가
  #    각각 있어야 한다.
  #
  #    **③b 로는 원리적으로 못 잡는다 (/qg iter-8 iteration 3, F1 — 리뷰어 4명 수렴).**
  #    ③b 는 *이름이 어디를 가리키는가*를 재지 *거기에 누가 쓰는가*를 재지 않는다. 그래서
  #    소비자만 있고 생산자가 0명인 파일이 `c == g` 도 `f > 0` 도 완벽히 만족한다 — 실제로
  #    이 브랜치의 **다섯 리비전 전부**에서 `expected-$runner.txt`·`baseline-$runner.tsv`·
  #    `head-$runner.tsv` 는 R6 의 읽기만 있고 쓰는 스텝이 하나도 없었는데 스위트는
  #    초록이었다. 정직한 실행은 `read_text_or_fail4` → `exit 4` 로 떨어진다.
  #
  #    **이 락이 없으면 그 수정도 지켜지지 않는다.** iteration 3 실측: 생산자 세 줄을 각각
  #    지운 mutant 가 셋 다 GREEN 이었다(③b 만 있을 때). 락이 안 흔들린다는 것은 그 락이
  #    대상을 구분하지 못한다는 증거다.
  #
  #    생산자의 정의는 **리다이렉트 대상**(`> "…"`)이다 — 문법이 아니라 위치라서
  #    `printf`·스크립트 stdout·`cat` 어느 것이 앞에 오든 동일하게 성립한다. 소비자는
  #    "리다이렉트 대상이 아닌 fenced 출현" 이다(인자 자리).
  #
  #    **창은 어댑터-스코프 세 파일이다 — 여섯 전부가 아니다.** 나머지 셋은 리터럴
  #    인라인 경로를 쓰지 않으므로 이 술어의 대상이 아니고, 각자 **이름 붙은 사슬
  #    assert 가 이미 있다**: `assign-rows.tsv` 와 `aggregate.yaml` 은 R-init 이
  #    오케스트레이터 변수로 바인딩해 스텝 사이로 들고 가는 설계라 사용 지점에 리터럴이
  #    없고, 그 생산자→소비자 사슬은 위의 "R1b 가 남기고 R8 이 --assign-rows 로 집행에
  #    넘김" · "R6 이 집계를 파일로 남기고 R8 이 그것을 --aggregate 로 대조에 넘김" 이
  #    잰다. `per-adapter-$runner.yaml` 은 생산자가 R6 의 리다이렉트이고 소비자가 glob
  #    (`per-adapter-*.yaml`, 다른 토큰)이라 이 술어로는 짝이 안 맞고, 아래 ③d 가
  #    그 소비 자리를 잰다. 세 파일만 남기는 것은 완화가 아니라 **갭이 실제로 있던
  #    자리에 락을 놓는 것**이다 — 이 셋이 다섯 리비전 내내 생산자 0명이었다.
  for tok in 'expected-$runner.txt' 'baseline-$runner.tsv' 'head-$runner.tsv'; do
    awk -v s="$rinit_s" -v e="$rt_end" -v t="$tok" '
      NR>s && NR<e {
        if ($0 ~ /^```/) { fence = !fence; next }
        if (!fence) next
        line = $0; sub(/[[:space:]]*#.*$/, "", line)
        p = "$qg_run_tmp/" t
        i = index(line, p)
        if (i == 0) next
        pre = substr(line, 1, i - 1)
        # 리다이렉트 대상이면 생산자, 아니면 소비자. `.part` 중간 파일도 생산자로 센다.
        if (pre ~ />[[:space:]]*"?$/) prod++
        else cons++
      }
      END { exit !(prod > 0 && cons > 0) }' "$SKILL_MD" \
      || { echo "    파일 '$tok' 에 fenced 생산자(리다이렉트 대상) 또는 fenced 소비자(인자)가 없음"; loc_ok=0; }
  done
  # ③d `--aggregate` 소비자가 **실제 생산물**을 세야 한다 — 모델이 적은 목록이 아니라.
  #    `per_adapter_yamls` 는 feature 커밋 이래 사용 1건·대입 0건인 이름이었고, 그것을
  #    되살리면 `--expected-adapters` 의 개수 대조가 *생산물 vs 기대* 가 아니라
  #    *모델이 적은 목록의 길이 vs 기대* 가 되어 대조 양쪽이 같은 출처에서 나온다.
  #    음의 락(그 이름 0건)에 **양의 짝**을 붙인다 — 집계 블록이 `$qg_run_tmp` 파생
  #    인자를 실제로 받는지까지 재야, 블록을 통째로 지우는 것이 통과 경로가 되지 않는다.
  awk -v s="$rinit_s" -v e="$rt_end" '
    NR>s && NR<e {
      if ($0 ~ /^```/) { fence = !fence; next }
      if (!fence) next
      line = $0; sub(/[[:space:]]*#.*$/, "", line)
      if (index(line,"per_adapter_yamls")) dead=1
      if (!inblk && index(line,"--aggregate") && index(line,"--expected-adapters") == 0) next
      if (index(line,"--expected-adapters")) {
        seen=1
        if (index(line,"$qg_run_tmp") || index(line,"${qg_run_tmp}")) rooted=1
      }
    }
    END { exit !(seen && rooted && !dead) }' "$SKILL_MD" \
    || { echo "    집계 호출이 \$qg_run_tmp 파생 생산물을 받지 않거나, 대입 없는 per_adapter_yamls 를 되살림"; loc_ok=0; }
  # ④ 런타임 containment 가드 — 텍스트가 못 보는 간접·TMPDIR 축의 유일한 집행자.
  #    `$evidence_dir ⊂ $project_dir` 이므로 `$project_dir` 담김 하나로 둘 다 잡힌다.
  #    **fenced + 주석 제거.** ④ 는 "가드가 코드로 존재한다"는 *요구*이므로 창이
  #    코드여야 한다 — 앞 버전은 unfenced `index()` 세 개였고, `case … esac` 를 통째로
  #    지운 뒤 산문 한 줄("양쪽에 `pwd -P` 를 쓰는 것은 symlink 우회를 막기 위해서다")만
  #    남겨도 GREEN 이었다(실측). **이 커밋이 산문-vs-코드 클래스의 답으로 추가한 assert
  #    자신이 그 클래스의 가장 순수한 사례였다.** 극성 규칙: 요구는 코드 안에 있어야
  #    하고(fence), 금지는 산문까지 덮어야 한다(no fence) — sub-assert 마다 따로 판단한다.
  #    ★ **해소(resolve)와 대조(compare)를 따로 잰다.** `head`·`pat` 만 재면 두 `pwd -P`
  #      해소 줄은 남기고 `case … esac` **대조만** 지운 mutant 가 통과한다(실측 생존) —
  #      그러면 경로를 정규화해 놓고 아무것도 비교하지 않는 가드가 남는다. `cmp` 가 그
  #      축이다: fenced 코드에 `project_dir` 과 glob 접미(`/*`)가 같은 줄에 있어야 한다
  #      (`case` 든 `[[ == ]]` 든 담김 비교는 이 모양을 피할 수 없다).
  #    ★ 정직한 한계: `PASS 불가` 는 이 창의 fenced 코드에 이미 여러 번 나오므로(mktemp
  #      실패 메시지 등) **이빨이 없다**. `r` probe 는 유지하되 집행 근거로 세지 않는다.
  #    ★ **모양이 아니라 동작을 잰다 (/qg iter-8 iteration 3, F4).** 앞 버전은 `head`·
  #      `pat`·`cmp` 세 probe 가 "실제 집행" 을 한다고 주석에 적었는데 **거짓이었다**:
  #      세 probe 는 전부 경로 *해소*와 비교 *모양*만 재므로, 리뷰어가 넣은 mutant 중
  #      (a) `case` 두 arm 을 뒤집기 (b) `exit 1` 을 `:` 로 바꾸기 (c) 담김 arm 을 통째
  #      no-op 로 만들기 (d) `case … esac` 를 지우고 `ls "$sealed_root"/*` 같은 decoy 를
  #      남기기 — 넷이 전부 GREEN 이었다(실측, 리뷰어 5명 중 3명이 독립 재현).
  #      `act` 가 그 축이다: **담김 패턴 줄과 `esac` 사이에 `exit` 이 있어야 한다.**
  #      가드 문법을 열거하지 않는 단일 술어이며 (a)~(d) 를 한 번에 죽인다. 한계는
  #      정직하게: `case` 가 아닌 `[[ == ]]` 모양으로 다시 쓰면 이 probe 는 RED 가
  #      된다(락 편집을 강제하는 fail-closed seam 이지 통과 경로가 아니다).
  #    ★ 기준 트리는 `$project_dir` 이 아니라 `$sealed_root` 다 (F10) — 봉인하는 쪽
  #      (`create-sandbox`)이 `--show-toplevel` 을 쓰므로 가드도 같은 트리를 봐야 한다.
  #      `pat` 은 그 파생이 `$project_dir` 에서 출발한다는 것까지 함께 잰다.
  awk -v s="$rinit_s" -v e="$r1a_s" '
    NR>s && NR<e {
      if ($0 ~ /^```/) { fence = !fence; next }
      if (!fence) next
      line = $0; sub(/[[:space:]]*#.*$/, "", line)
      if (index(line,"qg_run_tmp") && index(line,"pwd -P")) head=1
      if (index(line,"project_dir") && index(line,"rev-parse --show-toplevel")) pat=1
      if (index(line,"sealed_root") && index(line,"pwd -P")) res=1
      if (index(line,"sealed_root") && index(line,"/*")) { cmp=1; inarm=1 }
      if (inarm && index(line,"exit")) act=1
      if (inarm && index(line,";;")) inarm=0
      if (index(line,"-n \"$project_dir\"")) np=1
      if (index(line,"-n \"$sealed_root\"")) ns=1
      if (index(line,"PASS 불가")) r=1
    }
    END { exit !(head && pat && res && cmp && act && np && ns && r) }' "$SKILL_MD" \
    || { echo "    R-init 에 봉인-트리(\$sealed_root) 담김 런타임 가드(show-toplevel 파생 + pwd -P + 담김 비교 + 그 arm 안의 exit + 두 빈-값 검사)가 없음"; loc_ok=0; }
  if [[ $loc_ok -eq 1 ]]; then
    echo "PASS: 뿌리 1개·TMPDIR 0건·여섯 이름 ∀·런타임 담김 가드 (AC69)"
  else
    echo "FAIL: 중간 파일 custody (AC69 가 주장하는 위치가 지켜지지 않는다)"
    fail=$((fail + 1))
  fi
fi

# 새 라벨 5종이 실제로 존재하고 순서가 맞다
# 라벨은 **줄머리 볼드 헤딩**으로만 앵커한다. 맨 라벨로 찾으면 본문 cross-reference 가
# 먼저 잡힌다 — 실측: `first_line 'Step R5a⁰'` = **174**(다른 섹션의 참조), 실제 헤딩은
# **810**. 그러면 `r5a0 < r5a1` 순서 assert 가 "참조 < 헤딩"을 비교해 헤딩이 어디로
# 옮겨가도 통과하는 vacuous 락이 된다. 나머지 다섯은 지금 우연히 헤딩이 먼저일 뿐이므로
# 여섯 개 전부 같은 방식으로 못 박는다. (`\*` 금지 — 위 주석 참조.)
r5a0=$(first_line '^[*][*]Step R5a⁰'); r5a1=$(first_line '^[*][*]Step R5a¹')
r5a2=$(first_line '^[*][*]Step R5a²'); r5a3=$(first_line '^[*][*]Step R5a³')
r8=$(first_line '^[*][*]Step R8')
for pair in "R5a⁰:$r5a0" "R5a¹:$r5a1" "R5a²:$r5a2" "R5a³:$r5a3" "R8:$r8"; do
  assert_line "새 라벨 ${pair%%:*} 존재" "${pair#*:}"
done
assert_order "R5a⁰ precedes R5a¹" "$r5a0" "$r5a1"
assert_order "R5a¹ precedes R5a²" "$r5a1" "$r5a2"
assert_order "R5a² precedes R5a³" "$r5a2" "$r5a3"

# 기존 R-init 락이 검사하던 것(detect-runtime 실행)은 이제 R5a⁰ 의 책임이다.
# 두 겹 vacuous-pass 실측(수정 전), 둘 다 이제 막는다:
#   (a) $r5a0 이 0 이면(헤딩 실종) first_line_after 는 전체 파일을 처음부터
#       검색해 frontmatter 의 `detect-runtime.sh` 언급(:23)에 우연히 만족한다.
#   (b) $r5a0 이 유효해도 first_line_after 는 상한이 없어서, R5a⁰ 본문의
#       실제 호출을 지워도 R5a³ dispatch 프롬프트 안의 무관한 언급
#       (`manifest: <output of detect-runtime.sh>`, :879)에 만족해 버린다.
# 그래서 하한(R5a⁰)과 상한(R5a¹) 둘 다로 창을 좁힌다.
if [[ "$r5a0" -gt 0 && "$r5a1" -gt 0 ]] && \
   awk -v s="$r5a0" -v e="$r5a1" 'NR>s && NR<e && /detect-runtime/ {f=1} END{exit !f}' "$SKILL_MD"; then
  echo "PASS: R5a⁰ runs detect-runtime (window $r5a0..$r5a1)"
else
  echo "FAIL: R5a⁰ runs detect-runtime (heading missing or no in-window match; window $r5a0..$r5a1)"
  fail=$((fail + 1))
fi

# ── T1 / AC1 / AC2 / M3: 앵커 이전 ──
echo "== transparency 앵커 이전"
old_literal=$(grep -cF 'regardless of Review scope' "$SKILL_MD" || true)
if [[ "$old_literal" -eq 0 ]]; then
  echo "PASS: 구 리터럴 'regardless of Review scope' 0회"
else
  echo "FAIL: 구 리터럴이 ${old_literal}회 잔존"; fail=$((fail + 1))
fi
new_anchor='이번 변경의 영향분만 기준선 대비로 돌린다'
anchor_count=$(grep -cF "$new_anchor" "$SKILL_MD" || true)
if [[ "$anchor_count" -eq 1 ]]; then
  echo "PASS: 신 앵커 정확히 1회"
else
  echo "FAIL: 신 앵커가 ${anchor_count}회 (정확히 1회여야 함)"; fail=$((fail + 1))
fi
# 앵커는 R2(계획 산문)와 R3(갭 게이트) 사이에 있어야 한다
anchor_line=$(first_line "$new_anchor")
# awk 패턴에 `\*` 를 쓰지 않는다 — `-v` 가 백슬래시를 떼어내 `**…` 가 되고, 그러면
# `illegal primary in regular expression` 으로 매치 0건이 된다(실측: awk 20200816).
# `^` 가 앞에 붙으면 이 awk 의 관대한 처리로 *우연히* 통과할 뿐이라 `[*]` 로 못 박는다.
r2_marker=$(first_line '^[*][*]Step R2'); r3_marker=$(first_line '^[*][*]Step R3')
if [[ -n "$anchor_line" && "$anchor_line" -gt "$r2_marker" && "$anchor_line" -lt "$r3_marker" ]]; then
  echo "PASS: 앵커가 Step R2($r2_marker)와 Step R3($r3_marker) 사이 ($anchor_line)"
else
  echo "FAIL: 앵커 위치 ($anchor_line, R2=$r2_marker R3=$r3_marker)"; fail=$((fail + 1))
fi

# ── T22 / AC31 / M12: 호출 주체 — run-test-selection.sh 가 verifier dispatch 블록 밖 ──
echo "== 호출 주체 불변식"
r5b=$(first_line '^[*][*]Step R5b')   # 헤딩 앵커 — cross-reference latch 방지
# 형제 창(R5a⁰..R8)들과 달리 여기엔 존재 가드가 없었다. `$r5b` 가 0 이면 아래 창 조건
# `n < $r5b` 가 산술 컨텍스트에서 0 과 비교돼 **항상 거짓** → in_block 이 0 으로 남아
# 락 전체가 vacuous PASS 가 된다. 헤딩 리네임 한 번으로 무력화되는 구멍이라 막는다.
assert_line "Step R5b 헤딩 존재 (창 붕괴 방지)" "$r5b"
in_block=0
while IFS= read -r ln; do
  n="${ln%%:*}"
  if [[ "$n" -gt "$r5a3" && "$n" -lt "$r5b" ]]; then in_block=$((in_block + 1)); fi
done < <(grep -n 'run-test-selection.sh' "$SKILL_MD")
if [[ "$in_block" -eq 0 ]]; then
  echo "PASS: run-test-selection.sh 호출이 verifier dispatch 블록(R5a³..R5b) 안에 0회"
else
  echo "FAIL: verifier dispatch 블록 안에서 run-test-selection.sh 호출 ${in_block}회"
  fail=$((fail + 1))
fi
if grep -qF '이 호출 결과가 authoritative' "$SKILL_MD"; then
  echo "PASS: authoritative 문장 존재"
else
  echo "FAIL: authoritative 문장 부재"; fail=$((fail + 1))
fi

# ── 폴백에서 R5b 미실행 (실제 워킹 트리 보호) ──────────────────────────────
# 고친 결함: 폴백은 `runtime_project_dir = project_dir`(사용자의 실제 repo)로 두는데
# R5b 만 샌드박스 가용성 조건이 없어서, `npm ci`/`uv sync --frozen`/`venv+pip` 가 사용자
# 트리에서 돌았다. R7 폴백 신호는 `--porcelain` 기반이라 git-ignored 인 `.venv`/
# `node_modules` 를 **구조적으로** 볼 수 없어 경고조차 못 냈다.
#
# 락을 창(R5b..R6)으로 좁히는 이유: `sandbox_dir` 은 파일 전체에 8회(R0·R4 등) 나오므로
# 전체 파일 grep 은 R5b 본문에서 게이트를 통째로 지워도 통과한다. 창 안에서는 이 게이트가
# 유일한 출처다(실측: 창 내 `sandbox_dir` 1회, `SILENT_DROP` 1회).
echo "== 폴백 R5b 미실행"
r6_marker=$(first_line '^[*][*]Step R6')
assert_line "Step R6 헤딩 존재 (창 상한)" "$r6_marker"

# ── /qg iter-2 G1·G5: 이 락은 **극성**과 **지시 vs 산문**을 구분하지 못했다 ──────────
# 이전 형태는 창 안에 `sandbox_dir`·`unrun`·`SILENT_DROP` 이 **각각 어딘가에** 있는지만
# 봤다(독립 존재 검사 3개를 AND). 실측된 두 구멍:
#
#   G1 (criticality 9) — `sandbox_dir 가 UNSET 이면` → `SET 이면` 한 단어 반전이 GREEN.
#      뒤집힌 지시는 샌드박스가 **있을 때** R5b 를 건너뛰고 UNSET 일 때 실행한다 — 즉
#      정확히 사용자의 실제 워킹 트리에서 `npm ci`/`uv sync`/`venv` 를 돌린다. 워킹 트리
#      파괴를 막으려고 쓴 락이 술어 반전을 살아남으면 아무것도 지키지 않는다.
#   G5 (6) — `unrun` 이 창 안에 2회 나온다: 실제 지시(`<unit>\tunrun\t-`)와 **근거 산문**
#      ("HEAD 축 `unrun` 은 … SILENT_DROP 으로 라우팅돼"). 지시를 지우고 산문만 남기면 GREEN.
#
# 그래서 (a) 조건과 극성을 **같은 줄에서** 요구하고, (b) 반대 극성이 0회임을 요구하고,
# (c) `unrun` 은 산문에 없는 **지시 고유 형태**(`unrun\t-`)로 잰다.
polarity_ok=0; polarity_bad=0; rec_ok=0; route_ok=0; route_stale=0
while IFS= read -r line; do
  case "$line" in
    *sandbox_dir*UNSET*) polarity_ok=1 ;;
    *sandbox_dir*SET*)   polarity_bad=$((polarity_bad + 1)) ;;   # UNSET 은 위에서 이미 소비됨
  esac
  case "$line" in *'unrun\t-'*)   rec_ok=1 ;; esac
  # /qg iter-6 D3: 이 락은 원래 리터럴 `SILENT_DROP` 을 요구했다. 그런데 SR4 이후
  # 폴백에서는 **R4 도 건너뛰어 기준선 축까지 전량 `unrun`** 이므로 쌍은 항상
  # `(U,U) → BASELINE_UNRUNNABLE` 이다 — 즉 락이 **도달 불가능한(=틀린) 사실을
  # 방어**하고 있었고, 산문을 옳게 고치면 스위트가 red 가 되는 상태였다.
  # 락을 지우면 G5 보호가 사라지므로, 정정된 라우팅 주장으로 **재조준**한다.
  case "$line" in *'(U,U)'*BASELINE_UNRUNNABLE*) route_ok=1 ;; esac
  # 옛 주장의 재도입 차단. /qg iter-6 iteration 2 (I1): 앞선 판본은 `(P,U)` **한 표기만**
  # 핀했는데, 같은 문서 R4 절(:798)이 같은 규칙을 `(F,U)`/`(A,U)` 로도 적고 있어 그 표기로
  # 되살리면 통과했다(mutation 실측 GREEN). 드리프트 소스가 문서 안에 있는데 락이 한 셀만
  # 봤다 — 내 mutation 이 락의 전제를 공유한 전형. 창 안에서 `SILENT_DROP` 자체를 금지한다:
  # 정정된 산문은 이 창에서 그 토큰을 쓰지 않는다.
  case "$line" in *SILENT_DROP*) route_stale=1 ;; esac
done < <(awk -v s="$r5b" -v e="$r6_marker" 'NR>s && NR<e' "$SKILL_MD")

if [[ "$r5b" -gt 0 && "$r6_marker" -gt 0 && "$polarity_ok" -eq 1 && "$polarity_bad" -eq 0 \
      && "$rec_ok" -eq 1 && "$route_ok" -eq 1 && "$route_stale" -eq 0 ]]; then
  echo "PASS: R5b 폴백 게이트 — sandbox_dir+UNSET 동일 줄 · 반대 극성 0회 · unrun 지시형 · (U,U)→BASELINE_UNRUNNABLE · 옛 주장 0회 (창 $r5b..$r6_marker)"
else
  echo "FAIL: R5b 폴백 게이트 (polarity_ok=$polarity_ok polarity_bad=$polarity_bad rec=$rec_ok route=$route_ok stale=$route_stale 창 $r5b..$r6_marker)"
  fail=$((fail + 1))
fi

# 거짓이던 배너 문구의 재도입 방지. 이 문구는 R5b 가 실제 트리에서 설치·테스트를 돌리는
# 동안 "read-only" 라고 주장해 사용자를 오도했다 — 되돌아오면 즉시 빨개져야 한다.
stale_readonly=$(grep -cF 'read-only smoke mode on the real tree' "$SKILL_MD" || true)
if [[ "$stale_readonly" -eq 0 ]]; then
  echo "PASS: 거짓 배너 'read-only smoke mode on the real tree' 0회"
else
  echo "FAIL: 거짓 배너 재도입 ${stale_readonly}회 — 폴백은 read-only 가 아니다(verifier 가 Write 보유)"
  fail=$((fail + 1))
fi

if [[ "$fail" -eq 0 ]]; then
  echo "test_skill_orchestration_behavior: all protocol-shape assertions PASS"
  exit 0
else
  echo "test_skill_orchestration_behavior: $fail assertion(s) FAILED"
  exit 1
fi
