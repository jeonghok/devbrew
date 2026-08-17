#!/usr/bin/env bash
# Unit tests for qg-worktree.sh subcommands.
# Each test calls the script with stdin/args and asserts stdout/exit code.
set -u

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WT="$PLUGIN_DIR/scripts/qg-worktree.sh"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# --- sanitize ---
echo "[sanitize]"

out=$("$WT" sanitize "feat/x" 2>/dev/null) && [ "$out" = "feat-x" ] \
  && ok "slash to dash" || no "slash to dash got: $out"

out=$("$WT" sanitize "main" 2>/dev/null) && [ "$out" = "main" ] \
  && ok "plain name passthrough" || no "plain got: $out"

"$WT" sanitize "../evil" >/dev/null 2>&1 && no "dotdot accepted" \
  || ok "dotdot rejected"

"$WT" sanitize ".hidden" >/dev/null 2>&1 && no "leading dot accepted" \
  || ok "leading dot rejected"

"$WT" sanitize "with space" >/dev/null 2>&1 && no "space accepted" \
  || ok "space rejected"

long=$(printf 'a%.0s' {1..65})
"$WT" sanitize "$long" >/dev/null 2>&1 && no "65 chars accepted" \
  || ok "length cap enforced"

# --- validate-branch ---
echo "[validate-branch]"

REPO=$(mktemp -d)
(cd "$REPO" && git init -q -b main && git config user.email t@t && \
  git config user.name t && git commit -q --allow-empty -m init && \
  git branch real-branch)

(cd "$REPO" && "$WT" validate-branch real-branch) \
  && ok "existing branch ok" || no "existing branch rejected"

(cd "$REPO" && "$WT" validate-branch nonexistent 2>/dev/null) \
  && no "nonexistent accepted" || ok "nonexistent rejected"

# Regression: tag is not a branch
(cd "$REPO" && git tag v1) >/dev/null
(cd "$REPO" && "$WT" validate-branch v1 2>/dev/null) \
  && no "tag accepted as branch" || ok "tag rejected"

rm -rf "$REPO"

# --- create ---
echo "[create]"

REPO=$(mktemp -d)
(cd "$REPO" && git init -q -b main && git config user.email t@t && \
  git config user.name t && git commit -q --allow-empty -m init && \
  git branch feat-x)

SID="abcdef12345678"
WTPATH=$(cd "$REPO" && "$WT" create feat-x "$SID" 2>/dev/null)
[ -d "$WTPATH" ] && ok "create returns valid path" \
  || no "create path missing: $WTPATH"

[ "$(cd "$WTPATH" && git rev-parse HEAD)" = \
  "$(cd "$REPO" && git rev-parse feat-x)" ] \
  && ok "worktree HEAD matches branch" || no "HEAD mismatch"

# Detached HEAD check
sym=$(cd "$WTPATH" && git symbolic-ref -q HEAD 2>/dev/null || echo "")
[ -z "$sym" ] && ok "detached HEAD" || no "not detached: $sym"

# Idempotent reuse
WTPATH2=$(cd "$REPO" && "$WT" create feat-x "$SID" 2>/dev/null)
[ "$WTPATH" = "$WTPATH2" ] && ok "idempotent reuse" \
  || no "second create differs"

# Kill switch
( cd "$REPO" && DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1 \
    "$WT" create feat-x "killtest-$SID" 2>/dev/null ) \
  && no "kill switch ignored" || ok "kill switch honored"

# Regression: branch with dot in name doesn't cause grep false positive
(cd "$REPO" && git branch release-1.0) >/dev/null
WTPATH3=$(cd "$REPO" && "$WT" create release-1.0 "dotsid12345678" 2>/dev/null)
[ -d "$WTPATH3" ] && [ "$WTPATH3" != "$WTPATH" ] \
  && ok "dot in branch name doesn't collide" \
  || no "dot regression: $WTPATH3 vs $WTPATH"

rm -rf "$REPO"

# --- remove ---
echo "[remove]"

REPO=$(mktemp -d)
(cd "$REPO" && git init -q -b main && git config user.email t@t && \
  git config user.name t && git commit -q --allow-empty -m init && \
  git branch feat-y)
WTPATH=$(cd "$REPO" && "$WT" create feat-y "remove-test12345" 2>/dev/null)
[ -d "$WTPATH" ] || { no "create precondition"; }

(cd "$REPO" && "$WT" remove "$WTPATH") \
  && [ ! -d "$WTPATH" ] && ok "remove deletes dir" \
  || no "remove failed or dir remains"

# Remove a nonexistent path → exit 0 (best-effort)
(cd "$REPO" && "$WT" remove "$REPO/.claude/quality-gates/worktrees/missing-12345678") \
  && ok "remove missing is noop" || no "remove missing errored"

# Refuse outside-namespace paths (safety)
(cd "$REPO" && "$WT" remove "/tmp" 2>/dev/null) \
  && no "removed outside namespace" || ok "outside namespace refused"

rm -rf "$REPO"
finish
