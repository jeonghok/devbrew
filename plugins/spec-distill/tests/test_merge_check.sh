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
CT=""   # 장면 18 이 /tmp 아래에 만드는 호출한 쪽 임시 폴더 — trap 이 함께 지운다
NG=""   # 장면 19 가 /tmp 아래에 만드는 후보 폴더 — trap 이 함께 지운다
trap 'chmod -R u+w "$T" 2>/dev/null; rm -rf "$T"; [ -n "$CT" ] && rm -rf "$CT"; [ -n "$NG" ] && rm -rf "$NG"' EXIT
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
headline() {  # headline <출력> <브랜치> <꼬리 정규식> — 세 칸(브랜치 · 기본 브랜치 · 합친 사본 커밋)이 그대로이고 꼬리가 그것인 머리 줄 수
  printf '%s\n' "$1" | grep -cE "^\[spec-distill\] 스위트 대조 — $2\([0-9a-f]{8}\) 를 기본 브랜치 trunk\([0-9a-f]{8}\) 에 합친 사본\([0-9a-f]{8}\)$3\$"
}

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
assert_eq "$(headline "$out" feature/ut "과 기본 브랜치 사본을 돌렸다")" "1" "탐지 경로: 머리 줄 꼬리는 두 사본을 돌렸다 그대로다"

# 3 — 실행 비트 셸: 양쪽 빨강 · ✗ 줄로 이름 대조
mkrepo sh
put tests/t.sh $'#!/usr/bin/env bash\necho "  ✗ 하나"\nexit 1'; chmod +x "$W/tests/t.sh"
push_base
put tests/t.sh $'#!/usr/bin/env bash\necho "  ✗ 하나"\necho "  ✗ 둘"\nexit 1'; chmod +x "$W/tests/t.sh"
branch_with feature/sh
out="$(mc --branch feature/sh)"; rc=$?
assert_eq "$rc" "1" "셸: 양쪽 빨간 단위 안의 새 실패 → rc 1"
assert_contains "$out" "둘" "셸: 새 실패 이름(✗ 줄)"
assert_eq "$(cat "$W/.claude/spec-distill/.gitignore" 2>/dev/null)" "*" "상태 루트: 스위트 대조가 상태 루트를 보장한다(.gitignore)"
assert_eq "$(git -C "$W" status --porcelain)" "" "상태 루트: 스위트 대조 뒤 git status 가 비었다"
mkrepo trk; put README.md r; push_base; put x.txt x; branch_with feature/trk
mkdir -p "$W/.claude/spec-distill"; echo t > "$W/.claude/spec-distill/kept.md"; g add -f .claude/spec-distill/kept.md
out="$(mc --branch feature/trk)"; rc=$?
assert_eq "$rc" "3" "상태 루트: 추적 파일 레포에서 스위트 대조가 rc 3"
assert_contains "$out" "상태 폴더 아래 파일이 이미 추적된다" "상태 루트: 고치는 법을 보인다"
[ ! -e "$W/.claude/spec-distill/conductor" ] && ok "상태 루트: 잠금 · 사본 폴더를 만들지 않았다" || no "상태 루트: 추적 파일 레포에 기계 상태 폴더가 생겼다"
assert_not_contains "$out" "환경 변수" "상태 루트(양의 짝): 변수 없이 멈추면 환경 변수 알림이 없다"
out="$(cd "$W" && GIT_DIR="$W/.git" python3 "$MC" run --roadmap "$RM" --no-fetch --branch feature/trk 2>&1)"; rc=$?
assert_eq "$rc" "3" "상태 루트: GIT_DIR 을 물려받아도 추적 파일 레포에서 rc 3"
assert_contains "$out" "상태 폴더 아래 파일이 이미 추적된다" "상태 루트: GIT_DIR 을 물려받아도 같은 사유로 멈춘다"
assert_contains "$out" "환경 변수 GIT_DIR 가 설정된 채로 돈다" "상태 루트: 멈출 때도 GIT_DIR 알림을 보인다"

# 3b — 셸 단위의 `ERROR:` 진단 줄이 이름 집합을 가로채지 않는다(러너별 모양 — Ruling R32)
mkrepo se
put tests/t.sh $'#!/usr/bin/env bash\necho "ERROR: could not reach cache"\necho "  ✗ a"\nexit 1'; chmod +x "$W/tests/t.sh"
push_base
put tests/t.sh $'#!/usr/bin/env bash\necho "ERROR: could not reach cache"\necho "  ✗ a"\necho "  ✗ b"\nexit 1'; chmod +x "$W/tests/t.sh"
branch_with feature/se
out="$(mc --branch feature/se)"; rc=$?
assert_eq "$rc" "1" "셸: ERROR: 진단 줄이 있어도 양쪽 빨간 단위 안의 새 ✗ 실패 → rc 1"
assert_contains "$out" "tests/t.sh: b" "셸: 새 실패 이름 b"
assert_not_contains "$out" "could not reach cache" "셸: ERROR: 진단 줄은 실패 이름이 아니다"

# 4 — test_command(node --test tap) · 고쳐짐도 보인다
mkrepo nd 'test_command: node --test --test-reporter=tap tests/a.test.js\n'
put tests/a.test.js $'const t = require("node:test"); const a = require("node:assert");\nt("one", () => a.equal(1, 2));\nt("two", () => a.equal(1, 1));'
push_base
put tests/a.test.js $'const t = require("node:test"); const a = require("node:assert");\nt("one", () => a.equal(1, 1));\nt("two", () => a.equal(1, 2));'
branch_with feature/nd
out="$(mc --branch feature/nd)"; rc=$?
assert_eq "$rc" "1" "test_command: 새 실패 → rc 1"
assert_contains "$out" "two" "test_command: 새 실패 이름(tap not ok)"
assert_contains "$out" "기본 브랜치에만 있는 실패(고쳐짐) — 재지 않았다" "test_command: 목록을 건넨 대조는 고쳐짐을 재지 않았다고 말한다"

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
assert_contains "$out" "무엇을 돌렸나: test_command(\`bash run.sh\`) — 출처 로드맵" "로드맵 값이면 출처가 로드맵이다"
assert_not_contains "$out" "레포 설정 파일(.devbrew.md)에 올린다" "로드맵 값이면 올리자는 줄이 없다"

# 6a — test_command · 정규식 없음: 이미 있던 pytest 실패 옆의 새 ✗ 실패도 센다(알려진 꼴을 전부 센다 — 첫 꼴만이 아니다)
mkrepo mx 'test_command: bash run.sh\n'
put run.sh $'echo "FAILED a.py::old - x"\nexit 1'; push_base
put run.sh $'echo "FAILED a.py::old - x"\necho "  ✗ 새 셸 실패"\nexit 1'; branch_with feature/mx
out="$(mc --branch feature/mx)"; rc=$?
assert_eq "$rc" "1" "섞인 꼴: 이미 있던 pytest 실패 옆의 새 ✗ 실패 → rc 1"
assert_contains "$out" "이 브랜치에만 있는 실패 1개: 새 셸 실패" "섞인 꼴: 새 이름은 ✗ 줄의 것"
assert_contains "$out" "양쪽 다 있는 실패 1개: a.py::old" "섞인 꼴: 이미 있던 pytest 실패는 양쪽 다 있는 실패다"
assert_not_contains "$out" "예전 판이 적은 테스트 명령 줄" "기계 상태에 옛 레포 설정 줄이 없으면 알리지 않는다"

