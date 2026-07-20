---
name: spec-distill-interview-coverage-driven
version: 1.0.0
created_at: 2026-07-20
session_id: acd7a521-8c8a-47a7-b83c-357fdd2cdde8
status: locked
next_phase: writing-plans
source: spec-distill v0.21.0
# Locked decisions — interview LD1–LD5 (b/d path 명시 응답) + brainstorming BD1–BD3.
locked_decisions:
  - id: LD1
    section: "#goals"
    summary: "커버리지-구동 하이브리드 — 결정론은 floor 커버리지 계약만 강제, probe는 CTA 툴킷서 적응 선택, 라운드 카운터 제거"
    source: interview-round-1
  - id: LD2
    section: "#acceptance-criteria"
    summary: "teach/reveal = cross-cutting teach-beat + 전용 blind-spot/premortem 슬롯 1개(적대적 subagent+웹)"
    source: interview-round-2
  - id: LD3
    section: "#constraints"
    summary: "집요함 = 신호 기반 깊이 + 커버리지 계약(길이 아님), teach-beat 조건부 발화로 fatigue 회피"
    source: interview-round-3
  - id: LD4
    section: "#goals"
    summary: "커버리지 계약 = 고정 floor 5개 + 주제-도출 차원(인터뷰가 스스로 도출하고 근거를 brief에 기록)"
    source: interview-round-4
  - id: LD5
    section: "#non-goals"
    summary: "재구성 범위 = 중간(SKILL 프로즈 + check_brief + 상태 스키마). agent-이월 조항은 brainstorming서 사용자가 해제"
    source: interview-round-5
  - id: BD1
    section: "#files-to-modify"
    summary: "blind-spot floor 차원은 신규 blind-spot-prober 에이전트(적대적 premortem, read-only, fan-out 1)로 구현"
    source: brainstorming-round-1
  - id: BD2
    section: "#acceptance-criteria"
    summary: "teach-beat = 모든 probe 한 줄 teach-lite + 열거 신호 시 evidence-heavy(landscape 모순/hold 답/floor 첫 개방/subagent 표면화)"
    source: brainstorming-round-1
  - id: BD3
    section: "#files-to-modify"
    summary: "breadth-keeper를 coverage-mapper로 재목적화(출력 = derived_dimensions[] + neglect_flag). LD5 agent-이월 사용자 해제"
    source: brainstorming-round-1
---

# spec-distill 인터뷰 커버리지-구동 재구성

## Goal

`conducting-interview`의 종료 driver를 고정 라운드 카운터에서 미지-차원 커버리지 원장으로 바꿔, 집요함·깊이·차원이 주제에 적응하도록 재구성한다(브라우저-검증 아님 — 구조/게이트 변경).

## Handoff Context

**TL;DR** (무엇을·왜):
- spec-distill 인터뷰가 주제와 무관하게 같은 5개 라운드 박스를 밟아 "기계적"이고, 사용자가 모르는 주제-특수 미지를 열 자리가 없다. 근본원인은 집요함·깊이·차원이 전부 `interview_round` 카운터에 묶인 것 — 이를 "반드시 열려야 할 최소 미지 차원(floor) + 주제-도출 차원" 커버리지 계약으로 옮기고, probe 선택은 CTA 툴킷에서 모델이 적응적으로 한다.
- 산출물은 여전히 interview brief. 이 재구성은 인터뷰 stage(문제공간)만 바꾸며 design-doc 리뷰(Phase 2)·훅은 건드리지 않는다.

**Implicit context** (Constraints에 안 박힌, 작업 진행에 필요한 외부 사실):
- 인터뷰 stage는 자기 라운드를 모는 훅이 없다 — 라운드는 SKILL.md 프로즈 + `state.local.md`가 몬다. 그래서 커버리지 재구성은 훅을 강제 변경하지 않는다.
- `rhythm-guard`는 에이전트가 아니라 SKILL 안 `non_user_streak` 카운터다. 실제 에이전트 파일은 `breadth-keeper`, `steelman-builder` 둘뿐 — 후자의 `description:` 문자열에도 "breadth-keeper tunneling"이 박혀 있어 rename 시 terminology 동기화 대상(§files-to-modify).
- 현행 코드에서 `interview_round`를 참조하는 지점은 두 곳뿐 — 상태 스키마 필드 선언(SKILL.md 상태 frontmatter)과 breadth-keeper C45 dispatch 트리거(`interview_round >= 2` + "직전 3 round 같은 dimension"). 두 곳 모두 이 재구성의 갱신 대상이다(하나라도 빠지면 stale 참조).
- `check_brief.py`는 brief 파일만 읽는다 — `state.local.md`를 읽지 않는다. 따라서 "floor 전부 closed"를 게이트로 집행하려면 커버리지 원장이 brief에 직렬화돼 있어야 한다(아래 C9·AC2).
- `web_budget.py`(increment/check/reset-sweep)가 세션 web 예산의 기계적 집행 선례다 — probe 백스톱도 같은 패턴(`probe_budget.py`)으로 집행한다(프로즈 self-tracking 아님).
- devbrew 금지 패턴 "Unbounded autonomy" — 카운터를 종료 driver에서 떼면 max-iter 백스톱을 반드시 유지하며, 그 백스톱은 기계적으로 계산·집행돼야 한다.

