---
name: project-init-templates-industry-alignment
version: 1.0.0
created_at: 2026-05-10
session_id: brainstorm-2026-05-10
status: locked
next_phase: writing-plans
source: superpowers/brainstorming + 웹 리서치 6건 (Conventional Commits v1.0.0, Tim Pope 50/72, GitHub Flow 2026 docs, Trunk-Based Development canonical, Vincent Driessen 2020 reflection, branch naming 2026 best practices)
---

# project-init — Templates Industry Baseline 정렬 디자인 스펙 (v1.3.0)

> **For agentic workers:** 이 문서는 `plugins/project-init/templates/`의 git-workflow 템플릿을 2026년 industry baseline (Conventional Commits v1.0.0, Tim Pope canonical, Atlassian/Driessen 현재 권장사항, trunkbaseddevelopment.com)과 정렬하기 위한 v1.3.0 변경 명세이다. `templates/`는 단순한 정적 파일이 아니라 `hooks/post-tool-use.py`의 `get_branch_pattern()`이 런타임에 파싱하는 enforcement source — 따라서 템플릿 변경은 hook 동작 변경과 동기화되어야 한다. 다음 단계는 superpowers `writing-plans` skill로 implementation plan을 생성하는 것이다.

## Goal

`plugins/project-init/templates/`의 git-workflow 템플릿이 (1) 사실 오류를 시정하고, (2) 누락된 industry-standard 맥락을 추가하며, (3) `hooks/post-tool-use.py`와의 enforcement 정합성을 보존하도록 v1.3.0으로 갱신한다. **branch prefix 확장 (`chore/`, `docs/` 등)은 본 PR scope 아님** — devbrew "lightness default" 원칙에 따라 명시적으로 거부.

## Context / Why

`templates/`는 v1.2.3 시점 다음 4가지 industry baseline 갭이 있다 — 웹 리서치 6건으로 확인:

1. **사실 오류 — Subject line 한계 72자 (`commit-conventions.md:17`)**: Tim Pope canonical (2008, *"A Note About Git Commit Messages"*)와 cbea.ms *"How to Write a Git Commit Message"*는 모두 **subject 50자 / body wrap 72자**의 50/72 룰. `git log --oneline`, GitHub PR 리스트, 80-col 터미널 모두 50자에서 truncate. 현재 templates는 두 한계를 혼동했다.

2. **regex/prose 정합성 결여 — `[\w.-]+`가 `Foo_Bar` 통과**: 3개 strategy의 branch regex `^(feature|fix...)/[\w.-]+$`는 `\w` ≡ `[A-Za-z0-9_]`라 대문자·언더스코어 허용. 그러나 산문은 "kebab-case" 명시. 2026 best practice는 명백히 **lowercase + hyphens only** (URL-friendly, case-insensitive 파일시스템 충돌 방지). `hooks/post-tool-use.py`의 `get_branch_pattern()`이 이 regex를 동적 로드하므로 (line 72), 템플릿 regex가 정책의 single source of truth — 산문과 일치시켜야 enforcement 신뢰 가능.

3. **누락된 맥락 — Driessen 2020 reflection 미인용**: Vincent Driessen 본인이 2020년 3월 원본 Git Flow 글에 "modern web app엔 over-engineered, continuous delivery 팀은 GitHub Flow 권장. Git Flow는 explicitly versioned 소프트웨어에 한정"이라는 reflection을 추가했고, Atlassian은 현재 Git Flow를 "legacy"로 분류. 현재 `git-flow/branch-strategy.md`는 이 caveat 없이 Git Flow를 동등한 옵션으로 제시 — 사용자가 부적절한 선택을 할 정보 비대칭.

