#!/usr/bin/env bash
# AC8e — 규약 정렬(S4): project-init 템플릿 2개(github-flow · git-flow)에서 무조건
# rebase 금지 조항을 완화하고, 리포 루트 docs/git-workflow/branch-strategy.md는 원문
# 그대로 보존됐는지 검증한다 (양방향).
#
# 왜 양방향인가: 템플릿만 확인하면 리포 루트를 "정합"이라는 명분으로 함께 덮어써도
# 이 락은 못 잡는다. 리포 루트는 사용자 본인이 명시한 선호(C3)라 이 sweep의 스코프
# 밖이다 — 원문 rebase 금지 조항이 그대로 남아 있어야 PASS다.
#
# 왜 템플릿 2개 모두인가: 동일한 무조건 rebase 금지 조항이 github-flow와 git-flow
# 템플릿에 독립적으로 존재한다. 한쪽만 고치면 다른 variant에서 억제가 산다 —
# 이 sweep 설계 리뷰가 실제로 이 단일-variant 누락을 두 번 잡았다.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"

BANNED='`git rebase`는 절대 안 됨'
RELAXED='공유된 브랜치는 rebase하지 않는다'

for variant in github-flow git-flow; do
  f="plugins/project-init/templates/$variant/branch-strategy.md"
  if [ ! -f "$f" ]; then
    no "AC8e: $f 부재"
    continue
  fi
  if grep -qF "$BANNED" "$f"; then
    no "AC8e: $f 에 무조건 rebase 금지 조항이 잔존한다"
  else
    ok "AC8e: $f — 무조건 rebase 금지 조항 없음"
  fi
  if grep -qF "$RELAXED" "$f"; then
    ok "AC8e: $f — 완화된 rebase 조항(공유 여부 기준) 실재"
  else
    no "AC8e: $f 에 완화된 rebase 조항이 없다"
  fi
done

ROOT_DOC="docs/git-workflow/branch-strategy.md"
if [ ! -f "$ROOT_DOC" ]; then
  no "AC8e: $ROOT_DOC 부재"
elif grep -qF "$BANNED" "$ROOT_DOC"; then
  ok "AC8e: 리포 루트 $ROOT_DOC — rebase 금지 원문 보존 (사용자 선호, C3 스코프 밖)"
else
  no "AC8e: 리포 루트 $ROOT_DOC 의 rebase 금지 원문이 사라졌다 — 사용자 선호를 sweep이 침범했다"
fi

finish
