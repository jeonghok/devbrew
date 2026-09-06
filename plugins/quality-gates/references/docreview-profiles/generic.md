---
detectors: 1
ground_truth: "문서 자체 — 외부 정답이 없다. 문서가 자기 주장을 스스로 지탱하는가를 본다"
allowed_dispositions: [decide, ask, fix, drop]
fix_anchors: ["*"]
immutable: []
protected_headings: []
layer_rubric:
  layer1: [logic, assumption]
  layer2: [completeness, evidence, ambiguity, actionability, structure]
decision_log: {kind: state}
defer_target: {kind: none}
web: false
---

# generic 프로필 — 검토 항목

## 층 1 — 논리와 전제 (`docreview-layer1`)

- `logic` — 결론이 전제에서 따라 나오지 않는 곳. 서로 모순되는 두 주장.
- `assumption` — 말해지지 않은 전제 위에 선 주장. 그 전제가 거짓이면 무엇이 무너지는가를 `evidence` 에 적는다.

## 층 2 — 상세 (`docreview-layer2`)

- `completeness` — 약속하고 채우지 않은 절, 열거의 빠진 항.
- `evidence` — 근거 없이 단정된 사실.
- `ambiguity` — 두 가지로 읽히는 문장.
- `actionability` — 읽는 쪽이 무엇을 해야 하는지 알 수 없는 지시.
- `structure` — 목차와 본문의 불일치, 헤딩 없이 이어지는 긴 본문.

## 처분 안내

- 헤딩이 없는 문서일 수 있다 — 그때 모든 `fix` 의 범위는 문서 전체이고 얼림·보호 부류는 비활성이다(엔진이 공시한다).
- 문서의 목적을 바꾸는 수정은 `decide`. 저자의 의도를 모르면 `ask`.
