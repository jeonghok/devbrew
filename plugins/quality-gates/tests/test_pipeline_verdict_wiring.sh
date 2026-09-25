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
  # Fix round 1, Minor 5 — 옛 버전은 «펜스» 단위로 봤다: 한 펜스 안 여러 호출 중 하나만
  # 플래그를 실어도(S2), 다른 언어 태그의 새 펜스(S1), 플래그가 주석 안에만 있어도(S3)
  # 전부 GREEN 이었다. 이제 «호출» 단위 — 모든 펜스 언어를 보고, `#` 주석을 지운 뒤
  # `\` 로 이어지는 논리 줄 단위로 쪼개 그 호출 자신의 줄에서만 플래그를 찾는다.
  # trivia 호출(T1 — 콜을 echo 로 갈아치우고 사유를 주석에만 남기는 변이)은 verdict.py
  # 와 --reason trivia 가 «같은 논리 줄»에 있어야 한다.
  local got
  got=$(python3 - "$SKILL" "$REF" <<'PY'
import re, sys

def strip_comments(line):
    # `#` — bash 주석(선행 공백 또는 줄 시작 뒤). `//` — Agent({...}) 의사-JS 펜스의
    # 처분 주석(`  // **처분** — consumer=...synthesize_findings.py...`)은 줄 전체가
    # 주석이다 — 그 안의 `synthesize_findings.py` 언급을 호출로 오인하면 안 된다.
    # 줄 «전체»가 `//` 로 시작할 때만 지운다 — `sed -n 's/^x: //p'` 처럼 줄 중간의
    # `//` 는 셸 문법(빈 치환)이라 건드리지 않는다.
    line = re.sub(r'(?:(?<=\s)|^)#.*$', '', line)
    if line.lstrip().startswith('//'):
        return ''
    return line

def logical_lines(body):
    out, buf = [], ""
    for raw in body.split("\n"):
        line = strip_comments(raw)
        if line.rstrip().endswith("\\"):
            buf += line.rstrip()[:-1] + " "
        else:
            buf += line
            out.append(buf)
            buf = ""
    if buf:
        out.append(buf)
    return out

calls = bad = trivia = 0
for path in sys.argv[1:]:
    text = open(path, encoding="utf-8").read()
    for body in re.findall(r"^[ \t]*```[a-zA-Z]*\n(.*?)^[ \t]*```[ \t]*$", text, re.M | re.S):
        for ll in logical_lines(body):
            if "synthesize_findings.py" in ll:
                calls += 1
                if "--emit-verdict" not in ll or "--angles" not in ll:
                    bad += 1
            if "verdict.py" in ll and "--reason trivia" in ll:
                trivia += 1
print(f"CALLS:{calls}")
print(f"BAD:{bad}")
print(f"TRIVIA:{trivia}")
PY
)
  assert_grep "$got" '^CALLS:[1-9]' "합성기를 부르는 호출이 하나 이상 있다(0 이면 아래가 공허하다)"
  assert_grep "$got" '^BAD:0$'      "합성기를 부르는 호출 ∀(펜스 언어 무관 · 호출 단위) 가 --emit-verdict 와 --angles 를 싣는다"
  assert_grep "$got" '^TRIVIA:[1-9]' "trivia 호출은 verdict.py 와 --reason trivia 가 같은 논리 줄에 있다(주석만으로는 안 된다)"
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
  # 않으면 그 실행이 clean 으로 샌다.
  #
  # Fix round 1, Important 1 — 옛 버전은 표 «창 전체» 에서 `--reason silent-drop` 을 찾았다.
  # 그런데 `check_qa_ledger.py non-zero` 행(SKILL.md:514)도 같은 리터럴을 싣고 있어, L1(이
  # 행의 오른쪽 칸을 「싣지 않는다 — 공시만 한다」로 바꿔치기)· L2(「없음 — --reason
  # silent-drop 은 위 non-zero 행에만」으로 바꿔치기) 둘 다 창 안 다른 행이 리터럴을
  # 대신 만족시켜 GREEN 으로 남았다. 이제 *이 행 자신*(degraded· unclaimed 를 동시에 담은
  # «그 줄»)에서만 잰다 — 다른 행이 대신 만족시킬 수 없다.
  local got
  got=$(python3 - "$SKILL" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
rows = [l for l in text.splitlines() if "degraded" in l and "unclaimed" in l]
print(f"ROWS:{len(rows)}")
ok = 0
for l in rows:
    has_reason = "--reason silent-drop" in l
    negated = any(neg in l for neg in ("싣지 않는다", "없음", "공시만"))
    if has_reason and not negated:
        ok += 1
print(f"OK:{ok}")
PY
)
  assert_grep "$got" '^ROWS:1$' "degraded 이면서 unclaimed 인 조건을 담은 행이 정확히 하나 있다"
  assert_grep "$got" '^OK:1$'   "그 행 자신이 --reason silent-drop 을 싣고 부정형(싣지 않는다·없음·공시만)을 담지 않는다"
  # 양의 짝 — 새 행이 정상 경로(check_qa_ledger.py 가 돌아 원장이 전부 filled 인 실행)의
  # --differential 행을 밀어내지 않았다.
  assert_grep "$(cat "$SKILL")" -- '--differential "<\$aggregate_yaml' \
    "정상 --differential 행이 여전히 표에 남아 있다(새 행이 대체하지 않았다)"
}

