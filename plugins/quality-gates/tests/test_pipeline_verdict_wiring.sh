#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/quality-pipeline/references/differential-test.md plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/scripts/verdict.py plugins/quality-gates/scripts/angles.py plugins/quality-gates/scripts/recritic_bridge.py plugins/quality-gates/tests/lib/recritic_fixture.sh
# test_pipeline_verdict_wiring.sh — 판정 상시 배선 (설계 §6.1 ⑤ · §6.3.5 · §6.4.3, AC2 · AC8–AC12).
#
# 합성기 쪽 총 함수는 test_verdict_vocabulary.sh · test_angle_coverage.sh 가 잰다. 이 락은
# 오케스트레이터가 그것을 «실제로 부르는가»를 잰다 — 부르지 않으면 두 락의 GREEN 은 락
# 안에서만 참이다.
#
# 잴 수 없는 것: 모델이 각도 파일을 «참되게» 쓰는가(설계 §15-4). 이 락은 모양과 합성기의
# 행동만 잰다.
set -u
[ "${1:-}" = "--emit-scanned" ] && { printf '%s\n' \
  plugins/quality-gates/skills/quality-pipeline/SKILL.md \
  plugins/quality-gates/skills/quality-pipeline/references/differential-test.md \
  plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/scripts/verdict.py \
  plugins/quality-gates/scripts/angles.py plugins/quality-gates/scripts/recritic_bridge.py \
  plugins/quality-gates/tests/lib/recritic_fixture.sh; exit 0; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"
. "$SCRIPT_DIR/lib/recritic_fixture.sh"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
REF="$PLUGIN_ROOT/skills/quality-pipeline/references/differential-test.md"
V="$PLUGIN_ROOT/scripts/verdict.py"
export PYTHONDONTWRITEBYTECODE=1

case_every_synth_call_emits_verdict_and_angles() {
  local got
  got=$(python3 - "$SKILL" "$REF" <<'PY'
import re, sys
calls = bad = 0
for path in sys.argv[1:]:
    text = open(path, encoding="utf-8").read()
    for body in re.findall(r"^[ \t]*```bash\n(.*?)^[ \t]*```[ \t]*$", text, re.M | re.S):
        if "synthesize_findings.py" not in body:
            continue
        calls += 1
        if "--emit-verdict" not in body or "--angles" not in body:
            bad += 1
print(f"CALLS:{calls}")
print(f"BAD:{bad}")
PY
)
  assert_grep "$got" '^CALLS:[1-9]' "합성기를 부르는 펜스가 하나 이상 있다(0 이면 아래가 공허하다)"
  assert_grep "$got" '^BAD:0$'      "합성기를 부르는 펜스 ∀ 가 --emit-verdict 와 --angles 를 싣는다"
}

case_blocking_angle_dispatches_are_fail_closed() {
  # §6.3.5 — 보안 · 판정 각도 디스패치는 fail-closed. 처분 줄은 dispatch 블록 바로 안에 있다.
  local got
  got=$(python3 - "$SKILL" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
for agent in ("quality-gates:security-reviewer", "quality-gates:doc-recritic"):
    m = re.search(r'subagent_type:\s*"' + re.escape(agent)
                  + r'",?\s*\n\s*//\s*\*\*처분\*\*\s*—\s*consumer=\S+\s*·\s*fail-(open|closed)', text)
    print(f"{agent}:{m.group(1) if m else 'MISSING'}")
PY
)
  assert_grep "$got" '^quality-gates:security-reviewer:closed$' "보안 각도 디스패치는 fail-closed"
  assert_grep "$got" '^quality-gates:doc-recritic:closed$'      "판정 각도 디스패치는 fail-closed"
}

case_reason_literals_are_closed_and_pinned() {
  # SKILL · 레퍼런스가 싣는 `--reason <사유>` 리터럴 ∀ ⊆ verdict.REASONS, 그리고 그 집합은
  # 파일 밖 핀과 같다 — 재도출만 하면 오타(`killswitch`)가 새 이름으로 샌다.
  local got
  got=$(python3 - "$SKILL" "$REF" "$PLUGIN_ROOT/scripts" <<'PY'
import re, sys
sys.path.insert(0, sys.argv[3]); import verdict
found = set()
for path in sys.argv[1:3]:
    found |= set(re.findall(r"--reason ([a-z][a-z-]*)", open(path, encoding="utf-8").read()))
print("OUTSIDE:" + ",".join(sorted(found - set(verdict.REASONS))))
print("SET:" + " ".join(sorted(found)))
PY
)
  assert_grep "$got" '^OUTSIDE:$' "SKILL 이 싣는 사유는 전부 닫힌 열거 안이다"
  assert_grep "$got" '^SET:error-axis kill-switch scope-empty silent-drop trivia$' \
    "SKILL 이 싣는 사유 집합(핀) — declaration-invalid · merge-conflict 는 4c"
}

case_angle_template_is_total() {
  # SKILL 의 각도 파일 견본이 angles.parse 를 통과한다. 견본이 셋 중 하나를 빠뜨리거나 문법
  # 밖 상태를 적으면 모델이 그대로 베껴 쓰는 파일이 exit 4 가 된다.
  local got
  got=$(python3 - "$SKILL" "$PLUGIN_ROOT/scripts" <<'PY' 2>/dev/null
import re, sys
sys.path.insert(0, sys.argv[2]); import angles
text = open(sys.argv[1], encoding="utf-8").read()
blocks = re.findall(r"^[ \t]*```text\n(.*?)^[ \t]*```[ \t]*$", text, re.M | re.S)
cands = [b for b in blocks if re.search(r"^\s*security:", b, re.M)]
print(f"N:{len(cands)}")
for b in cands:
    angles.parse("\n".join(l.strip() for l in b.splitlines()))
print("PARSED")
PY
) || true
  assert_grep "$got" '^N:1$'    "각도 파일 견본이 정확히 하나 있다"
  assert_grep "$got" '^PARSED$' "견본이 angles.parse 를 통과한다(세 각도 · 문법 안)"
}

case_differential_runs_inside_every_iteration() {
  # Review Focus 3 · R-AC — ② 는 iteration 루프 «안»이다.
  local body it d fin
  body=$(awk '/^## Pipeline$/{f=1;next} f&&/^## /{exit} f' "$SKILL")
  it=$(printf '%s\n' "$body" | grep -n 'iteration N = 1\.\.5' | head -1 | cut -d: -f1)
  d=$(printf '%s\n' "$body" | grep -n '②' | head -1 | cut -d: -f1)
  fin=$(printf '%s\n' "$body" | grep -n 'Final Summary' | head -1 | cut -d: -f1)
  local inside=0
  if [ -n "$it" ] && [ -n "$d" ] && [ -n "$fin" ] && [ "$it" -lt "$d" ] && [ "$d" -lt "$fin" ]; then inside=1; fi
  assert_eq "$inside" "1" "② 가 iteration 항목과 Final Summary 사이(루프 안)에 있다"
  assert_grep "$body" '매 iteration 돈다' "② 가 매 iteration 돈다고 적혀 있다"
}

case_security_switch_is_not_certified_even_with_zero_findings() {
  # Review Focus 5 · §6.5.1 9행 — 보안 kill switch 의 새 뜻: 배너가 아니라 판정이다.
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"
  rf_prep "$T"
  rf_reply "$T" 'verdicts: []
added: []'
  printf 'security: absent\nadjudication: filled\ndifferent-premise: filled\n' > "$T/angles.txt"
  local out; out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt")
  assert_grep "$out" '^verdict: not-certified$' "보안 각도 부재는 탐지 0 이어도 clean 이 아니다"
  assert_grep "$out" '^reason: angle-absent$'   "사유는 angle-absent"
  printf 'security: filled\nadjudication: filled\ndifferent-premise: filled\n' > "$T/angles.txt"
  out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt")
  assert_grep "$out" '^verdict: clean$' "같은 실행에서 보안 각도가 채워지면 clean(양의 짝)"
  rm -rf "$T"
}

case_different_premise_absent_is_disclosed_not_blocked() {
  # AC12 — 다른 전제(codex) 부재는 공시만 한다.
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"
  rf_prep "$T"
  rf_reply "$T" 'verdicts: []
added: []'
  printf 'security: filled\nadjudication: filled\ndifferent-premise: absent(not-installed)\n' > "$T/angles.txt"
  local out; out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt")
  assert_grep "$out" '^verdict: clean$'                                 "다른 전제 부재는 막지 않는다"
  assert_grep "$out" '^  different-premise: absent\(not-installed\)$'  "부재가 각도 블록에 공시된다"
  rm -rf "$T"
}

case_caller_reasons_reach_the_verdict() {
  # AC9 · R-Y — 호출자 사유가 판정에 닿는다. 탐지 0 · 각도 전부 filled 인 «깨끗한» 실행에
  # 사유 하나씩을 얹는다.
  local T r out; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"
  rf_prep "$T"
  rf_reply "$T" 'verdicts: []
added: []'
  printf 'security: filled\nadjudication: filled\ndifferent-premise: filled\n' > "$T/angles.txt"
  for r in kill-switch scope-empty silent-drop error-axis; do
    out=$(rf_synth "$T" --emit-verdict --angles "$T/angles.txt" --reason "$r")
    assert_grep "$out" '^verdict: not-certified$' "--reason $r → not-certified"
    assert_grep "$out" "^reason: $r\$"            "사유는 $r"
  done
  out=$(python3 "$V" --reason trivia)
  assert_grep "$out" '^reason: trivia$' "trivia 는 verdict.py 가 직접 낸다"
  rm -rf "$T"
}

case_degraded_ledger_row_reaches_silent_drop() {
  # 컨트롤러 ruling(carry-notes Task 8, R-Y ADDITION) — R8 원장(runtime-evidence.md)의
  # floor 5차원 중 하나라도 `degraded` 이거나 unclaimed unit 이 있으면 `check_qa_ledger.py`
  # 는 원장 내부 일관성만 보고 그래도 exit 0 을 낼 수 있다(구조 게이트가 이 축을 못 잡는다).
  # SKILL Step 4 의 판정 입력 표가 이 경우를 별도 행으로 `--reason silent-drop` 에 연결하지
  # 않으면 그 실행이 clean 으로 샌다. 이 락은 그 행이 표에 실재하는지를 잰다(합성기 쪽
  # 행동은 case_caller_reasons_reach_the_verdict 의 silent-drop 케이스가 이미 잰다).
  local window
  window=$(awk '/\*\*판정 입력\*\*/,/^   ```bash$/' "$SKILL")
  assert_grep "$window" '하나라도.*degraded' \
    "판정 입력 표가 floor 5차원 중 하나라도 degraded 인 조건을 담는다"
  assert_grep "$window" 'unclaimed' \
    "그 조건이 unclaimed unit 도 함께 잡는다"
  assert_grep "$window" -- '--reason silent-drop' \
    "그 조건이 --reason silent-drop 으로 간다"
  # 양의 짝 — 새 행이 정상 경로(check_qa_ledger.py 가 돌아 원장이 전부 filled 인 실행)의
  # --differential 행을 밀어내지 않았다.
  assert_grep "$window" -- '--differential' \
    "정상 --differential 행이 여전히 표에 남아 있다(새 행이 대체하지 않았다)"
}

for c in case_every_synth_call_emits_verdict_and_angles case_blocking_angle_dispatches_are_fail_closed \
         case_reason_literals_are_closed_and_pinned case_angle_template_is_total \
         case_differential_runs_inside_every_iteration \
         case_security_switch_is_not_certified_even_with_zero_findings \
         case_different_premise_absent_is_disclosed_not_blocked case_caller_reasons_reach_the_verdict \
         case_degraded_ledger_row_reaches_silent_drop; do
  "$c"
done
finish
