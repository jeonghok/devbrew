#!/usr/bin/env bash
# test_v_requirements.sh — 요구 V1~V12(spec §요구 목록 「리뷰·판정」)를 번호로 잰다.
#
# 케이스 이름이 요구 번호를 싣는다. 각 케이스는 그 교훈이 «지금도 참인지»를 실제 스크립트를
# 돌리거나 SKILL 의 그 자리를 읽어 잰다. 더 깊은 변이 락은 옆 파일들이 진다 — 여기는 색인이자
# 마지막 그물이다(지우면 조용히 통과하는 것을 하나씩 막는다).
#
# SKILL 락은 전부 «자기 절 창» 안에서만 잰다 — 제목·frontmatter·다른 절의 같은 문구로는 만족되지 않는다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
S="$PLUGIN_ROOT/scripts"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
. "$SCRIPT_DIR/lib/recritic_fixture.sh"
export PYTHONDONTWRITEBYTECODE=1
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
# 제목 줄이 정확히 $1 인 절의 본문(다음 ##/### 제목 전까지).
sec() { awk -v h="$1" '$0==h{f=1;next} f&&/^#{2,3} /{exit} f' "$SKILL"; }
# 한 줄로 펴서 문단이 줄바꿈으로 갈라져도 잰다.
flat() { sec "$1" | tr '\n' ' ' | tr -s ' '; }
# 굵은 글씨 문단 창: 시작 정규식 줄부터 끝 정규식 줄 앞까지.
win() { awk -v s="$1" -v e="$2" '$0 ~ s{f=1;next} f&&$0 ~ e{exit} f' "$SKILL" | tr '\n' ' ' | tr -s ' '; }

case_v1_verdict_vocabulary_is_closed() {
  assert_eq "$(python3 -c "import sys; sys.path.insert(0,'$S'); import verdict; print(' '.join(verdict.VALUES))")" \
    "defect not-certified clean" "V1 — 판정값은 셋이고 우선순위 순서다"
  python3 "$S/verdict.py" --reason no-such-reason >/dev/null 2>&1
  assert_eq "$?" "4" "V1 — 열거 밖 사유는 exit 4"
  local out rc
  out=$(python3 "$S/verdict.py" --line --blocking x --optional 0 --new-failures 0 --excluded 0 --iter 1 --sha abc1234 2>/dev/null)
  rc=$?
  assert_eq "$rc" "4" "V1 — 비정수 개수는 exit 4 (_count 경로)"
  assert_eq "$out" "" "V1 — 비정수 개수는 stdout 을 비운다"
  out=$(python3 "$S/verdict.py" --line --blocking 1 --optional 0 --new-failures 0 --excluded 0 --iter 1 --sha abc1234 2>/dev/null)
  assert_grep "$out" '^qg: clean · 막는 지적 1 · 선택 0 · 차등 새 실패 0 · 제외 패치 0 · iter 1 · abc1234$' \
    "V1 — 정수 개수는 판정 줄이 된다(양성 짝)"
  assert_contains "$(flat '### Step 4.5 — Surface the verdict')" 'You do not choose or edit it (V1)' \
    "V1 — SKILL 은 판정 줄을 고르거나 고치지 말라고 한다"
}

case_v2_synth_failure_is_not_clean() {
  local out; out=$(python3 "$S/synthesize_findings.py" --findings "$T/none.yaml" --emit-verdict 2>/dev/null)
  assert_not_grep "$out" '^verdict: clean$' "V2 — 못 읽는 findings 는 clean 이 아니다"
  assert_grep "$(flat '### Step 4 — synthesis (after the differential test)')" \
    '\*\*rc 를 소비하라\.\*\* rc 가 0 이 아니거나 `\$RV/synth\.out` 이 비어 있으면 이 iteration 은 \*\*clean 이 아니다\*\*' \
    "V2 — SKILL 이 합성기 rc·빈 stdout 을 clean 으로 읽지 말라고 한다"
}

case_v3_malformed_finding_blocks() {
  mkdir -p "$T/v3"; printf -- '- "CRITICAL: bare"\n' > "$T/v3/findings.yaml"
  rf_prep "$T/v3"; rf_reply "$T/v3" 'verdicts: []'
  local out; out=$(rf_synth "$T/v3" --emit-verdict 2>/dev/null)
  assert_grep "$out" '^reason: findings-lost$' "V3 — 파손 finding 은 findings-lost"
  # 원장의 hold 가 사유를 따로 내므로, «센다»(dropped_malformed)는 이 공시 줄과 차단 문구로만 보인다.
  assert_grep "$out" '^1 finding\(s\) dropped as malformed .*이 실행은 clean이 아니다' \
    "V3 — 버려진 파손 finding 은 세어 공시한다(dropped as malformed)"
}

