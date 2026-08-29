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

# --- baseline resolution은 resolve-baseline.sh가 단독 소유 (design §5.2 R-init).
#     git sanity(비-git/HEAD 부재/detached/shallow) + base 후보 순서 + merge-base가
#     전부 그 스크립트 안에 있고, 이 스크립트는 4키를 읽어 fail-open 판정만 승계한다.
#     여기서 로직을 복제하면 두 소비자가 서로 다른 baseline을 보게 된다 (C2 재발). ---
_rb_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
_rb_out=$("$_rb_dir/resolve-baseline.sh" 2>/dev/null) || emit_degraded
_rb_field() { printf '%s\n' "$_rb_out" | awk -v k="$1:" '$1 == k { print $2 }'; }
[[ "$(_rb_field degraded)" == "no" ]] || emit_degraded
base=$(_rb_field base)
merge_base=$(_rb_field merge_base)
[[ -n "$base" && -n "$merge_base" && "$merge_base" != "-" ]] || emit_degraded

# branch_ahead_count is a CHANGED-FILE count (NOT a commit count): the number of
# files differing between merge_base and HEAD.
#
# This value MUST NOT become the SKILL's $resolved_scope_file_count. That equation was
# a CRITICAL caught in review (CHANGELOG [5.0.0] "Changed"; SKILL Step 4.5
# "Resolved-scope file count"): the honest-verdict floor keys on
# `resolved_scope_file_count == 0 AND changes_exist == yes`, so if the count were read
# off THIS script both operands would share one source, could never disagree, and the
# floor's first branch would be unreachable — disarmed for the default mode. The two
# operands stay independently computed: this script emits changes_exist; the count is
# the size of the file set the orchestrator actually resolved and reviewed at Step 1.
#
# Capture via a DIRECT assignment (not a
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
