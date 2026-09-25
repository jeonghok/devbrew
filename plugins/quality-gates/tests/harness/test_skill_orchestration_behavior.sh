#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/*/SKILL.md plugins/quality-gates/skills/quality-pipeline/references/differential-test.md plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/agents/security-reviewer.md plugins/quality-gates/agents/doc-recritic.md plugins/quality-gates/references/recritic-code-profile.md plugins/quality-gates/tests/lib/reconstruct-skill.sh
# test_skill_orchestration_behavior.sh — protocol-shape test for SKILL.md.
#
# 위 `# guards:` 는 이 파일이 실제로 여는 것에서 도출했다(R2, adjudication-topology
# Task 15c) — quality-pipeline/SKILL.md 는 `plugins/quality-gates/skills/*/SKILL.md`
# 로 잡히고(case 에서 `*` 는 `/` 를 넘으므로 다른 skill 의 SKILL.md 도 함께 잡힌다 —
# :274-307 의 major-버전 대조가 그 전량을 읽는다), references/differential-test.md 는
# reconstruct-skill.sh 가 SKILL.md 포인터 자리에 되접어 넣는 그 파일(스플라이스
# 지점은 reconstruct-skill.sh:41 — :27 은 그 파일의 usage 주석일 뿐이다), plugin.json
# 은 :274 의 major 판독 대상, security-reviewer.md 는 verifier-writable 페르소나 검사
# 대상, doc-recritic.md 는 #104 tools 포스처 검사 대상, references/recritic-code-profile.md
# 는 관문 D(verifier-writable) 검사 대상이다(PR4a 가 adversarial.md 하나였던 이 칸을
# 셋으로 갈랐다). **이 줄번호는 이 커밋(수정 라운드 2)
# 시점 기준이다** — m1 정정(라운드 1): 자기 헤더가 넣은 줄을 반영 안 한 편집-전
# 번호(:193 등)를 인용한 적이 있었다. 이 주석 블록 자체가 이후 더 늘어나면 같은
# drift 가 반복될 수 있으니, 줄번호를 믿기 전에 `grep -n '^PLUGIN_JSON=\|^AGENTS_DIR='`
# 로 먼저 재확인할 것.
#
# **수정 라운드 2, N3 — `tests/lib/reconstruct-skill.sh` 자신도 여섯 번째 코퍼스로
# 편입했다.** 이 락의 **모든** 단언이 읽는 문서(`$SKILL_MD`)를 만드는 게 이
# 라이브러리인데, 지금까지 `# guards:`에도 `--emit-scanned`에도 없었다 —
# `reconstruct-skill.sh` 만 고쳐도(예: 스플라이스 헤딩 매칭이 깨져도) 이 락이
# 후보에 안 뽑혔다(`tests/` 하위라 CHANGED_TESTS 로는 들어오지만, 실행하면 함수
# 정의뿐이라 no-op — R2·R3·F6 과 정확히 같은 부류). **판정: `.` (source) 는 "읽는
# 것"에 해당한다** — bash 가 그 파일의 바이트를 읽고 해석하는 것은 `cat`/`grep`
# 으로 여는 것과 다르지 않다. 리디렉션 감사(`grep -n '\. "\$SCRIPT_DIR'`)로
# `source` 호출이 `. "$SCRIPT_DIR/../lib/reconstruct-skill.sh"` 한 줄뿐임을
# 재확인했다(같은 문자열이 이 파일 상단 주석에도 한 번 나오지만 그것은 호출이
# 아니다). **줄번호로 적지 않는다** — 이 헤더가 늘 때마다 그 인용이 밀린다. `# guards:`·`--emit-scanned` 양쪽에 여섯 번째로 추가했다.
# 양성 대조: `compute-test-scope-candidates.sh` 에 이 파일을 건드리는 실제 diff
# 를 먹이면 이 락이 후보에 뜬다(수정 전엔 안 떴다), `test_guards_coverage_
# bidirectional.sh` 는 이 락 몫이 6/6·전체 105/105 GREEN.
#
# **일곱 밖의 파일은 이 스크립트가 열지 않는 것으로, 아래 다섯 변수(SCRIPT_DIR·
# SKILL_MD_REAL·PLUGIN_JSON·SKILLS_ROOT·AGENTS_DIR) + reconstruct-skill.sh 의
# `source` 한 자리의 모든 사용처를 직접 정독해 확인했다** — 자동화된 grep 전수
# 검사가 아니다(수정 라운드 1, I3 정정: 이전 판이 "전수 확인"의 근거로 인용한
# `grep -n '"\$[A-Za-z_]*\(_DIR\|_MD\|_JSON\|_ROOT\)"'` 는 변수 뒤에 닫는 따옴표가
# 바로 안 붙는 줄을 구조적으로 놓친다 — 이 파일 자신의 `. "$SCRIPT_DIR/../lib/
# reconstruct-skill.sh"` 줄이 그 예다: `_DIR` 접미사 뒤에 `/../lib/reconstruct-
# skill.sh"` 가 더 있어 그 정규식이 "닫는 따옴표 직전"으로 못 박은 자리에 안
# 걸린다. `reconstruct-skill.sh` 자신은(N3 로 이제 그 여섯 안에 스스로 포함되고)
# 그 여섯 밖의 새 코퍼스를 열지 않는 스플라이서-라이브러리라 결론(여섯 밖은 안
# 읽는다)은 안 바뀌지만, "이 정규식이 그것을 증명한다"는 서술은 거짓이었다 —
# 정규식을 인용하지 않고 수동 정독 사실만 남긴다).
#
# `--emit-scanned` — test_guards_coverage_bidirectional.sh 가 읽는다(수정 라운드 1,
# C1). **원래 이 값을 가로채지 않았다** — `--emit-scanned` 로 부르면 스위트 전체가
# 그대로 돌아 PASS/FAIL 123줄을 stdout 에 뿜었다. 오늘 그게 무해했던 유일한 이유는
# 이 파일이 코퍼스로 갖는 선재 RED 둘(iter cap 근접성·R1b→R8, 이 브랜치가 만든 것도
# 건드릴 것도 아니다) 때문에 rc≠0 이라 `test_guards_coverage_bidirectional.sh` 의 「`--emit-scanned` 미지원」 분기
# 의 `|| [ -z "$scanned" ]` 가 "미지원"으로 읽었기 때문이다 — 그 rc≠0 은 이 브랜치
# 소유가 아니라서, 그것이 언젠가 고쳐져 rc=0 이 되면 `scanned` 에 123줄의 단언
# 텍스트가 담겨 방향 A(선언 밖 123건)·방향 B(5/5 글롭이 아무것도 안 덮음)가 +6
# 거짓 FAIL 을 낸다 — **재리뷰가 88b0b0c 판에 이 반사실을 직접 적용해 재현**:
# emit 123줄·커버리지 락 방향 A 1 FAIL + 방향 B 5 FAIL, 총 Fail 6. **선택: 실제로
# 읽는 경로를 낸다** — `test_guards_coverage_bidirectional.sh:23` 의 `[ "${1:-}"
# = "--emit-scanned" ] && exit 0`(빈 응답)는 이 자리의 선례가 «아니다». 그 파일은
# "guards 선언을 가진 파일 전부를 스캔하는 락"이라 자기 자신을 그 스캔 대상에
# 넣으면 자기재귀로 멈추고(빈 응답이 사실과 일치 — 그 검사기 자신은 아무 경로도
# 스캔하지 않는다), 이 파일은 자기 자신을 스캔하는 게 «아니라» SKILL.md 5종 +
# plugin.json + 페르소나 둘 + reconstruct-skill.sh(N3) 를 읽을 뿐이다 — 빈 응답을
# 내면 그 사실이 사라져 방향 A/B 가 이 락을 영원히 "미지원"으로만 본다. 아래에서
# 그 여섯(SKILLS_ROOT 의 동적 find 로 나오는 SKILL.md 전량 + 나머지 넷)을 낸다 —
# 본 실행이 읽는 것과 같은 명령(`find "$SKILLS_ROOT" -maxdepth 2 -name
# 'SKILL.md'`)을 재사용해 드리프트 여지를 없앴다. **PATH shim 계측으로도 확증**
# (재리뷰) — `differential-test.md` 는 awk `getline` 내부 읽기라 이 emit 목록에 인자로는
# 안 나타나지만 실제로 읽히므로, 위 6경로는 과대 신고가 아니라 실제로 읽는 것과
# 정확히 일치한다.
if [ "${1:-}" = "--emit-scanned" ]; then
  _SOB_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  _SOB_QG_ROOT="$(cd -- "$_SOB_SCRIPT_DIR/../.." && pwd)"
  _SOB_REPO_ROOT="$(cd -- "$_SOB_QG_ROOT/../.." && pwd)"
  _SOB_REL="${_SOB_QG_ROOT#"$_SOB_REPO_ROOT"/}"
  printf '%s\n' \
    "$_SOB_REL/skills/quality-pipeline/references/differential-test.md" \
    "$_SOB_REL/.claude-plugin/plugin.json" \
    "$_SOB_REL/agents/security-reviewer.md" \
    "$_SOB_REL/agents/doc-recritic.md" \
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

