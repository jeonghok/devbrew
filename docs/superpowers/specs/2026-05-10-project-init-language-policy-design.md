---
name: project-init-language-policy
version: 1.0.0
created_at: 2026-05-10
session_id: brainstorm-2026-05-10
status: locked
next_phase: writing-plans
source: superpowers/brainstorming + devbrew Korean-primary 정책 (CLAUDE.md §"When Editing This Repo")
---

# project-init — 언어 관리 정책 정렬 디자인 스펙

> **For agentic workers:** 이 문서는 `plugins/project-init/`의 docs 언어 정책을 `plugins/quality-gates/`(qg)와 정렬하기 위한 v1.2.3 변경 명세이다. 다음 단계는 superpowers `writing-plans` skill로 implementation plan을 생성하는 것이다.

## Goal

devbrew CLAUDE.md의 *"Korean-primary, English-terms-only"* 정책을 `plugins/project-init/`에 qg precedent (commit `28c6ffb`)와 동일한 범위로 적용한다. 추가로 `templates/shared/llm-guidelines.md`가 v1.2.0에서 확립한 *"English headers/code + Korean explainers"* 하이브리드 패턴을 나머지 templates 전체로 확장한다.

## Context / Why

devbrew CLAUDE.md는 user-facing 문서를 Korean-primary로 유지할 것을 요구하며 (식별자/고유명사/원문 인용/번역 어색한 기술 용어는 영어 유지), qg가 commit `28c6ffb`에서 README.md + CHANGELOG.md를 한국화하며 이 정책을 instantiate했다. 그러나 `plugins/project-init/`는 다음 두 측면에서 정렬되지 않은 상태다:

1. **devbrew-internal docs 미정렬** — `README.md`, `CHANGELOG.md`, `commands/project-init.md`가 거의 전면 영어로 남아 있어 qg와 톤이 분리되고, devbrew 자체 docs (`CLAUDE.md`, `docs/philosophy/*.md`)와도 비대칭.
2. **Templates 패턴 불일치** — `templates/shared/llm-guidelines.md`는 v1.2.0 (CHANGELOG: *"Hybrid format (English headers + Korean explainers)"*)에서 의도적으로 하이브리드로 ship됐지만, 같은 디렉토리의 `commit-conventions.md`, `pr-process.md`, `branch-strategy.md`(3개), `claude-md-section.md`(3개)는 전면 영어. 같은 `/project-init` 호출에서 주입되는 페이로드 안에 두 가지 톤이 혼재.

이 PR은 두 측면을 동시 해결한다.

## Goals

- **G1 — qg precedent 정렬**: `plugins/project-init/`의 devbrew-internal docs를 qg `28c6ffb` 적용 범위와 동일하게 한국화 (README + CHANGELOG + 사용자 가시 command 본문).
- **G2 — Templates 톤 통일**: `templates/*` 전체가 `llm-guidelines.md`와 같은 "English headers/code + Korean explainers" 하이브리드 패턴을 따른다.
- **G3 — 식별자 안정성 보존**: 모든 표 컬럼명, anchor 헤더, code/regex/명령, frontmatter `description`, branch prefix, Conventional Commits 식별자(`feat`, `fix`, `BREAKING CHANGE` 등), Keep a Changelog 카테고리(`Added`/`Changed`/`Removed`/`Security`/`Fixed`)는 영어 유지.
- **G4 — devbrew Plugin Shape 준수**: `plugin.json` patch bump (`1.2.2` → `1.2.3`), `CHANGELOG.md`에 `[1.2.3] — 2026-05-10` entry 추가.

## Non-goals

