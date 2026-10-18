#!/usr/bin/env bash
# R5 AC18 — merge_check.py: 합친 사본 · 잠금 · 단위 짝짓기 · 이름 대조 · 테스트 명령 · 강등.
# 버릴 레포(기본 브랜치 trunk)마다 원격(bare) · 로드맵 frontmatter · 에픽 브랜치를 만든다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_merge_check.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
MC="$ROOT/plugins/spec-distill/scripts/merge_check.py"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 PYTHONDONTWRITEBYTECODE=1
RM="plan/rm/roadmap.md"

for n in run-test-selection.sh diff-test-results.py compute-test-scope-candidates.sh resolve-baseline.sh; do
  assert_eq "$(git -C "$ROOT" ls-files -s -- "plugins/spec-distill/scripts/$n" | awk '{print $1}')" "120000" "${n} 는 링크다"
  assert_eq "$(readlink "$ROOT/plugins/spec-distill/scripts/$n")" "../../../shared/test-selection/$n" "${n} 는 공유본으로 가는 상대 링크다"
done

g() { git -C "$W" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"; }
mkrepo() {  # mkrepo <이름> [frontmatter 추가 줄] — 원격 trunk · 로드맵 · 첫 커밋. W 를 그 클론으로.
  local o="$T/$1.git"
  git init -q --bare -b trunk "$o"
  W="$T/$1"; git clone -q "$o" "$W" 2>/dev/null
  g checkout -q -b trunk 2>/dev/null || true
  mkdir -p "$W/plan/rm"
  printf -- '---\ntype: roadmap\n%b---\n\n# r\n' "${2:-}" > "$W/$RM"
}
put() { mkdir -p "$(dirname "$W/$1")"; printf '%s\n' "$2" > "$W/$1"; }
push_base() { g add -A && g commit -qm base && g push -q origin trunk && g remote set-head origin --auto >/dev/null; }
branch_with() {  # branch_with <브랜치> — 지금 작업 트리 변경을 그 브랜치에 커밋하고 trunk 로 돌아온다
  g checkout -q -b "$1" && g add -A && g commit -qm "$1" && g checkout -q trunk
}
mc() { (cd "$W" && python3 "$MC" run --roadmap "$RM" --no-fetch "$@" 2>&1); }

# 1 — pytest: 양쪽 다 빨간 파일 안의 새 실패를 이름으로 가른다
if python3 -m pytest --version >/dev/null 2>&1; then
  mkrepo py; put pytest.ini '[pytest]'
  put tests/test_x.py $'def test_a():\n    assert 1 == 2\n\ndef test_b():\n    assert True'
  push_base
  put tests/test_x.py $'def test_a():\n    assert 1 == 2\n\ndef test_b():\n    assert True\n\ndef test_c():\n    assert 0'
  branch_with feature/py
  out="$(mc --branch feature/py)"; rc=$?
  assert_eq "$rc" "1" "pytest: 양쪽 빨간 파일 안의 새 실패 → rc 1"
  assert_contains "$out" "tests/test_x.py::test_c" "pytest: 새 실패 이름"
  assert_contains "$out" "양쪽 다 있는 실패 1개: tests/test_x.py: tests/test_x.py::test_a" "pytest: 원래 있던 실패는 양쪽 다 있는 실패다"
  assert_eq "$(git -C "$W" worktree list | wc -l | tr -d ' ')" "1" "pytest: 일회용 사본을 지웠다"
else
  no "pytest 가 없어 1번 장면을 돌리지 못했다 — 이 기계에 pytest 를 깔고 다시 돈다"
fi

# 1b — pytest: 양쪽 빨간 파일 안에서 fixture 가 터지는 새 테스트(ERROR 줄)도 새 실패다
if python3 -m pytest --version >/dev/null 2>&1; then
  mkrepo pe; put pytest.ini '[pytest]'
  put tests/test_x.py $'def test_a():\n    assert 1 == 2'
  push_base
  put tests/test_x.py $'import pytest\n\n@pytest.fixture\ndef boom():\n    raise RuntimeError("setup broke")\n\ndef test_a():\n    assert 1 == 2\n\ndef test_c(boom):\n    pass'
  branch_with feature/pe
  out="$(mc --branch feature/pe)"; rc=$?
  assert_eq "$rc" "1" "pytest: fixture 오류로 터지는 새 테스트 → rc 1"
  assert_contains "$out" "tests/test_x.py::test_c" "pytest: ERROR 줄의 새 이름"
else
  no "pytest 가 없어 1b 장면을 돌리지 못했다 — 이 기계에 pytest 를 깔고 다시 돈다"
fi

# 2 — unittest: 초록이던 테스트가 빨개진다(단위 수준 새 실패) · 이름도 낸다
mkrepo ut; put tests/__init__.py ''
put tests/test_y.py $'import unittest\nclass T(unittest.TestCase):\n    def test_a(self):\n        self.assertEqual(1, 1)'
push_base
put tests/test_y.py $'import unittest\nclass T(unittest.TestCase):\n    def test_a(self):\n        self.assertEqual(1, 2)'
branch_with feature/ut
out="$(mc --branch feature/ut)"; rc=$?
assert_eq "$rc" "1" "unittest: 새 실패 → rc 1"
assert_contains "$out" "test_a" "unittest: 새 실패 이름"

# 3 — 실행 비트 셸: 양쪽 빨강 · ✗ 줄로 이름 대조
mkrepo sh
put tests/t.sh $'#!/usr/bin/env bash\necho "  ✗ 하나"\nexit 1'; chmod +x "$W/tests/t.sh"
push_base
put tests/t.sh $'#!/usr/bin/env bash\necho "  ✗ 하나"\necho "  ✗ 둘"\nexit 1'; chmod +x "$W/tests/t.sh"
branch_with feature/sh
out="$(mc --branch feature/sh)"; rc=$?
assert_eq "$rc" "1" "셸: 양쪽 빨간 단위 안의 새 실패 → rc 1"
assert_contains "$out" "둘" "셸: 새 실패 이름(✗ 줄)"

# 4 — test_command(node --test tap) · 고쳐짐도 보인다
mkrepo nd 'test_command: node --test --test-reporter=tap tests/a.test.js\n'
put tests/a.test.js $'const t = require("node:test"); const a = require("node:assert");\nt("one", () => a.equal(1, 2));\nt("two", () => a.equal(1, 1));'
push_base
put tests/a.test.js $'const t = require("node:test"); const a = require("node:assert");\nt("one", () => a.equal(1, 1));\nt("two", () => a.equal(1, 2));'
branch_with feature/nd
out="$(mc --branch feature/nd)"; rc=$?
assert_eq "$rc" "1" "test_command: 새 실패 → rc 1"
assert_contains "$out" "two" "test_command: 새 실패 이름(tap not ok)"
assert_contains "$out" "기본 브랜치에만 있는 실패(고쳐짐) 1개: one" "test_command: 기본 브랜치에만 있는 실패(고쳐짐)를 이름으로 보인다"

# 5 — 이름을 못 뽑는 명령: 양쪽 다 빨강이면 빈 집합끼리 같다고 하지 않는다
mkrepo nn 'test_command: bash -c "exit 1"\n'; put a.txt a; push_base; put b.txt b; branch_with feature/nn
out="$(mc --branch feature/nn)"; rc=$?
assert_eq "$rc" "4" "이름 없는 명령 · 양쪽 빨강 → rc 4"
assert_contains "$out" "이름 대조 불가 — 단위 수준만" "이름 없는 명령: 단위 수준 공시"

# 6 — test_failure_pattern 이 이긴다
mkrepo pt 'test_command: bash run.sh\ntest_failure_pattern: "^BAD: (.+)$"\n'
put run.sh $'echo "BAD: alpha"\nexit 1'; push_base
put run.sh $'echo "BAD: alpha"\necho "BAD: beta"\nexit 1'; branch_with feature/pt
out="$(mc --branch feature/pt)"; rc=$?
assert_eq "$rc" "1" "test_failure_pattern: 새 이름 → rc 1"
assert_contains "$out" "beta" "test_failure_pattern: 새 이름 beta"

# 7 — 테스트 없음 → 7 · 러너 없는 테스트 파일 → 6
mkrepo none; put README.md r; push_base; put x.txt x; branch_with feature/none
out="$(mc --branch feature/none)"; rc=$?
assert_eq "$rc" "7" "테스트 없음 → rc 7"
assert_contains "$out" "스위트 대조 없음" "테스트 없음 공시"
mkrepo ask; put tests/t.sh $'#!/usr/bin/env bash\nexit 0'; push_base; put x.txt x; branch_with feature/ask
out="$(mc --branch feature/ask)"; rc=$?
assert_eq "$rc" "6" "실행 비트 없는 셸 테스트만 → rc 6(묻는 자리)"
assert_contains "$out" "test_command" "묻는 자리: 로드맵 frontmatter 키를 말한다"

# 7b — 테스트 파일 수를 못 세면 「스위트 대조 없음」 이 아니라 검사 불가(rc 3)
mkrepo cn; put README.md r; push_base; put x.txt x; branch_with feature/cn
out="$(cd "$W" && python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import merge_check as m
m.test_file_count = lambda tree: None
sys.exit(m.main(["run", "--roadmap", sys.argv[2], "--no-fetch", "--branch", "feature/cn"]))' "$ROOT/plugins/spec-distill/scripts" "$RM" 2>&1)"; rc=$?
assert_eq "$rc" "3" "파일 수를 못 셈 → rc 3(0 으로 접지 않는다)"
assert_contains "$out" "테스트 파일 수를 세지 못했다" "파일 수 못 셈 사유"

# 7c — 예상 못 한 예외는 rc 3 + 내부 오류 줄(파이썬 기본 rc 1 은 「새 실패 있음」)
out="$(cd "$W" && python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import merge_check as m
def boom(*a, **k): raise ValueError("x")
m.compare_detected = boom
sys.exit(m.main(["run", "--roadmap", sys.argv[2], "--no-fetch", "--branch", "feature/cn"]))' "$ROOT/plugins/spec-distill/scripts" "$RM" 2>&1)"; rc=$?
assert_eq "$rc" "3" "내부 오류 → rc 3"
assert_contains "$out" "내부 오류: ValueError: x" "내부 오류 줄"

# 8 — 잠금: 살아 있는 주인이면 5, 죽은 주인이면 풀고 간다
LOCKD="$(cd "$T/ut" && python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import conductor_state as cs, repo_defaults as r, state_path as s; print(cs.machine_dir(s.state_root(), sys.argv[2]) / r.MERGE_CHECK_DIR / "lock")' "$ROOT/plugins/spec-distill/scripts" "$RM")"
mkdir -p "$LOCKD"; printf '%s x\n' "$$" > "$LOCKD/owner"
W="$T/ut"; out="$(mc --branch feature/ut)"; rc=$?
assert_eq "$rc" "5" "살아 있는 잠금 → rc 5"
printf '999999 x\n' > "$LOCKD/owner"
out="$(mc --branch feature/ut)"; rc=$?
assert_contains "$out" "주인 없는 잠금을 풀었다" "죽은 주인의 잠금은 알리고 푼다"
assert_eq "$rc" "1" "잠금을 푼 뒤 대조가 돈다"
[ -d "$LOCKD" ] && no "대조가 끝난 뒤 잠금이 남았다" || ok "대조가 끝나면 잠금을 푼다"

# 9 — 합칠 수 없음 · 기본 브랜치 모름 · 사본 남기기
mkrepo cf; put a.txt one; push_base
g checkout -q -b feature/cf; put a.txt two; g add -A; g commit -qm cf; g checkout -q trunk
put a.txt three; g add -A; g commit -qm main3; g push -q origin trunk
out="$(mc --branch feature/cf)"; rc=$?
assert_eq "$rc" "3" "충돌 → rc 3"
assert_contains "$out" "합칠 수 없다 — 충돌 파일: a.txt" "충돌 파일을 보인다"
W="$T/ut"; out="$(mc --branch feature/ut --keep-merged)"; rc=$?
kept="$(printf '%s\n' "$out" | sed -n 's/^남긴 사본: //p')"
[ -n "$kept" ] && [ -d "$kept" ] && ok "사본 남기기: 경로가 있다" || no "사본 남기기: 남긴 사본이 없다"
assert_eq "$(git -C "$W" worktree list | wc -l | tr -d ' ')" "2" "사본 남기기: 합친 사본 하나만 남는다"
g remote set-head origin -d
out="$(mc --branch feature/ut)"; rc=$?
assert_eq "$rc" "3" "origin/HEAD 없음 → rc 3"
assert_contains "$out" "origin/HEAD 가 없다" "기본 브랜치 모름 사유"

# 10 — names_in: 알려진 모양 · 모양 없음
NAMES="$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import merge_check as m
for t in ("FAILED a.py::t1 - x", "FAIL: t2 (m.C)", "not ok 3 - t3", "  ✗ t4", "ERROR x.py::t5 - e", "nothing here"):
    print(sorted(m.names_in(t, None)[0]), m.names_in(t, None)[1])' "$ROOT/plugins/spec-distill/scripts")"
assert_eq "$NAMES" "$(printf "%s\n" "['a.py::t1'] pytest" "['t2 (m.C)'] unittest" "['t3'] tap" "['t4'] ✗ 표시" "['x.py::t5'] pytest" "[] None")" "names_in: 알려진 모양 넷과 모양 없음"

finish