**Deferred to plan** (이 spec이 의도적으로 lock하지 않은 결정):
- 없음 — 아래 "Locked in this doc" 항목이 이전 open question(probe cap·트리거 임계·섹션 배치)을 모두 확정했다. planning은 확정값의 튜닝과 기계적 구현만 담당.

**Locked in this doc (planning은 튜닝만, 재설계 금지):**
- **probe 정의**: 사용자에게 질문을 제기하고 답을 받는 단일 (b)/(d)-path 교환 1회. `probe_count`는 질문 제기 시 +1. (a) auto-research·teach-beat·subagent dispatch·web search는 probe가 아님(probe_count 미증가). "focused 차원" = 그 probe가 겨눈 커버리지 차원; 진전은 사용자 답변 후 원장에 기록. 이 정의가 probe_count·cap·C11 무진전 창·rhythm-guard·AC8 "모든 probe"를 결정한다.
- 커버리지 status = 3-state 열거 `open` / `in-progress` / `closed`(C9·AC2). 종료는 floor 전부 `closed`.
- probe cap 기본값 12 + env `DEVBREW_SPEC_DISTILL_PROBE_CAP`, `probe_budget.py`가 집행(C10).
- coverage-mapper dispatch 트리거: "한 focused 차원이 연속 3 probe 진전 없음 OR floor 차원 첫 open→in-progress 전이"(C11).
- 커버리지 원장은 brief `## Coverage Ledger` 단일 섹션에 직렬화(floor+derived 통합), orchestrator가 소유(C9). 별도 Derived Coverage 섹션은 두지 않는다.
- brief 템플릿 최종 섹션 순서(AC10): 1 Reframed Problem / 2 Locked Directions / 3 External Landscape / 4 Skepticism Log / 5 Blind Spots & Premortem / 6 Coverage Ledger / 7 Tried & Discarded / 8 Open Questions / 9 Concrete Next Action.

## Context / Why

사용자가 `/spec-distill:interview`로 인터뷰 메커니즘 자체를 강화 요청했다: "더 집요하게, 사용자가 모르는 미지를 드러내 가르치고, 외부 탐색을 더 적극적으로, 라운드 기반을 유연한 아키텍처로." 인터뷰 stage에서 이를 재구성했고(brief: `docs/superpowers/interview/2026-07-20-spec-distill-interview-strengthening-interview.md`), 재구성한 문제정의는:

> 진짜 문제는 "인터뷰가 덜 집요하다"가 아니라 인터뷰의 집요함·깊이·차원이 전부 고정 라운드 체크리스트에 묶여 있다는 것이다(ROOT_CAUSE). 이 단일 근본원인이 세 증상을 동시에 낳는다 — (1) 같은 박스를 밟아 기계적, (2) 주제-특수 미지를 열 자리 없음, (3) 외부 탐색이 라운드 종속.

숨은 가정 반증(HIDDEN_ASSUMPTIONS): "더 집요 + 더 유연"은 현재 결정론 라운드 구조에서 서로 당긴다. 해소는 집요함의 구현체를 "라운드 수 → 커버리지 계약"으로 옮기기다. 지금 하는 이유: 인터뷰 stage는 spec-distill 전체 파이프라인의 입구라, 여기서 미지를 놓치면 하류(brainstorming/plan/구현) 전체가 잘못된 전제 위에 선다.

## Goals

