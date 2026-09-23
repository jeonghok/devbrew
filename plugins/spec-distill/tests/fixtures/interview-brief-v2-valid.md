---
name: sample-topic-v2
type: interview-brief
created_at: 2026-09-23
session_id: testsessionv2
source: spec-distill conducting-interview 3.3.0
next_phase: superpowers:brainstorming
contract: v2
audit_file: interview-brief-v2-valid.audit.md
user_sourced_items:
  - id: C1
    source: verbatim
    status: confirmed
    statement: "대시보드는 SSR로 렌더한다"
    evidence: S1
---

# Sample Topic v2 — Interview Brief

## 0. 한눈에

TTFP를 줄이는 것이 진짜 목표다.

- OQ1 [열림] — 인증 뷰의 캐시 전략 → 근거 RC3
- OQ4 [해결 ⟨S1⟩] — 렌더링 전략 → 근거 RC3

## 1. Goal · Non-goal

- Goal: 대시보드 최초 페인트 시간 단축
- Non-goal: 전체 앱의 렌더링 전략 통일

## 2. 제약

- 🗣 confirmed **C1** — 대시보드는 SSR로 렌더한다 ⟨S1⟩

## 3. Open Questions

- OQ1: 인증 뷰의 캐시 전략 → 근거 RC3

## 4. External Landscape

- Next.js app-router SSR «nextjs-docs» — [취함] — 데이터 형태와 부합 [→ OQ1]
- 부분 하이드레이션 «islands» — [중립] — 이 결정과 무관 [→ 없음]

## 5. 기각 · Blind Spots

- 기각 — N/A — 전부 first-time defend+lock
- 검토 — steelman 0건: 검토한 방향 1개 · 전제 P1 · trigger 후보 landscape 모순 → 기각 이유 모순 없음
- 위험 — 숨은 가정 | 캐시 계층이 인증 뷰를 이미 다룬다 — RC3 [RC3 → OQ1 · OQ4]

## 6. 사용자 원문
- **S1** 🗣 최초 요청:
  > "대시보드가 너무 느려요."
## 7. Next Action

이 brief를 context로 brainstorming 호출.
