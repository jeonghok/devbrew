---
name: project-init-project-charter
version: 1.0.0
created_at: 2026-05-31
session_id: brainstorm-2026-05-31-project-charter
status: locked
next_phase: writing-plans
source: superpowers/brainstorming + reference corpus 탐색(Explore agent — ouroboros seed/project-context, oh-my-codex deep-interview, oh-my-claudecode project-memory, compound-engineering) + 5개 웹검색(project charter, CLAUDE.md hierarchy, AGENTS.md 오픈 스펙, spec-driven development + ADR)
---

# project-init — Project Charter surface 디자인 스펙 (v1.6.0)

> **For agentic workers:** 이 문서는 `plugins/project-init/`에 **프로젝트 헌장(Project Charter)** surface를 추가하기 위한 v1.6.0 변경 명세이다. `/project-init` 흐름에 fact-routing 경량 인터뷰 step을 더해, 프로젝트의 *거의 안 변하는* 정의(vision·non-goals·tech-stack·conventions·glossary)를 1회성으로 elicit하고, 이를 `AGENTS.md`의 `## Project Charter` 요약 섹션 + `docs/project/` 상세 파일로 발행한다. 일관성 유지는 (a) 헌장이 AGENTS.md 계층으로 매 세션 자동 상속되는 passive 메커니즘 + (b) 기존 `docs-lint.py` hook을 확장한 구조 무결성 advisory로 달성한다. **새 hook·새 kill-switch는 0개.** 다음 단계는 superpowers `writing-plans` skill로 implementation plan을 생성하는 것이다.

## 목차