4. **누락된 맥락 — Server-side enforcement, SemVer 매핑, Trunk-Based release 패턴 미언급**:
   - **PR process**: client-side hook이 server-side branch protection (required reviews, required status checks, linear history, no force push, signed commits)을 대체할 수 없는데 이 사실 미언급 — 사용자가 "hook이 다 막아준다"는 잘못된 안전감 가질 위험.
   - **Commit conventions**: Conventional Commits v1.0.0 §1이 `fix→PATCH`, `feat→MINOR`, `BREAKING CHANGE→MAJOR` SemVer 매핑을 *명시적으로 정의*. 이는 `release-please`/`semantic-release` 자동화의 근거인데 현재 templates 어디에도 없음.
   - **Trunk-Based**: trunkbaseddevelopment.com canonical은 "release from trunk (tag)" 기본 패턴 + "release branches cut from trunk for legacy version support" 보조 패턴 두 가지를 모두 권장. 현재 `trunk-based/branch-strategy.md`는 "no long-lived branches"만 언급해 release 시점에 사용자가 막막.
   - **`revert` commit type 누락**: CC v1 spec과 Angular convention 모두 `revert`를 표준 타입에 포함하나 현재 templates 9개 type에 누락. `hooks/post-tool-use.py:21` `CONVENTIONAL_COMMIT_PATTERN`도 동일 누락 — sync 필요.

이 4가지 갭을 한 PR로 동시 해결한다. brainstorming 단계에서 사용자가 "B. Recommended" 접근으로 명시적 승인 (G3 branch prefix 확장 제외).

## Goals

- **G1 — 사실 오류 시정**: `commit-conventions.md`의 subject 72자 → 50자, body wrap 72자 명확화.
- **G2 — Regex/prose 정합성 회복**: 3개 strategy의 branch regex를 `[a-z0-9][a-z0-9.-]*` 패턴으로 tighten — `hooks/post-tool-use.py`의 `DEFAULT_BRANCH_PATTERN` (line 19)도 동일하게 동기화.
- **G3 — Industry 맥락 보강**: Git Flow caveat (Driessen 2020), server-side enforcement note, Trunk-Based release 패턴, SemVer 매핑, `revert` type, issue-link footer 예제 추가.
- **G4 — Hook 동기화**: `revert` 타입을 `hooks/post-tool-use.py:21` `CONVENTIONAL_COMMIT_PATTERN` regex와 line 141 error message에 반영.
- **G5 — devbrew Plugin Shape 준수**: `plugin.json` minor bump (`1.2.3` → `1.3.0`), `CHANGELOG.md`에 `[1.3.0] — 2026-05-10` entry.

## Non-goals

- **NG1 — Branch prefix 확장 안 함 (G3 of gap analysis)**: `chore/`, `docs/`, `refactor/` 같은 추가 prefix 도입 안 함. 이유: devbrew CLAUDE.md "defaults to lightness" 원칙 + brainstorming에서 사용자가 "B" 선택 (= "C. Aggressive" 거부). 사용자가 이런 작업이 필요하면 `feature/typo-fix`나 `fix/cleanup`으로 표현 가능 — CC commit type과 branch prefix가 1:1 매핑될 필요 없음.
- **NG2 — `templates/shared/llm-guidelines.md` 변경 안 함**: git templates task 범위 밖. Karpathy 4-bullet baseline은 v1.2.0에서 의도적으로 확정.
- **NG3 — `commands/project-init.md` 변경 안 함**: 렌더링 로직과 placeholder 치환은 그대로. 본 PR은 템플릿 *내용*만 변경.
- **NG4 — `README.md` 변경 안 함**: "Branch Strategies" 표는 그대로 유효. 새로 추가되는 섹션들은 모두 templates 내부에만 들어감.
- **NG5 — PR 풋터 attribution 형식 정렬 안 함 (G13 of gap analysis)**: `Generated with [Claude Code]` vs `Co-Authored-By:` 정렬은 cosmetic. 별 PR에서.
- **NG6 — DCO sign-off 추가 안 함 (G14)**: 프로젝트별 정책. devbrew universal 룰 아님.
- **NG7 — Major bump 안 함**: 새 surface (3개 새 섹션) 추가는 minor에 해당. regex tighten은 *제한*이라 backward compat — 기존에 컨벤션 따랐던 사용자는 영향 없음, 잘못된 이름 쓰던 사용자만 거부됨 (의도된 fix).
- **NG8 — 사용자 프로젝트의 기존 `docs/git-workflow/` 자동 마이그레이션 안 함**: `/project-init` 재실행 시에만 새 템플릿 적용. 기존 사용자가 명시적으로 재실행하지 않으면 영향 없음.

