---
name: steelman-goal-fit
type: interview-brief
created_at: 2026-09-05
session_id: 1f5a8290-7b4b-454d-b493-438037a5123f
source: spec-distill conducting-interview v0.53.1
next_phase: superpowers:brainstorming
audit_file: 2026-09-05-steelman-goal-fit-interview.audit.md
user_sourced_items:
  - id: C1
    source: verbatim
    status: confirmed
    statement: "이 문제의 본질은 판정 기준의 부재와 builder 의 역할 편향 둘이고, 기록 어휘는 파생으로 보인다"
    evidence: S2
  - id: C2
    source: chosen
    status: confirmed
    statement: "핵심 전제는 orchestrator 가 R1 문제정의·goal·사용자 발화에서 도출해 builder 에 넘기고, 게이트 4-block 에 그 목록을 그대로 노출한다. 별도 확인 라운드는 두지 않는다"
    evidence: S3
  - id: C3
    source: chosen
    status: confirmed
    statement: "ST1 보완 — 단일 builder 가 원안·대안 양쪽 케이스를 쓰는 원안을 유지하되, P0(분리된 dispatch 컨텍스트) 명시 · dispatch payload 에 goal 리터럴 · 대안 케이스를 원안보다 먼저 쓰는 순서 셋을 더한다"
    evidence: S4
  - id: C4
    source: chosen
    status: confirmed
    statement: "builder 의 전제 부착 주장 중 양성(hits 가 비어 있지 않은 것)만 orchestrator 가 게이트 전에 전제 문장과 근거를 대조해 확인한다. 음성은 확인하지 않는다"
    evidence: S5
  - id: C5
    source: chosen
    status: confirmed
    statement: "전제에 닿지 않는 근거는 4-block 에 라벨을 붙여 노출하고 audit §3 ST<N> 에 전문 보존하며 payload §5 에 「근거 N 중 부착 M」 을 센다. 회계상 흡수이며 degrade 가 아니다"
    evidence: S6
  - id: C6
    source: chosen
    status: confirmed
    statement: "전제를 정면으로 치는 근거 더미(8-30 표본의 논문 9건)는 걸러질 대상이 아니라 정당한 재검토 사유다. 불만의 실체는 이분법 기록·제약 무지·무관 근거이고 이 설계가 그것을 잡는다"
    evidence: S7
  - id: C7
    source: chosen
    status: confirmed
    statement: "builder 출력 순서는 대안 케이스 → 원안 케이스 → 전제 반증 판정 → 추천이다. seed 의 「첫 필드」는 이 재결정으로 대체된다"
    evidence: S8
  - id: C8
    source: chosen
    status: confirmed
    statement: "의심 trigger 가 없는 인터뷰는 §5 에 검토한 방향 N·전제 목록·trigger 후보와 기각 이유를 적은 항목으로 skepticism 을 닫고, check_brief 가 그 형식을 인식한다"
    evidence: S9
  - id: C9
    source: chosen
    status: confirmed
    statement: "builder 의 리포 주장 인용은 경로 + 앵커(심볼·헤딩·원문 인용 중 하나) 필수, 줄번호는 보조다. seed 의 file:line 은 이 재결정으로 대체된다"
    evidence: S10
  - id: C10
    source: chosen
    status: confirmed
    statement: "verdict 기계 토큰은 VALID_VERDICTS 를 kept / refined / switched / deferred 로 토큰까지 전면 개명한다. 픽스처와 과거 brief 원장 이관이 필요하다"
    evidence: S11
  - id: C11
    source: chosen
    status: confirmed
    statement: "builder 추천은 4-block 추천 답안 블록에 orchestrator 의견과 나란히 표시하고, 선택지는 항상 유지/보완/전환/보류 순으로 고정하며 Recommended 라벨로 첫 자리에 올리지 않는다"
    evidence: S12
  - id: C12
    source: chosen
    status: confirmed
    statement: "Open Questions 6건은 유추로 닫지 않고 §3 에 이대로 박제한다"
    evidence: S13
  - id: C13
    source: verbatim
    status: confirmed
    statement: "범위는 steelman-builder 페르소나 + conducting-interview R3 게이트 + check_brief.py 이고 brief 리뷰 단계의 brief-direction-reviewer 는 이번 범위 밖이다"
    evidence: S1
  - id: C14
    source: verbatim
    status: confirmed
    statement: "재검토를 여는 열쇠는 하나 — 새 근거가 원안의 핵심 전제와 직접 충돌할 때. 그 외의 근거는 원안을 강화하거나 경계를 다듬는 데 쓴다"
    evidence: S1
  - id: C15
    source: verbatim
    status: confirmed
    statement: "판정 어휘는 유지 / 보완 / 전환 / 보류 넷. 보완이 신설이고 방어→유지는 개명이다. 보류는 builder 추천엔 없고 게이트에서 사람만 고른다"
    evidence: S1
  - id: C16
    source: verbatim
    status: confirmed
    statement: "builder 에게 「전제 목록 자체가 틀렸다」는 발견을 허용한다"
    evidence: S1
  - id: C17
    source: verbatim
    status: confirmed
    statement: "약하거나 무관한 반론의 봉쇄 기준은 근거가 어느 핵심 전제에 부딪히는지 명시하지 못하면 재검토 사유가 아니라는 것이며, confidence 임계는 올리지 않는다"
    evidence: S1
  - id: C18
    source: verbatim
    status: confirmed
    statement: "R3 trigger 중 coverage-mapper neglect 는 뺀다 — 커버리지 공백은 전제 충돌이 아니라 probe 질문으로 갈 일이다"
    evidence: S1
  - id: C19
    source: verbatim
    status: confirmed
    statement: "「확정된 방향」은 사용자가 인터뷰에서 실제로 답한 것과 seed 의 내용이다. 종료 게이트의 confirmed 가 아니다"
    evidence: S1
  - id: C20
    source: verbatim
    status: confirmed
    statement: "불만은 오염과 흔들림이지 탐색 비용이 아니다"
    evidence: S1
  - id: C21
    source: verbatim
    status: confirmed
    statement: "steelman 의 목적을 「원안 뒤집기」에서 「사용자 goal 에 가장 적합한 방향 찾기」로 바꾼다"
    evidence: S1
  - id: C22
    source: verbatim
    status: confirmed
    statement: "builder 는 원안과 대안 양쪽의 최강 케이스를 같은 기준(사용자 goal)으로 쓰고 유지/보완/전환 추천을 낸다"
    evidence: S1
  - id: C23
    source: chosen
    status: confirmed
    statement: "핵심 전제는 R1 이 재구성한 문제정의·goal 에서 오고, dispatch 시점에 orchestrator 가 사용자가 그때까지 말한 제약을 user_statements 원문 인용으로 함께 builder 입력으로 명시해 넘긴다 — seed 의 「요지」 전달은 이 재결정으로 대체된다"
    evidence: S15
  - id: C24
    source: verbatim
    status: confirmed
    statement: "builder 의 리포 주장을 orchestrator 가 게이트 전에 확인하는 단계를 R3 에 넣는다"
    evidence: S1
  - id: C25
    source: verbatim
    status: confirmed
    statement: "게이트 선택은 기존대로 사용자가 한다"
    evidence: S1
  - id: C26
    source: chosen
    status: confirmed
    statement: "steelman 0건 인터뷰는 §5 기록 항목이 필수다 — verdict 항목 0건이면서 기록 항목도 0건이면 check_brief 가 RED 를 낸다. 현행 T12 의 「기록 없이 통과」는 반전된다"
    evidence: S16