case_v4_missing_recritic_is_not_clean() {
  mkdir -p "$T/v4"; printf '[]\n' > "$T/v4/findings.yaml"; rf_prep "$T/v4"
  local out; out=$(python3 "$S/synthesize_findings.py" --findings "$T/v4/findings.yaml" \
    --recritic "$T/v4/none.txt" --recritic-map "$T/v4/map.json" --emit-verdict 2>/dev/null)
  assert_grep "$out" '^reason: angle-absent$' "V4 — 재비판 출력 부재는 angle-absent"
  assert_grep "$(flat '### Step 3.5 — re-critique (판정 각도)')" \
    'If the dispatch failed or returned nothing, do not create the file — Step 4 reads the absence as the adjudication angle.s death and the verdict becomes `not-certified \(angle-absent\)` \(V4\)' \
    "V4 — SKILL 은 재비판 출력 부재(recritic.txt 없음)를 clean 으로 읽지 않는다"
}

case_v5_security_absent_is_not_certified() {
  mkdir -p "$T/v5"; printf '[]\n' > "$T/v5/findings.yaml"; rf_prep "$T/v5"; rf_reply "$T/v5" 'verdicts: []'
  printf 'security: absent\nadjudication: filled\ndifferent-premise: filled\n' > "$T/v5/angles.txt"
  local out; out=$(rf_synth "$T/v5" --emit-verdict --angles "$T/v5/angles.txt")
  assert_grep "$out" '^reason: angle-absent$' "V5 — 보안 각도 부재는 angle-absent"
}

case_v6_codex_output_cleared_and_degrade_disclosed() {
  local out="$T/v6.yaml"; printf 'findings: []\nmeta:\n  codex_failed: false\n' > "$out"; chmod 444 "$out"
  mkdir -p "$T/v6ro"; chmod 555 "$T/v6ro"
  bash "$S/run_codex_reviewer.sh" /dev/null "$PLUGIN_ROOT" "$T/v6ro/out.yaml" >/dev/null 2>&1
  assert_eq "$?" "3" "V6 — 산출물을 못 쓰면 exit 3 (호출자가 지운다)"
  chmod 755 "$T/v6ro"
  assert_grep "$(flat '#### codex 결과 판정 (러너가 돌고 난 뒤)')" \
    'degrade 다 — `findings: \[\]` 만 보고 clean 으로 읽지 않는다 \(`indeterminate ≠ clean`\)' \
    "V6 — codex_failed 키 부재는 degrade"
  assert_grep "$(flat '### Step 3 — reviewers')" \
    '`rc == 3`, delete the output file before reading anything from it \(`rm -f <output_path>`\)' \
    "V6 — 러너 rc 3 이면 산출물을 지운다(앞 실행 출력을 재사용하지 않는다)"
}

case_v7_scope_count_is_independent() {
  assert_grep "$(sec '### Step 4 — synthesis (after the differential test)')" \
    'resolved_scope_file_count == 0.*changes_exist == yes.*scope-empty' "V7 — 빈 범위 floor 행"
  assert_grep "$(sec '### Step 1b — changes-exist signal (N = 1 only)')" \
    'It is \*\*never\*\* copied from `check-review-scope.sh`' "V7 — 개수는 독립 신호에서 베끼지 않는다"
}

case_v8_missing_severity_is_not_optimistic() {
  mkdir -p "$T/v8"; printf -- '- {agent: r, file: a.py, line: 1, summary: s}\n' > "$T/v8/findings.yaml"
  rf_prep "$T/v8"; rf_reply "$T/v8" 'verdicts:
  - f: f1
    verdict: confirm'
  local out; out=$(rf_synth "$T/v8" --emit-verdict 2>/dev/null)
  assert_grep "$out" '^verdict: defect$' "V8 — severity 결측은 막는 지적으로 남는다"
}

