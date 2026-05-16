#!/usr/bin/env bash
# Tests for scripts/setup-qg.sh per-session paths and --session-id arg.
# Uses bash assertions; no external test framework.
set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/setup-qg.sh"
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

assert_file_exists() {
  local path="$1" msg="$2"
  if [[ -f "$path" ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (file missing: $path)"
  fi
}

assert_file_not_exists() {
  local path="$1" msg="$2"
  if [[ ! -e "$path" ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (file exists: $path)"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (string '$needle' not in '$haystack')"
  fi
}

# --- Test 1: --session-id arg creates per-session folder ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="testsession01"
unset CLAUDE_CODE_SESSION_ID
"$SCRIPT" --session-id "$SID" >/dev/null 2>&1
RC=$?
assert_eq "$RC" "0" "exits 0 with --session-id"
STATE_FILE=".claude/quality-gates/$SID/pipeline.md"
assert_file_exists "$STATE_FILE" "creates pipeline.md in per-session folder"
assert_contains "$(cat "$STATE_FILE")" "gate3_resolution_iter: 0" "state file has gate3_resolution_iter"
assert_contains "$(cat "$STATE_FILE")" "max_gate3_resolutions: 3" "state file has max_gate3_resolutions default"
cd / && rm -rf "$TMPDIR"

# --- Test 1a: DEVBREW_GATE3_MAX_RESOLUTIONS=0 honored (Approach 2 mode) ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="testsession1a"
unset CLAUDE_CODE_SESSION_ID
DEVBREW_GATE3_MAX_RESOLUTIONS=0 "$SCRIPT" --session-id "$SID" >/dev/null 2>&1
RC=$?
assert_eq "$RC" "0" "exits 0 with DEVBREW_GATE3_MAX_RESOLUTIONS=0"
STATE_FILE=".claude/quality-gates/$SID/pipeline.md"
assert_contains "$(cat "$STATE_FILE")" "max_gate3_resolutions: 0" "state file honors env=0"
cd / && rm -rf "$TMPDIR"

# --- Test 1b: DEVBREW_GATE3_MAX_RESOLUTIONS=20 clamped to 10 with warning ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="testsession1b"
unset CLAUDE_CODE_SESSION_ID
DEVBREW_GATE3_MAX_RESOLUTIONS=20 "$SCRIPT" --session-id "$SID" >/dev/null 2>err
RC=$?
assert_eq "$RC" "0" "exits 0 with over-cap env"
STATE_FILE=".claude/quality-gates/$SID/pipeline.md"
assert_contains "$(cat "$STATE_FILE")" "max_gate3_resolutions: 10" "over-cap env clamped to 10"
ERR_MSG=$(cat err)
assert_contains "$ERR_MSG" "exceeds maximum 10" "over-cap warns on stderr"
cd / && rm -rf "$TMPDIR"

# --- Test 1c: DEVBREW_GATE3_MAX_RESOLUTIONS=abc warns + defaults to 3 ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="testsession1c"
unset CLAUDE_CODE_SESSION_ID
DEVBREW_GATE3_MAX_RESOLUTIONS=abc "$SCRIPT" --session-id "$SID" >/dev/null 2>err
RC=$?
assert_eq "$RC" "0" "exits 0 with non-numeric env"
STATE_FILE=".claude/quality-gates/$SID/pipeline.md"
assert_contains "$(cat "$STATE_FILE")" "max_gate3_resolutions: 3" "non-numeric env falls back to default 3"
ERR_MSG=$(cat err)
assert_contains "$ERR_MSG" "is not numeric" "non-numeric env warns on stderr"
cd / && rm -rf "$TMPDIR"

# --- Test 2: env var works without --session-id ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="envsess0001"
CLAUDE_CODE_SESSION_ID="$SID" "$SCRIPT" >/dev/null 2>&1
RC=$?
assert_eq "$RC" "0" "exits 0 with env var"
assert_file_exists ".claude/quality-gates/$SID/pipeline.md" "creates pipeline.md from env"
cd / && rm -rf "$TMPDIR"

# --- Test 3: missing both env and arg → hard fail ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
unset CLAUDE_CODE_SESSION_ID
"$SCRIPT" >/dev/null 2>err
RC=$?
ERR_MSG=$(cat err)
[[ "$RC" -ne 0 ]] && PASS=$((PASS + 1)) || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: hard fail expected, got rc=$RC"; }
echo "$ERR_MSG" | grep -q "session" && PASS=$((PASS + 1)) || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: error mentions session"; }
cd / && rm -rf "$TMPDIR"

# --- Test 4: legacy flat files removed on fresh setup ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="legacysess1"
mkdir -p .claude
touch .claude/quality-gates.local.md \
      .claude/quality-gates-session.local.md \
      .claude/quality-gates-branch.local.md \
      .claude/qg-diff-cache.txt \
      .claude/qg-code-paths.tmp
"$SCRIPT" --session-id "$SID" >/dev/null 2>&1
assert_file_not_exists ".claude/quality-gates.local.md" "legacy quality-gates.local.md removed"
assert_file_not_exists ".claude/quality-gates-session.local.md" "legacy session file removed"
assert_file_not_exists ".claude/quality-gates-branch.local.md" "legacy branch file removed"
assert_file_not_exists ".claude/qg-diff-cache.txt" "legacy diff cache removed"
assert_file_not_exists ".claude/qg-code-paths.tmp" "legacy code paths removed"
cd / && rm -rf "$TMPDIR"

# --- Test 5: same-session re-invocation blocked, different-session overwrites ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="sameses0001"
"$SCRIPT" --session-id "$SID" >/dev/null 2>&1
"$SCRIPT" --session-id "$SID" >/dev/null 2>err
RC=$?
[[ "$RC" -ne 0 ]] && PASS=$((PASS + 1)) || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: 2nd invocation same session should error"; }
cd / && rm -rf "$TMPDIR"

# --- Test 6: project_dir in state frontmatter (v1.13.0 AC6) ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
# Resolve the canonical path to handle macOS /var -> /private/var symlink
EXPECTED_DIR=$(cd "$TMPDIR" && pwd)
SID="proj-dir-test-01"
unset CLAUDE_CODE_SESSION_ID
CLAUDE_CODE_SESSION_ID="$SID" "$SCRIPT" >/dev/null 2>&1
STATE_FILE="$TMPDIR/.claude/quality-gates/$SID/pipeline.md"
assert_file_exists "$STATE_FILE" "project_dir test: state file created"
# Verify project_dir key is present
PROJ_LINE=$(grep '^project_dir:' "$STATE_FILE" 2>/dev/null || true)
if [[ -n "$PROJ_LINE" ]]; then
  PASS=$((PASS + 1)); note "PASS: project_dir present in state frontmatter"
else
  FAIL=$((FAIL + 1)); echo "  ✗ FAIL: project_dir missing from state frontmatter at $STATE_FILE"
fi
# Verify value contains expected dir (loose match, cross-platform)
assert_contains "$PROJ_LINE" "$EXPECTED_DIR" "project_dir value equals invocation cwd"
cd / && rm -rf "$TMPDIR"

echo
echo "Pass: $PASS, Fail: $FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
