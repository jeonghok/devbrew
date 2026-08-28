---
name: request-framing-phase0
type: interview-brief
created_at: 2026-08-22
session_id: 6fc6c085-03f0-4a6c-8596-b1040747f06d
source: spec-distill conducting-interview v0.23.0
next_phase: superpowers:brainstorming
audit_file: 2026-08-22-request-framing-phase0-interview.audit.md
user_sourced_items:
  - id: C1
    source: chosen
    status: confirmed
    statement: "seed 소비자는 지금 spec-distill:interview 하나 — 스키마는 소비자 중립으로 두어 확장점만 남기고 image-gen 어댑터는 구현하지 않는다"
    evidence: S1
  - id: C2
    source: chosen
    status: confirmed
    statement: "작업을 기술하는 필드는 허용하고 다음 단계의 답이 들어갈 슬롯은 금지 — 미확정 재료는 항목 라벨 open 으로만 표시하고 별도 섹션으로 모으지 않는다"
    evidence: S2
  - id: C3
    source: chosen
    status: provisional
    statement: "codex 는 비평자 — Claude 초안에 Suppression Review 를 독립 수행하고 기존 findings 스키마를 재사용한다"   # SUPERSEDED by C13 — 유효 제약은 C13
    evidence: S3
  - id: C4
    source: chosen
    status: confirmed
    statement: "/request-framing 을 신설하고 /interview 는 기존 동작을 유지하되 seed 아닌 입력에 한 줄 조언만 띄운다"
    evidence: S4
  - id: C5
    source: chosen
    status: confirmed
    statement: "Phase 0 종료 게이트는 기존 proceed-gate 와 같은 모양의 4옵션 — 새 세션에서 시작(경로+명령문 노출 후 턴 종료) / compact 후 이어서 / 수정 / 멈춤"
    evidence: S5
  - id: C6
    source: chosen
    status: confirmed
    statement: "새 단계를 만든다(steelman 방어) — blind-spot 8건은 반박이 아니라 설계 제약으로 흡수한다"
    evidence: S6
  - id: C7
    source: verbatim
    status: confirmed
    statement: "산출물은 프롬프트이고 자명한 사실·세세한 내용이 아닐 것이라 길지 않고 명확할 것이며, 그 정도면 사용자가 바로 리뷰 가능하고 그 프롬프트는 사용자의 결정이다"
    evidence: S7
  - id: C8
    source: chosen
    status: confirmed
    statement: "그 라운드에 제시한 선택지 집합 전체를 audit 에 기록한다 — 고른 것만이 아니라 제시된 것 전부"
    evidence: S8
  - id: C9
    source: chosen
    status: confirmed
    statement: "/interview 를 좁히지 않는다 — 원문의 좁히기 지시를 호환성을 위해 기각했다는 사실을 §5 에 명시한다"
    evidence: S9
  - id: C10
    source: verbatim
    status: confirmed
    statement: "codex 부재를 이유로 구현을 미루지 않는다"
    evidence: S10
  - id: C13
    source: chosen
    status: confirmed
    statement: "비평자는 역할 슬롯 — 항상 가용한 격리 agent 가 기본 구현이고 codex 는 모델 다양성 업그레이드다"
    evidence: S13
  - id: C11
    source: chosen
    status: confirmed
    statement: "seed 는 docs/ 아티팩트로 — brief 와 같은 자리, 세션 스코프 자동 삭제 영역 밖. git 이력에 남는 것을 받아들인다"
    evidence: S11
  - id: C12
    source: chosen
    status: confirmed
    statement: "이 단계의 효과를 측정하지 않는다는 것을 §1 Non-goal 에 명시한다 — 측정 없음을 숨기지 않고 선택으로 드러낸다"
    evidence: S12
  - id: C14
    source: verbatim
    status: confirmed
    statement: "confirmed 항목만 제약으로 취급하고 inferred·external·open 항목은 검증하거나 재질문할 수 있다고 seed 에 명시한다"
    evidence: S0
  - id: C15
    source: verbatim
    status: confirmed
    statement: "raw dump 자체를 곧바로 실행 프롬프트로 사용하지 않는다"
    evidence: S0
  - id: C16
    source: verbatim
    status: confirmed
    statement: "성공 조건에 의미 없는 수치를 만들지 않는다 — 기계 검증이 가능하면 기계로, 아니면 관찰 가능한 인수 시나리오나 판단 rubric 으로"
    evidence: S0
  - id: C17
    source: verbatim
    status: confirmed
    statement: "거친 프롬프트·생각·대화·링크·자료를 판단하거나 요약하기 전에 원형대로 보존한다"
    evidence: S0
  - id: C18
    source: verbatim
    status: confirmed
    statement: "사용자 발화·에이전트 추론·외부 근거·미결 질문의 출처와 확정 상태를 분리한다"
    evidence: S0
  - id: C19
    source: verbatim
    status: confirmed
    statement: "현재 이해와 원문 사이의 차이를 드러내고, 답에 따라 최종 프롬프트가 실질적으로 달라지는 질문을 집요하게 제기한다"
    evidence: S0
  - id: C20
    source: verbatim
    status: confirmed
    statement: "목표·대상 사용자와 소비자·입력 자료·실행 환경·권한과 승인 경계·제약·non-goal·성공 증거·중지와 handoff 조건을 최소한 확인한다"
    evidence: S0
  - id: C21
    source: verbatim
    status: confirmed
    statement: "질문 수를 목표로 삼지 않고 미충족 커버리지를 종료 기준으로 쓴다"
    evidence: S0
  - id: C22
    source: verbatim
    status: confirmed
    statement: "사용자가 모르는 사실·선택지를 외부 탐색으로 보완하되 외부 사례를 사용자 요구사항으로 임의 승격하지 않는다"
    evidence: S0
  - id: C23
    source: verbatim
    status: confirmed
    statement: "사용자의 표현을 단순히 문장 교정하지 말고 실제 실행 환경의 계약으로 변환한다"
    evidence: S0
  - id: C24
    source: verbatim
    status: confirmed
    statement: "실행 대상을 감지해 확장 가능한 profile 을 적용하되, profile 별 로직을 복제하지 말고 공통 계약과 대상별 adapter 로 구성한다"
    evidence: S0
  - id: C25
    source: verbatim
    status: confirmed
    statement: "정제 과정의 추가·삭제·변경을 보여주고, 근거 없는 제약·예시를 필수로 오인·조기 닫힘 표현·사용자 결정처럼 표현된 추론을 별도 표시한다"
    evidence: S0
  - id: C26
    source: verbatim
    status: confirmed
    statement: "사용자가 승인하기 전에는 이를 확정된 프롬프트로 만들지 않는다"
    evidence: S0
  - id: C27
    source: verbatim
    status: confirmed
    statement: "seed 는 독립적으로 이해 가능해야 하며, 새 세션에는 전체 대화 로그가 아니라 compact 한 실행 프롬프트와 원본 artifact 경로를 주입한다"
    evidence: S0
  - id: C28
    source: verbatim
    status: confirmed
    statement: "meta-prompting 은 내부 메커니즘 명칭으로만, 사용자-facing 단계명은 request-framing, 산출물명은 interview-seed 로 쓴다"
    evidence: S0
  - id: C29
    source: verbatim
    status: confirmed
    statement: "R1 Reframe 을 Problem Reframe 으로 재정의하고, Phase 0 외부탐색은 프롬프트 구성 컨텍스트 공백을, interview landscape 는 문제·도메인 대안과 prior art 를 맡는다"
    evidence: S0
  - id: C30
    source: verbatim
    status: confirmed
    statement: "이미 충분히 정제된 입력은 Phase 0 를 짧게 통과할 수 있으나, 확정되지 않은 핵심 가정이 남으면 자동으로 interview 로 넘어가지 않는다"
    evidence: S0
