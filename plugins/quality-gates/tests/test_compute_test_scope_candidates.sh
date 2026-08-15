#!/usr/bin/env bash
# Tests for scripts/compute-test-scope-candidates.sh
# Builds temp git repos at runtime; verifies heuristic src→test mapping
# + changed-test fallback + language-unsupported empty result.

set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/compute-test-scope-candidates.sh"
PASS=0
FAIL=0

note() { echo "  → $1"; }

assert_eq() {
  local actual="$1" expected="$2" msg="$3"
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg"
    echo "    got:      $actual"
    echo "    expected: $expected"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (missing '$needle')"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (unexpected '$needle')"
  fi
}

mktemp_repo() {
  local d
  d=$(mktemp -d -t qg-cand-XXXXXX)
  (
    cd "$d"
    git init -q
    git config user.email test@example.com
    git config user.name Test
    git config commit.gpgsign false
  )
  echo "$d"
}

run_script() {
  local repo="$1"
  ( cd "$repo" && bash "$SCRIPT" ) 2>/dev/null
}

# --- Test 1: Python src change → maps to existing tests/test_foo.py ---
echo "== Test 1: Python mapping =="
REPO=$(mktemp_repo)
(
  cd "$REPO"
  mkdir -p src tests
  echo "def foo(): return 1" > src/foo.py
  echo "from src.foo import foo
def test_foo(): assert foo() == 1" > tests/test_foo.py
  git add . && git commit -q -m "init"
  echo "def foo(): return 2" > src/foo.py
)
OUT=$(run_script "$REPO")
assert_contains "$OUT" "tests/test_foo.py" "T1: maps src/foo.py to tests/test_foo.py"
rm -rf "$REPO"

# --- Test 2: TypeScript src change → maps to .test.ts neighbor ---
echo "== Test 2: TypeScript mapping =="
REPO=$(mktemp_repo)
(
  cd "$REPO"
  mkdir -p src
  echo "export const bar = () => 1" > src/bar.ts
  echo "import { bar } from './bar'
test('bar', () => { expect(bar()).toBe(1) })" > src/bar.test.ts
  git add . && git commit -q -m "init"
  echo "export const bar = () => 2" > src/bar.ts
)
OUT=$(run_script "$REPO")
assert_contains "$OUT" "src/bar.test.ts" "T2: maps src/bar.ts to src/bar.test.ts"
rm -rf "$REPO"

# --- Test 3: changed test file is included verbatim ---
echo "== Test 3: changed-test fallback =="
REPO=$(mktemp_repo)
(
  cd "$REPO"
  mkdir -p tests
  echo "def test_x(): pass" > tests/test_x.py
  git add . && git commit -q -m "init"
  echo "def test_x(): assert True" > tests/test_x.py
)
OUT=$(run_script "$REPO")
assert_contains "$OUT" "tests/test_x.py" "T3: changed test file appears in candidates"
rm -rf "$REPO"

# --- Test 4: unsupported language (Go), no neighbor test → empty result ---
echo "== Test 4: unsupported language =="
REPO=$(mktemp_repo)
(
  cd "$REPO"
  echo "package main
func main() {}" > main.go
  git add . && git commit -q -m "init"
  echo "package main
func main() { println() }" > main.go
)
OUT=$(run_script "$REPO")
assert_eq "$OUT" "" "T4: Go src change without test produces empty output"
rm -rf "$REPO"

# --- Test 5: no diff (clean working tree, no commits ahead) → empty ---
echo "== Test 5: no diff =="
REPO=$(mktemp_repo)
(
  cd "$REPO"
  echo "x" > a.py
  git add . && git commit -q -m "init"
)
OUT=$(run_script "$REPO")
assert_eq "$OUT" "" "T5: clean tree produces empty output"
rm -rf "$REPO"

# --- Test 6: de-duplication (src change + same test also touched) ---
echo "== Test 6: de-dup =="
REPO=$(mktemp_repo)
(
  cd "$REPO"
  mkdir -p src tests
  echo "def f(): return 1" > src/f.py
  echo "from src.f import f
def test_f(): assert f() == 1" > tests/test_f.py
  git add . && git commit -q -m "init"
  echo "def f(): return 2" > src/f.py
  echo "from src.f import f
def test_f(): assert f() == 2" > tests/test_f.py
)
OUT=$(run_script "$REPO")
# tests/test_f.py should appear exactly once
COUNT=$(echo "$OUT" | grep -c '^tests/test_f.py$' || true)
assert_eq "$COUNT" "1" "T6: tests/test_f.py appears exactly once"
rm -rf "$REPO"