# 6b — AC4: 기계 상태 `## 레포 설정` 에 적은 값은 읽지 않는다 — 검사받는 하위 agent 도 쓸 수 있는 파일이다.
#       늘 통과하는 명령을 적어 두어도 탐지한 러너가 돌아 새 실패를 잡는다(이 장면은 그 명령이 이기면 rc 0 이 된다).
machine() {  # machine <글> — 이 레포 로드맵의 기계 상태 파일을 그 글로 쓴다
  (cd "$W" && python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import conductor_state as cs, state_path as s
p = cs.machine_path(s.state_root(), sys.argv[2]); p.parent.mkdir(parents=True, exist_ok=True)
p.write_text(sys.argv[3], encoding="utf-8")' "$ROOT/plugins/spec-distill/scripts" "$RM" "$1")
}
mkrepo mt; put tests/__init__.py ''
put tests/test_y.py $'import unittest\nclass T(unittest.TestCase):\n    def test_a(self):\n        self.assertEqual(1, 1)'
push_base
put tests/test_y.py $'import unittest\nclass T(unittest.TestCase):\n    def test_a(self):\n        self.assertEqual(1, 2)'
branch_with feature/mt
machine "$(printf -- '---\ntype: conductor-machine\nroadmap: %s\n---\n\n## 레포 설정\n\n- test_command · bash -c "exit 0"\n- test_failure_pattern · ^NOPE: (.+)$\n' "$RM")"
out="$(mc --branch feature/mt)"; rc=$?
assert_eq "$rc" "1" "기계 상태의 test_command(늘 통과)를 돌리지 않는다 — 탐지한 러너가 새 실패를 잡는다 → rc 1"
assert_contains "$out" "무엇을 돌렸나: 탐지한 러너" "기계 상태 값이 아니라 탐지 경로가 돈다"
assert_not_contains "$out" "exit 0" "기계 상태의 명령 글이 출력 어디에도 없다"
assert_not_contains "$out" "기계 상태(임시)" "기계 상태 출처 표기가 없다"
assert_contains "$out" "예전 판이 적은 테스트 명령 줄" "옛 레포 설정 줄을 조용히 버리지 않고 읽지 않는다고 알린다"
assert_contains "$out" "사용자에게 다시 물어 --test-command 로 넘기거나" "옛 줄 알림: 답은 다시 물어 인자로 넘긴다"
assert_contains "$out" "(\`## 레포 설정\`)이 남아 있다" "옛 줄 알림: 스위트 대조는 쓰지 않으므로 줄이 남아 있다고 말한다"
assert_not_contains "$out" "을 지웠다" "옛 줄 알림: 스위트 대조는 지웠다고 말하지 않는다"
machine "$(printf -- '---\ntype: conductor-machine\nroadmap: %s\n---\n\n## 레포 설정\n\n- 깨진 줄\n' "$RM")"
out="$(mc --branch feature/mt)"; rc=$?
assert_eq "$rc" "1" "기계 상태의 레포 설정 절이 깨져 있어도 읽지 않으므로 대조가 돈다 → rc 1"
mkrepo bp 'test_command: bash run.sh\ntest_failure_pattern: "["\n'
put run.sh $'echo "not ok 1 - alpha"\nexit 1'; push_base; put b.txt b; branch_with feature/bp
out="$(mc --branch feature/bp)"; rc=$?
assert_eq "$rc" "3" "컴파일되지 않는 test_failure_pattern → rc 3"
assert_contains "$out" "test_failure_pattern 정규식이 깨졌다 — 출처 로드맵: " "깨진 정규식 사유 문구와 출처(run 이 pattern_error 를 부른다 — 내부 오류 rc 3 과 가른다)"
mkrepo rp 'test_command: bash run.sh\n'
put .devbrew.md $'---\ntest_failure_pattern: "^BAD: (.+)$"\n---'
put run.sh $'echo "BAD: alpha"\nexit 1'; push_base
put run.sh $'echo "BAD: alpha"\necho "BAD: beta"\nexit 1'; branch_with feature/rp
out="$(mc --branch feature/rp)"; rc=$?
at="$(g rev-parse origin/HEAD | cut -c1-8)"
assert_eq "$rc" "1" "로드맵에 없고 레포 설정 파일에 있는 정규식으로 새 이름을 가른다 → rc 1"
assert_contains "$out" "beta" "레포 설정 파일의 정규식: 새 이름 beta"
assert_contains "$out" "실패 이름 정규식: test_failure_pattern(\`^BAD: (.+)$\`) — 출처 레포 설정@${at}" "정규식 출처가 레포 설정@<기본 브랜치 커밋 8자>다"

# 7 — 테스트 없음 → 7 · 러너 없는 테스트 파일 → 6
mkrepo none; put README.md r; push_base; put x.txt x; branch_with feature/none
out="$(mc --branch feature/none)"; rc=$?
assert_eq "$rc" "7" "테스트 없음 → rc 7"
assert_contains "$out" "스위트 대조 없음" "테스트 없음 공시"
mkrepo ask; put tests/t.sh $'#!/usr/bin/env bash\nexit 0'; push_base; put x.txt x; branch_with feature/ask
out="$(mc --branch feature/ask)"; rc=$?
assert_eq "$rc" "6" "실행 비트 없는 셸 테스트만 → rc 6(묻는 자리)"
assert_contains "$out" "test_command" "묻는 자리: 로드맵 frontmatter 키를 말한다"
assert_contains "$out" "레포 설정 파일(.devbrew.md)에 올린다" "묻는 자리: 정한 값은 레포 설정 파일에 올린다"

# 7a — 종료 코드 6 의 답: 지휘자가 사용자 답을 이 호출의 인자로만 넘긴다(기계 상태에 적지 않는다)
mkrepo an; put tests/t.sh $'echo "not ok 1 - alpha"\nexit 1'; push_base
put tests/t.sh $'echo "not ok 1 - alpha"\necho "not ok 2 - gamma"\nexit 1'; branch_with feature/an
out="$(mc --branch feature/an)"; rc=$?
assert_eq "$rc" "6" "인자 없음: 러너 없는 테스트 파일 → rc 6(전제)"
out="$(mc --branch feature/an --test-command "bash tests/t.sh")"; rc=$?
assert_eq "$rc" "1" "--test-command: 사용자 답의 명령을 돌려 새 실패 → rc 1"
assert_contains "$out" "gamma" "--test-command: 새 이름 gamma"
assert_contains "$out" "무엇을 돌렸나: test_command(\`bash tests/t.sh\`) — 출처 이 호출의 인자(사용자 답)" "--test-command: 무엇을 돌렸나에 출처가 이 호출의 인자다"
assert_contains "$out" "test_command 를 이 호출의 인자(사용자 답)에서 읽었다 — 이 값을 레포 설정 파일(.devbrew.md)에 올린다" "--test-command: 레포 설정 파일에 올리자고 알린다"
out="$(mc --branch feature/an)"; rc=$?
assert_eq "$rc" "6" "--test-command 는 그 호출에만 쓴다 — 인자 없이 다시 돌면 rc 6"
out="$(mc --branch feature/an --test-command "bash tests/t.sh" --test-failure-pattern '^not ok [0-9]+ - ([a-z]+)$')"; rc=$?
assert_eq "$rc" "1" "--test-failure-pattern: 정규식으로 가른 새 이름 → rc 1"
assert_contains "$out" "실패 이름 정규식: test_failure_pattern(\`^not ok [0-9]+ - ([a-z]+)\$\`) — 출처 이 호출의 인자(사용자 답)" "--test-failure-pattern: 출처가 이 호출의 인자다"
out="$(mc --branch feature/an --test-failure-pattern '^x$')"; rc=$?
assert_eq "$rc" "3" "--test-failure-pattern 만(돌릴 명령 없음) → rc 3"
assert_contains "$out" "테스트 명령과 함께만" "정규식만 준 사유"
assert_not_contains "$out" "레포 설정 파일(.devbrew.md)에 올린다" "정규식만: 쓰지 못할 값을 올리자고 먼저 알리지 않는다"
out="$(mc --branch feature/an --test-command "bash tests/t.sh" --test-failure-pattern '[')"; rc=$?
assert_not_contains "$out" "레포 설정 파일(.devbrew.md)에 올린다" "깨진 정규식: 거부하기 전에 올리자고 알리지 않는다"
out="$(mc --branch feature/an --test-command "bash tests/t.sh" --test-failure-pattern '')"; rc=$?
assert_eq "$rc" "3" "빈 --test-failure-pattern → rc 3"
assert_not_contains "$out" "레포 설정 파일(.devbrew.md)에 올린다" "빈 정규식: 명령 값도 올리자고 먼저 알리지 않는다"
# 7b — 두 사본의 경로 글자(끝에서 끝): 같은 실패는 갈리지 않고, 경로를 기대하는 사용자 정규식은 원래 출력에 맞춘다
mkrepo pp; put run.sh $'echo "  ✗ broken at $PWD/x"\necho "  ✗ tmp $TMPDIR/y"\necho "FAIL: test_old"\nexit 1'; push_base
put run.sh $'echo "  ✗ broken at $PWD/x"\necho "  ✗ tmp $TMPDIR/y"\necho "FAIL: test_old"\necho "FAIL: $PWD/tests/test_new"\nexit 1'; branch_with feature/pp
out="$(mc --branch feature/pp --test-command "bash run.sh" --test-failure-pattern '^  ✗ (.+)$')"; rc=$?
assert_eq "$rc" "0" "사본 · 임시 폴더 경로가 든 같은 실패는 새 실패가 아니다 → rc 0"
assert_contains "$out" "이 브랜치에만 있는 실패 0개" "경로만 다른 같은 실패를 새 실패로 세지 않는다"
out="$(mc --branch feature/pp --test-command "bash run.sh" --test-failure-pattern '^FAIL: (?:/\S+/)?(test_\w+)$')"; rc=$?
assert_eq "$rc" "1" "절대 경로를 기대하는 정규식: 원래 출력에서 이름을 뽑아 새 실패를 잡는다 → rc 1"
assert_contains "$out" "이 브랜치에만 있는 실패 1개: test_new" "경로가 붙은 새 실패의 이름"
out="$(mc --branch feature/an --test-command "")"; rc=$?
assert_eq "$rc" "3" "빈 --test-command → rc 3"
assert_contains "$out" "--test-command 값이 비었다" "빈 인자 사유"
out="$(mc --branch feature/an --test-command "bash tests/t.sh" --test-failure-pattern '[')"; rc=$?
assert_eq "$rc" "3" "깨진 --test-failure-pattern → rc 3"
assert_contains "$out" "test_failure_pattern 정규식이 깨졌다 — 출처 이 호출의 인자(사용자 답): " "깨진 인자 정규식 사유와 출처"
W="$T/pt"; out="$(mc --branch feature/pt --test-command "bash -c 'exit 0'")"; rc=$?
assert_eq "$rc" "0" "인자가 로드맵 값보다 앞선다(그 호출만)"
assert_contains "$out" "로드맵의 test_command(\`bash run.sh\`) 대신 이 호출의 인자를 쓴다" "인자가 설정 값을 대신하면 그 값과 출처를 알린다"

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

# 8 — 잠금: 하위 agent 의 전체 스위트와 같은 공유 스위트 잠금(지휘자 수리 2). 살아 있는 주인이면 5, 죽은 주인이면 풀고 간다
LOCKD="$(cd "$T/ut" && python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import conductor_state as cs, suite_lock as sl, state_path as s; print(sl.lock_path(cs.machine_dir(s.state_root(), sys.argv[2])))' "$ROOT/plugins/spec-distill/scripts" "$RM")"
LEDGER_LOCK="$(cd "$T/ut" && python3 "$ROOT/plugins/spec-distill/scripts/conductor_ledger.py" suite-lock --roadmap "$RM" | head -1)"
assert_eq "$LEDGER_LOCK" "$LOCKD" "스위트 대조와 담당자에게 싣는 경로(ledger suite-lock)가 같은 잠금이다"
case "$LOCKD" in */files/suite-lock) ok "잠금은 기계 상태 자원 폴더 아래에서 도출한다" ;; *) no "잠금 경로가 기계 상태 자원 폴더 아래가 아니다: $LOCKD" ;; esac
mkdir -p "$LOCKD"; printf '%s x\n' "$$" > "$LOCKD/owner"
W="$T/ut"; out="$(mc --branch feature/ut)"; rc=$?
assert_eq "$rc" "5" "살아 있는 잠금 → rc 5"
assert_contains "$out" "잡은 시각" "바쁜 잠금은 주인 · 잡은 시각을 보인다(잠금 대기는 줄)"
printf 'r2a-plan2-impl 2026-10-19 08:07\n' > "$LOCKD/owner"; touch -t 202610190807 "$LOCKD"
out="$(mc --branch feature/ut)"; rc=$?
assert_eq "$rc" "5" "프로세스 번호 없는 주인(사람 · 다른 도구가 쓴 잠금)은 오래돼도 훔치지 않는다 → rc 5"
assert_contains "$out" "r2a-plan2-impl" "그 주인을 보인다"
assert_eq "$(cat "$LOCKD/owner")" "r2a-plan2-impl 2026-10-19 08:07" "남의 잠금을 그대로 둔다"
printf '%s x\n' "$$" > "$LOCKD/owner"
out="$(cd "$W" && python3 "$MC" run --roadmap "$RM" --no-fetch --branch feature/ut --wait 1 2>&1)"; rc=$?
assert_eq "$rc" "5" "--wait 안에 못 잡으면 rc 5"
assert_contains "$out" "기다린다(줄)" "--wait 는 줄을 선다고 알린다"
printf '999999 x\n' > "$LOCKD/owner"
chmod 555 "$(dirname "$LOCKD")"
out="$(mc --branch feature/ut)"; rc=$?
chmod 755 "$(dirname "$LOCKD")"
assert_eq "$rc" "3" "죽은 주인의 잠금을 옮기지 못하면(부모 권한) rc 3 — 「다른 스위트가 도는 중」(5)이 아니다"
assert_contains "$out" "주인 없는 잠금을 옮기지 못했다" "옮기지 못한 사유를 보인다"
assert_not_contains "$out" "다른 스위트가 도는 중" "기다려도 풀리지 않는 잠금을 바쁘다고 하지 않는다"
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
assert_eq "$(ls -A "$(dirname "$kept")" | tr '\n' ' ')" "merged " "사본 남기기: 실행 폴더에는 합친 사본만 남는다(임시 폴더 · 결과 파일은 지운다)"
g remote set-head origin -d
out="$(mc --branch feature/ut)"; rc=$?
assert_eq "$rc" "3" "origin/HEAD 없음 → rc 3"
assert_contains "$out" "origin/HEAD 가 없다" "기본 브랜치 모름 사유"

