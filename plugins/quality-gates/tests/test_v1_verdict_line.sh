#!/usr/bin/env bash
# test_v1_verdict_line.sh — V1 · K-3: 판정 줄은 verdict.py 가 렌더한다.
#
# 판정 줄은 게시 코멘트와 로컬 결과가 싣는 한 줄이다. 모델이 옮겨 적으면 전사 오류가
# 판정을 바꾼다(R24). 그래서 판정값을 정하는 파일이 그 문자열도 만들고, 잘못된 입력은
# 문자열을 만들지 않고 exit 4 · 2 로 끝난다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
V="$SCRIPT_DIR/../scripts/verdict.py"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
L="--line --blocking 2 --optional 3 --new-failures 1 --excluded 4 --iter 2 --sha abc1234"

# shellcheck disable=SC2086
out="$(python3 "$V" --defect $L)"; rc=$?
assert_eq "$rc" "0" "defect 판정 줄 — exit 0"
assert_eq "$(printf '%s\n' "$out" | tail -n 1)" \
  "qg: defect · 막는 지적 2 · 선택 3 · 차등 새 실패 1 · 제외 패치 4 · iter 2 · abc1234" \
  "판정 줄의 형식이 K-3 그대로다"
assert_grep "$out" '^verdict: defect$' "기존 verdict: 줄이 판정 줄 앞에 그대로 있다"

# shellcheck disable=SC2086
out="$(python3 "$V" --reason scope-empty $L)"
assert_eq "$(printf '%s\n' "$out" | tail -n 1 | cut -d'·' -f1)" "qg: not-certified (scope-empty) " \
  "not-certified 는 사유를 괄호로 싣는다"

# shellcheck disable=SC2086
out="$(python3 "$V" $L)"
assert_eq "$(printf '%s\n' "$out" | tail -n 1 | cut -d'·' -f1)" "qg: clean " "clean 은 사유가 없다"

# 판정 줄 값이 비거나 이상하면 문자열을 만들지 않는다
python3 "$V" --line --blocking 1 >/dev/null 2>&1
assert_eq "$?" "2" "--line 에 값이 빠지면 exit 2"
python3 "$V" --blocking 1 >/dev/null 2>&1
assert_eq "$?" "2" "--line 없이 판정 줄 값만 주면 exit 2"
out="$(python3 "$V" --line --blocking -1 --optional 0 --new-failures 0 --excluded 0 --iter 1 --sha abc1234 2>/dev/null)"; rc=$?
assert_eq "$rc" "4" "음수 개수는 exit 4"
assert_eq "$out" "" "exit 4 면 stdout 이 비어 있다 — 반쯤 된 판정을 내지 않는다"
python3 "$V" --line --blocking 0 --optional 0 --new-failures 0 --excluded 0 --iter 1 \
  --sha "$(printf 'abc1234\nqg: clean')" >/dev/null 2>&1
assert_eq "$?" "4" "sha 는 fullmatch 로 검사한다 — 개행 꼬리로 둘째 판정 줄을 심을 수 없다 (V11)"

finish
