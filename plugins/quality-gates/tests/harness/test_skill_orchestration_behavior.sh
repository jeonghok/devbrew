#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/*/SKILL.md plugins/quality-gates/skills/quality-pipeline/references/differential-test.md plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/agents/security-reviewer.md plugins/quality-gates/agents/code-recritic.md plugins/quality-gates/references/recritic-code-profile.md plugins/quality-gates/tests/lib/reconstruct-skill.sh
# test_skill_orchestration_behavior.sh — protocol-shape test for SKILL.md.
#
# 위 `# guards:` 는 이 파일이 실제로 여는 것에서 도출했다 — quality-pipeline/SKILL.md 는
# `plugins/quality-gates/skills/*/SKILL.md` 로 잡히고(case 에서 `*` 는 `/` 를 넘으므로 다른
# skill 의 SKILL.md 도 함께 잡힌다 — 아래 major-버전 대조가 그 전량을 읽는다),
# references/differential-test.md 는 reconstruct-skill.sh 가 SKILL.md 포인터 자리에 되접어
# 넣는 그 파일, plugin.json 은 major 판독 대상, security-reviewer.md 는 verifier-writable
# 페르소나 검사 대상, code-recritic.md 는 #104 tools 포스처 검사 대상,
# references/recritic-code-profile.md 는 재비판 프로필의 verifier-writable 검사 대상이다.
# tests/lib/reconstruct-skill.sh 도 코퍼스다 — 이 락의 모든 단언이 읽는 문서(`$SKILL_MD`)를
# 만드는 라이브러리라, 그 파일만 고쳐도(예: 스플라이스 헤딩 매칭이 깨져도) 이 락이 후보에
# 떠야 한다. `.`(source) 는 「읽는 것」 이다 — bash 가 그 파일의 바이트를 읽고 해석한다.
# 줄번호로 적지 않는다 — 이 헤더가 늘 때마다 그 인용이 밀린다.
#
# 이 목록 밖의 파일은 이 스크립트가 열지 않는다 — 아래 경로 변수들과 reconstruct-skill.sh 의
# `source` 한 자리의 사용처를 정독해 확인한다. `"\$X_DIR"` 꼴 정규식으로 전수 확인하지 않는다:
# 변수 뒤에 경로가 더 붙는 줄(이 파일의 `. "$SCRIPT_DIR/../lib/reconstruct-skill.sh"`)을
# 구조적으로 놓친다.
#
# `--emit-scanned` — test_guards_coverage_bidirectional.sh 가 읽는다. 실제로 읽는 경로를
# 낸다: 가로채지 않으면 스위트가 그대로 돌아 단언 텍스트가 경로로 읽혀 커버리지 락이 거짓
# FAIL 을 내고, 빈 응답을 내면 그 락이 이 파일을 영원히 「미지원」 으로만 본다(빈 응답은 아무
# 경로도 스캔하지 않는 그 검사기 자신에게만 사실이다). 본 실행이 읽는 것과 같은 명령
# (`find "$SKILLS_ROOT" -maxdepth 2 -name 'SKILL.md'`)을 재사용해 드리프트 여지를 없앤다.
# `differential-test.md` 는 awk `getline` 내부 읽기라 인자로는 안 나타나지만 실제로 읽힌다.
if [ "${1:-}" = "--emit-scanned" ]; then
  _SOB_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  _SOB_QG_ROOT="$(cd -- "$_SOB_SCRIPT_DIR/../.." && pwd)"
  _SOB_REPO_ROOT="$(cd -- "$_SOB_QG_ROOT/../.." && pwd)"
  _SOB_REL="${_SOB_QG_ROOT#"$_SOB_REPO_ROOT"/}"
  printf '%s\n' \
    "$_SOB_REL/skills/quality-pipeline/references/differential-test.md" \
    "$_SOB_REL/.claude-plugin/plugin.json" \
    "$_SOB_REL/agents/security-reviewer.md" \
    "$_SOB_REL/agents/code-recritic.md" \
    "$_SOB_REL/references/recritic-code-profile.md" \
    "$_SOB_REL/tests/lib/reconstruct-skill.sh"
  find "$_SOB_QG_ROOT/skills" -maxdepth 2 -name 'SKILL.md' | sort | while IFS= read -r _sob_f; do
    printf '%s\n' "${_sob_f#"$_SOB_REPO_ROOT"/}"
  done
  exit 0
