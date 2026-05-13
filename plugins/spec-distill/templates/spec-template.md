---
name: <kebab-case-topic>
version: 1.0.0
created_at: YYYY-MM-DD
session_id: <uuid>
status: locked
next_phase: writing-plans
source: spec-distill v0.1.0
# Locked decisions — interview (b)/(d) path 사용자 명시 응답에서 도출.
# drafting-spec Mode A가 채움. Mode B는 superseded_by/supersedes 마커로 변경 이력 박제.
# source 허용값: interview-round-<N> (정상 운영) 또는 brainstorming-round-<N> (meta-spec dogfooding).
locked_decisions: []
---

# <Topic title>

## Goal

(One sentence — testable outcome.)

## Context / Why

(Why now, what problem, who asked, what's at stake.)

## Goals

- **G1**: ...
- **G2**: ...

## Non-goals

- **NG1**: ...

## Constraints

- **C1**: ...

## Acceptance Criteria

- **AC1**: (testable, measurable)
- **AC2**: ...

## Files to Modify

```
(exact paths to create/modify, with one-line responsibility per file)
```

## Verification Plan

- **V1**: (manual or automated check, with exact command)
- **V2**: ...

## Rejected Alternatives

- **R1 — <name>**: <reason rejected>

## Open Questions

- **OQ1**: ... (TBD if not resolved by spec time)
- (Or "None" if all resolved)

## Concrete Next Action

다음 단계: `<next skill or command>`.
- Spec 경로: `<this file path>`
- Plan 산출물: `docs/superpowers/plans/<date>-<topic>.md`
- 명령: `<exact command to invoke next phase>`
