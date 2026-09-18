---
type: interview-seed-audit
payload: <basename>.md
created_at: YYYY-MM-DD
session_id: <uuid>
source: spec-distill framing-requests
---

# <Topic> — Interview Seed Audit

> 순수 텔레메트리 — 다음 세션의 첫 턴 `/interview @<seed 경로>` 가 가리키는 것은 payload(seed)
> 파일이고, 여기에는 확산·압축이 어떻게 진행됐는지의 과정 기록만 남는다. payload 의 `audit_file`
> 이 이 파일을 가리킨다.

## 1. 원문

(사용자가 준 원문 — 요청 · 생각 · 대화 로그 · 자료를 세션 state 에서 그대로 옮긴다.
 **append-only**: 이후 라운드에서 나온 원문도 요약하지 않고 여기에 계속 덧붙인다.
 지금 요약하면 압축이 무엇을 떨어뜨렸는지 이 절이 못 남긴다.)

## 2. 질문 전체

(라운드마다 블록 하나 — 답하지 않은 질문도 남긴다. **«당신이 답한 것» 줄만 사용자의 말이다** —
 질문 문구 · 선택지 · 내가 읽은 것은 저자가 쓴 것이다. 리뷰는 이 구분으로 정답을 가른다.)

### 라운드 <n>

- 물은 것: <질문 문구 그대로>
  - 선택지: <선택지 라벨을 « / » 로 잇는다 — 자유 입력만 받았으면 «자유 입력»>
  - 당신이 답한 것: <고른 라벨 또는 적은 말 그대로 — 답이 없으면 «(답 없음)»>
- 확인 질문: <어느 라운드의 풀이인지>
  - 내가 읽은 것: 「<풀이 문장>」 — <고름 | 고르지 않음>

## 3. 긴 초안

(압축 전 긴 초안 — 크게 그린 다음 깎아낸 원본. **seed 로는** 나가지 않고 이 절에만 남는다.)

## 4. 비평과 냉독

(리뷰 엔진 라운드마다 탐지 · codex · 재비판 산출물을, 마지막에 냉독 산문을 **판정 없이** 그대로
 옮긴다 — 엔진 자리는 세션 정리로 사라지고 사람이 나중에 되짚을 자리는 여기다. 엔진 산출물은
 `seed_review_log.py append-verbatim` 이 인용 블록으로 붙인다.)

## 5. degrade

(`framing_degradations` 원장 — `brief_review_state.py degrade-append … --ledger-key
framing_degradations --axis suppression` 으로 기록한 것을 그대로 직렬화한다. 원장에
못 쓰면 그 사실 자체를 게이트 질문 텍스트에 실었다는 것과 함께 여기에도 남긴다. 워크트리를
만들지 않았으면(거절·`EnterWorktree` 부재·`DEVBREW_SPEC_DISTILL_DISABLE_WORKTREE`) «워크트리
없음 — <이유>» 한 줄도 여기 남긴다 — degrade 원장과 같은 절이지만 별개 사실이다.)

## 6. 리뷰 결정

(리뷰 라운드의 처분 기록. 엔진이 `decide` · `fix --event drop` 에서 한 줄씩 적고, 이 skill 이
 finding 없는 처분 — 저자 편집 덩어리 · 비차단 ask 의 답 — 을 같은 모양으로 적는다. 줄마다
 사용자 문구가 큰따옴표 안에 있다.)