---

# request-framing Phase 0 — Interview Brief

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 brainstorming 해답공간으로
> 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다. 텔레메트리는 `audit_file`에 있다.

## 0. 한눈에

**무엇** — spec-distill 파이프라인 맨 앞에 `request-framing` 단계를 신설한다. 거친 요청을 판단·요약 전에 원형 보존하고, 의도를 정렬하고, 실행 대상별 adapter 로 계약형 프롬프트를 만들고, 정제 과정에서 무엇이 더해졌는지 표면화해 승인받은 뒤 `interview-seed` 로 다음 세션에 넘긴다.

**왜** — 문제는 "인터뷰가 없다"가 아니라 **에이전트 추론이 사용자 결정으로 위장한 채 하류로 흘러가는 것**이다. 이 인터뷰에서 확인된 실재 갭 하나: 최초 요청 원문의 §6 보존은 템플릿 관례일 뿐 게이트 15항 어디에도 없다(`finishing.md:31` 이 §6 을 `user_statements` 에서 채우는데 `$ARGUMENTS` 는 거기 안 들어간다).

**무엇이 확정** — 소비자는 interview 하나·스키마는 중립(C1) / 답 슬롯 금지(C2) / 비평자는 역할 슬롯이고 격리 agent 가 기본, codex 는 업그레이드(C13), codex 부재로 구현을 미루지 않음(C10) / 별도 command + 조언, `/interview` 는 좁히지 않음(C4+C9) / 4옵션 종료 게이트(C5) / 새 단계를 만든다(C6) / 산출물이 길지 않고 명확**할 것이므로** 사용자가 바로 리뷰 가능하고 승인된 프롬프트는 사용자 결정(C7 — 이는 사용자의 **예상**이며 아직 관측되지 않았다) / 제시한 선택지 전부 audit 기록(C8) / seed 는 `docs/` 아티팩트(C11) / 효과는 측정하지 않는다(C12) / S0 원문에서 승격한 구속 요구 14건(C17–C30). **proceed 게이트에서 29건이 `confirmed` 로 전이했다.** 유일한 예외는 **C3**(`provisional` 유지) — C13 이 그 범위를 바꿨으므로 확정하면 충돌하는 유효 제약 두 개가 생긴다. confirmed 항목도 근거가 있으면 보고 후 재결정 가능하며, 임의 변경은 금지다.

**무엇이 열려 있음** — §3. 특히 trivia escape 소유권, proceed-gate 채택자 테스트의 이빨 보존, profile 공통 계약의 형태, 그리고 방향성 리뷰가 올린 이월 3건(D1·D2·D3).

**이 §0 의 한계** — 방향성 리뷰(D1)가 지적한 대로, 검증을 통과한 갭은 5단계 중 Raw Capture 하나이고 그 수리 비용은 한 줄이다. 나머지 네 단계(Intent Alignment · Prompt Shaping · Suppression Review · Session Handoff)의 필요성은 **검증되지 않았고 사용자 판단으로 채택됐다**(C6). 이 문서는 그 비대칭을 숨기지 않는다.

**다음 stage** — `superpowers:brainstorming` (해법 선택).

## 1. Goal · Non-goal

- Goal: 거친 요청을 다음 에이전트가 실행 가능한 계약으로 바꾸되, 그 변환에서 에이전트 추론이 사용자 결정으로 위장하는 것을 구조적으로 막는다.
- Goal: 산출물은 **프롬프트**다 — 다음 단계의 탐색 공간을 미리 좁히는 구조를 담지 않는다.
- Goal: **독립 비평자**가 그 프롬프트를 비평한다 — 쓴 쪽이 승인하지 않는다. 비평자는 역할 슬롯이고, 항상 가용한 격리 agent 가 기본 구현이며 codex 는 모델 다양성 업그레이드다(C13). codex 부재는 구현을 미루는 이유가 되지 않는다(C10).
- Non-goal: 요구사항 인터뷰를 여기서 시작하지 않는다 — 문제·도메인의 대안과 prior art 탐색은 Phase 1 의 몫이다.
- Non-goal: image-generation adapter 를 구현하지 않는다(C1) — 검증할 다운스트림이 이 리포에 없다.
- Non-goal: `/interview` 를 차단하지 않는다(C4) — 호환성 유지가 명시 요구다.
- Non-goal: **확정되지 않은 핵심 가정이 남아 있는 채로** seed 생성 후 자동으로 interview 로 진행하지 않는다. 원문의 금지는 조건부다 — "이미 충분히 정제된 입력은 Phase 0를 짧게 통과할 수 있지만, 확정되지 않은 핵심 가정이 남아 있는데 자동으로 interview로 넘어가서는 안 된다"(§6 S0). 짧은 통과 자체는 허용된다.
- Non-goal: **이 단계의 효과를 측정하지 않는다**(C12). 억제를 막았다는 것의 반사실은 관측 불가능하고, 대리 지표는 대상을 재지 않는다. 측정 없이 진행한다는 사실을 숨기지 않고 여기 적는다 — 이 단계를 제거하게 만들 관측은 정해지지 않았다.
- Non-goal: `/interview` 를 좁히지 않는다(C9). 원문은 "Phase 1 역할로 좁혀라"고 했으나 호환성 유지를 위해 그 지시를 기각했다 — §5 에 기각으로 명시돼 있다.

