# devbrew 수확 후 로드맵 (Post-Harvest Roadmap)

> **Research is done. This is the build sequence.**
> *리서치는 끝났다. 이제 빌드 순서다.*
>
> *4개 소스 하니스에서 69개 후보 패턴, 6개 페이즈로 증류. 각 페이즈에 수락 기준, 순서 제약, 버전 번호. 플러그인별 스펙은 해당 페이즈 시작 시점에 작성 — 그 전이 아님.*

이 문서는 리서치 ([`plugin-harvest-rounds.md`](../research/plugin-harvest-rounds.md))와 실행 사이의 다리입니다. Candidate Registry (C1–C69)를 Go/Park/Kill 결정과 단계적 빌드 순서로 변환합니다. 수확 파일에 분석이 있고, 이 파일에 결정이 있습니다.

**수확된 소스:** oh-my-claudecode v4.9.1 (R1), gstack (R2), ouroboros v0.28.7 (R3), compound-engineering v2.66.1 (R4).

**검증:** 4개 교차 참조 분석 (하니스당 하나), 각각 잘못된 할당, 누락된 수락 기준, 안티-권장 위반, 미해결 미결 질문을 검사.

## How to Read This Document

- **Go** — 빌드 확정, 페이즈에 배정됨.
- **Park** — 테스트 가능한 un-parking 조건과 함께 보류. 포기가 아님.
- **Kill** — 근거와 함께 영구 거절.
- 각 **페이즈** 섹션에는: 범위, 후보, 페이즈 내 빌드 순서, 순서 제약, 종료 기준이 포함.
- 후보는 **ID로만** 참조 (예: "C2 — physical tool scoping"). 전체 분석은 [수확 파일](../research/plugin-harvest-rounds.md)에 있음.
- **우선순위 rubric** (수확에서 유래): `(laws_covered × gap_severity × round_reinforcement) / build_cost`.

## Decision Summary

| id | pattern | disposition | phase |
|---|---|---|---|
| C1 | Ambiguity-gated spec authoring | Go | 2b |
| C2 | Physical tool scoping (PreToolUse hook) | Go | 1e |
| C3 | Learner skill (3-point extraction gate) | Go | 4a |
| C4 | Wiki/index triad | Go | 4a |
| C5 | PreCompact state snapshot | Go | 3 |
| C6 | Three-tier verification | Go | 1b |
| C7 | Stagnation detection (circuit breaker) | Go | 2a |
| C8 | Keyword pre-routing | Park | — |
| C9 | Dimensional progress tracking | Go | 2e |
| C10 | RALPLAN-DR plan format | Go | 0 |
| C11 | Kill-switch convention | Go | 0 |
| C12 | Hook signal-tag namespacing | Go | 0 |
| C13 | *(retired)* | Kill | — |
| C14 | Agent role-prompt opener | Go | 0 |
| C15 | Commit-trailer audit | Go | 5 |
| C16 | Cross-model adversarial routing | Park | — |
| C17 | Per-agent benchmark harness | Park | — |
| C18 | Agent `level: N` tag | Park | — |
| C19 | Two-stage reviewer protocol | Go | 1b |
| C20 | Standardized verdict schema | Go | 1a |
| C21 | Dual-harness packaging | Park | — |
| C22 | Working agreements block | Go | 0 |
| C23 | Lane-grouped agent catalog | Park | — |
| C24 | Multiple specialized reviewers | Go | 1d |
| C25 | Dual-lifetime memory tags | Go | 4a |
| C26 | Template-driven skill codegen | Park | — |
| C27 | `preamble-tier` frontmatter | Go | 0 |
| C28 | `benefits-from` handoff dependency | Go | 0 |
| C29 | Skill-level PreToolUse hooks | Park | — |
| C30 | Per-finding JSON output contract | Go | 1a |
| C31 | Review army scope-gated dispatch | Go | 1c |
| C32 | Expanded specialist catalog | Go | 1d |
| C33 | Always-on adversarial review | Go | 1c |
| C34 | Plan/audit boomerang | Go | 2d |
| C35 | Two-tier test classification | Go | 1b |
| C36 | Review readiness dashboard | Go | 1f |
| C37 | Retrospective `/retro` | Park | — |
| C38 | Host adapter registry | Park | — |
| C39 | Persistent runtime daemon | Park | — |
| C40 | AI-slop blacklist | Park | — |
| C41 | Prompt-injection defense | Go | 0 |
| C42 | Tiered review gating | Go | 1c |
| C43 | Socratic interview (4-path routing) | Go | 2c |
| C44 | Dialectic rhythm guard | Go | 2c |
| C45 | Breadth-keeper agent | Go | 2c |
| C46 | Lateral thinking personas | Go | 2a |
| C47 | PAL Router | Park | — |
| C48 | Event-sourced state | Kill | — |
| C49 | Seed immutability | Go | 2b |
| C50 | MCP-first with plugin fallback | Go | 0 |
| C51 | Ontological questioning | Go | 2c |
| C52a | Consensus triggers (structural) | Go | 1b |
| C52b | Consensus triggers (drift-aware) | Go | 2d |
| C53 | Answer prefix convention | Go | 2e |
| C54 | Drift measurement formula | Go | 3 |
| C55 | Seed schema (markdown+frontmatter) | Go | 2b |
| C56 | Autofix routing (4-level) | Go | 1a |
| C57 | Review mode detection | Go | 0 |
| C58 | Document-review skill | Go | 2d |
| C59 | Full compound cycle reference | Go | 0 |
| C60 | Scope-adaptive depth | Go | 2d |
| C61 | 5-dimension overlap detection | Go | 4c |
| C62 | Session historian | Park | — |
| C63 | False-positive suppression lists | Go | 1f |
| C64 | `disable-model-invocation` | Go | 0 |
| C65 | Run artifact persistence | Go | 3 |
| C66 | Linked artifact flow | Go | 0 |
| C67 | Execution strategy selector | Go | 0 |
| C68 | Adversarial 4-technique framework | Go | 1f |
| C69 | Grep-first learnings search | Go | 4b |

