# 로드맵 끝의 확인 — 직접 써 보는 확인

모든 에픽이 머지된 뒤 끝에서 끝 확인에서 함께 돈다. 플러그인을 올린 새 세션에서만 돌릴 수 있다 — 에픽을 구현한 세션은 시작 때의 플러그인 판을 쓴다. 돌린 결과는 로드맵을 닫는 PR 본문에 싣는다. 에픽 설계가 손 확인을 이 목록으로 미루면 여기에 한 줄을 더한다.

| # | 확인 | 나온 곳 |
|---|---|---|
| 1 | 실제 PR 하나에 qg 를 돌려(사람 승인 걷기 포함) 질문이 근거 줄과 함께 나오고 답 파일 · 그 파일만 담은 커밋 · 돌려주는 꼴이 생기는지, 걷기를 거절하고 차등 결과가 모두 통과인 실행이 「intent-critic — 근거 없음」 으로 끝나는지 | R1 설계 `## 미룸`(`docs/superpowers/specs/2026-11-14-qg-intent-critic-design.md`) |
| 2 | 머지 앞 리뷰 → 되돌리기 → 좁은 재리뷰의 실제 한 바퀴 | R4 설계 `## 미룸`(`docs/superpowers/specs/2026-11-22-qg-review-only-design.md`) |
| 3 | 격리 설치로 qg 를 직접 불러, 막는 지적이 나오는 변경에서 질문 없이 고칠 목록으로 끝나는지 | R4 설계 `## 미룸`(같은 문서) |
| 4 | 실제 지휘 리뷰에서 화면의 꼴과 답 이어지기 | R6 설계 `## 미룸`(`docs/superpowers/specs/2026-11-22-qg-readable-review-design.md`) |
| 5 | R7 의 새 흐름(경로로 넘기는 리뷰어 칸 · 게시 표지 · 공유 스위트 잠금 · 맡지 못한 파일)을 실제 지휘 리뷰에서 돌려 보기 | R7 설계 Verification Plan(`docs/superpowers/specs/2026-11-24-qg-planted-text-suite-lock-design.md`) |
| 6 | R8 의 새 흐름(어긋난 답 남기기 · 결과 줄 · 다른 팀 읽기)을 실제 리뷰에서 돌려 보기 | R8 설계 Verification Plan(`docs/superpowers/specs/2026-11-24-qg-answer-record-edges-design.md`) |
| 7 | R9 의 리뷰 상태 파일과 스크립트로 실제 지휘 리뷰 한 바퀴(머지 앞 리뷰 → 되돌리기 → 좁은 재리뷰 → 관문) | R9 설계 Verification Plan(`docs/superpowers/specs/2026-11-24-conductor-qg-review-edges-design.md`) |
