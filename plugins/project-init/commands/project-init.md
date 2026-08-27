---
description: "Initialize git workflow rules for the project (branch strategy, commit conventions, PR process)"
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

#### Charter 상태 감지 (파일 레벨 — Phase 0보다 선행)

charter state를 **파일 레벨**로 판정한다 (§6 matrix 입력):

- (a) `AGENTS.md`에 `## Project Charter` 섹션이 존재하는가.
- (b) 그 섹션의 `**Vision:**`·`**Non-goals:**`·`**Tech Stack:**` 값이 모두 비어있지 않고 `{{...}}` placeholder가 아닌가 (= `charter_section_complete`).
- (c) `docs/project/charter.md` **와** `docs/project/conventions.md`가 모두 존재하는가 (= `docs_complete`; `glossary.md`는 조건부라 completeness 판정에서 제외).

이 판정으로 C-S1 / C-S2 / C-S3 중 하나를 결정한다 (Step 4e의 matrix에서 사용):

- **C-S1 (clean)** = `## Project Charter` 섹션 부재 **AND** `docs/project/charter.md`·`docs/project/conventions.md` **둘 다 부재**. (섹션이 없어도 관리 detail 파일 `charter.md`·`conventions.md` 중 **하나라도** 있으면 C-S1이 아니라 C-S3 — 기존 user-authored docs를 clean-slate로 덮어쓰지 않는다. lone `conventions.md`만 있는 drifted repo도 여기서 C-S3로 라우팅된다.)
- **C-S2 (complete)** = `charter_section_complete` == true **AND** `docs_complete` == true.
- **C-S3 (partial/drifted)** = 그 외 전부. 분기: `charter_section_complete` == false 이면 **(a) 섹션 항목 누락** → Phase 1 보충 질문(Law 1 게이트 적용); `charter_section_complete` == true 이지만 `docs_complete` == false 이면 **(b) docs 파일만 누락** → 질문 없이 기존 섹션 값으로 누락 파일 생성.

이 판정은 git-workflow 감지와 독립이며, 두 matrix는 같은 run에서 동시에 평가되어도 서로 간섭하지 않는다.

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

### Step 3.5: Project Charter (신규)

**직렬 순서**: Step 3.5는 Step 3(release-branch 질문 포함)이 *모두 끝난 뒤* 시작한다. branching 질문과 charter 질문을 교차하지 않는다. Phase 1의 "≤4개" 한도는 charter 질문에만 적용되며 git step 질문 수와 합산하지 않는다 (독립 카운트).

C-S2(완전 헌장 존재)면 먼저 "헌장을 업데이트할까요?"를 묻고, **거절 시 Step 3.5를 건너뛴다**(unchanged — NG7 경계상 합법, Law 1 게이트 비적용). 승인 또는 C-S1/C-S3(a)면 아래 Phase 0+1을 진행한다. C-S3(b)(docs 파일만 누락)는 질문 없이 Step 4e에서 기존 섹션 값으로 누락 파일만 생성한다.

#### Phase 0 — 사실 발견 (질문 0개)

`Glob`/`Read`로 repo를 스캔해 tech-stack 후보를 자동 생성한다. manifest → stack 라벨 매핑:

| 감지 파일 | stack 라벨 (+ 추가 추론) |
|---|---|
| `package.json` | Node.js/JavaScript. `tsconfig.json` 또는 `devDependencies.typescript` → TypeScript. `dependencies`의 react/next/vue/svelte/express/nest → 프레임워크 라벨. `scripts.test`/`scripts.build` → build·test 명령. |
| `pyproject.toml` / `requirements.txt` / `setup.py` / `Pipfile` | Python. `pyproject.toml`의 `requires-python` → 버전. deps의 django/flask/fastapi → 프레임워크. `[tool.pytest]`/`pytest` dep → test 명령. |
| `go.mod` | Go. `go` directive → 버전. |
| `Cargo.toml` | Rust. `[package].edition` → edition. |
| `pom.xml` / `build.gradle` / `build.gradle.kts` | Java/Kotlin (Maven 또는 Gradle). |
| `Gemfile` | Ruby. |
| `composer.json` | PHP. |