case_r_init_abort_reaches_error_axis() {
  # Fix round 1, Important 2(plan-mandated, controller ruling) — the Step 4 판정
  # 입력 표는 원래 ② 가 R6 까지 «도달」한 실행만 다뤘다. `differential-test.md` 의
  # R-init 가드(TMPDIR 이 검사 트리 안 · `$project_dir` 빈 값 · 저장소 최상위 해소
  # 실패)는 R6·`check_qa_ledger.py` 가 존재하기도 «전에» exit 1 한다 — kill switch 와
  # 무관하다. 그 경로에서 어떤 행도 매치하지 않으면 오케스트레이터가 플래그 없이
  # synthesize_findings.py 를 불러 verdict: clean 이 나갈 수 있다(AC2 위반). 이 락은
  # 그 포괄 행이 표에 실재하는지 F1(행 삭제) 변이로 잰다.
  local got
  got=$(python3 - "$SKILL" <<'PY'
import sys
text = open(sys.argv[1], encoding="utf-8").read()
rows = [l for l in text.splitlines() if "R-init" in l and "중단" in l]
print(f"ROWS:{len(rows)}")
ok = sum(1 for l in rows if "--reason error-axis" in l)
print(f"OK:{ok}")
PY
)
  assert_grep "$got" '^ROWS:1$' "R-init 가드 중단(kill switch 와 무관)을 담은 행이 정확히 하나 있다"
  assert_grep "$got" '^OK:1$'   "그 행이 --reason error-axis 를 싣는다"
}

