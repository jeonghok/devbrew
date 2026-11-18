---
type: devbrew-switches
plugin: quality-gates
---

# quality-gates 끄기 변수

상태: 남음 = 계속 듣는다 · 은퇴 예정 = 지금은 듣고, 곧 듣지 않는다 · 은퇴 = 더 듣지 않는다.

| 이름 | 끄는 것 | 상태 | 대신할 길 |
|---|---|---|---|
| `DEVBREW_QUALITY_GATES_DISABLE_CODEX` | codex 리뷰 | 남음 | — |
| `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST` | 리뷰 대상 저장소의 테스트 실행(차등 테스트 · e2e 부팅) | 남음 | — |
| `DEVBREW_QUALITY_GATES_DISABLE_PUBLISH` | 열린 PR 에 코멘트 달기 | 남음 | — |
| `DEVBREW_QUALITY_GATES_DISABLE` | quality-gates 전체 | 은퇴 예정 | Claude Code 의 플러그인 끄기(`/plugin` · `claude plugin disable` · 설정의 `enabledPlugins`) — 새 세션부터 먹는다 |
| `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER` | 보안 리뷰어 | 은퇴 예정 | 없음 — 보안 리뷰는 늘 돈다 |
| `DEVBREW_QUALITY_GATES_DISABLE_CRITIQUE` | 문서 비평 | 은퇴 예정 | `/quality-gates:artifact-critique` 를 부르지 않는다 |
| `DEVBREW_QUALITY_GATES_DISABLE_E2E` | e2e 걷기 | 은퇴 예정 | e2e 질문에 「아니오」 로 답한다. 실행 자체를 막으려면 `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST` |
| `DEVBREW_QUALITY_GATES_DISABLE_INTENT_CRITIC` | 의도 점검 | 은퇴 예정 | 없음 — 읽기만 하는 단계다 |
| `DEVBREW_SKIP_HOOKS=quality-gates:qg-gc` | 남의 세션 폴더 정리 | 은퇴 예정 | 유예 시간 `DEVBREW_QUALITY_GATES_TTL_HOURS` 를 크게 준다 |