# 10 — names_in: 알려진 모양 · 모양 없음
NAMES="$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import merge_check as m
for t in ("FAILED a.py::t1 - x", "FAIL: t2 (m.C)", "not ok 3 - t3", "  ✗ t4", "ERROR x.py::t5 - e", "nothing here"):
    print(sorted(m.names_in(t, None)[0]), m.names_in(t, None)[1])' "$ROOT/plugins/spec-distill/scripts")"
assert_eq "$NAMES" "$(printf "%s\n" "['a.py::t1'] pytest" "['t2 (m.C)'] unittest" "['t3'] tap" "['t4'] ✗ 표시" "['x.py::t5'] pytest" "[] None")" "names_in: 알려진 모양 넷과 모양 없음"
MIXED="$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import merge_check as m
n, s = m.names_in("FAILED a.py::t1 - x\nnot ok 3 - t3\n  ✗ t4", None); print(sorted(n), s)' "$ROOT/plugins/spec-distill/scripts")"
assert_eq "$MIXED" "['a.py::t1', 't3', 't4'] pytest · tap · ✗ 표시" "names_in: 한 출력에 섞인 알려진 꼴을 전부 센다"
# 10b — 러너별 모양: 셸은 ✗ · FAIL: · tap 만, 모르는 러너는 이름을 뽑지 않는다
SHAPED="$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import merge_check as m
t = "ERROR: diag\n  ✗ a\nFAIL: b\nnot ok 1 - c\nFAILED x.py::d - e"
for r in ("shell", "pytest", "unittest", "jest"):
    print(r, sorted(m.names_in(t, shapes=m.RUNNER_SHAPES.get(r, ()))[0]))' "$ROOT/plugins/spec-distill/scripts")"
