---
name: interview-research-specialization
type: design
created_at: 2026-09-22
source_interview: docs/superpowers/interview/2026-09-21-interview-research-specialization-interview.md
next_phase: superpowers:writing-plans
---

# 인터뷰의 조사 특화 — 계약을 꺼내고 한 필드를 더한다 · Design

> 출하된 계약 하나가 조건부 뒤에 갇혀 한 자리에서만 돌고 있었다. 그것을 꺼내 네 자리에 걸되,
> 그 계약의 기존 필드는 다른 것을 가리키므로 결정 연결은 새 필드로 놓는다.

## Handoff Context

이 문서가 받은 것: `docs/superpowers/interview/2026-09-21-interview-research-specialization-interview.md`
(§2 확정 14건 · §3 Open Questions 22건 · §4 landscape 30건 · §5 기각 12 + 위험 14).
텔레메트리·steelman 원문·리뷰 결정 17건은 그 파일의 `audit_file` 에 있다.

**재결정 규약(P23)** — brief §2 의 confirmed 14건은 재논의 대상은 아니지만 **반증 대상**이다.
근거가 있으면 보고 후 사용자 동의로 재결정하고, 뒤집은 항목은 *원래 / 재결정 / 근거* 세 칸으로
남긴다. 임의 변경은 금지다. **이 문서는 확정 하나를 좁혔다** — ⟨C13⟩ 이고, 세 칸 기록은
`## 결정 기록` 의 `### 재결정` 절에 있다. 라운드 1 리뷰가 그 미기록을 잡았고(`5cc29851#r1.1`)
사용자가 채택했다. ⟨C12⟩ 는 좁히지 않고 **문면 그대로 구현한다**(§F ①).

**번호 규약** — 이 문서가 붙이는 결정 id 는 `X<n>` 이고, `## 결정 기록` 뒤쪽의 `D<n>.<m>` 은
리뷰 엔진이 append 한 것이다. 라운드 1 이 두 체계가 같은 절에서 섞이는 것을 드러내 접두를 갈랐다.

**Locked in this doc** — `## Constraints` 의 C1–C14 는 brief §2 확정을 물려받은 것이고
`## 결정 기록` 의 X1–X12 는 설계 세션에서 사용자가 고른 것이며 `D1.1`–`D1.20` 은 리뷰 게이트의
채택 기록이다. 셋 다 하류(writing-plans)가 근거 없이 바꿀 수 없다.

## 목차