---

# steelman 목표 적합 — Interview Brief

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 brainstorming 해답공간으로
> 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다. 텔레메트리는 `audit_file`에 있다.
> 이 파일은 Phase 0 의 interview-seed 와 같은 경로에 쓰였다 — seed 전문은 §6 `S1` 에 그대로 있다.

## 0. 한눈에

**무엇** — spec-distill 인터뷰의 R3 단계(의심된 방향에 대해 steelman-builder 가 반대 케이스를 만들고 사용자가 판정하는 게이트)를 「원안 뒤집기」에서 「사용자 goal 에 가장 적합한 방향 찾기」로 다시 세운다. 손대는 곳은 셋 — steelman-builder 페르소나, conducting-interview 의 R3 절, check_brief.py.

**왜** — 진단(orchestrator, Phase 0 표본 판독, 사용자 동의): 현 R3 에는 판정 기준(사용자 goal)이 없고 builder 는 「대안의 옹호자」로 정의돼 있다. 기준 부재와 역할 편향이 함께 근거의 **강도**가 **관련성**을 대체하게 만들고, 방어/전환 이분 어휘가 그 결과를 원장에 굳힌다(파생). 표본 8건에서 실질은 전환 3·보완 3·유지 1·불명 1 이었는데 기록은 switched 6·defended 2 였고, 2건에서 builder 가 리포 사실을 틀리거나 사용자가 이미 닫은 경로를 대안으로 냈고, 그것을 잡은 것은 계약에 없는 orchestrator 의 사후 검증이었다.

**무엇이 확정(Step B 에서 사용자 확정, C1~C25)** — steelman 의 목적은 「사용자 goal 에 가장 적합한 방향 찾기」다. 재검토 열쇠는 「새 근거가 핵심 전제와 직접 충돌」 하나. 핵심 전제(R1 문제정의·goal 에서 orchestrator 가 도출)와 사용자가 그때까지 말한 제약의 요지와 goal 리터럴을 orchestrator 가 dispatch 시 builder 에 명시해 넘기고, 전제 목록은 게이트 4-block 에 그대로 노출한다. builder 는 원안과 대안 양쪽의 최강 케이스를 같은 기준(사용자 goal)으로 대안 → 원안 → 전제 반증 판정 → 추천(유지/보완/전환) 순으로 쓰고, 근거마다 닿는 전제를 적으며, 전제 목록 자체를 반박할 수 있다. 양성 부착 주장과 리포 주장(경로+앵커)은 orchestrator 가 게이트 전에 확인한다. 비부착 근거는 라벨 붙여 노출·audit 보존·「근거 N 중 부착 M」 계수(흡수). 판정 어휘 유지/보완/전환/보류이고 게이트 선택은 사용자가 한다. 기계 토큰은 kept/refined/switched/deferred 로 전면 개명한다. trigger 없는 인터뷰는 기록 sentinel 로 skepticism 을 닫는다. coverage-mapper neglect 는 trigger 에서 뺀다. 개수 상한·티어링(orchestrator 위임 결정)·confidence 임계 상향은 쓰지 않는다. 그 아래 세부(refined 의 취함/버림 구절, 확인 결과의 기록·노출, confidence 필드 존치)는 orchestrator 제안이며 미확정이다(§2 ✎). 제약 전달 형태(원문 인용)와 0건 게이트(기록 항목 요구)는 brainstorming 진입 시 사용자가 확정했다(C23·C26).

**무엇이 열려 있음** — §3 의 6건: P0 분리가 프레임 공유·sycophancy 를 못 막는 것, 전제 도출 오류율, 순서 효과의 외삽, 결과를 치는 반증의 흡수, sentinel 형식주의, 스니펫 확인만 된 근거 5건.

