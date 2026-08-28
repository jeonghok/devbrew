---
type: interview-seed-audit
payload: <basename>.md
created_at: YYYY-MM-DD
session_id: <uuid>
source: spec-distill framing-requests
---

# <Topic> — Interview Seed Audit

> 순수 텔레메트리 — 다음 세션의 첫 턴에 붙여넣는 것은 payload(seed)이고, 여기에는
> 확산·압축이 어떻게 진행됐는지의 과정 기록만 남는다. payload 의 `audit_file` 이 이
> 파일을 가리킨다.

## 1. 원문

(사용자가 준 원문 — 요청 · 생각 · 대화 로그 · 자료를 세션 state 에서 그대로 옮긴다.
 **append-only**: 이후 라운드에서 나온 원문도 요약하지 않고 여기에 계속 덧붙인다.
 지금 요약하면 압축이 무엇을 떨어뜨렸는지 이 절이 못 남긴다.)

## 2. 질문 전체

(라운드마다 쏟아낸 질문을 하나도 빠뜨리지 않고 남긴다 — 답한 것과 안 한 것을 구분한다.)

- 쏟아낸 것: <질문 전체 목록>
- 답한 것: <사용자가 실제로 답한 질문과 답>
- 안 한 것: <답을 못 받아 다음 라운드로 좁혀 다시 물은 질문, 또는 끝내 안 한 질문>

## 3. 긴 초안

(압축 전 긴 초안 — 크게 그린 다음 깎아낸 원본. `docs/` 에는 나가지 않고 이 절에만 남는다.)

## 4. 비평과 냉독

(`seed-critic` · `seed-readback` 두 dispatch 의 raw 출력을 **판정 없이** 그대로 옮긴다.
 두 출력은 사용자에게 직접 가고 orchestrator 는 병합하지 않으므로, 여기 남기는 것도
 verbatim 이다.)

### seed-critic (억제 리뷰)

> <raw 출력 verbatim>

### seed-readback (냉독)

> <raw 출력 verbatim>

## 5. degrade

(`framing_degradations` 원장 — `brief_review_state.py degrade-append … --ledger-key
framing_degradations --axis suppression` 으로 기록한 것을 그대로 직렬화한다. 원장에
못 쓰면 그 사실 자체를 게이트 질문 텍스트에 실었다는 것과 함께 여기에도 남긴다.)