✎ (모델 추론) 요청문의 `Phase 0` 라는 이름은 README 의 `[0]`(trivia escape 점유)과 충돌한다. 사용자-facing 단계명 `request-framing` 은 **C28 로 원장에 올라 있으므로**(다른 항목과 같이 `provisional`) 번호 표기만 §3 OQ8 로 넘긴다.

## 2. 제약

- ☑ confirmed **C1** — seed 소비자는 지금 spec-distill:interview 하나 — 스키마는 소비자 중립으로 두어 확장점만 남기고 image-gen 어댑터는 구현하지 않는다 ⟨S1⟩
- ☑ confirmed **C2** — 작업을 기술하는 필드는 허용하고 다음 단계의 답이 들어갈 슬롯은 금지 — 미확정 재료는 항목 라벨 open 으로만 표시하고 별도 섹션으로 모으지 않는다 ⟨S2⟩
- ☑ provisional **C3** — codex 는 비평자 — Claude 초안에 Suppression Review 를 독립 수행하고 기존 findings 스키마를 재사용한다 ⟨S3⟩
- ☑ confirmed **C4** — /request-framing 을 신설하고 /interview 는 기존 동작을 유지하되 seed 아닌 입력에 한 줄 조언만 띄운다 ⟨S4⟩
- ☑ confirmed **C5** — Phase 0 종료 게이트는 기존 proceed-gate 와 같은 모양의 4옵션 — 새 세션에서 시작(경로+명령문 노출 후 턴 종료) / compact 후 이어서 / 수정 / 멈춤 ⟨S5⟩
- ☑ confirmed **C6** — 새 단계를 만든다(steelman 방어) — blind-spot 8건은 반박이 아니라 설계 제약으로 흡수한다 ⟨S6⟩
- 🗣 confirmed **C7** — 산출물은 프롬프트이고 자명한 사실·세세한 내용이 아닐 것이라 길지 않고 명확할 것이며, 그 정도면 사용자가 바로 리뷰 가능하고 그 프롬프트는 사용자의 결정이다 ⟨S7⟩
- ☑ confirmed **C8** — 그 라운드에 제시한 선택지 집합 전체를 audit 에 기록한다 — 고른 것만이 아니라 제시된 것 전부 ⟨S8⟩
- ☑ confirmed **C9** — /interview 를 좁히지 않는다 — 원문의 좁히기 지시를 호환성을 위해 기각했다는 사실을 §5 에 명시한다 ⟨S9⟩
- 🗣 confirmed **C10** — codex 부재를 이유로 구현을 미루지 않는다 ⟨S10⟩
- ☑ confirmed **C13** — 비평자는 역할 슬롯 — 항상 가용한 격리 agent 가 기본 구현이고 codex 는 모델 다양성 업그레이드다 ⟨S13⟩
- ☑ confirmed **C11** — seed 는 docs/ 아티팩트로 — brief 와 같은 자리, 세션 스코프 자동 삭제 영역 밖. git 이력에 남는 것을 받아들인다 ⟨S11⟩
- ☑ confirmed **C12** — 이 단계의 효과를 측정하지 않는다는 것을 §1 Non-goal 에 명시한다 — 측정 없음을 숨기지 않고 선택으로 드러낸다 ⟨S12⟩
- 🗣 confirmed **C14** — confirmed 항목만 제약으로 취급하고 inferred·external·open 항목은 검증하거나 재질문할 수 있다고 seed 에 명시한다 ⟨S0⟩
- 🗣 confirmed **C15** — raw dump 자체를 곧바로 실행 프롬프트로 사용하지 않는다 ⟨S0⟩
- 🗣 confirmed **C16** — 성공 조건에 의미 없는 수치를 만들지 않는다 — 기계 검증이 가능하면 기계로, 아니면 관찰 가능한 인수 시나리오나 판단 rubric 으로 ⟨S0⟩
- 🗣 confirmed **C17** — 거친 프롬프트·생각·대화·링크·자료를 판단하거나 요약하기 전에 원형대로 보존한다 ⟨S0⟩
- 🗣 confirmed **C18** — 사용자 발화·에이전트 추론·외부 근거·미결 질문의 출처와 확정 상태를 분리한다 ⟨S0⟩
- 🗣 confirmed **C19** — 현재 이해와 원문 사이의 차이를 드러내고, 답에 따라 최종 프롬프트가 실질적으로 달라지는 질문을 집요하게 제기한다 ⟨S0⟩
- 🗣 confirmed **C20** — 목표·대상 사용자와 소비자·입력 자료·실행 환경·권한과 승인 경계·제약·non-goal·성공 증거·중지와 handoff 조건을 최소한 확인한다 ⟨S0⟩
- 🗣 confirmed **C21** — 질문 수를 목표로 삼지 않고 미충족 커버리지를 종료 기준으로 쓴다 ⟨S0⟩
- 🗣 confirmed **C22** — 사용자가 모르는 사실·선택지를 외부 탐색으로 보완하되 외부 사례를 사용자 요구사항으로 임의 승격하지 않는다 ⟨S0⟩
- 🗣 confirmed **C23** — 사용자의 표현을 단순히 문장 교정하지 말고 실제 실행 환경의 계약으로 변환한다 ⟨S0⟩
- 🗣 confirmed **C24** — 실행 대상을 감지해 확장 가능한 profile 을 적용하되, profile 별 로직을 복제하지 말고 공통 계약과 대상별 adapter 로 구성한다 ⟨S0⟩
- 🗣 confirmed **C25** — 정제 과정의 추가·삭제·변경을 보여주고, 근거 없는 제약·예시를 필수로 오인·조기 닫힘 표현·사용자 결정처럼 표현된 추론을 별도 표시한다 ⟨S0⟩
- 🗣 confirmed **C26** — 사용자가 승인하기 전에는 이를 확정된 프롬프트로 만들지 않는다 ⟨S0⟩
- 🗣 confirmed **C27** — seed 는 독립적으로 이해 가능해야 하며, 새 세션에는 전체 대화 로그가 아니라 compact 한 실행 프롬프트와 원본 artifact 경로를 주입한다 ⟨S0⟩
- 🗣 confirmed **C28** — meta-prompting 은 내부 메커니즘 명칭으로만, 사용자-facing 단계명은 request-framing, 산출물명은 interview-seed 로 쓴다 ⟨S0⟩
- 🗣 confirmed **C29** — R1 Reframe 을 Problem Reframe 으로 재정의하고, Phase 0 외부탐색은 프롬프트 구성 컨텍스트 공백을, interview landscape 는 문제·도메인 대안과 prior art 를 맡는다 ⟨S0⟩
- 🗣 confirmed **C30** — 이미 충분히 정제된 입력은 Phase 0 를 짧게 통과할 수 있으나, 확정되지 않은 핵심 가정이 남으면 자동으로 interview 로 넘어가지 않는다 ⟨S0⟩

