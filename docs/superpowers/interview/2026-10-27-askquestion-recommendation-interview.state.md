---
type: interview-state
seed: 없음
session_id: 19459a6e
phase: 1
coverage:
  floor:
    root_problem:   {status: closed, evidence: "S1 · S2 · S3 — 원칙은 있는데 안 지켜진다(S2). 사례: 품질 검사 · 인터뷰·리뷰 질문, 그리고 분해 판단 질문에서 권고는 터미널 글에만 있고 선택지에 추천 표시가 없어 권고(로드맵)와 반대(스펙 하나)를 골랐다(S3)", reopened: 0, reopen_log: []}
    landscape:      {status: closed, evidence: "S10 — 외부 근거 처분: Microsoft 라벨 지침 · 도구 관례(첫 자리 + (Recommended))를 라벨 표시 근거로 취함, 기본값 · 과의존 연구는 §5 위험", reopened: 0, reopen_log: []}
    skepticism:     {status: closed, evidence: "S14 · S22 — ST1 verdict: refined(보완). 출처 꼬리는 S22 로 steelman 질문에만 남김", reopened: 1, reopen_log: [{round: 13, reason: "S18 — 출처 꼬리 표시가 필요한지 되물음", conflicts_with: S14}]}
    blind_spot:     {status: closed, evidence: "S9 — 숨은 가정·실패 양식 처분: 넷을 설계 제약으로 받음(추천은 도구 안에만 · 자기 처분은 추천 없음 · 지휘자 규칙 함께 · (Recommended) 인정). 나머지(정적 락 맹점 · 형식 채우기 · 따른 비율 지표 함정 · 훅 범위 누수)는 §5 위험",  reopened: 0, reopen_log: []}
    open_questions: {status: closed, evidence: "S15 — 열린 질문 OQ11–OQ14 확인", reopened: 0, reopen_log: []}
  derived:
    - {name: scope, rationale: "어떤 질문이 «모든 askquestion» 에 드는가 — 리터럴 호출 · 문장 지시 질문 · 지휘자가 만든/옮긴 질문 · 묶음 질문 · devbrew 흐름 안 외부 skill 질문", status: closed, evidence: "S11 · S12 — devbrew 가 띄우는 질문 전부(skill 리터럴 · 문장 지시 · 지휘자 · 즉석 질문). 외부 skill 질문은 그 skill 몫(S12)", reopened: 0, reopen_log: []}
    - {name: intentional_exceptions, rationale: "steelman 출처 라벨 · 지휘자 의견 줄 · 취향/확인 질문처럼 일부러 (권장)을 달지 않는 자리와 «모든» 의 충돌 — 예외 유지 vs 「추천 없음 — 이유」 명시", status: closed, evidence: "S19 — 모델 제안 승인 질문(③b)에도 추천을 단다. 자기 산출물 리뷰 지적 처분(③a)만 추천 없음(S9)", reopened: 1, reopen_log: [{round: 12, reason: "조사 7 — 모델 제안 승인 질문(③b) 7곳이 S9 의 «자기 처분» 범위 밖인지 정해지지 않음", conflicts_with: S9}]}
    - {name: clarity_standard, rationale: "«명확하게» 의 기준 — 라벨 꼬리 · 첫 자리 · 이유 한 줄 · 도구 관례 (Recommended) · multiSelect", status: closed, evidence: "S4 · S6 · S9 · S21 · S23 — 추천은 첫 자리 + 라벨 (권장) · 여럿이면 여럿 · (Recommended) 인정 · 추천 없으면 화면 표시 없음, 이유는 skill 문서에만 · 과하게 강제하는 장치는 만들지 않는다(S23)", reopened: 2, reopen_log: [{round: 13, reason: "S17 — 「추천 없음 — 근거 부족」 문구를 억지로 쓰지 말라", conflicts_with: S5}, {round: 14, reason: "조사 12 — 추천 없는 질문에서도 첫 자리가 위치로 추천처럼 읽힌다", conflicts_with: S21}]}
    - {name: enforcement_layer, rationale: "지금 집행은 문장뿐(블록 복제 락은 준수를 못 잰다) — 정본 문장 · 정적 락 · 리뷰어 persona · 훅 중 어디에", status: closed, evidence: "S20 — 정본 규칙 + 질문 자리 전수 검사. 리뷰어 검사는 넣지 않음(검사가 더 잘 잡는 자리 — CLAUDE.md 허용)", reopened: 1, reopen_log: [{round: 13, reason: "S16 — 리뷰어 검사가 필요한지 되물음", conflicts_with: S13}]}
    - {name: downstream_impact, rationale: "표기 변경 시 (권장) 리터럴 락 · relay-checker 대조 · 네 플러그인 bump/CHANGELOG", status: closed, evidence: "S4 · S9 — 지휘자 의견 줄 규칙 · relay-checker 대조 · 그 문구 락을 같은 변경에서 함께 고친다", reopened: 0, reopen_log: []}
    - {name: internal_research, rationale: "repo_claims 첫 산출(조사 1)", status: closed, evidence: "S2 · S9 — 레포 주장(RC1–RC56) 처분: 규칙은 있는데 안 지켜진다(S2), 레포 사실에서 나온 제약 넷을 받음(S9)", reopened: 0, reopen_log: []}
orchestration:
  focused_dimension: enforcement_layer
  research_dispatches: {coverage_mapper: 1, blind_spot_prober: 3, steelman_builder: 1, repo_researcher: 6, open_researcher: 1}
  research_limit: 60
  saturation_limit: 5
  research_log:
    - {n: 1, device: coverage-mapper, round: 1, batch: 1, changed: [], opened: [OQ1], summary: "derived 6 제안(원인·범위·예외·명확 기준·집행 층위·하류) · RC1-10 · 웹 2(2차)"}
    - {n: 6, device: repo-researcher, round: 11, batch: 4, changed: [OQ14], opened: [], summary: "라벨을 기계가 되읽는 곳 없음 · 글자 비교 소비자는 지휘자 옮김 · relay-checker 둘 · 깨지는 것은 문서 문면 락"}
    - {n: 7, device: repo-researcher, round: 11, batch: 4, changed: [OQ11], opened: [OQ15], summary: "무권장 55곳 — ① 3 · ② 35 · ③a 10 · ③b 7. ③b(모델 제안 승인) 경계가 새 결정"}
    - {n: 8, device: repo-researcher, round: 11, batch: 4, changed: [OQ11], opened: [], summary: "지금 추천 표시를 보는 PR 리뷰어 없음 · qg review-criteria 가 모든 qg 리뷰어 · codex 공유 자리 · plugin-audit 축 5"}
    - {n: 9, device: repo-researcher, round: 11, batch: 4, changed: [OQ13], opened: [], summary: "추천하는 쪽 둘 이상 3곳(steelman · 지휘자 옮김 · proceed 둘째 질문) · multiSelect 3곳 모두 무표시"}
    - {n: 10, device: blind-spot-prober, round: 11, batch: 4, changed: [OQ12], opened: [], summary: "사후 표본 검사 바탕 자료 거의 없음(state 는 고른 라벨만 · relay git-ignored · transcript 30일) · 감시하면 범주 바꿔치기"}
    - {n: 11, device: repo-researcher, round: 14, batch: 5, changed: [OQ14], opened: [], summary: "라벨 락 전수 — (가) 9파일 21 · (나) 3 · (다) 8 · 규칙 문장 7파일 19"}
    - {n: 12, device: blind-spot-prober, round: 14, batch: 5, changed: [], opened: [OQ17], summary: "추천 없는 질문의 첫 칸이 위치로 추천처럼 읽힘 · 조용한 누락 · 되묻기 규칙 충돌"}
    - {n: 13, device: orchestrator, round: 14, batch: 6, changed: [], opened: [], summary: "빈 곳 2 · 3 은 S4 · S6 · S9 · S22 가 덮음"}
    - {n: 5, device: steelman-builder, round: 6, batch: 3, changed: [OQ4], opened: [OQ10], summary: "refined — P5 반증(안 지킴이 아니라 맞서는 지역 규칙이 이김) · 출처 꼬리 「(<누가> 추천)」 도 정식 표지로"}
    - {n: 4, device: open-researcher, round: 3, batch: 2, changed: [OQ2, OQ3, OQ4], opened: [], summary: "추천 전용 필드 없음 · 도구 관례 첫 자리+(Recommended)(2차) · MS 「(recommended) 를 라벨에, 보충 설명 말고」(1차) · 추천 없음을 밝히는 관례는 없음 · multiSelect 추천 관례 없음 · 기본값은 알려도 끌어당김 · PreToolUse 는 AskUserQuestion 입력을 받고 deny/updatedInput 가능"}
    - {n: 3, device: blind-spot-prober, round: 3, batch: 2, changed: [OQ2, OQ3, OQ4, OQ5], opened: [], summary: "숨은 가정 5 · 실패 양식 4 — 질문 창이 앞선 글을 가리는 Claude Code 버그 · relay-checker 충돌 · Law 2 자기 처분 · 정적 락 맹점 · (Recommended) 혼용"}
    - {n: 2, device: repo-researcher, round: 1, batch: 1, changed: [], opened: [OQ1], summary: "질문 자리 전수 — 표시 꼴 다섯 갈래 · 준수 재는 락 없음 · 문서 충돌 2 · RC11-46"}
  saturation_log:
    - {k: 1, round: 10, verdict: not_saturated, basis: "묶음 2 · 3 모두 결정을 바꾸거나 열었다 · 열린 OQ11–14 에 직접 닿은 조사 없음", gaps: ["repo-researcher: 라벨 글자 비교 소비자 · 락 전수 → OQ14 · OQ13", "repo-researcher: 무권장 자리 ①지역 규칙 ②근거 없이 빠짐 ③자기 처분 분류 → OQ1 · OQ12 · OQ11", "repo-researcher: 리뷰어 persona 범위 → OQ11", "blind-spot-prober: 실행 중 라벨 흔적 · 사후 표본 검사 → OQ12 · OQ4", "coverage-mapper: 추천하는 쪽 둘 이상 자리 수 → OQ13"], user_choice: null}
    - {k: 2, round: 13, verdict: not_saturated, basis: "묶음 3 · 4 모두 결정을 바꾸거나 열었다 · OQ14 열림", gaps: ["repo-researcher: OQ14 소비자 22개 파일 전수 → OQ14", "orchestrator: relay-checker 꼬리 틈 · 병렬 (권장) 충돌이 OQ13 · OQ11 결정에 덮이나", "orchestrator: multiSelect · 게이트 둘째 질문이 OQ13 · S6 에 드나", "blind-spot-prober: OQ12 + OQ16 결합 — (권장) 쪽 실패를 누가 재나"], user_choice: null}
  open_decisions:
    - {id: OQ1, text: "이 일이 고치려는 핵심 문제 — 규칙 부재·미준수·표시 불명확·층위 중 무엇인가", dimension: root_problem, status: resolved, resolved_by: S3}
    - {id: OQ2, text: "선택지 밖(질문 위 문장 · 지휘자 의견 줄)에만 둔 추천을 어떻게 할까 — 라벨에도 (권장)을 의무로 달까", dimension: intentional_exceptions, status: resolved, resolved_by: S4}
    - {id: OQ3, text: "정직하게 추천이 없는 질문(취향 · 저자 판정 덩어리 · 확인)을 어떻게 표시하나", dimension: clarity_standard, status: resolved, resolved_by: S5}
    - {id: OQ4, text: "지키게 만드는 장치를 어느 층에 둘까 — 정본 문장 · 정적 락 · 리뷰어 · 훅", dimension: enforcement_layer, status: resolved, resolved_by: S13}
    - {id: OQ6, text: "「추천 없음」이 의무 회피 통로가 되지 않게 언제만 허용할까", dimension: intentional_exceptions, status: resolved, resolved_by: S7}
    - {id: OQ7, text: "S3 의 원인 — 권고가 질문 창에 가려졌나, 보였는데 놓쳤나", dimension: root_problem, status: resolved, resolved_by: S8}
    - {id: OQ8, text: "blind-spot 숨은 가정 · 실패 양식 중 무엇을 brief 제약으로 받을까", dimension: blind_spot, status: resolved, resolved_by: S9}
    - {id: OQ9, text: "바깥 근거(landscape) 처분 — MS 라벨 지침 · 도구 관례 · 기본값/과의존 연구를 어떻게 받을까", dimension: landscape, status: resolved, resolved_by: S10}
    - {id: OQ10, text: "steelman 판정 — 유지 / 보완 / 전환 / 보류 (ST1)", dimension: skepticism, status: resolved, resolved_by: S14}
    - {id: OQ11, text: "어느 리뷰어 persona 에 추천 표시 검사를 넣을까(skill 을 바꾸는 변경을 보는 리뷰어 — 코드 리뷰 · 문서 리뷰 · plugin-audit 축 중)", dimension: open_questions, status: resolved, resolved_by: S20}
    - {id: OQ12, text: "「추천 없음 — 근거 부족」 남발을 무엇으로 볼까(실행 중 라벨은 정적 검사가 못 본다)", dimension: open_questions, status: resolved, resolved_by: S17}
    - {id: OQ13, text: "「(<누가> 추천)」 출처 꼬리의 문법과, 어떤 질문을 «추천하는 쪽이 둘 이상»으로 셀지", dimension: open_questions, status: resolved, resolved_by: S22}
    - {id: OQ14, text: "라벨은 돌려받는 값이다 — 꼬리를 바꿀 때 라벨을 글자 그대로 비교하는 소비자 · 잠금 테스트 목록", dimension: open_questions, status: open, resolved_by: null}
    - {id: OQ15, text: "모델이 낸 제안 · 판정 · 풀이를 승인받는 질문(③b — 분해안 · 재분해 · 흐름 · trivia · 풀이 확인)도 자기 처분처럼 「추천 없음」으로 둘까", dimension: intentional_exceptions, status: resolved, resolved_by: S19}
    - {id: OQ16, text: "추천이 없을 때 무엇을 보일까 — S17 로 「추천 없음 — 이유」 문구를 사용자 화면에서 없앤 뒤", dimension: clarity_standard, status: resolved, resolved_by: S21}
    - {id: OQ17, text: "추천 위치 — 추천을 첫 자리에 둘까(도구 관례), 순서는 논리 순으로 두고 꼬리만으로 표시할까", dimension: clarity_standard, status: resolved, resolved_by: S23}
    - {id: OQ18, text: "조사를 더 할까, 여기서 마무리할까(OQ14 는 목록이 모여 설계로 넘김)", dimension: open_questions, status: resolved, resolved_by: S24}
    - {id: OQ19, text: "S23 «너무 강제하게 만드는 장치는 만들지 마» 의 경계 — 질문 자리 전수 검사(S20)를 얼마나 가볍게 할까", dimension: open_questions, status: open, resolved_by: null}
    - {id: OQ5, text: "적용 범위 — devbrew skill 이 띄우는 질문만인가, devbrew 흐름 안 외부 skill(brainstorming 등) 질문도인가", dimension: scope, status: resolved, resolved_by: S12}
trivia_escape_armed: false
user_statements:
  - id: S2
    source: chosen
    round: 1
    text: "안 지켜진다 (권장) — 추천 없는 질문을 실제로 받아 고르기 힘들었다. → 질문 자리들을 고치고, 지키는지 재는 장치를 더하는 일이 된다."
  - id: S3
    source: verbatim
    round: 2
    text: "품질 검사 질문 (권장), 인터뷰·리뷰 질문, 로드맵으로 갈지 스펙 하나로 갈지에서 추천이 뭐인지 안나오는데 위에 터미널 글은 추천은 로드맵이라 나왔음 근데 나는 스펙을 골라버림"
  - id: S4
    source: chosen
    round: 3
    text: "라벨에도 의무 (권장) — 추천이 있으면 그 선택지 라벨에 반드시 「(권장)」을 단다. 문장 권고는 이유 설명으로만 남는다. 지휘자 의견 줄 규칙과 relay-checker 대조 기준도 함께 바뀐다."
  - id: S5
    source: chosen
    round: 3
    text: "「추천 없음」 명시 (권장) — 질문 본문에 「추천 없음 — <이유>」를 쓴다. 일부러 없는 것과 빠뜨린 것이 구별되고, 검사도 «표시가 있는가» 하나로 잴 수 있다."
  - id: S6
    source: verbatim
    round: 3
    text: "그리고 꼭 한개만 권장이 아니라 클로드 코드가 이미 잘하지만 권장이 여러개인 경우 여러개 권장 표시해"
  - id: S7
    source: chosen
    round: 4
    text: "모델이 판단 못 할 때도 — 근거가 모자라 모델이 자신 없을 때도 「추천 없음 — 근거 부족」을 허용한다. 정직하지만 남발될 수 있다."
  - id: S8
    source: chosen
    round: 5
    text: "보였는데 놓침 — 고를 때 보였지만 선택지에 표시가 없어 연결을 못 했다. → 라벨 표시의 강도가 핵심이 된다."
  - id: S9
    source: chosen
    round: 5
    text: "추천은 도구 안에만 (권장), 자기 처분은 추천 없음 (권장), 지휘자 규칙 함께 (권장), (Recommended) 도 인정 (권장)"
  - id: S10
    source: chosen
    round: 6
    text: "라벨 근거로 취함 (권장) — Microsoft · 도구 관례를 라벨 표시의 근거로 쓴다. 과의존 연구는 brief 에 위험으로 남기고, 이미 받은 «자기 처분은 추천 없음»이 그 대비가 된다."
  - id: S11
    source: chosen
    round: 6
    text: "devbrew 가 띄우는 것 (권장) — devbrew skill 의 질문 · 문장으로 지시한 질문 · 지휘자가 만든 질문 · 모델이 그 자리에서 만든 질문까지 다 든다. 고칠 자리가 레포 안에서 닫힌다."
  - id: S12
    source: chosen
    round: 7
    text: "괜찮다 (권장) — 외부 skill 질문은 그 skill 의 몫이다. 지키게 하는 장치는 레포 안(규칙 문장 · 검사 · 리뷰어)으로 충분하다."
  - id: S13
    source: chosen
    round: 8
    text: "리뷰어 수정 (권장), 정본 + 전수 검사 (권장)"
  - id: S14
    source: chosen
    round: 9
    text: "보완 (builder·orchestrator 추천) — 맞서는 지역 규칙(문체 규칙 3행의 우선 조항 · 분해 판단 · relay-checker · 잠금 테스트)을 먼저 고친다. 추천하는 쪽이 둘 이상인 질문은 「(<누가> 추천)」도 표지로 센다."
  - id: S15
    source: chosen
    round: 10
    text: "이 넷으로 (권장) — OQ11–OQ14 를 brief 의 열린 질문으로 넘기고 설계 단계가 정한다."
  - id: S16
    source: verbatim
    round: 12
    text: "필요한가?"
  - id: S17
    source: verbatim
    round: 12
    text: "추천이 없다면 추천 없음 - 근거 부족 이말이 나오는게 이상하니까 그냥 억지로 적지를 마 없애 "
  - id: S18
    source: verbatim
    round: 12
    text: "누가 추천 이표시가 필요 할까?"
  - id: S19
    source: chosen
    round: 12
    text: "추천을 단다 (권장) — 모델이 추천하는 쪽에 「(권장)」을 단다. 분해 판단 같은 사고가 막힌다."
  - id: S20
    source: chosen
    round: 13
    text: "빼기 (권장) — 정본 규칙 + 전수 검사만 둔다. 리뷰어 검사는 넣지 않고, 왜 검사인지 이유를 적는다."
  - id: S21
    source: chosen
    round: 13
    text: "문서에만 이유 (권장) — 사용자 화면에는 아무 표시도 없다. 일부러 비운 이유는 skill 문서의 그 질문 옆에만 적어, 검사가 빠뜨린 것과 구별한다."
  - id: S22
    source: chosen
    round: 13
    text: "점검 질문만 그대로 (권장) — 추천이 둘로 갈리는 점검(steelman) 질문만 지금 표시를 둔다. 나머지는 모두 「(권장)」 하나로 통일한다."
  - id: S23
    source: verbatim
    round: 14
    text: "1, 너무 강제하게 만드는 장치만들거나 하진마"
  - id: S24
    source: chosen
    round: 14
    text: "여기서 마무리 (권장) — 인터뷰를 끝내고 brief 를 쓴다. 판정자의 «포화» 판정 없이 끝낸 것으로 기록된다."
  - id: S25
    source: chosen
    round: 15
    text: "spec 하나로 (권장) — brief 하나를 brainstorming 하나로 넘긴다. 로드맵을 만들지 않는다."
  - id: S26
    source: chosen
    round: 16
    text: "고친다(채택) — 근거 S6·S20 추가 (권장)"
  - id: S27
    source: chosen
    round: 16
    text: "고친다(채택) — 지휘자 질문은 범위 안 (권장)"
  - id: S28
    source: chosen
    round: 16
    text: "고친다(채택) — 추천 지시 문장 검사 (권장)"
  - id: S29
    source: chosen
    round: 16
    text: "고친다(채택) — 이유는 질문 위 글 (권장)"
  - id: S30
    source: chosen
    round: 17
    text: "고친다(채택) — 지휘자 예외 붙임 (권장)"
  - id: S31
    source: chosen
    round: 17
    text: "고친다(채택) — 리뷰 결정은 추천 단다 (권장)"
  - id: S32
    source: chosen
    round: 17
    text: "그대로 둔다(기각) — 이미 고침 (권장)"
  - id: S33
    source: chosen
    round: 17
    text: "그대로 둔다(기각) — 이미 고침 (권장)"
  - id: S34
    source: chosen
    round: 17
    text: "그대로 둔다(기각) — §3 고침에 함께 (권장)"
  - id: S35
    source: chosen
    round: 18
    text: "고친다(채택) — 옮긴 질문은 순서 유지 (권장)"
  - id: S36
    source: chosen
    round: 18
    text: "열지 않음 (권장)"
confirm_repost_count: 0
brief_review_degradations: []
---

## 풀린 입력

~~~~
devbrew의 모든 askquestion에 추천이 뭐인지 명확하게 알려줘야 함 원칙임
~~~~

### 조사 1 — coverage-mapper · R1 · 묶음 1

(subagent 임시 id → 인터뷰 번호: RC1–RC10 그대로)

