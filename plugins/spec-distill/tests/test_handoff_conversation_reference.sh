#!/usr/bin/env bash
# AC4 — 「대화 컨텍스트 의존」 축이 design 자리에서 살아 있는가 — 리뷰어 쪽.
#
# 재는 것: 프로필 층 2 의 `handoff_incomplete` rubric 이 `/compact` 뒤 남은 암묵 컨텍스트를
# 발화 조건으로 이름 댄다.
#
# 재지 못하는 것: 저자 쪽 지시(「대화 컨텍스트를 가정하지 말라」). 그 앵커였던 템플릿이
# spec-distill 3.0.0 에서 삭제됐다 — 이 성질은 이제 리뷰어가 결함으로 잡는 쪽에만 남는다.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PROFILE="$REPO_ROOT/plugins/spec-distill/references/docreview-profiles/design-doc.md"

. "$REPO_ROOT/shared/tests/assert.sh"

[[ -f "$PROFILE" ]] && ok "AC4: 대상 실재 — ${PROFILE#"$REPO_ROOT/"}" \
                    || { no "AC4: 대상 부재 — ${PROFILE#"$REPO_ROOT/"}"; finish; exit; }

# 창은 「## 층 2」 절이다. frontmatter 의 카테고리 목록 한 줄로는 만족되지 않는다
# (그 줄에는 산문이 없다) — header-satisfiable 회피.
BODY2="$(awk '/^## 층 2/{f=1; print; next} f && /^## /{f=0} f' "$PROFILE")"
if [[ -z "$BODY2" ]]; then
  no "AC4: 프로필의 '## 층 2' 창이 비었다 — 구조 앵커 파손 (통과 아님)"
else
  RUBRIC="$(printf '%s\n' "$BODY2" | grep -F 'handoff_incomplete' | head -1)"
  if [[ -z "$RUBRIC" ]]; then
    no "AC4: 층 2 본문에 handoff_incomplete rubric 줄이 없다"
  elif printf '%s' "$RUBRIC" | grep -qF '/compact' \
       && printf '%s' "$RUBRIC" | grep -qE '암묵 컨텍스트|implicit context'; then
    ok "AC4: 프로필 rubric 이 '/compact 뒤 남은 암묵 컨텍스트'를 발화 조건으로 이름 댄다"
  else
    no "AC4: handoff_incomplete rubric 이 대화 컨텍스트 의존 축을 잃었다 ($RUBRIC)"
  fi
fi
finish