**합계: 53 Go + 14 Park + 2 Kill = 69.**

---

## Phase 0 — Convention Sweep

문서, README, 프롬프트 변경만. 새 플러그인 코드 없음. 단일 PR.

**후보:** C10, C11, C12, C14, C22, C27, C28, C41, C50, C57, C59, C64, C66, C67.

**레트로핏 항목:** 양쪽 플러그인의 CHANGELOG.md, "Principles Instantiated" README 섹션, quality-pipeline skill과 runtime-verifier agent의 `cost_class` 선언, SKILL.md frontmatter 스키마 스펙.

**핵심 산출물 — C57 (review mode detection):** Phase 1a의 필수 선행 조건. 네 가지 모드: `headless` / `autofix` / `report-only` / `interactive`. 감지 로직은 Phase 1 시작 전에 문서화 완료 필수.

**조정 원칙** (R2 "Boil the Lake" vs P8): *"Tests boil the lake; production code deletes ruthlessly."*

**종료 기준:**
- 양쪽 플러그인이 CLAUDE.md Plugin Shape 체크리스트 전항목 통과.
- C57 mode detection 스펙 문서화 완료.
- quality-gates v1.4.1, project-init v1.1.1.

---

## Phase 1 — quality-gates Reviewer Hardening

**점수:** 8.0 (최고). **법칙:** 1+2. **비용:** S. **출시:** quality-gates v1.5.0.

**후보 (16개):** C2, C6, C19, C20, C24, C30, C31, C32, C33, C35, C36, C42, C52a, C56, C63, C68.

### Build order

**1a — 통합 리뷰 출력 스키마** (기반; Phase 0 C57에 의존):
- C20: Verdict envelope (APPROVE / REQUEST CHANGES / COMMENT × CRITICAL / HIGH / MEDIUM / LOW).
- C30: Per-finding payload (`severity`, `confidence` 1–10, `path`, `line`, `category`, `summary`, `fix`, `fingerprint`, `specialist`). Sentinel: `NO FINDINGS`. Confidence rubric: 9–10 표시, 7–8 표시, 5–6 주의 표기, 3–4 억제, 1–2 P0-only.
- C56: Autofix disposition (4 레벨): `safe_auto` → review-fixer, `gated_auto` → downstream-resolver (P22에 따라 `AskUserQuestion`), `manual` → human, `advisory` → release.

