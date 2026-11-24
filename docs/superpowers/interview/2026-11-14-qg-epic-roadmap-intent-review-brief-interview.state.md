---
type: interview-state
seed: docs/superpowers/interview/2026-11-14-qg-epic-roadmap-intent-review-interview.md
session_id: 2e569030-b34b-44df-b3cf-e6e82c81557f
phase: 1
coverage:
  floor:
    root_problem:   {status: closed, evidence: "S1 원문(「이게 진짜 의도가 맞는지 나에게 질문을 하는 … 리뷰어」) · S2(뿌리 = 고른 것을 의심할 자리 없음) · S3(알아챈 때: 구현 뒤 써 보고 · 로드맵을 다 끝내고 — 한참 뒤는 잘 모름)", reopened: 0, reopen_log: []}
    landscape:      {status: closed, evidence: "S4 — 외부 근거(조사 4) 처분: 의도 자체 이의 리뷰어 선례 없음, 실행은 /run · /verify 를 취함", reopened: 0, reopen_log: []}
    skepticism:     {status: closed, evidence: "S8 — ST1 steelman 판정 보완(refined)", reopened: 0, reopen_log: []}
    blind_spot:     {status: closed, evidence: "S15 · S16 — 2차 premortem(조사 7) 처분: 머지 뒤 잘못 골랐다는 새 일의 씨앗으로, 원문은 직접 쓴 말과 고른 라벨을 갈라 라벨도 의심", reopened: 1, reopen_log: [{round: 7, reason: "조사 7 — 머지 뒤 · 로드맵 끝엔 피벗 경로가 닫혀 있음(RC77 · RC78 · RC79), 원문 대부분이 모델 라벨(RC80)", conflicts_with: S8}]}
    open_questions: {status: closed, evidence: "S21 — 열린 질문 일곱 목록 확인(재개방 뒤 새 S)", reopened: 1, reopen_log: [{round: 8, reason: "S14 뒤 열린 질문 목록이 바뀜 — OQ15 · OQ19 해결, OQ23 추가, OQ12 는 S17 · S19 로 지휘자가 푸는 쪽", conflicts_with: S14}]}
  derived:
    - {name: internal_research, rationale: "R1 coverage-mapper 가 repo_claims 첫 산출 — 조사 행위가 함의", status: closed, evidence: "S8 — 레포 주장(RC1–44) 처분: ST1 보완이 레포 사실(원문 0건 · 24시간 GC · 피벗 경로)을 받아들임", reopened: 0, reopen_log: []}
    - {name: "돌려 보기의 주체와 방법", rationale: "qg 리뷰 agent 넷은 읽기 전용(RC1), 실행은 오케스트레이터(RC2) · e2e 는 승인한 명령만(RC4) · 표면은 웹 UI · API · CLI 셋(RC3) — devbrew skill 은 대화 세션 안에서만 써 볼 수 있고 질문하는 skill 은 헤드리스로 끝까지 못 감(RC14 · RC16 · 웹 E2)", status: closed, evidence: "S4 · S5 · S7 · S9", reopened: 0, reopen_log: []}
    - {name: "에픽 · 로드맵 이름을 리뷰 대상으로 푸는 길", rationale: "range 는 두 커밋 사이 하나(RC5), 로드맵 끝 호출은 남의 커밋까지 섞임(RC7), 머지 뒤 호출 없음(RC8), 이름 풀이 데이터는 spec-distill(RC9)인데 qg 는 그 스크립트를 못 부름(RC10)", status: closed, evidence: "S8 — 원문 · 묶음 · 에픽 블록은 부르는 쪽이 넘긴다(이름 풀이 주체는 OQ12 로 이월)", reopened: 0, reopen_log: []}
    - {name: "의도 출처 확장과 판정 축 · 질문 축의 경계", rationale: "의도는 지적을 올릴 수만 있는 정답(RC11), 재비판자는 하지 않은 일 요구를 낮춤(RC17) — 쓴소리는 판정 밖이어야 충돌을 비켜 감", status: closed, evidence: "S8 — 질문은 판정 밖, 원문은 부르는 쪽이 넘김", reopened: 0, reopen_log: []}
    - {name: "질문의 길과 답의 하류", rationale: "백그라운드엔 질문 도구 없음(RC18) · relay 파일 + 게이트 사이 별도 메시지(RC19 · RC20) · qg 결과는 24시간 뒤 지워짐(RC12) · 「내가 잘못 골랐다」 답의 피벗 경로(RC21) · 「맞다」 답의 재질문 방지", status: closed, evidence: "S8 · S12 — 질문 · 답은 docs 추적 파일, 잘못 골랐다는 spec-distill 피벗 경로, 리뷰 끝에 한 번에 / 지휘자는 게이트 사이", reopened: 0, reopen_log: []}
    - {name: "기존 비판 자리와의 겹침", rationale: "통합 리뷰어는 의도를 정답으로 놓고 로드맵 안 에픽만 봄(RC24) · 인터뷰의 steelman · premortem 은 구현 전(RC25) — 새 리뷰어 고유 몫을 가르기", status: closed, evidence: "S8 — 인터뷰의 steelman · premortem 의심을 입력으로 받아 구현 뒤 근거로 다시 묻는다", reopened: 0, reopen_log: []}
    - {name: "동시 작업을 아는 원천", rationale: "로드맵 밖 · 세션 밖 동시 작업을 아는 장치가 없음(RC24) · 옆 세션은 기계를 넘는 지휘자 소통을 만들려 함(RC22)", status: closed, evidence: "S11", reopened: 0, reopen_log: []}
    - {name: "옆 세션과의 순서 · 경계", rationale: "옆 seed 의 「지휘자 없이 도는 흐름 없음」(RC22) · INTENT.md · 관문 다섯 칸을 qg 에, 검수 두 번을 SDD 리뷰 + 머지 전 확인에 대응(RC23)", status: closed, evidence: "S20 — 본체 먼저, 입구는 옆 세션 설계에 맞춰(재개방 뒤 새 S)", reopened: 1, reopen_log: [{round: 8, reason: "S19 — qg 호출 전부가 지휘자 경유면 입구가 옆 세션의 지휘자 개편에 기댄다", conflicts_with: S10}]}
    - {name: "비용 · 맥락 상한", rationale: "qg 는 한 턴 · cost_class variable(RC26) — 에픽 · 로드맵 규모 탐색의 상한 · 멈출 조건", status: closed, evidence: "S6 · S13 — 근거 있을 때만 · 상한, 넓은 탐색은 규모 공시 + 승인이 상한", reopened: 0, reopen_log: []}
orchestration:
  focused_dimension: null
  research_dispatches: {coverage_mapper: 1, blind_spot_prober: 2, steelman_builder: 1, repo_researcher: 2, open_researcher: 2}
  research_limit: 60
  saturation_limit: 5
  research_log:
    - {n: 1, device: coverage-mapper, round: 1, batch: 1, changed: [], opened: [OQ1, OQ2], summary: "derived 10 제안(8로 묶어 admit) · RC1–26 · 웹 E1–E2 · seed 보다 넓어진 사실 다섯"}
    - {n: 2, device: orchestrator, round: 1, batch: 2, changed: [], opened: [], summary: "V1 확인 26건(전부 확인) · 웹 2건 확인 못 함"}
    - {n: 3, device: blind-spot-prober, round: 2, batch: 3, changed: [OQ3, OQ4, OQ5], opened: [OQ8, OQ9], summary: "숨은 가정 6 · 실패 양식 4 · RC27–31 — 모델 대리 써 보기의 한계 · 연출된 반대와 범람 · 모델 선택 실행의 주입면"}
    - {n: 4, device: open-researcher, round: 2, batch: 3, changed: [OQ3, OQ4, OQ5], opened: [OQ7], summary: "의도 자체에 이의를 거는 리뷰어 선례 없음 · 실행 확인은 /run · /verify · 평가자 직접 걷기 · 헤드리스 ①②③ 지금 사실 · SDK canUseTool 로 질문 skill 끝에서 끝 시험 가능 · RC32–36"}
    - {n: 5, device: steelman-builder, round: 3, batch: 4, changed: [OQ5], opened: [], summary: "ST1 — 전제 충돌 0 · builder refined · P2 쪼개기 · 빠진 전제(의심 대상이 손에 있음) · RC37–44"}
    - {n: 6, device: orchestrator, round: 7, batch: 5, changed: [OQ17], opened: [], summary: "웹 E1–E5 1차 확인 · 설치 CLI 2.1.323"}
    - {n: 7, device: blind-spot-prober, round: 7, batch: 5, changed: [OQ13, OQ14, OQ15, OQ18], opened: [OQ20, OQ21], summary: "보완안 premortem — 머지 뒤 피벗 막다른 길 · 원문은 모델 라벨 · 의심 목록이 닻 · 원장 충돌 · 단일 PR 입력 없음 · RC77–85"}
    - {n: 8, device: repo-researcher, round: 7, batch: 5, changed: [OQ12, OQ16], opened: [], summary: "이름 풀이 기계 출처 roadmap_status --json · qg 인자에 이름 · 의도 자리 없음 · 범위 끝 worktree 장치 있음 · RC57–76"}
    - {n: 9, device: repo-researcher, round: 7, batch: 5, changed: [OQ19], opened: [], summary: "옆 세션 R5 · 지휘자 없는 흐름 없음 확정 전제 · 과제 = 에픽 · qg 자리 · 검수 두 번 미정 · RC45–56"}
    - {n: 10, device: open-researcher, round: 7, batch: 5, changed: [OQ15], opened: [], summary: "답 재질문 방지 키 — 레포는 버킷 억제 기각 · 재상승 공시, 바깥은 근거 바뀌면 다시 · 단일 원장 충돌 · RC86–99"}
    - {n: 11, device: orchestrator, round: 10, batch: 6, changed: [], opened: [], summary: "PR #269 확인 — 설계문서 넷만 바뀜, conducting.md · redecompose.md 는 그대로"}
  saturation_log:
    - {k: 1, round: 6, verdict: not_saturated, basis: "최근 두 묶음(3 · 4) 모두 결정을 바꾸고 열었다", gaps: ["confirm/orchestrator: 조사 4 헤드리스 · SDK 웹 주장 1차 재확인 [OQ4 OQ7 OQ17]", "confirm/blind-spot-prober: ST1 보완안 premortem [OQ5 OQ12 OQ13 OQ15]", "explore/repo-researcher: 에픽 이름 풀이 명령 · qg 인자 표면 [OQ12 OQ13 OQ19]", "explore/repo-researcher: 기준선 · 사본 worktree 장치와 범위 모드 e2e 끔의 이유 [OQ16 OQ11]", "explore/open-researcher: 답 재질문 방지 키 선례 [OQ15]", "explore/orchestrator: 지금 CLI 판 · 헤드리스 재측정 [OQ17 OQ4]", "explore/repo-researcher: 옆 세션 최신 진행분 [OQ19 OQ6 OQ10 OQ12]"], user_choice: null}
    - {k: 2, round: 9, verdict: not_saturated, basis: "최근 두 묶음(4 · 5) 모두 결정을 바꾸고 열었다", gaps: ["confirm/repo-researcher: PR #269 뒤 로드맵 끝 수신처 [OQ20 OQ18]", "confirm/repo-researcher: 옆 세션 R5 다음 라운드 · qg 입구 처분 [OQ23 OQ22]", "confirm/steelman-builder: OQ15 조회 키 대 라벨 원문 [OQ15 OQ21]", "explore/orchestrator: 2.1.323 헤드리스 실측 [OQ17 OQ4]", "explore/orchestrator: 범위 끝 트리에서 e2e boot · fingerprint 실측 [OQ16]", "explore/repo-researcher: skill · 문서 PR 의 실행 근거 비율 [OQ14]", "explore/coverage-mapper: 두 갈래 파일 · 경계 지도 · 에픽 시작 커밋 규칙 [OQ13 OQ12]"], user_choice: S22}
  open_decisions:
    - {id: OQ1, text: "이 일이 먼저 풀어야 할 뿌리 문제는 무엇인가 — 에픽 · 로드맵 단위의 빈칸 · 고른 것 자체를 의심하는 자리의 부재 · 동시 작업의 갈라짐", dimension: root_problem, status: resolved, resolved_by: S2}
    - {id: OQ2, text: "「내가 잘못 골랐다」를 실제로 언제 알아챘나 — 새 리뷰어가 앉을 시점의 근거", dimension: root_problem, status: resolved, resolved_by: S3}
    - {id: OQ3, text: "쓴소리 리뷰어의 「돌려 보기」를 누가 하는가 — 오케스트레이터가 돌리고 리뷰어는 결과만 읽기 · 리뷰어에 실행 도구 · 사람이 걷기", dimension: "돌려 보기의 주체와 방법", status: resolved, resolved_by: S5}
    - {id: OQ4, text: "devbrew 처럼 산출물이 skill 인 대상에서 「써 보기」를 무엇으로 하는가", dimension: "돌려 보기의 주체와 방법", status: resolved, resolved_by: S9}
    - {id: OQ5, text: "쓴소리 질문을 언제 · 어디로 내고 답을 어디에 오래 남기는가", dimension: "질문의 길과 답의 하류", status: resolved, resolved_by: S12}
    - {id: OQ6, text: "옆 세션(팀 구조 개편)과 이 일의 순서", dimension: "옆 세션과의 순서 · 경계", status: resolved, resolved_by: S10}
    - {id: OQ7, text: "바깥 선례 처분 — 실행 확인은 Claude Code 의 /run · /verify 를 쓰고 쓴소리만 devbrew 가 맡을지", dimension: landscape, status: resolved, resolved_by: S4}
    - {id: OQ8, text: "쓴소리 질문의 양 — 근거 있을 때만 · 실행당 상한 · 매번 하나 이상", dimension: "질문의 길과 답의 하류", status: resolved, resolved_by: S6}
    - {id: OQ9, text: "모델이 고른 실행의 승인 경계 — 실행 전 사람 승인 유지 · 읽기 전용만 자동 · 자유", dimension: "돌려 보기의 주체와 방법", status: resolved, resolved_by: S7}
    - {id: OQ10, text: "동시에 도는 다른 세션 · 에픽 · 로드맵의 작업을 무엇으로 아는가", dimension: "동시 작업을 아는 원천", status: resolved, resolved_by: S11}
    - {id: OQ11, text: "에픽 · 로드맵 · 이름 호출의 넓은 탐색 비용 상한과 멈출 조건", dimension: "비용 · 맥락 상한", status: resolved, resolved_by: S13}
    - {id: OQ12, text: "이름으로 부른 에픽 · 로드맵을 커밋 · PR · 원문 묶음으로 푸는 주체 — 설치본 qg 는 spec-distill 스크립트를 못 부름(RC10)", dimension: open_questions, status: open, resolved_by: null}
    - {id: OQ13, text: "두 갈래(qg 의 에픽 · 로드맵 범위 / 쓴소리 리뷰어)를 한 일로 갈지 나눌지 — 종료 때 분해 판단", dimension: open_questions, status: open, resolved_by: null}
    - {id: OQ14, text: "PR 범위의 가벼운 쓴소리 기준 — 이미 있는 실행 근거와 원문이 어떻게 어긋나면 묻는가", dimension: open_questions, status: open, resolved_by: null}
    - {id: OQ15, text: "「맞다」로 답한 질문을 다음 실행이 다시 묻지 않게 하는 답 원장 조회 키", dimension: open_questions, status: resolved, resolved_by: S18}
    - {id: OQ16, text: "로드맵 끝 range 처럼 범위 끝 커밋과 체크아웃이 다를 때 넓은 탐색을 어디서 걷는가(RC27)", dimension: open_questions, status: open, resolved_by: null}
    - {id: OQ17, text: "헤드리스 동작의 판 차이 — 레포 기록 2.1.303 · 최신 2.1.323 · 레포 옛 실측(RC33 · RC35)과 지금 문서의 어긋남을 설계 전에 재측정", dimension: open_questions, status: open, resolved_by: null}
    - {id: OQ18, text: "「한참 뒤 다른 일 하다가」 알아챈 경우(S3 보류)를 위한 길이 필요한가", dimension: open_questions, status: open, resolved_by: null}
    - {id: OQ19, text: "옆 세션이 「지휘자 없이 도는 흐름 없음」을 확정하면 사용자 직접 호출 입구를 다시 볼지", dimension: open_questions, status: resolved, resolved_by: S17}
    - {id: OQ20, text: "에픽 머지 뒤 · 로드맵 끝에 「잘못 골랐다」로 답하면 그 답을 어디로 보내는가 — 재분해는 머지된 에픽을 거부(RC77)", dimension: blind_spot, status: resolved, resolved_by: S15}
    - {id: OQ21, text: "의심할 「사용자 원문」을 무엇으로 볼까 — 고른 (권장) 라벨과 직접 쓴 말(RC80)", dimension: blind_spot, status: resolved, resolved_by: S16}
    - {id: OQ22, text: "qg 호출 전부가 지휘자 경유(S19)일 때 옆 세션과의 순서 — 리뷰어 본체와 입구를 나눌지", dimension: "옆 세션과의 순서 · 경계", status: resolved, resolved_by: S20}
    - {id: OQ23, text: "지금의 qg 직접 호출(/quality-gates:quality-pipeline)을 없앨지 지휘자로 넘겨줄지 — 호출 이름 변경 · 제거는 major bump", dimension: open_questions, status: resolved, resolved_by: S28}
trivia_escape_armed: false
user_statements:
  - id: S2
    source: chosen
    round: 1
    text: "고른 것을 의심할 자리 없음 (권장) — 뿌리 문제는 사용자가 고른 것 자체를 의심할 자리가 없다는 것"
  - id: S3
    source: verbatim
    round: 1
    text: "1, 2이고 3은 잘 모르겠네"
  - id: S4
    source: chosen
    round: 2
    text: "/run · /verify 를 쓴다 (권장) — 실제로 돌려 보기는 Claude Code 의 /run · /verify 에 맡기고 devbrew 는 쓴소리만"
  - id: S5
    source: chosen
    round: 2
    text: "모델이 먼저, 사람 자리를 짚음 (권장) — 모델이 먼저 걷고 사람이 직접 써 봐야 알 자리를 질문과 함께 짚는다"
  - id: S6
    source: chosen
    round: 2
    text: "근거 있을 때만, 상한 둠 (권장) — 돌려 본 근거가 있는 쓴소리만, 실행당 상한, 없으면 없음이라고"
  - id: S7
    source: chosen
    round: 2
    text: "돌리기 전 사람 승인 (권장) — 모델이 고르고 사람이 승인한 뒤 돌린다"
  - id: S8
    source: chosen
    round: 3
    text: "보완 (builder·orchestrator 추천) — ST1: 입구는 qg, 사용자 원문은 부르는 쪽이 넘기고 질문 · 답은 docs 추적 파일에, 잘못 골랐다는 spec-distill 피벗 경로로, PR 은 가볍게 · 에픽/로드맵은 넓게, 인터뷰가 남긴 의심을 입력으로"
  - id: S9
    source: chosen
    round: 4
    text: "질문 전까지 모델, 그 뒤 사람 (권장) — skill 대상은 모델이 첫 질문까지 걷고 그다음부터는 사람이 직접 써 볼 자리로 짚는다"
  - id: S10
    source: chosen
    round: 4
    text: "이 일 먼저, 이음매만 열어 둠 (권장) — 옆 세션의 INTENT.md · 단계표가 오면 넘길 것만 바뀌게"
  - id: S11
    source: chosen
    round: 4
    text: "지금은 git, 채널 생기면 그것도 (권장) — 브랜치 · worktree · 열린 PR 을 읽고 못 본 것은 확인 못 함으로"
  - id: S12
    source: chosen
    round: 5
    text: "리뷰 끝에 한 번에 (권장) — 사람이 보는 세션은 리뷰 끝에 모아 묻고, 지휘자 자동 호출은 docs 파일에 쌓아 게이트 사이에"
  - id: S13
    source: chosen
    round: 5
    text: "규모 공시 + 승인이 상한 (권장) — 시작 전 몇 개를 걸을지 한 줄로 알리고 걷기마다 승인이 곧 상한"
  - id: S14
    source: chosen
    round: 6
    text: "맞다 (권장) — 설계로 넘길 열린 질문 OQ12–OQ19 여덟이 맞다"
  - id: S15
    source: chosen
    round: 7
    text: "새 일의 씨앗으로 (권장) — 에픽 머지 뒤 · 로드맵 끝의 잘못 골랐다 답은 다음 일의 출발점(seed 후보)으로 남기고 다음 세션 첫 턴을 안내"
  - id: S16
    source: chosen
    round: 7
    text: "갈라 보이고 라벨도 의심 (권장) — 직접 쓴 말과 고른 라벨을 나눠 보이고, 고른 라벨은 모델이 제안한 것으로 의심 대상에 넣는다"
  - id: S17
    source: chosen
    round: 7
    text: "지휘자 경유로만 — 이름으로 직접 부르기를 지휘자에게 이름을 대면 지휘자가 부른다로 바꾼다(seed 확인 문장을 뒤집음)"
  - id: S18
    source: chosen
    round: 7
    text: "답마다 파일, 근거 바뀌면 다시 (권장) — 답 하나에 파일 하나, 대상 커밋 · 실행 결과가 바뀌면 다시 묻고 조용히 지우지 않는다"
  - id: S19
    source: verbatim
    round: 8
    text: "2 devbrew내의 동작을 통일시켜서 갈라지지 않게 하고 싶어서야"
  - id: S20
    source: chosen
    round: 8
    text: "본체 먼저, 입구는 옆에 맞춰 (권장) — 쓴소리 리뷰어 본체는 지금, 지휘자 경유 입구는 옆 세션 설계가 정해지면 붙인다"
  - id: S21
    source: chosen
    round: 9
    text: "맞다 (권장) — 설계로 넘길 열린 질문 일곱(OQ12 · OQ13 · OQ14 · OQ16 · OQ17 · OQ18 · OQ23)이 맞다"
  - id: S22
    source: chosen
    round: 10
    text: "포화로 보고 마무리 (권장) — 반복 빈 곳(헤드리스 재측정)은 설계로 넘길 열린 질문, 남은 빈 곳도 설계 단계로"
  - id: S23
    source: verbatim
    round: 11
    text: "1, 2, 3 선택한거로 하자"
  - id: S24
    source: chosen
    round: 11
    text: "맞다 — R8 의 2 는 qg 호출 전부 경유(PR 하나를 포함해 qg 를 부르는 모든 길이 지휘자를 거친다)였다"
  - id: S25
    source: chosen
    round: 11
    text: "고친다 — 자동 호출 두 박자 (권장) — 첫 박자에 걸을 목록과 규모를 docs 파일에 남기고 게이트에서 승인하면 둘째 박자에 돌린 뒤 쓴소리한다"
  - id: S26
    source: chosen
    round: 11
    text: "고친다 — 커밋 키, 관찰 인용 시만 (권장) — 다시 묻는 키는 질문 정체 + 대상 커밋, 실행 결과는 근거로 붙이되 판단에 쓴 관찰이 달라졌다고 인용할 때만 다시 묻는다"
  - id: S27
    source: chosen
    round: 11
    text: "고친다 — qg 걷기, /verify 는 사람 자리 (권장) — 모델의 걷기는 qg 의 사람 승인 e2e 걷기(재 본 뒤의 /run 포함)로, /verify 는 사람이 직접 불러 볼 자리로"
  - id: S28
    source: chosen
    round: 11
    text: "고친다 — 이름 호출만 경유 — 통일은 지휘자가 늘 같은 qg 입구를 같은 입력으로 부르는 것, 로드맵 없는 PR 하나는 qg 를 바로 부르고 원문이 없으면 없다고 밝히며 에픽 · 로드맵 이름 호출만 지휘자를 거친다"
  - id: S29
    source: chosen
    round: 12
    text: "고친다 — Non-goal 빼고 추론 표시 (권장) — 리뷰어에게 실행 도구를 주지 않는다는 Non-goal 을 빼고 실행은 오케스트레이터 · 리뷰어 읽기 전용은 모델 추론으로 남긴다"
  - id: S30
    source: chosen
    round: 12
    text: "고친다 — 범위별 대상 (권장) — 다시 묻는 키의 대상은 에픽 · 로드맵은 끝 커밋, PR 하나는 리뷰한 트리의 해시로 하고 답 파일은 그 계산에서 뺀다"
  - id: S31
    source: chosen
    round: 12
    text: "고친다 — 호출 길마다 행선 (권장) — 지휘자를 거친 호출의 잘못 골랐다는 spec-distill 피벗 경로로, 로드맵 없는 PR 하나는 qg 가 docs 파일에 남기고 다음 할 일만 안내한다"
  - id: S32
    source: chosen
    round: 12
    text: "고친다 — 리뷰 끝난 뒤 다시 생성 (권장) — 로드맵과 에픽 묶음을 확정된 brief 로 다시 만든다"
  - id: S33
    source: chosen
    round: 13
    text: "고친다 — 먼저 걷고 나중에 대조 (권장) — 리뷰어는 의심 목록 없이 먼저 걷고 쓴소리 후보를 낸 뒤 인터뷰가 남긴 의심을 반증할 가설로 받아 대조한다, 비용이 상한을 넘으면 처음부터 넣되 반례를 찾게 한다"
  - id: S34
    source: chosen
    round: 13
    text: "열기 (권장) — 재리뷰 상한 뒤 추가 라운드 1회를 연다"
  - id: S35
    source: chosen
    round: 14
    text: "고친다 — 대상은 기록만 (권장) — 다시 묻는 키에 대상을 쓰지 않고 답에 기록만 하며, 판단에 쓴 관찰이 달라졌다고 인용할 때만 다시 묻는다"
confirm_repost_count: 0
decompose_edits: 0
brief_review_degradations:
  - component: critic
    reason: 번들 · 프로필을 프롬프트 내용 대신 작업 트리 임시 파일 경로로 실었다(분량 44KB) — 그 두 파일만 읽으라고 지시
    affected_axis: all
    verification_status: degraded
  - component: readback
    reason: 냉독에 payload 내용을 프롬프트 대신 작업 트리 임시 파일 경로로 실었다(분량) — 그 파일만 읽으라고 지시
    affected_axis: readback
    verification_status: degraded
  - component: readback
    reason: brief-readback 에 경로만 실어 보냈는데 그 agent 에 파일을 여는 도구가 없어 문서를 읽지 못했다 — 냉독 없음(gap 0 아님)
    affected_axis: readback
    verification_status: unavailable
---

## 풀린 입력

~~~~
---
type: interview-seed
next_phase: spec-distill:pm-interview
audit_file: 2026-11-14-qg-epic-roadmap-intent-review-interview.audit.md
---

qg 에 두 가지를 더하고 싶다. 하나는 에픽 단위와 로드맵 단위 리뷰이고, 다른 하나는 실제로 돌려 보며 탐색한 뒤 잘못된 방향이나 잘못된 것 같은 것, 의도가 갈라지는 것을 찾아 나에게 이게 정말 의도가 맞냐고 묻는 리뷰어다.

에픽·로드맵 리뷰는 사용자가 이름으로 직접 부를 수도 있고 지휘자가 에픽 머지 뒤와 로드맵 끝에 자동으로 부를 수도 있어야 한다. (사용자 확인) 지금 qg 는 에픽이나 로드맵을 이름으로 받지 못한다. 지휘자가 로드맵 끝에 범위 모드로 한 번 부르기는 하지만, 그때는 앱을 걷지 않고 의도 출처에 사용자가 처음 한 말이 들어가지 않는다.

새 리뷰어는 사용자 원문과 설계·에픽 묶음에 비춰 보되 그것을 정답으로 삼지 않고, 사용자의 선택 자체가 틀렸거나 빠뜨린 것까지 큰 방향·기능·동작에 걸쳐 쓴소리한다. (사용자 확인) 내가 잘못 골랐거나 놓쳤을 수 있기 때문이다. 지금 qg 리뷰어들은 의도 출처를 정답으로 놓고 그것을 어겼는지만 보므로, 의도 자체를 비판하는 자리가 없다. 내가 든 예는 잘못된 방향, 잘못된 것 같은 것, 의도가 갈라지는 것이다. 내가 목록을 늘어놓아 달라고 해서 Phase 0 이 문제를 잘못 고름, 더 단순한 길을 놓침, 들인 무게만큼 얻는 것이 없음, 내가 원한 것끼리 부딪침, 써 보면 당연히 필요한데 빠진 기능, 아무도 안 쓸 기능, 조용히 범위가 줄어듦, 모호한 말을 한쪽으로 읽고 굳힘, 앞 결정이 조용히 뒤집힘, 맞지 않는 기본값, 조용한 실패, 써 보면 생기는 마찰을 늘어놓았는데, 그 목록은 내가 하나하나 확인한 것이 아니다. 둘 다 느낌을 보여 주는 예시이지 닫힌 목록이 아니다.

리뷰어는 기능을 실제로 써 보거나 테스트·스크립트를 돌려 근거를 모으고, 무엇을 돌릴지는 대상에 맞춰 모델이 고른다. (사용자 확인) 새 리뷰어의 질문은 qg 판정을 바꾸지 않고, 질문과 사용자의 답은 따로 남는다. (사용자 확인) 새 쓴소리 리뷰어는 PR 하나를 포함한 지금 qg 의 모든 범위에서 돌고, 에픽·로드맵 단위에서는 더 넓게 본다. (사용자 확인)

옆 세션의 팀 구조 개편과 겹치는 자리는 이 일의 입력이고, 새 리뷰어도 리뷰할 때 동시에 도는 다른 세션·에픽·로드맵의 작업을 파악해 겹침과 갈라짐을 짚는다. (사용자 확인) 옆 세션은 feature/conductor-context-economy 브랜치에서 아직 seed 단계이고, seed 는 그 워크트리의 docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.md 에 있다. 그쪽은 파이프라인의 모든 단계가 지휘자를 거치게 하고, 과제마다 목표·지시 원문·하지 않을 것·결정 기록을 담는 INTENT.md 를 두고, 실제로 돌려 보거나 화면을 봐서 잘못되면 반려하는 검수 두 번과 단계표를 들이려 한다. 그 일과 이 일 중 무엇을 먼저 할지는 인터뷰가 겹치는 자리를 재고 정한다.

다시 검증할 것 — qg 리뷰어는 쓰기와 실행 도구를 가질 수 없는데 이 리뷰어는 실제로 돌려야 하므로, 누가 돌리고 리뷰어가 무엇을 읽는지는 정해지지 않았고 실행 격리를 크게 세웠다가 격리가 목적이 돼 폐기한 qg 의 전례가 있다는 것은 Phase 0 이 레포 기록에서 본 것이다. 헤드리스로 skill 을 불러 보는 길은 실패해도 성공으로 끝나고 Skill 도구를 못 쓴다는 기록이 있어, devbrew 에서 기능을 실제로 써 보는 방법은 따로 재야 한다. 지휘자가 자동으로 부를 때 질문이 어떻게 나에게 오는지, 질문을 리뷰 도중에 할지 결과로 남길지는 정하지 않았다. 지휘자의 통합 리뷰어가 이미 PR 마다 에픽 사이의 설계 의도 어긋남을 보고 있어 새 리뷰어와 겹치는 정도를 봐야 한다. 옆 세션의 내용은 아직 seed 라 바뀔 수 있다. 두 갈래를 한 일로 갈지 나눌지도 정하지 않았다.
~~~~

## seed 출처 분류

seed_provenance classify — audit: ok · user_confirmed 6 · user_unconfirmed 0 · author 18. «(사용자 확인)» 여섯 문장은 재확인 질문에서 제외한다.

## R1