# Task 31(무게 감축): 차등 테스트 절차 전문이 references/differential-test.md 로
# 분리됐다. 이 파일의 모든 검사는 원래 단일 SKILL.md 를 줄 번호로 분석하도록
# 설계됐으므로, 분할 전과 동일한 논리적 문서를 재구성해 그 위에서 돈다 — 그래야
# R-init..R8 앵커가 여전히 잡힌다. 재구성 실패(포인터 소실 등)는 조용히 원본으로
# 폴백하지 않고 FAIL 한다.
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
review_line=$(first_line 'subagent_type.*quality-gates:doc-recritic')
assert_line "Phase 1.5 재비판 dispatch (doc-recritic)" "$review_line"

# 각도 수행자 3종이 fan-out 에 있다 (보안 · 판정 · 다른 전제). runtime-verifier 는
# 대상 소멸(Task 7) — 4종 fan-out 이 이제 3종이다.
for agent in doc-recritic test-scope-validator security-reviewer; do
  if grep -qE "subagent_type[^\"]*\"quality-gates:$agent" "$SKILL_MD"; then
    echo "PASS: $agent dispatch present"
  else
    echo "FAIL: $agent dispatch missing"
    fail=$((fail + 1))
  fi
done

# Fix-loop iter cap proximity to the fix-loop AskUserQuestion.
# Use FIRST AskUserQuestion at or after the re-critique dispatch (the
# description's top-of-file AskUserQuestion mention is irrelevant; we want the
# fix-loop decision-tool call).
askuser_review_line=$(first_line_after 'AskUserQuestion' "$review_line")
itercap_line=$(first_line 'max_review_iterations')
# 선재 RED 락 — 이름 불변. Task 1 베이스라인에서 이미 FAIL(distance > 160). 이 Task
# 는 그 이름의 RED 를 고치지 않는다(범위 밖) — 160 을 올리지 않는다: 상한을 올리는
# 것은 이 근접성 sanity 를 무디게 하는 것이지 진짜 수정이 아니다.
assert_proximity "iter cap near Review gate AskUserQuestion" "$askuser_review_line" "$itercap_line" 160

