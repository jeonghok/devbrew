---
name: document-review-redesign
type: interview-brief
created_at: 2026-09-06
session_id: b19db3df-cae2-4390-a610-ca3641e03595
source: spec-distill conducting-interview v0.53.1
next_phase: superpowers:brainstorming
audit_file: 2026-09-06-document-review-redesign-interview.audit.md
user_sourced_items:
  - id: C1
    source: verbatim
    status: confirmed
    statement: "리뷰어는 근본적 해결을 제안하되 혼자 결정하지 않는다"
    evidence: S1
  - id: C2
    source: verbatim
    status: confirmed
    statement: "목표·범위·제약·Non-goal·아키텍처·trade-off·Acceptance Criteria 가 바뀌거나 새 요구가 추가되는 수정은 변경 내용과 근거·대안·영향을 보고하고 사용자가 결정한 뒤에 한다"
    evidence: S1
  - id: C3
    source: verbatim
    status: confirmed
    statement: "큰 그림 관점에서 방향이 틀렸다는 발견은 저자가 고치지 않고 사용자에게 바로 올라가며, 모델이 임의로 정한 것과 리뷰어 사이에 합의되지 않은 방향도 같은 길로 라운드마다 올리고, 상세 불일치는 둘 다 유지하며, 모델끼리 억지로 합의시키지 않는다"
    evidence: S1
  - id: C4
    source: verbatim
    status: confirmed
    statement: "무엇을 바로 고치고 무엇을 올릴지는 리뷰어의 표시와 수정하는 세션의 판단을 둘 다 쓰고, 하나라도 올리라 하면 올린다"
    evidence: S1
  - id: C5
    source: verbatim
    status: confirmed
    statement: "막아야 할 회귀는 수정이 새 결함을 만드는 것이다"
    evidence: S1
  - id: C6
    source: verbatim
    status: confirmed
    statement: "결정 게이트는 산문과 구조 둘 다 쓰되 너무 무거운 하니스는 지양한다"
    evidence: S1
  - id: C7
    source: verbatim
    status: confirmed
    statement: "seed 시점의 확정 — 그대로 두는 것은 재리뷰 상한 5회, codex 병렬 co-review, 문서 발견용 Stop 훅, /compact proceed 게이트이고, superpowers brainstorming 의 자체 self-review 단계는 범위 밖이다. 이 중 재리뷰 상한 5회는 S12 로 뒤집혔다(D17)"
    evidence: S1
  - id: C8
    source: verbatim
    status: confirmed
    statement: "라운드마다 자동 커밋하는 자율 루프를 포함해 기존 구현의 어느 모양에도 끌려가지 않고 가장 적합한 형태로 완전히 새로 만들며, 공통은 shared 로 통합하고 특화 지점에서는 반드시 분화한다"
    evidence: S1
  - id: C9
    source: verbatim
    status: confirmed
    statement: "레포 안에서 참고할 선례는 brief 의 방향 리뷰어와 quality-gates 의 critique 리뷰어 쌍이다 — 참고하되 끌려가지 않는다"
    evidence: S1
  - id: C10
    source: verbatim
    status: confirmed
    statement: "두 층의 내용 — 먼저 사용자 목표와 문제 정의, 전체 범위, 핵심 아키텍처, 컴포넌트 관계와 데이터 흐름, 주요 trade-off, 구현 가능성 등이 하나의 그림으로 정합한지, 그다음 누락·모호성·Acceptance Criteria·검증·handoff 등 상세 완결성. 세부 항목이 완전해도 전체 방향이 잘못됐으면 승인하지 않는다"
    evidence: S1
  - id: D1
    source: chosen
    status: confirmed
    statement: "근본 원인은 리뷰 산출물이 verdict 라 finding 에 수신자가 없어 전부 저자 수정 한 갈래로 흐르는 것이다"
    evidence: S2
  - id: D2
    source: chosen
    status: confirmed
    statement: "탐지 리뷰어 하나가 finding 마다 처분을 붙이고 오케스트레이터가 라우팅하며, 두 층은 리뷰어 persona 의 검토·출력 순서로 둔다"
    evidence: S3
  - id: D3
    source: chosen
    status: confirmed
    statement: "처분은 decide / fix / defer / ask / drop 다섯 값이고, 어휘는 공통이며 자리별로 낼 수 있는 값을 제한한다"
    evidence: S4
  - id: D4
    source: chosen
    status: confirmed
    statement: "현행은 D12 이며 이 항목은 라운드 4 시점의 선택 기록이다 — fix 는 앵커 섹션 안에서만 고치고, finding 이 없던 섹션은 얼리며, 얼린 섹션의 변경은 헤딩 단위 diff 로 자동 decide finding 이 된다. 결정론은 헤딩 diff 한 곳이다. 얼림 키와 결정론 수는 S11 로 넓혀졌다(D12)"
    evidence: S5
  - id: D5
    source: chosen
    status: confirmed
    statement: "리뷰 엔진은 하나이고 프로필은 design doc · brief · seed · generic doc 넷이며, doc 은 /qg critique 의 generic 프로필이고 seed 자리는 범위 안이되 배선은 마지막이다"
    evidence: S6
  - id: D6
    source: chosen
    status: confirmed
    statement: "스펙은 검증 가능성까지, plan 은 검증 절차부터 소유하며, 스펙 안의 plan 소유물은 defer 로 옮긴다"
    evidence: S7
  - id: D18
    source: chosen
    status: confirmed
    statement: "testing 카테고리는 폐기가 아니라 검증 전략 부재로 재정의하고 절차·명령만 defer 로 보낸다. Law 1 필수 섹션 목록은 그대로다"
    evidence: S11
  - id: D7
    source: chosen
    status: confirmed
    statement: "오케스트레이터는 올리기만 한다 — 처분 상향과 finding 추가만 가능하고 하향·삭제는 불가하며, codex 와 갈리면 높은 쪽을 취하고 codex 부재는 게이트 첫 줄에 공시한다"
    evidence: S8
  - id: D8
    source: chosen
    status: confirmed
    statement: "decide 는 결정 단위로 묶어 라운드마다 올리고, ask 와 defer 는 승인 게이트에서 한 번 보인다"
    evidence: S9
  - id: D9
    source: chosen
    status: confirmed
    statement: "Open Questions 는 일곱 개로 박제하고 skepticism 은 ST1 로 마감한다"
    evidence: S10
  - id: D10
    source: chosen
    status: confirmed
    statement: "현행은 09-02 C3 이다 — 오케스트레이터는 결과 수신·처분·라우팅을 맡고, 탐지와 재비판은 프레이밍을 못 보는 독립 critic 이 하며, 재비판 subagent 는 유지한다. 오탐의 기각은 그 독립 재비판자가 근거를 인용해 reject 하고 회계에 계수된다. 08-27 의 M2·M4 는 뒤집힌 결정이다"
    evidence: S11
  - id: D11
    source: chosen
    status: confirmed
    statement: "처분 다섯 값에는 전순서가 있다 — decide > ask > fix > defer > drop. 수신자가 사람에 가까울수록, 승인을 막을수록 높다"
    evidence: S11
  - id: D12
    source: chosen
    status: confirmed
    statement: "S5 의 「결정론은 한 곳」을 둘로 넓힌 재결정이다 — 얼림의 키는 이번 라운드에 finding 이 없던 섹션과 C2 의 보호 부류(목표·범위·제약·Non-goal·아키텍처·trade-off·AC)의 합집합이고, 보호 부류는 finding 이 있어도 항상 decide 다"
    evidence: S11
  - id: D13
    source: chosen
    status: confirmed
    statement: "finding 은 편집 범위를 선언한다(기본값은 자기 앵커 섹션, 새 섹션이 필요하면 삽입 위치). 헤딩 diff 의 기준선은 세션 state 의 라운드 스냅샷과 해시이며 git 커밋이 아니다"
    evidence: S11
  - id: D14
    source: chosen
    status: confirmed
    statement: "fix 는 적용 전 제안 단계를 거친다 — 저자가 finding 별 패치 의도(무엇을·어디를)를 먼저 내고 앵커·보호 부류 판정을 통과한 뒤 적용한다"
    evidence: S11
  - id: D15
    source: chosen
    status: confirmed
    statement: "brief·seed 프로필도 fix 를 낼 수 있되 앵커를 §0·§2 로 묶고 §6 은 불변이며, decide 는 원문 자체가 모호할 때로 좁힌다"
    evidence: S11
  - id: D16
    source: chosen
    status: confirmed
    statement: "ask 중 답이 fix 의 전제인 것은 그 라운드의 결정 묶음에 비차단 질문으로 함께 올리고, 나머지 ask 와 defer 만 승인 게이트에 모은다"
    evidence: S11
  - id: D17
    source: verbatim
    status: confirmed
    statement: "리뷰 한도는 2번으로 통일한다 — 수정 후 재리뷰 상한을 모든 문서 리뷰 자리에서 2회로 맞춘다(총 리뷰 횟수가 아니라 재리뷰 횟수라는 것을 S14 에서 사용자가 확인)"
    evidence: S12
  - id: D19
    source: verbatim
    status: confirmed
    statement: "반드시 필요한 경우에는 상한을 넘는 추가 라운드를 제안할 수 있다 — 제안이지 자동 연장이 아니며 여는 것은 사용자다"
    evidence: S13
