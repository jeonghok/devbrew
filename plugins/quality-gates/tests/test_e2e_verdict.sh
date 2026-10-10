#!/usr/bin/env bash
# test_e2e_verdict.sh — e2e 결과가 최종 판정과 판정 줄에 닿는 이음매(설계 v10 §1 표 · AC1 · AC2 · AC3).
#
# 최종 판정은 `verdict.py --prior <마지막 iteration 의 판정 출력> --e2e <상태> --line …` 한 번이다.
# 우선순위를 오케스트레이터가 머리로 합치지 않는다(색인 K-3) — 그래서 이음매를 이 CLI 에서 잰다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
V="$PLUGIN_ROOT/scripts/verdict.py"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
printf 'verdict: clean\n' >"$T/clean"
printf 'verdict: defect\n' >"$T/defect"
printf 'verdict: not-certified\nreason: scope-empty\nreasons: [scope-empty]\n' >"$T/nc"
LINE=(--line --blocking 0 --optional 2 --new-failures 0 --excluded 1 --iter 3 --sha abc1234)

final() {   # $1 앞 판정 파일 · $2 e2e 상태 · 나머지 추가 플래그
  local prior="$1" state="$2"; shift 2
  python3 "$V" --prior "$prior" --e2e "$state" "${LINE[@]}" "$@"
}

case_AC1_approved_fail_is_defect_and_line_says_both() {
  local out; out=$(final "$T/clean" fail)
  assert_grep "$out" '^verdict: defect$' "AC1: 승인된 e2e fail 은 defect"
  assert_grep "$out" '^qg: defect · ' "AC1: 판정 줄이 qg: defect 로 시작한다"
  assert_grep "$out" ' · e2e fail · ' "AC1: 판정 줄이 e2e fail 을 싣는다"
}

case_AC2_unconfirmed_on_clean_is_not_certified() {
  local out; out=$(final "$T/clean" 미확인)
  assert_grep "$out" '^verdict: not-certified$' "AC2: 다른 축 clean + e2e 미확인 → not-certified"
  assert_grep "$out" '^reason: e2e-unconfirmed$' "AC2: 사유 e2e-unconfirmed"
  assert_grep "$out" '^qg: not-certified \(e2e-unconfirmed\) · ' "AC2: 판정 줄도 같다"
  assert_grep "$out" ' · e2e 미확인 · ' "AC2: e2e 칸이 미확인"
}

case_AC2_unconfirmed_keeps_defect_and_earlier_reason() {
  local out; out=$(final "$T/defect" 미확인)
  assert_grep "$out" '^verdict: defect$' "AC2: 다른 축 defect 면 판정은 그대로 defect"
  assert_grep "$out" ' · e2e 미확인 · ' "AC2: defect 여도 e2e 칸에 미확인"
  out=$(final "$T/nc" 미확인)
  assert_grep "$out" '^reason: scope-empty$' "AC2: 앞선 사유(scope-empty)가 맨 앞에 남는다"
  assert_grep "$out" '^reasons: \[scope-empty, e2e-unconfirmed\]$' "AC2: e2e-unconfirmed 는 사유 맨 뒤"
}

case_AC3_no_walk_states_do_not_change_verdict() {
  local s p out want
  for p in clean defect nc; do
    want=$(sed -n 's/^verdict: //p' "$T/$p")
    for s in "안 함" "걸을 것 없음" "걸을 도구 없음" "꺼짐(kill switch)" pass; do
      out=$(final "$T/$p" "$s")
      assert_grep "$out" "^verdict: $want\$" "AC3: e2e '$s' 는 앞 판정($p)을 바꾸지 않는다"
      assert_contains "$out" " · e2e $s · " "AC3: 판정 줄의 e2e 칸이 '$s'"
    done
  done
}

case_override_suffix() {
  local out; out=$(final "$T/clean" fail --e2e-overridden)
  assert_contains "$out" " · e2e fail (사람이 뒤집음) · " "뒤집은 판정은 판정 줄에 (사람이 뒤집음) 이 붙는다"
}

case_line_order_and_shape() {
  local out; out=$(final "$T/clean" pass | tail -n 1)
  assert_eq "$out" "qg: clean · 막는 지적 0 · 선택 2 · 차등 새 실패 0 · e2e pass · 제외 패치 1 · iter 3 · abc1234" \
    "e2e 칸은 차등 새 실패 뒤, 제외 패치 앞이다(색인 K-3)"
}

case_bad_calls_are_usage_errors() {
  local rc
  rc=0; python3 "$V" --prior "$T/clean" --e2e 몰라 "${LINE[@]}" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "열거 밖 e2e 상태는 exit 2"
  rc=0; python3 "$V" --prior "$T/clean" --e2e pass >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "--e2e 는 --line 없이 exit 2"
  rc=0; python3 "$V" --prior "$T/clean" --differential "$T/clean" "${LINE[@]}" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "--prior 와 --differential 을 함께 주면 exit 2"
  rc=0; python3 "$V" --prior "$T/clean" --e2e-overridden "${LINE[@]}" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "--e2e-overridden 는 --e2e 없이 exit 2"
  rc=0; python3 "$V" --prior "$T/clean" --defect --e2e pass "${LINE[@]}" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "--prior 와 --defect 를 함께 주면 exit 2(앞 판정이 두 번 들어간다)"
  rc=0; python3 "$V" --prior "" --e2e pass "${LINE[@]}" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "--prior 빈 문자열은 exit 2"
  rc=0; python3 "$V" --prior "$T/clean" --reason trivia --e2e pass "${LINE[@]}" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "--prior 와 --reason 을 함께 주면 exit 2"
  rc=0; python3 "$V" --prior "$T/clean" --review-blocked --e2e pass "${LINE[@]}" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "--prior 와 --review-blocked 를 함께 주면 exit 2"
  rc=0; python3 "$V" --prior "$T/clean" --angle-absent --e2e pass "${LINE[@]}" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "2" "--prior 와 --angle-absent 를 함께 주면 exit 2"
}

case_V8_unreadable_prior_is_fail_closed() {
  local rc f
  for f in "verdict: clean\nverdict: clean\n" "verdict: maybe\n" "verdict: not-certified\n" \
           "verdict: clean\nreasons: [scope-empty]\n" "verdict: not-certified\nreason: made-up\nreasons: [made-up]\n" "" \
           "verdict: not-certified\nreason: kill-switch\nreasons: [scope-empty, kill-switch]\n" \
           "verdict: defect\nreason: scope-empty\n"; do
    printf '%b' "$f" >"$T/bad"
    rc=0; python3 "$V" --prior "$T/bad" --e2e pass "${LINE[@]}" >/dev/null 2>&1 || rc=$?
    assert_eq "$rc" "4" "모순되거나 판독 불가한 앞 판정은 exit 4: $(printf '%b' "$f" | tr '\n' '|')"
  done
}

for c in $(declare -F | awk '{print $3}' | grep '^case_'); do
  note "── $c"
  "$c"
done
finish