- §1 [Goal](#goal)
- §2 [Context / Why](#context--why)
- §3 [Goals](#goals)
- §4 [Non-goals](#non-goals)
- §5 [Constraints](#constraints)
- §6 [흐름 & 멱등 state matrix](#흐름--멱등-state-matrix)
- §7 [Acceptance Criteria](#acceptance-criteria)
- §8 [Files to Create / Modify](#files-to-create--modify)
- §9 [Verification Plan](#verification-plan)
- §10 [Rejected Alternatives](#rejected-alternatives) — §10.0 Adopted / §10.1 Rejected
- §11 [Metadata](#metadata)

## Goal

`plugins/project-init/`에 **프로젝트 헌장 레이어**를 추가한다. 구체적으로:

- **(a)** `/project-init` 커맨드에 charter step을 추가한다. **Phase 0 (사실 발견, 질문 0개)** — agent가 repo의 의존성 manifest와 디렉토리 구조를 스캔해 tech-stack을 자동 후보로 채운다. **Phase 1 (판단 질문, AskUserQuestion ≤4개)** — vision·non-goals·핵심 conventions·tech-stack 확인만 사용자에게 묻는다 (fact-routing: 사실은 안 묻고 판단만).
- **(b)** elicit된 헌장을 `AGENTS.md`의 `## Project Charter` 요약 섹션(≤약 25줄) + `docs/project/charter.md`·`docs/project/conventions.md`(+ 조건부 `glossary.md`) 상세 파일로 발행한다. `CLAUDE.md`는 기존 `@AGENTS.md` thin pointer 유지.
- **(c)** 기존 `hooks/docs-lint.py`를 확장해 `docs/project/*.md`를 검사 대상에 추가하고, `AGENTS.md`의 `## Project Charter` 필수 하위항목(vision·non-goals·tech-stack) 누락을 advisory로 검출한다. 새 hook 파일·새 kill-switch 토큰 없음.

세 변경을 한 PR (v1.6.0)로 동시 출시.

**Coupling 근거 (왜 단일 PR인가)**: (a) 커맨드만 출시하면 헌장 파일이 어떤 룰로도 검증되지 않아 사람 손에 의해 `## Project Charter`가 빈 채로 drift할 위험이 무방비다. (c) docs-lint 확장만 먼저 깔면 검사 대상(`docs/project/`)이 존재하지 않아 룰이 영원히 발화하지 않는다 (v1.4.0 R-pointer chicken-and-egg와 동형). 둘을 한 PR로 묶어야 헌장 발행과 그 검증의 *살아있는 baseline*이 동시에 생긴다.

## Context / Why

devbrew 생태계는 셋이다 — `project-init`(부트스트랩: git-workflow + docs-lint), `spec-distill`(per-feature interview→`spec.md`, Law 1), `quality-gates`(review, Law 2). **프로젝트 *전체*를 관통하는 "헌장" 레이어가 비어 있다.** spec-distill은 *기능 하나*의 명확성을 다루지만, "이 프로젝트는 무엇이고 어떤 컨벤션·비목표·tech-stack 위에서 도는가"라는 *프로젝트 수준의 durable 정의*는 어디에도 없다. 그 결과 모든 새 spec-distill 인터뷰와 모든 새 세션이 매번 같은 맥락을 처음부터 재확인해야 한다.

브레인스토밍 세션에서 reference corpus 탐색 + 5개 웹검색이 다음을 강하게 수렴 확인했다:

1. **"프로젝트 시작 시 무엇을 정의하는가"** — project charter(vision/objectives/scope/**non-goals**/success criteria — [Asana](https://asana.com/resources/project-charter), [projectmanager.com](https://www.projectmanager.com/blog/project-charter))와 AGENTS.md 오픈 스펙(tech-stack+버전, conventions, build/test, *always do / ask first / never do* 3단 경계 — [agents.md](https://agents.md/), [GitHub Blog 2,500 repos](https://github.blog/ai-and-ml/github-copilot/how-to-write-a-great-agents-md-lessons-from-over-2500-repositories/))이 거의 같은 항목으로 수렴. spec-driven development는 spec=*what*, ADR=*why*로 시간 축을 분리 ([intent-driven.dev](https://intent-driven.dev/blog/2026/04/29/spec-driven-development-with-adr/)).
2. **fact-routing은 reference 4개 공통 패턴** — ouroboros `seed`/`project-context.md`, oh-my-codex `deep-interview` 모두 *agent가 코드에서 발견 가능한 사실*은 자동 채우고(`[from-code][auto-confirmed]` 라벨), *사용자에겐 판단만* 묻는다. *"Execution quality is usually bottlenecked by intent clarity, not just missing implementation detail."* (oh-my-codex)
3. **CLAUDE.md/AGENTS.md 계층의 핵심은 "thin root + 상속"** — root는 모든 패키지 공통 룰만 얇게, 상세는 하위로 ([Claude Code Docs memory](https://code.claude.com/docs/en/memory), [AI Agent Factory](https://agentfactory.panaversity.org/docs/General-Agents-Foundations/claude-code-teams-cicd/claude-md-configuration-hierarchy)). project-init의 docs-lint이 이미 강제하는 size≤200 규칙이 이 철학의 enforcement다.

**v1.5.0 선례 (중요)**: 직전 릴리스 v1.5.0은 `## LLM Coding Guidelines`라는 *canned 의견 주입*을 전면 제거했다. 본 헌장 기능은 그 정반대 방향이다 — devbrew의 의견이 아니라 **사용자가 직접 elicit한 프로젝트 정의**를 캡처한다. fact-routing이 "agent의 추측"과 "사용자만 아는 판단"을 가르며, 어떤 canned baseline도 주입하지 않는다 (AC14).

`project-init`은 이미 "요약은 AGENTS.md, 상세는 `docs/`"(git-workflow) 패턴과 멱등 4-state matrix를 가지고 있으므로, 헌장은 그 형태의 자연스러운 동형 확장이다.

## Goals

- **G1 — Charter surface 추가**: `/project-init`에 charter step. Phase 0 fact-discovery(자동) + Phase 1 judgment AskUserQuestion(≤4개). 캡처 항목 — vision, non-goals, tech-stack(+버전), 핵심 conventions, glossary(조건부).
- **G2 — fact-routing**: tech-stack·디렉토리 구조·build/test 명령은 repo 스캔으로 자동 후보 생성 후 `[감지됨]` 라벨로 사용자 확인만 받는다. 사실 항목은 open-ended 재질문 금지.
- **G3 — AGENTS.md 요약 + docs/project/ 상세**: `AGENTS.md`에 `## Project Charter` 요약 섹션(vision·non-goals 압축·tech-stack·docs/project/ 포인터, ≤약 25줄). 상세는 `docs/project/charter.md`·`conventions.md`(+ 조건부 `glossary.md`). CLAUDE.md는 `@AGENTS.md` thin pointer 유지.
- **G4 — 멱등 재실행**: 기존 `## Project Charter` 섹션/`docs/project/` 감지 시 "헌장 업데이트할까요?" 프롬프트. 거절=unchanged 유지, 승인=in-place 갱신. 비-관리 콘텐츠는 모든 경로에서 보존 (기존 4c matrix 정신).
- **G5 — passive 상속이 일관성의 본질**: 헌장이 AGENTS.md 계층에 거주하므로 매 세션·모든 spec-distill 인터뷰가 자동 상속. 추가 런타임 비용 0.
- **G6 — docs-lint 구조 검증 (새 hook 0개)**: 기존 `docs-lint.py`의 `TARGET_RELPATHS`에 `docs/project/*.md` 추가 + `AGENTS.md` `## Project Charter` 필수 하위항목(vision·non-goals·tech-stack) 비어있음 검출 룰 추가. non-blocking advisory.
- **G7 — kill-switch 재사용**: `DEVBREW_DISABLE_PROJECT_INIT=1`(전체) 및 `DEVBREW_SKIP_HOOKS=project-init:docs-lint`(이 hook)가 헌장 검증까지 커버. 새 토큰 0개.
- **G8 — Law 1 구조적 게이트**: 최초 실행에서 vision·non-goals·tech-stack·conventions가 채워질 때까지 진행 불가 — silent 빈 헌장 금지. project-init에 *처음으로* 생기는 clarity 게이트.
- **G9 — devbrew Plugin Shape 준수**: `plugin.json` `1.5.0`→`1.6.0`(새 surface=minor), `CHANGELOG.md` `[1.6.0]` Added, `README.md` Architecture/동작/Hooks/Principles 동기화.
- **G10 — Unit test 동반**: docs-lint 확장(신규 타겟 + `## Project Charter` 필수항목 룰)의 happy/violation 케이스를 기존 `test_docs_lint.py`에 추가 + fixtures 동반.

## Non-goals

- **NG1 — per-feature spec 안 함**: 기능 하나의 spec은 `spec-distill`의 영역. 헌장은 *프로젝트 수준 불변 정의*만. spec-distill의 4-block Socratic interview 머신을 재사용·위임하지 않는다 (semantic mismatch + cross-plugin 결합 회피).
- **NG2 — ADR / 결정 로그 안 함**: 결정의 *why*를 누적하는 ADR 로그는 "헌장 레이어" scope 밖 (사용자가 "+ 진화하는 결정 로그" 옵션을 명시적으로 reject). 미래 별도 surface 또는 별도 플러그인 영역.
- **NG3 — 능동 drift 감지 안 함**: 헌장 tech-stack/conventions가 실제 코드와 갈라지는지를 semantic하게 감지하는 hook은 범위 밖 — false-positive 위험 + 새 kill-switch 필요. 일관성은 passive 상속 + 구조 무결성 advisory까지만 (사용자 선택 "상속 + 구조 검증").
- **NG4 — opinionated 콘텐츠 주입 안 함**: charter 콘텐츠는 100% 사용자 elicited. v1.5.0이 제거한 `## LLM Coding Guidelines` 류의 canned baseline을 재도입하지 않는다.
- **NG5 — nested per-directory 헌장 안 함**: 하위 디렉토리별 `AGENTS.md` 자동 scaffold는 v1.6.0 범위 밖 (YAGNI). root 헌장만. 미래 확장 가능.
- **NG6 — 새 hook 파일·새 hooks.json entry 안 함**: `docs-lint.py` 확장만. `post-tool-use.py`·`hooks.json` 무변경 (NG6 = v1.4.0 NG6 정신 계승).
- **NG7 — charter step skip 허용 안 함**: 최초 실행에서 charter step을 명시적으로 건너뛰는 옵션을 두지 않는다 (사용자가 "skip 가능" 옵션 reject) — silent 헌장 부재는 Law 1 위반. 단 멱등 재실행 시 기존 완전 헌장은 재질문 면제(G4).
- **NG8 — 자동 fix 안 함**: docs-lint 확장은 검증·경고만, mutation 안 함 (기존 advisory 정신).

## Constraints

- **C1 — Python 3 stdlib only**: `docs-lint.py` 확장은 기존과 동일하게 `json`/`os`/`re`/`sys`/`pathlib`만. PyYAML 등 외부 의존성 금지 (frontmatter/섹션 parse는 정규식으로).
- **C2 — Advisory non-blocking 유지**: 확장된 docs-lint 룰도 `{"systemMessage": ...}` 또는 `{}` exit 0. `decision: "block"` 금지.
- **C3 — Worktree-safe**: 기존 `WORKTREE_MARKER` skip + `CLAUDE_PROJECT_DIR` 기준 path resolve 패턴 그대로. `docs/project/*.md` 타겟도 동일 정규화 경로 통과.
- **C4 — Kill switch는 보안 컨트롤**: kill switch active 시 어떤 위반이 있어도 무조건 `{}` exit. 우회 금지.
- **C5 — size≤200 자기 준수**: 생성된 `AGENTS.md` `## Project Charter`는 요약만 — 기존 docs-lint R1(≤200줄)을 위반하지 않도록 상세는 전부 `docs/project/`로 내린다.
- **C6 — fact-routing graceful degradation**: Phase 0 자동 감지가 manifest를 못 찾으면 crash 금지 — 사용자에게 직접 tech-stack을 묻는 fallback으로 downgrade하되 fallback이 돌았음을 출력에 명시 (loud logging).
- **C7 — 템플릿은 skeleton**: 헌장 템플릿은 placeholder가 있는 *빈 골격*이다 (git-workflow 템플릿과 동형). 커맨드가 elicit된 값으로 placeholder를 치환한다. 템플릿에 의견 콘텐츠를 넣지 않는다 (NG4와 연결).
- **C8 — 멱등성 (Law 3 idempotent state machine 정신)**: charter step은 재실행 시 부분 진행/중복 섹션을 만들지 않는다 — §6 state matrix를 정확히 따른다.

## 흐름 & 멱등 state matrix

**커맨드 흐름** (기존 Step 1–5에 charter 통합):

1. **Step 1 (감지)** — 기존 git-workflow 감지 + `AGENTS.md`의 `## Project Charter` 섹션 존재 여부 + `docs/project/` 존재 여부 추가 감지.
2. **Step 2 (branching strategy 선택)** — 기존 그대로.
3. **Step 3 (git 커스터마이징 질문)** — 기존 그대로.
4. **Step 3.5 (charter — 신규)**:
   - **Phase 0 (사실 발견)**: manifest(`package.json`/`pyproject.toml`/`requirements.txt`/`go.mod`/`Cargo.toml`/`pom.xml`/`build.gradle` 등)·디렉토리 구조·테스트 명령 스캔 → tech-stack 후보 `[감지됨]` 라벨.
   - **Phase 1 (판단 질문 ≤4)**: ① vision 한 문장(필수) ② non-goals(필수) ③ 핵심 conventions 1–3개(필수) ④ 감지 tech-stack 확인(필수). 도메인 용어가 자연 발생하면 glossary 후보로 수집.
5. **Step 4 (파일 생성)** — 기존 git-workflow 파일 + 헌장 파일(`## Project Charter` 섹션, `docs/project/charter.md`·`conventions.md`, 조건부 `glossary.md`)을 §6 matrix에 따라 발행.
6. **Step 5 (확인)** — 생성/갱신 결과 보고에 헌장 파일 추가.

**Charter state matrix** (`## Project Charter` 섹션 × `docs/project/` 기준):

| State | `## Project Charter` | `docs/project/` | Action |
|---|---|---|---|
| **C-S1 (clean)** | 없음 | 없음 | Phase 0+1 진행 → 헌장 신규 발행 (섹션 + docs 파일). |
| **C-S2 (existing complete)** | 존재(필수항목 채움) | 존재 | "헌장 업데이트할까요?" 프롬프트. 거절=unchanged. 승인=Phase 0+1 재진행 후 `## Project Charter` 섹션 in-place 갱신 + docs 파일 갱신. **재질문 면제** = 최초 게이트(G8) 비적용. |
| **C-S3 (partial/drifted)** | 존재(필수항목 일부 누락) 또는 docs 불일치 | 부분 | advisory 후 Phase 1의 누락 항목만 보충 질문 → 필수항목 충족까지 채움(G8 적용). |

비-관리 콘텐츠(다른 헤딩·단락·코드 블록)는 모든 state에서 보존.

## Acceptance Criteria

- **AC1** — `/project-init`에 charter step(Step 3.5)이 branching 커스터마이징 이후·파일 생성 이전에 진입한다.
- **AC2** — Phase 0이 의존성 manifest와 디렉토리 구조를 스캔해 tech-stack을 자동 후보로 채우고 `[감지됨]` 라벨을 붙인다. manifest 부재 시 직접 질문 fallback으로 downgrade하며 fallback 사실을 출력에 명시한다 (C6).
- **AC3** — Phase 1이 AskUserQuestion으로 ≤4개 판단 질문만 한다: vision·non-goals·핵심 conventions(1–3)·감지 tech-stack 확인. 자동 감지된 사실은 open-ended 재질문하지 않는다.
- **AC4** — `AGENTS.md`에 `## Project Charter` 요약 섹션이 생성된다: vision, non-goals(압축), tech-stack, `docs/project/` 포인터 포함, ≤약 25줄(C5/기존 R1 준수).
- **AC5** — `docs/project/charter.md`가 생성된다: vision, goals, non-goals, success criteria/Definition of Done, key personas.
- **AC6** — `docs/project/conventions.md`가 생성된다: naming, 디렉토리 구조, error-handling, anti-patterns, build/test 명령.
- **AC7** — `docs/project/glossary.md`는 **조건부** — Phase 1에서 도메인 용어가 elicit된 경우에만 생성. 용어가 없으면 파일을 만들지 않는다(빈 파일 금지).
- **AC8** — `CLAUDE.md`는 `@AGENTS.md` thin pointer 유지(C-S1이면 신규 생성, 그 외 unchanged).
- **AC9** — 멱등 재실행: §6 matrix대로 동작. C-S2 거절 시 헌장 unchanged + 비-관리 콘텐츠 보존, 중복 `## Project Charter` 섹션을 만들지 않는다.
- **AC10** — Law 1 게이트: 최초 실행(C-S1) 및 C-S3에서 vision·non-goals·tech-stack·conventions가 채워질 때까지 charter step을 완료할 수 없다. C-S2(완전 헌장)는 재질문 면제.
- **AC11** — `docs-lint.py`가 확장되어 `docs/project/*.md`를 검사하고, `AGENTS.md` `## Project Charter`의 필수 하위항목(vision·non-goals·tech-stack) 누락을 advisory(`systemMessage`)로 검출한다. pass 시 `{}`.
- **AC12** — kill-switch 재사용: `DEVBREW_DISABLE_PROJECT_INIT=1` 및 `DEVBREW_SKIP_HOOKS=project-init:docs-lint`가 헌장 검증도 끈다. 새 kill-switch 토큰 0개.
- **AC13** — 새 hook 파일 0개, `hooks.json` entry 추가 0개, `post-tool-use.py` 무변경.
- **AC14** — charter 콘텐츠는 100% 사용자 elicited. 어떤 canned/opinionated baseline도 주입하지 않는다(v1.5.0 `## LLM Coding Guidelines` 재도입 금지).
- **AC15** — Plugin shape: `plugin.json` `1.5.0`→`1.6.0` + description에 charter surface 반영, `CHANGELOG.md` `[1.6.0] — 2026-05-31` Added, `README.md` Architecture/동작/Hooks/Principles Instantiated 동기화.
- **AC16** — docs-lint 확장의 모든 신규 룰(신규 타겟 + `## Project Charter` 필수항목)에 happy/violation 케이스를 `test_docs_lint.py`에 추가하고 fixtures를 동반한다.
- **AC17** — `README.md` "Principles Instantiated"에 Law 1(charter = project-init 최초 clarity 구조 게이트)과 Law 3(charter = 매 세션·모든 spec-distill 인터뷰가 상속하는 compounding substrate) 한 줄씩 추가.

## Files to Create / Modify

**Create:**
- `plugins/project-init/templates/project/agents-md-section.md` — `## Project Charter` 요약 skeleton (placeholder: `{{VISION}}`, `{{NON_GOALS}}`, `{{TECH_STACK}}`).
- `plugins/project-init/templates/project/charter.md` — charter.md skeleton (vision·goals·non-goals·DoD·personas placeholder).
- `plugins/project-init/templates/project/conventions.md` — conventions.md skeleton (naming·구조·error·anti-pattern·build/test placeholder).
- `plugins/project-init/templates/project/glossary.md` — glossary.md skeleton (조건부 발행).
- `plugins/project-init/hooks/tests/fixtures/charter_*/` — 신규 fixtures(완전 헌장 / 필수항목 누락 / docs/project drift 등).

**Modify:**
- `plugins/project-init/commands/project-init.md` — Step 1 감지 확장, Step 3.5 charter 흐름(Phase 0/1) 추가, Step 4 헌장 발행 + §6 state matrix, Step 5 확인 메시지.
- `plugins/project-init/hooks/docs-lint.py` — `TARGET_RELPATHS`에 `docs/project/*.md` 추가(glob 또는 prefix 매칭) + `## Project Charter` 필수 하위항목 룰.
- `plugins/project-init/hooks/tests/test_docs_lint.py` — 신규 룰 happy/violation 테스트.
- `plugins/project-init/.claude-plugin/plugin.json` — version `1.5.0`→`1.6.0`, description에 charter 반영.
- `plugins/project-init/CHANGELOG.md` — `[1.6.0] — 2026-05-31` Added.
- `plugins/project-init/README.md` — 아키텍처 트리, 동작 방식, 기능 표, Hooks, Principles Instantiated 동기화.

## Verification Plan

- **Unit (repo root에서)**: `python3 plugins/project-init/hooks/tests/test_docs_lint.py` — 신규 charter 룰 happy/violation 통과. (기존 reds baseline은 무관 — docs-lint 테스트만 대상.)
- **Smoke**: `bash plugins/project-init/hooks/tests/smoke.sh` 회귀 없음.
- **Manual — clean(C-S1)**: 빈 디렉토리에서 `/project-init` → `AGENTS.md ## Project Charter` + `docs/project/charter.md`·`conventions.md` 생성 확인. 도메인 용어 미언급 시 `glossary.md` **부재** 확인(AC7).
- **Manual — fact-routing**: node repo(package.json 존재)에서 실행 → tech-stack 자동 감지 + `[감지됨]` 라벨, 재질문 없음(AC2/AC3). manifest 없는 디렉토리 → fallback 질문 + loud 명시(C6).
- **Manual — 멱등(C-S2)**: 재실행 → "업데이트할까요?" 프롬프트, 거절 시 unchanged + 중복 섹션 없음(AC9). 승인 시 in-place 갱신.
- **Manual — Law 1 게이트(AC10)**: C-S1에서 non-goals를 빈 채로 진행 시도 → 채울 때까지 완료 불가.
- **docs-lint(AC11)**: `## Project Charter`의 vision을 비운 `AGENTS.md`를 Write → advisory 발화. 완전하면 `{}`.
- **kill-switch(AC12)**: `DEVBREW_SKIP_HOOKS=project-init:docs-lint` 설정 후 위 위반 재현 → advisory 미발화.
- **Plugin shape(AC15)**: plugin.json 1.6.0, CHANGELOG/README 동기화 육안 확인.

## Rejected Alternatives

### §10.0 Adopted Approach

project-init에 **프로젝트 헌장 레이어**를 추가한다: (1) `/project-init` 안 fact-routing 경량 인터뷰 step(재실행 멱등), (2) `AGENTS.md ## Project Charter` 요약 + `docs/project/` 상세(charter·conventions + 조건부 glossary), (3) 기존 `docs-lint.py` 확장으로 구조 무결성 advisory. 일관성은 passive 상속(본질) + 구조 검증(보강). 새 hook·새 kill-switch 0개.

### §10.1 Rejected

- **R1 — spec-distill 인터뷰 재사용/위임**: cross-plugin 결합 + per-feature용으로 튜닝된 4-block Socratic을 프로젝트-레벨로 전용하는 semantic mismatch + 무거움. (사용자 reject; NG1.)
- **R2 — 헌장 전부 AGENTS.md 안에**: size≤200 위반 + root context bloat → context rot. (C5/G3로 상세를 docs/로 분리.)
- **R3 — 별도 PROJECT.md 전용 파일**: AGENTS.md 계층 밖이라 매 세션 자동 로드 안 됨 → 사용자의 "계층구조" 요구·passive 상속(G5)과 어긋남.
- **R4 — ADR / 결정 로그 포함**: "헌장 레이어" scope 밖, lightness 위반. (사용자 reject; NG2.)
- **R5 — 능동 drift 감지 hook**: false-positive + 새 kill-switch + 무거움. (사용자 reject; NG3.)
- **R6 — 인터뷰 없는 템플릿+채우기**: Law 1 clarity 게이트 약화 — 빈 헌장이 silent 통과. (G8/NG7로 대체.)
- **R7 — charter step skip 허용**: silent 헌장 부재 = Law 1 위반. (사용자 reject; NG7.)
- **R8 — 별도 `/project-charter` 커맨드**: surface 증가 + "first-setup에서 시작" 응집 약화. (사용자가 "step 통합" 선택.)

## Metadata

- **name**: project-init-project-charter
- **version**: 1.0.0 (이 spec 문서의 버전; 대상 플러그인 릴리스는 project-init v1.6.0)
- **created_at**: 2026-05-31
- **session_id**: brainstorm-2026-05-31-project-charter
- **status**: locked
- **next_phase**: writing-plans
- **target_plugin**: plugins/project-init (1.5.0 → 1.6.0, minor)
- **source**: superpowers/brainstorming + reference corpus Explore(ouroboros seed/project-context, oh-my-codex deep-interview, oh-my-claudecode project-memory, compound-engineering) + 5개 웹검색(project charter, CLAUDE.md hierarchy, AGENTS.md 오픈 스펙, spec-driven dev + ADR)
- **devbrew Laws**: Law 1(charter 구조 게이트), Law 3(charter = compounding 상속 substrate)
