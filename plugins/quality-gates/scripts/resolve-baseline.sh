#!/usr/bin/env bash
# resolve-baseline.sh — 공유 baseline resolution (design 2026-08-01 §5.2 R-init, AC4).
# check-review-scope.sh v2.6.0→v2.7.0 3라운드 하드닝의 산물을 단일 모듈로 추출:
# origin/HEAD → origin/main → origin/master → local main → local master 순 resolution
# + merge-base + shallow/detached 감지.
#
# Output (stdout, 항상 4줄):
#   base:       <display short-name | ->      사람에게 보여줄 이름
#   base_ref:   <git-usable ref | ->          존재가 확인된 ref (remote-tracking일 수 있음)
#   merge_base: <full sha | ->                git merge-base <base_ref> HEAD
#   degraded:   yes|no                        yes면 위 3키는 전부 '-'
#
# Exit: 항상 0 (degraded: yes가 fail-open 상태를 실어 나른다). 인자 없음. read-only.
set -u

emit_degraded() {
  echo "base: -"
  echo "base_ref: -"
  echo "merge_base: -"
  echo "degraded: yes"
  exit 0
}

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || emit_degraded
git rev-parse --verify --quiet HEAD  >/dev/null 2>&1 || emit_degraded
# detached HEAD → 비교할 브랜치 컨텍스트 없음 → degraded.
git symbolic-ref --quiet HEAD        >/dev/null 2>&1 || emit_degraded
# shallow clone → 잘린 히스토리 → merge-base가 grafted boundary로 조용히 resolve될 수 있음.
[[ "$(git rev-parse --is-shallow-repository 2>/dev/null)" == "true" ]] && emit_degraded

base=""; base_ref=""
if ref=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null); then
  base="${ref#origin/}"; base_ref="$ref"
elif git rev-parse --verify --quiet refs/remotes/origin/main   >/dev/null 2>&1; then
  base="main";   base_ref="origin/main"
elif git rev-parse --verify --quiet refs/remotes/origin/master >/dev/null 2>&1; then
  base="master"; base_ref="origin/master"
elif git rev-parse --verify --quiet refs/heads/main            >/dev/null 2>&1; then
  base="main";   base_ref="main"
elif git rev-parse --verify --quiet refs/heads/master          >/dev/null 2>&1; then
  base="master"; base_ref="master"
else
  emit_degraded
fi

merge_base=$(git merge-base "$base_ref" HEAD 2>/dev/null) || emit_degraded
[[ -n "$merge_base" ]] || emit_degraded

echo "base: $base"
echo "base_ref: $base_ref"
echo "merge_base: $merge_base"
echo "degraded: no"
exit 0