# --- Test 7 (/qg iter-6 D1): 분모(--total)가 분자(후보)를 반드시 포함한다 ---
#
# `TESTRE` 에 `test_*.py` 가 없어서, 매퍼가 명시적으로 찾는 `test_${base}.py` 가
# **분자에는 들어가고 분모에는 안 들어갔다** (실측: N=1, M=0). SKILL 은
# `영향 테스트 N개 선택 (전체 M개 중)` 의 분모를 비율 부풀리기를 막으려고 이 스크립트에서
# 강제로 가져오므로, M < N 이면 그 보증이 통째로 무너진다.
#
# 관계로 잰다 (∀, 값 핀 아님): 후보로 나온 **모든** 경로가 분모 집합에도 있어야 한다.
# 값을 핀하면 픽스처가 바뀔 때마다 무의미하게 red 가 된다.
echo "== Test 7: --total 분모 ⊇ 후보 분자 =="
REPO=$(mktemp -d)
(
  cd "$REPO" && git init -q .
  echo "def f(): return 1" > mod.py
  echo "from mod import f
def test_f(): assert f() == 1" > test_mod.py          # 루트의 test_*.py — 매퍼가 찾는 형태
  mkdir -p pkg && echo "def g(): return 1" > pkg/g.py
  echo "def test_g(): pass" > pkg/g_test.py           # 이미 덮이던 형태(대조군)
  git add -A && git -c user.email=t@t -c user.name=t commit -qm init
  echo "def f(): return 2" > mod.py
  echo "def g(): return 2" > pkg/g.py
)
CANDS=$(run_script "$REPO")
TOTAL_LIST=$( ( cd "$REPO" && git ls-files | grep -E '(test|spec)\.[jt]sx?$|_test\.py$|(^|/)test_[^/]*\.py$|\.test\.|\.spec\.|(^|/)tests?/' ) || true )
TOTAL_N=$( ( cd "$REPO" && bash "$SCRIPT" --total ) 2>/dev/null )
MISSING=""
while IFS= read -r c; do
  [[ -z "$c" ]] && continue
  printf '%s\n' "$TOTAL_LIST" | grep -qxF -- "$c" || MISSING="$MISSING $c"
done <<< "$CANDS"
# 양의 짝: 후보가 0개면 위 ∀ 는 공허하게 참이다.
CAND_N=$(printf '%s\n' "$CANDS" | grep -c . || true)
if [[ "$CAND_N" -lt 1 ]]; then
  FAIL=$((FAIL + 1)); echo "  ✗ FAIL: T7 후보가 0개 — ∀ 가 공허하게 통과할 뻔했다"
else
  assert_eq "$MISSING" "" "T7: 후보 ${CAND_N}개 전부가 --total 분모에 포함 (∀)"
  # 분모가 분자보다 작아질 수 없다
  if [[ "$TOTAL_N" -ge "$CAND_N" ]]; then
    PASS=$((PASS + 1)); note "PASS: T7: 분모 M=$TOTAL_N ≥ 분자 N=$CAND_N"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: T7: 분모 M=$TOTAL_N < 분자 N=$CAND_N"
  fi
fi
rm -rf "$REPO"

# --- Test 8 (/qg iter-6 E10 ≡ §6.7 F6): 소유자 부재가 조용한 빈 결과가 되지 않는다 ---
#
# `RB_OUT=$(... || true)` 는 `resolve-baseline.sh` 의 부재·실패를 빈 문자열로 바꿔
# `REVIEW_RANGE=""` 로 조용히 떨어뜨렸다. 형제 `check-review-scope.sh` 는 같은 자리에서
# `|| emit_degraded` 로 fail-closed 다. 후보 목록은 힌트라 verdict 를 직접 막지 않지만,
# "영향 테스트 0개" 가 "영향이 없다" 로 읽히면 R2 선택 근거가 거짓이 된다.
#
# 양의 짝: 소유자가 **있을 때는** 이 경고가 나오면 안 된다.
echo "== Test 8: resolve-baseline.sh 부재 → loud =="
ORPHAN=$(mktemp -d)
cp "$SCRIPT" "$ORPHAN/compute-test-scope-candidates.sh"     # 형제 스크립트 없이 고립
(
  cd "$ORPHAN" && git init -q . && echo "x" > a.py
  git add -A && git -c user.email=t@t -c user.name=t commit -qm i
)
ORPHAN_ERR=$( ( cd "$ORPHAN" && bash "$ORPHAN/compute-test-scope-candidates.sh" ) 2>&1 >/dev/null )
assert_contains "$ORPHAN_ERR" "resolve-baseline.sh 실행 실패" "T8: 소유자 부재가 loud (조용한 빈 결과 아님)"
rm -rf "$ORPHAN"

REPO=$(mktemp -d)
(
  cd "$REPO" && git init -q . && echo "x" > a.py
  git add -A && git -c user.email=t@t -c user.name=t commit -qm i
)
NORMAL_ERR=$( ( cd "$REPO" && bash "$SCRIPT" ) 2>&1 >/dev/null )
assert_not_contains "$NORMAL_ERR" "resolve-baseline.sh 실행 실패" "T8: 소유자가 있으면 무경고 (양의 짝)"
rm -rf "$REPO"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