### 지금 이해
seed 의 확인 여섯 문장은 그대로 두고, «다시 검증할 것» 의 레포 사실을 확인했다(경로 a). qg 리뷰 agent 는 전부 읽기 전용이고 실행은 오케스트레이터가 한다(RC1 · RC2). 로드맵 끝 qg 호출은 로드맵 시작 커밋부터 기본 브랜치까지라 그 사이 다른 로드맵 · 세션의 커밋까지 섞이고(RC7), 에픽 머지 뒤 qg 호출은 없다(RC8). 질문은 사람이 보는 지휘 세션에서만 직접 할 수 있다(RC18). qg 결과는 24시간 뒤 지워진다(RC12). 헤드리스 한계의 진짜 벽은 「Skill 불가」보다 「질문하는 skill 은 헤드리스로 끝까지 못 간다」 쪽이다(RC14 · 웹 E2 — 웹 주장은 본체가 1차 자료로 아직 확인 못 함). 옆 세션은 이제 seed 를 커밋하고 인터뷰 R1 에서 첫 질문을 기다리는 중이다(답한 것 없음). 경로: 이 라운드 질문은 (d) 뿌리 문제 · (b) 사례.
조사 호출 1/60 · 이 라운드 본체 직접 1
줄인 사실 21개

- 확인 RC1 — 확인 — plugins/quality-gates/agents/code-recritic.md#tools: Read, Grep, Glob — 주장과 일치(artifact-adversarial · artifact-critic · security-reviewer 도 6행 같은 값)
- 확인 RC2 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#You run both axes of the differential test yourself — 주장과 일치(68행)
- 확인 RC3 — 확인 — plugins/quality-gates/references/e2e.md#의도 출처에 없는 동작을 기대 상태로 만들지 않는다 — 주장과 일치(21행, 표면 12행)
- 확인 RC4 — 확인 — plugins/quality-gates/references/e2e.md#실행해도 된다는 승인이다 — 주장과 일치(54 · 57행)
- 확인 RC5 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#범위 모드는 고치고 다시 돌지 않고 — 주장과 일치(136행)
- 확인 RC6 — 확인 — plugins/quality-gates/scripts/#grep source_interview|interview|roadmap|로드맵 — 0 파일, 주장과 일치
- 확인 RC7 — 확인 — plugins/spec-distill/references/conducting.md#로드맵 시작 커밋부터 지금 기본 브랜치까지 — 주장과 일치(78 · 79행)
- 확인 RC8 — 확인 — plugins/spec-distill/references/conducting.md#### 6. 머지 뒤 · 부를 skill: 없음. — 주장과 일치(70–75행)
- 확인 RC9 — 확인 — plugins/spec-distill/scripts/roadmap_model.py#FIELDS = ( — 주장과 일치(234행)
- 확인 RC10 — 확인 — CLAUDE.md#설치본에서 다른 플러그인의 스크립트는 도달 불가다 — 주장과 일치(55행)
- 확인 RC11 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#it never lowers or skips a finding — 주장과 일치(195행, discover-spec.sh 4–7행 사슬)
- 확인 RC12 — 확인 — plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md#TTL(기본 24시간) — 주장과 일치(77행)
- 확인 RC13 — 확인 — docs/archive/specs/2026-08-01-qg-impact-driven-qa-runtime-design.md#전량 폐기 — 주장과 일치(57행, LD1 149행)
- 확인 RC14 — 확인 — docs/superpowers/specs/2026-10-09-skill-only-surface-design.md#allowedTools Skill — 주장과 일치(253 · 261행)
- 확인 RC15 — 확인 — docs/superpowers/specs/2026-09-10-spec-review-hook-removal-design.md#rc 0 으로 조용히 실패 — 주장과 일치(468행)
- 확인 RC16 — 확인 — docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md#사람 몫 — 주장과 일치(238행)
- 확인 RC17 — 확인 — plugins/quality-gates/agents/code-recritic.md#과잉 처방 — 주장과 일치(5–6행)
- 확인 RC18 — 확인 — plugins/spec-distill/references/conducting.md#백그라운드 agent 에는 질문 도구가 없다 — 주장과 일치(100행)
- 확인 RC19 — 확인 — plugins/spec-distill/references/conducting.md#--kind relay — 주장과 일치(28행)
- 확인 RC20 — 확인 — plugins/spec-distill/agents/relay-checker.md#You are NOT responsible for judging whether the user's choice — 주장과 일치(23행)
- 확인 RC21 — 확인 — CLAUDE.md#Sealed decision — 주장과 일치(95행)
- 확인 RC22 — 확인 — (옆 워크트리) docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.md#지휘자 없이 도는 흐름을 따로 두지 않는다 — 주장과 일치(13행, audit 124 · 155행 claude -p 일꾼)
- 확인 RC23 — 확인 — (옆 워크트리) docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.audit.md#QUALITY_GATES 5칸 — 주장과 일치(381 · 382행)
- 확인 RC24 — 확인 — plugins/spec-distill/agents/integration-reviewer.md#함께 진행된 에픽의 설계 의도 — 주장과 일치(54행, tools 13행 읽기 전용)
- 확인 RC25 — 확인 — plugins/spec-distill/agents/steelman-builder.md#strongest case for — 주장과 일치(31 · 45행)
- 확인 RC26 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#cost_class: variable — 주장과 일치(12 · 61행)
- 웹 E1 · E2 (code.claude.com/docs/en/headless) — 확인 못 함(본체 1차 확인 전)

### 다음 결정
OQ1: 이 일이 먼저 풀어야 할 뿌리 문제 · 추천: 고른 것 자체를 의심하는 자리가 없다 · 트레이드오프: 단위 빈칸이면 qg 범위 확장이 본체 / 의심 자리면 쓴소리 리뷰어가 본체이고 에픽 · 로드맵은 그 리뷰어가 넓게 보는 무대 / 갈라짐이면 동시 작업 원천이 본체
OQ2: 「잘못 골랐다」를 언제 알아챘나 · 추천: 없음 — 사용자 경험이라 추측할 근거 없음 · 트레이드오프: 써 보고면 구현 직후 걷기 / 로드맵 끝이면 로드맵 리뷰 / 한참 뒤면 기록 · 다시 열기 / 겪은 적 없으면 예방용

### 질문
Q1(d) 이 일이 먼저 풀어야 할 뿌리 문제는 무엇인가요? — 고른 것을 의심할 자리 없음 (권장) / 에픽·로드맵 단위의 빈칸 / 동시 작업끼리 갈라짐 / 셋이 같은 무게
Q2(b) 「내가 잘못 골랐다 / 놓쳤다」를 실제로 알아챈 적이 있다면, 주로 언제였나요? — 구현 뒤 써 보고 / 로드맵을 다 끝내고 / 한참 뒤 다른 일 하다가 / 아직 겪은 적은 없다

### 답
→ S2 (OQ1 해결)
→ S3 (OQ2 해결 — 3 은 약한 답: 「잘 모르겠네」 · §3 이월 후보)

## R2

### 지금 이해
바깥에서 요구 · 의도 «자체»에 이의를 거는 리뷰어 선례는 찾지 못했다 — 전부 «구현이 스펙을 이루는가»다(조사 4). 가장 가까운 셋: Claude Code 번들 /run · /verify(앱을 띄워 써 보고 잘 된 방법을 skill 로 남김), Anthropic 하니스 evaluator(평가자가 직접 앱을 사용자처럼 클릭), 공식 권장 «작업 전 인터뷰 → SPEC.md» + 「문제를 찾으라는 리뷰어는 늘 뭔가 찾는다」 경고. 숨은 가정 셋이 가장 크다(조사 3): ① 사용자가 알아챈 원천은 «직접 써 본 경험»(S3)인데 모델 대리 사용은 사람과 다르게 행동한다 ② 늘 쓴소리 + 모든 범위 + 판정 밖 채널은 연출된 반대 · 범람으로 채널이 죽는다 — 레포도 채널이 읽히는지 못 잰다(RC29) ③ 「모델이 고른 실행」은 qg 의 「사람 승인 명령만」 경계(RC31)와 부딪치고 범위에 남의 커밋이 섞이면 주입면이 생긴다. 헤드리스: -p 의 /skill-name 펼침 · permission_denials · dontAsk 의 질문 거부는 지금 공식 문서상 사실이고, Agent SDK canUseTool 로 정한 답을 넣어 질문하는 skill 을 끝까지 시험할 길이 있다 — 레포는 쓴 적 없음(RC34). 레포 기록 판 2.1.303, 최신 2.1.323. 웹 주장은 본체 1차 재확인 전 — 확인 못 함. S3 의 「3은 잘 모르겠네」 는 약한 답이나 1 · 2 는 분명해 되묻지 않고 §3 이월로 둔다(이유: 뿌리 차원은 S2 로 충분히 닫힘). 경로: 이 라운드 질문은 외부 근거 처분(landscape · blind_spot) — (b).
조사 호출 3/60 · 이 라운드 본체 직접 2
- 확인 RC27 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#범위 모드는 … 앱을 걷지 않고 — 주장과 일치(136행)
- 확인 RC28 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#PR 본문은 읽지 않는다 — 주장과 일치(168행, discover-spec.sh 0건)
- 확인 RC29 — 확인 — CLAUDE.md#그 채널이 실제로 읽히는지는 못 잰다 — 주장과 일치(66행)
- 확인 RC30 — 확인 — CLAUDE.md#git-ignored, plugin namespace — 주장과 일치(70행, 상태 파일 untracked)
- 확인 RC31 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#an optional human-approved e2e walk — 주장과 일치(8행)
- 확인 RC32 — 확인 — plugins/quality-gates/dependencies.md#| claude-code | 2.1.303 — 주장과 일치(17행)
- 확인 RC33 — 확인 — docs/superpowers/plans/2026-09-08-docreview-design-doc-site.md#존재하지 않는다 — 주장과 일치(1140행)
- 확인 RC34 — 확인 — docs/superpowers/specs/2026-08-05-agent-transparency-design.md#OQ-AA — 주장과 일치(1422행 「-p 에는 답변 채널이 없어」, canUseTool 0건)
- 확인 RC35 — 확인 — docs/superpowers/plans/2026-08-17-devbrew-weight-reduction.md#헤드리스 호출 규격 — 주장과 일치(66행)
- 확인 RC36 — 확인 — docs/superpowers/interview/2026-09-01-seam-and-adjudication-interview.audit.md#권한 게이트 — 주장과 일치(349행)

### 다음 결정
OQ7: 바깥 선례 처분 · 추천: /run · /verify 를 실행 수단으로 · 트레이드오프: 있는 것을 쓰면 가볍고 판을 따라감 / 직접 짜면 qg e2e 와 한 몸이지만 무게 / 참고만이면 결정 미룸
OQ3: 써 보기 주체 · 추천: 모델이 먼저 걷고 사람이 써 볼 자리를 짚음 · 트레이드오프: 모델만이면 사람 발견 재현 못 함 / 사람만이면 지금과 같음(손 확인)
OQ8: 질문 양 · 추천: 근거 있을 때만 · 실행당 상한 · 트레이드오프: 매번 의무면 연출된 반대 / 상한 없으면 범람
OQ9: 실행 승인 · 추천: 실행 전 사람 승인 유지 · 트레이드오프: 자동이면 빠르나 주입면 / 자유면 컨테이너 폐기 전례의 «사용자 통제 상실»

### 질문
Q1(b) 실행 수단 — /run · /verify 를 쓴다 (권장) / qg e2e 를 넓힌다 / 참고만 한다
Q2(b) 써 보는 쪽 — 모델이 먼저, 사람 자리를 짚음 (권장) / 모델만 / 사람만
Q3(b) 질문 양 — 근거 있을 때만, 상한 둠 (권장) / 매번 하나 이상 / 찾은 만큼
Q4(b) 실행 승인 — 돌리기 전 사람 승인 (권장) / 읽기만 하는 것은 자동 / 모델이 자유롭게

### 답
→ S4 (OQ7 해결 · landscape 닫힘)
→ S5 (OQ3 해결)
→ S6 (OQ8 해결)
→ S7 (OQ9 해결 · blind_spot 닫힘)

## R3

### 지금 이해
의심 trigger(landscape 모순 + 있는 것 먼저)로 steelman ST1 을 띄웠다(조사 5). 전제 충돌 0건 — 재검토 사유 없음. builder · orchestrator 모두 보완. builder 의 전제 목록 지적: P2 를 «입구»와 «입력 · 원장 · 하류»로 쪼갤 것, «의심 대상이 리뷰어 손에 있다»가 빠졌음, goal 의 정확한 뿌리는 «구현 뒤 · 돌려 본 근거로 · 기본으로 도는 의심 자리가 없다», P3 와 S3 의 강도 무게중심 차이. 경로: steelman 절차(skepticism).
조사 호출 4/60 · 이 라운드 본체 직접 1
- 확인 RC37 — 확인 — CLAUDE.md#의식적으로 기억하지 않아도 — 주장과 일치(6행)
- 확인 RC38 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#Skepticism 통과 — 주장과 일치(514 · 299행)
- 확인 RC39 — 확인 — plugins/quality-gates/scripts/discover-spec.sh#interview|brief|roadmap 0건 — 주장과 일치
- 확인 RC40 — 확인 — plugins/spec-distill/scripts/roadmap_model.py#FIELDS = ( — 주장과 일치(234행)
- 확인 RC41 — 확인 — plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md#TTL(기본 24시간) — 주장과 일치(77행)
- 확인 RC42 — 확인 — plugins/spec-distill/references/conducting.md#부를 skill — 주장과 일치(73 · 80행)
- 확인 RC43 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#is my PR ready to merge — 주장과 일치(6행)
- 확인 RC44 — 확인 — plugins/quality-gates/references/e2e.md#의도 출처에 없는 동작 — 주장과 일치(21행)

### 다음 결정
ST1: 쓴소리 자리를 qg 안 새 리뷰어로 · steelman 절차 질문(유지 / 보완 / 전환 / 보류 고정 순서)

### 질문
쓴소리 자리를 「qg 안의 새 리뷰어」로 두는 방향을 어떻게 할까요? — 유지 / 보완 (builder·orchestrator 추천) / 전환 / 보류

### 답
→ S8 (ST1 판정 보완 · skepticism 닫힘)

## R4

### 지금 이해
ST1 보완(S8)으로 형태가 정해졌다: 입구는 qg(모든 범위 · 지휘자 자동 호출 포함), 사용자 원문 · 묶음 · 에픽 블록은 부르는 쪽이 넘기고, 질문 · 답은 docs 추적 파일에, 「잘못 골랐다」는 spec-distill 피벗 경로로, PR 은 가볍게(이미 있는 실행 근거 × 원문) · 에픽 · 로드맵 · 이름 호출은 넓게(/run · /verify), 인터뷰가 남긴 의심을 입력으로. 남은 결정 셋은 서로 기대지 않아 한 호출에 묶는다 — skill 대상의 써 보기(OQ4), 옆 세션과의 순서(OQ6), 동시 작업을 아는 원천(OQ10). 옆 세션은 R1 에서 답한 것이 아직 없다(그쪽 state user_statements 비어 있음, 조사 시점). 경로: (b) 판단.
조사 호출 4/60 · 이 라운드 본체 직접 0

### 다음 결정
OQ4: skill 대상 써 보기 · 추천: 질문 전까지 모델, 질문부터는 사람 자리로 짚기 · 트레이드오프: SDK 로 끝까지면 새 의존(SDK) · 정한 답이 사람과 다름 / 사람 몫 그대로면 지금과 같음
OQ6: 옆 세션과의 순서 · 추천: 이 일 먼저, 옆 세션이 받을 이음매만 열어 둠 · 트레이드오프: 기다리면 옆 설계가 확정될 때까지 멈춤 / 한 로드맵이면 큰 일 하나로 무거워짐
OQ10: 동시 작업을 아는 원천 · 추천: 지금은 git(브랜치 · worktree · 열린 PR), 채널이 생기면 그것도 · 못 본 것은 「확인 못 함」 · 트레이드오프: git 만이면 미커밋 인터뷰가 안 보임 / 채널만 기다리면 지금은 아무것도 못 봄

### 질문
Q1(b) skill 써 보기 — 질문 전까지 모델, 그 뒤 사람 (권장) / SDK 로 끝까지 모델 / 사람 몫 그대로
Q2(b) 옆 세션 순서 — 이 일 먼저, 이음매만 열어 둠 (권장) / 옆 세션 설계를 기다린다 / 한 로드맵으로 묶는다
Q3(b) 동시 작업 — 지금은 git, 채널 생기면 그것도 (권장) / git 만 / 채널을 기다린다

### 답
→ S9 (OQ4 해결)
→ S10 (OQ6 해결)
→ S11 (OQ10 해결)

## R5

### 지금 이해
R4 답으로 skill 대상 써 보기(S9 — 질문 전까지 모델, 그 뒤 사람 자리), 순서(S10 — 이 일 먼저, 옆 세션이 받을 이음매만 열어 둠), 동시 작업 원천(S11 — 지금은 git, 채널 생기면 그것도, 못 본 것은 「확인 못 함」)이 정해졌다. 남은 둘: 질문을 언제 내는가(OQ5 의 시점 몫 — 자리 · 영속 · 하류는 S8 로 정해짐), 넓은 탐색의 비용 상한(OQ11). 레포 사실: 지휘 세션 밖 백그라운드에는 질문 도구가 없고 relay 파일 + 게이트 사이 별도 메시지가 기존 길이다(RC18 · RC19). CLAUDE.md 는 cost_class high 면 규모를 한 줄로 알리고 진행하라고 한다(지출 승인은 묻지 않음). 경로: (b) 판단.
조사 호출 4/60 · 이 라운드 본체 직접 0

### 다음 결정
OQ5: 질문을 내는 시점 · 추천: 사람이 보는 세션이면 리뷰 끝에 한 번에, 지휘자 자동 호출이면 docs 파일에 쌓아 게이트 사이에 · 트레이드오프: 도중에 묻기면 흐름이 끊김 / 늘 결과로만이면 대화형에서도 늦음
OQ11: 넓은 탐색의 비용 상한 · 추천: 시작 전 규모 공시 + 걷기 승인이 곧 상한 · 트레이드오프: 숫자 상한은 탐색을 자름 / 상한 없음은 무경계 루프 금지와 부딪침

### 질문
Q1(b) 질문 시점 — 리뷰 끝에 한 번에 (권장) / 찾는 즉시 / 늘 결과 파일로만
Q2(b) 탐색 상한 — 규모 공시 + 승인이 상한 (권장) / 숫자 상한도 둠 / 모델 판단에 맡김

### 답
→ S12 (OQ5 해결)
→ S13 (OQ11 해결)

## R6

### 지금 이해
R5 답으로 질문 시점(S12 — 리뷰 끝에 한 번에, 지휘자 자동 호출은 docs 파일에 쌓아 게이트 사이에)과 넓은 탐색 상한(S13 — 규모 공시 + 걷기 승인이 상한)이 정해졌다. 이로써 처음 연 결정 OQ1–OQ11 은 모두 해결됐다. 설계로 넘길 열린 질문을 OQ12–OQ19 로 모았다. 경로: (b) 목록 확인 — open_questions 닫기.
조사 호출 4/60 · 이 라운드 본체 직접 0

### 다음 결정
OQ12–OQ19 목록 확인 · 추천: 맞다 · 트레이드오프: 빠진 것이 있으면 더하고, 지금 정할 것이 있으면 그 OQ 를 연다

### 질문
Q1(b) 설계로 넘길 열린 질문 여덟이 맞나요? — 맞다 (권장) / 빠진 게 있다 / 지금 정할 게 있다

### 답
→ S14 (open_questions 닫힘)

## R7

### 지금 이해
포화 판정 1 의 빈 곳 일곱을 묶음 5 로 조사했다(조사 6–10). → blind_spot 재개방: 조사 7 이 보완안(S8)의 「잘못 골랐다는 spec-distill 피벗 경로로」와 충돌하는 코드 사실을 냈다 — 재분해는 머지된 에픽을 거부하고(RC77), 「인터뷰 다시 열기」는 구현 전 게이트에만 있으며(RC79), qg 세션엔 spec-distill 루트가 없다(RC78). 또 이 인터뷰의 사용자 발화 13 중 12 가 내가 쓴 (권장) 라벨이다(RC80) — 원문 대조가 거짓 확인을 낼 수 있다. 옆 세션은 R5 까지 왔고 「지휘자 없이 도는 흐름 없음」을 확정 전제로 다룬다(RC45) — 이 seed 의 「이름으로 직접 부를 수도」와 같은 사용자의 두 결정이 갈라진다. 이름 풀이: 에픽 → 브랜치 · 끝 커밋 · 묶음 · 발화 번호의 기계 출처는 roadmap_status.py --json 이고(RC60), qg 인자에는 이름 · 의도 묶음을 받는 자리가 없다(RC65 · RC66). 걷기 자리: qg 에 범위 끝 커밋의 일회용 worktree 장치가 이미 있다(RC69), 범위 모드가 걷기를 끈 이유는 체크아웃 차이 한 문장뿐(RC72). 답 원장 키: 레포는 버킷 동일로 자동 억제하는 안을 이미 기각했고 지우지 않고 「재상승」으로 공시한다(RC89), 바깥은 근거(코드 · 인용)가 바뀌면 다시 묻는 쪽이 많다(SonarQube · Copilot Memory). 여러 브랜치가 덧붙이는 단일 원장은 충돌한다(GitLab changelog 선례). 웹 E1–E5 는 본체가 1차로 확인했다(조사 6). 설치된 CLI 는 2.1.323(최신). 경로: 외부 근거 처분(blind_spot) + 판단(b).
조사 호출 8/60 · 이 라운드 본체 직접 1
- 확인 RC45–RC56 — 확인 — 옆 워크트리 seed 13행 · audit 107 · 276 · 368 · 382행 · state S4 · S7–S9 · S12 · S14 · OQ10 — 주장과 일치(조사 9)
- 확인 RC57–RC76 — 확인 — conductor_ledger.py 1193 · review_intents.py 174 · control_plane.py 1212 · roadmap_status.py 885 · roadmap_model.py 245 · roadmap_render.py 343 · integration-reviewer.md 16 · conducting.md 105 · setup-qg.sh 119 · discover-spec.sh 16 · qg-worktree.sh 12 · 38 · e2e.md 24 · e2e-state.sh 218 · merge_check.py 152 · quality-pipeline SKILL.md 136 · 138 — 주장과 일치(조사 8)
- 확인 RC77–RC85 — 확인 — redecompose.md 73 · 5 · spec-review SKILL.md 700 · source_interview · finishing.md path-inside · quality-pipeline SKILL.md docs/ 0건 · 274 · 이 상태 파일 user_statements — 주장과 일치(조사 7)
- 확인 RC86–RC99 — 확인 — docreview_route.py 242 · 942 · stopping-criterion-design.md 325 · synthesize_findings.py 309 · CHANGELOG 4023 · synthesize_artifact_findings.py 43 · 48 · docreview_state.py 1271 · 1555 — 주장과 일치(조사 10)

### 다음 결정
OQ20: 에픽 머지 뒤 · 로드맵 끝의 「잘못 골랐다」 답을 어디로 · 추천: 새 일의 씨앗으로 남기고 다음 세션 첫 턴을 안내 · 트레이드오프: 머지된 에픽 다시 열기는 재분해 확장(무거움) / 머지 직전으로 당기면 seed 확인 「에픽 머지 뒤」를 바꿈
OQ21: 의심할 「사용자 원문」 — 고른 라벨과 직접 쓴 말 · 추천: 갈라 보이고 고른 라벨은 「모델이 제안한 것」으로 의심 대상에 포함 · 트레이드오프: 같게 보면 거짓 확인 / 직접 쓴 말만이면 원문이 거의 비어 있음
OQ19: 옆 세션과 갈라진 입구 · 추천: 둘 다 산다(직접 호출은 리뷰 한 번이지 파이프라인 흐름이 아님) + 옆 세션에 갈라짐을 알림 · 트레이드오프: 지휘자 경유로만이면 seed 확인을 바꿈 / 미루면 설계가 입구를 모름
OQ15: 답 원장 · 키 · 무효 조건 · 추천: 답마다 파일 하나(브랜치 충돌 없음) · 키는 질문 정체 + 근거(대상 커밋 · 실행 결과), 근거가 바뀌면 다시 묻고 지우지 않는다 · 트레이드오프: 단일 원장 파일은 충돌 / 기억 안 함은 같은 질문 반복

### 질문
Q1(b) 잘못 골랐다 — 새 일의 씨앗으로 (권장) / 머지된 에픽도 다시 연다 / 머지 직전으로 당긴다
Q2(b) 원문 — 갈라 보이고 라벨도 의심 (권장) / 둘 다 원문으로 같게 / 직접 쓴 말만
Q3(b) 옆 세션 충돌 — 둘 다 산다, 옆에 알림 (권장) / 지휘자 경유로만 / 옆 설계 뒤에 정한다
Q4(b) 답 기억 — 답마다 파일, 근거 바뀌면 다시 (권장) / 한 원장 파일에 / 기억하지 않는다

### 답
→ S15 (OQ20 해결)
→ S16 (OQ21 해결 · blind_spot 다시 닫힘)
→ S17 (OQ19 해결 — seed 확인 문장 「사용자가 이름으로 직접 부를 수도 있고」를 뒤집음: 원래 = 이름으로 직접 · 지휘자 자동 둘 다 / 재결정 = 지휘자 경유로만 / 근거 = 옆 세션의 「지휘자 없이 도는 흐름 없음」과 같은 사용자의 두 결정이 갈라짐(RC45) — brief §5 기각 · §6 새 S 로)
→ S18 (OQ15 해결)
- 풀이 메모: S17 은 에픽 · 로드맵을 «이름으로» 부르는 입구에 대한 답이다. PR 하나에 qg 를 부르는 지금의 직접 호출까지 막는지는 묻지 않았다 — 다음 라운드에서 확인.

## R8

### 지금 이해
S17 의 범위를 되물었다(풀이 메모). 답 S19: 「2」 — PR 하나를 포함한 qg 호출 전부가 지휘자를 거친다, 이유는 devbrew 안 동작을 통일해 갈라지지 않게. → 옆 세션과의 순서 · 경계 재개방: S10(이 일 먼저, 이음매만)은 입구가 qg 직접 호출이라는 전제였다 — 이제 입구가 옆 세션이 개편 중인 지휘자 안에 있다. seed 확인 ⑤(PR 하나 포함 모든 범위)는 «범위»로는 유지되고 «입구»만 지휘자로 바뀐다. 지금 qg 직접 호출을 없애면 호출 이름 제거라 major bump(CLAUDE.md). 경로: 되묻기(b).
조사 호출 8/60 · 이 라운드 본체 직접 0

### 다음 결정
OQ22: 옆 세션과의 순서 · 추천: 리뷰어 본체(쓴소리 · 이름 풀이 · 답 파일 · 걷기)는 먼저, 지휘자 경유 입구는 옆 세션 설계에 맞춰 · 트레이드오프: 옆 먼저면 이 일이 멈춤 / 한 로드맵이면 무거움

### 질문
Q1(b) 순서 다시 — 본체 먼저, 입구는 옆에 맞춰 (권장) / 옆 세션 먼저 / 한 로드맵으로 묶는다

### 답
→ S20 (OQ22 해결 · 옆 세션과의 순서 · 경계 다시 닫힘)

## R9

### 지금 이해
열린 질문 목록이 S14 확인 뒤 바뀌어 open_questions 를 재개방했다. 해결: OQ15(S18) · OQ19(S17). 이름 풀이 주체(OQ12)는 S17 · S19 로 «지휘자가 roadmap_status --json(RC60) 같은 spec-distill 쪽 출처로 풀어 qg 에 넘긴다»로 좁혀졌다. 추가: OQ23(지금 qg 직접 호출을 없앨지 넘겨줄지). 경로: (b) 목록 확인.
조사 호출 8/60 · 이 라운드 본체 직접 0

### 다음 결정
열린 질문 목록 확인 · 추천: 맞다

### 질문
Q1(b) 설계로 넘길 열린 질문 일곱이 맞나요? — 맞다 (권장) / 빠진 게 있다 / 지금 정할 게 있다

### 답
→ S21 (open_questions 다시 닫힘)

## R10

### 지금 이해
포화 판정 2: 아직 — 빈 곳 7개. 반복 감지: 「explore/orchestrator: 헤드리스 실측 [OQ17 OQ4]」 가 판정 1 의 빈 곳과 may_change · device 가 같다. PR #269 빈 곳은 본체가 확인했다(조사 11 — RC77 · RC78 그대로). 남은 빈 곳은 설계로 넘길 열린 질문(OQ12–OQ16 · OQ23)의 실측 · 지도다. 경로: 반복 감지 질문.
조사 호출 8/60 · 이 라운드 본체 직접 1
- 확인 RC100 — 확인 — git show ac2782e4 — 설계문서 넷만 바뀜(조사 11)

### 다음 결정
반복 빈 곳 처분 · 추천: 포화로 보고 마무리

### 질문
Q1 조사를 더 할까요, 여기서 마무리할까요? — 포화로 보고 마무리 (권장) / 한 번 더 조사 / 인터뷰 종료

### 답
→ S22 (포화 — 반복 빈 곳)

## 분해안