- [Goal](#goal)
- [Context / Why](#context--why)
  - [출하돼 있는 것 — 세 인용](#출하돼-있는-것--세-인용)
  - [그래서 결핍은 무엇인가](#그래서-결핍은-무엇인가)
- [Goals](#goals)
- [Non-goals](#non-goals)
- [Constraints](#constraints)
- [설계 (Architecture)](#설계-architecture)
  - [회계 — 무엇이 새로 생기는가](#회계--무엇이-새로-생기는가)
  - [§H 표기층 — id 의 생명주기](#h-표기층--id-의-생명주기)
  - [§A 자리 1 — 계약 정본](#a-자리-1--계약-정본)
  - [§B 자리 2 — 조사 장치 넷](#b-자리-2--조사-장치-넷)
  - [§C 자리 3 — 대등한 축](#c-자리-3--대등한-축)
  - [§D 자리 4 — 검문소 셋과 인계](#d-자리-4--검문소-셋과-인계)
  - [§E 자리 5 — 게이트](#e-자리-5--게이트)
  - [§F 동역학 — 자격 · 예산 · 면제](#f-동역학--자격--예산--면제)
  - [§G 데이터 흐름 한 장](#g-데이터-흐름-한-장)
- [Acceptance Criteria](#acceptance-criteria)
- [Files to Modify](#files-to-modify)
- [Verification Plan](#verification-plan)
  - [Deferred to plan](#deferred-to-plan)
- [Rejected Alternatives](#rejected-alternatives)
- [Open Questions](#open-questions)
- [알려진 한계](#알려진-한계)
- [Concrete Next Action](#concrete-next-action)
- [결정 기록](#결정-기록)
  - [재결정](#재결정)

## Goal

조사가 방향에 **영향**을 미치게 한다 — 바꾸거나, 기존 방향을 보강하거나, 기존 방향을 지지하거나.
셋 다 성공이다 ⟨C11⟩. 판별선은 남는다: **어느 결정에도 닿지 않은 조사는 셋 어디에도 들지 않는다**
(brief ⟨D1.1⟩). 이 문서의 모든 장치는 그 판별선 하나를 기계가 읽을 수 있는 형태로 만드는 것이다.

## Context / Why

brief 가 확정한 진단은 **조사 질의 결함이 네 국면 전부**라는 것이다 — 한 번 훑고 끝 · 결정에 안
닿는다 · 내부 없이 외부로만 · 하류가 못 쓴다 ⟨C1⟩. 특화의 축도 넷이고 자리는 다섯이다 ⟨C8⟩.

이 설계가 brief 를 받은 뒤 구현을 읽어 확인한 것이 무게중심을 옮겼다. 셋을 그대로 인용한다 —
풀어 쓰면 메커니즘이 소실된다.

### 출하돼 있는 것 — 세 인용

**① 내부 조사의 출력 계약은 이미 스키마로 존재한다.** `agents/steelman-builder.md` 의 출력 형식:

```yaml
repo_claims:
  - path: "<repo 상대경로>"
    anchor: "<심볼 | 헤딩 | 원문 인용>"
    line: 123                # 선택 — 보조 정보
    claim: "<주장>"
    touches: []
```

같은 파일의 동작 규칙 5·6:

> 5. 모든 `evidence[]` 와 `repo_claims[]` 는 `touches` 를 갖습니다. 빈 배열은 허용이고 거짓
>    부착보다 낫습니다 — 부착은 orchestrator 가 게이트 전에 확인합니다.
> 6. `repo_claims[]` 는 `path` 와 `anchor` 없이 내지 않습니다. 줄번호는 보조입니다.

⟨C12⟩ 가 요구한 「경로+앵커」가 `path`·`anchor` 로 있다. **「닿는 결정」은 `touches` 가 아니다** —
그 필드는 전제 `P<n>` 를 담는다(아래 ②). 라운드 1 리뷰가 이 오독을 잡았다.

**② 그 계약의 검증 절차도 존재한다.** `references/steelman.md` Step 2 「게이트-전 확인」:

> - `repo_claims` 전 항목: 경로 실재 → 앵커 실재 → 주장이 그 자리와 맞는가. 결과 ∈ {확인, 반증,
>   미확인}. `미확인`(확정도 반증도 못 한 것)은 J 에 들지 않되 4-block 에서 `[미확인]` 라벨로
>   **보인다** … 왜 확정하지 못했는지 한 줄을 audit §3 에 남긴다.
> - **양성 부착 주장 전부**(C4): `evidence[]`·`repo_claims[]` 중 `touches` 가 비어 있지 않은
>   항목마다 `claim` 을 **지목된 전제 문장**과 대조한다 … `premise_refutation.hits` 는 그 부분집합

세 번째 단계(「주장이 그 자리와 맞는가」)가 **구현을 읽으라는 요구**다. brief OQ17 이 지목한
구멍(경로+앵커만으로는 「인덱스만 읽고 구현을 안 읽음」이 안 걸러진다)을 이 절차는 이미 막는다.
동시에 두 번째 불릿이 `touches` 의 대상을 **전제**로 못 박는다 — 그 키잉에 Step 2.5 재검토 자격 ·
4-block 라벨 · `templates/interview-audit-template.md` 의 「부착 주장: <evidence #> → P<n>
확인|반증」이 전부 의존한다.

**③ 새 절을 만드는 쪽은 이미 계약으로 제한돼 있다.** `references/compression.md`:

> **존재 검사가 payload 를 양식으로 만든다.** 문서형 payload 는 절 존재 검사를 가질 수 있되
> 확산물의 *원문·근거·전량*을 payload 에 요구해서는 안 된다. 확산에서 나온 것의 **압축된 판정
> 한 줄**은 payload 의 것이다.

⟨C10⟩ 의 「새 절 신설 대신 §3·§5 를 살린다」가 이 계약과 정합한다. 같은 파일이 금지하는 것은
**링크**이고 경로+앵커가 아니므로, 내부 조사의 출처를 payload 에 두는 것은 N1a(payload 외부 URL
금지)와 충돌하지 않는다. 단 그 절은 문서형 payload 의 **절 존재 검사를 명시적으로 허용**하므로
「새 절이 금지된다」로 읽지는 않는다 — 새 절을 안 만드는 근거는 ⟨C10⟩ 자체다.

### 그래서 결핍은 무엇인가

**「장치가 없다」가 아니라 「있는 장치가 한 자리에서만, 조건부로 돈다」다.**

- 계약을 쓰는 자리가 `steelman-builder` **하나**다. `coverage-mapper`·`blind-spot-prober`·C43 경로
  (a) 자동확인은 같은 계약을 받지 않는다.
- 그 하나가 trigger 조건부다 — `references/steelman.md` 는 trigger 를 「landscape 모순 / 알려진
  anti-pattern / 기존 사용자 제약과의 충돌」로 한정하고, `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` 이면
  dispatch 가 `else` 가지 안이라 통째로 생략된다.
- 그래서 두 번 출하됐는데(2026-09-05 의 C9·C24) 두 번 다 발화하지 않았다. brief §2 의 ✎ 가 고른
  원인이 **「산문이라서」가 아니라 「읽는 자리가 없어서」**다.

Phase 0 과의 분업도 같은 모양이다. `skills/framing-requests/SKILL.md` 의 확산 절차 2는
「**레포 읽기** — 관련 코드 · `CLAUDE.md` · `AGENTS.md` · 기존 설계 문서를 읽습니다」 한 줄이고
출력 의무도 게이트도 없다. 즉 **분업선은 웹에만 그어져 있고 레포에는 어느 쪽에도 의무가 없다.**
이 사이클이 그 비용의 실증이다 — seed 가 레포를 읽고 낸 사실 셋이 Phase 1 의 재측정에 반증됐다
(brief §5 의 기각 1·2·3).

측정된 비대칭(외부 축은 floor 차원 + brief 절 + 게이트 검사 여섯, 내부 축은 산문 두 줄; 게이트
검사 26 중 조사 관련 15가 전부 외부)은 **상관까지만** 주장한다. 이 설계는 그 수를 인과로 쓰지
않는다 — `## Rejected Alternatives` R6 참조.

## Goals

- **G1** 내부(레포) 조사를 외부(웹) 조사와 **대등한 축**으로 세운다 — 커버리지 원장에 이름 있는
  자리가 있고 그 자리가 닫힐 때 floor 와 같은 앵커 검사를 받는다.
- **G2** 조사 산출물마다 **닿는 결정**을 달게 한다. 어느 결정에도 닿지 않은 조사는 성공 셋(바꿈·
  보강·지지) 어디에도 들지 않는다는 판별선을 계약으로 만든다. 그 연결은 기존 `touches`(전제)와
  **다른 필드**다.
- **G3** 조사를 **여러 겹**으로 돌 수 있게 한다 — 호출 «자격»을 ⟨C12⟩ 대로 「닿는 결정이 아직
  열려 있는가」로 두고, 그 위에 재개방의 함수인 예산 상한을 얹는다.
- **G4** 조사 산출이 **하류가 읽을 이유**를 갖게 한다 — 결정 연결과 상호참조로. 하류에 구속을
  걸지는 않는다(X2).
- **G5** 위 넷을 **집행**한다 — 검문소 셋: **생산 라운드 안의 확인** · 종료 시 누락 대조 · 게이트의
  형태 ∀. 앞의 둘은 웹 스위치와 steelman trigger 에 종속되지 않는다.

## Non-goals

- **조사를 했는지를 나중에 재는 장치** ⟨C5⟩. 2026-09-10 에 사용자가 사후 깊이 측정 계열을 「쓰이지
  않는 무게 · 번거로움 · 방향이 틀렸다」 세 이유로 직접 걷어냈고 그 판정은 유효하다. 술어의 범위를
  정밀하게 적는다(라운드 1 `f9bd806d#r1.1`):
  - **차단 판정에 개수를 쓰지 않는다.** red/green 을 가르는 술어는 전부 ∀ 형태이고, 순회할 항목이
    0건이면 공허하게 통과한다.
  - **조건 분기와 advisory 에는 개수가 들어간다.** 「레포 주장이 ≥1 이면」은 술어의 *발동 조건*이고
    「내부 조사 0건」 advisory 는 *공시*다. 둘 다 무엇도 막지 않는다.
  - 이 구분이 ⟨C5⟩ 양립 논거의 전부다 — 재서 **막으면** 사후 장치이고, 재서 **보이면** 공시다.
- **인터뷰를 조사 전용 단계로 바꾸는 것** ⟨C3⟩. 문제공간 탐색·질문·사용자 대화가 밀려나면 실패다.
  이 설계가 새 brief 절·새 agent·새 floor 키를 0개 만드는 이유가 이것이다.
- **Phase 0(`framing-requests`)의 편집** ⟨C4⟩. 「웹을 보지 않는다」 경계도, 레포 읽기 줄도
  건드리지 않는다. Phase 1 의 내부 축은 Phase 0 의 산출을 **받아 검증**하는 축이고(X6) 그 집행은
  Phase 0 을 고치지 않고 **받는 쪽 의무**로 놓는다(AC20).
- **소비자 플러그인(`superpowers:brainstorming`) 편집** — 이 리포 밖이라 불가능하다.
- **조사량의 «최대치»를 목표로 삼는 것** — brief ST1 에서 버렸다 ⟨C12⟩.
- **6번째 floor 키 신설** — `FLOOR_KEYS` 는 ∀ fail-closed 루프라 기존 픽스처 전량을 red 로 만든다 ⟨C10⟩.
- **기존 `touches` 의 의미 변경** — 락 둘과 Step 2·2.5·4-block·audit 템플릿이 전제 키잉에 의존한다(R9).
- **steelman.md Step 2 의 「중복 제거」** — 락이 그 문구를 그 파일에서 요구한다(R9).
- **새 조사 agent 파일 신설** — ⟨D1.7⟩ 이 열어 둔 자리를 배선으로 채운다.
- **리터럴 마커 `[from-code][auto-confirmed]` 의 유지** — 개념을 계약으로 흡수하고 리터럴은 폐기(X8).
- **과거 brief 코퍼스의 소급 수정** — 기존 줄번호 인용 23건은 그대로 남는다(X9).
- **하류에 대한 구속 문구** — X2 가 「읽을 이유까지만」으로 정했다.

## Constraints

brief §2 의 confirmed 14건을 그대로 물려받는다. 이 문서는 각 항목이 **어느 절에서 지켜지는지**를
함께 적는다 — 제약을 옮겨 적기만 하면 지켜졌는지 확인할 자리가 없다.

| id | 제약 (요지) | 지켜지는 자리 |
|---|---|---|
| C1 | 인터뷰가 조사의 책임 주체 · 내부와 외부 둘 다 | §A–§E 전부 |
| C2 | 하류 조사 슬롯 부재를 단정하지 않되 인터뷰가 특화해 짊어진다 | R3 |
| C3 | 조사 전용 단계로 바꾸지 않는다 · 대화가 밀리면 실패 | Non-goals · 새 절·agent·floor 키 0 · §F 면제 |
| C4 | Phase 1 안으로 한정 · Phase 0 의 웹 경계 불변 | Non-goals · AC20 |
| C5 | 사후 측정 장치 금지 | Non-goals 첫 항목의 세 불릿 · §E · AC8 |
| C6 | 강제 수준은 소비자에서 도출 | §D 인계 · X2 |
| C7 | 제약이라는 이름으로 구현 회피 거부 | §A–§E 다섯 자리 전부 실제 변경 |
| C8 | 네 축을 다섯 자리에 · 게이트가 다섯째이자 집행 수단 | §A–§E |
| C9 | 충돌 외부 근거 전부 취함 · decision-first 를 steelman 게이트로 | §B (계약이 decision-first) |
| C10 | 결핍 셋 · 새 절 대신 §3·§5 · 픽스처 안 건드리는 하한 | §C · §D · §E 조건부 발동 |
| C11 | 성공 = 조사가 방향에 영향(바꿈·보강·지지) | Goal · §D 반증 기록 · V1 의 라운드-안 배치 |
| C12 | 출력 의무(경로+앵커+닿는 결정)를 조사 자리 전부에 · **재개 조건은 「그 항목이 닿는 결정이 아직 열려 있는가」** · derived 축 | §A · §B · §C · **§F ① 호출 자격** |
| C13 | C44 압착의 대가는 가드의 계수 방식에서 지불 · **산출 항목이 «닿는 열린 결정»을 달면 +0, 없으면 +1** | §F ③ — **좁혔다. `### 재결정` 참조** |
| C14 | 장치의 형태는 소비 계약이 선 뒤에 결정 | 절 순서 자체(§D 소비 → §A 형태) |

## 설계 (Architecture)

### 회계 — 무엇이 새로 생기는가

라운드 1 리뷰가 「신설 0」을 반증했다. 정직한 회계는 이것이다:

| | 수 | 무엇 |
|---|---|---|
| 새 필드 | **2** | `decides: [OQ<n>]`(둘 다) · `id: RC<n>`(레포만) |
| 새 state 키 | **2** | `orchestration.open_decisions[]`(라운드 1 의 `touched_decisions` 를 필드로 흡수) · `blind_spot_dispatches: int`(개명) |
| 새 토큰 | **1** | `RC<n>`. 열린 결정은 기존 `OQ<n>` 을 쓴다(§H ①) |
| 새 파일 | **2** | `references/research-claims.md`(계약 정본) · `tests/test_research_claims_contract.sh`(락) |
| 새 게이트 술어 | **5** | 연결 ∀ · 연결 대상 실재 · 역참조 ∀ · 이름 정확 일치 derived(조건부) · 확인 줄 ∀ |
| **새 필수 줄 형식** | **4** | §4·§5 줄끝 `[RC3 → OQ1]` · §3 `→ 근거 RC3` · §0 `OQ1 [열림\|해결 ⟨S10⟩]` · audit §5 `확인 RC3 — …` |
| **새 frontmatter 필드** | **1** | `contract: v2` — 새 술어의 옵트인 스위치(§H ⑥) |
| **고치는 템플릿** | **2** | `interview-brief-template.md` · `interview-audit-template.md` |
| **새 agent** | **0** | orchestrator 직접 수행으로 채운다(§B) |
| **새 brief 절** | **0** | §0·§3·§4·§5 와 audit §1·§5 를 쓴다 |
| **새 floor 키** | **0** | `derived:` 축을 쓴다 |
| **새 dispatch 자리** | **0** | 라운드 2 가 네 번째 자리를 반증했다(§B) |
| **삭제** | **0** | — |
| **기존 `touches` 변경** | **0** | 락과 소비 절차가 의존한다 |
| **기존 픽스처 편집** | **0** | `contract: v2` 옵트인이라 81개가 무변경(§H ⑥) |

Non-goals 의 「0개」는 **이 표의 0 행들**만 가리킨다 — 줄 형식 넷·frontmatter 필드 하나·템플릿 둘은
0이 아니고 위에 세었다. 라운드 2 가 그 축소를 잡았다.

### §H 표기층 — id 의 생명주기

**라운드 2 가 이 절을 만들게 했다.** 라운드 1 의 지적을 각각 고치면서 술어 다섯이 전부 «줄 단위
리터럴»에 앵커됐고, 그 표기의 토큰 공간·발급자·정량자·순회 범위·일치 규칙·코퍼스 경계를 각각
정의하지 않아 같은 구멍이 여섯 번 다시 나왔다. 열거를 도출로 바꾼다 — 아래 여섯이 정본이고
§A·§D·§E·§F 는 전부 이 절을 전제한다.

**① 토큰 — 열린 결정은 `OQ<n>`, 레포 주장은 `RC<n>`.**

`D<n>` 을 쓰지 않는다. 리뷰 엔진이 `D<n>.<m>` 을 쓰고 그 토큰이 **이미 brief §2 ✎ 와 §3 에 살아
있어**(⟨D1.2⟩…⟨D1.7⟩ · ⟨D2.8⟩…⟨D2.14⟩) ② 의 실재 검사가 무관한 리뷰 결정 인용으로 만족된다.
대신:

- **열린 결정 = `OQ<n>`.** 새 토큰이 아니다 — payload §3 Open Questions 가 이미 그 목록이고
  코퍼스 전체가 그 표기를 쓴다. 「열린 결정」과 「Open Question」은 이 형식에서 같은 것이다.
- **레포 주장 = `RC<n>`.** 신설 토큰. `R<n>` 은 이 문서의 Rejected Alternatives 와 state 의 라운드
  헤딩(`## R<n>`)이 이미 쓰고 있어 삼중 과부하다.

**② 발급자와 거처 — state `orchestration.open_decisions[]` 하나.**

라운드 2 가 잡은 것: `OQ<n>`·`RC<n>` 을 **인터뷰가 도는 동안 만드는 자리가 없었다**. state 에
결정 목록이 없고 라운드의 «다음 결정»은 id 없는 문장이고 §0·§3 목록은 종료 시 작성되는 payload 다.
소비자만 있고 산출자가 없었다. 산출자를 둔다:

```yaml
orchestration:
  open_decisions:               # ★신설 — 인터뷰 중 결정의 유일한 거처
    - id: OQ1
      text: "<한 줄>"
      dimension: blind_spot     # 어느 커버리지 차원에 속하는가 (§F ① 자격의 입력)
      status: open              # open | resolved
      resolved_by: null         # resolved 면 그 사용자 발화 S<N>
      touched: false            # 조사가 닿았는가 (§F ③ 면제의 입력)
```

- **발급 시점**: orchestrator 가 라운드 규약의 «다음 결정» 블록을 쓸 때 그 문장에 `OQ<n>` 을 붙이는
  것이 발급이다. 번호는 순증이고 인터뷰 안에서만 유일하다.
- **`RC<n>`**: orchestrator 가 V1 확인을 마칠 때 붙인다. 거처는 audit §5 의 확인 줄이고, 그 줄이
  곧 레지스터다(별 state 키를 두지 않는다 — 확인 줄이 없는 `RC<n>` 은 §E ⑤ 가 red 로 잡는다).
- **생명주기**: `status: open → resolved` 는 사용자 발화로만. 해결돼도 **목록에서 지우지 않는다**
  (§D 의 근거 참조). `touched` 는 `false → true` 단방향이고 재개방으로도 되돌리지 않는다.
- **종료 시 사상**: `status: open` 인 것이 payload §3 Open Questions 로, 전량이 §0 결정 목록으로
  직렬화된다. 즉 §0 이 상위집합이고 §3 이 그 중 열린 것이다.

이 키 하나가 라운드 1 이 요구한 `touched_decisions` 를 필드로 흡수한다 — 별 키를 두지 않는다.

**③ 정량자 — ∀ 이되 sentinel 을 연다.**

§A 계약은 「빈 배열은 허용이고 거짓 연결보다 낫다」를 못 박는다. 게이트가 sentinel 없이 ∀ 를
요구하면 그 계약과 정면 충돌하고, brief §5 가 「필러 절 … «compliance-theatre»」로 이름 붙인 압력을
만든다. 그래서:

- 연결 표기는 `[RC3 → OQ1]`(레포) · `[→ OQ1]`(웹) · **`[→ 없음]`**(닿는 결정 없음) 셋이다.
- ∀ 는 「셋 중 하나가 줄 끝에 있는가」다. `[→ 없음]` 은 정직한 답이고 red 가 아니다.
- 「없음」이 몇 건인지는 **세지 않는다** — 세면 ⟨C5⟩ 위반이다(Non-goals).

**④ 복수 연결 — 전부 직렬화하고 역참조는 ∀.**

`decides: [OQ1, OQ4]` 는 `[RC3 → OQ1 · OQ4]` 로 쓴다. 역참조는 **그 `OQ<n>` 줄 전부**가 `RC3` 을
담아야 한다(∃ 아님). 라운드 2 가 지적한 것: ③ 을 단수·∃ 로 두면 §0 줄 하나로 만족돼 §3 의
`→ 근거 RC3` 을 지워도 통과한다.

**⑤ 일치 규칙 — 정확 일치.**

§C 의 derived 행 이름은 **정확히 `derived:internal_research`** 다. 접두 일치로 두면 무관한 차원으로
갈음된다 — 이 사이클의 audit §1 에 이미 `derived:internal_research_apparatus` 가 살아 있고 그것은
「내부 조사 장치의 형태」라는 **다른** 차원이다. 정확 일치면 그 행이 요구를 못 채우는 것이 맞다.

**⑥ 코퍼스 경계 — `contract: v2` 로 옵트인한다.**

라운드 2 가 실측했다: §4 항목에 연결을 ∀ 로 요구하면 `## 4. External Landscape` 를 가진 payload
픽스처 **81개**가 red 가 되고 그중 `interview-brief-valid.md` 는 스위트 다수의 베이스다. 일괄 편집은
회귀 생산원이고 optional 은 이빨 0이다 — brief §5 가 그 둘을 이미 이름 붙였다. 세 번째 길을 쓴다:

> §E 의 새 술어 다섯은 payload frontmatter 에 **`contract: v2`** 가 있을 때만 발동한다.
> 없으면 전부 미발동이고, 그때 `advisories` 에 「신 계약 미적용 brief」 한 줄이 실린다.

- 기존 픽스처·코퍼스 81개는 그 필드가 없어 **한 글자도 고치지 않는다**(⟨C10⟩ · Verification 7).
- 템플릿이 새 payload 에 `contract: v2` 를 넣으므로 앞으로의 산출은 전부 발동한다.
- 옵트인의 fail-open 방향은 advisory 가 사람에게 공시한다(L1 과 같은 형태).

### §A 자리 1 — 계약 정본

신규 `plugins/spec-distill/references/research-claims.md` 가 조사 주장 계약의 **정본**이다.
출하된 두 모양을 그대로 담고 **필드 둘을 더한다**:

```yaml
evidence:                      # 외부(웹) 주장
  - url: "https://..."
    supports: current | alternative | both
    claim: "<이 출처가 뒷받침하는 것>"
    touches: []                # 전제 P<n> — 출하된 뜻 그대로, 변경 없음
    decides: [OQ1]              # ★신설 — 이 주장이 닿는 «열린 결정». 빈 배열 허용
repo_claims:                   # 내부(레포) 주장
  - id: RC3                    # ★신설 — payload·audit 을 잇는 id (§H ①)
    path: "<repo 상대경로>"
    anchor: "<심볼 | 헤딩 | 원문 인용>"
    line: 123                  # 선택 — 보조 정보
    claim: "<주장>"
    touches: []                # 전제 P<n> — 변경 없음
    decides: [OQ1]              # ★신설
```

**두 필드를 왜 가르는가.** `touches` 는 전제 `P<n>` 를 담고 `steelman.md` Step 2 가 그것을 지목된
전제 문장과 대조하며 Step 2.5 가 `hits` 로 재검토 자격을 판정하고 4-block 이 `[반증됨]` 라벨을
붙이고 audit 템플릿이 「부착 주장: <evidence #> → P<n>」으로 직렬화한다. 같은 필드에 결정을 넣으면
그 사슬 전부가 무엇을 대조해야 하는지 모른다. **낱말도 가른다** — 「부착」은 `touches` 의 기존 뜻으로만
쓰고 새 것은 **「결정 연결」**이라 부른다. 템플릿 §5 의 `— 부착 M/N` 과 audit §3 의 「근거 N 중 부착 M」이
이미 그 낱말을 쓰고 있어 문구 기반 검사가 헛만족될 수 있다(라운드 1 `8891bd29#r1.1`). 그래서 술어의
대상은 낱말이 아니라 **`[RC<n> → OQ<n>]` 리터럴**이다.

**정본과 사본.** `agents/steelman-builder.md` 의 인라인 스키마 블록은 **남긴다** —
`tests/test_steelman_builder_scope.sh` 가 `repo_claims:`·`touches:`·`anchor:` 를 **그 파일에서**
요구하고, `awk '/^repo_claims:/{f=1;next}'` 로 블록을 잘라 `path`·`claim` 을 검사한다. 지우면
AC18(새 RED 0)과 충돌한다. 대신 **정합을 락이 지킨다**: 정본의 필드 이름 집합 ⊇ 사본의 것이고
사본에 정본에 없는 필드가 없다(락 축 D). 근거는 이 플러그인이 이미 집행하는 것이다 —
`tests/test_yaml_scalar_single_definition.py`:

> 갈라진 사본은 "한쪽만 고치는" 결함을 부르고, 실제로 두 merge 스크립트의 advisory 리터럴 5건이
> 인용 없이 나가 YAML flow sequence 로 읽히고 있었다.

**배달 방식** — 이 파일을 subagent 에게 **경로로 넘기지 않는다.** 설치본에서 플러그인 캐시는
사용자 프로젝트 밖이라 subagent 의 `Read` 가 권한 거부되고, 그러면 agent 는 계약 없이 판정하면서
orchestrator 는 그것을 모른다. 이 리포는 같은 문제를 이미 풀어 두었다 —
`skills/reviewing-brief/SKILL.md`:

> `${PROFILE}` 에는 경로가 아니라 **프로필 파일의 내용**을 싣는다 — 플러그인 캐시는 사용자
> 프로젝트 밖이라 리뷰어의 Read 가 거부된다.

같은 관습을 쓴다. dispatch 프롬프트가 받는 슬롯은 **둘**이다:

- `<claims_contract>${CLAIMS_CONTRACT}</claims_contract>` — 계약 파일의 **내용**(`cat` 펜스가 채운다)
- `<open_decisions>${OPEN_DECISIONS}</open_decisions>` — 지금 열린 결정 목록(`OQ<n>` + 한 줄).
  이것이 없으면 agent 는 `decides` 를 채울 수 없다.

**펜스 실패의 후효**(라운드 1 `bde80e55#r1.1`) — `cat` 펜스의 rc 가 0 이 아니면 **dispatch 하지
않는다**(계약 없는 조사는 계약 있는 조사와 산출물에서 구별되지 않는다). 그 라운드는 인터뷰를
멈추지 않고 계속하되:

- audit §2 Budget 에 `coverage-mapper 0 (unavailable: 계약 배달 실패)` 를 쓴다 — 게이트가
  `budget_mapper_failures` 에서 advisory 로 통과시켜 Step B 가 사람에게 보인다.
- 그 차원을 **자동으로 닫지 않는다.**
- `blind-spot-prober` 는 기존 web-off 경로와 같은 **inline premortem** 으로 강등한다.

**계약이 담는 문장 둘:**

1. **OQ17 의 선례 지시** — `docs/archive/interview/2026-07-12-project-init-audit-interview.md` 가
   남긴 것을 그대로: 「인덱스·레지스트리·목차·description 필드만 읽고 판정하지 말 것. **구현을
   읽어라.**」 그 사이클은 「레포에서 auto-confirm 한 사실」 범주를 만들었다가 **4건 중 3건의
   전제가 틀린 것**을 확인하고 범주 자체를 폐기했고, 실패 유형은 전부 같았다.
2. **`decides` 의 의미** — 「`<open_decisions>` 에 실제로 있는 결정 중 이 주장이 닿는 것」.
   목록에 없는 id 를 지어내지 않는다. 빈 배열은 허용이고 거짓 연결보다 낫다.

### §B 자리 2 — 조사 장치 넷

축 «전담 장치»는 **도구 부분집합이 아니라 출력 의무**로 정의한다 — brief ST1 이 「세 조사 agent 가
이미 동일한 `tools:` 를 갖고 있어 새 능력이 아니라 새 파일이 된다」로 도구-부분집합 정의를 버렸다.

| 장치 | 변경 | 웹 스위치 |
|---|---|---|
| C43 경로 (a) 자동확인 | `SKILL.md` 의 그 행이 리터럴 마커 대신 **계약(`repo_claims`)을 산출한다**고 적는다. **orchestrator 가 자기 `Read`/`Grep` 으로 직접 수행하고 subagent 를 부르지 않는다** | **무관** — 내부 축의 주 생산자다 |
| `agents/coverage-mapper.md` | `input_slots` 에 `claims_contract`·`open_decisions` 추가(각각 `kind:`). 출력에 `repo_claims[]`/`evidence[]` 요구 | 기존대로 `web_disabled` 시 codebase 근거만 |
| `agents/blind-spot-prober.md` | 같음 | 기존대로 web-off 시 inline premortem |
| `agents/steelman-builder.md` | 인라인 스키마에 `decides`·`id` 추가(블록 자체는 유지). 슬롯 둘 추가 | 기존대로 web-off 시 dispatch 생략 |

**생산자의 웹 종속을 여기서 해소한다**(라운드 1 `0fa0a9b6#r1.1`). 검문소만 무조건화하면
`DISABLE_WEB=1` 인 세션에서 내부 축의 ∀ 술어가 순회할 항목이 0건이라 공허하게 통과한다. 그래서
**내부 조사의 주 생산자를 경로 (a) 자동확인으로 둔다** — 그 자리는 웹 도구를 쓰지 않으므로 스위치와
무관하고, `SKILL.md` 의 C43 표에 이미 있다. steelman 의 `else` 가지 배치는
`tests/test_conducting_interview_stage.sh` 가 락으로 못 박은 **보안 컨트롤이라 건드리지 않는다**.
결과: web-off 세션에서도 내부 축은 돌고 웹 축만 강등된다. 이 주장은 Verification 8 이 실측한다.

**네 번째 dispatch 자리를 만들지 않는다**(라운드 2 재비판의 신규 지적). 「하니스 기본 탑재
read-only 탐색 subagent 배선」은 CLAUDE.md 가 요구하는 `**처분** —` 줄을 가질 수 없다 —
`shared/tests/test_dispatch_disposition.sh` 가 dispatch 대상 agent 집합을 `plugins/*/agents/*.md` 의
`name:` 으로만 도출하므로 기본 탑재 subagent 는 그 집합 밖이고, 처분 앵커만 +1 되어 「앵커 수 ==
dispatch 수」 단언(축 A①)이 red 가 된다. 안 적으면 「모든 dispatch 자리는 처분을 밝힌다」를 어긴다.
그래서 경로 (a) 는 **orchestrator 가 직접 수행**한다 — 「전담」의 판별은 도구가 아니라 출력 의무이므로
(brief ST1) 직접 수행도 그 의무를 똑같이 충족한다.

**dispatch 자리는 셋**이고 처분 줄을 락의 서식 그대로 쓴다 — `fail-(open|closed)` 다음에는
` · disclosure=` 나 줄끝만 허용되므로 **괄호 주석을 달지 않는다**(라운드 2 `2e6610eb#r2.1`):

```
**처분** — consumer=orchestrator · fail-closed · disclosure=loud advisory + audit §2 unavailable 사유
```

**`fail-closed` 가 막는 것은 «그 dispatch» 이고 인터뷰가 아니다**(라운드 2 `0fa0a9b6#r2.1`).
계약 펜스가 실패하면 그 장치를 **부르지 않고**(그게 fail-closed 다) 인터뷰는 계속하며, 게이트 쪽은
advisory 로 사람에게 공시한다. 둘은 다른 층이다 — CLAUDE.md 의 「막는 것은 항목이 소실됐거나 셀 수
없거나 주 판정자가 죽었을 때」는 **게이트 판정**의 규칙이고, 처분 줄의 방향은 **dispatch 단위**다.
현행 세 자리는 전부 `fail-open` 이므로 셋 다 고친다.

fan-out 은 선언한다(CLAUDE.md 처분 규약). **세 자리 전부 dispatch 당 1**이고 §F 의 자격·예산이 총량을
사용자 답에 묶는다.

### §C 자리 3 — 대등한 축

커버리지 원장의 `derived:` 에 **이름 있는** 내부 조사 차원을 세운다: `derived:internal_research`.
6번째 floor 키를 만들지 않는 근거는 ⟨C12⟩(iii) 와 `FLOOR_KEYS` 의 ∀ fail-closed 루프다(⟨C10⟩).

**이빨은 `closed` 에만 있다.** `coverage_anchor_failures` 는 행의 종류를 가리지 않지만 상태 토큰이
`closed` 가 아니면 `continue` 한다:

```python
m = LEDGER_ROW_RE.match(body)
if not m or m.group(2).strip() != "closed":
    continue
key, evidence = m.group(1).strip(), m.group(3)
cited = ANCHOR_RE.findall(evidence)
if not cited:
    fails.append(f"{key} evidence cites no S<N> anchor")
```

그리고 `coverage_ledger_failures` 는 derived 행의 **이름·닫힘·근거를 검사하지 않고 행 수만 센다**.
라운드 1 이 이 둘의 합성 결과를 실측했다 — `- derived:unrelated-ui — open — ` 한 줄이 두 함수를
모두 통과했다(`0bbd91d3#r1.1`). 따라서 하한은 「행이 하나 있는가」가 아니라 **셋 전부**여야 한다:

> 레포 주장(`RC<n>`)이 ≥1 인 payload 는 audit §1 에 `derived:internal_research` 라는 **이름의** 행이
> 있고 그 행의 상태가 **`closed`** 여야 한다.

`closed` 를 요구하면 `coverage_anchor_failures` 가 그 행의 evidence 에서 실재하는 `S<N>` 앵커를
요구한다. **그 이상은 주장하지 않는다**(라운드 2 `fccf272b#r2.1`) — 같은 함수의 docstring 이
「Form-only: «그 S 가 닫힘을 정당화하는가»는 보지 않는다」이고 `gate()` 가 넘기는 집합은 payload·audit
§6 앵커 전량이므로, `⟨S1⟩` 하나로도 통과한다. 즉 이 검사가 보는 것은 **「앵커 형태의 근거가 적혀
있는가」까지**이고 그 근거가 이 차원을 닫는가는 사람과 리뷰의 몫이다(L9).

이름은 **정확 일치**다(§H ⑤) — 접두 일치로 두면 무관한 차원으로 갈음된다. 레포 주장이 0건이거나
payload 에 `contract: v2` 가 없으면 이 요구가 발동하지 않으므로 `derived: N/A` sentinel 을 쓰는 기존
픽스처는 red 가 되지 않는다(⟨C10⟩ · §H ⑥).

### §D 자리 4 — 검문소 셋과 인계

라운드 1 이 검문소의 시점을 반증했다 — `finishing.md` Step A 는 floor 5 가 **전부 닫힌 뒤**에만
읽히므로(`SKILL.md`: 「읽어야 하는 조건: `coverage.floor` 의 다섯 차원이 모두 `status: closed`」)
거기서만 확인하면 반증이 마지막 라운드 «후»에 나오고 방향에 영향 줄 라운드가 없다. Goal ⟨C11⟩ 을
정면으로 못 맞춘다. 그래서 검문소를 **셋**으로 가른다.

| # | 자리 | 언제 | 무엇 | 종속 |
|---|---|---|---|---|
| **V1** | 라운드 규약(`SKILL.md`) | 주장을 «지금 이해»에 싣기 **전** | 항목마다 ① 경로 실재 ② 앵커 실재 ③ **주장이 그 자리와 맞는가**(구현을 읽는다) ④ 결과 ∈ {확인, 반증, 미확인} | **없음** |
| **V2** | `finishing.md` Step A | 종료 직전, 무조건 | payload 의 모든 `RC<n>` 에 대응하는 확인 줄이 audit 에 있는가 — **누락 대조**만 한다 | **없음** |
| **V3** | `check_brief.py` | 게이트 | 형태 ∀ (§E) | **없음** |

V1 이 steelman 의 Step 2 를 조사 전체로 일반화한 것이고, **steelman 은 자기 Step 2 를 그대로
유지한다**(락이 그 문면을 요구하고 Step 2.5 가 그 결과를 즉시 소비한다). 즉 steelman 경로는 두 번
**확인**하지 않는다 — Step 2 가 V1 의 특수 경우다.

**단 기록은 두 곳이다**(라운드 2 `db9a48da#r2.1`). 출하된 Step 2 는 결과를 audit §3 의 `#### ST<N>`
블록에 남기고, §E ⑤ 는 audit §5 에서 `확인 RC<n>` 줄을 찾는다. 그대로 두면 steelman 이 낸
`repo_claims` 가 ⑤ 에서 red 다. 해소: **§3 의 per-claim 줄은 그대로 남기고, 같은 판정을 §5 에
`확인 RC<n> — …` 한 줄로 함께 적는다.** 확인 «행위»는 한 번이고 기록만 두 자리다 — §3 은 steelman
4-block 의 소비자가 읽는 자리이고 §5 는 게이트가 읽는 자리다. 이 중복은 `## 알려진 한계` L10 에
대가로 적는다.

**확인 줄의 거처**(라운드 1 `8891bd29#r1.2`) — audit `## 5. 프로세스 로그`. `AUDIT_SECTIONS` 가
이미 요구하는 절이라 **무조건 존재하고** 새 절을 만들지 않는다(⟨C10⟩ · 압축 규약). 형식:

```
- 확인 RC3 — 확인 — plugins/spec-distill/scripts/check_brief.py#coverage_anchor_failures — 주장과 일치
- 확인 R4 — 반증 — <경로>#<앵커> — 그 자리는 <실제>이고 주장은 <주장>이었다
- 확인 R5 — 미확인 — <경로>#<앵커> — <왜 확정하지 못했는가>
```

`미확인` 은 라벨로 **보인다** — 조용히 흡수하지 않는다(출하된 Step 2 규약 그대로).

**반증의 소비 경로(최소 형태).** V1 의 판정이 `반증` 이면 그 항목이 닿는 확정을 payload §5 에
*원래 / 재결정 / 근거* 세 칸으로 남긴다. **재결정 자체는 사용자 동의로만 한다**(P23) — 이 규약은
기록 형식이고 판정 권한이 아니다. V1 이 라운드 «안»이므로 반증이 나온 라운드에서 그 차원을
재개방할 수 있고, 그것이 §F ② 의 예산을 늘려 다시 조사할 연료가 된다. 이것이 ⟨C11⟩ 의 「조사가
방향에 영향」이 실제로 발화하는 경로다.

**인계 — 「읽을 이유」까지.** ⟨D1.2⟩ 가 인계 축의 대상을 `/compact` 보존 목록에서 **하류가 그 절을
읽을 이유**로 옮겼다. 근거: 하류는 brief **파일 경로**를 받으므로 §5 를 포함한 전문을 읽을 수 있고,
반대로 보존 목록은 사람이 복사하는 산문이라 고쳐도 도달이 강제되지 않으며 옵션 ②(「compact 없이,
전체 context 유지」) 경로에는 목록이 적용조차 되지 않는다.

세 방향이고 **셋 다 같은 id 로 맞물린다** — 이것이 라운드 1 이 요구한 교차 술어의 재료다:

- **결정 연결 (§4 · §5 → 결정)** — 조사 항목 줄 **끝**에 `[RC3 → OQ1]`(레포) 또는 `[→ OQ1]`(웹).
  레포 항목의 `RC<n>` 이 audit 확인 줄과 맞물리는 id 이고, 웹 항목은 기존 `«출처키»` 가 그 역할을
  이미 한다(N2 가 audit §7 에 결속).
- **역참조 (§3 → 근거)** — OQ 줄이 그 근거의 **id** 를 포함한다: `→ 근거 RC3`. §3 항목은 **그 자체가
  열린 결정**이라 연결의 *대상*이고 출처가 아니다 — 거기에 `[→ OQ<n>]` 을 걸면 자기지시가 되어
  술어가 공허해진다.
- **요약 상호참조 (§0 → 근거)** — 「한눈에」의 결정 목록도 같은 id 를 쓴다.

**해결된 결정의 보존**(라운드 1 `4ceba241#r1.1`). 조사 당시 열려 있던 `OQ1` 이 사용자 답으로
해결되면 그 조사는 ⟨C11⟩ 의 성공 사례인데, 열린 목록에서 빠지면 §E ② 의 실재 검사가 red 가 된다.
성공을 red 로 만드는 것은 Goal 의 반전이다. 그래서:

> §0 의 결정 목록은 **해결된 것도 남기고** 상태 토큰을 붙인다 —
> `OQ1 [해결 ⟨S10⟩] — 면제 상한 → 근거 RC3`. 「열림」은 상태 토큰이 말하고 목록에서의 부재가 말하지
> 않는다. §E ② 의 실재 검사는 **목록에 있는가**만 보고 상태는 보지 않는다(L3).

`[해결 …]` 이 붙은 결정은 §3 Open Questions 에서 빠지고 §0 에만 남는다 — §3 은 미해결의 목록이다.

**§2 는 대상이 아니다** — 근거가 사용자 발화(`evidence: S<N>`)이고 ✎ 블록은 `bijection_b_errors`
(§2 본문 ↔ frontmatter)의 대상 밖이라, 거기에 새 술어를 걸면 그 bijection 과 이음매가 생긴다.

하류가 보는 것은 「OQ1 을 정하려면 RC3 를 읽어야 한다」다. **하류에 건 지시는 없다** — X2 가 그렇게
정했고, 구속 문구는 «Sealed decision» 을 관로화하고 P23 과 충돌한다.

### §E 자리 5 — 게이트

`scripts/check_brief.py` 에 술어 다섯 + advisory 하나. **차단 판정에 개수를 쓰지 않는다.**

**「조사 항목」의 기계적 정의**(라운드 1 `bf15a523#r1.2`) — 순회 대상은 이것뿐이다:

- payload §4 의 모든 항목 줄(프로필상 전부 landscape 다)
- payload §5 의 항목 줄 중 **`RC<n>` 리터럴을 가진 줄**

§5 의 `기각`·`보류`·`검토`·`위험` 네 모양 중 어느 것인지는 묻지 않는다 — `RC<n>` 이 있으면 레포
주장을 실은 줄이고 없으면 아니다. 그래서 기존 코퍼스·픽스처의 위험 항목은 대상 밖이다
(⟨C10⟩ · Verification 7). **§3 은 순회 범위에 없다** — 연결의 대상이기 때문이다.

**위치는 줄 끝**(라운드 1 `bf15a523#r1.1`). 하위 불릿은 금지한다 — `ENTRY_BULLET_RE`(`^\s*[-*]\s`)가
들여쓴 불릿도 §4 항목으로 세므로 하위 불릿 형태는 즉시 `unkeyed landscape entries` red 가 된다.

**다섯 술어 전부 payload frontmatter 의 `contract: v2` 를 발동 조건으로 갖는다**(§H ⑥) — 없으면
전부 미발동이고 advisory 한 줄이 나간다. 기존 픽스처 81개가 무변경으로 통과하는 근거가 이것이다.

| # | 검사 | 술어 | 발동 조건 · 0건일 때 |
|---|---|---|---|
| ① | 연결 ∀ | 위 정의의 조사 항목마다 `[RC<n> → OQ<n>]` · `[→ OQ<n>]` · **`[→ 없음]`** 중 하나가 줄 끝에 | `contract: v2` 없거나 항목 0건이면 공허 통과 |
| ② | 연결 대상 실재 | 그 `OQ<n>` 이 payload §3 또는 §0 의 결정 목록에 실재 (`[→ 없음]` 은 대상 아님) | 연결 0건이면 공허 통과 |
| ③ | 역참조 ∀ | 연결에 쓰인 `RC<n>` 이 그 `OQ<n>` 줄 **전부**에 되나타난다(§3·§0 양쪽 — ∃ 아님) | 같음 |
| ④ | 이름 정확 일치 derived (조건부) | `RC<n>` ≥1 이면 audit §1 에 **정확히** `derived:internal_research` 행이 있고 상태가 `closed` | `RC<n>` 0건이면 요구 미발동 — sentinel 통과 |
| ⑤ | 확인 줄 ∀ | payload 의 모든 `RC<n>` 마다 audit §5 에 `확인 RC<n> — {확인\|반증\|미확인} — …` 줄 | `RC<n>` 0건이면 공허 통과 |
| advisory | — | `RC<n>` 0건이면 「내부 조사 0건」 · `contract: v2` 부재면 「신 계약 미적용 brief」 | — |

③ 을 ∀ 로 둔 것이 라운드 2 `e361710c#r2.1` 의 답이다 — 단수·∃ 로 두면 §0 줄 하나로 만족돼 §3 의
`→ 근거 RC3` 를 지워도 통과하고, 라운드 1 이 지목한 구멍이 자리만 옮겨 남는다.

`[→ 없음]` sentinel 이 라운드 2 `0fa0a9b6#r2.1`·`c9126d7c#r2.1` 의 답이다 — §A 계약이 「빈 배열은
허용이고 거짓 연결보다 낫다」를 못 박으므로 sentinel 없는 ∀ 는 그 계약과 충돌하고 「필러 절」 압력을
만든다. 「없음」의 **개수는 세지 않는다**(⟨C5⟩).

③ 이 라운드 1 `e361710c#r1.2` 의 답이다. 원래 AC9 는 「`OQ<n>` 이 §3·§0 에 실재하는가」만 봤고
그것으로 §3 역참조가 닫힌다고 적었는데 **거짓이었다** — §3 의 `→ 근거 RC3` 를 지워도 통과한다.
③ 은 방향을 뒤집어 **`OQ<n>` 줄이 그 근거 id 를 포함하는가**를 보므로 역참조의 삭제가 red 가 된다.

⑤ 가 `e361710c#r1.1` 의 답이다. 두 파일을 잇는 것은 `RC<n>` 이고, 이것은 이 게이트의 기존 교차 술어
계열과 같은 모양이다 — `«출처키»`↔audit §7(`landscape_keys_declared`) · `ST<N>`↔audit §3
(`bijection A`) · `S<N>`↔§6(`bijection C`). 전부 id 로 맞물린다.

**①③⑤ 가 ⟨C5⟩ 와 양립하는 이유**는 `landscape_unkeyed` 가 §4 에 대해 이미 하는 것과 같다:

> #13 — §4 항목마다 «출처키»가 있는가. **∀다** … web-off brief는 §4에 순회할 항목이 없어 공허하게
> 통과하는 것이 옳다 — 조사하지 않았으면 인용할 것도 없다.

**④ 의 조건부**도 이 파일의 관습이다. `landscape_keys_declared`:

> **조건부다.** 「audit §7이 비어 있지 않다」로 두면 갓 만든 audit도 웹이 꺼진 audit도 red가 된다.
> payload가 landscape를 실었다는 사실을 조건으로 건다 — 키가 없으면 공집합 ⊆ 무엇이든으로 자동
> 만족되므로 kill switch 코드가 필요 없다.

조건을 산출물에 두는 대가는 `## 알려진 한계` L1 에 적는다.

**advisory 의 배달지** — `gate()` 의 `advisories` 채널이고, `finishing.md` Step B 가 그것을 proceed
게이트 `question` 본문에 싣는다(이미 `coverage-mapper 0 (unavailable: …)` 이 쓰는 자리). 침묵과 0 은
다른 사실이다.

### §F 동역학 — 자격 · 예산 · 면제

라운드 1 이 셋을 잡았다: 예산만으로는 ⟨C12⟩ 의 재개 조건을 구현하지 못하고(`5cc29851#r1.2`),
면제의 판정 근거인 «이미 닿은 결정 집합»에 **산출자가 없고**(`ab77284c#r1.1`), ⟨C13⟩ 을 좁힌 것이
기록되지 않았다(`5cc29851#r1.1`).

**① 호출 자격 — ⟨C12⟩ 문면 그대로.** dispatch 의 «자격»은 재개방이 아니라 결정의 열림에서 도출한다:

> 조사 장치를 다시 부를 자격은 **그 장치가 채우는 차원에 닿는 열린 결정이 아직 있는가**다.
> 그 차원의 열린 결정이 0이면 자격이 없다 — 예산이 남아도 부르지 않는다.

**② 예산 — 자격 위의 상한.** 자격만 두면 상한이 없으므로 그 위에 재개방의 함수인 상한을 얹는다:

| 장치 | 지금 | 바뀜 |
|---|---|---|
| `blind-spot-prober` | 인터뷰당 하드 1회 (`blind_spot_dispatched: bool`) | 자격 충족 시 `blind_spot_dispatches < 1 + coverage.floor.blind_spot.reopened` |
| `coverage-mapper` | 상한 2 (R1 전 1 + 재개방 시 ≤1) | 자격 충족 시 `coverage_mapper_dispatches < 1 + Σ(모든 차원의 reopened)` |
| `steelman-builder` | 방향당 1회 · 새 근거 있으면 재호출 | **불변** — 이미 근거-발동이라 같은 원리다 |

무한 루프가 아닌 근거는 `SKILL.md` 가 재개방에 상한을 두지 않을 때 쓴 것과 같다: 「상한 없음 —
라운드는 사용자 답으로만 돌아 **사용자가 시계다**」. 재개방은 정의상 「새 답·외부 근거·코드 사실이
그 차원의 닫힘 근거 S 와 충돌」해야 일어나고, 그 기록에 `conflicts_with: S<N>` 이 남아 게이트가
앵커 실재를 검사한다. 그리고 V1 이 라운드 «안»이므로 반증이 재개방을 낳는 경로가 실제로 돈다.

**③ 면제 — 산출자를 둔다.** state `orchestration` 에 키 하나를 더한다:

거처는 §H ② 가 정한 `orchestration.open_decisions[]` 하나이고 면제의 입력은 그 안의 `touched`
필드다 — 별 키를 두지 않는다(라운드 1 이 요구한 `touched_decisions` 를 흡수했다).

- **산출자**: orchestrator. 라운드 안에서 조사 산출을 «지금 이해»에 실을 때 그 산출의 `decides`
  원소의 `touched` 를 `true` 로 올린다. **순서는 «계수 먼저, 표시 나중»이다** — 라운드 2 가 반대
  순서의 결함을 잡았다(`720d4cf6#r2.1`): 먼저 표시하면 계수 시점에 「아직 안 닿은 것」이 항상
  공집합이라 **첫 연결부터 +1** 이 되고 면제가 영구히 발화하지 않는다. 그러면 ⟨C13⟩ 재결정의
  유한화 논거(「첫 연결은 +0, 두 번째부터 +1」)가 함께 무너진다.
- **소비자**: C44 계수 규칙. 면제 조건:

  > 산출 항목의 `decides` 가 **`status: open` 이고 `touched: false` 인 결정**을 하나라도 담으면
  > `non_user_streak` +0. 그렇지 않으면 +1. 그 계수 **뒤에** 그 원소들의 `touched` 를 `true` 로
  > 올린다. 열린 결정이 0이면 면제도 0이다.

- **초기화**: 없다. `touched` 는 단방향이고 재개방으로도 되돌리지 않는다 — 되돌리면 면제가
  무한해진다. 그 결정이 `status: resolved` 로 바뀌면 열린 집합에서 빠지므로 면제 후보에서도 빠진다.

그러면 면제 예산이 `|{status: open, touched: false}|` 이 되어 **유한**하다. 이 상한은 열린 결정
집합이 줄어드는 데 **의존하지 않는다** — 줄지 않아도 같은 결정의 두 번째 연결이 면제되지 않으므로
예산이 고갈된다. brief OQ19 가 지적한 「무한 면제가 임계 상향보다 강한 약화」는 이로써 해소되고
brief §5 의 임계값 상향 기각 이유(AP16 가드 직접 약화 · 임계치 완화는 보안-민감 편집)는 유지된다.

이 회계는 brief §4 의 «voi-analysis»(「결정을 바꿀 수 있는 정보만 값이 있다」)와
«decision-quality-chain»(「정보만 늘리면 상한이 안 움직인다」)이 처방한 것과 같다.

**④ 상태 스키마와 migration**(라운드 1 `868705ff#r1.1`). `blind_spot_dispatched: bool` →
`blind_spot_dispatches: int` 는 **개명**이라 「부재 키만 기본값으로 채운다」로는 이미 dispatch 한
세션이 `0` 을 받아 AP16 가드가 재무장된다. 그래서 `references/state-migration.md` 에 **이월 규칙**을
적는다:

- `blind_spot_dispatched: true` 가 있으면 `blind_spot_dispatches: 1` 로 이월한다. `false` 면 `0`.
- 이월 후 옛 키 `blind_spot_dispatched` 를 **지운다** — 같은 파일이 `rereview_count`·`issue_history`
  를 「승계하지 않고 지운다」로 옛 키 제거의 선례를 이미 갖는다.
- `open_decisions` 는 부재 시 `[]` — 기본값 채우기의 정상 경로다.

### §G 데이터 흐름 한 장

```
seed «다시 검증할 것»  ─┐
                        ├─→ coverage-mapper ─┐
사용자 답 (라운드)      ─┤                    │   슬롯 둘:
landscape sweep         ─┼─→ blind-spot-prober┤   <claims_contract> (내용)
                        │                    │   <open_decisions>  (OQ<n> 목록)
                        ├─→ steelman-builder ─┤
C43 경로 (a) 자동확인  ──┴────────────────────┘   ← 웹 스위치 무관 · 내부 축 주 생산자
        (+ 기본 탑재 Explore 배선)              │
                                                ▼
                           evidence[] / repo_claims[]
                           touches: [P<n>]  (전제 — 불변)
                           decides: [OQ<n>]  (★신설)
                           id: RC<n>         (★신설, 레포만)
                                                │
                    ┌───────────────────────────┘
                    ▼
        V1 — 라운드 규약 안, 무조건 (SKILL.md)
          경로 → 앵커 → 「그 자리가 주장과 맞는가」(구현을 읽는다)
          {확인 | 반증 | 미확인} → audit §5 프로세스 로그에 `확인 RC<n> — …`
          `반증` → §5 에 *원래/재결정/근거* + 그 차원 재개방 가능
                    │                              │
                    │                              └→ 재개방이 §F ② 예산을 늘린다 → 다시 조사
                    ▼
        payload §4 · §5 항목 줄 끝  [RC3 → OQ1] / [→ OQ1]
        payload §3 OQ               → 근거 RC3
        payload §0 결정 목록        OQ1 [열림|해결 ⟨S10⟩] — … → 근거 RC3
        audit  §1 derived:internal_research — closed — ⟨S<N>⟩
        audit  §5 확인 RC3 — 확인 — <경로>#<앵커> — …
                    │
                    ▼
        V2 — finishing.md Step A, 무조건 : RC<n> 누락 대조
                    │
                    ▼
        V3 — check_brief.py (fail-closed)
          ① 연결 ∀  ② 연결 대상 실재  ③ 역참조  ④ 이름 있는 derived(조건부)  ⑤ 확인 줄 ∀
          RC<n> 0건 → advisory → Step B 게이트 question 본문
                    │
                    ▼
        brainstorming (읽을 이유는 있고 구속은 없다)
```

## Acceptance Criteria

- **AC1** `references/research-claims.md` 가 실재하고 `evidence[]`·`repo_claims[]` 두 모양의 계약
  **정본**을 담으며 신설 필드 `decides`(둘 다)와 `id: RC<n>`(레포만)을 포함한다.
  `agents/steelman-builder.md` 의 인라인 블록은 **유지**된다(락이 그 파일에서 요구).
- **AC2** 조사 dispatch **셋**이 전부 `<claims_contract>${CLAIMS_CONTRACT}</claims_contract>` 와
  `<open_decisions>${OPEN_DECISIONS}</open_decisions>` 두 슬롯을 갖는다. 자리는
  `conducting-interview/SKILL.md` **둘**(coverage-mapper · blind-spot-prober)과
  `references/steelman.md` **하나**(steelman-builder)다.
- **AC3** `SKILL.md` 안에 `$CLAIMS_CONTRACT` 를 `cat` 으로 채우는 펜스가
  `<!-- claims-contract:begin -->`·`<!-- claims-contract:end -->` 마커 사이에 있고, 실패 분기가
  「dispatch 하지 않는다」를 말하며 rc 1 로 끝난다.
- **AC4** 세 agent 파일의 `input_slots` 에 `claims_contract`·`open_decisions` 항목이 있고 각각
  `kind:` 를 선언한다(미지정이면 `tools/adjudication/check_slots.py` 가 `no_kind` 로 red).
- **AC5** `research-claims.md` 가 「인덱스·레지스트리·목차·description 필드만 읽고 판정하지 말 것.
  구현을 읽어라」를 담고 그 출처
  (`docs/archive/interview/2026-07-12-project-init-audit-interview.md`)를 인용한다.
- **AC6** `SKILL.md` 라운드 규약에 **V1** 이 있다 — 주장을 «지금 이해»에 싣기 전에 ① 경로 실재
  ② 앵커 실재 ③ 주장이 그 자리와 맞는가 ④ 결과 {확인, 반증, 미확인} ⑤ audit §5 에 `확인 RC<n> — …`
  한 줄. **steelman trigger 와 `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 어느 것에도 종속되지 않음**을 명시.
- **AC7** `finishing.md` 에 **V2**(payload 의 `RC<n>` 누락 대조)가 있고, V1 판정이 `반증` 일 때
  그 항목이 닿는 확정을 payload §5 에 *원래 / 재결정 / 근거* 세 칸으로 남기며 **재결정은 사용자
  동의로만** 함을 적는다.
- **AC8** `check_brief.py gate` 가 §E 표의 ①②③⑤ 를 ∀ 로 요구하고 **차단 판정에 개수 술어를
  갖지 않는다** — 조사 항목 0건 fixture 가 이 검사들로 red 가 되지 않는다.
- **AC9** 「조사 항목」의 순회 정의가 코드 주석과 이 설계에 같은 문면으로 있다 — §4 의 모든 항목 줄 +
  §5 에서 `RC<n>` 리터럴을 가진 줄, §3 제외. 연결 위치는 **줄 끝**이고 하위 불릿은 red 다.
- **AC10** `RC<n>` ≥1 이면 audit §1 에 `derived:internal_research` 행이 있고 상태가 `closed` 여야
  한다. **이름이 다른 derived 행이나 `open` 행으로는 만족되지 않는다.** `RC<n>` 0건이면
  `derived: N/A` sentinel 로 통과한다.
- **AC11** `RC<n>` 0건이면 `gate()` 의 `advisories` 에 「내부 조사 0건」 한 줄이 실리고
  `finishing.md` Step B 가 그 줄을 proceed 게이트 `question` 본문에 싣는다고 적는다.
- **AC12** payload 의 모든 `RC<n>` 에 대응하는 `확인 RC<n> — {확인|반증|미확인} — …` 줄이 audit §5 에
  없으면 red. 웹 주장은 이 검사 대상이 아니다(N2 가 audit §7 결속을 이미 본다).
- **AC13** `SKILL.md` 가 dispatch **자격**(그 차원에 닿는 열린 결정이 있는가)과 **예산**
  (`1 + 재개방`)을 둘 다 적고, state 스키마가 `blind_spot_dispatches`(int)·`touched_decisions`(list)를
  갖고, `state-migration.md` 가 `blind_spot_dispatched: true → 1` 이월 + 옛 키 삭제 +
  `touched_decisions` 기본값 `[]` 를 적는다.
- **AC14** `SKILL.md` C44 절이 면제 규칙을 「`decides` 가 열린 결정 중 `touched_decisions` 에 없는
  것을 담으면 +0 · 그렇지 않으면 +1 · 열린 결정 0이면 면제 0」으로 적고, `touched_decisions` 의
  **산출자가 orchestrator 이고 append 가 계수보다 앞**임을 명시한다.
- **AC15** C43 경로 (a) 행에서 리터럴 `[from-code][auto-confirmed]` 가 제거되고 계약 산출로
  교체된다. `plugins/` 하위에 그 리터럴 잔존 0건(`docs/archive/` 는 이력이라 대상 아님).
- **AC16** 새 락 `tests/test_research_claims_contract.sh` 가 **다섯 축**을 갖는다 —
  A 산문 body-unique 문구 · B 양의 짝(슬롯 개수: SKILL.md 2 + steelman.md 1) · C 펜스가
  `<!-- claims-contract:begin/end -->` 마커 사이에서 `cat` 하고 실패 분기 rc 1 ·
  X 차가운 셸에서 그 마커로 잘라낸 펜스를 실행(실제 루트면 stdout 이 계약 내용, 계약 없는 루트면
  rc 1 + 빈 stdout) · **D 정합**(정본의 필드 이름 집합과 steelman-builder 사본의 것이 **집합 등호**).
  ⊇ 와 「사본에 정본에 없는 필드 없음」은 같은 명제라 사본이 `decides`·`id` 를 빠뜨려도 green 이고,
  그 방향이 바로 축 D 의 근거로 인용한 「한쪽만 고치는」 결함이다(라운드 2 `49ed4d39#r2.1`).
  그래서 AC1 이 사본에도 두 필드를 요구하고 `test_steelman_builder_scope.sh` 의 키 앵커 목록에
  `decides`·`id` 를 더한다.
- **AC17** `.claude-plugin/plugin.json` 이 `4.3.0` 이고 `CHANGELOG.md` 에 해당 항목이 있고
  `tests/test_readme_sync.sh` 가 green 이다 — 착수 뒤 main 이 4.2.1 로 움직여 minor 를 다시 셈.
- **AC18** 착수 전 baseline 대비 새 RED 0 — rc 뿐 아니라 **실패 줄 수**까지 대조한다. 특히
  `test_steelman_builder_scope.sh` 와 `test_conducting_interview_stage.sh` 가 green 을 유지한다.
- **AC19** `templates/interview-brief-template.md` 가 세 방향을 예시로 보인다 — §4·§5 의
  `[RC3 → OQ1]`/`[→ OQ1]` 줄 끝 연결 · §3 OQ 의 `→ 근거 RC3` 역참조 · §0 의
  `OQ1 [열림|해결 ⟨S10⟩] — … → 근거 RC3`. `templates/interview-audit-template.md` 가 §1 의
  `derived:internal_research` 행과 §5 의 `확인 RC<n> — …` 줄을 예시로 보인다. 두 템플릿의 예시가 곧
  AC8·AC10·AC12 의 green fixture 와 같은 모양이어야 한다 — 템플릿이 red 를 가르치면 첫 게이트가
  항상 red 다(이 플러그인이 sentinel 에서 이미 겪은 결함).
- **AC20** D6(검증 축)의 집행 손잡이 — `SKILL.md` 의 coverage-mapper 첫 dispatch 절이, seed 의
  «다시 검증할 것» 문단 중 **레포로 확인 가능한 항목마다** `repo_claims` 를 산출해 V1 을 태울 의무를
  적는다. 「사용자만 답할 수 있는 것」·「인과 추정」은 대상이 아니다(라운드 2 `0b618227#r2.1` — 이
  사이클 seed 의 그 문단 여섯 항목 중 레포 대상은 둘뿐이었다). 그 문단이 비었으면(규약 위반 seed —
  `SKILL.md` 슬롯 주석이 명시 허용) 이 의무는 미발동이고 그 사실을 audit §5 에 한 줄로 공시한다.
  Phase 0(`framing-requests`)은 건드리지 않는다(⟨C4⟩) — 의무는 받는 쪽에 있다.
- **AC21** `## 결정 기록` 의 이 문서 결정은 `X<n>` 접두를 쓰고 리뷰 엔진의 `D<n>.<m>` 과 섞이지
  않는다.
- **AC22** 세 dispatch 자리의 처분 줄이 **괄호 없는** `fail-closed` 서식이고, agent 파일 둘의 옛
  상한 문구가 **여섯 자리 전부** 자격+예산 서술로 갱신된다 — 라운드 2 가 제 열거가 전수가 아님을
  잡았다(`7b7d0951#r2.1` + 재비판의 추가 관측):
  `blind-spot-prober.md` 의 frontmatter description · 본문 「**fan-out 1**: 인터뷰당 1회 dispatch」 ·
  「재dispatch 금지 — fan-out 1」 · `coverage-mapper.md` 의 frontmatter description
  (`dispatch is bounded to two per interview`) · H1 제목 「(상한 2 dispatch …)」 · 본문
  「**bounded dispatch**: … 상한 2」. 착수 시 `grep` 으로 전수를 재도출하고 이 열거를 신뢰하지 않는다.
- **AC23** payload frontmatter 에 `contract: v2` 가 있을 때만 §E 의 다섯 술어가 발동하고, 없으면
  `advisories` 에 「신 계약 미적용 brief」 한 줄이 실린다. `templates/interview-brief-template.md` 가
  그 필드를 넣는다(§H ⑥).
- **AC24** dispatch 자리는 **셋**이다 — 네 번째 자리(기본 탑재 subagent 배선)를 만들지 않고 경로 (a)
  는 orchestrator 가 직접 수행한다. `shared/tests/test_dispatch_disposition.sh` 의 「앵커 수 ==
  dispatch 수」 단언이 green 을 유지한다.

## Files to Modify

| 파일 | 변경 |
|---|---|
| `plugins/spec-distill/references/research-claims.md` | **신규** — 계약 정본 (§A) |
| `plugins/spec-distill/agents/steelman-builder.md` | 인라인 블록 **유지** + `decides`·`id` 추가 · `input_slots` 둘 추가(각각 `kind:`) |
| `plugins/spec-distill/agents/coverage-mapper.md` | 슬롯 둘 + 출력 의무 · **본문 `bounded dispatch: … 상한 2` 문구를 자격+예산으로 갱신** |
| `plugins/spec-distill/agents/blind-spot-prober.md` | 슬롯 둘 + 출력 의무 · **본문 `fan-out 1: 인터뷰당 1회 dispatch(C8)`·`재dispatch 금지 — fan-out 1` 두 문구를 자격+예산으로 갱신** |
| `plugins/spec-distill/skills/conducting-interview/SKILL.md` | 계약 `cat` 펜스(마커 포함) · dispatch 둘의 슬롯 · V1 · C43 (a) · C44 계수 · 자격·예산 · state 스키마 둘 · coverage-mapper 첫 dispatch 의 AC20 의무 · **dispatch 처분 줄 둘의 `fail-open`→`fail-closed`** |
| `.../conducting-interview/references/finishing.md` | V2 · 반증 기록 · 연결·역참조·§0 상태 토큰 · Step B advisory 배달 |
| `.../conducting-interview/references/steelman.md` | dispatch 슬롯 둘 추가 · **Step 2 는 그대로 유지**(중복 제거 안 함) · **처분 줄의 `fail-open`→`fail-closed`** |
| `.../conducting-interview/references/state-migration.md` | `blind_spot_dispatched: true → 1` 이월 + 옛 키 삭제 + `touched_decisions` 기본값 |
| `plugins/spec-distill/templates/interview-brief-template.md` | 세 방향 예시 + frontmatter `contract: v2` (AC19·AC23) |
| `plugins/spec-distill/templates/interview-audit-template.md` | §1 `derived:internal_research` · §5 `확인 RC<n>` 예시 (AC19) |
| `plugins/spec-distill/scripts/check_brief.py` | 술어 다섯 + `contract: v2` 옵트인 분기 + advisory 둘 + 「조사 항목」 정의 주석 (§E·§H ⑥) |
| `plugins/spec-distill/tests/test_research_claims_contract.sh` | **신규** 락 · 다섯 축 (AC16) · `# guards:` 선언 + `--emit-scanned`(형제 다수의 관습) |
| `plugins/spec-distill/tests/test_check_brief.sh` + `tests/fixtures/` | AC8–AC12 red/green 짝 |
| `plugins/spec-distill/tests/test_brief_agents.sh` · `test_steelman_builder_scope.sh` · `test_conducting_interview_stage.sh` | 새 슬롯·문구를 반영해 **확장**(기존 단언은 유지 — AC18) |
| `tools/adjudication/` | 새 슬롯의 `kind:` 가 `orchestrator_framing` 이면 `EXEMPT_SLOTS_BASELINE`(현재 5) bump 필요 여부를 착수 시 확인 |
| `plugins/spec-distill/.claude-plugin/plugin.json` | `4.2.1` → `4.3.0` (minor = 새 surface — 착수 뒤 main 이 4.2.1 로 움직여 minor 를 다시 셈) |
| `plugins/spec-distill/CHANGELOG.md`, `README.md` | 항목 + Principles Instantiated |

## Verification Plan

1. **baseline 먼저** — 착수 전 전체 스위트를 돌려 rc 와 **파일별 실패 줄 수**를 기록한다. rc 만
   잡으면 이미 RED 인 파일 안의 새 실패가 원리적으로 안 보인다.
2. **새 락의 다섯 축** — AC16. `tests/test_dispatch_profile_inline.sh` 의 구조를 상속한다(그 락이
   같은 문제 — 「dispatch 슬롯에 경로가 아니라 내용을」 — 을 이미 네 축으로 잰다). **X 축이
   성립하려면 락이 펜스를 결정적으로 잘라낼 수 있어야 하므로 `<!-- claims-contract:begin/end -->`
   마커를 요구한다**(선례가 `<!-- profile-content:begin/end -->` 를 쓰는 것과 같은 이유 —
   라운드 1 `4af48fd0#r1.1`). 다섯째 축 D(정본↔사본 정합)는 이 설계가 사본을 남기기로 했기 때문에
   추가된 것이다.
3. **게이트 술어의 red/green 짝** — AC8–AC12 각각 red fixture 와 green fixture 를 둘 다 만든다.
   부재 락은 양의 짝이 없으면 통째로 삭제해도 통과한다. ④ 는 **red 셋**이 필요하다 — 행 부재 ·
   이름 다름 · `open` 상태.
4. **변이(mutation)** — 네 축으로 흔든다: 표기 · 값 · 위치 · **제약의 부정형**. 열거로 축을 만들면
   내 mutation 이 락의 전제를 공유한다. `PYTHONDONTWRITEBYTECODE=1`(같은 길이 변이는 stale `.pyc`
   를 못 넘어 거짓 GREEN·거짓 RED 둘 다 낸다).
5. **양성 대조** — 변이 계측기 자체가 고장 날 수 있으므로 반드시 RED 가 나와야 하는 변이 하나를
   먼저 확인한다. 양성 대조 없이는 RED 도 증거가 아니다.
6. **기존 스위트 전량** — `test_check_brief.sh` · `test_conducting_interview_stage.sh` ·
   `test_brief_agents.sh` · `test_steelman_builder_scope.sh` · `test_web_kill_switch.sh` ·
   `test_dispatch_profile_inline.sh` · `test_readme_sync.sh` · `test_stale_terms.sh` ·
   `shared/tests/test_dispatch_disposition.sh` · `tools/adjudication/check_slots.py`.
   python 은 `-m unittest` 로만.
7. **픽스처 회귀 0 을 명시 확인** — 라운드 2 가 실측했다: §4 항목을 가진 payload 픽스처는
   **81개**이고 `interview-brief-valid.md` 는 스위트 다수의 베이스다. `contract: v2` 옵트인(§H ⑥)이
   그 81개를 **한 글자도 고치지 않게** 하는 장치이므로, 검증은 두 방향이다 — (a) `contract: v2` 가
   없는 기존 픽스처 전량이 새 술어 다섯으로 red 가 되지 않는다 (b) `contract: v2` 를 **넣은** 새
   픽스처에서는 다섯이 전부 발동한다. (b) 없이 (a) 만 확인하면 옵트인이 「이빨 0」과 구별되지 않는다.
8. **web-off 세션 실측** — `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` 로 한 사이클을 돌려 내부 축이
   여전히 돌고(경로 (a) 생산자) 웹 축만 강등되는지 확인한다. §B 의 핵심 주장이 이것이다.

### Deferred to plan

- **floor 리터럴 계수 재도출** — 착수 시 재도출하고 파일 밖 기대값으로 고정하지 않는다. 같은 축을
  세 번 재서 세 값이 나왔다(플러그인 범위 · 워크트리 전체 · steelman-builder 의 계수).
- **로드 표면 순증 실측** — 새 reference 1 + 슬롯 둘 + 술어 다섯의 토큰 순증. 격리 설치로 배포
  경로에서 잰다.
- **`EXEMPT_SLOTS_BASELINE` bump 여부** — 새 슬롯의 `kind:` 선택에 달렸다.
- **변이 매트릭스의 구체 항목**과 **픽스처 파일명 목록**.
- **`RC<n>` 번호의 유일성 범위** — 인터뷰 하나 안에서만 유일한지, 코퍼스 전체에서 유일해야 하는지.
- **`fail-closed` 값의 회귀 감지 수단** — 락이 `fail-(open|closed)` 의 **어휘**만 보고 값을
  단언하지 않으므로(그 파일이 「값이 저자 손에 있는 한 축 B 급 이빨은 이 축에서 나오지 않는다」로
  자기공시한다) `fail-closed` 가 조용히 `fail-open` 으로 되돌아가는 것을 잡을 수단을 계획이 정한다
  (라운드 2 `2bf5fff6#r2.1`, defer).
- **e2e 수동 검증** — 실제 `/interview` 한 사이클. 자동화하지 않는다.
| 2bf5fff6#r2.1 | AC22 의 `fail-closed` 값은 어떤 락도 검사하지 않으므로(락은 `open|closed` 어휘만 본다) 값이 조용히 되돌아가는 회귀를 감지할 수단을 계획이 정해야 한다. |

## Rejected Alternatives

- **R1 게이트 단독** — 새 reference 없이 `check_brief.py` 에만 ∀ 술어를 더한다. 기각: 생산 시점
  확인이 없으면 OQ17 의 실패 유형이 그대로 통과한다(폐기된 auto-confirm 범주 4건 중 3건은 근거가
  **실재하는 파일 경로**였고 틀린 것은 「그 자리가 주장과 맞는가」였다).
- **R2 원장 중심** — 내부 조사를 `derived:` 무조건 하한으로 세우고 항목 연결은 advisory 로. 기각:
  `derived: N/A` 를 쓰는 기존 픽스처 다수가 red 가 되어 ⟨C10⟩ 위반이다.
- **R3 조사 장치를 하류에 둔다 (spec-kit 배치)** — brief §4 의 «spec-kit-plan» 은 전용 조사 단계가
  `/plan`(설계) 안에 있고 조사 과제를 상류 spec 의 미해결 unknown 에서 도출한다. 기각: ⟨C1⟩ 이
  「인터뷰 단계가 조사의 책임 주체」로 확정했다. 다만 ⟨C2⟩ 대로 **도출 방식(decision-keying)은
  취한다** — `decides` 가 그것이고 OQ18 의 실질은 이렇게 흡수된다.
- **R4 다섯 중 둘을 연기** — ⟨C8⟩ 을 P23 으로 재결정해 세 자리만. 기각: seed ⟨S1⟩ 이 이 사이클을
  부른 이유가 「2026-09-05 가 절반만 확정하고 끝났다」라 같은 모양의 반복이 된다.
- **R5 새 장치 신설 + 삭제 권한** — 다섯 자리에 새 agent·새 절을 만들고 예산을 맞추려 기존
  장치·제약을 뺀다. 기각: 빼는 대상이 ⟨C3⟩ 이 보호하는 부류(되묻기·문제공간 탐색)다. brief OQ22 가
  정면으로 경고한 경로다.
- **R6 「11 중 5가 0건」을 인과로 쓰기** — 결핍 (a) 를 코퍼스 18로 재측정해 진단을 보강한다.
  기각: 하한을 조건부로 만든 근거는 픽스처 대가(⟨C10⟩)와 ⟨C5⟩ 이고 그 **수가 아니다**. 코퍼스를
  18로 다시 잡아도 설계가 바뀌지 않으므로 재측정의 값이 0이다(OQ21).
- **R7 리터럴 마커 유지** — `[from-code][auto-confirmed]` 를 계약과 함께 둔다. 기각: 같은 행위가
  audit §5 프로세스 로그에 `auto-confirmed:` 라는 다른 표기로 이미 실재해(OQ20) 표기가 둘로
  갈려 있다. 갈라진 사본은 「한쪽만 고치는」 결함을 부른다.
- **R8 하류에 구속 문구** — 기각: P23·금지 패턴 «Sealed decision» 과 정면 충돌하고, 반증 소비
  경로가 아직 최소 형태뿐인 상태에서 구속만 먼저 걸면 OQ12 의 위험을 관로화한다.
- **R9 `touches` 를 결정 키잉으로 전환 + Step 2 중복 제거** — 라운드 1 이전의 이 문서의 설계다.
  기각: 출하된 `touches` 는 전제 `P<n>` 키잉이고 Step 2 대조·Step 2.5 자격·4-block 라벨·audit
  템플릿이 그것에 의존하며, `test_steelman_builder_scope.sh` 와
  `test_conducting_interview_stage.sh` 가 그 키와 문구를 **그 파일에서** 요구해 AC18 과 동시에
  성립하지 않는다. **대가**: 「신설 0」이 깨지고 새 필드 둘 + 정합 락 하나가 생긴다. 그 대가가
  기존 소비 사슬 넷을 재구축하는 것보다 싸다.
- **R10 검문소를 종료 시점에만 둔다** — 라운드 1 이전의 이 문서의 설계다. 기각: `finishing.md` 는
  floor 5 가 전부 닫힌 뒤에만 읽히므로 반증이 마지막 라운드 «후»에 나오고, 그러면 ⟨C11⟩ 의
  「조사가 방향에 영향」이 구조적으로 불가능하다. 선례의 비용은 「틀린 전제의 비용은 한 사이클
  전체다」였다.
- **R11 해결된 결정을 §0 에서 지운다** — 열린 목록을 「지금 열린 것」으로만 유지한다. 기각: 조사가
  결정을 해결하는 데 기여했으면 그것이 ⟨C11⟩ 의 성공 사례인데, 목록에서 빠지면 §E ② 가 그 조사를
  red 로 만든다. 성공을 red 로 만드는 술어는 Goal 의 반전이다. 대신 상태 토큰을 붙여 남긴다.
- **R12 면제를 라운드당 1회로 단순화** — 집합을 들지 않아도 도는 형태. 기각: 유한화의 근거가
  「집합 원소는 한 번만 소비된다」였으므로 그것을 버리면 OQ19 해소 근거를 새로 세워야 하고,
  라운드당 1회는 라운드 수만큼 무한하다.

## Open Questions

**사용자만 답할 수 있고 아직 답이 없다 — 유추 금지.**

- **OQ-A** (brief OQ8) 이 요청을 다시 꺼내게 만든 구체적 사건. Phase 0 의 촉발 질문이 답 없이
  지나갔고 「그때 미완이라 · 조사 질 자체」로만 좁혀졌다.
- **OQ-B** (brief OQ10) 네 국면과 네 축 각각의 구체 사례. 사용자 판단이고 사례는 수집되지 않았다.

**범위 밖이지만 설계를 흔들 수 있다.**

- **OQ-C** (brief OQ11) 첫 사이클 레포에서의 수익률. **부분 해소** — 조건부 발동이 이 문제의 답이기도
  하다: 건질 것이 없는 레포에서는 `RC<n>` 이 0건이고 술어가 공허 통과하며 advisory 만 뜬다. 필수
  필드가 없으므로 brief §5 의 「필러 절」 압력이 구조적으로 사라진다. 남는 것은 그 환경에서
  advisory 가 소음이 되는지의 관측이다.
- **OQ-D** (brief OQ12) 반증 소비 경로의 **해결**은 여전히 범위 밖이다. 이 설계는 기록 형식 + V1 의
  라운드-안 배치까지다(§D). 전진 경로(반증 → 사용자 게이트 → 확정 전이 → 게이트 처분)는 다음
  사이클이다.

## 알려진 한계

- **L1 조건부 발동이 피검자 산출물에 앵커돼 있다.** `RC<n>` 을 0건 내면 ④⑤ 와 advisory 가 발동하지
  않는다. `check_brief.py` 는 brief 파일만 읽으므로(모듈 docstring 의 불변식) 「조사를 했어야
  했는가」를 알 방법이 없다 — 이 방향의 fail-open 은 기계적으로 닫히지 않는다. backstop 은 0건
  advisory 가 Step B 게이트 텍스트로 **사람에게 가는 것**이다.
- **L2 면제 판정은 자기 신고다.** `non_user_streak`·`touched_decisions` 는 세션 state 에만 살고
  게이트는 state 를 읽지 않는다(불변식). brief ⟨D1.3⟩ 이 그 기계 검사 가능성 주장을 이미 철회했다.
  이 설계가 더한 것은 **산출자와 거처**이고, 그 값이 정직한지는 여전히 모델의 자기 신고다. 막는
  것은 열린 결정이 매 라운드 «다음 결정» 블록으로 사용자에게 보이는 것과 brief 리뷰 층 1이다.
- **L3 「열려 있음」은 검사하지 않는다.** ② 는 `OQ<n>` 이 §3·§0 의 목록에 **있는가**만 보고 상태
  토큰(`[열림]`/`[해결 …]`)은 보지 않는다. 해결된 결정에 새 조사를 연결해도 통과한다. 이것은
  의도된 선택이다 — 상태를 보면 해결에 기여한 조사가 red 가 된다(R11).
- **L4 V1 의 3단계는 기계가 대신할 수 없다.** 「주장이 그 자리와 맞는가」는 내용 이해다. V2·V3 가
  보는 것은 「그 확인 줄이 항목마다 있는가」까지다.
- **L5 정본과 사본이 둘 남는다.** `research-claims.md` 와 `steelman-builder.md` 의 인라인 블록.
  락 축 D 가 필드 이름 집합의 포함 관계를 지키지만 **설명 산문의 갈라짐은 못 잡는다.**
- **L6 기존 코퍼스의 줄번호 인용 23건은 그대로 남는다.** 계약은 앞으로의 산출에만 걸린다(X9).
- **L7 로드 표면은 순증한다.** 삭제가 0이므로 새 reference 1 + 슬롯 둘 + 술어 다섯이 그대로
  더해진다. ⟨C8⟩ 이 그 대가를 명시적으로 수용했고 양은 계획 단계가 실측한다.
- **L9 ④ 의 `closed` 요구는 「근거가 적혀 있는가」까지다.** `coverage_anchor_failures` 는 form-only 라
  §6 에 실재하는 아무 `S<N>` 이든 받는다 — `⟨S1⟩` 하나로도 통과한다. 그 앵커가 이 차원을 닫는가는
  사람과 brief 리뷰 층 1의 몫이고, 같은 파일이 그 한계를 자기 docstring 에 이미 공시한다.
- **L10 확인 판정이 두 자리에 기록된다.** steelman 경로는 audit §3(`ST<N>` 블록)과 §5(`확인 RC<n>`)에
  같은 판정을 적는다. 확인 «행위»는 한 번이지만 기록이 둘이라 갈라질 수 있다 — 락 축 D 와 같은
  종류의 위험이고 이 설계는 그것을 기계로 닫지 않는다.
- **L8 이 사이클의 brief 냉독이 하류 결함 둘을 관측했다.** ⟨S2⟩–⟨S12⟩ 앵커를 brief 만 보면 확인할
  수 없고(§6 은 `S1` 만 사는 것이 N1b 규약), 하니스 어휘가 설명 없이 쓰인다. 이 설계의 §D
  상호참조는 첫째를 완화하지 않는다 — 앵커는 audit 에 있고 하류는 audit 경로를 받지 않는다.
  brief OQ15 와 같은 뿌리이고 이 설계는 그것을 해결하지 않는다.

## Concrete Next Action

1. 이 문서를 커밋한다(브랜치 `feature/interview-research-burden`).
2. 리뷰 라운드 2 — `reviewing-spec` 이 이어서 돈다(재리뷰 상한 2, 라운드 1 에서 0 소비).
3. 승인 게이트에서 진행을 고른 뒤 `superpowers:writing-plans`.

## 결정 기록

이 설계 세션에서 사용자가 고른 것(X1–X5)과 orchestrator 가 위임받아 정한 것(X6–X12).
brief §3 의 A 군 10 · D 군 7 은 ⟨S12⟩·⟨D1.5⟩ 가 「설계가 받는다」로 처분한 것이다.
`### 재결정` 이 P23 세 칸이고, 그 뒤의 `D<n>.<m>` 은 리뷰 엔진이 append 한 게이트 채택 기록이다.

| id | 결정 | 출처 |
|---|---|---|
| X1 | 네 축을 **승격·재배치**로 만든다 — 새 agent·새 brief 절·새 floor 키 0, 삭제 0. **단 「신설 0」은 라운드 1 이 반증했다** — 새 필드 2 · state 키 2 · 파일 2 가 생긴다(`### 회계`) | 사용자 (OQ22) + 라운드 1 정정 |
| X2 | 인계는 **읽을 이유까지만** — 연결·역참조. 하류 구속 문구 없음 | 사용자 (OQ9) |
| X3 | derived 하한은 **조건부** · `RC<n>` 0건은 **advisory** 로만 공시 | 사용자 (OQ2·L1) |
| X4 | dispatch **예산** = `1 + 재개방` 을 두 장치에 적용. **2026-07-20 coverage-driven 설계의 C8 재결정** — *원래* 「fan-out 1(인터뷰당 1회) — devbrew N≥5 hard review 게이트 미해당」 / *재결정* `1 + 재개방` / *근거* 현행 `CLAUDE.md` 는 숫자가 아니라 「선언」을 기준으로 하고 재개방에는 사용자 답이 걸린다. **라운드 1 이 예산만으로는 ⟨C12⟩ 를 구현하지 못함을 잡아 자격을 그 위에 얹었다** | 사용자 (OQ19) + 라운드 1 |
| X5 | OQ12 는 **최소 형태만** 끌어온다 — 반증 시 *원래/재결정/근거* 기록 규약. 해결 경로는 범위 밖 유지 | 사용자 |
| X6 | OQ16 처분 = **검증 축**. Phase 0 을 안 건드리고(⟨C4⟩) Phase 1 이 Phase 0 의 산출을 받아 검증한다. **라운드 1 이 집행 손잡이 부재를 잡아 AC20 을 신설했다** | orchestrator + 라운드 1 |
| X7 | OQ13 여미 선 = **차단 판정에 개수를 쓰지 않는다.** 조건 분기·advisory 에는 들어간다(라운드 1 이 이 정밀화를 요구했다) | 사용자 승인 + 라운드 1 |
| X8 | OQ4·OQ20 처분 = 리터럴 마커 **폐기**, 개념은 계약으로 흡수 | orchestrator |
| X9 | OQ5 처분 = 기존 stale 인용 23건 **손대지 않는다** | orchestrator |
| X10 | OQ21 처분 = 코퍼스 18로 **재측정하지 않는다**(R6) | orchestrator |
| X11 | OQ14 처분 = 검문소 **셋**(V1 라운드 안 · V2 종료 누락 대조 · V3 게이트). 라운드 1 이 「둘, 종료 시점」을 반증했다 | orchestrator + 라운드 1 |
| X12 | OQ7 처분 = floor 리터럴 계수는 **계획으로 이월** | orchestrator (⟨S9⟩ 재확인) |

### 재결정

P23 이 요구하는 세 칸이다. brief §2 의 confirmed 항목을 이 설계가 좁힌 것은 **하나**다.

| 항목 | 원래 | 재결정 | 근거 |
|---|---|---|---|
| **⟨C13⟩** | 「C44 압착의 대가는 가드의 계수 방식에서 지불한다 · **산출 항목이 «닿는 열린 결정»을 달면 `non_user_streak` +0, 없으면 +1**」 ⟨S10⟩ | 「`decides` 가 **열린 결정 중 `touched_decisions` 에 없는 것**을 담으면 +0 · 그렇지 않으면 +1 · 열린 결정 0이면 면제 0」 | brief OQ19 가 원문 규칙의 면제에 상한이 없어 §5 가 기각한 임계값 상향보다 **더 강한 약화**임을 지적했다. 집합 원소에 묶으면 면제 예산이 「열린 결정 − touched_decisions」 로 유한해져 그 지적이 해소되고 §5 의 기각 이유가 유지된다. 사용자가 라운드 1 게이트에서 이 재결정을 채택했다(`5cc29851#r1.1`) |

⟨C12⟩ 는 **좁히지 않았다** — 라운드 1 이 예산이 그 문면을 구현하지 못함을 잡아, 설계가 「닿는
결정이 아직 열려 있는가」를 호출 **자격**으로 되돌렸다(§F ①). 확정을 바꾼 것이 아니라 확정대로
고친 것이다.

- D1.1 · r1 · adopt · 0b97902c#r1.1 · "채택(적용) (권장)" — §D·G5 가 검문소 C 를 「생산 직후」라 부르지만 finishing.md 는 floor 5 가 전부 closed 된 뒤에만 읽히므로 확인은 마지막 사용자 라운드 «후»에 일어나고, 반증이 나와도 그 조사가 방향에 영향을 줄 라운드가 남아 있지 않다.
- D1.2 · r1 · adopt · 0bbd91d3#r1.1 · "채택(적용) (권장)" — 조건부 derived 하한은 내부 조사 차원이 아니라 임의의 derived 행으로 충족된다. 내부 조사 차원을 식별해 요구할지, 게이트가 보장하는 범위를 단순 행 존재로 낮출지 정해야 한다.
- D1.3 · r1 · adopt · 0fa0a9b6#r1.1 · "채택(적용) (권장)" — 검문소는 무조건화되지만 계약을 산출할 생산자 둘은 여전히 웹 스위치 조건부라(steelman dispatch 는 보안 락이 else 가지 «안»을 구조적으로 요구하고, prober 는 web-off 시 agent 없는 inline premortem 으로 강등) DISABLE_WEB=1 이면 내부 축의 ∀ 술어가 전부 공허하게 통과한다.
- D1.4 · r1 · adopt · 4ceba241#r1.1 · "채택(적용) (권장)" — 조사가 닿은 결정이 인터뷰 중 해결된 뒤에도 부착을 보존하는 경로가 정의되지 않았다. 해결된 결정의 D ID를 §0에 유지할지, §2의 확정 항목으로 연결할지 정해야 한다.
- D1.5 · r1 · adopt · 5cc29851#r1.1 · "채택(적용) (권장)" — §F 가 확정 ⟨C13⟩ 의 조작 규칙(「산출 항목이 «닿는 열린 결정»을 달면 +0, 없으면 +1」)을 좁혀 부착이 «있는» 산출도 같은 결정 두 번째부터는 +1 을 받게 만드는데, 이 재결정이 어디에도 기록되지 않았다 — Constraints 표의 C13 요지는 좁혀지는 그 조작 절을 떼고 「계수 방식에서 지불」만 남겼고, Handoff Context 는 「뒤집은 것은 없다 · brief 의 확정은 전부 그대로 성립한다」고 단정하며, 결정 기록에도 *원래/재결정/근거* 세 칸이 없다(D4 는 dispatch 예산, D7 은 개수 술어다). P23 규약이 요구하는 사용자 동의와 기록이 빠진 확정 항목 변경이다.
- D1.6 · r1 · adopt · 5cc29851#r1.2 · "채택(적용) (권장)" — 재개방 횟수에 따른 예산만으로는 C12의 '닿는 결정이 아직 열려 있는가'라는 조사 재개 조건을 구현하지 못한다. 결정의 열림을 호출 자격으로 두고 예산을 별도 제한으로 적용하거나, C12를 재결정해야 한다.
- D1.7 · r1 · adopt · 7b7d0951#r1.1 · "채택(적용) (권장)" — AC1 의 인라인 스키마 제거와 Files to Modify 의 steelman.md 「Step 2 를 공유 계약 참조로(중복 제거)」는 각각 출하된 락 둘을 red 로 만들어 AC18(새 RED 0)과 동시에 성립할 수 없다 — 락의 앵커를 새 계약 파일로 옮길지, 사본을 남길지가 결정이다.
- D1.8 · r1 · adopt · 868705ff#r1.1 · "채택(적용) (권장)" — `blind_spot_dispatched: bool` → `blind_spot_dispatches: int` 는 개명이라 현행 migration 규칙(부재 키만 기본값으로 채운다)으로는 이미 dispatch 한 세션이 `0` 을 받아 AP16 가드가 재무장되므로, 값 이월 규칙(true → 1)과 옛 키 삭제를 함께 적어야 한다.
- D1.9 · r1 · adopt · 8891bd29#r1.1 · "채택(적용) (권장)" — 「부착」이라는 낱말이 템플릿 §5(`— 부착 M/N`)와 audit §3(「근거 N 중 부착 M」)에서 이미 다른 뜻으로 쓰이므로, 새 술어를 같은 낱말로 부르면 문구 기반 검사가 기존 `부착 M/N` 로 헛만족될 수 있다 — 술어의 대상은 낱말이 아니라 `[닿는 결정: …]` 리터럴임을 못 박아야 한다.
- D1.10 · r1 · adopt · 8891bd29#r1.2 · "채택(적용) (권장)" — 검문소 C 의 확인 줄이 audit 의 어느 절에 사는지 지정되지 않았다 — 현행 「게이트-전 확인」은 §3 의 ST 블록 안(steelman 조건부)이고 게이트는 절 단위로만 본문을 자르므로, 무조건 도는 검문소에는 무조건 존재하는 절이 필요하다.
- D1.11 · r1 · adopt · a37e4904#r1.1 · "채택(적용) (권장)" — 계약 슬롯을 추가할 dispatch 위치를 실제 파일 구조에 맞게 정정해야 한다. SKILL.md의 두 호출과 references/steelman.md의 한 호출을 명시하고 후자의 편집 목록에도 슬롯 추가를 적어야 한다.
- D1.12 · r1 · adopt · ab77284c#r1.1 · "채택(적용) (권장)" — 면제 술어 「아직 조사가 닿지 않은 열린 결정 하나에 «처음» 닿는가」는 «이미 닿은 결정 집합»을 라운드 사이에 들고 있어야 판정되는데, 그 집합의 산출자도 거처도 설계 어디에도 없다 — 부착은 Step A 에서야 brief 에 적히므로 라운드 중에는 state 밖에 운반체가 없고, §F 의 상태 스키마 변경과 AC13 은 `blind_spot_dispatches` 하나뿐이다. 소비자(면제 규칙)만 있고 산출자가 없다.
- D1.13 · r1 · adopt · abf861b2#r1.1 · "채택(적용) (권장)" — touches의 대상을 전제 P<n>에서 열린 결정 D<n>으로 바꾸면서 기존 steelman 소비 절차를 불변으로 두어 계약이 충돌한다. 전제 부착과 결정 부착을 분리하거나 명시적인 대응 관계를 정해야 한다.
- D1.14 · r1 · adopt · bde80e55#r1.1 · "채택(적용) (권장)" — 계약 펜스 실패 시 「dispatch 하지 않는다」 뒤에 인터뷰가 어떻게 계속되는지가 없다 — coverage-mapper 는 R1 첫 질문 전 필수 1회이고 게이트가 `coverage-mapper <k>` 의 k≥1 을 검사하므로, 원장·audit §2 에 무엇을 적는지(0 + unavailable 사유인지)가 정해져야 한다.
- D1.15 · r1 · adopt · bf15a523#r1.1 · "채택(적용) (권장)" — 부착을 §4 항목의 같은 줄에 두는지 하위 불릿으로 두는지가 정해지지 않았는데, `ENTRY_BULLET_RE`(`^\s*[-*]\s`)가 들여쓴 불릿도 §4 항목으로 세므로 하위 불릿 형태는 즉시 unkeyed landscape entries red 가 된다.
- D1.16 · r1 · adopt · bf15a523#r1.2 · "채택(적용) (권장)" — 부착 ∀ 가 순회할 「조사 항목」이 기계적으로 정의되지 않아 §5 의 기각·보류·검토·위험 네 모양 중 무엇이 대상인지 두 가지로 읽히고, 넓은 독법이면 기존 픽스처·코퍼스의 위험 항목 전량이 red 가 된다(⟨C10⟩·Verification 7 과 충돌).
- D1.17 · r1 · adopt · e361710c#r1.1 · "채택(적용) (권장)" — AC10 · AC11 · AC12 는 게이트가 payload 안에서 「레포 출처 항목」을 식별하고 그것을 audit 의 확인 줄과 대응시킬 것을 요구하는데, payload 쪽 표기도 두 파일을 잇는 id 도 설계에 없다 — 현행 교차 술어는 전부 키·id 기반이다.
- D1.18 · r1 · adopt · e361710c#r1.2 · "채택(적용) (권장)" — 부착 대상 D<n>의 존재 검사는 §3에서 근거로 돌아가는 역참조를 보장하지 않는다. 역참조를 실제 검사할지, 해당 연결은 작성 규약으로만 보장한다고 수정할지 정해야 한다.
- D1.19 · r1 · adopt · e46dabab#r1.1 · "채택(적용) (권장)" — D6(OQ16 처분 = 검증 축)에 대응하는 AC·파일·표기가 하나도 없고 Phase 0 의 레포 사실은 라벨 금지 산문으로 seed 에 실리므로, 「Phase 1 이 Phase 0 의 산출을 받아 검증한다」를 집행할 손잡이가 설계 안에 없다.
- D1.20 · r1 · adopt · f9bd806d#r1.1 · "채택(적용) (권장)" — Non-goals 의 「이 설계의 게이트는 개수를 어디서도 세지 않는다」가 §E 표의 조건부 하한(레포 출처 항목이 ≥1 이면)과 0건 advisory(내부 조사 0건)와 정면으로 어긋나므로, ⟨C5⟩ 양립 논거가 걸린 술어의 범위를 사용자가 못 박아야 한다.
- D2.21 · r2 · adopt · 00a2a19c#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — finding 없이 바뀜: 출하돼 있는 것 — 세 인용 (modified)
- D2.22 · r2 · adopt · 05e6cabb#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — payload 의 열린 결정 id 로 고른 `OQ<n>` 이 리뷰 엔진의 `D<n>.<m>` 과 같은 토큰 공간이고 그 토큰은 이미 brief §2·§3 본문에 살아 있어, ② 의 실재 검사와 ③ 의 역참조가 무관한 리뷰 결정 인용으로 만족될 수 있다.
- D2.23 · r2 · adopt · 0fa0a9b6#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — 세 dispatch 자리의 처분 줄을 `fail-closed` 로 고치기로 했는데 §A 는 같은 실패에서 인터뷰를 계속하고 게이트가 advisory 로 통과시킨다고 적어, 처분 선언과 실제 소비 동작이 어긋난다 — 막을 것인지 공시만 할 것인지 정해야 한다.
- D2.24 · r2 · adopt · 137e1dfd#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — §F ③ 이 못 박은 「append 가 계수보다 앞」 순서는 계수 시점에 `decides ⊆ touched_decisions` 를 항상 성립시켜 면제 조건을 영구히 거짓으로 만들고, ⟨C13⟩ 이 요구한 「계수 방식에서의 대가 지불」이 사라진다.
- D2.25 · r2 · adopt · 236477b0#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — 「`closed` 를 요구하면 … 차원이 사용자 발화로 닫혔다는 것까지 기계가 본다」는 과대 주장이다 — `coverage_anchor_failures` 는 §6 에 실재하는 아무 `S<N>` 이든 받는 form-only 검사라 무관한 앵커 하나로 통과한다.
- D2.26 · r2 · adopt · 3162cfd3#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — finding 없이 바뀜: §D 자리 4 — 검문소 셋과 인계 (added)
- D2.27 · r2 · adopt · 37ae622f#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — finding 없이 바뀜: 설계 (Architecture) (modified)
- D2.28 · r2 · adopt · 3d2723f5#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — 회계 표가 새 «줄 형식» 계약 넷과 템플릿 둘의 변경을 칸으로 세지 않아, Non-goals 가 ⟨C3⟩ 양립 논거로 쓰는 「0개」 서술이 실제 가산량을 축소한다.
- D2.29 · r2 · adopt · 3e568a4c#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — finding 없이 바뀜: Open Questions (modified)
- D2.30 · r2 · adopt · 3ef85a5b#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — finding 없이 바뀜: 그래서 결핍은 무엇인가 (modified)
- D2.31 · r2 · adopt · 496041cc#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — finding 없이 바뀜: Rejected Alternatives (modified)
- D2.32 · r2 · adopt · 49ed4d39#r2.2 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — §4 전체에 새 연결 표기를 요구하면 기존 green 픽스처가 red가 된다. 기존 픽스처 무변경 통과와 새 술어의 적용 범위를 함께 만족시킬 호환 정책이 필요하다.
- D2.33 · r2 · adopt · 5167dc45#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — finding 없이 바뀜: 인터뷰의 조사 특화 — 승격으로 만든다 · Design (removed)
- D2.34 · r2 · adopt · 66cfb623#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — finding 없이 바뀜: 인터뷰의 조사 특화 — 계약을 꺼내고 한 필드를 더한다 · Design (added)
- D2.35 · r2 · adopt · 720d4cf6#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — finding 없이 바뀜: 재결정 (added)
- D2.36 · r2 · adopt · 730c74a1#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — finding 없이 바뀜: 회계 — 무엇이 새로 생기는가 (added)
- D2.37 · r2 · adopt · 773399f7#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — 네 번째 dispatch 자리(C43 경로 (a) 의 「하니스 기본 탑재 read-only 탐색 subagent 배선」)는 처분 선언을 가질 수 없다 — CLAUDE.md 가 요구하는 `**처분** —` 줄을 그 자리에 적으면 락의 축 A① 이 red 가 되고(앵커 수 > dispatch 수), 안 적으면 「모든 dispatch 자리는 처분을 밝힌다」를 어긴다. §B 는 「네 자리 전부 dispatch 당 1」로 fan-out 을 선언하는데 AC2·AC22·Files to Modify 는 세 자리만 센다.
- D2.38 · r2 · adopt · 812301ba#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — finding 없이 바뀜: §F 동역학 — 자격 · 예산 · 면제 (added)
- D2.39 · r2 · adopt · 88cb8a12#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — finding 없이 바뀜: §C 자리 3 — 대등한 축 (modified)
- D2.40 · r2 · adopt · 8e81e781#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — finding 없이 바뀜: Constraints (modified)
- D2.41 · r2 · adopt · 9cb89df0#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — finding 없이 바뀜: 목차 (modified)
- D2.42 · r2 · adopt · a76ed781#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — finding 없이 바뀜: 알려진 한계 (modified)
- D2.43 · r2 · adopt · b9283cc5#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — finding 없이 바뀜: §G 데이터 흐름 한 장 (modified)
- D2.44 · r2 · adopt · bcf9a099#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — finding 없이 바뀜: Concrete Next Action (modified)
- D2.45 · r2 · adopt · c9126d7c#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — ④ 가 요구하는 행 이름 `derived:internal_research` 의 일치 규칙(정확 일치인가 접두 일치인가)이 없는데 이 사이클의 audit §1 에 이미 `derived:internal_research_apparatus` 가 살아 있어, 접두 일치면 무관한 차원으로 갈음되고 정확 일치면 그 기존 행이 요구를 못 채운다.
- D2.46 · r2 · adopt · db9a48da#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — OPEN_DECISIONS의 생산·보존 경로와 결정↔차원 대응이 없다. 소비 슬롯과 종료 산출물 사이에 인터뷰 중 사용할 결정 목록의 소유자와 생명주기를 정해야 한다.
- D2.47 · r2 · adopt · e09185f8#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — finding 없이 바뀜: Goals (modified)
- D2.48 · r2 · adopt · e361710c#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — 게이트 ① 이 §4 의 «모든» 항목 줄에 줄끝 연결을 ∀ 로 요구하는데 「닿는 결정 없음」을 적을 자리가 없어, §A 계약이 허용한 `decides: []` 항목은 거짓 연결 없이는 §4 에 실릴 수 없다 — 술어에 sentinel 을 열지, 순회 범위를 좁힐지 정해야 한다.
- D2.49 · r2 · adopt · e3ff3375#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — finding 없이 바뀜: Handoff Context (modified)
- D2.50 · r2 · adopt · ec10b9b6#r2.1 · "멈추고 표기층을 도출한다 (권장) — 라운드 3 을 돌지 않고 실질 18건을 «id 생명주기 한 장»으로 수렴시켜 고친다. 얼림 19건은 라운드 1 게이트가 이미 승인한 편집이라는 근거로 채택. 미해결은 §Open Questions 로 박제해 계획이 받는다" — steelman 의 Step 2 는 확인 결과를 audit §3 에 남기는데 ⑤·AC12 는 payload 의 모든 `RC<n>` 에 audit §5 줄을 요구하므로, 「steelman 경로는 두 번 확인하지 않는다」를 지키면 steelman 이 낸 `repo_claims` 는 ⑤ 에서 red 가 되거나 payload 에 아예 오르지 못한다.
