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

# --- validate-branch ---
echo "[validate-branch]"

REPO=$(mktemp -d)
(cd "$REPO" && git init -q -b main && git config user.email t@t && \
  git config user.name t && git commit -q --allow-empty -m init && \
  git branch real-branch)

(cd "$REPO" && "$WT" validate-branch real-branch) \
  && pass "existing branch ok" || fail "existing branch rejected"

(cd "$REPO" && "$WT" validate-branch nonexistent 2>/dev/null) \
  && fail "nonexistent accepted" || pass "nonexistent rejected"

rm -rf "$REPO"

# (further subcommand tests appended in later tasks)

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
