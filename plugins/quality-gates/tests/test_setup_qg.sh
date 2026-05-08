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

# --- Test 1: --session-id arg creates per-session folder ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="testsession01"
unset CLAUDE_CODE_SESSION_ID
"$SCRIPT" --session-id "$SID" >/dev/null 2>&1
RC=$?
assert_eq "$RC" "0" "exits 0 with --session-id"
assert_file_exists ".claude/quality-gates/$SID/pipeline.md" "creates pipeline.md in per-session folder"
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

echo
echo "Pass: $PASS, Fail: $FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
