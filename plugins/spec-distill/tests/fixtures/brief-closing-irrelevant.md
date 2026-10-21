---
name: sample-topic-v2
type: interview-brief
created_at: 2026-09-23
session_id: testsessionv2
source: spec-distill conducting-interview 4.4.0
next_phase: superpowers:brainstorming
contract: v2
audit_file: brief-closing-irrelevant.audit.md
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

- Goal: 대시보드 최초 페인트 시간 단축 ⟨S1⟩
- Non-goal: 전체 앱의 렌더링 전략 통일 ⟨S1⟩

## 2. 제약

- 🗣 confirmed **C1** — 대시보드는 SSR로 렌더한다 ⟨S1⟩

## 3. Open Questions

- OQ1: 인증 뷰의 캐시 전략 → 근거 RC3
- OQ4 [해결 ⟨S1⟩]: 렌더링 전략 — 해결: (픽스처) → 근거 RC3

## 4. External Landscape

외부 선례 무관(@S2) — 이 레포 안의 정리 일이라 바깥 선례가 결정을 바꾸지 않는다

## 5. 기각 · Blind Spots

- 기각 — N/A — 전부 first-time defend+lock
- 검토 — steelman 0건: 검토한 방향 1개 · 전제 P1 · trigger 후보 landscape 모순 → 기각 이유 모순 없음
- 위험 — 숨은 가정 | 캐시 계층이 인증 뷰를 이미 다룬다 — RC3 [RC3 → OQ1 · OQ4]
- 위험 — 실패 양식 | 세션 키 충돌은 열린 결정과 무관하다 — RC5 (plugins/spec-distill/scripts/check_brief.py#gate) [RC5 → 없음]

## 6. 사용자 원문
- **S1** 🗣 최초 요청:
  > "대시보드가 너무 느려요."
- **S2** ☑ 선택 (외부 선례):
  > "외부 선례 무관"
- **S3** 🗣 답:
  > "캐시는 지금 그대로 둔다"
- **S4** 🗣 답:
  > "로그인 화면은 범위 밖이다"
- **S5** 🗣 답:
  > "첫 화면만 빠르면 된다"
- **S6** 🗣 답:
  > "모바일은 다음에 본다"
- **S7** 🗣 답:
  > "숫자 목표는 2초 안이다"
- **S8** 🗣 답:
  > "열린 질문 목록은 이대로 맞다"
## 7. Next Action

이 brief를 context로 brainstorming 호출.