# 대상 소멸 (Task 7 — runtime-verifier · Decision 1/2 · Upfront Execution Plan ·
# block_policy · DISABLE_RUNTIME_SANDBOX · Runtime gate 그 자체가 SKILL.md 에서
# 사라졌다). 이 자리에 있던 락들: 「Runtime gate runtime-verifier dispatch」·
# 「Review precedes Runtime」·「RUNTIME_MAX_RESOLUTIONS near Runtime dispatch」·
# 「Retry-path AskUserQuestion between Review/Runtime gate」·「create-sandbox
# invoked (+ precedes runtime-verifier)」·「mutation-guard invoked after runtime
# dispatch」·「forced_downgrade referenced」·「Upfront Execution Plan section
# present」·「requires_decision referenced in plan gate」·「block policy
# stop/skip/ask present」·「runtime sandbox kill switch present」·
# 「spec_acceptance_criteria threaded」. 후계는 test_one_pipeline_surface.sh 의
# 음의 락(부재 확인) + 이 파일 아래 R6/R8 창 락이다.

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
# 대상 소멸 (Task 7, R-W) — R7(mutation-guard 라우팅 표) 자체가 differential-test.md
# 에서 통째로 지워졌다. qg 파이프라인은 create-sandbox/mutation-guard 를 더 호출하지
# 않는다(그 두 서브커맨드는 qg-worktree.sh 안에 남지만 소비자는 plugin-audit 뿐이다
# — R-W). 이 자리에 있던 락들: R7 exit-code routing 표(guard exit 4 → FAIL · guard_error
# · stderr verbatim · indeterminate ≠ clean) · fallback SKIP_WITH_EVIDENCE cap ·
# runtime_project_dir 변수 · R3 dispatch 의 project_dir 슬롯(+ sandbox_dir 하드코딩
# 금지 음의 짝) · evidence_dir threaded to verifier · I-G retry re-capture
# (sandbox_dir/baseline_sha/snapshot_digest) · R5a¹ 의 snapshot_digest capture ·
# guard call 3-arg 스레딩. verifier 자체가 사라져 그 무엇도 스레딩할 대상이 없다.

# --- R2-AC5: Law-3 persona hardening (the bypass escaped because reviewers
#     trusted a verifier-writable artifact; the persona now forces that check).
#     Anchor on the stable literal `verifier-writable`, which the security-reviewer
#     persona AND the re-critic code profile (PR4a — moved off the adversarial
#     persona, which no longer exists) include verbatim. ---
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
# doc-recritic itself is a byte-for-byte copy-of the shared persona (Law 2
# scoping lives upstream, verified by test_copy_of_contract.sh) — this only
# re-checks the #104 tools posture this SKILL's prose claims for it.
if grep -qE '^tools:[[:space:]]*Read,[[:space:]]*Grep,[[:space:]]*Glob$' "$AGENTS_DIR/doc-recritic.md"; then
  echo "PASS: doc-recritic persona keeps #104 tools posture (Read, Grep, Glob)"
