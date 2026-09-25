#!/usr/bin/env bash
# test_verdict_vocabulary.sh — AC8 · AC9 (설계 §6.4.3).
#
# 이 락이 재는 것은 «총 함수» 다: 세 값 밖의 값이 나오지 않고, `not-certified` 는
# 사유 없이 존재할 수 없으며, 사유는 닫힌 열거 밖으로 나갈 수 없다. 「어떤 입력에
# 어떤 값이 나온다」만 재는 락은 열거가 조용히 넓어져도 GREEN 이다 — 그래서
# 열거 자체를 **스크립트에서 도출해** 대조한다(∃ 가 아니라 ∀).
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
V="$PLUGIN_ROOT/scripts/verdict.py"
D="$PLUGIN_ROOT/scripts/diff-test-results.py"
SYNTH="$PLUGIN_ROOT/scripts/synthesize_findings.py"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
. "$SCRIPT_DIR/lib/recritic_fixture.sh"
export PYTHONDONTWRITEBYTECODE=1

# 열거를 **스크립트 자신에게 물어** 가져온다. 여기에 리터럴 목록을 복사하면
# 두 자리가 어긋날 때 락이 자기 사본만 보고 GREEN 을 낸다.
REASONS=$(python3 -c "import sys; sys.path.insert(0, '$PLUGIN_ROOT/scripts'); import verdict; print('\n'.join(verdict.REASONS))")
VALUES=$(python3 -c "import sys; sys.path.insert(0, '$PLUGIN_ROOT/scripts'); import verdict; print('\n'.join(verdict.VALUES))")

case_three_values_only() {
  assert_eq "$(printf '%s\n' "$VALUES" | wc -l | tr -d ' ')" "3" "판정값은 정확히 셋이다"
  # Ruling P1 — assert_grep <text> <ERE> <msg> 는 세 인자가 필수다. shared/tests/assert.sh
  # 가 "$3" 을 역참조하는데 이 파일은 `set -u` 아래라, msg 를 생략하면 첫 호출에서
  # unbound variable 로 스크립트 전체가 죽는다(개별 케이스 실패가 아니라 전멸).
  assert_grep "$VALUES" '^clean$'         "clean 이 있다"
  assert_grep "$VALUES" '^defect$'        "defect 가 있다"
  assert_grep "$VALUES" '^not-certified$' "not-certified 가 있다"
}

case_reason_flag_certifies_known_members() {
  # Important 1 (재명명) — 이 케이스는 «도달 가능성»을 증명하지 «않는다». `--reason
  # <x>` 는 decide() 의 add() 가 `x in REASONS` 만 검사하므로, REASONS 의 모든
  # 원소에 대해 구성상(by construction) 항상 성립한다 — REASONS 에 12번째 값을
  # 추가하고 decide() 를 전혀 안 고쳐도 이 루프는 GREEN 이다(실측, 이번 라운드
  # 리뷰가 잡음). 이 케이스가 실제로 재는 것은 그보다 좁다: 열거의 각 값을 CLI 로
  # 주면 그 값 그대로 `not-certified` 의 `reason:` 이 되는 **동작**뿐이다.
  # 「열거가 닫혀 있다(크기 고정)」·「각 사유가 산출자 또는 부채로 귀속된다」는
  # 아래 `case_reason_enum_is_closed_and_accounted` 가 잰다.
  local r out
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    out=$(python3 "$V" --reason "$r") || { no "사유 '$r' 가 exit != 0"; continue; }
    assert_grep "$out" '^verdict: not-certified$' "'$r' → not-certified"
    assert_grep "$out" "^reason: $r\$"            "'$r' 가 reason 으로 나온다"
  done <<< "$REASONS"
}