- **G1**: 종료 driver를 `interview_round`(int)에서 커버리지 원장(floor 5차원 + 주제-도출 차원, 각 status ∈ {open, in-progress, closed} + evidence)으로 교체한다. 원장은 `state.local.md`에 저장되고 brief `## Coverage Ledger`에 직렬화된다. 종료는 floor 전부 `closed`. (LD1)
- **G2**: 커버리지 계약 = 고정 보편 floor(root-problem / landscape / skepticism / blind-spot / open-questions)만 결정론 강제 + 그 위 주제-도출 차원. 주제-도출 차원의 authority는 orchestrator(인터뷰 스킬)에 있고, coverage-mapper는 후보를 *제안*할 뿐이다. (LD4)
- **G3**: 집요함을 인터뷰 길이가 아니라 "floor 미충족 시 종료 불가"로 구현하되, `probe_budget.py`가 집행하는 `probe_count` 백스톱으로 bounded. (LD3)
- **G4**: teach/reveal-unknown을 cross-cutting teach-beat(질문 형태, 단정 금지) + 전용 blind-spot floor 차원으로 구현. (LD2)
- **G5**: probe의 종류·순서·깊이를 모델이 CTA 툴킷(CDM 반복 pass / ACTA knowledge-audit·simulation)에서 신호 기반 적응 선택하게 한다. 고정 라운드 순서 없음. (LD1)

## Non-goals

- **NG1**: 훅(`review-dispatch`, `session-end-cleanup`, `spec-write-validator`, `pending-review-reminder`, `state_path`) 변경 — 이월이 아니라 커버리지 모델이 훅을 건드리지 않기 때문. (LD5)
- **NG2**: `reviewing-spec` Phase 2(design-doc Law 2 리뷰) 변경 — 인터뷰 stage 무관.
- **NG3**: `steelman-builder` 에이전트의 로직·persona·트리거 조건 변경 — SKILL.md 5-통과-의례의 Skepticism 게이트(이 문서 §Rejected Alternatives R3와 무관)는 floor에 그대로 유지. **예외**: `description:` 문자열의 "breadth-keeper" 용어를 "coverage-mapper"로 바꾸는 terminology-only 편집은 rename 정합을 위해 허용(behavior 무변경 — persona 약화 아님).
- **NG4**: 인터뷰 brief가 spec.md로 바뀌는 것 — brief는 단독 완결 terminal 산출물로 유지(SKILL의 NG7 handoff-optional 계약 불변 — 이 문서 자체 non-goal 번호와 무관).
- **NG5**: web budget cap(sweep 4 / session 8) 상향 — 외부 탐색 적극화는 라운드-비종속 재배치로 달성하지 cap 완화로 하지 않는다.
- **NG6**: `check_brief.py`가 커버리지의 *의미적* 정합(floor가 진짜로 닫혔나)을 판정하는 것 — 게이트는 form·존재만 본다(C2). 의미는 orchestrator + 독립 adversary가 담보.

## Constraints