**다음 stage** — brainstorming(§7). 이 인터뷰의 R3 자체가 새 계약을 한 번 예행했다(ST1, audit §3): 전제 4개와 제약을 넘겼고 builder 는 반증 없음·보완 추천을 냈으며 리포 주장 7건이 게이트 전 확인에서 전부 사실이었다.

## 1. Goal · Non-goal

- Goal: steelman 이 인터뷰의 결정 품질을 높이되, 그 결정의 기준(사용자 goal 과 핵심 전제)을 절차 **안에** 명시해 어떤 근거든 「그 기준에 닿는가」로 걸러지게 한다. 원안과 대안은 같은 기준 위에서 대칭으로 비교되고, 판정은 유지/보완/전환/보류 넷 중 하나로 원장에 남는다.
- Goal: 약하거나 무관한 반론이 확정된 방향(사용자가 인터뷰에서 답한 것 + seed)을 다시 열지 못한다 — 열쇠는 핵심 전제 충돌 하나다.
- Non-goal: brief 리뷰 단계의 brief-direction-reviewer 는 건드리지 않는다.
- Non-goal: 외부 근거의 개수 상한, 출처 티어링, confidence 임계 상향 — 셋 다 쓰지 않는다.
- Non-goal: 새 agent 추가(두 옹호자 설계)는 하지 않는다 — ST1 에서 보완으로 판정.
- Non-goal: 전제를 정면으로 치는 근거의 양을 줄이는 것 — 그것은 정당한 재검토 사유다(C6).
- Non-goal: 이 봉쇄가 Sealed decision 이 되는 것 — 열쇠는 「확정됐으니까」가 아니다. 반대로 원안 옹호로 기울어 steelman 의 존재 이유를 잃는 것도 아니다.

## 2. 제약

(이 절의 진술은 모델이 쓴 요약이다. 원문은 payload §6(S1)과 audit §6(S2 이상)에 나뉘어
 있고, `⟨S<N>⟩`가 그중 하나를 가리킨다. 전 항목은 종료 게이트(S14)에서 사용자가 일괄 확정했다 — 재결정 규약: confirmed 항목은 근거 있으면 보고 후 재결정 가능하고 임의 변경은 금지다.)

- 🗣 confirmed **C1** — 이 문제의 본질은 판정 기준의 부재와 builder 의 역할 편향 둘이고, 기록 어휘는 파생으로 보인다 ⟨S2⟩
- ☑ confirmed **C2** — 핵심 전제는 orchestrator 가 R1 문제정의·goal·사용자 발화에서 도출해 builder 에 넘기고, 게이트 4-block 에 그 목록을 그대로 노출한다. 별도 확인 라운드는 두지 않는다 ⟨S3⟩
- ☑ confirmed **C3** — ST1 보완 — 단일 builder 가 원안·대안 양쪽 케이스를 쓰는 원안을 유지하되, P0(분리된 dispatch 컨텍스트) 명시 · dispatch payload 에 goal 리터럴 · 대안 케이스를 원안보다 먼저 쓰는 순서 셋을 더한다 ⟨S4⟩
- ☑ confirmed **C4** — builder 의 전제 부착 주장 중 양성(hits 가 비어 있지 않은 것)만 orchestrator 가 게이트 전에 전제 문장과 근거를 대조해 확인한다. 음성은 확인하지 않는다 ⟨S5⟩
- ☑ confirmed **C5** — 전제에 닿지 않는 근거는 4-block 에 라벨을 붙여 노출하고 audit §3 ST<N> 에 전문 보존하며 payload §5 에 「근거 N 중 부착 M」 을 센다. 회계상 흡수이며 degrade 가 아니다 ⟨S6⟩
- ☑ confirmed **C6** — 전제를 정면으로 치는 근거 더미(8-30 표본의 논문 9건)는 걸러질 대상이 아니라 정당한 재검토 사유다. 불만의 실체는 이분법 기록·제약 무지·무관 근거이고 이 설계가 그것을 잡는다 ⟨S7⟩
- ☑ confirmed **C7** — builder 출력 순서는 대안 케이스 → 원안 케이스 → 전제 반증 판정 → 추천이다. seed 의 「첫 필드」는 이 재결정으로 대체된다 ⟨S8⟩
- ☑ confirmed **C8** — 의심 trigger 가 없는 인터뷰는 §5 에 검토한 방향 N·전제 목록·trigger 후보와 기각 이유를 적은 항목으로 skepticism 을 닫고, check_brief 가 그 형식을 인식한다 ⟨S9⟩
- ☑ confirmed **C9** — builder 의 리포 주장 인용은 경로 + 앵커(심볼·헤딩·원문 인용 중 하나) 필수, 줄번호는 보조다. seed 의 file:line 은 이 재결정으로 대체된다 ⟨S10⟩
- ☑ confirmed **C10** — verdict 기계 토큰은 VALID_VERDICTS 를 kept / refined / switched / deferred 로 토큰까지 전면 개명한다. 픽스처와 과거 brief 원장 이관이 필요하다 ⟨S11⟩
- ☑ confirmed **C11** — builder 추천은 4-block 추천 답안 블록에 orchestrator 의견과 나란히 표시하고, 선택지는 항상 유지/보완/전환/보류 순으로 고정하며 Recommended 라벨로 첫 자리에 올리지 않는다 ⟨S12⟩
- ☑ confirmed **C12** — Open Questions 6건은 유추로 닫지 않고 §3 에 이대로 박제한다 ⟨S13⟩
- 🗣 confirmed **C13** — 범위는 steelman-builder 페르소나 + conducting-interview R3 게이트 + check_brief.py 이고 brief 리뷰 단계의 brief-direction-reviewer 는 이번 범위 밖이다 ⟨S1⟩
- 🗣 confirmed **C14** — 재검토를 여는 열쇠는 하나 — 새 근거가 원안의 핵심 전제와 직접 충돌할 때. 그 외의 근거는 원안을 강화하거나 경계를 다듬는 데 쓴다 ⟨S1⟩
- 🗣 confirmed **C15** — 판정 어휘는 유지 / 보완 / 전환 / 보류 넷. 보완이 신설이고 방어→유지는 개명이다. 보류는 builder 추천엔 없고 게이트에서 사람만 고른다 ⟨S1⟩
- 🗣 confirmed **C16** — builder 에게 「전제 목록 자체가 틀렸다」는 발견을 허용한다 ⟨S1⟩
- 🗣 confirmed **C17** — 약하거나 무관한 반론의 봉쇄 기준은 근거가 어느 핵심 전제에 부딪히는지 명시하지 못하면 재검토 사유가 아니라는 것이며, confidence 임계는 올리지 않는다 ⟨S1⟩
- 🗣 confirmed **C18** — R3 trigger 중 coverage-mapper neglect 는 뺀다 — 커버리지 공백은 전제 충돌이 아니라 probe 질문으로 갈 일이다 ⟨S1⟩
- 🗣 confirmed **C19** — 「확정된 방향」은 사용자가 인터뷰에서 실제로 답한 것과 seed 의 내용이다. 종료 게이트의 confirmed 가 아니다 ⟨S1⟩
- 🗣 confirmed **C20** — 불만은 오염과 흔들림이지 탐색 비용이 아니다 ⟨S1⟩
- 🗣 confirmed **C21** — steelman 의 목적을 「원안 뒤집기」에서 「사용자 goal 에 가장 적합한 방향 찾기」로 바꾼다 ⟨S1⟩
- 🗣 confirmed **C22** — builder 는 원안과 대안 양쪽의 최강 케이스를 같은 기준(사용자 goal)으로 쓰고 유지/보완/전환 추천을 낸다 ⟨S1⟩
- ☑ confirmed **C23** — 핵심 전제는 R1 이 재구성한 문제정의·goal 에서 오고, dispatch 시점에 orchestrator 가 사용자가 그때까지 말한 제약을 user_statements 원문 인용으로 함께 builder 입력으로 명시해 넘긴다 — seed 의 「요지」 전달은 이 재결정으로 대체된다 ⟨S15⟩
- 🗣 confirmed **C24** — builder 의 리포 주장을 orchestrator 가 게이트 전에 확인하는 단계를 R3 에 넣는다 ⟨S1⟩
- 🗣 confirmed **C25** — 게이트 선택은 기존대로 사용자가 한다 ⟨S1⟩
- ☑ confirmed **C26** — steelman 0건 인터뷰는 §5 기록 항목이 필수다 — verdict 항목 0건이면서 기록 항목도 0건이면 check_brief 가 RED 를 낸다. 현행 T12 의 「기록 없이 통과」는 반전된다 ⟨S16⟩