```yaml
derived_dimensions:
  - name: "어긋남의 실제 원인 — 원칙이 없는가, 지켜지지 않는가"
    rationale: "seed 는 원칙을 새로 세우자는 문장이지만, 그 원칙은 이미 정본에 있다(plain-language.md 6행 「추천은 「(권장)」으로 표시한다」). 이 문장은 test_plain_language_block 이 모든 SKILL.md 에 같은 글자로 복제되는지 확인한다. 그런데 quality-pipeline 의 AskUserQuestion 리터럴 블록들(825·846·929·1003행 근처)에는 「(권장)」이 하나도 없고, saturation.md 의 판정 불가 · 판정 상한 질문도 마찬가지다. 그러니 이 일은 원칙을 만드는 일이 아니라 지켜지게 만드는 일일 공산이 크다. root_problem 차원과 맞닿아 있지만, 이 사실은 R1 에서 따로 확인해야 한다."
  - name: "적용 범위 — 어떤 질문이 «모든 askquestion» 에 드는가"
    rationale: "질문이 나오는 자리가 여러 겹이다. devbrew skill 의 리터럴 호출 · 문장으로만 적힌 질문(「…를 묻는다」) · 지휘자가 직접 만든 질문 · 하위 skill 의 질문을 지휘자가 옮긴 것 · 한 호출에 묶인 여러 질문 · devbrew 흐름 안에서 도는 외부 skill(superpowers brainstorming · writing-plans)의 질문이 있다. 정본은 이미 외부 skill 이 메시지 모양을 정한 대화를 예외로 둔다. seed 의 «모든» 이 이 경계까지 넓히자는 뜻인지 정해야 한다."
  - name: "의도된 «권장 없음» 예외와 정직성"
    rationale: "레포에는 일부러 「(권장)」을 달지 않는 자리가 이미 있다. steelman 질문은 고정 순서에 출처 라벨(builder 추천 / orchestrator 추천)만 달고, 지휘자의 권장은 선택지 밖 의견 줄로만 내며 지휘자가 만든 질문의 라벨에 「(권장)」을 달면 relay-checker 가 어긋남으로 잡는다. 기준점 효과(anchoring)를 막으려는 장치다. 사용자의 취향 · 선호만 남은 질문이나 동의 확인 질문에서 꾸며 낸 추천은 정직하지 않다. «모든» 을 글자 그대로 따르면 이 장치들과 부딪힌다. 예외를 남길지, 「추천 없음 — 이유」처럼 «없음도 명시» 하는 꼴로 바꿀지를 정해야 한다."
  - name: "«명확하게» 의 기준 — 표지 꼴 · 이유 · 도구 관례"
    rationale: "지금 꼴이 섞여 있다. 라벨 끝 「(권장)」, 첫 자리에 두기(pm-interview: 첫 선택지가 추천), 설명에 이유 한 줄(spec-review 702행), 출처 라벨(steelman)이다. Claude Code 도구 자체의 관례는 첫 자리 + 영어 「(Recommended)」로 알려져 있어(2차 출처) 한국어 「(권장)」과 겹치거나 부딪힌다. 여러 개를 고를 수 있는 질문(multiSelect)에서 권장이 여럿이면 어떻게 할지도 정해지지 않았다. «명확» 이 표지만으로 되는지, 이유까지 있어야 하는지가 결정 대상이다."
  - name: "집행 층위 — 문장 · 락 · 리뷰어 · 훅"
    rationale: "지금 집행은 문장뿐이다. pm-interview 205행이 「기계 검사는 없다」고 밝히고, plugins/ 아래 hooks 에는 AskUserQuestion 을 보는 훅이 없다. 고를 수 있는 길은 넷이다. SKILL 리터럴 블록을 보는 정적 락은 문장으로만 적힌 질문을 못 본다. AskUserQuestion 에 PreToolUse 훅을 걸면 실행 중에 보이지만, 결정론은 보안 · 정확성 게이트에만 쓴다는 원칙(P8)과 의도된 예외 때문에 막기보다 알리기에 가깝다. 리뷰어 persona 를 고치는 길도 있고, 정본 문장만 고치는 길도 있다. Law 3 에 따라 교훈을 어디에 남길지와 같은 질문이다."
  - name: "하류 영향 범위 — 락 · relay 대조 · 버전"
    rationale: "표기를 바꾸면 「(권장)」 리터럴에 기댄 락들이 깨진다(test_ledger_wiring · test_end_gates · test_conductor_dispatch_reference · test_conducting_reference). relay-checker 의 대조 기준도 바뀌고, 네 플러그인(spec-distill · quality-gates · project-init · plugin-audit)의 SemVer bump · CHANGELOG 와 정본 블록 복제 락이 함께 움직인다."
neglect_flag: false
neglected_dimensions: []
confidence: 0.7
evidence:
  - url: "https://juejin.cn/post/7667440437863874560"
    supports: alternative
    claim: "Claude Code AskUserQuestion 도구 지시문의 관례는 추천 선택지를 첫 자리에 두고 라벨 끝에 「(Recommended)」를 붙이는 것이다. 추천을 따로 담는 필드는 없고 위치와 접미사로만 나타낸다. 이 글은 도구 프롬프트를 옮긴 2차 출처이고, 공식 문서로는 확인하지 못했다."
    source_kind: secondary
    checked_at: "2026-10-27"
    certainty: uncertain
  - url: "https://dev.to/_94be737e156beb4d74df2/claude-code-tools-deep-dive-1-askuserquestion-4ck1"
    supports: alternative
    claim: "같은 관례(첫 자리 + 「(Recommended)」)를 다룬 2차 해설이다. 한국어 「(권장)」과 겹치는지 · 부딪히는지가 표기 결정에 걸린다."
    source_kind: secondary
    checked_at: "2026-10-27"
    certainty: uncertain
repo_claims:
  - {id: RC1, path: "shared/style/plain-language.md", anchor: "추천은 「(권장)」으로 표시한다.", line: 6, claim: "seed 의 원칙은 이미 정본 문장으로 있다. 같은 절(3행)은 부른 skill 이 메시지 모양을 정한 대화(예: brainstorming)를 예외로 두어 적용 범위를 줄인다."}
  - {id: RC2, path: "shared/tests/test_plain_language_block.sh", anchor: "「사람에게 쓰는 글」 블록 동일성", line: 4, claim: "이 락은 정본 블록이 모든 SKILL.md 에 같은 글자로 복제되는지만 잰다. 실제 질문이 그 규칙을 지키는지는 재지 않는다."}
  - {id: RC3, path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md", anchor: "{label: \"고치고 다시 돌기\"", line: 846, claim: "quality-pipeline 의 AskUserQuestion 리터럴 블록들(819·840·923·997행 호출)의 선택지 라벨에는 「(권장)」이 없다. 블록 복제 락이 통과해도 실제로는 지켜지지 않는 예다."}
  - {id: RC4, path: "plugins/spec-distill/skills/pm-interview/references/saturation.md", anchor: "「포화로 보고 종료」 · 「조사 계속」 중 하나를 받는다", line: 110, claim: "판정 불가(110행) · 반복 감지(96행) · 판정 상한(125행) 질문에는 추천 표기 지시가 없다. 같은 파일 35행의 상한 도달 질문만 「첫 선택지가 추천」이라고 적는다."}
  - {id: RC5, path: "plugins/spec-distill/skills/pm-interview/SKILL.md", anchor: "질문마다 첫 선택지가 추천이고 그 라벨 끝에 `(권장)` 을 단다", line: 202, claim: "pm-interview 는 첫 자리와 라벨 접미사를 함께 쓰고, steelman 질문을 예외로 둔다. 205행은 「기계 검사는 없다」고 밝힌다."}
  - {id: RC6, path: "plugins/spec-distill/skills/pm-interview/references/steelman.md", anchor: "추천을 첫 자리로 옮기지 않는다. 추천 표시는 출처 라벨뿐이다", line: 92, claim: "steelman 질문은 일부러 「(권장)」·「(Recommended)」 접미사를 쓰지 않고, 고정 순서에 출처 라벨만 단다. 기준점 효과를 막는 장치이고, seed 의 «모든» 과 정면으로 부딪힌다."}
  - {id: RC7, path: "plugins/spec-distill/agents/relay-checker.md", anchor: "지휘자가 만든 질문의 라벨에 (권장)", line: 35, claim: "지휘자의 권장은 선택지 밖 의견 줄에만 쓰고, 지휘자가 만든 질문의 라벨에 「(권장)」이 붙으면 어긋남으로 잡는다. 문장으로 낸 권장을 라벨 꼬리로 옮겨도 어긋남이다(32행). 여기서는 «표지를 달지 않음» 이 규칙이다."}
  - {id: RC8, path: "plugins/spec-distill/skills/spec-review/SKILL.md", anchor: "라벨에 「(권장)」, 설명에 이유 한 줄을 붙인다 — 고르는 것은 사용자다", line: 702, claim: "어떤 자리는 표지에 더해 이유 한 줄을 요구한다. «명확하게» 의 기준이 표지인지 이유인지가 표면마다 다르다."}
  - {id: RC9, path: "plugins/quality-gates/skills/artifact-critique/SKILL.md", anchor: "이 파일(`<path>`)을 산출물로 비평할까요?", line: 97, claim: "확인(예/아니오) 성격의 질문에는 추천이 없다. 동의 · 확인 질문에도 추천이 필요한지는 정해지지 않았다."}
  - {id: RC10, path: "plugins/spec-distill/tests/test_conductor_dispatch_reference.sh", anchor: "지휘자 자신의 권장은 라벨 안 「(권장)」으로 넣지 않고 그 의견 줄에만 쓴다", line: 30, claim: "「(권장)」 리터럴과 그 배치 규칙은 여러 락이 글자 그대로 잡고 있다(test_ledger_wiring 39·770행, test_end_gates 33행 포함). 표기를 바꾸면 이 락들이 함께 움직여야 한다."}
```
(모든 항목 touches: [] · decides: [] — 원문 그대로. 비고: 부재 주장은 하한(Grep 은 심볼릭 링크를 건너뛴다) · 웹 근거 둘은 2차 출처)

### 조사 2 — repo-researcher · R1 · 묶음 1

(subagent 임시 id → 인터뷰 번호: RC<n> → RC<n+10>. 아래는 원문 id 그대로 두고 괄호에 인터뷰 번호)

요약(원문): 「추천」 표시 규칙의 정본은 `shared/style/plain-language.md` 한 줄(「추천은 「(권장)」으로 표시한다」)이다. 이 줄은 표시 «방식»만 정하고, 언제 추천을 둬야 하는지는 정하지 않는다. `CLAUDE.md` · `docs/philosophy/` 에는 선택지 추천 규칙이 없다. 자리마다 꼴이 다섯 가지로 갈린다 — 라벨 꼬리 「(권장)」 · 첫 선택지가 추천(꼬리 표시 없음) · 선택지 밖 문장 권고 · 출처 라벨(builder/orchestrator 추천)과 「(권장)」 금지 · 표시 없음. 검사는 전부 문서 문구가 있는지 재는 grep 락과, 에픽이 끝난 뒤 옮긴 질문만 대조하는 relay-checker 다. 모든 질문 자리를 훑어 추천 표시 규칙을 지키는지 재는 락은 없다. 모델이 실제로 띄우는 라벨을 재는 락도 없다.

```yaml
repo_claims:
  - {id: RC1 (RC11), path: "shared/style/plain-language.md", line: 6, claim: "정본 규칙이다. 추천을 «둘 때» 「(권장)」으로 표시하라고만 하고, 추천을 둘 의무나 생략 조건은 정하지 않는다. 적용 범위는 사용자에게 보이는 글(질문·선택지 포함)이다. 예외가 둘 있다. 절차가 형식을 따로 정한 자리에서는 그 절차를 따르고, 부른 skill 이 메시지 모양을 정한 대화(예: brainstorming)에서는 낱말 규칙만 적용한다(3행)."}
  - {id: RC2 (RC12), path: "CLAUDE.md", line: 24, claim: "CLAUDE.md 에서 「권장」이 나오는 곳은 이 Law 1 문장뿐이고 선택지 추천과는 무관하다. docs/philosophy/*.md 에는 「(권장)」 · 첫 선택지 · 추천 선택지 규칙이 없다(grep 0건). AskUserQuestion 언급은 철학 문서 52행의 코드 지도 한 곳뿐이다. 선택지 추천 규칙은 레포 문서 층에 없고, plain-language 블록과 각 skill 에만 있다."}
  - {id: RC3 (RC13), path: "plugins/spec-distill/references/proceed-gate.md", line: 28, claim: "세 proceed 게이트(pm-interview 끝 · spec-review · request-framing)의 공통 계약이다. ① 이 「권장 핸드오프」(/compact), ② 가 「차선」이다. 둘째 질문(다음 단계 갈래)의 선택지는 'skill 의 기본 다음 단계 `(권장)` 과 모델의 제안 둘'이고, 첫 질문의 `(권장)` 위치는 그대로다(56행)."}
  - {id: RC4 (RC14), path: "plugins/spec-distill/skills/pm-interview/SKILL.md", line: 202, claim: "인터뷰 라운드 규약은 첫 선택지를 추천으로 두고 라벨 끝에 (권장)을 붙이게 한다. «다음 결정» 템플릿 줄도 「OQ<n>: … · 추천: <첫 선택지> · 트레이드오프: …」 꼴이다(190행). 되묻기 때는 인터뷰어의 추측을 첫 선택지로 둔다(207행). steelman 절차의 질문은 이 규약을 적용하지 않는다고 명시한다(214-217행)."}
  - {id: RC5 (RC15), path: "plugins/spec-distill/skills/pm-interview/references/steelman.md", line: 92, claim: "steelman 질문은 선택지 순서를 유지 / 보완 / 전환 / 보류로 고정하고 추천을 첫 자리로 옮기지 않는다. 추천은 출처 라벨로만 표시하고 (권장)은 금지한다. 근거 문장은 「봉쇄는 추천·라벨 층에 있고 선택지를 제한하지 않는다」(78행)와 「선택은 언제나 사용자다」(75행)다. 보류는 사람만 고른다(88행)."}
  - {id: RC6 (RC16), path: "plugins/spec-distill/references/conductor-dispatch.md", line: 32, claim: "옮긴 질문은 하위 skill 원문의 선택지 수 · 순서 · 라벨 · 「(권장)」을 글자 그대로 둔다. 지휘자의 권장은 선택지 밖 「지휘자 의견:」 한 줄에만 쓴다. skill 이 문장으로 낸 권장은 라벨 꼬리 「(권장)」으로 바꾸지 않는다. 하위의 보고를 지휘자가 질문으로 만든 「지휘자가 만든 질문」에는 「(권장)」을 달지 않는다. conducting.md 102행도 같은 규칙을 반복한다."}
  - {id: RC7 (RC17), path: "plugins/spec-distill/skills/request-framing/SKILL.md", line: 928, claim: "저자 편집 덩어리마다 묻는 질문(「그대로 둔다 / 되돌린다」)은 의도적으로 추천을 두지 않으며, 그 근거가 문장으로 적혀 있다."}
  - {id: RC8 (RC18), path: "plugins/spec-distill/skills/spec-review/SKILL.md", line: 702, claim: "로드맵 에픽의 ③ 후속 질문에서는 지적에 맞는 쪽 라벨에 (권장)을 달고, 설명에 이유 한 줄을 붙인다. 추천 위치가 고정이 아니라 지적에 따라 모델이 정하는 꼴이다. roadmap 줄이 없는 문서의 세 갈래에는 추천 규정이 없다(697 · 753행)."}
  - {id: RC9 (RC19), path: "plugins/spec-distill/skills/spec-review/SKILL.md", line: 692, claim: "spec-review 의 (권장) 자리는 다섯이다 — ① 승인 게이트 2단계 ① · 지휘 세션 승인 질문 「승인 — 계획 담당자에게」(권장)(766행) · 동시 리뷰 표지 충돌 「그만둠 (권장)」(301행; reviewing-brief 177 · request-framing 540 에도) · 로드맵 에픽 ③ 후속 갈래 · 둘째 질문은 정본을 따른다."}
  - {id: RC10 (RC20), path: "plugins/spec-distill/skills/request-framing/SKILL.md", line: 190, claim: "request-framing 의 (권장) 자리는 셋이다 — 「만들고 시작 (권장)」 · proceed 게이트 ① (1123행) · 둘째 질문 「인터뷰 (권장)」 및 「/compact 후 다음 단계로 (권장)」(1128행)."}
  - {id: RC11 (RC21), path: "plugins/spec-distill/skills/pm-interview/references/finishing.md", line: 510, claim: "B-2 proceed 게이트 ① 에 (권장)이 붙는다. 「선택지 넷의 개수 · 순서 · `(권장)` 은 어느 경우든 그대로」다(520-526행). 둘째 질문은 「brainstorming (권장)」 · 「<모델의 제안>」이다(528행)."}
  - {id: RC12 (RC22), path: "plugins/spec-distill/skills/pm-interview/references/state-file.md", line: 52, claim: "같은 seed 의 끝나지 않은 상태 파일이 있으면 묻는 질문에서 「이어 감」이 (권장)이다."}
  - {id: RC13 (RC23), path: "plugins/spec-distill/skills/reviewing-brief/SKILL.md", line: 261, claim: "원문 완전성 검사를 확인할 수 없을 때 묻는 질문은 멈추는 쪽이 (권장)이다."}
  - {id: RC14 (RC24), path: "plugins/spec-distill/skills/epic-conductor/SKILL.md", line: 116, claim: "다른 세션이 지휘 중일 때 넘겨받을지 묻는 질문은 읽기만이 (권장)이다. 로드맵이 여럿일 때 고르게 하는 질문(96행)에는 추천 규정이 없다."}
  - {id: RC15 (RC25), path: "plugins/spec-distill/references/conducting.md", line: 40, claim: "spec 승인 질문에 붙는 병렬 질문은 「병렬 (권장)」이다. conducting.md 는 이 질문을 «지휘자 질문»으로 분류한다(28행). 같은 문서의 흐름 승인 질문(35 · 101행)에는 추천 규정이 없다."}
  - {id: RC16 (RC26), path: "plugins/project-init/skills/project-init/SKILL.md", line: 74, claim: "project-init 의 (권장) 라벨은 다섯이다(교체 74 · AGENTS.md 로 옮기기 82 · 옮기기 247 · 더하지 않음 133 · 이대로 진행 189). 다른 꼴도 섞여 있다 — merge 전략 「Squash merge (clean history 권장)」(128) · release 포맷 「— default」(141). 표시 없는 자리: branching strategy(106-114) · commit scope(122) · 헌장 업데이트(148) · Law 1 게이트 3회 뒤(193-197)."}
  - {id: RC17 (RC27), path: "plugins/plugin-audit/skills/plugin-audit/SKILL.md", line: 84, claim: "축 고르기 질문의 (권장)은 여섯 축 전부다. 이어지는 다중 선택 축 질문 둘과 「다시 고르기 · 중단」(87-89행)에는 추천 규정이 없다."}
  - {id: RC18 (RC28), path: "plugins/quality-gates/skills/artifact-critique/SKILL.md", line: 188, claim: "artifact-critique 에서 (권장)이 있는 곳은 비평자 수 질문 하나다. 나머지 질문(97 · 133-140 · 178-183 · 293 · 351-353행)에는 추천 규정이 없다."}
  - {id: RC19 (RC29), path: "plugins/spec-distill/skills/pm-interview/references/saturation.md", line: 35, claim: "조사 상한 도달 질문은 '첫 선택지가 추천'이라고만 적고 (권장) 꼬리를 명시하지 않는다. 반복 감지(96) · 판정 불가(110) · 판정 상한(125) 질문에는 추천 규정이 없다. 이 질문들이 라운드 규약((권장) 꼬리) 적용을 받는지는 문서가 말하지 않는다."}
  - {id: RC20 (RC30), path: "plugins/spec-distill/references/proceed-gate.md", line: 60, claim: "정본은 지휘자 아래 승인 질문 셋에 (권장)을 적지 않는다. conducting.md 39 · 101행도 (권장) 없이 같은 셋을 나열한다. 반면 spec-review/SKILL.md 766행은 「승인 — 계획 담당자에게」(권장)으로 적는다. 같은 질문의 추천 표시가 문서마다 다르다(충돌)."}
  - {id: RC21 (RC31), path: "plugins/spec-distill/references/conductor-dispatch.md", line: 32, claim: "「지휘자가 만든 질문」에는 (권장)이 금지되는데 conducting.md 40행의 병렬 질문은 지휘자 질문이면서 「병렬 (권장)」을 단다. 금지 문장의 범위가 '하위 보고를 질문으로 만든 경우'로 한정되는지 문면으로는 확정되지 않는다(충돌 가능성)."}
  - {id: RC22 (RC32), path: "plugins/spec-distill/skills/pm-interview/references/finishing.md", line: 33, claim: "분해 판단 질문은 권고를 선택지 밖 문장 한 줄로 내고 라벨에는 (권장)이 없다. 근거 「컷오프는 두지 않는다 — 숫자는 판단 재료이고 판정은 사용자가 한다」(28행). 같은 파일의 다른 질문들(63 · 319-333 · 260 · 396행)에도 추천 규정이 없다."}
  - {id: RC23 (RC33), path: "plugins/spec-distill/references/trivia-escape.md", line: 13, claim: "trivia 질문에는 (권장)이 없다. 「판정은 모델이 했고, 건너뛸지는 사용자가 고른다」가 유일한 근거로 읽히고 명시적 '권장 금지' 문장은 없다."}
  - {id: RC24 (RC34), path: "plugins/spec-distill/references/redecompose.md", line: 60, claim: "재분해 승인 질문에는 (권장)이 없고, 없다는 근거 문장도 없다."}
  - {id: RC25 (RC35), path: "plugins/spec-distill/skills/spec-review/SKILL.md", line: 574, claim: "문서 리뷰 라운드 게이트의 라벨 규약은 상태별 라벨과 대체안 압축만 정하고 추천 표시는 정하지 않는다(shared/docreview/references/reviewing-document.md 42행 · docreview_state.py `_CHOICE_LABEL` 도 같다). 1단계 추가 라운드 · 후보 문서 고르기 · 참고 전부 보기에도 추천 규정이 없다."}
  - {id: RC26 (RC36), path: "plugins/spec-distill/skills/request-framing/SKILL.md", line: 255, claim: "추천 규정이 없는 request-framing 질문들 — 풀이 확인(multiSelect) · 중복 제목(602) · 기준 사본 없음(932) · 덜어 낸 것(1169) · 라운드 질문(230-240)."}
  - {id: RC27 (RC37), path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md", line: 807, claim: "quality-pipeline 의 AskUserQuestion 다섯 자리(711 · 819 · 840 · 923 · 997행)에는 (권장)이 하나도 없고, 없는 이유를 적은 문장도 없다. 이 SKILL 도 plain-language 블록(52행)을 담고 있어 정본 문면과 어긋난다."}
  - {id: RC28 (RC38), path: "plugins/quality-gates/references/e2e.md", line: 39, claim: "e2e 시나리오 질문은 모델 판단을 첫 선택지 자리와 사유 문구로 표시하고 (권장)도 '추천'이라는 말도 쓰지 않는다. 걷기 직후 게이트(100-107행)에도 추천 표시가 없다."}
  - {id: RC29 (RC39), path: "shared/tests/plain_language_block.py", line: 31, claim: "블록이 H1 바로 다음에 있는지, 정본과 바이트가 같은지를 본다. skill 본문의 질문 · 선택지가 그 규칙을 따르는지는 재지 않는다."}
  - {id: RC30 (RC40), path: "plugins/spec-distill/tests/test_conducting_interview_stage.sh", line: 808, claim: "라운드 규약 문구와 steelman 출처 라벨 리터럴을 잰다. 주석이 스스로 한계를 밝힌다 — 실제 런타임 라벨은 못 잰다."}
  - {id: RC31 (RC41), path: "plugins/spec-distill/tests/test_seed_at_path_handoff.sh", line: 100, claim: "proceed 게이트 ① 행에만 권장이 있는지를 잰다(test_review_handoff_order.sh 176-191 도). ③·④ 행에 권장이 생기는지는 재지 않는다."}
  - {id: RC32 (RC42), path: "plugins/spec-distill/tests/test_conductor_dispatch_reference.sh", line: 30, claim: "옮김 · 권장 규칙 문장이 정확히 한 번 있는지를 잰다. 문서 문구가 있는지만 잰다."}
  - {id: RC33 (RC43), path: "plugins/spec-distill/agents/relay-checker.md", line: 32, claim: "실제로 띄운 질문의 (권장)을 런타임에 대조하는 곳은 이 agent 하나다. 대상은 에픽 끝의 relay-*.md 뿐이고, 추천이 있어야 할 자리에 없는지는 판정하지 않는다. 지휘자를 거치지 않은 질문은 범위 밖. 막지 않는다."}
  - {id: RC34 (RC44), path: "plugins/spec-distill/tests/test_framing_review_contract.sh", line: 141, claim: "의도적으로 추천을 두지 않는 자리(RC17)의 금지 문장이 있는지만 잰다."}
  - {id: RC35 (RC45), path: "plugins/project-init/tests/test_command_contract.py", line: 253, claim: "개별 (권장) 라벨 리터럴 락이 여럿 흩어져 있다(project-init · plugin-audit · quality-gates · spec-distill 의 열 개 남짓 테스트). 모두 문서에 문구가 있는지만 잰다."}
  - {id: RC36 (RC46), path: "plugins/spec-distill/CHANGELOG.md", line: 1131, claim: "라운드 게이트 라벨 규약을 재는 락이 문구가 있는지만 잰다는 한계를 CHANGELOG 가 스스로 공시한다. 이 규약에는 추천 표시 항목 자체가 없다."}
unanswered: "레포 안의 질문 자리를 전부 훑어 (권장)이 있어야 할 곳의 «부재»나 표시 꼴의 일관성을 재는 락 · 스크립트는 찾지 못했다. 모델이 런타임에 띄운 실제 선택지 라벨을 재는 장치는 relay-checker(지휘자가 옮긴 질문 한정) 말고는 없다. RC20 · RC21 의 범위 충돌은 문면으로 확정되지 않는다."
```
(원문의 anchor 필드와 touches/decides(전부 []) 는 줄임 — 원문 anchor 는 V1 확인 줄에 실었다. 조사 범위: AskUserQuestion · (권장) · Recommended · 추천 · 권장 grep 53 · 45 파일, 자유문 질문 자리는 제외, 훅에는 질문 자리 없음)

## R1

### 지금 이해
요청은 한 줄 원칙이다. 레포를 보니 같은 규칙이 이미 공통 문체 규칙에 있고(RC1), 지켜지지 않는 자리 · 일부러 안 다는 자리 · 문서끼리 어긋나는 자리가 섞여 있다. 경로 (a) 로 확인 — 조사 두 개를 함께 띄웠다(서로 기대지 않는 레포 전수 조사와 차원 지도).
- 확인 RC1 — 확인 — shared/style/plain-language.md#추천은 「(권장)」으로 표시한다 — 주장과 일치
- 확인 RC2 — 확인 — shared/tests/test_plain_language_block.sh#블록 동일성 — 주장과 일치(복제만 잰다)
- 확인 RC3 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#고치고 다시 돌기 — 주장과 일치(다섯 자리 모두 (권장) 없음)
- 확인 RC4 — 확인 — plugins/spec-distill/skills/pm-interview/references/saturation.md#중 하나를 받는다 — 주장과 일치
- 확인 RC5 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#첫 선택지가 추천 — 주장과 일치
- 확인 RC6 — 확인 — plugins/spec-distill/skills/pm-interview/references/steelman.md#추천 표시는 출처 라벨뿐 — 주장과 일치
- 확인 RC7 — 확인 — plugins/spec-distill/agents/relay-checker.md#지휘자가 만든 질문의 라벨에 (권장) — 주장과 일치
- 확인 RC8 — 확인 — plugins/spec-distill/skills/spec-review/SKILL.md#설명에 이유 한 줄 — 주장과 일치
- 확인 RC9 — 확인 — plugins/quality-gates/skills/artifact-critique/SKILL.md#산출물로 비평할까요 — 주장과 일치
- 확인 RC10 — 확인 — plugins/spec-distill/tests/test_conductor_dispatch_reference.sh#의견 줄에만 쓴다 — 주장과 일치
- 확인 RC11 — 확인 — shared/style/plain-language.md#6행 — RC1 과 같은 자리
- 확인 RC12 — 미확인 — CLAUDE.md#Law 1 — 부재 주장(grep 0건)은 하한, 따로 재지 않음
- 확인 RC13 — 미확인 — plugins/spec-distill/references/proceed-gate.md#Step B — 이번 라운드 표본 밖
- 확인 RC14 — 확인 — pm-interview/SKILL.md#202 — RC5 와 같은 자리
- 확인 RC15 — 확인 — steelman.md#92 — RC6 과 같은 자리
- 확인 RC16 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#지휘자 자신의 권장은 — 주장과 일치
- 확인 RC17 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#권장 표시를 달지 않는다 — 주장과 일치
- 확인 RC18 — 확인 — spec-review/SKILL.md#702 — RC8 과 같은 자리
- 확인 RC19 — 미확인 — spec-review/SKILL.md#692 — 766행만 확인(일치), 나머지 자리는 표본 밖
- 확인 RC20 — 미확인 — request-framing/SKILL.md#만들고 시작 (권장) — 표본 밖
- 확인 RC21 — 확인 — pm-interview/references/finishing.md#확정하고 /compact 후 brainstorming (권장) — 주장과 일치
- 확인 RC22 — 확인 — pm-interview/references/state-file.md#이어 감 (권장) — 주장과 일치
- 확인 RC23 — 확인 — reviewing-brief/SKILL.md#멈춘다 (권장) — 주장과 일치
- 확인 RC24 — 확인 — epic-conductor/SKILL.md#읽기만 (권장) — 주장과 일치
- 확인 RC25 — 확인 — references/conducting.md#병렬 (권장) — 주장과 일치
- 확인 RC26 — 확인 — project-init/SKILL.md#교체 (권장) — 주장과 일치(128 · 141행 다른 꼴도 확인)
- 확인 RC27 — 확인 — plugin-audit/SKILL.md#여섯 축 전부 (권장) — 주장과 일치
- 확인 RC28 — 확인 — artifact-critique/SKILL.md#1명 (권장) — 주장과 일치
- 확인 RC29 — 확인 — saturation.md#첫 선택지가 추천 — 주장과 일치
- 확인 RC30 — 확인 — proceed-gate.md#60 · spec-review/SKILL.md#766 — 주장과 일치(정본 없음 · 사본 (권장) — 충돌 실재)
- 확인 RC31 — 확인 — conductor-dispatch.md#32 · conducting.md#40 — 주장과 일치(충돌 가능성 실재)
- 확인 RC32 — 확인 — finishing.md#권고 한 줄 · #컷오프는 두지 않는다 — 주장과 일치
- 확인 RC33 — 미확인 — trivia-escape.md#13 — 문장은 실재(이 인터뷰 진입 때 읽음), «유일한 근거» 여부는 해석
- 확인 RC34 — 확인 — redecompose.md#이대로 다시 나눈다 — 주장과 일치
- 확인 RC35 — 미확인 — spec-review/SKILL.md#574 — 표본 밖
- 확인 RC36 — 미확인 — request-framing/SKILL.md#풀이 1 — 표본 밖
- 확인 RC37 — 확인 — quality-pipeline/SKILL.md#Fix-loop decision — RC3 과 같은 사실
- 확인 RC38 — 확인 — quality-gates/references/e2e.md#걸을 것 없음 — 주장과 일치
- 확인 RC39 — 확인 — shared/tests/plain_language_block.py — RC2 와 같은 사실
- 확인 RC40 — 확인 — test_conducting_interview_stage.sh#808 — 주장과 일치
- 확인 RC41 — 미확인 — test_seed_at_path_handoff.sh#100 — 표본 밖
- 확인 RC42 — 확인 — test_conductor_dispatch_reference.sh#30 — RC10 과 같은 자리
- 확인 RC43 — 확인 — relay-checker.md#32 — 주장과 일치
- 확인 RC44 — 미확인 — test_framing_review_contract.sh#141 — 표본 밖
- 확인 RC45 — 미확인 — project-init/tests/test_command_contract.py#253 — 표본 밖
- 확인 RC46 — 미확인 — spec-distill/CHANGELOG.md#1131 — 표본 밖
조사 호출 2/60 · 이 라운드 본체 직접 1

