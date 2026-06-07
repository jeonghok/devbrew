#!/usr/bin/env bash
# check-review-scope.sh — read-only deterministic scope signal for the Review gate.
# (design v2.6.0 §5.1) Single responsibility: "Is the resolved review scope empty
# while there are changes that warrant review?" — the false-clean detector.
#
# Inputs:
#   $1                       — scope mode: session | branch | paths   (default: session)
#   $2..                     — glob list (paths mode only)
#   $CLAUDE_CODE_SESSION_ID  — locates .claude/quality-gates/<sid>/files.md (session mode)
#
# Output (structured stdout, consumed by SKILL.md):
#   resolved_count: <N>
#   branch_ahead_count: <M>
#   worktree_dirty: yes|no
#   base: <branch-name|->
#   signal: empty_scope_with_changes | normal | genuine_noop | degraded
#
# Exit code: always 0 (signal: degraded carries the fail-open state — C5).
# Read-only: never creates/modifies/deletes files (C4). Invoke from project root.

set -u   # NOT -e: graceful degradation, like detect-runtime.sh.

mode="${1:-session}"
shift || true
globs=("$@")

emit_degraded() {
  echo "resolved_count: 0"
  echo "branch_ahead_count: 0"
  echo "worktree_dirty: no"
  echo "base: -"
  echo "signal: degraded"
  exit 0
}

# --- git sanity (fail-open on anything uncertain — C5) ---
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || emit_degraded
git rev-parse --verify --quiet HEAD >/dev/null 2>&1 || emit_degraded
# detached HEAD → no branch context to compare → degraded.
git symbolic-ref --quiet HEAD >/dev/null 2>&1 || emit_degraded

# --- base resolution (single source of truth — C6). All existence checks use
#     `git rev-parse --verify --quiet` for consistent local/remote handling. ---
base=""
if ref=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null); then
  base="${ref#origin/}"
elif git rev-parse --verify --quiet refs/remotes/origin/main >/dev/null 2>&1; then
  base="main"
elif git rev-parse --verify --quiet refs/remotes/origin/master >/dev/null 2>&1; then
  base="master"
elif git rev-parse --verify --quiet refs/heads/main >/dev/null 2>&1; then
  base="main"
elif git rev-parse --verify --quiet refs/heads/master >/dev/null 2>&1; then
  base="master"
else
  emit_degraded
fi

merge_base=$(git merge-base "$base" HEAD 2>/dev/null) || emit_degraded
[[ -n "$merge_base" ]] || emit_degraded

branch_ahead_count=$(git diff --name-only "$merge_base"..HEAD 2>/dev/null | wc -l | tr -d ' ')

# --- worktree_dirty: tracked changes OR non-ignored untracked.
#     --exclude-standard is intentional (NG4): .gitignore'd build artifacts must
#     NOT count as "changes" and false-trip empty_scope_with_changes. ---
worktree_dirty="no"
if [[ -n "$(git diff HEAD --name-only 2>/dev/null)" ]]; then
  worktree_dirty="yes"
elif [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]]; then
  worktree_dirty="yes"
fi

# --- resolved_count per mode ---
resolved_count=0
case "$mode" in
  session)
    sid="${CLAUDE_CODE_SESSION_ID:-}"
    files_md=".claude/quality-gates/$sid/files.md"
    if [[ -n "$sid" && -f "$files_md" ]]; then
      # files.md entries are markdown list items "- <path>" (session-tracker hook).
      resolved_count=$(grep -cE '^- ' "$files_md" 2>/dev/null)
      resolved_count=${resolved_count:-0}
    fi
    ;;
  branch)
    resolved_count="$branch_ahead_count"
    ;;
  paths)
    if [[ ${#globs[@]} -gt 0 ]]; then
      # glob matches that ALSO appear in `git diff HEAD` (changed-and-matched),
      # not bare glob membership.
      resolved_count=$(git diff HEAD --name-only -- "${globs[@]}" 2>/dev/null | wc -l | tr -d ' ')
    fi
    ;;
  *)
    emit_degraded
    ;;
esac

# --- changes_exist + signal decision ---
changes_exist="no"
if [[ "$branch_ahead_count" -gt 0 || "$worktree_dirty" == "yes" ]]; then
  changes_exist="yes"
fi

if [[ "$resolved_count" -gt 0 ]]; then
  signal="normal"
elif [[ "$changes_exist" == "yes" ]]; then
  signal="empty_scope_with_changes"
else
  signal="genuine_noop"
fi

echo "resolved_count: $resolved_count"
echo "branch_ahead_count: $branch_ahead_count"
echo "worktree_dirty: $worktree_dirty"
echo "base: $base"
echo "signal: $signal"
exit 0
