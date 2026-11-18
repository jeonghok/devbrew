---
type: devbrew-switches
plugin: plugin-audit
---

# plugin-audit 끄기 변수

상태: 남음 = 계속 듣는다 · 은퇴 예정 = 지금은 듣고, 곧 듣지 않는다 · 은퇴 = 더 듣지 않는다.

| 이름 | 끄는 것 | 상태 | 대신할 길 |
|---|---|---|---|
| `DEVBREW_PLUGIN_AUDIT_DISABLE_CODEX` | codex 감사 | 남음 | — |
| `DEVBREW_PLUGIN_AUDIT_DISABLE_RUNTIME_SANDBOX` · `DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX` | 감사 대상 플러그인의 테스트 실행 | 남음 | — |
| `DEVBREW_PLUGIN_AUDIT_DISABLE` | plugin-audit 전체 | 은퇴 예정 | Claude Code 의 플러그인 끄기(`/plugin` · `claude plugin disable` · 설정의 `enabledPlugins`) — 새 세션부터 먹는다 |
| `DEVBREW_PLUGIN_AUDIT_DISABLE_WEB` | codex 감사의 웹 검색 | 은퇴 예정 | `DEVBREW_PLUGIN_AUDIT_DISABLE_CODEX` — codex 는 쓰되 웹만 막는 길은 없어진다 |