✎ orchestrator 가 위임받아 정한 것(S1 「직접 고민해줘」, 사용자 발화 아님): 외부 근거의 개수 상한과 출처 티어링은 쓰지 않는다 — 상한은 이 리포가 의도적으로 뺀 것이고 티어링은 8-30 인터뷰에서 사용자가 한 번 기각했다.

✎ orchestrator 제안 — **미확정**, 사용자가 정하지 않았고 Step B 게이트에서 판정 대상이다(제약이 아니다): ⓐ refined 항목은 「취함:」「버림:」 두 구절을 갖고 버림 구절이 R4 기각 코퍼스에 들어간다(prober FM1 대응 후보) ⓑ builder 에 넘기는 제약을 「요지」가 아니라 user_statements 원문 인용으로 한다(prober FM4 대응 후보 — C23 의 「요지」와 상충하므로 사용자 선택 필요) ⓒ 게이트-전 확인 결과를 audit §3 ST 블록 안에 주장별 확인·반증·미확인으로 남기고 반증된 주장은 4-block 에서 빼지 않고 「반증됨」 라벨로 보인다(prober FM5 대응 후보) ⓓ builder 출력의 confidence 필드를 폐지하고 「confidence<0.4 면 대안 약함 명시」 규칙은 recommendation=유지 가 대체한다(C17 은 임계 상향 금지만 말한다) ⓔ 전면 개명 후 옛 토큰을 한 minor 동안 별칭으로 받는다(C10 의 이관 방식 후보; CLAUDE.md 「제거 전 one-minor deprecation window」 규칙에서 옴).

✎ brainstorming 진입(2026-09-06)에서 사용자가 재결정 2건을 했다: ⓑ 는 ⟨S15⟩ 로 확정돼 C23 이 갱신됐고(근거: tools/adjudication/check_slots.py 의 orchestrator_framing 금지 kind 와 면제 baseline 4), 0건 게이트는 ⟨S16⟩ 으로 확정돼 C26 이 신설됐다. ⓐ·ⓒ·ⓓ 는 설계 문서에서 orchestrator 제안으로 다루고, ⓔ 는 CHANGELOG 선례(v0.x 는 one-minor window 면제)로 채택하지 않는다.

✎ R1 에서 orchestrator 가 도출해 ST1 dispatch 에 실제로 넘긴 핵심 전제 4개: P1 결함은 기준 부재 + 역할 편향 둘(C1) / P2 해법의 축은 같은 기준의 대칭 비교(C22) / P3 열쇠는 전제 충돌만(C14) / P4 게이트 선택은 사용자(C25). builder 가 P0 을 빠진 전제로 추가했고 사용자가 수용했다(C3). P0 의 「분리된 dispatch 컨텍스트」는 ST1 builder 원문(audit §3)에서 「방향을 형성한 인터뷰 턴과 분리된 컨텍스트」로 정의된 것이며, 그 정의는 builder 의 문장이고 사용자 발화는 아니다.

