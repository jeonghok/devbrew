---
detectors: 1
ground_truth: "인터뷰 브리프 §2 확정 항목 — frontmatter `source_interview` 가 가리키는 파일"
allowed_dispositions: [decide, ask, fix, defer, drop]
fix_anchors: ["*"]
immutable: []
protected_headings:
  - "\\bGoals?\\b|목표"
  - "Non-?goals?|비목표|범위 밖"
  - "Constraints?|제약"
  - "Architecture|아키텍처"
  - "trade-?offs?|트레이드오프"
  - "Acceptance Criteria|수용 기준|\\bAC\\b"
layer_rubric:
  layer1: [goal_fit, problem_definition, scope, architecture, component_relations, data_flow, tradeoffs, feasibility]
  layer2: [placeholder, ambiguity, scope_creep, approaches_comparison, isolation, testing, handoff_incomplete]
decision_log: {kind: doc_section, heading: "## 결정 기록"}
defer_target: {kind: doc_section, heading: "### Deferred to plan"}
web: false
---

# design-doc 프로필 — 검토 항목

## 층 1 — 큰 그림 정합 (먼저 검토하고 `docreview-layer1` 블록으로 낸다)

정답의 출처는 인터뷰 브리프 §2 의 확정 항목이다. 문서가 그 확정과 **하나의 그림**으로 정합한지 본다.

- `goal_fit` — 문서의 Goals 가 브리프의 goal 과 같은 것을 겨누는가. 다른 문제를 잘 풀고 있지 않은가.
- `problem_definition` — Context 의 근본 원인 서술이 브리프의 문제 정의와 맞는가.
- `scope` — Goals·Non-goals 가 브리프의 범위와 같은가. 조용히 넓어지거나 좁아진 곳.
- `architecture` — 핵심 구조가 확정 제약(C·D 항목)을 어기지 않는가.
- `component_relations` — 컴포넌트 사이 의존 방향이 한 그림으로 닫히는가(순환·고아).
- `data_flow` — 한 사이클의 데이터가 끊김 없이 흐르는가(생산자 없는 소비자, 소비자 없는 산출물).
- `tradeoffs` — 기각된 대안이 왜 기각됐는지가 확정 항목과 모순되지 않는가.
- `feasibility` — 설계가 단정한 도구·리포 사실이 실재하는가(파일·락·시그니처를 읽어 확인한다).

층 1 finding 의 처분은 대개 `decide` 다 — 방향의 결함은 저자가 아니라 사용자가 정한다.

## 층 2 — 상세 완결 (`docreview-layer2` 블록)

- `placeholder` — TBD·TODO·「나중에」·빈 절.
- `ambiguity` — 두 가지로 읽히는 요구. 측정 불가 표현("적절히", "빠르게").
- `scope_creep` — 한 구현 계획으로 분해되지 않는 독립 하위 시스템 묶음.
- `approaches_comparison` — 대안 비교 없이 단정된 선택.
- `isolation` — 단위 테스트·변경 격리가 불가능할 만큼 흐린 컴포넌트 경계.
- `testing` — **검증 전략의 부재**다. 「무엇이 관측되면 통과인가」가 없을 때만 낸다. 자동 검증 **절차**(명령·픽스처·순서)의 부재는 plan 의 일이므로 `defer` 로 낸다.
- `handoff_incomplete` — Handoff Context 가 없거나, `/compact` 뒤 이 문서만 읽고 이어갈 수 없는 암묵 컨텍스트가 남아 있다.

## 처분 안내

- 목표·범위·제약·Non-goal·아키텍처·trade-off·AC 를 바꾸는 수정은 `decide` — 변경 내용 · 근거 · 대안 · 영향을 `summary`/`evidence` 에 채운다.
- 답이 있어야 고칠 수 있는 fix 에는 `ask` 를 하나 내고 `blocks` 에 그 fix 의 `ref` 를 적는다.
- plan 이 도출·관측할 일은 `defer`. 근거 없는 의심은 내지 않는다 — 0건은 정직한 답이다.
