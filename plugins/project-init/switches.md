---
type: devbrew-switches
plugin: project-init
---

# project-init 끄기 변수

상태: 남음 = 계속 듣는다 · 은퇴 예정 = 지금은 듣고, 곧 듣지 않는다 · 은퇴 = 더 듣지 않는다.

| 이름 | 끄는 것 | 상태 | 대신할 길 |
|---|---|---|---|
| `DEVBREW_PROJECT_INIT_DISABLE` | project-init 전체(훅과 셋업) | 은퇴 예정 | Claude Code 의 플러그인 끄기(`/plugin` · `claude plugin disable` · 설정의 `enabledPlugins`) — 새 세션부터 먹는다 |
| `DEVBREW_SKIP_HOOKS=project-init:post-tool-use` · `DEVBREW_SKIP_HOOKS=project-init:PostToolUse` | 브랜치 · 커밋 확인 훅 | 은퇴 예정 | 플러그인 끄기, 또는 설정의 `disableAllHooks`(모든 플러그인의 훅이 함께 꺼진다) |
