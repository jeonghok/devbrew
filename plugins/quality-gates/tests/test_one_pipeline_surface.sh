#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/quality-pipeline/references/differential-test.md plugins/quality-gates/commands/qg.md
# test_one_pipeline_surface.sh — 한 파이프라인의 표면 (설계 §6.1 · §6.4.4 · §6.5.1, AC1 · AC2).
#
# 음의 락(옛 게이트 · verifier 토큰 부재)은 대상을 통째로 지워도 GREEN 이다 — 그래서 양의
# 짝(새 골격의 존재 · 스텝 집합 · 순서)을 함께 둔다. 코퍼스는 오케스트레이터가 읽는 세 파일이다.
set -u
# test_guards_coverage_bidirectional.sh 가 읽는다 — 이 락이 여는 파일(리포 상대)을 낸다.
[ "${1:-}" = "--emit-scanned" ] && { printf '%s\n' \
  plugins/quality-gates/skills/quality-pipeline/SKILL.md \
  plugins/quality-gates/skills/quality-pipeline/references/differential-test.md \
  plugins/quality-gates/commands/qg.md; exit 0; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
REF="$PLUGIN_ROOT/skills/quality-pipeline/references/differential-test.md"
QGMD="$PLUGIN_ROOT/commands/qg.md"

assert_file_absent_ci() {  # 대소문자 무관 변형 — shared/tests/assert.sh 는 이 라운드의
  # 수정 대상 밖이라(carry-notes 동결) 로컬로 둔다. assert_file_absent 와 같은 모양에 -i 만 더한다.
  local f="$1" pat="$2" msg="$3"
  if [ ! -f "$f" ]; then no "$msg (파일 없음: $f)"; return; fi
  if grep -qEi -- "$pat" "$f"; then no "$msg (금지 패턴이 있다[대소문자 무관]: $pat)"
  else ok "$msg"; fi
}

case_old_surface_absent() {
  # 파일 단위 제외 없이 — 이 세 파일에 이 토큰이 설 자리는 없다(설계 §6.4.4 일곱 · §6.5.1).
  #
  # PASS/FAIL 경계 정규식은 대소문자 그대로 둔다 — `pass`/`fail`/`fail-open`/`fail-closed`
  # 는 차등 테스트의 현재 어휘(개별 unit 결과·정책 이름)로 레퍼런스 전체에 수십 회
  # 등장한다. -i 를 붙이면 이 락이 자기 코퍼스 대부분에서 RED 가 된다(실측: fix round 1
  # 에서 grep -i 로 확인 — SKILL.md 6곳 · differential-test.md 20+곳 · qg.md 1곳).
  # 옛 판정 어휘(대문자 PASS/FAIL, verdict.py 밖 금지)와 새 소문자 pass/fail 어휘를 가르는
  # 것이 바로 이 대소문자 구분이다 — 둘을 섞으면 락의 이빨이 아니라 락 자체가 무너진다.
  local tok f
  for tok in '(^|[^A-Za-z_])PASS([^A-Za-z_]|$)' '(^|[^A-Za-z_-])FAIL([^A-Za-z_:]|$)'; do
    for f in "$SKILL" "$REF" "$QGMD"; do
      assert_file_absent "$f" "$tok" "$(basename "$f") 에 '$tok' 이 없다"
    done
  done

  # 나머지 토큰은 다단어 식별자/아키텍처 이름이라 대소문자 충돌 위험이 낮다 — -i 로 대소문자
  # 변형(RUNTIME GATE · runtime gate 등)도 잡는다. 'review gate'/'runtime gate' 만은
  # 경계를 보강한다 — SKILL.md:413 의 "hard-review gate"(CLAUDE.md 의 무관한 fan-out
  # 합의 게이트 역사 서술)가 하이픈 앞 소문자 'review gate' 로 -i 하에서 오탐되기 때문에
  # 앞이 `[-A-Za-z]` 가 아니어야 한다는 경계를 둔다.
  for tok in 'runtime-verifier' 'detect-runtime' 'create-sandbox' 'mutation-guard' \
             'effective_skip_runtime' 'block_policy' 'approved_surfaces' 'resolution_iter' \
             'NEEDS_RESOLUTION' 'SKIP_WITH_EVIDENCE' 'Decision [12]' \
             'RUNTIME_MAX_RESOLUTIONS' 'DISABLE_RUNTIME_SANDBOX' \
             '(^|[^-A-Za-z])runtime gate' '(^|[^-A-Za-z])review gate' \
             'runtime-gate\.md' 'Tier [ABC]' 'ac_coverage' \
             'Runtime 게이트' 'Review 게이트'; do
    for f in "$SKILL" "$REF" "$QGMD"; do
      assert_file_absent_ci "$f" "$tok" "$(basename "$f") 에 '$tok' 이 없다(대소문자 무관)"
    done
  done
}

case_new_skeleton_present() {
  assert_file_grep "$SKILL" '^## Flow$'                             "SKILL 에 흐름 절이 있다"
  assert_file_grep "$SKILL" '^## Differential test$'                "SKILL 에 차등 테스트 포인터 절이 있다"
  assert_file_grep "$SKILL" 'references/differential-test\.md'      "포인터가 새 레퍼런스를 가리킨다"
  assert_eq "$(grep -E '^## ' "$SKILL" | tr '\n' '|')" \
    "## Preflight|## Flow|## Review|## Differential test|## Fix-loop|## Final verdict|## kill switch|## Rules|## Requirement index|" \
    "K-8 — SKILL 의 ## 절이 이 순서다(③ 은 Publish, ④ 는 e2e 를 끼우며 이 핀을 고친다)"
  assert_file_grep "$REF"   '^## Differential test$'                "레퍼런스 머리 헤딩(스플라이스 앵커)"
  assert_file_grep "$REF"   'scripts/seal-worktree\.sh" seal'       "HEAD 축은 봉인에서 선다"
  assert_file_grep "$REF"   'scripts/qg-worktree\.sh" create-head'  "HEAD 축 트리를 만든다"
  assert_file_grep "$REF"   'scripts/qg-worktree\.sh" create-baseline' "기준선 축 트리를 만든다"
  assert_file_grep "$REF"   'scripts/diff-test-results\.py" --aggregate' "어댑터 집계가 남아 있다"
  assert_file_grep "$REF"   'scripts/check_qa_ledger\.py"'          "원장 구조 게이트가 남아 있다(R-AG)"
  # qg.md 자체의 양의 짝 — 세 파일 중 하나가 지워져도 이 절대 안 걸리던 공백을 메운다.
  assert_file_grep "$QGMD"  'one pipeline'                          "qg.md 가 '한 파이프라인' 정체성을 말한다"
  assert_file_grep "$QGMD"  'Skill\("quality-gates:quality-pipeline"\)' "qg.md 가 새 skill 을 호출한다"
  assert_file_grep "$QGMD"  'not-certified'                         "qg.md 가 새 판정 어휘를 쓴다"
}

case_reference_step_set() {
  # 살아남는 스텝 전부 · 지워진 스텝 없음 — 헤딩에서 도출해 핀과 대조한다(∀).
  local got
  got=$(grep -oE '^\*\*Step R[-0-9a-z]+' "$REF" | sed 's/^\*\*Step //' | LC_ALL=C sort -u | tr '\n' ' ')
  assert_eq "$got" "R-init R1a R1b R2 R3 R4 R5b R6 R8 " "레퍼런스의 스텝 집합(R5a · R7 · R9 없음)"
}

case_pipeline_order() {
  # C1 — 리뷰(①) → 차등 테스트(②) → 합성·판정(③). 흐름 절 안에서 이 순서로 처음 나온다.
  local body prev=0 n m good=1
  body=$(awk '/^## Flow$/{f=1;next} f&&/^## /{exit} f' "$SKILL")
  for m in ① ② ③; do
    n=$(printf '%s\n' "$body" | grep -n "$m" | head -1 | cut -d: -f1)
    if [ -z "$n" ] || [ "$n" -le "$prev" ]; then good=0; fi
    prev=${n:-0}
  done
  assert_eq "$good" "1" "흐름 절이 ① 리뷰 → ② 차등 테스트 → ③ 합성·판정 순서로 적혀 있다 (C1)"
  assert_grep "$(printf '%s\n' "$body" | grep '①')" '리뷰' "① 은 리뷰다 (C1 — 리뷰가 차등보다 먼저)"
}

case_no_gate_scope_question() {
  # AC1 — 게이트 범위를 묻는 결정 도구가 없다. 결정 도구 리터럴의 header 전수에서 도출한다.
  local headers
  headers=$(grep -oE 'header: "[^"]*"' "$SKILL" "$REF" | sed 's/.*header: //' | LC_ALL=C sort -u | tr '\n' ' ')
  assert_not_grep "$headers" 'Gate scope|Runtime scope|Runtime resolve' "게이트 · 런타임 범위 질문이 없다"
  assert_grep     "$headers" 'qg iter N'                              "fix-loop 결정 도구는 남아 있다(양의 짝)"
}

case_reference_has_no_design_section_pointers() {
  # 레퍼런스는 모델이 읽고 행동하는 산출물이다. 설치본에 없는 설계 문서의 절 번호(§)를
  # 싣지 않는다 — 모델이 없는 절을 찾게 된다. 설계를 가리켜야 하면 개념으로 적는다.
  assert_eq "$(grep -c '§' "$REF")" "0" "레퍼런스에 § 절 포인터가 0개"
  # 양의 짝 — 번호를 빼면서 잔여 결함의 공시까지 지우지 않았다
  assert_file_grep "$REF" '이 축은 잔여 결함이며 \*\*열려 있다\*\*' "R-init 잔여 결함 공시가 남았다"
  assert_file_grep "$REF" '^\*\*남은 것\(정직한 잔여\):\*\*' "R8 정직한 잔여 공시가 남았다"
  assert_file_grep "$REF" '잔여 결함과 같은 축이며 열려 있다' "custody 축 공시가 남았다"
  assert_file_grep "$REF" '빈 스코프 축' "행 0개 축 공시가 남았다"
}

for c in case_old_surface_absent case_new_skeleton_present case_reference_step_set \
         case_pipeline_order case_no_gate_scope_question \
         case_reference_has_no_design_section_pointers; do
  "$c"
done
finish