assert_eq "$SHAPED" "$(printf "%s\n" "shell ['a', 'b', 'c']" "pytest ['x.py::d']" "unittest ['b', 'diag']" "jest []")" "names_in: 러너별 모양만 쓴다"
# 10c — 두 사본의 경로 글자: 같은 실패가 사본 · 임시 폴더 경로 때문에 새 실패로 갈리지 않는다(양성 짝: 자리표시 없이는 갈린다)
NEUT="$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import merge_check as m; from pathlib import Path
w = Path("/w/run-1")
def side(s):
    return "FAILED a.py::t - x\nERROR: cannot open %s/%s/f\n  ✗ tmp %s/tmp-%s/x" % (w, s, w, s)
raw = sorted(m.names_in(side("merged"), None)[0] - m.names_in(side("base"), None)[0])
neu = sorted(m.names_in(m.neutral(side("merged"), w / "merged", w / "tmp-merged"), None)[0]
             - m.names_in(m.neutral(side("base"), w / "base", w / "tmp-base"), None)[0])
print(len(raw), neu)' "$ROOT/plugins/spec-distill/scripts")"
assert_eq "$NEUT" "2 []" "names_in: 사본 · 임시 폴더 경로를 자리표시로 바꾸면 같은 실패가 새 실패로 갈리지 않는다"

# 11 — 브랜치 끝: 로컬과 origin 이 다르면 앞선 쪽 · 갈라지면 rc 3. 낡은 로컬은 origin 이 이미 푼 충돌을 다시 낸다
mkrepo tip; put a.txt one; push_base
g checkout -q -b feature/tip; put a.txt two; g add -A; g commit -qm t1; g checkout -q trunk
put a.txt three; g add -A; g commit -qm main3; g push -q origin trunk
g checkout -q feature/tip; g merge -q trunk >/dev/null 2>&1; put a.txt merged; g add -A; g commit -qm t2
g push -q origin feature/tip; g checkout -q trunk
STALE="$(g rev-parse feature/tip~1)"; ORIG="$(g rev-parse feature/tip)"
g update-ref refs/heads/feature/tip "$STALE"
out="$(mc --branch feature/tip)"; rc=$?
assert_not_contains "$out" "합칠 수 없다" "낡은 로컬: 낡은 커밋으로 대조하지 않는다"
assert_contains "$out" "로컬 브랜치 feature/tip 가 origin 보다 뒤라 origin/feature/tip(${ORIG:0:8}) 를 썼다" "낡은 로컬: origin 끝을 쓰고 알린다"
assert_contains "$out" "스위트 대조 — feature/tip(${ORIG:0:8})" "낡은 로컬: 대조한 끝이 origin 끝이다"
assert_contains "$out" "(로컬 끝 ${STALE:0:8} · 원격 끝 ${ORIG:0:8})" "낡은 로컬: 알림 줄에 두 끝 8자가 다 보인다"
g checkout -q feature/tip; g reset -q --hard "$ORIG"; put b.txt b; g add -A; g commit -qm t3; g checkout -q trunk
AHEAD="$(g rev-parse feature/tip)"
out="$(mc --branch feature/tip)"; rc=$?
assert_contains "$out" "origin/feature/tip 가 로컬보다 뒤라(push 하지 않았거나 받아 오지 않은 커밋) 로컬 feature/tip(${AHEAD:0:8}) 를 썼다" "앞선 로컬: 로컬 끝을 쓰고 알린다"
assert_contains "$out" "스위트 대조 — feature/tip(${AHEAD:0:8})" "앞선 로컬: 대조한 끝이 로컬 끝이다"
assert_contains "$out" "(로컬 끝 ${AHEAD:0:8} · 원격 끝 ${ORIG:0:8})" "앞선 로컬: 알림 줄에 두 끝 8자가 다 보인다"
g checkout -q feature/tip; g reset -q --hard "$STALE"; put c.txt c; g add -A; g commit -qm t4; g checkout -q trunk
out="$(mc --branch feature/tip)"; rc=$?
assert_eq "$rc" "3" "갈라짐 → rc 3"
assert_contains "$out" "로컬 브랜치 feature/tip($(g rev-parse --short=8 feature/tip)) 와 origin/feature/tip(${ORIG:0:8}) 가 갈라졌다" "갈라짐: 두 끝을 보인다"
g branch -q -D feature/tip
out="$(mc --branch feature/tip)"; rc=$?
assert_contains "$out" "스위트 대조 — feature/tip(${ORIG:0:8})" "origin 만: origin 끝을 쓴다"
assert_not_contains "$out" "를 썼다" "origin 만: 알릴 것이 없다"
out="$(mc --branch origin/feature/tip)"; rc=$?
assert_contains "$out" "스위트 대조 — origin/feature/tip(${ORIG:0:8})" "origin/<브랜치> 를 직접 주면 그 끝을 쓴다"
g checkout -q -b feature/solo; put d.txt d; g add -A; g commit -qm solo; g checkout -q trunk
out="$(mc --branch feature/solo)"; rc=$?
assert_contains "$out" "스위트 대조 — feature/solo($(g rev-parse --short=8 feature/solo))" "로컬만: 로컬 끝을 쓴다"
assert_not_contains "$out" "를 썼다" "로컬만: 알릴 것이 없다"
ANC="$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import branch_tip as b
try:
    b._is_ancestor(sys.argv[2], "0" * 40, "0" * 40); print("no error")
except b.TipError as e:
    print(e)' "$ROOT/plugins/spec-distill/scripts" "$W")"
