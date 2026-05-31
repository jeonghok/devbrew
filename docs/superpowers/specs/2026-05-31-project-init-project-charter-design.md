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
- §11 [Handoff Context](#handoff-context)
- §12 [Metadata](#metadata)

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
- **G6 — docs-lint 구조 검증 (새 hook 0개)**: 기존 `docs-lint.py`에 additive predicate(C10)로 `docs/project/*.md`를 대상에 더하고 + `AGENTS.md` `## Project Charter` 필수 하위항목(vision·non-goals·tech-stack) 비어있음/placeholder 잔존 검출 룰 추가. non-blocking advisory.
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
- **NG7 — charter step skip 허용 안 함**: 헌장이 *없는* 최초 실행(C-S1)에서 charter step을 건너뛰는 옵션을 두지 않는다 (사용자가 "skip 가능" 옵션 reject) — silent 헌장 부재는 Law 1 위반. **경계 명확화**: C-S2(이미 완전한 헌장 존재)에서 "업데이트할까요?"에 *거절*하는 것은 skip이 아니라 G4 면제의 합법적 행사다 — 헌장은 이미 존재해 Law 1 충족 상태이고, 거절을 반복해도 위반이 아니다. 즉 "skip 금지"는 *헌장 생성*(C-S1)에만 걸리고, *기존 헌장 갱신 거절*(C-S2)에는 걸리지 않는다.
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
- **C9 — Law 1 게이트는 bounded (Unbounded-autonomy anti-pattern 회피)**: G8 게이트는 무한 루프가 아니다. 각 필수 항목(vision·non-goals·conventions)에 대해 AskUserQuestion 재질문을 **최대 3회**까지 한다. 3회 후에도 비면 charter step을 *loud advisory와 함께 abort*(silent 아님 — 예: `[project-init] charter 미완료: <항목> 비어 abort. docs-lint이 플래그합니다.`)하고, git-workflow 산출물은 정상 생성하며, 미완 charter는 docs-lint(AC11)이 사후 검출한다. abort는 Law 1 위반이 아니다(부재가 loud + 검출되므로).
- **C10 — docs-lint TARGET 확장은 additive (regression-free)**: 기존 `TARGET_RELPATHS` exact-set membership(4개 root 파일)은 *그대로 둔다*. `resolve_target_path()`에 별도 predicate `is_charter_doc(rel)` = `rel.startswith("docs/project/") and rel.endswith(".md")`를 OR로 추가한다. set 리팩터링 금지 — 4-path exact-match 보장이 흔들리지 않게. charter doc은 기존 R1/R2/R5/R6 룰을 그대로 받고, `## Project Charter` 필수항목 룰은 AGENTS.md(루트 컨텍스트)에만 적용.
- **C11 — Phase 0는 command-prose (의도적 lightness 결정)**: fact-discovery는 별도 Python helper로 추출하지 않고 command instruction이 `Glob`/`Read`로 manifest를 직접 읽어 추론한다 — 기존 project-init command(Step 1–5)가 전부 command-prose이고 command-flow 자동 테스트가 없는 패턴과 일관(새 `scripts/` surface 0). 결과적으로 AC2/C6의 검증은 manual(§9). deterministic helper 추출은 manual 검증이 flaky로 판명될 때의 미래 옵션으로 §11 Handoff에 deferral.

## 흐름 & 멱등 state matrix

**커맨드 흐름** (기존 Step 1–5에 charter 통합):

1. **Step 1 (감지)** — 기존 git-workflow 감지 + charter state(C-S1/C-S2/C-S3)를 *파일 레벨*로 판정한다. 이 판정은 **Phase 0보다 선행**한다. 판정 입력: (a) `AGENTS.md`에 `## Project Charter` 섹션 존재 여부, (b) 그 섹션의 vision·non-goals·tech-stack 레이블이 모두 비어있지 않고 `{{...}}` placeholder가 아닌지(= `charter_section_complete`), (c) `docs/project/charter.md`와 `docs/project/conventions.md`가 모두 존재하는지(= `docs_complete`; `glossary.md`는 조건부라 completeness 판정에서 제외).
2. **Step 2 (branching strategy 선택)** — 기존 그대로.
3. **Step 3 (git 커스터마이징 질문)** — 기존 그대로.
4. **Step 3.5 (charter — 신규)**:
   - **Phase 0 (사실 발견)**: manifest(`package.json`/`pyproject.toml`/`requirements.txt`/`go.mod`/`Cargo.toml`/`pom.xml`/`build.gradle` 등)·디렉토리 구조·테스트 명령 스캔 → tech-stack 후보 `[감지됨]` 라벨.
   - **Phase 1 (판단 질문 ≤4)**: ① vision 한 문장(필수) ② non-goals(필수) ③ 핵심 conventions 1–3개(필수) ④ 감지 tech-stack 확인(필수). 도메인 용어가 자연 발생하면 glossary 후보로 수집.
5. **Step 4 (파일 생성)** — 기존 git-workflow 파일 + 헌장 파일(`## Project Charter` 섹션, `docs/project/charter.md`·`conventions.md`, 조건부 `glossary.md`)을 §6 matrix에 따라 발행.
6. **Step 5 (확인)** — 생성/갱신 결과 보고에 헌장 파일 추가.

**직렬 순서 (interleave 금지)**: Step 3.5는 Step 3(git 커스터마이징 질문, Git Flow의 release-branch 질문 포함)이 *모두 끝난 뒤* 시작한다 — branching 질문과 charter 질문을 교차하지 않는다. Phase 1의 "≤4개" 한도는 charter 질문에만 적용되며 git step의 질문 수와 합산하지 않는다 (독립 카운트).

**Charter state matrix** (Step 1에서 판정한 `charter_section_complete` × `docs_complete` 기준):

| State | 판정 조건 (Step 1, 파일 레벨) | Action |
|---|---|---|
| **C-S1 (clean)** | `## Project Charter` 부재 **AND** `docs/project/charter.md` 부재 | Phase 0+1 진행 → 헌장 신규 발행(섹션 + docs 파일). Law 1 게이트(G8) 적용. |
| **C-S2 (complete)** | `charter_section_complete` == true **AND** `docs_complete` == true | "헌장 업데이트할까요?" 프롬프트. 거절=unchanged(중복 섹션 생성 안 함). 승인=Phase 0+1 재진행 후 in-place 갱신. **재질문 면제**(최초 게이트 G8 비적용). |
| **C-S3 (partial/drifted)** | 위 둘 어디에도 해당 안 함 — 섹션 존재하나 `charter_section_complete`==false, **또는** 섹션 완전하나 `docs_complete`==false | advisory로 누락 항목/파일 명시 후 분기: **(a) 섹션 항목 누락** → Phase 1 보충 질문(G8 적용, 충족까지). **(b) docs 파일만 누락**(섹션 내용은 완전) → 질문 없이 누락 파일만 기존 섹션 값으로 생성. |

비-관리 콘텐츠(다른 헤딩·단락·코드 블록)는 모든 state에서 보존.

## Acceptance Criteria

- **AC1** — `/project-init`에 charter step(Step 3.5)이 branching 커스터마이징 이후·파일 생성 이전에 진입한다.
- **AC2** — Phase 0이 의존성 manifest와 디렉토리 구조를 스캔해 tech-stack을 자동 후보로 채우고 `[감지됨]` 라벨을 붙인다. manifest 부재 시 직접 질문 fallback으로 downgrade하며 fallback 사실을 출력에 명시한다 (C6).
- **AC3** — Phase 1이 AskUserQuestion으로 ≤4개 판단 질문만 한다: vision·non-goals·핵심 conventions(1–3)·감지 tech-stack 확인. 자동 감지된 사실은 open-ended 재질문하지 않는다.
- **AC4** — `AGENTS.md`에 `## Project Charter` 요약 섹션이 생성된다: vision, non-goals(압축), tech-stack, `docs/project/` 포인터 포함, ≤약 25줄(C5/기존 R1 준수).
- **AC5** — `docs/project/charter.md`가 다음 고정 `##` 헤딩 구조로 생성된다: `## Vision`, `## Goals`, `## Non-goals`, `## Success Criteria / Definition of Done`, `## Personas`. (헤딩 고정 → content·링크 검증 가능.)
- **AC6** — `docs/project/conventions.md`가 다음 고정 `##` 헤딩 구조로 생성된다: `## Naming`, `## Directory Structure`, `## Error Handling`, `## Anti-patterns`, `## Build & Test`.
- **AC7** — `docs/project/glossary.md`는 **조건부** — Phase 1에서 도메인 용어가 elicit된 경우에만 생성. 용어가 없으면 파일을 만들지 않는다(빈 파일 금지).
- **AC8** — `CLAUDE.md`는 `@AGENTS.md` thin pointer 유지(C-S1이면 신규 생성, 그 외 unchanged).
- **AC9** — 멱등 재실행: §6 matrix대로 동작. C-S2 거절 시 헌장 unchanged + 비-관리 콘텐츠 보존, 중복 `## Project Charter` 섹션을 만들지 않는다.
- **AC10** — Law 1 게이트(bounded): 최초 실행(C-S1) 및 C-S3에서 vision·non-goals·tech-stack·conventions가 채워질 때까지 AskUserQuestion 재질문으로 진행을 막되, 각 항목 **최대 3회** 재질문 후에도 비면 loud advisory와 함께 charter step을 abort한다(C9 — unbounded 루프 금지). C-S2(완전 헌장)는 재질문 면제.
- **AC11** — `docs-lint.py`가 additive predicate(C10)로 `docs/project/*.md`를 검사 대상에 추가하고(기존 4-path exact-match 불변), `AGENTS.md`의 `## Project Charter` **섹션 내부**(다음 `##` heading 전까지 heading-bounded)에서 vision·non-goals·tech-stack 레이블이 (i) 존재하고 (ii) 비어있지 않으며 (iii) `{{...}}` placeholder 잔존이 아닌지를 검사해 위반 시 advisory(`systemMessage`)로 검출한다. pass 시 `{}`. `AGENTS.md`의 `docs/project/charter.md` 포인터 링크는 기존 R6(link resolve)이 의도적으로 함께 검증.
- **AC12** — kill-switch 재사용: `DEVBREW_DISABLE_PROJECT_INIT=1` 및 `DEVBREW_SKIP_HOOKS=project-init:docs-lint`가 헌장 검증도 끈다. 새 kill-switch 토큰 0개.
- **AC13** — 새 hook 파일 0개, `hooks.json` entry 추가 0개, `post-tool-use.py` 무변경.
- **AC14** — charter 콘텐츠는 100% 사용자 elicited. 어떤 canned/opinionated baseline도 주입하지 않는다(v1.5.0 `## LLM Coding Guidelines` 재도입 금지).
- **AC15** — Plugin shape: `plugin.json` `1.5.0`→`1.6.0` + description에 charter surface 반영, `CHANGELOG.md` `[1.6.0] — 2026-05-31` Added, `README.md` Architecture/동작/Hooks/Principles Instantiated 동기화.
- **AC16** — docs-lint 확장의 모든 신규 룰(신규 타겟 + `## Project Charter` 필수항목)에 happy/violation 케이스를 `test_docs_lint.py`에 추가하고 fixtures를 동반한다.
- **AC17** — `README.md` "Principles Instantiated"에 Law 1(charter = project-init 최초 clarity 구조 게이트)과 Law 3(charter = 매 세션·모든 spec-distill 인터뷰가 상속하는 compounding substrate) 한 줄씩 추가.

## Files to Create / Modify

**Create:**
- `plugins/project-init/templates/project/agents-md-section.md` — `## Project Charter` 요약 skeleton (placeholder: `{{VISION}}`, `{{NON_GOALS}}`, `{{TECH_STACK}}`).
- `plugins/project-init/templates/project/charter.md` — charter.md skeleton, 고정 헤딩 `## Vision`/`## Goals`/`## Non-goals`/`## Success Criteria / Definition of Done`/`## Personas` + 각 항목 `{{...}}` placeholder (AC5와 일치).
- `plugins/project-init/templates/project/conventions.md` — conventions.md skeleton, 고정 헤딩 `## Naming`/`## Directory Structure`/`## Error Handling`/`## Anti-patterns`/`## Build & Test` + placeholder (AC6와 일치).
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
- **Law 1 bounded(AC10/C9)**: 필수 항목을 3회 빈 응답으로 진행 시도 → charter step이 loud advisory와 함께 abort하고 git-workflow 산출물은 정상 생성됨 확인(무한 루프 없음).
- **docs-lint placeholder 잔존 + 회귀(AC11/C10)**: `## Project Charter`의 vision을 `{{VISION}}`로 둔 `AGENTS.md` Write → advisory 발화. additive predicate가 기존 4-path 검사를 깨지 않음을 기존 `test_docs_lint.py` green 유지로 회귀 확인.

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

## Handoff Context

> writing-plans를 실행할 다음 세션을 위한 packet.

### TL;DR (핵심 결정 3)
1. project-init에 **프로젝트 헌장 레이어** 추가 — spec-distill(per-feature) 위의 프로젝트-수준 불변 정의. fact-routing 경량 인터뷰(Phase 0 자동 감지 + Phase 1 ≤4 판단 질문).
2. 발행: `AGENTS.md ## Project Charter` 요약(≤약 25줄) + `docs/project/charter.md`·`conventions.md`(+ 조건부 `glossary.md`). CLAUDE.md는 `@AGENTS.md` thin pointer 유지.
3. 일관성: passive 상속(본질) + 기존 `docs-lint.py` **additive** 확장(C10, 새 hook 0개). v1.5.0이 제거한 canned 주입을 재도입하지 않음(elicited only).

### Implicit context (이 설계가 전제하는 것)
- `docs-lint.py`는 PostToolUse hook으로 `tool_input.file_path`를 받아 `CLAUDE_PROJECT_DIR` 기준 정규화 후 `TARGET_RELPATHS` exact-set membership으로 대상 판정한다(`resolve_target_path()`). charter 확장은 이 함수에 `is_charter_doc()` predicate를 OR로 더하는 형태(C10).
- `/project-init` command는 LLM agent가 실행하는 markdown instruction이며 command-flow 자동 단위 테스트가 없다(기존 Step 1–5와 동일). 따라서 charter step의 검증은 docs-lint 단위 테스트(hook) + manual(command)로 양분된다.
- 기존 4c AGENTS×CLAUDE 4-state matrix와 charter의 C-S1/2/3 matrix는 *독립*이다 — 같은 command run에서 둘 다 평가될 수 있으나 서로 간섭하지 않는다.

### Deferred to plan (구현 단계 결정)
- `is_charter_doc()` predicate의 정확한 구현(`str.startswith` vs `Path` 관계 검사)과 `## Project Charter` heading-bounded 파싱 정규식.
- `## Project Charter` 요약 섹션의 정확한 마크다운 레이아웃(`{{VISION}}`/`{{NON_GOALS}}`/`{{TECH_STACK}}` placeholder 배치, ≤약 25줄 충족 방법).
- Phase 0 manifest 탐지 매트릭스(어느 manifest → 어느 stack 라벨)와 fallback(C6) 트리거 조건의 prose 구체화. (manual 검증이 flaky로 판명되면 deterministic helper 추출 재검토 — C11.)
- glossary 조건부 발행 트리거(어떤 사용자 응답이 "도메인 용어 elicit됨"으로 카운트되는가)의 prose 기준.
- charter fixtures 설계(`charter_complete`, `charter_missing_subsection`, `charter_placeholder_residue`, `charter_docs_mismatch`, `glossary_present`/`glossary_absent`).
- **AC5 `## Personas` 채움 메커니즘** — Phase 1이 personas를 직접 묻지 않으므로(vision·non-goals·conventions·tech-stack만), personas를 vision 응답에서 파생할지 / 선택 질문으로 추가할지 / placeholder 유지할지 결정 (round-2 reviewer rec 3).
- **AC10 bound 검증 절차** — "3회 빈 응답 → abort"를 numbered manual step으로 기술하거나 `smoke.sh`에 stub 응답 시나리오 추가 (round-2 reviewer rec 4).

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