fi
#
# Asserts the prompt-defined orchestration protocol exists in SKILL.md with
# expected ordering, proximity, and section membership. Does NOT execute
# SKILL.md at runtime; this is a STATIC protocol-shape verifier. Anchors are
# body text that actually appears — a substring grep for a token that never
# appears has an unreachable negative path (tautological PASS).
#
# Coverage (spec §5.6.9):
#   - Step 3.5 code-recritic dispatch + both angle agents (code-recritic · security-reviewer) in the fan-out
#   - Lowered-findings gate AskUserQuestion within proximity of the Step 4.5 head
#   - SKILL title major == plugin.json major (every skills/*/SKILL.md)
#   - verifier-writable checks in the security-reviewer persona and the re-critic code profile
#   - code-recritic dispatch shape (profile before the fence · diff slot · fail-closed · zero-findings clause · format-patch ban)
#   - Surface findings (Step 4.5) precedes the lowered-findings decision question
#   - check-review-scope.sh invoked · review-scope ownership honesty norm · degraded scope advisory
#   - changes-exist floor (scope-empty) and the removed routing surface staying gone
#   - NG6: allowed-tools has no Skill
#   - differential-procedure anchors (scope note between D2 and D3 · authoritative sentence · false banner absent)

set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILL_MD_REAL="$(cd -- "$SCRIPT_DIR/../.." && pwd)/skills/quality-pipeline/SKILL.md"

test -f "$SKILL_MD_REAL" || { echo "FAIL: SKILL.md not found at $SKILL_MD_REAL"; exit 1; }

# 차등 테스트 절차 전문은 references/differential-test.md 에 있다. 이 파일의 검사는 한
# SKILL.md 를 줄 번호로 분석하므로, 그 파일을 포인터 자리에 되접은 논리적 문서를 재구성해
# 그 위에서 돈다 — 그래야 차등 절차(D0~D8)의 앵커가 잡힌다. 재구성 실패(포인터 소실 등)는
# 조용히 원본으로 폴백하지 않고 FAIL 한다.
. "$SCRIPT_DIR/../lib/reconstruct-skill.sh"
if ! SKILL_MD="$(reconstruct_skill_md "$SKILL_MD_REAL")"; then
  echo "FAIL: SKILL.md ↔ references/differential-test.md 재구성 실패 (아래 모든 검사가 공허해질 것을 막기 위해 중단)"
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
review_line=$(first_line 'subagent_type.*quality-gates:code-recritic')
assert_line "Step 3.5 재비판 dispatch (code-recritic)" "$review_line"

# 각도 수행자 2종이 fan-out 에 있다 (재비판 · 보안).
for agent in code-recritic security-reviewer; do
  if grep -qE "subagent_type[^\"]*\"quality-gates:$agent" "$SKILL_MD"; then
    echo "PASS: $agent dispatch present"
  else
    echo "FAIL: $agent dispatch missing"
    fail=$((fail + 1))
  fi
done

# 한 실행의 결정 도구 — Step 4.5 의 낮춘 지적 게이트 — 가 그 절 머리 가까이에 있다.
# 60 을 올리지 않는다: 상한을 올리는 것은 이 근접성 sanity 를 무디게 하는 것이다.
surface_head_line=$(first_line '^### Step 4\.5 — Surface the verdict$')
assert_line "Step 4.5 절 앵커" "$surface_head_line"
askuser_review_line=$(first_line_after 'AskUserQuestion[(][{]' "$surface_head_line")
assert_proximity "lowered gate AskUserQuestion near Step 4.5 head" "$surface_head_line" "$askuser_review_line" 60