---

# 문서 리뷰 재설계 — Interview Brief

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 brainstorming 해답공간으로
> 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다. 텔레메트리는 `audit_file`에 있다.

## 0. 한눈에

**무엇** — devbrew 에서 문서를 리뷰하는 자리 넷(brainstorming design doc 을 보는 `reviewing-spec`/`spec-reviewer`, 인터뷰 brief 를 보는 `reviewing-brief` 와 그 리뷰어 셋, `/qg critique` 의 비-코드 산출물 리뷰, Phase 0 의 seed 리뷰)을 「문서 리뷰」 하나의 관점으로 근본부터 새로 짓는다. 기존 구현의 모양에 끌려가지 않는다.

**왜** — 지금 네 자리는 전부 「결함 탐지기 + 수정 루프」이고 산출물이 verdict(approved / needs_revise)다. finding 에 수신자가 없어 방향 결함도 상세 결함도 plan 이 정할 것도 전부 「저자가 고쳐서 재리뷰」 한 갈래로 흐르고, 그 즉흥 수정이 새 결함을 만든다. 스펙 리뷰가 request framing → interview → brainstorming → writing-plans → 구현의 큰 그림에서 자기 역할(스펙의 역할)에 맞지 않게 plan 의 일까지 요구해 왔다.

**확정(S14 에서 사용자 일괄 확인)** — 리뷰의 산출물은 verdict 가 아니라 **수신자가 붙은 finding 목록**이다. 탐지 리뷰어는 하나, finding 마다 처분 다섯 값(`decide` 사용자 결정 / `fix` 저자 수정 / `defer` plan 이월 / `ask` 묻기만 / `drop`, 전순서 `decide` > `ask` > `fix` > `defer` > `drop`) 중 하나를 붙이고, 프레이밍을 못 보는 독립 재비판자가 오탐을 근거 인용으로 기각하며, 오케스트레이터는 수신·처분·라우팅만 한다(9월 2일 C3 — 탐지만 옮기고 처분은 그대로). ✎ 「`decide` 가 하나라도 열려 있으면 승인이 도출되지 않는다」는 S1 의 「세부가 완전해도 방향이 틀리면 승인하지 않는다」에서 이 세션이 도출한 규칙이다(사용자 발화가 아니다). 두 층(큰 그림 정합 → 상세 완결)은 별개 리뷰어가 아니라 리뷰어 persona 의 검토·출력 순서다. 회귀 장치는 「fix 는 finding 이 선언한 편집 범위 안에서만 + 적용 전 패치 의도 제안 + 이번 라운드 finding 없던 섹션과 C2 보호 부류는 얼림 + 얼린 곳의 변경은 헤딩 diff 로 자동 decide」이고, 결정론은 헤딩 diff 와 보호 섹션 목록 둘이며 기준선은 세션 state 의 스냅샷이다. 엔진 하나에 프로필 넷(design doc · brief · seed · generic doc). 스펙은 검증 가능성까지, plan 은 검증 절차부터(`testing` 은 폐기가 아니라 검증 전략 부재로 재정의). 오케스트레이터는 처분을 올리기만 한다. `decide` 는 결정 단위로 묶어 라운드마다, `fix` 의 전제인 `ask` 는 그 묶음에 비차단으로, 나머지 `ask`·`defer` 는 승인 게이트에서 한 번. 재리뷰 상한은 네 자리 모두 2회로 통일하고, 반드시 필요한 경우에만 추가 라운드를 사용자에게 제안할 수 있다(S12·S13 — seed 의 「5회 유지」를 사용자가 뒤집음).

✎ 용어 — M1~M4 는 2026-08-27 판정 지형 핸드오프가 적은 사용자 방향 넷(M1 수신처를 오케스트레이터로 통일 · M2 오케스트레이터가 항상 1차 재비판 · M3 사람은 자명하지 않은 결정만 · M4 재비판 subagent 가능하면 제거)이고, 09-02 C3 은 그 뒤 인터뷰에서 사용자가 M2·M4 를 뒤집은 확정이다. T1·T2 는 그 핸드오프의 긴장 항목(T1 오케스트레이터의 전제 오염, T2 codex 부재 시 독립 판정 0). ST1 은 이 인터뷰의 steelman 판정 1번(두 층을 별개 리뷰어로 나누는 원안 → 전환). 「회계」는 `shared/adjudication` 의 처분 원장(버린 finding 을 세고 공시하는 모듈). 「배선」은 dispatch 연결(엔진을 그 자리에서 실제로 부르게 하는 것)이다.

