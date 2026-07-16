#!/usr/bin/env bash
# artifact_branch_guard.sh — E2 branch safety (§8, C4, AC8). Run in project_dir (cwd).
# Rejects autonomous commits on the default/protected branch or in detached HEAD.
# fail-closed: ambiguity (detached HEAD) -> reject. Exit 0 always (advisory emit).
# Also emits project_dir so the SKILL freezes the coordinate without re-resolving.
set -u

echo "project_dir: $(pwd -P)"

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
if [ -z "$branch" ]; then
  echo "branch_ok: false"
  echo "reason: detached_head"
  exit 0
fi

# default 이름 = origin/HEAD basename (성공 시); 실패 시 리터럴 main/master fallback.
def="$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null \
       | sed 's#^refs/remotes/origin/##' || true)"

if { [ -n "$def" ] && [ "$branch" = "$def" ]; } \
   || [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
  echo "branch_ok: false"
  echo "reason: on_default_or_protected_branch"
  echo "branch: $branch"
  exit 0
fi

echo "branch_ok: true"
echo "branch: $branch"
exit 0