else
  echo "FAIL: doc-recritic persona tools posture changed from Read, Grep, Glob (#104 lock)"
  fail=$((fail + 1))
fi

# --- PR4a: Phase 1.5 재비판 dispatch protocol-shape ---
# recritic-code-profile.md must appear within 30 lines BEFORE the doc-recritic
# dispatch line (the Phase 1.5 `cat .../recritic-code-profile.md` fence sits
# ~16 lines ahead of the Agent({...}) fence) — an "after" window would be RED.
if [[ "$review_line" -gt 0 ]]; then
  recritic_win_start=$((review_line - 30))
  [[ "$recritic_win_start" -lt 1 ]] && recritic_win_start=1
  if awk -v s="$recritic_win_start" -v e="$review_line" \
      'NR>=s && NR<e && /recritic-code-profile\.md/ {f=1} END{exit !f}' "$SKILL_MD"; then
    echo "PASS: recritic-code-profile.md referenced within 30 lines before doc-recritic dispatch"
  else
    echo "FAIL: recritic-code-profile.md not found within 30 lines before doc-recritic dispatch (line $review_line)"
    fail=$((fail + 1))
  fi
else
  echo "FAIL: recritic-code-profile.md proximity check skipped — no doc-recritic dispatch line"
  fail=$((fail + 1))
fi

# The doc-recritic dispatch fence must carry the <diff>${DIFF}</diff> slot —
# the code path threads diff (test_agent_input_slots.sh cannot see this: the
# shared contract declares `diff` optional).
if [[ "$review_line" -gt 0 ]] && awk -v s="$review_line" -v e="$((review_line + 15))" \
    'NR>=s && NR<=e && index($0, "<diff>${DIFF}</diff>") {f=1} END{exit !f}' "$SKILL_MD"; then
  echo "PASS: doc-recritic dispatch fence carries <diff>\${DIFF}</diff> slot"
else
  echo "FAIL: doc-recritic dispatch fence missing <diff>\${DIFF}</diff> slot"
  fail=$((fail + 1))
fi

# The disposition line on the doc-recritic dispatch must be fail-closed (R-R) —
# the only place that measures R-R is actually true.
if [[ "$review_line" -gt 0 ]] && awk -v s="$review_line" -v e="$((review_line + 5))" \
    'NR>=s && NR<=e && /fail-closed/ {f=1} END{exit !f}' "$SKILL_MD"; then
  echo "PASS: doc-recritic disposition line is fail-closed (R-R)"
else
  echo "FAIL: doc-recritic disposition line missing fail-closed (R-R)"
  fail=$((fail + 1))
fi

# AC17 — re-critic dispatches even when detection produced zero findings, and
# that clause precedes the dispatch fence itself.
phase15_zero_line=$(first_line '탐지 결과가 0건이어도 디스패치한다')
assert_line "Phase 1.5 dispatches even when detection has zero findings (AC17)" "$phase15_zero_line"
assert_order "AC17 zero-findings clause precedes doc-recritic dispatch" "$phase15_zero_line" "$review_line"

# The recritic.diff instructions must forbid git show/format-patch/log -p output,
# backed by a body-unique rationale line (not header-satisfiable). Anchor on
# `git format-patch` AND the negation `쓰지 않는다` together — a bare
# `git format-patch` existence check doesn't lock the prohibition itself: someone
# could delete "쓰지 않는다" (turning the sentence into something else, or even
# permissive) while `git format-patch` still appears elsewhere on the line/file,
# and the old anchor would stay GREEN (fix round 1, Minor 3).
gitshow_line=$(first_line 'git format-patch.*쓰지 않는다')
assert_line "recritic diff prohibits git show/format-patch/log -p output" "$gitshow_line"
if [[ "$gitshow_line" -gt 0 ]] && awk -v s="$gitshow_line" -v e="$((gitshow_line + 3))" \
    'NR>=s && NR<=e && index($0, "커밋 메시지") {f=1} END{exit !f}' "$SKILL_MD"; then
  echo "PASS: git-show prohibition backed by body-unique 커밋 메시지 rationale (not header-satisfiable)"
else
  echo "FAIL: git-show prohibition missing body-unique 커밋 메시지 rationale"
  fail=$((fail + 1))
fi

# --- v2.3.0 R4: Review-gate findings surfaced before the decision tool ---
# The Surface-findings step (Step 4.5) must precede the iter-boundary
# decision's `findings remain` question. Anchor on the surface-step TEXT,
# NOT the `## Review` section heading — a heading always precedes its
# body, so a heading anchor is a tautological PASS (the V7-class defect this
# file was created to avoid). Existence grep alone cannot catch mis-placement.
surface_line=$(first_line 'Surface findings|Step 4\.5')
question_line=$(first_line 'question:.*findings remain')
assert_line "Surface-findings step present" "$surface_line"
assert_line "iter-boundary decision question present" "$question_line"
assert_order "Surface findings precedes iter-boundary decision" "$surface_line" "$question_line"

