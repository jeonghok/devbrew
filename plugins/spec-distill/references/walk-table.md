# 걸음표

## 설계 흐름

| 걸음 | 누가 | 단계 | 관문 | 작업 방식 | 상한 | 도구 |
|---|---|---|---|---|---|---|
| 방향 확인 | 사람 · leader | — | — | superpowers:brainstorming | — | — |
| 설계 대화 | 사람 · leader | design | — | superpowers:brainstorming | — | — |
| 설계 검토 | leader | design | — | spec-distill:spec-review | 리뷰 엔진의 재리뷰 상한 | — |
| 설계 승인 | 사람 | — | spec 승인 | — | — | — |
| 계획 | worker | plan | — | superpowers:writing-plans | — | — |
| 계획 확인 | 사람 · leader | — | 계획 검토 | — | — | — |
| 구현 | worker | implement | — | superpowers:subagent-driven-development | 작업 방식의 고침 루프를 따른다 | — |
| 검수 | leader | review | — | — | — | spec-distill:integration-reviewer · quality-gates:quality-pipeline |
| PR 전 확인 | 사람 · leader | — | — | — | — | — |
| 머지 | 사람 | — | — | — | — | — |
| 회고 | leader | — | — | — | — | spec-distill:relay-checker |

## 설계 없는 흐름

| 걸음 | 누가 | 단계 | 관문 | 작업 방식 | 상한 | 도구 |
|---|---|---|---|---|---|---|
| 방향 확인 | 사람 · leader | — | 흐름 승인 | — | — | — |
| 진행 | worker | implement | — | — | — | — |
| 결과 확인 | 사람 · leader | — | — | — | — | — |
