---
name: sample-topic
type: interview-brief
created_at: 2026-05-31
session_id: testsession01
source: spec-distill conducting-interview v0.22.0
next_phase: superpowers:brainstorming
locked_directions:
  - id: LD1
    statement: "use server-side rendering for the dashboard"
    source_path: b
    steelman: defended
    defense: "client hydration cost measured higher for this data shape"
---

# Sample Topic — Interview Brief (meta-prompt for brainstorming)

## 1. Reframed Problem

The real goal is reducing time-to-first-paint, not "make it a SPA" (ESSENCE).

## 2. Locked Directions

- **LD1**: use server-side rendering for the dashboard.

## 3. External Landscape

- Next.js app-router SSR — https://nextjs.org/docs/app — [취함] — matches data shape

## 4. Skepticism Log

- Alternative: islands architecture could beat full SSR here — https://jasonformat.com/islands-architecture/ — verdict: defended

## 5. Blind Spots & Premortem

- 숨은 가정: SSR host가 항상 저지연 — 왜 위험: cold start 시 TTFP 역전 — https://vercel.com/docs/functions/serverless-functions

## 6. Coverage Ledger

- floor:root_problem — closed — §1 Reframed Problem (ROOT_CAUSE)
- floor:landscape — closed — §3 Next.js SSR 인용
- floor:skepticism — closed — §4 islands steelman defended
- floor:blind_spot — closed — §5 cold-start premortem
- floor:open_questions — closed — §8 caching OQ1

## 7. Tried & Discarded

- Tried full client SPA → discarded: TTFP regression on cold load.

## 8. Open Questions

- OQ1: caching layer for authenticated views — deferred to solution space.

## 9. Concrete Next Action

superpowers 있으면 이 brief를 context로 brainstorming 호출 → -design.md → reviewer → writing-plans.
