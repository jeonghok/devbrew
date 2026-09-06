---
detectors: 1
ground_truth: "audit `## 1. 원문` — 사용자가 실제로 한 말 전부"
allowed_dispositions: [decide, ask, fix, drop]
fix_anchors: ["*"]
immutable: []
protected_headings: []
layer_rubric:
  layer1: [unfounded_addition, example_as_requirement, premature_closure, inference_as_decision]
  layer2: []
decision_log: {kind: audit_section, heading: "## 8. 리뷰 결정"}
defer_target: {kind: none}
web: false
---

# seed 프로필 — 검토 항목

## 층 1 — 억제 (`docreview-layer1`)

**뺄셈 검사**다. 「좋은 프롬프트냐」는 묻지 않는다 — 초안이 원문에 없는 것을 더했거나, 원문에 있는 열림을 닫았는가만 본다.

- `unfounded_addition` — 원문에 근거가 없는 요구·제약이 seed 에 들어감.
- `example_as_requirement` — 사용자가 예시로 든 것이 요구로 승격됨.
- `premature_closure` — 사용자가 열어 둔 선택이 seed 에서 닫힘.
- `inference_as_decision` — 모델의 추론이 사용자의 결정처럼 쓰임.

## 층 2

없다. 이 프로필은 `docreview-layer2` 블록을 요구하지 않는다 — 비어 있어도 낸다면 `[]` 로.

## 처분 안내

- 다시 열어야 할 닫힘은 `fix`(seed 본문 전체가 범위). 사용자만 답할 수 있는 것은 `ask`.
- 0건은 정직한 답이다.