assert_contains "$ANC" "조상 관계를 잴 수 없다" "조상 관계 재기가 실패하면(rc 1 이 아닌 0 아닌 값) 「조상 아님」 으로 접지 않는다"
GA="$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import branch_tip as b
try:
    b._git(sys.argv[2], "fetch"); print("no error")
except ValueError as e:
    print(e)' "$ROOT/plugins/spec-distill/scripts" "$W")"
assert_contains "$GA" "허용하지 않는 git 명령: fetch" "branch_tip._git 은 GIT_ALLOWED 밖의 명령(fetch)을 부르지 않고 거절한다"

# 12–17 — 대조는 한 바퀴: 합친 사본을 먼저 돌고, 깨끗하면 기준 사본을 돌지 않고, 실패 이름은 목록으로 건네 기준 사본에서 다시 돈다.
# 테스트 명령은 어느 사본에서 무엇을 받고 돌았는지 MC_LOG 에 한 줄 남긴다(첫 칸 끝 /base · /merged 로 사본을 가른다).
LOGLINE='printf '"'"'%s\t%s\n'"'"' "$PWD" "${SUITE_ONLY_FAILED_FILE:-}" >> "$MC_LOG"'
logn() {  # logn <로그> <base|merged> — 그 사본의 줄 수
  [ -f "$1" ] || { echo 0; return; }
  awk -F'\t' -v s="/$2" '{ if (substr($1, length($1) - length(s) + 1) == s) c++ } END { print c + 0 }' "$1"
}
logcol2() {  # logcol2 <로그> <base|merged> — 그 사본 줄들의 둘째 칸
  [ -f "$1" ] || return 0
  awk -F'\t' -v s="/$2" '{ if (substr($1, length($1) - length(s) + 1) == s) print $2 }' "$1"
}
with_runner() { mkdir -p "$W/tools/suite"; cp "$ROOT"/tools/suite/{run-all.sh,run_unittest_dir.py,suite_peers.py} "$W/tools/suite/"; }
# 호출한 쪽의 낡은 목록 — 합친 사본의 실패에 없는 대상(test_seen.sh)을 가리킨다. 기준 사본에 새면 /base 가 한 줄 생긴다
printf 'shared/tests/test_seen.sh: x\n' > "$T/stale-list"

# 12 — AC14: 합친 사본이 깨끗하면 기준 사본을 돌지 않는다
mkrepo cl 'test_command: bash run.sh\n'
put run.sh "$LOGLINE"$'\necho "  ✓ fine"'; push_base; put x.txt x; branch_with feature/cl
out="$(MC_LOG="$T/cl.log" mc --branch feature/cl)"; rc=$?
assert_eq "$rc" "0" "깨끗한 합친 사본 → rc 0"
assert_contains "$out" "판정: 새 실패 없음" "깨끗한 합친 사본: 새 실패 없음"
assert_contains "$out" "기준 사본은 돌리지 않았다" "깨끗한 합친 사본: 기준 사본을 돌리지 않았다고 알린다"
assert_contains "$out" "기본 브랜치에만 있는 실패(고쳐짐) — 재지 않았다" "깨끗한 합친 사본: 고쳐짐은 재지 않았다"
assert_eq "$(logn "$T/cl.log" base)" "0" "깨끗한 합친 사본: 기준 사본에서 테스트 명령을 돌리지 않았다"
assert_eq "$(logn "$T/cl.log" merged)" "1" "깨끗한 합친 사본: 합친 사본에서 한 번 돌았다"
assert_eq "$(headline "$out" feature/cl "을 돌렸다 — 기본 브랜치 사본은 돌리지 않았다")" "1" "깨끗한 합친 사본: 머리 줄이 기본 브랜치 사본을 돌리지 않았다고 말한다"

# 13 — AC15 · AC19 · AC24(없는 대상) · AC30: 실제 러너 · 원래 실패 하나 + 새 실패 하나 · 호출한 쪽에 살아 있는 목록
mkrepo ra 'test_command: bash tools/suite/run-all.sh\ntest_failure_pattern: "^FAILED (.+)$"\n'
with_runner
put shared/tests/test_old.sh $'echo "  ✗ old"\nexit 1'
put shared/tests/test_seen.sh "$LOGLINE"
push_base
put shared/tests/test_new.sh $'echo "  ✗ new"\nexit 1'; branch_with feature/ra
out="$(SUITE_ONLY_FAILED_FILE="$T/stale-list" MC_LOG="$T/ra.log" mc --branch feature/ra)"; rc=$?
assert_eq "$rc" "1" "실제 러너: 새 실패 → rc 1"
assert_contains "$out" "이 브랜치에만 있는 실패 1개: shared/tests/test_new.sh: new" "실제 러너: 새 실패는 기준 사본에 없는 대상의 것"
assert_contains "$out" "양쪽 다 있는 실패 1개: shared/tests/test_old.sh: old" "실제 러너: 원래 실패는 양쪽 다 있는 실패다"
assert_contains "$out" "목록(SUITE_ONLY_FAILED_FILE)으로 건네 돌렸다" "실제 러너: 기준 사본에 목록을 건넸다고 알린다"
assert_eq "$(logn "$T/ra.log" merged)" "1" "실제 러너: 합친 사본은 호출한 쪽 목록을 무시하고 전부 돌았다"
assert_eq "$(logn "$T/ra.log" base)" "0" "실제 러너: 기준 사본은 목록의 대상(test_old.sh)만 돌았다"
assert_eq "$(headline "$out" feature/ra "을 돌렸고 기본 브랜치 사본은 합친 사본의 실패 목록\(SUITE_ONLY_FAILED_FILE\)을 건네 돌렸다")" "1" "실제 러너: 머리 줄이 기본 브랜치 사본에 실패 목록을 건넸다고 말한다"

# 14 — AC16: 목록을 모르는 명령 — 기준 사본은 목록을 받고도 전부 돈다
mkrepo nl 'test_command: bash run.sh\ntest_failure_pattern: "^FAILED (.+)$"\n'
put run.sh "$LOGLINE"$'\necho "FAILED a.sh: old"\nexit 1'; push_base
put run.sh "$LOGLINE"$'\necho "FAILED a.sh: old"\necho "FAILED b.sh: new"\nexit 1'; branch_with feature/nl
out="$(MC_LOG="$T/nl.log" mc --branch feature/nl)"; rc=$?
assert_eq "$rc" "1" "목록을 모르는 명령: 새 실패 → rc 1"
assert_contains "$out" "이 브랜치에만 있는 실패 1개: b.sh: new" "목록을 모르는 명령: 새 실패 이름"
assert_contains "$out" "양쪽 다 있는 실패 1개: a.sh: old" "목록을 모르는 명령: 원래 실패는 양쪽 다 있는 실패다"
assert_eq "$(logcol2 "$T/nl.log" base | grep -c .)" "1" "목록을 모르는 명령: 기준 사본은 목록을 받고 돌았다"
out="$(SUITE_ONLY_FAILED_FILE="$T/stale-list" MC_LOG="$T/nl2.log" mc --branch feature/nl)"; rc=$?
assert_eq "$(logcol2 "$T/nl2.log" base | grep -c '/only-failed\.txt$')" "1" "목록을 모르는 명령: 호출한 쪽 목록이 있어도 기준 사본은 대조가 만든 목록(only-failed.txt)을 받았다"
# 14b — 합친 사본 뒤 Stop 아닌 예외(목록 파일을 쓰지 못함)에도 머리 줄을 그때까지의 꼴로 낸다
out="$(cd "$W" && python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import merge_check as m
m.ONLY_FAILED_FILE = "base"   # 실행 폴더의 기준 사본 폴더 — write_text 가 IsADirectoryError 로 실패한다
sys.exit(m.main(["run", "--roadmap", sys.argv[2], "--no-fetch", "--branch", "feature/nl"]))' "$ROOT/plugins/spec-distill/scripts" "$RM" 2>&1)"; rc=$?
assert_eq "$rc" "3" "목록 파일을 쓰지 못함 → 내부 오류 rc 3"
assert_contains "$out" "내부 오류: IsADirectoryError" "목록 파일을 쓰지 못함: 내부 오류 줄"
assert_eq "$(headline "$out" feature/nl "을 돌렸다 — 기본 브랜치 사본은 돌리지 않았다")" "1" "목록 파일을 쓰지 못함: 머리 줄을 내고 기본 브랜치 사본은 돌리지 않았다고 말한다"