| 번호 | 이름 | 종류 | 의도 | 범위 | 의존 | 브랜치 | 경로 예약 | 배정 번호 | 받는 것 | 넘기는 것 |
|---|---|---|---|---|---|---|---|---|---|---|
| R1 | intent-critic 리뷰어 본체 | 묶음 | qg 안에 사용자가 고른 것 자체를 의심하는 읽기 전용 리뷰어를 PR 범위부터 세운다 | 한다 리뷰어 agent · 입력 칸(직접 쓴 말과 고른 라벨을 갈라 보인 원문 · 묶음 · 인터뷰가 남긴 의심) · 근거 있을 때만 · 상한 · 판정 밖 질문 · 리뷰 끝에 한 번에 · 답마다 파일과 근거 키 / 안 한다 넓게 보기 · 지휘자 입구 · 이름 풀이 | 없음 | feature/qg-intent-critic | plugins/quality-gates/agents/, plugins/quality-gates/skills/quality-pipeline/ | C2 · C3 · C4 · C6 · C7 · C26 · D1 · D11 · D13 · D16 · D19 · D22 · OQ1 · OQ2 · OQ8 · OQ13 · OQ14 · OQ15 · OQ21 · RC1 · RC12 · RC17 · RC24 · RC25 · RC28 · RC29 · RC80 · RC81 · RC82 · RC84 · RC89 · RC94 · K2 · K3 · K4 · K5 · K7 · K8 · K10 · K11 · K15 · K16 · K17 · K19 · ST1 · S1 · S2 · S3 · S6 · S8 · S12 · S14 · S16 · S18 · S21 · S22 · S23 · S26 · S29 · S30 · S33 · S34 · S35 · «ask-less» · «bugbot-forum» · «claude-best-practices» · «claude-code-review» · «coderabbit-study» · «copilot-memory» · «devils-advocate» · «failing-falsify» · «gitlab-changelog» · «google-review» · «jakesch» · «sonarqube-match» | 없음 | 리뷰어 입력 칸 계약 · 답 파일 꼴 |
| R2 | 넓게 보는 조언자 | 묶음 | 에픽 · 로드맵 리뷰와 설계 단계에서 intent-critic 이 만들어진 것과 다른 팀의 계획을 읽어 사용자가 놓치거나 잘못 고른 것 · 팀 사이의 갈라짐 · 조율 안 된 중복을 짚는다 | 한다 에픽 · 로드맵 리뷰와 의도 문서가 바뀐 변경에서 조언자 부르기 · 읽은 인용을 근거로 받고 스크립트가 확인 · 다른 팀 읽기(팀 지도 · 진행 중인 의도 문서 · 파일 겹침) · 근거의 종류 보이기 / 안 한다 걷기 · 실행 · 새 입구 · 팀 사이 조율 자체 | R1 | feature/qg-wide-walk | plugins/quality-gates/scripts/, plugins/quality-gates/agents/intent-critic.md, plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md | C5 · C8 · D9 · D10 · D12 · D14 · D15 · D17 · OQ3 · OQ4 · OQ7 · OQ9 · OQ10 · OQ11 · OQ16 · OQ17 · RC2 · RC13 · RC16 · RC30 · RC31 · RC35 · RC69 · RC72 · K1 · K6 · K9 · K12 · K13 · K18 · S1 · S4 · S5 · S7 · S9 · S11 · S13 · S27 · «anthropic-harness» · «claude-changelog» · «claude-headless» · «claude-skills-verify» · «gitinject» · «ms-cicd» · «plugin-evals» · «sdk-user-input» · «sim-users» | R1 의 리뷰어 입력 칸 계약 | 읽은 인용 · 다른 팀 기록의 꼴 · 근거의 종류 |
| R3 | 지휘자 경유 입구 | 묶음 | 에픽 · 로드맵 이름 호출을 지휘자 경유로 모으고 이름 풀이 · 자동 호출 · 질문 옮기기 · 「잘못 골랐다」의 행선(피벗 경로 · 새 일의 씨앗)을 잇는다 | 한다 지휘자의 에픽 · 로드맵 이름 풀이(roadmap_status --json) · spec 승인 앞과 에픽 머지 뒤와 로드맵 끝 자동 호출 · 게이트 사이 질문 옮기기 · 새 일의 씨앗 · 범위로 부른 리뷰가 바뀐 의도 문서를 따라가게 qg 한 곳 고치기 · 머지된 PR 의 범위 확인 · 로드맵 없는 PR 의 qg 직접 호출은 그대로 둔다 / 안 한다 걷기 · 실행(두 박자의 걷기 전제는 뺐다) · qg 가 돌려주는 꼴 자체(R5) · 머지된 에픽 다시 열기 · 옆 세션의 팀 구조 자체 | R1, R2, R5 | feature/conductor-qg-entry | plugins/spec-distill/references/conducting.md, plugins/spec-distill/skills/epic-conductor/, plugins/quality-gates/scripts/setup-qg.sh, plugins/quality-gates/scripts/intent_origin.py, plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md | C21 · C25 · D18 · D20 · D23 · D24 · OQ5 · OQ6 · OQ12 · OQ18 · OQ19 · OQ20 · OQ22 · OQ23 · RC7 · RC10 · RC18 · RC45 · RC51 · RC60 · RC77 · RC78 · K14 · S1 · S8 · S10 · S15 · S17 · S19 · S20 · S24 · S25 · S28 · S31 · S32 · «scrum-guide» | R1 의 리뷰어 입력 칸 계약 · R2 의 넓게 보기(에픽 · 로드맵 리뷰에서 나오는 질문 목록) · R5 의 돌려주는 꼴 계약 · 옆 로드맵 conductor-context-economy 의 「지휘 절차 개편」 설계(로드맵 밖 — 그 설계가 승인된 뒤 시작한다) | 없음 |
| R4 | qg 리뷰 전념 — 고치기 반복을 지휘 흐름으로 | 묶음 | qg 는 리뷰만 하고 스스로 고치는 반복을 걷어내 고칠 일을 지휘 흐름(구현 담당자 · 재분해)과 qg 를 부른 세션으로 넘기고, 지휘 중 qg 가 코드를 보는 때를 머지 앞으로 당겨 옆 세션의 지휘자 설계에 녹인다 | 한다 qg 고치기 반복 걷어내기 · 고칠 지적을 부른 쪽에 돌려주는 꼴 · 지휘 중 qg 리뷰를 머지 앞으로 당기기 · 막는 지적과 「잘못 골랐다」 를 그 에픽 안에서 고치게 구현 · 설계 길로 되돌리기 · 그 일로 다시 쓰는 지휘 절차 문서의 남은 가장자리 · qg 본문과 README 문장 다듬기 · 옆 세션 설계에 맞추기 / 안 한다 쓴소리 리뷰어 본체 · 옆 세션의 팀 구조 자체 · 리뷰 글의 꼴과 답 이어지기(R6) · 심은 글에 속지 않기와 공유 스위트 잠금(R7) · qg 의 답 기록과 다른 팀 읽기 뒤처리(R8) | R1, R3 | feature/qg-review-only | plugins/quality-gates/skills/quality-pipeline/, plugins/quality-gates/README.md, plugins/quality-gates/references/e2e.md, plugins/quality-gates/scripts/verdict.py, plugins/quality-gates/scripts/review-diff.sh, plugins/quality-gates/scripts/intent_critic.py, plugins/quality-gates/agents/, plugins/quality-gates/tests/, plugins/spec-distill/references/conducting.md, plugins/spec-distill/references/walk-table.md, plugins/spec-distill/skills/epic-conductor/, plugins/spec-distill/README.md, plugins/spec-distill/tests/, shared/tests/ | S1 · S19 · S20 | R1 의 리뷰어 입력 칸 계약 · R3 의 지휘자 경유 입구 · 옆 세션의 지휘자 설계(로드맵 밖) | 고치기 반복을 걷어낸 qg 본문 · 머지 앞 리뷰 자리 · R6 · R7 · R8 이 받는 뒤처리 항목 |
| R5 | intent-critic 돌려주는 꼴 계약 · qg 안쪽 뒤처리 | 묶음 | 부르는 쪽(지휘자 · 사람이 보는 세션)이 intent-critic 의 질문을 받아 옮길 수 있게 qg 가 돌려주는 꼴을 계약으로 굳히고 R1 · R2 가 미룬 qg 안쪽 가장자리를 닫는다 | 한다 돌려주는 꼴에 질문 글 · 관찰 · 상태 넷(답 기록 실패 · 답하지 않음 · 묻지 않음 가르기) 싣기 · 묻지 않은 질문과 다른 팀 기록 파일의 자리와 수명 정하기 · 하위 명령을 직접 부를 때 전역 스위치 읽기 · 답 입력 읽기 · 다른 팀 읽기 · 리뷰어 입력 묶음과 공시 · 문서 머리 읽기의 남은 가장자리 · 테스트 틈 / 안 한다 지휘 절차 파일 · 지휘자의 자동 호출과 질문 옮기기(R3) · qg 본문 흐름 고치기와 README 다듬기(R4) · 걷기 · 실행 | R1, R2 | feature/qg-return-contract | plugins/quality-gates/scripts/intent_critic.py, plugins/quality-gates/scripts/intent_answers.py, plugins/quality-gates/scripts/intent_origin.py, plugins/quality-gates/scripts/other_teams.py, plugins/quality-gates/agents/intent-critic.md, plugins/quality-gates/skills/quality-pipeline/references/ | S1 · S8 · S12 · S31 | R1 의 리뷰어 입력 칸 계약 · 답 파일 꼴 · R2 의 읽은 인용 · 다른 팀 기록의 꼴 | 돌려주는 꼴 계약(질문 글 · 상태 넷 · 읽을 세션 파일과 그 수명) |
| R6 | 읽히는 리뷰 글 · 답 이어지기 | 묶음 | 지휘 중 에픽마다 도는 qg 리뷰의 결과와 질문을 사용자가 한눈에 읽게 하고 한 번 한 답이 다음 리뷰로 이어지게 한다 | 한다 리뷰 결과 글과 질문 앞 글의 꼴(맥락 머리 · 질문 먼저 · 왜 묻나 한 줄 · 근거는 파일로)을 지휘자의 묻기와 qg 가 직접 묻는 틀에 맞추기 · 리뷰어의 「왜 묻나」 칸과 돌려주는 꼴 · 지휘자를 거친 답을 qg 에 입력으로 넘겨 근거가 같으면 다시 묻지 않기 · 지휘자의 리뷰 기록 파일이 다른 팀 근거로 섞이지 않게 하기 · R4 가 구현 뒤 넘긴 둘(합쳐지기 전 지적 목록을 qg 가 파일로 남기기 · 이름으로 청한 리뷰 뒤의 좁은 재리뷰 세기) / 안 한다 답 자리 · 직접 쓴 답 · 읽기 실패 문구 같은 남은 뒤처리와 리뷰가 낸 막는 지적(R8) · 심은 글에 속지 않기와 공유 스위트 잠금(R7) · qg 가 직접 내는 결과 보고의 꼴 · qg 본문 흐름(R4) | R4 | feature/qg-readable-review | plugins/quality-gates/scripts/intent_critic.py, plugins/quality-gates/scripts/intent_answers.py, plugins/quality-gates/scripts/other_teams.py, plugins/quality-gates/agents/intent-critic.md, plugins/quality-gates/skills/quality-pipeline/SKILL.md, plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md, plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md, plugins/quality-gates/scripts/setup-qg.sh, plugins/quality-gates/scripts/synthesize_findings.py, plugins/quality-gates/tests/, plugins/quality-gates/README.md, plugins/spec-distill/skills/epic-conductor/, plugins/spec-distill/scripts/qg_answered.py, plugins/spec-distill/tests/, plugins/spec-distill/README.md, plugins/spec-distill/dependencies.md | S1 · S11 · S18 · S26 · S35 | R1 의 답 파일 꼴 · R5 의 돌려주는 꼴 계약 · R4 의 머지 앞 리뷰 자리와 묻는 틀 | 돌려주는 꼴 3판(왜 묻나 · 전에 한 답) · 「이미 답한 것」 입력 계약 · R8 이 받는 뒤처리 항목 |
| R7 | qg 경계 굳히기 — 심은 글 · 공유 스위트 잠금 | 묶음 | 리뷰 대상에 심은 글이 qg 의 리뷰어 입력 · 게시 확인 · 기록 펜스를 속이지 못하게 하고, qg 의 테스트 실행이 공유 스위트 잠금을 지키며 맡지 못한 파일 때문에 인증 못 함으로 끝나지 않게 하고, R4 머지 뒤 리뷰가 qg 본문에 낸 막는 지적을 닫는다 | 한다 리뷰 대상 글이 리뷰어 입력의 칸 표지를 닫는 흉내 막기(판정에 드는 리뷰어와 문서 비평의 리뷰어를 포함한 모든 리뷰어의 칸) · 게시 한 번 검사가 심은 줄에 속지 않게 하기 · qg 의 테스트 실행이 다른 하위 agent 의 전체 스위트와 겹치지 않게 공유 스위트 잠금 지키기 · qg 기록 펜스가 옮기는 글이 고정 끝 표지를 흉내 내지 못하게 하기(고칠 목록 · 걷기 기록) · 테스트 선택이 맡지 못한 파일 때문에 인증 못 함이 되는 것(TestCase 글자 없는 unittest 클래스 · tests 폴더의 테스트 아닌 파일) · R4 머지 뒤 리뷰가 qg 본문에 낸 막는 지적(무효 걷기 게이트의 선택지 하나 · 고칠 목록 가르기의 테스트 · 옛 세션 파일 부재 락의 범위) · 합성기가 판정 계산 앞에 합쳐지기 전 목록을 쓰는 순서 / 안 한다 지휘 절차(R9) · qg 본문 흐름을 다시 짜기(R4) · 리뷰 글의 꼴과 답 이어지기(R6) · 답 기록과 다른 팀 읽기 뒤처리(R8) · 결과 파일 이름의 반복 번호 없애기 · 실행 격리 | R4, R6 | feature/qg-planted-text-suite-lock | plugins/quality-gates/skills/quality-pipeline/SKILL.md, plugins/quality-gates/skills/quality-pipeline/references/, plugins/quality-gates/references/e2e.md, plugins/quality-gates/scripts/build_codex_prompt.py, plugins/quality-gates/scripts/build_artifact_codex_prompt.py, plugins/quality-gates/skills/artifact-critique/, plugins/quality-gates/scripts/run-test-selection.sh, plugins/quality-gates/scripts/synthesize_findings.py, plugins/quality-gates/scripts/intent_origin.py, plugins/quality-gates/agents/, plugins/quality-gates/tests/, plugins/quality-gates/README.md, plugins/quality-gates/CHANGELOG.md, plugins/quality-gates/.claude-plugin/plugin.json, shared/test-selection/, shared/tests/, tools/adjudication/check_slots.py, plugins/spec-distill/scripts/suite_lock.py, plugins/spec-distill/CHANGELOG.md, plugins/spec-distill/.claude-plugin/plugin.json, plugins/quality-gates/scripts/setup-qg.sh, plugins/quality-gates/dependencies.md, shared/suite-lock/, plugins/spec-distill/skills/epic-conductor/references/qg-review.md, plugins/spec-distill/scripts/merge_check.py, plugins/spec-distill/tests/, plugins/spec-distill/README.md, plugins/spec-distill/dependencies.md | S1 · S29 | R1 의 리뷰어 입력 칸 계약 · R4 가 넘긴 뒤처리 항목 · R4 머지 뒤 리뷰의 qg 본문 쪽 막는 지적 · R6 이 넘긴 합성 순서 | 없음 |
| R8 | qg 답 기록 · 다른 팀 읽기 뒤처리와 리뷰가 낸 막는 지적 | 묶음 | 앞 에픽들이 미룬 qg 안쪽 가장자리 가운데 intent-critic 의 답 기록과 다른 팀 읽기에 닿는 것과 R1 · R2 리뷰가 낸 막는 지적을 닫는다 | 한다 정체가 틀린 머리 아래 직접 쓴 답 · 답 커밋 뒤 질문 기록 실패의 표시 · 올리지 않은 로컬 브랜치의 인용 · 시간 한도와 브랜치 목록 실패의 사유 문구 · R1 과 R2 리뷰가 낸 막는 지적(답 파일 라벨 칸 무력화 · 답 파일 읽기 상한 · 직접 쓴 답의 라벨 읽기 · 표지 없는 옛 원문 공시 · 머리를 못 읽은 문서 세기 · 다른 팀 문서 거부 사유 공시) · 테스트 품질 리뷰가 낸 테스트 틈 · 돌려주는 꼴에서 이미 「잘못 골랐다」 로 걸러진 질문만 있던 실행 가르기 · 넘겨받는 답 파일 경로의 빈칸 · 범위로 부른 리뷰의 의도 출처에서 리뷰 기록 파일 빼기 · 넘겨받은 답 열쇠의 제어 글자 · 스크립트가 내는 낱말 다듬기 / 안 한다 리뷰 글의 꼴과 답 이어지기(R6) · 심은 글에 속지 않기와 공유 스위트 잠금(R7) · 지휘 절차(R9) · 옆 로드맵의 과제 폴더 구조에 맞추기(답 자리 · INTENT.md 읽기 — 그 구조를 쓰는 로드맵이 생긴 뒤) · 쓴소리 리뷰어 본체 | R6 | feature/qg-answer-record-edges | plugins/quality-gates/scripts/intent_critic.py, plugins/quality-gates/scripts/intent_answers.py, plugins/quality-gates/scripts/intent_origin.py, plugins/quality-gates/scripts/other_teams.py, plugins/quality-gates/scripts/setup-qg.sh, plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md, plugins/quality-gates/tests/, plugins/quality-gates/README.md, plugins/quality-gates/CHANGELOG.md, plugins/quality-gates/.claude-plugin/plugin.json | S1 · S11 · S18 | R1 의 답 파일 꼴 · R2 의 다른 팀 기록의 꼴 · R5 의 돌려주는 꼴 계약 · R4 가 넘긴 뒤처리 항목 · R6 의 돌려주는 꼴 3판 · R6 이 넘긴 뒤처리 항목 가운데 qg 스크립트 쪽 | 없음 |
| R9 | 지휘 절차의 qg 리뷰 뒤처리 — 믿는 자리 · 다시 들어오기 · 답 넘기기 | 묶음 | 지휘자가 qg 리뷰를 보내고 돌려받는 절차에서 앞 에픽들과 R4 머지 뒤 리뷰가 남긴 가장자리를 닫는다 — 검사받는 쪽이 고칠 수 있는 자리를 믿지 않고, 끊긴 뒤 다시 들어와도 리뷰 없이 머지 준비로 가지 않게 한다 | 한다 머지 앞 qg 리뷰 한 번의 상태(범위 · 단계 · 막는 지적과 처리 · 물을 것 · 답)를 지휘자가 쥐는 파일 하나에 모으고 스크립트가 재리뷰 범위 · 머지 관문 · 다시 들어왔을 때 할 일을 답하게 하기(PR 본문과 team 형식의 펜스는 표시로만) · 좁은 재리뷰 범위와 지난 리뷰의 끝을 PR 본문에서 읽는 자리를 검사받는 쪽이 고쳐 재리뷰를 비우지 못하게 하기 · 넘겨받는 답 기록의 진위 · 머지 앞 리뷰가 실패하거나 셀 수 없이 끝났을 때 머지 준비로 가지 않게 하기 · 되돌린 뒤 다시 들어왔을 때의 재리뷰 범위와 재전송 허용분 · 보고 없이 다시 들어온 길의 가장자리(거른 「잘못 골랐다」 목록 · 보내기 전 끊김 · 판정 절 없는 결과의 사유 문장 · 이름으로 청한 리뷰의 호출 줄) · 머지 직전 승인 기록 다시 보이기 · 답 넘기기 스크립트의 읽기 가장자리(읽지 못한 기록 · 새 답 없이 앞 답 빠짐 · 여러 줄 답 · 같은 날 같은 이름의 기록 파일 · 되풀이되는 알림을 푸는 길) · 여러 줄 지적 원문을 지휘 기록에 올리기 · 머지 관문과 team 형식 문장의 락 · 두 플러그인이 함께 쓰는 낱말과 지휘자가 읽는 qg 파일 꼴을 묶는 락 / 안 한다 qg 스크립트와 qg 본문(R7 · R8) · 지휘 절차를 다시 짜기(옆 로드맵) · 쓴소리 리뷰어 본체 · 실행 격리 | R6 | feature/conductor-qg-review-edges | plugins/spec-distill/skills/epic-conductor/references/qg-review.md, plugins/spec-distill/references/conducting.md, plugins/spec-distill/scripts/qg_answered.py, plugins/spec-distill/scripts/conductor_ledger.py, plugins/spec-distill/tests/, plugins/spec-distill/README.md, plugins/spec-distill/CHANGELOG.md, plugins/spec-distill/.claude-plugin/plugin.json, plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md, plugins/spec-distill/scripts/qg_review_state.py, plugins/spec-distill/references/team-files.md, plugins/spec-distill/dependencies.md | S1 · S19 · S20 | R4 의 머지 앞 리뷰 자리 · R6 의 「이미 답한 것」 입력 계약과 돌려주는 꼴 3판 · R4 · R6 이 넘긴 뒤처리 항목 가운데 지휘 절차 쪽 · R4 머지 뒤 리뷰의 지휘 절차 쪽 막는 지적 | 없음 |

## 먼저 볼 것 — 레포 검증 중 seed 와 어긋나거나 seed 보다 넓어진 사실

1. **「로드맵 끝 qg 호출」의 범위가 로드맵만이 아니다.** conducting.md 걸음 7 은 「로드맵 시작 커밋부터 지금 기본 브랜치까지」를 범위 모드로 돌립니다. 그래서 그 사이에 머지된 다른 로드맵과 다른 세션의 커밋도 함께 리뷰됩니다(RC7). 에픽 하나도 여러 브랜치·PR 로 나뉘고 다른 에픽과 섞여 머지되므로 연속된 커밋 범위로는 따로 잘라 낼 수 없습니다.
2. **「에픽 머지 뒤 자동 호출」은 지금 아예 없다.** 걸음 6(머지 뒤)에는 qg 호출이 없습니다(RC8). seed 의 「지금 qg 는 이름으로 받지 못한다」는 맞습니다. qg 스크립트 전체에 roadmap·interview·source_interview 참조가 0건입니다(RC6).
3. **「헤드리스는 Skill 도구를 못 쓴다」는 조건부 사실이다.** 레포 실측(RC14)은 기본 권한 모드에서 Skill 호출이 승인 대상으로 거부된다는 것이고, `--allowedTools Skill` 을 주면 skill 진입은 돌았습니다. 다만 그 뒤 여러 줄 Bash 가 승인 없이 막혔습니다. 공식 문서는 지금 `-p` 프롬프트에 `/skill-name` 을 넣으면 펼쳐서 실행한다고 합니다. 한편 `AskUserQuestion` 은 `dontAsk` 에서 거부되고 `--permission-prompts none` 에서는 아예 빠집니다. 따라서 진짜 벽은 「Skill 불가」가 아니라 **질문하는 skill 은 헤드리스로 끝까지 못 걷는다**는 쪽입니다. 「조용한 실패」도 `stream-json` 의 `permission_denials` 로 잡을 수 있습니다(웹 주장 1·2).
4. **옆 세션이 같은 헤드리스 길을 고려 중이다.** 옆 세션 audit 의 D11(RC22)은 영상 방식의 담당자 실행 수단(배정 스크립트가 `claude -p` 로 일꾼을 띄움)을 적었고, 담당자를 무엇으로 돌릴지는 그쪽 인터뷰가 정합니다. 그쪽도 「검수 두 번 = 실제로 돌려 보거나 화면을 봐서 반려」를 지금의 SDD 과제 리뷰와 지휘자 머지 전 확인에 대응시켰습니다(RC23). 이 일의 「실제로 돌려 보는 리뷰어」와 실행 주체 문제가 겹칩니다.
5. **qg 결과 파일은 24시간 뒤 지워진다.** seed 는 「질문과 답은 따로 남는다」고 하는데, 지금 qg 상태(`result.md`)는 세션 단위이고 TTL GC(기본 24시간)가 지웁니다(RC12). 오래 남길 자리가 따로 필요합니다.

