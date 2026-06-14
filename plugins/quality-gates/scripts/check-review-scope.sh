#!/usr/bin/env bash
# check-review-scope.sh — read-only deterministic CHANGES-EXIST signal for the
# Review gate's verdict-integrity floor (design v2.7.0 §5.2). Narrowed from v2.6.0:
# the single responsibility shrank from "is the resolved review scope empty while
# changes exist?" to "does this branch/worktree have changes?". Scope resolution
# (WHAT to review) is the MODEL's responsibility now; this script supplies only the
# load-bearing signal the SKILL Step 4.5 honest-verdict floor keys on, independent
# of any "clean" claim.
#
# Output (structured stdout, consumed by SKILL.md Step 1b → 4.5):
#   changes_exist: yes|no      # branch_ahead_count > 0 OR worktree_dirty == yes
#   branch_ahead_count: <M>    # CHANGED-FILE count on merge_base..HEAD (NOT commit count)
#   worktree_dirty: yes|no     # tracked diff OR non-ignored untracked
#   base: <name|->             # display name for the honest verdict message
#   degraded: yes|no           # fail-open marker (C2): cannot determine → floor not protected
#
# Exit code: always 0 (degraded: yes carries the fail-open state). Read-only:
# never creates/modifies/deletes files. Takes NO arguments. Invoke from project root.

set -u   # NOT -e: graceful degradation, like detect-runtime.sh.

emit_degraded() {
  echo "changes_exist: no"
  echo "branch_ahead_count: 0"
  echo "worktree_dirty: no"
  echo "base: -"
  echo "degraded: yes"
  exit 0
}

# --- git sanity (fail-open on anything uncertain — C2) ---
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || emit_degraded
git rev-parse --verify --quiet HEAD >/dev/null 2>&1 || emit_degraded
# detached HEAD → no branch context to compare → degraded.
git symbolic-ref --quiet HEAD >/dev/null 2>&1 || emit_degraded
# shallow clone → truncated history → merge-base may resolve to a grafted
# boundary commit (wrong count) instead of failing → degraded regardless (AC4;
# the SKILL degraded advisory lists shallow as a trigger, so the script must
# actually emit it). `--is-shallow-repository` (git ≥ 2.15) prints true|false;
# on older git it prints nothing → no false-degrade.
[[ "$(git rev-parse --is-shallow-repository 2>/dev/null)" == "true" ]] && emit_degraded

# --- base resolution. `base` is the human-readable DISPLAY short-name; `base_ref`
#     is the git-usable ref KNOWN to exist (may be a remote-tracking ref). Kept
#     separate so a remote-only default branch (origin/main with no local main —
#     fresh clone / CI checkout / worktree) does NOT make `git merge-base` fail and
#     fall open to degraded (F2 fix, preserved from v2.6.0). ---
base=""
base_ref=""
if ref=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null); then
  base="${ref#origin/}"; base_ref="$ref"
elif git rev-parse --verify --quiet refs/remotes/origin/main >/dev/null 2>&1; then
  base="main"; base_ref="origin/main"
elif git rev-parse --verify --quiet refs/remotes/origin/master >/dev/null 2>&1; then
  base="master"; base_ref="origin/master"
elif git rev-parse --verify --quiet refs/heads/main >/dev/null 2>&1; then
  base="main"; base_ref="main"
elif git rev-parse --verify --quiet refs/heads/master >/dev/null 2>&1; then
  base="master"; base_ref="master"
else
  emit_degraded
fi

merge_base=$(git merge-base "$base_ref" HEAD 2>/dev/null) || emit_degraded
[[ -n "$merge_base" ]] || emit_degraded

# branch_ahead_count is a CHANGED-FILE count (NOT a commit count): the number of
# files differing between merge_base and HEAD. The SKILL's branch-mode
# resolved_scope_file_count reuses this value. Capture via a DIRECT assignment (not a
# `git … | wc -l` pipe, whose exit status is wc's, swallowing git's) so a query failure
# fails OPEN to degraded — consistent with the C2 contract above. A silently-swallowed
# git error here would yield branch_ahead_count=0 + degraded=no = a FALSE-CLEAN, the
# exact state the floor exists to prevent.
branch_names=$(git diff --name-only "$merge_base"..HEAD 2>/dev/null) || emit_degraded
if [[ -z "$branch_names" ]]; then
  branch_ahead_count=0
else
  branch_ahead_count=$(printf '%s\n' "$branch_names" | wc -l | tr -d ' ')
fi

# --- worktree_dirty: tracked changes OR non-ignored untracked.
#     --exclude-standard is intentional (NG4): .gitignore'd build artifacts must
#     NOT count as "changes" and false-trip changes_exist. Both queries use a direct
#     assignment + `|| emit_degraded` so a git failure fails OPEN (C2), not fail-closed
#     to a false "no" via an empty `-n "$(…)"`. ---
tracked_changes=$(git diff HEAD --name-only 2>/dev/null) || emit_degraded
untracked_changes=$(git ls-files --others --exclude-standard 2>/dev/null) || emit_degraded
worktree_dirty="no"
if [[ -n "$tracked_changes" || -n "$untracked_changes" ]]; then
  worktree_dirty="yes"
fi

changes_exist="no"
if [[ "$branch_ahead_count" -gt 0 || "$worktree_dirty" == "yes" ]]; then
  changes_exist="yes"
fi

echo "changes_exist: $changes_exist"
echo "branch_ahead_count: $branch_ahead_count"
echo "worktree_dirty: $worktree_dirty"
echo "base: $base"
echo "degraded: no"
exit 0
