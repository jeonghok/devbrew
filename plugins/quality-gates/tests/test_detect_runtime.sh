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

# --- Test 6c: mcp_browser falls back to playwright when only playwright is configured ---
echo "== Test 6c: mcp_browser playwright detection =="
TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.claude"
cat > "$TMPHOME/.claude/settings.json" <<'EOF'
{
  "mcpServers": {
    "playwright": {"command": "fake"}
  }
}
EOF
OUT=$(cd "$FIXTURES/markdown-only" && HOME="$TMPHOME" bash "$SCRIPT" 2>/dev/null)
assert_contains "$OUT" "mcp_browser: playwright" "T6c: detects playwright as fallback"
rm -rf "$TMPHOME"

# --- Test 6d: chrome-devtools wins over playwright when both are configured ---
echo "== Test 6d: mcp_browser chrome-devtools priority over playwright =="
TMPHOME=$(mktemp -d)
mkdir -p "$TMPHOME/.claude"
cat > "$TMPHOME/.claude/settings.json" <<'EOF'
{
  "mcpServers": {
    "playwright": {"command": "fake"},
    "chrome-devtools": {"command": "fake"}
  }
}
EOF
OUT=$(cd "$FIXTURES/markdown-only" && HOME="$TMPHOME" bash "$SCRIPT" 2>/dev/null)
assert_contains "$OUT" "mcp_browser: chrome-devtools" "T6d: chrome-devtools wins"
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

# --- helper: extract the runnable_surfaces block that contains a marker ---
get_surface_block() {
  # $1 = full manifest text, $2 = marker substring identifying the surface
  awk -v marker="$2" '
    /^  - kind:/ {
      if (block != "" && index(block, marker)) print block
      block = $0 "\n"; next
    }
    /^[a-z_]+:/ {            # a top-level key ends the surfaces region
      if (block != "" && index(block, marker)) print block
      block = ""; next
    }
    { if (block != "") block = block $0 "\n" }
    END { if (block != "" && index(block, marker)) print block }
  ' <<< "$1"
}

# --- Test 8: blast-radius — process-start surfaces require_decision (AC2) ---
echo "== Test 8: blast-radius process-start =="
OUT=$(run_detector "web-compose")
dev_block=$(get_surface_block "$OUT" "name: dev")
test_block=$(get_surface_block "$OUT" "name: test")
assert_contains "$dev_block" "requires_decision: true" "T8: npm:dev requires_decision"
assert_not_contains "$test_block" "requires_decision" "T8: npm:test stays automatic"

# docker-compose keeps its existing requires_decision
dc_block=$(get_surface_block "$OUT" "kind: docker-compose")
assert_contains "$dc_block" "requires_decision: true" "T8: docker-compose requires_decision (unchanged)"

# --- Test 9: test runners stay automatic (AC2) ---
echo "== Test 9: test runner automatic =="
OUT=$(run_detector "library-tests")
pytest_block=$(get_surface_block "$OUT" "kind: pytest")
assert_not_contains "$pytest_block" "requires_decision" "T9: pytest automatic (no gate)"

# --- Test 10: danger-signal escalates an otherwise-automatic surface (AC5) ---
echo "== Test 10: danger-signal escalation =="
OUT=$(run_detector "danger-signal")
sig_test_block=$(get_surface_block "$OUT" "name: test")
assert_contains "$sig_test_block" "requires_decision: true" "T10: network-signal test script escalated"

# --- Test 11: CLI-tool fixture detected as cli project ---
echo "== Test 11: cli-tool fixture =="
OUT=$(run_detector "cli-tool")
RC=$?
assert_eq "$RC" "0" "T11: exit 0"
assert_contains "$OUT" "project_type: cli" "T11: project_type=cli"

# --- Test 12: --force-exit must NOT escalate (I1 false-positive fix) ---
echo "== Test 12: --force-exit not escalated =="
OUT=$(run_detector "force-flag")
ff_test_block=$(get_surface_block "$OUT" "name: test")
assert_not_contains "$ff_test_block" "requires_decision" "T12: jest --force-exit stays automatic"

echo ""
echo "Tests passed: $PASS, failed: $FAIL"
[[ $FAIL -eq 0 ]] || exit 1