```yaml
derived_dimensions:
  - name: "실행 증거의 주체와 리뷰어가 읽는 것 (Law 2 분리 안에서 '돌려 보기')"
    rationale: "qg 의 리뷰 agent 넷은 모두 tools: Read, Grep, Glob 이고(RC1), 차등 테스트와 e2e 걷기는 오케스트레이터가 직접 돌린다(RC2). e2e 는 시나리오마다 사용자가 골라 승인한 명령만 실행한다(RC4). 새 리뷰어는 '실제로 돌려 근거를 모은다'가 요구라서, 누가 돌리고 리뷰어가 무엇을 읽는지가 첫 설계 축이다. 실행 격리를 크게 세웠다가 폐기한 전례가 레포 기록으로 있다(RC13) — 폐기 사유는 범용성과 사용자 통제 상실이고, 격리 자체는 목적이 아니었다."
  - name: "대상 표면별 '써 보기' 방법 (skill · 대화형 표면 포함)"
    rationale: "지금 e2e 표면은 웹 UI · API · CLI 셋뿐이고, 기대 상태는 의도 출처가 약속한 동작에서만 뽑는다(RC3). 그래서 '의도에 없는데 써 보면 당연히 필요한 것'은 구조상 만들 수 없다. devbrew 처럼 산출물이 skill 인 레포는 대화 세션 안에서 불려야 '써 보기'가 된다. 헤드리스 측정 기록(RC14 · RC15)과 공식 문서(웹 1 · 2)는 질문하는 skill 이 헤드리스로 끝까지 못 간다는 데서 만난다. '사람 몫 손 확인'으로 남긴 전례도 있다(RC16)."
  - name: "에픽 · 로드맵 → 리뷰 대상 해석 (이름 → 커밋 · PR · 의도 묶음)"
    rationale: "range 는 연속된 두 커밋 사이 하나뿐이다(RC5). 로드맵 끝 호출은 다른 작업까지 섞인 범위를 리뷰하고(RC7), 에픽 머지 뒤 호출은 없다(RC8). 에픽과 브랜치 · PR · 묶음 · 발화의 연결은 spec-distill 의 로드맵 모델이 쥐고 있다(RC9). 그런데 qg 는 다른 플러그인의 스크립트를 설치본에서 부를 수 없다(RC10). 누가 이름을 풀어 qg 에 넘길지가 이음매 담당 문제다."
  - name: "의도 출처의 확장과 '비판 대상으로서의 의도' — 판정 축과 질문 축의 분리"
    rationale: "지금 의도 출처는 Spec: 트레일러의 설계문서 → 커밋 + PR 본문이고, 범위 모드는 PR 본문도 안 읽는다(RC5 · RC11). 의도는 '변경이 하려던 것'으로 지적을 올릴 수는 있어도 내리지는 못하는 정답이다(RC11). code-recritic 은 '이 변경이 하지 않은 일을 하라는 과잉 처방'을 SUGGESTION 으로 낮춘다(RC17) — 새 리뷰어가 낼 '빠진 기능' 쓴소리와 정반대 방향이다. 사용자 원문은 로드맵 에픽 블록의 발화(S<n>)와 묶음으로 닿는다(RC9). 질문이 qg 판정을 바꾸지 않는다는 결정을 지키려면 두 축이 서로 새지 않는 경계가 필요하다."
  - name: "질문의 전달 · 시점 · 영속 (지휘자 경유 포함)"
    rationale: "백그라운드 agent 에는 질문 도구가 없다(RC18). 지휘자는 한 에픽의 설계 대화 중에 다른 에픽의 질문을 relay 파일에 적어 두었다가 게이트 사이에 따로 묻는다(RC19). 옮긴 질문은 relay-checker 가 원문과 대조한다(RC20). qg 결과는 24시간 GC 대상이다(RC12). 리뷰 도중 묻는지 결과로 남기는지, 남긴다면 어디에 얼마나 오래 남기는지가 갈린다."
  - name: "답의 하류 — '의도가 틀렸다'는 답의 피벗 경로와 재질문 방지"
    rationale: "CLAUDE.md 의 Sealed decision 은 하류에서 반증된 확정에 피벗 경로가 없는 것을 금지한다(RC21). 지금 로드맵 끝 지적은 '후속 PR 하나로', 남은 에픽 변경은 재분해로 간다(RC7 · RC8). 질문에 '아니다, 내가 잘못 골랐다'로 답하면 그 답이 어디로 흘러 무엇을 다시 열지, 그리고 '맞다'로 답한 것을 다음 실행이 다시 묻지 않을지(Law 3)가 seed 에 없다."
  - name: "기존 비판 자리와의 겹침 · 경계 (있는 것 먼저)"
    rationale: "통합 리뷰어는 PR 마다 일곱째 이음매로 함께 진행된 에픽의 설계 의도와 어긋남을 본다(RC24). 하지만 의도 자체는 정답으로 놓는다. 인터뷰 단계에는 사용자 전제를 반박하는 steelman-builder 와 premortem 을 하는 blind-spot-prober 가 이미 있다(RC25). 새 리뷰어의 고유 몫이 '구현 뒤 · 돌려 본 근거로 · 사용자의 선택 자체를' 묻는 데 있는지, 어디까지 겹치는지 재야 한다."
  - name: "동시 작업 인식의 원천 (다른 세션 · 에픽 · 로드맵)"
    rationale: "지금 동시 작업을 아는 장치는 로드맵 하나의 기계 상태와, 같은 로드맵 안에서 열린 에픽 diff 를 모으는 review-pack 뿐이다(RC24). 로드맵이나 세션을 넘는 원천은 없다. 옆 세션은 지휘자끼리 같은 기계를 전제하지 않는 소통 계약을 만들려 한다(RC22). 새 리뷰어의 '겹침 · 갈라짐 짚기'는 그 채널을 기다릴지, 스스로 git · worktree 에서 읽을지에 달렸다."
  - name: "옆 세션(conductor-context-economy)과의 순서 · 경계"
    rationale: "옆 seed 는 '지휘자 없이 도는 흐름을 따로 두지 않는다'고 한다(RC22). 이것은 '사용자가 이름으로 직접 부르기'와 PR 하나 범위의 단독 실행을 바꿀 수 있다. 과제마다 INTENT.md(목표 · 지시 원문 · 하지 않을 것 · 결정 기록)를 두면 사용자 원문이 담긴 새 의도 출처 후보가 생긴다. 그쪽 audit 은 관문 다섯 칸을 quality-gates 플러그인에, '검수 두 번'을 기존 SDD 리뷰와 머지 전 확인에 대응시켰다(RC23). 단계표가 qg 를 한 단계로 만들면 '자동으로 부르는 자리'도 그쪽이 정한다."
  - name: "비용 · 맥락 상한 (로드맵 규모 탐색)"
    rationale: "quality-pipeline 은 한 assistant 턴에서 도는 cost_class: variable 의 skill 이다(RC26). 에픽 · 로드맵 단위로 '더 넓게 보며 실제로 돌려 탐색'하면 한 턴 맥락과 비용이 커진다. CLAUDE.md 는 Unbounded autonomy(상한 없는 루프)와 선언 없는 fan-out 을 금지한다. 옆 세션의 주제 자체가 맥락 낭비라서 두 일이 같은 예산을 다툰다."
neglect_flag: false
neglected_dimensions: []
confidence: 0.75
evidence:
  - url: "https://code.claude.com/docs/en/headless"
    supports: alternative
    claim: "-p 모드에서 사용자가 부르는 skill 은 프롬프트에 /skill-name 을 넣으면 펼쳐져 실행된다. stream-json 출력은 거부를 permission_denied 메시지와 결과의 permission_denials 로 낸다 — 'Skill 을 못 쓴다 · 조용히 실패한다'는 레포 기록은 조건부이고, 실패를 감지할 길이 있다."
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/headless"
    supports: current
    claim: "dontAsk 모드에서 AskUserQuestion 은 허용 규칙이 맞아도 거부되고, --permission-prompts none 이면 AskUserQuestion 같은 사람 답이 필요한 도구가 아예 빠진다. 질문하는 skill(예: qg 의 e2e 질문 · Fix-loop 게이트)은 헤드리스로 끝까지 걸을 수 없다."
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
repo_claims:
  - id: RC1
    path: "plugins/quality-gates/agents/code-recritic.md"
    anchor: "tools: Read, Grep, Glob (artifact-adversarial.md · artifact-critic.md · security-reviewer.md 도 같음)"
    line: 14
    claim: "qg 의 리뷰 agent 넷이 모두 읽기 전용 allowlist 라서 쓰기도 실행(Bash)도 못 한다."
    touches: []
    decides: []
  - id: RC2
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "You run both axes of the differential test yourself, and you edit files only for the fixes the user approved"
    line: 68
    claim: "실행(차등 테스트 두 축)은 오케스트레이터가 하고 리뷰어는 결과를 읽는 꼴이 이미 정석이다."
    touches: []
    decides: []
  - id: RC3
    path: "plugins/quality-gates/references/e2e.md"
    anchor: "## 1. 시나리오 만들기 — 표면 `웹 UI` · `API` · `CLI` / 기대 상태는 의도 출처가 약속한 동작에서 뽑는다. 의도 출처에 없는 동작을 기대 상태로 만들지 않는다"
    line: 21
    claim: "e2e 표면은 세 가지뿐이고, 기대 상태가 의도 출처에 묶여 있어 '의도에 없지만 당연히 필요한 것'을 걷기로 찾는 구조가 아니다. 표면을 바꾸지 않은 변경(문서 · 내부 · 테스트만)은 시나리오를 만들지 않는다(23행)."
    touches: []
    decides: []
  - id: RC4
    path: "plugins/quality-gates/references/e2e.md"
    anchor: "고른 시나리오 하나하나가 그 시나리오의 부팅 명령 … 을 실행해도 된다는 승인이다"
    line: 54
    claim: "걷기는 사용자 승인 질문(AskUserQuestion, 추천 없음)을 거친 명령만 실행한다 — 사용자 통제 지점이 이미 있다."
    touches: []
    decides: []
  - id: RC5
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "범위 모드는 고치고 다시 돌지 않고([Fix-loop decision]), 앱을 걷지 않고([e2e]), PR 코멘트를 달지 않는다"
    line: 136
    claim: "범위 모드(range <시작>[..<끝>])는 두 커밋 사이 하나만 받고, 걷기 · 고침 반복 · 게시를 모두 건너뛴다. e2e 절도 '범위 모드라 앱을 걷지 않는다' 한 줄로 끝난다(1035–1036행)."
    touches: []
    decides: []
  - id: RC6
    path: "plugins/quality-gates/scripts/"
    anchor: "grep 'source_interview|interview|roadmap|로드맵' → 0 files"
    claim: "qg 스크립트 어디에도 로드맵 · 에픽 · 인터뷰 묶음을 읽는 자리가 없다 — 에픽 · 로드맵을 이름으로 받을 길과 사용자 원문을 의도로 실을 길이 둘 다 없다."
    touches: []
    decides: []
  - id: RC7
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### 7. 끝 — 품질 게이트(`/quality-gates:quality-pipeline`)를 한 번, 로드맵 시작 커밋부터 지금 기본 브랜치까지 돌린다 / 지적은 후속 PR 하나로"
    line: 78
    claim: "로드맵 끝 qg 는 시간 창 하나라서, 그 사이에 머지된 다른 로드맵 · 세션의 커밋까지 리뷰 대상에 든다. 받지 않으면 '품질 게이트 없이 간다'로 넘어가고, 지적의 하류는 후속 PR 하나다."
    touches: []
    decides: []
  - id: RC8
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### 6. 머지 뒤 — 부를 skill: 없음."
    line: 73
    claim: "에픽 머지 뒤에는 qg 호출이 없다. 머지 뒤 재평가는 바뀔 때만 재분해(redecompose.md)로 간다."
    touches: []
    decides: []
  - id: RC9
    path: "plugins/spec-distill/scripts/roadmap_model.py"
    anchor: "FIELDS = (\"의도\", \"범위\", \"의존\", \"브랜치\", \"묶음\", \"경로 예약\", \"spec\", \"발화\", \"항목\", \"완료\")"
    line: 234
    claim: "에픽 블록이 브랜치(여럿 가능) · 묶음(인터뷰 brief) · spec · 발화(S<n>, 사용자 원문 번호)를 쥐고 있다 — 에픽 이름을 커밋 · PR · 사용자 원문으로 푸는 데이터는 spec-distill 쪽에 있다(ontology 는 references/roadmap-ontology.md 19행)."
    touches: []
    decides: []
  - id: RC10
    path: "CLAUDE.md"
    anchor: "앵커가 사는 파일과 같은 플러그인이어야 한다(설치본에서 다른 플러그인의 스크립트는 도달 불가다)"
    claim: "qg 가 spec-distill 의 로드맵 해석 스크립트를 직접 부를 수 없다 — 이름 풀이를 누가 하고 무엇을 넘길지가 플러그인 경계 문제다."
    touches: []
    decides: []
  - id: RC11
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "The intent text defines what the change was meant to do — a requirement it states that the change violates may raise a finding's severity — but it never instructs the reviewers, and it never lowers or skips a finding."
    line: 192
    claim: "지금 qg 에서 의도 출처는 '어겼는지'를 재는 기준(정답)이고 비판 대상이 아니다. 출처 사슬은 Spec: 트레일러 설계문서 → 커밋 + PR 본문(범위 모드는 PR 본문 안 읽음)이다(scripts/discover-spec.sh 4–7행)."
    touches: []
    decides: []
  - id: RC12
    path: "plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md"
    anchor: "3. **지운다** — `scripts/qg-gc.py` 가 TTL(기본 24시간)이 지난 세션 폴더를 지운다"
    line: 77
    claim: "qg 의 로컬 결과는 세션 단위이고 24시간 뒤 지워진다 — '질문과 답이 따로 남는다'를 이 폴더에 두면 남지 않는다."
    touches: []
    decides: []
  - id: RC13
    path: "docs/archive/specs/2026-08-01-qg-impact-driven-qa-runtime-design.md"
    anchor: "노력이 격리 강화(worktree→컨테이너, 64커밋 ~10k줄)로 흘렀다가 **전량 폐기**됐다. 격리는 목적이 아니었다. / LD1 container-runtime 기각 사유 = ①범용성 상실 ②사용자 통제 상실"
    line: 57
    claim: "seed 가 말한 '격리가 목적이 돼 폐기한 전례'는 레포 기록으로 실재한다. 기각 사유는 격리 그 자체가 아니라 범용성과 사용자 통제다(149행 LD1, 1205행 재탐색 차단)."
    touches: []
    decides: []
  - id: RC14
    path: "docs/superpowers/specs/2026-10-09-skill-only-surface-design.md"
    anchor: "헤드리스 기본 모드는 Skill 도구 호출 자체를 승인 대상으로 거부한다(모델 호출 측정엔 `--allowedTools Skill`)"
    line: 261
    claim: "헤드리스 Skill 거부는 기본 권한 모드의 승인 거부다. --allowedTools Skill 로는 진입이 돌았지만, 이어지는 여러 줄 Bash 가 승인 없이 막혀 끝까지 못 갔다(253행 M1)."
    touches: []
    decides: []
  - id: RC15
    path: "docs/superpowers/specs/2026-09-10-spec-review-hook-removal-design.md"
    anchor: "헤드리스 `claude -p` 는 rc 0 으로 조용히 실패하는 모드가 기록돼 있다"
    line: 468
    claim: "헤드리스 실행의 rc 0 조용한 실패는 레포 기록이다. 같은 사실이 shared/entry/entry_preflight.py 6행(rc≠0 이면 헤드리스에서 0턴 rc=0)에도 있다."
    touches: []
    decides: []
  - id: RC16
    path: "docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md"
    anchor: "손 확인(Verification 5 — 설치본으로 실제 질문에 꼬리가 붙는지) | 헤드리스 실행은 Skill 도구를 거부한다 — 사람 몫"
    line: 238
    claim: "devbrew 는 skill 을 실제로 써 보는 확인을 지금까지 '사람 몫 손 확인'으로 넘겨 왔다 — '써 보기'의 기존 기본값이다."
    touches: []
    decides: []
  - id: RC17
    path: "plugins/quality-gates/agents/code-recritic.md"
    anchor: "이 변경이 하지 않은 일을 하라는 과잉 처방인지(lower → SUGGESTION + 근거)"
    line: 5
    claim: "재비판자는 '이 변경이 하지 않은 일'을 요구하는 지적을 낮춘다 — 새 리뷰어의 '빠진 기능 · 범위가 줄어듦' 쓴소리가 판정 축에 들어가면 이 규칙과 충돌한다. 질문 축을 판정 밖에 두는 결정이 이 충돌을 비켜 가는 자리다."
    touches: []
    decides: []
  - id: RC18
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "사람에게 묻는 단계 … 는 사람이 보는 세션에서 한 번에 한 에픽씩 … 한다 — 백그라운드 agent 에는 질문 도구가 없다"
    line: 100
    claim: "질문은 사람이 보는 지휘 세션에서만 직접 할 수 있다. 백그라운드에서 돈 리뷰어의 질문은 옮겨져야 한다."
    touches: []
    decides: []
  - id: RC19
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "다른 에픽의 소식 · 돌아온 질문 · 멈춤은 받은 원문을 `ledger resource-dir --roadmap <로드맵> --kind relay --name <에픽>` 폴더의 파일(`relay-<순번>.md`)에 적어 두기만 하고 … 따로 된 메시지로"
    line: 28
    claim: "지휘자가 자동으로 부른 리뷰의 질문이 사용자에게 가는 기존 길은 relay 파일 + 게이트 사이의 별도 메시지다. 설계 대화 도중에는 섞지 않는다."
    touches: []
    decides: []
  - id: RC20
    path: "plugins/spec-distill/agents/relay-checker.md"
    anchor: "You are NOT responsible for judging whether the user's choice was wise"
    line: 23
    claim: "옮긴 질문은 relay-checker(읽기 전용)가 선택지 수 · 순서 · 라벨 · (권장) 출처 · 답을 원문과 대조한다(dispatch 자리는 skills/epic-conductor/SKILL.md 190–200행). 새 리뷰어의 질문이 이 길을 타면 그 대조 대상이 된다."
    touches: []
    decides: []
  - id: RC21
    path: "CLAUDE.md"
    anchor: "**Sealed decision** — 앞 단계의 확정이 하류에서 반증됐는데 피벗 경로가 없는 것"
    claim: "'의도가 틀렸다'는 답이 나왔을 때 그 답이 앞 결정을 다시 여는 길이 있어야 한다는 것이 레포 원칙이다 — 새 리뷰어의 답 하류 설계가 이 원칙에 걸린다."
    touches: []
    decides: []
  - id: RC22
    path: "docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.md (conductor-context-economy 워크트리 · feature/conductor-context-economy)"
    anchor: "설계문서가 하나뿐인 작은 일도 지휘자를 거치고, 지휘자 없이 도는 흐름을 따로 두지 않는다. / 지휘자들은 다른 세션이나 다른 서버에 있을 수 있으므로, 지휘자끼리의 소통은 같은 기계를 전제하지 않는다."
    line: 13
    claim: "옆 seed 가 확정하려는 것이 이 일의 '이름으로 직접 부르기 · PR 단독 실행'과 '동시 작업 파악'의 전제를 바꾼다. 같은 seed 15행의 과제 파일(목표 · 지시 원문 · 하지 않을 것 · 결정 기록)은 사용자 원문을 담은 새 의도 출처 후보다. 그쪽 audit D11(360행)은 영상 방식의 담당자 실행 수단(배정 스크립트가 claude -p 로 일꾼을 띄움)을 적었고, 담당자를 무엇으로 돌릴지는 그쪽 인터뷰가 정한다(seed 21행) — 같은 헤드리스 한계에 닿는다."
    touches: []
    decides: []
  - id: RC23
    path: "docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.audit.md (conductor-context-economy 워크트리)"
    anchor: "| QUALITY_GATES 5칸(테스트 · 린트 · 화면 · 문서 · 보고) | quality-gates 플러그인 · 스위트 대조(merge_check) · 통합 리뷰 · AC 보고 |"
    line: 381
    claim: "옆 세션은 관문 다섯 칸을 quality-gates 에, '검수 두 번 + 한 줄 반려'를 기존 SDD 과제 리뷰 + 지휘자 머지 전 확인에 대응시켰다(382행). 새 리뷰어 · qg 자동 호출 자리와 같은 표면을 다시 짠다."
    touches: []
    decides: []
  - id: RC24
    path: "plugins/spec-distill/agents/integration-reviewer.md"
    anchor: "7. 함께 진행된 에픽의 설계 의도 — `intents` 의 Goals · Non-goals · 결정 기록 · 판정과 이 PR 이 어긋나거나 … 경로가 겹치지 않아도 본다."
    line: 54
    claim: "통합 리뷰어는 PR 마다 다른 에픽의 설계 의도와 어긋남을 보지만, 의도를 기준(정답)으로 놓고 같은 로드맵 안의 열린 에픽 diff · 설계문서만 받는다(conducting.md 60행 review-pack). 의도 자체 비판, 로드맵 밖 동시 작업, 실행 근거는 맡지 않는다 — 새 리뷰어와 겹치는 것은 '에픽 사이 의도 어긋남' 한 줄이다."
    touches: []
    decides: []
  - id: RC25
    path: "plugins/spec-distill/agents/steelman-builder.md"
    anchor: "You are responsible for writing the strongest case for the alternative *and* for the current direction against the same criterion (the user's goal), judging whether any evidence refutes a stated core premise"
    line: 45
    claim: "사용자의 방향 · 전제를 반박하는 장치는 인터뷰 단계에 이미 있다(steelman-builder, blind-spot-prober 의 premortem). 구현 뒤 · 실행 근거로 같은 일을 하는 자리는 없다 — '있는 것 먼저' 검토 대상이자 새 리뷰어의 고유 몫을 가르는 기준이다."
    touches: []
    decides: []
  - id: RC26
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "cost_class: variable / You run the **quality-gates pipeline** in one assistant turn."
    line: 12
    claim: "qg 는 한 턴 안에서 도는 가변 비용 skill 이다 — 에픽 · 로드맵 규모의 넓은 탐색을 같은 꼴에 얹으면 맥락 · 비용 상한을 따로 정해야 한다."
    touches: []
    decides: []
```

## seed 가 덜 다룬 것 (neglect 는 아님 — 아직 집중된 차원이 없음)

이번이 첫 dispatch 이고 focused_dimension 이 null 이라 neglect_flag 는 false 입니다. 다만 seed 자체가 거의 다루지 않은 차원은 위 derived 가운데 세 가지입니다.

- 답의 하류와 재질문 방지(RC21)
- 비용 · 맥락 상한(RC26)
- 질문 · 답을 오래 남길 자리(RC12)

R1 이후 인터뷰가 「실행 주체」나 「옆 세션 순서」 한쪽으로 쏠리면, 이 셋부터 방치 후보로 보면 됩니다.

## 확인하지 못한 것

- 옆 세션 인터뷰의 R1 진행분(state 파일)은 읽지 않았습니다. seed 와 audit 만 봤고, 그쪽 내용은 아직 바뀔 수 있습니다.
- 「헤드리스 claude -p 는 쓰기 거부에도 rc 0」의 실측 원본은 사용자 메모리 쪽 기록입니다. 레포에서는 RC15 의 서술만 확인했습니다.
- 공식 문서 기준으로 `/skill-name` 이 `-p` 에서 펼쳐지는지 이 레포의 CLI 판으로 다시 재지는 않았습니다(RC14 측정은 2026-10 의 격리 설치본).

