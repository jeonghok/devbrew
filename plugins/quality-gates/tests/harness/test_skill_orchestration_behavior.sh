#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/*/SKILL.md plugins/quality-gates/skills/quality-pipeline/references/differential-test.md plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/agents/security-reviewer.md plugins/quality-gates/agents/code-recritic.md plugins/quality-gates/references/recritic-code-profile.md plugins/quality-gates/tests/lib/reconstruct-skill.sh
# test_skill_orchestration_behavior.sh — protocol-shape test for SKILL.md.
#
# 위 `# guards:` 는 이 파일이 실제로 여는 것에서 도출했다(R2, adjudication-topology
# Task 15c) — quality-pipeline/SKILL.md 는 `plugins/quality-gates/skills/*/SKILL.md`
# 로 잡히고(case 에서 `*` 는 `/` 를 넘으므로 다른 skill 의 SKILL.md 도 함께 잡힌다 —
# :274-307 의 major-버전 대조가 그 전량을 읽는다), references/differential-test.md 는
# reconstruct-skill.sh 가 SKILL.md 포인터 자리에 되접어 넣는 그 파일(스플라이스
# 지점은 reconstruct-skill.sh:41 — :27 은 그 파일의 usage 주석일 뿐이다), plugin.json
# 은 :274 의 major 판독 대상, security-reviewer.md 는 verifier-writable 페르소나 검사
# 대상, code-recritic.md 는 #104 tools 포스처 검사 대상, references/recritic-code-profile.md
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
# 차등 절차(D0~D8)의 앵커가 여전히 잡힌다. 재구성 실패(포인터 소실 등)는 조용히 원본으로
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
review_line=$(first_line 'subagent_type.*quality-gates:code-recritic')
assert_line "Step 3.5 재비판 dispatch (code-recritic)" "$review_line"

# 각도 수행자 2종이 fan-out 에 있다 (재비판 · 보안). runtime-verifier 는 대상 소멸(Task 7),
# test-scope-validator 는 agent 삭제(차등 재건 — 그 판단은 절차 D2 로 옮겼다).
for agent in code-recritic security-reviewer; do
  if grep -qE "subagent_type[^\"]*\"quality-gates:$agent" "$SKILL_MD"; then
    echo "PASS: $agent dispatch present"
  else
    echo "FAIL: $agent dispatch missing"
    fail=$((fail + 1))
  fi
done

# Fix-loop iter cap proximity to the fix-loop AskUserQuestion.
# v10(K-8): 차등 테스트 절이 Review 와 Fix-loop 사이에 접히므로 「재비판 dispatch 뒤 첫
# AskUserQuestion」 은 레퍼런스 R3 산문에 떨어진다 — 앵커를 Fix-loop decision 절의 호출
# 리터럴로 옮기고, 상한은 그 결정 도구가 스스로 밝히는 N<5 / N=5 → Max-iter 문장으로 잰다.
# 160 을 올리지 않는다: 상한을 올리는 것은 이 근접성 sanity 를 무디게 하는 것이다.
fixloop_line=$(first_line '^### Fix-loop decision')
assert_line "Fix-loop decision 절 앵커" "$fixloop_line"
askuser_review_line=$(first_line_after 'AskUserQuestion[(][{]' "$fixloop_line")
itercap_line=$(first_line 'N < 5 only — N=5 always goes to Max-iter decision')
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
# 음의 락(부재 확인)이다.

# SKILL 제목의 버전이 **shipped major 와 일치**한다 — 이 플러그인의 모든
# skills/*/SKILL.md 에 대해.
#
# 앞 버전은 quality-pipeline/SKILL.md 제목 하나만 봤다(리터럴 `v2.7.0` 핀의
# 후신). 이 플러그인엔 SKILL.md 가 둘이다 — quality-pipeline(버전 있음) ·
# artifact-critique(버전 없음). 한 파일만 보는 락은 나머지에 구조적으로 눈이 먼다 —
# 버전을 단 둘째 SKILL(v10 ③ 에서 삭제)이 plugin.json bump 뒤에도 제목에 구버전을
# 그대로 달고 있는 걸 못 잡은 적이 있다.
#
# 음의 락: 버전을 단 제목은 전부 major 가 shipped 와 같아야 한다. 버전이
# 아예 없는 제목(artifact-critique)은 위반이 아니다 — 무버전 제목은 애초에
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
# 않는다(그 두 서브커맨드는 v10 에서 plugin-audit 의 scripts/audit-sandbox.sh 로 옮겨 갔다
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
# code-recritic is qg's own re-critic persona — this re-checks the #104 tools
# posture this SKILL's prose claims for it.
if grep -qE '^tools:[[:space:]]*Read,[[:space:]]*Grep,[[:space:]]*Glob$' "$AGENTS_DIR/code-recritic.md"; then
  echo "PASS: code-recritic persona keeps #104 tools posture (Read, Grep, Glob)"
else
  echo "FAIL: code-recritic persona tools posture changed from Read, Grep, Glob (#104 lock)"
  fail=$((fail + 1))
fi

