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

> 이 spec을 처음 보는 사람(또는 /compact 후 자기 자신)이 30초에 핵심 파악할 수 있게.
> 대화 컨텍스트를 가정하지 말 것 — 모든 사실은 spec 본문에 self-contained.

**TL;DR** (1–2 sentences — 무엇을, 왜):
- spec-distill 인터뷰가 주제와 무관하게 같은 5개 라운드 박스를 밟아 "기계적"이고, 사용자가 모르는 주제-특수 미지를 열 자리가 없다. 근본원인은 집요함·깊이·차원이 전부 `interview_round` 카운터에 묶인 것 — 이를 "반드시 열려야 할 최소 미지 차원(floor) + 주제-도출 차원" 커버리지 계약으로 옮기고, probe 선택은 CTA 툴킷에서 모델이 적응적으로 한다.
- 산출물은 여전히 interview brief. 이 재구성은 인터뷰 stage(문제공간)만 바꾸며 design-doc 리뷰(Phase 2)·훅은 건드리지 않는다.

**Implicit context** (Constraints에 안 박힌, 작업 진행에 필요한 외부 사실):
- 인터뷰 stage는 자기 라운드를 모는 훅이 없다 — 라운드는 SKILL.md 프로즈 + `state.local.md`가 몬다. 그래서 커버리지 재구성은 훅을 강제 변경하지 않는다.
- `rhythm-guard`는 에이전트가 아니라 SKILL 안 `non_user_streak` 카운터다. 실제 에이전트 파일은 `breadth-keeper`, `steelman-builder` 둘뿐.
- 현행 코드에서 `interview_round`를 참조하는 지점은 두 곳뿐 — 상태 스키마 필드 선언(SKILL.md 상태 frontmatter)과 breadth-keeper C45 dispatch 트리거(`interview_round >= 2` + "직전 3 round 같은 dimension"). 두 곳 모두 이 재구성의 갱신 대상이다(하나라도 빠지면 stale 참조).
- `check_brief.py`는 brief 파일만 읽는다 — `state.local.md`를 읽지 않는다. 따라서 "floor 전부 closed"를 게이트로 집행하려면 커버리지 원장이 brief에 직렬화돼 있어야 한다(아래 C9).
- `web_budget.py`(increment/check/reset-sweep)가 세션 web 예산의 기계적 집행 선례다 — probe 백스톱도 같은 패턴(`probe_budget.py`)으로 집행한다(프로즈 self-tracking 아님).
- devbrew 금지 패턴 "Unbounded autonomy" — 카운터를 종료 driver에서 떼면 max-iter 백스톱을 반드시 유지하며, 그 백스톱은 기계적으로 계산·집행돼야 한다.

**Deferred to plan** (이 spec이 의도적으로 lock하지 않은 결정):
- 신규 섹션(`## Coverage Ledger`, `## Blind Spots & Premortem`) 삽입 시 기존 §1–7 renumber vs append 중 fixture churn 최소화 방식(§open-questions OQ1) — 내용이 아닌 기계적 배치.

**Locked in this doc (planning은 튜닝만, 재설계 금지):**
- probe cap 기본값 12 + env `DEVBREW_SPEC_DISTILL_PROBE_CAP`, `probe_budget.py`가 집행(C10).
- coverage-mapper dispatch 트리거 기본값: "한 차원에 연속 3 probe 진전 없음 OR floor 차원이 첫 도출 시점"(C11).
- 커버리지 원장은 brief `## Coverage Ledger`에 직렬화, orchestrator가 소유(C9).

## Context / Why

사용자가 `/spec-distill:interview`로 인터뷰 메커니즘 자체를 강화 요청했다: "더 집요하게, 사용자가 모르는 미지를 드러내 가르치고, 외부 탐색을 더 적극적으로, 라운드 기반을 유연한 아키텍처로." 인터뷰 stage에서 이를 재구성했고(brief: `docs/superpowers/interview/2026-07-20-spec-distill-interview-strengthening-interview.md`), 재구성한 문제정의는:

> 진짜 문제는 "인터뷰가 덜 집요하다"가 아니라 인터뷰의 집요함·깊이·차원이 전부 고정 라운드 체크리스트에 묶여 있다는 것이다(ROOT_CAUSE). 이 단일 근본원인이 세 증상을 동시에 낳는다 — (1) 같은 박스를 밟아 기계적, (2) 주제-특수 미지를 열 자리 없음, (3) 외부 탐색이 라운드 종속.

숨은 가정 반증(HIDDEN_ASSUMPTIONS): "더 집요 + 더 유연"은 현재 결정론 라운드 구조에서 서로 당긴다. 해소는 집요함의 구현체를 "라운드 수 → 커버리지 계약"으로 옮기기다. 지금 하는 이유: 인터뷰 stage는 spec-distill 전체 파이프라인의 입구라, 여기서 미지를 놓치면 하류(brainstorming/plan/구현) 전체가 잘못된 전제 위에 선다.

## Goals

- **G1**: 종료 driver를 `interview_round`(int)에서 커버리지 원장(floor 5차원 + 주제-도출 차원, 각 status open/closed + evidence)으로 교체한다. 원장은 `state.local.md`에 저장되고 brief `## Coverage Ledger`에 직렬화된다. (LD1)
- **G2**: 커버리지 계약 = 고정 보편 floor(root-problem / landscape / skepticism / blind-spot / open-questions)만 결정론 강제 + 그 위 주제-도출 차원. 주제-도출 차원의 authority는 orchestrator(인터뷰 스킬)에 있고, coverage-mapper는 후보를 *제안*할 뿐이다. (LD4)
- **G3**: 집요함을 인터뷰 길이가 아니라 "floor 미충족 시 종료 불가"로 구현하되, `probe_budget.py`가 집행하는 `probe_count` 백스톱으로 bounded. (LD3)
- **G4**: teach/reveal-unknown을 cross-cutting teach-beat(질문 형태, 단정 금지) + 전용 blind-spot floor 차원으로 구현. (LD2)
- **G5**: probe의 종류·순서·깊이를 모델이 CTA 툴킷(CDM 반복 pass / ACTA knowledge-audit·simulation)에서 신호 기반 적응 선택하게 한다. 고정 라운드 순서 없음. (LD1)

## Non-goals

- **NG1**: 훅(`review-dispatch`, `session-end-cleanup`, `spec-write-validator`, `pending-review-reminder`, `state_path`) 변경 — 이월이 아니라 커버리지 모델이 훅을 건드리지 않기 때문. (LD5)
- **NG2**: `reviewing-spec` Phase 2(design-doc Law 2 리뷰) 변경 — 인터뷰 stage 무관.
- **NG3**: `steelman-builder` 에이전트 변경 — R3 skepticism 의례는 floor에 그대로 유지.
- **NG4**: 인터뷰 brief가 spec.md로 바뀌는 것 — brief는 단독 완결 terminal 산출물로 유지(NG7 계약 불변).
- **NG5**: web budget cap(sweep 4 / session 8) 상향 — 외부 탐색 적극화는 라운드-비종속 재배치로 달성하지 cap 완화로 하지 않는다.
- **NG6**: `check_brief.py`가 커버리지의 *의미적* 정합(floor가 진짜로 닫혔나)을 판정하는 것 — 게이트는 form·존재만 본다(C2). 의미는 orchestrator + 독립 adversary가 담보.

## Constraints