Sources:
- [Run Claude Code programmatically (headless)](https://code.claude.com/docs/en/headless)

### 조사 2 — orchestrator · R1 · 묶음 2

- 확인 RC1 — 확인 — plugins/quality-gates/agents/code-recritic.md#tools: Read, Grep, Glob — 주장과 일치(artifact-adversarial · artifact-critic · security-reviewer 도 6행 같은 값)
- 확인 RC2 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#You run both axes of the differential test yourself — 주장과 일치(68행)
- 확인 RC3 — 확인 — plugins/quality-gates/references/e2e.md#의도 출처에 없는 동작을 기대 상태로 만들지 않는다 — 주장과 일치(21행, 표면 12행)
- 확인 RC4 — 확인 — plugins/quality-gates/references/e2e.md#실행해도 된다는 승인이다 — 주장과 일치(54 · 57행)
- 확인 RC5 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#범위 모드는 고치고 다시 돌지 않고 — 주장과 일치(136행)
- 확인 RC6 — 확인 — plugins/quality-gates/scripts/#grep source_interview|interview|roadmap|로드맵 — 0 파일, 주장과 일치
- 확인 RC7 — 확인 — plugins/spec-distill/references/conducting.md#로드맵 시작 커밋부터 지금 기본 브랜치까지 — 주장과 일치(78 · 79행)
- 확인 RC8 — 확인 — plugins/spec-distill/references/conducting.md#### 6. 머지 뒤 · 부를 skill: 없음. — 주장과 일치(70–75행)
- 확인 RC9 — 확인 — plugins/spec-distill/scripts/roadmap_model.py#FIELDS = ( — 주장과 일치(234행)
- 확인 RC10 — 확인 — CLAUDE.md#설치본에서 다른 플러그인의 스크립트는 도달 불가다 — 주장과 일치(55행)
- 확인 RC11 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#it never lowers or skips a finding — 주장과 일치(195행, discover-spec.sh 4–7행 사슬)
- 확인 RC12 — 확인 — plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md#TTL(기본 24시간) — 주장과 일치(77행)
- 확인 RC13 — 확인 — docs/archive/specs/2026-08-01-qg-impact-driven-qa-runtime-design.md#전량 폐기 — 주장과 일치(57행, LD1 149행)
- 확인 RC14 — 확인 — docs/superpowers/specs/2026-10-09-skill-only-surface-design.md#allowedTools Skill — 주장과 일치(253 · 261행)
- 확인 RC15 — 확인 — docs/superpowers/specs/2026-09-10-spec-review-hook-removal-design.md#rc 0 으로 조용히 실패 — 주장과 일치(468행)
- 확인 RC16 — 확인 — docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md#사람 몫 — 주장과 일치(238행)
- 확인 RC17 — 확인 — plugins/quality-gates/agents/code-recritic.md#과잉 처방 — 주장과 일치(5–6행)
- 확인 RC18 — 확인 — plugins/spec-distill/references/conducting.md#백그라운드 agent 에는 질문 도구가 없다 — 주장과 일치(100행)
- 확인 RC19 — 확인 — plugins/spec-distill/references/conducting.md#--kind relay — 주장과 일치(28행)
- 확인 RC20 — 확인 — plugins/spec-distill/agents/relay-checker.md#You are NOT responsible for judging whether the user's choice — 주장과 일치(23행)
- 확인 RC21 — 확인 — CLAUDE.md#Sealed decision — 주장과 일치(95행)
- 확인 RC22 — 확인 — (옆 워크트리) docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.md#지휘자 없이 도는 흐름을 따로 두지 않는다 — 주장과 일치(13행, audit 124 · 155행 claude -p 일꾼)
- 확인 RC23 — 확인 — (옆 워크트리) docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.audit.md#QUALITY_GATES 5칸 — 주장과 일치(381 · 382행)
- 확인 RC24 — 확인 — plugins/spec-distill/agents/integration-reviewer.md#함께 진행된 에픽의 설계 의도 — 주장과 일치(54행, tools 13행 읽기 전용)
- 확인 RC25 — 확인 — plugins/spec-distill/agents/steelman-builder.md#strongest case for — 주장과 일치(31 · 45행)
- 확인 RC26 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#cost_class: variable — 주장과 일치(12 · 61행)
- 웹 E1 · E2 (code.claude.com/docs/en/headless) — 확인 못 함(본체 1차 확인 전)
### 조사 3 — blind-spot-prober · R2 · 묶음 3

blind-spot-prober 결과 (blind_spot 첫 전이, 1회차). 웹 조사 9회, 레포 확인 grep·read 12회.

이미 state 의 derived 칸에 올라 있는 것은 다시 내지 않았다: 읽기 전용 리뷰어, relay, 24시간 GC, 재비판자 관문 E, 피벗 경로, 옆 세션 seed. 아래는 그 칸들에 없는 «숨은 가정»과 «실패 양식»만 담았다.

```yaml
hidden_assumptions:
  - assumption: "모델이 돌려 보면(써 보기) 사용자가 「잘못 골랐다」를 알아챈 순간(S3: 구현 뒤 직접 써 보고)을 재현할 수 있다"
    why_risky: "S3 의 발견 원천은 사용자 자신의 사용 경험이다. 모델이 대신 쓰면 다른 질문이 나온다(질문을 더 하고, 더 공손하고, 난이도별로 오차가 반대 방향이다). 리뷰어가 대는 근거가 설계문서·커밋·오케스트레이터 실행 결과뿐이면, 같은 파이프라인이 만든 산출물끼리의 내부 모순만 찾는다. 「선택 자체가 틀렸다」는 현실과 부딪쳐야 드러나는데 그 부분을 놓친다. 「써 보기」가 사람 몫이던 이유(헤드리스 한계)가 기술 제약에 그치지 않고 이 일의 핵심일 수 있다"
    evidence:
      - url: "https://arxiv.org/html/2601.17087v2"
        supports: current
        claim: "LLM 모의 사용자는 사람 사용자의 대리로 믿을 수 없다. 어려운 과제에선 성공률을 낮게, 중간 과제에선 높게 잡는 체계적 오차가 있고, 질문·공손함 같은 인공 행동이 끼어든다"
        touches: []
        decides: [OQ4, OQ3]
        source_kind: primary
        certainty: confirmed
      - url: "https://www.themoonlight.io/review/mind-the-sim2real-gap-in-user-simulation-for-agentic-tasks"
        supports: current
        claim: "실제 사용자 451명과 LLM 시뮬레이터 31종이 크게 다르게 행동했다. LLM 판정자는 상호작용 품질을 부풀려 매긴다"
        touches: []
        decides: [OQ4]
        source_kind: secondary
        certainty: uncertain
  - assumption: "역할로 배정한 「늘 쓴소리하는」 리뷰어가 진짜 반대 의견만큼 가치 있는 의심을 낸다"
    why_risky: "매 실행마다 쓴소리가 의무이면 근거가 약해도 반대 의견을 지어낸다. 연출된 반대는 오히려 처음 견해를 굳히는 쪽으로 작동한다는 실증이 있다. 실제 AI 리뷰 봇이 거절당한 주원인 중 하나도 「의도된 설계 선택을 무시하고 결함으로 지적」이었다. 이번 리뷰어는 바로 그 의도된 선택을 겨냥하는 리뷰어다"
    evidence:
      - url: "https://behavioralscientist.org/stop-playing-devils-advocate-and-other-advice-for-better-decision-making/"
        supports: current
        claim: "Nemeth 계열 연구: 진짜 소수 의견이 devil's advocate 세 형태 모두보다 나았다. 역할극 반대는 처음 견해를 강화하는 사고를 유도했다"
        touches: []
        decides: [OQ5]
        source_kind: secondary
        certainty: uncertain
      - url: "https://www.alphaxiv.org/abs/2607.03316v1"
        supports: current
        claim: "CodeRabbit 리뷰 31,073건 중 56.3% 가 거절됐다. 거절 원인은 오탐과 함께 「의도된 설계 선택을 무시함」이었다"
        touches: []
        decides: [OQ5]
        source_kind: primary
        certainty: confirmed
  - assumption: "판정을 바꾸지 않는(④) 질문 채널도 읽히고 답이 달린다"
    why_risky: "막는 힘이 없는 채널은 신호 대 잡음이 떨어지면 읽히지 않는다. ⑤처럼 PR 하나를 포함한 모든 범위에서 돌면 양이 PR 수에 비례해 늘고, 그 순간 에픽·로드맵 질문도 함께 묻힌다. 레포 장치는 채널 «이름»의 실재까지만 재고 실제로 읽히는지는 재지 못한다(RC-c)"
    evidence:
      - url: "https://arxiv.org/pdf/2502.06175"
        supports: current
        claim: "Dependabot 경고 피로: 비차단 경고가 쌓이면 무시된다는 문제 제기(포지션 페이퍼)"
        touches: []
        decides: [OQ5]
        source_kind: primary
        certainty: confirmed
      - url: "https://www.alphaxiv.org/abs/2607.03316v1"
        supports: current
        claim: "같은 연구가 거절될 공산이 큰 코멘트를 미리 걸러 잡음과 피로를 줄이자고 제안한다. 비차단 채널에도 거르는 단계가 필요하다는 근거다"
        touches: []
        decides: [OQ5]
        source_kind: primary
        certainty: confirmed
  - assumption: "범위가 넓을수록(로드맵 끝) 쓴소리의 가치가 크다"
    why_risky: "S3 에 따르면 사용자는 로드맵 끝에 이미 스스로 알아챘다. 그 자리의 리뷰어는 사용자 자신의 발견 시점과 겹친다. 그때는 결정이 매몰돼 답이 「다음 로드맵 입력」 말고 갈 곳이 없다. 에이전트 맥락에서 목표 명확화는 실행 초기를 지나면 가치가 거의 사라지고, 중반 이후 질문은 묻지 않는 것보다 나빴다는 측정이 있다(사람의 방향 결정에 대한 직접 증거는 아니다. 유비다)"
    evidence:
      - url: "https://chatpaper.com/paper/277580"
        supports: both
        claim: "Ask Early, Ask Late, Ask Right: 목표 명확화는 실행의 약 10% 뒤로 가치가 거의 사라졌고, 중반 이후의 명확화 질문은 묻지 않는 것보다 성능이 나빴다"
        touches: []
        decides: [OQ5]
        source_kind: secondary
        certainty: uncertain
  - assumption: "옆 세션·다른 에픽의 «진행 중» 작업을 리뷰어가 관찰할 수 있다(⑥)"
    why_risky: "진행 중인 작업은 다른 worktree 의 미커밋 변경이나 git-ignored 상태(.claude/<plugin>/)에 산다. 인터뷰 state 도 커밋 전엔 추적되지 않는다. 이 인터뷰의 state 파일부터 지금 untracked(??)다. git 이나 커밋으로 보는 리뷰어에게 겹침이 가장 위험한 «아직 인터뷰 중» 단계는 보이지 않는다. 결국 「겹침 없음」이라는 거짓 안심을 내게 된다(침묵과 0 이 구별되지 않는다)"
    evidence: []
    # 근거는 레포 사실뿐 — repo_claims RC-d 참조
  - assumption: "리뷰 시점에 「사용자 원문」이 qg 의 의도 사슬 안에 있다"
    why_risky: "qg 의도 출처를 푸는 discover-spec.sh 는 interview·brief·roadmap 을 전혀 참조하지 않는다(grep 0건). 범위 모드는 PR 본문도 읽지 않는다. 그러면 사용자 원문 대신 그 원문을 인터뷰어가 압축한 설계문서를 기준으로 「사용자의 선택」을 의심하게 된다. 그 압축 과정에서 빠진 것(=놓친 것)은 바로 이 리뷰어가 찾아야 할 대상이다"
    evidence: []
    # 근거는 레포 사실뿐 — repo_claims RC-b 참조
failure_modes:
  - mode: "질문 범람 → 사용자가 「맞다」로 일괄 통과 → 채널이 사실상 죽는다"
    trigger: "⑤ 모든 qg 범위(PR 포함)에서 매번 돌고 질문 수에 상한이 없을 때. 에픽 여럿을 병렬로 돌리면 게이트 사이 relay 에 질문이 몰린다"
    evidence:
      - url: "https://www.opentrain.ai/papers/ask-less-ask-better-allocating-user-attention-in-proactive-llm-agents-with-inter--arxiv-2610.24411/"
        supports: current
        claim: "질문을 1~3개로 묶으면 사용자 주의 비용이 36~73% 줄고 과제 보상은 무제한 대비 86~94% 를 유지했다. 질문 수보다 선별이 중요하다"
        touches: []
        decides: [OQ5]
        source_kind: secondary
        certainty: uncertain
      - url: "https://chatpaper.com/paper/277580"
        supports: current
        claim: "비스크립트 300 세션에서 최적 창 안에 질문한 프런티어 모델이 없었다. 52% 세션은 과잉 질문이었다"
        touches: []
        decides: [OQ5]
        source_kind: secondary
        certainty: uncertain
  - mode: "아첨 접힘과 반복 재질문의 양극: 사용자가 「의도다」라고 답하면 리뷰어가 근거와 무관하게 물러서거나, 반대로 답이 남지 않아 다음 실행이 같은 질문을 다시 낸다"
    trigger: "답이 리뷰어 입력으로 돌아가는 고리가 없거나(24시간 GC), 돌아가더라도 답에 맞서 근거를 유지하라는 규칙이 없을 때"
    evidence:
      - url: "https://tianpan.co/blog/2026-04-10-sycophancy-tax-agreeable-llms-production"
        supports: current
        claim: "LLM 은 사용자 반박(「확실해?」)에 맞던 답을 상당 비율로 뒤집는다. SycEval 2차 보고 기준으로 퇴행적 접힘이 14.66% 이고 뒤집힌 뒤 78.5% 가 유지됐다. 정확한 수치는 1차 논문으로 확인하지 못했다"
        touches: []
        decides: [OQ5]
        source_kind: secondary
        certainty: uncertain
  - mode: "근거가 서사에 포획된다: 리뷰어가 오케스트레이터의 실행 요약과 같은 파이프라인이 쓴 설계문서·커밋 메시지를 읽고, 그 서사를 따라 「의도대로다」라고 판정한다. 테스트 통과가 의도 충족으로 오독된다"
    trigger: "OQ3 에서 「오케스트레이터가 돌리고 리뷰어는 결과만 읽기」를 택했는데 결과 기록이 원시 출력 대신 요약일 때. 또는 근거가 테스트 통과뿐일 때"
    evidence:
      - url: "https://www.lesswrong.com/posts/Kc7Tc6XbbNeRK3Wg9/when-a-claude-judge-recognizes-the-hack-but-still-says"
        supports: current
        claim: "Claude 판정자가 해킹을 매번 알아보고도 에이전트 자신의 서술에 끌려 HONEST 로 판정했다는 보고(동료 심사 없음)"
        touches: []
        decides: [OQ3]
        source_kind: secondary
        certainty: uncertain
      - url: "https://arxiv.org/html/2511.21654v1"
        supports: current
        claim: "EvilGenie: 통과율(기능 정확성)은 에이전트 평가에 불충분하고, 숨긴 테스트도 다양성이 부족하면 휴리스틱 해법을 통과시킨다"
        touches: []
        decides: [OQ3, OQ4]
        source_kind: primary
        certainty: confirmed
  - mode: "모델이 고른 실행(③)이 리뷰 대상 텍스트에 조종된다: 범위 안 남의 커밋이나 PR·문서의 지시문이 「이걸 돌려 봐라」로 읽혀 임의 명령이 실행되거나 비밀이 새어 나간다"
    trigger: "③ 무엇을 돌릴지 모델이 고른다 + 로드맵 범위에 남의 커밋이 섞인다 + 지금의 「사용자가 승인한 명령만」 경계를 이 리뷰어가 우회할 때(RC-g)"
    evidence:
      - url: "https://labs.cloudsecurityalliance.org/research/csa-research-note-comment-control-github-prompt-injection-20/"
        supports: current
        claim: "Comment and Control: PR 제목·코멘트 주입으로 Claude Code Security Review 등 AI 리뷰 에이전트가 Bash 로 env 를 실행해 비밀을 지적 안에 실었다"
        touches: []
        decides: [OQ3]
        source_kind: secondary
        certainty: confirmed
      - url: "https://arxiv.org/pdf/2606.09935"
        supports: current
        claim: "GitInject: PR·이슈 본문 주입으로 CI 의 AI 에이전트가 GITHUB_TOKEN 을 빼냈다. 방어는 모델 밖(권한·도구 allowlist·승인 게이트)에 둬야 한다"
        touches: []
        decides: [OQ3]
        source_kind: primary
        certainty: confirmed
      - url: "https://microsoft.com/en-us/security/blog/2026/06/05/securing-ci-cd-in-agentic-world-claude-code-github-action-case"
        supports: current
        claim: "Microsoft: Claude Code GitHub Action 이 신뢰할 수 없는 이슈·PR 텍스트를 처리하다 CI 비밀을 노출할 수 있었다"
        touches: []
        decides: [OQ3]
        source_kind: primary
        certainty: confirmed
confidence: 0.7
repo_claims:
  - id: RC1
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "범위는 이미 있는 커밋이라 지금 체크아웃과 다를 수 있다 — 그래서 범위 모드는 고치고 다시 돌지 않고([Fix-loop decision](#fix-loop-decision)), 앱을 걷지 않고([e2e](#e2e))"
    line: 136
    claim: "로드맵 끝 호출이 쓰는 범위 모드는 설계상 걷기(e2e)를 하지 않는다(line 1035 도 같은 내용). 사용자가 가장 넓게 보길 원하는 범위(⑤)가 지금은 「실제 돌려 보기」(③)가 들어갈 자리가 없는 범위다. 범위 끝 커밋과 체크아웃이 다르다는 그 이유는 새 리뷰어의 실행에도 그대로 적용된다"
    touches: []
    decides: [OQ3, OQ4]
  - id: RC2
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "설계문서는 범위 안 커밋의 `Spec:` 트레일러에서 끝 커밋의 트리로 읽고, PR 본문은 읽지 않는다(범위에는 열린 PR 이 없다)"
    line: 168
    claim: "범위 모드의 의도 출처는 Spec 트레일러 설계문서뿐이다. plugins/quality-gates/scripts/discover-spec.sh 에는 interview·brief·roadmap 참조가 하나도 없다(grep 0건). 「사용자 원문에 비춰 본다」(②)에 필요한 원문은 지금의 qg 의도 사슬 밖에 있다"
    touches: []
    decides: []
  - id: RC3
    path: "CLAUDE.md"
    anchor: "축 C 는 채널 «이름»의 실재까지만 재고 그 채널이 실제로 읽히는지는 못 잰다."
    claim: "레포의 처분 집행은 consumer=human 채널이 실제로 읽혔는지 측정하지 못한다고 스스로 공시한다. 판정 밖 질문 채널(④)이 죽어도 기계적으로 드러날 길이 없다"
    touches: []
    decides: [OQ5]
  - id: RC4
    path: "CLAUDE.md"
    anchor: "런타임 state 는 `.claude/<plugin>/` 하위에 산다(git-ignored, plugin namespace 밖으로 나가지 않는다)"
    claim: "진행 중 상태는 git-ignored 이고 인터뷰 진행 기록은 산출물과 함께 커밋될 때까지 추적되지 않는다. 실제로 docs/superpowers/interview/2026-11-14-qg-epic-roadmap-intent-review-brief-interview.state.md(frontmatter `phase: 1`)가 지금 untracked 다. 옆 세션 같은 «인터뷰 중» 작업은 git·커밋 기반 리뷰어가 볼 수 없다"
    touches: []
    decides: [OQ6]
  - id: RC5
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "an optional human-approved e2e walk"
    line: 8
    claim: "qg 의 실행 경계는 「사람이 승인한 명령」이다. 「무엇을 돌릴지는 모델이 고른다」(③)는 이 경계와 정면으로 부딪친다. 범위 모드엔 남의 커밋(신뢰하지 않는 텍스트)이 섞이므로, 경계를 풀면 주입된 실행이 열린다"
    touches: []
    decides: [OQ3]
```

요약:
- 가장 강한 premortem 은 첫째 숨은 가정이다. 사용자가 「잘못 골랐다」를 안 원천은 자기가 직접 써 본 경험이었는데, 이 리뷰어가 모델이 대신 써 보는 것과 파이프라인 산출물로 그 경험을 대체하려 한다. 그러면 「선택이 틀렸다」 대신 「산출물끼리 어긋났다」를 찾는 도구가 될 위험이 있다(OQ4 · OQ3).
- 둘째는 «늘 쓴소리 + 모든 범위 + 판정 밖 채널»의 조합이다. 연출된 반대, 범람, 무시가 겹쳐 채널이 죽는다. 레포도 그 채널이 읽히는지 재지 못한다(OQ5).
- 셋째는 보안이다. ③(모델이 실행을 고름)은 지금의 승인 명령 경계와 충돌하고, 범위에 남의 커밋이 섞이면 주입 공격면이 생긴다(OQ3).
- 웹 수치 중 아첨 비율, 질문 예산 효과, 타이밍 연구는 2차 요약이라 certainty: uncertain 으로 표시했다. 타이밍 연구는 에이전트 과제 맥락이므로 사람의 방향 결정에는 유비로만 읽어야 한다(supports: both).
- 대안 옹호는 하지 않았다(steelman-builder 몫).

V1(본체): RC27(←RC1) 확인 — SKILL.md 136행 · RC28(←RC2) 확인 — SKILL.md 168행 · discover-spec.sh interview|brief|roadmap 0건 · RC29(←RC3) 확인 — CLAUDE.md 66행 · RC30(←RC4) 확인 — CLAUDE.md 70행 · git status ?? 상태 파일 · RC31(←RC5) 확인 — SKILL.md 8행

### 조사 4 — open-researcher · R2 · 묶음 3

요약: (A) 공식 문서와 1차 자료에서 요구사항이나 의도 «자체»에 이의를 거는 리뷰어 제품은 찾지 못했다. 바깥 선례는 셋으로 나뉜다. 첫째는 코드만 읽는 리뷰어로, 실행하지 않고 판정에 들어가지 않는다(Claude Code Review · Codex · Bugbot · Devin). 둘째는 이슈 · 스펙과 대조하는 리뷰어로, 조건부로 merge 를 막는다(CodeRabbit · Baz). 셋째는 앱을 직접 띄워 써 보는 평가자나 탐색 에이전트로, 리뷰어 자신이 브라우저를 몬다(Anthropic 하니스 evaluator · QA.tech · tester.army · Claude Code /verify). 사람에게 따로 묻는 자리는 «작업 전 인터뷰 → SPEC.md» 패턴뿐이었다. (B) 주문의 ①②③은 모두 지금 공식 문서에 적혀 있다. 다만 판 조건이 붙는다. 레포에 적힌 판은 2.1.303(2026-10-22 잼)이고 최신 판은 2.1.323(2026-11-12)이다. 레포의 2026-08~09 실측 둘이 지금 문서와 어긋나서 둘 다 낸다.

```yaml
evidence:
  # ---------- (A) 바깥 선례 ----------
  - url: "https://code.claude.com/docs/en/code-review.md"
    supports: alternative
    claim: "Claude Code Review(관리형 GitHub PR 리뷰)는 기본으로 정확성 버그에만 집중한다. 「a review works from reading the diff and the surrounding code, without building or running your code」 — 실행하지 않는다. 「A review never approves or blocks the pull request」이고 check run 은 「doesn't conclude as a failure」다. 지적은 PR 인라인 코멘트, 요약, «Claude Code Review» check run 상세에 남는다. 의도 · 요구사항에 이의를 거는 기능은 적혀 있지 않다."
    touches: []
    decides: [OQ3, OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/ultrareview.md"
    supports: both
    claim: "/code-review ultra 는 클라우드 샌드박스에서 리뷰어 에이전트 여럿을 띄우고, 「every reported finding is independently reproduced and verified」다 — 리뷰 쪽이 직접 재현한다. 여러 단어로 된 글을 주면 「Claude keeps your text as a note … and relates the findings to it」 — 의도는 쪽지로만 쓰이고 이의 대상은 아니다. 승인 · 차단을 하지 않고, 결과는 세션 알림으로 오거나 사용자가 고르면 PR 일반 코멘트 하나로 남는다."
    touches: []
    decides: [OQ3, OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/code-review-local.md"
    supports: both
    claim: "로컬 /code-review 는 대화로 보고하고, --comment 를 주면 PR 에 올린다. 이웃 명령 「/verify runs your app to confirm a change works」로 실행 확인은 리뷰와 따로 떼어 둔다. 리뷰어는 «build your own reviewer» 로 subagent · skill 을 직접 만들라고 권한다."
    touches: []
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/skills.md"
    supports: both
    claim: "번들 skill /run · /verify 는 「Build and run your app to confirm a code change does what it should, without falling back to tests or type checks」다. 프로젝트 종류(CLI, server, TUI, browser-driven)에서 띄우는 방법을 추론한다. 잘 된 방법은 .claude/skills/verify/SKILL.md 나 .claude/skills/run-<name>/ 에 기록해 다음 실행과 다른 에이전트가 따른다. 앱을 메인 세션이 돌리는지 subagent 가 돌리는지는 문서에 없다."
    touches: []
    decides: [OQ3, OQ4, OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/best-practices"
    supports: both
    claim: "공식 권장 패턴은 둘이다. (1) 「Interview me until you could write the spec, then write it to SPEC.md」 — 질문은 작업 «전»에 사람에게 하고 답은 SPEC.md 에 남긴다. (2) 리뷰는 별도 subagent(tools: Read, Grep, Glob)가 diff 를 SPEC.md 와 대조한다. 끝난 뒤에는 /verify 로 앱을 돌려 본다. 리뷰어가 스펙 자체에 이의를 거는 단계는 없다. 「A reviewer that's asked to find problems will always find something」이라는 경고도 붙어 있다."
    touches: []
    decides: [OQ3, OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://www.anthropic.com/engineering/harness-design-long-running-apps"
    supports: both
    claim: "Anthropic Labs 의 planner/generator/evaluator 하니스(2026-03)에서 evaluator 가 「used the Playwright MCP to click through the running application the way a user would」 — 평가자 자신이 실행 중인 앱을 사용자처럼 써 본다. 첫 판에서는 기준마다 문턱이 있었고 하나라도 못 넘으면 스프린트 실패(판정에 들어감)였다. 피드백은 에이전트끼리 주고받는 파일로 남았다. 스프린트 전에 「done」을 합의하는 sprint contract 협상은 있었지만 planner 의 스펙 자체를 반박한다는 서술은 없고, 실행 중 사람 체크포인트도 없다. 앱을 누가 띄우는지는 적혀 있지 않다."
    touches: []
    decides: [OQ3, OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://docs.github.com/en/copilot/concepts/agents/code-review"
    supports: alternative
    claim: "Copilot code review 는 Actions 러너에서 agentic 문맥 수집 · 도구 사용을 하고, 「The GitHub MCP server and Playwright MCP server are enabled by default」다. 코드 · 테스트를 실제로 실행하는지는 문서에 없다. 모든 리뷰는 개요 코멘트에 approval assessment 를 담고, 켜 두면 required-approval 을 채우는 승인을 낼 수 있다(기본은 집계 안 됨). 이슈 문맥은 MCP 로 끌어올 수 있지만 의도에 이의를 거는 기능은 없다."
    touches: []
    decides: [OQ3, OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://docs.coderabbit.ai/pr-reviews/pre-merge-checks.md"
    supports: alternative
    claim: "CodeRabbit 의 Issue Assessment 는 「Verify PRs address linked issues without containing out-of-scope changes」다 — 연결된 이슈와 대조할 뿐 이슈 자체를 반박하지 않는다. 모드는 off/warning(기본, 막지 않음)/error 이고, error 는 Automatic Approvals 와 짝일 때만 merge 를 막는다. 자연어 custom check 는 「secure, read-only sandbox」에서 돈다. 결과는 Walkthrough 행이나 GitHub Check Run 에 남고, 무시한 실패는 [IGNORED] 로 표시된다. Inconclusive 는 막지 않는다. 코드 실행 여부는 문서에 없다."
    touches: []
    decides: [OQ3, OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://aws.amazon.com/blogs/machine-learning/how-baz-improved-its-ai-agent-code-review-accuracy-using-amazon-bedrock-agentcore/"
    supports: both
    claim: "Baz Spec Reviewer 는 Figma · Jira 요구사항을 모은다. Implementation 서브에이전트가 「AgentCore Browser Use」로 Preview Environment 에서 앱을 직접 몬다 — 실행 환경은 프리뷰 배포, 조작은 리뷰어 쪽 브라우저 도구다. 결과는 PR 코멘트 · Slack · Jira 링크로 남는다. 구현을 스펙과 비교할 뿐 요구사항 자체를 묻지 않고, merge 게이트 여부는 이 글에 없다. (Baz 자체 페이지는 결과를 CI check 로 낸다고 하지만 2차 요약으로만 봤다.)"
    touches: []
    decides: [OQ3, OQ5]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://learn.chatgpt.com/docs/third-party/github"
    supports: alternative
    claim: "OpenAI Codex code review 는 「reviews the pull request diff, follows your repository guidance」(AGENTS.md 의 Review guidelines)이고 GitHub 에서는 P0/P1 만 표시한다. 결과는 PR 리뷰로 남고, 리뷰 규칙은 「don't replace tests, branch protections, or required approvals」다. 실행 · 의도 반박은 문서에 없다. (developers.openai.com 문서가 이 주소로 308 리디렉트됐다.)"
    touches: []
    decides: [OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://cursor.com/docs/bugbot"
    supports: alternative
    claim: "Cursor Bugbot 의 GitHub check 는 기본이 neutral 이라 required 로 걸어도 지적만으로는 막지 않고, fail-on-unresolved 설정일 때만 failure 가 된다. Autofix 는 새 브랜치나 기존 브랜치(최대 3회)에 쓴다. 지적을 코드 실행으로 검증한다는 서술은 찾지 못했다. PR 설명을 의도 문맥으로 쓴다는 말은 Cursor 직원의 포럼 답(2차)에만 있다."
    touches: []
    decides: [OQ5]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://docs.devin.ai/work-with-devin/devin-review"
    supports: alternative
    claim: "Devin Review 는 diff 를 묶어 설명하고 버그를 표시한다. 코드를 실행한다는 서술은 검색 결과에 없고, Auto-Fix 는 설정을 켜야 수정 커밋을 민다. (검색 요약만 봤고 페이지 본문은 열지 않았다.)"
    touches: []
    decides: [OQ3]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://qa.tech/changelog/exploratory-testing-pull-requests.md"
    supports: both
    claim: "QA.tech 는 프리뷰 배포가 준비되면 「automatically runs exploratory tests against that preview environment」 — 실행 대상은 사용자의 프리뷰 배포, 탐색은 QA.tech 에이전트다. 결과는 「GitHub PR reviews (approve, request changes, or informational)」로 남는다. 의도 반박이나 사람에게 묻는 장치는 적혀 있지 않다."
    touches: []
    decides: [OQ3, OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://docs.tester.army/run/pr-exploration-agent.md"
    supports: both
    claim: "tester.army PR exploration agent 는 「PR title and description - understands intent」로 의도를 읽고 테스트 계획을 세운다. 에이전트 자신이 실제 브라우저나 모바일 시뮬레이터에서 실행한다(대상 URL 은 호출자가 준다). 결과는 제자리에서 갱신되는 PR 코멘트와 PR check 에 남는다. 요구사항 반박 · 사람 질문 장치는 없고, 실패가 merge 를 막는지는 문서에 없다."
    touches: []
    decides: [OQ3, OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://claudeissues.com/issue/11450-feature-prompt-review-agent-pre-flight-context-optimisation-and-clarifying-quest"
    supports: alternative
    claim: "Claude Code 에 «요구사항을 시니어처럼 리뷰하고 확인 질문을 하는 Prompt Review Agent» 기능 요청이 2025-11 에 올라왔고 2026-01 에 닫혔다 — 공식 기능으로 생기지 않았다는 정황이다. Cursor 쪽 «interrogate» 플러그인은 의도를 한 문단으로 쓰게 하고 불분명하면 사용자에게 묻되, 리뷰어는 «의도가 옳은가»가 아니라 «의도를 이루는가»를 본다고 검색 요약에 나온다. 원문은 열지 못했다."
    touches: []
    decides: [OQ5]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain
  # ---------- (B) Claude Code 헤드리스 · 시험 방법 ----------
  - url: "https://code.claude.com/docs/en/headless"
    supports: current
    claim: "① 「User-invoked skills and custom commands work. Include /skill-name in the prompt string and Claude Code expands it before running.」 — 지금 사실이다. 프롬프트로 띄운 forked skill 의 메시지는 parent_tool_use_id 가 forked-command- 로 시작하고, 「v2.1.287 or later」가 필요하다. 아무것과도 맞지 않는 /<name> 은 v2.1.274 이후 실패하지 않고 평문으로 모델에 간다(agent-sdk/slash-commands 문서) — 오타 · 미로드가 조용히 지나갈 수 있다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 (레포 dependencies.md 기록 — 지금 설치된 CLI 판은 모름)", latest: "2.1.323 (changelog 2026-11-12)"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/headless"
    supports: current
    claim: "② 「With --output-format stream-json, denials appear as permission_denied system messages, and the final result message lists them in permission_denials.」 — 지금 사실이다(--permission-prompts 절에 적혀 있다). -p 는 「v2.1.302 or later」부터 권한 모드를 정하지 않으면 Manual 로 시작하고, 승인이 필요한 호출은 무언가 승인하지 않으면 거부된다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/headless"
    supports: current
    claim: "③ dontAsk: 「AskUserQuestion … [is] denied even when an allow rule matches」. --permission-prompts none: 「Claude Code removes the tools that need an answer from a person, such as AskUserQuestion, so Claude can't call them」 — 둘 다 지금 사실이다(dontAsk 는 거부, none 은 도구 제거). --permission-prompts 는 「v2.1.259 or later」가 필요하다. permission-modes 문서도 AskUserQuestion 을 「Actions no mode auto-approves」에 넣는다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/agent-sdk/user-input"
    supports: alternative
    claim: "대화형 세션 밖에서 질문까지 끝까지 시험하는 공식 길은 Agent SDK canUseTool 콜백이다. Claude 가 AskUserQuestion 을 부르면 콜백이 tool_name=='AskUserQuestion' 으로 받는다. 호스트가 {questions, answers:{질문 텍스트: 라벨}} 을 updatedInput 으로 돌려주면 진행된다 — 스크립트로 정한 답을 넣을 수 있다. tools 배열을 주면 AskUserQuestion 을 넣어야 한다. 제약: 「AskUserQuestion is not currently available in subagents spawned via the Agent tool」 · 호출당 질문 1–4개 · 선택지 2–4개. dontAsk 모드에서는 콜백이 불리지 않는다. 문서 예시에는 「dummy hook keeps the stream open」 우회가 필요하다고 적혀 있다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/agent-sdk/slash-commands"
    supports: alternative
    claim: "SDK 에서도 프롬프트에 /<name> 을 보내면 사용자 호출 skill 이 실행되고, plugins 옵션으로 경로에서 플러그인 skill 을 불러올 수 있다. system/init 의 slash_commands · skills 배열로 로드됐는지 확인한다(user-invocable:false 는 목록에 안 나온다). 그러니 canUseTool 과 /plugin:skill 디스패치를 묶으면 질문 포함 끝에서 끝 시험이 된다 — 다만 그 조합을 다룬 공식 예시는 없다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/plugin-evals.md"
    supports: alternative
    claim: "claude plugin eval(「v2.1.269 or later」, git 2.31+)는 케이스마다 「fresh, isolated non-interactive session with only your plugin loaded」를 띄워 프롬프트 하나를 보낸다(context.history_file 로 앞 대화를 이어 다음 턴 하나도 가능). grader 는 regex · tool_used · tool_order · file_exists · llm(판정 모델 3표 중 2) · baseline 이고, 플러그인 없는 baseline 과 Δ 를 비교한다. 기본 3회 반복, --threshold 로 CI 게이트, 결과는 ./evals/results/(aggregate-result.json)에 남는다. allowed_tools 후보에 AskUserQuestion 이 들어 있지만, 실행 중 질문에 «누가 어떻게 답하는지»(시뮬레이션 사용자 · 스크립트 답)는 문서에 없다 — 여러 라운드 질문 skill 에 맞는지 확인하지 못했다. 「Runs never stop to ask for permission」."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 (요구 2.1.269 이상 충족 — 기록 판 기준)", latest: "2.1.323"}
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/skills.md"
    supports: alternative
    claim: "skill 시험의 공식 방법: 새 세션에서 skill 을 켠 것과 끈 것을 비교한다. 플러그인 skill 은 skillOverrides 가 안 먹으니 claude plugin eval 을 쓰라고 한다. skill-creator 플러그인은 테스트 케이스마다 subagent 를 띄워 깨끗한 문맥에서 돌리고, grading.json · benchmark.json 과 사람이 정성 피드백을 적는 HTML review viewer 를 낸다(다음 반복이 읽는다). 질문 처리 방법은 적혀 있지 않다. 공식 문서에 subagent 에서는 AskUserQuestion 을 못 쓴다고 적혀 있으니(agent-sdk/user-input), subagent 실행으로는 질문 경로를 덮지 못할 공산이 크다."
    touches: []
    decides: [OQ4, OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/skills.md"
    supports: alternative
    claim: "플러그인 skill 명령 이름은 /plugin-name:skill-name 이다. frontmatter name 이 있으면 「The bare /fancy also invokes the skill unless another command already uses that name」. 레포의 2026-08-17 실측(맨 이름 → Unknown command)과 어긋난다. 그 실측은 v2.1.274 이전 동작이었을 수 있다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/changelog"
    supports: current
    claim: "최신 판은 2.1.323(2026-11-12)이다. 레포 기록 판 2.1.303 이후 관련 변경: 2.1.318 「Fixed custom slash commands that fail, or that only Claude can invoke, printing nothing in claude -p and SDK sessions」 · 2.1.319 permissions.denyInsteadOfPrompting 추가 · 2.1.319 plugin eval 경고 수정 · 2.1.321 -p/SDK 의 AskUserQuestion 이 문서에 없는 afkTimeoutMs 입력을 담은 호스트 답을 거부. changelog 앞 10만 자만 읽었다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
repo_claims:
  - id: RC1
    path: "plugins/quality-gates/dependencies.md"
    anchor: "| claude-code | 2.1.303 | 2026-10-22 | 기록 | 잰 판을 기록만 한다 |"
    line: 17
    claim: "레포가 기록한 Claude Code 판은 2.1.303(2026-10-22 잼, 강도 «기록»)이다. spec-distill · plugin-audit · project-init 의 dependencies.md 도 같은 값이다. 지금 이 기계에 깔린 CLI 판은 레포로 알 수 없다(모름)."
    touches: []
    decides: [OQ4]
  - id: RC2
    path: "docs/superpowers/plans/2026-09-08-docreview-design-doc-site.md"
    anchor: "`AskUserQuestion` 은 헤드리스 `claude -p` 세션에 **존재하지 않는다**"
    line: 1140
    claim: "2026-09 실측: --allowedTools 에 넣어도 헤드리스 -p 세션 init 도구 배열(79개)에 AskUserQuestion 이 없었다. 결론은 「사람이 대화형 라운드를 한 번 돌리는 것 말고 길이 없다」였다. 지금 문서는 제거를 --permission-prompts none 의 효과로 적고, 맨 -p(호스트 없음)에서는 질문이 «거부»된다고 읽힌다 — 판이 달라 어느 쪽이 지금 맞는지는 재지 않았다."
    touches: []
    decides: [OQ4]
  - id: RC3
    path: "docs/superpowers/specs/2026-08-05-agent-transparency-design.md"
    anchor: "OQ-AA"
    line: 1927
    claim: "레포는 「-p 실행에는 대화형 답변 채널이 없어, 답변된 AskUserQuestion 짝이 어느 실물 세션에도 생기지 않는다」를 열린 한계로 적었고, 질문 «문장»만 대조하는 대리 검사로 메웠다. 같은 한계가 docs/superpowers/plans/2026-09-10-seed-at-path-handoff.md 1081행(「헤드리스 한 턴으로는 거기 닿지 않는다」)과 docs/superpowers/specs/2026-09-10-spec-review-hook-removal-design.md 469행(「brainstorming 전체 헤드리스 실행 — AskUserQuestion 게이트에 답할 수 없어 실행이 멈춘다」)에도 있다. Agent SDK canUseTool 경로는 레포에서 쓰인 흔적이 없다(grep 0건)."
    touches: []
    decides: [OQ4]
  - id: RC4
    path: "docs/superpowers/plans/2026-08-17-devbrew-weight-reduction.md"
    anchor: "#### 헤드리스 호출 규격 — 2026-08-17 실측 확정"
    line: 66
    claim: "2026-08-17 실측: --plugin-dir 로 불러온 플러그인 명령은 맨 이름(/qg)이면 `Unknown command` + rc=0 이었고, `/<플러그인>:<커맨드>` 꼴만 됐다(init.slash_commands 에 네임스페이스 꼴만 있었다). 레포는 브랜치 코드 검증의 «유일한 경로»를 `claude -p --plugin-dir <repo>/plugins/<name> '/<플러그인>:<커맨드>'` 로 정했다. 지금 문서(v2.1.274+)는 맞지 않는 /<name> 을 평문으로 넘긴다고 해서, 같은 실수가 지금은 rc=0 + 조용한 평문 처리가 될 수 있다."
    touches: []
    decides: [OQ4]
  - id: RC5
    path: "docs/superpowers/interview/2026-09-01-seam-and-adjudication-interview.audit.md"
    anchor: "| **D — 실제로 하는 일** | **권한 게이트.**"
    line: 349
    claim: "레포 실측에서 거부된 Skill 호출이 `result.permission_denials` 에 기록됐다 — 공식 문서 ②(permission_denials)를 레포 쪽에서도 관측한 사례다(판은 그때 판)."
    touches: []
    decides: [OQ4]
unanswered: "요구사항 · 의도 «자체»에 이의를 거는 리뷰어의 1차 자료 선례는 찾지 못했다(찾은 것은 모두 «구현이 스펙 · 이슈 · 의도를 이루는가»였다). claude plugin eval 실행 중 AskUserQuestion 에 누가 어떻게 답하는지는 문서에 없다. skill-creator 의 질문 처리도 문서에 없다. 이 기계에 깔린 지금 CLI 판은 레포로 알 수 없다. 교차 호스트 리디렉트 둘(docs.baz.co→baz.ai, docs.cursor.com→cursor.com/docs)은 따라가지 않았다 — Baz 문서 본문과 Cursor 리디렉트 목적지 페이지는 열지 않았다(Bugbot 은 검색 요약과 cursor.com/docs/bugbot.md 의 404 로만 봤다). Codex 리디렉트(learn.chatgpt.com)는 OpenAI 쪽 공개 문서라 따라가 읽었다."
```

판단에 쓸 메모(판정 아님):
- 판 차이: 레포 기록 2.1.303 은 이 주문에 걸린 최소 판 조건(2.1.259 · 2.1.269 · 2.1.274 · 2.1.287 · 2.1.302)을 모두 넘는다. 다만 2.1.318 의 「-p 에서 Claude-only 명령이 아무것도 안 찍던」 수정은 기록 판보다 뒤다.
- RC2 · RC4 는 지금 문서와 어긋나는 레포 실측이다. 둘 다 그때 판에서 잰 것이라 하나를 고르지 않았다.

V1(본체): RC32(←RC1) 확인 — dependencies.md 17행 · RC33(←RC2) 확인 — 1140행 · RC34(←RC3) 확인 — OQ-AA 가 1422행에서 「-p 에는 답변 채널이 없어」로 실재 · canUseTool grep 0건 · RC35(←RC4) 확인 — 66행 표 「맨 이름 → Unknown command + rc=0」 · RC36(←RC5) 확인 — 349행. 웹 주장은 본체 1차 재확인 전 — 확인 못 함.

### 조사 5 — steelman-builder · R3 · 묶음 4

#### ST1 — 쓴소리 자리를 qg 안 새 리뷰어로 둘지

dispatch 입력: goal = S2(원 요청 S1 병기) · 전제 P1–P6(P1←S3 · P2←S1 · P3←seed 확인 · P4←seed 확인 · P5←seed 확인 + S4 · P6←S5) · 제약 S1(seed 확인 여섯) ~ S7 전량 · trigger = landscape 모순(의도 자체 이의 선례 없음 · 공식 권장은 작업 전 질문 + 「늘 뭔가 찾는다」 경고 · Ask Early · devil's advocate 연구) + 알려진 anti-pattern(있는 것 먼저 — steelman · premortem 이 이미 있음)

builder 출력 원문:

```yaml
case_for_alternative:
  statement: "쓴소리 자리를 qg 밖 별도 skill로 둔다. 이 skill은 spec-distill 쪽에 살며, 사용자 원문 · 인터뷰 묶음 · 로드맵 · 피벗 경로를 직접 쥔다. qg와 같은 범위(단일 PR · range · 에픽 · 로드맵)를 받지만 qg 판정과는 다른 박자로 돈다 — 단일 PR은 사용자가 써 본 뒤, 에픽은 머지 뒤, 로드맵은 끝에. 인터뷰 단계의 steelman · premortem이 남긴 의심을 구현 뒤 돌려 본 근거로 다시 묻는다."
  strongest: "의심할 대상은 «사용자가 고른 것»이다. 그런데 그것을 담은 원문(발화 S<n>) · 묶음 · 에픽 블록은 spec-distill에만 있고(roadmap_model.py FIELDS), qg의 의도 사슬은 이를 하나도 참조하지 않는다(discover-spec.sh 0건). 설치본의 qg는 spec-distill 스크립트를 부를 수도 없다. 그래서 qg 안의 리뷰어는 인터뷰어가 압축한 설계문서를 의심하게 되고, 압축에서 빠진 바로 그것(=놓친 것)을 못 본다. 「내가 잘못 골랐다」는 답이 흘러갈 피벗 경로(재분해 · 인터뷰 · Sealed decision)도 spec-distill에 있다. 반면 qg 상태는 24시간 뒤 지워진다. 박자도 S3와 맞는다. 사용자가 알아챈 때는 «써 본 뒤»와 «로드맵 끝»이지 «머지해도 되나» 판정 때가 아니었다. 업계 표준인 증분 뒤 방향 재검토(Scrum Sprint Review — 결과를 보고 다음 적응을 정하며, 백로그를 고칠 수 있는 작업 세션)는 코드 리뷰와 따로 떨어진 행사다. Claude Code 공식 문서도 /verify를 리뷰와 떼어 두고, 「A reviewer that's asked to find problems will always find something」이라고 경고한다 — 머지 게이트에 «선택이 옳았나»를 얹으면 지적 무더기 속에 질문이 묻힌다. 그리고 의심 장치(steelman-builder · blind-spot-prober)가 이미 같은 플러그인에 있다(있는 것 먼저). 구현 전에 남은 의심을 구현 뒤 근거로 닫는 고리는 별도 skill이어야 자연스럽게 생긴다."
case_for_current:
  strongest: "뿌리 문제는 «자리 없음»이다. 그리고 devbrew의 존재 이유는 «사용자가 의식적으로 기억하지 않아도 자동으로 지켜지게» 하는 것이다(CLAUDE.md 에피그래프). 인터뷰 단계의 steelman-builder는 이미 있지만 모델이 trigger를 볼 때만 도는 조건부 자리다(pm-interview R3). 그런데도 사용자는 잘못 고른 것을 구현 뒤 써 보고서야 알았다(S3). 기억해서 불러야 하는 자리는 자리가 없는 것과 같았다는 증거다. qg는 사용자가 매 PR에 이미 부르는 게이트이고(「is my PR ready to merge」), 지휘자가 로드맵 끝에 이미 부른다. 지휘자가 없는 단일 PR 일에는 구현 뒤 자동 자리가 qg 하나뿐이다. 돌려 본 근거도 qg에 이미 있다 — 기준선과 견주는 차등 테스트, 사람이 승인한 e2e 걷기(S7과 같은 경계), «오케스트레이터가 돌리고 리뷰어는 읽기만»이라는 Law 2 분리. 그래서 새 리뷰어가 따로 내는 비용은 작다. «구현 뒤 리뷰가 의도 자체를 묻는다»는 선례도 있다. Google 코드 리뷰 지침은 리뷰어에게 「Is what the developer intended good for the users of this code?」 · 「Is now a good time to add this functionality?」를 묻게 하고, 「코드만 읽어서는 사용자 영향을 알기 어렵다」며 직접 패치해 써 보거나 시연을 받으라고 한다. 이는 trigger (1) 「선례 없음」을 약하게 만들고 P5를 받친다. 사용자가 확인한 제약도 모두 qg를 기준으로 쓰여 있다(«qg의 모든 범위», «qg 판정을 바꾸지 않고»)."
premise_refutation:
  hits: []
premise_list_challenge: "반증은 없지만 목록에 결함이 넷 있다. (1) P2는 서로 다른 두 가지를 한 문장에 묶었다. (a) 사용자 · 지휘자가 부르는 «입구»를 qg에 둔다 — S1 원문이 받친다. (b) 리뷰어의 입력 · 질문 원장 · 답의 하류를 qg 안에 둔다 — 레포 사실이 이쪽에 불리하다(qg 의도 사슬에 원문 0건 · 다른 플러그인 스크립트에 닿지 못함 · 24시간 GC · 피벗 경로는 spec-distill). 둘로 쪼개야 한다. (2) 빠진 전제가 있다: «리뷰 시점에 의심 대상(사용자 원문 · 고른 것)이 리뷰어 손에 있다». 지금 qg에서는 거짓이다. 이것 없이는 P2 · P5가 맞아도 리뷰어가 압축본을 의심한다. (3) goal 문장 「고른 것 자체를 의심할 자리가 없다」는 레포 기준으로 정확하지 않다. 구현 전 의심 자리(steelman · premortem)는 있되 조건부다. 정확한 뿌리는 «구현 뒤, 돌려 본 근거로, 기본으로 도는 의심 자리가 없다»이다. 그러면 새 자리가 구현 전 의심(audit의 steelman 판정)을 입력으로 받아야 하는지가 전제 목록에 없다. (4) P1은 S3에서 «알아챈 때»를 뽑아 «드러날 수 있는 때»로 일반화했다. S3의 3은 「잘 모르겠네」로 약한 답이다. 반대쪽 근거(premortem)는 근거 기반이 얇아 반증까지는 아니다. 덧붙여 P3(모든 범위에서 같은 강도)와 S3(써 본 뒤 · 로드맵 끝)는 강도의 무게중심이 다르다. 이 차이는 S6(근거 있을 때만 · 상한)가 다 메우지 못한다. 반복 입력은 아니다 — 이 방향으로 처음 부른 것이다."
recommendation: refined
refined_takes: "입구는 qg에 둔다. qg의 모든 범위(단일 PR · range · 이름으로 부른 에픽 · 로드맵, 지휘자의 에픽 머지 뒤 · 로드맵 끝 호출)에서 자동으로 돈다. Law 2 분리를 유지한다 — 오케스트레이터가 사람 승인 뒤 /run · /verify로 돌리고 리뷰어는 읽기만 한다. 질문은 판정 밖에 둔다(P4). 근거가 있을 때만 묻고 상한을 둔다(S6). 모델이 먼저 걷고, 사람이 직접 써 볼 자리를 짚는다(S5)."
refined_drops: "«qg 리뷰어 하나를 더 두고 qg의 의도 사슬과 세션 상태를 그대로 쓴다»는 꼴을 버린다. 대신 넷을 바꾼다. ① 의심 대상인 사용자 원문 · 묶음 · 에픽 블록을 부르는 쪽이 넘긴다 — 지휘자는 인라인으로, 이름 호출은 추적 문서에서. qg 설계문서 사슬만으로 의심하지 않는다. ② 질문과 답은 qg의 24시간 상태가 아니라 docs의 추적 파일에 남긴다. 「잘못 골랐다」는 답은 spec-distill의 피벗 경로(재분해 · 인터뷰 다시 열기)로 보낸다 — 답의 하류는 qg 밖이다. ③ 범위마다 강도를 똑같이 두지 않는다. PR 범위에서는 qg가 이미 만든 실행 근거(차등 테스트 · 승인된 e2e)를 사용자 원문과 대조해 어긋날 때만 묻는다. 넓은 탐색(/run · /verify로 새로 걷기)은 에픽 머지 뒤 · 로드맵 끝 · 이름 호출에 몰아 둔다. ④ «늘 반대하는 역할»을 버린다. 인터뷰 단계의 steelman · premortem이 남긴 의심과 사용자가 「잘 모르겠다」고 한 자리를 입력으로 받아, «돌려 보니 그 의심이 맞았나»를 묻는다 — 연출된 반대와 「늘 뭔가 찾는 리뷰어」를 피하는 진짜 소수 의견에 가깝다."
evidence:
  - url: "https://google.github.io/eng-practices/review/reviewer/looking-for.html"
    supports: current
    claim: "Google 코드 리뷰 지침은 PR(CL) 리뷰어에게 「Is what the developer intended good for the users of this code?」 · 「Is now a good time to add this functionality?」를 묻게 한다. 또 「It's hard to understand how some changes will impact a user when you're just reading the code」라며 시연을 받거나 직접 패치해 써 보라고 한다 — 구현 뒤 리뷰 게이트에서 의도 자체를 묻고, 실행 근거로 보강하는 선례다."
    touches: [P2, P5]
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://scrumguides.org/scrum-guide.html"
    supports: alternative
    claim: "Sprint Review는 「inspect the outcome of the Sprint and determine future adaptations」이다. 이해관계자와 함께하고, 「a working session … avoid limiting it to a presentation」이며, 「The Product Backlog may also be adjusted」라고 한다 — 증분 뒤 방향 재검토를 코드 리뷰와 떨어진 정해진 박자의 행사로 둔다."
    touches: [P1, P2]
    decides: [OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/best-practices"
    supports: alternative
    claim: "공식 권장은 의도 질문을 작업 전에 둔다(「Interview me until you could write the spec, then write it to SPEC.md」). 리뷰어는 SPEC.md와 대조만 한다. 또 「A reviewer that's asked to find problems will always find something」이라고 경고한다 — 모든 범위에서 상시 도는 쓴소리는 지어낸 지적의 위험을 안는다."
    touches: [P3]
    decides: [OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/best-practices"
    supports: current
    claim: "「Once Claude says it's done, you can also run /verify … That catches the kind of problem that tests and typechecks miss」 — 구현 뒤 실제로 돌려 보면 서류 · 테스트 대조가 놓치는 문제를 잡는다."
    touches: [P5]
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/skills.md"
    supports: current
    claim: "/verify는 「Build and run your app to confirm a code change does what it should」이다. 기록된 방법이 없으면 잘 된 방법을 .claude/skills/verify/SKILL.md에 남겨 다음 실행과 다른 agent가 따른다. 띄우는 방법은 README · package.json · Makefile 같은 프로젝트 파일에서 추론한다 — 산출물이 대화형 skill인 대상을 어떻게 «써 보는지»는 적혀 있지 않다. 명령 실행에 사용자 승인이 필요한지도 문서에 없다."
    touches: [P5]
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://researchr.org/publication/Boehm00a/bibtex"
    supports: current
    claim: "Boehm(2000, IEEE Computer) 「Requirements that Handle IKIWISI, COTS, and Rapid Change」 — «보면 안다(IKIWISI)», 곧 사용자는 동작하는 것을 봐야 요구를 안다는 사실이 미리 확정하는 요구사항 방식을 흔든다. 본문은 열지 못했고 서지와 2차 요약만 봤다."
    touches: [P1]
    decides: []
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://corporate.jasoncollins.blog/premortem"
    supports: both
    claim: "premortem(구현 전 «실패했다고 치고» 원인 찾기)의 근거 기반은 얇다. Klein(2007)의 유일한 인용은 Mitchell · Russo · Pennington(1989)인데, 이 연구는 낸 이유의 «수»가 늘었다는 것만 쟀고 이유의 질은 재지 않았다 — 구현 전 의심 자리의 효과는 약하게만 뒷받침되며, P1을 반증하지 못한다."
    touches: [P1]
    decides: []
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://behavioralscientist.org/stop-playing-devils-advocate-and-other-advice-for-better-decision-making/"
    supports: both
    claim: "Nemeth 계열 연구(2차 요약): 진짜 소수 의견이 역할로 맡긴 devil's advocate보다 나았고, 역할극 반대는 처음 견해를 오히려 굳혔다 — 자리가 qg 안이든 밖이든 «늘 반대하는 역할»보다 실제 근거나 기존 의심에 기댄 질문이 낫다."
    touches: [P3]
    decides: [OQ5]
    source_kind: secondary
    certainty: uncertain
repo_claims:
  - id: RC37
    path: "CLAUDE.md"
    anchor: "devbrew의 역할은 사용자가 의식적으로 기억하지 않아도 이 세 가지가 자동으로 지켜지도록 만드는 것이다"
    line: 7
    claim: "레포의 존재 이유가 «기억하지 않아도 자동으로»다 — 사용자가 이미 부르는 게이트(qg)에 의심 자리를 다는 원안의 핵심 근거다."
    touches: [P2]
    decides: []
  - id: RC38
    path: "plugins/spec-distill/skills/pm-interview/SKILL.md"
    anchor: "| R3 | **Skepticism 통과** | 의심 triggered 방향이 모두 steelman 후 *유지 / 보완 / 전환 / 보류* 중 하나로 판정."
    line: 514
    claim: "구현 전 의심 자리(steelman-builder)는 trigger가 있을 때만 도는 조건부 자리다(같은 파일 299행 「조건 자리(steelman-builder)」). goal 문장의 «자리 없음»은 정확히는 «구현 뒤 · 기본으로 도는 자리 없음»이다."
    touches: [P1]
    decides: []
  - id: RC39
    path: "plugins/quality-gates/scripts/discover-spec.sh"
    anchor: "grep 'interview|brief|roadmap|로드맵' → 0건"
    claim: "qg 의도 출처를 찾는 스크립트는 인터뷰 묶음 · brief · 로드맵을 전혀 참조하지 않는다 — qg 안의 리뷰어는 지금 그대로라면 사용자 원문이 아니라 설계문서 압축본을 의심하게 된다."
    touches: [P2]
    decides: []
  - id: RC40
    path: "plugins/spec-distill/scripts/roadmap_model.py"
    anchor: "FIELDS = (\"의도\", \"범위\", \"의존\", \"브랜치\", \"묶음\", \"경로 예약\", \"spec\", \"발화\", \"항목\", \"완료\")"
    line: 234
    claim: "의심 대상(사용자 원문 번호인 발화 · 인터뷰 묶음 · 브랜치)을 에픽에 잇는 데이터는 spec-distill 쪽에 있다. 설치본 qg는 이 스크립트를 부를 수 없다(CLAUDE.md 「설치본에서 다른 플러그인의 스크립트는 도달 불가다」)."
    touches: [P2]
    decides: []
  - id: RC41
    path: "plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md"
    anchor: "`scripts/qg-gc.py` 가 TTL(기본 24시간)이 지난 세션 폴더를 지운다"
    line: 77
    claim: "qg 상태는 24시간 뒤 지워진다 — 질문과 답을 «따로 오래 남기는» 자리는 qg 세션 상태 밖이어야 한다."
    touches: [P4]
    decides: [OQ5]
  - id: RC42
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### 6. 머지 뒤 … 부를 skill: 없음. / ### 7. 끝 … 부를 skill: `/quality-gates:quality-pipeline`(범위 입력이 있을 때)."
    line: 73
    claim: "지휘자는 머지 뒤 자리(지금은 비어 있음)와 로드맵 끝 자리(qg range 호출, 지적은 후속 PR 하나로)를 이미 갖고 있다 — 에픽 · 로드맵 단위 질문을 낼 박자와 relay 길은 지휘자 쪽에 있다(80행)."
    touches: [P3]
    decides: [OQ5]
  - id: RC43
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "\"is my PR ready to merge\". One pipeline, one verdict — … a differential test against the baseline (always), an optional human-approved e2e walk"
    line: 6
    claim: "qg는 머지해도 되는지 판정하는 게이트이고, 실행 근거(차등 테스트는 늘 · e2e 걷기는 사람 승인 뒤)를 오케스트레이터가 이미 만든다 — 새 리뷰어가 읽을 실행 근거와 승인 경계(S7)가 이미 있다. 판정 게이트라는 성격은 판정 밖 질문(P4)을 따로 남길 자리를 요구한다."
    touches: [P4, P5]
    decides: []
  - id: RC44
    path: "plugins/quality-gates/references/e2e.md"
    anchor: "의도 출처에 없는 동작을 기대 상태로 만들지 않는다"
    line: 21
    claim: "qg의 지금 걷기는 기대 상태를 의도 출처에서만 뽑는다. 그래서 «써 보면 당연히 필요한데 빠진 것»을 찾는 탐색이 아니다 — PR 범위에서 이미 있는 실행 근거를 다시 쓰는 것만으로는 부족하고, 넓은 탐색은 별도 걷기가 필요하다."
    touches: [P5]
    decides: [OQ4]
```

게이트-전 확인:
- RC37 — 확인 — CLAUDE.md 6행(에피그래프) — 주장과 일치 · 부착 P2 확인(원안 쪽 근거, 충돌 아님)
- RC38 — 확인 — pm-interview/SKILL.md 514 · 299행 — 주장과 일치 · 부착 P1 확인(충돌 아님)
- RC39 — 확인 — discover-spec.sh 0건(R2 V1 과 같은 사실) · 부착 P2 확인
- RC40 — 확인 — roadmap_model.py 234행 · 부착 P2 확인
- RC41 — 확인 — state-file-format.md 77행 · 부착 P4 확인
- RC42 — 확인 — conducting.md 73 · 80행 · 부착 P3 확인
- RC43 — 확인 — quality-pipeline/SKILL.md 6행 · 부착 P4 · P5 확인
- RC44 — 확인 — e2e.md 21행 · 부착 P5 확인
- 웹 부착 8건: Google eng-practices(P2 · P5) · Scrum Guide(P1 · P2) · best-practices 두 건(P3 · P5) · skills.md(P5) 5건 확인(공식 1차 · 조사 4 와 교차) / Boehm · premortem · Nemeth 3건 미확인(2차 · 본체 확인 못 함)
- premise_refutation.hits 0건 → 재검토 사유 없음 — 확인된 전제 충돌 0건
- 근거 8 중 부착 5 · 리포 주장 8 중 확인 8

## audit §2 대기 줄

- 포화 판정 1: 아직 — 빈 곳 7개
- 포화 판정 2: 아직 — 빈 곳 7개
- 포화 판정 2: 사용자 판단 포화(@S22) — 반복 빈 곳

### 조사 6 — orchestrator · R7 · 묶음 5

- 웹 E1 확인 — https://code.claude.com/docs/en/headless — 「User-invoked skills and custom commands work. Include `/skill-name` in the prompt string and Claude Code expands it before running.」 (1차 · 확인 2026-11-14) [→ OQ17]
- 웹 E2 확인 — https://code.claude.com/docs/en/headless — 「With `--output-format stream-json`, denials appear as `permission_denied` system messages」 · 「the final result message lists them in `permission_denials`.」 (1차 · 확인 2026-11-14) [→ OQ17]
- 웹 E3 확인 — https://code.claude.com/docs/en/headless — dontAsk: AskUserQuestion 「denied even when an allow rule matches」 · --permission-prompts none: 「Claude Code removes the tools that need an answer from a person … so Claude can't call them」(v2.1.259+) (1차 · 확인 2026-11-14) [→ OQ17]
- 웹 E4 확인 — https://code.claude.com/docs/en/agent-sdk/user-input — 「Claude calls the `AskUserQuestion` tool. This triggers your `canUseTool` callback with `toolName` set to `AskUserQuestion`.」 · 답은 updatedInput 의 answers · 「`AskUserQuestion` is not currently available in subagents spawned via the Agent tool.」 (1차 · 확인 2026-11-14) [→ OQ17]
- 웹 E5 확인 — https://code.claude.com/docs/en/skills — 「`/verify` | Build and run your app to confirm a code change does what it should, without falling back to tests or type checks」 · 「writes what worked to `.claude/skills/verify/SKILL.md` at the repo root」 · 「the recorded skill replaces the bundled `/verify`」 · verify skill 이 있으면 커밋 전에 돈다(v2.1.286+) (1차 · 확인 2026-11-14) [→ 없음]
- 본체 관찰 — `claude --version` = 2.1.323 (Claude Code) — 설치된 CLI 는 최신 upstream 과 같고 레포 기록 2.1.303 보다 새롭다 [→ OQ17]

### 조사 9 — repo-researcher · R7 · 묶음 5

옆 세션 인터뷰 현황 조사 결과다. 모든 path 는 옆 워크트리 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy` 기준 상대경로다.

## 요약
- **진행 단계:** `phase: 1`, R5 까지 답을 받았다. brief 파일은 아직 없고 파일은 셋이다: seed(`2026-11-13-…-interview.md`), audit(`…-interview.audit.md`), state(`2026-11-14-…-brief-interview.state.md`). saturation_log 는 비어 있다. 조사 호출은 60 중 7 회 썼다. 끝의 `## audit §2 대기 줄` 절은 비어 있다.
- **닫힌 차원:**
  - floor 쪽: root_problem · landscape · skepticism · blind_spot.
  - derived 쪽: 일꾼 실행 방식과 역할 경계 집행, 파일 글의 믿음 경계, 토큰 재기와 리프레시 방식, 결정론 경계(P8)와 단계표, 사람이 보는 면, 작은 일과 작업 방식 결합.
- **열린 차원:** floor 의 open_questions, derived 의 internal_research · 걷어낼 장치와 갈아타는 길 · 플랫폼에 있는 것과 새 파일 규약의 경계 · 팀 상태 배치와 기계 간 조정.
- **열린 결정은 OQ10 하나다.** 지금 장치 중 무엇을 걷어내고 무엇을 새 팀 구조로 갈아탈지. OQ1–OQ9 와 OQ11 은 S2–S14 로 풀렸다.
- **user_statements:** S2–S14 가 있다. S1 은 seed 첫 요청 원문을 가리키고 목록에는 없다.
- **seed 확인 문장 19 개**는 state 가 「다시 묻지 않는다」고 적었다. 확정의 근거는 Phase 0 확인이다.

## 질문 항목별 판정
| 항목 | 상태 |
|---|---|
| 지휘자 없이 도는 흐름을 두지 않음 | 확정 — seed 확인 문장(Phase 0), 인터뷰에서 다시 묻지 않음 |
| INTENT.md(목표 · 지시 원문 · 하지 않을 것 · 결정 기록) | 확정. S8 로 결정 기록을 쓰는 시점이 「결정한 행동 직후 그 행동자」로 보완됨 |
| 검수 두 번 · 실제로 돌려 보거나 화면을 봐서 반려 | seed 의 구조 서술에는 있다. 다만 공식 용어 목록에 들지 않았고, 결정도 OQ 도 없다. devbrew 대응은 저자 제안(사용자 미확인)으로 덜어 냈다 |
| 단계표 | 확정. 단계표 파일 · 회고 단계(seed) · 스크립트가 강제할 범위(S14) · 실행기 칸(S4) |
| 지휘자끼리 소통 채널 | 확정(S9: git 원격 편지함이 정본 + 감시자). 배치 · 조정 차원은 아직 열림 |
| quality-gates 의 자리 | 미정. 결정 · OQ 없음, audit 의 저자 제안 표에만 있음 |
| 담당자를 무엇으로 돌릴지 | 확정(S4: 하위 agent 가 기본, claude -p 등은 단계표 실행기 칸에서 고를 수 있음) |

```yaml
repo_claims:
  - id: RC1
    path: "docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.md (옆 워크트리 기준)"
    anchor: "설계문서가 하나뿐인 작은 일도 지휘자를 거치고, 지휘자 없이 도는 흐름을 따로 두지 않는다. (사용자 확인)"
    line: 13
    claim: "「지휘자 없이 도는 흐름을 따로 두지 않는다」는 seed 의 사용자 확인 문장이다. 출처는 audit 라운드 6 의 사용자 원문 「그리고 스펙 하나여도 지휘자로 통일」(audit 276행)과 라운드 7 의 되읽기 「고름」(audit 281행)이다. state R1 은 「seed 의 확인 문장 19개는 다시 묻지 않는다」(state 102행)고 적어, 인터뷰 안에서 이 문장은 확정 전제로 다뤄진다."
    touches: []
    decides: [OQ19]
  - id: RC2
    path: "docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md (옆 워크트리 기준)"
    anchor: "S7 ... 「리프레시는 비용 아닌 품질 신호, 일꾼 파일은 대조해 믿기, 작은 일은 가볍게 (고르지 않음: 역할은 agent 정의로)」 · 차원 「작은 일과 작업 방식 결합」 evidence 「S7 「작은 일은 가볍게」 + seed 확인 문장(superpowers 에 묶이지 않음)」"
    line: 65
    claim: "「작은 일과 작업 방식 결합」 차원은 S7 「작은 일은 가볍게」로 닫혔다. 이 처분은 「작은 일도 지휘자를 거친다」를 뒤집지 않는다. 지휘자를 거치되 가볍게 받는다는 뜻으로 함께 기록됐다(23행). 사용자가 직접 부르는 입구를 따로 둘지는 이 인터뷰가 묻지 않았다."
    touches: []
    decides: [OQ19]
  - id: RC3
    path: "docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.md (옆 워크트리 기준)"
    anchor: "agent 끼리 대화가 안 돼서 빠지는 공유는 과제마다 파일(목표 · 지시 원문 · 하지 않을 것 · 결정 기록)로 메운다. (사용자 확인)"
    line: 15
    claim: "과제마다 INTENT.md(목표 · 지시 원문 · 하지 않을 것 · 결정 기록)를 두는 것은 seed 의 확인 문장이다. 11행 「my-team 의 구조(… INTENT.md, STATUS.md, inbox/, MEMORY → HANDBOOK)를 그 이름 그대로 공식 용어로 들이고 … (사용자 확인)」에 따라 이름도 공식 용어로 확정됐다."
    touches: []
    decides: []
  - id: RC4
    path: "docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md (옆 워크트리 기준)"
    anchor: "S8 「보완 … 파일 규약은 취하고, 읽기 설계와 결정한 자리에서 결정 기록을 같은 첫 단추로 올리며, 되읽기 보증은 산출물 대조로 바꿈」 · ST1 refined_drops 「(d) 결정 기록을 과제 시작 때 한 번 쓰는 칸으로 두는 것. 결정한 행동 직후 그 행동자가 쓰게 하고, 커밋 · 단계 경계에서 확인한다」"
    line: 58
    claim: "steelman ST1 판정은 「보완」(S8)이다. INTENT.md 는 그대로 두되 두 가지가 바뀌었다. 결정 기록은 결정한 행동 직후 그 행동자가 쓴다(1123행). 받음 확인 · 되읽기는 전달의 보증이 아니라 산출물 대조로 대신한다. 과제 단위는 S12 「내가 처음 생각한 내용은 에픽을 대상으로였어」로 에픽이 됐다(19행 evidence 「과제 = 에픽」)."
    touches: []
    decides: []
  - id: RC5
    path: "docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.md (옆 워크트리 기준)"
    anchor: "넘기기 전 관문 다섯 칸(테스트 · 린트 · 화면 · 문서 · 보고)을 채우고, 검수는 두 번이다. 테스트가 하나라도 실패하거나 실제로 돌려 보거나 화면을 봤을 때 잘못되었으면 반려하고, 반려는 어디서 무엇이 어떤 기준에 걸렸는지 한 줄로 되돌린다."
    line: 9
    claim: "「검수 두 번 · 실제로 돌려 보거나 화면을 봐서 반려」는 seed 에 있지만 「그 구조는 이렇다」로 시작하는 붙인 구조의 서술 안에 있다. 이 문장 자체에는 (사용자 확인) 표지가 없다. 11행의 공식 용어 목록에도 검수 · 관문이 들지 않았다. 사용자가 확인한 검수 문장은 17행의 다른 것 하나다: 「구현 뒤 자체 검수가 테스트 결과로 판정해 고칠 것이 있으면 구현으로 되돌리고, 세 번을 넘으면 더 돌리지 않고 보고한다. (사용자 확인)」. state 에는 검수 두 번 · 화면 반려를 다룬 OQ 도 결정도 없다."
    touches: []
    decides: []
  - id: RC6
    path: "docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.audit.md (옆 워크트리 기준)"
    anchor: "| 검수 두 번 + 한 줄 반려 | 실행 방식(SDD) 과제 리뷰 + 지휘자 머지 전 확인 | 두 단계는 이미 있다. 새로 필요한 것은 반려 한 줄 꼴(어디서 · 무엇이 · 어떤 기준) | · 「### my-team → devbrew 대응 제안 (… 저자 제안, 사용자 미확인)」"
    line: 382
    claim: "검수 두 번과 QUALITY_GATES 5칸(381행)이 devbrew 의 어디에 대응하는지는 저자 제안이고 사용자 미확인이다. 433행 「seed 에서 덜어 낸 것」은 이 대응 표를 「하류가 정할 것」으로 seed 에서 뺐다. 「실제로 돌려 보거나 화면을 봐서 반려」를 어디서 할지는 정해지지 않았다."
    touches: []
    decides: []
  - id: RC7
    path: "docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.audit.md (옆 워크트리 기준)"
    anchor: "| QUALITY_GATES 5칸(테스트 · 린트 · 화면 · 문서 · 보고) | quality-gates 플러그인 · 스위트 대조(merge_check) · 통합 리뷰 · AC 보고 | 담당자의 「넘기기 전 칸」으로 마지막 보고에 붙인다 |"
    line: 381
    claim: "quality-gates 의 자리는 이 저자 제안 표의 한 줄에만 나온다(사용자 미확인, 하류가 정할 것). state 의 open_decisions · user_statements · 차원 evidence 에는 quality-gates 의 자리를 정한 항목이 없다. state 에서 quality-gates 가 나오는 곳은 조사 주장 셋뿐이다: 1044행 판 기록, 1818행 Spec: 트레일러를 quality-gates 가 읽는다, 1957행 세션 단위 상태. 따라서 미정이다."
    touches: []
    decides: []
  - id: RC8
    path: "docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.md (옆 워크트리 기준)"
    anchor: "단계표 파일 하나가 무슨 순서로 누구(Claude · 다른 모델 · 스크립트 · 사람 · 대장)에게 일을 시킬지 정하고, 단계별 지시서는 따로 모아 두며, 과제마다 폴더 하나에서 일꾼이 자료를 꺼내고 결과를 넣는 구조를 가져온다. (사용자 확인) 회고도 단계표에 오르는 단계 중 하나다. (사용자 확인)"
    line: 17
    claim: "단계표 파일 · 단계별 지시서 · 과제 폴더 · 회고 단계는 seed 확인 문장이다. 같은 줄에는 사용자가 영상에서 가져오기로 고른 것도 있다: 해시 승인, 두 번 연속 실패 멈춤, 결과 파일로만 하는 보고, 단계마다 다른 일꾼 · 도구. 다만 상주 대장 + 배정 스크립트로 역할을 나눌지는 「인터뷰가 정한다」로 남겨 두었다."
    touches: []
    decides: []
  - id: RC9
    path: "docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md (옆 워크트리 기준)"
    anchor: "S14 「순서·숫자는 스크립트, 단계 안은 모델 (권장) — 단계표 순서·멈춤 횟수·해시 승인·동시 2개는 스크립트가 강제, 각 단계 안의 일은 모델이 판단」"
    line: 64
    claim: "OQ9(무엇을 스크립트가 강제할지, P8 개정 범위)는 S14 로 풀렸고, 「결정론 경계(P8)와 단계표」 차원은 닫혔다(20행). 스크립트가 강제하는 것은 단계표 순서 · 멈춤 횟수 · 해시 승인 · 동시 2개이고, 단계 안의 일은 모델이 판단한다."
    touches: []
    decides: []
  - id: RC10
    path: "docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md (옆 워크트리 기준)"
    anchor: "S9 「편지함 + 세션 안 감시자 (권장) — git 원격 편지함이 정본, 각 지휘자 세션의 감시자(monitor·훅)가 알림, 시작 훅이 밀린 글을 읽음」"
    line: 59
    claim: "OQ4(다른 기계의 지휘자끼리 글을 무엇으로 나를지)는 S9 로 풀렸다. 정본은 git 원격 편지함이고, 알림은 지휘자 세션 안의 감시자(monitor · 훅)가, 밀린 글은 시작 훅이 맡는다. 그 전 R2 에서 사용자는 S5 「한개 서버에 한 세션만 있다면 어떻게 메시지 보낼건데, 더 고민이 필요해」로 한 번 열어 두었다. 「팀 상태 배치와 기계 간 조정」 차원(21행)은 아직 open 이다. 잠금 · 표지가 한 기계를 전제하는 문제와 병렬 3 · 동시 2 상한을 맞추는 일이 남아 있다."
    touches: []
    decides: []
  - id: RC11
    path: "docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md (옆 워크트리 기준)"
    anchor: "S4 「하위 agent + 실행기 칸 (권장) — 지금 방식을 기본으로 두고 단계표 칸으로 백그라운드 세션·claude -p·다른 모델·스크립트를 단계별로 고를 수 있게」"
    line: 55
    claim: "OQ3(담당자를 무엇으로 돌릴지)는 S4 로 풀렸다. 기본은 하위 agent 이고, claude -p · 백그라운드 세션 · 다른 모델 · 스크립트는 단계표의 실행기 칸에서 단계별로 고르는 선택지다. landscape 처분(9행)은 agent 팀 · 헤드리스 기본 · herdr 같은 외부 실행기 기본을 피했다(실행기 칸으로만 허용). 역할을 agent 정의로 하자는 제안은 S7 에서 고르지 않았다. 역할 CLAUDE.md 를 읽히는 길은 OQ7 · S10 으로 풀렸다. 다만 S10 원문은 「1, 아니면 그 안에서 세션이 시작되는건 어려운거겠지?」라는 질문을 겸했고, R5 가 그 질문에 사실로 답했다(1981행)."
    touches: []
    decides: []
  - id: RC12
    path: "docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md (옆 워크트리 기준)"
    anchor: "{id: OQ10, text: \"지금 장치 중 무엇을 걷어내고 무엇을 새 팀 구조로 갈아탈까\", dimension: \"걷어낼 장치와 갈아타는 길\", status: open, resolved_by: null}"
    line: 49
    claim: "open_decisions 에서 열린 것은 OQ10 하나다. 이 결정에 R5 조사 8(지휘 · 파이프라인 장치 목록 43건, 36행)이 붙어 있다. 다음 라운드 질문은 아직 기록되지 않았다(R5 가 마지막 라운드)."
    touches: []
    decides: []
unanswered: "옆 인터뷰가 정하지 않은 것: quality-gates 의 자리, 「검수 두 번 · 실제로 돌려 보거나 화면을 봐서 반려」를 devbrew 의 어디에 둘지, 상주 대장 + 배정 스크립트로 역할을 나눌지, 걷어낼 장치(OQ10). 사용자가 직접 부르는 입구를 따로 둘지는 옆 인터뷰가 묻지 않았다. 이름으로 부른 에픽 · 로드맵을 커밋 · PR · 원문 묶음으로 푸는 주체(OQ12)와 두 갈래를 한 일로 갈지 나눌지(OQ13)에 닿는 기록은 옆 세션 파일에 없다."
```

V1(본체): RC45–RC56(←RC1–12) — 옆 seed 13행 「지휘자 없이 도는 흐름을 따로 두지 않는다. (사용자 확인)」 실재 · audit 107 · 276행 「스펙 하나여도 지휘자로 통일」 · state S4 · S7 · S8 · S9 · S12 · S14 · OQ10(49행 open) 실재 · seed 9행 「그 구조는 이렇다」 · audit 382 · 368행 저자 제안 미확인 · saturation_log [] — 전부 확인.

### 조사 8 — repo-researcher · R7 · 묶음 5

```yaml
repo_claims:
  # ── (A) 에픽 이름 → 브랜치 · PR · 커밋 범위 · 묶음 · 발화 ──
  - id: RC1
    path: "plugins/spec-distill/scripts/conductor_ledger.py"
    anchor: "def c_review_pack(root, a) / COMMANDS[\"review-pack\"]"
    line: 1193
    claim: "review-pack 의 인자는 --roadmap · --epic · --branch(셋 다 필수)와 --merged · --out(선택)이다. 에픽 이름만으로 브랜치를 찾지 않고, 브랜치는 호출자가 --branch 로 넘긴다. 끝 커밋은 branch_tip.tip 으로 고른다. 출력은 폴더 하나이고 파일은 여섯이다. pr.diff 는 `git diff <기본 브랜치>...<끝>` 이다. open-<에픽>-<브랜치>.diff 는 기본 브랜치에 아직 안 들어간 다른 에픽 브랜치의 diff 다. conflicts.txt 는 git merge-tree --name-only 로 본 충돌 파일이다. handoffs.md 는 gh 로 읽은 PR 본문의 `## 통합 리뷰 인계` 절이다. intents.md 와 README.txt 가 나머지 둘이다. stdout 에는 폴더 경로와 파일 목록, `경고:` 줄이 나온다. 커밋 목록이나 범위의 시작 · 끝 커밋, 인터뷰 묶음 경로, S<n> 발화는 내지 않는다."
    touches: []
    decides: [OQ12]
  - id: RC2
    path: "plugins/spec-distill/scripts/review_intents.py"
    anchor: "def build(report, epic, tip, git_fn) — `if b.get(\"id\") == epic or b.get(\"stage\") in NOT_STARTED: continue`"
    line: 166
    claim: "intents.md 에는 함께 진행된 «다른» 에픽들의 설계문서 전문만 실린다. 이름을 준 에픽 자신의 설계문서는 빠진다. 기준 커밋은 _base 가 고른다. 그 에픽의 설계문서를 처음 더한 커밋이고(`git log --diff-filter=A --reverse <tip> -- <specs>`), 그것을 못 찾으면 merge-base 로 대신한다. 이 기준 커밋은 첫 줄 문장에만 나오고, 범위로 따로 내지는 않는다."
    touches: []
    decides: [OQ12]
  - id: RC3
    path: "plugins/spec-distill/scripts/control_plane.py"
    anchor: "def epic_view(path, report, epic) — `show <roadmap> <epic>`"
    line: 1212
    claim: "`control_plane.py show <로드맵> <에픽>` 이 에픽 이름을 받아 한 에픽의 보기를 낸다. 줄 꼴은 `  <칸>: <값>` 이다. 칸은 묶음(R<n>.md) · 설계문서 · 계획 · 브랜치이고, 브랜치는 `<이름>(머지됨)` 이나 `<이름>(진행 — <끝 8자>)` 로 나온다. PR 은 pr_text 로 찍는다. 그 밖에 의존 · 동시 가능 에픽 · 선택 칸 · 열린 넘김 · 판정 줄 · 자원 · 살아 있는 agent · 경고 줄이 나온다. 범위 시작 커밋, 커밋 목록, S<n> 원문은 내지 않는다. 사람이 읽는 글이라 기계가 읽을 형식(JSON)이 없다."
    touches: []
    decides: [OQ12]
  - id: RC4
    path: "plugins/spec-distill/scripts/roadmap_status.py"
    anchor: "report[\"blocks\"].append({\"id\" … \"branches\" … \"branch_states\" … \"tip\" … \"specs\" … \"bundle\" … \"ids\" …})"
    line: 1198
    claim: "`roadmap_status.py --json <로드맵>` 은 블록마다 다음을 낸다. id · stage · branches · branch_states([{branch, tip, merged(근거 문자열 | None)}]) · tip · plans · specs · bundle · ids. ids 는 배정 번호이고 S<n> 을 포함한다. 에픽 → 브랜치 · 끝 커밋 · 설계문서 · 묶음 · 발화 «번호» 로 푸는 기계 읽기 출처는 이것이다. merged 는 머지 커밋 SHA 가 아니라 근거 글이고, 머지됨 단계에서는 블록의 tip 이 None 이 된다(944행). 발화 원문은 싣지 않는다."
    touches: []
    decides: [OQ12]
  - id: RC5
    path: "plugins/spec-distill/scripts/roadmap_model.py"
    anchor: "REQUIRED / FORBIDDEN — `\"bundle\": (\"spec\", \"발화\", \"항목\", \"완료\")` · `for key, want_s in ((\"발화\", True), (\"항목\", False))`"
    line: 240
    claim: "로드맵 블록은 세 종류다. branch · decision 블록은 `발화:` 칸에 S<n> 번호를 직접 적는다. bundle 블록은 `발화:` 칸을 둘 수 없고(FORBIDDEN), 배정 번호는 묶음 파일(R<n>.md) frontmatter 의 `ids:` 에서 collect_assigned 로 채운다(605행). 그래서 에픽의 S<n> 번호가 사는 자리는 블록 종류에 따라 다르다."
    touches: []
    decides: [OQ12]
  - id: RC6
    path: "plugins/spec-distill/scripts/roadmap_render.py"
    anchor: "BUNDLE_FORMAT — `## 6. 사용자 원문\\n%s` / render_bundle(… idx.s6 …)"
    line: 330
    claim: "에픽 묶음 파일(R<n>.md)의 `## 6. 사용자 원문` 에는 brief §6 과 audit §6 을 합친 전문(idx.s6, _merge_s6)이 그대로 들어간다. 그 에픽의 ids 로 거르지 않는다. 이 묶음에서 발화 «원문» 을 얻을 수 있지만 에픽에 배정된 S<n> 만 뽑아 주는 함수는 없다."
    touches: []
    decides: [OQ12]
  - id: RC7
    path: "plugins/spec-distill/agents/integration-reviewer.md"
    anchor: "input_slots: review_request · merged_copy · pr_diff · open_diffs · handoffs · intents"
    line: 16
    claim: "지휘자가 통합 리뷰어에게 넘기는 꼴은 여섯 칸이다. merged_copy 는 merge_check --keep-merged 가 남긴 합친 사본의 절대경로다. pr_diff · open_diffs · handoffs · intents 는 review-pack 폴더의 파일 경로다. 리뷰어 tools 는 Read, Grep, Glob 이다. dispatch 자리는 epic-conductor/SKILL.md `### 6. 통합 리뷰어`(173~187행)이다."
    touches: []
    decides: [OQ12]
  - id: RC8
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "7. **`Spec:` 트레일러.** 구현 커밋에는 `Spec: <에픽 설계문서 레포 상대경로>` 트레일러를 단다"
    line: 105
    claim: "지휘 흐름은 에픽의 구현 커밋에 `Spec: <에픽 설계문서>` 트레일러를 달게 한다. 에픽 → 커밋을 잇는 표지는 git 커밋 안에 있고, qg 의 topic 모드(resolve-topic.sh)와 discover-spec.sh 가 읽는 표지와 같다."
    touches: []
    decides: [OQ12]

  # ── (B) qg 진입 인자 표면 ──
  - id: RC9
    path: "plugins/quality-gates/scripts/setup-qg.sh"
    anchor: "USAGE: /quality-gates:quality-pipeline [branch] [--paths <glob>...] | range <시작>[..<끝>] / `*) echo \"❌ 모르는 인자다(Unknown argument)\"; exit 1`"
    line: 116
    claim: "qg 가 받는 범위 인자는 셋이다. `branch`(이름 없이), `--paths <glob>...`, `range <시작>[..<끝>]`. range 는 다른 범위 인자와 함께 줄 수 없다. 그 밖의 인자는 --session-id · --ensure · -h 뿐이고, 모르는 인자는 exit 1 로 거부한다. `--plan` 은 「리뷰 기준은 Spec: 트레일러 · 커밋 메시지 · PR 본문에서 읽는다」 는 안내와 함께 없어졌다(exit 2). `branch <name>` 도 없어졌다(exit 2). 에픽 · 로드맵 이름을 받는 인자나 다른 쪽이 만든 의도 파일을 받는 인자는 없다."
    touches: []
    decides: [OQ12, OQ19]
  - id: RC10
    path: "plugins/quality-gates/scripts/discover-spec.sh"
    anchor: "discover-spec.sh --intent-out <file> [--base <sha> | --range <start> <end>]"
    line: 16
    claim: "의도 출처는 이 스크립트가 git 에서 스스로 도출한다. 순서는 범위 안 커밋의 `Spec:` 트레일러가 가리키는 설계문서 전부, 없으면 커밋 메시지 + 열린 PR 본문이다. 범위 모드에서는 PR 본문을 읽지 않는다. `--intent-out` 은 쓰는 자리이고 읽는 자리가 아니다. 미리 만든 의도 묶음을 받는 입력 옵션은 없다."
    touches: []
    decides: [OQ12]
  - id: RC11
    path: "plugins/quality-gates/scripts/resolve-topic.sh"
    anchor: "detect -> key: value 4줄 (topic_key · status · reason · base_ref) — 현재 브랜치의 토픽 키"
    line: 6
    claim: "qg 의 topic 모드는 «지금 브랜치» 의 `Spec:` 트레일러에서 토픽 키를 detect 한다. 같은 키를 가진 커밋 집합(여러 브랜치)을 경계 · 끝점으로 묶는다. 토픽 키를 사용자가 인자로 넘기는 입구는 없다(setup-qg.sh 에 `topic` 인자가 없다)."
    touches: []
    decides: [OQ12]
  - id: RC12
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "Arguments: `branch` · `--paths <glob>...` · `range <시작>[..<끝>]` override the review scope"
    line: 120
    claim: "quality-pipeline SKILL 본문에는 spec-distill · 로드맵 · 에픽을 가리키는 글이 없다(quality-gates 플러그인에서 spec-distill 을 언급하는 곳은 artifact-critique SKILL 의 러너 계약 비교와 qg-gc.py 주석뿐이다). qg 쪽에는 에픽 · 로드맵을 푸는 장치가 없다."
    touches: []
    decides: [OQ12]

  # ── (C) 기준선 · 사본 장치와 범위 모드 e2e ──
  - id: RC13
    path: "plugins/quality-gates/scripts/qg-worktree.sh"
    anchor: "make_detached_worktree / create-baseline / create-head … --range <range-scope-file>"
    line: 38
    claim: "qg 차등 테스트의 두 축은 `git worktree add --detach` 로 만든 일회용 worktree 다. stash 나 파일 사본이 아니고, working-tree 오버레이도 하지 않는다. 자리는 `<main_root>/.claude/quality-gates/worktrees/{base|head}-<sid 8자>` 이고, 만들 때 같은 자리의 앞 트리를 먼저 지운다. `create-head --range` 는 범위 파일이 status ok 이고 start≠end 이며 인자가 얼린 end 와 같을 때만 그 end 커밋으로 트리를 만든다. 범위 끝 커밋의 detached 트리를 만드는 검증된 장치가 qg 안에 이미 있다."
    touches: []
    decides: [OQ16]
  - id: RC14
    path: "plugins/quality-gates/skills/quality-pipeline/references/differential-test.md"
    anchor: "`scope0=range` 이면 기준선 커밋은 `boundary=` 값 — 범위의 시작 커밋 / ## D6 트리 정리 — 모든 종료 경로"
    line: 70
    claim: "범위 모드에서 기준선은 범위 시작 커밋이고(create-baseline), HEAD 축은 `create-head --range` 로 끝 커밋에 만든다(D1, 109행). 실행 안 메모는 리포 밖 TMPDIR 에 둔다(memo-init, R6). D6 은 iteration 마다 base · head 트리를 지운다(R23)."
    touches: []
    decides: [OQ16]
  - id: RC15
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "리뷰 트리 (범위 모드 · 실행에 한 번 · P2b 바로 뒤) / `차등 테스트 D1 은 같은 자리(일회용 트리 이름공간의 HEAD 축 자리)에 같은 끝 커밋으로 트리를 다시 만든다`"
    line: 138
    claim: "범위 모드는 P2b 에서 끝 커밋의 임시 트리를 만들어 project_dir 로 쓴다. 지금 체크아웃이 범위 끝이어도(head_is_end: yes) 그렇게 한다. 커밋 안 된 변경을 리뷰어가 끝 커밋 코드로 읽지 않게 하려는 것이다. 이 리뷰 트리는 D1 의 HEAD 축과 같은 자리(head-<sid>)라서 D1 이 다시 만들고 D6 이 지운다. e2e 절에 이를 때 끝 커밋 트리는 이미 지워졌을 수 있다. Final verdict 의 「리뷰 트리 지우기」 는 이미 지워진 경우를 받아들인다(1497~1511행)."
    touches: []
    decides: [OQ16]
  - id: RC16
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "`범위는 이미 있는 커밋이라 지금 체크아웃과 다를 수 있다 — 그래서 범위 모드는 고치고 다시 돌지 않고 …, 앱을 걷지 않고 …, PR 코멘트를 달지 않는다`"
    line: 136
    claim: "범위 모드에서 Fix-loop 반복 · e2e 걷기 · 게시 셋을 끄는 이유로 SKILL 이 적은 것은 한 문장, 「범위는 이미 있는 커밋이라 지금 체크아웃과 다를 수 있다」 뿐이다. e2e 절의 공시 줄도 같은 이유 하나다(1035~1036행: `범위 모드라 앱을 걷지 않는다 — 지금 체크아웃이 범위 끝과 다를 수 있다.`)."
    touches: []
    decides: [OQ16]
  - id: RC17
    path: "plugins/quality-gates/references/e2e.md"
    anchor: "`현재 체크아웃만 걷는다.` / §5 표 `fail | Fix-loop 게이트(고치고 다시 돌기 / 지금 판정으로 끝내기 / 멈추기)` · `무효(코드 변경) | 리뷰·테스트부터 다시`"
    line: 24
    claim: "e2e 레퍼런스는 걷는 대상을 현재 체크아웃으로 못박는다. 걷기 직후 게이트의 fail · 무효 행은 Fix-loop 게이트, 「리뷰·테스트부터 다시」(iteration 소비)로 이어진다. 범위 모드는 반복 1 에서 끝나고 고치고 다시 돌지 않는다(SKILL 819~842행). 체크아웃 불일치와 별개로, 걷기 게이트의 이 갈래들이 범위 모드의 반복 없음과 맞물리지 않는 지점이 문서 구조에 있다. SKILL 은 이것을 범위 모드에서 걷지 않는 이유로 적지 않았다."
    touches: []
    decides: [OQ16]
  - id: RC18
    path: "plugins/quality-gates/scripts/e2e-state.sh"
    anchor: "cmd_boot — `top=$(git rev-parse --show-toplevel …)` · `cd \"$top\"` / fingerprint — `top = git(\"rev-parse\", \"--show-toplevel\")` · `os.chdir(top)` · `EXCLUDE = \":(exclude).claude/quality-gates\"`"
    line: 218
    claim: "e2e 의 boot 와 fingerprint 는 호출한 셸 cwd 의 git toplevel 에서 돈다. boot 는 그리로 cd 해 승인된 명령을 띄우고, fingerprint 는 그 트리의 HEAD · 추적 변경 · untracked 를 잰다. 상태 파일 자리는 --dir · --out 인자로 따로 받는다. 끝 커밋 worktree 안에서 부르면 그 트리를 대상으로 돌 수 있는 구조다. 다만 SKILL 의 e2e 펜스는 RD 를 `${TOP}/.claude/quality-gates/<session-id>` 로 cwd 의 toplevel 에서 도출하므로, worktree 안에서 부르면 상태 폴더 경로가 바뀐다."
    touches: []
    decides: [OQ16]
  - id: RC19
    path: "plugins/spec-distill/scripts/merge_check.py"
    anchor: "def make_copies(root, work, branch) — `git worktree add --detach <d> <base_sha>` · `merge --no-ff --no-edit <tip>`"
    line: 152
    claim: "spec-distill 의 스위트 대조 사본도 일회용 detached worktree 두 개다. base 는 기본 브랜치 SHA 이고, merged 는 같은 SHA 위에 에픽 끝을 --no-ff merge 한 것이다. 자리는 `<상태 루트>/<로드맵 기계 폴더>/<MERGE_CHECK_DIR>/run-<시각>-<pid>/{base,merged}` 이다. 그래서 --roadmap 이 필수이고 기계 상태 폴더 · 공유 스위트 잠금(suite_lock)에 묶인다. --keep-merged 면 merged 사본만 남긴다(통합 리뷰의 merged_copy). 「범위 끝 커밋 단독」 트리가 아니라 「기본 브랜치 + 끝」 의 합친 트리다."
    touches: []
    decides: [OQ16, OQ12]
  - id: RC20
    path: "plugins/spec-distill/tests/test_merge_check.sh"
    anchor: "`assert_eq \"$(readlink …/scripts/$n)\" \"../../../shared/test-selection/$n\" \"${n} 는 공유본으로 가는 상대 링크다\"`"
    line: 15
    claim: "merge_check 가 쓰는 run-test-selection.sh · diff-test-results.py · compute-test-scope-candidates.sh · resolve-baseline.sh 는 spec-distill/scripts 안의 심볼릭 링크다. 링크는 shared/test-selection/ 의 공유본을 가리킨다. 테스트 선택 · 실행 · 짝짓기 부품은 qg 와 공유본으로 나뉘어 있다. 사본(worktree) 만들기 장치는 qg-worktree.sh 와 merge_check.make_copies 로 따로 있다."
    touches: []
    decides: [OQ16]
unanswered: "아래는 레포가 답하지 못하거나 확인하지 못한 부분이다. (1) 끝 커밋 worktree 에서 e2e 부팅 명령이 실제로 도는지. 새 worktree 에는 git 이 무시하는 의존 설치물(node_modules · .venv 등)이 없을 수 있지만, 레포에 이를 잰 기록이나 장치는 없다. 차등 테스트는 setup 실패를 unrun 으로 접는다(R3). (2) 에픽 → 범위 «시작» 커밋을 정하는 규칙이 하나로 정해져 있지 않다. review-pack 의 pr.diff 는 기본 브랜치...끝을 쓰고, review_intents 는 설계문서를 처음 더한 커밋을 쓴다. (3) Grep · Glob 은 심볼릭 링크를 건너뛴다. 그래서 quality-gates/scripts 안 공유본 링크(run-test-selection.sh 등)가 있는지는 확인하지 못했다."
```

V1(본체): RC57–RC76(←RC1–20) — conductor_ledger.py 1193 · review_intents.py 174 · control_plane.py 1212 · roadmap_status.py branch_states 885 · roadmap_model.py FORBIDDEN 245 · roadmap_render.py 343 · integration-reviewer.md 16 · conducting.md 105 · setup-qg.sh USAGE 119 · discover-spec.sh 16 · qg-worktree.sh 12 · 38 · e2e.md 24 「현재 체크아웃만 걷는다」 · e2e-state.sh 218 · merge_check.py 152 · SKILL.md 138 — 앵커 전부 실재, 주장과 일치(줄번호는 ±몇 줄 차이).

### 조사 7 — blind-spot-prober · R7 · 묶음 5

blind-spot-prober, 2차 실행입니다. 대상은 ST1 보완안(S8)입니다. 계약을 받았고, 아래 주장은 모두 그 계약을 따릅니다.

이번에는 보완안이 새로 만든 위험만 냈습니다. 조사 3에서 이미 낸 것은 다시 내지 않았습니다(모델 대리 사용 · 연출된 반대 · 범람 · 주입면 · 진행 중 작업이 안 보임 · 원문이 의도 사슬 밖). RC 번호는 RC45부터 임시로 매겼습니다. 전제 P<n>는 ST1의 P1–P6에 붙였습니다.

검색과 확인 횟수는 다음과 같습니다.
- 웹: 검색 8회, 1차 자료 열람 2회.
- 레포: grep · read 14회.
- 확인한 구현: redecompose.md 전문, proceed-gate.md 재결정 규약, spec-review SKILL.md 게이트 ③, discover-spec.sh 머리, e2e.md 1절, quality-pipeline SKILL.md Step 1a · 1c, 인터뷰 state 파일 user_statements.

```yaml
hidden_assumptions:
  - assumption: "「잘못 골랐다」는 답을 받을 spec-distill 피벗 경로(재분해 · 인터뷰 다시 열기)가 쓴소리가 도는 그 시점에 열려 있다"
    why_risky: "에픽 머지 뒤와 로드맵 끝은 보완안이 넓은 탐색을 몰아 둔 자리이고 사용자가 알아챈 때(S3)이기도 하다. 그런데 재분해 생성기는 머지되거나 끝난 에픽을 거부한다. 로드맵 에픽의 「인터뷰 다시 열기」는 인터뷰를 다시 여는 길이 아니라 그 재분해로 가는 길이고, 구현 전 설계문서 승인 게이트(spec-review ③)에만 있다. 따라서 로드맵 끝에 「잘못 골랐다」고 답하면 받는 곳이 구조적으로 없다. Sealed decision이 사용자가 실제로 겪은 바로 그 자리에서 되풀이된다. 재분해 절차는 spec-distill 플러그인 루트가 로드된 세션에서만 돌므로, qg 세션에서는 멈춘다. 지휘자 없이 사용자가 PR 하나에 qg를 부르면 로드맵 자체가 없어 재분해가 해당되지 않는다. 그때는 이음매 담당이 아예 없다."
    evidence:
      - url: "https://jmis-web.org/articles/530"
        supports: current
        claim: "소프트웨어 프로젝트의 escalation of commitment 연구 갈래(Keil 등). 이미 들인 비용과 위험 인식이 클수록 문제가 보여도 계속 가려는 경향이 커진다. 늦은 시점의 「잘못 골랐다」는 받는 길이 미리 열려 있지 않으면 흡수되지 못한다는 유비다(직접 증거는 아님)"
        touches: [P1, P2]
        decides: [OQ18, OQ13]
        source_kind: secondary
        checked_at: "2026-11-14"
        certainty: uncertain
  - assumption: "사용자 원문(발화 S<n>)은 사용자가 고른 것 그 자체라서, 그것을 의심하면 사용자의 선택을 의심하게 된다"
    why_risky: "이번 인터뷰의 user_statements 13개 중 12개는 source: chosen이다. 글자는 인터뷰어가 쓴 「(권장)」이나 「(추천)」 선택지 라벨이다. 사용자 자신의 글은 S3 하나뿐이다. 그래서 「원문」에는 모델의 framing이 이미 들어 있다. 구현도 같은 framing에서 나왔다. 그러면 원문과 구현을 대조해도 어긋남이 나기 어렵고, 오히려 「원문과 일치 — 선택이 맞았다」는 거짓 확인을 낸다. 가벼운 PR 기준(OQ14)과 「맞다」 답 원장(OQ15)이 모두 이 원문에 기대고 있다."
    evidence:
      - url: "https://arxiv.org/pdf/2302.00560"
        supports: current
        claim: "Jakesch 외(CHI 2023, N=1,506). 특정 의견을 가진 언어 모델과 함께 글을 쓴 참가자는 글에 드러난 의견이 바뀌었고, 나중 태도 설문의 의견도 바뀌었다(latent persuasion). 모델이 제시한 framing을 고른 결과는 순수한 사용자 의견이 아니다"
        touches: [P2]
        decides: [OQ14, OQ15]
        source_kind: primary
        checked_at: "2026-11-14"
        certainty: confirmed
      - url: "https://arxiv.org/pdf/2502.15395"
        supports: current
        claim: "LLM을 많이 쓰는 사용자 연구. 우려할 행동은 수락률 자체보다 대안을 탐색하지 않고 LLM의 추론을 그대로 받아들이는 것이었다"
        touches: [P2]
        decides: [OQ14]
        source_kind: primary
        checked_at: "2026-11-14"
        certainty: uncertain
  - assumption: "인터뷰의 steelman · premortem이 남긴 의심을 입력으로 주면, 리뷰어가 연출된 반대 대신 진짜 발견에 다가간다"
    why_risky: "입력으로 넘기는 의심은 구현 전에 나온 것이고, 사용자가 이미 처분한 것이다. 사용자가 실제로 알아챈 것(S3)은 써 본 뒤에야 생긴 unknown-unknown이라서 그 목록에 없다. 의심 목록이 탐색의 닻이 되면 리뷰어는 「알려진 의심을 다시 검산하는 장치」가 된다. 여기에 「근거 있을 때만」(S6)이 겹치면 목록 밖 문제에는 침묵하고, 그 침묵이 「확인했다」로 읽힌다. LLM은 가설을 받으면 반증보다 확증하는 쪽으로 시험한다."
    evidence:
      - url: "https://arxiv.org/abs/2604.02485"
        supports: current
        claim: "Failing to Falsify. LLM 11종이 Wason 2–4–6 과제에서 가설을 반증하기보다 확증하는 예를 제안했고, 그래서 숨은 규칙을 늦게, 덜 찾았다. 반례를 고려하라는 개입으로 발견률이 42%에서 56%로 올랐다"
        touches: [P6]
        decides: [OQ14]
        source_kind: primary
        checked_at: "2026-11-14"
        certainty: confirmed
      - url: "https://arxiv.org/abs/2505.15392"
        supports: current
        claim: "LLM의 anchoring 효과는 흔하고 일반적인 완화 전략으로 없어지지 않는다(추론이 일부 완화한다)"
        touches: [P6]
        decides: [OQ14]
        source_kind: primary
        checked_at: "2026-11-14"
        certainty: uncertain
  - assumption: "원문 · 묶음은 부르는 쪽이 넘기면 된다(넘기지 않는 호출은 예외다)"
    why_risky: "지휘자 없이 사용자가 PR 하나에 qg를 부르는 일이 가장 흔한 길이다(RC43). 이 길에서는 넘길 원문도, 받을 의심 입력도 없다. 결과는 둘 중 하나다. 모든 PR에서 「근거 없음」으로 늘 침묵하는 죽은 기능이 되거나, discover-spec의 압축본 의심으로 조용히 되돌아간다. 원문이 넘어오는지가 사용자의 기억에 달리면 레포 에피그래프 「기억하지 않아도」와 어긋난다. 반면 레포에는 이미 설계문서 frontmatter `source_interview` → brief라는 결정론적 링크가 있는데, qg 사슬은 그것을 따라가지 않는다. 그 brief도 압축본이고, 원문 S는 state 파일에 있다. spec-distill을 쓰지 않는 레포에서는 이 입력이 늘 비어 있다."
    evidence: []
    # 근거는 레포 사실 — repo_claims RC49 · RC51
  - assumption: "PR 범위에서는 qg가 이미 만든 실행 근거(차등 테스트 · 승인된 e2e)를 원문과 대조하면 어긋남을 잡는다"
    why_risky: "e2e 기대 상태는 의도 출처(설계문서)에서만 뽑는다. 그러니 그 근거는 압축본에서 파생된 것이고, 원문과 대조해도 압축 단계에서 빠진 것은 기대 상태에도 없다. 대조가 순환한다. 또 사람이 걸을 표면을 바꾸지 않은 변경에는 시나리오를 만들지 않는다. 산출물이 skill(.md)인 devbrew에서는 PR 범위 근거가 거의 늘 비어 있다. 결국 PR 범위의 쓴소리는 사실상 꺼진 채 「없음」만 낸다."
    evidence: []
    # 근거는 레포 사실 — repo_claims RC50
failure_modes:
  - mode: "피벗 막다른 길. 로드맵 끝이나 에픽 머지 뒤에 「잘못 골랐다」로 답하면, 재분해가 머지된 에픽을 거부하고(rc 1) qg 세션에는 spec-distill 루트가 없다. 답은 원장에만 쌓이고 그것을 소비하는 쪽이 없다"
    trigger: "넓은 탐색 자리(에픽 머지 뒤 · 로드맵 끝 · 이름 호출)에서 사용자가 「잘못 골랐다」를 고를 때. 또는 로드맵이 없는 단일 PR 호출에서 고를 때"
    evidence:
      - url: "https://jmis-web.org/articles/530"
        supports: current
        claim: "이미 들인 비용이 클수록 철회가 어렵다. 늦게 알아챈 것은 받는 길이 미리 정해져 있지 않으면 사실상 다음 일의 입력으로만 남는다(유비)"
        touches: [P1]
        decides: [OQ18]
        source_kind: secondary
        checked_at: "2026-11-14"
        certainty: uncertain
  - mode: "답 원장이 갈라지거나 충돌하거나 사라진다. 병렬 에픽의 PR 브랜치마다 같은 docs 원장 파일에 줄을 덧붙이면 머지 충돌이 난다. PR이 닫히면 그 브랜치의 답이 사라진다. 머지 뒤나 로드맵 끝에는 main 위에서 쓰게 되는데, GitHub Flow상 직접 커밋할 수 없다. 그래서 원장이 별도 PR을 기다리거나 untracked로 남는다. 다른 worktree에서 도는 다음 실행은 그 답을 보지 못해 같은 질문을 다시 낸다(OQ15의 키가 무엇이든 원장이 안 보이면 소용없다)"
    trigger: "지휘자가 에픽 단위 병렬을 권하는 기본 흐름이거나, 머지 뒤 자동 호출이 main 체크아웃에서 원장을 쓸 때. 원장을 쓰는 주인이 qg이고 qg에는 docs writer와 커밋 펜스가 없을 때"
    evidence:
      - url: "https://about.gitlab.com/blog/solving-gitlabs-changelog-conflict-crisis/"
        supports: current
        claim: "GitLab: 「we'd constantly see merge conflicts in the changelog when multiple merge requests attempted to add an entry to the list」. 해법은 항목마다 파일 하나(「Each changelog entry would be its own YAML file」)였다. 여러 브랜치가 덧붙이는 단일 추적 파일은 충돌의 원천이다"
        touches: [P4]
        decides: [OQ15, OQ13]
        source_kind: primary
        checked_at: "2026-11-14"
        certainty: confirmed
      - url: "https://docs.github.com/en/enterprise-cloud@latest/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches"
        supports: current
        claim: "보호 브랜치의 「Require a pull request before merging」는 기본 브랜치에 직접 커밋하는 것을 막는다. 머지 뒤에 원장을 쓰려면 매번 별도 PR이 필요하다"
        touches: [P4]
        decides: [OQ15]
        source_kind: primary
        checked_at: "2026-11-14"
        certainty: uncertain
  - mode: "「맞다」 억제가 썩는다. 한 번 「맞다」로 닫힌 질문은 그 뒤 에픽이나 변경으로 근거가 달라져 다시 유효해져도 묻지 않는다. 그 「맞다」는 대개 모델의 (권장) 라벨을 고른 결과다(가정 2). 원장이 새 의심을 가리는 baseline이 된다"
    trigger: "OQ15의 조회 키가 질문 글자나 OQ · S 번호처럼 근거(실행 결과 · 대상 커밋)와 무관한 정체로 정해질 때"
    evidence:
      - url: "https://metbcy.github.io/bomdrift/baseline.html"
        supports: current
        claim: "baseline 억제 도구는 맥락(의존 버전)이 바뀌면 받아들였던 지적을 일부러 다시 띄운다. 「version drift is exactly the case where a known-acceptable finding becomes an unknown one」"
        touches: [P4]
        decides: [OQ15]
        source_kind: secondary
        checked_at: "2026-11-14"
        certainty: uncertain
  - mode: "원문 확증 루프. 리뷰어가 구현을 S 라벨과 대조해 「원문과 일치」를 보고한다. 그런데 둘이 같은 모델 framing에서 나왔으므로, 그 보고가 「선택이 옳았다」는 거짓 확인으로 작동한다"
    trigger: "가벼운 PR 기준(OQ14)이 「원문과 실행 근거의 어긋남」만을 질문 조건으로 삼고, 원문 대부분이 source: chosen일 때"
    evidence:
      - url: "https://arxiv.org/pdf/2302.00560"
        supports: current
        claim: "모델 제안을 거친 사용자 표현은 모델 쪽으로 기운다. 원문과 모델 산출물의 일치는 독립적인 확인이 아니다"
        touches: [P2]
        decides: [OQ14]
        source_kind: primary
        checked_at: "2026-11-14"
        certainty: confirmed
confidence: 0.7
repo_claims:
  - id: RC45
    path: "plugins/spec-distill/references/redecompose.md"
    anchor: "머지되거나 끝난 에픽은 건드리지 않는다 — 블록도 묶음도 그대로다. 생성기가 거부한다."
    line: 73
    claim: "재분해는 머지된 에픽을 바꾸지 못한다(117행: 바꾸거나 지우는 표는 쓰기 전에 rc 1). 에픽 머지 뒤나 로드맵 끝에 「잘못 골랐다」로 답하면 이 피벗 경로는 닫혀 있다."
    touches: [P2]
    decides: [OQ18, OQ13]
  - id: RC46
    path: "plugins/spec-distill/references/redecompose.md"
    anchor: "spec-distill 이 로드된 적 없는 지휘 세션에서는 `${CLAUDE_PLUGIN_ROOT}` 가 풀리지 않아 펜스 가드가 멈춰 보고한다"
    line: 5
    claim: "피벗 절차는 spec-distill 루트가 있는 세션에서만 돈다. qg 세션에서 받은 답을 넘기는 이음매(누가 언제 spec-distill 세션을 열게 하나)는 지금 담당이 없다."
    touches: [P2]
    decides: [OQ13]
  - id: RC47
    path: "plugins/spec-distill/skills/spec-review/SKILL.md"
    anchor: "「인터뷰 다시 열기」 갈래는 인터뷰를 다시 열지 않고 같은 로드맵 위의 재분해 절차로 간다"
    line: 700
    claim: "보완안이 이름 붙인 「인터뷰 다시 열기」는 설계문서 승인 게이트 ③(구현 전)의 갈래다. 로드맵 에픽에서는 RC45의 재분해와 같은 길이다. 구현 뒤 qg에서 들어오는 입구가 아니다."
    touches: [P2]
    decides: [OQ18]
  - id: RC48
    path: "docs/superpowers/interview/2026-11-14-qg-epic-roadmap-intent-review-brief-interview.state.md"
    anchor: "user_statements: … {id: S2, source: chosen, … (권장)} … {id: S3, source: verbatim, … \"1, 2이고 3은 잘 모르겠네\"}"
    line: 57
    claim: "이 인터뷰의 사용자 발화 13개 중 12개가 source: chosen이고 글은 「(권장)」이나 「(builder·orchestrator 추천)」 선택지 라벨이다. verbatim은 S3 하나다. 「사용자 원문」의 대부분은 모델이 쓴 framing이다(파일은 지금 untracked)."
    touches: [P2]
    decides: [OQ14, OQ15]
  - id: RC49
    path: "plugins/spec-distill/skills/spec-review/SKILL.md"
    anchor: "리뷰어는 설계문서 frontmatter `source_interview` 로 정답 출처에 닿고"
    line: 157
    claim: "설계문서에서 brief로 가는 결정론적 링크(source_interview)가 이미 있다. 그런데 qg의 discover-spec.sh(4–7행 사슬)는 Spec 트레일러 설계문서까지만 읽고 이 링크를 따라가지 않는다. 「부르는 쪽이 넘긴다」만으로는 단일 PR 호출에 원문이 오지 않는다."
    touches: [P2]
    decides: [OQ12, OQ14]
  - id: RC50
    path: "plugins/quality-gates/references/e2e.md"
    anchor: "기대 상태는 의도 출처가 약속한 동작에서 뽑는다 / 이 변경이 사람이 걸을 표면을 바꾸지 않았으면(문서 · 내부 리팩터 · 테스트만) 시나리오를 만들지 않는다"
    line: 21
    claim: "PR 범위에서 「이미 있는 실행 근거」는 압축본(의도 출처)에서 파생된다(21행). 표면 변경이 없으면 근거가 없다(23행). 24행에 따라 현재 체크아웃만 걷는다. 그래서 가벼운 PR 대조는 순환하거나 비어 있다."
    touches: [P3, P5]
    decides: [OQ14]
  - id: RC51
    path: "plugins/spec-distill/skills/pm-interview/references/finishing.md"
    anchor: "python3 \"$SD/scripts/state_path.py\" path-inside --root \"$top\" \"$BRIEF\" \"$AUDIT_F\" \"$STATE_F\""
    line: 623
    claim: "docs 추적 파일을 링크 검사 뒤 커밋하는 펜스와 writer는 spec-distill에 있다. qg에는 docs에 쓰는 자리가 없다(quality-pipeline SKILL.md에서 docs/ 0건, 상태는 .claude/quality-gates/). 원장의 주인을 qg로 두면 writer와 커밋 길을 새로 만들어야 한다. spec-distill로 두면 설치본 qg가 그 스크립트를 부를 수 없다(RC10). 어느 쪽이든 주인과 이음매가 지금은 비어 있다."
    touches: [P4]
    decides: [OQ13, OQ15]
  - id: RC52
    path: "CLAUDE.md"
    anchor: "GitHub Flow. `main`에서 분기, PR로 merge back."
    line: 13
    claim: "머지 뒤나 로드맵 끝의 자동 호출이 남기는 원장 줄은 main에 직접 커밋할 수 없다. 매번 별도 브랜치와 PR이 필요하거나 untracked로 남는다. 그러면 다음 실행(다른 worktree)이 보지 못한다."
    touches: [P4]
    decides: [OQ15]
  - id: RC53
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "토픽 <topic_key> 의 선언 커밋 <in_base>개는 이미 base 에 있어 토픽 구성원에서 빠졌다"
    line: 274
    claim: "qg에는 range 말고도 여러 브랜치를 묶는 topic 범위가 이미 있다(247 · 261행). 다만 머지된 구성원은 base로 빠진다. 따라서 에픽 머지 뒤에는 브랜치나 topic 기반 범위가 비고, 남는 것은 다른 일의 커밋이 섞이는 range(RC7)뿐이다. 이름 풀이(OQ12)가 이 둘을 모르고 새 범위를 만들면 있는 것과 겹친다."
    touches: [P3]
    decides: [OQ12]
```

요약:
- 가장 강한 위험은 첫째 가정입니다. 보완안은 넓은 탐색을 에픽 머지 뒤와 로드맵 끝에 몰아 두었는데, 그 두 자리에서 「잘못 골랐다」를 받을 피벗 경로가 레포 구조상 닫혀 있습니다. 재분해는 머지된 에픽을 거부합니다. 「인터뷰 다시 열기」는 구현 전 게이트에만 있습니다. qg 세션에는 spec-distill 루트가 없습니다. 그래서 사용자가 실제로 겪은 Sealed decision이 그 자리에서 되풀이됩니다(OQ18 · OQ13).
- 둘째, 「원문」은 대부분 모델이 쓴 (권장) 라벨입니다(이 인터뷰에서 12/13). 원문과 대조하는 장치(OQ14)와 「맞다」 원장(OQ15)이 모두 독립적인 확인이 되지 못하고 거짓 확인을 낼 수 있습니다.
- 셋째, 인터뷰의 의심을 입력으로 주는 설계(④)는 연출된 반대를 피하는 대신 탐색을 알려진 의심에 묶습니다. LLM의 확증 편향과 「근거 있을 때만」이 겹치면 목록 밖 문제에 침묵합니다.
- 넷째, docs 원장은 병렬 브랜치에서 충돌합니다. 머지 뒤에는 main 직접 커밋이 금지라 PR이 필요하거나 untracked로 남습니다. 쓰는 주인 플러그인(writer · 커밋 펜스)도 비어 있습니다.
- 다섯째, 단일 PR 호출은 원문도 의심 입력도 없어 늘 침묵하거나 압축본 의심으로 되돌아갑니다. 이미 있는 `source_interview` 링크는 쓰이지 않고 있습니다.
- 확신도: Keil(escalation) · 원장 baseline(bomdrift) · anchoring · GitHub 보호 브랜치 근거는 certainty를 uncertain으로 두었습니다. escalation은 유비로만 읽어야 합니다.
- 대안 옹호는 하지 않았습니다. steelman-builder의 몫입니다.

V1(본체): RC77–RC85(←RC45–53) — redecompose.md 73 · 5행 · spec-review/SKILL.md 700행 · source_interview(같은 파일에 실재) · finishing.md path-inside(실재, 줄번호 다름) · quality-pipeline SKILL.md docs/ 0건 · 274행 — 전부 확인. RC48 은 이 상태 파일 자체(S2–S14 중 verbatim 은 S3 하나) — 확인.

### 조사 10 — open-researcher · R7 · 묶음 5

OQ15 조사 결과입니다. 기대 결론 없이 근거만 냅니다. 레포 주장은 모두 구현을 읽고 냈습니다. `plugins/spec-distill/scripts/docreview_*.py` 는 `shared/docreview/scripts/` 를 가리키는 심볼릭 링크라서, path 는 실체 쪽으로 적었습니다.

```yaml
evidence:
  - url: "https://docs.coderabbit.ai/guides/learnings"
    supports: alternative
    claim: "CodeRabbit learnings 는 PR · 이슈 대화에서 생긴 자연어 문장이다. 파일 · 줄 · 해시를 키로 쓰지 않는다. 메타데이터로 PR 번호 · 파일명 · 사용자를 저장하고, 대시보드에서 벡터 유사도 검색으로 찾는다. 파일명 패턴에 묶인 learning 은 그 패턴이 바뀐 파일과 맞을 때 적용 후보가 된다. 범위는 local · global · auto(기본) 셋이다. 열린 PR 에서 생긴 learning 은 그 PR 에만 먼저 적용되고, 머지 뒤 레포 전체로 넓어진다. 코드가 바뀌면 자동으로 무효로 만드는 조건은 문서에 없다. 「learnings can become stale」이라 적고 사람이 주기적으로 지우고 고치라고 권한다. 같은 주제에 서로 충돌하는 learning 이 여럿이면 동작이 일관되지 않다고 경고한다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "레포 미사용", latest: "문서 판 표기 없음"}
    certainty: confirmed
  - url: "https://docs.coderabbit.ai/reference/glossary.md"
    supports: alternative
    claim: "CodeRabbit 의 증분 리뷰는 새 커밋분만 다시 보며 「avoids repeating comments already made on previous commits」. 사용자가 손으로 resolve 한 스레드가 코드가 그대로일 때 다시 제기되는지는 공식 문서에서 찾지 못했다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://cursor.com/blog/bugbot-learning"
    supports: alternative
    claim: "Bugbot(2026-04-08 글)은 세 신호에서 후보 규칙을 만든다 — 지적에 단 downvote · 지적에 단 답글 · 사람 리뷰어의 지적. 신호가 쌓이면 규칙이 active 로 오르고, 부정 신호가 이어지면 꺼진다. 규칙을 무엇으로 키 잡는지(파일 · 줄 등), 코드가 바뀌면 무효로 보는지는 이 글에 없다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://cursor.com/docs/bugbot"
    supports: alternative
    claim: "Bugbot 은 연결된 PR 의 최상위 댓글과 줄 댓글을 읽어 「avoid duplicate suggestions and build on prior feedback」. 기본은 증분 리뷰로, 직전 Bugbot 리뷰 이후 바뀐 부분만 본다. CI 통과 조건은 이전 실행의 미해결 Bugbot 댓글이 없는 것이다. 지적마다 resolution_status 를 단다. PR 에 `@cursor remember` 를 달아 규칙을 더할 수 있다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://forum.cursor.com/t/bugbot-should-filter-out-previously-resolved-dismissed-issues/147748"
    supports: alternative
    claim: "실패 사례. 사용자가 dismiss 하거나 「this is the correct behavior」 같은 의도 답글을 단 뒤에도 Bugbot 이 같은 지적을 여러 실행에 걸쳐 다시 냈다(2025-12-31, 2026-06-26 보고). Cursor 직원 답(2026-06-27): 「dedupe looks at the thread's resolved or dismissed state, and a plain reply might not count as a signal」. 곧 키가 스레드 상태이고, 글로 쓴 「의도한 것이다」 답은 억제 신호가 아닐 수 있다. 그 뒤 해결됐다는 확인은 없다."
    touches: []
    decides: [OQ15]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://docs.github.com/en/copilot/concepts/agents/copilot-memory"
    supports: alternative
    claim: "Copilot Memory 의 레포 사실은 「fact + citations(그 사실을 받치는 코드 위치)」로 저장된다. 쓰기 전에 「checks the fact's citations against the current branch」 해서 아직 맞는지 판단한다. 다만 이 판단은 보증이 아니라고 문서가 밝힌다. 만료는 기본 90일이고, 만든 때부터 세며 Copilot 이 upvote 하면 다시 센다. 조회만으로는 다시 세지 않는다. 조직은 7–180일로 정할 수 있다. 코드 리뷰에는 레포 사실만 쓰고 사용자 선호는 쓰지 않는다. dismiss 한 리뷰 댓글에 관한 내용은 없다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://github.blog/ai-and-ml/github-copilot/building-an-agentic-memory-system-for-github-copilot/"
    supports: alternative
    claim: "GitHub 엔지니어링 블로그(2026-01-15 게시, 2026-11-12 갱신)에 따르면 무효 판정을 미리 정리하지 않고 읽을 때 인용을 검증하는 쪽으로 했다. 코드가 기억과 모순되거나 인용이 없는 위치를 가리키면, 에이전트가 고친 기억을 다시 저장하도록 권한다. 일부러 넣은 적대적 기억도 인용 검증이 걸러냈다고 자체 보고한다(독립 검증은 아니다)."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://docs.sonarsource.com/sonarqube-server/2025.4/user-guide/issues/solution-overview"
    supports: alternative
    claim: "SonarQube 는 이전 분석의 이슈와 이번 분석의 이슈를 파일 안에서 짝짓는다. 다음 셋 중 하나면 같은 이슈다 — ① 같은 규칙 + 같은 line hash(첫 줄 내용에서 공백을 뺀 해시. 메시지는 달라도 된다) ② 같은 규칙 + 같은 줄 번호 + 같은 메시지 ③ 파일 안에서 옮겨진 블록 안의 같은 줄 + 같은 메시지. 짝이 없으면 Fixed 로 보고, Fixed 였던 이슈가 다시 짝지어지면 reopen 한다. False positive 와 Accepted 는 사람이 정한 상태이고, 사람이 다시 열 수 있다. 상태가 이미 False positive 인 이슈가 코드가 바뀌어 짝을 잃으면 어떻게 되는지는 이 페이지에 명시가 없다(일반 규칙대로 Fixed 처리로 보이지만 미확인)."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "레포 미사용", latest: "문서 2025.4 판 (짝짓기 규칙은 9.8 · 10.1 · 2025.1 사이에 바뀌었다는 검색 요약 — 판별 대조는 안 함)"}
    certainty: confirmed
  - url: "https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/sarif-support-for-code-scanning"
    supports: alternative
    claim: "GitHub code scanning 은 SARIF partialFingerprints 중 primaryLocationLineHash 하나만 써서 커밋 · 브랜치 사이의 같은 결과를 알아본다. ruleId 와 파일 경로가 실행마다 같아야 한다. 경로가 달라지면 새 알림이 생기고 옛 알림은 닫혀 같은 결과가 여러 알림이 된다. 지문 없이 API 로 올리면 중복 알림이 보일 수 있다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://docs.semgrep.dev/semgrep-code/remove-duplicates"
    supports: alternative
    claim: "Semgrep match_based_id 는 「파일 경로 + 규칙 이름 + 메타변수 값을 채운 규칙 패턴」의 해시에, 그 파일 안의 매치 순번(index)을 붙인 것이다. 무관한 줄이 끼어들어도 ID 가 그대로라 중복으로 묶인다. 한 브랜치에서 triage(무시 등)한 지적은 다른 브랜치에서도 triage 된 것으로 표시된다. 매치된 코드가 바뀌면 ID 가 바뀐다는 명시는 없다(패턴이 바뀌면 바뀐다는 것은 추론이다)."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://phpstan.org/user-guide/baseline"
    supports: alternative
    claim: "PHPStan baseline 항목은 message(정규식 꼴) · path · count(파일당 허용 횟수)다. 줄 번호는 없다. 어떤 인스턴스를 무시하는지 가리키지 못한다. 무시하던 오류가 더는 나지 않으면 알리고 `--fix` 로 줄인다. 무시 이유를 적을 칸이 없다는 것을 단점으로 문서가 밝힌다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://eslint.org/blog/2025/04/introducing-bulk-suppressions/"
    supports: alternative
    claim: "ESLint bulk suppressions(v9.24.0 도입)는 「파일 → 규칙 → count」 키다. 같은 파일 · 같은 규칙의 위반 수가 늘면 줄 단위로 새것과 옛것을 가릴 수 없어 「ESLint will report all of them」 — 새 지적을 묻지 않는 쪽으로 넘어진다. 다만 하나를 고치고 하나를 새로 들여 수가 같으면 새 위반이 묻힐 수 있는데, 이 결과를 글이 직접 말하지는 않는다(count 설계에서 나오는 추론)."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "레포 미사용", latest: "v9.24.0 에서 도입. eslint.org 배너에 v9.x 지원 종료 2026-08-06 (검색 결과 안 문구 — 직접 확인 안 함)"}
    certainty: uncertain
  - url: "https://googlesamples.github.io/android-custom-lint-rules/api-guide/messages.md.html"
    supports: alternative
    claim: "실패 사례. Android lint baseline 은 줄 번호가 아니라 「파일 안의 오류 메시지」로 짝짓는다. 메시지가 일반적이면(예: 모두 'Unused import') 「match them in order」 하여 엉뚱한 인스턴스와 짝지어진다. 정체가 빠진 키 때문에 다른 지적이 억제된다. 메시지 문구를 바꾸면 baseline 이 안 맞아 옛 지적이 새 지적으로 나온다. Google 의 lint API 안내서이고, 사용자용 공식 baseline 페이지는 아니다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://github.com/gitleaks/gitleaks"
    supports: alternative
    claim: "gitleaks 의 .gitleaksignore 는 지적마다 붙는 Fingerprint 로 무시한다. README 예시 꼴은 `<commit>:<file>:<rule>:<line>` 이다(형식 정의는 없고 'experimental' 이라 밝힌다). 커밋과 줄이 키에 들어 있다. baseline 보고서로 옛 지적을 무시하는 기능도 있으나 짝짓는 방법은 README 에 없다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://docs.snyk.io/developer-tools/snyk-cli/commands/ignore"
    supports: alternative
    claim: "Snyk ignore 는 이슈 ID(선택적으로 경로를 하위 키로)를 키로 하고, reason(자유 글) · expiry 칸을 둔다. expiry 기본값은 30일이고 `--file-path` 와 함께면 없다. 실패 사례: 만료 날짜 형식이 틀리면 「the ignore will be respected and persist indefinitely」 — 시간으로 무효화하는 조건이 조용히 꺼진다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
