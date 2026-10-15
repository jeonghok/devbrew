---
type: roadmap
source_brief: {{SOURCE_BRIEF}}
---

# {{TITLE}} — 로드맵

승인된 분해안의 에픽 지도다. 에픽마다 원본 brief · 이 로드맵 · 에픽 묶음을 넘긴다. 상태 칸은 없다 — 단계는 spec-distill 의 `scripts/roadmap_status.py` 가 git 에서 계산한다. 단위는 로드맵 > 에픽(spec 하나) > plan(PR 하나) > task 다.

## 에픽

{{EPICS}}
## 지휘 절차

지휘자 skill 이 생기기 전까지 지휘 세션이 따르는 절차다. 지휘 세션은 `/new` 뒤 첫 줄에 `@{{ROADMAP}}` 를 붙여 연다.

1. `git fetch origin` → spec-distill 의 `scripts/control_plane.py show --tasks {{ROADMAP}}` → 작업 목록을 결과에 맞춘다. 줄마다 `<제목><탭><작업 상태>` 이고 에픽 하나에 작업 하나다 — 제목은 그대로 쓰고, 상태가 `keep` 이면(알 수 없음) 작업 상태는 바꾸지 않고 제목만 바꾼다. 종료 코드가 3 이면 작업 목록을 바꾸지 않고 표준 오류의 「검사 불가」 사유를 사용자에게 그대로 보인다 — 일부 단계가 계산돼 보여도 믿지 않는다. 로드맵이 아직 origin/main 에 없으면(방금 분해해 머지 전) spec-distill 의 `scripts/roadmap_status.py --roadmap-file {{ROADMAP}}` 로 대신 계산하고, 대기 · 준비는 시작 전, 설계 중 · 계획은 진행 중, 머지됨 · 끝남은 완료로 맞춘다.
2. 준비 단계 에픽을 고른다. 블록의 `브랜치:` 이름으로 `origin/main` 에서 브랜치와 worktree 를 먼저 만들고, 그 에픽의 설계문서 · 계획은 모두 그 브랜치에 커밋한다. 설계(brainstorming → 설계문서 → spec-review 승인)는 한 세션 안에서 한 에픽씩 돈다 — spec 승인은 사용자가 에픽마다 한다. 에픽의 설계 세션은 spec-distill 의 `references/epic-handoff.md` 에 있는 에픽 넘김 줄을 자리표를 채워 `/new` 뒤 첫 줄로 붙여 연다.
3. 설계 세션은 설계문서를 커밋한 뒤 spec-review 를 설계문서 경로 뒤에 `--bundle <묶음>` 을 붙여 부른다 — `<묶음>` 은 설계문서 frontmatter `source_interview` 에 적은 것과 같은 레포 상대경로다. 그 값이 `source_interview` 와 다른 파일이거나 읽을 수 없으면 spec-review 는 리뷰하지 않고 끝난다. 같으면 진입에서 번호 대조(spec-distill 의 `scripts/check_bundle_coverage.py`)를 보이고 리뷰를 계속한다 — 빠진 번호 · 얕은 답 · 받드는 에픽 없는 발화 · 검사 불가는 막지 않고 승인 게이트의 「경고 N개」에 더해지며, 고칠지는 그 게이트에서 사용자가 정한다.
4. superpowers 가 묻는 자리(plan 검토 · 실행 방식 · 머지 메뉴)는 그대로 사용자에게 간다.
5. 구현은 에픽마다 worktree 에서 돌린다. SDD 가 마지막 메시지로 내는 판정 목록(「Rulings I made」)은 그대로 사용자에게 보이고 멈추지 않는다.
6. 에픽이 머지될 때마다 남은 에픽을 재평가하고, 바뀔 때만 사용자 승인 뒤 로드맵 수정을 전용 작은 브랜치(`feature/roadmap-<요지>`)와 PR 로 올린다. 에픽 경계를 다시 나누는 일은 spec-distill 의 `references/redecompose.md` 절차를 따른다. 머지는 사용자가 한다.
7. 구현 커밋에는 `Spec: <에픽 설계문서 레포 상대경로>` 트레일러를 단다.

## 결정 기록

줄 형식은 `- <블록> · <결정|머지> · <YYYY-MM-DD> · 「원문」` 이다. 인터뷰 뒤의 사용자 말은 새 S 번호 없이 원문 그대로 인용한다. squash · rebase 로 머지해 머지 커밋이 없는 에픽은 「머지」 줄로 적는다.

## 재분해 이력

{{HISTORY}}

## 위험 번호표

brief §5 의 번호 없는 위험 줄(숨은 가정 · 실패 양식 · 리뷰 참고 순)에 줄 순서대로 번호를 단다. 오른쪽은 brief 원문 그대로다.

{{RISKS}}
