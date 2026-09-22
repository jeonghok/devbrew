#!/usr/bin/env bash
# test_verdict_vocabulary.sh — AC8 · AC9 · AC23 (설계 §6.4.3).
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
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
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
  # Important 1 — 11 값 각각이 셋 중 하나에 «속한다», 그리고 그 셋의 합집합이
  # REASONS 와 «같다»(양방향). 산출자가 아직 없는 다섯은 부채로 이름을 적어 둔다.
  # PR3 가 angle-absent 를 배선하면 같은 커밋에서 이 debt 목록이 줄어야 한다 —
  # 부채가 원장이 되고, 열거에 값을 몰래 더하는 경로(위 case 가 못 잡는 경로)가
  # 여기서 닫힌다. `len(REASONS)` 를 직접 고정해 "닫힌 11값 열거" 를 처음으로
  # 측정한다 — VALUES 는 case_three_values_only 가 개수를 재지만 REASONS 는
  # 이 라운드 전까지 아무 케이스도 크기를 재지 않았다(실측 결함).
  #
  # 실측 3분할(코디네이터 정정 — 최초 지시의 5값 목록은 방향이 둘 다 틀렸었다):
  #   차등 축 산출 가능(5): scope-empty · baseline-unrunnable · silent-drop ·
  #                        error-axis · granularity-smear (CAUSE_TO_REASON.values())
  #   모듈 자신의 플래그로 산출 가능(1): findings-lost (decide(review_blocked=True))
  #   호출자-전용 부채, 이 PR 에 산출자 없음(5): trivia · kill-switch ·
  #                        declaration-invalid · merge-conflict · angle-absent
  local debt="angle-absent declaration-invalid kill-switch merge-conflict trivia"
  local got; got=$(python3 -c "
import sys; sys.path.insert(0,'$PLUGIN_ROOT/scripts'); import verdict
covered = set(verdict.CAUSE_TO_REASON.values()) | {'findings-lost'} | set('''$debt'''.split())
print('MISSING:' + ','.join(sorted(set(verdict.REASONS) - covered)))
print('STALE:'   + ','.join(sorted(covered - set(verdict.REASONS))))
print('N:%d' % len(verdict.REASONS))")
  assert_grep "$got" '^MISSING:$' "열거의 모든 사유가 산출자 또는 부채 목록에 귀속된다"
  assert_grep "$got" '^STALE:$'   "부채 목록·매핑에 열거 밖 이름이 없다"
  assert_grep "$got" '^N:11$'     "사유 열거는 정확히 열한 값이다"
}

case_unknown_reason_is_fail_closed() {
  local rc=0; python3 "$V" --reason made-up-reason >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "열거 밖 사유는 exit 4"
}