# 15 — AC17 · AC30: 합친 사본이 이름 없이 실패 → 기준 사본을 목록 변수 없이 전부 돈다
mkrepo nf 'test_command: bash run.sh\n'
put run.sh "$LOGLINE"; push_base
put run.sh "$LOGLINE"$'\nexit 1'; branch_with feature/nf
out="$(SUITE_ONLY_FAILED_FILE="$T/stale-list" MC_LOG="$T/nf.log" mc --branch feature/nf)"; rc=$?
assert_eq "$rc" "1" "이름 없는 실패: rc 1"
assert_contains "$out" "(test_command) 전체 — 이름 대조 불가 — 단위 수준만" "이름 없는 실패: 단위 수준 새 실패"
assert_contains "$out" "기준 사본은 전부 돌렸다" "이름 없는 실패: 기준 사본을 전부 돌렸다고 알린다"
assert_contains "$out" "기본 브랜치에만 있는 실패(고쳐짐) 0개" "이름 없는 실패: 전부 돈 기준 사본으로 고쳐짐을 센다"
assert_eq "$(logn "$T/nf.log" base)" "1" "이름 없는 실패: 기준 사본에서 한 번 돌았다"
assert_eq "$(logn "$T/nf.log" merged)" "1" "이름 없는 실패: 합친 사본에서 한 번 돌았다"
assert_eq "$(logcol2 "$T/nf.log" base)" "" "이름 없는 실패: 기준 사본을 전부 돌 때도 호출한 쪽 목록 변수를 빼고 돈다"
assert_eq "$(logcol2 "$T/nf.log" merged)" "" "이름 없는 실패: 합친 사본도 호출한 쪽 목록 변수를 빼고 돈다"
assert_eq "$(headline "$out" feature/nf "과 기본 브랜치 사본을 돌렸다 — 기본 브랜치 사본은 목록 없이 전부 돌렸다")" "1" "이름 없는 실패: 머리 줄이 기본 브랜치 사본을 전부 돌렸다고 말한다"

# 16 — AC24: 대상 경로를 뺀 이름 — 러너가 목록을 버리고 기준 사본을 전부 돈다
mkrepo rb 'test_command: bash tools/suite/run-all.sh\ntest_failure_pattern: "^FAILED [^:]+: (.+)$"\n'
with_runner
put shared/tests/test_old.sh $'echo "  ✗ old"\nexit 1'
put shared/tests/test_seen.sh "$LOGLINE"
push_base
put shared/tests/test_new.sh $'echo "  ✗ new"\nexit 1'; branch_with feature/rb
out="$(MC_LOG="$T/rb.log" mc --branch feature/rb)"; rc=$?
assert_eq "$rc" "1" "대상 없는 이름: 새 실패 → rc 1"
assert_contains "$out" "이 브랜치에만 있는 실패 1개: new" "대상 없는 이름: 새 실패 이름"
assert_contains "$out" "양쪽 다 있는 실패 1개: old" "대상 없는 이름: 원래 실패는 양쪽 다 있는 실패다"
assert_eq "$(logn "$T/rb.log" base)" "1" "대상 없는 이름: 러너가 목록을 버리고 기준 사본을 전부 돌았다"

# 17 — 합친 사본에서 테스트 명령을 실행하지 못하면 검사 불가
mkrepo nc 'test_command: no-such-cmd-e1p2\n'; put a.txt a; push_base; put b.txt b; branch_with feature/nc
out="$(mc --branch feature/nc)"; rc=$?
assert_eq "$rc" "3" "실행하지 못한 테스트 명령 → rc 3"
assert_contains "$out" "테스트 명령을 실행하지 못했다(rc 127)" "실행하지 못한 테스트 명령 사유"
assert_eq "$(headline "$out" feature/nc "을 돌렸다 — 기본 브랜치 사본은 돌리지 않았다")" "1" "합친 사본에서 멈춰도 머리 줄을 내고 기본 브랜치 사본은 돌리지 않았다고 말한다"

# 17b — 기준 사본만 테스트 명령을 실행하지 못한다(rc 127, 명령 스크립트가 브랜치에만 있다) → rc 3 · 머리 줄은 목록을 건네 돌렸다고 말한다
mkrepo nb 'test_command: bash run.sh\ntest_failure_pattern: "^FAILED (.+)$"\n'; put a.txt a; push_base
put run.sh $'echo "FAILED x: only-branch"\nexit 1'; branch_with feature/nb
out="$(mc --branch feature/nb)"; rc=$?
assert_eq "$rc" "3" "기준 사본만 명령을 실행하지 못함(rc 127) → rc 3"
assert_contains "$out" "테스트 명령을 실행하지 못했다(rc 127)" "기준 사본만 명령을 실행하지 못함: 사유"
assert_eq "$(headline "$out" feature/nb "을 돌렸고 기본 브랜치 사본은 합친 사본의 실패 목록\(SUITE_ONLY_FAILED_FILE\)을 건네 돌렸다")" "1" "기준 사본에서 멈춰도 머리 줄은 목록을 건네 돌렸다고 말한다"

