---
name: sample-topic
type: interview-brief
created_at: 2026-07-26
session_id: testsession01
source: spec-distill conducting-interview v0.23.0
next_phase: superpowers:brainstorming
audit_file: interview-brief-sec5-no-entries.audit.md
user_sourced_items:
  - id: C1
    source: verbatim
    status: confirmed
    statement: "대시보드는 SSR로 렌더한다"
    evidence: S1
  - id: D2
    source: chosen
    status: provisional
    statement: "캐시 계층은 인증 뷰까지 확장하지 않는다"
    evidence: S2
---

# Sample Topic — Interview Brief

## 0. 한눈에

TTFP를 줄이는 것이 진짜 목표다. SPA 전환은 수단이었지 목표가 아니었다.

## 1. Goal · Non-goal

- Goal: 대시보드 최초 페인트 시간 단축
- Non-goal: 전체 앱의 렌더링 전략 통일

## 2. 제약

이 절의 진술은 모델이 쓴 요약이다. 원문은 §6, `⟨S<N>⟩`가 그것을 가리킨다.

- 🗣 confirmed **C1** — 대시보드는 SSR로 렌더한다 ⟨S1⟩
- ☑ provisional **D2** — 캐시 계층은 인증 뷰까지 확장하지 않는다 ⟨S2⟩

✎ 렌더링 전략 선택이 이 토픽의 축으로 보인다 (모델 추론).

## 3. Open Questions

- OQ1: 인증 뷰의 캐시 전략 — 해답공간으로 이월.

## 4. External Landscape

- Next.js app-router SSR «nextjs-docs» — [취함] — 데이터 형태와 부합

## 5. 기각 · Blind Spots

## 6. 사용자 원문
- **S1** 🗣 최초 요청:
  > "대시보드가 너무 느려요. 서버에서 그려주면 안 되나요?"
## 7. Next Action

superpowers 있으면 이 brief를 context로 brainstorming 호출 → -design.md → reviewer → writing-plans.