- **C1**: Unbounded-autonomy 금지 — `probe_count` soft cap 도달 & floor 미충족 시 사용자-override escalation을 발화해야 한다. cap은 `probe_budget.py`가 기계적으로 계산·집행한다(C10) — 프로즈 self-tracking 금지. 세 선택의 종료 의미론: **(계속)** `probe_budget.py raise-cap`이 `probe_cap_override`를 base cap(12)만큼 올려 effective_cap = base + override로 상향(state persist) 후 진행; **(박제 후 종료)** 미충족 floor 행을 `status: closed` + evidence `사용자-승인 박제(@probe N) — §Open Questions 참조`로 기록하고 그 내용을 §Open Questions로 이동 → AC2 게이트 통과(floor closed)하되 박제 표식이 원장에 가시적(C2가 인정한 orchestrator-writes-closed의 명시적·사용자승인 사례, silent bypass 아님); **(abort)** brief 미작성, state 보존.
- **C2**: 결정론은 floor의 *형식·존재*에만 — `check_brief.py`는 의미적 커버리지를 판정하지 않는다(게이트는 자기 regex 밖을 못 봄). 단, brief에 직렬화된 원장 덕에 게이트는 "floor 5행 존재 + 각 status `closed` + evidence 비어있지 않음"을 form 수준에서 집행한다. orchestrator가 substance 없이 `closed`를 쓸 수 있다는 한계는 남으며(그 판정은 모델 + 독립 adversary인 coverage-mapper·blind-spot-prober가 담보), 게이트는 그 남은 한계를 숨기지 않는다. (harness-lightness)
- **C3**: teach-beat는 prior-art/trade-off를 **단정 아닌 질문 형태**로 제시해 편향-주입을 회피한다(공유된 전제가 사용자 답을 오염시키지 않게).
- **C4**: 상태 스키마 마이그레이션은 non-mutating read promote(기존 `SKILL.md`의 `## In-flight state migration` 섹션과 동일 패턴) — 구세션 로드 시 in-memory default로 승격하고 다음 명시적 write 시점에만 frontmatter 갱신(backward-rewrite 금지).
- **C5**: web 부재(`DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` 또는 도구 부재) 시 blind-spot은 inline premortem으로 loud 강등 — SKILL.md 5-통과-의례의 Landscape/Skepticism 게이트 web-absent 강등과 대칭(이 문서 §Rejected Alternatives R2/R3와 무관), opaque gate-fail 금지(graceful degradation).
- **C6**: 신규/변경 에이전트는 `tools:` allowlist frontmatter로 fail-closed(Write/Edit 물리 부재) — Law 2 read-only 불변.
- **C7**: 이 플러그인을 건드리는 PR이므로 같은 커밋에서 `plugin.json` 0.21.0 → 0.22.0(minor: 새 surface) + CHANGELOG `[0.22.0]` 동기화.
- **C8**: blind-spot-prober는 fan-out 1(인터뷰당 1회 dispatch) — devbrew N≥5 hard review 게이트 미해당.
- **C9**: **원장 ownership + 직렬화 스키마.** 커버리지 status 전이(open→in-progress→closed)와 evidence 기록은 orchestrator(인터뷰 스킬)만 수행하고, `state.local.md`에 쓰는 동시에 brief `## Coverage Ledger`에 직렬화한다. coverage-mapper·blind-spot-prober는 read-only *제안자*이지 상태 writer가 아니다(Law 2). 스키마:

  ```yaml
  # state.local.md — coverage 객체
  coverage:
    floor:
      root_problem:   {status: open|in-progress|closed, evidence: "<probe-ref 또는 brief 섹션 앵커>"}
      landscape:      {status: open|in-progress|closed, evidence: "..."}
      skepticism:     {status: open|in-progress|closed, evidence: "..."}
      blind_spot:     {status: open|in-progress|closed, evidence: "..."}
      open_questions: {status: open|in-progress|closed, evidence: "..."}
    derived:
      - {name: "<주제-특수 차원>", rationale: "<이 주제가 이 차원을 요구하는 이유>", status: open|in-progress|closed, evidence: "..."}
  orchestration:                              # C11/C8 across-resumption 상태 (orchestrator 소유, agent read-only)
    focused_dimension: "<현재 probe 대상 차원 이름 또는 null>"
    no_progress_streak: <int, 기본 0>          # C11 연속 무진전 probe 수; focused 변경·진전 시 0 reset
    blind_spot_dispatched: <bool, 기본 false>  # C8 인터뷰당 1회 보장; 첫 dispatch 시 true
    coverage_mapper_last_probe: <int 또는 null>
  probe_count: <int, 0 이상>
  probe_cap_override: <int, 0 이상, 기본 0>    # C1 '계속'이 base cap만큼 raise (probe_budget.py raise-cap)
  ```

  brief `## Coverage Ledger` 행 문법(state→brief 직렬화, 한 줄당 한 차원):

  ```
  - floor:root_problem — closed — <evidence>
  - floor:landscape — closed — <evidence>
  - floor:skepticism — closed — <evidence>
  - floor:blind_spot — closed — <evidence>
  - floor:open_questions — closed — <evidence>
  - derived:<name> — closed — <rationale>; <evidence>
  ```

  derived 0건이면 sentinel 한 줄 `- derived: N/A — floor로 충분`. `check_brief`는 floor 5행 각 존재 + status 토큰 `closed` + evidence 세그먼트 non-empty + derived(≥1행 OR sentinel)를 검사한다. `orchestration` 필드도 orchestrator만 갱신하며(agent read-only) brief에는 직렬화하지 않는다(state 전용); reset 규칙은 스키마 주석대로(no_progress_streak: focused 변경·진전 시 0, blind_spot_dispatched: 첫 dispatch 시 true), migration 기본값은 AC5.