**1b — 검증 강화** (1a 위에 구축):
- C6: 3-tier 매핑 강화 (Mechanical $0 → Semantic $$ → Consensus $$$).
- C19: Two-stage 프로토콜 (스펙 준수 → 코드 품질).
- C52a: 구조적 consensus trigger (7개 중 4개): SEED_MODIFICATION, ONTOLOGY_EVOLUTION, GOAL_INTERPRETATION, MANUAL_REQUEST. Drift-aware trigger (C52b)는 Phase 2d로 이연.
- C35: Two-tier 테스트 분류 (gate / periodic) + diff 기반 선택. 비용 계층: <5s 무료, E2E ~$3.85/run 게이트 뒤, LLM-judge ~$4/run 강한 게이트.

**1c — Fan-out 삼위일체** (1a에 의존, dispatch 대상 필요):
- C31: Scope-gated dispatch. 상시 활성: Testing + Maintainability (≥50 LOC). `SCOPE_*` env var로 조건부. `[NEVER_GATE]` floor: Security + Testing.
- C33: 상시 활성 adversarial. LOC나 risk signal에 조건부로 만들지 않음. shipping을 gate하지 않음 — advisory only.
- C42: Tiered gating. Eng-review = single hard gate. 모든 specialist review = advisory.

**1d — 전문가 확장** (1c에 게이트됨):
- C24: api-reviewer + performance-reviewer.
- C32: data-migration, maintainability, red-team. 각각 C30 스키마에 따라 JSON 출력.

**1e — 물리적 집행** (1c–1d와 병렬):
- C2: PreToolUse 훅으로 모든 review-role agent에 blanket `disallowedTools: Write, Edit` 적용. 에코시스템 전체, agent별이 아님.

**1f — 마무리** (최종):
- C36: Review readiness dashboard (stale = >7일 또는 HEAD 변경).
- C63: 리뷰어별 "Flag하지 말아야 할 것" 목록.
- C68: Adversarial 4-technique 프레임워크 (가정 위반, 합성 실패, 연쇄 구성, 악용 케이스). 깊이 조절: Quick / Standard / Deep.

### Constraints

- 모든 집행은 agent 레이어 (C2 PreToolUse)에서, skill 레벨 `allowed-tools`가 아님.
- Tier 1 self-review 제로. 모든 수정은 Tier 2 또는 Tier 3 리뷰 필요.

### Exit criteria

- quality-gates v1.5.0.
- 통합 3-layer 스키마: verdict + per-finding + autofix.
- PreToolUse 훅이 모든 review agent에서 Write/Edit 차단 (C2).
- Scope-gated dispatch with `[NEVER_GATE]` on Security + Testing (C31).
- Adversarial: 상시 활성, 4 technique (C33 + C68).
- 신규 전문가: api, performance, data-migration, maintainability, red-team (C24 + C32).
- Two-tier 테스트 분류 (C35).
- CHANGELOG.md 엔트리.

---

## 페이즈 2 — spec-authoring 플러그인 + 정체 라이브러리 (Stagnation Library)

**점수:** 6.0 + 3.0 (정체 흡수). **법칙:** 1+3. **비용:** M. **출시:** `plugins/spec-authoring/` v0.1.0.

**후보 (15개):** C1, C7, C9, C34, C43, C44, C45, C46, C49, C51, C52b, C53, C55, C58, C60.

### Build order (strictly serialized)

