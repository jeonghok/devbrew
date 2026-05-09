---
name: spec-distill-design
version: 1.0.0
created_at: 2026-05-09
session_id: brainstorm-2026-05-09
status: locked
next_phase: writing-plans
source: superpowers/brainstorming + devbrew dogfooding
---

# spec-distill — 디자인 스펙 (v0.1.0)

> **For agentic workers:** 이 문서는 spec-distill 플러그인의 v0.1.0 설계 명세이다. 다음 단계는 superpowers `writing-plans` skill로 implementation plan을 생성하는 것이다.

## Goal

집요한 인터뷰로 모호함을 명확함으로 변환해 superpowers 호환 `spec.md`를 생성하는 devbrew-native 플러그인을 v0.1.0으로 ship한다 — interview → spec phase까지.

## Context / Why

devbrew CLAUDE.md 첫 motto가 *"Specify before you code"*이고 Law 1이 *"Clarity Before Code"*임에도, devbrew marketplace에는 **spec authoring을 일급 단계로 다루는 native 플러그인이 없다**. 사용자는 외부 cache의 superpowers/brainstorming에 의존하거나, 매번 ad-hoc로 spec을 작성한다. 이는 다음 4개 gap을 만든다:

1. **Cache 의존**: `claude-plugins-official` cache가 unavailable이면 brainstorming 사용 불가.
2. **devbrew 철학 instantiation 부재**: superpowers/brainstorming은 *self-review*만 하고 sub-agent reviewer를 분리하지 않음 — devbrew Law 2 (Writer/Reviewer 분리) 미충족.
3. **인터뷰 메커니즘 약함**: brainstorming은 "한 번에 한 질문"만 강제하고 4-path Socratic routing, Dialectic Rhythm Guard, breadth-keeper 같은 ouroboros/OMC 메커니즘이 없음.
4. **유추 차단 부재**: 짧거나 모호한 prompt에 대해 인터뷰 진입을 권장하는 메커니즘이 없어, agent가 사용자 의도를 *유추*하고 진행 (사용자 #3 "유추 금지" 위반 가능성).

`spec-distill`은 위 4개 gap을 메우는 brainstorming **drop-in 대체** 플러그인이다. 산출물 위치/형식을 superpowers와 호환시켜 다음 단계(writing-plans → executing-plans)는 그대로 superpowers를 사용한다.

## Goals

- **G1 — Drop-in 대체**: superpowers/brainstorming 산출물 위치(`docs/superpowers/specs/`) 사용 + frontmatter/body 형식이 superpowers `writing-plans` input과 호환. 파일명 suffix는 `YYYY-MM-DD-<topic>-spec.md` (brainstorming의 `-design.md`와 구분 — 출처 추적성, writing-plans는 파일명 강제 안 함).
- **G2 — 4-block Korean Socratic 인터뷰**: devbrother2024 deep-interview 형식 채택 (현재 이해 / 막힌 결정 / 추천 답안 / 질문).
- **G3 — Writer/Reviewer 물리적 분리 (Law 2)**: `disallowedTools: Write, Edit, MultiEdit, NotebookEdit` frontmatter로 `spec-reviewer` + `breadth-keeper` agent 격리. 프롬프트 의존이 아닌 frontmatter scoping.
- **G4 — Loop-aware 흐름 (Phase 0–5, back-edges)**: 일부 자동 routing + 일부 user confirm gate. P17 사용자 주권 + AP16 unbounded autonomy 회피.
- **G5 — Stagnation/Trivia/Wall-clock guards**: devbrew Forbidden Patterns 회피 + 측정 가능한 advisory metric.
- **G6 — devbrew CLAUDE.md "첫 플러그인 체크리스트" 충족**: `plugin.json`(name/version/description), README "Principles Instantiated", 모든 skill `cost_class` 선언, 모든 agent `disallowedTools` 명시, 모든 hook kill switch.

## Non-goals

- **NG1**: `spec → plan` phase는 이번 PR scope 아님 (v0.2.0). v0.1.0은 `interview → spec`까지만.
- **NG2**: implementation phase hook (`drift-monitor`, `keyword-detector` PostToolUse) 도입 안 함. spec phase에 집중 (사용자 결정).
- **NG3**: Numerical ambiguity gate (`Ambiguity ≤ 0.2` 등) 도입 안 함 — devbrew §5.3 비추천.
- **NG4**: CCG 3-model decomposition 도입 안 함 — P11은 high-stakes만.
- **NG5**: PreCompact hook 도입 안 함 — OMC sub-agent advice ("interview는 single-turn"). v0.3.0+ 검토.
- **NG6**: 외부 superpowers wrapping 안 함 — self-contained, cache 독립.
- **NG7**: Cross-session 인터뷰 resume 자동화 안 함. SessionStart anchor advisory만 제공.
- **NG8**: 한국어 외 다른 언어 인터뷰 형식 미지원 — devbrew Korean primary 정책.

## Constraints

- **C1**: devbrew Three Laws 준수 (CLAUDE.md). Law N은 충돌 시 Law N+1 override.
- **C2**: devbrew Plugin Shape 준수 — `plugin.json` 필수, agent `allowedTools`/`disallowedTools` 명시, skill `cost_class` 선언, hook kill switch.
- **C3**: state는 마크다운 (`.claude/spec-distill/<session-id>/state.local.md`), JSON 아님.
- **C4**: 사용자 답변에 secret(token, key, credential) 포함 시 placeholder 치환 (P21).
- **C5**: 모든 hook/agent/skill에 kill switch 또는 noop fallback. `DEVBREW_DISABLE_SPEC_DISTILL=1` 존중 거부 불가.
- **C6**: superpowers `writing-plans` input 형식과 호환 (drop-in 대체).
- **C7**: Korean primary — 한국어 인터뷰 + 한국어 spec body 가능. 영어는 식별자/고유명사/원문 인용/번역 어색한 기술 용어에 한정.
- **C8**: v0.1.0 — `CHANGELOG.md` 미생성 (devbrew 규약: v1.0.0 이상이면 필수).

## Acceptance Criteria

- **AC1**: `/interview <rough request>` 또는 `/interview` 호출 시 `conducting-interview` skill이 4-block Korean format ("현재 이해 / 막힌 결정 / 추천 답안 / 질문")으로 첫 round 진행.
- **AC2**: 인터뷰 transcript가 `.claude/spec-distill/<session-id>/state.local.md`에 frontmatter (phase, interview_round, non_user_streak, rereview_count, issue_history, wall_clock_started_at, trivia_escape_armed) + body로 실시간 보존.
- **AC3**: `spec.md`가 `docs/superpowers/specs/YYYY-MM-DD-<topic>-spec.md` 위치에 11 필수 섹션 (Goal / Context / Goals / Non-goals / Constraints / Acceptance Criteria / Files to Modify / Verification Plan / Rejected Alternatives / Open Questions / Concrete Next Action) + frontmatter (name, version, created_at, session_id, status, next_phase, source)로 작성됨.
- **AC4**: `spec-reviewer` agent가 `disallowedTools: Write, Edit, MultiEdit, NotebookEdit`로 dispatch되어 Write/Edit 도구 호출 시도 시 *실제 InputValidationError 발생* (단순 프롬프트 강제 X).
- **AC5**: `spec-reviewer` 출력 형식이 superpowers `plan-document-reviewer-prompt.md`와 호환 — `Status: approved | needs_revise | needs_interview` + `Issues: [{id, category, section, message, raised_count}]` + `Recommendations: [...]` + `Stagnation_signal: bool`.
- **AC6**: Re-review 사이클 (`[3]↔[4]`) 4회째 진입 시 자동으로 `[5] Human Gate`로 forced escalate, 전체 issue history 첨부.
- **AC7**: 같은 issue ID `raised_count ≥ 3 unresolved` 도달 시 `Stagnation_signal: true` + `[5]` forced escalate (P18).
- **AC8**: `DEVBREW_DISABLE_SPEC_DISTILL=1` 설정 시 모든 hook + skill abort, `state.local.md` 보존.
- **AC9**: `DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit` 설정 시 해당 hook만 skip, 나머지 정상 작동.
- **AC10**: trivia 패턴 5종 (typo / 주석-only / 단일 파일 formatting / 단일 변수 rename / `<10` 토큰 + 단일 action 동사) 감지 시 `/interview` first-step에서 사용자 confirm 없이는 인터뷰 진입 안 함 (AP4 회피).
- **AC11**: `[5]` approve 시 4-step sequence 모두 실행 — `git add` + commit, handoff pointer 출력 (다음 단계: superpowers `writing-plans`), `.claude/spec-distill/<session-id>/` 디렉토리 rmtree, plugin 종료. polite stop (narrate-only) 없음 (AP2 회피).
- **AC12**: README.md "Principles Instantiated" 섹션이 Laws 1–3 + 8 P-numbers (P2/P5/P12/P14/P17/P18/P21/P22) + 4 C-numbers (C43/C44/C45/C51) + 7 AP-numbers (AP1/AP2/AP4/AP9/AP14/AP16/AP17 회피) 명시 cite.
- **AC13**: `breadth-keeper` agent가 인터뷰 round당 최대 1회만 invoke됨 (AP9 subagent spray 회피). 출력은 `{ narrow_tunneling: bool, suggested_lateral_questions: [...] }`.
- **AC14**: Wall-clock budget — `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN` env (default 30) 초과 시 `[5]` forced escalate.
- **AC15**: `reviewing-spec` SKILL.md에 verdict × signal → next phase routing이 deterministic table로 명시 (prose 아님).

## Files to Modify

**새로 생성** (이번 PR):

```
plugins/spec-distill/
├── .claude-plugin/
│   └── plugin.json                         # name, description, version: 0.1.0
├── README.md                               # "Principles Instantiated" 섹션 필수
├── commands/
│   └── interview.md                        # /interview, trivia escape rule
├── skills/
│   ├── conducting-interview/SKILL.md       # cost_class: medium
│   ├── drafting-spec/SKILL.md              # cost_class: low
│   └── reviewing-spec/SKILL.md             # cost_class: medium, routing table
├── agents/
│   ├── breadth-keeper.md                   # disallowedTools 명시
│   └── spec-reviewer.md                    # disallowedTools, output 형식
├── hooks/
│   ├── interview-trigger.sh                # UserPromptSubmit + kill switch
│   └── session-anchor.sh                   # SessionStart + kill switch
└── templates/
    └── spec-template.md                    # 11 섹션 + frontmatter 템플릿
```

**수정**:
- `.claude-plugin/marketplace.json` (devbrew root, existing) — `spec-distill` plugin 등록.

**미생성**:
- `plugins/spec-distill/CHANGELOG.md` — v0.1.0이라 미생성 (P23 — v1.0.0 이상에만 의무).

**미수정**:
- 다른 plugin (`quality-gates`, `project-init`, `feature-dev` 등) 영향 없음.

## Verification Plan

- **V1 (수동 — happy path)**: `/interview "todo 앱 만들어줘"` 호출 → 4-block 첫 round가 한국어로 출력 → 인터뷰 진행 → spec.md 11 섹션 + frontmatter 모두 채워짐 → Phase 5 approve → spec.md commit + state cleanup 확인.
- **V2 (수동 — state 보존)**: 인터뷰 진행 중간에 새 터미널 → `cat .claude/spec-distill/<session-id>/state.local.md` → frontmatter (phase, interview_round, non_user_streak, rereview_count, issue_history) + transcript body 모두 존재 확인.
- **V3 (구조 검증)**: `spec-reviewer` agent dispatch → 같은 conversation 안에서 Write 도구 호출 시도 → 실제 `InputValidationError` 발생 확인 (프롬프트 거부 아닌 frontmatter 차단).
- **V4 (수동 — reject path)**: 빈 ACs 또는 "TBD" 포함된 spec 입력 → `spec-reviewer`가 `Status: needs_revise` + 해당 issue (id, category, section, message) 반환 확인.
- **V5 (수동 — stagnation)**: 같은 issue를 3 라운드 unresolved 유지 → `Stagnation_signal: true` + `[5]` forced escalate 확인 + 전체 issue history 표시 확인.
- **V6 (수동 — re-review cap)**: 4번째 re-review 시도 → 자동 `[5]` escalate 확인.
- **V7 (수동 — kill switch plugin-wide)**: `DEVBREW_DISABLE_SPEC_DISTILL=1` export 후 `/interview` 호출 → abort 확인 + state.local.md 보존 확인.
- **V8 (수동 — kill switch hook-specific)**: `DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit` export → 짧은 prompt 입력해도 권장 신호 없음 확인. 나머지 (`/interview` 명시 호출) 정상 작동 확인.
- **V9 (수동 — trivia escape)**: `/interview "fix typo in line 3"` → 인터뷰 진입 안 하고 사용자 confirm 요청 메시지 출력 확인.
- **V10 (수동 — approve handoff)**: Phase 5 approve → `git log` 확인 (spec.md commit) + handoff pointer 출력 (`다음 단계: superpowers writing-plans`) + `.claude/spec-distill/<session-id>/` 디렉토리 삭제 확인.
- **V11 (구조 검증)**: `grep -E "Law [123]|P(2|5|12|14|17|18|21|22)|C(43|44|45|51)|AP(1|2|4|9|14|16|17)"` README.md → 모든 cite 존재 확인.
- **V12 (구조 검증)**: `grep -E "cost_class:" plugins/spec-distill/skills/*/SKILL.md` → 모든 skill에 cost_class 선언 확인.
- **V13 (구조 검증)**: `grep -E "disallowedTools:" plugins/spec-distill/agents/*.md` → `Write`, `Edit`, `MultiEdit`, `NotebookEdit` 모두 차단 확인.
- **V14 (구조 검증)**: `bash plugins/spec-distill/hooks/interview-trigger.sh` (with `DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit`) → exit 0 + no signal 출력 확인.
- **V15 (수동 — wall-clock)**: `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN=1` 설정 + 인터뷰 1분 이상 진행 → wall-clock advisory metric 표시 + 자동 `[5]` escalate 확인.

## Rejected Alternatives

- **R1 — superpowers/brainstorming wrapper 방식**: cache 의존 + devbrew 철학 instantiation 약화 + 사용자 의도("여러 skill+hook 조합")와 어긋남. 거부.
- **R2 — Single-stream interview (spec/plan 동시 성장)**: spec lock 시점 모호 → P5 (named/versioned/diff-able)를 약하게 만족. 인터뷰 메커니즘이 self-policed (사용자 의지 의존). 거부.
- **R3 — Numerical ambiguity gate (Ouroboros 핵심)**: devbrew §5.3 *허용하지만 권장하지 않음* (같은 LLM 생성/채점 brittle, reproducibility ≠ correctness, Ouroboros 자신의 약점). 사용자도 "조금 딥한데"라며 거부. **거부.**
- **R4 — 1 skill + 1 agent 극단 simplification (reviewer steelman position)**: 사용자 의도(여러 skill+hook 조합)와 충돌. Law 2 분리도 약화 (writer/reviewer 한 skill에 흡수되면 분리가 문서적). 거부.
- **R5 — Steelman critic v0.1.0 도입 (이전 final 디자인)**: P11 high-stakes only. spec interview는 reversible. plan-reviewer PR(v0.2.0)로 defer 결정. 단 v0.2.0+에서 spec phase 회귀 도입 예정 (사용자 결정).
- **R6 — User-driven routing 전체 (v2 변형)**: 매 review마다 사용자 마찰 큼. 사용자가 v2 거절, v1 (auto routing 일부 + user confirm 일부) 채택.
- **R7 — PreCompact hook v0.1.0 도입**: OMC sub-agent advice ("interview는 single-turn이 일반"). v0.3.0+ 사용 패턴 확인 후 재검토.
- **R8 — Phase 0–4 renumber (Phase 4 자리 안 비움)**: Phase 4 자리를 비워두면 plan-reviewer PR에서 자연스럽게 `[4] Steelman` 도입 가능. 0–5 유지.
- **R9 — Hook 3개 (UserPromptSubmit + SessionStart + PreCompact)**: Hook bloat 회피. PreCompact는 v0.3.0+로.
- **R10 — Plugin 이름 후보들 (`clarity-first` / `pre-flight` / `spec-brew` / `socratic-spec` / `probe-spec` / `interview`)**: 사용자가 `spec-distill` 선택 — 본질(증류 metaphor) 표현 + devbrew compound 패턴 부합 + hand-off 색채 없음.

## Open Questions

다음 PR(v0.2.0+)에서 결정될 사항. v0.1.0 implementation에 영향 없음.

- **OQ1**: `reviewing-spec` skill을 phase-aware (spec+plan 단일)로 일반화 vs phase별 별도 skill — **사용자 결정: phase별 분리**. v0.2.0에서 `reviewing-plan`을 별도 skill로 추가.
- **OQ2**: `steelman-critic`을 v0.2.0 plan phase에만 도입 vs spec phase 회귀 도입 — **사용자 결정: spec phase 회귀 도입**. v0.2.0에서 spec/plan 양쪽 모두 도입.
- **OQ3**: Cross-session 인터뷰 resume의 `PreCompact` hook 도입 시점 — TBD (v0.3.0+ 사용자 패턴 측정 후).
- **OQ4**: Auto-apply trivial revise 토글 — TBD (v0.4.0+ 마찰 측정 후).

## Concrete Next Action

다음 단계: superpowers `writing-plans` skill 호출.

- **Spec 경로**: `docs/superpowers/specs/2026-05-09-spec-distill-design.md` (이 문서)
- **Plan 산출물**: `docs/superpowers/plans/2026-05-09-spec-distill.md`
- **명령** (현재 세션 내): `Skill superpowers:writing-plans`

`writing-plans` skill이 위 spec을 input으로 받아 v0.1.0 implementation plan (bite-sized task, TDD steps, exact file paths, exact code blocks)을 생성한다. Plan은 `docs/superpowers/plans/`에 commit되며, 그 다음 단계는 `superpowers:subagent-driven-development` 또는 `superpowers:executing-plans`로 implementation에 진입한다.