## Constraints

- **C1**: `templates/<strategy>/branch-strategy.md`의 ```regex 블록은 `hooks/post-tool-use.py`의 `get_branch_pattern()` (line 72)이 런타임에 파싱한다. regex 변경은 hook 동작 변경과 직결 — 두 곳을 동시에, 일관되게 갱신해야 함.
- **C2**: `templates/`의 placeholder 토큰 (`{{SCOPE_CONVENTION}}`, `{{MERGE_STRATEGY}}`)은 위치·이름·개수가 보존되어야 한다 — `commands/project-init.md` Step 4b가 정확히 그 토큰을 찾아 치환.
- **C3**: 본 PR이 도입하는 한국어 prose는 v1.2.3 확립 *"English headers/code + Korean explainers"* 하이브리드 패턴을 유지. 헤더 영어, 표 컬럼명 영어, code/regex/명령 영어, prose 한국어.
- **C4**: regex tighten은 backward-compatible 방향 — 기존 컨벤션 따랐던 사용자 (`feature/foo-bar`)는 영향 없음. 더 엄격해질 뿐.
- **C5**: devbrew CLAUDE.md *"every PR touching plugins/<name>/ must bump that plugin's version"* — `plugin.json` minor bump + CHANGELOG entry 동반 필수.
- **C6**: 사용자 가시 stderr 메시지 (`hooks/post-tool-use.py:108-110, 141`)는 영어 유지 — terminal output, 별도 한국화 정책 결정 없음.
- **C7**: 새로 추가되는 모든 섹션은 *기존 섹션 사이에 삽입*하는 방식 — 헤더 anchor 변경 없음 (devbrew CLAUDE.md "TOC drift 시 cite-by-anchor 깨짐" 우려 회피, 비록 templates는 300줄 미만이라 TOC 면제이지만 일관성).

## Acceptance Criteria

### `commit-conventions.md` (shared)

- **AC1**: `## Rules` 섹션의 subject line 룰이 "최대 50자" (50자에서 truncate되는 도구 명시: `git log --oneline`, GitHub PR list, 80-col terminal). body wrap "72자" 별도 명시.
- **AC2**: `## Types` 표에 `| revert | 이전 commit 되돌림 | revert: feat(auth): add OAuth2 login |` row 추가 (마지막 row로). 다른 row 변경 없음.
- **AC3**: 새 섹션 `## SemVer Mapping`이 `## Breaking Changes` 다음에 추가 — 4줄 안에 `fix→PATCH`, `feat→MINOR`, `BREAKING CHANGE→MAJOR` 매핑 + Conventional Commits v1.0.0 §1 출처 cite. 자동화 도구 `release-please`/`semantic-release` 한 줄 언급.
- **AC4**: `## AI-Assisted Commits` 다음 또는 footer 관련 부분에 issue-link 풋터 예제 추가 (`Closes: #N`, `Refs: #N` 두 종류) — Conventional Commits v1.0.0 footer pattern으로 cite.
- **AC5**: 기존 `## Format`, `## Scope`, `## Good Examples`, `## Bad Examples` 섹션은 변경 없음. `{{SCOPE_CONVENTION}}` placeholder 위치·이름 보존.

### `pr-process.md` (shared)