### 다음 결정
OQ1: 이 일이 고치려는 핵심 문제 · 추천: 규칙은 있는데 안 지켜진다 · 트레이드오프: 미준수 → 질문 자리를 고치고 지키게 만드는 장치 / 표시 불명확 → 표기 꼴 하나로 통일 / 층위 → CLAUDE.md 상위 원칙으로 올림(문장만 늘 수 있음)

### 질문
(경로 d — 무엇이 문제인가) 이 원칙을 꺼내게 된 실제 문제는 무엇인가?

### 답
→ S2

## R2

### 지금 이해
S2 로 핵심 문제는 «규칙은 있는데 안 지켜진다»로 좁혀졌다. 다만 추천 선택지를 이유 없이 고른 답이라(되묻기 조건) 실제 사례를 되묻는다 — 어디서 겪었는지가 적용 범위(scope)와 고칠 자리 우선순위를 정한다.
조사 호출 2/60 · 이 라운드 본체 직접 0

### 다음 결정
OQ1: 이 일이 고치려는 핵심 문제(이어감 — 사례 되묻기) · 추천: 품질 검사 반복 질문 · 트레이드오프: 특정 플러그인 사례면 그 자리부터 / 외부 skill 이면 범위가 devbrew 밖으로 넓어짐 / 사례 없음이면 전수 기준 정비

### 질문
(경로 b — 되묻기: 사례) 추천 없는 질문을 실제로 겪은 자리는 어디였나?

### 답
→ S3

## R3

### 지금 이해
S3 의 분해 판단 사례를 확인했다 — finishing.md 「분해 판단」 질문은 본문이 「신호 셋과 권고를 위에 적었다」이고 선택지 「spec 하나로」 · 「나눈다 — 분해안 보기」에 추천 표시가 없다. 권고는 질문 위 터미널 글 한 줄에만 있다(설계 2026-10-15-interview-pm-decompose-design.md AC1 이 정한 꼴 — 라벨 추천을 일부러 뺀 근거 문장은 없다). 사용자는 권고(로드맵)와 반대(스펙 하나)를 골랐다. → root_problem 닫힘(S1 · S2 · S3). 같은 꼴(추천이 선택지 밖에만 있음)이 지휘자 의견 줄(RC16)에도 있다. blind-spot-prober(필수 첫 호출)와 open-researcher(AskUserQuestion 공식 관례 · 추천 표시의 기준점 효과 근거)를 함께 띄웠다 — 둘 다 이 라운드 질문과 기대지 않는다.
- 확인 RC47 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#신호 셋과 권고를 위에 적었다 — 선택지에 (권장) 없음 · 권고는 33행 문장
조사 호출 4/60 · 이 라운드 본체 직접 1

### 다음 결정
OQ2: 선택지 밖에만 둔 추천 · 추천: 추천이 있으면 그 선택지 라벨에 반드시 (권장) · 트레이드오프: 라벨 의무 → 이번 실수가 막힘, 지휘자 의견 줄 규칙과 relay-checker 대조를 바꿔야 함 / 문장 유지하되 질문 본문 첫머리로 → 변경 작지만 라벨만 보고 고르면 여전히 놓침
OQ3: 정직하게 추천이 없는 질문 · 추천: 질문 본문에 「추천 없음 — <이유>」 명시 · 트레이드오프: 명시 → 없음과 빠뜨림이 구별됨 / 그냥 둠 → 지금과 같아 빠뜨림과 구별 안 됨 / 무조건 하나 고름 → 꾸며 낸 추천이 생김

### 질문
(경로 b) OQ2 · OQ3 두 질문을 한 호출에 묶음.

### 답
→ S4 (OQ2) · S5 (OQ3) · 같은 턴 끼어든 발화 S6

## R4

### 지금 이해
S4 로 «추천이 있으면 라벨에 (권장) 의무», S5 로 «없으면 본문에 「추천 없음 — 이유」»가 정해졌다. S6 이 더한 것: 추천이 여럿이면 여럿 모두에 (권장)을 단다 — 「꼭 하나」 제약이 아니다. S5 는 추천을 이유 없이 고른 답이라 실패 조건을 되묻는다 — 「추천 없음」이 모델이 추천 의무를 피하는 통로가 될 수 있다(OQ6).
조사 호출 4/60 · 이 라운드 본체 직접 0

### 다음 결정
OQ6: 「추천 없음」 허용 조건 · 추천: 사용자만 아는 것(취향 · 사용자가 가르는 게 목적)일 때만 + 이유 필수 · 트레이드오프: 좁게 → 회피 막힘, 판정 경계가 모호한 자리는 모델 판단 / 넓게(모델이 자신 없으면) → 남발 위험 / 금지(S6 과 합쳐 여럿 권장으로 대체) → 꾸며 낸 추천

### 질문
(경로 b — 되묻기: 실패 조건) OQ6.

### 답
→ S7

### 조사 3 — blind-spot-prober · R3 · 묶음 2

(subagent 임시 id → 인터뷰 번호: RC1→RC48 · RC2→RC49 · RC3→RC50 · RC4→RC51 · RC5→RC52 · RC6→RC53)

원문 요지 문단(그대로): 가장 큰 숨은 가정은 S3 사례의 원인을 «라벨에 (권장)이 없어서»로 본 것입니다. 이 사례에는 원인 후보가 하나 더 있습니다. Claude Code 에는 AskUserQuestion 대화창이 같은 턴의 앞선 글을 가리거나 아예 그리지 않는 버그가 여러 건 보고돼 있습니다(일부는 열려 있음). finishing.md 의 분해 판단 질문은 권고를 «위에 적었다»는 앞선 글에 기대고 있습니다. 따라서 선택지 밖 채널은 표시 규칙과 별개로 화면 계층에서 신뢰할 수 없고, 이 근거는 OQ2 쪽으로 기웁니다. 반대 방향의 위험도 있습니다. 일괄 의무화는 레포가 일부러 둔 기준점 방지 예외(steelman · 저자 편집 덩어리 · 지휘자 relay)와 정면으로 부딪칩니다. 특히 relay-checker 는 «문장 권장이 라벨 꼬리로 옮겨짐»을 어긋남으로 잡도록 적혀 있습니다. 그래서 OQ2 를 그대로 의무화하면 이 수정 자체를 relay-checker 가 위반으로 잡습니다.

```yaml
hidden_assumptions:
  - assumption: "S3 실패의 원인은 «라벨에 (권장)이 없어서»다 — 라벨에 달면 해결된다"
    why_risky: "사용자는 «위에 터미널 글은 추천은 로드맵이라 나왔음»이라고 했다. 권고는 있었는데 고를 때 보이지 않았거나 늦게 보였을 수 있다. AskUserQuestion 창이 같은 턴의 앞선 글을 가리거나 아예 그리지 않는 버그가 Claude Code 에 반복 보고돼 있다. 그렇다면 원인은 표시 규칙 위반이 아니라 «선택지 밖 채널이 화면에서 사라짐»이다. 처방은 '규칙 문장 강화'가 아니라 '추천을 질문 도구 안(라벨·설명·질문문)에 둔다'가 되어야 한다. 원인을 문체 규칙 미준수로 잘못 짚으면 정본 문장만 고치고 '위에 적었다' 류 질문은 그대로 남는다."
    evidence:
      - {url: "https://claudeissues.com/issue/75182-bug-assistant-text-preceding-an-askuserquestion-call-in-the-same-turn-is-never-d", supports: alternative, claim: "터미널 CLI 에서 AskUserQuestion 직전의 같은 턴 글이 질문 전에도, 답한 뒤 스크롤백에도 보이지 않는다(2026-07 보고, 열림, 메인테이너 재현. Fable 계열 모델에서 재현, 기본 Opus 에선 아님)", decides: [OQ2], source_kind: secondary, checked_at: "2026-10-27", certainty: confirmed}
      - {url: "https://claudeissues.com/issue/67475-askuserquestion-dialog-hides-preceding-assistant-message-text-until-the-question", supports: alternative, claim: "질문 창이 앞선 글을 가려, 답하거나 닫기 전에는 그 글을 볼 수 없다(#67475, 2026-06 종결). 같은 계열 보고가 #23862 · #46825 · #62493 · #65662 · #73629(VS Code) · #77238(간헐)로 여러 판·표면에 걸쳐 있다", decides: [OQ2], source_kind: secondary, checked_at: "2026-10-27", certainty: confirmed}
      - {url: "https://claudeissues.com/issue/77238-assistant-text-in-the-same-turn-as-an-askuserquestion-tool-call-is-intermittentl", supports: alternative, claim: "같은 턴 글이 간헐적으로 렌더되지 않는다. 긴 글이나 펜스·인용이 들어간 글은 통째로 빠지고, 평문은 마지막 문단이 빠진다. 신호 셋 + 권고 한 줄 같은 구조가 바로 위험 모양이다", decides: [OQ2], source_kind: secondary, checked_at: "2026-10-27", certainty: uncertain}
  - assumption: "추천을 드러내는 것은 언제나 사용자에게 이롭다 — 기준점 효과 방지 예외들은 부수적이다"
    why_risky: "레포의 예외 넷은 구조적 이유로 있다. builder/orchestrator 기준점 방지, 저자가 자기 편집을 승인하지 않게 하는 Law 2, 지휘자 relay 의 원문 보존이다. «모든 질문에 (권장)» 원칙을 문면 그대로 두면 이 예외들이 위반처럼 읽힌다. 예외를 정본에 명시하지 않으면 다음 수정자가 예외를 '준수'시키는 쪽으로 고친다. 기본값 연구는 '권장' 꼬리표 자체가 선택을 크게 끌고, 사람이 그 근거를 모른 채 따른다고 보고한다. AI 조언은 AI 출처라는 사실만으로도 과신된다."
    evidence:
      - {url: "https://www.cambridge.org/core/product/48A391D40E7A5A54347BFDC757240F46", supports: current, claim: "'recommended default' 표시가 선택을 끌어당긴다. 기본값의 효과 크기는 메타분석에서 d≈0.68이다. 사람들은 기본값을 '권장 경로'로 가정하지만 그 권장의 근거는 불분명하다", decides: [OQ2, OQ3], source_kind: secondary, checked_at: "2026-10-27", certainty: uncertain}
      - {url: "https://arxiv.org/abs/2102.09692v1", supports: current, claim: "AI 결정에 설명을 붙여도 과의존이 줄지 않고 오히려 늘 수 있다. 과의존을 줄인 것은 cognitive forcing(먼저 스스로 판단하게 하기)이었다. steelman 의 '추천을 첫 자리로 옮기지 않는다'와 같은 계열 근거다", decides: [OQ2, OQ3], source_kind: primary, checked_at: "2026-10-27", certainty: uncertain}
  - assumption: "추천하는 쪽(모델)은 그 질문에서 중립적인 권고자다"
    why_risky: "quality-pipeline 의 「낮춘 지적」 게이트와 request-framing 의 저자 편집 덩어리 질문에서는 질문을 띄우는 모델이 곧 그 코드·문서를 쓴 쪽이다. 여기서 (권장)을 의무화하면 writer 가 자기 산출물에 대한 리뷰 처분을 권하게 된다(Law 2, Self-approval). 'quality-pipeline 다섯 자리 전부 (권장) 없음'을 미준수로만 세면, 그중 일부가 정당한 무권장일 가능성을 놓친다. LLM 의 조언은 사용자 쪽으로 기우는 아첨 경향도 측정돼 있다."
    evidence:
      - {url: "https://alphaxiv.org/abs/2505.13995", supports: current, claim: "11개 모델의 조언이 사용자 자기상을 사람보다 훨씬 더 보존한다. 도덕 갈등에서 사용자가 선 쪽을 48% 긍정한다. 선호 데이터가 이 아첨을 보상한다", decides: [OQ3], source_kind: primary, checked_at: "2026-10-27", certainty: uncertain}
  - assumption: "질문은 SKILL.md 안의 고정 리터럴이라 정적 락으로 준수를 잴 수 있다"
    why_risky: "실제 선택지는 실행 중에 모델이 채운다(예: 지적마다 「<파일 이름>:<줄> (L<k>)」). 템플릿에 '(권장)'이 있어도 실행 때 빠질 수 있고, 템플릿이 자리표시자뿐이면 락은 잴 것이 없다. 사실 확인에 나온 그대로 지금 락은 블록 복제만 재고 질문 준수는 재지 않는다. 락을 더해도 같은 맹점(템플릿 ≠ 실제 질문)이 그대로 남는다."
    evidence: []
  - assumption: "표시 꼴은 devbrew 가 정하는 「(권장)」 하나다"
    why_risky: "Claude Code 의 AskUserQuestion 도구 설명은 추천을 첫 자리에 두고 라벨 끝에 '(Recommended)'를 붙이라고 안내한다고 여러 2차 출처가 전한다. 모델은 도구 규약을 따라 영어 '(Recommended)'를 내거나 둘을 섞을 수 있다. 관찰된 «꼴이 섞임»의 한 원인일 수 있다. 「(권장)」 리터럴에 묶인 락·훅은 '(Recommended)'를 미준수로 잘못 잡거나 놓친다. 외부 skill(brainstorming 등)은 도구 규약 꼴을 쓸 것이다."
    evidence:
      - {url: "https://juejin.cn/post/7667440437863874560", supports: both, claim: "AskUserQuestion 도구 설명은 추천 선택지를 첫 자리에 두고 라벨에 '(Recommended)' 접미사를 붙이라고 한다. 별도 boolean 필드는 없고 위치와 접미사로만 표시한다", decides: [OQ4, OQ5], source_kind: secondary, checked_at: "2026-10-27", certainty: uncertain}
failure_modes:
  - mode: "OQ2 를 '라벨 (권장) 의무'로 정하면 지휘자 relay-checker 가 그 수정 자체를 어긋남으로 잡는다"
    trigger: "pm-interview 분해 판단 같은 skill 원문이 '문장 권장'에서 '라벨 꼬리'로 바뀌었는데 relay-checker 의 4번 규칙과 지휘자 락은 옛 계약 그대로일 때. 또는 반대로 skill 은 그대로이고 지휘자가 정본 새 규칙을 따라 라벨에 붙일 때"
    evidence: []
  - mode: "PreToolUse 훅으로 강제하면 devbrew 밖 질문까지 막거나 잘못 판정한다(범위 누수)"
    trigger: "matcher=AskUserQuestion 훅은 세션의 모든 질문에 발동하는데, payload 만으로는 어느 skill 이 띄웠는지 가를 수 없을 때. brainstorming 같은 외부 skill 의 '(Recommended)'나 무권장 질문이 deny 된다. 이 훅 경로는 과거에 답을 비우는 버그도 있었다"
    evidence:
      - {url: "https://claudeissues.com/issue/13439-pretooluse-hook-causes-askuserquestion-tool-to-return-empty-responses", supports: current, claim: "PreToolUse 훅이 켜져 있으면 AskUserQuestion 이 사용자 선택을 빈 값으로 돌려준 버그가 있었다(2026-01 종결). 이 훅 경로가 질문 도구의 답 흐름에 끼어든다는 뜻이다", decides: [OQ4], source_kind: secondary, checked_at: "2026-10-27", certainty: uncertain}
      - {url: "https://claudeissues.com/issue/39620-docs-hooks-reference-missing-askuserquestion-pretooluse-answer-flow", supports: current, claim: "hooks 문서에 AskUserQuestion 의 PreToolUse 답 흐름이 빠져 있다는 문서 이슈가 있다. tool_input 구조가 공식 문서에 고정돼 있지 않아 훅이 기댈 계약이 약하다", decides: [OQ4], source_kind: secondary, checked_at: "2026-10-27", certainty: uncertain}
  - mode: "「추천 없음 — 이유」 의무가 형식 채우기(boilerplate)로 퇴화한다"
    trigger: "모든 무권장 질문에 이유 한 줄을 요구하는데, 기계는 이유의 진정성을 잴 수 없고 리뷰어도 실행 중 질문을 보지 못할 때. 결정론은 보안·정확성에만(P8)이라 이 칸은 끝내 모델 판단이고, 문구만 채워진 '추천 없음 — 취향 문제'가 늘어난다. 진짜 추천이 있는데 책임을 피하려고 '추천 없음'으로 빠지는 길도 열린다"
    evidence: []
  - mode: "추천을 라벨에 단 뒤 사용자가 추천을 거스른 선택(S3 의 '스펙')이 '실패'로 재분류된다"
    trigger: "framing 이 '추천과 다른 선택 = 정보 부족'으로 읽을 때. 사용자 선택이 정당했을 수도 있다(P17). 그런데 추천을 첫 자리에 두면 기본값 효과로 추천 쪽 선택이 기계적으로 는다. '추천이 잘 보였는가'와 '추천을 따랐는가'를 섞으면 따른 비율을 성공 지표로 삼는 함정에 빠진다"
    evidence:
      - {url: "https://www.cambridge.org/core/product/48A391D40E7A5A54347BFDC757240F46", supports: current, claim: "권장 기본값의 수용은 기본값이 실제로 유리할 때만이 아니라 표시만으로도 일어난다. 경험에 따라 수용 여부가 달라진다", decides: [OQ2], source_kind: secondary, checked_at: "2026-10-27", certainty: uncertain}
confidence: 0.75
repo_claims:
  - {id: RC1 (RC48), path: "shared/style/plain-language.md", anchor: "추천은 「(권장)」으로 표시한다", line: 6, claim: "정본은 표시 꼴만 정하고 의무 여부는 정하지 않는다. 같은 블록 3행은 '부른 skill 이 메시지 모양을 정한 대화(예: brainstorming)에서는 그 skill 을 따르고 이 블록은 낱말에만 적용한다'고 적어 외부 skill 질문을 이미 범위 밖으로 둔다", decides: [OQ4, OQ5]}
  - {id: RC2 (RC49), path: "plugins/spec-distill/skills/pm-interview/references/finishing.md", anchor: "question: \"신호 셋과 권고를 위에 적었다. 이 일을 어떻게 진행할까?\"", line: 38, claim: "S3 의 분해 판단 질문은 권고를 질문 위 글(33행 '이어서 권고 한 줄')에만 두고, 질문문은 '위에 적었다'로 그 글을 가리킨다. 선택지에는 권장이 없다. 28행은 '판정은 사용자가 한다'로 무권장을 의도로 적었다. 앞선 글이 가려지면 이 질문은 추천 정보를 잃는다", decides: [OQ2]}
  - {id: RC3 (RC50), path: "plugins/spec-distill/agents/relay-checker.md", anchor: "「문장 권장이 라벨 꼬리로 옮겨짐」", line: 32, claim: "relay-checker 는 skill 원문이 권장을 문장으로 냈는데 띄운 질문 라벨에 (권장) 꼬리가 붙으면 어긋남으로 판정한다. 라벨 의무화(OQ2)는 이 persona 와 test_conducting_reference.sh · test_conductor_dispatch_reference.sh 의 문구 락을 함께 고치지 않으면 서로 충돌한다", decides: [OQ2, OQ4]}
  - {id: RC4 (RC51), path: "plugins/spec-distill/skills/pm-interview/references/steelman.md", anchor: "도구·라운드 규약의 `(Recommended)`·`(권장)` 접미사는 붙이지 않는다", line: 92, claim: "steelman 질문은 고정 순서와 출처 라벨만 쓰고 (Recommended)·(권장)을 금지한다. 레포 스스로 '(Recommended)'를 도구 규약 꼴로 인지하고 있다는 증거이고, 일괄 의무화의 명시적 예외 대상이다", decides: [OQ2, OQ3]}
  - {id: RC5 (RC52), path: "plugins/spec-distill/skills/request-framing/SKILL.md", anchor: "**권장 표시를 달지 않는다** —", line: 928, claim: "저자 편집 덩어리 질문은 '저자의 권장은 바로 그 가름을 저자가 하는 것'이라는 Law 2 근거로 무권장이다. test_framing_review_contract.sh:141 이 이 문구를 잠근다. 일괄 의무는 이 락과 정면 충돌한다", decides: [OQ3]}
  - {id: RC6 (RC53), path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md", anchor: "header: \"낮춘 지적\"", line: 713, claim: "선택지가 실행 중에 지적마다 동적으로 채워진다(<파일 이름>:<줄> (L<k>)). 처분 대상은 재비판이 낮춘 리뷰 지적이다. 정적 락은 이 동적 라벨의 권장 준수를 잴 수 없다. 오케스트레이터가 고친 코드에 대한 지적이면 '그대로 둔다 (권장)'은 writer 의 리뷰 처분 권고가 된다. '다섯 자리 전부 미준수' 판정을 자리마다 다시 갈라야 한다", decides: [OQ3, OQ4]}
```
(모든 항목 touches: [] — 원문 그대로)

## R5

### 지금 이해
S7 로 「추천 없음」은 사용자만 아는 것뿐 아니라 근거가 모자라 모델이 판단 못 할 때도 허용된다(이유 필수). blind-spot-prober 결과를 확인했다 — 질문 창이 같은 턴 앞 글을 가리는 Claude Code 버그는 1차 출처(GitHub)로 확인: #67475 «AskUserQuestion dialog hides preceding assistant message text until the question is answered»(2026-06 종결) · #75182 «Assistant text preceding an AskUserQuestion call in the same turn is never displayed»(2026-07, 열림). S3 의 «위에 터미널 글은 추천은 로드맵이라 나왔음»이 질문 전에 본 것인지 답한 뒤 본 것인지가 원인을 가른다.
- 확인 RC48 — 확인 — shared/style/plain-language.md#3·6행 — RC1 과 같은 자리, 3행 외부 skill 예외 확인
- 확인 RC49 — 반증 — plugins/spec-distill/skills/pm-interview/references/finishing.md#28행 — 그 자리는 «숫자 신호에 컷오프를 두지 않는다»이고 33행은 오히려 권고 한 줄을 내게 한다. 주장은 «28행이 무권장을 의도로 적었다»였다(38행 · 선택지 무권장 부분은 확인)
- 확인 RC50 — 확인 — plugins/spec-distill/agents/relay-checker.md#문장 권장이 라벨 꼬리로 옮겨짐 — 주장과 일치
- 확인 RC51 — 확인 — steelman.md#92 — 주장과 일치
- 확인 RC52 — 확인 — request-framing/SKILL.md#928 — 주장과 일치
- 확인 RC53 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#낮춘 지적 — 동적 라벨 · multiSelect 확인. «writer 의 처분 권고» 는 해석
- 웹 #67475 · #75182 — 1차(GitHub `gh issue view`)로 제목 · 상태 · 날짜 확인. #77238 · #13439 · #39620 · 연구 논문 넷 — 확인 못 함(2차 그대로)
조사 호출 4/60 · 이 라운드 본체 직접 2

### 다음 결정
OQ7: S3 의 원인 — 권고가 질문 창에 가려졌나 · 추천: 답한 뒤에야 보였다 · 트레이드오프: 가려짐 → «추천은 질문 도구 안에만» 이 핵심 규칙 / 보였는데 놓침 → 라벨 표시 강도가 핵심
OQ8: 숨은 가정·실패 양식 처분(blind_spot) — 어느 것을 brief 의 제약으로 받을까 · 추천: 넷 다(도구 안에만 · 자기 처분은 추천 없음 · 지휘자 규칙 함께 고침 · (Recommended) 같은 표시로 인정) · 트레이드오프: 받으면 설계 제약 / 안 받으면 §5 위험으로만 남음

### 질문
(경로 b) OQ7 · OQ8 한 호출에 묶음.

### 답
→ S8 (OQ7) · S9 (OQ8)

### 조사 4 — open-researcher · R3 · 묶음 2

(subagent 임시 id → 인터뷰 번호: RC1→RC54 · RC2→RC55 · RC3→RC56)

원문 요점(그대로): 추천 전용 필드는 없다. 공식 스키마의 선택지는 `label` · `description` 뿐이다(TS SDK 는 선택적으로 `preview` 를 더한다). 추천은 도구 설명문에만 있는 관례다. 추천하는 선택지를 첫 자리에 두고 라벨 끝에 「(Recommended)」를 단다. 이 문장은 공식 문서에 없고 2차 추출본에서만 읽혔다. 설명문은 multiSelect 일 때의 추천 표시와 추천이 없을 때의 표시를 정하지 않는다. PreToolUse 훅은 AskUserQuestion 의 `tool_input` 을 받는다(공식). 훅은 deny 로 막을 수 있고 `updatedInput` 으로 입력 전체를 바꿀 수 있다. 다만 바꾼 질문이 사용자 대화창에 그대로 보이는지는 공식 문서로 확인하지 못했다. Microsoft 는 추천을 라벨에 달라고 한다. 「(recommended)」를 보충 설명이 아니라 라벨 자체에 단다. 추천이 없을 때 그 사실을 따로 밝히라는 관례는 찾지 못했다. 연구는 같은 쪽을 가리킨다. 기본값은 함축된 추천으로 읽힌다. 기본값이라고 밝혀도 효과는 줄지 않는다. 시각 목록에서는 첫 자리가 더 많이 골린다.

