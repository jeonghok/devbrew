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
  python3 "$S/verdict.py" --reason no-such-reason >/dev/null 2>&1
  assert_eq "$?" "4" "V1 — 열거 밖 사유는 exit 4"
  assert_contains "$(flat '### Step 4.5 — Surface the verdict')" 'You do not choose or edit it (V1)' \
    "V1 — SKILL 은 판정 줄을 고르거나 고치지 말라고 한다"
}

case_v2_synth_failure_is_not_clean() {
  assert_grep "$(flat '### Step 4 — synthesis (after the differential test)')" \
    '\*\*rc 를 소비하라\.\*\* rc 가 0 이 아니거나 `\$RV/synth\.out` 이 비어 있으면 이 실행은 \*\*clean 이 아니다\*\*' \
    "V2 — SKILL 이 합성기 rc·빈 stdout 을 clean 으로 읽지 말라고 한다"
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
  assert_grep "$(sec '### Step 1b — changes-exist signal')" \
    'It is \*\*never\*\* copied from `check-review-scope.sh`' "V7 — 개수는 독립 신호에서 베끼지 않는다"
}

case_v9_one_pass_no_code_edits() {
  # V9 — 한 실행은 한 번 지나고 저장소의 코드를 고치지 않는다. 색인 행 · R1 문장 · 고칠 목록 기록을 잰다.
  local idx r1
  idx="$(sec '## Requirement index')"
  assert_eq "$(printf '%s\n' "$idx" | grep -cxF '| V9 한 실행은 한 번 지나고 저장소의 코드를 고치지 않는다 | Flow · Step 4.5 고칠 목록 · Law 2 |')" "1" \
    "V9 — Requirement index 에 V9 행이 줄 전체로 한 번 있다"
  r1="$(awk '/^\*\*R1 \(Law 2\):\*\*/{f=1} f&&/^\*\*R2 /{exit} f' "$SKILL" | tr '\n' ' ' | tr -s ' ')"
  assert_eq "$(printf '%s\n' "$r1" | grep -oF 'You do not edit working-tree files in this run — the only repository write is the intent-critic answer commit.' | grep -c .)" "1" \
    "V9 — R1 이 이 실행은 작업 트리를 고치지 않고 저장소 쓰기는 intent-critic 답 커밋 하나뿐이라고 문장째 한 번 말한다"
  assert_not_contains "$r1" 'Fix-loop' "V9 — R1 이 고치기 반복의 관문을 부르지 않는다(위 양성 짝)"
  # 고칠 목록 — Final verdict 기록 펜스가 Step 4.5 의 목록을 `## 고칠 목록` 절로 옮긴다(차등 테스트 앞).
  local d rd fv sid=v9fixlist01 lf ld
  d="$T/v9"; mkdir -p "$d"
  git -C "$d" init -q -b trunk \
    && git -C "$d" -c core.hooksPath=/dev/null -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q --allow-empty -m init
  rd="$(git -C "$d" rev-parse --show-toplevel)/.claude/quality-gates/$sid"; mkdir -p "$rd"
  fv="$(sec '## Final verdict' | awk '/^```bash$/{f=1;b="";next} f&&/^```$/{f=0; if (b ~ /## 판정/) {printf "%s", b; exit}; next} f{b=b $0 "\n"}')"
  assert_contains "$fv" "cat <<'QG_FIX_LIST'" "V9 — Final verdict 기록 펜스가 고칠 목록을 따옴표 here-doc 으로 받는다"
  cat > "$T/v9-fill.py" <<'PY'
import sys
f = sys.stdin.read().split("\n")
# 여는 줄의 따옴표 꼴은 가리지 않는다 — 따옴표가 빠진 펜스도 채워 돌려야 아래 명령 치환 단언이 그 결함을 잰다.
i = next(k for k, l in enumerate(f) if l.endswith(("<<'QG_FIX_LIST'", '<<"QG_FIX_LIST"', "<<QG_FIX_LIST")))
j = f.index("QG_FIX_LIST", i + 1)
body = ["### 막는 지적", "", "- IMPORTANT src/a.py:41 — 키를 검증하지 않는다 · 고칠 방법: $(touch PWNED)", "",
        "### 제안", "", "(없음)", "", "### 차등 회귀", "", "(없음)"]
print("\n".join(f[:i + 1] + body + f[j:]).replace("<session-id>", sys.argv[1]).replace("<N>", "1"))
PY
  printf '%s\n' "$fv" | python3 -I "$T/v9-fill.py" "$sid" > "$T/v9-fv.sh"
  printf 'verdict: defect\nqg: defect · 막는 지적 1 · 선택 0 · 차등 새 실패 0 · e2e 안 함 · abc1234\n' > "$rd/verdict.out"
  printf -- '---\nsession_id: "%s"\n---\n\n# qg result\n' "$sid" > "$rd/result.md"
  (cd "$d" && CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$T/v9-fv.sh") >/dev/null 2>&1
  lf=$(grep -n '^## 고칠 목록$' "$rd/result.md" | cut -d: -f1); ld=$(grep -n '^## 차등 테스트$' "$rd/result.md" | cut -d: -f1)
  if [ -n "$lf" ] && [ -n "$ld" ] && [ "$lf" -lt "$ld" ]; then ok "V9 — result.md 의 ## 고칠 목록 이 ## 차등 테스트 앞에 있다"
  else no "V9 — result.md 절 순서 (고칠 목록=$lf 차등=$ld)"; fi
  assert_eq "$(grep -c '^## 고칠 목록$' "$rd/result.md")" "1" "V9 — ## 고칠 목록 절은 하나다"
  assert_contains "$(cat "$rd/result.md")" '- IMPORTANT src/a.py:41 — 키를 검증하지 않는다 · 고칠 방법: $(touch PWNED)' "V9 — 고칠 목록의 줄이 글자 그대로 옮겨진다"
  assert_eq "$(ls "$d" | grep -c PWNED)" "0" "V9 — 고칠 목록 안의 명령 치환이 실행되지 않는다(따옴표 here-doc)"
  assert_file_absent "$rd/result.md" '^## (제외 패치|추가 반복)$' "V9 — 고치기 반복의 기록 절이 없다(위 양성 짝)"
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

for c in case_v1_verdict_vocabulary_is_closed case_v2_synth_failure_is_not_clean \
         case_v4_missing_recritic_is_not_clean case_v5_security_absent_is_not_certified \
         case_v6_codex_output_cleared_and_degrade_disclosed case_v7_scope_count_is_independent \
         case_v9_one_pass_no_code_edits \
         case_v10_backstop_called_directly case_v11_identity_grammar_fullmatch case_v12_dispatches_carry_project_dir \
         case_ac9_intent_line_printed_once case_p21_intent_never_lowers_or_skips; do
  "$c"
done
finish
