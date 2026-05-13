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
issue_history: []                    # 각 항목: {id, raised_count, dismissed_by_user, accepted_by_user, reconsensus_count, resolved, escalated}
pending_locked_decisions: []         # 매 round 끝 append (b/d path 명시 응답만). drafting-spec Mode A가 spec.md frontmatter로 변환.
reconsensus_accepted_ids: []         # reviewing-spec [3.5] sub-step이 기록. Mode B에 allowed_issue_ids로 전달.
under_revision: []                   # [3.5] sub-step "(3) 추가 인터뷰" 선택 시 LD ID 리스트. conducting-interview re-entry 시 focused interview 진행.
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

## Locked 판정 트리거 (G1, AC1)

매 round 끝에 사용자 응답을 `pending_locked_decisions`에 append할지 다음 decision table로 판정:

| 사용자 응답 유형 | path | locked? |
|---|---|---|
| 명시적 수락 (예/동의/선택지 1개 선택/자유 텍스트로 결정 명시) | b, d | ✅ true |
| 명시적 거절 (아니오/거절/대안 제시) | b, d | ✅ true (반대 명제로 locked) |
| 보류 ("잘 모르겠음", "둘 다 괜찮음", "나중에 결정") | b, d | ❌ false — Open Questions로 박제 |
| "추가 정보 필요" / "더 설명해주세요" | b, d | ❌ false — re-ask 또는 OQ |
| factual auto-confirm | a | ❌ false (사용자 미답변) |
| sub-agent ambiguity 답안 | c | ✅ true ONLY IF 사용자 confirm 받음 |

`locked? == true` 항목은 매 round 끝에 다음 형식으로 `pending_locked_decisions`에 append:

```yaml
- id: LD<N>                          # N = pending_locked_decisions.length + 1
  section: "#<spec-section-anchor>"  # 답변이 spec의 어느 섹션에 박힐지 (예: "#goals", "#acceptance-criteria")
  summary: "<160자 이내 한 줄 요약>"   # P21 secret placeholder 치환 적용
  source: interview-round-<N>        # 운영 경로 표시
  source_path: b | c | d             # 어느 routing path에서 왔는지
```

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

## In-flight state migration (C10)

state.local.md 로드 시 v0.1.x schema (신규 필드 부재)를 감지하면 *non-mutating read*로 자동 promote:

- `pending_locked_decisions` 부재 → `[]`로 in-memory default.
- `issue_history[].dismissed_by_user` / `accepted_by_user` / `reconsensus_count` 부재 → `0`으로 in-memory default.
- `reconsensus_accepted_ids` 부재 → `[]`로 in-memory default.
- `under_revision` 부재 → `[]`로 in-memory default.

다음 state write 시점에 frontmatter에 자연스럽게 추가 (backward-rewriting 금지 — 명시적 write 시점에만 frontmatter 갱신).

사용자에게 advisory 한 줄 출력:
```
[spec-distill v0.2.0] state.local.md schema migration: <fields> added with defaults.
```

자동 promote 실패 시 (파일 corruption 등) → 사용자에게 "v0.1.x in-flight state 호환 실패 — 세션 재시작 권장" 알림 + state.local.md 보존 (P14).

## kill switch

- `DEVBREW_DISABLE_SPEC_DISTILL=1`: 즉시 abort, state.local.md 보존 (실패 분석용).
- `DEVBREW_RHYTHM_GUARD_THRESHOLD=N`: rhythm guard threshold override.
- `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN=N`: wall-clock budget (default 30) — 초과 시 advisory metric에 기록.

## 다음 phase

`drafting-spec` skill 호출. 인터뷰 transcript와 결정된 정보를 input으로 넘김.