```yaml
evidence:
  - {url: "https://code.claude.com/docs/en/agent-sdk/approvals", supports: both, claim: "공식 Question format: 질문마다 question · header(12자 이하) · options(2-4개, 각각 label · description, TS 는 선택적 preview) · multiSelect 를 둔다. 한 호출에 질문 1-4개다. 추천 · 기본값 · 미리 선택을 위한 필드는 스키마에 없다. 페이지 전체에 Recommended 라는 말이 없다. 사용자 UI 에는 'Other' 자유 입력이 덧붙는다. AskUserQuestion 은 Agent 도구가 띄운 subagent 에서 쓸 수 없다.", decides: [OQ2, OQ3], source_kind: primary, checked_at: "2026-10-27", version: {used: "2.1.303 (레포 dependencies.md 에 적힌 잰 판 — 지금 설치된 판은 모름)", latest: "2.1.311 (anthropics/claude-code CHANGELOG 맨 위)"}, certainty: confirmed}
  - {url: "https://code.claude.com/docs/en/agent-sdk/approvals#option-previews-typescript", supports: both, claim: "preview 는 SDK 설정 toolConfig.askUserQuestion.previewFormat(markdown|html)을 켤 때만 생기는 표시용 필드다. 추천 표시와는 관계없다.", decides: [OQ3], source_kind: primary, certainty: confirmed}
  - {url: "https://code.claude.com/docs/en/tools-reference", supports: both, claim: "공식 「AskUserQuestion tool behavior」 절은 객관식 질문 · Other 칸 · 메모 칸 · 응답 시간 초과(askUserQuestionTimeout)만 설명한다. 추천 표기 관례는 공식 사용자 문서에 없다. 시간이 초과되면 사용자가 이미 고른 선택지를 제출한다고 적는다. 미리 선택된 기본값은 언급하지 않는다.", decides: [OQ2, OQ3], source_kind: primary, certainty: confirmed}
  - {url: "https://raw.githubusercontent.com/Piebald-AI/claude-code-system-prompts/main/system-prompts/tool-description-askuserquestion-without-plan-mode-note.md", supports: both, claim: "도구 설명문 추출본(ccVersion 2.1.295)의 원문: \"If you recommend a specific option, make that the first option in the list and add \"(Recommended)\" at the end of the label\". 추천은 필드가 아니라 첫 자리 배치와 라벨 접미사로 표시한다. 같은 파일은 multiSelect 일 때의 추천 표시도, 추천이 없을 때의 처리도 말하지 않는다. 사용자는 언제나 Other 를 고를 수 있다.", decides: [OQ2, OQ3], source_kind: secondary, certainty: uncertain}
  - {url: "https://raw.githubusercontent.com/Piebald-AI/claude-code-system-prompts/main/system-prompts/tool-description-askuserquestion-lean-rewrite.md", supports: both, claim: "다른 설명문 변형(ccVersion 2.1.301)은 더 강하게 쓴다: \"If you are suggesting a specific option, always make that option the first, and add \"(Recommended)\" at the end of the label.\" 변형마다 문장의 세기가 다르다. 어느 변형이 언제 쓰이는지는 확인하지 못했다.", decides: [OQ2], source_kind: secondary, certainty: uncertain}
  - {url: "https://raw.githubusercontent.com/Piebald-AI/claude-code-system-prompts/main/system-prompts/tool-description-askuserquestion-preview-field.md", supports: both, claim: "preview 설명문(ccVersion 2.1.69): \"previews are only supported for single-select questions (not multiSelect)\". 추천 표시 수단이 아니다.", decides: [OQ3], source_kind: secondary, certainty: uncertain}
  - {url: "https://raw.githubusercontent.com/Piebald-AI/claude-code-system-prompts/main/system-prompts/tool-description-askuserquestion-decision-guidance.md", supports: both, claim: "결정 지침 설명문(ccVersion 2.1.173): 이 도구는 사용자 답이 다음 행동을 바꾸는 결정에만 쓴다. 관례적 기본값이 있는 선택이나 코드에서 확인할 수 있는 사실은 묻지 않는다. 그런 경우는 뻔한 쪽을 골라 응답에 밝히고 진행하라고 한다. 추천이 없는 질문을 어떻게 표시할지는 말하지 않는다.", decides: [OQ3], source_kind: secondary, certainty: uncertain}
  - {url: "https://raw.githubusercontent.com/Piebald-AI/claude-code-system-prompts/main/system-prompts/tool-description-askuserquestion-extended-host-guidance.md", supports: both, claim: "확장 호스트용 변형(ccVersion 2.1.260)은 선택지가 서로 배타적이지 않으면 multiSelect: true 를 기본으로 하라고 한다. multiSelect 에서 추천을 어떻게 표시할지 정한 1차 · 2차 자료를 찾지 못했다.", decides: [OQ2, OQ3], source_kind: secondary, certainty: uncertain}
  - {url: "https://code.claude.com/docs/en/hooks", supports: both, claim: "공식: PreToolUse 는 EndConversation 을 뺀 모든 도구 이름에 걸리고, 목록에 AskUserQuestion 이 명시돼 있다. 입력으로 tool_name · tool_input · tool_use_id 를 받는다. AskUserQuestion 의 tool_input 은 questions(질문 · header · options · multiSelect)와 선택적 answers 다. permissionDecision 은 allow|deny|ask|defer 다. deny 는 호출을 막고 permissionDecisionReason 을 Claude 에게 보인다(exit 2 도 같다). updatedInput 은 입력 객체 전체를 바꾼다. 여러 훅이 다르게 답하면 deny > defer > ask > allow 순으로 이긴다.", decides: [OQ4], source_kind: primary, version: {used: "2.1.303", latest: "2.1.311"}, certainty: confirmed}
  - {url: "https://code.claude.com/docs/en/hooks#tools-that-require-user-interaction", supports: both, claim: "공식: AskUserQuestion 에서는 \"allow\" 만으로는 부족하다. allow 와 함께 questions · answers 를 담은 updatedInput 을 내면 사용자에게 묻지 않고 프로그램이 답한다. 질문 · 라벨을 고쳐 사용자에게 그대로 보이게 하는 길은 정하지 않았다. AskUserQuestion 대화창이 고친 질문을 보이는지는 확인하지 못했다.", decides: [OQ4], source_kind: primary, certainty: uncertain}
  - {url: "https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md", supports: both, claim: "최신 판은 2.1.311 이다. 2.1.300 의 Changed: PreToolUse · PermissionRequest 훅의 updatedInput 을 이제 Claude 자신의 입력처럼 검증한다(추론: 스키마 검증을 받는다). 'Recommended' 를 다룬 항목은 없었다(앞 100k 자).", decides: [OQ4], source_kind: primary, certainty: uncertain}
  - {url: "https://learn.microsoft.com/en-us/windows/win32/uxguide/ctrl-radio-buttons", supports: both, claim: "Microsoft Win32 UX 지침: \"If an option is strongly recommended, add \\\"(recommended)\\\" to the label. Be sure to add to the control label, not the supplemental notes.\" 기본값은 첫 선택지로. 기본값을 두지 말아야 할 때: 안전 · 보안 · 법 때문에 명시적 선택이 필요할 때, 아직 정해지지 않은 상태를 보여야 할 때, 치우침 없는 데이터를 모을 때. 맞는 선택지가 없으면 None · Does not apply 를 더한다.", decides: [OQ2, OQ3], source_kind: primary, certainty: confirmed}
  - {url: "https://learn.microsoft.com/en-us/windows/win32/uxguide/ctrl-command-links", supports: both, claim: "Microsoft 명령 링크 지침: \"If a response is strongly recommended, add \\\"(recommended)\\\" to the label. Be sure to add to the label, not the supplemental explanation.\" 파괴적 동작은 기본값으로 두지 않는다. 추천이 없음을 밝히는 규칙은 없다.", decides: [OQ2, OQ3], source_kind: primary, certainty: confirmed}
  - {url: "https://developer.apple.com/design/human-interface-guidelines/alerts", supports: both, claim: "Apple HIG Alerts: \"If you want to encourage people to read an alert and not just automatically press Return to dismiss it, avoid making any button the default button.\" 추천이 없으면 기본을 비워 둔다. 비웠다는 사실을 글로 밝히라는 규칙은 없다. 라벨 접미사 관례도 없다.", decides: [OQ3], source_kind: primary, certainty: confirmed}
  - {url: "https://www.nngroup.com/articles/radio-buttons-default-selection/", supports: both, claim: "NN/g(2014): 라디오 버튼은 대개 하나를 기본 선택해 둔다. 넘겨짚는 기본값은 피하라. 'recommended' 같은 말이 확신을 준다. 확신 있는 기본값을 줄 수 없으면 다른 컨트롤을 생각하라.", decides: [OQ2, OQ3], source_kind: primary, certainty: confirmed}
  - {url: "https://design-system.service.gov.uk/components/radios/", supports: both, claim: "GOV.UK: \"Do not pre-select radio options\". 미리 선택하면 질문을 놓친 줄 모르거나 틀린 답을 낼 공산이 커진다. 추천 표기 규칙은 없다.", decides: [OQ3], source_kind: primary, certainty: confirmed}
  - {url: "https://www.psychologicalscience.org/journals/psychological-science/j.1467-9280.2006.01721.x/", supports: both, claim: "McKenzie 외(2006): 사람들은 기본값을 정한 쪽이 권하는 방향으로 읽었다. 추천은 명시하지 않아도 기본 · 첫 자리 같은 구조로 전달된다.", decides: [OQ2, OQ3], source_kind: primary, certainty: uncertain}
  - {url: "https://ideas.repec.org/a/cup/bpubpo/v3y2019i02p159-186_00.html", supports: both, claim: "Jachimowicz 외(2019) 메타분석: 기본값 효과 d≈0.68. 승인(endorsement) 경로로 작동할 때 더 크다.", decides: [OQ2], source_kind: primary, certainty: uncertain}
  - {url: "https://ideas.repec.org/a/eee/joepsy/v65y2018icp41-59.html", supports: both, claim: "Bruns 외(2018): 기본값의 영향과 목적을 알려 줘도 기본값 효과는 유의하게 줄지 않았다.", decides: [OQ2], source_kind: primary, certainty: uncertain}
  - {url: "https://behavioralpolicy.org/wp-content/uploads/2017/05/BSP_vol1is1_Loewenstein.pdf", supports: both, claim: "Loewenstein 외(2015): 기본값이 있다고 알려도 효과가 남았다.", decides: [OQ2], source_kind: primary, certainty: uncertain}
  - {url: "https://www.eecs.harvard.edu/~kgajos/papers/2021/bucinca2021trust.shtml", supports: both, claim: "Buçinca 외(2021): AI 추천에 지나치게 기대며 설명으로 줄지 않는다. 인지 강제 장치는 의존을 줄였지만 만족도를 낮췄다.", decides: [OQ2, OQ3], source_kind: primary, certainty: uncertain}
  - {url: "https://boisestate.pressbooks.pub/surveydesign/chapter/4-3/", supports: both, claim: "(2차) Krosnick satisficing: 시각 목록에서 첫 선택지 primacy 효과.", decides: [OQ2], source_kind: secondary, certainty: uncertain}
  - {url: "https://research-portal.uu.nl/en/publications/nudging-online-food-choices-disentangling-salience-and-pre-select/", supports: both, claim: "(2차) 미리 선택이 눈에 띔보다 효과가 크다. (Recommended) 라벨을 직접 시험한 것은 아니다.", decides: [OQ2], source_kind: secondary, certainty: uncertain}
repo_claims:
  - {id: RC1 (RC54), path: "plugins/spec-distill/dependencies.md", anchor: "| claude-code | 2.1.303 | 2026-10-22 | 기록 | 잰 판을 기록만 한다 |", line: 19, claim: "레포가 적어 둔 Claude Code 판은 2.1.303. 지금 설치된 판은 모름.", decides: [OQ4]}
  - {id: RC2 (RC55), path: "plugins/spec-distill/references/proceed-gate.md", anchor: "선택지는 그 skill 의 기본 다음 단계 `(권장)` 과 모델의 제안 둘이다", line: 56, claim: "게이트 정본은 이미 라벨에 (권장)을 다는 꼴. 도구 관례 (Recommended) 를 한국어로 옮긴 꼴. (권장) 이 나오는 plugins/ 파일 44개.", decides: [OQ2, OQ3]}
  - {id: RC3 (RC56), path: "plugins/project-init/hooks/hooks.json", anchor: "\"matcher\": \"Bash|EnterWorktree\"", line: 6, claim: "레포의 hooks.json 은 이 파일 하나. AskUserQuestion 에 걸린 PreToolUse 훅은 없다.", decides: [OQ4]}
unanswered: "multiSelect 추천 표시 관례 없음 · 추천 없음을 글로 밝히는 관례 없음(기본 비움 · None 선택지만) · (Recommended) 문장은 2차 추출본에서만 · updatedInput 으로 고친 질문이 대화창에 보이는지 미확인 · 지금 설치된 판 모름"
```
(모든 항목 touches: [] · checked_at 2026-10-27 — 원문 그대로)

V1(이 조사의 확인 줄):
- 확인 RC54 — 확인 — plugins/spec-distill/dependencies.md#claude-code | 2.1.303 — 주장과 일치
- 확인 RC55 — 확인 — plugins/spec-distill/references/proceed-gate.md#56 — 주장과 일치. 더해 «제안 이유는 게이트 앞 글에 쓰고» — 추천 이유가 질문 위 글에 있는 꼴 하나 더
- 확인 RC56 — 확인 — plugins/project-init/hooks/hooks.json#matcher — git ls-files 로 hooks.json 셋(나머지 둘은 shared/tests/fixtures) — 주장과 일치
- 웹 Microsoft radio buttons — 1차로 본체가 다시 확인: «If an option is strongly recommended, add "(recommended)" to the label. Be sure to add to the control label, not the supplemental notes.» 원문 일치
- 웹 code.claude.com/docs/en/hooks AskUserQuestion 세부 — 본체 재확인에서 앞 100k 자 안에 AskUserQuestion 언급을 찾지 못함 — 확인 못 함(subagent 는 confirmed 로 냄)

## R6

### 지금 이해
바깥 근거(조사 4)를 받았다. Microsoft UX 지침은 1차로 다시 확인했다 — 「(recommended)」를 보충 설명이 아니라 라벨에 단다. Claude Code 도구는 추천 전용 필드가 없고, 도구 설명문 관례는 첫 자리 + 「(Recommended)」다(2차 추출본). 다만 여러 개를 고르는 질문의 추천 표시나 「추천 없음」을 밝히는 관례는 어디에도 없다 — devbrew 가 정해야 한다. 연구 쪽은 추천 표시가 알려도 선택을 끌어당기고 AI 추천에 지나치게 기대게 만든다고 본다. 이 방향 의심(landscape 모순)으로 steelman-builder 를 띄웠다(진행 중). 같은 갈래로 게이트 정본(proceed-gate.md:56)도 «제안 이유는 게이트 앞 글에 쓰고»라 추천 이유가 질문 위 글에 있는 꼴이 하나 더 있다(RC55).
조사 호출 5/60 · 이 라운드 본체 직접 2

### 다음 결정
OQ9: 바깥 근거 처분(landscape) · 추천: 라벨 표시 근거로 취하고 과의존 연구는 위험으로 기록 · 트레이드오프: 취함 → 지금 방향 강화 / 과의존을 무겁게 → 추천 표시에 완화 장치를 더 붙임
OQ5: 적용 범위 · 추천: devbrew 가 띄우는 모든 질문(skill 리터럴 · 문장 지시 · 지휘자 · 본체가 즉석에서 만든 질문) — 외부 skill 질문은 그 skill 규약 · 트레이드오프: devbrew 만 → 고칠 자리가 레포 안에 닫힘 / 외부까지 → 실행 중 훅이 아니면 강제 못 함

### 질문
(경로 b) OQ9 · OQ5 한 호출에 묶음. OQ4(집행 층)는 OQ5 에 기대므로 다음 라운드.

### 답
→ S10 (OQ9) · S11 (OQ5)

## R7

### 지금 이해
S10 으로 landscape 닫힘. S11 로 범위는 devbrew 가 띄우는 질문 전부. 둘 다 추천을 이유 없이 고른 답이라 범위 쪽 실패 조건을 되묻는다 — 외부 skill 질문이 범위 밖이면 devbrew 흐름 안 brainstorming 질문에 추천이 없어도 그대로다. 그게 괜찮은지가 집행 층(OQ4)에서 실행 중 훅이 필요한지를 가른다.
조사 호출 5/60 · 이 라운드 본체 직접 0

### 다음 결정
OQ5(이어감 — 되묻기: 실패 조건) · 추천: 괜찮다 — 외부 skill 질문은 그 skill 몫 · 트레이드오프: 괜찮다 → 레포 안 장치로 충분 / 거슬린다 → 범위를 넓히고 실행 중 훅이 필요

### 질문
(경로 b — 되묻기)

### 답
→ S12

## R8

### 지금 이해
S12 로 범위 닫힘 — 외부 skill 질문은 그 skill 몫이라 실행 중 훅이 꼭 필요하지는 않다. 남은 큰 결정은 집행 층(OQ4)이다. CLAUDE.md 는 «버그가 리뷰를 탈출하면 기본 해결책은 잡았어야 할 reviewer persona 파일을 편집하는 것»이라고 정한다. 정적 락은 SKILL · reference 의 질문 템플릿만 보고 실행 중 채워지는 라벨은 못 본다(조사 3). 실행 중 훅은 PreToolUse 가 AskUserQuestion 입력을 받아 deny 할 수 있지만(조사 4, 세부는 본체 확인 못 함) 세션의 모든 질문(범위 밖 외부 skill 포함)에 걸리고 결정론은 보안 · 정확성에만이라는 원칙(P8)과 부딪친다.
조사 호출 5/60 · 이 라운드 본체 직접 0

### 다음 결정
OQ4: 집행 층 · 추천: 정본 + 전수 락, 그리고 리뷰어 persona(둘 다 권장) · 트레이드오프: 락 → 템플릿 수준 드리프트를 잡고 실행 라벨은 못 잼 / persona → 레포 규칙대로 리뷰가 다음에 잡음 / 훅 → 실행 중까지 잡지만 범위 누수 · P8 충돌

### 질문
(경로 b) multiSelect.

### 답
→ S13

### 조사 5 — steelman-builder · R6 · 묶음 3 (ST1)

(subagent 임시 id → 인터뷰 번호: RC1→RC57 · RC2→RC58 · RC3→RC59 · RC4→RC60 · RC5→RC61 · RC6→RC62 · RC7→RC63 · RC8→RC64)

dispatch 입력: goal = S1 · 전제 P1(S3·S8) P2(S4) P3(S5·S7) P4(S6) P5(S2) P6(S9) · 제약 S1–S9 · trigger = landscape 모순(기본값·과의존 연구 대 라벨 의무, 레포의 기존 기준점 방지 장치)

```yaml
case_for_alternative:
  statement: "모든 AskUserQuestion 이 추천 여부를 라벨에서 밝히는 것은 같다. 다만 표지로 「(권장)」/「(Recommended)」 꼬리만 받지 않고, 누가 추천했는지 붙인 꼬리(「(builder 추천)」 · 「(지휘자 추천)」 처럼 「(<누가> 추천)」 꼴)도 정식 표지로 받는다. 추천하는 쪽이 둘 이상이고 서로 다른 선택지를 밀 때는 「(권장)」 하나로 합치지 않는다. 선택지 순서는 추천과 상관없이 정해진 대로 둔다. steelman 질문의 지금 꼴을 예외가 아니라 정식 형태로 삼는 셈이다."
  strongest: "goal 은 '추천이 뭐인지 명확하게' 다. devbrew 질문에는 추천하는 쪽이 여럿 있다. skill 작성자가 템플릿에 박아 둔 고정 (권장)(예: 「그만둠 (권장)」), 모델이 그때그때 하는 판단, builder 와 orchestrator, 지휘자다. 꼬리가 「(권장)」 하나면 '무엇을' 권하는지는 보여도 '누가 · 어떤 근거로' 권하는지는 지워진다. 기본값은 '선택을 설계한 쪽이 이걸 권한다'는 보증 신호를 통해 가장 세게 작동하고(Jachimowicz 2019, d=0.68), '이것은 기본값이다'라고 알려도 그 힘이 줄지 않는다(Bruns 2018 · Loewenstein 2015). 그래서 라벨 표지를 의무로 만들고 나면, 사용자가 그 추천을 따져 볼 지렛대로 남는 것은 출처뿐이다. 이유 한 줄을 붙여도 과의존은 줄지 않는다는 결과도 같은 쪽을 가리킨다(Buçinca 2021). 더 직접적인 문제도 있다. 추천하는 쪽들이 서로 다를 때(builder ≠ orchestrator, skill 원문의 권장 ≠ 지휘자 의견) 두 선택지에 모두 「(권장)」 을 달면 P4 의 '둘 다 좋다'와 '두 쪽이 의견이 갈린다'가 같은 글자가 된다. 그러면 오히려 덜 명확해진다. 지휘자가 옮기는 질문에서도 skill 의 (권장) 과 지휘자의 (권장) 이 같은 글자가 되어, relay-checker 가 그대로 옮겼는지 대조할 수 없게 된다."
case_for_current:
  strongest: "실제로 일어난 실패는 출처를 몰라서 생긴 것이 아니다. 라벨에 표시가 없어서 위에 쓴 권고와 선택지를 잇지 못한 것이다(S3 · S8: 터미널 글은 '로드맵' 을 권했는데 '스펙' 을 골랐다). 「(권장)」/「(Recommended)」 는 사용자가 이미 읽는 단 하나의 표지이고, Claude Code 도구에 이미 있는 관례다. Microsoft 지침도 '(recommended) 를 보충 설명이 아니라 라벨에 붙이라'고 정확히 같은 처방을 낸다. 표지가 한 글자로 정해져 있어야 S5 의 '표시가 있는가' 하나로 기계가 잴 수 있다. 출처 꼬리를 정식 표지로 열면 표지 문법이 늘어나고, 그만큼 검사가 놓치는 꼴이 생긴다. 사용자를 대신 판단하게 될 위험은 이미 P3 · S7(근거 부족이면 추천 없음)과 P6(자기 산출물 처분이면 추천 없음)이 막는다. 표시를 공개해도 기본값 효과가 줄지 않는다는 연구는, 숨긴 nudge 보다 드러낸 nudge 가 낫다는 근거로 읽힌다. 그러니 같은 기준(명확성)에서는 단일 표지가 이긴다."
premise_refutation:
  hits: [P5]
  why: "P5 는 '규칙 문장은 이미 있고(plain-language.md:6) 문제는 안 지켜지는 것이다' 라고 말한다. 그런데 레포를 보면, S3 이 지목한 바로 그 질문은 규칙을 어긴 것이 아니라 지역 규칙대로 돌았다. (1) plugins/spec-distill/skills/pm-interview/references/finishing.md 의 '### 분해 판단 — Step A 직전' 은 일부러 이렇게 설계됐다. 권고는 선택지 밖 「이어서 권고 한 줄 — 「하나로 충분해 보인다 — <이유>」 또는 「나누는 게 좋아 보인다 — <이유>」」 로 내고, 선택지 라벨은 「spec 하나로」 · 「나눈다 — 분해안 보기」 로 (권장) 없이 두며, 「판정은 사용자가 한다」 고 적혀 있다. 즉 S3 의 '추천은 로드맵이라 나왔는데 스펙을 골랐다' 는 이 설계가 낳은 결과다. (2) shared/style/plain-language.md:3 「아래 절차가 출력 형식·원문 보존·분량을 따로 정한 자리에서는 그 절차를 따른다」 · 「부른 skill 이 메시지 모양을 정한 대화(예: brainstorming)에서는 그 skill 을 따르고, 이 블록은 낱말에만 적용한다」 는 line 6 의 규칙을 지역 절차 아래에 둔다. (3) 정반대로 정한 지역 규칙이 셋 있다. steelman.md:92 「`(Recommended)`·`(권장)` 접미사는 붙이지 않는다」, conducting.md:102 「지휘 세션의 의견은 선택지 밖 「지휘자 의견:」 한 줄로만」, relay-checker.md:32 「문장 권장이 라벨 꼬리로 옮겨짐」(어긋남) · :35. 그러니 원인의 상당 부분은 '안 지킴' 이 아니라 '서로 맞서는 지역 규칙이 이긴 것' 이다. P5 의 진단대로 지키는지 재는 장치만 더하면, 그 장치는 일부러 그렇게 만든 자리를 위반으로 잡거나 면제 목록으로 눈을 감는다."
premise_list_challenge: "빠진 전제가 넷 있다. ① 서로 맞서는 지역 규칙을 고쳐 쓰는 일. plain-language.md:3 의 '지역 절차가 이긴다' 는 조항이 이 규칙에도 적용되는지, finishing.md 분해 판단, steelman.md:92, conducting.md:102, relay-checker.md:32·35, 그리고 그 규칙을 잠근 테스트 test_epic_conductor_skill.sh:73-75. 이것들을 먼저 뒤집지 않으면 S2 의 '재는 장치' 는 의미가 없다. S4 가 지휘자 규칙만 이름으로 집었고 나머지는 전제 목록에 없다. ② P4 의 '여럿이면 여럿 모두' 는 '여러 선택지가 다 좋다' 와 '추천하는 쪽들이 서로 다른 것을 민다' 를 구별하지 못한다. steelman 질문은 두 번째 경우라서 출처를 붙인 표지를 쓴다. 이 질문에 단일 「(권장)」 을 의무로 지우면 오히려 덜 명확해진다. 지휘자가 옮기는 질문도 skill 의 (권장) 과 지휘자의 (권장) 을 가를 표지가 있어야 relay-checker 대조가 산다. ③ 라벨은 '돌려줄 값' 이다(conducting.md:102 「라벨(돌려줄 값)」, SDK answers 는 라벨 문자열을 키로 쓴다). 꼬리를 붙이거나 떼면 그 라벨을 글자 그대로 비교하는 소비자와 잠금 테스트(test_end_gates.sh · test_critiquing_artifacts_skill.sh 등)가 함께 움직여야 한다. ④ 모델이 실행 중에 지어내는 라벨이 있다(quality-pipeline 낮춘 지적 게이트의 「<파일 이름>:<줄> (L<k>)」, finishing.md 의 「<모델의 제안>」). 이런 라벨은 정적 문서 검사로 볼 수 없고 실행 중 검사만 본다. OQ4 가 이 차이를 전제로 갖고 있어야 한다. 같은 입력을 다시 받았다는 신호는 없다."
recommendation: refined
refined_takes: "라벨 의무 표시(S4 · S8), 정식 표지 「(권장)」 · 「(Recommended)」(S9), 추천이 없으면 질문 본문에 「추천 없음 — <이유>」(S5 · S7), 권장이 여럿이면 여럿 모두(S6), 자기 산출물을 처분하는 질문은 추천 없음(P6 · Law 2), 지휘자 규칙과 relay-checker 기준을 함께 바꾸는 것(S4)."
refined_drops: "P5 의 '안 지켜지는 것' 이라는 진단과, 그 진단에서 나온 '재는 장치를 먼저 더한다' 는 순서를 버린다. 맞서는 지역 규칙(finishing.md 분해 판단의 문장 권고 · plain-language.md:3 의 지역 우선 조항을 이 규칙에 적용하는 것 · relay-checker.md:32 의 '문장 권장 → 라벨 꼬리 = 어긋남' · 그 잠금 테스트)을 먼저 고친다. 또 '표지는 「(권장)」 문자열뿐' 이라는 한정을 버린다. 추천하는 쪽이 둘 이상인 질문(steelman 의 builder/orchestrator, 지휘자가 옮기는 질문의 skill 대 지휘자)은 「(<누가> 추천)」 꼬리를 추천 표지로 인정하고, 검사도 이것을 '표시 있음' 으로 센다. steelman 의 고정 순서는 그대로 둔다."
evidence:
  - {url: "https://learn.microsoft.com/en-us/windows/win32/uxguide/ctrl-command-links", supports: current, claim: "Labels 절: 'If a response is strongly recommended, add \"(recommended)\" to the label. Be sure to add to the label, not the supplemental explanation.' ... Windows 7 시절 지침", touches: [P1, P2], decides: [], certainty: high}
  - {url: "https://ideas.repec.org/a/cup/bpubpo/v3y2019i02p159-186_00.html", supports: alternative, claim: "기본값 메타분석 d=0.68(95% CI 0.53–0.83). 보증(endorsement)으로 읽힐 때 더 세다. 라벨의 (권장) 은 이 보증 신호.", touches: [], decides: [], certainty: medium}
  - {url: "https://ideas.repec.org/a/eee/joepsy/v65y2018icp41-59.html", supports: both, claim: "기본값의 영향 · 목적을 공개해도 효과가 유의하게 약해지지 않았다(Bruns 외 2018).", touches: [], decides: [], certainty: medium}
  - {url: "https://www.cmu.edu/dietrich/sds/docs/loewenstein/WarningAboutNudged.pdf", supports: both, claim: "기본값을 미리/나중에 알려도 영향이 남았다(Loewenstein 외 2015).", touches: [], decides: [], certainty: medium}
  - {url: "https://www.eecs.harvard.edu/~kgajos/papers/2021/bucinca2021trust.shtml", supports: alternative, claim: "AI 추천에 설명을 붙여도 과의존이 줄지 않았다. 인지 강제 장치가 줄였다. '라벨 (권장) + 이유 한 줄' 만으로는 앵커링을 상쇄하지 못한다.", touches: [], decides: [], certainty: high}
  - {url: "https://code.claude.com/docs/en/agent-sdk/user-input", supports: both, claim: "options[] 는 label · description 만. 추천은 라벨이나 본문 글자로만. 'For logic that must apply to every tool call, use a PreToolUse hook...' 훅은 어느 skill 이 띄웠는지 구별 못 함.", touches: [], decides: [OQ4, OQ5], certainty: high}
  - {url: "https://juejin.cn/post/7667440437863874560", supports: current, claim: "도구 설명은 추천을 맨 앞 + '(Recommended)'. 제3자 재구성.", touches: [P2], decides: [], certainty: low}
repo_claims:
  - {id: RC1 (RC57), path: "shared/style/plain-language.md", anchor: "추천은 「(권장)」으로 표시한다.", line: 6, claim: "추천 없음을 밝히라는 요구는 없다. line 3 이 이 규칙을 지역 절차와 외부 skill 아래에 둔다.", touches: [P3, P5], decides: [OQ5]}
  - {id: RC2 (RC58), path: "plugins/spec-distill/skills/pm-interview/references/finishing.md", anchor: "### 분해 판단 — Step A 직전", line: 33, claim: "권고는 선택지 밖 문장으로만, 라벨엔 (권장) 없음. 「판정은 사용자가 한다」 는 설계 의도가 문서에 적혀 있다. 규칙 위반이 아니라 지역 설계다.", touches: [P1, P5], decides: []}
  - {id: RC3 (RC59), path: "plugins/spec-distill/skills/pm-interview/references/steelman.md", anchor: "도구·라운드 규약의 `(Recommended)`·`(권장)` 접미사는 붙이지 않는다.", line: 92, claim: "(권장) 금지 · 고정 순서 · 출처 라벨. 단일 (권장) 의무와 충돌, 추천하는 쪽이 갈리는 경우를 P4 로 표현 못 함.", touches: [P2, P4, P5], decides: []}
  - {id: RC4 (RC60), path: "plugins/spec-distill/references/conducting.md", anchor: "지휘 세션의 의견은 선택지 밖 「지휘자 의견:」 한 줄로만 쓰고", line: 102, claim: "지휘자의 추천은 선택지 밖에만. 라벨은 「돌려줄 값」. 지휘자 권장을 라벨로 옮기면 skill 의 권장과 구별할 표지가 필요.", touches: [P1, P5], decides: []}
  - {id: RC5 (RC61), path: "plugins/spec-distill/agents/relay-checker.md", anchor: "「문장 권장이 라벨 꼬리로 옮겨짐」", line: 32, claim: "원안과 반대 방향으로 이빨이 박혀 있다. 리뷰어 층은 이미 있고 뒤집기만 하면 된다.", touches: [P5], decides: [OQ4]}
  - {id: RC6 (RC62), path: "plugins/spec-distill/tests/test_epic_conductor_skill.sh", anchor: "AC9: 지휘자가 만든 질문의 라벨 (권장) 은 어긋남", line: 73, claim: "정적 잠금이 지휘자 질문의 라벨 (권장) 금지를 고정. 같은 PR 에서 뒤집어야 한다.", touches: [P5], decides: [OQ4]}
  - {id: RC7 (RC63), path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md", anchor: "낮춘 지적 게이트 (표면화 뒤 · 라우팅 앞)", line: 714, claim: "라벨을 실행 중에 만든다. 추천도 추천 없음도 없다. 정적 잠금은 실제 라벨을 못 본다.", touches: [P5], decides: [OQ4]}
  - {id: RC8 (RC64), path: "plugins/*/hooks/", anchor: "Grep 'AskUserQuestion' — 0건", claim: "어떤 훅도 AskUserQuestion 을 보지 않는다. 실행 중 검사 층은 새 표면이고 P8 · kill switch · README 정당화 의무를 진다.", touches: [], decides: [OQ4, OQ5]}
```

