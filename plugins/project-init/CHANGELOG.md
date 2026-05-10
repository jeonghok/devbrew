# Changelog

`project-init` 플러그인의 모든 주요 변경사항은 본 파일에 기록됩니다.

포맷은 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)를 기준으로 하고,
이 프로젝트는 [Semantic Versioning](https://semver.org/spec/v2.0.0.html)을 따릅니다.

## [1.2.2] — 2026-05-10

### Security
- `hooks/post-tool-use.py`가 devbrew kill-switch 계약을 존중하도록 수정. opt-out: `DEVBREW_DISABLE_PROJECT_INIT=1` 또는 `DEVBREW_SKIP_HOOKS=project-init:post-tool-use`. 이전 버전은 escape hatch가 없어 모든 `Bash` PostToolUse마다 무조건 실행됐고, 이는 `CLAUDE.md` §Plugin Shape ("어떤 훅도 자신의 kill switch 존중을 거부할 수 없음 — kill switch는 보안 컨트롤") 위반이었음.

### Added
- devbrew CLAUDE.md 요구사항에 따른 `README.md` "Hooks Installed" 섹션 (한 줄 "왜 skill이 아닌가" justification + kill-switch 문서화).

### Changed
- `README.md` Architecture tree에 박혀 있던 하드코딩 버전 주석 제거 (플러그인이 `1.2.1`일 때 `v1.2.0`으로 stale).

## [1.2.1] — 2026-05-07

v1.2.0 template default 보정용 same-day 패치 — 의도된 중복 날짜.

### Changed
- `templates/github-flow/branch-strategy.md`와 `templates/git-flow/branch-strategy.md`가 base와 feature 브랜치 동기화 시 default를 `git merge`로 변경. 새로 추가된 "Rules for Claude" 라인이 *"rebase golden rule"* (Pro Git §3.6 *"Rebasing"*)을 인용 — rebase는 history를 rewrite하므로 push된 브랜치에는 unsafe. one-line teachability와 로컬 브랜치 force-push safety를 위해 strict variant (always merge, never rebase) 채택.

### Removed
- 타깃 프로젝트의 `CLAUDE.md`에 더 이상 Andrej Karpathy attribution blockquote (`> Andrej Karpathy의 [LLM 코딩 관찰]...`)가 주입되지 않음. 4-bullet baseline은 그대로. attribution은 플러그인 layer (README, plugin.json description, slash-command 확인 메시지, 본 changelog)에 보존됨 — directive는 타깃 프로젝트의 LLM-context anchor에만 적용.

## [1.2.0] — 2026-05-07

### Added
- 타깃 CLAUDE.md에 `## Git Workflow`와 함께 `## LLM Coding Guidelines` 섹션 주입. 하이브리드 포맷 (English headers + Korean explainers), Andrej Karpathy의 LLM 코딩 관찰을 4줄로 압축.
- 새 공유 template `templates/shared/llm-guidelines.md`.
- README "Principles Instantiated" 섹션이 Law 1 (Clarity Before Code)을 cite.
- 본 `CHANGELOG.md` (devbrew 룰 복구 — v1.1.0에서 누락이었음).

### Changed
- `commands/project-init.md` Step 4가 strategy 섹션 *앞에* LLM Guidelines 섹션을 읽고 prepend하도록 수정. Step 5 confirmation에 새 섹션 명시.
- `plugin.json` description이 dual-purpose 초기화를 반영하도록 업데이트.
- `commands/project-init.md` Step 4c가 단일 섹션 로직에서 4-state matrix로 확장 — `## LLM Coding Guidelines`와 `## Git Workflow`를 인접 블록으로 관리하면서도 비-관리 컨텐츠를 모두 보존.

## [1.1.0] — 2026-04-12

### Added
- 3개 branching strategy로 초기 public release: GitHub Flow, Git Flow, Trunk-based.
- strategy 선택과 CLAUDE.md + `docs/git-workflow/` 파일 생성을 위한 `/project-init` 인터랙티브 command.
- 브랜치 명명·Conventional Commits 포맷을 검증하는 PostToolUse hook.
- Templates: 공유 `commit-conventions.md`와 `pr-process.md`; strategy별 `claude-md-section.md`와 `branch-strategy.md`.