# 18 — 대조가 테스트에 주는 임시 폴더는 git 작업 트리 밖이다(호출한 쪽 TMPDIR 이 git 안이어도) · 링크를 푼 경로다.
#   실행 폴더 안에 두던 때의 성질(3892f86d · b2d5ca11 — 사본마다 따로 · 대조가 끝나면 지움 · 경로 자리표시 <tmp>)을 새 자리에서 잰다.
#   자리표시는 7b · 10c 가 잰다. 테스트 명령은 받은 TMPDIR · 그 풀린 경로를 MC_LOG 에 남기고, TMPDIR 이 git 안이면 실패 이름을 낸다.
mkrepo tg 'test_command: bash run.sh\ntest_failure_pattern: "^FAILED (.+)$"\n'
cat > "$W/run.sh" <<'EOF'
printf '%s\t%s\t%s\n' "$PWD" "$TMPDIR" "$(cd "$TMPDIR" && pwd -P)" >> "${MC_LOG:-/dev/null}"
if git -C "$TMPDIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then echo "FAILED tmp: inside-git"; exit 1; fi
if [ -f fail.txt ]; then echo "FAILED x: only-branch"; exit 1; fi
echo ok
EOF
push_base
put b.txt b; branch_with feature/tg
put fail.txt f; branch_with feature/tg2   # 합친 사본에만 실패 — 기준 사본도 돌아 두 사본의 TMPDIR 을 견준다
mkdir -p "$W/tmpin"; echo tmpin >> "$W/.git/info/exclude"
out="$(MC_LOG="$T/tg.log" TMPDIR="$W/tmpin" mc --branch feature/tg)"; rc=$?
assert_eq "$rc" "0" "호출한 쪽 TMPDIR 이 git 안이어도 대조가 주는 임시 폴더는 git 밖이다"
assert_not_contains "$out" "inside-git" "호출한 쪽 TMPDIR 이 git 안이어도 테스트가 받은 TMPDIR 은 git 밖이다(실패 이름이 없다)"
out="$(MC_LOG="$T/tg2.log" TMPDIR="$W/tmpin" mc --branch feature/tg2)"; rc=$?
assert_eq "$rc" "1" "두 사본을 다 도는 대조: 합친 사본에만 있는 실패 → rc 1"
assert_contains "$out" "이 브랜치에만 있는 실패 1개: x: only-branch" "두 사본을 다 도는 대조: 새 실패는 브랜치의 것 하나뿐이다"
assert_not_contains "$out" "inside-git" "두 사본 모두 git 밖 임시 폴더를 받았다"
assert_eq "$(logn "$T/tg2.log" base) $(logn "$T/tg2.log" merged)" "1 1" "두 사본을 한 번씩 돌았다(전제)"
assert_eq "$(awk -F'\t' '$2 != $3' "$T/tg.log" "$T/tg2.log" | wc -l | tr -d ' ')" "0" "대조가 준 TMPDIR 이 자기 realpath 와 같다(/tmp → /private/tmp 링크를 푼 경로)"
assert_eq "$(cut -f2 "$T/tg2.log" | sort -u | wc -l | tr -d ' ')" "2" "사본마다 따로 — 두 사본의 TMPDIR 이 다르다"
assert_eq "$(awk -F'\t' '{ n = split($1, a, "/"); m = split($2, b, "/"); if (index(b[m], "merge-check-" a[n] "-") != 1) c++ } END { print c + 0 }' "$T/tg2.log")" "0" "사본마다 따로 — 각 사본의 TMPDIR 은 그 사본 이름의 merge-check-<사본>- 폴더다"
CT="$(mktemp -d /tmp/mc-ct.XXXXXX)" || CT=""
if [ -n "$CT" ] && ! git -C "$CT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  CTR="$(cd "$CT" && pwd -P)"
  out="$(MC_LOG="$T/ct.log" TMPDIR="$CT" mc --branch feature/tg2)"; rc=$?
  assert_eq "$rc" "1" "호출한 쪽 TMPDIR 이 git 밖이면 그 아래에서 대조가 돈다 → rc 1"
  assert_eq "$(ls -A "$CT")" "" "대조가 끝나면 만든 임시 폴더를 지운다"
  out="$(MC_LOG="$T/ct.log" TMPDIR="$CT" mc --branch feature/tg2 --keep-merged)"; rc=$?
  assert_contains "$out" "남긴 사본: " "--keep-merged: 합친 사본을 남겼다(전제)"
  assert_eq "$(ls -A "$CT")" "" "--keep-merged 여도 임시 폴더는 지운다"
  out="$(cd "$W" && MC_LOG="$T/ct.log" TMPDIR="$CT" python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import merge_check as m
def boom(*a, **k): raise ValueError("after-compare")
m.report = boom
sys.exit(m.main(["run", "--roadmap", sys.argv[2], "--no-fetch", "--branch", "feature/tg2"]))' "$ROOT/plugins/spec-distill/scripts" "$RM" 2>&1)"; rc=$?
  assert_eq "$rc" "3" "대조 뒤 예외 → 내부 오류 rc 3(전제)"
  assert_eq "$(ls -A "$CT")" "" "예외로 멈춰도 임시 폴더는 지운다"
  assert_eq "$(cut -f2 "$T/ct.log" | grep -c "^${CTR}/merge-check-")" "6" "세 번 · 두 사본 모두 호출한 쪽 TMPDIR(풀린 경로) 아래에 만든 폴더를 받았다(양성 짝 — 지울 것이 있었다)"
else
  no "전제: /tmp 아래에 git 작업 트리 밖 폴더를 만들지 못했다 — 장면 18 의 지움 단언을 돌리지 못했다"
fi
# 대체 길: 후보를 git 안 하나로 갈아 끼우면 알리고 실행 폴더 안을 쓴다 — 그때 run.sh 가 git 안을 잡는다(양성 짝)
out="$(cd "$W" && python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import merge_check as m
m.tmp_candidates = lambda: [sys.argv[3]]
sys.exit(m.main(["run", "--roadmap", sys.argv[2], "--no-fetch", "--branch", "feature/tg"]))' "$ROOT/plugins/spec-distill/scripts" "$RM" "$W" 2>&1)"; rc=$?
assert_contains "$out" "git 작업 트리 밖 임시 폴더를 찾지 못해 실행 폴더 안을 쓴다" "후보가 모두 git 안이면 알리고 실행 폴더 안을 쓴다"
assert_contains "$out" "tmp: inside-git" "대체 길: 실행 폴더 안 TMPDIR 은 git 안이다(양성 짝 — run.sh 의 검사가 이를 잡는다)"
assert_eq "$(ls -A "$W/tmpin")" "" "호출한 쪽 TMPDIR(git 안)에는 아무것도 남기지 않는다"
# 18b — 탐지 경로(test_command 없음)의 단위 실행도 같은 자리를 받는다: 실행 비트 셸 단위가 받은 TMPDIR 을 남긴다
mkrepo td; mkdir -p "$W/tests"
cat > "$W/tests/t.sh" <<'EOF'
#!/usr/bin/env bash
if git -C "$TMPDIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then w=in; else w=out; fi
if [ -d "$TMPDIR" ]; then e=yes; else e=no; fi
printf '%s\t%s\t%s\t%s\t%s\n' "$PWD" "$TMPDIR" "$w" "$e" "${SUITE_ONLY_FAILED_FILE:-}" >> "${MC_LOG:-/dev/null}"
exit 0
EOF
chmod +x "$W/tests/t.sh"; push_base; put x.txt x; branch_with feature/td
mkdir -p "$W/tmpin"; echo tmpin >> "$W/.git/info/exclude"
out="$(MC_LOG="$T/td.log" TMPDIR="$W/tmpin" SUITE_ONLY_FAILED_FILE="$T/stale-list" mc --branch feature/td)"; rc=$?
assert_eq "$rc" "0" "탐지 경로: 깨끗한 셸 단위 → rc 0(전제)"
assert_contains "$out" "무엇을 돌렸나: 탐지한 러너 shell" "탐지 경로가 돌았다(전제)"
assert_eq "$(logn "$T/td.log" base) $(logn "$T/td.log" merged)" "1 1" "탐지 경로: 두 사본의 단위를 한 번씩 돌았다(전제)"
assert_eq "$(awk -F'\t' '$3 != "out"' "$T/td.log" | wc -l | tr -d ' ')" "0" "탐지 경로: 단위가 받은 TMPDIR 은 git 작업 트리 밖이다(호출한 쪽 TMPDIR 이 git 안이어도)"
assert_eq "$(awk -F'\t' '$4 != "yes"' "$T/td.log" | wc -l | tr -d ' ')" "0" "탐지 경로: 단위가 받은 TMPDIR 폴더가 실제로 있었다(git 밖 단언이 공허하지 않다)"
assert_eq "$(awk -F'\t' '$5 != ""' "$T/td.log" | wc -l | tr -d ' ')" "0" "탐지 경로: 호출한 쪽 목록 변수를 단위에 건네지 않는다"
assert_eq "$(awk -F'\t' '{ n = split($1, a, "/"); m = split($2, b, "/"); if (index(b[m], "merge-check-" a[n] "-") != 1) c++ } END { print c + 0 }' "$T/td.log")" "0" "탐지 경로: 각 사본의 단위는 그 사본의 merge-check-<사본>- 폴더를 TMPDIR 로 받는다"

