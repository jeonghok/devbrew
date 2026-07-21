---
name: <kebab-topic>
type: interview-brief
created_at: YYYY-MM-DD
session_id: <uuid>
source: spec-distill conducting-interview v0.22.0
next_phase: superpowers:brainstorming
# locked_directions — (b)/(d) 명시 응답 + steelman 통과 방향. brainstorming 기정사실.
# 의심(R3) triggered 방향은 steelman ∈ {defended, switched-to-this} 여야 하며,
# Skepticism Log(§4)에 대응 항목이 있어야 한다. un-challenged 의심 방향은 금지.
locked_directions:
  - id: LD1
    statement: "<160자 이내, P21 secret placeholder>"
    source_path: a|b|c|d
    steelman: defended | switched-to-this | n/a
    defense: "<원안 방어 이유 — steelman: defended 인 경우 필수>"
---

# <Topic> — Interview Brief (meta-prompt for brainstorming)

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §9대로 brainstorming
> 해답공간으로 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다.

## 1. Reframed Problem

(메타 프롬프트 코어 — 받은 요청을 재구성한 한 문장 문제정의 + 진짜 goal.
 (d) ontological 5-type 중 무엇으로 도출했는지 명시.)

## 2. Locked Directions

(확정·검증된 방향. frontmatter locked_directions와 1:1. 재논쟁 금지.)

- **LD1**: ...

## 3. External Landscape

(prior-art / 경쟁 / 기존 해결책. **각 항목 출처 URL 필수** + [취함|피함|중립] + 이유.)

- ... — https://example.com — [취함] — 이유

## 4. Skepticism Log

(의심 triggered 방향별: steelman-builder가 구축한 대안 요지(verbatim) + 웹근거 URL
 + verdict ∈ {defended | switched | deferred}. conducting-interview는 약화·편집 금지(AC5).)

- 대안 statement (verbatim) — https://evidence.example — verdict: defended

## 5. Blind Spots & Premortem

(blind-spot-prober가 표면화한 hidden assumption + failure mode. 각 항목 근거 URL
 (web 부재 시 codebase 근거/사용자 판단, C5). 이 섹션은 blind_spot floor 차원의 기록처.)

- 숨은 가정: <가정> — 왜 위험: <이유> — https://evidence.example
- 실패 양식: <mode> — trigger: <조건> — https://evidence.example

## 6. Coverage Ledger

(커버리지 원장 직렬화 — floor 5행(전부 closed + evidence) + derived(≥1행 OR N/A sentinel).
 orchestrator가 state.local.md에서 직렬화. 종료 게이트가 이 섹션을 검증(AC2).)

- floor:root_problem — closed — <evidence>
- floor:landscape — closed — <evidence>
- floor:skepticism — closed — <evidence>
- floor:blind_spot — closed — <evidence>
- floor:open_questions — closed — <evidence>
- derived:<name> — closed — <rationale>; <evidence>

## 7. Tried & Discarded

(시행착오: 시도 → 버린 이유. 다운스트림 재탐색 차단.
 **시행착오 0건이면 `N/A — 전부 first-time defend+lock` 한 줄 명시**(빈 섹션 금지, R4 edge).)

- 시도한 방향 → 버린 이유

## 8. Open Questions

(미해결 명시. "유추 금지" — 해답공간으로 이월.)

- OQ1: ...

## 9. Concrete Next Action

(superpowers 있으면: 이 brief를 context로 `superpowers:brainstorming` 호출 → `-design.md`
 → reviewer 검증 → writing-plans. 없으면: 이 brief가 완결 산출물 — 직접 사용.)
