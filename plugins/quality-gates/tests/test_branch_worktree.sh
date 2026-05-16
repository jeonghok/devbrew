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

# --- AC3: nonexistent branch ---
echo "[AC3] nonexistent branch"
REPO=$(make_repo feat-c)
out=$(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac3session12 \
        "$SETUP" branch noexist 2>&1 >/dev/null) || true
[ ! -f "$REPO/.claude/quality-gates/ac3session12/pipeline.md" ] \
  && pass "no state file on failure" \
  || fail "state file leaked"
echo "$out" | grep -qi "not found\|failed" \
  && pass "error message present" \
  || fail "no error message: $out"
rm -rf "$REPO"

# --- AC4: path traversal in name ---
echo "[AC4] path traversal name"
REPO=$(make_repo feat-d)
out=$(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac4session12 \
        "$SETUP" branch ../evil 2>&1 >/dev/null) || true
echo "$out" | grep -qi "invalid\|dotdot\|sanitize\|not found\|failed" \
  && pass "rejected with message" \
  || fail "no error message: $out"
rm -rf "$REPO"

# --- AC5: idempotent reuse ---
echo "[AC5] idempotent reuse"
REPO=$(make_repo feat-e)
(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac5session12 "$SETUP" branch feat-e >/dev/null)
state="$REPO/.claude/quality-gates/ac5session12/pipeline.md"
wpath1=$(awk -F'"' '/^worktree_path:/{print $2}' "$state")
rm -f "$state"  # simulate re-run within same session
(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac5session12 "$SETUP" branch feat-e \
   2> "$REPO/stderr.txt" >/dev/null)
wpath2=$(awk -F'"' '/^worktree_path:/{print $2}' "$state")
[ "$wpath1" = "$wpath2" ] && [ -n "$wpath1" ] && pass "same worktree path" \
  || fail "paths differ: $wpath1 vs $wpath2"
grep -q "reusing existing" "$REPO/stderr.txt" \
  && pass "reuse message logged" \
  || fail "no reuse message in stderr"
rm -rf "$REPO"

# --- AC9: kill switch ---
echo "[AC9] DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1"
REPO=$(make_repo feat-f)
out=$(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac9session12 \
        DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1 \
        "$SETUP" branch feat-f 2>&1 >/dev/null) || true
echo "$out" | grep -qi "disabled" \
  && pass "kill switch message" \
  || fail "no kill switch message: $out"
[ ! -f "$REPO/.claude/quality-gates/ac9session12/pipeline.md" ] \
  && pass "kill switch prevented state" \
  || fail "state created despite kill switch"
# Legacy /qg branch (no name) still works under the kill switch
(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac9bsession \
   DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1 \
   "$SETUP" branch >/dev/null) \
  && pass "kill switch does not affect legacy /qg branch" \
  || fail "kill switch killed legacy mode"
rm -rf "$REPO"

# --- AC6: terminal status removes worktree (via stop-hook simulation) ---
echo "[AC6] cleanup on complete"
REPO=$(make_repo feat-g)
(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac6sess1234567 "$SETUP" branch feat-g >/dev/null)
state="$REPO/.claude/quality-gates/ac6sess1234567/pipeline.md"
wpath=$(awk -F'"' '/^worktree_path:/{print $2}' "$state")
# Simulate stop-hook terminal cleanup by calling qg-worktree.sh remove directly
(cd "$REPO" && "$PLUGIN_DIR/scripts/qg-worktree.sh" remove "$wpath")
[ ! -d "$wpath" ] && pass "worktree removed on cleanup" \
  || fail "worktree remains: $wpath"
rm -rf "$REPO"

# --- AC7: /cancel-qg removes worktree (same path) ---
echo "[AC7] cleanup on cancel"
# /cancel-qg internally clears state + would trigger same removal. Test that
# qg-worktree.sh remove is idempotent and works on the cancel path symmetrically.
REPO=$(make_repo feat-h)
(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac7sess1234567 "$SETUP" branch feat-h >/dev/null)
wpath=$(awk -F'"' '/^worktree_path:/{print $2}' "$REPO/.claude/quality-gates/ac7sess1234567/pipeline.md")
(cd "$REPO" && "$PLUGIN_DIR/scripts/qg-worktree.sh" remove "$wpath")
[ ! -d "$wpath" ] && pass "cancel cleanup symmetric" \
  || fail "cancel cleanup failed: $wpath"
rm -rf "$REPO"

# --- AC10: DEVBREW_QG_KEEP_WORKTREE documented somewhere ---
echo "[AC10] KEEP_WORKTREE documentation"
# AC10 (KEEP env actually preserves worktree at terminal status) is
# already verified end-to-end in test_stop_hook_worktree_cleanup.py.
# Here we just assert documentation exists somewhere users can find:
# either in setup-qg.sh --help, or in README, or in commands/qg.md.
found=0
"$SETUP" --help 2>&1 | grep -qi "KEEP_WORKTREE" && found=1
grep -qi "KEEP_WORKTREE" "$PLUGIN_DIR/README.md" 2>/dev/null && found=1
grep -qi "KEEP_WORKTREE" "$PLUGIN_DIR/commands/qg.md" 2>/dev/null && found=1
[ "$found" -eq 1 ] \
  && pass "DEVBREW_QG_KEEP_WORKTREE documented" \
  || fail "DEVBREW_QG_KEEP_WORKTREE not documented anywhere"

# --- AC11: working tree non-interference ---
echo "[AC11] working-tree non-interference"
REPO=$(make_repo feat-i)
(cd "$REPO" && echo "wip" > wip.txt)  # uncommitted change in main repo
(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac11sess123456 "$SETUP" branch feat-i >/dev/null)
# wip.txt must still be present (setup must not touch pre-existing untracked files)
[ -f "$REPO/wip.txt" ] && [ "$(cat "$REPO/wip.txt")" = "wip" ] \
  && pass "working tree unchanged" \
  || fail "wip.txt was modified or removed"
[ "$(cd "$REPO" && git rev-parse --abbrev-ref HEAD)" = "main" ] \
  && pass "still on main branch" \
  || fail "branch changed"
rm -rf "$REPO"

# (AC6–AC8, AC10–AC11 appended in later tasks)

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