- **C10**: **probe 백스톱 집행.** `probe_budget.py`(scripts/, `web_budget.py` sibling) CLI 계약:

  ```
  probe_budget.py increment <state.local.md>  → probe_count += 1; exit 0 (≤effective_cap) | 1 (>)
  probe_budget.py check <state.local.md>      → exit 0 (≤effective_cap) | 1 (>); stdout: remaining
  probe_budget.py raise-cap <state.local.md>  → probe_cap_override += base_cap; persist; exit 0
  base_cap = int(env DEVBREW_SPEC_DISTILL_PROBE_CAP) if set else 12
  effective_cap = base_cap + probe_cap_override
  ```

  SKILL은 매 probe 전 `increment`를 호출하고 non-zero exit 시 C1 escalation을 발화한다. C1 '계속' 선택은 `raise-cap`으로 effective_cap을 base만큼 올린다.
- **C11**: **coverage-mapper dispatch 트리거** = "한 focused 차원이 연속 3 probe 동안 status·evidence 무변경(진전 없음) OR floor 차원의 첫 open→in-progress 전이." 진전 = status 전이(open→in-progress→closed) 또는 evidence append. 연속 카운터는 focused 차원이 바뀌거나 진전 발생 시 reset. 기존 `interview_round >= 2` 트리거를 이 커버리지 조건으로 교체한다(라운드 참조 잔존 금지).
- **C12**: teach-beat *발화 시점*은 모델 판단 적응 행동이다(LD1/G5 harness-lightness) — 결정론 게이트로 기계화하지 않는다. AC8 신호는 결정 규칙이 아니라 모델 휴리스틱 가이드이며, 검증 가능한 것은 SKILL의 신호 열거 + 크기 한도(teach-lite ≤1문장 / teach-heavy ≥1 URL)뿐이다. per-firing 결정성은 non-goal(모델 판단을 결정론으로 대체하지 않음 — 이 재구성의 핵심 논지). 이 문서 C12는 자기-참조이며 SKILL.md의 C-넘버링과 무관.

## Acceptance Criteria

