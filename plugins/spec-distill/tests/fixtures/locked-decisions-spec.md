---
name: fixture-locked-decisions
version: 1.0.0
created_at: 2026-05-13
session_id: fixture-locked-001
status: locked
next_phase: writing-plans
source: spec-distill v0.2.0
locked_decisions:
  - id: LD1
    section: "#goals"
    summary: "G2 = onboarding은 in-scope"
    source: interview-round-1
    source_path: b
  - id: LD2
    section: "#acceptance-criteria"
    summary: "AC3 — 테스트 30초 이내"
    source: interview-round-2
    source_path: b
---

# Fixture spec — locked decisions

## Goal

Todo 앱 — onboarding 포함, 30초 이내 테스트.

## Goals

- G1: 기본 CRUD.
- G2: 신규 사용자 onboarding (LD1).

## Acceptance Criteria

- AC1: CRUD 동작.
- AC3: 통합 테스트 < 30s (LD2).

(... 다른 섹션 생략 — fixture 목적상 필요한 frontmatter + LD-매칭 가능 섹션만 ...)