**2a — 정체 라이브러리** (인터뷰 루프의 선행 조건):
- C7: Circuit breaker. 4개 패턴: SPINNING (sha256 반복, threshold=3), OSCILLATION (A↔B, threshold=2), NO_DRIFT (delta<0.01, threshold=3), DIMINISHING_RETURNS (improvement<0.01, threshold=3).
- C46: Persona 복구. Affinity: HACKER→SPINNING, RESEARCHER→{NO_DRIFT, DIMINISHING_RETURNS}, SIMPLIFIER→{DIMINISHING_RETURNS, OSCILLATION}, ARCHITECT→{OSCILLATION, NO_DRIFT}, CONTRARIAN→all. 결정론적 first-match.
- 위치: 크로스-플러그인 재사용을 위한 공유 `scripts/`.

**2b — 핵심 게이트** (2a에 의존):
- C1: 구조적 모호성 게이트. 필수 섹션: Context/Why, Goals, Non-goals, Constraints, Acceptance Criteria, Files to Modify, Verification Plan, Rejected Alternatives, Metadata. 구조적 먼저; 수치적은 선택.
- C55: Seed 스키마를 markdown + YAML frontmatter로 (.yaml 파일이 아님). 7개 core field: `goal`, `task_type`, `constraints`, `acceptance_criteria`, `exit_conditions`, `metadata`, `brownfield_context`. 선택적: `ontology_schema`, `evaluation_principles`, `ambiguity_score`.
- C49: git 버저닝으로 Seed 불변성 (event sourcing이 아님). 수정 시 C52a SEED_MODIFICATION 트리거.

**2c — 인터뷰 시스템** (2a + 2b에 의존):
- C43: 4-path 라우팅. PATH 1a는 사실 확인을 자동 승인 (`[from-code][auto-confirmed]` 표시). PATH 2 인간 판단 = 기본값.
- C44: Dialectic rhythm guard. 3회 연속 비사용자 답변 → PATH 2 강제.
- C45: Breadth-keeper agent (`disallowedTools: Write, Edit`).
- C51: 존재론적 질문 (5가지 유형: ESSENCE, ROOT_CAUSE, PREREQUISITES, HIDDEN_ASSUMPTIONS, EXISTING_CONTEXT). Standard/Deep scope에서 사용 가능; Lightweight에서는 skip.

**2d — 문서 리뷰** (Phase 1 리뷰어에 의존):
- C58: 2개 상시 활성 (coherence + feasibility) + 5개 조건부. Phase 1 리뷰어 풀에 dispatch.
- C34: Plan/audit boomerang (대칭적 사전 작업 + 사후 작업 리뷰).
- C60: Scope-adaptive 깊이. Lightweight / Standard / Deep. LLM 자동 평가 + `AskUserQuestion` override.
- C52b: Drift-aware trigger (SEED_DRIFT_ALERT >0.3, STAGE2_UNCERTAINTY >0.3, LATERAL_THINKING_ADOPTION). Phase 3이 drift 측정을 shipping할 때까지 부분적.

**2e — 출처 (Provenance)** (부가적):
- C53: 답변 접두사: `[from-code][auto-confirmed]`, `[from-code]`, `[from-user]`, `[from-research]`.
- C9: 차원별 스코어링 (선택적 — 구조적 게이트가 불충분할 때만 채택).

### Constraints

- 모든 파이프라인 단계 간 사용자 확인 게이트 (자동 결정 없음).
- 구조적 게이트 먼저; 수치 스코어링은 절대 primary가 되지 않음.
- Seed 스키마 = markdown + frontmatter, raw YAML 절대 금지.

### Exit criteria

- `plugins/spec-authoring/` v0.1.0 (Principles Instantiated: Law 1 / P1 / P2).
- 정체 라이브러리: 4개 패턴, sha256, persona 복구 (C7 + C46).
- 필수 섹션이 포함된 구조적 게이트 (C1).
- Seed 스키마: 7개 core field, markdown + frontmatter (C55).
- 인터뷰: 4-path 라우팅, rhythm guard, breadth-keeper (C43 + C44 + C45).
- Phase 1 리뷰어에 dispatch하는 문서 리뷰 (C58).
- CHANGELOG.md.

---

## 페이즈 3 — 상태 영속성 + Drift 라이브러리 (State Persistence + Drift Libraries)

**점수:** 3.0. **비용:** M. **출시:** 공유 라이브러리 모듈.

**후보 (3개):** C5, C54, C65.