## 3. Open Questions

- OQ1: builder 가 분리된 dispatch(P0)여도 전제 목록·goal·제약은 방향을 만든 턴이 저술한다 — 프레임 공유와 sycophancy 는 이 설계가 막지 못한다. 모델 다양성(codex co-builder)은 이번 범위 밖이다. 다음 단계는 이 한계를 알고 설계하되 해결하려 들지 않는다.
- OQ2: 전제 도출 자체의 오류율 — 표본에 결정 축을 교체한 사례가 있고, premise_list_challenge 필드가 그것을 얼마나 잡는지 미측정이다.
- OQ3: 「대안 케이스 먼저」와 「전제 반증 판정을 뒤로」는 인간 판단 문헌(consider-the-opposite, 선행 판정 앵커링)의 외삽이다 — LLM builder 와 사람 판정자 조합에서 실측이 없다.
- OQ4: 결과(순서·비용)를 치는 반증은 전제에 닿지 않아 「흡수」로 분류되고 builder 추천에서 빠진다 — 라벨만으로 사용자가 게이트에서 그것을 집어내는지. 봉쇄는 builder 추천·orchestrator 라벨 층에만 있고 사용자 게이트 선택지는 제한하지 않는다는 것이 P23 의 보루다.
- OQ5: 기록 sentinel 이 새 형식주의(sentinel 제조)가 되는지 — 표본 7개 인터뷰 중 6개가 steelman 1회, 1개(8-16)가 2회로 닫혔고 0회는 없었다. 이것이 자연 빈도인지 압력인지 가를 자료가 없다. 현 기계 게이트는 0건을 이미 허용한다(check_brief 주석) — 압력이 있다면 구조가 아니라 orchestrator 습관에 있을 수 있다.
- OQ6: 이 인터뷰의 웹 근거 중 5건(Nemeth 2001, Schweiger 1986, Schwenk 1989, Lord 1984, Schweiger 1988)은 출판사 403 으로 검색 스니펫의 초록만 확인됐다.

## 4. External Landscape

- 양측 케이스를 함께 세우는 dialectical inquiry 가 devil's advocacy 보다 표면화된 가정의 질을 높였고, 두 방식 모두 합의보다 참여자 만족은 낮았다 «schweiger-1986» — [취함] — seed 의 「양쪽 케이스, 같은 기준」이 이 형식이며, 사용자가 느낀 「흔들림」이 이 방식의 알려진 비용과 일치한다.
- 종단 연구에서는 dialectical inquiry 와 devil's advocacy 사이에 차이가 없었고, 메타분석의 견고한 결론은 「구조화된 갈등 > 무갈등」이다 «schwenk-1989» — [중립] — 문헌은 한 저자 대 두 저자를 강하게 판별하지 않는다.
- crux 는 「그것을 다르게 믿으면 결론이 바뀌는 사실」이고 논쟁은 crux 를 찾은 뒤에만 한다. 다만 crux 를 찾는 절차는 못 박히지 않았다 «double-crux» — [취함] — seed 의 「핵심 전제 충돌만이 열쇠」와 같은 개념이며, 전제 추출이 약한 고리라는 경고도 함께 취한다(OQ2).
- 독립된 두 옹호자의 대칭 토론이 단일 consultant 보다 판정 정확도를 높였고, consultant 를 설득력으로 최적화하면 틀린 쪽이 더 빨리 좋아진다. 한 모델이 양쪽을 쓰는 조건은 실험되지 않았다 «khan-2024» — [중립] — 현 설계(한 편 배정 옹호자)가 열세 조건 consultancy 와 동형이라는 점은 취하고, 두 옹호자로의 전환은 ST1 에서 보완으로 판정했다.
- 역할로 배정된 반대자는 원안의 cognitive bolstering 을 낳고, 진짜 반대만이 발산적 사고를 자극한다 «nemeth-2001» — [취함] — 원안 옹호까지 맡은 builder 가 「원안 강화」로 미끄러지는 위험의 이름. premise_list_challenge 필수화와 대안 케이스 선행 순서가 그 완화책이다.
- 자기-생성 반론보다 교차-출처 반론이 답 뒤집기를 더 유발한다 — 도전의 힘은 도전자가 결론 형성자와 같은 컨텍스트인가에서 크게 갈린다 «who-flips-2026» — [취함] — 빠진 전제 P0 의 근거. orchestrator 가 인라인으로 양쪽을 쓰는 축약 경로를 막는다.
- 구조화된 역할 없는 동종 모델 다중 토론은 더 많은 토큰으로 같거나 낮은 정확도를 냈고 실패 기제는 sycophantic conformity 였다 «cost-of-consensus-2026» — [취함] — 같은 모델 사본 둘을 양편에 세우는 대안이 사용자 불만의 핵심(오염)을 늘릴 수 있다는 직접 근거. 소형 모델 결과라 외삽 주의.
- 단일 판단자에게 반대 가능성을 스스로 생성하게 하는 consider-the-opposite 가 「공정하라」 지시보다 교정 효과가 컸다 «lord-1984» — [취함] — 한 컨텍스트가 양쪽을 쓰는 형식이 편향 교정으로 작동한 선례. 대안 케이스 선행 순서의 근거이나 외삽이다(OQ3).
- 사용자 견해와의 일치가 인간 선호의 가장 예측력 있는 특징이며 여러 프로덕션 모델에 공통이다 «sycophancy-2023» — [취함] — goal 문장을 그대로 넘기면 builder 가 그에 맞는 답으로 기울 수 있다는 위험(OQ1).
- 외부 피드백 없는 자기 검증·자기 교정은 추론 과제에서 우연 수준에 가깝다 «self-correct-2023» — [취함] — touches·hits 자기 라벨을 그대로 믿지 않고 양성만 orchestrator 가 확인하는 결정(C4)의 근거.
- 중간 옵션은 위치만으로 선택 확률이 불균형하게 오른다 «compromise-effect» — [취함] — 「보완」이 기본 착지점이 되는 위험. refined 항목의 취함/버림 필수와 선택지 순서 고정·추천 비승격(C11)이 대응.
- 측정이 목표가 되면 측정이 죽는다는 다중 에이전트 규정 준수 관측 «goodhart-multiagent-2026» — [취함] — 필수 필드 touches 가 「채워야 통과하는 칸」이 되는 위험과 sentinel 제조 위험(OQ5)의 이름.

