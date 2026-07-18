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

# default 이름 = origin/HEAD basename (authoritative, 성공 시).
origin_head="$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null \
       | sed 's#^refs/remotes/origin/##' || true)"
def="$origin_head"
# origin/HEAD 부재(fresh clone / worktree)면 init.defaultBranch로 fallback. 그래도
# 모르면 아래 공통-default 리터럴(main/master/develop/trunk)로 fail-closed —
# origin/HEAD unset + default가 develop/trunk인 리포에서 protected 브랜치에 자율
# 커밋되던 fail-open을 닫는다. (리터럴 열거는 커스텀 default 이름을 못 잡을 수
# 있어, origin/HEAD 미확인 시 loud warn으로 잔여 위험을 노출한다.)
if [ -z "$def" ]; then
  def="$(git config init.defaultBranch 2>/dev/null || true)"
fi

if { [ -n "$def" ] && [ "$branch" = "$def" ]; } \
   || [ "$branch" = "main" ] || [ "$branch" = "master" ] \
   || [ "$branch" = "develop" ] || [ "$branch" = "trunk" ]; then
  echo "branch_ok: false"
  echo "reason: on_default_or_protected_branch"
  echo "branch: $branch"
  exit 0
fi

echo "branch_ok: true"
echo "branch: $branch"
# loud advisory (graceful-degrade, non-blocking): origin/HEAD가 미확인이라 default를
# authoritative하게 못 정했다 — 리터럴 heuristic만 통과했으니, 사용자가 이 브랜치가
# 자신의 protected mainline이 아님을 확인하도록 알린다. 정상 feature 브랜치를
# hard-reject하지 않으려는 균형(P8: security-load-bearing엔 결정론, 잔여엔 loud-log).
if [ -z "$origin_head" ]; then
  echo "warn: default_branch_unverified"
fi
exit 0
