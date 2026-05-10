---
description: "Initialize git workflow rules + LLM coding baseline for the project (branch strategy, commit conventions, PR process, Karpathy-derived LLM guidelines)"
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