- **AC1**: `state.local.md` 스키마에서 **오직** `interview_round`만 제거되고 `coverage`(floor 5 + derived[]) + `probe_count` + `probe_cap_override` + `orchestration`(focused_dimension/no_progress_streak/blind_spot_dispatched/coverage_mapper_last_probe)가 추가된다. 기존 필드 `non_user_streak`·`web_sweep_count`·`web_search_count`·`rereview_count`·`trivia_escape_armed`·`issue_history`·`pending_locked_decisions`는 전부 **유지**(삭제 금지 — 이 목록은 non-exhaustive 유지 선언).
- **AC2**: 종료 게이트 = (a) orchestrator가 floor 5차원 전부 status `closed`임을 `state.local.md`에서 확인하고 brief `## Coverage Ledger`에 직렬화, AND (b) `check_brief.py gate`가 brief의 `## Coverage Ledger`에서 floor 5행 존재 + 각 `closed` + evidence 비어있지 않음 + derived(≥1행 OR sentinel)를 검증해 exit 0. floor 한 행이라도 `open`/`in-progress`/evidence-공백이면 exit ≠ 0.
- **AC3**: `check_brief.py`가 (a) `## Coverage Ledger`의 floor 5행 all-`closed` + evidence non-empty + derived 존재/sentinel, (b) `## Blind Spots & Premortem` 섹션 존재를 검증하고 미충족 시 exit ≠ 0.
- **AC4**: `probe_budget.py increment`가 `probe_count`를 전진시키고 cap(기본 12) 초과 시 non-zero exit. SKILL은 non-zero exit & floor 미충족 시 `AskUserQuestion` 3옵션 escalation을 발화하고, 각 옵션의 종료 의미론(계속=effective cap 상향 / 박제=floor 행 `closed`+박제 표식 후 §Open Questions 이동 / abort=brief 미작성·state 보존)은 C1대로 처리한다.
- **AC5**: 구세션(`interview_round` 존재 / `coverage` 부재) 로드 시 floor 전부 status `open`으로 seed + `probe_count`·`probe_cap_override`·`orchestration`(focused_dimension=null, no_progress_streak=0, blind_spot_dispatched=false, coverage_mapper_last_probe=null) 전부 **fresh 초기화**(probe_count=0 — interview_round 값 승계 금지, 라운드 수는 probe 수가 아님) + advisory 한 줄(`[spec-distill v0.22.0] state schema migration: coverage/probe_count added`) 출력, frontmatter는 backward-rewrite하지 않는다.
- **AC6**: 신규 `agents/blind-spot-prober.md`가 `tools: Read, Grep, Glob, WebSearch, WebFetch`(Write/Edit 부재) frontmatter + 명시적 Output YAML 스키마(`hidden_assumptions[]{assumption, why_risky, evidence[]}`, `failure_modes[]{mode, trigger, evidence[]}`, `confidence`)를 갖고, blind_spot floor 차원의 첫 open→in-progress 전이 시(그 차원에 첫 probe 착수 — C11·AC8 신호#3과 동일 정밀도) 인터뷰당 1회 dispatch된다. 출력은 orchestrator가 brief `## Blind Spots & Premortem`에 기록.
- **AC7**: `breadth-keeper`가 `coverage-mapper`로 전환 — Output 스키마가 `derived_dimensions: [{name, rationale}]` + `neglect_flag` + `neglected_dimensions[]` + `confidence`. read-only frontmatter 유지. 출력은 **advisory**(orchestrator가 원장 admit 판정, G2). 복수 dispatch 시 name 기준 union·dedup. 재명명이 README/dispatch/테스트 + `steelman-builder.md` description 용어(NG3 예외) 전반에 반영. C45 dispatch 트리거(SKILL.md의 `interview_round >= 2`)가 C11 커버리지 조건으로 교체.
- **AC8**: teach-beat = 모든 probe에 teach-lite(**≤1문장 근거, web 호출 없음**) + 열거 신호 시 evidence-heavy(**≥1 prior-art/URL 또는 landscape 인용**). 신호(모델 판단 휴리스틱 가이드 — 결정 규칙 아님, C12): (1) 사용자 답이 `## External Landscape` 한 항목과 모순, (2) hold·satisficing 답(기존 locked-판정 트리의 "보류" 분기 재사용 — "모르겠음/둘 다/아무거나"), (3) floor 차원의 첫 open→in-progress 전이(그 차원에 첫 probe 착수), (4) coverage-mapper/blind-spot-prober 출력 비어있지 않음. 복수 신호 동시 발화 시 heavy beat 1회로 합침(중복 억제). 모든 teach는 질문 형태·단정 금지(C3). **AC 검증 대상**은 SKILL이 이 신호 목록 + 크기 한도(teach-lite ≤1문장 / teach-heavy ≥1 URL)를 명문화했는지(grep)이며, 각 발화의 per-firing 결정성은 검증 대상이 아니다(C12).
- **AC9**: `rhythm-guard`(`non_user_streak`) 카운터가 probe 기준으로 재프레임되고, SKILL.md에서 **종료-scoped** round 참조가 커버리지 기반으로 교체된다. 검증은 두 레이어 — (i) 종료 로직 블록에 "round" 잔존 0(grep), (ii) 빈도-scoped round 언급(`round당 최대 1회` 류)은 교체 대상 아님을 리뷰가 확인. mechanical grep이 종료-scoped와 빈도-scoped round 언급을 구분 못 하는 한계는 리뷰 레이어가 보완한다(이 문서 검증의 mechanical 한계 인정).
- **AC10**: `templates/interview-brief-template.md`가 최종 9-섹션 순서(Handoff Context "Locked in this doc"에 명시)로 재구성 — `## Blind Spots & Premortem`(§5), `## Coverage Ledger`(§6) 신규 삽입, 기존 Tried & Discarded/Open Questions/Concrete Next Action은 §7/§8/§9로 renumber + stale `source:` 버전 동기화. `check_brief` 신규 fixture(valid-with-coverage / floor-open / floor-evidence-empty / missing-blind-spot / missing-derived-row / derived-sentinel / web-disabled-blind-spot) 통과.
- **AC11**: `plugin.json` 0.22.0, `CHANGELOG.md [0.22.0]`, `README.md`(Agents·Hooks·Principles Instantiated) 동기화. 버전 리터럴 핀 테스트는 minor 불변식만 검사(patch digit unpin).
- **AC12**: `probe_budget.py`가 mutation-검증 가능 — cap을 넘긴 상태 fixture에 `increment`가 non-zero exit(AC4). cap enforcement 제거 시 테스트 RED(teeth).

## Files to Modify

```
plugins/spec-distill/.claude-plugin/plugin.json           — version 0.21.0 → 0.22.0
plugins/spec-distill/skills/conducting-interview/SKILL.md  — 라운드 루프 → 커버리지 루프; 상태 스키마(3-state); teach-beat(AC8); C45 dispatch 트리거(interview_round>=2 → C11); rhythm-guard 재프레임; blind-spot dispatch; probe 백스톱 호출; 헤더 stale AC-ref 위생
plugins/spec-distill/scripts/probe_budget.py               — NEW web_budget.py sibling(increment/check, cap 12, DEVBREW_SPEC_DISTILL_PROBE_CAP)
plugins/spec-distill/scripts/check_brief.py                — Coverage Ledger floor all-closed + Blind Spots 섹션 게이트
plugins/spec-distill/templates/interview-brief-template.md — 9-섹션 재구성(§Blind Spots & Premortem, §Coverage Ledger 신규) + source: 버전 동기화
plugins/spec-distill/agents/coverage-mapper.md             — breadth-keeper 재명명·재목적화(Output = derived_dimensions[] + neglect_flag, advisory)
plugins/spec-distill/agents/blind-spot-prober.md           — NEW 적대적 premortem 에이전트(read-only, Output 스키마, fan-out 1)
plugins/spec-distill/agents/steelman-builder.md            — description 내 'breadth-keeper'→'coverage-mapper' terminology-only 동기화(NG3 예외, behavior 무변경)
plugins/spec-distill/README.md                             — Agents/Hooks/Principles Instantiated 동기화
plugins/spec-distill/CHANGELOG.md                          — [0.22.0] 항목
plugins/spec-distill/tests/fixtures/interview-brief-*.md   — 커버리지 게이트 신규 fixture 7종
plugins/spec-distill/tests/test_check_brief.sh             — Coverage Ledger + Blind Spots 게이트 assertion
plugins/spec-distill/tests/test_probe_budget.sh            — NEW cap increment/초과 mutation 테스트
plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh — breadth-keeper 테스트 재명명·전환
plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh — NEW read-only + Output 스키마 존재 테스트
plugins/spec-distill/tests/test_conducting_interview_*.sh  — 커버리지 루프·마이그레이션(probe_count seed=0)·백스톱 assertion
plugins/spec-distill/tests/test_readme_sync.sh             — 재명명된 에이전트/신규 섹션 참조 정합
```

## Verification Plan

- **V1**: `cd plugins/spec-distill && python3 -m pytest tests/ -q` 및 bash 스위트 실행 — baseline(작업 전 캡처) 대비 회귀 0. 테스트는 repo root/plugin dir 규약대로 실행.
- **V2**: `python3 scripts/check_brief.py gate <fixture>` — valid-with-coverage exit 0; floor-open / floor-evidence-empty / missing-blind-spot / missing-derived-row exit 1; derived-sentinel / web-disabled-blind-spot exit 0.
- **V3**: 신규 `blind-spot-prober`·재명명 `coverage-mapper` frontmatter 테스트 — `tools:` allowlist에 Write/Edit 부재를 grep으로 확증(mutation: Write 추가 시 RED) + blind-spot-prober Output 스키마 키(`hidden_assumptions`/`failure_modes`) 존재. (Law 2 teeth)
- **V4**: 마이그레이션 테스트 — 구 `interview_round` state fixture 로드 시 coverage floor all-`open` seed + `probe_count: 0` + advisory 출력, 원본 frontmatter 미변경 확인.
- **V5**: 백스톱 mutation 테스트 — `probe_budget.py increment`가 cap+1 상태에서 non-zero exit(AC12). cap 집행 코드 제거 시 RED. (프로즈 grep 아님 — 기계적 집행 확증)
- **V6**: `bash tests/test_readme_sync.sh` — README가 `breadth-keeper` 잔여 참조 0, `coverage-mapper`·`blind-spot-prober` 신규 참조 존재, 버전 0.22.0 정합.
- **V7**: stale-term 잔존 검사(두 term 분리 — V4와의 모순 회피). **(a) `breadth-keeper`**: `grep -rn 'breadth-keeper' plugins/spec-distill/` 잔존 0(코드·README·테스트·steelman description 전부, AC7·NG3). **(b) `interview_round`**: 활성 상태-스키마 선언 + 종료 로직에 잔존 0이되, 마이그레이션 감지 코드(AC5, `## In-flight state migration` 라벨 블록)와 `tests/fixtures/` legacy state fixture는 명시적 예외(구세션 감지에 필드명 필요 — V4 fixture와 정합). grep은 이 두 예외 경로를 제외하고 0(예: `--include` 스코프 또는 예외 경로 필터).
- **V8**: design-doc Law 2 분리 리뷰 — `spec-distill:spec-reviewer` + codex co-review dispatch(Stop 훅 강제)로 미검증 가정·핸드오프 완결성 검토, findings 반영.
- **V9**: 수동 e2e — 실제 토픽으로 인터뷰 1회 돌려 원장이 floor를 닫아가고 brief에 직렬화되며 blind-spot이 unknown-unknown을 표면화하고 teach-beat가 신호에서만 heavy로 발화, probe cap 초과 시 escalation이 뜨는지 육안 확인.

## Rejected Alternatives

- **R1 — 라운드 기반 구조 유지(또는 더 가볍게만)**: §4 steelman(respondent fatigue + YAGNI)이 방어된 방향. 라운드 카운터가 기계적 느낌 + 주제-특수 미지 부재의 근본원인이라 유지 시 원 문제 미해결. "집요함=길이" 등식 폐기로 흡수(재정의).
- **R2 — 모든 probe에 full teach-beat**: respondent fatigue/satisficing(15–20분 후 품질 하락, 장문 satisficing 20–40%)로 정확도 되레 하락. 대체 = teach-lite + 신호 조건부 heavy(BD2·AC8).
- **R3 — 커버리지 계약 = 고정 확장 체크리스트(~7 박스)**: 기계적 느낌의 근원(고정 박스)을 박스 수만 늘려 재도입. 대체 = 고정 floor + 주제-도출 하이브리드(LD4).
- **R4 — 재구성 범위 = 프로즈만(게이트/상태 불변)**: 커버리지-구동이 문서상으로만 존재하고 집행 안 됨. 대체 = 중간 범위(SKILL + check_brief + 상태 + probe_budget, LD5).
- **R5 — blind-spot 인라인(subagent 없음)**: 독립 적대자 상실 — 인터뷰 턴이 자기 전제에 눈멀어 unknown-unknown 노출력 약화. LD2의 "적대적 subagent" 취지와 상충.
- **R6 — blind-spot을 steelman-builder 재사용**: premortem(실패양식 노출)은 대안 옹호와 다른 작업 — steelman 단일 책임이 흐려짐. 대체 = 전용 blind-spot-prober(BD1).
- **R7 — coverage-mapper 대신 breadth-keeper 최소 유지(agent 이월)**: LD5가 애초 이월했으나 brainstorming서 사용자가 agent-이월 조항을 해제 — breadth-keeper의 tunneling-검출 side-role을 커버리지 계약에 공급하는 advisory 제안자 역할로 승격(BD3).
- **R8 — probe 백스톱 = SKILL 프로즈 self-tracking(스크립트 없음)**: "종료 불가"가 실제로 bounded/집행되는지 검증 불가 — Unbounded-autonomy 금지 패턴의 핵심 요건(기계적 backstop) 미충족. 대체 = `probe_budget.py` 기계적 집행 + mutation 테스트(C10·AC12, round-1 리뷰 반영).
- **R9 — 커버리지 원장을 state.local.md에만 저장**: `check_brief.py`가 state를 안 읽으므로 floor-closed를 게이트로 집행 불가(brief-only 게이트). 대체 = brief `## Coverage Ledger`에 직렬화(C9·AC2, round-1 리뷰 반영).
- **R10 — 커버리지 status = binary(open/closed)**: "진전 없음" 신호(C11)와 teach-beat 첫-개방 신호(AC8-3)를 표현할 중간 상태가 없어 dispatch·teach 트리거가 정의 불가. 대체 = 3-state open/in-progress/closed(C9, round-2 리뷰 반영).
- **R11 — Coverage Ledger와 Derived Coverage 별도 섹션**: 원장이 이미 derived 행을 rationale+evidence와 함께 담으므로 중복. 대체 = 단일 `## Coverage Ledger`(floor+derived 통합, round-2 리뷰 반영).

## Open Questions

- None — 모든 설계 결정이 이 문서에서 lock됨(probe cap·트리거 임계·status 모델·섹션 순서·직렬화 스키마 확정). planning은 확정값 구현·튜닝만 담당.

## Concrete Next Action

다음 단계: `superpowers:writing-plans` (단, Stop 훅이 먼저 `spec-distill:spec-reviewer` Law 2 분리 리뷰를 강제 — 리뷰 pass 후 진행).
- Spec 경로: `docs/superpowers/specs/2026-07-20-spec-distill-interview-coverage-driven-design.md`
- Plan 산출물: `docs/superpowers/plans/2026-07-20-spec-distill-interview-coverage-driven.md`
- 명령: `Skill superpowers:writing-plans docs/superpowers/specs/2026-07-20-spec-distill-interview-coverage-driven-design.md`