## R9

### 지금 이해
S13 으로 집행 층 닫힘 — 정본 + 전수 검사 + 리뷰어 수정. steelman(ST1) 이 돌아왔다. 게이트-전 확인:
- 확인 RC57 — 확인 — shared/style/plain-language.md#3·6행 — 주장과 일치(3행이 지역 절차 우선)
- 확인 RC58 — 반증 — plugins/spec-distill/skills/pm-interview/references/finishing.md#분해 판단 — 그 자리의 「판정은 사용자가 한다」(28행)는 숫자 신호에 컷오프를 두지 않는다는 뜻이고, 라벨에 추천을 일부러 빼는 의도 문장은 없다. 주장은 «무권장이 설계 의도로 적혀 있다»였다(선택지 밖 문장 권고 · 라벨 무권장이라는 사실은 일치)
- 확인 RC59 — 확인 — steelman.md#92 — 주장과 일치
- 확인 RC60 — 확인 — plugins/spec-distill/references/conducting.md#102 — 라벨(돌려줄 값) · skill 자신의 「(권장)」 글자 그대로 — 주장과 일치
- 확인 RC61 — 확인 — relay-checker.md#32 — 주장과 일치
- 확인 RC62 — 확인 — plugins/spec-distill/tests/test_epic_conductor_skill.sh#AC9 — 73-76행 잠금 — 주장과 일치
- 확인 RC63 — 확인 — quality-pipeline/SKILL.md#낮춘 지적 — 주장과 일치
- 확인 RC64 — 확인 — plugins/*/hooks — hooks.json 은 project-init 하나, AskUserQuestion 매처 없음 — 주장과 일치
부착 대조: MS command-links [부착 P1 · P2] 확인(원안 지지 — radio-buttons 원문 1차 확인과 같은 문장) · juejin [부착 P2] 확인(2차). P5 충돌 주장 — plain-language.md:3 지역 우선 조항 · steelman.md:92 · conducting.md:102 · relay-checker.md:32·35 의 맞서는 지역 규칙은 확인, finishing.md 의 «의도» 부분만 반증 → 충돌 확인 1건(P5).
조사 호출 6/60 · 이 라운드 본체 직접 1

### 다음 결정
OQ10: steelman 판정(ST1) — 유지 / 보완 / 전환 / 보류 · (steelman 절차 질문 — 라운드 규약의 추천 표기 대신 출처 라벨) builder: refined / orchestrator: 보완

### 질문
(steelman 절차 질문)

### 답
→ S14 (ST1 — 사용자 선택 보완 · builder refined 와 같음, 「버림」은 refined_drops)

## R10

### 지금 이해
S14 로 skepticism 닫힘(보완). 남은 floor 는 열린 질문 목록 확인뿐이다. 설계 단계로 넘길 열린 질문 넷을 추렸다(OQ11–OQ14). 지역 규칙과 어긋나는 자리 목록 · 표기 · 범위는 이미 정해졌다.
조사 호출 6/60 · 이 라운드 본체 직접 0

### 다음 결정
open_questions 확인 · 추천: 이 넷으로 넘김 · 트레이드오프: 넷으로 → 설계 단계가 정함 / 지금 하나 더 정함 → 인터뷰가 한 라운드 늘어남

### 질문
(경로 b)

### 답
→ S15

## audit §2 대기 줄

- 포화 판정 1: 아직 — 빈 곳 5개
- 포화 판정 2: 아직 — 빈 곳 4개
- 사용자 종료(@S24) — 마지막 판정 아직

## R11

### 지금 이해
[spec-distill] 포화 판정 1/5: 아직 — 빈 곳 5개, 다음: 라벨 문자열을 글자 그대로 비교하는 소비자와 락을 전부 훑는다 · 조사 호출 6/60
빈 곳 다섯을 한 묶음(묶음 4)으로 함께 띄운다 — 서로 기대지 않는다. 마지막 빈 곳(추천하는 쪽 둘 이상 자리 수)은 레포 계수라 coverage-mapper 대신 repo-researcher 로 보낸다(판정자 지정 장치와 다름 — 이유: 차원 제안이 아니라 자리 세기).

### 조사 8 — repo-researcher · R11 · 묶음 4

(빈 곳 3 — 리뷰어 persona 범위. subagent 임시 id → 인터뷰 번호: RC<n> → RC<n+64>, 곧 RC65–RC83)

```yaml
repo_claims:
  - {id: RC1 (RC65), path: "plugins/quality-gates/scripts/doc_paths.py", anchor: "MODEL_READ_NAMES = (\"CLAUDE.md\", \"AGENTS.md\", \"SKILL.md\") / MODEL_READ_SEGMENTS = (\"agents\", \"skills\", \"commands\", \"references\", ...)", line: 40, claim: "qg 의 리뷰 diff 는 문서 경로를 뺀 diff 다. 기본 패턴은 README* · CHANGELOG* 뿐이고(DEFAULT_DOC_PATHS), 모델이 읽는 파일(SKILL.md · skills/ · references/ · agents/ 아래)은 패턴에 걸려도 `kept` 로 남는다(select: `is_doc_file(path) and not is_model_read(path)` 일 때만 뺀다). 그래서 plugins/*/skills/*/SKILL.md 와 references/*.md 의 변경 hunk 는 qg 의 모든 리뷰어(보안 · 외부 · codex · 재비판)가 받는 FILTERED_DIFF 에 들어간다. 다만 받는 것은 hunk 이고, 파일 전문은 project_dir 에서 각자 Read 해야 한다.", decides: [OQ11]}
  - {id: RC2 (RC66), path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md", anchor: "### Step 3 — reviewers / 시작 구성 표", line: 382, claim: "PR 하나에 qg 가 띄우는 리뷰어 구성: pr-review-toolkit:code-reviewer(항상, 외부) · quality-gates:security-reviewer(항상) · codex 러너(항상 시도) · pr-test-analyzer · silent-failure-hunter · type-design-analyzer · comment-analyzer(조건부, 외부) · quality-gates:code-recritic(항상, Step 3.5). 모든 dispatch 가 같은 둘을 싣는다: CRITERIA(references/review-criteria.md 의 내용)와 INTENT. 외부 리뷰어 프롬프트는 `<intent>` · `<criteria>` · `<diff>${FILTERED_DIFF}` 로 짜인다. 표 위 문장이 근거를 적으면 리뷰어를 더할 수 있다고 허용한다. pr-review-toolkit:* persona 는 이 레포에 없어서 레포에서 고칠 수 없다.", decides: [OQ11]}
  - {id: RC3 (RC67), path: "plugins/quality-gates/references/review-criteria.md", anchor: "## 리뷰 기준 — 막는 지적(CRITICAL · IMPORTANT)은 아래 셋 중 하나일 때만이다", line: 1, claim: "모든 qg 리뷰어와 codex(build_codex_prompt.py 의 CRITERIA_PATH)가 공유하는 criteria 블록이다. 막는 조건은 셋뿐이다: 동작이 틀림 · 의도 출처 요구 어김 · 스스로 고친 통제가 뚫림. 사용자에게 보이는 글이나 질문 꼴(plain-language · 「(권장)」 표시)을 보는 항목은 없다. 따라서 추천 표시 위반은 의도 출처가 그 요구를 적었을 때만 막는 지적이 되고, 그 밖에는 SUGGESTION 이다. 리뷰어가 아니라 판정 기준을 공유하는 자리라서, 여기에 넣으면 qg 의 탐지 리뷰어 · codex · 재비판이 한꺼번에 받는다.", decides: [OQ11]}
  - {id: RC4 (RC68), path: "plugins/quality-gates/agents/security-reviewer.md", anchor: "**Skill / command body argument substitution** — in `plugins/*/skills/*/SKILL.md` and `plugins/*/commands/*.md`, ...", line: 54, claim: "입력은 project_dir · diff_scope · intent · criteria · iteration · filtered_diff 다. Hunt categories 에 SKILL.md 본문에 특화된 항목이 이미 하나 있다($0–$9 치환). 이 레포에 SKILL.md 전용 검사를 persona 의 Hunt 목록에 둔 선례다. 다만 역할은 보안 경로(입력→위험 sink)이고, 「NOT responsible for: code style, design ...」 라서 질문 꼴이나 사람에게 쓰는 글은 범위 밖이다.", decides: [OQ11]}
  - {id: RC5 (RC69), path: "plugins/quality-gates/agents/code-recritic.md", anchor: "프로필의 관문 A~E 를 항목마다 독립적으로 적용한다 / 놓친 결함이 있으면 `added` 에 새 finding 을 낸다", line: 59, claim: "입력 슬롯은 여섯이다: project_dir · scope · findings(익명) · diff · intent · profile. profile 은 recritic-code-profile.md 와 review-criteria.md 를 이어 붙인 것이다(quality-pipeline SKILL.md Step 3.5 의 `cat` 줄). 재비판자는 `added` 로 놓친 결함을 낼 수 있지만, 기준은 관문 A–E(코드 실재 · 변경 도입 · 다른 곳에서 막힘 · 신뢰 앵커 · 범위 초과 처방)뿐이다. 사람에게 보이는 글을 보는 관문은 없다. 관문 E 는 이 변경이 하지 않은 일을 처방하면 SUGGESTION 으로 낮추게 한다.", decides: [OQ11]}
  - {id: RC6 (RC70), path: "plugins/quality-gates/references/recritic-code-profile.md", anchor: "## 판정 관문 (항목마다 독립적으로 — 앞 판정이 뒤 판정을 누그러뜨리지 않는다)", line: 12, claim: "재비판 프로필에는 처분 어휘와 관문 A–E 와 근거 기준이 있다. 모두 코드 finding 용이다(「이 목록의 항목은 **코드 finding** 이다」). qg 쪽에서 새 판정 관문을 넣는다면 이 파일이 그 자리다.", decides: [OQ11]}
  - {id: RC7 (RC71), path: "plugins/quality-gates/scripts/build_codex_prompt.py", anchor: "PROMPT_TEMPLATE = \"\"\"You are a code reviewer. Review the diff for bugs, silent failures, security issues, and missing error handling.", line: 47, claim: "codex 리뷰어의 프롬프트는 diff · intent · review-criteria.md 를 받는다. 검사 대상은 버그 · 조용한 실패 · 보안 · 에러 처리이고, 사용자에게 보이는 글이나 질문 꼴 항목은 없다. criteria 블록을 고치면 이 프롬프트에도 들어간다(CRITERIA_PATH).", decides: [OQ11]}
  - {id: RC8 (RC72), path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md", anchor: "<!-- plain-language:begin --> ... 추천은 「(권장)」으로 표시한다.", line: 52, claim: "plain-language 블록은 그 skill 을 실행하는 모델(오케스트레이터)이 사용자에게 쓰는 글을 정하는 규칙이다. 리뷰어 체크리스트가 아니다(「지시문·subagent 프롬프트·state 파일에는 적용하지 않는다」). 정본은 shared/style/plain-language.md 이고, 잠금은 shared/tests/plain_language_block.py 다. 이 잠금은 블록의 위치(H1 바로 다음)와 바이트 동일성만 잰다. SKILL.md 안의 AskUserQuestion 리터럴이나 「…를 묻는다」 문장이 그 규칙(추천 표시 포함)을 지키는지는 재지 않는다.", decides: [OQ11, OQ12]}
  - {id: RC9 (RC73), path: "shared/docreview/agents/doc-critic.md", anchor: "## 입력 — `<document>` — 리뷰할 문서 전문(또는 번들). 이것이 대상이다. / `<profile>` — ... `layer_rubric`", line: 41, claim: "문서 리뷰 엔진의 탐지 리뷰어다. 입력은 document(전문) · profile · prior_finding_ids · related_changes 이고 PR diff 를 받지 않는다. 무엇을 검사할지는 전부 프로필의 layer_rubric 이 정한다. persona 본문에는 리뷰어 자신의 출력을 쉬운 말로 쓰라는 규칙만 있다. 대상 문서의 사용자 노출 글을 검사하는 항목은 없다. plugins/spec-distill/agents/doc-critic.md 는 이 정본의 사본이다(shared/tests/test_copy_of_contract.sh).", decides: [OQ11]}
  - {id: RC10 (RC74), path: "shared/docreview/agents/doc-recritic.md", anchor: "당신에게 오는 것은 문서 · 출처 라벨이 지워진 finding 목록(`f1`·`f2`…) · 이 자리의 프로필 · 그리고 선택적으로 변경 `<diff>`", line: 41, claim: "입력은 document · findings(익명) · profile · diff(선택) · related_changes(선택)다. confirm · reject · raise 와 added 로 판정한다. 기준은 프로필의 rubric 이고 persona 자체에 질문 꼴 항목은 없다.", decides: [OQ11]}
  - {id: RC11 (RC75), path: "plugins/spec-distill/references/docreview-profiles/design-doc.md", anchor: "layer_rubric: layer1: [goal_fit, problem_definition, scope, architecture, component_relations, data_flow, tradeoffs, feasibility, overdesign] / layer2: [placeholder, ambiguity, scope_creep, approaches_comparison, isolation, testing, handoff_incomplete, required_sections]", line: 14, claim: "spec-review(설계문서 리뷰)는 이 프로필로 고정이다. 대상은 설계문서 한 편이고 SKILL.md · references 변경 diff 가 아니다. 그래서 설계문서가 인용한 질문 문면만 볼 수 있다. rubric 17축 어디에도 사용자에게 보이는 글이나 질문 꼴 축은 없다. 이 자리에서 새 축을 넣는 곳은 frontmatter 의 layer_rubric(과 must_catch)과 본문의 축 정의 목록이다.", decides: [OQ11]}
  - {id: RC12 (RC76), path: "plugins/quality-gates/references/docreview-profiles/generic.md", anchor: "layer_rubric: layer1: [logic, assumption] / layer2: [completeness, evidence, ambiguity, actionability, structure]", line: 8, claim: "generic 문서 프로필(artifact 비평 쪽)은 문서 자기 정합만 본다. 질문 꼴이나 추천 표시 항목은 없다.", decides: [OQ11]}
  - {id: RC13 (RC77), path: "plugins/quality-gates/agents/artifact-critic.md", anchor: "## Critique rubric (the `category` value) — logic · assumption · completeness · evidence · ambiguity · actionability · structure", line: 35, claim: "/quality-gates:artifact-critique 의 비평자다. 입력은 project_dir · artifact_path(파일 하나 전문)이고 diff 는 받지 않는다. .md 를 non_code 로 분류하므로 사용자가 SKILL.md 경로를 직접 넘기면 비평 대상이 될 수 있다. 하지만 PR 경로에서 자동으로 불리지는 않는다. rubric 에 질문 꼴 항목은 없다.", decides: [OQ11]}
  - {id: RC14 (RC78), path: "plugins/plugin-audit/agents/plugin-auditor.md", anchor: "You are responsible for **finding evidence-backed gaps on the one axis you are assigned**, reading the in-scope files **end to end**", line: 33, claim: "plugin-auditor 는 PR diff 가 아니라 대상 플러그인 하나의 파일 전부를 끝까지 읽는다(SKILL.md 전문을 포함하므로 AskUserQuestion 리터럴과 문장 질문을 볼 수 있다). 축 질문은 persona 에 없고, audit-workflow.js 의 findPrompt 가 CONTRACT 와 축 질문을 붙여 넘긴다. 사용자가 /plugin-audit:plugin-audit 를 명시로 부를 때만 돈다.", decides: [OQ11]}
  - {id: RC15 (RC79), path: "plugins/plugin-audit/scripts/audit-workflow.js", anchor: "const AXES = [ ... { n: 5, name: 'UX·디테일', question: ['**명령 흐름 · 상호작용 수 · 생성물/템플릿 *내용* 품질**', ...", line: 424, claim: "여섯 축의 정의가 이 배열에 있다. 사용자 상호작용에 가장 가까운 것은 축 5 다. 그러나 plain-language 규칙이나 질문 · 선택지의 추천 표시를 보라는 문장은 없다. 새 검사 항목을 넣는다면 축 5 의 question 배열이 그 자리다. codex 쪽 축 질문은 SKILL.md 가 축마다 $AXIS_FILE 로 따로 쓴다.", decides: [OQ11]}
  - {id: RC16 (RC80), path: "plugins/spec-distill/agents/integration-reviewer.md", anchor: "it reports seam defects split into 「이 PR 이 고침」 and 「뒤 에픽이 고침」", line: 4, claim: "로드맵 에픽 PR 에서만 도는 리뷰어다. 맡는 일은 에픽 사이 이음매이고 질문 꼴 항목은 없다.", decides: [OQ11]}
  - {id: RC17 (RC81), path: "plugins/spec-distill/agents/relay-checker.md", anchor: "4. 「(권장)」 — skill 이 붙인 자리에만, 그 자리에 그대로 있는가. ... 「문장 권장이 라벨 꼬리로 옮겨짐」", line: 32, claim: "이 레포에서 「(권장)」을 검사 항목으로 가진 유일한 persona 다. PR 리뷰어가 아니라 실행 뒤 대조자다. 라벨을 「글자 그대로 같은가」로 비교하고 「(권장)」의 위치를 대조한다. 라벨 꼬리 문법을 바꾸면 이 비교 규칙이 영향을 받는 소비자다. 실행 중 라벨을 보는 유일한 자리라는 점에서 OQ12 와도 닿는다.", decides: [OQ12, OQ13, OQ14]}
  - {id: RC18 (RC82), path: "plugins/spec-distill/tests/ (외 shared/tests/plain_language_block.py · plugins/project-init/tests/test_command_contract.py · plugins/plugin-audit/tests/test_skill_orchestration.py · plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh)", anchor: "Grep `\\(권장\\)|plain-language:begin|추천 없음` in {shared,plugins,scripts}/**/*.{sh,py,js}", claim: "「(권장)」 등의 문자열을 담은 테스트 · 스크립트 파일이 22개 있다. 각 파일이 라벨을 글자 그대로 비교하는지는 열어 보지 않았다 — 파일 목록일 뿐이다.", decides: [OQ14]}
  - {id: RC19 (RC83), path: "CLAUDE.md", anchor: "**버그가 리뷰를 탈출하면** 기본 해결책은 잡았어야 할 reviewer persona 파일을 편집하는 것이다 — 코드만 패치하지 않는다. 그 버그를 더 잘 잡는 자리가 락 · 스크립트 · skill 이면 그것을 고치고 이유를 적는다.", line: 97, claim: "문장이 실재한다. 기본은 persona 편집이고, 더 잘 잡는 자리가 락 · 스크립트 · skill 이면 이유를 적고 그쪽을 고친다. 78행은 persona 를 약화하는 PR 만 보안 리뷰 대상으로 정한다.", decides: [OQ11]}
