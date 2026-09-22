#!/usr/bin/env bash
# test_resolution_disclosure.sh — AC13 (설계 §6.4.2).
#
# 이 락이 반드시 **두 층** 을 재는 이유: 어댑터가 여럿이면 오케스트레이터가 읽는
# 산출물은 집계다. per-adapter 만 재는 락은 GREEN 인 채로 실제 소비자가 공시를
# 한 번도 못 보는 상태를 통과시킨다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
DIFF="$PLUGIN_ROOT/scripts/diff-test-results.py"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

T=""
cleanup() { cd / && rm -rf "$T"; }

# per-adapter 한 번 — <expected> <baseline TSV> <head TSV> <granularity> <runner>
adapter() {
  T=$(mktemp -d) || exit 1
  printf '%s\n' "$1" > "$T/e.txt"
  printf '%s\n' "$2" > "$T/b.tsv"
  printf '%s\n' "$3" > "$T/h.tsv"
  python3 "$DIFF" --expected "$T/e.txt" --baseline "$T/b.tsv" --head "$T/h.tsv" \
    --granularity "$4" --runner "$5" --baseline-mode per-unit --head-mode per-unit \
    --baseline-detected "$5"
}

DISCLOSURE='resolution_disclosure: "양측 빨강 unit'

case_per_adapter_present() {
  # unit 둘 — pre_existing==1 로는 상수 "1"을 하드코딩한 mutation과 실제 개수를
  # 구별할 수 없다(Task 6 mutation 으로 실측: 상수 치환이 GREEN 으로 남았다).
  # 값을 실제 개수와 다른 2로 만들어야 「공시가 실제 개수를 싣는다」가 상수를 배제한다.
  local out; out=$(adapter "$(printf 'u1\nu2')" \
    "$(printf 'u1\tfail\t1\nu2\tfail\t1')" "$(printf 'u1\tfail\t1\nu2\tfail\t1')" file pytest)
  assert_grep "$out" '^resolution_disclosure: ' "pre_existing>0 이면 공시 줄이 있다"
  assert_grep "$out" 'unit 2개'                  "공시가 실제 개수를 싣는다(상수 1이 아니다)"
  # 전체 줄을 고정 — 개수만 재는 위 단언은 문구 중간의 조사 하나가 바뀌어도
  # (예: "실패는" → "실패가") 못 잡는다(Task 6 mutation 으로 실측: GREEN 으로
  # 남았다). 정확한 한 줄을 통째로 대조해야 문구 자체가 이빨의 대상이 된다.
  local line; line=$(printf '%s\n' "$out" | grep '^resolution_disclosure: ')
  assert_eq "$line" \
    'resolution_disclosure: "양측 빨강 unit 2개 — 그 안의 새 실패는 이 해상도(unit 당 종료 코드 하나)에서 보이지 않는다"' \
    "공시 문구 전체가 정확히 고정된 문자열이다(조사 하나만 바뀌어도 이 단언이 깨진다)"
  cleanup
}

case_per_adapter_absent_when_zero() {
  local out; out=$(adapter 'u1' "$(printf 'u1\tpass\t0')" "$(printf 'u1\tpass\t0')" file pytest)
  assert_not_grep "$out" '^resolution_disclosure: ' "pre_existing==0 이면 공시 줄이 없다"
  cleanup
}

case_disclosure_does_not_block() {
  # 공시는 «막지 않는다» — granularity:file + pre_existing 만으로는 degraded 가 아니다.
  local out; out=$(adapter 'u1' "$(printf 'u1\tfail\t1')" "$(printf 'u1\tfail\t1')" file pytest)
  assert_grep "$out" '^attribution_status: closed' "공시는 인증을 막지 않는다"
  cleanup
}

case_existing_bulk_guard_survives() {
  # …그러나 기존 가드는 그대로다. 이 둘을 한 케이스로 합치면 「공시를 넣다가 가드를
  # 조용히 지웠다」가 보이지 않는다.
  #
  # runner 는 brief 초안의 `pytest` 가 아니라 `make` 다: `granularity_of()`
  # (run-test-selection.sh:224-231)에서 pytest 의 실제 입도는 `file` 이라
  # `--granularity bulk`를 같이 주면 `verify_granularity`가 소유자 대조에서
  # exit 4 로 거절한다(pytest/unittest/shell/jest/vitest=file, go=package,
  # cargo/make/npm-script=bulk). bulk 를 실제로 재려면 bulk 러너가 필요하다.
  local out; out=$(adapter 'u1' "$(printf 'u1\tfail\t1')" "$(printf 'u1\tfail\t1')" bulk make)
  assert_grep "$out" '^attribution_status: degraded' "bulk + pre_existing 은 여전히 degraded"
  assert_grep "$out" 'bulk-pre-existing'              "그 사유가 이름을 갖는다"
  assert_grep "$out" '^resolution_disclosure: '       "degraded 여도 공시는 나간다"
  cleanup
}