**열려 있음** — shared 의 물리 배치, 한 리뷰어 안의 두 층이 서로를 오염하는 후광의 대응, 기존 락 이관 순서, seed 자리의 원장 계약, 결정 기록의 저장 위치, 헤딩 없는 문서의 앵커, codex 처분 어휘 계약(§3).

**다음 stage** — `superpowers:brainstorming` (architectural path). 인접 확정은 판정 지형 사이클의 9월 2일 C3(M1·M3 유지, M2·M4 반전, 축은 「프레이밍을 보느냐」)이며, 그 사이클이 이번으로 미룬 「비판자 역할 구조 통일」이 이 설계의 일부다. 그 인터뷰의 OQ11~OQ19 는 brainstorming 이 함께 읽는다.

## 1. Goal · Non-goal

- Goal: 네 문서 리뷰 자리가 같은 엔진(처분 어휘·라우팅·앵커 묶기/얼림·finding 정체성·codex co-review·degrade 공시)을 쓰고 프로필(정답의 출처·허용 처분값·검토 순서·handoff 목적지)만 다르게 갖는 설계. 방향 실패는 라운드마다 사용자에게, 상세 결함은 저자에게, plan 의 일은 plan 으로 간다.
- Goal: 수정이 새 결함을 만드는 회귀를 「리뷰어의 눈」에만 맡기지 않고 수정 범위 자체로 막는다.
- Goal: 하니스는 가볍게 — 판정·차단하는 결정론은 헤딩 단위 diff 와 보호 섹션 목록 둘뿐이고, 나머지는 산문(persona · skill)과 사용자 결정이다.
- Non-goal: superpowers brainstorming 의 자체 self-review 단계 수정. superpowers 는 건드리지 않는다.
- Non-goal: codex 병렬 co-review · 문서 발견용 Stop 훅 · `/compact` proceed 게이트를 바꾸는 것. 셋은 그대로 둔다. 재리뷰 상한은 seed 의 「5회 유지」에서 「2회로 통일」로 사용자가 바꿨다(D17) — 그대로 두는 목록에서 빠진다.
- Non-goal: 08-27 핸드오프의 M2·M4(오케스트레이터 1차 재비판 · 재비판 subagent 제거)를 현행으로 되살리는 것. 이 설계의 현행 기준은 9월 2일 C3(M1·M3 유지, M2·M4 반전)이며, 그 기준 자체도 §7 의 규약대로 근거가 있으면 보고 후 재결정할 수 있다.
- Non-goal: CLAUDE.md Law 1 의 필수 섹션 목록 개정.
- Non-goal: 코드 리뷰(`/qg` Review 게이트) 의 변경.

## 2. 제약

(이 절의 진술은 모델이 쓴 요약이다. 원문은 payload §6(S1)과 audit §6(S2 이상)에 나뉘어
 있고, `⟨S<N>⟩`가 그중 하나를 가리킨다.)

- 🗣 confirmed **C1** — 리뷰어는 근본적 해결을 제안하되 혼자 결정하지 않는다 ⟨S1⟩
- 🗣 confirmed **C2** — 목표·범위·제약·Non-goal·아키텍처·trade-off·Acceptance Criteria 가 바뀌거나 새 요구가 추가되는 수정은 변경 내용과 근거·대안·영향을 보고하고 사용자가 결정한 뒤에 한다 ⟨S1⟩
- 🗣 confirmed **C3** — 큰 그림 관점에서 방향이 틀렸다는 발견은 저자가 고치지 않고 사용자에게 바로 올라가며, 모델이 임의로 정한 것과 리뷰어 사이에 합의되지 않은 방향도 같은 길로 라운드마다 올리고, 상세 불일치는 둘 다 유지하며, 모델끼리 억지로 합의시키지 않는다 ⟨S1⟩
- 🗣 confirmed **C4** — 무엇을 바로 고치고 무엇을 올릴지는 리뷰어의 표시와 수정하는 세션의 판단을 둘 다 쓰고, 하나라도 올리라 하면 올린다 ⟨S1⟩
- 🗣 confirmed **C5** — 막아야 할 회귀는 수정이 새 결함을 만드는 것이다 ⟨S1⟩
- 🗣 confirmed **C6** — 결정 게이트는 산문과 구조 둘 다 쓰되 너무 무거운 하니스는 지양한다 ⟨S1⟩
- 🗣 confirmed **C7** — seed 시점의 확정 — 그대로 두는 것은 재리뷰 상한 5회, codex 병렬 co-review, 문서 발견용 Stop 훅, /compact proceed 게이트이고, superpowers brainstorming 의 자체 self-review 단계는 범위 밖이다. 이 중 재리뷰 상한 5회는 S12 로 뒤집혔다(D17) ⟨S1⟩
- 🗣 confirmed **C8** — 라운드마다 자동 커밋하는 자율 루프를 포함해 기존 구현의 어느 모양에도 끌려가지 않고 가장 적합한 형태로 완전히 새로 만들며, 공통은 shared 로 통합하고 특화 지점에서는 반드시 분화한다 ⟨S1⟩
- 🗣 confirmed **C9** — 레포 안에서 참고할 선례는 brief 의 방향 리뷰어와 quality-gates 의 critique 리뷰어 쌍이다 — 참고하되 끌려가지 않는다 ⟨S1⟩
- 🗣 confirmed **C10** — 두 층의 내용 — 먼저 사용자 목표와 문제 정의, 전체 범위, 핵심 아키텍처, 컴포넌트 관계와 데이터 흐름, 주요 trade-off, 구현 가능성 등이 하나의 그림으로 정합한지, 그다음 누락·모호성·Acceptance Criteria·검증·handoff 등 상세 완결성. 세부 항목이 완전해도 전체 방향이 잘못됐으면 승인하지 않는다 ⟨S1⟩
- ☑ confirmed **D1** — 근본 원인은 리뷰 산출물이 verdict 라 finding 에 수신자가 없어 전부 저자 수정 한 갈래로 흐르는 것이다 ⟨S2⟩
- ☑ confirmed **D2** — 탐지 리뷰어 하나가 finding 마다 처분을 붙이고 오케스트레이터가 라우팅하며, 두 층은 리뷰어 persona 의 검토·출력 순서로 둔다 ⟨S3⟩
- ☑ confirmed **D3** — 처분은 decide / fix / defer / ask / drop 다섯 값이고, 어휘는 공통이며 자리별로 낼 수 있는 값을 제한한다 ⟨S4⟩
- ☑ confirmed **D4** — 현행은 D12 이며 이 항목은 라운드 4 시점의 선택 기록이다 — fix 는 앵커 섹션 안에서만 고치고, finding 이 없던 섹션은 얼리며, 얼린 섹션의 변경은 헤딩 단위 diff 로 자동 decide finding 이 된다. 결정론은 헤딩 diff 한 곳이다. 얼림 키와 결정론 수는 S11 로 넓혀졌다(D12) ⟨S5⟩
- ☑ confirmed **D5** — 리뷰 엔진은 하나이고 프로필은 design doc · brief · seed · generic doc 넷이며, doc 은 /qg critique 의 generic 프로필이고 seed 자리는 범위 안이되 배선은 마지막이다 ⟨S6⟩
- ☑ confirmed **D6** — 스펙은 검증 가능성까지, plan 은 검증 절차부터 소유하며, 스펙 안의 plan 소유물은 defer 로 옮긴다 ⟨S7⟩
- ☑ confirmed **D18** — testing 카테고리는 폐기가 아니라 검증 전략 부재로 재정의하고 절차·명령만 defer 로 보낸다. Law 1 필수 섹션 목록은 그대로다 ⟨S11⟩
- ☑ confirmed **D7** — 오케스트레이터는 올리기만 한다 — 처분 상향과 finding 추가만 가능하고 하향·삭제는 불가하며, codex 와 갈리면 높은 쪽을 취하고 codex 부재는 게이트 첫 줄에 공시한다 ⟨S8⟩
- ☑ confirmed **D8** — decide 는 결정 단위로 묶어 라운드마다 올리고, ask 와 defer 는 승인 게이트에서 한 번 보인다 ⟨S9⟩
- ☑ confirmed **D9** — Open Questions 는 일곱 개로 박제하고 skepticism 은 ST1 로 마감한다 ⟨S10⟩
- ☑ confirmed **D10** — 현행은 09-02 C3 이다 — 오케스트레이터는 결과 수신·처분·라우팅을 맡고, 탐지와 재비판은 프레이밍을 못 보는 독립 critic 이 하며, 재비판 subagent 는 유지한다. 오탐의 기각은 그 독립 재비판자가 근거를 인용해 reject 하고 회계에 계수된다. 08-27 의 M2·M4 는 뒤집힌 결정이다 ⟨S11⟩
- ☑ confirmed **D11** — 처분 다섯 값에는 전순서가 있다 — decide > ask > fix > defer > drop. 수신자가 사람에 가까울수록, 승인을 막을수록 높다 ⟨S11⟩
- ☑ confirmed **D12** — S5 의 「결정론은 한 곳」을 둘로 넓힌 재결정이다 — 얼림의 키는 이번 라운드에 finding 이 없던 섹션과 C2 의 보호 부류(목표·범위·제약·Non-goal·아키텍처·trade-off·AC)의 합집합이고, 보호 부류는 finding 이 있어도 항상 decide 다 ⟨S11⟩
- ☑ confirmed **D13** — finding 은 편집 범위를 선언한다(기본값은 자기 앵커 섹션, 새 섹션이 필요하면 삽입 위치). 헤딩 diff 의 기준선은 세션 state 의 라운드 스냅샷과 해시이며 git 커밋이 아니다 ⟨S11⟩
- ☑ confirmed **D14** — fix 는 적용 전 제안 단계를 거친다 — 저자가 finding 별 패치 의도(무엇을·어디를)를 먼저 내고 앵커·보호 부류 판정을 통과한 뒤 적용한다 ⟨S11⟩
- ☑ confirmed **D15** — brief·seed 프로필도 fix 를 낼 수 있되 앵커를 §0·§2 로 묶고 §6 은 불변이며, decide 는 원문 자체가 모호할 때로 좁힌다 ⟨S11⟩
- ☑ confirmed **D16** — ask 중 답이 fix 의 전제인 것은 그 라운드의 결정 묶음에 비차단 질문으로 함께 올리고, 나머지 ask 와 defer 만 승인 게이트에 모은다 ⟨S11⟩
- 🗣 confirmed **D17** — 리뷰 한도는 2번으로 통일한다 — 수정 후 재리뷰 상한을 모든 문서 리뷰 자리에서 2회로 맞춘다(총 리뷰 횟수가 아니라 재리뷰 횟수라는 것을 S14 에서 사용자가 확인) ⟨S12⟩
- 🗣 confirmed **D19** — 반드시 필요한 경우에는 상한을 넘는 추가 라운드를 제안할 수 있다 — 제안이지 자동 연장이 아니며 여는 것은 사용자다 ⟨S13⟩

