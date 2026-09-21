---
name: designer-lens-review
type: design
created_at: 2026-09-21
source_interview: docs/superpowers/interview/2026-09-21-designer-lens-review-interview.md
next_phase: superpowers:writing-plans
---

# 설계자 시선 리뷰 — 설계

> **기존 축은 전부 「맞는가」를 묻는다. 설계자는 「과한가」를 묻는다.**

devbrew 의 문서 리뷰에 설계하는 사람의 눈을 넣고(갈래 1), 리뷰어가 찾은 것을 오케스트레이터가
반영할 때 사용자가 멈칫 없이 고르게 만든다(갈래 2). 둘은 독립 결함이고 같은 무게다.

갈래 1 은 두 문서 자리(brief · design-doc)의 `layer_rubric.layer1` 에 축 **하나**를 세우고 그 안에
술어 셋(과함 · 왜곡 · 층위 이탈)을 둔다. 판정 절차와 어법은 ponytail 에서 가져오고, 거기 없는 것은
리포 자신에게서 가져온다. 갈래 2 는 게이트 렌더의 **동어반복**을 없애고 리뷰어 칸 둘을 더해 「그대로
두면 / 고치면」을 같은 다섯 줄 안에 싣는다.

## 목차

- [1. Context · Why](#1-context--why)
  - [1.1 갈래 1 — 축이 통째로 없다](#11-갈래-1--축이-통째로-없다)
  - [1.2 갈래 2 — 자리는 있고 producer 가 잘못 채운다](#12-갈래-2--자리는-있고-producer-가-잘못-채운다)
  - [1.3 외부 조달 결과 — ponytail 이 준 것과 안 준 것](#13-외부-조달-결과--ponytail-이-준-것과-안-준-것)
- [2. Goals](#2-goals)
- [3. Non-goals](#3-non-goals)
- [4. Constraints](#4-constraints)
- [5. Architecture](#5-architecture)
  - [5.1 새 축 `overdesign`](#51-새-축-overdesign)
  - [5.2 판정 한 줄의 형식](#52-판정-한-줄의-형식)
  - [5.3 판정 절차 — Lazy Ladder 문서판](#53-판정-절차--lazy-ladder-문서판)
  - [5.4 자르지 않는 것 · 0건 출구 · 상한](#54-자르지-않는-것--0건-출구--상한)
  - [5.5 배선 — `doc-critic` 층 1 참조 전환](#55-배선--doc-critic-층-1-참조-전환)
  - [5.6 T13 의 새 장치 — 부재 열거를 허용 목록으로](#56-t13-의-새-장치--부재-열거를-허용-목록으로)
  - [5.7 갈래 2 — 네 해법의 생산 자리](#57-갈래-2--네-해법의-생산-자리)
  - [5.8 게이트 렌더 — 같은 다섯 줄, 정보는 3 → 5](#58-게이트-렌더--같은-다섯-줄-정보는-3--5)
  - [5.9 `/qg` 의 회계어](#59-qg-의-회계어)
- [6. 데이터 흐름 — 새 칸 둘이 어디서 나와 어디로 가나](#6-데이터-흐름--새-칸-둘이-어디서-나와-어디로-가나)
- [7. 위험](#7-위험)
- [8. Acceptance Criteria](#8-acceptance-criteria)
- [9. Files to Modify](#9-files-to-modify)
- [10. Verification Plan](#10-verification-plan)
- [11. Rejected Alternatives](#11-rejected-alternatives)
- [12. Open Questions](#12-open-questions)
- [결정 기록](#결정-기록)
- [Handoff Context](#handoff-context)
  - [Deferred to plan](#deferred-to-plan)

## 1. Context · Why

### 1.1 갈래 1 — 축이 통째로 없다

brief 자리의 `layer_rubric.layer1` 은 `[direction]` 하나다. 그 축이 묻는 것은 「사용자가 정한 방향이
틀렸을 근거가 있는가」이고, 「그 방향이 goal 에 비해 과한가」는 어디에도 없다.

design-doc 자리에는 층 1 여덟 축이 있지만 **전부 한 방향**이다 — 프로필 본문 실측:

| 축 | 묻는 것 | 방향 |
|---|---|---|
| `goal_fit` | Goals 가 브리프의 goal 과 **같은 것을 겨누는가** | 정렬 |
| `problem_definition` | 근본 원인 서술이 브리프와 **맞는가** | 정합 |
| `scope` | Goals·Non-goals 가 브리프의 범위와 **같은가** | 정합 |
| `architecture` | 핵심 구조가 확정 제약을 **어기지 않는가** | 준수 |
| `component_relations` | 의존 방향이 한 그림으로 **닫히는가** | 폐쇄 |
| `data_flow` | 데이터가 **끊김 없이 흐르는가** | 폐쇄 |
| `tradeoffs` | 기각 사유가 확정과 **모순되지 않는가** | 정합 |
| `feasibility` | 단정한 리포 사실이 **실재하는가** | 존재 |

설계자 시선의 술어 셋은 「**과한가** · **왜곡됐는가** · **넘어왔는가**」다. 절차를 얹어도 「같은 것을
겨누는가」에서 「goal 에 비해 과한가」는 안 나온다 — 다른 질문이기 때문이다. 겹치는 자리는 정확히 둘,
그것도 좁다: `data_flow` 의 「소비자 없는 산출물」이 ponytail `delete:`(dead code)와, 층 2 `scope_creep`
(분해 안 되는 묶음)이 「과함」과 부분적으로 겹친다.

**그리고 프로필만 고치면 안 된다.** `doc-critic` 본문이 층 1 축을 **리터럴 산문으로 쥐고** 있다
(`shared/docreview/agents/doc-critic.md:47` — 「목표·문제정의·범위·아키텍처·컴포넌트 관계·데이터
흐름·trade-off·구현 가능성」). 층 2 만 `layer_rubric.layer2` 를 참조한다(`:48`). 같은 파일 `:38` 이
`<profile>` 을 「이 자리의 공개 계약이지 프레이밍이 아니다」로 선언하므로 새 축은 리뷰어에게 **닿는다** —
결함은 미전달이 아니라 **리터럴 여덟 축과의 충돌**이다.

**그 충돌은 이미 돌고 있다.** codex 러너는 `layer_rubric.layer1` 을 읽어 프롬프트에 싣고
(`run_docreview_codex_reviewer.sh:372`·`:427`), Claude `doc-critic` 은 본문의 리터럴 여덟을 본다.
같은 라운드에서 두 판정자가 다른 rubric 으로 돈다. 그리고 리터럴 여덟 축은 **네 자리 중 하나에만** 맞다:

| 자리 | 프로필 `layer1` | 리터럴 여덟 축과 |
|---|---|---|
| design-doc | `[goal_fit … feasibility]` (8) | 일치 |
| brief | `[direction]` (1) | 불일치 |
| seed | `[unfounded_addition, example_as_requirement, premature_closure, inference_as_decision]` (4) | 불일치 |
| `/qg` generic | `[logic, assumption]` (2) | 불일치 |

### 1.2 갈래 2 — 자리는 있고 producer 가 잘못 채운다

게이트는 `decide` finding 마다 헤더 + 네 줄을 낸다(`docreview_state.py` `_rg_decide`). 그 네 줄 중 둘이
정보를 나르지 않는다:

- **「변경」** = `it["summary"]`(`docreview_route.py` `_decision_view`) — **헤더와 같은 문자열**이다.
- **「대안」** = 고정 라벨 셋 `채택(적용) / 기각(원복) / 보류`(`_CHOICE_LABEL`) — 대개 모든 항목에서 같다
  (승계·만료 때만 다르다).
- 「영향」 = `anchor` + 인용 섹션 수 — 영향이 아니라 **위치**다.
- `category` 는 렌더에 **한 번도 안 나온다**.

그래서 「고르면 무엇이 바뀌는지」가 원리적으로 안 보인다. 새 칸을 더하는 것만으로는 안 고쳐진다 —
`normalize()`(`docreview_route.py:52-78`)가 리뷰어 YAML 을 받아 **고정 10키 dict 를 처음부터 새로 짓고**
모르는 키를 **조용히 버리며**, 설령 칸이 비어도 `change` 가 `summary` 로 채워져 **비어 보이지 않는다.**

### 1.3 외부 조달 결과 — ponytail 이 준 것과 안 준 것

브리프 C26 이 이 단계에 맡긴 조달을 수행했다(`DietrichGebert/ponytail`, HEAD `e3ba2aa`, 2026-09-14).
결과는 **절반의 성공**이다.

**준 것** — 판정 절차(Lazy Ladder, **7단이 정본**) · 조기 종료 규칙 · 보호 경계 다섯 · 정직한 0건 출구
(`Lean already. Ship.` 한 줄로 끝, 정당화 금지) · finding 형식(지적과 **대체안**을 같은 항목에, 대체안이
없으면 `Replacement: nothing.` 으로 **명시**) · 판정 어법(태그 다섯 + **금지 어법** ❌「…might be… have you
considered…?」) · 스코프 배제(`over-engineering and complexity only`, 나머지는 다른 패스로 라우팅).

**안 준 것** — 아키텍처 층위의 판정 기준이 **없다**(전수 grep 0건). 가장 근접한 `yagni: layer with one
caller` 도 「층이 잉여인가」라는 **수량** 판정이지 「내용이 엉뚱한 층에 있는가」라는 **위치** 판정이 아니다.
과소설계·한 방향 압력의 균형 장치도 리뷰어 **밖**(빌드 페르소나의 하한선 + 다른 패스로의 라우팅)에만 있다.

**정정 둘** — ① 브리프 §4 는 사다리를 5단으로, ✎ 노트는 7단으로 적어 두 자리가 어긋나 있었다. 원문에
**7·6·5 세 판본이 병존**하고 **런타임에 주입되는 정본은 7단**이며 5단은 사람용 help 카드 축약(rung 2·5 를
떨어뜨림)이다. ② D6 의 넷째 장치(「줄이자 판정에 관측 가능한 검사를 함께」)는 **ponytail 원문에 없다** —
이 리포가 지어낸 것이다. 원문의 인접 장치는 **천장 + 올라갈 조건**(`ponytail:` 주석 + `no-trigger` 태그)이고,
그쪽을 채택한다([결정 기록](#결정-기록) D6′).

## 2. Goals

동등 무게 둘이다. 어느 하나가 다른 하나의 수단이거나 부차적이지 않다.

1. **구현 전에 과설계를 잡는다.** 두 문서 자리의 층 1 에 설계자 시선 축을 세우고, 그 축이
   ponytail 의 절차와 어법으로 판정한다.
2. **리뷰 처분을 멈칫 없이 고른다.** 조작적 정의 — 같은 길이에 정보가 더 많고, 쉽게 전달되어 피로도 없이
   이해되는 설명. 달성 판정은 브리프 D13 의 세 기준(라벨만 읽고 고른다 · 안 바뀐 것은 안 보인다 · 용어가
   처음 보는 말이 아니다)으로 한다.

## 3. Non-goals

- **탐지 리뷰어를 늘리는 것.** `doc-critic` 하나로 유지한다.
- **seed(Phase 0) 자리에 설계자 시선을 넣는 것.** 참조 전환은 seed 에 닿지만 **새 축은 안 간다**.
- **갈래 1 을 `/qg` 로 넓히는 것.** `/qg` 에 가는 것은 갈래 2 의 회계어 번역 하나다.
- **계측 칸 추가**(열린 `decide` 수 · 카테고리별 수) — 이번 사이클 밖.
- **`protected_headings` 단위 변경**(헤딩 → 소절) — 이번 사이클 밖.
- **`AskUserQuestion` 을 다른 응답 표면으로 바꾸는 것.** 문제는 방식이 아니라 선택의 내용이다.
- **엔진의 라운드·상한·처분 어휘를 바꾸는 것.** `rereview_cap: 2`·`RANK`·`allowed_dispositions` 는 불변.

## 4. Constraints

브리프 §2 의 27 항목이 정본이다. 설계에 직접 구속되는 것만 다시 적는다.

- **C1** 새 리뷰어 agent 를 만들지 않고 프로필 `layer_rubric` 에 축을 더한다.
- **C2** 갈래 1 의 적용 자리는 brief·design-doc 둘. seed·`/qg` 는 밖.
- **C3** 설명 개선 넷을 **모두** 범위에 둔다 — 하나만 고치는 것은 부분 해결이다.
- **C4** 두 goal 은 같은 무게다.
- **D5** 두 갈래는 독립 결함이다 — 통합 재구성을 하지 않는다.
- **D6′** ponytail 차용 넷 = 판정 절차 · 오탐 가드 · 0건 출구 · **천장 + 올라갈 조건**. 코드 층위 다섯
  카테고리는 버린다. 넷째 장치는 finding 스키마에 **전용 칸을 만들지 않고** rubric 산문으로만 둔다.
- **D7′** `doc-critic` 층 1 불릿을 `layer_rubric.layer1` 참조로 바꾸는 것을 같은 변경에 포함한다
  (agent 사본 넷). **두 자리 모두 같은 축 하나를 신설한다**(재결정 — [결정 기록](#결정-기록)).
- **D8** 난점 ⓐⓑ 의 수정 지점은 `_decision_view` 의 동어반복이다. 칸만으로는 안 고쳐진다.
- **D9** 새 축의 finding 은 라운드당 N 건까지. 엔진은 안 건드린다. 상한은 **판정자별**이라 라운드 총량은
  **2N+α** 다. 프로필 frontmatter 에 담을 필드가 없어 **강제 없는 rubric 산문**으로만 존재한다.
- **D11**(*provisional*) 축 하나 안에 술어 셋. ② 는 design-doc 자리에만, brief 에는 ①③.
- **D13** 갈래 2 의 수용 기준 셋.
- **D14** 갈래 2 의 적용 자리 = 문서 둘 + `/qg`.
- **C15** 축 목록은 여기서 닫히지 않는다.
- **C16** 과설계 기준 둘(goal 대비 · 더 단순한 대안)은 **우선순위**이지 닫힌 목록이 아니다.
- **C18** 밀도 — 같은 길이에 정보가 더 많은 쪽(**비구속 선호**). 글이 아니라 정보를 늘린다.
- **D21** `/qg` 의 회계 낱말은 **그대로 두고** 사람말 한 줄을 옆에 덧붙인다.
- **D22** 「새 의존성을 더하지 마라」는 리뷰 축으로 옮기지 않는다.
- **D24** 묶음은 **읽는 부담만** 줄인다 — 질문 수도 항목별 선택권도 그대로다.
- **D25** `/qg` 에 가는 것은 회계어 번역 하나. 그 자리에는 「읽히기」 기준을 따로 세운다.
- **C27** 응답 표면은 `AskUserQuestion` 유지.
- **P23 재결정 규약** — `confirmed` 는 재논의 대상이 아니지만 **반증 대상**이다. 근거를 대고 사용자 동의를
  받아 피벗하되 임의 변경은 금지이고, 뒤집은 항목은 «원래 / 재결정 / 근거» 세 칸으로 남긴다.

**기계적 제약 — 실측으로 확인한 것**

- `PROFILE_FIELDS`(`docreview_state.py:37-39`)는 **닫힌 10-튜플**이다. 11번째 필드도, `layer_rubric` 의
  셋째 키도 `fields_unknown`·`detectors_unsupported` 로 **rc 2 거부**다.
- `normalize()`(`docreview_route.py:52-78`)는 고정 10키 dict 를 **새로 짓는다.** 모르는 키는 조용히
  버려진다 — 새 칸은 이 함수까지 가야 산다.
- `doc-critic` 사본 넷은 `copy-of`·`variant-of` 마커로 묶여 락 넷이 동기화를 **강제**한다. 편집 자리는
  하나이고 하나라도 빠뜨리면 RED 다.
- `variant-of` 계약은 「웹 사본은 정본에 **한 덩어리를 끼워 넣은 것뿐**이고 정본의 어느 줄도 바뀌거나
  빠지지 않는다」이다.

## 5. Architecture

### 5.1 새 축 `overdesign`

```yaml
layer_rubric:                              # brief.md — 1 → 2
  layer1: [direction, overdesign]

layer_rubric:                              # design-doc.md — 8 → 9
  layer1: [goal_fit, problem_definition, scope, architecture,
           component_relations, data_flow, tradeoffs, feasibility, overdesign]
```

**이름의 근거** — 층 1 축은 리포 관례가 **주제 이름**(`direction`·`goal_fit`·`architecture`)이고 결함
이름은 층 2 관례(`distortion`·`omission`·`invention`)다. `overdesign` 은 사용자가 쓴 낱말 그대로이며
기존 어느 축과도 안 부딪힌다 — 특히 `distortion` 은 **brief 층 2 에 이미 있어**(원문의 뜻이 바뀐 요약)
술어 ②를 그 낱말로 부르면 충돌한다.

**술어 셋과 자리별 배치**

| 술어 | 묻는 것 | 기준의 출처 | brief | design-doc |
|---|---|---|---|---|
| ① 과함 | goal 대비 과한가 | ponytail Lazy Ladder + C16 의 기준 둘 | ✅ | ✅ (§1 Goal 기준) |
| ② 왜곡 | 제약을 지키려다 구조가 뒤틀렸나 | **ponytail 에 없음** — D22 · CLAUDE.md Forbidden Patterns | ❌ | ✅ |
| ③ 층위 이탈 | 아래 층의 일이 들어왔나 | **ponytail 에 없음** — 리포의 기존 경계 | ✅ | ✅ |

**② 가 brief 에 없는 이유** — 그 술어의 대상이 구조·구현이고 brief 에는 그것이 없다(D11).

**③ 은 새 메커니즘이 필요 없다.** design-doc 프로필 층 2 `testing` 이 이미 「자동 검증 **절차**(명령·
픽스처·순서)의 부재는 plan 의 일이므로 `defer` 로 낸다」고 적는다. ③ 은 그 문장의 **반대 방향**이고,
배관(`defer_target: {kind: doc_section, heading: "### Deferred to plan"}`)이 이미 깔려 있다. brief 자리는
`defer` 가 없으므로(`defer_target: {kind: none}`) ③ 의 처분은 `decide` 다.

**① 의 기준이 자리마다 다르다.** design-doc 에서 ① 은 **브리프 §1 Goal** 을 기준으로 잰다 — 기존
`architecture`(§2 확정 제약 준수)는 그대로 둔다. 그래야 「§2 가 확정한 것 자체가 §1 의 goal 에 비해
과하다」를 말할 수 있다. 브리프가 과설계를 확정한 경우 conformance 술어만으로는 정의상 「정합」이 나와
이빨이 없다.

### 5.2 판정 한 줄의 형식

ponytail 의 finding 형식을 문서용으로 옮긴다.

```
<앵커>: <태그> <무엇이 과한가>. <더 단순한 대안>.
        └ 천장: <이 판정이 틀릴 조건>
```

**태그 다섯** — ponytail 원문 다섯 중 코드 전용 둘(`stdlib:`·`native:`)을 버리고 셋을 그대로 쓰며,
원문에 없는 둘을 리포 자신에게서 만든다.

| 태그 | 뜻 | 출처 |
|---|---|---|
| `delete:` | 죽은 절 · 안 쓰는 유연성 · 투기적 기능. 대체안: 없음 | ponytail `review:23` 원문 |
| `yagni:` | 구현체 하나뿐인 추상 · 아무도 안 쓰는 설정 · 호출자 하나뿐인 층 | ponytail `review:26` 원문 |
| `shrink:` | 같은 결론, 더 적은 구조 | ponytail `review:27` 원문 |
| `bent:` | 제약 X 를 지키려 구조 Y 가 들어왔는데 X 를 만족하는 더 곧은 길 Z 가 있다 | 리포(D22 · Forbidden Patterns) |
| `altitude:` | 이 문서의 층이 아닌 것이 들어와 있다 | 리포(design-doc 층 2 `testing` 의 반대 방향) |

**대체안은 같은 항목 안에 필수다.** 없으면 빈칸이 아니라 `대체안 없음 — 그냥 뺀다.` 로 **명시**한다
(ponytail `delete:` → `Replacement: nothing.`).

**금지 어법** — ❌「…가 과할 수도 있는데 고려해 보셨나요?」 같은 헤지형 질문. ponytail 이 ❌ 예시로 원문에
박아 둔 어법이다(`review:31-32`). ✅ 사실 서술 + 대체안.

**`└ 천장`** — 「줄이자」 판정에는 그 줄임의 **천장**과 **올라갈 조건**을 함께 적는다. 조건을 못 적으면
`천장: (없음)` 으로 남기고 `no-trigger` 로 표시한다 — 되돌릴 길이 없다는 공시다. 이것은 finding 스키마의
칸이 아니라 **rubric 산문 규약**이고, `summary`/`replacement` 산문 안에 들어간다(D6′).

### 5.3 판정 절차 — Lazy Ladder 문서판

**선행 조건**(원문) — 사다리는 문제를 이해한 **뒤에** 돌지 이해를 대신하지 않는다. 문서를 끝까지 읽고
흐름을 따라간 뒤에 오른다. **성립하는 첫 단에서 멈춘다.**

| 원문 단(7단 정본) | 문서판 |
|---|---|
| 1 존재해야 하나 (YAGNI) | **1** 이 구조가 있어야 하나 — 투기적 필요면 한 줄로 그렇게 적고 뺀다 |
| 2 이미 이 코드베이스에 있나 | **2** 이미 리포에 있는 원칙·메커니즘으로 되나 |
| 3 stdlib · 4 native · 5 기존 의존성 | **3** 이미 있는 하니스 표면(프로필 필드·처분·락·훅)으로 되나 — 원문 세 단을 하나로 접는다. 문서엔 대응물이 없다 |
| 6 한 줄로 되나 | **4** 한 줄 규약으로 되나 |
| 7 그제서야 최소 | **5** 그제서야 새 메커니즘 |

**원문 모호성 하나를 이 설계가 정의한다.** 원문의 `Two rungs work → take the higher one` 에서 「higher」의
방향이 정의돼 있지 않다(리포 전수 grep 확인 — 그 문구는 `skills/ponytail/SKILL.md:47` 과 그 바이트
복제본에만 있고 다른 어느 파일도 해소하지 않는다). **번호가 작은 쪽**으로 정의한다 — `Stop at the first
rung that holds` 와 일관되기 때문이다.

### 5.4 자르지 않는 것 · 0건 출구 · 상한

**오탐 가드 — ponytail 원문 다섯**: trust-boundary 검증 · 데이터 손실 처리 · 보안 · 접근성 · 명시 요청 동작.

**조사가 찾아낸, 브리프가 빠뜨렸던 셋을 더한다** — 원문의 `## When NOT to be lazy` 절은 4문단인데
브리프는 첫 문장만 가져왔다:

- **「사용자가 완전판을 고집하면 짓는다 — 재논쟁 없음」**(`SKILL.md:94-95`). devbrew 의 P23 과 짝이다 —
  근거 **새것**이 있으면 반증, 없으면 재논쟁 금지. 같은 판정을 새 근거 없이 다음 라운드에 다시 내는 것이
  규약 위반이다.
- **「사다리는 해답을 줄이지 읽기를 줄이지 않는다」**(`:97-98`).
- **스코프 배제**(`review:52-54`) — 이 축은 **과함만** 본다. 충실도·방향의 결함은 다른 축이 낸다.

**devbrew 자리의 것** — Law 1·2·3 과 kill switch(P21 보안 컨트롤)는 어떤 모드에서도 안 자른다.

**0건 출구** — 「이 문서는 이미 최소다.」 **한 줄로 끝**이다. 정당화도 「찾아봤으나 없음」 서술도 붙이지
않는다(원문 `and stop.`).

**상한 N = 3.** 임의의 수가 아니라 도출이다 — 게이트가 `AskUserQuestion` 을 **4개씩** 나눠 부르므로
(`reviewing-document.md:28`), 3 이면 이 축이 한 호출을 통째로 먹지 않고 기존 축 자리가 최소 하나 남는다.
초과분은 한 묶음으로 남기고, **무엇을 잘랐는지 한 줄로 적는다.**

### 5.5 배선 — `doc-critic` 층 1 참조 전환

편집 자리는 **하나**이고 나머지 셋은 락이 강제한다.

```
shared/docreview/agents/doc-critic.md:47          ← 여기만 고친다
  ├─ variant-of ─→ shared/docreview/agents/doc-critic-web.md:49
  ├─ copy-of  ──→ plugins/spec-distill/agents/doc-critic.md:48
  └─ copy-of  ──→ plugins/spec-distill/agents/doc-critic-web.md:50
집행: test_copy_of_contract.sh · test_variant_of_contract.sh
      test_docreview_agents.sh · test_brief_agents.sh
```

**바꿀 문장** — 층 2 불릿과 같은 모양으로:

> - **층 1** — 프로필 `layer_rubric.layer1` 의 항목. `ground_truth` 와 문서가 하나의 그림으로 정합한지 그
>   항목들로 본다. 리포 사실을 단정하는 finding 은 파일·심볼을 실제로 읽어 확인한 근거를 `evidence` 에
>   인용한다.

원래 문장의 마지막 절(구현 가능성 finding 의 근거 요구)은 **축 이름에 묶여 있어** 축이 사라지면 같이
사라진다. 축 이름에서 떼어 **모든 층 1 finding** 에 걸도록 옮긴다 — 범위가 넓어지는 쪽이고, 좁아지면
`feasibility` 의 이빨이 조용히 빠진다.

**이것은 부수효과가 아니라 수선이다.** 네 자리 중 **셋**이 틀린 층 1 지시를 받고 있고, 같은 라운드의 두
판정자가 서로 다른 rubric 으로 돈다. 그 리터럴 줄을 붙드는 락은 **하나도 없다**(테스트 전수 grep 0건).
seed·`/qg` generic 은 각자 자기 프로필 축을 보게 되고, **새 축은 그 둘에 안 간다**(C2).

### 5.6 T13 의 새 장치 — 부재 열거를 허용 목록으로

`test_brief_review_ng3.sh` 의 T13 은 머리말에서 자기가 지키는 것을 밝힌다 — 「옛 design-doc 리뷰어 agent 가
자기 산문으로 지던 **역할 경계**를, 엔진 전환 이후에는 자리별 프로필의 `ground_truth`·`layer_rubric` 이
진다」. 지금 그 경계를 재는 방식과 못 재는 것:

```
for _did in goal_fit architecture tradeoffs; do grep -qF "$_did" <brief layer1>; done
  잡는 것   : 그 세 이름
  안 잡는 것: problem_definition · scope · component_relations · data_flow · feasibility
             (다섯 축이 brief 에 들어가도 무언 — fail-open)
```

**바꾼 뒤 — 단언 다섯**

| # | 단언 | 성격 |
|---|---|---|
| ① | 두 프로필의 층 1·2 목록을 읽었고 넷 다 비어 있지 않다 | 양의 짝 (기존 유지) |
| ② | 두 자리의 `ground_truth` 가 다르다 | 기존 유지 |
| ③ | brief 층 2 ∩ design 층 1·2 = ∅ | 기존 유지 |
| ④ | **brief 층 1 ∩ design 층 1 ⊆ SHARED** · `SHARED = {overdesign}` 을 락 파일이 명시 열거 | **신설 — fail-open → fail-closed** |
| ⑤ | **SHARED 의 각 축이 두 프로필 본문에서 서로 다른 문장으로 정의된다** | 신설 |

④ 가 실질이다 — 지금은 **금지 셋**이라 그 밖은 전부 통과하고, 바꾸면 **허용 목록**이라 목록 밖 공유는
전부 걸린다. ⑤ 는 「같은 이름이되 재는 대상이 다르다」를 기계로 붙든다: 두 불릿이 둘 다 실재하고(양의 짝)
→ 문자열이 다르며 → 각자 자기 자리의 기준어를 담는다(brief 불릿에 「사용자 원문」 계열, design 불릿에
「브리프 §1 Goal」).

**한계 공시** — ⑤ 는 리터럴 핀이고 **바이트를 잰다.** 두 불릿을 무의미하게 다르게 써도 통과한다. 잡는
것은 **한쪽을 다른 쪽에 통째로 베껴 넣는 것**뿐이다. 의미는 못 잰다.

### 5.7 갈래 2 — 네 해법의 생산 자리

| | 해법 | 생산 자리 | 왜 거기인가 |
|---|---|---|---|
| ⓐ | before/after | **리뷰어** 새 칸 `replacement` | 「고치면 무엇이 되는가」는 의미다. `summary` 하나로는 파생 불가 |
| ⓑ | 「그대로 두면」 | **리뷰어** 새 칸 `if_unfixed` | 같은 이유 |
| ⓒ | 회계어 번역 | **렌더러** — `_CHOICE_LABEL` · `/qg` 는 §5.9 | 결정론 |
| ⓓ | 우선순위·묶음 | **렌더러** — `GATE_ROWS` · `anchor` | 순위를 **새로 안 매긴다**. 이미 있는 순서의 **뜻**을 보이게 한다 |

**ⓐ 의 칸은 갈래 1 의 칸과 같은 칸이다.** ponytail 의 finding 계약이 지적과 대체안을 한 항목에 싣고,
브리프 §4 가 이미 이 단서를 적어 두었다 — 「before/after 와 「더 단순한 대안」이 별개 기능이 아니라 한
필드일 수 있다」. 한 칸이 둘을 다 산다.

**D8 에 대한 읽기** — D8 은 ⓐⓑ 의 *수정 지점*을 「리뷰어 새 필드」에서 「`_decision_view` 동어반복」으로
옮겼다. 이 설계는 그것을 「**칸 금지**」가 아니라 「**칸만으로는 안 됨**」으로 읽는다 — 브리프 §5 위험이
말한 실패가 정확히 「칸을 더해도 fallback 이 동어반복을 재현하고, 필드가 비어 있지 않으므로 그 실패는
관측되지 않는다」이기 때문이다. **칸 + fallback 수정**을 한 변경으로 묶는다.

**원칙: 강제할 수 없으면 보이게 한다.** 리뷰어가 칸을 안 채우면 렌더가 `summary` 를 되풀이하는 대신
「리뷰어가 안 적음」이라고 **말한다.** 이것이 실제로 작동하는 유일한 집행이다 — `evidence` 의 「`decide`
에는 필수」도 `normalize()` 가 강제하지 않는 산문 규약이라는 선례가 이미 있다.

**ⓓ 의 두 부분**

- **순위** — `GATE_ROWS` 10행의 순서는 이미 결정론이지만 **상태 범주** 순이다. 그 뜻을 게이트 머리에
  한 줄로 낸다: 「열린 결정 먼저 · 그다음 관측 대기 · 막힌 것 · 미적용 수정 · 질문」. 문제는 「순위가
  없다」가 아니라 「있는 순서의 뜻이 안 보인다」였다. **새 순위를 매기지 않는다** — 오케스트레이터가
  순위를 매기면 그 순위 자체가 판단이고, 사용자가 그 위험을 받아들인다고 말한 적이 없다.
- **묶음** — 같은 `anchor` 의 항목을 한 덩어리로 **보이게만** 한다. 질문 수도 항목별 선택권도 그대로다(D24).

### 5.8 게이트 렌더 — 같은 다섯 줄, 정보는 3 → 5

```
지금                                        바꾼 뒤
[decide] f3 — <summary>                     [decide] f3 — <summary>
  변경: <summary>       ← 헤더 복사·정보 0     그대로 두면: <if_unfixed>
  근거: <evidence>                            고치면: <replacement>
  대안: 채택/기각/보류   ← 대개 고정·정보 0     근거: <evidence>
  영향: <anchor> · 인용 N                     자리: <anchor> (<category>) · 인용 N
                                            [대안: …]  ← 기본 셋과 «다를 때만»
```

- **「변경」이 사라지고 「그대로 두면 / 고치면」 둘로 갈린다.** 헤더가 「무엇이 문제인가」, 두 줄이 「두면 /
  고치면」 — 동어반복이 원리적으로 불가능해진다.
- **리뷰어가 안 채우면**: `그대로 두면: (리뷰어가 안 적음)` · `고치면: 대체안 없음 — 그냥 뺀다`.
  **`summary` 로 메우지 않는다.**
- **「영향」 → 「자리」**: anchor + 인용수는 영향이 아니라 위치다. 이름을 정직하게 바꾸고 `category` 를
  함께 싣는다 — 지금 렌더에 한 번도 안 나오는 값이라 「왜 문제인가의 부류」가 처음으로 보인다.
- **「대안」은 조건부**: `decide_choices` 는 대개 같은 셋이지만 승계·만료 때 다르다. **다를 때만** 낸다.
  같으면 게이트 머리에 한 번만 적는다 — 모든 항목에 같은 문자열이 반복되는 것이 밀도의 적이다(C18).

**회계어는 순서만 뒤집는다**(ⓒ 의 문서 자리):

```
지금    채택(적용) / 기각(원복) / 보류
바꾼 뒤  고친다(채택) / 그대로 둔다(기각) / 나중에 정한다(보류)
```

낱말 수도 길이도 거의 같고 **회계어는 보존**된다(D21 의 「낱말은 그대로 두고」와 같은 정신) — 사람말이
**먼저** 올 뿐이다.

**밀도 회계** — 지금 다섯 줄 중 실효 정보는 셋(「변경」·「대안」이 정보 0). 바꾼 뒤 다섯 줄 전부 항목별.
**같은 길이에 정보 3 → 5.**

**D13 세 기준과의 대응**

| 기준 | 무엇이 닫는가 |
|---|---|
| ① 라벨만 읽고 고른다 | 선택지 라벨이 항목별이 됨 — `고친다 — <replacement 압축>` / `그대로 둔다` / `나중에`. `label` 은 1–5 낱말 예산 안에 들어가야 한다 |
| ② 안 바뀐 것은 안 보인다 | 동어반복 줄 제거 + 「그대로 두면」이 결과를 말함 |
| ③ 용어가 처음 보는 말이 아니다 | 회계어 순서 뒤집기 + `category` 를 사람말로 |

### 5.9 `/qg` 의 회계어

고칠 자리는 `shared/adjudication/render_disposition.py` **한 파일**, 소비자는 **둘**이다
(`synthesize_findings.py` · `synthesize_artifact_findings.py` — 실측 확인).

```
**처분:** 수용 0 · 기각 1 · 억제 1 · 흡수 0 · 미판정 1     (차단 아님)
**배관 손실:** 1 · 셀 수 없음 0     (차단: 예)
↳ 억제=규칙이 자른 것 · 흡수=같은 것끼리 합친 것
  · 미판정=볼 사람이 없던 것 · 배관 손실=판정에 못 들어간 것      ← 이 줄만 추가
```

풀이 줄은 **별도 반환값**이다(AC21) — 처분 줄도 배관 줄도 아닌 셋째 줄이라 어느 한쪽 문자열 안에 개행으로
넣지 않는다. 그 낱말들이 두 줄에 걸쳐 있기 때문이다.

**「읽히기」 기준 셋**(D25 가 요구한 `/qg` 자리의 기준 — D13 셋은 「고르기」를 재므로 여기 안 쓴다):

| # | 기준 | 지금 상태 |
|---|---|---|
| 1 | 한 줄만 읽고 「막혔는가」를 안다 | **이미 만족** — `(차단: 예/아니오)` 리터럴 |
| 2 | 모르는 낱말이 남지 않는다 | **미달** → 풀이 줄이 회계어 넷을 푼다 |
| 3 | `0` 이 「없었다」인지 「못 봤다」인지 구분된다 | **이미 만족** — `미판정`·`셀 수 없음` 두 칸 |

셋 중 둘이 이미 만족돼 있다. `/qg` 에 필요한 실제 변경은 **한 줄**이고, 이것이 D25 가 범위를 ⓒ 하나로
좁힌 것이 옳았다는 증거다.

## 6. 데이터 흐름 — 새 칸 둘이 어디서 나와 어디로 가나

```
doc-critic / doc-critic-web        ← 프로필 layer_rubric.layer1 에서 overdesign 을 읽는다
  └ docreview-layer1 블록
      ref · layer · category: overdesign · anchor · disposition
      summary · evidence · edit_scope
      replacement   ← 새 칸 (갈래 1 의 「더 단순한 대안」 = 갈래 2 의 ⓐ)
      if_unfixed    ← 새 칸 (갈래 2 의 ⓑ)
          ↓
docreview_route.py  normalize()        ← 두 칸을 실어 나른다 (안 고치면 조용히 버려짐)
          ↓
      prepare-recritic → prep.json items   (pub = dict(it) — 정규화된 dict 를 그대로 복사)
          ↓
doc-recritic  (문서 · items · 프로필 셋만)   ← 새 칸을 본다. added finding 도 같은 스키마
          ↓
docreview_route.py  finalize → _decision_view()
      change  → 제거                       ← 동어반복의 자리
      if_unfixed / replacement → 그대로, 비면 «없음»을 공시
      basis   → evidence
      impact  → anchor + nref + category
          ↓
docreview_state.py  _rg_decide()  게이트 텍스트 다섯 줄
          ↓
오케스트레이터가 AskUserQuestion 을 4개씩 조립
      label       ← replacement 를 1–5 낱말로 압축
      description ← 그대로 두면 / 고치면 / 근거
```

codex 쪽은 러너가 `layer_rubric.layer1` 을 읽어 같은 축을 프롬프트에 싣는다. codex finding 은
`normalize(it, 2, "x", i, L)` 로 같은 정규화를 거치므로 **같은 두 칸을 낼 수 있다** — 러너 프롬프트에 그
두 칸을 더해야 실제로 나온다.

## 7. 위험

- **수용률 역설** — 설명은 팀 정확도가 아니라 AI 제안의 **수용률**을 올린다(«bansal-chi2021»
  «automation-bias»). 갈래 2 의 성공이 갈래 1 의 판정을 무르게 만들 수 있고, 「멈칫」이 사라진 것이 판단이
  좋아진 신호가 아닐 수 있다. 두 목표가 독립이라는 전제가 여기서 깨진다. **완화 불가** — 「고치면」이
  구체적이면 틀린 판정을 알아볼 확률이 오르는 것이 전부다.
- **계측기 부재** — 게이트 회계에 「열린 `decide` 수」도 「카테고리별 수」도 없다. 사전 baseline 없이 넷을
  한꺼번에 고치면 증거가 사후 인상뿐이고 그 인상은 위 수용률 상승으로 낙관 편향된다. 계측 칸 추가는 이번
  범위 밖이다.
- **`decide` 인플레이션** — brief 층 1 은 전부 `decide` 이고 보호 부류·immutable 이 새 축의 finding 을
  그쪽으로 몬다. 상한 N=3 으로 막지만 그 상한은 **판정자별**이라 라운드 총량은 **2N+α** 다.
- **상한이 무엇을 자르는가** — 자를 것을 고르는 판단자가 자기 출력을 자르는 리뷰어 자신이다. 새 축이 먼저
  잘리면 갈래 1 이 무효화되고 기존 축이 잘리면 충실도 회귀다. 어느 쪽이 잘렸는지 볼 계측기가 없다.
- **반증 불가 축** — `doc-recritic` 은 `reject` 에만 문서 내 인용을 요구한다. 「이건 과설계다」는 문서
  내용으로 반증되지 않는다. §5.4 의 「근거 없는 재논쟁 금지」 규약과 `prior_finding_ids`·`supersedes` 표시로
  **완화되지만 안 닫힌다** — 「이력상 근거 없이 다시 냈다」는 문서 내용이 아니라 **이력**이라 recritic 이
  인용할 수 없다.
- **한 방향 압력** — 사다리는 「쓰인 것」에만 적용되어 판정이 항상 「줄여라」로 나고 과소설계는 원리적으로
  못 잡는다. 조사가 확인한 대로 **ponytail 원문도 한 방향**이고 균형을 리뷰어 **밖**에서 잡는다. 이 설계는
  천장 장치로 리뷰어 **안**에 일부를 들이는데, **검증된 선례가 없다.**
- **보호 경계는 열거다** — 도출 규칙이 아니라 닫힌 리스트라 저자의 상상력을 물려받는다. 원문도 그것을
  문자열로 CI 핀 고정한다(`scripts/check-rule-copies.js:49-57`).
- **rubric 항목 수 증가** — brief 1→2 · design-doc 8→9. 체크리스트 항목 수를 늘리면 평가자 간 신뢰도가
  떨어진다(«checklist-length-reliability»).
- **상한의 무이빨** — 프로필에 담을 필드가 없어 **강제 없는 산문**이다. 지켜지는지 셀 수단이 없다. 한계이지
  해결이 아니다.
- **설치 캐시** — 실행 시 agent 정의는 리포가 아니라 **설치 캐시**에서 온다. 리포만 고친 e2e 는 옛 리터럴
  축으로 돌고, 0건 출구가 그 오진을 감춘다.
- **T13 ⑤ 의 바이트 판정** — 두 불릿을 무의미하게 다르게 써도 통과한다.

## 8. Acceptance Criteria

**PR 1 — 수선**

- **AC1** `shared/docreview/agents/doc-critic.md` 의 층 1 불릿이 리터럴 여덟 축 열거를 담지 않고
  `layer_rubric.layer1` 을 참조한다.
- **AC2** 사본 넷이 동기화돼 `test_copy_of_contract.sh`·`test_variant_of_contract.sh`·
  `test_docreview_agents.sh`·`test_brief_agents.sh` 가 전부 GREEN 이다.
- **AC3** 구현 가능성 finding 의 근거 요구가 사라지지 않고 **모든 층 1 finding** 에 걸리는 문장으로 남는다.
- **AC4** 이 PR 이 새 축을 **어느 프로필에도 더하지 않는다** — `git diff` 에 `overdesign` 이 0회.

**PR 2 — 갈래 1**

- **AC5** `brief.md` 의 `layer_rubric.layer1` 이 `[direction, overdesign]` 이고 `design-doc.md` 의 것이
  기존 여덟에 `overdesign` 을 더한 아홉이다. **기존 여덟 축의 이름과 불릿 문구는 한 글자도 안 바뀐다.**
- **AC6** 두 프로필 본문의 `overdesign` 불릿이 서로 **다른 문장**이고, brief 쪽은 술어 ①③ 을,
  design-doc 쪽은 ①②③ 을 담는다.
- **AC7** 두 프로필 본문에 태그 다섯(`delete:`·`yagni:`·`shrink:`·`bent:`·`altitude:`)과 판정 한 줄의
  형식, 금지 어법, `└ 천장` 규약이 적혀 있다. `bent:` 는 design-doc 에만.
- **AC8** 두 프로필 본문에 Lazy Ladder 문서판 5단과 「성립하는 첫 단에서 멈춘다」·「두 단이 성립하면 번호가
  **작은** 쪽」이 적혀 있다.
- **AC9** 두 프로필 본문에 자르지 않는 것 여덟(ponytail 다섯 + 재논쟁 금지 + 읽기는 안 줄인다 + 스코프
  배제)과 devbrew 의 것(Law 1·2·3 · kill switch)이 적혀 있다.
- **AC10** 두 프로필 본문에 0건 출구 문구 한 줄과 「정당화를 붙이지 않는다」가 적혀 있다.
- **AC11** 두 프로필 본문에 상한 N=3 과 그 도출 근거, 초과분 묶음, 「무엇을 잘랐는지 한 줄」이 적혀 있고,
  **그것이 강제되지 않는다는 사실**이 함께 적혀 있다.
- **AC12** `test_brief_review_ng3.sh` 의 T13 이 §5.6 의 단언 다섯을 갖고, `SHARED = {overdesign}` 을 명시
  열거한다. 기존 단언 ①②③ 은 그대로 남는다.
- **AC13** `PROFILE_FIELDS` 와 `layer_rubric` 의 키 둘(`layer1`·`layer2`)은 안 바뀐다 — **이 PR 의**
  `git diff` 에 `docreview_state.py` 가 0줄. (PR 3 은 같은 파일의 다른 자리를 고친다.)

**PR 3 — 갈래 2**

- **AC14** `normalize()` 가 `replacement`·`if_unfixed` 두 키를 반환 dict 에 싣는다. 부재면 `None`.
- **AC15** `_decision_view()` 가 `change` 키를 내지 않고 `if_unfixed`·`replacement` 를 낸다. 둘 중
  어느 것이 비어도 **`summary` 로 메우지 않고** 부재를 말하는 리터럴을 낸다.
- **AC16** `_rg_decide()` 가 헤더 + `그대로 두면`·`고치면`·`근거`·`자리` 네 줄을 내고, `자리` 줄이
  `category` 를 담는다. `대안` 줄은 `decide_choices` 가 기본 셋과 **다를 때만** 난다.
- **AC17** `_CHOICE_LABEL` 이 `{"adopt": "고친다(채택)", "reject": "그대로 둔다(기각)", "hold": "나중에 정한다(보류)"}` 다.
- **AC18** 게이트 렌더 머리에 `GATE_ROWS` 순서의 뜻 한 줄과, 기본 선택지 셋이 한 번 난다.
- **AC19** `doc-critic`·`doc-critic-web` 출력 스키마에 두 칸이 적혀 있고 「`decide` 에는 `replacement`
  필수, 없으면 «대체안 없음 — 그냥 뺀다» 로 명시」가 적혀 있다.
- **AC20** codex 러너 프롬프트가 두 칸을 요구한다.
- **AC21** `render_disposition.py` 의 `disposition_lines()` 가 회계 낱말 여덟을 **그대로 둔 채** 풀이 줄을
  하나 더 낸다. 반환은 `(처분줄, 배관줄, **풀이줄**, advisory목록)` **4-튜플**이다 — 풀이 줄이 두 줄
  모두의 낱말을 풀므로 어느 한 줄 안에 개행으로 욱여넣지 않는다. 기존 위치 언패킹은 `ValueError` 로
  **소리 내며** 깨진다(조용히 넘어가지 않는다).
- **AC22** `/qg` 의 두 소비자가 4-튜플을 받아 세 줄을 함께 낸다. 두 소비자 밖에 이 함수를 부르는 자리가
  없음을 같은 PR 에서 전수 확인한다.

**전 PR 공통**

- **AC23** 착수 전 baseline(§10)의 다섯 파일이 전부 GREEN 을 유지한다. 새 RED 는 0.
- **AC24** 각 PR 이 건드린 플러그인의 `plugin.json` version bump 와 `CHANGELOG.md` 항목을 **같은 커밋**에
  담는다.

## 9. Files to Modify

**PR 1 — 수선**

| 파일 | 변경 |
|---|---|
| `shared/docreview/agents/doc-critic.md` | `:47` 층 1 불릿 → `layer_rubric.layer1` 참조 |
| `shared/docreview/agents/doc-critic-web.md` | `:49` 동일(variant-of 계약이 강제) |
| `plugins/spec-distill/agents/doc-critic.md` | `:48` 동일(copy-of) |
| `plugins/spec-distill/agents/doc-critic-web.md` | `:50` 동일(copy-of) |
| `plugins/spec-distill/plugin.json` · `CHANGELOG.md` | bump + 항목 |
| `plugins/quality-gates/plugin.json` · `CHANGELOG.md` | bump + 항목 (generic 자리 동작 변경) |

**PR 2 — 갈래 1**

| 파일 | 변경 |
|---|---|
| `plugins/spec-distill/references/docreview-profiles/brief.md` | `layer1` 에 `overdesign` · 본문에 축 절 신설 |
| `plugins/spec-distill/references/docreview-profiles/design-doc.md` | 동일(술어 ② 포함) |
| `plugins/spec-distill/tests/test_brief_review_ng3.sh` | T13 단언 ④⑤ 신설, leak2 제거 |
| `plugins/spec-distill/plugin.json` · `CHANGELOG.md` | bump + 항목 |

**PR 3 — 갈래 2**

| 파일 | 변경 |
|---|---|
| `shared/docreview/scripts/docreview_route.py` | `normalize()` · `_decision_view()` |
| `shared/docreview/scripts/docreview_state.py` | `_rg_decide()` · `_CHOICE_LABEL` · 게이트 머리 |
| `shared/docreview/agents/doc-critic.md` (+ 사본 셋) | 출력 스키마에 칸 둘 |
| `shared/docreview/scripts/run_docreview_codex_reviewer.sh` | 프롬프트에 칸 둘 |
| `shared/adjudication/render_disposition.py` | 풀이 줄 추가 · 반환 4-튜플 · docstring 의 반환 서술 갱신 |
| `plugins/quality-gates/scripts/synthesize_findings.py` | 4-튜플 언패킹 (`:482`·`:532` 두 자리) |
| `plugins/quality-gates/scripts/synthesize_artifact_findings.py` | 4-튜플 언패킹 (`:313`) |
| `plugins/quality-gates/tests/test_synthesize_artifact_findings.sh` | 머리말의 「처분 두 줄」 서술 → 세 줄 |
| `shared/docreview/references/reviewing-document.md` | 8단계의 `AskUserQuestion` 조립 규약 |
| `shared/tests/fixtures/docreview/golden/` | 렌더 변경에 따른 골든 갱신 |
| `plugins/quality-gates/tests/test_synthesize_disposition.sh` | 풀이 줄 단언 |
| `plugins/spec-distill/plugin.json`·`plugins/quality-gates/plugin.json` + 각 `CHANGELOG.md` | bump + 항목 |

## 10. Verification Plan

**baseline — 착수 전 실측(rc 가 아니라 통과 수로).** 2026-09-21 측정:

| 파일 | baseline | 닿는 PR |
|---|---|---|
| `shared/tests/test_docreview_agents.sh` | 36/36 GREEN | 1 · 3 |
| `shared/tests/test_copy_of_contract.sh` | 188/188 GREEN | 1 · 3 |
| `shared/tests/test_variant_of_contract.sh` | 87/87 GREEN | 1 · 3 |
| `plugins/spec-distill/tests/test_brief_review_ng3.sh` | 21/21 GREEN | 2 |
| `plugins/quality-gates/tests/test_synthesize_disposition.sh` | 11/11 GREEN | 3 |

**선재 RED 0.** 회귀가 생기면 전부 이 변경의 것이다. (CHANGELOG 에 적힌 「`test_synthesize_disposition.sh`
1/6 PASS」는 과거 기록이고 이후 고쳐졌다 — 기록이 아니라 실행으로 확인했다.)

**mutation — 통과가 정답인 단언이라 모양으로는 이빨을 못 가린다**

| 락 | mutation | 기대 |
|---|---|---|
| T13 ④ | brief `layer1` 에 `scope` 추가 | RED — **지금은 GREEN 인 자리** |
| T13 ④ | brief `layer1` 에 `goal_fit` 추가 | RED (기존과 동등) |
| T13 ④ 양성 대조 | `SHARED` 를 빈 집합으로 | RED (④가 공허하지 않음) |
| T13 ⑤ | design 의 `overdesign` 불릿을 brief 것으로 통째 교체 | RED |
| T13 ⑤ 양의 짝 | brief `layer1` 에서 `overdesign` 제거 | RED (⑤가 공허하지 않음) |
| AC14 | `normalize()` 에서 `replacement` 반환 제거 | RED |
| AC15 | `_decision_view` 의 fallback 을 `summary` 로 되돌림 | RED |
| AC15 양의 짝 | 정상 입력에서 `고치면` == `replacement` | **먼저 GREEN 이어야** 위 변이가 유효 |
| AC21 | 풀이 줄에서 「억제」 항목을 제거 | RED |

`PYTHONDONTWRITEBYTECODE=1` 을 걸고 돈다 — 같은 길이 변이는 stale `.pyc` 를 못 넘는다.

**e2e — 설치 캐시를 먼저 확인한다**

1. 실행 시 agent 정의가 오는 설치 캐시의 `doc-critic*.md` 가 리포의 것과 같은지 확인한다.
2. 같지 않으면 그 e2e 결과를 「축이 무이빨」의 근거로 **쓰지 않는다** — 0건 출구가 그 오진을 감춘다.
3. 확인 뒤에만: 과설계가 심어진 설계문서 하나로 라운드를 돌려 `overdesign` finding 이 태그·대체안·천장을
   갖춘 형식으로 나는지, 게이트 렌더가 다섯 줄을 내는지, `AskUserQuestion` 라벨이 항목별인지 본다.

**스위트 — 닿은 소비자 전부.** 셸 테스트는 리포 루트에서 돌린다. PR 마다 `shared/tests/` 전량 +
닿은 플러그인의 `tests/` 전량.

## 11. Rejected Alternatives

- **두 갈래를 하나로 묶는 재구성 세 후보** — 사용자가 셋을 모두 물리고 seed 의 두-독립-결함 읽기를
  유지했다. 축 주입 경로 문제는 사실로 살아남되 「문제 정의」가 아니라 「구현 세부」로 위치가 정해졌다.
- **ponytail 의 코드 층위 다섯 카테고리를 문서판으로 번역해 rubric 축으로 쓰는 안** — 축이 다섯 안팎으로
  늘어 finding 수와 게이트 질문 수를 키우고, 그것이 goal 의 뒤 절반을 직접 악화시킨다.
- **「프로필에 축을 더하면 끝」이라는 충분성 주장** — `doc-critic` 의 리터럴 여덟 축 줄이 사본 넷에 있어
  거짓이다.
- **아키텍처 축을 과설계 축과 별개로 세우는 안** — 축 수가 곧 finding 수이고, 사용자가 겪은 세 실패가
  한 축의 술어 셋으로 담긴다.
- **사다리에 두 단을 덧붙여 6단으로 만드는 안** — 성격이 다른 물음을 사다리 단계로 위장하면 「첫 단에서
  멈춘다」 규칙이 뒤 단을 건너뛴다.
- **우선순위를 오케스트레이터가 매기거나 엔진이 가중을 내는 안** — 그 순위 자체가 판단이고 사용자가 그
  위험을 받아들인다고 말한 적이 없다. 대신 **이미 있는 순서의 뜻을 보이게** 한다.
- **축 이름만 T13 의 세 낱말을 피하는 안** — 락은 GREEN 이지만 락이 지키던 경계가 실제로 약해졌다는 사실이
  아무 데도 안 남는다. 코드 변경 0 이 이 선택의 장점이자 정확히 그 위험 신호다.
- **T13 의 세 이름 금지를 두고 새 이름을 예외로 적는 안** — 열거를 하나 더 늘리는 것이라 다음 축이 붙을
  때 또 손대야 한다.
- **design-doc 은 기존 축 셋의 문구를 넓히는 안**(D7 원안) — 기존 판정의 **뜻이 바뀌어** 지금 돌고 있는
  리뷰가 회귀하고, 술어가 세 축에 흩어져 어느 finding 이 설계자 시선인지 **구분할 수 없게** 된다.
- **「줄이자」 판정에 관측 가능한 검사를 요구하는 안**(D6 원안) — 문서 층위에서 「관측 가능한 검사」가
  무엇인지 리뷰어가 매번 지어내야 하고 셀 수단이 없다. 천장 + 올라갈 조건이 ponytail 의 실재 장치이고
  문서에 자연스럽다.
- **`/qg` 에 설명 개선 넷을 모두 붙이는 안** — `/qg` 에는 항목별로 고르는 자리가 없다(유일한
  `AskUserQuestion` 이 iteration 단위 Retry/Proceed/Stop 셋). 나머지 셋을 붙이려면 그 자리를 새로
  만들어야 한다.
- **brief 에 `defer` 출구를 열어 「우선순위 낮음」에 행동을 주는 안** — 목적지 없는 `defer` 는 침묵
  삭제라 목적지 설계가 선행해야 한다. §12 로 남긴다.

## 12. Open Questions

- **OQ-A 계측기 부재** — 게이트 회계에 「열린 `decide` 수」도 「카테고리별 수」도 없어 이 변경이 무엇을
  바꿨는지 원리적으로 못 잰다. 이번 범위 밖(브리프 S5). 계측 칸을 열 때 Goodhart 를 함께 본다.
- **OQ-B `protected_headings` 단위** — 헤딩 단위라 상세 finding 이 `decide` 로 승격된다. 처방(소절 단위로
  좁히기)까지 앞선 설계문서에 적혀 있다. 이번 범위 밖.
- **OQ-C 상한이 무엇을 자르는가** — N=3 과 「무엇을 잘랐는지 한 줄」로 완화하되, 셀 수단이 없어 안 닫힌다
  (OQ-A 에 종속).
- **OQ-D 반증 불가 축** — 「근거 없는 재논쟁 금지」 규약과 `supersedes` 표시로 완화하되, recritic 이 이력을
  인용할 수 없어 기계적 기각 경로는 여전히 없다.
- **OQ-E 한 방향 압력** — 천장 장치가 리뷰어 안에서 균형을 잡는 첫 시도다. ponytail 원문은 균형을 리뷰어
  밖에서 잡으므로 **검증된 선례가 없다.** 과소설계를 적극적으로 찾는 술어를 나중에 열지는 미정.
- **OQ-F 수용률 역설** — 설명이 좋아지면 정확도가 아니라 수용률이 오른다. 두 goal 이 독립이라는 전제가
  여기서 깨진다. 측정 수단이 OQ-A 에 종속.
- **OQ-G rubric 항목 수** — design-doc 은 이미 층 1 아홉 + 층 2 일곱이 된다. 항목 수 증가가 일관성을
  떨어뜨리는 임계가 어디인지 모른다.
- **OQ-H 소비자 없는 배포 링크** — `plugins/spec-distill/scripts/render_disposition.py` 가 mode 120000
  심볼릭 링크로 남아 있으나 spec-distill 안에서 그것을 import 하는 코드가 **0** 이다
  (`merge_review.py`·`merge_brief_review.py` 가 docreview 전환으로 사라졌다). 이번 범위 밖이지만 우리
  변경이 그 링크를 통해 spec-distill 로 **새지 않는다**는 것은 확인했다.
- **OQ-I `shared/tests/test_adjudication_consumed.sh:28-42`** 의 「소비자 여섯 · 나머지 넷」 주석이
  현재 코퍼스와 어긋난다(둘이 사라졌다). 락 자체는 코퍼스를 동적으로 도출하므로 RED 가 아니다. 주석만
  낡았다. 이번 범위 밖.
- **OQ-J D11 의 지위** — D11 은 브리프에서 유일한 `provisional` 이고, 그 술어 셋의 **문구**가 사용자
  원문에서 복원되지 않는다. 이 설계는 술어 셋을 「확정된 문구」가 아니라 「사용자가 고른 방향의 한 표현」
  으로 다뤘고, §5.1 의 표가 그 표현이다. 리뷰에서 뒤집힐 수 있다.

## 결정 기록

**P23 재결정 — 브리프의 확정을 근거를 대고 뒤집은 것**

| 항목 | 원래 | 재결정 | 근거 |
|---|---|---|---|
| **D7 뒷절반** | design-doc 은 **기존 축의 절차화**, brief 는 축 추가 (비대칭) | **두 자리 모두 같은 축 하나를 신설** | design-doc 프로필 본문 실측 — 기존 여덟 축이 전부 「맞는가·빠지지 않았는가」 방향이고 술어 셋은 「과한가·왜곡됐는가·넘어왔는가」 방향이라 절차화로는 안 나온다. 겹치는 자리는 `data_flow` 의 한 술어와 층 2 `scope_creep` 둘뿐. 브리프 §5 의 기각 근거였던 「이미 다섯 축이 있어 신설이 중복」이 이 실측으로 반증된다. 사용자 동의 2026-09-21 |
| **D6 넷째 장치** | 「줄이자」 판정에 **관측 가능한 검사** 하나를 함께 낸다 (ponytail 차용이라고 기록) | **천장 + 올라갈 조건**, 조건 없으면 `no-trigger` 표시 | ponytail 원문 전수 조사 — 그 장치는 **원문에 없다**(리포 전수 grep 0건, 이 리포의 창작). 원문의 인접 장치는 빌드 쪽의 `ponytail:` ceiling 주석 + upgrade path + `no-trigger` 태그다. 문서 층위에 자연스럽고 한 방향 압력의 직접적 추다. 사용자 동의 2026-09-21 |

**사실 정정 — 결정이 아니라 측정으로 바뀐 것**

- **브리프 §4 의 사다리 단 수.** §4 는 5단으로, ✎ 노트는 7단으로 적어 두 자리가 어긋나 있었다. 원문에
  **7·6·5 세 판본이 병존**하고 런타임 주입 정본은 **7단**이며 5단은 help 카드 축약이다. 이 설계는 7단을
  정본으로 인용한다.
- **T13 의 새 술어 문구.** 이 설계 과정에서 오케스트레이터가 사용자에게 제시한 선택지 문구가
  「brief 층 1 의 각 축이 그 자리의 `ground_truth`(사용자 원문)를 쓰는가」였는데, 실측하면 brief 층 1 의
  `direction` 은 `ground_truth` 를 **안 쓴다** — 층 1 은 리포 실체와 웹 선례로 방향을 반증하고
  `ground_truth` 는 **층 2 의 정답**이다. 사용자가 고른 **방향**(이름 말고 관계로, fail-open → fail-closed)은
  그대로 서고 **기계 장치**만 §5.6 의 단언 다섯으로 바뀌었다. 사용자에게 고지함.
- **C26 의 조달 결과.** 「과설계 판정 기준을 외부 자료에서 끌어온다」의 답이 **절반**이다. ① 에는 내용과
  형식을 다 주고, ②③ 에는 **한 글자도 없다.** ②③ 의 기준은 리포 자신에게서 가져왔다(D22 · Forbidden
  Patterns · design-doc 층 2 `testing` 의 반대 방향).

**설계 결정 — 브리프가 열어 두고 이 단계가 정한 것**

| # | 결정 | 근거 |
|---|---|---|
| 1 | 축 이름 `overdesign` | 층 1 은 주제 이름이 관례. `distortion` 은 brief 층 2 에 이미 있어 충돌 |
| 2 | design-doc 의 ① 은 **§1 Goal** 기준, `architecture` 는 §2 확정 제약 그대로 | conformance 술어만으로는 브리프가 확정한 과설계를 정의상 「정합」으로 판정 |
| 3 | ③ 의 처분은 design-doc 에서 `defer`(`### Deferred to plan`), brief 에서 `decide` | 배관이 이미 있다 / brief 에는 `defer` 가 없다 |
| 4 | Lazy Ladder 원문 3·4·5 단을 하나로 접어 5단 | stdlib·native·의존성에 문서 대응물이 없다 |
| 5 | 「higher rung」을 **번호가 작은 쪽**으로 정의 | 원문 미정의. `Stop at the first rung that holds` 와 일관 |
| 6 | 상한 N = 3 | 게이트가 `AskUserQuestion` 을 4개씩 부른다 — 한 호출을 통째로 안 먹고 기존 축 자리가 하나 남는다 |
| 7 | ⓐⓑ 는 리뷰어 칸, ⓒⓓ 는 렌더러 (OQ1) | 「고치면 / 그대로 두면」은 의미라 파생 불가. 회계어와 순서는 결정론 |
| 8 | 「변경」 줄 제거 | 헤더가 이미 그 일을 한다. 동어반복이 원리적으로 불가능해진다 |
| 9 | 「대안」 줄은 조건부 | 모든 항목에 같은 문자열이 반복되는 것이 밀도의 적(C18) |
| 10 | 회계어는 **순서만** 뒤집는다 | D21 의 「낱말은 그대로 두고」와 같은 정신 |
| 11 | PR 셋 | 참조 전환이 갈래 둘과 독립으로 서고, Non-goal 자리의 동작 변경을 기능 PR 에 숨기지 않는다 |
| 12 | C18 을 구속 기준으로 **안 올린다** | `AskUserQuestion` 실측 — 경성 상한은 `header` 12자 하나뿐이고 나머지는 연성 지침이라 구속할 근거가 안 나온다 |

## Handoff Context

이 설계는 인터뷰 브리프(`source_interview`)를 정답 출처로 삼는다. 브리프 §2 의 27 항목 중 26 이
`confirmed`, **D11 하나만 `provisional`** 이다 — D11 의 술어 셋은 「확정된 문구」가 아니라 「사용자가 고른
방향의 한 표현」으로 다뤄야 한다(§12 OQ-J).

**이 설계가 딛고 선 실측** — 전부 이 세션에서 파일을 읽어 확인한 것이고 추론이 아니다:

- `doc-critic` 층 1 리터럴 여덟 축 = 사본 넷(`:47`/`:49`/`:48`/`:50`), 그것을 붙드는 락 0건
- 사본 넷의 관계 = `copy-of`·`variant-of` 마커 + 락 넷이 동기화 강제
- codex 러너가 `layer_rubric.layer1`·`layer2` 를 읽는다(`:372`·`:373`·`:427`·`:428`)
- `normalize()` 가 고정 10키 dict 를 새로 짓고 모르는 키를 조용히 버린다(`:52-78`)
- `_decision_view` 의 `change` = `it["summary"]`(`:235`)
- `_CHOICE_LABEL` 고정 셋(`docreview_state.py:1091`) · `GATE_ROWS` 는 상태 범주 순(`:537-553`)
- `PROFILE_FIELDS` 닫힌 10-튜플(`:37-39`)
- T13 의 `grep -qF` 세 이름(`test_brief_review_ng3.sh:116-121`) + 머리말이 밝힌 보호 대상(`:10-12`)
- `disposition_lines` 소비자 둘(`synthesize_findings.py:22,482,532` · `synthesize_artifact_findings.py:33,289,313`)
- 네 프로필의 `layer1` 값과 baseline 다섯 파일의 통과 수(§10)
- ponytail HEAD `e3ba2aa`(2026-09-14) 원문 — 7단 정본 · 보호 경계 4문단 · 0건 출구 리터럴 · finding 형식 ·
  태그 다섯 · 금지 어법 · Q7/Q10 부재

**다음 단계** — 이 문서를 `spec-distill:reviewing-spec` 으로 리뷰하고, 그 승인 게이트에서 진행이 선택된
뒤에 `superpowers:writing-plans` 로 간다.

### Deferred to plan

- 프로필 본문의 축 절 **정확한 문구** — 이 문서는 담을 내용과 그 출처를 정했고, 리뷰어가 읽을 최종 산문은
  plan 이 쓴다.
- T13 단언 ④⑤ 의 **셸 구현** — 집합 연산과 불릿 추출을 어떤 관용구로 쓸지(`lay_of` 헬퍼 재사용 여부 포함).
- 골든 픽스처(`shared/tests/fixtures/docreview/golden/`) 갱신 **목록과 순서** — 렌더 변경이 바이트로 고정된
  파일 몇 개를 건드리는지 plan 이 전수 열거한다.
- codex 러너 프롬프트에 두 칸을 싣는 **정확한 자리와 문구**.
- `doc-recritic` 이 `added` finding 에서 두 칸을 내는지의 **왕복 확인 절차**.
- 설치 캐시 동일성 **확인 명령**.
- 각 PR 의 version bump **숫자** — 릴리스 번호는 브랜치가 아니라 머지 직전에 정한다.
