#!/usr/bin/env bash
# test_setup_qg.sh — verify setup-qg.sh --ensure behavior against v1.32.1
# state schema. Replaces the v1.32.0-era assertions against removed schema
# keys (runtime_resolution_iter:, project_dir:) and removed stderr warnings.

set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/setup-qg.sh"

PASS=0
FAIL=0

note() { echo "  → $1"; }

assert() {
  local label="$1" cmd="$2"
  if eval "$cmd"; then PASS=$((PASS + 1)); note "PASS: $label"
  else FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $label"; fi
}

# --- Case 1: fresh state creation ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="test-fresh-$$"
unset CLAUDE_CODE_SESSION_ID
"$SCRIPT" --session-id "$SID" >/dev/null 2>&1
STATE_FILE=".claude/quality-gates/$SID/pipeline.md"
assert "fresh state file created" "test -f '$STATE_FILE'"
assert "state contains session_id" "grep -q 'session_id:' '$STATE_FILE'"
assert "state contains runtime_max_resolutions default 3" "grep -q 'runtime_max_resolutions: 3' '$STATE_FILE'"
assert "v1.32.0 schema: no project_dir in state" "! grep -q '^project_dir:' '$STATE_FILE'"
assert "v1.32.0 schema: no gate2_iteration phantom" "! grep -q '^gate2_iteration:' '$STATE_FILE'"
cd / && rm -rf "$TMPDIR"

# --- Case 2: --ensure idempotency (second call is no-op; same mtime) ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="test-ensure-$$"
unset CLAUDE_CODE_SESSION_ID
CLAUDE_CODE_SESSION_ID="$SID" "$SCRIPT" --ensure >/dev/null 2>&1
STATE_FILE=".claude/quality-gates/$SID/pipeline.md"
mtime1=$(stat -f %m "$STATE_FILE" 2>/dev/null || stat -c %Y "$STATE_FILE")
sleep 1
CLAUDE_CODE_SESSION_ID="$SID" "$SCRIPT" --ensure >/dev/null 2>&1
mtime2=$(stat -f %m "$STATE_FILE" 2>/dev/null || stat -c %Y "$STATE_FILE")
assert "--ensure idempotent (no rewrite)" "test '$mtime1' = '$mtime2'"
cd / && rm -rf "$TMPDIR"

# --- Case 3: clamp DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS=99 → 10 (C3) ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="test-clamp-$$"
unset CLAUDE_CODE_SESSION_ID
DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS=99 "$SCRIPT" --session-id "$SID" >/dev/null 2>err
STATE_FILE=".claude/quality-gates/$SID/pipeline.md"
assert "DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS=99 clamped to 10" "grep -q 'runtime_max_resolutions: 10' '$STATE_FILE'"
assert "clamp warning emitted on stderr" "grep -q 'exceeds maximum 10' err"
cd / && rm -rf "$TMPDIR"

# --- Case 3b: non-numeric → default 3 + stderr warning ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="test-nonnum-$$"
unset CLAUDE_CODE_SESSION_ID
DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS=abc "$SCRIPT" --session-id "$SID" >/dev/null 2>err
STATE_FILE=".claude/quality-gates/$SID/pipeline.md"
assert "non-numeric env defaults to 3" "grep -q 'runtime_max_resolutions: 3' '$STATE_FILE'"
assert "non-numeric warning emitted on stderr" "grep -q 'is not numeric' err"
cd / && rm -rf "$TMPDIR"

# --- Case 4: per-session folder isolation ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="test-isolation-$$"
unset CLAUDE_CODE_SESSION_ID
CLAUDE_CODE_SESSION_ID="$SID" "$SCRIPT" >/dev/null 2>&1
assert "session-isolated folder exists" "test -d '.claude/quality-gates/$SID'"
assert "no flat-layout state files" "! ls .claude/quality-gates*.md 2>/dev/null | grep -q ."
cd / && rm -rf "$TMPDIR"

# --- Case 5: missing both env and arg → hard fail ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
unset CLAUDE_CODE_SESSION_ID
"$SCRIPT" >/dev/null 2>err
RC=$?
assert "missing session-id hard-fails" "test '$RC' -ne 0"
assert "error message mentions session" "grep -qi 'session' err"
cd / && rm -rf "$TMPDIR"

echo
echo "test_setup_qg.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