✎ superpowers 의 소유 경계는 레포에서 자동 확인한 사실이다 — brainstorming 의 design doc 은 architecture · components · data flow · error handling · testing 을 다루고, writing-plans 는 파일 구조 확정 · 인터페이스 시그니처 · 태스크 분해 · 테스트 코드 · 커밋 단위를 소유하며 self-review 첫 항목이 「spec coverage」다. D6 은 이 사실 위의 결정이다.

✎ 현재 `spec-reviewer` 의 `testing` 카테고리(「자동 검증 절차 없음」 = high)가 「plan 의 일이 스펙에 섞인다」의 실체다. `Files to Modify` · `Verification Plan` 은 Law 1 필수 섹션이므로 남되, 전자는 영향 범위, 후자는 「무엇이 관측되면 통과인가」 수준이다. `defer` 의 목적지는 design doc 의 `Handoff Context › Deferred to plan` 소절이며 writing-plans 가 spec 을 읽을 때 같이 읽힌다.

✎ 「방향」은 처분값이 아니라 `decide` 가 붙는 사유 중 하나다. 모델이 임의로 정한 것과 리뷰어 사이의 방향 불일치도 `decide` 로 온다. 상세 불일치는 두 finding 이 모두 남는다 — 오케스트레이터가 접을 권한이 없기 때문이다(D7).

✎ 처분은 탐지 리뷰어 표시 + 수정 세션 판단(C4) + 오케스트레이터(D7) 세 손을 거치는데 셋 다 올리기만 한다. 내리는 손은 사용자(`decide` 에서)와 **프레이밍을 못 보는 독립 재비판자**(근거 인용 `reject`, 회계 계수 — D10)뿐이다. 오케스트레이터는 dispatch 를 자기가 쓴 주체라 재비판자가 될 수 없다는 것이 9월 2일 C3 의 근거다.

✎ 프로필이 허용 처분값을 제한하는 이유는 자리마다 「정답의 출처」가 다르기 때문이다. 충실도·냉독 자리(brief, seed)는 정답이 사용자 원문(§6)이라 §6 은 불변이고 `fix` 의 앵커는 §0·§2 로 묶이며 `decide` 는 원문 자체가 모호할 때만 낸다(D15). design doc 자리는 다섯 전부를 낸다.

✎ D6·D10~D16 의 근거 S11 은 「전부 추천대로」 한 마디다 — 사용자가 직접 말한 진술이 아니라, 방향성 리뷰 finding 마다 이 세션이 제시한 선택지(A~K)와 추천을 **일괄 채택**한 것이다. 그래서 이 항목들은 ☑ chosen 이다. 채택된 선택지의 문구를 아래에 제시 당시 그대로 옮긴다(§6 은 사용자 발화만 담으므로 여기 둔다 — 모델이 쓴 선택지 문구이지 사용자 원문이 아니다):