- C5: PreCompact 상태 스냅샷. 마크다운: `.claude/<plugin>.local.md`. PreCompact가 불안정할 경우 Stop-hook으로 fallback.
- C54: Drift 측정. 3축 가중 Jaccard (Goal 0.5, Constraint 0.3, Ontology 0.2). Threshold ≤ 0.3. point-in-time으로 시작; v0.2.0에서 continuous 추가.
- C65: Per-run artifact를 `.claude/<plugin>-<run-id>.local.md`로. 마크다운, 디렉토리가 아님.

**종료 기준:**
- PreCompact 훅 with Stop-hook fallback (C5).
- Drift 라이브러리: 3축 Jaccard, 설정 가능한 threshold (C54).
- Per-run 마크다운 artifact (C65).
- 크로스-프로젝트 state에 `trusted: false` 기본값.
- Kill switch: `DEVBREW_SKIP_HOOKS=state-persistence:pre-compact`.

---

## Phase 4 — compounding-learnings Plugin

**점수:** 2.25. **법칙:** 3. **비용:** M. **출시:** `plugins/compounding-learnings/` v0.1.0.

**후보 (5개):** C3, C4, C25, C61, C69. Phase 3에 의존.

**4a — 코어** (첫 compound 사이클):
- C3: 3-point gate가 있는 Learner skill (non-Googleable / context-specific / hard-won).
- C4: Wiki/index triad (기록 → SessionStart가 읽음 → PreCompact가 영속).
- C25: Dual-lifetime 태그 (7일 / 영구). 크로스-프로젝트에는 `trusted: false`.

> **참고 (2026-05-06):** Phase 4a 후보 C3+C4+C25+C69는 이제 철학 §4.6 Compounding Skill primitive의 first-class 운영 내용 (philosophy.md §4.6 + Law 3 corollary 참조).

**4b — 읽기 측:** C69. Grep-first 7-step 검색. 수락 기준: recall >85%, precision >80%.

**4c — 쓰기 측:** C61. 5차원 중복 검출 (problem, root cause, solution, files, prevention). High (4-5) → 업데이트. Moderate (2-3) → 생성 + flag. Low (0-1) → 생성.

**종료 기준:**
- `plugins/compounding-learnings/` v0.1.0 (Principles Instantiated: Law 3 / P5 / P14).
- 3-point extraction gate (C3). Discoverability check (Law 3 따름정리).
- 중복 검출: 5차원, zero false-negative >70% (C61).
- Grep 검색: recall >85%, precision >80% (C69).
- Kill switch: `DEVBREW_DISABLE_COMPOUNDING_LEARNINGS=1`.

---

## 페이즈 5 — project-init 강화 (Enhancements)

**비용:** S. **출시:** project-init v1.2.0. 독립적 — Phase 0 이후 Phase 2–4와 병렬 가능.

**후보 (1개):** C15. Commit-trailer 스키마: `Constraint:`, `Rejected:`, `Directive:`, `Confidence:`, `Scope-risk:`, `Not-tested:`. Trivia escape: 한 문장 diff에는 skip.

**종료 기준:** project-init v1.2.0. Trailer 템플릿 + optional PostToolUse validation 훅. CHANGELOG.md 엔트리.

---

## 보류 항목 (Parked Items)

| id | pattern | 사유 | un-parking 조건 |
|---|---|---|---|
| C8 | Keyword pre-routing | S 비용, top-6에 미포함 | keyword-triggered skill을 가진 플러그인 >3개 |
| C16 | Cross-model adversarial | L 비용, 다중 모델 필요 | Multi-model API 검증 완료 + C7 shipped |
| C17 | Per-agent benchmark | L 비용 | 사용자가 1주일 예산 할당 |
| C18 | Agent `level: N` | 철학 문서 전용 | 철학 개정 사이클 |
| C21 | Dual-harness | Claude-Code 전용 | devbrew가 다른 런타임을 타겟 |
| C23 | Lane-grouped catalog | 낮은 agent 수 | Agent 수 > 10 |
| C26 | Skill codegen | 빌드 단계 오버헤드 | >10개 플러그인 + authoring 병목 |
| C29 | Skill-level hooks | Q9 미해결 | Claude Code 문서에서 SKILL.md hook 확인 |
| C37 | Retrospective | Three Laws의 core가 아님 | Phase 4 shipped |
| C38 | Host adapters | 범위 밖 | C21과 동일 |
| C39 | Runtime daemon | L 비용 | 사용자 예산 + runtime-verifier 불충분 |
| C40 | AI-slop blacklist | 미검증 (보고됨) | Main-thread cite 확보 |
| C47 | PAL Router | 다중 모델 필요 | C16과 동일 |
| C62 | Session historian | 크로스-플랫폼 | Phase 4 shipped + Claude-Code-only scoped |

