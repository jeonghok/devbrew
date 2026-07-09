# devbrew 수확 후 로드맵 (Post-Harvest Roadmap)

> **Research is done. This is the build sequence.**
> *리서치는 끝났다. 이제 빌드 순서다.*
>
> *6개 페이즈로 증류. 각 페이즈에 후보·페이즈 내 빌드 순서·버전 번호. 플러그인별 스펙은 해당 페이즈 시작 시점에 작성 — 그 전이 아님.*

이 문서는 리서치 ([`plugin-harvest-rounds.md`](../research/plugin-harvest-rounds.md))와 실행 사이의 다리입니다. 후보 패턴을 단계적 빌드 순서로 변환합니다. 각 후보는 ID로만 참조하며 전체 분석은 수확 파일에 있습니다.

**수확된 소스:** oh-my-claudecode v4.9.1 (R1), gstack (R2), ouroboros v0.28.7 (R3), compound-engineering v2.66.1 (R4).

## How to Read This Document

- 각 **페이즈** 섹션 = 범위 + 후보 + 페이즈 내 빌드 순서. 플러그인별 스펙은 페이즈 시작 시점에 작성.
- 후보는 **ID로만** 참조 (예: "C2 — physical tool scoping"). 전체 분석은 [수확 파일](../research/plugin-harvest-rounds.md)에 있음.
- **우선순위 rubric** (수확에서 유래): `(laws_covered × gap_severity × round_reinforcement) / build_cost`.

---

## Phase 0 — Convention Sweep

문서, README, 프롬프트 변경만. 새 플러그인 코드 없음. 단일 PR. 출시: quality-gates v1.4.1, project-init v1.1.1.

**후보:** C10, C11, C12, C14, C22, C27, C28, C41, C50, C57, C59, C64, C66, C67.

**레트로핏 항목:** 양쪽 플러그인의 CHANGELOG.md, "Principles Instantiated" README 섹션, quality-pipeline skill과 runtime-verifier agent의 `cost_class` 선언, SKILL.md frontmatter 스키마 스펙.

**핵심 산출물 — C57 (review mode detection):** Phase 1a의 필수 선행 조건. 네 가지 모드: `headless` / `autofix` / `report-only` / `interactive`. 감지 로직은 Phase 1 시작 전에 문서화 완료 필수.

**조정 원칙** (R2 "Boil the Lake" vs P8): *"Tests boil the lake; production code deletes ruthlessly."*

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

---

## 페이즈 3 — 상태 영속성 + Drift 라이브러리 (State Persistence + Drift Libraries)

**점수:** 3.0. **비용:** M. **출시:** 공유 라이브러리 모듈.

**후보 (3개):** C5, C54, C65.

- C5: PreCompact 상태 스냅샷. 마크다운: `.claude/<plugin>.local.md`. PreCompact가 불안정할 경우 Stop-hook으로 fallback.
- C54: Drift 측정. 3축 가중 Jaccard (Goal 0.5, Constraint 0.3, Ontology 0.2). Threshold ≤ 0.3. point-in-time으로 시작; v0.2.0에서 continuous 추가.
- C65: Per-run artifact를 `.claude/<plugin>-<run-id>.local.md`로. 마크다운, 디렉토리가 아님.

---

## Phase 4 — compounding-learnings Plugin

**점수:** 2.25. **법칙:** 3. **비용:** M. **출시:** `plugins/compounding-learnings/` v0.1.0. Phase 3에 의존.

**후보 (5개):** C3, C4, C25, C61, C69.

**4a — 코어** (첫 compound 사이클):
- C3: 3-point gate가 있는 Learner skill (non-Googleable / context-specific / hard-won).
- C4: Wiki/index triad (기록 → SessionStart가 읽음 → PreCompact가 영속).
- C25: Dual-lifetime 태그 (7일 / 영구). 크로스-프로젝트에는 `trusted: false`.

> **참고 (2026-05-06):** Phase 4a 후보 C3+C4+C25+C69는 이제 철학 §4.6 Compounding Skill primitive의 first-class 운영 내용 (philosophy.md §4.6 + Law 3 corollary 참조).

**4b — 읽기 측:** C69. Grep-first 7-step 검색. 수락 기준: recall >85%, precision >80%.

**4c — 쓰기 측:** C61. 5차원 중복 검출 (problem, root cause, solution, files, prevention). High (4-5) → 업데이트. Moderate (2-3) → 생성 + flag. Low (0-1) → 생성.

---

## 페이즈 5 — project-init 강화 (Enhancements)

**비용:** S. **출시:** project-init v1.2.0. 독립적 — Phase 0 이후 Phase 2–4와 병렬 가능.

**후보 (1개):** C15. Commit-trailer 스키마: `Constraint:`, `Rejected:`, `Directive:`, `Confidence:`, `Scope-risk:`, `Not-tested:`. Trivia escape: 한 문장 diff에는 skip.
