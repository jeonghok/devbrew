---
name: sample-topic
type: interview-brief
created_at: 2026-05-31
session_id: testsession01
source: spec-distill conducting-interview v0.12.0
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

- islands architecture is popular these days

## 4. Skepticism Log

- Alternative: islands architecture could beat full SSR here — https://jasonformat.com/islands-architecture/ — verdict: defended

## 5. Tried & Discarded

- Tried full client SPA → discarded: TTFP regression on cold load.

## 6. Open Questions

- OQ1: caching layer for authenticated views — deferred to solution space.

## 7. Concrete Next Action

superpowers 있으면 이 brief를 context로 brainstorming 호출 → -design.md → reviewer → writing-plans.
