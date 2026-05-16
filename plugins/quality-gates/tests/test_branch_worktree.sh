#!/usr/bin/env bash
# Integration tests for /qg branch <name> auto-worktree (AC1–AC11).
set -u

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETUP="$PLUGIN_DIR/scripts/setup-qg.sh"

PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }

make_repo() {
  local root branch="$1"
  root=$(mktemp -d)
  (
    cd "$root"
    git init -q -b main
    git config user.email t@t
    git config user.name t
    git commit -q --allow-empty -m init
    git branch "$branch"
  )
  echo "$root"
}

# --- AC1: /qg branch (no name) regression — must not create worktree ---
echo "[AC1] /qg branch (no name) — backward compat"
REPO=$(make_repo feat-a)
(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac1session12 "$SETUP" branch >/dev/null)
state="$REPO/.claude/quality-gates/ac1session12/pipeline.md"
[ -f "$state" ] && pass "state file created" || fail "state file not created"
grep -q '^worktree_path:' "$state" \
  && fail "worktree_path set in legacy mode" \
  || pass "no worktree_path in legacy mode"
[ -d "$REPO/.claude/quality-gates/worktrees" ] \
  && fail "worktree dir created in legacy mode" \
  || pass "no worktree dir in legacy mode"
rm -rf "$REPO"

# --- AC2: /qg branch <name> creates worktree, sets project_dir ---
echo "[AC2] /qg branch <name> happy path"
REPO=$(make_repo feat-b)
(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac2session12 "$SETUP" branch feat-b >/dev/null)
state="$REPO/.claude/quality-gates/ac2session12/pipeline.md"
[ -f "$state" ] && pass "state file in main repo" || fail "state file not created"
wpath=$(awk -F'"' '/^worktree_path:/{print $2}' "$state")
[ -n "$wpath" ] && [ -d "$wpath" ] && pass "worktree_path exists" \
  || fail "worktree_path missing or invalid: $wpath"
pdir=$(awk -F'"' '/^project_dir:/{print $2}' "$state")
[ "$pdir" = "$wpath" ] && pass "project_dir = worktree path" \
  || fail "project_dir != worktree ($pdir vs $wpath)"
tb=$(awk -F'"' '/^target_branch:/{print $2}' "$state")
[ "$tb" = "feat-b" ] && pass "target_branch recorded" \
  || fail "target_branch wrong: $tb"
rm -rf "$REPO"

# (AC3–AC11 appended in later tasks)

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