- **NG1 — Hook 출력 메시지 변경 안 함**: `hooks/post-tool-use.py`의 인라인 영어 메시지는 user-facing stderr 출력이라 별도 정책 결정이 필요. 이번 PR scope 아님.
- **NG2 — `templates/shared/llm-guidelines.md` 재작성 안 함**: 이미 패턴 정합.
- **NG3 — `commands/project-init.md` frontmatter `description` 변경 안 함**: Claude Code UI surface 값. qg.md 패턴(영어 description 유지)을 따른다.
- **NG4 — qg agents/skills의 한국화 추가 작업 안 함**: 본 PR은 project-init scope 한정.
- **NG5 — 타 플러그인의 언어 정책 정렬 안 함**: 별 PR로 분리.
- **NG6 — Major/minor version bump 안 함**: surface 변화 없는 doc consolidation. qg `28c6ffb`도 patch bump.

## Constraints

- **C1**: devbrew CLAUDE.md *"Korean-primary, English-terms-only"* 정책 준수 — 영어 사용은 식별자, 고유명사, 원문 인용, 자연스러운 한국어 대응이 없는 기술 용어에 한정.
- **C2**: qg `28c6ffb` precedent 준수 — devbrew-internal scope 동일 (README + CHANGELOG + 사용자 가시 command 본문).
- **C3**: Plugin Shape 준수 — `plugin.json` version bump 동반, CHANGELOG entry 동반.
- **C4**: Templates의 placeholder 토큰 (`{{SCOPE_CONVENTION}}`, `{{MERGE_STRATEGY}}`)은 위치·이름·개수가 모두 보존되어야 한다 — `commands/project-init.md` Step 4b가 정확히 그 토큰을 찾아 치환한다.
- **C5**: `templates/<strategy>/claude-md-section.md`는 사용자 CLAUDE.md에 직접 주입되는 anchor 블록이므로 `## Git Workflow` 헤더는 영어 유지 (devbrew 본 CLAUDE.md `## Git Workflow` 섹션과 anchor 일치 — coupling).
- **C6**: 본 PR이 도입하는 한국어 텍스트는 사용자 가시 prose에 한정. code block, regex, 명령 예시, table 헤더, table 내부의 식별자 컬럼은 영어 그대로.

## Acceptance Criteria

