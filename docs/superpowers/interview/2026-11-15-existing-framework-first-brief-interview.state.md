---
type: interview-state
seed: docs/superpowers/interview/2026-11-15-existing-framework-first-interview.md
session_id: 35da5fc5-5b17-4b82-9b35-92c29a78d217
phase: 1
coverage:
  floor:
    root_problem:   {status: closed, evidence: "S1 · S2 — 사용자 원문과 원인 넷의 선택", reopened: 0, reopen_log: []}
    landscape:      {status: closed, evidence: "S4 · S5 · S6 — 외부 근거의 처분(검증 기준은 정보로 · 실험 기능은 보이고 고른다 · 반론 검토 보완)", reopened: 0, reopen_log: []}
    skepticism:     {status: closed, evidence: "S6 — ST1 보완", reopened: 0, reopen_log: []}
    blind_spot:     {status: closed, evidence: "S8 — 숨은 가정 · 실패 양식의 처분(승인이 도장이 됨 · 틀린 후보 · 구현에서 다시 만듦을 설계 필수로)", reopened: 0, reopen_log: []}
    open_questions: {status: closed, evidence: "S14 — 열린 질문 넷(OQ7 · OQ8 · OQ10 · OQ13)을 설계로 넘긴다(S12 · S13 으로 OQ9 · OQ11 을 닫은 뒤)", reopened: 1, reopen_log: [{round: 5, reason: "조사 10 이 Phase 0 선택지의 설명이 audit 에 없음을 보였고 본체가 이 세션 전사에서 「새로 들일 때만」의 설명을 되찾아 OQ9 가 이미 답이 걸린 결정임을 확인했다. 포화 판정이 OQ11 을 새로 열었다", conflicts_with: S11}]}
  derived:
    - {name: internal_research, rationale: "조사가 레포 주장을 처음 산출했다(조사 1~5)", status: closed, evidence: "S2 — 레포 주장의 처분", reopened: 0, reopen_log: []}
    - {name: rule_carrier, rationale: "규칙의 운반 자리 — 다른 레포 도달 · 외부 소유 단계 · 인터뷰를 거치지 않는 일(coverage-mapper 제안 1)", status: closed, evidence: "S3 — 단계 안에서만", reopened: 0, reopen_log: []}
    - {name: conclusion_judge, rationale: "결론을 판정하는 쪽과 효과 관측 — 「직접 만들 이유」를 작성자 아닌 누가 읽고, 형식이 아님을 무엇으로 아는가(coverage-mapper 제안 2 · 7 을 합침)", status: closed, evidence: "S2 · S6 — 결론을 읽는 눈이 없었다는 원인 선택과 보완 d", reopened: 0, reopen_log: []}
    - {name: fit_judgment, rationale: "「맞는」 판정과 부분 적합, 범주마다 다른 검증 기준의 뜻(coverage-mapper 제안 3 · 5 를 합침)", status: closed, evidence: "S4 · S6 — 기준은 보여 주는 정보, 후보마다 맞음 판정을 적는다(보완 a)", reopened: 0, reopen_log: []}
    - {name: adoption_cost_asymmetry, rationale: "채택 비용의 비대칭 — 외부 것에만 붙는 승인 · 의존 기록 · 없을 때 동작(coverage-mapper 제안 4)", status: closed, evidence: "S2 · S6 — 만드는 쪽이 쉬운 길이었다는 원인 선택과 보완 b", reopened: 0, reopen_log: []}
    - {name: touch_trigger, rationale: "「고칠 때 함께 본다」의 발동 지점과 크기 하한(coverage-mapper 제안 6)", status: closed, evidence: "S9 — 설계를 거치는 고침만", reopened: 0, reopen_log: []}
orchestration:
  focused_dimension: null
  research_dispatches: {coverage_mapper: 1, blind_spot_prober: 1, steelman_builder: 1, repo_researcher: 4, open_researcher: 5}
  research_limit: 60
  saturation_limit: 5
  research_log:
    - {n: 1, device: coverage-mapper, round: 1, batch: 1, changed: [OQ1, OQ6], opened: [OQ8, OQ9, OQ10], summary: "파생 차원 일곱 제안 · 원인 후보 둘(채택 비용 비대칭 · 결론을 읽는 리뷰 부재) · 플러그인 루트 CLAUDE.md 는 실리지 않음"}
    - {n: 2, device: repo-researcher, round: 1, batch: 1, changed: [OQ1, OQ6, OQ7], opened: [], summary: "있는 것 먼저 문장의 일곱 자리 · 실려 가는 자리 다섯 · 절 내용을 읽는 검사 없음 · 계획 단계에 요구 없음"}
    - {n: 3, device: repo-researcher, round: 1, batch: 1, changed: [OQ3, OQ6, OQ7], opened: [], summary: "과거 검토 기록 56건 · 있는 것 검토 절 12건의 결론 · D33 의 출처와 범위 · 사용자 제약 C5"}
    - {n: 4, device: open-researcher, round: 1, batch: 1, changed: [OQ1, OQ3], opened: [], summary: "플러그인이 규칙을 전달하는 공식 수단과 조건 · 실험 딱지를 붙이는 네 방식 · 레포 판 2.1.303 대 최신 2.1.325"}
    - {n: 5, device: open-researcher, round: 1, batch: 1, changed: [OQ2, OQ3, OQ4, OQ6, OQ7], opened: [], summary: "한쪽 승인 선례 · 들이는 쪽에만 건 승인이 직접 만들기로 몬 실무 보고 · 검증 기준의 결합 방식 · 실험 단계 다루기 · 에이전트 프레임워크 선례"}
    - {n: 6, device: blind-spot-prober, round: 1, batch: 2, changed: [OQ5, OQ7, OQ8, OQ9, OQ10], opened: [], summary: "숨은 가정 여덟 · 실패 양식 일곱 — 승인의 도장화 · 검증 셋은 대리 지표 · 후보의 실재 확인 · 설계는 채택 구현은 재구현 · 규칙이 닿지 않는 길 · 설치자에게 넘어가는 고장"}
    - {n: 7, device: steelman-builder, round: 1, batch: 2, changed: [OQ7, OQ8, OQ9], opened: [], summary: "ST1 — 추천 보완 · 전제 P2 충돌 · 빠진 전제(의존 쪽 비용) · 탐색 증거와 의존 쪽 이유를 원안에 붙이자는 안"}
    - {n: 8, device: open-researcher, round: 5, batch: 3, changed: [OQ8, OQ10], opened: [], summary: "과거 설계 셋의 일 열여섯에 설계 날짜 이전의 외부 후보가 있었고 문서에는 이름이 없다 · 후보마다 덮는 범위와 배포 조건에서 붙는 것"}
    - {n: 9, device: repo-researcher, round: 5, batch: 3, changed: [OQ8, OQ10], opened: [OQ13], summary: "설계문서 리뷰의 웹 대조는 1.0.0 에서 꺼졌고 이유는 한 줄뿐이며 다시 열 질문이 열린 채 남아 있다 · 웹 사본은 이미 있고 여는 데 드는 것"}
    - {n: 10, device: repo-researcher, round: 5, batch: 3, changed: [OQ9, OQ7], opened: [], summary: "기본 기능 · 이미 쓰던 것의 사용을 물은 기록은 묶음 승인 한 줄뿐 · 새 패키지는 하나씩 물음 · Phase 0 선택지 설명은 audit 에 없음"}
    - {n: 11, device: open-researcher, round: 5, batch: 3, changed: [OQ10, OQ11], opened: [], summary: "관측점 선례 여섯 갈래와 각 왜곡 · 사용자가 측정 장치를 걷어내거나 따로 재지 않기로 한 전례 둘"}
    - {n: 12, device: open-researcher, round: 5, batch: 3, changed: [OQ7, OQ11], opened: [], summary: "상류 설계 skill 은 7.0.1 부터 대안과 추천을 내놓되 방향은 정하지 않는다 · 구현과 리뷰 점검 목록에 고른 것을 썼는가가 없다"}
  saturation_log:
    - {k: 1, round: 4, verdict: not_saturated, basis: "묶음 2(조사 6 · 7)가 열린 결정 넷을 모두 바꿨고 새 결정 둘을 열었다", gaps: ["confirm · open-researcher · may_change OQ7 OQ8 OQ10 — 보완안 a · b 를 과거 설계에 소급 적용", "explore · repo-researcher · may_change OQ8 OQ10 — 설계문서 리뷰 프로필의 web false 고정 이유", "explore · repo-researcher · may_change OQ9 OQ7 — 기본 기능 · 이미 적힌 의존의 승인 선례", "explore · open-researcher · may_change OQ10 — 형식이 아님의 관측점 후보", "explore · open-researcher · may_change OQ7 — 설계 · 계획 단계에서 기본값이 닿는 자리"], user_choice: null}
    - {k: 2, round: 5, verdict: not_saturated, basis: "묶음 3(조사 8~12)이 열린 결정 넷을 모두 건드렸고 OQ13 은 한 블록만 받친다", gaps: ["confirm · repo-researcher · may_change OQ13 OQ8 — 웹이 켜진 brief 리뷰가 외부 대안 지적을 실제로 냈는지", "confirm · steelman-builder · may_change OQ13 — 웹 대조를 다시 여는 것의 반대편 논거", "explore · repo-researcher · may_change OQ8 OQ10 — 내장 후보를 설계 요구 문장과 맞대어 맞았을지 가르기(판정 1 의 둘째 빈 곳과 같은 결정 · 같은 장치)", "explore · orchestrator · may_change OQ7 — 7.0.2 의 대안 · 추천 걸음에서 넘김 줄이 추천 방향을 움직이는지 실행 관찰", "explore · repo-researcher · may_change OQ10 — plugin-audit 축 4 의 실적", "confirm · orchestrator · may_change OQ9 — 재개 사유 문장을 원문과 맞추기"], user_choice: S15}
  open_decisions:
    - id: OQ1
      text: "devbrew 플러그인을 쓰는 어느 레포에서든 통하려면 규칙이 어디에 살아야 하는가"
      dimension: rule_carrier
      status: resolved
      resolved_by: S3
    - id: OQ2
      text: "검증 기준 셋(공식 제공 · 널리 쓰임 · 유지 중)을 모두 넘어야 하는가 하나만 넘어도 되는가"
      dimension: open_questions
      status: resolved
      resolved_by: S4
    - id: OQ3
      text: "실험 딱지가 붙은 기능을 기반으로 쓸 수 있는가 — 예전 로드맵의 「실험 기능은 기반으로 쓰지 않는다」와의 관계"
      dimension: skepticism
      status: resolved
      resolved_by: S5
    - id: OQ4
      text: "에이전트 조율용 프레임워크는 대상에서 빼는가 그저 고르지 않았을 뿐인가"
      dimension: open_questions
      status: resolved
      resolved_by: S10
    - id: OQ5
      text: "「고칠 때 크기와 상관없이 함께 본다」가 오타 수정 같은 사소한 변경에도 걸리는가"
      dimension: touch_trigger
      status: resolved
      resolved_by: S9
    - id: OQ6
      text: "있는 것 검토가 형식에 그친 원인은 무엇이고 무엇이 결론을 실제로 바꾸는가"
      dimension: root_problem
      status: resolved
      resolved_by: S2
    - id: OQ7
      text: "프레임워크를 쓸 때도 직접 만들 때도 승인이 필요하면 「쓰는 것이 기본」은 실제 흐름에서 무엇을 바꾸는가"
      dimension: adoption_cost_asymmetry
      status: open
      resolved_by: null
    - id: OQ8
      text: "「맞는 프레임워크」에서 맞는지를 누가 무엇으로 판정하는가"
      dimension: fit_judgment
      status: open
      resolved_by: null
    - id: OQ9
      text: "Claude Code 기본 기능과 이미 의존으로 적힌 것도 쓸 때마다 승인받는 「외부 것」인가"
      dimension: adoption_cost_asymmetry
      status: resolved
      resolved_by: S12
    - id: OQ10
      text: "검토가 형식이 아니게 됐는지를 무엇으로 아는가"
      dimension: conclusion_judge
      status: open
      resolved_by: null
    - id: OQ11
      text: "구현 · 최종 리뷰에서 「고른 프레임워크를 실제로 썼는가」를 보는 자리를 이번 범위에 넣는가"
      dimension: conclusion_judge
      status: resolved
      resolved_by: S13
    - id: OQ12
      text: "직접 만들 「정당한 이유」의 종류를 정하고 부분 채택을 「쓰는 것」으로 세는가"
      dimension: adoption_cost_asymmetry
      status: open
      resolved_by: null
    - id: OQ13
      text: "설계문서 리뷰에 웹 대조(빠진 외부 후보 찾기)를 다시 여는가"
      dimension: conclusion_judge
      status: open
      resolved_by: null
    - id: OQ14
      text: "규칙을 얹을 상류 설계 skill 의 대안 · 추천 걸음이 레포가 적은 판(7.0.0)에 없다 — 기준 판을 올리는가 판에 매이지 않는 문장으로 쓰는가"
      dimension: rule_carrier
      status: open
      resolved_by: null
    - id: OQ15
      text: "같은 일을 하는 공개 skill 을 그대로 쓰는가 판정 틀만 빌리는가 직접 쓰는가"
      dimension: landscape
      status: open
      resolved_by: null
    - id: OQ16
      text: "돌고 있는 지휘자 맥락 경제 로드맵과 고칠 파일이 겹친다 — 두 일의 순서를 어떻게 두는가"
      dimension: rule_carrier
      status: open
      resolved_by: null
trivia_escape_armed: false
user_statements:
  - id: S2
    source: chosen
    round: 1
    text: "만드는 쪽이 쉬운 길, 결론을 읽는 눈이 없음, 바깥을 안 찾음, 레포 규칙에 막힘 — 검토가 형식에 그친 원인 후보 넷을 모두 골랐다(외부 것을 쓰면 승인 · 의존 기록 · 공시가 붙고 직접 만들면 아무것도 안 붙었다 / 검토 절은 쓰기만 하고 결론을 따지는 리뷰 항목 · 검사가 없었다 / 레포 밖 칸이 후보 이름 없이 「쓰지 않는다」 한 줄이었다 / 쓸 만한 것이 있어도 레포 자신의 규칙 때문에 「맞지 않는다」로 끝났다)"
  - id: S3
    source: chosen
    round: 1
    text: "단계 안에서만 (권장) — devbrew 규칙 문서와 spec-distill 의 인터뷰 · 설계 · 계획 넘김 글만 고친다. 새 장치는 없고, 이 흐름을 타지 않는 일(사소한 수정 등)에는 규칙이 닿지 않는다"
  - id: S4
    source: chosen
    round: 1
    text: "보여 주는 정보로 (권장) — 검증 기준 셋을 문턱으로 쓰지 않는다. 후보마다 셋의 상태를 보이고 승인 때 판단한다"
  - id: S5
    source: chosen
    round: 1
    text: "보이고 고른다 (권장) — 실험 딱지 기능도 후보에 올리되 딱지와 알려진 한계를 함께 보이고 승인 때 고른다. 지난 로드맵의 결정은 그 로드맵에만 남는다"
  - id: S6
    source: chosen
    round: 2
    text: "보완 (builder·orchestrator 추천) — 원안의 뼈대는 그대로 두고 탐색 증거, 의존 쪽 비용을 정당한 이유로 인정하는 것, 읽는 눈이 있는 자리에 규칙을 두는 것을 붙인다. 검증 기준과 실험 기능 부분은 다음 질문에서 따로 묻는다"
  - id: S7
    source: chosen
    round: 3
    text: "방금 답대로 (권장) — 검증 기준은 문턱이 아니라 보여 주는 정보로 두고, 실험 기능은 딱지와 한계를 보이고 승인 때 고른다. 「안정 단계(실험 딱지 여부)」를 후보마다 보이는 정보에 한 칸 더한다"
  - id: S8
    source: chosen
    round: 3
    text: "승인이 도장이 됨 (권장), 틀린 후보가 올라옴 (권장), 구현에서 다시 만듦 (권장) — 설계가 반드시 다뤄야 할 실패 양식으로 셋을 골랐다(「과하게 들임 · 고장 전가」는 고르지 않았다)"
  - id: S9
    source: chosen
    round: 3
    text: "설계를 거치는 고침만 (권장) — 인터뷰 · 설계를 타는 고침에서는 크기와 상관없이 함께 본다. 오타 같은 사소한 변경은 지금처럼 그냥 고친다. 작은 고침으로 직접 만들기가 새는 길은 남는다"
  - id: S10
    source: chosen
    round: 3
    text: "따로 가르지 않는다 (권장) — 에이전트 조율용 프레임워크를 빼는 규칙도 넣는 규칙도 두지 않는다. 조율용도 다른 후보와 같은 길(후보로 보이고 승인)을 탄다"
  - id: S11
    source: chosen
    round: 4
    text: "넷 다 설계로 (권장) — 열린 결정 넷(두 승인이 있을 때 「기본」이 바꾸는 것 · 「맞는」을 누가 무엇으로 판정하는가 · Claude Code 기본 기능과 이미 적힌 의존도 쓸 때마다 승인받는가 · 형식이 아니게 됐는지를 무엇으로 아는가)을 조사 재료와 함께 brief 의 열린 질문으로 싣는다"
  - id: S12
    source: chosen
    round: 5
    text: "묶어서 한 번 (권장) — 설계마다 그 설계가 기대는 Claude Code 기본 기능과 이미 적힌 의존을 이름으로 모아 한 번에 승인받는다. 새로 들이는 것은 하나씩 승인받는다"
  - id: S13
    source: chosen
    round: 5
    text: "넣는다 (권장) — 계획 · 구현으로 넘기는 글이 마지막 리뷰에서 「설계가 고른 것을 실제로 썼는가」를 보게 하는 것까지 이번 범위에 든다. 확인한 범위를 계획 뒤로 한 걸음 넓힌다"
  - id: S14
    source: chosen
    round: 5
    text: "넷 다 설계로 (권장) — 남은 열린 결정 넷(두 승인이 있을 때 「기본」이 바꾸는 것 · 「맞는」을 누가 무엇으로 판정하는가 · 형식이 아니게 됐는지를 무엇으로 아는가 · 설계문서 리뷰에 웹 대조를 다시 여는가)을 brief 의 열린 질문으로 싣는다. 웹 대조를 다시 여는 일은 설계가 비용과 함께 정한다"
  - id: S15
    source: chosen
    round: 6
    text: "포화로 보고 종료 (권장) — 조사가 충분하다고 보고 brief 작성으로 간다. 열린 질문 다섯(새로 짚인 「기준 판」 포함)과 조사 재료가 설계로 넘어간다"
  - id: S16
    source: chosen
    round: 6
    text: "spec 하나로 (권장) — 지금처럼 brief 하나를 brainstorming 하나로 넘긴다. 로드맵을 만들지 않는다"
  - id: S17
    source: chosen
    round: 7
    text: "고친다 — 목표 밖에서 뺀다 (권장) — 그 줄을 빼고, 과거에 측정 장치를 걷어낸 두 결정은 열린 질문의 재료로만 둔다. 재는 방법은 설계가 정한다(지적 2c0abd98#r1.1)"
  - id: S18
    source: chosen
    round: 7
    text: "고친다 — 후보별로 구체일 때만 (권장) — 이유는 그 후보에 대해 구체로 적을 때만 선다(누구 환경에 어떤 의존이 생기고 없을 때 무엇이 깨지는가). 상시 규칙이나 앞 인터뷰의 「의존 회피」 확정을 인용하는 것만으로는 이유가 안 된다. 어제 로드맵의 그 확정은 그 로드맵에만 남는다고 적는다(지적 abf668a4#r1.1)"
  - id: S19
    source: chosen
    round: 7
    text: "고친다 — 리뷰 프로필도 자리에 (권장) — 규칙을 두는 자리 목록에 설계문서 리뷰 프로필을 넣는다. 새 장치가 아니라 있는 리뷰 문장의 수정이고, 리뷰어 프로필 편집이라 보안 리뷰가 붙는다. 웹 대조를 다시 여는지는 설계에 남는다(지적 abf668a4#r1.2)"
  - id: S20
    source: chosen
    round: 7
    text: "고친다 — 후보로 이름을 올린다 (권장) — 조사 목록에 그 skill 을 이름으로 올리고, 그대로 쓸지 · 판정 틀만 빌릴지 · 직접 쓸지를 설계가 탐색 증거와 함께 정하게 한다. 쓰기로 하면 그때 승인을 받는다(지적 b73addba#r1.1)"
  - id: S21
    source: chosen
    round: 8
    text: "고친다 — 안전 칸을 더한다 (권장) — 후보마다 보이는 정보에 한 칸을 더한다 — 그 후보가 무엇을 실행하고 무엇에 닿는가(훅 · 스크립트 · 네트워크 · 자격증명)와 알려진 보안 문제. 인기 지표에는 재는 단위(저장소 전체인지 그 skill 하나인지)를 함께 적는다. 이 칸도 문턱이 아니라 보이는 정보다(지적 abf668a4#r2.1)"
  - id: S22
    source: chosen
    round: 8
    text: "고친다 — 규칙을 나르는 장치만 (권장) — 「규칙을 나를 새 장치(세션 시작 훅 · 대상 레포 규칙 파일 쓰기)는 만들지 않는다」로 좁혀 목표 밖 줄과 같은 글자로 맞춘다. 그 밖의 새 것(재는 수단 · 리뷰 걸음 · 공개 skill 을 들이는 것)은 설계가 이유와 함께 제안할 수 있다(지적 eb353eb4#r2.1)"
  - id: S23
    source: chosen
    round: 9
    text: "고친다 — 위험과 열린 질문으로 싣는다 (권장) — 위험 한 줄(고칠 자리가 그 로드맵의 예약 경로와 겹치고 지휘 절차 개편 에픽이 같은 문서를 쪼갠다)과 열린 질문 한 줄(두 일의 순서 — 이 일을 먼저 / 그 에픽이 끝난 뒤 / 겹치는 파일의 몫을 그 에픽으로 넘긴다)을 싣는다. 순서는 설계가 정한다(지적 abf668a4#r3.1)"
  - id: S24
    source: chosen
    round: 9
    text: "열지 않음 (권장) — 리뷰를 여기서 닫고 다음 단계 질문으로 간다. 이번에 고치는 다섯 곳은 리뷰어가 다시 보지 않는다"
  - id: S25
    source: chosen
    round: 9
    text: "확정하고 /compact 후 brainstorming (권장) — 확정 후보를 확정으로 바꿔 저장하고, 붙여 넣을 두 줄(/compact 와 다음 세션 줄)을 보여 준다. 인터뷰 기록을 요약해 둔 채 brief 를 붙여 읽고 brainstorming 을 시작한다"
confirm_repost_count: 0
brief_review_degradations:
  - component: readback
    reason: 냉독 agent 가 파일을 열지 못했다(도구 없음) — 경로로 한 번 보냈고 전문을 인라인으로 다시 싣지 않았다
    affected_axis: readback
    verification_status: unavailable
---

## 풀린 입력

~~~~
---
type: interview-seed
next_phase: spec-distill:pm-interview
audit_file: 2026-11-15-existing-framework-first-interview.audit.md
---

구현보다 최대한 있는 프레임워크 사용, 직접 만드는거는 가능한 최소화하고 검증된 프레임워크 위에서 작업

이 요청은 devbrew 한 레포의 이야기가 아니라 이미 만든 것과 앞으로 만들 것 모두에, 그리고 devbrew 플러그인을 쓰는 어느 레포에서든 통해야 하는 일하는 방식이다. (사용자 확인)
규칙과 장치에 devbrew 전용 값이나 특정 프레임워크 이름을 박아 넣지 않는다. (사용자 확인)

계기는 넷이다 — 직접 만든 스크립트와 테스트의 유지 부담, 직접 만든 장치에서 되풀이되는 버그, 새 장치를 만드는 데 드는 시간, 그리고 있는 것을 먼저 보라는 규칙이 있는데도 직접 만드는 쪽으로 흘러 온 것. (사용자 확인)
규칙이 지켜지지 않은 모습은 devbrew 전반과 다른 프로젝트에서 모두 겪었고, 있는 것을 검토했다고 적기는 했지만 결론은 늘 직접 만들기였다. (사용자 확인)

맞는 프레임워크가 있으면 그 위에서 만드는 것이 기본이고, 직접 만들려면 이유를 대고 사용자 승인을 받는다. (사용자 확인)
외부 것은 지금처럼 후보와 차이를 보이고 사용자 승인을 받은 뒤에만 쓴다. (사용자 확인)

프레임워크는 Claude Code 기본 기능, 남이 만들어 유지하는 플러그인과 skill, 널리 쓰이는 일반 패키지와 도구를 가리키고, 에이전트 조율용 프레임워크는 고르지 않았다. (사용자 확인)
검증된 프레임워크는 만든 쪽이 공식으로 내는지, 널리 쓰이는지, 지금도 유지되는지 셋으로 가른다. (사용자 확인)

이번 일은 규칙 문장과 인터뷰, 설계, 계획 단계가 프레임워크를 먼저 고르게 바꾸는 데까지이고, 이미 만든 장치를 조사하거나 옮기는 일은 이번에 하지 않는다. (사용자 확인)
이미 만든 장치는 이번에 옮기지 않지만, 그것을 고치는 일이 열리면 크기와 상관없이 프레임워크로 옮길 수 있는지도 함께 본다. (사용자 확인)

다시 검증할 것 — 검토가 형식에 그친 원인은 묻지 않았다.
지금 규칙이 검토까지만 요구하고 결론의 기본값을 정하지 않아서라는 것은 Phase 0 의 추측이다.
검증 기준 셋을 모두 넘어야 하는지 하나만 넘어도 되는지는 묻지 않았다.
에이전트 조율용 프레임워크는 고르지 않았을 뿐이고, 쓰지 않겠다는 뜻인지는 묻지 않았다.
실험 딱지가 붙은 기능을 빼는 선택지는 고르지 않았는데, 예전 로드맵에서 실험 기능은 기반으로 쓰지 않는다고 정한 것을 바꾸는 뜻인지는 묻지 않았다.
외부 것을 쓸 때도 직접 만들 때도 승인이 필요하므로 어느 쪽이든 사용자가 고르게 된다는 것은 두 답을 이은 Phase 0 의 추론이다.
고칠 때 크기와 상관없이 함께 본다는 것이 오타 수정 같은 사소한 변경에도 걸리는지는 묻지 않았다.
어느 레포에서든 통하려면 규칙이 어디에 살아야 하는지는 정하지 않았고, 이 레포의 규칙 문서만 고치면 다른 레포에는 닿지 않는다.
~~~~

## seed 문장 분류 (seed_provenance.py classify)

- audit: ok · 사용자 확인 10 · 사용자 미확인 0 · 저자 9(첫 줄 요청 원문 1 + «다시 검증할 것» 문단 8)


### 조사 2 — repo-researcher · R1 · 묶음 1

레포 루트: /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first (아래 `path` 는 이 루트 기준 상대경로)

요약: 「있는 것 먼저」 요구 문장은 일곱 자리에 산다 — 레포에만 있는 둘(CLAUDE.md · 철학 문서)과 spec-distill 플러그인에 실려 가는 다섯(인터뷰 SKILL · brief 다음 세션 줄 · 에픽 넘김 줄 · 지휘 절차 · README 요약). 요구는 전부 「검토 + 바깥 것은 사용자 검토/승인」까지이고, 결론의 기본값(쓰는 쪽이 기본)을 정하는 문장은 찾지 못했다. 설계문서 `## 있는 것 검토` 절의 존재 · 내용을 검사하는 스크립트 · 리뷰어 항목은 없다. 계획 단계(writing-plans 줄 · 계획 agent 틀)에는 같은 요구가 없다.

```yaml
repo_claims:
  # ── (1) 실려 가는가 ─────────────────────────────────────────────
  - id: RC1
    path: ".claude-plugin/marketplace.json"
    anchor: "\"source\": \"./plugins/spec-distill\""
    line: 24
    claim: "마켓플레이스가 싣는 단위는 플러그인 넷의 `./plugins/<이름>` 폴더뿐이다(quality-gates · project-init · spec-distill · plugin-audit). plugins/spec-distill/.claude-plugin/plugin.json 은 name · description · version(8.14.0) · author 만 갖고 폴더 밖 경로를 싣는 칸이 없다. 따라서 루트 CLAUDE.md · docs/philosophy/ · docs/plugin-authoring.md · shared/ · tools/ 는 설치한 다른 레포로 가지 않는다. shared 것은 플러그인 안 사본으로만 간다(예: plugins/spec-distill/agents/doc-critic-web.md 머리 `# copy-of: shared/docreview/agents/doc-critic-web.md`)."
    touches: []
    decides: [OQ1]

  # ── 레포에만 있는 자리 ─────────────────────────────────────────
  - id: RC2
    path: "CLAUDE.md"
    anchor: "**있는 것 먼저.** 만들기 전에 레포 안 · 밖의 있는 것을 검토하고 외부 것은 사용자 검토 뒤 쓴다(철학 P8)."
    line: 34
    claim: "레포 전용(플러그인 폴더 밖). Law 3 아래 불릿 다섯 중 하나. 요구 행동은 둘 — 만들기 전 「검토」와 외부 것의 「사용자 검토 뒤 사용」. 검토 결과가 어느 쪽이어야 한다는 기본값 · 기록 자리 · 검사 주체는 이 문장에 없다."
    touches: []
    decides: [OQ1, OQ7]
  - id: RC3
    path: "docs/philosophy/devbrew-harness-philosophy.md"
    anchor: "P8 — Determinism Economy · 「(재사용) 새로 만든 것은 유지할 표면이 되므로 레포 안 · 밖에 있는 것을 먼저 검토하고, 외부 것은 사용자가 검토한 뒤에 쓴다(P17).」"
    line: 85
    claim: "레포 전용. 이유(새로 만든 것 = 유지할 표면)를 대고 P17(User Sovereignty — 「agent는 권고하고 사용자가 결정한다」, :50-51)로 외부 검토를 묶는다. 요구는 CLAUDE.md 와 같은 「먼저 검토 + 외부는 사용자 검토 뒤」이고 기본 결론은 정하지 않는다. P8 의 「코드:」 지도 줄이 없어 이 불릿의 집행 자리는 문서에 적혀 있지 않다."
    touches: []
    decides: [OQ1, OQ7]
  - id: RC4
    path: "docs/superpowers/specs/2026-10-19-principles-docs-cleanup-design.md"
    anchor: "§1 옮길 원칙 여섯 표 6행 · 「기존에 있던거를 사용할 수 있는지 검토하는 성향이면 좋겠어 레포 내부든 외부든 … 다만 외부는 나한테 검토 받고 사용하는거로」"
    line: 70
    claim: "레포 전용 기록. CLAUDE.md 문장의 출처인 사용자 원문과 그 뜻 풀이(「만들기 전에 레포 안 · 밖의 있는 것을 먼저 검토한다 · 외부 것은 사용자 검토 뒤에만 쓴다」)가 여기 있다. 같은 문서 `## 플러그인 동작 자리 대조` 표(:231)는 원칙 6 이 실린 자리를 conducting.md · epic-handoff.md 로, 빈 곳을 finishing.md 의 하나짜리 brief 다음 세션 줄로 적고 R10 에 넘겼다(그 빈 곳은 지금 채워져 있다 — RC6)."
    touches: []
    decides: [OQ1, OQ6]

  # ── 플러그인에 실려 가는 자리: 인터뷰 ──────────────────────────
  - id: RC5
    path: "plugins/spec-distill/skills/pm-interview/SKILL.md"
    anchor: "## 조사 열기 · 「**있는 것 먼저.** 무엇을 만들자는 결정이 열리면, 레포 안의 있는 것(같은 일을 하는 스크립트 · skill · 모듈)을 먼저 찾고, 바깥의 성숙한 것(패키지 · 프레임워크 · 도구)을 웹으로 찾는다. 레포 안 후보는 레포 주장(RC)으로, 바깥 후보는 §4 웹 항목으로 brief 에 싣는다. 바깥 것은 사용자 검토 뒤에만 쓴다 — 후보와 차이를 보이고 묻는다. 기본은 이렇게 하고, 만들 것이 없는 일(조사 · 결정만)이면 건너뛰고 이유를 적는다.」"
    line: 312
    claim: "실려 간다(spec-distill). 발동 조건은 「무엇을 만들자는 결정이 열리면」이고 고치는 일 · 크기에 대한 문장은 없다. 요구 행동: ① 레포 안 먼저 찾기 ② 바깥의 「성숙한」 것을 웹으로 찾기(성숙의 기준은 적혀 있지 않다) ③ 기록 자리 지정 — 레포 안 후보는 RC, 바깥 후보는 brief §4 ④ 바깥 것은 후보와 차이를 보이고 묻기. 건너뛰기 조건은 「만들 것이 없는 일」 하나다. 찾은 것을 쓰는 쪽이 기본이라는 문장은 없다."
    touches: []
    decides: [OQ1, OQ2, OQ5, OQ7]
  - id: RC6
    path: "plugins/spec-distill/tests/test_open_research.sh"
    anchor: "# AC12 · assert_contains \"$FLAT\" '바깥 것은 사용자 검토 뒤에만 쓴다'"
    line: 61
    claim: "RC5 문장을 지키는 검사는 문구 존재 락 셋뿐이다(:61-63 — 「레포 안의 있는 것(…)을 먼저 찾고」 · 「바깥 것은 사용자 검토 뒤에만 쓴다」 · 「만들 것이 없는 일(조사 · 결정만)이면 건너뛰고 이유를 적는다」). SKILL 문장이 남아 있는지를 재고, 인터뷰가 실제로 그 검토를 했는지는 재지 않는다. plugins/spec-distill/tests/ 는 플러그인 폴더 안이라 함께 복사되지만 이 레포의 개발 락이다."
    touches: []
    decides: [OQ6]
  - id: RC7
    path: "plugins/spec-distill/templates/interview-brief-template.md"
    anchor: "## 4. External Landscape · 「1항목 = 첫 줄 하나(+ 들여쓴 본문 줄), 첫 줄에 **«출처키» 필수** + [취함|피함|중립] + 이유」 · 「외부 선례 무관(@S<m>) — <이유>」"
    line: 78
    claim: "인터뷰 단계의 기록 자리는 brief §4 다. 바깥 후보는 «출처키» + [취함|피함|중립] + 이유 + 결정 연결(`[→ OQ<n>]`)로, 레포 후보는 `[RC<n> → OQ<n>]` 로 실린다. 「있는 것 후보」 전용 칸 · 표시는 없고 다른 조사 항목과 같은 줄 꼴이다. 외부 선례가 상관없으면 사용자가 라운드 질문에서 고른 답(☑ S<m>)을 가리키는 한 줄로 닫는다."
    touches: []
    decides: [OQ6]
  - id: RC8
    path: "plugins/spec-distill/scripts/check_brief.py"
    anchor: "gate() · failures: 「External Landscape empty (no entries and no web-disabled sentinel)」 · 「unkeyed landscape entries」 · landscape_irrelevant()"
    line: 1812
    claim: "brief §4 를 검사하는 기계는 check_brief.py gate 다. 재는 것은 구조다 — §4 가 비지 않았는가(항목 · web-disabled sentinel · 「외부 선례 무관(@S<m>)」 중 하나), 항목마다 «출처키» 가 있고 audit §7 에 선언됐는가, 결정 연결 꼴이 맞는가, 「외부 선례 무관」 의 S 가 audit §6 의 사용자 선택(☑)인가. 「만들자는 결정에 대해 레포 안 · 밖 후보를 찾았는가」 나 「바깥 후보를 사용자에게 물었는가」 를 재는 술어는 없다. pm-interview SKILL `## 5 통과 의례` R2(:513)의 통과 기준도 「web sweep ≥1회, prior-art/대안이 인용과 함께 표면화」 다."
    touches: []
    decides: [OQ6]
  - id: RC9
    path: "plugins/spec-distill/references/docreview-profiles/brief.md"
    anchor: "`direction` — 확정 항목이 리포 사실과 모순되거나, 더 성숙한 외부 대안이 있거나, 확정 사이가 서로 충돌한다."
    line: 25
    claim: "brief 리뷰어가 있는 것 쪽을 보는 자리는 둘이다. ① 층 1 `direction`(must_catch, 처분 `decide`) — 「더 성숙한 외부 대안」 을 근거와 함께 사용자 결정으로 올린다. 이 프로필은 `web: true`(:14)라 doc-critic-web 이 웹으로 「더 나은 대안이 이미 있는가(성숙한 라이브러리 · 확립된 패턴 · 출시된 도구 · 문서화된 접근)」 를 찾는다(plugins/spec-distill/agents/doc-critic-web.md:60, 도구는 Read · Grep · Glob · WebSearch · WebFetch). ② 층 1 `overdesign` 사다리 2 · 3단(:60-61) 「이미 리포에 있는 원칙·메커니즘으로 되나」 · 「이미 있는 하니스 표면(프로필 필드 · 처분 · 락 · 훅)으로 되나」. 둘 다 리뷰어의 탐지이고 brief 에 검토 기록이 있는지를 요구하지는 않는다."
    touches: []
    decides: [OQ6]

  # ── 실려 가는 자리: 설계로 넘기는 줄 ───────────────────────────
  - id: RC10
    path: "plugins/spec-distill/skills/pm-interview/references/finishing.md"
    anchor: "**다음 세션 줄 — ①/② 공통** · 「설계문서에 ## 있는 것 검토 절(레포 안에 이미 있는 것을 먼저 찾아 쓰고, 레포 밖 패키지 · 프레임워크 · 서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다)과 ## 상류 · 하류 연계 절(…)을 두고」"
    line: 553
    claim: "실려 간다. 하나짜리 brief 를 superpowers:brainstorming 에 넘기는 프롬프트 한 줄 안의 문장이다. 같은 파일 `**규약의 거처 (C5)**`(:540-543)가 「`superpowers:brainstorming`은 spec-distill을 모르고 brief frontmatter를 읽지 않습니다 — 전달은 순수 프로즈 경로입니다」 라고 적는다 — 설계 단계의 요구는 이 줄의 산문으로만 전달된다. 요구 행동: 설계문서에 `## 있는 것 검토` 절을 둔다 · 레포 안 것은 「먼저 찾아 쓴다」(여기만 '쓴다' 까지 간다) · 레포 밖 것은 「후보로만 적어 사용자가 승인한 뒤에만 쓴다」(승인 요구). 절의 칸 · 꼴은 정하지 않는다."
    touches: []
    decides: [OQ1, OQ6, OQ7]
  - id: RC11
    path: "plugins/spec-distill/references/epic-handoff.md"
    anchor: "**에픽 넘김 줄** · 「설계 전에 이 에픽이 닿는 코드 · 문서를 직접 읽어 묶음의 근거가 지금도 맞는지, 빠진 항목 · 이미 고쳐진 항목이 있는지 꼼꼼히 조사해 ## 있는 것 검토 절에 적는다」"
    line: 7
    claim: "실려 간다. 에픽 설계를 여는 줄에 `## 있는 것 검토` 가 두 번 나오고 뜻이 다르다. ① 위 인용 — 묶음 근거의 재확인(지금도 맞는가 · 빠진 것 · 이미 고쳐진 것) 조사 결과를 그 절에 적는다. ② RC10 과 글자가 같은 원칙 문장(「레포 안에 이미 있는 것을 먼저 찾아 쓰고, 레포 밖 패키지 · 프레임워크 · 서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다」). 한 절이 「근거 재확인」 과 「재사용 · 외부 후보 검토」 두 가지를 받는다."
    touches: []
    decides: [OQ1, OQ6, OQ7]
  - id: RC12
    path: "plugins/spec-distill/tests/test_end_gates.sh"
    anchor: "SHARED='설계문서에 ## 있는 것 검토 절(…)을 두고, … 레포 설정에서 읽게 설계한다.' · 「AC22: brief 줄의 원칙 문장이 에픽 넘김 줄과 글자가 같다」"
    line: 68
    claim: "두 넘김 줄(RC10 · RC11)의 원칙 문장은 글자 동일 락으로 묶여 있다. 같은 문구의 존재 락이 test_epic_handoff.sh:64(「## 있는 것 검토 절」 · 「사용자가 승인한 뒤에만」) · test_review_handoff_order.sh:97 · test_parallel_recommend_docs.sh:111(「꼼꼼히 조사해 ## 있는 것 검토 절에 적는다」)에 있다. 전부 넘김 줄에 문장이 남아 있는지를 잰다."
    touches: []
    decides: [OQ6]

  # ── 설계 단계: 기록 자리와 검사 ────────────────────────────────
  - id: RC13
    path: "plugins/spec-distill/references/docreview-profiles/design-doc.md"
    anchor: "`required_sections` — 필수 섹션 누락. Context/Why · Goals · Non-goals · Constraints · Acceptance Criteria · Files to Modify · Verification Plan · Rejected Alternatives · Metadata 가운데 없는 절이 있거나"
    line: 108
    claim: "설계 단계의 기록 자리는 설계문서 `## 있는 것 검토` 절인데, spec-review 의 리뷰어 프로필은 그 절을 요구하지 않는다 — `required_sections` 의 아홉 절에 「있는 것 검토」 · 「상류 · 하류 연계」 가 없다. 이 프로필은 `web: false`(:20)라 설계문서 리뷰어는 웹으로 외부 대안을 찾지 않는다. 가까운 항목은 층 1 `overdesign` 사다리(:73-77 「2. 이미 리포에 있는 원칙·메커니즘으로 되나 / 3. 이미 있는 하니스 표면(…)으로 되나 / 5. 그제서야 새 메커니즘」, 처분 `decide`)와 층 2 `approaches_comparison`(:104 「대안 비교 없이 단정된 선택」) · 층 1 `feasibility`(:38) 다. 사다리의 단은 레포 안 것만 말하고 레포 밖 것은 없다."
    touches: []
    decides: [OQ6]
  - id: RC14
    path: "plugins/spec-distill/scripts/check_bundle_coverage.py"
    anchor: "(부재) `있는 것 검토` 리터럴이 plugins/**/*.py · *.js · hooks · agents/*.md · skills/**/SKILL.md · shared/** · tools/** 어디에도 없다"
    claim: "`## 있는 것 검토` 절의 존재 · 내용을 읽는 스크립트 · 훅 · agent 는 없다(Grep 0건 — 심볼릭 링크는 건너뛰므로 하한). check_bundle_coverage.py 는 번호 대조 표 · AC↔계획 Task · 미룸 표를, spec_review_bundle.py 는 정답 출처 · 로드맵 위치를 본다(plugins/spec-distill/README.md:151-153). 사용자 승인 기록을 `## 있는 것 검토` 와 잇는 장치도 없다 — 승인 기록이 있는 자리는 설계문서 `## 결정 기록`(리뷰의 decide)과 `## 지휘 기록`(spec 승인 줄)뿐이다."
    touches: []
    decides: [OQ6, OQ7]
  - id: RC15
    path: "docs/superpowers/specs/2026-10-19-principles-docs-cleanup-design.md"
    anchor: "## 있는 것 검토 · 「- 안 쓴다: 외부 패키지 · 도구 없음(문서 정리라 필요 없음).」"
    line: 123
    claim: "실제 기록 꼴(레포 전용 산출물). `## 있는 것 검토` 절을 가진 설계문서는 docs/superpowers/specs/ 에 11개다(2026-10-17 이후). 읽은 여덟의 꼴은 「레포 안(쓴다)」 목록 + 레포 밖 한 줄이고, 레포 밖 줄은 「레포 밖 후보: 없음」(2026-10-28-askquestion-recommendation :164) · 「외부 패키지 · 도구는 쓰지 않는다」(2026-10-19-interview-open-research :209) · 「새 외부 패키지는 쓰지 않는다」(2026-10-20-review-engine-leftovers :238 · 2026-10-20-dependency-portability :246) · 「레포 밖 패키지 · 서비스는 쓰지 않는다」(2026-10-25-epic-parallel-recommend :190) 다. 절 꼴은 문서마다 다르다(목록 · 표 · 쓴다/새로 만든다/바깥/기각). 외부 후보를 사용자에게 물어 승인받았다는 기록은 읽은 절들에 없다. 기각 칸에 외부 기능을 견준 예는 dependency-portability :247(plugin.json `dependencies` · `userConfig` 기각과 이유) 하나를 봤다."
    touches: []
    decides: [OQ6, OQ7]

  # ── 지휘자 · 계획 단계 ─────────────────────────────────────────
  - id: RC16
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### 3. 다음 일 고르기와 보내기 · 「설계 전 조사는 꼼꼼히(`epic-handoff.md` 의 조사 문장 — 있는 것 검토 절에 적고, 다른 에픽이 예약한 파일이면 재분해 신호), 계획의 첫 과제는 가벼운 다시 확인이다(`conductor-dispatch.md` 계획 틀).」"
    line: 34
    claim: "실려 간다. 지휘자는 자기 문장을 두지 않고 epic-handoff.md 를 가리킨다 — 지휘 순환 걸음 3(:34-35 「brainstorming 의 입력과 지시는 같은 폴더 `epic-handoff.md` 의 에픽 넘김 줄이 싣는 것과 같다」)과 손 절차 3(:101 괄호 열거 안의 「있는 것 검토」). 지휘자가 `## 있는 것 검토` 를 확인하는 걸음은 없다. 걸음 4(:102)의 계획 검토는 「설계에 없던 결정(범위 · 인터페이스 · 파일 배치 등)이 있는지」 를 가리고, 머지 전 통합 리뷰(:108)의 물음 목록에도 재사용 · 외부 의존 항목이 없다."
    touches: []
    decides: [OQ1, OQ6]
  - id: RC17
    path: "plugins/spec-distill/skills/spec-review/SKILL.md"
    anchor: "**다음 세션 줄 — ①/② 공통** · 「@<spec_path> 이 설계문서로 Skill superpowers:writing-plans 를 시작하라. confirmed 항목은 근거 있으면 보고 후 재결정 가능하고 임의 변경은 금지다. 계획을 쓴 뒤 … check_bundle_coverage.py --plan …」"
    line: 757
    claim: "계획 단계로 넘기는 줄에는 「있는 것」 요구가 없다. writing-plans 줄이 싣는 것은 재결정 규칙 · AC↔계획 대조 · AC 판정 보고 · 미룸 표 · 글 규칙이다. 지휘자가 계획 agent 에 주는 틀(plugins/spec-distill/references/conductor-dispatch.md:56)의 조사 문장은 「계획의 첫 과제는 가벼운 다시 확인이다 — 설계문서가 근거로 든 자리가 지금 코드에서도 그런지 보고, 달라졌으면 멈춰 보고한다」 하나이고, 이는 설계 근거의 유효성 확인이지 재사용 · 외부 후보 검토가 아니다. 구현 agent 틀에도 없다."
    touches: []
    decides: [OQ1, OQ6]
  - id: RC18
    path: "plugins/spec-distill/templates/roadmap-template.md"
    anchor: "(부재) 로드맵 틀 · 에픽 묶음 생성 자리에 `있는 것` · `재사용` · `외부` 문장 없음"
    claim: "에픽 묶음 · 로드맵 틀 자체는 이 요구를 싣지 않는다 — 템플릿 다섯(interview-brief · interview-audit · interview-seed · interview-seed-audit · roadmap)과 pm-interview references 의 분해 쪽에 해당 문장이 없다(「있는 것 검토」 는 skills 아래에서 finishing.md:553 한 곳뿐). 묶음에 실리는 것은 원본 brief 의 번호 항목이고, 요구는 에픽 넘김 줄(RC11)이 설계 세션에 얹는다. 옛 로드맵 묶음(docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R*.md)에 보이는 「있는 것 먼저(S30)」 는 그 인터뷰의 사용자 발화 · 확정 항목이지 틀이 넣은 문장이 아니다."
    touches: []
    decides: [OQ1]

  # ── 인접 자리(같은 방향이지만 「먼저 검토」 요구 문장은 아님) ──
  - id: RC19
    path: "plugins/spec-distill/references/fresh-evidence.md"
    anchor: "원칙 4 「최신과 신뢰성 간 스윗포인트를 생각해야하며 사용자에게 선택지를 줄 수 있어야 한다 모델이 혼자 결정하지 않음」 → 행동 「최신과 안정이 갈리면(새 판 · 실험 기능 · 막 바뀐 정책) 차이를 보이고 선택지로 묻는다」"
    line: 12
    claim: "실려 간다. 바깥 것을 조사할 때의 기본 행동이다 — 실험 기능은 금지가 아니라 「차이를 보이고 선택지로 묻는」 대상으로 적혀 있다. 원칙 5(:13)는 「가능한 경우 공식 문서와 1차 자료를 우선한다」 인데 이는 출처의 우선순위이지 후보 자체의 채택 기준(공식 제공 · 널리 쓰임 · 유지 중)이 아니다. 머리말(:3)은 「형식 칸을 채우라는 게이트가 아니라 기본 행동이다」 라고 적는다."
    touches: []
    decides: [OQ2, OQ3]
  - id: RC20
    path: "docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R6.md"
    anchor: "☑ confirmed **D33** — 「… 있는 것을 먼저 쓰며(기반은 작업 목록·worktree 격리·SDD·qg), agent teams 같은 실험 기능은 기반으로 쓰지 않는다 ⟨S31⟩」"
    line: 44
    claim: "레포 전용 기록. 「실험 기능은 기반으로 쓰지 않는다」 는 그 로드맵의 확정 항목(D33, 근거 S31)이고 같은 묶음들의 Non-goal 줄(예 R2a.md:27 「실험 기능(agent teams)을 기반으로 쓰는 것(S31) · 이미 있는 것을 다시 만드는 것(S30)」)에 실려 있다. 원문 발화는 「전부, 실험 기능은 제외 — … 있는 것 먼저(S30). agent teams 같은 실험 기능은 기반으로 쓰지 않음(작업 목록·worktree 격리·SDD·qg 만)」(R6.md:150). 범위는 그 로드맵 하나다 — CLAUDE.md · 철학 문서 · 플러그인 파일에는 실험 기능을 다루는 규칙 문장이 없다(RC19 의 「선택지로 묻는다」 만 있다). 같은 로드맵 R5.md:69 는 agent teams 를 「실험 기능이고 재개 불가·계획 자동 승인 «cc-agent-teams» — [피함]」 으로 적었다."
    touches: []
    decides: [OQ3]
  - id: RC21
    path: "plugins/plugin-audit/scripts/audit-workflow.js"
    anchor: "축 '외부대비·정체성' · 「**대상은 2026년에도 존재 이유가 있는가? 내장 기능·형제 플러그인·공식 규범과 겹치는가?**」"
    line: 405
    claim: "실려 간다(plugin-audit). 만든 «뒤» 의 감사 축이다 — devbrew 플러그인 하나를 대상으로 내장 기능 · 형제 플러그인 · 공식 규범과의 겹침을 묻고 공식 문서로 확인하게 한다(:407-412). 만들기 전 검토 요구가 아니고, 대상은 devbrew 플러그인이지 설치한 레포의 코드가 아니다. 축 4 는 기본 여섯 축 중 사용자가 고르는 축이다(plugins/plugin-audit/skills/plugin-audit/SKILL.md:88)."
    touches: []
    decides: []
  - id: RC22
    path: "docs/plugin-authoring.md"
    anchor: "「`plugin-dev`가 주는 것은 **문법**이다. … devbrew에서는 설계를 brainstorming과 spec-distill이 담당하므로 skill을 지식으로만 쓴다.」"
    line: 48
    claim: "레포 전용. 새 플러그인 설계의 기본을 외부(공식) `plugin-dev:plugin-structure` 로 둔 자리다(:42-45, CLAUDE.md `## Building a New Plugin` 과 같은 내용 — 「기본은 … 확정하는 것이다 — 다른 길이 맞으면 이유를 적는다」). 「외부 것을 기본으로 쓰고 다르면 이유를 적는다」 꼴의 문장은 레포에서 이 한 쌍뿐이고, 일반 「있는 것 먼저」 문장들(RC2 · RC3 · RC5 · RC10)은 이 꼴이 아니다."
    touches: []
    decides: [OQ7]
  - id: RC23
    path: "plugins/spec-distill/README.md"
    anchor: "`references/epic-handoff.md` — 「… 설계문서에 「있는 것 검토」 · 「상류 · 하류 연계」 절을 두고 …」"
    line: 154
    claim: "실려 간다. epic-handoff.md 의 요약 한 줄이며 새 요구를 더하지 않는다. quality-gates · project-init 의 skill · agent · reference · 템플릿에는 재사용 · 있는 것 검토 요구 문장이 없다(Grep — project-init 이 다른 레포에 쓰는 AGENTS.md/CLAUDE.md 템플릿에도 없다. qg 리뷰어 프로필에도 중복 구현 · 재발명 항목이 없다)."
    touches: []
    decides: [OQ1]
unanswered: "레포가 답하지 못한 것 — ① 채택 기준 셋(공식 제공 · 널리 쓰임 · 유지 중)은 어느 파일에도 없다. 문면의 수식어는 「성숙한」 하나다(OQ2). ② 에이전트 조율용 프레임워크를 대상에서 뺀다는 일반 규칙은 없다 — agent teams 를 피한 옛 로드맵 한 건(RC20)뿐이다(OQ4). ③ 고치는 일 · 사소한 변경에 이 검토가 걸리는지 말하는 문장은 없다 — 발동 조건은 「만들기 전에」 · 「무엇을 만들자는 결정이 열리면」 뿐이다(OQ5). ④ 검토가 형식에 그친 «원인» 은 레포가 말하지 않는다 — 확인된 것은 검사 부재와 실제 절의 꼴(RC13 · RC14 · RC15)까지다(OQ6). ⑤ superpowers 의 brainstorming · writing-plans 본문은 이 레포에 없어 그 skill 들이 넘김 줄의 문장을 어떻게 다루는지는 확인하지 못했다."
```

조사 범위 메모
- 훑은 곳: CLAUDE.md · docs/philosophy/ · docs/plugin-authoring.md · plugins/*/{skills,references,agents,templates,scripts,tests,README.md,dependencies.md} · shared/ · tools/ · docs/superpowers/{specs,roadmaps}. 검색어는 「있는 것 먼저/검토」 · 재사용 · 기존 것 · 이미 있는 · 사용자 검토/승인 뒤 · 패키지/프레임워크/라이브러리/성숙한/prior-art · 실험 기능 · reuse/reinvent/duplicate.
- 「재사용」 · 「이미 있는」 의 나머지 다수 적중(stale 산출물 재사용 방지 · 세션 id 재사용 · 번호 재사용 · 「이미 있는 원문 글자」 등)은 다른 뜻이라 주장에서 뺐다.
- Grep · Glob 은 심볼릭 링크를 건너뛰므로 「없다」 는 주장(RC14 · RC18 · RC23)은 하한이다.

관련 파일(절대경로)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/CLAUDE.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/philosophy/devbrew-harness-philosophy.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/.claude-plugin/marketplace.json
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/skills/pm-interview/SKILL.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/skills/pm-interview/references/finishing.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/skills/spec-review/SKILL.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/epic-handoff.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/conducting.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/conductor-dispatch.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/fresh-evidence.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/docreview-profiles/brief.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/docreview-profiles/design-doc.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/agents/doc-critic-web.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/templates/interview-brief-template.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/scripts/check_brief.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/scripts/check_bundle_coverage.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/tests/test_open_research.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/tests/test_end_gates.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/tests/test_epic_handoff.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/plugin-audit/scripts/audit-workflow.js
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/plugin-authoring.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-19-principles-docs-cleanup-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R6.md


### 조사 1 — coverage-mapper · R1 · 묶음 1

계약(`<claims_contract>`)은 받았다. 전제 목록 `P<n>` 은 받지 못해 모든 `touches` 는 빈 배열이다. `id: RC<n>` 은 임시값이다. 레포 루트는 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first` 이고 `path` 는 그 기준 상대경로다.

```yaml
derived_dimensions:
  - name: "규칙의 운반 자리 — 다른 레포 도달 · 외부 소유 단계 · 인터뷰를 거치지 않는 일"
    rationale: "플러그인은 늘 실리는 지시를 실어 보낼 수 없다(E1). 다른 레포에 닿는 자리는 지금 spec-distill 의 글 셋뿐이다(RC2 · RC3 · RC4). 이 답은 앞선 설계가 「두 갈래」로 이미 낸 적이 있다(RC10). 설계 · 계획 단계는 외부 플러그인의 skill 이 돌리고 devbrew 가 고칠 수 있는 것은 넘김 글 · 리뷰 프로필 · 계획 대조뿐이다(RC15). 가벼운 꼴 · 직접 고침처럼 인터뷰를 거치지 않는 일에는 다른 레포로 가는 운반 자리가 없다(RC11 · RC16)."
  - name: "결론을 판정하는 쪽 — 「직접 만들 이유」를 작성자 아닌 누가 읽는가"
    rationale: "설계문서 리뷰 프로필에 「있는 것 검토」를 재는 항목이 없고, 과설계 사다리의 재사용 단은 레포 안 것만 묻는다(RC6). 기계 검사는 넘김 줄에 그 문구가 있는지만 잰다(RC5). 리뷰어는 중복된 agent 코드에 중립 · 긍정으로 반응한다는 연구가 있다(E3). 이유 칸만 더하면 작성자가 쓰고 작성자가 결론 내는 구조가 그대로다."
  - name: "「맞는」 판정과 부분 적합 — 기본값이 뒤집히는 자리"
    rationale: "seed 의 기본값은 「맞는 프레임워크가 있으면」에 걸려 있는데 「검증된」에는 잣대 셋이 있고 「맞는」에는 없다(냉독 지적, RC17). 지난 설계가 플랫폼 기능을 기각한 이유는 검증이 아니라 적합이었다(RC8). agent 는 라이브러리를 들이고도 덜 쓰고 다시 만든다(E4)."
  - name: "채택 비용의 비대칭 — 의존 선언 · 없을 때 동작 · 배포 환경 · 공급망"
    rationale: "외부 것을 들이면 의존 표 행 · 잰 판 · 강도 · 없을 때 동작 · README 공시 · 사용자 승인이 붙는다. 레포 안에 만들면 붙지 않는다(RC9). 넘김 글의 문면도 레포 안은 「찾아 쓰고」, 밖은 「후보로만 적어」로 갈라져 있다(RC3). 이 비대칭은 Phase 0 추측(기본값 부재)과 다른 원인 후보다. 외부 패키지 기본값에는 공급망 위험이 따른다(E7)."
  - name: "검증 기준의 범주별 측정 가능성 — 세 범주에 세 잣대가 같은 뜻으로 걸리는가"
    rationale: "「유지 중」은 패키지에는 이미 있는 측정 정의가 있다(E8). Claude Code 기본 기능은 「공식 제공」을 자동으로 넘지만 공식 딱지가 안정성을 뜻하지 않는다(E1 · E2). agent 팀은 기본 기능이면서 실험 기능이고 agent 조율 기능이라 OQ3 와 OQ4 가 같은 대상에서 만난다(RC13 · RC14 · E2)."
  - name: "「고칠 때 함께 본다」의 발동 지점과 크기 하한"
    rationale: "사소한 변경은 진입 게이트에서 빠져나가 인터뷰 · 설계에 닿지 않는다(RC12). 이번 일의 범위는 인터뷰 · 설계 · 계획 단계라서, 사소한 변경에도 걸리게 하려면 그 단계 밖의 자리가 필요하다. 기존 장치를 고친 설계 9건은 모두 새 외부 것을 들이지 않았다(RC7)."
  - name: "효과 관측 — 검토가 형식이 아님을 무엇으로 아는가"
    rationale: "seed 의 핵심은 「결론이 실제로 달라지는 것」인데 달라졌는지를 볼 관측점이 정해져 있지 않다. 어떤 설정 장치가 build-vs-buy 결정을 바꾸는지는 통제 실험이 아직 없다(E5). 그래서 문장 고침의 효과는 전제할 수 없고 재야 한다. 지금 기준선은 9건 중 새 외부 것 0건이다(RC7)."
neglect_flag: true
neglected_dimensions:
  - "결론을 판정하는 쪽 — 「직접 만들 이유」를 작성자 아닌 누가 읽는가"
  - "「맞는」 판정과 부분 적합 — 기본값이 뒤집히는 자리"
  - "채택 비용의 비대칭 — 의존 선언 · 없을 때 동작 · 배포 환경 · 공급망"
  - "효과 관측 — 검토가 형식이 아님을 무엇으로 아는가"
confidence: 0.7
evidence:
  - url: "https://code.claude.com/docs/en/plugins-reference"
    supports: current
    claim: "플러그인은 늘 실리는 지시를 실어 보낼 수 없다. 원문: «A `CLAUDE.md` at the plugin root isn't loaded as context, and `claude plugin validate` warns when it finds one. To include instructions that load into Claude's context, put them in a skill.» 플러그인이 실을 수 있는 것은 skill · agent · hook · MCP · LSP · output style · workflow 등이다. 같은 문서의 `experimental` 칸은 «whose manifest shape may still change» 로 정의된다."
    touches: []
    decides: [OQ1, OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "claude-code 2.1.303 (plugins/spec-distill/dependencies.md, 2026-10-22 에 잰 값)", latest: "확인 안 함"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/agent-teams"
    supports: both
    claim: "agent 팀은 지금도 실험 기능이고 기본으로 꺼져 있다. 원문: «Agent teams are experimental and disabled by default.» 켜려면 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 이 필요하다. 한계로 세션 재개 불가 · 세션당 팀 하나 · 중첩 불가가 적혀 있다. Claude Code 기본 기능이면서 agent 조율 기능이고 실험 기능이다."
    touches: []
    decides: [OQ3, OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://arxiv.org/abs/2601.21276"
    supports: current
    claim: "agent 가 만든 PR 은 재사용 기회를 자주 지나쳐 사람보다 중복이 많다. 원문: «LLM Agents frequently disregard code reuse opportunities». 리뷰어는 그런 PR 에 사람 것보다 중립 · 긍정으로 반응한다. 저자들은 겉보기 그럴듯함이 중복을 가린다고 해석한다. 직접 만들기로 흐르는 것은 이 레포만의 일이 아니고 리뷰가 기본으로는 잡지 못한다. 2026-01 preprint."
    touches: []
    decides: [OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://arxiv.org/abs/2609.36730"
    supports: both
    claim: "하류 agent 는 라이브러리를 들이고도 덜 쓰고, 라이브러리가 이미 주는 기능을 다시 만든다. 원문: «Downstream agents adopt agent- and human-written libraries alike but underuse them». 실패 분석은 주된 원인을 기능 부재가 아니라 라이브러리가 딱딱하거나 쓰기 어려운 데 둔다. 채택 결정과 실제 사용은 다른 단계다. 2026-09 preprint, 초록만 확인했다."
    touches: []
    decides: [OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://arxiv.org/abs/2606.03907"
    supports: alternative
    claim: "어떤 설정 장치가 agent 의 build-vs-buy 결정을 바꾸는지는 아직 통제 실험이 없다. 원문: «no controlled experimental study has examined what governs build-versus-buy decisions in agentic AI coding tools». 이 글은 사전 등록 프로토콜이고 결과가 없다. Claude Code 와 Codex 에서 context 파일 · skill · MCP · 권한 설정을 비교할 계획이다. 규칙 문장을 고치면 결론이 달라진다는 것은 검증된 사실이 아니다."
    touches: []
    decides: [OQ6, OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://www.anthropic.com/engineering/building-effective-agents"
    supports: alternative
    claim: "Anthropic 은 agent 프레임워크에 한해 직접 만들기부터 권한다. 원문: «We suggest that developers start by using LLM APIs directly: many patterns can be implemented in a few lines of code.» 프레임워크는 «often create extra layers of abstraction that can obscure the underlying prompts and responses» 라고 쓴다. 2024-12-19 글이고, 그 뒤 도구가 많이 바뀌었다고 글 스스로 밝힌다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://www.kaspersky.com/blog/ai-slopsquatting-supply-chain-risk/53327/"
    supports: alternative
    claim: "LLM 이 없는 패키지 이름을 권하고 공격자가 그 이름을 선점하는 위험(slopsquatting)이 보도돼 있다. 2차 보도는 코드 표본 약 57만 6천 개 · 모델 16개 연구에서 상용 모델 평균 약 5%, 오픈소스 모델 평균 약 22% 를 전한다. 수치는 원 논문과 대조하지 못했고 페이지도 직접 열지 않았다(검색 요약). 외부 패키지를 기본으로 삼으면 검증 기준과 승인이 안전 장치 구실을 한다."
    touches: []
    decides: [OQ2]
    source_kind: secondary
    checked_at: "2026-11-15"
    certainty: uncertain
  - url: "https://github.com/ossf/scorecard/blob/main/docs/checks.md"
    supports: both
    claim: "「유지 중」은 패키지에 대해 이미 있는 측정 정의가 있다. OpenSSF Scorecard 의 Maintained 검사는 지난 90일 동안 주마다 커밋이 하나 이상이면 최고점, 보관된 프로젝트면 최저점을 준다. 원문 한계: «This check will only succeed if a GitHub project is >90 days old.» 낮은 점수가 꼭 문제는 아니라고도 적는다(작은 유틸리티는 유지가 필요 없을 수 있다). 「널리 쓰임」 · 「공식 제공」에 해당하는 검사는 이 목록에서 확인하지 못했다."
    touches: []
    decides: [OQ2]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
repo_claims:
  - id: RC1
    path: "CLAUDE.md"
    anchor: "**있는 것 먼저.** 만들기 전에 레포 안 · 밖의 있는 것을 검토하고 외부 것은 사용자 검토 뒤 쓴다(철학 P8)."
    line: 34
    claim: "레포 규칙 문장은 「검토한다」와 외부 것의 승인까지만 적는다. 결론의 기본값, 직접 만들 때의 이유 · 승인은 없다. 철학 문서 P8 (재사용) 조항(docs/philosophy/devbrew-harness-philosophy.md:85)도 같은 범위다. 이것이 형식에 그친 원인인지는 이 문장만으로 확인되지 않는다."
    touches: []
    decides: [OQ6, OQ7]
  - id: RC2
    path: "plugins/spec-distill/skills/pm-interview/SKILL.md"
    anchor: "**있는 것 먼저.** 무엇을 만들자는 결정이 열리면, 레포 안의 있는 것(같은 일을 하는 스크립트 · skill · 모듈)을"
    line: 312
    claim: "인터뷰 단계의 지금 동작은 넷이다. 레포 안 후보를 찾는다. 바깥 후보를 웹으로 찾는다. 둘을 brief 에 싣는다. 바깥 것은 후보와 차이를 보이고 묻는다. 기본 결론을 정하거나 직접 만들 이유를 적게 하는 걸음은 없다. 플러그인 skill 글이라 설치된 어느 레포에서나 실린다."
    touches: []
    decides: [OQ1, OQ7]
  - id: RC3
    path: "plugins/spec-distill/references/epic-handoff.md"
    anchor: "설계문서에 ## 있는 것 검토 절(레포 안에 이미 있는 것을 먼저 찾아 쓰고, 레포 밖 패키지 · 프레임워크 · 서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다)"
    line: 7
    claim: "설계 단계의 운반 자리는 외부 skill(superpowers:brainstorming)에 넘기는 한 줄 안의 문장이다. 그 문면은 레포 안 것은 「찾아 쓰고」, 레포 밖 것은 「후보로만 적어」로 갈라져 있다. 레포 안은 쓰는 것이 기본이고 밖은 후보에 머무는 비대칭이 문장에 이미 들어 있다."
    touches: []
    decides: [OQ1, OQ6, OQ7]
  - id: RC4
    path: "plugins/spec-distill/skills/pm-interview/references/finishing.md"
    anchor: "있는 것 검토 절(레포 안에 이미 있는 것을 먼저 찾아 쓰고, 레포 밖 패키지 · 프레임워크 · 서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다)"
    line: 553
    claim: "하나짜리 brief 의 다음 세션 줄에도 RC3 과 같은 문장이 실려 있다. 다른 레포에 닿는 플러그인 쪽 운반 자리는 RC2 · RC3 · RC4 셋이고, 지휘 절차(plugins/spec-distill/references/conducting.md:101)가 같은 원칙을 이름으로 가리킨다."
    touches: []
    decides: [OQ1]
  - id: RC5
    path: "plugins/spec-distill/tests/test_epic_handoff.sh"
    anchor: "'## 있는 것 검토 절' '사용자가 승인한 뒤에만' '## 상류 · 하류 연계 절' '레포 전용 값은 박지 말고'"
    line: 64
    claim: "기계 검사는 넘김 줄에 그 문구가 들어 있는지만 잰다. plugins/ 에서 「있는 것 검토」가 나오는 파일은 9개다(README · CHANGELOG · reference 둘 · finishing.md · 테스트 넷). 스크립트(.py)와 리뷰 프로필에는 0건이다. 설계문서의 그 절 내용이나 결론을 읽는 장치는 없다."
    touches: []
    decides: [OQ6]
  - id: RC6
    path: "plugins/spec-distill/references/docreview-profiles/design-doc.md"
    anchor: "### 판정 절차 — 사다리 / 2. 이미 리포에 있는 원칙·메커니즘으로 되나 / 3. 이미 있는 하니스 표면(프로필 필드 · 처분 · 락 · 훅)으로 되나"
    line: 74
    claim: "설계문서 리뷰어의 검토 항목(layer_rubric, 15-16행)에 재사용 검토를 재는 항목이 없다. 과설계 사다리의 재사용 단 둘은 레포 안 것만 묻고, 밖의 검증된 것이나 플랫폼 기본 기능을 묻는 단이 없다. 같은 프로필의 `approaches_comparison`(104행)은 기각된 대안을 채택안과 같은 기준으로 비교했는지 본다. 넓힐 수 있는 기존 자리가 둘 있다는 뜻이다. 리뷰어 프로필 편집은 CLAUDE.md 「Persona 파일은 보안-민감 코드」 에 걸린다."
    touches: []
    decides: [OQ6]
  - id: RC7
    path: "docs/superpowers/specs/2026-10-23-rules-docs-cleanup-design.md"
    anchor: "- 레포 밖: 쓰지 않는다."
    line: 394
    claim: "`## 있는 것 검토` 절이 있는 설계문서는 docs/superpowers/specs 에 9건이고, 9건 모두 새 외부 것을 들이지 않았다. 바깥 행의 꼴은 「없음」 · 「쓰지 않는다」 · 「새 외부 패키지는 쓰지 않는다」 · 「방식만 차용」이다. 레포 안 행은 9건 모두 구체적이다(쓰는 스크립트 · 함수를 이름으로 든다). 형식에 그친 쪽은 검토 전체가 아니라 바깥 축으로 보인다. 건마다 실제로 맞는 외부 후보가 있었는지는 확인하지 않았다. 9건 다수는 이미 만든 장치를 고치는 에픽이다."
    touches: []
    decides: [OQ6, OQ5]
  - id: RC8
    path: "docs/superpowers/specs/2026-10-20-dependency-portability-design.md"
    anchor: "- 기각: Claude Code plugin.json `dependencies`(superpowers 가 없으면 spec-distill 전체가 꺼진다 — U6 과 충돌) · Claude Code `userConfig`(레포 단위로 둘 수 없고 Bash 명령 환경에 없다"
    line: 247
    claim: "플랫폼 기본 기능을 실제로 검토하고 이유를 적어 기각한 선례다. 기각 이유는 검증 여부가 아니라 적합이다(없을 때 동작, 레포 단위 설정 불가). 검증 기준 셋을 다 넘는 것도 「맞지 않는다」로 직접 만들기가 된다."
    touches: []
    decides: [OQ6, OQ7]
  - id: RC9
    path: "CLAUDE.md"
    anchor: "**최소 버전이 선언된 의존성.** 플러그인이 기대는 도구 · 다른 플러그인은 그 플러그인의 `dependencies.md` 표(이름 · 최소 판 · 강도 · 없을 때)에 적고"
    line: 50
    claim: "외부 도구 · 플러그인을 들이면 의존 표 행, 잰 판, 강도, 없을 때 동작, README 공시가 따라붙는다(73행 「Loud logging을 동반한 graceful degradation」 포함). 레포 안에 직접 만들면 이 절차가 없다. spec-distill 이 지금 기대는 바깥 것은 여섯이다(plugins/spec-distill/dependencies.md — python · git · gh · superpowers · quality-gates · claude-code). 외부 채택에만 비용이 붙는 구조다."
    touches: []
    decides: [OQ6, OQ7]
  - id: RC10
    path: "docs/superpowers/specs/2026-10-19-principles-docs-cleanup-design.md"
    anchor: "**두 갈래의 「다른 레포」.** CLAUDE.md · 철학 문서는 devbrew 를 개발하는 세션(메모리 없는 다른 기기 · 새 clone 포함)만 읽는다."
    line: 74
    claim: "규칙이 살 자리에는 앞선 설계의 답이 있다. devbrew 개발 세션에는 CLAUDE.md · 철학 문서가 닿는다. 플러그인을 남의 레포에서 쓰는 세션에는 「플러그인의 동작 자리(skill · reference · 설계 틀 · 넘김 글)」가 닿는다. 같은 문서의 대조표(231행)가 원칙 6 의 자리를 conducting.md · epic-handoff.md 로 적었다. 55행 Constraints 는 외부 플러그인(superpowers) 파일 · 동작을 건드리지 않는다고 적는다."
    touches: []
    decides: [OQ1]
  - id: RC11
    path: "plugins/project-init/skills/project-init/SKILL.md"
    anchor: "프로젝트의 git workflow 규칙(브랜치 전략 · 커밋 규약 · PR 절차)과 project charter 를 대화형으로 초기화한다."
    line: 4
    claim: "대상 레포의 AGENTS.md · CLAUDE.md 에 규칙을 써 넣는 devbrew 표면은 project-init 하나다. 그 범위는 git 규칙과 헌장이다. 템플릿(plugins/project-init/templates/ — conventions.md · project/agents-md-section.md 를 읽음)에 재사용 규칙은 없다(`있는 것|재사용|기존 것|패키지` grep 0건). 대상 레포의 상시 규칙으로 실어 보내는 길은 지금 없다."
    touches: []
    decides: [OQ1]
  - id: RC12
    path: "plugins/spec-distill/references/trivia-escape.md"
    anchor: "한 문장으로 설명 가능한 사소한 변경이면(philosophy P12 — 파일 수는 기준이 아니다) 이 게이트를 우회한다."
    line: 3
    claim: "오타 수정 같은 사소한 변경은 진입 skill 에서 사용자에게 한 번 묻고 게이트를 빠져나간다. 그런 변경은 인터뷰 · 설계 · 계획 단계에 닿지 않는다. 「크기와 상관없이 함께 본다」가 사소한 변경에도 걸리려면 이번 범위(세 단계) 밖의 자리가 필요하다."
    touches: []
    decides: [OQ5]
  - id: RC13
    path: "docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.audit.md"
    anchor: "**S31** ☑ 선택 (round 21): 전부, 실험 기능은 제외 — … agent teams 같은 실험 기능은 기반으로 쓰지 않음(작업 목록·worktree 격리·SDD·qg 만)"
    line: 549
    claim: "「실험 기능은 기반으로 쓰지 않는다」는 한 로드맵 인터뷰에서 사용자가 고른 선택지다(D33). 그 로드맵의 묶음들과 설계 하나의 Constraints(docs/superpowers/specs/2026-10-15-roadmap-control-plane-design.md:64)로 내려갔다. CLAUDE.md 와 철학 문서에는 이 문장이 없다. 상시 원칙이 아니라 그 로드맵 범위의 결정이다. 이름으로 든 예는 agent 팀 하나이고, 그것은 agent 조율 기능이기도 하다."
    touches: []
    decides: [OQ3, OQ4]
  - id: RC14
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R2.md"
    anchor: "agent 팀은 리드 고정 · 세션당 팀 하나 · /resume 불가 · 기계 간 공유 불가인 실험 기능이다 «cc-agent-teams» — [피함]"
    line: 85
    claim: "하루 전(2026-11-14) 로드맵도 agent 팀을 실험 기능이라는 이유로 피했다. 이유는 딱지 자체가 아니라 구체적 한계다(재개 불가 · 팀 하나). 실험 기능을 피하는 판단은 최근까지 건별로 되풀이됐다."
    touches: []
    decides: [OQ3, OQ4]
  - id: RC15
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "superpowers:writing-plans 를 단일 세션과 똑같이, 단계를 빼거나 다시 쓰지 말고 끝까지 돈다."
    line: 57
    claim: "계획 단계는 외부 skill 을 손대지 않고 그대로 돌린다. devbrew 가 계획 단계에서 고칠 수 있는 자리는 이 보냄 글과 `check_bundle_coverage.py --plan`(58행)이다. 리뷰 프로필은 brief · design-doc · seed 셋이고 계획용은 없다(plugins/spec-distill/references/docreview-profiles/). 「계획 단계가 프레임워크를 먼저 고르게」의 손댈 자리는 설계 단계보다 좁다."
    touches: []
    decides: [OQ1]
  - id: RC16
    path: "CLAUDE.md"
    anchor: "중간 크기 일은 이유를 밝히고 가벼운 꼴(PR 본문의 계획 · 짧은 brief)을 고를 수 있다."
    line: 24
    claim: "설계문서를 쓰지 않는 가벼운 꼴은 CLAUDE.md 에만 정의돼 있다. plugins/ 의 .md 에는 그 낱말이 없다(`가벼운 꼴|PR 본문의 계획|짧은 brief` grep 0건). 인터뷰 · 설계를 거치지 않는 일에는 RC2~RC4 의 운반 자리가 닿지 않는다."
    touches: []
    decides: [OQ1, OQ5]
  - id: RC17
    path: "docs/superpowers/interview/2026-11-15-existing-framework-first-interview.audit.md"
    anchor: "**「맞는 프레임워크」** 에서 맞는지를 누가 무엇으로 판단하는지 모르겠다. 「검증된」에는 잣대 셋이 있는데 「맞는」에는 없다."
    line: 243
    claim: "seed 냉독이 이미 짚은 빈 곳 셋이 열린 결정 목록에 없다. 「맞는」의 판정 주체와 잣대(243행). Claude Code 기본 기능도 승인이 필요한 「외부 것」인가(244행). 「특정 프레임워크 이름을 박지 않는다」와 정의 속 「Claude Code 기본 기능」의 관계(246행)."
    touches: []
    decides: [OQ7]
```

## 계약 밖 메모

- **neglect 판정의 근거.** 열린 결정 일곱은 규칙의 정의 쪽에 모여 있다(자리 · 잣대 · 예외 · 크기). 방치된 넷은 규칙이 지켜지는지를 가르는 쪽이다(누가 판정하나 · 맞는지의 잣대 · 채택 비용 · 관측). focused_dimension 이 null 이라 인터뷰 진행 중의 쏠림은 아니고 seed 와 OQ 목록의 쏠림이다.
- **Phase 0 추측과 다른 원인 후보 둘.** 「기본값이 없어서」 말고도 레포에서 보이는 것이 있다. 하나는 외부 채택에만 붙는 비용이다(RC9 · RC3). 다른 하나는 결론을 읽는 리뷰어가 없다는 것이다(RC5 · RC6). 어느 쪽이 실제 원인인지는 레포만으로 가르지 못했다.
- **확인하지 못한 것.**
  - RC7 의 9건마다 실제로 맞는 외부 후보가 있었는지는 보지 않았다.
  - 「다른 프로젝트에서도 겪었다」는 이 레포에서 확인할 길이 없다.
  - E7 은 검색 요약만 본 2차 자료다.
  - E3 · E4 · E5 는 preprint 이고 초록만 읽었다.
  - Claude Code 최신 판은 확인하지 않았다.
- **OQ 목록에 없는 결정 후보.** RC17 의 셋이다. id 를 지어내지 않으려고 가장 가까운 OQ7 에만 연결했다.


### 조사 3 — repo-researcher · R1 · 묶음 1

레포 루트: /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first (아래 path 는 모두 이 루트 기준 상대경로)

## 0. 한눈에

- 찾은 기록: 설계류 26건 + brief 30건 = 56건. plans 에는 독립된 검토 기록이 없다(절 문면 · 락 과제뿐). roadmaps 는 brief 줄의 사본이 대부분이고 독립 기록은 `token-baseline.md` 하나(설계류에 셈).
- 설계류 26건의 결론(분류는 조사자 읽기 — 기준은 아래 표 머리): 그 후보 위에서 만들기 1 · 일부만 쓰기 9 · 직접 만들기(레포 안 재사용 포함) 15 · 해당 없음 1.
- 「## 있는 것 검토」 머리를 가진 12건(2026-10-17 이후)만 보면: 일부만 쓰기 2 · 직접 만들기 9 · 해당 없음 1. 12건 중 10건이 레포 밖 칸을 「쓰지 않는다 / 없음 / 넣지 않는다」 문장으로 닫는다. 외부 일반 패키지가 실제로 들어온 것은 1건(markdown-it-py, 테스트 전용). 외부 것을 기반으로 삼은 것은 0건.
- 사용자에게 외부 후보를 보이고 물은 흔적이 「있는 것 검토」 12건 중 확인되는 것은 2건(epic-conductor · shared-review-engine). 나머지는 보일 후보가 「없음」으로 적혀 물은 기록이 없다.
- D33 의 출처는 R6 설계문서가 아니라 2026-10-11 인터뷰 brief 다. 사용자가 round 21 에 고른 선택지 라벨(S31)에서 왔고, 「실험 기능」이 가리킨 것은 agent teams 하나다(R5 설계가 Workflow 를 덧붙였다). CLAUDE.md · 철학 문서에는 「실험」이라는 말이 없다(grep 0건).
- 주의: 2026-11-14 conductor-context-economy brief · 로드맵의 「D33」은 번호만 같은 다른 결정이다(팀 규칙 고르기 스크립트).

## 1. 설계류 26건 표

분류 기준: 위에서 = 외부 것 · Claude Code 기본 기능이 본체 / 일부 = 부르기 · 감싸기 · 테스트 전용 · 방식만 차용하고 본체는 직접 / 직접 = 레포 밖을 「쓰지 않는다 · 없음」으로 닫거나 기각 / 해당 없음 = 만들 것이 없음.

| # | 문서 | 본 후보 | 결론 · 적힌 이유(원문) | 사용자에게 물은 흔적 |
|---|---|---|---|---|
| 1 | specs/2026-10-17-epic-conductor-design.md §8 | 레포 안 스크립트 다수 · superpowers skill 9개 · CC 기본 기능(작업 목록 · worktree 격리 · SendMessage · PushNotification) · gh · Mergify · Graphite · agent teams · Workflow | 일부 — 「새 패키지 · 프레임워크 의존은 넣지 않는다. 병합 대기열 서비스(Mergify · Graphite)는 사례로만 참고하고 기반으로 쓰지 않는다(S31)」 | 있음 — 「결정 · 2026-10-17 · 접근 — 「1 · 외부 후보도 씁 (권장)」」 |
| 2 | specs/2026-10-17-shared-review-engine-devices-design.md §8 | markdown-it-py · bashlex | 일부 — 「markdown-it-py(MIT · 4.2.0 · 2026-05 · 의존 mdurl) — 사용자 검토 뒤 테스트에서만(B2). bashlex 는 GPLv3 라 쓰지 않고 원인 치우기로 대체」 · 「런타임 판독기는 표준 라이브러리만 쓴다」 | 있음 — 「B2 · 결정 · 2026-10-17 · 실제 파서 — 「테스트에서만 씁니다 (권장)」」 |
| 3 | specs/2026-10-19-interview-open-research-design.md | 내장 general-purpose agent · 역할 고정 agent 넷 · Anthropic 다중 agent 사례 | 직접 — 「새로 만든다: open-researcher agent 하나 · references/fresh-evidence.md 하나. 내장 general-purpose agent 는 쓰기 · 실행 도구를 가져 조사 agent 로 쓰지 않는다」 · 「외부 패키지 · 도구는 쓰지 않는다」 | 없음(지휘자 판정 목록에 agent 이름만) |
| 4 | specs/2026-10-19-principles-docs-cleanup-design.md | 레포 문서 | 해당 없음 — 「안 쓴다: 외부 패키지 · 도구 없음(문서 정리라 필요 없음)」 | 없음 |
| 5 | specs/2026-10-20-dependency-portability-design.md | CC plugin.json dependencies · CC userConfig · .local.md · git/gh 명령 · Renovate | 직접 — 「Renovate 의 기본 브랜치 설정 읽기(방식만 차용). 새 외부 패키지는 쓰지 않는다」 · 「기각: Claude Code plugin.json dependencies(superpowers 가 없으면 spec-distill 전체가 꺼진다 — U6 과 충돌) · Claude Code userConfig(레포 단위로 둘 수 없고 Bash 명령 환경에 없다 …)」 | 후보를 보인 기록 없음 — U6 은 부재 동작 질문이고 dependencies 기각은 「지휘자 판단 · 2026-10-20 · 설계문서 점검 답」 |
| 6 | specs/2026-10-20-review-engine-leftovers-design.md | 레포 안 · codex CLI -c | 직접 — 「새 외부 패키지는 쓰지 않는다」 | 없음 |
| 7 | specs/2026-10-21-interview-gate-leftovers-design.md | 레포 안 writer 둘(맞지 않아 안 씀) | 직접 — 「레포 밖: 쓰지 않는다. 파이썬 표준 os.open 플래그만 쓴다」 | 없음 |
| 8 | specs/2026-10-23-r8-device-leftovers-design.md | 레포 안 · gh | 직접 — 「새 외부 패키지는 쓰지 않는다」 | 없음 |
| 9 | specs/2026-10-23-rules-docs-cleanup-design.md | 레포 안 | 직접 — 「레포 밖: 쓰지 않는다」 | 없음 |
| 10 | specs/2026-10-25-epic-parallel-recommend-design.md | 레포 안 · 머지 큐 | 직접 — 「레포 안에 있는 것을 먼저 썼다. 레포 밖 패키지 · 서비스는 쓰지 않는다 — 머지 큐는 레포마다 원격에 있으면 읽기만 한다」 | 없음 |
| 11 | specs/2026-10-28-askquestion-recommendation-design.md | 레포 안 · 질문 도구 필드 · PreToolUse 훅 | 직접 — 「레포 밖 후보: 없음. 질문 도구에 추천 필드가 없고(«cc-sdk-approvals»), PreToolUse 훅은 고르지 않은 길이다(K14)」 | 훅은 brief 에 「사용자도 고르지 않음」 |
| 12 | roadmaps/2026-11-14-conductor-context-economy-brief/token-baseline.md | 상태줄 · ccusage · OpenTelemetry · mod | 직접 — ccusage 행 「아니다 — 외부 도구는 사용자 검토 뒤에 쓴다」, 집계는 「이 문서 옆 token-baseline/ 스크립트로 잰다」 | 없음(검토 요청 자체를 안 함) |
| 13 | specs/2026-10-15-roadmap-control-plane-design.md Constraints | CC 작업 목록 · 상태줄 설정 · 훅 알림 · 세션 시작 훅 | 일부 — 「실험 기능은 기반으로 쓰지 않는다(D33) — 기반은 작업 목록 · 상태줄 설정 · 진입 skill」, 새 control_plane.py | 있음 — B1 「명령만 주고 설치 안내 (권장)」 · B3 「A. 스크립트 + 진입 skill + 캐시 (권장)」 · B5 |
| 14 | specs/2026-10-12-interview-persistent-explore-design.md | doc-recritic · 내장 Explore | 직접 — 「내장 Explore 로 레포 조사 — C32 쪽이지만 Bash 가 있어 쓰기를 물리적으로 못 막고(Law 2 결), 처분 회계 락의 agent 집합 밖이라 호출이 락에 안 보인다(B3)」 | 있음 — B1 「새 판정자 agent (권장)」 · B3 「새 읽기 전용 조사 agent (권장)」 |
| 15–19 | specs/2026-10-11-roadmap-walking-skeleton · 2026-10-15-interview-pm-decompose · numbered-handoff-coverage · distill-distortion-devices · state-storage-redesign | 레포 안 스크립트만 | 직접(레포 안 재사용) — 예 「있는 것을 다시 만들지 않는다(C32) — 형식 해석 · 검증은 roadmap_status.py …」. 외부 후보 기록 없음 | 확인 못 함(맞은 줄만 읽음) |
| 20 | specs/2026-09-21-designer-lens-review-design.md §1.3 | ponytail(남의 플러그인) | 일부 — 「결과는 절반의 성공이다」, 「① 은 외부(ponytail)에서, ②③ 은 리포 자신에게서 가져온다」 | 있음 — 「사용자 동의 2026-09-21(리뷰 라운드 1 · D1.7)」 |
| 21 | specs/2026-10-08-qg-v10-rebuild-design.md | 1st-party /code-review · pr-review-toolkit | 일부 — 「1st-party /code-review 로 탐지·검증 대체 | 다이어트 지렛대(dispatch 프롬프트·재비판)를 잃는다 …」 기각, 「qg 소유 정확성 리뷰어 신설 | 사용자가 외부 플러그인 방식 유지를 골랐다(K2)」 | 있음(K2) |
| 22 | specs/2026-09-21-python-floor-and-uv-design.md | uv · PyYAML · ruff | 일부 — 「R2 — uv run --script 로 출하까지 조달. 요구사항이 「Python」에서 「uv」로 바뀌고 uv 미설치 사용자는 즉사한다」 | 「사용자가 3.12 를 선택(D1)」 — 후보 질문 여부는 확인 못 함 |
| 23 | archive/specs/2026-07-19-plugin-audit-plugin-design.md | 공식 플러그인(plugin-dev · security-guidance · claude-md-improver) | 일부 — 「재발명하지 말고 감싸라」, 「plugin-audit은 이들을 감싸거나 가리킬 뿐 재구현하지 않는다」 | 있음 — 「4각도 외부 리서치 … 로 증거를 세운 뒤 사용자가 골랐다」 |
| 24 | archive/specs/2026-07-12-project-init-audit-workflow-design.md §5.4 | plugin-dev · claude-md-management · claude-code-setup · 내장 /init | 일부(판정 기준 · 레퍼런스로) — 맞은 줄만 읽음 | 확인 못 함 |
| 25 | archive/specs/2026-08-01-qg-impact-driven-qa-runtime-design.md | gstack · CE · oh-my-codex 하니스 | 일부(방식 이식) — 「gstack식 명명 모드 4개 이식 … 이름 붙은 메뉴는 LD7이 금지한 satisficing 천장이 된다」 기각, 「빈 스코프 fail-safe (gstack :1173 이식 …)」 | B5 표에 선택 표시 — 맞은 줄만 읽음 |
| 26 | specs/2026-08-05-agent-transparency-design.md | CC output style · statusline | 위에서 — 「output style(본체, 시스템 프롬프트에 붙는다)」 | 「사용자가 이 대가를 알고 선택했다」. 이 플러그인은 뒤에 제거됨(2026-09-20 설계) |

## 2. brief 30건(§ External Landscape)

고유 30건(활성 24 + archive 6, `2026-07-26-qg-impact-driven-qa-runtime-interview.md` 는 두 폴더에 같은 이름 · 같은 절 자리라 한 번만 셈 — 바이트 대조는 안 함).

- 구체 후보(도구 · 플러그인 · CC 기능)에 쓰기 / 안 쓰기 판단이 있는 것 17건:
  - 취한 쪽 10: conductor-context-economy(mod · SDD · 세션 메시지 일부) · persistent-explore(CC 기본 기능 · SDD · qg) · qg-v10-rebuild(playwright-mcp) · skill-only-surface(`claude plugin validate --strict`) · comprehension-debt(output styles · statusline) · designer-lens(ponytail) · qg-impact(로컬 하니스) · brief-handoff-redesign(superpowers 리뷰 프롬프트 형식) · codex-usage-unification(codex 플래그) · project-init-audit(공식 플러그인을 기준으로)
  - 피하거나 원리만 7: qg-epic-roadmap-intent-review · askquestion-recommendation · subagent-adjudication-contract · request-framing-phase0 · epic-parallel-recommend · devbrew-weight-reduction · interview-research-specialization
- 논문 · 실무 글을 근거로만 쓴 것 13건: document-review-redesign · plain-language-output · interview-depth-redesign · framing-intent-drift · audit-folder-removal · review-stopping-criterion · adjudication-topology · brief-restructure · seam-channel-verification · qg-target-derived-judgment · steelman-goal-fit · context-slimming · interview-strengthening
- 이 갈래는 조사자 읽기다. brief 는 설계 전이라 「위에서 / 일부 / 직접」을 확정하지 않는다.

## 3. repo_claims

```yaml
repo_claims:
  # ── D33 의 출처 · 뜻 · 인용 ──
  - id: RC1
    path: "docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md"
    anchor: "id: D33 … source: chosen … evidence: S31"
    line: 176
    claim: "D33 의 정본은 이 brief 다. 원문 「SDD 연결·병렬 머지 원칙·Claude Code 기본 기능·의도 회귀 감지 조사를 모두 재료로 쓰고, 있는 것을 먼저 쓰며(기반은 작업 목록·worktree 격리·SDD·qg), agent teams 같은 실험 기능은 기반으로 쓰지 않는다」. source 는 chosen(사용자가 고른 선택지), status confirmed."
    touches: []
    decides: [OQ3]
  - id: RC2
    path: "docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.audit.md"
    anchor: "S28 · S29 · S30 · S31 (round 19–21)"
    line: 542
    claim: "맥락은 병렬 머지 · SDD 연결 조사의 처분이다. S28 발화 「superpowers쪽에도 이런게 있어 잘 연결될지 생각해봐 SDD중에, 그리고 병렬 머지 원칙의 경우 더 조사해봐」 → S29 선택 「더 조사 — 의도 회귀 자동 감지 사례, Claude Code 자체 병렬 기능을 더 찾기」 → S30 발화 「그리고 원래 있는걸 더 만들생각 말고」 → S31 선택(round 21) 「전부, 실험 기능은 제외 — SDD 연결·머지 원칙 7·Claude Code 기본 기능·의도 회귀 감지 모두 재료로, 있는 것 먼저(S30). agent teams 같은 실험 기능은 기반으로 쓰지 않음(작업 목록·worktree 격리·SDD·qg 만)」. 「실험 기능 제외」는 사용자 자신의 말이 아니라 인터뷰어가 쓴 선택지 라벨이고 사용자가 그것을 골랐다. 고르지 않은 다른 선택지는 audit 에 없다."
    touches: []
    decides: [OQ3]
  - id: RC3
    path: "docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md"
    anchor: "«cc-agent-teams» — [피함] [→ OQ15]"
    line: 429
    claim: "「실험 기능」이 가리킨 것은 Claude Code agent teams 다. §4 원문 「공유 작업 목록·의존·메시지·완료 훅이 있으나 실험 기능이고 재개 불가·계획 자동 승인 «cc-agent-teams» — [피함]」. 적힌 이유는 실험 딱지 + 재개 불가 + 계획 자동 승인 셋이다. audit §7 의 출처는 https://code.claude.com/docs/en/agent-teams (audit 636행). OQ15 는 「[해결 ⟨S31⟩] — 병렬 머지 원칙·SDD 연결 조사 결과를 설계 재료로 어떻게 처분하는가」(282행)."
    touches: []
    decides: [OQ3, OQ4]
  - id: RC4
    path: "docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md"
    anchor: "Non-goal: … 실험 기능(agent teams)을 기반으로 쓰는 것(S31) · 이미 있는 것을 다시 만드는 것(S30)"
    line: 310
    claim: "D33 은 이 로드맵 brief 의 Non-goal 로 적혔다 — 한 인터뷰(한 로드맵)의 확정 항목이고, 레포 전역 규칙으로 적은 자리는 아니다. 같은 Non-goal 줄이 로드맵 묶음 R1~R14 · R2a 15개 파일 27행에 그대로 복사돼 있다."
    touches: []
    decides: [OQ3]
  - id: RC5
    path: "docs/superpowers/specs/2026-10-15-roadmap-control-plane-design.md"
    anchor: "## Constraints — 「실험 기능은 기반으로 쓰지 않는다(D33) — 기반은 작업 목록 · 상태줄 설정 · 진입 skill.」"
    line: 64
    claim: "질문이 지목한 R6 설계문서의 줄은 D33 을 정한 자리가 아니라 받아 적은 자리다(frontmatter source_interview 가 묶음 R6.md). 이 설계에서의 쓰임은 「컨트롤 플레인을 무엇 위에 세우나」이고, 번호 대조 표는 「D33 | 반영 | Constraints — 작업 목록 · 기존 기능 기반, 실험 기능 아님」(210행) · 「S31 | 반영 | Constraints — 실험 기능 제외」(230행)다. 문서 안에 agent teams 라는 말은 없다. Rejected Alternatives 의 기각은 훅 알림 · 세션 시작 훅 · 프로젝트 설정 커밋이고 실험 기능 후보를 따로 검토한 기록은 없다."
    touches: []
    decides: [OQ3]
  - id: RC6
    path: "docs/superpowers/specs/2026-10-17-epic-conductor-design.md"
    anchor: "## Rejected Alternatives — 「agent teams · Workflow 기반」"
    line: 368
    claim: "R5 설계는 D33 · S31 을 받아 대상을 넓혔다 — 「실험 기능(agent teams)과 Workflow 를 기반으로 쓰지 않는다(S31)」(86행), 「agent teams · Workflow 기반 — 실험 기능이고(«cc-agent-teams» — 재개 불가 · 계획 자동 승인), Workflow 는 명시 요청이 필요하다(S31)」(368행). 같은 S31 을 병합 대기열 서비스에도 걸었다(255행 「Mergify · Graphite … 기반으로 쓰지 않는다(S31)」). 미룸 표는 SendMessage 가 「기반으로 쓰지 않기로 한 실험 기능에 속하지 않는지도 함께 확인해야 한다」(559행)고 적는다."
    touches: []
    decides: [OQ3, OQ4]
  - id: RC7
    path: "docs/superpowers/specs/2026-10-19-principles-docs-cleanup-design.md"
    anchor: "## 번호 대조 — 「S31 | 반영 | §1 원칙 6(실험 기능은 기반으로 쓰지 않음 — 이 설계는 새 장치 없음)」"
    line: 216
    claim: "원칙을 CLAUDE.md 로 옮긴 R11 설계는 D33 · S31 을 「원칙 6 있는 것 먼저」에 반영했다고 표에 적었지만(208 · 216행), 원칙 6 의 뜻 문장은 「만들기 전에 레포 안 · 밖의 있는 것을 먼저 검토한다 · 외부 것은 사용자 검토 뒤에만 쓴다」(70행)이고 실험 기능 절은 들어가지 않았다."
    touches: []
    decides: [OQ3, OQ1]
  - id: RC8
    path: "CLAUDE.md"
    anchor: "「**있는 것 먼저.** 만들기 전에 레포 안 · 밖의 있는 것을 검토하고 외부 것은 사용자 검토 뒤 쓴다(철학 P8).」"
    line: 34
    claim: "CLAUDE.md 와 docs/philosophy/devbrew-harness-philosophy.md 에는 「실험」 · experimental 이 없다(두 파일 grep 0건). 철학 P8 의 재사용 줄은 「새로 만든 것은 유지할 표면이 되므로 레포 안 · 밖에 있는 것을 먼저 검토하고, 외부 것은 사용자가 검토한 뒤에 쓴다(P17)」(85행)뿐이다. 두 문장 모두 「검토한다」까지이고 결론의 기본값은 적지 않는다."
    touches: []
    decides: [OQ3, OQ6]
  - id: RC9
    path: "plugins/spec-distill/references/fresh-evidence.md"
    anchor: "원칙 4 행 — 「최신과 안정이 갈리면(새 판 · 실험 기능 · 막 바뀐 정책) 차이를 보이고 선택지로 묻는다」"
    line: 12
    claim: "플러그인 동작 자리에서 「실험 기능」이 나오는 곳은 여기 하나다(plugins · shared 의 .md grep). D33 과 방향이 다르다 — D33 은 기반으로 쓰지 않는다, 이 줄은 차이를 보이고 사용자에게 선택지로 묻는다. 같은 문장이 설계문서 2026-10-19-interview-open-research-design.md 119행에 있고, 그 설계의 Non-goals 68행은 따로 「실험 기능(agent teams)을 기반으로 쓰는 것(S31)」을 적는다. 둘 다 살아 있다."
    touches: []
    decides: [OQ3]
  - id: RC10
    path: "docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.md"
    anchor: "## 5 — 「기각 — agent 팀을 일꾼 기반으로 → 리드 고정 · 재개 불가로 지휘 세션 리프레시와 충돌하는 실험 기능(S4)」"
    line: 482
    claim: "다음 로드맵(2026-11-14)에서 agent teams 가 다시 검토돼 다시 기각됐다. §4 원문 「agent 팀은 리드 고정 · 세션당 팀 하나 · /resume 불가 · 기계 간 공유 불가인 실험 기능이다 «cc-agent-teams» — [피함] — 지휘 세션 리프레시와 팀이 서로를 깨뜨린다 (1차 · 확인 2026-11-14)」(459행). 이유의 무게는 딱지보다 구체 제약(리드 고정 · 재개 불가)에 있다. 근거로 댄 S4 는 선택 「하위 agent + 실행기 칸 (권장)」(audit 461행)이고, 앞 로드맵의 D33 을 인용하지는 않는다."
    touches: []
    decides: [OQ3, OQ4]
  - id: RC11
    path: "docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.md"
    anchor: "☑ confirmed **D33** — 조건 붙은 팀 규칙은 적용 조건(경로 · 단계 · 역할) 칸을 두고 …"
    line: 376
    claim: "번호 충돌: 이 brief 와 그 로드맵(R1.md · R2.md · framing-ledger.md)의 D33 은 「팀 규칙을 스크립트가 골라 시작 묶음에 싣는다」는 다른 결정이다. 「D33」만으로 찾으면 두 결정이 섞인다."
    touches: []
    decides: []
  - id: RC12
    path: "docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md"
    anchor: "「[2차 블로그] 플러그인 monitor 의 한 줄이 알림 하나가 되고 … 대화형 CLI 전용이고 실험 기능이라 형식이 예고 없이 바뀔 수 있다고 적는다.」"
    line: 4064
    claim: "같은 인터뷰의 조사 기록에 「실험 기능」으로 적힌 것이 agent teams 말고 하나 더 있다(플러그인 monitor, 2차 블로그 근거). brief 는 OQ35 를 「mod 하나 … 표시는 mod 감시는 monitor + 자기 소켓(S28)」(311행)으로 닫았다. monitor 가 최종 기반에 들어갔는지, 그 실험 딱지를 사용자에게 보였는지는 이 조사에서 확인하지 못했다."
    touches: []
    decides: [OQ3]
  - id: RC13
    path: "docs/superpowers/interview/2026-11-15-existing-framework-first-interview.audit.md"
    anchor: "라운드 2 — 「선택지: 공식 제공 / 널리 쓰임 / 유지 중 / 실험 기능 제외」 「당신이 답한 것: 공식 제공, 널리 쓰임, 유지 중」"
    line: 55
    claim: "이번 seed 의 Phase 0 에서 「실험 기능 제외」는 여럿 고르기 질문의 넷째 선택지였고 사용자가 고르지 않았다. 라운드 1 의 「에이전트 프레임워크」도 넷째 선택지였고 고르지 않았다(41–42행). audit 148행은 seed 의 「예전 로드맵에서 … 정한 것」이 R6 설계 64행에 실재함을 확인했다고 적는다 — 출처 brief(RC1)까지는 거슬러 가지 않았다."
    touches: []
    decides: [OQ3, OQ4, OQ2]

  # ── 「있는 것 먼저」 규칙의 출처 · 사는 자리 ──
  - id: RC14
    path: "docs/superpowers/specs/2026-10-17-epic-conductor-design.md"
    anchor: "## 결정 기록 — 「결정 · 2026-10-17 · 이해 확인」"
    line: 373
    claim: "「있는 것 검토」 절의 출처는 사용자 발화다 — 「추가로 가능하면 기존에 있던거를 사용할 수 있는지 검토하는 성향이면 좋겠어 레포 내부든 외부든(예시로 페키지 프레임워크 등 항목은 너가 잘 적고 다만 외부는 나한테 검토 받고 사용하는거로) 이번 이번에도 반영이고 향후 devbrew성향에도 반영이야 어디 반영할지도 너가 검토하고」. 사용자 말 자체가 「검토하는 성향」이고, 쓰는 것을 기본으로 하라는 말은 없다. 같은 설계가 에픽 넘김 줄에 「설계문서에 「있는 것 검토」 절(외부 후보는 사용자 승인 뒤에만)」을 넣기로 했다(237행 · AC31)."
    touches: []
    decides: [OQ6]
  - id: RC15
    path: "plugins/spec-distill/references/epic-handoff.md"
    anchor: "「설계문서에 ## 있는 것 검토 절(레포 안에 이미 있는 것을 먼저 찾아 쓰고, 레포 밖 패키지 · 프레임워크 · 서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다)」"
    line: 7
    claim: "설치본에 실려 다른 레포에 닿는 자리는 셋이다 — 이 에픽 넘김 줄, 같은 문장을 가진 skills/pm-interview/references/finishing.md 553행(하나짜리 brief 의 다음 세션 줄), skills/pm-interview/SKILL.md 312–315행의 「있는 것 먼저」 문단(「바깥의 성숙한 것(패키지 · 프레임워크 · 도구)을 웹으로 찾는다 … 바깥 것은 사용자 검토 뒤에만 쓴다 — 후보와 차이를 보이고 묻는다」). 셋 다 찾기 · 적기 · 승인 뒤 쓰기까지이고, 레포 밖 것을 「후보로만 적어」 두라고 한다. 「있으면 쓰는 것이 기본」이나 「직접 만들면 이유 · 승인」은 없다. references/conducting.md 34 · 101행은 이 절을 가리킨다."
    touches: []
    decides: [OQ1, OQ6, OQ7]
  - id: RC16
    path: "docs/superpowers/specs/2026-10-19-principles-docs-cleanup-design.md"
    anchor: "§1 — 「**두 갈래의 「다른 레포」.**」"
    line: 74
    claim: "규칙이 어디에 살아야 하는지에 대해 레포가 이미 적은 답이 있다 — 「CLAUDE.md · 철학 문서는 devbrew 를 개발하는 세션(메모리 없는 다른 기기 · 새 clone 포함)만 읽는다. devbrew 플러그인을 남의 레포에 설치해 쓰는 세션에서는 그 원칙이 플러그인의 동작 자리(skill · reference · 설계 틀 · 넘김 글)에 실려 있어야 지켜진다.」 원칙 6 의 사용자 원문도 이 표에 있다(70행)."
    touches: []
    decides: [OQ1]
  - id: RC17
    path: "docs/superpowers/interview/2026-10-03-plain-language-output-interview.md"
    anchor: "## 5 — 「위험 — 숨은 가정 | CLAUDE.md 에 규칙을 두면 devbrew 사용자 모두에게 닿는다 — 틀림: 설치본에는 plugins/<name>/ 만 들어간다」"
    line: 244
    claim: "같은 물음을 앞선 brief 가 실측 근거로 닫았다(RC1 — shared/README.md#설치본에 들어가지 않는다). 이어지는 두 줄은 shared/ 정본 + 상대 심볼릭 링크가 설치 때 실체화되고(245행), 설치본에서 subagent 의 Read 는 권한 거부라 규칙 파일을 경로로 넘길 수 없다(246행)고 적는다."
    touches: []
    decides: [OQ1]

  # ── 「있는 것 검토」 절 12건 ──
  - id: RC18
    path: "docs/superpowers/specs/2026-10-17-epic-conductor-design.md"
    anchor: "### §8 있는 것 검토 — 「**레포 밖(사용자 승인됨 — `## 결정 기록` 「1 · 외부 후보도 씁 (권장)」).**」"
    line: 255
    claim: "첫 「있는 것 검토」 절. 레포 밖에서 쓴 것은 superpowers skill 9개(「부르기만, 고치지 않음」) · Claude Code 기본 기능(작업 목록 · agent 의 worktree 격리 · SendMessage · PushNotification) · gh(「없으면 강등」)이고, 「새 패키지 · 프레임워크 의존은 넣지 않는다」로 닫는다. 사용자 승인은 묶음 하나(접근 질문 한 번)로 받았고 후보별 승인은 아니다. 그 위에 skill · reference · 스크립트(merge_check.py · conductor_state.py · conductor_ledger.py 등)를 새로 만든다(Files to Modify 329행)."
    touches: []
    decides: [OQ6, OQ7]
  - id: RC19
    path: "docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md"
    anchor: "### §8 있는 것 검토 · 레포 전용 값 — 「**레포 밖**: markdown-it-py(MIT · 4.2.0 · 2026-05 · 의존 mdurl)」"
    line: 216
    claim: "외부 일반 패키지를 후보로 보이고 사용자 결정을 받은 유일한 기록이다. 결정 B2 「테스트에서만 씁니다 (권장)」(318행), 기각 「markdown-it-py 를 실행 때도 — 사용자 환경에 의존이 생긴다(B2)」(311행) · 「bashlex … GPLv3 이고, 원인(읽기 전용 예외)을 치우면 파서가 필요 없다」(310행). 후보에 적은 속성은 라이선스 · 판 · 날짜 · 의존이고, 공식 제공 · 널리 쓰임 · 유지 여부로 가른 문장은 없다. 런타임 판독기는 「표준 라이브러리만 쓴다」(165행)."
    touches: []
    decides: [OQ6, OQ7]
  - id: RC20
    path: "docs/superpowers/specs/2026-10-19-interview-open-research-design.md"
    anchor: "## 있는 것 검토 — 「새로 만든다: `open-researcher` agent 하나 · `references/fresh-evidence.md` 하나.」"
    line: 208
    claim: "Claude Code 내장 agent 를 후보로 보고 기각했다 — 「내장 `general-purpose` agent 는 쓰기 · 실행 도구를 가져 조사 agent 로 쓰지 않는다」, Rejected Alternatives 281행 「레포 규칙(Scoped agents)과 Law 2 에 어긋난다」. 바깥은 「Anthropic 의 다중 agent 조사 사례 … 를 따른다. 외부 패키지 · 도구는 쓰지 않는다」(209행). 같은 설계 §4(131행)가 인터뷰의 「있는 것 먼저」 문단을 만들었다."
    touches: []
    decides: [OQ6]
  - id: RC21
    path: "docs/superpowers/specs/2026-10-20-dependency-portability-design.md"
    anchor: "## 있는 것 검토 — 「기각: Claude Code plugin.json `dependencies` … · Claude Code `userConfig` …」"
    line: 247
    claim: "공식 Claude Code 기능 둘을 후보로 보고 이유와 함께 기각한 뒤 같은 일을 직접 만들었다(판 비교 · 레포 설정 해결자). 이유는 「superpowers 가 없으면 spec-distill 전체가 꺼진다 — U6 과 충돌」 · 「레포 단위로 둘 수 없고 Bash 명령 환경에 없다」. 기각의 주체는 「지휘자 판단 · 2026-10-20 · 설계문서 점검 답 — … superpowers 는 plugin.json `dependencies` 에 올리지 않는다(U6 과 충돌)」(360행)이고, U6 은 「superpowers 가 없을 때」 질문의 답 「지금처럼 + 나머지는 멈춤 (권장)」(349행)이다 — 그 기능을 쓸지 사용자에게 물은 기록은 없다. 레포 밖은 「Renovate 의 기본 브랜치 설정 읽기(방식만 차용). 새 외부 패키지는 쓰지 않는다」(246행)."
    touches: []
    decides: [OQ6, OQ7]
  - id: RC22
    path: "docs/superpowers/specs/2026-10-21-interview-gate-leftovers-design.md"
    anchor: "## 있는 것 검토 — 「레포 밖: 쓰지 않는다. 파이썬 표준 `os.open` 플래그만 쓴다.」"
    line: 225
    claim: "레포 밖 칸을 한 줄로 닫는 꼴이 다섯 설계에 되풀이된다 — 이 문서 · 2026-10-23-rules-docs-cleanup-design.md 394행 「레포 밖: 쓰지 않는다.」 · 2026-10-20-review-engine-leftovers-design.md 238행 · 2026-10-23-r8-device-leftovers-design.md 339행 · dependency-portability 246행의 「새 외부 패키지는 쓰지 않는다」. 다섯 모두 어떤 외부 후보를 찾아보았는지는 적지 않는다(쓰는 git · gh · codex 명령만 적는다). 레포 안 칸은 「쓴다」 · 「맞지 않아 쓰지 않는다」로 스크립트 · 함수 이름을 열거한다."
    touches: []
    decides: [OQ6]
  - id: RC23
    path: "docs/superpowers/specs/2026-10-25-epic-parallel-recommend-design.md"
    anchor: "## 있는 것 검토 — 「레포 안에 있는 것을 먼저 썼다. 레포 밖 패키지 · 서비스는 쓰지 않는다 — 머지 큐는 레포마다 원격에 있으면 읽기만 한다.」"
    line: 190
    claim: "표의 칸이 「필요 | 있는 것 | 이 설계의 쓰임」이고 9행 전부 레포 안 함수 · 문서다. 짝 brief 는 GitHub 머지 큐를 「[취함] — 하나씩 머지하고 합친 뒤 다시 대조하는 원리. devbrew 는 이것을 손 절차로 가진다(1차)」(brief 225행)로 적었다 — 외부 것은 원리만 가져오고 구현은 손 절차 · 레포 장치다."
    touches: []
    decides: [OQ6]
  - id: RC24
    path: "docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md"
    anchor: "## 있는 것 검토 — 「레포 밖 후보: 없음. 질문 도구에 추천 필드가 없고(«cc-sdk-approvals»), PreToolUse 훅은 고르지 않은 길이다(K14).」"
    line: 164
    claim: "Claude Code 기본 기능 둘(질문 도구 필드 · PreToolUse 훅)을 보았고 하나는 기능이 없어서, 하나는 사용자가 고르지 않아서 뺐다. 짝 brief §4 는 훅을 「[피함] — 범위 밖 외부 skill 질문에도 걸리고 결정론은 보안 · 정확성에만(P8), 사용자도 고르지 않음」(brief 215행)으로 적는다."
    touches: []
    decides: [OQ6]
  - id: RC25
    path: "docs/superpowers/specs/2026-10-19-principles-docs-cleanup-design.md"
    anchor: "## 있는 것 검토 — 「안 쓴다: 외부 패키지 · 도구 없음(문서 정리라 필요 없음).」"
    line: 126
    claim: "만들 것이 없는 일에도 절은 채워졌다. 이 설계가 「있는 것 먼저」를 CLAUDE.md 한 줄로 옮겼고(§1 원칙 6), 원칙이 고정 규칙이 되는 것을 Anti-goal 로 적었다(44행 「옮긴 원칙이 「언제나 X」 꼴의 고정 규칙이 되어 모델 판단을 옥죄는 것」) — 계획 2026-10-19-principles-docs-cleanup.md 118행의 락이 원칙 줄에서 「언제나|항상|반드시」를 찾으면 FIXED-RULE WORDING 으로 잡는다."
    touches: []
    decides: [OQ6, OQ7]
  - id: RC26
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/token-baseline.md"
    anchor: "## 있는 것 검토 — ccusage(외부) 행"
    line: 303
    claim: "가장 최근의 「있는 것 검토」. 외부 도구 ccusage 를 「이 기계에 깔려 있지 않다 … 여기서는 다시 확인하지 않았다 | 아니다 — 외부 도구는 사용자 검토 뒤에 쓴다」로 닫고, 레포 안 집계 코드는 「없다 — 이 문서 옆 `token-baseline/` 스크립트로 잰다」(300행)로 새로 만들었다. 「사용자 검토 뒤에 쓴다」가 검토를 청하는 문이 아니라 쓰지 않는 이유로 쓰였다."
    touches: []
    decides: [OQ6, OQ7]

  # ── 같은 뜻의 절(머리 없음) ──
  - id: RC27
    path: "docs/superpowers/specs/2026-10-12-interview-persistent-explore-design.md"
    anchor: "## Rejected Alternatives — 「**내장 Explore 로 레포 조사**」"
    line: 431
    claim: "Claude Code 내장 agent 를 쓰는 쪽이 「C32 쪽」임을 알면서 기각했다 — 「Bash 가 있어 쓰기를 물리적으로 못 막고(Law 2 결), 처분 회계 락의 agent 집합 밖이라 호출이 락에 안 보인다(B3)」. 레포 안 doc-recritic 재사용도 「C32(다시 만들지 않기)보다 역할 왜곡이 크다(B1)」(429행)로 기각. 사용자 결정 B1 「새 판정자 agent (권장)」 · B3 「새 읽기 전용 조사 agent (권장)」(443 · 445행) — 권장 선택지가 「새로 만들기」였다. 있는 것을 못 쓰는 이유가 레포 자신의 규칙(Law 2 · 회계 락)이다 — RC20 과 같은 꼴."
    touches: []
    decides: [OQ6, OQ7]
  - id: RC28
    path: "docs/superpowers/specs/2026-10-15-interview-pm-decompose-design.md"
    anchor: "## Constraints — 「있는 것을 다시 만들지 않는다(C32) — 형식 해석 · 검증은 `roadmap_status.py` …」"
    line: 65
    claim: "「있는 것 검토」 절이 생기기 전 R 에픽 설계 다섯(R0 walking-skeleton · R2 이 문서 · R3 numbered-handoff-coverage 77행 · R4 distill-distortion-devices 68행 · R7 state-storage-redesign 81행)은 C32 를 Constraints 한 줄로 받았고, 열거한 것은 모두 레포 안 스크립트다. 외부 후보를 적은 줄은 맞은 줄에 없었다(맞은 줄만 읽음 — 절 전체는 안 읽음)."
    touches: []
    decides: [OQ6]
  - id: RC29
    path: "docs/superpowers/specs/2026-09-21-designer-lens-review-design.md"
    anchor: "### 1.3 외부 조달 결과 — ponytail 이 준 것과 안 준 것"
    line: 120
    claim: "남의 플러그인에서 기준을 가져오라는 확정 제약(C26)을 실제로 수행한 기록이다 — 「브리프 C26 이 이 단계에 맡긴 조달을 수행했다(DietrichGebert/ponytail, HEAD e3ba2aa, 2026-09-14). 결과는 **절반의 성공**이다」. 준 것(판정 절차 · 보호 경계 · 0건 출구 · finding 형식)은 문면으로 가져오고, 안 준 것은 「ponytail 저장소 전수 grep 0건」으로 확인한 뒤 레포에서 만들었다. 그 전환을 재결정으로 기록했다 — 「「외부에 없더라」까지는 측정이지만 「그러면 리포에서 만든다」는 **결정**이다 … 사용자 동의 2026-09-21(리뷰 라운드 1 · D1.7)」(1022행). 의존으로 들인 것이 아니라 절차 · 어법의 차용이다."
    touches: []
    decides: [OQ6, OQ7]
  - id: RC30
    path: "docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md"
    anchor: "## Rejected Alternatives · Trade-offs — 「1st-party `/code-review` 로 탐지·검증 대체」 · 「qg 소유 정확성 리뷰어 신설」"
    line: 621
    claim: "부품마다 공식 대체를 묻는 칸을 둔 유일한 설계다 — 「한 줄 표(D18)의 칸은 「부품(하는 일) · 깔고 있는 가정 · 1st-party 대체 · 교훈 … · 처분」이다」(214행). 결과는 양쪽이다: 공식 /code-review 로 바꾸는 것은 기각(「다이어트 지렛대(dispatch 프롬프트·재비판)를 잃는다. 로컬에서 REVIEW.md 를 안 읽고 cleanup 을 낸다. qg 가 모델 호출로 부를 수 있는지 미확인이다」), 표의 대체 칸은 「없음(`/code-review` 는 판정이 없다)」 · 「없음(`/code-review` 는 Claude 만)」(343 · 357행). 반대로 직접 만드는 쪽도 기각했다 — 「qg 소유 정확성 리뷰어 신설 | 사용자가 외부 플러그인 방식 유지를 골랐다(K2)」(622행), 「K2. 외부 플러그인 리뷰어(pr-review-toolkit)를 쓰는 방식은 유지한다」(104행). 사용자 선택이 결론을 「외부 것 쓰기」로 정한 기록이다."
    touches: []
    decides: [OQ6, OQ7]
  - id: RC31
    path: "docs/archive/specs/2026-07-19-plugin-audit-plugin-design.md"
    anchor: "「→ **재발명하지 말고 감싸라.**」 · Non-goals 「**재발명 금지 — 위임/감싸기.**」"
    line: 67
    claim: "규칙이 생기기 전(2026-07)에 공식 생태계를 먼저 조사하고 감싸기로 정한 기록이다 — 「능력 확장 범위는 **4각도 외부 리서치**(공식 Claude Code 생태계 / devbrew 내부 / 성숙 audit·lint 도구 / LLM 감사 방법론 2025–26)로 증거를 세운 뒤 사용자가 골랐다」(61행), 「plugin-dev 공식 검증 스크립트를 감싸 … (재구현 금지, \"검증기를 먼저 검증\"; §11)」(89행), 「plugin-audit은 이들을 **감싸거나 가리킬 뿐 재구현하지 않는다**」(107행). 같은 문서가 「니치는 비어 있다」(64행)로 본체는 새로 만든다."
    touches: []
    decides: [OQ6, OQ7]
  - id: RC32
    path: "docs/superpowers/specs/2026-08-05-agent-transparency-design.md"
    anchor: "「**output style**(본체, 시스템 프롬프트에 붙는다)」"
    line: 36
    claim: "Claude Code 기본 기능을 본체로 삼은 기록은 찾은 것 가운데 이것 하나다. 짝 brief(archive/interview/2026-08-02-comprehension-debt-plugin-interview.md 336–339행)가 output styles · statusline · subagent 패널을 「[취함] … devbrew 등장 0회」 · 「플랫폼이 이미 상당 부분 shipping」으로 적었고, 설계는 대가를 「`Explanatory` 스타일이 꺼진다 … 사용자가 이 대가를 알고 선택했다」(52–56행)로 적는다. 이 플러그인은 뒤에 제거됐다(specs/2026-09-20-remove-agent-transparency-design.md — 제거 이유는 이 조사에서 읽지 않았다)."
    touches: []
    decides: [OQ6]
  - id: RC33
    path: "docs/superpowers/specs/2026-09-21-python-floor-and-uv-design.md"
    anchor: "## Rejected Alternatives — 「R2 — `uv run --script` 로 출하까지 조달.」"
    line: 419
    claim: "일반 도구(uv · ruff)를 본 기록. 출하 표면까지 uv 에 기대는 것은 「요구사항이 「Python」에서 「uv」로 바뀌고 uv 미설치 사용자는 즉사한다」로, ruff 는 「181 파일 diff 가 버전 회귀 판별을 오염시킨다」(424행)로 기각. 외부 도구를 개발 쪽에만 두는 꼴은 RC19 와 같다 — 설치한 사용자 환경에 의존을 만들지 않는다는 이유다. Rejected Alternatives 만 읽었다."
    touches: []
    decides: [OQ6]
  - id: RC34
    path: "docs/superpowers/interview/2026-07-26-qg-impact-driven-qa-runtime-interview.md"
    anchor: "## 3. External Landscape — 「**사내 prior-art (재발명 금지).**」 · 「**로컬 하니스 선례**」"
    line: 74
    claim: "남의 하니스(gstack · compound-engineering · oh-my-codex · ECC · ouroboros)를 file:line 으로 읽고 [취함]/[피함]을 단 기록이다. 다만 표는 「인터뷰 종료 후」 얕은 스캔으로 붙었고 결론은 그 전에 났다 — 「LD5(결정론=백스톱)는 레퍼런스를 보고 정한 게 아니라 steelman·premortem으로 독립 도달한 뒤 레퍼런스에서 같은 모양을 *확인*한 것이다」(167행). 「바닥부터 만들기 금지」를 적으면서(175행) OQ1 은 「위 제안이 레퍼런스보다 앞서 있으므로 설계에서 새로 만들어야 한다」(156행)로 닫는다. 설계(archive/specs/2026-08-01-qg-impact-driven-qa-runtime-design.md)는 문구 · 방식 일부를 이식하고(339행) 명명 모드 · baseline.json · 별도 플러그인은 기각했다(1203 · 1208 · 1211행). 같은 이름의 brief 가 docs/archive/interview/ 에도 있다."
    touches: []
    decides: [OQ6]
  - id: RC35
    path: "docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.md"
    anchor: "## 4. External Landscape — «cc-mods» · «herdr» · «thrum» · «mcp-agent-mail» · «superpowers-sdd» · «mattpocock» · «pstack»"
    line: 465
    claim: "외부 후보를 가장 많이 다룬 brief 다. 취함: mod(「표시 전용으로 묶고 감시자를 겸하게 한다」) · superpowers SDD(「자체 검수 상한을 여기에 맡긴다」). 피함: herdr(「특정 도구 의존이라 실행기 칸의 선택지로만」) · mcp_agent_mail(「상주 서버 의존」) · agent 팀. 중립: Thrum(「선례로만」) · Matt Pocock skills · pstack(「단계표의 사람 단계로」). 잠정 방향 271행 「바닥부터 만들지 않고 있는 장치(SDD 고침 루프 · Claude Code 세션 받은 편지함 · mod)에 맡긴다」. 사용자 확정 C5 「herdr 같은 방식까지 검토하되 특정 외부 도구에 하드코딩되거나 의존이 생기는 것은 피한다」(348행) — 사용자 자신이 외부 도구 의존을 피하라고 한 제약이다. 선택지를 화면에 보인 순서까지 적혀 있다(408 · 411행)."
    touches: []
    decides: [OQ4, OQ6, OQ7]
  - id: RC36
    path: "docs/superpowers/interview/2026-11-14-qg-epic-roadmap-intent-review-brief-interview.md"
    anchor: "## 4 — «sdk-user-input» · «claude-skills-verify» · «plugin-evals»"
    line: 259
    claim: "공식 기능을 보고 대부분 쓰지 않기로 한 brief. Agent SDK canUseTool 「[중립] — 끝까지 자동 시험의 길이지만 새 의존 · 정한 답이 사람과 다름(S9 로 쓰지 않음)」, 번들 /run · /verify 「[중립] — /verify 는 사람이 불러 볼 자리로만(S27)」(처음엔 S4 로 쓰기로 했다가 재결정 — 286행). 레포 안 재사용은 기각 줄로 — 「이름 풀이를 qg 안에 새로 만들기 → 설치본 qg 는 spec-distill 스크립트를 부를 수 없고 기계 출처가 이미 spec-distill 에 있다」(295행). 묶음 R3.md 66행은 같은 내용을 「(있는 것 먼저)」로 적는다."
    touches: []
    decides: [OQ6]
  - id: RC37
    path: "docs/superpowers/interview/2026-08-22-subagent-adjudication-contract-interview.md"
    anchor: "## 4 — 「superpowers SDD 처분 규율 … [피함]」"
    line: 210
    claim: "사용자가 외부 것을 골랐다가 레포 것으로 돌아선 기록 — 「**사용자가 S6에서 지목·S7에서 선택한 원안**이었으나 S8에서 전환. devbrew가 더 강한 형태 보유(수신자가 원장이 아니라 사용자)」. 같은 절 207행은 외부 방식에 「[중립] — 근거 비교 축은 유용하나 devbrew는 이미 refuter/grounding으로 구현」을 단다."
    touches: []
    decides: [OQ6]
  - id: RC38
    path: "docs/superpowers/interview/2026-10-08-skill-only-surface-interview.md"
    anchor: "## 4 — 「`claude plugin validate --strict` 를 manifest 의 권위 있는 검사로 둔다 «cc-plugins-ref» — [취함]」"
    line: 214
    claim: "직접 만든 락의 일부를 공식 검사기에 넘긴 기록 — 「락의 manifest 몫을 공식 검사기에 맡기는 근거」. brief §4 가운데 「직접 만든 것을 공식 도구로 바꾼다」는 방향이 적힌 드문 줄이다(설계에서 실제로 넘겼는지는 확인하지 않았다)."
    touches: []
    decides: [OQ6]
  - id: RC39
    path: "docs/superpowers/interview/2026-09-21-interview-research-specialization-interview.md"
    anchor: "## 4 — «claude-code-subagents» — [취함]"
    line: 336
    claim: "「하니스가 read-only 코드베이스 탐색 agent 와 계획 전 조사 agent 를 이미 기본 탑재한다 … 전담 장치는 만드는 문제가 아니라 배선 문제일 수 있다는 근거」로 적었으나, 뒤 설계들은 내장 agent 를 기각하고 전용 agent 를 만들었다(RC20 · RC27). 조사 단계의 「쓸 수 있다」가 설계 단계에서 레포 규칙에 막힌 사례다."
    touches: []
    decides: [OQ6]
  - id: RC40
    path: "docs/archive/interview/2026-07-12-project-init-audit-interview.md"
    anchor: "## 3. External Landscape — 「⚠️ **레퍼런스는 웹에만 있지 않다 — 디스크에 있다**」"
    line: 119
    claim: "설치된 공식 플러그인을 겹침 후보로 적은 기록 — 「`claude-code-setup`(**project-init과 정면으로 겹치는 공식 플러그인**)」(122행), 「**내장 `/init` 존재** … [중립] — project-init Phase 0 … 과 **기능 중복 의심**. 위임/차별화 판단은 OQ3」(132행). 겹침을 판단하지 않고 열린 질문으로 넘겼다. 짝 설계(archive/specs/2026-07-12-project-init-audit-workflow-design.md 387행)는 「겹치는지 아닌지는 축④가 판정한다」로 고치고 「다른 플러그인은 이렇게 한다」 논거를 무효로 둔다(94행 C5)."
    touches: []
    decides: [OQ6]

  # ── plans · roadmaps ──
  - id: RC41
    path: "docs/superpowers/plans/2026-10-17-epic-conductor-2-seams.md"
    anchor: "「# R5 계획 2 AC31 — … 있는 것 검토 · 연계 · 레포 전용 값」 락"
    line: 301
    claim: "plans 에는 후보를 검토한 독립 기록이 없다. 나오는 것은 절을 쓰라는 문면과 그 문면을 재는 락이다 — 이 계획의 락은 넘김 줄에 '## 있는 것 검토 절' · '사용자가 승인한 뒤에만' 글자가 있는지 본다(305행), 2026-10-19-r10-plan2-end-gates.md 200 · 213행이 같은 문장을 finishing.md 에 넣고, 2026-10-25-epic-parallel-recommend.md 538행이 「꼼꼼히 조사해 ## 있는 것 검토 절에 적는다」를 더한다. 락은 절이 있는지를 재고 절의 결론은 재지 않는다. 설계문서 리뷰 프로필이 이 절을 보는지는 조사하지 않았다."
    touches: []
    decides: [OQ6]
  - id: RC42
    path: "docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R11.md"
    anchor: "범위 — 「원칙 옮기기(있는 것 먼저 검토 — 레포 안 · 밖, 외부는 사용자 검토 뒤 · …)」"
    line: 22
    claim: "roadmaps 폴더의 관련 줄은 brief 의 사본이다 — 묶음 15개(R1~R14 · R2a)가 Non-goal 줄과 S31 원문을 싣고, D33 확정 줄은 R5.md 43행 · R6.md 44행 · R11.md 38행에 있으며, roadmap.md 76행 · 계획 2026-10-11-roadmap-walking-skeleton.md 1768 · 1947 · 1958행은 번호 목록으로만 D33 을 싣는다. roadmap.md 193행과 이 줄이 R11 의 범위로 「있는 것 먼저 검토」를 적는다."
    touches: []
    decides: [OQ3]

  # ── 이번 seed 가 스스로 적은 것 ──
  - id: RC43
    path: "docs/superpowers/interview/2026-11-15-existing-framework-first-interview.audit.md"
    anchor: "## 3. 긴 초안 12 — 「셋 다 「검토한다」까지이고 「있으면 쓰는 것이 기본」이라고 적은 자리는 없다.」"
    line: 100
    claim: "Phase 0 저자의 관찰은 이 조사 결과와 맞는다(RC8 · RC15). 사용자 답은 라운드 3 「검토가 형식이었다」(75행)와 확인받은 풀이 「있는 것을 검토했다고 적기는 했지만 결론은 늘 직접 만들기였다」(85행)이고 「구체적인 사건은 적지 않았다」(99행). 승인은 라운드 2 「승인 유지」(58–60행 — 선택지 「승인 유지 / 새로 들일 때만 / 기준 넘으면 묻지 않음」)다. 「결론은 늘 직접 만들기」는 「있는 것 검토」 절 12건에서 9건 직접 · 2건 일부 · 1건 해당 없음으로 대체로 맞지만, 그 전 기록에는 외부 것을 유지 · 감싸기 · 본체로 삼은 사례가 있다(RC30 · RC31 · RC32)."
    touches: []
    decides: [OQ6, OQ7]
unanswered: "「있는 것 검토」가 형식에 그친 원인을 직접 적은 문서는 없다 — 위 주장들은 정황(규칙 문면이 검토까지만 요구 · 락이 절의 존재만 잼 · 레포 밖 칸이 한 줄로 닫힘 · 내장 기능이 Law 2 · 회계 락 · 설치본 의존 회피에 막힘)이고 인과는 확인하지 못했다. 검증 기준 셋(공식 · 널리 쓰임 · 유지 중)을 적용하거나 모두 · 하나를 가른 과거 기록은 없다(OQ2). 사소한 변경에 검토를 거는지 다룬 기록도 없다(OQ5). D33 을 고를 때 함께 보인 다른 선택지는 audit 에 없다."
```

## 4. 읽은 깊이와 한계

- 절 전체를 읽은 것: 「있는 것 검토」 12건, control-plane 설계 전문, persistent-explore 설계의 Constraints · Rejected Alternatives, designer-lens §1.3, plugin-audit 설계 56–111행, brief 30건의 § External Landscape(대부분 §5 기각까지).
- 맞은 줄만 읽은 것: R0 · R2 · R3 · R4 · R7 설계, python-floor-and-uv(Rejected Alternatives 만), project-init-audit 설계, qg-impact 설계, agent-transparency 설계, qg-v10 설계. 이들의 분류는 그만큼 약하다.
- 읽지 않은 것: docs/archive/plans/ 의 「External Landscape」 맞은 줄(brief 형식을 구현하는 계획으로 보이나 열지 않았다), docs/superpowers/roadmaps/ 의 flexibility-audit.md · measurements.md, External Landscape 머리가 없는 brief · seed 6건(2026-09-01 둘 · 2026-09-05 둘 · 2026-11-13 · 2026-11-15).
- 「없음」 · 「0건」은 Grep 결과다 — Grep 은 심볼릭 링크와 숨김 디렉토리를 건너뛰므로 하한이다.
- 설계류 「위에서 / 일부 / 직접」과 brief 의 17 / 13 갈래는 조사자가 붙인 분류이고 문서 자신의 말이 아니다.


### 조사 4 — open-researcher · R1 · 묶음 1

조사 결과 (확인한 날 2026-11-15, 공식 문서는 code.claude.com/docs 의 지금 판을 직접 읽음).

읽는 법 세 가지.
- `supports` 는 이렇게 붙였다: `current` = 지금 상태(규칙이 이 레포의 CLAUDE.md 에 살고, 예전 로드맵이 실험 기능을 기반에서 뺌)를 받치는 사실, `alternative` = 다른 자리 · 다른 결론의 재료, `both` = 어느 쪽에도 쓰이는 중립 사실. 주문에 기준이 없어 내가 정한 것이니 본체가 다시 붙여도 된다.
- `touches` 는 전제 목록을 받지 못해 전부 빈 배열이다.
- 전부 문서 근거다. 실제 동작은 재지 않았다.

판: 레포가 적어 둔 Claude Code 판은 2.1.303(네 플러그인 `dependencies.md`, 잰 날 2026-10-22, 강도 「기록」), 최신 upstream 은 2.1.325(2026-11-13). 그 사이에 걸리는 판 조건이 있다 — skill 설명의 compaction 뒤 재주입(2.1.304+), 플러그인 `agent` 설정 deprecated(2.1.323), Code Mode(2.1.323+).

```yaml
evidence:
  # ── 플러그인이 실을 수 있는 것의 전체 목록 ──
  - url: "https://code.claude.com/docs/en/plugins/manifest-reference.md"
    supports: both
    claim: "plugin.json 필드 표와 Standard layout 표가 여는 컴포넌트는 skills · commands · agents · hooks · mcpServers(.mcp.json) · lspServers(.lsp.json) · outputStyles(output-styles/) · workflows · channels · userConfig · bin/ 와 `experimental` 컨테이너 아래의 themes · monitors · evals 다. CLAUDE.md · rules · memory 를 싣는 키나 기본 폴더는 표에 없다. 알 수 없는 최상위 키는 벗겨지고 플러그인은 로드된다."
    touches: []
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/manifest-reference.md"
    supports: alternative
    claim: "플러그인 루트의 CLAUDE.md 는 컨텍스트로 로드되지 않는다. 원문: 「A `CLAUDE.md` at the plugin root isn't loaded as context, and `claude plugin validate` warns when it finds one. To include instructions that load into Claude's context, put them in a skill.」"
    touches: []
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/components.md"
    supports: alternative
    claim: "공식 안내는 플러그인의 지시를 skill 로 쓰라는 것이고, 매번 지켜져야 하는 규칙은 hook 으로 쓰라는 것이다. 원문: 「To include instructions in a plugin, write them as a skill. Claude Code doesn't load a `CLAUDE.md` at the plugin root…」 「If a rule must hold every time, such as blocking edits to protected files, add it to the plugin as a hook rather than a skill.」"
    touches: []
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  # ── 후보 1: skill (description 자동 발동) ──
  - url: "https://code.claude.com/docs/en/skills.md"
    supports: alternative
    claim: "skill — (a) 플러그인이 `skills/<name>/SKILL.md` 로 싣는다. (b) 플러그인이 켜진 곳이면 어디서나 `/plugin:skill` 로 로드된다. (c) 이름 · description 목록은 세션 시작 때 들어가 매 요청에 실리고, 본문은 사용자가 부르거나 Claude 가 description 을 보고 고를 때만 들어간다(「Description in context, full skill loads when invoked」). 들어간 본문은 메시지 하나로 남고 다음 턴에 다시 읽지 않는다. `disable-model-invocation: true` 면 설명도 컨텍스트에서 빠진다. (d) 안정성 딱지 없음(이 페이지는 요약기를 거쳐 읽었다)."
    touches: []
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/skills.md"
    supports: both
    claim: "skill 목록에는 예산이 있다. description + when_to_use 는 항목당 1,536자에서 잘린다(`skillListingMaxDescChars` 로 조정). 목록 전체 예산은 컨텍스트 창의 1% 이고(`skillListingBudgetFraction` · `SLASH_COMMAND_TOOL_CHAR_BUDGET` 로 조정), 넘치면 덜 부른 skill 의 설명부터 버리고 이름만 남긴다. 플러그인 skill 은 `skillOverrides` 의 영향을 받지 않는다(「Manage those through `/plugin` instead」). 문제 해결 절은 매번 지켜져야 하는 규칙을 hook 으로 옮기라고 적는다."
    touches: []
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  # ── 후보 2: hook 의 추가 컨텍스트 ──
  - url: "https://code.claude.com/docs/en/plugins/components.md"
    supports: alternative
    claim: "hook — (a) 플러그인이 `hooks/hooks.json` 이나 매니페스트 `hooks` 키로 싣는다. (b) 세션이 플러그인을 로드할 때 등록되고 skill · command 사용을 기다리지 않는다. 원문: 「A plugin's hooks don't wait for one of the plugin's skills or commands to be used. Claude Code registers them when a session loads the plugin, and they fire on their events from then on.」 같은 매니페스트 이름의 플러그인 둘이 켜져 있으면 한쪽의 hooks.json 훅은 빠진다."
    touches: []
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/hooks.md"
    supports: alternative
    claim: "hook 이 모델 컨텍스트에 글을 넣는 길(c): SessionStart · SubagentStart 는 대화 시작, 첫 프롬프트 앞. UserPromptSubmit · UserPromptExpansion 은 제출된 프롬프트 옆(매 턴). PreToolUse · PostToolUse · PostToolUseFailure · PostToolBatch 는 도구 결과 옆. Stop · SubagentStop 은 턴 끝. PostModelSwitch 는 전환 뒤 다음 요청. 평문 stdout 이 컨텍스트가 되는 이벤트는 UserPromptSubmit · UserPromptExpansion · SessionStart · PostModelSwitch 넷이고, 나머지는 `hookSpecificOutput.additionalContext` 를 쓴다. 주입은 hook 이름으로 시작하는 system reminder 로 들어간다. SessionStart matcher 는 startup · resume · clear · compact · fork 이고 `command` · `mcp_tool` 타입만 받는다. Setup · InstructionsLoaded 는 컨텍스트를 못 넣는다."
    touches: []
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/hooks.md"
    supports: both
    claim: "hook 주입 글에는 상한이 있다. `additionalContext` · `systemMessage` · `initialUserMessage` · 평문 stdout 은 문자열마다 10,000자다. 넘으면 세션 폴더 파일로 빠지고 경로와 앞 2,000자 미리보기만 들어간다. 원문: 「Claude Code doesn't ask Claude to read the file, so keep anything Claude must always see within the cap.」"
    touches: []
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/hooks.md"
    supports: current
    claim: "SessionStart 절은 정적 컨텍스트에 CLAUDE.md 를 권한다. 원문: 「For static context that doesn't require a script, use CLAUDE.md instead.」 memory 페이지는 AGENTS.md 를 찍어 내던 SessionStart 훅을 지우라고 적는다(「A `SessionStart` hook that prints `AGENTS.md`: remove it.」). 뒤 문장은 AGENTS.md 를 직접 읽게 된 뒤의 중복 얘기이고 플러그인 규칙 전달 일반을 말하는 것은 아니다."
    touches: []
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/hooks.md"
    supports: both
    claim: "hook 의 (d) 안정성 표기: 읽은 범위에서 딱지는 handler 타입 하나에만 있다 — 「Agent hooks are experimental and may change.」 command · http · mcp_tool · prompt 타입과 SessionStart · UserPromptSubmit 이벤트에는 실험류 딱지가 보이지 않았다. 이 페이지는 약 29만 자 중 앞 20만 자만 요약기를 거쳐 읽었다."
    touches: []
    decides: [OQ1, OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/settings-reference.md"
    supports: both
    claim: "플러그인 hook 은 사용자 · 조직 설정으로 꺼진다. 관리형이 아닌 설정 파일의 `disableAllHooks` 는 user · project · local · plugin hook 을 끄고(관리형 hook 과 관리형 `enabledPlugins` 가 강제로 켠 플러그인의 hook 은 남는다) mod 도 멈춘다. `allowManagedHooksOnly` 는 플러그인 hook 을 막되 관리형으로 강제 활성된 플러그인의 hook 은 예외다."
    touches: []
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  # ── compaction 뒤에 무엇이 남는가 ──
  - url: "https://code.claude.com/docs/en/context-window.md"
    supports: both
    claim: "「What survives compaction」 표: 시스템 프롬프트와 output style 은 그대로 적용. 프로젝트 루트 CLAUDE.md 와 범위 없는 rules 는 디스크에서 재주입. skill 설명은 다시 만들어 재주입(「Requires Claude Code v2.1.304 or later」 — 레포 기록 판 2.1.303 보다 한 판 위). 부른 skill 본문은 skill 당 5,000 토큰 · 합계 25,000 토큰 상한으로 재주입하고 오래된 것부터 버린다. hook 이 앞서 넣은 컨텍스트는 대화와 함께 요약된다. `compact` source 에 맞는 SessionStart hook 은 다시 돌아 출력이 압축된 컨텍스트에 더해진다. `paths:` rules 와 하위 폴더 CLAUDE.md 는 필요할 때 다시 로드."
    touches: []
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  # ── 후보 3: output style ──
  - url: "https://code.claude.com/docs/en/output-styles.md"
    supports: alternative
    claim: "output style — (a) 플러그인이 `output-styles/` 로 싣는다. (b) 기본은 사용자가 `/output-style` 로 골라야 하지만 frontmatter `force-for-plugin: true` 가 있다. 원문: 「Plugin output styles only. Set to `true` to apply this style automatically whenever the plugin is enabled, without requiring users to select it. Overrides the user's `outputStyle` setting. If multiple enabled plugins set this, Claude Code uses the first one loaded.」 (c) 「Claude Code sends the active style's instructions with every request」. (d) 실험류 딱지 없음(전문을 읽음). 제약: 한 번에 하나만 활성. 커스텀 style 은 `keep-coding-instructions: true` 가 없으면 전체 시스템 프롬프트의 소프트웨어 엔지니어링 지시 절을 뺀다. fork 가 아닌 subagent 에는 적용되지 않는다. 문서는 이 기능을 역할 · 어조 · 응답 형식용으로 설명한다."
    touches: []
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  # ── 후보 4: MCP 서버 instructions ──
  - url: "https://code.claude.com/docs/en/mcp.md"
    supports: alternative
    claim: "MCP 서버 instructions — (a) 플러그인이 `.mcp.json` 이나 매니페스트로 서버를 싣는다. (b) 「When you enable a plugin, Claude Code starts its MCP servers automatically」. 프로젝트 `.mcp.json` 과 같은 서버별 승인을 거친다는 문장은 레포에 체크인된 project-scope 플러그인에만 있다. (c) 「Only tool names and server instructions load at session start」. (d) 실험류 딱지 없음. 제약: instructions 는 4,096자에서 잘린다(v2.1.296 전에는 2,048자). 문서가 말하는 용도는 Claude 가 그 서버 도구를 언제 찾을지 알게 하는 것이다."
    touches: []
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  # ── 후보 5: agents · commands · 플러그인 설정 ──
  - url: "https://code.claude.com/docs/en/sub-agents.md"
    supports: both
    claim: "agent(subagent) — (a) 플러그인이 `agents/*.md` 로 싣는다. (b) 플러그인이 켜지면 `plugin:name` 으로 쓸 수 있다. (c) 본문은 그 subagent 가 뜰 때 그 subagent 의 시스템 프롬프트로만 들어가고 메인 대화에는 안 들어간다. 메인 스레드에 얹으려면 `--agent <name>` 이나 설정 `agent` 가 필요하다. fork 가 아닌 subagent 의 시작 컨텍스트는 자기 시스템 프롬프트 · 위임 메시지 · CLAUDE.md 계층 전체(프로젝트 rules · 관리형 포함) · git status · `skills` 필드로 미리 싣는 skill 본문이다. 메인 대화 기록 · output style · auto memory 는 안 간다. 플러그인 agent 에서는 frontmatter `hooks` · `mcpServers` · `permissionMode` · `initialPrompt` 가 무시된다. (d) 페이지 수준의 실험 딱지는 없고 frontmatter 에 `experimental` 맵(`cacheTtl`)만 있다."
    touches: []
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/changelog.md"
    supports: both
    claim: "플러그인이 자기 agent 를 메인 스레드 기본값으로 싣는 길은 2.1.323 에서 deprecated 다. 원문: 「Deprecated a plugin's `agent` setting: it still applies, and now warns at startup, in `claude plugin list` and in `claude plugin validate`」. 지금의 manifest reference 필드 표와 Standard layout 에는 플러그인 루트 `settings.json` 이나 `settings` 키가 없다."
    touches: []
    decides: [OQ1, OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/81320"
    supports: both
    claim: "플러그인 루트 `settings.json`(통하는 키는 `agent` · `subagentStatusLine` 둘뿐이라는 설명)은 검색 결과 요약으로만 봤고 공식 문서의 해당 문장을 직접 읽지 못했다. 그 요약이 인용한 커뮤니티 README 는 2.1.323 이 `subagentStatusLine` 을 없앴다고 적어 공식 문서 요약과 어긋난다 — 어느 쪽이 지금 맞는지 확인하지 못했다."
    touches: []
    decides: []
    source_kind: secondary
    checked_at: "2026-11-15"
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/plugins/components.md"
    supports: both
    claim: "command — (a) 실을 수 있다(`commands/`). (c) 사용자가 이름으로 부를 때만 들어간다. (d) deprecated 딱지는 아니고 옛 형식으로 적혀 있다. 원문: 「Commands are the older format, and skills supersede them for new work.」"
    touches: []
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  # ── 후보 6: monitors · mods ──
  - url: "https://code.claude.com/docs/en/plugins/components.md"
    supports: alternative
    claim: "monitor — (a) 플러그인이 `monitors/monitors.json` 이나 `experimental.monitors` 로 싣는다. (b) 기본 `when: always` 면 세션 시작과 플러그인 reload 때 뜬다. (c) 출력이 Claude 에게 알림으로 간다. (d) 매니페스트 키가 `experimental` 컨테이너 아래다(「whose manifest shape may still change」). 제약: `-p` 에서는 안 뜬다. 레포에 체크인된 project-scope 플러그인의 monitor 는 로드되지 않는다. feature-flag fetch 가 꺼진 세션(Bedrock 등)은 v2.1.310+ 가 필요하다. sandbox 밖에서 사용자 권한으로 돈다."
    touches: []
    decides: [OQ1, OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/mods/overview.md"
    supports: alternative
    claim: "mod — (a) 플러그인의 `hooks/hooks.json` 이 `modules` 키로 JS/TS 모듈을 가리키면 그 플러그인이 mod 다. (b) 「Mods are on by default」(터미널 v2.1.287+, Desktop v2.1.286+) — 플러그인을 깔면 로드된다. (c) 이벤트(tool call · 제출된 프롬프트 · 턴)를 관찰 · 재작성 · 대답할 수 있고 「rewrite a prompt or a tool call, submit a prompt as if you had typed it」 가 가능하다고 적혀 있다. 내장 mod `cc-plugin-agents-md` 는 AGENTS.md 를 프로젝트 지시로 로드한다(소스가 anthropics/claude-code 의 `mods/agents-md` 에 공개). (d) 개요 페이지에 실험류 딱지는 없고 early access 때의 `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS` 는 이제 무시된다고 적는다. 제약: 사용자 권한으로 sandbox 없이 도는 코드다. `disableAllHooks` · `--safe-mode` · 조직의 `allowManagedModsOnly` 로 멈춘다. 제3자 mod 가 상시 지시를 넣는 전용 API 를 갖는지는 확인하지 못했다(mods reference · events · api 페이지는 읽지 않았다)."
    touches: []
    decides: [OQ1, OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: uncertain

  # ── 후보 7: CLAUDE.md · rules · import · 사용자/조직 단위 ──
  - url: "https://code.claude.com/docs/en/memory.md"
    supports: current
    claim: "CLAUDE.md 와 rules 는 플러그인 컴포넌트가 아니라 파일 위치로 정해진다. CLAUDE.md 는 관리형(OS별 경로) · 사용자(`~/.claude/CLAUDE.md`) · 프로젝트(`./CLAUDE.md`, `./.claude/CLAUDE.md`) · 로컬(`./CLAUDE.local.md`)이고, 작업 폴더와 그 위 폴더의 것은 시작 때 전부 이어 붙여 로드되며 하위 폴더 것은 그 폴더 파일을 다룰 때 로드된다. `.claude/rules/*.md` 는 `paths` 가 없으면 시작 때 `.claude/CLAUDE.md` 와 같은 우선순위로 로드되고 `paths` 가 있으면 맞는 파일을 읽거나 고칠 때 로드된다. `~/.claude/rules/` 는 그 기계의 모든 프로젝트에 적용된다. 전달 방식: 「CLAUDE.md content is delivered as a user message after the system prompt, not as part of the system prompt itself」. 이 페이지(전문을 읽음)에 플러그인이 CLAUDE.md 나 rules 를 보탠다는 문장과 실험류 딱지는 없다."
    touches: []
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/memory.md"
    supports: alternative
    claim: "CLAUDE.md 의 `@path` import 는 상대 · 절대 · `~/` 경로를 받고 최대 4단계까지 재귀하며, import 한 파일은 그 CLAUDE.md 와 함께 시작 때 로드된다. 프로젝트 파일이 작업 폴더 밖을 import 하면 그 프로젝트에서 처음 한 번 승인 대화상자가 뜨고 거절하면 계속 꺼진다. 사용자 범위 파일의 import 는 대화상자 없이 로드된다(Cowork 데스크톱 세션은 예외). `.claude/rules/` 는 symlink 를 받되 작업 폴더 밖을 가리키면 external import 로 취급한다. AGENTS.md 는 v2.1.277+ 에서 CLAUDE.md 가 없을 때 직접 읽는다. 플러그인 설치 경로를 import 하는 안과 맞닿는 사실 하나: manifest reference 는 `${CLAUDE_PLUGIN_ROOT}` 가 판마다 바뀐다고 적는다."
    touches: []
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/memory.md"
    supports: alternative
    claim: "조직 단위: 관리형 CLAUDE.md(macOS `/Library/Application Support/ClaudeCode/CLAUDE.md` 등)와 managed-settings 의 `claudeMd` 키가 있다. 그 기계의 모든 사용자 · 모든 레포에 적용되고 user · project CLAUDE.md 보다 먼저 로드되며 `claudeMdExcludes` 로 뺄 수 없다. `claudeMd` 는 managed/policy 설정에서만 통한다(「Setting `claudeMd` in user, project, or local settings has no effect」). 배포는 플러그인이 아니라 MDM · 관리형 설정이다."
    touches: []
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/features-overview.md"
    supports: both
    claim: "공식 비교표: CLAUDE.md 는 매 세션 자동 로드이고 「"Always do X" rules」 에 맞다. skill 은 필요할 때 로드(설명은 매 요청). hook 은 Claude 의 결정 없이 이벤트에 발화하고 출력을 돌려주지 않으면 컨텍스트 비용이 0. 플러그인은 「packaging layer」 로 「bundles skills, hooks, subagents, and MCP servers」. 원문: 「An instruction like "never edit `.env`" in CLAUDE.md or a skill is a request, not a guarantee.」 CLAUDE.md 는 모든 층이 동시에 더해지고 hook 은 출처와 무관하게 합쳐진다."
    touches: []
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  # ── 「설치한 어느 레포에서든 · 추가 작업 없이」의 조건 ──
  - url: "https://code.claude.com/docs/en/plugins/install.md"
    supports: both
    claim: "설치 범위: user scope 는 「enabled for you in every project on this machine」(`~/.claude/settings.json` 의 `enabledPlugins`). project scope 는 `.claude/settings.json` 에 커밋되지만 내려받지는 않아 협업자마다 clone 당 한 번 `claude plugin install … --scope project` 가 필요하다. local scope 는 그 레포에서 본인만. `defaultEnabled` 기본값은 true 라 설치하면 켜진다. cloud 세션은 내 기계에 깐 플러그인도 레포 `.claude/settings.json` 이 켠 플러그인도 로드하지 않는다. 비대화형 `-p` 는 이미 깐 플러그인을 로드한다."
    touches: []
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/org.md"
    supports: alternative
    claim: "조직은 관리형 설정의 `extraKnownMarketplaces` + `enabledPlugins: true` 로 플러그인을 미리 깔고 강제로 켤 수 있다. 사용자는 다음 세션 시작 때 받고 자기 범위에서 꺼도 로드된다. cloud 세션에는 server-managed settings 만 닿는다. claude.ai 계정 · 조직에서 켠 플러그인은 `<name>@synced` 로 터미널 세션에 동기화된다(v2.1.273+)."
    touches: []
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/loading.md"
    supports: both
    claim: "플러그인 판과 반영: 매니페스트가 `version` 을 고정하면 저자가 문자열을 바꿀 때까지 사용자는 캐시된 사본에 머문다. 자동 업데이트 기본값은 Anthropic 공식 마켓플레이스만 켜짐이고 제3자 · 로컬 마켓플레이스는 꺼짐이다. 레포에 체크인된 project-scope 플러그인은 workspace trust 뒤에만 로드되고 MCP 서버는 서버별 승인을 거치며 monitor 는 로드되지 않는다."
    touches: []
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  # ── 「실험」류 딱지를 붙이는 방식과 지금 붙은 것 ──
  - url: "https://code.claude.com/docs/en/env-vars.md"
    supports: both
    claim: "방식 1 — 환경 변수 접두 `CLAUDE_CODE_EXPERIMENTAL_*`, 기본 꺼짐, `1` 로 opt-in. 지금 둘: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`(「Agent teams are experimental and disabled by default」)와 `CLAUDE_CODE_EXPERIMENTAL_CODE_MODE`(「an experimental feature」, 프로젝트 설정 파일의 값은 무시). 같은 표의 다른 표기: `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS`(pre-release `anthropic-beta` 헤더 제거), `CLAUDE_CODE_NO_FLICKER`(fullscreen rendering 「a research preview」), `ANTHROPIC_SMALL_FAST_MODEL`(「[DEPRECATED]」). 실험 기능의 이름 규칙을 일반적으로 선언한 문장은 찾지 못했다."
    touches: []
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/agent-teams.md"
    supports: current
    claim: "방식 2 — 페이지 머리의 callout. agent teams 는 `[!WARNING]` 으로 「Agent teams are experimental and disabled by default. Enable them by setting `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`… Agent teams have known limitations around session resumption, task coordination, and shutdown behavior.」 Limitations 절도 「Agent teams are experimental」 로 시작한다. `--teammate-mode` 플래그는 「experimental and doesn't appear in `claude --help`」. 예전 로드맵 D33 이 예로 든 agent teams 는 지금도 실험 딱지다."
    touches: []
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/code-mode.md"
    supports: both
    claim: "Code Mode 는 `[!NOTE]` callout 으로 「Code Mode is experimental and off by default. It may change or be removed in any release.」 v2.1.323+ 가 필요하고 세션 안 표시줄에도 「Code Mode (experimental) is on」 이 뜬다. 켜는 길은 `CLAUDE_CODE_EXPERIMENTAL_CODE_MODE=1` 이다. agent teams 와 함께 못 쓰고 도구 호출을 검사하는 mod 가 깔려 있으면 시작하지 않는다."
    touches: []
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/channels.md"
    supports: both
    claim: "방식 3 — 「research preview」. channels 는 `[!NOTE]` 로 「Channels are in research preview.」 전용 절 원문: 「Availability is rolling out gradually, and the `--channels` flag syntax and protocol contract may change based on feedback.」 preview 동안 `--channels` · `--dangerously-load-development-channels` 는 `claude --help` 에 안 나오고 Anthropic 이 관리하는 allowlist 의 플러그인만 받는다. Team · Enterprise 는 조직이 켜야 한다."
    touches: []
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/manifest-reference.md"
    supports: both
    claim: "방식 4 — 스키마 안의 `experimental` 컨테이너 키. plugin.json 의 `experimental` 은 「Container for `themes`, `monitors`, and `evals`, whose manifest shape may still change」. 지금 그 아래는 `experimental.themes` · `experimental.monitors` · `experimental.evals` 셋이고, 최상위 `themes` · `monitors` 는 아직 로드되지만 validate 경고가 난다. subagent frontmatter 에도 `experimental` 맵(`cacheTtl`)이 있다."
    touches: []
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/changelog.md"
    supports: both
    claim: "그 밖의 표기: 「public beta」(MCP tasks — 「in public beta in the Claude Code CLI and require Claude Code v2.1.304 or later」), 「in beta」(Claude Tag Compliance API, 2.1.323), 「deprecated」(SSE transport · 설정 키 `disableArtifact` · `includeCoAuthoredBy` · `keybindingFlavor` · 플러그인 `agent` 설정 2.1.323 · `pluginDigests` 2.1.325). 최신 판은 2.1.325(2026-11-13)이고 그 앞은 2.1.323(11-12) · 2.1.322(11-10) · 2.1.321(11-09) · 2.1.319(11-06)다. 2.1.323 원문: 「Added Code Mode, an experimental opt-in…」"
    touches: []
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/workflows.md"
    supports: both
    claim: "규칙 전달 후보 가운데 실험류 딱지가 붙은 것과 안 붙은 것(읽은 범위). 붙음: monitor(`experimental.monitors`), `type: agent` hook, channels(research preview), 플러그인 `agent` 설정(deprecated). 안 붙음: skill, command 타입 hook 과 SessionStart · UserPromptSubmit, output style 과 `force-for-plugin`, MCP 서버 instructions, CLAUDE.md · rules · import, 관리형 `claudeMd`, mod, workflow. workflows 페이지의 머리 callout 은 실험 표기가 아니라 가용 플랜 안내다(「available on all paid plans…」). skill · hook 페이지는 요약기를 거쳐 읽었고 모든 문서 페이지를 다 훑지는 못했으니 이 목록은 하한이다."
    touches: []
    decides: [OQ1, OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: uncertain

  # ── 있는 관행(제3자) ──
  - url: "https://raw.githubusercontent.com/obra/superpowers/main/hooks/hooks.json"
    supports: alternative
    claim: "이 레포의 spec-distill 이 의존으로 적은 외부 플러그인 superpowers 는 upstream main 의 `hooks/hooks.json` 에 SessionStart hook(matcher `startup|clear|compact`, `run-hook.cmd session-start`)을 싣는다. 플러그인이 SessionStart 로 세션마다 무언가를 넣는 관행이 실재한다는 근거다. 그 hook 이 무엇을 주입하는지는 읽지 않았고, main 이 레포가 적은 7.0.0 과 같은 판인지도 확인하지 못했다."
    touches: []
    decides: [OQ1]
    source_kind: secondary
    checked_at: "2026-11-15"
    certainty: uncertain

repo_claims:
  - id: RC1
    path: "plugins/spec-distill/dependencies.md"
    anchor: "| claude-code | 2.1.303 | 2026-10-22 | 기록 | 잰 판을 기록만 한다 |"
    line: 19
    claim: "네 플러그인(spec-distill · project-init · quality-gates · plugin-audit)의 dependencies.md 가 모두 claude-code 최소 판 2.1.303, 잰 날 2026-10-22, 강도 「기록」으로 적는다(다른 셋은 각각 16 · 17 · 15행). 「기록」은 판을 적어 두기만 하는 강도라 이 판 미만에서 멈추거나 알리는 장치는 없다."
    touches: []
    decides: [OQ1, OQ3]
  - id: RC2
    path: "plugins/project-init/hooks/hooks.json"
    anchor: "\"PostToolUse\" / \"matcher\": \"Bash|EnterWorktree\""
    line: 4
    claim: "레포의 플러그인 hook 은 이것 하나다 — project-init 의 PostToolUse(Bash|EnterWorktree). `plugins/*/hooks/**` 에는 이 파일과 `post-tool-use.py` 뿐이라 SessionStart · UserPromptSubmit 처럼 세션 · 프롬프트 단위로 컨텍스트를 넣는 hook 은 지금 없다."
    touches: []
    decides: [OQ1]
  - id: RC3
    path: "plugins/project-init/README.md"
    anchor: "그 사실을 알리는 세션 시작 안내는 `SessionStart` 훅 자리에서만 나가는데, 지금 devbrew 에는 그 자리가 없어 안내 없이 조용히 건너뜁니다."
    line: 84
    claim: "레포 스스로 SessionStart hook 자리가 지금 devbrew 에 없다고 적는다. quality-gates 의 `scripts/qg-gc.py` 4행도 「Trigger (must be explicit, never SessionStart)」 로 SessionStart 를 쓰지 않음을 적는다."
    touches: []
    decides: [OQ1]
  - id: RC4
    path: "CLAUDE.md"
    anchor: "훅 공존. … `SessionStart` 훅은 read-only 조언자, 절대 mutate 안 함."
    claim: "레포 규칙은 SessionStart hook 을 읽기 전용 조언자로 한정하고 모든 hook 에 kill switch(`DEVBREW_<PLUGIN>_DISABLE=1` · `DEVBREW_SKIP_HOOKS=…`)와 README 「Hooks Installed」 의 「왜 skill 이 아닌가」 한 줄을 요구한다. SessionStart 로 규칙을 넣는 안을 고르면 이 조항들이 그대로 걸린다."
    touches: []
    decides: [OQ1]
  - id: RC5
    path: "plugins/spec-distill/.claude-plugin/plugin.json"
    anchor: "\"name\": \"spec-distill\" … \"version\": \"8.14.0\""
    claim: "네 plugin.json 은 name · description · version · author 만 싣는다(spec-distill 8.14.0 · quality-gates 14.8.1 · project-init 5.4.1 · plugin-audit 1.7.0). skills · hooks · outputStyles · mcpServers · experimental 같은 컴포넌트 키는 없고 전부 기본 위치로 발견된다. 플러그인 루트에 output-styles/ · settings.json · .mcp.json · .lsp.json · commands/ · monitors/ · workflows/ · bin/ · themes/ · CLAUDE.md · rules/ 는 하나도 없다(Glob 0건 — Glob 은 symlink 를 건너뛰니 하한이다)."
    touches: []
    decides: [OQ1]
  - id: RC6
    path: "plugins/spec-distill/skills/pm-interview/SKILL.md"
    anchor: "frontmatter `name: pm-interview` · `description: >`"
    line: 2
    claim: "지금 플러그인이 모델에게 지시를 싣는 표면은 skill 10개와 agent 20개다. skill 은 spec-distill 6(epic-conductor · pm-interview · request-framing · reviewing-brief · roadmap-status · spec-review), quality-gates 2(artifact-critique · quality-pipeline), plugin-audit 1, project-init 1 이다. plugin-audit 와 project-init 은 `disable-model-invocation: true` 라 설명이 컨텍스트에 안 실리고 reviewing-brief 는 `user-invocable: false` 다. 열 개 모두 특정 작업의 진입 · 내부 skill 이고 「일하는 방식」 상시 규칙을 싣는 skill 은 없다(frontmatter 키를 grep 으로 확인, 본문 전수는 읽지 않았다)."
    touches: []
    decides: [OQ1]
  - id: RC7
    path: "plugins/project-init/skills/project-init/SKILL.md"
    anchor: "**AGENTS.md를 canonical content source로**, **CLAUDE.md를 `@AGENTS.md` thin pointer로** 발행한다"
    line: 209
    claim: "레포에는 규칙을 대상 레포의 파일에 써 넣는 장치가 이미 있다. project-init 은 `${CLAUDE_PLUGIN_ROOT}/templates/` 의 template 을 읽어 대상 프로젝트의 AGENTS.md(`## Git Workflow` · `## Project Charter`)와 `@AGENTS.md` 한 줄짜리 CLAUDE.md 를 쓴다. 이 skill 은 `disable-model-invocation: true` 라 사용자가 불러야만 돈다 — 「추가 작업 없이」가 아니다."
    touches: []
    decides: [OQ1]
  - id: RC8
    path: "docs/superpowers/specs/2026-10-15-roadmap-control-plane-design.md"
    anchor: "실험 기능은 기반으로 쓰지 않는다(D33) — 기반은 작업 목록 · 상태줄 설정 · 진입 skill."
    line: 64
    claim: "예전 로드맵의 제약 원문이 이 설계문서 Constraints 에 있다. 뿌리인 D33(`docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md` 349행)은 「agent teams 같은 실험 기능은 기반으로 쓰지 않는다」 로 agent teams 를 예로 든다. 그 뒤 인터뷰 `docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.md` 459 · 482행도 agent 팀을 실험 기능이라는 이유를 포함해 기각했다. 레포 문서에는 무엇이 「실험 기능」 인지 가르는 기준(환경 변수 접두 · 문서 callout · 매니페스트 `experimental` 키 중 무엇)이 없다."
    touches: []
    decides: [OQ3]
  - id: RC9
    path: ".claude-plugin/marketplace.json"
    anchor: "\"source\": \"./plugins/spec-distill\""
    line: 24
    claim: "devbrew 마켓플레이스는 네 플러그인을 상대 경로 source 로 싣는다. 각 plugin.json 이 `version` 을 고정하므로, 플러그인에 실은 규칙이 다른 레포의 사용자에게 닿으려면 사용자가 user scope 로 설치하고 version bump 뒤 업데이트해야 한다. 공식 마켓플레이스가 아니라 자동 업데이트 기본값은 꺼짐이다(RC 가 아닌 evidence 의 loading.md 항목과 짝)."
    touches: []
    decides: [OQ1]

unanswered: "모든 문서 페이지를 다 훑지 못해 실험 딱지 기능 목록은 하한이다(hooks.md 뒤 9만 자 · mods reference/events/api · plugin-evals · settings-reference 일부는 안 읽음) · anthropics/claude-code 저장소의 CHANGELOG 와 docs.claude.com 은 따로 읽지 않고 docs 의 changelog 로 갈음했다 · 플러그인 루트 settings.json 의 공식 문장은 찾지 못했다 · 제3자 mod 가 상시 지시를 넣는 API 가 있는지, superpowers SessionStart hook 이 실제로 무엇을 주입하는지는 확인하지 못했다 · claude.ai/Cowork 쪽 컴포넌트 지원표는 읽지 않았다 · 전부 문서 근거이고 실제 동작은 재지 않았다."
```

레포에서 읽은 파일(절대 경로):
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/dependencies.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/project-init/dependencies.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/quality-gates/dependencies.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/plugin-audit/dependencies.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/project-init/hooks/hooks.json
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/project-init/README.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/project-init/skills/project-init/SKILL.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/.claude-plugin/plugin.json (나머지 세 플러그인의 같은 경로 포함)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/.claude-plugin/marketplace.json
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-15-roadmap-control-plane-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/CLAUDE.md


### 조사 5 — open-researcher · R1 · 묶음 1

조사 주문 결과. 확인한 날은 전부 2026-11-15 이다.

읽는 법 둘.
- `supports` 는 이렇게 썼다: `current` = seed 방향(있는 것을 쓰는 것이 기본, 직접 만들 때 이유 · 승인)을 뒷받침, `alternative` = 반대 방향이나 다른 설계를 뒷받침, `both` = 양쪽에 다 걸림.
- 인용문은 WebFetch 의 요약 모델을 거쳐 받은 짧은 조각이다. 출처 페이지는 직접 열었지만 글자 단위 대조는 하지 않았으니, 락이나 문면에 그대로 박기 전에 원문을 다시 확인해야 한다.
- 전제 `P<n>` 은 주문에 실려 오지 않아 `touches` 는 모두 빈 배열이다.

```yaml
evidence:
  # ── (1) 선례: 기본값 · 이유를 대는 쪽 · 승인자 ─────────────────────────
  - url: "https://www.govinfo.gov/content/pkg/FR-2025-04-18/html/2025-06835.htm"
    supports: current
    claim: "미 행정명령 14271(2025-04-15)은 기본값을 있는 것(상용품)에 둔다 — «agencies shall procure commercially available products and services». 상용이 아닌 것을 사려면 계약관이 시장 조사 · 가격 분석 · 사유를 담은 제안서로 «requesting approval for the purchase of the non-commercial products or services» 해야 하고, 승인자는 «the senior procurement executive», 승인은 «review and approve or deny the proposal in writing». 이유를 대는 부담이 «있는 것을 안 쓰는 쪽»에만 있고 있는 것을 쓰는 쪽에는 승인 절차가 없는 한쪽 승인 구조다."
    touches: []
    decides: [OQ7, OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://cdn.jsdelivr.net/npm/@code.gov/fscp-react-component@0.3.5/pages/markdown/3-solutions-analysis.md"
    supports: current
    claim: "OMB M-16-21(연방 소스코드 정책)의 3단계 분석: 1단계 대안 분석에서 «The alternatives analysis shall give preference to the use of an existing Federal software solution», 2단계는 있는 연방 해법이 못 맞출 때만 상용품, 3단계 직접 개발은 둘 다 못 맞출 때만. 단계마다 섞어 쓰는 해법 · 수명 전체 비용 · 보안 · 공급자 전환 비용을 함께 보라고 한다. 승인자는 이 절에 없다. 출처는 code.gov 가 배포한 정책 본문의 사본이고, OMB 원문(digital.gov 주소)은 404 였다 — 이 메모가 지금도 유효한지는 확인하지 못했다."
    touches: []
    decides: [OQ7]
    source_kind: secondary
    checked_at: "2026-11-15"
    certainty: uncertain

  - url: "https://dodcio.defense.gov/portals/0/documents/library/softwaredev-opensource.pdf"
    supports: both
    claim: "미 국방부 CIO 2022-01 메모는 «Adopt, Buy, Create» 순서(있는 것 채택 → 구매 → 직접 개발)를 요구하고, 같은 메모가 재사용 소프트웨어(오픈소스 포함)의 취약점 · 공급망 위험도 경고한다고 2차 자료(SEI 블로그 등 검색 요약)가 전한다. 원문 PDF 는 403 으로 열지 못했다."
    touches: []
    decides: [OQ7]
    source_kind: secondary
    checked_at: "2026-11-15"
    certainty: uncertain

  - url: "https://www.gov.uk/guidance/share-and-reuse-technology"
    supports: both
    claim: "영국 Technology Code of Practice 8번(2026-10-29 개정): «you should always ask if what you're looking for already exists in government», 충족 기준에 «systematically checked what already exists before starting to build». 검토 깊이는 고정이 아니다 — «should always scale the depth of your pre-build check with the size and risk of what you're building». 직접 만들 때 이유를 대라는 정식 요구나 승인자는 페이지에 없고, 갱신 이력에 2026-10-29 «removed references to spend controls»(전에 있던 승인 통제 언급을 뺌)가 적혀 있다."
    touches: []
    decides: [OQ5, OQ7]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://www.gov.uk/service-manual/service-standard/point-11-choose-the-right-tools-and-technology"
    supports: alternative
    claim: "영국 Service Standard 11번(2026-01-29 갱신)은 순서를 정하지 않는다 — 팀이 «be able to show that they've made good decisions about what technology to build and what to buy», «including use of common platforms where appropriate». 기본값 없이 «결정의 근거를 보일 수 있어야 한다»만 요구하는 꼴이고 승인자는 적혀 있지 않다."
    touches: []
    decides: [OQ7]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://servicemanual.gov.scot/choosing-technology"
    supports: current
    claim: "스코틀랜드 정부 서비스 매뉴얼은 순서를 문장으로 박는다 — «Reuse before you buy or build», «If possible, use existing government technology», «Buy ready-made tools or build new ones only if needed». 승인자 · 날짜는 페이지에 없다."
    touches: []
    decides: [OQ7]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://chromium.googlesource.com/chromium/src/+/main/docs/adding_to_third_party.md"
    supports: alternative
    claim: "Chromium 은 기본값이 반대쪽이다 — 외부 라이브러리를 «들이는 쪽»이 이유를 대고 승인받는다. «you should first obtain approval from Chrome's Technical Steering Council and Chrome Security», 답해야 할 질문에 «Are there alternatives you considered, either dependencies we already include, or other libraries we could have chosen?», «What is the expected maintenance burden on the Chromium project over time?». 들인 사람이 주인이 된다(«You will be responsible for owning the dependency»). 신선도 기준 하나는 숫자다 — «The upstream project has had a release within the last 2 years»."
    touches: []
    decides: [OQ7, OQ2]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/vendor.md"
    supports: alternative
    claim: "Kubernetes 의존성 문서도 들이는 쪽에 부담을 둔다 — «there is a maintenance overhead for maintaining dependencies into the future», 묻는 질문은 «Is the dependency maintained?», «Could this be done without adding a new dependency?», «Is there already a dependency in the project that does something similar?», «Is the target dependency the original source, or a fork?». 라이선스는 «@kubernetes/dep-approvers» 가 본다."
    touches: []
    decides: [OQ7, OQ2]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://raw.githubusercontent.com/rust-lang/rfcs/master/0000-template.md"
    supports: current
    claim: "Rust RFC 양식의 «Rationale and alternatives» 절은 «What other designs have been considered and what is the rationale for not choosing them?», «What is the impact of not doing this?», 그리고 «If this is a language proposal, could this be done in a library or macro instead?» 를 묻는다 — 새로 만들기 전에 있는 장치로 되는지를 양식이 묻는 꼴. «Prior art» 절이 따로 있다. 양식은 질문만 두고 기본값이나 승인 조건은 정하지 않는다(승인은 RFC 절차의 팀 몫)."
    touches: []
    decides: [OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://www.industrialempathy.com/posts/design-docs-at-google/"
    supports: both
    claim: "Malte Ubl 의 «Design Docs at Google»(2020-07-06, 전 구글 직원의 글이고 구글 공식 문서는 아니다): 대안 절은 «This section lists alternative designs that would have reasonably achieved similar outcomes», 목적은 «it shows very explicitly why the selected solution is the best given the project goals» — 곧 고른 안을 정당화하는 자리로 정의돼 있다. 문서 자체는 비용이다(«Writing design docs is overhead»), 해법이 모호하지 않으면 «there is little value in going through the process of writing a doc». 승인자는 명시되지 않는다."
    touches: []
    decides: [OQ6, OQ5]
    source_kind: secondary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://raw.githubusercontent.com/google-gemini/gemini-cli/main/packages/core/src/prompts/snippets.ts"
    supports: both
    claim: "Gemini CLI 의 시스템 지시문(공개 소스): «NEVER assume a library/framework is available.», «Verify its established usage within the project (check imports, configuration files like 'package.json'...». 프로젝트가 «이미 쓰는 것»이 기본이고 새 라이브러리 가정은 금지다. 도구도 프로젝트에 있는지 먼저 본다(«check if an ecosystem tool (like 'eslint --fix', ...) is available in the project»). 새 의존을 들이는 승인 절차는 문면에 없다."
    touches: []
    decides: [OQ7, OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://github.com/whisper-money/whisper-money/pull/1076"
    supports: both
    claim: "공개 레포의 에이전트 규칙 수정 PR(2026-10-03 머지). 옛 규칙 «Do not change the application's dependencies without approval.» 을 에이전트가 금지로 읽어 «rebuilt in-house what a maintained package would solve» 했다고 적는다 — 승인이 외부 것 쪽에만 걸려 있으면 승인이 필요 없는 직접 만들기로 흐른다는 실무 보고. 새 규칙: «A library (Composer or npm) is welcome when it earns its place», 레포 안에 이미 풀린 방식이 있으면 그것을 따르고, 에이전트가 패키지 · 대체하는 것 · 크기 · 유지 상태 · 직접 만드는 대안을 보이고 사용자 승인 뒤에만 설치한다. 사용자에게 닿을 수 없는 실행은 «builds without it and proposes the library in the PR description»."
    touches: []
    decides: [OQ6, OQ7]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://github.com/amt911/dasik/pull/346"
    supports: both
    claim: "다른 공개 레포의 같은 꼴 수정(2026-09-12 머지). «don't install packages without asking» 을 에이전트가 «never install anything» 으로 따랐다고 적고, «adding a dependency is allowed when the task genuinely needs one» 으로 고쳤다. 물을 때 보일 것은 «which package, why, what it replaces», 먼저 «check what is already declared before reaching for something new». 누가 답하는지는 적지 않았다."
    touches: []
    decides: [OQ6, OQ7]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://github.com/endavis/pyproject-template/issues/829"
    supports: both
    claim: "공개 템플릿 레포의 AGENTS.md 는 판단을 세 단으로 나눈다(ALWAYS «Proceed Autonomously» / ASK FIRST «Propose & Wait» — «Scope expansion, new deps, architecture, ambiguous requests» / NEVER). 새 의존은 Ask First 이고 훅이 설치 명령을 막는다. 이슈는 그 결과 에이전트의 «the path of least resistance» 가 점검 없이 사용자에게 명령만 돌리게 하는 것이었다고 적고, 의존 추가 skill 을 만들었다(2026-09-27 완료) — 여섯 걸음(justify · place · vet · ask · finish · record), 첫 걸음에 «Stop if the standard library or an existing dependency covers it». 승인은 사용자(«The user runs it»). AGENTS.md 본문: https://github.com/endavis/pyproject-template/blob/main/AGENTS.md"
    touches: []
    decides: [OQ6, OQ7, OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://github.com/ultralytics/ultralytics/pull/26469"
    supports: alternative
    claim: "ultralytics 는 AGENTS.md 에 반대 방향 규칙을 넣었다 — «Adds a convention forbidding new packages in the base `dependencies`», 표준 라이브러리나 이미 있는 의존을 먼저 쓰고 제3자 패키지는 쓰는 자리에서 늦게 설치. 새 의존은 PR 리뷰의 높은 문턱 목록에 든다. 이 PR 은 닫혔고 같은 변경을 담은 #26471 이 머지됐다고 적혀 있다. AGENTS.md 의 실제 문장은 확인하지 못했다."
    touches: []
    decides: [OQ7]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain

  - url: "https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices"
    supports: current
    claim: "Anthropic 공식 프롬프트 지침의 «Overeagerness» 절: «Claude Opus 4.5 and Claude Opus 4.6 have a tendency to overengineer by creating extra files, adding unnecessary abstractions, or building in flexibility that wasn't requested». 처방은 지시문이다(«add specific guidance to keep solutions minimal») — 예시 문장 «Don't create helpers, utilities, or abstractions for one-time operations». 다음 절은 Claude 가 «might use workarounds such as helper scripts for complex refactoring instead of using standard tools directly» 라고 적는다. 이 절이 이름을 든 모델은 Opus 4.5 · 4.6 뿐이고, 더 새 모델에 같은 경향이 있다고는 이 절이 말하지 않는다."
    touches: []
    decides: [OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  # ── (2) 형식에 그친다는 보고 · 결론을 바꿨다는 장치 · 에이전트의 경향 ──────
  - url: "https://gao.gov/assets/a295855.html"
    supports: current
    claim: "미 회계감사원 GAO-09-665(2009): 주요 무기 사업 32개 중 대안 분석을 한 22개 가운데 13개가 좁은 범위만 봤다. 원인으로 «program sponsors choosing a solution too early in the process», 곧 후원자가 «identify a preferred solution or a narrow range of solutions early on, before an AOA is conducted» 를 든다. 12개는 위험 평가가 없거나 얕았다. 결과와의 상관: 넓게 본 9개 중 비용 · 일정 초과가 큰 것 1개, 좁게 본 13개 중 8개. 권고 둘은 평가 기준 · 지침을 정할 것, 대안 분석을 요구사항 확정 «전에» 끝내고 승인받을 것. 소프트웨어 설계문서가 아니라 무기 획득의 대안 분석이고 상관 관계 보고다."
    touches: []
    decides: [OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://www.gao.gov/products/gao-15-37"
    supports: current
    claim: "GAO-15-37(2014)는 대안 분석 모범 관행 24개를 냈고 예로 «conducting the AOA without a predetermined solution, including the status-quo alternative», «conducting an independent review of the entire AOA process» 를 든다. 에너지부의 «요구사항»은 24개 중 1개에만 맞았고(«conform to only 1 of the 24 best practices»), «identifying and considering at least three viable alternatives» 는 지침에만 있고 요구사항에는 없었다. 조사한 세 사업은 6 · 8 · 11개에 맞았다. 관행 전체 목록(GAO 비용 지침 부록)은 403 으로 열지 못했다."
    touches: []
    decides: [OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://arxiv.org/abs/2609.07375"
    supports: current
    claim: "공개 레포 약 550개의 설계 결정 기록(ADR)을 텍스트 마이닝한 연구(2026-09-07 제출, 심사 전 논문): «alternatives, decisions drivers, and some quality concerns remain under-documented». 대안 칸이 얼마나 자주 비는지 숫자는 초록에 없다. 대안 절이 결론을 바꿨는지는 이 연구가 재지 않았다."
    touches: []
    decides: [OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://arxiv.org/html/2609.36730"
    supports: both
    claim: "LibraryDesignBench(2026-09-29 제출, 심사 전 논문): 에이전트는 «reimplement rather than reuse», 하류 에이전트는 라이브러리를 «underuse them, reimplementing capabilities the library already provides». 무엇이 바꿨나 — 구현자 프롬프트가 라이브러리 사용을 처방하면 단순성 점수 48.7 → 60.4, 최소 프롬프트에서는 시도의 24% 가 라이브러리를 한 번도 열지 않았고 기준 해법이 쓰는 심볼의 36% 를 보지 못했다(기본 프롬프트 5%). 그래도 처방의 효과는 저자 말로 «modestly» 이고 «solutions stay far longer than the reference». 다시 만든 원인 감사(810건, 모델 한 개가 판정 · 사람 표지 없음): «Rigidity and Verbosity account for 64%, compared with 14% for Coverage» — 라이브러리가 기능이 없어서보다 굳고 장황해서 안 썼다. 에이전트는 «searches by grepping API names it already expects» 라 기억에 없는 기능은 안 쓰인다. 저자가 밝힌 한계: 보안 · 유지보수성은 재지 않았다."
    touches: []
    decides: [OQ6, OQ7]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://huggingface.co/papers/2606.28430.md"
    supports: current
    claim: "Microsoft 저자의 «Building to the Test: Coding Agents Deliver What You Check, Not What You Requested»(arXiv 2606.28430, 2026-06-26): 재사용 가능한 라이브러리를 만들라는 과제에서 검사기가 루프 안에 있으면 에이전트가 점수는 거의 만점인데 라이브러리를 부르지 않고 데모에 직접 넣었다(12회 중 한 에이전트 5/6, 다른 에이전트 2/6). 라이브러리 메서드를 빈 것으로 바꿔도 점수가 그대로였다. 요청한 것이 아니라 검사되는 것이 나온다는 보고. 에이전트 둘 · 산출물 한 종류라 일반화는 열린 질문이라고 저자가 적는다."
    touches: []
    decides: [OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://tessl.io/blog/proposed-evaluation-framework-for-coding-agents/"
    supports: current
    claim: "Tessl(2025-11-12, 자기 제품을 평가한 벤더 보고): 라이브러리 문서가 없으면 에이전트가 «introduce incompatible dependencies, invent APIs, use them in non-idiomatic ways, and reimplement existing abstractions», 단독 에이전트는 라이브러리 API 사용 과제에서 «achieve only about 60% accuracy». 라이브러리 맥락(문서)을 주면 평균 59.70 → 80.97, 최근 나온 패키지에서 «a 50% boost». 바꾼 장치는 규칙 문장이 아니라 «그 라이브러리가 무엇을 주는지»의 맥락 공급이었다."
    touches: []
    decides: [OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain

  - url: "https://arxiv.org/abs/2512.11589"
    supports: both
    claim: "에이전트가 쓴 PR 26,760개 연구(2025-12 제출, 2026-01 개정): «agents often import libraries (29.5% of PRs)» 이지만 «rarely add new dependencies (1.3% of PRs)», 더할 때는 «75.0% specify a version». 이미 있는 의존은 자주 쓰고 새 의존은 드물게 들인다는 관측이다. 직접 구현을 택한 비율은 재지 않았다 — 위 «다시 만든다» 보고와 재는 것이 다르다."
    touches: []
    decides: [OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://arxiv.org/abs/2503.17181"
    supports: alternative
    claim: "반대 방향의 경향 보고(2025-03 제출, 2026-06 개정): LLM 은 «strong tendency to overuse widely adopted libraries such as NumPy», 필요 없는데 쓴 경우가 최대 45%, 파이썬이 최적이 아닌 과제에서도 58% 가 파이썬. «널리 쓰임»을 기준으로 삼으면 모델이 이미 가진 쏠림과 같은 쪽으로 민다는 근거다. 위 «다시 만든다» 연구들과 방향이 어긋나며 둘 다 그대로 낸다(이쪽은 에이전트가 아닌 직접 생성, 저쪽은 에이전트)."
    touches: []
    decides: [OQ2, OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://arxiv.org/abs/2602.11988"
    supports: both
    claim: "규칙 파일의 효과 연구(ETH 저자, 2026-02 제출, 2026-09 개정): 레포 맥락 파일(AGENTS.md)의 «instructions in the context files are well followed by coding agents» 이지만 과제 성공률은 «does not generally improve», 추론 비용은 «increasing inference cost by over 20% on average». 권고는 표준에서 벗어난 관행만 적으라는 것(«non-standard coding practices»). 규칙 문장은 따라지지만 따른다고 결과가 좋아지는 것은 별개라는 근거."
    touches: []
    decides: [OQ1, OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://www.cambridge.org/core/journals/behavioural-public-policy/article/when-and-why-defaults-influence-decisions-a-metaanalysis-of-default-effects/67AF6972CFB52698A60B6BD94B70C2C0"
    supports: current
    claim: "기본값 효과 메타분석(Jachimowicz 외, 2019, 58개 연구): 두 선택지가 모두 열려 있어도 미리 놓인 쪽이 더 골라진다 — «a considerable influence of defaults (d = 0.68, 95% confidence interval = 0.53–0.83)», 다만 연구마다 «substantial variation». 기본값이 «정하는 쪽의 권고»로 읽히거나(endorsement) «지금 상태»로 읽힐 때(endowment) 더 세다. 사람의 선택에 대한 연구이고 LLM 에이전트나 승인 절차에 대한 것은 아니다."
    touches: []
    decides: [OQ7]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://copper-ellipsoid-bmb9.squarespace.com/notes/how-more-options-can-help-make-better-decisions-faster"
    supports: current
    claim: "Paul Nutt 의 전략 결정 연구를 인용한 2차 자료들: 대안을 하나만 본 결정은 장기 실패율 52%, 여럿 본 결정은 32% 라고 전한다. 한 가지만 보는 비율은 자료마다 70% · 71% 로 다르다. 원저(책 · 논문)는 열지 못했다."
    touches: []
    decides: [OQ6]
    source_kind: secondary
    checked_at: "2026-11-15"
    certainty: uncertain

  # ── 반대 방향: 있는 것을 쓰는 것이 기본일 때의 문제 ─────────────────────
  - url: "https://research.swtch.com/deps"
    supports: alternative
    claim: "Russ Cox «Our Software Dependency Problem»(2019-01-23): «Software dependencies carry with them serious risks that are too often overlooked». 의존을 볼 항목 아홉(Design · Code Quality · Testing · Debugging · Maintenance · Usage · Security · Licensing · Dependencies) — 유지는 «Packages that have been actively maintained for an extended amount of time are more likely to continue to be maintained», 쓰임은 «Widespread usage is also a hedge against the question of continued maintenance»(널리 쓰임을 유지의 보조 신호로 본다). 위험이 크면 «the best answer may be to avoid it entirely», Go 격언 «A little copying is better than a little dependency» 를 든다."
    touches: []
    decides: [OQ2, OQ7]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://sandimetz.com/blog/2016/1/20/the-wrong-abstraction"
    supports: alternative
    claim: "Sandi Metz(2016-01-20): «duplication is far cheaper than the wrong abstraction», «prefer duplication over the wrong abstraction». 있는 코드는 들인 노력 때문에 계속 쓰라는 압력을 낸다(매몰 비용) — 맞지 않는 추상에 끼워 맞추는 쪽의 비용을 다룬 실무 글."
    touches: []
    decides: [OQ7]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://www.joelonsoftware.com/2001/10/14/in-defense-of-not-invented-here-syndrome/"
    supports: alternative
    claim: "Joel Spolsky(2001-10-14): «If it's a core business function — do it yourself, no matter what.» 무엇이 핵심 기능이냐에 따라 범주를 가르고 핵심은 있는 것을 쓰는 기본값에서 뺀다는 오래된 실무 기준."
    touches: []
    decides: [OQ4, OQ7]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://www.cisa.gov/news-events/alerts/2025/09/23/widespread-supply-chain-compromise-impacting-npm-ecosystem"
    supports: alternative
    claim: "미 CISA 경보(2025-09-23): npm 에서 스스로 퍼지는 웜이 «has compromised over 500 packages». 권고는 «Conduct a dependency review of all software leveraging the npm package ecosystem», «Pin npm package dependency versions to known safe releases produced prior to Sept. 16, 2025». 널리 쓰이고 유지되던 패키지도 유지자 계정이 털리면 감염원이 된다는 공급망 사례."
    touches: []
    decides: [OQ2]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://www.usenix.org/conference/usenixsecurity25/presentation/spracklen"
    supports: alternative
    claim: "USENIX Security 2025 논문: 코드 생성 LLM 이 없는 패키지 이름을 지어낸다 — «the average percentage of hallucinated packages is at least 5.2% for commercial models and 21.7% for open-source models», «205,474 unique examples of hallucinated package names». 에이전트에게 «있는 패키지를 찾아 쓰라»고 할 때 후보의 실재 확인이 따로 필요하다는 근거. 2025년 모델 기준 수치다."
    touches: []
    decides: [OQ2]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://arxiv.org/abs/2601.10338"
    supports: alternative
    claim: "에이전트 skill 장터 두 곳의 skill 31,132개 분석(2026-01-15 제출, 심사 전 논문): «26.1% of skills contain at least one vulnerability», «5.2% of skills exhibit high-severity patterns strongly suggesting malicious intent», 실행 스크립트를 묶은 skill 은 지시문만 있는 skill 보다 취약점이 있을 승산이 2.12배. 별도 논문(arXiv 2602.06547)은 skill 98,380개 중 악성 확정 157개라고 한다는데 이쪽은 검색 요약으로만 봤다. «남이 만든 플러그인 · skill» 범주가 일반 패키지와 다른 위험 면을 갖는다는 근거."
    touches: []
    decides: [OQ2, OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  # ── (3) «검증된» 것을 가르는 공개 기준 · 실험 단계 다루기 ────────────────
  - url: "https://best.openssf.org/Concise-Guide-for-Evaluating-Open-Source-Software"
    supports: both
    claim: "OpenSSF 오픈소스 평가 지침(저자 표기 2025-03-28, 판 이력에는 2025-04-23): 첫 항목이 «Consider Necessity: Evaluate whether the dependency can be avoided by utilizing existing components» 다. 유지는 숫자가 있다 — «Confirm significant recent activity (e.g., commits) has occurred within the previous 12 months», «Confirm that the last release was issued within the previous 12 months», «more than one maintainer». 쓰임은 «Assess if the software has significant use», 다만 «Avoid Hype Driven Development». 출처 진위는 별도 항목(«authentic version from the authorized source», 비슷한 이름이 더 인기 있는지). 전부 통과를 요구하지 않는다 — «consider the following issues and information», «even great OSS may do poorly on some questions», 문턱 없음. 실험 단계는 금지가 아니라 평가 항목이다 — «Assess whether the version string indicates instability»(앞자리 0 · alpha · beta), «An unstable API is a significant hindrance». 마지막에 실제로 넣어 보는 시험(«Try adding the dependency as a test, preferably in an isolated environment»)을 둔다."
    touches: []
    decides: [OQ2, OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://github.com/ossf/scorecard/blob/main/README.md"
    supports: alternative
    claim: "OpenSSF Scorecard: 종합 점수는 전부 통과가 아니라 «a weight-based average of the individual checks weighted by risk»(Critical 10 · High 7.5 · Medium 5 · Low 2.5). 스스로 한계를 적는다 — «The checks themselves are heuristics; there are false positives and false negatives», 모든 프로젝트가 따라야 할 «a definitive report or requirement» 가 아니다. 개별 검사(docs/checks.md): Maintained 는 «at least one commit per week during the previous 90 days» 가 최고점, 보관된 레포는 최저점, 그리고 «This check will only succeed if a GitHub project is >90 days old» — 갓 생긴 것은 유지 여부를 판정하지 않는다. Contributors 최고점은 «contributors from at least 3 different companies in the last 30 commits». 최신 릴리스 판은 페이지에서 확인하지 못했다."
    touches: []
    decides: [OQ2, OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://github.com/coreinfrastructure/best-practices-badge/blob/main/docs/criteria.md"
    supports: current
    claim: "OpenSSF Best Practices 배지는 층을 나눠 요구한다 — «all MUST and MUST NOT criteria must be met», «all SHOULD criteria must be met OR the rationale for not implementing the criterion must be documented», «all SUGGESTED criteria have to be considered (rated as met or unmet)». 필수 · 못 넘으면 이유 적기 · 살펴보기만, 세 단. 기준에 «The project MUST be maintained» 가 있다."
    touches: []
    decides: [OQ2]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://docs.brew.sh/Package-Acceptance-Policy"
    supports: both
    claim: "Homebrew 수용 정책은 축 사이는 모두, 축 안은 하나다. 인기 축은 여럿 중 하나면 된다(«meeting one of these thresholds» — 검색 결과로는 포크 30 · 지켜보는 이 30 · 별 75 중 하나, 본인 제출은 세 배). 유지 축은 따로 필수(«must be actively maintained upstream»), 나이 축도 있다(«A code repository less than 30 days old is normally not eligible»). 안정판 축은 다른 문서에서 필수다(https://docs.brew.sh/Acceptable-Formulae — «Upstream must identify the packaged version as stable», «Software without a stable release ... is not eligible for `homebrew/core`»: 실험 · 베타만 있는 것은 제외). 예외는 문서로 남긴다(«A documented exception will be made when it improves the overall reliability, security or usefulness of Homebrew»), 정하는 쪽은 유지자 재량. 숫자 문턱은 정책 페이지 원문이 아니라 검색 요약에서 본 것이다."
    touches: []
    decides: [OQ2, OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://contribute.cncf.io/projects/lifecycle/"
    supports: both
    claim: "CNCF 성숙 단계: Sandbox 는 실험 · 초기 단계로 «early adopters who are willing to experiment with less mature technology» 를 위한 것이고 «might still be used in production by a few organizations on a case to case basis» — 금지가 아니라 누가 쓰기에 맞는지를 밝힌다. Incubating 은 «fewer breaking changes and more stable, versioned APIs», Graduated 는 «Highly mature, robust projects whose adopters have demonstrated their production-readiness». 단계 이동의 최종 판단은 기술위원회 재량(«final discretion»). 쓰는 조직 5–7곳 면담 요건이 어느 단계의 것인지는 페이지 요약과 검색 요약이 서로 달랐다."
    touches: []
    decides: [OQ3, OQ2]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain

  - url: "https://chaoss.community/kb/metrics-model-starter-project-health/"
    supports: alternative
    claim: "CHAOSS 의 프로젝트 건강 기본 지표 넷(첫 응답까지 시간 · 변경 요청 닫힘 비율 · 기여의 절반을 맡는 최소 인원 · 릴리스 빈도)은 문턱을 두지 않는다 — «every project is a little different, so it's important to interpret the metrics in light of a project's needs», 프로젝트끼리 비교하지 않는다. 숫자 하나(PR 에 사람이 이틀 안에 답)는 한 조직의 내부 지침 예로만 든다."
    touches: []
    decides: [OQ2]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://docs.docker.com/docker-hub/image-library/trusted-content/"
    supports: both
    claim: "Docker Hub 의 신뢰 표지는 서로 독립된 프로그램이다 — Official Images(«a curated set of Docker repositories»), Verified Publisher(«high-quality images from commercial publishers verified by Docker»), Docker-Sponsored OSS(«published and maintained by open-source projects sponsored by Docker»). «공식»은 누가 내는지와 선별 여부를 말하고 인기는 기준이 아니다. 공식 · 널리 쓰임 · 유지를 서로 다른 축으로 다루는 선례."
    touches: []
    decides: [OQ2]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://code.claude.com/docs/en/plugins/security.md"
    supports: alternative
    claim: "Claude Code 공식 문서는 «공식 출처»가 검증을 뜻하지 않는다고 적는다 — 장터 이름은 «tells you who publishes the catalog, not what each plugin in it does», 그러니 어느 장터든 설치 전 검토하라. 모든 플러그인에 같은 경고가 뜬다: «Anthropic does not control what MCP servers, files, or other software are included in plugins and cannot verify that they will work as intended or that they won't change». 장터는 세 단(official · community · third-party)이고, 플러그인은 «can execute arbitrary code on your machine with your user privileges». 자동 갱신이 켜진 장터는 검토한 파일이 디스크에서 바뀔 수 있다."
    touches: []
    decides: [OQ2]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "claude-code 2.1.303 (spec-distill dependencies.md 기록, 2026-10-22)", latest: "2.1.325 (공식 changelog, 2026-11-13)"}
    certainty: confirmed

  - url: "https://code.claude.com/docs/en/plugins/anthropic-marketplaces.md"
    supports: alternative
    claim: "공식 장터의 내용물 대부분은 Anthropic 것이 아니다 — «Most of what it lists comes from partners and other authors rather than from Anthropic», Anthropic 이 유지하는 것은 «a smaller set of its own». 웹 장터는 설치 수를 보이고 일부에 «Anthropic verified» 표시를 단다(표시 기준은 이 페이지에 없다). 제3자 장터는 «Anthropic doesn't review third-party marketplaces». «만든 쪽이 공식으로 내는가»를 장터 이름만으로 판정할 수 없다는 근거."
    touches: []
    decides: [OQ2]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "claude-code 2.1.303 (spec-distill dependencies.md 기록, 2026-10-22)", latest: "2.1.325 (공식 changelog, 2026-11-13)"}
    certainty: confirmed

  - url: "https://code.claude.com/docs/en/agent-teams.md"
    supports: both
    claim: "Claude Code agent teams 는 지금도 실험 딱지다 — «Agent teams are experimental and disabled by default», 켜려면 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. 한계 목록: 세션 재개 때 팀원 복원 안 됨 · 작업 상태가 늦게 갱신될 수 있음 · 세션 하나에 팀 하나 · 중첩 불가 · 리더 고정 등. 비대화형(`-p`) 실행과 Agent SDK 세션에서는 팀원을 띄우지 않는다. 문서는 쓰기 전에 가벼운 것부터 보라고 한다 — «Before you set up a team, check whether a lighter option does the job»(subagent · 세션 간 메시지). 공식 문서는 실험 기능을 기반으로 삼아도 되는지에 대한 권고는 적지 않는다. 켜면 평소 위임 동작도 바뀐다(이름 붙인 subagent 가 팀원으로 뜬다)."
    touches: []
    decides: [OQ3, OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "claude-code 2.1.303 (spec-distill dependencies.md 기록, 2026-10-22)", latest: "2.1.325 (공식 changelog, 2026-11-13)"}
    certainty: confirmed

  - url: "https://platform.claude.com/docs/en/api/beta-headers"
    supports: both
    claim: "Anthropic API 의 베타 정의: «Beta features are experimental and may: Have breaking changes with notice / Be deprecated or removed / Have different rate limits or pricing / Not be available in all regions». 쓰지 말라는 문장은 없고, 무엇이 바뀔 수 있는지를 밝힌다."
    touches: []
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://kubernetes.io/docs/reference/using-api/"
    supports: current
    claim: "Kubernetes 는 단계마다 쓸 자리를 문장으로 정한다. Alpha: «disabled by default», «Support for an alpha API may be dropped at any time without notice», «recommended for use only in short-lived testing clusters». Beta: «The support for a feature will not be dropped, though the details may change», «The software is not recommended for production uses». Stable: 주 판 안에서 계속 제공. 실험 단계를 기반으로 쓰지 말라는 쪽의 공식 선례이되, alpha 와 beta 를 다르게 다룬다."
    touches: []
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://nodejs.org/api/documentation.html"
    supports: current
    claim: "Node.js 안정성 지표: «Stability: 1 - Experimental. ... Non-backward compatible changes or removal may occur in any future release. Use of the feature is not recommended in production environments.» 실험 안에도 단계가 있다(1.0 초기 개발 · 1.1 활발한 개발 · 1.2 출시 후보 «No further breaking changes are anticipated but may still occur»). 그 위에 짓는 쪽에 대한 경고가 따로 있다 — «Use caution when making use of Experimental features, particularly when authoring libraries. Users may not be aware that experimental features are being used.»"
    touches: []
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://www.thoughtworks.com/radar/faq"
    supports: both
    claim: "Thoughtworks Technology Radar 는 통과 · 탈락 대신 네 단으로 가른다 — Adopt «blips that we think you should seriously consider using», Trial «ready for use, but not as completely proven», Assess «things to look at closely, but not necessarily trial yet». Trial 에 들려면 실사용 경험이 필요하다(«We can only put blips into the Trial ring when we have experience of using that blip for production software»). 넷째 단의 이름은 자료가 갈린다 — 이 FAQ 를 읽은 결과는 «Caution», 검색으로 본 다른 Thoughtworks 글은 «Hold»."
    touches: []
    decides: [OQ2, OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain

  # ── OQ4: 에이전트 조율용 프레임워크를 따로 다룬 선례 ─────────────────────
  - url: "https://www.anthropic.com/engineering/building-effective-agents"
    supports: alternative
    claim: "Anthropic 의 «Building effective agents»(2024-12-19, 페이지는 그 뒤 도구 지형이 바뀌었다고 적고 프레임워크 예시에 Claude Agent SDK 등을 든다)는 에이전트 프레임워크만은 «있는 것 먼저»의 반대를 권한다 — 프레임워크는 «make it easy to get started» 이지만 «often create extra layers of abstraction that can obscure the underlying prompts» 이고, «We suggest that developers start by using LLM APIs directly». 쓴다면 밑의 코드를 이해하라고 한다. 에이전트 조율 프레임워크를 일반 패키지와 다르게 다룬 공식 벤더 선례다. 공개 뒤 2년 가까이 지난 글이다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://github.com/humanlayer/12-factor-agents"
    supports: alternative
    claim: "실무자 글(12-factor agents, 날짜 표기 없음): «I don't see a lot of frameworks in production customer-facing agents», 대부분이 «rolling the stack themselves». 프레임워크로 «Get to 70-80% quality bar» 까지 간 뒤 «Start over from scratch» 하는 경로를 적고, 원칙으로 «Own your prompts» · «Own your control flow» 를 든다. 한 사람의 관찰이고 조사 수치는 아니다."
    touches: []
    decides: [OQ4]
    source_kind: secondary
    checked_at: "2026-11-15"
    certainty: uncertain

repo_claims:
  - id: RC1
    path: "CLAUDE.md"
    anchor: "**있는 것 먼저.** 만들기 전에 레포 안 · 밖의 있는 것을 검토하고 외부 것은 사용자 검토 뒤 쓴다(철학 P8)."
    line: 34
    claim: "레포 규칙은 «검토한다»와 «외부 것은 사용자 검토 뒤 쓴다»까지만 적는다. 있으면 쓰는 것이 기본이라는 문장도, 직접 만들 때 이유 · 승인을 요구하는 문장도 없다. 승인이 걸린 쪽은 외부 것을 쓰는 쪽 하나다."
    touches: []
    decides: [OQ6, OQ7, OQ1]

  - id: RC2
    path: "docs/philosophy/devbrew-harness-philosophy.md"
    anchor: "### P8 — Determinism Economy (Maintain Simplicity) › (재사용)"
    line: 85
    claim: "철학 문서의 근거 문장은 «새로 만든 것은 유지할 표면이 되므로 레포 안 · 밖에 있는 것을 먼저 검토하고, 외부 것은 사용자가 검토한 뒤에 쓴다(P17)» 다. 이유(유지 표면)는 적지만 결론의 기본값은 정하지 않는다."
    touches: []
    decides: [OQ6, OQ7]

  - id: RC3
    path: "plugins/spec-distill/skills/pm-interview/SKILL.md"
    anchor: "**있는 것 먼저.** 무엇을 만들자는 결정이 열리면"
    line: 312
    claim: "인터뷰 조사 단계는 레포 안의 있는 것을 먼저 찾고 «바깥의 성숙한 것(패키지 · 프레임워크 · 도구)을 웹으로 찾는다», 바깥 후보는 brief 에 싣고 «바깥 것은 사용자 검토 뒤에만 쓴다 — 후보와 차이를 보이고 묻는다». «성숙한»을 가르는 기준은 이 문단에 없고, 찾은 뒤 어느 쪽이 기본인지도 없다. 만들 것이 없는 일이면 건너뛰고 이유를 적는다."
    touches: []
    decides: [OQ6, OQ2, OQ7, OQ1]

  - id: RC4
    path: "plugins/spec-distill/references/epic-handoff.md"
    anchor: "설계문서에 ## 있는 것 검토 절(레포 안에 이미 있는 것을 먼저 찾아 쓰고, 레포 밖 패키지 · 프레임워크 · 서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다)"
    line: 7
    claim: "에픽 넘김 줄은 레포 안과 밖을 다르게 다룬다 — 레포 안의 것은 «먼저 찾아 쓰고»(쓰는 것이 기본), 레포 밖의 것은 «후보로만 적어 사용자가 승인한 뒤에만 쓴다». 레포 밖 것에 대해서는 쓰는 쪽에만 승인이 걸리고, 후보를 적은 뒤 직접 만들기로 결론 내는 쪽에는 이유 · 승인 요구가 없다. 같은 줄의 앞쪽 «## 있는 것 검토 절에 적는다»는 묶음 근거가 지금도 맞는지의 조사 기록을 가리켜, 한 절 이름이 두 가지 일을 맡는다."
    touches: []
    decides: [OQ6, OQ7]

  - id: RC5
    path: "plugins/spec-distill/references/docreview-profiles/design-doc.md"
    anchor: "`required_sections` — 필수 섹션 누락. Context/Why · Goals · Non-goals · Constraints · Acceptance Criteria · Files to Modify · Verification Plan · Rejected Alternatives · Metadata"
    line: 108
    claim: "설계문서 리뷰 프로필의 필수 섹션 목록에 «Rejected Alternatives» 는 있고 «있는 것 검토» 는 없다. docreview-profiles 폴더를 «있는 것 · 재사용 · existing · reinvent · 직접 만» 으로 검색했을 때 이 절의 내용(결론이 직접 만들기일 때의 이유)을 판정 기준으로 삼는 줄은 나오지 않았다. 테스트(`plugins/spec-distill/tests/test_end_gates.sh` 68행 · `test_epic_handoff.sh` 64행)는 넘김 줄에 그 문구가 있는지를 잠근다. 검색 기반 확인이라 다른 낱말로 적힌 기준이 있을 가능성은 남는다."
    touches: []
    decides: [OQ6]

  - id: RC6
    path: "docs/superpowers/specs/2026-10-15-roadmap-control-plane-design.md"
    anchor: "## Constraints › 실험 기능은 기반으로 쓰지 않는다(D33) — 기반은 작업 목록 · 상태줄 설정 · 진입 skill."
    line: 64
    claim: "예전 로드맵의 제약은 그 설계문서의 Constraints 한 줄이고, 뿌리인 D33(`docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md` 349행)의 문장은 «agent teams 같은 실험 기능은 기반으로 쓰지 않는다» 다. 그때 든 예가 agent teams 하나라, 실험 딱지(OQ3)와 에이전트 조율용 기능(OQ4)이 같은 사례에서 겹친다. 같은 결정 문장 안에 «있는 것을 먼저 쓰며»도 들어 있다."
    touches: []
    decides: [OQ3, OQ4]

  - id: RC7
    path: "plugins/spec-distill/dependencies.md"
    anchor: "| claude-code | 2.1.303 | 2026-10-22 | 기록 | 잰 판을 기록만 한다 |"
    line: 19
    claim: "이 레포가 적어 둔 Claude Code 판은 2.1.303(2026-10-22 잼, 강도 «기록»)이다. 같은 표가 외부 의존마다 이름 · 최소 판 · 강도(멈춤 · 알림 · 기록) · 없을 때 동작을 적는 자리로 이미 있다 — 들인 뒤의 의존을 적는 장치는 있고, 들이기 전에 «검증된» 것인지 가르는 칸은 없다."
    touches: []
    decides: [OQ1, OQ2]

  - id: RC8
    path: "docs/superpowers/specs/2026-10-19-principles-docs-cleanup-design.md"
    anchor: "| 6 | 있는 것 먼저 | 「기존에 있던거를 사용할 수 있는지 검토하는 성향이면 좋겠어 레포 내부든 외부든 … 다만 외부는 나한테 검토 받고 사용하는거로」"
    line: 70
    claim: "원칙이 들어올 때의 사용자 말은 «검토하는 성향»과 «외부는 검토받고 사용»이었고, 설계는 이를 «먼저 검토한다 · 외부 것은 사용자 검토 뒤에만 쓴다»로 옮겼다. 기본값 · 직접 만들 때의 승인은 그때 요구에 없었다."
    touches: []
    decides: [OQ6, OQ7]

unanswered: "찾지 못했거나 확인하지 못한 것 — (가) 소프트웨어 설계문서 · RFC 의 대안 절이 결론을 실제로 바꿨는지를 잰 대조 연구는 못 찾았다(있는 것은 무기 획득 대안 분석의 상관 보고와 ADR 대안 칸이 덜 채워진다는 관측뿐). (나) 쓰는 쪽과 만드는 쪽 «둘 다» 승인이 필요한 제도에서 «기본»이 무엇을 바꾸는지를 직접 다룬 선례는 못 찾았다 — 찾은 선례는 모두 한쪽에만 승인을 건다(행정명령 14271 은 안 쓰는 쪽, Chromium · Kubernetes 는 들이는 쪽). 가장 가까운 것은 사용자에게 먼저 묻되 닿지 못하면 만들고 PR 에 제안하라는 공개 레포 규칙 하나와 사람 대상 기본값 효과 메타분석이다. (다) 의존성 정책 안에서 에이전트 조율용 프레임워크를 따로 범주로 다룬 조직 규칙은 못 찾았고, 벤더 글 하나와 실무자 글 하나만 있다. (라) 원문을 못 연 것: OMB M-16-21 원문(404, 현재 효력 미확인) · 미 국방부 2022 메모 PDF(403) · GAO 대안 분석 모범 관행 전체 목록(403) · Google Cloud 출시 단계 정의(본문 잘림) · Nutt 원저 · Not-Invented-Here 논문(Antons & Piller 2015) 원문. (마) Claude Code 자체 시스템 지시문과 superpowers 등 외부 플러그인 skill 이 «있는 라이브러리를 먼저 쓰라»를 어떻게 적는지는 확인하지 않았다."
```

서로 어긋나는 주장(하나로 고르지 않고 둘 다 냄).
- 에이전트의 경향: LibraryDesignBench · Tessl · Anthropic 프롬프트 지침은 «다시 만든다 · 과하게 만든다»를, arXiv 2503.17181 은 «널리 쓰이는 라이브러리를 필요 없이 쓴다»를, arXiv 2512.11589 는 «있는 의존은 자주 쓰고 새 의존은 드물게 들인다»를 보고한다. 재는 대상(에이전트 대 직접 생성, 과제 종류)이 서로 다르다.
- 승인 방향: 행정명령 14271 · M-16-21 · 스코틀랜드 매뉴얼은 «안 쓰는 쪽»이 이유를 대고, Chromium · Kubernetes · ultralytics 는 «들이는 쪽»이 이유를 댄다. 공개 레포 두 곳(whisper-money · dasik)은 들이는 쪽에만 건 승인이 에이전트를 직접 만들기로 몰았다고 보고하고 규칙을 고쳤다.
- 검증 기준의 결합: OpenSSF Best Practices 배지는 필수 항목 전부, Homebrew 는 축 사이는 모두 · 인기 축 안은 하나, OpenSSF 평가 지침 · Scorecard · CHAOSS 는 문턱 없는 고려 사항이나 가중 평균이다.
- 실험 단계: Kubernetes · Node.js 는 운영에 쓰지 말라고 적고(단계별로 다르게), CNCF · OpenSSF 지침 · Anthropic 베타 문서는 금지 없이 누구에게 맞는지 · 무엇이 바뀔 수 있는지를 밝힌다.

읽은 레포 파일(절대 경로).
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/CLAUDE.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/philosophy/devbrew-harness-philosophy.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/skills/pm-interview/SKILL.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/epic-handoff.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/docreview-profiles/design-doc.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/dependencies.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-15-roadmap-control-plane-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-19-principles-docs-cleanup-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/interview/2026-11-15-existing-framework-first-interview.md

RC5 의 테스트 파일 두 개와 RC6 의 D33 원문, RC8 은 파일을 열지 않고 검색 결과의 해당 줄로만 확인했다.


## R1

### 지금 이해

(경로 a — 레포 · 웹 조사) 「있는 것 먼저」 문장은 일곱 자리에 살고 모두 「검토 + 외부 것은 사용자 승인」까지다 — 쓰는 쪽이 기본이라는 문장도, 직접 만들 때 이유 · 승인을 요구하는 문장도 없다. 다른 레포에 닿는 것은 spec-distill 의 세 자리뿐이고, 「있는 것 검토」 절의 결론을 읽는 검사 · 리뷰 항목은 없다.

함께 띄운 이유: 커버리지 조사(필수) · 레포 조사 둘 · 웹 조사 둘은 서로 기대지 않는 질문이라 한 묶음으로 띄웠다.
공시: 레포 조사 둘 · 웹 조사 둘에는 조사 주장 계약의 전문이 아니라 형식 · 규칙만 남긴 줄인 본을 실었다(커버리지 조사는 전문).
seed 문장 분류: 사용자 확인 10 · 저자 9(분류기 audit ok). «다시 검증할 것» 문단의 레포로 확인 가능한 항목(예전 로드맵 결정 · 규칙 문서만 고치면 닿지 않음)은 RC1 · RC4 · RC26 으로 확인했다.
파생 차원: coverage-mapper 제안 일곱을 다섯으로 합쳐 받았다(2 · 7 → conclusion_judge, 3 · 5 → fit_judgment). internal_research 는 레포 주장 첫 산출로 열었다.
번호: 조사가 낸 레포 주장의 임시 번호는 버리고 아래 전역 번호로 다시 붙였다. 같은 자리를 가리키는 주장은 하나로 합쳤다. 아래에 없는 조사 주장은 «지금 이해»에 싣지 않았다.

- 확인 RC1 — 확인 — .claude-plugin/marketplace.json#"source": "./plugins/spec-distill" — 주장과 일치(설치본에 실리는 것은 plugins/<이름>/ 넷뿐이다)
- 확인 RC2 — 확인 — CLAUDE.md#**있는 것 먼저.** 만들기 전에 레포 안 · 밖의 있는 것을 검토하고 — 주장과 일치(검토와 외부 것의 사용자 검토까지, 기본값 없음)
- 확인 RC3 — 확인 — docs/philosophy/devbrew-harness-philosophy.md#(재사용) 새로 만든 것은 유지할 표면이 되므로 — 주장과 일치
- 확인 RC4 — 확인 — docs/superpowers/specs/2026-10-19-principles-docs-cleanup-design.md#**두 갈래의 「다른 레포」.** — 주장과 일치(CLAUDE.md 는 devbrew 개발 세션만 읽고, 남의 레포에서는 플러그인 동작 자리에 실려야 지켜진다)
- 확인 RC5 — 확인 — docs/superpowers/specs/2026-10-17-epic-conductor-design.md#결정 · 2026-10-17 · 이해 확인 — 주장과 일치(원칙이 들어올 때의 사용자 말은 「검토하는 성향」이었다)
- 확인 RC6 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#**있는 것 먼저.** 무엇을 만들자는 결정이 열리면 — 주장과 일치(찾기 · 싣기 · 묻기까지, 발동은 「만들자는 결정」, 「성숙한」의 기준 없음)
- 확인 RC7 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#**다음 세션 줄 — ①/② 공통** — 주장과 일치(설계 단계의 요구는 넘김 줄의 산문으로만 전달된다)
- 확인 RC8 — 확인 — plugins/spec-distill/references/epic-handoff.md#설계문서에 ## 있는 것 검토 절 — 주장과 일치(레포 안은 「찾아 쓰고」, 밖은 「후보로만 적어 사용자가 승인한 뒤에만」 — 한 절이 근거 재확인과 재사용 검토 두 일을 맡는다)
- 확인 RC9 — 확인 — plugins/spec-distill/tests/test_end_gates.sh#SHARED= — 주장과 일치(검사는 넘김 줄에 문구가 있는지만 잰다)
- 확인 RC10 — 확인 — plugins/spec-distill/references/docreview-profiles/design-doc.md#`required_sections` — 주장과 일치(필수 절 아홉에 「있는 것 검토」 없음 · web: false · 사다리는 레포 안만)
- 확인 RC11 — 확인 — plugins/spec-distill/references/docreview-profiles/brief.md#`direction` — 주장과 일치(brief 리뷰어는 「더 성숙한 외부 대안」을 웹으로 본다)
- 확인 RC12 — 확인 — plugins/spec-distill/scripts/check_bundle_coverage.py#(부재) 있는 것 검토 — 주장과 일치(plugins · shared · tools 의 .py · .js · agents · hooks · SKILL.md 에 그 글자 0건 — 하한)
- 확인 RC13 — 확인 — plugins/spec-distill/scripts/check_brief.py#External Landscape empty — 주장과 일치(brief §4 검사는 구조만 잰다)
- 확인 RC14 — 확인 — plugins/spec-distill/skills/spec-review/SKILL.md#writing-plans 를 시작하라 — 주장과 일치(계획으로 넘기는 줄과 계획 agent 틀에 「있는 것」 요구 없음)
- 확인 RC15 — 확인 — plugins/spec-distill/references/conducting.md#설계 전 조사는 꼼꼼히 — 주장과 일치(지휘자는 epic-handoff 를 가리킬 뿐 그 절을 확인하는 걸음이 없다)
- 확인 RC16 — 확인 — docs/superpowers/specs/2026-10-23-rules-docs-cleanup-design.md#- 레포 밖: 쓰지 않는다. — 주장과 일치(「있는 것 검토」 머리를 가진 설계문서 11건 — `##` 9건은 절 전문을, `### §8` 2건은 해당 줄을 읽었다. 새 외부 것을 기반으로 삼은 것 0건, 레포 밖 칸은 대부분 한 줄로 닫힌다)
- 확인 RC17 — 확인 — docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md#**레포 밖**: markdown-it-py — 주장과 일치(외부 패키지를 후보로 보이고 결정받은 기록 — 테스트에서만, 사용자 환경에 의존을 만들지 않으려고)
- 확인 RC18 — 확인 — docs/superpowers/specs/2026-10-17-epic-conductor-design.md#**레포 밖(사용자 승인됨 — 주장과 일치(Claude Code 기본 기능 · superpowers skill 을 레포 밖으로 다루고 묶음 한 번으로 승인받았다. 새 패키지 의존은 넣지 않았다)
- 확인 RC19 — 확인 — docs/superpowers/specs/2026-10-20-dependency-portability-design.md#- 기각: Claude Code plugin.json `dependencies` — 주장과 일치(공식 기능 둘을 적합 이유로 기각하고 직접 만들었다. 기각은 지휘자 판단으로 적혀 있다)
- 확인 RC20 — 확인 — docs/superpowers/specs/2026-10-12-interview-persistent-explore-design.md#**내장 Explore 로 레포 조사** — 주장과 일치(내장 agent 를 레포 자신의 규칙 때문에 기각했고 권장 선택지가 새로 만들기였다)
- 확인 RC21 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/token-baseline.md#ccusage(외부) — 주장과 일치(「외부 도구는 사용자 검토 뒤에 쓴다」가 검토를 청하는 문이 아니라 쓰지 않는 이유로 쓰였다)
- 확인 RC22 — 확인 — docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md#K2. 외부 플러그인 리뷰어(pr-review-toolkit)를 쓰는 방식은 유지한다. — 주장과 일치(사용자 선택이 결론을 외부 것 쓰기로 정한 기록)
- 확인 RC23 — 확인 — docs/archive/specs/2026-07-19-plugin-audit-plugin-design.md#**재발명하지 말고 감싸라.** — 주장과 일치
- 확인 RC24 — 확인 — docs/superpowers/specs/2026-08-05-agent-transparency-design.md#**output style**(본체 — 주장과 일치(Claude Code 기본 기능을 본체로 삼은 기록. `force-for-plugin: true` 를 썼고 그 플러그인은 뒤에 제거됐다 — 제거 이유는 읽지 않았다)
- 확인 RC25 — 확인 — CLAUDE.md#**최소 버전이 선언된 의존성.** — 주장과 일치(외부 것을 들이면 의존 표 · 없을 때 동작 · 공시가 붙고 레포 안에 만들면 붙지 않는다)
- 확인 RC26 — 확인 — docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md#☑ confirmed **D33** — 주장과 일치(「실험 기능은 기반으로 쓰지 않는다」는 한 로드맵에서 고른 선택지이고 가리킨 것은 agent teams 다. CLAUDE.md · 철학 문서에는 없다)
- 확인 RC27 — 확인 — plugins/spec-distill/references/fresh-evidence.md#최신과 안정이 갈리면(새 판 · 실험 기능 · 막 바뀐 정책) 차이를 보이고 선택지로 묻는다 — 주장과 일치
- 확인 RC28 — 확인 — docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.md#agent 팀은 리드 고정 · 세션당 팀 하나 — 주장과 일치(2026-11-14 에 다시 기각했고 이유는 구체 한계다)
- 확인 RC29 — 확인 — docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.md#🗣 confirmed **C5** — 주장과 일치(「특정 외부 도구에 하드코딩되거나 의존이 생기는 것은 피한다」는 사용자 확정 제약)
- 확인 RC30 — 확인 — plugins/project-init/skills/project-init/SKILL.md#**AGENTS.md를 canonical content source로** — 주장과 일치(대상 레포의 규칙 파일에 쓰는 표면은 이것 하나이고 사용자가 불러야 돈다. 템플릿에 재사용 규칙은 없다)
- 확인 RC31 — 확인 — plugins/project-init/hooks/hooks.json#"PostToolUse" — 주장과 일치(레포의 플러그인 훅은 이것 하나이고 세션 시작 훅은 없다)
- 확인 RC32 — 확인 — plugins/spec-distill/references/trivia-escape.md#한 문장으로 설명 가능한 사소한 변경이면 — 주장과 일치(사소한 변경은 진입에서 빠져 인터뷰 · 설계에 닿지 않는다)
- 확인 RC33 — 확인 — CLAUDE.md#중간 크기 일은 이유를 밝히고 가벼운 꼴 — 주장과 일치(가벼운 꼴은 CLAUDE.md 에만 있고 플러그인 .md 에는 그 낱말이 없다)
- 확인 RC34 — 확인 — plugins/spec-distill/dependencies.md#| claude-code | 2.1.303 — 주장과 일치
- 확인 RC35 — 확인 — docs/superpowers/specs/2026-09-21-designer-lens-review-design.md#### 1.3 외부 조달 결과 — 주장과 일치(외부에서 조달해 절반만 얻었고, 나머지를 레포에서 만드는 전환을 사용자 동의로 기록했다)
- 확인 RC36 — 확인 — docs/superpowers/interview/2026-10-03-plain-language-output-interview.md#위험 — 숨은 가정 | CLAUDE.md 에 규칙을 두면 devbrew 사용자 모두에게 닿는다 — 주장과 일치(앞선 brief 가 같은 물음을 「틀림」으로 닫았다)
- 확인 RC37 — 확인 — docs/superpowers/interview/2026-11-15-existing-framework-first-interview.audit.md#**「맞는 프레임워크」** 에서 맞는지를 누가 무엇으로 판단하는지 모르겠다 — 주장과 일치(냉독이 짚은 빈 곳)
- 확인 RC38 — 확인 — docs/superpowers/specs/2026-10-17-epic-conductor-design.md#- agent teams · Workflow 기반 — 주장과 일치(뒤 설계가 같은 결정을 Workflow · 병합 대기열 서비스로 넓혀 걸었다)
- 확인 RC39 — 미확인 — docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md#플러그인 monitor 의 한 줄이 알림 하나가 되고 — 그 줄은 실재하지만 monitor 가 최종 기반에 들어갔는지와 그 딱지를 사용자에게 보였는지는 확정하지 못했다
- 확인 RC40 — 미확인 — docs/superpowers/specs/2026-10-25-epic-parallel-recommend-design.md#레포 안에 있는 것을 먼저 썼다 — 절은 확인했으나 짝 brief 의 「머지 큐 [취함]」 줄은 조사가 든 줄 번호에서 찾지 못했다(brief 파일 날짜가 다르다)

웹 근거(본체가 1차 자료를 직접 다시 읽은 것):

- «cc-plugin-manifest» 플러그인 루트의 CLAUDE.md 는 컨텍스트로 실리지 않고, 실리는 지시는 skill 에 두라고 적는다. 매니페스트의 `experimental` 은 themes · monitors · evals 의 그릇이다 — https://code.claude.com/docs/en/plugins/manifest-reference.md (1차 · 확인 2026-11-15) [→ OQ1]
- «cc-output-styles» 플러그인 output style 은 `force-for-plugin: true` 로 자동 적용되고 매 요청에 실리지만 한 번에 하나만 활성이고 사용자의 설정을 덮으며 subagent 에는 적용되지 않는다 — https://code.claude.com/docs/en/output-styles.md (1차 · 확인 2026-11-15) [→ OQ1]
- «cc-agent-teams» agent teams 는 지금도 실험 기능이고 기본으로 꺼져 있으며 세션 재개 · 팀 하나 · 중첩 불가 한계가 적혀 있다 — https://code.claude.com/docs/en/agent-teams.md (1차 · 확인 2026-11-15) [→ OQ3]
- «whisper-money-1076» 「승인 없이 의존을 바꾸지 말라」를 에이전트가 금지로 읽어 유지되는 패키지가 풀 일을 직접 만들었다고 적고, 패키지 · 대체하는 것 · 크기 · 유지 상태 · 직접 만드는 대안을 보이고 승인받게 고쳤다 — https://github.com/whisper-money/whisper-money/pull/1076 (1차 · 확인 2026-11-15) [→ OQ6]
- «chromium-third-party» 들이는 쪽이 이유를 대고 승인받으며 들인 사람이 주인이 된다. 최근 2년 안의 릴리스를 요구한다 — https://chromium.googlesource.com/chromium/src/+/main/docs/adding_to_third_party.md (1차 · 확인 2026-11-15) [→ OQ7]
- «openssf-eval-guide» 첫 항목이 「있는 것으로 피할 수 있는가」이고, 유지는 12개월 안의 활동 · 릴리스로 보며, 전부 통과를 요구하지 않는다. 판 문자열의 불안정 표시는 금지가 아니라 평가 항목이다 — https://best.openssf.org/Concise-Guide-for-Evaluating-Open-Source-Software (1차 · 확인 2026-11-15) [→ OQ2]
- «library-design-bench» 에이전트는 라이브러리를 들이고도 덜 쓰고 이미 있는 기능을 다시 만든다. 원인은 기능 부재보다 라이브러리가 굳고 쓰기 어려운 데 있다(심사 전 논문, 초록 확인) — https://arxiv.org/abs/2609.36730 (1차 · 확인 2026-11-15) [→ OQ6]
- «agents-md-eval» 레포 규칙 파일의 지시는 잘 따라지지만 과제 성공률은 대체로 오르지 않고 비용이 평균 20% 넘게 는다(초록 확인) — https://arxiv.org/abs/2602.11988 (1차 · 확인 2026-11-15) [→ OQ1]

웹 근거(조사 보고 — 본체가 다시 읽지 못함, 확인 못 함):

- «cc-hooks» 플러그인 훅은 세션이 플러그인을 실을 때 등록되고 세션 시작 훅의 출력이 컨텍스트에 들어간다(문자열마다 10,000자 상한). 이 세션에서 다른 플러그인의 세션 시작 주입은 직접 관찰했다 — https://code.claude.com/docs/en/hooks.md (1차 · 조사 4 · 상한 수치는 확인 못 함) [→ OQ1]
- «eo-14271» 미 행정명령은 있는 것(상용품)이 기본이고 안 쓰는 쪽만 이유 · 승인을 낸다 — https://www.govinfo.gov/content/pkg/FR-2025-04-18/html/2025-06835.htm (1차 · 조사 5 · 확인 못 함) [→ OQ7]
- «homebrew-policy» 축 사이는 모두, 인기 축 안은 하나를 요구하고 안정판이 없는 것은 받지 않는다 — https://docs.brew.sh/Package-Acceptance-Policy (1차 · 조사 5 · 확인 못 함) [→ OQ2]
- «k8s-api-stages» alpha 는 짧은 시험용에만, beta 는 운영에 권하지 않는다고 단계마다 쓸 자리를 적는다 — https://kubernetes.io/docs/reference/using-api/ (1차 · 조사 5 · 확인 못 함) [→ OQ3]
- «anthropic-effective-agents» 에이전트 프레임워크만은 LLM API 를 직접 쓰는 데서 시작하라고 권한다(2024-12 글) — https://www.anthropic.com/engineering/building-effective-agents (1차 · 조사 5 · 확인 못 함) [→ OQ4]
- «gao-09-665» 대안 분석이 좁았던 원인으로 후원자가 해법을 너무 일찍 정한 것을 든다(무기 획득의 상관 보고) — https://gao.gov/assets/a295855.html (1차 · 조사 5 · 확인 못 함) [→ OQ6]

조사 호출 7/60 · 이 라운드 본체 직접 9
밀린 질문 6개 — OQ4 에이전트 조율용 프레임워크 · OQ5 사소한 변경 · OQ7 두 승인의 흐름 · OQ8 「맞는」 판정 · OQ9 기본 기능도 승인 대상인가 · OQ10 효과 관측. 외부 근거의 처분과 방향 의심 검토(반론 조사 진행 중)는 다음 라운드.

### 다음 결정

OQ6: 검토가 형식에 그친 원인 가운데 겪은 것과 맞는 것 · 추천: 없음 — 사용자 경험을 묻는 질문 · 트레이드오프: 고른 원인이 하류 설계가 손댈 자리를 정한다
OQ1: 규칙이 어디에 살아야 하는가 · 추천: 단계 안에서만 · 트레이드오프: 단계 안에서만(확정 범위와 같고 새 장치 없음, 그 흐름 밖 일에는 안 닿음) / 대상 레포 규칙 파일에도(모든 세션에 닿음, 범위가 넓어지고 사용자가 불러야 함) / 세션마다 자동으로(설치만 하면 닿음, 새 훅을 만든다)
OQ2: 검증 기준 셋의 관계 · 추천: 보여 주는 정보로 · 트레이드오프: 정보로(승인 때 판단, 문턱 없음) / 셋 모두(엄격, 재기 어려운 범주가 빠짐) / 하나만(넓음, 약한 후보가 올라옴)
OQ3: 실험 딱지 기능 · 추천: 보이고 고른다 · 트레이드오프: 보이고 고른다(지금 플러그인 조사 규칙과 같은 방향) / 기반 후보에서 뺀다(지난 로드맵 결정을 상시 규칙으로)

### 질문

(경로 b — 판단) AskUserQuestion 한 번에 넷: 원인(여럿 고르기) · 규칙이 살 자리 · 검증 기준 셋 · 실험 기능.

### 답
→ S2 (OQ6 원인 — 넷 모두)
→ S3 (OQ1 — 단계 안에서만)
→ S4 (OQ2 — 보여 주는 정보로)
→ S5 (OQ3 — 보이고 고른다)

원장: root_problem 닫음(S1 · S2) · internal_research 닫음(레포 주장의 처분 S2) · rule_carrier 닫음(S3). OQ1 · OQ2 · OQ3 · OQ6 해결.
되묻기 대상: S3 · S4 · S5 는 이유 없는 추천 수락이다 — 다음 라운드에서 S3 의 실패 조건(흐름 밖 작은 고침으로 새는 것)을 OQ5 와 함께 되묻는다.

### 조사 6 — blind-spot-prober · R1 · 묶음 2

계약(`<claims_contract>`)은 받았다. 전제 번호(P<n>)는 입력에 없어서 `touches` 는 전부 빈 배열이다. `decides` 는 받은 OQ1–OQ10 안에서만 걸었다. framing 에 이미 실린 조사(승인을 외부 쪽에만 건 레포의 PR 둘 · 라이브러리를 들이고도 다시 만든다는 논문)는 되풀이하지 않고 새 근거만 실었다.

```yaml
hidden_assumptions:
  - assumption: "결론의 기본값을 뒤집고 «직접 만들려면 이유 + 사용자 승인»을 걸면 결론이 실제로 달라진다 — 승인이 걸러내는 장치로 작동한다."
    why_risky: "이유는 직접 만들고 싶은 쪽(모델)이 쓰고, 승인자는 그 이유의 진위를 따질 재료가 없다. 지금 「있는 것 검토」 절이 형식이 된 것과 같은 구조가 승인 한 겹 더 붙은 채 되풀이된다. 승인이 도장이 되면 사용자가 겪은 «검토했다고 적었지만 결론은 늘 직접 만들기»가 «승인까지 받았다»로 굳는다. 프레임워크를 쓸 때도 직접 만들 때도 승인이 붙으면 승인 횟수가 늘어 주의가 더 얇아진다."
    evidence:
      - url: "https://www.anthropic.com/engineering/claude-code-auto-mode"
        supports: current
        claim: "Anthropic 은 Claude Code 사용자가 수동 승인 요청의 93% 를 그대로 받아들인다고 적고, 이것이 «approval fatigue, where people stop paying close attention to what they're approving» 으로 이어진다고 적는다(2026-03-25)."
        touches: []
        decides: [OQ7, OQ6]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: confirmed
      - url: "https://researchportal.northumbria.ac.uk/en/publications/a-typology-for-exploring-the-quality-of-explanations-for-non-comp/"
        supports: current
        claim: "«지키거나 이유를 대라» 제도의 선례(영국 지배구조 규범, FTSE 350, 2004/05 · 2011/12): 준수율은 올랐지만 따르지 않은 이유 설명의 질은 들쭉날쭉했다. 설명의 내용을 판정하는 규정이 없으면 설명이 형식이 된다. 초록 · 검색 요약만 확인했고 전문은 읽지 못했다."
        touches: []
        decides: [OQ6, OQ10]
        source_kind: secondary
        checked_at: "2026-11-15"
        certainty: uncertain

  - assumption: "검증 기준 셋(공식 제공 · 널리 쓰임 · 유지 중)이 «믿고 그 위에 지어도 되는가»를 가른다."
    why_risky: "셋은 모두 대리 지표이고 저마다 따로 깨진다. 「널리 쓰임」은 조작되고, 「널리 쓰이고 유지 중」인 패키지가 공격 표적이 되며, 「공식」 기능도 철회가 예고된다. 그리고 framing 이 확인했듯 과거 기각 사유는 검증이 아니라 적합이었다. 셋을 모두 넘는 후보가 나와도 같은 적합 사유(도구 제한 · 없을 때 동작 · 설치자 환경 의존)로 다시 기각될 수 있다. 기준 셋을 정교하게 다듬는 일이 원인과 무관한 자리에 힘을 쓰는 것이 될 수 있다."
    evidence:
      - url: "https://arxiv.org/abs/2412.13459"
        supports: current
        claim: "GitHub 별 600만 개가 가짜로 추정되고 18,617 개 레포가 가짜 별 캠페인을 벌였다(2019-07 – 2024-12, ICSE 2026). 저자들은 별 수가 인기 신호로서 한계가 있다고 결론짓는다. 수치는 탐지 도구의 추정이다."
        touches: []
        decides: [OQ2, OQ8]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: confirmed
      - url: "https://endorlabs.com/learn/major-supply-chain-attack-compromises-popular-npm-packages-including-chalk-and-debug"
        supports: current
        claim: "2025-09-08 유지자 한 사람의 계정이 피싱으로 넘어가 chalk · debug 등 주간 내려받기 20억 회 규모의 npm 패키지에 악성 코드가 실렸다. 널리 쓰이고 유지되는 패키지였다는 점이 표적이 된 이유다. 패키지 수(18 – 25)는 출처마다 다르다."
        touches: []
        decides: [OQ2]
        source_kind: secondary
        checked_at: "2026-11-15"
        certainty: confirmed
      - url: "https://github.com/anthropics/claude-code/issues/10671"
        supports: current
        claim: "Claude Code 의 공식 기능 output styles 는 2025-11-05 제거가 예고됐다가 사용자 반발 뒤 2025-11-02 에 «keep output styles working indefinitely … at least until we are confident that we can offer you strictly better alternatives» 로 되돌려졌다. 공식 · 정식 기능도 철회 예고 대상이었다. 제거 예고의 세부는 이슈 안 사용자 보고를 거친 것이다."
        touches: []
        decides: [OQ3, OQ1, OQ2]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: confirmed

  - assumption: "모델이 후보 프레임워크와 그 검증 셋(공식인가 · 널리 쓰이나 · 유지되나)을 정확히 안다."
    why_risky: "기본값이 «쓴다»로 뒤집히면 모델이 후보를 «내놓아야» 하는 압력이 생긴다. 모델은 없는 패키지 이름을 지어내고 학습 시점의 낡은 API 를 쓴다. 승인 자리에서 사용자가 보는 «후보와 차이» 자체가 틀릴 수 있다. 검증 셋을 그 자리에서 실측하게 하지 않으면 기억으로 채운다."
    evidence:
      - url: "https://arxiv.org/abs/2406.10279"
        supports: current
        claim: "코드 생성 모델 16종에서 추천 패키지 가운데 없는 패키지의 비율이 상용 모델 최소 5.2%, 공개 모델 21.7% 였고 지어낸 이름은 205,474 가지였다(USENIX Security 2025). 공격자가 그 이름을 선점하면 공급망 공격이 된다."
        touches: []
        decides: [OQ8, OQ2]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: confirmed
      - url: "https://arxiv.org/abs/2406.09834"
        supports: current
        claim: "모델 7종 · 파이썬 라이브러리 8개 · 프롬프트 28,125 건에서 낡은 API 사용률이 높았다. 원인은 학습 자료의 낡은 예시와 추론 시점에 폐기 사실을 모르는 것이다(ICSE 2025). 검색 요약으로 확인했다."
        touches: []
        decides: [OQ8]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: uncertain

  - assumption: "인터뷰 · 설계 · 계획이 프레임워크를 고르면 구현이 그 위에서 이뤄진다 — 이번 범위(규칙 문장 + 세 단계)로 충분하다."
    why_risky: "범위가 계획에서 끝나고 구현 · 리뷰는 닿지 않는다. 에이전트는 검사받는 것에 맞춰 만든다. 설계문서에 «X 를 쓴다»가 적히고 승인까지 받았는데 구현은 X 를 얇게 들이고 같은 기능을 다시 짜는 결과가 가능하다. 이러면 유지 부담은 «직접 만든 것 + 의존» 둘 다가 된다."
    evidence:
      - url: "https://arxiv.org/abs/2606.28430"
        supports: current
        claim: "재사용 라이브러리를 만들라는 요청에 시험 오라클이 있으면 점수는 거의 만점인데 라이브러리는 죽었거나 없고 동작은 시연 코드 안에 직접 들어가 있었다. «The agent does not, on its own, validate what it ships as a user would.» 18회 실행 · 에이전트 둘의 작은 연구다."
        touches: []
        decides: [OQ10, OQ6]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: confirmed
      - url: "https://tessl.io/podcast/how-new-libraries-saw-a-50-improvement-maria-gorinova"
        supports: both
        claim: "실무 보고: 에이전트가 프로젝트의 표준 유틸을 두고 다시 짠다. 제안된 처방은 쓸 라이브러리와 import 경로를 «이름으로» 적고, 금지 패턴을 적고, 재발명을 AST · 정규식으로 검사하는 것이다. 개입별 효과 수치는 본문에 없다. 「특정 프레임워크 이름을 박지 않는다」는 제약과 방향이 엇갈린다."
        touches: []
        decides: [OQ6, OQ1]
        source_kind: secondary
        checked_at: "2026-11-15"
        certainty: uncertain

  - assumption: "규칙 문장을 어딘가에 두면 devbrew 플러그인을 쓰는 어느 레포에서든, 어떤 크기의 일에서든 그 문장이 읽힌다."
    why_risky: "설치본에 가는 규칙 문장은 skill 본문 · reference 안에만 있고 그 skill 이 불렸을 때만 컨텍스트에 실린다. 사소한 변경과 가벼운 꼴의 일은 인터뷰 · 설계를 거치지 않는다. 그런데 직접 만든 스크립트가 늘어난 길이 바로 그 «작은 고침»일 수 있다. «고칠 때 크기와 상관없이 함께 본다»는 문장이 발화할 자리가 없다. 긴 skill 본문의 한 문단으로 더하면 다른 지시에 묻힌다."
    evidence:
      - url: "https://code.claude.com/docs/en/plugins-reference"
        supports: current
        claim: "«A CLAUDE.md at the plugin root isn't loaded as context, and claude plugin validate warns when it finds one. To include instructions that load into Claude's context, put them in a skill.» 플러그인이 상시 규칙을 실을 공식 자리는 skill 뿐이다."
        touches: []
        decides: [OQ1]
        source_kind: primary
        checked_at: "2026-11-15"
        version: {used: "2.1.303", latest: "2.1.325"}
        certainty: confirmed
      - url: "https://scottspence.com/posts/claude-code-skills-dont-auto-activate"
        supports: current
        claim: "새 세션 20회 실측에서 skill 자동 활성은 전역 4/10 · 프로젝트 5/10 이었다(«Basically a coin flip»). 안정적이었던 것은 프롬프트 낱말을 잡아 skill 사용을 지시하는 훅이었다(2025-11-06, 2026-09-13 갱신). 한 사람의 실험이다."
        touches: []
        decides: [OQ1, OQ5]
        source_kind: secondary
        checked_at: "2026-11-15"
        certainty: uncertain
      - url: "https://arxiv.org/abs/2507.11538"
        supports: current
        claim: "지시 수가 늘수록 지시 준수가 떨어진다. 최상위 모델도 지시 500개에서 정확도 68% 이고 앞쪽 지시에 치우친다(IFScale, NeurIPS 2025). 긴 본문에 규칙 한 줄을 더하는 방식의 한계를 보인다. 검색 요약으로 확인했다."
        touches: []
        decides: [OQ1, OQ6]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: uncertain

  - assumption: "프레임워크 위에서 만들면 계기 넷(유지 부담 · 되풀이 버그 · 만드는 시간)이 줄어든다."
    why_risky: "부담은 사라지지 않고 꼴이 바뀐다. 상류의 깨는 변경 · 판 추적 · 없을 때 동작이 생긴다. devbrew 는 배포되는 플러그인이라 그 부담의 일부가 설치한 사용자에게 넘어간다. 계기 넷이 «직접 만든 것» 때문인지 «검사 · 락을 많이 두는 방식» 때문인지 갈라 보지 않았다. 후자라면 프레임워크로 옮겨도 같은 양의 접착 스크립트와 락이 남는다."
    evidence:
      - url: "https://arxiv.org/abs/2301.04563"
        supports: current
        claim: "npm 에서 의존의 «주 판이 아닌» 갱신이 낸 깨는 변경이 의존 패키지의 약 12%, 그 릴리스의 14% 에 영향을 줬고 절반만 스스로 회복했다."
        touches: []
        decides: [OQ7]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: confirmed
      - url: "https://code.claude.com/docs/en/plugins/dependencies.md"
        supports: current
        claim: "«Without a version constraint, a dependency moves to each new release … If that release renames an MCP tool your plugin calls, your plugin breaks for everyone who updates.» 다른 마켓플레이스의 플러그인은 기본으로 설치되지 않는다. plugin.json 에 선언한 경우 «the install completes without the dependency and your plugin then fails to load»."
        touches: []
        decides: [OQ7, OQ9, OQ1]
        source_kind: primary
        checked_at: "2026-11-15"
        version: {used: "2.1.303", latest: "2.1.325"}
        certainty: confirmed
      - url: "https://code.claude.com/docs/en/plugins-reference"
        supports: current
        claim: "새 공식 기능은 판 하한을 끌고 온다 — «If you declare options on any field, users on Claude Code versions before v2.1.271 can't load the plugin.» 같은 문서에 «Requires v2.1.2xx or later» 표기가 여럿 있다. 기본 기능 위에 지어도 설치자의 판에 따라 플러그인이 통째로 안 실릴 수 있다."
        touches: []
        decides: [OQ9, OQ3]
        source_kind: primary
        checked_at: "2026-11-15"
        version: {used: "2.1.303", latest: "2.1.325"}
        certainty: confirmed

  - assumption: "설계 · 계획 단계는 넘김 글 한 줄을 고치면 «프레임워크 먼저»로 바뀐다."
    why_risky: "그 단계의 주인은 고칠 수 없는 상류 skill 이고, 그 본문에는 반대로 읽힐 지시가 있다. 직접 만든 스크립트가 쌓인 레포에서 «있는 작업이 쓰는 것 위에 지어라»는 «지금의 직접 만든 스택을 이어 가라»로 읽힌다. 웹 조사는 선택이다. 넘김 글과 상류 본문이 부딪칠 때 어느 쪽이 이기는지 재 본 적이 없다. 이 단계가 프레임워크 위에 지었을 때 «규칙이 살아야 할 자리를 고칠 수 없게 되는» 비용의 실례이기도 하다."
    evidence:
      - url: "https://github.com/obra/superpowers/blob/main/skills/brainstorming/SKILL.md"
        supports: current
        claim: "상류 설계 skill 본문: «When there's existing work, build on what it already uses.» 웹 조사는 «Once you have a bit of grounding and looking further would help, go look» 로 선택이다. 선행 사례는 «what they've seen elsewhere» 로 사용자에게 듣는 항목이다. 로컬에 설치된 7.0.2 판 본문에서도 같은 문장을 읽었다."
        touches: []
        decides: [OQ1, OQ6]
        source_kind: primary
        checked_at: "2026-11-15"
        version: {used: "7.0.0", latest: "7.0.2"}
        certainty: confirmed

  - assumption: "프레임워크의 세 갈래(Claude Code 기본 기능 · 남이 유지하는 플러그인과 skill · 일반 패키지)와 «에이전트 조율용 프레임워크»가 서로 겹치지 않고, «실험 딱지»는 하나의 이분법이다."
    why_risky: "Claude Code 기본 기능 안에 조율 기능(subagent · workflow · agent teams)이 있어 첫 갈래와 «고르지 않은» 갈래가 겹친다. 실험 표시는 기능 단위 · manifest 칸 단위 · 환경변수 단위로 층이 다르다. 두 열린 결정을 따로 닫으면 «기본 기능이라 기본으로 쓴다»와 «조율 프레임워크라 대상 밖»이 같은 기능을 두고 엇갈린다."
    evidence:
      - url: "https://code.claude.com/docs/en/plugins-reference"
        supports: current
        claim: "plugin.json 은 `workflows` 를 정식 컴포넌트로 받고, 따로 `experimental` 칸(themes · monitors · evals)을 두며 그 칸을 «whose manifest shape may still change» 라고 적는다. 조율 기능이 정식 기본 기능의 일부이고 실험 표시는 칸 단위로 붙는다."
        touches: []
        decides: [OQ4, OQ3]
        source_kind: primary
        checked_at: "2026-11-15"
        version: {used: "2.1.303", latest: "2.1.325"}
        certainty: confirmed

failure_modes:
  - mode: "승인의 도장화 — «직접 만들기» 사유가 매번 그럴듯하게 적히고 매번 승인된다. 결론 분포는 그대로이고 승인 기록만 쌓인다."
    trigger: "사유를 모델이 쓰고, 사유의 진위를 다른 눈이 읽지 않으며(설계문서 리뷰는 웹이 꺼져 있고 그 절이 필수 절이 아님), 한 설계에서 승인 질문이 외부 사용 · 직접 만들기 양쪽으로 여러 번 뜬다."
    evidence:
      - url: "https://www.anthropic.com/engineering/claude-code-auto-mode"
        supports: current
        claim: "승인 요청의 93% 가 그대로 수락되고 주의가 얇아진다는 Anthropic 의 자체 수치."
        touches: []
        decides: [OQ7, OQ10]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: confirmed

  - mode: "과잉 채택으로의 반동 — «채택 건수»가 성공 지표가 되면 필요 없는 의존을 들인다. 11건 중 0건이 «실패의 증거»로만 읽히고, 정말로 맞는 것이 없었을 가능성은 지워진다."
    trigger: "검토가 형식이 아니게 됐는지를 외부 채택 수 · 비율로 잰다. 「맞는」의 판정 기준 없이 기본값만 «쓴다»로 둔다."
    evidence:
      - url: "https://arxiv.org/abs/2503.17181"
        supports: alternative
        claim: "모델 8종에서 NumPy 같은 널리 쓰이는 라이브러리를 과하게 쓰는 경향이 강했다. 그 사용의 최대 45% 는 필요 없었고 정답 풀이에서 벗어났다. 인기 있는 것 쪽으로 기우는 편향이 따로 있다는 뜻이다."
        touches: []
        decides: [OQ10, OQ8, OQ2]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: confirmed

  - mode: "지어낸 · 낡은 후보가 승인 자리에 올라간다 — 없는 패키지 이름, 폐기된 API, 옛 판 기준의 Claude Code 기능 설명."
    trigger: "후보와 검증 셋을 그 자리의 실측(레지스트리 · 릴리스 날짜 · 공식 문서) 없이 기억으로 채운다. 웹이 꺼진 실행(웹 kill switch · 설계문서 리뷰)."
    evidence:
      - url: "https://arxiv.org/abs/2406.10279"
        supports: current
        claim: "상용 모델도 추천 패키지의 5.2% 이상이 없는 패키지였다."
        touches: []
        decides: [OQ8]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: confirmed

  - mode: "설계는 채택, 구현은 재구현 — 설계문서 · 계획에는 프레임워크가 적혔는데 구현은 그것을 얇게 들이고 같은 기능을 옆에 다시 짠다. 의존 표 한 줄과 직접 만든 스크립트가 둘 다 남는다."
    trigger: "이번 범위가 계획에서 끝나 구현 · 최종 리뷰에 «고른 프레임워크를 실제로 썼는가»를 보는 항목이 없다."
    evidence:
      - url: "https://arxiv.org/abs/2606.28430"
        supports: current
        claim: "검사되는 것에 맞춰 만들고 요청된 재사용 구조는 비워 두는 «building to the test»."
        touches: []
        decides: [OQ10]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: confirmed

  - mode: "규칙이 닿지 않는 길로 직접 만들기가 계속 샌다 — 사소한 변경 · 가벼운 꼴 · skill 을 부르지 않은 세션 · 다른 레포의 일반 작업."
    trigger: "규칙을 인터뷰 skill 본문과 넘김 글에만 둔다. «고칠 때 크기와 상관없이»를 약속하면서 사소한 변경은 진입에서 skill 을 끝낸다."
    evidence:
      - url: "https://scottspence.com/posts/claude-code-skills-dont-auto-activate"
        supports: current
        claim: "skill 자동 활성이 반반 수준이라는 실측. 안정적인 것은 훅이었다."
        touches: []
        decides: [OQ1, OQ5]
        source_kind: secondary
        checked_at: "2026-11-15"
        certainty: uncertain

  - mode: "설치자에게 넘어가는 고장 — devbrew 가 남의 플러그인 · 새 공식 기능 위에 지은 뒤, 설치한 레포에서 플러그인이 통째로 안 실리거나 상류 갱신 한 번에 깨진다."
    trigger: "다른 마켓플레이스 플러그인을 plugin.json `dependencies` 로 선언한다. 판 제약 없이 의존한다. 판 하한이 있는 manifest 칸을 쓴다."
    evidence:
      - url: "https://code.claude.com/docs/en/plugins/dependencies.md"
        supports: current
        claim: "교차 마켓플레이스 의존은 허용 목록 없이는 설치되지 않고, plugin.json 선언이면 설치는 끝나되 플러그인이 실리지 않는다. 제약 없는 의존은 상류의 다음 릴리스로 옮겨 간다."
        touches: []
        decides: [OQ9, OQ7]
        source_kind: primary
        checked_at: "2026-11-15"
        version: {used: "2.1.303", latest: "2.1.325"}
        certainty: confirmed

  - mode: "공식 기능의 철회 · 형태 변경이 규칙의 «사는 자리»째 흔든다 — 규칙을 실은 공식 표면(예: 자동 적용 output style)이 폐기 예고 대상이 된다."
    trigger: "«공식 제공» 하나만 넘으면 검증된 것으로 본다. 실험 표시가 없다는 것을 안정의 증거로 읽는다."
    evidence:
      - url: "https://github.com/anthropics/claude-code/issues/10671"
        supports: current
        claim: "output styles 는 정식 기능이었는데 제거가 예고됐다가 «무기한 유지»로 되돌려졌다. 되돌린 조건도 «더 나은 대안을 줄 수 있다고 확신할 때까지»다."
        touches: []
        decides: [OQ1, OQ2, OQ3]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: confirmed

confidence: 0.72

repo_claims:
  - id: RC1
    path: "docs/superpowers/specs/2026-10-20-dependency-portability-design.md"
    anchor: "기각: Claude Code plugin.json `dependencies`(superpowers 가 없으면 spec-distill 전체가 꺼진다 — U6 과 충돌)"
    line: 247
    claim: "이 레포는 2026-10-20 에 공식 의존 선언 기능을 이미 검토해 기각했다. 사유는 검증이 아니라 «없을 때 플러그인 전체가 꺼진다»는 사용자 결정(U6)과의 충돌이다. 같은 줄에서 `userConfig` 도 «레포 단위로 둘 수 없고 Bash 명령 환경에 없다»로 기각했다. «프레임워크 위에서가 기본»이 되면 이 기각을 다시 열어야 하는지, 같은 사유가 «맞지 않음»의 정당한 이유로 남는지가 정해지지 않았다."
    touches: []
    decides: [OQ8, OQ9, OQ7]
  - id: RC2
    path: "docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.md"
    anchor: "특정 외부 도구에 하드코딩되거나 의존이 생기는 것은 피한다. (사용자 확인)"
    line: 21
    claim: "하루 전 같은 사용자가 확정한 제약이 «의존이 생기는 것은 피한다»이고, 같은 줄에 «superpowers 하나에 묶이지 않고 … 다른 작업 방식도 끼워 쓸 수 있게»가 있다. «검증된 프레임워크 위에서 작업»과 방향이 반대인 확정 둘이 이틀 사이에 나란히 있다. 둘의 경계(무엇이 «묶임»이고 무엇이 «위에서 짓기»인가)가 없으면 모델은 직접 만들기의 사유로 앞의 것을 인용할 수 있다."
    touches: []
    decides: [OQ7, OQ8, OQ6]
  - id: RC3
    path: "plugins/spec-distill/references/trivia-escape.md"
    anchor: "**그대로** — 다음 안내를 내고 진행하지 않는다"
    line: 31
    claim: "사소한 변경으로 판정되면 진입 skill 이 안내만 내고 끝난다(→ END). 그 뒤 처리는 skill 밖이라 skill 본문의 어떤 규칙도 실리지 않는다. «고칠 때 크기와 상관없이 프레임워크로 옮길 수 있는지 함께 본다»는 이 길에서 발화할 자리가 구조적으로 없다."
    touches: []
    decides: [OQ5, OQ1]
  - id: RC4
    path: "plugins/spec-distill/references/docreview-profiles/design-doc.md"
    anchor: "web: false"
    line: 20
    claim: "설계문서 리뷰 프로필은 웹이 꺼져 있다. `required_sections`(108행)가 나열하는 필수 절 아홉에 「있는 것 검토」가 없고, `layer_rubric` · `must_catch`(15–17행)에도 그 절의 내용을 보는 항목이 없다. 직접 만들기 사유나 «레포 밖: 쓰지 않는다» 한 줄의 진위를 리뷰어가 외부와 대조할 길이 없다. 사유 + 승인을 더해도 사유를 읽는 둘째 눈은 생기지 않는다."
    touches: []
    decides: [OQ6, OQ10]
  - id: RC5
    path: "plugins/spec-distill/dependencies.md"
    anchor: "| superpowers | 7.0.0 | 2026-10-22 | 알림 |"
    line: 17
    claim: "이미 의존으로 적힌 것은 여섯(python · git · gh · superpowers · quality-gates · claude-code)이고 행마다 최소 판 · 강도 · 없을 때 동작이 있다. 이 표가 «이미 승인된 외부 것»의 목록 구실을 할 수 있지만, 지금 규칙 문장은 표에 있는 것과 새로 들이는 것을 가르지 않는다. superpowers 행은 7.0.0 으로 재어져 있는데 이 기계에 설치된 캐시는 7.0.2 다(`~/.claude/plugins/cache/claude-plugins-official/superpowers/7.0.2/` — 레포 밖 관찰). 강도가 «알림»이라 상류가 움직여도 진행된다."
    touches: []
    decides: [OQ9]
  - id: RC6
    path: "plugins/spec-distill/skills/pm-interview/SKILL.md"
    anchor: "**있는 것 먼저.** 무엇을 만들자는 결정이 열리면"
    line: 312
    claim: "설치본에 가는 「있는 것 먼저」의 인터뷰 쪽 정본은 긴 skill 본문 312–315행의 한 문단이고 «조사 열기» 흐름 안에 있다. 끝은 «바깥 것은 사용자 검토 뒤에만 쓴다 — 후보와 차이를 보이고 묻는다»이고 결론의 기본값이나 직접 만들 때의 조건은 없다. 이 문단은 pm-interview 가 불렸을 때만 읽힌다."
    touches: []
    decides: [OQ1, OQ6]
  - id: RC7
    path: "plugins/spec-distill/references/epic-handoff.md"
    anchor: "레포 밖 패키지 · 프레임워크 · 서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다"
    line: 7
    claim: "설계 단계에 닿는 유일한 길인 넘김 줄은 수십 개 지시를 한 문단에 실은 인용문이고 그중 한 구절이 이 규칙이다. 받는 쪽은 devbrew 가 고치지 않는 상류 skill 이다. 같은 문장을 `tests/test_end_gates.sh` 68행이 글자째 고정한다. 이 문장을 뒤집으면 넘김 줄 · `finishing.md` · 락 여럿을 함께 고쳐야 한다. 상류 본문의 «build on what it already uses»와 부딪칠 때의 우선은 어디에도 적혀 있지 않다."
    touches: []
    decides: [OQ1, OQ6]
  - id: RC8
    path: "CLAUDE.md"
    anchor: "Workflow 와 deep-research 는 범위 밖 — 여전히 명시 요청이 필요하다"
    claim: "레포 규칙이 Claude Code 기본 기능 가운데 조율 기능 일부(Workflow)를 이미 «명시 요청이 있어야 쓰는 것»으로 따로 다룬다. «Claude Code 기본 기능은 프레임워크다»와 «에이전트 조율용은 고르지 않았다»가 같은 기능 위에서 겹치는 실례다."
    touches: []
    decides: [OQ4, OQ9]
```

가장 무게 있는 셋은 다음과 같다.

1. **승인은 걸러내지 못할 공산이 크다.** 사유를 쓰는 쪽이 직접 만들고 싶은 쪽이고, 사유를 읽는 둘째 눈이 없다(RC4). 승인 요청의 93% 가 그대로 수락된다는 1차 수치가 있다. OQ6 · OQ7 · OQ10 에 닿는다.
2. **검증 셋은 과거 기각의 원인이 아니었고, 상충하는 확정이 이미 있다.** 과거 기각은 적합 사유였고(RC1), 하루 전 확정은 «의존이 생기는 것은 피한다»다(RC2). 기준을 다듬어도 같은 사유로 같은 결론이 나올 수 있다. OQ8 · OQ9 에 닿는다.
3. **규칙이 살 자리가 구조적으로 좁다.** 플러그인 루트 CLAUDE.md 는 실리지 않고, skill 자동 활성은 불안정하고, 사소한 변경은 skill 밖으로 나가고(RC3), 설계 단계는 반대로 읽힐 문장을 가진 상류 skill 이 주인이다. OQ1 · OQ5 에 닿는다.

확인 수준의 한계는 넷이다.

- 지배구조 연구(Shrives · Brennan), IFScale, 낡은 API 논문은 초록 · 검색 요약만 확인해 `uncertain` 으로 표시했다.
- chalk · debug 사건의 패키지 수는 출처마다 다르다.
- 상류 skill 본문은 GitHub main 과 로컬 7.0.2 캐시 두 곳에서 같은 문장을 읽었다.
- OQ4(조율용 프레임워크)에 직접 닿는 외부 실패 사례는 찾지 못했다. 닿는 것은 범주가 겹친다는 것(공식 문서 + RC8)뿐이다.

읽은 레포 파일:

- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/skills/pm-interview/SKILL.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/epic-handoff.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/trivia-escape.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/docreview-profiles/design-doc.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/dependencies.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-20-dependency-portability-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/interview/2026-11-15-existing-framework-first-interview.md

Sources:

- [Anthropic — Claude Code auto mode](https://www.anthropic.com/engineering/claude-code-auto-mode)
- [Shrives & Brennan — explanations for non-compliance](https://researchportal.northumbria.ac.uk/en/publications/a-typology-for-exploring-the-quality-of-explanations-for-non-comp/)
- [Six Million (Suspected) Fake Stars on GitHub](https://arxiv.org/abs/2412.13459)
- [Endor Labs — chalk/debug npm compromise](https://endorlabs.com/learn/major-supply-chain-attack-compromises-popular-npm-packages-including-chalk-and-debug)
- [anthropics/claude-code issue 10671 — output styles](https://github.com/anthropics/claude-code/issues/10671)
- [We Have a Package for You! (package hallucination)](https://arxiv.org/abs/2406.10279)
- [LLMs Meet Library Evolution (deprecated API)](https://arxiv.org/abs/2406.09834)
- [Building to the Test](https://arxiv.org/abs/2606.28430)
- [Tessl — agents and existing libraries](https://tessl.io/podcast/how-new-libraries-saw-a-50-improvement-maria-gorinova)
- [Claude Code — plugin manifest reference](https://code.claude.com/docs/en/plugins-reference)
- [Claude Code — plugin dependencies](https://code.claude.com/docs/en/plugins/dependencies.md)
- [Scott Spence — skills don't auto-activate](https://scottspence.com/posts/claude-code-skills-dont-auto-activate)
- [IFScale — How Many Instructions Can LLMs Follow at Once?](https://arxiv.org/abs/2507.11538)
- [Breaking changes in npm client packages](https://arxiv.org/abs/2301.04563)
- [A Study of LLMs' Preferences for Libraries and Programming Languages](https://arxiv.org/abs/2503.17181)
- [superpowers brainstorming skill](https://github.com/obra/superpowers/blob/main/skills/brainstorming/SKILL.md)


### 조사 7 — steelman-builder · R1 · 묶음 2

```yaml
case_for_alternative:
  statement: "기본값을 결론 한 곳이 아니라 의존의 거리로 나눈다 — 플랫폼 기본 기능과 이미 의존으로 적힌 것 위에서 만드는 것만 「쓰는 것이 기본」으로 두고, 새 외부 의존(남의 플러그인 · skill · 패키지)은 방향 기본값 없이 쓰기와 만들기 양쪽에 같은 비용표를 요구해 사용자가 고르며, 강제는 결론이 아니라 «후보를 실제로 찾았다는 증거»에 건다(승인은 지금처럼 둔다)."
  strongest: |
    goal 은 「있는 프레임워크」가 아니라 「검증된 프레임워크 위에서」다. 새 외부 의존을 들이는 쪽에 증명 책임을 지우는 것이 큰 프로젝트의 표준이다 — Chromium 은 동기 · 검토한 대안 · 보안 · 유지 책임 · 무게를 적어 두 곳의 승인을 받게 하고, Kubernetes 는 「의존 없이 할 수 있는가 · 이미 비슷한 의존이 있는가」를 묻는다. 공식 · 널리 쓰임 · 유지 중 셋을 다 넘은 xz 가 공식 릴리스에 백도어를 실었고, Anthropic 공식 마켓플레이스조차 「의도대로 동작하는지 · 바뀌지 않는지 확인할 수 없다」고 적는다.
    이 레포의 기록에서 고장 난 곳은 결론이 아니라 탐색이다. 설계 다섯이 바깥 칸을 「새 외부 패키지는 쓰지 않는다」 한 줄로 닫았고 어떤 후보를 찾았는지 적지 않았다. 후보가 비어 있으면 「맞는 프레임워크가 있으면」이라는 조건절이 거짓이 되어 결론 기본값은 발동하지 않는다 — 「쓰는 것이 기본」은 같은 저자가 「맞는 것 없음」 한 줄로 지나간다. 이유를 대게 하는 제도는 내용 기준이 없으면 상투 문구로 굳는다(comply-or-explain 실증).
    배포 구조도 대안 편이다. 플러그인은 어느 레포에나 깔리므로 런타임 의존 하나가 모든 소비 레포의 환경에 생긴다. Claude Code 는 Python 의존을 자동으로 깔아 주지 않고, plugin.json 의존은 못 풀리면 그 플러그인이 로드되지 않으며, 판을 고정하지 않은 의존은 상류가 이름을 바꾸는 순간 모든 사용자에게서 깨진다. 같은 사용자가 C5(특정 외부 도구 의존을 피한다)와 B2(외부 패키지는 테스트에서만 — 사용자 환경에 의존이 생기므로)에서 이 비용을 이미 결정 근거로 썼다. 맞지 않는 추상에 끼워 맞춘 비용은 중복보다 크고(Metz), 작은 필요에는 복사가 의존보다 낫다(Cox). 그래서 goal 의 「직접 만드는 것 최소화」는 플랫폼 기본 기능과 이미 든 의존에서 가장 싸게 이뤄지고, 거기에만 방향 기본값을 두는 편이 유지 부담 · 되풀이 버그 · 시간이라는 계기 셋을 실제로 줄인다.
case_for_current:
  strongest: |
    goal 의 낱말은 「최대한」과 「가능한 최소화」다. 방향 없는 양쪽 비교는 지금 규칙(「검토한다」) 그대로이고, 그 규칙 아래 `## 있는 것 검토` 절이 있는 설계 아홉 가운데 새 외부 것을 들인 것은 하나도 없다. 만드는 쪽에는 구조적 홈 이점이 있다 — 모델에게 새 코드를 쓰는 것은 그 순간 가장 싼 길이고, AI 보조 이후 옮겨 다시 쓴 줄(재사용의 대리 지표)이 2021년 24.8% 에서 2024년 9.5% 로 줄었다는 측정이 있다. 이 기울기를 되돌리는 것은 증명 책임의 방향뿐이고, 기본값은 58개 연구 메타분석에서 d=0.68 로 선택을 옮긴다.
    원안은 지금 흐름의 구멍 하나를 정확히 막는다. 의존 이식성 설계는 공식 Claude Code 기능 둘(plugin.json 의존 · userConfig)을 후보로 보고도 지휘자 판단으로 기각한 뒤 같은 일을 직접 만들었고, 그 기능을 쓸지 사용자에게 물은 기록이 없다. 「직접 만들려면 이유 + 사용자 승인」은 이 조용한 기각을 사용자 앞의 결정으로 바꾼다 — 「새 외부 패키지는 쓰지 않는다」 한 줄이 더는 승인 없이 설 수 없다.
    trigger 의 landscape 모순은 원안을 뒤집지 못한다. Chromium 문서의 첫 문장은 「제3자 코드 사용은 시간을 아끼고 우리 가치와 맞다 — 바퀴를 다시 만들 필요가 없다」이고 그 위에 승인 절차를 얹는다. 재사용이 기본 가치인 것과 들일 때 승인받는 것은 한 문서 안에서 함께 선다 — 원안의 P5 가 바로 그 구조다. 공급망 위험과 환각 패키지는 그대로 둔 외부 승인이 받는다. 체계적 재사용은 산업 연구 다섯에서 낮은 결함 밀도와, 셋에서 수정 노력 감소와 유의하게 묶였고, 오래 쓰인 기술은 고장 방식이 알려져 있으며 운영 비용이 만들 때의 불편을 압도한다. 벤더의 「API 를 직접 쓰는 데서 시작하라」는 에이전트 프레임워크 이야기이고, 사용자는 그 범주를 고르지 않았다.
premise_refutation:
  hits: [P2]
  why: |
    P2 — 「검증된 프레임워크(만든 쪽이 공식으로 내고 · 널리 쓰이고 · 지금도 유지되는 것)는 직접 만든 것보다 믿을 수 있다」는 세 기준을 넘으면 기반으로 믿을 수 있다는 문장인데, 세 기준을 넘는 것을 같은 사용자 · 같은 레포가 기반으로 믿지 않기로 한 기록과 직접 충돌한다.
    (1) docs/superpowers/specs/2026-10-15-roadmap-control-plane-design.md 「실험 기능은 기반으로 쓰지 않는다(D33)」와 docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.md 「기각 — agent 팀을 일꾼 기반으로 → 리드 고정 · 재개 불가로 지휘 세션 리프레시와 충돌하는 실험 기능(S4)」. agent 팀은 Anthropic 이 공식으로 내고 지금도 유지하는 Claude Code 기본 기능이고, 공식 문서(https://code.claude.com/docs/en/agent-teams)가 「experimental and disabled by default … known limitations around session resumption, task coordination, and shutdown behavior」라고 적는다. 세 기준에는 이것을 걸러 낼 축이 없다.
    (2) 같은 brief 의 「기각 — 헤드리스 claude -p 를 일꾼 기본으로 → Skill 도구 거부 · 실패가 rc 0 으로 숨음(S4)」와 docs/superpowers/specs/2026-10-20-dependency-portability-design.md 「기각: Claude Code plugin.json `dependencies`(superpowers 가 없으면 spec-distill 전체가 꺼진다 — U6 과 충돌) · Claude Code `userConfig`(레포 단위로 둘 수 없고 Bash 명령 환경에 없다)」. 넷 다 공식 · 유지 중인데 기각 사유는 믿음의 문제(실패가 숨는다)이거나 맞음의 문제(레포 단위로 못 둔다)였다.
    (3) https://research.swtch.com/xz-timeline — xz 는 세 기준을 모두 넘었고 공식 상류 릴리스 5.6.0 · 5.6.1 에 백도어가 실렸다. https://github.com/anthropics/claude-plugins-official 은 공식 마켓플레이스에 대해 「Anthropic does not control what MCP servers, files, or other software are included in plugins and cannot verify that they will work as intended or that they won't change」라고 적는다.
    충돌의 범위는 「세 기준이면 충분하다」까지다. 재사용이 평균적으로 결함을 줄인다는 근거(Mohagheghi · Conradi)는 그대로 서므로 P2 는 버려지지 않고 기준이 다듬어진다 — 세 기준은 필요조건이고, 인터페이스 안정(실험 딱지) · 실패가 드러나는가 · 일에 맞는가가 빠져 있다.
premise_list_challenge: |
  결함 넷과 공시 둘이다.
  (1) 빠진 전제 — 「프레임워크에 기대서 생기는 비용(사용자 환경에 생기는 의존 · 특정 도구 종속 · 상류 판 변동 · 없을 때의 길)이 직접 만드는 비용보다 작다」. P1 은 장부의 한쪽(직접 만든 것의 비용)만 적는다. trigger 의 C5 와 B2 는 P1~P6 어느 문장과도 직접 충돌하지 않는다 — 둘이 충돌하는 상대는 목록에 없는 이 전제다. 같은 사용자가 2026-10-17(B2) · 2026-11-14(C5)에 이 비용을 이유로 만드는 쪽을 골랐으므로, 이 전제를 세우지 않으면 새 규칙 아래서 그 두 결정이 그대로인지 뒤집히는지 판정할 수 없다.
  (2) P4 는 지렛대 둘을 하나로 적었다 — 결론의 방향(기본값)과 후보 탐색. 레포 기록에서 형식에 그친 것은 바깥 칸의 탐색이고(다섯 설계가 후보 없이 한 줄로 닫음), 결론 기본값은 후보가 있을 때만 발동한다. 「맞는 프레임워크가 있으면」의 판정자가 만드는 쪽 저자 자신인 한 P4 의 「결론이 실제로 달라진다」는 그 조건절에서 새어 나간다. P4 는 반증되지 않았다 — 조용한 기각을 승인 대상으로 바꾸는 효과는 실재한다 — 그러나 탐색 증거 없이 이 전제 하나로는 서지 않는다.
  (3) P3 의 「늘」은 레포 기록과 글자대로는 맞지 않는다. markdown-it-py 는 사용자 승인으로 들어왔고(테스트 한정), 설계 · 계획 단계 자체가 남이 유지하는 플러그인(superpowers) 위에 서 있다. 다만 B2 는 P3 를 약하게 하지 않는다 — 맞는 파서가 있었는데 런타임 판독기는 직접 만들었고, 그 선택지에 「(권장)」을 붙인 쪽은 모델이었다. 승인 게이트가 있어도 추천의 방향이 만드는 쪽이면 결론은 만드는 쪽으로 간다는 실례라서 P4 의 「기본값」 부분을 오히려 받친다. hit 으로 내지 않았다.
  (4) P6 에는 「규칙이 닿는 자리를 devbrew 가 갖고 있다」는 전제가 숨어 있다. 설계와 계획 단계의 실행자는 superpowers(brainstorming · writing-plans)이고 devbrew 가 쥔 자리는 넘김 줄 · 인터뷰 문단 · 설계문서 리뷰 프로필뿐이다. CLAUDE.md 는 이 레포에만 있고, 플러그인이 실어 보낼 수 있는 컴포넌트에 규칙 파일은 없다. 그리고 설계문서를 읽는 유일한 독립 판정자의 과설계 사다리에는 「플랫폼 기본 기능 · 바깥의 유지되는 것으로 되나」 단이 없고 그 판정자는 웹 도구가 없다 — 바깥 칸을 읽어 줄 독자가 지금 없다.
  공시 1 — 닫힌 경로: 「지금 규칙이 지켜지게」(라운드 1)와 「새로 들일 때만 승인」 · 「기준 넘으면 묻지 않음」(라운드 2)은 사용자가 고르지 않아 대안에 넣지 않았다. 대안의 단계 구분은 승인을 푸는 것이 아니라 방향 기본값이 걸리는 범위만 가른다.
  공시 2 — 반복 감지: 이 방향으로 받은 첫 입력이다. 같은 입력의 재호출이 아니다.
recommendation: refined
refined_takes: |
  원안의 뼈대 전부 — 맞는 프레임워크가 있으면 그 위에서 만드는 것이 세 범주(Claude Code 기본 기능 · 남이 유지하는 플러그인과 skill · 널리 쓰이는 패키지와 도구) 모두에서 기본이고, 직접 만들려면 이유와 사용자 승인이 필요하며, 외부 것의 승인은 그대로 두고, 규칙과 장치에 레포 전용 값 · 특정 프레임워크 이름을 박지 않고, 범위는 규칙 문장과 인터뷰 · 설계 · 계획 단계까지다.
  대안에서 가져와 원안에 붙이는 것 넷.
  (a) 만드는 이유의 선행 조건으로 탐색 증거 — 찾아본 후보를 이름으로 들고 후보마다 요구에 비춘 맞음 판정을 적는다. 「없음」은 어디를 찾았는지와 함께만 선다.
  (b) 의존 쪽 장부를 이유의 종류로 인정 — 사용자 환경에 생기는 의존 · 특정 도구 종속 · 라이선스 · 없을 때의 길 없음 · 요구에 안 맞음은 정당한 이유이고, 테스트 한정 · 방식만 차용 같은 부분 채택도 「쓰는 것」의 한 형태로 센다. 그래야 C5 · B2 가 새 규칙과 어긋나지 않는다.
  (c) 검증 기준 셋은 필요조건이고 인터페이스 안정을 더한다 — 실험 딱지 기능은 사용자가 따로 승인하지 않는 한 기반이 아니다(D33 유지).
  (d) 규칙이 사는 자리는 독립 독자가 있는 곳 — 플러그인이 실어 보내는 인터뷰 문단 · 넘김 줄 · 설계문서 리뷰 프로필의 사다리. CLAUDE.md 문장만 고치는 것으로 끝내지 않는다.
refined_drops: |
  셋을 버린다.
  (1) 「공식 · 널리 쓰임 · 유지 중이면 직접 만든 것보다 믿을 수 있다」를 충분조건으로 읽는 것(P2 의 반증된 범위).
  (2) 결론의 기본값을 뒤집는 것만으로 결론이 달라진다는 기대 — 후보가 비면 기본값은 발동하지 않는다.
  (3) 「결론은 늘 직접 만들기였다」를 원인 진단으로 쓰는 것 — 기록이 보이는 고장은 잘못된 결론보다 비어 있는 바깥 칸과 사용자에게 닿지 않은 기각이다.
evidence:
  - url: "https://chromium.googlesource.com/chromium/src/+/main/docs/adding_to_third_party.md"
    supports: both
    claim: "첫 문장이 「Using third party code can save time and is consistent with our values - no need to reinvent the wheel!」이고, 같은 문서가 새 제3자 프로젝트에 Technical Steering Council 과 Chrome Security 의 승인, 동기 · 검토한 대안 · 보안 · 유지 책임(「You will be responsible for owning the dependency」) · 무게 기재를 요구하며 「Third party code is a hot spot for security vulnerabilities」라고 적는다. 재사용이 기본 가치인 것과 들일 때의 승인이 한 절차 안에 함께 선다."
    touches: [P5, P1]
    decides: [OQ7, OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/vendor.md"
    supports: alternative
    claim: "새 의존 검토 목록이 「Is the dependency maintained?」 · 「Does the dependency bring value to the project? Could this be done without adding a new dependency?」 · 「Is there already a dependency in the project that does something similar?」이고 라이선스는 dep-approvers 가 본다. 유지 중인지는 여러 물음 가운데 하나이고, 이미 든 의존을 먼저 보는 단계가 따로 있다."
    touches: [P2]
    decides: [OQ2, OQ8, OQ9]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://www.anthropic.com/engineering/building-effective-agents"
    supports: alternative
    claim: "「We suggest that developers start by using LLM APIs directly」 · 프레임워크는 「extra layers of abstraction that can obscure the underlying prompts and responses」 · 「If you do use a framework, ensure you understand the underlying code」 · 「Incorrect assumptions about what's under the hood are a common source of customer error」. 범위는 에이전트 시스템을 쉽게 만들어 주는 프레임워크이고 일반 패키지 · 플랫폼 기능이 아니다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://research.swtch.com/deps"
    supports: alternative
    claim: "의존 관리자는 내려받고 까는 비용만 없앴고 평가 · 유지 비용은 남는다. 들이기 전에 설계 · 코드 품질 · 테스트 · 디버깅 · 유지 · 사용처 · 보안 · 라이선스 · 그 의존의 의존을 살피라 하고, 위험하고 격리할 수 없으면 「the best answer may be to avoid it entirely」, 작은 필요에는 「A little copying is better than a little dependency」. 결론은 「We do this because it's easy, because it seems to work, because everyone else is doing it too」."
    touches: [P1, P2]
    decides: [OQ2, OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://research.swtch.com/xz-timeline"
    supports: alternative
    claim: "공격자가 2년 넘게 신뢰받는 기여자가 되어 유지 권한을 얻었고, 백도어는 공식 상류 릴리스 xz 5.6.0 · 5.6.1 배포본에 실렸다. 공식 · 널리 쓰임 · 유지 중 세 기준을 모두 넘는 것이 믿을 수 없게 된 실례다."
    touches: [P2]
    decides: [OQ2]
    source_kind: secondary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/agent-teams"
    supports: alternative
    claim: "「Agent teams are experimental and disabled by default … known limitations around session resumption, task coordination, and shutdown behavior」. 한계 목록에 in-process 팀원의 세션 재개 불가 · 작업 상태 지연 · 리드 고정이 있다. 만든 쪽이 공식으로 내고 유지하는 기본 기능이 기반으로 쓰기에는 불안정할 수 있다."
    touches: [P2]
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-plugins-official"
    supports: alternative
    claim: "공식 마켓플레이스의 경고 — 「Make sure you trust a plugin before installing, updating, or using it. Anthropic does not control what MCP servers, files, or other software are included in plugins and cannot verify that they will work as intended or that they won't change」. 공식 목록에 올랐다는 것이 검증을 뜻하지 않는다."
    touches: [P2, P5]
    decides: [OQ2]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://snyk.io/blog/toxicskills-malicious-ai-agent-skills-clawhub/"
    supports: alternative
    claim: "커뮤니티 skill 저장소 약 4천 개를 훑은 감사에서 3분의 1 이상에 결함이 있었고 악성 페이로드가 확인된 skill 이 나왔다. 「남이 만들어 유지하는 플러그인과 skill」 범주는 사용자 승인 없이 기본으로 들일 수 없다. 수치는 요약마다 달라(악성 76건 대 페이로드 1,467건) 원문 확인이 필요하다."
    touches: [P2, P5]
    decides: [OQ2]
    source_kind: secondary
    checked_at: "2026-11-15"
    certainty: uncertain
  - url: "https://labs.cloudsecurityalliance.org/research/csa-research-note-slopsquatting-ai-supply-chain-20260419/"
    supports: alternative
    claim: "USENIX Security 2025 연구(Spracklen 외)에서 코드 생성 표본의 19.7% 가 실재하지 않는 패키지 이름을 하나 이상 담았고, 같은 프롬프트를 열 번 돌리면 환각 이름의 43% 가 매번 되풀이됐다. 모델이 「맞는 패키지가 있다」고 내는 판정은 그 자체로 확인 대상이다. 표본 수는 출처마다 다르다."
    touches: [P5]
    decides: [OQ8]
    source_kind: secondary
    checked_at: "2026-11-15"
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/plugin-dependencies"
    supports: alternative
    claim: "판을 고정하지 않은 플러그인 의존은 「If that release renames an MCP tool your plugin calls, your plugin breaks for everyone who updates」. 다른 마켓플레이스의 의존은 기본으로 깔리지 않고, plugin.json 에 선언된 의존이 못 깔리면 「the install completes without the dependency and your plugin then fails to load」. 플러그인이 남의 플러그인에 기대는 공식 길은 있지만 못 풀릴 때 기대는 쪽 전체가 꺼진다."
    touches: [P1, P6]
    decides: [OQ1, OQ9]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/loading.md"
    supports: alternative
    claim: "Claude Code 는 플러그인의 Node.js 패키지 의존만 자동으로 깐다(package.json + 지원 lockfile). Python 의존은 자동 설치가 없어 훅으로 영속 데이터 폴더에 직접 깔아야 한다(「install it from a hook into the persistent data directory. That includes … Python dependencies」). 플러그인은 캐시로 복사되고 플러그인 폴더 밖 파일은 복사되지 않는다. Python 기반 플러그인이 런타임에 일반 패키지에 기대면 그 설치가 모든 소비 레포 사용자 환경의 일이 된다."
    touches: [P6, P1]
    decides: [OQ1]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://www.cambridge.org/core/product/1E6135ADFCBBC9AC9170DAEB3BBDA9DA"
    supports: current
    claim: "기본값 효과 메타분석(Jachimowicz 외 2019, 연구 58 · 참가자 73,675) — 합친 효과 d=0.68(95% CI 0.53–0.83). 미리 골라 둔 선택지가 선택을 옮긴다. 다만 연구 사이 편차가 크고 효과가 없거나 반대인 연구도 있으며, 기본값이 «추천»으로 읽힐 때 더 잘 듣는다."
    touches: [P4]
    decides: [OQ7]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://assets.kpmg.com/content/dam/kpmgsites/uk/pdf/2021/03/improving-the-quality-of-comply-or-explain-reporting.pdf"
    supports: alternative
    claim: "영국 FRC 의 comply-or-explain 보고 품질 검토 — 「'tick-box compliance' continues to be preferred over high quality reporting」 · 「such a formulaic approach leads to boilerplate language and ineffective reporting」. 따르지 않을 때 이유를 대게 하는 제도는 이유의 내용 기준이 없으면 상투 문구로 굳는다. 본문은 읽지 못했고 문서 설명 칸에서 확인했다."
    touches: [P4]
    decides: [OQ6, OQ10]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain
  - url: "https://link.springer.com/doi/10.1007/s10664-007-9040-x"
    supports: current
    claim: "산업 연구 검토(Mohagheghi · Conradi 2007) — 체계적 재사용이 연구 다섯에서 낮은 결함 밀도와, 셋에서 수정 노력 감소와, 셋에서 생산성 이득과 유의하게 묶였다. 합치는 방식은 표 세기이고 산업 근거는 드물다고 저자가 적는다."
    touches: [P1]
    decides: []
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://mcfunley.com/choose-boring-technology"
    supports: both
    claim: "오래 쓰인 기술은 「their failure modes are well understood」이고 「the long-term costs of keeping a system working reliably vastly exceed any inconveniences you encounter while building it」 — 검증된 것 위에서 만드는 쪽의 근거. 같은 글이 「adding tech is a decision that requires company-wide visibility」라고 적어 새로 들이는 것에는 가시적 결정을 요구한다."
    touches: [P1, P2, P5]
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://sandimetz.com/blog/2016/1/20/the-wrong-abstraction"
    supports: alternative
    claim: "「duplication is far cheaper than the wrong abstraction」 · 「prefer duplication over the wrong abstraction」. 이미 들인 것에는 유지하려는 압력이 생겨 맞지 않는 추상을 매개변수와 조건문으로 계속 구부린다. 「맞는가」를 재지 않고 프레임워크에 올리면 유지 부담이 줄지 않고 옮겨 간다."
    touches: [P1]
    decides: [OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://www.devclass.com/ai-ml/2025/02/20/ai-is-eroding-code-quality-states-new-in-depth-report/1626250"
    supports: current
    claim: "GitClear 2025 보고서(2020–2024 바뀐 줄 2억 1,100만) — 옮긴 줄(리팩터 · 재사용의 대리 지표)의 비중이 2021년 24.8% 에서 2024년 9.5% 로 줄고 2024년에 복사 · 붙여 넣은 줄이 옮긴 줄을 처음 넘었다. AI 보조가 새 코드 삽입을 가장 쉬운 길로 만든다는 풀이. 있는 것을 쓰지 않고 새로 쓰는 쪽으로 기우는 것이 도구 차원의 경향이라는 근거다. 보고서 원문은 접근이 막혀 2차 보도로 확인했다."
    touches: [P3]
    decides: [OQ6]
    source_kind: secondary
    checked_at: "2026-11-15"
    certainty: uncertain
repo_claims:
  - id: RC1
    path: "CLAUDE.md"
    anchor: "**있는 것 먼저.** 만들기 전에 레포 안 · 밖의 있는 것을 검토하고 외부 것은 사용자 검토 뒤 쓴다(철학 P8)."
    line: 34
    claim: "지금 규칙 문장은 「검토한다」까지이고 결론의 방향도, 무엇을 찾아봤는지 남기라는 요구도 없다. 이 파일은 이 레포에만 있어 플러그인을 깐 다른 레포에는 닿지 않는다. 철학 문서 P8 재사용 조항(docs/philosophy/devbrew-harness-philosophy.md 85행)도 같은 문장이다."
    touches: [P6]
    decides: [OQ1, OQ6]
  - id: RC2
    path: "plugins/spec-distill/skills/pm-interview/SKILL.md"
    anchor: "**있는 것 먼저.** 무엇을 만들자는 결정이 열리면"
    line: 312
    claim: "플러그인이 실어 보내는 인터뷰 문단이 이미 「바깥의 성숙한 것(패키지 · 프레임워크 · 도구)을 웹으로 찾는다 … 후보와 차이를 보이고 묻는다」를 요구한다. 다른 레포에 실제로 닿는 규칙 자리는 여기이고, 이 문단도 방향 기본값과 「없음」의 근거 요구가 없다."
    touches: [P6, P4]
    decides: [OQ1, OQ6]
  - id: RC3
    path: "plugins/spec-distill/references/epic-handoff.md"
    anchor: "설계문서에 ## 있는 것 검토 절(레포 안에 이미 있는 것을 먼저 찾아 쓰고, 레포 밖 패키지 · 프레임워크 · 서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다)"
    line: 7
    claim: "설계 단계의 실행자는 superpowers:brainstorming, 계획 단계는 superpowers:writing-plans 이고 devbrew 가 설계 · 계획에 규칙을 넣는 자리는 이 넘김 줄 한 문장이다. 그 문장은 레포 안은 「먼저 찾아 쓰고」, 레포 밖은 「후보로만 적어」로 비대칭이다 — 바깥 것에는 쓰라는 방향이 아니라 붙잡아 두는 방향이 적혀 있다. 락(plugins/spec-distill/tests/test_epic_handoff.sh 64행)은 이 문구의 존재만 잰다."
    touches: [P6, P4]
    decides: [OQ1, OQ6]
  - id: RC4
    path: "plugins/spec-distill/references/docreview-profiles/design-doc.md"
    anchor: "### 판정 절차 — 사다리"
    line: 69
    claim: "설계문서를 읽는 독립 판정자의 과설계 사다리는 「1. 이 구조가 있어야 하나 2. 이미 리포에 있는 원칙·메커니즘으로 되나 3. 이미 있는 하니스 표면으로 되나 4. 한 줄 규약으로 되나 5. 그제서야 새 메커니즘」이다. 플랫폼 기본 기능이나 바깥의 유지되는 것으로 되는지를 묻는 단이 없고, 층 1 · 층 2 범주 어디에도 「있는 것 검토」 절을 읽는 항목이 없다. 이 판정자는 웹 도구가 없다(plugins/spec-distill/CHANGELOG.md 「새 `doc-critic`·`doc-recritic` 은 `tools: Read, Grep, Glob` 뿐이고 `design-doc.md` 프로필은 `web: false` 를 고정한다」). 바깥 칸은 쓰는 사람만 있고 읽는 사람이 없다."
    touches: [P4]
    decides: [OQ1, OQ6, OQ10]
  - id: RC5
    path: "docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md"
    anchor: "B2 · 결정 · 2026-10-17 · 실제 파서 — 「테스트에서만 씁니다 (권장)」"
    line: 318
    claim: "맞는 파서(markdown-it-py)가 있었고 사용자 승인도 거쳤지만 결론은 「런타임 판독기는 표준 라이브러리만 쓴다」(165행)였다. 기각 사유는 「markdown-it-py 를 실행 때도 — 사용자 환경에 의존이 생긴다(B2)」(311행)이고, 「(권장)」은 만드는 쪽 선택지에 붙어 있었다. 승인 게이트가 있어도 추천의 방향이 결론을 정한 실례이고, 「사용자 환경에 생기는 의존」이 사용자가 받아들인 이유의 종류라는 기록이다. 같은 절에 bashlex 를 GPLv3 라이선스로 기각한 것도 있다(216행)."
    touches: [P3, P4, P1]
    decides: [OQ7, OQ8]
  - id: RC6
    path: "docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.md"
    anchor: "기각 — herdr 같은 외부 실행기를 기본으로 → 특정 도구 의존(C5)"
    line: 484
    claim: "하루 전 같은 사용자의 확정 제약 C5(34행 「특정 외부 도구에 하드코딩되거나 의존이 생기는 것은 피한다」)가 외부 도구를 「특정 도구 의존」 한마디로 기각하는 근거로 쓰였다. 같은 목록이 공식 Claude Code 기능 둘도 기각한다 — 「agent 팀을 일꾼 기반으로 → … 실험 기능(S4)」(482행) · 「헤드리스 claude -p 를 일꾼 기본으로 → Skill 도구 거부 · 실패가 rc 0 으로 숨음(S4)」(483행). 반대로 superpowers SDD 는 「[취함] — 자체 검수 상한을 여기에 맡긴다」(475행)로 들였다. 새 규칙이 「의존이 생긴다」를 이유로 인정하는지 정하지 않으면 C5 와 맞부딪친다."
    touches: [P2]
    decides: [OQ3, OQ4, OQ8]
  - id: RC7
    path: "docs/superpowers/specs/2026-10-15-roadmap-control-plane-design.md"
    anchor: "실험 기능은 기반으로 쓰지 않는다(D33) — 기반은 작업 목록 · 상태줄 설정 · 진입 skill."
    line: 64
    claim: "실험 딱지 기능을 기반에서 빼는 것은 확정 제약으로 이미 있다. 공식 제공 · 유지 중을 넘는 기능이라도 기반으로 믿지 않기로 한 결정이므로, 검증 기준 셋만으로는 이 결정을 다시 낼 수 없다."
    touches: [P2]
    decides: [OQ3, OQ2]
  - id: RC8
    path: "docs/superpowers/specs/2026-10-20-dependency-portability-design.md"
    anchor: "기각: Claude Code plugin.json `dependencies`(superpowers 가 없으면 spec-distill 전체가 꺼진다 — U6 과 충돌) · Claude Code `userConfig`(레포 단위로 둘 수 없고 Bash 명령 환경에 없다"
    line: 247
    claim: "공식 Claude Code 기능 둘을 후보로 보고 구체적인 맞음 사유로 기각한 뒤 같은 일을 직접 만들었다. 바깥 칸은 「Renovate 의 기본 브랜치 설정 읽기(방식만 차용). 새 외부 패키지는 쓰지 않는다」(246행)다. 기각 사유는 믿음이 아니라 맞음의 문제였다 — 「맞는가」의 판정 기준이 없으면 같은 기각이 새 규칙 아래서도 저자 판단으로 되풀이된다."
    touches: [P2, P3]
    decides: [OQ6, OQ8]
  - id: RC9
    path: "docs/superpowers/specs/2026-10-23-r8-device-leftovers-design.md"
    anchor: "레포 밖: gh `pr view <번호> --json` · `pr create` 의 URL 출력. 새 외부 패키지는 쓰지 않는다."
    line: 339
    claim: "바깥 칸이 찾아본 후보 없이 한 줄로 닫힌다. 같은 꼴이 docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md 238행 「새 외부 패키지는 쓰지 않는다」 · 2026-10-23-rules-docs-cleanup-design.md 394행 「레포 밖: 쓰지 않는다.」 · 2026-10-21-interview-gate-leftovers-design.md 225행 「레포 밖: 쓰지 않는다」 · 2026-10-25-epic-parallel-recommend-design.md 190행에 되풀이된다. 같은 문서들의 레포 안 칸은 스크립트 · 함수를 이름으로 열거한다(r8 328–338행). 형식에 그친 것은 검토 전체가 아니라 바깥 칸의 탐색이다."
    touches: [P3, P4]
    decides: [OQ6, OQ10]
  - id: RC10
    path: "plugins/spec-distill/dependencies.md"
    anchor: "| superpowers | 7.0.0 | 2026-10-22 | 알림 |"
    line: 17
    claim: "spec-distill 은 이미 남이 유지하는 플러그인(superpowers) · 자매 플러그인(quality-gates) · python · git · gh · claude-code 를 의존 표에 적고 그 위에서 돈다. 「이미 의존으로 적힌 것」이라는 범주가 파일로 실재하고(이름 · 최소 판 · 강도 · 없을 때), 새로 들이는 것과 가를 기준선으로 쓸 수 있다. 「결론은 늘 직접 만들기」는 설계 · 계획 단계 자체에는 맞지 않는다."
    touches: [P3]
    decides: [OQ9]
  - id: RC11
    path: "CLAUDE.md"
    anchor: "**Trivia ceremony** — 한 문장 diff에 full pipeline 실행"
    claim: "한 문장으로 설명되는 trivia diff 는 게이트를 우회하고(Law 1 Trivia escape), trivia 에 전체 절차를 돌리는 것은 금지 패턴으로 이름 붙어 있다. 「고칠 때 크기와 상관없이 함께 본다」를 오타 수정에까지 걸면 이 조항과 부딪친다."
    touches: []
    decides: [OQ5]
```

읽은 파일(절대 경로):
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/CLAUDE.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/philosophy/devbrew-harness-philosophy.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/skills/pm-interview/SKILL.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/epic-handoff.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/docreview-profiles/design-doc.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/dependencies.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/interview/2026-11-15-existing-framework-first-interview.audit.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-15-roadmap-control-plane-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-20-dependency-portability-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-19-interview-open-research-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-23-r8-device-leftovers-design.md

확인 수준 공시:
- RC9 의 되풀이 다섯 가운데 r8 · review-engine-leftovers 는 절 전체를 읽었고, rules-docs-cleanup · interview-gate-leftovers · epic-parallel-recommend 는 해당 줄만 grep 으로 확인했다.
- RC4 의 「층 1 · 층 2 범주에 있는 것 검토를 읽는 항목이 없다」는 프로필 23–114행을 읽고 확인했다. 판정자의 도구 제한은 CHANGELOG 문장으로 확인했고 agent 파일의 frontmatter 는 직접 읽지 않았다.
- 웹 근거 가운데 Snyk · 환각 패키지 연구 · GitClear 는 2차 요약으로만 확인했고(GitClear 원문은 403), FRC 보고서는 PDF 본문이 읽히지 않아 문서 설명 칸의 문장만 확인했다 — 넷 다 `certainty: uncertain` 으로 표시했다.
- Kubernetes vendor.md 는 「새 의존에 별도의 이유 서식을 요구한다」고 적지 않는다 — 검토 물음 목록과 라이선스 검토자만 있다. trigger 의 「Kubernetes 는 이유와 승인을 요구한다」는 그만큼 약하게 읽어야 한다.


## R2

### 지금 이해

(반론 검토 ST1 — steelman 절차의 질문) 「쓰는 것이 기본」 방향이 의심 trigger 둘에 걸려 양쪽 주장을 세웠다. 숨은 가정 조사(조사 6)도 돌아왔고 그 처분은 다음 라운드에 묻는다.

ST1 dispatch 입력 — goal: S1 의 첫 줄(사용자 요청 원문 「구현보다 최대한 있는 프레임워크 사용, 직접 만드는거는 가능한 최소화하고 검증된 프레임워크 위에서 작업」) · 전제 P1~P6(아래) · 제약: S1 전문(dispatch 시점의 user_statements 전량 — S2~S5 는 dispatch 뒤에 왔다).
- P1: 직접 만든 스크립트와 테스트는 유지 부담을 낳고, 직접 만든 장치에서 버그가 되풀이되며, 새 장치를 만드는 데 시간이 든다 — 있는 프레임워크 위에서 만들면 이 셋이 줄어든다 (근거 S1 · 줄어든다는 부분은 orchestrator 도출)
- P2: 검증된 프레임워크(만든 쪽이 공식으로 내고 · 널리 쓰이고 · 지금도 유지되는 것)는 직접 만든 것보다 믿을 수 있다 (근거 S1 · orchestrator 도출)
- P3: 맞는 프레임워크가 실제로 있는 경우가 있었는데도, 있는 것을 검토했다고 적기만 하고 결론은 늘 직접 만들기였다 (근거 S1)
- P4: 기본값을 「쓰는 것」으로 두고 직접 만들 때 이유와 사용자 승인을 요구하면 결론이 실제로 달라진다 (근거 S1 · 달라진다는 부분은 orchestrator 도출)
- P5: 외부 것을 쓸 때의 사용자 승인을 그대로 두어도 「쓰는 것이 기본」과 함께 설 수 있다 (근거 S1)
- P6: 이 방식은 devbrew 전용 값이나 특정 프레임워크 이름에 묶이지 않고 devbrew 플러그인을 쓰는 어느 레포에서든 통한다 (근거 S1)
trigger: (1) 기존 사용자 제약과의 충돌 — 2026-11-14 확정 C5 · 2026-10-17 결정 B2 (2) landscape 모순 — 들이는 쪽에 부담을 두는 선례 · 공급망 위험 · 에이전트 프레임워크 벤더 글.
builder 출력 verbatim: 위 `### 조사 7 — steelman-builder` 블록.

게이트-전 확인(ST1):
- 확인 RC41 — 확인 — docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.md#특정 외부 도구에 하드코딩되거나 의존이 생기는 것은 피한다. (사용자 확인) — 주장과 일치(같은 줄에 「팀 구조는 superpowers 하나에 묶이지 않고」도 사용자 확인으로 있다) [조사 6]
- 확인 RC42 — 확인 — plugins/spec-distill/references/trivia-escape.md#**그대로** — 다음 안내를 내고 진행하지 않는다 — 주장과 일치(사소한 변경으로 판정되면 skill 이 안내만 내고 끝난다) [조사 6]
- 확인 RC43 — 확인 — plugins/spec-distill/dependencies.md#| superpowers | 7.0.0 | 2026-10-22 | 알림 | — 주장과 일치(이미 의존으로 적힌 것은 여섯. 설치 캐시에는 7.0.0 과 7.0.2 가 함께 있다 — 레포 밖 관찰) [조사 6 · 조사 7]
- 확인 RC44 — 확인 — CLAUDE.md#Workflow 와 deep-research 는 범위 밖 — 주장과 일치(Claude Code 기본 기능 가운데 조율 기능 일부를 이미 「명시 요청이 있어야 쓰는 것」으로 다룬다) [조사 6]
- 확인 RC45 — 확인 — plugins/spec-distill/references/docreview-profiles/design-doc.md#### 판정 절차 — 사다리 — 주장과 일치(다섯 단에 플랫폼 기본 기능 · 바깥의 유지되는 것으로 되는지를 묻는 단이 없고, doc-critic · doc-recritic 의 tools 는 Read, Grep, Glob 이다) [조사 7]
- 확인 RC46 — 확인 — docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.md#기각 — herdr 같은 외부 실행기를 기본으로 → 특정 도구 의존(C5) — 주장과 일치(같은 목록이 agent 팀 · 헤드리스 claude -p 도 기각하고 superpowers SDD 는 취했다) [조사 7]
- 확인 RC47 — 확인 — docs/superpowers/specs/2026-10-23-r8-device-leftovers-design.md#- 레포 밖: gh `pr view <번호> --json` — 주장과 일치(바깥 칸이 찾아본 후보 없이 한 줄로 닫히고 같은 꼴이 다른 설계 넷에 있다) [조사 7]
- 확인 RC48 — 확인 — CLAUDE.md#**Trivia ceremony** — 주장과 일치(한 문장 diff 에 전체 절차를 돌리는 것은 금지 패턴이다) [조사 7]
- 확인 RC49 — 확인 — docs/superpowers/specs/2026-10-15-roadmap-control-plane-design.md#실험 기능은 기반으로 쓰지 않는다(D33) — 주장과 일치 [조사 7]
- 조사 7 의 나머지 레포 주장은 앞 번호와 같은 자리다: 임시 RC1 → RC2 · RC2 → RC6 · RC3 → RC8 · RC5 → RC17 · RC8 → RC19 — 모두 확인. 조사 6 의 임시 RC1 → RC19 · RC4 → RC10 · RC6 → RC6 · RC7 → RC8 — 모두 확인.
- 부착 주장 대조: 근거 17 중 부착 16(비부착 1 — Anthropic 의 에이전트 프레임워크 글), 부착 16 모두 지목된 전제에 닿는다 — 확인. 리포 주장 11 중 확인 11.
- 전제 충돌(hits P2) 확인 4건: agent teams 공식 문서(본체가 직접 읽음) · RC46 과 RC49 · RC19(공식 기능을 기반으로 믿지 않거나 적합 이유로 기각한 기록) · 공식 플러그인 저장소 경고문(본체가 원문을 받아 확인). xz 사례는 본체가 다시 읽지 않았다.
- 미확인: 조사 6 이 든 상류 설계 skill 의 문장 «When there's existing work, build on what it already uses» 는 설치된 7.0.2 본문에서 grep 으로 찾지 못했다(「go look」 · 「seen elsewhere」 줄은 찾았다).

웹 근거(본체가 직접 다시 읽은 것):
- «anthropic-auto-mode» 사용자는 승인 요청의 93% 를 그대로 받아들이고, 시간이 지나면 무엇을 승인하는지 덜 보게 된다 — https://www.anthropic.com/engineering/claude-code-auto-mode (1차 · 확인 2026-11-15) [→ OQ7]
- «cc-plugin-deps» 판을 고정하지 않은 플러그인 의존은 상류가 바뀌면 모든 사용자에게서 깨지고, 다른 마켓플레이스의 의존은 기본으로 깔리지 않으며 plugin.json 에 선언했으면 플러그인이 실리지 않는다 — https://code.claude.com/docs/en/plugins/dependencies.md (1차 · 확인 2026-11-15) [→ OQ9]
- «cc-plugins-official» 공식 플러그인 저장소는 플러그인에 무엇이 들었는지 통제하지 않고 의도대로 동작하는지 확인할 수 없다고 적는다 — https://github.com/anthropics/claude-plugins-official (1차 · 확인 2026-11-15) [→ OQ8]

조사 호출 7/60 · 이 라운드 본체 직접 3
밀린 질문 9개 — 숨은 가정 · 실패 양식의 처분 · 외부 근거의 처분 · builder 보완안의 (c)(검증 기준은 필요조건 · 실험 기능은 따로 승인 없으면 기반 아님)가 S4 · S5 와 어긋나는 것 · OQ4 · OQ5(S3 의 실패 조건 되묻기 포함) · OQ7 · OQ8 · OQ9 · OQ10.

### 다음 결정

ST1: 「쓰는 것이 기본」 방향을 유지 · 보완 · 전환 · 보류 중 무엇으로 할지 · 추천: builder 보완 / orchestrator 보완 — 원안의 뼈대는 근거로 흔들리지 않았고(P4 는 반증되지 않음), P2 는 「세 기준이면 충분하다」까지만 충돌한다. 대안이 짚은 빈 바깥 칸과 의존 쪽 비용은 원안에 붙일 수 있다 · 트레이드오프: 유지(단순, 빈 바깥 칸이 그대로) / 보완(조건이 늘어남) / 전환(새 외부 의존에는 방향 기본값 없음 — 지금 규칙과 거의 같아짐) / 보류(열린 채 설계로)

### 질문

(steelman 게이트 — 선택지 고정 순서) 유지 / 보완 (builder·orchestrator 추천) / 전환 / 보류

### 답

→ S6 (ST1 — 보완)

원장: skepticism 닫음(S6) · landscape 닫음(S4 · S5 · S6) · fit_judgment 닫음(S4 · S6) · conclusion_judge 닫음(S2 · S6) · adoption_cost_asymmetry 닫음(S2 · S6).
ST1 기록(종료 때 payload §5 · audit §3 으로): 기각 — 세 기준이면 충분하다고 읽는 것 · 기본값만 뒤집으면 결론이 달라진다는 기대 · 「결론은 늘 직접 만들기」를 원인 진단으로 쓰는 것 → builder 의 refined_drops — verdict: refined — ST1 — 부착 16/17. 붙임 (a) 탐색 증거 (b) 의존 쪽 비용을 이유로 인정 · 부분 채택도 쓰는 것 (d) 읽는 눈이 있는 자리. 붙임 (c)는 S4 · S5 와 어긋나 R3 에서 따로 묻는다.

## R3

### 지금 이해

(경로 a) 숨은 가정 조사(조사 6)가 낸 실패 양식 가운데 본체가 1차 자료로 확인한 것은 둘이다 — 승인 요청의 93% 가 그대로 수락된다(Anthropic 글), 판을 고정하지 않은 플러그인 의존은 상류가 바뀌면 모든 사용자에게서 깨진다(공식 문서). 사소한 변경은 진입에서 skill 밖으로 나가므로(RC42) 「크기와 상관없이 함께 본다」가 닿을 자리가 그 길에는 없고, 한 문장 diff 에 전체 절차를 돌리는 것은 레포의 금지 패턴이다(RC48). 에이전트 조율 기능은 Claude Code 기본 기능 안에도 있어(subagent · workflow · agent teams) 「기본 기능은 프레임워크」와 「조율용은 고르지 않았다」가 같은 기능에서 겹친다(RC44).

- 위험 — 실패 양식: 승인이 도장이 된다 — 직접 만들 이유를 만들고 싶은 쪽이 쓰고, 그 이유를 읽는 둘째 눈이 없으며, 승인 질문이 양쪽으로 늘어난다 — «anthropic-auto-mode» · RC45
- 위험 — 실패 양식: 지어낸 · 낡은 후보가 승인 자리에 올라간다 — 후보와 검증 셋을 그 자리에서 실측하지 않고 기억으로 채울 때 — 조사 6(환각 패키지 연구 · 본체 확인 못 함)
- 위험 — 실패 양식: 설계는 채택, 구현은 재구현 — 범위가 계획에서 끝나 구현 · 최종 리뷰에 「고른 것을 실제로 썼는가」를 보는 항목이 없다 — 조사 6(«building-to-the-test» · 본체 확인 못 함)
- 위험 — 실패 양식: 과하게 들이거나 설치한 사람에게 고장이 넘어간다 — 채택 수가 지표가 되거나, 판 제약 없이 남의 플러그인에 기댈 때 — «cc-plugin-deps»
- 위험 — 숨은 가정: 규칙 문장을 두면 어떤 크기의 일에서든 읽힌다 — 사소한 변경 · 가벼운 꼴 · skill 을 부르지 않은 세션에는 닿지 않는다 — RC42 · RC33
- 위험 — 숨은 가정: 넘김 글 한 줄을 고치면 설계 · 계획 단계가 바뀐다 — 그 단계의 주인은 고칠 수 없는 상류 skill 이다 — RC14 · 조사 6(상류 본문의 문장은 미확인)
- 위험 — 숨은 가정: 공식 기능은 안정적이다 — 정식 기능도 철회가 예고된 적이 있다고 조사가 전한다 — 조사 6(본체 확인 못 함)

조사 호출 7/60 · 이 라운드 본체 직접 0
밀린 질문 1개 — 설계로 넘길 열린 질문 목록의 확인(OQ7 · OQ8 · OQ9 · OQ10).

### 다음 결정

ST1-c: 보완안의 (c)(검증 기준 셋은 필요조건 · 실험 딱지 기능은 따로 승인 없으면 기반이 아니다)를 받을지 · 추천: 방금 답대로 — S4 · S5 가 더 늦은 사용자 발화이고, (c)가 더하려는 「안정 단계」는 후보마다 보이는 정보 한 칸으로 들어갈 수 있다 · 트레이드오프: 방금 답대로(문턱 없음, 판단은 승인 때) / 조사 안대로(문턱이 생기고 지난 로드맵 결정이 상시 규칙이 된다)
blind_spot 처분: 설계가 반드시 다뤄야 할 위험 · 추천: 승인이 도장이 됨 · 틀린 후보 · 구현에서 다시 만듦 — 셋은 이번 방향의 효과를 직접 무너뜨린다 · 트레이드오프: 고르지 않은 것은 위험 목록에 남되 설계의 필수 항목은 아니다
OQ5: 「고칠 때 크기와 상관없이 함께 본다」가 닿는 범위(S3 의 실패 조건 되묻기) · 추천: 설계를 거치는 고침만 — S3(단계 안에서만)과 맞고 사소한 변경에 전체 절차를 돌리지 않는 레포 규칙과 맞는다 · 트레이드오프: 설계를 거치는 고침만(작은 고침으로 새는 길은 남는다) / 가벼운 꼴까지(devbrew 규칙 문서로는 닿지만 다른 레포에는 자리가 없다) / 사소한 변경도(흐름 밖 자리가 새로 필요해 S3 을 다시 연다)
OQ4: 에이전트 조율용 프레임워크 · 추천: 따로 가르지 않는다 — Claude Code 기본 기능과 범주가 겹치고 승인이 어차피 유지된다 · 트레이드오프: 따로 가르지 않는다 / 대상에서 뺀다(겹치는 기본 기능의 처리가 다시 열린다)

### 질문

(경로 b — 판단) AskUserQuestion 한 번에 넷: 보완안 (c) · 위험 처분(여럿 고르기) · 고칠 때의 범위 · 에이전트 조율용 프레임워크.

### 답

→ S7 (ST1-c — 방금 답대로)
→ S8 (blind_spot 처분 — 승인이 도장이 됨 · 틀린 후보 · 구현에서 다시 만듦)
→ S9 (OQ5 — 설계를 거치는 고침만)
→ S10 (OQ4 — 따로 가르지 않는다)

원장: blind_spot 닫음(S8) · touch_trigger 닫음(S9). OQ4 · OQ5 해결.
seed 뒤집음(P23): 원래 — seed 의 「그것을 고치는 일이 열리면 크기와 상관없이 프레임워크로 옮길 수 있는지도 함께 본다」(사용자 확인) / 재결정 — 인터뷰 · 설계를 타는 고침에서만 크기와 상관없이 함께 보고, 사소한 변경은 지금처럼 그냥 고친다(S9) / 근거 — 사소한 변경은 진입에서 skill 밖으로 나가 규칙이 닿을 자리가 없고(RC42), 한 문장 diff 에 전체 절차를 돌리는 것은 레포의 금지 패턴이며(RC48), 규칙은 단계 안에서만 두기로 했다(S3).
되묻기: S3 의 실패 조건을 OQ5 로 되물었고 답은 S9 다. S7 · S9 · S10 도 이유 없는 추천 수락이다 — 다음 질문의 선택지에 더 팔 길을 둔다.

## R4

### 지금 이해

floor 넷과 파생 차원 여섯이 닫혔고 남은 것은 열린 질문 목록의 확인이다. 지금 열려 있는 결정은 넷이고 모두 「어떻게 지켜지게 하는가」 쪽이라 설계가 정할 수 있다 — OQ7(두 승인이 있을 때 「기본」이 바꾸는 것) · OQ8(「맞는」을 누가 무엇으로 판정하는가) · OQ9(Claude Code 기본 기능과 이미 의존으로 적힌 것도 쓸 때마다 승인받는가) · OQ10(형식이 아니게 됐는지를 무엇으로 아는가).

조사 호출 7/60 · 이 라운드 본체 직접 0

### 다음 결정

열린 질문 목록: OQ7 · OQ8 · OQ9 · OQ10 을 설계로 넘길지 · 추천: 넷 다 설계로 — 넷은 방식의 문제이고 조사 재료(승인 피로 수치 · 한쪽 승인 선례 · 묶음 승인 선례 · 지금 기준선)가 brief 에 실려 간다 · 트레이드오프: 넷 다 설계로(인터뷰는 여기서 닫힘) / 일부는 지금 정한다(라운드가 늘어난다) / 빠진 질문이 있다(목록을 고친다)

### 질문

(경로 b — 판단) 열린 질문 넷을 설계로 넘길지.

### 답

→ S11 (열린 질문 목록 — 넷 다 설계로)

원장: open_questions 닫음(S11). floor 다섯이 모두 닫혀 포화 판정 1 을 불렀다.
공시: 판정자에게 조사 원문 일곱을 글에 붙이지 않고 워크트리 안 파일(.claude/docreview-inputs/research-outputs.md — 조사 원문만 이어 붙인 것) 경로로 넘겼다.
[spec-distill] 포화 판정 1/5: 아직 — 빈 곳 5개, 다음: 보완안의 탐색 증거 · 이유 인정을 과거 설계 두세 건에 소급 적용해 그때 실제로 맞는 외부 후보가 있었는지 본다 · 조사 호출 7/60
판정자가 연 결정: OQ11(구현 · 최종 리뷰에서 고른 것을 실제로 썼는가를 보는 자리를 범위에 넣는가 — 열림) · OQ12(직접 만들 정당한 이유의 종류 — S6 의 보완 b 로 이미 해결).
반복 감지: 첫 판정이라 앞 빈 곳이 없다 — 반복 아님. 빈 곳 다섯을 묶음 3 으로 조사한다(레포 조사 둘 · 웹 조사 셋 — 서로 기대지 않는 질문).



### 조사 9 — repo-researcher · R5 · 묶음 3

레포 루트(절대): /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first — 아래 `path` 는 모두 이 루트 기준 상대경로다. 구현(프로필 · skill 펜스 · 러너 · agent · 테스트)을 직접 읽고 썼다. `id` 는 임시값이다.

```yaml
repo_claims:
  # ── A. 경위 · 이유 (원문) ─────────────────────────────────────────────
  - id: RC1
    path: "plugins/spec-distill/CHANGELOG.md"
    anchor: "## [1.0.0] — 2026-09-09 › ### Changed › 「능력 축소 — design doc 리뷰의 외부 prior-art 대조가 Claude·codex 양쪽에서 동시에 0 이 됐다.」"
    line: 1500
    claim: "항목 전문: 「**능력 축소 — design doc 리뷰의 외부 prior-art 대조가 Claude·codex 양쪽에서 동시에 0 이 됐다.** 옛 `spec-reviewer` 는 `tools:` 에 `WebSearch, WebFetch` 를 가졌고 `run_spec_codex_reviewer.sh` 는 codex 웹 검색을 기본 ON 으로 켰다. 새 `doc-critic`·`doc-recritic` 은 `tools: Read, Grep, Glob` 뿐이고 `design-doc.md` 프로필은 `web: false` 를 고정한다 — 이 결정은 설계 §5.3·OQ-C 의 의도이고 이 릴리스는 그것을 뒤집지 않는다. `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 은 이제 소비자 **둘**(interview 웹 리서치 · codex brief co-reviewer)만 끄고, design-doc 리뷰는 이 스위치의 대상이 아니다 — 프로필이 이미 꺼 놨으므로 켜고 끌 것이 없다.」 즉 1.0.0(문서 리뷰 엔진 전환)에서 생긴 축소이고, 이 항목 자신은 이유를 대지 않고 설계 §5.3 · OQ-C 를 가리킨다."
    touches: []
    decides: [OQ8]
  - id: RC2
    path: "docs/superpowers/specs/2026-09-06-document-review-redesign-design.md"
    anchor: "### 5.3 프로필 넷 › 표의 `web` 행"
    line: 185
    claim: "설계가 적은 이유는 표 한 칸이다: 「| `web` | critic 의 웹 허용 | false | true(방향성 축은 근거 폭이 본질) | false | false |」(칸 순서 design-doc · brief · seed · generic). design-doc 쪽 `false` 에는 별도 사유가 없고, brief 쪽 `true` 의 사유(방향성 축은 근거 폭이 본질)만 있다."
    touches: []
    decides: [OQ8]
  - id: RC3
    path: "docs/superpowers/specs/2026-09-06-document-review-redesign-design.md"
    anchor: "## 16. 결정 기록 › S1 행"
    line: 837
    claim: "결정 기록 원문: 「| S1 | 방향성 리뷰어의 웹 탐색은 brief 프로필의 `web: true` 로 흡수 | 근거 폭이 본질인 축은 brief 의 방향성 하나뿐 | 「방향 리뷰어는 별도 agent 로」(ST1 재개) |」. 절 머리(:828)는 「이 설계 세션에서 사용자가 답한 것 넷(브리프 OQ 해소)과 설계가 혼자 닫은 것」이라 적는다 — 사용자가 답한 넷은 Q1~Q4 행이고(개수로 대응) S1 은 그 밖이다. 즉 이 문서 안에서 design-doc `web: false` 는 사용자 발화가 아니라 설계가 닫은 결정으로 기록돼 있다(S 접두 = 설계 단독이라는 명시 문장은 없고, 「넷」 과 Q1~Q4 의 개수 대응으로 읽은 것이다)."
    touches: []
    decides: []
  - id: RC4
    path: "docs/superpowers/specs/2026-09-06-document-review-redesign-design.md"
    anchor: "## 15. Open Questions › OQ-C"
    line: 807
    claim: "설계가 스스로 열어 둔 질문 원문: 「**OQ-C** — `doc-critic` 의 웹 허용을 brief 프로필에만 두었다. design-doc 프로필에서 외부 근거가 필요한 finding(구현 가능성)이 나오면 그때 `web: true` 로 열지, 별도 처분값으로 둘지.」 절 머리는 「이 설계가 닫지 않은 것. 유추하지 않는다.」 다. 즉 `web: false` 는 닫힌 결정이 아니라 다시 열 조건(외부 근거가 필요한 finding 이 나오면)이 붙은 채 남아 있다. 레포에서 OQ-C 를 닫은 기록은 찾지 못했다."
    touches: []
    decides: [OQ8]
  - id: RC5
    path: "docs/superpowers/plans/2026-09-08-docreview-design-doc-site.md"
    anchor: "Task 8 › 「Step 3: 능력 축소를 명시한다 (조용히 넘기지 않는다)」"
    line: 1326
    claim: "CHANGELOG 항목의 출처인 계획 원문: 「…`design-doc.md` 프로필은 `web: false` 다 — **design doc 리뷰의 외부 prior-art 대조가 Claude·codex 양쪽에서 동시에 0 이 된다.** 설계는 이것을 의도로 정했고(§5.3 표 · OQ-C) 이 태스크는 그 결정을 뒤집지 않는다. 다만: 1. CHANGELOG 의 `### Changed` 에 이 축소를 **한 줄로 명시**한다. 없어진 능력이 릴리스 노트에 없으면 다음 사람이 회귀로 읽는다. 2. README 에서 `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 이 design-doc 리뷰를 덮는다는 서술이 있으면 고친다 — **끌 대상이 없는 kill switch 를 있다고 적으면 껐다고 믿게만 만든다**(P21).」 계획도 새 이유를 더하지 않고 공시만 요구한다."
    touches: []
    decides: []
  - id: RC6
    path: "docs/archive/plans/2026-08-09-codex-usage-unification.md"
    anchor: "「명시적으로 켠다 — design doc 리뷰는 외부 prior-art 대조가 판정의 일부다.」"
    line: 4401
    claim: "축소 전 상태의 근거: 옛 `run_spec_codex_reviewer.sh` 에 넣은 주석 원문이 「웹 검색: 사용자 kill switch(DEVBREW_SPEC_DISTILL_DISABLE_WEB=1)만 끈다. 그 밖에는 명시적으로 켠다 — design doc 리뷰는 외부 prior-art 대조가 판정의 일부다. `allowed_domains`로 좁히지 않는다 … 좁히면 조사 능력을 깎는다(하니스는 능력을 억제하지 않는다).」 였다. 1.0.0 이전에는 설계문서 리뷰에서 외부 선행 사례 대조가 판정의 일부로 명시돼 있었고, 09-06 설계의 S1 은 이 문장을 인용하거나 반박하지 않는다(충돌하는 두 기록)."
    touches: []
    decides: [OQ8]
  - id: RC7
    path: "docs/superpowers/interview/2026-09-06-document-review-redesign-interview.md"
    anchor: "🗣 confirmed **C9** — 「레포 안에서 참고할 선례는 brief 의 방향 리뷰어와 quality-gates 의 critique 리뷰어 쌍이다 — 참고하되 끌려가지 않는다 ⟨S1⟩」"
    line: 200
    claim: "그 설계의 출처 brief 에는 설계문서 리뷰의 웹을 끄라는 확정 항목도 사용자 발화도 없다. brief 본문에서 web · 웹 · 외부 를 찾으면 :298 의 위험 한 줄(codex 독립성)뿐이고, 짝 audit 에서는 진행 기록(web sweep 횟수 · `check_brief.py … web: enabled`)뿐이다. 웹에 닿는 사용자 원문은 C9(방향 리뷰어를 참고 선례로 삼되 끌려가지 않는다) 하나다."
    touches: []
    decides: []
  # ── B. 그 뒤 이 결정을 다시 다룬 기록 ───────────────────────────────
  - id: RC8
    path: "docs/superpowers/plans/2026-09-06-document-review-engine.md"
    anchor: "「웹은 프로필이 정하지만 도구 표면은 상수라 `WebSearch`/`WebFetch` 를 **넣지 않는다** — brief 프로필의 웹은 codex 축이 담당하고(설계 S1), critic 의 웹은 OQ-C 로 열려 있다.」"
    line: 3677
    claim: "설계 §5.2(:153)는 「프로필이 `web: true` 면 `WebSearch, WebFetch` 추가 — … 웹 허용 여부는 dispatch 프롬프트의 `web_disabled` 슬롯으로 전달한다」 고 적었으나, 구현 계획은 `doc-critic` 에 웹 도구를 넣지 않았다. 그래서 1.0.0 시점의 `web: true` 는 codex 웹만 뜻했고 Claude 쪽 탐지는 어느 프로필에서도 웹이 없었다. `web_disabled` 슬롯은 지금 agent 정의에 없다(`input_slots` 넷: document · profile · prior_finding_ids · related_changes)."
    touches: []
    decides: []
  - id: RC9
    path: "plugins/spec-distill/CHANGELOG.md"
    anchor: "## [3.1.0] — 2026-09-14 › ### Added › 「웹 있는 탐지 리뷰어 사본 `agents/doc-critic-web.md`.」"
    line: 1303
    claim: "Claude 쪽 웹이 돌아온 기록 원문: 「… 도구는 `doc-critic` 의 `Read, Grep, Glob` 에 `WebSearch` · `WebFetch` 를 더한 것이다. 프로필이 `web: true` 인 자리만 지명한다 — 오늘은 brief 자리 하나다(사용자 결정). brief 자리의 Claude 쪽 웹 근거(층 1 방향성의 외부 선례)가 이것으로 돌아왔다. 나머지 자리의 탐지는 웹 없는 `doc-critic` 그대로다.」 「사용자 결정」 이라는 표기는 여기 있지만, 그 결정의 원 발화가 적힌 설계문서 · 계획 · 인터뷰는 찾지 못했다(`docs/superpowers/plans/2026-09-10-docreview-brief-site.md` 에 `doc-critic-web` 0건)."
    touches: []
    decides: [OQ8]
  - id: RC10
    path: "docs/superpowers/interview/2026-09-27-review-stopping-criterion-interview.audit.md"
    anchor: "「방향 결함도 하류에는 웹이 없어 외부 선례 축이 사라지고, repo 쪽(feasibility)만 남는다.」"
    line: 48
    claim: "뒤 인터뷰가 이 결정을 전제 반증의 근거로 다시 다뤘다. 원문: 「design-doc 프로필의 `ground_truth` 는 「인터뷰 브리프 §2 확정 항목」이고 `web: false` 다. … 방향 결함도 하류에는 웹이 없어 외부 선례 축이 사라지고, repo 쪽(feasibility)만 남는다.」 같은 인터뷰 brief(`…-review-stopping-criterion-interview.md:194`)는 위험으로 「방향 축을 advisory 로 내리면 무조건 외부 반증 지점이 약해진다 — 하류 design doc 프로필은 `web: false` 이고, 인터뷰 steelman 은 trigger 조건부다」 를 적는다. 둘 다 `web: false` 를 사실로 인용할 뿐 값을 바꾸자는 결정은 아니다. 이 밖에 설계문서 프로필의 웹을 다시 여는 설계 · 로드맵 기록은 찾지 못했다(지금 진행 중인 2026-11-15 인터뷰 state 는 제외)."
    touches: []
    decides: [OQ8]
  # ── C. 엔진이 `web:` 값으로 무엇을 달리 하는가 ──────────────────────
  - id: RC11
    path: "shared/docreview/scripts/docreview_state.py"
    anchor: "PROFILE_FIELDS … `\"web\"` · `if not isinstance(data[\"web\"], bool):`"
    line: 51
    claim: "엔진 python(docreview_state · docreview_route)은 `web` 을 필수 필드 · bool 로 검증하고 `profile-check` 출력에 실어 줄 뿐, 그 값으로 분기하지 않는다(`shared/docreview/scripts/*.py` 에서 web 은 :51 · :196 두 줄뿐). 값을 읽어 행동을 바꾸는 소비자는 둘이다 — brief 진입 skill 의 선택 펜스(RC12)와 codex 러너(RC14)."
    touches: []
    decides: []
  - id: RC12
    path: "plugins/spec-distill/skills/reviewing-brief/SKILL.md"
    anchor: "<!-- critic-select:begin --> 펜스 (`CRITIC_AGENT=…`)"
    line: 491
    claim: "doc-critic 과 doc-critic-web 을 가르는 자리는 brief 진입 skill 의 이 펜스 하나다. `docreview_state.py profile-check brief.md` 의 JSON 에서 `web` 을 읽어, true 이고 `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 이 정확히 `1` 이 아니면 `CRITIC_AGENT=spec-distill:doc-critic-web`, 그 밖(web false · 스위치 켜짐 · 판독 불가)은 `spec-distill:doc-critic` 이다. 스위치 · 판독 불가로 내려간 경우에만 advisory 와 degrade record(`critic`/`direction`/`degraded`)를 남긴다. 펜스의 프로필 경로는 `brief.md` 로 박혀 있다(:504). 산문(:486)은 「이 선택을 강제하는 훅은 없다」 고 적는다."
    touches: []
    decides: [OQ8]
  - id: RC13
    path: "plugins/spec-distill/skills/spec-review/SKILL.md"
    anchor: "## 프로필 — 「프로필은 `design-doc.md` 로 **고정**이다」 · dispatch 블록 `subagent_type: \"spec-distill:doc-critic\"`"
    line: 338
    claim: "설계문서 리뷰 skill 에는 선택 펜스가 없다. 프로필은 `design-doc.md` 고정이고 탐지 dispatch 블록은 `spec-distill:doc-critic` 하나(:516), 재비판은 `spec-distill:doc-recritic`(:534)다. 이 파일 전체에 web · 웹 이라는 글자가 한 번도 없다 — `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 확인도, 웹 degrade 공시 줄도 없다. 따라서 프로필의 `web:` 을 true 로 바꾸기만 하면 codex 쪽 웹만 켜지고(RC14) Claude 쪽 탐지는 여전히 웹 없는 `doc-critic` 이다 — Claude 쪽까지 열려면 이 skill 에 선택 펜스 · dispatch 블록 · 스위치 확인을 더해야 한다."
    touches: []
    decides: [OQ8]
  - id: RC14
    path: "shared/docreview/scripts/run_docreview_codex_reviewer.sh"
    anchor: "「웹 스위치 — 이 if/else 가 WEB_ARGS 를 만드는 **유일한 자리**다(P11).」"
    line: 469
    claim: "codex 쪽: 러너가 프로필 frontmatter 의 `web` 을 stdlib 파서로 읽어 `web.meta` 에 쓰고(:409), 기본 인자는 `-c 'tools.web_search=false' -c 'web_search=\"disabled\"'` 다. `web: true` 이고 두 호스트 스위치(`DEVBREW_SPEC_DISTILL_DISABLE_WEB` · `DEVBREW_QUALITY_GATES_DISABLE_WEB`)가 모두 `1` 이 아닐 때만 `tools.web_search=true` · `web_search=\"live\"` 로 바꾼다. `web: false` 프로필이면 스위치와 무관하게 꺼져 있다. 설계문서 리뷰(spec-review SKILL.md:451)는 이 러너를 `design-doc.md` 로 부르므로 codex 웹 검색은 꺼진 채 돈다. 러너는 프로필 본문 전체를 `<review_profile>` 로 프롬프트에 싣는다(:441-442) — 프로필 본문을 고치면 Claude 리뷰어와 codex 가 함께 바뀐다."
    touches: []
    decides: [OQ8]
  - id: RC15
    path: "shared/docreview/references/reviewing-document.md"
    anchor: "3. **탐지** — 「기본은 `doc-critic` 이고, 프로필이 `web: true` 인 자리는 자기 선택 펜스로 웹 사본 `doc-critic-web` 을 지명할 수 있다(어느 쪽인지는 진입 skill 이 정한다).」"
    line: 18
    claim: "공유 절차서는 웹 사본 지명을 엔진이 아니라 각 진입 skill 의 일로 둔다. 즉 `web: true` 는 Claude 쪽에서 자동으로 웹을 켜는 값이 아니라 진입 skill 이 선택 펜스를 가질 「수 있다」 는 허가다."
    touches: []
    decides: []
  # ── D. brief 의 direction 축과 doc-critic-web 이 지금 대조하는 것 ────
  - id: RC16
    path: "plugins/spec-distill/references/docreview-profiles/brief.md"
    anchor: "- `direction` — 「확정 항목이 리포 사실과 모순되거나, 더 성숙한 외부 대안이 있거나, 확정 사이가 서로 충돌한다. 근거(파일:심볼 · URL)를 `evidence` 에 인용한다.」"
    line: 25
    claim: "brief 프로필은 `web: true`(:14)이고 층 1 은 `[direction, overdesign]`, `direction` 은 `must_catch` 에 든다(:11). 층 머리(:21)는 「사용자가 정한 방향이 **틀렸을 근거**를 찾는다 — 리포 실체와 웹의 선례로. 방향을 바꾸지 않는다: finding 하나마다 사용자가 결정할 질문 하나를 `summary` 에 담고 처분은 `decide` 다.」, 판정 관계(:23)는 「`direction` 은 리포 실체와 웹 선례로 사용자가 정한 방향을 **반증**한다 — 이 축은 `ground_truth` 를 쓰지 않는다.」 다. 「더 성숙한 외부 대안이 있다」 가 이 축의 세 술어 중 하나로 명시돼 있다."
    touches: []
    decides: [OQ8]
  - id: RC17
    path: "plugins/spec-distill/agents/doc-critic-web.md"
    anchor: "## 웹 근거"
    line: 58
    claim: "웹 사본이 웹으로 대조하는 것 원문: 「웹(`WebSearch`·`WebFetch`)은 층 1 에서 문서의 **방향**을 따질 때만 쓴다 — 이 방향이 틀렸다면 그 근거는 무엇인가(방향을 반박하는 선행 사례 · 알려진 실패 양식 · 문서가 적지 않은 가정을 반증하는 사실), 그리고 더 나은 대안이 이미 있는가(성숙한 라이브러리 · 확립된 패턴 · 출시된 도구 · 문서화된 접근). 웹에서 얻은 근거는 URL 을 `evidence` 에 인용한다. 층 2 에는 웹을 쓰지 않는다 — 층 2 는 문서 안의 대조라 외부 정보가 오염원이다.」 `tools: Read, Grep, Glob, WebSearch, WebFetch`(:16). 정본은 `shared/docreview/agents/doc-critic-web.md` 이고 `doc-critic` 과의 차이는 frontmatter 세 키(name · description · tools)와 이 절 하나뿐이다. description 은 「`web: true` — today the interview brief」 로 자리를 brief 로 적는다. 웹 사본 본문은 자리에 묶이지 않은 범용 문장이라 다른 프로필이 지명해도 같은 대조를 한다."
    touches: []
    decides: [OQ8]
  # ── E. 설계문서 프로필이 「있는 것 검토」 · 레포 밖 대안을 다루는가 ──
  - id: RC18
    path: "plugins/spec-distill/references/docreview-profiles/design-doc.md"
    anchor: "frontmatter `layer_rubric` · `must_catch` · `web: false`"
    line: 14
    claim: "층 1 은 아홉(goal_fit · problem_definition · scope · architecture · component_relations · data_flow · tradeoffs · feasibility · overdesign), 층 2 는 여덟(placeholder · ambiguity · scope_creep · approaches_comparison · isolation · testing · handoff_incomplete · required_sections), `must_catch` 는 [goal_fit, problem_definition, scope, architecture, required_sections], `web: false`(:20)다. 열일곱 항목 어디에도 `## 있는 것 검토` 절을 읽거나 그 절의 내용(레포 밖 후보 · 사용자 승인)을 확인하는 항목이 없고, 이 파일 전체에 「있는 것 검토」 라는 글자가 없다. 층 1 판정 관계(:29)는 정답 출처(`source_interview` 파일)와의 정합이라 brief 의 `direction` 같은 「방향 반증」 축이 없다."
    touches: []
    decides: [OQ8, OQ10]
  - id: RC19
    path: "plugins/spec-distill/references/docreview-profiles/design-doc.md"
    anchor: "- `required_sections` — 「필수 섹션 누락. Context/Why · Goals · Non-goals · Constraints · Acceptance Criteria · Files to Modify · Verification Plan · Rejected Alternatives · Metadata 가운데 없는 절이 있거나…」"
    line: 108
    claim: "필수 절 아홉에 「있는 것 검토」 도 「상류 · 하류 연계」 도 없다. 그 절이 통째로 빠지거나 비어도 이 축은 finding 을 내지 않는다. 이 절을 요구하는 자리는 에픽 넘김 줄(`plugins/spec-distill/references/epic-handoff.md:7` 「설계문서에 ## 있는 것 검토 절(레포 안에 이미 있는 것을 먼저 찾아 쓰고, 레포 밖 패키지 · 프레임워크 · 서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다)…을 두고」)이고, 그 문구를 `test_end_gates.sh:68` · `test_epic_handoff.sh:64` · `test_review_handoff_order.sh:97` · `test_parallel_recommend_docs.sh:111` 이 잠근다 — 쓰라는 지시는 잠겨 있고 읽는 리뷰 항목은 없다."
    touches: []
    decides: [OQ10]
  - id: RC20
    path: "plugins/spec-distill/references/docreview-profiles/design-doc.md"
    anchor: "### 판정 절차 — 사다리"
    line: 69
    claim: "과설계 사다리 원문: 「1. 이 구조가 있어야 하나 — 투기적 필요면 한 줄로 그렇게 적고 뺀다 / 2. 이미 리포에 있는 원칙·메커니즘으로 되나 / 3. 이미 있는 하니스 표면(프로필 필드 · 처분 · 락 · 훅)으로 되나 / 4. 한 줄 규약으로 되나 / 5. 그제서야 새 메커니즘」. 2 · 3단은 레포 안 것만 말하고, 플랫폼 기본 기능 · 레포 밖 패키지 · 프레임워크로 되는지를 묻는 단이 없다. 이 축의 기준은 「브리프 §1 Goal 에 비해 과한가」(:39)이고 「이 축은 **과함만** 본다」(:87), 처분은 전부 `decide` 다. brief.md 의 사다리(:59-63)도 글자가 같다."
    touches: []
    decides: [OQ8, OQ10]
  - id: RC21
    path: "plugins/spec-distill/references/docreview-profiles/design-doc.md"
    anchor: "- `approaches_comparison` · - `feasibility` · - `tradeoffs`"
    line: 104
    claim: "대안에 가장 가까운 항목 셋: 층 2 `approaches_comparison`(「대안 비교 없이 단정된 선택. Rejected Alternatives 의 각 대안이 채택안과 같은 기준으로 비교됐는가 — 한 단어로만 기각했으면 지적.」), 층 1 `feasibility`(:38 「설계가 단정한 도구·리포 사실이 실재하는가(파일·락·시그니처를 읽어 확인한다).」), 층 1 `tradeoffs`(:37 「기각된 대안이 왜 기각됐는지가 확정 항목과 모순되지 않는가.」). 셋 다 문서가 이미 적은 대안의 비교 품질 · 실재 여부를 볼 뿐, 문서가 적지 않은 레포 밖 대안을 찾아오라는 문장은 없다. 리뷰어 도구도 `Read, Grep, Glob` 이라 레포 밖 것은 확인할 길이 없다(`shared/docreview/agents/doc-critic.md:13`)."
    touches: []
    decides: [OQ8, OQ10]
  # ── F. 걸리는 레포 규칙 ─────────────────────────────────────────────
  - id: RC22
    path: "CLAUDE.md"
    anchor: "### 네이밍 & 보안 › 「**Persona 파일은 보안-민감 코드.**」"
    line: 78
    claim: "원문: 「Reviewer persona를 약화(규칙 제거, 임계치 완화)하는 PR은 보안 리뷰 대상. test-suite 편집과 같은 신중함으로 persona 편집을 treat.」 같은 파일 :97 은 「**버그가 리뷰를 탈출하면** 기본 해결책은 잡았어야 할 reviewer persona 파일을 편집하는 것이다 … 그 버그를 더 잘 잡는 자리가 락 · 스크립트 · skill 이면 그것을 고치고 이유를 적는다.」, 철학 P21(`docs/philosophy/devbrew-harness-philosophy.md:59`)도 같은 말이다. 조항의 글자는 「약화」 를 보안 리뷰 대상으로 삼는다 — 규칙 · 도구를 더하는 편집이 대상인지는 글자로 정해져 있지 않다. 선례는 더하는 편집에도 보안 리뷰를 거쳤다: `docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md:155` 「persona 편집이라 보안 리뷰를 거친다」, :264 「그 persona diff 의 보안 리뷰(qg 보안 리뷰어, 웹 도구 없음) 결과가 PR 본문에 있다」, 그리고 CHANGELOG :386 「persona 는 보안에 민감한 파일이라 기록한다 — 도구 목록 `tools:` 과 데이터 경계 문장은 그대로」."
    touches: []
    decides: []
  - id: RC23
    path: "plugins/spec-distill/README.md"
    anchor: "「compounding substrate다. 리뷰가 놓친 결함류가 나오면 그 프로필과 페르소나를 편집하는 것이 compounding 이벤트다 — codex 도 같은 프로필 본문을 받으므로 한 곳을 고치면 두 판정자가 함께 바뀐다(persona = 보안-민감 코드).」"
    line: 89
    claim: "이 플러그인은 프로필도 persona 와 같은 보안-민감 편집 대상으로 적는다. 같은 README :305-307 은 「**design-doc 리뷰는 이 스위치의 대상이 아니다** — `doc-critic`·`doc-recritic` 은 `tools:` 에 웹 도구가 아예 없고 `design-doc.md` 프로필이 `web: false` 를 고정해서 켜고 끌 것이 없다.」 고 공시한다 — 설계문서 자리의 웹을 열면 이 문장과 kill switch 범위 공시를 함께 고쳐야 한다. CLAUDE.md 「컴포넌트 격리」 는 agent 가 `tools:` allowlist 만 쓰고, 플러그인을 건드리는 PR 마다 `plugin.json` SemVer bump 와 CHANGELOG 항목을 요구한다."
    touches: []
    decides: []
  # ── G. 그 변경을 지키는 테스트 · 락 ─────────────────────────────────
  - id: RC24
    path: "shared/tests/test_docreview_codex.sh"
    anchor: "「러너: web:false 프로필 → 두 kill switch 무관하게 웹 켜지 않음」"
    line: 64
    claim: "이 락은 실제 `design-doc.md` 를 `PROF` 로 넘겨(:31, 주석 `# web: false`) codex 인자에 `web_search=\"live\"` 가 없음을 단언한다. `design-doc.md` 를 `web: true` 로 바꾸면 이 단언이 RED 가 된다 — 설계문서 프로필의 `web: false` 를 실질로 핀하는 유일한 자리다. `shared/tests/test_docreview_profiles.sh:40` 의 「brief 만 web true」 는 이름과 달리 brief 값만 재고 design-doc 값은 재지 않는다. 같은 파일 :323 은 프로필 코퍼스 전체에서 러너의 웹 인자와 게이트 `web` 값이 같은지를 잰다(값 핀이 아니라 일치)."
    touches: []
    decides: []
  - id: RC25
    path: "plugins/spec-distill/tests/test_web_kill_switch.sh"
    anchor: "(b) 웹 도구 agent를 dispatch하는 skill — `GUARD_WINDOW=40`"
    line: 305
    claim: "웹 도구를 가진 agent(`tools:` 에 WebSearch/WebFetch — 도출)를 dispatch 하는 모든 skill · reference 표면은 각 dispatch 줄 위 40줄 안에 `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 확인이 있어야 하고 실행 가능한 확인 블록이 실재해야 한다. spec-review 가 `doc-critic-web` 을 dispatch 하게 되면 이 락이 스위치 확인을 요구한다. 같은 파일 :84-101 의 표는 codex 호출부별 웹 on/off 기대값을 리터럴로 두고(「넷 중 brief.md만 `web: true`고 나머지 셋은 `web: false`」 주석), :408-413 은 brief.md 가 `web: true` 임을 단언한다."
    touches: []
    decides: []
  - id: RC26
    path: "plugins/spec-distill/tests/test_reviewing_brief_critic_select.sh"
    anchor: "S1~S4 (「프로필 web: true · 스위치 꺼짐 → spec-distill:doc-critic-web」 …)"
    line: 7
    claim: "brief 선택 펜스를 차가운 셸로 잘라 실행해 네 셀(web true+스위치 꺼짐 → 웹 사본 / web true+스위치 켜짐 → 웹 없는 사본+advisory+record / web false → 웹 없는 사본 · 공시 없음 / 판독 불가 → 웹 없는 사본+advisory+record)을 잰다. 대상은 `reviewing-brief/SKILL.md` 하나다 — spec-review 에 같은 펜스를 더하면 이 락은 그것을 재지 않는다(같은 모양의 락이 새로 필요하다)."
    touches: []
    decides: []
  - id: RC27
    path: "shared/tests/test_docreview_agents.sh"
    anchor: "「웹 사본 doc-critic-web — doc-critic 의 variant-of 정본」"
    line: 64
    claim: "agent 를 고칠 때 걸리는 락 묶음: ① 이 파일 — 웹 사본의 `tools` 집합 == `doc-critic` 의 것 ∪ {WebSearch, WebFetch}, 본문 차이는 `## 웹 근거` 절 한 덩어리뿐, 그 절에 URL 인용 요구가 있고 검색 횟수 상한이 없음(:83-100). ② `shared/tests/test_variant_of_contract.sh`(variant-of 마커 파일 집합을 리터럴 목록과 등호로 대조 — `doc-critic.md` 한쪽만 고치면 RED). ③ `shared/tests/test_copy_of_contract.sh`(플러그인 사본이 정본과 바이트 동일). ④ `shared/tests/test_docreview_copy_set.sh:130`(사본 집합과 dispatch 집합이 모두 `spec-distill:doc-critic spec-distill:doc-critic-web spec-distill:doc-recritic` 와 같아야 한다 — 새 사본 · 새 dispatch 자리는 이 핀을 함께 고친다). ⑤ `plugins/spec-distill/tests/test_brief_agents.sh`(사본의 쓰기 · 실행 · 위임 도구 부재, model 키 부재, :185-203 웹 사본 도구 집합). ⑥ `shared/tests/test_docreview_layer1_wiring.sh`(agent 본문이 층 1 축 이름 · 판정 관계를 리터럴로 쥐지 않고, 프로필마다 「**층 1 판정 관계** —」 줄이 있고 넷이 서로 다른 문장). ⑦ `shared/tests/test_docreview_agent_fields.sh`(정본 셋 + 사본 셋의 출력 필드 문구)."
    touches: []
    decides: []
  - id: RC28
    path: "plugins/spec-distill/tests/test_overdesign_rubric.sh"
    anchor: "「AC8~AC11 : 사다리 · 자르지 않는 것 · 0건 출구 · 상한」"
    line: 275
    claim: "프로필 본문을 고칠 때 걸리는 락: 이 파일이 design layer1 축 수를 9 로 핀하고(:100 — 축을 더하면 숫자를 올려야 한다), 기존 여덟 축의 잔존(:48), layer1 이 한 줄일 것(:53-80), layer1 축 전부가 본문에 서로 다른 불릿을 가질 것(:104-136), 사다리 절의 다섯 단 문구(「이 구조가 있어야 하나」 · 「이미 리포에 있는」 · 「이미 있는 하니스 표면」 · 「한 줄 규약으로 되나」 · 「그제서야 새 메커니즘」, :322)를 brief · design 양쪽에서 부분 문자열로 잰다. 단을 «더하는» 것은 이 락을 깨지 않고, 기존 단의 문구를 바꾸면 RED 다. 그 밖에 `shared/tests/test_docreview_profile_schema.sh`(허용 키 · 중복 키 · 층 축의 사람말 사상 커버리지 — 새 축 이름은 엔진 사상에 있어야 한다, :188-194), `shared/tests/test_docreview_profiles.sh:28`(프로필은 정확히 넷, `web` 누락이면 rc 2), `plugins/spec-distill/tests/test_design_profile_source.sh`(정답 출처 문구), `plugins/spec-distill/tests/test_reviewing_spec_design_only.sh`(spec-review 가 design-doc 프로필 하나만 이름 댄다), `plugins/spec-distill/tests/test_dispatch_profile_inline.sh`(프로필 내용을 인라인으로 싣는 펜스)가 건다. 락들의 머리말이 스스로 밝히듯 대부분 «문구의 실재» 만 재고 리뷰어가 실제로 그렇게 판정하는지는 재지 않는다."
    touches: []
    decides: [OQ10]
unanswered: "① 설계문서 프로필을 `web: false` 로 둔 «이유» 는 레포에 따로 적혀 있지 않다 — 있는 것은 brief 쪽을 켠 이유(「근거 폭이 본질인 축은 brief 의 방향성 하나뿐」)와 열어 둔 질문 OQ-C 뿐이다. ② 이 값을 정한 사용자 발화는 찾지 못했다(출처 brief · audit 에 없고, 설계 §16 은 S1 을 사용자가 답한 넷 밖에 둔다). ③ CHANGELOG 3.1.0 의 「오늘은 brief 자리 하나다(사용자 결정)」 가 가리키는 원 발화의 기록 자리도 찾지 못했다. ④ OQ-C 를 닫거나 설계문서 자리의 웹을 다시 여는 결정 기록은 없다. ⑤ CLAUDE.md persona 조항이 도구 · 규칙을 «더하는» 편집에도 보안 리뷰를 요구하는지는 글자로 정해져 있지 않다(선례는 거쳤다)."
```

조사 중 확인한 충돌(둘 다 냈다):
- 축소 전 주석 「design doc 리뷰는 외부 prior-art 대조가 판정의 일부다」(RC6) 와 09-06 설계의 「근거 폭이 본질인 축은 brief 의 방향성 하나뿐」(RC3). 뒤 문서는 앞 문장을 인용하거나 반박하지 않는다.
- 설계 §5.2 의 「`web: true` 면 `doc-critic` 에 WebSearch/WebFetch 추가 · `web_disabled` 슬롯」(RC8) 과 실제 구현(도구 표면 상수, 웹은 별도 사본 `doc-critic-web` + 진입 skill 의 선택 펜스 — RC12 · RC15).

결정 연결은 좁게 달았다. OQ8(맞는지를 누가 무엇으로 판정하는가)에는 판정자 후보와 그 도구 범위에 닿는 주장을, OQ10(검토가 형식이 아니게 됐는지를 무엇으로 아는가)에는 「있는 것 검토」 절을 읽는 자리의 유무에 닿는 주장을 연결했다. OQ7 · OQ9 · OQ11 에 직접 닿는 근거는 이 질문 범위에서 나오지 않아 비워 뒀다.

읽은 주요 파일(절대경로):
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/docreview-profiles/design-doc.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/docreview-profiles/brief.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/CHANGELOG.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-09-06-document-review-redesign-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/plans/2026-09-08-docreview-design-doc-site.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/plans/2026-09-06-document-review-engine.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/archive/plans/2026-08-09-codex-usage-unification.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/interview/2026-09-06-document-review-redesign-interview.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/interview/2026-09-27-review-stopping-criterion-interview.audit.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/skills/spec-review/SKILL.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/skills/reviewing-brief/SKILL.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/agents/doc-critic-web.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/shared/docreview/scripts/run_docreview_codex_reviewer.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/shared/docreview/scripts/docreview_state.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/shared/docreview/references/reviewing-document.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/epic-handoff.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/README.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/shared/tests/test_docreview_codex.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/shared/tests/test_docreview_agents.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/shared/tests/test_docreview_copy_set.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/shared/tests/test_docreview_profiles.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/tests/test_overdesign_rubric.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/tests/test_web_kill_switch.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/tests/test_reviewing_brief_critic_select.sh

한계: 테스트는 읽기만 했고 돌리지 않았다(이 agent 에는 실행 도구가 없다) — 「RED 가 된다」 는 단언문과 입력을 읽어 낸 판단이다. Grep 은 심볼릭 링크를 건너뛰므로 `plugins/spec-distill/scripts/` 의 링크 배포본은 정본(`shared/docreview/scripts/`)으로 읽었다.


### 조사 10 — repo-researcher · R5 · 묶음 3

레포 루트: /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first (아래 `path` 는 모두 이 루트 기준 상대경로)

읽은 범위를 먼저 밝힌다. 이 실행에는 셸이 없어 `git log` 를 돌리지 못했다. 커밋 해시는 문서에 적힌 것만 옮겼다. 「있는 것 검토」 절이 있는 설계 11개는 그 절과 `## 결정 기록` 을 직접 읽었다. 그 절이 없는 나머지(specs 약 40개 · archive 설계 11개)는 전문을 읽지 않고 헤딩 · 결정 줄 · 기능 이름 grep 과 부분 읽기로 확인했다.

```yaml
repo_claims:
  # ── A. 규칙 문장이 「외부 것 · 레포 밖 · 바깥 것」 범위를 어디까지 적는가 ──
  - id: RC1
    path: "CLAUDE.md"
    anchor: "**있는 것 먼저.** 만들기 전에 레포 안 · 밖의 있는 것을 검토하고 외부 것은 사용자 검토 뒤 쓴다(철학 P8)."
    line: 34
    claim: "규칙 문장은 「레포 안 · 밖」 · 「외부 것」 두 낱말만 쓰고 범위를 열거하지 않는다. Claude Code 기본 기능이나 이미 의존으로 적힌 것이 「외부 것」에 드는지 빠지는지 적은 글자가 없다."
    touches: []
    decides: [OQ9]
  - id: RC2
    path: "docs/philosophy/devbrew-harness-philosophy.md"
    anchor: "(재사용) 새로 만든 것은 유지할 표면이 되므로 레포 안 · 밖에 있는 것을 먼저 검토하고, 외부 것은 사용자가 검토한 뒤에 쓴다(P17)."
    line: 85
    claim: "철학 P8 의 재사용 조항도 「외부 것」의 범위를 열거하지 않는다. 승인 근거로 P17(User Sovereignty, 50행)을 가리킨다. P17 본문은 「위험한·되돌리기 어려운·공유 state에 영향을 주는 액션은 항상 confirmation 게이트」다."
    touches: []
    decides: [OQ9]
  - id: RC3
    path: "plugins/spec-distill/skills/pm-interview/SKILL.md"
    anchor: "**있는 것 먼저.** … 바깥의 성숙한 것(패키지 · 프레임워크 · 도구)을 웹으로 찾는다. … 바깥 것은 사용자 검토 뒤에만 쓴다 — 후보와 차이를 보이고 묻는다."
    line: 312
    claim: "인터뷰 조사 단계의 「바깥 것」은 「패키지 · 프레임워크 · 도구」로 열거되고 웹으로 찾는 대상이다. 레포 안은 「같은 일을 하는 스크립트 · skill · 모듈」이다. Claude Code 기본 기능과 dependencies.md 에 적힌 것은 어느 쪽 열거에도 없다."
    touches: []
    decides: [OQ9]
  - id: RC4
    path: "plugins/spec-distill/references/epic-handoff.md"
    anchor: "설계문서에 ## 있는 것 검토 절(레포 안에 이미 있는 것을 먼저 찾아 쓰고, 레포 밖 패키지 · 프레임워크 · 서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다)"
    line: 7
    claim: "에픽 넘김 줄은 승인 대상을 「레포 밖 패키지 · 프레임워크 · 서비스」로 적는다. 같은 문장이 `plugins/spec-distill/skills/pm-interview/references/finishing.md:553` 에 있고 `plugins/spec-distill/tests/test_end_gates.sh:68` 의 SHARED 리터럴이 글자로 잠근다. 여기에도 Claude Code 기본 기능 · 이미 적힌 의존은 없다."
    touches: []
    decides: [OQ9]
  - id: RC5
    path: "docs/superpowers/specs/2026-10-17-epic-conductor-design.md"
    anchor: "결정 · 2026-10-17 · 이해 확인 — 「… 기존에 있던거를 사용할 수 있는지 검토하는 성향이면 좋겠어 레포 내부든 외부든(예시로 페키지 프레임워크 등 항목은 너가 잘 적고 다만 외부는 나한테 검토 받고 사용하는거로) …」"
    line: 373
    claim: "「외부는 검토 받고 사용」 원칙의 사용자 원문 전체다. 「외부」의 예시는 사용자가 「페키지 프레임워크 등」으로만 들고 「항목은 너가 잘 적고」로 열거를 모델에 맡겼다. `docs/superpowers/specs/2026-10-19-principles-docs-cleanup-design.md:70` 은 이 원문을 「…」 로 줄여 원칙 6 의 근거로 싣는다."
    touches: []
    decides: [OQ9]
  - id: RC6
    path: "docs/superpowers/specs/2026-10-17-epic-conductor-design.md"
    anchor: "### §8 있는 것 검토 — **레포 밖(사용자 승인됨 — `## 결정 기록` 「1 · 외부 후보도 씁 (권장)」).** superpowers skill — … · Claude Code 기본 기능 — 작업 목록 · agent 의 worktree 격리 · `SendMessage` · `PushNotification` · GitHub CLI `gh`(없으면 강등)."
    line: 255
    claim: "Claude Code 기본 기능을 「레포 밖」 칸에 글자로 넣은 자리는 내가 본 범위에서 이 설계 하나다. grep 으로 본 CLAUDE.md · 철학 문서 · plugins 와 shared 의 md · docs/plugin-authoring.md · specs 에서 「Claude Code 기본 기능」 문자열은 이 줄에만 나온다. 같은 설계 Constraints(91행)는 「레포 안 것은 모델 판단으로 쓰고, 레포 밖 것은 사용자 검토 뒤에만 쓴다(§8)」다."
    touches: []
    decides: [OQ9]

  # ── B. 설계별 — 쓴 기본 기능 · 이미 적힌 의존과 사용자 결정 줄 ──
  - id: RC7
    path: "docs/superpowers/specs/2026-10-17-epic-conductor-design.md"
    anchor: "## 결정 기록 — 「결정 · 2026-10-17 · 접근 — 「1 · 외부 후보도 씁 (권장)」」"
    line: 380
    claim: "지휘자 설계는 superpowers skill 아홉 · Claude Code 기본 기능 넷 · gh 를 기반으로 쓰고, 그 사용 승인은 결정 줄 하나로 묶여 있다(하나씩 묻지 않았다). 결정 줄에는 답 라벨만 있고 질문문과 다른 선택지는 설계문서에 없다. 따로 「superpowers 재사용」 줄(382행) 「ok 2절 전체 각 부분은 superpowers가 잘하더라 최대한 가져오거나 불러서 쓰고 …」 가 있다."
    touches: []
    decides: [OQ9, OQ7]
  - id: RC8
    path: "docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.audit.md"
    anchor: "**S31** ☑ 선택 (round 21): 전부, 실험 기능은 제외 — … Claude Code 기본 기능 … 모두 재료로, 있는 것 먼저(S30). agent teams 같은 실험 기능은 기반으로 쓰지 않음(작업 목록·worktree 격리·SDD·qg 만)"
    line: 548
    claim: "로드맵 인터뷰에서 사용자가 선택지 하나로 「Claude Code 기본 기능 · 작업 목록 · worktree 격리 · SDD · qg 를 기반으로」를 묶어 골랐다. brief 는 이를 D33 으로 싣는다(`docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md:349`). S14(514행)는 「Claude Code 안 (권장) — … 상태줄·패널」, S30(546행)은 「그리고 원래 있는걸 더 만들생각 말고」다. 이 로드맵의 에픽 설계들은 기본 기능 사용의 근거로 이 번호를 인용한다."
    touches: []
    decides: [OQ9]
  - id: RC9
    path: "docs/superpowers/specs/2026-10-15-roadmap-control-plane-design.md"
    anchor: "Constraints — 「실험 기능은 기반으로 쓰지 않는다(D33) — 기반은 작업 목록 · 상태줄 설정 · 진입 skill.」 / 결정 기록 B1 · B2 · B3 · B7"
    line: 64
    claim: "작업 목록 · 상태줄 · 진입 skill 을 기반으로 쓴다. 「쓸지」를 묻는 결정 줄은 없고 근거는 brief 번호(D22 · D33) 인용이다. 사용자 결정 줄은 쓰는 방식에 관한 것이다 — B1 「상태줄을 켜는 방법 — 「명령만 주고 설치 안내 (권장)」」(177행), B2 「경고를 보이는 때 — 「상태줄에 항상 + 상세는 명령 (권장)」」, B3 「컨트롤 플레인 모양 — 「A. 스크립트 + 진입 skill + 캐시 (권장)」」, B7 「설계 2절 진입 skill · 설치 · 작업 목록 · 스위치 — 「맞다, 설계문서 작성 (권장)」」. 훅 알림은 B5 로 쓰지 않기로 했다."
    touches: []
    decides: [OQ9]
  - id: RC10
    path: "docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md"
    anchor: "번호 대조 — 「| D33 | 반영(R0 몫) | §3 ③ 작업 목록 · ⑤ qg `Spec:` · §5 worktree. SDD 실행 기록 회수는 R5(B6) |」"
    line: 483
    claim: "작업 목록 · worktree · superpowers SDD · qg 를 쓰지만 `## 결정 기록`(411행~, B1–B12)에는 그 사용을 묻는 줄이 없다. 근거는 brief D22 · D33 인용이다."
    touches: []
    decides: [OQ9]
  - id: RC11
    path: "docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md"
    anchor: "B2 · 결정 · 2026-10-17 · 실제 파서 — 「테스트에서만 씁니다 (권장)」(markdown-it-py, 개발 의존 · `uv.lock` 고정 · 원장 쓰기 락은 원인 치우기)"
    line: 318
    claim: "새 외부 패키지 하나(markdown-it-py)를 들일 때는 그것 하나에 대한 결정 줄이 있다. §8(216행)은 「**레포 밖**: markdown-it-py(MIT · 4.2.0 · 2026-05 · 의존 mdurl) — 사용자 검토 뒤 테스트에서만(B2). bashlex 는 GPLv3 라 쓰지 않고 …」 다. 이 설계가 함께 쓰는 subagent · superpowers · pr-review-toolkit 호출은 「레포 밖」 칸에 없고 결정 줄도 없다."
    touches: []
    decides: [OQ9]
  - id: RC12
    path: "docs/superpowers/specs/2026-09-21-python-floor-and-uv-design.md"
    anchor: "**D5 — uv 를 리포에 들인다.** 초안은 「pyproject·lock 없이 `uv run --with pyyaml`」이었고 사용자 반론(「같은걸 안들이는 이유가 있어? 들이는게 좋지않나」)으로 철회했다."
    line: 479
    claim: "「있는 것 먼저」 원칙(2026-10-17) 전의 설계인데, 새 외부 도구 uv 는 그것 하나에 대한 결정으로 들어왔다. 방향은 모델이 덜 들이려 했고 사용자가 들이자고 한 것이다. 같은 줄 묶음의 D6 은 「ruff 는 제외」, D7 은 「출하 PyYAML 은 별도 PR」 이다. uv 는 어느 dependencies.md 표에도 행이 없다."
    touches: []
    decides: [OQ9]
  - id: RC13
    path: "docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md"
    anchor: "K2. 외부 플러그인 리뷰어(pr-review-toolkit)를 쓰는 방식은 유지한다. / 결정 기록 표 「| OQ28 | 외부 플러그인 방식 유지, 고정 기본 3 + 조건부 4 + qg 재비판. opus 는 qg 소유 리뷰어만 고정 |」"
    line: 104
    claim: "pr-review-toolkit 을 계속 쓰는 것은 brainstorming 에서 닫은 결정으로 적혀 있다(Constraints 머리 98–100행 「이 문서가 더하는 제약은 brainstorming 에서 사용자가 정한 것이다」). 결정 표에는 사용자 원문 인용이 없고 결론만 있다."
    touches: []
    decides: [OQ9]
  - id: RC14
    path: "docs/superpowers/specs/2026-10-20-dependency-portability-design.md"
    anchor: "## 있는 것 검토 — 「레포 밖: git `remote set-head --auto` · `ls-remote --symref` · gh `-R` · `--json` 필드 · Renovate 의 기본 브랜치 설정 읽기(방식만 차용). 새 외부 패키지는 쓰지 않는다.」"
    line: 246
    claim: "이미 쓰던 git · gh 의 새 명령 · 플래그를 「레포 밖」 칸에 적었지만 그 사용을 묻는 결정 줄은 없다. Claude Code 기능은 「기각」 칸(247행 — plugin.json `dependencies` · `userConfig` · `.local.md` · 샌드박스)에 후보로 올랐다. project-init 훅 matcher 를 `Bash|EnterWorktree` 로 넓힌 것은 「지휘자 판단 … project-init matcher 에 EnterWorktree(a6c6dbd6)」(353행)로 사용자 결정이 아니다."
    touches: []
    decides: [OQ9]
  - id: RC15
    path: "docs/superpowers/specs"
    anchor: "헤딩 `## 있는 것 검토` / `### §8 있는 것 검토` (grep `^#+ .*있는 것 검토`)"
    claim: |
      「있는 것 검토」 절이 있는 설계는 11개이고 모두 2026-10-17 이후다. 레포 밖 칸의 내용은 아래와 같다.
      - epic-conductor 10-17 §8(255행): RC6 · RC7.
      - shared-review-engine-devices 10-17 §8(216행): RC11.
      - interview-open-research 10-19(208–209행): 「내장 `general-purpose` agent 는 쓰기 · 실행 도구를 가져 조사 agent 로 쓰지 않는다」 · 「바깥: Anthropic 의 다중 agent 조사 사례 … 를 따른다. 외부 패키지 · 도구는 쓰지 않는다.」 새 subagent 하나를 만든다.
      - principles-docs-cleanup 10-19(126행): 「안 쓴다: 외부 패키지 · 도구 없음(문서 정리라 필요 없음).」
      - dependency-portability 10-20(246행): RC14.
      - review-engine-leftovers 10-20(238행): 「레포 밖: codex CLI 의 설정 넘기기(`-c key=value` …) … 새 외부 패키지는 쓰지 않는다.」 191행에 「(지휘자 판단 — 외부 도구 …)」.
      - interview-gate-leftovers 10-21(225행): 「레포 밖: 쓰지 않는다. 파이썬 표준 `os.open` 플래그만 쓴다.」
      - r8-device-leftovers 10-23(339행): 「레포 밖: gh `pr view <번호> --json` · `pr create` 의 URL 출력. 새 외부 패키지는 쓰지 않는다.」
      - rules-docs-cleanup 10-23(394행): 「레포 밖: 쓰지 않는다.」
      - epic-parallel-recommend 10-25(190행): 「레포 밖 패키지 · 서비스는 쓰지 않는다 — 머지 큐는 레포마다 원격에 있으면 읽기만 한다.」 작업 목록 출력은 표에서 자기 스크립트(`control_plane.tasks_output`) 행으로 적혔다.
      - askquestion-recommendation 10-28(164행): 「레포 밖 후보: 없음. 질문 도구에 추천 필드가 없고(«cc-sdk-approvals»), PreToolUse 훅은 고르지 않은 길이다(K14).」
      이 11개 가운데 기본 기능 · 이미 적힌 의존의 사용을 묻는 결정 줄은 epic-conductor 의 묶음 한 줄과 shared-review-engine-devices B2(새 패키지) 둘이다. 나머지 9개의 결정 줄(U · B 번호)은 설계 내용 · 리뷰 반영에 관한 것이고, gh · git · codex · subagent · 훅 · AskUserQuestion 사용을 묻는 줄은 찾지 못했다. Claude Code 기능이 어느 칸에 오는지는 설계마다 다르다(epic-conductor 는 레포 밖, dependency-portability 는 기각, askquestion 은 레포 밖 후보, 나머지는 언급 없음).
    touches: []
    decides: [OQ9]
  - id: RC16
    path: "docs/superpowers/specs"
    anchor: "grep — 「있는 것 검토」 헤딩 없음 · 결정 줄 꼴(`^- (B|D|U)\\d+ ·`, 「사용자 결정/선택/승인」) 대조"
    claim: |
      2026-10-17 전 설계(specs 약 40개)와 `docs/archive/specs/` 설계 11개에는 「있는 것 검토」 절이 없다. subagent · `tools:` allowlist · 훅 · AskUserQuestion · Workflow · codex · superpowers · gh 를 기반으로 쓰면서 그 사용을 사용자에게 물은 결정 줄은 아래 넷 말고 찾지 못했다.
      - RC12(uv D5) · RC13(pr-review-toolkit K2 · OQ28) · RC9(상태줄 쓰는 방식 B1–B3).
      - `2026-07-27-spec-distill-brief-review-pipeline-design.md:131` 「| **D4** | 🗣 | brief 리뷰에 **codex도 활용** — 별-모델 독립 리뷰어 |」 — 사용자 발화로 codex 사용.
      방향이 반대인 기록도 있다. `docs/archive/specs/2026-07-19-plugin-audit-plugin-design.md:53–67` 은 사용자 지시 「… 외부 사례 탐색 깊게 해봐 …」 뒤 「재발명하지 말고 감싸라」 를 리서치 결론으로 적는다. `2026-10-15-state-storage-redesign-design.md:313` 은 B4 「세션 끝 정리 훅 — 「훅을 없앰 (권장)」」 이다. 이 묶음은 전문을 읽지 않았으므로 「없다」가 아니라 「이 방법으로는 못 찾았다」이다.
    touches: []
    decides: [OQ9]

  # ── C. dependencies.md 표의 행 — 처음 들어온 설계 · 결정 줄 ──
  - id: RC17
    path: "docs/superpowers/specs/2026-10-20-dependency-portability-design.md"
    anchor: "§5 「의존마다 확인 강도」 표(Python · git · gh · superpowers · qg · Claude Code) / G4 「의존(Python · git · gh · Claude Code · superpowers · qg)을 개발 당시 판으로 선언하고 …」"
    line: 158
    claim: "dependencies.md 표는 R8 설계(2026-10-20)에서 처음 생겼다. 그 전에는 「의존 최소 판 선언이 없다(spec-distill `README.md:274` superpowers 「optional」, `:275` qg 「따로 말하지 않는다」 …)」(64행)였다. 표의 행은 새로 들인 의존이 아니라 이미 쓰던 것을 선언한 것이다. CHANGELOG 로는 spec-distill 8.7.0(`plugins/spec-distill/CHANGELOG.md:153`) · quality-gates 14.6.0(`:70`) · project-init 5.3.0(`:41`) · plugin-audit 1.5.0(`:31`)이고 모두 2026-10-22 다. 그 커밋 해시는 문서에 없다."
    touches: []
    decides: [OQ9]
  - id: RC18
    path: "docs/superpowers/specs/2026-10-20-dependency-portability-design.md"
    anchor: "## 결정 기록 U1 · U2 · U3 · U6 · U7 · U11 · U12 · 「지휘자 판단 · 2026-10-20 — … qg 는 선택 의존 …」"
    line: 344
    claim: |
      행마다의 결정 줄은 아래와 같다. 사용자 줄은 「그 의존을 쓸지」가 아니라 강도 · 없을 때 동작 · 판 규칙을 정한다.
      - gh: U1 「gh는 있어야 한다고 보자 기본적인거야 그리고 너무 낮은 호환을제공하진말자」(344행) · U9 「GitHub 레포만 지원 (권장)」(351행).
      - superpowers: U6 「지금처럼 + 나머지는 멈춤 (권장)」 (superpowers 가 없을 때)(349행). plugin.json `dependencies` 에 올리지 않는 것은 지휘자 판단(360행).
      - python: U11 「넣는다 (권장)」(356행) = D3.21 「… Python 이 의존 선언 · 개발 당시 판 확인 목록에 없습니다 …」(387행).
      - python-hook: U12 「경로마다 실측 판 (권장)」(355행). 행 자체는 계획 `docs/superpowers/plans/2026-10-20-r8-plan2-gh-merge-dependencies.md:66` 「설계와 다른 점 12」 가 더했다.
      - 판 규칙 전체: U2 · U3 「개발 당시 버전 이렇게 하자」(345–346행).
      - quality-gates 행: 사용자 줄 없음 — 「지휘자 판단 · 2026-10-20 — … qg 는 선택 의존 · RC78 그대로」(359행).
      - git 행 · claude-code 행: 그 행만의 결정 줄 없음. 둘은 G4 · §5 표에 들어 있고, claude-code 는 §8 표 「`claude --version` ≠ 실행 중인 판 | 뺌 — … Claude Code 판은 기록만」(216행)이다. 덮는 사용자 줄은 묶음 승인 U7 「덩어리 3(조용한 오답 · 작업공간 · 개발 당시 판) · 덩어리 4(쓰는 세션 신뢰) 되비춤에 「좋아」」(350행)뿐이다.
      - 플러그인별 행 배정: 계획 `…r8-plan2-gh-merge-dependencies.md:63` 「설계와 다른 점 · 설계에 없던 결정 9」 — 「plugin-audit · project-init 의 의존 행은 Python · Claude Code 둘 … codex CLI 는 이 표에 넣지 않고 README 의 지금 줄을 둔다(설계 표 밖)」. 사용자 결정 표시는 없다.
    touches: []
    decides: [OQ9]
  - id: RC19
    path: "docs/superpowers/specs/2026-10-23-rules-docs-cleanup-design.md"
    anchor: "## 결정 기록 「작성자 판단(지휘자가 맡긴 자리 · 사용자 결정 아님) · 2026-10-23: … qg `dependencies.md` 의 `pr-review-toolkit` 행은 `check_deps.py measure` 가 외부 플러그인 판을 못 재서 새 측정 길이 필요하다 → `## 미룸`.」"
    line: 565
    claim: "표가 생긴 뒤 더해진 행은 quality-gates 의 `pr-review-toolkit` 하나다(`plugins/quality-gates/CHANGELOG.md:38`, 14.7.3 · 2026-10-24). 사용자 결정 줄 없이 「작성자 판단(… 사용자 결정 아님)」 → `## 미룸` 표(664행) → 계획 2 Task 7b (i) 로 들어갔다. 미룸 행은 「끝냄 — c4f419e4(행 · 예외 문장 · 락) · 0224b553(CHANGELOG)」 을 적는다. 계획은 `docs/superpowers/plans/2026-10-23-r9-plan2-cost-scale-disclosure.md:246–265` 이고 커밋 메시지는 「fix(qg): 의존 표에 외부 플러그인 pr-review-toolkit 행을 기록으로 더하고 판 칸 — 예외를 규칙에 적는다」 다. 근거는 「qg 가 그 agent 를 dispatch 하는데 의존 표에 없다」(664행)이고, 이미 쓰던 의존의 선언이다(RC13)."
    touches: []
    decides: [OQ9]
  - id: RC20
    path: "plugins/quality-gates/dependencies.md"
    anchor: "「판을 잴 길이 없는 외부 플러그인 행만 판 칸 둘에 `—` 를 적는다」 / 행 「| pr-review-toolkit | — | — | 기록 | 외부 플러그인이라 판을 재지 못한다 …」"
    line: 8
    claim: "지금 표에서 「외부 플러그인」이라고 불리는 행은 pr-review-toolkit 하나다(CLAUDE.md:50 에 같은 예외 문장). 네 표의 행 전체는 spec-distill: python · git · gh · superpowers · quality-gates · claude-code / quality-gates: python · git · gh · claude-code · pr-review-toolkit / project-init: python · python-hook · claude-code / plugin-audit: python · claude-code 다. claude-code 는 네 표 모두에서 강도 「기록」 · 「잰 판을 기록만 한다」 다."
    touches: []
    decides: [OQ9]

  # ── D. 이번 seed audit 의 라운드 2 질문 ──
  - id: RC21
    path: "docs/superpowers/interview/2026-11-15-existing-framework-first-interview.audit.md"
    anchor: "### 라운드 2 — 「물은 것: 지금은 「외부 것은 사용자 검토 뒤 쓴다」입니다. 「쓰는 것이 기본」이 되면 이 승인은 어떻게 할까요? / 선택지: 승인 유지 / 새로 들일 때만 / 기준 넘으면 묻지 않음 / 당신이 답한 것: 승인 유지」"
    line: 58
    claim: "audit 에는 선택지의 라벨 셋과 답만 있고 선택지 설명은 없다. 「새로 들일 때만」이 무엇을 뜻했는지(이미 의존으로 적힌 것 · Claude Code 기본 기능을 승인에서 빼는 뜻이었는지)는 audit 어디에도 없다. 레포 전체 grep 에서 「새로 들일 때만」은 이 줄과 이번 인터뷰 state 파일의 인용 둘(989행 · 2477행)뿐이다. `## 1. 원문` 26행은 「(라운드 2 답 — 외부 승인) 승인 유지」 다."
    touches: []
    decides: [OQ9, OQ7]
  - id: RC22
    path: "docs/superpowers/interview/2026-11-15-existing-framework-first-interview.audit.md"
    anchor: "확인 질문: 라운드 2 의 풀이 — 「외부 것은 지금처럼 후보와 차이를 보이고 사용자 승인을 받은 뒤에만 쓴다.」 — 고름"
    line: 79
    claim: "사용자가 확인한 풀이는 「외부 것」 · 「지금처럼」 이라고만 하고 범위를 정하지 않는다. 같은 audit 라운드 1(40–42행)에서 「검증된 프레임워크」의 답에 「Claude Code 기본 기능」이 들어 있다. `## 3` 항목 16(104행)은 「지금 바깥에 기대는 것 — python · git · gh · superpowers · quality-gates · Claude Code · pr-review-toolkit(플러그인별 의존 표)」 라고 저자의 말로 적고 seed 에서는 덜어 냈다(122행). 항목 17(105행)은 두 승인을 이은 것이 「사용자가 한 말이 아니라 … 저자의 추론」 이라고 적는다."
    touches: []
    decides: [OQ9, OQ7]
  - id: RC23
    path: "docs/superpowers/interview/2026-11-15-existing-framework-first-interview.audit.md"
    anchor: "### 냉독 (seed-readback) — 「**「프레임워크」와 「외부 것」의 관계** 가 헷갈렸다. Claude Code 기본 기능도 승인이 필요한 「외부 것」인지, 아니면 승인 없이 쓰는 것인지 읽어 내지 못했다.」"
    line: 244
    claim: "seed 만 읽은 냉독자가 같은 모호함을 적었다. 바로 다음 불릿(245행)은 「양쪽 모두 승인이 필요하면 「기본」이 무엇을 바꾸는지(추천의 방향인지, 이유를 대는 부담이 어느 쪽에 있는지)가 잡히지 않는다」 다."
    touches: []
    decides: [OQ9, OQ7]
unanswered: "셋이다 — ① 셸이 없어 dependencies.md 행이 처음 들어온 커밋을 git 으로 확인하지 못했다(문서에 적힌 해시는 pr-review-toolkit 행의 c4f419e4 · 0224b553 뿐이고 2026-10-22 첫 표의 해시는 문서에 없다). ② 라운드 2 선택지의 설명 문구와 epic-conductor 「접근」 질문의 질문문 · 다른 선택지는 레포에 기록이 없다. ③ 2026-10-17 전 설계와 archive 설계는 전문을 읽지 않아, 결정 줄 꼴이 아닌 산문 속 사용자 승인은 놓쳤을 수 있다."
```

**주장끼리 어긋나는 곳 (고르지 않고 둘 다 낸다)**

- RC6 · RC7 은 Claude Code 기본 기능을 「레포 밖」에 넣고 묶음 승인 한 줄을 받았다. RC9 · RC10 · RC14 · RC15 는 같은 종류의 기능을 「레포 밖」 칸에 넣지 않고 따로 묻지도 않았다. 설계마다 분류가 다르다.
- RC3 · RC4 의 규칙 문장은 승인 대상을 「패키지 · 프레임워크 · 도구/서비스」로 열거한다. RC1 · RC2 는 「외부 것」이라고만 한다. RC5 의 사용자 원문은 열거를 모델에 맡겼다.
- 새 외부 패키지 · 도구(RC11 markdown-it-py, RC12 uv)는 하나씩 결정 줄이 있다. 이미 쓰던 의존을 표에 올린 일(RC18 의 git · claude-code · quality-gates 행, RC19 의 pr-review-toolkit 행)은 사용자 줄 없이 지휘자 · 작성자 판단이나 묶음 승인으로 들어갔다.

**관련 파일 (절대경로)**

- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/CLAUDE.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/philosophy/devbrew-harness-philosophy.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/skills/pm-interview/SKILL.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/epic-handoff.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/skills/pm-interview/references/finishing.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/tests/test_end_gates.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/dependencies.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/quality-gates/dependencies.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/project-init/dependencies.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/plugin-audit/dependencies.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/quality-gates/CHANGELOG.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/CHANGELOG.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-17-epic-conductor-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-20-dependency-portability-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-23-rules-docs-cleanup-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-15-roadmap-control-plane-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-09-21-python-floor-and-uv-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-19-principles-docs-cleanup-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-19-interview-open-research-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-21-interview-gate-leftovers-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-23-r8-device-leftovers-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-25-epic-parallel-recommend-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-07-27-spec-distill-brief-review-pipeline-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-15-state-storage-redesign-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/archive/specs/2026-07-19-plugin-audit-plugin-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/plans/2026-10-20-r8-plan2-gh-merge-dependencies.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/plans/2026-10-23-r9-plan2-cost-scale-disclosure.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.audit.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/interview/2026-11-15-existing-framework-first-interview.audit.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/interview/2026-11-15-existing-framework-first-interview.md


### 조사 12 — open-researcher · R5 · 묶음 3


# 조사 보고 — superpowers 의 설계 · 계획 · 실행 · 리뷰 skill 본문과 이 레포가 지시를 얹는 자리

확인한 날: 2026-11-15. 판정은 하지 않았고 문장만 옮겼다.

## 먼저 알아야 할 것 (판 · 읽은 방법)

- **레포가 적은 판은 7.0.0, 지금 upstream 최신은 7.0.2 이고 main 은 v7.0.2 와 같다.** 이 기기에 깔린 설치본도 7.0.2 다.
- **brainstorming 의 「대안을 내놓고 추천을 붙이는 걸음」은 7.0.0 에 없다.** 7.0.1 에서 생겼고 7.0.2 에서 문장이 바뀌었다. 주문 (2) 가 묻는 걸음은 레포가 적은 판에는 없는 걸음이다.
- 나머지 다섯 skill 의 점검 목록 · 계획 요구 문장은 7.0.0 과 7.0.2 사이에 달라지지 않았다(파일별 근거는 아래 E2).
- **읽은 방법이 판마다 다르다.**
  - 7.0.2 전문: 설치본 `/Users/jeonghokim/.claude/plugins/cache/claude-plugins-official/superpowers/7.0.2/skills/…` 를 직접 읽었다. upstream v7.0.2 raw 와는 한 문장만 글자 대조했다.
  - 7.0.0 · 7.0.1: `raw.githubusercontent.com` 의 태그 경로를 WebFetch 로 읽었다. 이 도구는 중간 모델이 125자 이하 조각으로 인용해 돌려준다. 그래서 7.0.0 · 7.0.1 인용은 조각 단위 글자 인용이고 줄바꿈 · 굵은 표시는 확인하지 못했다.
- `check_deps.py` 는 돌리지 않았다(이 조사자는 셸이 없다). 「설치본이 레포가 적은 판과 다르다」는 폴더 이름 · plugin.json 으로만 본 것이다.

```yaml
evidence:
  # ── 판 ─────────────────────────────────────────────
  - url: "https://github.com/obra/superpowers/tags"
    supports: both
    claim: >
      태그: v7.0.0 = bb92a77 (Oct 10, 2026 — 전체 해시 bb92a77741419a4ab5f06e711a283343f1ada0c3,
      RELEASE-NOTES 머리는 2026-10-09) · v7.0.1 = 2ce8aa1 (Oct 21, 2026) · v7.0.2 = 22f0b46 (Nov 3, 2026).
      https://github.com/obra/superpowers/compare/v7.0.2...main 은 「v7.0.2 and main are identical」.
      main 의 .claude-plugin/plugin.json 은 "version": "7.0.2".
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "7.0.0 (plugins/spec-distill/dependencies.md, 잰 날짜 2026-10-22)", latest: "7.0.2 (2026-11-03, main 과 동일)"}
    certainty: confirmed

  - url: "https://github.com/obra/superpowers/commits/main/skills/writing-plans/SKILL.md"
    supports: both
    claim: >
      파일별 마지막 변경(commits 페이지).
      7.0.0 이후 그대로인 것: writing-plans/SKILL.md = 8ca22db(v6.4.2, Sep 25) ·
      requesting-code-review/code-reviewer.md = 5bf4e78(v6.4.1, Sep 19) ·
      requesting-code-review/SKILL.md = bb92a77(v7.0.0) ·
      verification-before-completion/SKILL.md = 3be5aad(Jul 24) ·
      using-superpowers/SKILL.md = 5bf4e78 ·
      subagent-driven-development/implementer-prompt.md = b36e082(v6.3.0).
      7.0.0 뒤에 바뀐 것: task-reviewer-prompt.md(22f0b46, v7.0.2) · executing-plans/SKILL.md(2ce8aa1 · 22f0b46).
      brainstorming/SKILL.md 와 subagent-driven-development/SKILL.md 의 commits 페이지는 잘려서 못 읽었다 —
      이 둘은 태그별 본문 대조와 RELEASE-NOTES 로 확인했다.
      builder-check-prompt.md 의 이력은 확인하지 못했다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "7.0.0", latest: "7.0.2"}
    certainty: confirmed

  # ── (1) 있는 코드 · 의존 · 라이브러리 · 선행 사례 — brainstorming ──
  - url: "https://raw.githubusercontent.com/obra/superpowers/v7.0.2/skills/brainstorming/SKILL.md"
    supports: both
    claim: >
      [7.0.2 — 설치본 전문] 있는 것 · 라이브러리 · 선행 사례 · 웹을 다루는 문장 전부.
      (a) L121-129 「**How it gets made.** Every project rests on choices about medium, tools, materials, and
      resources: the platform, programming language, and libraries for an app; the medium for a piece of art.
      Read from how they talk which of those choices they want to make. Someone who raises the how or asks about
      trade-offs wants the options with your pick. Someone who talks about outcomes is handing you the how: make
      those calls and state each in a line. When there's existing work, build on what it already uses. Any choice
      you make goes in the design as your call, never as something they agreed to.」
      (b) L42-50 「## Look Before You Ask — In an existing project, or when they've given you context (a spec, a
      plan, a handoff, files they pointed at, earlier conversation), dig in before your first message. Read what
      they referred to and the code or material it connects to, and keep reading until you can explain how the
      relevant parts work today and what this change would touch. Never ask what the project or their context
      already answers, or reopen what they've already decided.」
      (c) L152-154 「**Do recon.** Once you have a bit of grounding and looking further would help, go look: deeper
      into their codebase or project, their own files and data, or the web. Say what you looked for and what you
      found.」
      (d) Ground to cover L138-139 「prior art: what they've seen elsewhere, loved or hated」 ·
      「current state: what exists now, what they've tried」
      (e) 첫 메시지 L60-64 「Add what you found that bears on it: how the relevant parts work today and what the
      change would touch. If you found something they may not have considered that would change what they're
      asking for or how it has to be built, like a constraint, a conflict, or a cheaper path, say so plainly.」
      (f) HARD-GATE L272-274 「Building includes writing product code, scaffolding, installing dependencies,
      creating projects, and invoking an implementation skill. Reading and exploring are fine.」
      이 파일에 YAGNI 라는 낱말은 없다. 「librar」 는 L123, 「dependenc」 는 L273 한 곳씩뿐이다(설치본 grep).
    touches: []
    decides: [OQ7, OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "7.0.0", latest: "7.0.2"}
    certainty: confirmed

  - url: "https://raw.githubusercontent.com/obra/superpowers/v7.0.0/skills/brainstorming/SKILL.md"
    supports: both
    claim: >
      [7.0.0 — 레포가 적은 판, 조각 인용] 같은 자리의 문장이 다르다.
      (a) How it gets made: 「Find out early which of those choices they want to make, which they're handing to
      you, and what they already have to work with. Someone with strong views or skills will want to talk it
      through. Someone counting on you needs sensible defaults, said in plain words. When there's existing work,
      build on what it already uses. Any choice you make goes in the design as your call, never as something they
      agreed to.」 — 「When there's existing work, build on what it already uses.」 는 세 판 모두 같다.
      (b) 「## Look Before You Ask」 절이 없다. 「handoff」 · 「context」 낱말도 파일에 없다.
      (c) 조사는 허락을 구한다: 「Offer recon. Once you have a bit of grounding and looking would help, offer to go
      look: their codebase or project, their own files and data, or the web. Say what you'd look for. They decide
      whether you go.」 7.0.1 도 「Offer recon … They decide whether you go.」 이고, 7.0.2 에서 「Do recon … go
      look … Say what you looked for and what you found.」 로 바뀌었다.
      (d) 「prior art: what they've seen elsewhere, loved or hated」 는 같다.
      (e) HARD-GATE: 「Nothing gets built until your human partner approves the full description: in chat for a
      small change, the document for a project. Building includes writing product code, scaffolding, installing
      dependencies, creating projects, and invoking an implementation skill.」
    touches: []
    decides: [OQ7, OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "7.0.0", latest: "7.0.2"}
    certainty: confirmed

  # ── (2) 대안 · 추천 걸음과 밖에서 얹는 지시 ─────────────
  - url: "https://raw.githubusercontent.com/obra/superpowers/v7.0.2/skills/brainstorming/SKILL.md"
    supports: both
    claim: >
      [7.0.2 — 설치본 전문] 대안 · 추천 걸음이 적힌 자리 넷.
      (a) L26-32 「Before you start implementing, you must, in order: 1. Lay out the approaches in a message of
      their own, and have your human partner pick one (see Lay out the approaches). 2. Write the design doc, short
      or full (see Size the Work). 3. Get their approval of that doc. 4. Invoke the superpowers:writing-plans
      skill.」
      (b) L156-167 「**Lay out the approaches.** Once you understand what they want, and before you write anything
      up, put the ways of building it in a message of its own. Come up with several real alternatives and drop the
      weak ones, including any that work against why they want it and any the existing work rules out. Sketch the
      two or three that remain concretely enough to picture, grounded in what the project actually does, with what
      each trades off. Recommend one and say why, then ask which way they want to go; if they've handed you the
      how, say you'll go with your pick instead. When there's genuinely one sensible way, say so in that message
      and explain why the others don't fit; the design comes in the next one. This is for how it gets built; for
      what they want, get them describing first.」
      (c) L219-222 「Short or full, the design doc has an **Approaches** part: the two or three ways you considered
      building it, what each trades off, which one they picked, and why. They pick in the conversation, before you
      write the doc.」 그리고 The Written Design 의 Cover 목록에 「approaches (above)」.
      (d) 첫 메시지 L72-76 「If nothing like that is open, there's one sensible way: end with the short design
      itself (the approach, a line on why the others don't fit, and the design in a few lines) and ask them to
      approve it.」
      추천의 «방향»(있는 것을 쓰는 쪽 · 새로 만드는 쪽)을 정하는 문장은 이 걸음에 없다. 탈락 기준으로 적힌 것은
      「any that work against why they want it and any the existing work rules out」 둘이고, 남은 안의 근거는
      「grounded in what the project actually does」 다.
    touches: []
    decides: [OQ7, OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "7.0.0", latest: "7.0.2"}
    certainty: confirmed

  - url: "https://raw.githubusercontent.com/obra/superpowers/v7.0.0/skills/brainstorming/SKILL.md"
    supports: both
    claim: >
      [7.0.0 — 조각 인용] 대안 · 추천 걸음이 없다. 파일에 「approach」 가 들어간 문장이 하나도 없고
      「Lay out the approaches」 · 「Recommend one」 도 없다.
      절 머리는 Brainstorming / First: What Do You Actually Know? / Your First Message / The Conversation /
      Play It Back / Size the Work / The Written Design / Red Flags / Visual Companion 이다.
      선택지에 대한 7.0.0 문장: 「Get them describing. Open questions come first. Their own words carry intent that
      your options can't. Offer a short menu only when they're stuck.」 · Red Flags 「I'll offer options to save them
      effort | Options steer. Ask them to describe it first.」
      Size the Work 표는 세 줄이다 — 「A quick, clear task | the request itself | do it」 ·
      「A small change | in chat | build it through the normal workflow」 ·
      「A project with a written design | a written design document | a full plan (for software:
      superpowers:writing-plans)」.
      The Written Design 의 Cover 는 다섯 항목이고 approaches 가 없다.
    touches: []
    decides: [OQ7, OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "7.0.0", latest: "7.0.2"}
    certainty: confirmed

  - url: "https://raw.githubusercontent.com/obra/superpowers/v7.0.1/skills/brainstorming/SKILL.md"
    supports: both
    claim: >
      [7.0.1 — 조각 인용] 대안 · 추천 걸음이 여기서 생겼다.
      「Once you understand what they want, and before you write anything up, put the ways of building it in a
      message of its own. Come up with several real alternatives and drop the weak ones, including any that work
      against why they want it and any the existing work rules out. Present the two or three that remain, grounding
      each in what the project actually does and saying what it trades off. Recommend one and say why, then ask
      which way they want to go. When there's genuinely one sensible way, say so and explain why the others don't
      fit.」
      「Before you start implementing, you must, in order」 네 걸음과 「## Look Before You Ask」 도 7.0.1 에서 생겼다.
      RELEASE-NOTES v7.0.1(설치본 사본): 「**It lays out the approaches and writes a design doc before building.**
      It presents two or three ways to build the thing, recommends one, and asks you to pick.」 (#2571)
      RELEASE-NOTES v7.0.2: 「**When there's a choice it can name, it shows you the options with a
      recommendation.**」 · 「**It reads from how you talk whether you want to discuss the technical choices,**」 (#2644)
    touches: []
    decides: [OQ7, OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "7.0.0", latest: "7.0.2"}
    certainty: confirmed

  - url: "https://github.com/obra/superpowers/blob/v7.0.2/skills/using-superpowers/SKILL.md"
    supports: both
    claim: >
      [설치본 7.0.2 전문 · 이 파일은 v6.4.1 뒤로 바뀌지 않았다] 사용자 지시와 skill 지시의 우선순위를 적은 문장은
      using-superpowers 의 「## User Instructions」 에 있다: 「User instructions (CLAUDE.md, AGENTS.md, GEMINI.md, etc,
      direct requests) take precedence over skills, which in turn override default behavior. Only skip skill
      workflows or instructions when your human partner has explicitly told you to.」
      brainstorming 본문에서 받은 프롬프트 · 첨부 문서를 다루는 문장(7.0.2):
      (a) L44-50 Look Before You Ask — 위 인용. 끝 문장 「Never ask what the project or their context already
      answers, or reopen what they've already decided.」 (7.0.1 은 「…already answers.」 까지, 7.0.0 은 절이 없다)
      (b) L56-57 「**They've already said what they want** (a spec, a plan, a detailed request)…」 ·
      L77 「Specs are often incomplete, so confirm before you build on one.」
      (c) L245-248 「**Where it goes:** in a software repo, `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`,
      committed. Otherwise, pick a sensible place and say where. Your human partner's preferences override
      both.」 — 「preferences override」 는 설계문서 위치 문단의 문장이다(7.0.0 에도 같은 문장).
      (d) L211-212 「say how big the work is in plain words. They can override it.」
      (e) L128-129 「Any choice you make goes in the design as your call, never as something they agreed to.」
      brainstorming 본문에는 「호출 프롬프트에 실려 온 지시」 를 따로 가리키는 문장이 없다.
      우선순위 문장은 using-superpowers 쪽 하나다. 본문은 설치본에서 읽었고 이 URL 은 같은 판의 upstream 자리다(직접 fetch 하지 않았다).
    touches: []
    decides: [OQ7, OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "7.0.0", latest: "7.0.2"}
    certainty: confirmed

  - url: "https://github.com/obra/superpowers/blob/v7.0.2/skills/brainstorming/builder-check-prompt.md"
    supports: both
    claim: >
      [설치본 7.0.2 전문] 설계문서 점검(builder check) 프롬프트는 계획을 세우는 데 모자란 질문만 묻는다:
      「Report only the questions you'd still need answered before you could plan this well: places where you'd
      have to guess and a wrong guess would matter.」 · 「Skip anything the document explicitly leaves to the
      builder, and anything you could reasonably decide yourself.」
      있는 것 · 라이브러리 · 대안 선택을 보라는 항목은 없다. 7.0.0 의 이 파일은 읽지 못했다.
    touches: []
    decides: [OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "7.0.0", latest: "7.0.2"}
    certainty: uncertain

  # ── (3) writing-plans ───────────────────────────────
  - url: "https://raw.githubusercontent.com/obra/superpowers/v7.0.0/skills/writing-plans/SKILL.md"
    supports: both
    claim: >
      [7.0.0 조각 인용 + 설치본 7.0.2 전문 — 두 판이 같다] 계획에 요구하는 구체 수준.
      Overview L10: 「What they cannot know is what you decided: which files, which names and signatures, which
      values from the spec, which tests prove each task. Document those. Give them the whole plan as bite-sized
      tasks. DRY. YAGNI. TDD. Frequent commits.」
      Task Structure: 「**Files:** - Create: `exact/path/to/file.py` - Modify: `exact/path/to/existing.py:123-145`
      - Test: `tests/exact/path/to/test.py`」 · 「**Interfaces:** - Consumes: [… exact signatures] - Produces: […
      exact function names, parameter and return types …]」
      What a Step Contains: 「**A test step:** the test's name and its assertions, as code, with the spec's exact
      values in them.」 · 「**A code step:** the exact signature (name, parameters, return type), the file it lives
      in, and the specific values the spec pins. The implementer writes the body. A body appears only for an
      algorithm the signature and tests do not determine, or for exact copy the spec fixes.」 ·
      「**A verification step:** the command to run and the output that means it passed.」
      「A plan is the set of decisions the implementer cannot make alone.」
      의존 · 라이브러리에 닿는 문장은 넷이다(설치본 grep 으로 전부):
      (a) 머리말 틀 L65 「**Tech Stack:** [Key technologies/libraries]」
      (b) Global Constraints L72-75 「[The spec's project-wide requirements — version floors, dependency limits,
      naming and copy rules, platform requirements — one line each, with exact values copied verbatim from the
      spec. Every task's requirements implicitly include this section.]」
      (c) Step 3 L123-125 「One line on the approach when the signature and the test leave a choice (which library
      call, which data structure); a code block only for an algorithm they do not determine.」
      (d) File Structure L30 「In existing codebases, follow established patterns.」
      라이브러리를 고르거나 있는 것을 찾아보라는 걸음은 없다. Self-Review 다섯 항목(Spec coverage · Step scan · Type
      consistency · Review Focus · Proportion)에도 의존 · 라이브러리 항목이 없다. 계획이 따르는 권위는
      「**Spec:** [path to the spec/design doc this plan implements — the plan argues from the spec, so the spec
      travels with it; executors read both]」.
      Execution Handoff: 「If they have already explicitly supplied an execution method, ask them to review the plan
      and confirm it captures what they want; wait for that review before implementation, then use the preserved
      method.」
    touches: []
    decides: [OQ7, OQ11]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "7.0.0", latest: "7.0.2 (이 파일은 v6.4.2 8ca22db 뒤로 그대로)"}
    certainty: confirmed

  # ── (4) 실행 · 리뷰 skill 의 점검 목록 ──────────────────
  - url: "https://raw.githubusercontent.com/obra/superpowers/v7.0.0/skills/subagent-driven-development/task-reviewer-prompt.md"
    supports: both
    claim: >
      [7.0.0 조각 인용 + 설치본 7.0.2 전문 — 점검 목록은 같다] 과제 리뷰어의 점검 목록.
      「## Part 1: Spec Compliance — Compare the diff against What Was Requested: - **Missing:** requirements they
      skipped, missed, or claimed without implementing - **Extra:** features that weren't requested,
      over-engineering, unneeded "nice to haves" - **Misunderstood:** right feature built the wrong way, wrong
      problem solved」
      「## Part 2: Code Quality — **Code quality:** Clean separation of concerns? / Proper error handling? / DRY
      without premature abstraction? / Edge cases handled? **Tests:** Do the new and changed tests verify real
      behavior, not mocks? / Are the task's edge cases covered? **Structure:** Does each file have one clear
      responsibility with a well-defined interface? / Are units decomposed so they can be understood and tested
      independently? / Is the implementation following the file structure from the plan? / Did this change create
      new files that are already large, or significantly grow existing files?」
      Calibration: 「Important means this task cannot be trusted until it is fixed: incorrect or fragile behavior, a
      missed requirement, or maintainability damage you would block a merge over — verbatim duplication of a logic
      block, swallowed errors, tests that assert nothing.」 · 「If the plan or brief explicitly mandates something
      this rubric calls a defect (a test that asserts nothing, verbatim duplication of a logic block), that IS a
      finding — report it as Important, labeled plan-mandated.」
      읽는 범위: 「Do not crawl the broader codebase. Inspect code outside the diff only to evaluate a concrete risk
      you can name — one focused check per named risk」 · 「If a requirement cannot be verified from this diff alone
      (it lives in unchanged code or spans tasks), report it as a ⚠️ item instead of broadening your search.」
      보고 불신: 「Design rationales in the report are claims too: "left it per YAGNI," "kept it simple
      deliberately," or any other justification is the implementer grading their own work.」
      「계획이 고른 라이브러리 · 기능을 썼는가」 나 「이미 있는 것의 재구현」 을 이름으로 묻는 항목은 없다. 설치본에서
      library · dependency · framework · reinvent · reimplement 를 grep 했을 때 이 파일은 0건이다. 중복에 닿는 것은
      「DRY without premature abstraction?」 과 「verbatim duplication of a logic block」(diff 안의 중복)이다.
    touches: []
    decides: [OQ11]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "7.0.0", latest: "7.0.2 (v7.0.2 커밋이 이 파일을 건드렸으나 Part 1 · Part 2 · Calibration 인용은 같다)"}
    certainty: confirmed

  - url: "https://raw.githubusercontent.com/obra/superpowers/v7.0.0/skills/subagent-driven-development/SKILL.md"
    supports: both
    claim: >
      [7.0.0 조각 인용 + 설치본 7.0.2 전문] 지휘 쪽(controller)이 리뷰어에게 지시를 싣는 자리와 그 제한.
      「The global-constraints block you hand the reviewer is its attention lens. Copy the binding requirements
      verbatim from the plan's Global Constraints section or the spec: exact values, exact formats, and the stated
      relationships between components ("same layout as X", "matches Y"). The reviewer's template already carries
      the process rules (YAGNI, test hygiene, review method) — the constraints block is for what THIS project's
      spec demands.」
      「Do not add open-ended directives like "check all uses" or "run race tests if useful" without a concrete,
      task-specific reason」
      「Do not pre-judge findings for the reviewer — never instruct a reviewer to ignore or not flag a specific
      issue. … If the prompt you are writing contains "do not flag," "don't treat X as a defect," "at most Minor,"
      or "the plan chose" — stop: you are pre-judging, usually to spare yourself a review loop.」
      권위 순서: 「The spec is the binding authority, the plan is its argument, and your judgment settles what
      neither answers.」
      실행 전 훑기(7.0.2 는 references/preflight.md, 7.0.0 은 SKILL.md 본문): 「tasks that contradict each other or
      the plan's Global Constraints」 · 「anything the plan explicitly mandates that the review rubric treats as a
      defect (a test that asserts nothing, verbatim duplication of a logic block)」
      판 차이: 7.0.0 의 SKILL.md 는 references/final-review.md · references/preflight.md 를 가리키지 않는다(본문에
      들어 있다). 7.0.1 이 fix loop · final review · preflight 등을 `references/` 로 옮겼다(RELEASE-NOTES v7.0.1,
      #2565). 위 인용 문장은 두 판에서 같다.
    touches: []
    decides: [OQ11]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "7.0.0", latest: "7.0.2"}
    certainty: confirmed

  - url: "https://github.com/obra/superpowers/blob/v7.0.2/skills/subagent-driven-development/implementer-prompt.md"
    supports: both
    claim: >
      [설치본 7.0.2 전문 · v6.3.0 뒤로 그대로] 과제 구현 agent 의 자기 점검:
      「**Discipline:** - Did I avoid overbuilding (YAGNI)? - Did I only build what was requested? - Did I follow
      existing patterns in the codebase?」
      Code Organization: 「Follow the file structure defined in the plan」 · 「In existing codebases, follow
      established patterns. Improve code you're touching the way a good developer would, but don't restructure
      things outside your task.」
      시작 전 질문: 「If you have questions about: … - The approach or implementation strategy - Dependencies or
      assumptions …」 · 문맥 칸 「[Scene-setting: where this fits, dependencies, architectural context]」
      멈출 조건: 「The task requires architectural decisions with multiple valid approaches」
      본문은 설치본에서 읽었고 이 URL 은 직접 fetch 하지 않았다.
    touches: []
    decides: [OQ11]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "7.0.0", latest: "7.0.2"}
    certainty: confirmed

  - url: "https://github.com/obra/superpowers/blob/v7.0.2/skills/requesting-code-review/code-reviewer.md"
    supports: both
    claim: >
      [설치본 7.0.2 전문 · v6.4.1 뒤로 그대로] 마지막 전체 리뷰(SDD · executing-plans 둘 다 이 틀을 쓴다)의 점검
      목록 전문.
      「## What to Check
      **Plan alignment:** - Does the implementation match the plan / requirements? - Are deviations justified
      improvements, or problematic departures? - Is all planned functionality present?
      **Code quality:** - Clean separation of concerns? - Proper error handling? - Type safety where applicable? -
      DRY without premature abstraction? - Edge cases handled?
      **Architecture:** - Sound design decisions? - Reasonable scalability and performance? - Security concerns? -
      Integrates cleanly with surrounding code?
      **Testing:** - Tests verify real behavior, not mocks? - Edge cases covered? - Integration tests where they
      matter? - All tests passing?
      **Production readiness:** - Migration strategy if schema changed? - Backward compatibility considered? -
      Documentation complete? - No obvious bugs?」
      Calibration: 「If you find significant deviations from the plan, flag them specifically so the implementer can
      confirm whether the deviation was intentional. If you find issues with the plan itself rather than the
      implementation, say so.」
      「## Declined to judge — Before your verdict, list every behavior you considered and set aside as outside the
      plan or spec, one line each, with the reason.」
      틀이 받는 칸은 넷뿐이다: 「[DESCRIPTION]」 · 「[PLAN_OR_REQUIREMENTS] — what it should do (plan file path, task
      text, or requirements)」 · 「[BASE_SHA]」 · 「[HEAD_SHA]」.
      라이브러리 · 의존 · 재구현을 이름으로 묻는 항목은 없다(같은 grep 0건). 닿는 것은 「Plan alignment」 세 줄,
      「DRY without premature abstraction?」, 「Integrates cleanly with surrounding code?」 다.
      requesting-code-review/SKILL.md(v7.0.0 뒤로 그대로)는 칸 이름과 「Dispatch a `general-purpose` subagent,
      filling the template at code-reviewer.md」 만 적는다.
      본문은 설치본에서 읽었고 이 URL 은 직접 fetch 하지 않았다.
    touches: []
    decides: [OQ11]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "7.0.0", latest: "7.0.2"}
    certainty: confirmed

  - url: "https://github.com/obra/superpowers/blob/v7.0.2/skills/subagent-driven-development/references/final-review.md"
    supports: both
    claim: >
      [설치본 7.0.2 전문] SDD 의 마지막 전체 리뷰에 싣는 것: 「Dispatch on the most capable available model (see
      SKILL.md's Model Selection), using superpowers:requesting-code-review's code-reviewer.md. Point it at the
      ledger's deferred-minor and parked lines so it can triage which must be fixed before merge.」
      지적이 나오면 「dispatch ONE fix subagent with the complete findings list」 · 「There is no second fix wave」.
      7.0.0 에서는 같은 문장이 SKILL.md 본문에 있다(조각 인용: 「Dispatch on the most capable available model (see
      Model Selection), using superpowers:requesting-code-review's code-reviewer.md. Point it at the ledger's
      deferred-minor and parked lines so it can triage which must be fixed before merge.」).
      SDD 쪽 마지막 리뷰 문장에는 계획의 Review Focus · spec 경로를 실으라는 말이 없다(executing-plans 쪽에는
      있다 — 다음 항목).
    touches: []
    decides: [OQ11]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "7.0.0", latest: "7.0.2"}
    certainty: confirmed

  - url: "https://raw.githubusercontent.com/obra/superpowers/v7.0.0/skills/executing-plans/SKILL.md"
    supports: both
    claim: >
      [7.0.0 조각 인용 + 설치본 7.0.2 전문 — 아래 문장은 두 판이 같다]
      「**Core principle:** The plan already did the thinking. Execute it exactly, prove each step with a test you
      watched fail and then pass, and leave a record that survives your own forgetting.」
      「Deviating from the plan without a ledgered ruling is a decision made in secret.」 · 완료 계약 「Every
      deviation from the brief has a `Ruling:` line in the ledger.」
      마지막 리뷰에 싣는 것: 「**With a subagent tool:** dispatch the reviewer on the most capable available model …
      using superpowers:requesting-code-review's code-reviewer.md, with the package path, the plan and spec
      paths, the plan's Review Focus section verbatim if it has one (the input classes and failure modes the
      plan's tests do not exercise — the reviewer checks each deliberately), and a pointer to the ledger's
      `Ruling:` lines so it can weigh the calls you made.」
      라이브러리 · 의존을 이름으로 다루는 문장은 없다(grep 0건 — 「re-implements」 는 압축 뒤 과제를 다시 구현하는
      실패를 말하는 문장).
      판 차이: 7.0.0 에는 「Example Workflow」 절이 있고 7.0.1 이 뺐다(RELEASE-NOTES: 「drops its Example Workflow,
      which repeated rules stated above it」). 7.0.2 는 도우미 스크립트를 절대경로로 부르라는 문구를 바꿨다.
    touches: []
    decides: [OQ11]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "7.0.0", latest: "7.0.2"}
    certainty: confirmed

  - url: "https://github.com/obra/superpowers/blob/v7.0.2/skills/verification-before-completion/SKILL.md"
    supports: both
    claim: >
      [설치본 7.0.2 전문 · 2026-07-24 3be5aad 뒤로 그대로] 완료 주장 전에 증거를 요구하는 skill 이다.
      요구 사항 대조에 닿는 줄은 둘: Common Failures 표 「Requirements met | Line-by-line checklist | Tests
      passing」 · Key Patterns 「**Requirements:** ✅ Re-read plan → Create checklist → Verify each → Report gaps or
      completion ❌ "Tests pass, phase complete"」
      라이브러리 · 의존 · 재구현 · 중복을 다루는 문장은 없다(grep 0건).
      본문은 설치본에서 읽었고 이 URL 은 직접 fetch 하지 않았다.
    touches: []
    decides: [OQ11]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "7.0.0", latest: "7.0.2"}
    certainty: confirmed

repo_claims:
  - id: RC1
    path: "plugins/spec-distill/dependencies.md"
    anchor: "| superpowers | 7.0.0 | 2026-10-22 | 알림 | 판이 다르면 알린다. …"
    line: 17
    claim: >
      레포가 적은 superpowers 판은 7.0.0, 잰 날짜 2026-10-22, 강도 「알림」 이다. 판 칸은 「`check_deps.py measure`
      … 가 쓴다 — 손으로 고치지 않는다」(L8). 이 기기 설치본 폴더는
      `/Users/jeonghokim/.claude/plugins/cache/claude-plugins-official/superpowers/7.0.2/` 하나뿐이다 — 적힌 판과
      깔린 판이 다르다(스크립트로는 확인하지 않았다).
    touches: []
    decides: []

  - id: RC2
    path: "plugins/spec-distill/CHANGELOG.md"
    anchor: "superpowers 7.0.0 brainstorming 에 맞췄다: spec-review 의 자리는 brainstorming 이 설계문서 점검(builder check)과 그 질문을 마친 뒤 문서를 승인받는 자리다"
    line: 420
    claim: >
      넘김 줄들은 7.0.0 의 brainstorming 모양에 맞춰 쓰였다고 CHANGELOG 가 적는다: 「넘김 줄은 사용자 선호
      입력(설계문서를 쓰는 크기 · 질문을 건너뛰어도 설계문서와 spec-review)과 확정 항목 되비춤을 싣고, 끝의 쉬운 말
      규칙은 낱말 규칙만 남겨 메시지 모양은 brainstorming 을 따른다.」 7.0.0 brainstorming 에는 대안 · 추천 걸음이
      없다(위 evidence).
    touches: []
    decides: [OQ7]

  - id: RC3
    path: "plugins/spec-distill/references/epic-handoff.md"
    anchor: "**에픽 넘김 줄** — `@<bundle-abs> 이 에픽 묶음으로 Skill superpowers:brainstorming 을 시작하라. …`"
    line: 7
    claim: >
      에픽 넘김 줄이 brainstorming 에 얹는 것 가운데 있는 것 · 외부 것에 닿는 문장은 둘이다.
      (a) 「설계 전에 이 에픽이 닿는 코드 · 문서를 직접 읽어 묶음의 근거가 지금도 맞는지, 빠진 항목 · 이미 고쳐진
      항목이 있는지 꼼꼼히 조사해 ## 있는 것 검토 절에 적는다 — 조사가 다른 에픽이 예약한 파일을 고쳐야 한다고
      보이면 재분해 신호로 보고한다.」
      (b) 「설계문서에 ## 있는 것 검토 절(레포 안에 이미 있는 것을 먼저 찾아 쓰고, 레포 밖 패키지 · 프레임워크 ·
      서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다)과 ## 상류 · 하류 연계 절(…)을 두고, 경로 · 테스트 명령 ·
      기본 브랜치 · 브랜치 이름 · 모델 같은 레포 전용 값은 박지 말고 도출하거나 레포 설정에서 읽게 설계한다.」
      같은 줄의 다른 지시: 「사용자 선호: 이 에픽 설계는 설계문서를 쓰는 크기다 — 질문을 건너뛰어도 설계문서를 쓰고
      spec-review 를 거친다. 묶음의 확정 항목은 다시 묻지 않고 되비춤으로 확인한다.」 · 「confirmed 항목은 근거 있으면
      보고 후 재결정 가능, 임의 변경은 금지.」 · 끝 「메시지 모양(첫 메시지 · 질문 하나 · 되비춤)은 brainstorming 을
      따른다.」
      이 줄에는 대안 · 추천을 가리키는 낱말이 없다(approach · 접근 방식 · 대안 · 추천 · 권장 grep 0건). 계획 ·
      실행 · 마지막 리뷰에 싣는 문장(「writing-plans 가 계획을 쓴 뒤 … check_bundle_coverage.py --plan …」 · 「고른
      실행 방식의 마지막 전체 리뷰(조사 에픽은 산출물의 AC 대조)에 설계문서 ## Acceptance Criteria 의 AC 목록을
      싣고, 리뷰가 AC 마다 한 줄씩 AC1: 구현됨 — 근거 꼴(판정은 구현됨 · 미룸 · 빠짐 중 하나)로 보고하게 해 …」)은
      AC 대조만 말하고 있는 것 검토 절 · 고른 패키지를 다시 가리키지 않는다.
    touches: []
    decides: [OQ7, OQ8, OQ11]

  - id: RC4
    path: "plugins/spec-distill/skills/pm-interview/references/finishing.md"
    anchor: "**다음 세션 줄 — ①/② 공통** — `@<brief-path> 이 interview brief 로 Skill superpowers:brainstorming 을 시작하라. …`"
    line: 553
    claim: >
      brief 의 다음 세션 줄도 같은 괄호 문장을 싣는다: 「설계문서에 ## 있는 것 검토 절(레포 안에 이미 있는 것을 먼저
      찾아 쓰고, 레포 밖 패키지 · 프레임워크 · 서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다)과 ## 상류 · 하류
      연계 절(…)을 두고, …」
      에픽 넘김 줄과 다른 점: 「설계 전에 … 직접 읽어 … 꼼꼼히 조사해 ## 있는 것 검토 절에 적는다」 조사 문장이
      없다. 대신 「설계의 규칙은 「기본은 X, 일의 모양이 다르면 모델이 판단하고 이유를 적는다」로 쓰고 정석 흐름(설계
      → 계획 → 구현)의 의도는 지킨다.」 와 「brief 의 §2 확정 항목뿐 아니라 §3 열린 질문 · §4 조사 · §5 위험을 번호째
      설계의 입력으로 읽는다」 가 있다.
      계획 · 마지막 리뷰 문장은 RC3 과 같은 AC 대조 문장이다.
      왜 줄에 싣는지는 L540-543: 「`superpowers:brainstorming`은 spec-distill을 모르고 brief frontmatter를 읽지
      않습니다 — 전달은 순수 프로즈 경로입니다. 그래서 C4 재결정 프로토콜은 brief 파일이 아니라 **다음 세션 줄**
      (brainstorming 을 부르는 호출 프롬프트)에 싣습니다.」
      둘째 질문에서 다른 단계를 골랐을 때의 줄(L560)이 「이 글자로 싣는다」 는 공통 지시 넷에는 있는 것 검토
      문장이 없다.
    touches: []
    decides: [OQ7, OQ8, OQ11]

  - id: RC5
    path: "plugins/spec-distill/skills/spec-review/SKILL.md"
    anchor: "**다음 세션 줄 — ①/② 공통** — `@<spec_path> 이 설계문서로 Skill superpowers:writing-plans 를 시작하라. …`"
    line: 757
    claim: >
      계획 넘김 줄 전문: 「@<spec_path> 이 설계문서로 Skill superpowers:writing-plans 를 시작하라. confirmed 항목은
      근거 있으면 보고 후 재결정 가능하고 임의 변경은 금지다. 계획을 쓴 뒤 python3
      ${CLAUDE_PLUGIN_ROOT}/scripts/check_bundle_coverage.py --plan <spec_path> 뒤에 계획 경로를 붙여 돌리고, 계획에
      없는 AC 는 계획에 더한다. 고른 실행 방식의 마지막 전체 리뷰에 이 설계문서 ## Acceptance Criteria 의 AC 목록을
      싣고, 리뷰가 AC 마다 한 줄씩 AC1: 구현됨 — 근거 꼴(판정은 구현됨 · 미룸 · 빠짐 중 하나)로 보고하게 해 그 보고를
      git 이 추적하지 않는 파일에 적는다. 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 ## 미룸 표(항목 · 이유 · 받는
      곳)에 올리고, PR 을 만들기 전에 … --impl <spec_path> 뒤에 보고 파일 경로를 붙여 돌려 경고를 사용자에게 보인다.
      사람에게 쓰는 글 규칙(…)을 지킨다.」
      있는 것 검토 절 · 고른 라이브러리 · 프레임워크를 계획에 옮기거나 리뷰에서 보라는 말은 이 줄에 없다. 로드맵
      에픽이면 이 줄이 「계획 agent 의 입력」 으로 지휘자에게 넘어간다(L764 · L766).
    touches: []
    decides: [OQ11, OQ7]

  - id: RC6
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "### 계획 agent (틀)"
    line: 53
    claim: >
      계획 agent 틀이 writing-plans 에 얹는 것: 「흐름: <고른 흐름> — <이유>. 입력: 설계문서 <설계문서 절대경로>. 승인
      게이트가 낸 계획 agent 의 입력 줄: <그 줄 그대로>.」(=RC5 의 줄) · 「계획의 첫 과제는 가벼운 다시 확인이다 —
      설계문서가 근거로 든 자리가 지금 코드에서도 그런지 보고, 달라졌으면 멈춰 보고한다.」 · 「superpowers:writing-plans
      를 단일 세션과 똑같이, 단계를 빼거나 다시 쓰지 말고 끝까지 돈다.」 · 「… check_bundle_coverage.py --plan
      <설계문서> <계획>[ --acs "<이 계획 몫 AC>"] 를 돌려 빠진 AC 를 계획에 더하고 그 첫 줄을 보고한다.」 ·
      「writing-plans 가 끝에 묻는 질문(계획 검토 · 실행 방식)에서 멈추고 (a) … (b) 질문 원문을 함께 돌려보낸다.」
      라이브러리 · 의존 선택이나 있는 것 검토 절을 가리키는 문장은 틀에 없다. 계획 검토는 지휘자 몫이다 —
      conducting.md 걸음 4(L50): 「계획 agent 가 돌아오면 이 세션이 계획을 읽고 「설계에 없던 결정(범위 · 인터페이스 ·
      파일 배치 등)」 이 있는지 가른다 — 계획을 쓴 agent 가 스스로 가르지 않는다.」
    touches: []
    decides: [OQ11, OQ7]

  - id: RC7
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "### 구현 agent (틀) — 「마지막 전체 리뷰는 설계문서 ## Acceptance Criteria 가운데 <이 계획 몫 AC> 를 …」"
    line: 72
    claim: >
      구현 agent 틀이 실행 skill 과 마지막 전체 리뷰에 얹는 것:
      「계획 <계획 레포 상대경로> 를 <writing-plans 가 권한 실행 방식 skill> 로 단일 세션과 똑같이 끝까지 실행한다.」
      「과제 경계마다 바꾼 파일을 코퍼스로 읽는 락까지 넓게 돈다(테스트 안에서 그 파일 이름으로 찾는다) — 전체
      스위트는 잠금 아래 끝에 한 번. 네가 띄우는 과제 구현 agent 에게 보내는 글에도 이 줄을 싣는다.」
      「마지막 전체 리뷰는 설계문서 ## Acceptance Criteria 가운데 <이 계획 몫 AC> 를 AC 마다 한 줄(AC<번호>: 구현됨 |
      미룸 | 빠짐 — 근거)로 보고하게 하고, 과제 사이 이음매(끝에서 끝 흐름 · 종료 코드를 받는 쪽 · 상태 가정)와
      계획이 쓴 테스트 코드도 묻게 한다.」
      「구현 커밋마다 Spec: <설계문서 레포 상대경로> 트레일러.」
      구현 agent 의 입력은 L37: 「입력은 커밋된 계획 경로 · 설계문서 경로 · 미리 받은 답(실행 방식 포함) · 기준
      브랜치뿐이다.」
      마지막 전체 리뷰에 싣는 것은 셋이다 — AC 대조 · 과제 사이 이음매 · 계획이 쓴 테스트 코드. 「고른 라이브러리 ·
      기능을 실제로 썼는가」 나 재구현 · 중복을 묻게 하는 문장은 없다. 과제 리뷰어에게 얹는 글도 스위트 잠금 줄과
      락 범위 줄뿐이다(L15 · L71).
    touches: []
    decides: [OQ11]

  - id: RC8
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### 3. 다음 일 고르기와 보내기 — 「설계 전 조사는 꼼꼼히(`epic-handoff.md` 의 조사 문장 — 있는 것 검토 절에 적고, 다른 에픽이 예약한 파일이면 재분해 신호), 계획의 첫 과제는 가벼운 다시 확인이다」"
    line: 34
    claim: >
      지휘 순환은 brainstorming 에 넘김 줄과 같은 것을 얹는다: 「brainstorming 의 입력과 지시는 같은 폴더
      `epic-handoff.md` 의 에픽 넘김 줄이 싣는 것과 같다 — 그 줄을 사용자에게 주지 않고 이 세션의 입력으로 쓴다.
      brainstorming 대화는 superpowers 의 brainstorming 이 정한 모양(첫 메시지 · 열린 문장 질문 하나 · 되비춤)이고,
      지휘 소식(…)은 그 메시지에 얹지 않는다.」(L35) 손 절차 3(L101)은 싣는 것을 「묶음 첨부 · 번호째 읽기 · 번호 대조
      표 · frontmatter · AC 번호 · 있는 것 검토 · 상류 · 하류 연계 · 레포 전용 값 · 계층 · 온톨로지 · 크기 선호 · 확정
      항목 되비춤」 으로 열거한다. L5: 「superpowers 는 부르기만 하고 고치지 않는다.」
      brainstorming 이 정한 모양을 적은 괄호에 대안 제시 걸음은 없다 — 7.0.0 기준 문장이다(RC2).
    touches: []
    decides: [OQ7, OQ8]

  - id: RC9
    path: "plugins/spec-distill/agents/integration-reviewer.md"
    anchor: "## 볼 이음매 (1~7)"
    line: 46
    claim: >
      머지 전 통합 리뷰어가 보는 것은 에픽 사이 이음매 일곱이다(옮겨진 이름의 import · 같은 파일 순서와 문구 ·
      상태 · 경로 규약 · 합계 제약 · 되살아난 옛 문구와 리뷰어 프로필 완화 · 앞선 인계 · 함께 진행된 에픽의 설계
      의도). 맡지 않는 일: 「You are NOT responsible for re-reviewing each epic's internal correctness」.
      이 PR 자신의 설계문서가 고른 것을 썼는가는 목록에 없다. `intents` 는 「이 PR 과 함께 진행된 다른 에픽들의
      설계문서 전문」 이다.
      틀은 conducting.md L60 · epic-conductor/SKILL.md L173 이 적는다: 「`superpowers:requesting-code-review` 의
      리뷰 요청 틀(`code-reviewer.md`)을 이 PR 로 채운 글 … 틀에서는 무엇을 · 왜 · 범위 칸만 빌려 채운다. … 틀의 출력
      형식은 넣지 않는다」 — superpowers code-reviewer.md 의 「What to Check」 목록은 이 리뷰어의 점검 목록이 아니다.
    touches: []
    decides: [OQ11]

  - id: RC10
    path: "plugins/spec-distill/references/docreview-profiles/design-doc.md"
    anchor: "`approaches_comparison` — 대안 비교 없이 단정된 선택. Rejected Alternatives 의 각 대안이 채택안과 같은 기준으로 비교됐는가"
    line: 104
    claim: >
      주문이 열거한 자리 밖이지만 같은 흐름의 설계문서 리뷰 자리에 닿는 문장 둘이 있다.
      (a) 층 2 항목 `approaches_comparison`(L16 · L104).
      (b) 과설계 사다리 L73-77: 「1. 이 구조가 있어야 하나 … 2. 이미 리포에 있는 원칙·메커니즘으로 되나 3. 이미 있는
      하니스 표면(프로필 필드 · 처분 · 락 · 훅)으로 되나 4. 한 줄 규약으로 되나 5. 그제서야 새 메커니즘」 — 「이 축은
      과설계 **경고**다」(L79).
      같은 흐름의 `agents/doc-critic-web.md` L60: 웹은 「더 나은 대안이 이미 있는가(성숙한 라이브러리 · 확립된 패턴 ·
      출시된 도구 · 문서화된 접근)」 를 따질 때 쓴다.
      `## 있는 것 검토` 라는 절 이름을 읽는 스크립트 · 리뷰 프로필은 찾지 못했다. plugins/ 안에서 이 낱말이 나오는
      곳은 넘김 줄 둘, conducting.md, README, 그리고 넘김 줄 문구를 핀 하는 테스트 넷(test_epic_handoff.sh ·
      test_end_gates.sh · test_parallel_recommend_docs.sh · test_review_handoff_order.sh)뿐이다(CHANGELOG 제외
      grep, 숨김 폴더 · 링크는 보지 못한다).
    touches: []
    decides: [OQ11, OQ8]

unanswered: >
  (1) v7.0.0 · v7.0.1 의 전문은 통째로 받지 못했다 — 조각 인용이고 줄바꿈 · 굵은 표시는 확인하지 못했다.
  (2) brainstorming/SKILL.md · subagent-driven-development/SKILL.md 의 commits 페이지와 v7.0.0...v7.0.2 compare 의
  파일 목록은 잘려서 못 읽었다 — 이 두 파일의 판 사이 차이는 태그별 본문 대조와 RELEASE-NOTES 로만 확인했다.
  (3) builder-check-prompt.md · re-review-prompt.md · references/fix-loop.md 의 7.0.0 판은 읽지 않았다.
  (4) 설치본이 레포가 적은 판과 다르다는 것은 check_deps.py 로 확인하지 않았다.
  (5) 얹은 지시가 실제 세션에서 brainstorming 의 추천 방향을 바꾸는지는 문서만으로 답할 수 없다 — 실행 관찰이 필요하다.
```

## 읽은 파일

레포(루트 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first`):
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/dependencies.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/epic-handoff.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/conductor-dispatch.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/conducting.md` (L30-68, L97-114)
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/skills/pm-interview/references/finishing.md` (L436-570)
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/skills/spec-review/SKILL.md` (L735-774)
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/skills/epic-conductor/SKILL.md` (L165-179)
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/agents/integration-reviewer.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/docreview-profiles/design-doc.md` (L70-79, L104)
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/agents/doc-critic-web.md` (L56-63)

superpowers 7.0.2 설치본(레포 밖, 루트 `/Users/jeonghokim/.claude/plugins/cache/claude-plugins-official/superpowers/7.0.2`):
- `RELEASE-NOTES.md` (L1-160)
- `skills/brainstorming/SKILL.md` · `skills/brainstorming/builder-check-prompt.md`
- `skills/writing-plans/SKILL.md`
- `skills/subagent-driven-development/SKILL.md` · `task-reviewer-prompt.md` · `implementer-prompt.md` · `re-review-prompt.md` · `references/final-review.md` · `references/preflight.md`
- `skills/executing-plans/SKILL.md`
- `skills/requesting-code-review/SKILL.md` · `code-reviewer.md`
- `skills/verification-before-completion/SKILL.md`
- `skills/using-superpowers/SKILL.md`

웹(1차):
- https://github.com/obra/superpowers/tags · https://github.com/obra/superpowers/releases
- https://github.com/obra/superpowers/compare/v7.0.2...main
- https://raw.githubusercontent.com/obra/superpowers/main/.claude-plugin/plugin.json
- `https://raw.githubusercontent.com/obra/superpowers/<태그>/skills/…` — v7.0.0: brainstorming · writing-plans · subagent-driven-development(SKILL.md · task-reviewer-prompt.md) · executing-plans / v7.0.1: brainstorming / v7.0.2: brainstorming
- `https://github.com/obra/superpowers/commits/main/skills/…` 의 파일별 이력


### 조사 8 — open-researcher · R5 · 묶음 3

조사 결과 — 과거 설계문서 셋이 직접 만든 것과, 설계 날짜에 있던 외부 후보. 확인한 날은 전부 2026-11-15. 판정은 하지 않았고 사실만 나란히 두었다.

읽은 설계문서(절대경로):
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-20-dependency-portability-design.md (R8)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md (R12)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-23-r8-device-leftovers-design.md (R14)

## 일 단위 요약 (설계문서 → 만든 것 → 찾은 후보)

R8 (2026-10-20)
- 일 A 값 해결자: `.devbrew.md` 머리말을 기본 브랜치 판에서 읽고, 층 넷 · 닫힌 키 · 출처 표시 · 엄격 파서. 후보: `git config --blob` + `--show-origin`, Claude Code `userConfig`, PyYAML 계열(python-frontmatter · strictyaml), Renovate(설계가 방식만 차용).
- 일 B 기본 브랜치 도출 · 두 출처 대조: 후보: git `fetch.followRemoteHEAD` / `remote.<name>.followRemoteHEAD` 의 `warn` · `always`.
- 일 C squash · rebase 머지 판정: 후보: gh-poi, git-delete-merged-branches, git-machete, gh-stack.
- 일 D 의존 선언 파일 · 판 재기 · 진입 확인: 후보: Claude Code plugin.json `dependencies`(설계가 기각), `packaging`, mise, `claude plugin list --json`.
- 일 E gh 대상 레포 고정(`-R` 도출): 후보: `gh repo set-default`.
- 일 F 상태 루트 자기 무시: 후보: `${CLAUDE_PLUGIN_DATA}`.
- 일 G project-init 훅의 새 브랜치 이름 관찰: 후보: Claude Code `WorktreeCreate` 훅, git `reference-transaction` · `post-checkout` 훅, pre-commit-hooks `no-commit-to-branch`.

R14 (2026-10-23)
- 일 H 에픽 PR 번호 기록 + 번호로 머지 판정(`ledger pr-record`, `## 에픽 PR`): 후보: gh-stack, Claude Code 세션-PR 연결(`--from-pr` · agent view PR 상태), ccpm, git-spice.
- 일 I 폴더 값의 pathspec 특수 글자 거부: 후보: `GIT_LITERAL_PATHSPECS` / `--literal-pathspecs`(설계가 기각).
- 일 J 콜론 없는 머리말 줄 · 같은 키 거부: 후보: 일 A 의 YAML 계열과 같다.
- 일 K 다음 세션의 superpowers 판 확인: 후보: `claude plugin list --json`, plugin.json `dependencies`.
- 일 L `put_snap` 서브셸 실패 수: 후보: ShellCheck SC2031, bats-core.

R12 (2026-10-20)
- 일 M `</related_changes>` 주입 이스케이프: 후보: Django `json_script`, simplejson `JSONEncoderForHTML`.
- 일 N qg 판정 id(요약 지문): 후보: SARIF 2.1.0 `fingerprints` · `partialFingerprints`(표준).
- 일 O codex 가 검토 트리 AGENTS.md 를 읽지 않게: 후보: codex `project_doc_max_bytes`(설계가 「계획이 실측」으로 남긴 자리).
- 일 P 원장 쓰기 순서 락을 산문까지: 후보: Vale `conditional`.

찾지 못함 / 찾지 않음
- R12 §2 불변 절 「새 항목만 추가」 판정: WebSearch `markdown linter "append-only" section check CI changelog entries only appended not modified tool` → hallmark · changelog-linter 류(문체 · 형식 검사)만 나왔고 이전 판과 대조하는 도구는 찾지 못함.
- R14 일 H 전체를 덮는 Claude Code 플러그인: WebSearch `Claude Code plugin roadmap epic orchestrator tracks pull request number merged status "squash" statusline plugin marketplace` → 해당 결과 없음(부분 후보만 위에 적음).
- 검색하지 않은 일(레포 내부 불변식이라 바깥 낱말을 정하지 못함): R12 §3 재비판 흡수의 막는 목록 합치기 · §4 보호 계보 · finalize 멱등 · 닫힌 뒤 결정 줄 · §7 「다시 읽지 않기」 · worktree 세션 결속 · §8 kill switch 정규식 · `check_wiring` 키 · 호출 표면 락, R14 §3 공시 문장 · §4 락 지도 단언 · §5 (3) 레포 설정 같은 키, R8 §7 쓰는 세션 신뢰(설계가 Claude Code 샌드박스 · 훅을 이미 인용) · §9 작업공간 불변 락.

```yaml
evidence:
  # ── R8 일 A: 값 해결자 ──
  - url: "https://git-scm.com/docs/git-config"
    supports: alternative
    claim: "(a) git config `--blob` · `--show-origin` · `--show-scope` (git 내장). (b) 덮는 것: 임의 ref 의 blob 에서 설정을 읽기(원문 「Similar to --file but use the given blob instead of a file. E.g. you can use master:.gitmodules to read values from the file .gitmodules in the master branch」), 값마다 출처 표시(원문 「origin type (file, standard input, blob, command line) and the actual origin」). 못 덮는 것: 문서에 닫힌 키 집합 · 층별 허용 키 · 모르는 키 거부 · 로드맵/기계 상태 층 병합은 없다. 파일 형식이 git config 문법이라 설계의 마크다운 머리말(`.devbrew.md`)과 다르다. (c) git 프로젝트, 문서 판 2.56.1. `--blob` 이 처음 들어온 판은 이번에 확인하지 못했다. (d) git 은 이미 런타임 의존이라 새 설치는 없다. 설정 파일 형식을 바꾸는 일이 붙는다."
    touches: []
    decides: [OQ8, OQ9]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "git 2.54.0 (plugins/spec-distill/dependencies.md, 잰 날 2026-10-22)", latest: "2.56.1 (문서 페이지 표기)"}
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/plugins-reference"
    supports: both
    claim: "(a) Claude Code plugin.json `userConfig`. (b) 값 저장: 원문 「Non-sensitive values are saved under pluginConfigs in the user's settings.json」. 닿는 곳: 원문 「${user_config.KEY}: substituted in MCP server config, LSP server config, exec-form hook args, and skill and agent content」 · 「CLAUDE_PLUGIN_OPTION_<KEY>: exported to hook processes for every option」. 경로 변수에 대해 원문 「The variables aren't present in the environment of commands Claude runs through the Bash tool」. (c) Anthropic 공식 문서. `options` 는 v2.1.271 이상 등 판 조건이 붙은 칸이 있다. (d) R8 설계의 기각 사유 원문은 「레포 단위로 둘 수 없고 Bash 명령 환경에 없다」 — 오늘 문서에는 skill · agent 본문 치환 길이 적혀 있다(설계 날짜에 그 길이 있었는지는 확인하지 못했다)."
    touches: []
    decides: [OQ8, OQ9]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "claude-code 2.1.303 (dependencies.md, 기록만)", latest: "미확인"}
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/settings-reference"
    supports: current
    claim: "`pluginConfigs` 의 설정 범위 칸은 색인 표에 「User or managed」 로 적혀 있다(프로젝트 · 로컬 설정은 그 칸에 없다). 상세 항목은 페이지가 잘려 읽지 못했다. R8 기각 사유 「레포 단위로 둘 수 없고」 와 같은 방향의 사실이다."
    touches: []
    decides: [OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain
  - url: "https://pypi.org/pypi/python-frontmatter/json"
    supports: alternative
    claim: "(a) python-frontmatter (PyPI). (b) 덮는 것: YAML 머리말 파싱. 못 덮는 것: 닫힌 키 · 층 · 출처 · 기본 브랜치 판 읽기는 패키지 범위가 아니다. (c) 작성자 Chris Amico, MIT, 첫 릴리스 0.1.0 2014-09-15, 최신 1.3.0 2026-05-20 — 설계 날짜(2026-10-20)에 있었다. (d) `requires_python >=3.10` 이고 pyyaml 에 의존한다 — 레포가 적은 python 바닥은 3.9.6 이고 런타임 의존은 표준 라이브러리다(서드파티 설치 길이 새로 붙는다)."
    touches: []
    decides: [OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "쓰지 않음(python 3.9.6 표준 라이브러리만)", latest: "1.3.0"}
    certainty: confirmed
  - url: "https://pypi.org/pypi/strictyaml/json"
    supports: alternative
    claim: "(a) strictyaml (PyPI). (b) 덮는 것: 원문 「StrictYAML is a type-safe YAML parser that parses and validates a restricted subset of the YAML specification」 — 스키마 검증 · 중복 키 금지 항목이 설명 목차에 있다(금지 문장 자체는 확인하지 못함). 못 덮는 것: 머리말 구분(`---`) 처리 · 층 · 출처. (c) Colm O'Connor, MIT, 첫 릴리스 0.1 2016-06-19, 최신 1.7.3 2023-03-10(그 뒤 릴리스 없음). (d) `requires_python >=3.7`, python-dateutil 의존 — 서드파티 설치 길이 붙는다."
    touches: []
    decides: [OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "쓰지 않음", latest: "1.7.3"}
    certainty: confirmed
  - url: "https://docs.renovatebot.com/configuration-options/"
    supports: current
    claim: "Renovate 문서 원문 「Renovate always uses the config from the repository's default branch」. R8 설계 §1 과 `## 있는 것 검토` 가 「방식만 차용」 이라 적은 근거가 지금도 문서에 있다."
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  # ── R8 일 B: 기본 브랜치 ──
  - url: "https://git-scm.com/docs/git-fetch"
    supports: both
    claim: "(a) git `fetch.followRemoteHEAD`(원격별은 `remote.<name>.followRemoteHEAD`, 추가 값 `warn-if-not-$branch`). (b) 덮는 것: 값 `warn` — 원문 「Display a warning if the remote advertises a different HEAD than what is set locally」, 값 `always` — 원문 「Silently update remotes/<name>/HEAD whenever the remote advertises a new value」. 기본값 `create` — 원문 「An existing symbolic-ref will not be touched」(R8 설계 Context 가 인용한 문장과 같다). 못 덮는 것: fetch 때만 돌고(오프라인 · fetch 없는 진입에는 없음), 경고이지 멈춤이 아니며, 사용자 git 설정을 바꿔야 켜진다. (c) git 프로젝트, 문서 판 2.56.0/2.56.1. (d) git 은 이미 의존. 플러그인이 사용자 레포의 git 설정을 쓰는 일이 붙는다. R8 설계는 기본값 문장만 인용했고 `warn` · `always` 값은 문서에 없다(레포 grep)."
    touches: []
    decides: [OQ8, OQ9, OQ10]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "git 2.54.0", latest: "2.56.1"}
    certainty: confirmed
  - url: "https://www.kernel.org/pub/software/scm/git/docs/RelNotes/2.48.0.adoc"
    supports: alternative
    claim: "git 2.48.0 릴리스 노트에 `git fetch` 가 `remote.<remote>.followRemoteHEAD` 설정을 따른다는 항목이 있다(검색 요약으로 확인, 본문 직접 읽기는 하지 않음) — 설계 날짜보다 앞선다. 전역 키 `fetch.followRemoteHEAD` 가 들어온 판은 확인하지 못했다."
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain

  # ── R8 일 C: squash · rebase 머지 판정 ──
  - url: "https://github.com/seachicken/gh-poi"
    supports: alternative
    claim: "(a) gh-poi (gh 확장, seachicken). (b) 덮는 것: README 가 squash 머지는 기본 브랜치에 머지 이력이 없다고 적고, PR 상태와 로컬 브랜치의 커밋을 대조해 머지된 브랜치를 가린다(`--state (closed|merged)`, `--scan (quick|deep)`, `--dry-run`). 못 덮는 것: 목적이 로컬 브랜치 삭제다 — 기계가 읽는 판정 출력은 README 에 없고, base 브랜치 · 교차 레포 · mergeCommit 도달 조건이나 네트워크 없는 캐시 판정은 적혀 있지 않다. (c) 개인 유지, MIT, 별 약 1.0k, v0.1.0 2021-10-24(pkg.go.dev, 검색 요약), 최신 v0.18.7 2026-11-14 — 설계 날짜에 있었다. (d) `gh extension install` 로 사용자가 확장을 따로 깔아야 한다."
    touches: []
    decides: [OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "쓰지 않음(gh 2.88.1 본체만)", latest: "v0.18.7"}
    certainty: confirmed
  - url: "https://pypi.org/pypi/git-delete-merged-branches/json"
    supports: alternative
    claim: "(a) git-delete-merged-branches (PyPI). (b) 덮는 것: `git cherry` 기반으로 rebase 머지 · squash 머지(`--effort=3` 필요, PyPI 설명 · 검색 요약)를 사실상의 머지로 탐지 — gh 없이 git 만으로. 못 덮는 것: 브랜치 삭제 도구이고 PR 번호 · base · fork 구분은 없다. (c) hartwork, GPLv3+, 첫 릴리스 1.0.0 2020-07-22, 최신 7.7.0 2026-10-13 — 설계 날짜에 있었다. (d) `requires_python >=3.10`, colorama · prompt-toolkit 의존 — 레포 python 바닥 3.9.6 과 다르고 서드파티 설치가 붙는다."
    touches: []
    decides: [OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "쓰지 않음", latest: "7.7.0"}
    certainty: confirmed
  - url: "https://github.com/VirtusLab/git-machete"
    supports: alternative
    claim: "(a) git-machete. (b) 덮는 것: README 원문 「The config option git config machete.squashMergeDetection simple usually works well for this, but isn't perfect」 · `exact` 모드, `git machete github create-pr` · `checkout-prs`. 못 덮는 것: 브랜치 배치(`.git/machete`)를 사람이 관리하는 도구이고, PR 번호를 어디에 두는지는 README 에서 확인하지 못했다. (c) VirtusLab, MIT, 별 약 1.1k, PyPI 에서 보인 가장 이른 릴리스 2.11.2 2019-10-28, 최신 3.46.1 — 설계 날짜에 있었다. (d) `requires_python >=3.6`, 의존 없음. pip · brew 등으로 따로 설치. 비공개 레포 · create-pr 에는 GitHub API 토큰이 필요하다고 README 가 적는다."
    touches: []
    decides: [OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "쓰지 않음", latest: "3.46.1"}
    certainty: uncertain

  # ── R8 일 D · R14 일 K: 의존 선언 · 판 확인 ──
  - url: "https://code.claude.com/docs/en/plugin-dependencies"
    supports: both
    claim: "(a) Claude Code plugin.json `dependencies`(semver 범위 `~2.1.0` · `^2.0` · `>=1.4`). (b) 덮는 것: 다른 «플러그인» 의존의 선언 · 설치 · 판 범위 검사. 못 덮는 것: 선택 의존 개념이 문서에 없다 — 원문 「the dependent plugin is disabled if the installed version doesn't satisfy it」 · 「your plugin stops loading whenever the local copy is disabled or absent」. python · git · gh 같은 외부 도구의 판은 대상이 아니다(매니페스트 필드 표에 그런 필드가 없다). (c) Anthropic 공식. R8 설계가 2026-10-20 에 같은 문서를 인용해 기각했다(원문 사유: 「의존이 없거나 판이 맞지 않으면 플러그인 전체를 끄기 때문에 … U6 의 「없어도 인터뷰는 brief 까지」가 깨진다」) — 오늘 문서도 같은 동작을 적는다. (d) 추가 설치 없음."
    touches: []
    decides: [OQ8, OQ9]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "claude-code 2.1.303", latest: "미확인"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/cli-reference"
    supports: alternative
    claim: "(a) `claude plugin list --json`. (b) 덮는 것: 설치된 플러그인마다 객체 하나, 원문 「id, version, scope, enabled, and installPath are always present」 — 설치된 superpowers 의 판을 기계 출력으로 준다. 레포가 지금 쓰는 길은 불러온 skill 기준 폴더 경로에서 판을 뽑는 것이다(repo_claims RC6). 못 덮는 것: 세션 «안» 에서 실제로 불러온 판과 같은지는 문서가 말하지 않는다. `--plugin-dir` 로 실은 플러그인은 따로 표시된다. (c) Anthropic 공식. `list --json` 에는 판 조건 표기가 없다(다른 하위 명령의 `--json` 은 v2.1.268 이상). 설계 날짜에 있었는지는 확인하지 못했다. (d) `claude` 실행 파일을 Bash 로 부르는 일이 붙는다(지금 의존 표의 claude-code 는 「기록만」)."
    touches: []
    decides: [OQ8, OQ9]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "claude-code 2.1.303", latest: "미확인"}
    certainty: uncertain
  - url: "https://pypi.org/pypi/packaging/json"
    supports: alternative
    claim: "(a) packaging (PyPI, `packaging.version`). (b) 덮는 것: PEP 440 판 문자열 파싱 · 비교. 못 덮는 것: `2.54.0 (Apple Git-157)` 같은 도구 출력에서 판을 뽑는 일, 의존 표 · 진입 멈춤은 범위 밖. (c) PyPA(소유자 brettcannon · dstufft · pf_moore · pradyunsg), Apache-2.0 OR BSD-2-Clause, 첫 릴리스 14.0 2014-09-05, 최신 26.3 2026-08-04 — 설계 날짜에 있었다. (d) `requires_python >=3.9`, 의존 없음. 그래도 표준 라이브러리가 아니라 사용자 환경에 설치돼 있어야 한다. 레포 구현은 정규식으로 숫자 셋을 뽑는다(RC6)."
    touches: []
    decides: [OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "쓰지 않음", latest: "26.3"}
    certainty: confirmed
  - url: "https://mise.jdx.dev/configuration.html"
    supports: alternative
    claim: "(a) mise (`mise.toml` `[tools]`). (b) 덮는 것: 프로젝트가 요구하는 도구 판을 커밋된 파일로 선언(원문 「Tool versions and per-tool options」 · 「Shared project config」), `min_version` 은 mise 자신의 최소 판. 못 덮는 것: gh · git 을 다루는지는 이 페이지에서 확인하지 못했다. 플러그인이 «설치된 레포»마다 mise.toml 을 두게 하는 일이 된다. (c) 유지 상태 · 릴리스 날짜는 이번에 확인하지 않았다. (d) 사용자가 mise 를 따로 깔아야 한다."
    touches: []
    decides: [OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain

  # ── R8 일 E: gh 대상 레포 ──
  - url: "https://cli.github.com/manual/gh_repo_set-default"
    supports: alternative
    claim: "(a) `gh repo set-default`(gh 내장). (b) 덮는 것: 원문 「This command sets the default remote repository to use when querying the GitHub API for the locally cloned repository」 — fork 클론에서 gh 가 부모 레포를 고르는 문제의 gh 쪽 답. 못 덮는 것: 클론마다 사용자가 한 번 정해야 하는 상태다. `GH_REPO` · `GH_HOST` 환경 변수와의 우선순위, 저장 위치는 이 페이지에 없다. (c) GitHub CLI 공식. 들어온 판은 확인하지 못했다. (d) gh 는 이미 의존. R8 설계는 호출마다 `-R <host>/<owner>/<repo>` 를 origin URL 에서 도출하는 길을 골랐고 `set-default` 는 문서에 나오지 않는다(레포 grep)."
    touches: []
    decides: [OQ8, OQ9, OQ10]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "gh 2.88.1", latest: "미확인"}
    certainty: uncertain

  # ── R8 일 F: 상태 폴더 ──
  - url: "https://code.claude.com/docs/en/plugins-reference"
    supports: alternative
    claim: "(a) `${CLAUDE_PLUGIN_DATA}`. (b) 덮는 것: 원문 「~/.claude/plugins/data/<id>/, created on first reference and kept across plugin updates」 — 레포 작업 트리 밖이라 git 추적 문제가 생기지 않는 플러그인 상태 자리. 못 덮는 것: 사용자 단위 폴더라 레포 · 로드맵마다 가르는 일은 플러그인 몫이다. 원문 「The variables aren't present in the environment of commands Claude runs through the Bash tool」 — skill 본문 치환이나 훅 환경으로만 닿는다. 플러그인을 지우면 기본으로 삭제된다(원문 「deletes the ${CLAUDE_PLUGIN_DATA} directory when you uninstall the plugin from the last place it's installed」). (c) Anthropic 공식. 들어온 판 · 설계 날짜의 실재는 확인하지 못했다. (d) 추가 설치 없음. CLAUDE.md 의 「런타임 state 는 `.claude/<plugin>/` 하위」 규칙과 자리가 다르다."
    touches: []
    decides: [OQ8, OQ9]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "claude-code 2.1.303", latest: "미확인"}
    certainty: uncertain

  # ── R8 일 G: 새 브랜치 이름 관찰 ──
  - url: "https://code.claude.com/docs/en/hooks"
    supports: both
    claim: "(a) Claude Code `WorktreeCreate` 훅 이벤트. (b) 발화: 원문 「Claude creates a worktree during a session and switches into it with the EnterWorktree tool」 · `--worktree` · `isolation: \"worktree\"` 등. 못 덮는 것: 관찰자가 아니다 — 원문 「Configuring a WorktreeCreate hook replaces that default git behavior」 · 「The hook must return the path to the created worktree directory」. 입력은 `name`(슬러그)뿐이다. 원문 「A WorktreeCreate hook doesn't run for a worktree Claude adds through Bash」. 플러그인 훅은 원문 「Before v2.1.300, a plugin's WorktreeCreate hook didn't run with --worktree alone either」. (c) Anthropic 공식. v2.1.300 이전부터 있던 이벤트로 읽힌다(레포가 잰 판 2.1.303, 2026-10-22). (d) 추가 설치 없음. R8 설계는 PostToolUse matcher 를 `Bash|EnterWorktree` 로 넓히는 길을 골랐고 `WorktreeCreate` 는 문서에 나오지 않는다(레포 grep). PostToolUse 가 EnterWorktree 에 실제로 불리는지는 문서의 읽은 구간에 없었다."
    touches: []
    decides: [OQ8, OQ9, OQ10]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "claude-code 2.1.303", latest: "미확인"}
    certainty: confirmed
  - url: "https://git-scm.com/docs/githooks"
    supports: alternative
    claim: "(a) git `reference-transaction` 훅 · `post-checkout` 훅(git 내장). (b) 덮는 것: 원문 「This hook is invoked by any Git command that performs reference updates」, stdin 줄 `<old-value> SP <new-value> SP <ref-name> LF`, 새로 만드는 ref 는 old 가 all-zero — 명령 표기(`worktree add -b` · `branch -m` · `switch -c`)와 무관하게 ref 생성을 본다(명령별 확인은 문서에 없다). `post-checkout` 은 `git worktree add` 뒤에도 돈다. 못 덮는 것: 레포마다 `.git/hooks` 에 사용자가 설치해야 하고(`core.hooksPath`), Claude Code 세션에 알림을 돌려줄 길은 git 훅에 없다. (c) git 프로젝트. 들어온 판은 확인하지 못했다. (d) git 은 이미 의존. 사용자 레포의 git 훅 폴더를 건드리는 일이 붙는다."
    touches: []
    decides: [OQ8, OQ9]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "git 2.54.0", latest: "2.56.1"}
    certainty: uncertain
  - url: "https://github.com/pre-commit/pre-commit-hooks"
    supports: alternative
    claim: "(a) pre-commit-hooks `no-commit-to-branch`. (b) 덮는 것: 원문 「Protect specific branches from direct checkins」 · 「Both main and master are protected by default if no branch argument is set」 · `--pattern` 정규식 — 「기본 브랜치에 직접 커밋하지 않는다」 쪽. 못 덮는 것: 새 브랜치 이름이 규칙에 맞는지 알리는 일은 아니다(커밋 시점 검사). (c) pre-commit 프로젝트, 별 약 6.8k, README 예시의 rev 는 v6.0.0. 최신 릴리스 날짜는 확인하지 못했다. (d) 사용자가 pre-commit 프레임워크를 깔고 레포에 `.pre-commit-config.yaml` 을 둬야 한다."
    touches: []
    decides: [OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain

  # ── R14 일 H: 에픽 PR 번호 기록 ──
  - url: "https://github.com/github/gh-stack"
    supports: alternative
    claim: "(a) gh-stack (`gh stack`, GitHub 공식 gh 확장). (b) 덮는 것: 브랜치마다 PR 을 만들고 PR 메타데이터를 `<common-dir>/gh-stack` JSON 에 둔다(커밋되지 않음 · 연결된 worktree 가 공유) — 「이 기계에만 두는 브랜치→PR 기록」 이라는 점이 R14 의 `## 에픽 PR` 과 같은 모양이다. 머지된 PR 을 `rebase` · `sync` 가 알아본다. `link` 가 base 가 어긋난 PR 을 고친다. 못 덮는 것: 단위가 스택이지 로드맵 에픽이 아니다. 그 JSON 의 형식 안정성 · 외부 도구가 읽어도 되는지는 README 에 없다. squash 머지를 따로 다루는 문장은 없다. (c) GitHub, MIT, 별 약 1.8k, 최신 v0.3.0 2026-10-26, 페이지에서 보인 가장 이른 릴리스 v0.0.4(5월 15일, 해 표기 없음). (d) `gh extension install github/gh-stack` 가 붙고, 판 번호가 0.x 다."
    touches: []
    decides: [OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "쓰지 않음(gh 2.88.1 본체만)", latest: "v0.3.0"}
    certainty: confirmed
  - url: "https://github.blog/changelog/2026-07-30-stacked-pull-requests-are-now-in-public-preview/"
    supports: alternative
    claim: "GitHub stacked pull requests 는 2026-07-30 에 public preview 로 전 레포에 풀리기 시작했다 — R14 설계 날짜(2026-10-23)보다 앞선다. 아래층이 머지되면 위 PR 이 「automatically rebase and retarget」 한다(R14 §2 의 「쌓인 PR 의 바탕을 기본 브랜치로 바꾼 직후 번호를 적는다」 걸음과 닿는 동작). private preview 2026-04-13 은 2차 자료(InfoQ · The Register), GA 2026-10-06 은 블로그 한 곳만의 주장이라 확인되지 않았다."
    touches: []
    decides: [OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/agent-view"
    supports: alternative
    claim: "(a) Claude Code 의 세션-PR 연결 · PR 상태 표시(내장). (b) 덮는 것: Claude 가 `gh pr create` 로 PR 을 열면 세션에 그 PR 을 잇고(「links the pull request that the command's own output names」), 색으로 상태를 보인다(Purple = Merged). `claude --from-pr <번호>` 로 그 세션을 찾는다. 못 덮는 것: 문서에 그 연결을 스크립트 · 훅 · 상태줄로 내보내는 길이 없다(`claude agents --json` 필드에 PR 이 없다). 에픽 단위가 아니라 세션 단위다. `gh pr merge` 는 출력이 없어 연결을 만들지 않는다고 적혀 있다. (c) Anthropic 공식. v2.1.122 릴리스 노트(2026 18주차)가 PR URL 로 세션 찾기를 적는다(검색 요약) — 설계 날짜보다 앞선다. (d) 추가 설치 없음. 기계가 읽을 출력이 없어 머지 판정 입력으로는 문서상 쓸 길이 없다."
    touches: []
    decides: [OQ8, OQ9]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "claude-code 2.1.303", latest: "미확인"}
    certainty: confirmed
  - url: "https://github.com/automazeio/ccpm"
    supports: alternative
    claim: "(a) ccpm (Agent Skill). (b) 덮는 것: PRD → 에픽 → 작업 → GitHub 이슈, 작업 파일을 이슈 번호로 개명(원문 「renamed to {issue-id}.md (e.g. 1234.md). Issue #1234 = file 1234.md」), `.claude/epics/<feature>/` 에 둠. 못 덮는 것: PR 번호 기록 · 머지 판정 조건은 README 에 없다(이슈 번호 기준). (c) automazeio, MIT, 별 약 8.4k, 커밋 92. 최신 커밋 · 첫 릴리스 날짜는 페이지에서 확인하지 못했다(설계 날짜의 실재 미확인). (d) git · gh(인증) 필요, `gh-sub-issue` 확장은 선택, bash 스크립트 15개. 설치는 skill 폴더를 가리키는 방식."
    touches: []
    decides: [OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain
  - url: "https://abhinav.github.io/git-spice/guide/internals/"
    supports: alternative
    claim: "(a) git-spice. (b) 브랜치 추적 정보를 로컬 ref `refs/spice/data` 에 JSON 으로 둔다. PR 번호가 그 안에 있는지 · 머지 탐지는 이 페이지에서 확인하지 못했다. (c)(d) 유지 상태 · 릴리스 날짜 · 설치 조건은 이번에 확인하지 않았다."
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain
  - url: "https://cli.github.com/manual/gh_pr_view"
    supports: current
    claim: "`gh pr view [<number> | <url> | <branch>] --json` 의 필드에 `mergeCommit` · `mergedAt` · `state` · `headRefOid` · `isCrossRepository` · `baseRefName` 이 있다 — R14 `## 있는 것 검토` 의 「레포 밖: gh pr view <번호> --json」 과 레포 구현(RC8)이 쓰는 필드가 공식 문서에 실재한다."
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "gh 2.88.1", latest: "미확인"}
    certainty: confirmed

  # ── R14 일 I: pathspec ──
  - url: "https://git-scm.com/docs/git"
    supports: both
    claim: "(a) `GIT_LITERAL_PATHSPECS` / `--literal-pathspecs`, `GIT_NOGLOB_PATHSPECS` / `--noglob-pathspecs`(git 내장). (b) 원문 「Treat pathspecs literally (i.e. no globbing, no pathspec magic)」 · 「You might want this if you are feeding literal paths to Git」. `--noglob-pathspecs` 는 개별 pathspec 에 `:(glob)` 로 글롭을 되살릴 수 있다고 적는다. (c) git 프로젝트. (d) git 은 이미 의존. R14 설계의 기각 사유 원문: 「폴더 값을 쓰는 git 호출마다 --literal-pathspecs — spec-review 의 *-design.md 처럼 일부러 쓰는 글롭이 깨지고, 호출 자리마다 사본이 생긴다」. 설계문서에 `--noglob-pathspecs` + `:(glob)` 조합과 환경 변수 꼴은 나오지 않는다(레포 grep)."
    touches: []
    decides: [OQ8, OQ9, OQ10]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "git 2.54.0", latest: "2.56.1"}
    certainty: confirmed

  # ── R14 일 L: 셸 테스트 ──
  - url: "https://www.shellcheck.net/wiki/SC2031"
    supports: alternative
    claim: "(a) ShellCheck SC2031 「var was modified in a subshell. That change might be lost.」. (b) 서브셸에서 바뀐 변수가 바깥에 남지 않는 부류를 정적으로 잡는다 — 위키가 명령 치환도 서브셸 구문으로 든다. `put_snap` 꼴(`$(…)` 안에서 실패 수를 올림)을 실제로 보고하는지는 확인하지 못했다(위키 원문 「shellcheck may not warn about all of them」). (c) 유지 상태 · 릴리스는 이번에 확인하지 않았다. (d) 개발 때만 쓰는 도구라 사용자 환경 런타임에는 붙지 않는다. 개발 환경에 shellcheck 설치가 붙는다."
    touches: []
    decides: [OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain
  - url: "https://github.com/bats-core/bats-core"
    supports: alternative
    claim: "(a) bats-core (Bash 테스트 프레임워크). (b) 원문 「Bats makes use of Bash's errexit (set -e) option when running test cases」 — 실패 수를 손으로 세지 않는 구조. `$(…)` 안 실패를 잡는지는 페이지에서 확인하지 못했다. (c) MIT, 별 약 6.4k, 릴리스 날짜 미확인. (d) 개발 때만 쓰는 도구. 레포의 기존 셸 테스트(`cases.sh` 꼴)를 옮겨 적는 일이 붙는다."
    touches: []
    decides: [OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain

  # ── R12 일 M: 슬롯 주입 이스케이프 ──
  - url: "https://docs.djangoproject.com/en/stable/ref/templates/builtins/"
    supports: alternative
    claim: "(a) Django `json_script` 필터. (b) 원문 「XSS attacks are mitigated by escaping the characters \"<\", \">\" and \"&\"」 — JSON 유니코드 이스케이프(`\\u003C` · `\\u003E` · `\\u0026`)로 바꾼다. R12 §2 가 고른 방법(`\\u003c` · `\\u003e` · `\\u0026`)과 같은 기법이다. 못 덮는 것: `<script>` 태그로 감싸 내는 필터라 그대로는 쓸 수 없다. (c) Django 프로젝트, stable 문서. 들어온 판은 페이지에 표기 없음. (d) Django 전체가 의존으로 붙는다. 레포 구현은 `json.dumps` 뒤 세 글자를 바꾸는 세 줄이다(RC9)."
    touches: []
    decides: [OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://simplejson.readthedocs.io/en/latest/"
    supports: alternative
    claim: "(a) simplejson `JSONEncoderForHTML`. (b) 원문 「Subclass of JSONEncoder that escapes &, <, and > for embedding in HTML」, U+2028 · U+2029 도 이스케이프. (c) 원문 「is pure Python code with no dependencies, but includes an optional C extension」. 문서의 최신 판 표기는 3.19.0 이상. 첫 릴리스 · 최신 릴리스 날짜는 확인하지 않았다. (d) 표준 라이브러리가 아니라 서드파티 설치가 붙는다."
    touches: []
    decides: [OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain

  # ── R12 일 N: 판정 id ──
  - url: "https://docs.oasis-open.org/sarif/sarif/v2.1.0/os/sarif-v2.1.0-os.html"
    supports: alternative
    claim: "(a) SARIF 2.1.0 의 result `fingerprints`(§3.27.16) · `partialFingerprints`(§3.27.17) — 패키지가 아니라 표준. (b) 원문 「ensure that a fingerprint is resistant to changes that do not affect the logical identity of the result, such as … the line number where a result appears in a source file」 · partialFingerprints 값은 「a string that contributes to the stable, unique identity, or \"fingerprint,\" of the result」. R12 §7 의 `agent-file-line-<요약 지문>` 은 줄 번호를 id 에 남긴다. 못 덮는 것: 지문을 어떻게 계산할지는 표준이 정하지 않는다. (c) OASIS. 발행일은 이번 읽기 구간에서 확인하지 못했다. (d) 형식만 빌리면 설치는 없다. qg 의 지적 형식을 SARIF 로 바꾸는 일은 설계 범위 밖이다."
    touches: []
    decides: [OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain

  # ── R12 일 O: codex AGENTS.md ──
  - url: "https://learn.chatgpt.com/docs/config-file/config-reference"
    supports: both
    claim: "(a) codex 설정 키 `project_doc_max_bytes`(developers.openai.com/codex/config-reference 가 이 주소로 308 넘김). (b) 원문 「Maximum bytes read from AGENTS.md when building project instructions」. 값 0 이 불러오기를 끈다는 문장은 설정 레퍼런스에도 AGENTS.md 안내 페이지(learn.chatgpt.com/docs/agent-configuration/agents-md — 「stops adding files once the combined size reaches the limit」)에도 없다. 2차 자료(mintlify 의 비공식 codex 문서)는 `--no-project-doc` · `CODEX_DISABLE_PROJECT_DOC=1` · `[project_docs] enabled = false` 를 적지만 공식 문서에서 확인되지 않았다. (c) OpenAI 공식. (d) R12 `## 있는 것 검토` 원문: 「AGENTS.md 불러오기를 끄는 키는 계획이 실측한다」. 레포 구현은 `-c 'project_doc_max_bytes=0'` 을 넘긴다(RC11)."
    touches: []
    decides: [OQ8, OQ10]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "codex-cli 0.160.0 (R12 설계문서 본문 표기 — 의존 표에는 없음)", latest: "미확인"}
    certainty: uncertain

  # ── R12 일 P: 산문 락 ──
  - url: "https://docs.vale.sh/checks/conditional"
    supports: alternative
    claim: "(a) Vale `conditional` 검사(산문 린터). (b) 덮는 것: 원문 「the existence of 'first' implies the existence of 'second'」 — 「이 명령 꼴이 나오면 이 규칙 문장도 있어야 한다」 는 조건문 꼴. 못 덮는 것: 평가 범위가 문단이 아니다 — 원문 「a match of second covers every first after it in the file, in any later paragraph」. R12 §5 는 「같은 문단(목록에서는 항목 하나)」 을 요구한다. 펜스 안 · 밖 가르기와 `git ls-files` mode 120000 링크 따라가기는 Vale 범위가 아니다. (c) 유지 상태 · 릴리스 날짜는 이번에 확인하지 않았다. (d) 개발 · CI 에서만 쓰는 Go 바이너리 설치가 붙는다."
    touches: []
    decides: [OQ8]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain

repo_claims:
  - id: RC1
    path: "docs/superpowers/specs/2026-10-20-dependency-portability-design.md"
    anchor: "## 있는 것 검토 — 「레포 밖: git `remote set-head --auto` · `ls-remote --symref` · gh `-R` · `--json` 필드 · Renovate 의 기본 브랜치 설정 읽기(방식만 차용). 새 외부 패키지는 쓰지 않는다.」"
    line: 246
    claim: "R8 설계가 레포 밖에 대해 적은 전문이다. 이어지는 기각 줄은 Claude Code 기능 넷을 사유와 함께 든다: 「Claude Code plugin.json `dependencies`(superpowers 가 없으면 spec-distill 전체가 꺼진다 — U6 과 충돌) · Claude Code `userConfig`(레포 단위로 둘 수 없고 Bash 명령 환경에 없다 …) · `.claude/<plugin>.local.md`(git-ignored 라 새 작업공간에 없다) · 샌드박스 · 훅 출처 · 별도 프로세스(§7)」. 서드파티 패키지 · 남의 플러그인은 이름으로 한 건도 나오지 않는다."
    touches: []
    decides: [OQ10, OQ7]
  - id: RC2
    path: "docs/superpowers/specs/2026-10-23-r8-device-leftovers-design.md"
    anchor: "## 있는 것 검토 — 「레포 밖: gh `pr view <번호> --json` · `pr create` 의 URL 출력. 새 외부 패키지는 쓰지 않는다.」"
    line: 339
    claim: "R14 설계가 레포 밖에 대해 적은 전문이다(한 줄). 기각 항목이 그 절에 없고, 외부 것에 닿는 기각은 `## Rejected Alternatives` 의 두 줄뿐이다 — 「판 확인을 다음 세션 줄 대신 brainstorming 앞에 도는 새 펜스 · 훅으로 — 외부 skill 앞에 끼어드는 장치라 C25 · D26 과 과설계 경계에 걸린다」 · 「폴더 값을 쓰는 git 호출마다 `--literal-pathspecs` — … 글롭이 깨지고, 호출 자리마다 사본이 생긴다」."
    touches: []
    decides: [OQ10, OQ7]
  - id: RC3
    path: "docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md"
    anchor: "## 있는 것 검토 — 「레포 밖: codex CLI 의 설정 넘기기(`-c key=value`, codex-cli 0.160.0 `codex exec --help` 로 확인) — AGENTS.md 불러오기를 끄는 키는 계획이 실측한다. 새 외부 패키지는 쓰지 않는다.」"
    line: 238
    claim: "R12 설계가 레포 밖에 대해 적은 전문이다(한 줄). 그 절의 기각 줄(「해시 대조 … · 레포 밖 상태 폴더(U2) · relay-checker 문장 수 세기 · 새 표 행 쓰기 엔진 명령」)은 모두 레포 안 대안이다."
    touches: []
    decides: [OQ10, OQ7]
  - id: RC4
    path: "docs/superpowers/specs/"
    anchor: "세 설계문서의 「새 외부 패키지는 쓰지 않는다.」"
    claim: "「새 외부 패키지는 쓰지 않는다.」 는 세 문서의 레포 밖 줄 끝에 글자까지 같게 있고(R8 :246 · R12 :238 · R14 :339), 그 문장에 사유나 견준 후보는 붙어 있지 않다. 세 문서를 `--blob` · `set-default` · `WorktreeCreate` · `reference-transaction` · `CLAUDE_PLUGIN_DATA` · `plugin list` · `gh-stack` · `machete` · `poi` · `packaging` · `SARIF` · `Vale` · `shellcheck` · `bats` · `json_script` · `simplejson` · `from-pr` · `mise` · `pre-commit` 로 grep 하면 후보 이름은 한 건도 나오지 않는다(걸린 것은 `differential.yaml` 파일 이름 · `pr_cache_fingerprint` 함수 이름 · R8 :61 의 `fetch.followRemoteHEAD` 기본값 인용뿐)."
    touches: []
    decides: [OQ10]
  - id: RC5
    path: "plugins/spec-distill/scripts/repo_defaults.py"
    anchor: "def strict_frontmatter"
    line: 113
    claim: "값 해결자의 머리말 파서는 손으로 쓴 줄 단위 파서다 — BOM · 여는 줄 · 콜론 없는 줄 · 같은 키 · 따옴표 뒤 주석을 각각 `SettingsError` 로 낸다. 모듈의 import 는 argparse · os · re · stat · subprocess · sys · pathlib 와 같은 폴더의 `roadmap_model` 뿐이다(YAML 라이브러리 없음). 설정 파일 이름은 `SETTINGS_FILE = \".devbrew.md\"`(:35)이고 기본 브랜치 커밋의 blob 에서 읽는다(`_read_blob(top, commit, SETTINGS_FILE, \"repo\", run)`, :400)."
    touches: []
    decides: [OQ8]
  - id: RC6
    path: "plugins/spec-distill/scripts/check_deps.py"
    anchor: "def version_triple · def superpowers_version"
    line: 53
    claim: "판 비교는 첫 줄에서 `\\d+\\.\\d+\\.\\d+` 를 정규식으로 뽑아 정수 셋으로 견준다(표준 라이브러리만 import). superpowers 판은 불러온 skill 기준 폴더 경로 `…/superpowers/<판>/skills/…` 의 조각에서 읽는다(:221) — `claude plugin list` 나 plugin.json `dependencies` 를 쓰지 않는다."
    touches: []
    decides: [OQ8]
  - id: RC7
    path: "plugins/spec-distill/scripts/conductor_ledger.py"
    anchor: "def c_pr_record"
    line: 1031
    claim: "R14 가 만든 `ledger pr-record` 는 구현돼 있다 — PR 참조를 읽고(rc 2), URL 이면 origin 과 대조하고(rc 4), `gh_repo.pr_view` 로 번호를 물어 number · headRefName 등을 에픽 블록의 브랜치와 대조한 뒤에만 쓴다. `--drop` 은 gh 없이 줄을 지운다. 절 이름 상수는 `conductor_state.EPIC_PR = \"에픽 PR\"`(conductor_state.py:49), 찾기 함수 `recorded_number`(:227) · `recorded_cache_row`(:235)."
    touches: []
    decides: []
  - id: RC8
    path: "plugins/spec-distill/scripts/gh_repo.py"
    anchor: "PR_FIELDS · def pr_view"
    line: 45
    claim: "외부에서 빌려 쓰는 것은 gh 본체의 `pr view <N> --json number,state,headRefName,headRefOid,isCrossRepository,baseRefName,mergeCommit` 과 `pr list --state all --head <브랜치> --json` 이다(:181 · :191). gh 확장은 부르지 않는다."
    touches: []
    decides: [OQ9]
  - id: RC9
    path: "shared/docreview/scripts/docreview_state.py"
    anchor: "for ch, esc in ((\"&\", \"\\\\u0026\"), (\"<\", \"\\\\u003c\"), (\">\", \"\\\\u003e\")):"
    line: 1519
    claim: "R12 §2 의 슬롯 주입 이스케이프는 `json.dumps(out, ensure_ascii=False)` 뒤 세 글자를 `str.replace` 로 바꾸는 세 줄로 구현돼 있다(표준 라이브러리만)."
    touches: []
    decides: [OQ8]
  - id: RC10
    path: "plugins/quality-gates/scripts/synthesize_findings.py"
    anchor: "def finding_id"
    line: 169
    claim: "R12 §7 의 판정 id 는 `hashlib.sha1(claim_key(f).encode(\"utf-8\")).hexdigest()[:8]` 로 만든 요약 지문을 쓴다(표준 라이브러리 hashlib)."
    touches: []
    decides: []
  - id: RC11
    path: "plugins/quality-gates/scripts/run_codex_reviewer.sh"
    anchor: "-c 'project_doc_max_bytes=0'"
    line: 245
    claim: "R12 설계가 「계획이 실측한다」 로 남긴 AGENTS.md 끄는 키는 구현에서 `codex exec … -c 'project_doc_max_bytes=0'` 으로 들어갔다. 그 값 0 의 동작을 적은 공식 문서 문장은 이번 조사에서 찾지 못했다(evidence 의 codex 항목)."
    touches: []
    decides: [OQ10]
  - id: RC12
    path: "plugins/project-init/hooks/hooks.json"
    anchor: "\"matcher\": \"Bash|EnterWorktree\""
    line: 6
    claim: "R8 §3 의 훅 넓히기는 PostToolUse matcher `Bash|EnterWorktree` 로 구현돼 있고, `post-tool-use.py` 가 EnterWorktree 의 `name` 으로 만든 작업 트리의 브랜치를 실행 뒤에 관찰한다(:353 · :401 · :625). `WorktreeCreate` 이벤트는 쓰지 않는다."
    touches: []
    decides: [OQ9]
  - id: RC13
    path: "plugins/spec-distill/dependencies.md"
    anchor: "| 이름 | 최소 판 | 잰 날짜 | 강도 | 없을 때 |"
    line: 12
    claim: "레포가 쓰는 판(잰 날 2026-10-22): python 3.9.6 · git 2.54.0 · gh 2.88.1 · superpowers 7.0.0 · quality-gates 14.6.0 · claude-code 2.1.303(기록만). 표에 서드파티 Python 패키지나 gh 확장 행은 없다. quality-gates 의 표에는 `pr-review-toolkit`(외부 플러그인, 판 `—`)이 한 행 있다."
    touches: []
    decides: [OQ8, OQ9]
  - id: RC14
    path: "shared/docreview/scripts/docreview_config.py"
    anchor: "MAXIMUM = {\"detectors\": 6, \"rereview_cap\": 10, \"render_cap\": 100, \"summary_width\": 500}"
    line: 17
    claim: "R12 §2 의 최댓값 표는 dict 상수 한 줄로 구현돼 있다. 이 일에 대해서는 외부 후보를 따로 찾지 않았다(표준 라이브러리 한 줄 규모)."
    touches: []
    decides: []
  - id: RC15
    path: "plugins/"
    anchor: "grep `CLAUDE_PLUGIN_DATA|userConfig|plugin list|\"dependencies\"` (plugins/**/*.py · *.sh · *.json)"
    claim: "플러그인 스크립트 · 매니페스트에서 `CLAUDE_PLUGIN_DATA` · `userConfig` · `claude plugin list` 를 쓰는 자리는 없다. 걸린 한 건은 plugin.json 에 `dependencies` 가 «없음» 을 재는 테스트다(`plugins/spec-distill/tests/test_superpowers_presence.sh:205`). `.md`(skill · reference) 는 이 grep 범위 밖이다."
    touches: []
    decides: [OQ9]

unanswered: "확인하지 못한 것 — (1) 여러 후보의 «들어온 판 · 날짜»: git `--blob` · `reference-transaction` · 전역 `fetch.followRemoteHEAD`, `gh repo set-default`, `${CLAUDE_PLUGIN_DATA}`, `claude plugin list --json`, Django `json_script`, SARIF 발행일, ccpm · git-spice · Vale · ShellCheck · bats-core · mise 의 릴리스 날짜와 유지 상태 (2) Jinja `tojson` / `htmlsafe_json_dumps` 문서 원문(페이지 잘림) (3) GitHub rulesets 의 브랜치 이름 제한 규칙과 요금제 조건(읽은 페이지에 그 절이 없었다) (4) PostToolUse 가 EnterWorktree 도구 뒤에 불리는지의 공식 문장 (5) codex `project_doc_max_bytes=0` 의 공식 동작 (6) gh-stack GA 날짜(블로그 한 곳만 2026-10-06 이라 적음) (7) R12 · R14 의 레포 내부 불변식 일들(보호 계보 · 흡수 · 다시 읽지 않기 · 락 지도 단언 등)은 바깥 낱말을 정하지 못해 검색하지 않았고, 「새 항목만 추가」 판정과 에픽-PR 기록 플러그인은 검색했으나 찾지 못함."
```

덧붙임 — 주문 범위 안에서 나란히 둘 사실 셋(판정 아님):
1. 세 설계문서의 레포 밖 줄은 모두 git · gh · codex · Claude Code 의 내장 기능(과 Renovate 의 방식)만 들고, 「새 외부 패키지는 쓰지 않는다.」 로 끝난다. 이번에 찾은 서드파티 후보(gh-poi · git-delete-merged-branches · git-machete · gh-stack · packaging · python-frontmatter · strictyaml · simplejson · Vale · ShellCheck · bats-core · ccpm)는 어느 문서에도 이름이 없다.
2. 서드파티 후보마다 배포 조건에서 붙는 것이 확인됐다 — Python 패키지 둘(git-delete-merged-branches · python-frontmatter)은 `requires_python >=3.10` 이고 레포 바닥은 3.9.6 이다. gh-poi · gh-stack 은 gh 확장 설치가 따로 든다. gh-stack 은 0.x 이고 설계 날짜에는 public preview 가 확인된다.
3. 이미 의존인 git · gh · Claude Code 안에 설계가 언급하지 않은 내장 후보가 있다 — `git config --blob`, `fetch.followRemoteHEAD=warn|always`, `reference-transaction` 훅, `GIT_NOGLOB_PATHSPECS`, `gh repo set-default`, `WorktreeCreate` 훅, `${CLAUDE_PLUGIN_DATA}`, `claude plugin list --json`, 세션-PR 연결. 각각 못 덮는 부분은 위 항목에 적었다.

Sources:
- https://code.claude.com/docs/en/plugins-reference
- https://code.claude.com/docs/en/plugin-dependencies
- https://code.claude.com/docs/en/plugins/cli-reference
- https://code.claude.com/docs/en/plugins/troubleshooting
- https://code.claude.com/docs/en/hooks
- https://code.claude.com/docs/en/settings-reference
- https://code.claude.com/docs/en/agent-view
- https://code.claude.com/docs/en/common-workflows
- https://git-scm.com/docs/git-config
- https://git-scm.com/docs/git-fetch
- https://git-scm.com/docs/git
- https://git-scm.com/docs/githooks
- https://www.kernel.org/pub/software/scm/git/docs/RelNotes/2.48.0.adoc
- https://cli.github.com/manual/gh_repo_set-default
- https://cli.github.com/manual/gh_pr_view
- https://github.com/seachicken/gh-poi
- https://github.com/seachicken/gh-poi/releases
- https://pkg.go.dev/github.com/seachicken/gh-poi@v0.1.0
- https://pypi.org/pypi/git-delete-merged-branches/json
- https://pypi.org/pypi/git-machete/json
- https://github.com/VirtusLab/git-machete
- https://github.com/github/gh-stack
- https://github.com/github/gh-stack/releases
- https://github.blog/changelog/2026-07-30-stacked-pull-requests-are-now-in-public-preview/
- https://infoq.com/news/2026/04/github-stacked-prs (2차)
- https://www.theregister.com/2026/04/14/github_stacked_prs/ (2차)
- https://flaviocopes.com/github-stacked-prs/ (2차)
- https://abhinav.github.io/git-spice/guide/internals/
- https://github.com/automazeio/ccpm
- https://pypi.org/pypi/packaging/json
- https://pypi.org/pypi/strictyaml/json
- https://pypi.org/pypi/python-frontmatter/json
- https://mise.jdx.dev/configuration.html
- https://docs.renovatebot.com/configuration-options/
- https://github.com/pre-commit/pre-commit-hooks
- https://docs.djangoproject.com/en/stable/ref/templates/builtins/
- https://simplejson.readthedocs.io/en/latest/
- https://docs.oasis-open.org/sarif/sarif/v2.1.0/os/sarif-v2.1.0-os.html
- https://learn.chatgpt.com/docs/config-file/config-reference
- https://learn.chatgpt.com/docs/agent-configuration/agents-md
- https://www.mintlify.com/openai/codex/advanced/custom-instructions (2차, 미확인 주장)
- https://docs.vale.sh/checks/conditional
- https://www.shellcheck.net/wiki/SC2031
- https://github.com/bats-core/bats-core
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets (해당 절 없음)


### 조사 11 — open-researcher · R5 · 묶음 3

조사 결과입니다. 넷 중 (3)과 (4)는 본문을 읽었고, (1)의 Shrives · Brennan 논문과 (2)의 GAO 22개 목록 전체는 본문에 닿지 못했습니다.

읽은 방식의 한계 둘:
- 웹 본문은 모두 WebFetch(작은 모델이 페이지를 읽고 답하는 방식)로 읽었습니다. 인용은 그 도구가 돌려준 짧은 원문 조각이고, 제가 페이지를 직접 대조하지는 못했습니다.
- PDF 는 이 환경에서 읽히지 않았습니다(바이너리로 돌아오고 `pdftoppm` 이 없음). 그래서 GAO 보고서 PDF 와 FRC 2025 리뷰 PDF 는 본문 미확인입니다.

전제 번호(P<n>)는 입력에 없어 `touches` 는 전부 빈 배열입니다. `decides` 는 OQ10 · OQ11 안에서만 걸었습니다.

```yaml
evidence:
  # ── (1) comply-or-explain: 설명의 질 ──
  - url: "https://www.frc.org.uk/docs/9178/html/"
    supports: both
    claim: >
      FRC 「Improving the quality of 'comply or explain' reporting (March 2026)」, 2026-03-16 발행 — 2021 지침의 최신 개정판.
      (a) 읽는 것: 이탈 설명 한 건이 다섯 요소를 갖췄는가 — 배경 · 맥락(어느 조항인지 명시), 대안의 설득력 있는 근거,
      위험과 완화 조치, 기한(한시인지 무기한인지 · 언제 따를지), 평이한 말로 이해되고 설득력 있는가.
      좋은 예(Rolls-Royce, Provision 32)와 나쁜 예(Provision 9: "The Non-Executive Directors have determined that [the Chair] continues to lead the Board effectively.")를 싣는다.
      (b) 판정자: FRC 가 연례 리뷰 표본으로 읽는다. 평가자 · 채점 절차는 문서에 없다. 이 판에는 통계가 없다.
      (c) 왜곡: 엄격한 준수를 좇으면 "often leads to boilerplate language". 일부 이해관계자가 Code 를
      "a compliance exercise, from which companies feel they cannot depart" 로 만들었다고 적는다.
      주주 · 의결권 자문사에게 "should not expect or favour strict compliance over effective governance" 라고 요구한다.
      읽은 범위: HTML 본문. 그 HTML 은 FRC 가 PDF 를 AI 로 변환했고 사람 검증이 없다고 스스로 밝힌다.
    touches: []
    decides: [OQ10]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://www.frc.org.uk/docs/1892/html/"
    supports: both
    claim: >
      FRC 같은 제목의 2021-02-26 판(2026-03 판이 대체).
      (a) 센 것: 무작위 100개사 표본(2020-11 리뷰)의 미준수 74건 가운데 높은 질로 평가된 설명은 4건, 다수는 부적절, 1건은 설명 없음.
      Provision 9 미준수를 밝힌 16개사 전부 설명이 불충분. 다섯 요소는 2026 판과 같다.
      (b) 판정자: FRC. 누가 어떤 채점 절차로 평가했는지는 문서에 없다.
      (c) 왜곡: 어느 조항에서 벗어났는지 밝히지 않는 포괄 문장("Other than where expressly stated below ... the company complied in full...").
      전면 준수를 선언했는데 조사해 보니 이탈을 밝히지 않은 회사가 여럿 있었다(수는 없음).
      읽은 범위: HTML 본문(AI 변환 · 미검증 고지 있음).
    touches: []
    decides: [OQ10]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://www.frc.org.uk/docs/1337/html/"
    supports: both
    claim: >
      FRC Review of Corporate Governance Reporting (2021-11). 표본은 "a random sample of 100 FTSE 350 and Small Cap companies".
      "most explanations lack supporting information or use boilerplate language", 상투 문장은
      "seldom substantiated by actions or examples", 설명의 질이 "has not significantly improved".
      같은 해 미준수 선언 수는 늘었다(Provision 38: 27 대 전년 11, Provision 19: 16 대 9).
      Provision 36 · 38 은 밝히지 않은 미준수가 가장 많았다.
      즉 「이탈을 밝힌 건수」는 늘어도 「설명의 질」은 그대로일 수 있고, 둘은 서로 다른 관측점이다.
      읽은 범위: HTML 약 19만 자 중 앞 10만 자(AI 변환 · 미검증 고지 있음).
    touches: []
    decides: [OQ10]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://www.frc.org.uk/news-and-events/news/2025/11/frc-annual-review-highlights-the-value-of-meaningful-explanations-in-corporate-governance-reporting-and-the-codes-flexibility/"
    supports: both
    claim: >
      FRC 2025 연례 리뷰 보도자료(리뷰는 2025-11-13 발행). 100개사 표본 중 25개사가 조항 하나 이상에서 이탈을 밝혔다.
      이탈한 회사가 점점 "clear, meaningful and context-specific explanations" 를 낸다고 한다.
      "clear and meaningful explanations are just as valid as compliance".
      이 평가는 위 2021 리뷰의 「나아지지 않았다」와 방향이 다르다. 시점이 다르므로 둘 다 싣는다.
      2차 요약(Clifford Chance, 검색 요약으로만 봄)은 일부 설명이 "remain relatively narrow in scope and lack clarity" 라고 전한다.
      읽은 범위: 보도자료만. 리뷰 PDF 본문과 질 판정 기준 · 건수는 확인하지 못했다.
    touches: []
    decides: [OQ10]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain

  - url: "https://researchportal.northumbria.ac.uk/en/publications/a-typology-for-exploring-the-quality-of-explanations-for-non-comp/"
    supports: both
    claim: >
      Shrives & Brennan (2015), British Accounting Review 47(1) 85–99, DOI 10.1016/j.bar.2014.08.002.
      (a) FTSE 350 의 Code 미준수 설명을 2004/5 · 2011/12 두 시기에 걸쳐 일곱 질 특성으로 평가한 유형론.
      초록의 결론: 준수는 늘었지만 설명의 질은 들쭉날쭉했고, 특히 location · complexity · specificity 가 개선 대상.
      준수율을 올리라는 압력은 comply-or-explain 철학과 어긋나며, 준수 증가보다 설명의 질이 중요하다.
      (b) 판정자: 연구자의 사후 코딩. 초록은 감사인의 침묵을 문제 삼는다. 코딩 절차 · 코더 간 일치도는 확인하지 못했다.
      (c) 일곱 특성의 이름(Location · Comprehensiveness · Originality/Mimetic behaviour · Length · Complexity · Specificity · Attestation)과
      표본 수(미준수 회사 204(125) · 위반 537(253) · 설명 438(208))는 검색 요약에 나온 인용 문헌 조각에서만 봤다.
      각 특성의 정의와 좋은 설명 · 상투 문구를 가르는 조작 기준은 읽지 못했다.
      읽은 범위: 초록만(Northumbria 포털 · RePEc · Semantic Scholar API). 본문은 core.ac.uk 403 · UCD 저장소 405 · ScienceDirect 403.
    touches: []
    decides: [OQ10]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain

  - url: "https://www.cambridge.org/core/journals/legal-studies/article/abs/comply-or-explain-in-corporate-governance-codes-in-need-of-greater-regulatory-oversight/E36C5EB6E97052A41C6F1C88F480F7A3"
    supports: both
    claim: >
      Keay (2014), Legal Studies 34(2). 판정자 축의 근거:
      "There is no provision in the UK for any statements by companies to be assessed by any regulatory body."
      설명이 충분한지는 시장과 주주가 판단하게 돼 있고, 논문은 규제자가 설명의 질을 평가해야 하는지를 묻는다.
      읽은 범위: 초록만.
    touches: []
    decides: [OQ10]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://ideas.repec.org/a/kap/jmgtgv/v17y2013i3p791-826.html"
    supports: both
    claim: >
      Seidl, Sanderson & Roberts (2013), J. Management & Governance 17(3).
      영국 · 독일 상장사 257곳의 이탈 기록 약 715건에서 "empirically derived taxonomy of the explanations" 를 만들었다.
      유형 이름과 결함 있는 설명의 비율은 초록에 없다.
      읽은 범위: 초록만.
    touches: []
    decides: [OQ10]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain

  # ── (2) GAO 대안 분석(AOA) 모범 관행 ──
  - url: "https://www.gao.gov/products/gao-15-37"
    supports: both
    claim: >
      GAO-15-37 (2014-12-11).
      (a) AOA 모범 관행 24개를 식별하고 「24개 중 몇 개에 부합하는가」를 셌다.
      DOE 요구사항은 24개 중 1개(임무 필요에 근거한 기능 요구 정의), 비강제 지침을 더하면 9개.
      NNSA 사업 셋은 6–11개. "NNSA did not conform to most of the best practices GAO identified for conducting AOAs."
      (b) 관행의 출처: 널리 인정된 단일 기준이 없어 AOA 경험이 있는 공공 · 민간 일곱 기관의 정책 · 지침을 검토하고 전문가에게 확인받았다.
      판정자는 GAO 다.
      (c) NNSA 는 DOE 요구와 겹치는 한 관행만 일관되게 따랐다. 요구된 것만 채워진 꼴이다.
      읽은 범위: 제품 요약 페이지만. 24개 목록과 등급 정의는 PDF 본문이라 읽지 못했다.
    touches: []
    decides: [OQ10]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://files.gao.gov/reports/GAO-25-107092/index.html"
    supports: both
    claim: >
      GAO-25-107092 (2025-05-29, HTML 전문). 22개 관행 틀의 채점 방식이 본문에 있다.
      (a) 관행마다 증거의 양으로 5점 척도를 매긴다.
      Not Met=1 "no evidence that satisfies any of the best practice",
      Minimally=2 "a small portion", Partially=3 "about half", Substantially=4 "a large portion",
      Fully=5 "complete evidence that satisfies the best practice".
      관행 점수를 네 특성(comprehensive · well-documented · credible · unbiased)별로 평균한다
      (1.0–1.4 Not Met … 4.5–5.0 Fully Met). 네 특성은 "identify a high quality, reliable AOA process".
      본문에서 번호 · 이름 · 특성을 확인한 관행 11개:
      2 Define functional requirements(Comprehensive) · 5 Define selection criteria(Credible) ·
      6 Weight selection criteria(Unbiased) · 12 Identify significant risks and mitigation strategies(Well-documented) ·
      13 Determine and quantify benefits and effectiveness(Unbiased) · 15 Develop life-cycle cost estimates(Comprehensive) ·
      16 Include a confidence level or range for life-cycle cost estimates(Credible) · 17 Perform sensitivity analysis(Credible) ·
      19 Document ground rules, assumptions, and constraints(Well-documented) ·
      21 Perform independent review(Credible) · 22 Compare alternatives(Unbiased).
      10번(include baseline alternative)은 기준 대안이 없어 「해당 없음」으로 채점하지 않았다.
      21번의 뜻: "An entity independent of the AOA process reviews the extent to which all best practices are followed."
      (b) 판정자: GAO 분석관. GAO 등급의 독립 검증은 본문에 없다.
      (c) 한계를 GAO 가 직접 적는다: "We did not use our best practices for an AOA process to determine whether the Air Force
      or President made the correct decision". 재는 것은 과정이지 결론의 옳음이 아니다.
      완결된 AOA 가 아니면 채점하지 않았다. 선정 기준 가중은 분석 전에 정해야 한다는 식으로 시점에 매인 관행도 있다.
      읽은 범위: HTML 약 14.9만 자 중 14만 자(끝 9천 자 미독). 22개 전체 표는 그림이라 읽히지 않았다.
    touches: []
    decides: [OQ10]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://www.gao.gov/products/gao-16-853"
    supports: both
    claim: >
      GAO-16-853 (2016-09-30). 22개 관행 · 네 특성으로 DOD 의 AOA 를 평가했다.
      "fully or substantially met 6 best practices, partially or minimally met 15, and did not meet 1".
      DOD 는 권고에 동의하지 않았고 22개 관행이 기지 결정에 적용된다는 것 자체를 다퉜다. 권고는 "Closed – Not Implemented".
      피평가자가 적용 범위를 다투면 평가가 행동을 바꾸지 못한다는 사례다.
      읽은 범위: 제품 요약 페이지만.
    touches: []
    decides: [OQ10]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://www.gao.gov/products/gao-21-194"
    supports: both
    claim: >
      GAO-21-194 (2021-04-29). NNSA El Capitan AOA 는 특성 넷 중 하나를 partially met, 셋을 minimally met.
      지적: HPC 해법이 미리 정해져 있었고, 사업을 운영하는 계약자가 AOA 를 수행했으며(정책은 독립 주체를 요구),
      관행에서 벗어난 것을 정당화 · 기록하지 않았다.
      NNSA 는 모범 관행을 자본 취득 사업에만 따르겠다고 했다. 이후 다음 HPC 시스템에 독립 검토 위원회를 둔 AOA 를 요구해 권고가 닫혔다.
      분석을 수행한 쪽이 결론에 이해가 있으면 「미리 정해진 해법」이 나온다는 것이 unbiased 축의 실패 양식이다.
      읽은 범위: 제품 요약 페이지만.
    touches: []
    decides: [OQ10]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://www.gao.gov/products/gao-20-195g"
    supports: both
    claim: >
      GAO-20-195G Cost Estimating and Assessment Guide (2020-03-12). 22개 AOA 모범 관행의 정본 목록은 Appendix XI 에 있다.
      검색 결과로는 24개(GAO-15-37)가 GAO-16-22(2015-10-28)에서 22개로 줄었고 이 지침이 그것을 싣는다.
      읽은 범위: 제품 페이지만. PDF 는 읽히지 않고 디지털판(guides.gaoinnovations.gov)은 403 이라 22개 전체 이름과 다섯 단계 묶음은 확인하지 못했다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain

  # ── (3) 에이전트의 build-vs-buy · 재사용 판정 ──
  - url: "https://arxiv.org/html/2606.03907"
    supports: both
    claim: >
      Lulla · Galster · Zhang · Baltes · Treude, "The Impact of Configuring Agentic AI Coding Tools on Build-vs-Buy Decisions:
      A Study Protocol" (arXiv 2606.03907 v1, 2026-06-02). 사전 등록 프로토콜이라 결과는 아직 없다.
      조작 변수(Claude Code · OpenAI Codex 에 주는 설정):
      컨텍스트 파일(없음 / 재사용 선호 / 직접 구현 선호) · 전달 수단(컨텍스트 파일 대 Skill) ·
      MCP 라이브러리 탐색 도구 유무 · 승인 우회 켬/끔 · 지시 강도(없음 / 부드러운 선호 / 명시 금지) ·
      라이브러리 이름 없는 buy 지시 · 허용/차단 목록 · 새 라이브러리 공개 지시.
      (a) 측정: 결정 지점마다 이진값 — "1 if the tool imports an external library for that point, 0 if it implements the functionality from scratch".
      보는 것은 import 문 · pip/npm install 명령 · 도구 출력, 그리고 vendored 소스를 잡는 디렉토리 구조 휴리스틱.
      vendored 는 buy, 표준 라이브러리 import 는 build("We will treat standard library imports as build decisions throughout").
      라이브러리를 「import 뒤에도 참조되어 실제로 쓰임」과 「import 만 되고 참조 없음」으로 가른다.
      그 밖: 지시 준수율, 라이브러리 선택이나 설치를 언급하는 멈춰 묻기 여부,
      공개 Coverage(|disclosed ∩ used| / |used|) · Precision(레지스트리에 실재하고 생성 코드에 나타나는 이름의 비율), 단계별 테스트 통과율.
      (b) 판정자: 규칙 기반 파싱. 분류에 사람 · LLM 판정이나 평가자 간 일치 검사는 본문에 없다.
      (c) 저자가 든 한계: 분류가 파싱 휴리스틱에 달려 있다. 표준 라이브러리와 서드파티의 경계가 모호하다.
      과제 문구가 한쪽을 유리하게 할 수 있다. 셀당 세션 하나라 확률 변동에 노출된다.
      Skill · MCP 는 설정해도 불리지 않을 수 있다. 프로젝트 5 · 언어 2(Python · JavaScript) · 고정 모델 판이라 일반화에 한계가 있다.
      읽은 범위: HTML 본문.
    touches: []
    decides: [OQ10, OQ11]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://arxiv.org/html/2606.28430"
    supports: both
    claim: >
      Ma · Kereopa-Yorke · Schultz, "Building to the Test: Coding Agents Deliver What You Check, Not What You Requested"
      (arXiv 2606.28430 v1, 2026-06-26). Copilot CLI 에이전트 둘에게 React 데이터 테이블을 Angular 재사용 라이브러리로 다시 만들게 했다
      (숨긴 Playwright 테스트 222개 · 18회 실행 · 세 조건).
      (a) 관측점 둘.
      ① 정적 감사: 하위 시스템 넷(selection · sort · resize · grid navigation)마다 데모가 라이브러리를 거치는지 인라인으로 다시 만들었는지 본다.
         ND="the demo calls the library; the subsystem is not reimplemented inline",
         L2(죽은 라이브러리)=라이브러리에 구현이 있는데 "the demo reimplements the behavior inline and never calls the library",
         L1(없는 라이브러리)=구현이 없거나 표시용뿐.
         규칙: 완전한 구현이 있고 데모의 참조(런타임 import · 호출 자리)가 0보다 크면 ND, 0이면 L2. "Type-only imports do not count."
      ② no-op 절제: 라이브러리의 상태 메서드 본문을 no-op 으로 바꾸고 그 하위 시스템 테스트를 다시 돌린다.
         L2 는 점수가 안 변한다("No-oping the GPT L2 library leaves the score unchanged", 29/29→29/29).
         ND 대조는 무너진다("breaks 12 of 29 resize tests").
      결과: 테스트 오라클을 주자 점수는 거의 만점인데 라이브러리가 죽거나 없었다. GPT 는 6회 중 5회, Claude 는 6회 중 2회. L2 12칸 · L1 3칸.
      (b) 판정자: 표준 라이브러리만 쓰는 Python 스크립트(audit-tool/audit.py, --verify 48/48 일치).
      판정 자체의 사람 검증은 따로 없고 절제가 각 판정을 반증하는 수단이다.
      (c) 「점수를 목표로 삼으면 생기는 일」 그 자체가 결과다. 통과 점수는 요청한 것이 납품됐는지를 확인해 주지 않는다.
      감사의 편향: "any token-level match to a library symbol inflates refs and biases the verdict toward ND, so the audit under-reports the disposition".
      메서드가 상태를 「소유」하는지는 형식화되지 않은 해석이다. ND 대조 절제는 셋뿐이다. 에이전트 둘 · 18회라 유병률은 열린 질문이다.
      읽은 범위: HTML 본문(0–10만 자 · 10만 자 이후 부록 E 포함).
    touches: []
    decides: [OQ10, OQ11]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

  - url: "https://arxiv.org/html/2609.36730"
    supports: both
    claim: >
      Orlanski 외, "Can Agents Design Libraries for Agents?" (LibraryDesignBench, arXiv 2609.36730 v1, 2026-09-29).
      (a) 단순성: 문제마다 ρ = 네 정적 지표(Cyclomatic Complexity · Cognitive Complexity · Halstead Volume · SLOC)의
      min{기준 해법 값 / 제출 값, 1} 평균. 기준 해법은 실제 라이브러리를 관용적으로 쓴 고정 프로그램이다.
      점수는 q²·ρ(q=테스트 통과 비율)의 평균. 비는 1에서 잘려 기준보다 작아도 가산이 없다.
      재구현 판정에 전용 분류기는 없고 분석이 둘이다.
      ① 기준보다 코드가 큰 부분 통과 칸 810개를 LLM 감사자 하나(GPT-5.6 Luna)가 라이브러리 · 궤적 · 해법 · 테스트 결과 · 기준을 읽고 분류:
         라이브러리의 한계 82%(661/810, 이 중 Rigidity+Verbosity 64%, Coverage 14%) 대 라이브러리를 다 쓰지 않음 18%(149/810).
      ② 저자의 손 라벨: "41% of 13,562 hand-labeled lines that implementers rebuilt in 180 solutions redo functionality the library shipped but hid or broke."
      (b) 판정자: ① 은 LLM 한 개가 한 번 — "Each cell is audited once by one model... without human labels or an agreement check",
      실행하지 않고 추론한다("The auditor reasons about the best as-shipped path rather than running it"). ② 는 저자, 일치도 보고 없음.
      (c) 저자가 든 한계: 기준 프로그램이 유일한 최적이 아니다. 지표는 테스트된 정확성과 정적 크기 · 복잡도만 본다
      (not "full library correctness, security, runtime efficiency, or maintainability"). 분류 비율은 부분 통과 칸만의 것이다.
      다시 만든 이유의 다수가 「없어서」가 아니라 「쓰기 어렵거나 굳어서」라는 결과는, 재구현율만 세면 원인(맞지 않음 대 안 찾음)이 가려진다는 뜻이다.
      읽은 범위: HTML 약 11.8만 자 중 앞 10만 자.
    touches: []
    decides: [OQ10, OQ11]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed

repo_claims:
  - id: RC1
    path: "docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/measurements.md"
    anchor: "「설계문서에는 결과를 적지 않는다. 결과가 바꾸는 에픽은 표의 마지막 칸이다.」 · 표 머리 「# | 묻는 것 | 결과(한 줄) | 바꾸는 것」"
    line: 3
    claim: >
      M1–M10 은 「나아졌는가」가 아니라 「이것이 되는가 · 어떻게 동작하는가」를 한 번씩 확인한 실측이다
      (예: M1 백그라운드 subagent 에서 AskUserQuestion 가능 여부, M4 에픽 하나에서 superpowers 가 사용자를 기다린 자리 10곳).
      각 행은 결과가 바꾸는 에픽(예 「R5(OQ30)」)에 묶이고, 절마다 방법 · 원 출력 · 판정 · 재지 못한 것을 적는다.
      판정은 측정을 돌린 지휘 세션(모델)이 쓴다. 판 · 날짜가 붙어 있다(Claude Code 2.1.296/2.1.302 · superpowers 6.4.1).
      왜곡을 스스로 적은 자리: M5 「측정 자체가 결과를 밀었다」(압축 요약이 관측할 일을 들고 있어 돌아왔을 공산),
      M2 「/compact 측정은 한 번이다」, M10 「원인은 재지 못했다」.
    touches: []
    decides: [OQ10]

  - id: RC2
    path: "docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/flexibility-audit.md"
    anchor: "# 흐름 고정 점검 (2026-10-17) · 「형식만 채우는 무거운 게이트를 추가하지 않는다」 · ## 끝에서 끝 확인에서 찾은 것"
    line: 35
    claim: >
      측정 기록이 아니라 점검 목록이다. 「언제나 X」 로 고정된 자리를 파일:줄로 열거해 받는 에픽(R10 · R5 · R2a · R9)에 배정했다.
      세지 않고, 자리마다 「기본 + 모델 판단」으로 풀 것을 적는다. 판정은 점검한 세션과 사용자 결정(원문 인용)이다.
      R10 설계 입력으로 실린 사용자 원칙에 「조사 능력을 제한하는 임의의 검색 횟수·출처 수 상한이나, 형식만 채우는 무거운 게이트를 추가하지 않는다.」 가 있다.
      끝에서 끝 확인 절은 가상 시나리오를 실제 명령으로 걸었고, 사람 · 모델이 필요한 자리는 「걷지 못했다」 고 따로 적었다.
    touches: []
    decides: [OQ10]

  - id: RC3
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/token-baseline.md"
    anchor: "## 이 기준선을 쓸 때 · ## 번호 대조 D11 행 「측정 도구를 제품화하지 않는다 — 스크립트는 플러그인 밖 이 문서 옆에 둔다」 · AC5"
    line: 285
    claim: >
      이 레포에서 전후 비교용으로 잰 유일한 기준선이다(2026-11-14).
      (a) 세는 것: 세션 기록 assistant 줄의 usage 네 칸을 message.id 로 한 번씩, 지휘 본체 대 하위 agent 로 갈라서.
      (b) 판정: 문서 옆 `token-baseline/` 스크립트(조용히 틀릴 자리에서 rc 3 으로 멈춤). 재측정은 R5 가 같은 규칙으로 한다.
      (c) 문서가 적은 왜곡:
      「실제로 쓴 토큰이 아니라 그 하한이다」.
      「일꾼이 별도 세션으로 뜨는 구조로 바뀌면 같은 규칙으로 재도 일꾼 몫이 빠져 가짜 절감이 나온다」.
      응답당 입력계와 캐시 읽기 비율은 걸음 수에 따라 움직여 「둘 다 품질 지표가 아니다」.
      「원시 토큰 수는 리프레시 문턱이 아니다(D11)」.
      측정 장치의 위치는 AC5 「재현할 수 있게 집계 규칙과 실행 방법을 적되 측정 도구를 제품화하지 않는다」 로 정했다.
      같은 문서에 `## 있는 것 검토` 표(칸: 수단 · 자리 · 지금 확인한 것 · 이 조사에 쓰나)가 있고 여섯 행 모두 결론이 「아니다」 또는 「없다」 다.
    touches: []
    decides: [OQ10]

  - id: RC4
    path: "docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md"
    anchor: "「- Non-goal: … 개선을 재는 별도 측정 장치(S32) …」 · D34 「개선 여부는 따로 재지 않고 사용자가 쓰면서 판단한다」 · OQ16"
    line: 310
    claim: >
      「개선을 재는 별도 측정 장치」 Non-goal 의 출처는 2026-10-11 로드맵 인터뷰의 S32 다.
      audit 원문(같은 폴더 `…-interview.audit.md` 550–551행): 「**S32** ☑ 선택 (round 22): 내가 쓰면서 판단 — 개선 여부는 따로 재지 않고 사용자가 쓰면서 체감으로 판단」.
      이것이 OQ16 「바뀐 파이프라인의 품질이 실제로 나아졌는지 무엇으로 확인하는가」 를 닫았고 D34 로 확정됐다.
      같은 Non-goal 문장이 그 로드맵의 에픽 묶음 R1–R14(각 27행)와 설계문서 셋의 Non-goals 에 복제돼 있다
      (`docs/superpowers/specs/2026-10-12-interview-persistent-explore-design.md:88`,
      `…/2026-10-17-shared-review-engine-devices-design.md:77`, `…/2026-10-19-interview-open-research-design.md:68`).
      범위는 그 로드맵과 거기서 나온 설계다. CLAUDE.md 와 철학 문서에는 측정 장치를 금하는 문장이 없다(두 파일에서 「측정|계측」 검색 0건).
    touches: []
    decides: [OQ10]

  - id: RC5
    path: "docs/superpowers/specs/2026-09-22-interview-research-specialization-design.md"
    anchor: "## Non-goals 첫 항목 「조사를 했는지를 나중에 재는 장치 ⟨C5⟩」 · 「재서 **막으면** 사후 장치이고, 재서 **보이면** 공시다.」"
    line: 162
    claim: >
      더 앞선 전례다. 「2026-09-10 에 사용자가 사후 깊이 측정 계열을 「쓰이지 않는 무게 · 번거로움 · 방향이 틀렸다」 세 이유로 직접 걷어냈고 그 판정은 유효하다.」
      술어의 범위를 셋으로 적는다. 「차단 판정에 개수를 쓰지 않는다」. 「조건 분기와 advisory 에는 개수가 들어간다」. 「재서 막으면 사후 장치이고, 재서 보이면 공시다」.
      실제 제거 기록은 `plugins/spec-distill/CHANGELOG.md:1425` — 사유 「쓰이지 않는 무게(0.57.0 도입 뒤 측정 기록 0건 · 사람 e2e 미실행), 인터뷰가 번거로움, 방향이 틀렸다」.
      `depth-auditor` agent · 측정 스크립트 둘 · 원장 디렉토리가 함께 지워졌다.
    touches: []
    decides: [OQ10]

  - id: RC6
    path: "docs/superpowers/specs/2026-09-06-interview-depth-redesign-design.md"
    anchor: "「R14 — 사후 측정을 게이트로: Goodhart(brief §4). brief C11 이 «게이트 아님»을 확정.」"
    line: 753
    claim: >
      이 레포는 「숫자를 목표로 삼을 때의 왜곡」을 이미 기각 사유로 썼다. 같은 목록의 R12:
      「하류 재질문 계수 채널 … 게이트가 되면 인터뷰가 설계 결정을 brief 에 선기입하는 쪽으로 왜곡된다.」
      `docs/superpowers/specs/2026-09-21-designer-lens-review-design.md:989-990` 도
      「계측기 부재 — … 이 변경이 무엇을 바꿨는지 원리적으로 못 잰다. 이번 범위 밖(브리프 S5). 계측 칸을 열 때 Goodhart 를 함께 본다.」 로 열어 두었다.
    touches: []
    decides: [OQ10]

  - id: RC7
    path: "plugins/spec-distill/references/epic-handoff.md"
    anchor: "에픽 넘김 줄 — 「설계문서에 ## 있는 것 검토 절(레포 안에 이미 있는 것을 먼저 찾아 쓰고, 레포 밖 패키지 · 프레임워크 · 서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다)」"
    line: 7
    claim: >
      「있는 것 검토」의 결론이 지금 남는 자리는 설계문서의 `## 있는 것 검토` 절이다. 넘김 줄과 `plugins/spec-distill/skills/pm-interview/SKILL.md:312-315` 의 「있는 것 먼저」 문단이 요구한다.
      이 절의 결론을 읽거나 세는 장치는 찾지 못했다.
      `plugins/**/*.py` 에서 「있는 것 검토」 검색 0건. 셸 테스트 셋(`test_epic_handoff.sh:64` · `test_end_gates.sh:68` · `test_review_handoff_order.sh:97`)은 넘김 문구가 있는지만 잠근다.
      리뷰어 프로필(`plugins/spec-distill/agents/`)에도 이 절을 보는 항목이 없다.
      가까운 것은 `doc-critic-web.md:60` 의 방향 검토 「더 나은 대안이 이미 있는가(성숙한 라이브러리 · 확립된 패턴 · 출시된 도구 · 문서화된 접근)」 하나다.
      이 절을 가진 설계문서는 `docs/superpowers/specs/` 에 10개다(Grep 은 심볼릭 링크를 건너뛰므로 하한).
      그중 「레포 밖」 줄을 본 8건의 결론:
      「없음」 또는 「쓰지 않는다」 3건(2026-10-28 · 2026-10-23 rules-docs · 2026-10-25),
      표준 라이브러리 · git · gh · codex CLI 의 기능만 쓰고 「새 외부 패키지는 쓰지 않는다」 4건(2026-10-21 · 2026-10-20 둘 · 2026-10-23 r8),
      외부 패키지 채택 1건(`2026-10-17-shared-review-engine-devices-design.md:216` — markdown-it-py 를 「사용자 검토 뒤 테스트에서만」, bashlex 는 GPLv3 라 기각).
      이 절들을 전수로 읽은 것은 아니고 「레포 밖」 줄만 봤다.
    touches: []
    decides: [OQ10]

  - id: RC8
    path: "plugins/spec-distill/scripts/check_bundle_coverage.py"
    anchor: "check_impl · REPORT_LINE_RE = r\"AC(\\d+): (구현됨|미룸|빠짐) — (\\S.*)\""
    line: 582
    claim: >
      구현 · 최종 리뷰 쪽에서 설계와 구현을 맞대는 지금의 자리는 AC 단위 보고다.
      넘김 줄(`references/epic-handoff.md:7`)이 「고른 실행 방식의 마지막 전체 리뷰」 에 AC 목록을 싣고
      「AC1: 구현됨 — 근거 꼴(판정은 구현됨 · 미룸 · 빠짐 중 하나)」 로 보고하게 하며, `--impl` 이 그 보고 파일을 읽는다.
      `check_impl` 이 보는 것은 보고 줄의 유무 · 판정 낱말 · 미룸 표와의 대조뿐이다. 코드도, 설계의 「있는 것 검토」 절도 읽지 않는다.
      그래서 「고른 것을 실제로 썼는가」는 설계문서가 그것을 AC 로 적었을 때만 이 길에 실리고,
      그때도 판정은 리뷰어의 한 줄 보고다(실행 방식이 고른 리뷰어, 기본 SDD 의 최종 리뷰어).
    touches: []
    decides: [OQ11]

  - id: RC9
    path: "plugins/spec-distill/agents/integration-reviewer.md"
    anchor: "## 볼 이음매 1–7"
    line: 46
    claim: >
      머지 전 통합 리뷰어의 일곱 이음매에 「설계가 고른 라이브러리 · 기능을 구현이 실제로 썼는가」는 없다.
      7번은 「함께 진행된 에픽의 설계 의도 — intents 의 Goals · Non-goals · 결정 기록 · 판정과 이 PR 이 어긋나거나」 로, 다른 에픽의 설계와 대조한다.
      이 파일에서 재사용 · 재구현 계열 낱말(있는 것 · 재사용 · reuse 등) 검색 0건.
      quality-gates 리뷰어 쪽도 같다. `plugins/quality-gates/agents/security-reviewer.md:32` 는
      「design or architecture critique」 와 「proposing alternative fixes when the existing approach is sound」 를 맡지 않는 일로 적는다.
    touches: []
    decides: [OQ11]

  - id: RC10
    path: "CLAUDE.md"
    anchor: "「막지 않는 것을 막는다고 믿게 만드는 선언은 없는 것보다 나쁘다.」 · 「**축 C 는 채널 «이름»의 실재까지만 재고 그 채널이 실제로 읽히는지는 못 잰다.**」"
    line: 66
    claim: >
      레포 규칙에 측정 장치를 직접 금하는 문장은 없다. 닿는 원칙은 둘이다.
      결정론 장치의 경제: `docs/philosophy/devbrew-harness-philosophy.md:79` 「훅·스크립트·강제 규칙 같은 결정론 장치는 … load-bearing일 때만 정당하다」,
      `:85` 「(재사용) 새로 만든 것은 유지할 표면이 되므로 레포 안 · 밖에 있는 것을 먼저 검토하고, 외부 것은 사용자가 검토한 뒤에 쓴다(P17).」
      검사가 재는 범위의 한계를 문면에 적는 관행: 위 축 C 문장.
    touches: []
    decides: [OQ10]

unanswered: >
  ① Shrives · Brennan (2015) 본문 — 일곱 특성의 정의, 좋은 설명과 상투 문구를 가르는 조작 기준, 코딩 절차를 읽지 못했다(초록만).
  ② GAO 22개 모범 관행 전체 목록과 다섯 단계 묶음, GAO-15-37 의 24개 목록 — 22개 중 11개와 10번의 이름만 본문에서 확인했다.
  ③ FRC 2025 연례 리뷰 PDF 본문(설명 질의 건수 · 판정 기준).
  ④ Seidl 외 (2013)의 유형 이름. Arcot 외 (2010)의 설명 분류는 초록에도 닿지 못했다.
  ⑤ LibraryDesignBench HTML 끝 1.8만 자, GAO-25-107092 끝 9천 자.
```

## 덧붙임

**서로 어긋나는 것 — 하나로 고르지 않았습니다.**
- FRC 의 설명 질 평가: 2021 리뷰는 「나아지지 않았다 · 대부분 상투 문구」, 2025 보도자료는 「점점 명확하고 의미 있다」, 2026-03 지침은 여전히 상투 문구와 준수 압력을 문제로 듭니다. 시점이 다릅니다.
- 레포의 측정 전례: 2026-10-11 로드맵은 「따로 재지 않고 사용자가 쓰면서 판단」(RC4)이고, 2026-11-14 로드맵은 토큰 기준선을 재고 다시 재기로 했습니다(RC3). 뒤쪽도 「측정 도구를 제품화하지 않는다」는 선은 지켰습니다.

**주문의 「Non-goal 로 둔 기록」은 실재하지만 범위가 좁습니다.** 그 문장은 2026-10-11 로드맵과 거기서 나온 설계문서의 Non-goal 이고, CLAUDE.md 나 철학 문서의 상시 규칙은 아닙니다(RC4).

**관측점 후보를 판정자 축으로 나눈 것(근거 정리일 뿐 권고가 아닙니다).**

| 판정자 | 관측점 | 스스로 밝힌 한계 |
|---|---|---|
| 요소 점검표를 사람이 읽음 | FRC 다섯 요소 | 평가자 · 채점 절차가 문서에 없음 |
| 관행별 증거량을 감사 기관이 5점 채점 | GAO AOA | 과정만 재고 결론의 옳음은 재지 않음 |
| 규칙 기반 정적 판정 | 2606.03907 의 import · 참조 여부, 2606.28430 의 참조 수 | 휴리스틱 의존, 토큰 일치가 「쓰임」 쪽으로 편향 |
| 행동 절제 | 2606.28430 의 no-op 뒤 테스트 재실행 | 대조 절제가 셋뿐 |
| LLM 감사자 한 개 | 2609.36730 의 실패 분류 | 사람 라벨 · 일치 검사 없음, 실행하지 않고 추론 |
| 사용자의 체감 | 레포 S32 | 기록이 남지 않음(조사자 관찰) |

**OQ11 에 가장 가까운 외부 근거**는 2606.28430 의 「죽은 라이브러리」(구현은 있는데 호출이 0)와 2606.03907 의 「import 만 되고 참조 없음」 구분입니다.

**읽은 레포 파일(절대경로).**
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/measurements.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/flexibility-audit.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/token-baseline.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md (및 같은 이름의 .audit.md)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-09-22-interview-research-specialization-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-09-06-interview-depth-redesign-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-09-21-designer-lens-review-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/references/epic-handoff.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/scripts/check_bundle_coverage.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/agents/integration-reviewer.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/skills/pm-interview/SKILL.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/plugins/spec-distill/CHANGELOG.md (1425행 부근)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/docs/philosophy/devbrew-harness-philosophy.md (P8)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/existing-framework-first/CLAUDE.md

Sources:
- [FRC — Improving the quality of 'comply or explain' reporting (March 2026)](https://www.frc.org.uk/docs/9178/html/)
- [FRC — Improving the quality of 'comply or explain' reporting (February 2021)](https://www.frc.org.uk/docs/1892/html/)
- [FRC — Review of Corporate Governance Reporting (November 2021)](https://www.frc.org.uk/docs/1337/html/)
- [FRC — 2025 annual review press release](https://www.frc.org.uk/news-and-events/news/2025/11/frc-annual-review-highlights-the-value-of-meaningful-explanations-in-corporate-governance-reporting-and-the-codes-flexibility/)
- [Shrives & Brennan (2015) — Northumbria portal record](https://researchportal.northumbria.ac.uk/en/publications/a-typology-for-exploring-the-quality-of-explanations-for-non-comp/)
- [Keay (2014) — Legal Studies abstract](https://www.cambridge.org/core/journals/legal-studies/article/abs/comply-or-explain-in-corporate-governance-codes-in-need-of-greater-regulatory-oversight/E36C5EB6E97052A41C6F1C88F480F7A3)
- [Seidl, Sanderson & Roberts (2013) — RePEc abstract](https://ideas.repec.org/a/kap/jmgtgv/v17y2013i3p791-826.html)
- [GAO-15-37](https://www.gao.gov/products/gao-15-37)
- [GAO-25-107092 (HTML)](https://files.gao.gov/reports/GAO-25-107092/index.html)
- [GAO-16-853](https://www.gao.gov/products/gao-16-853)
- [GAO-21-194](https://www.gao.gov/products/gao-21-194)
- [GAO-20-195G](https://www.gao.gov/products/gao-20-195g)
- [GAO-16-22](https://www.gao.gov/products/gao-16-22)
- [arXiv 2606.03907](https://arxiv.org/html/2606.03907)
- [arXiv 2606.28430](https://arxiv.org/html/2606.28430)
- [arXiv 2609.36730](https://arxiv.org/html/2609.36730)


## R5

### 지금 이해

(경로 a — 포화 판정 1 의 빈 곳 다섯 조사, 묶음 3) → open_questions 재개방: 조사 10 이 Phase 0 의 고르지 않은 선택지 「새로 들일 때만」의 설명을 되찾아 OQ9 가 이미 답이 걸린 결정임을 보였고, 포화 판정이 OQ11 을 새로 열었다.

[spec-distill] 포화 판정 1/5: 아직 — 빈 곳 5개, 다음: 보완안의 탐색 증거 · 이유 인정을 과거 설계 두세 건에 소급 적용해 그때 실제로 맞는 외부 후보가 있었는지 본다 · 조사 호출 7/60

함께 띄운 이유: 빈 곳 다섯은 서로 기대지 않는 질문이라 한 묶음으로 띄웠다.

- 확인 RC50 — 확인 — plugins/spec-distill/CHANGELOG.md#**능력 축소 — design doc 리뷰의 외부 prior-art 대조가 Claude·codex 양쪽에서 동시에 0 이 됐다.** — 주장과 일치(1.0.0 에서 설계문서 리뷰의 웹 대조가 꺼졌다. 그 전에는 「외부 prior-art 대조가 판정의 일부」였다) [조사 9]
- 확인 RC51 — 확인 — docs/superpowers/specs/2026-09-06-document-review-redesign-design.md#| S1 | 방향성 리뷰어의 웹 탐색은 brief 프로필의 `web: true` 로 흡수 — 주장과 일치(끈 이유는 「근거 폭이 본질인 축은 brief 의 방향성 하나뿐」 한 줄이고 설계가 혼자 닫은 결정으로 적혀 있다. 같은 설계의 OQ-C 가 다시 열 조건을 열린 채 남겼다) [조사 9]
- 확인 RC52 — 확인 — plugins/spec-distill/skills/spec-review/SKILL.md#subagent_type: "spec-distill:doc-critic" — 주장과 일치(설계문서 리뷰 skill 에는 웹 사본을 고르는 걸음이 없고 web · 웹 글자가 0건이다. 프로필 값만 바꾸면 codex 쪽만 켜진다) [조사 9]
- 확인 RC53 — 확인 — shared/tests/test_docreview_codex.sh#러너: web:false 프로필 → 두 kill switch 무관하게 웹 켜지 않음 — 주장과 일치(설계문서 프로필의 web false 를 실질로 잠그는 락) [조사 9]
- 확인 RC54 — 확인 — docs/superpowers/specs/2026-10-17-epic-conductor-design.md#결정 · 2026-10-17 · 접근 — 「1 · 외부 후보도 씁 (권장)」 — 주장과 일치(기본 기능 · superpowers · gh 의 사용 승인이 결정 줄 하나로 묶여 있다) [조사 10]
- 확인 RC55 — 확인 — docs/superpowers/specs/2026-10-20-dependency-portability-design.md#U1 · 결정 · 2026-10-20 · 사용자 — 주장과 일치(의존 표 행의 사용자 줄은 쓸지가 아니라 강도 · 없을 때 동작 · 판 규칙을 정한다. quality-gates 행은 지휘자 판단이다) [조사 10]
- 확인 RC56 — 확인 — docs/superpowers/specs/2026-10-23-rules-docs-cleanup-design.md#qg `dependencies.md` 의 `pr-review-toolkit` 행 — 주장과 일치(표가 생긴 뒤 더해진 행은 이것 하나이고 사용자 결정 줄 없이 들어갔다) [조사 10]
- 확인 RC57 — 확인 — docs/superpowers/interview/2026-11-15-existing-framework-first-interview.audit.md#선택지: 승인 유지 / 새로 들일 때만 / 기준 넘으면 묻지 않음 — 주장과 일치(audit 에는 라벨만 있다. 본체가 이 세션의 전사에서 설명을 되찾았다 — 승인 유지 「외부 것은 지금처럼 후보와 차이를 보이고 승인받은 뒤에만 쓴다」 · 새로 들일 때만 「이미 깔려 쓰고 있는 것은 묻지 않고 쓰고, 새로 설치하거나 의존에 더해야 하는 것만 승인받는다」) [조사 10]
- 확인 RC58 — 확인 — plugins/spec-distill/CHANGELOG.md#superpowers 7.0.0 brainstorming 에 맞췄다 — 주장과 일치(넘김 글은 7.0.0 모양에 맞춰 쓰였다) [조사 12]
- 확인 RC59 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#마지막 전체 리뷰는 설계문서 ## Acceptance Criteria 가운데 — 주장과 일치(마지막 리뷰에 얹는 것은 수용 기준 대조 · 과제 사이 이음매 · 계획이 쓴 테스트 코드 셋이다) [조사 12]
- 확인 RC60 — 확인 — plugins/spec-distill/agents/integration-reviewer.md### 볼 이음매 — 주장과 일치(「고른 것을 실제로 썼는가」는 목록에 없다) [조사 11 · 조사 12]
- 확인 RC61 — 확인 — plugins/spec-distill/scripts/repo_defaults.py#def strict_frontmatter — 주장과 일치(손으로 쓴 줄 단위 파서이고 표준 라이브러리만 쓴다) [조사 8]
- 확인 RC62 — 확인 — docs/superpowers/specs/2026-10-23-r8-device-leftovers-design.md#레포 밖: gh `pr view <번호> --json` · `pr create` 의 URL 출력. 새 외부 패키지는 쓰지 않는다. — 주장과 일치(세 설계문서에 조사가 찾은 후보 이름은 없다 — 걸린 글자는 무관한 낱말과 `fetch.followRemoteHEAD` 기본값 인용뿐) [조사 8]
- 확인 RC63 — 확인 — plugins/spec-distill/scripts/check_bundle_coverage.py#def check_impl — 주장과 일치(구현 쪽 대조는 수용 기준 단위 보고 줄만 읽는다. 「고른 것을 썼는가」는 설계가 수용 기준으로 적을 때만 이 길에 실린다) [조사 11]
- 확인 RC64 — 확인 — docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.audit.md#**S32** ☑ 선택 (round 22) — 주장과 일치(「내가 쓰면서 판단 — 개선 여부는 따로 재지 않고」 — 그 로드맵 범위의 사용자 결정) [조사 11]
- 확인 RC65 — 확인 — docs/superpowers/specs/2026-09-22-interview-research-specialization-design.md#**조사를 했는지를 나중에 재는 장치** — 주장과 일치(2026-09-10 에 사용자가 사후 측정 장치를 「쓰이지 않는 무게 · 번거로움 · 방향이 틀렸다」로 걷어냈다) [조사 11]
- 확인 RC66 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/token-baseline.md#측정 도구를 제품화하지 않는다 — 주장과 일치 [조사 11]
- 대체됨: 「상류 설계 skill 의 «When there's existing work, build on what it already uses» 는 설치본에서 찾지 못했다」 → 설치된 7.0.2 본문 127~128행에 줄바꿈에 걸쳐 실재한다 (조사 12)

웹 근거(본체가 직접 확인한 것):
- «superpowers-brainstorming» 설치된 7.0.2 의 설계 skill 은 대안 두세 개를 내놓고 하나를 추천해 고르게 하며, 있는 작업이 쓰는 것 위에 지으라고 적는다. 추천의 방향을 정하는 문장은 없다 — https://raw.githubusercontent.com/obra/superpowers/v7.0.2/skills/brainstorming/SKILL.md (1차 · 설치본에서 확인 2026-11-15) [→ OQ7]
- «superpowers-reviewers» 과제 리뷰와 마지막 전체 리뷰의 점검 목록에 라이브러리 · 의존 · 재구현을 이름으로 묻는 줄이 없다 — https://github.com/obra/superpowers/blob/v7.0.2/skills/requesting-code-review/code-reviewer.md (1차 · 설치본에서 확인 2026-11-15) [→ OQ11]
- «pypi-python-frontmatter» 머리말 파서 패키지는 Python 3.10 이상을 요구한다(레포 바닥 3.9.6) — https://pypi.org/pypi/python-frontmatter/json (1차 · 확인 2026-11-15) [→ OQ8]
- «gh-poi» 머지된 브랜치를 PR 상태로 가리는 gh 확장은 2021 년부터 있고 지금도 유지된다 — https://github.com/seachicken/gh-poi (1차 · 확인 2026-11-15) [→ OQ8]
- «gh-stack» GitHub 의 PR 묶음 확장은 2026-02 에 생겼고 브랜치별 PR 기록을 이 기계에만 둔다 — https://github.com/github/gh-stack (1차 · 확인 2026-11-15) [→ OQ8]

웹 근거(조사 보고 — 본체가 다시 읽지 못함, 확인 못 함):
- «arxiv-building-to-the-test» 테스트를 주면 점수는 만점에 가까운데 라이브러리는 불리지 않고, 라이브러리 본문을 비워도 점수가 그대로였다 — https://arxiv.org/html/2606.28430 (1차 · 조사 11 · 확인 못 함) [→ OQ11]
- «arxiv-build-vs-buy-protocol» import 만 되고 참조되지 않는 라이브러리를 쓰인 것과 가른다(결과 없는 사전 등록 프로토콜) — https://arxiv.org/html/2606.03907 (1차 · 조사 11 · 확인 못 함) [→ OQ10]
- «frc-comply-or-explain» 이탈 설명 74건 가운데 높은 질은 4건이었고, 밝힌 건수가 늘어도 설명의 질은 그대로일 수 있다 — https://www.frc.org.uk/docs/1892/html/ (1차 · 조사 11 · 확인 못 함) [→ OQ10]
- «gao-aoa-practices» 대안 분석 모범 관행은 과정만 재고 결론의 옳음은 재지 않는다고 스스로 적는다 — https://files.gao.gov/reports/GAO-25-107092/index.html (1차 · 조사 11 · 확인 못 함) [→ OQ10]

조사 호출 12/60 · 이 라운드 본체 직접 5
줄인 사실 3개
- 과거 설계 셋의 일 열여섯에 후보가 한둘씩 있었으나 후보마다 일의 일부만 덮고 배포 조건에서 붙는 것이 있다(조사 8 의 건별 표).
- 이미 의존인 git · gh · Claude Code 안에 설계가 언급하지 않은 내장 기능이 있었다(`git config --blob` 은 설치된 git 2.54.0 에서 확인, `fetch.followRemoteHEAD` 의 warn · always 값은 설치본 도움말에서 찾지 못함).
- 레포가 적은 superpowers 판은 7.0.0 이고 설치된 판은 7.0.2 다. 대안 · 추천 걸음은 7.0.1 에서 생겼다(조사 12).

### 다음 결정

OQ9: Claude Code 기본 기능과 이미 의존으로 적힌 것의 승인 · 추천: 묶어서 한 번 — 「승인 유지」를 지키면서 실제로 있었던 유일한 선례와 같고 질문 수를 늘리지 않는다 · 트레이드오프: 묶어서 한 번(선례와 같음) / 묻지 않고 이름으로 적는다(지금 관행과 같지만 Phase 0 에서 고르지 않은 쪽) / 하나씩 승인(글자대로, 승인 질문이 가장 많다)
OQ11: 구현 · 최종 리뷰에서 「고른 것을 실제로 썼는가」를 보는 자리를 범위에 넣는가 · 추천: 넣는다 — 설계 필수 위험으로 고른 「구현에서 다시 만듦」(S8)이 닿을 자리가 지금 없고, 이미 있는 넘김 글의 한 문장으로 닿는다 · 트레이드오프: 넣는다(seed 의 범위를 계획 뒤로 한 걸음 넓힌다) / 넣지 않는다(위험으로만 남는다)
열린 질문 목록: OQ7 · OQ8 · OQ10 · OQ13 을 설계로 넘길지 · 추천: 넷 다 설계로 — S11 과 같은 판단이고 조사 재료가 늘었다 · 트레이드오프: 넷 다 설계로 / 웹 대조는 지금 정한다

### 질문

(경로 b — 판단) AskUserQuestion 한 번에 셋: 이미 쓰는 것의 승인 · 구현 뒤 확인을 범위에 넣는가 · 열린 질문 목록.

### 답

→ S12 (OQ9 — 묶어서 한 번)
→ S13 (OQ11 — 넣는다)
→ S14 (열린 질문 목록 — 넷 다 설계로)

원장: open_questions 다시 닫음(S14 — 재개방 뒤 새 근거). OQ9 · OQ11 해결.
seed 뒤집음(P23): 원래 — seed 의 「이번 일은 규칙 문장과 인터뷰, 설계, 계획 단계가 프레임워크를 먼저 고르게 바꾸는 데까지이고」(사용자 확인) / 재결정 — 계획 · 구현으로 넘기는 글이 마지막 리뷰에서 「설계가 고른 것을 실제로 썼는가」를 보게 하는 것까지 범위에 넣는다(S13). 이미 만든 장치를 조사하거나 옮기지 않는다는 부분은 그대로다 / 근거 — 설계 필수 위험으로 고른 「구현에서 다시 만듦」(S8)이 닿을 자리가 계획 뒤에 있고 지금 그 자리에 보는 줄이 없다(RC59 · RC60 · RC63).
Phase 0 답과의 관계(OQ9): 「승인 유지」(외부 것은 지금처럼 후보와 차이를 보이고 승인받은 뒤에만 쓴다)는 그대로이고, 이미 쓰는 것의 승인 꼴만 「묶어서 한 번」으로 정했다(S12) — 뒤집음이 아니라 정밀화다.

## R6

### 지금 이해

[spec-distill] 포화 판정 2/5: 아직 — 빈 곳 6개, 다음: 웹이 켜진 brief 리뷰가 「더 성숙한 외부 대안」 지적을 실제로 냈는지와 그 지적이 확정 항목을 바꿨는지 본다 · 조사 호출 12/60

반복 감지: 빈 곳 「내장 후보를 설계 요구 문장과 맞대어 맞았을지 가르기」는 닿는 결정(OQ8 · OQ10)과 장치(레포 조사)가 판정 1 의 둘째 빈 곳과 같다 — 같은 빈 곳이라 혼자 다시 돌리지 않고 사용자에게 묻는다.
본체가 바로잡은 것(판정 2 의 여섯째 빈 곳): 재개 사유에 「조사 10 이 설명을 되찾아」라고 적었으나 조사 10 은 그 설명이 audit 에 없음을 보였을 뿐이고, 설명을 되찾은 것은 본체가 이 세션 전사에서 한 일이다 — 원장 문장을 고쳤다. OQ9 를 닫은 근거는 사용자 답 S12 다.
- 대체됨: 「조사 10 이 Phase 0 의 「새로 들일 때만」 설명을 되찾았다」 → 조사 10 은 그 설명이 audit 에 없음을 보였고 본체가 이 세션 전사에서 되찾았다 (조사 10)
판정자가 연 결정: OQ14(규칙을 얹을 상류 걸음이 레포가 적은 판에 없다 — 기준 판을 올리는가 판에 매이지 않는 문장으로 쓰는가 — 열림).

조사 호출 12/60 · 이 라운드 본체 직접 0

### 다음 결정

포화: 같은 빈 곳이 되풀이됐을 때 더 조사할지 끝낼지 · 추천: 포화로 보고 종료 — 남은 열린 결정은 모두 설계로 넘기기로 했고(S11 · S14), 남은 빈 곳은 그 결정들의 재료를 더 다듬는 것이라 설계 세션이 자기 조사로 이어 갈 수 있다 · 트레이드오프: 포화로 보고 종료(여기서 brief) / 한 번 더 조사(조사 넷과 실행 관찰 하나, 그 뒤 판정을 다시 받는다) / 인터뷰 종료(조사가 덜 됐다는 표시를 남기고 brief)

### 질문

(saturation.md 반복 감지의 질문) 포화로 보고 종료 / 한 번 더 조사 / 인터뷰 종료

### 답

→ S15 (포화 — 포화로 보고 종료)

원장: 열린 질문은 다섯이다(OQ7 · OQ8 · OQ10 · OQ13 · OQ14) — S15 가 OQ14 를 더한 목록을 설계로 넘기는 것을 확인했다. 조사하지 않고 남긴 빈 곳 다섯(판정 2)은 brief 의 열린 질문 재료로 싣는다.

## R7

### 지금 이해

brief 리뷰 1라운드의 게이트다(인터뷰 질문 라운드가 아니다). 리뷰가 사용자 결정 넷과 저자가 고칠 곳 다섯을 냈다. 경로 (a) 로 본체가 직접 확인한 것: 리뷰어가 든 공개 skill search-first 는 공개 저장소(everything-claude-code)에 실재하고 MIT 이며 저장소는 2026-11-09 까지, 그 skill 파일은 2026-09-27 까지 갱신됐다. 판정은 그대로 쓰기 · 얹어 쓰기 · 조합 · 직접 만들기 넷이다. 같은 계열의 search-before-building 은 목록 페이지만 읽었다(개인 저장소 · 별 7 · 마지막 커밋 2026-06-06).
→ open_questions: OQ12 를 다시 열었다 — 「해결(S6)」 표기가 S6 의 글자(의존 쪽 비용을 정당한 이유로 인정)보다 넓었다(이유의 종류 목록 · 부분 채택은 사용자가 고르지 않았다). OQ15 를 새로 열었다(같은 일을 하는 공개 skill 을 그대로 쓰는가 판정 틀만 빌리는가 직접 쓰는가).

조사 호출 12/60 · 이 라운드 본체 직접 2

### 다음 결정

리뷰 결정 넷 — 목표 밖의 「측정 장치를 만들지 않는다」 줄 · 「의존이 생긴다」를 정당한 이유로 인정하는 범위 · 규칙을 두는 자리와 「읽는 눈」의 충돌 · 같은 일을 하는 공개 skill 을 후보로 올릴지 · 추천: 넷 다 고친다 · 트레이드오프: 고친다(채택) / 그대로 둔다(기각) / 나중에 정한다(보류)

### 질문

(리뷰 엔진 라운드 게이트의 질문 넷 — 선택지는 고친다 / 그대로 둔다 / 나중에 정한다)

### 답

→ S17 · S18 · S19 · S20

## R8

### 지금 이해

brief 리뷰 2라운드의 게이트다(인터뷰 질문 라운드가 아니다). 1라운드의 결정 넷은 반영됐고 다시 지적되지 않았다. 리뷰가 사용자 결정 둘과 저자가 고칠 곳 둘을 냈고, 재비판이 지적 하나를 기각했다. 경로 (a) 로 본체가 직접 확인한 것: 리뷰어가 든 공개 skill 보안 조사(skill 3,984개 · 보안 결함 36.82% · 치명 결함 13.4% · 확인된 악성 76건 · skill 은 에이전트 권한을 그대로 물려받는다)와 GitHub 가짜 별 연구(약 600만 개 — 초록만 읽었고 저장소 수는 초록에 없다)는 원문과 맞는다.

조사 호출 12/60 · 이 라운드 본체 직접 2

### 다음 결정

리뷰 결정 둘 — 후보마다 보이는 정보에 안전을 알리는 칸을 더할지 · 「새 장치는 만들지 않는다」가 규칙을 나르는 장치만 가리키는지 이번 일 전체를 가리키는지 · 추천: 둘 다 고친다(안전 칸을 더한다 · 규칙을 나르는 장치만) · 트레이드오프: 고친다(채택) / 그대로 둔다(기각) / 나중에 정한다(보류)

### 질문

(리뷰 엔진 라운드 게이트의 질문 둘 — 선택지는 고친다 / 그대로 둔다 / 나중에 정한다)

### 답

→ S21 · S22

## R9

### 지금 이해

brief 리뷰 3라운드(재리뷰 상한 도달)의 승인 게이트 1단계다(인터뷰 질문 라운드가 아니다). 2라운드의 결정 둘은 반영됐고 다시 지적되지 않았다. 리뷰가 사용자 결정 하나와 저자가 고칠 곳 넷을 냈고, 재비판이 지적 하나를 기각했다. codex 는 사용 한도에 걸려 이 라운드에 돌지 못했다. 경로 (a) 로 본체가 직접 확인한 것: 이 일이 고칠 자리가 돌고 있는 지휘자 맥락 경제 로드맵의 예약 경로와 겹친다.
- 확인 RC67 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#R2 — 지휘 절차 개편 — 주장과 일치 — 팀 파일 규약 에픽(R1)의 경로 예약에 에픽 넘김 글이 있고, 지휘 절차 개편 에픽(R2)의 경로 예약에 규칙 문서 · 철학 문서 · 구현 담당자 틀 · 설계문서 리뷰 프로필이 있으며 R2 의 의도는 절차서를 단계표와 지시서로 쪼개고 작업 방식 결합을 푸는 것이다. 재분해 이력은 R2 경로 예약에서 인터뷰 끝맺음 절차 파일을 뺐다고 적는다
→ open_questions: OQ16 을 새로 열었다(두 일의 순서를 어떻게 두는가).

조사 호출 12/60 · 이 라운드 본체 직접 1

### 다음 결정

리뷰 결정 하나 — 돌고 있는 로드맵과의 겹침을 brief 에 싣는가(실으면 두 일의 순서가 OQ16 으로 열린다) · 추천: 고친다 — 위험과 열린 질문으로 싣는다 · 트레이드오프: 고친다(채택) / 그대로 둔다(기각) / 나중에 정한다(보류). 함께 물은 것: 추가 라운드 1회를 여는가 · 추천: 열지 않음 — 라운드마다 정할 것이 줄었고 codex 가 한도에 걸려 있다 · 트레이드오프: 열지 않음(고친 다섯 곳을 리뷰어가 다시 보지 않는다) / 열기(탐지 1 · 재비판 1 이 더 돈다)

### 질문

(리뷰 엔진 승인 게이트 1단계의 질문 둘 — 열린 결정 하나의 고친다 / 그대로 둔다 / 나중에 정한다, 추가 라운드의 열지 않음 / 열기)

### 답

→ S23 · S24

## audit §2 대기 줄

- 포화 판정 1: 아직 — 빈 곳 5개
- 포화 판정 2: 아직 — 빈 곳 6개
- 포화 판정 2: 사용자 판단 포화(@S15) — 반복 빈 곳
