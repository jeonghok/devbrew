---
detectors: 1
ground_truth: "payload `## 6. 사용자 원문`(S1) + audit `## 6. 사용자 원문`(S2 이상) — 둘 다 정답이다"
allowed_dispositions: [decide, ask, fix, drop]
fix_anchors: ["^0\\.", "^2\\."]
immutable: ["^6\\."]
protected_headings: ["^1\\."]
layer_rubric:
  layer1: [direction]
  layer2: [distortion, omission, invention]
decision_log: {kind: audit_section, heading: "## 8. 리뷰 결정"}
defer_target: {kind: none}
web: true
---

# brief 프로필 — 검토 항목

## 층 1 — 방향성 (`docreview-layer1`)

사용자가 정한 방향이 **틀렸을 근거**를 찾는다 — 리포 실체와 웹의 선례로. 방향을 바꾸지 않는다: finding 하나마다 사용자가 결정할 질문 하나를 `summary` 에 담고 처분은 `decide` 다.

- `direction` — 확정 항목이 리포 사실과 모순되거나, 더 성숙한 외부 대안이 있거나, 확정 사이가 서로 충돌한다. 근거(파일:심볼 · URL)를 `evidence` 에 인용한다.

## 층 2 — 충실도 (`docreview-layer2`)

문서 **내부 대조**다. §2 요약이 §6 원문을 어떻게 옮겼는지만 본다. 외부 정보는 이 층의 오염원이다.

- `distortion` — 원문의 뜻이 바뀐 요약.
- `omission` — 원문에 있는 결정·제약이 요약에서 빠짐.
- `invention` — 원문에 없는 것이 요약에 확정으로 들어감.

## 처분 안내

- `fix` 는 §0·§2 에만 낼 수 있다. §6 원문은 어떤 처분도 바꾸지 못한다.
- **원문 자체가 두 가지로 읽힐 때만** `decide` 를 낸다 — 그 결정의 적용처는 원문이 아니라 §0·§2 의 해석이다.
- §1 Goal 을 바꾸는 수정은 사용자 결정(보호 부류).