- **AC1**: `plugins/project-init/README.md`가 Korean-primary로 재작성됨 — 헤딩 한국어 ("아키텍처", "동작 방식", "기능", "브랜치 전략", "통합", "설치된 Hook", "인스턴스화한 원칙", "사용"), 본문 한국어, 식별자/code/branch 이름/regex 영어 유지. 톤이 `plugins/quality-gates/README.md`와 일치.
- **AC2**: `plugins/project-init/CHANGELOG.md`가 Korean-primary로 재작성됨 — Keep a Changelog 카테고리 헤더 (`### Added`, `### Changed`, `### Removed`, `### Security`, `### Fixed`)는 영어, 본문 prose는 한국어. 기존 entry의 fact 정확성·날짜·버전 번호는 절대 변경 없음.
- **AC3**: `plugins/project-init/commands/project-init.md` 본문이 한국어로 재작성됨 — Step 헤딩 한국어, frontmatter `description`은 영어 그대로 (qg.md 패턴), 코드/명령/template 경로/표 컬럼명 영어. `${CLAUDE_PLUGIN_ROOT}` 등 환경 변수와 `<strategy>` placeholder 영어 유지.
- **AC4**: `templates/shared/commit-conventions.md`의 `## Format`, `## Rules`, `## Types`, `## Scope`, `## Breaking Changes`, `## AI-Assisted Commits`, `## Good Examples`, `## Bad Examples` 헤더 영어 유지. Conventional Commits 식별자 (`feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `BREAKING CHANGE`) 영어. 표의 "When to use", "Example", "Why it's good", "Problem", "Fix" 컬럼명 영어. 본문 prose (현재 영어 설명 — 예: 현 `commit-conventions.md` Subject line 룰 "imperative mood, max 72 characters, no period")는 한국어로 재작성. `{{SCOPE_CONVENTION}}` placeholder 보존.
- **AC5**: `templates/shared/pr-process.md`의 `## PR Body Template`, `## Creating a PR`, `## PR Title`, `## Merge Strategy`, `## Review Checklist`, `## Plugin Integration` 헤더 영어. `gh pr create ...` 명령과 PR body markdown template, `{{MERGE_STRATEGY}}` placeholder 영어 그대로 보존. 안내 prose 한국어.
- **AC6**: `templates/<strategy>/branch-strategy.md` 3개 파일 (github-flow, git-flow, trunk-based) 각각의 `## Model`, `## Branch Naming Pattern`, `## Branch Prefixes`, `## Branch Lifecycle`, `## Rules for Claude` 헤더 영어. regex 블록, branch prefix (`feature/<name>`, `fix/<name>`), `git` 명령 영어. "Rules for Claude" bullet 안의 강조 토큰 (`**ALWAYS**`, `**NEVER**`)은 영어 유지, 그 뒤의 prose 설명은 한국어.
- **AC7**: `templates/<strategy>/claude-md-section.md` 3개 파일의 `## Git Workflow` 헤더 영어 (C5). bullet 설명 한국어. `{{MERGE_STRATEGY}}` placeholder 보존.
- **AC8**: `templates/shared/llm-guidelines.md`는 변경 없음 (NG2).
- **AC9**: `plugin.json`의 `version` 필드가 `1.2.2`에서 `1.2.3`으로 변경됨. 다른 필드 변경 없음.
- **AC10**: `CHANGELOG.md`에 `## [1.2.3] — 2026-05-10` entry 추가 — 어떤 카테고리(Changed)에 어떤 변경이 있었는지 한국어 prose로 명시. qg `28c6ffb`의 CHANGELOG entry를 reference 톤으로 사용.
- **AC11**: 모든 `templates/`의 placeholder 토큰 위치·이름·개수가 보존되어 `commands/project-init.md` Step 4b의 치환 로직이 깨지지 않음. 검증: 변경 전/후 `grep -rE "\{\{[A-Z_]+\}\}" plugins/project-init/templates/` 결과의 매치 문자열·매치 수가 동일.
- **AC12**: 변경 후 `/project-init` 호출 시뮬레이션이 가능한지 dry-run으로 점검 — `commands/project-init.md` Step 4 (Read templates → Replace placeholders → Write files) 흐름이 변경된 한국어 본문에서도 placeholder 토큰을 정상 식별.

## Files to Modify

### 변경 (rewrite)
1. `plugins/project-init/README.md` — Korean-primary 재작성 (AC1).
2. `plugins/project-init/CHANGELOG.md` — Korean-primary 재작성 + `[1.2.3]` entry 추가 (AC2, AC10).
3. `plugins/project-init/commands/project-init.md` — 본문 한국어, frontmatter 영어 유지 (AC3).
4. `plugins/project-init/templates/shared/commit-conventions.md` — 하이브리드 변환 (AC4).
5. `plugins/project-init/templates/shared/pr-process.md` — 하이브리드 변환 (AC5).
6. `plugins/project-init/templates/github-flow/branch-strategy.md` — 하이브리드 변환 (AC6).
7. `plugins/project-init/templates/git-flow/branch-strategy.md` — 하이브리드 변환 (AC6).
8. `plugins/project-init/templates/trunk-based/branch-strategy.md` — 하이브리드 변환 (AC6).
9. `plugins/project-init/templates/github-flow/claude-md-section.md` — bullet 한국어 (AC7).
10. `plugins/project-init/templates/git-flow/claude-md-section.md` — bullet 한국어 (AC7).
11. `plugins/project-init/templates/trunk-based/claude-md-section.md` — bullet 한국어 (AC7).
12. `plugins/project-init/.claude-plugin/plugin.json` — `version: "1.2.2"` → `"1.2.3"` (AC9).

### 미변경 (명시)
- `plugins/project-init/templates/shared/llm-guidelines.md` (NG2) — 이미 패턴 정합.
- `plugins/project-init/hooks/` 전체 (NG1) — hook 출력 정책은 별 PR.
- `plugins/project-init/.claude-plugin/plugin.json`의 `description` 필드 — 영어 유지 (Claude Code UI surface).

## Verification Plan

- **V1 (정적 검증)**: `git diff --stat`이 정확히 12개 파일만 보여주는지 확인. 그 외 파일이 포함됐다면 stop.
- **V2 (헤더 검증)**: `grep -rh "^##\? " plugins/project-init/templates/` 결과가 모두 영어 헤더만 보여주는지 확인. 한국어 헤더가 templates에 누출됐다면 stop.
- **V3 (placeholder 검증, AC11)**: 변경 전/후로 `grep -rE "\{\{[A-Z_]+\}\}" plugins/project-init/templates/` 실행, 매치되는 줄의 placeholder 문자열·개수가 정확히 동일한지 확인.
- **V4 (식별자 보존)**: `grep -rE "feat|fix|docs|style|refactor|perf|test|build|ci|chore" plugins/project-init/templates/shared/commit-conventions.md`로 Conventional Commits 식별자 영어 유지 확인.
- **V5 (Version 정합)**: `cat plugins/project-init/.claude-plugin/plugin.json | grep version` → `"1.2.3"`. `head plugins/project-init/CHANGELOG.md` → `## [1.2.3] — 2026-05-10` entry 존재.
- **V6 (Coupling 보존, C5)**: `grep -h "^## " plugins/project-init/templates/*/claude-md-section.md` 모두 `## Git Workflow` (영어).
- **V7 (Dry-run 시뮬레이션, AC12)**: `commands/project-init.md` Step 4의 흐름을 mental dry-run — Step 4a Read → Step 4b Replace → Step 4c/4d Write가 한국어 본문에서도 placeholder 토큰을 정상 식별하는지.
- **V8 (Tone 비교)**: 변경된 README와 `plugins/quality-gates/README.md`를 나란히 비교 — 헤딩 패턴, prose 톤, 식별자 처리 방식이 일치하는지.

## Rejected Alternatives

- **R1 — Templates 전면 한국화 (옵션 3)**: 사용자 영어팀 프로젝트에 강제 한국어 docs 주입. 거절 — `templates/*`는 user-facing 페이로드라 devbrew 정책의 정당한 적용 대상이 아니다 (devbrew 정책은 *devbrew 자체* docs 대상). 하이브리드 패턴이 더 정합.
- **R2 — Internal만 한국화 (옵션 1, qg와 정확히 동일)**: templates는 그대로 두고 README/CHANGELOG/command만 한국화. 거절 (사용자 결정) — 같은 `/project-init` 호출에서 주입되는 페이로드 안에 `llm-guidelines.md`(한국어 explainer)와 다른 templates(전면 영어)가 톤 분리되어 있는 기존 불일치가 그대로 유지된다. 하이브리드 패턴 통일이 더 일관.
- **R3 — Hook 출력 메시지도 함께 한국화**: 거절 (NG1) — user-facing stderr 출력 정책은 docs 정책과 다른 결정 축. 별 PR로 분리해 risk 격리.
- **R4 — `commands/project-init.md` frontmatter `description`도 한국화**: 거절 (NG3) — Claude Code UI surface 값. qg.md가 명시적으로 영어 유지하는 패턴 따름.
- **R5 — `.ko.md` 동반 파일 모델 (qg `28c6ffb` 이전)**: 거절 — devbrew CLAUDE.md *"`.ko.md` 동반 파일 모델은 폐기 (drift 비용 > 이중 노출 가치)"*에서 명시 폐기.

## Concrete Next Action

1. 본 spec.md 검토 후 사용자 승인 (이 디자인 단계의 종료 게이트).
2. superpowers `writing-plans` skill을 invoke해 implementation plan (`docs/superpowers/plans/2026-05-10-project-init-language-policy-plan.md`)을 작성.
3. plan은 12개 파일을 commit-friendly하게 group化 (예: Group A = README+CHANGELOG+plugin.json, Group B = command, Group C = templates).
4. plan 작성 후 superpowers `executing-plans` skill로 단계별 구현 + verification.
