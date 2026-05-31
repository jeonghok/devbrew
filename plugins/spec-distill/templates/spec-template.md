---
name: <kebab-case-topic>
version: 1.0.0
created_at: YYYY-MM-DD
session_id: <uuid>
status: locked
next_phase: writing-plans
source: spec-distill v0.2.0
# Locked decisions — interview (b)/(d) path 사용자 명시 응답에서 도출.
# (v0.12.0: drafting-spec 제거 — spec.md를 수동 작성/검토할 때 이 형식 사용. 이 템플릿은 hook의 spec-mode 검증 대상 형식.)
# source 허용값: interview-round-<N> 또는 brainstorming-round-<N>.
locked_decisions: []
---

# <Topic title>

## Goal

(One sentence — testable outcome.)

## Handoff Context

> 이 spec을 처음 보는 사람(또는 /compact 후 자기 자신)이 30초에 핵심 파악할 수 있게.
> 대화 컨텍스트를 가정하지 말 것 — 모든 사실은 spec 본문에 self-contained.

**TL;DR** (1–2 sentences — 무엇을, 왜):
- ...

**Implicit context** (Constraints에 안 박힌, 작업 진행에 필요한 외부 사실):
- ...

**Deferred to plan** (이 spec이 의도적으로 lock하지 않은 결정):
- ...

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
