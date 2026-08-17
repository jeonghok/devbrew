#!/usr/bin/env bash
# T2/AC8 — branch safety. fixture: origin/HEAD 유/무 + detached, 각 거부/진행 결정론.
set -u
SCRIPT="$(cd "$(dirname "$0")/../scripts" && pwd)/artifact_branch_guard.sh"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
mkrepo() { # -> echoes new repo dir on a fresh feature branch
  local d; d="$(mktemp -d)"; ( cd "$d"
    git init -q; git config user.email t@t; git config user.name t
    git commit -q --allow-empty -m init
    git branch -m feature/x ) ; echo "$d"; }

# Case A: feature 브랜치 + origin/HEAD=main -> 진행
d="$(mkrepo)"; ( cd "$d"; git update-ref refs/remotes/origin/main HEAD 2>/dev/null || true
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main )
out="$(cd "$d" && bash "$SCRIPT")"
[ "$(field branch_ok "$out")" = "true" ] && ok "feature branch allowed" \
  || no "feature branch should be allowed ($out)"
rm -rf "$d"

# Case B: main 브랜치 -> 거부 (origin/HEAD 유무 무관: 리터럴 fallback)
d="$(mktemp -d)"; ( cd "$d"; git init -q; git config user.email t@t; git config user.name t
  git commit -q --allow-empty -m init; git branch -m main )
out="$(cd "$d" && bash "$SCRIPT")"
[ "$(field branch_ok "$out")" = "false" ] && ok "main rejected" \
  || no "main should be rejected ($out)"
rm -rf "$d"

# Case C: master (리터럴 fallback, origin/HEAD 없음) -> 거부
d="$(mktemp -d)"; ( cd "$d"; git init -q; git config user.email t@t; git config user.name t
  git commit -q --allow-empty -m init; git branch -m master )
out="$(cd "$d" && bash "$SCRIPT")"
[ "$(field branch_ok "$out")" = "false" ] && ok "master rejected" \
  || no "master should be rejected ($out)"
rm -rf "$d"

# Case D: detached HEAD -> 거부 (fail-closed)
d="$(mkrepo)"; ( cd "$d"; git commit -q --allow-empty -m second
  git checkout -q "$(git rev-parse HEAD)" )
out="$(cd "$d" && bash "$SCRIPT")"
[ "$(field reason "$out")" = "detached_head" ] && [ "$(field branch_ok "$out")" = "false" ] \
  && ok "detached rejected" \
  || no "detached should be rejected ($out)"
rm -rf "$d"

# Case E (F-E): default branch named `develop`, origin/HEAD UNSET -> rejected
# fail-closed via the common-default literal list. Pre-fix this was ALLOWED
# (branch != main/master) -> autonomous commits on the protected mainline.
d="$(mktemp -d)"; ( cd "$d"; git init -q; git config user.email t@t; git config user.name t
  git commit -q --allow-empty -m init; git branch -m develop )
out="$(cd "$d" && bash "$SCRIPT")"
[ "$(field branch_ok "$out")" = "false" ] && ok "develop (origin/HEAD unset) rejected fail-closed" \
  || no "develop should be rejected ($out)"
rm -rf "$d"

# Case F (F-E): feature branch with origin/HEAD UNSET -> allowed BUT a loud warn
# so the user can confirm it isn't their (custom-named) protected mainline.
d="$(mktemp -d)"; ( cd "$d"; git init -q; git config user.email t@t; git config user.name t
  git commit -q --allow-empty -m init; git branch -m feature/y )
out="$(cd "$d" && bash "$SCRIPT")"
[ "$(field branch_ok "$out")" = "true" ] && [ "$(field warn "$out")" = "default_branch_unverified" ] \
  && ok "origin/HEAD unset -> allowed + loud warn" \
  || no "unset origin/HEAD should warn ($out)"
rm -rf "$d"

# project_dir emitted
d="$(mkrepo)"; out="$(cd "$d" && bash "$SCRIPT")"
[ -n "$(field project_dir "$out")" ] && ok "project_dir emitted" \
  || no "project_dir missing ($out)"
rm -rf "$d"

finish
