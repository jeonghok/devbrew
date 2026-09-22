---
name: interview-research-specialization
type: design
created_at: 2026-09-22
source_interview: docs/superpowers/interview/2026-09-21-interview-research-specialization-interview.md
next_phase: superpowers:writing-plans
---

# 인터뷰의 조사 특화 — 승격으로 만든다 · Design

> 네 축을 만드는 문제가 아니었다. 이미 만들어 둔 계약 하나가 조건부 뒤에 갇혀 한 자리에서만
> 돌고 있었다. 이 설계는 그것을 꺼내 네 자리에 걸고, 그 산출에 형태 술어를 건다.

## Handoff Context

이 문서가 받은 것: `docs/superpowers/interview/2026-09-21-interview-research-specialization-interview.md`
(§2 확정 14건 · §3 Open Questions 22건 · §4 landscape 30건 · §5 기각 12 + 위험 14).
텔레메트리·steelman 원문·리뷰 결정 17건은 그 파일의 `audit_file` 에 있다.

**재결정 규약(P23)** — brief §2 의 confirmed 14건은 재논의 대상은 아니지만 **반증 대상**이다.
근거가 있으면 보고 후 사용자 동의로 재결정하고, 뒤집은 항목은 *원래 / 재결정 / 근거* 세 칸으로
남긴다. 임의 변경은 금지다. 이 문서가 뒤집은 것은 **없다** — 다른 사이클의 설계 제약 하나를
재결정했고(`## 결정 기록` D4), brief 의 확정은 전부 그대로 성립한다.

**Locked in this doc** — 아래 `## Constraints` 의 C1–C14 는 brief §2 의 확정을 그대로 물려받은
것이고, `## 결정 기록` 의 D1–D5 는 이 설계 세션에서 사용자가 고른 것이다. 둘 다 하류(writing-plans)가
근거 없이 바꿀 수 없다.

## 목차

