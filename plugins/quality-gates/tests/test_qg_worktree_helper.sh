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

# Regression: tag is not a branch
(cd "$REPO" && git tag v1) >/dev/null
(cd "$REPO" && "$WT" validate-branch v1 2>/dev/null) \
  && fail "tag accepted as branch" || pass "tag rejected"

rm -rf "$REPO"

# --- create ---
echo "[create]"

REPO=$(mktemp -d)
(cd "$REPO" && git init -q -b main && git config user.email t@t && \
  git config user.name t && git commit -q --allow-empty -m init && \
  git branch feat-x)

SID="abcdef12345678"
WTPATH=$(cd "$REPO" && "$WT" create feat-x "$SID" 2>/dev/null)
[ -d "$WTPATH" ] && pass "create returns valid path" \
  || fail "create path missing: $WTPATH"

[ "$(cd "$WTPATH" && git rev-parse HEAD)" = \
  "$(cd "$REPO" && git rev-parse feat-x)" ] \
  && pass "worktree HEAD matches branch" || fail "HEAD mismatch"

# Detached HEAD check
sym=$(cd "$WTPATH" && git symbolic-ref -q HEAD 2>/dev/null || echo "")
[ -z "$sym" ] && pass "detached HEAD" || fail "not detached: $sym"

# Idempotent reuse
WTPATH2=$(cd "$REPO" && "$WT" create feat-x "$SID" 2>/dev/null)
[ "$WTPATH" = "$WTPATH2" ] && pass "idempotent reuse" \
  || fail "second create differs"

# Kill switch
( cd "$REPO" && DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1 \
    "$WT" create feat-x "killtest-$SID" 2>/dev/null ) \
  && fail "kill switch ignored" || pass "kill switch honored"

# Regression: branch with dot in name doesn't cause grep false positive
(cd "$REPO" && git branch release-1.0) >/dev/null
WTPATH3=$(cd "$REPO" && "$WT" create release-1.0 "dotsid12345678" 2>/dev/null)
[ -d "$WTPATH3" ] && [ "$WTPATH3" != "$WTPATH" ] \
  && pass "dot in branch name doesn't collide" \
  || fail "dot regression: $WTPATH3 vs $WTPATH"

rm -rf "$REPO"

# --- remove ---
echo "[remove]"

REPO=$(mktemp -d)
(cd "$REPO" && git init -q -b main && git config user.email t@t && \
  git config user.name t && git commit -q --allow-empty -m init && \
  git branch feat-y)
WTPATH=$(cd "$REPO" && "$WT" create feat-y "remove-test12345" 2>/dev/null)
[ -d "$WTPATH" ] || { fail "create precondition"; }

(cd "$REPO" && "$WT" remove "$WTPATH") \
  && [ ! -d "$WTPATH" ] && pass "remove deletes dir" \
  || fail "remove failed or dir remains"

# Remove a nonexistent path → exit 0 (best-effort)
(cd "$REPO" && "$WT" remove "$REPO/.claude/quality-gates/worktrees/missing-12345678") \
  && pass "remove missing is noop" || fail "remove missing errored"

# Refuse outside-namespace paths (safety)
(cd "$REPO" && "$WT" remove "/tmp" 2>/dev/null) \
  && fail "removed outside namespace" || pass "outside namespace refused"

rm -rf "$REPO"

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