case_v9_retry_paths_are_confined() {
  local b; b="$(sec '### Retry: file-write safety')"
  assert_contains "$b" 'os.path.commonpath([root, candidate]) != root' "V9 — Retry 경로를 project_dir 안에 가둔다"
  assert_contains "$(sec '### Retry: error handling')" 'Retry failed at <file>' "V9 — Edit 실패는 묻는다"
}

case_v10_backstop_called_directly() {
  assert_contains "$(sec '## Differential test')" 'Read ${CLAUDE_PLUGIN_ROOT}/skills/quality-pipeline/references/differential-test.md' \
    "V10 — 차등 테스트는 오케스트레이터가 레퍼런스대로 직접 돈다"
  assert_not_grep "$(sec '## Differential test')" 'subagent_type' "V10 — 차등 실행을 subagent 에 맡기지 않는다"
}

case_v11_identity_grammar_fullmatch() {
  mkdir -p "$T/v11"; printf -- '- {agent: "scout\\n", file: a.py, line: 1, severity: IMPORTANT, summary: s}\n' > "$T/v11/findings.yaml"
  rf_prep "$T/v11"; rf_reply "$T/v11" 'verdicts: []'
  printf 'security: filled\nadjudication: filled\ndifferent-premise: filled\n' > "$T/v11/angles.txt"
  rf_synth "$T/v11" --emit-verdict --angles "$T/v11/angles.txt" >/dev/null 2>&1
  assert_eq "$?" "4" "V11 — 개행 꼬리 저자 이름은 신원 문법(fullmatch)에서 걸린다"
}

case_v12_dispatches_carry_project_dir() {
  local n a
  for a in security-reviewer code-recritic; do
    # Agent 리터럴 하나(subagent_type 줄부터 닫는 `})` 까지) 안에서만 project_dir 를 찾는다.
    n=$(awk -v name="subagent_type: \"quality-gates:$a\"" 'index($0,name){f=1} f&&/project_dir/{print "y"; exit} f&&/^\}\)/{exit}' "$SKILL")
    assert_eq "$n" "y" "V12 — $a dispatch 가 project_dir 를 싣는다"
  done
}

# ── SKILL 본문 의무(Task 6 리뷰가 이월한 것) — 각자 자기 절 창 안에서 ──
case_ac9_intent_line_printed_once() {
  assert_grep "$(win '^\*\*P3 — intent source' '^## Flow')" 'Print exactly one line for the whole run \(AC9\)' \
    "AC9 — intent: 줄은 실행 전체에서 정확히 한 줄이다"
}

case_p21_intent_never_lowers_or_skips() {
  assert_grep "$(win '^\*\*P3 — intent source' '^## Flow')" \
    'it never instructs the reviewers, and it never lowers or skips a finding' \
    "P21 — 의도 텍스트는 지적을 낮추거나 건너뛰게 하지 못한다"
}

case_ac7_fix_loop_override_and_excluded_log() {
  local w; w="$(flat '### Fix-loop decision')"
  assert_grep "$w" 'Each number typed there flips that item \(적용 ↔ 제외\)\. A user.s change overrides your classification, in either direction' \
    "AC7 — 사용자가 적용/제외를 뒤집을 수 있고 그 변경이 분류를 이긴다"
  assert_grep "$w" 'For every 제외 item append one line to `\$RD/excluded\.md`: `- iter <N> · #<k> · <file> · <사유>`' \
    "AC7 — 제외 항목은 excluded.md 에 한 줄씩 남는다"
}

case_max_iter_cap_is_five() {
  assert_grep "$(flat '### Max-iter decision')" 'question: "qg reached max 5 iterations\.' \
    "P18 — Max-iter 질문이 상한 5 를 말한다"
}

for c in case_v1_verdict_vocabulary_is_closed case_v2_synth_failure_is_not_clean case_v3_malformed_finding_blocks \
         case_v4_missing_recritic_is_not_clean case_v5_security_absent_is_not_certified \
         case_v6_codex_output_cleared_and_degrade_disclosed case_v7_scope_count_is_independent \
         case_v8_missing_severity_is_not_optimistic case_v9_retry_paths_are_confined \
         case_v10_backstop_called_directly case_v11_identity_grammar_fullmatch case_v12_dispatches_carry_project_dir \
         case_ac9_intent_line_printed_once case_p21_intent_never_lowers_or_skips \
         case_ac7_fix_loop_override_and_excluded_log case_max_iter_cap_is_five; do
  "$c"
done
finish
