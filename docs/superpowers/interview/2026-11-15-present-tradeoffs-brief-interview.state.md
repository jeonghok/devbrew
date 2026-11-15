---
type: interview-state
seed: docs/superpowers/interview/2026-11-15-present-tradeoffs-interview.md
session_id: 34dcab50-d8b4-4d46-a347-1199115da8bb
phase: 1
coverage:
  floor:
    root_problem:   {status: closed, evidence: "S1 — 「전반적으로 트레이드 오프를 같이 제시해줘야함」 · 「리뷰어가 리뷰한뒤에 나한테 ask question하는데 설명이 비어있음 그리고 위를 보라는데 위에 아무것도 없음 설명도 부족」 / S8 — 「글자는 있었지만 내용이 없었다」", reopened: 0, reopen_log: []}
    landscape:      {status: closed, evidence: "S16 — 바깥 선례의 처분(취함 셋 · 피함 하나를 이대로 받아들인다)", reopened: 0, reopen_log: []}
    skepticism:     {status: closed, evidence: "S10 — ST1 의 방향 판정(보완)", reopened: 0, reopen_log: []}
    blind_spot:     {status: closed, evidence: "S14 — 숨은 가정 · 실패 양식 일곱을 전부 위험으로 넘긴다", reopened: 0, reopen_log: []}
    open_questions: {status: closed, evidence: "S18 — 설계에 넘길 열린 질문 여섯을 이대로 넘긴다", reopened: 0, reopen_log: []}
  derived:
    - {name: internal_research, rationale: "레포 주장(RC1–RC61)이 처음 산출됐다 — 지금 증상을 처방하는 기존 규칙 · 그 문면을 잠근 테스트 · 이미 대가를 내는 자리(엔진 렌더 · 인터뷰 규약 · 지휘자 규칙)를 함께 다룬다", status: closed, evidence: "S17 · S24 — 레포에 이미 있는 것을 옮겨 쓰되 리뷰어 글은 모델이 줄인 요약으로 싣고 전문은 앞 글에 남긴다", reopened: 1, reopen_log: [{round: 7, reason: "리뷰어 글을 그대로 싣는다는 처분이 요약으로 바뀌었다", conflicts_with: S17}]}
    - {name: screen_channel, rationale: "「위에 아무것도 없음」의 원인이 셋으로 갈리고 고칠 자리가 다르다 — 모델이 안 썼다 / 질문 창이 가렸다 / 화면과 기록에서 사라졌다(#75182)", status: closed, evidence: "S2 · S7 · S10 · S19 · S20 · S25 — 화면 확인 · 이유와 대가를 질문 안으로 · 질문 창이 정본 통로 · 화면 시험 · 경고는 요약 한 줄로", reopened: 1, reopen_log: [{round: 7, reason: "경고를 셋까지 한 줄씩 싣는다는 답이 요약 한 줄로 바뀌었다", conflicts_with: S11}]}
    - {name: prior_decisions, rationale: "2026-10-27 인터뷰의 확정(D16 이유는 질문 위 글에 · D13 외부 skill 질문은 그 skill 몫 · C17 강제 장치 금지)이 이 일의 선택지를 막거나 뒤집힌다 — 사용자 동의로 재결정할 항목", status: closed, evidence: "S7 · S5 · S10 — D16 재결정 · D13 유지 · 실행 중 검사 장치 없음(C17 유지)", reopened: 0, reopen_log: []}
    - {name: ownership_boundary, rationale: "범위의 예 셋 중 설계 · 계획은 외부 skill 이 메시지 모양을 정한다 — devbrew 가 글을 쓰는 표면이 어디까지인가", status: closed, evidence: "S5 — 설계 · 계획 대화는 그 skill 에 맡긴다", reopened: 0, reopen_log: []}
    - {name: minimum_content, rationale: "리뷰 뒤 질문에는 추천을 다는 자리와 일부러 비우는 자리가 섞여 있다 — 추천 없는 질문에서 화면에 실어야 하는 최소가 무엇인가", status: closed, evidence: "S9 · S10 — 리뷰 결정 질문 안의 셋 · 추천 없는 질문에는 얻음 · 내줌을 억지로 채우지 않는다", reopened: 0, reopen_log: []}
    - {name: prose_recommendation_sites, rationale: "확정 범위에 「모델이 한쪽을 권하는 글」이 들었는데 그런 문장 권고 자리의 목록이 레포에 없다", status: closed, evidence: "S12 — 문장 권고 자리 셋에 대가 한 구절", reopened: 0, reopen_log: []}
    - {name: verification_method, rationale: "기준 측정(세션 기록의 글자 수 · 낱말 맞추기)은 화면에 무엇이 보였는지를 담지 않는다 — 고쳐졌는지를 무엇으로 확인하나", status: closed, evidence: "S13 — 기록 재측정과 화면 확인 둘 다", reopened: 0, reopen_log: []}
orchestration:
  focused_dimension: screen_channel
  research_dispatches: {coverage_mapper: 1, blind_spot_prober: 1, steelman_builder: 1, repo_researcher: 3, open_researcher: 1}
  research_limit: 60
  saturation_limit: 5
  research_log:
    - {n: 1, device: coverage_mapper, round: 1, batch: 1, changed: [OQ1, OQ2, OQ3, OQ4, OQ5, OQ6], opened: [OQ7, OQ8, OQ9, OQ10, OQ11], summary: "파생 차원 여덟 제안 · 질문 앞 글이 화면과 기록에서 사라지는 버그(#75182) · 지난 인터뷰 확정 D16 · D13 · C17 과의 충돌"}
    - {n: 2, device: repo_researcher, round: 1, batch: 1, changed: [OQ1, OQ3, OQ4, OQ6], opened: [], summary: "리뷰 뒤 결정 질문 자리와 칸 규칙 · 「위에 적었다」가 규칙이 처방한 문면 · 설명 칸 내용을 재는 검사는 없음"}
    - {n: 3, device: open_researcher, round: 1, batch: 1, changed: [OQ3, OQ4, OQ5, OQ6], opened: [], summary: "표면별 질문 창 동작과 changelog · 다른 plugin 의 질문에 닿는 공식 수단(훅 · mod) · 추천과 대가를 함께 보이는 바깥 선례와 쏠림 연구"}
    - {n: 4, device: orchestrator, round: 1, batch: 2, changed: [OQ6, OQ7], opened: [], summary: "RC1–RC61 확인 · #75182 · #45384 1차 확인 · 세션 기록 재측정(모델별 · 생각 블록 · preview 칸)"}
    - {n: 5, device: blind_spot_prober, round: 2, batch: 3, changed: [OQ3, OQ4, OQ10, OQ11], opened: [OQ12], summary: "숨은 가정 여섯 · 실패 양식 일곱 — 창 안 글도 잘릴 수 있다 · 경고 목록도 앞 글에 실린다 · 공통 규칙 한 줄만 고치면 지역 규칙이 이긴다 · 대가 줄이 형식 채우기로 퇴화한다"}
    - {n: 6, device: steelman_builder, round: 2, batch: 4, changed: [OQ3, OQ4, OQ10, OQ11], opened: [], summary: "ST1 — 전제 충돌 0건 · 추천 보완(창이 정본 통로 · 앞 글은 덤 · 길이 상한 · 훅 없음) · 전제 목록 결함 다섯(경고 줄 · 창 안도 실패한다 · 짧음과 되풀이는 다르다 · 누가 줄이는가 · P4 의 근거 셋)"}
    - {n: 7, device: orchestrator, round: 3, batch: 5, changed: [OQ3], opened: [], summary: "RC62–RC88 확인 · 훅 문서 일부 확인 · 깔린 판 2.1.325 · R2 앞 글도 기록에 남음"}
    - {n: 8, device: orchestrator, round: 4, batch: 6, changed: [], opened: [], summary: "Microsoft command link 지침을 1차로 확인"}
    - {n: 9, device: orchestrator, round: 6, batch: 7, changed: [OQ12, OQ14], opened: [], summary: "경고를 질문 밖으로 뺀 이유(2026-10-08 설계 목표 4) · 리뷰 렌더 줄 길이 재측정 · 리뷰어 칸의 길이 규칙 없음 · token_boundary.py 는 측정 도구"}
    - {n: 10, device: orchestrator, round: 6, batch: 8, changed: [OQ13], opened: [], summary: "깔린 판 2.1.325 화면 시험 — 선택지 넷 × 설명 약 180자 × 본문 경고 세 줄이 끝까지 보였다(한 번)"}
    - {n: 13, device: orchestrator, round: 9, batch: 10, changed: [OQ15], opened: [], summary: "추천 선택지 설명 표본 24개 중 내주는 것을 적은 것은 8개 · 토큰 경계는 재지 못함"}
    - {n: 14, device: orchestrator, round: 9, batch: 11, changed: [OQ13, OQ19], opened: [], summary: "화면 시험 — 약 300자 · 480자 설명 넷이 끝까지 보였다 · 기타 칸에 글자를 적어 답할 수 있었다"}
    - {n: 11, device: repo_researcher, round: 8, batch: 9, changed: [OQ19, OQ18], opened: [], summary: "옮김 대조는 요약의 뜻을 보지 않는다 · 리뷰어 세 칸의 정의와 락 · 줄이기 규칙이 자리마다 다르다 · 칸을 더할 때 고칠 자리"}
    - {n: 12, device: repo_researcher, round: 8, batch: 9, changed: [OQ16, OQ17, OQ18], opened: [], summary: "낮춘 지적 게이트의 접힘에는 이유 기록이 없다 · 비움 자리 다섯이 싣는 것 · 지휘자 의견 줄과 공통 규칙 구절을 잠근 테스트 · token_boundary.py 의 입출력"}
    - {n: 15, device: orchestrator, round: 10, batch: 12, changed: [], opened: [], summary: "RC92–RC135 확인(확인 43 · 미확인 1)"}
    - {n: 16, device: orchestrator, round: 10, batch: 13, changed: [OQ13], opened: [], summary: "기타 칸에 답한 뒤에도 질문과 설명이 화면에 남았다(한 번)"}
    - {n: 17, device: orchestrator, round: 11, batch: 14, changed: [OQ15], opened: [], summary: "추천 선택지 설명 49개를 단계별로 가름 — 내주는 것을 적은 것 10개 · 지휘자 쪽이 가장 높다"}
    - {n: 18, device: orchestrator, round: 11, batch: 15, changed: [OQ18], opened: [], summary: "공통 규칙 블록의 길이 여유 — 가장 좁은 plugin-audit 가 보수 근사 187토큰"}
    - {n: 19, device: orchestrator, round: 11, batch: 16, changed: [], opened: [], summary: "좁은 창 · 한 호출에 질문 넷 — 리뷰 뒤 질문의 꼴 셋이 다 보였다(한 번)"}
  saturation_log:
    - {k: 1, round: 5, verdict: not_saturated, basis: "최근 두 묶음(5 · 6)은 결정을 바꾸지도 열지도 않았으나 아직 보지 않았고 결정을 바꿀 수 있는 자리 넷이 남았다", gaps: ["5.1.0 에서 경고 목록을 질문 밖으로 뺀 이유 — may_change OQ12 · OQ4 — repo-researcher", "깔린 판 2.1.325 의 실제 화면에서 잘림 재기 — may_change OQ13 · OQ12 · OQ4 · OQ16 — orchestrator", "리뷰 렌더의 그대로 두면 · 고치면 줄 길이 분포 — may_change OQ14 · OQ16 — orchestrator", "token_boundary.py 의 여유와 다른 리뷰어 설정의 길이 규칙 — may_change OQ18 · OQ14 — repo-researcher"], user_choice: null}
    - {k: 2, round: 7, verdict: not_saturated, basis: "최근 두 묶음(7 · 8)이 모두 결정을 바꿨다 — OQ12 · OQ14 · OQ13", user_choice_note: "S26 더 조사한다", gaps: ["화면 시험에서 재지 않은 것(300자 · 480자 설명 · 좁은 창 · 질문 넷 · 기타 칸) — may_change OQ13 · OQ14 · OQ12 · OQ19 — orchestrator", "요약이 원문의 뜻을 바꾸지 않게 하는 레포 안 장치와 리뷰어가 짧은 칸을 쓰게 하는 길 — may_change OQ19 · OQ14 — repo-researcher", "이미 대가를 내는 자리의 실제 글에서 형식 채우기가 얼마나 일어나는지 — may_change OQ15 · OQ18 — orchestrator", "낮춘 지적 게이트가 넷 이상에서 접는 이유와 비움 자리 다섯이 싣는 것 — may_change OQ16 · OQ17 — repo-researcher", "지휘자 의견 줄을 잠근 자리와 새 문면의 토큰 경계 — may_change OQ18 — repo-researcher"], user_choice: S26}
    - {k: 3, round: 10, verdict: not_saturated, basis: "최근 두 묶음(12 · 13)은 결정을 바꾸지도 열지도 않았으나 열린 결정을 겨눈 조사가 아니었고 빈 곳 셋이 남았다", gaps: ["추천 선택지 설명을 자리 종류별로 갈라 다시 보기 — may_change OQ15 — orchestrator", "지금 문면에서 SKILL.md 10개의 토큰 경계 여유 — may_change OQ18 — orchestrator", "한 호출에 질문 넷 · 좁은 창의 화면 — may_change OQ18 · OQ19 — orchestrator"], user_choice: null}
    - {k: 4, round: 11, verdict: not_saturated, basis: "최근 두 묶음(15 · 16) 가운데 묶음 15 가 OQ18 을 바꿨다", gaps: ["새 문면 후보를 적어 토큰 경계를 다시 재기 — may_change OQ18 — orchestrator", "좁은 창에서 긴 설명(300자 이상) — may_change OQ19 · OQ16 · OQ18 — orchestrator", "낮춘 지적 게이트가 넷 이상에서 접은 이유를 git 이력에서 — may_change OQ16 — orchestrator", "라벨 압축이 뜻을 바꾼 사례를 세션 기록에서 대조 — may_change OQ19 — orchestrator", "추천을 낸 쪽이 대가를 적을 때 형식 채우기를 줄인 선례 — may_change OQ15 — open-researcher"], user_choice: S35}
  open_decisions:
    - id: OQ1
      text: "리뷰 뒤 결정 질문 문제에 어떤 범위가 걸리는가 — 추천의 대가 문제와 같은 「방향을 정하는 자리」만인가, 리뷰 뒤 결정 질문 전부인가"
      dimension: root_problem
      status: resolved
      resolved_by: S6
    - id: OQ2
      text: "요청을 정리하는 단계(request-framing)가 「방향을 정하는 자리」에 드는가"
      dimension: root_problem
      status: resolved
      resolved_by: S4
    - id: OQ3
      text: "어떻게 지키게 할지 — 규칙 문장만 둘지 검사까지 둘지"
      dimension: open_questions
      status: open
      resolved_by: null
    - id: OQ4
      text: "화면의 어느 칸(질문 본문 · 선택지 설명 · 질문 앞 글)에 무엇을 실을지"
      dimension: open_questions
      status: resolved
      resolved_by: S10
    - id: OQ5
      text: "devbrew 밖 skill(superpowers 의 brainstorming)이 띄우는 설계 단계 질문까지 이 일이 닿게 할지"
      dimension: ownership_boundary
      status: resolved
      resolved_by: S5
    - id: OQ6
      text: "사용자가 본 「설명 칸이 없던」 화면이 무엇이었는지"
      dimension: root_problem
      status: resolved
      resolved_by: S8
    - id: OQ7
      text: "질문 앞 글이 화면에서 사라질 수 있다고 보고 질문만 보고 고를 수 있게 할지 — 앞 글에 기대는 지금 방식을 둘지"
      dimension: screen_channel
      status: resolved
      resolved_by: S10
    - id: OQ8
      text: "지난 확정 「추천의 이유는 질문 위 글에 둔다」(2026-10-27 D16)를 다시 정할지"
      dimension: prior_decisions
      status: resolved
      resolved_by: S7
    - id: OQ9
      text: "추천이 없는 문서 리뷰 뒤 결정 질문에서 화면에 실어야 하는 최소 내용"
      dimension: minimum_content
      status: resolved
      resolved_by: S9
    - id: OQ10
      text: "질문 밖 「권하는 글」 자리를 무엇으로 찾고 어디까지 넣을지"
      dimension: prose_recommendation_sites
      status: resolved
      resolved_by: S42
    - id: OQ11
      text: "고쳐졌는지를 무엇으로 확인할지"
      dimension: verification_method
      status: resolved
      resolved_by: S13
    - id: OQ12
      text: "경고(degrade) 목록을 질문 창 안에 한 줄씩 실을지 — 「경고 N개 — 위에 적었다」가 가리키는 것이 이 목록이다"
      dimension: screen_channel
      status: resolved
      resolved_by: S25
    - id: OQ13
      text: "지금 깔린 판에서 질문 창 안 글이 얼마까지 보이는지(선택지 수 × 설명 줄 수)를 실제 화면에서 재기"
      dimension: screen_channel
      status: open
      resolved_by: null
    - id: OQ14
      text: "리뷰어의 「그대로 두면 · 고치면」이 길 때 누가 줄이는지"
      dimension: minimum_content
      status: resolved
      resolved_by: S24
    - id: OQ15
      text: "「얻음 · 내줌」이 형식 채우기가 되는 것을 무엇으로 막을지"
      dimension: blind_spot
      status: open
      resolved_by: null
    - id: OQ16
      text: "코드 리뷰에서 낮춘 지적이 넷 이상이라 선택지가 둘로 접힐 때 항목별 내용을 어디에 실을지"
      dimension: minimum_content
      status: open
      resolved_by: null
    - id: OQ17
      text: "추천을 일부러 비우는 질문에 실을 내용의 세부"
      dimension: minimum_content
      status: open
      resolved_by: null
    - id: OQ18
      text: "공통 규칙과 지휘자 의견 줄의 새 문면"
      dimension: prose_recommendation_sites
      status: open
      resolved_by: null
    - id: OQ19
      text: "모델이 쓴 요약이 리뷰어 글의 뜻을 바꾸지 않게 하는 방법 — 질문을 짜는 쪽이 리뷰어의 지적을 줄인다"
      dimension: internal_research
      status: open
      resolved_by: null
    - id: OQ20
      text: "리뷰 뒤 질문에서 「그대로 두면 · 고치면」을 질문 본문과 선택지 설명 가운데 어느 칸에 실을지"
      dimension: minimum_content
      status: open
      resolved_by: null
    - id: OQ21
      text: "코드 리뷰 질문의 질문 창 안에 무엇을 실을지"
      dimension: minimum_content
      status: open
      resolved_by: null
    - id: OQ22
      text: "리뷰어 글의 전문(줄이기 전 지적)을 어디에 둘지"
      dimension: screen_channel
      status: open
      resolved_by: null
trivia_escape_armed: false
user_statements:
  - id: S2
    source: chosen
    round: 1
    text: "보인다 — 질문 창 위에 확인용 문장이 든 글이 지금 보인다(화면 확인 질문)"
  - id: S3
    source: chosen
    round: 1
    text: "문서 리뷰 셋 (권장) — 리뷰 뒤 결정 질문은 설계문서 · brief · seed 리뷰 셋을 고친다"
  - id: S4
    source: chosen
    round: 1
    text: "넣는다 (권장) — 요청을 정리하는 단계(request-framing)의 질문에도 추천의 대가를 적는다"
  - id: S5
    source: chosen
    round: 1
    text: "그 skill 에 맡긴다 (권장) — 설계 · 계획 대화(외부 skill)는 그 skill 에 맡긴다"
  - id: S6
    source: chosen
    round: 2
    text: "이번에 넣는다 — 코드 리뷰(quality-gates)의 질문도 이번 범위에 넣는다(S3 의 범위를 넓힌다)"
  - id: S7
    source: chosen
    round: 2
    text: "이유와 대가를 질문 안으로 (권장) — 지난 확정 「추천의 이유는 질문 위 글에」를 다시 정해, 추천의 이유와 대가를 질문 안으로 옮긴다"
  - id: S8
    source: chosen
    round: 2
    text: "글자는 있었지만 내용이 없었다 — 설명 칸에 글은 있었는데 라벨을 되풀이하거나 너무 짧아서 없는 것과 같았다"
  - id: S9
    source: chosen
    round: 2
    text: "무엇이 문제인지 (권장), 그대로 두면 어떻게 되는지 (권장), 고치면 무엇이 바뀌는지 (권장) — 문서 리뷰 뒤 결정 질문의 질문 창 안에 있어야 하는 것(리뷰어의 근거는 고르지 않음)"
  - id: S10
    source: chosen
    round: 3
    text: "보완 (builder·orchestrator 추천) — 질문 창만 보고 고를 수 있게 하되 설명은 한 줄(길어도 세 줄)로 묶고 앞 글은 덤으로 남긴다. 추천 없는 질문에는 얻음 · 내줌을 억지로 채우지 않고 실행 중 검사 장치는 두지 않는다(ST1 방향 판정)"
  - id: S11
    source: chosen
    round: 4
    text: "첫 질문 본문에 한 줄씩 (권장) — 경고 목록을 질문 앞 글에만 두지 않고 첫 질문 본문에 한 줄씩 싣는다"
  - id: S12
    source: chosen
    round: 4
    text: "셋 모두에 대가 한 구절 (권장) — 질문 밖 「권하는 글」 자리 셋(분해 권고 한 줄 · 다음 단계 제안 이유 한 줄 · 지휘자 의견 한 줄)에 대가 한 구절을 붙인다"
  - id: S13
    source: chosen
    round: 4
    text: "기록 재측정과 화면 확인 둘 다 (권장) — 고쳐졌는지는 세션 기록 재측정과 실제 화면 확인 둘 다로 확인한다"
  - id: S14
    source: chosen
    round: 4
    text: "전부 위험으로 넘긴다 (권장) — 조사가 낸 실패 양식 일곱을 전부 설계가 다룰 위험으로 넘긴다"
  - id: S15
    source: chosen
    round: 5
    text: "셋까지 싣고 나머지는 개수 (권장) — 경고가 많으면 첫 질문 본문에 셋까지 싣고 나머지는 개수로 알린다"
  - id: S16
    source: chosen
    round: 5
    text: "이대로 받아들인다 (권장) — 바깥 선례의 취함 셋(추천 표시는 라벨에 · 이유와 결과는 선택지 아래 설명에 세 줄 이내 · 선택지마다 결과와 불이익을 그 옆에 · 모든 선택지를 같은 꼴로)과 피함 하나(질문 안에 근거와 풀이를 길게 싣는 형식)"
  - id: S17
    source: chosen
    round: 5
    text: "있는 것을 옮겨 쓴다 (권장) — 리뷰어가 이미 쓰는 세 칸 · 인터뷰의 추천 · 트레이드오프 한 줄 형식 · 지휘자 규칙의 「질문만 봐도 결정할 수 있게」 문장을 옮겨 쓰고, 기존 규칙 셋을 함께 고친다"
  - id: S18
    source: chosen
    round: 5
    text: "이대로 넘긴다 (권장) — 설계에 넘길 열린 질문 여섯을 이대로 넘긴다"
  - id: S19
    source: chosen
    round: 6
    text: "첫째 선택지, 둘째 선택지, 셋째 선택지, 넷째 선택지 — 화면 시험에서 설명의 끝말까지 보인 선택지(넷 모두)"
  - id: S20
    source: chosen
    round: 6
    text: "모두 보였다 — 화면 시험의 첫 질문 본문에서 경고 세 줄과 본문 끝 표시까지 모두 보였다"
  - id: S21
    source: verbatim
    round: 7
    text: "너무 긴게 좋은건 아니야"
  - id: S22
    source: verbatim
    round: 7
    text: "요즘 클로드는 서머리도 되는듯한데"
  - id: S23
    source: verbatim
    round: 7
    text: "본문에 서머리"
  - id: S24
    source: chosen
    round: 7
    text: "맞다 — 전문은 앞 글에 (권장) — 리뷰 뒤 질문에는 리뷰어의 긴 글 대신 모델이 줄인 요약을 질문 본문에 싣고, 전문은 앞 글에 남긴다(「본문에 서머리」의 읽기 확인)"
  - id: S25
    source: chosen
    round: 7
    text: "요약 한 줄로 (권장) — 경고도 질문에 요약 한 줄로 싣는다(S11 · S15 의 「셋까지 한 줄씩」을 바꾼다)"
  - id: S26
    source: chosen
    round: 8
    text: "더 조사한다 — 포화 판정이 두 번 아직으로 나온 뒤 남은 빈 곳 다섯을 설계에 넘기지 않고 더 조사한다"
  - id: S27
    source: chosen
    round: 9
    text: "첫째 (300자), 둘째 (300자), 셋째 (480자), 넷째 (480자) — 긴 글 화면 시험에서 설명의 끝말까지 보인 선택지(넷 모두)"
  - id: S28
    source: verbatim
    round: 9
    text: "1"
  - id: S29
    source: chosen
    round: 10
    text: "남아 있었다 — 기타 칸에 답한 뒤에도 그 질문과 선택지 설명이 화면에 남아 있었다"
  - id: S30
    source: chosen
    round: 10
    text: "설계에 넘긴다 (권장) — 레포 조사가 찾은 것 넷(대조 장치는 요약의 뜻을 보지 않는다 · 줄이기 규칙이 자리마다 다르다 · 접힘의 이유 기록 없음 · 문면을 잠근 테스트 목록)을 설계에 넘긴다"
  - id: S31
    source: chosen
    round: 11
    text: "다 보인다 — 넷 묶음 화면 시험의 첫 질문에서 본문 끝 표시와 설명 셋의 끝말이 다 보였다"
  - id: S32
    source: chosen
    round: 11
    text: "다 보인다 — 넷 묶음 화면 시험의 둘째 질문에서 본문 끝 표시와 설명 셋의 끝말이 다 보였다"
  - id: S33
    source: chosen
    round: 11
    text: "다 보인다 — 넷 묶음 화면 시험의 셋째 질문(본문에 경고 한 줄)에서 본문 끝 표시와 설명 셋의 끝말이 다 보였다"
  - id: S34
    source: chosen
    round: 11
    text: "줄였다 — 창을 가로 80 · 세로 24 쯤으로 줄인 채 답했다"
  - id: S35
    source: chosen
    round: 12
    text: "포화로 보고 종료 (권장) — 네 번째 판정도 아직이고 같은 빈 곳이 되풀이된 뒤, 조사를 여기서 닫고 brief 로 간다. 빈 곳 다섯은 설계가 먼저 볼 것으로 넘긴다"
  - id: S36
    source: chosen
    round: 13
    text: "spec 하나로 (권장) — 이 일을 나누지 않고 설계문서 하나로 한다. 로드맵을 만들지 않는다"
  - id: S37
    source: chosen
    round: 14
    text: "고친다 — 추천 있으면 전부 적는다 (권장) — 추천이 있는 질문에서는 모든 선택지에 얻음 · 내줌을 같은 꼴로 적고, 채우지 않아도 되는 것은 추천이 없는 질문뿐으로 한다(brief 리뷰 1라운드 결정)"
  - id: S38
    source: chosen
    round: 14
    text: "고친다 — 열 곳 모두 적용으로 적는다 (권장) — 공통 규칙의 변경이 추천이 있는 질문에 한해 skill 열 곳 모두에 적용된다는 것을 범위 결정으로 brief 에 적는다(brief 리뷰 1라운드 결정)"
  - id: S39
    source: chosen
    round: 14
    text: "고친다 — 모델 요약 유지, 위험을 적는다 (권장) — 리뷰어 글을 질문을 짜는 모델이 줄이는 방식은 두고, 원문은 고치지 않는다 규칙의 예외라는 것과 글을 쓴 쪽이 자기 글에 대한 지적을 줄인다는 위험을 brief 에 적는다(brief 리뷰 1라운드 결정)"
  - id: S40
    source: chosen
    round: 14
    text: "고친다 — 문서 리뷰로 좁힌다 (권장) — 질문 창 안의 셋(문제 · 그대로 두면 · 고치면)은 문서 리뷰 뒤 질문의 것으로 적고, 코드 리뷰 질문에 무엇을 실을지는 열린 질문으로 둔다(brief 리뷰 1라운드 결정)"
  - id: S41
    source: chosen
    round: 15
    text: "고친다 — 스크립트 줄 그대로 (권장) — 질문의 경고 줄은 스크립트 · 엔진이 낸 경고 줄을 그대로 쓰고, 스크립트가 낸 줄이 없는 자리만 모델이 쓴다(brief 리뷰 2라운드 결정)"
  - id: S42
    source: chosen
    round: 15
    text: "고친다 — 지휘자 의견 줄만 (권장) — 분해 권고 · 다음 단계 제안 이유 두 자리는 그 질문 안의 얻음 · 내줌으로 갈음하고, 대가 구절을 따로 붙이는 자리는 지휘자 의견 줄 하나로 한다(brief 리뷰 2라운드 결정)"
  - id: S43
    source: chosen
    round: 15
    text: "고친다 — 사라지지 않는 자리 (권장) — 리뷰어 글의 전문은 앞 글이 안 보여도 찾아갈 수 있는 자리에 남기고, 어디인지는 설계가 정한다(brief 리뷰 2라운드 결정)"
  - id: S44
    source: chosen
    round: 15
    text: "닫는다 — 이미 들어가 있음 (권장) — 고르지 않은 넓힘을 기각 목록에 적으라는 지적은 그 줄이 이미 들어가 있어 닫는다(brief 리뷰 2라운드 결정)"
  - id: S45
    source: chosen
    round: 15
    text: "닫고 표기를 바로잡는다 (권장) — 기각 목록의 「리뷰어 글을 그대로 싣는다」 줄을 다시 쓸 때 사용자가 따로 고른 것이 아니라고 표기를 바로잡는다(brief 리뷰 2라운드 결정)"
  - id: S46
    source: chosen
    round: 16
    text: "고친다 — 규칙 한 문장으로 (권장) — 공통 규칙에 질문 없이 한쪽을 권하는 글에는 대가 한 구절을 붙인다는 문장을 넣어 자리 목록 없이 닿게 한다(brief 리뷰 3라운드 결정)"
  - id: S47
    source: chosen
    round: 16
    text: "고친다 — 스크립트가 짧은 줄을 냄 (권장) — 스크립트가 질문용 짧은 경고 줄(개수와 종류 이름)을 따로 내게 하는 것을 범위에 넣고 질문은 그 줄을 그대로 싣는다. 경고 전체 목록은 리뷰어 글 전문과 같은 자리에 둔다(brief 리뷰 3라운드 결정)"
  - id: S48
    source: chosen
    round: 16
    text: "열지 않음 (권장) — 재리뷰 상한에서 추가 라운드를 열지 않고 리뷰를 닫는다(brief 리뷰 3라운드 결정)"
  - id: S49
    source: chosen
    round: 17
    text: "확정하고 /compact 후 brainstorming (권장) — 확정 후보 27개를 확정으로 바꿔 저장하고 다음 단계(설계)로 넘긴다"
confirm_repost_count: 0
brief_review_degradations:
  - component: critic
    reason: 리뷰어 입력(번들 · 프로필)을 프롬프트에 싣지 못하고 워크트리 사본 경로로 넘김(번들 약 4만 8천 자)
    affected_axis: fidelity
    verification_status: degraded
  - component: critic
    reason: 리뷰어 입력(번들 · 프로필)을 프롬프트에 싣지 못하고 워크트리 사본 경로로 넘김(번들 약 4만 8천 자)
    affected_axis: fidelity
    verification_status: degraded
  - component: codex
    reason: 2라운드 codex 가 사용 한도(quota)로 실패(exit_nonzero) — 이 라운드는 Claude 만 봤다. 한도를 기다리지 않고 진행
    affected_axis: direction
    verification_status: unavailable
  - component: critic
    reason: 리뷰어 입력(번들 · 프로필)을 프롬프트에 싣지 못하고 워크트리 사본 경로로 넘김(번들 약 4만 8천 자)
    affected_axis: fidelity
    verification_status: degraded
  - component: readback
    reason: 냉독 입력(brief 본문)을 프롬프트에 싣지 못하고 워크트리 사본 경로로 넘김
    affected_axis: readback
    verification_status: degraded
  - component: readback
    reason: 냉독을 두 번 보냈다 — 첫 번째는 본문을 경로로 넘겨 리뷰어가 읽지 못했고(도구 없음), 두 번째는 본문을 직접 실되 길이 때문에 frontmatter 의 항목 목록(§2 와 같은 문장)과 §6 사용자 원문을 뺐다
    affected_axis: readback
    verification_status: degraded
---

## 풀린 입력

~~~~
---
type: interview-seed
next_phase: spec-distill:pm-interview
audit_file: 2026-11-15-present-tradeoffs-interview.audit.md
---

사용자가 맡긴 일은 둘이고 하나로 묶였다. 처음 요청은 「전반적으로 트레이드 오프를 같이 제시해줘야함」이었고, 회의 도중에 「리뷰어가 리뷰한뒤에 나한테 ask question하는데 설명이 비어있음 그리고 위를 보라는데 위에 아무것도 없음 설명도 부족」을 덧붙였다.
리뷰 뒤 질문 문제는 추천의 대가 문제와 한 일로 묶는다. (사용자 확인)
이 일의 목표는 모델이 무언가를 권하거나 리뷰 뒤에 결정을 물을 때 사용자가 그 화면에 보이는 글만으로 무엇을 고르는지와 그 대가를 알 수 있게 하는 것이다. (사용자 확인)

트레이드오프는 추천을 달 때 그 추천을 따르면 내주는 것을 함께 적는 것이다. (사용자 확인)
대상은 인터뷰 · 설계 · 계획처럼 방향을 정하는 자리다. (사용자 확인)
방향을 정하는 자리에서는 질문뿐 아니라 모델이 한쪽을 권하는 글에도 그 대가를 같이 적는다. (사용자 확인)
지금까지 추천의 대가를 모르고 골랐고, 선택지를 견주기 어려웠고, 질문이 아닌 글에서는 한쪽 길만 들었다. (사용자 확인)
devbrew 가 띄우는 질문 전부나 모델이 권하는 글 전부로 넓히는 것, 추천이 없는 질문에도 선택지마다 얻는 것과 내주는 것을 적는 것은 선택지로 보였지만 사용자가 고르지 않았다.

얻는 것과 내주는 것을 문장으로 풀어 쓴 형식은 길어서, 한눈에 들어오는 더 짧은 형식이어야 한다. (사용자 확인)
그 말을 듣고 이 회의의 다음 질문부터 선택지 설명을 「얻음: 겹치는 규칙을 한 번에 고친다 · 내줌: 일이 커져 인터뷰와 설계가 길어진다」처럼 한 줄로 줄여 보였다.
선택지 설명은 얻음과 내줌을 한 줄에 적는 이번 형식 정도면 된다. (사용자 확인)

리뷰 뒤에 받는 결정 질문은 선택지 설명이 비어 있고 「위에 적었다」가 가리키는 글이 보이지 않아, 질문만 보고는 무엇을 고르는지 알 수 없었다. (사용자 확인)
설명이 비었다는 것은 설명 칸이 아예 없던 경우, 있어도 한 줄뿐이던 경우, 질문 본문에 무엇이 문제인지가 없던 경우를 모두 가리킨다. (사용자 확인)
어느 리뷰에서 그랬는지는 사용자가 짚지 않았고, 지난 세션 기록을 잰 결과로 정한다. (사용자 확인)

그래서 이 레포의 지난 세션 기록 872개에 남은 질문 827개를 쟀다.
「위」를 가리킨 질문 가운데 그 앞에 모델이 쓴 글이 하나도 없던 것이 요청을 정리하는 단계(request-framing)에서 36개 중 31개, 설계문서 리뷰에서 25개 중 17개, 인터뷰에서 28개 중 14개였다.
코드 리뷰의 질문 67개에는 「위」를 가리킨 것이 없었다.
지휘자 세션의 질문 28개에는 「위」를 가리킨 것이 하나 있었고, 그 앞에 글이 없던 것은 없었다.
직접 열어 본 한 사례에서는 seed 리뷰 뒤 질문 넷이 모두 「경고 4개 — 위에 적었다」로 끝났는데, 리뷰어 결과를 받은 뒤 그 질문까지 모델이 쓴 글이 없었다.
선택지 설명 칸이 완전히 빈 질문은 기록에서 찾지 못했고, 열두 자 이하로 짧은 설명은 여러 곳에 있었다.

어떻게 지키게 할지(규칙 문장만 둘지 검사까지 둘지)와 화면의 어느 칸에 무엇을 실을지는 이 회의에서 정하지 않았다.
사용자에게는 그것을 인터뷰와 설계가 정할 일이라고 말하고 회의를 닫았다.

다시 검증할 것 — 두 문제가 「질문 화면만 보고는 고를 수 없다」는 한 뿌리라는 것은 Phase 0 의 추론이다. 사용자는 묶는 데 동의했지 그 원인 진단을 확인하지 않았다.
질문 창이 떠 있는 동안 그 앞에 쓴 글이 화면에 보이지 않을 수 있다는 것은 질문 도구의 설명서에 적힌 말이고, 실제 화면에서 재지 않았다.
설명 칸이 아예 없던 질문은 기록에 없으므로, 사용자가 본 화면이 무엇이었는지는 다시 물어야 한다.
측정은 거칠다 — 어느 리뷰의 질문인지는 그 세션에서 마지막으로 부른 skill 로 나눴고, 「위」를 가리키는지는 낱말 맞추기로 셌고, 손으로 연 사례는 하나다.
범위 답은 추천의 대가 문제만 놓고 받은 것이고, 리뷰 뒤 질문 문제에도 같은 범위가 걸리는지는 묻지 않았다.
요청을 정리하는 단계가 「방향을 정하는 자리」에 드는지는 묻지 않았다. 범위 질문의 선택지에 적은 예는 인터뷰 · 설계 · 계획이었는데 측정에서는 그 단계가 가장 심했다.
설계 단계의 질문은 devbrew 밖의 skill(superpowers 의 brainstorming)이 띄우는데, 이 일의 규칙이 거기에 닿을 수 있는지는 보지 않았다.
코드 리뷰에 「위」를 가리키는 질문이 없다는 것이 그쪽 질문은 화면만 보고 고를 수 있다는 뜻인지도 보지 않았다.
~~~~

## R1

### 지금 이해
(경로 a — 레포 · 웹에서 확인) 사용자가 본 리뷰 뒤 질문의 모양은 규칙을 어긴 것이 아니라 규칙대로 나온 것이다 — 문서 리뷰 셋(설계문서 · brief · seed)이 함께 쓰는 엔진 절차서가 「질문 본문에는 결정 하나와 『경고 N개 — 위에 적었다』 한 줄만」을 정하고, 설명 칸에 무엇을 쓸지는 정하지 않는다. 그리고 질문 창 앞에 쓴 글이 화면과 세션 기록에서 사라지는 Claude Code 버그(#75182, 열림, 최근 보고 2026-11-14)가 1차 출처로 확인됐다 — 「앞 글 0자」 측정은 모델이 안 쓴 것인지 썼는데 사라진 것인지를 가르지 못한다.
함께 띄운 조사 셋(주제 찾기 · 레포 · 바깥 선례)은 서로 기대지 않아 한 묶음으로 보냈다. 바깥 선례(조사 3): 플랫폼 지침(Microsoft command link)은 「추천 표시는 라벨에, 왜 고르는지 · 고르면 어떻게 되는지는 선택지 아래 설명에 세 줄 이내」 쪽이고, 추천을 첫 자리 · 표시와 함께 보이면 쏠림이 생긴다는 연구가 있다 — 본체가 다시 확인하지 않은 주장이다.
admit 한 파생 차원 일곱: internal_research · screen_channel · prior_decisions · ownership_boundary · minimum_content · prose_recommendation_sites · verification_method (coverage-mapper 가 낸 여덟 중 「기존 규칙과 잠금 테스트」 · 「있는 것」 둘은 internal_research 로 합쳤다 — 둘 다 레포 주장의 처분으로 닫히는 같은 근거라서). neglect_flag: true — 화면 통로 · 이전 확정의 재결정 · 고쳐졌는지 재는 방법.
조사 호출 3/60 · 이 라운드 본체 직접 1
밀린 질문 6개 — 앞 글이 사라진다고 보고 질문 안에 다 실을지(OQ7) · 지난 확정 「추천의 이유는 질문 위 글에」를 다시 정할지(OQ8) · 추천 없는 리뷰 질문에 실을 최소 내용(OQ9) · 질문 밖 「권하는 글」 자리를 무엇으로 찾을지(OQ10) · 고쳐졌는지 무엇으로 확인할지(OQ11) · 지키게 하는 방법과 칸 배치(OQ3 · OQ4)
줄인 사실 74개

- 대체됨: 인터뷰 규약의 «추천 · 트레이드오프» 줄은 상태 파일에만 적는 줄이다 → 화면 출력에도 같은 형식으로 나가는 줄이다(pm-interview/SKILL.md 180행 「사용자에게 보이는 출력과 state 본문 기록이 같은 형식이다」) (조사 1)
- 대체됨: 질문 창이 앞 글을 가릴 수 있다는 근거는 질문 도구 설명서의 말뿐이다 → 1차 출처의 버그 보고가 있고(#75182 · #67475) 레포의 지난 인터뷰(2026-10-27)도 이미 확인해 적어 두었다 (조사 1 · 조사 4)
- 대체됨: 코드 리뷰에는 질문 밖 글을 가리키는 질문이 없다 → 낱말이 달라 측정에 안 걸렸을 뿐이고 「위 「낮춘 지적」 절」 · 「분류표의 「적용」 항목」으로 질문 밖 글을 가리킨다 (조사 1 · 조사 2)

레포 주장 확인(V1) — 조사 2(repo-researcher)의 RC1–RC29 는 번호 그대로, 조사 1(coverage-mapper)의 RC1–RC23 은 RC30–RC52 로, 조사 3(open-researcher)의 RC1–RC9 는 RC53–RC61 로 다시 붙였다.
- 확인 RC1 — 확인 — shared/style/plain-language.md#질문 하나에 결정 하나. 선택지 이름은 짧은 쉬운 말로 — 주장과 일치(6행 전문 대조 · 「대가」 · 「트레이드오프」 낱말 없음)
- 확인 RC2 — 확인 — shared/style/plain-language.md#아래 절차가 출력 형식·원문 보존·분량을 따로 정한 자리에서는 그 절차를 따른다 — 주장과 일치(3행)
- 확인 RC3 — 확인 — shared/tests/plain_language_block.py#def check(root, rel, canon) — check() 는 주장대로 넷만 잰다. 짝 .sh 의 문장 실재 검사는 읽지 않았다
- 확인 RC4 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#· 트레이드오프: <선택지별 한 줄> — 주장과 일치(180 · 190 · 204–205행 · 「트레이드오프」 낱말은 skills · references · shared 에서 이 줄과 리뷰 프로필 정규식 한 줄뿐)
- 확인 RC5 — 확인 — shared/docreview/references/reviewing-document.md#8. **게이트** — 주장과 일치(27–40행 · 이 파일에 description 낱말 0개)
- 확인 RC6 — 확인 — shared/docreview/references/reviewing-document.md#**`AskUserQuestion` 라벨의 항목별 내용** — 주장과 일치(42행 · 86행)
- 확인 RC7 — 확인 — shared/docreview/scripts/docreview_state.py#def _rg_decide(st, g, fid) — 주장과 일치(2310–2315행의 다섯 줄 · _CHOICE_LABEL 2137행 · 추천 줄 없음)
- 확인 RC8 — 확인 — plugins/spec-distill/skills/spec-review/SKILL.md#승인 게이트 질문에는 「경고 N개 — 위에 적었다」 — 555 · 661 · 827–828행 일치. 2단계 옵션 표(688–695행)는 읽지 않았다
- 확인 RC9 — 확인 — plugins/spec-distill/skills/spec-review/SKILL.md#**③ 의 갈래와 로드맵 에픽.** — 702행 「이유는 질문 위 글에 한 줄로 쓴다」 일치. 그 밖 라벨 줄(301 · 635 · 766행)은 읽지 않았다
- 확인 RC10 — 확인 — plugins/spec-distill/skills/reviewing-brief/SKILL.md### 게이트 — 604 · 739–740행 일치
- 확인 RC11 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#B-2 — 497–499 · 513–519 · 536행 일치
- 확인 RC12 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#신호 셋과 권고를 위에 적었다 — 33 · 38행 일치. (b)(c)(d) 의 줄(64 · 266 · 298 · 329 · 402행)은 읽지 않았다
- 확인 RC13 — 확인 — plugins/spec-distill/references/proceed-gate.md### Step B — 단일 `AskUserQuestion` — 주장과 일치(28–60행)
- 확인 RC14 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#### 게이트 — 처분은 사용자가, 편집은 처분 뒤에 — 784 · 934–935 · 1094행 일치. 800 · 1127–1134행은 읽지 않았다
- 확인 RC15 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#### 확인 질문 — 라운드마다 하나 — 246행 일치 · 워크트리 질문 펜스 일치
- 확인 RC16 — 확인 — plugins/spec-distill/references/redecompose.md#다시 나눌 표와 영향을 위에 적었다. 어떻게 할까? — 주장과 일치(57–62행)
- 확인 RC17 — 확인 — plugins/spec-distill/references/conducting.md#### 2. 사람 몫 모으기 — 27 · 40행 일치. 29 · 102–114행은 읽지 않았다
- 확인 RC18 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#지휘자는 배경을 먼저 쉬운 말로 쓰고 질문만 봐도 결정할 수 있게 묻는다 — 32행 · relay-checker.md 34행 일치
- 확인 RC19 — 확인 — shared/tests/ask_recommendation.py#def required(kind, body) — 주장과 일치(109–127행 — 종류별 글자 실재만 본다 · 본문 · 설명 내용은 재지 않는다)
- 확인 RC20 — 확인 — shared/tests/test_ask_recommendation.sh## 한계 둘: — 일치. 목록 줄 수는 wc 로 168
- 확인 RC21 — 확인 — shared/tests/test_docreview_round_gate_split.sh#**이 축의 한계** — 31–34행 일치
- 확인 RC22 — 확인 — plugins/spec-distill/tests/test_plain_gate_templates.sh## ⑬ 질문 본문에는 결정과 상태 한 줄만 — 133 · 150행 일치. test_brief_review_entry.sh 는 읽지 않았다
- 확인 RC23 — 확인 — plugins/spec-distill/tests/test_conducting_interview_stage.sh#고르면 무엇이 달라지는가 — 487 · 498행 일치
- 확인 RC24 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#남은 지적이 있다(<summary>). 어떻게 할까? — 851 · 854 · 861 · 873행 일치
- 확인 RC25 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#**낮춘 지적 게이트 (표면화 뒤 · 라우팅 앞).** — 713–720행 일치. 범위 모드 · 수정 실패 질문은 읽지 않았다
- 확인 RC26 — 미확인 — plugins/quality-gates/references/e2e.md#증거표와 판정안을 보인 뒤 — 102행만 확인했고 §2 시나리오 질문의 설명 규칙(41–57행)은 읽지 않았다
- 확인 RC27 — 미확인 — plugins/quality-gates/skills/artifact-critique/SKILL.md#### E3 — 범위 고르기 · 규모 공시 — 189행(비평자 수 질문의 대가 문장)만 확인했다
- 확인 RC28 — 확인 — plugins/quality-gates/tests/test_plain_qg_templates.sh#grep -c .)" "6" — 51 · 64 · 66 · 167행 일치
- 확인 RC29 — 미확인 — shared/tests/fixtures/ask-sites.tsv## 게이트 · 리뷰 결정 질문 (Task 4) — 여러 자리를 모은 집계 주장이라 자리마다 대조하지 않았다
- 확인 RC30 — 확인 — shared/style/plain-language.md#이유는 질문 위 글에 — 6행 · proceed-gate.md 44행 일치(두 규칙이 같은 통로에 기댄다는 데까지)
- 확인 RC31 — 확인 — docs/superpowers/interview/2026-10-27-askquestion-recommendation-interview.state.md#75182 — 429 · 478 · 485행 · brief 216행 일치
- 확인 RC32 — 확인 — plugins/spec-distill/dependencies.md#| claude-code | 2.1.303 | 2026-10-22 | 기록 | — 19행 일치
- 확인 RC33 — 확인 — plugins/spec-distill/references/proceed-gate.md#질문 본문에는 결정 하나와 「경고 N개 — 위에 적었다」 — 44행과 일곱 자리 일치
- 확인 RC34 — 확인 — shared/docreview/references/reviewing-document.md#렌더 첫 줄(상태와 경고)은 첫 호출 **앞 글**에 한 번 쓴다 — 30 · 42행 일치 · description 낱말 0개
- 확인 RC35 — 확인 — shared/docreview/scripts/docreview_state.py#_rg_decide — 2311–2315행 일치
- 확인 RC36 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#옵션 description 에 싣지 않습니다 — 497 · 38행 일치
- 확인 RC37 — 확인 — shared/tests/test_ask_recommendation.sh#모델이 즉석에서 만드는 질문은 정본 규칙만이 집행한다 — 9행 · ask_recommendation.py required() 일치
- 확인 RC38 — 확인 — plugins/spec-distill/tests/test_plain_gate_templates.sh#질문 본문 — 133행 일치 · 쉬운 말 블록 사본 10개 확인. test_plain_language_block.sh 28–32행은 읽지 않았다
- 확인 RC39 — 확인 — docs/superpowers/interview/2026-10-27-askquestion-recommendation-interview.md#**D16** — 175 · 181 · 195행 일치
- 확인 RC40 — 확인 — docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md### Anti-goals — 47–54 · 59행 · brief 176행(C17) 일치
- 확인 RC41 — 확인 — docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md#«gh-askuserquestion-hides-text» — 289행 일치
- 확인 RC42 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#OQ<n>: <무엇을 정하는지 한 줄> · 추천: — 180 · 190 · 204–205행 일치
- 확인 RC43 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#지휘자는 배경을 먼저 쉬운 말로 쓰고 질문만 봐도 결정할 수 있게 묻는다 — 32행 일치. 29행은 읽지 않았다
- 확인 RC44 — 확인 — shared/style/plain-language.md#부른 skill 이 메시지 모양을 정한 대화(예: brainstorming)에서는 그 skill 을 따르고 — 3행 일치
- 확인 RC45 — 확인 — docs/superpowers/interview/2026-10-27-askquestion-recommendation-interview.md#**D13** — 172 · 173행 일치
- 확인 RC46 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#**다음 세션 줄 — ①/② 공통** — 551 · 553행 일치
- 확인 RC47 — 확인 — plugins/spec-distill/references/conducting.md#brief · 설계 · 계획처럼 방향을 정하는 단계면 특히 그렇다 — 28행 일치(plugins 에서 「방향을 정하는 단계」 1곳 · 「방향을 정하는 자리」 0곳)
- 확인 RC48 — 확인 — shared/tests/fixtures/ask-sites.tsv## 게이트 · 리뷰 결정 질문 (Task 4) — 비움 행 87 · 88 · 91 · 120 · 124행과 request-framing 934 · 939행 · quality-pipeline 720 · 873행 일치
- 확인 RC49 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#이어서 권고 한 줄 — 33 · 536행 · proceed-gate.md 56행 일치. 문장 권고 자리를 모은 목록이 없다는 것은 찾지 못한 것이다
- 확인 RC50 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#재비판이 심각도를 낮춘 지적이 <n>개 있다(위 「낮춘 지적」 절) — 713 · 851 · 861행 일치 · 측정 낱말에 걸리지 않음을 측정 스크립트로 확인
- 확인 RC51 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#### 게이트 — 처분은 사용자가, 편집은 처분 뒤에 — 784 · 1094행 · reviewing-brief 11행 일치. 「리뷰 · 확정 게이트에서 왔을 공산」은 추정 그대로다
- 확인 RC52 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#{label: "만들고 시작 (권장)", description: — plugins 의 .md 에서 preview 를 질문 칸으로 쓰라는 지시를 찾지 못했다 · 세션 기록의 질문 855개 중 preview 칸이 있는 것은 1개
- 확인 RC53 — 확인 — plugins/spec-distill/dependencies.md#| claude-code | 2.1.303 | 2026-10-22 | 기록 | — 네 플러그인의 dependencies.md 모두 2.1.303 · superpowers 7.0.0(17행) 일치
- 확인 RC54 — 확인 — shared/style/plain-language.md#질문 하나에 결정 하나. 선택지 이름은 짧은 쉬운 말로 — 6행 일치(RC1 과 같은 자리)
- 확인 RC55 — 확인 — shared/style/plain-language.md#부른 skill 이 메시지 모양을 정한 대화(예: brainstorming)에서는 — 3행 일치(RC2 와 같은 자리)
- 확인 RC56 — 확인 — plugins/spec-distill/references/proceed-gate.md### Step B — 단일 `AskUserQuestion` — 39–45행 일치
- 확인 RC57 — 확인 — shared/docreview/references/reviewing-document.md#「경고 N개 — 위에 적었다」 한 줄만 둔다. — 열 자리와 CHANGELOG 699행 일치
- 확인 RC58 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#신호 셋과 권고를 위에 적었다 — 38행 · redecompose.md 57행 일치
- 확인 RC59 — 확인 — shared/tests/test_ask_recommendation.sh## 한계 둘: — 8–10행 · required() 일치
- 확인 RC60 — 확인 — plugins/project-init/hooks/hooks.json#"PostToolUse": [ — plugins/*/hooks 에서 AskUserQuestion · PreToolUse 0건 · 이벤트 키는 project-init 의 PostToolUse 하나
- 확인 RC61 — 확인 — plugins/spec-distill/agents/integration-reviewer.md#with a conflict preview, and earlier — plugins 의 .md 에서 preview 낱말은 이 한 줄

웹 주장 확인(본체)
- 웹 조사 3 의 훅 · mod 문서(PreToolUse 가 AskUserQuestion 입력을 본다 · plugin 훅은 세션 전체에 걸린다 · mod 가 질문 창 위에 글을 그릴 수 있다) — 확인 못 함(본체가 다시 확인하지 않음 · OQ3 을 다루는 라운드 전에 1차로 확인한다)
- 웹 조사 3 의 선례(Microsoft command link · Apple HIG alerts · ADR/MADR · 기본값 쏠림 메타분석 · AI 추천 과신 연구 · MCP elicitation) — 확인 못 함(본체가 다시 확인하지 않음)
- 웹 조사 3 의 changelog 줄 · #84409 · #95228 · #73629 · #64776 — 확인 못 함(본체가 다시 확인하지 않음)
- 웹 #75182 — 확인(1차 · GitHub · 2026-11-15) — 열림 · 2026-07-07 · 메인테이너가 2.1.233 에서 재현 · Fable 5 에서 질문 앞 글이 질문 전에도 답한 뒤에도 안 보임 · 저장된 세션 기록에서도 빠짐 · 최근 댓글 2026-11-14(2.1.325) · 우회책 「턴을 글로 끝내라」 [→ OQ7]
- 웹 #45384 — 확인(1차 · GitHub · 2026-11-15) — preview 칸이 있으면 description 이 안 그려진다는 보고 · 메인테이너 답 없이 닫힘 [→ OQ6]
- 웹 질문 도구 형식(질문 1–4 · 선택지 2–4 · 머리글 12자 · label · description · preview) — 확인(본체의 도구 정의) [→ OQ4]
- 웹 brainstorming 의 대가 · 추천 요구 — 확인(깔린 판 superpowers 7.0.2 SKILL.md 162행 「each trades off. Recommend one and say why, then ask which way they want」 · 함께 깔린 7.0.0 사본에는 그 문장이 없고 221행에 tradeoffs 낱말 하나뿐 · 레포가 기록한 판은 7.0.0) [→ OQ5]
- 웹 #67475 · #77242 · #67113 · W3C 인지 접근성 패턴 — 확인 못 함(조사 agent 가 1차로 읽었다고 보고 · 본체가 다시 확인하지 않음)

재측정(본체 · 세션 기록)
- 기록 804개 · 질문 855개(Phase 0 측정의 872 · 827 과 세는 범위가 달라 수가 다르다). 「위」를 가리킨 질문 107개 · 그중 앞 글 0자 65개(Phase 0 측정과 같은 수).
- 모델별: opus 계열 「위」 60개 중 앞 글 0자 42개 · fable 계열 47개 중 23개.
- 앞 글 0자인 질문 앞에는 전부 생각 블록이 있었다 — 기록으로는 「모델이 안 썼다」와 「썼는데 사라졌다」를 가르지 못한다.

### 다음 결정
OQ6 · OQ7: 지금 이 화면에서 질문 창 앞의 글이 보이는가(사용자만 볼 수 있는 사실) · 추천: 없음 — 관찰을 묻는 질문 · 트레이드오프: 해당 없음
OQ1: 리뷰 뒤 결정 질문을 어디까지 고칠지 · 추천: 문서 리뷰 셋 · 트레이드오프: 문서 리뷰 셋 — 엔진 규칙 한 곳으로 셋이 함께 고쳐지나 코드 리뷰 질문은 그대로 남는다 / 코드 리뷰까지 — 리뷰 뒤 질문 전부가 같은 기준이 되나 다른 플러그인의 질문과 테스트까지 고쳐 일이 커진다 / seed 리뷰만 — 가장 작게 끝나나 같은 문장을 쓰는 두 리뷰에 같은 증상이 남는다
OQ2: 요청 정리 단계의 질문에도 추천의 대가를 적을지 · 추천: 넣는다 · 트레이드오프: 넣는다 — 측정에서 가장 심했던 단계가 빠지지 않으나 설명 칸을 다른 용도로 쓰는 확인 질문과 갈라야 한다 / 넣지 않는다 — 처음 고른 범위 그대로이나 그 단계의 추천은 대가 없이 남는다
OQ5: 설계 · 계획 대화(외부 skill)까지 닿게 할지 · 추천: 그 skill 에 맡긴다 · 트레이드오프: 맡긴다 — 지난 확정과 맞고 그 skill 이 이미 대가와 추천을 요구하나 빠져도 devbrew 규칙으로는 못 잡는다 / 다음 세션 줄에 한 문장 — 요구가 전달되나 붙여 넣는 줄이 길어지고 지난 확정을 다시 정하는 것이다

### 질문
1. (화면 확인) 화면 확인입니다. 이 질문 창을 띄우기 직전에 제가 글을 썼고 그 안에 「확인용 문장 — 파란 고래 37」을 넣었습니다. 이 창이 떠 있는 지금, 그 문장이 화면에 보이나요? 묻는 이유: Claude Code 에 질문 창 앞에 쓴 글이 화면과 기록에서 사라지는 버그가 열려 있습니다(공식 저장소 이슈 75182, 어제까지 보고가 이어짐). 말씀하신 「위에 아무것도 없음」이 그 버그인지 이 화면에서 직접 재려는 것입니다.
2. (리뷰 범위) 리뷰 뒤 결정 질문은 어디까지 고칠까요? 확인한 사실: 설계문서 리뷰 · 인터뷰 brief 리뷰 · 요청 정리 단계의 seed 리뷰 셋은 같은 규칙을 쓰고, 그 규칙이 「질문 본문에는 결정 하나와 『경고 N개 — 위에 적었다』 한 줄만」이라고 정해 두었습니다. 보신 모양은 규칙대로 나온 것입니다. 코드 리뷰(quality-gates)는 문구만 다르고 같은 꼴입니다(「위 낮춘 지적 절」 · 「분류표의 적용 항목」으로 질문 밖 글을 가리킴). 문서 리뷰 셋을 권합니다 — 증상을 확인한 곳이 거기이고 규칙 한 곳을 고치면 셋이 함께 고쳐집니다.
3. (요청 정리) 요청을 정리하는 단계(request-framing)의 질문에도 추천의 대가를 적을까요? 범위를 고르실 때 제가 든 예는 인터뷰 · 설계 · 계획이었고 이 단계는 여쭙지 않았습니다. 이 단계도 추천을 달아 방향을 묻습니다(예: 두 문제를 묶을지 따로 할지). 넣기를 권합니다 — 「위」를 가리키는데 앞 글이 없던 질문이 가장 많았던 단계이고(36개 중 31개), 지난 회의에서 「얻음 · 내줌」 형식을 실제로 써 본 곳입니다.
4. (외부 skill) 설계 · 계획 단계의 대화는 devbrew 밖 skill(superpowers 의 brainstorming · writing-plans)이 진행합니다. 고르신 범위 「인터뷰 · 설계 · 계획」 가운데 둘이 여기에 듭니다. 이 일의 규칙을 거기까지 닿게 할까요? 확인한 사실: 지난 10월 추천 표시 일에서 「외부 skill 의 질문은 그 skill 몫」으로 확정하셨고, 지금 깔린 brainstorming(7.0.2)은 접근안마다 대가와 추천을 이미 요구합니다(7.0.0 사본에는 그 문장이 없습니다). 맡기기를 권합니다.

### 답
→ S2 (화면 확인): 보인다
→ S3 (리뷰 범위): 문서 리뷰 셋 (권장)
→ S4 (요청 정리): 넣는다 (권장)
→ S5 (외부 skill): 그 skill 에 맡긴다 (권장)

## R2

### 지금 이해
(경로 a) S2 뒤에 이 세션 기록을 열어 보니 확인용 문장이 든 글이 글 블록(1,370자 · 모델 claude-fable-5-2)으로 남아 있었다 — 이번 한 번은 썼고, 기록에 남았고, 화면에도 보였다. 버그(#75182)는 늘 나는 것이 아니고, 지난 측정의 65건이 「안 썼다」인지 「사라졌다」인지는 여전히 가르지 못한다.
S3 · S4 · S5 로 범위가 정해졌다 — 리뷰 뒤 질문은 문서 리뷰 셋, 추천의 대가는 요청 정리 단계까지, 설계 · 계획 대화는 그 skill 에 맡긴다(지난 확정 D13 유지). 세 답 모두 이유 없는 추천 수락이라 가장 무거운 하나(코드 리뷰 제외)를 되묻는다.
blind_spot 차원의 첫 조사(숨은 가정 · 실패 양식)를 이 라운드 질문과 함께 띄웠다 — 결과는 다음 라운드에 보인다.
조사 호출 4/60 · 이 라운드 본체 직접 1
밀린 질문 4개 — 질문 밖 「권하는 글」 자리를 무엇으로 찾을지(OQ10) · 고쳐졌는지 무엇으로 확인할지(OQ11) · 지키게 하는 방법(OQ3) · 바깥 선례의 처분(landscape)

### 다음 결정
되묻기(S3): 코드 리뷰를 뺀 이유와 실패 조건 · 추천: 다음 일로 따로 한다 · 트레이드오프: 다음 일로 — 이번 일이 작게 끝나나 그때까지 코드 리뷰 질문은 지금 모양이다 / 이번에 넣는다 — 한 번에 끝나나 다른 플러그인의 질문과 테스트까지 고친다 / 공통 규칙만 같이 — 새 기준이 규칙으로는 걸리나 코드 리뷰의 고정 문면과 어긋난 채 남는다
OQ8 · OQ7 · OQ4: 지난 확정 「추천의 이유는 질문 위 글에」를 다시 정할지 · 추천: 이유와 대가를 질문 안으로 · 트레이드오프: 질문 안으로 — 앞 글이 사라져도 남으나 지난 확정을 뒤집고 질문이 길어진다 / 대가만 설명 칸에 — 지난 확정을 지키나 앞 글이 사라지면 이유는 못 본다 / 그대로 — 고칠 것이 없으나 이번 요청이 앞 글에 기댄다
OQ6: 「설명 칸이 없었다」는 화면이 어느 쪽이었는지 · 추천: 없음 — 사용자만 아는 관찰 · 트레이드오프: 해당 없음
OQ9: 문서 리뷰 결정 질문 안에 있어야 하는 것 · 추천: 무엇이 문제인지 · 그대로 두면 · 고치면 · 트레이드오프: 항목마다 질문이 그만큼 길어진다 — 리뷰어의 근거까지 넣으면 지적이 여럿일 때 화면이 넘친다

### 질문
1. (범위 확인) 코드 리뷰(quality-gates)의 질문은 이번 범위에서 빼셨습니다. 뺀 이유를 기록해 두려고 여쭙니다 — 이 일을 마친 뒤 코드 리뷰에서 같은 증상(질문만 보고는 고를 수 없음)을 보시면 어떻게 받아들이실까요? 알아 두실 사실: 「설명에는 고르면 무엇이 달라지는지만 쓴다」 같은 공통 글쓰기 규칙은 모든 플러그인의 skill 10개에 같은 글자로 복제돼 있어, 그 규칙을 고치면 코드 리뷰 쪽 skill 에도 같이 들어갑니다. 따로 하기를 권합니다.
2. (지난 확정) 지난 10월 추천 표시 일에서 「(권장) 표시는 라벨에, 추천의 이유는 질문 위 글에 둔다」로 확정하셨습니다. 이번 목표(화면에 보이는 글만으로 무엇을 고르는지와 그 대가를 안다)와 부딪힙니다 — 질문 위 글은 사라지는 날이 있습니다(이번 확인에서는 보였습니다). 다시 정할까요? 질문 안으로 옮기기를 권합니다 — 지난번에는 「위 글이 사라져도 표시는 남는다」로 이유의 손실을 받아들였는데, 이번에 말씀하신 「추천의 대가를 몰랐다」가 바로 그 손실 자리입니다.
3. (본 화면) 「설명이 비어있음」에서 「설명 칸이 없었다」도 고르셨는데, 지난 세션 기록 855개 질문에는 설명 칸이 빈 질문이 하나도 없습니다. 기록과 화면이 달랐을 수 있어 여쭙니다 — 보신 것이 어느 쪽에 가까운가요?
4. (리뷰 질문) 문서 리뷰 뒤 결정 질문 하나(예: 지적 하나를 고칠지 그대로 둘지)에서, 질문 창 안에 무엇이 있어야 고르실 수 있나요? 맞는 것을 모두 골라 주세요. 확인한 사실: 리뷰 엔진은 지적마다 「그대로 두면 · 고치면 · 근거 · 자리」를 이미 만들지만 그 글은 도구 출력으로만 나오고, 질문 창에는 「고친다 — 대체안 1–5 낱말」 같은 라벨만 가게 돼 있습니다. 앞의 셋을 권합니다 — 셋이 있으면 무엇을 고르는지와 그 대가가 화면에 나옵니다.

### 답
→ S6 (범위 확인): 이번에 넣는다
→ S7 (지난 확정): 이유와 대가를 질문 안으로 (권장)
→ S8 (본 화면): 글자는 있었지만 내용이 없었다
→ S9 (리뷰 질문): 무엇이 문제인지 (권장), 그대로 두면 어떻게 되는지 (권장), 고치면 무엇이 바뀌는지 (권장)

## R3

### 지금 이해
S6 이 S3 의 범위를 넓혔다(새 발화가 이긴다) — 리뷰 뒤 결정 질문은 문서 리뷰 셋과 코드 리뷰(quality-gates)까지다. S7 로 지난 확정 D16(추천의 이유는 질문 위 글에)을 사용자 동의로 다시 정했다 — 추천의 이유와 대가는 질문 안에 둔다. S8 로 「설명 칸이 없었다」는 화면 표시 문제가 아니라 글자는 있어도 내용이 없던 경우로 정해졌다. S9 로 리뷰 결정 질문 안에 있어야 하는 것은 무엇이 문제인지 · 그대로 두면 · 고치면 셋이다(리뷰어의 근거 제외).
(경로 a) 이 컴퓨터의 Claude Code 는 2.1.325 다. 이 세션에서 질문 앞 글은 두 번(R1 · R2) 모두 글 블록으로 기록에 남았다 — 사라진다고 보고된 꼴(도구 호출 → 글 → 질문)이었는데도 그랬다. 표본이 둘이라 일반화하지 않는다.
steelman(ST1): 의심 방향 「이유 · 대가 · 지적 내용을 질문 창 안에 싣고 앞 글 방식을 버린다」 — 확인된 전제 충돌 0건, builder 추천은 보완(refined). 이 라운드는 그 게이트 질문 하나다.
blind-spot 조사(조사 5)의 숨은 가정 여섯 · 실패 양식 일곱은 다음 라운드에 처분을 묻는다.
조사 호출 5/60 · 이 라운드 본체 직접 1
밀린 질문 6개 — 숨은 가정 · 실패 양식의 처분(blind_spot) · 경고 목록을 질문 창 안에 실을지(OQ12) · 질문 밖 「권하는 글」 자리(OQ10) · 고쳐졌는지 무엇으로 확인할지(OQ11) · 지키게 하는 방법(OQ3) · 바깥 선례의 처분(landscape)
줄인 사실 31개

레포 주장 확인(V1) — 조사 5(blind-spot-prober)의 RC1–RC12 는 RC62–RC73 으로, 조사 6(steelman-builder)의 RC1–RC15 는 RC74–RC88 로 다시 붙였다.
- 확인 RC62 — 확인 — shared/docreview/references/reviewing-document.md#렌더의 「고치면」 줄이 전문을 이미 내므로 라벨은 그 줄을 가리키는 손잡이다 — 27–42행 일치(지적별 줄을 사용자 글로 옮기라는 문장 없음)
- 확인 RC63 — 확인 — shared/docreview/scripts/docreview_state.py#def _one — 2223–2225행은 공백만 접고 길이를 자르지 않는다 · 2311–2312행 자리표 일치
- 확인 RC64 — 확인 — shared/style/plain-language.md#스크립트·subagent 가 낸 원문은 고치지 않는다 — 블록 9행 · 6행 · 3행 일치
- 확인 RC65 — 확인 — plugins/spec-distill/tests/test_plain_gate_templates.sh#⑬ 질문 본문에는 결정과 상태 한 줄만 — 100–113행 인접 순서 락 · 133–142행 양의 락 · 143–147행 부재 락 일치
- 확인 RC66 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#옵션 description 에 싣지 않습니다 — 497행 · 테스트 150–151행 일치
- 확인 RC67 — 확인 — plugins/spec-distill/agents/relay-checker.md#지휘자 의견이 선택지 설명 안으로 들어갔으면 어긋남이다 — 34 · 37행 일치
- 확인 RC68 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#덩어리 본문(`render`)은 질문 텍스트에 줄임 없이 싣는다 — 934 · 935 · 939행 일치
- 확인 RC69 — 확인 — shared/tests/plain_language_block.py#블록 바이트가 정본(%s)과 다르다 — 52행 일치 · 사본 10개(quality-gates 둘 · plugin-audit · project-init 하나씩 · spec-distill 여섯)
- 확인 RC70 — 확인 — docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md### Anti-goals — 28 · 51–54 · 178행 일치
- 확인 RC71 — 확인 — shared/tests/test_ask_recommendation.sh#한계 둘 — 8–10 · 37행 일치
- 확인 RC72 — 확인 — plugins/spec-distill/references/proceed-gate.md### Step B — 단일 `AskUserQuestion` — 39–50 · 58행 일치
- 확인 RC73 — 확인 — plugins/spec-distill/CHANGELOG.md### [5.1.0] — 2026-10-09 — 696 · 699행 일치. 왜 질문 안에서 뺐는지의 이유는 그 항목에 없다
- 확인 RC74 — 확인 — shared/style/plain-language.md#설명에는 고르면 무엇이 달라지는지만 쓴다 — 6 · 9행 일치
- 확인 RC75 — 확인 — shared/tests/test_plain_language_block.sh#REC='추천이 있으면 그 선택지를 첫 자리에 두고 — 30 · 32행 일치
- 확인 RC76 — 확인 — docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md### Anti-goals — 30 · 47–54 · 68 · 178행 일치
- 확인 RC77 — 확인 — shared/docreview/scripts/docreview_state.py#def _rg_decide(st, g, fid) — 2310–2315 · 2223–2225행 일치
- 확인 RC78 — 확인 — plugins/spec-distill/agents/doc-critic.md#`summary`·`if_unfixed`·`replacement` 는 게이트에 그대로 실려 처음 보는 사람이 읽는다 — 60 · 68행 일치
- 확인 RC79 — 확인 — shared/docreview/references/reviewing-document.md#렌더 첫 줄(상태와 경고)은 첫 호출 **앞 글**에 한 번 쓴다 — 30 · 42행 일치. 지적별 줄을 옮기라는 문장이 없다는 것은 찾지 못한 것이다
- 확인 RC80 — 확인 — plugins/spec-distill/references/proceed-gate.md#질문 본문에는 결정 하나와 「경고 N개 — 위에 적었다」 — 39–45 · 56행 일치
- 확인 RC81 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#옵션 description 에 싣지 않습니다 — 497 · 513 · 536행 일치
- 확인 RC82 — 확인 — plugins/spec-distill/tests/test_plain_gate_templates.sh## ⑬ 질문 본문에는 결정과 상태 한 줄만 — 134–147 · 150행 일치
- 확인 RC83 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#사용자에게 보이는 출력과 state 본문 기록이 같은 형식이다 — 180 · 190 · 204–205행 일치
- 확인 RC84 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#지휘자는 배경을 먼저 쉬운 말로 쓰고 질문만 봐도 결정할 수 있게 묻는다 — 32행 일치. 29행은 읽지 않았다
- 확인 RC85 — 확인 — docs/superpowers/interview/2026-11-15-present-tradeoffs-brief-interview.state.md#앞 글 0자인 질문 앞에는 전부 생각 블록이 있었다 — 236–238행(이 인터뷰의 재측정 줄) 일치
- 확인 RC86 — 확인 — docs/superpowers/interview/2026-10-27-askquestion-recommendation-interview.md#해결: 보였는데 놓침 — 라벨 표시의 강도가 핵심 — 175 · 181 · 195행 일치
- 확인 RC87 — 확인 — shared/tests/ask_recommendation.py#def required(kind, body) — 109–127행 일치
- 확인 RC88 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#재비판이 심각도를 낮춘 지적이 <n>개 있다(위 「낮춘 지적」 절) — 707–720행 일치

웹 주장 확인(본체)
- 웹 공식 훅 문서 — 일부 확인(1차 · code.claude.com/docs/en/hooks · 2026-11-15) — 훅이 도구 호출을 막고 이유를 모델에 돌려줄 수 있다(permissionDecision deny)까지 읽었다. 질문 도구에 그대로 통하는지 · 호출한 skill 을 알려 주는 칸이 있는지는 읽은 범위에 없었다 [→ OQ3]
- 웹 조사 5 · 6 의 창 안 잘림 이슈(#39867 · #29125 · #88494 · #89644) · 연구(Bansal · Buçinca · Vasconcelos · 공간 근접) · Microsoft · W3C · MCP · gstack — 확인 못 함(본체가 다시 확인하지 않음)
- 재측정: 깔린 Claude Code 2.1.325(claude --version). R2 의 앞 글도 글 블록(929자)으로 기록에 남았다.

steelman ST1 — 게이트-전 확인
- dispatch 입력: goal = S1 의 goal 문장(「이 일의 목표는 … 알 수 있게 하는 것이다. (사용자 확인)」) · 전제 P1–P7 · 제약 S1–S9 와 지난 인터뷰의 D13 · D16 · C17
- 전제: P1 화면에 보이는 글만으로 무엇을 고르는지와 그 대가를 알 수 있어야 한다(S1) · P2 추천에는 내주는 것을 함께 적는다(S1) · P3 얻음 · 내줌은 한 줄 정도의 짧은 형식(S1) · P4 질문 위 글은 사라지는 날이 있어 기대면 안 된다(S7 · orchestrator 도출 포함) · P5 설명 칸에 글자가 있어도 라벨을 되풀이하거나 너무 짧으면 빈 것과 같다(S8) · P6 리뷰 결정 질문은 창 안에 무엇이 문제인지 · 그대로 두면 · 고치면이 있어야 한다(S9) · P7 범위는 devbrew 가 글을 쓰는 방향 자리와 리뷰 뒤 결정 질문이고 설계 · 계획 대화는 외부 skill 몫(S1 · S4 · S5 · S6)
- 리포 주장 15 중 확인 15(RC74–RC88)
- 양성 부착 13건 대조: #75182→P4 확인 · changelog→P4 확인 · Microsoft command link→P2 · P3 · P5 확인 · Microsoft dialog→P1 · P6 확인 · W3C→P1 · P2 확인 · MCP→P1 확인 · gstack→P2 확인 · #77242→P1 확인 · #29125→P3 확인 · #67113→P3 확인 · Bansal→P2 확인 · Vasconcelos→P3 확인 · 공간 근접→P1 확인. 대조는 「그 주장이 그 전제에 닿는가」이고 출처를 본체가 다시 읽은 것은 #75182 하나다
- premise_refutation.hits: 없음 → 재검토 사유 없음 — 확인된 전제 충돌 0건
- 근거 17 중 부착 13 · 리포 주장 15 중 확인 15

### 다음 결정
ST1: 의심 방향의 판정(유지 / 보완 / 전환 / 보류) — steelman 절차의 질문

### 질문
(방향 판정) 「이유 · 대가 · 지적 내용을 질문 창 안에 싣는다」는 방향을 반대 논거와 맞세워 봤습니다. 지금까지 하신 말씀(전제 일곱)과 부딪히는 근거는 0건이었고, 조사는 「보완」을 권합니다. 양쪽 논거 전문은 이 창 위 글에 있습니다 — 안 보이면 기타 칸에 「안 보인다」라고 적어 주세요. 어느 쪽으로 할까요?

### 답
→ S10 (방향 판정 · ST1): 보완 (builder·orchestrator 추천)

## R4

### 지금 이해
S10 으로 방향이 정해졌다(ST1 보완) — 질문 창이 정본 통로다(어느 질문도 앞 글이 보여야만 고를 수 있게 짜지 않는다) · 설명은 한 줄(길어도 세 줄) · 앞 글은 덤으로 남긴다 · 추천이 없는 질문과 이름만으로 뜻이 서는 선택지에는 얻음 · 내줌을 억지로 채우지 않는다 · 지키게 하는 장치는 규칙 문장과 레포 테스트까지이고 실행 중 검사는 두지 않는다.
(경로 a · 웹) Microsoft command link 지침을 본체가 1차로 읽었다 — 「If a response is strongly recommended, add "(recommended)" to the label」 · 「Supplemental explanations describe why users might want to choose a response or what happens if a response is chosen」 · 「Use parallel phrasing and at most three lines of text」 · 「Don't use a supplemental explanation that is wordy restatement of the command link」 · 「Omit details that don't affect the choice」 가 그 페이지에 있다.
조사 호출 5/60 · 이 라운드 본체 직접 1
밀린 질문 2개 — 바깥 선례의 처분(landscape) · 레포에서 확인한 사실의 처분(internal_research)

- 웹 Microsoft command link 지침 — 확인(1차 · learn.microsoft.com · 2026-11-15 · Windows 7 때 문서이고 「Much of the guidance still applies in principle」 주석이 있다) [→ OQ4]

### 다음 결정
OQ12: 경고 목록을 질문 창 안에 실을지 · 추천: 첫 질문 본문에 한 줄씩 · 트레이드오프: 첫 질문 본문에 — 직접 보신 사례가 고쳐지나 경고가 많으면 질문이 길어지고 지금 규칙 · 테스트를 뒤집는다 / 가장 무거운 하나와 개수만 — 짧으나 나머지는 여전히 앞 글에 기댄다 / 지금 그대로 — 고칠 것이 없으나 「위에 적었다」가 남는다
OQ10: 질문 밖 「권하는 글」(지휘자 의견 포함)을 어디까지 넣을지 · 추천: 문장 권고 자리 셋에 대가를 붙인다 · 트레이드오프: 셋에 붙인다 — 확정 범위(권하는 글에도 대가)를 지키나 그 줄은 질문 밖 글이라 사라질 수 있다 / 지휘자 의견은 뺀다 — 옮김 대조 규칙을 건드리지 않으나 지휘자의 권고는 대가 없이 남는다 / 공통 규칙 한 문장만 — 가장 가벼우나 어느 자리가 지키는지 아무도 모른다
OQ11: 고쳐졌는지 무엇으로 확인할지 · 추천: 기록 재측정과 화면 확인 둘 다 · 트레이드오프: 둘 다 — 기계 수치와 실제 화면을 함께 보나 검증이 길어진다 / 기록만 — 반복해 재기 쉬우나 화면에 보였는지는 모른다 / 화면만 — 직접 보나 사람 손이 들고 표본이 적다
blind_spot: 숨은 가정 · 실패 양식의 처분 · 추천: 전부 위험으로 싣는다 · 트레이드오프: 전부 — 설계가 일곱을 하나씩 다루나 설계가 길어진다 / 일부만 — 짧아지나 뺀 위험은 설계가 보지 않는다

### 질문
1. (경고 목록) 리뷰 뒤 질문의 「경고 N개 — 위에 적었다」가 가리키는 것은 경고 목록입니다(예: 리뷰어 하나가 돌지 못했다). 직접 열어 본 사례가 바로 이 줄이었습니다. 지금 규칙은 경고를 질문 앞 글에만 쓰고 선택지 설명에는 싣지 말라고 하며, 그 문장이 테스트로 잠겨 있습니다. 방금 고르신 방향(질문 창만 보고 고를 수 있게)을 경고에도 적용할까요? 첫 질문 본문에 싣기를 권합니다 — 한 번에 질문이 여럿 떠도 같은 경고가 되풀이되지 않습니다.
2. (권하는 글) 질문이 아닌 글에서 모델이 한쪽을 권하는 자리를 레포에서 셋 찾았습니다 — 인터뷰 끝의 「하나로 충분해 보인다 / 나누는 게 좋아 보인다」 권고 한 줄, 다음 단계를 제안하는 이유 한 줄, 지휘자가 옮긴 질문에 붙이는 「지휘자 의견:」 한 줄. 「권하는 글에도 대가를 같이 적는다」를 이 자리들에 어떻게 걸까요? 알아 두실 사실: 지휘자 의견은 일부러 선택지 밖에 두게 돼 있고(옮긴 질문의 원문을 지키려고), 그것을 대조하는 리뷰어 규칙이 있습니다. 셋 모두에 「대가 한 구절」을 붙이기를 권합니다 — 자리는 그대로 두고 문장만 늘립니다.
3. (확인 방법) 이 일이 끝난 뒤 「고쳐졌다」를 무엇으로 확인할까요? 알아 두실 사실: 세션 기록에는 질문 창에 넣은 글(본문 · 설명)이 그대로 남아 기계로 잴 수 있지만, 화면에 실제로 보였는지(잘림 · 사라짐)는 기록에 없습니다. 둘 다를 권합니다.
4. (위험 처분) 숨은 가정을 찾는 조사가 실패 양식 일곱을 냈습니다. ① 설명이 길면 아래쪽 선택지 설명이 잘린다(보고 있음 · 지금 판에서는 재지 않음) ② 기타 칸을 고르면 질문과 설명이 화면에서 사라진다(보고 있음) ③ 공통 규칙 한 줄만 고치면 자리마다 따로 정한 규칙이 이겨 리뷰 질문은 그대로다 ④ 「얻음 · 내줌」이 형식 채우기가 된다 — 추천을 낸 모델이 자기 추천의 대가를 가볍게 적는다 ⑤ 모델이 리뷰어의 글을 줄이다 뜻이 달라진다 ⑥ 기록 수치로만 확인하면 화면은 확인되지 않는다 ⑦ 지휘자가 옮기는 질문에서 대조 규칙과 부딪힌다. 이것들을 설계가 다뤄야 할 위험으로 넘길까요? 전부 넘기기를 권합니다.

### 답
→ S11 (경고 목록): 첫 질문 본문에 한 줄씩 (권장)
→ S12 (권하는 글): 셋 모두에 대가 한 구절 (권장)
→ S13 (확인 방법): 기록 재측정과 화면 확인 둘 다 (권장)
→ S14 (위험 처분): 전부 위험으로 넘긴다 (권장)

## R5

### 지금 이해
S11–S14 로 넷이 정해졌다 — 경고 목록은 첫 질문 본문에 한 줄씩 싣는다 · 질문 밖 「권하는 글」 자리 셋(분해 권고 · 다음 단계 제안 이유 · 지휘자 의견)에 대가 한 구절을 붙인다 · 고쳐졌는지는 세션 기록 재측정과 실제 화면 확인 둘 다로 본다 · 실패 양식 일곱은 전부 설계가 다룰 위험으로 넘긴다. 네 답 모두 이유 없는 추천 수락이라 가장 무거운 하나(경고를 질문 본문에 — 5.1.0 에서 일부러 들인 규칙을 뒤집는다)의 실패 조건을 되묻는다.
root_problem 은 사용자 원문으로 닫는다 — 「전반적으로 트레이드 오프를 같이 제시해줘야함」 · 「리뷰어가 리뷰한뒤에 나한테 ask question하는데 설명이 비어있음 그리고 위를 보라는데 위에 아무것도 없음 설명도 부족」(S1) · 「글자는 있었지만 내용이 없었다」(S8).
(경로 a) 두 문제가 한 뿌리라는 Phase 0 의 추론은 규칙 쪽에서는 확인됐다 — 추천의 이유(공통 규칙 6행 「이유는 질문 위 글에」)와 리뷰의 경고 · 상세(「질문 본문에는 결정 하나와 한 줄만」)는 둘 다 「내용은 질문 위 글에, 질문 창에는 표시만」이라는 같은 꼴의 규칙이다(RC30). 사용자가 겪은 원인이 그것인지는 확인하지 못했다.
조사 호출 5/60 · 이 라운드 본체 직접 0
밀린 질문 0개

### 다음 결정
되묻기(S11): 경고가 많아 질문이 길어질 때 · 추천: 셋까지 싣고 나머지는 개수 · 트레이드오프: 셋까지 — 질문이 잘릴 위험이 줄어드나 넷째부터는 앞 글에 기댄다 / 전부 — 하나도 빠지지 않으나 길어져 잘릴 수 있다 / 설계가 화면을 재고 정한다 — 근거가 생기나 이 인터뷰에서는 열린 채 남는다
landscape: 바깥 선례의 처분 · 추천: 이대로 받아들인다 · 트레이드오프: 이대로 — 바깥 기준 셋이 설계 요건이 되나 본체가 다시 확인하지 않은 둘은 설계 때 원문 확인이 필요하다 / 원문 확인한 것만 — 확인된 근거만 요건이 되나 「모든 선택지에 같은 꼴」 요건이 빠진다
internal_research: 레포에 이미 있는 것을 옮겨 쓸지 · 추천: 있는 것을 옮겨 쓴다 · 트레이드오프: 옮겨 쓴다 — 새 장치 없이 리뷰어가 쓴 글이 그대로 화면에 가나 글이 길면 그대로 길다 / 질문용 요약을 새로 쓴다 — 창에 맞는 길이가 되나 요약하는 쪽이 지적의 뜻을 바꿀 수 있다
open_questions: 설계에 넘길 열린 질문 목록의 확인 · 추천: 이대로 넘긴다 · 트레이드오프: 이대로 — 인터뷰가 여기서 닫히나 빠진 것이 있으면 설계가 모른 채 시작한다 / 빠진 것이 있다 — 목록이 채워지나 한 라운드가 더 든다

### 질문
1. (경고가 많을 때) 경고를 첫 질문 본문에 싣기로 하셨습니다. 실패 조건 하나만 여쭙니다 — 경고가 많아(예: 다섯 이상) 질문이 길어지면 어떻게 할까요? 알아 두실 사실: 질문이나 설명이 길면 화면에서 잘린다는 보고가 있고(지금 깔린 판에서는 재지 않음), 지금의 「앞 글에만」 규칙은 지난 10월에 일부러 들인 것인데 왜 질문 안에서 뺐는지는 기록에 없습니다. 셋까지 싣고 나머지는 개수로 알리기를 권합니다.
2. (바깥 선례) 바깥 선례를 이렇게 받아들이려 합니다. 취함 셋 — (가) 추천 표시는 라벨에, 「왜 고를 만한지 · 고르면 어떻게 되는지」는 선택지 바로 아래 설명에 세 줄 이내로, 라벨을 되풀이하는 설명은 쓰지 않는다(Microsoft 지침 — 제가 원문 확인) (나) 선택지마다 결과와 불이익을 그 옆에 밝힌다(W3C 인지 접근성 패턴 — 조사 보고, 제가 다시 확인하지 않음) (다) 모든 선택지를 같은 꼴로 써서 추천 쪽에만 설득 문장이 붙지 않게 한다(추천 쏠림 · 과신 연구 — 조사 보고). 피함 하나 — 질문 안에 근거와 풀이를 길게 싣는 다른 도구의 형식(자리만 취하고 길이는 버림). 이대로 받아들이기를 권합니다.
3. (있는 것 쓰기) 레포에 이미 있는 것을 새로 만들지 않고 옮겨 쓰려 합니다 — (가) 리뷰어가 지적마다 이미 쓰는 세 칸(무엇이 문제인지 한 문장 · 그대로 두면 · 고치면)을 질문 본문과 두 선택지 설명에 그대로 싣는다 (나) 인터뷰가 이미 내는 「추천 · 트레이드오프」 한 줄 형식 (다) 지휘자 규칙의 「질문만 봐도 결정할 수 있게」 문장. 함께 고쳐야 하는 기존 규칙은 셋입니다 — 「질문 본문에는 결정 하나와 한 줄만」(여섯 자리 · 테스트로 잠김), 「경고를 선택지 설명에 싣지 않는다」, 공통 규칙의 「이유는 질문 위 글에」(skill 10개에 복제). 옮겨 쓰기를 권합니다.
4. (열린 질문) 이 인터뷰에서 정하지 않고 설계에 넘길 것은 여섯입니다 — ① 지금 깔린 판에서 질문 창 안 글이 얼마까지 보이는지(선택지 수 × 설명 줄 수)를 실제 화면에서 재기 ② 리뷰어의 「그대로 두면 · 고치면」이 길 때 누가 줄이는지 ③ 「얻음 · 내줌」이 형식 채우기가 되는 것을 무엇으로 막을지 ④ 코드 리뷰에서 낮춘 지적이 넷 이상이라 선택지가 둘로 접힐 때 항목별 내용을 어디에 실을지 ⑤ 추천을 일부러 비우는 질문에 실을 내용의 세부 ⑥ 공통 규칙과 지휘자 의견 줄의 새 문면. 빠진 것이 있나요? 이대로 넘기기를 권합니다.

### 답

## R6

### 지금 이해
[spec-distill] 포화 판정 1/5: 아직 — 빈 곳 4개, 다음: 경고 목록을 질문 밖으로 뺀 지난 변경(5.1.0)의 이유를 git 기록에서 찾기 · 조사 호출 5/60
판정자가 짚은 빈 곳 넷 가운데 셋을 본체가 직접 조사했다(경로 a). 넷째(실제 화면에서 잘림 재기)는 사용자만 볼 수 있어 이 라운드의 시험 질문으로 잰다.
- 경고를 질문 밖으로 뺀 이유를 찾았다 — 2026-10-08 「쉬운 말」 설계의 목표 4 「모든 게이트 질문은 결정 하나와 상태 한 줄만 담는다. 상태와 경고 목록은 질문 앞 글에 있다」. 질문을 짧게 하려는 것이었다. S11 · S15(경고를 첫 질문 본문에 셋까지)는 그 목표를 다시 정하는 것이다.
- 리뷰어 글은 길다 — 지난 세션 기록의 리뷰 렌더에서 「고치면」 줄은 중앙 182자 · 절반이 180자 초과 · 최대 484자, 「그대로 두면」 줄은 중앙 111자 · 37% 가 120자 초과였다. S17(리뷰어 글을 그대로 싣는다)과 S10(설명은 길어도 세 줄)이 「고치면」의 절반쯤에서 부딪힌다.
- 리뷰어 설정에서 길이를 묶은 칸은 「무엇이 문제인지」(한 문장)뿐이고 「그대로 두면 · 고치면」에는 길이 규칙이 없다.
판정자와 본체의 새로움 표시가 조사 2 · 4 · 5 · 6 · 7 에서 다르다(어느 결정을 바꿨다고 보는지) — 멈춤은 판정자를 따른다.
조사 호출 5/60 · 이 라운드 본체 직접 3
밀린 질문 2개 — 경고를 질문 본문에 싣는 결정을 지난 설계 목표와 맞춰 다시 볼지 · 리뷰어 글이 길 때 누가 줄일지(OQ14)

- 확인 RC89 — 확인 — docs/superpowers/specs/2026-10-08-plain-language-output-design.md#3. 스킬이 시키는 질문·보고 틀: 질문 하나에 결정 하나만 담고, 경고 목록은 질문 앞으로 옮긴다. — 19 · 90–91 · 255–257행(목표 4 와 게이트 규칙) · 그 변경이 들어온 커밋은 2026-10-09 의 79d010ab · de05ce3a · dc4510d0 · 6b74f39b(커밋 본문에 이유 없음)
- 확인 RC90 — 확인 — plugins/spec-distill/agents/doc-critic.md#`summary`(한 문장) — 길이를 묶은 칸은 summary 뿐이다. if_unfixed · replacement 를 정하는 파일은 doc-critic · doc-critic-web · doc-recritic(spec-distill 과 shared/docreview 의 사본) · 프로필 둘 · codex 변환기이고 어디에도 그 두 칸의 길이 규칙이 없다
- 확인 RC91 — 확인 — tools/plain-language/token_boundary.py#압축 뒤 다시 붙는 skill 앞 5,000토큰의 경계가 규칙 블록 때문에 어디로 옮겼는지 잰다(근사) — 새 문면을 넣은 뒤에야 잴 수 있는 측정 도구다(근사식 · 실제 tokenizer 로 보정하지 않음). 부르는 테스트는 plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh 하나
- 재측정: 기록 804개의 도구 출력에서 서로 다른 「그대로 두면」 줄 108개(자리표 1개 · 중앙 111자 · 75% 132자 · 90% 158자 · 최대 344자 · 60자 초과 92% · 120자 초과 37% · 180자 초과 6%) · 「고치면」 줄 109개(자리표 1개 · 중앙 182자 · 75% 217자 · 90% 299자 · 최대 484자 · 60자 초과 98% · 120자 초과 89% · 180자 초과 50%)

### 다음 결정
OQ13: 지금 깔린 판(2.1.325)의 화면에서 질문 창 안 글이 얼마까지 보이는가(사용자만 볼 수 있는 사실) · 추천: 없음 — 측정을 묻는 질문 · 트레이드오프: 해당 없음

### 질문
1. (화면 시험) 결정이 아니라 측정입니다. 설명이 긴 선택지 넷을 일부러 띄웠습니다 — 설명마다 세 줄쯤이고 맨 끝에 「끝말」이 있습니다. 설명의 끝말까지 보이는 선택지를 모두 골라 주세요. 이 본문에는 경고 꼴의 줄 셋도 넣었습니다. 경고 1: 리뷰어 하나가 돌지 못해 이번 판정은 한 리뷰어의 것입니다. 경고 2: 문서에 제목이 없어 지적의 자리를 가리키지 못했습니다. 경고 3: 이전 라운드의 기록 파일을 다시 읽었습니다. ◆본문 끝
2. (본문 확인) 방금 첫 질문의 본문에서 경고 세 줄과 「◆본문 끝」 표시까지 모두 보였나요?

### 답
→ S19 (화면 시험): 첫째 선택지, 둘째 선택지, 셋째 선택지, 넷째 선택지
→ S20 (본문 확인): 모두 보였다

## R7

### 지금 이해
화면 시험(S19 · S20): 깔린 판 2.1.325 에서 한 호출에 질문 둘 · 선택지 넷 · 설명마다 약 180자(세 줄쯤) · 본문에 경고 세 줄을 실은 꼴이 끝까지 다 보였다 — 설명 끝말 넷과 「◆본문 끝」 표시 모두. 한 번의 측정이고, 더 긴 글(「고치면」 줄의 열에 하나는 300자 이상) · 다른 창 크기 · 기타 칸을 골랐을 때는 재지 않았다.
이 라운드는 앞 라운드에서 밀린 둘이다 — 둘 다 이미 받은 답(S11 · S15 · S17)을 새로 찾은 사실에 비춰 다시 본다(근거를 보이고 사용자 동의로만 다시 정한다).
조사 호출 5/60 · 이 라운드 본체 직접 1
밀린 질문 0개

- 질문을 띄우기 전에 사용자가 세 마디를 보냈다(S21 · S22 · S23 — 원문 그대로): 「너무 긴게 좋은건 아니야」 · 「요즘 클로드는 서머리도 되는듯한데」 · 「본문에 서머리」. 준비한 두 질문을 이 말에 맞춰 고쳤다 — 길이 질문은 「본문에 요약」의 읽기를 확인하는 질문으로 바꾸고, 경고 질문에 「요약 한 줄」 선택지를 더했다. 이 인터뷰의 질문도 이때부터 짧게 쓴다.

### 다음 결정
OQ14 · S17 재확인: 「본문에 서머리」의 읽기 — 리뷰어의 긴 글을 그대로 싣지 않고 모델이 줄인 요약을 질문 본문에 싣는다 · 추천: 요약은 본문에 · 전문은 앞 글에 · 트레이드오프: 요약 + 전문 — 창이 짧고 원문도 남으나 요약이 뜻을 바꾸지 않게 하는 법을 설계가 정해야 한다 / 요약만 — 가장 짧으나 원문을 볼 곳이 없다 / 다르게 읽었다 — 다시 여쭌다
OQ12 재확인: 경고를 질문에 어떻게 실을지(지난 10월 설계 목표 「질문은 결정 하나와 한 줄만」을 알고) · 추천: 요약 한 줄 · 트레이드오프: 요약 한 줄 — 짧고 무슨 경고인지 알 수 있으나 낱낱은 앞 글에 기댄다 / 셋까지 한 줄씩 — 낱낱이 보이나 질문이 서너 줄 길어진다 / 앞 글에만 — 가장 짧으나 「위에 적었다」가 남는다

### 질문
1. (요약 읽기) 「본문에 서머리」를 이렇게 읽었습니다 — 리뷰 뒤 질문에는 리뷰어의 긴 글 대신 모델이 줄인 요약을 질문 본문에 싣는다. 맞나요? (잰 사실: 리뷰어의 「고치면」 줄은 절반이 180자를 넘습니다.)
2. (경고) 경고도 같은 식으로 할까요? 지난 10월에는 질문을 짧게 하려고 경고를 질문 밖으로 뺐습니다.

### 답

## R8

### 지금 이해
[spec-distill] 포화 판정 2/5: 아직 — 빈 곳 5개, 다음: 화면 시험에서 재지 않은 것(300자 이상 설명 · 좁은 창 · 기타 칸)을 같은 시험 질문으로 재기 · 조사 호출 5/60
판정 근거: 최근 두 묶음(조사 9 · 10)이 모두 결정을 바꿨다(OQ12 · OQ14 · OQ13). 빈 곳 다섯은 앞 판정의 넷과 겹치지 않는다(결정 집합 · 장치가 다르다 — 반복 아님). 다섯 모두 설계에 넘기기로 한 열린 질문(OQ13 · OQ15–OQ19)의 세부에 닿고, 첫째는 사용자가 화면을 봐야 잴 수 있다.
판정자와 본체의 새로움 표시가 조사 2 · 4 · 5 · 6 · 7 · 10 에서 다르다 — 멈춤은 판정자를 따른다.
조사 호출 5/60 · 이 라운드 본체 직접 0
밀린 질문 0개

### 다음 결정
남은 조사를 지금 할지 설계에 넘길지 · 추천: 여기서 끝내고 설계에 넘긴다 · 트레이드오프: 넘긴다 — brief 로 가고 남은 조사는 설계가 실제 문면을 놓고 하나 「조사가 덜 됐다」는 판정이 brief 에 남는다 / 더 조사한다 — 설계 전에 사실이 채워지나 조사 서너 번 · 화면 시험 · 질문 라운드가 더 든다 / 화면 시험만 한 번 더 — 긴 글이 잘리는지 지금 아나 긴 시험 화면을 한 번 더 봐야 한다

### 질문
(남은 조사) 조사가 충분한지 판정이 두 번 「아직」으로 나왔습니다. 남은 빈 곳 다섯은 모두 설계에 넘기기로 하신 열린 질문의 세부입니다(화면에 얼마까지 보이는지 · 요약이 뜻을 바꾸지 않게 하는 법 · 형식 채우기 · 코드 리뷰의 접힘 · 새 문면). 어떻게 할까요?

### 답
→ S26 (남은 조사): 더 조사한다

## R9

### 지금 이해
S26 으로 빈 곳 다섯을 조사한다. 레포 조사 둘(조사 11 · 12 — 요약이 뜻을 바꾸지 않게 하는 장치 · 접힘 규칙과 문면 락)을 한 묶음으로 띄웠고 결과를 기다린다. 서로 기대지 않아 함께 보냈다.
(경로 a) 본체가 지난 세션 기록에서 추천 꼬리가 붙은 선택지 설명을 쟀다 — 서로 다른 644개 가운데 무작위 24개를 손으로 가르니 내주는 것을 적은 설명이 8개, 고르면 일어나는 일만 적은 것이 13개, 라벨을 거의 되풀이한 것이 3개였다(한 사람이 한 번 가른 표본). 낱말 맞추기로는 644개 중 96개(15%)에 대가를 가리킬 만한 낱말이 있었다.
새 문면의 토큰 경계는 재지 못했다 — 후보 문면이 있어야 잴 수 있다.
조사 호출 7/60 · 이 라운드 본체 직접 1
밀린 질문 1개 — 조사 11 · 12 결과의 처분

### 다음 결정
OQ13: 300자 · 480자 설명과 기타 칸을 골랐을 때 화면에 무엇이 남는가(사용자만 볼 수 있는 사실) · 추천: 없음 — 측정을 묻는 질문 · 트레이드오프: 해당 없음

### 질문
1. (긴 글 시험) 측정입니다. 설명에 번호 붙은 줄을 넣었습니다 — 위 둘은 약 300자, 아래 둘은 약 480자이고 맨 끝에 끝말이 있습니다. 끝말까지 보이는 선택지를 모두 골라 주세요. 중간에 끊겼으면 몇 번 줄까지 보였는지 기타 칸에 적어 주세요.
2. (기타 칸 시험) 이 질문에서는 선택지를 고르지 말고 기타 칸에 아무 글자나 적어 주세요. 답한 뒤에도 이 질문과 선택지 설명이 화면에 남아 있는지를 다음에 여쭙니다.

### 답

## R10

### 지금 이해
레포 조사 둘(조사 11 · 12)이 도착해 본체가 원문과 대조했다(RC92–RC135 — 확인 43 · 미확인 1).
- 지금 있는 대조 장치(옮긴 질문을 대조하는 리뷰어)는 선택지 수 · 순서 · 라벨 글자 · 추천 표시의 출처만 보고 요약의 뜻은 보지 않으며, 일이 끝난 뒤에 본다.
- 줄이기 규칙이 자리마다 다르다 — 공통 규칙은 「원문은 고치지 않는다」, 리뷰 절차서는 라벨을 「대체안 1–5 낱말로 압축」(필수), 저자 편집 덩어리와 코드 리뷰의 쉬운 말 한 줄은 「줄이지 않고 그대로」.
- 코드 리뷰의 낮춘 지적 게이트가 넷 이상에서 선택지를 둘로 접는 이유는 설계 · 계획 · 변경 기록 어디에도 없다. 요청 정리 단계는 같은 상황을 「넷씩 나눈다」로 푼다.
- 「이유는 질문 위 글에」와 「지휘자 의견:」 줄을 글자째 잠근 테스트는 각각 둘 · 셋이다.
- 리뷰어에 칸을 더하면 고칠 자리가 여럿이다(리뷰어 설정의 원본과 사본 · 다른 모델 리뷰어의 변환기와 지시문 · 엔진의 칸 목록).
화면 시험(S27): 약 300자 · 480자 설명 넷이 끝까지 보였다. 기타 칸에 글자를 적어 답할 수 있었다(S28).
조사 호출 7/60 · 이 라운드 본체 직접 1
밀린 질문 0개

레포 주장 확인(V1) — RC92–RC135
- 확인 RC92 — 확인 — plugins/spec-distill/agents/relay-checker.md#볼 것 — 29–37행 일치 — 대조 항목은 다섯이고 요약의 뜻 · 설명의 내용을 대조하는 항목은 없다
- 확인 RC93 — 확인 — plugins/spec-distill/skills/epic-conductor/SKILL.md#7. 옮김 대조 — 190–192행 일치 — 에픽이 끝난 뒤의 사후 대조다
- 확인 RC94 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#사람 자리 — 32행 일치(문장 수를 지킨다 · 원문은 늘 붙인다 · 지휘자 의견은 선택지 밖)
- 확인 RC95 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#쓰기 권한 없는 agent 가 둘의 선택지 수 · 라벨 · 순서를 대조한다 — 32행 일치
- 확인 RC96 — 확인 — plugins/spec-distill/tests/test_conductor_dispatch_reference.sh#once — 12–26행 일치. test_epic_conductor_skill.sh · test_conducting_reference.sh 는 해당 줄만 확인했다
- 확인 RC97 — 확인 — plugins/spec-distill/agents/doc-critic.md#출력 형식 — 60 · 68행 일치
- 확인 RC98 — 확인 — plugins/spec-distill/references/docreview-profiles/brief.md#사용자가 결정할 질문 하나 — 21행 일치. 45행 · design-doc.md 61행은 앞서 확인했고 112행은 읽지 않았다
- 확인 RC99 — 확인 — plugins/spec-distill/agents/doc-recritic.md#같은 칸을 싣는다 — 58행 일치
- 확인 RC100 — 확인 — shared/codex/codex_findings_to_yaml.py#DOCREVIEW_KEYS — 73–75행 일치. codex 지시문과 그 테스트는 읽지 않았다
- 확인 RC101 — 확인 — shared/tests/test_docreview_agent_fields.sh#부분 문자열 — 11행 일치 · 테스트 폴더에 summary 한 문장 · 재진술 문구의 핀 0건
- 확인 RC102 — 미확인 — plugins/spec-distill/tests/test_overdesign_rubric.sh#field_mapping_line_of — 읽지 않았다
- 확인 RC103 — 확인 — shared/docreview/scripts/docreview_state.py#_rg_decide — 2295–2322 · 2223–2225행 일치. 결정이 아닌 행의 함수들은 읽지 않았다
- 확인 RC104 — 확인 — shared/docreview/scripts/docreview_route.py#부재를 summary 로 메우지 않는다 — 511–516행 일치. normalize · _classify_items 와 cases.sh 는 읽지 않았다
- 확인 RC105 — 확인 — shared/docreview/scripts/docreview_advice.py#def clip — 166–168행 · docreview_config.py 13행(summary_width 60) 일치
- 확인 RC106 — 확인 — shared/docreview/references/reviewing-document.md#`AskUserQuestion` 라벨의 항목별 내용 — 42행 일치
- 확인 RC107 — 확인 — shared/docreview/references/reviewing-document.md#8. **게이트** — 27–40 · 86행 · spec-review SKILL.md 509행 일치
- 확인 RC108 — 확인 — shared/style/plain-language.md#스크립트·subagent 가 낸 원문은 고치지 않는다 — 블록 9 · 3행 일치
- 확인 RC109 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#덩어리 본문(`render`)은 질문 텍스트에 줄임 없이 싣는다 — 935행 · steelman.md 94행 · quality-pipeline SKILL.md 560행 일치
- 확인 RC110 — 확인 — CLAUDE.md#Law 2 — Writer and Reviewer Must Never Share a Pass. — 일치
- 확인 RC111 — 확인 — CLAUDE.md#Persona 파일은 보안-민감 코드. — 78행 일치
- 확인 RC112 — 확인 — shared/tests/test_copy_of_contract.sh#copy-of 물리 사본 — 10–11행 · docreview_state.py 1110행(PUBLIC_FIELDS) 일치. 나머지 자리는 읽지 않았다
- 확인 RC113 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#낮춘 지적 게이트 (표면화 뒤 · 라우팅 앞). — 707–720행 일치
- 확인 RC114 — 확인 — docs/superpowers/plans/2026-10-19-r2a-plan3-qg-devices-range-persona.md#n ≥ 4: {label: "전부 되올린다" — 767–769행 일치. 상위 설계의 줄은 읽지 않았다
- 확인 RC115 — 확인 — docs/superpowers/specs/2026-10-25-qg-range-repairs-design.md#고를 지적이 넷 이상인 낮춘 지적 게이트 — 95행 · quality-gates CHANGELOG 28행 일치
- 확인 RC116 — 확인 — plugins/quality-gates/CHANGELOG.md#「낮춘 지적」 — 재비판이 낮춘 지적을 합성기가 — 146행 일치 · 「넷 이상」은 28행 한 곳
- 확인 RC117 — 확인 — plugins/quality-gates/scripts/synthesize_findings.py#_lowered_lines — 711–719행 일치
- 확인 RC118 — 확인 — plugins/quality-gates/tests/test_plain_qg_templates.sh#AC26: 낮춘 지적 게이트 질문이 한국어다 — 50–51행 일치
- 확인 RC119 — 확인 — plugins/quality-gates/tests/test_lowered_gate_wiring.sh#case_step45_gate — 49–61행 일치
- 확인 RC120 — 확인 — shared/tests/ask_recommendation.py#EMPTY =  — 26행 · required() 일치
- 확인 RC121 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#덩어리마다 질문 하나 — 933–935행 일치. 테스트 줄은 읽지 않았다
- 확인 RC122 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#기준 사본이 없으면 — 937–939행 일치
- 확인 RC123 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#덜어 낸 것이 1개 이상이면 — 1175–1176행 일치
- 확인 RC124 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#추천을 달지 않는다 — 낮춘 지적을 되올릴지는 — 720행 일치
- 확인 RC125 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#분류표의 적용/제외를 바꿀까요 — 861 · 873행 일치. 선택지 줄은 읽지 않았다
- 확인 RC126 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#지휘자 의견은 선택지 밖 「지휘자 의견:」 한 줄로만 쓴다. — 32행 일치
- 확인 RC127 — 확인 — plugins/spec-distill/references/conducting.md#지휘 세션의 의견은 선택지 밖 「지휘자 의견:」 한 줄로만 쓰고 — 102행 일치
- 확인 RC128 — 확인 — plugins/spec-distill/agents/relay-checker.md#지휘자 의견이 선택지 설명 안으로 들어갔으면 어긋남이다 — 34 · 37행 일치
- 확인 RC129 — 확인 — plugins/spec-distill/tests/test_conductor_dispatch_reference.sh#once '## 사람 자리' — 26행 · test_conducting_reference.sh 117–119행 · test_epic_conductor_skill.sh 81행 일치
- 확인 RC130 — 확인 — docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md#「지휘자 의견:」 줄에 어느 꼬리가 지휘자의 것인지와 이유를 쓴다(필수 — 115행 일치. 122행은 읽지 않았다
- 확인 RC131 — 확인 — shared/tests/test_plain_language_block.sh#REC='추천이 있으면 그 선택지를 첫 자리에 두고 — 30 · 32행 일치
- 확인 RC132 — 확인 — shared/tests/plain_language_block.py#if region != canon: — 51–52행 · 사본 10개 일치
- 확인 RC133 — 확인 — plugins/spec-distill/tests/test_review_handoff_order.sh#라벨에 「(권장)」을 달고 이유는 질문 위 글에 한 줄로 쓴다 — 191행 · saturation.md 35행 일치
- 확인 RC134 — 확인 — tools/plain-language/token_boundary.py#def main(argv=None): — 47–69행 일치(--base 필수 · 측정만 낸다)
- 확인 RC135 — 확인 — plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh#import token_boundary as tb — 202–210행 일치

### 다음 결정
OQ13: 기타 칸에 답한 뒤 질문과 설명이 화면에 남는가(사용자만 볼 수 있는 사실) · 추천: 없음 — 측정을 묻는 질문 · 트레이드오프: 해당 없음
OQ16 · OQ18 · OQ19: 조사 11 · 12 가 찾은 사실의 처분 · 추천: 설계에 넘긴다 · 트레이드오프: 넘긴다 — 설계가 실제 문면을 놓고 정하나 이 인터뷰에서는 열린 채 남는다 / 지금 정할 것이 있다 — 설계 전에 방향이 하나 더 서나 한 라운드가 더 든다

### 질문
1. (기타 칸) 앞 질문에서 기타 칸에 「1」을 적어 답하셨습니다. 답한 뒤에도 그 질문과 선택지 설명이 화면에 남아 있었나요?
2. (조사 처분) 레포 조사가 찾은 것 넷을 설계에 넘기려 합니다 — ① 지금 있는 대조 장치는 요약의 뜻을 보지 않는다 ② 줄이기 규칙이 자리마다 다르다 ③ 코드 리뷰가 넷 이상에서 선택지를 둘로 접는 이유는 기록에 없다 ④ 문면을 잠근 테스트 목록. 이대로 넘길까요?

### 답

## R11

### 지금 이해
[spec-distill] 포화 판정 3/5: 아직 — 빈 곳 3개, 다음: 추천 선택지 설명을 자리 종류별로 갈라 다시 보기 · 조사 호출 7/60
판정 근거: 최근 두 묶음은 결정을 바꾸지도 열지도 않았으나 열린 결정을 겨눈 조사가 아니었고 빈 곳 셋이 남았다. 셋 모두 본체가 직접 잴 수 있고 앞 판정의 빈 곳과 겹치지 않는다(결정 집합 · 장치가 다르다 — 반복 아님).
(경로 a) 본체가 둘을 쟀다.
- 추천 선택지 설명 49개를 단계별로 갈라 보니 내주는 것을 적은 설명은 10개였다 — 지휘자 4/7 · 인터뷰 2/7 · 설계문서 리뷰 1/7 · 설계 대화 1/7 · 코드 리뷰 1/7 · 그 밖 1/7 · 요청 정리 0/7(한 사람이 한 번 가른 표본).
- 공통 규칙 블록을 약 180자 넘게 늘리면 plugin-audit skill 에서 절 하나가 앞 5,000토큰 경계 밖으로 밀린다(보수 근사). 구절을 바꾸거나 짧은 문장 하나를 더하는 것은 열 skill 모두에서 여유 안이다.
셋째 빈 곳(한 호출에 질문 넷 · 좁은 창)은 이 라운드의 시험 질문으로 잰다.
판정자와 본체의 새로움 표시가 조사 2 · 4 · 5 · 6 · 7 · 10 · 11 · 16 에서 다르다 — 멈춤은 판정자를 따른다.
조사 호출 7/60 · 이 라운드 본체 직접 2
밀린 질문 0개

### 다음 결정
OQ18 · OQ19: 한 호출에 질문 넷을 묶은 꼴과 좁은 창에서 화면에 무엇이 보이는가(사용자만 볼 수 있는 사실) · 추천: 없음 — 측정을 묻는 질문 · 트레이드오프: 해당 없음

### 질문
1–3. (넷 묶음 시험) 리뷰 뒤 질문이 실제로 뜰 꼴(문제 한 줄 요약 + 선택지 셋)을 한 번에 넷 묶어 띄웠습니다. 본문의 끝 표시와 선택지 설명 셋의 끝말이 다 보이면 「다 보인다」를 골라 주세요. 가능하면 창을 가로 80 · 세로 24 쯤으로 줄인 뒤 답해 주세요(어려우면 그대로).
4. (창 크기) 창을 줄이고 답하셨나요?

### 답

## R12

### 지금 이해
[spec-distill] 포화 판정 4/5: 아직 — 빈 곳 5개, 다음: 공통 규칙의 새 문면 후보를 실제로 적어 길이 여유를 다시 재기 · 조사 호출 7/60
판정 근거: 최근 두 묶음 가운데 하나(조사 18 — 공통 규칙 블록의 길이 여유)가 OQ18 을 바꿨다. 빈 곳 다섯 — ① 새 문면 후보를 적어 길이 여유를 다시 재기(OQ18) ② 좁은 창에서 긴 설명(300자 이상)이 보이는지 ③ 코드 리뷰가 넷 이상에서 선택지를 둘로 접은 이유를 git 기록에서 찾기 ④ 모델이 이미 하는 줄이기(라벨 압축)가 뜻을 바꾼 사례가 얼마나 있는지 ⑤ 추천을 낸 쪽이 대가를 스스로 적을 때 형식 채우기를 줄인 선례.
반복 감지: 첫째 빈 곳(OQ18 · 본체가 잼)이 앞 판정(3)의 빈 곳과 같다 — 혼자 다시 돌리지 않고 사용자에게 묻는다. 그 빈 곳은 새 문면 후보가 있어야 잴 수 있고, 후보 문면을 쓰는 것은 설계의 일이다.
판정자와 본체의 새로움 표시가 조사 2 · 4 · 5 · 6 · 7 · 9 · 10 · 11 · 16 에서 다르다 — 멈춤은 판정자를 따른다.
조사 호출 7/60 · 이 라운드 본체 직접 0
밀린 질문 0개

### 다음 결정
반복 빈 곳의 처분 · 추천: 포화로 보고 종료 · 트레이드오프: 종료 — brief 로 가고 빈 곳 다섯은 설계가 먼저 볼 것으로 넘기나 「조사가 덜 됐다」는 판정이 brief 에 남는다 / 한 번 더 조사 — 사실이 더 채워지나 판정은 한 번밖에 남지 않았고 같은 빈 곳이 다시 나올 수 있다 / 인터뷰 종료 — 여기서 멈추나 brief 는 사용자 종료로 기록된다

### 질문
(남은 조사) 판정이 네 번째도 「아직」이고, 같은 빈 곳(공통 규칙의 새 문면 길이 재기)이 되풀이됐습니다. 그것은 새 문면이 있어야 잴 수 있어 설계에서 할 일입니다. 어떻게 할까요?

### 답

## R13

### 지금 이해
S35 로 조사를 닫았다(포화 판정 4: 사용자 판단 포화 — 반복 빈 곳). 분해 판단의 신호 셋: 따로 승인할 수 있는 덩어리 5(공통 규칙 한 줄과 사본 ← S7 · OQ18 / 문서 리뷰 뒤 질문 규칙 ← S9 · S24 · S25 · OQ19 / 코드 리뷰 질문 ← S6 · OQ16 · OQ17 / 인터뷰 · 요청 정리 단계의 추천 대가 ← S4 · OQ15 / 문장 권고 자리 셋 ← S12) · 파일 영역 3(shared/ ← RC1 · RC5 · RC19 / plugins/spec-distill/ ← RC8 · RC11 · RC13 · RC14 / plugins/quality-gates/ ← RC24 · RC25 — 공통 규칙 사본은 다른 플러그인 둘에도 있다 RC69) · 사용자 원문 갈래 2(추천의 대가 / 리뷰 뒤 질문 — S1 에서 한 일로 묶음).
권고: 하나로 충분해 보인다 — 공통 규칙 한 줄이 skill 열 곳에 같은 커밋으로 들어가야 하고 리뷰 질문 규칙과 서로 물려 있어, 나누면 중간에 규칙과 문면이 어긋난다.
조사 호출 7/60 · 이 라운드 본체 직접 0

### 다음 결정
분해 판단: 이 일을 spec 하나로 할지 나눌지 · 추천: spec 하나로 · 트레이드오프: 하나로 — 규칙과 문면이 한 설계에서 함께 맞춰지나 설계문서가 길어진다 / 나눈다 — 덩어리마다 따로 승인하나 로드맵과 묶음을 만드는 절차가 더 든다

### 질문
(분해 판단) 이 일을 설계문서 하나로 할까요, 나눌까요? 잰 것: 따로 승인할 수 있는 덩어리 5 · 파일 영역 3(공통 규칙 · spec-distill · quality-gates) · 말씀하신 갈래 2(한 일로 묶으심). 하나로 하기를 권합니다 — 공통 규칙 한 줄이 skill 열 곳에 같은 커밋으로 들어가야 하고 리뷰 질문 규칙과 서로 물려 있습니다.

### 답
→ S36 (분해 판단): spec 하나로 (권장)

## 조사 원문

### 조사 1 — coverage-mapper · R1 · 묶음 1

계약(`<claims_contract>`)을 받았고 그 형식대로 낸다. `RC<n>` 은 임시 번호다. 레포 경로는 모두 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/` 기준 상대경로다.

```yaml
derived_dimensions:
  - name: "화면 통로 — 앞 글 · 도구 출력 · 질문 창 중 무엇이 실제로 보이나, 질문 창에 얼마나 실을 수 있나"
    rationale: "「위에 아무것도 없음」의 원인이 셋으로 갈리고 고칠 자리가 다르다 — 모델이 안 썼다 / 썼는데 질문 창이 가렸다 / 썼는데 화면과 세션 기록 양쪽에서 사라졌다(#75182). 셋째면 측정의 「앞 글 0자」가 모델의 누락인지 하니스의 소실인지 기록으로는 못 가르고, 「질문 앞 글에 쓰라」는 규칙으로는 고쳐지지 않는다. 리뷰 항목의 상세(그대로 두면 · 고치면)는 Bash 도구 출력에만 있다. 질문 창은 질문 1–4개 · 선택지 2–4개 · 머리글 12자 · 라벨과 설명 두 칸뿐이다. (RC2 · RC3 · RC5 · RC6 · 웹 1–6)"
  - name: "지금 증상을 처방하는 기존 규칙과 그 문면을 잠근 테스트"
    rationale: "사용자가 본 모양은 규칙 위반이 아니라 규칙대로다 — 질문 본문은 「결정 하나와 한 줄만」, 앞 글에는 렌더 첫 줄만, 라벨은 1–5 낱말, 설명 칸은 규정 없음, 경고는 「옵션 description 에 싣지 않습니다」. 이 문장들은 다섯 자리에서 글자째 잠겨 있고 쉬운 말 블록은 SKILL.md 10개에 같은 바이트로 복제된다. 지난 추천 표시 일의 진단도 「맞서는 지역 규칙이 이겼다」였다. (RC4 · RC5 · RC7 · RC8 · RC9)"
  - name: "이전 확정의 재결정(P23) — 「이유는 질문 위 글에」 · 「외부 skill 질문은 그 skill 몫」 · 「실행 중 훅 금지」"
    rationale: "2026-10-27 인터뷰에서 사용자가 확정한 D16 · D13 · C17 과 그 설계의 Anti-goals 가 이 일의 OQ3 · OQ4 · OQ5 선택지를 직접 막거나 뒤집힌다. 그때도 「앞 글이 사라질 수 있다」를 알고 표시만 라벨로 옮기고 이유는 위에 남겼다(「사라져도 표시는 남음」) — 이번 요청은 그때 받아들인 대가가 돌아온 것이다. 근거를 보이고 사용자 동의로 재결정할 항목이다. (RC10 · RC11 · RC12)"
  - name: "있는 것 — 이미 대가를 내는 자리와 꼴"
    rationale: "리뷰 엔진은 항목마다 「그대로 두면 / 고치면 / 근거 / 대안」을 이미 낸다(통로만 도구 출력이다). 인터뷰 라운드 규약은 「트레이드오프: 선택지별 한 줄」을 화면 출력 형식으로 이미 정했다. 지휘자 규칙은 「배경을 먼저 쓰고 질문만 봐도 결정할 수 있게」와 설명 칸 보존을 이미 정했고, 측정에서 지휘자 세션만 깨끗했다. 새 규칙을 만들기 전에 이 셋을 옮겨 쓰는 길을 봐야 한다. (RC6 · RC13 · RC14)"
  - name: "소유 경계 — 「방향을 정하는 자리」 셋 중 devbrew 가 글을 쓰는 표면"
    rationale: "범위의 예 셋 가운데 설계(brainstorming)와 계획(writing-plans)은 외부 skill 이 메시지 모양을 정한다. devbrew 가 닿는 길은 다음 세션 줄의 운반 문장과 지휘자의 옮긴 질문 둘뿐이고, 쉬운 말 블록은 그 대화에서 「낱말에만 적용」으로 잠겨 있다. devbrew 소유의 방향 자리는 framing · 인터뷰 · 세 문서 리뷰 · 지휘자 계획 검토다. upstream brainstorming 은 접근안마다 대가와 추천을 이미 요구한다. (RC15 · RC16 · RC17 · RC18 · 웹 7)"
  - name: "추천 유무 × 자리별 최소 내용 — 「무엇을 고르는지」까지인가 「대가」까지인가"
    rationale: "리뷰 뒤 질문에는 추천을 다는 자리(설계 · brief 리뷰 결정, D18)와 일부러 비우는 자리(저자 편집 덩어리 · 낮춘 지적)가 섞여 있다. 사용자는 「추천과 같이」를 골랐고 「선택지마다」는 고르지 않았는데, 인터뷰 규약은 이미 「선택지별 한 줄」이다. 추천 없는 리뷰 질문에서 목표가 요구하는 최소가 무엇인지 정해야 OQ1 · OQ4 가 닫힌다. (RC13 · RC19)"
  - name: "질문 밖 「권하는 글」의 자리 목록과 찾는 방법"
    rationale: "확정 범위에 「모델이 한쪽을 권하는 글」이 들었는데, 전수 목록은 `AskUserQuestion` 글자가 있는 줄에서만 후보를 뽑는다. 분해 판단의 「권고 한 줄」 · 게이트의 「제안 이유」 · 「지휘자 의견:」 같은 문장 권고는 목록에도 검사에도 없다. 검사까지 둘지(OQ3)는 이 자리를 무엇으로 찾느냐에 달렸다. (RC8 · RC20)"
  - name: "고쳐졌는지 재는 방법"
    rationale: "기준 측정이 세션 기록의 글자 수와 낱말 맞추기인데, 기록은 화면에 무엇이 보였는지를 담지 않고 #75182 에서는 앞 글이 기록에서도 빠진다. 코드 리뷰 0건도 낱말 차이의 산물이다. 문서의 문면 검사는 「그 문장이 문서에 있다」만 재고 실행 중 질문의 내용은 못 잰다. 수용 기준을 무엇으로 확인할지 따로 정해야 한다. (RC8 · RC21 · RC22 · 웹 1)"
neglect_flag: true
neglected_dimensions:
  - "화면 통로 — 앞 글 · 도구 출력 · 질문 창 중 무엇이 실제로 보이나, 질문 창에 얼마나 실을 수 있나"
  - "이전 확정의 재결정(P23) — 「이유는 질문 위 글에」 · 「외부 skill 질문은 그 skill 몫」 · 「실행 중 훅 금지」"
  - "고쳐졌는지 재는 방법"
confidence: 0.7
evidence:
  - url: "https://github.com/anthropics/claude-code/issues/75182"
    supports: alternative
    claim: "터미널 CLI 에서 같은 턴에 글을 쓰고 AskUserQuestion 을 부르면 그 글이 질문 전에도 답한 뒤에도 보이지 않는다. 2026-07-07 에 열렸고 지금도 열려 있으며 메인테이너가 2.1.233 에서 재현했다(Fable 5 — 글이 숨은 추론으로 처리된다). 댓글 보고로는 세션 기록(.jsonl)에도 전문이 없고, 2.1.325 · Opus 5.5 · Fable 5.1 에서도 난다. 앞에 다른 도구 호출이 없거나 글이 턴의 마지막이면 보인다. 메인테이너의 우회책은 「턴을 글로 끝내라」다. 이 주장은 「앞 글 0자」 측정이 모델 누락이 아니라 하니스 소실일 수 있음을 뜻한다."
    touches: []
    decides: [OQ3, OQ4, OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303 (plugins/spec-distill/dependencies.md 의 기록 판)", latest: "모름 — 이슈 댓글의 가장 늦은 보고 판은 2.1.325"}
    certainty: uncertain
  - url: "https://github.com/anthropics/claude-code/issues/67475"
    supports: both
    claim: "질문 창이 뜨면 같은 턴의 앞 글이 답하거나 닫을 때까지 가려지고 답한 뒤에야 보인다(2.1.173 · Windows, 2026-06-11). 수정 확인 없이 #65662 의 중복으로 닫혔다. 재현 사례는 앞 글에 선택지 설명을 쓰고 질문이 그것을 가리킨 꼴이다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/77242"
    supports: alternative
    claim: "질문 창이 머리글과 선택지만 그리고 질문 문장은 안 보인다(2026-07-13, 열림). 보고자가 찾은 원인은 밝은 터미널 배경 + 기본 어두운 테마에서 질문 문장만 흰 글자로 칠해지는 것이고(대비 1.04:1) `/theme` 를 Auto 나 Light 로 바꾸면 보인다. 긴 세션에서 간헐적으로 난다는 보고도 있다. 사용자가 고른 「질문 본문이 비었다」의 후보 설명이다."
    touches: []
    decides: [OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain
  - url: "https://github.com/anthropics/claude-code/issues/45384"
    supports: alternative
    claim: "선택지에 `preview` 칸이 있으면 `description` 이 그려지지 않고 라벨과 미리보기만 보인다(2026-04-08 macOS CLI 보고). 메인테이너 답 없이 비활성으로 닫혀 버그인지 의도인지 확정되지 않았다. 사용자가 고른 「설명 칸이 없었다」의 후보 설명이다 — 기록에는 설명이 있어도 화면에는 없을 수 있다."
    touches: []
    decides: [OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain
  - url: "https://github.com/anthropics/claude-code/issues/67113"
    supports: both
    claim: "긴 질문 문장 · 긴 선택지 설명이 줄바꿈 없이 창 가장자리에서 잘린다는 보고(2026-06-10)가 2026-06-16 에 완료로 닫혔다. 고친 판은 페이지에 없다. 질문 창 안에 내용을 더 실을 때의 길이 한계를 실제 화면에서 확인해야 한다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/agent-sdk/user-input"
    supports: both
    claim: "공식 문서의 질문 형식: 호출당 질문 1–4개, 질문당 선택지 2–4개, 머리글 12자 이하, 선택지는 `label` 과 `description`(TypeScript 에서 `previewFormat` 을 켰을 때만 `preview`). 추천 · 대가 · 배경을 위한 전용 칸은 없다 — 실을 자리는 질문 문장 · 라벨 · 설명 셋이다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/obra/superpowers/main/skills/brainstorming/SKILL.md"
    supports: alternative
    claim: "upstream brainstorming 은 접근안을 따로 된 메시지로 내고 「what each trades off and which you'd pick」 · 「Recommend one and say why, then ask which way they want to go」 를 이미 요구한다. 질문은 하나씩, 이유를 알기 전에는 예시 답 없는 열린 질문이다. 설계 단계의 대가 제시는 그 skill 이 이미 맡고 있고 선택지 질문 꼴이 기본이 아니다."
    touches: []
    decides: [OQ5]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://www.w3.org/WAI/WCAG2/supplemental/patterns/o7p03-supported-choice"
    supports: current
    claim: "W3C 인지 접근성 패턴 「Clearly State the Results and Disadvantages of Actions, Options, and Selections」 — 고르게 할 때 선택지마다 이득 · 위험 · 결과를 화면 안에, 선택지 옆에 밝히라. 대가를 고르는 자리에 같이 적으라는 요구의 바깥 근거다. 짧게 쓰는 법은 다루지 않는다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
repo_claims:
  - id: RC1
    path: "shared/style/plain-language.md"
    anchor: "설명에는 고르면 무엇이 달라지는지만 쓴다 … 이유는 질문 위 글에"
    line: 6
    claim: "«한 뿌리» 추론의 규칙 쪽 근거. 추천의 이유(정본 6행)와 리뷰 경고 · 상세(proceed-gate.md:44 「질문 본문에는 결정 하나와 … 한 줄만」)는 둘 다 「내용은 질문 위 글에, 질문 창에는 표시만」이라는 같은 꼴의 규칙이다. 두 증상이 같은 통로(질문 위 글)에 기대는 것까지는 레포로 확인된다. 그것이 사용자가 겪은 원인인지는 확인되지 않는다."
    touches: []
    decides: [OQ4]
  - id: RC2
    path: "docs/superpowers/interview/2026-10-27-askquestion-recommendation-interview.state.md"
    anchor: "claudeissues.com/issue/75182"
    line: 429
    claim: "«질문 창이 앞 글을 가릴 수 있다는 것은 설명서의 말뿐» 에 대한 정정. 레포의 지난 인터뷰가 #67475 · #75182 를 `gh issue view` 로 제목 · 상태까지 확인해 적어 두었다(같은 파일 485행, brief 216행 «gh-askuserquestion-hides-text»). 설명서 문장 말고도 버그 보고 근거가 레포에 있다. 이 사용자의 화면에서 잰 것은 여전히 없다."
    touches: []
    decides: [OQ4, OQ6]
  - id: RC3
    path: "plugins/spec-distill/dependencies.md"
    anchor: "| claude-code | 2.1.303 | 2026-10-22 | 기록 |"
    line: 19
    claim: "레포가 기록한 Claude Code 판은 2.1.303 이다. #75182 의 재현 판(2.1.233)과 댓글 보고 판(2.1.302–2.1.325) 사이에 든다."
    touches: []
    decides: [OQ6]
  - id: RC4
    path: "plugins/spec-distill/references/proceed-gate.md"
    anchor: "질문 본문에는 결정 하나와 「경고 N개 — 위에 적었다」"
    line: 44
    claim: "게이트 정본이 질문 본문을 「결정 하나와 한 줄만」으로 제한하고 내용은 게이트 앞 글에 두라고 한다. 같은 문장이 request-framing(784 · 1094행) · spec-review(555 · 827행) · reviewing-brief(604 · 739행) · finishing.md(499행)에 있다. 「위에 적었다」 꼴은 규칙이 처방한 문구다."
    touches: []
    decides: [OQ4, OQ1]
  - id: RC5
    path: "shared/docreview/references/reviewing-document.md"
    anchor: "렌더 첫 줄(상태와 경고)은 첫 호출 **앞 글**에 한 번 쓴다"
    line: 30
    claim: "리뷰 절차서 8단계가 앞 글에 쓰라고 하는 것은 렌더의 첫 줄뿐이다. 선택지 라벨은 「상태별 라벨 + 대체안 1–5 낱말」이고 「렌더의 「고치면」 줄이 전문을 이미 내므로 라벨은 그 줄을 가리키는 손잡이」라고 한다(42행). 이 파일에 `description` 이라는 낱말은 없다 — 설명 칸에 무엇을 쓸지 정한 문장이 없다. 항목 상세를 사용자 글로 옮기라는 문장도 없다."
    touches: []
    decides: [OQ4, OQ3]
  - id: RC6
    path: "shared/docreview/scripts/docreview_state.py"
    anchor: "_rg_decide"
    line: 2311
    claim: "게이트 렌더가 결정 항목마다 「그대로 두면: <if_unfixed>」 · 「고치면: <replacement>」 · 「근거」 · 「자리」 · 「대안」 줄을 낸다. 리뷰 결정 질문의 대가에 해당하는 내용은 엔진이 이미 만든다. 나가는 곳은 `gate --render` 의 표준 출력, 곧 Bash 도구 결과다."
    touches: []
    decides: [OQ4]
  - id: RC7
    path: "plugins/spec-distill/skills/pm-interview/references/finishing.md"
    anchor: "옵션 description 에 싣지 않습니다"
    line: 497
    claim: "인터뷰 끝 게이트는 경고를 선택지 설명에 싣는 것을 명시로 금한다 — 「모든 degrade record 는 게이트 앞 글에 한 줄씩 씁니다 — 옵션 description 에 싣지 않습니다」. 분해 판단 질문의 문구도 「신호 셋과 권고를 위에 적었다. 이 일을 어떻게 진행할까?」로 고정돼 있다(38행)."
    touches: []
    decides: [OQ4]
  - id: RC8
    path: "shared/tests/test_ask_recommendation.sh"
    anchor: "모델이 즉석에서 만드는 질문은 정본 규칙만이 집행한다"
    line: 9
    claim: "질문 자리 전수 검사는 문서에 `AskUserQuestion` 글자가 있는 줄만 후보로 뽑고, 판정 모듈(`shared/tests/ask_recommendation.py` 의 `required`)은 종류별 리터럴(라벨 꼬리 · 지시 문장 · 「추천을 달지 않는다 —」 · 뗌 문장)이 범위에 있는지만 본다. 질문 본문 · 설명 칸의 내용은 재지 않는다. 즉석 질문과 도구 이름 없는 문장 질문은 스스로 밝힌 한계 밖이다. 지금 장치를 넓혀도 잴 수 있는 것은 「그 자리에 지시 문장이 있다」까지다."
    touches: []
    decides: [OQ3]
  - id: RC9
    path: "plugins/spec-distill/tests/test_plain_gate_templates.sh"
    anchor: "질문 본문: 정본"
    line: 141
    claim: "「질문 본문에는 결정 하나와 … 한 줄만」 문장이 다섯 자리(spec-review · reviewing-brief · request-framing · proceed-gate · finishing)에서 글자째 1회로 잠겨 있다(138–142행). 쉬운 말 블록은 SKILL.md 10개에 같은 바이트로 복제되고 `shared/tests/test_plain_language_block.sh` 가 추천 문장을 글자째 잠근다(30–32행). 질문 본문 규칙이나 블록 문장을 바꾸면 이 락들이 함께 바뀐다."
    touches: []
    decides: [OQ3]
  - id: RC10
    path: "docs/superpowers/interview/2026-10-27-askquestion-recommendation-interview.md"
    anchor: "**D16** — 「(권장)」 표시는 라벨에, 추천의 이유는 지금처럼 질문 위 글에 둔다"
    line: 175
    claim: "「이유는 질문 위 글에」는 사용자가 확정한 결정이다(D16, 근거 발화 S29). 같은 brief 는 설명 칸 제한을 「바꾸지 않아도 된다고 본다 — 사용자가 따로 정한 것은 아니다」로 적었다(181행). 그 인터뷰의 원인 판정은 「보였는데 놓침」이었다(OQ7, 195행) — 이번 「위에 아무것도 없음」과 다른 진단이다. 대가나 이유를 질문 창 안으로 옮기면 D16 의 재결정이다."
    touches: []
    decides: [OQ4]
  - id: RC11
    path: "docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md"
    anchor: "## Anti-goals"
    line: 49
    claim: "추천 표시 설계의 Anti-goals: 실행 중 질문 도구 호출에 끼어드는 훅 · 래퍼, SKILL.md 복제 블록을 눈에 띄게 늘리는 것, 리뷰 엔진의 라벨 코드를 바꾸는 것. 사용자 경계는 「너무 강제하게 만드는 장치는 만들지 마」(C17)이고 막는 검사는 레포 테스트에만 둔다. 이번 OQ3 의 「검사까지」는 이 경계 안에서 정하거나 재결정해야 한다."
    touches: []
    decides: [OQ3]
  - id: RC12
    path: "docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md"
    anchor: "«gh-askuserquestion-hides-text» | 반영 | §1 — 표시는 라벨에(질문 위 글은 이유만, 사라져도 표시는 남음)"
    line: 289
    claim: "지난 설계는 앞 글이 사라질 수 있음을 알고 추천 표시만 라벨로 옮기고, 이유는 사라져도 되는 것으로 보고 위에 남겼다. 이번에 사용자가 말한 「추천의 대가를 몰랐다」는 그때 받아들인 손실과 같은 자리다."
    touches: []
    decides: [OQ4]
  - id: RC13
    path: "plugins/spec-distill/skills/pm-interview/SKILL.md"
    anchor: "OQ<n>: <무엇을 정하는지 한 줄> · 추천: <첫 선택지 | 없음 — <이유>> · 트레이드오프: <선택지별 한 줄>"
    line: 190
    claim: "인터뷰 라운드 규약의 «다음 결정» 줄은 상태 파일 전용이 아니다 — 180행이 「사용자에게 보이는 출력과 state 본문 기록이 같은 형식이다」라고 한다(화면에서 빼는 것은 «추천: 없음 — 이유» 뿐). 인터뷰는 이미 선택지별 대가 한 줄을 질문 앞 글에 내게 돼 있고, 그 범위는 사용자가 고르지 않은 「선택지마다」다. 204–205행은 설명 칸에 «고르면 무엇이 달라지는가»를 담으라고 하고 「기계 검사는 없다」고 적는다. seed audit 의 「상태 파일에 적는 줄」 읽기와 어긋난다."
    touches: []
    decides: [OQ4, OQ3]
  - id: RC14
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "지휘자는 배경을 먼저 쉬운 말로 쓰고 질문만 봐도 결정할 수 있게 묻는다"
    line: 32
    claim: "지휘자의 옮긴 질문 규칙에 이번 목표와 같은 문장이 이미 있다 — 「질문만 봐도 결정할 수 있게」, 「각 선택지 설명에 원문의 「고르면 무엇이 달라지나」 를 빠뜨리지 않는다」. 하위가 돌려보내는 쉬운 요약의 꼴도 「무엇을 정하나 · 고르면 무엇이 달라지나(그대로 두면 · 고치면) · 배경」이다(29행). 다만 배경은 여전히 질문 앞 글에 쓴다."
    touches: []
    decides: [OQ4, OQ1]
  - id: RC15
    path: "shared/style/plain-language.md"
    anchor: "부른 skill 이 메시지 모양을 정한 대화(예: brainstorming)에서는 그 skill 을 따르고, 이 블록은 낱말에만 적용한다"
    line: 3
    claim: "쉬운 말 블록은 brainstorming 대화에서 메시지 모양을 그 skill 에 맡기고 낱말에만 적용한다. 이 예외 문장은 `shared/tests/test_plain_language_block.sh` 28행이 잠근다. 정본 블록에 대가 규칙을 넣어도 지금 문면으로는 brainstorming 의 질문 모양에 닿지 않는다."
    touches: []
    decides: [OQ5]
  - id: RC16
    path: "docs/superpowers/interview/2026-10-27-askquestion-recommendation-interview.md"
    anchor: "**D13** — 외부 skill(brainstorming 등)의 질문은 그 skill 몫이다"
    line: 172
    claim: "사용자가 추천 표시 일에서 외부 skill 의 질문을 범위 밖으로 확정했다(D13). 지휘자가 옮겨 띄우는 질문만 원문이 외부 skill 이어도 범위 안이다(D14, 173행). OQ5 를 「닿게 한다」로 정하면 이 확정과 다른 선을 긋는 것이다."
    touches: []
    decides: [OQ5]
  - id: RC17
    path: "plugins/spec-distill/skills/pm-interview/references/finishing.md"
    anchor: "**다음 세션 줄 — ①/② 공통**"
    line: 551
    claim: "devbrew 가 brainstorming 세션에 지시를 싣는 통로가 이미 있다 — 인터뷰 끝의 다음 세션 줄(553행) 운반 문장이다. 그 끝 문장이 「사람에게 쓰는 글의 낱말 규칙…을 지키고, 메시지 모양(첫 메시지 · 질문 하나 · 되비춤)은 brainstorming 을 따른다」다. 닿게 하려면 고칠 자리는 이 한 줄이고(사람이 붙여 넣는 긴 줄이 더 길어진다), 같은 줄이 `superpowers:writing-plans` 도 부른다 — 계획 단계도 외부 skill 이다."
    touches: []
    decides: [OQ5]
  - id: RC18
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "brief · 설계 · 계획처럼 방향을 정하는 단계면 특히 그렇다"
    line: 28
    claim: "레포에서 「방향을 정하는 단계」라는 말을 쓰는 곳은 여기 하나이고 예는 brief · 설계 · 계획이다 — request-framing 은 들지 않았다. 반면 request-framing 은 인터뷰 · 설계 리뷰와 같은 게이트 계약의 셋째 채택자이고(proceed-gate.md 3–5행) 같은 리뷰 엔진 8단계를 쓴다(request-framing/SKILL.md 781행). 낱말의 기존 쓰임은 framing 을 빼고, 장치의 공유는 framing 을 넣는다."
    touches: []
    decides: [OQ2]
  - id: RC19
    path: "shared/tests/fixtures/ask-sites.tsv"
    anchor: "# 게이트 · 리뷰 결정 질문 (Task 4)"
    line: 39
    claim: "리뷰 뒤 질문 자리는 추천 유무가 섞여 있다. 문서 리뷰의 결정 질문은 `지시`(권하는 쪽이 있으면 단다)이고, request-framing 의 저자 편집 덩어리 질문과 quality-pipeline 의 낮춘 지적 게이트는 `비움`(일부러 추천 없음)이다. 「추천과 같이 대가를 적는다」만으로는 `비움` 자리에서 무엇을 실을지가 정해지지 않는다."
    touches: []
    decides: [OQ1, OQ4]
  - id: RC20
    path: "plugins/spec-distill/skills/pm-interview/references/finishing.md"
    anchor: "이어서 권고 한 줄 — 「하나로 충분해 보인다 — <이유>」"
    line: 33
    claim: "질문 밖 권하는 글의 실례. 분해 판단은 질문 앞에 문장으로 권고를 내고 질문은 그것을 「위에 적었다」로 가리킨다. 같은 꼴이 게이트 둘째 질문의 「제안 이유는 게이트 앞 글에」(proceed-gate.md:56)와 「지휘자 의견:」 줄(conductor-dispatch.md:32)에 있다. 이런 문장 권고 자리를 모은 목록은 레포에 없다."
    touches: []
    decides: [OQ3]
  - id: RC21
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "재비판이 심각도를 낮춘 지적이 <n>개 있다(위 「낮춘 지적」 절)"
    line: 713
    claim: "«코드 리뷰에는 「위」를 가리키는 질문이 없다» 는 낱말 맞추기의 산물이다. 낮춘 지적 게이트는 「위 「낮춘 지적」 절」로, 분류 질문은 「분류표의 적용/제외를 바꿀까요?」(861행)로 앞 글을 가리키는데 둘 다 측정 낱말(위에 적었다 · 위에 적은 · 위 글 · 위를 보 · 위 표 · 위의)에 걸리지 않는다. 코드 리뷰 질문도 화면만 보고는 고를 수 없는 꼴이 있다. 다만 반복 질문은 지적 개수 줄(`<summary>`)을 질문 문장 안에 싣는다(851행)."
    touches: []
    decides: [OQ1]
  - id: RC22
    path: "plugins/spec-distill/skills/request-framing/SKILL.md"
    anchor: "### 게이트 — 처분은 사용자가, 편집은 처분 뒤에"
    line: 779
    claim: "«측정은 거칠다» 의 레포 쪽 확인. seed 리뷰는 request-framing SKILL 안에 인라인이고(별도 skill 아님), brief 리뷰 `reviewing-brief` 는 pm-interview 가 부르는 내부 skill 이다(`user-invocable: false`, reviewing-brief/SKILL.md 11행). 마지막으로 부른 skill 로는 framing 라운드 질문과 seed 리뷰 결정 질문이 갈리지 않는다. request-framing SKILL 에서 「위에 적었다」가 처방된 곳은 리뷰 게이트(784행)와 확정 게이트(1094행)뿐이다 — 그 묶음의 「위」 질문은 리뷰 · 확정 게이트에서 왔을 공산이 크다(추정)."
    touches: []
    decides: [OQ1, OQ2]
  - id: RC23
    path: "plugins/spec-distill/skills/request-framing/SKILL.md"
    anchor: "{label: \"만들고 시작 (권장)\", description:"
    line: 190
    claim: "devbrew 의 질문 틀은 `label` 과 `description` 만 쓴다. `plugins/**/*.md` 를 대소문자 무시로 훑어 `preview` 를 질문 칸으로 쓰라는 지시는 찾지 못했다(걸린 넷은 무관한 문맥). #45384(preview 가 있으면 설명이 안 보임)가 사용자 화면의 원인이려면 모델이 실행 중 스스로 `preview` 를 붙였어야 한다 — 세션 기록에서 `preview` 칸 유무를 다시 재면 가를 수 있다."
    touches: []
    decides: [OQ6]
```

덧붙임 넷.

- **확실성.** GitHub 이슈 다섯은 페이지를 요약해 읽었다. 제목 · 상태 · 날짜는 확인했고, 댓글 속 세부(기록에서도 사라짐 · 재현 모델 · 테마 원인)는 `uncertain` 으로 뒀다 — 결정에 쓰기 전에 본체가 1차로 한 번 더 확인해야 한다. `claudeissues.com` 사본은 열리지 않아 `github.com` 원본으로 읽었다.
- **가장 무거운 발견.** #75182 가 맞다면 「위를 가리키는데 앞 글이 0자」라는 기준 측정이 모델이 안 쓴 것인지 하니스가 지운 것인지 기록으로는 가를 수 없다. 이 세션의 모델(Fable 5.2)도 보고된 계열이다. `neglect_flag` 를 켠 이유다 — seed 와 열린 결정 여섯은 「어떤 규칙을 어느 칸에」에 모여 있고 통로 자체가 믿을 만한지는 OQ6 의 일부로만 걸쳐 있다.
- **seed audit 과 어긋난 곳 하나.** audit `## 3` 라 는 인터뷰 skill 의 트레이드오프 줄을 「상태 파일에 적는 줄」로 읽었는데, SKILL.md 180행은 화면 출력과 같은 형식이라고 한다(RC13).
- **확인하지 못한 것.** 사용자의 실제 화면 · 터미널 테마 · 지금 깔린 Claude Code 판, 세션 기록에 `preview` 칸이 있었는지, 827개 측정의 재현(스크립트가 남지 않았다).

Sources:
- [#75182 Assistant text preceding an AskUserQuestion call is never displayed](https://github.com/anthropics/claude-code/issues/75182)
- [#67475 AskUserQuestion dialog hides preceding assistant message text](https://github.com/anthropics/claude-code/issues/67475)
- [#77242 AskUserQuestion dialog renders options but not the question text](https://github.com/anthropics/claude-code/issues/77242)
- [#45384 option description not shown when preview is present](https://github.com/anthropics/claude-code/issues/45384)
- [#67113 long question/option text is cut off](https://github.com/anthropics/claude-code/issues/67113)
- [Agent SDK — Handle approvals and user input](https://code.claude.com/docs/en/agent-sdk/user-input)
- [superpowers brainstorming SKILL.md](https://raw.githubusercontent.com/obra/superpowers/main/skills/brainstorming/SKILL.md)
- [W3C — Clearly State the Results and Disadvantages of Actions, Options, and Selections](https://www.w3.org/WAI/WCAG2/supplemental/patterns/o7p03-supported-choice)

### 조사 2 — repo-researcher · R1 · 묶음 1

조사 범위: 작업 디렉토리 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs` 의 `plugins/` · `shared/`. 아래 주장은 모두 해당 파일의 구현(본문 · 스크립트)을 읽고 적었다. 줄번호는 보조다. 경로는 레포 상대경로이고, 절대경로 목록은 끝에 있다.

```yaml
repo_claims:
  # ── (2) 공통 규칙: 선택지 설명 · 추천 · 대가를 적는 자리 ─────────────────
  - id: RC1
    path: "shared/style/plain-language.md"
    anchor: "질문 하나에 결정 하나. 선택지 이름은 짧은 쉬운 말로, 설명에는 고르면 무엇이 달라지는지만 쓴다."
    line: 6
    claim: >-
      공통 규칙 블록의 질문 줄 전문은 「질문 하나에 결정 하나. 선택지 이름은 짧은 쉬운 말로, 설명에는 고르면 무엇이 달라지는지만 쓴다.
      본문에 없던 주제를 선택지에서 꺼내지 않는다. 추천이 있으면 그 선택지를 첫 자리에 두고 라벨 끝에 「(권장)」을 단다 — 여럿이면 모두,
      이유는 질문 위 글에. 추천이 없으면 아무 표시도 쓰지 않는다.」 이다. 곧 설명 칸은 「고르면 무엇이 달라지는지만」, 추천 표시는 라벨 끝,
      추천 이유는 「질문 위 글」(질문 밖)로 정한다. 「대가」 · 「트레이드오프」 라는 낱말은 이 블록에 없다.
    touches: []
    decides: [OQ4, OQ1]
  - id: RC2
    path: "shared/style/plain-language.md"
    anchor: "아래 절차가 출력 형식·원문 보존·분량을 따로 정한 자리에서는 그 절차를 따른다."
    line: 3
    claim: >-
      블록 첫 줄이 적용 범위와 예외를 정한다 — 「이 절은 사용자에게 보이는 글(답변·보고·질문·선택지·경고·PR 본문·커밋)에만 적용한다. …
      아래 절차가 출력 형식·원문 보존·분량을 따로 정한 자리에서는 그 절차를 따른다. 추천 표시는 그 자리에서도 이 블록을 따른다 —
      옮긴 질문과 steelman 질문의 선택지 순서, steelman 질문의 출처 표지만 예외다. 부른 skill 이 메시지 모양을 정한 대화(예: brainstorming)에서는
      그 skill 을 따르고, 이 블록은 낱말에만 적용한다.」 곧 brainstorming 이 띄우는 대화의 메시지 모양은 이 블록의 적용 밖(낱말만 적용)이라고 이미 적혀 있다.
    touches: []
    decides: [OQ5, OQ1]
  - id: RC3
    path: "shared/tests/plain_language_block.py"
    anchor: "def check(root, rel, canon)"
    line: 31
    claim: >-
      이 블록은 `plugins/*/skills/*/SKILL.md` 전부(와 `plugins/*/commands/*.md`)에 사본으로 들어가고, 판정기는 대상마다 넷만 잰다 — 표시 줄
      (`<!-- plain-language:begin/end -->`)이 한 쌍 · 블록이 H1 바로 다음 · 시작이 끝보다 앞 · 표시 줄 사이 바이트가 정본과 같다
      (「블록 바이트가 정본(%s)과 다르다」). `shared/tests/test_plain_language_block.sh` 는 여기에 정본 안 문장의 실재(추천 문장 `REC` · 예외 문장 `EXC` ·
      brainstorming 예외 문장)를 더 잰다. 재는 것은 «규칙 글자의 실재와 사본 동일성»이고, 실제 질문이 그 규칙을 지켰는지는 재지 않는다.
      읽은 사본: spec-review(L19–31) · pm-interview(L24) · reviewing-brief(L21) · request-framing(L20) · quality-pipeline(L52) · artifact-critique(L51) — 질문 줄이 같은 글자다.
    touches: []
    decides: [OQ3]
  - id: RC4
    path: "plugins/spec-distill/skills/pm-interview/SKILL.md"
    anchor: "OQ<n>: <무엇을 정하는지 한 줄> · 추천: <첫 선택지 | 없음 — <이유>> · 트레이드오프: <선택지별 한 줄>"
    line: 190
    claim: >-
      plugins/ · shared/ 의 모델이 읽는 문서에서 「트레이드오프」를 사용자 질문과 묶어 적는 자리는 인터뷰 라운드 규약의 «다음 결정» 줄 하나다
      (grep 으로 확인 — 그 밖의 일치는 리뷰어 축 이름 `tradeoffs` · CHANGELOG · README 다). 이 줄은 질문 도구의 칸이 아니라 라운드 출력의
      `### 다음 결정` 절(질문 앞 글이자 state 본문 기록 — 「사용자에게 보이는 출력과 state 본문 기록이 같은 형식이다」 L180)에 선다.
      같은 절이 칸을 가른다 — 「question 본문은 무엇을 정하는지·용어·기술 사실을 풀고, 각 선택지의 `description` 은 «고르면 무엇이 달라지는가»를 담는다.
      기계 검사는 없다.」(L204–205). 이 규약은 인터뷰 라운드 질문의 것이고 리뷰 뒤 게이트 질문 자리에는 같은 «추천 · 트레이드오프» 줄이 없다.
    touches: []
    decides: [OQ4, OQ1, OQ3]

  # ── (1) 리뷰 뒤 결정 질문 — 공유 엔진 절차서와 그 사본 ────────────────────
  - id: RC5
    path: "shared/docreview/references/reviewing-document.md"
    anchor: "8. **게이트** — `docreview_state.py gate --state-dir D --render`."
    line: 27
    claim: >-
      문서 리뷰 라운드 게이트 · 승인 게이트 1단계의 질문 모양을 정하는 정본. 질문 앞 글: 「렌더 첫 줄(상태와 경고)은 첫 호출 **앞 글**에 한 번 쓴다.」
      질문 본문: 「질문 본문에는 그 질문의 결정 하나와, 경고가 있으면 「경고 N개 — 위에 적었다」 한 줄만 둔다.」 — 질문 밖의 글을 가리키는 「위에 적었다」가
      본문 규칙에 들어 있다. 추천: 「권하는 쪽이 있으면 첫 자리로 옮기고 라벨 끝에 「(권장)」을 단다.」(결정 묶음 · 열린 것 0 · 열린 것 있음 세 자리).
      묶음: 「**`AskUserQuestion` 최대 4개씩 연속 호출**」 · 「한 호출에 묶는 질문은 서로의 답에 기대지 않는 결정이다」.
      이 절은 선택지 설명(description)에 무엇을 실을지 따로 정하지 않는다(파일 전문을 읽었다 — 설명 칸은 공통 블록 RC1 에 맡겨져 있다).
      추천 «이유»나 선택지별 대가를 어디에 적을지도 이 절에는 없다.
    touches: []
    decides: [OQ1, OQ4]
  - id: RC6
    path: "shared/docreview/references/reviewing-document.md"
    anchor: "**`AskUserQuestion` 라벨의 항목별 내용**"
    line: 42
    claim: >-
      라벨 규칙: 「각 선택지 `label` 은 **상태별 라벨 + `— <replacement 를 1–5 낱말로 압축>`** 이다」 · 「같은 라운드의 두 항목이 **같은 라벨을 갖지 않는다.**」 ·
      「렌더의 「고치면」 줄이 전문을 이미 내므로 라벨은 그 줄을 가리키는 손잡이다」 · 「질문 · 선택지 이름에 AC 번호 · 지적 id · § 를 쓰지 않고 설명 괄호에만 쓴다 —
      선택지 이름만 보고 무엇을 고르는지 알 수 있어야 한다.」 곧 결정의 전문(그대로 두면 · 고치면)은 질문 칸이 아니라 엔진 렌더 글에 있고 라벨이 그것을 가리킨다고 적는다.
      같은 파일 `## 배달` 은 「고친다(채택)는 고를 수 없다」 줄에 대해 「질문 앞 글에 그 줄을 그대로 옮긴다」(L86)고 정한다.
    touches: []
    decides: [OQ4]
  - id: RC7
    path: "shared/docreview/scripts/docreview_state.py"
    anchor: "def _rg_decide(st, g, fid)"
    line: 2295
    claim: >-
      엔진 렌더가 결정 항목마다 내는 줄은 요약 한 줄 + 「  그대로 두면: …」 · 「  고치면: …」 · 「  근거: …」 · 「  자리: …」 · 「  대안: 고친다(채택) / 그대로 둔다(기각) / 나중에 정한다(보류)」다
      (선택지 라벨 리터럴은 `_CHOICE_LABEL` L2137). 곧 선택지별 결과에 해당하는 글(그대로 두면 / 고치면)은 엔진이 «렌더 글»로 만들어 내고,
      이 글을 질문 본문 · 선택지 설명 · 앞 글 중 어느 칸에 싣는지를 정하는 문장은 RC5 의 절차서에 없다(첫 줄만 앞 글로 지정). 렌더에 추천 줄은 없다.
    touches: []
    decides: [OQ4, OQ6]
  - id: RC8
    path: "plugins/spec-distill/skills/spec-review/SKILL.md"
    anchor: "## 게이트"
    line: 543
    claim: >-
      설계문서 리뷰 자리. RC5 와 같은 글자의 라운드 게이트 규칙(L552–563: 앞 글에 렌더 첫 줄 한 번 · 본문에 결정 하나와 「경고 N개 — 위에 적었다」 한 줄 · 추천 지시)과
      RC6 과 같은 라벨 규칙(L574)을 갖는다. 승인 게이트 2단계는 옵션 넷의 표(L688–695 — 「| ① | 미커밋 확인 → `/compact` 후 다음 세션 줄 (권장) …」)이고 선택지 설명 문면은 정하지 않는다.
      `## degrade 채널`: 「게이트를 띄우기 **직전에** 이 셋을 읽어 하나도 빠뜨리지 않고 게이트 앞 글에 쓰고, 승인 게이트 질문에는 「경고 N개 — 위에 적었다」(또는 「경고 없음」·「이상 없음」) 한 줄만 둔다.」(L826–827).
      2단계 질문 앞 글에 싣는 것도 정한다 — 번호 대조 줄(L661) · 기각한 번호 목록(L663 「2단계 질문 앞 글에 … 펜스 출력 그대로 싣는다」) · 로드맵 속 위치(L673 「게이트 앞 글의 맨 끝(질문 바로 앞)」).
    touches: []
    decides: [OQ1, OQ4]
  - id: RC9
    path: "plugins/spec-distill/skills/spec-review/SKILL.md"
    anchor: "**③ 의 갈래와 로드맵 에픽.**"
    line: 697
    claim: >-
      ③(수정 필요) 뒤 후속 질문 — 「지적대로 고치기」 · 「인터뷰 다시 열기」 · 「직접 편집」(로드맵 에픽이면 「이 에픽 다시 설계」 추가). 라벨만 정하고 설명 문면은 없다.
      추천 이유의 자리를 이 자리에서 다시 적는다 — 「두 갈래 중 이번 지적에 맞는 쪽 라벨에 「(권장)」을 달고 이유는 질문 위 글에 한 줄로 쓴다 — 고르는 것은 사용자다.」(L702).
      같은 파일의 그 밖 질문: 표지 충돌 「그만둠 (권장)」/「이어 씀 — 표지를 내 것으로 바꾼다」(L301) · 「참고 전부 보기 (권장)」 · 「접은 채로 둔다」(L635) ·
      지휘 세션 아래 승인 질문 「승인 — 계획 담당자에게 (권장)」 · 「수정 필요」 · 「멈춤」(L766) — 셋 다 라벨만 있고 설명 · 본문 문면은 없다.
    touches: []
    decides: [OQ1, OQ4, OQ6]
  - id: RC10
    path: "plugins/spec-distill/skills/reviewing-brief/SKILL.md"
    anchor: "## 게이트"
    line: 598
    claim: >-
      brief 리뷰 자리. 라운드 게이트 규칙이 RC5 와 같은 글자다(L601–612). degrade 절: 「Step B 게이트를 띄우기 **직전에** 이 채널들을 읽어 하나도 빠뜨리지 않고
      게이트 앞 글에 쓴다(질문 본문에는 「경고 N개 — 위에 적었다」(또는 「경고 없음」·「이상 없음」) 한 줄).」(L738–739). 승인 게이트 2단계(진행 옵션)는 이 skill 이 띄우지 않고
      호출자 finishing.md Step B 가 묻는다(RC11). 표지 충돌 질문 「그만둠 (권장)」/「이어 씀 …」(L177)은 라벨만이다. 선택지 설명에 대한 자기 규칙은 없다.
    touches: []
    decides: [OQ1, OQ4]
  - id: RC11
    path: "plugins/spec-distill/skills/pm-interview/references/finishing.md"
    anchor: "#### B-2 — 단일 `AskUserQuestion` proceed 게이트 (4옵션, AC2)"
    line: 461
    claim: >-
      brief 리뷰 뒤 다음 단계 게이트. 본문 · 설명 · 앞 글을 모두 리터럴로 정한 자리다. 본문(L513): 「interview brief 를 만들었다: <brief-path> (구조 검사 통과 · 리뷰 <게이트 결과 한 줄 …>).
      경고 <N>개 — 위에 적었다 | 경고 없음 | 이상 없음. 다음 단계는?」 — 「위에 적었다」가 본문 리터럴에 있다. 라벨 · 설명(L516–519): 「확정하고 /compact 후 brainstorming (권장)」 —
      「확정 후보를 확정으로 바꿔 저장하고, 붙여 넣을 두 줄(/compact 와 다음 세션 줄)을 보여 준다. …」 등 넷 모두 «고르면 일어나는 일»을 적는다.
      앞 글(L473–485): 리뷰 게이트 결과 · readback 요약 · 열린 채 남은 항목 · 경고를 「프로즈로 출력」. 칸 사이 가름을 명문화한다 —
      「모든 degrade record 는 **게이트 앞 글**(위 목록 4)에 한 줄씩 씁니다 — 옵션 description 에 싣지 않습니다. 사용자가 옵션을 고르기 *전에* 읽도록 질문 바로 앞에 둡니다.
      질문 본문에는 결정 하나와 그 개수 한 줄(「경고 N개 — 위에 적었다」 또는 「경고 없음」·「이상 없음」)만 둡니다.」(L497–499).
      둘째 질문의 추천 이유도 앞 글이다 — 「제안 이유는 게이트 앞 글(위 목록 끝)에 한 줄로 쓴다」(L536).
    touches: []
    decides: [OQ1, OQ4]
  - id: RC12
    path: "plugins/spec-distill/skills/pm-interview/references/finishing.md"
    anchor: "question: \"신호 셋과 권고를 위에 적었다. 이 일을 어떻게 진행할까?\""
    line: 38
    claim: >-
      같은 파일의 그 밖 결정 질문. (a) 분해 판단(L34–48): 본문이 「신호 셋과 권고를 위에 적었다. 이 일을 어떻게 진행할까?」로 질문 밖 글을 가리키고, 권고는 질문 앞 프로즈 한 줄
      (「이어서 권고 한 줄 — 「하나로 충분해 보인다 — <이유>」 또는 「나누는 게 좋아 보인다 — <이유>」」 L33)이며, 설명은 «고르면 일어나는 일»
      (「지금처럼 brief 하나를 brainstorming 하나로 넘긴다. 로드맵을 만들지 않는다.」). (b) 고치기 · 승인(L64) · 되묻기 갈래(L266) · 「참고 전부 보기 (권장)」(L402)는 라벨과 추천 지시만 있고 설명 문면이 없다.
      (c) 재제시 상한(L329–338)은 본문 「확정 목록을 두 번 고쳤습니다. 어떻게 할까요?」와 설명 셋을 리터럴로 정한다. (d) B-0(L298–299): 「게이트를 띄우기 *전에* 확정 후보 목록을 **프로즈로** 출력합니다(목록이 길 수 있으므로 `AskUserQuestion`은 선택지만 담당)」.
    touches: []
    decides: [OQ1, OQ4, OQ6]
  - id: RC13
    path: "plugins/spec-distill/references/proceed-gate.md"
    anchor: "## Step B — 단일 `AskUserQuestion`"
    line: 28
    claim: >-
      pm-interview 종료 · spec-review · request-framing 세 게이트의 공통 계약. 앞 글: 「게이트를 띄우기 **전에** 판정 결과와, 이번 라운드에 실제로 일어난 **degrade 를 하나도 빠뜨리지 않고**
      게이트 앞 글에 쉬운 말로 쓴다(원문 사유 토큰은 괄호에).」 본문: 「질문 본문에는 결정 하나와 「경고 N개 — 위에 적었다」 (또는 「경고 없음」·「이상 없음」) 한 줄만 둔다. … 머리글은 「다음 단계」다.」
      옵션은 넷 · 순서 고정 · 「① 의 라벨 끝에 `(권장)` 을 단다」. 둘째 질문(L56): 「제안 이유는 게이트 앞 글에 쓰고, 같은 질문 호출에 둘째 질문을 더한다 — … 선택지는 모델의 제안 `(권장)` 이 첫 자리」 ·
      「둘째 질문이 뜰 때는 ①/② 의 이름과 설명은 특정 단계를 가리키지 않는다」. 선택지 설명의 내용 규칙은 이 문장 말고는 없다. 추천의 대가를 적는 자리도 없다.
    touches: []
    decides: [OQ1, OQ4]
  - id: RC14
    path: "plugins/spec-distill/skills/request-framing/SKILL.md"
    anchor: "### 게이트 — 처분은 사용자가, 편집은 처분 뒤에"
    line: 779
    claim: >-
      request-framing 도 seed 리뷰 뒤에 같은 엔진 게이트를 띄운다 — 「그 묶음은 **`AskUserQuestion` 최대 4개씩 연속 호출**로 나눠 띄웁니다. 결정 질문마다 권하는 쪽이 있으면 첫 자리로 옮기고 라벨 끝에 「(권장)」을 단다」 ·
      「렌더 첫 줄(상태와 경고)은 첫 호출 **앞 글**에 한 번 쓴다. 질문 본문에는 그 질문의 결정 하나와, 경고가 있으면 「경고 N개 — 위에 적었다」 한 줄만 둔다.」(L782–784). 이 자리 고유 규칙:
      `fix` 질문 「적용 / 적용하지 않음」(L800, 추천 지시 있음) · 저자 편집 덩어리 질문 「그대로 둔다 / 되돌린다」는 「추천을 달지 않는다」이고 「덩어리 본문(`render`)은 질문 텍스트에 줄임 없이 싣는다 … 이 덩어리 본문은 규칙 블록의 「따로 정한 자리」다 —
      「질문 본문엔 결정과 상태 한 줄만」의 예외로, 결정의 대상 자체라 질문에 그대로 싣는다.」(L933–935). 확정 게이트(L1094): 「질문 본문에는 결정 하나와 「경고 N개 — 위에 적었다」(또는 「경고 없음」·「이상 없음」) 한 줄만 둡니다.」
      네 옵션은 표(L1127–1132)로 정하고 설명 문면은 없다. 둘째 질문은 「선택지는 「<모델의 제안> (권장)」 · 「인터뷰」, 제안 이유는 게이트 앞 글에」(L1134).
    touches: []
    decides: [OQ2, OQ1, OQ4]
  - id: RC15
    path: "plugins/spec-distill/skills/request-framing/SKILL.md"
    anchor: "### 확인 질문 — 라운드마다 하나"
    line: 242
    claim: >-
      request-framing 에는 선택지 설명에 «고르면 달라지는 것»이 아닌 내용을 싣도록 정한 자리가 있다 — 풀이 확인 질문은 「선택지 설명에 세 줄을 나란히 둡니다: 그 답을 끌어낸 질문 문구 · 사용자가 한 말 · 저자의 풀이」
      (`description: "내가 물은 것 「<질문 문구>」 · 당신이 답한 것 「<사용자가 한 말>」 · 내가 읽은 것 「<풀이 문장>」"`), 풀이가 하나뿐이면 「세 줄 … 은 **질문 텍스트**에 싣는다」(L270–271).
      워크트리 질문(L182–191)은 본문과 옵션 설명 문면을 리터럴로 정한다(「고르면 이 세션의 cwd 가 그 워크트리로 옮겨지고 …」). 공통 블록의 「설명에는 고르면 무엇이 달라지는지만」(RC1)과 글자로는 어긋나는 자리이고,
      블록의 「따로 정한 자리」 예외(RC2)에 드는지를 이 자리는 밝히지 않는다(L935 의 덩어리 본문만 예외라고 밝힌다).
    touches: []
    decides: [OQ2, OQ4]
  - id: RC16
    path: "plugins/spec-distill/references/redecompose.md"
    anchor: "question: \"다시 나눌 표와 영향을 위에 적었다. 어떻게 할까?\""
    line: 57
    claim: >-
      spec-review ③ → 재분해 절차의 승인 질문. 본문이 「다시 나눌 표와 영향을 위에 적었다. 어떻게 할까?」로 질문 밖 글을 가리킨다. 라벨 · 설명: 「이대로 다시 나눈다 (권장)」 — 「새 표로 로드맵 블록과 묶음을 다시 쓰고 재분해 이력에 항목 하나를 남긴다.」 ·
      「고치기」 — 「말로 받아 새 표를 고쳐 다시 보인다.」 · 「그만둔다」 — 「아무것도 쓰지 않고 spec-review 게이트 ③ 의 후속 질문으로 돌아간다.」 설명은 «고르면 일어나는 일»이고 추천 이유 · 대가의 자리는 없다.
    touches: []
    decides: [OQ1, OQ4]
  - id: RC17
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### 2. 사람 몫 모으기"
    line: 26
    claim: >-
      지휘자가 띄우는 결정 질문(흐름 승인 · 감사 · 계획 검토 · 옮긴 질문 · spec 승인)의 규칙: 「답할 수 있는 것만 배경과 함께 하나씩 묻는다. 배경을 붙여 묻는 것은 지휘자가 정할 질문 …이다 —
      brainstorming 대화의 질문은 brainstorming 이 정한 모양 그대로다. 지휘자 질문은 질문 문장 앞머리에 에픽 이름을 쓴다」(L27) · 「부를 skill: 없음(지휘자가 정할 질문은 `AskUserQuestion`.
      brainstorming 대화는 brainstorming 대로 열린 문장 질문이고 선택지는 막혔을 때만이다)」(L29). 병렬 질문(L40)은 「질문 본문 앞에 배경 한 줄(의존 없음 · 경로 예약이 공유 파일 말고 겹치지 않음)을 쓰고,
      선택지는 「병렬 (권장)」(<B…> 의 계획이 끝나는 대로 구현 담당자를 보낸다 — <A> 구현과 동시에 돌고 머지는 하나씩이다)과 「차례로」(…)다」 — 선택지별 결과를 괄호로 정한다.
      계획 검토 · 구현 막힘 · 재리뷰 잔여 · 정리 질문(L102 · L103 · L109 · L114)은 「배경과 함께 묻고(권하는 쪽이 있으면 첫 자리로 옮기고 라벨 끝에 「(권장)」을 단다)」 까지만 정하고 본문 · 설명 문면은 없다.
    touches: []
    decides: [OQ1, OQ4, OQ5]
  - id: RC18
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "지휘자는 배경을 먼저 쉬운 말로 쓰고 질문만 봐도 결정할 수 있게 묻는다"
    line: 32
    claim: >-
      하위 agent 가 돌려보낸 질문을 지휘자가 옮겨 띄울 때의 칸 규칙: 하위는 「(a) 사람에게 보일 쉬운 요약 — 무엇을 정하나 · 고르면 무엇이 달라지나(그대로 두면 · 고치면) · 배경」(L29)과 원문을 함께 돌려보내고,
      지휘자는 「선택지는 (b) 의 수 · 순서 · 라벨 글자를 그대로 두고, 각 선택지 설명에 원문의 「고르면 무엇이 달라지나」 를 빠뜨리지 않는다. 지휘자 의견은 선택지 밖 「지휘자 의견:」 한 줄로만 쓴다.」 ·
      「선택지 설명을 옮길 때 원문의 문장을 하나도 빼지 않는다 — 번역해도 문장 수를 지킨다.」 곧 «추천하는 쪽의 의견 · 이유»는 설명 칸이 아니라 선택지 밖 한 줄에 두라고 정한 자리다(같은 문장이 `conducting.md` L102 에도 있다).
      쓰기 권한 없는 `plugins/spec-distill/agents/relay-checker.md` 가 「지휘자 의견이 선택지 설명 안으로 들어갔으면 어긋남이다」(L34)로 대조한다 — 스크립트가 아니라 agent 의 대조다.
    touches: []
    decides: [OQ4, OQ3]

  # ── (3) 질문 모양을 기계로 재는 장치 ──────────────────────────────────────
  - id: RC19
    path: "shared/tests/ask_recommendation.py"
    anchor: "def required(kind, body)"
    line: 109
    claim: >-
      질문 자리 전수 검사의 본체(`shared/tests/test_ask_recommendation.sh` 가 부른다). 재는 것: ① 모델이 읽는 문서(`plugins/*/skills/*.md` · `plugins/*/references/*.md` · `plugins/*/agents/*.md` · `shared/*/references/*.md`,
      `/tests/` 제외)에서 `AskUserQuestion` 글자가 나온 자리마다 목록(`shared/tests/fixtures/ask-sites.tsv`)의 행이 덮고 «덮는 수»가 맞는가 ② 행의 앵커 · 끝 · 종류가 성립하고 질문 범위가 다른 질문 행의 앵커를 넘지 않는가
      ③ 종류별 필수 글자 — 꼬리: 범위(`label:` 키가 있으면 그 값 안)에 `(권장)` · `(Recommended)` / 지시: 「권하는 쪽이 있으면 첫 자리로 옮기고 라벨 끝에 「(권장)」을 단다」 / 비움: 「추천을 달지 않는다 — 」 가 있고 꼬리가 없다 /
      출처꼬리: 「추천)」 / 떼기: 「라벨 끝의 「(권장)」 · 「(Recommended)」 꼬리를 뗀 이름으로 읽는다」 ④ 후보 줄이 0 이 아닌가. 재지 않는 것: 질문 본문의 내용, 선택지 설명에 무엇이 들었는지, 질문 앞 글, 추천 이유가 적혔는지,
      꼬리가 «첫» 선택지에 있는지(`any(TAIL_RE.search …)` — 아무 라벨이면 통과), 대가 서술. 설명 칸에 대해 아는 것은 하나뿐이다 — 꼬리가 `description` 에만 있으면 ③ 으로 떨어진다
      (fixture `doc.md` 의 「너」·「서」·「저」 → `expected.txt` 「범위의 `label:` 값에 라벨 꼬리 … 가 없다」).
    touches: []
    decides: [OQ3, OQ4]
  - id: RC20
    path: "shared/tests/test_ask_recommendation.sh"
    anchor: "# 한계 둘:"
    line: 8
    claim: >-
      이 락이 스스로 적은 한계: 「· 모델이 즉석에서 만드는 질문은 정본 규칙만이 집행한다. · 도구 이름 없이 문장으로만 묻는 새 질문 자리는 후보로 뽑히지 않는다 — 목록의 손 행은 지금 있는 자리만 덮는다.」
      곧 검사 대상은 «skill · reference 문서의 문면»이고 실행 중 실제로 뜬 질문 화면이 아니다. 목록 `ask-sites.tsv` 는 169줄이고 리뷰 게이트 자리(「# 게이트 · 리뷰 결정 질문 (Task 4)」 L39–74) ·
      request-framing(L76–91) · 지휘자(L93–115) · quality-gates(L117–139) 를 종류(꼬리 · 지시 · 비움 · 출처꼬리 · 언급 · 떼기)로만 분류한다 — 「방향을 정하는 자리」 같은 분류 칸은 없다.
    touches: []
    decides: [OQ3, OQ1]
  - id: RC21
    path: "shared/tests/test_docreview_round_gate_split.sh"
    anchor: "**이 축의 한계** — 이 락이 잴 수 있는 것은 이 규약이 절차서·"
    line: 31
    claim: >-
      라운드 게이트 문면 락. 재는 것은 절차서 · spec-review(일부는 reviewing-brief · request-framing 까지) 본문에 문구가 있는가다 — 「최대 4개씩」 · 「replacement 를 1–5 낱말로 압축」 · 「같은 라벨을 갖지 않는다」 ·
      「질문 · 선택지 이름에 AC 번호 · 지적 id · § 를 쓰지 않고」 · 추천 지시 3회 · 「렌더 첫 줄(상태와 경고)은 첫 호출 **앞 글**에 한 번 쓴다」 각 1회. 스스로 적은 한계: 「라벨 조립은 엔진이 아니라 런타임의
      오케스트레이터가 하므로, 오케스트레이터가 실제로 이 규약을 **지키는가**는 이 락의 도달 밖이다(e2e 로만 눈으로 본다).」 선택지 설명에 관한 단언은 없다.
    touches: []
    decides: [OQ3]
  - id: RC22
    path: "plugins/spec-distill/tests/test_plain_gate_templates.sh"
    anchor: "# ⑬ 질문 본문에는 결정과 상태 한 줄만 — 자리마다 그 문장(M5 · M7)."
    line: 133
    claim: >-
      게이트 질문의 칸 배치를 재는 락. 문장 실재(줄바꿈을 접은 본문에서 정확히 N번)로 잰다 — 다섯 자리의 「질문 본문에는 결정 하나와 … 「경고 N개 — 위에 적었다」 … 한 줄만」 · 「게이트 앞 글」 이름 ·
      「옵션 description 에 싣지 않습니다」(finishing, ⑭) · B-2 `question:` 줄에 「위에 적었다」가 있고 `degrade:` 가 없다(②). `plugins/spec-distill/tests/test_brief_review_entry.sh`(L254–277)는 B-2 javascript 펜스 «안»의 `question:` 줄이 정확히 하나이고
      「위에 적었다」를 담는지를 잰다(「경고 개수 줄이 description 이나 죽은 // 코멘트로 옮겨 갔다」를 RED 로). 곧 «질문 밖을 가리키는 「위에 적었다」»는 여러 락이 리터럴로 못 박고 있어, 이 문구를 바꾸면 이 락들이 함께 걸린다.
      선택지 설명이 «무엇을 담아야 하는가»를 재는 단언은 이 두 파일에 없다(부정 방향 — degrade 를 싣지 않는다 — 만 있다).
    touches: []
    decides: [OQ3, OQ4]
  - id: RC23
    path: "plugins/spec-distill/tests/test_conducting_interview_stage.sh"
    anchor: "grep -qF '고르면 무엇이 달라지는가' <<<\"$round_flat\""
    line: 498
    claim: >-
      인터뷰 라운드 규약의 «추천 · 트레이드오프» 줄과 설명 규칙은 문구 실재로만 잰다 — `### 다음 결정` 다음 줄이 `OQ<n>: <무엇을 정하는지 한 줄> · 추천: ` 로 시작하는지(L487), 「질문마다 추천이 있으면 첫 선택지에 두고 그 라벨 끝에 `(권장)` 을 단다」(L496),
      「고르면 무엇이 달라지는가」(L498). 「트레이드오프: <선택지별 한 줄>」 꼬리는 접두 대조(`'OQ<n>: … · 추천: '*`)에 들지 않아 이 락이 재지 않는다. SKILL 본문도 설명 규칙에 대해 「기계 검사는 없다.」고 적는다(RC4).
    touches: []
    decides: [OQ3]

  # ── (4) 코드 리뷰 쪽(quality-gates)의 결정 질문 ───────────────────────────
  - id: RC24
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "### Fix-loop decision"
    line: 812
    claim: >-
      코드 리뷰 뒤 결정 질문은 본문 · 라벨 · 설명을 펜스 리터럴로 정한다. 앞 글은 Step 4.5 의 판정 원문 표면화와 Step 5 분류표(「Print the table」 L802 — `| # | 지적 | 분류 | 사유 |`)다. 본문:
      「qg 반복 N: 남은 지적이 있다(<summary>). 어떻게 할까?」(`<summary>` 는 「the `**Findings:**` counts line from `$RV/synth.out`, copied verbatim」 L816). 설명: 「고치고 다시 돌기」 — 「분류표의 「적용」 항목을 이 턴에서 파일에 고치고 다음 반복을 돈다(차등 테스트 포함).」 ·
      「지금 판정으로 끝내기」 — 「남은 지적을 그대로 두고 지금 판정으로 끝낸다.」 · 「멈추기」 — 「이 반복에서 멈춘다 — PR 코멘트도 달지 않는다. 지적을 고친 뒤 /quality-gates:quality-pipeline 을 다시 돌린다.」 설명이 질문 밖의 표(「분류표의 「적용」 항목」)를 가리킨다.
      둘째 질문 「분류표의 적용/제외를 바꿀까요? 바꿀 항목 번호는 「기타」에 적는다(예: 2, 5).」 도 앞에 찍은 표를 가리키고 「추천을 달지 않는다 — 분류표는 오케스트레이터가 자기 코드의 지적에 매긴 적용/제외다.」(L873).
      첫 질문은 「권하는 쪽이 있으면 첫 자리로 옮기고 라벨 끝에 「(권장)」을 단다」(L845)뿐이고 추천 이유 · 대가를 적는 자리는 이 절에 없다(공통 블록 사본 L52 가 「이유는 질문 위 글에」).
      Max-iter(L926–957)도 같은 꼴 — 「show the table (Step 5) and call」, 본문 「qg 가 반복 상한(<CAP>번 — 기본 5번)에 닿았다. 마지막 지적: <summary>. 반복을 하나 더 열까, 지금 판정으로 끝낼까, 멈출까?」.
    touches: []
    decides: [OQ1, OQ4]
  - id: RC25
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "**낮춘 지적 게이트 (표면화 뒤 · 라우팅 앞).**"
    line: 707
    claim: >-
      낮춘 지적 게이트는 본문이 질문 밖 글을 직접 가리킨다 — 「재비판이 심각도를 낮춘 지적이 <n>개 있다(위 「낮춘 지적」 절). 되올릴 것을 고르세요 — 되올리면 원래 심각도로 판정에 들어간다.」 설명은
      `{label: "<파일 이름>:<줄> (L<k>)", description: "<낮춘 이유를 쉬운 말 한 줄로>"}` — «고르면 달라지는 것»이 아니라 «이유»를 싣는다(달라지는 것은 본문에 있다). 「추천을 달지 않는다 — 낮춘 지적을 되올릴지는 리뷰 대상 코드를 쓴 쪽이 권할 수 없는 처분이다.」(L720).
      범위 모드 질문(L824–839) · 수정 실패 질문(L1011–1026)은 본문 · 설명 리터럴 + 추천 지시다(예: 「<file> 수정에 실패했다: <reason>. 이번 수정 반복을 멈출까, 이 파일만 건너뛰고 나머지를 계속할까?」 / 「이번 수정 반복 전체를 멈추고 qg 판정에 실패로 올린다.」).
    touches: []
    decides: [OQ1, OQ4]
  - id: RC26
    path: "plugins/quality-gates/references/e2e.md"
    anchor: "증거표와 판정안을 보인 뒤 `AskUserQuestion` 하나를 띄운다. 선택지는 판정안의 행을 따른다."
    line: 102
    claim: >-
      e2e 걷기 직후 게이트는 앞 글(증거표 · 판정안)과 선택지 «이름»만 표로 정한다(「| pass | 승인 / fail 로 뒤집기 / 다시 걷기 |」 등 L104–109) — 본문 문면과 선택지 설명은 정하지 않고 「권하는 쪽이 있으면 첫 자리로 옮기고 라벨 끝에 「(권장)」을 단다」(L111)만 있다.
      같은 파일 §2 시나리오 질문은 설명 내용을 따로 정한다 — 「`description` 은 부팅 명령 글자 그대로 · 명령 출처 · 기대 상태 수 · 「고르면 이 명령을 이 컴퓨터에서 실행하는 것을 승인한다」 를 담는다」(L41–42) ·
      「질문 본문 · 선택지의 `label` · `description` 은 SKILL.md `## 사람에게 쓰는 글` 을 따른다. 부팅 명령은 글자 그대로 둔다.」(L44) · 「추천을 달지 않는다 — 고르는 것이 곧 이 컴퓨터에서 명령을 실행해도 된다는 승인이다.」(L57).
    touches: []
    decides: [OQ1, OQ4, OQ6]
  - id: RC27
    path: "plugins/quality-gates/skills/artifact-critique/SKILL.md"
    anchor: "### E3 — 범위 고르기 · 규모 공시"
    line: 169
    claim: >-
      문서 비평 쪽 질문은 인용 문장 + 괄호 풀이 꼴이다. E3(L179–191): 「「실행」을 첫 자리에 두고 「(권장)」을 단다. 이유(사용자가 부른 대상 · 모드 그대로다)는 질문 위 글에 쓴다」 — 추천 이유의 자리를 «질문 위 글»로 다시 적는 자리이고,
      비평자 수 질문은 대가를 «본문»에 싣는다(「기본 1명 — 늘리면 지적을 더 넓게 찾지만 라운드마다 그만큼 더 부른다」). 멈출 때의 선택(L133–140): 「질문 글에 멈춘 대상과 이유를 대상마다 나열한다」, 옵션마다 괄호로 결과
      (「**지적만 받기로 진행**(실행 전체를 「지적만 받기」로 바꾼다 — …)」). 판정 실패(L296–299, 「재시도 / 중단?」) · 상한(L353–358, 「한 번 더 돌기」 · 「여기서 끝내기」) · 모호한 대상 확인(L97)은 본문 인용과 라벨 + 추천 지시만 있고 설명 문면이 없다.
    touches: []
    decides: [OQ1, OQ4, OQ6]
  - id: RC28
    path: "plugins/quality-gates/tests/test_plain_qg_templates.sh"
    anchor: "assert_eq \"$(qlines \"$S\" | grep -c .)\" \"6\""
    line: 51
    claim: >-
      quality-gates 의 질문 락은 `question:` 줄의 리터럴(한국어 문면 · 개수 여섯) · 라벨 · 머리글 · 분기 불릿과 라벨의 일치를 재고, 설명은 세 자리의 리터럴만 잰다 —
      `description: "표의 적용/제외대로 고친다."`(L64) · 「멈추기」 설명의 「PR 코멘트도 달지 않는다」(L66 「규칙 블록: 멈추기 설명이 달라지는 것(게시 없음)을 말한다」 · L167) · 「한 번 더 돌기」 설명 전문(L168).
      질문 앞 글에 무엇이 실렸는지, 추천 이유 · 대가가 적혔는지를 재는 단언은 없다. 추천 표시는 RC19 의 공용 락이 quality-gates 행(`ask-sites.tsv` L117–139)으로 잰다.
    touches: []
    decides: [OQ3]

  # ── 설명 문면이 없는 자리의 모음 ──────────────────────────────────────────
  - id: RC29
    path: "shared/tests/fixtures/ask-sites.tsv"
    anchor: "# 게이트 · 리뷰 결정 질문 (Task 4)"
    line: 39
    claim: >-
      읽은 자리를 «설명 문면을 리터럴로 정했는가»로 가르면 둘이다. 정한 자리(펜스에 `description:` 이 있다): finishing 분해 판단 · 재제시 상한 · B-2, redecompose, trivia-escape, request-framing 워크트리 · 풀이 확인,
      quality-pipeline 의 다섯 펜스, e2e §2 시나리오 질문(내용 지정), plugin-audit 축 고르기(「선택지 설명에 규모를 싣는다」). 정하지 않고 라벨(과 추천 지시)만 적은 자리: 엔진 라운드 게이트의 결정 질문 전부(RC5 —
      고친다 / 그대로 둔다 / 나중에 정한다), 「추가 라운드 1회 열기」 · 「열기 / 열지 않음」, 표지 충돌 「그만둠 (권장)」/「이어 씀 …」, 「참고 전부 보기 (권장)」 · 「접은 채로 둔다」, spec-review 2단계 넷 · ③ 후속 갈래 · 지휘자 아래 승인 셋,
      request-framing `fix` 「적용 / 적용하지 않음」 · 저자 편집 「그대로 둔다 / 되돌린다」 · 확정 게이트 넷, conducting 의 계획 검토 · 막힘 · 정리 질문, e2e 걷기 직후 게이트, artifact-critique 의 판정 실패 · 상한 · 모호한 대상 확인.
      뒤쪽 자리에서 설명 칸을 채우는 규칙은 공통 블록 한 문장(RC1)뿐이고, 그 칸이 비었는지를 재는 장치는 없다(RC19–RC23 · RC28).
    touches: []
    decides: [OQ6, OQ1, OQ3]

unanswered: >-
  레포가 답하지 못한 것 셋. (가) 사용자가 본 「설명 칸이 없던」 화면이 어느 자리였는지 — 레포에는 문면 규칙만 있고 실제로 뜬 질문의 기록을 이 조사 범위(plugins/ · shared/)에서 찾지 못했다. RC29 는 후보 자리의 목록일 뿐이다.
  (나) 「방향을 정하는 자리」 라는 분류 — 질문 자리를 그렇게 가르는 문면 · 목록 칸이 없다(conducting.md L28 의 「brief · 설계 · 계획처럼 방향을 정하는 단계」 한 구절은 «기다림» 규칙이지 질문 모양 규칙이 아니다).
  (다) superpowers brainstorming 자체의 질문 모양 — 레포 밖 skill 이라 읽지 않았다. 레포가 말하는 것은 「그 skill 을 따른다 · 이 블록은 낱말에만」(RC2 · RC17)까지다.
```

서로 어긋나 보이는 주장(하나로 고르지 않고 둘 다 냈다):

- RC1 「설명에는 고르면 무엇이 달라지는지만 쓴다」 대 RC15(설명에 질문 문구 · 사용자 말 · 풀이 세 줄) · RC25(설명에 «낮춘 이유») · RC26(설명에 부팅 명령 · 출처 · 기대 상태 수). 블록의 「따로 정한 자리」 예외(RC2)로 읽을 수 있으나, 그 예외라고 스스로 밝힌 자리는 request-framing 의 덩어리 본문(RC14) 하나뿐이다.
- RC1 「이유는 질문 위 글에」 대 RC27(비평자 수 질문은 대가를 질문 «본문»에 싣는다) · RC17(병렬 질문은 선택지별 결과를 괄호 — 설명 — 로 정한다) · RC4(인터뷰는 «다음 결정» 줄에 추천과 트레이드오프를 함께 적는다). 추천의 이유 · 대가가 서는 칸이 자리마다 다르다.
- RC5 · RC13 「질문 본문에는 결정 하나와 … 한 줄만」 대 RC14(덩어리 본문을 질문 텍스트에 줄임 없이) · RC27(멈춘 대상과 이유를 질문 글에 나열).

읽은 파일(절대경로):

- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/style/plain-language.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/docreview/references/reviewing-document.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/docreview/scripts/docreview_state.py (L2128–2197 · L2270–2558)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/tests/ask_recommendation.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/tests/test_ask_recommendation.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/tests/fixtures/ask-sites.tsv
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/tests/fixtures/ask_recommendation/doc.md (같은 폴더의 sites.tsv · expected.txt 포함)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/tests/plain_language_block.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/tests/test_plain_language_block.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/tests/test_docreview_round_gate_split.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/references/proceed-gate.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/references/conducting.md (L24–43 · L96–109 · L114)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/references/conductor-dispatch.md (L24–35)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/references/redecompose.md (L50–64)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/references/trivia-escape.md (L11–31)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/skills/spec-review/SKILL.md (L1–398 · L543–602 · L630–829, 그 사이는 grep)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/skills/reviewing-brief/SKILL.md (L592–621, 나머지는 grep)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/skills/request-framing/SKILL.md (L236–275 · L776–809 · L926–941 · L1086–1145 · L1170–1181, 나머지는 grep)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/skills/pm-interview/SKILL.md (L176–219)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/skills/pm-interview/references/finishing.md (L26–67 · L262–341 · L398–542)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/skills/pm-interview/references/steelman.md (L92 · L104, grep)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/agents/relay-checker.md (L34 · L37, grep)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/tests/test_plain_gate_templates.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/tests/test_brief_review_entry.sh (L240–284)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/tests/test_conducting_interview_stage.sh (L480–501)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/quality-gates/skills/quality-pipeline/SKILL.md (L690–959 · L1000–1029 · L1155–1174)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/quality-gates/skills/artifact-critique/SKILL.md (L130–194 · L292–363)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/quality-gates/references/e2e.md (L30–59 · L96–129)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/quality-gates/tests/test_plain_qg_templates.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/plugin-audit/skills/plugin-audit/SKILL.md (L82–86, grep)

부분만 읽은 파일의 «없다» 주장(예: 「이 자리는 설명 문면을 정하지 않는다」)은 해당 파일에 `설명에|description:|선택지 설명|질문 위 글|앞 글|위에 적었다` grep 을 함께 돌려 확인한 것이다. grep 이 놓칠 다른 표현의 규칙이 읽지 않은 구간에 있을 가능성은 남는다. Grep · Glob 은 심볼릭 링크를 건너뛰므로 링크로만 닿는 사본은 보지 못했다.

### 조사 3 — open-researcher · R1 · 묶음 1

조사 결과입니다. 확인한 날은 모두 2026-11-15, 레포 루트는 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs` 입니다(`path` 는 그 아래 상대경로).

읽는 법 셋.
- 전제 `P<n>` 을 받지 못해 `touches` 는 전부 빈 배열입니다.
- `supports` 는 이렇게 썼습니다: `current` = seed 의 지금 이해와 레포의 지금 방식(질문 앞 글에 싣고 「위에 적었다」로 가리킴)을 뒷받침, `alternative` = 다른 길을 뒷받침, `both` = 양쪽 재료.
- 공식 저장소 issue 는 `primary` 로 두되, 내용이 Anthropic 직원 발언인지 사용자 보고인지 claim 안에 갈라 적었습니다.

가장 무게가 큰 발견 셋.
- **(A)** 터미널 CLI 에서 질문과 같은 턴에 그 앞에 쓴 글이 «가려지는» 것이 아니라 아예 그려지지 않고 저장된 세션 기록에도 글 블록으로 남지 않는 결함이 열려 있습니다. Anthropic 직원이 2.1.233 에서 재현했고, 사용자 보고는 2.1.325(최신)까지 이어집니다.
- **(B)** 다른 plugin 의 skill 이 띄우는 질문에 닿는 공식 수단은 둘입니다. plugin 의 PreToolUse 훅(세션 전체에 걸리고 `AskUserQuestion` 의 입력을 봄)과 mod(도구 호출 · 다른 skill 의 글 · 질문 창 위 그림을 바꿈)입니다.
- **(C)** 선례는 대체로 「추천 표시는 라벨에, 대가 · 결과는 선택지 아래 설명에 짧게」 쪽입니다. 추천을 기본값으로 보이면 쏠림이 생기고, 설명을 붙이는 것만으로는 과신이 줄지 않는다는 연구가 있습니다.

```yaml
evidence:
  # ───────── (A) 질문 창과 그 앞 글 · 칸 · 제약 ─────────
  - url: "https://github.com/anthropics/claude-code/issues/75182"
    supports: current
    claim: "터미널 CLI 에서 AskUserQuestion 과 같은 턴에 그 앞에 쓴 assistant 글이 전혀 표시되지 않는다는 issue 가 열려 있다(2026-07-07 개설, 마지막 댓글 2026-11-14). Anthropic 직원(bcherny, 2026-08-16)이 2.1.233 · macOS 터미널에서 재현을 확인했다: 기본 Opus 에서는 글이 질문 위에 그려지고 scrollback 에 남았으나, Fable 5 에서는 답하기 전에도 뒤에도 나타나지 않았고 저장된 세션 transcript 에도 없었다. 직원 발언 원문: 'the model's user-facing text is arriving in a form the CLI treats as hidden reasoning, so nothing is displayed', 고칠 자리가 모델/API 쪽인지 클라이언트 쪽인지는 'still being worked out'. 직원이 준 우회: 턴을 평문으로 끝내고(뒤에 도구 호출 없이) 다음 턴에 묻거나, 그 세션에 Fable 이 아닌 모델을 쓴다. 고쳐진 판은 언급 없음."
    touches: []
    decides: [OQ4, OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303 (plugins/*/dependencies.md, 잰 날 2026-10-22)", latest: "2.1.325 (공식 CHANGELOG.md 맨 위)"}
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/75182"
    supports: both
    claim: "위 직원 판정(「Fable 5 한정」)과 충돌하는 사용자 보고가 같은 issue 에 있다(직원 확인 없음). jayenashar(2026-10-26, 2.1.302 등): opus-5-5 · sonnet-5-5 · fable-5-1 에서 0/3, haiku-5-5 만 3/3, thinking 을 끄는 환경 변수로도 같고 raw stream-json 에서도 같아 'the text seems to become a thinking block before the client sees it'. deraljoscha(2026-11-14, 2.1.325 · Opus 5.5): jsonl 에 약 200자 요약의 thinking 블록만 있고 전체 글은 없다. oschrenk(2026-11-06, 2.1.314): CLAUDE.md · 메모리 지시(「설명과 질문을 같은 턴에 쓰지 말라」)가 'do not hold reliably', 질문이 'the three options above' 처럼 그 글을 가리켜 답할 수 없다. 둘 다 보고한다 — 모델 한정인지 아닌지는 고르지 않았다."
    touches: []
    decides: [OQ4, OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: uncertain
  - url: "https://github.com/anthropics/claude-code/issues/84409"
    supports: current
    claim: "같은 증상의 다른 열린 issue(2026-08-06 개설, Windows Terminal CLI, 2.1.220; 댓글로 2.1.287 · 2.1.306 · macOS iTerm2). 보고자 원문: 'only the bare option picker is shown', 'nothing of the preceding message renders at all, not just its final line'. 보고자는 회귀라고 적었으나 마지막으로 정상이던 판은 'Unknown'. 직원 댓글 없음(라벨만). 관련: #67426(CLI, 2.1.173, 비결정적으로 빠짐 — 봇이 비활성으로 not planned 닫음, 직원 댓글 없음, 우회로 「맥락을 파일에 쓰고 경로를 question 칸에」 · 「preview 는 몇 줄 뒤 접혀 우회가 못 된다」), #66960(열림, Fable 5 에서 text 블록이 화면과 기록 양쪽에서 빠짐)."
    touches: []
    decides: [OQ4, OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md"
    supports: both
    claim: "공식 changelog 의 판별 변화(전 구간을 훑음). 2.0.21 'Added an interactive question tool'. 2.0.62 'Added \"(Recommended)\" indicator for multiple-choice questions, with the recommended option moved to the top of the list'. 2.1.85 PreToolUse 훅이 updatedInput 으로 AskUserQuestion 을 답할 수 있게 됨. 2.1.141 'Fixed AskUserQuestion popup hiding the last line of preceding chat content'. 2.1.154 'Claude now reserves the multiple-choice question prompt for decisions it genuinely cannot make itself'. 2.1.181 'Fixed AskUserQuestion preview content being cut off at the dialog edge instead of word-wrapping'. 2.1.200 질문 창이 기본으로 자동 진행하지 않음. 2.1.261 '[VSCode] Added a fold button to permission and question prompts so the conversation behind them can be read without dismissing them; the space beside the prompt now scrolls the conversation'. 2.1.281 '[VSCode] Fixed Claude attaching option previews to multiple-choice questions in the chat panel, where the question card never shows them'. 2.1.286 '[VSCode] Added option previews to question cards in the chat panel…' 와 '[VSCode] Added the questions Claude asks and your answers to the conversation…'. 「같은 턴 앞 글이 통째로 안 그려지는」 증상을 고쳤다는 줄은 2.1.325 까지 찾지 못했다."
    touches: []
    decides: [OQ4, OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/tools-reference"
    supports: both
    claim: "공식 도구 문서의 AskUserQuestion 절은 답하는 법('picking an option, or type your own text through the `Other` row or the notes field')과 자동 진행 시간 제한(`askUserQuestionTimeout`, 기본은 답할 때까지 열림)만 적는다. 질문 앞 글이 창이 떠 있는 동안 보이는지, description · preview 가 어떻게 그려지는지는 이 문서에 없다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/agent-sdk/user-input"
    supports: both
    claim: "공식 제약: 한 호출에 질문 1–4개, 질문마다 선택지 2–4개('each `AskUserQuestion` call supports 1-4 questions with 2-4 options each'), header 는 'max 12 characters', 선택지는 `label` 과 `description`. `preview` 는 SDK 에서 `toolConfig.askUserQuestion.previewFormat` 을 켰을 때만 생긴다('Without this setting, Claude does not generate previews'). Agent 도구로 띄운 subagent 에서는 AskUserQuestion 을 쓸 수 없다. question · label · description 의 글자 수 상한은 문서에 없다. TypeScript 참조(https://code.claude.com/docs/en/agent-sdk/typescript)의 `AskUserQuestionInput` 은 `options: Array<{ label: string; description: string; preview?: string }>` 이다 — description 은 필수 칸이고 preview 만 선택 칸이다."
    touches: []
    decides: [OQ4, OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/45384"
    supports: alternative
    claim: "「설명 칸이 없는 화면」의 한 후보: CLI(macOS, 2026-04-08 보고, 판 미기재)에서 선택지에 `preview` 가 있으면 `description` 이 그려지지 않는다는 보고('Only `label` and `preview` are rendered. `description` is silently dropped'; preview 가 없으면 description 은 라벨 아래 정상). 직원 댓글 없이 봇이 비활성으로 not planned 닫음(2026-05-22). 지금 판에서도 그런지는 확인하지 못했다."
    touches: []
    decides: [OQ6, OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: uncertain
  - url: "https://github.com/anthropics/claude-code/issues/77242"
    supports: alternative
    claim: "「질문 본문이 안 보이는 화면」의 한 후보: 터미널에서 선택지(라벨 + 설명)와 header 는 보이는데 question 글이 안 보인다는 열린 issue(2.1.201 · 2.1.207 · 2.1.234). 직원(bcherny, 2026-08-17)은 Linux tmux 에서 2.1.233 · 2.1.207 로 재현하지 못했다('may be specific to your terminal setup or the particular question content'). 한 보고자의 진단(직원 미확인): 질문 글이 dark 테마의 흰색으로 칠해져 밝은 배경 터미널에서 거의 안 보이고, `/theme` 을 Auto 나 Light 로 바꾸면 보인다."
    touches: []
    decides: [OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: uncertain
  - url: "https://github.com/anthropics/claude-code/issues/95228"
    supports: both
    claim: "VS Code 확장: 2.1.273–2.1.274 에서 질문 카드는 'label + description only' 로 그려지고 preview 는 버려졌다. Anthropic 직원(bpasero-ant, 2026-10-24): 'This is fixed in Claude Code 2.1.286.' CLI 는 preview 를 그린다고 보고자가 적었다. 표면마다 칸의 표시가 달랐고 2.1.286 에서 바뀌었다는 뜻이다."
    touches: []
    decides: [OQ4, OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/73629"
    supports: current
    claim: "VS Code 확장(2.1.201, 2026-07): 같은 턴의 앞 글이 질문 modal 앞에도 뒤 transcript 에도 나타나지 않는다는 보고. 한 댓글은 AskUserQuestion 한정이 아니라 글 뒤에 어떤 tool_use 가 와도 같고 모델과 무관하다고 주장했다(직원 미확인). 봇이 not planned 로 닫음, 직원 댓글 · 고친 판 없음. 따로 changelog 2.1.261 이 VS Code 에 질문 창 접기 버튼을 더했다 — 이것은 «가림» 에 대한 조치이고 «안 그려짐» 과는 다른 증상이다."
    touches: []
    decides: [OQ4, OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: uncertain
  - url: "https://github.com/anthropics/claude-code/issues/64776"
    supports: current
    claim: "데스크톱 앱(Code 탭, 2.1.160, Windows, 2026-06): 질문 팝업이 앞 메시지의 대부분을 덮어 3–5줄만 보인다는 보고(«가림» 증상). 직원 댓글 없이 봇이 닫음. 보고자가 2026-07-09 에 질문을 접는 작은 화살표 버튼이 생겼다고 적었으나 공식 changelog 근거는 아니다. 관련 #67474(데스크톱, 2.1.173): 한 턴 안의 도구 호출 사이 글이 transcript 에서 조용히 숨겨지고 같은 기계의 터미널 CLI 는 그렸다는 보고 — 봇이 닫음."
    touches: []
    decides: [OQ4, OQ6]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain

  # ───────── (B) 다른 plugin 의 질문 모양에 규칙을 거는 공식 수단 ─────────
  - url: "https://code.claude.com/docs/en/hooks"
    supports: alternative
    claim: "PreToolUse 훅은 `AskUserQuestion` 을 matcher 로 잡을 수 있고(내장 도구 목록에 명시), `tool_input` 으로 `questions` 배열(각 `question` · 짧은 `header` · `options`(label · description) · `multiSelect`)을 받는다. 결정은 `permissionDecision` allow/deny/ask/defer 이고 'deny prevents the tool call'. `updatedInput` 은 'Replaces the entire input object … Combine with \"allow\" to auto-approve, or \"ask\" to show the modified input to the user'. AskUserQuestion 은 사용자 상호작용이 필요한 도구라 'Returning \"allow\" alone is not sufficient' 이고, `updatedInput` 에 `answers` 를 실어야 창 없이 돈다. 곧 훅은 질문의 칸을 기계로 검사해 막고 사유를 모델에 돌려줄 수 있다. 질문 칸을 고쳐 쓴 뒤에도 사용자에게 창을 띄우는 조합(ask + updatedInput)이 AskUserQuestion 에 통하는지는 문서가 따로 적지 않았다."
    touches: []
    decides: [OQ3, OQ5]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/components.md"
    supports: alternative
    claim: "plugin 의 훅은 그 plugin 의 skill 이 쓰일 때만 도는 것이 아니다: 'A plugin's hooks don't wait for one of the plugin's skills or commands to be used. Claude Code registers them when a session loads the plugin, and they fire on their events from then on. To limit when a hook runs, narrow its `matcher`.' 또 'If a rule must hold every time … add it to the plugin as a hook rather than a skill.' plugin 루트의 CLAUDE.md 는 맥락으로 읽히지 않는다('To include instructions in a plugin, write them as a skill'). 곧 한 plugin 의 PreToolUse 훅은 다른 plugin 의 skill 이 띄운 AskUserQuestion 호출에도 걸린다."
    touches: []
    decides: [OQ3, OQ5]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/skills"
    supports: both
    claim: "skill 문서에는 한 skill 이 다른 skill 의 동작을 제약 · 감싸는 수단이 적혀 있지 않다. plugin skill 은 `/plugin-name:skill-name` 으로 이름 공간이 갈려 같은 이름으로 덮지 못한다. skill frontmatter 의 `hooks` 는 'registers when the skill is invoked and keeps running for the rest of the session'. `allowed-tools` 는 'does not restrict which tools are available'."
    touches: []
    decides: [OQ5, OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/mods/events.md"
    supports: alternative
    claim: "mod(plugin 의 `hooks/hooks.json` `modules` 로 싣는 JS 핸들러, 터미널 2.1.287 · 데스크톱 2.1.286 부터 기본 켜짐)의 `tool.call` 훅은 Claude 가 쓰려는 모든 도구 호출(subagent · MCP 포함)을 보고 'refuse the call, change its arguments, or let it through' 할 수 있고, `{ deny: reason }` 은 Claude 가 도구 결과로 읽는다. 참조(https://code.claude.com/docs/en/plugins/mods/reference.md)의 `skill.prompt` 이벤트는 'A skill's text is expanded for Claude' 때 불리고 `e.pluginName` · `e.path` 로 어느 plugin 의 skill 인지 읽으며(2.1.299+) 'A hook can pass a changed `text` … Claude reads the final `text`' — 다른 plugin 의 skill 글을 읽는 순간에 고쳐 넣는 공식 수단이다. 개요(https://code.claude.com/docs/en/plugins/mods/overview.md)의 경고: mod 는 사용자 권한으로 돌고 sandbox 밖이며, 'Install mods only from authors and marketplaces you trust'. 조직의 built-in guard 가 사용자 mod 의 일부 훅을 건너뛸 수 있다."
    touches: []
    decides: [OQ3, OQ5]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/mods/interface.md"
    supports: alternative
    claim: "질문 창은 mod 의 render site 다: 'The permission prompt isn't a render site … The question dialog, `AskUserQuestion`, is one, so a mod can change that dialog when Claude asks a question. A tree for the dialog has to hold the reference exactly once, with your elements above it.' 터미널 · 데스크톱 · VS Code 에서 동작하되, VS Code 는 'the panel keeps its own question card and draws your elements above it. Props you pass to `next` don't change the card'(확장 2.1.299+). 곧 mod 는 질문 창 바로 위에 글을 그릴 수 있다. `claude -p` · cloud session 에서는 mod 가 그리는 것이 나타나지 않는다(개요의 표)."
    touches: []
    decides: [OQ4, OQ3, OQ5]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/75182"
    supports: both
    claim: "훅의 한계에 대한 사용자 보고(직원 미확인). oschrenk(2.1.314): AskUserQuestion 의 PreToolUse 훅이 `transcript_path` 를 읽어 마지막 사용자 메시지 뒤 assistant 글이 200자를 넘으면 deny 하는 우회가 'That works'. deraljoscha(2.1.325, Linux): 'Neither PreToolUse nor PostToolUse on AskUserQuestion sees the running turn's assistant entry … The hook counts zero and lets everything through.' 두 보고가 충돌한다. 따로, 공식 hooks 문서에서 읽은 범위의 PreToolUse 입력에는 그 호출을 낸 skill · plugin 을 이름 붙이는 칸이 없었다(공통 입력 칸 절 전체는 읽지 못했다)."
    touches: []
    decides: [OQ3, OQ5]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: uncertain

  # ───────── (C) 바깥 선례 — 추천과 대가를 짧게 함께 ─────────
  - url: "https://learn.microsoft.com/en-us/windows/win32/uxguide/ctrl-command-links"
    supports: alternative
    claim: "Microsoft Windows UX 지침(command link = 선택지 라벨 + 선택지 아래 보조 설명, Windows 7 때 문서이고 '원칙은 여전히 적용'이라는 주석). 라벨: 'Use parallel phrasing and single line labels', 'Focus the labels on the differences among the responses'. 추천: 'If a response is strongly recommended, add \"(recommended)\" to the label. Be sure to add to the label, not the supplemental explanation.' 보조 설명: 'Supplemental explanations describe why users might want to choose a response or what happens if a response is chosen', 'Use parallel phrasing and at most three lines of text', 'Don't use a supplemental explanation that is wordy restatement of the command link', 'Omit details that don't affect the choice'. 수: 2–5개, 가장 흔히 쓰는 것을 첫 자리에. 기본값: 'Select the safest … and most secure response to be the default'. 과잉 경고: 'Don't use command links to over-communicate.' 쏠림: 'Users are less likely to change a default radio button than a default command link … command links are a better choice if you want to encourage users to make an explicit choice.'"
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://learn.microsoft.com/en-us/windows/win32/uxguide/win-dialog-box"
    supports: alternative
    claim: "같은 지침의 dialog 절: 주 지시문은 'Be concise use only a single, complete sentence … If you must explain anything more, use supplemental instruction'. 'If the appearance of the dialog box is program or system initiated (and therefore out of context), use the supplemental instruction to explain why the dialog has appeared. For such dialogs, the context is usually not obvious.' — 맥락은 창 밖이 아니라 창 안의 보조 지시문에 실으라는 선례다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://developer.apple.com/design/human-interface-guidelines/alerts.md"
    supports: both
    claim: "Apple HIG Alerts(변경 기록 마지막 2024-02-02): 제목은 'clearly and succinctly describes the situation … avoid overly long titles that wrap to more than two lines', 설명 글은 'Include informative text only if it adds value … keep it as short as possible', 버튼은 'one- or two-word title that describes the result of selecting the button', 'Avoid explaining alert buttons'. 기본값: 'If you want to encourage people to read an alert and not just automatically press Return to dismiss it, avoid making any button the default button.' 짧음을 더 세게 요구하고, 읽게 하려면 기본 버튼을 두지 말라는 쪽이다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions"
    supports: alternative
    claim: "ADR 원전(Nygard, 2011): Consequences 칸에 'All consequences should be listed here, not just the \"positive\" ones', 문서 전체는 'one or two pages long'. MADR(https://adr.github.io/madr/, 최신 릴리스 4.0.0 · 2024-09-17)의 템플릿 줄: 'Chosen option: \"{title of option 1}\", because {justification…}', Consequences 는 '* Good, because {positive consequence…}' · '* Bad, because {negative consequence…}'(선택 절), 선택지별로도 Good/Neutral/Bad 줄. Y-statement(Zimmermann; https://socadk.github.io/design-practice-repository/artifact-templates/DPR-ArchitecturalDecisionRecordYForm)는 결정 하나를 한 문장으로 적으며 그 안에 'to achieve …, accepting that …'(얻는 것 · 받아들이는 대가)을 둔다 — 템플릿 문장은 그 페이지에서 그림이라 글로 확인한 것은 이 두 구절뿐이고, 길다는 반응이면 두세 문장으로 나누라고 한다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://collaborate.princeton.edu/en/publications/when-and-why-defaults-influence-decisions-a-meta-analysis-of-defa/"
    supports: both
    claim: "기본값 쏠림: Jachimowicz · Duncan · Weber · Johnson (2019, Behavioural Public Policy 3(2):159-186) 메타분석 — 58개 연구(n=73,675)에서 'a considerable influence of defaults (d = 0.68, 95% CI 0.53-0.83)', 연구마다 편차가 크고(무효 · 음의 효과도 있음), 기본값이 「설계자가 권하는 것」으로 읽힐 때(endorsement) · 현 상태로 읽힐 때(endowment) 더 세다. Nielsen 'The Power of Defaults'(2005-09-25, https://www.nngroup.com/articles/the-power-of-defaults/): 'Users click the top hit not because it's any better, but simply because it's first', 'if you consistently pick the most expensive option as the default, you'll lose credibility'. 추천을 첫 자리 · 표시와 함께 보이는 방식이 바로 endorsement 경로다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://www.eecs.harvard.edu/~kgajos/papers/2021/bucinca2021trust.shtml"
    supports: both
    claim: "AI 추천의 부작용: Buçinca · Malaya · Gajos (2021, Proc. ACM HCI 5(CSCW1)) — 사람들은 AI 제안이 틀려도 받아들이고('frequently overrely'), 설명을 붙이는 것은 과신을 줄이지 않는 것으로 보이며, 생각을 강제하는 장치는 과신을 줄였으나 'people assigned the least favorable subjective ratings to the designs that reduced the overreliance the most'. Anthropic 공식 글(2026-03-25, https://www.anthropic.com/engineering/claude-code-auto-mode): 사용자는 권한 질문을 'accept 93% of them anyway' 이고 'approval fatigue, where people stop paying close attention to what they're approving'. 대가를 설명 칸에 적는 것만으로 읽힌다고 볼 근거는 약하고, 질문이 잦을수록 덜 읽는다는 쪽의 자료다."
    touches: []
    decides: [OQ4, OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://modelcontextprotocol.io/specification/2025-06-18/client/elicitation"
    supports: alternative
    claim: "에이전트 쪽이 사람에게 입력을 구할 때의 표준 지침(MCP 2025-06-18 elicitation): 'Clients SHOULD present elicitation requests in a way that makes it clear what information is being requested and why', 'provide clear decline and cancel options', 응답은 accept/decline/cancel 셋. 무엇을 왜 묻는지를 요청 화면 자체에서 분명히 하라는 요구다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/obra/superpowers/main/skills/brainstorming/SKILL.md"
    supports: both
    claim: "superpowers brainstorming(upstream main, 파일에 판 표지 없음)은 질문 도구를 이름으로 지정하지 않는다(AskUserQuestion 언급 없음). 물음은 'Ask one at a time', 처음에는 보기 없는 열린 질문('Options steer'), 접근안은 둘셋으로 추려 그리고 'Recommend one and say why, then ask which way they want to go.' 긴 설계는 200–300 단어씩 되읽고 끝마다 무엇이 틀렸거나 빠졌는지 묻는다. 「대가(trade-off)를 함께 적으라」는 글자가 그 파일에 있는지는 요약으로만 읽어 확정하지 못했다. upstream 최신 릴리스는 v7.0.2(2026-11-03)이고 읽은 것은 main 가지라 7.0.0 의 문면과 같은지는 확인하지 못했다."
    touches: []
    decides: [OQ5, OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    version: {used: "superpowers 7.0.0 (plugins/spec-distill/dependencies.md)", latest: "v7.0.2 (2026-11-03)"}
    certainty: uncertain

repo_claims:
  - id: RC1
    path: "plugins/spec-distill/dependencies.md"
    anchor: "| claude-code | 2.1.303 | 2026-10-22 | 기록 | 잰 판을 기록만 한다 |"
    line: 19
    claim: "이 레포가 개발 · 검증 때 깔려 있던 Claude Code 는 2.1.303(잰 날 2026-10-22, 강도 「기록」)이고 superpowers 는 7.0.0 이다. 네 플러그인의 dependencies.md 가 모두 claude-code 2.1.303 을 적는다. 2.1.303 은 mod 가 기본으로 켜진 판(2.1.287) · VS Code 접기 버튼(2.1.261) · VS Code preview(2.1.286) · `skill.prompt` 의 `e.pluginName`(2.1.299) 보다 뒤다."
    touches: []
    decides: []
  - id: RC2
    path: "shared/style/plain-language.md"
    anchor: "질문 하나에 결정 하나. 선택지 이름은 짧은 쉬운 말로, 설명에는 고르면 무엇이 달라지는지만 쓴다."
    line: 6
    claim: "사람에게 쓰는 글의 정본 블록이 이미 선택지 설명의 내용을 정한다(「고르면 무엇이 달라지는지만」). 추천은 「첫 자리 + 라벨 끝 (권장)」이고 그 이유는 「질문 위 글에」 두라고 한다 — 추천 이유의 자리가 질문 창 밖(같은 턴의 앞 글)으로 지정돼 있다. 대가 · 내주는 것을 어디에 적을지는 이 블록에 없다."
    touches: []
    decides: [OQ4, OQ3]
  - id: RC3
    path: "shared/style/plain-language.md"
    anchor: "부른 skill 이 메시지 모양을 정한 대화(예: brainstorming)에서는 그 skill 을 따르고, 이 블록은 낱말에만 적용한다."
    line: 3
    claim: "지금 정본은 brainstorming 같은 바깥 skill 이 메시지 모양을 정한 대화에서는 그 skill 을 따르고 이 블록은 낱말에만 적용한다고 명시해, 그 질문의 모양에는 손대지 않는다."
    touches: []
    decides: [OQ5]
  - id: RC4
    path: "plugins/spec-distill/references/proceed-gate.md"
    anchor: "## Step B — 단일 `AskUserQuestion` / 질문 본문에는 결정 하나와 「경고 N개 — 위에 적었다」"
    line: 44
    claim: "게이트 계약의 정본이 「게이트를 띄우기 전에 판정 결과와 degrade 를 게이트 앞 글에 쓰고, 질문 본문에는 결정 하나와 『경고 N개 — 위에 적었다』(또는 『경고 없음』·『이상 없음』) 한 줄만 둔다」고 정한다(39–45행). 「위에 적었다」는 모델의 즉흥이 아니라 이 규칙이 시킨 문면이고, 내용은 질문과 같은 턴의 앞 글에 실리도록 설계돼 있다."
    touches: []
    decides: [OQ4, OQ1]
  - id: RC5
    path: "shared/docreview/references/reviewing-document.md"
    anchor: "「경고 N개 — 위에 적었다」 한 줄만 둔다."
    line: 31
    claim: "같은 문면이 리뷰 라운드 게이트 여러 곳에 실려 있다: 이 파일 31행, plugins/spec-distill/skills/spec-review/SKILL.md 555 · 661 · 827행, skills/reviewing-brief/SKILL.md 604 · 739행, skills/request-framing/SKILL.md 784 · 1094행, skills/pm-interview/references/finishing.md 499 · 513행. request-framing 의 확정 게이트도 같은 규칙을 따른다. plugins/spec-distill/CHANGELOG.md 699행이 「모든 게이트 … 가 경고 목록을 질문 앞 글에 쓰고, 질문에는 결정 하나와 『경고 N개 — 위에 적었다』 한 줄만 싣는다」로 그 도입을 적는다."
    touches: []
    decides: [OQ1, OQ2, OQ4]
  - id: RC6
    path: "plugins/spec-distill/skills/pm-interview/references/finishing.md"
    anchor: "question: \"신호 셋과 권고를 위에 적었다. 이 일을 어떻게 진행할까?\""
    line: 38
    claim: "리뷰 게이트 밖에도 질문 본문이 「위에 적었다」로 앞 글을 가리키는 고정 템플릿이 있다 — 이 자리(분해 판단)와 plugins/spec-distill/references/redecompose.md 57행(「다시 나눌 표와 영향을 위에 적었다. 어떻게 할까?」). 두 템플릿 모두 선택지마다 description 문자열이 있고 preview 칸은 없다."
    touches: []
    decides: [OQ4, OQ1]
  - id: RC7
    path: "shared/tests/test_ask_recommendation.sh"
    anchor: "# 한계 둘: · 모델이 즉석에서 만드는 질문은 정본 규칙만이 집행한다."
    line: 8
    claim: "질문 모양에 거는 검사가 이미 하나 있다: 모델이 읽는 문서에서 `AskUserQuestion` 이 나온 자리를 전수 도출해 목록(shared/tests/fixtures/ask-sites.tsv)과 대조하고 추천 꼬리 「(권장)」 등 종류별 글자가 범위 안에 있는지 본다(본체 shared/tests/ask_recommendation.py 의 `required()` · `TAIL_RE`). 이 검사는 문서의 글자만 보는 정적 검사이고 스스로 한계를 적는다 — 모델이 즉석에서 만드는 질문은 「정본 규칙만이 집행」하고, 도구 이름 없이 문장으로 묻는 자리는 후보로 뽑히지 않는다. description 칸의 내용이나 「위」 지시는 보지 않는다."
    touches: []
    decides: [OQ3]
  - id: RC8
    path: "plugins/project-init/hooks/hooks.json"
    anchor: "\"PostToolUse\": ["
    line: 4
    claim: "레포의 plugin 훅 설정 가운데 `AskUserQuestion` 이나 `PreToolUse` 를 잡는 것은 없다(plugins/**/hooks/** 에서 두 낱말 0건, hooks.json 에서 이벤트 키가 잡힌 것은 project-init 의 PostToolUse 하나). 실행 시점에 질문 입력을 검사하는 장치는 지금 없다."
    touches: []
    decides: [OQ3]
  - id: RC9
    path: "plugins/spec-distill/agents/integration-reviewer.md"
    anchor: "with a conflict preview, and earlier"
    line: 5
    claim: "plugins 아래 skills · references · agents 의 .md 에서 `preview` 낱말은 이 한 줄(질문과 무관한 문맥)뿐이다. 레포가 쓴 질문 템플릿은 선택지 `preview` 칸을 쓰지 않으므로, 「preview 가 있으면 description 이 안 그려진다」는 upstream 보고(#45384)의 경로는 레포 템플릿에서는 생기지 않는다. 모델이 즉석에서 preview 를 붙인 질문은 이 검색으로 배제하지 못한다."
    touches: []
    decides: [OQ6]

unanswered: "웹(cloud session) · 모바일 표면에서 질문 앞 글이 보이는지에 대한 공식 근거를 찾지 못했고, 어느 표면에서도 실제 화면을 재지 않았다(문서 · issue 만 읽음) — 나머지는 아래 「답하지 못한 것」 목록."
```

## 답하지 못한 것

- **웹 · 모바일 표면.** cloud session 과 모바일에서 질문 앞 글이 보이는지에 대한 공식 문서 · issue 를 찾지 못했습니다.
- **실제 화면 측정.** 어느 표면에서도 화면을 재지 않았습니다. 위 내용은 문서와 issue 에서 읽은 것입니다.
- **도구 설명서 원문.** seed 가 말한 「질문 도구의 설명서에 적힌 말」의 공식 공개본을 찾지 못했습니다. 2차 미러(Piebald-AI, ccVersion 2.1.295)는 본문이 변수 자리표시라 확인이 안 됐습니다.
- **글자 수 상한.** question · label · description 의 글자 수 상한은 공식 문서에 없었습니다(header 12자만 있음).
- **#67426 이 인용한 2.1.152 줄.** 「popup now hides the last line … less intrusively」는 changelog 에서 찾지 못했습니다.
- **Microsoft HAX 지침.** 개별 조항 원문을 확인하지 못해 싣지 않았습니다.

## 본체가 다시 확인할 것

- 이 세션의 모델은 환경 표기상 Fable 계열입니다. #75182 의 직원 판정은 모델 계열에 묶여 있으므로, seed 의 측정(「위」를 가리킨 질문 앞에 글 블록이 0개였던 비율)이 「모델이 안 썼다」인지 「썼는데 글 블록으로 저장되지 않았다」인지는 세션 기록의 thinking 블록 유무로 가를 수 있을 것으로 보입니다. 이번 조사에서는 세션 기록을 열지 않았습니다.

Sources:
- [anthropics/claude-code #75182](https://github.com/anthropics/claude-code/issues/75182)
- [anthropics/claude-code #84409](https://github.com/anthropics/claude-code/issues/84409)
- [anthropics/claude-code #67426](https://github.com/anthropics/claude-code/issues/67426)
- [anthropics/claude-code #66960](https://github.com/anthropics/claude-code/issues/66960)
- [anthropics/claude-code #45384](https://github.com/anthropics/claude-code/issues/45384)
- [anthropics/claude-code #77242](https://github.com/anthropics/claude-code/issues/77242)
- [anthropics/claude-code #95228](https://github.com/anthropics/claude-code/issues/95228)
- [anthropics/claude-code #73629](https://github.com/anthropics/claude-code/issues/73629)
- [anthropics/claude-code #64776](https://github.com/anthropics/claude-code/issues/64776)
- [anthropics/claude-code #67474](https://github.com/anthropics/claude-code/issues/67474)
- [anthropics/claude-code #67113](https://github.com/anthropics/claude-code/issues/67113)
- [anthropics/claude-code #87647](https://github.com/anthropics/claude-code/issues/87647)
- [Claude Code CHANGELOG.md](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
- [Tools reference](https://code.claude.com/docs/en/tools-reference)
- [Handle approvals and user input (Agent SDK)](https://code.claude.com/docs/en/agent-sdk/user-input)
- [Agent SDK TypeScript reference](https://code.claude.com/docs/en/agent-sdk/typescript)
- [Hooks reference](https://code.claude.com/docs/en/hooks)
- [Add components to a plugin](https://code.claude.com/docs/en/plugins/components.md)
- [Plugin manifest reference](https://code.claude.com/docs/en/plugins-reference)
- [Skills](https://code.claude.com/docs/en/skills)
- [Mods overview](https://code.claude.com/docs/en/plugins/mods/overview.md)
- [React to events with a mod](https://code.claude.com/docs/en/plugins/mods/events.md)
- [Draw in the interface with a mod](https://code.claude.com/docs/en/plugins/mods/interface.md)
- [Mods reference](https://code.claude.com/docs/en/plugins/mods/reference.md)
- [Microsoft — Command Links](https://learn.microsoft.com/en-us/windows/win32/uxguide/ctrl-command-links)
- [Microsoft — Dialog Boxes](https://learn.microsoft.com/en-us/windows/win32/uxguide/win-dialog-box)
- [Apple HIG — Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts.md)
- [Nygard — Documenting Architecture Decisions](https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [MADR](https://adr.github.io/madr/)
- [Y-Statement (Design Practice Repository)](https://socadk.github.io/design-practice-repository/artifact-templates/DPR-ArchitecturalDecisionRecordYForm)
- [Jachimowicz et al. 2019](https://collaborate.princeton.edu/en/publications/when-and-why-defaults-influence-decisions-a-meta-analysis-of-defa/)
- [Nielsen — The Power of Defaults](https://www.nngroup.com/articles/the-power-of-defaults/)
- [Buçinca et al. 2021](https://www.eecs.harvard.edu/~kgajos/papers/2021/bucinca2021trust.shtml)
- [Anthropic — Claude Code auto mode](https://www.anthropic.com/engineering/claude-code-auto-mode)
- [MCP spec — Elicitation](https://modelcontextprotocol.io/specification/2025-06-18/client/elicitation)
- [superpowers brainstorming SKILL.md](https://raw.githubusercontent.com/obra/superpowers/main/skills/brainstorming/SKILL.md)
- [superpowers releases](https://github.com/obra/superpowers/releases)
- [Piebald-AI tool-description-askuserquestion.md (2차)](https://raw.githubusercontent.com/Piebald-AI/claude-code-system-prompts/main/system-prompts/tool-description-askuserquestion.md)

### 조사 4 — orchestrator · R1 · 묶음 2

레포 주장 확인(V1) — 조사 2(repo-researcher)의 RC1–RC29 는 번호 그대로, 조사 1(coverage-mapper)의 RC1–RC23 은 RC30–RC52 로, 조사 3(open-researcher)의 RC1–RC9 는 RC53–RC61 로 다시 붙였다.
- 확인 RC1 — 확인 — shared/style/plain-language.md#질문 하나에 결정 하나. 선택지 이름은 짧은 쉬운 말로 — 주장과 일치(6행 전문 대조 · 「대가」 · 「트레이드오프」 낱말 없음)
- 확인 RC2 — 확인 — shared/style/plain-language.md#아래 절차가 출력 형식·원문 보존·분량을 따로 정한 자리에서는 그 절차를 따른다 — 주장과 일치(3행)
- 확인 RC3 — 확인 — shared/tests/plain_language_block.py#def check(root, rel, canon) — check() 는 주장대로 넷만 잰다. 짝 .sh 의 문장 실재 검사는 읽지 않았다
- 확인 RC4 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#· 트레이드오프: <선택지별 한 줄> — 주장과 일치(180 · 190 · 204–205행 · 「트레이드오프」 낱말은 skills · references · shared 에서 이 줄과 리뷰 프로필 정규식 한 줄뿐)
- 확인 RC5 — 확인 — shared/docreview/references/reviewing-document.md#8. **게이트** — 주장과 일치(27–40행 · 이 파일에 description 낱말 0개)
- 확인 RC6 — 확인 — shared/docreview/references/reviewing-document.md#**`AskUserQuestion` 라벨의 항목별 내용** — 주장과 일치(42행 · 86행)
- 확인 RC7 — 확인 — shared/docreview/scripts/docreview_state.py#def _rg_decide(st, g, fid) — 주장과 일치(2310–2315행의 다섯 줄 · _CHOICE_LABEL 2137행 · 추천 줄 없음)
- 확인 RC8 — 확인 — plugins/spec-distill/skills/spec-review/SKILL.md#승인 게이트 질문에는 「경고 N개 — 위에 적었다」 — 555 · 661 · 827–828행 일치. 2단계 옵션 표(688–695행)는 읽지 않았다
- 확인 RC9 — 확인 — plugins/spec-distill/skills/spec-review/SKILL.md#**③ 의 갈래와 로드맵 에픽.** — 702행 「이유는 질문 위 글에 한 줄로 쓴다」 일치. 그 밖 라벨 줄(301 · 635 · 766행)은 읽지 않았다
- 확인 RC10 — 확인 — plugins/spec-distill/skills/reviewing-brief/SKILL.md### 게이트 — 604 · 739–740행 일치
- 확인 RC11 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#B-2 — 497–499 · 513–519 · 536행 일치
- 확인 RC12 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#신호 셋과 권고를 위에 적었다 — 33 · 38행 일치. (b)(c)(d) 의 줄(64 · 266 · 298 · 329 · 402행)은 읽지 않았다
- 확인 RC13 — 확인 — plugins/spec-distill/references/proceed-gate.md### Step B — 단일 `AskUserQuestion` — 주장과 일치(28–60행)
- 확인 RC14 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#### 게이트 — 처분은 사용자가, 편집은 처분 뒤에 — 784 · 934–935 · 1094행 일치. 800 · 1127–1134행은 읽지 않았다
- 확인 RC15 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#### 확인 질문 — 라운드마다 하나 — 246행 일치 · 워크트리 질문 펜스 일치
- 확인 RC16 — 확인 — plugins/spec-distill/references/redecompose.md#다시 나눌 표와 영향을 위에 적었다. 어떻게 할까? — 주장과 일치(57–62행)
- 확인 RC17 — 확인 — plugins/spec-distill/references/conducting.md#### 2. 사람 몫 모으기 — 27 · 40행 일치. 29 · 102–114행은 읽지 않았다
- 확인 RC18 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#지휘자는 배경을 먼저 쉬운 말로 쓰고 질문만 봐도 결정할 수 있게 묻는다 — 32행 · relay-checker.md 34행 일치
- 확인 RC19 — 확인 — shared/tests/ask_recommendation.py#def required(kind, body) — 주장과 일치(109–127행 — 종류별 글자 실재만 본다 · 본문 · 설명 내용은 재지 않는다)
- 확인 RC20 — 확인 — shared/tests/test_ask_recommendation.sh## 한계 둘: — 일치. 목록 줄 수는 wc 로 168
- 확인 RC21 — 확인 — shared/tests/test_docreview_round_gate_split.sh#**이 축의 한계** — 31–34행 일치
- 확인 RC22 — 확인 — plugins/spec-distill/tests/test_plain_gate_templates.sh## ⑬ 질문 본문에는 결정과 상태 한 줄만 — 133 · 150행 일치. test_brief_review_entry.sh 는 읽지 않았다
- 확인 RC23 — 확인 — plugins/spec-distill/tests/test_conducting_interview_stage.sh#고르면 무엇이 달라지는가 — 487 · 498행 일치
- 확인 RC24 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#남은 지적이 있다(<summary>). 어떻게 할까? — 851 · 854 · 861 · 873행 일치
- 확인 RC25 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#**낮춘 지적 게이트 (표면화 뒤 · 라우팅 앞).** — 713–720행 일치. 범위 모드 · 수정 실패 질문은 읽지 않았다
- 확인 RC26 — 미확인 — plugins/quality-gates/references/e2e.md#증거표와 판정안을 보인 뒤 — 102행만 확인했고 §2 시나리오 질문의 설명 규칙(41–57행)은 읽지 않았다
- 확인 RC27 — 미확인 — plugins/quality-gates/skills/artifact-critique/SKILL.md#### E3 — 범위 고르기 · 규모 공시 — 189행(비평자 수 질문의 대가 문장)만 확인했다
- 확인 RC28 — 확인 — plugins/quality-gates/tests/test_plain_qg_templates.sh#grep -c .)" "6" — 51 · 64 · 66 · 167행 일치
- 확인 RC29 — 미확인 — shared/tests/fixtures/ask-sites.tsv## 게이트 · 리뷰 결정 질문 (Task 4) — 여러 자리를 모은 집계 주장이라 자리마다 대조하지 않았다
- 확인 RC30 — 확인 — shared/style/plain-language.md#이유는 질문 위 글에 — 6행 · proceed-gate.md 44행 일치(두 규칙이 같은 통로에 기댄다는 데까지)
- 확인 RC31 — 확인 — docs/superpowers/interview/2026-10-27-askquestion-recommendation-interview.state.md#75182 — 429 · 478 · 485행 · brief 216행 일치
- 확인 RC32 — 확인 — plugins/spec-distill/dependencies.md#| claude-code | 2.1.303 | 2026-10-22 | 기록 | — 19행 일치
- 확인 RC33 — 확인 — plugins/spec-distill/references/proceed-gate.md#질문 본문에는 결정 하나와 「경고 N개 — 위에 적었다」 — 44행과 일곱 자리 일치
- 확인 RC34 — 확인 — shared/docreview/references/reviewing-document.md#렌더 첫 줄(상태와 경고)은 첫 호출 **앞 글**에 한 번 쓴다 — 30 · 42행 일치 · description 낱말 0개
- 확인 RC35 — 확인 — shared/docreview/scripts/docreview_state.py#_rg_decide — 2311–2315행 일치
- 확인 RC36 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#옵션 description 에 싣지 않습니다 — 497 · 38행 일치
- 확인 RC37 — 확인 — shared/tests/test_ask_recommendation.sh#모델이 즉석에서 만드는 질문은 정본 규칙만이 집행한다 — 9행 · ask_recommendation.py required() 일치
- 확인 RC38 — 확인 — plugins/spec-distill/tests/test_plain_gate_templates.sh#질문 본문 — 133행 일치 · 쉬운 말 블록 사본 10개 확인. test_plain_language_block.sh 28–32행은 읽지 않았다
- 확인 RC39 — 확인 — docs/superpowers/interview/2026-10-27-askquestion-recommendation-interview.md#**D16** — 175 · 181 · 195행 일치
- 확인 RC40 — 확인 — docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md### Anti-goals — 47–54 · 59행 · brief 176행(C17) 일치
- 확인 RC41 — 확인 — docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md#«gh-askuserquestion-hides-text» — 289행 일치
- 확인 RC42 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#OQ<n>: <무엇을 정하는지 한 줄> · 추천: — 180 · 190 · 204–205행 일치
- 확인 RC43 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#지휘자는 배경을 먼저 쉬운 말로 쓰고 질문만 봐도 결정할 수 있게 묻는다 — 32행 일치. 29행은 읽지 않았다
- 확인 RC44 — 확인 — shared/style/plain-language.md#부른 skill 이 메시지 모양을 정한 대화(예: brainstorming)에서는 그 skill 을 따르고 — 3행 일치
- 확인 RC45 — 확인 — docs/superpowers/interview/2026-10-27-askquestion-recommendation-interview.md#**D13** — 172 · 173행 일치
- 확인 RC46 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#**다음 세션 줄 — ①/② 공통** — 551 · 553행 일치
- 확인 RC47 — 확인 — plugins/spec-distill/references/conducting.md#brief · 설계 · 계획처럼 방향을 정하는 단계면 특히 그렇다 — 28행 일치(plugins 에서 「방향을 정하는 단계」 1곳 · 「방향을 정하는 자리」 0곳)
- 확인 RC48 — 확인 — shared/tests/fixtures/ask-sites.tsv## 게이트 · 리뷰 결정 질문 (Task 4) — 비움 행 87 · 88 · 91 · 120 · 124행과 request-framing 934 · 939행 · quality-pipeline 720 · 873행 일치
- 확인 RC49 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#이어서 권고 한 줄 — 33 · 536행 · proceed-gate.md 56행 일치. 문장 권고 자리를 모은 목록이 없다는 것은 찾지 못한 것이다
- 확인 RC50 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#재비판이 심각도를 낮춘 지적이 <n>개 있다(위 「낮춘 지적」 절) — 713 · 851 · 861행 일치 · 측정 낱말에 걸리지 않음을 측정 스크립트로 확인
- 확인 RC51 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#### 게이트 — 처분은 사용자가, 편집은 처분 뒤에 — 784 · 1094행 · reviewing-brief 11행 일치. 「리뷰 · 확정 게이트에서 왔을 공산」은 추정 그대로다
- 확인 RC52 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#{label: "만들고 시작 (권장)", description: — plugins 의 .md 에서 preview 를 질문 칸으로 쓰라는 지시를 찾지 못했다 · 세션 기록의 질문 855개 중 preview 칸이 있는 것은 1개
- 확인 RC53 — 확인 — plugins/spec-distill/dependencies.md#| claude-code | 2.1.303 | 2026-10-22 | 기록 | — 네 플러그인의 dependencies.md 모두 2.1.303 · superpowers 7.0.0(17행) 일치
- 확인 RC54 — 확인 — shared/style/plain-language.md#질문 하나에 결정 하나. 선택지 이름은 짧은 쉬운 말로 — 6행 일치(RC1 과 같은 자리)
- 확인 RC55 — 확인 — shared/style/plain-language.md#부른 skill 이 메시지 모양을 정한 대화(예: brainstorming)에서는 — 3행 일치(RC2 와 같은 자리)
- 확인 RC56 — 확인 — plugins/spec-distill/references/proceed-gate.md### Step B — 단일 `AskUserQuestion` — 39–45행 일치
- 확인 RC57 — 확인 — shared/docreview/references/reviewing-document.md#「경고 N개 — 위에 적었다」 한 줄만 둔다. — 열 자리와 CHANGELOG 699행 일치
- 확인 RC58 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#신호 셋과 권고를 위에 적었다 — 38행 · redecompose.md 57행 일치
- 확인 RC59 — 확인 — shared/tests/test_ask_recommendation.sh## 한계 둘: — 8–10행 · required() 일치
- 확인 RC60 — 확인 — plugins/project-init/hooks/hooks.json#"PostToolUse": [ — plugins/*/hooks 에서 AskUserQuestion · PreToolUse 0건 · 이벤트 키는 project-init 의 PostToolUse 하나
- 확인 RC61 — 확인 — plugins/spec-distill/agents/integration-reviewer.md#with a conflict preview, and earlier — plugins 의 .md 에서 preview 낱말은 이 한 줄

웹 주장 확인(본체)
- 웹 조사 3 의 훅 · mod 문서(PreToolUse 가 AskUserQuestion 입력을 본다 · plugin 훅은 세션 전체에 걸린다 · mod 가 질문 창 위에 글을 그릴 수 있다) — 확인 못 함(본체가 다시 확인하지 않음 · OQ3 을 다루는 라운드 전에 1차로 확인한다)
- 웹 조사 3 의 선례(Microsoft command link · Apple HIG alerts · ADR/MADR · 기본값 쏠림 메타분석 · AI 추천 과신 연구 · MCP elicitation) — 확인 못 함(본체가 다시 확인하지 않음)
- 웹 조사 3 의 changelog 줄 · #84409 · #95228 · #73629 · #64776 — 확인 못 함(본체가 다시 확인하지 않음)
- 웹 #75182 — 확인(1차 · GitHub · 2026-11-15) — 열림 · 2026-07-07 · 메인테이너가 2.1.233 에서 재현 · Fable 5 에서 질문 앞 글이 질문 전에도 답한 뒤에도 안 보임 · 저장된 세션 기록에서도 빠짐 · 최근 댓글 2026-11-14(2.1.325) · 우회책 「턴을 글로 끝내라」 [→ OQ7]
- 웹 #45384 — 확인(1차 · GitHub · 2026-11-15) — preview 칸이 있으면 description 이 안 그려진다는 보고 · 메인테이너 답 없이 닫힘 [→ OQ6]
- 웹 질문 도구 형식(질문 1–4 · 선택지 2–4 · 머리글 12자 · label · description · preview) — 확인(본체의 도구 정의) [→ OQ4]
- 웹 brainstorming 의 대가 · 추천 요구 — 확인(깔린 판 superpowers 7.0.2 SKILL.md 162행 「each trades off. Recommend one and say why, then ask which way they want」 · 함께 깔린 7.0.0 사본에는 그 문장이 없고 221행에 tradeoffs 낱말 하나뿐 · 레포가 기록한 판은 7.0.0) [→ OQ5]
- 웹 #67475 · #77242 · #67113 · W3C 인지 접근성 패턴 — 확인 못 함(조사 agent 가 1차로 읽었다고 보고 · 본체가 다시 확인하지 않음)

재측정(본체 · 세션 기록)
- 기록 804개 · 질문 855개(Phase 0 측정의 872 · 827 과 세는 범위가 달라 수가 다르다). 「위」를 가리킨 질문 107개 · 그중 앞 글 0자 65개(Phase 0 측정과 같은 수).
- 모델별: opus 계열 「위」 60개 중 앞 글 0자 42개 · fable 계열 47개 중 23개.
- 앞 글 0자인 질문 앞에는 전부 생각 블록이 있었다 — 기록으로는 「모델이 안 썼다」와 「썼는데 사라졌다」를 가르지 못한다.

### 조사 5 — blind-spot-prober · R2 · 묶음 3

계약(`<claims_contract>`)은 받았다. 아래 주장은 그 계약을 따른다.

## 요지

가장 큰 숨은 가정은 둘이다.

- **「앞 글이 보였다(1회 관찰)」는 일반화되지 않는다.** 공식 이슈 75182의 통제 재현에 따르면 글이 사라지는 꼴은 「도구 호출 → 글 → 질문 도구」다. 앞에 도구 호출이 없으면 12/12로 보였고, 있으면 Opus 5.5 · Sonnet 5.5 · Fable 5.1에서 0/3이었다(2.1.302). 리뷰 게이트는 언제나 `gate --render`(Bash) 뒤에 글을 쓰므로 바로 그 꼴이다.
- **「질문 창 안은 믿을 수 있는 칸」도 확인된 사실이 아니다.** 창 안 글도 잘리거나 안 보인다는 보고가 있다: 아래쪽 선택지 설명 잘림, 테마가 어긋나면 질문 본문이 안 보임, preview가 있으면 설명 칸이 안 그려짐, 기타 칸을 고르면 질문과 선택지가 통째로 사라짐.

그 밖에 눈에 띄는 것:

- 이슈 39867 보고자가 쓴 우회법이 지금 레포 규칙과 같은 꼴이다(자세한 내용은 질문 앞 글에, 라벨 5낱말 이하, 설명 한 문장). 지금 규칙과 기울어 있는 방향은 서로 다른 upstream 버그의 우회로 관계다.
- 경고(degrade 공시)도 같은 「앞 글」 채널에 실린다. 추천 이유와 지적 내용만 옮기면 「경고 N개 — 위에 적었다」는 여전히 사라질 수 있는 글을 가리킨다.
- 정본 블록 한 줄(D16)만 뒤집으면 지역 규칙과 락이 이겨 리뷰 게이트는 그대로다. 지난 설계가 Context에 적은 실패와 같다.
- 지난 세션 기록은 도구 입력을 담을 뿐 화면을 담지 않는다. OQ6과 OQ11을 기록 측정에 기대면 화면과 어긋난다.

```yaml
hidden_assumptions:
  - assumption: "지금 화면에서는 질문 앞 글이 보인다(1회 관찰) — 앞 글 소실은 간헐적이거나 특정 모델의 문제다"
    why_risky: "통제 재현에서 소실은 턴의 꼴에 달려 있었다. 「도구 호출 → 보고 글 → 질문 도구」 꼴이면 Opus 5.5 · Sonnet 5.5 · Fable 5.1 에서 0/3 이고, 보고 글 앞에 도구 호출이 없으면 네 모델 12/12 로 글이 나왔다. 리뷰 게이트는 gate --render(Bash) 뒤에 앞 글을 쓰고 질문을 띄우므로 실패 꼴이다. 1회 관찰이 대조군 꼴(앞에 도구 호출 없음)이었다면 OQ7 을 「앞 글에 기대도 된다」로 닫는 근거가 못 된다. 재현 판은 2.1.284–2.1.325 로, framing 이 적은 레포 기록 판 2.1.303 을 사이에 둔다. 메인테이너의 마지막 댓글은 2026-08-16 이고 고친 판은 없다."
    evidence:
      - url: "https://github.com/anthropics/claude-code/issues/75182"
        supports: alternative
        claim: "열림 · reproduced 라벨. 재현 꼴은 ls → 두 문단 보고 → AskUserQuestion. 2.1.302 에서 opus-5-5 0/3 · sonnet-5-5 0/3 · fable-5-1 0/3 · haiku-5-5 3/3. 도구 호출이 앞에 없으면 12/12 로 text 블록이 나온다. 2.1.284 · 296 · 300 · 302 · 310 · 317 · 325 에서 재현 보고. 메인테이너: 모델의 사용자용 글이 CLI 가 숨은 추론으로 다루는 꼴로 도착한다, 고칠 자리(모델/API 쪽인지 클라이언트인지)는 미정. 실사용 보고는 「하루에 여러 번」. 믿을 만한 우회는 글로 턴을 끝내고 다음 턴에 묻는 것뿐이라는 보고(2026-11-14)."
        touches: []
        decides: [OQ7, OQ8]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: confirmed
      - url: "https://github.com/anthropics/claude-code/issues/67426"
        supports: alternative
        claim: "같은 꼴의 턴에서도 어떤 글은 보이고 어떤 글은 삼켜진다는 네 번 실행 표(2.1.173, 보고자는 비결정적이라 봄). 긴 글은 빠지고 도구 호출 뒤의 한 줄짜리 글은 보인 사례가 있다. 봇이 not planned 로 닫았고 메인테이너 답은 없다. 보고자의 우회는 맥락을 파일에 쓰고 경로를 question 칸에 넣는 것이었다."
        touches: []
        decides: [OQ7]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: uncertain

  - assumption: "질문 창 안(본문 · 선택지 설명)에 실으면 사용자가 그 글을 본다 — 창 안은 앞 글보다 믿을 수 있는 칸이다"
    why_risky: "창 안 글에도 표시 실패 보고가 여럿이다. 선택지 3–4개에 설명이 2줄 이상이면 아래쪽 선택지 설명이 잘리고 스크롤이 없다. 테마와 터미널 배경이 어긋나면 질문 본문이 안 보인다. preview 가 있으면 설명 칸이 그려지지 않는다. 방향이 설명 칸에 얻음 · 내줌과 지적 내용을 실으면 바로 그 조건(설명 여러 줄 × 선택지 여럿)을 만든다. 이 이슈들은 대부분 봇이 닫아 지금 판에서 고쳐졌는지 알 수 없다. 창 안이 지금 판에서 얼마까지 그려지는지 재지 않고 칸 배치(OQ4)를 정하면 「위에 아무것도 없음」이 「아래가 잘림」으로 바뀔 뿐이다."
    evidence:
      - url: "https://github.com/anthropics/claude-code/issues/39867"
        supports: current
        claim: "터미널 CLI 에서 선택지 3–4개에 설명이 2줄 이상이면 목록 아래쪽 선택지 설명이 잘리고 컴포넌트 안 스크롤이 없다. 보고자의 우회는 자세한 정보를 질문 호출 앞의 일반 글로 내고 라벨은 5낱말 이하, 설명은 짧은 한 문장으로 하는 것이다(지금 레포 규칙과 같은 꼴). 2026-04-27 봇이 not planned 로 닫았고 수정 언급은 없다."
        touches: []
        decides: [OQ4, OQ7]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: uncertain
      - url: "https://github.com/anthropics/claude-code/issues/29125"
        supports: current
        claim: "2.1.59 · 80x24 터미널에서 긴 선택지 설명이 문장 중간에 잘리고 펼칠 방법이 없다. 보고자 진단: 대화창의 고정 렌더 영역이 긴 설명을 담지 못하며, 그런 설명은 Claude 가 기술 선택지를 트레이드오프 설명과 함께 낼 때 흔하다. 중복으로 자동 종결됐고 수정 판 언급은 없다."
        touches: []
        decides: [OQ4]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: uncertain
      - url: "https://github.com/anthropics/claude-code/issues/67113"
        supports: both
        claim: "터미널 CLI(Fable 5)에서 긴 질문 · 선택지 설명 · preview 가 줄바꿈 없이 대화창 가장자리에서 잘린다는 보고. 2026-06-16 completed 로 닫혔지만 수정 판 · 커밋은 페이지에 없다. 고쳐졌을 수 있으나 확인되지 않았다."
        touches: []
        decides: [OQ4]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: uncertain
      - url: "https://github.com/anthropics/claude-code/issues/77242"
        supports: current
        claim: "열림(2.1.207 · 2.1.234). 머리글과 선택지는 그려지는데 question 글이 안 보인다. 보고자 진단은 테마 dark + 밝은 터미널 배경에서 글자색 대비가 1.04:1 이라는 것. 메인테이너는 Linux 에서 재현하지 못했다. 큰 출력 뒤에 간헐적으로 생기고 Ctrl+L 로 돌아온다는 별도 보고도 같은 스레드에 있다."
        touches: []
        decides: [OQ4, OQ6]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: uncertain
      - url: "https://github.com/anthropics/claude-code/issues/45384"
        supports: current
        claim: "선택지에 preview 칸이 있으면 description 이 그려지지 않고 label 과 preview 만 나온다(2026-04, 봇이 not planned 로 닫음, 수정 언급 없음). 지적 내용을 preview 칸으로 옮기는 안은 설명 칸을 지운다."
        touches: []
        decides: [OQ4, OQ6]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: uncertain

  - assumption: "지난 세션 기록에 남은 것이 사용자가 본 화면이다 — 「설명 칸이 빈 질문 0개」는 사용자가 설명을 봤다는 뜻이다"
    why_risky: "기록은 도구 입력(question · description)을 담고 화면에 그려진 결과는 담지 않는다. 설명 칸에 글자가 있어도 아래쪽이 잘렸거나 본문이 안 보였을 수 있다. 반대로 앞 글은 기록에 text 블록 자체가 없어 「썼는데 사라짐」을 기록으로 셀 수 없다. 「설명 칸이 없던 화면」(OQ6)을 기록에서 찾으려는 시도와 「고쳐졌는지」(OQ11)를 기록 재측정으로 확인하려는 시도는 둘 다 화면과 어긋날 수 있다."
    evidence:
      - url: "https://github.com/anthropics/claude-code/issues/75182"
        supports: alternative
        claim: "실패한 턴의 기록은 tool_use → thinking → thinking → tool_use 이고 text 블록이 없다. jsonl 에는 약 200자 요약의 thinking 블록만 남고 전문은 없다. AskUserQuestion 의 PreToolUse 훅으로 앞 글 길이를 재려던 우회는 돌고 있는 턴의 항목을 못 봐 0 으로 세고 전부 통과시켰다는 보고가 있다."
        touches: []
        decides: [OQ6, OQ11]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: confirmed

  - assumption: "추천 옆에 대가(내줌)를 적으면 사용자가 더 잘 고른다 — 그리고 모델이 적는 대가는 실제 대가다"
    why_risky: "사람–AI 결정 연구에서 설명은 AI 권고의 수용을 정답 여부와 무관하게 늘렸고 과의존을 줄이지 못했다. 대가를 적는 쪽은 그 추천을 낸 모델이라, 형식(「내줌: …」)은 채워져도 내용이 추천을 위협하지 않는 가벼운 대가로 채워질 수 있다. 그러면 화면은 「대가까지 따져 본 추천」으로 보여 추천의 무게만 는다. 사용자가 이미 「좀 기네」라고 했으므로 줄일 때 먼저 깎이는 쪽도 내줌일 공산이 크다. 추천을 일부러 비운 자리(저자 편집 덩어리 등)에서는 얻음 · 내줌 서술이 추천을 대신하는 통로가 된다(OQ9)."
    evidence:
      - url: "https://arxiv.org/abs/2006.14779"
        supports: current
        claim: "Bansal 외(CHI 2021): 설명은 상보적 팀 성능을 올리지 못했고, 사람이 AI 권고를 정답 여부와 무관하게 받아들일 확률을 올렸다."
        touches: []
        decides: [OQ9, OQ11]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: confirmed
      - url: "https://arxiv.org/abs/2102.09692v1"
        supports: current
        claim: "Buçinca 외(2021, N=199): AI 결정에 설명을 붙여도 과의존은 줄지 않았다. 과의존을 줄인 것은 먼저 스스로 판단하게 하는 장치였는데, 참가자는 그 장치를 가장 낮게 평가했다. (검색 요약으로 확인했고 원문 전문은 읽지 않았다.)"
        touches: []
        decides: [OQ3, OQ9]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: uncertain

  - assumption: "질문 창 안으로 옮길 것은 추천의 이유 · 대가와 지적 내용이다 — 경고(degrade 공시) 목록은 지금처럼 앞 글에 남아도 된다"
    why_risky: "게이트 정본은 degrade 를 하나도 빠뜨리지 않고 게이트 앞 글에 쓰라고 하고, 질문에는 개수 한 줄만 둔다. 앞 글이 사라지는 턴에서는 이 공시 의무가 화면에서 통째로 깨진다(「경고 4개 — 위에 적었다」만 남는다). 사용자가 본 「위를 보라는데 위에 아무것도 없음」의 직접 대상이 바로 이 경고 줄이다. 추천 이유와 지적 내용만 창 안으로 옮기면 가리키는 문구는 그대로 남는다. 반대로 경고까지 옮기려 하면 레포가 그것을 금지 문장과 부재 락으로 막아 둔 자리와 정면으로 부딪친다(repo_claims RC4 · RC5)."
    evidence:
      - url: "https://github.com/anthropics/claude-code/issues/75182"
        supports: alternative
        claim: "같은 턴의 질문 도구 앞 글은 질문 전에도 답한 뒤에도 표시되지 않고 기록에도 없다. 앞 글에만 실린 공시는 사용자에게 닿지 않는다."
        touches: []
        decides: [OQ4, OQ7]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: confirmed

  - assumption: "범위 밖으로 뺀 자리(외부 skill 의 설계 · 계획 대화, 코드 리뷰)는 이 변경과 독립이다"
    why_risky: "두 방향으로 샌다. (1) 공통 글쓰기 블록은 quality-gates 의 SKILL 둘을 포함한 SKILL.md 10개에 같은 바이트로 복제된다. 「이유는 질문 위 글에」 한 줄을 고치면 범위 밖 skill 의 규칙도 함께 바뀌고, 그 skill 의 지역 게이트 문구(질문 밖 글을 가리킴)와 어긋난다. (2) 사용자의 첫 요청은 「전반적으로」였고 대상은 「인터뷰 · 설계 · 계획」이다. 설계 대화를 맡은 외부 skill 은 추천과 이유를 문장으로 내라고만 하고 질문 도구는 정하지 않는다. 모델이 그 뒤에 질문 도구를 붙이면 같은 소실이 난다. 고친 뒤에도 사용자가 체감하는 화면의 큰 몫이 그대로일 수 있어, 「고쳐졌는지」를 체감으로 확인하면 실패로 읽힌다."
    evidence:
      - url: "https://raw.githubusercontent.com/obra/superpowers/main/skills/brainstorming/SKILL.md"
        supports: both
        claim: "brainstorming skill 은 「Recommend one and say why, then ask which way they want to go」 「Ask one at a time」으로 추천과 이유를 문장으로 내게 한다. AskUserQuestion 등 질문 도구는 이름조차 나오지 않는다. 대가를 질문 창 안에 싣는 규칙은 이 표면에 없다."
        touches: []
        decides: [OQ11]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: confirmed
      - url: "https://github.com/anthropics/claude-code/issues/77242"
        supports: current
        claim: "같은 스레드에 superpowers brainstorming 을 쓰는 중에 질문 글이 안 보였다는 사용자 보고(2026-08-18)가 있다. 외부 skill 의 대화도 같은 화면 결함을 겪는다."
        touches: []
        decides: [OQ11]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: uncertain

failure_modes:
  - mode: "설명 칸에 얻음 · 내줌과 지적 내용을 실은 뒤 아래쪽 선택지의 설명이 잘린다 — 「위에 아무것도 없음」이 「아래가 안 보임」으로 바뀐다"
    trigger: "선택지 3–4개 × 설명 2줄 이상, 표준 높이(예: 80x24) 터미널, 한 호출에 질문 4개를 묶는 리뷰 라운드 게이트. 엔진이 내는 「그대로 두면 · 고치면」 줄에는 길이 상한이 없다(RC2)."
    evidence:
      - url: "https://github.com/anthropics/claude-code/issues/39867"
        supports: current
        claim: "3–4개 선택지에 설명이 2줄 이상이면 아래쪽 설명이 잘리고 스크롤이 없다."
        touches: []
        decides: [OQ4, OQ7]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: uncertain
      - url: "https://github.com/anthropics/claude-code/issues/89644"
        supports: both
        claim: "질문 창이 화면을 다 차지해 위 설명을 못 보고 선택지 요약만으로 답해 나쁜 결정을 한다는 보고. 보고자의 우회(맥락을 선택지 안에 반복)는 「창을 부풀리고 토큰을 더 쓴다」. 문제는 실재하고, 창 안으로 옮기는 길에도 비용이 있다. 봇이 not planned 로 닫았다."
        touches: []
        decides: [OQ4, OQ7]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: confirmed

  - mode: "사용자가 선택지 대신 기타 칸(자유 입력 · 논의)을 고르면 질문과 선택지 설명이 화면과 기록에서 사라진다 — 앞 글을 비운 설계에서는 논의할 근거가 화면에 하나도 남지 않는다"
    trigger: "이유 · 대가 · 지적 내용을 질문 창 안에만 싣고 앞 글을 줄인 상태에서 사용자가 「잘 모르겠다, 얘기하자」 쪽으로 간다. 설명이 부족하다고 느낀 사용자일수록 이 길로 간다. 레포는 기타 칸에 「여기서 계속」 · 기각 번호 되돌리기 같은 갈래를 이미 걸어 두었다(RC11)."
    evidence:
      - url: "https://github.com/anthropics/claude-code/issues/88494"
        supports: current
        claim: "2.1.231: 마지막 항목(자유 입력 / chat about this)을 고르면 질문 글 · 모든 라벨 · 모든 설명이 대화 화면에서 사라지고 기록에도 없으며 스크롤로도 못 돌아간다. 다른 답은 기록이 남는다. 봇이 not planned 로 닫았고 메인테이너 답은 없다."
        touches: []
        decides: [OQ4, OQ7]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: uncertain

  - mode: "정본 블록의 한 줄(「이유는 질문 위 글에」, D16)만 뒤집고 끝낸다 — 리뷰 게이트의 화면은 그대로다"
    trigger: "공통 블록 3행이 「절차가 출력 형식을 따로 정한 자리에서는 그 절차를 따른다」로 지역 규칙에 우선권을 주고, 지역 규칙(「질문 본문에는 결정 하나와 한 줄만」)은 양의 락과 부재 락으로 잠겨 있다. 지난 설계가 Context 에 적은 실패(지역 규칙과 락이 정본을 이겼다)와 같은 꼴이다. 반대로 지역 규칙만 고치면 정본 블록과 모순이 남고, 범위 밖 skill 의 블록도 같은 바이트라 함께 흔들린다."
    evidence: []

  - mode: "「얻음: … · 내줌: …」이 형식 채우기로 퇴화한다 — 검사는 낱말의 존재만 재고, 길이 압박에서 내줌이 먼저 얇아진다"
    trigger: "규칙 문장 또는 정적 검사(OQ3)가 형식만 요구하고, 실행 중 질문의 설명 칸 내용은 어떤 검사도 보지 못한다(RC10). 추천을 낸 모델이 자기 추천의 대가를 적는다. 사용자는 이미 지금 형식이 길다고 했다."
    evidence:
      - url: "https://arxiv.org/abs/2006.14779"
        supports: current
        claim: "설명은 내용의 옳고 그름과 무관하게 권고 수용을 올린다. 얇은 대가 줄도 「따져 본 추천」처럼 작동한다."
        touches: []
        decides: [OQ3, OQ11]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: confirmed

  - mode: "모델이 엔진의 지적 줄을 질문 창 예산에 맞춰 줄이면서 뜻이 달라진다 — 사용자는 요약에 답하고 원장은 원문에 처분을 적는다"
    trigger: "지적의 「그대로 두면 · 고치면」을 질문 본문 · 설명에 넣는데 원문이 길거나 「(리뷰어가 안 적음)」 · 「(대체안 미작성)」 자리표일 때. 공통 규칙은 스크립트 · subagent 원문을 고치지 말라고 하고(RC3), 라벨 규칙은 이미 1–5 낱말 압축을 요구한다(RC1). 원문 그대로면 잘림(위 실패 양식), 줄이면 원문 보존 규칙과 충돌한다."
    evidence:
      - url: "https://github.com/anthropics/claude-code/issues/89644"
        supports: current
        claim: "보고자: 선택지 요약만 보고 답해 전체 맥락 없이 최선이 아닌 결정을 내리곤 한다. 요약이 결정의 유일한 입력이 되면 요약의 손실이 곧 결정의 손실이다."
        touches: []
        decides: [OQ4, OQ9]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: confirmed

  - mode: "「고쳐졌는지」를 지난 세션 기록 재측정이나 훅으로 확인한다 — 수치는 좋아지는데 화면은 확인되지 않는다"
    trigger: "OQ11 을 「위를 가리키는 질문 수 · 앞 글 0자 수 · 설명 칸 길이」 같은 기록 지표로 정한다. 기록은 도구 입력이지 렌더 결과가 아니다. 사라진 앞 글은 기록에 없어 분모와 분자가 모두 틀린다. 질문 도구에 거는 훅은 돌고 있는 턴의 글을 못 본다(지난 설계의 Anti-goal 이기도 하다, RC9)."
    evidence:
      - url: "https://github.com/anthropics/claude-code/issues/75182"
        supports: current
        claim: "실패한 턴의 기록에 text 블록이 없다. transcript_path 를 읽는 PreToolUse 훅은 돌고 있는 턴의 항목을 못 봐 0자로 세고 전부 통과시켰다."
        touches: []
        decides: [OQ11, OQ3]
        source_kind: primary
        checked_at: "2026-11-15"
        certainty: confirmed

  - mode: "지휘 세션이 옮기는 질문에서 이유를 설명 칸에 넣으면 옮김 대조자가 그것을 어긋남으로 잡는다"
    trigger: "「추천 이유는 질문 창 안에」를 정본으로 정했는데 relay-checker 의 4번 규칙(지휘자 의견은 선택지 밖 한 줄)과 그 락은 그대로일 때. 지난 인터뷰 premortem 이 라벨 꼬리에 대해 예보한 것과 같은 충돌이 설명 칸에서 되풀이된다(RC6)."
    evidence: []

confidence: 0.78

repo_claims:
  - id: RC1
    path: "shared/docreview/references/reviewing-document.md"
    anchor: "렌더의 「고치면」 줄이 전문을 이미 내므로 라벨은 그 줄을 가리키는 손잡이다"
    line: 42
    claim: "라벨 규칙의 근거 문장은 「렌더 줄이 전문을 낸다」를 전제로 라벨을 1–5 낱말 손잡이로 줄인다. 그런데 같은 절차의 8단계(27–31행)가 앞 글에 쓰라고 정한 것은 「렌더 첫 줄(상태와 경고)」뿐이다. 읽은 구간(27–42행) 안에는 지적별 「그대로 두면 · 고치면」 줄을 사용자에게 보이는 글로 옮기라는 지시가 없다. 버그가 없어도 손잡이가 가리키는 전문은 규칙상 사용자 글에 실릴 자리가 없다."
    touches: []
    decides: [OQ4, OQ7]
  - id: RC2
    path: "shared/docreview/scripts/docreview_state.py"
    anchor: "def _rg_decide / def _one"
    line: 2311
    claim: "`_rg_decide` 는 리뷰어가 칸을 비우면 「(리뷰어가 안 적음)」 · 「(대체안 미작성)」 자리표를 그대로 낸다(2311–2312행). `_one`(2223–2225행)은 공백만 접고 길이는 자르지 않는다. 이 줄을 질문 창에 그대로 실으면 길이 상한 없는 리뷰어 글이나 자리표가 질문 본문이 된다."
    touches: []
    decides: [OQ4, OQ9]
  - id: RC3
    path: "shared/style/plain-language.md"
    anchor: "스크립트·subagent 가 낸 원문은 고치지 않는다"
    line: 9
    claim: "공통 블록은 스크립트 · subagent 원문을 고치지 말라고 하고(9행), 설명에는 「고르면 무엇이 달라지는지만」 쓰라고 한다(6행). 3행은 「절차가 출력 형식 · 원문 보존 · 분량을 따로 정한 자리에서는 그 절차를 따른다」로 지역 규칙에 우선권을 준다. 지적 줄을 창 안에 맞게 줄이는 일은 9행과 부딪치고, 6행의 「만」은 대가 · 이유 서술과 부딪친다. 블록만 고쳐도 지역 규칙이 이긴다."
    touches: []
    decides: [OQ3, OQ4, OQ8]
  - id: RC4
    path: "plugins/spec-distill/tests/test_plain_gate_templates.sh"
    anchor: "⑬ 질문 본문에는 결정과 상태 한 줄만 — 자리마다 그 문장"
    line: 143
    claim: "양의 락(133–142행: 여섯 파일에서 「질문 본문에는 결정 하나와 … 한 줄만」 문장이 정확히 1번)에 더해 부재 락이 있다(143–147행: 여섯 파일 어디에도 「질문…한 줄씩 / 한 줄씩…질문」 꼴 문장이 0번이어야 한다). 경고를 질문 안에 한 줄씩 싣는 규칙 문장을 쓰면 문구에 따라 이 부재 락이 RED 가 된다. 100–113행은 같은 문장의 인접 순서까지 잠근다."
    touches: []
    decides: [OQ3, OQ4]
  - id: RC5
    path: "plugins/spec-distill/skills/pm-interview/references/finishing.md"
    anchor: "모든 degrade record 는 **게이트 앞 글**(위 목록 4)에 한 줄씩 씁니다 — 옵션 description 에 싣지 않습니다."
    line: 497
    claim: "인터뷰 끝 게이트는 경고를 선택지 설명에 싣는 것을 명문으로 금하고, test_plain_gate_templates.sh ⑭(149–151행)가 그 문장을 정확히 1번으로 잠근다. 「질문 창 안에 싣는다」가 경고에도 닿으면 이 금지를 뒤집는 재결정이 필요하다."
    touches: []
    decides: [OQ4, OQ7]
  - id: RC6
    path: "plugins/spec-distill/agents/relay-checker.md"
    anchor: "지휘자 의견이 선택지 설명 안으로 들어갔으면 어긋남이다(「지휘자 의견:」 은 선택지 밖 한 줄이다)"
    line: 34
    claim: "옮김 대조자는 지휘자의 권장 이유가 선택지 설명 칸에 들어간 것을 어긋남으로 판정한다(34 · 37행). 이유를 설명 칸으로 옮기는 규칙은 지휘 세션이 옮기는 질문에서 이 persona 와 충돌한다. persona 편집은 CLAUDE.md 가 보안 리뷰 대상으로 정한 자리다."
    touches: []
    decides: [OQ4, OQ8]
  - id: RC7
    path: "plugins/spec-distill/skills/request-framing/SKILL.md"
    anchor: "덩어리 본문(`render`)은 질문 텍스트에 줄임 없이 싣는다 — 분량 상한을 두지 않는다"
    line: 935
    claim: "레포에는 「질문 본문엔 결정과 상태 한 줄만」의 명문 예외가 이미 하나 있다. 저자 편집 덩어리는 질문 글에 분량 상한 없이 싣는다(935행). 같은 자리는 추천을 일부러 비운다(934 · 939행: 저자의 권장은 저자가 자기 편집을 승인하는 것이다). 긴 본문을 질문 창에 실은 실제 사례가 있어 창 안이 얼마까지 그려지는지 확인할 수 있는 자리다. 추천 없는 질문에 얻음 · 내줌을 의무화하면 이 자리에서 저자가 서술로 가름을 하게 된다."
    touches: []
    decides: [OQ4, OQ9]
  - id: RC8
    path: "shared/tests/plain_language_block.py"
    anchor: "블록 바이트가 정본(%s)과 다르다"
    line: 52
    claim: "공통 블록은 SKILL.md 마다 정본과 바이트가 같아야 한다. `plain-language:begin` 표지를 가진 SKILL.md 는 10개이고 그중 둘이 quality-gates(quality-pipeline · artifact-critique), 하나씩이 plugin-audit · project-init 이다. 블록의 「이유는 질문 위 글에」를 고치면 이번 범위에서 뺀 코드 리뷰 skill 의 규칙도 같은 커밋에서 바뀐다."
    touches: []
    decides: [OQ8, OQ3]
  - id: RC9
    path: "docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md"
    anchor: "## Anti-goals"
    line: 47
    claim: "지난 설계의 Anti-goals(51–54행)는 질문 도구 호출에 끼어드는 훅 · 래퍼, 복제 블록을 눈에 띄게 늘리는 것, 엔진 라벨 코드 변경을 실패로 정했다. AC3(178행)는 블록 변경이 skill 앞부분 토큰 경계에서 `## ` 절을 새로 밀어내지 않는지를 잰다고 적는다. Context 28행은 「지역 규칙과 그 문면을 잠근 테스트가 이겼다」를 지난 실패의 원인으로 적는다. 얻음 · 내줌 규칙을 블록에 더하는 길과 실행 중 검사를 두는 길은 둘 다 확정된 금지에 닿는다. (token_boundary.py 구현은 읽지 않았다. 설계문서의 문면만 확인했다.)"
    touches: []
    decides: [OQ3, OQ8]
  - id: RC10
    path: "shared/tests/test_ask_recommendation.sh"
    anchor: "한계 둘"
    line: 8
    claim: "전수 검사는 스스로 한계를 적는다: 모델이 즉석에서 만드는 질문은 정본 규칙만이 집행하고, 도구 이름 없이 문장으로만 묻는 자리는 후보로 뽑히지 않는다(8–10행). 후보 줄은 문서 속 `AskUserQuestion` 글자로만 도출한다(37행). 질문 밖 「권하는 글」에는 그런 도출 열쇠가 되는 글자가 없어 이 검사 방식으로는 자리를 열거할 수 없다. 설명 칸의 실제 내용(대가가 적혔는지)도 재지 못한다."
    touches: []
    decides: [OQ3, OQ10, OQ11]
  - id: RC11
    path: "plugins/spec-distill/references/proceed-gate.md"
    anchor: "## Step B — 단일 `AskUserQuestion`"
    line: 39
    claim: "게이트 정본은 degrade 를 「하나도 빠뜨리지 않고 게이트 앞 글에」 쓰라고 하고(39–45행), 「감추지 않는다」가 이 계약이 정하는 유일한 의무라고 적는다(47–50행). 이 의무의 유일한 운반 채널이 앞 글이다. 같은 절 58행은 기타 칸에 「여기서 계속」 갈래를 걸어 둔다. 기타 칸은 실제로 쓰이는 길이다."
    touches: []
    decides: [OQ4, OQ7]
  - id: RC12
    path: "plugins/spec-distill/CHANGELOG.md"
    anchor: "## [5.1.0] — 2026-10-09"
    line: 699
    claim: "「경고 목록은 질문 앞 글에, 질문에는 결정 하나와 한 줄만」은 5.1.0(2026-10-09)에서 모든 게이트에 일부러 들인 변경이다. 이 항목은 무엇을 바꿨는지만 적고 왜 질문 안에서 뺐는지는 적지 않는다. 그 이유(예: 질문 넷에 같은 경고가 되풀이됨, 창 안 잘림)를 찾지 않고 되돌리면 그때 고친 문제가 돌아올 수 있다. 이유를 적은 자리는 이번 조사에서 찾지 않았다."
    touches: []
    decides: [OQ4, OQ7]
```

## 확인하지 못한 것

- `claudeissues.com` 은 가져오지 못했다(DNS 실패). 같은 이슈를 `github.com/anthropics/claude-code/issues/<번호>` 로 직접 읽었다.
- 창 안 잘림 계열(#39867 · #29125 · #45384 · #88494 · #89644)은 모두 봇이 비활성으로 닫았다. 닫힘이 수정을 뜻하지 않고, 지금 판에서 고쳐졌는지는 어느 페이지로도 확인되지 않았다. #67113 만 사람이 completed 로 닫았지만 수정 판은 적혀 있지 않다. 이 실패 양식들은 실재 여부를 이 레포가 쓰는 판에서 한 번 재야 확정된다.
- Buçinca 외 논문은 검색 요약으로만 확인했다. Bansal 외는 초록을 직접 읽었다.
- 레포 쪽: reviewing-document.md 는 1–60행, proceed-gate.md 는 전문, relay-checker.md 는 전문, test_plain_gate_templates.sh 는 95–156행, docreview_state.py 는 `_rg_decide` · `_one` 주변만 읽었다. finishing.md 497행과 plain_language_block.py 52행은 grep 이 낸 줄로만 확인했다. token_boundary.py 와 CHANGELOG 5.1.0 의 배경 설계는 읽지 않았다.
- 전제 번호(P<n>)를 받지 못해 `touches` 는 전부 빈 배열이다.

## 읽은 레포 파일

- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/docreview/references/reviewing-document.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/docreview/scripts/docreview_state.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/style/plain-language.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/tests/test_ask_recommendation.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/tests/plain_language_block.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/references/proceed-gate.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/agents/relay-checker.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/tests/test_plain_gate_templates.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/skills/request-framing/SKILL.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/skills/spec-review/SKILL.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/skills/pm-interview/references/finishing.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/CHANGELOG.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/docs/superpowers/interview/2026-10-27-askquestion-recommendation-interview.state.md

Sources:
- [anthropics/claude-code #75182](https://github.com/anthropics/claude-code/issues/75182)
- [anthropics/claude-code #67426](https://github.com/anthropics/claude-code/issues/67426)
- [anthropics/claude-code #39867](https://github.com/anthropics/claude-code/issues/39867)
- [anthropics/claude-code #29125](https://github.com/anthropics/claude-code/issues/29125)
- [anthropics/claude-code #67113](https://github.com/anthropics/claude-code/issues/67113)
- [anthropics/claude-code #77242](https://github.com/anthropics/claude-code/issues/77242)
- [anthropics/claude-code #45384](https://github.com/anthropics/claude-code/issues/45384)
- [anthropics/claude-code #88494](https://github.com/anthropics/claude-code/issues/88494)
- [anthropics/claude-code #89644](https://github.com/anthropics/claude-code/issues/89644)
- [anthropics/claude-code #87647](https://github.com/anthropics/claude-code/issues/87647)
- [obra/superpowers brainstorming SKILL.md](https://raw.githubusercontent.com/obra/superpowers/main/skills/brainstorming/SKILL.md)
- [Bansal et al., Does the Whole Exceed its Parts? (arXiv 2006.14779)](https://arxiv.org/abs/2006.14779)
- [Buçinca et al., To Trust or to Think (arXiv 2102.09692)](https://arxiv.org/abs/2102.09692v1)

### 조사 6 — steelman-builder · R2 · 묶음 4

전제 반증은 없고 추천은 `refined` 입니다. 계약(`<claims_contract>`)을 받아 그 형식대로 냈고, `RC<n>` 은 임시 번호입니다. 레포 경로는 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/` 기준 상대경로입니다. `supports` 의 `current` 는 의심 방향(질문 창 안으로 옮김), `alternative` 는 아래 대안(이중 통로)입니다.

```yaml
case_for_alternative:
  statement: "질문 창 안에는 고르는 데 필요한 한 줄들만 요약으로 싣고, 질문 앞 글은 버리지 않고 전문(추천 이유의 풀이 · 리뷰 지적의 원문 · 경고 목록)을 싣는 둘째 통로로 의무로 남긴다 — 옮기지 않고 겹쳐 쓴다."
  strongest: >-
    질문 창도 사라지거나 잘리는 통로다. 선택지는 보이는데 질문 문장만 안 보이는 버그가 열려 있고(#77242),
    긴 선택지 설명이 문장 중간에서 잘린다는 보고는 바로 「trade-off 설명이 붙은 기술 선택지」에서 나왔으며(#29125),
    긴 질문 · 설명이 창 가장자리에서 잘려 「나머지는 사라진다」는 보고는 고친 판 표기 없이 완료 처리됐다(#67113).
    한 통로로 옮기면 실패 지점이 하나가 되고, 겹쳐 쓰면 둘 중 하나만 살아도 사용자가 읽는다 — 앞 글은 기본 Opus 에서
    정상으로 그려졌고(메인테이너 재현) 이 인터뷰의 화면 확인(S2)에서도 보였다.
    바깥 지침의 상한(설명은 세 줄 이내 · 선택에 영향 없는 세부는 뺀다 · 「over-communicate 하지 마라」)은 창 안에 실을 수 있는
    양을 묶는다. 리뷰 엔진의 「그대로 두면 · 고치면」 줄에는 길이 상한이 없어(RC4) 창에는 줄인 글만 들어가고,
    줄이지 않은 원문과 경고 목록이 설 자리는 앞 글뿐이다.
    인터뷰의 «추천 · 트레이드오프» 줄은 화면 출력이 곧 상태 기록 형식이라(RC10) 앞 글에서 뺄 수 없다 — 이미 이중 통로다.
case_for_current:
  strongest: >-
    앞 글은 devbrew 가 통제하지 못하는 통로이고, 그 실패 꼴이 devbrew 게이트의 꼴과 같다. 도구 호출 → 글 → 질문 순서에서
    글이 화면과 세션 기록 양쪽에서 빠진다(#75182 — 메인테이너가 2.1.233 에서 재현, 사용자 측정으로 세 모델에서 3번 중 0번만 글이 남았고
    앞에 도구 호출이 없으면 12번 중 12번 남았다). 리뷰 게이트는 언제나 엔진 렌더(Bash 호출) 뒤에 온다.
    보고는 2.1.325(2026-11-14)까지 이어지고, changelog 맨 위 다섯 판에 고친 줄이 없으며, 고칠 자리가 모델 쪽인지 클라이언트 쪽인지도 정해지지 않았다.
    같은 이슈에서 「글과 질문을 한 턴에 쓰지 말라」는 지시는 「do not hold reliably」였다.
    버그가 고쳐져도 앞 글은 진다. 레포 측정에서 「위」를 가리킨 질문 107개 중 65개가 앞 글 0자였고(RC12),
    지난 인터뷰의 사용자 확정 진단은 「보였는데 놓침」이었다(RC13) — 보일 때도 읽히지 않았다.
    반면 question · description 은 도구 호출의 칸이라 세션 기록에 그대로 남아, 고쳐졌는지를 기록으로 잴 수 있다.
    리뷰 결정 질문에는 가리킬 «위»가 애초에 없다. 절차서는 렌더 첫 줄만 앞 글에 쓰라고 하고 지적별 「그대로 두면 · 고치면」은
    Bash 출력에만 있다(RC6). 리뷰어는 그 셋(무엇이 문제인지 한 문장 · 그대로 두면 · 고치면)을 이미 «게이트에 그대로 실릴» 글로 쓴다(RC5) —
    본문과 두 선택지 설명에 그대로 꽂으면 엔진 코드도, 「설명에는 고르면 무엇이 달라지는지만」 규칙도 바꾸지 않는다(RC1 · RC4).
    바깥 지침은 «짧게»를 말할 뿐 «창 밖에»를 말하지 않는다. Microsoft 는 추천 표시는 라벨에, 「왜 고를 만한지 · 고르면 어떻게 되는지」는
    선택지 바로 아래 설명에(세 줄 이내) 두고, 맥락 없이 뜨는 창은 창 안에서 왜 떴는지 설명하라고 한다. W3C 는 선택지마다
    이득 · 위험 · 결과를 선택지 옆에, MCP 는 요청 화면 자체가 무엇을 왜 묻는지 밝히라고 한다. 길이 상한은 전제 P3 이 이미 갖고 있다.
    겹쳐 쓰면 화면이 길어지고(P3) 두 글이 어긋날 수 있으며, 앞 글을 의무로 남기는 한 「위에 적었다」로 되돌아갈 길이 열려 있다.
premise_refutation:
  hits: []
premise_list_challenge: >-
  반증은 없지만 목록에 결함이 다섯 있다.
  (1) 빠진 전제 — 경고(degrade) 줄. 버리려는 문면 「경고 N개 — 위에 적었다」가 실제로 가리키는 것은 추천 이유도 리뷰 지적 셋도 아니고
  경고 목록인데(RC7), 방향 문장과 P6 은 경고를 어디에 실을지 말하지 않는다. 사용자가 직접 연 사례가 바로 이 줄이었다(RC12).
  P1 · P4 를 그대로 적용하면 경고도 창 안에 한 줄씩 있어야 하고, 지금 규칙과 락은 그것을 명시로 금한다(RC8 · RC9).
  (2) 빠진 전제 — 「질문 창 안의 글은 다 보인다」. 방향은 이것을 말없이 가정한다. 창의 실패 보고(#77242 · #29125 · #67113 · #45384)는
  긴 글 · preview 칸 · 테마에 몰려 있다 — 그래서 P3(짧게)은 취향이 아니라 «보이기 위한 조건»이고, preview 칸은 쓰지 않아야 한다.
  (3) P5 는 둘을 묶었다. 「라벨을 되풀이」는 바깥 지침도 금하지만(Microsoft 「wordy restatement」), 「너무 짧으면」은 P3 과 부딪히고
  그 지침은 라벨이 자명하면 설명을 안 붙여도 된다고 한다. 재는 기준은 길이가 아니라 «고르면 달라지는 것(얻음 · 내줌)을 말하는가»여야 한다 —
  글자 수로 재는 검사는 거짓 대리 지표가 된다(OQ3 · OQ11).
  (4) P3 과 P6 사이 긴장. 지적 하나에 셋을 싣되 한 줄이어야 하는데, 엔진 줄에는 길이 상한이 없다(RC4). 누가 줄이는지(리뷰어가 처음부터 짧게 쓰는지,
  질문을 짜는 저자 모델이 줄이는지)가 전제에 없다. 정본 블록 9행 「스크립트·subagent 가 낸 원문은 고치지 않는다」와, 저자가 리뷰어의 지적을
  자기 말로 줄이는 것(Law 2 쪽 위험)이 걸린다.
  (5) P4 의 근거가 이슈 하나로만 적혀 있다. 실제 근거는 셋이다 — 하니스가 지운다(#75182) · 모델이 안 쓴다(지시가 지켜지지 않는다) ·
  보여도 놓친다(RC13). 버그가 고쳐져도 뒤의 둘은 남으므로 trigger (3)은 P4 를 무너뜨리지 못한다. 셋을 전제에 적어 두어야 한다.
  덧붙임 — 메인테이너 우회책(턴을 글로 끝내고 질문 도구 없이 묻기)은 닫힌 경로가 아니지만 대안으로 세우지 않았다. 게이트들이 고른 라벨 글자를
  읽어 분기하고(「라벨 끝의 꼬리를 뗀 이름으로 읽는다」), S9 가 질문 창을 전제로 답해졌으며, 그 지시가 지켜지지 않았다는 보고가 같은 이슈에 있다.
recommendation: refined
refined_takes: >-
  질문 창이 정본 통로다. 어느 질문도 앞 글이 보여야만 고를 수 있게 짜지 않는다.
  (a) 추천이 있는 질문은 선택지 설명마다 「얻음 · 내줌」 한 줄 — 추천 선택지의 얻음이 곧 추천 이유이고, 모든 선택지에 같은 꼴로 써서 추천 쪽에만 설득 문장이 붙지 않게 한다.
  (b) 리뷰 뒤 결정 질문은 본문에 무엇이 문제인지 한 줄, 「고친다」 설명에 「고치면」, 「그대로 둔다」 설명에 「그대로 두면」 — 리뷰어가 쓴 글을 그대로 쓴다.
  (c) 내용을 「위에 적었다」만으로 가리키는 문면을 없앤다. 경고도 같은 원칙으로 창 안에 한 줄씩 싣는 쪽을 사용자에게 묻는다(위 결함 1).
  (d) 지키게 하는 장치는 규칙 문장과 레포 테스트까지다(C17 · 지난 설계의 Anti-goals).
refined_drops: >-
  (a) 「앞 글 방식을 버린다」의 넓은 읽기 — 앞 글 자체를 없애는 것. 앞 글은 덤으로 남긴다: 인터뷰 «다음 결정» 줄(상태 기록과 같은 형식이라 뺄 수 없다) ·
  엔진 렌더 첫 줄 · 근거 · 자리 · 줄이지 않은 원문. 정본 블록은 문장을 늘리지 않고 「이유는 질문 위 글에」 구절만 바꾼다.
  (b) 길이 무제한 — 설명은 한 줄(넘어도 세 줄), 본문은 결정과 문제 한 줄. 근거 · 자리 · 선택에 영향 없는 세부와 preview 칸은 창에 싣지 않는다.
  (c) 추천이 없는 질문과 이름만으로 뜻이 서는 선택지(멈춤 등)에 얻음 · 내줌을 억지로 채우는 것 — 되풀이 설명을 새로 만든다.
  (d) 실행 중 훅 · mod 로 질문 칸을 검사하거나 고치는 것, 리뷰 엔진의 라벨 코드를 바꾸는 것.
evidence:
  - url: "https://github.com/anthropics/claude-code/issues/75182"
    supports: current
    claim: >-
      2026-07-07 개설, 2026-11-15 현재 열림 · 담당자 없음 · 고친 판 언급 없음. 메인테이너(bcherny, 2026-08-16)가 2.1.233 macOS 터미널에서 재현:
      기본 Opus 는 글이 질문 위에 그려졌고 Fable 5 는 답하기 전에도 뒤에도 안 보였으며 저장된 세션 기록에도 없었다 —
      「the model's user-facing text is arriving in a form the CLI treats as hidden reasoning」, 고칠 자리는 「still being worked out」.
      우회책은 턴을 평문으로 끝내거나 Fable 이 아닌 모델을 쓰는 것. 사용자 보고(메인테이너 미확인): 2.1.302 에서 opus-5-5 · sonnet-5-5 · fable-5-1 은
      3번 중 0번, haiku-5-5 만 3번 중 3번 글 블록이 남았고, 실패한 기록의 꼴은 tool_use > thinking > thinking > tool_use,
      앞에 도구 호출이 없으면 12번 중 12번 남았다. 2.1.317 Windows · 2.1.325 Linux(Opus 5.5, 2026-11-14)에서도 보고.
      「글과 질문을 한 턴에 쓰지 말라」는 CLAUDE.md · 메모리 지시는 「do not hold reliably」. 질문 앞 글을 훅으로 세는 우회는 한 사람은 된다고,
      다른 사람은 2.1.325 에서 「Neither PreToolUse nor PostToolUse on AskUserQuestion sees the running turn's assistant entry」라고 보고했다.
    touches: [P4]
    decides: [OQ3, OQ4, OQ11]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md"
    supports: current
    claim: >-
      맨 위 판은 2.1.325. 읽은 범위(2.1.325 · 2.1.323 · 2.1.322 · 2.1.321 · 2.1.319)에 「같은 턴의 질문 앞 글이 안 그려짐」을 고쳤다는 줄이 없다.
      그 아래 판은 이번에 읽지 못했다(파일이 길어 앞 10만 자만 읽음).
    touches: [P4]
    decides: []
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/agent-sdk/user-input"
    supports: current
    claim: >-
      공식 형식: 호출당 질문 1–4개, 질문당 선택지 2–4개, header 「max 12 characters」, 선택지는 「each with `label` and `description`」.
      `preview` 는 SDK 에서 `previewFormat` 을 켰을 때만 생긴다(「Without this setting, Claude does not generate previews」).
      question · label · description 의 글자 수 상한은 이 문서에 없다. 실을 칸은 질문 문장 · 라벨 · 설명 셋뿐이고,
      셋 다 도구 입력이라 호출 기록에 그대로 남는다.
    touches: []
    decides: [OQ4, OQ11]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://learn.microsoft.com/en-us/windows/win32/uxguide/ctrl-command-links"
    supports: both
    claim: >-
      Windows UX 지침(Windows 7 때 문서 · 「Much of the guidance still applies in principle」). 원안 쪽: 「If a response is strongly recommended, add
      "(recommended)" to the label」, 「Supplemental explanations describe why users might want to choose a response or what happens if a response is chosen」 —
      이유와 결과의 자리는 선택지 바로 아래다. 대안 쪽(양의 상한): 「Use parallel phrasing and at most three lines of text. Long supplemental
      explanations discourage reading」, 「Omit details that don't affect the choice」, 「Don't use command links to over-communicate」.
      P5 관련: 「Don't use a supplemental explanation that is wordy restatement of the command link. Use a supplemental explanation only when you can't
      make a command link self-explanatory. Providing a supplemental explanation for one command link doesn't mean that you have to provide them for all」 —
      되풀이는 금하되 짧음 · 없음 자체는 결함으로 보지 않는다.
    touches: [P2, P3, P5]
    decides: [OQ4, OQ3]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://learn.microsoft.com/en-us/windows/win32/uxguide/win-dialog-box"
    supports: current
    claim: >-
      같은 지침의 dialog 절: 주 지시문은 「Be concise use only a single, complete sentence … If you must explain anything more, use supplemental
      instruction」, 「If the appearance of the dialog box is program or system initiated (and therefore out of context), use the supplemental instruction to
      explain why the dialog has appeared. For such dialogs, the context is usually not obvious」, 「Don't repeat the main instruction with slightly different
      wording」. 맥락은 창 밖이 아니라 창 안의 보조 지시문에 싣는다 — 질문 본문 = 결정 한 문장 + 문제 한 줄의 선례다.
    touches: [P1, P6]
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://www.w3.org/WAI/WCAG2/supplemental/patterns/o7p03-supported-choice"
    supports: current
    claim: >-
      W3C 인지 접근성 패턴 「Clearly State the Results and Disadvantages of Actions, Options, and Selections」: 「When presenting users with actions and
      selections, clearly explain the benefits, risks and consequences of each option」. 예시는 선택지 옆에 무엇이 포함되는지를 두라는 것이고,
      고른 뒤에야 나오는 세부를 피하라고 한다. 짧게 쓰는 법은 다루지 않는다.
    touches: [P1, P2]
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://modelcontextprotocol.io/specification/2025-06-18/client/elicitation"
    supports: current
    claim: >-
      MCP elicitation 규격: 「Clients SHOULD present elicitation requests in a way that makes it clear what information is being requested and why」.
      에이전트가 사람에게 입력을 구할 때 무엇을 왜 묻는지는 요청 화면 자체가 밝혀야 한다는 표준 문장이다.
    touches: [P1]
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/garrytan/gstack/main/scripts/resolvers/preamble/generate-ask-user-format.ts"
    supports: current
    claim: >-
      다른 하니스(gstack)의 선례: 질문 글 «안»에 근거 한 문장 · 쉬운 설명 2–4문장 · 「Stakes if we pick wrong」 한 문장 ·
      「Recommendation: <choice> because <one-line reason>」을 넣고, 선택지마다 장점 둘 이상 · 단점 하나 이상(각 40자 이상)과 「Net」 한 줄을 요구한다.
      추천과 이유 · 대가를 질문 안에 싣는 방식의 실례다. 다만 분량은 이 일의 사용자가 길다고 한 「문장으로 풀어 쓴 형식」 쪽이다 — 자리는 취하고 길이는 취하지 않는다.
    touches: [P2]
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/77242"
    supports: alternative
    claim: >-
      열림(2026-07-13 개설, 마지막 댓글 2026-10-07). 질문 창에서 header 와 선택지(라벨 · 설명)는 보이고 question 글만 안 보인다(2.1.201 · 2.1.207 · 2.1.234, macOS).
      메인테이너(bcherny, 2026-08-17)는 Linux tmux 에서 재현하지 못했다. 보고자 진단(메인테이너 미확인): 질문 글이 dark 테마의 흰색으로 칠해져
      밝은 배경 터미널에서 대비 약 1.04:1 이고 `/theme` 을 Auto 나 Light 로 바꾸면 보인다. 질문 본문에만 실은 내용은 이 환경에서 안 보인다 —
      질문 창도 완전한 통로가 아니다.
    touches: [P1]
    decides: [OQ4, OQ11]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain
  - url: "https://github.com/anthropics/claude-code/issues/29125"
    supports: alternative
    claim: >-
      2.1.59 · 80x24 터미널에서 긴 선택지 설명이 문장 중간에서 잘린다는 보고 — 「fixed rendering area doesn't accommodate longer descriptions, which are
      common when Claude presents technical options with trade-off explanations」. 봇이 #28991 의 중복으로 닫았고 메인테이너 댓글 · 고친 판은 없다.
      대가 설명을 길게 실은 선택지가 잘리는 실제 보고다. 지금 판에서도 그런지는 확인하지 못했다.
    touches: [P3]
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain
  - url: "https://github.com/anthropics/claude-code/issues/67113"
    supports: alternative
    claim: >-
      긴 질문 글 · 긴 선택지 설명 · preview 가 줄바꿈 없이 창 가장자리에서 잘린다는 보고(2026-06-10, Fable 5, macOS CLI) —
      「lines are cut at the dialog edge and the remainder is gone」. 2026-06-16 에 완료로 닫혔으나 메인테이너 댓글 · 연결된 PR · 고친 판이 페이지에 없다.
      창 안에 긴 글을 실을 때의 한계는 실제 화면에서 재야 한다.
    touches: [P3]
    decides: [OQ4, OQ11]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain
  - url: "https://github.com/anthropics/claude-code/issues/45384"
    supports: both
    claim: >-
      선택지에 `preview` 가 있으면 `description` 이 그려지지 않는다는 보고(2026-04-08, macOS CLI, 판 미기재) — 「Only `label` and `preview` are
      rendered. `description` is silently dropped」. 메인테이너 댓글 없이 봇이 비활성으로 닫았다. 설명 칸에 대가를 싣는다면 preview 칸을 함께 쓰지 않아야 한다.
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain
  - url: "https://arxiv.org/abs/2006.14779"
    supports: both
    claim: >-
      Bansal 외(CHI 2021): 설명은 사람이 AI 추천을 받아들일 가능성을 그 추천이 옳든 그르든 높였고, 팀 정확도는 확신도만 보인 경우보다 높아지지 않았다.
      trigger (2)의 「설명을 붙여도 과신은 줄지 않는다」의 출처 계열이다. 이 일의 goal 은 과신을 줄이는 것이 아니라 고르는 것과 대가를 알 수 있게 하는 것이라
      어느 전제와도 충돌하지 않는다. 닿는 것은 P2 다 — 추천 «이유»만 붙이면 수락만 늘 수 있으므로 내주는 것을 같은 줄에 적는 것이 그 반대 무게다.
      초록을 검색 요약으로 읽었다.
    touches: [P2]
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain
  - url: "https://arxiv.org/abs/2212.06823"
    supports: current
    claim: >-
      Vasconcelos 외(CSCW 2023, 다섯 연구 N=731): 사람은 설명을 읽을지를 비용 대 이득으로 고르며, 설명이 AI 를 확인하는 비용을 충분히 낮출 때는
      과신이 줄었다 — 앞선 무효 결과는 설명이 확인 비용을 충분히 낮추지 못해서일 수 있다고 본다. 고르는 자리 바로 옆의 한 줄 「얻음 · 내줌」은
      다른 곳의 긴 글을 찾아 읽는 것보다 확인 비용이 낮다. 초록을 검색 요약으로 읽었다.
    touches: [P3]
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain
  - url: "https://www.eecs.harvard.edu/~kgajos/papers/2021/bucinca2021trust.shtml"
    supports: both
    claim: >-
      Buçinca · Malaya · Gajos(CSCW 2021, N=199): 설명을 붙이는 것만으로는 과신이 줄지 않는 것으로 보이고, 생각을 강제하는 장치는 과신을 줄였으나
      사용자는 그런 설계를 덜 좋아했다. 설명 칸에 대가를 적는다고 반드시 읽힌다는 근거는 아니다. 다만 비교 대상(앞 글)도 같은 한계를 지므로
      자리 선택을 가르지 못한다. 초록을 검색 요약으로 읽었다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain
  - url: "https://www.anthropic.com/engineering/claude-code-auto-mode"
    supports: both
    claim: >-
      「in practice users accept 93% of them anyway」 · 「approval fatigue, where people stop paying close attention to what they're approving」 —
      이 수치는 명령 실행 · 파일 수정 앞의 «권한 승인 질문»에 관한 것이고 선택지 질문에 관한 것이 아니다. trigger (2)의 「승인 질문이 잦으면 덜 읽는다」는
      질문의 빈도에 관한 주장인데 이 방향은 질문 수를 바꾸지 않는다 — 전제에 닿지 않는다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: confirmed
  - url: "https://doi.org/10.3389/feduc.2019.00086"
    supports: current
    claim: >-
      공간 근접(spatial contiguity) 연구: 관련된 글을 가리키는 대상 가까이에 둘 때 이해가 낫다 — Beege 외(2019)는 과제가 복잡할 때 통합 배치의 효과가 크고
      (d = 0.78) 단순할 때는 작다고(d = 0.28, 유의하지 않음) 보고했고, 선행 메타분석(Schroeder & Cenkci 2018, 58개 비교)은 g = 0.63 을 보고했다.
      「위에 적었다」로 떨어진 글을 가리키는 꼴은 이 연구들이 말하는 주의 분할 배치다. 학습 과제 연구라 질문 창에 그대로 옮기는 것은 유추이고,
      검색 요약으로만 읽었다.
    touches: [P1]
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-15"
    certainty: uncertain
repo_claims:
  - id: RC1
    path: "shared/style/plain-language.md"
    anchor: "설명에는 고르면 무엇이 달라지는지만 쓴다"
    line: 6
    claim: >-
      정본 블록 6행이 설명 칸을 「고르면 무엇이 달라지는지만」으로, 추천 이유의 자리를 「이유는 질문 위 글에」로 정한다. 이 방향이 뒤집는 것은 뒤 구절 하나다.
      「얻음 · 내줌」과 리뷰의 「그대로 두면 · 고치면」은 «고르면 달라지는 것»이라 앞 문장을 고치지 않고 설명 칸에 들어간다.
      같은 블록 9행 「스크립트·subagent 가 낸 원문은 고치지 않는다」는 리뷰어 글을 창에 맞춰 줄이는 일과 걸린다.
    touches: [P2, P6]
    decides: [OQ4, OQ3]
  - id: RC2
    path: "shared/tests/test_plain_language_block.sh"
    anchor: "REC='추천이 있으면 그 선택지를 첫 자리에 두고 라벨 끝에 「(권장)」을 단다 — 여럿이면 모두, 이유는 질문 위 글에."
    line: 30
    claim: >-
      그 문장은 글자째 잠겨 있고(정본에 정확히 한 번), 블록은 `plugins/*/skills/*/SKILL.md` 전부에 같은 바이트로 복제돼 판정 모듈이 동일성을 잰다.
      「이유는 질문 위 글에」를 바꾸면 이 락과 모든 사본이 한 커밋에서 함께 바뀐다 — 규칙 문장만 두는 길에도 이 비용은 든다.
    touches: []
    decides: [OQ3]
  - id: RC3
    path: "docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md"
    anchor: "## Anti-goals"
    line: 47
    claim: >-
      지난 설계의 Anti-goals 는 넷이다 — 실행 중 질문 도구 호출에 끼어드는 훅 · 래퍼, 복제 블록을 눈에 띄게 늘리는 것, 화면의 「추천 없음」 문구,
      리뷰 엔진의 라벨 코드 · 정답 파일을 바꾸는 것. 30행이 C17 의 뜻을 「순정 Claude Code 의 동작에 잘못 끼어들어 성능을 해치지 말라」로 풀고,
      68행은 정본을 「새 줄을 더하지 않고 있는 문장을 바꾼다」로 고쳤으며, 178행 AC3 은 블록 변경으로 새로 밀려난 `## ` 절이 없는지를
      `token_boundary.py` 로 잰다. 이 방향은 구절 치환(블록을 늘리지 않음) · 엔진 코드 무변경(RC4) · 훅 없음으로 넷 모두 안에서 할 수 있다 —
      trigger (1)의 충돌은 D16 하나로 좁혀지고, 그것은 S7 로 재결정됐다.
    touches: []
    decides: [OQ3, OQ4]
  - id: RC4
    path: "shared/docreview/scripts/docreview_state.py"
    anchor: "def _rg_decide(st, g, fid)"
    line: 2295
    claim: >-
      엔진 렌더는 결정 항목마다 요약 한 줄과 「그대로 두면: <if_unfixed>」 · 「고치면: <replacement>」 · 「근거」 · 「자리」 · 「대안」 줄을 이미 만든다(2310–2315행).
      나가는 곳은 `gate --render` 의 표준 출력이다. 이 줄들을 질문 본문 · 설명으로 옮기는 것은 절차서 문장의 일이라 엔진 코드를 바꾸지 않는다.
      같은 파일 `_one`(2223행)은 공백만 접어 한 줄로 만들 뿐 길이를 자르지 않는다 — 설명 칸에 그대로 실으면 길이는 리뷰어가 쓴 만큼이다.
    touches: [P6, P3]
    decides: [OQ4]
  - id: RC5
    path: "plugins/spec-distill/agents/doc-critic.md"
    anchor: "`summary`·`if_unfixed`·`replacement` 는 게이트에 그대로 실려 처음 보는 사람이 읽는다"
    line: 68
    claim: >-
      P6 의 셋은 리뷰어가 이미 따로 쓰는 칸이다 — `summary`(한 문장 · 내부 기호 없이 무엇이 문제인지), `if_unfixed`(「문제의 재진술이 아니라 결과」),
      `replacement`(「고치면 무엇이 되는가」, decide 에는 필수). 셋 다 쉬운 말로, 게이트에 그대로 실릴 글로 쓰라고 돼 있다. 저자 모델이 새로 요약할 필요 없이
      본문 = summary · 「그대로 둔다」 설명 = if_unfixed · 「고친다」 설명 = replacement 로 꽂을 수 있다. `summary` 만 한 문장 제한이 있고 나머지 둘은 길이 제한이 없다.
    touches: [P6]
    decides: [OQ4]
  - id: RC6
    path: "shared/docreview/references/reviewing-document.md"
    anchor: "렌더 첫 줄(상태와 경고)은 첫 호출 **앞 글**에 한 번 쓴다"
    line: 30
    claim: >-
      절차서 8단계가 앞 글에 쓰라고 하는 것은 렌더 «첫 줄»뿐이고, 질문 본문은 「결정 하나와 … 「경고 N개 — 위에 적었다」 한 줄만」이다.
      42행은 「렌더의 「고치면」 줄이 전문을 이미 내므로 라벨은 그 줄을 가리키는 손잡이다」라고 하지만, 지적별 줄을 사용자에게 보이는 글이나 설명 칸으로
      옮기라는 문장은 이 파일에도, 같은 문장을 가진 spec-review(554행) · request-framing(783행) · reviewing-brief(603행)에도 없다
      (세 SKILL 과 references 를 「그대로 두면」 · 「렌더 … 쓴다/싣는다」로 훑어 확인 — 다른 표현의 규칙이 있을 가능성은 남는다).
      리뷰 결정 질문에서 지적 내용이 사는 곳은 Bash 도구 출력이다 — 버그가 없어도 가리킬 앞 글이 규칙에 없다.
    touches: [P6, P4]
    decides: [OQ4]
  - id: RC7
    path: "plugins/spec-distill/references/proceed-gate.md"
    anchor: "질문 본문에는 결정 하나와 「경고 N개 — 위에 적었다」"
    line: 44
    claim: >-
      게이트 정본은 판정 결과와 degrade 를 「하나도 빠뜨리지 않고 게이트 앞 글에」 쓰고(39–40행) 질문에는 개수 줄만 두라고 한다.
      「위에 적었다」가 가리키는 것은 경고 목록이다. 같은 파일 56행은 둘째 질문의 「제안 이유는 게이트 앞 글에」 쓰라고 한다 — 질문 밖 「권하는 글」 자리의 하나이고,
      「이유는 … 앞 글에 / 위 글에」 글자 계열로 찾을 수 있는 자리다(정본 블록 6행 · finishing.md 536행이 같은 꼴).
    touches: [P1, P4]
    decides: [OQ4, OQ10]
  - id: RC8
    path: "plugins/spec-distill/skills/pm-interview/references/finishing.md"
    anchor: "옵션 description 에 싣지 않습니다"
    line: 497
    claim: >-
      인터뷰 끝 게이트는 「모든 degrade record 는 게이트 앞 글에 한 줄씩 씁니다 — 옵션 description 에 싣지 않습니다. 사용자가 옵션을 고르기 전에 읽도록
      질문 바로 앞에 둡니다」라고 정한다. 이 규칙의 근거(«고르기 전에 읽도록 앞에»)가 P4 와 정면으로 부딪힌다 — 앞 글이 안 보이면 경고는 고르기 전에 읽히지 않는다.
      513행 질문 리터럴에도 「경고 <N>개 — 위에 적었다」가 박혀 있다. 536행은 둘째 질문의 제안 이유를 「게이트 앞 글(위 목록 끝)에 한 줄로」 쓰라고 한다.
    touches: [P1, P4]
    decides: [OQ4, OQ10]
  - id: RC9
    path: "plugins/spec-distill/tests/test_plain_gate_templates.sh"
    anchor: "# ⑬ 질문 본문에는 결정과 상태 한 줄만"
    line: 133
    claim: >-
      「질문 본문에는 결정 하나와 … 「위에 적었다」 … 한 줄만」 문장이 여섯 자리에서 글자째 정확히 한 번으로 잠겨 있고(134–142행),
      143–147행은 여섯 파일 어디에도 「경고를 질문에 한 줄씩 싣는 문장이 없다」는 음의 락이며, 150행은 finishing 의 「옵션 description 에 싣지 않습니다」를 잠근다.
      「위에 적었다」 방식을 버리거나 경고를 창 안에 싣기로 하면 이 양 · 음의 락을 함께 뒤집어야 한다 — 지금 락은 새 방향의 반대쪽을 지킨다.
    touches: []
    decides: [OQ3, OQ4]
  - id: RC10
    path: "plugins/spec-distill/skills/pm-interview/SKILL.md"
    anchor: "사용자에게 보이는 출력과 state 본문 기록이 같은 형식이다"
    line: 180
    claim: >-
      인터뷰 라운드 규약은 질문 앞 글 `### 다음 결정` 에 「OQ<n>: … · 추천: … · 트레이드오프: <선택지별 한 줄>」(190행)을 내고 그 형식이 상태 기록과 같다.
      인터뷰에서는 추천과 선택지별 대가가 이미 앞 글에 한 줄로 나가고, 이 줄은 상태 기록이라 앞 글에서 통째로 뺄 수 없다.
      204–205행은 「각 선택지의 `description` 은 «고르면 무엇이 달라지는가»를 담는다. 기계 검사는 없다」다 — 창 안의 자리는 이미 정해져 있고 집행만 없다.
    touches: [P2, P3]
    decides: [OQ4, OQ10, OQ3]
  - id: RC11
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "지휘자는 배경을 먼저 쉬운 말로 쓰고 질문만 봐도 결정할 수 있게 묻는다"
    line: 32
    claim: >-
      레포 안의 선례. 지휘자 규칙은 이미 「질문만 봐도 결정할 수 있게」와 「각 선택지 설명에 원문의 「고르면 무엇이 달라지나」 를 빠뜨리지 않는다」를 요구하고,
      하위가 돌려보내는 요약 꼴도 「무엇을 정하나 · 고르면 무엇이 달라지나(그대로 두면 · 고치면) · 배경」(29행)이다. 같은 문장이
      「지휘자 의견은 선택지 밖 「지휘자 의견:」 한 줄로만 쓴다」고도 정한다 — 추천 이유를 일부러 선택지 밖에 두는 자리이고(옮긴 원문을 글자 그대로 지키려는 것),
      P7 의 범위 목록에 지휘자는 없다. 이유를 창 안으로 옮기는 규칙이 정본 블록으로 들어가면 이 자리와 부딪히는지 정해야 한다.
    touches: [P1, P7]
    decides: [OQ4, OQ10]
  - id: RC12
    path: "docs/superpowers/interview/2026-11-15-present-tradeoffs-brief-interview.state.md"
    anchor: "앞 글 0자인 질문 앞에는 전부 생각 블록이 있었다"
    line: 238
    claim: >-
      본체 재측정: 「위」를 가리킨 질문 107개 중 앞 글 0자가 65개(236행), opus 계열 60개 중 42개 · fable 계열 47개 중 23개(237행),
      그 65개 앞에는 전부 생각 블록이 있었다(238행). 이 꼴은 #75182 의 사용자 보고(실패한 기록 = tool_use > thinking > tool_use)와 같아
      기록으로는 「안 썼다」와 「사라졌다」를 가를 수 없다. seed 29행의 손으로 연 사례는 질문 넷이 모두 「경고 4개 — 위에 적었다」였다.
      261행은 이번 화면 확인에서 앞 글이 글 블록으로 남고 화면에도 보였다고 적는다 — 늘 나는 버그가 아니다. 앞 글을 기록으로 재는 방법은 믿을 수 없고,
      질문 칸은 도구 입력이라 기록에 남는다.
    touches: [P4]
    decides: [OQ11]
  - id: RC13
    path: "docs/superpowers/interview/2026-10-27-askquestion-recommendation-interview.md"
    anchor: "해결: 보였는데 놓침 — 라벨 표시의 강도가 핵심"
    line: 195
    claim: >-
      지난 인터뷰의 원인 판정(OQ7, 사용자 발화 S8)은 「권고가 질문 창에 가려졌나, 보였는데 놓쳤나 — 보였는데 놓침」이었다. 앞 글이 보일 때도 그 안의 권고는
      읽히지 않았다는 사용자 확정이다. D16(175행)은 그 위에서 표시만 라벨로 옮기고 이유를 위에 남겼고, 181행은 설명 칸 규칙을 그대로 둔 것이
      「사용자가 따로 정한 것은 아니다」라고 적는다. 앞 글을 둘째 통로로 남겨도 읽히리라는 기대는 이 판정과 맞지 않는다.
    touches: [P4, P1]
    decides: [OQ4]
  - id: RC14
    path: "shared/tests/ask_recommendation.py"
    anchor: "def required(kind, body)"
    line: 109
    claim: >-
      지금 있는 질문 자리 검사는 종류별 리터럴(라벨 꼬리 · 지시 문장 · 「추천을 달지 않는다 —」 · 출처 꼬리 · 뗌 문장)이 문서의 그 범위에 있는지만 본다(109–127행).
      질문 본문 · 설명 칸의 내용은 재지 않는다. 이 장치를 넓혀 잴 수 있는 것은 「그 자리에 새 지시 문장이나 설명 리터럴이 있다」까지이고,
      실행 중 실제로 뜬 질문의 내용은 이 검사의 도달 밖이다 — 고쳐졌는지는 세션 기록의 질문 입력(question · description)을 재는 다른 방법이 필요하다.
    touches: []
    decides: [OQ3, OQ11]
  - id: RC15
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "재비판이 심각도를 낮춘 지적이 <n>개 있다(위 「낮춘 지적」 절)"
    line: 713
    claim: >-
      코드 리뷰의 낮춘 지적 게이트는 질문 본문이 「위 「낮춘 지적」 절」로 질문 밖 글을 가리키고(708–709행 「위 원문 표면화로 이미 보였다」),
      설명 칸에는 이미 지적별 「낮춘 이유를 쉬운 말 한 줄로」를 싣는다(715행). 추천은 일부러 비운다(720행). 코드 리뷰 쪽은 설명 칸에 항목별 한 줄을 싣는 꼴이
      이미 있고, 고칠 것은 「위」를 가리키는 본문이다 — 지적이 4개 이상이면 선택지가 「전부 되올린다 / 그대로 둔다」 둘로 접혀(716행) 항목별 내용이 창에 설 자리가 없다.
    touches: [P7, P4, P6]
    decides: [OQ4]
```

## 확인하지 못한 것

- **Apple HIG Alerts** — 페이지 본문이 열리지 않아 싣지 않았습니다. 조사 3 의 인용은 여전히 본체 미확인입니다.
- **changelog** — 맨 위 다섯 판만 읽었습니다. 2.1.318 아래에 고친 줄이 있는지는 보지 못했습니다.
- **연구 넷** (Bansal · Vasconcelos · Buçinca · 공간 근접) — 초록을 검색 요약으로만 읽어 `uncertain` 으로 두었습니다.
- **지금 판의 질문 창 길이 한계** — 어느 표면에서도 화면으로 재지 않았습니다. #29125 · #67113 이 2.1.303 이후에도 나는지 모릅니다.
- **읽지 않은 레포 자리** — spec-review 702행(③ 후속 갈래의 「이유는 질문 위 글에」) · artifact-critique · e2e.md 는 조사 2 의 주장을 그대로 믿지 않고 `repo_claims` 에서 뺐습니다.

## 읽은 파일

- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/docs/superpowers/interview/2026-11-15-present-tradeoffs-interview.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/docs/superpowers/interview/2026-11-15-present-tradeoffs-brief-interview.state.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/docs/superpowers/interview/2026-10-27-askquestion-recommendation-interview.md (166–201행)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md (30–99행 · AC3 줄)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/style/plain-language.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/docreview/references/reviewing-document.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/docreview/scripts/docreview_state.py (`_one` · `_rg_decide`)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/tests/test_plain_language_block.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/tests/ask_recommendation.py (100–131행)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/references/proceed-gate.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/references/conductor-dispatch.md (24–37행)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/skills/pm-interview/SKILL.md (174–209행)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/skills/pm-interview/references/finishing.md (466–541행)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/skills/spec-review/SKILL.md (543–578행)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/agents/doc-critic.md (54–73행)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/tests/test_plain_gate_templates.sh (120–156행)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/quality-gates/skills/quality-pipeline/SKILL.md (705–722행)

Sources:
- [anthropics/claude-code #75182](https://github.com/anthropics/claude-code/issues/75182)
- [anthropics/claude-code #77242](https://github.com/anthropics/claude-code/issues/77242)
- [anthropics/claude-code #29125](https://github.com/anthropics/claude-code/issues/29125)
- [anthropics/claude-code #67113](https://github.com/anthropics/claude-code/issues/67113)
- [anthropics/claude-code #45384](https://github.com/anthropics/claude-code/issues/45384)
- [Claude Code CHANGELOG.md](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
- [Handle approvals and user input (Agent SDK)](https://code.claude.com/docs/en/agent-sdk/user-input)
- [Microsoft — Command Links](https://learn.microsoft.com/en-us/windows/win32/uxguide/ctrl-command-links)
- [Microsoft — Dialog Boxes](https://learn.microsoft.com/en-us/windows/win32/uxguide/win-dialog-box)
- [W3C — Clearly State the Results and Disadvantages of Actions, Options, and Selections](https://www.w3.org/WAI/WCAG2/supplemental/patterns/o7p03-supported-choice)
- [MCP spec — Elicitation](https://modelcontextprotocol.io/specification/2025-06-18/client/elicitation)
- [gstack — generate-ask-user-format.ts](https://raw.githubusercontent.com/garrytan/gstack/main/scripts/resolvers/preamble/generate-ask-user-format.ts)
- [Bansal et al. 2021 — Does the Whole Exceed its Parts?](https://arxiv.org/abs/2006.14779)
- [Vasconcelos et al. 2023 — Explanations Can Reduce Overreliance](https://arxiv.org/abs/2212.06823)
- [Buçinca et al. 2021 — To Trust or to Think](https://www.eecs.harvard.edu/~kgajos/papers/2021/bucinca2021trust.shtml)
- [Anthropic — Claude Code auto mode](https://www.anthropic.com/engineering/claude-code-auto-mode)
- [Beege et al. 2019 — spatial contiguity](https://doi.org/10.3389/feduc.2019.00086)

### 조사 7 — orchestrator · R3 · 묶음 5

레포 주장 확인(V1) — 조사 5(blind-spot-prober)의 RC1–RC12 는 RC62–RC73 으로, 조사 6(steelman-builder)의 RC1–RC15 는 RC74–RC88 로 다시 붙였다.
- 확인 RC62 — 확인 — shared/docreview/references/reviewing-document.md#렌더의 「고치면」 줄이 전문을 이미 내므로 라벨은 그 줄을 가리키는 손잡이다 — 27–42행 일치(지적별 줄을 사용자 글로 옮기라는 문장 없음)
- 확인 RC63 — 확인 — shared/docreview/scripts/docreview_state.py#def _one — 2223–2225행은 공백만 접고 길이를 자르지 않는다 · 2311–2312행 자리표 일치
- 확인 RC64 — 확인 — shared/style/plain-language.md#스크립트·subagent 가 낸 원문은 고치지 않는다 — 블록 9행 · 6행 · 3행 일치
- 확인 RC65 — 확인 — plugins/spec-distill/tests/test_plain_gate_templates.sh#⑬ 질문 본문에는 결정과 상태 한 줄만 — 100–113행 인접 순서 락 · 133–142행 양의 락 · 143–147행 부재 락 일치
- 확인 RC66 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#옵션 description 에 싣지 않습니다 — 497행 · 테스트 150–151행 일치
- 확인 RC67 — 확인 — plugins/spec-distill/agents/relay-checker.md#지휘자 의견이 선택지 설명 안으로 들어갔으면 어긋남이다 — 34 · 37행 일치
- 확인 RC68 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#덩어리 본문(`render`)은 질문 텍스트에 줄임 없이 싣는다 — 934 · 935 · 939행 일치
- 확인 RC69 — 확인 — shared/tests/plain_language_block.py#블록 바이트가 정본(%s)과 다르다 — 52행 일치 · 사본 10개(quality-gates 둘 · plugin-audit · project-init 하나씩 · spec-distill 여섯)
- 확인 RC70 — 확인 — docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md### Anti-goals — 28 · 51–54 · 178행 일치
- 확인 RC71 — 확인 — shared/tests/test_ask_recommendation.sh#한계 둘 — 8–10 · 37행 일치
- 확인 RC72 — 확인 — plugins/spec-distill/references/proceed-gate.md### Step B — 단일 `AskUserQuestion` — 39–50 · 58행 일치
- 확인 RC73 — 확인 — plugins/spec-distill/CHANGELOG.md### [5.1.0] — 2026-10-09 — 696 · 699행 일치. 왜 질문 안에서 뺐는지의 이유는 그 항목에 없다
- 확인 RC74 — 확인 — shared/style/plain-language.md#설명에는 고르면 무엇이 달라지는지만 쓴다 — 6 · 9행 일치
- 확인 RC75 — 확인 — shared/tests/test_plain_language_block.sh#REC='추천이 있으면 그 선택지를 첫 자리에 두고 — 30 · 32행 일치
- 확인 RC76 — 확인 — docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md### Anti-goals — 30 · 47–54 · 68 · 178행 일치
- 확인 RC77 — 확인 — shared/docreview/scripts/docreview_state.py#def _rg_decide(st, g, fid) — 2310–2315 · 2223–2225행 일치
- 확인 RC78 — 확인 — plugins/spec-distill/agents/doc-critic.md#`summary`·`if_unfixed`·`replacement` 는 게이트에 그대로 실려 처음 보는 사람이 읽는다 — 60 · 68행 일치
- 확인 RC79 — 확인 — shared/docreview/references/reviewing-document.md#렌더 첫 줄(상태와 경고)은 첫 호출 **앞 글**에 한 번 쓴다 — 30 · 42행 일치. 지적별 줄을 옮기라는 문장이 없다는 것은 찾지 못한 것이다
- 확인 RC80 — 확인 — plugins/spec-distill/references/proceed-gate.md#질문 본문에는 결정 하나와 「경고 N개 — 위에 적었다」 — 39–45 · 56행 일치
- 확인 RC81 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#옵션 description 에 싣지 않습니다 — 497 · 513 · 536행 일치
- 확인 RC82 — 확인 — plugins/spec-distill/tests/test_plain_gate_templates.sh## ⑬ 질문 본문에는 결정과 상태 한 줄만 — 134–147 · 150행 일치
- 확인 RC83 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#사용자에게 보이는 출력과 state 본문 기록이 같은 형식이다 — 180 · 190 · 204–205행 일치
- 확인 RC84 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#지휘자는 배경을 먼저 쉬운 말로 쓰고 질문만 봐도 결정할 수 있게 묻는다 — 32행 일치. 29행은 읽지 않았다
- 확인 RC85 — 확인 — docs/superpowers/interview/2026-11-15-present-tradeoffs-brief-interview.state.md#앞 글 0자인 질문 앞에는 전부 생각 블록이 있었다 — 236–238행(이 인터뷰의 재측정 줄) 일치
- 확인 RC86 — 확인 — docs/superpowers/interview/2026-10-27-askquestion-recommendation-interview.md#해결: 보였는데 놓침 — 라벨 표시의 강도가 핵심 — 175 · 181 · 195행 일치
- 확인 RC87 — 확인 — shared/tests/ask_recommendation.py#def required(kind, body) — 109–127행 일치
- 확인 RC88 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#재비판이 심각도를 낮춘 지적이 <n>개 있다(위 「낮춘 지적」 절) — 707–720행 일치

웹 주장 확인(본체)
- 웹 공식 훅 문서 — 일부 확인(1차 · code.claude.com/docs/en/hooks · 2026-11-15) — 훅이 도구 호출을 막고 이유를 모델에 돌려줄 수 있다(permissionDecision deny)까지 읽었다. 질문 도구에 그대로 통하는지 · 호출한 skill 을 알려 주는 칸이 있는지는 읽은 범위에 없었다 [→ OQ3]
- 웹 조사 5 · 6 의 창 안 잘림 이슈(#39867 · #29125 · #88494 · #89644) · 연구(Bansal · Buçinca · Vasconcelos · 공간 근접) · Microsoft · W3C · MCP · gstack — 확인 못 함(본체가 다시 확인하지 않음)
- 재측정: 깔린 Claude Code 2.1.325(claude --version). R2 의 앞 글도 글 블록(929자)으로 기록에 남았다.

steelman ST1 — 게이트-전 확인
- dispatch 입력: goal = S1 의 goal 문장(「이 일의 목표는 … 알 수 있게 하는 것이다. (사용자 확인)」) · 전제 P1–P7 · 제약 S1–S9 와 지난 인터뷰의 D13 · D16 · C17
- 전제: P1 화면에 보이는 글만으로 무엇을 고르는지와 그 대가를 알 수 있어야 한다(S1) · P2 추천에는 내주는 것을 함께 적는다(S1) · P3 얻음 · 내줌은 한 줄 정도의 짧은 형식(S1) · P4 질문 위 글은 사라지는 날이 있어 기대면 안 된다(S7 · orchestrator 도출 포함) · P5 설명 칸에 글자가 있어도 라벨을 되풀이하거나 너무 짧으면 빈 것과 같다(S8) · P6 리뷰 결정 질문은 창 안에 무엇이 문제인지 · 그대로 두면 · 고치면이 있어야 한다(S9) · P7 범위는 devbrew 가 글을 쓰는 방향 자리와 리뷰 뒤 결정 질문이고 설계 · 계획 대화는 외부 skill 몫(S1 · S4 · S5 · S6)
- 리포 주장 15 중 확인 15(RC74–RC88)
- 양성 부착 13건 대조: #75182→P4 확인 · changelog→P4 확인 · Microsoft command link→P2 · P3 · P5 확인 · Microsoft dialog→P1 · P6 확인 · W3C→P1 · P2 확인 · MCP→P1 확인 · gstack→P2 확인 · #77242→P1 확인 · #29125→P3 확인 · #67113→P3 확인 · Bansal→P2 확인 · Vasconcelos→P3 확인 · 공간 근접→P1 확인. 대조는 「그 주장이 그 전제에 닿는가」이고 출처를 본체가 다시 읽은 것은 #75182 하나다
- premise_refutation.hits: 없음 → 재검토 사유 없음 — 확인된 전제 충돌 0건
- 근거 17 중 부착 13 · 리포 주장 15 중 확인 15

### 조사 8 — orchestrator · R4 · 묶음 6

- 웹 Microsoft command link 지침 — 확인(1차 · learn.microsoft.com · 2026-11-15 · Windows 7 때 문서이고 「Much of the guidance still applies in principle」 주석이 있다) — 「If a response is strongly recommended, add "(recommended)" to the label」 · 「Supplemental explanations describe why users might want to choose a response or what happens if a response is chosen」 · 「Use parallel phrasing and at most three lines of text」 · 「Don't use a supplemental explanation that is wordy restatement of the command link」 [→ OQ4]

### 조사 9 — orchestrator · R6 · 묶음 7

- 확인 RC89 — 확인 — docs/superpowers/specs/2026-10-08-plain-language-output-design.md#3. 스킬이 시키는 질문·보고 틀: 질문 하나에 결정 하나만 담고, 경고 목록은 질문 앞으로 옮긴다. — 19 · 90–91 · 255–257행(목표 4 「모든 게이트 질문은 결정 하나와 상태 한 줄만 담는다. 상태와 경고 목록은 질문 앞 글에 있다」) · 그 변경이 들어온 커밋은 2026-10-09 의 79d010ab · de05ce3a · dc4510d0 · 6b74f39b(커밋 본문에 이유 없음) [RC89 → OQ12]
- 확인 RC90 — 확인 — plugins/spec-distill/agents/doc-critic.md#`summary`(한 문장) — 길이를 묶은 칸은 summary 뿐이다. if_unfixed · replacement 를 정하는 파일은 doc-critic · doc-critic-web · doc-recritic(spec-distill 과 shared/docreview 의 사본) · 프로필 둘 · codex 변환기이고 어디에도 그 두 칸의 길이 규칙이 없다 [RC90 → OQ14]
- 확인 RC91 — 확인 — tools/plain-language/token_boundary.py#압축 뒤 다시 붙는 skill 앞 5,000토큰의 경계가 규칙 블록 때문에 어디로 옮겼는지 잰다(근사) — 새 문면을 넣은 뒤에야 잴 수 있는 측정 도구다 [RC91 → OQ18]
- 재측정(세션 기록의 리뷰 렌더 줄): 「그대로 두면」 서로 다른 줄 108개 — 중앙 111자 · 90% 158자 · 최대 344자 · 120자 초과 37% / 「고치면」 109개 — 중앙 182자 · 90% 299자 · 최대 484자 · 180자 초과 50% [→ OQ14 · OQ16]

### 조사 10 — orchestrator · R6 · 묶음 8

- 화면 측정(본체가 시험 질문을 띄워 잼 · 2026-11-15 · Claude Code 2.1.325 · 터미널 CLI): 한 호출에 질문 둘 · 첫 질문은 여러 선택 · 선택지 넷 · 설명마다 약 180자(세 줄쯤) · 본문에 경고 꼴 세 줄과 끝 표시 — 설명 넷의 끝말과 본문 끝 표시가 모두 보였다. 한 번의 측정이다 [→ OQ13 · OQ12 · OQ4]
- 재지 않은 것: 300자 이상의 설명 · 다른 창 크기 · 기타 칸을 골랐을 때 질문과 설명이 화면에 남는지(#88494) · preview 칸

### 조사 13 — orchestrator · R9 · 묶음 10

- 재측정(세션 기록의 추천 선택지 설명 · 이 세션 제외): 추천 꼬리가 붙은 선택지 679개(서로 다른 것 644개). 무작위 24개를 본체가 손으로 가름 — 내주는 것을 적은 설명 8개 · 고르면 일어나는 일만 적은 것 13개 · 라벨을 거의 되풀이한 것 3개. 한 사람이 한 번 가른 표본이다. 낱말 맞추기로는 644개 중 96개(15%)에 대가를 가리킬 만한 낱말이 있었다(거칠다) [→ OQ15]
- 재지 못한 것: 공통 규칙의 새 문면이 skill 앞 5,000토큰 경계에서 절을 밀어내는지 — 후보 문면이 있어야 tools/plain-language/token_boundary.py 로 잴 수 있다 [→ OQ18]

### 조사 14 — orchestrator · R9 · 묶음 11

- 화면 측정(본체가 시험 질문을 띄워 잼 · 2026-11-15 · Claude Code 2.1.325 · 터미널 CLI): 한 호출에 질문 둘 · 첫 질문은 여러 선택 · 선택지 넷 · 설명 약 300자 둘과 약 480자 둘 — 설명 넷의 끝말이 모두 보였다. 「고치면」 줄의 최대값(484자)에 해당하는 길이다. 한 번의 측정이다 [→ OQ13 · OQ19]
- 기타 칸: 둘째 질문에서 기타 칸에 글자를 적어 답할 수 있었다. 답한 뒤 질문과 설명이 화면에 남았는지는 다음 라운드에 묻는다
- 재지 않은 것: 좁은 창(예: 80x24) · 한 호출에 질문 넷 · preview 칸

### 조사 11 — repo-researcher · R8 · 묶음 9

레포 루트: /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs (아래 path 는 이 루트 기준 상대경로). 구현 · 테스트 본문을 읽고 낸 주장이다.

```yaml
repo_claims:
  # ── (1) 옮김 대조 · (a)/(b) 꼴 ──────────────────────────────────────────
  - id: RC1
    path: "plugins/spec-distill/agents/relay-checker.md"
    anchor: "## 볼 것 (1–5)"
    line: 29
    claim: "대조 항목은 다섯뿐이다 — 선택지 수 · 순서 · 꼬리를 뗀 라벨의 글자 일치 · 「(권장)」 꼬리의 출처(원문 꼬리 빠짐 / 출처 없는 꼬리 / 지휘자 의견이 선택지 설명 안에 들어감) · 돌려보낸 글에 원문 라벨이 글자 그대로 있는가. 쉬운 요약(배경)의 뜻이나 선택지 설명의 문장 · 내용을 원문과 대조하는 항목은 없다. 판정은 파일마다 「일치 | 어긋남」이고 읽지 못한 것은 「확인 못 함」으로 따로 낸다."
    touches: []
    decides: [OQ19, OQ18]
  - id: RC2
    path: "plugins/spec-distill/skills/epic-conductor/SKILL.md"
    anchor: "### 7. 옮김 대조"
    line: 190
    claim: "relay-checker 는 에픽이 끝난 뒤(걸음 6) 그 에픽의 `relay-*.md` 파일만 입력으로 받아 불린다 — 사용자가 질문을 보기 전이 아니라 사후 대조다. 결과 전부를 사용자에게 보이고 어긋남은 설계문서 `## 지휘 기록` 에 적는다(처분 줄: consumer=orchestrator · fail-closed). tools 는 `Read, Grep, Glob` 뿐이다."
    touches: []
    decides: [OQ19]
  - id: RC3
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "## 사람 자리 — 「(a) 사람에게 보일 쉬운 요약」 · 「(b) skill 이 낸 문면 원문」"
    line: 28
    claim: "하위는 (a) 쉬운 요약(무엇을 정하나 · 고르면 무엇이 달라지나 · 배경)과 (b) 원문(앞 글 · 경고 · 질문 · 선택지)을 함께 돌려보낸다. 지휘자는 선택지의 수 · 순서 · 라벨 글자를 (b) 그대로 두고, 「원문은 늘 붙인다」, 「선택지 설명을 옮길 때 원문의 문장을 하나도 빼지 않는다 — 번역해도 문장 수를 지킨다」, 지휘자 의견은 선택지 밖 「지휘자 의견:」 한 줄로만 쓴다. 받은 원문 · 띄운 질문 · 답 · 돌려보낸 글을 `relay-<번호>.md` 에 남긴다."
    touches: []
    decides: [OQ19, OQ18]
  - id: RC4
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "「쓰기 권한 없는 agent 가 둘의 선택지 수 · 라벨 · 순서를 대조한다」"
    line: 32
    claim: "이 문서가 스스로 적는 대조 범위는 선택지 수 · 라벨 · 순서다. 같은 문단의 「문장 수를 지킨다」 · 「고르면 무엇이 달라지나를 빠뜨리지 않는다」 규칙은 RC1 의 대조 항목에 짝이 없어 산문 규칙으로만 선다."
    touches: []
    decides: [OQ19]
  - id: RC5
    path: "plugins/spec-distill/tests/test_conductor_dispatch_reference.sh"
    anchor: "once '## 사람 자리' \"$lit\" 루프"
    line: 24
    claim: "(a)/(b) 꼴과 옮김 규칙 문장들(「원문은 늘 붙인다」 · 「문장 수를 지킨다」 · 꼬리 규칙 등)이 `## 사람 자리` 절에 정확히 한 번 있는지를 부분 문자열로 잰다. relay-checker 본문은 `plugins/spec-distill/tests/test_epic_conductor_skill.sh` 65–90행이 tools · 대조 항목 문장의 실재(양)와 옛 문장 부재(음)로 잠그고, `conducting.md` 걸음 4 의 같은 규칙은 `test_conducting_reference.sh` 117 · 152행이 잠근다. 셋 다 문구의 실재만 재는 정적 락이다."
    touches: []
    decides: [OQ19, OQ18]

  # ── (2) 리뷰어의 세 칸 정의와 락 ─────────────────────────────────────────
  - id: RC6
    path: "plugins/spec-distill/agents/doc-critic.md"
    anchor: "## 출력 형식 — 「`summary`(한 문장)」 · 「`if_unfixed`(「그대로 두면 무엇이 남는가」 — 문제의 재진술이 아니라 **결과**)」"
    line: 68
    claim: "`summary` 는 「한 문장」이고 「내부 기호 없이 무엇이 문제인지 문장으로」 쓰는 칸이다 — 결과는 따로 `if_unfixed`(재진술이 아니라 결과), 고친 뒤 모습은 `replacement`(`decide` 에 필수, 삭제 제안은 「대체안 없음 — 그냥 뺀다」를 명시)에 담는다. 즉 정의상 `summary` 한 칸은 결과를 담지 않는다. 세 칸은 「게이트에 그대로 실려 처음 보는 사람이 읽는다」고 적혀 있고 `evidence` 만 원문 그대로다."
    touches: []
    decides: [OQ19, OQ15]
  - id: RC7
    path: "plugins/spec-distill/references/docreview-profiles/brief.md"
    anchor: "「finding 하나마다 사용자가 결정할 질문 하나를 `summary` 에 담고 처분은 `decide` 다」"
    line: 21
    claim: "brief 프로필 층 1 은 `summary` 를 「사용자가 결정할 질문 하나」로 정의한다 — RC6 의 「무엇이 문제인지」 와 다른 정의다. 같은 파일 45행 · design-doc.md 61행의 「필드 사상」은 overdesign 판정의 `<태그> <무엇이 과한가>` 를 `summary` 에 「문장 그대로」, 대안과 천장을 `replacement` 한 줄에, 결과를 `if_unfixed` 에 싣게 하고, design-doc.md 112행은 「무엇이 문제인지는 `summary`」 라고 적는다. seed.md 에는 세 칸 언급이 없다."
    touches: []
    decides: [OQ19, OQ15]
  - id: RC8
    path: "plugins/spec-distill/agents/doc-recritic.md"
    anchor: "「critic 항목과 **같은 칸을 싣는다** — `replacement`·`if_unfixed` 도 그렇다」"
    line: 58
    claim: "재비판자의 `added` 항목도 같은 세 칸을 싣고 「처음 보는 사람이 읽는다 — 내부 번호 없이 쉬운 말로」 쓴다. doc-critic-web.md 74행은 doc-critic 과 같은 문단이다. 플러그인 쪽 셋은 `shared/docreview/agents/` 정본의 `copy-of` 사본이다."
    touches: []
    decides: [OQ19]
  - id: RC9
    path: "shared/codex/codex_findings_to_yaml.py"
    anchor: "DOCREVIEW_KEYS"
    line: 73
    claim: "codex 출력의 `summary` · `replacement` · `if_unfixed` 는 이 키 목록에 있어야 YAML 로 넘어가고(주석: 없으면 「codex 가 적은 값이 이 변환에서 버려진다」), 값은 `_yaml_scalar` 인용만 거쳐 글자 그대로 나간다. codex 에게 주는 정의는 `shared/docreview/scripts/run_docreview_codex_reviewer.sh` 447–454행에 영어로 같다(「the consequence, not a restatement of the problem」). 운반을 잠근 테스트는 `plugins/spec-distill/tests/test_codex_findings_to_yaml.py` 288행 `test_docreview_keyset_carries_replacement_and_if_unfixed` 다."
    touches: []
    decides: [OQ19]
  - id: RC10
    path: "shared/tests/test_docreview_agent_fields.sh"
    anchor: "AC19 · AC19″ · PLAIN_LINE · FIRST_LINE"
    line: 44
    claim: "잠근 것: `replacement` 가 decide 에 필수 · `if_unfixed(` 칸의 실재 · 삭제 제안 문구 · 「빈 칸은 삭제 제안이 아니다」 · 예시 항목의 두 줄 · 「처음 보는 사람이 읽는다 — 내부 번호 없이 쉬운 말로 쓴다」 · 「항목 첫 줄(summary)은 … 무엇이 문제인지 문장으로 쓴다」 · codex 프롬프트의 `read by a first-time reader`. 「`summary`(한 문장)」 과 「문제의 재진술이 아니라 결과」 는 어느 테스트에도 핀이 없고(tests 전수 grep 0건), 길이 규칙을 재는 락도 없다. 파일 머리가 「부분 문자열 핀이라 문장 뒤에 붙인 부정은 못 잡는다」 고 한계를 적는다."
    touches: []
    decides: [OQ19, OQ15]
  - id: RC11
    path: "plugins/spec-distill/tests/test_overdesign_rubric.sh"
    anchor: "field_mapping_line_of — 「필드 사상」"
    line: 246
    claim: "프로필의 「필드 사상」 문단은 이 테스트가 잠근다 — 천장의 목적지가 `replacement` 라는 것과 「개행 없이」 규칙을 brief · design-doc 양쪽에서 잰다."
    touches: []
    decides: []

  # ── (3) 엔진 렌더와 저자의 바꿔 쓰기 ─────────────────────────────────────
  - id: RC12
    path: "shared/docreview/scripts/docreview_state.py"
    anchor: "_rg_decide"
    line: 2295
    claim: "열린 결정 한 항목은 여섯 줄로 난다 — 머리 `- <summary> (<id>)`, `  그대로 두면: <if_unfixed>`, `  고치면: <replacement>`, 근거, 자리, 대안. 세 칸은 `_one`(공백 · 개행을 한 칸으로 접기, 2223행)만 거치고 자르거나 바꾸지 않는다. 결정이 아닌 행(`_rg_adopted` · `_rg_unapplied_fix` · `_rg_blocking_ask` · `_rg_ask_open` 등)은 `summary` 한 줄만 내고 `if_unfixed` · `replacement` 는 내지 않는다."
    touches: []
    decides: [OQ19]
  - id: RC13
    path: "shared/docreview/scripts/docreview_route.py"
    anchor: "decision_view 조립 — 「**부재를 summary 로 메우지 않는다**」"
    line: 511
    claim: "리뷰어가 칸을 비우면 엔진은 `(리뷰어가 안 적음)` · `(대체안 미작성)` 리터럴을 싣고 summary 로 메우지 않는다. 정규화(`normalize` 185행)는 summary 를 strip 만 하고, `_classify_items`(755행)가 `replacement` · `if_unfixed` 의 공백 · 개행만 접으며 그 접기를 coerced 로 센다. 잠금: `shared/tests/fixtures/docreview/cases.sh` 의 `case_gate_render_six_lines`(3313행, AC16) · `case_I4_summary_newline_collapsed`(3566행 — 원장 값은 그대로, 접기는 렌더에서만)."
    touches: []
    decides: [OQ19]
  - id: RC14
    path: "shared/docreview/scripts/docreview_advice.py"
    anchor: "clip · render_lines · sink_row"
    line: 166
    claim: "끝의 참고(advisory) 목록은 엔진이 `summary` 를 `summary_width`(기본 60자 — `docreview_config.py` DEFAULTS, 환경 변수 · 프로필로 바꿈) 에서 잘라 `…` 를 붙인다. 머리 줄이 전문의 자리(`전문: <박제처>`)와 폭 값 · 출처를 밝히고, 박제 행(`sink_row`)은 summary 전문 + 「 — 고치면: <replacement>」 를 싣되 `if_unfixed` 는 싣지 않는다."
    touches: []
    decides: [OQ19]
  - id: RC15
    path: "shared/docreview/references/reviewing-document.md"
    anchor: "「**`AskUserQuestion` 라벨의 항목별 내용**」"
    line: 42
    claim: "절차서는 저자(오케스트레이터)에게 줄이기를 요구한다 — 선택지 라벨은 「상태별 라벨 + `— <replacement 를 1–5 낱말로 압축>`」 이고 「압축은 필수」 이며 근거는 「렌더의 「고치면」 줄이 전문을 이미 내므로 라벨은 그 줄을 가리키는 손잡이」 다. 같은 문단이 spec-review SKILL.md 574행에 있다. 잠금은 `shared/tests/test_docreview_round_gate_split.sh` 축 5(95–108행)인데, 그 머리와 spec-distill CHANGELOG 1191행이 「규약의 실재만 재고 오케스트레이터가 런타임에 지키는지는 못 잰다 — 라벨을 짓는 것은 엔진이 아니라 런타임의 오케스트레이터」 라고 한계를 적는다."
    touches: []
    decides: [OQ19]
  - id: RC16
    path: "shared/docreview/references/reviewing-document.md"
    anchor: "8. **게이트** — 「질문 본문에는 그 질문의 결정 하나와 … 한 줄만 둔다」"
    line: 27
    claim: "이 절차서에서 글자 그대로 쓰라고 명시한 것은 렌더 첫 줄(앞 글에 한 번) · 「고친다(채택)는 고를 수 없다」 줄(86행 「그 줄을 그대로 옮긴다」) · 승인 선택지 이름 「열린 지적 N개를 두고 진행」 셋이다. 항목 줄(summary · 그대로 두면 · 고치면)을 질문 본문이나 선택지 설명에 어떻게 싣는지 — 그대로인지 줄여도 되는지 — 를 정한 문장은 없다. 리뷰어 출력을 파일로 저장할 때는 「verbatim」 이다(3 · 6단계, spec-review SKILL.md 509행 「요약·전사 없이」)."
    touches: []
    decides: [OQ19]
  - id: RC17
    path: "shared/style/plain-language.md"
    anchor: "「스크립트·subagent 가 낸 원문은 고치지 않는다」"
    line: 9
    claim: "모든 SKILL.md 에 복제되는 쉬운 말 블록이 「판정·개수·공시 줄은 스크립트가 낸 쉬운 첫 줄을 그대로 쓰고, 자기 말로 다시 풀거나 덧붙이지 않는다. 스크립트·subagent 가 낸 원문은 고치지 않는다」 고 금지한다. 같은 블록 3행은 「아래 절차가 출력 형식·원문 보존·분량을 따로 정한 자리에서는 그 절차를 따른다」 로 절차에 양보한다 — RC15 의 라벨 압축이 그런 자리다. 블록 동일성은 `shared/tests/test_plain_language_block.sh` 가 잠근다."
    touches: []
    decides: [OQ19, OQ18]
  - id: RC18
    path: "plugins/spec-distill/skills/request-framing/SKILL.md"
    anchor: "「덩어리 본문(`render`)은 질문 텍스트에 줄임 없이 싣는다 — 분량 상한을 두지 않는다(줄이면 공시가 아니다)」"
    line: 935
    claim: "줄이기를 명시로 금지한 이웃 자리가 있다 — 저자 편집 덩어리는 질문에 그대로 싣는다. 같은 계열로 `plugins/spec-distill/skills/pm-interview/references/steelman.md` 94행 「builder 출력을 약화·편집하지 않는다 — verbatim 계약」, `plugins/quality-gates/skills/quality-pipeline/SKILL.md` 560행 「각 항목의 `plain:` 은 리뷰어가 쓴 문장 그대로 싣는다 — 없으면 키를 뺀다(지어내지 않는다)」 가 있고 뒤의 것은 `plugins/quality-gates/tests/test_plain_field_path.sh` 35행이 잠근다."
    touches: []
    decides: [OQ19]

  # ── (4) CLAUDE.md 의 요구 ────────────────────────────────────────────────
  - id: RC19
    path: "CLAUDE.md"
    anchor: "**Law 2 — Writer and Reviewer Must Never Share a Pass.**"
    line: 26
    claim: "Law 2 가 요구하는 것은 `tools:` allowlist 로 리뷰어가 Write/Edit 을 갖지 못하게 하는 물리 분리다(48행 Scoped agents 가 같은 집행 지점을 적는다). 리뷰어 출력의 칸이나 길이에 대한 요구는 이 문장들에 없다."
    touches: []
    decides: [OQ19]
  - id: RC20
    path: "CLAUDE.md"
    anchor: "**Persona 파일은 보안-민감 코드.**"
    line: 78
    claim: "「Reviewer persona를 약화(규칙 제거, 임계치 완화)하는 PR은 보안 리뷰 대상. test-suite 편집과 같은 신중함으로 persona 편집을 treat.」 — 보안 리뷰는 약화에 걸리고, 모든 persona 편집에는 테스트 편집 수준의 신중함이 걸린다. 칸 · 길이 규칙을 «더하는» 편집이 약화인지는 이 문장이 정하지 않는다. 97행은 리뷰를 탈출한 버그의 기본 수리 자리가 persona 파일이라고 적는다."
    touches: []
    decides: [OQ19]
  - id: RC21
    path: "shared/tests/test_copy_of_contract.sh"
    anchor: "(b) copy-of 물리 사본 — 「그 줄만 제외하고 바이트가 같아야 한다」"
    line: 10
    claim: "리뷰어에 칸을 더하면 구현이 요구하는 자리가 여럿이다 — 정본(`shared/docreview/agents/`)과 플러그인 사본의 바이트 일치, doc-critic-web 의 variant-of 대조(`shared/tests/test_docreview_agents.sh` 92–93행), 그리고 칸이 버려지지 않게 `DOCREVIEW_KEYS`(codex_findings_to_yaml.py 73행) · `normalize` 반환 dict(docreview_route.py 224–239행 「여기 없으면 … 조용히 버려진다」) · `PUBLIC_FIELDS`(docreview_state.py 1110행) · codex 프롬프트(run_docreview_codex_reviewer.sh 447–460행)에 함께 넣어야 한다."
    touches: []
    decides: [OQ19]
unanswered: "문서 리뷰 게이트에서 저자가 실제로 띄운 질문 글을 리뷰어의 세 칸과 대조하는 장치는 찾지 못했다(relay-checker 는 지휘자의 relay 파일만 받는다) — 다만 spec-review · reviewing-brief SKILL.md 전문, plain_language_block.py, golden 픽스처는 끝까지 읽지 않아 그 안의 문장은 확인 못 함. OQ13(화면에 보이는 양) · OQ16 · OQ17 은 이 질문의 범위에서 레포가 답하지 않는다."
```

충돌로 둘 다 낸 것: RC6(summary = 무엇이 문제인지) 대 RC7(brief 층 1 의 summary = 사용자가 결정할 질문 하나), RC17(원문은 고치지 않는다) 대 RC15(replacement 를 1–5 낱말로 압축 — 필수).

### 조사 12 — repo-researcher · R8 · 묶음 9

레포 루트: /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs (아래 `path` 는 이 루트 기준 상대경로). 읽기 도구만 있어 git 이력과 테스트 실행은 하지 않았다 — 전부 파일 본문을 읽은 결과다.

```yaml
repo_claims:
  # ── (1) 낮춘 지적 게이트 — 접는 규칙의 출처와 락 ─────────────────────────
  - id: RC1
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "**낮춘 지적 게이트 (표면화 뒤 · 라우팅 앞).**"
    line: 707
    claim: "게이트는 707–731행이다(질문 펜스 711–718). n ≤ 3 은 지적마다 `{label: \"<파일 이름>:<줄> (L<k>)\", description: \"<낮춘 이유를 쉬운 말 한 줄로>\"}` + 「그대로 둔다」(multiSelect true), n ≥ 4 는 `{label: \"전부 되올린다\", description: \"낮춘 지적 <n>개를 모두 원래 심각도로 되돌린다.\"}` · `{label: \"그대로 둔다\", description: \"낮춘 대로 둔다.\"}` 둘(multiSelect false)이고 「일부만이면 「기타」에 번호(예: L1, L3)」다. 항목별 내용은 질문에 없고 질문 본문이 「(위 「낮춘 지적」 절)」로 가리키며, 708–709행이 「「낮춘 지적」 절은 위 원문 표면화로 이미 보였다」고 적는다."
    touches: []
    decides: [OQ16, OQ19]
  - id: RC2
    path: "docs/superpowers/plans/2026-10-19-r2a-plan3-qg-devices-range-persona.md"
    anchor: "n ≥ 4: {label: \"전부 되올린다\", …} · {label: \"그대로 둔다\", …} — 일부만이면 「기타」에 번호(예: L1, L3)>,"
    line: 768
    claim: "n ≤ 3 / n ≥ 4 로 가르는 꼴이 처음 나오는 자리는 이 계획의 Task 9 펜스(763–769행, 당시 `multiSelect: true`)이고, 왜 넷에서 접는지 적은 문장은 그 계획에 없다. 상위 설계(`docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md` 104 · 179 · 272행)는 「게이트에서 되올릴 것을 여러 개 고름」 · 「되올리기(multiSelect)」 · AC26 「게이트에서 여러 개를 되올릴 수 있다」까지만 정하고 접기는 정하지 않는다. 같은 설계 122행의 「질문 도구의 선택지 4개 제약 · 화면 범람」은 e2e 시나리오 행의 이유이지 이 게이트의 이유로 적힌 것이 아니다."
    touches: []
    decides: [OQ16]
  - id: RC3
    path: "docs/superpowers/specs/2026-10-25-qg-range-repairs-design.md"
    anchor: "고를 지적이 넷 이상인 낮춘 지적 게이트(SKILL :716 `multiSelect: true`)는 「그대로 둔다」 와 「전부 되올린다」 를 함께 고를 수 없게 단일 선택으로 바꾼다."
    line: 95
    claim: "설계문서가 이 게이트의 n ≥ 4 에 대해 이유와 함께 정한 것은 「하나만 고른다」뿐이다(「작은 수리 셋(실행 경험)」 목록의 한 줄). `plugins/quality-gates/CHANGELOG.md` 28행([14.7.4] Fixed)이 같은 것을 「낮춘 지적이 넷 이상일 때 게이트가 여러 선택이라 「전부 되올린다」 와 「그대로 둔다」 를 함께 고를 수 있던 것 — 하나만 고른다.」로 적는다. AC26 의 「여러 개를 되올릴 수 있다」와는 n ≥ 4 에서 어긋난다 — 그때 일부 되올리기는 「기타」 칸 번호로만 된다(둘 다 낸다)."
    touches: []
    decides: [OQ16]
  - id: RC4
    path: "plugins/quality-gates/CHANGELOG.md"
    anchor: "- 「낮춘 지적」 — 재비판이 낮춘 지적을 합성기가 번호(`L<k>`) · 원래 심각도 · 이유와 함께 `## 낮춘 지적` 절과 `lowered:` 줄로 싣는다."
    line: 146
    claim: "게이트를 들인 [14.1.0] Added 항목은 번호 · 원래 심각도 · 이유를 절로 싣는 것, 반복마다 되올리는 것, 「기타」 칸 번호 대조만 적는다. 넷 이상에서 선택지를 둘로 접는다는 말도 그 이유도 CHANGELOG 어디에도 없다(「넷 이상」이 나오는 줄은 28행 하나)."
    touches: []
    decides: [OQ16]
  - id: RC5
    path: "plugins/quality-gates/scripts/synthesize_findings.py"
    anchor: "_lowered_lines"
    line: 713
    claim: "질문이 가리키는 「낮춘 지적」 절은 합성기가 `| 번호 | 위치 | 원래 심각도 | 내용 | 낮춘 이유 |` 표로 낸다(되올린 행은 이유 칸 머리에 `(사용자가 되올림)`). 접힌 질문에서 항목별 내용이 지금 실리는 자리는 질문 창 밖의 이 표 하나다."
    touches: []
    decides: [OQ16]
  - id: RC6
    path: "plugins/quality-gates/tests/test_plain_qg_templates.sh"
    anchor: "AC26: 낮춘 지적 게이트 질문이 한국어다"
    line: 50
    claim: "이 파일이 낮춘 지적 게이트에서 잠근 것은 둘뿐이다 — 50행이 `question:` 줄 전체를 글자째(「재비판이 심각도를 낮춘 지적이 <n>개 있다(위 「낮춘 지적」 절). 되올릴 것을 고르세요 — 되올리면 원래 심각도로 판정에 들어간다.」), 51행이 SKILL 의 `question:` 줄 수를 정확히 6 으로 잠근다. 이 게이트의 header · 선택지 라벨 · 설명 · 「추천을 달지 않는다」 문장은 이 파일에 없다(질문 줄을 더하거나 본문 글자를 바꾸면 여기서 RED)."
    touches: []
    decides: [OQ16, OQ17]
  - id: RC7
    path: "plugins/quality-gates/tests/test_lowered_gate_wiring.sh"
    anchor: "case_step45_gate"
    line: 49
    claim: "선택지 쪽은 이 파일이 Step 4.5 창 안에서 잠근다(51–82행): `header: \"낮춘 지적\",`(SKILL 전체 1회) · `multiSelect: <n ≤ 3: true · n ≥ 4: false> }] })` · `n ≤ 3: 지적마다 {label: \"<파일 이름>:<줄> (L<k>)\"` · `n ≥ 4: {label: \"전부 되올린다\"` · `{label: \"그대로 둔다\", description: \"낮춘 대로 둔다.\"}` · `일부만이면 「기타」에 번호(예: L1, L3)` · 갈래 문장들 · 게이트가 차등 요약 뒤 라우팅 앞이라는 순서. 잠기지 않은 글자는 n ≤ 3 의 설명 `<낮춘 이유를 쉬운 말 한 줄로>` 와 「전부 되올린다」의 설명 「낮춘 지적 <n>개를 모두 원래 심각도로 되돌린다.」 둘이다."
    touches: []
    decides: [OQ16, OQ19]

  # ── (2) ask-sites.tsv 「비움」 행 가운데 리뷰 뒤 질문 다섯 ─────────────────
  - id: RC8
    path: "shared/tests/ask_recommendation.py"
    anchor: "EMPTY = \"추천을 달지 않는다 — \""
    line: 26
    claim: "「비움」 행에 검사가 요구하는 것은 범위 안에 글자 「추천을 달지 않는다 — 」가 있고 「(권장)」 · 「(Recommended)」 꼬리가 없으며, 범위 안 `AskUserQuestion` 자리 수가 「덮는 수」 칸과 같은 것뿐이다(`required` 118–122행 · `check` 211–216행). 대시 뒤 이유의 내용, 질문 본문, 선택지 설명은 보지 않는다."
    touches: []
    decides: [OQ17]
  - id: RC9
    path: "plugins/spec-distill/skills/request-framing/SKILL.md"
    anchor: "- 덩어리가 있으면 **덩어리마다 질문 하나** — 「그대로 둔다 / 되돌린다」."
    line: 933
    claim: "저자 편집 덩어리(tsv 87행 · 끝 「덩어리 본문(`render`)은 질문 텍스트에」 · 덮는 수 빈칸): 「추천을 달지 않는다 — 어느 덩어리가 승인된 수정인지 가를 기계가 없고, 저자의 권장은 바로 그 가름을 저자가 하는 것이다.」 질문 본문은 「덩어리 본문(`render`)은 질문 텍스트에 줄임 없이 싣는다 — 분량 상한을 두지 않는다(줄이면 공시가 아니다). 이 덩어리 본문은 규칙 블록의 「따로 정한 자리」다 — 「질문 본문엔 결정과 상태 한 줄만」의 예외로, 결정의 대상 자체라 질문에 그대로 싣는다.」로 정하고, 선택지 설명에 무엇을 실을지는 정하지 않는다. 락은 `plugins/spec-distill/tests/test_framing_review_contract.sh` 107행(「덩어리마다 질문 하나」) · 141행(「추천을 달지 않는다 — 」)까지다."
    touches: []
    decides: [OQ17]
  - id: RC10
    path: "plugins/spec-distill/skills/request-framing/SKILL.md"
    anchor: "- 기준 사본이 없으면(rc 3 — 원장이 정리됐다) 그 사실을 게이트 앞 글에 쓰고 seed 전문을 한 질문으로"
    line: 937
    claim: "기준 사본 없음(tsv 88행 · 끝 「처분을 받은 뒤 순서가 계약입니다」): 「그 사실을 게이트 앞 글에 쓰고 seed 전문을 한 질문으로 보여 「이대로 둔다 / 멈춘다」를 묻는다. 「이대로 둔다」면 `seed_edit_diff.py init` 으로 새 기준 사본을 뜬다. 추천을 달지 않는다 — 기준 사본이 없어 저자 편집이 섞였는지 가를 수 없고, 권하면 저자가 자기 편집을 스스로 승인한다.」 사유는 질문 밖(게이트 앞 글), 질문에는 seed 전문이고 선택지 설명은 정하지 않는다."
    touches: []
    decides: [OQ17]
  - id: RC11
    path: "plugins/spec-distill/skills/request-framing/SKILL.md"
    anchor: "덜어 낸 것이 1개 이상이면 `AskUserQuestion` 한 번으로 묻습니다"
    line: 1175
    claim: "덜어 낸 것(tsv 91행 · 끝 「되살린 항목은 seed 에」 · 덮는 수 1): 「「되살리기」(고르면 이어서 되살릴 항목을 번호로 고르게 한다. 항목이 넷을 넘으면 `### 확인 질문` 처럼 넷씩 나눈다) · 「그대로 둔다」. 추천을 달지 않는다 — 덜어 낸 것은 저자의 압축 편집이라, 권하면 저자가 자기 편집을 남길지 스스로 정한다.」 질문 본문 문면과 선택지 설명은 정하지 않고, 항목 내용은 질문 앞 공시 줄 `seed 에서 덜어 낸 것 <N>개 — <번호 · 한 줄 이유>`(1168행)에 있다. 넷을 넘을 때 접지 않고 넷씩 나누는 점이 낮춘 지적 게이트(RC1)와 다르다."
    touches: []
    decides: [OQ16, OQ17]
  - id: RC12
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "추천을 달지 않는다 — 낮춘 지적을 되올릴지는 리뷰 대상 코드를 쓴 쪽이 권할 수 없는 처분이다."
    line: 720
    claim: "낮춘 지적 게이트(tsv 120행 · 앵커 「**낮춘 지적 게이트 (표면화 뒤 · 라우팅 앞).**」 · 끝 「- 지적을 하나도 고르지 않았다」 · 덮는 수 1)의 비움 사유 문장이다. 질문 본문과 설명에 싣는 것은 RC1 의 펜스 그대로 — 본문은 개수 · 위 절 가리킴 · 되올리면 생기는 일, 설명은 n ≤ 3 일 때만 지적별 낮춘 이유 한 줄이다."
    touches: []
    decides: [OQ16, OQ17]
  - id: RC13
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "question: \"분류표의 적용/제외를 바꿀까요? 바꿀 항목 번호는 「기타」에 적는다(예: 2, 5).\","
    line: 861
    claim: "분류 질문(tsv 124행 · 끝 「Branch on answer:」 · 덮는 수 빈칸): header 「분류」, 선택지 `{label: \"분류표 그대로\", description: \"표의 적용/제외대로 고친다.\"}` · `{label: \"SUGGESTION 도 전부 적용\", description: \"SUGGESTION 으로 제외된 항목을 모두 적용으로 바꾼다.\"}`, 873행 「둘째 질문(분류)에는 추천을 달지 않는다 — 분류표는 오케스트레이터가 자기 코드의 지적에 매긴 적용/제외다.」 항목별 내용은 질문에 없고 번호를 「기타」로 받는다(875–877행). `test_plain_qg_templates.sh` 가 잠근 것은 질문 줄 앞머리(47행) · 라벨 「분류표 그대로」(54행) · header(58행) · 그 설명(64행)이고, 둘째 선택지의 라벨 · 설명은 테스트 어디에도 없다."
    touches: []
    decides: [OQ17]

  # ── (3) 「지휘자 의견:」 한 줄 ────────────────────────────────────────────
  - id: RC14
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "지휘자 의견은 선택지 밖 「지휘자 의견:」 한 줄로만 쓴다."
    line: 32
    claim: "`## 사람 자리` 절의 한 문단(32행)에 그 줄을 정한 문장이 둘 있다 — 위 앵커와 「지휘자가 꼬리를 달면 선택지 밖 「지휘자 의견:」 한 줄에 어느 꼬리가 지휘자의 것인지와 이유를 쓴다.」 같은 문단이 「각 선택지 설명에 원문의 「고르면 무엇이 달라지나」 를 빠뜨리지 않는다」 · 「선택지 설명을 옮길 때 원문의 문장을 하나도 빼지 않는다 — 번역해도 문장 수를 지킨다.」도 정한다."
    touches: []
    decides: [OQ18, OQ19]
  - id: RC15
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "지휘 세션의 의견은 선택지 밖 「지휘자 의견:」 한 줄로만 쓰고"
    line: 102
    claim: "손 절차 걸음 4(「superpowers 가 묻는 자리」)가 같은 규칙을 다시 적는다 — 이어서 「지휘자가 단 꼬리는 그 의견 줄에 어느 꼬리가 지휘자의 것인지와 이유를 쓰고, 원문은 늘 붙인다」. 이 걸음 안에 「「지휘자 의견:」 한 줄」 글자는 한 번뿐이다(둘째는 「그 의견 줄」)."
    touches: []
    decides: [OQ18]
  - id: RC16
    path: "plugins/spec-distill/agents/relay-checker.md"
    anchor: "지휘자 의견이 선택지 설명 안으로 들어갔으면 어긋남이다(「지휘자 의견:」 은 선택지 밖 한 줄이다)."
    line: 34
    claim: "대조 규칙 4(34행)가 그 줄을 두 번 쓴다 — 원문에 없던 꼬리가 일치인 조건(「「지휘자 의견:」 줄이 그 선택지를 지휘자 권장으로 밝히고 이유를 단 경우」)과 위 앵커. 37행은 「지휘자가 만든 질문」에도 「지휘자 의견이 선택지 설명 안에 들어간 것만 어긋남이다」를 건다 — 의견 줄에 실을 것을 선택지 설명으로 옮기면 이 persona(보안-민감 파일) 두 자리가 함께 바뀌어야 한다."
    touches: []
    decides: [OQ18]
  - id: RC17
    path: "plugins/spec-distill/tests/test_conductor_dispatch_reference.sh"
    anchor: "once '## 사람 자리' \"$lit\""
    line: 26
    claim: "글자째 잠근 테스트는 셋이다. (가) 이 파일 26행 「「지휘자 의견:」 한 줄로만 쓴다」 · 32행 「지휘자가 꼬리를 달면 선택지 밖 「지휘자 의견:」 한 줄에 어느 꼬리가 지휘자의 것인지와 이유를 쓴다.」 — 둘 다 `## 사람 자리` 절에서 정확히 1회(`grep -oF | wc -l`). (나) `plugins/spec-distill/tests/test_conducting_reference.sh` 117–119행 — 걸음 4 에서 「「지휘자 의견:」 한 줄」 · 「어느 꼬리가 지휘자의 것인지와 이유」 · 「「고르면 무엇이 달라지나」(그대로 두면 · 고치면)」 각 정확히 1회. (다) `plugins/spec-distill/tests/test_epic_conductor_skill.sh` 79 · 81 · 83행 — relay-checker.md 의 세 문장 전체를 `assert_contains` 로(있음만, 횟수 아님)."
    touches: []
    decides: [OQ18]
  - id: RC18
    path: "docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md"
    anchor: "그리고 「지휘자 의견:」 줄에 어느 꼬리가 지휘자의 것인지와 이유를 쓴다(필수 — 출처 꼬리는 steelman 에만 쓰므로(D11) 출처는 라벨이 아니라 이 줄이 밝힌다)."
    line: 115
    claim: "지금 문면의 출처는 이 설계 115 · 122행이다 — 의견 줄은 「어느 꼬리가 지휘자 것인지」를 밝히는 출처 표지 구실로 필수이고, 「지휘자 의견이 선택지 **설명** 안으로 들어간 것은 여전히 어긋남」으로 남겼다. 규범이 아닌 되비춤은 `plugins/spec-distill/CHANGELOG.md` 31행 하나이고, epic-conductor SKILL.md 본문에는 이 글자가 없다."
    touches: []
    decides: [OQ18]

  # ── (4) 「이유는 질문 위 글에」 락 · token_boundary.py ────────────────────
  - id: RC19
    path: "shared/tests/test_plain_language_block.sh"
    anchor: "REC='추천이 있으면 그 선택지를 첫 자리에 두고 라벨 끝에 「(권장)」을 단다 — 여럿이면 모두, 이유는 질문 위 글에. 추천이 없으면 아무 표시도 쓰지 않는다.'"
    line: 30
    claim: "정본 락이다 — 30행의 두 문장 전체를 32행이 `grep -cF` 로 `shared/style/plain-language.md` 에서 세어 정확히 1(줄 수)이어야 한다. 구절 하나만 바꿔도 이 리터럴과 함께 고쳐야 한다."
    touches: []
    decides: [OQ18]
  - id: RC20
    path: "shared/tests/plain_language_block.py"
    anchor: "if region != canon:"
    line: 51
    claim: "`test_plain_language_block.sh` 54행이 부르는 판정 모듈로, 글롭(`plugins/*/skills/*/SKILL.md` · `plugins/*/commands/*.md`)에서 도출한 대상마다 표시 줄 한 쌍 · H1 바로 다음 자리 · 표시 줄 사이 바이트가 정본과 같은지를 본다. 지금 그 구절을 가진 사본은 SKILL.md 10개다(spec-distill 6: spec-review · pm-interview · reviewing-brief · request-framing · epic-conductor · roadmap-status / quality-gates 2: quality-pipeline · artifact-critique / project-init · plugin-audit) — 정본을 고치면 열이 같은 커밋에서 같은 바이트로 바뀌어야 한다."
    touches: []
    decides: [OQ18]
  - id: RC21
    path: "plugins/spec-distill/tests/test_review_handoff_order.sh"
    anchor: "'라벨에 「(권장)」을 달고 이유는 질문 위 글에 한 줄로 쓴다'"
    line: 191
    claim: "정본 밖에서 그 구절을 잠근 유일한 테스트다 — spec-review SKILL.md 702행(③ 로드맵 갈래 문단 창)에 이 글자가 있는지 `assert_contains` 로 본다. 같은 구절을 쓰는 `plugins/spec-distill/skills/pm-interview/references/saturation.md` 35행(「이유는 질문 위 글에 한 줄로 쓴다」)은 어느 테스트도 잠그지 않는다. 형제 구절 「제안 이유는 게이트 앞 글(에)」는 `test_end_gates.sh` 47행 · `test_request_framing_open.sh` 104행이 따로 잠근다."
    touches: []
    decides: [OQ18]
  - id: RC22
    path: "tools/plain-language/token_boundary.py"
    anchor: "def main(argv=None):"
    line: 47
    claim: "입력은 `--base <rev>`(필수) · `--body`(frontmatter 빼고 재기)이고, 레포 루트 cwd 에서 `git ls-files` 로 SKILL.md · commands 를 도출해 파일마다 `git show <base>:<경로>`(넣기 전)와 작업 트리(넣은 뒤)를 견준다. 출력은 첫 줄 「블록 근사 토큰: cons N · cent M」과 파일 × 프로필(cons · cent)마다 한 줄 — 「파일 전체가 5000토큰 미만 — 밀린 절 없음」 또는 「경계 L.. → L.. · 새로 밀린 절: … · 경계가 걸친 절: …」이고 rc 는 늘 0 이다(통과 · 실패를 내지 않는 측정). 토큰은 근사식(한글 음절 · 그 밖 비ASCII · ASCII/3.0 또는 /3.7)이고 실제 tokenizer 로 보정하지 않았다고 머리말이 적는다 — base 에 없던 파일은 `check=True` 라 예외로 죽을 것으로 읽힌다(실행해 보지 않음)."
    touches: []
    decides: [OQ18]
  - id: RC23
    path: "plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh"
    anchor: "import token_boundary as tb; L=io.open(sys.argv[1],encoding=\"utf-8\").read().split(\"\\n\"); b=tb.boundary(L,\"cons\",True)"
    line: 202
    claim: "이 도구를 쓰는 테스트는 이것 하나이고 `main` 이 아니라 `boundary()` 함수만 불러 artifact-critique SKILL 의 `## kill switch` 절이 보수 근사 5,000토큰 경계 안에서 시작하는지 본다(208–212행) — 블록이 길어지면 여기서 RED 가 날 수 있다. `--base` 측정을 돌리라는 자리는 문서뿐이다: `tools/plain-language/README.md` 6행, `docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md` 161 · 178(AC3 「새로 밀려난 `## ` 절이 SKILL.md 10개 어디에도 없다 … 있으면 PR 본문에 공시」) · 207행, 계획 `docs/superpowers/plans/2026-10-28-askquestion-recommendation.md` 286 · 406행. 도구 자체의 단위 테스트는 없다(폴더의 테스트는 `test_measure_output.py` 뿐)."
    touches: []
    decides: [OQ18]
unanswered: "넷 이상에서 선택지를 둘로 «접는» 이유를 적은 문장은 CHANGELOG · specs · 계획 어디에도 없다(RC2 — 첫 등장 자리에 근거 없음, 설계가 이유를 댄 것은 단일 선택 전환뿐). git 이력 · 커밋 메시지는 도구가 없어 보지 못했다. OQ13(실제 화면 측정) · OQ15 에 닿는 레포 근거는 이 질문 범위에서 찾지 못했다."
```

충돌 · 주의(하나로 고르지 않고 둘 다 냄):
- RC2 대 RC3 — 2026-10-17 설계 AC26 은 「게이트에서 여러 개를 되올릴 수 있다」, 2026-10-25 설계는 n ≥ 4 를 단일 선택으로 바꿨다. 지금 SKILL 은 뒤쪽을 따른다.
- RC11 대 RC1 — 같은 「선택지 넷 초과」 상황을 request-framing 은 「넷씩 나눈다」, 낮춘 지적 게이트는 「둘로 접고 기타 칸 번호」로 다르게 푼다.
- 질문에 적힌 「705–722행 부근」의 실제 범위는 707–731행이다. 2026-10-28 설계 94행은 이 게이트를 「(711)」로 인용한다(질문 펜스 시작 줄).

관련 절대경로:
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/quality-gates/skills/quality-pipeline/SKILL.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/quality-gates/tests/test_plain_qg_templates.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/quality-gates/tests/test_lowered_gate_wiring.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/quality-gates/scripts/synthesize_findings.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/quality-gates/CHANGELOG.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/docs/superpowers/specs/2026-10-25-qg-range-repairs-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/docs/superpowers/plans/2026-10-19-r2a-plan3-qg-devices-range-persona.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/tests/fixtures/ask-sites.tsv
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/tests/ask_recommendation.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/tests/test_plain_language_block.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/tests/plain_language_block.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/shared/style/plain-language.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/skills/request-framing/SKILL.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/references/conductor-dispatch.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/references/conducting.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/agents/relay-checker.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/tests/test_conductor_dispatch_reference.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/tests/test_conducting_reference.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/tests/test_epic_conductor_skill.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/tests/test_review_handoff_order.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/plugins/spec-distill/tests/test_framing_review_contract.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/tools/plain-language/token_boundary.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/present-tradeoffs/tools/plain-language/README.md

### 조사 15 — orchestrator · R10 · 묶음 12

레포 주장 확인(V1) — 조사 11(repo-researcher)의 RC1–RC21 은 RC92–RC112 로, 조사 12(repo-researcher)의 RC1–RC23 은 RC113–RC135 로 다시 붙였다.
- 확인 RC92 — 확인 — plugins/spec-distill/agents/relay-checker.md#볼 것 — 29–37행 일치 — 대조 항목은 다섯이고 요약의 뜻 · 설명의 내용을 대조하는 항목은 없다
- 확인 RC93 — 확인 — plugins/spec-distill/skills/epic-conductor/SKILL.md#7. 옮김 대조 — 190–192행 일치 — 에픽이 끝난 뒤의 사후 대조다
- 확인 RC94 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#사람 자리 — 32행 일치(문장 수를 지킨다 · 원문은 늘 붙인다 · 지휘자 의견은 선택지 밖)
- 확인 RC95 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#쓰기 권한 없는 agent 가 둘의 선택지 수 · 라벨 · 순서를 대조한다 — 32행 일치
- 확인 RC96 — 확인 — plugins/spec-distill/tests/test_conductor_dispatch_reference.sh#once — 12–26행 일치. test_epic_conductor_skill.sh · test_conducting_reference.sh 는 해당 줄만 확인했다
- 확인 RC97 — 확인 — plugins/spec-distill/agents/doc-critic.md#출력 형식 — 60 · 68행 일치
- 확인 RC98 — 확인 — plugins/spec-distill/references/docreview-profiles/brief.md#사용자가 결정할 질문 하나 — 21행 일치. 45행 · design-doc.md 61행은 앞서 확인했고 112행은 읽지 않았다
- 확인 RC99 — 확인 — plugins/spec-distill/agents/doc-recritic.md#같은 칸을 싣는다 — 58행 일치
- 확인 RC100 — 확인 — shared/codex/codex_findings_to_yaml.py#DOCREVIEW_KEYS — 73–75행 일치. codex 지시문과 그 테스트는 읽지 않았다
- 확인 RC101 — 확인 — shared/tests/test_docreview_agent_fields.sh#부분 문자열 — 11행 일치 · 테스트 폴더에 summary 한 문장 · 재진술 문구의 핀 0건
- 확인 RC102 — 미확인 — plugins/spec-distill/tests/test_overdesign_rubric.sh#field_mapping_line_of — 읽지 않았다
- 확인 RC103 — 확인 — shared/docreview/scripts/docreview_state.py#_rg_decide — 2295–2322 · 2223–2225행 일치. 결정이 아닌 행의 함수들은 읽지 않았다
- 확인 RC104 — 확인 — shared/docreview/scripts/docreview_route.py#부재를 summary 로 메우지 않는다 — 511–516행 일치. normalize · _classify_items 와 cases.sh 는 읽지 않았다
- 확인 RC105 — 확인 — shared/docreview/scripts/docreview_advice.py#def clip — 166–168행 · docreview_config.py 13행(summary_width 60) 일치
- 확인 RC106 — 확인 — shared/docreview/references/reviewing-document.md#`AskUserQuestion` 라벨의 항목별 내용 — 42행 일치
- 확인 RC107 — 확인 — shared/docreview/references/reviewing-document.md#8. **게이트** — 27–40 · 86행 · spec-review SKILL.md 509행 일치
- 확인 RC108 — 확인 — shared/style/plain-language.md#스크립트·subagent 가 낸 원문은 고치지 않는다 — 블록 9 · 3행 일치
- 확인 RC109 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#덩어리 본문(`render`)은 질문 텍스트에 줄임 없이 싣는다 — 935행 · steelman.md 94행 · quality-pipeline SKILL.md 560행 일치
- 확인 RC110 — 확인 — CLAUDE.md#Law 2 — Writer and Reviewer Must Never Share a Pass. — 일치
- 확인 RC111 — 확인 — CLAUDE.md#Persona 파일은 보안-민감 코드. — 78행 일치
- 확인 RC112 — 확인 — shared/tests/test_copy_of_contract.sh#copy-of 물리 사본 — 10–11행 · docreview_state.py 1110행(PUBLIC_FIELDS) 일치. 나머지 자리는 읽지 않았다
- 확인 RC113 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#낮춘 지적 게이트 (표면화 뒤 · 라우팅 앞). — 707–720행 일치
- 확인 RC114 — 확인 — docs/superpowers/plans/2026-10-19-r2a-plan3-qg-devices-range-persona.md#n ≥ 4: {label: "전부 되올린다" — 767–769행 일치. 상위 설계의 줄은 읽지 않았다
- 확인 RC115 — 확인 — docs/superpowers/specs/2026-10-25-qg-range-repairs-design.md#고를 지적이 넷 이상인 낮춘 지적 게이트 — 95행 · quality-gates CHANGELOG 28행 일치
- 확인 RC116 — 확인 — plugins/quality-gates/CHANGELOG.md#「낮춘 지적」 — 재비판이 낮춘 지적을 합성기가 — 146행 일치 · 「넷 이상」은 28행 한 곳
- 확인 RC117 — 확인 — plugins/quality-gates/scripts/synthesize_findings.py#_lowered_lines — 711–719행 일치
- 확인 RC118 — 확인 — plugins/quality-gates/tests/test_plain_qg_templates.sh#AC26: 낮춘 지적 게이트 질문이 한국어다 — 50–51행 일치
- 확인 RC119 — 확인 — plugins/quality-gates/tests/test_lowered_gate_wiring.sh#case_step45_gate — 49–61행 일치
- 확인 RC120 — 확인 — shared/tests/ask_recommendation.py#EMPTY =  — 26행 · required() 일치
- 확인 RC121 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#덩어리마다 질문 하나 — 933–935행 일치. 테스트 줄은 읽지 않았다
- 확인 RC122 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#기준 사본이 없으면 — 937–939행 일치
- 확인 RC123 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#덜어 낸 것이 1개 이상이면 — 1175–1176행 일치
- 확인 RC124 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#추천을 달지 않는다 — 낮춘 지적을 되올릴지는 — 720행 일치
- 확인 RC125 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#분류표의 적용/제외를 바꿀까요 — 861 · 873행 일치. 선택지 줄은 읽지 않았다
- 확인 RC126 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#지휘자 의견은 선택지 밖 「지휘자 의견:」 한 줄로만 쓴다. — 32행 일치
- 확인 RC127 — 확인 — plugins/spec-distill/references/conducting.md#지휘 세션의 의견은 선택지 밖 「지휘자 의견:」 한 줄로만 쓰고 — 102행 일치
- 확인 RC128 — 확인 — plugins/spec-distill/agents/relay-checker.md#지휘자 의견이 선택지 설명 안으로 들어갔으면 어긋남이다 — 34 · 37행 일치
- 확인 RC129 — 확인 — plugins/spec-distill/tests/test_conductor_dispatch_reference.sh#once '## 사람 자리' — 26행 · test_conducting_reference.sh 117–119행 · test_epic_conductor_skill.sh 81행 일치
- 확인 RC130 — 확인 — docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md#「지휘자 의견:」 줄에 어느 꼬리가 지휘자의 것인지와 이유를 쓴다(필수 — 115행 일치. 122행은 읽지 않았다
- 확인 RC131 — 확인 — shared/tests/test_plain_language_block.sh#REC='추천이 있으면 그 선택지를 첫 자리에 두고 — 30 · 32행 일치
- 확인 RC132 — 확인 — shared/tests/plain_language_block.py#if region != canon: — 51–52행 · 사본 10개 일치
- 확인 RC133 — 확인 — plugins/spec-distill/tests/test_review_handoff_order.sh#라벨에 「(권장)」을 달고 이유는 질문 위 글에 한 줄로 쓴다 — 191행 · saturation.md 35행 일치
- 확인 RC134 — 확인 — tools/plain-language/token_boundary.py#def main(argv=None): — 47–69행 일치(--base 필수 · 측정만 낸다)
- 확인 RC135 — 확인 — plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh#import token_boundary as tb — 202–210행 일치

### 조사 16 — orchestrator · R10 · 묶음 13

- 화면 측정(2026-11-15 · Claude Code 2.1.325 · 터미널 CLI): 기타 칸에 글자를 적어 답한 뒤에도 그 질문 문장과 선택지 설명이 화면에 남아 있었다. 한 번의 측정이다 [→ OQ13]
- 재지 않은 것: 좁은 창(예: 80x24) · 한 호출에 질문 넷 · preview 칸

### 조사 17 — orchestrator · R11 · 묶음 14

- 재측정(세션 기록의 추천 선택지 설명 · 이 세션 제외 · 마지막으로 부른 skill 로 가름): 단계마다 무작위 7개씩 49개를 본체가 손으로 가름 — 설명이 내주는 것을 적은 수는 인터뷰 2/7 · 설계문서 리뷰 1/7 · 설계 대화 1/7 · 요청 정리 0/7 · 지휘자 4/7 · 코드 리뷰 1/7 · 그 밖 1/7(합 10/49). 가르는 기준: 그 선택지를 고르면 잃거나 떠안는 것(재검증 없음 · 범위가 커짐 · 길어짐 · 손이 듦 · 남는 위험)을 한 구절이라도 적었으면 적은 것으로 셌다. 한 사람이 한 번 가른 표본이고 단계 가름은 거칠다 [→ OQ15]
- 단계별 서로 다른 추천 선택지 수: 인터뷰 193 · 설계문서 리뷰 180 · 설계 대화 121 · 그 밖 75 · 요청 정리 35 · 지휘자 32 · 코드 리뷰 13
- 지휘자 쪽이 가장 높다 — 그 자리에는 「질문만 봐도 결정할 수 있게」 · 「고르면 무엇이 달라지나를 빠뜨리지 않는다」 규칙이 있다(RC18 · RC94)

### 조사 18 — orchestrator · R11 · 묶음 15

- 측정(tools/plain-language/token_boundary.py 의 boundary 근사 · 지금 문면 · frontmatter 제외): 쉬운 말 블록 사본을 가진 SKILL.md 10개에서, 앞 5,000토큰 경계 안에서 시작하는 마지막 `## ` 절까지의 여유(보수 근사)는 plugin-audit 187토큰 · pm-interview 979 · spec-review 1404 · request-framing 1406 · reviewing-brief 2088 · artifact-critique 3042 · quality-pipeline 3146 · project-init 3182 · epic-conductor 3887 이고 roadmap-status 는 파일 전체가 경계 안이다. 블록은 보수 근사 1010토큰이다. 한글 한 글자가 보수 근사 1토큰이라, 블록이 약 180자 넘게 늘면 plugin-audit 에서 절 하나가 경계 밖으로 밀린다. 근사식이고 실제 tokenizer 로 보정하지 않았다 [RC134 → OQ18]
- 중앙 근사로는 pm-interview 294 · artifact-critique 558 이 가장 좁게 나오는데, pm-interview 의 그 절(「## R<n>」)은 코드 펜스 안의 줄이라 실제 절이 아니다

### 조사 19 — orchestrator · R11 · 묶음 16

- 화면 측정(2026-11-15 · Claude Code 2.1.325 · 터미널 CLI · 창을 가로 80 · 세로 24 쯤으로 줄인 상태): 한 호출에 질문 넷 · 앞의 셋은 리뷰 뒤 질문의 꼴(본문에 지적 요약 한두 문장 + 선택지 셋 · 설명마다 한 줄쯤 · 셋째 질문 본문에는 경고 한 줄) — 세 질문 모두 본문의 끝 표시와 설명 셋의 끝말이 다 보였다. 한 번의 측정이다 [→ OQ18 · OQ19]
- 재지 않은 것: 좁은 창에서의 긴 설명(300자 이상) · preview 칸(쓰지 않기로 한 칸)

## audit §2 대기 줄

- 포화 판정 1: 아직 — 빈 곳 4개
- 포화 판정 2: 아직 — 빈 곳 5개
- 포화 판정 3: 아직 — 빈 곳 3개
- 포화 판정 4: 아직 — 빈 곳 5개
- 포화 판정 4: 사용자 판단 포화(@S35) — 반복 빈 곳
