---
description: "Initialize git workflow rules for the project (branch strategy, commit conventions, PR process)"
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---

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

또한 root에 `CLAUDE.md`가 존재하고 `AGENTS.md`가 없다면 사용자에게 묻는다:

> "기존 CLAUDE.md 발견. AGENTS.md로 migrate할까요? (CLAUDE.md는 `@AGENTS.md` thin pointer로 교체됩니다)"

사용자 거절 시: 전체 `/project-init` 실행 abort — Step 2 이후의 docs/git-workflow/ 생성도 skip. AC21에 따라 부분 진행 금지.

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

**중요:** template 파일들은 `${CLAUDE_PLUGIN_ROOT}/templates/`에 있다. 읽고, placeholder를 치환하고, 프로젝트에 쓴다. **AGENTS.md를 canonical content source로**, **CLAUDE.md를 `@AGENTS.md` thin pointer로** 발행한다 (Codex/Cursor 등 16+ 벤더 호환 + 단일 source of truth).

#### 4a: Templates 읽기

플러그인에서 다음 파일을 읽는다:
- `${CLAUDE_PLUGIN_ROOT}/templates/<strategy>/agents-md-section.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/<strategy>/branch-strategy.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/shared/commit-conventions.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/shared/pr-process.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/shared/claude-md-pointer.md`

여기서 `<strategy>`는 `github-flow`, `git-flow`, `trunk-based` 중 하나.

#### 4b: Placeholder 치환

template 컨텐츠에서 다음 placeholder들을 치환:

| Placeholder | 치환 값 |
|-------------|---------|
| `{{SCOPE_CONVENTION}}` | Step 3 질문 1의 scope 룰 |
| `{{MERGE_STRATEGY}}` | Step 3 질문 2의 merge 전략 |

#### 4c: AGENTS.md × CLAUDE.md 4-state matrix

프로젝트 root의 `AGENTS.md`와 `CLAUDE.md` 상태에 따라 다음 matrix 적용 (AC22):

| State | AGENTS.md | CLAUDE.md | Action |
|---|---|---|---|
| **S1 (clean slate)** | 없음 | 없음 | AGENTS.md 신규 작성 (`agents-md-section.md` content); CLAUDE.md 신규 작성 (`claude-md-pointer.md` content — `@AGENTS.md` 한 줄). |
| **S2 (CLAUDE-only legacy)** | 없음 | 존재 | Step 1의 migration 프롬프트 (AC21) — 거절 시 전체 `/project-init` abort. 승인 시 CLAUDE.md 내용 분기 (AC16 정규화 절차 (frontmatter strip → HTML comment strip → str.strip()) 준용해 분류): **S2a** 정규화 결과가 `@AGENTS.md` 아니면 full content — (a) `## Git Workflow` 섹션 추출, (b) AGENTS.md로 이전·새 template과 merge, (c) CLAUDE.md를 `@AGENTS.md` 한 줄로 교체. 기존 CLAUDE.md의 `## LLM Coding Guidelines` 섹션은 plugin이 더 이상 *managed*로 취급하지 않으므로 자동으로 *비-관리 컨텐츠*로 분류되어, matrix 직후의 "비-관리 컨텐츠 (다른 헤딩, 단락, 코드 블록)는 모든 state에서 보존" 규칙에 따라 AGENTS.md migration 시 그대로 이전·보존됨 (사용자 4-bullet 컨텐츠 silent drop 없음). **S2b** 정규화 결과 == `@AGENTS.md`인 dangling pointer (AGENTS.md 부재) — 새 template만으로 AGENTS.md 신규 작성, CLAUDE.md unchanged. |
| **S3 (AGENTS canonical, CLAUDE pointer)** | 존재 | 존재 + `@AGENTS.md` (R-pointer 통과) | AGENTS.md의 `## Git Workflow` 섹션만 in-place 갱신. CLAUDE.md는 unchanged. |
| **S4 (AGENTS exists, CLAUDE divergent or absent)** | 존재 | 없음 또는 divergent content | 사용자에게 advisory + 두 옵션 — (i) CLAUDE.md를 `@AGENTS.md` 한 줄로 *재작성* (AGENTS.md unchanged), (ii) abort. 승인 시 (i) 수행 + S3 action. |

비-관리 컨텐츠 (다른 헤딩, 단락, 코드 블록)는 모든 state에서 보존.

#### 4d: docs/git-workflow/ 파일 쓰기

`docs/git-workflow/` 디렉토리가 없으면 생성. 다음 3개 파일 작성:

1. `docs/git-workflow/branch-strategy.md` — `templates/<strategy>/branch-strategy.md`에서
2. `docs/git-workflow/commit-conventions.md` — `templates/shared/commit-conventions.md`에서 (placeholder 치환 후)
3. `docs/git-workflow/pr-process.md` — `templates/shared/pr-process.md`에서 (placeholder 치환 후)

### Step 5: 확인

생성 결과 보고:

> **{strategy 이름}** 전략으로 git workflow 초기화 완료.
>
> 생성/업데이트된 파일:
> - `AGENTS.md` — `## Git Workflow` 섹션 추가 (canonical content source)
> - `CLAUDE.md` — `@AGENTS.md` 한 줄 thin pointer (Claude Code가 AGENTS.md content를 자동 import)
> - `docs/git-workflow/branch-strategy.md` — 브랜치 룰
> - `docs/git-workflow/commit-conventions.md` — Commit 컨벤션
> - `docs/git-workflow/pr-process.md` — PR 프로세스
>
> `project-init` 플러그인 hook이 브랜치·commit 메시지 + agent-readable docs convention (size, TOC, fenced lang, links, drift)을 자동 검증합니다.
> AGENTS.md primary 패턴으로 OpenAI Codex, Cursor, Aider 등 16+ 벤더가 동일 파일을 인식합니다.
> 간결한 git 작업을 위해 `/commit` 또는 `/commit-push-pr` (commit-commands 플러그인) 사용.
