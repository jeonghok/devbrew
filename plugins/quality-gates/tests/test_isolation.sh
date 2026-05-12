#!/usr/bin/env bash
# Isolation tests: verify quality-gates state has no cross-talk between
#   (A) a worktree and its origin repo, when they share a session ID
#   (B) two sessions running in the same directory with different SIDs
#
# Mirrors test_setup_qg.sh style; mktemp + HOME override for hermetic runs.

set -u

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETUP="$PLUGIN_DIR/scripts/setup-qg.sh"

PASS=0
FAIL=0

note() { echo "  → $1"; }
pass() { PASS=$((PASS+1)); note "PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }

make_repo_with_worktree() {
  local root branch
  root=$(mktemp -d)
  branch="wt-$$-$RANDOM"
  (
    cd "$root"
    mkdir repo
    cd repo
    git init -q -b main
    git config user.email "test@example.com"
    git config user.name "test"
    echo "# scratch" > README.md
    git add README.md
    git commit -q -m "init"
    git worktree add -q -b "$branch" "$root/worktree" main
  )
  printf '%s|%s|%s\n' "$root/repo" "$root/worktree" "$branch"
}

inode_of() {
  stat -f %i "$1" 2>/dev/null || stat -c %i "$1" 2>/dev/null
}

# ============================================================
# Section A: Worktree ↔ origin repo isolation under shared SID
# ============================================================

# --- T1: worktree setup(SID) then origin setup(SID) → both succeed ---
IFS='|' read -r REPO WT BRANCH < <(make_repo_with_worktree)
unset CLAUDE_CODE_SESSION_ID
SID="isoshared01"

(cd "$WT"   && HOME="$WT"   "$SETUP" --session-id "$SID" >/dev/null 2>&1)
RC_WT=$?
(cd "$REPO" && HOME="$REPO" "$SETUP" --session-id "$SID" >/dev/null 2>&1)
RC_REPO=$?

WT_FILE="$WT/.claude/quality-gates/$SID/pipeline.md"
REPO_FILE="$REPO/.claude/quality-gates/$SID/pipeline.md"

[[ "$RC_WT" -eq 0 && -f "$WT_FILE" ]] && pass "T1a: worktree setup ok" || fail "T1a: worktree setup failed (rc=$RC_WT)"
[[ "$RC_REPO" -eq 0 && -f "$REPO_FILE" ]] \
  && pass "T1b: origin setup with same SID succeeded (origin did not see worktree state)" \
  || fail "T1b: origin setup failed (rc=$RC_REPO) — isolation broken"

WT_INODE=$(inode_of "$WT_FILE")
REPO_INODE=$(inode_of "$REPO_FILE")
if [[ -n "$WT_INODE" && -n "$REPO_INODE" && "$WT_INODE" != "$REPO_INODE" ]]; then
  pass "T1c: state files are physically distinct (inodes differ)"
else
  fail "T1c: state files share inode or could not be read"
fi

rm -rf "$(dirname "$REPO")"

# --- T2: reverse order — origin first, then worktree ---
IFS='|' read -r REPO WT BRANCH < <(make_repo_with_worktree)
SID="isoshared02"

(cd "$REPO" && HOME="$REPO" "$SETUP" --session-id "$SID" >/dev/null 2>&1)
RC_REPO=$?
(cd "$WT"   && HOME="$WT"   "$SETUP" --session-id "$SID" >/dev/null 2>&1)
RC_WT=$?

[[ "$RC_REPO" -eq 0 ]] && pass "T2a: origin setup ok" || fail "T2a: origin setup failed"
[[ "$RC_WT" -eq 0 && -f "$WT/.claude/quality-gates/$SID/pipeline.md" ]] \
  && pass "T2b: worktree setup with same SID succeeded (worktree did not see origin state)" \
  || fail "T2b: worktree setup failed (rc=$RC_WT)"

rm -rf "$(dirname "$REPO")"

# --- T3: cancel (rm) in worktree does not affect origin state ---
IFS='|' read -r REPO WT BRANCH < <(make_repo_with_worktree)
SID="isoshared03"

(cd "$WT"   && HOME="$WT"   "$SETUP" --session-id "$SID" >/dev/null 2>&1)
(cd "$REPO" && HOME="$REPO" "$SETUP" --session-id "$SID" >/dev/null 2>&1)

# Simulate cancel-qg in worktree: rm -rf its own session folder
rm -rf "$WT/.claude/quality-gates/$SID"

if [[ ! -d "$WT/.claude/quality-gates/$SID" && -f "$REPO/.claude/quality-gates/$SID/pipeline.md" ]]; then
  pass "T3: worktree cancel left origin's pipeline.md intact"
else
  fail "T3: cancel affected origin state OR worktree state still present"
fi

rm -rf "$(dirname "$REPO")"

# ============================================================
# Section B: Two sessions in the same directory
# ============================================================

# --- T4: two different SIDs concurrently active ---
ROOT=$(mktemp -d)
cd "$ROOT"
git init -q -b main
git config user.email "test@example.com"
git config user.name "test"
echo "ok" > a.txt
git add a.txt
git commit -q -m "init"

SID_A="multiseska01"
SID_B="multiseskb01"
unset CLAUDE_CODE_SESSION_ID

HOME="$ROOT" "$SETUP" --session-id "$SID_A" >/dev/null 2>&1
RC_A=$?
HOME="$ROOT" "$SETUP" --session-id "$SID_B" >/dev/null 2>&1
RC_B=$?

FILE_A="$ROOT/.claude/quality-gates/$SID_A/pipeline.md"
FILE_B="$ROOT/.claude/quality-gates/$SID_B/pipeline.md"

[[ "$RC_A" -eq 0 && -f "$FILE_A" ]] && pass "T4a: SID_A setup ok" || fail "T4a: SID_A failed"
[[ "$RC_B" -eq 0 && -f "$FILE_B" ]] && pass "T4b: SID_B setup ok (concurrent)" || fail "T4b: SID_B failed"

if grep -q "session_id: \"$SID_A\"" "$FILE_A" 2>/dev/null \
   && grep -q "session_id: \"$SID_B\"" "$FILE_B" 2>/dev/null; then
  pass "T4c: each pipeline.md owns its session_id (no cross-contamination)"
else
  fail "T4c: session_id mismatch in one of the state files"
fi

# --- T5: cancel SID_A leaves SID_B intact ---
rm -rf "$ROOT/.claude/quality-gates/$SID_A"
if [[ ! -d "$ROOT/.claude/quality-gates/$SID_A" && -f "$FILE_B" ]]; then
  pass "T5: SID_B unaffected by SID_A cancel"
else
  fail "T5: SID_B state lost OR SID_A folder still present"
fi

# --- T6: same-SID re-invocation is rejected (per-session active boundary) ---
OUT=$(HOME="$ROOT" "$SETUP" --session-id "$SID_B" 2>&1)
RC=$?
if [[ "$RC" -ne 0 ]] && echo "$OUT" | grep -qi "already active"; then
  pass "T6: re-invocation rejected with 'already active' (rc=$RC)"
else
  fail "T6: re-invocation NOT rejected (rc=$RC, out=$OUT)"
fi

cd / && rm -rf "$ROOT"

# --- Summary ---
echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
