#!/usr/bin/env bash
# T2/AC8 — branch safety. fixture: origin/HEAD 유/무 + detached, 각 거부/진행 결정론.
set -u
SCRIPT="$(cd "$(dirname "$0")/../scripts" && pwd)/artifact_branch_guard.sh"
PASS=0; FAIL=0
field() { sed -n "s/^$2: //p" <<<"$1"; }
mkrepo() { # -> echoes new repo dir on a fresh feature branch
  local d; d="$(mktemp -d)"; ( cd "$d"
    git init -q; git config user.email t@t; git config user.name t
    git commit -q --allow-empty -m init
    git branch -m feature/x ) ; echo "$d"; }

# Case A: feature 브랜치 + origin/HEAD=main -> 진행
d="$(mkrepo)"; ( cd "$d"; git update-ref refs/remotes/origin/main HEAD 2>/dev/null || true
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main )
out="$(cd "$d" && bash "$SCRIPT")"
[ "$(field "$out" branch_ok)" = "true" ] && { PASS=$((PASS+1)); echo "  PASS: feature branch allowed"; } \
  || { FAIL=$((FAIL+1)); echo "  ✗ FAIL: feature branch should be allowed ($out)"; }
rm -rf "$d"

# Case B: main 브랜치 -> 거부 (origin/HEAD 유무 무관: 리터럴 fallback)
d="$(mktemp -d)"; ( cd "$d"; git init -q; git config user.email t@t; git config user.name t
  git commit -q --allow-empty -m init; git branch -m main )
out="$(cd "$d" && bash "$SCRIPT")"
[ "$(field "$out" branch_ok)" = "false" ] && { PASS=$((PASS+1)); echo "  PASS: main rejected"; } \
  || { FAIL=$((FAIL+1)); echo "  ✗ FAIL: main should be rejected ($out)"; }
rm -rf "$d"

# Case C: master (리터럴 fallback, origin/HEAD 없음) -> 거부
d="$(mktemp -d)"; ( cd "$d"; git init -q; git config user.email t@t; git config user.name t
  git commit -q --allow-empty -m init; git branch -m master )
out="$(cd "$d" && bash "$SCRIPT")"
[ "$(field "$out" branch_ok)" = "false" ] && { PASS=$((PASS+1)); echo "  PASS: master rejected"; } \
  || { FAIL=$((FAIL+1)); echo "  ✗ FAIL: master should be rejected ($out)"; }
rm -rf "$d"

# Case D: detached HEAD -> 거부 (fail-closed)
d="$(mkrepo)"; ( cd "$d"; git commit -q --allow-empty -m second
  git checkout -q "$(git rev-parse HEAD)" )
out="$(cd "$d" && bash "$SCRIPT")"
[ "$(field "$out" reason)" = "detached_head" ] && [ "$(field "$out" branch_ok)" = "false" ] \
  && { PASS=$((PASS+1)); echo "  PASS: detached rejected"; } \
  || { FAIL=$((FAIL+1)); echo "  ✗ FAIL: detached should be rejected ($out)"; }
rm -rf "$d"

# project_dir emitted
d="$(mkrepo)"; out="$(cd "$d" && bash "$SCRIPT")"
[ -n "$(field "$out" project_dir)" ] && { PASS=$((PASS+1)); echo "  PASS: project_dir emitted"; } \
  || { FAIL=$((FAIL+1)); echo "  ✗ FAIL: project_dir missing ($out)"; }
rm -rf "$d"

echo ""; echo "Total: $((PASS+FAIL)), PASS=$PASS, FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