또한 **디렉토리 구조**를 스캔한다 (AC2 — manifest와 함께): `src/`·`app/`·`pages/`·`components/`·`lib/`·`tests/`(또는 `test/`·`spec/`)·`cmd/`·`internal/` 등 표준 레이아웃과 monorepo 신호(`packages/*`·`apps/*`, workspace 매니페스트)를 감지해 tech-stack·빌드 layout 후보를 보강한다. 디렉토리 신호도 manifest 후보와 동일하게 `[감지됨]` 라벨로 표기한다.

감지된 각 항목에 **`[감지됨]`** 라벨을 붙여 Phase 1 ④에서 확인만 받는다.

**Fallback (C6 — graceful degradation, loud logging)**: 위 manifest를 하나도 못 찾으면 crash하지 않고 직접 질문 모드로 downgrade하되 fallback이 돌았음을 명시한다:

> `[project-init] manifest 미발견 — tech-stack 자동 감지 fallback: 직접 입력으로 진행합니다.`

이 경우 Phase 1 ④는 `[감지됨]` 확인 대신 open-ended tech-stack 질문이 된다.

#### Phase 1 — 판단 질문 (AskUserQuestion, ≤4개)

`AskUserQuestion`으로 다음 4개만 묻는다 (자동 감지된 사실은 open-ended 재질문 금지 — AC3):

1. **Vision** (필수, 1문장) — "이 프로젝트의 한 문장 vision은?"
2. **Non-goals** (필수) — "명시적으로 하지 *않을* 것 (non-goals)은?"
3. **핵심 conventions** (필수, 1–3개) — "지켜야 할 핵심 코딩/구조 컨벤션 1–3개는?"
4. **Tech-stack 확인** (필수) — Phase 0 후보를 보여주고 "감지된 tech-stack이 맞나요? 수정·추가할 것은?" (fallback 시 open-ended 입력).

**Glossary 트리거 (AC7, 별도 질문 아님)**: 위 4개 답변 안에서 사용자가 *프로젝트 고유 도메인 용어*(일반 SW 어휘가 아닌, 이 프로젝트에서 특정 의미로 정의해 쓰는 명사 — 예: "ledger", "tenant", "rollup")를 명시적으로 정의·언급한 경우에만 glossary 후보로 수집한다. 용어를 **추측해 만들지 않는다**. 모호하면 수집하지 않는다(보수적). 수집된 용어가 0개면 `glossary.md`를 생성하지 않는다(빈 파일 금지).

#### Law 1 구조적 게이트 (bounded — AC10/C9)

C-S1 및 C-S3(a)에서 **vision·non-goals·conventions·tech-stack**가 채워질 때까지 진행을 막는다. 각 필수 항목에 대해 빈/무의미 응답이면 AskUserQuestion 재질문을 **최대 3회**까지 한다. 3회 후에도 비면 charter step을 *loud advisory와 함께 abort*한다:

> `[project-init] charter 미완료: <항목> 비어 abort. git-workflow 산출물은 정상 생성됩니다. 미완 항목의 사후 자동 플래그는 없습니다 — 헌장을 채우려면 /project-init 을 다시 실행하세요.`