- **C1**: Unbounded-autonomy 금지 — `probe_count` soft cap 도달 & floor 미충족 시 사용자-override escalation(계속 / Open Question 박제 후 종료 / abort)을 발화해야 한다. cap은 `probe_budget.py`가 기계적으로 계산·집행한다(C10) — 프로즈 self-tracking 금지.
- **C2**: 결정론은 floor의 *형식·존재*에만 — `check_brief.py`는 의미적 커버리지를 판정하지 않는다(게이트는 자기 regex 밖을 못 봄). 단, brief에 직렬화된 원장 덕에 게이트는 "floor 5행 존재 + 각 status:closed + evidence 비어있지 않음"을 form 수준에서 집행한다. 실체는 모델 + 독립 adversary(coverage-mapper·blind-spot-prober)가 담보. (harness-lightness)
- **C3**: teach-beat는 prior-art/trade-off를 **단정 아닌 질문 형태**로 제시해 편향-주입을 회피한다(공유된 전제가 사용자 답을 오염시키지 않게).
- **C4**: 상태 스키마 마이그레이션은 non-mutating read promote(C10 패턴) — 구세션 로드 시 in-memory default로 승격하고 다음 명시적 write 시점에만 frontmatter 갱신(backward-rewrite 금지).
- **C5**: web 부재(`DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` 또는 도구 부재) 시 blind-spot은 inline premortem으로 loud 강등 — R2/R3와 대칭, opaque gate-fail 금지(graceful degradation).
- **C6**: 신규/변경 에이전트는 `tools:` allowlist frontmatter로 fail-closed(Write/Edit 물리 부재) — Law 2 read-only 불변.
- **C7**: 이 플러그인을 건드리는 PR이므로 같은 커밋에서 `plugin.json` 0.21.0 → 0.22.0(minor: 새 surface) + CHANGELOG `[0.22.0]` 동기화.
- **C8**: blind-spot-prober는 fan-out 1(인터뷰당 1회 dispatch) — devbrew N≥5 hard review 게이트 미해당.
- **C9**: **원장 ownership** — 커버리지 status 전이(open→closed)와 evidence 기록은 orchestrator(인터뷰 스킬)만 수행하고, `state.local.md`에 쓰는 동시에 brief `## Coverage Ledger`에 직렬화한다. coverage-mapper·blind-spot-prober는 read-only *제안자*이지 상태 writer가 아니다(Law 2). agent 출력은 orchestrator가 원장에 반영할지 판정한다.
- **C10**: **probe 백스톱 집행** — `probe_budget.py`(scripts/, `web_budget.py` sibling)가 `increment`/`check`로 `probe_count`를 계산하고 cap 초과 시 non-zero exit. cap 기본값 12, env `DEVBREW_SPEC_DISTILL_PROBE_CAP`로 override. SKILL은 매 probe 전 `increment`를 호출한다.
- **C11**: **coverage-mapper dispatch 트리거** = "한 차원에 연속 3 probe 진전 없음 OR floor 차원 첫 도출." `interview_round >= 2` 트리거를 이 커버리지 조건으로 교체한다(라운드 참조 잔존 금지).

## Acceptance Criteria