unanswered: "pr-review-toolkit:* 의 persona 는 레포 밖이라 읽지 않았다. SKILL.md 변경 PR 에서 질문의 추천 표시를 지금 검사하는 리뷰어 · 축 · criteria 를 하나도 찾지 못했다. relay-checker 는 실행 뒤 relay 파일에서 「(권장)」 을 대조한다. RC18 의 각 테스트가 라벨을 글자 그대로 비교하는지는 열어 보지 않았다."
```
(모든 항목 touches: [] — 원문 그대로)

### 조사 9 — repo-researcher · R11 · 묶음 4

(빈 곳 5 — 추천하는 쪽 둘 이상 자리 수. 임시 id → 인터뷰 번호: RC<n> → RC<n+83>, 곧 RC84–RC99)

```yaml
repo_claims:
  - {id: RC1 (RC84), path: "plugins/spec-distill/skills/pm-interview/references/steelman.md", anchor: "#### Step 3 — 4-block 제시 / - **질문**: 「추천 표시는 출처 라벨뿐이다: builder 가 추천한 선택지 라벨 뒤에 `(builder 추천)`, orchestrator 판정 선택지 라벨 뒤에 `(orchestrator 추천)`」", line: 92, claim: "추천하는 쪽이 둘인 자리 1. 추천은 builder agent(kept/refined/switched)와 orchestrator(유지/보완/전환, 보류는 없음)에서 온다. 지금 표시 꼴: 선택지 순서는 유지/보완/전환/보류로 고정이고, 라벨 꼬리에 출처를 단다. 둘이 다른 선택지면 `(builder 추천)`과 `(orchestrator 추천)`을 각각 달고, 같으면 `(builder·orchestrator 추천)` 하나다. switched이면서 충돌이 0이면 `(builder 추천 · 전제 충돌 없음)`이다. `(권장)`·`(Recommended)`는 붙이지 않는다고 명시한다. 같은 두 출처는 질문 위 「추천 답안」 두 줄(88행)에도 나란히 나온다. 레포 안에서 '출처 꼬리' 문법이 이미 있는 유일한 자리다.", decides: [OQ13, OQ14]}
  - {id: RC2 (RC85), path: "plugins/spec-distill/skills/pm-interview/SKILL.md", anchor: "- **steelman 절차의 질문** — 「이 절의 질문 수·`(권장)` 표기·«추천: <첫 선택지>»·겹침 순서는 그 질문들에 적용하지 않으며」", line: 214, claim: "인터뷰 라운드의 일반 규칙은 '첫 선택지가 추천이고 라벨 끝에 `(권장)`'(202행)이다. steelman 질문만 이 규칙에서 빠져 RC1의 출처 꼬리를 쓴다. 그래서 한 skill 안에 표시 꼴이 두 가지 함께 있다.", decides: [OQ13]}
  - {id: RC3 (RC86), path: "plugins/spec-distill/references/conductor-dispatch.md", anchor: "## 사람 자리 — 「선택지는 (b) 의 수 · 순서 · 라벨 · 「(권장)」 를 글자 그대로 두고 … 지휘자 의견은 선택지 밖 「지휘자 의견:」 한 줄로만 쓴다. 지휘자 자신의 권장은 라벨 안 「(권장)」으로 넣지 않고 그 의견 줄에만 쓴다」", line: 32, claim: "추천하는 쪽이 둘인 자리 2. 지휘자가 하위 skill의 질문을 옮기는 자리다. 출처는 하위 skill 원문의 `(권장)`과 지휘자 의견이다. 지휘자 의견은 선택지 밖 한 줄로만. skill이 문장으로 낸 권장은 문장으로 옮기고 라벨 꼬리로 바꾸지 않는다. 그래서 세 번째 꼴(본문 문장 권장)도 함께 실릴 수 있다. 지금 표시 꼴은 두 출처가 서로 다른 층(라벨 꼬리 대 선택지 밖 줄)에 있다.", decides: [OQ13]}
  - {id: RC4 (RC87), path: "plugins/spec-distill/references/conducting.md", anchor: "4. **superpowers 가 묻는 자리.** 「skill 자신의 「(권장)」 표시와 사용자 답은 글자 그대로 두고 … 지휘 세션의 의견은 선택지 밖 「지휘자 의견:」 한 줄로만 쓰고」", line: 102, claim: "RC3과 같은 자리의 두 번째 서술이다. 자리 수로는 RC3과 합쳐 하나로 센다.", decides: [OQ13]}
  - {id: RC5 (RC88), path: "plugins/spec-distill/agents/relay-checker.md", anchor: "## 볼 것 — 「3. 라벨 — 돌려줄 값(라벨)이 글자 그대로 같은가. 4. 「(권장)」 — skill 이 붙인 자리에만, 그 자리에 그대로 있는가」", line: 31, claim: "옮김 대조 agent가 라벨과 `(권장)`의 위치를 글자 그대로 비교하는 소비자다. 지휘자가 만든 질문의 (권장)(35행)과 '문장 권장이 라벨 꼬리로 옮겨짐'(32행)을 어긋남으로 적는다. 꼬리 문법을 바꾸면 이 대조 규칙도 같이 바꿔야 한다.", decides: [OQ14, OQ11]}
  - {id: RC6 (RC89), path: "plugins/spec-distill/references/proceed-gate.md", anchor: "**둘째 질문(선택) — 다음 단계 갈래.** 「선택지는 그 skill 의 기본 다음 단계 `(권장)` 과 모델의 제안 둘이다」", line: 56, claim: "추천하는 쪽이 둘인 자리 3(정본). 출처는 skill에 고정된 기본 다음 단계 `(권장)`과 모델이 실행 중에 내는 다른 단계 제안이다. 모델의 제안은 꼬리 없는 라벨이고 제안 이유는 게이트 앞 글에 쓴다. 그래서 모델이 '이게 더 맞다'고 낸 쪽이 오히려 추천 표시를 받지 못한다.", decides: [OQ13]}
  - {id: RC7 (RC90), path: "plugins/spec-distill/skills/pm-interview/references/finishing.md", anchor: "**둘째 질문 — 다른 다음 단계.** 「선택지는 「brainstorming (권장)」 · 「<모델의 제안>」이고, 제안 이유는 게이트 앞 글(위 목록 끝)에 한 줄로 쓴다」", line: 528, claim: "RC6을 실제로 쓰는 곳 1. 이름 표(524–526행)에 ① 라벨 `… (권장)`이 고정돼 있다.", decides: [OQ13, OQ14]}
  - {id: RC8 (RC91), path: "plugins/spec-distill/skills/request-framing/SKILL.md", anchor: "**다른 다음 단계(둘째 질문).** 「선택지는 「인터뷰 (권장)」 · 「<모델의 제안>」, 제안 이유는 게이트 앞 글에」", line: 1128, claim: "RC6을 실제로 쓰는 곳 2. spec-review에는 이 둘째 질문이 없다.", decides: [OQ13, OQ14]}
  - {id: RC9 (RC92), path: "plugins/spec-distill/skills/spec-review/SKILL.md", anchor: "「두 갈래 중 이번 지적에 맞는 쪽 라벨에 「(권장)」, 설명에 이유 한 줄을 붙인다 — 고르는 것은 사용자다.」", line: 702, claim: "추천하는 쪽은 모델 하나이고, 표시가 고정 `(권장)`과 같은 꼴이라 출처를 구분할 수 없다. '둘 이상'에는 세지 않았다. 710행에서도 모델은 「인터뷰 다시 열기」 갈래를 '권한다'(문장 권장).", decides: [OQ12, OQ13]}
  - {id: RC10 (RC93), path: "plugins/spec-distill/references/conducting.md", anchor: "- 병렬 질문: 「선택지는 「병렬 (권장)」(…)과 「차례로」(…)다」", line: 40, claim: "지휘자가 만든 질문인데도 라벨에 `(권장)`이 고정돼 있다. 승인 질문과 같은 호출에 둘째 질문으로 붙는다. 질문마다 추천하는 쪽은 하나라 '둘 이상'으로 세지 않았다. conductor-dispatch.md 32행 · relay-checker.md 35행과 글자 그대로는 충돌한다. relay-checker는 relay 파일에 기록된 질문만 보므로 이 질문은 대조 대상이 아니다.", decides: [OQ13]}
  - {id: RC11 (RC94), path: "plugins/spec-distill/references/conducting.md", anchor: "- 병렬 질문: 「ledger record --spec <설계문서> --line \"병렬 답 · <YYYY-MM-DD HH:MM> · 「<고른 선택지>」 · 준비 에픽 <B…>\"」 / - 「차례로」 확인", line: 40, claim: "고른 라벨 원문이 설계문서 `## 지휘 기록`에 기록되고 뒤에 다시 읽힌다. 41행의 「차례로」 확인이 라벨을 글자 그대로 비교한다. 승인 줄도 `--choice \"<고른 선택지 원문>\"`으로 원문 그대로 남긴다(39행). 라벨 꼬리를 바꾸면 영향을 받는 소비자다.", decides: [OQ14]}
  - {id: RC12 (RC95), path: "plugins/spec-distill/skills/request-framing/SKILL.md", anchor: "### 확인 질문 — 라운드마다 하나 / `multiSelect: true,` (header: \"풀이 확인\")", line: 253, claim: "multiSelect 자리 1. 추천 표시가 없다. 추천이 여럿 붙을 수 있는지도 정해져 있지 않다.", decides: [OQ13]}
  - {id: RC13 (RC96), path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md", anchor: "**낮춘 지적 게이트 (표면화 뒤 · 라우팅 앞).** / `multiSelect: true }] })`", line: 716, claim: "multiSelect 자리 2. 추천 표시가 없다.", decides: [OQ13]}
  - {id: RC14 (RC97), path: "plugins/quality-gates/references/e2e.md", anchor: "## 2. 질문 — 「`AskUserQuestion` 질문 하나, 여러 선택(`multiSelect: true`)이다. 선택지는 넷을 넘지 않는다.」", line: 35, claim: "multiSelect 자리 3. 추천 표시는 없다. 모델 판단은 첫 선택지 위치로 드러내고 (권장) 꼬리는 없다.", decides: [OQ13]}
  - {id: RC15 (RC98), path: "plugins/spec-distill/tests/test_end_gates.sh", anchor: "assert_contains \"$B2\" '| 하나짜리 brief · 둘째 질문 있음 | 확정하고 /compact 후 다음 단계로 (권장) | …' / '「brainstorming (권장)」 · 「<모델의 제안>」'", line: 44, claim: "라벨을 글자 그대로 잡는 잠금 테스트(40, 44, 47행)다. test_request_framing_open.sh 102행 · test_parallel_recommend_docs.sh 62·65·158행 · test_conducting_interview_stage.sh 119 · 812–815 · 840행(steelman 출처 꼬리)도 같은 종류다. 꼬리 문법을 바꾸면 모두 영향을 받는다.", decides: [OQ14]}
  - {id: RC16 (RC99), path: "plugins/spec-distill/skills/pm-interview/SKILL.md", anchor: "「`neglect_flag: true`면 다음 probe에서 neglected 차원 하나를 추천 답안으로 제시」", line: 446, claim: "agent가 근거를 낸 추천과 모델이 스스로 낸 추천이 같은 `(권장)` 꼴로 합쳐진다. '둘 이상'으로 세지 않았다.", decides: [OQ13]}
unanswered: "multiSelect 질문에서 추천이 여럿일 때의 표시 규칙은 레포 어디에도 없다. 세 자리 모두 지금은 추천 표시가 없다."
```
원문 요지(그대로): 추천하는 쪽이 둘 이상인 자리는 3곳이다 — steelman 질문 · 지휘자가 하위 skill 질문을 옮기는 자리 · proceed-gate 둘째 질문(정본 1곳 + 쓰는 곳 2곳). multiSelect: true 자리는 3곳이다 — request-framing 풀이 확인 · quality-pipeline 낮춘 지적 · e2e 시나리오. 지금 추천이 붙는 곳은 0곳이다.
(모든 항목 touches: [] — 원문 그대로)

### 조사 10 — blind-spot-prober · R11 · 묶음 4

(빈 곳 4 — 실행 중 라벨 흔적 · 사후 표본 검사. 임시 id → 인터뷰 번호: RC<n> → RC<n+99>, 곧 RC100–RC107)

```yaml
hidden_assumptions:
  - assumption: "레포 안에 «모델이 실제로 띄운 질문 라벨»의 흔적이 남아 있어서, 나중에 표본을 뽑아 검사할 수 있다"
    why_risky: "인터뷰 state 는 고른 선택지 라벨 하나만 적고(source: chosen), 고르지 않은 선택지와 질문 본문은 적지 않는다. 그래서 어느 선택지에 (권장)이 붙었는지, 본문에 「추천 없음 — 근거 부족」이 있었는지를 되살릴 수 없다. S3 사건이 일어난 자리(분해 판단, R10)는 라운드 기록에 질문도 다음 결정도 없다. relay 파일은 git 이 무시하는 기계 상태이고, 지휘자가 옮긴 질문만 다룬다. 세션 transcript 는 기본값으로 30일 뒤 지워진다. 사후 표본 검사(OQ12)를 할 바탕 자료가 거의 없다."
    evidence:
      - {url: "https://code.claude.com/docs/en/claude-directory", supports: current, claim: "Claude Code 는 cleanupPeriodDays(기본 30일, 0은 받지 않음)를 넘긴 세션 파일을 시작할 때 지운다. 레포 밖 transcript 는 오래 남는 감사 자료가 될 수 없다.", decides: [OQ12]}
      - {url: "https://brycewatson.com/blog/28-claude-code-deletes-old-logs", supports: current, claim: "보존 기간을 나중에 늘려도 이미 지워진 transcript 는 되살아나지 않는다(블로그 관찰).", decides: [OQ12]}
  - assumption: "흔적이 남아도 그 기록은 실제로 띄운 질문과 같다"
    why_risky: "state 의 라운드 기록과 relay 파일은 질문을 띄운 바로 그 모델이 직접 쓴 서술이다. 도구 호출에 실린 값을 기계로 옮긴 것이 아니다. 띄운 쪽과 기록하는 쪽이 같아서 Law 2 와 같은 구조 문제가 생긴다."
    evidence:
      - {url: "https://www.anthropic.com/research/reasoning-models-dont-say-think", supports: current, claim: "모델이 자기 행동의 이유를 스스로 적은 서술은 실제로 영향을 준 요인을 자주 빠뜨린다(Claude 3.7 Sonnet 충실도 25%).", decides: [OQ12]}
  - assumption: "「추천 없음 — 근거 부족」의 빈도가 회피를 재는 신호다"
    why_risky: "빈도만으로는 정당한 추천 없음과 회피를 가를 수 없다. 그 질문에 추천이 마땅히 있었어야 했는지라는 정답이 따로 필요하다."
    evidence:
      - {url: "https://arxiv.org/html/2510.01782v1", supports: current, claim: "거절 비율만 세면 거절 성향에 치우친다. 그래서 거절과 실제 오류의 상관(Refusal Index)으로 잰다.", decides: [OQ12]}
      - {url: "https://hamel.dev/blog/posts/evals-faq/how-do-we-evaluate-a-models-ability-to-express-uncertainty-or-know-what-it-doesnt-know.html", supports: current, claim: "«모른다»를 제대로 하는지 평가하려면 정답이 미리 정해진 균형 잡힌 집합이 필요하다.", decides: [OQ12]}
  - assumption: "근거 부족 남발을 감시하면 회피가 줄어든다"
    why_risky: "추천 없음의 이유 범주는 모델이 스스로 고른다. 근거 부족만 표본으로 보면 회피는 «사용자만 아는 것»으로 옮겨 가거나, 약한 근거 위의 (권장)으로 바뀐다. 웹 사례는 RL 학습 압력에 관한 것이라 유비로만 쓴다."
    evidence:
      - {url: "https://arxiv.org/abs/2503.11926v1", supports: current, claim: "감시 신호에 최적화 압력을 걸면, 에이전트는 감시가 보는 표면만 숨기는 쪽으로 간다(obfuscation).", decides: [OQ12]}
  - assumption: "(권장) 표시는 이득만 있다 — 실패는 추천이 «없는» 쪽에서만 난다"
    why_risky: "모든 질문에 (권장)이 붙으면 사용자는 근거를 읽지 않고 표시를 따르게 된다. 표본 검사가 추천 없음만 보면 반대쪽 실패(나쁜 추천을 사람이 그대로 승인)는 아무도 재지 않는다. 지난 인터뷰 기록에서 사용자가 고른 답은 대부분 (권장) 선택지다."
    evidence:
      - {url: "https://repository.gatech.edu/entities/publication/1118fdb6-fa90-499b-b5e1-9628b8680d00", supports: current, claim: "표시 방식으로 순응을 높이면 commission error 도 함께 늘었다. 자동화 편향을 줄이려면 표시가 권장의 근거를 전해야 한다.", decides: [OQ12]}
failure_modes:
  - {mode: "사후 표본 검사의 표본이 없거나 한쪽으로 쏠려서, 「남발 없음」이 «잴 수 없음»과 구별되지 않는다", trigger: "질문 라운드를 tracked 파일에 남기는 곳이 pm-interview 하나뿐이다. 다른 skill 의 질문은 흔적이 없거나 git 이 무시하는 자리에 남는다. 레포 규칙은 «셀 수 없음을 침묵과 0으로 내지 말라»인데, 표본 검사가 이 규칙을 어길 위험이 크다.", evidence: [{url: "https://code.claude.com/docs/en/claude-directory", claim: "레포 밖 원본(transcript)은 30일 뒤 지워져 나중에 표본을 다시 뽑을 수 없다", decides: [OQ12]}]}
  - {mode: "정적 검사가 템플릿 자리표시는 통과시키는데, 실행 중 모델이 (권장)을 채우지 않거나 엉뚱한 선택지에 채운다", trigger: "S3 사건 자리(finishing.md 분해 판단)는 라벨이 고정 리터럴이고, 권고는 실행 중에 정해져 산문 줄에만 실린다. 라벨에 권장을 실으려면 리터럴을 «실행 중 채우는 꼴»로 바꿔야 한다. 그러면 정적 검사는 지시문만 보고 채운 결과는 못 본다. 그 리터럴을 글자 그대로 잠근 테스트도 함께 깨진다.", evidence: [{url: "https://repository.gatech.edu/entities/publication/1118fdb6-fa90-499b-b5e1-9628b8680d00", claim: "권장 표지만 있고 근거가 전달되지 않으면, 잘못된 권장에도 순응이 일어난다.", decides: [OQ12, OQ14]}]}
  - {mode: "이유 범주를 바꿔 치기 — 근거 부족 감시를 «사용자만 아는 것»이나 «자기 산출물 처분»으로 우회한다", trigger: "어떤 질문이 어느 범주인지를 정답 없이 모델이 자기 판단으로 고른다", evidence: [{url: "https://arxiv.org/abs/2503.11926v1", claim: "감시되는 표면만 바뀌고 밑의 행동은 남는다(유비).", decides: [OQ12]}]}
  - {mode: "빈도 지표의 오독 — 추천 없음 비율이 낮다고 좋다고 읽거나, 높다고 회피라고 읽는다", trigger: "질문마다 «추천할 수 있었나»의 정답 라벨 없이 비율만 센다", evidence: [{url: "https://arxiv.org/html/2510.01782v1", claim: "거절 비율은 실력이 아니라 거절 성향을 잰다.", decides: [OQ12]}]}
confidence: 0.7
repo_claims:
  - {id: RC1 (RC100), path: "plugins/spec-distill/skills/pm-interview/SKILL.md", anchor: "답은 `user_statements` 에 `S<m>` 하나로 append 한다(선택지 = `chosen`", line: 220, claim: "인터뷰 state 는 고른 선택지 라벨만 적는다. 고르지 않은 선택지 라벨과 그 (권장) 표시는 남지 않는다.", decides: [OQ12]}
  - {id: RC2 (RC101), path: "docs/superpowers/interview/2026-10-24-epic-parallel-recommend-interview.state.md", anchor: "## R10", line: 796, claim: "S3 사건이 난 라운드(R10)에는 「질문」 · 「다음 결정」 절이 없고 「답 → S17」 만 있다. 사건의 답 S18 「spec 하나로」(line 127)는 어느 라운드의 답으로도 이어져 있지 않다.", decides: [OQ12]}
  - {id: RC3 (RC102), path: "plugins/spec-distill/skills/pm-interview/references/finishing.md", anchor: "2. **판정.** `AskUserQuestion` 하나", line: 34, claim: "분해 판단 라벨은 고정 리터럴이다. 권고가 실행 중에 정해지므로, 라벨에 실으려면 «실행 중 채우는 꼴»이 되고 정적 검사는 채운 결과를 못 본다.", decides: [OQ12, OQ14]}
  - {id: RC4 (RC103), path: "plugins/spec-distill/tests/test_decompose_surface.sh", anchor: "'\"spec 하나로\"' '\"나눈다 — 분해안 보기\"'", line: 27, claim: "분해 판단 라벨을 글자 그대로 잠근 테스트다.", decides: [OQ14]}
  - {id: RC5 (RC104), path: ".gitignore", anchor: "/.claude/*", line: 219, claim: "relay 파일이 사는 .claude/spec-distill/conductor/... 는 git 이 무시한다.", decides: [OQ12]}
  - {id: RC6 (RC105), path: "plugins/spec-distill/skills/epic-conductor/SKILL.md", anchor: "### 7. 옮김 대조", line: 192, claim: "relay 기록과 relay-checker 대조는 «하위가 돌려보낸 사람 자리를 옮긴» 질문만 다룬다.", decides: [OQ12]}
  - {id: RC7 (RC106), path: ".claude/spec-distill/conductor/2026-10-11-persistent-explore-pm-decompose/files/relay/R14/relay-1.md", anchor: "## 실제로 띄운 질문", line: 13, claim: "「실제로 띄운 질문」 절은 질문을 띄운 지휘자 모델이 스스로 쓴 서술이다. 기록은 도구 호출 값이 아니라 자기 보고다. «라벨은 원문 그대로»라는 지금의 옮김 규칙이 (권장) 꼬리와 맞선다는 것도 보인다.", decides: [OQ12, OQ14]}
  - {id: RC8 (RC107), path: "docs/superpowers/interview/2026-10-24-epic-parallel-recommend-interview.state.md", anchor: "user_statements", line: 59, claim: "chosen 답 대부분이 (권장) 또는 (… 추천) 선택지다. 권장을 고르지 않은 답은 S3 · S18 정도다. 권장 표시가 생기면 사용자 수락률이 매우 높다는 정황이다.", decides: [OQ12]}
```
(모든 항목 touches: [] — 원문 그대로)

### 조사 6 — repo-researcher · R11 · 묶음 4

(빈 곳 1 — 라벨 글자 비교 소비자 · 락. 임시 id → 인터뷰 번호: RC<n> → RC<n+107>, 곧 RC108–RC125)

```yaml
repo_claims:
  - {id: RC1 (RC108), path: "shared/docreview/scripts/docreview_state.py", anchor: "_CHOICE_LABEL = { \"pre\": {\"adopt\": \"고친다(채택)\", ...}, \"post\": {...} } / def choice_label(choice, kind)", line: 2134, claim: "선택지 라벨이 사는 유일한 리터럴 자리다. 엔진은 라벨을 내보내기만 하고 다시 읽지 않는다. 사용자가 고른 답은 라벨로 엔진에 돌아오지 않는다. 모델이 고른 처분을 enum `decide --choice adopt|reject|hold`로 바꿔 넘기고, 라벨 원문은 `--quote` 에 불투명한 글로만 실린다. 그래서 모델이 화면의 라벨 끝에 「(권장)」이나 「(<누가> 추천)」을 붙이거나 떼어도 엔진은 깨지지 않는다. 다만 이 사전의 값 자체를 고치면 렌더와 cases.sh 기대값이 함께 바뀐다.", decides: [OQ14]}
  - {id: RC2 (RC109), path: "shared/tests/fixtures/docreview/cases.sh", anchor: "choices_match() / choices_match_expired()", line: 1290, claim: "렌더된 「대안:」 줄을 '/' 로 나눠 strip 한 집합이 choice_label() 집합과 같은지 잰다(집합 등호). _CHOICE_LABEL 에 꼬리를 넣으면 양쪽이 함께 움직여 통과한다. 렌더 쪽에서만 꼬리를 덧붙이면 등호가 깨진다.", decides: [OQ14]}
  - {id: RC3 (RC110), path: "plugins/spec-distill/agents/relay-checker.md", anchor: "## 볼 것 — 3. 라벨 — 돌려줄 값(라벨)이 글자 그대로 같은가. 4. 「(권장)」 — skill 이 붙인 자리에만, 그 자리에 그대로 있는가.", line: 31, claim: "실행 중 라벨을 글자 그대로 대조하는 agent 는 이것 하나다. 4번과 35행은 「(권장)」 리터럴을 이름으로 잡는다. 「(<누가> 추천)」 꼴은 «권장 표시» 규칙으로 다루지 않는다 — 3번의 라벨 불일치로만 잡히고, 「지휘자가 만든 질문」에서는 3번이 꺼지므로 잡히지 않는다. 이 agent 가 «누가 추천했나» 꼬리를 허용할지가 정해져 있지 않다.", decides: [OQ13, OQ14, OQ12]}
  - {id: RC4 (RC111), path: "plugins/spec-distill/references/conductor-dispatch.md", anchor: "선택지는 (b) 의 수 · 순서 · 라벨 · 「(권장)」 를 글자 그대로 두고 … 사용자 답은 글자 그대로 같은 agent 에 돌려준다.", line: 32, claim: "지휘자가 하위 skill 라벨과 꼬리를 바꾸지 않고, 고른 라벨을 글자 그대로 하위 agent 에 돌려준다. 규칙 문면은 「(권장)」 리터럴로만 금지를 쓴다.", decides: [OQ13, OQ14]}
  - {id: RC5 (RC112), path: "plugins/spec-distill/skills/pm-interview/references/steelman.md", anchor: "추천 표시는 출처 라벨뿐이다: … `(builder 추천)` … `(orchestrator 추천)` … `(builder·orchestrator 추천)` … `(builder 추천 · 전제 충돌 없음)`", line: 92, claim: "「(<누가> 추천)」 출처 꼬리 문법이 이미 한 곳에 정착돼 있다: 추천한 쪽 이름 + ' 추천'. 같은 선택지면 가운뎃점(·)으로 합친 꼬리 하나, 다르면 각자. 부가 조건은 ' · ' 로 덧붙인다. Step 4 기록은 verdict 어휘로 적어 꼬리가 기록 파서에 닿지 않는다.", decides: [OQ13]}
  - {id: RC6 (RC113), path: "plugins/spec-distill/tests/test_conducting_interview_stage.sh", anchor: "steelman_q … ban='`(Recommended)`·`(권장)` 접미사는 붙이지 않는다'; grep -qE '\\(Recommended\\)|\\(권장\\)' <<<\"$r3_minus_ban\"", line: 809, claim: "RC5 문법을 잠그는 락이다. 부재 regex 는 두 리터럴만 본다. 「(<누가> 추천)」 꼴은 막지 않고, 다른 철자도 못 잡는다. 「어느 락도 모델이 실제로 라벨을 그렇게 붙이는지는 재지 않는다」.", decides: [OQ13, OQ12, OQ14]}
  - {id: RC7 (RC114), path: "plugins/spec-distill/tests/test_conducting_interview_stage.sh", anchor: "grep -qF '{label: \"확정하고 /compact 후 brainstorming (권장)\"' <<<\"$b2_block\"", line: 119, claim: "finishing.md B-2 라벨을 여는 따옴표부터 닫는 따옴표까지 고정 문자열로 잡는다. ① 에서 꼬리를 떼거나 바꾸면 RED, ② 에 꼬리를 붙여도 RED 다. 496행은 라운드 규칙 문장을 잠근다.", decides: [OQ14]}
  - {id: RC8 (RC115), path: "plugins/spec-distill/tests/test_end_gates.sh", anchor: "assert_contains \"$B2\" '| 하나짜리 brief · 둘째 질문 없음 | 확정하고 /compact 후 brainstorming (권장) | 확정하고 /new 후 brainstorming |'", line: 40, claim: "B-2 이름 표 행 전체를 잠근다. ① 꼬리를 바꾸거나 ② 에 꼬리를 붙이면 RED 다.", decides: [OQ14]}
  - {id: RC9 (RC116), path: "plugins/spec-distill/tests/test_review_handoff_order.sh", anchor: "assert_not_contains \"$r2\" '권장' \"spec-review: 권장은 ① 하나\"", line: 176, claim: "① 행에 '(권장)' 이 있는지를 본다. ② 행 부재 락은 '권장' 낱말만 보므로 「(… 추천)」을 붙여도 통과한다.", decides: [OQ14]}
  - {id: RC10 (RC117), path: "plugins/project-init/tests/test_command_contract.py", anchor: "for label in (\"「AGENTS.md 로 옮기기 (권장)」\", \"「CLAUDE.md 에 바로 쓰기」\", \"「중단」\"): self.assertIn(label, self.step1)", line: 253, claim: "닫는 」 까지 포함하므로 꼬리를 떼거나 바꾸거나 꼬리 없는 라벨에 새로 붙이면 모두 RED 다.", decides: [OQ14]}
  - {id: RC11 (RC118), path: "plugins/plugin-audit/tests/test_skill_orchestration.py", anchor: "scope = \"「여섯 축 전부 (권장)」 · 「축 골라서」 · 「중단」\"", line: 79, claim: "셋 다 닫는 」 까지 포함하므로 꼬리를 바꾸면 RED 다.", decides: [OQ14]}
  - {id: RC12 (RC119), path: "plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh", anchor: "assert_contains \"$E3\" '「1명 (권장)」'", line: 76, claim: "꼬리를 바꾸거나 「2명」 · 「3명」에 꼬리를 붙이면 RED 다.", decides: [OQ14]}
  - {id: RC13 (RC120), path: "plugins/spec-distill/tests/test_ledger_wiring.sh", anchor: "grep -qF '「그만둠 (권장)」' \"$SR\"", line: 39, claim: "같은 꼴의 락이 더 있다: test_interview_state_flow.sh:85 · test_reviewing_brief_skill.sh:153(」 없이 부분 문자열이라 끝에 꼬리를 덧붙이면 통과) · test_parallel_recommend_docs.sh:62 · 65 · 158 · test_request_framing_open.sh:102 · test_entry_guidance.sh:46(꼬리가 」 밖에 붙는 별종 꼴).", decides: [OQ14]}
  - {id: RC14 (RC121), path: "plugins/spec-distill/tests/test_epic_conductor_skill.sh", anchor: "assert_contains \"$(cat \"$RC\")\" '「지휘자가 만든 질문의 라벨에 (권장)」'", line: 73, claim: "relay-checker.md 의 「(권장)」 규칙 문장 넷을 잠근다. test_conductor_dispatch_reference.sh:26-32 와 test_conducting_reference.sh:117 도 같은 규칙 문장을 잠근다. 꼬리 문법을 일반화하면 함께 고쳐야 한다.", decides: [OQ13, OQ14]}
  - {id: RC15 (RC122), path: "plugins/spec-distill/scripts/conductor_ledger.py", anchor: "def approval_line(date, choice): return \"%s%s · 「%s」\" % (APPROVAL_PREFIX, date, choice)", line: 259, claim: "고른 라벨 원문을 승인 줄에 그대로 싣고, 읽는 쪽은 날짜만 읽는다. 꼬리가 무엇이든 깨지지 않는다. 테스트의 「(권장)」 리터럴 여럿은 입력과 기대값이 같은 데이터 픽스처라 skill 라벨을 바꿔도 깨지지 않는다.", decides: [OQ14]}
  - {id: RC16 (RC123), path: "plugins/spec-distill/skills/pm-interview/references/finishing.md", anchor: "**이름이 바뀌어도 절차는 같다.** … - **① 확정하고 /compact 후 brainstorming**:", line: 554, claim: "산문 분기 문장은 대체로 꼬리를 뗀 이름으로 분기하고 모델의 의미 대응에 기댄다. 글자 비교 코드는 없다. 예외: conducting.md:101 「「병렬 (권장)」 은 … 뜻이다」는 꼬리까지 포함한 라벨을 이름으로 부른다(test_parallel_recommend_docs.sh:158 이 잠금).", decides: [OQ14]}
  - {id: RC17 (RC124), path: "shared/tests/test_plain_language_block.sh", anchor: "plain_language_block.py — region != canon", line: 49, claim: "규칙 줄은 모든 SKILL.md 에 바이트 단위로 복제된다. 정본 한 줄을 고치면 모든 SKILL.md 의 블록을 같은 바이트로 다시 맞춰야 한다.", decides: [OQ13, OQ14]}
  - {id: RC18 (RC125), path: "plugins (scripts · hooks 전수)", anchor: "Grep '권장\\)|Recommended|추천\\)' in {plugins,shared}/**/{scripts,hooks,lib,bin}/** → plugin-audit/scripts/run-own-tests.sh:113 '(gtimeout 권장)' 1건뿐", claim: "라벨에서 꼬리를 떼고 비교하는 공통 정규화 함수는 없다. AskUserQuestion 답을 받아 읽는 훅 · 스크립트도 없다. 라벨을 «돌려받아» 비교하는 소비자는 모델(산문 분기 · 지휘자 옮김)과 relay-checker 둘뿐이다.", decides: [OQ14, OQ12]}
unanswered: "실행 중 라벨을 정적으로 재는 장치는 relay-checker 말고는 없다. 부분 문자열 락이 끝에 덧붙인 꼬리를 통과시키는지는 리터럴이 닫는 」/\" 를 포함하는지에 달려 있다."
```
원문 요지(그대로): 라벨을 기계가 글자 그대로 되읽는 곳은 없다. 글자 그대로 비교하는 실행 중 소비자는 지휘자의 옮김 규칙과 relay-checker 둘이고, 둘 다 「(권장)」 리터럴로 규칙을 쓴다. 꼬리를 바꿀 때 깨지는 것은 주로 문서 문면 락이다. 출처 꼬리 문법의 기존 선례는 steelman.md:92 다.
(모든 항목 touches: [] — 원문 그대로)

### 조사 7 — repo-researcher · R11 · 묶음 4

(빈 곳 2 — 무권장 자리 분류. 임시 id → 인터뷰 번호: RC<n> → RC<n+125>, 곧 RC126–RC159)

원문 요약(그대로): `plugins/*` 와 `shared/*` 에서 사용자에게 선택지를 내는 자리 중 추천 표시(「(권장)」 · 「(Recommended)」 · 「(… 추천)」)가 없는 곳은 **55곳**이다. 분류하면 **① 3곳 · ② 35곳 · ③ 17곳**이다. ③ 은 둘로 나눴다. ③a 는 자기 코드 · 문서 · 편집에 대한 지적이나 편집을 처분하는 질문(10곳)이고, ③b 는 모델이 낸 제안 · 판정 · 풀이를 승인받는 질문(7곳)이다. 사용자 정의의 ③ 은 ③a 에 더 가깝다. ③b 를 ② 로 옮기면 ② 42 · ③ 10 이 된다. 세지 않은 경우: 선택지 없는 자유 입력 질문, 같은 질문을 다시 묻는 경우, 이미 추천 표시가 있는 자리. 셀 단위: 질문 정의가 사는 곳 하나를 한 자리로 셌다.

```yaml
repo_claims:
  - {id: RC1 (RC126), path: "shared/style/plain-language.md", anchor: "추천은 「(권장)」으로 표시한다.", line: 6, claim: "추천할 때의 표기만 정하고, 추천을 반드시 하라고는 하지 않는다. 그래서 이 규칙만으로는 ① 과 ② 를 가를 수 없다.", decides: [OQ11]}
  - {id: RC2 (RC127), path: "plugins/spec-distill/skills/pm-interview/SKILL.md", anchor: "질문마다 첫 선택지가 추천이고 그 라벨 끝에 `(권장)` 을 단다 — steelman 절차의 질문만 예외다", line: 202, claim: "추천을 의무로 정한 곳은 인터뷰 라운드 질문뿐이다. 포화 · 상한 질문(saturation.md)은 라운드로 기록되지 않아 이 규칙에 들지 않는다.", decides: [OQ11]}
  - {id: RC3 (RC128), path: "plugins/spec-distill/skills/pm-interview/references/steelman.md", anchor: "추천 표시는 출처 라벨뿐이다: … `(Recommended)`·`(권장)` 접미사는 붙이지 않는다", line: 92, claim: "레포에서 출처 꼬리 문법이 정해진 유일한 곳이다. 추천은 있으므로 55곳에 넣지 않았다.", decides: [OQ13]}
  - {id: RC4 (RC129), path: "plugins/spec-distill/skills/request-framing/SKILL.md", anchor: "**권장 표시를 달지 않는다** — 어느 덩어리가 승인된 수정인지 가를 기계가 없고, 저자의 권장은 바로 그 가름을 저자가 하는 것이다.", line: 928, claim: "① 저자 편집 덩어리마다 「그대로 둔다 / 되돌린다」. 무권장의 근거가 문장으로 적혀 있다.", decides: [OQ11]}
  - {id: RC5 (RC130), path: "plugins/spec-distill/references/conductor-dispatch.md", anchor: "지휘자 자신의 권장은 라벨 안 「(권장)」으로 넣지 않고 그 의견 줄에만 쓴다 — 지휘자가 만든 질문에서도 같다. … 그 선택지에는 「(권장)」을 달지 않는다", line: 32, claim: "① 하위 agent 의 보고로 지휘자가 만든 질문에는 라벨 꼬리를 달지 않는다. 해당 자리는 둘이다 — conducting.md:50 · 102 의 계획 검토, conducting.md:50 · 103 의 판정이 AC 를 바꿀 때 · BLOCKED 일 때. 두 자리에 규칙이 닿는다는 판단은 추론이다.", decides: [OQ11, OQ13]}
  - {id: RC6 (RC131), path: "plugins/spec-distill/skills/spec-review/SKILL.md", anchor: "「승인 — 계획 담당자에게」(권장) · 「수정 필요」 · 「멈춤」", line: 766, claim: "「(권장)」이 꺾쇠 밖에 있어 라벨 꼬리인지 산문인지 모호하다.", decides: [OQ14]}
  - {id: RC7 (RC132), path: "plugins/spec-distill/references/proceed-gate.md", anchor: "「승인 — 계획 담당자에게」 · 「수정 필요」(③ 과 같은 후속 갈래) · 「멈춤」(④)", line: 60, claim: "정본과 conducting.md:39 · 101 은 표시 없이 적고, 근거 문장도 없다(②). RC131 과 맞지 않는다.", decides: [OQ11]}
  - {id: RC8 (RC133), path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md", anchor: "**범위 모드 갈래.** … 「지금 판정으로 끝내기」 · 「멈추기」", line: 819, claim: "② 범위 모드는 이미 있는 커밋을 리뷰하므로 저자가 이 세션이 아닐 수 있다.", decides: []}
  - {id: RC9 (RC134), path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md", anchor: "### Retry: error handling — 「이번 반복 멈추기」 · 「이 파일만 건너뛰기」", line: 997, claim: "② 수정 실패 때 묻는 질문이다.", decides: []}
  - {id: RC10 (RC135), path: "plugins/quality-gates/references/e2e.md", anchor: "## 2. 질문 — `AskUserQuestion` 질문 하나, 여러 선택(`multiSelect: true`)", line: 35, claim: "② 고르는 것이 명령 실행 승인이 된다. 순서 규칙만 있고 표시는 없다.", decides: []}
  - {id: RC11 (RC136), path: "plugins/quality-gates/skills/artifact-critique/SKILL.md", anchor: "E1 「이 파일(`<path>`)을 산출물로 비평할까요?」 · E2b **멈출 때의 선택** · E3 (1) … · 4 NEEDS_RESOLUTION 「재시도 / 중단?」", line: 97, claim: "② 네 자리다(97 · 133 · 176 · 293). 188 만 「1명 (권장)」.", decides: []}
  - {id: RC12 (RC137), path: "plugins/spec-distill/skills/pm-interview/references/saturation.md", anchor: "`AskUserQuestion` 1회로 셋 중 하나를 받는다(첫 선택지가 추천)", line: 35, claim: "② 4곳(35 · 96 · 110 · 125). 35 는 순서만, 나머지는 순서 규칙조차 없다.", decides: [OQ12]}
  - {id: RC13 (RC138), path: "plugins/spec-distill/skills/pm-interview/references/finishing.md", anchor: "이어서 권고 한 줄 … header: \"분해 판단\"", line: 33, claim: "② 권고는 질문 앞 문장으로만. relay-checker.md:32 가 「문장 권장」이라 부르는 모양이다.", decides: [OQ13]}
  - {id: RC14 (RC139), path: "plugins/spec-distill/skills/pm-interview/references/finishing.md", anchor: "**닫은 답의 출처로 멈추면 — 되묻기 갈래.** … / 「참고 전부 보기」 · 「접은 채로 둔다」", line: 260, claim: "② 두 자리(260 · 396). spec-review/SKILL.md:635 도 ② 1곳.", decides: []}
  - {id: RC15 (RC140), path: "plugins/spec-distill/references/conducting.md", anchor: "사용자 몫 감사는 … 골라 묻는다 / 설계 의도가 바뀌면 사용자에게 묻는다 / …", line: 28, claim: "② 지휘자 자신이 묻는 문장형 질문 여섯(28 · 50 · 71 · 72 · 114 · 14). 병렬 질문은 「병렬 (권장)」(40).", decides: []}
  - {id: RC16 (RC141), path: "plugins/spec-distill/skills/epic-conductor/SKILL.md", anchor: "여럿이면 `AskUserQuestion` 으로 고르게 한다", line: 96, claim: "② 로드맵을 고르는 질문이다.", decides: []}
  - {id: RC17 (RC142), path: "plugins/spec-distill/skills/request-framing/SKILL.md", anchor: "단독 `AskUserQuestion` 으로 「멈춘다 / 그 줄만 인용 표시로 감싼다」 / 3. **질문을 한꺼번에**", line: 602, claim: "② 두 자리(602 · 230).", decides: []}
  - {id: RC18 (RC143), path: "plugins/spec-distill/skills/spec-review/SKILL.md", anchor: "인자가 없으면 후보를 뽑아 `AskUserQuestion` 으로 고르게 한다 / 「지적대로 고치기」 · 「인터뷰 다시 열기」 · 「직접 편집」", line: 697, claim: "② 두 자리(184 · 697).", decides: []}
  - {id: RC19 (RC144), path: "plugins/project-init/skills/project-init/SKILL.md", anchor: "### Step 2 … / Commit scope / 「Squash merge (clean history 권장)」 / 「`release/v*` … — default」 / \"헌장을 업데이트할까요?\" / 「건너뛰기」 · 「계속 묻기」 · 「중단」", line: 106, claim: "② 여섯 자리(106 · 122 · 127 · 140 · 148 · 193). 설명 안 「권장」 · 「— default」 는 비표준 표기라 ② 에 넣었다.", decides: [OQ13]}
  - {id: RC20 (RC145), path: "plugins/plugin-audit/skills/plugin-audit/SKILL.md", anchor: "「축 1~3 중 쓸 것」 · 「축 4~6 중 쓸 것」 … 「다시 고르기」 · 「중단」", line: 87, claim: "② 두 자리.", decides: []}
  - {id: RC21 (RC146), path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md", anchor: "**낮춘 지적 게이트** / ### Fix-loop decision / ### Max-iter decision", line: 711, claim: "③a 세 자리(711 · 840 · 923). 이 세션이 쓴 코드의 지적과 분류표를 처분한다. 근거 문장은 없다.", decides: [OQ11]}
  - {id: RC22 (RC147), path: "plugins/quality-gates/references/e2e.md", anchor: "## 5. 걷기 직후 게이트", line: 100, claim: "③a 모델이 걸어 모은 증거의 판정안을 승인하거나 뒤집는다.", decides: []}
  - {id: RC23 (RC148), path: "plugins/quality-gates/skills/artifact-critique/SKILL.md", anchor: "**한 번 더 돌기** / **여기서 끝내기**", line: 353, claim: "③a 루프가 편집한 산출물에 지적이 남은 상태에서 상한을 넘길지 묻는다.", decides: []}
  - {id: RC24 (RC149), path: "shared/docreview/references/reviewing-document.md", anchor: "8. **게이트** … 「추가 라운드 1회 열기」와 「진행 옵션으로」 … 「열기 / 열지 않음」", line: 27, claim: "③a 두 자리. 라벨은 엔진 표(docreview_state.py:2135)를 쓰고 shared/docreview 에 「권장」 글자는 하나도 없다. spec-review:552 · reviewing-brief:601 · request-framing:777 · 795 가 같은 질문을 다시 적는다.", decides: [OQ11, OQ12, OQ14]}
  - {id: RC25 (RC150), path: "plugins/spec-distill/skills/request-framing/SKILL.md", anchor: "seed 전문을 한 질문으로 보여 「이대로 둔다 / 멈춘다」를 묻는다 / 「되살리기」 … · 「그대로 둔다」", line: 932, claim: "③a 두 자리(932 · 1169). RC129 의 근거 문장은 덩어리 질문에만 걸린다.", decides: []}
  - {id: RC26 (RC151), path: "plugins/spec-distill/references/conducting.md", anchor: "두 번째 재리뷰 뒤 남는 지적은 고치지 않고 멈출 조건대로 넘기거나, 고치려면 사용자에게 묻는다.", line: 109, claim: "③a 남은 리뷰 지적을 고칠지 묻는 문장형 질문이다.", decides: []}
  - {id: RC27 (RC152), path: "plugins/spec-distill/skills/pm-interview/references/finishing.md", anchor: "4. **고치기 · 승인.** … 「승인」 · 「고치기」 · 「spec 하나로」 … 「계속 고칠까요」 / 「계속 고친다(2번 더)」 · 「지금 목록으로 확정」 · 「brief 만 종료」", line: 63, claim: "③b 세 자리(63 분해안 승인 · 63 계속 고칠까요 · 319 확정 목록 재제시 상한).", decides: []}
  - {id: RC28 (RC153), path: "plugins/spec-distill/references/redecompose.md", anchor: "「이대로 다시 나눈다」 · 「고치기」 · 「그만둔다」", line: 55, claim: "③b 모델이 만든 새 분해 표를 승인받는다.", decides: []}
  - {id: RC29 (RC154), path: "plugins/spec-distill/references/conducting.md", anchor: "고른 흐름 · 이유 · 산출물을 보이고 `AskUserQuestion` 으로 승인받는다(거절이면 설계 흐름)", line: 35, claim: "③b 지휘자가 고른 흐름을 승인받는다(101 에도).", decides: []}
  - {id: RC30 (RC155), path: "plugins/spec-distill/references/trivia-escape.md", anchor: "판정은 모델이 했고, 건너뛸지는 사용자가 고른다.", line: 13, claim: "③b ① 과의 경계에 있다.", decides: []}
  - {id: RC31 (RC156), path: "plugins/spec-distill/skills/request-framing/SKILL.md", anchor: "앞 라운드의 답을 저자가 풀어 쓴 문장(이하 «풀이»)은 사용자가 **골라야** 확인이 됩니다.", line: 244, claim: "③b 풀이 확인. 추천을 언급한 문장은 없다.", decides: []}
  - {id: RC32 (RC157), path: "plugins/spec-distill/agents/relay-checker.md", anchor: "4. 「(권장)」 — skill 이 붙인 자리에만, 그 자리에 그대로 있는가 … 「문장 권장이 라벨 꼬리로 옮겨짐」", line: 32, claim: "추천 표시를 검사하는 리뷰어는 지금 이 agent 하나다. 실행 중 지휘자가 옮긴 기록만 본다.", decides: [OQ11, OQ12]}
  - {id: RC33 (RC158), path: "docs/superpowers/interview/2026-10-24-epic-parallel-recommend-interview.audit.md", anchor: "얼림 검사 자동 결정(4039a5a0#r3.1) 「그대로 둔다 (권장)」 · 추가 라운드 「열지 않음 (권장)」", line: 143, claim: "엔진 라벨과 reviewing-document.md 에는 「(권장)」이 없는데, 실행 중 모델이 붙였다. 정적 텍스트와 실제로 띄운 라벨이 갈린다는 실례다.", decides: [OQ12, OQ14]}
  - {id: RC34 (RC159), path: "plugins/quality-gates/tests/test_plain_qg_templates.sh", anchor: "assert_eq … \"한 번 더 돌기|지금 판정으로 끝내기|멈추기|\"", line: 165, claim: "라벨을 글자 그대로 잠그는 자리다. test_v_requirements.sh:220 · test_range_wiring.sh:165-166 · test_critiquing_artifacts_skill.sh:76,262 · test_skill_orchestration.py:79,120 도. 고른 라벨을 원문 그대로 기록하는 소비자는 quality-pipeline SKILL:944 · request-framing SKILL:805 · reviewing-document.md:39 · conducting.md:39. 전수 조사는 하지 않았다.", decides: [OQ14]}
unanswered: "③ 의 경계(③b 를 ③ 에 넣을지)와 RC130 이 계획 검토 · BLOCKED 질문에 닿는지는 레포 문구로 확정되지 않는다. OQ14 소비자 목록은 본 것만이다."
```
(모든 항목 touches: [] — 원문 그대로)

### R11 (이어서) — V1 확인 줄

- 확인 RC65–RC83 — 표본 확인: RC66 quality-pipeline/SKILL.md#시작 구성 표(382 표 머리) · RC67 review-criteria.md#리뷰 기준(1행) · RC79 audit-workflow.js#UX·디테일(424) · RC83 CLAUDE.md#버그가 리뷰를 탈출하면 — 주장과 일치. 나머지는 미확인(표본 밖)
- 확인 RC84–RC99 — 표본 확인: RC84 steelman.md#92 · RC86 conductor-dispatch.md#32 · RC89 proceed-gate.md#56 · RC93 conducting.md#40 — 앞 라운드에서 확인한 자리와 일치. 나머지 미확인
- 확인 RC100 — 확인 — pm-interview/SKILL.md#220 — 고른 라벨만 기록, 주장과 일치
- 확인 RC101 — 확인 — 2026-10-24-epic-parallel-recommend-interview.state.md#R10 — 그 라운드에 «지금 이해»와 «답» 뿐, 질문 절 없음 — 주장과 일치
- 확인 RC103 — 확인 — test_decompose_surface.sh#27 — 분해 판단 라벨 리터럴 잠금 — 주장과 일치
- 확인 RC102 · RC104–RC107 — 미확인(표본 밖)
- 확인 RC108 — 확인 — docreview_state.py#_CHOICE_LABEL(2135) — 주장과 일치
- 확인 RC109–RC125 — 미확인(표본 밖, 같은 조사의 RC108 확인)
- 확인 RC158 — 확인 — 2026-10-24-…-interview.audit.md#143 — 실행 중 「(권장)」을 모델이 붙인 기록 — 주장과 일치
- 확인 RC159 — 확인 — test_plain_qg_templates.sh#165 — 주장과 일치
- 확인 RC126–RC157 — 미확인(표본 밖. 앞 라운드에서 같은 자리 다수 확인)
- 웹(조사 10) — transcript 30일 삭제 · 연구 다섯 — 확인 못 함(2차 그대로)

## R12

### 지금 이해
[spec-distill] 포화 판정 1/5: 아직 — 빈 곳 5개, 다음: 라벨 문자열을 글자 그대로 비교하는 소비자와 락을 전부 훑는다 · 조사 호출 11/60
빈 곳 다섯을 조사했다(묶음 4). 바뀐 것: ① 추천 표시가 없는 질문 자리는 55곳 — 일부러 뺀 곳 3 · 근거 없이 빠진 곳 35 · 자기 산출물 처분 10 · 모델 제안을 승인받는 곳 7. ② 지금 어떤 PR 리뷰어도 추천 표시를 보지 않는다. SKILL · references 변경은 qg 리뷰 diff 에 들어가고, qg 리뷰 기준(review-criteria.md)은 모든 qg 리뷰어 · codex 가 함께 받는 자리다. plugin-audit 축 5(UX)는 명시 호출 때만 돈다. ③ 사후 표본 검사의 바탕 자료가 거의 없다 — 인터뷰 state 는 고른 라벨만, 지휘 relay 는 git 밖, transcript 는 30일 뒤 삭제. 실행 중 모델이 템플릿에 없는 「(권장)」을 붙인 기록도 있다(RC158). ④ 추천하는 쪽이 둘 이상인 자리는 3곳(steelman · 지휘자 옮김 · 게이트 둘째 질문), 출처 꼬리 문법은 steelman 에 이미 있다. ⑤ 라벨을 기계가 되읽는 곳은 없고, 꼬리를 바꾸면 깨지는 것은 문서 문면 락 열댓 개와 relay-checker · 지휘자 옮김 규칙이다(OQ14 목록 → 설계로).
→ intentional_exceptions 재개방: 모델 제안 승인 질문(③b)이 S9 «자기 처분» 범위인지 미정
조사 호출 11/60 · 이 라운드 본체 직접 1

### 다음 결정
OQ11: 리뷰어 자리 · 추천: qg 리뷰 기준 + plugin-audit 축 5(둘 다) · 트레이드오프: qg 기준 → 모든 PR 에서 잡지만 막는 지적은 아님(의도 출처에 적힐 때만) / 축 5 → 명시 감사 때만
OQ12: 「근거 부족」 남발 · 추천: 감시 장치 없이 한계 공시 · 트레이드오프: 공시 → 범주 바꿔치기 압력 없음, 남발은 못 잼 / state 에 질문 전문 기록 → 인터뷰만 잼, 자기 보고 한계
OQ13: 출처 꼬리 범위 · 추천: steelman 문법을 정본으로 올려 셋 자리에 씀 · 트레이드오프: 셋 → 지휘자 · 게이트 둘째 질문도 누가 권하는지 보임 / steelman 만 → 바꿀 곳 적음
OQ15: 모델 제안 승인 질문 · 추천: 추천을 단다(자기 처분과 다름) · 트레이드오프: 단다 → 분해 판단 같은 사고가 막힘 / 추천 없음 → 자기 승인 위험 줄지만 S3 사례가 바로 이 꼴

### 질문
(경로 b) OQ11 · OQ12 · OQ13 · OQ15 묶음.

### 답
→ S16 (OQ11 — 되물음) · S17 (OQ12 — 문구 없애기) · S18 (OQ13 — 되물음) · S19 (OQ15)

## R13

### 지금 이해
S19 로 모델 제안 승인 질문에도 추천을 단다 → intentional_exceptions 다시 닫힘(S19). 나머지 셋은 사용자가 되물었다 — 세 번 다 «장치를 더하지 말자»는 쪽이다.
→ enforcement_layer 재개방: S16 «필요한가?» 가 S13(리뷰어 수정)과 충돌
→ clarity_standard 재개방: S17 «「추천 없음 — 근거 부족」 억지로 적지 마, 없애» 가 S5(본문에 「추천 없음 — 이유」)와 충돌
→ skepticism 재개방: S18 «누가 추천 표시가 필요할까?» 가 S14(출처 꼬리도 표지로)와 충돌
본체 판단: ① 리뷰어 — 전수 검사가 매 테스트 실행마다 템플릿을 결정론으로 잡으므로 리뷰어 추가는 겹친다. CLAUDE.md 도 «더 잘 잡는 자리가 락이면 그것을 고치고 이유를 적는다»를 허용한다 → 빼기 권장. ② 「추천 없음」 — 사용자에게 보이는 문구는 없애고, 일부러 비운 이유는 skill 문서(검사가 읽는 자리)에만 둔다 → 검사는 여전히 빠뜨림과 일부러 비움을 가른다. ③ 출처 꼬리 — 추천하는 쪽이 실제로 갈리는 곳은 steelman 하나뿐 → 그 질문만 지금 꼴, 나머지는 「(권장)」 하나.
조사 호출 11/60 · 이 라운드 본체 직접 0

### 다음 결정
OQ11(이어감): 리뷰어 검사 · 추천: 빼기 — 전수 검사로 충분 · 트레이드오프: 빼기 → 장치 하나 덜, 문장으로만 적힌 질문은 검사 몫 / 넣기 → 겹침
OQ16: 추천이 없을 때 · 추천: 사용자에게는 표시 없음, 이유는 skill 문서에만 · 트레이드오프: 문서에만 → 화면이 깔끔하고 검사도 가름 / 전부 없앰 → 빠뜨림과 구별 못 함
OQ13(이어감): 출처 꼬리 · 추천: steelman 질문만 그대로 · 트레이드오프: steelman 만 → 갈리는 추천이 한 글자로 뭉개지지 않음 / 전부 (권장) → 가장 단순, steelman 의 두 추천이 같은 글자

### 질문
(경로 b) OQ11 · OQ16 · OQ13 묶음.

### 답
→ S20 (OQ11) · S21 (OQ16) · S22 (OQ13)

## R14

### 지금 이해
[spec-distill] 포화 판정 2/5: 아직 — 빈 곳 4개, 다음: OQ14 소비자 목록 22개 파일을 하나씩 열어 가른다 · 조사 호출 11/60
빈 곳 1(라벨 락 전수)과 4(«추천 없음 표시 없앰» + «감시 없음» 결합 점검)를 함께 띄웠다(묶음 5). 빈 곳 2 · 3 은 이미 정한 결정에 드는지 확인하는 일이라 본체가 직접 대조했다(조사 13).

### 조사 13 — orchestrator · R14 · 묶음 6

- 확인 RC110 — 확인 — plugins/spec-distill/agents/relay-checker.md#4. 「(권장)」 — 4번 · 35행이 「(권장)」 리터럴로 지휘자 권장을 금지 — 주장과 일치. 결정 대조: S4 · S9(지휘자 규칙 함께 고침 — 지휘자 권장도 라벨 (권장)) · S22(출처 꼬리는 steelman 에만)로 지휘자 쪽 출처 꼬리 자체가 생기지 않는다 → 꼬리 틈은 사라지고, relay-checker 4번 · 35행은 «skill 원문 (권장) 은 그대로 · 지휘자 추천도 (권장) 허용»으로 다시 쓴다(설계 몫) [RC110 → 없음]
- 확인 RC93 — 확인 — plugins/spec-distill/references/conducting.md#병렬 (권장) — 지휘자 질문의 라벨 (권장). 새 규칙(S4 · S9)에서는 충돌이 아니라 준수가 된다 [RC93 → 없음]
- 확인 RC95–RC97 — 확인 — multiSelect 세 자리 무표시 — S6 «권장이 여럿이면 여럿 모두»가 덮는다(정본 문장에 multiSelect 를 명시하는 것은 설계 몫) [RC95 → 없음]
- 확인 RC89 — 확인 — plugins/spec-distill/references/proceed-gate.md#둘째 질문 — 모델 제안에 꼬리 없음. S4(추천하면 라벨 (권장)) · S6(여럿 허용) · S22(출처 꼬리 없음)로 «모델이 권하면 그 제안에도 (권장)»이 된다 · 제안 이유를 «게이트 앞 글»에 두는 문장은 S9(도구 안에만)와 맞서 고칠 자리 [RC89 → 없음]

### 조사 12 — blind-spot-prober · R14 · 묶음 5

(빈 곳 4 — «표시 없앰» + «감시 없음» 결합. 임시 id → 인터뷰 번호: RC<n> → RC<n+159>, 곧 RC160–RC167)

```yaml
hidden_assumptions:
  - assumption: "꼬리가 없으면 아무 신호도 없다. 추천이 없는 질문은 화면에서 중립으로 읽힌다."
    why_risky: "꼬리 말고 위치도 신호다. pm-interview 는 '질문마다 첫 선택지가 추천'이라는 위치 규칙을 이미 갖고 있다. Claude Code 질문 도구도 추천을 맨 앞에 두고 '(Recommended)'를 붙이는 관행을 따른다는 보고가 있다. 그래서 추천이 없는 질문에서도 사용자는 첫 선택지를 추천으로 읽을 수 있다. 사용자는 '표시 없음'을 '첫 칸이 추천'으로 배워 왔다. 이 상태에서 표시를 없애면 신호가 사라지는 게 아니라 숨은 신호로 바뀐다."
    evidence:
      - {url: "https://www.surveypractice.org/article/3034", supports: current, claim: "닫힌 선택지에서는 앞에 놓인 선택지가 더 자주 골라지는 primacy 효과가 일반적으로 예상된다.", decides: []}
      - {url: "https://juejin.cn/post/7667440437863874560", supports: current, claim: "(비공식) AskUserQuestion 은 추천을 첫 선택지에 두고 라벨 끝에 '(Recommended)'를 단다.", decides: [OQ14]}
  - assumption: "정적 검사(질문 자리 전수 + 정본 문장)로 '추천 빠뜨림'과 '일부러 비움'을 가를 수 있다. 질문과 선택지가 skill 문서에 고정돼 있다는 가정이다."
    why_risky: "인터뷰 라운드 질문, 되묻기, 지휘자 질문은 실행 중에 모델이 선택지를 만든다. 정적 검사가 확인할 수 있는 것은 '추천을 달라'는 지시 문장이 그 자리에 있는지뿐이다. 화면 표시를 없앤 뒤 실행 중에 빠뜨리면 사용자 화면에서는 정상인 '추천 없음'과 똑같이 보인다. S3 의 사고가 다시 일어나도 이제는 겉보기에 정상인 상태가 된다."
    evidence:
      - {url: "https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/10580288", supports: current, claim: "경보 체계가 고장 나면 대개 그냥 조용해지므로 사람이 고장을 알아차리기 어렵다.", decides: []}
      - {url: "https://www.microsoft.com/en-us/haxtoolkit/pattern/g2-d-provide-low-performance-alerts/", supports: current, claim: "경보가 없다는 것 자체가 사용자에게 해가 될 수 있다.", decides: []}
  - assumption: "추천 표시는 정보만 더할 뿐 선택 분포를 바꾸지 않는다. 추천은 대체로 맞다."
    why_risky: "기본값과 추천 표시는 효과 크기가 크다. 틀린 의사결정 지원은 그대로 따르는 실수(commission error)를 늘린다. 이 위험을 재는 자리는 없다."
    evidence:
      - {url: "https://www.cambridge.org/core/product/1E6135ADFCBBC9AC9170DAEB3BBDA9DA", supports: current, claim: "기본값 연구 58편 메타분석에서 평균 효과는 d=0.68.", decides: []}
      - {url: "https://en.wikipedia.org/wiki/Automation_bias", supports: current, claim: "Goddard 등(2012): 틀린 의사결정 지원은 commission error 위험을 26% 늘린다.", decides: []}
      - {url: "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5356416/", supports: current, claim: "e-prescribing 시뮬레이션에서 틀린 지원은 omission error 를 24~33% 늘렸다.", decides: []}
  - assumption: "실행 중 흔적이 거의 없으니 과의존을 잴 데이터도 없다."
    why_risky: "지휘 기록의 spec 승인 줄에는 고른 라벨이 꼬리까지 그대로 커밋된다. 지금 있는 7건이 모두 '(권장)'을 골랐다. 이 7건만으로는 좋은 추천과 과의존을 가를 수 없다. 인터뷰 state 는 '고른 라벨과 요지'만 남겨 '추천 거절'과 '추천 없음'을 가를 수 없다."
    evidence: []
failure_modes:
  - {mode: "조용한 추천 누락. 실행 중 생성된 질문에서 모델이 꼬리를 빠뜨려도 사용자, relay-checker, 정적 검사 모두 이를 정상인 '추천 없음'으로 본다.", trigger: "선택지를 실행 중에 만드는 자리에서 문맥이 길거나 compact 직후라 정본 문장이 약하게 작동할 때. relay-checker 4번은 skill 원문과 띄운 질문이 같은지만 본다.", evidence: [{url: "https://ntrs.nasa.gov/api/citations/20170011323/downloads/20170011323.pdf", claim: "상업 항공 사고 46건 분석에서 위험이 아예 경보되지 않았거나 도움이 되지 않은 경우가 많았다."}]}
  - {mode: "추천 없는 질문에서 위치가 묵시적 추천이 된다. 사용자가 꼬리 없는 첫 선택지를 추천으로 오인해 고른다.", trigger: "S17/S21 로 추천 없는 질문이 생기는데 '첫 선택지 = 추천'이라는 위치 규칙(pm-interview SKILL 202행)이나 도구 관행이 그대로 남아 있을 때.", evidence: [{url: "https://research.google/pubs/how-the-order-of-response-options-in-a-running-tally-can-affect-online-survey-estimates/", claim: "온라인 설문에서 선택지 순서가 추정치를 바꾼다."}]}
  - {mode: "추천 꼬리 의무화가 기존의 과의존 장치와 충돌한다. pm-interview 의 '이유 없는 추천 수락이면 되묻기' 규칙은 꼬리가 모든 질문에 붙으면 라운드마다 터지거나 사문화된다.", trigger: "모든 질문에 (권장)을 달고, 사용자가 대부분 꼬리 붙은 라벨을 클릭만 할 때.", evidence: [{url: "https://www.microsoft.com/en-us/research/?p=854967", claim: "과의존 완화 전략이 오히려 과의존을 늘릴 수 있으니 실제 맥락에서 시험하라."}]}
  - {mode: "꼬리가 두 가지('(권장)'과 '(Recommended)')라서 한쪽만 아는 소비자가 다른 꼬리를 빠뜨림으로 오판하거나 놓친다.", trigger: "정적 검사의 regex, relay-checker 4번, 잠금 테스트가 한 꼬리만 리터럴로 비교할 때.", evidence: [{url: "https://openskillindex.com/skills/majiayu000-claude-skill-registry-cc-askuserquestion", claim: "(비공식) 커뮤니티 skill 예시는 영어 꼬리를 첫 선택지에 단다.", decides: [OQ14]}]}
confidence: 0.7
repo_claims:
  - {id: RC1 (RC160), path: "plugins/spec-distill/skills/pm-interview/SKILL.md", anchor: "질문마다 첫 선택지가 추천이고 그 라벨 끝에 `(권장)` 을 단다", line: 202, claim: "위치와 꼬리를 함께 추천 신호로 정해 두었다. 추천 없는 질문을 허용하면 위치 규칙이 남아 첫 선택지가 여전히 추천으로 읽힌다.", decides: []}
  - {id: RC2 (RC161), path: "plugins/spec-distill/skills/pm-interview/SKILL.md", anchor: "**되묻기** — 직전 답이 보류(«모르겠다/둘 다/아무거나»)·한 단어·이유 없는 추천 수락·근거 없는 단정이면", line: 206, claim: "실행 중 과의존 대응이 이미 하나 있다. 꼬리 의무화와의 관계가 정해져 있지 않다.", decides: []}
  - {id: RC3 (RC162), path: "plugins/spec-distill/agents/relay-checker.md", anchor: "4. 「(권장)」 — skill 이 붙인 자리에만, 그 자리에 그대로 있는가.", line: 32, claim: "충실도만 대조하고 존재는 보지 않는다. 문면은 「(권장)」만 적고 '(Recommended)'는 언급하지 않는다. 35행은 '모델 제안 승인 질문에도 추천' 방향과 정면으로 충돌한다.", decides: [OQ14]}
  - {id: RC4 (RC163), path: "plugins/spec-distill/scripts/conductor_ledger.py", anchor: "def approval_line(date: str, choice: str) -> str:", line: 259, claim: "spec 승인 줄 7건이 모두 '(권장)' 라벨이다(예: 2026-10-23-rules-docs-cleanup-design.md:683). 따름 비율 100% 지만 좋은 추천인지 과의존인지는 가를 수 없다.", decides: [OQ14]}
  - {id: RC5 (RC164), path: "plugins/spec-distill/scripts/roadmap_model.py", anchor: "def approval_date(doc_text: str):", line: 712, claim: "승인 줄은 날짜만 파싱하고 라벨 글자는 비교하지 않는다. 꼬리를 바꿔도 깨지지 않는다.", decides: [OQ14]}
  - {id: RC6 (RC165), path: "plugins/spec-distill/skills/pm-interview/SKILL.md", anchor: "source: verbatim         # verbatim(발화 그대로) | chosen(고른 선택지 라벨 + 요지)", line: 372, claim: "제시된 선택지 집합이나 어느 것이 추천이었는지는 남기지 않는다.", decides: []}
  - {id: RC7 (RC166), path: "plugins/project-init/tests/test_command_contract.py", anchor: "for label in (\"「AGENTS.md 로 옮기기 (권장)」\", \"「CLAUDE.md 에 바로 쓰기」\", \"「중단」\"):", line: 253, claim: "꼬리를 포함한 라벨을 리터럴로 단언한다. 꼬리를 바꾸면 함께 고쳐야 할 소비자다.", decides: [OQ14]}
  - {id: RC8 (RC167), path: "plugins/spec-distill/scripts/check_verbatim_coverage.py", anchor: "if not srcs or any(s and s != \"chosen\" for s in srcs):", line: 341, claim: "L3 는 source 필드만 보고 라벨 글자는 비교하지 않는다. 꼬리 변경에 둔감한 소비자다.", decides: [OQ14]}
```
(모든 항목 touches: [] — 원문 그대로)

### 조사 11 — repo-researcher · R14 · 묶음 5

(빈 곳 1 — 라벨 리터럴 락 전수. 임시 id → 인터뷰 번호: RC<n> → RC<n+167>, 곧 RC168–RC181)

원문 요약(그대로): 이 에이전트에는 Bash 가 없어서 `git grep -l` 을 돌리지 못했다. 같은 정규식을 Grep 도구(ripgrep)로 대신 돌렸다 — 결과는 하한이다. 정규식 `\(권장\)|\(Recommended\)|추천\)` — path=plugins 43개 파일 · 120건, path=shared 1개 파일. 테스트 · 스크립트로 좁히면 20개 파일, 전부 tests/ 이다. scripts/ 에서는 0개. 분류 — (가) 꼬리를 붙이면 깨지는 완전 일치 락 9개 파일 · 21건(test_ledger_wiring.sh 39 · 770 / test_end_gates.sh 40 · 41 · 44 · 47 / test_entry_guidance.sh 46 / test_interview_state_flow.sh 85 / test_parallel_recommend_docs.sh 62 · 65 · 158 / test_critiquing_artifacts_skill.sh 76 · 262 / test_command_contract.py 253 · 269 · 445 · 491 / test_skill_orchestration.py 79 · 120 / test_conducting_interview_stage.sh 119 · 825 부재 락). (나) 부분 문자열 락 3개 파일 · 3건(test_reviewing_brief_skill.sh 153 / test_request_framing_open.sh 102 / test_review_handoff_order.sh 176). (다) 데이터 픽스처 · 지난 기록 8개 파일 · 13건(test_spec_review_bundle.sh 42 · 102 / test_conductor_ledger.py 585 · 587 / test_roadmap_approval.py 24 / test_framing_review_contract.sh 286 · 289 / test_roadmap_write.sh 120 · 138 / test_seed_review_log.sh 62 · 73 / test_parallel_recommend_docs.sh 173 / fixtures/conductor-e2e/roadmap.md 31). 셋에 들지 않는 규칙 문장 락 7개 파일 · 19건(test_conducting_reference.sh 117 / test_end_gates.sh 33 · 45 / test_epic_conductor_skill.sh 73–76 / test_conductor_dispatch_reference.sh 26 · 30 · 31 · 32 / test_request_framing_open.sh 93 / test_conducting_interview_stage.sh 496 · 812 · 813 · 814 · 816 · 823 / test_review_handoff_order.sh 191).

```yaml
repo_claims:
  - {id: RC1 (RC168), path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md", anchor: "- **한 번 더 돌기** → 아래 펜스로 한 줄을 기록하고(출처 `label` · 원문은 고른 선택지 이름 「한 번 더 돌기」)", line: 944, claim: "기록 펜스는 고른 선택지 이름을 그대로 extra-iterations.md 에 붙인다. 상한 CAP 은 줄 수만 세므로 라벨 끝에 「(권장)」이 붙어도 상한 계산은 바뀌지 않는다. 원문 칸에 꼬리가 그대로 남는다.", decides: [OQ14]}
  - {id: RC2 (RC169), path: "plugins/quality-gates/tests/test_plain_qg_templates.sh", anchor: "assert_eq \"$(printf '%s\\n' \"$MXL\" | tr '\\n' '|')\" \"한 번 더 돌기|지금 판정으로 끝내기|멈추기|\"", line: 165, claim: "라벨 목록 전체를 등호로 비교한다. 꼬리를 붙이면 깨지는 (가) 락이고 (권장)이 없는 라벨을 잡는다. 형제: 같은 파일 55 · 66 · 167 · 168, test_range_wiring.sh 165–166, test_lowered_gate_wiring.sh 57–59, test_distortion_devices.sh 56–57, test_conducting_interview_stage.sh 122 · 181–183. 전수가 아니다.", decides: [OQ14]}
  - {id: RC3 (RC170), path: "plugins/quality-gates/tests/test_v_requirements.sh", anchor: "fill \"$fx\" 6 label '한 번 더 돌기'", line: 217, claim: "입력과 기대값이 같은 (다) 픽스처라 SKILL 라벨이 바뀌어도 깨지지 않는다.", decides: [OQ14]}
  - {id: RC4 (RC171), path: "plugins/spec-distill/skills/request-framing/SKILL.md", anchor: "사용자 문구는 게이트에서 사용자가 고른 선택지 라벨(«기타» 면 적은 말) 그대로다.", line: 805, claim: "「(권장)」 꼬리는 사용자 문구의 일부로 그대로 기록 · 전달될 뿐 막히거나 오판되지 않는다.", decides: [OQ14]}
  - {id: RC5 (RC172), path: "shared/docreview/scripts/docreview_state.py", anchor: "st[\"extra_rounds\"].append({\"round\": n, \"quote\": a.extra_approval, \"source\": a.extra_approval_source})", line: 1073, claim: "라벨 글자와 비교하는 코드는 없다. 엔진이 렌더하는 라벨에 꼬리를 붙이면 golden/*.gate.json 5개와 cases.sh 가 깨진다.", decides: [OQ14]}
  - {id: RC6 (RC173), path: "plugins/spec-distill/scripts/roadmap_model.py", anchor: "def approval_date(doc_text: str):", line: 702, claim: "꼬리가 붙은 선택지 원문은 그대로 기록되고 승인 판정에는 영향이 없다.", decides: [OQ14]}
  - {id: RC7 (RC174), path: "plugins/spec-distill/references/conducting.md", anchor: "「차례로」 확인: … 「차례로」 면", line: 41, claim: "병렬 답 줄을 파싱하는 스크립트는 없다. 「차례로」에 꼬리가 붙어 「차례로 (권장)」으로 기록되면 글자 그대로 비교하는 독해에서는 「차례로」 면 조건이 맞지 않는다. 그러면 남는 갈래가 기본(병렬) 보내기라 fail-open 방향이다.", decides: [OQ14]}
  - {id: RC8 (RC175), path: "plugins/spec-distill/agents/relay-checker.md", anchor: "3. 라벨 — 돌려줄 값(라벨)이 글자 그대로 같은가. 4. 「(권장)」 — skill 이 붙인 자리에만, 그 자리에 그대로 있는가.", line: 31, claim: "skill 원문 쪽에 꼬리가 새로 붙으면 지휘자도 그대로 옮겨야 일치가 된다.", decides: [OQ14]}
  - {id: RC9 (RC176), path: "plugins/spec-distill/references/conductor-dispatch.md", anchor: "지휘자 자신의 권장은 라벨 안 「(권장)」으로 넣지 않고 그 의견 줄에만 쓴다 — 지휘자가 만든 질문에서도 같다.", line: 32, claim: "RC177 병렬 질문과 충돌로 읽힐 수 있다.", decides: [OQ14]}
  - {id: RC10 (RC177), path: "plugins/spec-distill/references/conducting.md", anchor: "선택지는 「병렬 (권장)」(<B…> 의 계획이 끝나는 대로 구현 담당자를 보낸다", line: 40, claim: "지휘자 병렬 질문은 라벨 안에 「(권장)」을 단다. (가) 락이 잡는다.", decides: [OQ14]}
  - {id: RC11 (RC178), path: "plugins/spec-distill/tests/test_conducting_interview_stage.sh", anchor: "grep -qE '\\(Recommended\\)|\\(권장\\)' <<<\"$r3_minus_ban\"", line: 825, claim: "steelman 블록 부재 락. 이 게이트 라벨에 기본 권장 꼬리를 새로 붙이면 반드시 깨진다.", decides: [OQ14]}
  - {id: RC12 (RC179), path: "plugins/spec-distill/tests/test_ledger_wiring.sh", anchor: "grep -qF '「그만둠 (권장)」' \"$SR\" && grep -qF '「이어 씀 — 표지를 내 것으로 바꾼다」' \"$SR\"", line: 39, claim: "(가) 계열의 대표 사례다.", decides: [OQ14]}
  - {id: RC13 (RC180), path: "plugins/spec-distill/tests/test_review_handoff_order.sh", anchor: "for n in '`/compact` 후 다음 세션 줄' '(권장)' '턴 종료'; do assert_contains \"$r1\" \"$n\"", line: 176, claim: "(나) 사례다. 178행은 ② 행에 권장이 새로 붙으면 RED 가 나는 부재 락이다.", decides: [OQ14]}
  - {id: RC14 (RC181), path: "plugins/spec-distill/tests/test_conductor_ledger.py", anchor: "L.approval_line(\"2026-10-18\", \"① /compact 후 다음 세션 줄 (권장)\")", line: 585, claim: "(다) 사례다.", decides: [OQ14]}
unanswered: "git grep 을 직접 돌리지 못해 ripgrep 결과(하한)로 대신했다. (권장) 없는 라벨 리터럴 락은 `label: \"` grep 으로 걸린 것만 냈다."
```
(모든 항목 touches: [] — 원문 그대로)

V1(묶음 5): 
- 확인 RC160 — 확인 — pm-interview/SKILL.md#202 — 위치 규칙 실재
- 확인 RC163 — 미확인 — conductor_ledger.py#approval_line — «승인 줄 7건 모두 (권장)» 계수는 다시 세지 않음
- 확인 RC169 — 확인 — test_plain_qg_templates.sh#165 — 앞 라운드 확인과 같음
- 확인 RC161 · RC162 · RC164–RC168 · RC170–RC181 — 미확인(표본 밖, 다수는 앞 라운드에서 같은 자리 확인)
- 웹(조사 12) — 확인 못 함(2차 · 비공식 포함 그대로)

### 다음 결정
OQ17: 추천 위치 · 추천: 첫 자리 + 꼬리(도구 관례 그대로) · 트레이드오프: 첫 자리 → 모델 습관과 같아 단순, 추천 없는 질문의 첫 칸이 추천처럼 읽힐 위험은 남음 / 논리 순 + 꼬리만 → 위치 신호 없음, 정본과 모델 습관을 거스름
OQ18: 계속 · 마무리 · 추천: 마무리 — 남은 열린 질문은 설계 단계의 목록 작업(OQ14)뿐 · 트레이드오프: 마무리 → 포화 판정 전 사용자 종료로 기록 / 판정 한 번 더 → 조사 묶음이 더 돌 수 있음

### 질문
(경로 b) OQ17 · OQ18 묶음.

### 답
→ S23 (OQ17 · 과한 강제 장치 금지) · S24 (OQ18 — 마무리)

## R15

### 지금 이해
S24 로 마무리(사용자 종료 — 마지막 판정 아직). 분해 판단: 신호 — 따로 승인할 덩어리 3(규칙 정리 · 질문 자리 · 검사) · 파일 영역 5(shared · spec-distill · quality-gates · project-init · plugin-audit) · 사용자 원문 갈래 1. 권고는 하나로 충분. 이 질문부터 라벨에 (권장)을 달았다(S4 를 이 자리에 먼저 적용).
brief 에 실을 근거 중 범위 줄로만 확인했던 것을 낱낱이 다시 확인했다:
- 확인 RC67 — 확인 — plugins/quality-gates/references/review-criteria.md#리뷰 기준 — 1행 머리, 주장과 일치
- 확인 RC124 — 확인 — shared/tests/test_plain_language_block.sh#plain_language_block.py — 49행 호출, plain_language_block.py 51–52행 «블록 바이트가 정본과 다르다» — 주장과 일치
- 확인 RC126 — 확인 — shared/style/plain-language.md#추천은 「(권장)」으로 표시한다. — 주장과 일치
- 확인 RC146 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#낮춘 지적 — 711–716행 질문에 추천 표시 없음, 이 세션이 쓴 코드의 지적을 처분 — 주장과 일치
- 확인 RC161 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#되묻기 — 206행 «이유 없는 추천 수락» — 주장과 일치
- 확인 RC162 — 확인 — plugins/spec-distill/agents/relay-checker.md#4. 「(권장)」 — 32행 충실도만 대조 — 주장과 일치
- 확인 RC174 — 확인 — plugins/spec-distill/references/conducting.md#「차례로」 확인 — 41행 «「차례로」 면» 글자 조건 — 주장과 일치
- 확인 RC178 — 확인 — plugins/spec-distill/tests/test_conducting_interview_stage.sh#r3_minus_ban — 825행 부재 락 — 주장과 일치
- 확인 RC179 — 확인 — plugins/spec-distill/tests/test_ledger_wiring.sh#「그만둠 (권장)」 — 39행 닫는 꺾쇠까지 잡음 — 주장과 일치

### 다음 결정
분해 판단 · 추천: spec 하나로

### 답
→ S25
