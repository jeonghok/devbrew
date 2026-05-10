#!/usr/bin/env bash
# Tests for scripts/detect-runtime.sh — fixture-based black-box testing.
# Mirrors style of test_discover_plan.sh.

set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/detect-runtime.sh"
FIXTURES="$(cd "$(dirname "$0")" && pwd)/fixtures/gate3"
PASS=0
FAIL=0

note() { echo "  → $1"; }

assert_eq() {
  local actual="$1" expected="$2" msg="$3"
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (got '$actual', expected '$expected')"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (string '$needle' not in output)"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (unexpected '$needle' in output)"
  fi
}

run_detector() {
  local fixture="$1"; shift
  cd "$FIXTURES/$fixture"
  bash "$SCRIPT" "$@" 2>/dev/null
  return $?
}

# --- Test 1: markdown-only fixture → empty runnable_surfaces ---
echo "== Test 1: markdown-only =="
OUT=$(run_detector "markdown-only")
RC=$?
assert_eq "$RC" "0" "T1: exit 0"
assert_contains "$OUT" "project_type:" "T1: emits project_type"
assert_contains "$OUT" "runnable_surfaces: []" "T1: empty runnable_surfaces"
assert_contains "$OUT" "test_runners: []" "T1: empty test_runners"

# --- Test 2: web-compose fixture → docker-compose + npm-script surfaces ---
echo "== Test 2: web-compose =="
OUT=$(run_detector "web-compose")
RC=$?
assert_eq "$RC" "0" "T2: exit 0"
assert_contains "$OUT" "project_type: web" "T2: project_type=web"
assert_contains "$OUT" "kind: docker-compose" "T2: docker-compose surface"
assert_contains "$OUT" "kind: npm-script" "T2: npm-script surface"
assert_contains "$OUT" "name: dev" "T2: npm:dev script detected"
assert_contains "$OUT" "name: test" "T2: npm:test script detected"
assert_contains "$OUT" "test_runners:" "T2: emits test_runners"
assert_contains "$OUT" "- npm" "T2: npm in test_runners"

# --- Test 3: library-tests fixture → pytest only ---
echo "== Test 3: library-tests =="
OUT=$(run_detector "library-tests")
RC=$?
assert_eq "$RC" "0" "T3: exit 0"
assert_contains "$OUT" "project_type: library" "T3: project_type=library"
assert_contains "$OUT" "kind: pytest" "T3: pytest surface"
assert_contains "$OUT" "- pytest" "T3: pytest in test_runners"
assert_not_contains "$OUT" "kind: npm-script" "T3: no npm in non-node project"

# --- Test 4: web-example-only fixture → env_status flags missing .env ---
echo "== Test 4: web-example-only =="
OUT=$(run_detector "web-example-only")
RC=$?
assert_eq "$RC" "0" "T4: exit 0"
assert_contains "$OUT" "project_type: web" "T4: web project"
assert_contains "$OUT" "env_status:" "T4: emits env_status"
assert_contains "$OUT" "file: .env" "T4: tracks .env file"
assert_contains "$OUT" "exists: false" "T4: .env does not exist"
assert_contains "$OUT" "has_example: true" "T4: .env.example present"

# --- Test 5: app_url_candidates from docker-compose ports ---
echo "== Test 5: app_url_candidates =="
OUT=$(run_detector "web-compose")
assert_contains "$OUT" "app_url_candidates:" "T5: emits app_url_candidates"
assert_contains "$OUT" "http://localhost:3000" "T5: port 3000 from compose"

# --- Test 6: mcp_browser defaults to "none" when no settings reference it ---
echo "== Test 6: mcp_browser default =="
TMPHOME=$(mktemp -d)
OUT=$(cd "$FIXTURES/markdown-only" && HOME="$TMPHOME" bash "$SCRIPT" 2>/dev/null)
assert_contains "$OUT" "mcp_browser: none" "T6: defaults to none with no settings"
rm -rf "$TMPHOME"

# --- Test 6b: mcp_browser detects chrome-devtools when settings.json contains it ---
echo "== Test 6b: mcp_browser chrome-devtools detection =="
TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.claude"
cat > "$TMPHOME/.claude/settings.json" <<'EOF'
{
  "mcpServers": {
    "chrome-devtools": {"command": "fake"}
  }
}
EOF
OUT=$(cd "$FIXTURES/markdown-only" && HOME="$TMPHOME" bash "$SCRIPT" 2>/dev/null)
assert_contains "$OUT" "mcp_browser: chrome-devtools" "T6b: detects chrome-devtools"
rm -rf "$TMPHOME"

# --- Test 7: plan_features extracted from plan_path ---
echo "== Test 7: plan_features extraction =="
PLAN_TMP=$(mktemp)
cat > "$PLAN_TMP" <<'EOF'
# Plan
- visit /auth login form
- check /dashboard
EOF
OUT=$(cd "$FIXTURES/web-compose" && PLAN_PATH="$PLAN_TMP" bash "$SCRIPT" 2>/dev/null)
assert_contains "$OUT" "plan_features:" "T7: emits plan_features"
assert_contains "$OUT" "/auth" "T7: extracts /auth"
assert_contains "$OUT" "/dashboard" "T7: extracts /dashboard"
rm -f "$PLAN_TMP"

echo ""
echo "Tests passed: $PASS, failed: $FAIL"
[[ $FAIL -eq 0 ]] || exit 1