# 대상 소멸 (Task 7, AC1) — v2.4.0 Decision 1(gate-scope question, 'both gates'
# anchor) · Dispatch Loop 참조(Decision 1 / short-circuit) · F1(단일-게이트
# `/qg runtime` 의 R5a⁰ manifest 초기화) · F2(review-only 의 gate-scope-conditional
# 옵션 대체) · C4(effective_skip_runtime 배선 ≥3회) · F7(clean-exit 의 gate-scope
# 라우팅)이 이 자리에 있었다. 한 파이프라인에는 게이트 범위가 없다 — 이 여섯 락
# 전부가 지키던 SKILL.md 표면이 사라졌다(Pipeline 절이 후계 — 단일 ①→⑤ 흐름).

# --- v2.7.0 §5.2-5.4: changes-exist floor (routing removed, integrity kept) ---
# check-review-scope.sh still invoked in the Review gate (call+cache for the floor).
assert_line "check-review-scope.sh invoked" "$(first_line 'check-review-scope.sh')"

# AC12: the model-owned routing honesty norm is present.
assert_line "review-scope ownership honesty norm present" "$(first_line 'You own review-scope resolution')"

# AC5 (Task8 R-Y/R-AA — the floor moved from a Step 4.5 IF-condition to a row in
# Step 4's 판정 입력 table): the floor keys on the two deterministic inputs — the
# resolved scope file count AND the script-emitted changes_exist (NOT the removed
# scope_signal). Anchor BOTH conditions on a SINGLE line: 'changes_exist == yes'
# also appears on the honesty-norm line, so a lone `first_line 'changes_exist ==
# yes'` would match there and pass even if the floor row itself regressed. The
# combined 'resolved_scope_file_count == 0 …changes_exist == yes' pattern is
# unique to the floor row (codex v2.7.0 review, finding 3 — the underlying
# uniqueness concern survives the row's relocation and Korean rephrasing, so the
# glue between the two conditions is no longer pinned to the literal "AND").
assert_line "floor keyed on resolved_scope_file_count == 0 AND changes_exist == yes" \
  "$(first_line 'resolved_scope_file_count == 0.*changes_exist == yes')"
# Fix round 1, Minor 6 — the old target `not-certified \(scope-empty\)` matched the
# honesty-norm quote line (SKILL.md:241), not the floor row itself; deleting the
# floor row alone left this GREEN. Tie it to the SAME line as the check above
# (unique to the floor row — the honesty-norm line lacks the literal
# `resolved_scope_file_count == 0` token) and require the reason token there too.
assert_line "honest floor label present" \
  "$(first_line 'resolved_scope_file_count == 0.*changes_exist == yes.*scope-empty')"

# AC6: degraded signal still emits a loud fail-open advisory.
assert_line "degraded scope advisory present" "$(first_line 'scope check degraded')"

# Task8 R-AA — the old English label 'no scope reviewed' is gone; the floor now
# speaks through the closed reason token `scope-empty`, which appears in the
# Step 1b intro + the honesty-norm quote + Step 4's floor row → at least 3
# occurrences.
floor_count=$(grep -cF 'scope-empty' "$SKILL_MD" || true)
if [[ "$floor_count" -ge 3 ]]; then
  echo "PASS: honest floor label (scope-empty) in intro + honesty norm + floor row ($floor_count)"
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

# ── T48 / AC51 (대상 소멸 — Task 7) ──
# 이 자리는 기존 로직 7종(detect-runtime.sh · block_policy · snapshot_digest ·
# quality-gates:test-scope-validator · spec_acceptance_criteria ·
# quality-gates:runtime-verifier · mutation-guard)이 "새 SKILL 에서 자리를 잃지
# 않았는가"를 잤다. Task 7 은 그중 여섯을 **의도적으로 삭제**한다(대상 소멸이지
# 누락이 아니다) — 남는 것은 quality-gates:test-scope-validator 하나뿐이고, 그
# 존재는 위 fan-out 루프가 이미 잰다. "옮겨갈 새 자리"를 찾는 이 락의 전제 자체가
# 더는 성립하지 않아 대응물 없이 지운다 — 후계는 test_one_pipeline_surface.sh 의
# 음의 락(일곱 토큰 중 여섯의 전면 부재 확인)이다.

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
  'scripts/baseline-cache.sh" get'         '^[*][*]Step R4'     '^[*][*]Step R5b'
assert_call_in_window "R4 가 baseline-cache.sh put 호출" \
  'scripts/baseline-cache.sh" put'         '^[*][*]Step R4'     '^[*][*]Step R5b'
