# 질문 자리 fixture

## 가 — 라벨 꼬리가 있는 꼬리 질문

가-질문: 아래 `AskUserQuestion` 하나를 띄운다.

```javascript
AskUserQuestion({ questions: [{ question: "어떻게 할까?", options: [
  {label: "계속 (권장)"}, {label: "멈춤"}] }] })
```

## 나 — 지시 · 뗌 문장만 있고 라벨 꼬리는 없는 꼬리 질문

나-질문: `AskUserQuestion` 하나 — 「계속」 · 「멈춤」. 권하는 쪽이 있으면 첫 자리로 옮기고 라벨 끝에 「(권장)」을 단다. 고른 선택지는 라벨 끝의 「(권장)」 · 「(Recommended)」 꼬리를 뗀 이름으로 읽는다.

## 다 — 한 줄에 질문 둘

다-승인: `AskUserQuestion` 하나 — 「승인」 · 「고치기」. 다-병렬: 같은 호출에 「병렬 (권장)」 · 「차례로」를 묻는다.

## 라 — 끝을 표시 문장으로 잡았는데 표시가 없는 지시 질문, 바로 뒤에 표시가 있는 지시 질문

라-첫: `AskUserQuestion` 하나 — 「적용」 · 「버림」.

라-둘: `AskUserQuestion` 하나 — 「열기」 · 「닫기」. 권하는 쪽이 있으면 첫 자리로 옮기고 라벨 끝에 「(권장)」을 단다.

## 마 — 꼬리가 있는 비움 질문

마-질문: `AskUserQuestion` 하나 — 「A (권장)」 · 「B」. 추천을 달지 않는다 — 사용자가 고른다.

## 바 — 어느 행에도 덮이지 않는 줄

바: 이 문단은 `AskUserQuestion` 을 말하지만 목록에 없다.

## 사 — 목록 행의 ② 사유(도구 이름 없는 줄)

사-둘 사-둘 · 사-끝: 끝을 찾지 못한다 · 사-종류: 모르는 종류다.

## 아 — 뗌 문장이 없는 떼기 문단

아-뗌: 고른 라벨이 「계속」이면 진행한다.

## 자 — 출처 꼬리가 없는 출처꼬리 문단

자-출처: 선택지 순서는 원문 그대로 옮긴다.

## 차 — (Recommended) 만 꼬리인 꼬리 질문

차-질문: `AskUserQuestion` 하나 — 「Go (Recommended)」 · 「Stop」.

## 카 — 한 줄에 도구 이름이 둘인 언급 행

카-언급: `AskUserQuestion` 은 도구 이름이다. 카-추가: 같은 줄에 `AskUserQuestion` 질문이 하나 더 있다.

## 타 — 지시 문장이 없는 지시 질문

타-질문: `AskUserQuestion` 하나 — 「열기」 · 「닫기」.

## 파 — 이유 문장도 꼬리도 없는 비움 질문

파-질문: `AskUserQuestion` 하나 — 「A」 · 「B」.

## 하 — 떼기 앵커 줄에 쓴 새 질문

하-뗌: 고른 선택지는 라벨 끝의 「(권장)」 · 「(Recommended)」 꼬리를 뗀 이름으로 읽는다. 하-새: `AskUserQuestion` 으로 「다시」 · 「그만」을 묻는다.

## 거 — 질문 범위 안에 낀 새 질문

거-질문: 아래 `AskUserQuestion` 하나를 띄운다.

```javascript
AskUserQuestion({ questions: [{ question: "어떻게 할까?", options: [
  {label: "계속 (권장)"}, {label: "멈춤"}] }] })
```

거-새: 그다음 `AskUserQuestion` 으로 「다시」 · 「그만」을 묻는다.

## 너 — 설명에만 꼬리가 있는 꼬리 질문

너-질문: 아래 `AskUserQuestion` 하나를 띄운다.

```javascript
AskUserQuestion({ questions: [{ question: "어떻게 할까?", options: [
  {label: "계속", description: "고르면 계속한다 (권장)"}, {label: "그만"}] }] })
```

## 러 — 질문 행 앵커 줄에 쓴 둘째 질문

러-질문: `AskUserQuestion` 하나 — 「계속 (권장)」 · 「멈춤」. 러-새: 이어 `AskUserQuestion` 으로 「다시」 · 「그만」을 묻는다.

## 머 — 이미 센 펜스 줄에 붙인 둘째 호출

머-질문: 아래 `AskUserQuestion` 하나를 띄운다.

```javascript
AskUserQuestion({ questions: [{ question: "어떻게 할까?", options: [{label: "계속 (권장)"}, {label: "멈춤"}] }] }); AskUserQuestion({ questions: [{ question: "또 할까?" }] })
```

## 버 — label: 꼴인데 꼬리를 question 으로 옮긴 꼬리 질문

버-질문: 아래 `AskUserQuestion` 하나를 띄운다.

```javascript
AskUserQuestion({ questions: [{ question: "어떻게 할까? (권장)", options: [
  {label: "계속"}, {label: "그치기"}] }] })
```

## 서 — 따옴표로 감싼 키 · 꼬리는 description 에

서-질문: 아래 `AskUserQuestion` 하나를 띄운다.

```javascript
AskUserQuestion({ "questions": [{ "question": "어떻게 할까?", "options": [
  {"label": "계속", "description": "고르면 계속한다 (권장)"}, {"label": "쉬기"}] }] })
```

## 어 — 질문 범위 안의 언급(같은 줄)

어-질문: 빈 답이면 `AskUserQuestion` 재질문을 한 번 더 하고, 그래도 비면 `AskUserQuestion` 하나 — 「채우기 (권장)」 · 「건너뛰기」.