# 19 — 임시 자리 고르기(tmp_candidates · outside_git · side_tmps)의 갈래를 함수 단위로 잰다. 후보 폴더는 /tmp 아래 git 밖(NG).
#   side.py <경우> 는 「<경우> note=<알림 또는 ->」 · 「<경우> <사본>=<폴더>」 줄을 내고 만든 폴더를 지운다(죽으면 「<경우> raised=<예외>」).
NG="$(mktemp -d /tmp/mc-ng.XXXXXX)" || NG=""
if [ -n "$NG" ] && ! git -C "$NG" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  NG="$(cd "$NG" && pwd -P)"
  mkrepo st; put a.txt a; push_base; WR="$(cd "$W" && pwd -P)"   # git 안 후보
  mkdir -p "$NG/a" "$NG/b" "$NG/fakegit"; : > "$NG/file"
  printf '#!/bin/sh\necho "fatal: boom-e1r" >&2\nexit 1\n' > "$NG/fakegit/git"; chmod +x "$NG/fakegit/git"
  cat > "$T/side.py" <<'EOF'
import os
import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
import merge_check as m
ng, repo, case = Path(sys.argv[2]), sys.argv[3], sys.argv[4]
work = ng / ("work-" + case)
work.mkdir()
real_mkdtemp, real_cands = m.tempfile.mkdtemp, m.tmp_candidates
if case.startswith("gettempdir"):
    def boom():
        raise FileNotFoundError(2, "No usable temporary directory found")
    m.tempfile.gettempdir = boom
if case == "gettempdir-why":   # 기본 자리의 까닭만 남기고 나머지 후보는 쓸 수 없는 것으로 바꾼다
    m.tmp_candidates = lambda: [c for c in real_cands() if not isinstance(c, str)] + [str(ng / "file")]
elif case != "gettempdir":
    cands = {"mkdtemp": [ng / "a", ng / "b"], "dotgit": [Path(repo) / ".git", ng / "b"],
             "gitenv": [ng / "b"], "unknown": [ng / "b"], "why": [ng / "file", Path(repo), ng / "a"]}[case]
    m.tmp_candidates = lambda: [str(c) for c in cands]
if case in ("mkdtemp", "why"):   # 후보 a 에서만 폴더 만들기가 실패한다
    def flaky(*a, **k):
        if os.path.realpath(str(k.get("dir", ""))) == str(ng / "a"):
            raise PermissionError(13, "Permission denied")
        return real_mkdtemp(*a, **k)
    m.tempfile.mkdtemp = flaky
if case == "gitenv":   # 호출한 쪽이 다른 레포의 GIT_DIR · GIT_WORK_TREE 를 물려준다
    os.environ["GIT_DIR"] = str(Path(repo) / ".git")
    os.environ["GIT_WORK_TREE"] = repo
if case == "unknown":   # git 이 「레포 아님」 이 아닌 까닭으로 실패한다
    os.environ["PATH"] = str(ng / "fakegit") + os.pathsep + os.environ["PATH"]
try:
    tmps, note = m.side_tmps(work)
except BaseException as exc:
    print("%s raised=%s" % (case, type(exc).__name__))
    sys.exit(0)
print("%s note=%s" % (case, note or "-"))
for side in m.SIDES:
    print("%s %s=%s" % (case, side, tmps[side]))
m.drop_tmps(tmps)
EOF
  side() { python3 "$T/side.py" "$ROOT/plugins/spec-distill/scripts" "$NG" "$W" "$1" 2>&1; }
  TR="$(cd /tmp && pwd -P)"
  o="$(side gettempdir)"
  assert_not_contains "$o" "raised=" "기본 임시 자리를 정하지 못해도(gettempdir 실패) 내부 오류로 멈추지 않는다"
  assert_contains "$o" "gettempdir merged=$TR/merge-check-merged-" "기본 임시 자리를 정하지 못하면 다음 후보(/tmp)로 간다"
  o="$(side gettempdir-why)"
  assert_contains "$o" "git 작업 트리 밖 임시 폴더를 찾지 못해 실행 폴더 안을 쓴다" "후보가 모두 떨어지면 대체 길(실행 폴더 안)로 간다"
  assert_contains "$o" "기본 임시 자리를 정하지 못했다(FileNotFoundError: No usable temporary directory found)" "대체 길 알림이 기본 임시 자리를 못 정한 까닭을 싣는다"
  o="$(side mkdtemp)"
  assert_contains "$o" "mkdtemp note=-" "첫 후보에서 폴더를 만들지 못해도 다음 후보가 되면 알리지 않는다"
  assert_contains "$o" "mkdtemp merged=$NG/b/merge-check-merged-" "첫 후보에서 폴더를 만들지 못하면(OSError) 다음 후보로 간다"
  assert_eq "$(ls -A "$NG/a")" "" "폴더를 만들지 못한 후보에는 아무것도 남기지 않는다"
  o="$(side dotgit)"
  assert_contains "$o" "dotgit merged=$NG/b/merge-check-merged-" "레포의 .git 폴더 안(git 이 「작업 트리 안 아님」 이라 답한다)은 git 밖으로 치지 않는다"
  o="$(side gitenv)"
  assert_contains "$o" "gitenv note=-" "호출한 쪽 GIT_DIR · GIT_WORK_TREE 가 있어도 git 밖 후보를 git 밖으로 잰다(알림 없음)"
  assert_contains "$o" "gitenv merged=$NG/b/merge-check-merged-" "호출한 쪽 GIT_DIR · GIT_WORK_TREE 를 빼고 재어 git 밖 후보를 쓴다"
  o="$(side unknown)"
  assert_contains "$o" "unknown merged=$NG/work-unknown/tmp-merged" "git 이 다른 까닭으로 실패하면 git 밖으로 치지 않고 대체 길로 간다"
  assert_contains "$o" "$NG/b: git 밖인지 가리지 못했다(fatal: boom-e1r)" "git 밖인지 가리지 못한 까닭을 알림에 싣는다"
  o="$(side why)"
  assert_contains "$o" "why merged=$NG/work-why/tmp-merged" "후보가 모두 떨어지면 실행 폴더 안을 쓴다(전제)"
  assert_contains "$o" "$NG/file: 쓸 수 있는 폴더가 아니다" "대체 길 알림: 폴더가 아닌 후보의 까닭"
  assert_contains "$o" "$WR: git 작업 트리 안이다" "대체 길 알림: git 안 후보의 까닭"
  assert_contains "$o" "$NG/a: 폴더를 만들지 못했다(PermissionError: Permission denied)" "대체 길 알림: 폴더를 만들지 못한 까닭을 버리지 않는다"
else
  no "전제: /tmp 아래에 git 작업 트리 밖 폴더를 만들지 못했다 — 장면 19 를 돌리지 못했다"
fi

finish