assert_call_in_window "R4 가 run-test-selection.sh run 호출 (기준선 측)" \
  'scripts/run-test-selection.sh" run'     '^[*][*]Step R4'     '^[*][*]Step R5b'
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
r5b_s=$(first_line '^[*][*]Step R5b'); r8_s=$(first_line '^[*][*]Step R8')
r6_s=$(first_line '^[*][*]Step R6')
if [[ "$r5b_s" -le 0 || "$r6_s" -le 0 || "$r8_s" -le 0 || "$r5b_s" -ge "$r6_s" || "$r6_s" -ge "$r8_s" ]]; then
  echo "FAIL: HEAD 축 인자 락 — 창 앵커 붕괴 (R5b=$r5b_s R6=$r6_s R8=$r8_s)"
  fail=$((fail + 1))
else
  # sites = 창 안 `run` 호출 줄 수 · good = 다음 줄이 head_tree_dir 인 것
  # 창 상한을 R7(대상 소멸)에서 R8 로 옮긴다 — R7 이 사라지며 R6 의 flaky 재실행
  # 구간이 이제 R8 바로 앞까지다.
  read -r sites good < <(awk -v s="$r5b_s" -v e="$r8_s" '
    NR>s && NR<e && index($0,"scripts/run-test-selection.sh\" run") { want=NR+1; sites++ }
    want && NR==want { if (index($0,"$head_tree_dir")) good++; want=0 }
    END { print sites+0, good+0 }
  ' "$SKILL_MD")
  # ∃ 짝: 호출이 0개면 ∀ 는 공허하게 참이다. 그리고 **2개 이상**이어야 한다 — R5b 의
  # 본 실행과 R6 의 flaky 재실행. 하나만 요구하면 R6 의 재실행을 통째로 지워도 통과한다.
  if [[ "$sites" -ge 2 && "$good" -eq "$sites" ]]; then
    echo "PASS: R5b·R6 의 run 호출 ${sites}곳 전부가 HEAD 축 트리(\$head_tree_dir)를 받음 (창 $r5b_s..$r8_s)"
  else
    echo "FAIL: HEAD 축 인자 (호출 ${sites}곳(≥2 필요) 중 head_tree_dir 수신 ${good}곳) — 샌드박스로 되돌아갔거나 flaky 재실행이 사라졌는가?"
    fail=$((fail + 1))
  fi
fi

# create-head 의 인자는 **다시 뜬 봉인**($sealed) 이어야 한다 (R-X) — 옛 R5a 시절의
# create-sandbox 커밋 B 는 $baseline_sha 였지만, 이제 R5b 는 seal-worktree.sh 로
# 봉인하고 그 봉인 sha 를 create-head 에 넘긴다. $merge_base 를 넘기면 HEAD 축이
# 기준선과 같은 커밋에 붙어 차등이 구조적으로 0 이 되는데, 트리는 정상 생성되고 행도
# 정상으로 나오므로 **어떤 degrade 신호도 서지 않는다**.
#
# **∀ 다 (/qg iter-7, pr-test-analyzer).** 앞 버전은 ∃ 여서 — 맞는 호출 하나만 있으면
# `f=1` — 뒤에 다른 값을 받는 **두 번째** `create-head` 를 덧붙이는 mutation 이
# 통과했다(마지막 대입이 이긴다). 형제 `run` 인자 락은 처음부터 ∀ 였는데 이 락만
# ∃ 였다: 같은 파일 안에서 관례가 갈린 것이 구멍이었다.
read -r ch_sites ch_good < <(awk -v s="$r5b_s" -v e="$r8_s" '
  NR>s && NR<e && index($0,"scripts/qg-worktree.sh\" create-head") { want=NR+1; sites++
    if (index($0,"$sealed")) { good++; want=0 } }
  want && NR==want { if (index($0,"$sealed")) good++; want=0 }
  END { print sites+0, good+0 }
' "$SKILL_MD")
if [[ "$ch_sites" -ge 1 && "$ch_good" -eq "$ch_sites" ]]; then
  echo "PASS: create-head 호출 ${ch_sites}곳 전부가 다시 뜬 봉인(\$sealed)을 받음"
else
  echo "FAIL: create-head 인자 (호출 ${ch_sites}곳 중 sealed 수신 ${ch_good}곳)"
  fail=$((fail + 1))
fi

# HEAD 축 트리 폐기는 **R6 뒤**여야 한다 — R6 의 flaky 재실행이 그 트리를 쓴다.
# R5b 창 안에 `remove "$head_tree_dir"` 가 있으면 그 재실행이 불가능해진다(iter-7 CRITICAL).
rm_in_r5b=$(awk -v s="$r5b_s" -v e="$r6_s" \
  'NR>s && NR<e && index($0,"remove \"$head_tree_dir\"") { c++ } END { print c+0 }' "$SKILL_MD")
rm_in_r6=$(awk -v s="$r6_s" -v e="$r8_s" \
  'NR>s && NR<e && index($0,"remove \"$head_tree_dir\"") { c++ } END { print c+0 }' "$SKILL_MD")
if [[ "$rm_in_r5b" -eq 0 && "$rm_in_r6" -ge 1 ]]; then
  echo "PASS: HEAD 축 트리 폐기가 R6 뒤 (R5b 창 ${rm_in_r5b}회 · R6 창 ${rm_in_r6}회)"
else
  echo "FAIL: HEAD 축 트리 폐기 위치 (R5b 창 ${rm_in_r5b}회(0 이어야) · R6 창 ${rm_in_r6}회(≥1 이어야)) — flaky 재실행이 지워진 트리를 쓴다"
  fail=$((fail + 1))
fi

# R5b 실패 라우팅 — R6 과 같은 규율(R7 대상 소멸). `create-head`/`run` 이 죽었을 때 무엇을 할지
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

# Fix round 1 (Important #3) — differential-test.md 가 "행 부재의 귀속 카테고리 이름을
# 이 창에 리터럴로 적지 않는다 — 이 창에 그 토큰이 0회여야 한다는 회귀 락이 있다" 고
# 주장하는데, 그 락(옛 == 폴백 R5b 미실행 절의 route_stale)은 Task 7 이 대상 소멸로
# 지웠다 — 이 창에 SILENT_DROP 을 심어도 통과하는 상태였다. 여기서 그 락을 복원한다.
# 양의 짝은 $r5b_body 가 비어 있지 않다는 위 가드가 이미 선다.
if [[ -n "${r5b_body:-}" ]]; then
  if grep -qF 'SILENT_DROP' <<<"$r5b_body"; then
    echo "FAIL: R5b 창에 SILENT_DROP 잔존 — 행 부재가 '기준선을 못 돌렸다' 대신 '고른 것이 사라졌다'로 오라벨될 수 있다"
    fail=$((fail + 1))
  else
    echo "PASS: R5b 창에 SILENT_DROP 0회 (귀속 카테고리 이름 재도입 봉쇄)"
  fi
fi

# 대상 소멸 (Task 7) — NEEDS_RESOLUTION 재시도 경로("재시도의 R5b" 문단, 'Yes, retry'
# 옵션)가 통째로 사라졌다. 재시도는 이제 fix-loop 의 Retry 하나이고, R5b 는 매
# iteration 처음부터 다시 돈다(R-AC) — "재호출 vs 재사용" 반전 축 자체가 없다.

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
  'scripts/diff-test-results.py' 2         '^[*][*]Step R6'     '^[*][*]Step R8'
assert_call_in_window "R6 이 diff-test-results.py --aggregate 호출 (집계)" \
  'scripts/diff-test-results.py" --aggregate' '^[*][*]Step R6'  '^[*][*]Step R8'
assert_call_in_window "R8 이 check_qa_ledger.py 호출" \
  'scripts/check_qa_ledger.py'             '^[*][*]Step R8'     '^## Final Summary'

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
fs_s=$(first_line '^## Final Summary')
if [[ "$r6_s" -le 0 || "$r8_s" -le 0 || "$fs_s" -le 0 ]]; then
  echo "FAIL: 집계 사슬 락 — 창 앵커 붕괴 (R6=$r6_s R8=$r8_s FinalSummary=$fs_s)"
  fail=$((fail + 1))
else
  chain_ok=1
  # ① R6 의 `--aggregate` 호출이 stdout 을 파일로 남긴다 (창 상한: R7 대상 소멸 → R8)
  awk -v s="$r6_s" -v e="$r8_s" '
    NR>s && NR<e && index($0,"diff-test-results.py\" --aggregate") { want=1 }
    want && index($0,"> \"$aggregate_yaml\"") { f=1 }
    END { exit !f }' "$SKILL_MD" \
    || { echo "    R6 이 집계 stdout 을 \$aggregate_yaml 로 남기지 않음"; chain_ok=0; }
  # ② R8 의 게이트 호출이 **그 파일을** --aggregate 로 넘긴다 (호출 줄 또는 이어지는 줄).
  # 창 상한: R9 대상 소멸(R8 이 이제 참고 문서의 마지막 스텝) → '## Final Summary'.
  #
  # 두 분기 모두 리터럴 `"$aggregate_yaml"` 을 요구한다 (/qg iter-7, 리뷰어 2명).
  # 앞 버전은 같은-줄 분기가 **토큰 `--aggregate` 만** 요구해서, 호출을 한 줄로 접고
  # `--aggregate "$per_adapter_yaml"` 을 넘기는 mutation 이 통과했다. 그리고 그것은
  # 이론이 아니라 실제 fail-open 이다: `per_adapter()` 도 `attribution_status:` 를 내므로
  # 게이트가 **깨끗하게 파싱해** 어댑터의 `closed` 를 원장의 `closed` 와 대조하고 통과한다
  # — 전사 게이트가 막으려던 바로 그 형태다. 현재 SKILL 이 2줄이라 GREEN 이었던 것이지
  # 락의 이빨 때문이 아니었다.
  awk -v s="$r8_s" -v e="$fs_s" '
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
# 창 상한: Step R9(대상 소멸 — R8 이 이제 참고 문서의 마지막 스텝) → '## Final Summary'.
rt_end=$(first_line '^## Final Summary')
if [[ "$rinit_s" -le 0 || "$r1a_s" -le 0 || "$r1b_s" -le 0 || "$r2_s" -le 0 \
      || "$r8_s" -le 0 || "$rt_end" -le 0 ]]; then
  echo "FAIL: unclaimed 사슬 락 — 창 앵커 붕괴 (R-init=$rinit_s R1a=$r1a_s R1b=$r1b_s R2=$r2_s R8=$r8_s FinalSummary=$rt_end)"
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
  awk -v s="$r8_s" -v e="$rt_end" '
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
  # 판정 어휘가 Task 7 에서 'PASS 로 올리지 않는다' → 'clean 불가' 로 바뀌었다(전면
  # 치환 — scripts/verdict.py 밖에 판정 어휘를 두지 않는다). 앵커도 같이 옮긴다.
  awk -v s="$r8_s" -v e="$rt_end" '
    NR>s && NR<e {
      if (index($0,"non-zero 면") && index($0,"clean 불가")) {
        pos=1
        if ($0 ~ /참고한다|권고|advisory/) neg++
      }
    }
    END { exit !(pos && neg == 0) }' "$SKILL_MD" \
    || { echo "    R8 게이트의 'non-zero → clean 불가' 라우팅 문장이 없거나 그 줄에서 권고로 약화됨"; uc_ok=0; }
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
  #    ★ 정직한 한계: `clean 불가` 는 이 창의 fenced 코드에 이미 여러 번 나오므로(mktemp
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
  #      (`seal-worktree.sh`)이 `--show-toplevel` 을 쓰므로 가드도 같은 트리를 봐야 한다.
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
      if (index(line,"clean 불가")) r=1
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

# 대상 소멸 (Task 7) — 라벨 R5a⁰/R5a¹/R5a²/R5a³ 4종과 그 순서 불변식, 그리고
# "R5a⁰ 가 detect-runtime 을 실행한다" 락이 이 자리에 있었다. 해소 루프(Decision 2 ·
# block_policy · runtime-verifier manifest 초기화)가 통째로 사라지며 그 스텝들 자체가
# 없어졌다(R-AG: `evidence_dir` 정의는 R5a²→R8 로 옮겨졌다) — detect-runtime.sh 스크립트
# 도 삭제됐다. 양의 짝으로 R8 라벨 존재만 남긴다(뒤 여러 창 락이 이미 R8 을 앵커로 쓴다).
assert_line "새 라벨 R8 존재" "$(first_line '^[*][*]Step R8')"

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
assert_line "Step R5b 헤딩 존재 (창 붕괴 방지)" "$r5b"
# 대상 소멸 (Task 7) — "run-test-selection.sh 호출이 verifier dispatch 블록
# (R5a³..R5b) 안에 0회" 는 그 창 자체가 사라져 대응물이 없다(verifier 가 삭제돼
# 그 턴이 존재하지 않는다). 아래 authoritative 문장 존재 검사는 keep — Step 3(a)
# 의 머리 인용 블록(호출 주체 불변식)이 그 문장을 그대로 남긴다.
if grep -qF '이 호출 결과가 authoritative' "$SKILL_MD"; then
  echo "PASS: authoritative 문장 존재"
else
  echo "FAIL: authoritative 문장 부재"; fail=$((fail + 1))
fi

# 대상 소멸 (Task 7) — "== 폴백 R5b 미실행" 전체(polarity_ok/bad · rec_ok · route_ok
# · route_stale 5축)가 이 자리에 있었다. `DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX`
# 로 R4 가 건너뛰고 R5b 가 `unrun` 전량이 되던 시나리오 자체가 사라졌다 — R-V 의 새
# kill switch(`DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST`)는 R4 한 스텝이 아니라
# ② 전체를 건너뛴다. 후계는 이미 존재한다 — 위 "R5b 실패 라우팅" 검사(r5b_route)가
# `$sealed`/`$head_tree_dir` 관측 실패 → `unrun` + `degraded` · '폴백하지 않는다'
# 명문화를 같은 창(R5b..R6)에서 잰다. 새 락을 더 두지 않는다(중복).

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