✎ 채택된 선택지 원문(S11 이 가리키는 것) —
- A1: 09-02 C3 이 현행(오케스트레이터=수신·처분·라우팅, 탐지와 재비판은 프레이밍을 못 보는 독립 critic, 재비판 subagent 유지)
- B2: 독립 재비판자가 근거 인용으로 `reject`(회계에 계수, 현행 adversarial 방식). 라운드 7 의 「하향 불가」는 오케스트레이터에게만 남기고, 독립 critic 의 근거 있는 `reject` 는 허용
- C1: 다섯 값에 전순서를 명시(`decide` > `ask` > `fix` > `defer` > `drop`). 순서의 뜻은 「수신자가 사람에 가까울수록, 승인을 막을수록 높다」
- D3: 둘의 합집합 — finding 없음(현행) ∪ C2 보호 부류(목표·범위·제약·Non-goal·아키텍처·trade-off·AC)는 finding 이 있어도 항상 `decide`. 결정론은 「헤딩 diff + 보호 섹션 목록」 둘이 된다
- E2: finding 이 편집 범위를 선언(기본값=자기 앵커 섹션, 필요하면 `insert-after`)
- F1: 세션 state 의 라운드 스냅샷 + 해시(원장식 LKG). §5 문장은 「자율 커밋 루프 기각, LKG 핀 채택」으로 고친다
- G1: 적용 전 제안 — 저자가 finding 별 패치 의도(무엇을·어디를)를 먼저 내고 앵커·보호 부류 판정 뒤 적용
- H2: `testing` 을 「검증 전략 부재」(무엇이 관측되면 통과인가)로 재정의하고 절차·명령만 `defer`, Law 1 목록은 그대로(Files to Modify=영향 범위, Verification Plan=관측 기준)
- I2: `fix` 허용하되 앵커를 §0/§2 로 묶고 §6 은 불변, `decide` 는 원문 자체가 모호할 때만
- J1: 공시만, 단 A1 전제. 09-02 OQ13(1명 vs 병렬 N명)은 답하지 않고 이 brief 의 OQ 로 이월
- K1: `ask` 중 답이 `fix` 의 전제인 것은 그 라운드의 결정 묶음에 비차단 질문으로 함께 올리고, 나머지만 게이트에 모음

✎ 라운드 4 에서 S5 가 고른 선택지 ③ 의 제시 당시 문구 — 「앵커 묶기 + 얼림 + 얼린 섹션 변경은 자동 `decide`」: 모든 finding 은 `target_anchor` 를 갖고 `fix` 의 수정은 그 앵커 섹션 안에서만; 라운드 n 에서 finding 이 없었던 섹션은 얼린 것으로 보고, 라운드 n+1 진입 시 헤딩 단위 diff 로 얼린 섹션이 바뀌었으면 자동으로 `decide` finding; 정체성은 리뷰어의 `supersedes:` 지목 + 오케스트레이터 대조; 결정론은 「헤딩 단위 diff → decide finding 생성」 하나뿐. D4 의 「finding 이 없던 섹션은 얼리며」는 이 문구에서 왔다.

✎ C7 의 「재리뷰 상한 5회 그대로」는 S12 로 뒤집혔다 — 지금 자리마다 다른 상한(design doc 5 · brief 2 · `/qg critique` 5)을 2 로 통일한다. C7 의 나머지 셋(codex co-review · Stop 훅 · `/compact` 게이트)은 그대로다. 상한 도달 후의 추가 라운드는 「반드시 필요한 경우」에 한해 **제안**만 할 수 있고(S13) 여는 것은 사용자다 — C1(혼자 결정하지 않는다)의 적용이며, 자동 연장 경로는 두지 않는다(Unbounded autonomy 금지). 상한 2 는 안전망이지 회귀 장치가 아니라는 점(D4·D12)은 변하지 않는다 — 상한 도달 시 사용자에게 보이는 것은 열린 결정 목록과 마지막 라운드의 새 결함이다(D8).