- [Goal](#goal)
- [Context / Why](#context--why)
  - [출하돼 있는 것 — 세 인용](#출하돼-있는-것--세-인용)
  - [그래서 결핍은 무엇인가](#그래서-결핍은-무엇인가)
- [Goals](#goals)
- [Non-goals](#non-goals)
- [Constraints](#constraints)
- [설계 (Architecture)](#설계-architecture)
  - [§A 자리 1 — 계약 정본](#a-자리-1--계약-정본)
  - [§B 자리 2 — 조사 장치 넷](#b-자리-2--조사-장치-넷)
  - [§C 자리 3 — 대등한 축](#c-자리-3--대등한-축)
  - [§D 자리 4 — 검문소와 인계](#d-자리-4--검문소와-인계)
  - [§E 자리 5 — 게이트](#e-자리-5--게이트)
  - [§F 동역학 — 예산과 면제](#f-동역학--예산과-면제)
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

⟨C12⟩ 가 요구한 「경로+앵커+닿는 결정」이 `path`·`anchor`·`touches` 로 전부 있다.

**② 그 계약의 검증 절차도 존재한다.** `references/steelman.md` Step 2 「게이트-전 확인」:

> - `repo_claims` 전 항목: 경로 실재 → 앵커 실재 → 주장이 그 자리와 맞는가. 결과 ∈ {확인, 반증,
>   미확인}. `미확인`(확정도 반증도 못 한 것)은 J 에 들지 않되 4-block 에서 `[미확인]` 라벨로
>   **보인다** … 왜 확정하지 못했는지 한 줄을 audit §3 에 남긴다.
> - 「근거 N 중 부착 M」의 M 은 **확인을 통과한 부착**만 센다. … 리포 주장은 「리포 주장 K 중 확인
>   J」로 따로 센다.

세 번째 단계(「주장이 그 자리와 맞는가」)가 **구현을 읽으라는 요구**다. brief OQ17 이 지목한
구멍(경로+앵커만으로는 「인덱스만 읽고 구현을 안 읽음」이 안 걸러진다)을 이 절차는 이미 막는다.

**③ 새 절을 만드는 쪽은 이미 계약으로 제한돼 있다.** `references/compression.md`:

> **존재 검사가 payload 를 양식으로 만든다.** 문서형 payload 는 절 존재 검사를 가질 수 있되
> 확산물의 *원문·근거·전량*을 payload 에 요구해서는 안 된다. 확산에서 나온 것의 **압축된 판정
> 한 줄**은 payload 의 것이다.

⟨C10⟩ 의 「새 절 신설 대신 §3·§5 를 살린다」는 취향이 아니라 이 계약과의 정합이다. 같은 파일이
금지하는 것은 **링크**이고 경로+앵커가 아니므로, 내부 조사의 출처를 payload 에 두는 것은
N1a(payload 외부 URL 금지)와 충돌하지 않는다.

### 그래서 결핍은 무엇인가

**「장치가 없다」가 아니라 「있는 장치가 한 자리에서만, 조건부로 돈다」다.**

- 계약을 쓰는 자리가 `steelman-builder` **하나**다. `coverage-mapper`·`blind-spot-prober`·C43 경로
  (a) 자동확인은 같은 계약을 받지 않는다.
- 그 하나가 trigger 조건부다 — `references/steelman.md` 는 trigger 를 「landscape 모순 / 알려진
  anti-pattern / 기존 사용자 제약과의 충돌」로 한정하고, `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` 이면
  dispatch 가 `else` 가지 안이라 통째로 생략된다. 웹을 요구하지 않는 내부 조사의 검문소가 웹
  스위치에 종속돼 있다(brief ⟨D1.6⟩).
- 그래서 두 번 출하됐는데(2026-09-05 의 C9·C24) 두 번 다 발화하지 않았다. brief §2 의 ✎ 가 고른
  원인이 **「산문이라서」가 아니라 「읽는 자리가 없어서」**다.

Phase 0 과의 분업도 같은 모양이다. `skills/framing-requests/SKILL.md` 의 확산 절차 2는
「**레포 읽기** — 관련 코드 · `CLAUDE.md` · `AGENTS.md` · 기존 설계 문서를 읽습니다」 한 줄이고
출력 의무도 게이트도 없다. 즉 **분업선은 웹에만 그어져 있고 레포에는 어느 쪽에도 의무가 없다.**
이 사이클이 그 비용의 실증이다 — seed 가 레포를 읽고 낸 사실 셋이 Phase 1 의 재측정에 반증됐다
(brief §5 의 기각 1·2·3).

측정된 비대칭(외부 축은 floor 차원 + brief 절 + 게이트 검사 여섯, 내부 축은 산문 두 줄; 게이트
검사 26 중 조사 관련 15가 전부 외부)은 **상관까지만** 주장한다. 이 설계는 그 수를 인과로 쓰지
않는다 — 아래 `## Rejected Alternatives` R6 참조.

## Goals

- **G1** 내부(레포) 조사를 외부(웹) 조사와 **대등한 축**으로 세운다 — 커버리지 원장에 자리가 있고
  그 자리가 닫힐 때 floor 와 같은 검사를 받는다.
- **G2** 조사 산출물마다 **닿는 결정**을 달게 한다. 어느 결정에도 닿지 않은 조사는 성공 셋(바꿈·
  보강·지지) 어디에도 들지 않는다는 판별선을 계약으로 만든다.
- **G3** 조사를 **여러 겹**으로 돌 수 있게 한다 — 차원 재개방이 빈손으로 돌지 않게, 그 차원을
  채우는 장치의 예산을 재개방의 함수로 만든다.
- **G4** 조사 산출이 **하류가 읽을 이유**를 갖게 한다 — 부착과 상호참조로. 하류에 구속을 걸지는
  않는다(D2).
- **G5** 위 넷을 **집행**한다 — 무조건 도는 검문소 둘(생산 직후 확인 · 종료 시 형태 대조).

## Non-goals

- **조사를 했는지를 나중에 재는 장치** ⟨C5⟩. 2026-09-10 에 사용자가 사후 깊이 측정 계열을 「쓰이지
  않는 무게 · 번거로움 · 방향이 틀렸다」 세 이유로 직접 걷어냈고 그 판정은 유효하다. **이 설계의
  게이트는 개수를 어디서도 세지 않는다** — ∀ 형태 술어뿐이고, 항목이 0건이면 공허하게 통과한다.
- **인터뷰를 조사 전용 단계로 바꾸는 것** ⟨C3⟩. 문제공간 탐색·질문·사용자 대화가 밀려나면 실패다.
  이 설계가 새 절·새 agent·새 floor 키를 0개 만드는 이유가 이것이다.
- **Phase 0(`framing-requests`)의 편집** ⟨C4⟩. 「웹을 보지 않는다」 경계도, 레포 읽기 줄도
  건드리지 않는다. Phase 1 의 내부 축은 Phase 0 의 산출을 **받아 검증**하는 축이다(D6).
- **소비자 플러그인(`superpowers:brainstorming`) 편집** — 이 리포 밖이라 불가능하다.
- **조사량의 «최대치»를 목표로 삼는 것** — brief ST1 에서 버렸다 ⟨C12⟩.
- **6번째 floor 키 신설** — 기존 픽스처 전량을 red 로 만든다 ⟨C10⟩.
- **새 조사 agent 파일 신설** — ⟨D1.7⟩ 이 열어 둔 자리를 배선으로 채운다. 「배선도 구현이다」.
- **리터럴 마커 `[from-code][auto-confirmed]` 의 유지** — 개념을 계약으로 흡수하고 리터럴은
  폐기한다(D8).
- **과거 brief 코퍼스의 소급 수정** — 기존 줄번호 인용 23건은 그대로 남는다(D9).
- **하류에 대한 구속 문구** — D2 가 「읽을 이유까지만」으로 정했다.

## Constraints

brief §2 의 confirmed 14건을 그대로 물려받는다. 이 문서는 각 항목이 **어느 절에서 지켜지는지**를
함께 적는다 — 제약을 옮겨 적기만 하면 지켜졌는지 확인할 자리가 없다.

| id | 제약 (요지) | 지켜지는 자리 |
|---|---|---|
| C1 | 인터뷰가 조사의 책임 주체 · 내부와 외부 둘 다 | §A–§E 전부 |
| C2 | 하류 조사 슬롯 부재를 단정하지 않되 인터뷰가 특화해 짊어진다 | R3(spec-kit 배치 기각 + 도출 방식은 취함) |
| C3 | 조사 전용 단계로 바꾸지 않는다 · 대화가 밀리면 실패 | Non-goals · 신설 0 · §F 면제 |
| C4 | Phase 1 안으로 한정 · Phase 0 의 웹 경계 불변 | Non-goals · D6 |
| C5 | 사후 측정 장치 금지 | §E (개수 술어 0) · AC8 |
| C6 | 강제 수준은 소비자에서 도출 | §D 인계 · D2 |
| C7 | 제약이라는 이름으로 구현 회피 거부 | §A–§E 다섯 자리 전부 실제 변경 |
| C8 | 네 축을 다섯 자리에 · 게이트가 다섯째이자 집행 수단 | §A–§E |
| C9 | 충돌 외부 근거 전부 취함 · decision-first 를 steelman 게이트로 | §B (계약이 decision-first) |
| C10 | 결핍 셋 · 새 절 대신 §3·§5 · 픽스처 안 건드리는 하한 | §C 조건부 하한 · §D 부착 |
| C11 | 성공 = 조사가 방향에 영향(바꿈·보강·지지) | Goal · §D 반증 기록 |
| C12 | 출력 의무(경로+앵커+닿는 결정)를 조사 자리 전부에 · derived 축 | §A · §B · §C |
| C13 | C44 압착의 대가는 가드의 계수 방식에서 지불 | §F |
| C14 | 장치의 형태는 소비 계약이 선 뒤에 결정 | 이 문서의 절 순서 자체(§D 소비 → §A 형태) |

## 설계 (Architecture)

다섯 자리 · 축 넷 · **신설 파일 1(계약 정본) · 새 agent 0 · 새 brief 절 0 · 새 floor 키 0 · 삭제 0.**

### §A 자리 1 — 계약 정본

신규 `plugins/spec-distill/references/research-claims.md` 한 장이 조사 주장의 **유일한 정의**를
갖는다. 두 모양은 이미 출하된 것 그대로다 — 새 스키마를 만들지 않는다.

```yaml
evidence:                      # 외부(웹) 주장
  - url: "https://..."
    supports: current | alternative | both | framing
    claim: "<이 출처가 뒷받침하는 것>"
    touches: [D3]              # 닿는 열린 결정 — 빈 배열 허용
repo_claims:                   # 내부(레포) 주장
  - path: "<repo 상대경로>"
    anchor: "<심볼 | 헤딩 | 원문 인용>"
    line: 123                  # 선택 — 보조 정보
    claim: "<주장>"
    touches: [D3]
```

정본이 하나여야 하는 근거는 이 플러그인이 이미 락으로 집행하는 것이다 —
`tests/test_yaml_scalar_single_definition.py` 의 서술:

> 갈라진 사본은 "한쪽만 고치는" 결함을 부르고, 실제로 두 merge 스크립트의 advisory 리터럴 5건이
> 인용 없이 나가 YAML flow sequence 로 읽히고 있었다.

그래서 `agents/steelman-builder.md` 의 인라인 스키마 블록을 **제거하고** 이 파일을 정본으로 만든다
(사본 둘을 남기지 않는다). 계약이 추가로 담는 문장 둘:

1. **OQ17 의 선례 지시** — `docs/archive/interview/2026-07-12-project-init-audit-interview.md` 가
   남긴 것을 그대로: 「인덱스·레지스트리·목차·description 필드만 읽고 판정하지 말 것. **구현을
   읽어라.**」 그 사이클은 「레포에서 auto-confirm 한 사실」 범주를 만들었다가 **4건 중 3건의
   전제가 틀린 것**을 확인하고 범주 자체를 폐기했고, 실패 유형은 전부 같았다.
2. **`touches` 의 의미** — 「지금 열려 있는 결정 중 이 주장이 닿는 것」. 빈 배열은 허용이고 거짓
   부착보다 낫다(출하된 규칙 5 그대로).

**배달 방식** — 이 파일은 subagent 에게 **경로로 넘기지 않는다.** 설치본에서 플러그인 캐시는
사용자 프로젝트 밖이라 subagent 의 `Read` 가 권한 거부되고, 그러면 agent 는 계약 없이 판정하면서
orchestrator 는 그것을 모른다. 이 리포는 같은 문제를 이미 풀어 두었다 —
`skills/reviewing-brief/SKILL.md`:

> `${PROFILE}` 에는 경로가 아니라 **프로필 파일의 내용**을 싣는다 — 플러그인 캐시는 사용자
> 프로젝트 밖이라 리뷰어의 Read 가 거부된다.

같은 관습을 쓴다: `conducting-interview/SKILL.md` 에 `cat` 펜스 하나를 두어 `$CLAIMS_CONTRACT` 를
채우고, 조사 dispatch 셋의 프롬프트에 `<claims_contract>${CLAIMS_CONTRACT}</claims_contract>` 슬롯으로
**내용을** 싣는다. 펜스가 실패하면 **dispatch 하지 않는다**(rc 1 + loud advisory) — 계약 없는
조사는 계약 있는 조사와 산출물에서 구별되지 않기 때문이다.

### §B 자리 2 — 조사 장치 넷

축 «전담 장치»는 **도구 부분집합이 아니라 출력 의무**로 정의한다 — brief ST1 이 「세 조사 agent 가
이미 동일한 `tools:` 를 갖고 있어 새 능력이 아니라 새 파일이 된다」로 도구-부분집합 정의를 버렸다.

| 장치 | 변경 |
|---|---|
| `agents/steelman-builder.md` | 인라인 스키마 블록 제거 → `claims_contract` 슬롯. 출력 형식·동작 규칙의 나머지는 불변 |
| `agents/coverage-mapper.md` | `input_slots` 에 `claims_contract` 추가. 출력에 `repo_claims[]`/`evidence[]` 요구 — derived 차원 제안의 근거를 주장 형태로 낸다 |
| `agents/blind-spot-prober.md` | 같음. `hidden_assumptions[]`·`failure_modes[]` 의 각 `evidence` 를 계약 형태로 |
| C43 경로 (a) 자동확인 | `SKILL.md` 의 그 행이 리터럴 마커 대신 **계약을 산출한다**고 적는다. 대량 레포 스윕이 필요하면 하니스 기본 탑재 read-only 탐색 subagent 에 같은 계약을 인라인해 배선한다 — 새 agent 파일을 만들지 않는 근거는 ⟨D1.7⟩ 이고, brief §4 의 «claude-code-subagents» 가 그 기본 탑재를 prior art 로 기록했다 |

**처분** — consumer=orchestrator · fail-closed · disclosure=계약 펜스 실패 시 loud advisory + dispatch 중단

fan-out 은 선언한다(CLAUDE.md 처분 규약). 네 자리 전부 dispatch 당 1이고 §F 의 예산이 총량을
사용자 답에 묶는다.

### §C 자리 3 — 대등한 축

커버리지 원장의 `derived:` 에 내부 조사 차원을 세운다. 6번째 floor 키를 만들지 않는 근거는 둘이다 —
⟨C12⟩(iii) 가 그렇게 골랐고, `FLOOR_KEYS` 는 `check_brief.py` 의 ∀ fail-closed 루프라 키를 더하면
기존 픽스처 전량이 red 가 된다(⟨C10⟩).

**이미 이빨이 있다.** `check_brief.py` 의 `coverage_anchor_failures` 는 행의 종류를 가리지 않는다:

```python
m = LEDGER_ROW_RE.match(body)
if not m or m.group(2).strip() != "closed":
    continue
key, evidence = m.group(1).strip(), m.group(3)
cited = ANCHOR_RE.findall(evidence)
if not cited:
    fails.append(f"{key} evidence cites no S<N> anchor")
```

즉 `derived:` 행도 닫혔다고 적으면 **실재하는 사용자 발화 앵커를 대야 한다.** 같은 함수의
docstring 이 그것을 명시한다:

> 인용된 앵커는 **전부** 실재해야 한다 — 재개방 접미의 `conflicts_with` S 도 사용자 발화이므로
> 같은 요구를 받는다.

그래서 brief ⟨D1.4⟩ 가 지적한 「derived 는 영으로 선언 가능」은 정확히 **구멍 하나**다:
`- derived: N/A` 한 줄로 행 자체가 사라지는 것. 새 술어는 하한을 «만드는» 것이 아니라 **그 탈출을
언제 막는가** 하나다 → §E 로.

### §D 자리 4 — 검문소와 인계

**검문소 C(생산 직후) — `references/finishing.md` Step A.** steelman 의 Step 2 를 조사 전체로
일반화해 승격한다. 대상은 **레포 주장(`repo_claims[]`)** 이다 — 웹 주장은 URL 재방문을 강제하지
않으므로 이 자리에서 확인할 것이 없다(그쪽은 §4 의 «출처키»와 N2 가 이미 audit §7 에 결속한다).
항목마다:

1. 경로 실재
2. 앵커 실재
3. **주장이 그 자리와 맞는가** — 인덱스·레지스트리·목차·description 필드가 아니라 구현을 읽는다
4. 결과 ∈ {확인, 반증, 미확인} 을 audit 에 항목당 한 줄로. `미확인` 은 라벨로 **보인다** —
   조용히 흡수하지 않는다(출하된 Step 2 규약 그대로).

이 단계는 steelman trigger 에도 `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 에도 **종속되지 않는다** —
⟨D1.6⟩ 이 요구한 「무조건 도는 자리」다. Step A 는 brief 를 쓰는 모든 종료 경로가 지나가고,
`DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW=1` 로도 꺼지지 않는다(그 스위치는 Step A.5 리뷰만 끈다).

**반증의 소비 경로(최소 형태).** 3단계 판정이 `반증` 이면, 그 항목이 닿는 확정을 payload §5 에
*원래 / 재결정 / 근거* 세 칸으로 남긴다. **재결정 자체는 사용자 동의로만 한다**(P23) — 이 규약은
기록 형식이고 판정 권한이 아니다. 이것을 넣는 이유는 이 설계가 반증을 **생산**하는 장치를 늘리기
때문이다: 생산은 늘리고 소비 경로는 닫아 두면 금지 패턴 «Sealed decision» 이다. 이 형식은 새로
만드는 것이 아니라 brief 가 이미 세 번 쓴 것의 규약화다(⟨S2⟩ 진단 · 「1회-상한」 진단 · §4 Kiro
라벨).

**인계 — 「읽을 이유」까지.** ⟨D1.2⟩ 가 인계 축의 대상을 `/compact` 보존 목록에서 **하류가 그 절을
읽을 이유**로 옮겼다. 근거: 하류는 brief **파일 경로**를 받으므로 §5 를 포함한 전문을 읽을 수 있고,
반대로 보존 목록은 사람이 복사하는 산문이라 고쳐도 도달이 강제되지 않으며 옵션 ②(「compact 없이,
전체 context 유지」) 경로에는 목록이 적용조차 되지 않는다.

그래서 인계 장치는 **세 방향**이다. ⟨C10⟩ 이 「§3·§5 를 살린다」로, ⟨C8⟩ 이 「§4 도 함께
구제한다」로 지목한 세 절이 각각 **다른 방향**을 받는다:

- **부착 (§4 · §5 → 결정)** — 조사 항목이 `[닿는 결정: D<n>]` 을 단다. 여기가 ⟨D1.2⟩ 가 「산출물
  소실이 아니라 **강조 소실**」로 다시 읽은 자리다.
- **역참조 (§3 → 근거)** — OQ 가 그 근거 항목을 되가리킨다(`→ 근거 §5-R2`). §3 항목은 **그 자체가
  열린 결정**이라 부착의 *대상*이고 출처가 아니다 — 거기에 「닿는 결정」을 걸면 자기지시가 되어
  술어가 공허해진다. §3 의 「살림」은 방향이 반대다.
- **요약 상호참조 (§0 → 근거)** — 「한눈에」의 열린 결정 줄이 근거 항목을 가리킨다
  (`열린 결정 D3 — 면제 상한 → 근거 §5-R2 · §3-OQ1`).

§2 는 대상이 아니다 — 근거가 사용자 발화(`evidence: S<N>`)이고 ✎ 블록은 `bijection_b_errors`
(§2 본문 ↔ frontmatter)의 대상 밖이라, 거기에 새 술어를 걸면 그 bijection 과 이음매가 생긴다.

하류가 보는 것은 「D3 을 정하려면 §5 R2 를 읽어야 한다」다. **하류에 건 지시는 없다** — D2 가
그렇게 정했고, 구속 문구는 «Sealed decision» 을 관로화하고 P23 과 충돌한다.

### §E 자리 5 — 게이트

`scripts/check_brief.py` 에 술어 둘 + advisory 하나. **개수는 어디서도 세지 않는다.**

| 검사 | 술어 | 0건일 때 |
|---|---|---|
| 부착 ∀ | payload **§4·§5** 의 조사 항목마다 `[닿는 결정: …]` 존재 | 공허 통과 |
| 부착 지시 대상 실재 | 그 `D<n>` 이 같은 payload 의 §3 또는 §0 에 실재 — **§3 의 역참조가 기계적으로 닫히는 자리가 이것이다**(별 술어를 두지 않는다) | 공허 통과 |
| 확인 줄 ∀ | **레포 주장**마다 §D 확인 줄이 audit 에 존재 (웹 주장은 대상 아님) | 공허 통과 |
| derived 하한 (조건부) | payload 에 레포 출처 항목이 ≥1 이면 audit §1 에 `derived:` 행 ≥1 필요 · sentinel 만으로 불충분 | sentinel 통과 |
| advisory | 레포 출처 항목 0건이면 「내부 조사 0건」 한 줄 | — |

**개수 술어를 두지 않는 것이 ⟨C5⟩ 와 축 «게이트» 의 충돌(OQ13)을 해소하는 선이다.** 개수를 재서
막으면 「조사를 했는지를 나중에 재는 장치」가 되고, ∀ 형태만 보면 「써 놓은 것이 쓸 수 있는
형태인가」를 보는 것이다. 이것은 새 술어 계열이 아니다 — `landscape_unkeyed` 가 §4 에 대해 이미
같은 일을 한다:

> #13 — §4 항목마다 «출처키»가 있는가. **∀다** … web-off brief는 §4에 순회할 항목이 없어 공허하게
> 통과하는 것이 옳다 — 조사하지 않았으면 인용할 것도 없다.

**조건부 하한**도 이 파일의 관습이다. `landscape_keys_declared`:

> **조건부다.** 「audit §7이 비어 있지 않다」로 두면 갓 만든 audit도 웹이 꺼진 audit도 red가 된다.
> payload가 landscape를 실었다는 사실을 조건으로 건다 — 키가 없으면 공집합 ⊆ 무엇이든으로 자동
> 만족되므로 kill switch 코드가 필요 없다.

조건을 산출물에 두는 대가는 `## 알려진 한계` L1 에 적는다.

**0건 advisory 의 배달지** — `gate()` 의 `advisories` 채널이고, `finishing.md` Step B 가 그것을
proceed 게이트 `question` 본문에 싣는다(이미 `coverage-mapper 0 (unavailable: …)` 이 쓰는 자리).
같은 파일의 근거를 상속한다: 「advisory 는 조용히 통과하지 않고 Step B 게이트 텍스트로 사람에게
간다」. 침묵과 0 은 다른 사실이다.

### §F 동역학 — 예산과 면제

**dispatch 예산 = `1 + 그 차원의 재개방 횟수`.** ⟨C12⟩ 가 확정한 진단은 「현행 조사 장치는 전부
1회-상한」이 아니라 **「차원 재개방은 무제한인데 그 차원을 채우는 장치는 1회 하드캡이라 재개방이
빈손으로 돈다」**는 비대칭이다. 그러면 고칠 것은 상한의 숫자가 아니라 상한이 무엇의 함수인가다.

| 장치 | 지금 | 바뀜 |
|---|---|---|
| `blind-spot-prober` | 인터뷰당 하드 1회 (`blind_spot_dispatched: bool`) | `blind_spot_dispatches < 1 + coverage.floor.blind_spot.reopened` |
| `coverage-mapper` | 상한 2 (R1 전 1 + 재개방 시 ≤1) | `coverage_mapper_dispatches < 1 + Σ(모든 차원의 reopened)` |
| `steelman-builder` | 방향당 1회 · 새 근거 있으면 재호출 | **불변** — 이미 근거-발동이라 같은 원리다 |

무한 루프가 아닌 근거는 `SKILL.md` 가 재개방에 상한을 두지 않을 때 쓴 것과 같다:

> 상한 없음 — 라운드는 사용자 답으로만 돌아 **사용자가 시계다.**

재개방은 정의상 「새 답·외부 근거·코드 사실이 그 차원의 닫힘 근거 S 와 충돌」해야 일어나고, 그
기록에 `conflicts_with: S<N>` 이 남아 게이트가 앵커 실재를 검사한다.

**면제의 유한화 (⟨C13⟩ · OQ1 · OQ19).** ⟨C13⟩ 은 「산출 항목이 «닿는 열린 결정»을 달면
`non_user_streak` +0, 없으면 +1」이다. 조건을 한 단어 좁힌다:

> 면제는 「부착이 **있다**」가 아니라 **「아직 조사가 닿지 않은 열린 결정 하나에 처음 닿는다」**
> 일 때만 +0. 같은 열린 결정에 두 번째로 닿는 산출은 +1. 열린 결정이 0이면 면제도 0.

그러면 면제 예산이 `|아직 안 닿은 열린 결정|` 이 되어 **유한**하다. 이 상한은 열린 결정 집합이
줄어드는 데 **의존하지 않는다** — 줄지 않아도 같은 결정의 두 번째 부착이 면제되지 않으므로 예산이
고갈된다. OQ19 가 지적한 「무한 면제가 §5 가 기각한 임계값 상향보다 더 강한 약화」는 이로써
해소되고, §5 의 임계값 상향 기각 이유(AP16 가드 직접 약화 · 임계치 완화는 보안-민감 편집)는
유지된다.

이 회계는 brief §4 의 «voi-analysis»(「결정을 바꿀 수 있는 정보만 값이 있다」)와
«decision-quality-chain»(「정보만 늘리면 상한이 안 움직인다」)이 처방한 것과 같다 — 값을 정보의
양이 아니라 **닿는 결정의 수**로 센다.

**상태 스키마.** `blind_spot_dispatched: bool` → `blind_spot_dispatches: int`.
`references/state-migration.md` 의 발동 조건이 이미 「**부재 키가 있는가**」이므로 새 키가 그 경로로
처리된다 — 「`coverage`/`orchestration` 이 통째로 없을 때로 좁히면 직전 릴리스 세션이 어느 조건에도
안 걸린다」가 그 조건의 이유다.

### §G 데이터 흐름 한 장

```
seed «다시 검증할 것»  ─┐
                        ├─→ coverage-mapper ─┐
사용자 답 (라운드)      ─┤                    │
                        ├─→ blind-spot-prober ┤──→ evidence[] / repo_claims[]
landscape sweep         ─┤                    │     (계약 = research-claims.md,
                        └─→ steelman-builder ─┤      dispatch 프롬프트에 인라인)
C43 경로 (a) 자동확인  ──────────────────────┘
                                              │
                    ┌─────────────────────────┘
                    ▼
        finishing.md Step A — 검문소 C (무조건)
          경로 → 앵커 → 「그 자리가 주장과 맞는가」
          결과 {확인 | 반증 | 미확인} → audit 에 항목당 한 줄
          `반증` → payload §5 에 *원래 / 재결정 / 근거*
                    │
                    ▼
        payload §4 · §5 조사 항목   [닿는 결정: D<n>]      (부착)
        payload §3 OQ               → 근거 §5-R2           (역참조)
        payload §0 열린 결정        → 근거 §5-R2 · §3-OQ1  (요약 상호참조)
        audit §1 derived: 내부조사 — closed — ⟨S<N>⟩
                    │
                    ▼
        check_brief.py — 검문소 B (fail-closed)
          ∀ 부착(§4·§5) · ∀ 부착 대상이 §3·§0 에 실재
          ∀ 확인 줄(레포 주장) · 조건부 derived 하한
          레포 항목 0건 → advisory → Step B 게이트 question 본문
                    │
                    ▼
        brainstorming (읽을 이유는 있고 구속은 없다)
```

## Acceptance Criteria

- **AC1** `references/research-claims.md` 가 실재하고 `evidence[]`(웹) · `repo_claims[]`(레포) 두
  모양의 **유일한 정의**를 담는다. `agents/steelman-builder.md` 본문에 그 스키마의 두 번째 사본이
  없다(그 파일의 YAML 블록에 `repo_claims:` 정의 0건).
- **AC2** `conducting-interview/SKILL.md` 의 조사 dispatch 셋이 전부
  `<claims_contract>${CLAIMS_CONTRACT}</claims_contract>` 슬롯을 갖고, 같은 SKILL 안에 그 변수를
  `cat` 으로 채우는 펜스가 있고, 펜스의 실패 분기가 「dispatch 하지 않는다」를 말하며 rc 1 로 끝난다.
- **AC3** `agents/{steelman-builder,coverage-mapper,blind-spot-prober}.md` 의 `input_slots` 에
  `claims_contract` 항목이 있다.
- **AC4** `coverage-mapper`·`blind-spot-prober` 의 출력 규약이 `evidence[]`/`repo_claims[]` 를
  요구하고 각 항목에 `touches` 가 필수임을 명문화한다.
- **AC5** `research-claims.md` 가 「인덱스·레지스트리·목차·description 필드만 읽고 판정하지 말 것.
  구현을 읽어라」를 담고, 그 출처(`docs/archive/interview/2026-07-12-project-init-audit-interview.md`)를
  인용한다.
- **AC6** `references/finishing.md` Step A 에 「게이트-전 확인」 단계가 있고, 대상이 **레포
  주장(`repo_claims[]`)** 임을 말하며 (i) 경로 실재 (ii) 앵커 실재 (iii) 주장이 그 자리와 맞는가
  (iv) 결과 {확인, 반증, 미확인} (v) audit 에 항목당 한 줄을 적고, **steelman trigger 와
  `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 어느 것에도 종속되지 않음**을 명시한다.
- **AC7** `finishing.md` 가 확인 결과 `반증` 일 때 그 항목이 닿는 확정을 payload §5 에
  *원래 / 재결정 / 근거* 세 칸으로 남기고 **재결정은 사용자 동의로만** 함을 적는다.
- **AC8** `check_brief.py gate` 가 payload **§4·§5** 의 조사 항목마다 부착 필드를 ∀ 로 요구하고,
  **개수 술어를 갖지 않는다** — 조사 항목 0건 fixture 가 이 검사로 red 가 되지 않는다. §3 은 부착의
  출처가 아니라 대상이므로 이 검사의 순회 범위에 **없다**(§D).
- **AC9** 부착이 가리키는 결정 식별자가 같은 payload 의 §3·§0 어디에도 없으면 red. 이 검사가 §3
  역참조가 기계적으로 닫히는 유일한 자리이고, §3 쪽에 별 술어를 두지 않는다.
- **AC10** payload 에 레포 출처 항목이 ≥1 이면 audit §1 의 `derived: N/A` sentinel 만으로는 통과하지
  않고, 레포 출처 항목이 0건이면 sentinel 로 통과한다.
- **AC11** 레포 출처 항목 0건이면 `gate()` 의 `advisories` 에 「내부 조사 0건」 한 줄이 실리고,
  `finishing.md` Step B 가 그 줄을 proceed 게이트 `question` 본문에 싣는다고 적는다.
- **AC12** **레포 주장**에 대응하는 확인 줄이 audit 에 없으면 red. 웹 주장은 이 검사의 대상이
  아니다(N2 가 audit §7 결속을 이미 본다).
- **AC13** `SKILL.md` 가 dispatch 예산을 `1 + 재개방 횟수` 로 적고, state 스키마가
  `blind_spot_dispatches`(int)를 갖고, `state-migration.md` 가 그 키 부재를 migration 대상으로
  포함한다.
- **AC14** `SKILL.md` 의 C44 절이 면제 규칙을 「아직 조사가 닿지 않은 열린 결정 하나에 처음 닿을
  때만 +0 · 같은 결정 두 번째부터 +1 · 열린 결정 0이면 면제 0」으로 적는다.
- **AC15** C43 경로 (a) 행에서 리터럴 `[from-code][auto-confirmed]` 가 제거되고 계약 산출로
  교체된다. `plugins/` 하위에 그 리터럴 잔존 0건(`docs/archive/` 는 이력이므로 대상 아님).
- **AC16** 새 락 `tests/test_research_claims_contract.sh` 가 네 축을 갖는다 — A 산문 body-unique 문구 ·
  B 양의 짝(슬롯 개수) · C 펜스가 `cat` 하고 실패 분기 rc 1 · X 차가운 셸에서 펜스 실행(실제 루트면
  stdout 이 계약 내용, 계약 없는 루트면 rc 1 + 빈 stdout).
- **AC17** `.claude-plugin/plugin.json` 이 `3.3.0` 이고 `CHANGELOG.md` 에 해당 항목이 있고
  `tests/test_readme_sync.sh` 가 green 이다.
- **AC18** 착수 전 baseline 대비 새 RED 0 — rc 뿐 아니라 **실패 줄 수**까지 대조한다.
- **AC19** `templates/interview-brief-template.md` 가 세 방향을 각각 예시로 보인다 — §4·§5 의
  `[닿는 결정: D<n>]` 부착 · §3 OQ 의 `→ 근거 §5-R2` 역참조 · §0 의 요약 상호참조. 템플릿의 예시가
  곧 AC8·AC9 의 green fixture 와 같은 모양이어야 한다(템플릿이 red 를 가르치면 첫 게이트가 항상
  red 다 — 이 플러그인이 sentinel 에서 이미 겪은 결함이다).

## Files to Modify

| 파일 | 변경 |
|---|---|
| `plugins/spec-distill/references/research-claims.md` | **신규** — 계약 정본 (§A) |
| `plugins/spec-distill/agents/steelman-builder.md` | 인라인 스키마 제거 → 슬롯 (§A·§B) |
| `plugins/spec-distill/agents/coverage-mapper.md` | 슬롯 + 출력 의무 (§B) |
| `plugins/spec-distill/agents/blind-spot-prober.md` | 슬롯 + 출력 의무 (§B) |
| `plugins/spec-distill/skills/conducting-interview/SKILL.md` | 계약 `cat` 펜스 · dispatch 셋 슬롯 · 원장 `derived:` · C43 (a) · C44 계수 · dispatch 예산 · state 스키마 |
| `.../conducting-interview/references/finishing.md` | Step A 검문소 C 승격 · 반증 기록 · 부착·상호참조 · Step B advisory 배달 |
| `.../conducting-interview/references/steelman.md` | Step 2 를 공유 계약 참조로 (중복 제거) |
| `.../conducting-interview/references/state-migration.md` | 새 키 |
| `plugins/spec-distill/templates/interview-brief-template.md` | 세 방향 예시 — §4·§5 부착 · §3 역참조 · §0 상호참조 (AC19) |
| `plugins/spec-distill/templates/interview-audit-template.md` | §1 derived 예시 · 확인 줄 자리 |
| `plugins/spec-distill/scripts/check_brief.py` | 술어 둘 + 조건부 하한 + advisory (§E) |
| `plugins/spec-distill/tests/test_research_claims_contract.sh` | **신규** 락 (AC16) |
| `plugins/spec-distill/tests/test_check_brief.sh` + `tests/fixtures/` | AC8–AC12 |
| `plugins/spec-distill/.claude-plugin/plugin.json` | `3.2.0` → `3.3.0` (minor = 새 surface) |
| `plugins/spec-distill/CHANGELOG.md`, `README.md` | 항목 + Principles Instantiated |

## Verification Plan

1. **baseline 먼저** — 착수 전 전체 스위트를 돌려 rc 와 **파일별 실패 줄 수**를 기록한다. rc 만
   잡으면 이미 RED 인 파일 안의 새 실패가 원리적으로 안 보인다.
2. **새 락의 네 축** — AC16. `tests/test_dispatch_profile_inline.sh` 의 구조를 상속한다(그 락이
   같은 문제 — 「dispatch 슬롯에 경로가 아니라 내용을」 — 을 이미 네 축으로 잰다).
3. **게이트 술어의 red/green 짝** — AC8–AC12 각각 red fixture 와 green fixture 를 둘 다 만든다.
   부재 락은 양의 짝이 없으면 통째로 삭제해도 통과한다.
4. **변이(mutation)** — 네 축으로 흔든다: 표기 · 값 · 위치 · **제약의 부정형**. 열거로 축을 만들면
   내 mutation 이 락의 전제를 공유한다. `PYTHONDONTWRITEBYTECODE=1` (같은 길이 변이는 stale `.pyc`
   를 못 넘어 거짓 GREEN·거짓 RED 둘 다 낸다).
5. **양성 대조** — 변이 계측기 자체가 고장 날 수 있으므로, 반드시 RED 가 나와야 하는 변이 하나를
   먼저 확인한다. 양성 대조 없이는 RED 도 증거가 아니다.
6. **기존 스위트** — `test_check_brief.sh` · `test_conducting_interview_stage.sh` ·
   `test_brief_agents.sh` · `test_web_kill_switch.sh` · `test_readme_sync.sh` · `test_stale_terms.sh` ·
   `shared/tests/test_dispatch_disposition.sh` 전부. python 은 `-m unittest` 로만.
7. **픽스처 회귀 0 을 명시 확인** — `derived: N/A` 를 쓰는 기존 픽스처가 AC10 으로 red 가 되지
   않는지 파일 단위로 확인한다(AC10 의 조건부가 성립하는지가 이 설계의 ⟨C10⟩ 준수 증거다).

### Deferred to plan

- **OQ7 floor 리터럴 계수** — 착수 시 재도출하고 파일 밖 기대값으로 고정하지 않는다. 같은 축을
  세 번 재서 세 값이 나왔다(플러그인 범위 · 워크트리 전체 · steelman-builder 의 계수).
- **로드 표면 순증 실측** — 새 reference 1 + 슬롯 + 술어의 토큰 순증. 격리 설치로 배포 경로에서 잰다.
- **변이 매트릭스의 구체 항목**과 **픽스처 파일명 목록**.
- **e2e 수동 검증** — 실제 `/interview` 한 사이클. 자동화하지 않는다.

## Rejected Alternatives

- **R1 게이트 단독** — 새 reference 없이 `check_brief.py` 에만 ∀ 술어를 더한다. 기각: 게이트-전
  확인이 없으면 OQ17 의 실패 유형이 그대로 통과한다(폐기된 auto-confirm 범주 4건 중 3건은 근거가
  **실재하는 파일 경로**였고 틀린 것은 「그 자리가 주장과 맞는가」였다). 그리고 축 «전담 장치»가
  게이트로 흡수돼 ⟨C7⟩·brief §5 가 이미 기각한 모양(축 하나를 경량성으로 포장해 삭제)이 된다.
- **R2 원장 중심** — 내부 조사를 `derived:` 무조건 하한으로 세우고 항목 부착은 advisory 로. 기각:
  `derived: N/A` 를 쓰는 기존 픽스처 다수가 red 가 되어 ⟨C10⟩ 위반이고, 차원 admit 권한이
  피검자에게 있어(⟨D1.4⟩) 하한이 이빨을 못 갖는다.
- **R3 조사 장치를 하류에 둔다 (spec-kit 배치)** — brief §4 의 «spec-kit-plan» 은 전용 조사 단계가
  `/plan`(설계) 안에 있고 조사 과제를 상류 spec 의 미해결 unknown 에서 도출한다. 기각: ⟨C1⟩ 이
  「인터뷰 단계가 조사의 책임 주체」로 확정했다. 다만 ⟨C2⟩ 대로 하류 슬롯 부재를 단정하지 않으므로
  **도출 방식(decision-keying)은 취한다** — `touches` 가 그것이고, OQ18 의 실질은 이렇게 흡수된다.
- **R4 다섯 중 둘을 연기** — ⟨C8⟩ 을 P23 으로 재결정해 세 자리만. 기각: 승격 방식이 가산량을
  충분히 낮춰 연기가 불필요해졌고, seed ⟨S1⟩ 이 이 사이클을 부른 이유가 「2026-09-05 가 절반만
  확정하고 끝났다」라 같은 모양의 반복이 된다.
- **R5 새 장치 신설 + 삭제 권한** — 다섯 자리에 새 agent·새 절을 만들고 예산을 맞추려 기존
  장치·제약을 뺀다. 기각: 빼는 대상이 ⟨C3⟩ 이 보호하는 부류(되묻기·문제공간 탐색)라 사용자가
  못 박은 실패 조건을 설계가 직접 건드린다. OQ22 가 정면으로 경고한 경로다.
- **R6 「11 중 5가 0건」을 인과로 쓰기** — 결핍 (a) 를 코퍼스 18로 재측정해 진단을 보강한다.
  기각: 이 설계에서 하한을 조건부로 만든 근거는 픽스처 대가(⟨C10⟩)와 ⟨C5⟩ 이고 그 **수가 아니다**.
  코퍼스를 18로 다시 잡아도 설계가 바뀌지 않으므로 재측정의 값이 0이다(OQ21). brief §0 이 그 수를
  「측정된 상관까지만」으로 이미 한정했다.
- **R7 리터럴 마커 유지** — `[from-code][auto-confirmed]` 를 계약과 함께 둔다. 기각: 같은 행위가
  audit §5 프로세스 로그에 `auto-confirmed:` 라는 다른 표기로 이미 실재해(OQ20) 표기가 둘로
  갈려 있다. 갈라진 사본은 「한쪽만 고치는」 결함을 부른다 — 이 플러그인이 락으로 집행하는 바로
  그 논거다.
- **R8 하류에 구속 문구** — 「하류는 이 조사가 닿은 결정을 조사 없이 뒤집지 않는다」를 brief 에.
  기각: P23·금지 패턴 «Sealed decision» 과 정면 충돌하고, 반증 소버 경로가 아직 최소 형태뿐인
  상태에서 구속만 먼저 걸면 OQ12 의 위험을 관로화한다.

## Open Questions

**사용자만 답할 수 있고 아직 답이 없다 — 유추 금지.** 이 설계는 둘 없이 성립하지만, 답이 오면
진단의 하중이 바뀔 수 있다.

- **OQ-A** (brief OQ8) 이 요청을 다시 꺼내게 만든 구체적 사건. Phase 0 의 촉발 질문이 답 없이
  지나갔고 「그때 미완이라 · 조사 질 자체」로만 좁혀졌다. 첫 번째 시도가 왜 떨어졌는지는 이 사이클이
  구조 사실로 답했다(범위 밖 확정 + 산문 무발화). 사건 쪽은 여전히 미답이다.
- **OQ-B** (brief OQ10) 네 국면(한 번 훑고 끝 · 결정에 안 닿는다 · 내부 없이 외부로만 · 하류가 못
  쓴다)과 네 축 각각의 구체 사례. 사용자 판단이고 사례는 수집되지 않았다.

**범위 밖이지만 설계를 흔들 수 있다.**

- **OQ-C** (brief OQ11) 첫 사이클 레포에서의 수익률. 이 사이클의 측정 기반(brief 코퍼스 ·
  `docs/audits/`)은 devbrew 에만 있다. **부분 해소** — 조건부 하한이 이 문제의 답이기도 하다:
  건질 것이 없는 레포에서는 레포 항목이 0건이고 하한이 공허 통과하며 advisory 만 뜬다. 필수 필드가
  없으므로 brief §5 의 「필러 절」 압력이 구조적으로 사라진다. 남는 것은 그 환경에서 advisory 가
  소음이 되는지의 관측이다.
- **OQ-D** (brief OQ12) 반증 소비 경로의 **해결**은 여전히 범위 밖이다. 이 설계는 기록 형식만
  끌어왔다(§D). 전진 경로(반증 감지 → 차원 재개방 → 사용자 게이트 → 게이트 처분)는 다음 사이클이다.

## 알려진 한계

- **L1 조건부 하한이 피검자 산출물에 앵커돼 있다.** 레포 항목을 0건 내면 하한이 공허 통과한다.
  `check_brief.py` 는 brief 파일만 읽으므로(모듈 docstring 의 불변식) 「조사를 했어야 했는가」를
  알 방법이 없다 — 이 방향의 fail-open 은 기계적으로 닫히지 않는다. backstop 은 0건 advisory 가
  Step B 게이트 텍스트로 **사람에게 가는 것**이다. 개수를 재서 막으면 ⟨C5⟩ 위반이므로 이 방향을
  골랐다.
- **L2 면제 판정은 자기 신고다.** `non_user_streak` 는 세션 state 에만 살고 게이트는 state 를 읽지
  않는다(불변식). brief ⟨D1.3⟩ 이 그 기계 검사 가능성 주장을 이미 철회했다. 막는 것은 열린 결정이
  매 라운드 «다음 결정» 블록으로 사용자에게 보이는 것과 brief 리뷰 층 1(방향성)이다 — 둘 다 기계가
  아니다.
- **L3 부착의 «실재»는 보지만 «열려 있음»은 안 본다.** `D<n>` 이 §3·§0 에 있는지는 검사하지만 그
  결정이 진짜 열려 있는지는 안 본다. `landscape_keys_declared` 가 「키를 지어내도 통과한다」로 이미
  공시한 것과 같은 종류의 구멍이다(brief OQ3).
- **L4 검문소 C 의 3단계는 기계가 대신할 수 없다.** 「주장이 그 자리와 맞는가」는 내용 이해다.
  게이트가 보는 것은 「그 확인 줄이 항목마다 있는가」까지다.
- **L5 기존 코퍼스의 줄번호 인용 23건은 그대로 남는다.** 계약은 앞으로의 산출에만 걸린다(D9).
- **L6 로드 표면은 순증한다.** 삭제가 0이므로 새 reference 1 + 슬롯 + 술어가 그대로 더해진다.
  ⟨C8⟩ 이 그 대가를 명시적으로 수용했고, 양은 계획 단계가 실측한다.
- **L7 이 사이클의 brief 냉독이 하류 결함 둘을 관측했다.** ⟨S2⟩–⟨S12⟩ 앵커를 brief 만 보면 확인할
  수 없고(§6 은 `S1` 만 사는 것이 N1b 규약), 하니스 어휘가 설명 없이 쓰인다. 이 설계의 §D
  상호참조는 첫째를 완화하지 않는다 — 앵커는 audit 에 있고 하류는 audit 경로를 받지 않는다.
  brief OQ15 와 같은 뿌리이고, 이 설계는 그것을 해결하지 않는다.

## Concrete Next Action

1. 이 문서를 커밋한다(브랜치 `feature/interview-research-burden`).
2. `Skill spec-distill:reviewing-spec docs/superpowers/specs/2026-09-22-interview-research-specialization-design.md`
   — brainstorming 의 「다음은 writing-plans 뿐」 지시보다 이 순서가 우선한다.
3. 그 승인 게이트에서 진행을 고른 뒤 `superpowers:writing-plans`.

## 결정 기록

이 설계 세션에서 사용자가 고른 것(D1–D5)과 orchestrator 가 위임받아 정한 것(D6–D12).
A 군 10 · D 군 7 은 brief ⟨S12⟩·⟨D1.5⟩ 가 「설계가 받는다」로 처분한 것이다.

| id | 결정 | 출처 |
|---|---|---|
| D1 | 네 축을 **승격·재배치**로 만든다 — 새 agent·새 절·새 floor 키 0, 삭제 0 | 사용자 (OQ22) |
| D2 | 인계는 **읽을 이유까지만** — 부착·상호참조. 하류 구속 문구 없음 | 사용자 (OQ9) |
| D3 | derived 하한은 **조건부** · 레포 항목 0건은 **advisory** 로만 공시. 「조사를 전혀 안 해도 게이트는 초록」을 받아들인다 | 사용자 (OQ2·L1) |
| D4 | dispatch 예산 = `1 + 재개방` 을 `blind-spot-prober`·`coverage-mapper` 둘에 적용. **2026-07-20 coverage-driven 설계의 C8 재결정** — *원래* 「fan-out 1(인터뷰당 1회) — devbrew N≥5 hard review 게이트 미해당」 / *재결정* `1 + 재개방` / *근거* 현행 `CLAUDE.md` 는 숫자가 아니라 「선언」을 기준으로 하고(「규모 자체가 아니라 선언 없음이」), 재개방에는 사용자 답이 걸린다 | 사용자 (OQ19·§F) |
| D5 | OQ12 는 **최소 형태만** 끌어온다 — 반증 시 *원래/재결정/근거* 기록 규약 한 줄. 해결 경로는 범위 밖 유지 | 사용자 |
| D6 | OQ16 처분 = **검증 축**. Phase 0 을 안 건드리고(⟨C4⟩) Phase 1 이 Phase 0 의 레포 사실을 받아 검증한다. 근거: 양쪽 다 산문 한 줄이고, 이 사이클에서 seed 의 레포 사실 셋이 반증됐다 | orchestrator |
| D7 | OQ13 여미 선 = **게이트는 개수를 어디서도 세지 않는다.** ∀ 형태 술어만 | 사용자 승인 |
| D8 | OQ4·OQ20 처분 = 리터럴 마커 **폐기**, 개념은 계약으로 흡수 | orchestrator |
| D9 | OQ5 처분 = 기존 stale 인용 23건 **손대지 않는다**. 계약은 앞으로의 산출에만 | orchestrator |
| D10 | OQ21 처분 = 코퍼스 18로 **재측정하지 않는다**. 그 수가 설계 근거가 아니다(R6) | orchestrator |
| D11 | OQ14 처분 = 검문소 **둘** (Step A 확인 + 게이트 ∀ 대조) | orchestrator |
| D12 | OQ7 처분 = floor 리터럴 계수는 **계획으로 이월**, 설계에 숫자를 쓰지 않는다 | orchestrator (⟨S9⟩ 재확인) |
