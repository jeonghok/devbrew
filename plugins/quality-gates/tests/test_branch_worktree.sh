#!/usr/bin/env bash
# Integration tests for /qg branch <name> auto-worktree (AC1–AC11).
set -u

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETUP="$PLUGIN_DIR/scripts/setup-qg.sh"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

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
[ -f "$state" ] && ok "state file created" || no "state file not created"
grep -q '^worktree_path:' "$state" \
  && no "worktree_path set in legacy mode" \
  || ok "no worktree_path in legacy mode"
[ -d "$REPO/.claude/quality-gates/worktrees" ] \
  && no "worktree dir created in legacy mode" \
  || ok "no worktree dir in legacy mode"
rm -rf "$REPO"

# --- AC2: /qg branch <name> creates worktree, records worktree_path + target_branch ---
# (project_dir field was removed from state schema in v1.32.0 minimal-state
# refactor — worktree_path itself is the user-visible invariant.)
echo "[AC2] /qg branch <name> happy path"
REPO=$(make_repo feat-b)
(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac2session12 "$SETUP" branch feat-b >/dev/null)
state="$REPO/.claude/quality-gates/ac2session12/pipeline.md"
[ -f "$state" ] && ok "state file in main repo" || no "state file not created"
wpath=$(awk -F'"' '/^worktree_path:/{print $2}' "$state")
[ -n "$wpath" ] && [ -d "$wpath" ] && ok "worktree_path exists" \
  || no "worktree_path missing or invalid: $wpath"
tb=$(awk -F'"' '/^target_branch:/{print $2}' "$state")
[ "$tb" = "feat-b" ] && ok "target_branch recorded" \
  || no "target_branch wrong: $tb"
rm -rf "$REPO"

# --- AC3: nonexistent branch ---
echo "[AC3] nonexistent branch"
REPO=$(make_repo feat-c)
out=$(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac3session12 \
        "$SETUP" branch noexist 2>&1 >/dev/null) || true
[ ! -f "$REPO/.claude/quality-gates/ac3session12/pipeline.md" ] \
  && ok "no state file on failure" \
  || no "state file leaked"
echo "$out" | grep -qi "not found\|failed" \
  && ok "error message present" \
  || no "no error message: $out"
rm -rf "$REPO"

# --- AC4: path traversal in name ---
echo "[AC4] path traversal name"
REPO=$(make_repo feat-d)
out=$(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac4session12 \
        "$SETUP" branch ../evil 2>&1 >/dev/null) || true
echo "$out" | grep -qi "invalid\|dotdot\|sanitize\|not found\|failed" \
  && ok "rejected with message" \
  || no "no error message: $out"
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
[ "$wpath1" = "$wpath2" ] && [ -n "$wpath1" ] && ok "same worktree path" \
  || no "paths differ: $wpath1 vs $wpath2"
grep -q "reusing existing" "$REPO/stderr.txt" \
  && ok "reuse message logged" \
  || no "no reuse message in stderr"
rm -rf "$REPO"

# --- AC9: kill switch ---
echo "[AC9] DEVBREW_QUALITY_GATES_DISABLE_BRANCH_WORKTREE=1"
REPO=$(make_repo feat-f)
out=$(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac9session12 \
        DEVBREW_QUALITY_GATES_DISABLE_BRANCH_WORKTREE=1 \
        "$SETUP" branch feat-f 2>&1 >/dev/null) || true
echo "$out" | grep -qi "disabled" \
  && ok "kill switch message" \
  || no "no kill switch message: $out"
[ ! -f "$REPO/.claude/quality-gates/ac9session12/pipeline.md" ] \
  && ok "kill switch prevented state" \
  || no "state created despite kill switch"
# Legacy /qg branch (no name) still works under the kill switch
(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac9bsession \
   DEVBREW_QUALITY_GATES_DISABLE_BRANCH_WORKTREE=1 \
   "$SETUP" branch >/dev/null) \
  && ok "kill switch does not affect legacy /qg branch" \
  || no "kill switch killed legacy mode"
