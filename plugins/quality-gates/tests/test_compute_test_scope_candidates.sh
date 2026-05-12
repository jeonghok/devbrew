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

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
