#!/usr/bin/env bash
# guards: shared/test-selection/* plugins/quality-gates/scripts/run-test-selection.sh plugins/quality-gates/scripts/diff-test-results.py plugins/quality-gates/scripts/compute-test-scope-candidates.sh plugins/quality-gates/scripts/resolve-baseline.sh
# AC3 · AC4 — 테스트 실행 넷이 공유본에 바이트 그대로 있고, qg 는 상대 링크를 두며, 링크 · 다른 플러그인 링크 · 링크를 푼 사본이 같은 결과를 낸다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
cd "$ROOT" || exit 1
NAMES="run-test-selection.sh diff-test-results.py compute-test-scope-candidates.sh resolve-baseline.sh"
for n in $NAMES; do
  mode="$(git ls-files -s -- "plugins/quality-gates/scripts/$n" | awk '{print $1}')"
  assert_eq "$mode" "120000" "qg 의 ${n} 는 심볼릭 링크다"
  assert_eq "$(readlink "plugins/quality-gates/scripts/$n")" "../../../shared/test-selection/$n" "qg 의 ${n} 는 공유본으로 가는 상대 링크다"
  assert_eq "$(git ls-files -s -- "shared/test-selection/$n" | awk '{print $1}')" "100755" "공유본 ${n} 는 실행 비트를 지킨다"
done
B="$HOME/.claude/sdd-mirror/r2a-plan1/blobs-before.tsv"
if [ -f "$B" ]; then
  while IFS="$(printf '\t')" read -r n h; do
    assert_eq "$(git hash-object "shared/test-selection/$n")" "$h" "공유본 ${n} 는 이동 전 blob 과 바이트가 같다"
  done < "$B"
else
  ok "이동 전 blob 기록이 이 기계에 없다 — 바이트 대조는 Step 1 을 돈 기계에서만"
fi
assert_contains "$(cat shared/test-selection/README.md)" "넷을 전부" "소비자 규칙: 묶음 전체를 링크한다"
# 세 경로가 같은 결과를 낸다: qg 링크 · 다른 플러그인 폴더의 링크 · 링크를 푼 사본(설치본 모양)
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/other/scripts" "$T/deref/scripts"
for n in $NAMES; do ln -s "$ROOT/shared/test-selection/$n" "$T/other/scripts/$n"; cp -L "$ROOT/plugins/quality-gates/scripts/$n" "$T/deref/scripts/$n"; done
g1="$(bash plugins/quality-gates/scripts/run-test-selection.sh granularity shell 2>&1)"
g2="$(bash "$T/other/scripts/run-test-selection.sh" granularity shell 2>&1)"
g3="$(bash "$T/deref/scripts/run-test-selection.sh" granularity shell 2>&1)"
assert_eq "$g2|$g3" "$g1|$g1" "run-test-selection.sh: 세 경로가 같은 결과"
r1="$(cd "$ROOT" && { bash plugins/quality-gates/scripts/compute-test-scope-candidates.sh 2>/dev/null; echo "rc=$?"; })"
r2="$(cd "$ROOT" && { bash "$T/other/scripts/compute-test-scope-candidates.sh" 2>/dev/null; echo "rc=$?"; })"
r3="$(cd "$ROOT" && { bash "$T/deref/scripts/compute-test-scope-candidates.sh" 2>/dev/null; echo "rc=$?"; })"
assert_eq "$r2|$r3" "$r1|$r1" "compute-test-scope-candidates.sh: 세 경로가 같은 결과(형제 resolve-baseline.sh 를 자기 폴더에서 찾는다)"
d1="$(python3 plugins/quality-gates/scripts/diff-test-results.py --help 2>&1 | head -3)"
d3="$(python3 "$T/deref/scripts/diff-test-results.py" --help 2>&1 | head -3)"
assert_eq "$d3" "$d1" "diff-test-results.py: 링크를 푼 사본도 같은 결과"
finish