rm -rf "$REPO"

# --- AC6: terminal status removes worktree (AskUserQuestion-cleanup simulation) ---
echo "[AC6] cleanup on complete"
REPO=$(make_repo feat-g)
(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac6sess1234567 "$SETUP" branch feat-g >/dev/null)
state="$REPO/.claude/quality-gates/ac6sess1234567/pipeline.md"
wpath=$(awk -F'"' '/^worktree_path:/{print $2}' "$state")
# v1.32.0: SKILL's terminal status path triggers qg-worktree.sh remove via
# /cancel-qg or SessionEnd cleanup; simulate that by calling remove directly.
(cd "$REPO" && "$PLUGIN_DIR/scripts/qg-worktree.sh" remove "$wpath")
[ ! -d "$wpath" ] && ok "worktree removed on cleanup" \
  || no "worktree remains: $wpath"
rm -rf "$REPO"

# --- AC7: /cancel-qg removes worktree (same path) ---
echo "[AC7] cleanup on cancel"
# /cancel-qg internally clears state + would trigger same removal. Test that
# qg-worktree.sh remove is idempotent and works on the cancel path symmetrically.
REPO=$(make_repo feat-h)
(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac7sess1234567 "$SETUP" branch feat-h >/dev/null)
wpath=$(awk -F'"' '/^worktree_path:/{print $2}' "$REPO/.claude/quality-gates/ac7sess1234567/pipeline.md")
(cd "$REPO" && "$PLUGIN_DIR/scripts/qg-worktree.sh" remove "$wpath")
[ ! -d "$wpath" ] && ok "cancel cleanup symmetric" \
  || no "cancel cleanup failed: $wpath"
rm -rf "$REPO"

# --- AC10: DEVBREW_QUALITY_GATES_KEEP_WORKTREE documented somewhere ---
echo "[AC10] KEEP_WORKTREE documentation"
# AC10 end-to-end behavior (KEEP env actually preserves worktree at
# terminal status) was previously verified in test_stop_hook_worktree_cleanup.py,
# which was removed alongside the Stop hook in v1.32.0. Behavioral coverage
# moves to /cancel-qg + SessionEnd cleanup paths.
# Here we just assert documentation exists somewhere users can find:
# either in setup-qg.sh --help, or in README, or in commands/qg.md.
found=0
"$SETUP" --help 2>&1 | grep -qi "KEEP_WORKTREE" && found=1
grep -qi "KEEP_WORKTREE" "$PLUGIN_DIR/README.md" 2>/dev/null && found=1
grep -qi "KEEP_WORKTREE" "$PLUGIN_DIR/commands/qg.md" 2>/dev/null && found=1
[ "$found" -eq 1 ] \
  && ok "DEVBREW_QUALITY_GATES_KEEP_WORKTREE documented" \
  || no "DEVBREW_QUALITY_GATES_KEEP_WORKTREE not documented anywhere"

# --- AC11: working tree non-interference ---
echo "[AC11] working-tree non-interference"
REPO=$(make_repo feat-i)
(cd "$REPO" && echo "wip" > wip.txt)  # uncommitted change in main repo
(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac11sess123456 "$SETUP" branch feat-i >/dev/null)
# wip.txt must still be present (setup must not touch pre-existing untracked files)
[ -f "$REPO/wip.txt" ] && [ "$(cat "$REPO/wip.txt")" = "wip" ] \
  && ok "working tree unchanged" \
  || no "wip.txt was modified or removed"
[ "$(cd "$REPO" && git rev-parse --abbrev-ref HEAD)" = "main" ] \
  && ok "still on main branch" \
  || no "branch changed"
rm -rf "$REPO"

# (AC8 was covered by test_stop_hook_worktree_cleanup.py, removed in
#  v1.32.0 along with the Stop hook itself. AC12 remains exercised here
#  via the AC2 worktree_path frontmatter assertion.)
finish
