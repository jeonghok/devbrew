#!/usr/bin/env bash
# Unit tests for qg-worktree.sh subcommands.
# Each test calls the script with stdin/args and asserts stdout/exit code.
set -u

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WT="$PLUGIN_DIR/scripts/qg-worktree.sh"

PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }

# --- sanitize ---
echo "[sanitize]"

out=$("$WT" sanitize "feat/x" 2>/dev/null) && [ "$out" = "feat-x" ] \
  && pass "slash to dash" || fail "slash to dash got: $out"

out=$("$WT" sanitize "main" 2>/dev/null) && [ "$out" = "main" ] \
  && pass "plain name passthrough" || fail "plain got: $out"

"$WT" sanitize "../evil" >/dev/null 2>&1 && fail "dotdot accepted" \
  || pass "dotdot rejected"

"$WT" sanitize ".hidden" >/dev/null 2>&1 && fail "leading dot accepted" \
  || pass "leading dot rejected"

"$WT" sanitize "with space" >/dev/null 2>&1 && fail "space accepted" \
  || pass "space rejected"

long=$(printf 'a%.0s' {1..65})
"$WT" sanitize "$long" >/dev/null 2>&1 && fail "65 chars accepted" \
  || pass "length cap enforced"

# (further subcommand tests appended in later tasks)

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
