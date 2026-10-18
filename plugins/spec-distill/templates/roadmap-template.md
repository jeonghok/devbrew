---
type: roadmap
source_brief: {{SOURCE_BRIEF}}
---

# {{TITLE}} — 로드맵

승인된 분해안의 에픽 지도다. 에픽마다 원본 brief · 이 로드맵 · 에픽 묶음을 넘긴다. 상태 칸은 없다 — 단계는 spec-distill 의 `scripts/roadmap_status.py` 가 git 에서 계산한다. 단위는 로드맵 > 에픽(spec 하나) > plan(PR 하나) > task 다.

## 에픽

{{EPICS}}
## 지휘 절차

이 로드맵은 지휘자가 이끈다 — `/spec-distill:epic-conductor {{ROADMAP}}`. 다시 불러도 git 과 기계 상태에서 상태를 다시 계산해 같은 자리에서 잇는다. 지휘자를 껐으면(`DEVBREW_SPEC_DISTILL_DISABLE=1`) spec-distill 의 `references/conducting.md` 끝 절 「손으로 따르는 절차」 를 따른다.

- 사람 몫(brainstorming · spec 승인 · 계획의 설계에 없던 결정)은 지휘 세션이 한 번에 한 에픽씩 배경과 함께 묻는다.
- 실행 방식은 writing-plans 가 권하는 방식이고, 계획 검토는 계획에 설계에 없던 결정이 있을 때만 기다린다.
- 머지는 사용자가 한다.

## 결정 기록

줄 형식은 `- <블록> · <결정|머지> · <YYYY-MM-DD> · 「원문」` 이다. 인터뷰 뒤의 사용자 말은 새 S 번호 없이 원문 그대로 인용한다. squash · rebase 로 머지해 머지 커밋이 없는 에픽은 「머지」 줄로 적는다.

## 재분해 이력

{{HISTORY}}

## 위험 번호표

brief §5 의 번호 없는 위험 줄(숨은 가정 · 실패 양식 · 리뷰 참고 순)에 줄 순서대로 번호를 단다. 오른쪽은 brief 원문 그대로다.

{{RISKS}}
