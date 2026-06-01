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
    defense: "user judgment — web disabled this session"
---

# Sample Topic — Interview Brief (meta-prompt for brainstorming)

## 1. Reframed Problem

The real goal is reducing time-to-first-paint (ESSENCE).

## 2. Locked Directions

- **LD1**: use server-side rendering for the dashboard.

## 3. External Landscape

web 비활성 — landscape 생략, codebase 근거만 사용.

## 4. Skepticism Log

- Alternative: a static-export build could avoid SSR infra — verdict: defended (web 비활성, 사용자 판단 근거, URL 부재)

## 5. Tried & Discarded

- N/A — 전부 first-time defend+lock

## 6. Open Questions

- OQ1: caching layer — deferred.

## 7. Concrete Next Action

brainstorming 호출.
