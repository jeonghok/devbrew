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

case_old_surface_absent() {
  # 파일 단위 제외 없이 — 이 세 파일에 이 토큰이 설 자리는 없다(설계 §6.4.4 일곱 · §6.5.1).
  local tok f
  for tok in 'runtime-verifier' 'detect-runtime' 'create-sandbox' 'mutation-guard' \
             'effective_skip_runtime' 'block_policy' 'approved_surfaces' 'resolution_iter' \
             'NEEDS_RESOLUTION' 'SKIP_WITH_EVIDENCE' 'Decision [12]' \
             'RUNTIME_MAX_RESOLUTIONS' 'DISABLE_RUNTIME_SANDBOX' 'Runtime gate' \
             'Review gate' 'runtime-gate\.md' 'Tier [ABC]' 'ac_coverage' \
             '(^|[^A-Za-z_])PASS([^A-Za-z_]|$)' '(^|[^A-Za-z_-])FAIL([^A-Za-z_:]|$)'; do
    for f in "$SKILL" "$REF" "$QGMD"; do
      assert_file_absent "$f" "$tok" "$(basename "$f") 에 '$tok' 이 없다"
    done
  done
}

case_new_skeleton_present() {
  assert_file_grep "$SKILL" '^## Pipeline$'                         "SKILL 에 파이프라인 절이 있다"
  assert_file_grep "$SKILL" '^## Differential test$'                "SKILL 에 차등 테스트 포인터 절이 있다"
  assert_file_grep "$SKILL" 'references/differential-test\.md'      "포인터가 새 레퍼런스를 가리킨다"
  assert_file_grep "$SKILL" '^\*\*Step 1c '                         "Review 절에 ② 의 자리(Step 1c)가 있다"
  assert_file_grep "$REF"   '^## Differential test$'                "레퍼런스 머리 헤딩(스플라이스 앵커)"
  assert_file_grep "$REF"   'scripts/seal-worktree\.sh" seal'       "HEAD 축은 봉인에서 선다"
  assert_file_grep "$REF"   'scripts/qg-worktree\.sh" create-head'  "HEAD 축 트리를 만든다"
  assert_file_grep "$REF"   'scripts/qg-worktree\.sh" create-baseline' "기준선 축 트리를 만든다"
  assert_file_grep "$REF"   'scripts/diff-test-results\.py" --aggregate' "어댑터 집계가 남아 있다"
  assert_file_grep "$REF"   'scripts/check_qa_ledger\.py"'          "원장 구조 게이트가 남아 있다(R-AG)"
}

case_reference_step_set() {
  # 살아남는 스텝 전부 · 지워진 스텝 없음 — 헤딩에서 도출해 핀과 대조한다(∀).
  local got
  got=$(grep -oE '^\*\*Step R[-0-9a-z]+' "$REF" | sed 's/^\*\*Step //' | LC_ALL=C sort -u | tr '\n' ' ')
  assert_eq "$got" "R-init R1a R1b R2 R3 R4 R5b R6 R8 " "레퍼런스의 스텝 집합(R5a · R7 · R9 없음)"
}

case_pipeline_order() {
  # 설계 §6.1 — ② 가 ③ 보다 앞(load-bearing). 파이프라인 절 안에서 ①→⑤ 가 이 순서로 처음 나온다.
  local body prev=0 n m good=1
  body=$(awk '/^## Pipeline$/{f=1;next} f&&/^## /{exit} f' "$SKILL")
  for m in ① ② ③ ④ ⑤; do
    n=$(printf '%s\n' "$body" | grep -n "$m" | head -1 | cut -d: -f1)
    if [ -z "$n" ] || [ "$n" -le "$prev" ]; then good=0; fi
    prev=${n:-0}
  done
  assert_eq "$good" "1" "파이프라인 절이 ①→②→③→④→⑤ 순서로 적혀 있다"
}

case_no_gate_scope_question() {
  # AC1 — 게이트 범위를 묻는 결정 도구가 없다. 결정 도구 리터럴의 header 전수에서 도출한다.
  local headers
  headers=$(grep -oE 'header: "[^"]*"' "$SKILL" "$REF" | sed 's/.*header: //' | LC_ALL=C sort -u | tr '\n' ' ')
  assert_not_grep "$headers" 'Gate scope|Runtime scope|Runtime resolve' "게이트 · 런타임 범위 질문이 없다"
  assert_grep     "$headers" 'qg iter N'                              "fix-loop 결정 도구는 남아 있다(양의 짝)"
}

for c in case_old_surface_absent case_new_skeleton_present case_reference_step_set \
         case_pipeline_order case_no_gate_scope_question; do
  "$c"
done
finish
