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
두면 / 고치면」을 게이트 렌더의 같은 자리에 싣는다.

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
  - [5.8 게이트 렌더 — 같은 자리에 정보를 채운다](#58-게이트-렌더--같은-자리에-정보를-채운다)
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

| 자리 | 프로필 `layer1` | 리터럴 여덟 축과 | 지금 도는가 |
|---|---|---|---|
| design-doc | `[goal_fit … feasibility]` (8) | 일치 | ✅ |
| brief | `[direction]` (1) | 불일치 | ✅ |
| seed | `[unfounded_addition, example_as_requirement, premature_closure, inference_as_decision]` (4) | 불일치 | ✅ |
| `/qg` generic | `[logic, assumption]` (2) | 불일치 | ❌ **호출자 0** |

**넷째 칸의 실측** — `/qg` generic 자리는 프로필과 링크만 심겨 있고 **아직 아무도 호출하지 않는다**
(`plugins/quality-gates/CHANGELOG.md:115` 「이 릴리스는 `scripts/` 링크 넷만 심고 **아직 `/qg critique` 를
호출하지 않는다** — `generic` 자리 전환은 PR 4」, `:34`·`:36`·`:37` 이 최신 릴리스까지 「호출자는 여전히
0 이다」를 반복). 그래서 **지금 틀린 지시를 실제로 받고 있는 자리는 둘**(brief · seed)이고, generic 은
전환되는 날 같은 결함을 물려받지 않도록 **미리** 고치는 것이다.

**quality-gates 가 PR 1 에서 무엇을 받는가** — 이 플러그인은 `doc-critic*.md` 를 **배송하지 않는다**(사본
넷은 `shared/docreview/agents/` 와 `plugins/spec-distill/agents/` 뿐). 그러나 **`references/docreview-profiles/generic.md` 는
이 플러그인의 배포 트리 안에 있고**, PR 1 이 그 파일에 층 1 판정 관계 한 줄을 넣는다(§5.5·AC3′). 그래서
**PR 1 은 이 플러그인의 배포 바이트를 바꾸며 bump 가 필요하다** — 다만 바뀌는 것은 agent 가 아니라
프로필이고, 그 자리는 아직 호출자가 0 이라 **동작 변경이 아니라 장래 전환을 위한 선반영**이다.

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

**안 준 것** — 아키텍처 층위의 판정 기준이 **없다**(ponytail 저장소 전수 grep 0건). 가장 근접한 `yagni: layer with one
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
- **갈래 1 의 «축»을 `/qg` 로 넓히는 것.** 새 축 `overdesign` 은 `/qg` 의 generic 자리에 안 간다(C2).
  다만 PR 1 의 **참조 전환 수선**은 그 자리의 프로필 본문 한 줄을 함께 고친다 — 수선은 범위 안이고
  축이 범위 밖이다. 갈래 2 에서 `/qg` 로 가는 것은 회계어 번역(ⓒ) 하나다(D25).
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
- **프로필 frontmatter 의 값은 한 줄에서 끝나야 한다.** codex 러너의 파서는 줄 단위라 이어진 줄을
  `profile_parse_ambiguous`(rc 5)로 거부하고, T13 의 `lay_of` 는 `head -1` 이라 첫 줄만 읽는다. Python
  게이트만 PyYAML 이라 통과하므로, 줄바꿈은 **판정자 하나를 조용히 끄는** 변경이다(§5.1 ⚠).

## 5. Architecture

### 5.1 새 축 `overdesign`

```yaml
layer_rubric:                              # brief.md — 1 → 2
  layer1: [direction, overdesign]

layer_rubric:                              # design-doc.md — 8 → 9
  layer1: [goal_fit, problem_definition, scope, architecture, component_relations, data_flow, tradeoffs, feasibility, overdesign]
```

⚠ **`layer1:` 은 반드시 한 줄로 적는다 — 줄바꿈이 판정자 하나를 끈다.** codex 러너의 프로필 파서는
**줄 단위**이고 한 줄 완결만 받는다(`run_docreview_codex_reviewer.sh:302` 의
`re.fullmatch(r"  ([a-z_][a-z0-9_]*): (.+)", line)`) — 이어진 줄은 `:321` 에서
`line outside the line grammar` 로 떨어져 rc 5 `profile_parse_ambiguous` 다. T13 의 `lay_of` 도
`sed … | head -1` 이라 **첫 줄만** 읽어 축을 덜 잰다. 반면 Python 게이트는 PyYAML 이라 **통과한다**
(`docreview_state.py:120-126`). 즉 줄바꿈 하나로 **codex 축만 죽고 락은 조용히 덜 재며 Python 쪽은
GREEN** 이고, 그 죽음이 §7 위험의 「축이 무이빨」 오진으로 읽힌다. 현행 네 프로필은 전부 한 줄이다
(design-doc 은 151자). 이 제약은 §4 「기계적 제약」에 넷째 항목으로 올라간다.

**이름의 근거** — 층 1 축은 리포 관례가 **주제 이름**(`direction`·`goal_fit`·`architecture`)이고 결함
이름은 층 2 관례(`distortion`·`omission`·`invention`)다. `overdesign` 은 사용자가 쓴 낱말 그대로이며
기존 어느 축과도 안 부딪힌다 — 특히 `distortion` 은 **brief 층 2 에 이미 있어**(원문의 뜻이 바뀐 요약)
술어 ②를 그 낱말로 부르면 충돌한다.

**술어 셋과 자리별 배치**

| 술어 | 묻는 것 | 절차·어법의 출처 | brief 자리 | design-doc 자리 |
|---|---|---|---|---|
| ① 과함 | goal 대비 과한가 | ponytail Lazy Ladder + C16 의 기준 둘 | ✅ **§6 사용자 원문의 goal** 대비 | ✅ **브리프 §1 Goal** 대비 |
| ② 왜곡 | 제약을 지키려다 구조가 뒤틀렸나 | **ponytail 에 없음** — D22 · CLAUDE.md Forbidden Patterns | ❌ | ✅ 브리프 §2 확정 제약 대비 |
| ③ 층위 이탈 | 아래 층의 일이 들어왔나 | **ponytail 에 없음** — 리포의 기존 경계 | ✅ | ✅ |

★ **① 의 기준은 두 자리에서 모양이 같다** — 「**상류가 말한 goal**」 대비 과한가다. brief 의 상류는
사용자 원문이고 design-doc 의 상류는 브리프다. 이름이 같은 축이 자리마다 다른 것을 재는 것이 아니라,
**같은 관계를 각자의 상류에 대해** 재는 것이다.

⚠ **기존 `direction` 축과의 구별** — brief 층 1 의 기존 축 `direction` 은 프로필 `ground_truth` 를 쓰지
않는다(리포 실체와 웹 선례로 방향을 **반증**한다). 새 축 `overdesign` 은 그 `ground_truth` 를 **쓴다** — 그리고 그것은
**원문 둘**이다(payload `## 6. 사용자 원문` + `<<<AUDIT-VERBATIM>>>` 뒤 블록). 한쪽만 읽으면 「빠진 것
없음」이 조용히 나온다고 그 프로필이 스스로 경고한다(`brief.md:36`) — 이 브리프만 해도 D11·C16 의
근거(S9·S15)가 audit 쪽 블록에 산다. 한 층 안에 정답 출처가 둘이 되는 것이고, 그 차이가 §5.6 의 락 ⑤ 가
잡는 기준어다.

**② 가 brief 에 없는 이유** — 그 술어의 대상이 구조·구현이고 brief 에는 그것이 없다(D11).

★ **brief 자리의 어법 — 두 계약을 하나로 만족시킨다.** brief 프로필 층 1 은 「finding 하나마다 **사용자가
결정할 질문 하나**를 `summary` 에 담고 처분은 `decide` 다」(`brief.md:20`)를 요구하고, ponytail 은 **헤지형
질문을 금지**하고 사실 서술 + 대체안을 요구한다(§5.2). 둘은 **양립한다** — 대체안을 제시하는 것이 곧
결정 질문을 세우는 것이기 때문이다.

```
❌ ponytail 금지 어법 (헤지형 의문문)
   「이 레이어가 과할 수도 있는데 고려해 보셨나요?」

❌ brief 계약만 만족 (사실도 대체안도 없는 질문)
   「레이어를 남길까요 말까요?」

✅ 둘 다 만족
   「yagni: §5 의 플러그인 레이어, 구현체 하나. 직접 호출로 인라인.
    └ 천장: 둘째 구현체가 생기면 이 판정이 틀린다.」
   → 사실 + 대체안이고, 「인라인할까」가 그 자체로 결정 질문이다
```

규약은 「**결정 질문을 의문문으로 쓰지 말고, 사용자가 고를 두 상태를 사실로 제시해서 세워라**」다.
이 공존은 사용자 원문이 미확인으로 남긴 자리였다(브리프 §6 S1 — 「과설계 축이 그 계약과 어떻게
공존하는지도 보지 않았다」). 여기서 닫는다.

**③ 의 개념은 새 메커니즘이 필요 없다.** design-doc 프로필 층 2 `testing` 이 이미 「자동 검증
**절차**(명령·픽스처·순서)의 부재는 plan 의 일이므로 `defer` 로 낸다」고 적고, ③ 은 그 문장의
**반대 방향**이다.

⚠ **그러나 `defer` 배관은 이 축에서 도달 불가라 ③ 의 처분은 두 자리 모두 `decide` 다.** 엔진이 보호
헤딩 앵커의 `decide` 아닌 처분을 **전부 `decide` 로 승격**하고(`docreview_route.py:416-420`), design-doc 의
`protected_headings` 에 **Architecture 와 AC** 가 들어 있으며, 그 보호가 **하위 소절까지 캐스케이드**된다
(`docreview_anchor.py:9`). 구현이 설계문서로 새는 일은 바로 그 절들에서 가장 자주 생기므로 ③ 의 finding
은 사실상 언제나 승격 대상이다. 설계가 `defer` 를 적어 두면 **plan 이 그 배관을 믿고 만들었다가 실행 시
전부 `decide` 로 올라오는 것**을 보게 된다. brief 자리는 애초에 `defer` 가 없다(`defer_target: {kind: none}`).

부수 효과 — **③ 은 `### Deferred to plan` 으로 자동으로 내려가지 않는다.** 사용자가 채택한 뒤 저자가
손으로 옮긴다. 자동 배관을 되살리려면 `protected_headings` 를 소절 단위로 좁혀야 하는데(§12 OQ-B) 그건
브리프 S5 로 **이번 범위 밖**이다.

★ 이 현상은 **이 리뷰에서 실제로 여섯 번 발동했다** — §5.5·§5.6·§5.9 의 층 2 `fix` 셋이 `## 5.
Architecture` 아래라 `decide` 로 승격됐고(그중 둘은 `evidence` 가 없어 게이트에 `근거: (근거 없음)` 으로
올라왔다), 라운드 2 의 `fix` 셋은 같은 이유로 `check-intent` 가 거부해 다음 라운드 결정으로 상향됐다.
예측이 아니라 관측이다.

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
| `delete:` | 죽은 절 · 안 쓰는 유연성 · 투기적 기능. 대체안: 없음 | ponytail `skills/ponytail-review/SKILL.md:23` |
| `yagni:` | 구현체 하나뿐인 추상 · 아무도 안 쓰는 설정 · 호출자 하나뿐인 층 | ponytail `skills/ponytail-review/SKILL.md:26` |
| `shrink:` | 같은 결론, 더 적은 구조 | ponytail `skills/ponytail-review/SKILL.md:27` |
| `bent:` | 제약 X 를 지키려 구조 Y 가 들어왔는데 X 를 만족하는 더 곧은 길 Z 가 있다 | 리포(D22 · Forbidden Patterns) |
| `altitude:` | 이 문서의 층이 아닌 것이 들어와 있다 | 리포(design-doc 층 2 `testing` 의 반대 방향) |

**대체안은 같은 항목 안에 필수다.** 없으면 빈칸이 아니라 `대체안 없음 — 그냥 뺀다.` 로 **명시**한다
(ponytail `delete:` → `Replacement: nothing.`).

**금지 어법** — ❌「…가 과할 수도 있는데 고려해 보셨나요?」 같은 헤지형 질문. ponytail 이 ❌ 예시로 원문에
박아 둔 어법이다(ponytail `skills/ponytail-review/SKILL.md:31-32`). ✅ 사실 서술 + 대체안.

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
방향이 정의돼 있지 않다(**ponytail 저장소** 전수 grep 확인 — 그 문구는 그 저장소의
ponytail `skills/ponytail/SKILL.md:47` 과 그 바이트 복제본에만 있고 다른 어느 파일도 해소하지 않는다).

| 후보 | 뜻 | 채택 | 이유 |
|---|---|---|---|
| **번호가 작은 쪽** | 더 게으른 단 — 더 많이 자른다 | ✅ | `Stop at the first rung that holds` 와 일관된다. 사다리를 위에서 아래로 훑는 절차이므로 「먼저 성립한 단」과 「작은 번호」가 같은 것을 가리킨다 |
| 번호가 큰 쪽 | 더 많이 짓는 단 | ❌ | 「첫 단에서 멈춘다」와 정면으로 충돌한다 — 두 단이 성립할 때만 큰 쪽을 고르면 절차가 자기 종료 규칙을 어긴다 |

⚠ **이 선택의 대가** — 작은 쪽은 **언제나 더 많이 자르는** 해석이다. 동점마다 판정이 절감 쪽으로 기울므로
이 문서가 §7 위험과 §12 OQ-E 로 스스로 경고한 **「한 방향 압력」을 증폭한다.** 균형 장치는 `└ 천장`(§5.2)
하나뿐이고, 그것은 **줄임을 되돌릴 조건을 적게 할 뿐 줄임 자체를 막지 않는다.** 이 비대칭은 이번 설계에서
해소되지 않는다 — OQ-E 가 그 자리다.

### 5.4 자르지 않는 것 · 0건 출구 · 상한

**오탐 가드 — ponytail 원문 다섯**: trust-boundary 검증 · 데이터 손실 처리 · 보안 · 접근성 · 명시 요청 동작.

**조사가 찾아낸, 브리프가 빠뜨렸던 셋을 더한다** — 원문의 `## When NOT to be lazy` 절은 4문단인데
브리프는 첫 문장만 가져왔다:

- **「사용자가 완전판을 고집하면 짓는다 — 재논쟁 없음」**(ponytail `skills/ponytail/SKILL.md:94-95`). devbrew 의 P23 과 짝이다 —
  근거 **새것**이 있으면 반증, 없으면 재논쟁 금지. 같은 판정을 새 근거 없이 다음 라운드에 다시 내는 것이
  규약 위반이다.
- **「사다리는 해답을 줄이지 읽기를 줄이지 않는다」**(`:97-98`).
- **스코프 배제**(ponytail `skills/ponytail-review/SKILL.md:52-54`) — 이 축은 **과함만** 본다. 충실도·방향의 결함은 다른 축이 낸다.

**devbrew 자리의 것** — Law 1·2·3 과 kill switch(P21 보안 컨트롤)는 어떤 모드에서도 안 자른다.

**0건 출구 — 이 축에만 걸린다.** `overdesign` finding 이 하나도 없으면 그 축의 자리에 「이 문서는 이미
최소다.」 **한 줄만** 적는다. 정당화도 「찾아봤으나 없음」 서술도 붙이지 않는다.

⚠ **이식은 부분적이다.** 원문의 `If there is nothing to cut, say 'Lean already. Ship.' and stop.` 은
**리뷰 전체**를 끝내라는 뜻이다. 우리 자리에서는 그럴 수 없다 — `doc-critic` 은 `docreview-layer1`·
`docreview-layer2` 두 블록을 **항상** 내야 하고, 층 1 블록이 없으면 엔진이 `critic_dead`(주 판정자 사망)로
읽어 라운드가 「미검증」으로 닫힌다(`docreview_route.py:156-168`). 과설계가 0건이어도 기존 축의 결함은
있을 수 있다. 그래서 0건 규약은 「**이 축의 finding 을 지어내지 않는다**」로만 한정하고 두 블록을 모두
낸다는 기존 출력 계약은 그대로 둔다 — `and stop.` 은 **가져오지 않는다.**

**상한 N = 3.**

- **재는 것** — 한 판정자가 한 라운드에 낼 수 있는 이 축의 finding 수다.
- **근거** — 게이트가 `AskUserQuestion` 을 **4개씩** 나눠 부르므로(`reviewing-document.md:28`), 3 이면
  **판정자 하나가 한 호출을 혼자 채우지 못한다.**
- **약속하지 않는 것** — 라운드 총량이다. 상한은 **판정자별**이라 총량은 **2N+α** 이고, 판정자 둘이 각각
  3건이면 6건이라 한 호출의 네 질문이 전부 이 축일 수 있다. 게이트는 상태 범주와 id 순으로만 정렬하고
  **축별 자리를 예약하지 않는다** — 그런 배치 보장은 엔진 변경이라 이번 범위 밖이다(§3 Non-goal).
- 초과분은 한 묶음으로 남기고, **무엇을 잘랐는지 한 줄로 적는다.**

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

> - **층 1** — 프로필 `layer_rubric.layer1` 의 항목으로 본다. **무엇과 대조하는지는 그 프로필이 말한다.**
>   리포 사실을 단정하는 finding 은 파일·심볼을 실제로 읽어 확인한 근거를 `evidence` 에 인용한다.

**「`ground_truth` 와 정합한가」를 agent 본문에 남기지 않는다.** 그 관계는 **design-doc 자리의 것**이지
네 자리 공통이 아니다 — brief 층 1 은 `ground_truth` 를 안 쓰고(리포 실체와 웹 선례로 방향을 반증),
generic 은 `ground_truth: "문서 자체 — 외부 정답이 없다"` 라 그 문장이 「문서와 문서가 정합한가」로
공허해진다. 축 이름만 프로필로 넘기고 판정 관계를 리터럴로 두면 **넷 중 하나에만 맞던 문장이 넷 중
둘에만 맞는 문장**이 될 뿐이다. 그래서 각 프로필 본문이 자기 자리의 판정 관계를 한 줄로 소유한다 —
이것이 PR 1 이 agent 사본 넷과 **프로필 넷**을 함께 건드리는 이유다.

**근거 요구의 조건절은 그대로 둔다.** 원래 문장은 「**구현 가능성** finding 은 …」으로 **축 이름에 묶여**
있었고, 축이 사라지면 같이 사라졌다. 바뀐 문장은 「**리포 사실을 단정하는** finding 은 …」으로 **축과
무관**해진다 — 조건은 남되 그 조건이 더 이상 축 이름이 아니다. 「예외 없이 모든 층 1 finding」으로 넓히지
않는다: 문서 내부 모순처럼 리포를 볼 필요가 없는 finding 에까지 리포 인용을 요구하면 그 판정이 갈 곳을
잃는다. **AC3 이 재는 것은 「근거 요구가 축 이름에 더 이상 묶여 있지 않다」이다.**

**이것은 부수효과가 아니라 수선이다.** 네 자리 중 **둘**(brief · seed)이 지금 틀린 층 1 지시를 실제로
받고 있고, 같은 라운드의 두 판정자가 서로 다른 rubric 으로 돈다(`/qg` generic 은 아직 호출자가 0 이라
장래의 자리다 — §1.1). 그 리터럴 줄을 붙드는 락은 **하나도 없다**(테스트 전수 grep 0건).
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
| ③ | brief 층 2 ∩ design **층 2** = ∅ | 기존 유지 — 현행 락이 대조하는 것이 `L2_D` 하나다(`L1_D` 는 그 루프에 안 들어간다). 「층 1·2」로 넓히는 것은 기존 유지가 아니라 신설이므로 여기 적지 않는다 |
| ④ | **brief 층 1 ∩ design 층 1 ⊆ SHARED** · `SHARED = {overdesign}` 을 락 파일이 명시 열거 | **신설 — fail-open → fail-closed** |
| ⑤ | **SHARED 의 각 축이 두 프로필 본문에서 서로 다른 문장으로 정의된다** | 신설 |

④ 가 실질이다 — 지금은 **금지 셋**이라 그 밖은 전부 통과하고, 바꾸면 **허용 목록**이라 목록 밖 공유는
전부 걸린다. ⑤ 는 「같은 이름이되 재는 대상이 다르다」를 기계로 붙든다: 두 불릿이 둘 다 실재하고(양의 짝)
→ 문자열이 다르며 → 각자 **자기 상류**를 기준어로 담는다.

| 자리 | ⑤ 가 그 불릿에서 찾는 기준어 | 그것이 가리키는 것 |
|---|---|---|
| brief | 「사용자 원문」 계열 | `brief.md` 의 `ground_truth` = **원문 둘** — payload `## 6. 사용자 원문`(S1) **과** `<<<AUDIT-VERBATIM>>>` 뒤 블록(audit §6 의 S2 이상) |
| design-doc | 「브리프 §1 Goal」 | `source_interview` 가 가리키는 파일의 §1 |

§5.1 의 표와 이 표는 **같은 것을 말한다** — ① 은 두 자리 모두 「상류가 말한 goal 대비 과한가」이고,
상류만 다르다. 새 축이 brief 의 `ground_truth` 를 쓴다는 점에서 **기존 `direction` 축과 갈린다**(그쪽은
리포·웹 선례를 쓴다) — 한 층 안에 정답 출처가 둘이 되는 것이고, ⑤ 가 붙드는 것이 바로 그 구별이다.

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

### 5.8 게이트 렌더 — 같은 자리에 정보를 채운다

```
지금                                        바꾼 뒤
[decide] f3 — <summary>                     [decide] f3 — <summary>
  변경: <summary>       ← 헤더 복사·정보 0     그대로 두면: <if_unfixed>
  근거: <evidence>                            고치면: <replacement>
  대안: 채택/기각/보류   ← 모든 항목 동일       근거: <evidence>
  영향: <anchor> · 인용 N                     자리: <anchor> (<category>) · 인용 N
                                              대안: <상태에 맞는 라벨 셋>
```

- **「변경」이 사라지고 「그대로 두면 / 고치면」 둘로 갈린다.** 헤더가 「무엇이 문제인가」, 두 줄이 「두면 /
  고치면」 — 동어반복이 원리적으로 불가능해진다.
- **「영향」 → 「자리」**: anchor + 인용수는 영향이 아니라 위치다. 이름을 정직하게 바꾸고 `category` 를
  함께 싣는다 — 지금 렌더에 한 번도 안 나오는 값이라 「왜 문제인가의 부류」가 처음으로 보인다.
- **「대안」 줄은 항상 낸다.** 조건부로 내지 않는다 — 그 줄이 기존 락 하나의 **발동 조건**이기 때문이다.
  `cases.sh:558` 이 「평범한 open decide 에서 『대안:』 줄과 `decide_choices` 가 같은 집합」(「제안 = 수용」
  등식)을 단언하고, 줄이 사라지면 `offered` 가 빈 집합이라 RED 다. 그 단언을 지우면 평범한 항목에 대한
  렌더-측 채널이 통째로 사라진다 — `docreview_state.py:1128-1138` 이 `_rg_expired` 에서 **똑같은 실패를
  이미 한 번 고쳤다**(「우연히 일치했을 뿐 그 함수를 쓰지 않았다」). 밀도는 그 줄을 **지워서**가 아니라
  아래의 상태별 라벨로 **정보량을 채워서** 얻는다.

**부재를 두 가지로 가른다** — 침묵과 판정은 다른 사실이다:

| 상황 | 「그대로 두면」 | 「고치면」 |
|---|---|---|
| 리뷰어가 칸을 안 채웠다 | `(리뷰어가 안 적음)` | `(대체안 미작성)` |
| 리뷰어가 「그냥 빼라」고 판정했다 | — | `대체안 없음 — 그냥 뺀다` |

두 줄이 **같은 모양**으로 침묵을 공시한다. 이전 판은 두 경우에 같은 글자(`대체안 없음 — 그냥 뺀다`)를
냈는데, 그러면 **아무도 제안하지 않은 삭제**가 사용자에게 제안으로 전달된다. 이 경로는 리뷰어 실수에
한정되지 않는다 — `_auto_decides` 가 내는 `frozen_change` 는 애초에 `replacement` 가 없다. 리뷰어가
삭제를 제안할 때는 **명시적으로** 그렇게 쓰게 하는 규약을 프로필에 함께 넣는다(ponytail `delete:` →
`Replacement: nothing.` 과 같은 자리).

**회계어 — 사람말을 앞에 두되 상태에 맞게 쓴다**(ⓒ 의 문서 자리):

```
지금  (모든 상태 동일)
  채택(적용) / 기각(원복) / 보류

바꾼 뒤
  kind=pre  (리뷰어가 제안한 변경)
    고친다(채택) / 그대로 둔다(기각) / 나중에 정한다(보류)
  kind=post (저자가 이미 고쳐 얼림 검사가 잡은 변경)
    현재 변경 유지(채택) / 이전 상태로 원복(기각) / 나중에 정한다(보류)
```

⚠ **라벨이 상태의 함수여야 하는 이유** — `cmd_decide`(`docreview_state.py:739-750`)는 `kind=post` 에서
`reject` 를 고르면 **revert permit 을 만들고**, `adopt` 를 고르면 현재 변경을 유지한 채 `applied` 로
닫는다. 그 자리에서 「그대로 둔다」는 실제로 **원복**이다. 상태를 모르는 고정 라벨을 사람말로 바꾸면
**동작을 반대로 설명**하게 되고, 그것은 D13-① 을 정면으로 위반한다 — 이 설계가 고치려는 결함을 새로
만드는 셈이다. 그래서 `_CHOICE_LABEL` 은 단순 상수에서 `decide_choices` 와 같은 모양의 **상태 함수**가
된다. 회계어(`채택`·`기각`·`보류`)는 괄호 안에 **그대로 보존**된다(D21 의 「낱말은 그대로 두고」).

**밀도 회계** — **줄 수는 다섯으로 같다.**

| 줄 | 지금 | 바꾼 뒤 |
|---|---|---|
| 1 헤더 | `summary` | `summary` |
| 2 | **변경** = 헤더 복사 → 정보 0 | **그대로 두면** = `if_unfixed` → 항목별 |
| 3 | 근거 = `evidence` | 고치면 = `replacement` → 항목별 |
| 4 | **대안** = 전 항목 동일 → 정보 0 | 근거 = `evidence` |
| 5 | 영향 = anchor + 인용수 | 자리 = anchor + **`category`** + 인용수 |
| 6 | — | 대안 = **상태에 맞는** 라벨 셋 → 상태별 |

**줄 수를 말하는 자리는 이 표 하나다** — 앞선 라운드에서 같은 수가 절 제목·머리말·목차·AC·e2e 문장에
복제돼 있다가 결정이 뒤집혔을 때 한 자리만 고쳐져 모순이 났다. 그 복제를 없앴으니 수는 여기서만 읽는다.

지금 다섯 줄 중 실효 정보는 **셋**. 바꾼 뒤 여섯 줄 중 정보 0 인 줄은 **없다**. 줄이 하나 늘지만 늘어난
줄은 **락의 발동 조건**이고, 사라진 것은 동어반복 한 줄이다 — **글이 아니라 정보를 늘린다**(C18).

**D13 세 기준과의 대응**

| 기준 | 무엇이 닫는가 |
|---|---|
| ① 라벨만 읽고 고른다 | 라벨이 **상태별**이 되어 어느 자리에서도 참이고(`고친다(채택)` vs `현재 변경 유지(채택)`), 그 위에 **`— <replacement 압축>` 을 붙이는 것이 필수다** — 「무엇이 바뀌는가」가 라벨에 없으면 이 기준이 원리적으로 안 닫힌다. `label` 은 1–5 낱말 예산 안에 들어가야 하므로 압축 규칙이 함께 선다 |
| ② 안 바뀐 것은 안 보인다 | 동어반복 줄 제거 + 「그대로 두면」이 결과를 말함 + 침묵과 삭제 제안이 갈림 |
| ③ 용어가 처음 보는 말이 아니다 | 사람말을 앞으로 + `category` 를 사람말로 |

### 5.9 `/qg` 의 회계어

고칠 자리는 `shared/adjudication/render_disposition.py` **한 파일**, 소비자는 **둘**이다
(`synthesize_findings.py` · `synthesize_artifact_findings.py` — 실측 확인).

```
**처분:** 수용 0 · 기각 1 · 억제 1 · 흡수 0 · 미판정 1     (차단 아님)
**배관 손실:** 1 · 셀 수 없음 0     (차단: 예)
↳ 억제=규칙이 자른 것 · 흡수=같은 것끼리 합친 것 · 미판정=볼 사람이 없던 것
  · 배관 손실=입력이 죽었거나 항목이 깨졌거나 값을 보정한 것      ← 이 줄만 추가
```

풀이 줄은 **별도 반환값**이다(AC21) — 처분 줄도 배관 줄도 아닌 셋째 줄이라 어느 한쪽 문자열 안에 개행으로
넣지 않는다. 그 낱말들이 두 줄에 걸쳐 있기 때문이다.

**「읽히기」 기준 셋**(D25 가 요구한 `/qg` 자리의 기준 — D13 셋은 「고르기」를 재므로 여기 안 쓴다):

| # | 기준 | 지금 상태 |
|---|---|---|
| 1 | 한 줄만 읽고 「막혔는가」를 안다 | **이미 만족** — `(차단: 예/아니오)` 리터럴 |
| 2 | 모르는 낱말이 남지 않는다 | **미달** → 풀이 줄이 회계어 넷을 푼다 |
| 3 | `0` 이 「없었다」인지 「못 봤다」인지 구분된다 | **이미 만족** — `미판정`·`셀 수 없음` 두 칸 |

셋 중 둘이 이미 만족돼 있으므로 `/qg` 에 필요한 실제 변경은 **한 줄**이다.

**이 셋을 고른 이유와 버린 후보** — 기준은 D25 가 「따로 세우라」고만 했고 내용은 이 설계가 정한다.

| 후보 | 채택 | 이유 |
|---|---|---|
| 한 줄만 읽고 「막혔는가」를 안다 | ✅ | 이 출력의 **유일한 행동 유발 정보**가 차단 여부다 |
| 모르는 낱말이 남지 않는다 | ✅ | 사용자가 든 난점 ⓒ(회계어) 그 자체 |
| `0` 이 「없었다」인지 「못 봤다」인지 구분된다 | ✅ | 이 모듈의 docstring 이 스스로 「칸의 합계와 차단은 같은 집합이 아니다」로 경고하는 자리 |
| 분량 상한(예: 두 줄 이내) | ❌ | D19 — 사용자가 분량 기준을 고르지 않았다. C18 도 비구속 선호다 |
| 용어 사전 링크 | ❌ | `/qg` 출력은 터미널 텍스트라 링크가 안 눌린다 |
| 칸마다 예시 수치 | ❌ | 같은 길이에 정보를 늘리는 것이 아니라 길이를 늘린다(C18 위반) |

버린 셋은 전부 **읽는 사람이 이 출력으로 할 수 있는 일을 안 늘린다.** 이것이 세 기준의 공통 축이다.

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
      if_unfixed / replacement → 그대로, 비면 «침묵»을 공시
      basis   → evidence
      impact  → anchor + nref + category
          ↓
docreview_state.py  record_findings()      ← ★ 세 번째 관문 (PUBLIC_FIELDS)
      st["findings"][fid] = {k: it.get(k) for k in PUBLIC_FIELDS}   (:625)
      PUBLIC_FIELDS 에 top-level replacement·if_unfixed 가 «없다» (:516-518)
      → 원장에 살아남는 통로는 `decision_view` 하나뿐이다
          ↓
docreview_state.py  _rg_decide()  게이트 텍스트 여섯 줄
          ↓
오케스트레이터가 AskUserQuestion 을 4개씩 조립
      label       ← replacement 를 1–5 낱말로 압축
      description ← 그대로 두면 / 고치면 / 근거
```

codex 쪽은 러너가 `layer_rubric.layer1` 을 읽어 같은 축을 프롬프트에 싣는다. codex finding 은
`normalize(it, 2, "x", i, L)` 로 같은 정규화를 거치므로 **같은 두 칸을 낼 수 있다** — 러너 프롬프트에 그
두 칸을 더해야 실제로 나온다.

★ **닫힌 열거가 셋이다.** `PROFILE_FIELDS`(프로필 frontmatter) · `normalize()` 의 반환 10키(리뷰어 →
라우터) · `PUBLIC_FIELDS`(라우터 → 원장). 앞의 둘만 보고 칸을 더하면 렌더까지는 도달하지만 **상태
파일에는 안 남아** 다음 라운드가 그 값을 못 본다.

⚠ **`decision_view` 통로는 `decide` 에만 열린다.** `docreview_route.py:640-641` 이
`if it["disposition"] == "decide":` 일 때만 그 키를 달므로, **`fix`·`defer`·`ask` 로 난 `overdesign`
finding 의 두 칸은 원장에 한 글자도 안 남는다.** 그런데 §5.2 는 「대체안은 같은 항목 안에 필수」를
**처분과 무관하게** 요구한다 — 두 요구가 지금 어긋나 있다.

★ **해소는 이 설계가 정한다 — `PUBLIC_FIELDS` 에 두 칸을 top-level 로 더한다.** 그러면 `fix`·`defer`·
`ask` 로 난 항목의 대체안도 원장에 남는다. plan 에 미루지 않는 이유는 둘이다 — ① 미루면 **아무것도 안
하는 쪽이 기본값**이고 그것이 곧 「조용히 버려지는 쪽」이다 ② `### Deferred to plan` 에 그 선택이 없어
미룬다는 사실조차 안 남는다. 기각한 대안은 §5.2 의 「필수」를 `decide` 에만 거는 것인데, 그러면 `fix` 로
난 과설계 지적이 대체안 없이 저자에게 가서 ponytail 이식의 핵심(지적과 대체안을 한 항목에)이 그 경로에서
빠진다.

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
  문자열로 CI 핀 고정한다(ponytail `scripts/check-rule-copies.js:49-57`).
- **rubric 항목 수 증가** — brief 1→2 · design-doc 8→9. 체크리스트 항목 수를 늘리면 평가자 간 신뢰도가
  떨어진다(«checklist-length-reliability»).
- **상한의 무이빨** — 프로필에 담을 필드가 없어 **강제 없는 산문**이다. 지켜지는지 셀 수단이 없다. 한계이지
  해결이 아니다.
- **설치 캐시** — 실행 시 agent 정의는 리포가 아니라 **설치 캐시**에서 온다. 리포만 고친 e2e 는 옛 리터럴
  축으로 돌고, 0건 출구가 그 오진을 감춘다.
- **T13 ⑤ 의 바이트 판정** — 두 불릿을 무의미하게 다르게 써도 통과한다.
- **줄번호 앵커의 연쇄** — `check_wiring.py` 의 `EXEMPT` 가 줄번호를 키로 쓰므로 `docreview_route.py`
  앞부분을 건드리는 **모든** 변경이 그 키들을 민다. 같은 파일이 이 일을 이미 한 번 겪었다고 스스로
  기록해 두었다 — 이번 PR 3 이 두 번째다. 재앵커를 빠뜨리면 **무관해 보이는 락**이 RED 로 나고, 그
  RED 를 「원래 그렇던 것」으로 오해하면 회귀가 그 뒤에 숨는다.
- **외부 저장소 경로가 리포 경로로 읽힌다** — 이 문서는 devbrew 파일과 **ponytail 저장소** 파일을 둘 다
  인용한다. ponytail 쪽 경로(`skills/…`·`scripts/check-rule-copies.js`)는 이 워크트리에 **없다**.
  **규약: ponytail 쪽 인용에는 반드시 `ponytail ` 접두를 붙인다.** 안 붙이면 하류가 devbrew 에서 찾다
  실패하고 「경로가 틀렸나」로 시간을 쓴다 — 같은 이유로 「리포 전수 grep」처럼 어느 저장소인지 모호한
  표현도 쓰지 않는다.
- **한 층 안의 정답 출처 둘** — brief 층 1 에서 `direction` 은 리포·웹 선례를, `overdesign` 은
  `ground_truth`(사용자 원문)를 쓴다. 같은 층의 두 축이 다른 정답을 쓰는 것은 이 리포에 **선례가 없다**.
  리뷰어가 둘을 섞어 판정할 위험이 있고, T13 ⑤ 는 프로필 본문의 문구만 잴 뿐 **리뷰어의 실제 판정이
  어느 출처를 썼는지는 못 잰다.**

## 8. Acceptance Criteria

**PR 1 — 수선**

- **AC1** `shared/docreview/agents/doc-critic.md` 의 층 1 불릿이 리터럴 여덟 축 열거를 담지 않고
  `layer_rubric.layer1` 을 참조한다.
- **AC2** 사본 넷이 동기화돼 `test_copy_of_contract.sh`·`test_variant_of_contract.sh`·
  `test_docreview_agents.sh`·`test_brief_agents.sh` 가 전부 GREEN 이다.
- **AC3** 근거 요구가 **축 이름에 묶여 있지 않다** — 바뀐 문장의 조건이 「구현 가능성 finding」이 아니라
  「리포 사실을 단정하는 finding」이고, `layer_rubric.layer1` 에서 `feasibility` 를 빼도 그 요구가 살아남는다.
- **AC3′** 네 프로필(brief · design-doc · seed · generic) 본문이 각자 **자기 자리의 층 1 판정 관계**를 한 줄로
  갖고, agent 본문에는 그 관계가 리터럴로 남지 않는다 — `doc-critic*.md` 에 `ground_truth` 와 문서의
  정합을 단정하는 문장이 0건.
- **AC4** 이 PR 이 새 축을 **어느 프로필에도 더하지 않는다** — `git diff` 에 `overdesign` 이 0회.

**PR 2 — 갈래 1**

- **AC5** `brief.md` 의 `layer_rubric.layer1` 이 `[direction, overdesign]` 이고 `design-doc.md` 의 것이
  기존 여덟에 `overdesign` 을 더한 아홉이다. **기존 여덟 축의 이름과 불릿 문구는 한 글자도 안 바뀐다.**
- **AC6** 두 프로필 본문의 `overdesign` 불릿이 서로 **다른 문장**이고, brief 쪽은 술어 ①③ 을,
  design-doc 쪽은 ①②③ 을 담는다.
- **AC7** 두 프로필 본문에 태그 다섯(`delete:`·`yagni:`·`shrink:`·`bent:`·`altitude:`)과 판정 한 줄의
  형식, 금지 어법, `└ 천장` 규약이 적혀 있다. `bent:` 는 design-doc 에만.
- **AC7′** **brief 프로필 본문**에 두 어법 계약의 공존 문장이 적혀 있다 — 「결정 질문을 의문문으로 쓰지
  말고, 사용자가 고를 두 상태를 사실로 제시해서 세워라」. 그 자리는 기존 계약(「finding 하나마다 사용자가
  결정할 질문 하나」)과 ponytail 의 헤지형 질문 금지가 만나는 지점이라, 안 실리면 리뷰어가 런타임에
  모순을 스스로 푼다.
- **AC8** 두 프로필 본문에 Lazy Ladder 문서판 5단과 「성립하는 첫 단에서 멈춘다」·「두 단이 성립하면 번호가
  **작은** 쪽」이 적혀 있다.
- **AC9** 두 프로필 본문에 자르지 않는 것 여덟(ponytail 다섯 + 재논쟁 금지 + 읽기는 안 줄인다 + 스코프
  배제)과 devbrew 의 것(Law 1·2·3 · kill switch)이 적혀 있다.
- **AC10** 두 프로필 본문에 0건 출구 문구 한 줄과 「정당화를 붙이지 않는다」가 적혀 있고, 그 규약이
  **`overdesign` 축에만** 걸린다는 것과 **두 sentinel 블록은 그래도 낸다**는 것이 함께 적혀 있다.
  `and stop.` 에 해당하는 문구는 **없다**.
- **AC11** 두 프로필 본문에 상한 N=3 과 그 근거(「판정자 하나가 한 호출을 혼자 채우지 못한다」), 초과분
  묶음, 「무엇을 잘랐는지 한 줄」이 적혀 있고, **라운드 총량은 2N+α 이며 이 수단이 총량을 약속하지
  않는다**는 것과 **그것이 강제되지 않는다는 사실**이 함께 적혀 있다. 「한 호출을 통째로 먹지 않는다」는
  문구는 **없다**(2N+α 로 반증되므로).
- **AC12** `test_brief_review_ng3.sh` 의 T13 이 §5.6 의 단언 다섯을 갖고, `SHARED = {overdesign}` 을 명시
  열거한다. 기존 단언 ①②③ 은 그대로 남는다.
- **AC13** `PROFILE_FIELDS` 와 `layer_rubric` 의 키 둘(`layer1`·`layer2`)은 안 바뀐다 — **이 PR 의**
  `git diff` 에 `docreview_state.py` 가 0줄. (PR 3 은 같은 파일의 다른 자리를 고친다.)

**PR 3 — 갈래 2**

- **AC14** `normalize()` 가 `replacement`·`if_unfixed` 두 키를 반환 dict 에 싣는다. 부재면 `None`.
- **AC15** `_decision_view()` 가 `change` 키를 내지 않고 `if_unfixed`·`replacement` 를 낸다. 둘 중
  어느 것이 비어도 **`summary` 로 메우지 않고** 부재를 말하는 리터럴을 낸다 — `if_unfixed` 부재는
  `(리뷰어가 안 적음)`, `replacement` 부재는 `(대체안 미작성)` 이고, **`대체안 없음 — 그냥 뺀다` 는
  리뷰어가 그 문자열을 실제로 낸 경우에만** 난다(`_auto_decides` 의 `frozen_change` 는 `replacement` 가
  없으므로 이 경로로 내려간다).
- **AC16** `_rg_decide()` 가 헤더 + `그대로 두면`·`고치면`·`근거`·`자리`·`대안` 을 내고,
  `자리` 줄이 `category` 를 담는다. **`대안` 줄은 항상 난다** — `cases.sh:558` 의 「제안 = 수용」 단언이
  변경 전후로 GREEN 을 유지하는 것이 이 AC 의 증거다.
- **AC17** 선택지 라벨이 **`kind` 의 함수**다 — `pre` 는 `고친다(채택) / 그대로 둔다(기각) / 나중에
  정한다(보류)`, `post` 는 `현재 변경 유지(채택) / 이전 상태로 원복(기각) / 나중에 정한다(보류)`.
  세 회계어(`채택`·`기각`·`보류`)가 모든 라벨의 괄호 안에 그대로 있다.
- **AC17′** `post` 자리에서 「그대로 둔다」로 읽히는 라벨이 **하나도 없다** — `cmd_decide` 가 `post` 의
  `reject` 에 revert permit 을 만들기 때문이다. 이 단언은 `kind=post` 픽스처 위에서 돈다.
- **AC18** 게이트 렌더 머리에 `GATE_ROWS` 순서의 뜻 한 줄이 난다. (선택지 셋은 항목마다 `대안` 줄이
  내므로 머리에 중복해 적지 않는다.)
- **AC18′** 같은 `anchor` 의 열린 항목은 **GATE_ROWS 순서상 우연히 인접할 때만** 묶음 마커가 붙는다 —
  id prefix `sha1(layer|category|anchor)`(`_bucket()`, `docreview_route.py`)가 `anchor` 뿐 아니라
  `category` 도 섞어 버킷을 가르므로, 같은 `anchor` 라도 `category` 가 다르면(이 기능이 만드는 가장
  흔한 입력 — `overdesign` 항목과 `architecture` 항목이 한 자리를 짚는 경우) 인접 여부가 **그 둘의
  버킷 사이에 다른 항목의 버킷이 끼는지에 달렸다** — 열린 항목이 그 둘뿐이면 사이에 낄 것이 없어
  인접이 강제돼 마커가 붙지만, 버킷이 그 사이에 오는 항목이 하나만 더 열려도 갈라져 마커가
  **안 붙는다.** **이 AC 는 인접을 보장하지 않는다** — 첫 절(「한 덩어리로 묶여 렌더된다」는 보장)은
  철회됐다(P23 재결정, 아래 결정 기록 참조). `GATE_ROWS` 의 순서 자체는 **재정렬하지 않는다** — §5.7
  「새 순위를 매기지 않는다」(오케스트레이터가 순위를 매기면 그 자체가 판단이라 사용자 동의가 없으면
  매길 수 없다). 질문 수와 항목별 선택권은 그대로다(D24) — `AskUserQuestion` 질문 수가 **마커 유무와
  무관하게** 같음을 함께 잰다.
- **AC19** `doc-critic`·`doc-critic-web` 출력 스키마에 두 칸이 적혀 있고, 「`decide` 에는 `replacement`
  필수」와 「**삭제를 제안할 때는 «대체안 없음 — 그냥 뺀다» 를 명시적으로 쓴다**」가 적혀 있다. 칸을 비우는
  것은 삭제 제안이 **아니다.**
- **AC19′** `자리` 줄의 `category` 가 **사람말 사상**을 거쳐 난다. 사상 코퍼스는 **네 프로필**(brief ·
  design-doc · seed · generic)의 층 1·2 축 전부 **+ 엔진이 직접 만드는 category**(`frozen_change` 등
  `docreview_route.py:443`)다 — 렌더는 프로필별이 아니라 엔진 하나라, 두 프로필로 좁히면 **가장 흔한
  항목**(얼림 검사가 잡은 변경)이 상시 advisory 경로가 되어 D13-③ 이 거기서 안 닫힌다. 사상에 없는
  이름이 오면 원래 이름을 그대로 내되 그 사실을 advisory 로 공시한다(조용히 빈칸으로 두지 않는다).
- **AC19″** `doc-recritic`·`plugins/spec-distill/agents/doc-recritic.md` 의 `added` 출력 형식에도 두 칸이
  적혀 있다 — AC19 와 대칭이다. `added` 는 critic 항목과 같은 `normalize()` 를 지나므로
  (`docreview_route.py:315`) 칸을 실을 수 있고, **그것을 내라고 적는 자리는 agent 본문뿐**이다.
- **AC17″** 최종 `AskUserQuestion` 의 각 선택지 `label` 이 **그 항목에서 무엇이 바뀌는지**를 담는다 —
  상태별 라벨 + `— <replacement 압축>`. 같은 라운드의 두 항목이 **같은 `label` 을 갖지 않는다**(단,
  `replacement` 가 둘 다 부재면 그 부재 표기가 같을 수 있고 그때는 이 단언이 공허하지 않도록 부재
  건수를 함께 공시한다).
- **AC21′** `PUBLIC_FIELDS` 에 `replacement`·`if_unfixed` 가 top-level 로 있고, **`decide` 가 아닌
  처분**(`fix`·`defer`·`ask`)으로 기록된 finding 을 저장 → 재조회했을 때 두 칸의 값이 유지된다.
- **AC20** codex 러너 프롬프트가 두 칸을 요구한다.
- **AC21** `render_disposition.py` 의 `disposition_lines()` 가 회계 낱말 여덟을 **그대로 둔 채** 풀이 줄을
  하나 더 낸다. 반환은 `(처분줄, 배관줄, **풀이줄**, advisory목록)` **4-튜플**이다 — 풀이 줄이 두 줄
  모두의 낱말을 풀므로 어느 한 줄 안에 개행으로 욱여넣지 않는다. 기존 위치 언패킹은 `ValueError` 로
  **소리 내며** 깨진다(조용히 넘어가지 않는다).
- **AC22** `/qg` 의 두 소비자가 4-튜플을 받아 세 줄을 함께 낸다. 두 소비자 밖에 이 함수를 부르는 자리가
  없음을 같은 PR 에서 전수 확인한다.

**전 PR 공통**

- **AC23** 착수 전 baseline(§10)의 **모든** 파일이 GREEN 을 유지한다. 새 RED 는 0. baseline 목록은
  「내가 고칠 파일」이 아니라 「**내 변경이 닿는 코퍼스를 읽는 스위트 전부**」로 도출한다 — 리터럴을
  복제한 픽스처와 줄번호로 앵커된 판정기를 포함한다.
- **AC25** PR 들은 **1 → 3 → 2** 순으로만 머지한다(§9 의 두 사고 표가 그 근거다). 순서가 지켜졌음을 각 PR 본문이 선행 PR 번호로 명시한다.
- **AC24** 각 PR 이 건드린 플러그인의 `plugin.json` version bump 와 `CHANGELOG.md` 항목을 **같은 커밋**에
  담는다.

## 9. Files to Modify

★ **머지 순서는 1 → 3 → 2 이고 계약이다**(AC25). 「분할했다」가 「순서가 없다」를 뜻하지 않는다 — 실측:

| 잘못된 순서 | 무슨 일이 일어나는가 |
|---|---|
| 2 가 1 보다 먼저 | Claude `doc-critic` 은 여전히 리터럴 여덟 축을 보므로 **새 축이 codex 쪽에서만 돈다** — 두 판정자가 다른 rubric 으로 돌고 「축이 무이빨」로 오진된다 |
| 2 가 3 보다 먼저 | 프로필이 「대체안은 같은 항목 안에 필수」를 심는데 그 대체안을 실어 나를 `replacement` 칸이 아직 없다 — `normalize()` 가 **조용히 버린다**(§1.2) |

**두 사고가 둘 다 「2 가 늦어야 한다」를 말한다.** 그래서 축(PR 2)이 **맨 뒤**다:

```
PR 1  참조 전환        ← doc-critic/codex 분기를 먼저 없앤다
PR 3  칸 둘 + 렌더      ← 축이 쓸 배관을 미리 깐다
PR 2  축 + 프로필 + 락  ← 배관이 준비된 위에 축이 선다
```

**PR 3 이 PR 2 보다 앞서는 창의 성질** — 그 사이에는 `replacement`·`if_unfixed` 칸이 존재하지만 그것을
채우라고 적는 프로필 규약이 아직 없다. 리뷰어가 안 채우면 렌더가 `(대체안 미작성)` 을 낸다 — **그것이
바로 §5.7 의 원칙(「강제할 수 없으면 보이게 한다」)이 작동하는 모습**이지 결함이 아니다. 반대 창(2 가
3 보다 앞)에서는 규약이 요구한 값이 `normalize()` 에서 **조용히 사라진다** — 같은 불완전이 한쪽에서는
보이고 한쪽에서는 안 보인다. 그 비대칭이 순서를 정한다.

AC13 이 PR 2 를 엔진과 분리하므로 **PR 2 단독 머지가 구조적으로 가능하다.** 그래서 순서를 문서로 못 박는다.

**PR 1 — 수선**

| 파일 | 변경 |
|---|---|
| `shared/docreview/agents/doc-critic.md` | `:47` 층 1 불릿 → `layer_rubric.layer1` 참조 · 판정 관계 리터럴 제거 |
| `shared/docreview/agents/doc-critic-web.md` | `:49` 동일(variant-of 계약이 강제) |
| `plugins/spec-distill/agents/doc-critic.md` | `:48` 동일(copy-of) |
| `plugins/spec-distill/agents/doc-critic-web.md` | `:50` 동일(copy-of) |
| `plugins/spec-distill/references/docreview-profiles/brief.md` | 층 1 판정 관계 한 줄(자기 자리의 것) |
| `plugins/spec-distill/references/docreview-profiles/design-doc.md` | 동일 |
| `plugins/spec-distill/references/docreview-profiles/seed.md` | 동일 |
| `plugins/quality-gates/references/docreview-profiles/generic.md` | 동일 |
| `plugins/spec-distill/plugin.json` · `CHANGELOG.md` | bump + 항목 |
| `plugins/quality-gates/plugin.json` · `CHANGELOG.md` | bump + 항목 (**generic 프로필 본문**을 고치므로 — agent 사본은 이 플러그인에 없다) |

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
| `shared/docreview/scripts/docreview_route.py` | `normalize()` · `_decision_view()` · **`:236` 의 `_CHOICE_LABEL` 소비** |
| `shared/docreview/scripts/docreview_state.py` | `_rg_decide()`(`:1114`) · **`_rg_expired()`(`:1137`)** · `_CHOICE_LABEL`(`:1091`) · **`PUBLIC_FIELDS`(`:516-518`)에 두 칸 추가** · 게이트 머리 |
| `shared/docreview/agents/doc-critic.md` (+ 사본 셋) | 출력 스키마에 칸 둘 |
| `shared/docreview/agents/doc-recritic.md` (+ `plugins/spec-distill/agents/doc-recritic.md`, `copy-of` 락이 강제) | `added` finding 출력 형식에 칸 둘 — `added` 는 critic 항목과 **같은 `normalize()`** 를 지나므로(`docreview_route.py:315`) 칸을 실을 수 있지만, **그것을 내라고 적는 자리는 agent 본문뿐**이다 |
| `shared/docreview/scripts/run_docreview_codex_reviewer.sh` | 프롬프트에 칸 둘 |
| `shared/adjudication/render_disposition.py` | 풀이 줄 추가 · 반환 4-튜플 · docstring 의 반환 서술 갱신 |
| `plugins/quality-gates/scripts/synthesize_findings.py` | 4-튜플 언패킹 (`:482`·`:532` 두 자리) |
| `plugins/quality-gates/scripts/synthesize_artifact_findings.py` | 4-튜플 언패킹 (`:313`) |
| `plugins/quality-gates/tests/test_synthesize_artifact_findings.sh` | 머리말의 「처분 두 줄」 서술 → 세 줄 |
| `shared/docreview/references/reviewing-document.md` | 8단계의 `AskUserQuestion` 조립 규약 |
| `shared/tests/fixtures/docreview/golden/` | 렌더 변경에 따른 골든 갱신 |
| `plugins/quality-gates/tests/test_synthesize_disposition.sh` | 풀이 줄 단언 |
| `shared/tests/fixtures/docreview/cases.sh` | **라벨 리터럴 복제 네 자리**(`:375`·`:490`·`:512`·`:1174`) — 상태별 라벨로 갱신. 이 파일을 `.` 로 읽는 스위트 **여섯**이 함께 움직인다 |
| `tools/adjudication/check_wiring.py` | `EXEMPT` 의 **줄번호 재앵커** — `normalize()`·`_decision_view()` 가 그 키들보다 «위»라 두 칸 추가가 아래 전부를 민다 |
| `shared/tests/test_docreview_mutations.sh` | **`:572`·`:581`·`:612`** 세 자리의 sed 패턴이 `_CHOICE_LABEL` 리터럴을 겨눈다(`:612` 는 `_rg_expired` 를 겨누는 셀) — 같은 파일 `:196-199` 이 「매치 0건으로 조용히 무동작」 함정을 이미 기록해 두었다. **셋을 다 갱신하지 않으면 빠진 셀이 「안 잡힘」이 아니라 「못 잼」으로 조용히 통과한다** |
| `plugins/spec-distill/plugin.json`·`plugins/quality-gates/plugin.json` + 각 `CHANGELOG.md` | bump + 항목 |

## 10. Verification Plan

**baseline — 착수 전 실측(rc 가 아니라 통과 수로).** 2026-09-21 측정:

**목록은 「내가 고칠 파일」이 아니라 「내 변경이 닿는 코퍼스를 읽는 스위트 전부」로 도출한다.** 리터럴을
복제한 픽스처와 줄번호로 앵커된 판정기가 여기 들어간다 — 그것들은 내가 고치지 않아도 **내 변경 때문에
RED 가 된다.**

**실측 완료(2026-09-21)**

| 파일 | baseline | 닿는 PR |
|---|---|---|
| `shared/tests/test_docreview_agents.sh` | 36/36 GREEN | 1 · 3 |
| `shared/tests/test_copy_of_contract.sh` | 188/188 GREEN | 1 · 3 |
| `shared/tests/test_variant_of_contract.sh` | 87/87 GREEN | 1 · 3 |
| `plugins/spec-distill/tests/test_brief_review_ng3.sh` | 21/21 GREEN | 2 |
| `plugins/quality-gates/tests/test_synthesize_disposition.sh` | 11/11 GREEN | 3 |

**아직 안 잰 것 — 착수 전에 반드시 잰다**(리뷰가 찾아낸 누락)

| 파일 | 왜 닿는가 | 닿는 PR |
|---|---|---|
| `shared/tests/test_docreview_state.sh` | `cases.sh` 를 `.` 로 읽는다 | 3 |
| `shared/tests/test_docreview_route.sh` | 〃 | 3 |
| `shared/tests/test_docreview_intent.sh` | 〃 | 3 |
| `shared/tests/test_docreview_anchor.sh` | 〃 | 3 |
| `shared/tests/test_docreview_gate_visibility.sh` | 〃 | 3 |
| `shared/tests/test_docreview_mutations.sh` | 〃 + sed 패턴이 `_CHOICE_LABEL` 리터럴을 겨눈다 | 3 |
| `shared/tests/test_adjudication_wiring.sh` | `EXEMPT` 의 **줄번호** 앵커가 `docreview_route.py` 를 가리키고 `:169` 가 drift 를 직접 잰다. `:269-272` 의 컴프리헨션 baseline 도 같은 코퍼스를 잰다 | 3 |
| `shared/tests/test_adjudication_consumed.sh` | `render_disposition.py` 를 코퍼스로 도출한다 | 3 |
| `plugins/quality-gates/tests/test_synthesize_artifact_findings.sh` | 4-튜플 언패킹 + 머리말 서술 | 3 |
| `plugins/spec-distill/tests/test_brief_agents.sh` | agent 사본 계약 | 1 · 3 |

★ **`check_wiring.py` 는 「고칠 파일」이자 「락이 잴 대상」이다.** `EXEMPT` 가 (경로, **줄번호**, 분기
설명) 3-튜플을 키로 쓰는데, PR 3 이 고치는 `normalize()`(`:52-78`)와 `_decision_view()`(`:213-238`)가 그
키들(`:97`·`:372`·`:391` …)보다 **위**라 두 칸 추가가 아래 전부를 민다. 같은 파일 `:164-168` 이
「줄번호는 매 재앵커마다 실측으로 갱신한다」와 「I1 정정이 이 파일 앞부분 줄 수를 늘렸다」로 **같은 일이
이미 한 번 일어났음**을 기록해 두었다 — 예측이 아니라 **재발**이다.

**선재 RED 0**(잰 다섯에 한해). 회귀가 생기면 전부 이 변경의 것이다. (CHANGELOG 에 적힌
「`test_synthesize_disposition.sh` 1/6 PASS」는 과거 기록이고 이후 고쳐졌다 — 기록이 아니라 실행으로
확인했다.) **안 잰 열 개의 baseline 은 plan 의 첫 Task 가 rc 가 아니라 통과 수로 캡처한다.**

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
   갖춘 형식으로 나는지, 게이트 렌더가 §5.8 의 밀도 표대로 나는지, `AskUserQuestion` 라벨이 항목별인지 본다.

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
| **D6 넷째 장치** | 「줄이자」 판정에 **관측 가능한 검사** 하나를 함께 낸다 (ponytail 차용이라고 기록) | **천장 + 올라갈 조건**, 조건 없으면 `no-trigger` 표시 | ponytail 원문 전수 조사 — 그 장치는 **원문에 없다**(ponytail 저장소 전수 grep 0건 — devbrew 의 창작이다). 원문의 인접 장치는 빌드 쪽의 `ponytail:` ceiling 주석 + upgrade path + `no-trigger` 태그다. 문서 층위에 자연스럽고 한 방향 압력의 직접적 추다. 사용자 동의 2026-09-21 |
| **C26 조달 경로** | 과설계 판정 기준을 **외부 자료를 전문 조사해 거기서 끌어온다** | ① 은 외부(ponytail)에서, **②③ 은 리포 자신에게서** 가져온다(D22 · CLAUDE.md Forbidden Patterns · design-doc 층 2 `testing` 의 반대 방향) | 전수 조사로 **외부 자료에 ②③ 의 기준이 없음을 확인**했다(ponytail HEAD `e3ba2aa` 저장소 전수 grep 0건 — Q10). 「외부에 없더라」까지는 측정이지만 「그러면 리포에서 만든다」는 **결정**이다. 대안은 ㉮ ②③ 을 빼고 다시 조달 ㉯ ②③ 을 범위에서 제외였고, 둘 다 C10 이 든 세 실패 중 둘을 놓친다. 사용자 동의 2026-09-21(리뷰 라운드 1 · D1.7) |
| **AC18′ 첫 절** | 같은 `anchor` 의 열린 항목이 **한 덩어리로 묶여 렌더된다**(보장) — 질문 수·선택권은 그대로다 | 첫 절을 **철회** — 묶음 마커는 `GATE_ROWS` 순서상 **우연히 인접할 때만** 붙고 인접을 보장하지 않는다. 둘째 절(질문 수·선택권 불변)은 그대로 선다 | 전 기능 리뷰 실측(2026-09-23) — 게이트 렌더 순서를 정하는 id prefix `sha1(layer\|category\|anchor)`(`_bucket()`, `docreview_route.py`)가 `anchor` 뿐 아니라 `category` 도 섞어 버킷을 가르므로, 같은 `anchor` 라도 `category` 가 다른 두 항목(이 기능이 만드는 가장 흔한 입력 — `overdesign` 항목과 `architecture` 항목이 한 자리를 짚는 경우)의 인접 여부는 **`(layer, category, anchor)` 에 대한 sha1 추첨이라 보장되지 않는다** — 그 둘만 열려 있으면 인접이 강제돼 마커가 붙지만, 버킷이 둘 사이에 오는 항목이 하나만 더 열려도 갈라진다. 보장하려면 `GATE_ROWS` 를 anchor 기준으로 **재정렬**해야 하는데, 그러면 오케스트레이터가 새 순위를 매기게 되어 §5.7 의 원칙(「새 순위를 매기지 않는다 — 순위를 매기면 그 자체가 판단이고 사용자가 그 위험을 받아들인다고 말한 적이 없다」)과 정면으로 부딪힌다. 재정렬 대신 첫 절을 철회하기로 사용자가 결정 2026-09-23 |

**사실 정정 — 결정이 아니라 측정으로 바뀐 것**

- **브리프 §4 의 사다리 단 수.** §4 는 5단으로, ✎ 노트는 7단으로 적어 두 자리가 어긋나 있었다. 원문에
  **7·6·5 세 판본이 병존**하고 런타임 주입 정본은 **7단**이며 5단은 help 카드 축약이다. 이 설계는 7단을
  정본으로 인용한다.
- **T13 의 새 술어 문구.** 이 설계 과정에서 오케스트레이터가 사용자에게 제시한 선택지 문구가
  「brief 층 1 의 각 축이 그 자리의 `ground_truth`(사용자 원문)를 쓰는가」였는데, 실측하면 brief 층 1 의
  `direction` 은 `ground_truth` 를 **안 쓴다** — 층 1 은 리포 실체와 웹 선례로 방향을 반증하고
  `ground_truth` 는 **층 2 의 정답**이다. 사용자가 고른 **방향**(이름 말고 관계로, fail-open → fail-closed)은
  그대로 서고 **기계 장치**만 §5.6 의 단언 다섯으로 바뀌었다. 사용자에게 고지함.
- **C26 의 조달 결과 — 측정 부분만.** 「과설계 판정 기준을 외부 자료에서 끌어온다」의 답이 **절반**이다.
  ① 에는 내용과 형식을 다 주고, ②③ 에는 **한 글자도 없다**(ponytail 저장소 전수 grep 0건). 여기까지가 측정이고, 그
  **뒤에 이어진 선택**(그러면 리포에서 가져온다)은 위 P23 표의 세 번째 행이다 — 측정이 아니라 결정이라서.

⚠ **원장과 선택이 갈린 자리 하나 — D1.10.** 라운드 1 게이트에서 finding `d935937f#r1.2`(「대안」 줄
조건부가 락의 발동 조건을 없앤다)에 대해 사용자가 고른 선택지의 **내용**은 「**「대안」 줄을 항상
낸다**」였고, 그것이 위 결정 9 와 §5.8·AC16 에 반영돼 있다. 그런데 오케스트레이터가 그 선택지에
붙인 회계어가 「기각」이었고 엔진 원장에는 `reject` 로 기록됐다 — 엔진에서 `reject` 는 「이 지적을
받아들이지 않고 문서를 그대로 둔다」라서 **내용과 반대**다. 같은 라운드 안에서는 재결정이 막혀 있어
(`decide_not_open`) 원장 쪽은 못 고쳤다. **문서는 사용자가 고른 내용을 따르고, 원장은 `reject` 로
남아 있다** — 이 문단이 그 불일치의 공시다. 이 오류의 종류가 바로 이 설계의 §5.8 이 고치려는 것이다
(사람말 라벨이 엔진 동작을 반대로 설명하는 것), 그리고 그것을 고치기로 결정한 **바로 다음 질문에서**
같은 실수가 났다는 사실이 그 결함의 실재를 보여 준다.

**설계 결정 — 브리프가 열어 두고 이 단계가 정한 것**

| # | 결정 | 근거 |
|---|---|---|
| 1 | 축 이름 `overdesign` | 층 1 은 주제 이름이 관례. `distortion` 은 brief 층 2 에 이미 있어 충돌 |
| 2 | design-doc 의 ① 은 **§1 Goal** 기준, `architecture` 는 §2 확정 제약 그대로 | conformance 술어만으로는 브리프가 확정한 과설계를 정의상 「정합」으로 판정 |
| 3 | **③ 의 처분은 두 자리 모두 `decide`** | 보호 헤딩(Architecture·AC)이 하위 소절까지 캐스케이드돼 non-`decide` 가 전부 승격되므로 `defer` 배관은 이 축에서 도달 불가다 ⟵ 라운드 2 D2.12 에서 고침 |
| 4 | Lazy Ladder 원문 3·4·5 단을 하나로 접어 5단 | stdlib·native·의존성에 문서 대응물이 없다 |
| 5 | 「higher rung」을 **번호가 작은 쪽**으로 정의 | 원문 미정의. `Stop at the first rung that holds` 와 일관 |
| 6 | 상한 N = 3 | 게이트가 `AskUserQuestion` 을 4개씩 부른다 — **판정자 하나가 한 호출을 혼자 채우지 못하는 수**다. 총량(2N+α)은 약속하지 않는다 ⟵ 라운드 1 D1.3 에서 고침 |
| 7 | ⓐⓑ 는 리뷰어 칸, ⓒⓓ 는 렌더러 (OQ1) | 「고치면 / 그대로 두면」은 의미라 파생 불가. 회계어와 순서는 결정론 |
| 8 | 「변경」 줄 제거 | 헤더가 이미 그 일을 한다. 동어반복이 원리적으로 불가능해진다 |
| 9 | **「대안」 줄은 항상 낸다** | 그 줄이 `cases.sh:558` 「제안 = 수용」 락의 **발동 조건**이다. 밀도는 줄을 지워서가 아니라 상태별 라벨로 **정보량을 채워서** 얻는다 ⟵ 라운드 1 에서 뒤집힘(아래 ⚠) |
| 10 | 라벨은 **상태의 함수** — 사람말을 앞에, 회계어는 괄호에 보존 | `kind=post` 에서 `reject` 가 revert permit 을 만들므로 고정 라벨은 동작을 반대로 설명한다 ⟵ 라운드 1 D1.9 에서 고침 |
| 11 | PR 셋 | 참조 전환이 갈래 둘과 독립으로 서고, Non-goal 자리의 동작 변경을 기능 PR 에 숨기지 않는다 |
| 13 | **대체안 두 칸을 `PUBLIC_FIELDS` 에 top-level 로 더한다** | 미루면 「아무것도 안 하는 쪽」이 기본값이고 그것이 곧 소실이다 ⟵ 라운드 3 D3.21 |
| 14 | **라벨의 항목별 내용은 필수** | 없으면 D13-① 이 원리적으로 안 닫힌다 ⟵ 라운드 3 D3.20 |
| 15 | **`category` 사상은 네 프로필 + 엔진 category** | 렌더가 프로필별이 아니라 엔진 하나다 ⟵ 라운드 3 D3.22 |
| 16 | **프로필 `layer1:` 은 한 줄** | 줄바꿈이 codex 축을 끄고 락을 덜 재게 한다 ⟵ 라운드 3 D3.19 |
| 12 | C18 을 구속 기준으로 **안 올린다** | `AskUserQuestion` 실측 — 경성 상한은 `header` 12자 하나뿐이고 나머지는 연성 지침이라 구속할 근거가 안 나온다 |
- D1.1 · r1 · adopt · 19a8fc9c#r1.1 · "채택 — 판정 관계도 프로필로" — 참조 전환의 새 문장이 축 이름만 프로필로 넘기고 「ground_truth 와 문서가 정합한가」라는 design-doc 전용 판정 관계는 리터럴로 남겨, brief·generic 두 자리에서 이 설계 자신이 반증한 프레이밍을 그대로 못 박는다 — 넷 중 하나에만 맞던 문장을 넷 중 둘에만 맞는 문장으로 바꾸는 것이라 「수선」의 절반만 달성된다.
- D1.2 · r1 · adopt · 29dd293f#r1.1 · "채택 — overdesign 축에만 한정" — ‘이 문서는 이미 최소다’ 한 줄로 끝내는 규약이 overdesign 축만 끝내는지 리뷰 전체를 끝내는지 불명확하다. 기존 두 출력 블록과 다른 축 검토를 유지하는 적용 범위를 명시해야 한다.
- D1.3 · r1 · adopt · 2d40ac9d#r1.1 · "채택 — 보장을 철회하고 N=3 은 유지" — 판정자별 N=3은 네 질문 중 기존 축 자리를 하나 남긴다는 보장을 만들지 못한다. N=3의 근거를 경험적 선택으로 고칠지, 호출별 배치 보장을 별도로 설계할지 결정해야 한다.
- D1.4 · r1 · adopt · 48524b91#r1.1 · "채택 — AC 둘을 더한다" — 설명 개선 넷을 모두 범위에 둔다는 C3 와 D13 세 기준을 AC 가 다 재지 못한다 — ⓓ 의 「묶음」(같은 anchor 를 한 덩어리로 보이게)과 「`category` 를 사람말로」 둘은 본문이 약속하지만 대응하는 AC 가 없어, AC 를 다 통과해도 두 약속은 미구현으로 남을 수 있다.
- D1.5 · r1 · adopt · 7a400261#r1.1 · "채택 — 사용자 원문의 goal 로 못 박는다" — brief 자리 술어 ① 이 무엇에 대비해 「과한가」를 재는지가 두 곳에서 갈린다 — §5.1 표는 design-doc 에만 「(§1 Goal 기준)」을 달아 brief 칸을 비워 두는데, §5.6 ⑤ 는 brief 불릿이 「사용자 원문」 계열 기준어를 담을 것을 리터럴 락으로 요구하고, [결정 기록]은 brief 층 1 이 바로 그 원문(`ground_truth`)을 안 쓴다고 적는다. AC6 과 AC12 가 이 갈림 위에 서므로 plan 이 어느 쪽으로 써도 다른 쪽이 RED 가 될 수 있다.
- D1.6 · r1 · adopt · 879d792c#r1.1 · "채택 — 침묵과 판정을 가른다" — replacement 누락과 명시적 삭제 제안을 구분해야 한다. 누락을 ‘대체안 없음 — 그냥 뺀다’로 표시하면 리뷰어가 제안하지 않은 삭제를 만들어 낸다.
- D1.7 · r1 · adopt · a1923121#r1.1 · "채택 — 리포 출처를 받고 P23 기록을 남긴다" — 술어 ②③ 의 판정 기준을 외부 자료 대신 리포 자신에게서 가져온 것은 확정 제약 C26 의 조달 경로를 바꾼 **결정**인데, 문서는 그것을 「사실 정정 — 결정이 아니라 측정으로 바뀐 것」으로 분류해 P23 재결정 절차(근거 · 사용자 동의 · 세 칸)를 우회한다.
- D1.8 · r1 · adopt · b2ac704f#r1.1 · "채택 — 자기증명 문장을 지운다" — D25 가 요구한 `/qg` 자리의 「읽히기」 기준 셋이 후보 비교 없이 단정되고, 곧바로 그 셋 중 둘이 이미 만족된다는 사실이 「D25 가 범위를 ⓒ 하나로 좁힌 것이 옳았다는 증거」로 쓰인다 — 기준을 세운 쪽과 그 기준으로 결론을 정당화하는 쪽이 같아 어떤 후보가 왜 탈락했는지가 남지 않는다.
- D1.9 · r1 · adopt · d935937f#r1.1 · "채택 — 상태별로 다른 라벨" — 고정 라벨 ‘고친다(채택) / 그대로 둔다(기각)’은 사후 변경 결정에서 실제 동작을 반대로 설명한다. 사전 제안과 사후 변경의 라벨을 구분할지 결정해야 한다.
- D1.10 · r1 · reject · d935937f#r1.2 · "기각 — 「대안」 줄을 항상 낸다" — 「대안」 줄을 기본 셋과 다를 때만 내기로 한 결정(결정 9 · AC16)이 「제안 = 수용」 등식을 재는 기존 락의 발동 조건을 없애고, 그 자리를 게이트 머리의 고정 열거(AC18)로 대체해 과거 리뷰가 닫은 「두 번째, 안 이어진 열거」를 되살릴 위험이 있다 — 밀도를 위해 이 락의 이빨을 포기할지는 사용자 결정이다.
- D1.11 · r1 · adopt · de339fb3#r1.1 · "채택 — 조건절을 유지하고 AC3 을 고친다" — AC3 은 근거 요구가 「**모든 층 1 finding** 에 걸리는 문장으로 남는다」를 요구하는데 §5.5 의 바꿀 문장은 「**리포 사실을 단정하는** finding 은 … 인용한다」로 조건이 붙어 있어, 「축 이름에 안 묶였다」는 뜻인지 「예외 없이 전부에 걸린다」는 뜻인지 두 가지로 읽힌다 — 락이 어느 쪽을 잴지 정해지지 않는다.
- D2.12 · r2 · adopt · 18396efc#r2.1 · "채택 — ③ 를 decide 로 통일한다" — 술어 ③ 의 처분을 design-doc 에서 `defer` 로 정한 결정은 「배관이 이미 깔려 있다」에 기대는데, 엔진은 보호 헤딩 앵커의 `decide` 아닌 처분을 전부 `decide` 로 승격하므로 층위 이탈이 가장 자주 사는 Architecture·AC 절에서 그 `defer` 는 구조적으로 도달 불가다 — ③ 을 `decide` 로 통일할지, 앵커를 비보호 소절로 좁힐지(OQ-B 선행)를 정해야 한다.
- D2.13 · r2 · adopt · bd92db46#r2.1 · "채택 — 둘을 합친다 (사실 + 대체안 + 결정 질문)" — brief 프로필 층 1 은 finding 마다 「사용자가 결정할 질문 하나」를 `summary` 에 담기를 요구하는데 새 축이 가져오는 ponytail 어법은 질문형을 금지하고 사실 서술 + 대체안을 요구하므로, 한 층 안에서 두 어법 계약이 충돌한다 — 어느 쪽을 그 자리의 정본으로 삼을지 정해야 한다.
- D2.14 · r2 · adopt · e2e3e66a#r2.1 · "채택 — 1 → 3 → 2 로 뒤집는다" — 머지 순서 계약(1 → 2 → 3)이 같은 절의 「잘못된 순서」 표가 해롭다고 적은 순서와 같다 — 계약이 스스로 진단한 사고를 처방하므로 순서를 1 → 3 → 2 로 뒤집을지, 아니면 PR 2·3 사이 창의 손실을 감수할지 사용자가 정해야 한다.
- D2.15 · r2 · adopt · ca163eab#r2.1 · "채택 — 작은 쪽 유지 + 대가를 적는다" — 원문 미정의인 「higher rung」을 「번호가 작은 쪽」으로 못 박으면서 반대 읽기(번호가 큰 쪽)를 후보로 세워 비교하지 않았다 — 작은 쪽은 언제나 더 많이 자르는 해석이라 문서가 §7·OQ-E 로 스스로 경고한 「한 방향 압력」을 증폭하는 선택이고, 그 대가가 어디에도 안 적힌다.
- D2.16 · r2 · adopt · 94a2dbed#r2.1 · "채택 — 이 편집을 유지한다 (§7 위험: 줄번호 연쇄 · 정답 출처 둘)" — finding 없이 바뀜: 7. 위험 (modified)
- D2.17 · r2 · adopt · 9ebabf8d#r2.1 · "채택 — 이 편집을 유지한다 (§5.1: 자리별 기준 칸 · 두 문단)" — finding 없이 바뀜: 5.1 새 축 `overdesign` (modified)
- D2.18 · r2 · adopt · e3ff3375#r2.1 · "채택 — 이 편집을 유지한다 (Handoff: 실측 여섯 줄)" — finding 없이 바뀜: Handoff Context (modified)
- D3.19 · r3 · adopt · 18396efc#r3.1 · "채택 — 한 줄 강제 + 제약을 §4 에 올린다" — §5.1 의 프로필 스니펫이 아홉 축을 `layer1:` 두 줄에 걸쳐 적는데 codex 러너의 프로필 문법은 한 줄 완결만 받고 T13 의 `lay_of` 도 첫 줄만 읽으므로, 그 표기를 한 줄로 못 박고 그 제약을 §4 기계적 제약에 올릴지 정해야 한다.
- D3.20 · r3 · adopt · 2c004d3a#r3.1 · "채택 — 항목별 내용을 필수로 + AC 로 잰다" — 항목별 변경 내용을 라벨에 담는 것이 선택 사항이라 D13의 ‘라벨만 읽고 고른다’를 보장하지 못한다. 최종 AskUserQuestion 라벨의 항목별 내용을 필수로 할지 결정해야 한다.
- D3.21 · r3 · adopt · 3de9e66f#r3.1 · "채택 — 모든 처분에서 보존한다" — 문서가 스스로 「어긋나 있다」고 적은 계약 충돌(§5.2 의 처분-무관 「대체안 필수」 대 `decide` 에만 열리는 원장 통로)을 해소하지 않고 plan 에 넘기는데, 해소 선택지 한쪽이 이미 AC19 에 박혀 있고 그 선택은 `### Deferred to plan` 목록에도 없어 기본값이 「조용히 버려지는 쪽」으로 굳는다 — 여기서 한쪽을 정해야 한다.
- D3.22 · r3 · adopt · 48524b91#r3.1 · "채택 — 네 프로필 + 엔진 category 로 넓힌다" — AC19′ 의 `category` 사람말 사상 코퍼스가 「두 프로필」로 좁혀져 있는데 그 렌더는 seed 자리와 엔진이 만드는 `frozen_change` 까지 지나므로, 사상을 네 프로필 + 엔진 category 로 넓힐지 아니면 그 자리들의 advisory 를 감수할지 정해야 한다.
- D3.23 · r3 · adopt · 80adb4f3#r3.1 · "채택 — 실제 집계에 맞게 고친다" — ‘배관 손실=판정에 못 들어간 것’은 실제 집계 의미와 다르다. 입력 실패·미처리 항목·값 보정을 포함하는 설명으로 고쳐야 한다.
- D3.24 · r3 · adopt · 879d792c#r3.1 · "채택 — 여섯으로 통일하고 네 자리를 다 고친다" — §5.8 의 「줄 수는 다섯으로 같다」가 같은 절의 밀도 표(1~6행)와 바로 다음 문장(「여섯 줄 … 줄이 하나 늘지만」)과 AC16(「헤더 + 다섯 줄」 = 여섯)에 반박된다 — 「대안」 줄을 항상 내기로 뒤집힌 결정 9 이전의 수가 절 제목 · §1 머리말 · 목차 · §10 e2e 문장까지 복제돼 남아 있다.
- D3.25 · r3 · adopt · 879d792c#r3.2 · "채택 — 여섯으로 통일하고 네 자리를 다 고친다 (r3.1 과 같은 결함)" — check-intent 거부 후 상향: 같은 절이 렌더 줄 수를 다섯과 여섯 두 가지로 말한다 — 헤딩과 「줄 수는 다섯으로 같다」가 바로 아래 여섯 행 표·「줄이 하나 늘지만」·AC16 과 어긋나므로 여섯으로 통일하고 목차도 함께 고쳐야 한다.
- D3.26 · r3 · adopt · a24bda4a#r3.1 · "채택 — 원문 둘로 고친다" — check-intent 거부 후 상향: brief 자리의 `ground_truth` 를 payload `## 6. 사용자 원문` 하나로 적었으나 실제 값은 원문 **둘**(payload §6 + audit `<<<AUDIT-VERBATIM>>>` 뒤 블록)이라, 그 반쪽 인용 위에 세운 ⑤ 의 기준어가 새 축을 S2 이상 원문에서 눈멀게 한다.
- D3.27 · r3 · adopt · a24bda4a#r3.2 · "채택 — 기존 범위(층 2)로 고친다" — check-intent 거부 후 상향: 단언 ③ 을 「brief 층 2 ∩ design 층 1·2 = ∅ · 기존 유지」로 적었으나 현행 락은 design **층 2** 만 대조하므로, 「기존 유지」와 적힌 집합이 서로 다른 것을 가리킨다.
- D3.28 · r3 · adopt · 9fd94927#r3.1 · "채택 — 이 편집을 유지한다 (§1.3: ponytail 저장소 명시)" — finding 없이 바뀜: 1.3 외부 조달 결과 — ponytail 이 준 것과 안 준 것 (modified)
- D3.29 · r3 · adopt · e6d5b199#r3.1 · "채택 — 이 편집을 유지한다 (§5.2: 태그 출처를 완전 경로로)" — finding 없이 바뀜: 5.2 판정 한 줄의 형식 (modified)
- D3.30 · r3 · adopt · d171e8ab#r3.1 · "채택 — 이 편집을 유지한다 (§5.4: 오탐 가드 출처를 완전 경로로)" — finding 없이 바뀜: 5.4 자르지 않는 것 · 0건 출구 · 상한 (modified)
- D3.31 · r3 · adopt · c06b959b#r3.1 · "채택 — AC19 와 대칭되는 AC 를 더한다" — `doc-recritic` 이 `added` finding 에 두 칸을 내는지를 재는 AC 가 없다 — §9 PR 3 표가 그 사본 둘을 고친다고 적으면서 「그것을 내라고 적는 자리는 agent 본문뿐」이라고 스스로 경고하는데, AC14~AC22 중 그것을 재는 것이 없어 AC 전부 GREEN 인 채로 재비판의 `added` 가 대체안 없이 렌더로 갈 수 있다.
- D3.32 · r3 · adopt · c06b959b#r3.2 · "채택 — AC6·AC7 에 어법 규약을 더한다" — §5.2 가 새로 세운 brief 자리의 어법 규약(「결정 질문을 의문문으로 쓰지 말고 사용자가 고를 두 상태를 사실로 제시해서 세워라」)에 대응하는 AC 가 없어 통과 여부를 관측할 수단이 없으므로, AC6·AC7 에 그 규약을 더할지 정해야 한다.
- D3.33 · r3 · adopt · f901f1f5#r3.1 · "채택 — AC25 를 1 → 3 → 2 로 고친다" — 머지 순서 계약이 문서 안에서 반대로 두 번 적혀 있다 — AC25 는 아직 「1 → 2 → 3」이고 §9 는 「1 → 3 → 2」이며, 라운드 2 에서 사용자가 고른 것은 뒤집는 쪽이라 AC25 를 갱신할지(그리고 §9 의 AC25 인용을 유지할지) 정해야 한다.
- D3.34 · r3 · adopt · fee27fc9#r3.1 · "채택 — 문장을 브리프 범위로 되돌린다" — Non-goal 의 「`/qg` 에 가는 것은 갈래 2 의 회계어 번역 하나다」가 이 설계 자신의 PR 1(generic 프로필 본문 편집 + quality-gates bump)로 반증되므로, 그 문장을 고칠지 아니면 PR 1 에서 generic 자리를 빼고 전환 시점으로 미룰지 정해야 한다.

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
- `PROFILE_FIELDS` 닫힌 10-튜플(`:37-39`) · `PUBLIC_FIELDS` 닫힌 열거(`docreview_state.py:516-518`,
  적용은 `:625`) — **닫힌 열거가 셋**이다
- `cmd_decide` 의 `kind=post` 분기가 `reject` 에 revert permit 을 만든다(`docreview_state.py:739-750`)
- `cases.sh` 가 라벨을 바이트로 복제한다(`:375`·`:490`·`:512`·`:1174`) · 그 파일을 읽는 스위트 여섯
- `check_wiring.py` 의 `EXEMPT` 가 (경로, **줄번호**, 분기) 3-튜플을 키로 쓴다(`:145-179`) ·
  `test_adjudication_wiring.sh:169` 가 그 drift 를 직접 잰다
- `/qg` generic 자리는 **호출자가 0** 이다(`quality-gates/CHANGELOG.md:34`·`:36`·`:37`·`:115` ·
  `README.md:83`) · quality-gates 는 `doc-critic*.md` 를 배송하지 않는다
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