- **AC6**: 새 섹션 `## Server-Side Enforcement`가 `## Review Checklist` 다음에 추가 — 6개 branch protection 항목 bullet으로 명시: required PR reviews / required status checks / linear history (optional) / no force push to protected branches / required signed commits (optional) / dismiss stale reviews on push. **첫 줄 강조**: "이 플러그인의 hook은 client-side 검증만 — server-side enforcement는 GitHub Settings → Branches → Branch protection rules 또는 Repository rulesets에서 별도 설정 필요." GitHub 공식 docs URL cite.
- **AC7**: 기존 `## PR Body Template`, `## Creating a PR`, `## PR Title`, `## Merge Strategy`, `## Plugin Integration` 섹션은 변경 없음. `{{MERGE_STRATEGY}}` placeholder 보존.

### `git-flow/branch-strategy.md`

- **AC8**: 새 섹션 `## When NOT to use Git Flow`가 `## Model` 다음에 (그리고 `## Branch Naming Pattern` 앞에) 추가 — Driessen 2020 reflection 1줄 인용 (출처 명시): "continuous delivery → GitHub Flow / Trunk-Based가 더 적합. Git Flow는 versioned releases (mobile, desktop, OSS library) 한정". Atlassian "legacy" 분류 사실 cite.
- **AC9**: `## Branch Naming Pattern` ```regex 블록이 `^(feature|fix|release|hotfix)/[a-z0-9][a-z0-9.-]*$`로 변경. 산문에 "lowercase + hyphens only — URL-friendly, case-insensitive 충돌 방지" 한 줄 추가.
- **AC10**: 기존 `## Branch Lifecycle`, `## Rules for Claude` 변경 없음. `{{MERGE_STRATEGY}}` placeholder 없음 (이 파일에는 원래 없음).

### `github-flow/branch-strategy.md`

- **AC11**: ```regex 블록이 `^(feature|fix)/[a-z0-9][a-z0-9.-]*$`로 변경. 산문에 "lowercase + hyphens only" 한 줄 추가.
- **AC12**: 다른 섹션 변경 없음.

### `trunk-based/branch-strategy.md`

- **AC13**: ```regex 블록이 `^(feature|fix)/[a-z0-9][a-z0-9.-]*$`로 변경. 산문에 "lowercase + hyphens only" 한 줄 추가.
- **AC14**: 새 섹션 `## Releasing`이 `## Feature Flags` 다음에 (그리고 `## Rules for Claude` 앞에) 추가 — 두 패턴 명시: (1) **Default**: trunk에서 직접 tag (`git tag -a v1.2.0 -m "Release v1.2.0"`), (2) **Legacy version support 필요 시**: `release/v1.x` 브랜치를 trunk에서 cut, hotfix를 trunk에 commit 후 release branch로 cherry-pick. trunkbaseddevelopment.com 출처 cite.
- **AC15**: `claude-md-section.md` 변경 없음 (3개 strategy 모두).

### `hooks/post-tool-use.py`

- **AC16**: Line 19 `DEFAULT_BRANCH_PATTERN`이 `re.compile(r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$")`로 변경 (template fallback과 일치).
- **AC17**: Line 21 `CONVENTIONAL_COMMIT_PATTERN`이 `^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?!?:\s.+`로 변경 (`revert` 추가).
- **AC18**: Line 141 error message 문자열의 types 목록에 `revert` 추가 — 표시 순서는 alphabetical 또는 frequency 기준 일관성.
- **AC19**: 다른 hook 로직 변경 없음 — `validate_branch`, `validate_commit`, `get_branch_pattern`, `guess_commit_type`, kill switch 처리 모두 그대로.

### Plugin metadata

- **AC20**: `plugin.json`의 `version` 필드가 `1.2.3`에서 `1.3.0`으로 변경. 다른 필드 변경 없음.
- **AC21**: `CHANGELOG.md`에 `## [1.3.0] — 2026-05-10` entry 추가. Keep a Changelog 카테고리 영어, prose 한국어. 카테고리 사용:
  - `### Added` — 새 섹션들 (SemVer Mapping, Server-Side Enforcement, When NOT to use Git Flow, Releasing, issue-link footer 예제), `revert` type
  - `### Changed` — branch regex tighten (3개 파일), `DEFAULT_BRANCH_PATTERN` 동기화, `CONVENTIONAL_COMMIT_PATTERN` 확장
  - `### Fixed` — subject line 한계 50자 (G1 사실 오류)