repo_claims:
  - id: RC1
    path: "shared/docreview/scripts/docreview_route.py"
    anchor: "def _bucket"
    line: 242
    claim: "docreview 지적의 정체 bucket 은 sha1(\"layer|category|anchor\")[:8] 이다. 요약 글은 키에 없다. 최종 id 는 `<bucket>#r<라운드>.<k>` 이고 k 는 그 라운드 · 그 bucket 의 순번이라서, 같은 절 · 같은 분류의 다른 결함은 합쳐지지 않는다(설계 §6.2 「정체성」 docs/superpowers/specs/2026-09-06-document-review-redesign-design.md:298)."
    touches: []
    decides: [OQ15]
  - id: RC2
    path: "shared/docreview/scripts/docreview_route.py"
    anchor: "def _resolve_ids_and_lineage — resolve_lineage"
    line: 976
    claim: "라운드를 건너 같은 지적을 알아보는 키는 계보(lineage)다. 리뷰어가 단 supersedes 가 이전 id 를 가리키면 그 계보를 잇는다. 없으면 같은 bucket 의 아직 열린 이전 지적을 순번 낮은 것부터 하나씩 잇는다. 남은 것은 새 계보다. 같은 bucket 의 직전 계보가 기각 원장(rejected_lineages)에 있으면 새 지적을 지우지 않고 revived 에 사유와 함께 담는다."
    touches: []
    decides: [OQ15]
  - id: RC3
    path: "docs/superpowers/specs/2026-09-06-document-review-redesign-design.md"
    anchor: "### 6.3 라우팅 규칙 — 「기각된 계보의 부활」 행"
    line: 333
    claim: "설계가 정한 규칙: 기각된 계보의 부활은 라우터가 원장으로 대조한다(재비판자는 이력을 받지 않는다). 「새 finding 은 지우지 않고 게이트 텍스트에 「기각 계보 재상승 — <기각 사유>」를 붙여 사람이 본다」. 사용자 기각 · 재비판 reject 는 「그 id 하나에만 닿는다」(같은 문서 :304-305)."
    touches: []
    decides: [OQ15]
  - id: RC4
    path: "docs/superpowers/specs/2026-09-27-review-stopping-criterion-design.md"
    anchor: "기각 대안 표 「must-catch 축의 재제기 금지(버킷 동일 → 자동 처분)」 행 · `### 재결정` R2"
    line: 325
    claim: "레포가 이미 기각한 선례. 재제기 금지를 bucket(층|축|절)으로 막는 안을 버렸다. 이유는 「탐지기는 사용자 결정을 못 보므로(프레이밍 차단) 「새 근거」를 판정할 수 없고, 엔진이 가를 수 있는 버킷으로 막으면 같은 절의 새 충실도 결함이 묻힌다」이다. 결론: must-catch 는 재제기를 허용하고 revived 로 공시하며, 재제기 금지는 advisory 축에만 둔다(R2, 사용자 선택 B5, :412)."
    touches: []
    decides: [OQ15]
  - id: RC5
    path: "shared/docreview/scripts/docreview_state.py"
    anchor: "def _record_advice"
    line: 1271
    claim: "advisory 항목의 1회 규칙. 키는 bucket(층|축|앵커)이다. 이전 라운드에 오른 bucket 은 목록에 다시 올리지 않고 repeat 로만 센다. 설계 「알려진 한계 2」(review-stopping-criterion-design.md:352)가 이 키는 절 단위라 거칠다고 공시한다 — 「라운드 2 에 편집이 §2 에 새로 들인 방향 결함도 repeat 로 접힌다」. 키가 너무 넓어 진짜 새 지적이 묻히는 레포 안 실례이고, 손실은 advisory 층에 한정한다고 적혀 있다."
    touches: []
    decides: [OQ15]
  - id: RC6
    path: "shared/docreview/scripts/docreview_route.py"
    anchor: "리뷰어 사이의 겹침 — key = (it[\"layer\"], it[\"category\"], it[\"anchor\"], it[\"disposition\"], it[\"summary\"])"
    line: 419
    claim: "한 라운드 안 리뷰어 간 흡수(dedup)의 키는 (층, 분류, 앵커, 처분, 요약 글자)다. 같으면 앞 리뷰어 것만 남기고 absorbed 로 센다. 「비슷하기만 한 항목은 재비판으로 간다」 — 뜻이 같은지는 기계가 아니라 재비판자의 same_as 판단에 맡긴다."
    touches: []
    decides: [OQ15]
  - id: RC7
    path: "shared/adjudication/adjudication.py"
    anchor: "def absorbed · def suppressed"
    line: 61
    claim: "shared/adjudication 은 회계만 하고 흡수 키를 갖지 않는다. 키는 소비자(RC6 · RC9 · RC10)가 정한다. 처분 이름은 둘이 갈린다: absorbed(중복이 흡수처에 귀속된 것 — 소실 아님, degrade 아님)와 suppressed(판정자의 판단이 아니라 규칙이 정한 배제 — reject 와 합치지 않고, degrade 도 차단도 아님)."
    touches: []
    decides: [OQ15]
  - id: RC8
    path: "shared/docreview/scripts/docreview_route.py"
    anchor: "def _contradiction_binding · _classify_items 의 contradicts 처리"
    line: 712
    claim: "리뷰어가 지적에 contradicts: D<r>.<n>(이미 내린 결정 id)을 달면 엔진이 결정 원장과 대조한다. 그 지적이 결정에 묶이는 조건은 넷이다: ① 사용자가 채택(adopt)한 결정 ② 뒤 결정이 잇지(supersedes) 않음 ③ 지적의 앵커가 결정이 닿은 절 안 ④ 울타리 절이 아님. 묶여도 「처분은 건드리지 않는다」 — 지적을 지우지 않고 _decision_backed 로 표시만 한다(docreview_advice.py:47 에서 must-catch 로 친다). 결정 id 가 키이고, 결정 줄은 문서의 결정 기록 절에 있어 리뷰어가 문서로 읽는다(agents/doc-critic.md:68)."
    touches: []
    decides: [OQ15]
  - id: RC9
    path: "plugins/quality-gates/scripts/synthesize_findings.py"
    anchor: "def dedup — (file, line, severity) 그룹핑"
    line: 309
    claim: "qg 코드 리뷰의 dedup 키는 (file, line, 정규화한 severity)다. CHANGELOG [2.14.13](plugins/quality-gates/CHANGELOG.md:4003-4032)이 이 키의 실패를 기록한다. adversarial 이 새 지적을 낼 수 있게 된 뒤로 같은 좌표가 「같은 줄의 다른 결함」일 수 있게 되었다. 재현: SQL injection 지적이 null check 지적에 흡수돼 사라졌고, 살아남은 행이 adversarial 을 sources 에 달아 허위 귀속까지 났다. 수정은 승격 항목을 그룹핑에서 빼 「소실이 아니라 중복 쪽」으로 돌린 최소 봉쇄였다. 키 설계 자체는 「여전히 미해결」(CHECKS-07)로 남았다."
    touches: []
    decides: [OQ15]
  - id: RC10
    path: "plugins/quality-gates/scripts/synthesize_artifact_findings.py"
    anchor: "def dedup_key · def stagnation_key"
    line: 43
    claim: "qg artifact-critique 의 키는 둘이다. dedup_key = sha1(norm(category) \\0 norm(target_anchor) \\0 norm(summary))[:12] — 요약 글자가 키에 들어간다. stagnation_key = sha1(category \\0 target_anchor)[:12] — 요약이 빠진 넓은 키로, 정체 감지용이다. adversarial 판정은 finding_key == dedup_key 로 짝짓는다."
    touches: []
    decides: [OQ15]
  - id: RC11
    path: "shared/docreview/scripts/docreview_state.py"
    anchor: "cmd_decide — reject 갈래 · entry[\"supersedes\"]"
    line: 1587
    claim: "사용자 결정 원장(decision_log) 줄은 D<라운드>.<순번> id 와 finding_ids · lineage · choice · quote(사용자 말)를 담는다. 같은 lineage 의 이전 결정이 있으면 supersedes 로 잇는다. reject 를 고르면 rejected_lineages[lineage] = {by: user, why: quote, round} 를 쓴다 — 사용자 답을 계보 단위로 기억한다."
    touches: []
    decides: [OQ15]
  - id: RC12
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### 4. 돌아오기 — 「- 기록:」 결정 기록 세 갈래"
    line: 53
    claim: "사용자 결정 원문을 설계문서 `## 결정 기록` 에 남기는 갈래는 셋이다. 리뷰가 열려 있으면 엔진 log-decision, 리뷰 전이면 손으로(첫 라운드가 기준선으로 받는다), 리뷰가 닫혔으면 절 끝에 손으로 쓴다. 「다음 재리뷰가 그 줄을 기록으로 읽는다(재리뷰를 시작한 뒤에 쓴 줄은 다시 묻는다)」 — 답을 기억하는 운반체가 문서 본문의 결정 기록 절이다(spec-distill CHANGELOG :367 「다음 라운드에 그 결정이 「허가 없이 바뀜」 질문으로 돌아오지 않는다」)."
    touches: []
    decides: [OQ15]
  - id: RC13
    path: "plugins/spec-distill/skills/pm-interview/SKILL.md"
    anchor: "## 닫힘 · 재개방"
    line: 460
    claim: "인터뷰 결정 원장은 차원 · OQ 를 사용자가 답한 S<N>(원문 발화) 인용으로만 닫는다(check_brief.py:971 ANCHOR_RE 와 coverage_anchor_failures 가 앵커가 실재하는지만 잰다 — 그 S 가 닫힘을 정당화하는지는 안 본다). 무효 조건: 새 답 · 외부 근거 · 코드 사실이 닫힘 근거 S 와 충돌하면 closed → open 으로 재개방한다. 사유와 conflicts_with: S<N> 을 남기고, 다시 닫을 때는 새 S 를 인용한다. 충돌인지는 orchestrator 가 판단한다."
    touches: []
    decides: [OQ15]
  - id: RC14
    path: "shared/docreview/scripts/docreview_state.py"
    anchor: "def cmd_advice docstring — 「새 원장은 목적지에 같은 키의 줄이 있어도 다시 적는다(겹침을 택한다)」"
    line: 2588
    claim: "레포의 기록 멱등 쪽 선례. 키가 사건을 가를 수 없을 때는 중복 기록(겹침)을 택한다. 겹침은 되돌릴 수 있고 소실은 되돌릴 수 없다는 판단이다. 같은 계열 교훈은 qg CHANGELOG [2.14.13]의 「소실이 아니라 중복 쪽」(RC9)."
    touches: []
    decides: [OQ15]