- **AC1**: `state.local.md` 스키마에서 **오직** `interview_round`만 제거되고 `coverage`(floor 5 + derived[]) + `probe_count`가 추가된다. 기존 필드 `non_user_streak`·`web_sweep_count`·`web_search_count`·`rereview_count`·`trivia_escape_armed`·`issue_history`·`pending_locked_decisions`는 전부 **유지**(삭제 금지 — 이 목록은 non-exhaustive 유지 선언).
- **AC2**: 종료 게이트 = (a) orchestrator가 floor 5차원 전부 `status: closed`임을 `state.local.md`에서 확인하고 brief `## Coverage Ledger`에 직렬화, AND (b) `check_brief.py gate`가 brief의 `## Coverage Ledger`에서 floor 5행 존재 + 각 `closed` + evidence 비어있지 않음 + `## Derived Coverage` 존재를 검증해 exit 0. floor 한 행이라도 open/evidence-공백이면 exit ≠ 0.
- **AC3**: `check_brief.py`가 (a) `## Coverage Ledger`의 floor 5행 all-closed, (b) `## Blind Spots & Premortem` 섹션 존재, (c) `## Derived Coverage` 형식·존재(≥1 entry `dimension — rationale — evidence` OR sentinel `N/A — floor로 충분`)를 검증하고 미충족 시 exit ≠ 0.
- **AC4**: `probe_budget.py increment`가 `probe_count`를 전진시키고 cap(기본 12) 초과 시 non-zero exit. SKILL은 non-zero exit & floor 미충족 시 `AskUserQuestion` 3옵션 escalation(계속 / 박제 후 종료 / abort)을 발화한다. abort 선택 시 state 보존.
- **AC5**: 구세션(`interview_round` 존재 / `coverage` 부재) 로드 시 floor 전부 open으로 seed + `probe_count`는 **0으로 초기화**(interview_round 값 승계 금지 — 라운드 수는 probe 수가 아님) + advisory 한 줄(`[spec-distill vX] state schema migration: coverage/probe_count added`) 출력, frontmatter는 backward-rewrite하지 않는다.
- **AC6**: 신규 `agents/blind-spot-prober.md`가 `tools: Read, Grep, Glob, WebSearch, WebFetch`(Write/Edit 부재) frontmatter + 명시적 Output YAML 스키마(`hidden_assumptions[]{assumption, why_risky, evidence[]}`, `failure_modes[]{mode, trigger, evidence[]}`, `confidence`)를 갖고, blind-spot floor 차원 개방 시 인터뷰당 1회 dispatch된다. 출력은 orchestrator가 brief `## Blind Spots & Premortem`에 기록.
- **AC7**: `breadth-keeper`가 `coverage-mapper`로 전환 — Output 스키마가 `derived_dimensions: [{name, rationale}]` + `neglect_flag` + `neglected_dimensions[]` + `confidence`. read-only frontmatter 유지. 출력은 **advisory**(orchestrator가 원장 admit 판정, G2). 복수 dispatch 시 name 기준 union·dedup. 재명명이 README/dispatch/테스트 참조 전반에 반영. C45 dispatch 트리거(SKILL.md의 `interview_round >= 2`)가 C11 커버리지 조건으로 교체.
- **AC8**: teach-beat = 모든 probe에 teach-lite(**≤1문장 근거, web 호출 없음**) + 열거 신호 시 evidence-heavy(**≥1 prior-art/URL 또는 landscape 인용**). 신호 술어(관측 가능): (1) 사용자 답이 `## External Landscape` 한 항목과 모순, (2) hold·satisficing 답(기존 locked-판정 트리의 "보류" 분기 재사용 — "모르겠음/둘 다/아무거나"), (3) floor 차원 status open→in-progress 첫 전이, (4) coverage-mapper/blind-spot-prober 출력 비어있지 않음. 복수 신호 동시 발화 시 heavy beat 1회로 합침(precedence: 중복 억제). 모든 teach는 질문 형태·단정 금지(C3).
- **AC9**: `rhythm-guard`(`non_user_streak`) 카운터가 probe 기준으로 재프레임되고, SKILL.md에서 **종료-scoped** round 참조가 커버리지 기반으로 교체된다. 검증은 두 레이어 — (i) 종료 로직 블록에 "round" 잔존 0(grep), (ii) 빈도-scoped round 언급(`round당 최대 1회` 류)은 교체 대상 아님을 리뷰가 확인(mechanical grep이 둘을 구분 못 하는 한계 인정, AC11 선례).
- **AC10**: `templates/interview-brief-template.md`에 `## Coverage Ledger`, `## Blind Spots & Premortem`, `## Derived Coverage` 추가 + stale `source:` 버전 동기화 + `check_brief` 신규 fixture(valid-with-coverage / floor-open / floor-evidence-empty / missing-blind-spot / missing-derived-coverage / derived-coverage-sentinel / web-disabled-blind-spot) 통과.
- **AC11**: `plugin.json` 0.22.0, `CHANGELOG.md [0.22.0]`, `README.md`(Agents·Hooks·Principles Instantiated) 동기화. 버전 리터럴 핀 테스트는 minor 불변식만 검사(patch digit unpin).
- **AC12**: `probe_budget.py`가 mutation-검증 가능 — cap을 넘긴 상태 fixture에 `increment`가 non-zero exit(프로즈 grep 아님). cap enforcement 제거 시 테스트 RED(teeth).

## Files to Modify