abort 후에도 Step 4의 git-workflow 파일 생성은 정상 진행한다(부분 산출물 금지 아님 — git-workflow는 charter와 독립). C-S2(완전 헌장 갱신)는 이 게이트 면제.

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
| **S2 (CLAUDE-only legacy)** | 없음 | 존재 | Step 1의 migration 프롬프트 (AC21) — 거절 시 전체 `/project-init` abort. 승인 시 CLAUDE.md 내용 분기 (AC16 정규화 절차 (frontmatter strip → HTML comment strip → str.strip()) 준용해 분류): **S2a** 정규화 결과가 `@AGENTS.md` 아니면 full content — (a) `## Git Workflow` 섹션 추출, (b) AGENTS.md로 이전·새 template과 merge, (c) CLAUDE.md를 `@AGENTS.md` 한 줄로 교체, (d) 이전된 H1이 *원본 파일명을 지칭*하면 (`# CLAUDE.md`) `# AGENTS.md`로 재제목한다 — 그렇지 않은 H1(`# My Project` 등)은 프로젝트 제목이므로 비-관리 컨텐츠로 보존. 기존 CLAUDE.md의 `## LLM Coding Guidelines` 섹션은 plugin이 더 이상 *managed*로 취급하지 않으므로 자동으로 *비-관리 컨텐츠*로 분류되어, matrix 직후의 "비-관리 컨텐츠 (다른 헤딩, 단락, 코드 블록)는 모든 state에서 보존" 규칙에 따라 AGENTS.md migration 시 그대로 이전·보존됨 (사용자 4-bullet 컨텐츠 silent drop 없음). **S2b** 정규화 결과 == `@AGENTS.md`인 dangling pointer (AGENTS.md 부재) — 새 template만으로 AGENTS.md 신규 작성, CLAUDE.md unchanged. |
| **S3 (AGENTS canonical, CLAUDE pointer)** | 존재 | 존재 + `@AGENTS.md` (R-pointer 통과) | AGENTS.md의 `## Git Workflow` 섹션만 in-place 갱신. CLAUDE.md는 unchanged. |
| **S4 (AGENTS exists, CLAUDE divergent or absent)** | 존재 | 없음 또는 divergent content | 사용자에게 advisory + 두 옵션 — (i) CLAUDE.md를 `@AGENTS.md` 한 줄로 *재작성* (AGENTS.md unchanged), (ii) abort. 승인 시 (i) 수행 + S3 action. |

비-관리 컨텐츠 (다른 헤딩, 단락, 코드 블록)는 모든 state에서 보존. 유일한 예외는 4c S2a (d)의 H1 재제목 — 파일명을 지칭하는 제목은 이전 후 대상 파일을 잘못 가리키므로 보존 대상이 아니다.

#### 4d: docs/git-workflow/ 파일 쓰기

`docs/git-workflow/` 디렉토리가 없으면 생성. 다음 3개 파일 작성:

1. `docs/git-workflow/branch-strategy.md` — `templates/<strategy>/branch-strategy.md`에서
2. `docs/git-workflow/commit-conventions.md` — `templates/shared/commit-conventions.md`에서 (placeholder 치환 후)
3. `docs/git-workflow/pr-process.md` — `templates/shared/pr-process.md`에서 (placeholder 치환 후)

#### 4e: Project Charter 발행 (§6 state matrix)

charter step이 abort(Law 1 게이트 실패)되지 않았다면, Step 1에서 판정한 charter state에 따라 발행한다 (C-S2 갱신 거절은 abort가 아니라 아래 C-S2 행의 unchanged로 처리). template은 `${CLAUDE_PLUGIN_ROOT}/templates/project/`에서 읽어 placeholder를 elicit된 값으로 치환한다 (C7 — 의견 콘텐츠 주입 금지, AC14).

읽을 template:
- `${CLAUDE_PLUGIN_ROOT}/templates/project/agents-md-section.md` → `AGENTS.md`의 `## Project Charter` 섹션
- `${CLAUDE_PLUGIN_ROOT}/templates/project/charter.md` → `docs/project/charter.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/project/conventions.md` → `docs/project/conventions.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/project/glossary.md` → `docs/project/glossary.md` (조건부)

placeholder 치환 매핑:

| Placeholder | 값 출처 |
|---|---|
| `{{VISION}}` | Phase 1 ① |
| `{{NON_GOALS}}` | Phase 1 ② |
| `{{TECH_STACK}}` | Phase 1 ④ (확정 tech-stack) |
| `{{GOALS}}` | vision에서 파생한 1–3개 목표 (사용자 답변 기반) |
| `{{SUCCESS_CRITERIA}}` | 사용자가 success/DoD를 언급했으면 그 값, 아니면 `_명시되지 않음 — 추후 보강._` |
| `{{PERSONAS}}` | vision·non-goals 답변에 audience/사용자가 언급됐으면 그로부터 파생; 없으면 `_명시되지 않음 — 추후 보강._` (canned persona 주입 금지, AC14). **personas는 Law 1 게이트 항목이 아니므로**(AC10은 vision·non-goals·conventions·tech-stack만) 비어 있어도 abort하지 않는다. |
| `{{NAMING}}`·`{{DIRECTORY_STRUCTURE}}`·`{{ERROR_HANDLING}}`·`{{ANTI_PATTERNS}}` | Phase 1 ③ conventions 답변을 항목별로 분배; 해당 답변이 없으면 `_명시되지 않음._` |
| `{{BUILD_TEST}}` | Phase 0에서 감지한 build·test 명령; 없으면 `_명시되지 않음._` |
| `{{GLOSSARY_TERMS}}` | 수집된 도메인 용어를 `- **<용어>**: <정의>` 목록으로 (용어 0개면 glossary.md 미생성) |

**State별 action (§6):**

| State | Action |
|---|---|
| **C-S1 (clean)** | `AGENTS.md`에 `## Project Charter` 섹션 신규 추가(`agents-md-section.md` 치환본) + `docs/project/charter.md`·`conventions.md` 생성 (+용어 있으면 `glossary.md`). |
| **C-S2 (complete)** | 업데이트 승인 시: `## Project Charter` 섹션 in-place 교체 + `docs/project/` 파일 in-place 갱신. 거절 시: 전부 unchanged, 중복 `## Project Charter` 섹션 생성 안 함. |
| **C-S3 (a) 섹션 항목 누락** | Phase 1 보충 질문으로 채운 뒤 C-S1과 동일하게 발행(in-place 교체). |
| **C-S3 (b) docs 파일만 누락** | 질문 없이(C-S3(b) 계약) 누락된 `docs/project/charter.md`·`conventions.md`를 생성하되, **`## Project Charter` 요약이 실제 source로 가진 값(vision·non-goals·tech-stack)만** 채운다. 요약에 없는 필드 — charter.md의 `## Goals`·`## Success Criteria / Definition of Done`·`## Personas`, conventions.md의 모든 헤딩(`## Naming`·`## Directory Structure`·`## Error Handling`·`## Anti-patterns`·`## Build & Test`) — 는 위 4e placeholder 치환 매핑 표의 해당 fallback 마커(`_명시되지 않음._` 또는 charter.md soft 필드의 `_명시되지 않음 — 추후 보강._`)로 둔다(요약은 이 값들의 source가 아니므로 재구성 불가). AGENTS.md 섹션은 unchanged. 헌장 전체를 다시 채우려면 C-S2 경로의 "업데이트" 승인으로 Phase 1을 재진행한다. |

`docs/project/` 디렉토리가 없으면 생성한다. 비-관리 콘텐츠(다른 헤딩·단락·코드 블록)는 모든 state에서 보존한다(기존 4c matrix 정신). `## Project Charter` 요약은 ≤약 25줄로 유지하고 상세는 전부 `docs/project/`로 내린다(C5 — 기존 R1 size 룰 자기 준수).

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
> - `AGENTS.md` — `## Project Charter` 요약 섹션 (vision·non-goals·tech-stack + docs/project/ 포인터)
> - `docs/project/charter.md` — vision·goals·non-goals·success criteria·personas
> - `docs/project/conventions.md` — naming·구조·error handling·anti-patterns·build & test
> - (도메인 용어가 있으면) `docs/project/glossary.md`
>
> `project-init` 플러그인 hook이 브랜치·commit 메시지 + agent-readable docs convention (size, TOC, fenced lang, links, drift) + `## Project Charter` 필수 항목(vision·non-goals·tech-stack)을 자동 검증합니다.
> AGENTS.md primary 패턴으로 OpenAI Codex, Cursor, Aider 등 16+ 벤더가 동일 파일을 인식합니다.
> 간결한 git 작업을 위해 `/commit` 또는 `/commit-push-pr` (commit-commands 플러그인) 사용.