## 5. 기각 · Blind Spots

- 기각 — 두 대칭 옹호자(원안 편·대안 편)로 builder 를 나누고 판정은 제3자가 하는 대안 → 사람 판정 보완(기계 어휘 부재로 defended 기록): 원안의 축은 유지하되 P0 명시·goal 리터럴·대안 케이스 선행 셋을 더한다. 두 옹호자 설계는 Khan 의 이득 조건(blind judge·교차 반박)이 R3 에 없고 동종 다중 토론이 오염을 늘린다는 근거가 사용자 불만의 핵심을 친다 — verdict: defended — ST1
- 기각 — seed 의 「premise_refutation 을 첫 필드로」 → 재결정: 대안 케이스 → 원안 케이스 → 전제 반증 판정 → 추천 순. 근거: 9-02 adjudication 인터뷰가 앵커링 해악을 「선행 판정·점수 노출」로 실측해 좁혔고, 첫 필드의 「none」이 봉쇄 도장으로 작동할 위험(prober FM3). 원래/재결정/근거 세 칸 기록 ⟨S8⟩
- 기각 — seed 의 「builder 리포 주장에 file:line 요구」 → 재결정: 경로 + 앵커(심볼·헤딩·원문 인용) 필수, 줄번호 보조. 근거: 직전 커밋 cb0b4dd 가 같은 리포에서 줄번호 인용 28건을 다섯 번 재발 뒤 전부 앵커로 옮겼고, ST1 의 builder 가 앵커로 7/7 을 검증 가능하게 냈다 ⟨S10⟩
- 기각 — orchestrator 추천 「refined 토큰 하나만 추가, 나머지 토큰 유지」 → 사용자가 전면 개명(kept/refined/switched/deferred)을 택했다. 비용(픽스처 10건·과거 brief 원장)은 사용자가 알고 감수 ⟨S11⟩
- 기각 — 「보완을 defended 에 흡수하고 산문으로만 구별」 → seed 가 닫은 선택지: 보완이 유지 안에 숨으면 원장에서 구별이 안 된다 ⟨S1⟩
- 기각 — 「skepticism 은 steelman 1회 필수로 닫힌다」(현행 사실상의 계약) → 기록 sentinel. 닫는 길이 판정뿐이면 trigger 제조 압력이 구조에서 나온다는 것이 orchestrator 의 논거였고(표본 7개 인터뷰 중 0회로 닫힌 것은 없었다 — 수치는 OQ5), 사용자가 sentinel 을 택했다 ⟨S9⟩
- 기각 — 「builder 추천을 Recommended 라벨로 첫 선택지에」 → 나란히 표시·순서 고정. compromise effect 와 앵커링 재현을 피한다 ⟨S12⟩
- 기각 — ✎ orchestrator 가 round 2 에서 낸 선택지 ②「dispatch 전 사용자 확인 라운드」·③「R1 종료 시 전제 항목 박제」(선택지 원문은 audit §5 프로세스 로그 round 2) → 사용자가 ①「도출 + 게이트 노출」을 택했다 ⟨S3⟩. orchestrator 의 기각 이유: 전자는 매 steelman 마다 라운드가 늘고, 후자는 R1 이 이미 하는 일의 중복
- 기각 — ✎ orchestrator 가 round 4 에서 「버린 것」으로 제시한 「check_brief 가 전제 부착을 기계 검사」(사용자 선택지에는 없었다; audit §5 round 4) → 사용자는 ①「양성만 orchestrator 확인」을 택했다 ⟨S5⟩. orchestrator 의 기각 이유: 전제와 근거의 충돌은 의미 판단이라 기계는 필드 존재만 보고, 그것은 문구만 있으면 GREEN 인 헤더-satisfiable 락이 된다
- 기각 — 「비부착 근거는 audit 에만」 → 노출+보존+계수. CLAUDE.md 처분 규범(사람 소비자면 라벨 붙여 노출)과 역방향이었다 ⟨S6⟩
- 기각 — ✎ orchestrator 가 round 5 에서 낸 선택지 ②「아니다 — 전제 부착 외에 양·밀도를 누르는 축 하나 더」(audit §5 round 5) → 사용자가 ①「괜찮다」를 택했다 ⟨S7⟩. orchestrator 의 기각 이유: 전제를 치는 근거 더미는 정당한 재검토 사유이고, 줄이려면 상한이나 티어링이 필요하며 둘 다 기각됐다
- 기각 — 「orchestrator 가 인라인으로 양쪽 케이스를 쓴다」는 축약 경로 → P0 로 봉쇄. 교차-출처 반론이 자기-생성 반론보다 강하다는 근거 ⟨S4⟩
- 기각 — 제약을 「요지」로 builder 에 전달(seed·C23 원안) → 재결정: user_statements 원문 인용. 근거: tools/adjudication/check_slots.py 가 orchestrator 산문 종합을 금지 kind(orchestrator_framing)로 잠그고 면제 수를 baseline 4 로 재는데 요지는 그 부류이고, 원문 인용은 kind=artifact 다. prober FM4 도 함께 닫힌다 ⟨S15⟩
- 기각 — 「steelman 0건이면 기록 항목 없이 통과」(현행 check_brief T12) → 기록 항목 요구. 근거: 원장 행 검사는 형식만 보므로 검토 흔적이 남지 않고, R3 의 「un-challenged 의심 방향은 확정 후보가 될 수 없다」에 증거가 없다 ⟨S16⟩
- 위험 — 숨은 가정: P0 분리(방향을 형성한 턴과 다른 dispatch 컨텍스트)가 독립을 보장한다 — 도구와 컨텍스트는 나뉘어도 전제·goal·제약의 프레임은 방향을 만든 턴이 저술하며, goal 문장 일치로의 sycophancy 가 겹친다. premise_list_challenge 가 상쇄 장치지만 그것도 같은 프롬프트 안의 자기 채점이다 — 근거 «sycophancy-2023»·리포 실패 클래스 「공유된 전제는 리뷰어를 눈멀게 한다」(OQ1)
- 위험 — 숨은 가정: 한 builder 가 양쪽을 쓰면 대칭이 된다 — 양쪽이 다 「역할」이 되면 대안 케이스는 점검용 형식으로, 원안 케이스는 확증으로 읽힌다. 형식의 대칭이지 수용의 대칭이 아니다 — 근거 «nemeth-2001»
- 위험 — 숨은 가정: 핵심 전제를 R1 에서 신뢰성 있게 도출할 수 있다 — 표본에서 결정 축 교체·전제 절반 오류·리포 사실 반증 사례가 있다. 전제 목록은 쓴 사람의 상상력 경계를 물려받는다. 대응: premise_list_challenge 필수 + 게이트 노출(OQ2)
- 위험 — 실패 양식: touches 필수 필드가 「채워야 통과하는 칸」이 되어 모든 근거에 전제 하나가 붙고 필터가 아무것도 걸러내지 않는다 — 대응: 양성만 orchestrator 확인(C4), 음성 오류는 사용자 게이트가 받친다 — 근거 «self-correct-2023»·«goodhart-multiagent-2026»
- 위험 — 실패 양식: 결과를 치는 반증(전제는 그대로 두고 순서·비용이 틀렸다는 것)이 「비부착」으로 분류돼 추천에서 빠진다 — 대응: 라벨 노출(C5)과 사용자 게이트 선택지 무제한. 리포 실례 9-02 seam ST1 (OQ4)
- 위험 — 실패 양식: 「보완」이 중간 착지점이 되어 유지·전환이 줄고 버려진 절반이 R4 기각에서 사라진다 — 대응(확정): 선택지 순서 고정·추천 비승격(C11). 대응 후보(미확정, §2 ✎ ⓐ): refined 항목 취함/버림 구절 — 근거 «compromise-effect»
- 위험 — 실패 양식: skepticism 을 닫기 위해 trigger 가 제조된다 — 대응: 기록 sentinel(C8). 남는 위험은 sentinel 제조(OQ5). 방향성 리뷰(D5)는 이 전제 자체(0건이 막힌다)가 현 check_brief 와 어긋난다고 지적 — Step B 에서 사용자 결정
- 위험 — 실패 양식: 제약 「요지」 전달이 조건부 발화를 무조건 제약으로 굳혀 열린 경로까지 닫는다 — 대응(확정, C23·⟨S15⟩): 제약을 user_statements 원문 인용으로 넘긴다
- 위험 — 실패 양식: repo_claims 사전 확인(C24)이 「확인했다」 한 줄로 형해화된다 — 대응 후보(미확정, §2 ✎ ⓒ): 확인 결과를 audit §3 ST 블록에 주장별로 남기고 반증은 4-block 에 라벨로 노출. 기계 검사는 형식만 볼 수 있다
- 위험 — 실패 양식: 페르소나에서 「원안의 옹호자 아님」을 제거하는 변경이 락(test_steelman_builder_scope.sh 의 verbatim·약화금지 문구)과 충돌하거나, 락을 맞추려 문구만 남기고 의미를 뒤집는 이중 상태가 생긴다. verbatim 의 대상(alternative_statement+evidence → 양측 케이스 전체)을 락과 SKILL 이 같은 답으로 갖게 해야 한다
- 위험 — 실패 양식: R3 블록에 「coverage-mapper neglect」 문구 존재를 GREEN 조건으로 잠근 락(test_conducting_interview_stage.sh)이 있어 trigger 제거가 그대로 RED — 부재 락으로 반전하고 양성 짝을 둔다
- 위험 — 실패 양식: check_brief 의 verdict 어휘와 결합된 표면 — 템플릿 §5 예시 줄, test_check_brief.sh 의 sed 변이, verdict 픽스처 10건, bijection A — 전면 개명 시 한 곳만 고치면 게이트가 조용히 빈 문자열을 읽고 통과한다

