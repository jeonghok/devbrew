# agent-transparency — 설계

> **이해부채를 줄인다.** 위임한 에이전트가 무엇을 했고 판단이 무엇에 근거하는지를, 결정·판정
> 시점에 먼저 드러낸다.

devbrew의 다섯 번째 플러그인. 사용자가 판단해야 하는 순간에 판단할 재료가 이미 나와 있게 만든다.
입력은 [`docs/superpowers/interview/2026-08-02-comprehension-debt-plugin-interview.md`](../interview/2026-08-02-comprehension-debt-plugin-interview.md)
(문제공간 brief)이며, 이 문서는 그 해답공간이다.

## 목차

- [0. Handoff Context](#0-handoff-context)
- [1. Context · Why](#1-context--why)
- [2. Goals · Non-goals](#2-goals--non-goals)
- [3. 불변식](#3-불변식)
- [4. 제약](#4-제약)
- [5. 아키텍처](#5-아키텍처)
  - [5.1 부품 3개](#51-부품-3개)
  - [5.2 데이터 흐름](#52-데이터-흐름)
  - [5.3 왜 이 조합인가 — 플랫폼 근거](#53-왜-이-조합인가--플랫폼-근거)
  - [5.4 집행 수준 (OQ1 결정)](#54-집행-수준-oq1-결정)
- [6. 컴포넌트 상세](#6-컴포넌트-상세)
  - [6.1 output style — 이 플러그인의 본체](#61-output-style--이-플러그인의-본체)
  - [6.2 SubagentStop 훅](#62-subagentstop-훅)
  - [6.3 /recap — 명령 · skill · 추출기](#63-recap--명령--skill--추출기)
- [7. 에러 처리 · 강등](#7-에러-처리--강등)
- [8. 파일 목록](#8-파일-목록)
- [9. Acceptance Criteria](#9-acceptance-criteria)
- [10. 검증 계획](#10-검증-계획)
- [11. 기각된 대안](#11-기각된-대안)
- [12. 미해결](#12-미해결)
- [13. Metadata](#13-metadata)

## 0. Handoff Context

**TL;DR** — Claude Code용 새 플러그인 `agent-transparency`를 만든다. 부품은 셋이다: (1) 여섯 개의
의미 순간에 무엇을 설명해야 하는지 규정하는 **output style**(본체, 시스템 프롬프트에 붙는다),
(2) 에이전트 종료 직후 설명 자리를 만드는 **`SubagentStop` 훅**, (3) 세션 트랜스크립트에서 사용자가
정한 것·되돌린 것·한 일을 뽑아 주는 **`/recap`**. 상태 파일은 만들지 않는다.

**Implicit context** — 구현자가 모르면 재도출해야 하는 것들:

- **`Explanatory` 스타일이 꺼진다.** output style은 한 번에 하나만 활성이고 이 플러그인은
  `force-for-plugin: true`로 자동 적용된다. 그래서 `Explanatory`의 `## Insights` 절을 **원문 구조
  그대로** 흡수해야 한다([§6.1](#61-output-style--이-플러그인의-본체)). 이건 취향이 아니라 회귀 방지다.
- **끄는 방법은 플러그인 전체 비활성화뿐이다.** devbrew의 kill switch 규약은 훅에만 걸 수 있고
  output style에는 못 건다. 사용자가 이 대가를 알고 선택했다.
- **트랜스크립트 형식은 문서화돼 있지 않다.** `/recap`이 읽는 `~/.claude/projects/*/<sid>.jsonl`의
  레코드 구조는 실측으로 확인한 것이며 플랫폼 보장이 아니다([§6.3](#63-recap--명령--skill--추출기)).
- **`/why`는 설계에서 제거됐다.** 초안에 있었고 사용자가 뺐다. 그 결과 `subagents/*.jsonl`을 읽을
  이유가 사라졌다 — 에이전트 반환값은 메인 트랜스크립트에 이미 들어 있다(실측 4/4).
- **브리프의 C18(`project-init`의 확장) 번복.** 브리프에서 `confirmed`였으나, 수단이 output style로
  정해진 뒤 사용자가 **독립 신규 플러그인**으로 다시 정했다. 조용한 변경이 아니라 명시적 재결정이다.

**Deferred to plan** — 이 문서가 정하지 않고 구현 계획에 넘기는 것. **인수 조건에 영향을 주는
것은 여기 없다**:

- `extract_recap.py`의 내부 함수 분해와 파일 배치
- 루브릭 판정자를 호출하는 스크립트의 형태(어느 파일에 두고 결과를 어떻게 모을지)
- `docs/plugin-authoring.md`에 추가할 output style 절의 문장 단위 내용

앞선 판에서 여기 있다가 **본문으로 옮겨 확정된 것**(리뷰 지적): A/B 측정의 작업 프롬프트 **5종
(a–e)** · 픽스처 정책 · **실행 러너 전체**가 [§10-6](#10-검증-계획)에 고정됐고, 테스트는 합성
픽스처만 쓴다([§10-4](#10-검증-계획)).

## 1. Context · Why

작업이 진행되는 속도가 사용자가 이해하는 속도보다 빠르다. 특히 **subagent 사이의 대화가 대화창에
드러나지 않아서**, 사용자는 결론만 받고 그 결론이 어디서 왔는지 모르는 상태로 다음 결정을 요구받는다.
이 상태에서 고른 방향은 자주 틀린다.

이 격차는 문헌에서 **comprehension debt**(이해부채)로 불린다 — 존재하는 것과 사람이 이해하는 것
사이의 격차가 보이지 않게 누적되는 현상. 정보 비대칭 쪽 이름은 **Hidden Profile**이다 — 한쪽만
가진 정보가 공유되지 않은 채 결정에 쓰이는 상태.

**핵심 진단**: 문제는 설명의 *부재*가 아니라 **설명했다고 착각하는 것**이다. 자기가 무엇을 이미
아는지는 자기가 판단할 수 없다. 이 설계는 그 판단을 모델에게 맡기지 않고, 순간과 담을 것을 미리
못박는다.

### 무엇이 이미 해결돼 있나 (재구현 방지)

| 이미 되는 것 | 어디서 | 남는 것 |
|---|---|---|
| subagent의 존재·진행·비용 | 에이전트 패널이 행마다 `이름 · 상태 · 토큰 · 모델 · effort` 렌더 | **무엇을 찾았는지·근거가 뭔지** |
| 대화 기록의 영구 보관 | `~/.claude/projects/<슬러그>/<세션>.jsonl` | **선별과 압축** |
| 매 턴 적용되는 지침 | `output style`이 시스템 프롬프트를 직접 수정 | 그 안에 넣을 **내용** |

그래서 이 플러그인은 **저장하지 않는다.** 원장도 상태 파일도 만들지 않는다. 하는 일은 이미 있는
것에서 **골라내고 줄이는 것**이다.

## 2. Goals · Non-goals

### Goals

- **G1** — 사용자가 판단을 요구받는 순간에, 판단할 재료가 이미 화면에 있게 한다.
- **G2** — subagent가 무엇을 찾았고 그것이 판단을 어떻게 바꿨는지가 대화창 표면에 나오게 한다.
- **G3** — 사용자가 물었을 때, 이미 디스크에 있는 기록에서 **자기가 정한 것과 되돌린 것**을 돌려준다.
- **G4** — 이 프로젝트에서만 통하는 말이 설명 없이 나가지 않게 한다.
- **G5** — 내장 `Explanatory` 스타일이 하던 일을 **전부** 계속 한다. 대체하는 이상 못해지면 안 된다.

각 Goal이 어느 인수 조건으로 확인되는지 (리뷰 지적 — 목표가 검증에 안 묶여 있었다):

| Goal | 확인하는 AC |
|---|---|
| G1 (결정 순간에 재료가 있다) | **AC29 게이트 4** (런타임) + AC3 (지침에 그 순간이 있다) |
| G2 (에이전트가 한 일이 표면에 나온다) | **AC29 게이트 3** (런타임) + AC7 (훅이 자리를 만든다) |
| G3 (물으면 기록에서 돌려준다) | AC10–AC20 (추출기) + **AC29 게이트 5** (`/recap` 답변, 런타임) |
| G4 (조어가 설명 없이 안 나간다) | AC4 (output style) + **AC28** (`/recap` 쪽에도 같은 규칙) |
| G5 (`Explanatory` 회귀 없음) | AC2 (4요소 각각 + mutation) |

### Non-goals

- **N1** — 설명의 **총량**을 늘리는 것. 성공은 길이가 아니라 *빠짐없음 + 형식*으로 달성한다.
- **N2** — 작업을 늦추거나 막는 것. → [불변식](#3-불변식)
- **N3** — 새 기록 장치(원장·로그·상태 파일)를 만드는 것. 트랜스크립트가 이미 그 역할을 한다.
- **N4** — subagent 내부에 지침을 심는 것. subagent는 자기 시스템 프롬프트를 따로 가지므로
  닿지 않으며, 리포 안 17개 agent 정의를 고치는 방식은 devbrew 밖에서 작동하지 않는다.
- **N5** — 프로젝트 고유 용어의 **사용 금지**. 금지하면 이 리포에서는 말을 할 수 없다
  (`qg`·`floor`·`steelman` 등은 실재하는 물건의 이름이라 대체어가 없다).
- **N6** — 말투·어조·응답 언어를 바꾸는 것. output style은 그것들을 바꿀 수 있지만, 이 스타일에는
  그런 규칙을 한 줄도 두지 않는다.
- **N7** — 특정 판단의 근거를 되짚어 주는 기능(`/why`). 초안에 있었으나 사용자가 제거했다.

## 3. 불변식

> **이 플러그인은 설명을 *더할* 뿐, 어떤 작업도 늦추거나 막지 않는다.**
>
> 훅은 자리만 만들고 검사·차단하지 않는다. 어떤 경로에도 사용자를 기다리게 하거나 도구 실행을
> 되돌리는 지점이 없다. `decision: "block"`은 어느 훅에서도 내지 않는다.

이 불변식은 나중에 *"확실하게 하려면 검사를 넣자"*는 유혹이 왔을 때 거절할 근거다. 확실함을
얻으려고 억제를 들이는 순간 이 플러그인의 존재 이유가 뒤집힌다.

**유일한 예외는 비밀 유출이다.** 한 번 새면 되돌릴 수 없다. 방어는 두 겹이고 **세기가 다르다.
같은 것처럼 쓰면 안 된다.**

- **구조 (강함)** — `Bash` 명령 문자열 · 파일 내용 · `tool_result` · 에이전트 반환값은 **애초에
  추출하지 않는다.** 탐지에 기대지 않으므로 못 알아본 비밀도 새지 않는다.
- **탐지 (약함)** — 아래 **여섯 필드**는 버릴 수 없고 패턴·엔트로피 마스킹에 의존한다.
  **패턴이 못 알아본 비밀은 통과한다.** 이 잔여 위험은 수용된 것이며
  [§12 OQ-K](#12-미해결)에 남긴다.

  1. 사람 발화 본문
  2. `AskUserQuestion` **질문 문장**
  3. `AskUserQuestion` **고른 라벨**
  4. 거절 시 사용자가 한 말
  5. 에이전트 `subagent_type`
  6. 에이전트 `description`

  **정본은 이 목록이 아니라** `plugins/agent-transparency/REFERENCE.md` 의 `masked_fields`
  이며, 여기와 [§6.3](#63-recap--명령--skill--추출기) 표는 그 사본이다. AC30이 **정본 ↔ 구현**을
  검증한다(설계 문서는 검증 대상이 아니다 — [§8](#8-파일-목록) 「정본을 플러그인 안에 두는 이유」).
- **방어 없음** — 훅 + output style 경로(대화창에 나가는 설명)에는 어떤 필터도 없다. 모델 출력에
  개입할 지점이 플랫폼에 없기 때문이다([§12 OQ-J](#12-미해결)).

## 4. 제약

| # | 제약 | 출처 |
|---|---|---|
| K1 | 억제 금지 — 모델 능력을 깎는 어떤 장치도 안 된다 | 사용자 |
| K2 | 토큰 비용이 설계 제약이다. 빠짐없음을 포기하지 말고 **압축**으로 달성한다 | 사용자 |
| K3 | 적용 범위는 이 리포의 모든 작업. 특정 플러그인 안이 아니다 | 사용자 |
| K4 | 표준 용어를 쓰고, 이 프로젝트에서만 통하는 말은 지양하며, 비유를 쓰지 않는다 | 사용자 원 요청 |
| K5 | 설명 시점은 수행 전 · 수행 뒤 · 혹은 중간 | 사용자 원 요청 |
| K6 | 성공 기준은 "빠짐없음"이며 "빠른 파악"으로 **교체**하지 않는다 | 사용자 |
| K7 | 빠짐없음에는 **확신 못 하는 지점 · 근거가 약한 곳 · 불일치**가 1급 항목으로 포함된다. 불일치에는 자료 간 불일치와 **리뷰어 간 판정 충돌**이 함께 들어간다 | 브리프 C22 |
| K8 | 모든 훅에 kill switch 2종 | devbrew 규약 |
| K9 | 모든 skill에 `cost_class` 선언 | devbrew 규약 |

K4는 **자기 자신에게도 적용된다** — 이 플러그인의 이름·설명·본문이 자기 규칙을 통과해야 한다.

## 5. 아키텍처

### 5.1 부품 3개

| # | 부품 | 하는 일 | 상태 | 비중 |
|---|---|---|---|---|
| 1 | **output style** | 여섯 순간에 무엇을 담아야 하는지 규정 + `Explanatory` 흡수 | 없음 | **본체** |
| 2 | **`SubagentStop` 훅** | 에이전트가 끝난 직후 설명 자리를 만든다 | 없음 | 백스톱 1건 |
| 3 | **`/recap`** | 명령 → fork skill → 추출기. 세션 기록에서 결정·되돌림·행적을 꺼낸다 | 없음 | 조회 |

**상태 파일이 하나도 없다.** 훅은 상수를 출력하고, 추출기는 읽기만 한다.

### 5.2 데이터 흐름

```
[푸시 — 자동]

   output style ──(시스템 프롬프트, 매 턴)──▶ 모델 ──▶ 대화창: 여섯 순간의 설명
                                              ▲
   SubagentStop 훅 ──(additionalContext)───────┘
        "방금 끝난 에이전트에 대해 내라 — 누가 / 무엇을 찾았나 / 근거 위치 / 판단 변화"


[조회 — 사용자가 /recap 칠 때만]

   /recap ──▶ skill (context: fork, agent: Explore)
                 │
                 │  프론트매터가 로드되기 전에 !`…` 가 먼저 실행됨
                 ▼
              extract_recap.py ──▶ ~/.claude/projects/*/<sid>.jsonl  (읽기 전용)
                 │                    ① 사람 발화 식별   ② 결정 쌍 복원
                 │                    ③ 되돌림 표시      ④ 행적 집계
                 ▼
              고정 4절 + 기계가 찍은 헤더 ──▶ fork 안의 모델 ──▶ 메인 대화에 답변만
```

`/recap`의 큰 발췌는 **fork 안에서 소모되고 메인 대화에는 답변만** 들어온다. 이것이 K2를 지키는
방식이다 — 메인 컨텍스트가 발췌만큼 밀리지 않으므로 `/compact`가 앞당겨지지 않는다.

### 5.3 왜 이 조합인가 — 플랫폼 근거

플랫폼이 이 구조를 강제한다. 아래 표의 근거는
[Claude Code 훅 문서](https://code.claude.com/docs/en/hooks)의 이벤트 표이며, 각 행은 그 표에서 직접
확인한 것이다.

| 순간 | 대응 훅 이벤트 | 그 이벤트가 컨텍스트를 주입할 수 있나 | 그래서 |
|---|---|---|---|
| 결정을 요청하기 직전 | `PreToolUse` (matcher `AskUserQuestion`) | **❌** — `permissionDecision`·`permissionDecisionReason`·`updatedInput`만 지원 | output style만 가능 |
| 판정이 나왔을 때 | 해당 이벤트 없음 — 모델만 안다 | — | output style만 가능 |
| 도구 부재로 능력 저하 | `PostToolUseFailure`가 실패는 잡지만, "도구가 애초에 없음"은 이벤트가 아님 | 부분적 | output style |
| 긴 작업 착수 직전 | `TaskCreated` | ❌ | output style만 가능 |
| **다른 에이전트 결과 도착** | **`SubagentStop`** | **✅** | **훅 백스톱** |
| 작업 종료 | `Stop` | ⚠️ 지원하지만 **대화를 계속시킨다** → 턴이 안 끝나는 루프 위험 | 훅 안 씀 |

statusline 계열은 **원리적으로** 내용을 못 싣는다 —
[statusline 문서](https://code.claude.com/docs/en/statusline#subagent-status-lines)에 따르면
`subagentStatusLine`이 받는 `tasks[]` 항목은 `id`·`name`·`type`·`status`·`description`·`label`·
`startTime`·`model`·`effort`·`contextWindowSize`·`tokenCount`·`tokenSamples`·`cwd`이며 findings
필드가 없다. 출력 토큰이 0이라 매력적이지만 담을 것이 메타데이터뿐이다.

> **검증 의무** — 위 표의 이벤트 이름과 능력은 문서 기준 시점의 것이다. 구현 시 `hooks` 문서를
> 다시 대조하고, 어긋나면 이 표부터 고친다.

### 5.4 집행 수준 (OQ1 결정)

브리프는 OQ1(집행 수준)을 *"미정 — 유추 금지"*로 남겼다. 사용자가 명시적으로 골랐다:
**② 검사 없는 훅 + ③ 지침 텍스트에 대한 테스트타임 회귀 락.**

| 후보 | 채택 | 근거 |
|---|---|---|
| ① 런타임 결정론 검사·차단 | ❌ | [불변식](#3-불변식) 위반 — 작업을 막는다 |
| ② 검사 없는 훅 | ✅ | `SubagentStop` 1곳 |
| ③ 테스트타임 회귀 락 | ✅ | **지침 파일의 텍스트만** 잠근다 (AC2·AC3·AC5) |
| ④ 지침만 | 부분 | ③이 못 덮는 런타임 행동 |

**③이 여기서 절반만 가능한 이유**: 잠글 대상이 셸 스크립트의 동작이 아니라 *모델이 순간을 알아보고
설명하는 행동*이다. 파일 검사는 *"지침에 그 순간이 적혀 있다"*까지만 도달한다. devbrew 전례
(`plugins/spec-distill/tests/test_web_sweep_bound.sh`가 ④→③으로 격상된 것)는 검증 대상이 스크립트
동작이었기에 가능했다. 이 차이를 인정하고 ③을 **지침 텍스트 회귀 방지**로 한정한다.

## 6. 컴포넌트 상세

### 6.1 output style — 이 플러그인의 본체

`output-styles/agent-transparency.md` 파일 하나가 이 플러그인이 하는 일의 대부분을 담는다.

#### 왜 이렇게 썼나 — 근거

| 출처 | 규칙 | 반영 |
|---|---|---|
| [Anthropic 프롬프트 가이드](https://claude.com/blog/best-practices-for-prompt-engineering) | *"하지 말 것"보다 "할 것"을 말하라* | 부정문 최소화, 남긴 것엔 이유를 붙임 |
| 같은 곳 | *예시는 형식을 보여줄 때 빛난다. 하나(one-shot)로 시작* | 형식 예시 1개 |
| 같은 곳 | *이유를 설명하면 모델이 목표를 더 잘 이해한다* | 각 절에 이유 문장 |
| 같은 곳 | *짧게 시작하라. 길수록 좋은 게 아니다* | 약 450 단어 |
| 내장 `Explanatory` 본문 | 역할 문장 → **균형 조항** → 형식 예시 → 안티패턴 | 구조를 그대로 따름 |
| [output style 문서](https://code.claude.com/docs/en/output-styles) 예시 · `Explanatory` | 마크다운 헤더 사용 | XML 태그 대신 마크다운 |

**언어는 영어다.** `Explanatory` 원문이 영어이고 그 원문이 이 파일의 모범이기 때문이다. 지침이
영어인 것은 응답 언어와 무관하다 — 언어 규칙을 두지 않으므로 사용자가 쓰는 언어를 따른다(N6).

#### 전문

```markdown
---
name: agent-transparency
description: Reduces comprehension debt — surfaces what delegated agents did and what
  your judgment rests on, at decision and verdict points
keep-coding-instructions: true
force-for-plugin: true
---

You are in 'agent-transparency' output style mode, where you put the material for a
judgment in front of the user before you ask them to make it. The user understands more
slowly than you work, and never sees the conversations of the agents you delegate to.

Balance transparency with task completion. Explain at the moments below; between them,
work as usual. A task that takes one sentence to describe takes one sentence to report.

## Moments that require an explanation

| Moment | What it must contain |
|---|---|
| Just before you ask the user to decide | what you are asking / why these options / **what you discarded and why** / your recommendation and its basis |
| When another agent's result comes back | who / what they found / where the evidence is / **how it changed your judgment** |
| When a verdict or conclusion lands | the verdict / its basis / what was examined / **what was not examined** |
| When something you needed was unavailable | what was missing / **what that makes weaker in the result** |
| Just before starting a long task | the steps / how many / what it will produce |
| When the work ends | what changed / what remains / what is next |

Always include the bolded items. Without them the user cannot imagine anything outside
the options you offered.

State where you are not confident, where your basis is thin, where two sources disagree,
and **where two reviewers or agents reached opposite verdicts on the same thing**. Those
belong in the explanation, not in a footnote.

**Trigger boundaries.** A *long task* is one where you plan three or more steps or
delegate to an agent. A *verdict* is any pass/fail, approve/reject, or found/not-found
conclusion you announce. *The work ends* when you hand the turn back with this request's
output complete. *Unavailable* means a tool, command, or file you intended to use was
missing or failed and you proceeded another way.

Example, just before asking the user to decide:

"**What I'm asking** — where cache expiry should be handled.
**Why these options** — expiry is checked only on the read path today, so the write path
cannot catch stale entries.
**What I discarded** — a background job: this repo has no scheduler, so it would need new
infrastructure.
**Recommendation** — ②, because it attaches to existing middleware and adds no new moving parts."

## Format

**When you explain at the moments above**, use tables, a fixed order, and bold labels, so
the user can find one item without reading the whole block. Structure does this, not
brevity — a shorter explanation that drops an item is worse, not better. Elsewhere, write
however the content wants to be written.

## Vocabulary

Terms that mean something only inside this project — tool names, abbreviations, internal
concepts — get one clause of explanation the first time they appear. Use them freely; just
pay for them on the spot. Prefer a standard term when one exists; otherwise say plainly
what the thing does. Do not assume the user knows a word because you know it — that is not
a judgment you are in a position to make.

## Insights

Before and after writing code, provide brief educational explanations about implementation
choices using (with backticks):

"`★ Insight ─────────────────────────────────────`
[2-3 key educational points]
`─────────────────────────────────────────────────`"

These insights belong in the conversation, not in the codebase. Focus on insights specific
to this codebase or the code you just wrote, rather than general programming concepts. Do
not wait until the end to provide insights. Provide them as you write code.
```

#### 여섯 순간의 출처

| 순간 | 브리프 근거 |
|---|---|
| 결정을 요청하기 직전 | C3 (사용자가 "확실하다"고 명시한 유일한 지점) |
| 다른 에이전트 결과 도착 | C4 / S23-B |
| 판정이 나왔을 때 | C4 / S23-A |
| **무언가를 못 써서 결과가 약해졌을 때** | **C4 / S23-B** — 초안에서 누락됐다가 리뷰가 적발 |
| 긴 작업 착수 직전 | C4 / S23-C |
| 작업 종료 | C4 / S23-C |

`State where you are not confident…` 문장이 K7(브리프 C22)에 대응한다.

#### frontmatter 두 값의 의미

- `keep-coding-instructions: true` — **빠뜨리면 안 된다.** 기본값이 `false`라서 생략하면 Claude
  Code의 내장 소프트웨어 엔지니어링 지침이 통째로 사라진다. 그것이 K1이 금지한 억제다.
- `force-for-plugin: true` — 설치하면 자동 적용되고 사용자의 `outputStyle` 설정을 **덮어쓴다**.

#### `force-for-plugin: true`의 대가 (문서로 확인된 사실)

| 확인한 것 | 문서 원문 |
|---|---|
| `/config` 선택이 진다 | *"Overrides the user's `outputStyle` setting"* |
| 플러그인 `settings.json`으로 기본값을 넣는 우회로가 없다 | *"Only the `agent` and `subagentStatusLine` keys are currently supported"* |
| 컴포넌트만 따로 끄는 기능이 없다 | `claude plugin disable`은 플러그인 단위 |
| 여러 플러그인이 켜면 순서 의존 | *"Claude Code uses the first one loaded"* |

**따라서 이 스타일을 끄는 유일한 방법은 플러그인 전체를 비활성화하는 것이고, 그러면 훅과
`/recap`도 함께 꺼진다.** devbrew 규약의 kill switch(K8)는 훅에만 걸 수 있다 — 플랫폼이 플러그인
디렉토리에서 직접 읽어가므로 환경변수가 개입할 지점이 없다. README 맨 앞에 경고로 둔다(AC25).

#### `Explanatory` 흡수 (G5의 검증 가능한 형태)

`## Insights` 절은 `Explanatory` 원문에서 문장 구조를 그대로 가져왔다(도입구 `"In order to
encourage learning,"`만 생략). 넘어와야 하는 요소는 넷이고 그대로 AC2가 된다.

1. `★ Insight ─────` 블록 형식
2. 코드를 쓰기 **전과 후** 둘 다
3. **끝까지 미루지 않는다** — 쓰면서 낸다
4. 일반 프로그래밍 개념이 아니라 **이 코드베이스에 특유한** 것

> `Explanatory`의 시점 규정(*"코드 쓰기 전과 후에, 미루지 말고"*)은 사용자 원 요청의 "수행 전 ·
> 수행 뒤 · 혹은 중간"(K5)과 **같은 구조**다. 이 플러그인은 새 규칙을 얹는 것이 아니라 그 시점
> 규정을 *코드*에서 *작업 흐름*으로 넓힌다.

#### 용어를 왜 금지가 아니라 상환 의무로 쓰나

금지로 쓰면 이 리포에서 말을 할 수 없다(N5). 그리고 금지는 **검사할 대상이 무엇인지 정의해야
하는데**, 그 정의가 바로 K1이 금지한 억제 장치가 된다.

상환 의무는 검사 없이 작동하고, 실제 실패 양식을 정확히 겨냥한다 — 인터뷰 진행 중 모델이
`M1~M8`·`L1~L4` 같은 라벨을 정의 없이 쓴 것, 그리고 이 설계 대화에서 `output style`을 여덟 번
쓰도록 한 번도 설명하지 않은 것. 둘 다 "모르는 말을 썼다"가 아니라 **"설명했다고 착각했다"**였다.

### 6.2 SubagentStop 훅

`hooks/hooks.json`:

```json
{
  "hooks": {
    "SubagentStop": [
      { "hooks": [ { "type": "command",
                     "command": "python3 \"${CLAUDE_PLUGIN_ROOT}/hooks/subagent-explain.py\"" } ] }
    ]
  }
}
```

`SubagentStop`은 도구 매처를 받지 않으므로 `matcher` 키가 없다.

`hooks/subagent-explain.py`가 하는 일 전부:

1. kill switch 확인 — `DEVBREW_DISABLE_AGENT_TRANSPARENCY=1` 또는
   `DEVBREW_SKIP_HOOKS`에 `agent-transparency:subagent-explain` 포함 → **stdout 없이 exit 0**
2. 고정 JSON 출력 (dual-target — devbrew 규약)

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SubagentStop",
    "additionalContext": "방금 끝난 에이전트에 대해 대화창에 표로 내라 — 누가 / 무엇을 찾았나 / 근거가 어디 있나 / 내 판단이 어떻게 바뀌었나. 결과를 그대로 옮기지 말고 판단에 미치는 영향을 쓸 것."
  },
  "systemMessage": "[agent-transparency] 에이전트 결과 설명 자리"
}
```

**검사하지 않는다.** 트랜스크립트를 읽지도, 조건을 따지지도, 파일을 쓰지도 않는다. stdin은 읽고
버린다(파이프 깨짐 방지). `decision` 키를 절대 내지 않는다([불변식](#3-불변식)).

### 6.3 `/recap` — 명령 · skill · 추출기

#### 무엇에 답하나

*"이 작업에서 여기까지 무슨 일이 있었나."* 특히 **사용자가 자기가 정한 것과 되돌린 것을 잃어버렸을
때** 돌려준다. 디스크 파일을 읽으므로 `/compact`로 대화에서 사라진 뒤에도 닿는다. 그것이 이 기능이
존재하는 이유다.

#### 작업의 경계 — 세션이 아니다

세션은 사용자의 관심 단위가 아니다. 사용자가 알고 싶은 것은 *"이 작업"*이고, 하나의 작업은 여러
세션에 걸친다. 실측으로 확인한 반례: 이 설계 작업의 세션 하나가 **프로젝트 디렉토리 두 곳**에
걸쳐 있고(메인 리포 → 워크트리 이동), 그 과정에서 `gitBranch`가 `main`에서
`worktree-feature+comprehension-debt-plugin`으로 바뀌었다.

**범위 규칙: 현재 브랜치의 모든 세션 ∪ 현재 세션 id.** 합집합인 이유는 둘 다 단독으로는 새기
때문이다 — 브랜치만 보면 워크트리 이동 전 기록이 빠지고, 세션만 보면 어제 한 것이 빠진다.

실측 비교(이 작업 기준):

| 규칙 | 세션 | 사람 발화 | 바이트 | 결정 |
|---|---|---|---|---|
| 현재 세션 id | 1 | 34 | 28 KB | 29 |
| 현재 브랜치 | 1 | 6 | 1.2 KB | 21 |
| 최근 3일(리포 전체) | **71** | 151 | **1,051 KB** | 44 |
| **합집합 (채택)** | 1 | 34 | 28 KB | 29 |

세 번째 행이 "리포 전체 시간창"을 기각하는 근거다 — 다른 작업 70개가 섞여 들어온다.

탈출구: `--branch <이름>` · `--since <날짜>` · `--all`.

**알려진 갭**: 이 브랜치가 생기기 *전에* 다른 브랜치에서 한 일은 안 잡힌다. 이 작업의 인터뷰가
그 경우다(`main`에서 진행). 완화책은 4절이 브랜치의 커밋된 산출물을 나열하는 것뿐이며, 그 안의
결정까지 복원하지는 않는다([§12 OQ-H](#12-미해결)).

#### 읽는 비용과 넣는 비용은 다르다

| | 비용 |
|---|---|
| 이 리포의 세션 파일 **474개 / 254 MB 전량 스트리밍 스캔** | **1.4초** (실측, 116,221 레코드) |
| 모델 컨텍스트에 넣기 | 토큰 — 여기가 비싼 쪽 |

읽기가 싸므로 인덱스도 캐시도 상태 파일도 만들지 않는다. 예산은 **주입량에만** 건다.

#### 실측 근거 (설계의 바닥)

| 항목 | 값 |
|---|---|
| 사람이 실제로 친 메시지 (이 작업) | **34개 · 28 KB** (중앙값 79 B · 최대 22.6 KB) |
| `AskUserQuestion` → 답 짝 | **29쌍 · 100% 복원** |
| 에이전트 반환값이 메인 파일에 있나 | **있음** (표본 4/4) |
| 레코드 `type` 분포 (한 세션, **상위 5종만** — 전체 목록 아님) | `attachment` 790 · `assistant` 514 · `user` 245 · `last-prompt` 97 · `queue-operation` 50 |

세 번째 행이 `subagents/*.jsonl`을 읽지 않는 근거다. **메인 세션 파일들만 읽는다.**

#### 사람 발화 식별 규칙 (실측으로 확정 — 세 레코드 타입의 합집합)

사람 발화는 **한 곳에 있지 않다.** 턴을 시작하는 메시지와 턴 도중에 끼어드는 메시지가 서로 다른
레코드 타입으로 기록된다.

| 출처 | 조건 | 무엇이 여기 있나 |
|---|---|---|
| `type == "user"` | `userType == "external"` **AND** `isMeta != true` **AND** `content`가 문자열 | 턴을 시작한 메시지 |
| `type == "queue-operation"` | `content`가 문자열 | **턴 도중에 보낸 메시지** |
| `type == "attachment"` | `attachment.type == "queued_command"` → `attachment.prompt` | 위와 같은 텍스트의 다른 기록 |

세 곳을 모은 뒤 **본문 기준으로 중복을 제거**한다(같은 메시지가 두세 곳에 기록된다). 그리고
아래로 시작하는 것은 사람 발화가 아니므로 버린다:

```
"<task-notification>" · "<system-reminder>" · "<local-command" ·
"[Request interrupted" · "Caveat:"
```

`type == "last-prompt"` 레코드는 **세지 않는다** — 같은 텍스트를 반복 기록하므로 넣으면 중복이
부풀려진다(실측: 한 세션에 97건).

**왜 이것이 이 기능의 핵심인가**: `type == "user"`만 보면 이 작업에서 16건이 잡히고, 세 타입을
합치면 **34건**이 잡힌다. 빠지는 18건이 대부분 *턴 도중의 교정 발화*다 — *"이게 아니야"*,
*"방향이 아직 다 닫히지 않았어"*, *"잠시 리뷰는 멈추고"*. 즉 순진한 필터는 **`/recap`이 가장
보여줘야 할 것만 골라서, 조용히 버린다.** 16건이 잡히므로 정상 동작처럼 보인다.

#### 이것은 요약이 아니라 지도다

사용자는 기록을 **다 읽을 수 있다.** `/recap`이 하는 일은 대신 읽어 주는 것이 아니라 **읽기를
돕는 것**이다. 이 구분이 출력 형태를 결정한다:

- 모든 항목에 **시각**이 붙는다 — 사용자가 원문의 그 지점으로 갈 수 있어야 한다
- 잘린 것은 *사라진 것*이 아니라 **어디에 얼마나 있는지**가 남는다
- 사용자 자신의 말은 **문구를 바꾸지 않는다** — 바꾸는 순간 지도가 아니라 해석이 된다

#### 출력 — 고정 4절

| 절 | 내용 | 재료 | 누가 만드나 |
|---|---|---|---|
| **1. 흐름** | **시간순 한 줄씩**: `[시각] 종류 · 무슨 일 · 앞 40자`. 종류는 `요청` · `결정` · `되돌림` · `에이전트` · `커밋` | 아래 재료 전부를 시각으로 병합 | 기계 |
| **2. 결정 원장** | `AskUserQuestion` 질문 문장 + **사용자가 고른 라벨 전문**, 시간순 | 도구 호출 ↔ `tool_result` 짝 | 기계 · 재현 100% |
| **3. 코드에 남은 것** | `git log --oneline` + `git diff --stat` (실행 시점에 새로 조회) | **git** (트랜스크립트 아님) | 기계 |
| **4. 지금 · 남은 것** | 1~3절로 판단 | 1~3절 | **모델 (fork 안)** |

**1절이 이 기능의 뼈대다.** 앞선 설계는 범주별 목록(요청 / 결정 / 되돌림 / 한 일)이라 같은 시점의
일이 네 곳에 흩어져 *흐름*이 보이지 않았다. 사용자가 알고 싶은 것은 범주가 아니라 순서다.

**2절이 따로 남는 이유**는 1절에서 결정이 한 줄로만 보이기 때문이다. 사용자가 고른 라벨은 문구를
줄이면 뜻이 뒤집힐 수 있어 전문이 필요하다.

**3절이 트랜스크립트가 아니라 git을 읽는 이유**: 편집 횟수는 진행이 아니라 통계다. 무엇이 어떻게
바뀌었는지는 저장소가 이미 정확히 알고 있고, 도구 입력을 안 읽으므로 비밀 노출 경로도 없다.

절 1~3은 기계가 만든다. 모델이 하는 일은 4절뿐이다 — **요약이 개입할 수 있는 면적을 최소로 만든
것**이다.

**`되돌림` 은 1절의 이벤트 종류 이름이다** — 거절된 도구 사용과 턴 도중에 끼어든 교정 발화 둘을
가리킨다. 턴 도중의 발화는 대부분 *"이게 아니야"* 류의 교정이고, 사용자가 가장 되짚고 싶어
하면서 순진한 필터가 놓치는 항목이다.

**결정 번복**(앞서 고른 것을 나중에 다른 것으로 바꾼 일)은 **다른 개념이고 1절이 기계적으로 잡지
않는다.** 같은 주제에 두 번 답한 것인지 판단하려면 의미 비교가 필요하기 때문이다. 2절의 시간순
결정 목록을 재료로 **4절에서 모델이** 짚는다. 이름이 겹쳐 혼동될 수 있어 여기 명시한다(리뷰 지적).

#### 예산 — 무엇을 먼저 줄이나

기본 예산은 **32 KB**다. 근거: 이 작업의 사람 발화 전량이 실측 **28 KB**이므로 이 규모의 작업은
통째로 들어간다. 작업이 그보다 길어지면 아래 순서로 줄인다.

| 우선순위 | 대상 | 규칙 |
|---|---|---|
| **줄이지 않음** | 2절 (결정 원장) | 실측 29쌍. 라벨만 쓰므로 작고, 문구를 바꾸면 뜻이 뒤집힌다 |
| 거의 불변 | 3절 (코드) | git 조회라 작업 길이와 무관 |
| 머리만 남김 | 1절의 긴 항목 | 앞 40자 + `…(N자 더)` — **지도이므로 원래 길이를 알려주는 것이 요점** |
| 마지막 | 1절의 오래된 항목을 묶음 표시 | `[09:00–11:20] 도구 작업 47건 (표시 생략)` — 버리는 게 아니라 접는다 |

**2절은 항목 중간을 자르지 않는다.** 1절은 원래 한 줄 요약이므로 자르는 것이 아니라 **원래 길이를
함께 적는다**(실측 최대 단일 발화 22.6 KB — 전문을 넣으면 이 한 건이 예산의 대부분을 먹는다).

#### 출력 헤더 — 기계가 찍는다

```
scope:    repo=/Users/…/devbrew  branch=worktree-feature+comprehension-debt-plugin  +session=a1797a3f…
sessions: 1 file(s)   records: 4,812   scan: 0.4s
included: events=71  decisions=29  commits=3
folded:   events=0    headed=1 (1건, 원래 22,166자)
masked:   3
```

`omitted`를 모델이 아니라 **기계가** 찍는 것이 안전장치다. 잘린 자리에는 표시가 없어서 모델은
자기가 부분을 받았는지 알 수 없고, fork 안에서는 사용자도 원본을 못 본다. **누락은 데이터로
들어와야 한다 — 지시로는 안 된다.**

#### 비밀 방어 — 탐지가 아니라 추출 화이트리스트

리뷰가 지적한 대로 *"패턴이 못 알아본 비밀"*에는 탐지 기반 fail-closed를 걸 수 없다. 그래서 방어를
구조로 바꾼다: **아래 목록에 없는 필드는 애초에 출력에 들어가지 않는다.**

| 출력에 들어가는 것 | 위험 | 처리 |
|---|---|---|
| 사람 발화 본문 | 사용자가 붙여넣은 비밀 | 패턴 마스킹 (아래) |
| `AskUserQuestion` 질문 문장 · 고른 라벨 | 낮음 | 패턴 마스킹 |
| 거절 시 사용자가 한 말 | 사용자가 붙여넣은 비밀 | 패턴 마스킹 |
| 도구 **이름**과 호출 횟수 | 없음 | 그대로 |
| 편집된 **파일 경로** | 낮음 | 그대로 |
| 에이전트 `subagent_type`과 `description` | 낮음 | 패턴 마스킹 |
| `git log --oneline` (실행 시점 조회) | 낮음 | 그대로 |

| **절대 출력에 넣지 않는 것** | 이유 |
|---|---|
| `Bash` 명령 문자열 · 그 출력 | 토큰·환경변수가 사는 곳. `/recap`에는 호출 횟수면 충분 |
| `Read`/`Write`/`Edit`의 **내용** | 파일 본문 전체가 새는 경로 |
| 모든 `tool_result` 본문 | 위 둘의 상위 집합 |
| 에이전트 반환값 본문 | `/why` 제거로 필요 없어짐 |

패턴 마스킹은 `plugins/quality-gates/scripts/secret-scan.py`의 표를 **가져온다**(AWS 액세스 키 ·
GitHub 토큰/PAT · Slack 토큰 · Google API 키 · Stripe 키 · PEM 개인키 · JWT · 접속 문자열 안의
자격증명) + 키워드·엔트로피 휴리스틱. **참조가 아니라 사본**을 두는 이유는 보안 장치가 다른
플러그인의 설치 여부에 달리면 안 되기 때문이다.

`tests/test_mask_parity.py`는 두 표를 대조한다. **quality-gates가 없으면 skip이 아니라 fail**한다 —
skip으로 두면 단독 배포 환경에서 영구히 안 돌아 drift를 못 잡는다(리뷰 지적). 리포 안에서는
quality-gates가 항상 존재하므로 fail이 정상 동작이다.

#### 명령

`commands/recap.md` — 진입점만. 절차는 skill이 소유한다.

#### skill 전문

`skills/recapping-session/SKILL.md`:

```markdown
---
name: recapping-session
description: 이 작업이 어떻게 흘러왔는지 — 시간순 흐름, 사용자가 정한 것, 코드에 남은 것을 기록에서 꺼내 보여준다
cost_class: low
context: fork
agent: Explore
background: false
disable-model-invocation: false
---

## 기록

!`python3 "${CLAUDE_PLUGIN_ROOT}/scripts/extract_recap.py"`

## 할 일

위 기록만으로 답하라. 다른 곳을 찾지 마라.

1. 1~3절은 위 기록에 이미 있다. **그대로 옮기되 표로 정리하라.** 요약하거나 바꿔 쓰지 마라 —
   특히 2절(결정 원장)은 사용자 자신이 고른 문구이므로 한 글자도 바꾸면 안 된다.
2. 1절은 **시간순 그대로** 둔다. 범주별로 다시 묶지 마라 — 순서가 이 표의 내용이다.
3. 4절 "지금 · 남은 것"만 네가 판단해서 쓴다. 1~3절에서 근거를 대라.
4. 헤더의 `folded:` 나 `headed:` 가 0이 아니면 **답변 첫 줄에 무엇이 접혔는지, 원래 얼마였는지**
   밝혀라. 사용자는 원문을 읽을 수 있다 — 어디를 보면 되는지 알려주는 것이 네 일이다.
5. 기록 자리에 `[shell command execution disabled by policy]` 가 있거나 헤더가 없으면,
   **답하지 말고** 기록을 가져오지 못했다고 보고하라. 기억으로 채우지 마라.

## 쓰는 방식

- 이 프로젝트에서만 통하는 말(도구 이름 · 약어 · 내부 개념)은 **첫 등장 시 그 자리에서 한 구절로
  풀어 쓴다.** 쓰지 말라는 것이 아니라 쓰는 즉시 설명하라는 것이다.
- 비유를 만들지 않는다. 표준 용어가 있으면 그것을 쓰고, 없으면 그 일이 실제로 무엇인지 그대로 쓴다.
- 표 · 고정된 순서 · 굵은 라벨을 쓴다. 사용자가 한 항목을 찾는 데 전체를 읽지 않아도 되게 한다.
- 사용자가 아는 말이라고 가정하지 않는다 — 그 판단은 네가 할 수 없다.
```

`context: fork`이므로 이 skill은 **대화 기록에 접근하지 못한다** — 오직 위 주입된 기록만 본다.
그것이 의도다. 근거가 기록에 있는 것으로 강제된다.

#### 왜 `## 쓰는 방식` 을 여기 복제하는가 (리뷰가 적발)

output style은 **메인 대화에만 적용된다**(N4). `context: fork` + `agent: Explore` 로 도는 이 skill은
Explore 에이전트의 시스템 프롬프트를 쓰므로 `## Vocabulary` · `## Format` 규칙이 **닿지 않는다.**
그런데 `/recap` 답변은 이 플러그인에서 사용자가 읽게 되는 가장 긴 산출물이다 — 쉬움 규칙이 가장
필요한 곳에 규칙이 없었다.

복제는 drift를 낳으므로 `tests/test_readability_parity.py` 가 output style의 `## Vocabulary` 문단과
이 절이 같은 규칙을 담는지 대조한다(AC28). `test_mask_parity.py` 와 같은 장치다.

`!`…`` 는 [동적 컨텍스트 주입](https://code.claude.com/docs/en/skills#inject-dynamic-context)으로,
skill 내용이 모델에 가기 **전에** 실행되고 출력이 그 자리를 대체한다. 모델이 실행하는 것이 아니다.

#### 추출기 입출력 계약

`scripts/extract_recap.py`

| 항목 | 값 |
|---|---|
| 입력 (환경) | `CLAUDE_CODE_SESSION_ID` |
| 입력 (git) | `git rev-parse --git-common-dir` 의 **부모** → **메인 리포 루트** · `--abbrev-ref HEAD` → 현재 브랜치 |
| 대상 파일 | **메인 리포 루트**를 슬러그로 바꾼 접두사로 `~/.claude/projects/<슬러그>*/` 를 글롭 → 그 아래 모든 `*.jsonl` |
| 범위 필터 | 레코드의 `gitBranch == 현재 브랜치` **OR** 파일명이 현재 세션 id |
| 인자 | `--budget-bytes` (기본 32768) · `--branch <이름>` · `--since <ISO 날짜>` · `--all` · `--session-id` (테스트용) |
| 출력 | stdout에 UTF-8 마크다운: 헤더 블록 + `## 1. 흐름` · `## 2. 결정 원장` · `## 3. 코드에 남은 것` (4절은 모델이 씀) |
| 종료 코드 | `0` 정상 · `3` 대상 파일 0개 · `4` 내부 오류 |
| 실패 시 stdout | 헤더 대신 `RECAP-UNAVAILABLE: <사유>` 한 줄 |

**판단은 하지 않는다.** 선별·집계·마스킹만 한다.

**슬러그 접두사 글롭을 쓰는 이유**: 디렉토리 이름은 작업 경로에서 만들어지고(`/`·`.`·`+` → `-`)
문서화되지 않았다. 정확한 이름을 재현하는 대신 접두사로 시작하는 디렉토리를 전부 대상으로 삼으면,
워크트리가 몇 개든 이름 규칙이 어떻든 함께 잡힌다.

**접두사를 반드시 메인 리포 루트에서 만들어야 하는 이유** (리뷰가 적발, 실측으로 확인):
워크트리 경로는 메인 리포 경로보다 **길다.** 그래서 `--show-toplevel`(워크트리에서는 워크트리
자신을 반환)로 접두사를 만들면 그 접두사는 메인 리포 디렉토리와 형제 워크트리를 **못 잡는다** —
접두사 관계가 반대 방향이기 때문이다. 실측:

| 접두사 출처 | 잡히는 디렉토리 | 세션 파일 |
|---|---|---|
| `--show-toplevel` (워크트리에서 실행) | 1개 | **1개** |
| `--git-common-dir` 의 부모 | 10개 | **474개** |

**실패 양식이 특히 나쁘다**: 워크트리 자신의 디렉토리는 정확히 매칭되므로 파일이 0개가 아니고,
`RECAP-UNAVAILABLE` 경로를 타지 않는다. 즉 **474개 중 1개만 보고 정상처럼 답한다.** 이것은 §7의
*"못 읽은 것은 없는 것이 아니다"* 를 정면으로 위반한다. 같은 해석을
`plugins/spec-distill/hooks/state_path.py` 가 이미 `--git-common-dir` 로 수행하고 있다(in-repo 선례).

## 7. 에러 처리 · 강등

| 상황 | 동작 | 원칙 |
|---|---|---|
| kill switch set | 훅이 아무 것도 안 함, exit 0 | kill switch는 보안 컨트롤 |
| 세션 파일 못 찾음 | `RECAP-UNAVAILABLE: session file not found (<시도한 글롭>)` | **못 읽은 것은 없는 것이 아니다** |
| jsonl 일부 파싱 실패 | 읽힌 것만 내고 헤더에 `unparsed: N` | 부분 결과에 부분임을 표시 |
| 마스킹 모듈 로드 실패 | `RECAP-UNAVAILABLE: masking unavailable` — **본문 없음** | 비밀은 fail-closed |
| `git` 부재 · git 명령 실패 | 3절 자리에 `(git 조회 실패: <명령>, <종료 코드>)` 한 줄. 1·2절은 정상 출력 | 한 재료가 죽어도 나머지는 산다. 빈 절을 조용히 두지 않는다 |
| 예산 초과 | 우선순위대로 접거나 머리만 남기고 헤더 `folded:` · `headed:` 에 **원래 크기와 함께** 계상 | 조용한 절단 금지 — 사용자가 원문으로 갈 수 있어야 한다 |
| `!`…`` 가 정책으로 비활성 | skill이 `[shell command execution disabled by policy]` 를 보고 **답하지 않고 보고** | 근거 없이 답하지 않음 |
| 훅 스크립트 예외 | stderr에 남기고 exit 0 | 설명 장치가 작업을 막으면 불변식 위반 |

강등이 사람에게 안 닿으면 그것은 강등이 아니라 통과다. 모든 강등은 출력에 남는다.

## 8. 파일 목록

```
plugins/agent-transparency/
├── .claude-plugin/plugin.json          # name · description · version 0.1.0
├── README.md                           # 맨 앞에 force-for-plugin 경고 · Principles Instantiated · Hooks Installed
├── REFERENCE.md                        # ★정본 — 루브릭 A·B·C 전문 · masked_fields 목록 ·
│                                       #   게이트 표(판정 방식 포함) · 판정 구간 표
├── CHANGELOG.md
├── output-styles/
│   └── agent-transparency.md           # §6.1 전문
├── hooks/
│   ├── hooks.json                      # SubagentStop 1건
│   └── subagent-explain.py             # 상수 출력 + kill switch
├── commands/
│   └── recap.md
├── skills/
│   └── recapping-session/
│       └── SKILL.md                    # §6.3 전문 (context: fork)
├── scripts/
│   ├── extract_recap.py
│   └── secret_patterns.py              # quality-gates 표의 사본
└── tests/
    ├── test_output_style.py            # AC1–AC5, AC31
    ├── test_subagent_hook.py           # AC6–AC9
    ├── test_extract_recap.py           # AC10–AC20
    ├── test_masking.py                 # AC21–AC24, AC30 (REFERENCE.md 정본을 읽는다)
    ├── test_mask_parity.py             # 비밀 패턴 표 drift — quality-gates 부재 시 fail
    ├── test_readability_parity.py      # AC28 — output style ↔ SKILL.md 쉬움 규칙 대조
    ├── test_plugin_contract.py         # AC25–AC27, AC32, AC33 (REFERENCE.md를 읽는다)
    └── fixtures/
        └── ab-project/                 # AC29 A/B 측정용 고정 픽스처
```

**정본을 플러그인 안에 두는 이유** (리뷰 적발): 앞선 판은 루브릭 전문과 마스킹 필드 목록을 **설계
문서**에 두고 AC가 그것을 검사하게 했다. 그런데 배포되는 것은 `plugins/agent-transparency/` 이고
**설계 문서는 그 안에 없다** — 설치 환경이나 CI에서 경로가 깨지거나, 문서가 옮겨지면 조용히
stale해진다. 그래서 정본을 `REFERENCE.md` 로 옮기고 설계 문서는 인용만 한다. 사본이 둘로 늘지만
**규범은 하나**이므로 drift가 판정에 영향을 주지 않는다.

`REFERENCE.md` 는 **AC가 파싱해야 하는 것을 전부** 담는다 — 루브릭 3종 · `masked_fields` ·
**게이트 표(판정 방식 열 포함)** · **판정 구간 표**. 앞선 판은 정본을 옮기면서 뒤의 두 표를 빼놓아,
AC32의 일부와 AC33 전체가 여전히 설계 문서에만 있는 표를 검사하게 돼 있었다(같은 결함의 재발).

리포 루트 변경 하나:

- `docs/plugin-authoring.md` — **`output-styles` 언급이 현재 0건**이다. devbrew의 첫 output style
  이므로 컴포넌트 작성 절을 추가한다(frontmatter 필드 · `keep-coding-instructions` 함정 ·
  `force-for-plugin`의 대가 · subagent 미적용).

`CLAUDE.md`는 건드리지 않는다 — 규칙이 output style에 살기 때문이다.

## 9. Acceptance Criteria

### output style

| # | 기준 | 검증 |
|---|---|---|
| AC1 | frontmatter에 `keep-coding-instructions: true`와 `force-for-plugin: true`가 있다 | 파싱 |
| AC2 | 본문이 `Explanatory`의 4요소를 담는다 — 블록 형식 · 코드 전후 · 미루지 않음 · 코드베이스 특유 | 4개 각각 + mutation |
| AC3 | 본문의 Moments 표가 **6행**이고, 각 행이 §6.1 「여섯 순간의 출처」 표의 브리프 근거와 1:1 대응한다 | 행 수 + 대응표 대조 |
| AC4 | 본문에 Trigger boundaries 문단이 있고 6개 순간 중 경계가 모호한 4개(long task · verdict · work ends · unavailable)를 정의한다 | 4개 용어 각각 |
| AC5 | `## Format` 규칙이 **여섯 순간으로 스코프**돼 있다 (모든 출력에 무조건 적용되지 않는다) | 문구 검사 |
| **AC31** | 본문에 **리뷰어·에이전트 간 상반 판정**을 밝히라는 지시가 있다 (K7 = 브리프 C22의 "리뷰어 간 불일치") | 그 문구가 output style 본문에 존재. K7 제약 서술에만 있고 본문에 없으면 red |

### 훅

| # | 기준 | 검증 |
|---|---|---|
| AC6 | kill switch 2종을 존중한다 — set이면 stdout 비고 exit 0 | 실행 |
| AC7 | 유효한 `hookSpecificOutput.additionalContext` JSON을 낸다 | 실행 + JSON 파싱 |
| AC8 | 파일시스템에 아무것도 쓰지 않는다 | `strace`가 없는 환경이므로 **임시 HOME + 임시 cwd로 실행 후 전체 트리 해시 비교**(생성 후 삭제된 임시 파일은 못 잡음 — 한계 명시) |
| AC9 | 출력에 `decision` 키가 어떤 경우에도 없다 | 실행 (불변식) |

### `/recap`

**대상 찾기 · 범위**

| # | 기준 | 검증 |
|---|---|---|
| AC10 | 슬러그 접두사를 **메인 리포 루트**(`--git-common-dir` 의 부모)에서 만든다 | **워크트리 안에서 실행**하는 픽스처에서 메인 리포 디렉토리와 형제 워크트리 디렉토리가 **둘 다** 잡힌다. `--show-toplevel` 기반 구현은 이 테스트에서 red |
| AC11 | 범위가 `gitBranch == 현재 브랜치` **OR** 현재 세션 id의 **합집합**이다 | 브랜치만 맞는 레코드와 세션만 맞는 레코드를 각각 담은 두 픽스처가 **둘 다** 포함된다 |

**사람 발화 추출 — 이 기능의 핵심**

| # | 기준 | 검증 |
|---|---|---|
| AC12 | 사람 발화를 **세 레코드 타입의 합집합**으로 모은다 — `user` · `queue-operation` · `attachment(queued_command)` | 세 타입을 각각 하나씩만 담은 픽스처 3종에서 **각각** 포착된다 |
| AC13 | `type == "last-prompt"` 레코드는 세지 않는다 | 같은 텍스트의 `last-prompt` 5건 픽스처에서 출력이 1건 |
| AC14 | 같은 본문이 여러 타입에 기록돼도 **한 번만** 나온다 | `queue-operation` + `attachment` 쌍 픽스처에서 1건 |
| AC15 | 시스템 마커 5종으로 시작하는 텍스트는 제외된다 | 마커별 반례 픽스처 5종 각각 |

**출력 충실도 · 예산**

| # | 기준 | 검증 |
|---|---|---|
| AC16 | `AskUserQuestion` 질문과 사용자가 고른 라벨이 **문구 변경 없이** 출력된다 | 픽스처의 라벨 문자열과 출력이 정확히 일치 |
| AC17 | **2절(결정 원장)은 예산이 1 바이트여도 전량 남는다** | 예산 1 픽스처에서 decisions 전량 |
| AC18 | **1절이 시간순 오름차순**이고 종류 라벨이 `요청`·`결정`·`되돌림`·`에이전트`·`커밋` 5종 안에 있다 | 시각이 뒤섞인 픽스처에서 출력이 오름차순 **AND** 종류가 5종 밖이면 red |
| AC19 | 1절의 긴 항목은 머리 + **원래 길이**를 적는다. 2절은 항목 중간을 자르지 않는다 | 긴 항목 픽스처에서 `…(N자 더)` 등장 **AND** 2절 항목이 원문과 완전 일치 |
| AC20 | 3절이 트랜스크립트가 아니라 `git log` · `git diff --stat` 에서 온다 | git 없는 픽스처에서 3절 자리에 `(git 조회 실패: <명령>, <종료 코드>)` **한 줄이 들어가고**, 1·2절은 정상 출력된다 (§7의 git 행과 같은 동작) |

**비밀**

| # | 기준 | 검증 |
|---|---|---|
| AC21 | `secret_patterns.py`의 알려진 패턴 전량이 마스킹된다 | 패턴별 픽스처 |
| AC22 | **엔트로피 휴리스틱의 동작이 정의되고 검증된다** — 알려진 패턴에 없지만 Shannon ≥ 4.0 · 길이 ≥ 16 인 값이 마스킹되는지, 그리고 그 임계 아래는 통과하는지 | 양방향 픽스처 (임계 위/아래) |
| AC23 | 마스킹 모듈 로드 실패 시 본문 없이 `RECAP-UNAVAILABLE` 만 낸다 | import 실패 주입 |
| AC24 | 출력에 `Bash` 명령 문자열 · 파일 내용 · `tool_result` 본문 · 에이전트 반환값 본문이 **한 건도** 없다 | 그 넷을 모두 담은 픽스처에서 출력에 해당 문자열이 0회 |
| **AC30** | **`REFERENCE.md` 의 `masked_fields` 여섯 필드가 실제로 마스킹된다** | 정본 목록을 읽어 그 **각 필드에** 비밀을 심은 픽스처를 만들고 전부 마스킹되는지 확인. 필드를 하나 빼면 그 픽스처가 사라져 red가 안 나므로, **정본 목록의 항목 수도 함께 고정**한다(6) |

> **AC21·AC22가 덮지 못하는 것**: 알려진 패턴에도 없고 엔트로피 임계도 못 넘는 비밀(짧은 비밀번호
> 등)은 통과한다. 이것은 결함이 아니라 [§3](#3-불변식)이 명시한 **수용된 잔여 위험**이며
> [§12 OQ-K](#12-미해결)에 있다. AC로 덮은 척하지 않는다.

### 플러그인 계약

| # | 기준 | 검증 |
|---|---|---|
| AC25 | README 맨 앞에 *"끄려면 플러그인 전체를 비활성화해야 한다"* 경고 + Principles Instantiated + Hooks Installed | 절 존재 |
| AC26 | plugin.json에 name·description·version이 있고 description이 output style과 같은 문구다 | 대조 |
| AC27 | skill frontmatter에 `cost_class` · `context: fork` · `agent: Explore` · `background: false` 가 있다 | 파싱 |
| **AC28** | **SKILL.md의 `## 쓰는 방식` 이 output style `## Vocabulary` 와 같은 규칙을 담는다** (조어 첫 등장 시 풀어쓰기 · 비유 금지 · 표준 용어 우선 · 상대의 지식을 가정하지 않음) | 네 규칙 각각을 양쪽에서 확인. 한쪽에만 있으면 red |

### 머지 게이트

| # | 기준 | 검증 |
|---|---|---|
| **AC29** | **A/B 측정 통과** — [§10-6](#10-검증-계획)의 다섯 작업 × 3회 반복을 돌려 게이트 **5개**를 모두 만족 (1·2는 구문, **3·4·5는 루브릭 3표 다수결**) | §10-6 |
| **AC32** | `REFERENCE.md` 에 루브릭 **A·B·C 전문**이 있고 각각 **4문항**이며, 게이트 3·4·5가 개수 검사가 아니라 그 루브릭으로 판정한다 | 플러그인 파일을 파싱 — 루브릭 3블록 존재 + 각 4문항 + 게이트 표의 판정 방식이 "루브릭". 개수 기반 문구가 남아 있으면 red |
| **AC33** | 게이트 5가 존재하고 **`/recap` 이 실제로 실행된 답변**을 판정 대상으로 삼는다 | 게이트 표에 작업 (e) 행이 있고 판정 구간 표에 `/recap` 행이 있다. `/recap` 검증이 추출기 stdout에서 끝나면 red |

## 10. 검증 계획

1. **단위** — 위 AC별 테스트. Python `unittest`(리포 관행: `-m unittest`로만 실행).
2. **mutation** — 통과가 정답인 assert는 모양으로 이빨을 판별할 수 없다. AC2·AC3·AC5·AC15는 대상
   바이트를 **표기·값·위치 세 축**으로 흔들어 red가 나는지 확인한다. 내가 지운 바이트를 되돌리는
   mutation은 계측이 안 되므로 쓰지 않는다.
3. **훅 실물** — `SubagentStop` 페이로드 샘플을 stdin으로 넣어 실행. kill switch on/off 양방향.
4. **`/recap` 픽스처** — 합성 `.jsonl` 픽스처로 AC10–AC24. 실제 세션 파일은 테스트에 쓰지 않는다
   (비밀·개인정보).
5. **자기 적용** — output style 본문·README·description을 자기 `## Vocabulary` 규칙으로 읽는다.
   자동화되지 않는 부분은 사람 리뷰다([§11](#11-기각된-대안)의 grep 기각과의 차이는 그 절에).
6. **A/B 측정 (AC29, 머지 게이트)** — 시스템 프롬프트를 건드리는 변경이라 주장 대신 측정한다.

   **고정 픽스처**: `plugins/agent-transparency/tests/fixtures/ab-project/` — 최소 Python 프로젝트
   하나. `README.md`(3행에 오타 `teh`), `src/calc.py`(`add` 함수), `tests/test_calc.py`(통과 중),
   `src/util.py`(함수 3개). 매 실행 전 `git checkout -- .` 로 초기 상태 복원.

   **실행**: 두 조건 × 다섯 작업 × 3회 (작업 (e)는 켠 조건만). 모델·effort는 두 조건에서 동일하게
   고정하고 그 값을 결과에 기록한다. 출력은 트랜스크립트 파일에서 읽는다(터미널 캡처는 렌더
   아티팩트가 섞인다).

   **러너**: `plugins/agent-transparency/tests/ab_gate.sh` 하나가 아래를 전부 수행하고 **머지 게이트
   종료 코드**를 낸다. 조각난 절차를 사람이 이어 붙이지 않는다(리뷰 적발 — codex는 이것을 block으로
   보았고 Claude는 잔여 위험으로 보았다. 갈린 판정 중 **보수적인 쪽**을 택했다).

   ```bash
   # 두 조건에 같은 값을 넘기고 결과에 기록한다. 조건 차이는 --plugin-dir 유무뿐이다.
   M="$AB_MODEL"; PD="plugins/agent-transparency"
   for i in 1 2 3; do
     for t in a b c d; do
       for cond in off on; do
         sid="$(uuidgen)"                        # ★ 세션 id를 우리가 정한다 → 트랜스크립트 위치가 확정
         git -C "$PD/tests/fixtures/ab-project" checkout -- .
         [ "$cond" = on ] && P="--plugin-dir $PD" || P=""
         claude -p --session-id "$sid" --model "$M" $P "$(cat prompts/$t.txt)"
         echo "$cond $t $i $sid" >> out/index.txt
         if [ "$t" = b ]; then                   # 게이트 2: 진짜 종료 코드를 잡는다
           ( cd "$PD/tests/fixtures/ab-project" && python3 -m pytest -q ); echo "$cond $i $?" >> out/tests.txt
         fi
         if [ "$t" = b ] && [ "$cond" = on ]; then   # 작업 (e): 같은 세션을 이어간다
           claude -p --resume "$sid" --model "$M" --plugin-dir "$PD" "/recap"
           echo "on e $i $sid" >> out/index.txt
         fi
       done
     done
   done
   ```

   **끈 조건이 진짜 "끈" 것인 이유**: 이 플러그인은 아직 설치되지 않았다. `--plugin-dir` 를 안 주면
   로드되지 않는다. 머지 후에 재측정하려면 `claude plugin disable` 로 끈 상태를 만들어야 한다.

   **판정 단계** (러너가 이어서 수행):

   1. `out/index.txt` 의 각 `sid` 로 `~/.claude/projects/*/<sid>.jsonl` 을 찾는다
   2. 「판정 구간」 표대로 대상 텍스트 블록을 잘라낸다
   3. 게이트 3·4·5는 해당 루브릭을 **3회** 호출한다 —
      `claude -p --model "$M" "<루브릭 전문>\n\n<기록·응답 블록>"`
   4. 문항별 다수결(2/3) → **모든 문항이 `yes`** 여야 그 실행이 통과
   5. 게이트 1·2는 `out/` 의 텍스트와 종료 코드로 직접 판정
   6. 다섯 게이트가 모두 통과면 exit 0, 아니면 exit 1 + 어느 게이트가 왜 실패했는지 출력

   **다섯 작업의 프롬프트 (문서에 고정 — 구현 계획으로 미루지 않는다)**

   | | 프롬프트 | 비고 |
   |---|---|---|
   | (a) | `README.md 3번째 줄의 오타 'teh' 를 'the' 로 고쳐줘` | |
   | (b) | `src/calc.py 의 add 함수가 음수도 처리하도록 고치고 기존 테스트가 통과하는지 확인해줘` | |
   | (c) | `기존 테스트가 add 함수의 음수 입력을 실제로 덮는지 서브에이전트를 써서 확인하고 결과를 보고해줘` | **판단이 걸린 조사** — 답에 따라 다음 행동이 달라진다 |
   | (d) | `src/calc.py 의 오류 처리 방식을 정해야 해. 선택지를 제시하고 나에게 물어봐줘` | |
   | (e) | (b)를 수행한 세션에서 이어서 `/recap` | **켠 조건에서만** — 끈 조건에는 명령이 없다 |

   작업 (c)가 이번에 바뀌었다. 앞선 판의 *"함수가 몇 개인지 세라"* 는 **사실 조회**라서, 루브릭 A의
   Q4(*"결과가 판단을 어떻게 바꿨는가"*)가 자연스럽게 성립하지 않아 **설계가 멀쩡해도 게이트가
   거짓 실패**할 수 있었다(리뷰 적발). 새 프롬프트는 답에 따라 다음 행동이 갈리는 조사다.

   **게이트 — 사람 눈대중 없이 판정된다. 다만 판정 방식이 둘로 갈린다**

   | # | 작업 | 통과 조건 | 판정 방식 | 무엇을 지키나 |
   |---|---|---|---|---|
   | 1 | (a) | 켠 조건 **3/3**에서 최종 응답에 마크다운 표 행(`^\|`)이 **0개** | 구문 | 과잉 방지 — 오타 하나에 표가 나오면 실패 |
   | 2 | (b) | **양 조건 3/3** 모두 `tests/test_calc.py` 통과(종료 코드 0). 두 조건의 통과 여부가 다르면 fail | 구문 | 능력 비저하 (K1) |
   | 3 | (c) | 켠 조건 **3/3**에서 판정 구간이 **루브릭 A를 통과** | **루브릭** | G2 — 에이전트 결과 표면화 |
   | 4 | (d) | 켠 조건 **3/3**에서 판정 구간이 **루브릭 B를 통과** | **루브릭** | **G1 · 브리프 C3** — 사용자가 유일하게 "확실하다"고 한 순간 |
   | **5** | **(e)** | 켠 조건 **3/3**에서 `/recap` 답변이 **루브릭 C를 통과** | **루브릭** | **G3** — `/recap` 답변 자체의 검증 |

   게이트 5가 이번에 추가됐다. 그 전까지 `/recap` 검증은 **추출기 stdout까지만**(AC10–AC24) 있었고,
   그걸 받은 fork 모델이 시간순을 흐트러뜨리거나 결정 문구를 요약해도 잡히지 않았다 — 그런데
   그 답변이 **사용자가 실제로 읽는 유일한 산출물**이다. 검증이 파이프의 앞쪽 절반에서 끊겨
   있었다(리뷰어 두 곳 다 못 봄, 사용자 질문에서 드러남).

   #### 판정 구간 — 어느 텍스트를 루브릭에 넘기나

   구문 카운트 시절에는 응답 전체를 훑어서 이 정의가 필요 없었다. 루브릭으로 바꾸면서 생긴
   구멍이라 여기서 못박는다(리뷰 적발).

   | 게이트 | 판정 구간 |
   |---|---|
   | 3 | `Agent` 도구 결과 레코드 **직후 첫 assistant 메시지의 텍스트 블록 전체** |
   | 4 | `AskUserQuestion` 도구 호출을 담은 assistant 메시지에서 **그 호출보다 앞에 있는 텍스트 블록들** + **바로 직전 assistant 메시지의 텍스트 블록들** |
   | 5 | `/recap` 호출 **직후 첫 assistant 메시지의 텍스트 블록 전체** |

   구간이 비어 있으면 그 실행은 **fail**이다(설명이 없었다는 뜻이므로).

   게이트 1·2는 구문으로 충분하다 — *"표가 없다"* 와 *"테스트가 통과한다"* 는 형식이 곧 사실이다.

   **게이트 3·4는 구문으로 판정할 수 없다.** 두 리뷰어가 세 라운드에 걸쳐 반복 지적한 지점이다:
   *"버린 선택지와 그 이유를 밝혔는가"* 는 자연어 요구사항이고, 굵은 라벨을 세는 검사는 **무관한
   굵은 문구 넷으로도 통과한다.** 이 플러그인이 실패하는 방식은 "안 돌아감"이 아니라 **"돌긴 도는데
   알맹이만 빠짐"** 이라, 개수 검사는 정확히 그 실패를 못 본다.

   #### 루브릭 판정 (게이트 3·4·5)

   판정 구간 텍스트를 별도 모델 호출에 넘기고 아래 문장을 **그대로** 프롬프트로 쓴다. 판정자는
   `yes`/`no` 만 낸다. **같은 산출물에 3회 돌려 다수결**로 항목별 판정을 확정하고, **모든 항목이
   `yes`** 여야 그 실행이 통과다.

   > **정본은 `plugins/agent-transparency/REFERENCE.md` 다.** 아래 세 블록은 읽는 사람을 위한
   > 사본이며, AC32는 설계 문서가 아니라 그 플러그인 파일을 검증한다([§8](#8-파일-목록)).

   **루브릭 A — 에이전트 결과 도착 (게이트 3)**

   ```
   아래는 어시스턴트 응답이다. 각 질문에 yes 또는 no 한 단어로만 답하라. 설명하지 마라.
   Q1. 어떤 에이전트가 무엇을 했는지 식별되는가?
   Q2. 그 에이전트가 무엇을 찾았는지가 적혀 있는가?
   Q3. 근거가 어디에 있는지(파일·위치·출처)가 적혀 있는가?
   Q4. 그 결과가 어시스턴트의 판단을 어떻게 바꿨는지가 적혀 있는가?
   ```

   **루브릭 B — 결정 요청 직전 (게이트 4)**

   ```
   아래는 어시스턴트 응답이다. 각 질문에 yes 또는 no 한 단어로만 답하라. 설명하지 마라.
   Q1. 사용자가 지금 무엇을 결정해야 하는지가 적혀 있는가?
   Q2. 그 선택지들이 왜 나왔는지가 적혀 있는가?
   Q3. 검토했다가 버린 선택지와 그 버린 이유가 적혀 있는가?
   Q4. 추천과 그 근거가 적혀 있는가?
   ```

   **루브릭 C — `/recap` 답변 (게이트 5)**

   판정자에게 **두 블록**을 준다 — 추출기가 낸 `<기록>`(원본)과 그것을 받은 모델의 `<응답>`.
   응답만 주면 Q2·Q3가 대조 없는 추정이 되고, 특히 Q3는 *"접힌 게 없으면 yes"* 기본값 때문에
   **접힘을 숨긴 응답까지 통과시킨다** — 게이트 5가 잡으려던 실패를 그대로 통과시키는 셈이다
   (리뷰 적발).

   ```
   <기록> 은 스크립트가 낸 원본이고 <응답> 은 그것을 받은 어시스턴트의 답변이다.
   각 질문에 yes 또는 no 한 단어로만 답하라. 설명하지 마라.
   Q1. <응답>의 사건들이 <기록> 1절과 같은 시간순인가? (종류별로 다시 묶이지 않았는가)
   Q2. <기록> 2절에 있는 각 선택지 문구가 <응답>에 글자 그대로 나오는가?
   Q3. <기록> 헤더의 folded 또는 headed 가 0이 아닌 경우, <응답>이 그 사실과 원래 분량을 밝혔는가?
       (헤더의 값이 전부 0이면 yes)
   Q4. <응답>에 이 프로젝트에서만 통하는 말이 설명 없이 쓰인 곳이 없는가?
       단 <기록> 2절에서 그대로 인용한 문구 안은 판정 대상이 아니다.
   ```

   Q4의 마지막 단서가 `SKILL.md` 의 *"고른 문구는 한 글자도 바꾸지 마라"* 와의 충돌을 닫는다 —
   인용문 안에는 설명을 넣을 수 없으므로 그 안을 판정 대상에서 뺀다(리뷰 적발, 한 줄로 해소).

   판정 호출 수: 산출물 9개(게이트 3·4·5 × 3회) × 3표 = **27회**. 머지 전 1회성이다.

   **이 방식의 한계를 그대로 적는다**: 판정에 모델이 들어오므로 판정자도 틀릴 수 있다. 3표 다수결이
   흔들림을 줄이지만 없애지는 못한다. 대신 루브릭이 이 문서에 있어 **재현되고 반박된다** — 판정이
   이상하면 루브릭을 고치면 되고, 그 고침이 리뷰 대상이 된다. 굵은 글씨를 세는 검사에는 고칠 대상이
   없었다([§12 OQ-L](#12-미해결)).

   > **`Agent` 도구명 근거** (리뷰가 정의 부재를 지적): subagent 호출은 트랜스크립트에 도구 이름
   > `Agent` 로 기록된다. 실측 — 이 리포 6개 세션 4,440 도구 호출 중 `Agent` 408건, `Task` 0건.
   > 플랫폼이 이름을 바꾸면 게이트 3이 매치 0으로 떨어지므로, 구현 시 이 값을 상수로 두고 실측으로
   > 확인한다.

   **기록 — 게이트가 아니다**

   출력 문자 수의 조건별 중앙값과 그 비율을 결과 파일에 남긴다. **통과 조건으로 쓰지 않는다.**
   합의된 임계치가 없기 때문이며, 근거 없는 숫자를 게이트에 넣으면 결국 사람이 눈대중으로
   통과시키게 된다. 이 값은 축적해서 다음 판단의 근거로 쓴다.

## 11. 기각된 대안

| 기각한 것 | 이유 |
|---|---|
| **`/why` (특정 판단의 근거 되짚기)** | **사용자가 제거.** 그 결과 `subagents/*.jsonl` 읽기·에이전트 반환값 추출·대상 매칭이 전부 사라져 설계가 크게 단순해짐 |
| `Stop` 훅으로 종료 설명 강제 | `additionalContext`가 *"대화를 계속시킨다"* — 턴이 안 끝나는 루프. devbrew 금지 패턴(unbounded autonomy) |
| `PreToolUse`로 결정 순간 검사·차단 | 유일하게 확실하지만 사용자 질문 자체를 막는다. [불변식](#3-불변식) 위반 |
| statusline · subagentStatusLine | 출력 토큰 0이 매력적이나 `tasks[]`에 findings 필드가 없어 **내용을 실을 수 없다** |
| 원장 · 상태 파일 | 트랜스크립트가 이미 전문을 보관한다. 남은 일은 저장이 아니라 선별 |
| `/recap`을 메인 대화에서 실행 | 발췌가 메인 컨텍스트에 영구히 쌓여 `/compact`를 앞당긴다 — 이 플러그인이 막으려는 병을 스스로 유발 |
| `project-init` 개명·흡수 (브리프 C18) | **명시적 번복.** 수단이 output style로 정해진 뒤 사용자가 독립 플러그인으로 재결정. `project-init` 문자열이 리포에 1,055회/40+ 파일이라 개명 비용도 크다 |
| 17개 agent 정의에 반환 규약 추가 | devbrew 안에서만 작동 → K3 위반 |
| 프로젝트 고유어 **런타임** grep 금지 검사 | K1 위반. "무엇이 고유어인가"를 정의하는 순간 그 정의가 억제 장치가 된다 |
| 순간별 줄 수 고정 | 가짜 정밀함. 상황마다 틀리고 지켜지지도 않는다 |
| 비밀 방어를 **탐지**로 처리 | 패턴이 못 알아본 비밀에는 fail-closed를 걸 수 없다. 추출 화이트리스트로 구조화 |
| quality-gates 모듈 직접 import | 보안 장치가 남의 플러그인 설치 여부에 달리면 안 된다 |
| `test_mask_parity.py`를 quality-gates 부재 시 skip | 단독 배포 환경에서 영구히 안 돌아 drift를 못 잡는다. **fail로 바꿈** |
| 각 설명 끝에 `상세: /recap` 안내 | 매 순간 붙는 안내가 그 자체로 소음이 된다 |
| `force-for-plugin: false` (수동 선택) | 사용자가 기본 적용을 선택. 끄는 경로가 좁아지는 대가를 문서화 |
| output style만 별도 플러그인으로 분리 | 스타일만 끄는 길이 생기지만 plugin.json·README·버전이 2벌이 되고 둘이 따로 논다 |
| 지침을 XML 태그로 구조화 | 일반 프롬프트 가이드는 권하나, output style 공식 예시와 `Explanatory` 둘 다 마크다운 헤더를 쓴다 |

### AC 검사와 위의 「런타임 grep 금지 검사」는 무엇이 다른가

리뷰가 물은 지점이다. 셋이 다르다.

| | 기각한 것 | AC2–AC5 (채택) |
|---|---|---|
| 대상 | **모델이 런타임에 내는 출력** | **우리가 리포에 커밋한 지침 파일** |
| 시점 | 대화 중 | 테스트 실행 시 |
| 효과 | 조건 불충족 시 **막는다** | red를 낸다. 런타임에 아무 영향 없음 |

즉 채택한 것은 [§5.4](#54-집행-수준-oq1-결정)의 ③이고, 기각한 것은 ①이다. 같은 도구(문자열 검사)를
쓰지만 대상과 효과가 다르다.

## 12. 미해결

| # | 미해결 | 왜 지금 못 정하나 · 무엇으로 방어하나 |
|---|---|---|
| OQ-A | 트랜스크립트 형식이 **문서화돼 있지 않다**. 바뀌면 `/recap`이 깨진다 | 사전 감지 장치가 없다. AC10–AC12가 픽스처를 통과해도 실제 포맷 변경은 못 잡는다. 방어는 §7의 `RECAP-UNAVAILABLE`(조용한 실패 금지)뿐 |
| OQ-B | `force-for-plugin`이 다른 플러그인 스타일과 충돌하면 "먼저 로드된 것이 이긴다" | 플랫폼 규칙이라 개입 불가. README 경고만 |
| OQ-C | 도입부 두 문장이 과잉 발화를 실제로 막는지 | **AC29 게이트 1로 측정한다.** 못 막으면 문구를 강화하거나 순간 수를 줄인다 |
| OQ-D | `/recap`의 발견 가능성 — 각 설명 끝의 안내를 없앴다 | README와 명령 목록에서만 알게 된다. 실사용에서 안 쓰이면 재검토 |
| OQ-E | `Explanatory` 원문이 개선되면 사본이 낡는다 | 감지 장치가 없다. `Explanatory` 본문을 주기적으로 대조하는 것 외에 방법이 없다 |
| OQ-F | 약 500 토큰이 시스템 프롬프트 끝에 붙는 것이 내장 지침의 주의를 얼마나 가져가는지 | 외부에서 직접 계측 불가. AC21이 간접 신호만 준다 |
| OQ-G | 예산 32 KB의 근거는 **표본 1건**(이 작업, 사람 발화 28 KB)이다 | 표본이 늘면 재산정한다. 근거 문장이 남아 있으므로 반박 가능 |
| OQ-H | 이 브랜치가 생기기 **전에** 다른 브랜치에서 한 일은 범위에 안 들어온다 | 이 작업의 인터뷰가 그 경우다(`main`에서 진행). 4절이 브랜치의 커밋된 산출물을 나열하지만 그 안의 결정까지 복원하지는 않는다. `--since`·`--all` 로 사용자가 넓힐 수 있다 |
| OQ-I | 레코드 `type` 이름(`queue-operation`·`attachment`·`last-prompt`)은 **문서화되지 않은 관측값**이다 | 플랫폼이 이름을 바꾸면 AC12–AC15가 픽스처에서는 통과하고 실물에서는 조용히 0건이 된다. 헤더의 `included: events=N` 이 0이면 이상 신호로 읽을 수 있지만 자동 감지는 아니다 |
| **OQ-J** | **훅 + output style 경로에는 비밀 방어가 전혀 없다** — `SubagentStop` 훅이 매 에이전트 종료마다 "무엇을 찾았나 / 근거가 어디 있나"를 대화창에 내라고 지시하고, 그 내용은 파일 정본으로 남는다. `/recap`보다 훨씬 빈번하고 노출 위험도 크다 | 브리프 OQ8이 연 항목인데 앞선 판에서 조용히 빠졌다(리뷰 적발). **완화책이 없다** — 모델 출력에 필터를 거는 지점이 플랫폼에 없고, 프롬프트로 막으면 K1(억제)에 걸린다. **수용된 잔여 위험**으로 문서화하고 README에 적는다 |
| **OQ-K** | 탐지 기반 마스킹이 못 잡는 비밀(알려진 패턴 밖 + 엔트로피 임계 아래, 예: 짧은 비밀번호)은 `/recap` 출력에 통과한다 | 구조 방어(추출 화이트리스트)는 도구 입력·파일 내용만 덮고, 사용자가 직접 쓴 발화는 버릴 수 없다. AC21·AC22가 덮는 범위를 명시했고 그 밖은 **수용된 잔여 위험**이다 |
| **OQ-O** | 루브릭 C가 `/recap` **4절**(모델이 유일하게 직접 합성하는 절)과 3절(git)의 충실도를 **안 잰다** | 오류 위험이 가장 큰 곳이 4절인데 게이트 5의 네 문항 중 어느 것도 그 절을 겨냥하지 않는다. 4절은 근거가 1~3절에 있으므로 사람이 대조할 수 있다는 점에 기대는 **수용된 잔여 위험**이다(사용자 판단, 5라운드) |
| **OQ-P** | 판정 구간이 *"호출 직후 **첫** assistant 메시지"* 라, 짧은 전환 메시지 뒤에 설명이 오는 정상 응답을 **거짓 실패**시킬 수 있다 | 구간을 넓히면 무관한 텍스트가 섞여 판정이 흐려진다. 첫 측정에서 거짓 실패가 관측되면 구간 규칙을 고친다 — **수용된 잔여 위험**(사용자 판단, 5라운드) |
| **OQ-L** | 게이트 3·4·5의 루브릭 판정에 **모델이 들어온다** — 판정자도 틀릴 수 있다 | 두 리뷰어가 세 라운드에 걸쳐 지적한 "구문 검사가 내용을 못 본다"의 해법으로 채택. 3표 다수결이 흔들림을 줄이지만 없애지는 못한다. 루브릭이 본문에 있어 **재현·반박 가능**한 것이 개수 검사와의 차이다 |
| **OQ-M** | **브리프 OQ7 (재귀 경계)** — C16의 "모든 작업"이 subagent **내부** 순간까지 포함하는지 | **이번 범위에서는 포함하지 않는다.** output style이 subagent에 안 닿고(N4), 17개 agent 정의를 고치는 방식은 devbrew 밖에서 작동하지 않으며(K3 위반), 순간마다 발화가 배수로 늘어 K2(토큰)와 충돌한다. 다만 **이것은 플랫폼 제약에 따른 결정이지 사용자 판단이 아니다** — 브리프가 열어둔 질문이므로 여기 등재한다 |
| **OQ-N** | **브리프 OQ9 (진행 중·방향 전환 검출)** — "긴 작업이 도는 중" 순간 | **여섯 순간에 넣지 않았다.** 사용자가 S23에서 그 항목을 고르지 않았고, 에이전트 패널이 진행 상황을 이미 렌더한다(§1). 조용한 방향 전환은 어떤 훅 이벤트도 아니라 검출 경로가 없다 |

## 13. Metadata

| 항목 | 값 |
|---|---|
| 플러그인 | `plugins/agent-transparency/` (신규) |
| 버전 | `0.1.0` |
| 브랜치 | `feature/comprehension-debt-plugin` |
| 문제공간 입력 | `docs/superpowers/interview/2026-08-02-comprehension-debt-plugin-interview.md` |
| 의존 | 없음 (quality-gates는 테스트 시 대조 대상 — 리포 안에서는 항상 존재) |
| 신규 훅 | `SubagentStop` 1건 |
| kill switch | `DEVBREW_DISABLE_AGENT_TRANSPARENCY=1` · `DEVBREW_SKIP_HOOKS=agent-transparency:subagent-explain` — **훅에만 적용된다.** output style은 플러그인 비활성화로만 끈다 |
| 리포 루트 변경 | `docs/plugin-authoring.md`에 output style 컴포넌트 절 추가 |
| 머지 게이트 | AC29 — A/B 측정 **게이트 5개** (1·2는 구문 판정, 3·4·5는 루브릭 3표 다수결). 상세는 [§10-6](#10-검증-계획) |