✎ (모델 추론, 게이트 대상 아님) **C3 은 이후 좁혀졌다.** C3 은 S3 시점의 선택("codex 가 Suppression Review 를 독립 수행")을 그대로 옮긴 것이고, S10·S13 이 그 범위를 바꿨다 — 유효한 제약은 **C13**(비평자는 역할 슬롯, 격리 agent 가 기본 구현)이며 codex 는 업그레이드다. §2 만 읽고 C3 을 "codex 단독 수행"으로 받으면 안 된다. C3 을 지우지 않는 이유는 S3 이 실제로 그 선택이었기 때문이고, 그 변화의 이력은 §5 기각 항목에 남아 있다.

✎ (모델 추론, 게이트 대상 아님) C14·C15·C16 은 라운드 선택이 아니라 **S0 최초 요청에서 직접 승격한 구속 요구**다. 충실도 리뷰 라운드 2 가 "S0 의 구속 요구 중 §2 로 승격된 것이 0건"임을 적발해 추가했다 — 이 brief 가 설계하는 기능(원문이 요약 층에서 증발하는 것을 막기)의 실패를 이 brief 자신이 저지르고 있었다.

✎ (모델 추론, 게이트 대상 아님) C7 은 blind-spot 이 제기한 "승인 피로 → rubber-stamping" 위험에 대한 사용자 판정이다. 완화책을 승인 UI 가 아니라 **산출물 크기 자체**에 둔다는 뜻이며, 이것이 #127(brief 분량 상한 제거) 결론과도 정합한다 — 짧음은 상한을 씌워서가 아니라 들어가면 안 되는 것을 뺀 결과다.

✎ (모델 추론) 원 요청의 5단계(Raw Capture / Intent Alignment / Prompt Shaping / Suppression Review / Session Handoff)와 **R1 재정의**(`Reframe (메타 프롬프트)` → `Problem Reframe` — 명칭 변경이 아니라 Phase 0 와 중복되지 않게 하는 역할 재정의다), `meta-prompting` 을 내부 명칭으로만 쓰는 규약, 이미 정제된 입력의 단축 통과는 모두 §6 S0 에 원문으로 보존돼 있다. 이 인터뷰가 판정한 것은 그 위의 갈림길들뿐이며, 5단계 구조 자체는 사용자 요구로 그대로 남는다.

## 3. Open Questions