```
plugins/spec-distill/.claude-plugin/plugin.json           — version 0.21.0 → 0.22.0
plugins/spec-distill/skills/conducting-interview/SKILL.md  — 라운드 루프 → 커버리지 루프; 상태 스키마; teach-beat(AC8); C45 dispatch 트리거(interview_round>=2 → C11); rhythm-guard 재프레임; blind-spot dispatch; probe 백스톱 호출; 헤더 stale AC-ref 위생
plugins/spec-distill/scripts/probe_budget.py               — NEW web_budget.py sibling(increment/check, cap 12, DEVBREW_SPEC_DISTILL_PROBE_CAP)
plugins/spec-distill/scripts/check_brief.py                — Coverage Ledger floor all-closed + Blind Spots 섹션 + Derived Coverage 형식·존재 게이트
plugins/spec-distill/templates/interview-brief-template.md — §Coverage Ledger, §Blind Spots & Premortem, §Derived Coverage 추가 + source: 버전 동기화
plugins/spec-distill/agents/coverage-mapper.md             — breadth-keeper 재명명·재목적화(Output = derived_dimensions[] + neglect_flag, advisory)
plugins/spec-distill/agents/blind-spot-prober.md           — NEW 적대적 premortem 에이전트(read-only, Output 스키마, fan-out 1)
plugins/spec-distill/README.md                             — Agents/Hooks/Principles Instantiated 동기화
plugins/spec-distill/CHANGELOG.md                          — [0.22.0] 항목
plugins/spec-distill/tests/fixtures/interview-brief-*.md   — 커버리지 게이트 신규 fixture 7종
plugins/spec-distill/tests/test_check_brief.sh             — Coverage Ledger + Blind Spots + Derived Coverage 게이트 assertion
plugins/spec-distill/tests/test_probe_budget.sh            — NEW cap increment/초과 mutation 테스트
plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh — breadth-keeper 테스트 재명명·전환
plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh — NEW read-only + Output 스키마 존재 테스트
plugins/spec-distill/tests/test_conducting_interview_*.sh  — 커버리지 루프·마이그레이션(probe_count seed=0)·백스톱 assertion
plugins/spec-distill/tests/test_readme_sync.sh             — 재명명된 에이전트/신규 섹션 참조 정합
```

## Verification Plan

- **V1**: `cd plugins/spec-distill && python3 -m pytest tests/ -q` 및 bash 스위트 실행 — baseline(작업 전 캡처) 대비 회귀 0. 테스트는 repo root/plugin dir 규약대로 실행.
- **V2**: `python3 scripts/check_brief.py gate <fixture>` — valid-with-coverage exit 0; floor-open / floor-evidence-empty / missing-blind-spot / missing-derived-coverage exit 1; derived-coverage-sentinel / web-disabled-blind-spot exit 0.
- **V3**: 신규 `blind-spot-prober`·재명명 `coverage-mapper` frontmatter 테스트 — `tools:` allowlist에 Write/Edit 부재를 grep으로 확증(mutation: Write 추가 시 RED) + blind-spot-prober Output 스키마 키(`hidden_assumptions`/`failure_modes`) 존재. (Law 2 teeth)
- **V4**: 마이그레이션 테스트 — 구 `interview_round` state fixture 로드 시 coverage floor all-open seed + `probe_count: 0` + advisory 출력, 원본 frontmatter 미변경 확인.
- **V5**: 백스톱 mutation 테스트 — `probe_budget.py increment`가 cap+1 상태에서 non-zero exit(AC12). cap 집행 코드 제거 시 RED. (프로즈 grep 아님 — 기계적 집행 확증)
- **V6**: `bash tests/test_readme_sync.sh` — README가 `breadth-keeper` 잔여 참조 0, `coverage-mapper`·`blind-spot-prober` 신규 참조 존재, 버전 0.22.0 정합.
- **V7**: `grep -n interview_round plugins/spec-distill/` — 구현 후 상태 필드 선언·C45 트리거 두 곳 모두에서 잔존 0(AC1·AC7·C11 교차 확증).
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

## Open Questions

- **OQ1**: 신규 3섹션(`## Coverage Ledger`, `## Blind Spots & Premortem`, `## Derived Coverage`) 삽입 시 기존 §1–7 renumber vs append 중 fixture churn 최소화 방식 — 내용 결정이 아니라 기계적 배치라 planning이 정한다.

## Concrete Next Action

다음 단계: `superpowers:writing-plans` (단, Stop 훅이 먼저 `spec-distill:spec-reviewer` Law 2 분리 리뷰를 강제 — 리뷰 pass 후 진행).
- Spec 경로: `docs/superpowers/specs/2026-07-20-spec-distill-interview-coverage-driven-design.md`
- Plan 산출물: `docs/superpowers/plans/2026-07-20-spec-distill-interview-coverage-driven.md`
- 명령: `Skill superpowers:writing-plans docs/superpowers/specs/2026-07-20-spec-distill-interview-coverage-driven-design.md`
