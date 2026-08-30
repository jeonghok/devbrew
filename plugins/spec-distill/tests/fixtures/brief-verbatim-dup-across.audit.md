---
type: interview-audit
payload: brief-verbatim-dup-across.md
created_at: 2026-08-31
session_id: 11111111-1111-1111-1111-111111111111
source: spec-distill conducting-interview v0.43.0
---

# Verbatim Cross-File Duplicate Anchor — Interview Audit

U2-T4 전용 fixture다. S5가 payload §6과 이 audit §6 양쪽에 같은 앵커로 나온다 — 교차
파일 append-only 위반. 어느 statement도 S5를 실제로 참조하지 않아도(state 원장은
S1만 안다) 합집합 단계에서 앵커 교집합만으로 exit 1이 나야 한다.

## 1. Coverage Ledger

- floor:root_problem — closed — <evidence>
- floor:landscape — closed — <evidence>
- floor:skepticism — closed — <evidence>
- floor:blind_spot — closed — <evidence>
- floor:open_questions — closed — <evidence>
- derived:N/A — closed — N/A

## 2. Budget

- 질문 라운드: 1 · agent dispatch: 0 · codex 실호출: 0 (성공 0)

## 3. Steelman 원문

## 4. 게이트 실행 기록

- check_brief.py gate — pass (2026-08-31)
- check_verbatim_coverage.py — exit 1 (2026-08-31, 의도된 fixture)

## 5. 프로세스 로그

- round 1: (b) — fixture

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S5** 🗣 교차 중복(audit 쪽):
  > "같은 앵커가 반대편에도 있다"
