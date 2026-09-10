#!/usr/bin/env bash
# AC3 — design doc 의 Handoff Context 계약이 리뷰어 쪽에 실재한다.
#
# 재는 것 — design 자리 프로필(`references/docreview-profiles/design-doc.md`):
#   · `defer_target` 이 `### Deferred to plan` 을 이름으로 가리킨다. 엔진이 `defer` 처분을 실제로
#     적어 넣는 자리이고, 이름이 갈라지면 `defer` 가 문서에 없는 절을 가리킨다.
#   · 층 2 의 `handoff_incomplete` rubric 줄이 Handoff Context 를 이름으로 댄다.
#
# 재지 못하는 것 — 저자 쪽 지시. Handoff Context 를 `TL;DR` · `Implicit context` · `Deferred to plan`
# 세 하위 항목으로 쓰라는 기계 앵커는 spec-distill 2.0.0 에서 템플릿과 함께 사라졌다
# (brainstorming 은 그 템플릿을 읽지 않았다). 앞의 두 라벨은 이제 어디서도 기계로 재지 않는다.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PROFILE="$REPO_ROOT/plugins/spec-distill/references/docreview-profiles/design-doc.md"

. "$REPO_ROOT/shared/tests/assert.sh"

[[ -f "$PROFILE" ]] && ok "AC3: 대상 실재 — ${PROFILE#"$REPO_ROOT/"}" \
                    || { no "AC3: 대상 부재 — ${PROFILE#"$REPO_ROOT/"}"; finish; exit; }

DEFER="$(sed -n 's/^[[:space:]]*defer_target:[[:space:]]*//p' "$PROFILE" | head -1)"
if [[ -z "$DEFER" ]]; then
  no "AC3: 프로필에서 defer_target 을 추출하지 못했다"
elif printf '%s' "$DEFER" | grep -qF 'Deferred to plan'; then
  ok "AC3: 프로필 defer_target 이 'Deferred to plan' 을 이름으로 가리킨다 ($DEFER)"
else
  no "AC3: 프로필 defer_target 이 'Deferred to plan' 이 아니다 ($DEFER) — defer 가 문서에 없는 절로 간다"
fi

BODY2="$(awk '/^## 층 2/{f=1; print; next} f && /^## /{f=0} f' "$PROFILE")"
RUBRIC="$(printf '%s\n' "$BODY2" | grep -F 'handoff_incomplete' | head -1)"
if [[ -z "$BODY2" ]]; then
  no "AC3: 프로필의 '## 층 2' 창이 비었다 — 구조 앵커 파손 (통과 아님)"
elif [[ -z "$RUBRIC" ]]; then
  no "AC3: 층 2 본문에 handoff_incomplete rubric 줄이 없다"
elif printf '%s' "$RUBRIC" | grep -qF 'Handoff Context'; then
  ok "AC3: handoff_incomplete rubric 이 Handoff Context 를 이름으로 댄다"
else
  no "AC3: handoff_incomplete rubric 이 Handoff Context 를 대지 않는다 ($RUBRIC)"
fi
finish
