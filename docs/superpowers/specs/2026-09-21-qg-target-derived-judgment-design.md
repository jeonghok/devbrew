---
name: qg-target-derived-judgment
type: design
created_at: 2026-09-21
source_interview: docs/superpowers/interview/2026-09-21-qg-target-derived-judgment-interview.md
next_phase: superpowers:writing-plans
interview_audit: docs/superpowers/interview/2026-09-21-qg-target-derived-judgment-interview.audit.md
plugin: quality-gates
version_target: major   # 정확한 번호는 머지 직전에 — 먼저 머지되는 쪽이 이긴다
---

# qg — 판정 구조를 대상에서 도출

> `clean` 은 「버그가 없다」가 아니라 「정확히 이만큼을 검증했다」여야 한다.

`quality-gates` 플러그인을 네 축(게이트 구조 · 리뷰어 구성 · 리뷰 스코프 · 차등 정밀도)에서
동시에 재편해, 판정 구조를 **대상에서 도출**한다.

## 목차

- [1. Context · Why](#1-context--why)
- [2. Goals](#2-goals)
- [3. Non-goals](#3-non-goals)
- [4. 결정 D1–D6](#4-결정-d1d6)
- [5. 제약의 반영](#5-제약의-반영)
- [6. 설계](#6-설계)
  - [6.1 파이프라인 골격](#61-파이프라인-골격)
  - [6.2 스코프 — 커밋 집합 모델](#62-스코프--커밋-집합-모델)
  - [6.3 각도 바닥 · 리뷰어 도출 · 재비판](#63-각도-바닥--리뷰어-도출--재비판)
  - [6.4 차등 테스트 · 해상도 공시 · 판정 어휘](#64-차등-테스트--해상도-공시--판정-어휘)
  - [6.5 공개 표면 · 이주 · 헌장](#65-공개-표면--이주--헌장)
- [7. 실측 근거](#7-실측-근거)
- [8. 재결정 기록 P23](#8-재결정-기록-p23)
- [9. brief 정정 셋](#9-brief-정정-셋)
- [10. Open Questions 처분표](#10-open-questions-처분표)
- [11. Acceptance Criteria](#11-acceptance-criteria)
- [12. Files to Modify](#12-files-to-modify)
- [13. Verification Plan](#13-verification-plan)
- [14. Rejected Alternatives](#14-rejected-alternatives)
- [15. 알려진 한계](#15-알려진-한계)
- [16. 구현 분할](#16-구현-분할)
- [결정 기록](#결정-기록)
- [Handoff Context](#handoff-context)
  - [Deferred to plan](#deferred-to-plan)
- [Metadata](#metadata)

## 1. Context · Why

qg 의 구조가 **「부팅되는 웹앱 · 고정 리뷰 관점 · 한 브랜치 PR」** 을 전제로 굳어 있는데 실제
대상은 그 전제 밖에 있다. 그래서 셋이 동시에 일어난다 — 가장 비싼 게이트가 아무것도 검증하지
못하고, 무관한 리뷰어가 매번 불리고, 한 작업이 판정 단위로 안 잡힌다.

진짜 문제는 성능이 아니라 **대상 모델의 어긋남**이다. 따라서 해법도 게이트를 빠르게 만드는 것이
아니라 **판정 구조를 대상에서 도출**하는 것이다.

## 2. Goals

- **G1** — 무엇을 검증할지 · 누가 검증할지 · 무엇을 대상으로 할지 · 무엇을 회귀로 셀지를 전부
  대상에서 도출해, `clean` 이 그 실행에서 실제로 검증된 것과 일치하게 만든다.
- **G2** — 그 일치를 네 축에서 동시에 만든다. 어느 한 축의 성과가 다른 축의 결손을 갚지 않는다.
- **G3** — 「검증하지 못했다」를 `clean` 과도 실패와도 다른 **일급 판정값**으로 만든다.

## 3. Non-goals

- 리뷰어를 더 많이 부르는 것. 외부 실측이 역할 자리를 늘리는 것 자체가 신뢰도를 사주지 않음을
  보인다(brief §4 «cr-benchmark» · «submodularity»).
- 「도출」을 이유로 결정론적 보장을 0으로 만드는 것. 명단은 버리되 각도 의무와 그 집행 장치는
  남는다.
- 차등 테스트 실행 자체를 없애거나 선택적으로 만드는 것.
- spec↔브랜치 묶음을 문서 사슬 추론으로 세우는 것.
- **차등 테스트 기계 자체를 다른 것으로 바꾸는 것**(brief OQ5). 지금 기계는 여러 라운드의
  하드닝을 거쳤고, 교체는 신뢰도 하한을 올리지 않으면서 단순함을 크게 깎는다 — D1 상 범위 밖.
- **부팅되는 앱의 런타임 행위 검증**. 대체하지 않고 **주장을 거둔다**(§6.5).

## 4. 결정 D1–D6

인터뷰 brief 의 열린 질문 중 사용자 소유였던 여섯. 이 결정들이 나머지를 계산으로 바꿨다.

| id | 질문 | 결정 |
|---|---|---|
| **D1** | 성공 척도 넷이 부딪히면 무엇이 이기는가 (OQ4) | **신뢰도는 저울 위가 아니라 후보 자격**이다. `clean` 이 실제 검증된 것과 어긋나게 만드는 안은 애초에 후보가 아니다. 그 필터를 통과한 안들 사이에서 비용·시간 / 단순함 / SDD 맞물림 셋을 대등하게 저울질하고, 셋이 부딪히면 **단순함**이 이긴다. |
| **D2** | C14(차등 정밀도)를 어떻게 하는가 (OQ18) | **「해상도 공시」로 재결정.** 파서 층을 만들지 않고, `(F,F)` 구멍을 닫는 대신 **드러낸다**. |
| **D3** | 선언을 무엇이 담는가 (C12 하위) | **커밋 트레일러 `Spec: <리포-상대 경로>`.** |
| **D4** | 묶음이 미완일 때 무엇을 하는가 (OQ10) | **지금 실재하는 것을 묶고**, 판정 산출물에 본 커밋 집합과 각 SHA 를 싣는다. |
| **D5** | codex 를 어느 층에 두는가 (OQ2) | **C13 의 각도 목록에 세 번째 각도 「다른 전제」로 편입.** 3단계 Tier 개념이 사라진다. |
| **D6** | 재편된 qg 의 큰 모양 (C19 하위) | **한 파이프라인.** 게이트 두 이름을 없앤다. |

**D1 은 C1 의 근거 있는 재결정이다(P23 — 전문은 §8).** 원문 C1 은 「넷은 대등하고 어느 하나가
다른 것을 대체하지 않는다」였고 §14 는 「넷 전부의 엄격 전순서」를 기각한다. D1 이 깐 「셋이
부딪히면 단순함」은 약하지만 **여전히 부분 순서**다 — 숨기지 않고 재결정으로 기록한다.

**D1 의 적용 방식** — 갈림마다 두 줄을 적는다: ⑴ 이 안이 신뢰도 하한을 깨는가(깨면 탈락) ⑵ 남은
셋 중 무엇이 이겼는가. **이 두 줄은 설계문서의 «모든» 선택이 아니라 D1 이 실제로 갈랐던 네 자리
(§6.1 · §6.2.4 · §6.3.1 · §6.4.2)에 붙어 있다** — 나머지 선택은 확정 제약이나 실측이 직접 정한
것이라 저울질이 없었다.

**관측 — 네 자리 전부에서 단순함이 이겼다.** 비용·시간이나 SDD 맞물림이 이긴 갈림은 0건이다.

## 5. 제약의 반영

인터뷰가 확정한 19항목(brief §2)과 이 설계의 대응. **어느 것도 침묵으로 처리하지 않는다.**

| 제약 | 반영 |
|---|---|
| C1 척도 넷 대등 | D1 이 「대등」을 깨지 않는 방식으로 충돌 규칙을 세움 |
| C2 verifier 와 딸린 것만 제거 | §6.1 · §6.4.1 — 제거 목록 일곱 전부에 처분 부여 |
| C3 실행 주체는 오케스트레이터 | §6.1 단계 ② — verifier 가 없으므로 self-report 경로 자체가 소멸 |
| C4 차등 테스트는 항상 | §6.1 표 · §6.4.3 — kill switch 경로는 `not-certified` |
| C5 리뷰어는 스코프 도출 | §6.3.1 — 각도는 고정, **수행자**가 도출됨 |
| C6 Tier A 바닥 제거 | §6.3.1 — 명단 2인 전용 디스패치 형태 소멸 |
| C7 adversarial → 출처-제거 재비판 | §6.3.3 |
| C8 브랜치 전부가 한 리뷰 대상 | §6.2 — 브랜치가 아니라 **커밋 집합**으로 일반화 |
| C9 경계는 spec/design 문서 | §6.2 — 트레일러 값이 그 문서 경로 |
| C10 기준선은 작업 시작점 | §6.2 경계 규칙 — merge-base 를 쓰지 않음 |
| C11 goal = 판정 구조를 대상에서 도출 | G1 |
| C12 묶음은 선언이 담는다 | D3 |
| C13 바닥의 축을 명단 → 각도 | §6.3.1 |
| C14 정밀도는 자리별 원장 | **D2 로 재결정** — §8 |
| C15 공개 계약 + 헌장 동시 이동 | §6.5.3 |
| C18 재비판 계약에 diff 슬롯 + 도입-게이트 | §6.3.4 |
| C19 게이트 범위 공개 인자 제거 | §6.5.1 — **셋이 아니라 11 자리**(OQ15 가 맞았다) |
| C20 커밋 봉인·두 축 트리 배관 존치 | §6.4.1 — 봉인자는 워크트리 없이 산다 |
| C21 HEAD 축은 합친 한 트리 | §6.2 — `merge-tree --write-tree` |

## 6. 설계

### 6.1 파이프라인 골격

`/qg` 는 게이트가 없는 **한 파이프라인**이고 판정도 하나다.

| # | 단계 | 소유 | 빠질 수 있나 |
|---|---|---|---|
| ① | **스코프 해소** — 선언 → 커밋 집합 → 경계·끝점 → 두 축 트리 | 결정론 스크립트 | 아니오 |
| ② | **차등 테스트** — 기준선 축·HEAD 축 양쪽에서 오케스트레이터가 직접 | 결정론 | trivia escape · kill switch 만 |
| ③ | **각도 도출 + 리뷰어 디스패치** | 수행자는 모델, 각도 의무는 결정론 | 아니오 |
| ④ | **출처-제거 재비판** | 공유 문서-리뷰 엔진 | 아니오 |
| ⑤ | **합성 · 판정 · 공시** | 결정론 | 아니오 |

**②가 ③보다 앞인 것이 load-bearing 이다.** 테스트 결과가 ③의 각도 도출 입력이 되고, 그만큼
「도출의 입력을 피검자가 쓴다」(OQ14)가 완화된다 — diff 는 피검자가 쓰지만 **테스트 결과는 실행이
낸다.**

**「게이트」라는 이름을 지우는 이유** — C19 가 게이트 범위를 고르는 인자를 없애면 고를 것이 없다.
헌장이 「막지 않는 것을 막는다고 믿게 만드는 선언은 없는 것보다 나쁘다」고 적고 있고, 고를 수
없는 두 게이트가 정확히 그것이다.

*D1: 하한 무관(판정 내용이 안 바뀜) → 단순함이 이김.*

### 6.2 스코프 — 커밋 집합 모델

#### 6.2.1 선언

커밋 트레일러 **`Spec: <리포-상대 경로>[#<조각>]`**. 작성자가 쓰고, qg 는 그것만 읽으며 문서에서
추론하지 않는다(C12).

**선언의 입도는 «한 설계문서»가 아니라 «한 번에 머지되는 묶음»이다.** 한 설계문서가 여러 PR 로
나뉘면(§16) 각 PR 이 자기 조각을 선언한다 — `…-design.md#pr1` · `…#pr2` … . 이유는 §16 의
분할이 이 모델과 부딪히기 때문이다: 다섯 PR 이 **같은** 값을 선언하면 PR2~5 의 매 `/qg` 가 이미
머지된 앞 PR 전부를 합집합으로 보고(AC3·AC4 가 그것을 요구한다) 기준선이 PR1 직전에 고정돼,
**분할이 리뷰 1회의 분량을 줄이지 못하고 같은 커밋이 최대 다섯 번 재리뷰된다.** 이번 재편의
발단이 바로 그 비용 축이다.

- **C8 은 그 묶음 «안»에서 유지된다** — 「한 작업의 브랜치 전부가 한 대상」의 «한 작업»이 «한 번에
  머지되는 것» 으로 읽힌다. 한 PR 이 브랜치 셋으로 이뤄지면 그 셋이 한 대상이다.
- **C9 도 유지된다** — 경계를 정하는 것은 여전히 spec/design 문서이고, 조각은 그 문서 «안»의
  분할을 가리킬 뿐 다른 문서를 가리키지 않는다.
- **조각 없는 값도 유효하다** — 분할하지 않는 흔한 경우가 기본형이다.

이 리포는 이미 커밋 트레일러를 쓴다 — 최근 200 커밋 중 `Claude-Session` 172개 ·
`Co-Authored-By` 189개(실측 §7-B). 새 배관이 아니다.

#### 6.2.2 토픽은 브랜치가 아니라 커밋 집합이다

```
C   = git log --all --grep='^Spec: <토픽키>$' --format='%H'              # 선언 커밋
B_t = C 의 원소를 «담은» 토픽 브랜치 집합                                  # 아래 도출 규칙
T   = ⋃(b ∈ B_t) [ rev-list(b) \ rev-list(경계) ]                        # 토픽이 담은 커밋 전부
```

**토픽 키는 트레일러 값 «전체»다 — 조각까지 포함한다.** `…-design.md#pr1` 과 `…-design.md#pr2`
는 **서로 다른 토픽**이고, 질의는 그 값에 정확히 일치하는 것만 받는다. 조각을 무시하는 질의를 쓰면
다섯 PR 이 한 토픽으로 합쳐져 §6.2.1·§16 이 조각 표기를 도입한 이유가 그대로 되돌려진다.
AC3 의 「`Spec:` 트레일러를 가진 커밋」도 **「같은 토픽 키를 가진 커밋」**으로 읽는다.

**선언은 «그 커밋이 토픽이다»가 아니라 «그 커밋이 달린 브랜치가 토픽이다»를 뜻한다.** 트레일러
하나면 그 브랜치 전체가 들어온다. 이유는 §15-8 의 시나리오다 — R→A→B 에서 A 부터 작업했는데 B 에만
트레일러를 붙이면 커밋 단위 해석에서는 `T={B}` · 기준선=A 가 되어 **A 의 회귀가 선재 결함으로
숨는다.** C10 의 「그 작업 전체를 한 덩어리로」가 깨지는 자리다.

**`B_t` 의 도출 — `git branch --contains` 를 쓰지 않는다.** §7-C 가 그것을 봉했다(머지된 커밋에
대해 `main` 과 후손 전부를 돌려준다). 대신:

1. **살아 있는 ref** — `git for-each-ref refs/heads` **와 `refs/remotes`** 중 `C` 의 원소를
   포함하면서 **`base_ref` 의 조상이 아닌** 것(§8 재결정 — 근거는 그 절 참고). `main` 과 무관한
   브랜치는 `C` 를 포함하지 않으므로 자동으로 빠진다. 로컬 브랜치와 그 원격-추적 대응이 같은
   커밋을 가리키면 커밋 SHA 로 중복을 접고 로컬 ref 이름을 표시에 남긴다.
2. **머지된 구성원** — `C` 의 원소 `c` 가 **1단계가 낸 `B_t` 에 들어가지 않으면**(ref 가 지워졌든,
   ref 는 남았지만 그 tip 이 이미 `base_ref` 의 조상이든 **둘 다** 이 갈래다), `c` 를 처음
   담은 머지 커밋 `m`(= `git rev-list --ancestry-path --merges c..base_ref | tail -1`)의
   **주제 쪽 부모**를 그 브랜치의 끝으로 쓴다.
3. 1·2 가 **둘 다** 답을 못 내면 그 선언 커밋은 **고아**다 — `not-certified (declaration-invalid)`.
   머지된 브랜치는 2단계가 반드시 받으므로 AC4(「이미 `main` 에 머지돼 있어도 토픽에 포함된다」)가
   여기서 깨지지 않는다.

> 도출의 정확한 명령 형태와 `--ancestry-path` 의 경계 조건은 §Deferred to plan 이다. 이 절이
> 못 박는 것은 **「`git branch --contains` 를 쓰지 않는다」와 「세 갈래 전부에 답이 있다」** 다.

**브랜치 모델을 쓰지 않는 이유는 실측 둘이다**(§7-C · §7-D):

1. `git branch --contains` 는 머지된 커밋에 대해 `main` 과 그 후손 브랜치 전부를 돌려준다 —
   실측에서 커밋 35개가 매번 브랜치 5개를 내놨다. 토픽의 끝점을 이걸로 못 찾는다.
2. 이미 머지된 앞 브랜치는 `base..branch` 범위 스캔에서 **통째로 안 보인다.** seed 가 이름 붙인
   결함(「스택에서 앞 브랜치가 이미 머지됐으면 그 변경은 지금 안 보인다」)이 선언 기반 스코프에서
   그대로 재발하는 자리다.

커밋 집합 모델은 둘 다 피한다. 비용도 문제가 아니다 — 2409 커밋 리포에서 값 하나로 좁히는 데
40ms(실측 §7-A).

#### 6.2.3 기준선 = 작업 시작점 (C10 · OQ16)

```
fork(b) = merge-base(base_ref, b)        # 각 토픽 브랜치가 기반에서 갈라진 지점
경계    = |B_t| == 1 ? fork(그것) : merge-base(fork(b) for b ∈ B_t)
```

**경계를 브랜치에서 뽑는다** — `parents(T) \ T` 를 쓰면 `T` 를 먼저 알아야 하는데 `T` 의 정의가
경계에 의존해 순환이 된다. 브랜치의 분기점에서 뽑으면 순환이 없고, R→A→B 에서 A·B 가 모두 R 에서
갈라지므로 경계가 **R** 이 되어 C10 이 지켜진다.

**이미 머지된 구성원** — `fork(b)` 가 `base_ref` 안쪽으로 들어오면(앞 브랜치가 머지된 경우)
그 브랜치의 **주제 쪽 첫 커밋의 부모**를 `fork` 로 쓴다. 이것이 없으면 머지된 앞 브랜치의 회귀가
기준선에 숨는다 — seed 가 이름 붙인 바로 그 결함이다.

**이 규칙은 선언과 별개의 값이 아니라 히스토리에서 도출된다.** 그래서 「피검자가 무엇이 선재
결함인가까지 정한다」(OQ16)가 성립하지 않는다.

*실측 검증(§7-E)* — devbrew 자신의 한 토픽(|T|=35)에 이 규칙을 걸었더니 경계 2개가 나왔고 그
merge-base 가 `add4c9cd` 였다. 그 커밋은 그 작업이 실제로 시작된 직전 지점(PR #155 머지)이다.
**규칙의 «모양»이 사람이 아는 답과 일치했다.**

> 그 실측은 `T` = 선언 커밋 집합에 `parents(T) \ T` 를 걸어 돌렸다. 지금 경계는 **브랜치
> 분기점**에서 나오므로 **같은 토픽으로 새 규칙을 다시 돌려야 한다**(§7 의 재검증 목록).

경계가 여럿인 정상 원인은 **토픽 중간의 main 병합**이다(그 두 번째 부모가 경계에 든다). 그때
merge-base 를 쓰면 그 병합이 가져온 남의 변경까지 diff 에 든다 — §15 의 알려진 한계.

#### 6.2.4 HEAD 축 = 합친 한 트리 (C21)

- **끝점** — **치환이 아니라 «먼저 넣고 계산»이다.** 봉인 커밋 `B`(§6.4.1)를 후보 집합에 먼저
  넣고, 그다음 `{tip(b) : b ∈ B_t} ∪ {B}` 의 **극대원소**(다른 원소의 조상이 아닌 것)를 끝점으로
  삼는다. 끝점이 선언 «커밋»이 아니라 브랜치의 «끝»이므로 마지막 선언 커밋 뒤에 달린 커밋도
  합친 트리에 든다.
  > 치환으로 쓰면 **현재 브랜치가 다른 구성원 브랜치의 조상일 때 넣을 자리가 없다.** 스택 A→B 에서
  > 현재 체크아웃이 A 면 `tip(A)` 는 `tip(B)` 의 조상이라 극대원소가 아니고, 「끝점 중 현재
  > 브랜치의 것을 치환」할 대상이 없어 A 의 커밋 안 된 변경이 HEAD 축에서 **조용히 사라진다**
  > (AC6 불만족). `B` 는 `tip(A)` 의 «자식»이라 먼저 넣으면 그 자신이 극대원소로 선다.
  > 부수 효과 — 그 둘이 충돌하면 `not-certified (merge-conflict)` 가 나는데 그것이 맞는 답이다.
- **합치기** = `git merge-tree --write-tree` 를 끝점들에 **순차** 적용. 워크트리가 필요 없다.
  C21 원문이 「머지 결과 **또는 octopus**」로 두 형태를 이름 붙였는데 순차를 고른 이유는 §14 에 있다.
- **순서** = 선언 커밋의 topo-order. 결정론으로 고정한다.
- **충돌** = `rc 1`(실측 §7-F). 그 실행은 `not-certified (merge-conflict)` 이고 충돌 파일 목록을
  싣는다.
- 순차 합치기는 `commit-tree` 중간 커밋을 만들고 그것은 unreachable 로 남는다(실측 §7-G) →
  기존 `qg-gc.py` 경로에 편입한다.

**OQ17 의 성숙형(한 구성원 실패 시 그것 없이 재테스트)은 취하지 않는다.** 충돌이 「판정 불가」로
렌더되는 한 신뢰도 하한이 지켜지고, 그다음은 단순함이 이긴다. 순서만 결정론으로 고정한다.

*D1: 하한 지켜짐(충돌 → not-certified) → 단순함이 이김.*

#### 6.2.5 세 스코프 모드의 처분 (OQ1)

새 스코프가 **기본**이고 `paths` · `branch` · `session` 은 **override 로 존치**한다. seed 원문이
「기본으로」라 했고, 선언 없는 브랜치에는 fallback 이 필요하다. 선언이 없으면
어느 `not-certified` 사유로도 막히지 않고 **기존 세 모드로 내려간다** — 선언은 새 능력이지
새 의무가 아니다.

#### 6.2.6 산출물이 싣는 것 (D4 · OQ6)

판정 산출물은 다음을 함께 싣는다: **본 커밋 SHA 전부 · 끝점 · 경계 · 합친 트리 OID.**

`clean` 은 그 튜플에 대한 clean 이다. 나중에 트레일러를 고쳐도 이미 난 `clean` 이 다른 대상의
판정으로 재사용되지 않는다 — OQ6 의 「재선언」 절반이 이 한 장치로 닫힌다. 「충돌」 절반은 spec
경로가 리포 안에서 유일하므로 원천적으로 없다.

**봉인은 끝점이지만 토픽 커밋이 아니다.** `T` 는 §6.2.2 의 정의 그대로 `B_t`(브랜치 집합)에서
도출되고, 봉인 커밋은 `B_t` 의 원소가 아니다 — 그래서 봉인의 부모가 `B_t` 의 어느 구성원에도
안 담기면(다른, 토픽 밖 브랜치에서 갈라졌으면) 봉인은 「토픽 위」가 아니다. 이때도 판정은
막히지 않는다 — `T` 가 `B_t` 에서 뽑히므로 그 오염이 애초에 `T` 에 들어오지 않기 때문이다.
다만 그 사실 자체는 공시한다: `seal_on_topic: no`. 봉인의 부모가 `B_t` 어느 구성원의 조상(자기
자신 포함)이면 `seal_on_topic: yes` 다.

#### 6.2.7 선언 창의 양끝 (OQ14 잔여)

**끝점 «뒤»의 커밋은 이제 빠지지 않는다** — 끝점이 선언 커밋이 아니라 브랜치의 끝이기
때문이다(§6.2.4). 그래서 남는 것은 아래 «앞»쪽 하나다.

경계보다 앞선 커밋이 그 브랜치에 있으면(= 선언을 늦게 붙였으면) **그 수를 공시한다.**
`resolve-baseline.sh` 의 `ahead:` 키와 같은 모양이고, 같은 이유로 막지는 않는다 — 신뢰 채널이
없다. 막으면 「작업 도중에 spec 으로 묶기로 마음먹는」 흔한 경로가 rebase 강제가 되고, 이미 머지된
앞 브랜치는 rebase 가 불가능해 영원히 묶을 수 없게 된다.

### 6.3 각도 바닥 · 리뷰어 도출 · 재비판

#### 6.3.1 각도 셋 (C13 + D5)

| 각도 | 묻는 것 | 다른 리뷰어에 접어 넣기 | 부재 시 |
|---|---|---|---|
| **보안** | 이 변경이 악용 가능 경로를 여는가 | 가능 | 공시 + `clean` 아님 |
| **판정** | 나온 finding 이 진짜인가 · 놓친 게 있는가 | **다른** 리뷰어에게만 가능 | 공시 + `clean` 아님 |
| **다른 전제** | 전제를 공유하지 않는 모델이 같은 것을 보는가 | 불가(같은 모델이 다른 전제를 연기할 수 없다) | 공시, **막지 않음** |

셋째 행의 비대칭이 헌장 그대로다 — 「모델 다양성 손실은 공시하고 막지 않는다」. 앞 둘은
**소실·부재**라 막는다.

**판정 각도의 「다른 리뷰어에게만」이 C13 과 Law 2 를 동시에 만족시키는 방식이다.** C13 은 작은
스코프에서 각도를 다른 리뷰어 프롬프트에 접어 넣는 것을 허용한다. Law 2 는 finding 을 «낸» 패스가
그 finding 을 판정하는 것을 금한다. 둘을 겹치면 답이 하나로 떨어진다 — **접어 넣되 자기 자신에게는
안 된다.** 즉 판정 각도는 전용 재비판 패스로 채우거나, finding 을 내지 않은 다른 리뷰어에게 접어
넣거나, `absent` 로 공시된다. 「자기 finding 을 자기가 판정」은 `folded_into` 값으로 쓸 수 없고,
합성기가 그 조합을 거부한다(AC10a — **판정 각도에 한정**한다. 보안 각도는 그 리뷰어가 finding 을
내는 것이 정상이다).

**각도 ≠ 에이전트.** 각도는 「채워졌는가」의 술어이고 수행자는 스코프가 정한다. 그래서 C6(명단
제거)과 C13(각도 의무)이 충돌하지 않는다 — C6 이 닫은 것은 「명단 2인을 매 iteration 전용
에이전트로 무조건 디스패치」라는 **형태**이고, C13 이 세운 것은 그 형태가 지키고 있던 **coverage**
다.

**D5 의 효과** — codex 가 별도 Tier B 가 아니라 세 번째 각도가 되면서 **3단계 Tier 개념이 통째로
사라진다.** 남는 것은 「각도 의무 + 도출된 수행자」 한 기계뿐이다.

*D1: 하한 지켜짐(부재가 clean 을 막음) → 단순함이 크게 이김(Tier 소멸).*

#### 6.3.2 교체 락의 앵커 (OQ12)

명단-리터럴 락(`plugins/quality-gates/tests/test_review_floor_lock.sh`)을 지우고 **각도 coverage
락으로 교체한다.** 교체 없는 삭제는 별개 결정이 아니라 C13 위반이다.

앵커는 **피검자가 쥘 수 없는 것**이어야 한다:

- ✗ SKILL.md 산문 — 피검자가 쓴다
- ✗ 각도 이름 리터럴 — 명단 락의 반복
- ✓ **합성기 출력 스키마의 ∀ 관계** — `synthesize_findings.py` 가 각 각도의 상태를
  `filled` / `folded_into:<수행자>` / `absent` 의 **총 함수**로 내고, 각도 하나라도 상태가 없으면
  스키마 검증 RED

오늘 `diff-test-results.py` 의 16칸 총 함수와 같은 모양이다 — **열거가 아니라 총 함수.**

**음의 짝** — 부재 락만 두면 통째로 삭제해도 통과한다. 그래서 양의 락을 함께 둔다:
**보안 또는 판정 각도가 `absent` 인데 판정이 `clean` 으로 렌더되면 RED.** 「다른 전제」 각도는
이 락의 대상이 아니다 — 그 부재는 공시하되 막지 않는다(§6.3.1 셋째 행).

#### 6.3.3 재비판 — 빈 입력 처분 (OQ13)

`quality-gates:adversarial` 자리를 공유 문서-리뷰 엔진의 **출처-제거 재비판**으로 바꾼다(C7).

- 탐지가 0건이어도 **재비판을 디스패치한다.** 슬롯이 비었다는 사실을 프롬프트에 명시한다.
- 탐지 0 · 재비판 0 이면 `clean` 이되, 판정 표면에 **「탐지 0 · 재비판 0」을 싣는다** — 침묵과 0
  은 다른 사실이다.

#### 6.3.4 diff 슬롯과 도입-게이트 (C18 · OQ9)

**사본 비용은 파일당 한 줄이되, 그 락은 ∃ 다.** `shared/tests/test_copy_of_contract.sh` 는
`plugins/** shared/**` 를 guards 로 잡지만 **세 축의 한정사가 다르다** — 심볼릭 링크 축과 import
형제 축은 ∀ 도미넌스이고, **`copy-of:` 축은 마커를 가진 파일만 훑는다**(마커가 없으면 `continue`).
즉 **있는 사본이 어긋나는 것은 잡지만 «빠진 사본»은 못 잡는다**. `shared/README.md` 가 그 차이를
명시한다(실측 §7-H).

→ qg 의 새 사본은 정확히 「빠질 수 있는 자리」다. 그래서 **∀ 락을 하나 더 단다** — 다만 그 대상은
「사본 셋 전부」가 **아니다.** `shared/tests/test_dispatch_disposition.sh` 가 `plugins/*/agents/*.md`
를 전수 훑어 **agent 정의마다 dispatch ≥ 1 을 면제 없이** 요구하기 때문이다(설계 스스로 §12 에서
그 락을 근거로 `adversarial.md` 를 지운다 — 같은 논리가 새 사본에 역방향으로 걸린다).

→ **AC22 의 대상은 「그 플러그인이 실제로 디스패치하는 docreview agent」다.** qg 의 코드 경로는
재비판자 하나만 부르므로 사본도 `doc-recritic.md` **하나**다. 탐지 층은 qg 가 이미 가진 코드
리뷰어들이 맡으므로 `doc-critic`·`doc-critic-web` 사본은 **만들지 않는다**. 락은 「디스패치하는데
사본이 없다」와 「사본이 있는데 디스패치하지 않는다」 **양쪽**을 잡는다.

남는 것은 **슬롯 락의 동반 이동**이다. `shared/tests/test_docreview_agents.sh` 가 재비판자 입력
슬롯을 정확히 셋(`document` · `findings` · `profile`)으로 락하고 있고, **그 락은 spec-distill 의
브리프 경로도 지배한다.**

→ diff 를 **선택 슬롯**으로 더한다(`kind: repo_context`, 부재 허용). 브리프 경로는 싣지 않고 코드
경로만 싣는다. 락 기대값이 한 번 움직이고, **`diff` 만 optional** 임을 락이 명시한다.

**「이 변경이 도입했는가」 게이트** — 재비판자의 판정 축으로 더한다. diff 가 있으면 「선재 결함」을
기각 사유로 쓸 수 있고, 없으면 그 축을 쓰지 않는다.

**출력 계약의 차이는 «입력»과 별개 문제이고, 변환 계층을 qg 가 소유한다.** 재비판자는 항목을
`f` 로 식별하고 신규 발견을 `added` 로 내며 `raise`/`to`/`same_as` 를 쓴다. `synthesize_findings.py`
는 `finding_id` 로 연결하고 `new_findings` 만 읽으며 신규 발견에 `file`·`severity`·`summary` 를
요구한다. **그대로 이으면 기각이 원래 finding 에 반영되지 않고 `added` 가 누락된다.**

→ qg 쪽에 **변환 한 자리**를 둔다:

- **`f` ↔ `finding_id` 역매핑** — 익명화할 때 만든 매핑을 보관했다가 역으로 쓴다(그 라운드 안에서만 산다).
- **`added` → `new_findings`** — `file`·`severity` 는 diff 슬롯에서 도출하고, 도출할 수 없으면
  **「미지」로 공시한다**(값을 발명하지 않는다).
- **`raise`/`to`** — 코드 경로의 severity 어휘로 매핑하고, 매핑 못 하는 값은 소실이 아니라
  **강제(coercion)** 로 계수한다(헌장 — 강제가 게이트 판정을 바꾸면 degrade 다).

**변환을 공유 층에 두지 않는 이유** — 그러면 `shared/docreview` 가 코드 경로의 어휘를 알게 되고
spec-distill 의 문서 경로까지 그 어휘를 지고 다닌다. 임피던스는 **경계를 넘는 쪽**이 흡수한다.

**프레이밍 맹목성과 충돌하지 않는다.** 재비판자가 맹목이어야 하는 것은 「왜 이 리뷰가 열렸나 ·
앞 리뷰어가 무엇이라 했나」다. diff 는 출처가 아니라 **대상**이고 문서 자신과 같은 층의 1차
자료다. 슬롯 `kind` 어휘가 이미 그 선을 긋고 있다 — `artifact` · `repo_context` 는 허용,
`prior_verdict` · `orchestrator_framing` 은 **락으로 금지**. diff 는 `repo_context` 다.

#### 6.3.5 처분 회계의 기대값 앵커 (헌장 · 브리프 §5 blind spot)

브리프 §5 가 이름 붙인 위험 — 「항상-디스패치 바닥은 도구 표면이 아니라 회계의 **기대값 앵커**
이기도 했다. 전부 도출로 내리면 도출이 잘못돼 아무도 안 불린 실행과 정상적으로 아무도 필요 없던
실행이 회계상 같은 모양이 된다」 — 의 처분:

**각도 셋이 새 기대값 앵커다.** 회계가 기대하는 것이 「몇 명이 불렸나」에서 「각도 셋이 전부 상태를
가졌나」로 옮겨간다. 그러면 두 실행이 **갈라진다**:

| 실행 | 회계가 보는 것 |
|---|---|
| 도출이 잘못돼 아무도 안 불림 | 각도 `absent` → 공시 + `not-certified (angle-absent)` |
| 정상적으로 아무도 필요 없었음 | 각도 `filled` 또는 `folded_into:<수행자>` → `clean` 가능 |

**처분 줄**(`**처분** — consumer=… · fail-… · disclosure=…`)은 헌장이 매 dispatch 자리에 요구하고
`shared/tests/test_dispatch_disposition.sh` 가 집행한다. 이 설계가 정하는 값:

- **보안 각도 · 판정 각도의 디스패치** — `fail-closed`. 부재가 판정을 막으므로 오늘의 `fail-open`
  에서 바뀐다.
- **「다른 전제」 각도(codex)** — `fail-open` + `disclosure` 필수. 헌장의 「모델 다양성 손실은
  공시하고 막지 않는다」 그대로다.
- **처분 줄이 붙는 자리는 agent 정의가 아니라 그것을 dispatch 하는 자리**(SKILL.md 의 각도
  디스패치 블록)다.
- **그 락은 agent 정의마다 dispatch ≥ 1 을 요구하고 면제값이 없다.** 그러므로 qg 가 갖는 사본은
  **실제로 디스패치되는 것만**이어야 한다 — 이것이 §6.3.4 의 AC22 범위를 결정한다(c2).

#### 6.3.6 도출 입력의 신뢰 (OQ14)

제거는 불가하다(신뢰 채널이 없다). 완화 셋:

1. ②가 ③보다 앞 — 테스트 결과는 실행이 낸다
2. **각도 셋은 도출에 걸리지 않는다** — 스코프가 정하는 것은 수행자이지 각도의 유무가 아니다
3. 「라우팅과 무관하게 서는 층」 = §6.3.2 의 각도 coverage 락

### 6.4 차등 테스트 · 해상도 공시 · 판정 어휘

#### 6.4.1 봉인자를 샌드박스에서 분리 (C2 · C20 · OQ19)

brief 는 C2(「샌드박스 생성·폐기」 제거)와 C20(봉인자 존치)이 리포에서 같은 한 서브커맨드라
충돌한다고 적었다. **분리 가능하고, 오히려 워크트리가 아예 필요 없어진다.**

**기준선 축** — 경계 커밋에서 `git worktree add --detach`. 기존 `create-baseline` 그대로, 인자만
`merge_base` → 경계.

**HEAD 축** — 네 걸음:

```bash
# 1. 봉인 — 워크트리 생성 없음. 인덱스 경로는 «git 이 무시하는 자리» 여야 한다.
#    변수는 반드시 export 하거나 각 명령에 실어 보낸다 — 그냥 대입만 하면 아래 두 git 이
#    실제 인덱스를 쓴다(그러면 AC14 가 깨진다).
(
  export GIT_INDEX_FILE="$SEAL_INDEX"
  git read-tree HEAD && git add -A && TREE=$(git write-tree)
  git commit-tree "$TREE" -p HEAD -m "qg: sealed"        # → B
)
# 2. 끝점: 봉인 커밋 B 를 후보에 «먼저 넣고» 극대원소를 계산 (§6.2.4)
# 3. 합치기: git merge-tree --write-tree 순차
# 4. 체크아웃: 합친 트리로 commit-tree → git worktree add --detach
```

*실측(§7-I)* — 수정 반영 ✓ · 삭제 반영 ✓ · untracked 포함 ✓ · `.gitignore` 존중 ✓ · 실제
인덱스 불변 ✓ · HEAD 불변 ✓ · 워킹트리 불변 ✓ · 추가 워크트리 0 ✓ · 봉인 커밋에서 워크트리 추출
가능 ✓.

> **요건은 「리포 밖」이 아니라 「git 이 무시하는 자리」다.** 실측에서 인덱스를 리포 안 추적
> 대상 자리에 뒀더니 `.qg-seal-index` 와 `.qg-seal-index.lock` 이 봉인 트리에 들어갔다. 그런데
> **qg 의 세션 상태 디렉토리는 리포 «안»이다** — `state_path.py` 가 `<cwd>/.claude/quality-gates`
> 를 내고 헌장이 그 자리를 못 박는다. 그 자리가 안전한 이유는 밖이라서가 아니라
> `.gitignore` 의 `/.claude/*` 가 덮어서 `git add -A` 가 집지 않기 때문이다.
> 그래서 이 설계가 못 박는 것은 **`$SEAL_INDEX` 가 git 이 무시하는 자리여야 한다**는 것이고,
> 회귀 락은 「봉인 트리에 인덱스 파일이 없다」를 잰다(AC14) — 위치가 아니라 결과를 잰다.

`create-sandbox` 는 **사라진다.** `create-head` 의 「샌드박스 디렉토리 실재」 assert 는 「봉인
커밋의 트리가 기대 OID 와 일치」로 바뀐다 — verifier 가 없으니 「피검자가 샌드박스 HEAD 를
움직인다」 위협 자체가 사라져 대조가 단순해진다.

#### 6.4.2 해상도 공시 (D2 — C14 재결정)

**산출자가 이미 있다.** `diff-test-results.py` 가 `counts: {still_green: N, …, pre_existing: N, …}`
로 8칸 전부를 emit 한다(실측 §7-J). D2 가 더하는 것은 **렌더링과 규칙**뿐이고 새 계산은 없다.

- `counts.pre_existing > 0` → 판정 옆 한 줄:
  **「양측 빨강 unit N개 — 그 안의 새 실패는 이 해상도(unit 당 종료 코드 하나)에서 보이지 않는다」**
- 이 줄은 **그 자체로는 `clean` 을 막지 않는다.** `(F,F)` 보호의 이유(devbrew 자신의 stale red 가
  첫 실행부터 게이트를 막으면 설계를 쓸 수 없다)가 그대로 유효하다.
  > **다만 기존 가드를 대체하지 않는다.** 오늘 `granularity == bulk` 이거나 `smeared` 일 때
  > `pre_existing > 0` 은 이미 `degraded` 로 인증을 막는다(`diff-test-results.py` 의 `degraded`
  > 식). 공시 줄은 그 «위에» 얹히는 것이고, 그 조건에서는 여전히
  > `not-certified (granularity-smear)` 가 난다. 이 단서 없이 구현하면 가드가 조용히 사라진다.
- 락: `pre_existing > 0` 인데 공시 줄이 없으면 RED.

*D1: 하한 지켜짐(구멍을 드러내면 clean 이 「정확히 이만큼」을 뜻한다) → 단순함이 이김(파서 층 0).*

#### 6.4.3 판정 어휘 (OQ11 · OQ8)

C2 가 `PASS` / `FAIL` / `SKIP_WITH_EVIDENCE` / `NEEDS_RESOLUTION` 의 산출자(verifier)를 지운다.
대체 어휘는 **세 값 + 사유**다:

| 값 | 뜻 |
|---|---|
| `clean` | 검증했고 확증 결함 없음 |
| `defect` | 확증 결함 (`NEW_REGRESSION` · `NEW_TEST_RED` · 채택된 finding) |
| `not-certified` | **판정하지 못함** — `reason:` 필수 |

`reason` 닫힌 열거 — **존치하는 차등 기계가 실제로 내는 미판정 상태를 전부 받는다.**
`diff-test-results.py` 의 `degraded` 식은 원인이 여섯인데(`not expected` · `baseline_unrunnable` ·
`silent_drop` · `error_axis_seen` · `granularity==bulk && pre_existing>0` · `smeared`) 초안의
열거에는 하나뿐이었다. 그러면 오늘 인증을 막던 실행이 새 어휘에서 갈 곳을 잃는다.

| `reason` | 발동 |
|---|---|
| `kill-switch` | 차등 테스트가 kill switch 로 생략됨 |
| `merge-conflict` | 끝점 합치기가 `rc 1`(§6.2.4) |
| `baseline-unrunnable` | 기준선 축이 안 돌아 귀속의 한쪽이 없음 |
| `silent-drop` | 영향분으로 고른 unit 이 HEAD 에서 미확인 |
| `error-axis` | 어느 축이든 `error` 상태가 닿음(수집 에러·import 실패의 대칭 경우) |
| `granularity-smear` | bulk 도말 또는 `smeared` — 한 종료 코드가 전 unit 에 발림 |
| `angle-absent` | 보안 또는 판정 각도가 `absent`(§6.3.1) |
| `scope-empty` | **resolved scope 가 0 인데 `check-review-scope.sh` 가 `changes_exist: yes` 를 냄** — 오늘의 「정직-verdict floor」가 내던 false-clean 차단이 이 사유로 옮겨온다. 진짜 변경 없음(genuine no-op)은 `scope-empty` 가 아니라 `clean` 이다 |
| `declaration-invalid` | 트레일러가 있으나 가리키는 경로가 실재하지 않거나, **한 브랜치가 서로 다른 토픽 키를 단 커밋을 함께 담음** |
| `trivia` | trivia escape 로 파이프라인 전체가 생략됨 — C4 가 허용한 두 탈출구 중 나머지 하나다. `clean` 으로 렌더하면 「테스트 없는 clean 은 나오지 않는다」가 거짓이 된다 |
| `findings-lost` | 리뷰 항목이 **소실됐거나 셀 수 없다** — 헌장이 막으라고 지정한 세 조건 중 둘이다(나머지 「주 판정자 사망」은 `angle-absent` 가 받는다). §6.3.4 의 강제(coercion) 계수가 소실로 판정되면 여기로 온다 |

**우선순위** — `defect` > `not-certified` > `clean`. 확증 결함과 미판정이 같은 실행에서 나면
**`defect`** 다. 기존 `runtime-gate.md` R8 이 이미 그 순서로 돌고 있어, 안 적으면 오늘 결함으로
잡히던 실행이 내일 「판정 불가」로 내려앉는다.

> `declaration-invalid` 는 **선언이 없는 경우가 아니다** — 없으면 §6.2.5 대로 기존 세 모드로
> 내려간다. 선언이 깨진 것과 없는 것은 다른 사실이다.

**이것이 OQ11 을 푼다** — kill-switched 실행은 `not-certified (kill-switch)` 다. `clean` 이
아니므로 C4 후반(「테스트 없는 clean 은 나오지 않는다」)이 참이고, 실패도 아니므로 kill switch 가
「무조건 실패 버튼」이 되지 않는다. §6.2.4 의 합치기 충돌과 §6.3.1 의 각도 부재가 **같은 어휘**를
쓴다.

**하류 처분** — 기계 소비자(PR 코멘트 · SDD 원장 등 이분법을 기대하는 자리)는 `not-certified` 를
**`clean` 아님**으로 읽는다. 사람은 사유를 보고 넘어갈지 정한다. 헌장의 「미판정 항목의 방향은
다음 소비자가 정한다 — 기계면 제외, 사람이면 라벨을 붙여 보여준다」 그대로다.

**이주 목록은 열거가 아니라 도출** — 구현 시
`SKIP_WITH_EVIDENCE|NEEDS_RESOLUTION|forced_downgrade|block_policy` 4토큰 전수 grep 으로 뽑는다.

> **그 grep 은 존치 표면까지 쓸어간다.** `/qg critique`(`critiquing-artifacts`)는 §6.5.1 에서
> **존치**로 선언됐는데 그 루프의 살아 있는 판정값이 `NEEDS_RESOLUTION` 이고, 파이프라인
> 오케스트레이션 락들도 같은 토큰을 쓴다. 그래서 도출 규칙은 두 단계다 — ① 4토큰으로 후보를 뽑고
> ② **`critiquing-artifacts` 경로와 그 락들을 제외**한 뒤 ③ 남은 것을 사람이 확인한다. §12 의
> 삭제 목록 도출도 같은 규칙을 쓴다(그쪽은 `sandbox|mutation.guard` 가 OR 로 더해진다).

#### 6.4.4 C2 제거 목록 일곱의 전수 처분

brief ✎ 가 「일곱 중 둘의 처분이 없다」고 지적했다. 전수:

| 항목 | 처분 |
|---|---|
| spec AC 런타임 검증 | 제거 |
| 브라우저 플로우 | 제거 |
| mutation guard (R7) | 제거 |
| 샌드박스 워크트리 배관 | 제거 — 봉인자는 워크트리 없이 산다(§6.4.1) |
| block policy | 제거 |
| **런타임 스코프 결정** | **제거** — 부팅할 표면이 없으니 대상이 사라짐 |
| **해소 루프** | **제거** — 그 어휘의 산출자가 사라짐 |

### 6.5 공개 표면 · 이주 · 헌장

#### 6.5.1 breaking 전수 (C19 · OQ15)

**OQ15 가 맞았다 — C19 가 센 「셋」은 과소 계수다.** 도출한 전수는 **11 자리**다(아래 8번은
대상이 없어 세지 않는다). 한자리에서 센다:

| # | 자리 | 처분 |
|---|---|---|
| 1 | `/qg both` | 제거 |
| 2 | `/qg review` | 제거 |
| 3 | `/qg runtime` | 제거 |
| 4 | `--skip-runtime` | 제거 |
| 5 | `DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX` | 제거(대상 소멸) |
| 6 | `DEVBREW_QUALITY_GATES_RUNTIME_MAX_RESOLUTIONS` | 제거(대상 소멸) |
| 7 | `DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE` | 축소 |
| 8 | `DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_TEST_VALIDATION` | **대상 없음** — 이 이름의 살아 있는 독자가 0 이고 CHANGELOG 이력에만 남아 있다(Task 26 이 좀비 판정 후 표에서 제거). 이번에 할 일은 이 설계문서에서 그 줄을 빼는 것뿐이라 breaking 이 아니다 |
| 9 | `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER` | 의미 변경 |
| 10 | `.claude-plugin/marketplace.json` 의 「2-gate」 문자열 | 이동 |
| 11 | `plugins/quality-gates/.claude-plugin/plugin.json` 의 같은 문장 | 이동 |
| 12 | `CLAUDE.md` Law 2 *Scoped exception (qg v2.2.0)* | 제거 |

Decision 1 의 게이트-범위 질문이 사라지는 것은 **13번째 자리가 아니라 1~4 의 결과**다 — 고를 인자가
없으면 물을 것도 없다.

**CLI 인자 4 제거** — `both` · `review` · `runtime` · `--skip-runtime`. Decision 1 질문도 사라진다.
**존치** — `branch [<name>]` · `--paths` · `--reset` · `--gc` · `--plan` · `--pr-url` ·
`critique <path>`.

**환경 스위치 — 전 17개 중 실제로 움직이는 것은 4개다**(아래 8번은 대상이 없다 · 실측 §7-K):

| 스위치 | 처분 | 근거 |
|---|---|---|
| `DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX` | 제거 | 대상(샌드박스 executor)이 사라짐 |
| `DEVBREW_QUALITY_GATES_RUNTIME_MAX_RESOLUTIONS` | 제거 | 해소 루프가 사라짐 |
| `DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE` | 축소 | `ac_coverage` 만 사라지고 나머지 유지 |
| `DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_TEST_VALIDATION` | 개명 | 이름에서 `RUNTIME` 이 빠짐(대상은 존치) |
| `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER` | 의미 변경 | loud advisory → 보안 각도 `absent` → `not-certified (angle-absent)` |

> **「통제 제거」와 「대상 소멸」은 다르다.** 헌장이 kill switch 를 보안 컨트롤로 규정하므로 통제를
> 없애는 것은 그 자체로 결정 사안이다. 위 둘은 통제를 없애는 게 아니라 **통제할 대상이 사라져
> 스위치가 공허해지는** 경우다. 이 구분을 CHANGELOG 에도 그대로 적는다.

#### 6.5.2 deprecation — 친절한 오류로 바로 major

별도 deprecation 릴리스 없이 **v8.0.0 에서 제거**하되, 제거된 인자를 받으면 조용히 무시하지 않고
한 줄을 내고 **정상 진행**한다:

```
> [quality-gates] `review` 인자는 제거됐다 — 이제 한 파이프라인이라 게이트 범위를 고르지 않는다. 그대로 진행한다.
```

하드 오류로 멈추지 않는 이유: 스크립트·별칭·메모에 묻힌 호출이 어느 날 아무것도 안 하게 되는
것을 피한다. 조용히 무시하지 않는 이유: 「내가 고른 범위가 무시됐는데 모르고 지나감」 경로를
막는다.

#### 6.5.3 공개 계약과 헌장 (C15)

- `.claude-plugin/marketplace.json` — `"2-gate quality verification pipeline (review + runtime)…"`
  → 「리뷰 파이프라인 + 강제 차등 테스트」로
- `plugins/quality-gates/.claude-plugin/plugin.json` — 같은 문장
- `CLAUDE.md` Law 2 *Scoped exception (qg v2.2.0)* — `runtime-verifier` 를 **이름으로** 박고 있다.
  그 executor 가 사라지므로 조항 전체를 제거한다. Law 2 는 예외 없는 원칙으로 돌아간다.

**이것이 OQ7 의 답이기도 하다** — 부팅되는 앱을 가진 설치본의 런타임 결함 클래스를 **대체하지
않고 주장을 거둔다.** 신뢰도 하한은 「검증 못 하는 것을 검증했다고 말하지 않음」으로 지켜진다 —
C11 의 goal 그 자체다. CHANGELOG 에 그 설치본이 잃는 것(브라우저 플로우 · spec AC 런타임 검증 ·
mutation guard)을 **이름으로** 적는다.

#### 6.5.4 헌장 조항의 고아화 방지

brief 의 blind-spot 이 짚은 대로 **그 조항에는 아무 락도 없다** — 제거가 GREEN 으로 통과해도
조항이 대상 없이 살아남는다. 락 부재는 자유가 아니라 무보호다.

새 락: **`CLAUDE.md` 가 이름으로 박는 agent · 스크립트 · 플러그인이 실재해야 한다.** 코퍼스를 헌장
본문에서 **도출**해 하나씩 확인(∀). 이번 제거뿐 아니라 앞으로의 모든 제거를 덮는다.

## 7. 실측 근거

이 설계가 기대는 도구 동작 사실. **전부 이 리포 또는 격리된 scratch 리포에서 직접 실행해 관측한
것이고, 산문 추론이 아니다.** 환경: git 2.54.0 (Apple Git-157), macOS.

| id | 관측 | 값 |
|---|---|---|
| **A** | `git log --all --grep='^Claude-Session: <값>$'` 로 토픽 좁히기 | 커밋 35개 / **40ms** (전체 2409 커밋) |
| **B** | 이 리포의 트레일러 관행 | 최근 200 중 `Claude-Session` 172 · `Co-Authored-By` 189 · `Spec` 0 |
| **C** | `git branch --contains <머지된 커밋>` | 커밋마다 **브랜치 5개**(main + 후손 전부) — 끝점 식별 불가 |
| **D** | `origin/main..<머지된 브랜치>` 범위 스캔 | 범위가 비어 **히트 0** — 머지된 앞 브랜치가 안 보임 |
| **E** | 경계 규칙 `parents(T) \ T` | |T|=35 → |B|=2 → merge-base = `add4c9cd` = **PR #155 머지(작업 시작 직전)** |
| **F** | `git merge-tree --write-tree` 충돌 (scratch 합성) | **rc 1** + stdout 에 트리 OID · stage 1/2/3 · `CONFLICT (content):` |
| **G** | 순차 합치기의 `commit-tree` 중간 커밋 | ref 0개 · `fsck --unreachable` 에 잡힘 |
| **H** | `test_copy_of_contract.sh` | guards `plugins/** shared/**` · 마커 정규식이 `#`·`//`·`<!--` 수용 · **세 축의 한정사가 다르다** — 심볼릭 링크·import 형제 축은 ∀, **`copy-of:` 축은 ∃**(마커 없는 파일은 `continue`, 564–568줄). `shared/README.md` 가 그 차이를 명시 |
| **I** | 임시 인덱스 봉인 (scratch) | 수정·삭제·untracked 반영 ✓ · `.gitignore` 존중 ✓ · 인덱스/HEAD/워킹트리 불변 ✓ · 워크트리 0 ✓ · **인덱스를 리포 안에 두면 봉인 트리에 들어감** |
| **J** | `diff-test-results.py` 집계 출력 | `counts: {…}` 가 8칸 전부 emit (`pre_existing` 포함) |
| **K** | qg 의 `DEVBREW_QUALITY_GATES_*` 전수 | **17개** |
| **L** | `run-test-selection.sh run` 출력 계약 | `<unit>\t<status>\t<exit-code>` — 테스트 신원 없음 |
| **M** | `diff-test-results.py:read_results` | 3열 TSV → `{unit: (status, exit)}` · 상태값 `pass\|fail\|error\|unrun\|absent` 5개 |

**E 와 I 는 구현 전에 재검증한다** — E 는 브랜치 형태에 따라 경계가 달라질 수 있고, I 는 scratch
리포와 실제 리포의 `.gitignore` 깊이가 다르다.

## 8. 재결정 기록 P23

devbrew 는 「재발견 금지 ≠ 반증 금지」를 원칙으로 둔다. 근거 있는 재결정은 기록한다.

**C1 — 성공 척도 넷의 대등**

- **원래** — 척도 넷은 대등하고 어느 하나가 다른 것을 대체하지 않는다.
- **재결정** — 신뢰도는 저울 «밖»의 후보 자격이고, 남은 셋 사이에는 **단순함 우선의
  타이브레이커**가 있다. 「대등」은 무게가 같다는 뜻이지 동점 처리 규칙이 없다는 뜻이 아니다.
- **근거** — 규칙이 없으면 갈림마다 즉흥 저울질이 반복되고 기록에 남지 않는다(브리프 §7 이 경고한
  것). 그리고 이 리포에는 「하니스 가볍게」라는 축적된 선례가 있다.
- **남는 것** — 실제로 D1 이 가른 네 자리에서 **전부 단순함이 이겼다.** 비용·시간이나 SDD 맞물림이
  이긴 갈림은 0건이고, 그 편향 자체가 다음 검토 대상이다(§15-9).

**C14 — 차등 정밀도**

- **원래** (seed 확정): unit 축에 상태와 **실패 개수**를 함께 실어 양측 빨강 unit 에서도 수가
  늘었으면 회귀로 잡는다.
- **1차 재결정** (인터뷰 S5): 개수는 신원 없는 스칼라라 교환 가능하다 — 하나 고쳐지고 하나
  깨지면 총합이 같아 구멍이 그대로 남고, 반대로 불안정한 테스트 하나가 없는 회귀를 발명한다.
  → 실패 **집합의 차집합**(자리별 원장).
- **2차 재결정** (이 설계 D2): 집합을 얻을 **해상도가 실행 층에 없다.** `run` 계약이 unit 당
  `(status, exit)` 둘만 내고(실측 L) `read_results` 의 상태값이 5개뿐이다(실측 M). unit 해상도의
  「집합 차집합」은 이미 16칸 표가 하는 일이므로, 파서 층을 새로 만들지 않는 한 C14 는 정밀도를
  0 만큼 올린다. → **구멍을 닫는 대신 드러낸다**(§6.4.2).
- **근거** — 실측 L · M. 그리고 D1: 구멍을 공시하면 신뢰도 하한(「clean 이 검증된 것과 일치」)이
  지켜지므로 그다음은 단순함이 정한다.
- **남는 것** — `(F,F)` 안의 새 실패는 여전히 안 보인다. 구멍은 **「이미 빨간 파일 안에 새 실패가
  생기는 경우」 하나**다(새 파일은 `(A,F)=NEW_TEST_RED` 로 이미 잡힌다). §15 에 적는다.

**§6.2.2 stage 1 — 스캔 대상 ref 네임스페이스**

- **원래** — §6.2.2 1단계는 `refs/heads` 만 열거한다.
- **재결정** — `refs/heads` 와 `refs/remotes` 를 함께 열거한다.
- **근거** — 선언 발견(`C`, §6.2.2 상단)은 이미 `git log --all` 로 원격-추적 ref 까지 본다. 그
  비대칭 때문에 머지 안 된 원격-전용 구성원이 1단계도 2단계(머지된 구성원)도 못 받아 3단계로
  떨어져 고아(`declaration-invalid`)로 보고되고 토픽 전체가 막혔다 — `git clone` 은 로컬에
  `main` 만 만드므로 이것이 신선한 clone·CI 체크아웃의 **기본 상태**고, AC3 의 헤드라인
  시나리오(「`Spec:` 트레일러가 브랜치 둘 이상에 걸침」)가 바로 거기서 깨졌다. 사람(사용자)이
  이 재결정에 동의했다.
- **남는 것** — 원격-추적 ref 가 낡으면 그 tip 도 낡은 채로 쓰인다 — 정확성이 이제 `git fetch`
  최신성에 의존한다.

## 9. brief 정정 셋

인터뷰 brief 가 사실로 적은 것 중 셋이 실측과 어긋났다. **설계는 정정된 사실 위에 선다.**

1. **OQ9 「기존 두 사본이 이미 서로 어긋나 있다」 — 아니다.**
   `shared/docreview/agents/doc-recritic.md` 와 `plugins/spec-distill/agents/doc-recritic.md` 의
   차이는 **한 줄**이다: `# copy-of: shared/docreview/agents/doc-recritic.md`. drift 가 아니라
   선언된 사본 표식이고, `shared/tests/test_copy_of_contract.sh` 가 **있는 사본끼리는** 바이트
   동일성을 집행한다(실측 H). 그 축은 ∃ 라 «빠진 사본»은 못 잡으므로 §6.3.4 가 ∀ 락을 따로 세운다.
   → 「세 번째 사본」의 비용이 실제로는 **파일당 한 줄**이다.

2. **OQ13 「재판정기는 생성기가 아니다」 — 아니다.**
   `shared/docreview/agents/doc-recritic.md` 가 「놓친 결함이 있으면 `added` 에 새 finding 을
   낸다」고 적고 `added:` 필드를 갖는다. 재비판자는 재판정기 **이면서** 생성기다.
   → 남는 진짜 문제는 **빈 입력**이고, §6.3.3 이 그것을 다룬다.

3. **OQ8 의 소비자 목록 중 둘이 틀렸다.**
   `render-terminal.py` 와 `comment-upsert.py` 는 판정 어휘를 **아예 읽지 않는다**(두 파일 모두
   `PASS|FAIL|clean|SKIP_WITH_EVIDENCE|NEEDS_RESOLUTION|verdict` 히트 0).
   → 이주 목록을 이름으로 열거하지 않고 **4토큰 전수 grep 으로 도출**한다(§6.4.3).

## 10. Open Questions 처분표

brief §3 의 19개 전부. **미처분 0.**

| OQ | 처분 | 절 |
|---|---|---|
| OQ1 세 스코프 모드 | 새 스코프가 기본, 셋은 override 로 존치 | §6.2.5 |
| OQ2 codex 층 | D5 — 각도 목록에 편입, Tier 개념 소멸 | §6.3.1 |
| OQ3 부모-브랜치 후보 부재 | **부수 효과로 해소** — 선언 경로의 기준선이 경계 규칙이라 merge-base 를 안 씀. 선언 없는 fallback 경로에는 남음(§15) | §6.2.3 |
| OQ4 척도 충돌 순서 | **D1** | §4 |
| OQ5 차등 기계 교체 | **범위 밖** — 하한을 올리지 않고 단순함을 크게 깎음 | §3 |
| OQ6 선언의 가변성·충돌 | 충돌: spec 경로가 유일해 원천 없음 / 재선언: 산출물이 집합+SHA 를 실음 | §6.2.6 |
| OQ7 N=1 일반화 · 부팅 앱 설치본 | 대체하지 않고 **주장을 거둠** | §6.5.3 |
| OQ8 판정 어휘 소비자 이주 | 세 값 어휘 + **4토큰 전수 grep 도출**. brief 목록 정정 | §6.4.3 · §9 |
| OQ9 스키마 임피던스 · 세 번째 사본 | 사본은 한 줄 + **빠진 사본용 ∀ 락 신설**. 임피던스는 입력=diff 선택 슬롯 · **출력=qg 쪽 변환 계층** | §6.3.4 · §9 |
| OQ10 리뷰 발동 시점·중복 | **D4** — 있는 것을 묶고 집합을 실음. SDD 최종 리뷰와는 **대상이 다름** | §6.2.6 |
| OQ11 kill-switched 실행의 어휘 | `not-certified (kill-switch)` | §6.4.3 |
| OQ12 교체 락의 앵커 | 합성기 출력 스키마의 ∀ + 양의 짝 | §6.3.2 |
| OQ13 재판정기 ≠ 생성기 | **전제 정정.** 남는 문제는 빈 입력 | §6.3.3 · §9 |
| OQ14 도출 입력을 피검자가 씀 | 완화 셋(제거 불가) | §6.3.5 · §6.2.7 |
| OQ15 공개 표면의 실제 크기 | **11 자리** — C19 의 셋은 과소 계수 | §6.5.1 |
| OQ16 「작업 시작점」의 산출자 | **경계 규칙** — 선언과 별개 값이 아니라 히스토리에서 도출 | §6.2.3 |
| OQ17 합친 트리의 성숙형 | **취하지 않음** — 순서만 결정론 고정, 충돌은 판정 불가 | §6.2.4 |
| OQ18 자리별 원장의 실효 | **D2** — 파서 층 없음, 해상도 공시로 | §6.4.2 · §8 |
| OQ19 봉인자 분리 가능성 | **가능** — 워크트리가 아예 필요 없음 | §6.4.1 |

## 11. Acceptance Criteria

- **AC1** — `/qg` 가 게이트 범위를 묻지 않는다. `both` · `review` · `runtime` · `--skip-runtime`
  를 주면 §6.5.2 의 한 줄을 내고 정상 진행한다.
- **AC2** — 차등 테스트는 trivia escape 와 kill switch 외의 어느 경로로도 생략되지 않는다.
- **AC3** — `Spec:` 트레일러를 가진 커밋이 둘 이상의 브랜치에 걸쳐 있을 때, 한 번의 `/qg` 가 그
  전부를 한 판정 단위로 본다.
- **AC4** — 그중 하나가 이미 `main` 에 머지돼 있어도 토픽에 포함된다.
- **AC5** — **선언 경로에서** 기준선이 **`fork(b) = merge-base(base_ref, b)` 들의 merge-base**
  로 계산된다(§6.2.3). `parents(T) \ T` 도 `merge-base(base_ref, HEAD)` 도 쓰지 않는다. (선언 없는
  fallback 경로는 기존대로 — AC16 · §15-5.)
- **AC6** — HEAD 축이 끝점들의 `merge-tree --write-tree` 결과이고, **봉인 커밋이 후보 집합에 먼저
  들어간 뒤 극대원소로 끝점이 계산된다**(§6.2.4). 「치환」이 아니다 — 현재 브랜치가 다른 구성원의
  조상이면 치환할 자리가 없다.
- **AC7** — 합치기 충돌 시 판정이 `not-certified` 이고 `reason: merge-conflict` 이며 충돌 파일이
  나열된다. `clean` 이 아니다.
- **AC8** — 판정값이 `clean` · `defect` · `not-certified` 셋 뿐이고, `not-certified` 는 항상
  닫힌 열거의 `reason` 을 동반한다.
- **AC9** — kill switch 로 차등 테스트가 생략된 실행의 판정이 `not-certified (kill-switch)` 다.
- **AC10** — 각 각도(보안 · 판정 · 다른 전제)의 상태가 `filled` / `folded_into:<수행자>` /
  `absent` 중 하나로 **항상** 산출물에 있다. 셋 중 하나라도 상태가 없으면 스키마 검증이 실패한다.
- **AC10a** — **판정 각도**의 `folded_into:<수행자>` 가 그 실행에서 finding 을 낸 리뷰어면
  실패한다(자기 finding 자기 판정 = Law 2 위반). **보안 각도에는 적용하지 않는다** — 보안 각도는
  «무엇을 찾는가»의 문제라 그 리뷰어가 finding 을 내는 것이 정상이고, 금지하면 C13 이 허용한
  접어 넣기가 사실상 죽는다.
- **AC11** — 보안 또는 판정 각도가 `absent` 인데 판정이 `clean` 이면 실패한다.
- **AC12** — 「다른 전제」 각도가 `absent` 여도 판정은 막히지 않고 공시만 된다.
- **AC13** — `counts.pre_existing > 0` 인 실행의 산출물에 해상도 공시 줄이 있다. 그 줄이 없으면
  실패한다.
- **AC14** — 봉인이 실제 인덱스 · HEAD · 워킹트리를 바꾸지 않고, 추가 워크트리를 만들지 않으며,
  **봉인된 트리에 임시 인덱스 파일이 들어 있지 않다.**
- **AC15** — 판정 산출물이 본 커밋 SHA 전부 · 끝점 · 경계 · 합친 트리 OID 를 싣는다.
- **AC16** — 선언이 없는 브랜치에서 `/qg` 가 기존 세 모드로 내려가고 어느 `not-certified` 사유로도
  막히지 않는다. 트레일러가 «있는데» 그 경로가 실재하지 않거나 한 토픽이 서로 다른 경로를
  가리키면 `not-certified (declaration-invalid)` 다.
- **AC17** — 탐지 0건이어도 재비판이 디스패치되고, 탐지 0 · 재비판 0 이 산출물에 명시된다.
- **AC18** — 재비판자의 `diff` 슬롯이 optional 이고, 부재 시 「이 변경이 도입했는가」 축을 쓰지
  않는다. spec-distill 의 브리프 경로는 diff 를 싣지 않는다.
- **AC19** — `CLAUDE.md` 가 이름으로 박는 agent · 스크립트 · 플러그인이 전부 실재한다.
- **AC20** — `marketplace.json` · `plugin.json` · `CLAUDE.md` 셋 어디에도 `runtime-verifier` 나
  「2-gate」가 남지 않는다.
- **AC23** — PR2 가 넣는 옛↔새 판정 어휘 매핑 표가 PR4 에서 산출자와 함께 제거된다. PR5 시점에
  그 표가 남아 있으면 실패한다.
- **AC22** — docreview agent 의 **사본 집합과 디스패치 집합이 정확히 일치한다** — 디스패치하는데
  사본이 없어도, 사본이 있는데 디스패치하지 않아도 실패한다. 두 집합 모두 코퍼스에서 도출한다
  (∃ 가 아니라 ∀).
- **AC21** — 제거된 테스트가 어떤 `# guards:` 글롭의 유일 대상이 아니다(선언이 공허해지지 않는다).

## 12. Files to Modify

**제거**
- `plugins/quality-gates/agents/runtime-verifier.md`
- `plugins/quality-gates/scripts/detect-runtime.sh`
- `plugins/quality-gates/scripts/qg-worktree.sh` 의 `create-sandbox` · `mutation-guard` 분기
- `plugins/quality-gates/tests/` 중 4토큰 grep + `sandbox|mutation.guard` 로 도출되는 것
  (`test_qg_runtime_sandbox.sh` · `test_qg_mutation_guard.sh` · `test_sandbox_enforced.sh` ·
  `test_runtime_verifier_*` · `test_runtime_verdict_precedence.sh` · `test_detect_runtime.sh` 등 —
  **열거가 아니라 도출로 확정한다**)
- `plugins/quality-gates/tests/test_review_floor_lock.sh` (교체)
- **`plugins/quality-gates/agents/adversarial.md`** — **제거.** §6.3.3 이 그 dispatch 자리를
  재비판으로 바꾸므로 정의만 남으면 `shared/tests/test_dispatch_disposition.sh` 가 「어디서도
  dispatch 되지 않는 agent」로 잡는다. SKILL.md 의 dispatch 블록과 **같은 커밋**에서 지운다.

**대폭 수정**
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — 962줄. 게이트 개념 제거, 5단계 골격,
  각도 절, Decision 1·2 제거
- `plugins/quality-gates/skills/quality-pipeline/references/runtime-gate.md` — 1206줄. R5a·R7·R9
  제거 후 「차등 테스트」 레퍼런스로 개명·재작성
- `plugins/quality-gates/commands/qg.md` — 인자 표 · Quick Reference · Gates 절
- `plugins/quality-gates/scripts/resolve-baseline.sh` — 경계 규칙 추가(기존 키는 fallback 경로용
  으로 유지)
- `plugins/quality-gates/scripts/qg-worktree.sh` — 봉인 서브커맨드 신설, `create-head` assert 변경
- `plugins/quality-gates/scripts/synthesize_findings.py` — 각도 상태 총 함수, 세 값 어휘
- `plugins/quality-gates/scripts/diff-test-results.py` — 해상도 공시 줄
- `plugins/quality-gates/scripts/qg-gc.py` — unreachable 중간 커밋 정리
- `plugins/quality-gates/README.md` · `plugins/quality-gates/CHANGELOG.md` ·
  `plugins/quality-gates/.claude-plugin/plugin.json`

**신설**
- `plugins/quality-gates/scripts/resolve-topic.sh` — 선언 → 커밋 집합 → 경계 · 끝점
- `plugins/quality-gates/scripts/seal-worktree.sh` — 임시 인덱스 봉인
- `plugins/quality-gates/scripts/combine-tips.sh` — 순차 `merge-tree`
- `plugins/quality-gates/agents/doc-recritic.md` — `# copy-of:` 사본 **하나뿐**이다. qg 의 코드
  경로는 재비판자만 디스패치하므로 `doc-critic`·`doc-critic-web` 사본을 만들면 `dispatch ≥ 1` 락이
  RED 다(§6.3.4 · AC22).
- 새 락 5종(§13)

**리포 루트**
- `.claude-plugin/marketplace.json` — 공개 계약 문자열
- `CLAUDE.md` — Law 2 scoped exception 제거

**qg 밖 (이번 사이클이 qg 경계를 넘는 자리)**
- `shared/docreview/agents/doc-recritic.md` — `diff` 선택 슬롯
- **`plugins/spec-distill/agents/doc-recritic.md`** — 위 정본의 `# copy-of:` 물리 사본. 정본이
  움직이면 **같은 커밋에서 함께** 움직여야 한다 — 안 그러면 `test_copy_of_contract.sh` 의 바이트
  동일성 검사가 RED 다. (이것이 「유일한 자리」가 아니었던 이유다.)
- `shared/tests/test_docreview_agents.sh` — 슬롯 기대값 이동

## 13. Verification Plan

**교체 1**
- `test_angle_coverage.sh` — §6.3.2 의 ∀ 총 함수 + 양의 짝(`absent` + `clean` = RED)

**신규 5**
- `test_verdict_vocabulary.sh` — 세 값 × 사유 닫힌 열거의 총 함수
- `test_topic_boundary.sh` — 경계 규칙. **합성 토픽 픽스처 + 양성 대조 필수**
- `test_seal_no_side_effects.sh` — AC14. 특히 **봉인 트리에 인덱스 파일 없음**(실측 결함의 회귀 락)
- `test_resolution_disclosure.sh` — AC13
- `shared/tests/test_charter_citations.sh` — AC19. 코퍼스를 `CLAUDE.md` 본문에서 도출(∀)

**mutation** — 새 락 전부를 네 축으로 흔든다: **삭제 · 변형 · 추가 · 불일치**. 각 축에
**양성 대조**를 둔다(green-expected 단언은 모양으로 이빨을 판별할 수 없다). `PYTHONDONTWRITEBYTECODE=1`
로 돌린다(같은 길이 변이가 stale `.pyc` 를 못 넘는다).

**삭제 후 필수** — `plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh` 를 돌려
AC21 을 확인한다.

**회귀 스위트** — `shared/tests/` 전부 + `plugins/quality-gates/tests/` 전부 + `plugins/spec-distill/tests/`
전부(§12 의 마지막 항목이 그 경로를 건드린다). 리포 루트에서 돌린다.

**선재 RED 기준선** — 이 리포에 stale red 가 있다. 착수 전에 baseline 을 캡처하고 **실패 파일
이름과 실패 줄 수를 함께** 기록한다(rc 만으로는 이미 RED 인 파일 안의 새 실패가 원리적으로 안
보인다).

**수동 e2e** — 실제로 `Spec:` 트레일러를 단 브랜치 둘을 만들어 `/qg` 를 돌린다. 자동 락이 잴 수
없는 것: 실제 디스패치가 일어나는지, 산출물이 사람에게 읽히는지.

## 14. Rejected Alternatives

| 기각한 것 | 이유 |
|---|---|
| **넷 전부의 엄격 전순서**(신뢰도 > 맞물림 > 단순함 > 비용) | C1 의 「넷은 대등」이 통째로 깨진다. 네 축 전부에 순서를 매기는 것은 곧 대체다. **D1 은 신뢰도를 저울 밖으로 빼고 남은 «셋»에만 타이브레이커를 두므로 이것과 다르다** — 그 차이가 §8 의 C1 재결정 항목이다 |
| **비용·시간을 1순위로** | §2 확정 둘(C14 · C21)의 근거를 되돌려야 한다 |
| **파서 층 전면 신설** | shell·make·npm-script 는 구조화 출력이 없어 휴리스틱 파싱이 된다. 이번 사이클이 「차등 기계 재작성」으로 불어난다 |
| **신원을 낼 수 있는 어댑터만 per-test 원장** | 구멍이 주 스위트에서 닫히지만 「어댑터 전부에 같은 코드」 전제가 깨지고 기준선 캐시가 열 수 검증(`NF != 4`)으로 전량 무효화된다 |
| **추적되는 선언 파일**(`.qg/topics/*.yml`) | 트리 쪽이라 C12 의 「브랜치 쪽」과 어긋나고, 브랜치마다 갈라져 충돌하며, 작업 시작점이 여전히 사람이 쓰는 별도 필드라 OQ16 이 안 풀린다 |
| **SDD 원장 한 줄 정형화** | `.superpowers/sdd/.gitignore` 가 `*` 라 기계가 의지할 수 없고, 추적되게 바꾸려면 외부 플러그인의 파일을 고쳐야 한다 |
| **`git notes` · `branch.<name>.description`** | notes 는 push 가 기본이 아니고 이 리포에 흔적 0. description 은 로컬 전용이라 클론에 없다 |
| **묶음이 완결될 때까지 리뷰 거부** | 「완결」의 판정자가 새 열림이 되고, 긴 작업에서 마지막까지 피드백이 없으며, 사용자가 선언을 늦게 붙이는 우회를 배우게 된다 |
| **브랜치별 + 묶음 둘 다 리뷰** | 비용·시간이 명시적으로 오르는데 이번 재편의 발단이 그 축이다 |
| **두 게이트 유지, Runtime 을 개명만** | 고를 수 없는 「게이트」라는 허구가 남고 단순함 축이 거의 안 움직인다 |
| **codex 를 availability-floor 로 남기기**(감지되면 스코프 무관 무조건) | OQ2 가 열어 둔 대안이고 오늘의 동작이다. 각도로 내리면 3단계 Tier 개념이 통째로 사라져 「각도 의무 + 도출된 수행자」 한 기계만 남는다 — D1 상 단순함이 이긴다. 대가: 「감지됐는데 스코프가 안 불렀다」와 「없어서 못 불렀다」가 같은 `absent` 로 접힌다. **그래서 각도 상태에 사유를 싣는다** — `absent(not-installed)` · `absent(not-derived)` 로 갈라 공시하고, 둘 다 막지는 않는다 |
| **octopus 머지로 N 개를 한 번에 합치기** | C21 이 이름 붙인 다른 형태다. `git merge-tree` 는 두 갈래만 받으므로 octopus 는 실제 워크트리에서 `git merge -s octopus` 를 돌려야 해 §6.4.1 이 없앤 워크트리 의존이 되살아난다. 그리고 octopus 는 **한 파일에 충돌이 나면 전체를 중단**해 어느 구성원 때문인지 가려 주지 않는데, 순차는 실패한 단계가 곧 그 구성원이라 충돌 파일 목록에 귀속이 실린다. 순차의 대가는 중간 커밋이 unreachable 로 남는 것이고 그것은 기존 GC 경로가 받는다 |
| **차등 테스트를 「리뷰어 한 명」으로 모델링** | 결정론 기계를 모델-소유 자리처럼 보이게 만든다. C3 및 「락의 PASS 는 이빨의 증거가 아니다」와 어긋날 위험 |
| **`folded_into` 금지**(각도는 항상 전용 패스) | C6 이 없앤 「매 iteration 전용 디스패치」 형태가 이름만 바꿔 되살아나고 비용·단순함이 둘 다 내려간다 |
| **`not-certified` 를 `defect` 로 접기** | kill switch 가 「무조건 실패 버튼」이 되어 사용자가 스위치 대신 플러그인을 끈다(OQ11 이 경고한 경로) |
| **`not-certified` 를 `clean` 으로 접기** | C11 의 goal 을 정면으로 깬다 |
| **diff 슬롯을 qg 전용으로 분기** | `# copy-of:` 계약을 일부러 깨야 하고, 「통합한 것의 재분열」을 막는 바로 그 락에 예외를 파야 한다 |
| **one-minor deprecation window** | 릴리스 둘을 나눠 돌려야 하고 중간 상태 자체의 테스트가 필요해진다. 친절한 오류가 같은 일을 한 릴리스로 한다 |
| **제거 인자를 하드 오류로** | 스크립트·별칭에 묻힌 호출이 어느 날 아무것도 안 하게 된다 |

## 15. 알려진 한계

설계가 **못 하는 것**을 적는다. 이 절이 비어 보이면 그것이 위험 신호다.

1. **`(F,F)` 구멍은 열려 있다.** 이미 빨간 파일 **안**에 새 실패가 생기면 이 해상도에서 안
   보인다(새 파일은 `(A,F)` 로 잡힌다). 공시로 드러낼 뿐 닫지 않는다 — D2.
2. **토픽 중간의 main 병합이 diff 를 부풀린다.** 경계가 여럿일 때 merge-base 를 쓰므로 그 병합이
   가져온 남의 변경이 diff 에 든다. 공시하되 막지 않는다.
3. **선언을 늦게 붙인 앞 커밋은 범위 밖이다.** 수만 공시한다. 신뢰 채널이 없어 막을 결정론 수단이
   없다 — `resolve-baseline.sh` 의 `ahead:` 가 같은 이유로 같은 선택을 했다.
4. **각도 coverage 락은 형식적 완전성만 잰다.** 「각도가 상태를 가졌는가」는 재지만 「그 상태가
   참인가」는 못 잰다 — 모델이 모든 각도를 `folded_into:` 로 주장하면 락은 GREEN 이다. 이 한계를
   락 자신의 주석에 공시한다.
5. **선언 없는 fallback 경로에는 OQ3 의 결함이 남는다.** 그 경로는 여전히
   `merge-base(base_ref, HEAD)` 를 쓰므로 스택 앞 브랜치가 머지됐으면 그 변경이 안 보인다.
6. **증거가 N=1 이다.** 「대상 모델이 어긋났다」의 근거가 전부 devbrew 한 리포에서 왔고, 그 리포는
   부팅되는 앱이 없다는 점에서 모집단 중 가장 비전형적이다. 이 설계는 그 비대표성을 **해결하지
   않고**, 대신 qg 가 하지 않는 일을 공개 계약에서 주장하지 않게 만든다.
7. **실측 E · I 는 구현 전 재검증이 필요하다**(§7). E 는 경계 규칙이 브랜치 분기점으로 바뀌어
   **새 규칙으로 다시 돌려야** 하고, I 는 scratch 리포와 실제 리포의 `.gitignore` 깊이가 다르다.
8. **선언을 늦게 붙이면 경계 앞의 커밋이 범위 밖이다** — 수만 공시한다(§6.2.7).
9. **D1 의 타이브레이커가 한 방향으로만 작동했다** — 실제로 가른 네 자리에서 전부 단순함이 이겼고
   비용·시간이나 SDD 맞물림이 이긴 갈림은 0건이다(§8 의 C1 재결정 항목).
10. **브리프가 이름 붙인 긴장 ①이 라벨만 받았다.** 「스코프를 여러 브랜치로 넓히면 공통 조상이
    뒤로 밀리고 기준선 트리가 낡아 기준선 실행 불가가 예외가 아니라 기본 경로가 될 수 있다」 —
    이 설계는 그 실행을 `not-certified (baseline-unrunnable)` 로 **이름 붙이기만 했고** 발생
    빈도·완화·수용 여부를 저울에 올리지 않았다. 기계 소비자가 그것을 `clean` 아님으로 읽으므로
    이번 재편의 발단인 비용·시간 축이 거꾸로 밀릴 수 있다. **완화 후보 둘**(둘 다 이 문서가
    고르지 않는다): 기준선 축이 안 서면 그 어댑터만 빼고 나머지로 판정하기 · 경계가 너무 뒤면
    사용자에게 좁힐지 묻기. 구현 계획이 실측으로 빈도를 먼저 재고 그때 고른다.
11. **AC5·AC6 를 제외한 나머지 AC 는 라운드 2 에서 본문과의 정합을 전수 대조하지 않았다** — 두
    자리에서 옛 규칙이 남아 있던 것이 발견됐으므로 같은 종류가 더 있을 수 있다.

## 16. 구현 분할

이 설계는 **한 구현 계획으로는 크다** — 962줄 SKILL · 1206줄 레퍼런스 · 스크립트 10 · 새 락 5 ·
삭제 ~15 파일 · 리포 루트 2 · `shared/` 1. 한 PR 에 담으면 리뷰가 실질을 못 본다.

**원래 다섯 PR 로 나눴으나 4a·4b·4c 분할(아래 재결정 둘) 뒤 일곱이다. 전부 같은 사이클이다**
(C7·C15 의 「같은 사이클」 요구를 만족한다 — 그 요구는 같은 PR 이 아니라 같은 사이클이다).

| PR | 내용 | 기존 동작 영향 |
|---|---|---|
| **1** | 스코프 기계 — `resolve-topic.sh` · `seal-worktree.sh` · `combine-tips.sh` + `test_topic_boundary.sh` · `test_seal_no_side_effects.sh` | **없음** (새 스크립트만, 호출자 0) |
| **2** | 판정 어휘 세 값 + 해상도 공시 — `synthesize_findings.py` · `diff-test-results.py` + 락 둘 | 어휘가 바뀐다 (소비자 동반 이주) |
| **3** | 각도 바닥 — 각도 총 함수 · `test_angle_coverage.sh` · 명단 락 교체 · `doc-critic`/`doc-recritic` 사본 · `shared` diff 슬롯 | 리뷰어 구성이 바뀐다 |
| **4a** | 재비판 교체 — `adversarial` 자리를 공유 재비판자로 · §6.3.4 변환 계층 · qg `doc-recritic` 사본 · AC17 · AC22 | 판정자가 바뀐다 (두 게이트 구조는 그대로) |
| **4b** | verifier 제거 + 파이프라인 합치기 — SKILL · runtime-gate.md → differential-test.md · qg.md · 공개 인자 · 판정 어휘 상시 배선 | **breaking** |
| **4c** | 토픽 스코프 배선 — resolve-topic.sh · combine-tips.sh → 선언 경로 · AC3–AC7 · AC15 · AC16 선언 쪽 · declaration-invalid · merge-conflict 발화 · PR1 이월 둘 · 중간 커밋 GC | 없음(선언이 없으면 기존 세 모드) |
| **5** | 공개 계약 · 헌장 · 인용 락 — `marketplace.json` · `plugin.json` · `CLAUDE.md` · `test_charter_citations.sh` | 문자열·조항 |

**순서 제약** — 1 → 2 → 3 → 4a → 4b → 4c → 5. PR 4b 가 봉인자를, PR 4c 가 나머지 PR 1 스크립트를
배선하고 PR 2·3 의 어휘를 쓴다. PR 5 는 PR 4b 가 대상을 지운 뒤라야 인용 락이 GREEN 이 된다.

**재결정 (P23, 2026-09-24) — PR4 를 4a · 4b 로 나눈다.**
- **원래** — 다섯 PR 이고 넷째가 「verifier 제거 + 파이프라인 합치기」 하나다.
- **재결정** — 넷째를 둘로 쪼갠다. 4a 는 오늘의 두 게이트 구조 «안»에서 판정자만 바꾸고(비-breaking),
  4b 가 게이트를 합친다(breaking).
- **근거** — PR3 가 사본 · AC17 · AC22 · 변환 계층을 PR4 로 넘겼고(PR3 계획 R-D), 실측한 PR4 의 크기가
  이 절이 분할한 이유(「한 PR 에 담으면 리뷰가 실질을 못 본다」)를 그대로 재현했다 — 삭제 에이전트 둘 ·
  테스트 삭제 ~10 · 수정 ~12 · SKILL 962줄 · 레퍼런스 1218줄 재작성에 새 모듈 · 새 락까지. 사람(사용자)이
  이 재결정에 동의했다.
- **남는 것** — 선언 조각이 `#pr4a` · `#pr4b` 둘이 된다. 아래 「PR4」를 가리키는 문장(AC23 의 매핑 표
  제거 등)은 **verifier 가 사라지는 4b** 를 뜻한다 — 매핑 표의 산출자가 거기서 죽는다.

**재결정 (P23, 2026-09-25) — PR4b 를 4b · 4c 로 나눈다.**
- **원래** — 4b 가 verifier 제거 · 게이트 합치기 · 스코프 배선을 함께 진다.
- **재결정** — 스코프 배선(토픽 선언 → 커밋 집합 → 합친 HEAD 트리)을 4c 로 뗀다. 4b 는
  breaking 부분(verifier 제거 · 한 파이프라인 · 판정 상시 배선)만 진다.
- **근거** — 실측한 4b 가 이 절이 분할한 이유를 다시 재현했다(1017줄 SKILL · 1218줄
  레퍼런스 재작성 · 판정 배선 · 합성기 정리 · 스코프 배선). 스코프 배선은 선언이 없으면 기존
  세 모드로 내려가는 **새 능력**이라(§6.2.5) 떼어 내도 breaking 경계가 깨지지 않는다.
  사람(사용자)이 이 재결정에 동의했다.
- **남는 것** — 선언 조각이 `#pr4c` 하나 더 는다. 4b 와 4c 사이 한 릴리스 동안 `Spec:`
  트레일러는 효과가 없다. HEAD 축의 봉인은 4b 가 먼저 배선한다 — 샌드박스가 사라지면
  `create-head` 가 붙을 커밋이 봉인뿐이기 때문이다.

**각 PR 은 자기 `Spec:` 조각을 선언한다**(§6.2.1) — `…-design.md#pr1` … `#pr5`. 같은 값을 쓰면
PR2~5 가 앞 PR 전부를 합집합으로 재리뷰해 분할이 비용을 **늘린다**.

**PR2 와 PR4 사이의 중간 상태를 닫는다.** PR2 가 판정 어휘를 세 값으로 바꾸는데 옛 어휘의
산출자(`runtime-verifier` 와 그 락들)는 PR4 까지 살아 있다 — 그대로 두면 두 릴리스 동안 산출자와
소비자가 다른 어휘로 말한다. 처리:

- PR2 의 합성기는 **두 어휘를 모두 읽는다**(옛 값 → 새 값 매핑 표를 그 PR 안에 둔다). 새 어휘만
  «낸다».
- 옛 어휘를 **내는** 자리(verifier·그 락들)는 PR4 에서 산출자와 함께 사라지고, 그때 PR2 가 넣은
  매핑 표도 같이 지운다 — 그 삭제를 PR4 의 체크리스트에 명시한다.
- 매핑 표가 PR5 까지 살아남으면 그 자체가 결함이다(AC23).

**계획 단위는 PR 하나에 계획 하나다.** `superpowers:writing-plans` 를 PR 수만큼(4a·4b·4c 분할 뒤 일곱) 부른다 — 여럿을 한
계획으로 받으면 §16 이 분할한 이유가 계획 층에서 다시 붕괴한다. 각 계획은 그 PR 의 AC 부분집합만
받고, 앞 PR 의 산출물을 전제로 적는다.

**각 PR 마다** `plugin.json` bump · CHANGELOG 항목 · 그 PR 이 닿은 소비자 전부의 스위트를 돌린다.

## 결정 기록

리뷰 라운드의 `decide` 처분이 여기 쌓인다. 진입 시점의 내용은 아래 둘이다.

**D1–D6 — 인터뷰 열린 질문 중 사용자 소유였던 여섯.** 표는 §4 에 있다. 요지 —
D1 신뢰도는 저울 위가 아니라 후보 자격(셋 중엔 단순함 우선) · D2 C14 를 해상도 공시로 재결정 ·
D3 선언은 커밋 트레일러 `Spec:` · D4 있는 것을 묶고 집합+SHA 를 실음 · D5 codex 를 각도로 편입 ·
D6 한 파이프라인.

**C14 재결정 (P23).** 원래 / 재결정 / 근거의 전문은 §8 에 있다. 요약 — 실행 층이 unit 당
`(status, exit)` 둘만 내고 테스트 신원이 없어 파서 층 없이는 정밀도가 0만큼 오른다. 구멍을 닫는
대신 드러낸다.

**brief 정정 셋.** OQ9·OQ13·OQ8 의 전제가 실측과 어긋났다. 전문은 §9.
- D1.1 · r1 · adopt · 3dc9f893#r1.1 · "채택 — 열거 확장 + 우선순위 명시" — 새 판정 사유가 존치하는 차등 테스트의 모든 미판정 상태를 수용하지 못한다. 기존 degraded 상태의 매핑과 결함 동시 발생 시 우선순위를 정해야 한다.
- D1.2 · r1 · adopt · 737cd2ec#r1.1 · "채택 — 봉인을 먼저 넣고 끝점을 계산" — 현재 브랜치가 다른 구성원 브랜치의 조상이면 끝점 집합에 없어 봉인 커밋 치환이 불가능하다. 봉인을 반영한 뒤 끝점을 계산하는 등의 규칙이 필요하다.
- D1.3 · r1 · adopt · 75676a42#r1.1 · "채택 — 변환 계층을 qg 쪽에" — diff 슬롯 추가만으로 공유 재비판자와 코드 합성기의 출력 계약 차이가 해결되지 않는다. 변환 계층 또는 공통 계약 확장을 정해야 한다.
- D1.4 · r1 · adopt · 85e80b4b#r1.1 · "채택 — PR 마다 선언을 달리 한다" — §16 이 다섯 PR 로 쪼갠 이유(「한 PR 에 담으면 리뷰가 실질을 못 본다」)를 §6.2 의 스코프 모델이 되돌린다 — 다섯 PR 이 같은 `Spec:` 경로를 선언하는 한 PR2~PR5 의 매 `/qg` 는 이미 머지된 앞 PR 전부를 합집합으로 한 판정 단위로 보고(AC3·AC4 가 그것을 요구한다), 기준선은 PR1 직전에 고정된다. 분할이 리뷰 1회의 분량을 줄이지 못하고 같은 커밋이 사이클 안에서 최대 다섯 번 재리뷰돼 이번 재편의 발단인 비용·시간 축(C1)을 거꾸로 민다. 사이클 안의 PR 마다 선언을 달리할지(그러면 C8 의 「브랜치 전부가 한 대상」이 사이클 안에서 깨진다), 판정 단위를 그대로 두고 §16 의 분할 근거를 다시 쓸지 사용자가 정해야 한다.
- D1.5 · r1 · adopt · 8692acd2#r1.1 · "채택 — 판정 각도에만 적용" — AC10a의 자기 판정 금지가 보안 각도의 정상적인 접어 넣기까지 금지한다. 판정 각도에만 적용하도록 AC 범위를 명확히 해야 한다.
- D1.6 · r1 · adopt · b3b6ed3b#r1.1 · "채택 — 선언을 브랜치 소속 표식으로" — 끝점을 `T` 안에서만 고르므로 브랜치의 마지막 선언 커밋 «뒤»의 미선언 커밋은 합친 트리에서 통째로 빠지는데 공시가 없다 — §6.2.7 은 경계 «앞»만 세고 현재 브랜치는 봉인이 가려 주지만 이미 머지된·형제 브랜치에서는 그대로 소실되어 「`clean` 은 그 튜플에 대한 clean」이 깨진다.
- D1.7 · r1 · adopt · bf618af4#r1.1 · "채택 — 각도가 새 기대값 앵커다" — 디스패치를 모델 도출로 내리면서 헌장의 처분 회계 계약과의 관계를 설계가 정하지 않았다 — 매 dispatch 자리의 `**처분** — consumer=… · fail-… · disclosure=…` 줄을 도출된 수행자에 어떻게 붙이는지, 현 `fail-open` 이 각도 fail-closed 로 바뀌는지, 신설 사본 둘의 처분 자리는 어디인지가 없고, 브리프가 이름 붙인 blind spot(「항상-디스패치 바닥은 회계의 기대값 앵커이기도 했다」)이 §5·§10 어디에서도 처분을 받지 않았다.
- D1.8 · r1 · adopt · db12e61a#r1.1 · "채택 — C1 의 근거 있는 재결정으로 명시" — D1 의 「셋이 부딪히면 단순함이 이긴다」는 §14 가 「순서는 곧 대체다」라며 기각한 바로 그 형태이고 — 실제로 본문의 D1 판정 넷이 전부 「단순함이 이김」이라 비용·시간·SDD 맞물림이 이긴 갈림이 0건이다 — C1 의 「넷 대등」을 유지할지 「신뢰도 필터 + 단순함 우선」을 C1 의 근거 있는 재결정으로 명시할지 사용자가 정해야 한다.
- D1.9 · r1 · adopt · fe2f8d17#r1.1 · "채택 — b3b6ed3b 와 같은 규칙을 경계에도" — 선언된 커밋만으로 경계와 끝점을 정하면 선언이 묶는 브랜치 전체가 빠질 수 있다. 브랜치 전체를 포함할지 선언 커밋으로 범위를 좁힐지 결정해야 한다.
- D2.10 · r2 · adopt · 15d73e45#r2.1 · "채택 — 내 수정이 만든 둘 + 새 것 넷은 본문에서 닫고, 나머지는 §15 알려진 한계·§Deferred to plan 에 명시한다" — 차등 테스트가 빠지는 두 경로 중 kill switch 만 판정값을 얻었고 trivia escape 는 닫힌 열거에 사유가 없어, 그 실행이 clean 으로 렌더되면 C4 후반(「테스트 없는 clean 판정은 나오지 않는다」)이 깨진다 — 새 사유를 더할지 trivia 실행은 판정을 내지 않는다고 못 박을지 정해야 한다.
- D2.11 · r2 · adopt · 2143fd89#r2.1 · "채택 — 내 수정이 만든 둘 + 새 것 넷은 본문에서 닫고, 나머지는 §15 알려진 한계·§Deferred to plan 에 명시한다" — 선언을 브랜치 소속 표식으로 쓴다는 결정과 선언된 커밋만 포함하는 알고리즘이 충돌한다. 브랜치 전체의 시작점·끝점을 복원하는 규칙을 확정해야 한다.
- D2.12 · r2 · adopt · 2bc893ab#r2.1 · "채택 — 내 수정이 만든 둘 + 새 것 넷은 본문에서 닫고, 나머지는 §15 알려진 한계·§Deferred to plan 에 명시한다" — finding 없이 바뀜: 6.5.1 breaking 전수 (C19 · OQ15) (modified)
- D2.13 · r2 · adopt · 3dc9f893#r2.1 · "채택 — 내 수정이 만든 둘 + 새 것 넷은 본문에서 닫고, 나머지는 §15 알려진 한계·§Deferred to plan 에 명시한다" — 닫힌 reason 열거가 존치하는 미판정 상태를 모두 받지 못한다. 테스트 미실행·귀속 실패·리뷰 항목 소실의 최종 판정을 정의해야 한다.
- D2.14 · r2 · adopt · 47775166#r2.1 · "채택 — 내 수정이 만든 둘 + 새 것 넷은 본문에서 닫고, 나머지는 §15 알려진 한계·§Deferred to plan 에 명시한다" — finding 없이 바뀜: 6.3.1 각도 셋 (C13 + D5) (modified)
- D2.15 · r2 · adopt · 50e30a6c#r2.1 · "채택 — 내 수정이 만든 둘 + 새 것 넷은 본문에서 닫고, 나머지는 §15 알려진 한계·§Deferred to plan 에 명시한다" — finding 없이 바뀜: 6.2.1 선언 (modified)
- D2.16 · r2 · adopt · 6099ee68#r2.1 · "채택 — 내 수정이 만든 둘 + 새 것 넷은 본문에서 닫고, 나머지는 §15 알려진 한계·§Deferred to plan 에 명시한다" — finding 없이 바뀜: 9. brief 정정 셋 (modified)
- D2.17 · r2 · adopt · 737cd2ec#r2.1 · "채택 — 내 수정이 만든 둘 + 새 것 넷은 본문에서 닫고, 나머지는 §15 알려진 한계·§Deferred to plan 에 명시한다" · supersedes D1.2 — 채택 후 미적용(expired): 현재 브랜치가 다른 구성원 브랜치의 조상이면 끝점 집합에 없어 봉인 커밋 치환이 불가능하다. 봉인을 반영한 뒤 끝점을 계산하는 등의 규칙이 필요하다.
- D2.18 · r2 · adopt · b3b6ed3b#r2.1 · "채택 — 내 수정이 만든 둘 + 새 것 넷은 본문에서 닫고, 나머지는 §15 알려진 한계·§Deferred to plan 에 명시한다" · supersedes D1.6 — 채택 후 미적용(expired): 끝점을 `T` 안에서만 고르므로 브랜치의 마지막 선언 커밋 «뒤»의 미선언 커밋은 합친 트리에서 통째로 빠지는데 공시가 없다 — §6.2.7 은 경계 «앞»만 세고 현재 브랜치는 봉인이 가려 주지만 이미 머지된·형제 브랜치에서는 그대로 소실되어 「`clean` 은 그 튜플에 대한 clean」이 깨진다.
- D2.19 · r2 · adopt · bf618af4#r2.1 · "채택 — 내 수정이 만든 둘 + 새 것 넷은 본문에서 닫고, 나머지는 §15 알려진 한계·§Deferred to plan 에 명시한다" · supersedes D1.7 — 채택 후 미적용(expired): 디스패치를 모델 도출로 내리면서 헌장의 처분 회계 계약과의 관계를 설계가 정하지 않았다 — 매 dispatch 자리의 `**처분** — consumer=… · fail-… · disclosure=…` 줄을 도출된 수행자에 어떻게 붙이는지, 현 `fail-open` 이 각도 fail-closed 로 바뀌는지, 신설 사본 둘의 처분 자리는 어디인지가 없고, 브리프가 이름 붙인 blind spot(「항상-디스패치 바닥은 회계의 기대값 앵커이기도 했다」)이 §5·§10 어디에서도 처분을 받지 않았다.
- D2.20 · r2 · adopt · c32704ec#r2.1 · "채택 — 내 수정이 만든 둘 + 새 것 넷은 본문에서 닫고, 나머지는 §15 알려진 한계·§Deferred to plan 에 명시한다" — finding 없이 바뀜: 10. Open Questions 처분표 (modified)
- D2.21 · r2 · adopt · d204606d#r2.1 · "채택 — 내 수정이 만든 둘 + 새 것 넷은 본문에서 닫고, 나머지는 §15 알려진 한계·§Deferred to plan 에 명시한다" — finding 없이 바뀜: 6.4.2 해상도 공시 (D2 — C14 재결정) (modified)
- D2.22 · r2 · adopt · db12e61a#r2.1 · "채택 — 내 수정이 만든 둘 + 새 것 넷은 본문에서 닫고, 나머지는 §15 알려진 한계·§Deferred to plan 에 명시한다" · supersedes D1.8 — 채택 후 미적용(expired): D1 의 「셋이 부딪히면 단순함이 이긴다」는 §14 가 「순서는 곧 대체다」라며 기각한 바로 그 형태이고 — 실제로 본문의 D1 판정 넷이 전부 「단순함이 이김」이라 비용·시간·SDD 맞물림이 이긴 갈림이 0건이다 — C1 의 「넷 대등」을 유지할지 「신뢰도 필터 + 단순함 우선」을 C1 의 근거 있는 재결정으로 명시할지 사용자가 정해야 한다.
- D2.23 · r2 · adopt · fe2f8d17#r2.1 · "채택 — 내 수정이 만든 둘 + 새 것 넷은 본문에서 닫고, 나머지는 §15 알려진 한계·§Deferred to plan 에 명시한다" · supersedes D1.9 — 채택 후 미적용(expired): 선언된 커밋만으로 경계와 끝점을 정하면 선언이 묶는 브랜치 전체가 빠질 수 있다. 브랜치 전체를 포함할지 선언 커밋으로 범위를 좁힐지 결정해야 한다.

## Handoff Context

`/compact` 뒤 이 문서만 읽고 이어갈 수 있도록, 이 문서 밖에만 있는 것을 여기 적는다.

- **상류** — 인터뷰 brief(frontmatter `source_interview`)의 §2 가 확정 19항목의 정본이고, 그
  audit(`interview_audit`)의 §6 이 사용자 원문이다. 이 설계의 §5 가 그 19 전부에 대응을 붙였다.
- **실측은 §7 이 전부다** — 이 문서가 기대는 도구 동작 사실 13개가 거기 있고, 그중 **E(경계
  규칙)와 I(임시 인덱스 봉인)는 구현 전에 재검증해야 한다**고 적혀 있다.
- **이 리포에는 선재 RED 가 있다.** 착수 전 baseline 을 캡처하되 rc 만이 아니라 **실패 파일 이름과
  실패 줄 수**를 함께 기록한다 — 이미 RED 인 파일 안의 새 실패는 rc 로는 원리적으로 안 보인다.
- **세션 격리** — 이 작업은 워크트리 `.claude/worktrees/qg-review-only-sdd-scope` 에서 진행됐다.
  브랜치는 `feature/qg-review-only-sdd-scope`.
- **머지 규약** — `gh pr merge` 는 auto-mode 판정기가 막는다. 머지는 사용자가 직접 실행한다.

### Deferred to plan

이 문서가 정하지 않고 구현 계획에 넘기는 것. **판정에 영향을 주는 것은 여기 두지 않는다.**

- 새 스크립트 셋(`resolve-topic.sh` · `seal-worktree.sh` · `combine-tips.sh`)의 정확한 CLI 표면과
  출력 키 이름. 계약은 §6.2·§6.4.1 이 정했고 표기는 구현이 정한다.
- 제거 대상 테스트의 **최종 목록**. §12 가 도출 규칙(4토큰 + `sandbox|mutation.guard` grep)을
  정했고, 그 grep 을 실제로 돌려 확정하는 것은 계획의 일이다.
- 새 락 5종의 픽스처 구성과 mutation 변이의 구체 문면. 축 넷과 양성 대조 요구는 §13 이 정했다.
- `run-test-selection.sh` 의 러너 어댑터 표를 건드리는지 여부 — §6.4.2 는 새 계산이 없다고
  적었으므로 기본은 「안 건드린다」이고, 구현이 반증하면 보고한다.
- 각 PR 의 버전 번호. §16 이 순서를 정했고 번호는 머지 직전에 정한다.

## Metadata

- **상류** — `docs/superpowers/interview/2026-09-21-qg-target-derived-judgment-interview.md`
  (Phase 1 brief, 확정 19 · 열린 19) 및 그 audit
- **Phase 0 seed** — `docs/superpowers/interview/2026-09-21-qg-review-only-sdd-scope-interview.md`
- **대상 플러그인** — `quality-gates` (현재 7.6.2 → **major**, breaking)
- **동반 bump** — `spec-distill` (**minor 이상** — `shared/docreview` 슬롯 변경은 surface 변경이다)
- **버전 번호는 브랜치에서 정하지 않는다** — 머지 직전에 정한다. 같은 버전 문자열은 충돌 없이
  병합되므로 먼저 머지되는 쪽이 이긴다.
- **다음 단계** — `spec-distill:reviewing-spec` 으로 이 문서를 리뷰한 뒤, 승인 게이트에서 진행을
  고르면 `superpowers:writing-plans`