- **AC22**: 본 PR이 도입한 모든 변경의 출처 (Tim Pope, cbea.ms, Driessen 2020, trunkbaseddevelopment.com, GitHub docs, CC v1.0.0 §1)가 CHANGELOG entry 안에 한 줄씩 cite — Law 3 compounding (미래 reviewer가 "왜 이 숫자/패턴인가" 추적 가능).

## Files to Modify

### 변경 (편집)
1. `plugins/project-init/templates/shared/commit-conventions.md` — AC1–AC5
2. `plugins/project-init/templates/shared/pr-process.md` — AC6–AC7
3. `plugins/project-init/templates/git-flow/branch-strategy.md` — AC8–AC10
4. `plugins/project-init/templates/github-flow/branch-strategy.md` — AC11–AC12
5. `plugins/project-init/templates/trunk-based/branch-strategy.md` — AC13–AC14
6. `plugins/project-init/hooks/post-tool-use.py` — AC16–AC19
7. `plugins/project-init/.claude-plugin/plugin.json` — AC20
8. `plugins/project-init/CHANGELOG.md` — AC21–AC22

### 변경 없음 (명시적)
- `plugins/project-init/README.md` — "Branch Strategies" 표 그대로 유효. 만약 미래에 README를 갱신한다면 새 섹션들에 대한 참조 추가 가능하지만 본 PR scope 아님.
- `plugins/project-init/commands/project-init.md` — 렌더링 로직 동일.
- `plugins/project-init/templates/shared/llm-guidelines.md` — NG2.
- `plugins/project-init/templates/<strategy>/claude-md-section.md` 3개 — anchor 블록, 변경 없음.

## Verification Plan

### Static checks
- **V1**: `grep -rE "\{\{[A-Z_]+\}\}" plugins/project-init/templates/` 결과의 매치 문자열·매치 수가 변경 전/후 동일 (placeholder 보존 — C2).
- **V2**: 모든 `branch-strategy.md` 3개 파일의 ```regex 블록이 정확히 1개씩 존재하고, 패턴이 `[a-z0-9][a-z0-9.-]*`를 포함 (`get_branch_pattern()` 파싱 보존).
- **V3**: `commit-conventions.md`의 `## Types` 표 row 수가 정확히 10개 (`revert` 포함).
- **V4**: `hooks/post-tool-use.py:21` regex가 `revert`를 포함하는지 `grep` 확인.

### Behavioral checks (수동)
- **V5**: Hook 동작 확인 — `feature/foo-bar`, `fix/issue-123` PASS / `Foo_Bar`, `feature/Foo-Bar`, `feature/foo_bar` FAIL (regex tighten). Test 방법: `python3` REPL에서 `re.compile(...).match(...)` 직접 호출.
- **V6**: Hook commit validation — `revert: feat(auth): add OAuth2`, `revert(api): undo breaking change` PASS (새 type).
- **V7**: `/project-init` smoke test — 임시 빈 디렉토리에서 실행 후 `docs/git-workflow/branch-strategy.md`의 regex 블록이 `[a-z0-9][a-z0-9.-]*` 패턴인지 grep 확인.
- **V8**: 같은 smoke test에서 `docs/git-workflow/commit-conventions.md`에 `## SemVer Mapping` 섹션 존재 확인.
- **V9**: 같은 smoke test에서 `docs/git-workflow/pr-process.md`에 `## Server-Side Enforcement` 섹션 존재 확인.

### CHANGELOG / metadata
- **V10**: `plugin.json`의 `version`이 정확히 `1.3.0`.
- **V11**: `CHANGELOG.md`의 `[1.3.0]` entry가 `### Added`, `### Changed`, `### Fixed` 세 카테고리 모두 포함.
- **V12**: CHANGELOG entry 안에 6개 출처 cite (Tim Pope, cbea.ms, Driessen 2020, trunkbaseddevelopment.com, GitHub docs, CC v1.0.0).

