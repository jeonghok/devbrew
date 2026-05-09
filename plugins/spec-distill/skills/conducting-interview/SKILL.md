---
name: conducting-interview
description: >
  Use this skill to run the spec-distill 4-block Korean Socratic interview.
  Called by /interview command after trivia escape check passes. Implements
  C43 4-path routing (factual auto-confirm / judgment→user / ambiguity→sub-agent /
  ontological→5-type), C44 Dialectic Rhythm Guard, C45 breadth-keeper dispatch
  (max 1 per round, AC13). Persists state to .claude/spec-distill/<session-id>/state.local.md.
cost_class: medium
---

# Conducting Interview (Phase 1)

당신은 spec-distill의 인터뷰 phase를 진행 중입니다. 사용자의 모호한 요청을 명확한 spec으로 변환하기 위해 4-block Korean Socratic format으로 round를 진행합니다.

## State location (AC2)

`.claude/spec-distill/<session-id>/state.local.md` (per-session 격리, devbrew §4.8 준수)

State frontmatter schema:

```yaml
---
session_id: <uuid>
phase: 1
interview_round: <int>
non_user_streak: <int>
rereview_count: 0
wall_clock_started_at: <ISO8601>
trivia_escape_armed: false
issue_history: []
---
```

State body: 각 round의 4-block 출력 + 사용자 답변 + (있다면) breadth-keeper 출력 transcript.

**Secret 기록 금지** (P21): 사용자 답변에 token/key/credential 패턴 감지 시 placeholder로 치환 후 기록.

## 4-block Korean format (devbrother2024 deep-interview 흡수, AC1)

매 round마다 다음 4 block을 출력하십시오:

```markdown
**현재 이해:**
(지금까지 인터뷰로 파악한 사용자 요청의 *현재 이해*를 한두 문장으로 요약. 1라운드는 사용자 prompt에서 추출.)

**막힌 결정:**
(가장 큰 단일 불확실성 — goal/scope/constraints/AC 중 가장 모호한 한 가지를 명시.)

**추천 답안:**
(막힌 결정에 대한 *내 추천 답*. 사용자가 No만 골라도 진행 가능하게.)

**질문:**
(한 번에 하나의 질문. 다지선다 형태 권장. open-ended는 신중히.)
```

## C43 4-path routing

질문을 만들 때 다음 4 경로 중 하나로 분류해서 routing 하십시오:

| Path | When | Action |
|---|---|---|
| (a) **factual** | 답이 codebase/git history에 있는 경우 | grep/Read로 *auto-confirm*, 사용자에게 묻지 않음. transcript에 `[from-code][auto-confirmed]` 마커 표시. |
| (b) **judgment** | 사용자 선호/우선순위/제약 | 사용자에게 묻기 (default path). 4-block 출력. |
| (c) **ambiguity** | 여러 해석 가능한 핵심 가정 | sub-agent에 adversarial draft 요청 (`general-purpose` agent에 "이 가정이 잘못됐다면 어떤 시나리오가 가능한가?" 형태로 dispatch). 답을 그대로 사용자에게 보여주고 confirm. |
| (d) **ontological** | "이게 무엇인가" 종류 (essence/root cause 등) | C51 5-type framework 사용 — ESSENCE / ROOT_CAUSE / PREREQUISITES / HIDDEN_ASSUMPTIONS / EXISTING_CONTEXT 중 하나로 라벨링 후 사용자에게 묻기. |

매 round의 4-block에서 어떤 path로 routing했는지 transcript에 명시하십시오.

## C44 Dialectic Rhythm Guard

`non_user_streak` 카운터 — 직전 N round 동안 *사용자 답변이 없었던* 횟수.

- (a) factual auto-confirm: streak +1
- (c) sub-agent adversarial: streak +1
- (b) 사용자 답변 받음: streak = 0
- (d) ontological 사용자 답변 받음: streak = 0

`non_user_streak >= DEVBREW_RHYTHM_GUARD_THRESHOLD` (default 3) 도달 시:

→ 다음 round의 질문은 **반드시 (b) judgment path** (사용자에게 직접 질문)로 라우팅. 강제.

## breadth-keeper dispatch (C45, AC13)

매 round 끝에 다음 조건 모두 만족하면 `breadth-keeper` agent를 1회 dispatch:

1. `interview_round >= 2` (첫 round는 탐색기 — skip)
2. 직전 3 round가 같은 dimension(같은 spec 섹션)에 집중함
3. 이번 round에서 dispatch 안 한 경우 (round당 max 1, AC13)

dispatch 결과 (`narrow_tunneling: true`) 면 다음 round 시작 시 `suggested_lateral_questions` 중 하나를 추천 답안으로 제시.

## 종료 조건

다음을 모두 만족하면 phase 1 종료, drafting-spec skill로 전환:

- Goal 명확 (한 문장으로 표현 가능)
- Goals/Non-goals 일관 (충돌 없음)
- Constraints 명시
- Acceptance Criteria 측정 가능 형태로 도출
- Open Questions 사용자 인지 (불명확한 것은 OQ로 박제)

종료 시 다음 메시지 출력:

> 인터뷰 phase 종료 조건 충족. `drafting-spec` skill로 전환합니다.

## kill switch

- `DEVBREW_DISABLE_SPEC_DISTILL=1`: 즉시 abort, state.local.md 보존 (실패 분석용).
- `DEVBREW_RHYTHM_GUARD_THRESHOLD=N`: rhythm guard threshold override.
- `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN=N`: wall-clock budget (default 30) — 초과 시 advisory metric에 기록.

## 다음 phase

`drafting-spec` skill 호출. 인터뷰 transcript와 결정된 정보를 input으로 넘김.
