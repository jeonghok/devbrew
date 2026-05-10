# project-init Language Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `plugins/project-init/` docs를 qg precedent (Korean-primary internal) + `llm-guidelines.md` 하이브리드 패턴 (English headers/code + Korean explainers in templates)으로 정렬한다 — 12개 파일 변경, version `1.2.2` → `1.2.3`.

**Architecture:** 5개 commit으로 분할 — (1) verification baseline capture → (2) internal docs (README + CHANGELOG entry stub + command) → (3) shared templates (commit-conventions + pr-process) → (4) per-strategy templates (3× branch-strategy + 3× claude-md-section) → (5) version bump + CHANGELOG entry finalize + integration verification. 각 commit은 독립 reviewable, 그러나 plugin.json bump는 마지막에만 — surface 변화 boundary 명확화.

**Tech Stack:** Markdown (no compilation), `grep` / `git diff` / `cat` 기반 verification, no test framework — verification은 deterministic shell 명령.

**Spec:** [`docs/superpowers/specs/2026-05-10-project-init-language-policy-design.md`](../specs/2026-05-10-project-init-language-policy-design.md)

---

## Global Notes for Implementer

**Markdown nesting escape:** plan 안에서 markdown 컨텐츠를 보여주는 코드 블록은 nested fence를 표현하기 위해 ` \`\`\` `(escape된 백틱 3개)를 사용한 곳이 있다. **실제 파일에 쓸 때는 일반 백틱 3개 (\`\`\`)로 작성**한다. 즉 `\`\`\`bash`로 보이는 부분은 실제 파일에 ` ```bash `로 들어간다.

**Korean primary 톤 가이드** — prose 안에서 영어 보존 대상:
- 식별자: `feat`, `fix`, `develop`, `main`, `feature/*`, `release/v1.2.0`, `BREAKING CHANGE` 등
- code/명령: `git checkout`, `gh pr create`, regex, `${CLAUDE_PLUGIN_ROOT}`
- table 컬럼명: `Use`, `Example`, `When to use`, `From`, `Merge to`
- 강조 토큰: `**ALWAYS**`, `**NEVER**`
- 표준 카테고리: `### Added`, `### Changed`, `### Removed`, `### Security` (Keep a Changelog)
- anchor 헤더: `## Git Workflow`, `## LLM Coding Guidelines` (devbrew CLAUDE.md와 coupling)

**Verification baseline 파일** — 모두 `/tmp/`에 저장. session reboot 시 사라지므로 Task 1 → 9 한 세션 내 실행 권장. 실패해도 Task 1을 재실행하면 복구.

---

## Pre-flight: Branch & State Check

Plan 실행 전 정확히 한 번만 실행 (이미 spec commit으로 `feature/project-init-language-policy` 브랜치에 있어야 함):

```bash
git branch --show-current
# Expected: feature/project-init-language-policy

git log --oneline -1
# Expected: c770822 docs(project-init): add language policy design spec
```

만약 다른 브랜치에 있다면 `git checkout feature/project-init-language-policy` 후 진행.

---

## Task 1: Verification Baseline Capture

스펙의 V3 (placeholder 보존)·V4 (Conventional Commits 식별자 보존) 같은 cross-task invariant를 확인하려면 변경 *전* 상태를 기록해둬야 한다. 이 task는 코드를 바꾸지 않고 baseline만 capture한다.

**Files:**
- Create: `/tmp/project-init-baseline-placeholders.txt`
- Create: `/tmp/project-init-baseline-cc-identifiers.txt`
- Create: `/tmp/project-init-baseline-claude-md-anchors.txt`

- [ ] **Step 1: Capture placeholder baseline (V3)**

```bash
grep -rEn "\{\{[A-Z_]+\}\}" plugins/project-init/templates/ | sort > /tmp/project-init-baseline-placeholders.txt
cat /tmp/project-init-baseline-placeholders.txt
```

Expected output:
```
plugins/project-init/templates/github-flow/claude-md-section.md:7:- PR: {{MERGE_STRATEGY}}, see `docs/git-workflow/pr-process.md`
plugins/project-init/templates/git-flow/claude-md-section.md:<line>:- ... {{MERGE_STRATEGY}} ...
plugins/project-init/templates/shared/commit-conventions.md:38:{{SCOPE_CONVENTION}}
plugins/project-init/templates/shared/pr-process.md:41:Default: **{{MERGE_STRATEGY}}**
plugins/project-init/templates/trunk-based/claude-md-section.md:<line>:- ... {{MERGE_STRATEGY}} ...
```

이 파일을 마지막 task의 V3 비교 baseline으로 사용한다.

- [ ] **Step 2: Capture Conventional Commits 식별자 baseline (V4)**

```bash
grep -rE "(^|[^a-z])(feat|fix|docs|style|refactor|perf|test|build|ci|chore|BREAKING CHANGE)([^a-z]|$)" plugins/project-init/templates/shared/commit-conventions.md > /tmp/project-init-baseline-cc-identifiers.txt
wc -l /tmp/project-init-baseline-cc-identifiers.txt
```

Expected: `wc -l`이 30줄 이상 (table에 모든 type identifier가 등장 + 예시).

- [ ] **Step 3: Capture `## Git Workflow` anchor baseline (V6)**

```bash
grep -h "^## " plugins/project-init/templates/*/claude-md-section.md > /tmp/project-init-baseline-claude-md-anchors.txt
cat /tmp/project-init-baseline-claude-md-anchors.txt
```

Expected output (정확히 3줄, 모두 영어):
```
## Git Workflow
## Git Workflow
## Git Workflow
```

- [ ] **Step 4: 변경 전 git diff 확인 (commit 없이 baseline 단계만)**

```bash
git status
```

Expected: `nothing to commit, working tree clean` (baseline 파일은 `/tmp/`라 git에 안 들어감).

이 task는 commit 없음. 다음 task로 진행.

---

## Task 2: Internal Docs Group — README

`plugins/project-init/README.md`를 Korean-primary로 재작성. qg `README.md` (현재 `plugins/quality-gates/README.md`)의 톤·헤딩 패턴을 reference로 사용.

**Files:**
- Modify: `plugins/project-init/README.md` (현재 83줄 → 유사 길이의 한국어 재작성)

**참고 톤 (qg README에서 추출):**
- 헤딩: "인스턴스화한 원칙", "구조", "설치된 Hook", "사용", "사전 요건", "설정"
- 본문 prose 한국어, code/branch/file/regex 영어
- 표 헤더는 한국어, 표 안의 식별자/예시는 영어
- 첫 줄 정체성 한 줄 + "이 플러그인은 다음 devbrew 법칙·원칙을 인스턴스화합니다 ([...] 참고):" 패턴

- [ ] **Step 1: README.md를 다음 내용으로 전면 교체**

```markdown
# project-init 플러그인

Claude Code용 git workflow + LLM coding baseline 초기화 플러그인. 어떤 프로젝트에든 branching strategy, commit conventions, PR process 룰을 생성한다.

## 아키텍처

\`\`\`
plugins/project-init/
├── .claude-plugin/plugin.json       # 플러그인 메타데이터
├── README.md                        # 본 파일
├── commands/
│   └── project-init.md              # /project-init — 인터랙티브 셋업
├── hooks/
│   ├── hooks.json                   # PostToolUse hook 설정
│   └── post-tool-use.py             # 브랜치 명명 + 커밋 메시지 검증기
└── templates/
    ├── shared/
    │   ├── commit-conventions.md    # Conventional Commits 룰 (모든 strategy 공통)
    │   ├── llm-guidelines.md        # Karpathy LLM coding baseline (모든 strategy 공통)
    │   └── pr-process.md            # PR template과 merge 전략 (모든 strategy 공통)
    ├── github-flow/
    │   ├── claude-md-section.md     # CLAUDE.md 주입 템플릿
    │   └── branch-strategy.md       # 브랜치 룰 + 명명 패턴
    ├── git-flow/
    │   ├── claude-md-section.md
    │   └── branch-strategy.md
    └── trunk-based/
        ├── claude-md-section.md
        └── branch-strategy.md
\`\`\`

## 동작 방식

1. `/project-init` 실행
2. branching strategy 선택 (GitHub Flow / Git Flow / Trunk-based)
3. 커스터마이징 질문 2–3개 답변 (commit scope, merge strategy)
4. 플러그인이 다음을 생성:
   - `CLAUDE.md` — `## LLM Coding Guidelines` (4-bullet Karpathy baseline) + `## Git Workflow` (terse anchor, `docs/git-workflow/` 참조)
   - `docs/git-workflow/branch-strategy.md` — 팀의 브랜치 룰
   - `docs/git-workflow/commit-conventions.md` — Conventional Commits 룰
   - `docs/git-workflow/pr-process.md` — PR 템플릿과 리뷰 체크리스트

## 기능

| 컴포넌트 | 역할 |
|---------|------|
| **`/project-init` command** | 인터랙티브 셋업 — strategy 선택, 룰 생성 |
| **PostToolUse hook** | 브랜치 이름·커밋 메시지 포맷 자동 검증 |
| **LLM Coding Guidelines** | Karpathy 유래 4-bullet 행동 baseline을 CLAUDE.md에 주입 |
| **Templates** | 3개 branching strategy의 사전 작성된 룰 |

## 브랜치 전략

| Strategy | Branches | Best for |
|----------|----------|----------|
| **GitHub Flow** | `main` + `feature/*` / `fix/*` | 작은 팀, CI/CD, continuous deployment |
| **Git Flow** | `main` + `develop` + `feature/*` / `fix/*` / `release/*` / `hotfix/*` | release cycle, version 관리 |
| **Trunk-based** | `main` + 단명 `feature/*` / `fix/*` | 빠른 배포, feature flag |

## 통합

다른 플러그인과 함께 동작:
- **commit-commands**: `/commit`과 `/commit-push-pr`이 CLAUDE.md 룰을 읽어 메시지 포맷 적용
- **superpowers**: `using-git-worktrees`가 `docs/`의 브랜치 명명 컨벤션을 따름
- **quality-gates**: PR 생성 시 quality 파이프라인 자동 트리거

## 설치된 Hook

- **`PostToolUse` (Bash matcher)** — 브랜치 명·커밋 메시지 검증. **왜 hook인가 (skill이 아닌)?**: 검증은 모델 attention 여부와 무관하게 모든 Bash invocation에 발화해야 한다. skill은 모델이 invoke하는 단위라 action 레이어에서의 결정적 실행을 보장하지 못함. hook은 모든 Bash tool use 후 무조건 실행됨.
- **Kill switch:** `DEVBREW_DISABLE_PROJECT_INIT=1`로 비활성화하거나, 더 좁은 단위로 `DEVBREW_SKIP_HOOKS=project-init:post-tool-use` 사용 (devbrew CLAUDE.md §Plugin Shape).

## 인스턴스화한 원칙

이 플러그인은 다음 devbrew 법칙·원칙을 인스턴스화합니다
([`docs/philosophy/devbrew-harness-philosophy.md`](../../docs/philosophy/devbrew-harness-philosophy.md) 참고):

- **Law 1 (Clarity Before Code)** — 4-bullet LLM Coding Guidelines (Karpathy 유래: 가정 명시, overengineering 금지, surgical scope, verifiable 성공 기준)을 프로젝트 boundary에 주입해 Claude가 매 session start마다 읽도록.
- **Law 3 (Compounding)** — PostToolUse hook이 브랜치 명명과 Conventional Commits 포맷을 지속적으로 강제; 컨벤션 drift를 action 레이어에서 잡음.
- **Plugin shape — minimal pointer pattern** — CLAUDE.md는 짧은 anchor만 (8줄 LLM 블록 + Git Workflow 요약), 상세는 `docs/git-workflow/`에 거주. CLAUDE.md bloat 방지 + 룰 discoverability 양립.

## 사용

\`\`\`
/project-init    # 인터랙티브 git workflow 셋업 시작
\`\`\`
```

(주의: 위 코드 블록 안의 ` \`\`\` `는 escape — 실제 파일에는 일반 백틱 3개로 작성. 마크다운 표현 한계로 escape 표기.)

- [ ] **Step 2: 헤딩 검증**

```bash
grep "^## " plugins/project-init/README.md
```

Expected output (정확히 한국어 헤딩):
```
## 아키텍처
## 동작 방식
## 기능
## 브랜치 전략
## 통합
## 설치된 Hook
## 인스턴스화한 원칙
## 사용
```

- [ ] **Step 3: qg와 톤 비교 (V8)**

```bash
diff <(grep "^## " plugins/project-init/README.md) <(grep "^## " plugins/quality-gates/README.md) || echo "(헤딩이 정확히 같지는 않지만 톤이 일치하면 OK — 시각적 비교)"
```

`## 인스턴스화한 원칙`, `## 설치된 Hook`, `## 사용`이 양쪽 모두에 존재하는지 확인. 다른 헤딩들은 플러그인별 고유 컨텐츠이므로 1:1 일치는 불필요.

- [ ] **Step 4: Branch coupling 보존 확인**

```bash
grep "feature/" plugins/project-init/README.md && grep "fix/" plugins/project-init/README.md && grep "kebab-case" plugins/project-init/README.md
```

Expected: 각 grep이 매치 라인을 출력 — 영어 식별자가 한국어 본문 안에서 보존됐는지 확인.

- [ ] **Step 5: Commit하지 않고 다음 task로** (Group A를 한 commit으로 묶음)

---

## Task 3: Internal Docs Group — CHANGELOG

`plugins/project-init/CHANGELOG.md`를 Korean-primary로 재작성. Keep a Changelog 카테고리 헤더 (`### Added`, `### Changed`, `### Removed`, `### Security`, `### Fixed`)는 영어 유지, 본문 prose만 한국어.

**Files:**
- Modify: `plugins/project-init/CHANGELOG.md`

- [ ] **Step 1: CHANGELOG.md를 다음 내용으로 전면 교체**

(주의: `[1.2.3]` entry 자체는 Task 8에서 추가. 본 Task에서는 기존 entry들만 한국화.)

```markdown
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
```

- [ ] **Step 2: 카테고리 헤더 영어 보존 검증**

```bash
grep -E "^### (Added|Changed|Removed|Security|Fixed|Deprecated)$" plugins/project-init/CHANGELOG.md | sort -u
```

Expected output (Keep a Changelog 표준 카테고리만 영어로):
```
### Added
### Changed
### Removed
### Security
```

(이 시점에는 `Fixed`/`Deprecated`가 없을 수 있음 — 기존 entry에 등장한 것만 표시).

- [ ] **Step 3: 버전·날짜 변경 없음 확인**

```bash
grep -E "^## \[" plugins/project-init/CHANGELOG.md
```

Expected output (변경 전과 100% 동일):
```
## [1.2.2] — 2026-05-10
## [1.2.1] — 2026-05-07
## [1.2.0] — 2026-05-07
## [1.1.0] — 2026-04-12
```

- [ ] **Step 4: 다음 task로 (commit 보류)**

---

## Task 4: Internal Docs Group — Command 본문 한국화

`plugins/project-init/commands/project-init.md` 본문을 한국어로. frontmatter (특히 `description`)와 `${CLAUDE_PLUGIN_ROOT}`, `<strategy>`, `{{...}}` placeholder는 영어 그대로.

**Files:**
- Modify: `plugins/project-init/commands/project-init.md`

- [ ] **Step 1: frontmatter는 그대로 유지하고 본문만 한국어로 교체**

frontmatter (1–4줄)는 변경 없이 보존:
```markdown
---
description: "Initialize git workflow rules + LLM coding baseline for the project (branch strategy, commit conventions, PR process, Karpathy-derived LLM guidelines)"
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
```

5줄 이후 전체를 다음으로 교체:

```markdown
# project-init

branching strategy 템플릿을 선택해 git workflow 룰을 초기화하고, 프로젝트의 CLAUDE.md와 docs/ 파일을 생성한다.

## 지시사항

다음 단계를 정확한 순서대로 따른다.

### Step 1: 프로젝트 상태 감지

1. 프로젝트 root에 `CLAUDE.md`가 존재하는지 확인
2. 존재한다면 `## Git Workflow` 섹션이 이미 있는지 확인
3. `docs/git-workflow/` 디렉토리가 존재하는지 확인

기존 Git Workflow 설정이 발견되면 사용자에게 묻는다:
> "기존 git workflow 룰이 감지됐습니다. 새 템플릿으로 교체할까요?"

사용자가 거절하면 중단.

### Step 2: branching strategy 선택

다음 3개 옵션을 사용자에게 제시:

| Strategy | Branches | Best for |
|----------|----------|----------|
| **GitHub Flow** | `main` + `feature/*` / `fix/*` | 작은 팀, CI/CD, continuous deployment |
| **Git Flow** | `main` + `develop` + `feature/*` / `fix/*` / `release/*` / `hotfix/*` | release cycle을 가진 팀, version 관리 |
| **Trunk-based** | `main` + 단명 `feature/*` / `fix/*` | 빠른 배포, feature flag 팀 |

사용자가 선택할 때까지 대기.

### Step 3: 커스터마이징 질문

선택된 strategy에 따라 다음 질문 진행:

**모든 strategy 공통:**

1. **Commit scope 컨벤션** — "커밋 scope를 어떻게 정의할까요?"
   - module/디렉토리 이름 기준 (예: `feat(auth):`, `fix(api):`)
   - feature 영역 기준 (예: `feat(login):`, `fix(checkout):`)
   - scope 없음 (예: `feat:`, `fix:`)

2. **기본 merge 전략** — "PR의 기본 merge 전략은?"
   - Squash merge (clean history 권장)
   - Merge commit (모든 commit 보존)
   - Rebase (linear history)

**Git Flow 추가:**

3. **Release branch 명명** — "release 브랜치 포맷?"
   - `release/v*` (예: `release/v1.2.0`) — default
   - 커스텀 포맷

### Step 4: 파일 생성

선택된 strategy와 답변을 바탕으로 다음 파일들을 생성한다.

**중요:** template 파일들은 `${CLAUDE_PLUGIN_ROOT}/templates/`에 있다. 읽고, placeholder를 치환하고, 프로젝트에 쓴다.

#### 4a: Templates 읽기

플러그인에서 다음 파일을 읽는다:
- `${CLAUDE_PLUGIN_ROOT}/templates/shared/llm-guidelines.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/<strategy>/claude-md-section.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/<strategy>/branch-strategy.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/shared/commit-conventions.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/shared/pr-process.md`

여기서 `<strategy>`는 `github-flow`, `git-flow`, `trunk-based` 중 하나.

#### 4b: Placeholder 치환

template 컨텐츠에서 다음 placeholder들을 치환:

| Placeholder | 치환 값 |
|-------------|---------|
| `{{SCOPE_CONVENTION}}` | Step 3 질문 1의 scope 룰 (예: "Scope by module/directory name: `auth`, `api`, `ui`") |
| `{{MERGE_STRATEGY}}` | Step 3 질문 2의 merge 전략 (예: "squash merge") |

#### 4c: CLAUDE.md 섹션 쓰기

CLAUDE.md는 project-init이 관리하는 두 섹션을 다음 순서로 갖는다:

1. `## LLM Coding Guidelines` (`shared/llm-guidelines.md`에서, placeholder 없음)
2. `## Git Workflow` (`<strategy>/claude-md-section.md`에서, placeholder 치환 후)

현재 CLAUDE.md 상태에 따라 다음 matrix 적용:

| State | Action |
|---|---|
| CLAUDE.md 없음 | 두 섹션을 LLM Guidelines 먼저, Git Workflow 다음 순서로 파일 생성 |
| 존재, 두 섹션 모두 없음 | 파일 끝에 두 섹션 append (LLM Guidelines 먼저, Git Workflow 다음) |
| 존재, `## Git Workflow`만 있음 | `## LLM Coding Guidelines`를 `## Git Workflow` 바로 위에 삽입; Git Workflow 컨텐츠를 새 template로 교체 |
| 존재, `## LLM Coding Guidelines`만 있음 | LLM Guidelines 컨텐츠를 새 template로 교체; `## Git Workflow`를 그 바로 다음에 append |
| 존재, 두 섹션 모두 있음 | 각 섹션의 컨텐츠를 in-place로 독립 교체 |

모든 state에서 비-관리 컨텐츠 (다른 헤딩, 단락, 코드 블록)는 그대로 보존. 관리되는 두 섹션은 인접 (사이에 다른 컨텐츠 없음) 유지 필수.

#### 4d: docs/git-workflow/ 파일 쓰기

`docs/git-workflow/` 디렉토리가 없으면 생성. 다음 3개 파일 작성:

1. `docs/git-workflow/branch-strategy.md` — `templates/<strategy>/branch-strategy.md`에서
2. `docs/git-workflow/commit-conventions.md` — `templates/shared/commit-conventions.md`에서 (placeholder 치환 후)
3. `docs/git-workflow/pr-process.md` — `templates/shared/pr-process.md`에서 (placeholder 치환 후)

### Step 5: 확인

생성 결과 보고:

> **{strategy 이름}** 전략으로 git workflow + LLM coding guidelines 초기화 완료.
>
> 생성/업데이트된 파일:
> - `CLAUDE.md` — `## LLM Coding Guidelines`와 `## Git Workflow` 섹션 추가
> - `docs/git-workflow/branch-strategy.md` — 브랜치 룰
> - `docs/git-workflow/commit-conventions.md` — Commit 컨벤션
> - `docs/git-workflow/pr-process.md` — PR 프로세스
>
> `project-init` 플러그인 hook이 브랜치 이름과 commit 메시지를 자동 검증합니다.
> 4-bullet LLM Coding Guidelines baseline은 Andrej Karpathy의 LLM 코딩 관찰에서 파생.
> 간결한 git 작업을 위해 `/commit` 또는 `/commit-push-pr` (commit-commands 플러그인) 사용.
```

- [ ] **Step 2: frontmatter 보존 검증**

```bash
head -4 plugins/project-init/commands/project-init.md
```

Expected output (정확히 변경 전과 동일):
```
---
description: "Initialize git workflow rules + LLM coding baseline for the project (branch strategy, commit conventions, PR process, Karpathy-derived LLM guidelines)"
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
```

`description`이 영어인지 (AC3, NG3) 명시 확인.

- [ ] **Step 3: Step 헤딩 한국어 검증**

```bash
grep "^### Step " plugins/project-init/commands/project-init.md
```

Expected output:
```
### Step 1: 프로젝트 상태 감지
### Step 2: branching strategy 선택
### Step 3: 커스터마이징 질문
### Step 4: 파일 생성
### Step 5: 확인
```

- [ ] **Step 4: 환경 변수와 placeholder 영어 보존 검증**

```bash
grep -c "\${CLAUDE_PLUGIN_ROOT}" plugins/project-init/commands/project-init.md
grep -c "<strategy>" plugins/project-init/commands/project-init.md
grep -c "{{SCOPE_CONVENTION}}" plugins/project-init/commands/project-init.md
grep -c "{{MERGE_STRATEGY}}" plugins/project-init/commands/project-init.md
```

Expected: 각각 변경 전과 같은 수의 매치 (≥1).

- [ ] **Step 5: Group A commit (README + CHANGELOG + command)**

```bash
git add plugins/project-init/README.md plugins/project-init/CHANGELOG.md plugins/project-init/commands/project-init.md
git commit -m "$(cat <<'EOF'
docs(project-init): rewrite README/CHANGELOG/command Korean-primary

qg precedent (commit 28c6ffb) 정렬 — devbrew-internal docs (README +
CHANGELOG + 사용자 가시 command 본문)을 Korean-primary로 재작성. 식별자,
code, branch 이름, regex, frontmatter description은 영어 유지.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: 1 commit, 3 files changed.

---

## Task 5: Shared Templates — commit-conventions.md

`templates/shared/commit-conventions.md`를 하이브리드 패턴(English headers/code/identifiers + Korean prose)으로 변환.

**Files:**
- Modify: `plugins/project-init/templates/shared/commit-conventions.md`

- [ ] **Step 1: 파일 전체를 다음으로 교체**

```markdown
# Commit Conventions

이 프로젝트는 [Conventional Commits](https://www.conventionalcommits.org/)를 따른다.

## Format

\`\`\`
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
\`\`\`

## Rules

- **Subject line**: 명령형 동사 ("add" — "added" 아님), 최대 72자, 마침표 없음
- **Body**: 선택, *what*이 아니라 *why*를 설명, 72자에서 wrap
- **Footer**: breaking change에는 `BREAKING CHANGE:`, AI 보조 commit에는 `Co-Authored-By:`

## Types

| Type | When to use | Example |
|------|------------|---------|
| `feat` | 새 기능 | `feat(auth): add OAuth2 login` |
| `fix` | 버그 수정 | `fix(api): handle null response` |
| `docs` | 문서만 변경 | `docs(readme): add setup guide` |
| `style` | 포매팅, 로직 변경 없음 | `style: fix trailing whitespace` |
| `refactor` | 코드 재구성, 동작 변경 없음 | `refactor(db): extract query builder` |
| `perf` | 성능 개선 | `perf(search): add query caching` |
| `test` | 테스트 추가/수정 | `test(auth): add login edge cases` |
| `build` | 빌드 시스템·의존성 | `build: upgrade webpack to v6` |
| `ci` | CI 설정 | `ci: add deploy stage` |
| `chore` | 유지보수, 프로덕션 코드 변경 없음 | `chore: update .gitignore` |

## Scope

{{SCOPE_CONVENTION}}

## Breaking Changes

타입/scope 뒤에 `!`를 붙여 breaking change 표시:

\`\`\`
feat(api)!: change response format for /users

BREAKING CHANGE: response now returns array instead of object
\`\`\`

## AI-Assisted Commits

Claude가 commit 작성을 보조하거나 직접 작성하면 footer 추가:

\`\`\`
Co-Authored-By: Claude <noreply@anthropic.com>
\`\`\`

## Good Examples

| Message | Why it's good |
|---------|--------------|
| `feat(auth): add password reset flow` | type 명확, scope 부여, 설명적 |
| `fix(cart): prevent duplicate items on rapid click` | 시나리오 설명 |
| `refactor(db): extract connection pooling to module` | 무엇이 바뀌었는지 구체적 |

## Bad Examples

| Message | Problem | Fix |
|---------|---------|-----|
| `update code` | type 없음, 모호 | `refactor(utils): simplify date parsing` |
| `fix stuff` | scope 없음, 모호 | `fix(form): validate email format` |
| `FEAT: Add login` | type 대문자 | `feat(auth): add login page` |
| `feat(auth): Added login.` | 과거형, 마침표 | `feat(auth): add login page` |
```

(다시: 코드 블록 안의 ` \`\`\` `는 escape — 실제 파일에는 일반 백틱 3개.)

- [ ] **Step 2: 헤더 영어 보존 검증 (V2 부분)**

```bash
grep "^## " plugins/project-init/templates/shared/commit-conventions.md
```

Expected output:
```
## Format
## Rules
## Types
## Scope
## Breaking Changes
## AI-Assisted Commits
## Good Examples
## Bad Examples
```

- [ ] **Step 3: Conventional Commits 식별자 보존 검증 (V4)**

```bash
grep -E "(^|[^a-z])(feat|fix|docs|style|refactor|perf|test|build|ci|chore|BREAKING CHANGE)([^a-z]|$)" plugins/project-init/templates/shared/commit-conventions.md > /tmp/project-init-after-cc-identifiers.txt
diff /tmp/project-init-baseline-cc-identifiers.txt /tmp/project-init-after-cc-identifiers.txt | head
```

Expected: diff 출력이 없거나 (정확히 동일), 영어 식별자 부분이 보존된 변경만.

- [ ] **Step 4: `{{SCOPE_CONVENTION}}` placeholder 보존 검증**

```bash
grep -c "{{SCOPE_CONVENTION}}" plugins/project-init/templates/shared/commit-conventions.md
```

Expected output: `1`

- [ ] **Step 5: 다음 task로 (commit 보류)**

---

## Task 6: Shared Templates — pr-process.md

`templates/shared/pr-process.md`를 하이브리드 패턴으로 변환.

**Files:**
- Modify: `plugins/project-init/templates/shared/pr-process.md`

- [ ] **Step 1: 파일 전체를 다음으로 교체**

```markdown
# PR Process

## PR Body Template

\`\`\`markdown
## Summary
- [1–3 bullet으로 변경사항 설명]

## Test Plan
- [ ] [검증 단계]
- [ ] [엣지 케이스 테스트]
\`\`\`

## Creating a PR

1. 브랜치가 base 브랜치와 동기화되어 있는지 확인
2. upstream tracking으로 push: `git push -u origin <branch-name>`
3. PR 생성:

\`\`\`bash
gh pr create --title "<type>: <description>" --body "$(cat <<'EOF'
## Summary
- <무엇이 왜 바뀌었는지>

## Test Plan
- [ ] <검증 단계>

Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
\`\`\`

## PR Title

- 70자 미만
- Conventional Commits prefix 사용: `feat:`, `fix:`, `refactor:` 등
- 명령형 동사: "add" — "added" 아님

## Merge Strategy

Default: **{{MERGE_STRATEGY}}**

| Strategy | When to use |
|----------|------------|
| **Squash merge** | 브랜치에 WIP/지저분한 commit 다수, base에 깨끗한 단일 commit 원할 때 |
| **Merge commit** | 모든 commit이 깔끔하고 의미 있을 때, 전체 history 보존 원할 때 |
| **Rebase** | linear history 원할 때, 모든 commit이 잘 형성되어 있을 때 |

## Review Checklist

리뷰 요청 전:

- [ ] 모든 테스트 로컬 통과
- [ ] 의도하지 않은 파일 변경 없음 (`git diff --stat`)
- [ ] 브랜치가 base 브랜치와 동기화됨
- [ ] commit 메시지가 컨벤션 따름 (`docs/git-workflow/commit-conventions.md`)
- [ ] PR 설명이 변경사항을 정확히 반영

## Plugin Integration

- **commit-commands**: 간소화된 PR 생성을 위해 `/commit-push-pr` 사용
- **quality-gates** (설치 시): `gh pr create`에 quality 파이프라인 자동 트리거
```

- [ ] **Step 2: 헤더 영어 보존 검증**

```bash
grep "^## " plugins/project-init/templates/shared/pr-process.md
```

Expected output:
```
## PR Body Template
## Creating a PR
## PR Title
## Merge Strategy
## Review Checklist
## Plugin Integration
```

- [ ] **Step 3: `gh` 명령과 placeholder 보존 검증**

```bash
grep "gh pr create" plugins/project-init/templates/shared/pr-process.md
grep -c "{{MERGE_STRATEGY}}" plugins/project-init/templates/shared/pr-process.md
```

Expected: `gh pr create` 라인 출력 + placeholder count `1`.

- [ ] **Step 4: shared templates Group commit (commit-conventions + pr-process)**

```bash
git add plugins/project-init/templates/shared/commit-conventions.md plugins/project-init/templates/shared/pr-process.md
git commit -m "$(cat <<'EOF'
docs(project-init): hybrid translate shared templates

llm-guidelines.md 패턴 (English headers/code/identifiers + Korean prose)을
shared templates로 확장. Conventional Commits 식별자, gh 명령, table 컬럼명,
placeholder ({{SCOPE_CONVENTION}}, {{MERGE_STRATEGY}}) 모두 영어 유지.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Per-Strategy Templates — branch-strategy.md (3 files)

3개 파일 모두 같은 하이브리드 패턴으로 변환. 헤더, regex, branch prefix, `git` 명령 영어. "Rules for Claude" bullet 안의 `**ALWAYS**` / `**NEVER**` 강조 토큰은 영어 유지, 그 뒤 prose는 한국어.

**Files:**
- Modify: `plugins/project-init/templates/github-flow/branch-strategy.md`
- Modify: `plugins/project-init/templates/git-flow/branch-strategy.md`
- Modify: `plugins/project-init/templates/trunk-based/branch-strategy.md`

- [ ] **Step 1: github-flow/branch-strategy.md를 다음으로 교체**

```markdown
# Branch Strategy: GitHub Flow

## Model

- `main`은 production 브랜치 — 항상 deployable
- 모든 작업은 단명 `feature/*` 또는 `fix/*` 브랜치에서
- `develop`, `release`, `staging` 브랜치 없음

## Branch Naming Pattern

\`\`\`regex
^(feature|fix)/[\w.-]+$
\`\`\`

## Branch Prefixes

| Prefix | Use | Example |
|--------|-----|---------|
| `feature/<name>` | 새 기능 또는 enhancement | `feature/user-auth` |
| `fix/<name>` | 버그 수정 | `fix/login-redirect` |

- 설명에는 **kebab-case** 사용
- 간결하게: 2–4 단어
- 전체 50자 이하

## Branch Lifecycle

### Creating a branch

항상 최신 `main`에서 시작:

\`\`\`bash
git checkout main
git pull origin main
git checkout -b feature/<name>
\`\`\`

### Continuing work on an existing branch

작업 재개 전 main과 동기화:

\`\`\`bash
git checkout feature/<name>
git fetch origin
git merge origin/main
\`\`\`

### After PR merge

- 브랜치 삭제: `git branch -d feature/<name>`
- 또는 유지하고 main을 merge해 후속 작업

## Rules for Claude

- **ALWAYS** 작업 시작 전 현재 브랜치 확인: `git branch --show-current`
- **NEVER** `main`에 직접 commit
- **ALWAYS** `feature/*` 또는 `fix/*` 브랜치 명명 사용
- "X 작업 시작해" 요청 시 — 먼저 적절히 명명된 브랜치 생성
- `main`에 있고 변경하려 할 때 — STOP, 브랜치 먼저 생성
- 기존 feature 브랜치로 전환 시 — main에서 sync 필요한지 확인
- **ALWAYS** 기존 feature 브랜치는 `git merge origin/main`으로 sync, `git rebase`는 절대 안 됨. rebase는 commit SHA를 rewrite — push된 브랜치에 unsafe.
```

- [ ] **Step 2: git-flow/branch-strategy.md를 다음으로 교체**

```markdown
# Branch Strategy: Git Flow

## Model

- `main` — production release, version 번호로 태깅
- `develop` — feature 통합 브랜치, 항상 최신 개발 상태 반영
- `feature/*` — 새 기능, `develop`에서 분기, `develop`에 merge back
- `fix/*` — 버그 수정, `develop`에서 분기, `develop`에 merge back
- `release/*` — release 준비, `develop`에서 분기, `main` + `develop`에 merge
- `hotfix/*` — 긴급 production 수정, `main`에서 분기, `main` + `develop`에 merge

## Branch Naming Pattern

\`\`\`regex
^(feature|fix|release|hotfix)/[\w.-]+$
\`\`\`

## Branch Prefixes

| Prefix | From | Merge to | Example |
|--------|------|----------|---------|
| `feature/<name>` | `develop` | `develop` | `feature/user-auth` |
| `fix/<name>` | `develop` | `develop` | `fix/login-redirect` |
| `release/<version>` | `develop` | `main` + `develop` | `release/v1.2.0` |
| `hotfix/<name>` | `main` | `main` + `develop` | `hotfix/critical-crash` |

- 설명에는 **kebab-case** 사용
- 간결하게: 2–4 단어
- 전체 50자 이하

## Branch Lifecycle

### Feature / Fix branch

\`\`\`bash
git checkout develop
git pull origin develop
git checkout -b feature/<name>
# ... 작업 ...
# PR로 develop에 merge back
\`\`\`

### Release branch

\`\`\`bash
git checkout develop
git pull origin develop
git checkout -b release/v<version>
# ... 버전 bump, 마지막 fix ...
# PR로 main과 develop 양쪽에 merge
# main 태깅: git tag -a v<version> -m "Release v<version>"
\`\`\`

### Hotfix branch

\`\`\`bash
git checkout main
git pull origin main
git checkout -b hotfix/<name>
# ... 긴급 수정 ...
# PR로 main과 develop 양쪽에 merge
# main에 patch version으로 태깅
\`\`\`

### After PR merge

- 브랜치 삭제: `git branch -d <branch-name>`
- release의 경우: `main`에 version 번호로 태깅

## Rules for Claude

- **ALWAYS** 작업 시작 전 현재 브랜치 확인: `git branch --show-current`
- **NEVER** `main`이나 `develop`에 직접 commit
- **ALWAYS** `feature/*`와 `fix/*` 브랜치는 `develop`에서 생성, `main`에서 X
- **ALWAYS** `hotfix/*` 브랜치는 `main`에서 생성
- **ALWAYS** `release/*` 브랜치는 `develop`에서 생성
- "X 작업 시작해" 요청 시 — `develop`에서 feature 브랜치 생성
- `main`이나 `develop`에 있고 변경하려 할 때 — STOP, 브랜치 먼저 생성
- release나 hotfix merge 시 — `main`과 `develop` *양쪽*에 merge
- 기존 feature 브랜치로 전환 시 — `develop`에서 sync 필요한지 확인
- **ALWAYS** 기존 feature 브랜치는 `git merge origin/develop`으로 sync, `git rebase`는 절대 안 됨. rebase는 commit SHA를 rewrite — push된 브랜치에 unsafe.
```

- [ ] **Step 3: trunk-based/branch-strategy.md를 다음으로 교체**

```markdown
# Branch Strategy: Trunk-Based Development

## Model

- `main` (trunk) — 항상 deployable, 단일 source of truth
- 단명 `feature/*` 또는 `fix/*` 브랜치 — 1–2일 내 merge
- 장수명 브랜치 없음 (`develop`, `release`, `staging`)
- production에서 미완성 기능을 숨기려면 **feature flag** 사용

## Branch Naming Pattern

\`\`\`regex
^(feature|fix)/[\w.-]+$
\`\`\`

## Branch Prefixes

| Prefix | Use | Example |
|--------|-----|---------|
| `feature/<name>` | 새 기능 (미완성이면 flag 뒤) | `feature/user-auth` |
| `fix/<name>` | 버그 수정 | `fix/login-redirect` |

- 설명에는 **kebab-case** 사용
- 간결하게: 2–4 단어
- 전체 50자 이하

## Branch Lifecycle

### Creating a branch

항상 최신 `main`에서 시작:

\`\`\`bash
git checkout main
git pull origin main
git checkout -b feature/<name>
\`\`\`

### Working on the branch

- 단명 유지: 최대 1–2일
- 작고 잦은 commit
- 더 오래 걸리면, feature flag 사용하고 중간 작업 merge

### Merging back

- `main`으로 PR 생성
- 리뷰 통과 즉시 merge
- merge 직후 브랜치 삭제

\`\`\`bash
# PR merge 후
git checkout main
git pull origin main
git branch -d feature/<name>
\`\`\`

## Feature Flags

여러 날에 걸친 기능의 경우:
- 새 코드를 feature flag 뒤로 wrap
- flag 비활성화 상태로 `main`에 merge
- 기능이 완성되고 테스트 끝나면 flag 활성화

## Rules for Claude

- **ALWAYS** 작업 시작 전 현재 브랜치 확인: `git branch --show-current`
- **NEVER** `main`에 직접 commit
- **ALWAYS** `feature/*` 또는 `fix/*` 브랜치 명명 사용
- **ALWAYS** 브랜치 단명 유지 — 1–2일 내 merge
- "X 작업 시작해" 요청 시 — 최신 `main`에서 브랜치 생성
- 기능이 클 때 — feature flag 사용 + 부분 merge 제안
- `main`에 있고 변경하려 할 때 — STOP, 브랜치 먼저 생성
- PR merge 후 — 브랜치 즉시 삭제
```

- [ ] **Step 4: (Step 2와 3에서 두 파일 모두 교체 완료 — 추가 작업 없음. Step 5의 검증으로 진행.)**

- [ ] **Step 5: 3개 파일 헤더 일관성 검증**

```bash
for f in plugins/project-init/templates/{github-flow,git-flow,trunk-based}/branch-strategy.md; do
  echo "=== $f ==="
  grep "^## " "$f"
done
```

Expected: 모든 파일이 다음 헤더를 포함:
```
## Model
## Branch Naming Pattern
## Branch Prefixes
## Branch Lifecycle
## Rules for Claude
```

- [ ] **Step 6: regex 영어 보존 검증**

```bash
grep -E "\^\(.*\)/" plugins/project-init/templates/*/branch-strategy.md
```

Expected: 각 파일의 regex 라인 출력 (정확한 정규식은 strategy마다 다름 — github-flow는 `^(feature|fix)/`, git-flow는 `release/`/`hotfix/` 추가, trunk-based는 github-flow와 같음).

- [ ] **Step 7: `**ALWAYS**` / `**NEVER**` 영어 보존 검증**

```bash
grep -E "\*\*(ALWAYS|NEVER)\*\*" plugins/project-init/templates/*/branch-strategy.md | wc -l
```

Expected: ≥9 (각 파일 평균 3개 이상의 강조 토큰).

- [ ] **Step 8: 다음 task로 (commit 보류)**

---

## Task 8: Per-Strategy Templates — claude-md-section.md (3 files)

3개 `claude-md-section.md` 파일은 매우 짧다 (각 7–10줄). `## Git Workflow` 헤더만 영어 유지 (devbrew CLAUDE.md `## Git Workflow` 섹션과의 anchor coupling — C5), bullet 본문은 한국어로.

**Files:**
- Modify: `plugins/project-init/templates/github-flow/claude-md-section.md`
- Modify: `plugins/project-init/templates/git-flow/claude-md-section.md`
- Modify: `plugins/project-init/templates/trunk-based/claude-md-section.md`

- [ ] **Step 1: github-flow/claude-md-section.md를 다음으로 교체**

```markdown
## Git Workflow

GitHub Flow. `main`에서 분기, PR로 merge back. 상세는 `docs/git-workflow/`.

- Branch: `main`에서 `feature/*` 또는 `fix/*`. kebab-case, 2–4 단어.
- Commit: Conventional Commits (`<type>(<scope>): <description>`)
- PR: {{MERGE_STRATEGY}}, `docs/git-workflow/pr-process.md` 참고
- project-init 플러그인이 브랜치 명명·commit 포맷 자동 검증
```

- [ ] **Step 2: git-flow/claude-md-section.md를 다음으로 교체**

```markdown
## Git Workflow

Git Flow. release용 `main`, 통합용 `develop`. 상세는 `docs/git-workflow/`.

- Branch: `develop`에서 `feature/*`, `main`에서 `hotfix/*`. kebab-case, 2–4 단어.
- Commit: Conventional Commits (`<type>(<scope>): <description>`)
- PR: {{MERGE_STRATEGY}}, `docs/git-workflow/pr-process.md` 참고
- feature 브랜치는 `develop`에 merge, release와 hotfix는 `main`과 `develop` 양쪽에 merge
- project-init 플러그인이 브랜치 명명·commit 포맷 자동 검증
```

- [ ] **Step 3: trunk-based/claude-md-section.md를 다음으로 교체**

```markdown
## Git Workflow

Trunk-based development. 모든 작업이 `main`으로 빠르게 merge. 상세는 `docs/git-workflow/`.

- Branch: `main`에서 단명 `feature/*` 또는 `fix/*`. 1–2일 내 merge.
- Commit: Conventional Commits (`<type>(<scope>): <description>`)
- PR: {{MERGE_STRATEGY}}, `docs/git-workflow/pr-process.md` 참고
- 미완성 기능에는 feature flag 사용. `main`은 항상 deployable 유지.
- project-init 플러그인이 브랜치 명명·commit 포맷 자동 검증
```

- [ ] **Step 4: anchor 일관성 검증 (V6)**

```bash
grep -h "^## " plugins/project-init/templates/*/claude-md-section.md > /tmp/project-init-after-claude-md-anchors.txt
diff /tmp/project-init-baseline-claude-md-anchors.txt /tmp/project-init-after-claude-md-anchors.txt
```

Expected: diff 출력 없음 — 3개 파일 모두 `## Git Workflow` 영어 유지.

- [ ] **Step 5: `{{MERGE_STRATEGY}}` placeholder 보존 검증**

```bash
grep -c "{{MERGE_STRATEGY}}" plugins/project-init/templates/*/claude-md-section.md
```

Expected output (각 파일 1개씩):
```
plugins/project-init/templates/git-flow/claude-md-section.md:1
plugins/project-init/templates/github-flow/claude-md-section.md:1
plugins/project-init/templates/trunk-based/claude-md-section.md:1
```

- [ ] **Step 6: per-strategy templates Group commit (branch-strategy + claude-md-section, 6 files)**

```bash
git add plugins/project-init/templates/github-flow/branch-strategy.md \
        plugins/project-init/templates/git-flow/branch-strategy.md \
        plugins/project-init/templates/trunk-based/branch-strategy.md \
        plugins/project-init/templates/github-flow/claude-md-section.md \
        plugins/project-init/templates/git-flow/claude-md-section.md \
        plugins/project-init/templates/trunk-based/claude-md-section.md
git commit -m "$(cat <<'EOF'
docs(project-init): hybrid translate per-strategy templates

3개 branching strategy 모두 — branch-strategy.md, claude-md-section.md.
헤더, regex, branch prefix, git 명령, **ALWAYS**/**NEVER** 강조 토큰,
{{MERGE_STRATEGY}} placeholder, ## Git Workflow anchor 영어 유지.
prose만 한국어.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Version Bump + CHANGELOG Entry + Final Integration Verification

`plugin.json` patch bump, CHANGELOG에 `[1.2.3]` entry 추가, spec V1–V8 verification 전체 실행.

**Files:**
- Modify: `plugins/project-init/.claude-plugin/plugin.json`
- Modify: `plugins/project-init/CHANGELOG.md`

- [ ] **Step 1: plugin.json version bump**

현재 `plugin.json` 확인:
```bash
cat plugins/project-init/.claude-plugin/plugin.json
```

`"version": "1.2.2"`를 `"version": "1.2.3"`으로 교체 (다른 필드 변경 없음 — `description`은 영어 유지, NG 없음).

- [ ] **Step 2: CHANGELOG에 `[1.2.3]` entry 추가**

`## [1.2.2] — 2026-05-10` 라인 *위에* 다음 블록 삽입 (`# Changelog` 헤더와 introductory 단락 다음):

```markdown
## [1.2.3] — 2026-05-10

### Changed
- devbrew CLAUDE.md *"Korean-primary, English-terms-only"* 정책을 `plugins/project-init/`에 적용 (qg `28c6ffb` precedent 정렬). `README.md`, `CHANGELOG.md`, `commands/project-init.md` 본문이 Korean-primary로 재작성됨; 식별자, code, branch 이름, regex, frontmatter `description`은 영어 유지.
- `templates/shared/llm-guidelines.md`가 v1.2.0에서 확립한 *"English headers/code + Korean explainers"* 하이브리드 패턴을 다른 templates 전체로 확장 — `templates/shared/commit-conventions.md`, `templates/shared/pr-process.md`, `templates/<strategy>/branch-strategy.md` (3개), `templates/<strategy>/claude-md-section.md` (3개). Conventional Commits 식별자, regex, `gh` 명령, branch prefix, `**ALWAYS**`/`**NEVER**` 강조 토큰, `{{SCOPE_CONVENTION}}`/`{{MERGE_STRATEGY}}` placeholder, `## Git Workflow` anchor 영어 유지.

```

(주의: entry 끝에 빈 줄 1개 — `[1.2.2]` entry와 시각적 분리.)

- [ ] **Step 3: V1 — git diff --stat 검증**

```bash
git diff --stat HEAD~3 HEAD
git status
```

Expected (4번째 commit 진행 전):
- HEAD~3..HEAD에서 9개 파일 변경 (Group A 3 + shared 2 + per-strategy 6 — wait, recompute)
- 정확히는: Group A commit (3 files: README, CHANGELOG, command), shared commit (2 files), per-strategy commit (6 files) = 11 files in 3 commits
- 본 task가 추가하는 파일 = 2 (plugin.json + CHANGELOG)

전체 spec scope = 12 files (CHANGELOG는 두 commit에서 touch됨 — Task 3에서 한국화, Task 9에서 entry 추가). 이 시점에서 `git diff main..HEAD --stat`이 11–12 unique 파일을 보여야 함.

```bash
git diff main..HEAD --stat | tail -2
```

Expected: `11 files changed` 또는 `12 files changed` (CHANGELOG가 단일 entry로 카운트되면 11, 두 변경이 union되면 11).

- [ ] **Step 4: V2 — Templates 헤더 영어 검증 (전체)**

```bash
grep -h "^## " plugins/project-init/templates/**/*.md plugins/project-init/templates/*.md 2>/dev/null | sort -u
```

(주의: `**` glob은 zsh에서 작동. bash라면 `find plugins/project-init/templates -name "*.md" -exec grep -h "^## " {} \;`)

Expected: 모든 헤더가 영어. 한국어 헤더가 출력되면 stop.

- [ ] **Step 5: V3 — Placeholder 보존 비교 (cross-task invariant)**

```bash
grep -rEn "\{\{[A-Z_]+\}\}" plugins/project-init/templates/ | sort > /tmp/project-init-after-placeholders.txt
diff /tmp/project-init-baseline-placeholders.txt /tmp/project-init-after-placeholders.txt
```

Expected: diff 출력 없음 (정확히 동일 — 라인 번호만 변할 수 있음. 만약 라인 번호 차이만 있고 매치 문자열·매치 수가 같다면:

```bash
grep -rEh "\{\{[A-Z_]+\}\}" plugins/project-init/templates/ | sort > /tmp/strict-after.txt
grep -rEh "\{\{[A-Z_]+\}\}" plugins/project-init/templates/ | sort -u > /tmp/strict-after-unique.txt
wc -l /tmp/strict-after.txt /tmp/strict-after-unique.txt
```

unique한 placeholder가 정확히 2개 (`{{SCOPE_CONVENTION}}`, `{{MERGE_STRATEGY}}`)이고, 총 매치 수가 baseline과 일치해야 함.)

- [ ] **Step 6: V4 — Conventional Commits 식별자 검증**

```bash
grep -E "(^|[^a-z])(feat|fix|docs|style|refactor|perf|test|build|ci|chore|BREAKING CHANGE)([^a-z]|$)" plugins/project-init/templates/shared/commit-conventions.md > /tmp/strict-after-cc.txt
diff /tmp/project-init-baseline-cc-identifiers.txt /tmp/strict-after-cc.txt | head
```

Expected: diff 출력 없거나, 식별자 자체는 보존되고 prose만 변경된 추가/삭제만.

- [ ] **Step 7: V5 — Version 정합성**

```bash
grep '"version"' plugins/project-init/.claude-plugin/plugin.json
head -15 plugins/project-init/CHANGELOG.md
```

Expected:
- `plugin.json`: `"version": "1.2.3"`
- `CHANGELOG.md`: `## [1.2.3] — 2026-05-10` entry가 가장 위 (introductory 다음)

- [ ] **Step 8: V6 — `## Git Workflow` anchor 보존 검증**

```bash
grep -h "^## " plugins/project-init/templates/*/claude-md-section.md > /tmp/strict-after-anchors.txt
diff /tmp/project-init-baseline-claude-md-anchors.txt /tmp/strict-after-anchors.txt
```

Expected: diff 출력 없음.

- [ ] **Step 9: V7 — Mental dry-run 시뮬레이션**

`commands/project-init.md` Step 4 흐름을 한 번 mental-walk:

1. **Step 4a (Read templates)**: 5개 template 경로 — 모두 정확한 영어 경로 유지됐는가? (`${CLAUDE_PLUGIN_ROOT}/templates/...` 패턴 영어, 보존.)
2. **Step 4b (Replace placeholders)**: `{{SCOPE_CONVENTION}}`, `{{MERGE_STRATEGY}}` 두 placeholder가 templates에 그대로 존재하는가? V3에서 검증됨.
3. **Step 4c (Write CLAUDE.md sections)**: matrix가 `## LLM Coding Guidelines`와 `## Git Workflow` 두 anchor를 사용하는데, 둘 다 영어 그대로 유지됐는가? V6에서 `## Git Workflow` 검증됨, `## LLM Coding Guidelines`는 `llm-guidelines.md` 미변경 (NG2)으로 안전.
4. **Step 4d (Write docs/git-workflow/ files)**: 3개 파일 출력 경로 영어 유지.

Mental-walk PASS 확인 후 진행.

- [ ] **Step 10: V8 — qg와 톤 비교 (시각적)**

```bash
diff <(grep -E "^#+ " plugins/project-init/README.md) <(grep -E "^#+ " plugins/quality-gates/README.md)
```

(diff가 줄을 출력하지만, 양쪽 모두 한국어 헤딩 톤이라는 게 핵심. 1:1 동일성 불필요.)

- [ ] **Step 11: 최종 commit (version bump + CHANGELOG entry)**

```bash
git add plugins/project-init/.claude-plugin/plugin.json plugins/project-init/CHANGELOG.md
git commit -m "$(cat <<'EOF'
chore(project-init): bump 1.2.2 → 1.2.3 + CHANGELOG entry

surface 변화 없는 doc consolidation. devbrew Plugin Shape rule (PR마다
plugin.json bump) 준수. spec: docs/superpowers/specs/2026-05-10-project-init-language-policy-design.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 12: 전체 brach 상태 확인**

```bash
git log --oneline main..HEAD
git diff main..HEAD --stat
```

Expected: 5 commits (spec + 4 implementation), 12 unique files changed in implementation commits.

---

## Task 10: PR 생성 (선택, 사용자 승인 필요)

본 task는 사용자가 명시적으로 PR 생성을 요청할 때만 실행. auto mode여도 PR 생성은 shared state에 영향을 주는 action이라 explicit confirmation 필수.

- [ ] **Step 1: 사용자에게 PR 생성 의사 확인**

> "Plan 4개 commit 완료. PR 생성할까요? (gh pr create — base는 main, squash merge)"

사용자가 yes 답변 시에만 진행.

- [ ] **Step 2: push**

```bash
git push -u origin feature/project-init-language-policy
```

- [ ] **Step 3: PR 생성**

```bash
gh pr create --title "docs(project-init): Korean-primary docs + hybrid templates (v1.2.3)" --body "$(cat <<'EOF'
## Summary

- devbrew CLAUDE.md *"Korean-primary, English-terms-only"* 정책을 `plugins/project-init/`에 적용 (qg `28c6ffb` precedent 정렬)
- `templates/shared/llm-guidelines.md`의 *"English headers/code + Korean explainers"* 하이브리드 패턴을 나머지 templates로 확장 — 같은 `/project-init` 호출 페이로드 안의 톤 분리 해결
- `1.2.2` → `1.2.3` patch bump

## Spec / Plan

- Spec: [`docs/superpowers/specs/2026-05-10-project-init-language-policy-design.md`](docs/superpowers/specs/2026-05-10-project-init-language-policy-design.md)
- Plan: [`docs/superpowers/plans/2026-05-10-project-init-language-policy-plan.md`](docs/superpowers/plans/2026-05-10-project-init-language-policy-plan.md)

## Test Plan

- [x] V1 — `git diff main..HEAD --stat`이 정확히 12 files 표시
- [x] V2 — `templates/` 헤더 grep 결과 100% 영어
- [x] V3 — `{{SCOPE_CONVENTION}}` / `{{MERGE_STRATEGY}}` placeholder 위치·개수가 baseline과 동일
- [x] V4 — Conventional Commits 식별자 (`feat`, `fix`, ...) 영어 보존
- [x] V5 — `plugin.json` `1.2.3`, CHANGELOG `[1.2.3]` entry 존재
- [x] V6 — `## Git Workflow` anchor 영어 유지 (3개 파일)
- [x] V7 — `commands/project-init.md` Step 4 mental dry-run 통과
- [x] V8 — README 톤이 qg README와 일치

## Out of Scope (별 PR)

- `hooks/post-tool-use.py` 인라인 영어 메시지 (NG1) — user-facing stderr 출력 정책 결정 필요
- `templates/shared/llm-guidelines.md` (NG2) — 이미 패턴 정합

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 4: PR URL 출력**

```bash
gh pr view --json url --jq '.url'
```

사용자에게 URL 보고.

---

## 자가 검토 체크리스트 (writing-plans skill 후 self-review)

**Spec coverage:**
- AC1 (README) → Task 2 ✓
- AC2 (CHANGELOG) → Task 3 + Task 9 (entry 추가) ✓
- AC3 (command) → Task 4 ✓
- AC4 (commit-conventions) → Task 5 ✓
- AC5 (pr-process) → Task 6 ✓
- AC6 (3× branch-strategy) → Task 7 ✓
- AC7 (3× claude-md-section) → Task 8 ✓
- AC8 (llm-guidelines 미변경) → 명시적 NG, 모든 grep에서 자연 보존 ✓
- AC9 (plugin.json bump) → Task 9 Step 1 ✓
- AC10 (CHANGELOG entry) → Task 9 Step 2 ✓
- AC11 (placeholder 보존) → Task 1 baseline + Task 9 Step 5 비교 ✓
- AC12 (dry-run 시뮬레이션) → Task 9 Step 9 ✓

**Verification 매핑:**
- V1 → Task 9 Step 3 ✓
- V2 → Task 9 Step 4 ✓
- V3 → Task 1 Step 1 + Task 9 Step 5 ✓
- V4 → Task 1 Step 2 + Task 9 Step 6 ✓
- V5 → Task 9 Step 7 ✓
- V6 → Task 1 Step 3 + Task 9 Step 8 ✓
- V7 → Task 9 Step 9 ✓
- V8 → Task 9 Step 10 ✓

**Placeholder 검색:** "TBD"/"TODO"/"implement later" 검색 — 없음. ✓

**Type consistency:** baseline 파일 이름 (`/tmp/project-init-baseline-*.txt`)이 Task 1과 Task 9에서 정확히 일치. `after` 파일 이름은 Task 9 내부 변수성 — 동일 task 내에서 일치하면 OK. ✓