# 집계 fixture 는 손으로 쓰지 않는다 — 실제 per-adapter 모드를 돌려 그 stdout 을
# 파일로 옮긴다(test_diff_test_results.py 의 `write_real_adapter_yaml` 의 셸
# 동형; 컨트롤러 ruling T3-a). 손 fixture 는 프로듀서의 불변식과 어긋날 수 있고
# (Task 2 리뷰가 실측: `silent_drop: true` 와 `attribution_status: closed` 가
# 동시에 있는, 실제 스크립트는 낼 수 없는 조합), 필수 키 하나(`degrade_causes:`
# 포함 다섯 개)라도 빠뜨리면 `parse_adapter_yaml`의 `_one()`이 파싱 단계에서
# fail4 로 죽어 그 RED 가 "단언이 잡은 것"과 구별되지 않는다.
adapter_yaml() {   # adapter_yaml <destfile> <expected> <baseline TSV> <head TSV> <granularity> <runner>
  local dest="$1" exp="$2" btsv="$3" htsv="$4" gran="$5" runner="$6"
  local d; d=$(mktemp -d) || exit 1
  printf '%s\n' "$exp" > "$d/e.txt"
  printf '%s\n' "$btsv" > "$d/b.tsv"
  printf '%s\n' "$htsv" > "$d/h.tsv"
  python3 "$DIFF" --expected "$d/e.txt" --baseline "$d/b.tsv" --head "$d/h.tsv" \
    --granularity "$gran" --runner "$runner" --baseline-mode per-unit --head-mode per-unit \
    --baseline-detected "$runner" > "$dest"
  rm -rf "$d"
}

case_aggregate_carries_disclosure() {
  # ★ 이 케이스가 이 락의 존재 이유다. 어댑터 «셋» — pytest(unit 둘 다 양측 fail,
  # pre_existing 2), shell·go(둘 다 pre_existing 0) — 을 실제 per-adapter 모드로
  # 만들어 --aggregate 로 돌린다. 기대: 최상위 resolution_disclosure 가 있고
  # N == 2(세 어댑터의 «합» — 어댑터 «개수»(3)와 일부러 다르게 만들어, 합을 개수로
  # 바꿔치기하는 mutation 이 이 단언 하나만으로는 안 잡히는 것을 막는다. Task 6
  # mutation 실측: 어댑터 둘 · pre_existing 합 2 였던 이전 fixture는 개수(2)와
  # 합(2)이 우연히 같아 `len(per_adapter_counts)`로 바꿔치기해도 이 단언이
  # GREEN 으로 남았다 — 별개 케이스(`case_aggregate_absent_when_all_zero`)가
  # 대신 잡았을 뿐, 이 단언 자신은 이빨이 없었다).
  T=$(mktemp -d) || exit 1
  adapter_yaml "$T/pytest.yaml" \
    "$(printf 'u1\nu2')" \
    "$(printf 'u1\tfail\t1\nu2\tfail\t1')" \
    "$(printf 'u1\tfail\t1\nu2\tfail\t1')" \
    file pytest
  adapter_yaml "$T/shell.yaml" \
    "$(printf 'u3')" "$(printf 'u3\tpass\t0')" "$(printf 'u3\tpass\t0')" \
    file shell
  adapter_yaml "$T/go.yaml" \
    "$(printf 'u4')" "$(printf 'u4\tpass\t0')" "$(printf 'u4\tpass\t0')" \
    package go
  local out
  out=$(python3 "$DIFF" --aggregate --expected-adapters 3 "$T/pytest.yaml" "$T/shell.yaml" "$T/go.yaml")
  assert_grep "$out" '^resolution_disclosure: ' "집계 최상위에 공시 줄이 있다"
  assert_grep "$out" "$DISCLOSURE"               "공시 문구가 집계에서도 같다"
  assert_grep "$out" 'unit 2개'                  "집계의 N 은 세 어댑터의 합(2)이다 — 어댑터 개수(3)로 바꿔치기하면 이 단언이 깨진다"
  cleanup
}

case_aggregate_absent_when_all_zero() {
  # 두 어댑터 모두 pre_existing 0 → 최상위 공시 줄 없음.
  T=$(mktemp -d) || exit 1
  adapter_yaml "$T/pytest.yaml" \
    "$(printf 'u1')" "$(printf 'u1\tpass\t0')" "$(printf 'u1\tpass\t0')" \
    file pytest
  adapter_yaml "$T/shell.yaml" \
    "$(printf 'u2')" "$(printf 'u2\tpass\t0')" "$(printf 'u2\tpass\t0')" \
    file shell
  local out
  out=$(python3 "$DIFF" --aggregate --expected-adapters 2 "$T/pytest.yaml" "$T/shell.yaml")
  assert_not_grep "$out" '^resolution_disclosure: ' "두 어댑터 모두 0 이면 집계 공시가 없다"
  cleanup
}

case_per_adapter_present
case_per_adapter_absent_when_zero
case_disclosure_does_not_block
case_existing_bulk_guard_survives
case_aggregate_carries_disclosure
case_aggregate_absent_when_all_zero
finish
