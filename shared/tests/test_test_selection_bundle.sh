#!/usr/bin/env bash
# guards: shared/test-selection/* plugins/quality-gates/scripts/run-test-selection.sh plugins/quality-gates/scripts/diff-test-results.py plugins/quality-gates/scripts/compute-test-scope-candidates.sh plugins/quality-gates/scripts/resolve-baseline.sh
# AC3 · AC4 — 테스트 실행 넷이 공유본에 바이트 그대로 있고, qg 는 상대 링크를 두며, 링크 · 다른 플러그인 링크 · 링크를 푼 사본이 같은 결과를 낸다.
set -u
# test_guards_coverage_bidirectional.sh 가 읽는다 — 이 락이 여는 파일(리포 상대)을 낸다.
if [ "${1:-}" = "--emit-scanned" ]; then
  cd "$(dirname "$0")/../.." || exit 1
  ls shared/test-selection/*
  for n in run-test-selection.sh diff-test-results.py compute-test-scope-candidates.sh resolve-baseline.sh; do
    printf 'plugins/quality-gates/scripts/%s\n' "$n"
  done
  exit 0
fi
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
cd "$ROOT" || exit 1
assert_ne() {  # assert_ne <a> <b> <msg> — 음성 대조: 두 값이 달라야 한다
  if [ "$1" != "$2" ]; then ok "$3"; else no "$3"; printf '      같은 값: %s\n' "$1"; fi
}
NAMES="run-test-selection.sh diff-test-results.py compute-test-scope-candidates.sh resolve-baseline.sh"
for n in $NAMES; do
  mode="$(git ls-files -s -- "plugins/quality-gates/scripts/$n" | awk '{print $1}')"
  assert_eq "$mode" "120000" "qg 의 ${n} 는 심볼릭 링크다"
  assert_eq "$(readlink "plugins/quality-gates/scripts/$n")" "../../../shared/test-selection/$n" "qg 의 ${n} 는 공유본으로 가는 상대 링크다"
  assert_eq "$(git ls-files -s -- "shared/test-selection/$n" | awk '{print $1}')" "100755" "공유본 ${n} 는 실행 비트를 지킨다"
done
# 이동이 바이트를 바꾸지 않았는지는 공유본을 처음 더한 커밋에서 잰다 — 그 뒤의 의도한 편집은 이 대조 밖이다.
# 이동 전 blob 은 그 커밋의 부모에 있던 qg 스크립트다. 커밋이나 부모를 못 찾으면(얕은 클론 등) 통과가 아니라 실패다.
for n in $NAMES; do
  add_c="$(git log --diff-filter=A --format=%H -- "shared/test-selection/$n" | tail -1)"
  after="$(git rev-parse "${add_c:-none}:shared/test-selection/$n" 2>/dev/null)"
  before="$(git rev-parse "${add_c:-none}^:plugins/quality-gates/scripts/$n" 2>/dev/null)"
  if [ -z "$after" ] || [ -z "$before" ]; then
    no "공유본 ${n} 의 이동 전후 blob 을 git 에서 풀지 못했다(공유본을 더한 커밋 또는 그 부모가 없다 — 얕은 클론이면 전체 이력을 받아라)"
  else
    assert_eq "$after" "$before" "공유본 ${n} 는 처음 더한 커밋에서 이동 전 qg 스크립트와 바이트가 같다"
  fi
done
assert_contains "$(cat shared/test-selection/README.md)" "넷을 전부" "소비자 규칙: 묶음 전체를 링크한다"
# 세 경로가 같은 결과를 낸다: qg 링크 · 다른 플러그인 폴더의 링크 · 링크를 푼 사본(설치본 모양)
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/other/scripts" "$T/deref/scripts"
for n in $NAMES; do ln -s "$ROOT/shared/test-selection/$n" "$T/other/scripts/$n"; cp -L "$ROOT/plugins/quality-gates/scripts/$n" "$T/deref/scripts/$n"; done
g1="$(bash plugins/quality-gates/scripts/run-test-selection.sh granularity shell 2>&1)"
g2="$(bash "$T/other/scripts/run-test-selection.sh" granularity shell 2>&1)"
g3="$(bash "$T/deref/scripts/run-test-selection.sh" granularity shell 2>&1)"
assert_eq "$g2|$g3" "$g1|$g1" "run-test-selection.sh: 세 경로가 같은 결과"
# stderr 도 함께 잡는다 — 기준선이 없는 기계에서 셋이 모두 rc=4 로 같아지더라도 사유 문장이 다르면 갈린다.
# 형제 없는 사본(음성 대조)은 설치본에서 한 개만 링크했을 때의 모양이고 r1 과 달라야 한다.
mkdir -p "$T/lone/scripts"
cp -L "$ROOT/plugins/quality-gates/scripts/compute-test-scope-candidates.sh" "$T/lone/scripts/"
cp -L "$ROOT/plugins/quality-gates/scripts/diff-test-results.py" "$T/lone/scripts/"
r1="$(cd "$ROOT" && { bash plugins/quality-gates/scripts/compute-test-scope-candidates.sh 2>&1; echo "rc=$?"; })"
r2="$(cd "$ROOT" && { bash "$T/other/scripts/compute-test-scope-candidates.sh" 2>&1; echo "rc=$?"; })"
r3="$(cd "$ROOT" && { bash "$T/deref/scripts/compute-test-scope-candidates.sh" 2>&1; echo "rc=$?"; })"
r4="$(cd "$ROOT" && { bash "$T/lone/scripts/compute-test-scope-candidates.sh" 2>&1; echo "rc=$?"; })"
assert_eq "$r2|$r3" "$r1|$r1" "compute-test-scope-candidates.sh: 세 경로가 같은 결과(형제 resolve-baseline.sh 를 자기 폴더에서 찾는다)"
assert_ne "$r4" "$r1" "compute-test-scope-candidates.sh: 형제 resolve-baseline.sh 가 없는 사본은 다른 결과다(음성 대조)"
# diff-test-results.py 는 granularity_of 가 자기 폴더의 run-test-selection.sh 를 부르는 경로로 잰다(--help 는 거기 닿기 전에 끝난다).
PROBE='import importlib.util, sys
spec = importlib.util.spec_from_file_location("dtr", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
try:
    print(m.granularity_of("shell"))
except SystemExit as e:
    print("exit=%s" % (e.code,))'
d1="$(python3 -I -c "$PROBE" "$ROOT/plugins/quality-gates/scripts/diff-test-results.py" 2>&1)"
d2="$(python3 -I -c "$PROBE" "$T/other/scripts/diff-test-results.py" 2>&1)"
d3="$(python3 -I -c "$PROBE" "$T/deref/scripts/diff-test-results.py" 2>&1)"
d4="$(python3 -I -c "$PROBE" "$T/lone/scripts/diff-test-results.py" 2>&1)"
assert_eq "$d1" "file" "diff-test-results.py: qg 링크 경로가 입도를 얻는다"
assert_eq "$d2|$d3" "$d1|$d1" "diff-test-results.py: 다른 플러그인 링크 · 링크를 푼 사본도 같은 입도를 얻는다"
assert_ne "$d4" "$d1" "diff-test-results.py: 형제 run-test-selection.sh 가 없는 사본은 입도를 얻지 못한다(음성 대조)"
finish
