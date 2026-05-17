# Changelog

`project-init` 플러그인의 모든 주요 변경사항은 본 파일에 기록됩니다.

포맷은 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)를 기준으로 하고,
이 프로젝트는 [Semantic Versioning](https://semver.org/spec/v2.0.0.html)을 따릅니다.

## [1.4.0] — 2026-05-17

### Added
- `hooks/docs-lint.py` — root context 파일 (`CLAUDE.md`/`AGENTS.md`/`.claude/CLAUDE.md`/`.claude/AGENTS.md`) 의 5 agent-readable convention rule을 PostToolUse advisory로 검증. R1 size (>200 warn, >300 STRONG), R2 TOC (>300 lines required), R5 fenced code language tag, R6 internal links resolve, R-pointer CLAUDE/AGENTS drift (bidirectional trigger). Non-blocking, kill switch `DEVBREW_SKIP_HOOKS=project-init:docs-lint`. 디자인 근거: Anthropic 공식 ([code.claude.com/docs/en/memory.md] *"target under 200 lines"*) + AGENTS.md 오픈 스펙 ([agents.md] 16+ 벤더 채택) + Chroma 2025 *Context Rot* (input length에 monotonic degradation) + Lost-in-the-Middle (Liu 2023) 3-source 합의.
- `templates/shared/claude-md-pointer.md` — `@AGENTS.md\n` 한 줄, `/project-init`이 CLAUDE.md로 발행하는 thin pointer template.
- `hooks/tests/` — Python stdlib `unittest` 기반 40+ test case (모든 룰 happy/violation + kill switch + symlink + worktree + bidirectional trigger). fixture 9개 서브디렉토리 layout (`fixtures/<case>/AGENTS.md` 또는 `CLAUDE.md`).
- `hooks/tests/smoke.sh` — V2 자동화 smoke script (CI-runnable, no human eyeballing, macOS bash 3.2 호환).

### Changed
- `commands/project-init.md` Step 4 전반 — **AGENTS.md를 canonical**, **CLAUDE.md를 `@AGENTS.md` thin pointer**로 발행. 기존 단일-CLAUDE.md 5-state matrix를 *AGENTS.md × CLAUDE.md 2축 4-state matrix* (S1 clean / S2a CLAUDE-only full / S2b dangling pointer / S3 AGENTS canonical / S4 divergent) 로 재작성. 4-state matrix는 mutually exclusive AND exhaustive — raw 6 조합 중 S2가 (2→1), S4가 (2→1) 압축.
- `commands/project-init.md` Step 1 — 기존 CLAUDE.md가 있고 AGENTS.md가 없으면 migration 프롬프트 추가. 거절 시 전체 abort.
- `commands/project-init.md` Step 5 confirmation — AGENTS.md (canonical) + CLAUDE.md (`@AGENTS.md` thin pointer) 생성 명시.
- `templates/<strategy>/claude-md-section.md` → `agents-md-section.md` 3건 rename (`git mv`로 history 보존).
- `hooks/hooks.json` — PostToolUse에 두 번째 entry 추가 (matcher `Write|Edit|MultiEdit`).
- `plugin.json` description — AGENTS.md primary + thin pointer 패턴 반영.

### Migration notes
- 기존 v1.3.0 사용자가 `/project-init` 재실행 시 S2 path로 진입 → migration 프롬프트 → AGENTS.md 생성 + CLAUDE.md thin pointer 교체.
- 두 hook은 kill switch 토큰이 다름 (`project-init:post-tool-use` vs `project-init:docs-lint`). 둘 모두 끄려면 `DEVBREW_SKIP_HOOKS=project-init:post-tool-use,project-init:docs-lint`.

## [1.3.0] — 2026-05-10

### Added
- `templates/shared/commit-conventions.md`에 `revert` commit type row 추가 (Conventional Commits v1.0.0 / Angular convention 표준 type, AC2). `hooks/post-tool-use.py:21` `CONVENTIONAL_COMMIT_PATTERN`과 line 141 error message도 동기화 (AC17, AC18).
- `templates/shared/commit-conventions.md`에 `## SemVer Mapping` 섹션 신설. `fix→PATCH`, `feat→MINOR`, `BREAKING CHANGE→MAJOR` 매핑 명시 — [Conventional Commits v1.0.0 §1](https://www.conventionalcommits.org/en/v1.0.0/) 정의에 따라 `release-please`/`semantic-release` 자동화 enabler (AC3).
- `templates/shared/commit-conventions.md`에 `## Issue References` 섹션 신설. `Closes: #N` (issue auto-close), `Refs: #N` (참조) footer pattern 예제 (AC4).
- `templates/shared/pr-process.md`에 `## Server-Side Enforcement` 섹션 신설. 6개 GitHub branch protection 항목 (PR reviews, status checks, linear history, no force push, signed commits, dismiss stale approvals) 명시. "client-side hook이 server-side를 대체하지 않음" 강조. [GitHub docs — About protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches) 참조 (AC6).
- `templates/git-flow/branch-strategy.md`에 `## When NOT to use Git Flow` 섹션 신설. [Vincent Driessen 2020 reflection](https://nvie.com/posts/a-successful-git-branching-model/) paraphrase 인용 — continuous delivery 팀이라면 GitHub Flow 권장, Git Flow는 versioned releases 한정. [Atlassian "legacy" 분류](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow) cite (AC8).
- `templates/trunk-based/branch-strategy.md`에 `## Releasing` 섹션 신설. Pattern A (tag from trunk, default) + Pattern B (release branches for legacy version support, cherry-pick from trunk + kill switch 안내). [trunkbaseddevelopment.com](https://trunkbaseddevelopment.com/) canonical 권장 패턴 (AC14).

### Changed
- 3개 strategy의 branch naming regex가 `[\w.-]+` → `[a-z0-9][a-z0-9.-]*`로 tighten. `\w`가 대문자/언더스코어 허용해 산문의 "kebab-case" 권장과 정합성 결여였던 사실 오류 수정 (AC9, AC11, AC13). `hooks/post-tool-use.py:19` `DEFAULT_BRANCH_PATTERN` fallback도 동기화 (AC16). 기존 컨벤션 따르던 사용자 (`feature/foo-bar`)는 영향 없음 — 잘못된 이름 (`feature/Foo_Bar`, `feature/foo_bar`) 쓰던 사용자만 거부됨 (의도된 fix).
- `templates/shared/commit-conventions.md` `## Rules` 섹션의 subject line 한계가 72자 → **50자**로 변경. body wrap 72자 별도 명시. [Tim Pope 2008 *"A Note About Git Commit Messages"*](https://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html) canonical "50/72 rule" 정렬 — `git log --oneline`, GitHub PR list, 80-col terminal이 50자에서 truncate. [cbea.ms *"How to Write a Git Commit Message"*](https://cbea.ms/git-commit/) 동일 권장 (AC1).

### Fixed
- v1.2.3 이전 templates는 subject line 한계를 72자로 표기해 Tim Pope 50/72 rule의 두 한계 (subject 50 / body 72)를 혼동하고 있었음. AC1으로 시정.

## [1.2.3] — 2026-05-10

### Changed
- devbrew CLAUDE.md *"Korean-primary, English-terms-only"* 정책을 `plugins/project-init/`에 적용 (qg `28c6ffb` precedent 정렬). `README.md`, `CHANGELOG.md`, `commands/project-init.md` 본문이 Korean-primary로 재작성됨; 식별자, code, branch 이름, regex, frontmatter `description`은 영어 유지.
- `templates/shared/llm-guidelines.md`가 v1.2.0에서 확립한 *"English headers/code + Korean explainers"* 하이브리드 패턴을 다른 templates 전체로 확장 — `templates/shared/commit-conventions.md`, `templates/shared/pr-process.md`, `templates/<strategy>/branch-strategy.md` (3개), `templates/<strategy>/claude-md-section.md` (3개). Conventional Commits 식별자, regex, `gh` 명령, branch prefix, `**ALWAYS**`/`**NEVER**` 강조 토큰, `{{SCOPE_CONVENTION}}`/`{{MERGE_STRATEGY}}` placeholder, `## Git Workflow` anchor 영어 유지.

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
