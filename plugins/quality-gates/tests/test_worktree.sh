#!/usr/bin/env bash
# Tests for quality-gates behavior inside a git worktree.
#
# Guards the structural property that state and discovery are PWD-relative,
# so a worktree run cannot leak into (or read from) its origin repo.
#
# Uses bash assertions; no external test framework. Mirrors test_setup_qg.sh
# style. All side effects are confined to a per-test mktemp dir which acts
# as both a throwaway git repo and a $HOME for legacy-fallback isolation.

set -u

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETUP="$PLUGIN_DIR/scripts/setup-qg.sh"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"


# Create an isolated repo + worktree pair, echo "<repo>|<worktree>|<branch>".
# Caller must remove the returned root manually (or trap-cleanup).
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

# --- Test 1: worktree setup writes state inside worktree, not origin repo ---
IFS='|' read -r REPO WT BRANCH < <(make_repo_with_worktree)
unset CLAUDE_CODE_SESSION_ID
SID="wt1session01"

(
  cd "$WT"
  HOME="$WT" "$SETUP" --session-id "$SID" >/dev/null 2>&1
)
RC=$?

if [[ "$RC" -eq 0 && -f "$WT/.claude/quality-gates/$SID/result.md" ]]; then
  ok "T1a: state file created inside worktree"
else
  no "T1a: state file missing in worktree (rc=$RC)"
fi

if [[ ! -d "$REPO/.claude/quality-gates/$SID" ]]; then
  ok "T1b: origin repo .claude untouched (no leakage from worktree)"
else
  no "T1b: LEAKAGE — origin repo has state for SID=$SID"
fi

if grep -q "session_id: \"$SID\"" "$WT/.claude/quality-gates/$SID/result.md" 2>/dev/null; then
  ok "T1c: state frontmatter carries correct session_id"
else
  no "T1c: state file missing session_id frontmatter"
fi

# 같은 SID 로 원 레포에서도 setup — worktree 의 상태가 원 레포를 막지 않는다.
(cd "$REPO" && HOME="$REPO" "$SETUP" --session-id "$SID" >/dev/null 2>&1)
RC_REPO=$?
WT_FILE="$WT/.claude/quality-gates/$SID/result.md"
REPO_FILE="$REPO/.claude/quality-gates/$SID/result.md"
if [[ "$RC_REPO" -eq 0 && -f "$REPO_FILE" ]]; then
  ok "T1d: 같은 SID 로 원 레포의 setup 도 된다(원 레포가 worktree 상태를 보지 않는다)"
else
  no "T1d: 같은 SID 로 원 레포의 setup 이 안 됐다(rc=$RC_REPO) — 격리가 깨졌다"
fi

WT_INODE=$(inode_of "$WT_FILE")
REPO_INODE=$(inode_of "$REPO_FILE")
if [[ -n "$WT_INODE" && -n "$REPO_INODE" && "$WT_INODE" != "$REPO_INODE" ]]; then
  ok "T1e: 두 상태 파일이 물리적으로 다르다(inode 다름)"
else
  no "T1e: 두 상태 파일이 inode 를 같이 쓰거나 읽을 수 없다"
fi

# 거꾸로 — 새 SID 로 원 레포 먼저, 그다음 worktree.
SID2="wt1session02"
(cd "$REPO" && HOME="$REPO" "$SETUP" --session-id "$SID2" >/dev/null 2>&1)
(cd "$WT" && HOME="$WT" "$SETUP" --session-id "$SID2" >/dev/null 2>&1)
RC_WT=$?
if [[ "$RC_WT" -eq 0 && -f "$WT/.claude/quality-gates/$SID2/result.md" ]]; then
  ok "T1f: 원 레포 먼저 돈 같은 SID 로 worktree 의 setup 도 된다(worktree 가 원 레포 상태를 보지 않는다)"
else
  no "T1f: 원 레포 먼저 돈 같은 SID 로 worktree 의 setup 이 안 됐다(rc=$RC_WT)"
fi

rm -rf "$(dirname "$REPO")"

# --- Test 8: agent.md Inputs contract drift guard (AC2, T8) ---
# T3-3: codex-reviewer.md deleted — removed from this loop (no longer applicable post-T3-3).
# T3-2: synthesizer.md deleted — removed from this loop (no longer applicable post-T3-2).
# T3-1: scout.md deleted — removed from this loop (no longer applicable post-T3-1).
# PR4a: adversarial.md deleted — removed from this loop. The re-critic is
# quality-gates:code-recritic (Step 3.5), which declares project_dir (checked below).
for agent in security-reviewer code-recritic; do
  if grep -q 'project_dir' "$PLUGIN_DIR/agents/$agent.md"; then
    ok "T8: agents/$agent.md declares project_dir input"
  else
    no "T8: agents/$agent.md missing project_dir input contract"
  fi
done

# --- Test 7: T3-3 — codex-reviewer.md deleted; script exists + uses CLAUDE_PLUGIN_ROOT ---
if [[ -f "$PLUGIN_DIR/agents/codex-reviewer.md" ]]; then
  no "T7: codex-reviewer.md should be absent post-T3-3"
elif grep -q '\$REPO_ROOT/plugins/quality-gates' "$PLUGIN_DIR/scripts/run_codex_reviewer.sh" 2>/dev/null; then
  no "T7: run_codex_reviewer.sh still references \$REPO_ROOT/plugins/quality-gates (breaks outside devbrew)"
else
  ok "T7: codex-reviewer migrated to script; script uses \${CLAUDE_PLUGIN_ROOT} (devbrew-portable)"
fi

# --- Test 9: REMOVED — v1.32.0 schema intentionally has no project_dir field ---
# project_dir is now a per-dispatch runtime parameter threaded by the SKILL
# (see T5), not a state-frontmatter field. The schema field was removed to
# avoid coordinate drift between worktree-mode and main-repo-mode pipelines.

# --- Summary ---
finish
