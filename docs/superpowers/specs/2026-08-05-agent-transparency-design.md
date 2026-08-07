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
  - [6.3 /standup — 명령 · skill · 준비 스크립트](#63-standup--명령--skill--준비-스크립트)
- [7. 에러 처리 · 강등](#7-에러-처리--강등)
- [8. 파일 목록](#8-파일-목록)
- [9. Acceptance Criteria](#9-acceptance-criteria)
- [10. 검증 계획](#10-검증-계획)
- [11. 기각된 대안](#11-기각된-대안)
- [12. 미해결](#12-미해결)
- [13. Metadata](#13-metadata)

## 0. Handoff Context

**TL;DR** — Claude Code용 새 플러그인 `agent-transparency`를 만든다. 부품은 셋이다: (1) 일곱 개의
의미 순간에 무엇을 설명해야 하는지 규정하는 **output style**(본체, 시스템 프롬프트에 붙는다),
(2) 에이전트 종료 직후 설명 자리를 만드는 **`SubagentStop` 훅**, (3) 대화에 쌓인 그 설명들과 git을
읽어 *"지금 어떤 상태인가"* 에 답하는 **`/standup`**. 상태 파일은 만들지 않는다.

**세 부품은 하나의 파이프라인이다.** 앞의 둘이 **기록을 만들고**(설명이 메인 트랜스크립트에 쌓인다),
`/standup`이 그것을 **다시 꺼낸다.** 이 관계가 이 설계의 중심이며, 여기서 두 가지가 따라 나온다 —
`/standup`은 서브에이전트 파일을 열 필요가 없고(훅이 이미 요지를 메인으로 끌어올렸다), 플러그인
설치 *이전* 작업에는 답할 재료가 거의 없다.

**Implicit context** — 구현자가 모르면 재도출해야 하는 것들:

- **`Explanatory` 스타일이 꺼진다.** output style은 한 번에 하나만 활성이고 이 플러그인은
  `force-for-plugin: true`로 자동 적용된다. 그래서 `Explanatory`의 `## Insights` 절을 **원문 구조
  그대로** 흡수해야 한다([§6.1](#61-output-style--이-플러그인의-본체)). 이건 취향이 아니라 회귀 방지다.
- **끄는 방법은 플러그인 전체 비활성화뿐이다.** devbrew의 kill switch 규약은 훅에만 걸 수 있고
  output style에는 못 건다. 사용자가 이 대가를 알고 선택했다.
- **트랜스크립트 형식은 문서화돼 있지 않다.** `/standup`이 읽는 `~/.claude/projects/*/<sid>.jsonl`의
  레코드 구조는 실측으로 확인한 것이며 플랫폼 보장이 아니다
  ([§6.3](#63-standup--명령--skill--준비-스크립트)).
- **`/why`는 설계에서 제거됐다.** 초안에 있었고 사용자가 뺐다.
- **비밀 마스킹은 제거됐다** — 2026-08-06 재설계. 앞선 판은 추출 화이트리스트 + 패턴/엔트로피
  마스킹을 3층으로 쌓았는데, 재료가 *"이미 메인 트랜스크립트에 있는 것"* 으로 바뀌면서 그 방어가
  막는 것이 거의 없어졌다(근거는 [§3](#3-불변식)). 되살리려면 그 절의 계산을 먼저 반박해야 한다.
- **브리프의 C18(`project-init`의 확장) 번복.** 브리프에서 `confirmed`였으나, 수단이 output style로
  정해진 뒤 사용자가 **독립 신규 플러그인**으로 다시 정했다. 조용한 변경이 아니라 명시적 재결정이다.

**Deferred to plan** — 이 문서가 정하지 않고 구현 계획에 넘기는 것. **인수 조건에 영향을 주는
것은 여기 없다**:

- `prepare_standup.py`의 내부 함수 분해와 파일 배치
- `docs/plugin-authoring.md`에 추가할 output style 절의 문장 단위 내용

앞선 판에서 여기 있다가 **본문으로 옮겨 확정된 것**(리뷰 지적): A/B 측정의 작업 프롬프트 · 픽스처
정책 · **실행 러너 전체**가 [§10-6](#10-검증-계획)에 고정됐고, 테스트는 합성 픽스처만 쓴다
([§10-4](#10-검증-계획)).

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
- **G3** — 사용자가 물었을 때, **지금 이 작업이 어떤 상태인지**를 돌려준다 — 코드가 무엇이 됐고,
  무엇이 열려 있고, 왜 그렇게 됐는지. 성공은 *전부 읽는 것*이 아니라 **얼마를 읽었는지 숨기지
  않는 것**이다([§4](#4-제약)의 K6 분할).
- **G4** — 이 프로젝트에서만 통하는 말, 그리고 **문서·대화의 번호로 가리키는 것**이 설명 없이
  나가지 않게 한다.
- **G5** — 내장 `Explanatory` 스타일이 하던 일을 **전부** 계속 한다. 대체하는 이상 못해지면 안 된다.
- **G6** — **사용자가 내리지 않았지만 사용자를 구속하는 결정**이 그 자리에서 드러나고, 되돌리는
  방법이 함께 나오게 한다.

각 Goal이 어느 인수 조건으로 확인되는지 (리뷰 지적 — 목표가 검증에 안 묶여 있었다):

| Goal | 확인하는 AC |
|---|---|
| G1 (결정 순간에 재료가 있다) | **AC29 게이트 4** (런타임) + AC3 (지침에 그 순간이 있다) |
| G2 (에이전트가 한 일이 표면에 나온다) | **AC29 게이트 3** (런타임) + AC7 (훅이 자리를 만든다) + AC36·AC37 |
| G3 (물으면 지금 상태를 돌려준다) | AC10·AC11·AC16·AC20·AC34·AC35 + **AC29 게이트 5** (`/standup` 답변, 런타임) |
| G4 (조어·포인터가 설명 없이 안 나간다) | AC4 (output style) + **AC28** (`/standup` 쪽에도 같은 다섯 규칙) |
| G5 (`Explanatory` 회귀 없음) | AC2 (4요소 각각 + mutation) |
| **G6** (묻지 않고 정한 것이 드러난다) | **AC38** (지침에 두 갈래가 있다) + **AC29 게이트 6** (런타임, 루브릭 D) |

### Non-goals

- **N1** — 설명의 **총량**을 늘리는 것. 성공은 길이가 아니라 *빠짐없음 + 형식*으로 달성한다.
- **N2** — 작업을 늦추거나 막는 것. → [불변식](#3-불변식)
- **N3** — 새 기록 장치(원장·로그·상태 파일)를 만드는 것. 트랜스크립트가 이미 그 역할을 한다.
  다만 2026-08-06 재설계로 **무엇이 거기 적히는지는 이 플러그인이 통제하게 됐다** — 훅과 output
  style이 설명을 쌓고 `/standup`이 그것을 읽는다. 파일을 새로 만들지 않는다는 뜻이지, 트랜스크립트를
  쓰지 않는다는 뜻이 아니다.
- **N4** — subagent 내부에 지침을 심는 것. subagent는 자기 시스템 프롬프트를 따로 가지므로
  닿지 않으며, 리포 안 17개 agent 정의를 고치는 방식은 devbrew 밖에서 작동하지 않는다.
- **N5** — 프로젝트 고유 용어의 **사용 금지**. 금지하면 이 리포에서는 말을 할 수 없다
  (`qg`·`floor`·`steelman` 등은 실재하는 물건의 이름이라 대체어가 없다). **번호·기호 포인터도
  마찬가지로 금지가 아니다** — 긴 문서에서 절 번호를 못 쓰면 문서가 성립하지 않는다. 둘 다
  금지가 아니라 상환 의무다.
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

### 비밀 — 방어는 한 층뿐이고, 그 사실을 숨기지 않는다

> **모델 출력에 필터를 걸 지점이 플랫폼에 없다.** 훅 경로와 `/standup` 경로는 **같은 등급**이며,
> 이것은 수용된 잔여 위험이다([§12 OQ-J](#12-미해결)).

2026-08-06 재설계 이전에는 여기에 3층 방어(추출 화이트리스트 → 패턴·엔트로피 마스킹 → 방어 없음)가
있었다. 재료가 *"이미 메인 트랜스크립트에 있는 것"* 으로 확정되면서 그 방어가 실제로 막는 것을
다시 계산했고, 결과가 이렇다:

| 위협 | 입력 마스킹이 막나 | 실제 |
|---|---|---|
| 비밀이 API로 전송됨 | ❌ | 메인 세션이 그 도구 결과를 받은 순간 **이미 전송됐다** |
| 비밀이 디스크에 남음 | ❌ | `/standup`이 읽는 그 `.jsonl`이 **곧 저장소다** |
| fork가 본 것이 유출됨 | ❌ | fork 컨텍스트는 버려진다. 메인으로 오는 것은 **답변뿐** |
| 답변에 비밀이 실려 메인에 잔류 | 부분적 | **모델이 옮겨 적어야만** 발생 |
| 사람이 답변을 PR·이슈에 붙여넣음 | 부분적 | 위와 같은 조건 |
| **fork 자신이 새 트랜스크립트를 만든다** | **막았을 것** | **2026-08-07 리뷰가 적발 — 아래 참조** |

**여섯 번째 행이 앞의 다섯과 다르다.** `/standup`의 fork는 서브에이전트이므로 실행되면
`<sid>/subagents/agent-*.jsonl` 이 **새로 생기고**, 거기에 그 fork가 읽은 원문이 남는다. 앞 다섯
행의 *"이미 디스크에 있다 / 이미 전송됐다"* 논거는 **새로 생기는 파일에는 적용되지 않는다.**
게다가 그 경로는 이 설계가 스스로 *"읽지 않는다"* 고 지정한 바로 그 자리다 — 안 읽겠다고 선언한
곳에 자기가 사본을 쓴다.

수용하는 근거는 셋이고, 그 셋이 **완화가 아니라 한정**이라는 점을 분명히 한다: (i) 사본은 같은
프로젝트 디렉토리 안, 같은 신뢰 경계에 생긴다 (ii) `/standup`의 범위 규칙이 서브에이전트 파일을
읽지 않으므로 다음 호출에 다시 실리지는 않는다 (iii) 사본을 안 만들려면 fork를 포기해야 하는데,
그러면 발췌가 메인 컨텍스트에 쌓여 이 플러그인이 막으려는 병을 유발한다. **그래도 호출마다 노출
표면이 늘어나는 것은 사실이며** 이것은 [§12](#12-미해결)의 OQ-U로 등재한다.

나머지 다섯 행의 실효는 마지막 두 줄뿐이고 둘 다 *"모델이 출력에 옮겨 적는 경우"* 에만 발동한다 — 즉 **확률적 완화이지
구조적 보장이 아니다.** 앞선 판은 그것을 「구조 (강함)」이라고 라벨링했고, 그 과장된 라벨이 라운드마다
방어를 강화시켰다.

결정적으로, **같은 종류의 내용이 이미 훅 경로로 필터 없이 나가고 있다** — `SubagentStop` 훅은
에이전트가 끝날 때마다 *"무엇을 찾았나 / 근거가 어디 있나"* 를 대화창에 쓰라고 지시하고, 그 출력은
메인 트랜스크립트에 영구히 남는다. 한 플러그인 안에서 두 경로의 방어 수준이 다를 근거가 없다.

devbrew 규약 P21(*"Secret 기록 금지"*)은 **플러그인 state 파일**에 대한 규칙이고, 이 플러그인은
state를 만들지 않으므로 여기 걸리지 않는다.

되살리려면 위 표를 먼저 반박해야 한다.

## 4. 제약

| # | 제약 | 출처 |
|---|---|---|
| K1 | 억제 금지 — 모델 능력을 깎는 어떤 장치도 안 된다 | 사용자 |
| K2 | 토큰 비용이 설계 제약이다. 빠짐없음을 포기하지 말고 **압축**으로 달성한다 | 사용자 |
| K3 | 적용 범위는 이 리포의 모든 작업. 특정 플러그인 안이 아니다 | 사용자 |
| K4 | 표준 용어를 쓰고, 이 프로젝트에서만 통하는 말은 지양하며, 비유를 쓰지 않는다 | 사용자 원 요청 |
| K5 | 설명 시점은 수행 전 · 수행 뒤 · 혹은 중간 | 사용자 원 요청 |
| K6 | 성공 기준은 "빠짐없음"이며 "빠른 파악"으로 **교체**하지 않는다. **적용 대상은 설명 순간이다** — `/standup`은 이 기준의 대상이 아니다(아래 분할) | 사용자 · 2026-08-07 분할 |
| K7 | 빠짐없음에는 **확신 못 하는 지점 · 근거가 약한 곳 · 불일치**가 1급 항목으로 포함된다. 불일치에는 자료 간 불일치와 **리뷰어 간 판정 충돌**이 함께 들어간다 | 브리프 C22 |
| K8 | 모든 훅에 kill switch 2종 | devbrew 규약 |
| K9 | 모든 skill에 `cost_class` 선언 | devbrew 규약 |

K4는 **자기 자신에게도 적용된다** — 이 플러그인의 이름·설명·본문이 자기 규칙을 통과해야 한다.

### K6의 적용 범위 분할 (2026-08-07 — 리뷰가 적발한 충돌)

codex가 잡은 모순: 문서는 성공 기준을 *"빠짐없음"* 으로 못박아 두고, 정작 `/standup`은 에이전트가
**임의의 부분집합만 읽고** 그 사실을 밝히면 충분하다고 했다. 둘이 같은 기준일 수 없다. 사용자
결정(2026-08-07)으로 **순간별로 나눈다**:

| 대상 | 기준 | 왜 그 기준인가 |
|---|---|---|
| **설명 순간 일곱 개** | **빠짐없음** — 각 순간의 필수 항목이 [§6.1](#61-output-style--이-플러그인의-본체) 표에 열거돼 있다 | 담을 것이 유한하고 열거돼 있어 **측정 가능**하다. 루브릭 A·B·D가 문항별로 그 항목을 확인한다 |
| **`/standup`** | **투명한 표본** — 전부 읽는 것이 목표가 아니라, **얼마를 읽었는지 숨기지 않는 것**이 목표 | 브랜치 재료가 220~904 KB라 전수 읽기는 호출당 고정 비용이 되고 K2(토큰 비용)와 충돌한다. 루브릭 C의 Q2가 총수 대비 읽은 수를 강제한다 |

**K7(확신 못 하는 지점·근거가 약한 곳·불일치가 1급 항목)은 분할 대상이 아니다** — 양쪽 모두에 적용된다.

## 5. 아키텍처

### 5.1 부품 3개

| # | 부품 | 하는 일 | 상태 | 비중 |
|---|---|---|---|---|
| 1 | **output style** | 일곱 순간에 무엇을 담아야 하는지 규정 + `Explanatory` 흡수 | 없음 | **본체** |
| 2 | **`SubagentStop` 훅** | 에이전트가 끝난 직후 설명 자리를 만든다 | 없음 | 백스톱 1건 |
| 3 | **`/standup`** | 명령 → fork skill → 준비 스크립트. 쌓인 설명 + git으로 *"지금 상태"* 를 낸다 | 없음 | 조회 |

**상태 파일이 하나도 없다.** 훅은 상수를 출력하고, 준비 스크립트는 읽기만 한다.

**부품 3은 부품 1·2의 산출물을 먹는다.** 앞의 둘이 매 순간 설명을 대화창에 쓰고, 그 설명은 메인
트랜스크립트에 영구히 남는다. `/standup`이 읽는 주재료가 바로 그것이다. 이 의존이 두 가지를 결정한다:

- **서브에이전트 파일을 열 필요가 없다** — 훅이 이미 그 요지를 메인으로 끌어올렸다.
- **소급이 안 된다** — 플러그인 설치 *이전* 세션에는 설명 블록이 없다. 그 구간에 대해 `/standup`은
  git과 결정 원장만 낸다. 별도 판별 장치를 두지 않으며, 인벤토리가 설명 블록 총수를 주므로
  *"이 범위엔 설명이 N건뿐"* 으로 저절로 드러난다.

### 5.2 데이터 흐름

```
[쓰는 쪽 — 자동, 매 턴]

   output style ──(시스템 프롬프트)──▶ 모델 ──┐
                                              ├──▶ 대화창의 설명 블록
   SubagentStop 훅 ──(additionalContext)──────┘         │
        "방금 끝난 <agent_type> 에 대해 내라 —           │  그대로 메인 .jsonl 에 쌓인다
         누가 / 무엇을 찾았나 / 근거 위치 / 판단 변화"   ▼
                                              ~/.claude/projects/<슬러그>*/<sid>.jsonl


[읽는 쪽 — 사용자가 /standup 칠 때만]

   /standup ──▶ skill (context: fork, agent: Explore)
                   │
                   │  프론트매터가 로드되기 전에 !`…` 가 먼저 실행됨
                   ▼
                prepare_standup.py ──▶ 인벤토리 한 줄 + git 상태
                   │        (범위 결정 · 총량 계수 · git log/diff --stat. 본문은 안 담는다)
                   ▼
                fork 안의 에이전트가 인벤토리를 보고 **필요한 만큼 직접 읽는다**
                   │
                   ▼
                고정 3절 ──▶ 메인 대화에 답변만
```

발췌는 **fork 안에서 소모되고 메인 대화에는 답변만** 들어온다. 이것이 K2를 지키는 방식이다 —
메인 컨텍스트가 발췌만큼 밀리지 않으므로 `/compact`가 앞당겨지지 않는다.

**왜 주입이 아니라 탐색인가** (2026-08-06 재설계, 실측 근거):

| 재본 것 | 값 |
|---|---|
| 한 세션의 어시스턴트 텍스트 블록 (**세션 단독** 범위) | **187개 / 228.7 KB** (중앙값 212 B, 최대 7.9 KB) |
| 기계적 앵커 세 종(에이전트 결과 직후 · 결정 요청 직전 · 턴 마지막)의 합집합 | 189.2 KB = 전체의 **82.7%** |
| 크기 임계(≥ 2,000 B)로 고른 것 | 185.1 KB = **80.9%** |
| 전형적 브랜치 하나의 총량 | **220~560 KB** (`main`은 904 KB) |

> **숫자 두 벌이 나오는 이유** (리뷰가 혼동을 지적): 이 표의 187개/228.7 KB는 **세션 단독**
> 범위이고, [§6.3](#63-standup--명령--skill--준비-스크립트)의 192개/239.2 KB는 **브랜치 ∪ 세션**
> 합집합이다. 같은 날 같은 데이터를 두 범위 규칙으로 잰 것이며 둘 다 맞다. 선별 비율(82.7% 등)은
> 세션 단독 기준으로 계산했다.

바이트가 소수의 큰 블록에 몰려 있고 **그 큰 블록이 곧 설명 블록**이라, 어떤 선별 규칙을 써도 80%대가
잡힌다 — 즉 **선별이 필터로 기능하지 못한다.** 그리고 브랜치 범위의 재료는 주입으로 감당할 수 없는
크기다. 탐색이 아니면 범위를 세션으로 줄여야 하고, 그러면 *"이 작업"* 이 아니라 *"이 세션"* 만
답하게 된다.

대가는 **에이전트가 자기가 안 본 것을 모른다**는 것이다. 그래서 인벤토리(총 블록 수 · 바이트 · 기간 ·
결정 수)는 계속 기계가 찍어 주입한다 — 답변이 *"187개 중 20개를 읽었다"* 를 말할 수 있어야
[§7](#7-에러-처리--강등)의 *"못 읽은 것은 없는 것이 아니다"* 가 성립한다.

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
| 같은 곳 | *짧게 시작하라. 길수록 좋은 게 아니다* | 약 550 단어 (일곱 번째 순간 + 포인터 규칙 추가 후) |
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
| **When you settled something without asking the user** | what you decided / **why you did not ask** — the evidence left one option, a measurement ruled the others out, or an earlier instruction from the user ruled them out / **what the user would say to reverse it** |
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
missing or failed and you proceeded another way. *You settled something without asking*
when the choice you closed alone is one the user might have answered differently had they
known it was being closed — direction, scope, what gets built, or a trade-off they are the
one paying for. Formatting, naming, and the order of independent steps are not that. The
test is not whether the answer felt obvious to you; it is whether the user would recognise
the question as theirs.

Example, just before asking the user to decide:

"**What I'm asking** — where cache expiry should be handled.
**Why these options** — expiry is checked only on the read path today, so the write path
cannot catch stale entries.
**What I discarded** — a background job: this repo has no scheduler, so it would need new
infrastructure.
**Recommendation** — ②, because it attaches to existing middleware and adds no new moving parts."

## Format

**When you explain at the moments above**, use a fixed order and bold labels, so the user
can find one item without reading the whole block. Structure does this, not brevity — a
shorter explanation that drops an item is worse, not better.

Use a table when the report has more than one item to find. A moment whose whole report is
a single item — a one-line change, one file, one next step — is already in a findable order
as a sentence; a table around one row costs the reader more than it saves. Elsewhere, write
however the content wants to be written.

## Vocabulary

Terms that mean something only inside this project — tool names, abbreviations, internal
concepts — get one clause of explanation the first time they appear. Use them freely; just
pay for them on the spot. Prefer a standard term when one exists; otherwise say plainly
what the thing does. Do not assume the user knows a word because you know it — that is not
a judgment you are in a position to make.

The same payment is due when you point with a number or a symbol: a section number, an item
number, an acceptance-criterion id, or a label you coined earlier in this conversation. Say
in one clause what you are pointing at. The user is not holding that document open, and a
label you invented three messages ago is not shared vocabulary just because you have been
using it.

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

#### 일곱 순간의 출처

| 순간 | 브리프 근거 |
|---|---|
| 결정을 요청하기 직전 | C3 (사용자가 "확실하다"고 명시한 유일한 지점) |
| **묻지 않고 정했을 때** | **사용자 2026-08-06 재결정** — *"결정사항이 있는 경우 … 이해 부채를 만드는 지점임"*. 첫 줄을 넓혀 두 갈래로 두는 안은 기각됐다([§11](#11-기각된-대안)) — 안 묻는 갈래는 정의상 스스로 드러나지 않으므로 제목이 "요청"인 줄 밑에 두면 묻힌다 |
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
`/standup`도 함께 꺼진다.** devbrew 규약의 kill switch(K8)는 훅에만 걸 수 있다 — 플랫폼이 플러그인
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

#### 왜 규칙이 단어에서 **포인터**로 넓어졌나

2026-08-06 이 설계 대화에서 사용자가 *"이해가 안 가네 … 이런 게 이해부채 예시겠어"* 라고 지적한
지점이 근거다. 모델이 *"1번 순간"*, *"7번째 순간"* 이라고 썼는데 그 번호는 1,100줄짜리 문서와
대화 위쪽에만 있었다.

돌아보니 같은 대화에서 모델이 만들어 쓴 라벨이 이만큼이었다 — `D1~D5` · `U1~U6` · `B1~B3` ·
`C1~C2` · `E1~E3` · `§3` · `§6.3` · `AC21` · `AC30` · `OQ-J` · `K1` · `N1`. **어느 것도 설명한 적이
없다.** 정리하려고 붙인 번호가 어느새 공용어인 척했다.

포인터가 조어보다 나쁜 이유는 **신호가 없다**는 것이다. 조어는 최소한 *"사전에 없는 말"* 이라는
표시라도 주지만, 번호는 그 표시조차 없이 *"당신도 이 문서를 펴 놓고 있다"* 를 가정한다. 이것은
[§1](#1-context--why)이 진단한 *"설명했다고 착각하는 것"* 의 더 순수한 형태다.

금지가 아니라 상환으로 둔 이유는 조어와 같다 — 긴 문서에서 번호를 못 쓰면 문서가 성립하지 않는다.

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

#### 페이로드 — 실측 (2026-08-06, Claude Code 2.1.223)

임시 플러그인에 `SubagentStop` 훅을 걸고 실제로 받은 stdin의 키 전량:

```
agent_id · agent_type · agent_transcript_path · last_assistant_message ·
effort · background_tasks · session_crons · stop_hook_active ·
permission_mode · prompt_id · session_id · transcript_path · cwd · hook_event_name
```

| 키 | 쓰나 | 이유 |
|---|---|---|
| **`agent_type`** | **쓴다** | 어느 에이전트가 끝났는지가 문구에 들어간다. 추가 토큰 ≈ 0 |
| **`agent_type == "workflow-subagent"`** | **쓴다** | 아래 분기의 근거. 실측으로 일반 에이전트(`Explore` 등)와 구분됨 |
| `last_assistant_message` (에이전트 최종 메시지 전문) | **안 쓴다** | 같은 내용이 메인 트랜스크립트에 이미 있어, 넣으면 컨텍스트에 두 번 들어간다 (K2 = 토큰 비용 제약) |
| `agent_transcript_path` | 안 쓴다 | 서브에이전트 파일을 읽지 않기로 확정 |
| `stop_hook_active` | 안 쓴다 | Stop 루프 가드용. 이 훅은 `decision`을 안 내므로 무관 |
| 나머지 | 안 쓴다 | — |

#### `hooks/subagent-explain.py`가 하는 일 전부

1. kill switch 확인 — `DEVBREW_DISABLE_AGENT_TRANSPARENCY=1` 또는
   `DEVBREW_SKIP_HOOKS`에 `agent-transparency:subagent-explain` 포함 → **stdout 없이 exit 0**
2. stdin에서 `agent_type` 하나만 읽는다 (없거나 파싱 실패면 `"에이전트"`)
3. `agent_type`에 따라 **두 상수 중 하나**를 골라 JSON 출력 (dual-target — devbrew 규약)

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SubagentStop",
    "additionalContext": "Report on the `<agent_type>` agent that just finished: who ran / what they found / where the evidence is / how it changed your judgment. Do not restate their output; write its effect on your judgment. Answer in the language the user is writing in."
  },
  "systemMessage": "[agent-transparency] 에이전트 결과 설명 자리"
}
```

`agent_type == "workflow-subagent"` 이면 `additionalContext` 끝에 한 문장이 더 붙는다:

> `This is one piece of a workflow — if other agents from the same workflow finished alongside it, report them together as one.`

**문구가 영어인 이유는 N6(응답 언어를 바꾸지 않는다) 보호다** (codex가 적발). 한국어 지시문이
영어 세션에 주입되면 모델이 한국어로 답할 수 있고, 그것은 이 플러그인이 하지 않겠다고 선언한 일이다.
output style 본문이 영어인 것과 같은 이유이며, 마지막 문장이 언어를 사용자에게 되돌린다.

#### 왜 그 분기가 필요한가 — 실측

| 경로 | `SubagentStop` 발화 | `agent_type` | 동시성 |
|---|---|---|---|
| `Agent` 도구 (일반 subagent) | ✅ | `Explore` 등 실제 타입명 | **0/777 병렬** — 이 리포 전체에서 한 어시스턴트 메시지에 `Agent` 호출이 2개 이상인 적이 **없다** |
| **`Workflow`** | **✅** | **`workflow-subagent`** | 3 에이전트가 **1.3초 안에** 종료 — 진짜 동시 |

워크플로는 동시 최대 16, 총 1,000 에이전트까지 가므로 한 턴에 수십 건 주입이 가능하다. 묶기 문장이
**억제가 아닌 이유**: 설명을 *줄이라*는 것이 아니라 **보고 단위**를 알려 주는 것이다. 워크플로에서
의미 있는 단위는 에이전트 하나가 아니라 워크플로 전체이고, 그건 사실 서술이지 제한이 아니다
(K1 = 억제 금지).

#### 불변식 — 정확히

> 훅은 **에이전트의 출력 내용을 검사하지 않고**, 차단하지 않으며, 파일을 쓰지 않는다.
> `agent_type` 라벨에 따라 두 상수 중 하나를 고르는 것은 내용 검사가 아니다.

앞선 판은 *"조건을 따지지 않는다"* 라고 썼는데 `agent_type` 분기는 조건이다. 조용히 어기지 않고
문구를 고쳤다. 트랜스크립트는 읽지 않고, stdin은 읽고 버린다(파이프 깨짐 방지). `decision` 키를
절대 내지 않는다([§3](#3-불변식)).

### 6.3 `/standup` — 명령 · skill · 준비 스크립트

#### 무엇에 답하나

***"지금 이 작업이 어떤 상태인가."*** 코드가 무엇이 됐고, 무엇이 열려 있고, 왜 그렇게 됐는지.
디스크 파일을 읽으므로 `/compact`로 대화에서 사라진 뒤에도 닿는다.

**이것이 "요약"이 아니라는 점이 설계의 중심이다.** 앞선 판은 사용자 발화·결정·되돌림을 되짚어
주는 것이었는데, 그 재료는 **사용자 본인이 쓴 것**이라 이해부채가 0이다. 부채가 0인 자료를 읽고
부채가 최대인 자료(사용자가 원리적으로 못 본 것)를 버리고 있었다. 재료를 뒤집었다.

| 자료 | 사용자의 이해부채 | 이번 판 |
|---|---|---|
| 사용자 본인의 발화 | **0** (본인이 씀) | 주재료 아님 |
| `AskUserQuestion`으로 고른 라벨 | **0** (본인이 고름) | 작은 부분으로 유지 (문구 보존 가치는 남음) |
| **어시스턴트 설명 블록** (훅·output style이 만든 것) | **큼** — 그때 안 읽었으면 사라짐 | **주재료** |
| **git `main..HEAD`** | 큼 — 사용자가 실제로 물려받는 것 | **주재료** |
| 서브에이전트 내부 대화 | 최대 | 안 읽음 (훅이 요지를 메인으로 올림) |

#### 이름 — 왜 `/recap`이 아닌가 (실측)

내장 `/recap`이 **이미 존재한다.** Claude Code 2.1.223 바이너리에서 확인한 정의와 프롬프트 전문:

```
{ type:"local", name:"recap", description:"Generate a one-line session recap now" }

"The user stepped away and is coming back. Recap in under 40 words, 1-2 plain sentences,
 no markdown. Lead with the overall goal and current task, then the one next action.
 Skip root-cause narrative, fix internals, secondary to-dos, and em-dash tangents."
```

내부 이름은 `awaySummary`이고, **메모리에 있는 메시지**로 1턴 fork를 돌린다(`skipTranscript: true`).
기능은 안 겹치지만 **이름이 겹치고, 실패 양식이 나쁘다** — bare `/recap`을 치면 내장이 응답하므로
사용자는 오류가 아니라 *그럴듯한 다른 답*을 받는다.

실물 probe로 확인한 이름 상태:

| 상태 | 이름 |
|---|---|
| 활성 예약어 (쓰면 안 됨) | `recap` · `stats` · `context` |
| 게이트된 예약어 (현재 비활성이나 이름이 잡혀 있음) | `brief` |
| 비어 있음 (`Unknown command` 응답) | **`standup`** · `surface` · `readout` · `trail` · `handoff` · `briefing` · `journal` · `ledger` |

`/standup`을 쓴다. 데일리 스탠드업의 세 질문(한 것 / 할 것 / 막힌 것)이 아래 3절과 거의 1:1로
대응한다.

#### 작업의 경계 — 세션이 아니다

세션은 사용자의 관심 단위가 아니다. 사용자가 알고 싶은 것은 *"이 작업"*이고, 하나의 작업은 여러
세션에 걸친다. 실측으로 확인한 반례: 이 설계 작업의 세션 하나가 **프로젝트 디렉토리 두 곳**에
걸쳐 있고(메인 리포 → 워크트리 이동), 그 과정에서 `gitBranch`가 `main`에서
`worktree-feature+comprehension-debt-plugin`으로 바뀌었다.

**범위 규칙: 현재 브랜치의 모든 세션 ∪ 현재 세션 id.** 합집합인 이유는 둘 다 단독으로는 새기
때문이다 — 브랜치만 보면 워크트리 이동 전 기록이 빠지고, 세션만 보면 어제 한 것이 빠진다.

실측 비교 — **이 작업 기준으로는 브랜치 갈래가 0을 더한다**(2026-08-06, 새 재료 기준):

| 규칙 | 세션 파일 | 설명 블록 | 바이트 | 결정 |
|---|---|---|---|---|
| 현재 세션 id | 1 | 190 | 239.1 KB | 38 |
| 현재 브랜치 | 2 | 112 | 165.4 KB | 30 |
| **합집합 (채택)** | 2 | 192 | 239.2 KB | 38 |

**그런데 이 표만으로 브랜치 갈래를 기각하면 안 된다** — 이 작업이 예외적으로 짧다. 같은 리포의
다른 브랜치를 재보면:

| 브랜치 | 세션 수 | 어시스턴트 텍스트 |
|---|---|---|
| `main` | **69** | 904.4 KB |
| `worktree-qg-container-runtime` | 57 | 414.5 KB |
| `feature/spec-distill-brief-review-pipeline` | 45 | 243.7 KB |
| `feature/plugin-audit-plugin` | 41 | 223.6 KB |
| `feature/project-init-audit` | 36 | 562.5 KB |

전형적인 **feature/fix 브랜치**는 **35~57 세션**이다(`main`의 69는 여러 작업이 합류하는 trunk라
이 범위 밖이며, 그래서 `main`에서 `/standup`을 부르면 답이 넓어진다 — 그건 사용자가 `--branch`나
`--since`로 좁혀야 하는 경우다). 어느 쪽이든 브랜치 갈래 없이는 그 작업의 대부분이 범위 밖이 된다.
표본 하나로 기각할 뻔한 지점이라 두 표를 함께 남긴다.

**상한을 두지 않는다.** 탐색 방식이라 범위가 넓어져도 비용이 비례해 늘지 않는다 — 인벤토리만
커지고(472개 세션 파일 전량 스캔이 **1.5초**) 실제로 얼마나 읽을지는 에이전트가 정한다. 여기에
예산 캡을 걸면 K1(억제 금지)에 걸린다.

탈출구: `--branch <이름>` · `--since <날짜>` · `--all`.

**알려진 갭**: 이 브랜치가 생기기 *전에* 다른 브랜치에서 한 일은 안 잡힌다. 이 작업의 인터뷰가
그 경우다(`main`에서 진행). 완화책은 1절(지금 상태)이 git으로 브랜치의 커밋된 산출물을
나열하는 것뿐이며, 그 안의 결정까지 복원하지는 않는다([§12 OQ-H](#12-미해결)).

#### 읽는 비용과 넣는 비용은 다르다

| | 비용 |
|---|---|
| 이 리포의 세션 파일 **472개 전량 스트리밍 스캔** | **1.5초** (실측 2026-08-06) |
| 모델 컨텍스트에 넣기 | 토큰 — 여기가 비싼 쪽 |

읽기가 싸므로 인덱스도 캐시도 상태 파일도 만들지 않는다. 그리고 **읽는 양에도 상한을 걸지 않는다** —
무엇을 얼마나 읽을지는 fork 안의 에이전트가 인벤토리를 보고 정한다(K1 = 억제 금지).

#### 재료 — 무엇을 읽고 무엇을 안 읽나

**읽는 것** (전부 메인 세션 `.jsonl` + git):

| 재료 | 어디서 | 누가 뽑나 |
|---|---|---|
| 어시스턴트 텍스트 블록 | 메인 `.jsonl` | 에이전트가 탐색 |
| 결정 원장 — `AskUserQuestion` 질문 + 고른 라벨 | 메인 `.jsonl`의 도구 호출 ↔ `tool_result` 짝 | 에이전트가 탐색 (문구 보존) |
| 코드 상태 | `git log --oneline` · `git diff --stat` (실행 시점 조회) | **기계**가 주입 |
| 인벤토리 (총량) | 위 파일들의 계수 | **기계**가 주입 |

**안 읽는 것** — 구조가 아니라 `SKILL.md`의 **지시**로 막는다:

`Bash` 명령 문자열 · 파일 내용 · `tool_result` 본문 · 에이전트 반환값 본문 · 서브에이전트
트랜스크립트(`<sid>/subagents/*.jsonl`).

앞선 판은 이것을 추출 스크립트가 **구조적으로** 배제했다. 이번 판은 에이전트가 원본 `.jsonl`을 직접
읽으므로 그 보장이 없다 — 플러그인 `settings.json`은 `agent`와 `subagentStatusLine` 키만 지원해서
`permissions.deny`로 경로를 막을 수단이 없다. **지시 준수 수준으로 내려간 것을 인정하고 적는다**
(어차피 훅 경로는 처음부터 같은 등급이었다 — [§3](#3-불변식)).

#### 에이전트에게 넘겨야 할 트랜스크립트 지식 (실측)

추출 코드가 사라지면서 이 지식이 `SKILL.md`의 지시로 옮겨간다. **코드에서 지시로 옮겼을 뿐 잃지
않는다는 것이 요점**이고, 셋 다 순진한 구현이 조용히 틀리는 지점이다.

| # | 사실 | 순진하게 하면 |
|---|---|---|
| 1 | 사람 발화는 **세 레코드 타입에 나뉘어** 있다 — `type=="user"`(+ `userType=="external"` · `isMeta!=true` · `content`가 문자열) · `type=="queue-operation"` · `type=="attachment"`의 `attachment.type=="queued_command"` | `user`만 보면 이 작업에서 34건 중 **16건**만 잡힌다. 빠지는 18건이 대부분 **턴 도중의 교정 발화**(*"이게 아니야"*, *"방향이 아직 다 닫히지 않았어"*) — 가장 보여줘야 할 것만 골라서 버린다. 16건이 잡히므로 **정상 동작처럼 보인다** |
| 2 | `type=="last-prompt"` 는 같은 텍스트를 반복 기록한다 (한 세션에 157건) | 세면 중복이 부풀려진다 |
| 3 | 어시스턴트 레코드는 `text`·`thinking`·`tool_use` 중 **하나만** 담는 경우가 많다 (한 세션: `tool_use` 356 · `thinking` 258 · `text` 187) | *"다음 어시스턴트 메시지"* 를 찾으면 **3분의 2 확률로 텍스트 없는 레코드**에 착지한다. 이 함정을 밟은 채로 재면 *"에이전트 반환 11곳 중 설명이 붙은 것 1곳(9%)"* 이 나오고, 건너뛰고 다시 재면 **4곳(36%)** 이다 |

세 곳을 모은 뒤 **본문 기준으로 중복을 제거**하고, 아래로 시작하는 것은 사람 발화가 아니므로 버린다:

```
"<task-notification>" · "<system-reminder>" · "<local-command" ·
"[Request interrupted" · "Caveat:"
```

#### 훅이 없으면 재료도 없다 (실측)

같은 데이터로 잰 것 — 이 설계 대화에서 에이전트가 돌아온 **11곳 중 그 직후에 설명(≥200 B)이 붙은
곳은 4곳(36%)** 이다. 나머지 7곳은 아무 말 없이 다음 도구 호출로 넘어갔다. 이 숫자가 두 방향으로
읽힌다:

- **`SubagentStop` 훅의 존재 이유** — 훅이 겨냥한 실패가 이 대화 안에 7건 있다.
- **`/standup` 재료의 하한** — 훅이 켜지면 그 7곳이 설명으로 채워지므로 실측 228.7 KB는
  **하한이지 상한이 아니다.**

#### 이것은 요약이 아니라 지도다

사용자는 기록을 **다 읽을 수 있다.** `/standup`이 하는 일은 대신 읽어 주는 것이 아니라 **읽기를
돕는 것**이다. 이 구분이 출력 형태를 결정한다:

- 모든 항목에 **시각**이 붙는다 — 사용자가 원문의 그 지점으로 갈 수 있어야 한다
- **얼마나 읽었는지가 답변에 나온다** — 인벤토리가 총량을 주므로 *"192개 중 20개를 읽었다"* 가 가능하다
- 사용자 자신의 말과 **고른 선택지 문구는 바꾸지 않는다** — 바꾸는 순간 지도가 아니라 해석이 된다

#### 출력 — 인벤토리 한 줄 + 고정 3절

```
scope:   repo=/Users/…/devbrew  branch=worktree-feature+comprehension-debt-plugin  +session=a1797a3f…
files:   2    blocks: 192 (239.2 KB)    decisions: 38    span: 2026-08-02 09:11 ~ 2026-08-06 22:51
commits: 6    scan: 1.5s                unparsed: 0
```

| 절 | 내용 | 재료 | 누가 만드나 |
|---|---|---|---|
| **1. 지금 상태** | 이 브랜치가 `main` 대비 담고 있는 것 · 어디까지 됐나 · 무엇이 아직 검증 안 됐나 | git(기계 주입) + 설명 블록 | 기계 + 모델 |
| **2. 열려 있는 것** | 미해결 · 막힌 것 · 다음 행동 | 1·3절 | 모델 |
| **3. 그렇게 된 이유** | **두 원장을 나란히** — ⓐ **내가 정한 것**(`AskUserQuestion` 짝, 문구 그대로) ⓑ **묻지 않고 정해진 것**(output style의 일곱 번째 순간이 표시한 블록) · 버린 길 | 설명 블록 + 결정 짝 | 모델 |

**순서가 이 구조의 내용이다.** 행동 가능한 것(1·2절)이 위로 오고 근거(3절)가 아래에서 받친다.
앞선 판은 시간순 흐름이 뼈대였는데, 그건 *"무슨 일이 있었나"* 에 맞는 형태이지 *"지금 어떤 상태인가"*
에 맞는 형태가 아니다.

**3절의 두 원장이 이 기능의 새 축이다.** 앞선 판의 결정 원장은 `AskUserQuestion` 짝만 담았다 — 즉
**사용자가 내린 결정**만. 그 여집합(사용자 없이 내려졌지만 사용자를 구속하는 결정)이 어디에도
없었는데, 이해부채의 정의가 정확히 그것이다. ⓑ는 output style의 일곱 번째 순간이 대화창에 표시한
것을 모아 온다 — 여기서도 **앞의 둘이 쓰고 `/standup`이 읽는다.**

**인벤토리를 모델이 아니라 기계가 찍는 것이 안전장치다.** 에이전트는 자기가 안 본 것을 모르고,
fork 안에서는 사용자도 원본을 못 본다. **누락은 데이터로 들어와야 한다 — 지시로는 안 된다.**

#### 명령

`commands/standup.md` — 진입점만. 절차는 skill이 소유한다.

**호출 형태 주의**: `--plugin-dir`로 로드한 플러그인은 **bare 이름으로 호출되지 않는다**(실측 —
`/surface`는 플러그인을 로드한 채로도 `Unknown command`이고 `/nameprobe:surface`만 잡혔다). 설치된
플러그인은 bare가 되지만, [§10-6](#10-검증-계획)의 A/B 러너는 미설치 상태로 도는 환경이므로
**네임스페이스 형태(`/agent-transparency:standup`)로 호출해야 한다.**

#### skill 전문

`skills/briefing-current-state/SKILL.md`:

```markdown
---
name: briefing-current-state
description: 지금 이 작업이 어떤 상태인지 — 코드가 무엇이 됐고, 무엇이 열려 있고, 왜 그렇게 됐는지를 대화 기록과 git에서 꺼내 보여준다
cost_class: low
context: fork
agent: Explore
background: false
disable-model-invocation: false
---

## 인벤토리 · 코드 상태

!`python3 "${CLAUDE_PLUGIN_ROOT}/scripts/prepare_standup.py"`

## 할 일

위 인벤토리가 가리키는 파일들을 **직접 읽어서** 아래 3절을 만든다.

1. `files:` 줄이 읽을 대상의 개수와 총량이다. 인벤토리는 총량만 알려 준다 — 본문은 네가 읽는다.
2. **최근부터 읽는다.** 목적이 "지금 상태"라 최신 서술이 더 유용하다. 오래된 근본 결정은 결정
   원장이 따로 보존하므로 최근 우선이 그것들을 잃지 않는다.
3. 3절을 이 순서로 쓴다 — ① 지금 상태 ② 열려 있는 것 ③ 그렇게 된 이유.
4. 3절은 두 원장을 **나란히** 놓는다 — ⓐ 사용자가 고른 것(`AskUserQuestion` 질문 + 고른 라벨)
   ⓑ 사용자에게 묻지 않고 정해진 것. ⓑ가 이 절의 핵심이다.
5. **답변 첫 줄에 얼마나 읽었는지 밝힌다** — `blocks: N` 중 실제로 몇 개를 읽었는지. 너는 네가
   안 본 것을 모르므로, 이 한 줄이 사용자가 그 사실을 아는 유일한 경로다.
6. ⓐ의 선택지 문구는 **한 글자도 바꾸지 않는다.**
7. 인벤토리 자리에 `[shell command execution disabled by policy]` 가 있거나 `scope:` 줄이 없으면
   **답하지 말고** 기록을 가져오지 못했다고 보고한다. 기억으로 채우지 마라.

## 무엇을 읽고 무엇을 읽지 않나

**읽지 않는다** — `Bash` 명령 문자열 · 파일 내용 · `tool_result` 본문 · 에이전트 반환값 본문 ·
`<sid>/subagents/*.jsonl`. 이 절의 목적에 필요하지 않고, 비밀이 사는 곳이다.

**읽을 때 알아야 할 것** (전부 실측):

- 사람 발화는 세 곳에 나뉘어 있다 — `type=="user"`(`userType=="external"` · `isMeta!=true` ·
  `content`가 문자열) · `type=="queue-operation"` · `type=="attachment"`의
  `attachment.type=="queued_command"`. **`user`만 보면 턴 도중의 교정 발화를 통째로 놓친다.**
- `type=="last-prompt"` 는 같은 텍스트를 반복 기록하므로 세지 않는다.
- 어시스턴트 레코드는 `text`·`thinking`·`tool_use` 중 하나만 담는 경우가 많다. "다음 어시스턴트
  메시지"를 찾을 때 **텍스트 없는 레코드를 건너뛴다.**
- 다음으로 시작하는 텍스트는 사람 발화가 아니다 — `<task-notification>` · `<system-reminder>` ·
  `<local-command` · `[Request interrupted` · `Caveat:`

## 쓰는 방식

- 이 프로젝트에서만 통하는 말(도구 이름 · 약어 · 내부 개념)은 **첫 등장 시 그 자리에서 한 구절로
  풀어 쓴다.** 쓰지 말라는 것이 아니라 쓰는 즉시 설명하라는 것이다.
- **번호나 기호로 가리키지 않는다** — 절 번호, 항목 번호, 이 답변에서 네가 붙인 라벨. 가리켜야
  하면 그것이 무엇인지 한 구절로 함께 적는다. 사용자는 그 문서를 펴 놓고 있지 않다.
- 비유를 만들지 않는다. 표준 용어가 있으면 그것을 쓰고, 없으면 그 일이 실제로 무엇인지 그대로 쓴다.
- 표 · 고정된 순서 · 굵은 라벨을 쓴다. 사용자가 한 항목을 찾는 데 전체를 읽지 않아도 되게 한다.
- 사용자가 아는 말이라고 가정하지 않는다 — 그 판단은 네가 할 수 없다.
- **사용자가 쓰는 언어로 답한다.** 이 지시문이 한국어인 것은 답변 언어와 무관하다.
```

`context: fork`이므로 이 skill은 **메인 대화 기록에 접근하지 못한다** — 디스크의 트랜스크립트 파일만
본다. 그것이 의도다. 근거가 파일에 있는 것으로 강제된다.

#### 왜 `## 쓰는 방식` 을 여기 복제하는가 (리뷰가 적발)

output style은 **메인 대화에만 적용된다**(N4 = subagent에는 안 닿는다). `context: fork` + `agent:
Explore` 로 도는 이 skill은 Explore 에이전트의 시스템 프롬프트를 쓰므로 output style의 `## Vocabulary`
· `## Format` 규칙이 **닿지 않는다.** 그런데 `/standup` 답변은 이 플러그인에서 사용자가 읽게 되는
가장 긴 산출물이다 — 쉬움 규칙이 가장 필요한 곳에 규칙이 없었다.

복제는 drift를 낳으므로 `tests/test_readability_parity.py` 가 output style의 `## Vocabulary` 문단과
이 절이 **같은 다섯 규칙**을 담는지 대조한다(AC28). 다섯 번째(포인터 상환)는 2026-08-06에 추가됐다.

`` !`…` `` 는 [동적 컨텍스트 주입](https://code.claude.com/docs/en/skills#inject-dynamic-context)으로,
skill 내용이 모델에 가기 **전에** 실행되고 출력이 그 자리를 대체한다. 모델이 실행하는 것이 아니다.

#### 준비 스크립트 입출력 계약

`scripts/prepare_standup.py` — **약 40줄.** 앞선 판의 `extract_recap.py`에서 선별 · 마스킹 · 접기 ·
머리자르기 로직이 전부 사라지고 범위 결정 · 계수 · git 조회만 남는다.

| 항목 | 값 |
|---|---|
| 입력 (환경) | `CLAUDE_CODE_SESSION_ID` |
| 입력 (git) | `git rev-parse --git-common-dir` 의 **부모** → **메인 리포 루트** · `--abbrev-ref HEAD` → 현재 브랜치 |
| 대상 파일 | **메인 리포 루트**를 슬러그로 바꾼 접두사로 `~/.claude/projects/<슬러그>*/` 를 글롭 → 그 아래 모든 `*.jsonl`, **단 아래 후보 검증을 통과한 것만** |
| **후보 검증** (2026-08-07 신규) | 각 후보 파일의 레코드에 실린 `cwd` 가 **메인 리포 루트 아래**인지 확인한다. 아니면 버리고 헤더에 `rejected: N` 으로 계상 |
| 범위 필터 | 레코드의 `gitBranch == 현재 브랜치` **OR** 파일명이 현재 세션 id |
| 인자 | `--branch <이름>` · `--since <ISO 날짜>` · `--all` · `--session-id` (테스트용) |
| **인자 전달 경로** (2026-08-07 신규) | `commands/standup.md` 가 사용자 인자를 `$ARGUMENTS` 로 받아 skill 호출에 그대로 넘기고, `SKILL.md` 의 `` !`…` `` 줄이 `python3 … prepare_standup.py $ARGUMENTS` 로 전달한다. **허용 인자 화이트리스트**를 스크립트가 강제하고 그 밖의 토큰은 거부한다(exit 4) — 셸에 임의 문자열이 들어가는 경로를 만들지 않기 위해서다 |
| 출력 | stdout에 UTF-8: **인벤토리 3줄** + 대상 파일 **경로 목록 — 파일마다 그 파일의 in-scope 레코드 수를 함께** + `## 코드 상태`(`git log --oneline` · `git diff --stat`) |
| **출력에 없는 것** | **대화 본문 일체.** 본문은 에이전트가 직접 읽는다 |
| 종료 코드 | `0` 정상 · `3` 대상 파일 0개 · `4` 내부 오류 |
| 실패 시 stdout | 인벤토리 대신 `STANDUP-UNAVAILABLE: <사유>` 한 줄 |

**판단은 하지 않는다.** 범위 결정 · 계수 · git 조회만 한다.

**파일마다 in-scope 레코드 수를 함께 내는 이유** (리뷰가 적발): 범위는 **레코드 단위**(`gitBranch`)로
정의되고 인벤토리도 레코드 단위로 세는데, 에이전트에게는 **파일 경로**가 간다. 한 세션이 여러
브랜치에 걸쳐 있으면(이 작업의 세션이 실제로 그랬다 — `main` → 워크트리) 에이전트가 그 파일을
통째로 읽으면서 범위 밖 레코드를 함께 보고, **인벤토리 숫자와 자기가 본 것이 어긋난다.**
파일별 수를 함께 주면 `SKILL.md` 가 *"이 파일에서는 `gitBranch` 가 X인 레코드만 세라"* 를 지시할 수
있고, 어긋남이 에이전트에게 보인다.

**후보 검증이 필요한 이유** (codex가 적발): 슬러그 접두사 글롭은 **경로가 그 접두사로 시작하기만
하면** 잡는다. `…/devbrew` 접두사는 `…/devbrew-experiments` 같은 **무관한 리포**도 잡고, 그 다음
`gitBranch == main` 같은 흔한 이름이 매칭되면 남의 작업 트랜스크립트가 범위에 들어온다. 레코드의
`cwd` 가 메인 리포 루트 아래인지 확인하면 그 경로가 닫힌다.

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
| `--git-common-dir` 의 부모 | **9개** | **472개** |

**실패 양식이 특히 나쁘다**: 워크트리 자신의 디렉토리는 정확히 매칭되므로 파일이 0개가 아니고,
`STANDUP-UNAVAILABLE` 경로를 타지 않는다. 즉 **472개 중 1개만 보고 정상처럼 답한다.** 이것은 §7의
*"못 읽은 것은 없는 것이 아니다"* 를 정면으로 위반한다. 같은 해석을
`plugins/spec-distill/hooks/state_path.py` 가 이미 `--git-common-dir` 로 수행하고 있다(in-repo 선례).

## 7. 에러 처리 · 강등

| 상황 | 동작 | 원칙 |
|---|---|---|
| kill switch set | 훅이 아무 것도 안 함, exit 0 | kill switch는 보안 컨트롤 |
| 훅 stdin 파싱 실패 · `agent_type` 부재 | `"에이전트"` 로 대체하고 **정상 출력** | 설명 장치가 스스로를 막지 않는다 |
| 세션 파일 못 찾음 | `STANDUP-UNAVAILABLE: session file not found (<시도한 글롭>)` | **못 읽은 것은 없는 것이 아니다** |
| jsonl 일부 파싱 실패 | 읽힌 것만 세고 인벤토리에 `unparsed: N` | 부분 결과에 부분임을 표시 |
| `git` 부재 · git 명령 실패 | `## 코드 상태` 자리에 `(git 조회 실패: <명령>, <종료 코드>)` 한 줄. 인벤토리와 나머지 절은 정상 | 한 재료가 죽어도 나머지는 산다. 빈 절을 조용히 두지 않는다 |
| 에이전트가 인벤토리보다 **적게** 읽음 | **정상 동작이다.** 답변 첫 줄이 `blocks: N` 중 몇 개를 읽었는지 밝힌다 | 탐색의 자유가 누락의 은폐가 되면 안 된다 |
| `` !`…` `` 가 정책으로 비활성 | skill이 `[shell command execution disabled by policy]` 를 보고 **답하지 않고 보고** | 근거 없이 답하지 않음 |
| 훅 스크립트 예외 | stderr에 남기고 exit 0 | 설명 장치가 작업을 막으면 [§3](#3-불변식) 위반 |

강등이 사람에게 안 닿으면 그것은 강등이 아니라 통과다. 모든 강등은 출력에 남는다.

**앞선 판에서 사라진 두 행**: *"마스킹 모듈 로드 실패 → 본문 없이 `RECAP-UNAVAILABLE`"* 과
*"예산 초과 → 접거나 머리만 남김"*. 마스킹과 예산이 [§3](#3-불변식)·[§6.3](#63-standup--명령--skill--준비-스크립트)에서
제거됐으므로 대응하는 강등 경로도 없다.

## 8. 파일 목록

```
plugins/agent-transparency/
├── .claude-plugin/plugin.json          # name · description · version 0.1.0
├── README.md                           # 맨 앞에 force-for-plugin 경고 · Principles Instantiated ·
│                                       #   Hooks Installed · "설치 이전 작업에는 설명 블록이 없다"
├── REFERENCE.md                        # ★정본 — 루브릭 A·B·C·D 전문 ·
│                                       #   게이트 표(판정 방식 포함) · 판정 구간 표
├── CHANGELOG.md
├── output-styles/
│   └── agent-transparency.md           # §6.1 전문 (일곱 순간)
├── hooks/
│   ├── hooks.json                      # SubagentStop 1건
│   └── subagent-explain.py             # agent_type 기반 상수 2종 + kill switch
├── commands/
│   └── standup.md
├── skills/
│   └── briefing-current-state/
│       └── SKILL.md                    # §6.3 전문 (context: fork)
├── scripts/
│   └── prepare_standup.py              # 범위 결정 + 인벤토리 + git. 약 40줄
└── tests/
    ├── test_output_style.py            # AC1–AC5 · AC31 · AC38
    ├── test_subagent_hook.py           # AC6–AC9 · AC36 · AC37 · AC44
    ├── test_prepare_standup.py         # AC10 · AC11 · AC20 · AC34 · AC41 · AC42
    ├── test_readability_parity.py      # AC28 — output style ↔ SKILL.md 다섯 규칙 대조
    ├── test_plugin_contract.py         # AC25–AC27 · AC32 · AC33 · AC35 · AC39 · AC43
    ├── test_ab_runner_contract.py       # AC40 · AC45 — ab_gate.sh 를 실행하지 않고 문자열로 검사
    ├── ab_gate.sh                       # A/B 러너 (§10-6)
    ├── prompts/                         # a.txt · b.txt · c.txt · d.txt — 러너가 읽는 작업 프롬프트
    └── fixtures/
        └── ab-project/                 # AC29 A/B 측정용 고정 픽스처
```

**2026-08-06에 사라진 파일 셋**: `scripts/secret_patterns.py` · `tests/test_masking.py` ·
`tests/test_mask_parity.py`. 입력 마스킹이 [§3](#3-불변식)에서 제거되면서 검증 대상 자체가 없어졌다.
`extract_recap.py` → `prepare_standup.py` 는 개명이 아니라 **책임 축소**다(선별·마스킹·접기 삭제).

**정본을 플러그인 안에 두는 이유** (리뷰 적발): 앞선 판은 루브릭 전문을 **설계 문서**에 두고 AC가
그것을 검사하게 했다. 그런데 배포되는 것은 `plugins/agent-transparency/` 이고 **설계 문서는 그 안에
없다** — 설치 환경이나 CI에서 경로가 깨지거나, 문서가 옮겨지면 조용히 stale해진다. 그래서 정본을
`REFERENCE.md` 로 옮기고 설계 문서는 인용만 한다. 사본이 둘로 늘지만 **규범은 하나**이므로 drift가
판정에 영향을 주지 않는다.

`REFERENCE.md` 는 **AC가 파싱해야 하는 것을 전부** 담는다 — 루브릭 **네 종(A·B·C·D)** ·
**게이트 표(판정 방식 열 포함)** · **판정 구간 표**.

리포 루트 변경 하나:

- `docs/plugin-authoring.md` — **`output-styles` 언급이 현재 0건**이다. devbrew의 첫 output style
  이므로 컴포넌트 작성 절을 추가한다(frontmatter 필드 · `keep-coding-instructions` 함정 ·
  `force-for-plugin`의 대가 · subagent 미적용).

`CLAUDE.md`는 건드리지 않는다 — 규칙이 output style에 살기 때문이다.

## 9. Acceptance Criteria

번호는 **앞선 판과 동일하게 유지**한다 — 재번호를 하면 diff에서 무엇이 실제로 바뀌었는지 안 보인다.
2026-08-06에 **12개가 삭제**되고(AC12–AC15 · AC17–AC19 · AC21–AC24 · AC30) **7개가 추가**됐으며
(AC34–AC40), 2026-08-07 리뷰 반영으로 **5개가 더 추가**됐다(AC41–AC45). 21 + 7 + 5 = **총 33건**
(우연히 v1과 같은 수이나 구성이 다르다). 삭제된 번호는 재사용하지 않는다.

### output style

| # | 기준 | 검증 |
|---|---|---|
| AC1 | frontmatter에 `keep-coding-instructions: true`와 `force-for-plugin: true`가 있다 | 파싱 |
| AC2 | 본문이 `Explanatory`의 4요소를 담는다 — 블록 형식 · 코드 전후 · 미루지 않음 · 코드베이스 특유 | 4개 각각 + mutation |
| AC3 | 본문의 Moments 표가 **7행**이고, 각 행이 [§6.1](#61-output-style--이-플러그인의-본체) 「일곱 순간의 출처」 표의 근거와 1:1 대응한다 | 행 수 + 대응표 대조 |
| AC4 | 본문에 Trigger boundaries 문단이 있고 경계가 모호한 **5개**(long task · verdict · work ends · unavailable · **settled without asking**)를 정의한다 | 5개 용어 각각 |
| AC5 | `## Format` 규칙이 **일곱 순간으로 스코프**돼 있고(모든 출력에 무조건 적용되지 않는다), **표는 항목이 둘 이상일 때만** 요구한다 | 두 문구 각각. 표 예외 문장이 없으면 red — 그 예외가 없으면 [§10-6](#10-검증-계획) 게이트 1(오타 수정 응답에 표 0개)을 설계가 **구조적으로 통과할 수 없다**(리뷰가 적발) |
| AC31 | 본문에 **리뷰어·에이전트 간 상반 판정**을 밝히라는 지시가 있다 (K7 = 브리프 C22) | 그 문구가 output style 본문에 존재. K7 제약 서술에만 있고 본문에 없으면 red |
| **AC38** | **「묻지 않고 정했을 때」 행이 세 항목을 모두 요구한다** (행 번호가 아니라 **이름**으로 찾는다 — 표 안 위치는 바뀔 수 있다) — 무엇을 정했나 · **왜 안 물었나**(세 사유가 열거됨) · **되돌리는 말** | 세 항목 각각 + 세 사유 열거 확인. 되돌리는 항목이 빠지면 red — 그것이 없으면 통보이지 투명성이 아니다 |

### 훅

| # | 기준 | 검증 |
|---|---|---|
| AC6 | kill switch 2종을 존중한다 — set이면 stdout 비고 exit 0 | 실행 |
| AC7 | 유효한 `hookSpecificOutput.additionalContext` JSON을 낸다 | 실행 + JSON 파싱 |
| AC8 | 파일시스템에 아무것도 쓰지 않는다 | `strace`가 없는 환경이므로 **임시 HOME + 임시 cwd로 실행 후 전체 트리 해시 비교**(생성 후 삭제된 임시 파일은 못 잡음 — 한계 명시) |
| AC9 | 출력에 `decision` 키가 어떤 경우에도 없다 | 실행 ([§3](#3-불변식)) |
| **AC36** | 페이로드의 `agent_type` 값이 출력 `additionalContext` 문자열에 **그대로 나타난다**. 키가 없거나 stdin이 파싱 불가면 `"에이전트"` 로 대체하고 **정상 출력**한다 | 세 입력(정상 값 · 키 없음 · 깨진 JSON) 각각 |
| **AC37** | 묶기 문장이 `agent_type == "workflow-subagent"` 일 때 **나오고**, 그 외 값일 때 **안 나온다** | **양방향** — 한쪽만 검사하면 항상 붙이는 구현이 통과한다. **이것은 문구 검사이지 행동 검사가 아니다** — 실제로 하나의 표로 묶이는지는 [§12](#12-미해결)의 OQ-X로 남긴다(리뷰가 적발) |
| **AC44** | **훅 상수가 요구하는 네 요소를 모두 담는다** — 누가 / 무엇을 찾았나 / 근거가 어디 있나 / 판단이 어떻게 바뀌었나 | 네 요소 각각 + mutation(하나를 지우면 red). AC7·AC36·AC37은 JSON 유효성·치환·분기만 보므로 **요소 하나가 조용히 삭제되는 회귀를 아무도 못 잡는다**(리뷰가 적발) |

### `/standup`

| # | 기준 | 검증 |
|---|---|---|
| AC10 | 슬러그 접두사를 **메인 리포 루트**(`--git-common-dir` 의 부모)에서 만든다 | **워크트리 안에서 실행**하는 픽스처에서 메인 리포 디렉토리와 형제 워크트리 디렉토리가 **둘 다** 잡힌다. `--show-toplevel` 기반 구현은 이 테스트에서 red |
| AC11 | 범위가 `gitBranch == 현재 브랜치` **OR** 현재 세션 id의 **합집합**이다 | 브랜치만 맞는 레코드와 세션만 맞는 레코드를 각각 담은 두 픽스처가 **둘 다** 포함된다 |
| AC16 | `AskUserQuestion` 질문과 사용자가 고른 라벨이 **문구 변경 없이** 출력된다 | **게이트 5a**(구문) — 답변이 인용한 라벨 문자열을 실제 트랜스크립트에서 grep으로 찾는다. 못 찾으면 red. 루브릭 C의 Q2·Q3가 보조 |
| AC20 | 코드 상태가 트랜스크립트가 아니라 `git log` · `git diff --stat` 에서 온다 | git 없는 픽스처에서 그 자리에 `(git 조회 실패: <명령>, <종료 코드>)` **한 줄이 들어가고**, 인벤토리는 정상 출력된다 |
| **AC34** | **인벤토리가 총량을 정확히 보고한다.** 술어를 여기서 못박는다 — `files`=후보 검증 통과 파일 수 · `blocks`=in-scope 레코드 중 `type=="assistant"` 의 비어 있지 않은 `text` 블록 수 · 바이트=그 `text` 문자열의 **UTF-8 인코딩 길이 합**(레코드 직렬화 길이가 아님) · `decisions`=`AskUserQuestion` **도구 호출** 수(짝이 없는 호출도 센다, 그 사실을 `unpaired: N` 으로 함께 표기) · `span`=in-scope 레코드 `timestamp` 의 최소·최대 · `unparsed`=JSON 파싱 실패 줄 수 | 값을 아는 합성 픽스처에서 여섯 값이 **정확히** 일치. `blocks`가 실제보다 작으면 red (에이전트가 "다 읽었다"고 착각하게 만든다). 술어 미정의 상태로 두면 구현마다 다른 수가 나온다(리뷰가 적발) |
| **AC41** | **후보 검증이 무관한 리포를 배제한다** — 접두사만 공유하는 다른 리포의 트랜스크립트가 범위에 안 들어온다 | `…/devbrew` 와 `…/devbrew-experiments` 두 디렉토리를 만들고 후자에 `gitBranch: main` 레코드를 심은 픽스처에서, 후자가 **0건** 포함되고 헤더 `rejected` 가 그 수를 계상한다. 접두사 글롭만 하는 구현은 red |
| **AC42** | **인벤토리가 파일마다 그 파일의 in-scope 레코드 수를 낸다** | 한 파일에 두 브랜치 레코드를 섞은 픽스처에서, 그 파일의 수가 **전체 레코드 수가 아니라 in-scope 수**와 일치 |
| **AC43** | **`--branch`·`--since`·`--all` 이 명령 → skill → 스크립트로 전달되고, 화이트리스트 밖 토큰은 거부된다** | 세 인자 각각이 스크립트에 도달 + 임의 문자열(`; rm -rf /` 등)이 exit 4로 거부. 문서가 광고하는 탈출구가 실물에 없으면 red |
| **AC35** | **`SKILL.md`가 세 가지 트랜스크립트 사실과 「읽지 않는 것」 목록을 담는다** — ① 사람 발화 세 레코드 타입 ② `last-prompt` 제외 ③ 텍스트 없는 어시스턴트 레코드 건너뛰기 ④ `Bash` 문자열·파일 내용·`tool_result`·에이전트 반환값·서브에이전트 파일 | 네 항목 각각 + mutation. 앞선 판에서 이것들은 추출기 **코드**에 있었고 AC12–AC15가 검사했다 — 코드가 사라졌으므로 검사 대상이 지시문으로 옮겨간다 |

> **AC12–AC15 · AC17–AC19 · AC21–AC24 · AC30 삭제.** 사람 발화 추출 코드(AC12–15)는 `SKILL.md`
> 지시로 옮겨가 AC35가 대신한다. 예산·접기(AC17–19)와 마스킹(AC21–24·AC30)은 대상 자체가 사라졌다.
> **AC30은 4라운드 리뷰가, AC22는 3라운드 리뷰가 만들어 낸 것**이다 — 리뷰가 정교하게 다듬은 검증이,
> 검증 대상이 사라지면서 통째로 없어졌다. 리뷰어는 *"이 AC가 대상을 제대로 재는가"* 는 묻지만
> *"이 대상이 있어야 하는가"* 는 잘 묻지 않는다는 것이 이번 사이클의 교훈이다.

### 플러그인 계약

| # | 기준 | 검증 |
|---|---|---|
| AC25 | README 맨 앞에 *"끄려면 플러그인 전체를 비활성화해야 한다"* 경고 + *"설치 이전 작업에는 설명 블록이 없다"* + **[§12](#12-미해결) OQ-J의 잔여 위험 고지**(*"이 플러그인이 대화창에 내는 설명에는 어떤 비밀 필터도 없다"*) + Principles Instantiated + Hooks Installed | 네 항목 각각. OQ-J가 README 공개를 요구하는데 이 AC가 그것을 검사하지 않으면 요구가 문서에만 남는다(리뷰가 적발) |
| AC26 | plugin.json에 name·description·version이 있고 description이 output style과 같은 문구다 | 대조 |
| AC27 | skill frontmatter에 `cost_class` · `context: fork` · `agent: Explore` · `background: false` 가 있다 | 파싱 |
| AC28 | **`SKILL.md`의 `## 쓰는 방식` 이 output style `## Vocabulary` 와 같은 다섯 규칙을 담는다** — 조어 첫 등장 시 풀어쓰기 · **번호·기호 포인터 상환** · 표준 용어 우선 · 비유 금지 · 상대의 지식을 가정하지 않음 | **판정 메커니즘을 여기서 못박는다**(리뷰가 적발 — 순수 `unittest`가 영어 산문과 한국어 산문의 의미 대응을 판정할 수는 없다): 두 파일에 규칙마다 **주석 앵커**를 단다 — output style 쪽은 `<!-- rule:pointer -->`, `SKILL.md` 쪽은 같은 문자열. 테스트는 **다섯 앵커가 양쪽에 모두 있는지**만 본다. 산문 일치는 사람 리뷰이고, 이 검사는 *한쪽에서 규칙이 통째로 사라지는 것*만 잡는다 — 그 한계를 AC 문구에 적는다 |
| **AC39** | **명령 이름이 내장 command와 겹치지 않는다** | 실물 probe — 임시 플러그인에 같은 이름의 명령을 두고 bare 호출했을 때 `Unknown command` 가 나와야 한다. 바이너리 문자열 추출만으로는 **번들 prompt 계열 명령을 못 본다**(실측: 존재하는 `/review`·`/pr-comments`가 그 방식으로 0회로 나왔다) |

### 머지 게이트

| # | 기준 | 검증 |
|---|---|---|
| AC29 | **A/B 측정 통과** — [§10-6](#10-검증-계획)의 작업들을 돌려 게이트 **7개**를 모두 만족 (1·2·**5a**는 구문, **3·4·5b·6은 루브릭 3표 다수결**) | §10-6 |
| AC32 | `REFERENCE.md` 에 루브릭 **A·B·C·D 전문**이 있고 각각 **4문항**이며, 게이트 3·4·5·6이 개수 검사가 아니라 그 루브릭으로 판정한다 | 플러그인 파일을 파싱 — 루브릭 4블록 존재 + 각 4문항 + 게이트 표의 판정 방식이 "루브릭". 개수 기반 문구가 남아 있으면 red |
| AC33 | 게이트 5가 존재하고 **`/standup` 이 실제로 실행된 답변**을 판정 대상으로 삼는다 | 게이트 표에 그 작업 행이 있고 판정 구간 표에 `/standup` 행이 있다. `/standup` 검증이 스크립트 stdout에서 끝나면 red |
| **AC45** | **러너가 픽스처를 cwd로 claude를 호출하고, model·effort·CLI 버전을 매니페스트에 기록한다** | 러너 문자열 검사 — `cd "$FX"` 없이 호출하는 형태면 red(모델이 리포 루트를 편집할 수 있다). `--effort` 미전달 또는 매니페스트 부재도 red |
| **AC40** | **A/B 러너가 명령을 네임스페이스 형태로 호출한다** (`/agent-transparency:standup`) | 러너 스크립트 문자열 검사. bare `/standup` 이면 red — `--plugin-dir` 환경에서 `Unknown command` 가 되어 게이트 5·6이 **측정 자체를 못 하고**, 모델이 자연어로 대충 답한 것을 루브릭이 판정하게 된다(실측) |

## 10. 검증 계획

1. **단위** — 위 AC별 테스트. Python `unittest`(리포 관행: `-m unittest`로만 실행).
2. **mutation** — 통과가 정답인 assert는 모양으로 이빨을 판별할 수 없다. AC2·AC3·AC5·AC35는 대상
   바이트를 **표기·값·위치 세 축**으로 흔들어 red가 나는지 확인한다. 내가 지운 바이트를 되돌리는
   mutation은 계측이 안 되므로 쓰지 않는다.
3. **훅 실물** — `SubagentStop` 페이로드 샘플을 stdin으로 넣어 실행. kill switch on/off 양방향,
   `agent_type` 세 입력(정상 · 키 없음 · 깨진 JSON), `workflow-subagent` 양방향.
4. **`/standup` 픽스처** — 합성 `.jsonl` 픽스처로 AC10·AC11·AC20·AC34. 실제 세션 파일은 테스트에
   쓰지 않는다(비밀·개인정보).
5. **자기 적용** — output style 본문·README·description을 자기 `## Vocabulary` 다섯 규칙으로 읽는다.
   **번호·기호 포인터 규칙을 이 설계 문서 자신에게도 적용한다** — `§`·`AC`·`OQ` 참조가 무엇을
   가리키는지 한 구절로 함께 적혔는지. 자동화되지 않는 부분은 사람 리뷰다.
6. **A/B 측정 (AC29, 머지 게이트)** — 시스템 프롬프트를 건드리는 변경이라 주장 대신 측정한다.

   **고정 픽스처**: `plugins/agent-transparency/tests/fixtures/ab-project/` — 최소 Python 프로젝트
   하나. `README.md`(3행에 오타 `teh`), `src/calc.py`(`add` 함수), `tests/test_calc.py`(통과 중),
   `src/util.py`(함수 3개). 매 실행 전 `git checkout -- .` 로 초기 상태 복원.

**`add` 의 초기 동작을 픽스처가 명시한다** (codex가 적발): `def add(a, b): assert a >= 0 and b >= 0;
return a + b` — 음수 입력에서 `AssertionError`. 그리고 `tests/test_calc_negative.py` 를 **실패하는
상태로** 함께 둔다(음수 두 개, 음수-양수 혼합, 0 경계). 이것이 없으면 게이트 2는 모델이 **아무것도
안 고쳐도** 통과하고, 게이트 6은 *"결정이 일어났을 것"* 을 가정만 하게 된다. 게이트 2의 통과 조건은
`test_calc.py` **와** `test_calc_negative.py` 둘 다 exit 0이다.

   **실행**: 두 조건 × 네 작업 × 3회 (작업 (e)는 켠 조건만). 모델·effort는 두 조건에서 동일하게
   고정하고 그 값을 결과에 기록한다. 출력은 트랜스크립트 파일에서 읽는다(터미널 캡처는 렌더
   아티팩트가 섞인다).

   **러너**: `plugins/agent-transparency/tests/ab_gate.sh` 하나가 아래를 전부 수행하고 **머지 게이트
   종료 코드**를 낸다. 조각난 절차를 사람이 이어 붙이지 않는다.

   ```bash
   set -euo pipefail
   # 모델과 effort를 둘 다 요구하고 결과에 기록한다. 조건 차이는 --plugin-dir 유무뿐이다.
   : "${AB_MODEL:?AB_MODEL 필요}"; : "${AB_EFFORT:?AB_EFFORT 필요}"
   ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"      # 리포 루트 (절대경로)
   PD="$ROOT/plugins/agent-transparency"                # 플러그인 절대경로
   FX="$PD/tests/fixtures/ab-project"; OUT="$PD/tests/out"; mkdir -p "$OUT"
   # ★ 매니페스트 — 재현에 필요한 값을 전부 남긴다
   { echo "model=$AB_MODEL"; echo "effort=$AB_EFFORT";
     echo "claude=$(claude --version)"; echo "plugin=$(git -C "$ROOT" rev-parse HEAD)"; } > "$OUT/manifest.txt"
   for i in 1 2 3; do
     for t in a b c d; do
       for cond in off on; do
         sid="$(uuidgen)"                       # ★ 세션 id를 우리가 정한다 → 트랜스크립트 위치가 확정
         git -C "$FX" checkout -- .
         [ "$cond" = on ] && P=(--plugin-dir "$PD") || P=()
         # ★ 반드시 픽스처를 cwd 로 — 안 그러면 모델이 리포 루트를 편집할 수 있다
         ( cd "$FX" && claude -p --session-id "$sid" --model "$AB_MODEL" --effort "$AB_EFFORT" \
             "${P[@]}" "$(cat "$PD/tests/prompts/$t.txt")" )
         echo "$cond $t $i $sid" >> "$OUT/index.txt"
         if [ "$t" = b ]; then                  # 게이트 2: 진짜 종료 코드를 잡는다
           ( cd "$FX" && python3 -m pytest -q ) ; echo "$cond $i $?" >> "$OUT/tests.txt"
         fi
         if [ "$t" = b ] && [ "$cond" = on ]; then   # 작업 (e): 같은 세션을 이어간다
           # ★ 네임스페이스 필수 — --plugin-dir 로는 bare 이름이 Unknown command 다 (AC40)
           ( cd "$FX" && claude -p --resume "$sid" --model "$AB_MODEL" --effort "$AB_EFFORT" \
               --plugin-dir "$PD" "/agent-transparency:standup" )
           echo "on e $i $sid" >> "$OUT/index.txt"
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
   3. 게이트 3·4·5b·6은 해당 루브릭을 **3회** 호출한다 —
      `claude -p --model "$M" "<루브릭 전문>\n\n<기록·응답 블록>"`
   4. 문항별 다수결(2/3) → **모든 문항이 `yes`** 여야 그 실행이 통과
   5. 게이트 1·2·5a는 `out/` 의 텍스트·종료 코드·트랜스크립트 grep으로 직접 판정
   6. 일곱 게이트가 모두 통과면 exit 0, 아니면 exit 1 + 어느 게이트가 왜 실패했는지 출력

   **작업 프롬프트 (문서에 고정 — 구현 계획으로 미루지 않는다)**

   | | 프롬프트 | 비고 |
   |---|---|---|
   | (a) | `README.md 3번째 줄의 오타 'teh' 를 'the' 로 고쳐줘` | |
   | (b) | `src/calc.py 의 add 함수가 음수도 처리하도록 고치고 기존 테스트가 통과하는지 확인해줘` | **혼자 정할 일이 여럿 생긴다** — 게이트 2와 게이트 6이 이 하나를 공유한다 |
   | (c) | `기존 테스트가 add 함수의 음수 입력을 실제로 덮는지 서브에이전트를 써서 확인하고 결과를 보고해줘` | **판단이 걸린 조사** — 답에 따라 다음 행동이 달라진다 |
   | (d) | `src/calc.py 의 오류 처리 방식을 정해야 해. 선택지를 제시하고 나에게 물어봐줘` | |
   | (e) | (b)를 수행한 세션에서 이어서 `/agent-transparency:standup` | **켠 조건에서만** — 끈 조건에는 명령이 없다 |

   작업 (c)는 3라운드에서 바뀌었다. 앞선 판의 *"함수가 몇 개인지 세라"* 는 **사실 조회**라서, 루브릭
   A의 Q4(*"결과가 판단을 어떻게 바꿨는가"*)가 자연스럽게 성립하지 않아 **설계가 멀쩡해도 게이트가
   거짓 실패**할 수 있었다. 새 프롬프트는 답에 따라 다음 행동이 갈리는 조사다.

   **게이트 — 사람 눈대중 없이 판정된다. 다만 판정 방식이 둘로 갈린다**

   | # | 작업 | 통과 조건 | 판정 방식 | 무엇을 지키나 |
   |---|---|---|---|---|
   | 1 | (a) | 켠 조건 **3/3**에서 최종 응답에 마크다운 표 행(`^\|`)이 **0개** | 구문 | 과잉 방지 — 오타 하나에 표가 나오면 실패 |
   | 2 | (b) | **양 조건 3/3** 모두 `tests/test_calc.py` 통과(종료 코드 0). 두 조건의 통과 여부가 다르면 fail | 구문 | 능력 비저하 (K1) |
   | 3 | (c) | 켠 조건 **3/3**에서 판정 구간이 **루브릭 A를 통과** | **루브릭** | G2 — 에이전트 결과 표면화 |
   | 4 | (d) | 켠 조건 **3/3**에서 판정 구간이 **루브릭 B를 통과** | **루브릭** | **G1 · 브리프 C3** — 사용자가 유일하게 "확실하다"고 한 순간 |
   | **5a** | (e) | 켠 조건 **3/3**에서 답변이 인용한 결정 라벨 문자열이 **실제 트랜스크립트에 존재** | **구문** | **사실 부합** — 모델이 문구를 지어내거나 바꾸면 여기서 걸린다 |
| 5b | (e) | 켠 조건 **3/3**에서 `/standup` 답변이 **루브릭 C를 통과** | **루브릭** | G3 — `/standup` 답변 자체의 검증 |
   | **6** | **(b)** | 켠 조건 **3/3**에서 응답이 **루브릭 D를 통과** | **루브릭** | **G6** — 묻지 않고 정해진 결정의 표면화 |

   게이트 6이 2026-08-06에 추가됐다. 새 작업을 만들지 않고 (b)를 재사용하는 이유: *"음수를 어떻게
   처리할까"* 는 답이 여럿인 선택인데 프롬프트가 묻지 말라고도 물으라고도 하지 않으므로, **모델이
   혼자 정하는 상황이 자연스럽게 발생한다.** 별도 작업을 만들어 *"혼자 정해라"* 라고 지시하면 그건
   지시받은 행동이지 자발적 행동이 아니라 측정 의미가 없다.

   #### 판정 구간 — 어느 텍스트를 루브릭에 넘기나

   | 게이트 | 판정 구간 |
   |---|---|
   | 3 | `Agent` 도구 결과 레코드 직후 첫 **텍스트 블록을 담은** 어시스턴트 메시지의 텍스트 블록 전체 |
   | 4 | `AskUserQuestion` 호출을 담은 어시스턴트 메시지에서 **그 호출보다 앞에 있는 텍스트 블록들** + 바로 직전의 **텍스트 블록을 담은** 어시스턴트 메시지 |
   | 5 | `/standup` 호출 직후 첫 **텍스트 블록을 담은** 어시스턴트 메시지의 텍스트 블록 전체 |
   | **6** | 작업 (b) 실행의 **모든 텍스트 블록을 시간순으로 이은 것** — 결정이 어느 시점에 일어날지 미리 알 수 없다 |

   구간이 비어 있으면 그 실행은 **fail**이다(설명이 없었다는 뜻이므로).

   **"텍스트 블록을 담은"이 load-bearing이다** (2026-08-06 실측으로 발견). 앞선 판은 *"직후 첫
   assistant 메시지"* 였는데, 어시스턴트 레코드는 `text`·`thinking`·`tool_use` 중 **하나만** 담는
   경우가 많다(한 세션: `tool_use` 356 · `thinking` 258 · `text` 187). 그래서 순진한 정의는 **3분의 2
   확률로 텍스트 없는 레코드에 착지**하고, 구간이 비어 fail로 떨어진다. 이 함정을 밟은 채로 재면
   *"에이전트 반환 11곳 중 설명 1곳"* 이 나오는데, 건너뛰고 다시 재면 **4곳**이다.

   게이트 1·2는 구문으로 충분하다 — *"표가 없다"* 와 *"테스트가 통과한다"* 는 형식이 곧 사실이다.

   **게이트 3·4·5·6은 구문으로 판정할 수 없다.** 두 리뷰어가 세 라운드에 걸쳐 반복 지적한 지점이다:
   *"버린 선택지와 그 이유를 밝혔는가"* 는 자연어 요구사항이고, 굵은 라벨을 세는 검사는 **무관한
   굵은 문구 넷으로도 통과한다.** 이 플러그인이 실패하는 방식은 "안 돌아감"이 아니라 **"돌긴 도는데
   알맹이만 빠짐"** 이라, 개수 검사는 정확히 그 실패를 못 본다.

   #### 루브릭 판정 (게이트 3·4·5·6)

   판정 구간 텍스트를 별도 모델 호출에 넘기고 아래 문장을 **그대로** 프롬프트로 쓴다. 판정자는
   `yes`/`no` 만 낸다. **같은 산출물에 3회 돌려 다수결**로 항목별 판정을 확정하고, **모든 항목이
   `yes`** 여야 그 실행이 통과다.

   > **정본은 `plugins/agent-transparency/REFERENCE.md` 다.** 아래 네 블록은 읽는 사람을 위한
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

   **루브릭 C — `/standup` 답변 (게이트 5)**

   판정자에게 **두 블록**을 준다 — 스크립트가 낸 `<인벤토리>`(원본 헤더)와 그것을 받은 모델의
   `<응답>`. 응답만 주면 Q2가 대조 없는 추정이 된다.

   ```
   <인벤토리> 는 스크립트가 낸 헤더이고 <응답> 은 그것을 받은 어시스턴트의 답변이다.
   각 질문에 yes 또는 no 한 단어로만 답하라. 설명하지 마라.
   Q1. <응답>이 세 절을 이 순서로 담는가 — ① 지금 상태 ② 열려 있는 것 ③ 그렇게 된 이유?
   Q2. <응답>이 <인벤토리>의 blocks 총수 대비 자기가 실제로 몇 개를 읽었는지 밝혔는가?
       (총수와 읽은 수가 둘 다 나와야 yes. "다 읽었다"만 있고 수가 없으면 no)
   Q3. <응답>의 세 번째 절이 두 원장을 구분해 담는가 — 사용자가 고른 것 / 사용자에게 묻지 않고
       정해진 것? (한쪽이 0건이면 0건이라고 적혀 있어야 yes. 절 자체가 없으면 no)
   Q4. <응답>에 이 프로젝트에서만 통하는 말, 또는 설명 없는 번호·기호 참조가 쓰인 곳이 없는가?
       단 기록에서 그대로 인용한 문구 안은 판정 대상이 아니다.
   ```

   앞선 판의 루브릭 C는 4절 구조·접힘 표시·시간순을 물었는데 **그 셋 다 이번 판에서 사라졌다**
   (4절 → 3절, 접기 규칙 삭제, 시간순 → 상태 우선). 문항을 재작성한 이유다. Q2·Q3의 괄호 단서는
   *"해당 없으면 yes"* 기본값이 **빠뜨린 응답까지 통과시키는 것**을 막는다 — 앞선 판이 그 함정을
   4라운드에 한 번 밟았다.

   **루브릭 D — 묻지 않고 정한 것 (게이트 6)**

   ```
   아래는 어시스턴트 응답이다. 이 작업에서 어시스턴트는 사용자에게 묻지 않고 여러 선택을 했다.
   각 질문에 yes 또는 no 한 단어로만 답하라. 설명하지 마라.
   Q1. 사용자에게 묻지 않고 정한 것이 무엇인지 적혀 있는가?
   Q2. 왜 묻지 않았는지가 적혀 있는가?
   Q3. 사용자가 무엇이라고 말하면 그 결정이 뒤집히는지가 적혀 있는가?
   Q4. 그렇게 적힌 항목이 실제로 답이 여럿일 수 있는 선택인가?
       (자명한 사실 진술이나 이미 지시받은 것을 "내가 정했다"고 부르고 있으면 no)
   ```

   Q4가 **게이밍 방지**다. Q1~Q3만 있으면 *"파일을 읽기로 정했습니다 / 필요해서 / 읽지 말라고
   하시면 됩니다"* 같은 빈 항목으로 통과한다.

   판정 호출 수: 산출물 12개(게이트 3·4·5·6 × 3회) × 3표 = **36회**. 머지 전 1회성이다.

   **이 방식의 한계를 그대로 적는다**: 판정에 모델이 들어오므로 판정자도 틀릴 수 있다. 3표 다수결이
   흔들림을 줄이지만 없애지는 못한다. 대신 루브릭이 파일에 있어 **재현되고 반박된다** — 판정이
   이상하면 루브릭을 고치면 되고, 그 고침이 리뷰 대상이 된다. 굵은 글씨를 세는 검사에는 고칠 대상이
   없었다([§12](#12-미해결)의 OQ-L).

   > **`Agent` 도구명 근거** (리뷰가 정의 부재를 지적): subagent 호출은 트랜스크립트에 도구 이름
   > `Agent` 로 기록된다. 실측 — 이 리포 전체 도구 호출 중 `Agent` **777건**, `Task` **0건**.
   > 플랫폼이 이름을 바꾸면 게이트 3이 매치 0으로 떨어지므로, 구현 시 이 값을 상수로 두고 실측으로
   > 확인한다.

   **기록 — 게이트가 아니다**

   출력 문자 수의 조건별 중앙값과 그 비율을 결과 파일에 남긴다. **통과 조건으로 쓰지 않는다.**
   합의된 임계치가 없기 때문이며, 근거 없는 숫자를 게이트에 넣으면 결국 사람이 눈대중으로
   통과시키게 된다. 이 값은 축적해서 다음 판단의 근거로 쓴다.

## 11. 기각된 대안

| 기각한 것 | 이유 |
|---|---|
| **`/why` (특정 판단의 근거 되짚기)** | **사용자가 제거.** 그 결과 서브에이전트 파일 읽기·에이전트 반환값 추출·대상 매칭이 사라졌다. **다만 이 삭제가 과했다** — `/why`라는 기능을 지우면서 *"에이전트 작업을 읽는 능력"* 까지 딸려 나갔고, 그 자리를 사용자 본인의 발화가 메웠다. 2026-08-06에 재료를 다시 뒤집은 계기다 |
| **`/recap` 이라는 이름** | **내장 `/recap` 이 이미 있다**(실측 — `type:"local"`, *"Generate a one-line session recap now"*). 기능은 안 겹치지만 bare 호출을 내장이 가져가므로 사용자는 오류가 아니라 *그럴듯한 다른 답*을 받는다. `/brief`·`/context`·`/stats` 도 같은 이유로 제외 |
| **설명 표의 첫 줄을 넓혀 두 갈래(묻는다 / 혼자 정한다)로 두기** | **사용자 재결정(2026-08-06)** — *"줄을 하나 더 늘리는 게 명확하겠어"*. 줄 수를 6으로 묶는 이점(분량·발화 빈도)보다, **안 묻는 갈래가 정의상 스스로 드러나지 않는다**는 점이 컸다. 제목이 "요청"인 줄 밑에 두면 가장 놓치기 쉬운 항목이 가장 안 보이는 자리에 놓인다 |
| **입력 마스킹 (패턴 · 엔트로피) 과 추출 화이트리스트** | **2026-08-06 제거.** 재료가 *"이미 메인 트랜스크립트에 있는 것"* 으로 확정되면서 막는 것이 거의 없어졌다 — 근거 계산은 [§3](#3-불변식)의 위협 표. 같은 내용이 훅 경로로는 필터 없이 나가고 있어 두 경로의 등급이 달랐던 것도 이유다 |
| **스크립트가 설명 블록을 골라 주입** | **선별이 필터로 기능하지 못한다**(실측). 기계적 앵커 세 종의 합집합이 82.7%, 크기 임계가 80.9% — 바이트가 소수의 큰 블록에 몰려 있고 그 큰 블록이 곧 설명 블록이다. 게다가 전형적 브랜치의 재료가 220~560 KB라 주입으로는 브랜치 범위를 감당할 수 없다 |
| 마스킹한 **정제 사본**을 임시 파일로 만들고 그것만 탐색하게 | 마스킹된 대화 사본이 디스크에 남고, skill 종료 훅이 없어 삭제를 보장할 수 없다. 그리고 원본을 못 읽게 막는 수단이 어차피 없다(플러그인 `settings.json`은 `agent`·`subagentStatusLine` 키만 지원) |
| 읽는 양에 상한(예산) 두기 | K1(억제 금지) 위반. 탐색 방식에서는 범위가 넓어져도 인벤토리만 커지고 실제 읽기는 에이전트가 정한다 |
| `Stop` 훅으로 종료 설명 강제 | `additionalContext`가 *"대화를 계속시킨다"* — 턴이 안 끝나는 루프. devbrew 금지 패턴(unbounded autonomy) |
| `PreToolUse`로 결정 순간 검사·차단 | 유일하게 확실하지만 사용자 질문 자체를 막는다. [§3](#3-불변식) 위반 |
| 훅이 `last_assistant_message`(에이전트 최종 메시지)를 `additionalContext`에 실어 보내기 | 페이로드에 **실제로 온다**(실측). 그러나 같은 내용이 메인 트랜스크립트에 이미 있어 컨텍스트에 두 번 들어간다 — K2(토큰 비용) |
| 훅이 에이전트 출력을 보고 **짧으면 주입을 건너뛰기** | 내용 검사 = [§3](#3-불변식) 위반. `agent_type` 라벨 분기와 다르다 — 라벨은 메타데이터이고 이건 내용이다 |
| statusline · subagentStatusLine | 출력 토큰 0이 매력적이나 `tasks[]`에 findings 필드가 없어 **내용을 실을 수 없다** |
| 원장 · 상태 파일 | 트랜스크립트가 이미 전문을 보관한다. 남은 일은 저장이 아니라 선별 |
| `/standup`을 메인 대화에서 실행 | 발췌가 메인 컨텍스트에 영구히 쌓여 `/compact`를 앞당긴다 — 이 플러그인이 막으려는 병을 스스로 유발 |
| `project-init` 개명·흡수 (브리프 C18) | **명시적 번복.** 수단이 output style로 정해진 뒤 사용자가 독립 플러그인으로 재결정. `project-init` 문자열이 리포에 1,055회/40+ 파일이라 개명 비용도 크다 |
| 17개 agent 정의에 반환 규약 추가 | devbrew 안에서만 작동 → K3(적용 범위는 이 리포의 모든 작업) 위반 |
| 프로젝트 고유어 **런타임** grep 금지 검사 | K1 위반. "무엇이 고유어인가"를 정의하는 순간 그 정의가 억제 장치가 된다 |
| 순간별 줄 수 고정 | 가짜 정밀함. 상황마다 틀리고 지켜지지도 않는다 |
| 각 설명 끝에 `상세: /standup` 안내 | 매 순간 붙는 안내가 그 자체로 소음이 된다 |
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

즉 채택한 것은 [§5.4](#54-집행-수준-oq1-결정)의 ③(테스트타임 회귀 락)이고, 기각한 것은 ①(런타임
차단)이다. 같은 도구(문자열 검사)를 쓰지만 대상과 효과가 다르다.

## 12. 미해결

| # | 미해결 | 왜 지금 못 정하나 · 무엇으로 방어하나 |
|---|---|---|
| OQ-A | 트랜스크립트 형식이 **문서화돼 있지 않다**. 바뀌면 `/standup`이 깨진다 | 사전 감지 장치가 없다. 방어는 [§7](#7-에러-처리--강등)의 `STANDUP-UNAVAILABLE`(조용한 실패 금지)과 인벤토리의 `blocks: 0` 신호뿐 |
| OQ-B | `force-for-plugin`이 다른 플러그인 스타일과 충돌하면 "먼저 로드된 것이 이긴다" | 플랫폼 규칙이라 개입 불가. README 경고만 |
| OQ-C | 도입부 두 문장이 과잉 발화를 실제로 막는지 | **AC29 게이트 1로 측정한다.** 못 막으면 문구를 강화하거나 순간 수를 줄인다 |
| OQ-D | `/standup`의 발견 가능성 — 각 설명 끝의 안내를 없앴다 | README와 명령 목록에서만 알게 된다. 실사용에서 안 쓰이면 재검토 |
| OQ-E | `Explanatory` 원문이 개선되면 사본이 낡는다 | 감지 장치가 없다. `Explanatory` 본문을 주기적으로 대조하는 것 외에 방법이 없다 |
| OQ-F | 약 550 토큰이 시스템 프롬프트 끝에 붙는 것이 내장 지침의 주의를 얼마나 가져가는지 | 외부에서 직접 계측 불가. 게이트 2(능력 비저하)가 간접 신호만 준다 |
| OQ-H | 이 브랜치가 생기기 **전에** 다른 브랜치에서 한 일은 범위에 안 들어온다 | 이 작업의 인터뷰가 그 경우다(`main`에서 진행). `--since`·`--all` 로 사용자가 넓힐 수 있다 |
| OQ-I | 레코드 `type` 이름(`queue-operation`·`attachment`·`last-prompt`)은 **문서화되지 않은 관측값**이다 | 플랫폼이 이름을 바꾸면 AC35의 지시문이 실물에서는 조용히 빗나간다. 인벤토리의 `blocks`가 0이면 이상 신호로 읽을 수 있지만 자동 감지는 아니다 |
| **OQ-J** | **훅 · output style · `/standup` 세 경로 모두 출력 필터가 없다** — 훅이 매 에이전트 종료마다 "무엇을 찾았나 / 근거가 어디 있나"를 대화창에 내라고 지시하고, 그 내용은 파일 정본으로 남는다 | 브리프 OQ8이 연 항목. **완화책이 없다** — 모델 출력에 필터를 거는 지점이 플랫폼에 없고, 프롬프트로 막으면 K1(억제)에 걸린다. **수용된 잔여 위험**으로 문서화하고 README에 적는다. 2026-08-06에 입력 마스킹이 제거되면서 이 항목이 비밀 관련 유일한 잔여 위험이 됐다 |
| **OQ-P** | 판정 구간이 *"직후 첫 텍스트 블록을 담은 메시지"* 라, 짧은 전환 메시지 뒤에 설명이 오는 정상 응답을 **거짓 실패**시킬 수 있다 | `thinking`·`tool_use` 전용 레코드를 건너뛰는 것은 2026-08-06에 고쳤지만, *"짧은 전환 텍스트"* 는 여전히 텍스트라 걸린다. 구간을 넓히면 무관한 텍스트가 섞여 판정이 흐려진다. 첫 측정에서 거짓 실패가 관측되면 구간 규칙을 고친다 — **수용된 잔여 위험** |
| **OQ-L** | 게이트 3·4·5·6의 루브릭 판정에 **모델이 들어온다** — 판정자도 틀릴 수 있다 | 두 리뷰어가 세 라운드에 걸쳐 지적한 "구문 검사가 내용을 못 본다"의 해법으로 채택. 3표 다수결이 흔들림을 줄이지만 없애지는 못한다. 루브릭이 파일에 있어 **재현·반박 가능**한 것이 개수 검사와의 차이다 |
| **OQ-M** | **브리프 OQ7 (재귀 경계)** — C16의 "모든 작업"이 subagent **내부** 순간까지 포함하는지 | **이번 범위에서는 포함하지 않는다.** output style이 subagent에 안 닿고(N4), 17개 agent 정의를 고치는 방식은 devbrew 밖에서 작동하지 않으며(K3 위반), 순간마다 발화가 배수로 늘어 K2(토큰)와 충돌한다. 다만 **이것은 플랫폼 제약에 따른 결정이지 사용자 판단이 아니다** |
| **OQ-N** | **브리프 OQ9 (진행 중·방향 전환 검출)** — "긴 작업이 도는 중" 순간 | **설명 표에 넣지 않았다.** 사용자가 그 항목을 고르지 않았고, 에이전트 패널이 진행 상황을 이미 렌더한다([§1](#1-context--why)). 조용한 방향 전환은 어떤 훅 이벤트도 아니라 검출 경로가 없다 |
| **OQ-Q** *(신규)* | **자유 탐색은 에이전트가 자기가 안 본 것을 모른다** | 인벤토리(총 블록 수·바이트·기간)를 기계가 주입하고, 루브릭 C의 Q2가 *"총수 대비 몇 개를 읽었는지"* 를 답변에 강제한다. 그래도 **무엇을 안 읽었는지**(어느 블록인지)는 알 수 없다 — 총량만 안다 |
| **OQ-R** *(신규)* | **측정 환경과 실사용 환경이 다르다** — A/B 측정은 `--plugin-dir`(미설치)로 돌고, 그 환경에서는 명령이 bare 이름으로 안 잡힌다(실측) | 러너를 네임스페이스 형태로 고정했다(AC40). 그러나 **설치 후 bare 호출 경로는 측정되지 않는다.** 머지 후 수동 확인이 필요하다 |
| **OQ-S** *(신규)* | **일곱 번째 순간은 모델이 "내가 방금 결정했다"고 인식해야만 발동한다** | 인식 실패는 **검출 경로가 없다** — 결정을 안 했다고 믿는 모델은 아무것도 표시하지 않고, 표시가 없는 것과 결정이 없는 것을 밖에서 구분할 수 없다. 게이트 6(루브릭 D)이 *"결정이 확실히 일어나는 작업"* 하나에서만 측정한다. **수용된 잔여 위험** |
| **OQ-T** *(신규)* | **`/standup` 답변 품질이 과거에 이 플러그인이 켜져 있었는지에 달린다** | 훅과 output style이 먼저 돌아야 읽을 재료가 생긴다. 설치 이전 세션에는 git과 결정 원장만 남는다. 인벤토리의 `blocks` 수가 그 사실을 드러내며, README에 명시한다 |

| **OQ-Y** *(신규)* | **`SKILL.md`의 실제 판단 행동을 빠르게 재검증할 단위 테스트가 없다** | Claude 리뷰가 적발. 정적 검사(AC35·AC28)는 지시문에 그 문장이 있는지만 보고, 행동은 머지 전 1회성 AC29 게이트가 유일한 신호다. **게이트 사이의 회귀에는 감지 수단이 없다** — 지시문을 고쳐 놓고 다음 머지까지 아무도 모를 수 있다. 완화 후보(합성 트랜스크립트 + 소형 모델 호출로 도는 상시 스모크)는 이번 범위에 넣지 않았다 |
| **OQ-U** *(신규)* | **`/standup`의 fork가 실행될 때마다 새 서브에이전트 트랜스크립트가 생기고, 거기에 읽은 원문이 남는다** | [§3](#3-불변식)의 여섯 번째 위협 행. 사본을 안 만들려면 fork를 포기해야 하는데 그러면 발췌가 메인 컨텍스트에 쌓인다. 같은 신뢰 경계 안이고 다음 호출에 다시 실리지 않는다는 것이 한정 조건이지 완화책은 아니다. **수용된 잔여 위험** |
| **OQ-V** *(신규)* | **트랜스크립트 스키마의 *부분* drift는 감지되지 않는다** — 새 모양의 레코드가 조용히 빠져도 `blocks` 는 0이 아니다 | codex가 적발. 전면 실패는 `blocks: 0` 으로 보이지만 부분 변경은 안 보인다. 모든 자동 테스트가 합성 픽스처(현재 스키마)를 쓰므로 실물 변화를 잡을 경로가 없다. 완화 후보는 미지 레코드 타입 카운터인데 이번 범위에 넣지 않았다 |
| **OQ-W** *(신규)* | **지시문 언어가 응답 언어를 오염시킬 수 있다** | 훅 상수를 영어로 바꾸고 마지막에 *"사용자가 쓰는 언어로 답하라"* 를 넣어 완화했지만, fork skill 본문은 한국어로 남는다(devbrew 문서 규약). 한국어·영어 두 세션에서의 실제 동작은 측정하지 않았다 |
| **OQ-X** *(신규)* | **AC37은 묶기 *문구*만 검사하고 실제로 하나로 묶이는지는 검사하지 않는다** | codex가 적발. 동시 워크플로 종료를 실제로 만들어 확인하려면 런타임 probe가 필요한데, 워크플로 실행은 비용이 크고 A/B 배터리 밖이다. 문구가 있으면 모델이 따를 것이라는 가정에 기댄다 |

> **삭제된 항목**: OQ-G(예산 32 KB의 근거가 표본 1건) · OQ-K(탐지 마스킹이 못 잡는 비밀) ·
> OQ-O(루브릭 C가 4절을 안 잰다). 예산 · 마스킹 · 4절 구조가 2026-08-06에 전부 제거되면서 대응하는
> 미해결 항목도 사라졌다.

## 13. Metadata

| 항목 | 값 |
|---|---|
| 플러그인 | `plugins/agent-transparency/` (신규) |
| 버전 | `0.1.0` |
| 브랜치 | `feature/comprehension-debt-plugin` |
| 문제공간 입력 | `docs/superpowers/interview/2026-08-02-comprehension-debt-plugin-interview.md` |
| 의존 | 없음 |
| 신규 훅 | `SubagentStop` 1건 |
| 신규 명령 | `/standup` (설치 후) · `/agent-transparency:standup` (`--plugin-dir` 환경 — AC40) |
| kill switch | `DEVBREW_DISABLE_AGENT_TRANSPARENCY=1` · `DEVBREW_SKIP_HOOKS=agent-transparency:subagent-explain` — **훅에만 적용된다.** output style은 플러그인 비활성화로만 끈다 |
| 리포 루트 변경 | `docs/plugin-authoring.md`에 output style 컴포넌트 절 추가 |
| 머지 게이트 | AC29 — A/B 측정 **게이트 7개** (1·2·5a는 구문 판정, 3·4·5b·6은 루브릭 3표 다수결, 판정 호출 36회). 상세는 [§10-6](#10-검증-계획) |
| 개정 이력 | v1 (2026-08-05, 리뷰 5라운드) → **v2 (2026-08-07)** — 재료 반전(사용자 발화 → 어시스턴트 설명 + git) · 주입 → 탐색 · 마스킹 제거 · 4절 → 3절 · `/recap` → `/standup` · 일곱 번째 순간 추가 · 게이트 6 추가 |
