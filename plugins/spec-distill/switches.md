---
type: devbrew-switches
plugin: spec-distill
---

# spec-distill 끄기 변수

상태: 남음 = 계속 듣는다 · 은퇴 예정 = 지금은 듣고, 곧 듣지 않는다 · 은퇴 = 더 듣지 않는다.

| 이름 | 끄는 것 | 상태 | 대신할 길 |
|---|---|---|---|
| `DEVBREW_SPEC_DISTILL_DISABLE_CODEX` | codex 리뷰 | 남음 | — |
| `DEVBREW_SPEC_DISTILL_DISABLE_WEB` | 인터뷰와 brief 리뷰의 웹 조사 | 남음 | — |
| `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST` | 지휘자의 스위트 대조가 저장소 테스트를 돌리기 | 남음 | — |
| `DEVBREW_SPEC_DISTILL_DISABLE` | spec-distill 전체 | 은퇴 예정 | Claude Code 의 플러그인 끄기(`/plugin` · `claude plugin disable` · 설정의 `enabledPlugins`) — 새 세션부터 먹는다 |
| `DEVBREW_SPEC_DISTILL_DISABLE_RECRITIC` | 문서 리뷰의 재비판 | 은퇴 예정 | 없음 — 작은 일에서 건너뛰는 것은 모델 판단이 이유를 적고 한다 |
| `DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW` | brief 리뷰 | 은퇴 예정 | 없음 — 작은 일에서 건너뛰는 것은 모델 판단이 이유를 적고 한다 |
| `DEVBREW_SPEC_DISTILL_DISABLE_WORKTREE` | request-framing 의 워크트리 질문 | 은퇴 예정 | 질문에 「아니오」 로 답한다 |
| `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE` | 설계문서 리뷰 | 은퇴 예정 | `/spec-distill:spec-review` 를 부르지 않는다 |
| `DEVBREW_SKIP_HOOKS=spec-distill:review-entry` | 설계문서 리뷰 | 은퇴 예정 | `/spec-distill:spec-review` 를 부르지 않는다 |
| `DEVBREW_QUALITY_GATES_DISABLE_WEB` | brief 리뷰가 codex 에 여는 웹 검색 | 은퇴 예정 | `DEVBREW_SPEC_DISTILL_DISABLE_WEB` |
| `DEVBREW_SKIP_HOOKS=spec-distill:statusline` | 상태줄과 로드맵 지도 | 은퇴 예정 | 상태줄 설정을 지운다 |
| `DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd` · `DEVBREW_SKIP_HOOKS=spec-distill:session-end-cleanup` | 리뷰 원장 정리 | 은퇴 예정 | 유예 시간 `DEVBREW_SPEC_DISTILL_TTL_HOURS` 를 크게 준다 |
| `DEVBREW_SKIP_HOOKS=spec-distill:spec-distill-gc` | 리뷰 원장 정리 | 은퇴 예정 | 유예 시간 `DEVBREW_SPEC_DISTILL_TTL_HOURS` 를 크게 준다 |