# SKILL 제목의 버전이 **shipped major 와 일치**한다 — 이 플러그인의 모든
# skills/*/SKILL.md 에 대해. 한 파일만 보는 락은 나머지에 구조적으로 눈이 먼다 —
# 버전을 단 다른 SKILL 이 plugin.json bump 뒤에도 제목에 구버전을 그대로 달고 있는 것을
# 못 잡는다.
#
# 음의 락: 버전을 단 제목은 전부 major 가 shipped 와 같아야 한다. 버전이
# 아예 없는 제목(artifact-critique)은 위반이 아니다 — 무버전 제목은 애초에
# stale 해질 수 없는 모양이라 legal 로 둔다. major 만 재고 minor/patch 는 풀어
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

# --- Law-3 persona hardening (a bypass escaped when reviewers trusted a
#     verifier-writable artifact; the persona now forces that check).
#     Anchor on the stable literal `verifier-writable`, which the security-reviewer
#     persona AND the re-critic code profile include verbatim. ---
AGENTS_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)/agents"
REFERENCES_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)/references"
for p in security-reviewer; do
  if grep -qi 'verifier-writable' "$AGENTS_DIR/$p.md"; then
    echo "PASS: $p persona has the verifier-writable-artifact check"
  else
    echo "FAIL: $p persona missing the verifier-writable-artifact check"
    fail=$((fail + 1))
  fi
done
if grep -qi 'verifier-writable' "$REFERENCES_DIR/recritic-code-profile.md"; then
  echo "PASS: re-critic code profile has the verifier-writable-artifact check (moved from adversarial persona, PR4a R-Q)"
else
  echo "FAIL: re-critic code profile missing the verifier-writable-artifact check (moved from adversarial persona, PR4a R-Q)"
  fail=$((fail + 1))
fi
# code-recritic is qg's own re-critic persona — this re-checks the #104 tools
# posture this SKILL's prose claims for it.
if grep -qE '^tools:[[:space:]]*Read,[[:space:]]*Grep,[[:space:]]*Glob$' "$AGENTS_DIR/code-recritic.md"; then
  echo "PASS: code-recritic persona keeps #104 tools posture (Read, Grep, Glob)"
else
  echo "FAIL: code-recritic persona tools posture changed from Read, Grep, Glob (#104 lock)"
  fail=$((fail + 1))
fi

# --- Step 3.5 재비판 dispatch protocol-shape ---
# recritic-code-profile.md must appear within 30 lines BEFORE the code-recritic
# dispatch line (the Step 3.5 `cat .../recritic-code-profile.md` fence sits
# ~16 lines ahead of the Agent({...}) fence) — an "after" window would be RED.
if [[ "$review_line" -gt 0 ]]; then
  recritic_win_start=$((review_line - 30))
  [[ "$recritic_win_start" -lt 1 ]] && recritic_win_start=1
  if awk -v s="$recritic_win_start" -v e="$review_line" \
      'NR>=s && NR<e && /recritic-code-profile\.md/ {f=1} END{exit !f}' "$SKILL_MD"; then
    echo "PASS: recritic-code-profile.md referenced within 30 lines before code-recritic dispatch"
  else
    echo "FAIL: recritic-code-profile.md not found within 30 lines before code-recritic dispatch (line $review_line)"
    fail=$((fail + 1))
  fi
else
  echo "FAIL: recritic-code-profile.md proximity check skipped — no code-recritic dispatch line"
  fail=$((fail + 1))
fi

# The code-recritic dispatch fence must carry the <diff>${DIFF}</diff> slot —
# the code path threads diff (test_agent_input_slots.sh cannot see this: the
# shared contract declares `diff` optional).
if [[ "$review_line" -gt 0 ]] && awk -v s="$review_line" -v e="$((review_line + 15))" \
    'NR>=s && NR<=e && index($0, "<diff>${DIFF}</diff>") {f=1} END{exit !f}' "$SKILL_MD"; then
  echo "PASS: code-recritic dispatch fence carries <diff>\${DIFF}</diff> slot"
else
  echo "FAIL: code-recritic dispatch fence missing <diff>\${DIFF}</diff> slot"
  fail=$((fail + 1))
fi

# The disposition line on the code-recritic dispatch must be fail-closed (R-R) —
# the only place that measures R-R is actually true.
if [[ "$review_line" -gt 0 ]] && awk -v s="$review_line" -v e="$((review_line + 5))" \
    'NR>=s && NR<=e && /fail-closed/ {f=1} END{exit !f}' "$SKILL_MD"; then
  echo "PASS: code-recritic disposition line is fail-closed (R-R)"
