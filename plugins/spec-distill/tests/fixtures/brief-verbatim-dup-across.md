---
name: verbatim-dup-across
type: interview-brief
created_at: 2026-08-31
session_id: 11111111-1111-1111-1111-111111111111
source: spec-distill conducting-interview v0.43.0
next_phase: superpowers:brainstorming
audit_file: brief-verbatim-dup-across.audit.md
user_sourced_items:
  - id: C1
    source: verbatim
    status: provisional
    statement: "brief에 리뷰를 붙인다"
    evidence: S1
---

# Verbatim Cross-File Duplicate Anchor — Interview Brief

U2-T4 전용 fixture다. v0.43.0 설계상 payload §6에는 S1만 있어야 하지만, 이 fixture는
**의도적으로** S5를 payload에도 심어 audit §6과 충돌시킨다 — 교차 파일 append-only
위반(exit 1)을 잡기 위해서다.

## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > "브리프에 리뷰를 붙이고 싶다"
- **S5** 🗣 교차 중복(payload 쪽):
  > "이 앵커는 audit에도 있다"

## 7. Next Action

- 없음