case_not_certified_always_has_reason() {
  # AC8 후반 — 사유 없는 not-certified 는 **낼 수 없다**. 옛 SKIP_WITH_EVIDENCE 가
  # 정확히 그 형태(사유를 싣지 않는 미판정)라 매핑만으로는 AC8 을 어긴다.
  local rc=0; python3 "$V" --legacy-verdict SKIP_WITH_EVIDENCE >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "사유 없는 not-certified 는 exit 4"
  local out; out=$(python3 "$V" --legacy-verdict SKIP_WITH_EVIDENCE --reason kill-switch)
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

case_legacy_table_is_exactly_four() {      # AC23
  # PR4 가 **지울 블록** 이다. 넷보다 적으면 산출자 하나가 매핑 없이 남고,
  # 많으면 이 PR 이 설계가 지운 어휘를 되살린 것이다.
  local n; n=$(python3 -c "import sys; sys.path.insert(0, '$PLUGIN_ROOT/scripts'); import verdict; print(len(verdict.LEGACY_VERDICTS))")
  assert_eq "$n" "4" "옛 어휘 매핑표는 정확히 네 값"
  local out
  out=$(python3 "$V" --legacy-verdict PASS); assert_grep "$out" '^verdict: clean$'  "PASS → clean"
  out=$(python3 "$V" --legacy-verdict FAIL); assert_grep "$out" '^verdict: defect$' "FAIL → defect"
  local rc=0; python3 "$V" --legacy-verdict MADE_UP >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "미지의 옛 값은 exit 4"
}

case_needs_resolution_requires_reason() {
  # Minor 3 — 옛 네 값 중 NEEDS_RESOLUTION 만 유일하게 어떤 케이스에서도
  # `--legacy-verdict` 로 불려 본 적이 없었다. 그 매핑을 `"clean"` 으로 바꿔도
  # `len(LEGACY_VERDICTS)==4` 는 그대로라 `case_legacy_table_is_exactly_four` 는
  # 못 잡고, (이 케이스 추가 전) 17케이스 전부 GREEN 으로 남았다(실측) — 옛
  # "미해결" 이 `clean` 으로 인증되는 경로가 무방비였다는 뜻이다.
  local rc=0; python3 "$V" --legacy-verdict NEEDS_RESOLUTION >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "사유 없는 NEEDS_RESOLUTION 은 exit 4"
  local out; out=$(python3 "$V" --legacy-verdict NEEDS_RESOLUTION --reason kill-switch)
  assert_grep "$out" '^verdict: not-certified$' "사유를 주면 미판정이 선다"
}

case_legacy_table_marked_for_removal() {
  # PR4 가 찾을 수 있어야 한다. 주석 문구가 아니라 **표 자체**가 한 자리에 있는지 본다.
  #
  # Ruling P2 — 브리프 원안은 이 카운트를 2(정의 1 + 사용 1)로 기대했지만, 브리프
  # 자신의 verdict.py 원문은 `LEGACY_VERDICTS` 리터럴을 **세** 자리에서 쓴다:
  #   ① 정의        — `LEGACY_VERDICTS = {`
  #   ② 소속 검사    — `if legacy_verdict not in LEGACY_VERDICTS:`
  #   ③ 조회         — `mapped = LEGACY_VERDICTS[legacy_verdict]`
  # 2로 두면 정확한 구현에서마저 이 단언이 RED 가 된다. 그래서 실측한 3을 핀
  # 한다 — "표를 두 자리로 쪼개기" 변이(PR4 가 한쪽만 지우는 경로)는 이 세 자리
  # 중 하나가 다른 이름으로 갈라지므로 카운트가 이 3에서 움직여 여전히 RED 다.
  local hits; hits=$(grep -c 'LEGACY_VERDICTS' "$V")
  assert_eq "$hits" "3" "매핑표는 ①정의 ②소속검사 ③조회, 정확히 세 자리다"
  # Minor 4 — 'AC23' 단독 패턴은 헤더-satisfiable 이다: 모듈 docstring 1행에도
  # "AC23" 이 나오므로, 블록 «전체» 를 지워도(정의·소속검사·조회 세 자리를 통째로
  # 삭제해도) docstring 이 남아 있는 한 이 단언은 GREEN 이었다(실측) — 주석이
  # 주장하는 "PR4 가 지울 블록임이 적혀 있다" 와 정반대로 몸통 없이도 통과했다.
  # 몸통에만 있는 종결 표지로 앵커를 옮긴다.
  assert_file_grep "$V" 'AC23 블록 끝' "PR4 가 지울 블록의 몸통(종결 표지)이 파일에 적혀 있다"
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
  local T; T=$(mktemp -d)
  printf '\xff\xfe\x00bad' > "$T/bad.yaml"
  local rc=0; python3 "$V" --differential "$T/bad.yaml" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "비-UTF-8 차등 산출물은 exit 4 — exit 1 raw traceback 이 아니다"
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

case_empty_legacy_verdict_flag_is_usage_error() {
  local rc=0; python3 "$V" --legacy-verdict "" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "--legacy-verdict 에 빈 문자열은 usage 오류다"
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

case_three_values_only
case_reason_flag_certifies_known_members
case_reason_enum_is_closed_and_accounted
case_unknown_reason_is_fail_closed
case_not_certified_always_has_reason
case_kill_switch_is_not_certified
case_review_blocked_is_not_certified
case_review_blocked_survives_under_defect
case_precedence_defect_wins
case_precedence_not_certified_beats_clean
case_reason_is_first_in_enum_order
case_reason_is_member_of_reasons
case_clean_carries_no_reason
case_legacy_table_is_exactly_four
case_needs_resolution_requires_reason
case_legacy_table_marked_for_removal
case_differential_causes_become_reasons
case_differential_defect_flag_wins
case_unreadable_differential_is_fail_closed
case_non_utf8_differential_is_fail_closed
case_empty_differential_flag_is_usage_error
case_empty_legacy_verdict_flag_is_usage_error
case_degrade_causes_and_cause_to_reason_are_bijective
case_real_producer_per_adapter_feeds_verdict
case_real_producer_aggregate_feeds_verdict
finish "test_verdict_vocabulary"