else
  echo "FAIL: code-recritic disposition line missing fail-closed (R-R)"
  fail=$((fail + 1))
fi

# AC17 — re-critic dispatches even when detection produced zero findings, and
# that clause precedes the dispatch fence itself.
phase15_zero_line=$(first_line '탐지 결과가 0건이어도 디스패치한다')
assert_line "Step 3.5 dispatches even when detection has zero findings (AC17)" "$phase15_zero_line"
assert_order "AC17 zero-findings clause precedes code-recritic dispatch" "$phase15_zero_line" "$review_line"

# The recritic.diff instructions must forbid git show/format-patch/log -p output,
# backed by a body-unique rationale line (not header-satisfiable). Anchor on
# `git format-patch` AND the negation `쓰지 않는다` together — a bare
# `git format-patch` existence check doesn't lock the prohibition itself: someone
# could delete "쓰지 않는다" (turning the sentence into something else, or even
# permissive) while `git format-patch` still appears elsewhere on the line/file,
# and an existence-only anchor would stay GREEN.
gitshow_line=$(first_line 'git format-patch.*쓰지 않는다')
assert_line "recritic diff prohibits git show/format-patch/log -p output" "$gitshow_line"
if [[ "$gitshow_line" -gt 0 ]] && awk -v s="$gitshow_line" -v e="$((gitshow_line + 3))" \
    'NR>=s && NR<=e && index($0, "커밋 메시지") {f=1} END{exit !f}' "$SKILL_MD"; then
  echo "PASS: git-show prohibition backed by body-unique 커밋 메시지 rationale (not header-satisfiable)"
else
  echo "FAIL: git-show prohibition missing body-unique 커밋 메시지 rationale"
  fail=$((fail + 1))
fi

# --- Review-gate findings surfaced before the decision tool ---
# The Surface-findings step (Step 4.5) must precede the remaining decision
# tool's question (the lowered-findings gate). Anchor on the surface-step TEXT,
# NOT the `## Review` section heading — a heading always precedes its
# body, so a heading anchor is a tautological PASS. Existence grep alone cannot
# catch mis-placement.
surface_line=$(first_line 'Surface findings|Step 4\.5')
question_line=$(first_line 'question: "재비판이 심각도를 낮춘 지적')
assert_line "Surface-findings step present" "$surface_line"
assert_line "lowered-findings decision question present" "$question_line"
assert_order "Surface findings precedes lowered-findings decision" "$surface_line" "$question_line"

# --- §5.2-5.4: changes-exist floor (verdict integrity) ---
# check-review-scope.sh still invoked in the Review gate (call+cache for the floor).
assert_line "check-review-scope.sh invoked" "$(first_line 'check-review-scope.sh')"

# AC12: the model-owned routing honesty norm is present.
assert_line "review-scope ownership honesty norm present" "$(first_line 'You own review-scope resolution')"

# AC5: the floor (a row in Step 4's 판정 입력 table) keys on the two deterministic
# inputs — the resolved scope file count AND the script-emitted changes_exist.
# Anchor BOTH conditions on a SINGLE line: 'changes_exist == yes' also appears on
# the honesty-norm line, so a lone `first_line 'changes_exist == yes'` would match
# there and pass even if the floor row itself regressed. The combined
# 'resolved_scope_file_count == 0 …changes_exist == yes' pattern is unique to the
# floor row; the glue between the two conditions is not pinned to a literal "AND".
assert_line "floor keyed on resolved_scope_file_count == 0 AND changes_exist == yes" \
  "$(first_line 'resolved_scope_file_count == 0.*changes_exist == yes')"
# The reason token must sit on the floor row itself: an anchor that also matches
# the honesty-norm quote line stays GREEN when the floor row alone is deleted. Tie
# it to the SAME line as the check above (unique to the floor row — the
# honesty-norm line lacks the literal `resolved_scope_file_count == 0` token).
assert_line "honest floor label present" \
  "$(first_line 'resolved_scope_file_count == 0.*changes_exist == yes.*scope-empty')"