✎ 인접 확정의 현행은 판정 지형 **인터뷰**(2026-09-02)의 C3 이다: M1(수신처 오케스트레이터)·M3(사람은 자명하지 않은 결정만)은 유지, M2(오케스트레이터 1차 재비판)·M4(재비판 subagent 제거)는 **뒤집힘**, 축은 「프레이밍을 보느냐」. 그 사이클(#138)은 역할 재배치를 OQ11~OQ19 미해소를 이유로 이번 사이클로 미뤘다. 이 brief 의 첫 판본은 08-27 핸드오프의 M2·M4 를 현행으로 읽고 D7 을 세웠고, 방향성 리뷰가 그것을 잡아 D10 으로 재결정했다.

## 3. Open Questions

(OQ1~OQ7 은 S10 에서 사용자가 「일곱 개」로 박제한 것이다. OQ8 은 채택된 선택지 J1 이 명시한 이월이고, OQ9·OQ10 은 ✎ 이 세션이 방향성 리뷰 finding(D1 의 09-02 OQ11~OQ19 인용, D4 의 보호 부류 식별)에서 도출해 더한 미결이다 — 사용자 발화가 더한 것이 아니므로 brainstorming 은 이 둘을 사용자에게 다시 물을 수 있다.)

- OQ1: shared 의 물리 배치 — 새 플러그인 / spec-distill 이 호스팅하고 quality-gates 가 cross-plugin 으로 dispatch / 스크립트 링크 복제. 설치본에서 다른 플러그인의 스크립트는 도달 불가라는 제약 아래 approaches 비교가 필요하다. 유추 금지.
- OQ2: 두 층을 한 리뷰어의 검토·출력 순서로 둘 때의 후광 효과(상세 노이즈가 방향 판정을 오염) 를 어떻게 막나 — 같은 리뷰어를 두 번 부르는지, sentinel 을 층별로 나누는지, 다른 형태인지. ST1 전환이 남긴 약점이다.
- OQ3: 기존 락의 이관 — 재리뷰 상한 5 의 cross-file 락(상한이 2 로 바뀌므로 8개 파생 위치를 함께 옮겨야 한다), stagnation 술어(dismissed_by_user 의 의미가 「기각 처분」으로 옮겨감), dispatch 처분 락 축 A~C. 어느 자리부터 바꾸고 두 계약이 공존하는 창을 어떻게 다루나.
- OQ4: seed 자리(Phase 0, state 파일이 없는 단계)의 원장·처분 계약 형태. 배선은 마지막으로 결정됐고 형태는 미정.
- OQ5: 결정 기록(append-only, 뒤집으면 superseded)의 저장 위치 — 문서 안 섹션 / 세션 state / audit. 세 곳 다 선례가 있다.
- OQ6: generic doc 프로필에서 헤딩이 없는 문서의 앵커와 얼림 단위.
- OQ7: codex 가 같은 처분 어휘를 내게 하는 형식 계약 — JSON 강제 출력이 정확도를 크게 떨어뜨린다는 실측이 있어 sentinel 형식이 자명하지 않다.
- OQ8: 1차 탐지를 프레이밍을 못 보는 critic 「한 명」으로 둘지 「독립 병렬 N명」으로 둘지 — 9월 2일 인터뷰의 OQ13 이 그대로 열려 있다. D2 의 「하나」는 이 반론을 검토한 뒤의 결정이 아니다. 유추 금지.
- OQ9: 9월 2일 인터뷰의 OQ11·OQ12·OQ14~OQ19(분기 판정자의 프레이밍 공유, 입력 비대칭, 입증 책임 비대칭, 프레이밍 누출 경로 전수, 별가족 축의 위치, 기각 계수, 회계 어휘 반례, 집행 층)는 이 설계가 그 사이클에서 물려받은 미결이다. brainstorming 이 그 문서를 함께 읽는다.
- OQ10: 보호 부류(D12)를 문서 안에서 식별하는 규칙 — 헤딩 이름 매칭인지 프로필이 선언하는 목록인지.

## 4. External Landscape

- PaperJury «paperjury» — [취함] — 리뷰 finding 을 층이 아니라 처분(invalid-drop / valid-fixable / author-required)으로 라우팅하고, 핵심 주장을 얼려 두며(frozen claim spine) 수정을 앵커에 묶는다. 「issue validity does not imply machine editability」가 D3 의 `decide` 와 D4 의 얼림의 선례다. 안전·완료 로직은 model discretion 이 아닌 deterministic orchestration 에 둔다.
- Nine Judges, Two Effective Votes «nine-judges» — [취함] — LLM 판정자 9개의 실질 독립 표는 약 2개이고 최고 단일 판정자가 패널을 대개 이긴다. 병목은 집계가 아니라 판정자 상관. 리뷰어 추가가 독립성을 더하지 않는다는 근거 — D2 의 이유.
- Looping Is Not Reliability «looping-not-reliability» — [취함] — 회귀는 정답 상태가 non-absorbing 이라 다음 revision 이 지우는 데서 온다(정답 후 revision 에서 16% 소실). 처방은 라우팅이 아니라 last-known-good 핀 + 수정 범위 제한(Keep/Patch/Escalate 타입 계약). D4 의 근거.
- Iterative refinement 연구 정리 «iterative-refinement» — [취함] — 첫 반복 이후 회귀율이 오르고, 전체 재작성보다 선택적 편집이 회귀를 줄이며, self-bias 는 별도 모델 피드백으로 막는다. codex co-review 유지의 이유.
- Adversarial Review «adversarial-review» — [취함] — 리뷰 역할 둘이 다섯 에이전트 파이프라인을 이긴다. 산출물을 얼린 채 리뷰 텍스트만 교환하고 그다음 편집 — 「무엇이 틀렸는지 합의 안 된 채 함께 고쳐 쓰기」를 막는 것이 핵심. C3 의 「모델끼리 억지로 합의시키지 않는다」와 같은 축.
- Two Calls Beat Five Agents «two-calls» — [취함] — 2-call 이 5-agent 보다 정확하고 토큰 7배 절감. 부수 발견: JSON 강제 출력이 정확도를 절반으로 붕괴 — OQ7 의 출처.
- Selection Bottleneck «selection-bottleneck» — [중립] — 다양성의 이득은 selector(라우팅) 품질에 종속. 리뷰어보다 라우터 설계가 우선이라는 관점. 이 설계에서 라우터는 오케스트레이터 + 처분 규칙이다.
- Conventional Comments «conventional-comments» — [취함] — 리뷰어 한 명이 comment 마다 blocking / non-blocking 장식으로 「무엇이 승인을 막나」를 표현. 두 축(수신자 × 승인 차단)을 값 다섯으로 접은 D3 의 실무 선례.
- Squarespace 「Yes, if」 «yes-if» — [취함] — approve / reject verdict 를 「무엇이 있으면 승인인가」 finding 단위 조건으로 대체. verdict → 처분 전환의 실무 선례.
- Azure Well-Architected ADR «azure-adr» — [취함] — 결정 기록은 append-only, 뒤집을 때는 superseded 새 기록, 결정의 confidence 를 함께 적는다. D8 의 결정 단위 escalation 기록 형식.
- Fagan / software inspection «software-inspection» — [중립] — 발견과 처리 논의를 회의에서 분리한다. 리뷰어가 처분까지 정하면 발견의 정확도가 떨어진다는 경고 — C4 의 「둘 다 쓴다」가 그 대응이다.
- Human-in-the-loop automation bias «automation-bias» — [피함] — 사람이 결론을 승인하는 자리에 놓이면 정확도가 크게 떨어지고 클릭으로 게이트를 여는 법을 학습한다. `decide` 인플레이션을 피하려고 `ask` 를 별도 값으로 두고(D3) 결정 단위로 묶었다(D8) — 라운드마다 올린다는 C3 자체는 바꾸지 않았다.

## 5. 기각 · Blind Spots

- 기각 — 두 층을 별개 리뷰어(subagent)로 나누고 1층은 verdict 없이 질문만 내는 형태 → 근본 원인(수신자 부재)에 맞는 약은 리뷰어 분할이 아니라 finding 의 수신자 필드이고, 같은 모델 리뷰어를 하나 더 두는 것은 독립 판정을 더하지 않으며, dispatch·파싱·회계 지점이 늘어 경량 제약과 M4 에 걸리고, 교차 finding(상세 문장이지만 방향 문제)의 귀속이 모호해진다. 두 층이라는 관점은 persona 의 검토·출력 순서로 남긴다 — verdict: switched — ST1
- 기각 — 라운드마다 자동 커밋하는 자율 루프를 새 설계의 전제로 삼는 것 → 사용자가 seed 에서 「그것을 포함해 기존 구현의 어느 모양에도 끌려가지 말라」고 했다(선택지에서 제거한 것이 아니라 전제로 삼지 말라는 것). last-known-good 핀 자체는 버리지 않는다 — 세션 state 의 라운드 스냅샷과 해시로 채택한다(D13). 첫 판본은 핀을 자율 커밋과 묶어 함께 기각했고 방향성 리뷰가 그 묶음을 풀었다
- 기각 — 오케스트레이터가 1차 재비판을 하고 재비판 subagent 를 제거하는 형태(08-27 M2·M4, 이 brief 첫 판본의 D7·§5) → 원래: 오케스트레이터 재비판 + subagent 제거 / 재결정: 프레이밍을 못 보는 독립 재비판자 유지, 오케스트레이터는 수신·처분·라우팅만(D10·D7) / 근거: 사용자가 9월 2일 인터뷰 C3 에서 M2·M4 를 이미 뒤집었고, 오탐을 기각할 기계 경로가 0 이 되며(Claude D2·codex 2 독립 지적), 오케스트레이터는 dispatch 를 쓴 주체라 전제 오염이 가장 크다
- 기각 — 재리뷰 상한 5회 유지(seed C7) → 원래: 5회 그대로(S1) / 재결정: 모든 문서 리뷰 자리에서 2회로 통일(D17) / 근거: 사용자 지시(S12), 단 반드시 필요한 경우 추가 라운드 제안은 허용(S13). 인터뷰 중 근거로 본 것 — 실측 연구에서 첫 반복 이후 회귀율이 오르고, 이 리포의 brief 리뷰가 이미 2 로 돌며, 상한은 회귀 장치가 아니라 안전망이다
- 기각 — 현재 spec-reviewer 의 verdict 세 값(approved / needs_revise / needs_interview) 유지 → ✎ 도출: verdict 는 처분의 집계로 나온다(`decide` 열림 → 승인 불가). 세 값을 산출물로 두는 것이 근본 원인(D1)이다
- 기각 — `decide` · `fix` · `defer` 셋만 두는 처분 집합 → `ask` 가 없으면 불확실한 finding 이 `decide` 로 승격돼 라운드마다 중단이 늘거나 `fix` 로 내려가 저자가 유추해 채운다
- 기각 — 스펙에 파일 경로·코드 블록·명령을 금지하고 있으면 `fix` 로 잡는 강한 경계 → 저자를 막는다. `defer` 로 옮기는 쪽이 같은 경계를 덜 무겁게 지킨다(S7)
- 기각 — `testing` 카테고리 폐기(이 brief 첫 판본의 D6) → 원래: 폐기 / 재결정: 「검증 전략 부재」로 재정의하고 절차·명령만 `defer`, Law 1 목록 불변 / 근거: CLAUDE.md Law 1 필수 섹션(Files to Modify·Verification Plan)과 superpowers brainstorming 의 testing 커버 요구와 충돌했다(Claude D7)
- 기각 — 얼림 키를 「이번 라운드 finding 없는 섹션」 하나로 두는 것(첫 판본 D4) → 원래: finding 없음(결정론은 헤딩 diff 한 곳, S5) / 재결정: C2 보호 부류와의 합집합(D12), 결정론은 헤딩 diff 와 보호 섹션 목록 둘 / 근거: AC 섹션에 `fix` 하나만 앵커되면 녹아 저자가 사용자 결정 없이 AC 를 바꾸는 경로가 열린다(Claude D4·codex 1 독립 지적)
- 기각 — brief·seed 프로필의 허용값을 `decide`·`drop` 으로 제한(첫 판본 §2 ✎) → 원래: `fix` 금지 / 재결정: `fix` 허용하되 앵커 §0·§2, §6 불변(D15) / 근거: 충실도 왜곡 하나하나가 사용자 결정이 되어 M3 와 충돌하고 `decide` 인플레이션의 최대 공급원이 된다(Claude D8)
- 기각 — `ask` 전부를 승인 게이트까지 미루는 것(첫 판본 D8) → 원래: 전부 게이트 / 재결정: `fix` 의 전제인 `ask` 는 라운드 묶음에 비차단으로(D16) / 근거: 답 없이 종속 수정을 진행하거나 사실 확인을 `decide` 로 승격하게 된다(codex 3)
- 위험 — 숨은 가정: 리뷰어가 「누가 받을지」를 정확히 판정할 수 있다 — 리뷰어는 결함의 원인이 어느 층에 있는지에 대한 정보가 가장 적은 쪽이다. 방향 결함이 `fix` 로 오라벨되면 근본 원인이 라벨만 바꿔 재생산된다 — 근거: inspection 문헌의 발견/처리 분리, C4 의 이중 처분과 D7 의 올리기 전용 재비판이 완화 장치
- 위험 — 숨은 가정: `decide` 열림 → 승인 불가 규칙이 사람 결정의 질을 보장한다 — 보장하는 것은 클릭 사실뿐이다. 오케스트레이터가 요약·추천을 붙여 올리면 사람은 결론을 승인하는 자리에 놓인다 — 근거: automation bias 실측, 결정 단위 묶음(D8)이 밀도를 줄일 뿐 마모를 재는 장치는 없다
- 위험 — 숨은 가정: codex 별모델 co-review 가 독립성을 맡는다 — codex 가용성은 외부 계정 상태의 함수라 부재 시 독립 판정이 0 이고(핸드오프 T2), 살아 있어도 같은 문서·같은 프롬프트를 읽으면 별가족 모델도 전제를 공유한다 — 근거: verifier 상관 모델링 연구, 「model-family diversity does not ensure independence」. D7 이 부재를 게이트 첫 줄에 공시하되 막지 않는다
- 위험 — 숨은 가정: 방향/상세 구분이 리뷰어 출력에서 안정적으로 갈린다 — 같은 문장이 「고치면 무엇이 바뀌나」에 따라 방향도 상세도 된다. 두 리뷰어가 라벨 자체에서 갈리면 「하나라도 올리면 올림」이 메우지만 escalate 수가 보수적인 쪽에 수렴한다 — 근거: reasoning-trace disagreement 연구, 처분 어휘가 커지면 off-vocab drift 표면도 커진다
- 위험 — 실패 양식: 처분 부활/흡수 — finding 정체성이 (category, section) 해시면 기각된 finding 이 다른 이름으로 재등장하거나 새 회귀가 옛 id 에 흡수돼 소실된다 — 근거: 「stale evidence resurrects bugs」 실측, D4 의 supersedes 지목 + 오케스트레이터 대조가 대응이나 형태는 brainstorming 몫
- 위험 — 실패 양식: 정답 파괴 회귀가 라우팅을 통과 — `fix` 몇 건을 고치는 한 revision 이 이미 통과한 섹션을 건드려 방향을 바꾸는데 어떤 finding 에도 속하지 않아 처분이 없다 — 근거: 정답 후 revision 16% 소실 실측, D4 의 얼림 + 자동 decide 가 정확히 이것을 겨냥한다
- 위험 — 실패 양식: 오케스트레이터 재비판이 「둘 다 유지」를 한쪽으로 접는다 — 저자에게 넘길 때 하나의 지시로 접혀 반대 의견이 사라진다(핸드오프 T1) — 근거: consensus collapse 는 접는 주체가 누구든 발생. D7 이 하향·삭제를 막아 구조적으로 접을 수 없게 한다
- 위험 — 실패 양식: 두 층을 한 패스의 출력 순서로 두면 상세 노이즈가 방향 판정을 오염하는 후광 — 순서는 출력의 순서지 판단의 독립이 아니다 — 근거: LLM 리뷰어의 systematic overcorrection 실측. OQ2
- 위험 — 숨은 가정: 리뷰어 「하나」가 병렬 N명보다 낫다 — 근거로 든 판정자 상관 연구는 점수 판정 과업을 잰 것이지 인용 근거로 finding 을 기각하는 2차 패스의 효용을 잰 것이 아니고, 이 리포에는 두 번째 판정자가 단독으로 잡은 사례가 반복 기록돼 있다(Claude D9). OQ8
- 위험 — 숨은 가정: 편집 범위 선언(D13)과 적용 전 제안(D14)이 산문으로 지켜진다 — 하니스를 가볍게 두는 대가로, 선언 범위 대 실제 diff 의 대조 하나만 결정론이고 나머지는 저자 세션의 준수에 걸린다
- 위험 — 실패 양식: 「완전 새로」가 기존 락의 트리거를 지운다 — 재리뷰 상한 5 · stagnation 술어가 cross-file 락으로 묶여 있고 verdict 를 처분으로 대체하면 dismissed_by_user 의 의미가 옮겨가 stagnation 이 조용히 inconclusive 로 떨어진다 — 근거: 레포 실측 「내 수정이 기존 락의 트리거를 없앤다 — GREEN 유지라 안 보인다」. OQ3
- 위험 — 실패 양식: `defer` 가 결함 매립지가 된다 — plan 이 이월을 읽을 계약이 없으면 침묵 삭제와 같다 — 근거: spec-driven 도구들의 spec/plan 분리 관행. 완화: 목적지가 `Handoff Context › Deferred to plan` 소절로 문서 안에 있고 writing-plans 가 spec 을 읽는다
- 위험 — 숨은 가정: 네 자리가 같은 문제를 공유하므로 하나의 공통 설계로 덮인다 — 저자가 다르고 정답의 출처가 다르다 — 근거: PRD / spec / plan 의 소유 구분 관행. D5 의 프로필(허용 처분값)이 이 차이를 담는 자리다

## 6. 사용자 원문

- **S1** 🗣 최초 요청 (Phase 0 이 확정한 interview-seed 전문, frontmatter 포함):
  > ---
  > name: document-review-redesign
  > type: interview-seed
  > ---
  >
  > devbrew 에서 문서를 리뷰하는 자리들을 근본부터 다시 설계하려고 한다. 지금 보이는 자리는 셋이다. brainstorming 이 낸 design doc 을 보는 `reviewing-spec` 과 `spec-reviewer`, 인터뷰 brief 를 보는 `reviewing-brief` 와 그 리뷰어들, 그리고 quality-gates 의 `/qg critique` 가 비-코드 산출물을 보는 자리. design doc · brief · artifact · doc 을 리뷰한다는 관점에서 이 자리들에는 통합되는 부분이 있다고 본다. 이 네 종류가 세 자리에 어떻게 대응하는지, 특히 doc 이 어디에 속하는지는 아직 정하지 않았다. 공통되는 부분은 shared 로 통합 관리하고, 특화되는 지점에서는 반드시 분화한다. 라운드마다 자동 커밋하는 자율 루프를 포함해 기존 구현의 어느 모양에도 끌려가지 말고, 가장 적합한 형태로 완전히 새로 만든다.
  >
  > 내가 본 문제는 이렇다. 스펙 리뷰가 request framing → interview → brainstorming → writing-plans → 구현으로 이어지는 큰 그림에서 자기 역할에 맞게 하고 있는지 봐야 한다. 리뷰어 발견 이후 고치는 것이 바로바로 고치는 식이라 잘 고민해서 고치지 못한다. 단순한 수정과 재리뷰의 반복이 회귀를 만든다. writing-plans 가 도출하고 관측할 일이 스펙 쪽에 섞여 있다 — 스펙은 스펙의 역할에 충실해야 한다.
  >
  > 내가 정한 것. 리뷰어는 근본적 해결을 제안하되 혼자 결정하지 않는다. 큰 그림 관점에서 방향이 틀렸다는 발견은 저자가 고치지 않고 나에게 바로 올라온다. finding 을 반영하다가 목표·범위·제약·Non-goal·아키텍처·trade-off·Acceptance Criteria 가 바뀌거나 새 요구가 추가되면 수정하기 전에 변경 내용과 근거·대안·영향을 나에게 보고하고 내가 결정한다. 모델이 임의로 정한 것과 리뷰어 사이에 합의되지 않은 방향도 같은 길로 온다. 모델끼리 억지로 합의시키지 않는다. 무엇을 바로 고치고 무엇을 올릴지는 리뷰어의 표시와 수정하는 세션의 판단을 둘 다 쓰고, 하나라도 올리라 하면 올린다. 리뷰어 불일치는 방향에 관한 것만 나에게 올리고 상세에 관한 불일치는 둘 다 유지한다. 올리는 시점은 라운드마다다. 막아야 할 회귀는 수정이 새 결함을 만드는 것이다.
  >
  > 내 안은 두 층이다. 먼저 사용자 목표와 문제 정의, 전체 범위, 핵심 아키텍처, 컴포넌트 관계와 데이터 흐름, 주요 trade-off, 구현 가능성 등이 하나의 그림으로 정합한지 검토한다. 그다음 누락·모호성·Acceptance Criteria·검증·handoff 등 상세 완결성을 확인한다. 세부 항목이 완전해도 전체 방향이 잘못됐으면 승인하지 않는다. 이 방식은 내 의견이고 더 좋은 방안이나 형태가 있으면 반드시 제안해 달라. 후보 하나는 두 층을 별개 리뷰어로 나누고 첫 층 리뷰어는 verdict 없이 질문만 내는 것이다. 확정은 인터뷰에서 근거를 더 모은 뒤에 한다. 레포 안에서 참고할 선례는 brief 의 방향 리뷰어와 quality-gates 의 critique 리뷰어 쌍이다. 참고하되 끌려가지 않는다.
  >
  > 결정 게이트는 산문과 구조 둘 다 쓴다. 구조를 만드는 것은 좋지만 너무 무거운 하니스는 버그가 나거나 억제가 심해지거나 다른 방향으로 동작했다. 그건 지양한다.
  >
  > 그대로 두는 것: 재리뷰 상한 5회, codex 병렬 co-review, 문서 발견용 Stop 훅, `/compact` proceed 게이트. superpowers brainstorming 의 자체 self-review 단계는 범위 밖이다.
  >
  > 인터뷰에서 정해야 할 것: 스펙과 plan 의 경계 — superpowers 의 spec 과 plan 이 각각 무엇을 소유하는지 더 이해한 뒤에 무엇을 plan 으로 넘길지 정한다. 두 층의 형태. 수정이 만드는 새 결함을 잡는 장치의 형태. 세 자리에서 무엇이 공통이고 무엇이 특화인지를 가르는 방법. 네 종류의 리뷰 대상과 세 자리의 대응.

## 7. Next Action

superpowers 가 있으면 이 brief 를 context 로 `superpowers:brainstorming` 을 호출한다(architectural path — 새 subsystem 이자 세 플러그인의 인터페이스 변경). brainstorming 은 레포 선례(brief 의 방향 리뷰어 · quality-gates 의 critique 리뷰어 쌍)를 참고하되 끌려가지 않고(C9), §3 의 OQ1~OQ10 을 approaches 비교로 다루고(OQ9 의 원문은 `docs/superpowers/interview/2026-09-02-adjudication-topology-interview.md` §3), §2 의 확정 항목은 근거가 있으면 보고 후 재결정 가능하되 임의 변경은 금지다. 산출 `-design.md` 는 reviewer 검증을 거쳐 writing-plans 로 간다. superpowers 가 없으면 이 brief 가 완결 산출물이다.