# --- PR4a: Step 3.5 재비판 dispatch protocol-shape ---
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
# decision's `남은 지적이 있다` question. Anchor on the surface-step TEXT,
# NOT the `## Review` section heading — a heading always precedes its
# body, so a heading anchor is a tautological PASS (the V7-class defect this
# file was created to avoid). Existence grep alone cannot catch mis-placement.
surface_line=$(first_line 'Surface findings|Step 4\.5')
question_line=$(first_line 'question:.*남은 지적이 있다')
assert_line "Surface-findings step present" "$surface_line"
assert_line "iter-boundary decision question present" "$question_line"
assert_order "Surface findings precedes iter-boundary decision" "$surface_line" "$question_line"

# 대상 소멸 (Task 7, AC1) — v2.4.0 Decision 1(gate-scope question, 'both gates'
# anchor) · Dispatch Loop 참조(Decision 1 / short-circuit) · F1(단일-게이트
# `/qg runtime` 의 R5a⁰ manifest 초기화) · F2(review-only 의 gate-scope-conditional
# 옵션 대체) · C4(effective_skip_runtime 배선 ≥3회) · F7(clean-exit 의 gate-scope
# 라우팅)이 이 자리에 있었다. 한 파이프라인에는 게이트 범위가 없다 — 이 여섯 락
# 전부가 지키던 SKILL.md 표면이 사라졌다(Flow 절이 후계 — 단일 흐름).

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

# ── T48 / AC51 (대상 소멸 — Task 7) ──
# 이 자리는 기존 로직 7종(detect-runtime.sh · block_policy · snapshot_digest ·
# quality-gates:test-scope-validator · spec_acceptance_criteria ·
# quality-gates:runtime-verifier · mutation-guard)이 "새 SKILL 에서 자리를 잃지
# 않았는가"를 잤다. Task 7 은 그중 여섯을 **의도적으로 삭제**했고(대상 소멸이지
# 누락이 아니다), 남았던 quality-gates:test-scope-validator 도 차등 재건에서 agent 째
# 지워졌다. "옮겨갈 새 자리"를 찾는 이 락의 전제 자체가 더는 성립하지 않아 대응물 없이
# 지운다 — 후계는 test_one_pipeline_surface.sh 의 음의 락(전면 부재 확인)이다.

# 대상 소멸 (차등 재건) — 옛 절차 Step R-init~R8 의 창 락(신규 스크립트 배선 · HEAD 축 인자 ·
# create-head 인자 · HEAD 축 트리 폐기 위치 · R5b 실패 라우팅 · R6 집계 · R6→R8 집계 사슬 ·
# R1b→R8 unclaimed 사슬 · 중간 파일 custody · 라벨 R8)이 이 자리에 있었다. 그 단계 · 집계 ·
# 원장 · qg_run_tmp 가 절차와 함께 사라졌다. 각 요구는 행동 테스트가 잰다 — 배선은
# test_differential_procedure.sh(D0~D8 · 토픽 경로 · D1 실행), 두 축의 트리는 R5 · R11 · R12,
# 관측 실패는 R3 · R18, unclaimed 는 R16, 기계 출력의 판정 도달은 R24, 메모 위치는 R6
# (plan 「요구 → 테스트」).

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
# 앵커는 D2(후보와 배정 — 범위 공지)와 D3(HEAD 축 실행) 사이에 있어야 한다.
# 두 헤딩이 없으면 0 이 되어 아래 비교가 실패한다(창 붕괴가 통과로 읽히지 않는다).
anchor_line=$(first_line "$new_anchor")
d2_marker=$(first_line '^## D2 '); d3_marker=$(first_line '^## D3 ')
if [[ "$d2_marker" -gt 0 && "$d3_marker" -gt "$d2_marker" && "$anchor_line" -gt "$d2_marker" && "$anchor_line" -lt "$d3_marker" ]]; then
  echo "PASS: 앵커가 D2($d2_marker)와 D3($d3_marker) 사이 ($anchor_line)"
else
  echo "FAIL: 앵커 위치 ($anchor_line, D2=$d2_marker D3=$d3_marker)"; fail=$((fail + 1))
fi

# ── T22 / AC31 / M12: 호출 주체 — run-test-selection.sh 가 verifier dispatch 블록 밖 ──
echo "== 호출 주체 불변식"
# 대상 소멸 (Task 7) — "run-test-selection.sh 호출이 verifier dispatch 블록
# (R5a³..R5b) 안에 0회" 는 그 창 자체가 사라져 대응물이 없다(verifier 가 삭제돼
# 그 턴이 존재하지 않는다). 아래 authoritative 문장 존재 검사는 keep — 차등 절차
# 머리말(호출 주체 불변식)이 그 문장을 그대로 남긴다.
if grep -qF '이 호출 결과가 authoritative' "$SKILL_MD"; then
  echo "PASS: authoritative 문장 존재"
else
  echo "FAIL: authoritative 문장 부재"; fail=$((fail + 1))
fi

# 대상 소멸 (Task 7) — "== 폴백 R5b 미실행" 전체(polarity_ok/bad · rec_ok · route_ok
# · route_stale 5축)가 이 자리에 있었다. 옛 런타임 샌드박스 kill switch
# 로 R4 가 건너뛰고 R5b 가 `unrun` 전량이 되던 시나리오 자체가 사라졌다 — 새
# kill switch(`DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST`)는 ② 전체를 건너뛴다
# (R22 — test_differential_procedure.sh · test_runner_adapters.sh). 관측 실패가 `unrun`
# 으로 남는 것은 R3 행동 테스트가 잰다.

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