case_reason_enum_is_closed_and_accounted() {
  # Important 1 — 11 값 각각이 셋 중 하나에 «속한다», 그리고 그 셋이 서로
  # «겹치지 않는다»(진짜 partition — 라운드 2 수정). 라운드 1 판은 `covered` 를
  # 합집합으로만 만들었다: "산출 가능" 과 "부채" 가 같은 이름을 동시에 만족해도
  # (겹쳐도) MISSING·STALE 둘 다 비어 GREEN 이 났다 — 이것은 *cover* 검사이지
  # 주석이 주장한 *partition* 이 아니었다. 리뷰가 실측: 나중 PR 이 `decide()`
  # 안에 `add("angle-absent")` 를 실제로 배선해도, 64행의 `debt` 문자열에서 그
  # 이름을 안 지우면 라운드 1 케이스는 여전히 전부 GREEN 이었다 — "부채로 적혀
  # 있다" 가 반증 불가능했다(산출자가 생겨도 부채 목록에 남아 있으면 안 걸림).
  #
  # 이번 판은 `produced`(CAUSE_TO_REASON.values() ∪ decide() 소스에서 정규식
  #으로 **도출한** 리터럴 `add("...")` 호출들) 와 `debt` 가 서로소인지
  # (OVERLAP 비어 있음)까지 함께 잰다 — 부채로 적어 둔 이름에 실제 산출자가
  # 생기면 이제 그 자리가 RED 로 알린다("배선했으면 부채 목록에서 지워라").
  # `findings-lost` 도 이제 하드코딩이 아니라 `decide()` 소스에서 같은 방식으로
  # 도출된다.
  #
  # **이 케이스가 여전히 증명하지 않는 것** — `produced` 는 `decide()` 소스에서
  # `add("<literal>")` 형태의 호출만 정규식으로 찾는다. `add(CAUSE_TO_REASON[c])`
  # 처럼 변수를 거쳐 사유를 넣는 경로는 이 정규식에 안 잡힌다 — 그 경로는
  # `CAUSE_TO_REASON.values()` 로 이미 따로 세고 있어 의도적으로 제외했다.
  # 하지만 **미래에 어떤 사유가 리터럴이 아닌 다른 방식(딕셔너리 조회·f-string
  # 조합 등)으로 새로 배선되면 이 케이스는 그것을 "아직 산출자 없음(부채)" 으로
  # 오판할 수 있다** — 이것은 정적 분석의 근본 한계이고, 여기서는 "오늘 이
  # 소스가 실제로 갖고 있는 리터럴 add() 호출" 이상을 주장하지 않는다.
  #
  # **둘째 스코프 한계(Task 6 mutation 실측, ★NB1) — `inspect.getsource(verdict.
  # decide)` 는 decide() «자기 본문만» 읽는다.** 리터럴 `add("angle-absent")` 를
  # decide() 가 호출하는 **헬퍼 함수**로 추출하면(decide() 는 그 헬퍼를 부르기만
  # 함) 정규식이 그 헬퍼의 소스를 보지 않으므로 이 케이스의 88개 단언이 전부
  # GREEN 인 채로 남는다 — 그런데 그 상태에서 `decide(angle_absent=True)` 는
  # 실제로 `reason: angle-absent` 를 낸다(실측: mutant 파일
  # `/Users/jeonghokim/.claude/jobs/58376a1b/tmp/task6/findingB/apply_helper_mutation.py`,
  # 결과 로그 `T4_FindingB_run1.log`, MISSING/STALE/OVERLAP 셋 다 빈 채로 88/88
  # PASS). 이것은 "리터럴이 아닌 형태" 한계(위 문단)와는 **다른 축** 이다 —
  # 저건 리터럴이되 변수를 거치는 경로, 이건 리터럴이되 **다른 함수 본문에 있는**
  # 경로다.
  #
  # 둘째 독립 증인(아래 `AXES:`) — `decide()` 의 **키워드 전용 파라미터 집합**을
  # 핀한다. `add()` 호출을 어떻게 감추든, 그 조건을 CLI/호출자가 켤 방법이
  # 있으려면 거의 항상 새 파라미터가 하나 는다(오늘의 세 배선 방식 — 본문 리터럴
  # · 변수 경유 · 헬퍼 추출 — 전부 새 파라미터를 요구했다: `angle_absent` 없이는
  # 어떤 방식으로도 그 사유를 켤 수 없다). **`OVERLAP` 을 대체하지 않는다** —
  # `CAUSE_TO_REASON` 경유로 배선되는 사유(예: 오늘의 `smeared`)는 새 파라미터가
  # 필요 없고(기존 `differential_text` 축을 그대로 씀), `OVERLAP` 이 바로 그
  # 경로를 잡는다. 둘은 상호 보완이다 — 파라미터 축은 헬퍼-추출처럼 **새 축**이
  # 열리는 배선을, `OVERLAP`은 **기존 축**(차등 산출물)에 얹히는 배선을 잡는다.
  #
  # 산출자 셋:
  #   차등 축(CAUSE_TO_REASON.values()): scope-empty · baseline-unrunnable · silent-drop ·
  #                                     error-axis · granularity-smear
  #   decide() 자신의 플래그: findings-lost · angle-absent
  #   오케스트레이터(SKILL · 레퍼런스의 `--reason` 리터럴): trivia · kill-switch · (차등
  #                                     축과 겹치는) scope-empty · silent-drop · error-axis
  #   부채 — 산출자 없음(PR4c): declaration-invalid · merge-conflict
  local debt="declaration-invalid merge-conflict"
  local SKILL_MD="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
  local REF_MD="$PLUGIN_ROOT/skills/quality-pipeline/references/differential-test.md"
  local got; got=$(python3 -c "
import re, inspect, sys
sys.path.insert(0,'$PLUGIN_ROOT/scripts'); import verdict
debt = set('''$debt'''.split())
flag_produced = set(re.findall(r'add\(\"([a-z-]+)\"\)', inspect.getsource(verdict.decide)))
caller_produced = set()
for p in ('$SKILL_MD', '$REF_MD'):
    caller_produced |= set(re.findall(r'--reason ([a-z][a-z-]*)', open(p, encoding='utf-8').read()))
produced = set(verdict.CAUSE_TO_REASON.values()) | flag_produced | caller_produced
print('MISSING:' + ','.join(sorted(set(verdict.REASONS) - (produced | debt))))
print('STALE:'   + ','.join(sorted((produced | debt) - set(verdict.REASONS))))
print('OVERLAP:' + ','.join(sorted(debt & produced)))
print('N:%d' % len(verdict.REASONS))
print('AXES:' + ','.join(sorted(inspect.signature(verdict.decide).parameters)))")
  assert_grep "$got" '^MISSING:$' "열거의 모든 사유가 산출자 또는 부채 목록에 귀속된다"
  assert_grep "$got" '^STALE:$'   "부채 목록·매핑에 열거 밖 이름이 없다"
  assert_grep "$got" '^OVERLAP:$' "부채 목록에 이미 산출자가 생긴 이름이 남아 있지 않다"
  assert_grep "$got" '^N:11$'     "사유 열거는 정확히 열한 값이다"
  assert_grep "$got" '^AXES:angle_absent,defect,differential_text,extra_reasons,review_blocked$' \
    "decide() 의 키워드 전용 파라미터 집합이 다섯이다 — 새 축마다 파라미터가 하나 는다(OVERLAP 이 못 잡는 헬퍼-추출 배선의 둘째 독립 증인)"
}

case_unknown_reason_is_fail_closed() {
  local rc=0; python3 "$V" --reason made-up-reason >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "열거 밖 사유는 exit 4"
}

case_not_certified_always_has_reason() {
  # AC8 후반 — 사유 없는 not-certified 는 **낼 수 없다**. 렌더러가 마지막 관문이다.
  local rc=0
  python3 -c "import sys; sys.path.insert(0,'$PLUGIN_ROOT/scripts'); import verdict; verdict.render({'verdict':'not-certified','reason':None,'reasons':[]})" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "사유 없는 not-certified 는 exit 4"
  local out; out=$(python3 "$V" --reason kill-switch)
  assert_grep "$out" '^verdict: not-certified$' "사유를 주면 선다"
}

case_kill_switch_is_not_certified() {      # AC9
  local out; out=$(python3 "$V" --reason kill-switch)
  assert_grep "$out"     '^verdict: not-certified$' "kill switch 실행은 not-certified"
  assert_not_grep "$out" '^verdict: clean$'          "clean 이 아니다"
  assert_not_grep "$out" '^verdict: defect$'         "실패도 아니다"
}

case_review_blocked_is_not_certified() {
  # Important 4 — 리뷰 축(세 입력 중 하나)이 CLI 로 전혀 재지지 않고 있었다:
  # `decide()` 의 `if review_blocked: add("findings-lost")` 줄을 통째로 지워도
  # 이전 17케이스 전부 GREEN 이었다(실측, 이번 라운드 리뷰가 잡음) — 리뷰가
  # findings 를 잃어도 `clean` 으로 인증되는 경로가 무방비였다는 뜻이다.
  local out; out=$(python3 "$V" --review-blocked)
  assert_grep "$out" '^verdict: not-certified$' "리뷰 축 차단은 미판정을 만든다"
  assert_grep "$out" '^reason: findings-lost$'  "findings-lost 가 reason 이 된다"
}

case_angle_absent_is_not_certified() {      # AC11 의 «값» 쪽
  local out; out=$(python3 "$V" --angle-absent)
  assert_grep "$out"     '^verdict: not-certified$' "각도 부재는 미판정을 만든다"
  assert_grep "$out"     '^reason: angle-absent$'   "angle-absent 가 reason 이 된다"
  assert_not_grep "$out" '^verdict: clean$'          "clean 이 아니다 (AC11)"
}

case_angle_absent_and_findings_lost_are_distinct() {
  # 둘은 **다른 사유**다. 같은 실행에서 둘 다 서면 reasons 에 둘 다 남고,
  # `reason:` 은 열거 순서에서 앞선 `findings-lost` 다. 이 케이스가 없으면
  # 「둘을 하나로 다시 접는」 회귀가 GREEN 으로 지나간다 — PR2 가 갖고 있던
  # 바로 그 접힘이다(I2).
  local out; out=$(python3 "$V" --angle-absent --review-blocked)
  assert_grep "$out" '^verdict: not-certified$' "둘 다면 여전히 미판정"
  assert_grep "$out" '^reason: findings-lost$'  "reason 은 열거 순서상 앞선 쪽"
  assert_grep "$out" 'angle-absent'             "그래도 angle-absent 가 reasons 에서 소실되지 않는다"
}

case_review_blocked_survives_under_defect() {
  # defect 가 우선하더라도 findings-lost 가 reasons 에서 소실되면 안 된다 —
  # "왜 미판정이 아니라 결함으로 떨어졌는지" 를 읽는 쪽이 여전히 알아야 한다.
  local out; out=$(python3 "$V" --review-blocked --defect)
  assert_grep "$out" '^verdict: defect$' "확증 결함이 미판정보다 우선한다"
  assert_grep "$out" 'findings-lost'     "그래도 findings-lost 는 reasons 에서 소실되지 않는다"
}

case_precedence_defect_wins() {
  local out; out=$(python3 "$V" --defect --reason silent-drop)
  assert_grep "$out" '^verdict: defect$'  "defect > not-certified"
  assert_grep "$out" 'silent-drop'        "그래도 사유는 드러난다"
}

case_precedence_not_certified_beats_clean() {
  local out; out=$(python3 "$V" --reason granularity-smear)
  assert_grep "$out" '^verdict: not-certified$' "not-certified > clean"
}

case_reason_is_first_in_enum_order() {
  # `reason:` 은 임의의 하나가 아니라 **열거 순서에서 가장 앞선** 것이다.
  # 인자 순서를 뒤집어도 같은 값이 나와야 한다.
  local a b
  a=$(python3 "$V" --reason granularity-smear --reason kill-switch | sed -n 's/^reason: //p')
  b=$(python3 "$V" --reason kill-switch --reason granularity-smear | sed -n 's/^reason: //p')
  assert_eq "$a" "kill-switch" "열거 앞선 사유가 reason 이 된다"
  assert_eq "$a" "$b"          "인자 순서가 reason 을 바꾸지 않는다"
}

case_reason_is_member_of_reasons() {
  local out; out=$(python3 "$V" --reason granularity-smear --reason kill-switch)
  local one; one=$(printf '%s\n' "$out" | sed -n 's/^reason: //p')
  local all; all=$(printf '%s\n' "$out" | sed -n 's/^reasons: //p')
  assert_grep "$all" "$one" "reason 은 reasons 의 원소다"
  assert_grep "$all" 'granularity-smear' "나머지 사유가 소실되지 않는다"
}

case_clean_carries_no_reason() {
  local out; out=$(python3 "$V")
  assert_grep "$out"     '^verdict: clean$' "아무 신호도 없으면 clean"
  assert_not_grep "$out" '^reason: '        "clean 에는 reason 이 없다"
}

case_legacy_table_is_gone() {
  # AC23 — 옛 판정 어휘의 산출자(runtime-verifier)가 사라졌으므로 매핑표도 없다.
  local hits; hits=$(grep -cE 'LEGACY_VERDICTS|legacy_verdict|AC23' "$V" || true)
  assert_eq "$hits" "0" "verdict.py 에 옛 어휘 매핑의 흔적이 없다(정의·인자·표지)"
  local rc=0 err
  err=$(python3 "$V" --legacy-verdict PASS 2>&1 >/dev/null) || rc=$?
  assert_eq "$rc" "2" "verdict.py 는 --legacy-verdict 를 모른다(exit 2)"
  # Controller fix round 1, Minor 5 — exit 2 가 다른 usage 오류가 아니라 「모르는
  # 인자」 그 자체인지를 사유로 확인한다.
  assert_contains "$err" 'unrecognized arguments' "verdict.py — argparse 가 모르는 인자로 거부한다"
  rc=0; err=$(python3 "$SYNTH" --emit-verdict --legacy-verdict PASS 2>&1 >/dev/null) || rc=$?
  assert_eq "$rc" "2" "합성기도 --legacy-verdict 를 모른다(exit 2)"
  assert_contains "$err" 'unrecognized arguments' "합성기 — argparse 가 모르는 인자로 거부한다"
  # 양의 짝 — 같은 CLI 가 살아 있는 인자는 받는다(「언제나 exit 2」 변이를 막는다).
  local out; out=$(python3 "$V" --reason kill-switch)
  assert_grep "$out" '^verdict: not-certified$' "살아 있는 인자는 그대로 선다"
}

case_differential_causes_become_reasons() {
  # Task 2 가 연 `degrade_causes` 가 실제로 사유가 되는지 — 두 모듈의 이음매다.
  local T; T=$(mktemp -d)
  printf 'attribution_status: degraded\ndegrade_causes: [silent-drop, smeared]\nverdict_input:\n  confirmed_product_defect: false\n  silent_drop: true\n  baseline_unrunnable: false\n' > "$T/d.yaml"
  local out; out=$(python3 "$V" --differential "$T/d.yaml")
  assert_grep "$out" '^verdict: not-certified$'  "degrade 원인이 미판정을 만든다"
  assert_grep "$out" 'silent-drop'                "원인이 사유로 옮겨온다"
  assert_grep "$out" 'granularity-smear'          "smeared → granularity-smear 로 번역된다"
  rm -rf "$T"
}

case_differential_defect_flag_wins() {
  local T; T=$(mktemp -d)
  printf 'attribution_status: degraded\ndegrade_causes: [silent-drop]\nverdict_input:\n  confirmed_product_defect: true\n  silent_drop: true\n  baseline_unrunnable: false\n' > "$T/d.yaml"
  local out; out=$(python3 "$V" --differential "$T/d.yaml")
  assert_grep "$out" '^verdict: defect$' "확증 결함이 미판정을 이긴다"
  rm -rf "$T"
}

case_unreadable_differential_is_fail_closed() {
  local rc=0; python3 "$V" --differential /nonexistent/d.yaml >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "차등 산출물을 못 읽으면 exit 4 — clean 으로 새지 않는다"
}

case_non_utf8_differential_is_fail_closed() {
  # Important 2 — UnicodeDecodeError 는 ValueError 의 하위이지 OSError 가 아니다.
  # read_or_none() 이 OSError 만 잡던 상태에서는 비-UTF-8 바이트가 raw traceback +
  # exit 1 로 0/2/4 계약을 그대로 탈출했다(실측). 형제 diff-test-results.py 의
  # read_text_or_fail4(75-82행)가 이미 같은 결함을 잡아 뒀던 자리인데
  # (/qg iter-7 M2) 이 모듈만 없었다. 이 케이스가 그 문을 못박는다 — 바로 위
  # case_unreadable_differential_is_fail_closed 옆에 둔다.
  #
  # Minor (라운드 2) — 라운드 1 픽스처는 `printf '\xff\xfe\x00bad'` 한 줄뿐이었다.
  # 이 `\x` 이스케이프는 **셸이 확장**해야 진짜 잘못된 바이트가 된다(bash 는
  # 확장한다). 확장 안 하는 셸에서 돌면 파일은 리터럴 ASCII 문자열
  # `\xff\xfe\x00bad`(유효한 UTF-8)가 되는데, 그래도 이 케이스는 여전히 rc=4
  # 였다 — `degrade_causes` 줄이 0회라는 **다른** 이유로(causes_of() 의 zero-hit
  # 경로). 즉 "진짜 디코드 실패" 세계와 "이스케이프 미확장" 세계가 같은 exit
  # 코드로 뭉개져, 이 케이스가 실제로 디코드 오류 경로를 태웠는지 구별하지
  # 못했다(실측 — green-for-the-wrong-reason). 픽스처를 **유효한 차등 산출물
  # 본문 + 그 뒤에 곧바로 붙는 나쁜 바이트**로 바꿨다: 확장이 안 되는 세계에서는
  # 본문이 그대로 정상 파싱되어 `rc=0`(다른 이유로 우연히 4가 되지 않는다 —
  # RED 로 드러난다)이 나오도록 갈랐다.
  local T; T=$(mktemp -d)
  printf 'attribution_status: degraded\ndegrade_causes: [silent-drop]\nverdict_input:\n  confirmed_product_defect: false\n  silent_drop: true\n  baseline_unrunnable: false\n\xff\xfe' > "$T/bad.yaml"
  local rc=0; python3 "$V" --differential "$T/bad.yaml" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "비-UTF-8 차등 산출물은 exit 4 — exit 1 raw traceback 도, 다른 이유의 exit 4 도 아니다"
  rm -rf "$T"
}

case_empty_differential_flag_is_usage_error() {
  # Important 3 — `--differential` 기본값이 `""` 였을 때는 "플래그를 안 줬다"
  # 와 "빈 경로를 줬다" 가 같은 값이었다. 값을 못 구한 호출자가
  # `--differential "$DIFF_YAML"` 을 빈 변수로 호출하면 차등 축이 조용히
  # 사라지고 `clean`·exit 0 으로 인증됐다(실측 — read_or_none() 자신의
  # docstring 이 "둘을 합치면 파일이 사라진 실행이 조용히 clean 으로 샌다" 고
  # 명시적으로 금지한 바로 그 경로). 명시적으로 빈 문자열을 주면 이제 usage
  # 오류(exit 2)다 — clean(exit 0)도 아니고 판정축 실패(exit 4)도 아니다.
  local rc=0; python3 "$V" --differential "" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "--differential 에 빈 문자열은 usage 오류다"
}

case_fail4_uses_scriptname_prefix_not_verdict_key() {
  # Minor 1 (라운드 1) 회귀 방지 — fail4() 가 `verdict:` 키로 에러를 내면
  # `field verdict "$text"`(shared/tests/assert.sh:95) 같은 순진한 파서가 에러
  # 문장을 넷째 판정값으로 읽을 수 있다. 라운드 1 은 접두사를 `verdict.py:` 로
  # 고쳤지만 그 수정을 지키는 락이 없었다 — `print(f"verdict: {msg}")` 로
  # 되돌려도(라운드 2 리뷰 실측) 이전까지는 어떤 단언도 RED 가 안 됐다. 이제
  # 이 케이스가 그 자리를 지킨다.
  local err; err=$(python3 "$V" --reason bogus 2>&1 >/dev/null)
  assert_grep "$err"     '^verdict\.py: ' "fail4 의 stderr 는 verdict.py: 로 시작한다"
  assert_not_grep "$err" '^verdict: '     "fail4 의 stderr 가 성공 출력의 verdict: 키를 재사용하지 않는다"
}

case_render_enforces_values_and_reasonless_guard() {
  # Minor 2 (라운드 1) 회귀 방지 — render() 의 `decision["verdict"] not in
  # VALUES` 가드를 지워도, decide() 가 오늘 세 리터럴("defect"/"not-certified"/
  # "clean")만 반환해 그 가드를 발화시킬 정상 경로가 없으므로 어떤 단언도 RED
  # 가 안 됐다(라운드 2 리뷰 실측). render() 를 직접 불러 강제로 두 시나리오를
  # 통과시킨다: ①어휘 밖 판정값, ②사유 없는 not-certified(AC8) — 후자는
  # render() 의 가드가 decide() 로부터는 도달 불가라 라운드 1 이후 한 번도
  # 실행된 적이 없었다.
  local rc
  rc=0; python3 -c "
import sys; sys.path.insert(0,'$PLUGIN_ROOT/scripts'); import verdict
verdict.render({'verdict': 'passed', 'reason': None, 'reasons': []})
" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "어휘 밖 판정값은 render() 가 exit 4 로 막는다"

  rc=0; python3 -c "
import sys; sys.path.insert(0,'$PLUGIN_ROOT/scripts'); import verdict
verdict.render({'verdict': 'not-certified', 'reason': None, 'reasons': []})
" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "사유 없는 not-certified 는 render() 가 exit 4 로 막는다(AC8, decide() 에서는 도달 불가)"
}

case_degrade_causes_and_cause_to_reason_are_bijective() {
  # Important 5 — diff-test-results.py 의 DEGRADE_CAUSES 와 이 모듈의
  # CAUSE_TO_REASON 키는 오늘 정확히 1:1 이다(실측). 아무것도 그것을 강제하지
  # 않으면, 산출자에 새 원인이 생겨도 이 락 스위트 어디도 미리 알리지 않고 실제
  # 게이트 실행에서만 `fail4("미지의 degrade_cause")` 로 터진다 — 방향은
  # fail-closed 지만, 어떤 테스트도 예견하지 못한 실패다. UNMAPPED 가 핵심
  # 방향(산출자가 낼 수 있는데 이 모듈이 모르는 값)이고, ORPHAN 은 반대쪽
  # drift(이 모듈만 아는 죽은 이름)를 잡는다.
  #
  # diff-test-results.py 는 대시 때문에 이름으로 import 할 수 없어 경로로
  # 로드한다 — main() 이 `__name__` 가드 아래 있어 import 자체는 부작용이 없다.
  local got; got=$(python3 -c "
import sys, importlib.util
sys.path.insert(0,'$PLUGIN_ROOT/scripts'); import verdict
spec = importlib.util.spec_from_file_location('dtr', '$D')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print('UNMAPPED:' + ','.join(sorted(set(m.DEGRADE_CAUSES) - set(verdict.CAUSE_TO_REASON))))
print('ORPHAN:'   + ','.join(sorted(set(verdict.CAUSE_TO_REASON) - set(m.DEGRADE_CAUSES))))")
  assert_grep "$got" '^UNMAPPED:$' "producer 가 낼 수 있는 모든 원인이 CAUSE_TO_REASON 에 매핑돼 있다"
  assert_grep "$got" '^ORPHAN:$'   "CAUSE_TO_REASON 에 producer 가 안 내는 죽은 이름이 없다"
}

case_real_producer_per_adapter_feeds_verdict() {
  # Ruling T4-a — 손으로 쓴 YAML 은 이 모듈의 파싱만 재고, 두 모듈이 실제로
  # 맞물리는지는 못 잰다(산출자의 표기가 흔들려도 손 픽스처는 못 알아챈다).
  # 여기서는 diff-test-results.py 를 per-adapter 모드로 **실제로** 돌려 그
  # stdout 을 파일로 받고, 그 파일을 verdict.py 에 먹인다.
  #
  # 시나리오: expected 에 test_a 하나, baseline 은 pass, head 파일은 비어 있다
  # (= head 에 그 unit 행이 없다) → (P,∅) 는 SILENT_DROP 하나뿐이라
  # degrade_causes 는 [silent-drop] 하나, confirmed_product_defect 는 false다.
  #
  # Concern 2 좁히기 — `--granularity` 를 하드코딩하지 않고 소유자
  # (run-test-selection.sh granularity)에게 pytest 의 실제 입도를 물어 쓴다.
  # 이 시나리오는 pre_existing == 0 이라 granularity 값이 무엇이든 smeared·
  # bulk 도말 절이 발화하지 않는다(결과 불변) — 값 자체보다 "diff-test-results.py
  # 가 소유자와 불일치하면 verify_granularity() 가 거부한다" 는 것만 산다.
  local T out rc G
  T=$(mktemp -d)
  G=$(bash "$PLUGIN_ROOT/scripts/run-test-selection.sh" granularity pytest) \
    || { no "pytest granularity 소유자를 부를 수 없다"; rm -rf "$T"; return; }
  printf 'test_a\n' > "$T/expected.txt"
  printf 'test_a\tpass\t0\n' > "$T/baseline.tsv"
  : > "$T/head.tsv"
  rc=0
  python3 "$D" --expected "$T/expected.txt" --baseline "$T/baseline.tsv" \
    --head "$T/head.tsv" --granularity "$G" --runner pytest \
    --baseline-mode per-unit --head-mode per-unit \
    --baseline-detected pytest > "$T/adapter.yaml" 2>"$T/adapter.err" || rc=$?
  if [ "$rc" -ne 0 ]; then
    no "실제 producer(per-adapter) 실행이 실패했다 (rc=$rc): $(cat "$T/adapter.err")"
    rm -rf "$T"; return
  fi
  out=$(python3 "$V" --differential "$T/adapter.yaml")
  assert_grep "$out" '^verdict: not-certified$' "실제 per-adapter 산출물의 silent-drop 이 미판정을 만든다"
  assert_grep "$out" '^reason: silent-drop$'    "실제 산출물의 유일 원인이 reason 이 된다"
  rm -rf "$T"
}

case_real_producer_aggregate_feeds_verdict() {
  # Ruling T4-a (집계 모드) — per-adapter 산출물 두 개를 **실제로** 집계해,
  # 두 원인이 합쳐진 실제 verdict_input 을 verdict.py 에 먹인다. per-adapter
  # 와 집계가 같은 표기를 쓴다는 인터페이스 계약을 실행으로 확인한다.
  #
  # 어댑터1(pytest): test_a, baseline pass · head 없음 → SILENT_DROP.
  # 어댑터2(unittest): test_b, baseline unrun · head pass → BASELINE_UNRUNNABLE.
  # 집계 원인은 [baseline-unrunnable, silent-drop] (DEGRADE_CAUSES 열거 순서) —
  # REASONS 순서에서도 baseline-unrunnable 이 silent-drop 보다 앞이라 reason 은
  # baseline-unrunnable 이어야 한다.
  #
  # Concern 2 좁히기 — 두 러너 모두 `--granularity` 를 하드코딩하지 않고 각자의
  # 소유자 응답을 쓴다. 두 시나리오 다 pre_existing == 0 이라 값 자체가
  # smeared·bulk 도말 결과를 바꾸지 않는다(결과 불변, 값은 소유자 일치 검증용).
  local T rc out Gp Gu
  T=$(mktemp -d)
  Gp=$(bash "$PLUGIN_ROOT/scripts/run-test-selection.sh" granularity pytest) \
    || { no "pytest granularity 소유자를 부를 수 없다"; rm -rf "$T"; return; }
  Gu=$(bash "$PLUGIN_ROOT/scripts/run-test-selection.sh" granularity unittest) \
    || { no "unittest granularity 소유자를 부를 수 없다"; rm -rf "$T"; return; }
  printf 'test_a\n' > "$T/expected1.txt"
  printf 'test_a\tpass\t0\n' > "$T/baseline1.tsv"
  : > "$T/head1.tsv"
  printf 'test_b\n' > "$T/expected2.txt"
  printf 'test_b\tunrun\t0\n' > "$T/baseline2.tsv"
  printf 'test_b\tpass\t0\n' > "$T/head2.tsv"

  rc=0
  python3 "$D" --expected "$T/expected1.txt" --baseline "$T/baseline1.tsv" \
    --head "$T/head1.tsv" --granularity "$Gp" --runner pytest \
    --baseline-mode per-unit --head-mode per-unit \
    --baseline-detected pytest > "$T/adapter1.yaml" 2>"$T/adapter1.err" || rc=$?
  if [ "$rc" -ne 0 ]; then
    no "실제 producer(adapter1) 실행이 실패했다 (rc=$rc): $(cat "$T/adapter1.err")"
    rm -rf "$T"; return
  fi

  rc=0
  python3 "$D" --expected "$T/expected2.txt" --baseline "$T/baseline2.tsv" \
    --head "$T/head2.tsv" --granularity "$Gu" --runner unittest \
    --baseline-mode per-unit --head-mode per-unit \
    --baseline-detected unittest > "$T/adapter2.yaml" 2>"$T/adapter2.err" || rc=$?
  if [ "$rc" -ne 0 ]; then
    no "실제 producer(adapter2) 실행이 실패했다 (rc=$rc): $(cat "$T/adapter2.err")"
    rm -rf "$T"; return
  fi

  rc=0
  python3 "$D" --aggregate --expected-adapters 2 "$T/adapter1.yaml" "$T/adapter2.yaml" \
    > "$T/agg.yaml" 2>"$T/agg.err" || rc=$?
  if [ "$rc" -ne 0 ]; then
    no "실제 producer(aggregate) 실행이 실패했다 (rc=$rc): $(cat "$T/agg.err")"
    rm -rf "$T"; return
  fi

  out=$(python3 "$V" --differential "$T/agg.yaml")
  assert_grep "$out" '^verdict: not-certified$'      "실제 집계 산출물이 미판정을 만든다"
  assert_grep "$out" '^reason: baseline-unrunnable$' "열거 앞선 원인이 reason 이 된다(집계도 같은 표기)"
  assert_grep "$out" 'silent-drop'                   "두 번째 원인도 reasons 에서 소실되지 않는다"
  rm -rf "$T"
}

case_synth_off_is_byte_prefix_of_on() {
  # 차등 — 같은 입력으로 두 번 돌려 **off 출력이 on 출력의 접두** 인지 본다.
  # 「off 에 verdict 줄이 없다」만 재면 on 이 앞부분을 바꿔도 안 보인다.
  #
  # Ruling T6-a — rc 를 안 재면 이 케이스는 사각지대다. `off=$(...)` 는 stdout 만
  # 잡고 종료 코드를 안 본다: off 경로가 죽으면(트레이스백이 stdout 에 안 실리는
  # 크래시, 또는 부분 출력 후 죽는 크래시) `off` 가 비거나 짧아지고, `assert_not_grep
  # "$off" '^verdict: '` 는 그 빈/짧은 문자열에 대해 그대로 통과하며,
  # `"${on:0:${#off}}" == "$off"` 도 **빈 문자열의 0-길이 접두는 항상 빈 문자열과
  # 같으므로 트리비얼하게 통과**한다 — 죽은 off 경로가 "정상적으로 판정 줄을 안 냈다"
  # 와 구별되지 않는다(Task 6 mutation 실측: T5-1 1차 시도 로그
  # `synth/T5row1_partial.log`가 바로 이 모양 — 트레이스백이 찍힌 뒤 곧바로 ✓).
  # rc 를 먼저 확인해 이 사각지대를 막는다.
  local T; T=$(mktemp -d)
  printf -- '- {agent: r, file: a.py, line: 1, severity: IMPORTANT, confidence: 8, summary: s, proposed_fix: f}\n' > "$T/findings.yaml"
  rf_prep "$T"
  rf_reply "$T" 'verdicts: []
added: []'
  local off on off_rc on_rc
  off=$(rf_synth "$T"); off_rc=$?
  on=$(rf_synth "$T" --emit-verdict); on_rc=$?
  assert_eq "$off_rc" "0" "off 경로가 정상 종료한다(비정상 종료를 뒤 단언이 놓치지 않게 먼저 잡는다)"
  assert_eq "$on_rc"  "0" "on 경로가 정상 종료한다"
  assert_not_grep "$off" '^verdict: '  "기본값에서는 판정 줄이 없다"
  assert_grep     "$on"  '^verdict: '  "--emit-verdict 가 판정 줄을 켠다"
  assert_eq "${on:0:${#off}}" "$off"   "off 출력은 on 출력의 바이트 접두다"
  rm -rf "$T"
}

case_synth_kept_finding_is_defect() {
  local T; T=$(mktemp -d)
  printf -- '- {agent: r, file: a.py, line: 1, severity: SUGGESTION, confidence: 8, summary: s, proposed_fix: f}\n' > "$T/findings.yaml"
  rf_prep "$T"
  rf_reply "$T" 'verdicts: []
added: []'
  local out; out=$(rf_synth "$T" --emit-verdict)
  # 계획 R-B — severity 를 묻지 않는다. SUGGESTION 하나도 채택된 finding 이다.
  assert_grep "$out" '^verdict: defect$' "채택된 finding 이 있으면 defect"
  rm -rf "$T"
}

case_synth_lost_findings_is_not_certified() {
  # 원장의 blocks() — 항목이 소실되면 막는다. 공시(degraded)가 아니라 차단이다.
  local T; T=$(mktemp -d)
  printf -- '- not-a-mapping\n' > "$T/findings.yaml"
  rf_prep "$T"
  rf_reply "$T" 'verdicts: []'
  local out; out=$(rf_synth "$T" --emit-verdict)
  assert_grep "$out" '^verdict: not-certified$' "소실된 항목이 있으면 미판정"
  assert_grep "$out" '^reason: findings-lost$'  "사유가 findings-lost 다"
  rm -rf "$T"
}

case_synth_secondary_degrade_does_not_block() {
  # R-AD — 옛 픽스처(`verdicts: {a: 1}`, 매핑이 아닌 최상위 verdicts)는 재비판
  # 경로에서 대응이 없다: `recritic_bridge.to_adjudication_doc` 은 verdicts/added
  # 가 목록이 아니면 그 자체로 **판정자 사망**(주 입력 실패)을 낸다 — 옛 경로의
  # "보조 source_failed 만으로 degrade" 모양과 다르다. 같은 «성질»(차단 없이
  # degrade 만 공시된다)을 재비판 경로의 다른 강제 자리로 잰다 — 모르는 verdict
  # 동사(`downgrade`)의 `ledger.coerced(gate=True)`. finding 은 SUGGESTION ·
  # confidence 3 이라 confirm 으로 강제돼 살아도 suppress() 가 걸러 kept=0 이다.
  local T; T=$(mktemp -d)
  printf -- '- {agent: r, file: a.py, line: 1, severity: SUGGESTION, confidence: 3, summary: s}\n' > "$T/findings.yaml"
  rf_prep "$T"
  rf_reply "$T" 'verdicts:
  - f: f1
    verdict: downgrade
    to: SUGGESTION'
  local out; out=$(rf_synth "$T" --emit-verdict)
  # Controller fix round 1, Minor 2 — 전제(강제가 실제로 일어났다)를 먼저 잰다.
  # 이게 없으면 bridge 가 언젠가 `downgrade` 를 더 이상 강제하지 않도록 바뀌어도
  # (예: 조용히 무시) 이 케이스는 finding 이 어차피 억제돼 kept=0·clean 이라
  # 계속 GREEN 이다 — «차단 안 됨» 을 증명하려면 먼저 «강제가 있었다» 가 참이어야
  # 한다.
  assert_grep "$out" "강제\(게이트 변경\): verdict 'downgrade'" "전제 — 모르는 verdict 가 실제로 강제됐다"
  assert_grep "$out" '^verdict: clean$' "보조 축(모델 다양성) 손실만으로는 차단되지 않는다"
  assert_not_grep "$out" '^reason: '   "clean 에는 사유가 없다"
  rm -rf "$T"
}

case_synth_clean_is_clean() {
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"
  rf_prep "$T"
  rf_reply "$T" 'verdicts: []
added: []'
  local out; out=$(rf_synth "$T" --emit-verdict)
  assert_grep "$out" '^verdict: clean$' "발견 0 · 소실 0 이면 clean"
  rm -rf "$T"
}

case_synth_empty_differential_is_usage_error() {
  # Ruling T5-a — 합성기도 `verdict.py` 의 post-fix 계약을 그대로 거울처럼
  # 따른다: present-but-empty `--differential` 은 usage 오류(exit 2)지 판정축
  # 실패(exit 4)도, 조용한 clean(exit 0)도 아니다.
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/findings.yaml"
  rf_prep "$T"
  rf_reply "$T" 'verdicts: []
added: []'
  local rc=0
  rf_synth "$T" --emit-verdict --differential "" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "--differential 에 빈 문자열은 usage 오류다"
  rm -rf "$T"
}

case_synth_verdict_flags_without_emit_are_usage_error() {
  # I1 (리뷰 라운드 2) — off + 판정 입력 플래그 조합을 실측했더니 셋은
  # rc=0·verdict_lines=0·stderr 없음(조용한 소실)이었고, 오직
  # `--differential ""`(위 케이스) 만 usage 오류로 닫혀 있었다. 이것은
  # Ruling T5-a 가 이미 닫은 것과 같은 fail-open 계열이다: 나중 호출자가
  # `--differential "$agg_yaml"` 을 주고 `--emit-verdict` 를 빼먹으면 완전해
  # 보이는 보고서 + rc=0 이 나가고 차등 축 전체가 그 실행에서 조용히
  # 사라진다. 두 플래그(`--differential`·`--reason`) 모두 `--emit-verdict`
  # 없이는 의미가 없으므로 대칭으로 막는다 — exit 2(usage 오류)지 exit
  # 4(판정축 실패)가 아니다: 잘못된 *호출*이지 실패한 *판정*이 아니다.
  #
  # R-AD — 옛 픽스처는 이 세 호출의 운반체로 `--adversarial "$T/adv.yaml"` 을
  # 곁들였다. `--adversarial` 이 사라진 지금 그 인자를 그대로 두면 argparse 가
  # 「모르는 인자」로 먼저 exit 2 를 내 세 단언이 **공허하게** 통과한다 — 운반체를
  # 빼고(`--findings` 만 둔다), exit 2 를 기대하는 단언마다 stderr 의 사유
  # 문장도 함께 재 「모르는 인자」의 exit 2 와 구별한다.
  local T; T=$(mktemp -d)
  printf '[]\n' > "$T/f.yaml"
  local valid_reason; valid_reason=$(printf '%s\n' "$REASONS" | head -1)

  local rc=0 err
  err=$(python3 "$SYNTH" --findings "$T/f.yaml" \
    --differential /nonexistent/does-not-matter 2>&1 >/dev/null) || rc=$?
  assert_eq "$rc" "2" "--emit-verdict 없는 --differential <경로> 는 usage 오류다"
  assert_grep "$err" '없이는 의미가 없다' "「모르는 인자」의 exit 2 가 아니라 usage 사유 문장이다"

  rc=0
  err=$(python3 "$SYNTH" --findings "$T/f.yaml" \
    --reason "$valid_reason" 2>&1 >/dev/null) || rc=$?
  assert_eq "$rc" "2" "--emit-verdict 없는 --reason <열거값> 은 usage 오류다 — 값이 유효해도 마찬가지다"
  assert_grep "$err" '없이는 의미가 없다' "「모르는 인자」의 exit 2 가 아니라 usage 사유 문장이다"

  rm -rf "$T"
}

case_synth_verdict_failure_is_atomic() {
  # Ruling T5-b — 판정 «계산» 은 본 보고서를 쓰기 «전» 에 한다. 디코드 불가한
  # `--differential` 이 `read_or_none()` 의 fail4 를 태우면, 그 시점에 stdout 은
  # 아직 비어 있어야 한다 — 이 리포의 fail4 계약(원자적·무출력)을 이 소비자도
  # 지킨다.
  #
  # 단언은 **둘**이다 — exit 코드 하나만 재면 이빨이 없다. 판정 계산을 본
  # 보고서 뒤로 옮겨도 exit 4 단언은 여전히 통과한다: 실패가 나긴 나기
  # 때문이다. stdout-빈값 단언만이 그 순서를 구별한다.
  #
  # 픽스처는 **유효한 차등 산출물 본문 + 그 뒤에 곧바로 붙는 나쁜 바이트**다
  # (`read_or_none()` 의 `f.read()` 는 파일 전체를 한 번에 디코드하므로 앞부분이
  # 유효해도 뒤의 나쁜 바이트가 여전히 `UnicodeDecodeError` 를 낸다) — 그래야
  # `causes_of()` 의 zero-hit 경로라는 다른 이유로 우연히 같은 exit 4 가 나는
  # green-for-the-wrong-reason 을 피한다.
  local T; T=$(mktemp -d)
  printf -- '- {agent: r, file: a.py, line: 1, severity: IMPORTANT, confidence: 8, summary: s, proposed_fix: f}\n' > "$T/findings.yaml"
  rf_prep "$T"
  rf_reply "$T" 'verdicts: []
added: []'
  printf 'attribution_status: degraded\ndegrade_causes: [silent-drop]\nverdict_input:\n  confirmed_product_defect: false\n  silent_drop: true\n  baseline_unrunnable: false\n\xff\xfe' > "$T/bad.yaml"
  local out rc=0
  out=$(rf_synth "$T" --emit-verdict --differential "$T/bad.yaml" 2>/dev/null) || rc=$?
  assert_eq "$rc" "4"  "디코드 불가 차등 산출물은 exit 4"
  assert_eq "$out" ""  "그 실행의 stdout 은 비어 있다 — 판정 실패는 원자적이다(이 단언이 이빨이다)"
  rm -rf "$T"
}

case_three_values_only
case_reason_flag_certifies_known_members
case_reason_enum_is_closed_and_accounted
case_unknown_reason_is_fail_closed
case_not_certified_always_has_reason
case_kill_switch_is_not_certified
case_review_blocked_is_not_certified
case_angle_absent_is_not_certified
case_angle_absent_and_findings_lost_are_distinct
case_review_blocked_survives_under_defect
case_precedence_defect_wins
case_precedence_not_certified_beats_clean
case_reason_is_first_in_enum_order
case_reason_is_member_of_reasons
case_clean_carries_no_reason
case_legacy_table_is_gone
case_differential_causes_become_reasons
case_differential_defect_flag_wins
case_unreadable_differential_is_fail_closed
case_non_utf8_differential_is_fail_closed
case_empty_differential_flag_is_usage_error
case_fail4_uses_scriptname_prefix_not_verdict_key
case_render_enforces_values_and_reasonless_guard
case_degrade_causes_and_cause_to_reason_are_bijective
case_real_producer_per_adapter_feeds_verdict
case_real_producer_aggregate_feeds_verdict
case_synth_off_is_byte_prefix_of_on
case_synth_kept_finding_is_defect
case_synth_lost_findings_is_not_certified
case_synth_secondary_degrade_does_not_block
case_synth_clean_is_clean
case_synth_empty_differential_is_usage_error
case_synth_verdict_flags_without_emit_are_usage_error
case_synth_verdict_failure_is_atomic
finish "test_verdict_vocabulary"