case_security_kill_switch_routes_to_absent() {
  # Fix round 1, Important 3(a)(plan-mandated) — Review Focus 5 의 A2 변이(각도
  # 표 :499 를 `filled` 로, IF item 4 :287 를 `security: filled` 로 바꿔치기)가
  # 기존 락 전부를 GREEN 인 채로 통과시켰다: 옛 락은 한 번도 «이 kill switch 가
  # absent 로 간다» 는 라우팅 자체를 재지 않았다(합성기 행동만 rf_synth 픽스처로
  # 쟀지, SKILL 문서가 그 경로로 실제로 매핑하는지는 안 쟀다). 이제 세 지점을
  # 각각 같은-줄/같은-문단으로 고정한다.
  local got
  got=$(python3 - "$SKILL" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
lines = text.splitlines()

# (i) 각도 표의 kill-switch 행 — `| | `absent` | `DEVBREW_...SECURITY_REVIEWER=1` |`
tbl = [l for l in lines if l.lstrip().startswith("|") and "DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1" in l]
print(f"TBL_ROWS:{len(tbl)}")
tbl_ok = sum(1 for l in tbl if "absent" in l and "filled" not in l)
print(f"TBL_OK:{tbl_ok}")

# (ii) IF item 4 — "각도 파일(Step 4)에" 와 같은 줄에 `security: absent`
item4 = [l for l in lines if "각도 파일(Step 4)에" in l]
print(f"ITEM4_ROWS:{len(item4)}")
item4_ok = sum(1 for l in item4 if "security: absent" in l and "security: filled" not in l)
print(f"ITEM4_OK:{item4_ok}")

# (iii) fail-closed 문단 — "absent(source-failed)" 를 담는다(문단 창, 다음 빈 줄까지)
m = re.search(r'\*\*fail-closed 의 뜻\*\*.*?(?=\n\s*\n)', text, re.S)
print(f"FC_OK:{1 if (m and 'absent(source-failed)' in m.group(0)) else 0}")
PY
)
  assert_grep "$got" '^TBL_ROWS:1$'  "각도 표의 보안 kill-switch 행이 정확히 하나 있다"
  assert_grep "$got" '^TBL_OK:1$'    "그 행이 absent 이고 filled 가 아니다(A2 가 filled 로 바꾸면 RED)"
  assert_grep "$got" '^ITEM4_ROWS:1$' "IF item 4(각도 파일(Step 4)에 쓰는 줄)가 정확히 하나 있다"
  assert_grep "$got" '^ITEM4_OK:1$'   "그 줄이 security: absent 를 쓰고 security: filled 가 아니다"
  assert_grep "$got" '^FC_OK:1$'      "fail-closed 문단이 absent(source-failed) 로 매핑한다"
}

case_differential_kill_switch_env_name_is_pinned() {
  # Fix round 1, Important 3(b) — KS 변이(SKILL 의 세 자리 모두에서
  # DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST 를 오탈자로 바꿔치기)가 R-V 의
  # 보안 컨트롤을 무력화해도 옛 락은 잡지 못했다. 정확한 이름을 이 락 «안에서» 한 번
  # 핀하고, ② 를 건너뛴다는 문단과 kill-switch 색인 둘 다 그 정확한 철자를 쓰는지 잰다.
  local KS_ENV='DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST'
  local got
  got=$(python3 - "$SKILL" "$KS_ENV" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
env = sys.argv[2]
m = re.search(r'\*\*Kill switch —[^\n]*' + re.escape(env) + r'=1.*?(?=\n\s*\n)', text, re.S)
para = m.group(0) if m else ""
print(f"PARA_ENV:{1 if env in para else 0}")
print(f"PARA_SKIP:{1 if ('②' in para and ('건너뛴다' in para)) else 0}")
print(f"PARA_REASON:{1 if '--reason kill-switch' in para else 0}")
idx_lines = [l for l in text.splitlines() if l.lstrip().startswith('-') and env in l]
print(f"IDX_ROWS:{len(idx_lines)}")
PY
)
  assert_grep "$got" '^PARA_ENV:1$'    "Kill-switch 문단이 정확한 env 이름을 싣는다(오탈자면 RED)"
  assert_grep "$got" '^PARA_SKIP:1$'   "그 문단이 ② 를 건너뛴다고 적는다"
  assert_grep "$got" '^PARA_REASON:1$' "그 문단이 --reason kill-switch 를 싣는다"
  assert_grep "$got" '^IDX_ROWS:1$'    "kill-switch 색인에도 같은 정확한 철자의 행이 하나 있다"
}

for c in case_every_synth_call_emits_verdict_and_angles case_blocking_angle_dispatches_are_fail_closed \
         case_reason_literals_are_closed_and_pinned case_angle_template_is_total \
         case_differential_runs_inside_every_iteration \
         case_security_switch_is_not_certified_even_with_zero_findings \
         case_different_premise_absent_is_disclosed_not_blocked case_caller_reasons_reach_the_verdict \
         case_degraded_ledger_row_reaches_silent_drop case_r_init_abort_reaches_error_axis \
         case_security_kill_switch_routes_to_absent case_differential_kill_switch_env_name_is_pinned; do
  "$c"
done
finish