## 거절 항목 (Killed Items)

| id | pattern | 사유 |
|---|---|---|
| C13 | *(original benchmark)* | R1에서 retired, C17로 대체됨 |
| C48 | Event-sourced state | markdown-state mandate와 영구적 충돌 |

---

## 페이즈 의존성 그래프 (Phase Dependency Graph)

```
Phase 0 ─── C57 required ──→ Phase 1
                                 │
                    ┌────────────┼────────────┐
                    ▼            │            ▼
                Phase 2         │        Phase 5
                    │           │      (parallel)
                    ▼           │
                Phase 3         │
                    │           │
                    ▼           │
                Phase 4         │
```

**병렬화:** Phase 5는 Phase 0 이후 어떤 것과도 병렬 가능. Phase 2a는 Phase 1d–1f와 병렬 시작 가능. Phase 3→4는 엄격 직렬. C52 분할: C52a는 Phase 1b, C52b는 Phase 2d.

---

## 미결 질문 (Open Questions)

### 해결됨 (Resolved)

| Q | 결정 | 근거 |
|---|---|---|
| Q1 | C2 = 에코시스템 전체 blanket | OMC의 agent별 방식은 일관성 부족 |
| Q2 | Learnings index = 플러그인별 `docs/learnings/` | 플러그인-로컬, grep-discoverable |
| Q8 | Fan-out via C31 + C33 + C42 삼위일체 | Scope gating + advisory tier |
| Q13 | `[NEVER_GATE]` for Security + Testing | 다른 것들은 0-finding run 후 gate |
| Q15 | PATH 1a 허용, `[from-code]` 표시 | 3개 소스 수렴; provenance가 trust 보존 |
| Q18 | git 버저닝으로 frozen spec | C48 killed |
| Q19 | C51은 Standard/Deep에서, Lightweight에서는 아님 | scope가 정당화할 때 사용 가능 |
| Q22 | 7개 core seed field; 3개 optional | 최소로 시작, 검증 후 확장 |
| Q23 | 4-level autofix | CE가 60+ 버전 shipping |
| Q24 | `mode:headless` 채택 | composition에 필수 |
| Q25 | C58은 Phase 2d에 번들 | 관련 workflow |
| Q30 | `.claude/<plugin>-<run-id>.local.md` | 마크다운 관례 |

### 이월됨 (Carried Forward)

| Q | 차단 대상 | 결정 이연 시점 |
|---|---|---|
| Q3 | Phase 3 | PreCompact 안정성; Stop-hook fallback |
| Q9 | C29 un-parking | Claude Code 문서 |
| Q17 | Phase 2a | 결정론적으로 시작, 측정 |
| Q21 | Phase 3 | point-in-time 먼저, continuous v0.2.0 |
| Q26 | Phase 2d | LLM 자동 평가 + override |
| Q27 | Phase 4c | devbrew에 맞게 차원 조정 |

---

## Metadata

- **Created:** 2026-04-16
- **Branch:** `feature/harness-philosophy`
- **Harvest source:** [`docs/research/plugin-harvest-rounds.md`](../research/plugin-harvest-rounds.md) (4 rounds, 69 candidates)
- **Philosophy anchor:** [`docs/philosophy/devbrew-harness-philosophy.md`](devbrew-harness-philosophy.md) (3 Laws, 23 principles, 17 anti-patterns)