# AC6: degraded signal still emits a loud fail-open advisory.
assert_line "degraded scope advisory present" "$(first_line 'scope check degraded')"

# The floor speaks through the closed reason token `scope-empty`, which appears in the
# Step 1b intro + the honesty-norm quote + Step 4's floor row → at least 3
# occurrences.
floor_count=$(grep -cF 'scope-empty' "$SKILL_MD" || true)
if [[ "$floor_count" -ge 3 ]]; then
  echo "PASS: honest floor label (scope-empty) in intro + honesty norm + floor row ($floor_count)"
else
  echo "FAIL: honest floor under-applied (found $floor_count, need >=3)"
  fail=$((fail + 1))
fi

# --- negative guards: the removed routing surface must be GONE ---
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

# --- NG6 ---
# 자기 변수(ng6_block)로 독립 도출한다: 다른 섹션의 변수를 빌려 쓰면 그 섹션이 지워질 때
# 이 검사도 함께 죽는다.
#
# allowed-tools: 키부터, 다음 top-level frontmatter 키(들여쓰기 없고 '-'로도
# 시작하지 않는 줄) 또는 frontmatter 닫는 '---' 중 먼저 오는 것 앞까지를 뽑는다.
ng6_block="$(awk '/^allowed-tools:/{f=1;next} f&&/^---$/{exit} f&&/^[^ -]/{exit} f{print}' "$SKILL_MD")"

# 양성 증인 먼저 — 도출한 블록이 비어 있지 않고, 알려진 항목(사전 검사 줄)을
# 담는다. 이게 없으면 앵커가 죽어 $ng6_block 이 빈 문자열이 될 때 아래 부재
# 단언이 공허참으로 통과한다.
if [[ -n "$ng6_block" ]] && grep -qF 'entry_preflight.py" quality-gates quality-pipeline' <<<"$ng6_block"; then
  echo "PASS: NG6 양성 증인 — allowed-tools 블록 도출 유효(사전 검사 항목 확인)"
else
  echo "FAIL: NG6 양성 증인 실패 — allowed-tools 블록 도출이 비었거나 앵커가 죽음"; fail=$((fail+1))
fi

# 부재 — allowed-tools 에 standalone `Skill` 항목이 없다 (no skill-nesting).
if grep -qE '^[[:space:]]*-[[:space:]]*Skill[[:space:]]*$' <<<"$ng6_block"; then
  echo "FAIL: quality-pipeline allowed-tools contains Skill (NG6 violation)"; fail=$((fail+1))
else
  echo "PASS: quality-pipeline allowed-tools has no Skill (NG6)"
fi

# ── 범위 투명성 앵커 — 옛 리터럴 부재 · 새 앵커 정확히 한 번 · D2 와 D3 사이 ──
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
# 앵커는 D2(후보와 배정 — 범위 공지)와 D3(HEAD 축 실행) 사이에 있어야 한다.
# 두 헤딩이 없으면 0 이 되어 아래 비교가 실패한다(창 붕괴가 통과로 읽히지 않는다).
anchor_line=$(first_line "$new_anchor")
d2_marker=$(first_line '^## D2 '); d3_marker=$(first_line '^## D3 ')
if [[ "$d2_marker" -gt 0 && "$d3_marker" -gt "$d2_marker" && "$anchor_line" -gt "$d2_marker" && "$anchor_line" -lt "$d3_marker" ]]; then
  echo "PASS: 앵커가 D2($d2_marker)와 D3($d3_marker) 사이 ($anchor_line)"
else
  echo "FAIL: 앵커 위치 ($anchor_line, D2=$d2_marker D3=$d3_marker)"; fail=$((fail + 1))
fi

# ── 호출 주체 불변식 — 차등 절차 머리말의 authoritative 문장 ──
echo "== 호출 주체 불변식"
if grep -qF '이 호출 결과가 authoritative' "$SKILL_MD"; then
  echo "PASS: authoritative 문장 존재"
else
  echo "FAIL: authoritative 문장 부재"; fail=$((fail + 1))
fi

# 거짓이던 배너 문구의 재도입 방지. 이 문구는 옛 절차가 실제 트리에서 설치·테스트를 돌리는
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
