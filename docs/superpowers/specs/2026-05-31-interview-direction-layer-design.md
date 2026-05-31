---
name: interview-direction-layer
version: 1.0.0
created_at: 2026-05-31
status: design-approved
next_phase: writing-plans
source: superpowers:brainstorming (meta-spec dogfooding)
target_plugin: spec-distill
target_version: 0.12.0
---

# spec-distill interview를 brainstorming 앞단 "문제공간 stage"로 재배치

> *받아적는 인터뷰가 아니라, 시행착오를 미리 겪어 해소하고 외부 근거로 구체화하며 약한 방향을 깨뜨리는 강한 문제공간 stage. 그 산출물(meta-prompt)은 그 자체로 완결되며, superpowers가 있으면 brainstorming 해답공간으로 넘어간다.*

## 목차

- [Handoff Context](#handoff-context)
- [Context / Why](#context--why)
- [Goals](#goals)
- [Non-goals](#non-goals)
- [Constraints](#constraints)
- [Acceptance Criteria](#acceptance-criteria)
- [Architecture & Flow](#architecture--flow)
- [Component Map](#component-map)
- [Interview Stage Internals — 5 통과 의례](#interview-stage-internals--5-통과-의례)
- [Interview Brief Format (meta-prompt)](#interview-brief-format-meta-prompt)
- [Decision Log](#decision-log)
- [Files to Modify](#files-to-modify)
- [Verification Plan](#verification-plan)
- [Rejected Alternatives](#rejected-alternatives)
- [Open Questions](#open-questions)
- [Concrete Next Action](#concrete-next-action)

## Handoff Context

> 이 spec을 처음 보는 사람(또는 /compact 후 자기 자신)이 30초에 핵심 파악할 수 있게. 대화 컨텍스트 가정 금지.

**TL;DR**: spec-distill의 `/interview`를 "spec 생성기"에서 **superpowers brainstorming 앞단의 강한 문제공간(problem-space) stage**로 재배치한다. 인터뷰가 ① 메타 프롬프팅(방향 재구성) ② 웹 외부조사로 리서치 구체화 ③ steelman으로 의심·검증 ④ 시행착오 선(先)해소를 *강하게* 수행하고, 그 결과를 **interview brief(=brainstorming용 meta-prompt)**로 산출한다. brainstorming은 그 위에서 해답공간(architecture/approaches/design doc)을 온전히 설계하고, 그 design doc을 spec-distill의 분리 reviewer가 Law 2로 검증한다. **인터뷰는 단독 완결 stage** — brief가 terminal 산출물이고 brainstorming 호출은 *optional 다음 단계*다(superpowers optional; 없으면 brief + advisory로 완료, fallback spec-mode 경로 없음).

**Implicit context** (Constraints에 안 박힌 외부 사실):
- superpowers는 외부·**수정 불가**·**optional** 플러그인 (`~/.claude/plugins/cache/claude-plugins-official/superpowers/5.1.0/`). 통합은 brainstorming 내부 수정이 아니라 brief 산출 + (있으면) invoke로만. 인터뷰는 brief까지로 단독 완결되므로 superpowers 부재가 인터뷰를 막지 않는다.
- 이건 **Double Diamond**의 두 다이아몬드: interview = 문제공간(diverge→converge on the *right problem*), brainstorming = 해답공간. 둘은 상보적이며 brainstorming은 **단축·스킵되지 않는다**.
- **brainstorming 정지점(OQ1 주 방어선 근거)**: superpowers `brainstorming` SKILL.md "User Review Gate"(step 8)는 design doc 작성·commit 후 *"Wait for the user's response"*로 **명시 정지**한다 — 이 정지가 턴 경계를 만들어 spec-distill Stop hook(`review-dispatch.py`)의 reviewer dispatch를 트리거한다. 즉 reviewer는 brainstorming이 writing-plans로 가기 *전에* 돈다. (가정이 아니라 brainstorming 소스 step 8의 명시 동작.)
- **Hook 인터페이스 계약(소스 확인 + 본 세션 live 관측)**: `spec-write-validator.py`의 `PATH_PREFIX = "docs/superpowers/specs/"` 아래 `.md` write 시 발동, `-design.md`는 design mode로 분류, `.claude/spec-distill/<session>/state.local.md`에 `pending_review:` block을 `{path, mode, worktree_path, triggered_at}` 키로 기록 → Stop hook이 이를 읽어 `reviewing-spec` dispatch를 강제. brainstorming의 `-design.md`에 **이미 이 seam이 걸려 있다** — 이 design doc 자체가 그 hook에 걸려 분리 reviewer 검증을 받았다(live dogfooding 확인).
- 현재 spec-distill 버전 main = 0.11.3.

**Deferred to plan** (이 spec이 의도적으로 lock하지 않은 결정):
- **OQ1–OQ4 전부 해소됨** (Decision Log #9–#11 + 본문 반영). 요약: PreToolUse 게이트 **미구현**(주 방어선만 — brainstorming step 8 정지 + Stop hook, 소스 ground), drafting-spec **완전 제거**(Mode A+B), superpowers **optional**(fallback spec-mode 경로 없음), brief supersession 마커 **불필요**.
- **남은 plan-구현 노트(설계 blocker 아님)**: 워크트리 세션이 main-repo `.claude/spec-distill/<sid>/` state를 Edit/Write-tool로 못 고침(Bash는 가능) — hook write-path(state_path 라우팅) vs tool edit-path 비대칭. 이 design 세션에서 실증. §4.8 worktree-path와 같은 클래스. plan에서 state 갱신 경로 구현 시 고려.

## Context / Why

**누가, 왜.** 사용자(devbrew 운영자)가 요청. 현재 `/interview`는 인터뷰→drafting-spec→reviewing-spec→`spec.md`까지 한 파이프라인으로 **그 자체가 spec 생성기**다. 사용자는 인터뷰를 더 앞으로 당겨, superpowers brainstorming **앞에 놓이는 강한 문제공간 stage**로 재배치하길 원한다.

**무엇이 문제인가.** 현재 인터뷰는 사용자 요청을 *받아적어* spec으로 박제하는 경향이 있다. 세 가지 핵심 capability가 비어 있다:

| 사용자 요청 capability | 현재 상태 |
|---|---|
| ① 방향 도출(메타 프롬프팅·재구성) | △ 4-path Socratic 있으나 judgment(받아적기) 편향 |
| ② 잘못된 방향 교정 / counter-proposal | ✗ steelman은 README에 **명시적으로 defer**됨 (미구현) |
| ③ 외부 사례 웹조사 | ✗ **없음** — factual path는 codebase grep만, 웹 접근 0 |

**무엇이 걸려 있나.** 시행착오를 brainstorming·plan·구현 단계에서 비싸게 겪는 대신, **인터뷰에서 미리(선제적으로) 겪고 해소**해서 넘긴다. 약한 방향이 인터뷰를 그냥 통과하면 이 stage는 실패다 — 그래서 인터뷰 *강도*가 비용이 아니라 목적이다.

**외부 근거(웹 리서치 종합).** RE 문헌은 "gathering(모으기)"과 "eliciting(끌어내기)"을 구분(Wiegers 16 practices, BABOK 5-Whys). Product discovery는 "reframe, reframe, reframe" + "내가 뭘 틀렸는지 능동 청취(confirmation bias 역행)"(Teresa Torres) + Double Diamond 발산/수렴을 강조. 경쟁/​prior-art 분석은 "경쟁 솔루션 = 그들이 이미 거친 discovery의 결과물." 사용자의 세 요청이 각각 이 확립된 프레임워크에 정확히 대응한다.

## Goals

- **G1** — `/interview`를 brainstorming 앞단 문제공간 stage로 재배치: 산출물이 `spec.md`가 아니라 brainstorming이 소비하는 **interview brief(meta-prompt)**.
- **G2** — **메타 프롬프팅**: 받은 요청을 재구성한 한 문장 문제정의 + 진짜 goal을 (d) ontological 5-type으로 도출.
- **G3** — **웹 외부조사 내장**: 토픽 확정 후 landscape sweep 1회(bounded) + steelman/factual on-demand. 모든 외부 주장은 **인용 필수**.
- **G4** — **Adversarial steelman 의심 게이트**: 의심 방향에 대안 steelman을 웹근거와 함께 제시, 사용자 방어/전환/보류 없이는 lock 불가. P17 sovereignty 유지(최종 결정권 항상 유저).
- **G5** — **시행착오 선해소 기록**: 시도→버린 방향을 이유와 함께 박제(brief Tried & Discarded)해 다운스트림 재탐색 차단.
- **G6** — **Law 2 보존**: brainstorming의 `-design.md`를 spec-distill의 frontmatter-scoped reviewer가 검증. drafting-spec **완전 제거**(Mode A+B), reviewing-spec는 **design-mode 전용 단순화**(spec-mode 행 + re-consensus [3.5] 제거), hook 무수정.
- **G7** — **devbrew 원칙 흡수**: 신규 기능 셋을 기존 4-path/rhythm/breadth 구조에 흡수(새 P# 없음). 모든 신규 surface에 cost_class·kill switch·README "Principles Instantiated" 동기화.

## Non-goals

- **NG1** — superpowers brainstorming 내부 수정. 외부·불가침. 통합은 brief 산출 + invoke로만.
- **NG2** — brainstorming의 front 단계(질문/approach) 스킵·단축. brainstorming은 정상 풀가동(상보적, 비중복).
- **NG3** — interview brief에 대한 Law 2 분리 reviewer 추가. brief는 **Law 1 구조 게이트(5 의례)**로 품질 확보, 분리 reviewer는 design doc 전용(역할 분담).
- **NG4** — 새 devbrew P# 신설. 기존 원칙 흡수가 default ([[feedback_devbrew_design_lightness]]).
- **NG5** — 웹조사 무제한 fan-out. bounded(AP9 N≥5 hard 게이트 미만).
- **NG6** — `/interview`의 trivia escape 변경. 그대로 유지.
- **NG7** — 인터뷰가 spec 작성으로의 handoff를 *강제*하는 것. 인터뷰는 brief까지로 **단독 완결** — brainstorming 호출은 optional. superpowers를 required prerequisite로 격상하지 않음(결정 #10).

## Constraints

- **C1** — superpowers 5.1.0 외부 플러그인, 수정 불가, **optional**. brainstorming은 호출되면 자체 clarifying-questions/approaches 흐름을 돈다. superpowers 부재 시 인터뷰는 brief + loud advisory로 완료(fallback spec-mode 경로 없음, graceful degrade — C4 패턴).
- **C2** — devbrew Three Laws + Plugin Shape 전부 준수. Law 2는 frontmatter scoping(프롬프트 아님)으로 물리 분리.
- **C3** — `spec-reviewer.md`/`breadth-keeper.md`/`steelman-builder.md` persona는 **보안-민감 코드**(CLAUDE.md) — 약화 PR은 보안 리뷰 대상.
- **C4** — 웹조사 cost_class **variable**, kill switch 필수, graceful degradation(웹 불가 시 loud log + landscape 생략 명시).
- **C5** — steelman subagent dispatch는 **엄격 순차**(병렬·투기적 금지, AP9 + [[feedback_evidence_before_approved]]).
- **C6** — plugin.json SemVer bump(0.11.3→0.12.0) + CHANGELOG, **같은 PR에서** ([[feedback_plugin_version_bump]]).
- **C7** — 모든 hook은 기존 kill switch(`DEVBREW_DISABLE_SPEC_DISTILL`, `DEVBREW_SKIP_HOOKS=spec-distill:<event>`) 존중.
- **C8** — interview brief는 `docs/superpowers/specs/` **밖**(`docs/superpowers/interview/`)에 둔다. `spec-write-validator.py`의 `PATH_PREFIX = "docs/superpowers/specs/"`(소스 확인)이므로 interview/ 경로는 **자동 제외** — 추가 hook 변경 불필요(review 게이트 경로 밖 보장, NG3).

## Acceptance Criteria

- **AC1** — `/interview` 완주 시 `docs/superpowers/interview/YYYY-MM-DD-<topic>-interview.md`가 생성되고, frontmatter `type: interview-brief` + `next_phase: superpowers:brainstorming` + `locked_directions[]`를 포함한다. (파일 존재 + frontmatter 키 검증)
- **AC2** — interview brief는 7개 본문 섹션(Reframed Problem / Locked Directions / External Landscape / Skepticism Log / Tried & Discarded / Open Questions / Concrete Next Action)을 모두 가진다. 누락 섹션이 있으면 종료 차단. (template 대조 + 종료 게이트 테스트)
- **AC3** — 5개 통과 의례(R1 Reframe, R2 Landscape, R3 Skepticism, R4 시행착오 기록, R5 OQ 박제) 중 하나라도 미충족이면 brief 작성·brainstorming invoke가 차단된다. (각 의례별 미충족 fixture로 종료 차단 검증)
- **AC4** — External Landscape의 모든 항목은 출처 URL을 가진다. URL 없는 외부 주장이 brief에 있으면 종료 게이트 fail. (인용 검증 스크립트)
- **AC5** — 의심 trigger된 방향은 `steelman-builder` 에이전트 dispatch를 거쳐 Skepticism Log에 {대안 steelman 요지, 웹근거 URL, verdict ∈ defended|switched|deferred}로 기록된다. **steelman-builder 출력은 verbatim 보존** — Skepticism Log 항목은 builder가 반환한 대안 statement와 ≥1 인용을 그대로 포함하며 conducting-interview가 약화·편집하지 않는다. un-challenged 의심 방향은 `locked_directions`에 들어갈 수 없다. (steelman fixture 라우팅 + verbatim 보존 테스트)
- **AC6** — `steelman-builder.md` frontmatter는 `disallowedTools`에 `Write, Edit, MultiEdit, NotebookEdit`을 포함한다(물리 분리). (frontmatter grep 테스트)
- **AC7** — 웹조사가 단일 sweep에서 5회 이상 검색을 fan-out하지 않는다(AP9). steelman/factual on-demand는 순차이며 **인터뷰 세션 총량 soft cap ≤8**(초과 시 advisory + 강제 (b) 사용자 질문 — AP16 unbounded 방지). (검증: 웹 도구를 stub한 fixture 1회 실행 시 sweep 내 검색 호출 카운트 ≤4 assert + 세션 on-demand ≤8 assert — `tests/test_web_sweep_bound.sh`. 수동 리뷰 폴백 없음.)
- **AC8** — 웹 비활성(`DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` 또는 도구 부재) 시 인터뷰는 crash하지 않고 landscape 생략을 loud하게 알리며 계속 진행한다(graceful degradation). (kill switch 테스트)
- **AC9** — brainstorming이 `docs/superpowers/specs/...-design.md`를 쓰면 기존 `spec-write-validator` hook이 design mode로 감지해 `pending_review`를 기록하고, reviewer dispatch가 강제된다(Law 2 design-doc 검증 살아있음). (hook 출력 스키마 테스트 — 기존 `test_hook_output_schema.py` 확장)
- **AC10** — `drafting-spec` 스킬이 **완전 제거**(Mode A+B)되고 skills/hooks/commands 경로에서 호출 참조가 사라진다. (`grep -rl 'drafting-spec' plugins/spec-distill/{skills,hooks,commands}` = 0 — tests/ fixture·CHANGELOG 이력 제외)
- **AC11** — `plugin.json` version = `0.12.0`, `CHANGELOG.md`에 `## [0.12.0]` 엔트리 존재(유효 ISO8601 날짜 — merge 날짜와 일치, `XX` placeholder 금지) + Added/Changed/Removed 섹션. (파일 검증 — 날짜는 merge 시점 확정, Deferred 아님)
- **AC12** — README "Principles Instantiated"/"Flow"/"Hooks"/"Kill switches"가 새 흐름과 동기화된다. (자동: `grep`으로 README에 `DEVBREW_SPEC_DISTILL_DISABLE_WEB`·`interview-brief`·`steelman-builder` 키워드 존재 확인 — `tests/test_readme_sync.sh`. + 수동: 산문 정합 리뷰. 완전 수동 의존 아님.)
- **AC13** — superpowers(`brainstorming` skill) 부재 시 `/interview`는 brief를 생성·완료하고 **loud advisory**("brief 완결 — superpowers 설치 시 design 단계로, 아니면 brief 직접 사용")를 낸 뒤 정지한다. crash·spec-mode fallback 시도 없음(단독 완결, graceful degrade). (superpowers-absent fixture 테스트)

## Architecture & Flow

```
/interview <rough request>
  │ (Step 2 trivia escape — 변경 없음)
  ▼
conducting-interview  ── 강한 문제공간 STAGE ──────────────────────┐
  · 4-block Korean Socratic + 4-path routing  (유지)               │
  · R1 Reframe: (d) ontological 5-type로 메타 프롬프트 도출         │
  · R2 Landscape: 토픽 잡히면(round 1–2) web sweep ≤4회, 인용       │  path(a) 확장
  · R3 Skepticism: 의심 방향 → steelman-builder dispatch(순차)      │  (c)build+(b)adjudicate
  ·      → defend / switch / defer 게이트 (P17)                    │
  · R4 시행착오 기록 (steelman switch·방향 폐기의 부산물)            │
  · breadth-keeper / rhythm guard(3) / wall-clock(30min)  (유지)   │
  ▼ 5 의례 모두 통과 (Law 1 구조 게이트)                            │
interview brief 작성 → docs/superpowers/interview/<date>-<topic>-interview.md   ← terminal 산출물(meta-prompt, 단독 완결)
  ▼ (optional 다음 단계 — superpowers 있을 때만; 없으면 brief + loud advisory로 완료)
superpowers:brainstorming  (외부, brief를 rich context로)
  · 정상 풀가동 — 해답공간 설계(architecture/approaches)
  · -design.md 작성 → docs/superpowers/specs/<date>-<topic>-design.md
  ▼ [PostToolUse: spec-write-validator → design mode → pending_review 기록]  (기존 hook)
  ▼ brainstorming "user reviews spec" 게이트에서 정지 → 턴 경계
  ▼ [Stop: review-dispatch → reviewer 강제]  (기존 hook)
reviewing-spec → spec-reviewer agent (Law 2 frontmatter-scoped)  ── design doc 검증
  · approved → writing-plans
  · needs_revise → 메인 agent(brainstorming author 회귀)가 design.md 직접 수정 → 재검증 (Mode B 없음 — design mode)
  ▼
writing-plans
```

핵심: 신규 기능 셋이 **기존 4-path·rhythm·breadth에 흡수**된다. 웹 = path(a) 확장(codebase→codebase|외부 prior-art, 자동조사, 마커 `[from-web]`, streak +1), steelman = (c) subagent build + (b) user adjudicate 하이브리드(마커 `[steelman]`, adjudicate 시 streak reset), 시행착오 = steelman switch **또는** 사용자 직접 폐기의 기록.

**Hook 경계 (component isolation).** 위 PostToolUse/Stop hook은 *무수정*으로 충분하다 — `spec-write-validator.py`의 `PATH_PREFIX`가 이미 `docs/superpowers/specs/`라 brainstorming의 `-design.md`를 design mode로 잡는다(Implicit context의 인터페이스 계약 참조). **변경이 필요한 건 hook이 아니라** 그 design doc을 *읽고 검증하는* `reviewing-spec` 라우팅(design-mode 전용 단순화) + `spec-reviewer` persona뿐. interview brief는 `docs/superpowers/interview/`(PATH_PREFIX 밖)라 hook이 건드리지 않는다(C8 자동 보장).

## Component Map

| 컴포넌트 | 처리 | 비고 |
|---|---|---|
| `commands/interview.md` | **수정** | description/역할: "spec 생성기" → "brainstorming 앞단 문제공간 stage". trivia escape 유지(NG6). |
| `skills/conducting-interview/SKILL.md` | **대수정** | 5 의례 종료 게이트 + path(a) 웹 확장 + steelman 게이트 + brief 작성(terminal) + (superpowers 있으면) brainstorming optional invoke. cost_class medium→**variable**. |
| `agents/steelman-builder.md` | **신규(scoped)** | `allowedTools: Read, Grep, Glob, WebSearch, WebFetch, mcp__*tavily*` / `disallowedTools: Write, Edit, MultiEdit, NotebookEdit`. 독립 skeptic, 대안 steelman 구축. |
| `templates/interview-brief-template.md` | **신규** | meta-prompt 포맷(7 섹션). |
| `skills/drafting-spec/` | **전면 삭제(Mode A+B)** | brief=conducting-interview, design doc=brainstorming, design revise=메인 agent(author 회귀) → drafting-spec 불필요. 디렉토리 제거. rename(OQ2) moot. (결정 #10) |
| `skills/reviewing-spec/SKILL.md` | **design-mode 전용 단순화** | design-mode 라우팅 행만 유지(검증 대상 = brainstorming `-design.md`). **spec-mode 행 + [3.5] re-consensus + mode_b_violation 제거**(drafting-spec/spec-mode 소멸로 dead path). |
| `agents/spec-reviewer.md` | **persona 갱신** | 11-섹션 spec → brainstorming design doc 포맷 검증 추가. 보안-민감(C3). |
| `agents/breadth-keeper.md` | **유지** | tunnel 감지 여전히 유효. |
| `hooks/spec-write-validator.py` 등 | **무수정** | `PATH_PREFIX=docs/superpowers/specs/`(소스 확인)라 design mode 감시 기존재 + interview/ 자동 제외(C8). 추가 조치 불필요. |
| `README.md` / `CHANGELOG.md` / `plugin.json` | **수정** | flow·principles·hooks·kill switches 동기화, 0.12.0 bump(C6). |
| `tests/` | **수정·신규** | Mode A 참조 테스트 갱신 + steelman 라우팅/웹 bound/brief 포맷/5 의례 종료 게이트 신규 테스트. |

## Interview Stage Internals — 5 통과 의례

문제공간 stage가 *강하게* 작동하려면 다음 5 의례를 **모두 통과해야** brief 작성(+ superpowers 있으면 brainstorming invoke)이 허용된다(Law 1 구조 게이트). 하나라도 미충족이면 종료 차단:

| # | 의례 | 통과 기준 | 기존 메커니즘 |
|---|---|---|---|
| R1 | **Reframe (메타 프롬프트)** | 받은 요청을 재구성한 한 문장 문제정의 + 진짜 goal. | (d) ontological 5-type (ESSENCE/ROOT_CAUSE/...) |
| R2 | **Landscape 수집** | web sweep ≥1회, prior-art/대안이 **인용과 함께** 표면화. | path(a) 확장 |
| R3 | **Skepticism 통과** | 의심 triggered 방향이 모두 steelman 후 *방어 또는 전환*. un-challenged 의심 방향 통과 불가. | (c)+(b) 하이브리드 + steelman-builder |
| R4 | **시행착오 기록** | steelman switch된 방향 **또는** 사용자가 명시적으로 폐기한 방향이 *이유와 함께* Tried & Discarded 섹션에 존재. **edge case**: 시행착오 0건이면 섹션에 `N/A — 전부 first-time defend+lock` 명시(빈 섹션 금지). | steelman switch + 사용자 직접 폐기 |
| R5 | **Open Questions 박제** | 미해결 명시("유추 금지"). | 기존 OQ 정책 |

**웹조사(R2 + on-demand)**: 토픽이 잡히면(round 1–2) landscape sweep 1회(≤4 검색, AP9 회피). steelman 근거/factual 판별이 필요할 때 on-demand(1–2/trigger, 순차). 모든 외부 주장 인용 필수(AC4). cost_class variable, kill switch `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`, 웹 불가 시 loud log + landscape 생략(AC8). rhythm guard와 호환 — 웹 auto-research는 streak +1이라, 과도하면 강제로 (b) 사용자 질문(사용자를 loop에 유지).

**Steelman(R3)**: 의심 trigger = landscape 모순 / 알려진 anti-pattern / 기존 LD 불일치 / breadth-keeper tunneling. → `steelman-builder` 에이전트(독립 skeptic, write 불가)가 대안의 강한 케이스를 웹근거와 함께 구축 → 4-block에 반대 케이스로 제시 → **게이트**: 사용자가 (방어→원안 lock + 방어이유 기록) / (전환→대안 lock, 원안은 R4로) / (보류→OQ). 한 방향당 steelman 1회(새 근거 없으면 재steelman 금지 — AP16 harassment 방지). **Law 2 명확화(reviewer 지적 반영, issue f5c2a7e9)**: steelman 게이트는 *Law 2 분리 메커니즘이 아니다* — Law 2 분리 reviewer는 오직 design doc에만 적용된다(결정 #2). steelman은 문제공간 품질을 끌어올리는 *Law 1급 skepticism 의례*다. 다만 conducting-interview가 curate하며 약화시키면 의례가 무력화되므로: **steelman-builder의 출력(대안 statement + 웹근거)은 사용자에게 verbatim 제시**되고 conducting-interview는 이를 편집·약화할 수 없다(AC5 검증). 사용자는 *방향*을 adjudicate하고, steelman의 *품질*은 verbatim pass-through + 구조 최소검증(V3)으로 담보한다.

## Interview Brief Format (meta-prompt)

위치: `docs/superpowers/interview/<YYYY-MM-DD>-<topic>-interview.md` (specs/ 밖, C8/NG3).

```markdown
---
name: <kebab-topic>
type: interview-brief
created_at: YYYY-MM-DD
session_id: <uuid>
source: spec-distill conducting-interview v0.12.0
next_phase: superpowers:brainstorming
locked_directions:              # (b)/(d) 명시 + steelman 통과. brainstorming 기정사실.
  - id: LD1
    statement: "<160자, P21 secret placeholder>"
    source_path: a|b|c|d
    steelman: defended | switched-to-this | n/a
    defense: "<원안 방어 이유, defended인 경우>"
---

# <Topic> — Interview Brief (meta-prompt for brainstorming)

## 1. Reframed Problem      # 메타 프롬프트 코어: 재구성된 한 문장 문제 + 진짜 goal
## 2. Locked Directions     # 확정·검증된 방향(각 LD). 재논쟁 금지.
## 3. External Landscape    # prior-art/경쟁/기존해결 + 출처 URL + [취함/피함/중립] + 이유. 인용 필수.
## 4. Skepticism Log        # 의심 방향별: 대안 steelman 요지 + 웹근거 + verdict.
## 5. Tried & Discarded     # 시행착오: 시도→버린 이유. 다운스트림 재탐색 차단.
## 6. Open Questions        # 해답공간으로 이월. "유추 금지".
## 7. Concrete Next Action  # (optional) superpowers 있으면 brainstorming 호출(이 brief가 context) → -design.md → reviewer → writing-plans. 없으면 이 brief가 완결 산출물.
```

§1~2 = 재구성된 문제공간(meta-prompt 코어), §3~5 = 해소된 탐색(landscape+의심+시행착오), §6 = 미해결 이월, §7 = 다음 액션.

**`session_id` 생성 주체**: conducting-interview가 기존 spec-distill session(`state_path` 라우팅으로 main repo `.claude/spec-distill/<sid>/`에 anchor된 것)을 재사용한다 — brief가 새 session을 만들지 않음. (plan은 이 owner를 Component Map대로 구현.)

## Decision Log

brainstorming 인터뷰 라운드 + post-review OQ 해소에서 확정된 11개 결정(이 design의 locked directions):

1. **레이어 위치** = superpowers brainstorming **앞단**(상보적, 비중복).
2. **Law 2 위치** = brainstorming의 `-design.md`를 spec-distill reviewer가 검증(drafting-spec **완전 제거**, reviewing-spec **design-mode 전용 단순화**).
3. **반례 강도** = **Adversarial steelman** (defend/override 게이트, P17 유지).
4. **웹조사** = **Landscape sweep**(round 1–2) + steelman/factual on-demand, bounded.
5. **Handoff** = **Approach A** — interview brief가 **단독 완결 terminal 산출물**. superpowers 있으면 brief를 context로 brainstorming 호출(optional 다음 단계), 없으면 brief + advisory로 완료.
6. **목적 framing** = 강한 문제공간 stage(Double Diamond 1st diamond) — brainstorming 단축 아님. 메타 프롬프팅 + 리서치 구체화 + 시행착오 선해소 + 의심.
7. **네이밍** = "interview" (브리프/폴더/stage 명칭; `discovery` 폐기).
8. **steelman 에이전트** = 전용 scoped `steelman-builder` 신설(general-purpose 재사용 아님).
9. **OQ1 해소** = PreToolUse 보강 게이트 **미구현**. 주 방어선(brainstorming step 8 user-review 정지 → Stop hook, 소스 ground)만으로 Law 2 보존.
10. **OQ2+3 해소** = drafting-spec **완전 제거**(Mode A+B), superpowers **optional**, no-superpowers fallback 없음. 인터뷰는 brief까지 단독 완결(brief=terminal). rename(OQ2)·deprecation window(OQ3) moot.
11. **OQ4 해소** = brief에 superseded LD 마커 **불필요**(Tried & Discarded로 방향변경 이력 충분).

## Files to Modify

```
plugins/spec-distill/.claude-plugin/plugin.json        # version 0.11.3 → 0.12.0
plugins/spec-distill/CHANGELOG.md                      # ## [0.12.0] Added/Changed/Removed
plugins/spec-distill/commands/interview.md             # 역할 reframe(문제공간 stage), description
plugins/spec-distill/skills/conducting-interview/SKILL.md  # 5 의례 + 웹 path(a) + steelman 게이트 + brief 작성 + invoke; cost_class variable
plugins/spec-distill/agents/steelman-builder.md        # 신규 scoped 에이전트
plugins/spec-distill/templates/interview-brief-template.md  # 신규 meta-prompt 템플릿
plugins/spec-distill/skills/drafting-spec/             # 디렉토리 전면 삭제 (Mode A+B)
plugins/spec-distill/skills/reviewing-spec/SKILL.md    # design-mode 전용 단순화 (spec-mode 행+re-consensus+mode_b_violation 제거)
plugins/spec-distill/agents/spec-reviewer.md           # design doc 포맷 검증 persona(보안-민감)
plugins/spec-distill/README.md                         # flow/principles/hooks/kill switches 동기화
plugins/spec-distill/hooks/spec-write-validator.py     # 무수정 검증 (PATH_PREFIX 자동 제외) — 변경 없음, 진입점 참고
plugins/spec-distill/tests/                            # drafting-spec/spec-mode 참조 테스트 제거·갱신 + 신규(steelman/웹/brief/5의례/superpowers-absent)
```

## Verification Plan

- **V1** — brief 생성 + frontmatter 검증: 통과 fixture로 `/interview` 종료 시 `docs/superpowers/interview/*-interview.md` 생성 + `type`/`next_phase`/`locked_directions` 키 확인. (`tests/test_interview_brief_*.sh` 신규)
- **V2** — 5 의례 종료 게이트: 각 의례 미충족 fixture(landscape 없음/un-challenged 의심/OQ 미박제 등)로 종료 차단 검증. **R4 edge fixture 포함**: 시행착오 0건일 때 Tried & Discarded에 `N/A — 전부 first-time defend+lock`이 없으면 종료 차단.
- **V3** — steelman 라우팅: 의심 fixture가 `steelman-builder` dispatch + Skepticism Log verdict 기록을 거치는지. un-challenged 방향이 locked_directions에 들어가면 fail. **구조 최소검증**: Skepticism Log 각 항목이 (대안 statement 비어있지 않음 AND ≥1 URL 인용 포함) — 빈/형식적 steelman 차단(약하지만 mechanical, 품질은 V10이 보완).
- **V4** — `steelman-builder.md` frontmatter `disallowedTools` grep으로 Write/Edit/MultiEdit/NotebookEdit 차단 확인. (`tests/test_steelman_builder_scope.sh`)
- **V5** — 웹 bound + kill switch: sweep ≤4 호출 규약 검증 + `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` 시 graceful degradation(loud log, no crash).
- **V6** — 인용 강제: External Landscape 항목에 URL 없으면 종료 게이트 fail. (`tests/test_landscape_citation.sh`)
- **V7** — Law 2 design-doc 검증 생존: brainstorming `-design.md` write 시 hook `pending_review` 기록 + reviewer dispatch. (`tests/test_hook_output_schema.py` 확장)
- **V8** — drafting-spec 전면 삭제: `grep -rl 'drafting-spec' plugins/spec-distill/{skills,hooks,commands}` = 0 (AC10) + 디렉토리 부재. reviewing-spec에 spec-mode 행/re-consensus 잔존 없음 확인.
- **V9** — 회귀: 기존 spec-distill 테스트 baseline 캡처 후 신규 변경이 통과 테스트를 깨지 않는지(레포 root에서 실행, [[project_qg_pre_existing_test_reds]] 따라 사전 baseline). `bash plugins/spec-distill/tests/*.sh`.
- **V10** — 수동 e2e: 실제 `/interview` 1회 — 웹 sweep·steelman·brief 생성·brainstorming invoke·reviewer 검증까지 흐름 확인. **체크리스트 항목 명시**: steelman이 *실제 반례 논거*를 담는지(빈/형식적 아님) — V3 구조검증이 못 잡는 품질 공백(G4 직결) 보완.

## Rejected Alternatives

- **R1 — 기존 인터뷰 in-place 강화(spec-distill 자체 완결)**: 인터뷰를 강화하되 산출물은 여전히 drafting-spec→reviewing-spec로. → 사용자가 명시적으로 brainstorming 앞단 재배치를 선택(결정 #1).
- **R2 — discovery↔spec 디커플(범용 brief)**: 인터뷰를 어느 consumer든 먹을 수 있는 범용 brief로 분리. → 사용자가 superpowers brainstorming 특정 타깃을 선택.
- **R3 — Law 2 완전 위임(brainstorming self-review에 의존)**: drafting+reviewing 전부 retire하고 brainstorming의 same-agent "spec self-review"에 검증을 맡김. → brainstorming self-review는 쓴 에이전트가 자기 글을 보는 것이라 devbrew **AP1 self-approval**이자 Law 2 위반. 외부 plugin이라 분리 reviewer 주입도 불가. **대비 트레이드오프(NG3 정당화)**: 본 설계는 design doc은 Law 2 분리 reviewer로, interview brief는 분리 reviewer 없이 **Law 1 구조 게이트(5 통과 의례)**로 검증하는 의도적 비대칭을 택한다 — brief는 brainstorming이 곧바로 재가공하는 *중간 산출물*이라 brief 단계 separated review의 한계효용이 낮고, 진짜 spec(design doc)에 Law 2를 집중하는 게 비용 대비 효과적. brief 품질 공백은 5 의례 + 종료 게이트가 감당(감수한 위험). 거절(결정 #2).
- **R4 — Handoff B(tight auto-chain, 단계 억제)**: brainstorming 내부 흐름을 강제 조작. → 외부 skill 불가침(C1)·fragile. 거절(결정 #5).
- **R5 — Handoff C(design-seed 선기록)**: 인터뷰가 design doc 초안을 직접 씀. → 인터뷰가 spec-writer로 복귀, Law 2 writer 정체성 흐림. 거절(결정 #5).
- **R6 — Advisory counter-proposal(약한 제안)**: steelman 대신 추천답만. → 약한 방향이 그냥 통과할 위험. 사용자가 강한 steelman 선택(결정 #3).
- **R7 — 매 round 웹 보강**: 매 라운드 웹조사. → AP9/P22/AP16 위험 + 인터뷰 속도 저하. 거절(결정 #4).
- **R8 — steelman을 general-purpose 재사용**: 전용 에이전트 대신 범용. → "scoped agents, default-everything 금지"(Plugin Shape) 약화. 사용자가 전용 신설 선택(결정 #8).
- **R9 — superpowers를 required prerequisite로 격상**: 인터뷰가 항상 brainstorming으로 넘어가도록 강제(brainstorm 위임). → 인터뷰는 brief까지로 **단독 완결**이라 handoff 강제 불필요(NG7). superpowers 없으면 brief + advisory로 graceful degrade. 거절(결정 #10).

## Open Questions

**OQ1–OQ4 전부 해소됨** (Decision Log #9–#11):
- **OQ1**(PreToolUse 게이트) → **미구현**, 주 방어선만(brainstorming step 8 정지 + Stop hook, 소스 ground).
- **OQ2**(drafting-spec rename) → **moot**, drafting-spec 전면 삭제.
- **OQ3**(Mode A deprecation window) → **moot**, 전면 삭제(pre-1.0, loud CHANGELOG Removed로 충분).
- **OQ4**(brief supersession 마커) → **불필요**, Tried & Discarded로 방향변경 이력 충분.

**남은 plan-구현 노트(설계 blocker 아님)**:
- **PN1** — 워크트리 세션이 main-repo `.claude/spec-distill/<sid>/` state를 Edit/Write-tool로 못 고침(Bash는 가능). hook write-path(state_path 라우팅) vs tool edit-path 비대칭 — 이 design 세션에서 실증. §4.8 worktree-path와 같은 클래스. plan에서 state 갱신 경로 구현 시 고려.
- **PN2** — V8의 "reviewing-spec spec-mode/re-consensus 잔존 없음 확인"에 검증 스크립트 경로(예: `tests/test_reviewing_spec_design_only.sh`)를 plan에서 명시(V1–V7 수준 자동화 통일). (round-4 reviewer advisory)
- **PN3** — AC7 "세션 총량 soft cap ≤8"의 계측 단위(state 파일 카운터 vs 메모리 내 누적)를 conducting-interview 구현 시 plan에서 명시(모호성 방지). (round-4 reviewer advisory)
- **PN4** — AC5 verbatim 보존 테스트의 diff 기준(exact string match vs 핵심 URL·statement 포함)을 plan에서 세분화(flakiness 방지). (round-4 reviewer advisory)

## Concrete Next Action

다음 단계: superpowers `writing-plans` skill 호출(brainstorming 종료 상태).
- Spec(이 design doc) 경로: `docs/superpowers/specs/2026-05-31-interview-direction-layer-design.md`
- Plan 산출물: `docs/superpowers/plans/2026-05-31-interview-direction-layer-plan.md`
- 명령: writing-plans skill invoke (이 design doc을 input으로). OQ1–OQ4 해소 완료 — plan은 Component Map 순서[steelman-builder + template → conducting-interview(5의례+웹 path(a)+steelman 게이트+brief 작성+optional invoke) → **drafting-spec 디렉토리 삭제** + reviewing-spec design-mode 단순화 → reviewer persona → README/version/tests]로 TDD 분해. PN1(워크트리 state 경로) 고려.