## 6. 사용자 원문

- **S1** 🗣 최초 요청 (Phase 0 이 만든 interview-seed 전문, frontmatter 포함):
  > ---
  > type: interview-seed
  > next_phase: spec-distill:interview
  > audit_file: 2026-09-05-steelman-goal-fit-interview.audit.md
  > ---
  > spec-distill 인터뷰의 R3 steelman 흐름을 고친다. 목적을 「원안 뒤집기」에서 「사용자 goal 에 가장 적합한 방향 찾기」로 바꾼다.
  >
  > **사용자가 본 문제.** 현재 방식은 대안을 억지로 강하게 만들고, 관련성이 약한 외부 컨텍스트까지 가져와 기존 결정을 필요 이상으로 흔든다. 불만은 오염과 흔들림이지 탐색 비용이 아니다.
  >
  > **orchestrator 진단 (Phase 0 표본 판독, 사용자 동의).** 과거 인터뷰 8건의 steelman 을 다시 세면 기록은 switched 6 · defended 2 인데 실질은 전환 3 · 보완 3 · 유지 1 · 불명 1 이다 — 「보완」 판정이 없어 3건이 양극단으로 기록됐다. 2건에서 builder 가 리포 사실을 틀리거나 사용자가 이미 닫은 경로를 대안으로 냈고, 그것을 잡은 것은 계약에 없는 orchestrator 의 사후 검증이었다. 사용자가 지목한 표본(brief-restructure ST1)엔 특정 논문 9건이 붙어 있었다. 편향은 산문이 아니라 스키마에 있다 — builder 출력이 대안 쪽만 담고, 게이트 선택지가 방어/전환/보류다.
  >
  > **사용자가 확정한 방향.**
  >
  > - 범위는 steelman-builder 페르소나 + conducting-interview R3 게이트 + check_brief.py. brief 리뷰 단계의 brief-direction-reviewer 는 이번 범위 밖이다.
  > - 재검토를 여는 열쇠는 하나다: 새 근거가 원안의 **핵심 전제**와 직접 충돌할 때. 그 외의 근거는 원안을 강화하거나 경계를 다듬는 데 쓴다. 핵심 전제는 R1 이 재구성한 문제정의·goal 에서 오고, dispatch 시점에 orchestrator 가 **사용자가 그때까지 말한 제약의 요지와 함께** builder 입력으로 명시해 넘긴다 — 표본에서 builder 가 이미 닫힌 경로를 대안으로 낸 원인이 제약을 몰랐던 것이라, 사용자가 이 전달을 별도로 확정했다.
  > - builder 는 원안과 대안 **양쪽**의 최강 케이스를 같은 기준(사용자 goal)으로 쓰고, 첫 필드에 「이것이 확정 방향의 핵심 전제에 대한 반증인가」를 답한 뒤 유지/보완/전환 추천을 낸다. 게이트 선택은 기존대로 사용자가 한다.
  > - builder 에게 「전제 목록 자체가 틀렸다」는 발견을 허용한다. orchestrator 가 든 이유: 결정 축 자체를 바꾼 사례가 있었고, 이것을 막으면 전제 목록이 원안 저자의 상상력을 물려받는다. 이 권한은 아래 「seed 자체의 문턱」을 상쇄하는 장치이기도 하다.
  > - 판정 어휘는 유지 / 보완 / 전환 / 보류 넷. 보완이 신설이고, 방어→유지는 개명이다. 보류는 builder 추천엔 없고 게이트에서 사람만 고르는 값이다. 보완이 유지 안에 숨으면 원장에서 구별이 안 된다.
  > - 약하거나 무관한 반론의 봉쇄 기준: 근거가 어느 핵심 전제에 부딪히는지 명시하지 못하면 재검토 사유가 아니다. confidence 임계는 올리지 않는다.
  > - 「확정된 방향」은 사용자가 인터뷰에서 실제로 답한 것과 seed 의 내용이다. 종료 게이트의 confirmed 가 아니다 — 그러면 인터뷰 중에는 봉쇄가 작동하지 않는다.
  > - 추가로 둘: builder 의 리포 주장에 file:line 을 요구하고 orchestrator 가 게이트 **전에** 확인하는 단계를 R3 에 넣는다. R3 trigger 중 coverage-mapper neglect 는 뺀다 — 커버리지 공백은 전제 충돌이 아니라 probe 질문으로 갈 일이다.
  >
  > **orchestrator 가 위임받아 정한 것 (사용자: "직접 고민해줘").** 외부 근거의 개수 상한과 출처 티어링은 쓰지 않는다 — 상한은 이 리포가 의도적으로 뺀 것이고, 티어링은 과거 인터뷰에서 사용자가 한 번 기각했다. 억제는 「전제에 닿는가」 하나로 한다.
  >
  > **경계.** 이 봉쇄가 Sealed decision 이 되면 안 된다 — 열쇠는 「확정됐으니까」가 아니라 「핵심 전제 충돌」만이다. 반대로 원안 옹호로 기울면 steelman 이 존재하는 이유를 잃는다 — 대칭(같은 기준, 양쪽 케이스)이 핵심이다. 이 seed 는 확정 항목이 많아 다음 인터뷰의 R3 가 이 설계 자체를 겨눌 때 문턱이 높게 시작한다 — 그것을 알고 넘긴다.
  >
  > **인터뷰가 정할 것 (Phase 0 이 닫지 않았다).** 전제에 닿지 않는 근거의 처분 — 사람 소비자에게 라벨을 붙여 보여줄지, audit 에만 남길지, 회계상 소실·흡수·공시 중 무엇인지. 「전제 부착」을 builder 가 자칭하면 통과하는지, orchestrator 가 file:line 처럼 게이트 전에 확인하는지. skepticism 차원이 의심 trigger 없이 어떻게 닫히는지, trigger 를 억지로 만들어 차원을 닫는 압력이 있는지.

## 7. Next Action

superpowers 가 있으면 이 brief 를 context 로 `superpowers:brainstorming` 을 호출해 `-design.md` 를 만들고, reviewer 검증 뒤 writing-plans 로 간다. 설계는 세 파일(steelman-builder 페르소나 · conducting-interview R3 절 · check_brief.py)과 그에 결합된 락·픽스처·템플릿을 함께 다룬다. §5 의 위험 항목 중 「대응」이 적힌 것은 설계에 그 대응을 실어야 하고, OQ 6건은 유추로 닫지 않는다. superpowers 가 없으면 이 brief 가 완결 산출물이다.