### devbrew Plugin Shape 준수
- **V13**: `README.md` "Hooks Installed" 섹션 그대로 유효 (kill switch 변경 없음).
- **V14**: `README.md` "Principles Instantiated" 섹션 그대로 유효.

## Rejected Alternatives

### A. Surgical (factual fixes only)
- **거부 이유**: 사용자가 brainstorming에서 명시적으로 "B. Recommended"를 선택. 사실 오류만 시정하면 누락된 industry 맥락 (Driessen caveat, server-side enforcement, Trunk-Based release 패턴)이 그대로 남아 사용자가 부적절한 선택을 할 위험 지속.

### C. Aggressive (B + branch prefix 확장)
- **거부 이유**: devbrew CLAUDE.md "defaults to lightness" + 사용자 memory `feedback_devbrew_design_lightness.md` 명시. CC commit type과 branch prefix는 1:1 매핑될 필요 없음 — `chore/` branch에서 `chore:` commit이 자연스러워 보이지만 실제로는 branch prefix가 *작업 종류* (feature 추가 vs 버그 수정), commit type은 *변경 종류* (코드/문서/빌드/테스트 등)로 다른 분류 축. 강제로 정합시키면 의미 손실.

### D. Major bump (1.2.3 → 2.0.0)
- **거부 이유**: 새 섹션 추가는 backward-compat. regex tighten도 기존 컨벤션 따르던 사용자엔 영향 없음 — 잘못된 이름 쓰던 사용자만 거부됨 (의도된 fix). devbrew SemVer 정의 (CLAUDE.md "minor = 새 surface")에 minor가 정확히 부합.

### E. Branch prefix 확장은 안 하지만 산문에서 "추가 type 사용 시 → ## Customizing 섹션 참고" 안내 추가
- **거부 이유**: out-of-the-box 정책은 단순하게, 커스터마이징은 사용자가 자기 프로젝트의 `docs/git-workflow/branch-strategy.md`를 직접 편집하면 되도록 (현재 hook이 이미 동적 로드 — `get_branch_pattern()` line 72). devbrew CLAUDE.md "templates는 static 시작점, 사용자가 fork해서 진화" 방향과 일치. 별도 안내 섹션 없음으로 minimal.

### F. PR template footer 정렬 (G13)
- **거부 이유**: cosmetic. 별 PR에서.

### G. DCO sign-off 추가 (G14)
- **거부 이유**: 프로젝트별 정책 (Linux kernel, CNCF projects는 필수, 나머지 다수는 선택). devbrew universal 룰로 못 씀. 만약 사용자 프로젝트가 DCO 필요하면 자기 `docs/git-workflow/pr-process.md`에 직접 추가하면 됨.

## Metadata

- **Source**: `superpowers/brainstorming` 결과 + 웹 리서치 6건
- **Brainstorming session**: 2026-05-10
- **Approval**: 사용자가 "B. Recommended" 선택으로 명시 승인
- **Target version**: `1.2.3` → `1.3.0` (minor bump per devbrew Plugin Shape)
- **Estimated diff scope**: 8 files modified, 0 added, 0 deleted. ~150 LOC 변경 (대부분 새 섹션 추가, regex 1자 변경).
- **Risk class**: low — backward-compatible regex tighten, 새 섹션 추가, hook regex 1줄 변경. 기존 사용자 프로젝트에 영향 없음 (재실행 시에만 새 템플릿 적용).
- **Quality gates**: Gate 2 (PR review)에서 (1) 새 prose의 한국어 톤 일관성, (2) regex 패턴의 ReDoS 안전성, (3) CHANGELOG 출처 cite 정확성 확인 권장.
- **Next phase**: `superpowers/writing-plans`로 단계별 implementation plan 생성 — 8개 파일 변경의 순서·의존성·롤백 포인트 정의.