unanswered: "CodeRabbit · Copilot 코드 리뷰가 사람이 손으로 resolve · dismiss 한 지적을, 코드가 그대로일 때 다시 내는지는 공식 문서에 명시가 없다(Bugbot 은 직원 포럼 답만 있다). SonarQube 에서 False positive 상태인 이슈가 짝을 잃은 뒤 어떻게 되는지도 문서에 명시가 없다. ESLint v9 지원 종료일은 검색 결과의 배너 문구로만 봤다."
```

주문의 세 갈래 요약:

- **(1) 레포 안 선례:**
  - 같은 지적을 알아보는 키는 자리마다 다르다.
    - docreview: 정체는 bucket = (층 · 분류 · 앵커)이고, 라운드를 건너는 동일성은 계보(supersedes 사슬)다 (RC1 · RC2).
    - 리뷰어 간 흡수는 요약 글자까지 넣은 5칸 키를 쓴다 (RC6).
    - qg: 코드 리뷰는 (파일 · 줄 · 심각도), artifact-critique 는 (분류 · 앵커 · 요약) 해시다 (RC9 · RC10).
    - shared/adjudication 은 회계만 하고 키를 갖지 않는다 (RC7).
  - 사용자 답은 세 운반체에 남는다: 결정 원장의 계보, 문서의 결정 기록 절, 인터뷰의 S 인용 (RC11 · RC12 · RC13).
  - 레포는 must-catch 지적을 bucket 이 같다는 이유로 자동 억제하는 안을 명시적으로 기각했다. 지금 동작은 지우지 않고 revived 로 공시하는 것이다 (RC3 · RC4).
- **(2) 바깥 선례:** 키 잡는 방식이 크게 갈린다.
  - 자연어 · 의미 키: CodeRabbit, Bugbot 규칙
  - 스레드 상태 키: Bugbot dedupe
  - 인용 + 읽을 때 검증 · 만료 키: Copilot Memory
  - 규칙 + 줄 해시 · 메시지 키: SonarQube, GitHub code scanning
  - 경로 + 규칙 + 패턴 해시 + 순번 키: Semgrep
  - 파일 + 메시지 · 규칙 + 횟수 키: PHPStan, ESLint, Android lint
  - 커밋 · 파일 · 규칙 · 줄 키: gitleaks
  - 이슈 ID + 만료일 키: Snyk

  무효 조건도 갈린다. 코드가 바뀌어 짝을 잃으면 새 지적으로 보는 쪽(SonarQube · code scanning · Semgrep), 읽을 때 인용을 다시 검증하는 쪽(Copilot), 시간 만료(Copilot · Snyk), 사람이 직접 정리하는 쪽(CodeRabbit)이 있다.
- **(3) 실패 사례:**
  - 키가 너무 넓은 경우: qg 의 (파일 · 줄 · 심각도) 키가 SQL injection 지적을 흡수했다 (RC9). advisory 의 절 단위 bucket 이 새 방향 결함을 repeat 로 접는다 (RC5). Android lint 의 일반적인 메시지가 엉뚱한 인스턴스와 짝지어진다.
  - 키가 신호를 못 받는 경우: Bugbot 은 글로 쓴 「맞다」 답글을 억제 신호로 받지 않을 수 있다.
  - 만료 조건이 조용히 꺼지는 경우: Snyk 은 만료 날짜 형식이 틀리면 무기한 유지된다.
  - 반대 방향: ESLint 는 수가 늘면 전부 다시 내서 새 지적을 묻지 않는 쪽으로 넘어진다.

V1(본체): RC86–RC99(←RC1–14) — docreview_route.py _bucket 242 · _resolve_ids_and_lineage 942 · stopping-criterion-design.md 325 행 실재 · synthesize_findings.py dedup 309 · CHANGELOG CHECKS-07 4023 · 4032 · synthesize_artifact_findings.py 43 · 48 · docreview_state.py _record_advice 1271 · cmd_decide 1555 — 확인(나머지는 같은 파일 안 앵커, 줄번호 ±).

### 조사 11 — orchestrator · R10 · 묶음 6

- 확인 RC100 — 확인 — git show ac2782e4(Merge PR #269 docs/roadmap-close-receivers) — 바뀐 파일은 docs/superpowers/specs/ 설계문서 넷(2026-10-17-epic-conductor-design.md · 2026-10-23-r8-device-leftovers-design.md · 2026-10-23-rules-docs-cleanup-design.md · 2026-10-25-qg-range-repairs-design.md)뿐이다. plugins/spec-distill/references/conducting.md · redecompose.md 는 바뀌지 않아 RC77 · RC78 은 그대로 맞다 [RC100 → OQ20]

## 생성 기록

- docs/superpowers/roadmaps/2026-11-14-qg-epic-roadmap-intent-review-brief/R1.md
- docs/superpowers/roadmaps/2026-11-14-qg-epic-roadmap-intent-review-brief/R2.md
- docs/superpowers/roadmaps/2026-11-14-qg-epic-roadmap-intent-review-brief/R3.md
- docs/superpowers/roadmaps/2026-11-14-qg-epic-roadmap-intent-review-brief/roadmap.md

## 리뷰 1라운드 반영(reviewing-brief)

- S23 — 「1, 2」 뜻 되묻기의 답: 셋 다 고른 것으로(한참 뒤도 알아챈 때다)
- S24 — R8 의 「2」 뜻 확인
- S25 · S26 · S27 · S28 — 리뷰 결정 D1.1 · D1.2 · D1.3 · D1.4 채택(각각 S12/S13 보강 · S18 · S4 · S19 를 다시 정함)
- S29 · S30 · S31 · S32 — 리뷰 2라운드 결정 D2.5 · D2.6 · D2.7 · D2.8 채택
- S33 — 리뷰 3라운드 결정 D3.9 채택 · S34 — 추가 라운드 1회 열기
- S35 — 리뷰 4라운드 결정 채택(추가 라운드는 열지 않음)