- OQ2: trivia escape 소유권. 5패턴 판정이 `commands/interview.md` Step 2 에만 있는데, `/request-framing` 이 앞에 서면 escape 없이 시작하거나 로직이 두 벌로 갈라진다. C9(좁히지 않음)로 `/interview` 가 그대로 남으므로 이 갈림은 그대로 미해결이다.
- OQ3: `tests/test_proceed_gate_adopters.sh` 의 이빨 보존. 하한이 *개수*이지 *구성원*이 아니어서, request-framing 이 게이트 어휘를 갖는 순간 현재의 치환-RED 가 소멸할 수 있다.
- OQ5: profile 공통 계약의 구체적 형태 — adapter 가 무엇을 공유하고 무엇을 갈아끼우는가. "복제하지 말라"는 요구는 **C24 로 원장에 있으나**(다른 항목과 같이 `provisional`) 계약의 모양은 미정. 기성 답 후보 둘 — Prompty 파일 포맷(YAML frontmatter(model·inputs·outputs·tools) + markdown body, https://prompty.ai/core-concepts/file-format/)과 microsoft/poml(`<role>`·`<task>`·`<example>` 의미 컴포넌트, https://github.com/microsoft/poml) — 을 먼저 평가한다(판정 근거 없어 §4 에서 이관). spec-kit(§4)은 C2·OQ12 관련 판정을 이미 마쳐 이 후보에서 제외.
- OQ6: "확정되지 않은 핵심 가정"의 정의. 어떤 `open` 항목이 진행을 막는 *core* 인가 — C2 로 별도 슬롯을 못 만들게 됐으므로 라벨만으로 판정해야 한다.
- OQ7: degrade 채널 명명. 실측 확인 — `shared/codex/codex_findings_to_yaml.py:56-58` 이 `quota|billing|subscription` 을 `AUTH_ERROR_RE` 에 넣어 **한도 소진을 인증 오류로 분류**한다. 또한 러너가 모델을 핀하지 않아 이 계정에서는 한도와 무관하게 기본 모델이 400 을 받는다. 두 원인이 `exit_nonzero` 하나로 뭉개진다. 어느 층까지 이름을 붙일지 미정.
- OQ8: `Phase 0` 번호 표기. README 의 `[0]` 은 trivia escape 가 점유, `[4]` 는 미사용.
- OQ9: 이 단계의 효과 관측. C12 로 **측정하지 않는다**가 확정됐으나, 방향성 리뷰(D8)의 지적 — C7 은 설계가 참이라는 주장이지 거짓일 때 관측될 신호가 아니다 — 은 그대로 열려 있다. 나중에 제거 관측을 정할지 여부가 미정.
- OQ10 (이월, D1): 정당화의 범위 문제. 검증된 갭은 Raw Capture 하나이고 수리 비용은 한 줄인데 5단계 전체가 그 위에 서 있다. `$ARGUMENTS` → §6 보존을 독립 변경으로 먼저 닫은 뒤 남은 네 단계를 다시 물을 것인가.
- OQ11 (이월, D2): §0 의 "왜"를 'Raw Capture 갭'에서 '새 세션 경계에서 단일 자족 프롬프트로 통합'으로 바꿔 적을 것인가. 후자면 Raw Capture 는 목적이 아니라 통합의 입력으로 강등된다 — 두 설계는 다른 물건이다.
- OQ12 (이월, D3): Phase 0 · interview · brainstorming 이 연속 세 번 요구사항 질문을 한다. 질문 배분 규칙(예: "답이 프롬프트를 바꾸면 Phase 0, 문제 정의를 바꾸면 Phase 1")을 못 박을 것인가, 아니면 Intent Alignment 의 커버리지-구동 루프를 상한 있는 clarification 패스로 바꿀 것인가.

✎ (해소됨) 이전 OQ1(seed 저장 경로)은 전제가 틀려 삭제됐다 — 후보 두 경로가 **둘 다** 세션 종료 시 삭제되는 영역이었다(`hooks/session-end-cleanup.py` 의 `safe_rmtree`, `spec-distill-gc.py` 의 24h TTL). C11 이 `docs/` 아티팩트로 확정했다. 이전 OQ4(seed 철회 경로)도 같은 결정으로 "파일 편집·삭제"라는 평범한 답을 얻었다.

## 4. External Landscape

- REprompt — 사용자 프롬프트를 initial requirements 로 보고 elicitation/analysis/specification/validation 4단계 멀티에이전트로 정련 — https://arxiv.org/html/2601.16507v1 — [취함] — Phase 0 와 가장 가까운 공개 prior art이며, 소비자를 하나로 고정해 얻는 단순함이 C1 판정의 근거가 됐다.
- 에이전트 사전-실행 diff + provenance 추적 패턴 — https://labs.reversec.com/posts/2025/08/design-patterns-to-secure-llm-agents-in-action — [취함] — Suppression Review 가 "실행 전에 무엇을 할 것인지 보여준다"는 형태의 선례.
- LLM 에이전트 provenance 분석 — https://arxiv.org/pdf/2607.01236 — [중립] — 출처 추적의 필요는 지지하나 여기서 다루는 것은 보안 경계가 아니라 저자 귀속이다.
- MAST 멀티에이전트 실패 분류(150 trace) — https://arxiv.org/abs/2503.13657 — [피함] — 경계·핸드오프 신설이 지배적 실패원이라는 논거. C6 에서 방어로 판정했으나 설계 제약으로 흡수한다.
- Poppendieck 핸드오프 손실 — https://6sigma.com/poppendieck-on-waste-the-handoff/ — [피함] — 핸드오프 1회당 암묵지 ~50% 소실. seed 가 "전체 대화 로그가 아니라 compact 한 프롬프트"여야 한다는 요구와 정면으로 만난다.
- DORA 승인 프로세스 — https://dora.dev/capabilities/streamlining-change-approval/ — [피함] — 외부 형식 승인이 실패율을 낮춘다는 증거 없음. C5 의 게이트가 형식이 되지 않게 하는 것이 C7 의 역할이다.
- Anthropic Building Effective Agents — https://www.anthropic.com/engineering/building-effective-agents — [중립] — "결과가 실증적으로 개선될 때만 복잡도를 올려라". OQ9 가 이 항목의 미해결분이다.
- Ferrari et al. 요구공학 인터뷰 모호성 34건 실증 — https://link.springer.com/article/10.1007/s00766-016-0249-3 — [중립] — 개선 지렛대가 루프 내부 탐지라는 논거. Phase 0 와 Phase 1 의 역할 분담을 지지하는 쪽으로도 읽힌다.
- Fowler MonolithFirst — https://martinfowler.com/bliki/MonolithFirst.html — [피함] — 안정적 경계를 알기 전의 분할 경고.
- Metz The Wrong Abstraction — https://sandimetz.com/blog/2016/1/20/the-wrong-abstraction — [피함] — "중복이 잘못된 추상보다 싸다". OQ5(adapter 계약)가 이 위험의 착지점이다.
- Cooper After Stage-Gate — https://media.transformanceadvisors.com/pdfs/After-Stage-Gate.pdf — [피함] — 게이트 추가가 아니라 fluid·conditional 게이트가 처방. "이미 정제된 입력은 짧게 통과"가 이 처방과 같은 방향이다.
- 설명이 오히려 과신을 부른다(XAI 실증) — https://dl.acm.org/doi/10.1145/3579605 — [피함] — 설명의 존재 자체가 내용 평가 없이 신뢰를 올린다. C7 이 이에 대한 사용자 판정이다.
- 승인 피로 — https://aipatternbook.com/approval-fatigue — [피함] — 승인 항목이 늘면 blanket accept 로 붕괴. C7 이 완화책을 크기에 둔다.
- 선호는 제시 구조 위에서 구성된다 — https://academic.oup.com/jcr/article-pdf/25/3/187/5081546/25-3-187.pdf — [취함] — C8(제시한 선택지 전부 기록)의 직접 근거.
- design fixation: 예시의 결함을 지적해도 계승된다 — https://dalyresearch.engin.umich.edu/wp-content/uploads/sites/237/2020/12/Leahy_Daly_McKilligan_Seifert-Design-Fixation-From-Initial-Examples-Provided-Versus-Self-Generated-Ideas.pdf — [피함] — C2 의 슬롯 금지가 내용의 조기 고정까지는 막지 못한다는 경고.
- 프롬프트 압축의 정보 손실 — https://arxiv.org/html/2503.19114 — [피함] — 복잡·다단계 태스크에서 압축이 실질 손실을 낸다. "compact" 요구의 상한선.
- LLM judge 의 탐지 실패와 verbosity bias — https://arxiv.org/pdf/2606.10315 — [피함] — 비평자가 누락을 인지조차 못 하는 실패가 다수. C3 의 codex 비평자가 "선택지 조기 닫힘"을 못 보는 이유와 같은 뿌리.
- LLM-as-a-Judge 편향 정량화 — https://llm-judge-bias.github.io/ — [피함] — 과잉결정을 잡으라는 리뷰어가 길이에 보상을 줄 수 있다.
- LLMs Get Lost In Multi-Turn Conversation — https://arxiv.org/abs/2505.06120 — [중립] — 완전 명세를 여러 턴에 쪼개 주면 평균 39% 성능 저하, 처방은 "필요한 정보를 하나의 프롬프트로 통합". 방향성 리뷰(D2)가 이 단계의 진짜 정당화일 수 있다고 지적한 근거. OQ11 에서 판정.
- GitHub Spec Kit — https://github.com/github/spec-kit — [취함] — `/speckit.specify` 가 거친 요청을 스펙으로 바꾸고 모호한 지점을 본문 **인라인 `[NEEDS CLARIFICATION: …]` 마커**로 표시. C2("별도 섹션으로 모으지 않는다")와 같은 규약의 shipped 구현체 — C2 판정을 뒷받침하는 선례.
- spec-kit `/clarify` 워크플로 — https://deepwiki.com/github/spec-kit/5-spec-driven-development-workflow — [피함] — 질문 **최대 5개**·마커 **최대 3개** 상한. 원문의 "질문 수를 목표로 삼지 말라"(무상한, C21)와 정반대 처방이라 채택하지 않았다. §4 의 Cooper(fluid gate) 항목과는 같은 방향이나 수치 상한 자체는 피함. OQ12 와 맞물린다.

## 5. 기각 · Blind Spots

- 기각 — 새 단계 없이 conducting-interview 의 R1+Round1 심화로 흡수하고 새 command·skill·seed·러너·게이트를 만들지 않는다 → 핵심 사실 주장('요청 원형 보존이 이미 기계 강제됨')이 오케스트레이터 검증에서 반증돼 Raw Capture 가 실재 갭으로 확인됨 — https://arxiv.org/abs/2503.13657 — verdict: defended — ST1
- 기각 — seed 소비자를 임의 다운스트림 에이전트로 여는 범용 프롬프트 도구 → image-gen·research adapter 를 검증할 다운스트림이 이 리포에 없어 관찰 가능한 성공 조건을 쓸 수 없음
- 기각 — `/interview` 가 거친 입력을 차단하고 framing 을 강제 → "호환성 유지" 명시 요구와 충돌하고, 원문 자체가 "이미 충분히 정제된 입력은 짧게 통과"를 허용함
- 기각 — **확정되지 않은 핵심 가정이 남은 채로** seed 생성 즉시 자동으로 interview 를 이어서 실행 → 원문이 그 조건에서 직접 금지했고(짧은 통과 자체는 허용), 리포가 polite handoff · cross-compact 조기 진행으로 이미 두 번 막은 실패 양식
- 기각 — codex 를 profile 감지에만 사용 → 감지는 판정이 아니라 분류라 모델 다양성 이득이 없고, 틀리면 조용히 잘못된 profile 로 진행되는 fail-open
- 기각 — "OQ 섹션만" 콕 집어 금지 → 규칙이 예시 하나에 결박되어 같은 닫힘을 다른 이름(대안 목록·AC 초안·리스크 목록)으로 하면 통과함
- 기각 — `chosen` 에 새 provenance 등급을 추가해 저자를 표시 → 이미 verbatim/chosen 으로 구분되며, 라벨을 늘려도 *제시되지 않은* 선택지는 여전히 불가시
- 기각 — **원문의 "`/interview` 를 Phase 1 역할로 좁혀라" 지시** → 호환성 유지를 우선해 기각(C9). 원문은 두 절이었고 첫 절("호환성을 유지하고")만 결정으로 전환됐다. 이 기각은 사용자 판정이며, 지시가 조용히 증발하지 않도록 여기 명시한다. 부작용: OQ2(trivia escape 소유권)가 미해결로 남는다
- 기각 — Suppression Review 의 비평자를 codex 단독으로 두는 것(원안 C3 의 좁은 독법) → codex 가 이 설계의 구현·검증 창 전체에서 돌지 않는 것이 실측됐고 감지기가 그것을 보지 못하므로, 비평자를 **역할 슬롯**으로 재정의하고 항상 가용한 격리 agent 를 기본 구현으로 둔다(C13). codex 는 모델 다양성 업그레이드로 남으며, 그 부재가 구현을 미루는 이유는 되지 않는다(C10)
- 기각 — **원문의 "codex 도 메타프롬프트를 도출하는 과정에 활용되게 구현하자" 를 codex 필수로 읽는 독법** → codex 를 필수 구성요소로 두면 이 설계는 오늘 비평자 0명으로 돈다(실측). 원문 지시는 C13 으로 강등돼 "codex 는 업그레이드"가 됐다. 이 강등은 사용자 판정(S10·S13)이며, C9 와 대칭으로 여기 명시해 원문 지시가 조용히 증발하지 않게 한다
- 위험 — 실패 양식(**실측 확인, 2026-08-22**): codex 러너가 이 계정에서 2층으로 실패한다. (1) 러너 4종이 모델을 핀하지 않아 기본 `gpt-5.6-sol` 이 나가고 `400 invalid_request_error: not supported when using Codex with a ChatGPT account`. (2) `-m gpt-5.5` 로 재시도하면 `usage limit` — 오류 메시지상 2026-09-17 21:03 까지(사용자는 8-31 로 말함, 두 값이 불일치). 첫 오류가 둘째를 가려 degrade record 에는 `exit_nonzero` 하나만 남는다 — `plugins/spec-distill/scripts/codex-direction.yaml` 실행 결과
- 위험 — 실패 양식(**실측 확인**): `shared/codex/codex_findings_to_yaml.py:56-58` 이 `quota|billing|subscription` 을 `AUTH_ERROR_RE` 에 포함시켜 **한도 소진을 인증 오류로 분류**한다. 사용자는 고칠 수 없는 것을 고치려 들게 된다 — `shared/codex/codex_findings_to_yaml.py:56-58`
- 위험 — 실패 양식: 이 설계의 정당화 범위가 근거 범위보다 넓다. 검증된 갭은 5단계 중 Raw Capture 하나이고 수리 비용은 한 줄(`finishing.md:31` + `SKILL.md:134` 의 정의 + 단언 1개)인데 §0 이 5단계 전체를 그 위에 세운다 — 방향성 리뷰 D1, OQ10 으로 이월
- 위험 — 숨은 가정: Phase 0 · interview · brainstorming 이 같은 사용자에게 **연속 세 번** 요구사항 질문을 한다. MAST 가 지목한 duplicate role · ambiguous role definition 의 형태이며, 질문 배분 경계를 소유한 규칙이 없다 — https://arxiv.org/abs/2503.13657 (D3, OQ12 로 이월)
- 위험 — 숨은 가정: `source: chosen` 자체가 laundering 경로다. 선택지를 저술한 것은 모델인데 산출물에는 ☑ 사용자 결정 라벨이 붙는다. `inferred` 만 게이트로 차단되고 `chosen` 은 허용된다 — 이 brief 의 C1~C6·C8·C9·C11·C12·C13 이 전부 그 형태다(충실도 리뷰가 C10 을 이 목록에서 빠뜨린 오라벨을 적발해 C10/C13 으로 분리했다) — https://academic.oup.com/jcr/article-pdf/25/3/187/5081546/25-3-187.pdf
- 위험 — 실패 양식(**하니스 자체의 결함, 미반영 finding**): `check_brief.py` 가 강제하는 sentinel 문장 `# confirmed 0건 — 사용자가 전부 잠정으로 판단` 은 §6 에 근거가 없다. 사용자는 항목을 잠정으로 "판단"한 적이 없고, 전부 provisional 인 것은 *파이프라인 규칙*(확정은 proceed 게이트에서만)의 산물이다. 규칙의 산물을 사용자 판단으로 귀속하는 문장을 게이트가 요구하며, 저자는 그 문구를 바꿀 권한이 없다(지우면 red) — `plugins/spec-distill/scripts/check_brief.py`
- 위험 — 실패 양식: "선택지 조기 닫힘"은 codex 비평자가 원리적으로 볼 수 없다. 닫힌 선택지는 어떤 산출물에도 표현이 없고 리뷰어 코퍼스는 산출물뿐이다 — C8 이 부분적 대응이나 완전하지 않다 — https://arxiv.org/pdf/2606.10315
- 위험 — 실패 양식: `shared/codex/detect_codex.sh` 는 바이너리·auth·버전만 보고 **실제 호출을 하지 않아** 한도 소진과 모델 거부를 원리적으로 관측할 수 없다 — 두 조건 모두에서 `available: true` 를 낸다. C13 이 비평자를 역할 슬롯으로 바꿔 "유일한 비평자가 비었는데 있다고 보고" 되는 최악은 피했지만, 감지기 자체의 거짓 양성은 그대로다 — `shared/codex/detect_codex.sh`
- 위험 — 실패 양식: trivia escape 소유권. 5패턴 판정 로직이 `commands/interview.md` Step 2 에만 있어 `/request-framing` 이 앞에 서면 한 문장 요청에 full ceremony 가 붙거나 로직이 두 벌로 갈라진다 — `plugins/spec-distill/commands/interview.md`
- 위험 — 실패 양식: `tests/test_proceed_gate_adopters.sh` 의 하한이 개수이지 구성원이 아니다. 오늘 치환이 RED 인 것은 대체 후보가 게이트 어휘를 0줄 갖기 때문인데, request-framing 은 그 어휘를 반드시 갖게 되므로 그 우연을 소멸시킨다 — `plugins/spec-distill/tests/test_proceed_gate_adopters.sh`
- 위험 — 숨은 가정: "compact 한 실행 프롬프트" 요구가 #127(brief 분량 상한 제거, 2026-08-22 머지)의 결론과 역주행할 수 있다. C7 이 이를 "상한이 아니라 배제의 결과"로 해소했으나, 구현에서 수치 상한으로 되살아나면 같은 함정이다 — https://arxiv.org/html/2503.19114
- 위험 — 실패 양식(**부분 해소**): 승인된 seed 가 인터뷰 중 사용자의 새 발화와 경쟁하는 문제. C11 이 seed 를 `docs/` 파일로 확정하면서 철회 경로는 "파일 편집·삭제"라는 평범한 답을 얻었으나, *어느 쪽이 이기는가*(seed 의 승인된 제약 vs 인터뷰 중 새 발화)의 규칙은 여전히 없다 — C11
- 위험 — 숨은 가정: 이 단계의 효과를 재는 oracle 이 없다. C12 로 "측정하지 않는다"가 명시적 선택이 됐으므로 더 이상 숨은 가정은 아니지만, 그 결과 이 단계는 **자기 효과를 반증할 수 없는 상태로 ship 된다** — OQ9

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S0** 🗣 최초 요청 (Round 0, `/spec-distill:interview` 인자 전문):
  > 이 진행은 새로운 워크트리를 생성하여 거기서 하자
  > - spec-distill 파이프라인의 가장 앞에 Phase 0 `request-framing`을 도입해줘. 여기서 만드는거는 프롬프트이다. 이번 페이즈 산출물이 공간을 닫는건 지양해야함(예시: OQ를 만드는거도 공간을 닫는거다 이 페이즈의 산출물은 프롬프트이다). codex도 메타프롬프트를 도출하는 과정에 활용되게 구현하자.
  >   이 단계의 목적은 바로 요구사항 인터뷰를 시작하는 것이 아니라, 사용자의 날것의 요청과 실제 의도를 정렬하고 실행 대상에 최적화된 `interview-seed`를 만들어 새로운 세션의 첫 컨텍스트로 전달하는 것이다. 기존 `/interview` 명령은 호환성을 유지하고, `interview-seed`를 입력받아 문제공간을 탐색하는 Phase 1 역할로 좁혀라.
  >   `request-framing`은 다음 흐름을 가져야 한다.
  >       1. Raw Capture
  >         - 사용자가 제공한 거친 프롬프트, 생각, 대화, 링크와 자료를 판단하거나 요약하기 전에 원형대로 보존한다.
  >         - raw dump 자체를 곧바로 실행 프롬프트로 사용하지 않는다.
  >         - 사용자 발화, 에이전트 추론, 외부 근거, 미결 질문의 출처와 확정 상태를 분리한다.
  >       2. Intent Alignment
  >         - 현재 이해와 원문 사이의 차이를 드러내고, 답에 따라 최종 프롬프트가 실질적으로 달라지는 질문을 집요하게 제기한다.
  >         - 최소한 목표, 대상 사용자·소비자, 입력 자료, 실행 환경, 권한과 승인 경계, 제약, non-goal, 성공 증거, 중지·handoff 조건을 확인한다.
  >         - 질문 수를 목표로 삼지 말고 미충족 커버리지를 종료 기준으로 사용한다.
  >         - 사용자가 모르는 사실이나 선택지를 외부 탐색으로 보완하되, 외부 사례를 사용자 요구사항으로 임의 승격하지 않는다.
  >       3. Prompt Shaping
  >         - 사용자의 표현을 단순히 문장 교정하지 말고 실제 실행 환경의 계약으로 변환한다.
  >         - 실행 대상을 감지하고 확장 가능한 profile을 적용한다. 예시는 다음과 같지만 이에 한정하지 않는다.
  >             - goal agent: 검증 가능한 최종 상태, 변경 금지 범위, 증거, 중지·승인 조건
  >             - coding agent: 작업 범위, 저장소 제약, 권한, 필요한 검증과 산출물
  >             - image generation: 사용 목적, 피사체, 구도, 스타일, 조명, 시점, 규격과 참조 이미지
  >             - research agent: 조사 질문, 범위, 출처 기준, 최신성, 상충 근거 처리, 검증과 인용 방식
  >         - profile별 로직을 파이프라인에 복제하지 말고 공통 계약과 대상별 adapter로 구성한다.
  >         - 성공 조건은 가능한 경우 기계적으로 검증하고, 그렇지 않으면 관찰 가능한 인수 시나리오나 명확한 판단 rubric으로 표현한다. 의미 없는 수치는 만들지 않는다.
  >       4. Suppression Review
  >         - 정제 과정에서 추가·삭제·변경된 내용을 사용자에게 보여준다.
  >         - 특히 근거 없이 추가된 제약, 예시를 필수사항으로 오인한 부분, 선택지를 조기에 닫는 표현, 사용자 결정처럼 표현된 에이전트 추론을 별도로 표시한다.
  >         - 사용자가 승인하기 전에는 이를 확정된 프롬프트로 만들지 않는다.
  >       5. Session Handoff
  >         - 승인된 결과를 독립적으로 이해 가능한 `interview-seed`로 만든다.
  >         - 새로운 세션에는 전체 대화 로그가 아니라 compact한 실행 프롬프트와 원본 artifact 경로를 주입한다.
  >         - confirmed 항목만 제약으로 취급하고, inferred·external·open 항목은 검증하거나 재질문할 수 있다고 명시한다.
  >         - 새 세션은 이 seed를 입력으로 `spec-distill:interview`를 시작한다.
  >   기존 interview의 R1 `Reframe (메타 프롬프트)`는 `Problem Reframe`으로 재정의해 Phase 0와 중복되지 않게 해라. Phase 0의 외부 탐색은 프롬프트 구성에 필요한 컨텍스트 공백을, interview의 landscape 탐색은 실제 문제·도메인의 대안과 prior art를 담당하도록 경계를 나눠라.
  >   `meta-prompting`은 내부 메커니즘 명칭으로만 사용하고, 사용자-facing 단계명은 결과를 설명하는 `request-framing`, 산출물명은 `interview-seed`로 사용해라. 이미 충분히 정제된 입력은 Phase 0를 짧게 통과할 수 있지만, 확정되지 않은 핵심 가정이 남아 있는데 자동으로 interview로 넘어가서는 안 된다.
  >     - 추천 구분
  >        단계               핵심 질문                                            산출물
  >        request-framing    다음 에이전트에게 정확히 어떤 작업을 맡길 것인가?    interview-seed
  >        interview          실제로 해결해야 할 문제와 방향은 무엇인가?           interview-brief
  >        brainstorming      어떤 해법을 선택할 것인가?                           design

- **S1** ☑ 선택 (seed 소비자 범위):
  > ③ 단일 소비자 + 중립 포맷 — 지금 seed를 받는 것은 spec-distill:interview 하나. 단 seed 스키마는 소비자 중립(target 일반 필드)으로 설계해 나중에 다른 실행 에이전트를 붙일 확장점만 남긴다. image-gen 어댑터는 구현하지 않음.
- **S2** ☑ 선택 ('공간을 닫는다'의 금지 경계):
  > ① 작업-기술 필드만 허용 — 맡길 작업을 기술하는 필드(범위·저장소 제약·권한·필요한 증거·중지/승인 조건)는 허용. 다음 단계의 답이 들어갈 슬롯(Open Questions, 대안 목록, AC 초안, 기각 목록)은 금지. 미확정 재료는 항목 라벨 open 으로만 표시하고 별도 섹션으로 모으지 않는다.
- **S3** ☑ 선택 (codex 의 역할):
  > ① 비평자 — Claude 가 seed 초안을 만들고 codex 가 독립적으로 Suppression Review 를 수행한다(근거 없는 제약 추가 / 예시를 필수로 오인 / 선택지 조기 닫힘 표현 / 사용자 결정처럼 표현된 에이전트 추론). 기존 findings 스키마 재사용.
- **S4** ☑ 선택 (진입 표면):
  > ③ 별도 command + 조언 — /request-framing 을 정식 진입점으로 신설. /interview 는 기존대로 거친 요청도 받아 동작하되, 입력이 seed 가 아니면 framing 을 먼저 하라는 한 줄 조언만 띄운다. 차단 아님.
- **S5** ☑ 선택 (세션 핸드오프):
  > ③ 두 경로 모두 제시 — Phase 0 종료 게이트가 4옵션을 띄운다: 새 세션에서 시작(seed 경로+명령문 노출 후 턴 종료) / /compact 후 이어서 / 수정 / 멈춤. 기존 proceed-gate 와 같은 모양.
- **S6** ☑ 선택 (R3 steelman 게이트 판정):
  > ① 방어 — 원안 유지. 새 단계를 만든다. steelman 의 핵심 사실 주장(원형 보존이 이미 구현됨)이 검증에서 과장으로 드러났고 Raw Capture 는 실재 갭. blind-spot 8건은 반박이 아니라 설계 제약으로 흡수한다.
- **S7** 🗣 발화 (성공 oracle — 제시된 선택지 밖에서 자유 서술):
  > 만들어 내는 거는 프롬프트이며 이거는 자명한 사실이나 세세한 내용이 아닐거니 그렇게 길지 않고 명확한 내용일거야 이정도면 사용자가 보고 바로 리뷰가 가능하고 다음 interview에서 받은 이 프롬프트는 사용자의 결정인거지
- **S8** ☑ 선택 (제시되지 않은 선택지 처리):
  > ① 제시한 선택지 전부 audit 에 기록 — 고른 것만이 아니라 그 라운드에 제시한 옵션 집합 전체를 남긴다. 사후 검토가 가능해지고 codex 비평자에게도 볼 코퍼스가 생겨 '선택지 조기 닫힘' 불가시 축이 부분적으로 열린다. audit 은 payload 가 아니므로 seed 의 짧고 명확 요구와 충돌하지 않는다.

- **S9** ☑ 선택 (D4 — `/interview` 좁히기 지시 처리):
  > 좁히기 지시를 명시적으로 기각 기록 — /interview 는 지금 그대로 둔다. 단 원문이 'Phase 1 역할로 좁혀라'고 했으나 호환성을 위해 기각했다는 사실을 §5 기각 항목으로 명시해 지시가 조용히 증발하지 않게 한다.
- **S10** 🗣 발화 (D5 — Suppression Review 비평자):
  > 1번 8-31까지 못도는거고 구현을 스킵하진 말아줘
- **S13** ☑ 선택 (D5 — S10 의 "1번"이 가리키는 옵션 본문. 충실도 리뷰 지적으로 추가 기록):
  > ① 역할 슬롯으로 — 격리 Claude agent 기본 + codex 업그레이드. 비평자를 '누가'가 아니라 '어떤 역할'로 정의. 항상 가용한 격리 agent(brief-critic 형태, tools: [])를 기본 구현으로 두고 codex 는 모델 다양성 업그레이드로. 지금 돌리고 나중에 강해진다.
- **S11** ☑ 선택 (D6 — seed 저장 위치):
  > docs/ 아티팩트로 — seed 를 brief 와 같은 자리(docs/superpowers/ 아래 git 추적 파일)에 둔다. 세션 스코프 자동 삭제 영역 밖. 대가로 seed 가 git 이력에 남는 것을 받아들인다.
- **S12** ☑ 선택 (D8 — 성공 오라클):
  > 오라클 없이 진행한다는 것을 명시한다 — §1 Non-goal 에 '이 단계의 효과를 측정하지 않는다'를 명시적으로 적는다. 측정 없음을 숨기지 않고 선택으로 드러낸다.

## 7. Next Action

이 brief를 context로 `superpowers:brainstorming` 호출 → `-design.md` → `spec-distill:reviewing-spec` 검증 → `superpowers:writing-plans`.

작업 위치: 워크트리 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+request-framing-phase0` (branch `worktree-feature+request-framing-phase0`, base `ead6835`). 테스트 baseline = 61 pass / 1 fail(`test_hook_output_schema` cross-resolver, 워크트리 전용·선재).
