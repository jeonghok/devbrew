---
name: <kebab-topic>
type: interview-brief
created_at: YYYY-MM-DD
session_id: <uuid>
source: spec-distill conducting-interview v0.23.0
next_phase: superpowers:brainstorming
audit_file: <YYYY-MM-DD>-<kebab-topic>-interview.audit.md   # basename만 (같은 디렉토리)
# user_sourced_items — **사용자 출처 항목만**. `source: inferred`는 여기 들어갈 수 없다(게이트 fail).
# 모델 추론은 본문 프로즈에 ✎ 표기로만 산다.
# status는 인터뷰 종료 직전 사용자 일괄 확인으로만 confirmed가 된다 — 라운드 중에는 전부 provisional.
# confirmed 0건이면 다음 sentinel 한 줄을 이 블록 안에 명시한다:
#   # confirmed 0건 — 사용자가 전부 잠정으로 판단
user_sourced_items:
  - id: C1
    source: verbatim          # verbatim(발화 그대로) | chosen(선택지 선택)
    status: provisional       # confirmed | provisional | open
    statement: "<160자 이내 — 모델이 쓴 제약 한 줄. P21 secret placeholder 치환>"
    evidence: S1              # §6의 어느 발화에서 나왔는가 — 필수
---

# <Topic> — Interview Brief

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 brainstorming 해답공간으로
> 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다. 텔레메트리는 `audit_file`에 있다.

## 0. 한눈에

(≤15줄. 무엇 / 왜 / 무엇이 확정 / 무엇이 열려 있음 / 다음 stage. 다음 세션이 여기만 읽고도
 방향을 잡을 수 있어야 한다.)

## 1. Goal · Non-goal

(≤12줄.)

- Goal: ...
- Non-goal: ...

## 2. 제약

(≤30줄. 이 절의 진술은 모델이 쓴 요약이다. 원문은 §6, `⟨S<N>⟩`가 그것을 가리킨다.)

- 🗣 confirmed **C1** — <statement> ⟨S1⟩
- ☑ provisional **D2** — <statement> ⟨S2⟩

✎ (모델 추론은 이 프로즈 형식으로만. frontmatter 계약 밖이라 게이트 대상이 아니다.)

## 3. Open Questions

(≤25줄. 미해결 명시 — "유추 금지". 탐색 대상이므로 앞쪽에 온다.)

- OQ1: ...

## 4. External Landscape

(≤20줄. 1항목 = 1줄, **출처 URL 필수** + [취함|피함|중립] + 이유.)

- ... — https://example.com — [취함] — 이유

## 5. 기각 · Blind Spots

(≤25줄. `기각` 항목이 0건이면 `- 기각 — N/A — 전부 first-time defend+lock` 한 줄 명시(빈 섹션 금지).
 `verdict:`를 가진 항목은 audit §3의 `ST<N>` 참조가 필수다.)

- 기각 — <시도한 방향> → <버린 이유>
- 기각 — <시도한 방향> → <버린 이유> — https://evidence.example — verdict: defended — ST1
- 위험 — <숨은 가정 | 실패 양식>: <내용> — <근거>

## 6. 사용자 원문

(분량 무제한 — **전문 보존**. 허용 변환은 P21 placeholder 치환·앞뒤 공백 정리·인용 블록 래핑뿐이며
 요약·재서술·발췌는 금지. 각 항목이 `S<N>` 앵커를 제공한다.)

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S1** 🗣 최초 요청:
  > "..."
- **S2** ☑ 선택 (<무엇에 대한 선택>):
  > "..."

## 7. Next Action

(≤10줄. superpowers 있으면: 이 brief를 context로 `superpowers:brainstorming` 호출 → `-design.md`
 → reviewer 검증 → writing-plans. 없으면: 이 brief가 완결 산출물 — 직접 사용.)
