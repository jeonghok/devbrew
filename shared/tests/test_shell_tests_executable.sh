#!/usr/bin/env bash
# 스위트가 고르는 셸 테스트는 전부 git 인덱스에서 100755 여야 한다.
# 고르는 규칙은 run-all.sh 의 find 명령에서 꺼낸다(사본을 두지 않는다).
# 환경: RUNALL=<run-all.sh 경로> 로 다른 사본을 겨눌 수 있다(변이용).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
. "$ROOT/shared/tests/assert.sh"
cd "$ROOT" || exit 1
RUNALL="${RUNALL:-$ROOT/tools/suite/run-all.sh}"

find_cmd="$(sed -nE 's/.*< <\((find [^|]*[^| ]) *\|.*/\1/p' "$RUNALL" | head -n 1)"
if [ -z "$find_cmd" ]; then
  no "run-all.sh 에서 find 명령을 뽑지 못했다"
  finish
  exit $?
fi
selected="$(bash -c "$find_cmd" 2>/dev/null | LC_ALL=C sort)"
n_sel="$(printf '%s' "$selected" | grep -c .)"
if [ "$n_sel" -eq 0 ]; then
  no "뽑은 find 명령이 셸 테스트를 0개 골랐다: $find_cmd"
  finish
  exit $?
fi
ok "run-all.sh 가 셸 테스트 ${n_sel}개를 고른다"

modes="$(git ls-files -s)"
bad=0
while IFS= read -r f; do
  m="$(printf '%s\n' "$modes" | awk -F'\t' -v p="$f" '$2==p{split($1,a," "); print a[1]; exit}')"
  if [ "$m" != "100755" ]; then
    no "실행 비트가 없다: $f (mode=${m:-인덱스에 없음})"
    bad=$((bad+1))
  fi
done <<< "$selected"
[ "$bad" -eq 0 ] && ok "고른 ${n_sel}개가 모두 100755 다"

# 양성 대조 — 독립 도출의 수가 뽑은 find 의 수와 같다
indep="$(git ls-files shared plugins | grep -E '(^|/)test_[^/]*\.sh$' | grep -vE '/(spike|fixtures)/' | grep -cE '^(shared/tests|plugins/[^/]+/tests)/')"
assert_eq "$n_sel" "$indep" "양성 대조: find 가 고른 수 = 독립 도출 수"
finish
