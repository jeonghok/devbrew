---
type: interview-state
seed: docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.md
session_id: 1db2fcc3-3cab-40d9-8250-d061331e0172
phase: 1
coverage:
  floor:
    root_problem:   {status: closed, evidence: "S1(첫 요청 원문 — seed 첫 문단의 출처) + S2 「같은 뿌리 (권장)」 — 토큰 낭비와 공유 누락은 맥락이 대화·메시지에만 쌓이고 파일에 안 남는 같은 뿌리", reopened: 0, reopen_log: []}
    landscape:      {status: closed, evidence: "S4 「하위 agent + 실행기 칸 (권장)」 — 지형(조사 4) 처분: 하위 agent 취함 · agent 팀 · 헤드리스 기본 · herdr 류 외부 실행기 기본은 피함(실행기 칸으로만)", reopened: 0, reopen_log: []}
    skepticism:     {status: closed, evidence: "S8 ST1 판정 「보완」 — 파일 규약은 취하고 읽기 설계 · 행동 직후 결정 기록을 같은 첫 단추로, 되읽기 보증은 산출물 대조로", reopened: 0, reopen_log: []}
    blind_spot:     {status: closed, evidence: "S7 premortem 처분 — 리프레시는 품질 신호 · 일꾼 파일은 대조해 믿기 · 작은 일은 가볍게 받음, 역할은 agent 정의로 기각", reopened: 0, reopen_log: []}
    open_questions: {status: closed, evidence: "S30 「이대로 넘김 (권장)」 — 열린 질문 OQ21–OQ32 를 설계로 넘김", reopened: 0, reopen_log: []}
  derived:
    - {name: internal_research, rationale: "R1 조사에서 repo_claims 첫 산출 — 조사 행위가 함의", status: closed, evidence: "S20 — 조사 8 레포 장치 목록(RC49–RC91)과 조사 1–10 레포 주장 처분: 「있는 것을 새 자리로」 갈아탐을 받음", reopened: 0, reopen_log: []}
    - {name: "걷어낼 장치와 갈아타는 길", rationale: "보고 전문 메시지 규칙(RC1)·기계 상태 표(RC7) 등 지금 장치가 새 규칙과 부딪히고, 도는 로드맵 이전·판 올림이 미정", status: closed, evidence: "S41 조건 붙은 규칙은 적용 조건 칸을 두고 지휘자가 시작 묶음에 골라 실음 + S36(바이트 예산 · 반증 삭제 · 맨 위 안 함 · 반례 확인 승격) · S20 · S21 · S18 · S27", reopened: 2, reopen_log: [{round: 13, reason: "조사 18 — seed 의 규칙 목차 운영 근거가 S24 로 사라지고 합치기가 S27 출처 · 조건을 깎음", conflicts_with: S27}, {round: 14, reason: "조사 20 — 경로 조건 규칙이 격리 worktree 하위 agent 에 안 실리고 플러그인 배포 불가 · .gitignore 가 막음", conflicts_with: S36}]}
    - {name: "플랫폼에 있는 것과 새 파일 규약의 경계", rationale: "세션 간 메시지·agent 팀 mailbox·agent memory 가 대화 계약 일부를 이미 준다(E4·E5·E3) — 있는 것 먼저 대 외부 의존 회피", status: closed, evidence: "S28 지금 안(git 편지함 + 감시자) + 기성 기법(자체 세션 받은 편지함 · asyncRewake) 차용", reopened: 0, reopen_log: []}
    - {name: "일꾼 실행 방식과 역할 경계 집행", rationale: "하위 agent·팀원·세션·claude -p 마다 CLAUDE.md 적재·Skill·실패 노출·도구 권한이 다르다(E2·RC13) — 역할 CLAUDE.md 대 tools allowlist", status: closed, evidence: "S4 실행 방식 · S7 역할은 agent 정의로 기각(역할 CLAUDE.md 적재 방식은 OQ7 로 남김)", reopened: 0, reopen_log: []}
    - {name: "파일 글의 믿음 경계", rationale: "지금은 하위가 쓸 수 있는 파일을 판정 근거로 안 쓴다(RC5) — inbox·결과 파일 보고·해시 승인이 이 경계를 넓힌다", status: closed, evidence: "S7 「일꾼 파일은 대조해 믿기」", reopened: 0, reopen_log: []}
    - {name: "토큰 재기와 리프레시 방식", rationale: "압축은 사용자만(RC3), 하위 agent 는 자동 압축(E1), 단계마다 새 agent(RC12) — 측정원·문턱·과제 단위", status: closed, evidence: "S6 mod 로 측정 · 표시, S7 리프레시는 품질 신호, S12 진행 agent 교대는 기존 장치에 맡김 · 과제 = 에픽, S13 지휘 세션은 사용자가", reopened: 0, reopen_log: []}
    - {name: "결정론 경계(P8)와 단계표", rationale: "P8 이 순서 강제 결정론을 금한다(RC2) — 무엇을 어디까지 결정론으로", status: closed, evidence: "S37 순서는 스크립트가 지키되 사람 승인 탈출구, 동시 수는 레포 설정(무거운 일 기본 2) — S14 를 다듬음", reopened: 1, reopen_log: [{round: 13, reason: "조사 18 — 순서 강제가 탈출구 락과 충돌, 동시 2 리터럴이 이식성 줄과 충돌", conflicts_with: S14}]}
    - {name: "팀 상태 배치와 기계 간 조정", rationale: "잠금·표지가 한 기계 파일시스템 전제(RC8), 추적/무시 파일 규칙(RC9), 병렬 권장 3 대 동시 2 상한(RC14)", status: closed, evidence: "S35 지휘자 상태 브랜치(코드 없음 · STATUS 는 그 지휘자만 · 편지함 한 글 한 파일 · main 에 머지 안 함) + S34 코드는 기본 main · 선택으로 로드맵 취합 + S9 · S23 · S24 · S26", reopened: 1, reopen_log: [{round: 11, reason: "조사 13 — main 직접 커밋 금지 · 보호 권장과 S17(STATUS 를 계산해 커밋)의 자리가 충돌, 사용자가 S33 으로 다시 엶", conflicts_with: S17}]}
    - {name: "사람이 보는 면", rationale: "작업 목록 도구가 새 모델에서 기본으로 빠짐(E6, 이 세션 도구 목록에도 없음)·SessionStart 훅 부재(RC10)", status: closed, evidence: "S3 STATUS 파일 + S6 「1」 mod 하나로", reopened: 0, reopen_log: []}
    - {name: "작은 일과 작업 방식 결합", rationale: "trivia escape(RC11)와 「작은 일도 지휘자」, superpowers 필수 결합(RC6)", status: closed, evidence: "S7 「작은 일은 가볍게」 + seed 확인 문장(superpowers 에 묶이지 않음)", reopened: 0, reopen_log: []}
orchestration:
  focused_dimension: root_problem
  research_dispatches: {coverage_mapper: 1, blind_spot_prober: 2, steelman_builder: 1, repo_researcher: 3, open_researcher: 10}
  research_limit: 60
  saturation_limit: 5
  research_log:
    - {n: 1, device: coverage-mapper, round: 1, batch: 1, changed: [], opened: [OQ2], summary: "derived 11 제안(9로 묶어 admit), RC1–14, 웹 E1–E6"}
    - {n: 2, device: orchestrator, round: 1, batch: 2, changed: [], opened: [], summary: "V1 확인 14건 + 이 세션 도구 목록에 작업 목록 도구 없음 관찰"}
    - {n: 3, device: blind-spot-prober, round: 2, batch: 3, changed: [OQ3, OQ5], opened: [], summary: "숨은 가정 8 · 실패 양식 10 — agent 팀 대 리프레시 충돌, 캐시 재작성, 역할 CLAUDE.md 미적재"}
    - {n: 4, device: open-researcher, round: 2, batch: 3, changed: [OQ3, OQ4], opened: [], summary: "공식 병렬 방식 다섯 · herdr · claude-squad · ccmanager · workmux · Gas Town 지형"}
    - {n: 5, device: open-researcher, round: 2, batch: 3, changed: [OQ5, OQ6], opened: [], summary: "mod 실재 · turn.step 요청별 토큰 · 상태줄 칸 · OTel query_source"}
    - {n: 6, device: open-researcher, round: 3, batch: 4, changed: [OQ4], opened: [], summary: "한 서버 한 세션: 보내기 가능(RC+claude.ai), 꺼진 수신자 보존 미문서, 플러그인 monitor · asyncRewake · Channels · Routines 지형"}
    - {n: 8, device: repo-researcher, round: 5, batch: 5, changed: [OQ10], opened: [], summary: "지휘 · 파이프라인 장치 목록 43건 — machine.md · relay · report · suite-lock · 설계문서 절 · control_plane · 로드맵 · 묶음 · 인터뷰 state · docreview 원장"}
    - {n: 9, device: open-researcher, round: 6, batch: 6, changed: [OQ15], opened: [OQ15], summary: "S9 를 통째로 대신할 기성품 없음 — Channels 위 버스(개발 플래그) · mcp_agent_mail(상주 서버 · 끌어오기) · git 기반(Thrum · claude-coordinator) · ntfy(알림 층)"}
    - {n: 10, device: open-researcher, round: 8, batch: 7, changed: [OQ18], opened: [], summary: "superpowers 경로 · 원장 규약, Matt Pocock · pstack 주 skill 은 disable-model-invocation(본체가 원문으로 확인), 산출 경로 · 계획 형식이 다름"}
    - {n: 11, device: repo-researcher, round: 11, batch: 8, changed: [OQ30], opened: [OQ33], summary: "superpowers 형식 결합 지점 30 — 다른 형식이면 「계획 없음」 · 판정 0 · 후보 없음으로 조용히 셈"}
    - {n: 12, device: open-researcher, round: 11, batch: 8, changed: [OQ21, OQ30], opened: [], summary: "같은 기계 소켓은 모든 제공자 · Remote Control 불필요 · 자기 자식 예외, asyncRewake timeout 600초 · 반복 없음, monitor idle 깨우기 공식 미명시, DMI skill 은 하위 agent 불가 · -p 길 미실측"}
    - {n: 13, device: open-researcher, round: 11, batch: 8, changed: [OQ21, OQ13], opened: [], summary: "main 직접 커밋 금지와 충돌 — orphan 데이터 브랜치 · 한 글 한 파일 · 읽을 때 계산 · Issues 선례"}
    - {n: 14, device: open-researcher, round: 11, batch: 8, changed: [OQ27], opened: [], summary: "소급 가능한 것은 세션 기록뿐(30일) — message.id 중복 제거 · 2.1.293–2.1.306 하위 출력 과소"}
    - {n: 15, device: orchestrator, round: 13, batch: 9, changed: [], opened: [], summary: "SDD 원장 형식 실재 · plan_specs 실행 확인 · 설치 판 · 기록 날짜"}
    - {n: 16, device: repo-researcher, round: 13, batch: 10, changed: [OQ32, OQ23, OQ31, OQ21], opened: [], summary: "브랜치 검사는 생성 때 알림만 · 상태 루트는 git 무시 강제 · plumbing 선례(qg) · 관문/검수/상한 대응표"}
    - {n: 17, device: open-researcher, round: 13, batch: 10, changed: [OQ28, OQ26], opened: [OQ35], summary: "표시 전용 mod 는 권한 이벤트 미구독 · validate 로 hooks/calls 기계 확인 · $.env.get 자기 no-op · mod 가 $.clock.every + $.process.run + $.prompt.submit 으로 감시자 겸임 가능"}
    - {n: 18, device: blind-spot-prober, round: 13, batch: 10, changed: [OQ22, OQ24], opened: [OQ36], summary: "120줄 근거는 자동 메모리 규약 · 합치기가 조건을 깎음 · 새 규칙 맨 위 쏠림 · 두 번 승격이 오류를 굳힘 · path-scoped rules · 숫자는 이미 허용 · 순서 강제의 탈출구 · 동시 2 는 이식성 충돌"}
    - {n: 19, device: orchestrator, round: 14, batch: 11, changed: [OQ31], opened: [], summary: "SDD 고침 루프 5 라운드(1–3 이어 부름 · 4–5 강한 모델 · 차단기) · managed settings 없음"}
    - {n: 20, device: open-researcher, round: 14, batch: 12, changed: [OQ36, OQ22], opened: [OQ40], summary: "경로 조건 규칙도 역할 CLAUDE.md 와 같은 함정 — 맞는 파일을 건드릴 때만 · 하위 agent 는 메인 것 물려받지 않음 · 격리 worktree 하위 agent 는 worktree 규칙을 읽기로도 안 실음 · 플러그인 배포 불가 · .gitignore 가 .claude/rules 를 막음"}
    - {n: 7, device: steelman-builder, round: 3, batch: 4, changed: [OQ7, OQ8], opened: [], summary: "ST1 refined — P1·P2·P4 전제 충돌, 읽기 설계 · 결정 외재화"}
  saturation_log:
    - {k: 1, round: 10, verdict: not_saturated, basis: "최근 두 묶음(6 · 7) 모두 결정을 바꿈 — OQ15 · OQ18, 조사 10 이 superpowers 형식 결합이라는 새 결정을 엶", gaps: ["confirm: Matt Pocock · pstack disable-model-invocation 원문 · 하위 agent Skill 호출 동작 [OQ18, OQ30] open-researcher", "explore: superpowers 형식에 묶인 레포 읽기 지점 전수 [OQ30, OQ10] repo-researcher", "confirm: 자체 세션 받은 편지함 · asyncRewake 조건 · Channels API 키 충돌 [OQ15, OQ21] blind-spot-prober", "explore: 여러 기계 git 동시 쓰기 기성 해법 [OQ21, OQ13] open-researcher", "explore: 토큰 기준선을 지금 무엇으로 잴 수 있나 [OQ27, OQ26] steelman-builder"], user_choice: null}
    - {k: 2, round: 12, verdict: not_saturated, basis: "최근 두 묶음(7 · 8) 모두 결정을 바꾸고 엶 — 조사 12 를 본문 없음으로 실패 처리(판정자 입력 추출기 결함: 블록 안 ### 소제목에서 잘림, 본체가 고침)", gaps: ["explore: 조사 12 주제 재조사 [OQ30, OQ28, OQ15] open-researcher — 추출기 결함이라 원문은 state 에 온전함", "confirm: 지휘자 상태 브랜치와 브랜치 이름 검사 · rebase 금지 · 한 기계 여러 worktree 쓰기 [OQ21, OQ13, OQ34] repo-researcher", "confirm: **Spec:** 없는 계획 등 fixture 실행 · SDD progress.md 의 Ruling: · BLOCKED [OQ25, OQ30, OQ33] orchestrator", "confirm: 설치 판 · 세션 기록 날짜 · placeholder 문장 [OQ27, OQ26] orchestrator", "explore: OQ32 · OQ31 · OQ23 레포 대응 [OQ32, OQ31, OQ23] repo-researcher", "explore: mod 권한 범위 · kill switch [OQ28] open-researcher", "explore: OQ22 · OQ24 숨은 가정 [OQ22, OQ24] blind-spot-prober"], user_choice: null}
    - {k: 3, round: 13, verdict: not_saturated, basis: "최근 두 묶음(9 · 10) 중 묶음 10 이 결정을 바꾸고 엶(OQ31 · OQ32 · OQ28 · OQ26 · OQ22 · OQ24, 상태 브랜치 이름 · 최소 판 · kill switch)", gaps: ["confirm: 기본 가드 · mod 자식 env [OQ28, OQ35] orchestrator", "confirm: superpowers SDD 과제 · 최종 리뷰 구성과 재시도 횟수 [OQ31, OQ23, OQ32] orchestrator", "confirm: 상태 브랜치 이름 · git workflow 예외 반대 논거 [OQ21] steelman-builder", "confirm: P8 개정 파급 전수 · 강제 장소 [OQ24, OQ37] repo-researcher", "confirm: 경로 조건 규칙이 일꾼(하위 agent · 격리 worktree)에게 실리는지 [OQ22, OQ36, OQ16] open-researcher", "explore: 기존 지휘 기록 · 도는 로드맵 이전 목록 [OQ29, OQ10] repo-researcher"], user_choice: S40}
    - {k: 4, round: 15, verdict: not_saturated, basis: "최근 두 묶음(11 · 12) 모두 결정을 엶 — OQ38(SDD 고침 루프) · OQ40(경로 조건 규칙 불적재)", gaps: ["confirm: 시작 묶음에 규칙을 다시 적는 이음매 · 바이트 예산 단위 [OQ40, OQ36, OQ22] repo-researcher", "confirm: SDD fix round 줄 · 차단기를 devbrew 가 읽나 · superpowers 최소 판 [OQ38, OQ31] repo-researcher", "explore: S41 숨은 가정 — 지휘자 압축 뒤 · 플러그인 사용 레포 [OQ40, OQ22] blind-spot-prober", "explore: 로그인 종류 · 기본 가드 [OQ28] orchestrator"], user_choice: S42}
  open_decisions:
    - {id: OQ1, text: "이 재설계가 먼저 풀어야 할 뿌리 문제는 무엇인가", dimension: root_problem, status: resolved, resolved_by: S2}
    - {id: OQ2, text: "지휘 중 작업 목록을 무엇으로 띄울까 — 플랫폼 작업 목록 도구 켜기 · STATUS 파일 · 둘 다", dimension: "사람이 보는 면", status: resolved, resolved_by: S3}
    - {id: OQ3, text: "일꾼(담당자)을 무엇으로 돌릴까 — 하위 agent · agent 팀원 · 따로 띄운 세션 · 헤드리스 claude -p · 외부 실행기", dimension: "일꾼 실행 방식과 역할 경계 집행", status: resolved, resolved_by: S4}
    - {id: OQ4, text: "다른 기계의 지휘자끼리 글을 무엇으로 나를까 — git 원격의 파일 · 플랫폼 세션 메시지 · 둘 다", dimension: "팀 상태 배치와 기계 간 조정", status: resolved, resolved_by: S9}
    - {id: OQ5, text: "토큰을 무엇으로 재고 어디에 보일까 — 세션 기록 · 상태줄 입력 · 그 밖의 공식 수단", dimension: "토큰 재기와 리프레시 방식", status: resolved, resolved_by: S6}
    - {id: OQ6, text: "터미널 현황을 보여 줄 「모드」가 무엇인가 — Claude Code mod(대화 옆 패널·상태줄)인지", dimension: "사람이 보는 면", status: resolved, resolved_by: S6}
    - {id: OQ7, text: "역할 CLAUDE.md(할 일 · 하지 않을 일)를 일꾼이 실제로 읽게 하는 길 — 역할 폴더 CLAUDE.md 는 자동 적재되지 않는다(조사 3)", dimension: "일꾼 실행 방식과 역할 경계 집행", status: resolved, resolved_by: S10}
    - {id: OQ8, text: "리프레시 문턱 — 과제 경계 · 맥락 크기 중 무엇에, 과제 단위는 devbrew 의 무엇", dimension: "토큰 재기와 리프레시 방식", status: resolved, resolved_by: S12}
    - {id: OQ9, text: "무엇을 스크립트가 강제하고 무엇을 모델 판단에 둘까(P8 개정 범위)", dimension: "결정론 경계(P8)와 단계표", status: resolved, resolved_by: S14}
    - {id: OQ10, text: "지금 장치 중 무엇을 걷어내고 무엇을 새 팀 구조로 갈아탈까", dimension: "걷어낼 장치와 갈아타는 길", status: resolved, resolved_by: S20}
    - {id: OQ12, text: "과제(=에픽) 폴더 INTENT.md 를 어떻게 둘까 — 에픽 묶음을 INTENT.md 로 · 따로 만들기", dimension: "걷어낼 장치와 갈아타는 길", status: resolved, resolved_by: S21}
    - {id: OQ13, text: "STATUS.md 와 machine.md 의 관계", dimension: "팀 상태 배치와 기계 간 조정", status: resolved, resolved_by: S17}
    - {id: OQ14, text: "75KB 지휘 절차서를 어떻게 다룰까", dimension: "걷어낼 장치와 갈아타는 길", status: resolved, resolved_by: S18}
    - {id: OQ15, text: "세션 간 · 기계 간 지휘자 대화 수단 — 이미 있는 도구 중 S9 안보다 나은 것이 있나", dimension: "플랫폼에 있는 것과 새 파일 규약의 경계", status: resolved, resolved_by: S28}
    - {id: OQ16, text: "역할 폴더(역할별 CLAUDE.md)를 어디에 둘까 — 레포 공통 · 팀(로드맵) 폴더 안", dimension: "팀 상태 배치와 기계 간 조정", status: resolved, resolved_by: S23}
    - {id: OQ17, text: "레포 안 MEMORY.md 가 Claude 자동 메모리 MEMORY.md 와 이름이 겹치는 것을 어떻게 할까", dimension: "팀 상태 배치와 기계 간 조정", status: resolved, resolved_by: S24}
    - {id: OQ18, text: "다른 작업 방식(Matt Pocock skills · pstack)을 단계표에 끼우려면 각 skill 의 입력 · 산출 규약이 무엇인가", dimension: "작은 일과 작업 방식 결합", status: resolved, resolved_by: S29}
    - {id: OQ19, text: "역할 · 규칙을 레포 공통에 두면 팀(로드맵)을 나누는 의미가 약해지지 않나 — 팀이 무엇으로 갈리는가", dimension: "팀 상태 배치와 기계 간 조정", status: resolved, resolved_by: S26}
    - {id: OQ20, text: "HANDBOOK · 팀 규칙 목차에 잘못 쌓인 맥락을 막는 경계 장치 중 무엇을 둘까", dimension: "걷어낼 장치와 갈아타는 길", status: resolved, resolved_by: S27}
    - {id: OQ21, text: "inbox/ 와 STATUS.md 를 어느 브랜치에 커밋 · 푸시하고, 여러 지휘자의 동시 쓰기 충돌을 어떻게 피할까", dimension: "팀 상태 배치와 기계 간 조정", status: resolved, resolved_by: S35}
    - {id: OQ22, text: "팀 규칙 목차의 새 이름과 HANDBOOK · 팀 전용 목록의 상한", dimension: "걷어낼 장치와 갈아타는 길", status: open, resolved_by: null}
    - {id: OQ23, text: "역할 목록과 devbrew 이름 — my-team 의 대장은 지휘자인가, 1차 검수는 누가 하는가", dimension: "일꾼 실행 방식과 역할 경계 집행", status: open, resolved_by: null}
    - {id: OQ24, text: "P8 과 CLAUDE.md 의 새 문장 — 순서 · 숫자는 스크립트, 단계 안은 모델(S14)을 어떻게 쓸까", dimension: "결정론 경계(P8)와 단계표", status: open, resolved_by: null}
    - {id: OQ25, text: "결과 파일이 지워지지 않는 자리(일꾼 worktree 밖)와 일꾼 파일을 대조해 믿는 방법", dimension: "파일 글의 믿음 경계", status: open, resolved_by: null}
    - {id: OQ26, text: "지휘자가 사용자에게 /compact 를 권하는 「끊기 좋은 자리」 기준과 mod 의 토큰 표시(캐시 읽기 · 새 입력 · 출력 갈라 보기)", dimension: "토큰 재기와 리프레시 방식", status: open, resolved_by: null}
    - {id: OQ27, text: "재설계 전후 토큰을 비교할 측정 기준선", dimension: "토큰 재기와 리프레시 방식", status: open, resolved_by: null}
    - {id: OQ28, text: "현황 mod 의 안전 경계 — 표시만 하고 도구 승인 이벤트는 받지 않는지, 지금 훅 규칙(kill switch 등)은 고칠 후보로", dimension: "사람이 보는 면", status: open, resolved_by: null}
    - {id: OQ29, text: "기존 설계문서 9개의 지휘 기록과 도는 로드맵을 새 구조로 옮기는 길", dimension: "걷어낼 장치와 갈아타는 길", status: open, resolved_by: null}
    - {id: OQ30, text: "단계표 파일 형식과 실행기 칸 값(하위 agent · 백그라운드 세션 · claude -p · 다른 모델 · 스크립트 · 사람)", dimension: "결정론 경계(P8)와 단계표", status: open, resolved_by: null}
    - {id: OQ31, text: "같은 단계 2회 연속 실패 멈춤(영상에서 고름 · 횟수는 스크립트가 강제 — S14)을 작업 방식 고침 루프의 상한 · 차단기(S39 — 자체 검수 되돌림 상한의 답)와 어떻게 함께 둘까 — 다른 작업 방식은 그 방식의 상한을 단계표가 적는다", dimension: "결정론 경계(P8)와 단계표", status: open, resolved_by: null}
    - {id: OQ32, text: "관문 다섯 칸(테스트 · 린트 · 화면 · 문서 · 보고) · 2단 검수 · 테스트 서버 배포를 플러그인 마켓플레이스 devbrew 에서 무엇으로 볼까", dimension: "작은 일과 작업 방식 결합", status: open, resolved_by: null}
    - {id: OQ33, text: "devbrew 상태 계산 · 지휘 원장 읽기가 superpowers 산출 형식(**Spec:** · ### Task · Ruling: · *-design.md)에 묶인 것을 다른 작업 방식과 어떻게 가를까", dimension: "작은 일과 작업 방식 결합", status: resolved, resolved_by: S32}
    - {id: OQ34, text: "에픽 코드를 어디로 모을까 — 에픽마다 main · 로드맵 지휘자 브랜치에 취합", dimension: "팀 상태 배치와 기계 간 조정", status: resolved, resolved_by: S34}
    - {id: OQ35, text: "현황 mod 가 편지함 감시자를 겸할까 — mod 하나($.clock.every · $.process.run · $.prompt.submit) · 표시는 mod 감시는 monitor + 자기 소켓(S28)", dimension: "플랫폼에 있는 것과 새 파일 규약의 경계", status: resolved, resolved_by: S38}
    - {id: OQ36, text: "seed 의 규칙 목차 운영(120줄 · 새 규칙 맨 위 · 넘치면 합침 · 두 번 나오면 승격)을 조사 18 근거로 바꿀까", dimension: "걷어낼 장치와 갈아타는 길", status: resolved, resolved_by: S36}
    - {id: OQ37, text: "S14 「순서는 스크립트가 강제」의 탈출구와 동시 수 — 사람 승인 탈출구 · 레포 설정 값", dimension: "결정론 경계(P8)와 단계표", status: resolved, resolved_by: S37}
    - {id: OQ38, text: "자체 검수 되돌림 상한 — superpowers SDD 고침 루프(과제당 5 라운드 · 1–3 이어 부름 · 4–5 강한 모델 · 차단기)에 맡길까, devbrew 가 따로 3회를 둘까", dimension: "결정론 경계(P8)와 단계표", status: resolved, resolved_by: S39}
    - {id: OQ39, text: "지휘자 상태 브랜치의 이름 접두와 git workflow 문서(접두 넷 · 단명 브랜치 · rebase 금지 범위) 예외, plumbing 으로 쓸지", dimension: "팀 상태 배치와 기계 간 조정", status: open, resolved_by: null}
    - {id: OQ40, text: "조건 붙은 팀 규칙을 일꾼에게 닿게 하는 길 — 경로 조건 규칙(S36)이 격리 worktree 하위 agent 에 안 실리므로 시작 묶음에 골라 싣기 · 경로 조건 규칙 유지 · 플러그인 skill paths", dimension: "걷어낼 장치와 갈아타는 길", status: resolved, resolved_by: S41}
    - {id: OQ41, text: "지휘 절차에서 시작 묶음에 골라 실은 규칙을 다시 적는 자리와 묶음 바이트 예산을 재는 단위", dimension: "걷어낼 장치와 갈아타는 길", status: open, resolved_by: null}
    - {id: OQ42, text: "devbrew 가 SDD 「fix round N/5」 줄 · 차단기 멈춤을 읽는 길과 superpowers 최소 판 기록", dimension: "결정론 경계(P8)와 단계표", status: open, resolved_by: null}
    - {id: OQ43, text: "지휘자 자신이 압축한 뒤 규칙 조건 칸을 다시 읽는 길과, 플러그인을 쓰는 다른 레포에서 팀 규칙 파일을 둘 자리", dimension: "걷어낼 장치와 갈아타는 길", status: open, resolved_by: null}
    - {id: OQ44, text: "도구 제한을 어디서 걸까 — 하위 agent 는 부를 때 도구를 정할 수 없어 칸만으로는 막히지 않는다: 단계표 허락 도구 칸의 값 = 쓰기 도구 없는 agent 정의 이름(역할마다 하나 · 하위 agent 는 그 정의로 보내고, 따로 띄우는 세션 실행기만 실행 옵션으로 칸을 바로 쓴다) · agent 정의만. 역할 CLAUDE.md 는 할 일의 맥락을 싣고, 검수 · 점검 단계는 최소한 쓰기 도구 없는 역할로 돈다(Law 2)", dimension: "일꾼 실행 방식과 역할 경계 집행", status: open, resolved_by: null}
    - {id: OQ45, text: "S23 「잘못 쌓인 맥락은 없는 것보다 나쁘다」 원칙을 레포 어디에 둘까 — 지금은 사용자 자동 메모리에만 저장됐다(레포 원칙 문서 · HANDBOOK · CLAUDE.md 중)", dimension: "파일 글의 믿음 경계", status: open, resolved_by: null}
    - {id: OQ46, text: "편지함 발신 확인을 무엇으로 할까 — 서명 커밋 · 보낸 쪽 허용 목록 중에서, 그리고 확인 안 된 글을 알림만 할 때의 알림 꼴(리뷰 결정 S46)", dimension: "파일 글의 믿음 경계", status: open, resolved_by: null}
    - {id: OQ47, text: "devbrew 산출물의 「한곳」은 무엇인가 — 로드맵(팀) 폴더 하나 아래에 인터뷰 · 설계 · 계획 · INTENT · 결과를 다 둘지, 단계별 폴더(interview · specs · plans · roadmaps)를 두고 색인만 둘지, 그리고 git 이 무시하는 실행 상태(.claude/<plugin>/)와 지휘자 상태 브랜치(D18 — 동시 쓰기 충돌을 피하려고 고름)를 그 한곳과 어떻게 맞출지 · 스크립트 · 다른 모델(codex) 다루기도 같은 한곳에 드는가 — 지금 codex 사슬은 shared/codex 정본을 플러그인마다 사본으로 싣고(설치본은 다른 플러그인의 파일에 닿지 못한다) 용도별 러너는 플러그인마다 따로다. 단계표 실행기 칸의 「다른 모델 · 스크립트」 값이 그 정본을 부르게 할지", dimension: "팀 상태 배치와 기계 간 조정", status: open, resolved_by: null}
    - {id: OQ48, text: "D33 의 고르기 스크립트를 지금 만들까, 팀 목록이 커질 때까지 미룰까 — [참고 · overdesign] 팀 전용 규칙이 아직 하나도 없는데, 적용 조건 칸으로 맞는 줄만 골라 보내는 스크립트를 먼저 설계한다 — 팀 목록은 몇 줄로 묶였으니 통째로 보낼 수도 있다. 대안: 규칙마다 출처 · 조건 · 확인법(D25)은 두고 시작 묶음에는 팀 목록 전체를 싣되, 고르는 스크립트는 팀 목록이 바이트 예산(D30)을 넘거나 잘못 닿으면 일꾼을 오도하는 첫 규칙이 생길 때 더한다 (리뷰 41df26ba#r1.1)", dimension: "걷어낼 장치와 갈아타는 길", status: open, resolved_by: null}
    - {id: OQ11, text: "지휘 세션 리프레시를 누가 · 언제 일으킬까", dimension: "토큰 재기와 리프레시 방식", status: resolved, resolved_by: S13}
trivia_escape_armed: false
user_statements:
  - id: S2
    source: chosen
    round: 1
    text: "같은 뿌리 (권장) — 토큰 낭비와 공유 누락은 둘 다 맥락이 대화·메시지에만 쌓이고 파일에 안 남는 데서 나온다고 보고 파일 규약을 먼저 설계"
  - id: S3
    source: verbatim
    round: 1
    text: "3, 터미널에서 현황 파악은 모드로 할게"
  - id: S4
    source: chosen
    round: 2
    text: "하위 agent + 실행기 칸 (권장) — 지금 방식을 기본으로 두고 단계표 칸으로 백그라운드 세션·claude -p·다른 모델·스크립트를 단계별로 고를 수 있게"
  - id: S5
    source: verbatim
    round: 2
    text: "나쁘진 않은 생각인데 한개 서버에 한 세션만 있다면 어떻게 메시지 보낼건데, 더 고민이 필요해"
  - id: S6
    source: verbatim
    round: 2
    text: "1, 낡은 규칙과 철학으로 지래짐작 제약은 안되는거 알지?"
  - id: S7
    source: chosen
    round: 2
    text: "리프레시는 비용 아닌 품질 신호, 일꾼 파일은 대조해 믿기, 작은 일은 가볍게 (고르지 않음: 역할은 agent 정의로)"
  - id: S8
    source: chosen
    round: 3
    text: "보완 (builder·orchestrator 추천) — ST1: 파일 규약은 취하고, 읽기 설계와 결정한 자리에서 결정 기록을 같은 첫 단추로 올리며, 되읽기 보증은 산출물 대조로 바꿈"
  - id: S9
    source: chosen
    round: 4
    text: "편지함 + 세션 안 감시자 (권장) — git 원격 편지함이 정본, 각 지휘자 세션의 감시자(monitor·훅)가 알림, 시작 훅이 밀린 글을 읽음"
  - id: S10
    source: verbatim
    round: 4
    text: "1, 아니면 그 안에서 세션이 시작되는건 어려운거겠지? 그러면 읽게 되는거자나"
  - id: S11
    source: verbatim
    round: 4
    text: "1, task는 어디서 말하는 task인거야?"
  - id: S12
    source: verbatim
    round: 5
    text: "이부분은 뭔가 더 만들지 말고 기존에 있는거에 맡기자 새로 바닥부터 구현보다. 내가 처음 생각한 내용은 에픽을 대상으로였어"
  - id: S13
    source: chosen
    round: 5
    text: "사용자가 (지금) — 지휘자가 끊기 좋은 자리를 알리고 사용자가 /compact"
  - id: S14
    source: chosen
    round: 5
    text: "순서·숫자는 스크립트, 단계 안은 모델 (권장) — 단계표 순서·멈춤 횟수·해시 승인·동시 2개는 스크립트가 강제, 각 단계 안의 일은 모델이 판단"
  - id: S15
    source: verbatim
    round: 6
    text: "1, 내가 프레이밍 단계에서 이야기한거에서 바꾼거 있어?"
  - id: S16
    source: verbatim
    round: 6
    text: "1, 이러면 어떠한 영향이 있는거지?"
  - id: S17
    source: chosen
    round: 6
    text: "STATUS 는 계산해 쓴 추적 파일 (권장) — 스크립트가 git·원장에서 계산해 STATUS.md 를 쓰고 커밋, machine.md 는 이 기계 캐시로 줄임"
  - id: S18
    source: chosen
    round: 6
    text: "단계표+지시서로 쪼개기 (권장) — 단계표 파일 + 걸음별 지시서로 나눠 그 걸음에서만 읽고, 쓰지 않는 손 절차(30KB)는 떼어냄"
  - id: S19
    source: verbatim
    round: 6
    text: "세션간 대화방식 더 나은 방법 없는지 조사해줘봐 바닥부터 만들생각 말고"
  - id: S20
    source: verbatim
    round: 7
    text: "1, 파일 구조는 어떻게 되는데"
  - id: S21
    source: verbatim
    round: 7
    text: "1, superpowers같은 다른 플러그인들과의 호환은 ?"
  - id: S22
    source: chosen
    round: 7
    text: "맞다 — 영상의 과제 = devbrew 의 에픽, 과제 폴더는 에픽마다 하나"
  - id: S23
    source: verbatim
    round: 8
    text: "1, 이러면 핸드북이 너무 쌓이기만 하거나 커지는건 아니지? 이부분은 항상 경계해야해 잘못 쌓인 컨텍스트가 없는거보다 최악이거든 예를 들어 이때는 맞았는데 다른 떄는 틀린거를 그 내용을 보고 근거로 그냥 진행한다던지 아님 핸드북 내용을 보고 지래짐작으로 판단하거나 확인 안해보거나 구현을 꼬으거나 등의 망가지는 현상을 많이 봤어 이거 말고도 리스팅해봐 (이거 원칙으로 저장해줘)"
  - id: S24
    source: chosen
    round: 8
    text: "레포 쪽 이름 바꿀 (권장) — 팀 규칙 목차를 MEMORY.md 가 아닌 다른 이름으로"
  - id: S25
    source: verbatim
    round: 8
    text: "그리고 이렇게 가면 팀간 나눈다는게 의미가 조금 약해지지 않나?"
  - id: S26
    source: chosen
    round: 9
    text: "공통 + 팀 전용 짧은 목록 (권장) — 역할·HANDBOOK 은 공통, 팀 폴더에 출처·적용 조건이 붙은 팀 전용 규칙 몇 줄, 두 팀에서 같은 게 나오면 공통으로"
  - id: S27
    source: chosen
    round: 9
    text: "규칙마다 출처·조건·확인법, 쓰기 전 지금 확인, 반증·낡음이면 지움, 승격 전 반례 확인·상한"
  - id: S28
    source: chosen
    round: 9
    text: "지금 안 + 기성 기법 차용 (권장) — git 편지함 정본 유지, 감시자는 Claude Code 자체 세션 받은 편지함 + 쉬는 세션 깨우기 훅(asyncRewake) 기법"
  - id: S29
    source: chosen
    round: 9
    text: "모델용은 일꾼, 사람용은 사람 단계 (권장) — 모델이 부를 수 있는 skill 은 일꾼 단계에, /이름으로만 되는 것은 사람 단계로, 산출 위치는 지시서가 적음"
  - id: S30
    source: chosen
    round: 10
    text: "이대로 넘김 (권장) — OQ21–OQ32 를 brief 의 열린 질문으로 넘기고 마무리 단계로"
  - id: S31
    source: chosen
    round: 11
    text: "지금 복사해 둠 (권장) — ~/.claude/projects 의 devbrew 기록(하위 agent 포함)을 레포 밖 백업 폴더로 복사, 설정은 안 바꿈"
  - id: S32
    source: chosen
    round: 11
    text: "devbrew 파일 기준 계산 (권장) — 단계 계산은 과제 폴더(INTENT.md · results/)를 읽고, superpowers 형식 읽기는 「superpowers 단계 맞춤」 하나로"
  - id: S33
    source: verbatim
    round: 11
    text: "1, 데이터 브랜치 보다는 그 로드맵의 지휘자의 브랜치겠지 지금 gitflow상으로는 main에 계속 머지하고 있나? 이거를 여기에서 취합하는건 어떻게 생각해? 여러 로드맵이 동시에 돌거나 디펜던시 걸려있는 경우 많이 갈리려나? 상황을 리스팅 해보고 트레이드 오프를제시해줘"
  - id: S34
    source: chosen
    round: 12
    text: "기본 main, 선택으로 로드맵 취합 (권장) — 에픽마다 main 에 머지, 함께 나가야 하는 로드맵만 지휘자 브랜치에 취합"
  - id: S35
    source: chosen
    round: 12
    text: "지휘자 상태 브랜치 (권장) — 로드맵 지휘자마다 코드 없는 상태 전용 브랜치, STATUS 는 그 지휘자만, 편지함은 한 글 한 파일, main 에 머지하지 않음"
  - id: S36
    source: chosen
    round: 13
    text: "근거대로 바꿈 (권장) — 조건 붙은 규칙은 경로 조건 규칙(.claude/rules)으로, 목차는 바이트 예산, 합치기·나이 이관 대신 반증 삭제, 새 규칙 맨 위 안 함, 승격은 반례 확인 뒤"
  - id: S37
    source: chosen
    round: 13
    text: "강제 + 사람 승인 탈출구 (권장) — 순서는 스크립트가 지키되 사람이 승인하면 단계를 건너뛰거나 바꿈, 동시 수는 레포 설정(무거운 일 기본 2)"
  - id: S38
    source: chosen
    round: 13
    text: "mod 하나가 겸함 (권장) — 타이머로 git fetch, 새 글이면 자기 세션에 새 턴, 대화형 터미널에서만"
  - id: S39
    source: chosen
    round: 14
    text: "SDD 고침 루프에 맡김 (권장) — devbrew 는 따로 세지 않고 작업 방식의 상한 · 차단기를 따름, 다른 작업 방식은 그 방식의 상한을 단계표가 적음"
  - id: S40
    source: chosen
    round: 14
    text: "한 번만 더 (권장) — 경로 조건 규칙 적재 여부만 조사, 나머지 셋(상태 브랜치 이름 · P8 파급 · 이전 목록)은 설계의 열린 질문으로, 그 뒤 마무리"
  - id: S41
    source: chosen
    round: 15
    text: "시작 묶음에 골라 싣기 (권장) — 규칙마다 적용 조건(경로 · 단계 · 역할) 칸, 지휘자가 보낼 때 맞는 줄만 골라(스크립트) 시작 묶음에"
  - id: S42
    source: chosen
    round: 16
    text: "마무리 (권장) — 포화 판정 4 의 빈 곳 넷을 설계의 열린 질문으로 넘기고 분해 판단 → brief 작성으로"
  - id: S43
    source: chosen
    round: 16
    text: "고친다 — 출처 바로잡기 (권장) — 목표 출처를 S1·S3 으로, 비목표는 실행기 몸을 S4·S12 로 따로 달아 설계가 출처를 따라갈 수 있게"
  - id: S44
    source: chosen
    round: 16
    text: "고친다 — 도구 제한 열린 질문로 (권장) — 기각 줄을 「고르지 않음(열림)」으로 바꾸고, 도구 제한을 어디서 거나(허락 도구 칸·쓰기 없는 agent 정의)를 열린 질문으로 더함 — 검수 단계는 쓰기 없는 역할"
  - id: S45
    source: chosen
    round: 16
    text: "고친다 — 답 번호 풀이 기록 (권장) — 결정(STATUS 파일 + mod)은 그대로, 「3 = STATUS 파일만」을 열린 질문 줄에 적어 다시 헷갈리지 않게"
  - id: S46
    source: chosen
    round: 16
    text: "고친다 — 발신 확인 먼저 (권장) — 자동 새 턴은 유지하고 발신 확인(서명 커밋·보낸 쪽 허용 목록)을 편지함 계약의 전제로, 확인 안 된 글은 알림만"
  - id: S47
    source: chosen
    round: 16
    text: "고친다 — 칸 = agent 정의 이름 (권장) — 칸에는 쓰기 도구 없는 agent 정의 이름(역할마다 하나)을 적고 하위 agent 는 그 정의로 보낸다. 따로 띄우는 세션 실행기만 실행 옵션으로 칸을 바로 쓴다. 열린 질문의 선택지가 「칸 = 정의 이름」과 「정의만」 둘로 준다"
  - id: S48
    source: verbatim
    round: 16
    text: "아니 내가 생각하는거는 데브브류의 것들이 한곳으로 모이는걸 원하는거야 이번 고침이 거기에 맏다아 있는거 같은데"
  - id: S49
    source: chosen
    round: 16
    text: "목표 + 열린 질문으로 싣기 (권장) — 말씀을 원문으로 기록하고 목표 한 줄과 「한곳이 무엇인가」 열린 질문을 더한다 — 팀 파일 규약(R1) · 이전(R5) 설계가 정한다. 인터뷰는 다시 열지 않는다"
  - id: S50
    source: verbatim
    round: 16
    text: "그거랑 추가로 스크립트, 다른모델(코덱스) 이런거 다루는거도 들어가 있는거지?"
confirm_repost_count: 0
decompose_edits: 1
brief_review_degradations:
  - component: readback
    reason: 첫 dispatch 에서 도구 없는 readback agent 에 본문 대신 파일 경로를 넘겨 읽지 못했고, 재dispatch 는 본문(약 4만 토큰) 인라인이 이 턴 맥락에 들지 않아 하지 못했다
    affected_axis: readback
    verification_status: unavailable
---

## 풀린 입력

~~~~
---
type: interview-seed
next_phase: spec-distill:pm-interview
audit_file: 2026-11-13-conductor-context-economy-interview.audit.md
---

로드맵 지휘와 그 아래 담당자들이 토큰을 너무 많이 쓴다. 맥락이 쌓이면 비용도 들고 판단도 흐려진다 — 사용자는 둘 다 걱정한다. 담당자 보고는 너무 길고, 파일에 남지 않고, 도는 동안 중간 소식이 없고, 반려가 흐릿하다. agent 끼리는 서로 대화가 안 돼서 병렬 담당자끼리, 지휘자에서 담당자로, 단계와 교대 사이, 담당자에서 그 하위로 가는 모든 자리에서 공유가 빠진다.

방향은 사용자가 붙여 준 팀 구조다. 붙인 팀 구조 글은 첫 요청(보고 · 공유 누락 · 리프레시 · 토큰)을 풀 방향을 보여 주는 추가 지시다. (사용자 확인) 그 구조는 이렇다. 팀 공통 CLAUDE.md 아래 역할마다 폴더와 그 역할의 CLAUDE.md(할 일과 하지 않을 일 두 칸)를 둔다. 대장은 과제를 받으면 바로 시작하지 않고 방향을 먼저 사람에게 보인 뒤 빈 일꾼에게 맡기고, 일꾼은 과제 폴더에 INTENT.md(목표 · 지시 원문 · 하지 않을 것 · 결정 기록)부터 만든다. 넘기기 전 관문 다섯 칸(테스트 · 린트 · 화면 · 문서 · 보고)을 채우고, 검수는 두 번이다. 테스트가 하나라도 실패하거나 실제로 돌려 보거나 화면을 봤을 때 잘못되었으면 반려하고, 반려는 어디서 무엇이 어떤 기준에 걸렸는지 한 줄로 되돌린다. 테스트 서버 배포까지는 대장이, 실서비스 배포는 사람이 하고, 권한은 도구로 막는다. 대장은 승인 요청 · 배정 · 2차 검수 · 테스트 서버 배포를 맡고, 대장 폴더에는 STATUS.md 와 inbox/ 가 있다. MEMORY.md 는 한 줄에 규칙 하나, 새 규칙은 맨 위이고, 세션마다 읽히니 120줄 안으로 묶으며 넘으면 겹치는 줄은 합치고 오래된 것은 HANDBOOK.md 로 보낸다. 같은 지적이 두 번 나오면 지휘자(오케스트레이터)가 HANDBOOK.md 정식 규칙으로 올린다.

my-team 의 구조(역할 폴더와 역할별 CLAUDE.md, 한곳의 작업 폴더, INTENT.md, STATUS.md, inbox/, MEMORY → HANDBOOK)를 그 이름 그대로 공식 용어로 들이고, 지금 있는 장치는 어느 정도 걷어내고 바꾼다. (사용자 확인) 워커를 하위 agent 로 할지 따로 띄운 세션으로 할지는 인터뷰가 정하고, 역할 이름은 devbrew 가 쓰는 말로 바꾼다. (사용자 확인) 팀 문서는 한 팀 폴더에 모으고 코드를 고치는 자리만 worktree 로 둔다. 팀 규칙 목차는 레포 안 파일로 둔다.

팀은 로드맵 지휘에만 쓰는 것이 아니라 devbrew 파이프라인의 모든 단계가 팀을 쓴다. (사용자 확인) 설계문서가 하나뿐인 작은 일도 지휘자를 거치고, 지휘자 없이 도는 흐름을 따로 두지 않는다. (사용자 확인) 로드맵 하나가 팀 하나이고, 여러 로드맵이 동시에 돌 때 지휘자끼리의 소통이 필요하다. (사용자 확인) 지휘자들은 다른 세션이나 다른 서버에 있을 수 있으므로, 지휘자끼리의 소통은 같은 기계를 전제하지 않는다. (사용자 확인) 지휘자끼리는 같은 파일을 건드리려는 것, 머지 순서, 규칙과 배운 것, 사람에게 묻는 질문의 줄을 주고받아야 하고, 지휘자끼리의 대화에도 계약(대화 형식 · 받았음과 답했음의 확인 · 글이 왔음을 아는 방법 · 우리 agent 가 보낸 글인지의 확인)이 필요하다. 여러 로드맵을 동시에 돌리는 일은 실제로 생기고 있다.

메시지는 짧게 쓰고 자세한 것은 파일 경로로 남긴다 — 메시지는 세션이 끝나면 사라지기 때문이다. 이 규칙은 agent 사이 글에 적용한다. agent 끼리 대화가 안 돼서 빠지는 공유는 과제마다 파일(목표 · 지시 원문 · 하지 않을 것 · 결정 기록)로 메운다. (사용자 확인) 기억은 파일에 두되, 과제의 왜는 과제 파일에, 팀 규칙은 한 줄에 하나씩 120줄 안의 목차 파일에 두고, 두 번 나온 지적은 정식 규칙 파일로 올린다. (사용자 확인) 글을 파일로 주고받으므로, 받는 쪽이 그 파일을 실제로 읽고 이해했음을 확인하는 약속(받음 확인 · 되읽기)이 필요하다. (사용자 확인) 팀원끼리의 대화에는 계약이 필요하다 — 대화 형식, 받았음과 답했음의 확인, 글이 왔음을 아는 방법, 우리 agent 가 보낸 글인지의 확인. (사용자 확인) STATUS 같은 진행 문서는 사람과 agent 가 둘 다 읽는다. 터미널에서도 지휘자가 작업 목록을 만들지 않는 것이 문제이고, 지휘가 도는 동안 목록이 떠 있어야 한다. (사용자 확인)

사용자가 준 영상(제목은 「클로드 코드 팀, 상주는 하나만 두고 나머지는 불러서 씁니다」)도 참조다 — 영상 내용은 사용자가 옮겨 적어 준 것으로 다 읽은 것으로 본다. 영상의 방식에서는 상주하는 대장 하나가 과제를 등록만 하고 배정 담당 스크립트가 단계표대로 일꾼을 부르는데, 이 역할 나눔을 들일지는 인터뷰가 정한다 — 사용자는 단계 진행 담당을 인터뷰에 맡겼다. 단계표 파일 하나가 무슨 순서로 누구(Claude · 다른 모델 · 스크립트 · 사람 · 대장)에게 일을 시킬지 정하고, 단계별 지시서는 따로 모아 두며, 과제마다 폴더 하나에서 일꾼이 자료를 꺼내고 결과를 넣는 구조를 가져온다. (사용자 확인) 회고도 단계표에 오르는 단계 중 하나다. (사용자 확인) 구현 뒤 자체 검수가 테스트 결과로 판정해 고칠 것이 있으면 구현으로 되돌리고, 세 번을 넘으면 더 돌리지 않고 보고한다. (사용자 확인) 과제 여러 개는 병렬로 돌리되, 빌드처럼 컴퓨터를 많이 쓰는 일만 동시 2개로 묶고 다른 일은 서버 부하를 보고 정한다. (사용자 확인) 사용자가 영상에서 그 밖에 가져오기로 고른 것은 승인을 파일 내용의 해시에 묶어 파일이 바뀌면 다시 승인받기, 같은 단계가 두 번 연속 실패하면 멈추고 알리는 숫자 멈춤 조건, 파일만 읽어 토큰을 쓰지 않는 현황 보기와 세션을 비운 뒤 시작 훅이 넣는 현황 요약, 보고 메시지 없이 결과 파일로만 하는 보고, 단계마다 다른 일꾼, 단계마다 허락하는 도구, 세션 기록의 사용량 집계로 재는 토큰이다.

토큰은 한 번 재서 낭비를 줄이고, 지휘 중에 계속 보이고, 리프레시 신호로도 쓴다 — 사용자는 셋 다 골랐다. 리프레시는 적절한 순간에 하되 너무 자주는 하지 않고, 지휘 세션도 구현 담당자도 대상이다. 영상은 과제마다 세션 하나를 이어 붙이다 과제가 끝나면 닫는데, 그 과제를 devbrew 의 어느 단위로 볼지는 사용자도 애매하다고 했다 — 인터뷰가 정한다.

담당자를 무엇으로 돌릴지는 인터뷰가 herdr 같은 방식까지 검토해 정하되, 특정 외부 도구에 하드코딩되거나 의존이 생기는 것은 피한다. (사용자 확인) 단계 진행을 돕는 관리 스크립트는 지휘자가 쓰는 도구 역할이고, devbrew 원칙 P8 의 「결정론은 보안 · 정확성 게이트에만」 내용은 바꾼다. (사용자 확인) 팀 구조는 superpowers 하나에 묶이지 않고, 나중에 들일 Matt Pocock skills · pstack 같은 다른 작업 방식도 단계에 끼워 쓸 수 있게 둔다. (사용자 확인)

다시 검증할 것 — 사용자는 이제 하위 agent 도 자동 압축이 된다고 봤는데 확인하지 않았다. 레포 기록상 헤드리스 claude -p 는 쓰기 거부 같은 실패에도 성공으로 끝나고 Skill 도구를 쓰지 못한다 — 담당자를 그렇게 돌리면 결과 파일 검사가 따로 필요하다는 것은 Phase 0 의 추론이다. 역할 폴더의 CLAUDE.md 를 지휘 세션이 띄운 하위 agent 가 읽는지는 모른다. 하지 않을 일은 글로 적어서는 막히지 않고 도구 권한으로만 막힌다는 것이 devbrew 의 기존 입장이라, 역할 CLAUDE.md 와 어떻게 함께 갈지 봐야 한다. 레포 안 MEMORY.md 는 이름이 Claude 자동 메모리의 MEMORY.md 와 겹친다. 영상의 캐시 읽기 비율(입력의 98.5%와 99%)은 영상 제작자의 측정이다. 작업 목록이 왜 생기지 않는지는 원인을 보지 않았다. 지휘 절차서 하나가 약 3.5만 토큰이고 지휘자가 부를 때마다 읽는다는 것, 레포에 토큰을 세는 코드가 없고 세션 기록에는 턴마다 사용량이 남는다는 것은 Phase 0 이 한 번 본 값이다.
~~~~

seed 분류기: 사용자 확인 19 · 사용자 미확인 0 · 저자 35 (audit: ok)

## R1

### 지금 이해
seed 의 확인 문장 19개는 다시 묻지 않는다. 첫 조사가 seed 의 「다시 검증할 것」 셋을 풀었다 — 하위 agent 자동 압축은 공식 문서상 있다(E1), 지휘 절차서는 75,138 바이트이고 지휘자가 부를 때마다 Read 한다(RC4), 작업 목록이 안 뜨는 원인 후보는 새 모델에서 작업 목록 도구가 기본으로 빠지는 것이다(E6 — 이 세션의 도구 목록에도 작업 목록 도구가 없다, 경로 a 관찰). 지금 장치와 새 규칙이 부딪히는 자리도 나왔다: 보고 전문을 메시지에 싣는 규칙(RC1), 순서 강제 결정론 금지(RC2), 압축은 사용자만(RC3), 하위가 쓸 수 있는 파일을 판정 근거로 안 씀(RC5), superpowers 필수(RC6), 잠금이 한 기계 전제(RC8). 파생 차원 9개(internal_research 포함)를 admit 했다(제안 11개를 묶음).
- 확인 RC1 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#마지막 보고 — 주장과 일치(43행 「경로만으로는 부족하다」)
- 확인 RC2 — 확인 — docs/philosophy/devbrew-harness-philosophy.md#P8 — 주장과 일치(84행 「순서를 강제하는 결정론은 두지 않는다」)
- 확인 RC3 — 확인 — plugins/spec-distill/references/conducting.md#/compact 시점 — 주장과 일치(85행 「압축은 사용자만 한다」)
- 확인 RC4 — 미확인 — plugins/spec-distill/references/conducting.md#파일 전체 — 매 호출 Read(epic-conductor SKILL 163–164행)와 75,138 바이트 · 116줄은 확인, 35,641 토큰 수치는 본체가 재지 못함
- 확인 RC5 — 확인 — plugins/spec-distill/references/conducting.md#5. 머지 전 확인 — 주장과 일치(59행 「답은 기계 상태에 적지 않는다」)
- 확인 RC6 — 확인 — plugins/spec-distill/skills/epic-conductor/SKILL.md#1.5 의존 확인 — 주장과 일치(64행 superpowers 없으면 멈춤)
- 확인 RC7 — 확인 — plugins/spec-distill/references/conducting.md#1. 맞추기 — 주장과 일치(16행 원천 셋 · 표는 사본)
- 확인 RC8 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#스위트 잠금 — 주장과 일치(15행 suite-lock 경로는 로컬 파일)
- 확인 RC9 — 확인 — CLAUDE.md#런타임 상태 & 훅 — 주장과 일치(70행 git-ignored 런타임 · docs 추적 진행 기록)
- 확인 RC10 — 확인 — plugins/project-init/hooks/hooks.json#PostToolUse — 레포의 hooks.json 은 이것 하나이고 SessionStart 없음
- 확인 RC11 — 확인 — CLAUDE.md#Law 1 Trivia escape · Trivia ceremony — 주장과 일치
- 확인 RC12 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#단계마다 새 agent — 주장과 일치(37행 「백만 토큰 가까이」)
- 확인 RC13 — 확인 — docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md#238행 — 주장과 일치(Skill 도구 거부), plans 1538행 rc 0 조용한 실패도 확인
- 확인 RC14 — 확인 — plugins/spec-distill/references/conducting.md#병렬 권장 수 — 주장과 일치(19행 기본값 · 상한 아님)
- 웹 E1–E6 — 본체가 1차 자료로 다시 확인하지 못함(확인 못 함). E6 은 이 세션 도구 목록 관찰과 맞는다.
조사 호출 1/60 · 이 라운드 본체 직접 1
사실로 보고 직접 답한 질문 1개 — 작업 목록이 왜 안 뜨나 · 이 세션(Opus 5.5)의 도구 목록에 TaskCreate/TodoWrite 가 없다
줄인 사실 3개

### 다음 결정
OQ1: 이 재설계가 먼저 풀어야 할 뿌리 문제 · 추천: 같은 뿌리 — 일의 맥락이 대화·메시지에만 쌓이고 파일에 안 남는다 · 트레이드오프: 같은 뿌리=파일 규약 하나가 토큰·공유를 함께 푼다 / 토큰 비용=측정·리프레시부터 / 공유 누락=대화 계약부터
OQ2: 지휘 중 작업 목록 · 추천: 둘 다 · 트레이드오프: 둘 다=터미널 목록+파일 둘 다 유지 비용 / 도구만=세션 끝나면 사라짐 / 파일만=터미널에 안 뜸

### 질문
(d) 뿌리 문제 · (b) 작업 목록 표면 — 같은 호출에 둘

### 답
→ S2 (OQ1: 같은 뿌리 (권장)) · S3 (OQ2: 「3, 터미널에서 현황 파악은 모드로 할게」 — STATUS 파일만, 터미널 현황은 「모드」로)

### 조사 1 — coverage-mapper · R1 · 묶음 1

```yaml
derived_dimensions:
  - name: "걷어낼 장치와 갈아타는 길 (지금 도는 로드맵 포함)"
    rationale: "seed 는 지금 장치를 「어느 정도 걷어내고 바꾼다」고만 적었다. 지금 규칙 중 몇은 seed 의 새 규칙과 정면으로 부딪힌다. 지휘 절차(conductor-dispatch.md)의 「마지막 보고」는 보고 전문을 메시지에 실으라고 요구한다. 실행 방식이 작업 폴더를 지울 수 있다는 이유다(RC1). seed 는 「결과 파일로만 보고」다. 기계 상태 표 · relay 파일 · 실행 원장(RC7)을 STATUS.md · inbox/ 가 대신하는지도 정해야 한다. 이미 돌고 있는 로드맵을 어떻게 옮길지, major 판 올림 · CHANGELOG Removed 를 어떻게 할지, kill switch 이름을 지킬지(CLAUDE.md)도 남아 있다. 지금은 어느 floor 에도 이 축이 들어 있지 않다."
  - name: "플랫폼에 이미 있는 장치와 새로 만들 파일 규약의 경계 (있는 것 먼저)"
    rationale: "seed 가 요구하는 대화 계약은 넷이다. 대화 형식, 받았음 · 답했음 확인, 글이 왔음을 아는 방법, 보낸 쪽 확인. Claude Code 는 이것의 일부를 이미 준다. 세션끼리 보내는 메시지는 Remote Control 을 거치면 다른 기계까지 간다. 보낸 쪽이 표시되고, 그 메시지로는 승인할 수 없고, 쉬는 세션은 새 턴을 연다(E4). agent 팀에는 mailbox · 공유 작업 목록 · file lock 이 있다(E5). 하위 agent 를 이름으로 부르고 SendMessage 로 서로 보낼 수 있다(E5). agent 마다 memory 칸도 있다(E3). 따라서 직접 만들 파일 프로토콜과 플랫폼 기능 사이의 선을 정하는 축이 필요하다. 이 선은 CLAUDE.md 「있는 것 먼저」와 seed 의 「특정 외부 도구에 묶이지 않기」 사이의 긴장이기도 하다. agent 팀은 실험 기능이고, 세션 하나에 팀 하나, 중첩 불가, 재개 불가다(E5)."
  - name: "일꾼을 무엇으로 돌릴지 — 실행 방식별 능력표"
    rationale: "일꾼 후보는 하위 agent · 팀원 · 따로 띄운 세션 · 헤드리스 claude -p · herdr 같은 외부 실행기다. 후보마다 갈리는 축이 여럿이다. CLAUDE.md 를 싣는지(E2), Skill 도구를 쓸 수 있는지(RC13 — 헤드리스는 거부), 실패가 rc 0 으로 숨는지(RC13), 스스로 압축하는지(E1), 도구 권한을 어떻게 막는지(tools allowlist 냐 --tools 냐), 메시지를 받을 수 있는지(E4 — claude -p 도 inbox socket 을 연다)가 그 축이다. seed 는 이 결정을 인터뷰에 맡겼다. 비교 표 없이 고르면 Law 2(도구 권한으로 막기)와 결과 파일 검사 필요 여부가 덩달아 정해진다."
  - name: "역할 경계를 실제로 막는 자리 (글로 쓴 역할 문서 대 도구 권한)"
    rationale: "Claude Code 는 하위 폴더의 CLAUDE.md 를 그 폴더 파일을 읽을 때 늦게 싣는다(E2). 그렇다면 역할 폴더의 CLAUDE.md 는 그 역할만이 아니라 그 폴더를 읽는 누구(지휘자 포함)에게나 섞여 들어갈 수 있다. 문서에 적힌 근거는 Explore · Plan · omitClaudeMd 에이전트 쪽뿐이고, 보통 하위 agent 에 대해서는 직접 확인하지 못했다. 「하지 않을 일」 칸은 devbrew 입장으로는 글로는 막히지 않는다. 역할 정의를 agent 정의 파일의 tools 로 옮길지, 두 겹으로 둘지 정하는 축이다. 팀원은 agent 정의의 tools 를 그대로 쓴다(E5)."
  - name: "파일로 주고받는 글의 믿음 경계와 보안"
    rationale: "지금 지휘 절차는 사용자 답을 기계 상태에 적지 않는다. 검사받는 하위 agent 도 쓸 수 있는 파일이기 때문이다(RC5). 하위가 쓰는 파일을 판정 근거로 삼지 않는 경계가 이미 있다는 뜻이다. seed 의 구조는 이 경계를 넓힌다. inbox/ · 결과 파일만으로 하는 보고 · 파일 해시에 묶은 승인 · 다른 기계와의 지휘자 통신이 모두 그렇다. 결과 파일 위조, 넘긴 글 속 지시 주입, 「우리 agent 가 보낸 글인지」 확인 방법이 이 축의 질문이다. 플랫폼 메시지에는 보낸 쪽 표시와 승인 불가가 붙어 있다(E4). 파일에는 아무것도 붙지 않는다."
  - name: "토큰 재기 · 맥락 비우기 · 압축의 방식"
    rationale: "지금 지휘 절차서는 한 번 읽을 때 약 3.6만 토큰이다(RC4 — Read 도구가 35,641 로 쟀다). 지휘 세션의 압축은 「사용자만 한다」로 묶여 있다(RC3). 반면 하위 agent 는 스스로 압축하고 기준값(autoCompactWindow)을 바꿀 수 있다(E1). 압축할 때마다 기록(transcript)에 압축 전 토큰 수(preTokens)가 남고, 하위 agent 기록은 따로 된 jsonl 이다(E1 · E6). 정할 것은 다섯이다: 무엇으로 잴지, 어느 문턱에서 비울지, 너무 잦지 않게 막을 장치, 비운 뒤 무엇을 다시 읽힐지, 과제 하나를 devbrew 의 어느 단위로 볼지. 과제 단위는 지금 「단계마다 새 agent」 규칙(RC12)과 겹친다."
  - name: "결정론의 경계를 고치는 원칙 수정 (P8)과 단계표 스크립트의 권한"
    rationale: "P8 은 결정론을 보안 · 정확성 게이트에만 걸게 한다. 「순서를 강제하는 결정론은 두지 않는다」고도 명시한다(RC2). 단계표가 순서와 담당을 정하고, 세 번 · 두 번 연속 같은 숫자 멈춤 조건을 두는 방식은 이 문장과 바로 부딪힌다. seed 는 P8 을 바꾼다고 확정했다. 그래도 정할 것이 남는다. 무엇을 어디까지 결정론으로 둘지, 모델이 단계표와 다르게 판단할 수 있는지, 원칙 문서 · CLAUDE.md 를 어떻게 함께 고칠지다. 이 원칙은 레포 전체에 퍼져 있어서 이 축이 따로 필요하다."
  - name: "여러 팀(로드맵)·여러 기계 사이의 자원 조정"
    rationale: "지금의 조정 장치는 모두 한 기계의 파일시스템을 전제한다. 공유 스위트 잠금, 로드맵마다 세션이 잡는 표지(claim), 에이전트별 임시 폴더(resource-dir)가 그렇다(RC8). seed 는 지휘자가 다른 서버에 있을 수 있다고 했다. 같은 파일을 노리는 일, 머지 순서, 빌드 동시 2개 제한은 기계를 넘는 잠금 · 순서 정본이 없으면 지킬 수 없다. 기계를 넘는 메시지는 Anthropic 서버를 거친다(E4). 지금 병렬 권장 수는 기본 3이고 상한이 아니다(RC14). seed 의 무거운 일 동시 2개는 상한이다. 두 규칙이 서로 다르다."
  - name: "팀 문서 · 상태를 어디에 둘지 (추적 파일 · git-ignored · 기계 간 공유)"
    rationale: "CLAUDE.md 는 런타임 상태를 `.claude/<plugin>/` 아래 git-ignored 로 둔다. 세션을 넘는 진행 기록은 docs 의 추적 파일에 둔다(RC9). seed 가 정한 배치는 셋이다. 팀 문서는 한 팀 폴더에, 규칙 목차는 레포 안 파일에, 코드를 고치는 자리만 worktree 에. STATUS.md · inbox/ · INTENT.md 가 추적 파일인지 무시 파일인지 정하는 축이다. 이에 따라 머지 충돌, 다른 기계와의 동기화, 시크릿 기록 금지가 갈린다. 레포 안 MEMORY.md 는 Claude 자동 메모리 이름과 겹치는 문제가 있다. agent 마다 붙는 memory 칸(E3)도 같은 이름 공간을 쓴다."
  - name: "사람이 보는 면 — 작업 목록 · 현황 보기 · 시작 훅"
    rationale: "작업 목록이 안 뜨는 원인 후보가 하나 나왔다. 작업 목록 도구(TaskCreate 등)는 Opus 4.7 · Sonnet 4.6 · Haiku 4.5 와 그 이전 모델에만 기본으로 있다. 그보다 새 모델에서는 opt-in(CLAUDE_CODE_ENABLE_TODO_TOOLS=1 등)을 해야 생긴다. background · cloud 세션에는 늘 있다(E6). 이 세션 모델은 그보다 새 모델이다. 그렇다면 원인은 절차가 아니라 플랫폼 기본값일 수 있다. 「세션을 비운 뒤 시작 훅이 넣는 현황 요약」은 이 레포에 아직 없는 SessionStart 훅이다(RC10 — 지금 훅은 project-init 의 PostToolUse 하나뿐). 새로 만들면 kill switch, 읽기 전용(mutate 금지), README 「왜 skill 이 아닌가」 한 줄이 따라와야 한다."
  - name: "작은 일 · trivia 비용과 어느 파이프라인에도 쓸 수 있는가"
    rationale: "seed 는 설계문서 하나뿐인 작은 일도 지휘자를 거치게 했다. 이것은 Law 1 의 trivia escape 와 「Trivia ceremony」 금지(RC11)와 어긋날 수 있다. agent 팀 문서도 순차 · 같은 파일 · 의존 많은 일에는 한 세션이나 하위 agent 가 낫다고 적는다(E5). 지금 지휘자는 superpowers 가 없으면 멈추고(RC6), 절차서는 superpowers skill 이름을 박아 둔다. 「다른 작업 방식도 단계에 끼워 쓴다」는 목표와 부딪힌다."
neglect_flag: false
neglected_dimensions: []
confidence: 0.72
evidence:
  - url: "https://code.claude.com/docs/en/sub-agents"
    supports: current
    claim: "하위 agent 는 자동 압축을 지원한다. 자기 맥락 창이 차면 압축되고, CLAUDE_AUTOCOMPACT_PCT_OVERRIDE 가 적용되며, frontmatter autoCompactWindow(100000~1000000)로 더 일찍 압축하게 할 수 있다. 압축은 하위 agent 기록에 compact_boundary 와 preTokens 로 남는다. seed 의 「다시 검증할 것」 첫 항목(하위 agent 도 자동 압축된다)을 확인한다."
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/sub-agents"
    supports: alternative
    claim: "Explore · Plan 을 뺀 하위 agent 는 메인 대화가 싣는 CLAUDE.md 계층 전부를 싣고, 메인 대화의 작업 폴더에서 시작한다. 하위 폴더 CLAUDE.md 는 그 폴더 파일을 다룰 때 싣는다고 적혀 있으나, 문서는 이를 Explore · Plan · omitClaudeMd 에 대해서만 명시한다. 따라서 역할 폴더 CLAUDE.md 가 그 역할에만 실린다는 보장은 문서에 없다."
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/sub-agents"
    supports: alternative
    claim: "agent 정의의 memory 칸은 agent 마다 따로 영속 폴더를 준다(.claude/agent-memory/<agent>/ 등). 자동 메모리의 일부여서 자동 메모리를 끄면 효과가 없다. 메인 대화의 자동 메모리 MEMORY.md 는 하위 agent 에 실리지 않는다."
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/cross-session-messaging"
    supports: both
    claim: "세션끼리 보내는 메시지는 평문만이고 파일이나 대화 기록을 옮기지 않는다. 같은 기계에서는 per-session socket 으로, 다른 기계로는 Remote Control 을 통해 Anthropic 서버를 거쳐 간다. 받는 쪽에는 다른 세션에서 왔다고 표시되고, 그 메시지로는 승인 · 설정 변경을 할 수 없다. 쉬는 세션은 새 턴으로 받는다. 쉬면 알려 달라는 구독(notify_when_idle)은 같은 기계에서만 된다. 받는 쪽이 accept · hold · refuse 를 정하고, 보류는 최대 100개다. 도착 확인 · 보낸 쪽 확인 일부는 플랫폼이 이미 준다(alternative). 메시지가 파일로 남지 않으니 「자세한 것은 파일로」는 여전히 필요하다(current)."
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/agent-teams"
    supports: alternative
    claim: "agent 팀은 실험 기능이고 기본으로 꺼져 있다(CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1). mailbox 는 ~/.claude/teams/{team}/inboxes/{agent}.json 이고, 공유 작업 목록에는 의존이 있고 받을 때 file lock 을 쓴다. 팀원은 CLAUDE.md · skill 을 싣고, agent 정의를 쓰면 그 tools 가 적용된다. 한계는 세션당 팀 하나 · 중첩 팀 불가 · /resume 불가 · -p 에서는 팀원을 띄우지 않음이다. 문서는 순차 · 같은 파일 · 의존 많은 일에는 한 세션이나 하위 agent 가 낫다고 적는다."
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/tools-reference"
    supports: alternative
    claim: "작업 목록 도구(TaskCreate · TaskGet · TaskList · TaskUpdate · TodoWrite)는 Opus 4.7 · Sonnet 4.6 · Haiku 4.5 와 그 이전 모델에만 기본으로 있다. 그 밖의 모델에서는 opt-in(CLAUDE_CODE_ENABLE_TODO_TOOLS=1 · --allowedTools TaskCreate 등)을 해야 하고, 도구가 없으면 작업 목록에 아무것도 오르지 않는다. background · cloud 세션에는 모델과 무관하게 있다. seed 의 「작업 목록이 왜 생기지 않는지」에 대한 원인 후보다."
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
repo_claims:
  - {id: RC1, path: "plugins/spec-distill/references/conductor-dispatch.md", anchor: "## 마지막 보고 — 「실행 방식이 작업 폴더를 지울 수 있어 경로만으로는 부족하다」", line: 43, claim: "지금 규칙은 하위가 판정 전체 · AC 보고 전체를 마지막 메시지에 싣게 한다. 실행 방식이 작업 폴더를 지울 수 있어서다. seed 의 「보고 메시지 없이 결과 파일로만」은 이 규칙을 대체해야 하고, 결과 파일이 지워지지 않을 자리를 함께 정해야 한다.", touches: [], decides: []}
  - {id: RC2, path: "docs/philosophy/devbrew-harness-philosophy.md", anchor: "### P8 — Determinism Economy — 「정석 흐름 … 의 의도는 지키되 순서를 강제하는 결정론은 두지 않는다」", line: 84, claim: "P8 은 결정론을 보안 · 정확성 게이트에만 걸고(82행), 순서를 강제하는 결정론을 금한다(84행). 단계표가 순서 · 담당을 정하고 숫자 멈춤 조건을 두는 방식과 바로 부딪혀, 원칙 문장을 함께 고쳐야 한다.", touches: [], decides: []}
  - {id: RC3, path: "plugins/spec-distill/references/conducting.md", anchor: "### /compact 시점 — 「압축은 사용자만 한다」", line: 85, claim: "지금 지휘 세션의 맥락 비우기는 사용자가 /compact 를 해야만 일어난다. 「적절한 순간의 리프레시」를 누가 일으키는지가 이 규칙을 바꾸는 결정이다.", touches: [], decides: []}
  - {id: RC4, path: "plugins/spec-distill/references/conducting.md", anchor: "# 지휘 — 로드맵의 에픽을 끝까지 이끄는 절차 (+ skills/epic-conductor/SKILL.md 「### 5. 지휘 순환」 의 Read 줄)", claim: "Read 도구가 이 파일을 35,641 토큰으로 쟀다. 117줄 가운데 걸음마다 한 줄이 수천 자다. epic-conductor 는 부를 때마다 이 파일과 conductor-dispatch.md 를 Read 한다. seed 의 「약 3.5만 토큰 · 부를 때마다 읽는다」를 한 번 더 확인했다.", touches: [], decides: []}
  - {id: RC5, path: "plugins/spec-distill/references/conducting.md", anchor: "### 5. 머지 전 확인 — 「답은 기계 상태에 적지 않는다 — 검사받는 하위 agent 도 쓸 수 있는 파일이라 스위트 대조가 읽지 않는다」", line: 59, claim: "지금 설계에는 하위가 쓸 수 있는 파일을 판정 근거로 쓰지 않는 믿음 경계가 있다. 결과 파일로만 하는 보고 · inbox/ · STATUS.md 는 이 경계를 넓히므로 따로 다뤄야 한다.", touches: [], decides: []}
  - {id: RC6, path: "plugins/spec-distill/skills/epic-conductor/SKILL.md", anchor: "### 1.5 의존 확인 — 「superpowers 확인 — skill 목록에 `superpowers:` 로 시작하는 skill 이 하나도 없으면 … 멈춤」", line: 64, claim: "지금 지휘자는 superpowers 가 없으면 지휘하지 않는다. conducting.md 걸음마다 「부를 skill」 칸이 superpowers skill 이름을 박아 두었다. 「다른 작업 방식도 단계에 끼워 쓴다」를 이루려면 이 결합을 풀어야 한다.", touches: [], decides: []}
  - {id: RC7, path: "plugins/spec-distill/references/conducting.md", anchor: "### 1. 맞추기 — 「기계 상태의 「살아 있는 agent」 · 「작업」 표는 사본이다」", line: 16, claim: "지금 상태 모델은 셋으로 나뉜다. 원천은 하니스 agent 목록 · git 상태 계산 · 실행 원장이고, 기계 상태 표는 그 사본이다. STATUS.md 를 들이면 이 정본 · 사본 관계를 다시 정해야 한다.", touches: [], decides: []}
  - {id: RC8, path: "plugins/spec-distill/references/conductor-dispatch.md", anchor: "9. **스위트 잠금.** — 「경로는 지휘자가 … conductor_ledger.py suite-lock --roadmap <로드맵> 의 첫 줄로 얻어 싣는다」", line: 15, claim: "공유 스위트 잠금 · 임시 폴더(resource-dir) · 로드맵 표지(claim)는 모두 한 기계의 로컬 파일시스템 경로다. 다른 서버의 지휘자와는 이 장치로 조정할 수 없다.", touches: [], decides: []}
  - {id: RC9, path: "CLAUDE.md", anchor: "### 런타임 상태 & 훅 — 「런타임 state 는 `.claude/<plugin>/` 하위에 산다(git-ignored …)」 · 「인터뷰처럼 세션을 넘는 진행 기록은 docs 의 추적 파일에 두고」", claim: "레포 규칙은 상태를 git-ignored 런타임 상태와 추적되는 진행 기록 둘로 가른다. 팀 폴더 · STATUS.md · inbox/ · INTENT.md 가 어느 쪽인지 정하지 않으면 배치가 이 규칙과 어긋나고, 기계 간 공유도 정해지지 않는다.", touches: [], decides: []}
  - {id: RC10, path: "plugins/project-init/hooks/hooks.json", anchor: "\"PostToolUse\" — 「matcher\": \"Bash|EnterWorktree\"」", claim: "레포에 등록된 훅은 project-init 의 PostToolUse 하나뿐이고 SessionStart 훅은 없다. 「세션을 비운 뒤 시작 훅이 넣는 현황 요약」은 새 훅 표면이다. CLAUDE.md 훅 규칙(kill switch · SessionStart 는 읽기 전용 · README 의 「왜 skill 이 아닌가」)이 따라온다.", touches: [], decides: []}
  - {id: RC11, path: "CLAUDE.md", anchor: "Law 1 — 「*Trivia escape:* 한 문장으로 설명 가능한 trivia diff … 는 게이트 우회」 · Forbidden Patterns 「Trivia ceremony」", claim: "레포는 작은 diff 가 전체 파이프라인을 건너뛰게 한다. seed 의 「작은 일도 지휘자를 거친다 · 지휘자 없는 흐름을 두지 않는다」와 이 escape 의 관계를 정해야 한다.", touches: [], decides: []}
  - {id: RC12, path: "plugins/spec-distill/references/conductor-dispatch.md", anchor: "## 단계마다 새 agent — 「한 agent 가 리뷰~계획을 이으면 맥락이 백만 토큰 가까이 커진다」", line: 37, claim: "지금은 단계마다 새 agent 를 보내 맥락을 끊는다. 영상의 「과제마다 세션 하나를 잇다 끝나면 닫기」와 단위가 다르다. 과제 단위를 무엇으로 볼지 정할 때 이 실측 근거와 맞춰야 한다.", touches: [], decides: []}
  - {id: RC13, path: "docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md", anchor: "「헤드리스 실행은 Skill 도구를 거부한다 — 사람 몫」", line: 238, claim: "레포 기록이 헤드리스 실행의 Skill 도구 거부를 확인한다. docs/superpowers/plans/2026-10-18-r2a-plan2-shared-engine-security.md 1538행은 「헤드리스 claude -p 는 rc 0 으로 조용히 실패하는 일이 있으니 결과 파일의 바이트로 판정한다」고 적는다. 일꾼을 claude -p 로 돌리면 skill 기반 단계를 못 쓰고, 결과 파일 검사가 필수가 된다.", touches: [], decides: []}
  - {id: RC14, path: "plugins/spec-distill/references/conducting.md", anchor: "### 1. 맞추기 — 병권장 수 「동시에 돌리는 큰 작업의 권장 수는 기본 3 … 이고 상한이 아니다」", line: 19, claim: "지금 병렬 규칙은 기본 3, 상한 아님, 병목은 스위트 잠금 · 같은 파일 겹침이다. seed 의 「빌드처럼 무거운 일만 동시 2개 · 나머지는 서버 부하를 보고」는 성격이 다른 상한 규칙이라, 둘을 어떻게 합칠지 정해야 한다.", touches: [], decides: []}
```

메모 (orchestrator 용): 조사 주장 계약을 받았다. 열린 결정 목록이 비어 있어서 모든 decides 는 [] 다. 전제 P<n> 도 받지 못해 모든 touches 도 [] 다. neglect_flag 는 false 다. 원장에 집중 중인 차원이 없고 아직 라운드도 없어서다. 다만 seed 자체가 my-team 구조를 들이는 쪽과 대화 계약 쪽으로 기울어 있다. 위 차원 가운데 셋은 seed 에 거의 없다: 갈아타는 길, 믿음 경계와 보안, 여러 기계 사이 자원 조정. 첫 라운드에서 볼 만하다. 「다시 검증할 것」 항목 중 셋은 조사로 결론이 났다(하위 agent 자동 압축 E1 · 지휘 절차서 35,641 RC4 · 작업 목록 원인 후보 E6, 직접 재현 안 함). 역할 폴더 CLAUDE.md 가 그 역할에만 실리는지는 문서로 확정하지 못했다(E2, uncertain). 확인하지 못한 것: 토큰 수를 실시간으로 보여 주는 플랫폼 기능(statusline · /cost · OpenTelemetry)은 조사하지 않았다. 레포 전체 grep 결과 cache_read_input_tokens · input_tokens 는 정리된 설계문서 하나와 codex 테스트 fixture 하나에만 나온다. 토큰을 세는 동작 코드는 레포에 없다.

### 조사 2 — orchestrator · R1 · 묶음 2

- 확인 RC1 … RC14 — 위 R1 «지금 이해»의 확인 줄 14개 그대로
- 관찰 — 이 세션(claude-opus-5-5)의 도구 목록에 TaskCreate · TodoWrite 가 없다 [→ OQ2]

### 조사 3 — blind-spot-prober · R2 · 묶음 3

(하니스 표시: 출력에 bypass-permissions 꼴 문구가 있어 제어 태그를 무력화했다 — 문서의 bypassPermissions 모드 서술이고 지시가 아니다)

```yaml
hidden_assumptions:
  - assumption: "토큰 낭비와 공유 누락은 둘 다 맥락이 파일에 안 남아서 생긴다(S2 「같은 뿌리」). 그러니 파일 규약을 늘리면 둘 다 줄어든다."
    why_risky: "레포에는 이미 파일 원칙이 있다(P14 「State Survives Compaction」). 지휘 절차도 machine.md · relay 파일 · intents.md · `## 지휘 기록` 을 13번 언급한다. 지금 토큰의 큰 몫은 오히려 «읽는 파일»이다(절차서 약 3.5만 토큰을 부를 때마다 읽는다). 팀 공통 CLAUDE.md · 역할 CLAUDE.md · INTENT · STATUS · HANDBOOK · inbox 를 일꾼마다 시작할 때 읽게 하면 dispatch 마다 드는 고정비가 오른다. 또 공유 누락의 원인이 «파일이 없음»이 아니라 «행동에 묻은 암묵적 결정이 글로 옮겨지지 않음»이면 파일 규약으로는 고쳐지지 않는다."
    evidence:
      - url: "https://cognition.ai/blog/dont-build-multi-agents"
        supports: current
        claim: "원칙 2 'Actions carry implicit decisions'. 과제 원문을 하위에 넘겨도 이미 쌓인 도구 호출 · 암묵적 결정은 전달되지 않는다. 병렬 하위끼리는 스타일 · API 선택이 어긋난다."
        touches: []
        decides: [OQ3]
      - url: "https://arxiv.org/abs/2503.13657v2"
        supports: current
        claim: "MAST: 다중 agent 실패의 한 범주가 inter-agent misalignment(정보 누락 · 확인 질문 안 함 · 대화 리셋)다. 저자들은 단순한 통신 프로토콜로는 이 실패를 막기에 부족하다고 결론냈다."
        touches: []
        decides: [OQ3]
  - assumption: "역할 폴더에 둔 CLAUDE.md(할 일 · 하지 않을 일)를 그 역할의 일꾼이 읽는다."
    why_risky: "공식 문서상 cwd 아래 하위 폴더의 CLAUDE.md 는 Claude 가 그 폴더 파일을 열 때에만 on-demand 로 읽힌다. 하위 agent 는 메인 대화가 읽은 계층을 그대로 읽는다. 팀원도 일반 세션과 같은 project context 를 읽는다. 일꾼의 cwd 가 코드 worktree 이면 팀 폴더의 역할 CLAUDE.md 는 자동으로 읽히지 않는다. 또 CLAUDE.md 는 'context, not enforced configuration' 이고, 세션 도중 고쳐도 다음 /clear · /compact · 재시작 전까지 반영되지 않는다. 그러니 HANDBOOK 으로 올린 규칙이 돌고 있는 일꾼에게 닿지 않는다."
    evidence:
      - url: "https://code.claude.com/docs/en/memory.md"
        supports: current
        claim: "CLAUDE.md files in the directory hierarchy above the working directory are loaded at launch. Files in subdirectories load on demand. 그리고 Claude treats them as context, not enforced configuration."
        touches: []
        decides: [OQ3]
      - url: "https://code.claude.com/docs/en/sub-agents.md"
        supports: current
        claim: "하위 agent 는 'every level of the CLAUDE.md hierarchy the main conversation loads' 를 읽는다. 역할별로 다르게 넣는 것은 정의의 본문 · omitClaudeMd 로 한다."
        touches: []
        decides: [OQ3]
      - url: "https://code.claude.com/docs/en/prompt-caching"
        supports: current
        claim: "CLAUDE.md 를 세션 도중 고치면 캐시는 유지되지만 편집은 반영되지 않는다. 다음 /clear · /compact · 재시작에 반영된다."
        touches: []
        decides: [OQ3]
  - assumption: "Claude Code 의 agent teams(메일함 · 공유 작업 목록)를 my-team 구조의 실행 기반이자 공식 용어로 쓸 수 있다."
    why_risky: "공식 제약이 사용자 제약과 정면으로 부딪힌다. (1) 세션 하나에 팀 하나이고 세션 사이에 팀을 공유할 수 없다. (2) 중첩 팀이 없다(담당자→하위 공유 요구와 충돌). (3) 리드는 바뀌지 않고, /resume 은 in-process 팀원을 되살리지 않는다. 그러니 «지휘 세션 리프레시»와 «팀»이 서로를 깨뜨린다. (4) 팀 설정 폴더는 세션이 끝나면 지워진다. (5) -p 에서는 팀원을 띄우지 않는다. (6) 팀원별 권한 모드를 띄울 때 정할 수 없고, 리드의 bypassPermissions 를 물려받는다. (7) 실험 기능이다. 팀을 켜면 이름 붙은 하위 agent 가 모두 팀원으로 바뀐다."
    evidence:
      - url: "https://code.claude.com/docs/en/agent-teams"
        supports: current
        claim: "Limitations: One team per session … can't share a team across sessions / No nested teams / Lead is fixed / /resume and /rewind do not restore in-process teammates / No per-teammate permission modes at spawn. Team config 는 세션 종료 시 제거된다. -p 와 Agent SDK 에서는 팀원을 띄우지 않는다."
        touches: []
        decides: [OQ3]
      - url: "https://code.claude.com/docs/en/agent-teams"
        supports: current
        claim: "Agent teams … use significantly more tokens than a single session … For routine tasks, a single session is more cost-effective. 과제가 너무 작으면 coordination overhead exceeds the benefit."
        touches: []
        decides: [OQ3]
  - assumption: "모든 단계 · 작은 일까지 팀과 지휘자를 거치게 해도 토큰이 줄어든다."
    why_risky: "다중 agent 구조는 같은 일을 단일 agent 보다 몇 배의 토큰으로 한다. 사용자의 첫 문제는 «토큰이 너무 많이 든다»인데, 처방(모든 단계 팀화)이 기본 지출을 늘리는 쪽이다. 레포의 Trivia ceremony 금지와도 긴장한다."
    evidence:
      - url: "https://www.anthropic.com/engineering/multi-agent-research-system"
        supports: current
        claim: "agent 는 채팅보다 약 4배, 다중 agent 는 약 15배 토큰을 쓴다. 모든 agent 가 같은 맥락을 공유해야 하거나 의존이 많은 영역은 지금 다중 agent 에 맞지 않는다(Anthropic 은 코딩을 덜 병렬화 가능하다고 함). 원문 페이지는 직접 열지 않았고 검색 발췌 · 2차 보도로 확인했다."
        touches: []
        decides: [OQ3]
  - assumption: "리프레시(새 세션 · 새 agent)는 비용을 줄인다. 토큰 수가 리프레시 신호로 쓸 만하다."
    why_risky: "Claude Code 비용은 캐시 읽기가 지배한다(영상 제작자 측정: 입력의 98.5% · 99%가 캐시 읽기). 원시 토큰 합계는 값싼 캐시 읽기와 비싼 새 입력 · 캐시 쓰기를 섞는다. 새 세션 · /compact 는 프로젝트 맥락 층을 다시 쓴다. 하위 agent 와 팀원은 구독이라도 TTL 이 5분이라 길게 쉬면 캐시를 다시 쓴다. 캐시는 기계 · 디렉토리 단위라 worktree 가 다르면 서로의 캐시를 못 읽는다. 원시 토큰 % 로 리프레시를 걸면 맥락은 줄고 청구액은 늘 수 있다. 반면 맥락이 길수록 품질이 떨어지는 것(context rot)은 리프레시를 지지한다. 두 신호를 갈라야 한다."
    evidence:
      - url: "https://code.claude.com/docs/en/prompt-caching"
        supports: both
        claim: "/compact 뒤 project context 층은 'rebuilt even if its files are unchanged'. subagents · in-process teammates 는 'Everything else' 버킷이라 기본 5분 TTL. 'the cache is effectively scoped to one machine and directory'."
        touches: []
        decides: [OQ5]
      - url: "https://recca0120.github.io/en/2026/04/13/claude-code-session-cost-cache-misconception/"
        supports: alternative
        claim: "커뮤니티 분석: 잦은 /clear 는 매 새 세션이 CLAUDE.md 를 다시 읽고 캐시를 다시 데우므로 긴 세션보다 비쌀 수 있다(2차 출처, uncertain)."
        touches: []
        decides: [OQ5]
      - url: "https://research.trychroma.com/context-rot"
        supports: alternative
        claim: "입력 길이가 늘수록 18개 LLM 의 성능이 점점 불안정해진다. 품질 측면에서는 리프레시를 지지한다."
        touches: []
        decides: [OQ5]
  - assumption: "세션 기록(transcript jsonl)의 usage 를 모으면 토큰을 정확히 잴 수 있다."
    why_risky: "세션 기록 형식은 공식 스키마가 없다. 알려진 오염이 여럿이다. 응답 하나가 content block 마다 같은 usage 를 되풀이하고, input_tokens 에 스트리밍 placeholder(1)가 남고, 하위 agent 기록은 하위 폴더에 따로 있고, /btw 사이드 기록이 전체 대화를 다시 싣는다. 세션 기록은 cleanupPeriodDays(기본 30일) 뒤 지워져 「한 번 재서 낭비 줄이기」의 기준선이 사라진다. 상태줄의 prompt_cache 통계는 하위 agent 요청을 세지 않는다. cost.total_cost_usd 는 클라이언트 추정이고 /clear 때 0 으로 돌아간다."
    evidence:
      - url: "https://claudeissues.com/issue/87303-bug-session-transcript-repeats-the-full-usage-object-for-every-content-block-of"
        supports: current
        claim: "세션 기록이 API 응답 하나를 content block 마다 assistant 항목으로 쓰고 각 항목에 같은 usage 를 되풀이한다. 그대로 더하면 이중 계수가 된다."
        touches: []
        decides: [OQ5]
      - url: "https://github.com/anthropics/claude-code/issues/28197"
        supports: current
        claim: "usage.input_tokens 가 스트리밍 placeholder(흔히 1)로 기록되고 끝난 뒤 갱신되지 않는다."
        touches: []
        decides: [OQ5]
      - url: "https://net.nhd.workers.dev/ryoppippi/ccusage/issues/913"
        supports: current
        claim: "subagents/ 아래 /btw 파일이 전체 대화를 캐시 읽기로 다시 기록해 합계를 부풀린다(미러 출처, uncertain)."
        touches: []
        decides: [OQ5]
      - url: "https://code.claude.com/docs/en/statusline.md"
        supports: both
        claim: "상태줄 JSON 에 context_window.used_percentage · current_usage(cache read/creation 분리) · cost.total_cost_usd(client-side estimate, /clear 시 0) · transcript_path 가 있다. prompt_cache 통계는 'doesn't count subagent requests'."
        touches: []
        decides: [OQ5]
      - url: "https://code.claude.com/docs/en/memory.md"
        supports: current
        claim: "Claude Code 는 cleanupPeriodDays 가 지나면 옛 세션 기록을 지운다."
        touches: []
        decides: [OQ5]
  - assumption: "다른 기계의 지휘자끼리 플랫폼 세션 메시지로 믿을 만하게 소통할 수 있다."
    why_risky: "다른 기계로 보내려면 양쪽 모두 Remote Control 과 claude.ai 로그인이 필요하다. API 키 · Bedrock 등에서는 다른 기계 세션을 찾을 수 없다. Remote Control 에 붙지 않은 채 보내면 답장 주소가 없다. cloud 세션은 답장하지 못한다. bypassPermissions 인 받는 쪽은 기본으로 메시지를 보류하고, -p 에서는 보류 메시지가 dialogExpiry(기본 5분) 뒤 버려진다. 보류는 100건, 큐는 50건이 상한이다. 메시지는 평문뿐이고 파일 · 이력은 따라가지 않는다. 사용자가 요구한 «받음 · 답함 확인 · 우리 agent 가 보낸 글인지 확인» 중 출처 확인은 같은 계정 수준까지만 보장된다."
    evidence:
      - url: "https://code.claude.com/docs/en/cross-session-messaging.md"
        supports: current
        claim: "다른 기계 세션은 Remote Control 연결 상태에서만 보이고 claude.ai 로그인이 필요하다. 'Claude can't find those sessions with an API key or on Amazon Bedrock…'. offline 이면 재연결 뒤 도착하고, Remote Control 미연결 송신은 reply address 가 없다. -p 의 보류 메시지는 dialogExpiry 뒤 drop 된다. 'Claude Code holds at most 100 messages'. Plain text only."
        touches: []
        decides: [OQ4]
  - assumption: "터미널 현황을 보여 줄 「모드」는 안전하고 가벼운 표시 장치다."
    why_risky: "Claude Code mods(2026-10 출시)는 실재하고 패널 · 프롬프트 위 띠를 그릴 수 있다. 하지만 mod 는 사용자 권한으로 도는 샌드박스 없는 JS/TS 코드다. 도구 호출을 자동 승인할 수 있고, 내장 가드가 없으면 deny 규칙 · PreToolUse 훅도 넘는다. devbrew 의 파이썬 · 셸 표면 밖의 새 언어 표면이다. 공식 문서는 mod 의 handler 를 'hook' 이라 부른다. 그래서 «모든 훅에 kill switch» 규칙이 걸린다. -p · Agent SDK · cloud 세션에서는 아무것도 그리지 않는다(헤드리스 일꾼의 현황은 안 보인다). 최소 판(v2.1.287, VS Code 2.1.299)을 dependencies.md 에 적어야 한다."
    evidence:
      - url: "https://code.claude.com/docs/en/plugins/mods/overview.md"
        supports: both
        claim: "mod 는 플러그인에 담겨 설치되고 pane/band 를 그린다. 'Mods aren't sandboxed', 'Act without asking you: approve a tool call before you're asked'. claude -p · Agent SDK 에서는 'What the mod draws appears: No'. 터미널은 v2.1.287 이상이다."
        touches: []
        decides: [OQ6]
failure_modes:
  - mode: "지휘 세션을 리프레시하는 순간 팀이 증발한다. 리드가 없는 팀원에게 메시지를 보내고, 일을 중복 배정하고, 일이 고아가 된다."
    trigger: "agent teams 를 일꾼 기반으로 고르고, 토큰 신호로 리드 세션을 /clear · 새 세션 · /resume 할 때."
    evidence:
      - url: "https://code.claude.com/docs/en/agent-teams"
        supports: current
        claim: "After resuming a session, the lead may attempt to message teammates that no longer exist. Lead is fixed. Team config 는 세션 종료 시 제거된다."
        touches: []
        decides: [OQ3]
  - mode: "0토큰 현황 보기(STATUS · 작업 목록)가 실제와 어긋난다. 끝난 일이 진행 중으로 남아 의존 과제가 막히고, 사람이 낡은 현황을 믿는다."
    trigger: "일꾼이 상태 갱신 없이 끝나거나 오류로 멈출 때. 현황이 일꾼이 쓰는 파일에만 기댈 때."
    evidence:
      - url: "https://code.claude.com/docs/en/agent-teams"
        supports: current
        claim: "Task status can lag: teammates sometimes fail to mark tasks as completed, which blocks dependent tasks. Teammates may stop after encountering errors."
        touches: []
        decides: [OQ3, OQ6]
  - mode: "받음 확인 · 되읽기 계약이 형식만 남는다. 일꾼이 「읽고 이해함」을 적지만 지시를 오해한 채 진행하고, 확인 질문을 하지 않는다."
    trigger: "되읽기를 자기 보고 문장으로 받고 내용 대조(예: 지시 핵심의 재진술 비교)가 없을 때."
    evidence:
      - url: "https://arxiv.org/abs/2503.13657v2"
        supports: current
        claim: "failure to ask for clarification · withholding information 이 주요 실패 양식이다. 단순한 프로토콜로는 부족하다."
        touches: []
        decides: []
  - mode: "토큰 계측이 조용히 틀린다(이중 계수 · 과소 계수 · 하위 agent 누락). 리프레시가 너무 잦거나 전혀 안 걸리고, 낭비 진단이 엉뚱한 곳을 가리킨다."
    trigger: "세션 기록 jsonl 을 줄마다 더하거나, 메인 세션 파일만 읽거나, 30일이 지난 뒤 기준선을 다시 잴 때."
    evidence:
      - url: "https://claudeissues.com/issue/87303-bug-session-transcript-repeats-the-full-usage-object-for-every-content-block-of"
        supports: current
        claim: "같은 usage 가 content block 마다 되풀이된다."
        touches: []
        decides: [OQ5]
      - url: "https://openskillindex.com/skills/tdimino-claude-code-minoan-claude-usage"
        supports: current
        claim: "ccusage 가 {session}/subagents/{agent}.jsonl 을 무시해 크게 과소 계수한다는 보고가 있다(3자 출처, uncertain)."
        touches: []
        decides: [OQ5]
  - mode: "캐시 재작성 폭풍: 맥락 % 는 내려가는데 청구액 · 사용량 한도 소모는 오른다."
    trigger: "리프레시 문턱을 맥락 크기 하나로 정하고, 구현 일꾼을 자주 새로 보내고, 일꾼이 5분 넘게 기다리는 단계(빌드 동시 2개 제한 대기 · 스위트 잠금 --wait)가 섞일 때."
    evidence:
      - url: "https://code.claude.com/docs/en/prompt-caching"
        supports: current
        claim: "subagents · teammates 는 기본 5분 TTL(subagentPromptCacheTtl 로 1h 가능, 쓰기 단가 더 높음). 하위 agent 의 첫 요청은 부모 캐시를 읽지 못한다."
        touches: []
        decides: [OQ5]
  - mode: "구현 일꾼을 과제 중간에 리프레시하면 암묵적 결정이 사라진다. 새 일꾼이 앞 일꾼과 다른 선택을 해서 같은 과제 안에 불일치가 생긴다."
    trigger: "리프레시를 과제 경계가 아니라 토큰 문턱에서 걸 때. INTENT.md 의 결정 기록이 일꾼이 실제로 한 선택을 다 못 담을 때."
    evidence:
      - url: "https://cognition.ai/blog/dont-build-multi-agents"
        supports: current
        claim: "Actions carry implicit decisions. 결정이 상충하면 나쁜 결과가 나온다."
        touches: []
        decides: []
  - mode: "agent teams 를 켜자 기존 지휘 흐름이 조용히 바뀐다. 이름 붙은 하위 agent 가 팀원으로 뜨고, 권한 모드가 리드를 따라가고, 백그라운드 하위 agent 가 막힌다."
    trigger: "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 을 사용자 · 프로젝트 settings 에 켤 때. 지휘자가 SendMessage 로 같은 agent 를 이어 부르는 기존 흐름과 섞일 때."
    evidence:
      - url: "https://code.claude.com/docs/en/agent-teams"
        supports: current
        claim: "Enabling agent teams also changes ordinary delegation … a subagent that Claude names launches as a teammate. 리드가 bypassPermissions 이면 새 팀원도 그 모드로 시작한다. in-process 팀원은 background 하위 agent 를 띄울 수 없다."
        touches: []
        decides: [OQ3]
  - mode: "다른 기계의 지휘자 메시지가 소실 · 보류 · 만료된다. 같은 파일을 건드리려는 알림이나 머지 순서 합의가 닿지 않은 채 양쪽이 진행한다."
    trigger: "받는 지휘자가 bypassPermissions · -p 로 돌거나, Remote Control 이 끊기거나, API 키 인증일 때."
    evidence:
      - url: "https://code.claude.com/docs/en/cross-session-messaging.md"
        supports: current
        claim: "bypass 하는 받는 쪽은 기본으로 보류한다. -p 는 dialogExpiry(기본 5분) 뒤 drop 한다. offline 은 재연결까지 미도착이다. 반복 메시지는 rate-limit · 동일 반복 drop 된다."
        touches: []
        decides: [OQ4]
  - mode: "레포 MEMORY.md 와 Claude 자동 메모리 MEMORY.md 가 섞인다. 팀 규칙이 기계 로컬 자동 메모리에 쓰여 다른 서버 지휘자에게 닿지 않거나, 120줄 규약과 200줄 · 25KB 자동 로드 규약이 혼동된다."
    trigger: "역할 파일에서 「MEMORY.md 에 규칙을 적어라」라고 지시할 때. 자동 메모리가 켜진 세션에서."
    evidence:
      - url: "https://code.claude.com/docs/en/memory.md"
        supports: current
        claim: "자동 메모리의 MEMORY.md 는 ~/.claude/projects/<project>/memory/ 의 색인이다. 매 세션 첫 200줄 또는 25KB 를 읽는다. 'Auto memory is machine-local … not shared across machines'."
        touches: []
        decides: []
  - mode: "현황 mod 가 보안 표면이 된다. kill switch 없이 도는 JS handler 가 도구 호출을 승인하거나, disableAllHooks 로 끄면 상태줄 · 다른 훅까지 함께 꺼진다."
    trigger: "현황 표시를 mod 로 만들면서 표시 이외의 이벤트(tool.call 등)를 구독하거나, DEVBREW_<PLUGIN>_DISABLE 을 mod 진입에서 읽지 않을 때."
    evidence:
      - url: "https://code.claude.com/docs/en/plugins/mods/overview.md"
        supports: current
        claim: "A mod can approve many tool calls that your deny or ask rules or your PreToolUse hooks would stop, unless the built-in guard prevents it. disableAllHooks 는 settings hooks 와 custom status line 도 멈춘다."
        touches: []
        decides: [OQ6]
confidence: 0.75
repo_claims:
  - id: RC1
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "검사받는 하위 agent 도 쓸 수 있는 파일이라 스위트 대조가 읽지 않는다"
    line: 59
    claim: "지금 지휘 계약은 하위가 쓸 수 있는 파일을 판정 근거에서 뺀다. «결과 파일로만 보고» · 일꾼이 쓰는 STATUS · INTENT 를 판정 · 현황의 근거로 삼는 방향은 이 신뢰 경계와 충돌한다. 일꾼이 쓴 파일 중 무엇을 근거로 읽고 무엇을 지휘자 측 대조로 다시 재는지 정해야 한다."
    touches: []
    decides: [OQ3]
  - id: RC2
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "실행 방식이 작업 폴더를 지울 수 있어 경로만으로는 부족하다"
    line: 43
    claim: "마지막 메시지에 결과 전문을 싣는 이유가 작업 폴더 삭제다. 「메시지는 짧게, 자세한 것은 파일 경로로」로 바꾸면 이 실패(경로가 가리키는 파일이 사라짐)가 되살아난다. 과제 폴더가 일꾼 worktree 밖, 지워지지 않는 자리에 있어야 성립한다."
    touches: []
    decides: [OQ3]
  - id: RC3
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "구현 agent 는 새로 보낸다 — 계획 agent 를 이어 쓰지 않는다(한 agent 가 리뷰~계획을 이으면 맥락이 백만 토큰 가까이 커진다)"
    line: 37
    claim: "단계 경계에서 새 agent 를 보내는 리프레시는 이미 구조로 있다. 새로 요구되는 것은 «단계 안» 리프레시다. 그 경우 숨은 가정(암묵적 결정 손실 · 캐시 재작성)이 더 크게 걸린다."
    touches: []
    decides: [OQ3, OQ5]
  - id: RC4
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "하위가 돌린 리뷰를 다시 돌거나 좁은 재리뷰를 할 때는 같은 agent 를 이어 부른다(`SendMessage`)"
    line: 38
    claim: "기존 흐름이 이름 붙은 하위 agent 를 SendMessage 로 이어 부른다. agent teams 를 켜면 이름 붙은 하위 agent 가 팀원으로 뜨므로 이 경로의 동작(격리 · 백그라운드 · 권한 모드)이 바뀐다."
    touches: []
    decides: [OQ3]
  - id: RC5
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### /compact 시점"
    line: 84
    claim: "지휘 세션 리프레시는 지금 «끊기 좋은 자리 + 맥락이 무거우면 + 사용자만 압축»이다. 자동 신호로 바꾸면 그 «끊기 좋은 자리» 판단(계획 agent 를 보낸 직후 등)을 신호가 대신해야 한다. 토큰 수만으로는 그 자리를 모른다."
    touches: []
    decides: [OQ5]
  - id: RC6
    path: "docs/philosophy/devbrew-harness-philosophy.md"
    anchor: "### P14 — State Survives Compaction"
    line: 90
    claim: "«load-bearing 사실은 파일로»는 이미 정본 원칙이다. 그런데도 공유 누락이 난다면 원인은 «파일 부재»가 아니라 무엇을 · 누가 · 언제 읽는가일 수 있다. S2 「같은 뿌리」 진단의 숨은 가정이다."
    touches: []
    decides: []
  - id: RC7
    path: "docs/philosophy/devbrew-harness-philosophy.md"
    anchor: "정석 흐름(brainstorming → 계획 → 구현)의 의도는 지키되 순서를 강제하는 결정론은 두지 않는다"
    line: 84
    claim: "단계표 + 배정 스크립트는 순서를 강제하는 결정론이다. P8 개정은 사용자가 정했지만, 개정 범위가 qg 판정 floor 예시(정확성 한 점에만 결정론)와 «모델이 판단하고 이유를 적는다» 원칙까지 무너뜨리지 않도록 경계가 필요하다."
    touches: []
    decides: []
  - id: RC8
    path: "docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.audit.md"
    anchor: "캐시 읽기 비율: 이 구조로 돌린 실제 제작 세션 2개에서 입력 토큰의 98.5%, 99.0%"
    line: 132
    claim: "영상 측 측정에서도 입력의 대부분이 캐시 읽기다. 원시 토큰 수를 낭비 · 리프레시 지표로 쓰면 값싼 캐시 읽기에 끌려간다. 캐시 읽기 · 쓰기 · 새 입력 · 출력을 갈라 재야 한다."
    touches: []
    decides: [OQ5]
  - id: RC9
    path: "CLAUDE.md"
    anchor: "**Trivia ceremony** — 한 문장 diff에 full pipeline 실행"
    claim: "«설계문서 하나뿐인 작은 일도 지휘자를 거친다»는 레포 금지 패턴과 긴장한다. trivia escape(P12)를 팀 구조에서 어떻게 남길지 정하지 않으면 작은 일에 팀 비용이 붙는다."
    touches: []
    decides: []
  - id: RC10
    path: "CLAUDE.md"
    anchor: "**모든 훅에 kill switch.** 진입 skill 도 같다."
    claim: "공식 문서는 mod 의 handler 를 'hook' 이라 부른다. 현황 표시를 mod 로 만들면 DEVBREW_<PLUGIN>_DISABLE 존중 · README 「설치된 Hook」 문서화 · 왜 skill 이 아닌가 정당화를 함께 갖춰야 한다."
    touches: []
    decides: [OQ6]
```

참고:
- confidence 0.75 는 framing 이 약하다는 뜻이 아니다. 여러 공식 제약(agent teams 의 리드 고정 · 재개 불가 · 세션당 팀 하나, 교차 기계 메시지의 Remote Control · claude.ai 로그인 요구, 세션 기록 30일 삭제)이 사용자 제약과 정면으로 부딪힌다는 뜻이다. 그중 가장 센 충돌은 «지휘 세션 리프레시»와 «agent teams» 가 서로를 깨뜨린다는 것이다.
- `touches` 는 모두 빈 배열이다. 전제 `P<n>` 목록을 받지 못해서 거짓 부착을 피했다.
- 2차 · 미러 출처(recca0120 블로그, ccusage #913 미러, openskillindex)는 uncertain 으로 읽어야 한다. Anthropic 의 15배 수치는 원문을 직접 열지 않고 발췌로 확인했다.
- OQ6 는 웹으로 판정됐다. Claude Code mods 는 2026-10 에 출시된 실재 기능이고(v2.1.287 이상, 대화 옆 pane · 프롬프트 위 band), 사용자가 말한 「모드」가 이것일 공산이 크다. 다만 사용자 확인은 아직 없다.

Sources:
- [Claude Code docs — agent teams](https://code.claude.com/docs/en/agent-teams)
- [Claude Code docs — cross-session messaging](https://code.claude.com/docs/en/cross-session-messaging.md)
- [Claude Code docs — subagents](https://code.claude.com/docs/en/sub-agents.md)
- [Claude Code docs — memory](https://code.claude.com/docs/en/memory.md)
- [Claude Code docs — prompt caching](https://code.claude.com/docs/en/prompt-caching)
- [Claude Code docs — status line](https://code.claude.com/docs/en/statusline.md)
- [Claude Code docs — mods overview](https://code.claude.com/docs/en/plugins/mods/overview.md)
- [Cognition — Don't Build Multi-Agents](https://cognition.ai/blog/dont-build-multi-agents)
- [MAST — Why Do Multi-Agent LLM Systems Fail? (arXiv 2503.13657)](https://arxiv.org/abs/2503.13657v2)
- [Anthropic — multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)
- [Chroma — Context Rot](https://research.trychroma.com/context-rot)
- [recca0120 — long session cost misconception](https://recca0120.github.io/en/2026/04/13/claude-code-session-cost-cache-misconception/)
- [claude-code issue 87303 (usage 반복)](https://claudeissues.com/issue/87303-bug-session-transcript-repeats-the-full-usage-object-for-every-content-block-of)
- [anthropics/claude-code issue 28197 (input_tokens placeholder)](https://github.com/anthropics/claude-code/issues/28197)
- [ccusage issue 913 mirror](https://net.nhd.workers.dev/ryoppippi/ccusage/issues/913)
- [openskillindex — claude-usage](https://openskillindex.com/skills/tdimino-claude-code-minoan-claude-usage)

읽은 레포 파일:
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.audit.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/references/conducting.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/references/conductor-dispatch.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/docs/philosophy/devbrew-harness-philosophy.md

### 조사 4 — open-researcher · R2 · 묶음 3

```yaml
evidence:
  # ── Claude Code 공식: agent teams(실험 기능) ──
  - url: "https://code.claude.com/docs/en/agent-teams"
    supports: alternative
    claim: "[방식] 팀원(teammate)은 «따로 도는 Claude Code 인스턴스»다. 리더 세션 하나가 Agent 도구에 name 을 붙여 띄운다. 기본 표시는 in-process(같은 터미널)이고, split-pane 은 tmux 나 iTerm2(it2 CLI)가 필요하다. 실험 기능이라 CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 을 줘야 켜진다. 켜 두면 Claude 가 이름 붙인 하위 agent 도 팀원으로 뜨고, 이때 frontmatter 의 isolation 값은 무시된다(팀원은 리더의 작업 폴더에서 돈다). 팀원은 worktree 로 격리되지 않는다. 헤드리스(-p) · Agent SDK 세션은 팀원을 띄우지 않고 이름 붙인 하위 agent 를 일반 하위 agent 로 돌린다. 제한: 세션당 팀 하나 · 중첩 팀 없음 · 리더 고정 · /resume 하면 in-process 팀원이 되살아나지 않음."
    touches: []
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 (plugins/spec-distill/dependencies.md 에 잰 값)", latest: "v2.1.323 (GitHub release, 2026-11-12)"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/agent-teams"
    supports: alternative
    claim: "[글 주고받기 · 받음 확인 · 보고] 메일함은 ~/.claude/teams/{team}/inboxes/{agent}.json 의 JSON 파일이다. 받는 쪽 메일함 파일에 쓰기가 성공해야 '보냄'으로 치고, 실패하면 보낸 쪽이 오류를 받는다. 이것은 쓰기 확인이지 읽음 확인이 아니다. 메시지는 자동으로 배달되고(폴링 불필요), 팀원이 멈추면 리더에게 idle 알림이 가며 «최종 답을 알림에 담는다»(결과는 메시지로 온다). 공유 작업 목록은 ~/.claude/tasks/{team}/ 에 있고 파일 잠금으로 맡는다. 팀 설정 · 작업은 모두 로컬(~/.claude)이라 기계를 넘는 팀은 문서에 없다('one team per session … can't share a team across sessions')."
    touches: []
    decides: [OQ3, OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/agent-teams"
    supports: alternative
    claim: "[맥락 갱신] 팀원마다 맥락 창이 따로 있다. in-process 팀원에는 하위 agent 정의의 autoCompactWindow 가 적용된다(v2.1.296+). split-pane 팀원은 이 필드를 무시한다. 리더의 대화 이력은 넘어가지 않고 spawn 프롬프트만 넘어간다. 멈춘 팀원은 '교체 팀원을 띄우라'고 안내한다. 팀원 맥락을 지휘자가 교체하는 전용 기구는 문서에 없다."
    touches: []
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  # ── Claude Code 공식: 하위 agent ──
  - url: "https://code.claude.com/docs/en/sub-agents"
    supports: current
    claim: "[방식 · 보고] 하위 agent 는 한 세션 안에서 자기 맥락 창으로 돌고 결과를 부른 쪽에 돌려준다. 백그라운드 하위 agent 의 결과는 다음 턴에 '완료 알림'으로 온다(메시지). 이어 부르기는 SendMessage(to=agent id 나 이름)이고 팀 기능 없이도 된다. 끝난 하위 agent 는 메시지를 받으면 백그라운드에서 되살아난다. isolation: worktree 는 임시 git worktree 에서 돌고, 기본은 부모 HEAD 가 아니라 기본 브랜치에서 갈라진다. 중첩은 세 층까지, 동시 실행은 기본 20개다. transcript 는 ~/.claude/projects/{project}/{sessionId}/subagents/agent-{id}.jsonl 에 남는다. 다른 기계와 주고받는 길은 없다."
    touches: []
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "v2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/sub-agents"
    supports: both
    claim: "[판 차이 — 레포 판에 닿음] 문서 원문: 'Before v2.1.304, a subagent that Claude messaged or resumed right after it finished could forget its most recent work.' 레포가 잰 판은 2.1.303 이라 이 결함이 고쳐지기 전 판이다. 레포는 SendMessage 로 이어 부르는 방식을 쓴다. 맥락 쪽: 본 대화가 압축돼도 하위 agent transcript 에는 닿지 않는다. 하위 agent 별 autoCompactWindow 는 100000~1000000 범위다(v2.1.296+)."
    touches: []
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "v2.1.323"}
    certainty: confirmed
  # ── Claude Code 공식: 세션 사이 메시지(cross-session messaging) ──
  - url: "https://code.claude.com/docs/en/cross-session-messaging"
    supports: alternative
    claim: "[방식 · 운반] 사용자의 Claude Code 세션끼리 SendMessage/ListAgents 로 평문을 주고받는다. 켜는 것 없이 기본으로 켜져 있다(v2.1.224+, Windows 는 v2.1.234+). 같은 기계 안에서는 세션마다 Unix 소켓(Windows 는 named pipe)으로 가고 Anthropic 서버를 거치지 않는다. 다른 기계나 클라우드 세션으로는 Anthropic 서버를 거쳐 Remote Control 연결로 간다(v2.1.225+). 이 경로에는 claude.ai 로그인이 필요하고 API 키 · Bedrock · Vertex 계열은 안 된다. 상대가 offline 이면 다시 연결될 때 받는다. 이 세션이 Remote Control 에 연결돼 있지 않으면 답장 주소 없이 일방 전송이 된다. 문서는 대상을 «your sessions»(내 세션)로만 적는다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "v2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/cross-session-messaging"
    supports: alternative
    claim: "[받음 확인 · 한계] 받는 쪽은 inbound 설정에 따라 delivered · held · refused 셋 중 하나로 처리한다. 보낸 쪽은 크기 초과 · 폭주 · 상대가 받을 수 없는 경우에 'Not sent' 결과를 받는다. held 메시지는 기본 5분(dialogExpiry) 뒤 버려지고, 닿을 수 있는 보낸 쪽에는 만료로 보고된다. 일반적인 읽음 확인은 없다. 대신 같은 기계 세션 하나에는 notify_when_idle 로 'idle 이 되면 한 번 알림'을 구독할 수 있다(v2.1.236+, 12시간 뒤 만료, 다른 기계 대상은 거절). 평문만 간다. 같은 기계 상한은 약 100만 자, 받는 쪽 대기열은 50개다. 헤드리스 -p 세션도 소켓을 열어 받을 수 있지만, 무인으로 받으려면 crossSessionInbound=accept 가 필요하고 --bare 면 소켓이 없다."
    touches: []
    decides: [OQ4, OQ3]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/remote-control"
    supports: alternative
    claim: "[다른 기계 경로의 전제] Remote Control 은 Pro · Max · Ultra · Team · Enterprise 요금제에서 되고 API 키는 지원하지 않는다. Team/Enterprise 는 Owner 가 관리 설정에서 켜야 한다. ANTHROPIC_BASE_URL 을 게이트웨이로 돌리면 쓸 수 없다. claude 프로세스가 로컬에서 계속 돌아야 한다. 서로 다른 계정 · 사람의 세션끼리 메시지를 나르는지는 문서에서 확인하지 못했다(문서는 '내 세션'만 다룬다)."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  # ── Claude Code 공식: 헤드리스 claude -p / Agent SDK ──
  - url: "https://code.claude.com/docs/en/headless"
    supports: alternative
    claim: "[방식 · 보고] claude -p 는 비대화형 프로세스 하나다. 결과는 stdout 으로 나오고(text · json · stream-json), 종료 코드 0 이면 성공, 아니면 실패다. --json-schema 를 주면 structured_output 칸으로 받는다. 이어 가기는 --resume <session_id> 나 --continue 이고, 결과 json 에 session_id 가 있다. 세션 바꾸기는 새 -p 실행 자체다. --bare 는 hooks · skills · plugins · CLAUDE.md 를 읽지 않으며 앞으로 -p 의 기본값이 될 예정이라고 공시돼 있다. bare 모드에는 ANTHROPIC_API_KEY 가 필요하다(구독 로그인 미사용). 판 v2.1.302+ 에서는 권한 모드를 정하지 않으면 Manual 로 시작해, 승인이 필요한 호출은 거부된다. 다른 기계 통신 기능은 따로 없다."
    touches: []
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "v2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/headless"
    supports: alternative
    claim: "[토큰 · 비용] --output-format json 결과에 total_cost_usd 와 모델별 비용 내역이 있고, stream-json 의 마지막 result 메시지에 cost · usage 가 있다. 둘 다 클라이언트 쪽 추정치다. --resume 으로 이으면 앞 실행분까지 더한 대화 전체 합계를 보고한다."
    touches: []
    decides: [OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/agent-sdk/overview"
    supports: alternative
    claim: "[Agent SDK] Python · TypeScript 라이브러리이고 'A library that runs the Claude Code binary'다. 도구 · 권한 · 세션(resume/fork) · hooks · subagents · plugins 는 Claude Code 와 같다. 정책: 사전 승인 없이는 제3자 제품이 claude.ai 로그인 · 요금 한도를 제공할 수 없으니 API 키를 쓰라고 한다. 다른 언어에서는 -p 를 하위 프로세스로 돌리라고 한다."
    touches: []
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  # ── Claude Code 공식: agent view / 백그라운드 세션 ──
  - url: "https://code.claude.com/docs/en/agent-view"
    supports: alternative
    claim: "[방식] research preview 기능이다. claude --bg \"<prompt>\" 나 claude agents 로 띄우면 supervisor 백그라운드 서비스 아래에서 세션마다 따로 Claude Code 프로세스가 돈다. 파일을 고치기 전에 .claude/worktrees/ 아래 자기 worktree 로 옮긴다. 원격이 있으면 브랜치를 push 하고 draft PR 을 열 수 있다. [보고] 결과는 사용자에게만 간다(행 요약 · peek · Notification hook 의 agent_completed). 스크립트는 claude agents --json --all 의 state(working/blocked/done/failed/stopped)로 폴링한다. ~/.claude/jobs/ 파일은 안정 인터페이스가 아니라고 명시돼 있다. 세션끼리의 길은 cross-session messaging 뿐이다. --bg 와 -p 는 함께 쓸 수 없다. 다른 기계는 범위 밖이다(이 기능은 로컬 기계용)."
    touches: []
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/agents"
    supports: both
    claim: "[공식 지형 요약] 공식 병렬 방식은 다섯이다: subagents · agent view(research preview) · agent teams(experimental, 기본 꺼짐) · dynamic workflows · projects(claude.ai/code, 공개 베타). 보조 기구로 worktrees · cross-session messaging · /batch 가 있다. 원문: 'Subagents report results back to the conversation that spawned them, and agent view sessions report results only to you.' agent teams 는 worktree 로 격리하지 않는다."
    touches: []
    decides: [OQ3, OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  # ── herdr ──
  - url: "https://github.com/herdrdev/herdr"
    supports: alternative
    claim: "[도구 — herdr] Rust 단일 바이너리다(tmux 를 요구하지 않고, Electron 없음). 일꾼은 herdr 가 소유한 터미널 pane 에서 도는 «별도 대화형 CLI 세션»이다('doesn't wrap or replace them; it owns their terminals'). 백그라운드 서버가 클라이언트가 끊겨도 pane 을 살려 두고, pane 마다 working · blocked · idle 상태를 표시한다. 설치: curl 스크립트 · brew · mise · Windows PowerShell. 최신 릴리스는 v0.9.5(2026-10-14)이고, GitHub API 에서 ogulcancelik/herdr 가 herdrdev/herdr 로 넘어간다. 라이선스: README 는 Apache-2.0 이라 하지만 2차 자료(linuxlinks 등)에는 AGPL-3.0 · 듀얼 라이선스라는 서술도 있어 충돌한다."
    touches: []
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "레포가 쓰지 않음", latest: "v0.9.5 (2026-10-14)"}
    certainty: confirmed
  - url: "https://herdr.dev/docs/socket-api/"
    supports: alternative
    claim: "[방식 — herdr 통신] 로컬 소켓 위의 줄 단위 JSON(Unix 소켓 ~/.config/herdr/herdr.sock, Windows named pipe)이다. pane.send_text/send_keys/send_input 으로 글을 넣고, pane.read 로 화면을 읽고, agent.wait 로 상태를 기다리며, events.subscribe 로 사건을 받는다. 받음 확인은 응답이 요청 id 를 되돌리는 것인데, 원문은 'acknowledge queue admission, not command execution'이다(대기열 접수 확인일 뿐 실행 확인이 아니다). 완료는 wait 계열로 관찰한다. 결과 보고 전용 채널은 없다 — 화면 읽기 · 상태 기다리기로 본다. 이 방식은 '터미널에 글 주입 + 화면 읽기 + 상태 휴리스틱'이라 도구와 갈라 다른 멀티플렉서에서도 따라 할 수 있다."
    touches: []
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "레포가 쓰지 않음", latest: "문서 판 0.9.5"}
    certainty: confirmed
  - url: "https://herdr.dev/docs/persistence-remote/"
    supports: alternative
    claim: "[다른 기계 — herdr] herdr --remote <host> 는 SSH 로 원격 herdr 서버에 붙는 thin client 다. 기계마다 자기 서버 · 세션을 갖고, 저장된 SSH 기계 여럿을 한 창의 agent 목록으로 합쳐 본다. 이것은 사람 UI 를 원격으로 비추는 것이다. 소켓 API 는 로컬로 문서화돼 있고, 원격 raw 소켓이나 기계 간 agent 메시지 운반은 문서에서 확인하지 못했다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://www.linuxlinks.com/herdr-terminal-based-agent-multiplexer/"
    supports: alternative
    claim: "[2차] herdr 의 라이선스 · 스타 수 서술이 출처마다 다르다(AGPL-3.0 / Apache-2.0 / 듀얼). 맥락 갱신(세션 교체) 기능은 1차 · 2차 어디에서도 확인하지 못했다. 재시작 뒤 '지원하는 agent 세션 재개'만 1차에 있다."
    touches: []
    decides: [OQ3]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain
  # ── claude-squad ──
  - url: "https://github.com/smtg-ai/claude-squad"
    supports: alternative
    claim: "[도구 — claude-squad] Go TUI(cs)다. 일꾼은 agent 마다 tmux 세션 하나와 git worktree 하나를 쓰는 «별도 대화형 세션»이고, claude 외 프로그램은 -p 로 지정한다. 일꾼끼리나 지휘자-일꾼 사이의 메시지 기구는 없고 사람이 attach 해서 다시 지시한다. 결과는 diff 탭 · commit · push(사람 검토)로 받는다. 원격 지원은 문서에 없다. 맥락 리셋 기능도 문서에 없다(reset 은 저장된 인스턴스를 지우는 것). 의존: tmux · gh. 설치는 brew 나 curl 이다. 라이선스 AGPL-3.0. 최신 릴리스는 v1.0.20(2026-08-20)이다. -y/--autoyes 는 실험 기능이다."
    touches: []
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "레포가 쓰지 않음", latest: "v1.0.20 (2026-08-20)"}
    certainty: confirmed
  # ── ccmanager ──
  - url: "https://github.com/kbwo/ccmanager"
    supports: alternative
    claim: "[도구 — ccmanager] npm 전역 설치(Node 필요)이고 tmux 는 필요 없다. 자체 PTY 로 «별도 대화형 세션»을 돌린다. worktree 를 만들고 · 머지하고 · 지우며, 세션 데이터를 새 worktree 로 복사할 수 있다. 상태는 Idle/Busy/Waiting 이고 CLI 마다 감지 전략을 설정할 수 있다. 상태 변경 hook 이 있다. 세션 사이 메시지 기구 · 원격 지원은 문서에 없다(devcontainer 연동은 있음). 라이선스 MIT. 최신 릴리스는 v4.4.11(2026-10-27)이다."
    touches: []
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "레포가 쓰지 않음", latest: "v4.4.11 (2026-10-27)"}
    certainty: confirmed
  # ── workmux ──
  - url: "https://github.com/raine/workmux"
    supports: alternative
    claim: "[도구 — workmux] Rust 바이너리다. worktree 마다 멀티플렉서 창 하나를 쓰고(tmux · WezTerm · Kitty · Zellij 중 하나가 필수), 일꾼은 그 창의 대화형 agent 다. 직접적인 agent 간 메시지는 없다. 대시보드에서 pane 에 타이핑할 수 있고, `workmux add --wait` 로 창이 닫힐 때까지 기다리며, agent 는 `workmux remove --keep-branch` 로 끝났음을 알린다(종료 신호를 프로세스 · 창 수명으로 받는 방식). 상태 추적은 agent hook 으로 설치한다. 결과는 `workmux merge`(브랜치 머지 + 정리)로 받는다. 라이선스 MIT. 최신 릴리스는 v0.1.282(2026-11-10)이다."
    touches: []
    decides: [OQ3]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "레포가 쓰지 않음", latest: "v0.1.282 (2026-11-10)"}
    certainty: confirmed
  # ── Gas Town ──
  - url: "https://github.com/gastownhall/gastown"
    supports: alternative
    claim: "[도구 — Gas Town] Go 로 쓴 다중 agent 지휘 도구다. 일꾼(polecat)은 tmux 로 돌리는 대화형 Claude Code 세션이고, 정체(identity)는 오래 가고 세션은 일회성이다. 통신은 내장 메일함(gt mail)과 nudge 이고, 메일은 hook 으로 세션에 주입된다(gt mail check --inject). 작업 상태는 beads(git 으로 받쳐진 이슈 추적)와 worktree 에 있다. 맥락 갱신은 gt handoff(handoff 메일을 자기 · 후임에게 남기고 세션을 바꿈) · gt prime(맥락 복원) · seance(앞 세션 기록 조회)로 한다. 기계 간 연결은 'Federated … through DoltHub' 연합이다. 의존: Go 1.26.2+ · git 2.20+ · tmux 3.0+ · beads(bd) 0.57+ · Dolt · sqlite3 · Claude Code CLI. MIT. 최신 릴리스는 v1.2.1(2026-06-06)이고 steveyegge/gastown 이 gastownhall/gastown 으로 넘어간다."
    touches: []
    decides: [OQ3, OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "레포가 쓰지 않음", latest: "v1.2.1 (2026-06-06)"}
    certainty: confirmed
  - url: "https://docs.gastownhall.ai/glossary/"
    supports: alternative
    claim: "[2차 성격의 검색 요약 — 본문 미확인] 이 내용은 원문을 직접 읽지 않고 검색 요약으로만 얻었다. handoff 는 '맥락이 차면 일 상태를 새 세션으로 옮기는 세션 리프레시'이고, handoff 메일은 beads 로 저장돼 남는다. 커밋 · 스테이지 · beads 상태 · hook 은 세션을 넘어 남고 Claude 맥락만 리셋된다. 메일의 읽음 확인 여부와 git 원격 동기화의 세부(기계 간 메일이 git remote 로 가는지 · Dolt 로 가는지)는 확인하지 못했다. 이 문서 도메인은 다른 호스트로 리다이렉트돼 따라가지 않았다."
    touches: []
    decides: [OQ3, OQ4]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain
  # ── 지형 2차 ──
  - url: "https://amux.io/guides/ai-agent-orchestration-2026/"
    supports: both
    claim: "[2차 — 지형] 같은 모양의 도구가 많다: multiclaude(Go · tmux · worktree), cmux, dmux, Orchestra, workmux, vibe-kanban, cc-tmux-worktree-orchestration plugin. 공통 방식은 'tmux(또는 자체 PTY) 창마다 대화형 CLI + worktree 격리'이고, 갈리는 점은 UI(TUI · 칸반 · plugin) · agent 간 조정 유무 · 지원 CLI 수다. 개별 도구의 판 · 유지 상태는 검증하지 않았다."
    touches: []
    decides: [OQ3]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain
repo_claims:
  - id: RC1
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "## 늘 싣는 것 — 1. **자리.** 「기본은 `isolation: \"worktree\"` 로 띄운 agent 가 자기 worktree 에서 `git switch --ignore-other-worktrees <에픽 브랜치>` 로 그 브랜치에 서는 것」"
    line: 7
    claim: "지금 일꾼은 하니스 하위 agent(Agent 도구)다. 기본은 isolation:worktree 로 띄우고, 일꾼이 에픽 브랜치로 switch 한다. 외부 실행기 · 헤드리스 프로세스 · 팀원이 아니다."
    touches: []
    decides: [OQ3]
  - id: RC2
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "## 단계마다 새 agent — 「구현 agent 는 새로 보낸다 — 계획 agent 를 이어 쓰지 않는다(한 agent 가 리뷰~계획을 이으면 맥락이 백만 토큰 가까이 커진다)」 · 「같은 agent 를 이어 부른다(`SendMessage`)」"
    line: 37
    claim: "일꾼 맥락을 갱신하는 지금 방식은 «단계마다 새 하위 agent»이고, 이어 부를 때는 SendMessage 를 쓴다. 끝나 worktree 가 지워진 격리 agent 는 깨우면 지휘자의 worktree 에 다시 묶이므로 새로 보낸다(줄 38). 공식 문서는 v2.1.304 전에는 막 끝난 하위 agent 를 이어 부르면 최근 일을 잊을 수 있다고 적는다. 레포가 잰 판은 2.1.303 이다."
    touches: []
    decides: [OQ3]
  - id: RC3
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "## 마지막 보고 — 「하위의 마지막 메시지는 아래를 모두 싣는다 — 실행 방식이 작업 폴더를 지울 수 있어 경로만으로는 부족하다」"
    line: 43
    claim: "결과 보고는 파일이 아니라 하위 agent 의 마지막 메시지로 받는다(판정 전체 · AC 보고 · 커밋 목록). 사람 자리 원문의 옮김은 relay 폴더의 파일(relay-<번호>.md)에 남긴다(줄 32)."
    touches: []
    decides: [OQ3]
  - id: RC4
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "5. **임시 폴더.** 「격리 worktree 에서 일하는 하위는 이 폴더에 Write · Edit 도구로 쓸 수 없다 — 셸 명령 · 스크립트로 쓴다(2026-10-19 실측: 도구는 거절, 셸은 됨)」"
    line: 11
    claim: "격리된 하위 agent 는 공유 폴더에 쓸 때 도구 제약을 받는다(실측). 하위 agent 방식이 지닌 운영 비용 하나다."
    touches: []
    decides: [OQ3]
  - id: RC5
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### 4. 돌아오기 — 「기본값: 백그라운드 agent 가 끝나면 알림이 온다」"
    line: 49
    claim: "지휘자-일꾼 사이의 완료 신호는 하니스가 주는 백그라운드 agent 완료 알림이다. 진행은 실행 방식 원장(SDD 의 progress.md 파일)의 Ruling 줄을 맞추기마다 읽는다. 받음 · 진행 확인은 알림(메시지)과 원장 파일(파일)을 섞어 쓴다."
    touches: []
    decides: [OQ3]
  - id: RC6
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### 1. 맞추기 — 「완료 표시는 일이 끝났다는 뜻이 아니다(2026-10-19 실측)」"
    line: 17
    claim: "하니스 agent 목록의 completed 만으로는 멈춤을 단정할 수 없다는 실측이 있다(자기 백그라운드 일을 걸어 두고 턴을 끝낸 경우). 판단이 모호하면 SendMessage 로 한 줄 묻는다. 지금 방식에는 명시적인 받음 · 완료 확인 프로토콜이 없고 원천 대조로 메운다."
    touches: []
    decides: [OQ3]
  - id: RC7
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### /compact 시점 — 「압축은 사용자만 한다. 압축 뒤에는 걸음 1 부터 한다.」"
    line: 85
    claim: "지휘자 자신의 맥락 갱신은 사용자가 하는 /compact 다. 기록을 커밋하고 기계 상태를 저장한 뒤 '/compact' 와 '/spec-distill:epic-conductor <로드맵>' 두 줄을 준다. 지휘자 세션 교체(새 세션 띄우기)는 이 절차에 없다."
    touches: []
    decides: []
  - id: RC8
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "하위 agent 의 자리(2026-10-15 · 10-18 실측): 「agent 는 스스로 다른 worktree 로 옮겨 갈 수 없다(경로 지정 들어가기는 격리 agent 도 거절된다)」"
    line: 43
    claim: "하위 agent 의 자리 제약(세션 worktree 에 묶임 · 스스로 옮기지 못함 · 같은 브랜치를 두 worktree 가 쥐면 조용히 되돌림)을 실측해 그 위에 절차를 쌓았다. 다른 기계와의 소통 경로는 이 절차에 없다(GitHub PR · 원격 브랜치를 주인으로 맞추는 pr-refresh 뿐, 줄 13)."
    touches: []
    decides: [OQ3, OQ4]
  - id: RC9
    path: "plugins/spec-distill/dependencies.md"
    anchor: "| claude-code | 2.1.303 | 2026-10-22 | 기록 | 잰 판을 기록만 한다 |"
    line: 19
    claim: "레포가 잰 Claude Code 판은 2.1.303(2026-10-22)이고 강도는 '기록'(막지 않음)이다. upstream 최신은 v2.1.323(2026-11-12)이다. 2.1.303 보다 높은 판을 요구하는 문서 항목은 셋이다: 하위 agent 이어 부르기 망각 수정(2.1.304), split-pane 팀원의 --disallowedTools 전달(2.1.309), 대기 메시지 transcript 표시(2.1.309)."
    touches: []
    decides: [OQ3]
unanswered: "herdr 의 맥락 리프레시 기능 유무, Gas Town 메일의 읽음 확인과 기계 간 운반 세부(git remote 인지 Dolt 인지 — 문서 도메인이 다른 호스트로 리다이렉트돼 따라가지 않음), 서로 다른 계정 · 사람의 Claude Code 세션 사이 cross-session 메시지 가능 여부, 2차 지형 목록(multiclaude · cmux · dmux · vibe-kanban 등)의 개별 판 · 유지 상태는 확인하지 못함. 공식 문서가 'mod'(code.claude.com/docs/en/plugins/mods)를 언급하는 것은 봤지만 OQ6 은 이 주문 범위 밖이라 조사하지 않음."
```

**도구와 방식을 가른 요약**

| 방식 | 일꾼 | 글 운반 · 받음 확인 | 결과 보고 | 다른 기계 | 대표 도구 |
|---|---|---|---|---|---|
| 하위 agent | 같은 세션 안의 하위 agent | SendMessage(쓰기 확인만) | 메시지(완료 알림) | 없음 | Claude Code 내장. 지금 devbrew 의 방식 |
| 공식 팀원 | 따로 도는 Claude Code 인스턴스 | JSON 메일함 파일(쓰기 성공 = 보냄) | idle 알림에 최종 답 | 없음(로컬 ~/.claude) | agent teams(실험 기능) |
| 백그라운드 세션 | supervisor 아래의 독립 프로세스 | cross-session(소켓) | 사용자에게만, `--json` 폴링 | 이 기능 안에는 없음 | agent view(research preview) |
| 세션 사이 메시지 | 사용자가 띄운 아무 세션 | 같은 기계는 Unix 소켓, 다른 기계는 Anthropic 서버 + Remote Control. delivered/held/refused 처리, idle 알림 구독 | 메시지 | 됨(claude.ai 로그인, 같은 사용자) | Claude Code 내장 |
| 헤드리스 | 일회성 프로세스 | stdin/argv | stdout JSON(종료 코드 · 비용 · session_id) | 없음 | `claude -p` · Agent SDK |
| 터미널 주입 | 멀티플렉서 pane 의 대화형 CLI | 소켓으로 글 주입 + 화면 읽기(대기열 접수 확인만) | 화면 · 상태 휴리스틱 | SSH 로 UI 를 원격으로 비춤 | herdr |
| tmux/PTY + worktree 관리자 | 대화형 CLI | 없음(사람이 attach) | diff · 머지 | 없음 | claude-squad · ccmanager · workmux |
| 메일함 + 원장 | tmux 대화형 세션 | 메일(beads/git 기반) + nudge | 메일 · beads | DoltHub 연합(세부 미확인) | Gas Town |

Sources:
- [Agent teams](https://code.claude.com/docs/en/agent-teams)
- [Cross-session messaging](https://code.claude.com/docs/en/cross-session-messaging)
- [Run agents in parallel](https://code.claude.com/docs/en/agents)
- [Subagents](https://code.claude.com/docs/en/sub-agents)
- [Headless](https://code.claude.com/docs/en/headless)
- [Agent SDK overview](https://code.claude.com/docs/en/agent-sdk/overview)
- [Agent view](https://code.claude.com/docs/en/agent-view)
- [Remote Control](https://code.claude.com/docs/en/remote-control)
- [Claude Code releases](https://github.com/anthropics/claude-code/releases)
- [herdr](https://github.com/herdrdev/herdr) · [herdr socket API](https://herdr.dev/docs/socket-api/) · [herdr remote](https://herdr.dev/docs/persistence-remote/) · [linuxlinks (2차)](https://www.linuxlinks.com/herdr-terminal-based-agent-multiplexer/)
- [claude-squad](https://github.com/smtg-ai/claude-squad)
- [ccmanager](https://github.com/kbwo/ccmanager)
- [workmux](https://github.com/raine/workmux)
- [Gas Town](https://github.com/gastownhall/gastown) · [Gas Town glossary (검색 요약)](https://docs.gastownhall.ai/glossary/)
- [amux 지형 가이드 (2차)](https://amux.io/guides/ai-agent-orchestration-2026/)

레포 파일(절대경로):
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/references/conductor-dispatch.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/references/conducting.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/dependencies.md

### 조사 5 — open-researcher · R2 · 묶음 3

요약: Claude Code 에는 「mod」라는 공식 기능이 있다(code.claude.com 공식 문서). mod 는 플러그인 안에 넣어 배포한다. 띄울 수 있는 자리는 다섯이다: 대화 옆 pane, 입력칸 위 띠(band), 입력칸 아래 상태 한 줄(`$.ui.status`), toast, 대화 기록 안 줄. 지휘 세션과 하위 agent 의 요청 하나하나의 토큰을 `turn.step` · `turn.complete` 이벤트로 받을 수 있다(`e.agentId` 로 둘을 가른다). 반면 상태줄(statusLine)은 사용자 · 프로젝트 설정으로만 켜지고, 지휘 세션 자신의 맥락 창 · 비용만 준다. 하위 agent 사용량을 합산하는 공식 수단은 OpenTelemetry(`query_source` = `subagent`) · mod 이벤트 · `/usage` 귀속 표다. 레포(plugins/ · shared/)에는 상태줄 코드가 있다(spec-distill `control_plane.py statusline`). 다만 이 코드는 입력 JSON 에서 작업 폴더만 읽고 토큰 · 맥락 칸은 읽지 않는다. Claude 토큰을 재는 코드와 mod 코드는 없다.

```yaml
evidence:
  - url: "https://code.claude.com/docs/en/statusline"
    supports: both
    claim: "statusLine 명령이 stdin 으로 받는 JSON 의 토큰 · 맥락 · 비용 칸: context_window.{total_input_tokens,total_output_tokens,context_window_size,used_percentage,remaining_percentage,current_usage{input_tokens,output_tokens,cache_creation_input_tokens,cache_read_input_tokens}}, exceeds_200k_tokens, cost.{total_cost_usd,total_duration_ms,total_api_duration_ms,total_lines_added,total_lines_removed}, rate_limits.{five_hour,seven_day}.{used_percentage,resets_at}(구독자만), rate_limits.spend_limit.*(gateway), prompt_cache{warm,hit_ratio,misses,...}(v2.1.251+), session_id, transcript_path, agent.name(--agent 일 때). used_percentage 는 입력 토큰만(input+cache_creation+cache_read) 쓰고 마지막 API 응답 기준이다. current_usage 는 첫 호출 전과 /compact 직후 null 이다. 누구의 사용량인가: 지휘(주) 세션 자신이다. prompt_cache 는 문서가 «Claude Code doesn't count subagent requests» 라고 명시한다."
    touches: []
    decides: [OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 (레포 dependencies.md 기록)", latest: "2.1.323 (CHANGELOG 최상단)"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/statusline"
    supports: both
    claim: "상태줄 갱신 시점: 세션 시작 · 재개, 새 assistant 메시지, /compact 완료, 권한 모드 변경, vim 토글, command 변경, refreshInterval 타이머(최소 1초), rate-limit resets_at, prompt_cache expires_at. 300ms debounce 를 둔다. 여러 줄 · ANSI 색 · OSC8 링크를 낼 수 있다. 문서 인용: «The event-driven triggers can go quiet when the main session is idle, for example while a coordinator waits on background subagents» — 그래서 refreshInterval 을 권한다. 스크립트는 파일을 자유롭게 읽을 수 있다(예시가 /tmp 캐시 파일을 읽는다). 토큰을 쓰지 않는다. 설정 위치는 user 또는 project settings 의 statusLine 이다. 플러그인 manifest 의 component 목록에는 statusLine 이 없다."
    touches: []
    decides: [OQ5, OQ6]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/costs"
    supports: both
    claim: "/usage(별칭 /cost · /stats)의 Session 블록은 세션 비용과 모델별 input · output · cache read · cache write 를 보인다(/clear 에서 초기화). 'Prompt cache (main)' 줄은 «covers the main conversation only, not subagents» 다. 구독 플랜 화면은 최근 24시간 · 7일 사용량을 skill · subagent · plugin · MCP 서버별 비율로 귀속해 보인다. 이 귀속은 이 기계의 로컬 세션 기록으로 계산한다. 스피너 옆 토큰 수는 이번 턴의 출력이고 foreground subagent 출력을 포함한다. /context 는 마지막 응답 뒤 추가분 추정치를 더하므로 상태줄 값보다 높게 나올 수 있다(statusline 문서 Troubleshooting)."
    touches: []
    decides: [OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/commands"
    supports: both
    claim: "`/context [all]`: «Visualize current context usage as a colored grid» 에 최적화 제안이 붙는다. `/cost`: «Alias for `/usage`». `/stats`: /usage 별칭(Stats 탭). /usage 는 응답 중에도 즉시 실행된다. 셋 다 사람이 보는 대화형 화면이고 기계가 읽는 출력이 아니다(문서에 프로그램 출력 형식이 없음)."
    touches: []
    decides: [OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/monitoring-usage"
    supports: alternative
    claim: "OpenTelemetry metric: claude_code.token.usage(type=input|output|cacheRead|cacheCreation; 속성 model, query_source, agent.name, skill.name, plugin.name …), claude_code.cost.usage(USD). metric 의 query_source 는 'main' | 'subagent' | 'auxiliary' 로 지휘 세션과 하위 agent 를 가른다. agent.name 은 하위 agent 종류다(공식 · 내장 외에는 'custom'). event claude_code.api_request 는 input_tokens · output_tokens · cache_read_tokens · cache_creation_tokens · cost_usd 를 싣는다. event 에만 agent_id · parent_agent_id 가 있다(v2.1.310+). 켜는 법: CLAUDE_CODE_ENABLE_TELEMETRY=1 과 OTEL_METRICS_EXPORTER · OTEL_LOGS_EXPORTER(otlp|prometheus|console). 기본 metric 내보내기 간격은 60000ms 다. 외부 수집기가 필요하다."
    touches: []
    decides: [OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 — agent_id/parent_agent_id(2.1.310+) 이전 판", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/sessions"
    supports: both
    claim: "세션 기록은 ~/.claude/projects/<project>/<session-id>.jsonl 이다(<project> = 작업 경로의 비영숫자를 '-' 로 바꾼 것). 문서 인용: «The entry format is internal to Claude Code and changes between versions, so scripts that parse these files directly can break on any release» — 대신 /export 나 스크립트 인터페이스(claude -p --output-format json 은 usage · cost 를 포함, hooks · 상태줄의 transcript_path)를 권한다. message.usage 필드는 이 문서에 정의돼 있지 않다."
    touches: []
    decides: [OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/claude-directory"
    supports: both
    claim: "하위 agent 기록은 projects/<project>/<session>/subagents/ 아래에 «in the same format as the session transcript» 로 있다(sub-agents 문서: 파일명 agent-{agentId}.jsonl). 부모 기록이 만료될 때 함께 지워진다(cleanupPeriodDays 기본 30). stats-cache.json 은 /usage 가 보이는 누적 토큰 · 비용 집계다."
    touches: []
    decides: [OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/hooks"
    supports: both
    claim: "settings 훅 입력의 토큰 · 맥락 정보: 공통 필드(session_id, transcript_path, cwd, permission_mode, agent_id, agent_type …)에는 토큰 칸이 없다. SessionStart 는 source 가 resume | fork 일 때만 context_tokens · seconds_since_last_response · prompt_cache_likely_expired · estimated_cache_write_usd 를 준다(v2.1.251+). PreModelSwitch 는 context_tokens 를 준다(«input, cache read, cache creation, and output tokens of the last response in the main conversation»). PreCompact 는 trigger(manual|auto) · custom_instructions 만, PostCompact 는 trigger · compact_summary 만 주고 토큰 · 비율은 없다. SubagentStop 은 agent_id · agent_type · agent_transcript_path(…/<session>/subagents/agent-<id>.jsonl) · last_assistant_message 를 주고 토큰 칸은 없다. PostToolUse 의 Agent 도구 tool_response.totalTokens · usage 는 하위 agent 의 «final API request» 값이다(«This isn't a total across the whole run»). 합산에는 OTel query_source='subagent' 를 쓰라고 한다."
    touches: []
    decides: [OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/model-config"
    supports: both
    claim: "자동 압축 문턱: /autocompact <값>(모델별로 user settings modelSettings 에 저장), settings 키 autoCompactWindow(모든 모델), --autocompact 플래그(한 번 실행), env CLAUDE_CODE_AUTO_COMPACT_WINDOW(100000–1000000. command · flag · setting 보다 우선). 하위 agent 는 frontmatter autoCompactWindow(v2.1.296+)를 쓴다. 문서 인용: CLAUDE_CODE_AUTO_COMPACT_WINDOW 를 설정하면 «the status line's used_percentage measures against the model's full context window, so … that percentage doesn't indicate when compaction will run». 기본값: 1M 기본 모델은 약 967K 에서 압축한다."
    touches: []
    decides: [OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/env-vars"
    supports: both
    claim: "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE: auto-compact window 의 1–100% 지점에서 압축한다. 문턱을 낮추기만 하고 올릴 수 없다. «applies only in sessions that compact before the model's context limit». «Applies to both main conversations and subagents». 관련 변수로 CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS(기본 200000) · CLAUDE_CODE_MAX_CONTEXT_TOKENS 가 있다."
    touches: []
    decides: [OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md"
    supports: both
    claim: "최신 판은 2.1.323 이다. 2.1.323: «Changed CLAUDE_AUTOCOMPACT_PCT_OVERRIDE in Anthropic-hosted cloud sessions to stop applying». 2.1.323: «Removed the subagentStatusLine setting: subagent rows always use the default look». 2.1.319 에 «plugin-provided subagentStatusLine» 수정이 있어, 플러그인이 하위 agent 상태줄을 공급하던 길은 있었으나 지금은 제거됐다. 2.1.323: 모르는 모델 ID 에 가정하는 맥락 창을 200K→1M 으로 바꿨다."
    touches: []
    decides: [OQ5, OQ6]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/model-config"
    supports: both
    claim: "충돌 공시: model-config 문서는 «Claude Code doesn't recognize your session's model ID, so it … assumes 200K tokens» 라고 쓴다. 위 CHANGELOG 2.1.323 은 이 가정을 1M 으로 바꿨다고 쓴다. 둘 다 1차 자료이고 어느 쪽이 현행인지 확정하지 못했다(문서 갱신 지연 가능성). 모르는 모델 ID 를 쓰는 세션의 used_percentage 분모에 닿는다."
    touches: []
    decides: [OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/plugins/mods/overview"
    supports: alternative
    claim: "«A mod is a plugin that changes how Claude Code looks and behaves». mod 는 JavaScript · TypeScript 이벤트 핸들러로 이뤄지고 Claude Code 프로세스 안에서 돈다. 배포: «A mod installs as a plugin, from a marketplace». 구조는 플러그인에 hooks/hooks.json 의 \"modules\": [\"./register.js\"] 와 register(on) 를 export 하는 모듈을 둔다. 한 플러그인 안에 skill · agent · MCP 와 같이 둘 수 있다. 기본으로 켜져 있다. 터미널은 v2.1.287+, Desktop 앱 Code 탭은 v2.1.286+ 다. 끄기: 플러그인 비활성, --safe-mode, disableAllHooks:true(이때 상태줄도 꺼진다). 보안: sandbox 가 없다. 사용자 권한으로 파일 · 프로세스 · 네트워크에 닿는다. 공식 샘플 token-weather 는 «draws a forecast of your context window above the prompt» 다."
    touches: []
    decides: [OQ6]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 (mod 최소판 2.1.287 이상)", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/mods/overview"
    supports: alternative
    claim: "어디서 그려지는가(Where mods run 표): 터미널 claude(편집기 내장 터미널 · JetBrains 포함)는 훅도 돌고 그림도 보인다. Desktop Code 탭은 둘 다 되지만 terminal-only 요소는 빠진다(WSL 세션은 플러그인이 없어 안 된다). VS Code 확장은 2.1.299+ 에서 그린다. claude -p · Agent SDK 는 훅만 돌고 그리지 않는다. Remote Control 은 내 기계의 터미널에만 그려진다. cloud 세션은 훅만 돈다. 상태줄 · settings 훅 · skill · MCP 와 비교한 표: «Can it draw in the interface: Mod Yes / Settings hook No / Skill No / MCP No»."
    touches: []
    decides: [OQ6]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/mods/interface"
    supports: alternative
    claim: "그릴 자리(render site): Pane = «a sidebar beside the transcript in a wide fullscreen terminal, or a framed region above the prompt otherwise», $.ui.open({id}) 로 연다. 띠 AbovePrompt = «a strip directly above the prompt input. It's always there, and every mod shares it». Placed = 대화 기록 안 줄. 이 밖에 Spinner · ToolUse · AskUserQuestion 등 기존 UI 를 고쳐 그릴 수 있다. 다시 그리기: $.ui.invalidate('ui.render') 또는 $.clock.every 타이머 또는 반응형 $.state. 제한: 초당 10회, 터미널의 보이는 pane · 띠는 초당 30회. 화면 지도 그림에는 «a status line under the prompt» 와 «a toast at the top right» 도 있다."
    touches: []
    decides: [OQ6]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/mods/reference"
    supports: alternative
    claim: "render site 별 표면: Pane 은 Terminal · Desktop · VS Code, AbovePrompt(띠)는 Terminal · Desktop, Placed 는 Terminal 만, Backdrop 은 desktop · mobile 만(v2.1.319+). $.session.usage() 는 «{ startedAt, context, rateLimits, cost }: context has tokens, window, and percent» 를 돌려준다. 이벤트 session.measure 는 «After each turn, and when a plan limit's percent used changes» 때 난다. $.agent.list() 는 하위 agent · 팀원의 status(pending · running · waiting · idle · completed · failed · killed)를 준다. $.fs 메서드는 read · write · list · exists · stat · ancestors 뿐이고 watch 는 없다. write 는 원자적이지 않다. $.store 는 기계의 모든 세션이 함께 쓰는 키-값 저장소다."
    touches: []
    decides: [OQ5, OQ6]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/mods/reference"
    supports: alternative
    claim: "$.session.usage() 의 context · cost 가 하위 agent 사용량을 포함하는지는 문서에 나오지 않는다. 지휘 세션 자신의 값으로 보이지만 확인하지 못했다."
    touches: []
    decides: [OQ5]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/plugins/mods/events"
    supports: alternative
    claim: "turn.step: «`e.agentId` is set for a subagent's request». 결과 result.usage 는 input_tokens · output_tokens · cache_read_input_tokens · cache_creation_input_tokens · model 이다. «The hook runs for subagents' requests too, so check e.agentId when you want only the main conversation». turn.complete: e.usage 는 «the turn's token totals» 이고 하위 agent 턴이면 e.agentId 가 붙는다. mod 는 지휘 세션과 하위 agent 의 요청별 토큰을 실시간으로 받아 pane · 띠에 그릴 수 있다. settings 훅 이벤트는 classic.<Event> 로도 받는다. 다만 기본 가드(cc-plugin-sec-default)가 로드되면 사용자가 설치한 mod 의 classic.* 훅은 돌지 않는다."
    touches: []
    decides: [OQ5, OQ6]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/mods/api"
    supports: alternative
    claim: "백그라운드 표시(턴을 시작하지 않음): $.ui.status(text) 는 «One line under the prompt that stays until you change it. It starts with ⚠ and the mod's name». $.ui.toast 는 몇 초 뒤 사라진다. $.ui.log 는 대화 기록 안의 흐린 줄이고 Claude 는 읽지 않는다. $.ui.notify 는 터미널 알림이다. 파일을 읽어 갱신하는 길: session.start 훅에서 $.clock.every(ms, fn) 로 $.fs.read 나 $.process.run 을 돌리고 $.ui.status 나 $.ui.invalidate 로 고친다(문서 예시는 1분마다 gh pr checks 를 돌려 상태 줄을 바꾼다). 훅 모듈 자체에는 Node API · setTimeout · 파일 접근이 없고 $ API 로만 닿는다. VS Code 에서는 상태 줄 · toast 가 입력칸 위에 보인다(상태 줄은 200자 · 2줄에서 잘린다). $.session.send 로 다른 세션 · 하위 agent 에 글을 보낼 수 있다."
    touches: []
    decides: [OQ6]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/manifest-reference"
    supports: current
    claim: "플러그인 plugin.json 필드 · 표준 레이아웃(skills, commands, agents, hooks, mcpServers, lspServers, outputStyles, workflows, themes, monitors, bin, userConfig, types …)에 statusLine 항목이 없다. 플러그인이 메인 상태줄을 대신 켤 공식 manifest 경로는 문서에 없다. mod 를 쓰는 플러그인은 'types'(mod 의 $.state 선언 .d.ts)와 hooks/hooks.json 의 modules 를 쓴다. 플러그인 루트 settings.json 이 statusLine 을 받는지는 이 문서로 확인하지 못했다."
    touches: []
    decides: [OQ6]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
repo_claims:
  - id: RC1
    path: "plugins/spec-distill/README.md"
    anchor: "### 상태줄 — «플러그인이 대신 켜 줄 수 없습니다 — 메인 `statusLine` 은 사용자 · 프로젝트 설정만 정합니다. 직접 켭니다.»"
    line: 175
    claim: "레포에는 이미 상태줄 표면이 있다. 사용자가 ~/.claude/devbrew-statusline 스크립트와 user settings 의 statusLine 을 손으로 켠다. 내용은 로드맵 에픽 단계 요약 · 경고 수 · fetch 경과 · 진행 중 인터뷰 조사 수다. 다른 상태줄과는 stdin JSON 을 두 명령에 나눠 이어 붙이는 방법을 안내한다. 토큰 · 맥락 칸은 보이지 않는다."
    touches: []
    decides: [OQ6]
  - id: RC2
    path: "plugins/spec-distill/scripts/control_plane.py"
    anchor: "def stdin_dir — «상태줄 표준 입력 JSON 의 workspace.current_dir → cwd»"
    line: 1144
    claim: "상태줄 구현(cmd_statusline, line 1193)은 stdin JSON 에서 workspace.current_dir · cwd 만 꺼내 작업 폴더를 정한다. context_window · cost · rate_limits · transcript_path 칸은 읽지 않는다. 시간 예산은 STATUSLINE_BUDGET = 3.0 초(line 443)이고 kill switch 는 DEVBREW_SKIP_HOOKS=spec-distill:statusline(line 1139)이다."
    touches: []
    decides: [OQ5, OQ6]
  - id: RC3
    path: "plugins/spec-distill/dependencies.md"
    anchor: "| claude-code | 2.1.303 | 2026-10-22 | 기록 | 잰 판을 기록만 한다 |"
    line: 19
    claim: "레포가 기록한 Claude Code 판은 2.1.303 이다(plugin-audit · project-init · quality-gates 의 dependencies.md 도 같다). mod 최소판 2.1.287 · 상태줄 prompt_cache 2.1.251 · 하위 agent autoCompactWindow 2.1.296 이상이다. OTel event 의 agent_id(2.1.310) · $.ui.place(2.1.314) · $.theme(2.1.319)보다는 낮다."
    touches: []
    decides: [OQ5, OQ6]
  - id: RC4
    path: "plugins/quality-gates/tests/spike/fixtures/codex_jsonl_sample.json"
    anchor: "{\"type\":\"turn.completed\",\"usage\":{\"input_tokens\":14922,...}}"
    line: 4
    claim: "plugins/ · shared/ 아래에서 토큰 사용량 필드(input_tokens · cache_read_input_tokens · message.usage · context_window · AUTOCOMPACT · OTEL_)가 나오는 곳은 codex JSONL 테스트 fixture 하나뿐이다. Claude Code 세션 · 하위 agent 의 토큰이나 맥락을 재는 코드는 없다. epic-conductor skill 에도 compact · 맥락 · 사용량 언급이 없다. mod 코드(hooks.json \"modules\", register(on), $.ui.*)도 없다."
    touches: []
    decides: [OQ5, OQ6]
unanswered: "확인하지 못한 것 넷: $.session.usage() 가 하위 agent 를 포함하는지, 플러그인 루트 settings.json 으로 statusLine 을 공급할 수 있는지, 세션 jsonl 의 message.usage 정확한 구조(공식 문서는 «internal» 이라며 정의하지 않음), 모르는 모델 ID 의 가정 맥락 창(문서 200K 와 CHANGELOG 2.1.323 의 1M 이 충돌)."
```

**알아 둘 점**
- 「지휘 세션 자신 · 하위 agent」 구분:
  - 상태줄 · `/usage` Session 블록 · `prompt_cache` · 훅의 `context_tokens`: 지휘 세션만 준다.
  - 하위 agent 를 함께 주거나 가를 수 있는 공식 수단: OTel(`query_source`), mod `turn.step` · `turn.complete`(`e.agentId`), `/usage` 귀속 표(구독, 로컬 기록 근거, 24시간 · 7일 단위).
  - `SubagentStop` 훅과 하위 agent jsonl: 경로만 준다. 형식은 내부 형식이라고 공시돼 있다.
- 상태줄과 mod 의 차이:
  - 상태줄: 셸 명령이고 사용자 · 프로젝트 설정에서만 켠다. 이벤트가 있을 때와 `refreshInterval` 로 갱신된다. 지휘가 하위 agent 를 기다리며 쉴 때는 이벤트가 멈춘다고 문서가 명시한다.
  - mod: 플러그인으로 배포한다. 같은 프로세스 안의 JS 이고, pane · 띠 · 상태 한 줄 · toast 를 그리며 타이머와 `$.fs.read` 로 파일을 읽어 갱신할 수 있다. 다만 sandbox 가 없고, 사용자 권한 전체에 닿는다.
- 터미널 CLI 와 Desktop 앱 Code 탭 둘 다 mod 를 그린다. 띠(AbovePrompt)는 VS Code 에서 빠지고, Placed 는 터미널에서만 된다.

## R2

### 지금 이해
세 조사(묶음 3 — 바깥 지휘 도구 지형 · 토큰 측정과 화면 표면 · premortem)를 함께 띄웠다 — 서로 기대지 않아서. 일꾼 후보 중 agent 팀은 리드 고정 · 세션당 팀 하나 · 재개 불가 · 기계 간 불가라 지휘 세션 리프레시와 서로 깨뜨린다. 다른 기계 세션 메시지는 Remote Control + claude.ai 로그인이 필요하고 평문 · 보류 만료가 있다. 「모드」는 Claude Code mod(2026-10 출시, 플러그인으로 배포, pane · 띠 · 상태 한 줄)로 보이며, mod 의 turn.step 이벤트가 지휘 세션과 하위 agent 의 요청별 토큰을 갈라 준다. 세션 기록 jsonl 은 공식 문서가 내부 형식이라 하고 이중 계수 버그 보고가 있다. premortem: 모든 단계 팀화는 토큰을 늘리는 쪽(다중 agent 약 15배, 2차 확인), 리프레시는 캐시 재작성으로 비용을 늘릴 수 있음, 역할 폴더 CLAUDE.md 는 일꾼에게 자동으로 안 읽힘, 일꾼이 쓴 파일을 판정 근거로 믿는 문제, 파일 원칙(P14)이 이미 있어 「같은 뿌리」 진단은 «무엇을 · 누가 · 언제 읽나»일 수 있음.
- 확인 RC15 — 확인 — plugins/spec-distill/references/conducting.md#5. 머지 전 확인 — RC5 와 같은 자리(59행)
- 확인 RC16 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#마지막 보고 — RC1 과 같은 자리(43행)
- 확인 RC17 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#단계마다 새 agent — RC12 와 같은 자리(37행)
- 확인 RC18 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#38행 — SendMessage 로 같은 agent 를 이어 부름
- 확인 RC19 — 확인 — plugins/spec-distill/references/conducting.md#/compact 시점 — RC3 과 같은 자리(85행)
- 확인 RC20 — 확인 — docs/philosophy/devbrew-harness-philosophy.md#P14 — State Survives Compaction(90행) 실재
- 확인 RC21 — 확인 — docs/philosophy/devbrew-harness-philosophy.md#P8 — RC2 와 같은 자리(84행)
- 확인 RC22 — 확인 — docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.audit.md#132행 — 98.5% · 99.0% 원문 일치
- 확인 RC23 — 확인 — CLAUDE.md#Trivia ceremony — 주장과 일치
- 확인 RC24 — 확인 — CLAUDE.md#모든 훅에 kill switch — 주장과 일치
- 확인 RC25 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#1. 자리 — 7행 기본 isolation worktree
- 확인 RC26 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#단계마다 새 agent · SendMessage — 37–38행
- 확인 RC27 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#마지막 보고 — 43행
- 확인 RC28 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#5. 임시 폴더 — 11행 「도구는 거절, 셸은 됨」
- 확인 RC29 — 확인 — plugins/spec-distill/references/conducting.md#4. 돌아오기 — 49행 완료 알림
- 확인 RC30 — 확인 — plugins/spec-distill/references/conducting.md#1. 맞추기 — 17행 완료 표시 실측
- 확인 RC31 — 확인 — plugins/spec-distill/references/conducting.md#43행 — 하위 agent 자리 실측
- 확인 RC32 — 확인 — plugins/spec-distill/dependencies.md#claude-code — 19행 2.1.303 기록
- 확인 RC33 — 확인 — plugins/spec-distill/README.md#상태줄 — 175행 원문 일치
- 확인 RC34 — 확인 — plugins/spec-distill/scripts/control_plane.py#stdin_dir · cmd_statusline — 1144 · 1193행, context_window · cost · transcript_path 를 읽지 않음(grep 0건), kill switch 는 1140행
- 확인 RC35 — 확인 — plugins/spec-distill/dependencies.md#claude-code — RC32 와 같은 자리
- 확인 RC36 — 확인 — plugins · shared#토큰 필드 — cache_read_input_tokens · context_window · AUTOCOMPACT · OTEL_ grep 0건
- 웹: 조사 4 · 5 의 agent teams · cross-session 제약, 조사 3 · 5 의 mod 실재 · 무 sandbox 는 서로 독립한 두 조사가 같은 1차 문서로 일치했으나 본체가 1차 자료를 다시 열지는 않았다(확인 못 함). Anthropic 15배 수치 · ccusage 미러 · 블로그는 2차 · 불확실.
조사 호출 4/60 · 이 라운드 본체 직접 1
줄인 사실 6개

### 다음 결정
OQ3: 일꾼 기본 실행 방식 · 추천: 하위 agent 기본 + 단계표에 실행기 칸 · 트레이드오프: 하위 agent=지금 방식 · Skill 됨 · 기계 간 안 됨 / 백그라운드 세션=지휘 리프레시에 독립 · research preview / 헤드리스=Skill 거부 · rc 0 조용한 실패 / agent 팀=리드 고정으로 리프레시와 충돌
OQ4: 다른 기계 지휘자 간 운반 · 추천: git 원격 파일이 정본 + 세션 메시지는 초인종 · 트레이드오프: 파일만=느린 알림 / 메시지만=평문 · 만료 · claude.ai 로그인 필요
OQ5 · OQ6: 현황 · 토큰 표면 · 추천: mod 하나로 · 트레이드오프: mod=요청별 토큰 · 하위 agent 구분 · 무 sandbox JS / 상태줄 확장=지휘 세션만 · 사용자가 직접 켬
blind_spot 처분: premortem 항목 중 설계 제약으로 받을 것

### 질문
(b) 일꾼 실행 · (b) 지휘자 간 운반 · (b)+(a) 현황 · 토큰 표면 · (b) premortem 처분

### 답
→ S4 (OQ3) · S5 (OQ4 — 열린 채, 한 서버 한 세션일 때 알림 경로를 더 조사) · S6 (OQ5 · OQ6: mod 하나로 + 「낡은 규칙과 철학으로 지레짐작 제약은 안 된다」 steer) · S7 (premortem 처분)

### 조사 7 — steelman-builder · R3 · 묶음 4 (ST1)

```yaml
case_for_alternative:
  statement: "뿌리는 «파일이 없음»이 아니다. «누가 · 언제 · 무엇을 · 얼마나 읽는가»(읽기 설계)와 «행동에 묻은 결정이 그 자리에서 글로 옮겨지지 않음»(결정 외재화)이 뿌리다. 그러니 첫 단추는 역할 · 단계별 읽기 예산과 결정 기록의 쓰기 시점이고, 파일 규약은 그 둘을 담는 그릇이다."
  strongest: "goal 의 첫 불만은 «토큰 너무 많이 들음»이다. 이 레포에서 확인된, 매번 반복되는 고정비는 대화가 아니라 «읽는 파일»에서 나온다. 지휘자는 부를 때마다 75KB 절차서 전체를 Read 하고(RC1), 그 안에는 이 skill 안에서는 따르지 않는다고 명시한 「손으로 따르는 절차」 절까지 들어 있다. 레포 철학(P5)은 이미 «최소 인덱스만 preload, 나머지는 just-in-time» 이라고 적었는데도 그렇다(RC2). 그러니 파일이 있느냐가 아니라 읽기가 설계되었느냐가 갈린다. 공식 문서도 같은 쪽이다. CLAUDE.md 는 200줄을 넘으면 «consume more context and reduce adherence» 이고, import 로 나눠도 비용이 줄지 않는다. Chroma 는 입력이 길수록, 관련 없는 단락 하나만 끼어도 성능이 떨어진다고 쟀다. 팀 공통 CLAUDE.md · 역할 CLAUDE.md · INTENT · STATUS · HANDBOOK · inbox 를 일꾼이 시작할 때마다 읽게 하면 dispatch 마다 드는 고정비와 주의 분산이 함께 오른다. 공유 누락 쪽도 Cognition 이 짚는다. 병렬 하위끼리의 충돌은 «conflicting assumptions not prescribed upfront», 곧 아무도 글로 쓰지 않은 결정에서 나온다. 파일 칸이 있다고 그 결정이 적히지는 않는다. MAST 는 정보를 갖고도 무시하는 실패(FM-2.5)와 말한 추론과 다른 행동(FM-2.6)을 따로 분류했다. 이 둘은 받음 확인 · 되읽기로 막히지 않는다."
case_for_current:
  strongest: "goal 이 직접 요구하는 «적절한 순간의 리프레시»(지휘 세션과 구현 담당자 모두)는 상태가 대화 밖에 살아 있어야 성립한다. 파일 없이 리프레시하면 맥락을 통째로 잃는다. Anthropic 의 장기 실행 하니스는 «each session begins with no memory» 를 전제로 progress 파일 · feature list · git log 를 세션 시작 때 읽혀 한 세션에 기능 하나씩 끊어 가게 했다. Anthropic 다중 agent 연구 시스템은 하위의 결과를 파일시스템에 두고 가벼운 참조만 넘겨 «game of telephone» 을 줄였다. 지금 레포는 그 반대다. 하위가 판정 전체와 AC 보고 전체를 마지막 메시지에 싣게 되어 있어(RC3) 긴 보고가 고스란히 지휘자 맥락에 쌓인다. goal 의 «보고 · progress · 지휘 문서» 세 항목이 바로 이 자리다. 한 agent 가 리뷰에서 계획까지 이으면 맥락이 백만 토큰 가까이 커진다는 레포 실측(RC4)도 «대화에 쌓임»이 실제 비용원임을 보인다. 읽기 설계(just-in-time)도 파일로 쪼개 둔 것만 골라 읽을 수 있다. 그러니 파일 규약은 대안의 전제 조건이고, 먼저 세우는 순서가 맞다."
premise_refutation:
  hits: [P1, P2, P4]
  why: "P1 — RC1(plugins/spec-distill/skills/epic-conductor/SKILL.md 「### 5. 지휘 순환」 Read 두 줄)이 문제다. 지휘자는 부를 때마다 conducting.md 전체(75,138 바이트, Phase 0 측정 약 3.5만 토큰)를 읽고, 그 안의 「## 손으로 따르는 절차」는 같은 SKILL 169행이 «이 skill 안에서는 따르지 않는다»고 한 절이다. https://www.anthropic.com/engineering/multi-agent-research-system 은 다중 agent 가 채팅의 약 15배 토큰을 쓰고 토큰 사용량이 성능 분산의 80%를 설명한다고 적는다. 이 둘은 토큰이 «무엇을 몇 agent 가 읽는가»에서 크게 나온다는 근거다. 그래서 «토큰 낭비의 주된 원인은 맥락이 대화 · 메시지에 쌓이는 것»의 «주된»과 충돌한다. 레포에는 토큰을 세는 코드가 없어 «주된»이라는 말 자체가 재지 않은 주장이다. 대화 누적도 원인 하나인 것은 RC4 가 지지하므로, 반증되는 것은 «주된»과 그 원인 배정이다. P2 — https://cognition.com/blog/dont-build-multi-agents 가 문제다. 병렬 하위의 충돌을 «actions … based on conflicting assumptions not prescribed upfront»로 설명하고, 과제 원문을 복사해 넘기는 것으로는 부족하다고 한다. https://arxiv.org/html/2503.13657v2 FM-2.4(정보 보유자가 나누지 않음)도 같은 쪽이다. 이 둘은 누락의 원인이 «쓰이지 않은 결정 · 나누지 않기로 한 판단»에 있다고 본다. 그러니 «공유 누락의 주된 원인은 맥락이 파일에 남지 않는 것»과 충돌한다. 저장 매체가 없어서가 아니라 글로 쓰이지 않아서다. 레포의 relay 경로는 이미 원문 · 질문 · 답을 파일로 남기고 대조까지 한다(RC5). 그러니 적어도 그 경로에서는 «파일 없음»이 원인일 수 없다. P4 — https://arxiv.org/html/2503.13657v2 가 문제다. FM-2.5(다른 agent 의 입력을 받고도 무시)와 FM-2.6(말한 추론과 다른 행동)은 받는 쪽이 읽고 되말할 수 있어도 생기는 실패다. 5.2절은 전술적 수정만으로는 «not all failure modes are eradicated»이고, 높은 신뢰성에는 «more fundamental changes to agent organization, communication protocols»가 필요하다고 결론낸다. https://code.claude.com/docs/en/memory 도 지시 파일을 «context, not enforced configuration»이라고 적는다. 그러니 «받음 확인 · 되읽기 약속이 있으면 … 실제로 전달된다»와 충돌한다. 되읽기는 읽었다는 증거일 뿐 적용했다는 증거가 아니다."
premise_list_challenge: "빠진 전제가 넷이고 기대고 있는 전제가 둘이다. (1) 읽기 설계 전제가 없다. 누가 · 언제 · 무엇을 · 얼마나 읽는가가 목록 어디에도 없다. 그런데 매번 읽는 지휘 절차서(RC1), 자동으로 실리지 않는 역할 CLAUDE.md(OQ7), 일꾼마다 시작할 때 읽는 묶음이 토큰과 전달을 함께 정한다. 120줄 상한도 HANDBOOK 목차 하나에만 걸려 있고, 일꾼이 시작할 때 읽는 묶음 전체에는 걸려 있지 않다. (2) 측정 전제가 없다. P1 · P2 의 «주된»은 기준선 없이 정해졌다. S6 으로 측정 수단(mod)은 골랐지만, 규약보다 측정이 먼저 또는 함께 와야 한다는 전제가 목록에 없다. (3) 결정 기록의 쓰기 시점과 주체가 없다. INTENT.md 의 «결정 기록» 칸은 결정한 행동 직후 그 행동자가 써야 Cognition 이 말한 암묵적 결정을 잡는다. 과제 시작 때 한 번 만드는 파일로는 못 잡는다. (4) 캐시 경제가 없다. 새 일꾼 · 리프레시 · 시작 때 파일을 많이 읽을수록 캐시를 다시 쓴다(Manus: KV-cache 적중률이 가장 중요한 지표). S7 「리프레시는 비용 아닌 품질 신호」와 같은 방향이니 전제로 올려야 한다. 기대는 전제 — P3 는 P1 ∧ P2 의 결론이라 위 hit 를 그대로 물려받는다. 특히 «토큰이 함께 준다»는 반쪽은 읽기 설계 없이는 성립하지 않고, 오히려 늘 수 있다. P5 는 결과 파일이 지워지지 않는 자리를 전제한다. 지금 규칙은 바로 그 이유(실행 방식이 작업 폴더를 지울 수 있다) 때문에 반대로 되어 있다(RC3). 그 자리를 정하지 않으면 P5 는 성립하지 않는다. 범위 메모 — 대안은 «모든 단계가 팀을 쓴다 · 작은 일도 지휘자»(seed 확인)로 닫힌 «다중 agent 를 덜 쓰기»를 내지 않는다. 레포의 P14 · P5 는 S6 에 따라 제약으로 쓰지 않았다. «파일 원칙이 이미 있는데도 문제가 남는다»는 지형 사실로만 썼다. 같은 입력으로 다시 불린 것은 아니다(state 에 앞선 steelman 산출물이 없다)."
recommendation: refined
refined_takes: "파일 규약 자체는 취한다. 결과 파일로만 하는 보고(지워지지 않는 자리를 함께 정하는 조건), INTENT.md(목표 · 지시 원문 · 하지 않을 것 · 결정 기록), STATUS.md, 두 번 나온 지적의 HANDBOOK 승격, «메시지는 짧게 · 자세한 것은 경로로». 리프레시(goal 항목)의 전제 조건이고, 보고가 지휘자 맥락에 쌓이는 지금의 RC3 경로를 끊는다."
refined_drops: "버리는 것은 넷이다. (a) «파일 없음이 단일 뿌리»라는 틀과 «파일 규약을 먼저 세우면 토큰이 준다»는 기대. 읽기 설계를 같은 첫 단추로 올린다 — 역할 · 단계별 시작 묶음에 예산 상한을 두고, 지휘 절차서는 걸음별로 쪼개 그 걸음에서만 읽고, 쓰지 않는 절(「손으로 따르는 절차」)은 읽지 않는다. (b) 받음 확인 · 되읽기를 전달의 보증으로 쓰는 것. 산출물 · 행동 대조로 바꾼다 — S7 「일꾼 파일은 대조해 믿기」와 같은 방향이다. (c) «일꾼 시작 때 팀 파일 전부 읽기»라는 암묵적 기본값. (d) 결정 기록을 과제 시작 때 한 번 쓰는 칸으로 두는 것. 결정한 행동 직후 그 행동자가 쓰게 하고, 커밋 · 단계 경계에서 확인한다."
evidence:
  - url: "https://www.anthropic.com/engineering/multi-agent-research-system"
    supports: alternative
    claim: "agent 는 채팅보다 약 4배, 다중 agent 는 약 15배 토큰을 쓰고, 토큰 사용량 하나가 성능 분산의 80%를 설명한다. 토큰은 구조(agent 수 · 각자가 읽는 양)에서 크게 나온다."
    touches: [P1]
    decides: []
  - url: "https://www.anthropic.com/engineering/multi-agent-research-system"
    supports: current
    claim: "「Subagent output to a filesystem to minimize the 'game of telephone'」 — 하위는 결과를 외부 저장소에 두고 가벼운 참조만 조정자에게 넘긴다. 결과 파일 보고와 «자세한 것은 경로로»를 지지한다."
    touches: [P3, P5]
    decides: []
  - url: "https://www.anthropic.com/engineering/multi-agent-research-system"
    supports: current
    claim: "자세한 과제 설명이 없으면 agent 들이 일을 겹치거나 빈틈을 남기거나 필요한 정보를 못 찾는다. 과제마다 목표 · 지시 원문 · 하지 않을 것을 적는 INTENT.md 를 지지한다."
    touches: [P2, P3]
    decides: []
  - url: "https://www.anthropic.com/engineering/multi-agent-research-system"
    supports: current
    claim: "맥락이 200,000 토큰을 넘으면 잘리므로 리드 agent 는 계획을 Memory 에 저장해 두고, 한도에 닿으면 저장된 계획을 다시 꺼낸다. 맥락 비우기 전에 파일로 남기기를 지지한다."
    touches: [P5]
    decides: [OQ8]
  - url: "https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents"
    supports: alternative
    claim: "좋은 맥락 설계는 «the smallest possible set of high-signal tokens»를 찾는 일이다. 모든 데이터를 미리 싣지 않고, 파일 경로 같은 참조만 쥐고 필요할 때 읽는 just-in-time 방식을 권한다. 읽기 설계가 핵심 축이라는 근거다."
    touches: [P3]
    decides: [OQ7]
  - url: "https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents"
    supports: current
    claim: "구조화된 노트(NOTES.md)를 맥락 밖에 두어 «critical context and dependencies that would otherwise be lost across dozens of tool calls»를 지킨다. 맥락을 파일로 남기는 규약을 지지한다."
    touches: [P2, P3]
    decides: []
  - url: "https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents"
    supports: both
    claim: "하위 agent 는 깨끗한 맥락에서 탐색하고 «often 1,000-2,000 tokens»의 압축 요약을 돌려준다. 보고를 짧게 하라는 쪽(P5)과, 짧은 요약이 넘어가는 길이 메시지라는 점을 함께 보인다."
    touches: [P5]
    decides: []
  - url: "https://cognition.com/blog/dont-build-multi-agents"
    supports: alternative
    claim: "원칙 2 «Actions carry implicit decisions, and conflicting decisions carry bad results». 하위 둘의 행동은 «conflicting assumptions not prescribed upfront»에서 나왔다. 공유 누락은 쓰이지 않은 결정에서 생긴다."
    touches: [P2]
    decides: []
  - url: "https://cognition.com/blog/dont-build-multi-agents"
    supports: both
    claim: "과제 원문을 복사해 넘기는 것은 충분하지 않다. 긴 과제에는 행동 · 대화 이력을 «key details, events, and decisions»로 압축하는 별도 모델을 제안하지만 «hard to get right»이고 결국 한계에 닿는다. 결정 기록 칸(current)을 지지하는 동시에, 그 칸을 언제 누가 채우는지가 어렵다는 점(alternative)을 보인다."
    touches: [P2, P3]
    decides: [OQ8]
  - url: "https://arxiv.org/html/2503.13657v2"
    supports: alternative
    claim: "MAST 의 inter-agent misalignment 범주에는 FM-2.4 정보 보유자가 나누지 않음, FM-2.5 다른 agent 의 입력을 무시하거나 가볍게 봄, FM-2.6 말한 추론과 실제 행동의 불일치가 있다. FM-2.5 · 2.6 은 받는 쪽이 읽었어도 생긴다."
    touches: [P2, P4]
    decides: []
  - url: "https://arxiv.org/html/2503.13657v2"
    supports: both
    claim: "5.2절 개입 사례 — 프롬프트 개선 · 구조 변경 같은 전술적 수정 뒤에도 «not all failure modes are eradicated»였다. «Achieving high reliability likely requires more fundamental changes to agent organization, communication protocols»라고 결론낸다. 통신 계약은 필요하지만 약속 하나로는 부족하다."
    touches: [P4]
    decides: []
  - url: "https://www.trychroma.com/research/context-rot"
    supports: alternative
    claim: "«model performance consistently degrades with increasing input length». 관련 없는 단락 하나만 끼어도(«Even a single distractor») 성능이 떨어진다. 일꾼이 시작할 때 읽는 묶음의 크기와 관련성이 품질을 정한다."
    touches: [P3]
    decides: [OQ7, OQ8]
  - url: "https://code.claude.com/docs/en/memory"
    supports: alternative
    claim: "CLAUDE.md 와 자동 메모리는 «context, not enforced configuration»이다. CLAUDE.md 는 200줄 아래가 목표이고 더 길면 «consume more context and reduce adherence»다. @import 는 맥락 비용을 줄이지 않는다. 경로 지정 규칙(paths:)과 하위 폴더 CLAUDE.md 는 맞는 파일을 다룰 때만 on demand 로 실린다. 역할 문서를 일꾼에게 닿게 하는 길과 읽는 양의 상한을 함께 정한다."
    touches: [P3, P4]
    decides: [OQ7]
  - url: "https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus"
    supports: both
    claim: "KV-cache 적중률이 «the single most important metric»이고 입력 대 출력은 약 100:1 이다(비용은 읽기 쪽에서 나온다 — alternative). 동시에 파일시스템을 «restorable» 압축의 외부 기억으로 쓰고, todo.md 를 다시 써서 목표를 맥락 끝에 붙잡아 둔다(current)."
    touches: [P1, P3]
    decides: [OQ8]
  - url: "https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents"
    supports: current
    claim: "«each session begins with no memory of what came before» 를 전제로, 초기화 agent 가 progress 파일 · feature list(JSON) · init.sh 를 만든다. 새 세션은 git log · progress 파일 · feature list 를 읽고 한 세션에 기능 하나만 한다. 파일 규약이 세션 리프레시를 가능하게 하고, 과제 단위를 세션 경계로 쓰는 선례다."
    touches: [P2, P3]
    decides: [OQ8]
  - url: "https://code.claude.com/docs/en/cross-session-messaging"
    supports: both
    claim: "세션끼리 보내는 메시지는 «plain text only»이고 «never the sender's conversation history or files»다. @ 로 파일을 적어도 아무것도 붙지 않는다. 다른 기계로는 Remote Control 연결을 거쳐 Anthropic 서버로 가고, offline 이면 다시 연결된 뒤에 닿는다. 받는 쪽에는 보낸 세션 이름이 붙고, 그 메시지로 승인 · 설정 변경을 할 수 없다. 메시지가 파일을 나르지 못하므로 자세한 것은 받는 기계에서 열 수 있는 자리(예: git 원격)에 있어야 한다."
    touches: [P5]
    decides: [OQ4]
repo_claims:
  - id: RC1
    path: "plugins/spec-distill/skills/epic-conductor/SKILL.md"
    anchor: "### 5. 지휘 순환 — 「Read ${CLAUDE_PLUGIN_ROOT}/references/conducting.md」 · 「`conducting.md` 의 손으로 따르는 절차는 지휘자를 부르지 않고 진행할 때의 것이다 — 이 skill 안에서는 따르지 않는다」"
    line: 163
    claim: "지휘자는 부를 때마다 conducting.md 전체(75,138 바이트 — R1 확인 값)와 conductor-dispatch.md 를 Read 한다. 그 안의 「## 손으로 따르는 절차」(conducting.md 90행~)는 같은 SKILL 169행이 이 skill 안에서는 따르지 않는다고 밝힌 절인데도 매번 읽힌다. 반복 고정비는 파일이 없어서가 아니라 읽기가 설계되지 않아서 생긴다."
    touches: [P1, P3]
    decides: []
  - id: RC2
    path: "docs/philosophy/devbrew-harness-philosophy.md"
    anchor: "### P5 — Filesystem as Memory — 「최소 인덱스만 preload하고 나머지는 Glob/Read/Grep으로 just-in-time 로드한다」 · ### P14 — 「턴 종료 전 load-bearing 사실은 파일로 기록한다」"
    line: 94
    claim: "레포는 이미 «사실은 파일로»(P14, 91행)와 «just-in-time 로드»(P5, 94행)를 정본으로 둔다. 그런데도 RC1 처럼 절차서를 통째로 읽고 seed 의 공유 누락이 남아 있다. «파일 원칙의 부재»가 아니라 읽기 · 쓰기 실행의 틈이 문제라는 지형 사실이다. S6 에 따라 제약으로 쓰지 않고 지형으로만 쓴다."
    touches: [P1, P2]
    decides: []
  - id: RC3
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "## 마지막 보고 — 「하위의 마지막 메시지는 아래를 모두 싣는다 — 실행 방식이 작업 폴더를 지울 수 있어 경로만으로는 부족하다」"
    line: 43
    claim: "지금 하위는 판정 전체와 AC 보고 전체를 마지막 메시지에 싣는다. 보고는 파일이 아니라 지휘자 대화에 쌓인다(current 를 지지). 같은 줄이 그 이유로 «작업 폴더가 지워질 수 있다»를 든다. 결과 파일 보고(P5)는 지워지지 않는 자리를 함께 정해야 성립한다."
    touches: [P1, P5]
    decides: []
  - id: RC4
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "## 단계마다 새 agent — 「한 agent 가 리뷰~계획을 이으면 맥락이 백만 토큰 가까이 커진다」"
    line: 37
    claim: "대화 누적은 레포가 실제로 겪은 비용원이다. 그래서 지금도 단계 경계마다 새 agent 를 보내 맥락을 끊는다. P1 의 «대화에 쌓임»이 원인 하나라는 것은 지지하고, 단계 경계가 이미 리프레시 단위로 쓰이고 있음을 보인다."
    touches: [P1]
    decides: [OQ8]
  - id: RC5
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "## 사람 자리 — 「옮길 때마다 받은 원문 · 실제로 띄운 질문 · 사용자 답 · 돌려보낸 글을 … 폴더의 파일(`relay-<번호>.md`)에 남기고, 에픽이 끝나면 쓰기 권한 없는 agent 가 … 대조한다」"
    line: 32
    claim: "옮긴 질문의 경로에는 이미 «파일로 남기기 + 쓰기 권한 없는 agent 의 대조»가 있다. 적어도 이 경로에서 공유 누락의 원인은 «파일에 안 남음»이 아니다. 받음 확인 · 되읽기보다 산출물 대조가 레포가 이미 쓰는 전달 검증 방식이다."
    touches: [P2, P4]
    decides: []
  - id: RC6
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### /compact 시점 — 「승인 뒤 계획 agent 를 보낸 직후처럼 끊기 좋은 자리에서 맥락이 무거우면, 기록(설계문서 절)을 커밋하고 기계 상태를 저장한 뒤 … 압축은 사용자만 한다」"
    line: 85
    claim: "지금 지휘 세션의 리프레시 문턱은 «끊기 좋은 자리(과제 경계) ∧ 맥락이 무거움»의 조합이다. 실행은 먼저 파일에 기록한 뒤 사용자가 한다. 리프레시 문턱 결정의 출발점이고, 리프레시 전에 파일로 남긴다는 순서(current)를 이미 담고 있다."
    touches: [P5]
    decides: [OQ8]
```

참고 경로(모두 절대경로):
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/skills/epic-conductor/SKILL.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/references/conducting.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/references/conductor-dispatch.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/docs/philosophy/devbrew-harness-philosophy.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.md

확인하지 못한 것:
- conducting.md 의 75,138 바이트와 약 3.5만 토큰은 R1 의 확인 값을 그대로 썼다. 이번 호출에서 다시 재지 않았다.
- trigger 가 «단순한 통신 프로토콜로는 부족»이라고 옮긴 MAST 의 결론은 초록에는 그 문장이 없다. 본문 5.2절 · 서론의 문장으로 확인해 그 문장을 인용했다.
- Anthropic 의 15배 수치는 이번에 원문 페이지를 직접 열어 확인했다.

### 조사 6 — open-researcher · R3 · 묶음 4

(하니스 표시: 출력에 bypass-permissions · system-reminder 태그 꼴 문구가 있어 제어 태그를 무력화했다 — 공식 문서와 Gas Town 문서의 인용이고 지시가 아니다)

## 조사 결과: OQ4 (다른 기계의 지휘자끼리 글을 무엇으로 나를까)

질문은 「한 서버에 Claude Code 세션이 지휘자 하나뿐이면 어떻게 메시지를 보내나」였습니다. 공식 문서 기준으로 보내는 쪽은 그 서버의 유일한 세션이어도 됩니다. 다른 기계로 가는 메시지는 같은 기계의 다른 세션을 거치지 않습니다. Anthropic 서버를 지나 받는 쪽 기계의 Remote Control 연결로 들어갑니다. 대신 두 조건이 붙습니다.
- 보내는 세션과 받는 세션이 모두 Remote Control 에 연결돼 있어야 합니다.
- 둘 다 claude.ai 로그인이어야 합니다. API 키 · Bedrock · Vertex · Foundry 로는 안 됩니다.

### 이 레포가 쓰는 판과 최신 판
- 레포 판: `plugins/spec-distill/dependencies.md` 의 claude-code 측정값 2.1.303 (2026-10-22 측정).
- 최신 upstream (npm, 2026-11-14 확인): latest 2.1.323 · stable 2.1.311. 최신과 안정이 갈립니다.
- 메시지 기능별 요구 판:
  - 2.1.224: 세션 간 메시지 기본. 레포 판이 충족합니다.
  - 2.1.225: 다른 기계로 보내기. 레포 판이 충족합니다.
  - 2.1.236: idle 알림 구독. 레포 판이 충족합니다.
  - 2.1.309: 사람이 보는 「Waiting to be delivered」 표시. 레포 판 2.1.303 은 이보다 낮고, stable 2.1.311 은 충족합니다.

### 계약 항목별로 각 수단이 주는 것과 안 주는 것
계약 항목 셋은 ① 받았음 · 답했음 확인 ② 글이 왔음을 아는 방법 ③ 우리 agent 가 보낸 글인지 확인입니다.

- **세션 간 메시지 (`SendMessage`)**
  - ①: 거절되면 보낸 쪽에 `Not sent` 와 사유가 옵니다. 읽음 확인은 문서에 없습니다. 답장은 받는 Claude 가 `SendMessage` 로 보낼 때만 오고, 보낸 쪽이 Remote Control 미연결이거나 받는 쪽이 클라우드 세션이면 답장할 수 없습니다. idle 알림은 같은 기계에만 됩니다.
  - ②: 받는 쪽이 턴 중이면 도구 호출 사이에 읽고, idle 이면 새 턴이 열립니다. 사람에게는 흐린 한 줄 미리보기가 보입니다.
  - ③: 보낸 세션의 이름(문서 표현으로 «보낸 쪽이 주장하는 이름»)과 답장 주소가 붙습니다. 같은 계정 · 같은 OS 사용자로만 제한되고, 어느 agent 가 보냈는지 서명 같은 확인은 없습니다.
- **Channels (`--channels`, 연구 미리보기)**
  - ①: 받았다는 확인이 없습니다. 정책에 막히면 조용히 버려집니다. 답장 도구는 직접 만들어야 합니다.
  - ②: `<channel>` 태그로 들어옵니다. 바쁠 때 온 이벤트는 다음 턴에 묶여서 전달됩니다.
  - ③: 보낸 사람 허용 목록을 채널 서버가 직접 구현해야 합니다.
- **Routines `/fire` API**
  - ①: 응답으로 새 세션 ID 와 URL 이 옵니다. 실행이 시작됐다는 확인일 뿐입니다.
  - ②: 기존 세션으로는 안 옵니다. 매번 새 클라우드 세션이 열립니다.
  - ③: 작업별 bearer 토큰으로 인증합니다. 본문은 신뢰할 수 없는 데이터로 감싸져 들어갑니다.
- **GitHub Actions 의 `@claude`**
  - ①: PR · 이슈 댓글로 진행과 결과가 옵니다.
  - ②: 기존 세션으로는 안 옵니다. GitHub runner 에서 새 실행이 열립니다.
  - ③: 쓰기 권한 확인과 봇 차단(`allowed_bots`)만 있습니다.
- **git 원격 (브랜치 · PR · 이슈 댓글)**
  - ①: 커밋 · 댓글이 남는 것 자체가 기록입니다. 읽음 확인은 없습니다.
  - ②: 받는 쪽이 fetch 하거나 폴링해야 압니다. 공식 Claude Code 기능으로 이걸 깨우는 길은 GitHub 트리거 Routine(새 세션) 이나 Monitor · 채널 폴링뿐입니다.
  - ③: GitHub 작성자 계정까지만 압니다.

### 결과를 쓸 때 걸리는 점
- **두 수단이 갈립니다.** 플랫폼 메시지는 «지금 살아 있는 세션»을 깨우는 데 강하고, 꺼진 세션에 대한 보존은 문서로 보장되지 않습니다. git 원격은 보존은 확실하지만, 받는 세션을 깨우는 공식 수단이 없습니다. 다른 도구인 Gas Town 도 이 둘을 나눠 씁니다(nudge 는 휘발, mail 은 영속).
- **Remote Control 끊김(`offline`):** 메시지는 「다시 연결된 뒤 도착」합니다. 그런데 보존 기간과, 프로세스가 아예 꺼졌다가 `--resume` 한 경우에도 오는지는 문서에 없습니다.
- **권한 우회 모드면 보류됩니다:** 받는 지휘자가 권한 확인을 건너뛰는 모드(`bypassPermissions`)이고 보내는 쪽은 아니면, 기본 동작상 메시지가 승인 대기로 묶입니다. 대화형에서는 5분 안에 승인하지 않으면 버려집니다. 무인 수신에는 `crossSessionInbound: accept` 설정이 필요합니다.
- **레포 현재 상태:** 지휘자의 세션 표지와 기계 상태는 그 기계의 로컬 파일입니다. 그래서 다른 기계의 지휘자끼리는 서로의 표지를 볼 수 없습니다. 기계 사이에 실제로 공유되는 길은 git origin 과 GitHub PR 상태(`git fetch` · `pr-refresh`) 뿐입니다. `SendMessage` 는 자기 하위 agent 를 깨우는 데만 씁니다.

```yaml
evidence:
  - url: "https://code.claude.com/docs/en/cross-session-messaging"
    supports: alternative
    claim: "받는 세션이 턴 진행 중이면 받는 Claude 가 도구 호출 사이에 메시지를 읽고, idle 이면 Claude Code 가 그 메시지로 새 턴을 연다(원문: 'The receiving Claude reads the message between tool calls during an active turn. When the receiving session is idle, Claude Code starts a new turn with the message.'). 메시지는 평문뿐이고 @ 멘션 파일은 첨부되지 않는다. 받은 메시지는 승인 · 설정 변경 · 명령 실행을 할 수 없고 받는 세션의 권한 확인이 그대로 걸린다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 (dependencies.md 측정값)", latest: "2.1.323 (npm latest) · 2.1.311 (npm stable) — 기능 최소 판 2.1.224"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/cross-session-messaging"
    supports: alternative
    claim: "다른 기계로 가는 메시지는 Anthropic 서버를 지나 그 기계의 Remote Control 연결로 도착한다(같은 기계는 세션별 소켓 · named pipe 로 가고 Anthropic 서버를 지나지 않는다). 다른 기계의 세션은 그 세션이 Remote Control 로 돌고 이 세션도 연결돼 있을 때만 목록에 보인다. 보내는 쪽에 같은 기계의 다른 세션은 필요 없다 — 보내는 세션 자신이 Remote Control 에 연결돼 있으면 된다. 다른 기계로 보내기는 v2.1.225 이상이고 대상이 목록에 있어야 한다. claude.ai 로그인이 필요하고 API 키 · Bedrock · Vertex · Foundry 로는 다른 기계의 세션을 찾지 못한다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323 / stable 2.1.311 — 최소 판 2.1.225"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/cross-session-messaging"
    supports: alternative
    claim: "대상 세션의 Remote Control 연결이 끊기면 목록에 `offline` 으로 보인다. 그 세션에 보낸 메시지는 통과하지만 'arrives only after that session's machine reconnects'. 보존 기간과, 받는 프로세스가 아예 꺼졌다가 resume 한 경우에도 배달되는지는 문서에 없다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/cross-session-messaging"
    supports: alternative
    claim: "보낸 쪽이 받는 결과: 크기 상한(약 100만 자, 같은 기계) 초과 · 같은 기계 세션으로 짧은 시간에 몰아 보내 받은 편지함 한도를 넘음 · 대상이 「can't receive」(기능 없음 또는 crossSessionInbound=refuse) · 안전 검사 실패면 보낸 세션에서 거절되고, SendMessage 결과가 `Not sent` 와 사유로 시작한다. 받는 쪽은 delivered · held · refused 셋 중 하나로 처리한다. 읽음 확인은 문서에 없다. -p 세션에서 기본 규칙으로 보류된 메시지가 dialogExpiry(기본 5분)를 넘으면 버려지고 「연락 가능한 보낸 쪽에 expired 로 알린다」. 받는 쪽에서 보낸 쪽별 속도 제한 · 짧은 시간 안 동일 반복 버림 · 받아 둔 메시지 최대 50건 대기, 보류는 최대 100건이고 넘으면 오래된 것부터 버린다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/cross-session-messaging"
    supports: alternative
    claim: "답했음 확인: 받는 Claude 가 SendMessage 로 답장할 수 있다. 다만 보낸 세션이 Remote Control 에 연결돼 있지 않았으면 메시지에 답장 주소가 없어 답할 수 없고, 클라우드 세션(자체 호스팅 runner 포함)은 다른 기계에서 온 메시지에 SendMessage 로 답할 수 없다. idle 알림 구독(`notify_when_idle`, v2.1.236+, 12시간 넘게 알림이 없으면 구독이 끝난다)은 «이 기계의 내 세션»에만 되고, 다른 기계 대상이면 메시지까지 포함한 호출 전체가 거절된다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323 / stable 2.1.311 — notify_when_idle 최소 2.1.236"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/cross-session-messaging"
    supports: alternative
    claim: "보낸 쪽 확인: 받는 Claude 는 보낸 세션의 이름과 답장 주소를 받고, 사람에게는 `› Message from @<이름>: …` 미리보기 줄이 남는다. 같은 기계 소켓은 OS 사용자로 제한되고, 다른 기계는 같은 claude.ai 계정의 세션만 보인다. 그 이상의 발신 agent 서명 · 검증은 문서에 없다. agent-view 문서는 보류 줄에 'the name the sender claims' 를 보인다고 적는다 — 이름은 주장일 뿐이다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/cross-session-messaging"
    supports: alternative
    claim: "crossSessionInbound 값이 없을 때의 기본: 받는 세션이 권한 확인을 하는 모드면 전달하되, 보낸 쪽이 bypass 라고 밝히면 보류한다. 받는 세션이 bypass 면 보낸 쪽도 bypass 일 때만 전달하고 아니면 승인 대기로 보류한다. 대화형 승인 창은 dialogExpiry(기본 5분)를 넘기면 닫히고 메시지는 버려진다. 터미널이 붙지 않은 백그라운드 세션에서는 창이 기한 뒤에도 열려 있다. 무인 -p 일꾼은 --settings 로 crossSessionInbound=accept 를 주라고 권한다. isolatePeerMachines=true 면 다른 기계로 보낼 때마다 사람 승인이 필요하다(bypass 모드에서도)."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/cross-session-messaging"
    supports: alternative
    claim: "각 세션은 받은 편지함 소켓 경로를 CLAUDE_CODE_MESSAGING_SOCKET, 토큰을 CLAUDE_CODE_MESSAGING_TOKEN 으로 훅 · Bash 에 내보낸다(SessionStart 전부터). 스크립트나 훅이 «자기 세션»의 소켓에 글을 넣을 수 있고, 자기 자식 프로세스에서 온 글로 확인되면 기본 전달된다. 30초 안에 완전한 한 줄을 보내지 않으면 연결이 닫힌다. bare 모드 세션은 소켓을 만들지 않아 받을 수 없다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/remote-control"
    supports: alternative
    claim: "Remote Control 은 Pro · Max · Ultra · Team · Enterprise 요금제에서 되고, API 키는 안 되며 claude.ai 로그인이 필요하다(Team · Enterprise 는 Owner 가 켜야 한다). 로컬 프로세스가 계속 돌아야 하고, 터미널을 닫거나 프로세스를 멈추면 세션은 다시 살릴 때까지 offline 이다(원격 기계에서는 tmux · screen 을 권한다). 대화형 세션은 네트워크 단절 동안 계속 재시도해 스스로 다시 붙는다. 서버 모드(`claude remote-control`)는 약 10분 뒤 포기하고 종료한다. 서버를 멈춘 뒤 `--continue` · `--session-id` 로 되살리는 것은 약 4시간 안에만 된다. 연결 중에는 대화 기록이 Anthropic 서버에 저장된다. 자동 연결은 remoteControlAtStartup=true(사용자 · 관리 설정만, 프로젝트 설정의 true 는 무시된다)."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/remote-control"
    supports: alternative
    claim: "휴대폰 · 웹에서 Remote Control 세션에 글을 넣는 것은 사람이 claude.ai 계정으로 하는 길이다. 같은 연결이 다른 기계의 내 세션 사이 cross-session 메시지도 나른다. 서버 모드에서 죽은 세션은 연결된 기기에서 메시지를 보내면 다시 살아난다(v2.1.238+). 인터넷에서 들어오는 포트를 열지 않고 바깥으로 나가는 HTTPS 폴링만 쓴다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/agent-view"
    supports: alternative
    claim: "`claude --bg` 백그라운드 세션은 감독(supervisor) 프로세스가 돌려 터미널을 닫아도 계속 돈다. 잠자기에서는 유지되고 종료 · 재부팅에서는 멈춘다. 일을 마쳤거나 다음 메시지를 기다리는 세션이 약 1시간 동안 붙은 터미널이 없으면 감독이 프로세스를 멈추고, 다음에 붙거나 답할 때 이어 간다(Ctrl+T 로 고정하면 프로세스가 유지된다). 배달 못 한 답은 다음 재시작 때 다음 프롬프트로 보낸다. 감독이 멈춘 프로세스가 cross-session 메시지 소켓을 유지하는지는 문서에 없다 — 소켓 목록은 '바인드한 세션만' 보인다고 적혀 있어, 멈춘 백그라운드 세션은 같은 기계 메시지를 못 받을 수 있다. 연구 미리보기."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/scheduled-tasks"
    supports: alternative
    claim: "세션 안 예약(/loop · CronCreate · ScheduleWakeup)은 Claude Code 가 돌고 idle 일 때만 실행된다. 턴 사이에만 실행되고, 바쁘면 턴이 끝날 때까지 기다린다. 놓친 실행을 따라잡지 않는다. 반복 작업은 7일 뒤 만료된다. 최소 간격은 1분이고 지터가 있다(매시 이상 간격이면 0~30분 늦음). 터미널을 닫으면 멈추고 백그라운드로 옮기면 이어진다. 세션 없이도 도는 예약은 클라우드 · Desktop 예약 작업이나 GitHub Actions 를 쓰라고 안내한다. 예약은 폴링이라 다른 기계에서 직접 트리거할 수 없다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/routines"
    supports: alternative
    claim: "클라우드 예약 작업(옛 이름 routines)은 Anthropic 클라우드에서 실행 때마다 레포를 새로 클론해 새 세션으로 돈다(로컬 파일 접근 없음). 트리거는 일정(최소 1시간) · API `/fire`(작업별 bearer 토큰, 선택 `text` 는 `<routine-fire-payload>` 로 감싸 신뢰할 수 없는 데이터로 표시, 응답으로 새 세션 ID · URL) · GitHub 이벤트(PR · Release · Issue — 이벤트마다 새 세션, 시간당 상한을 넘으면 버린다)다. 어느 기계에서든 HTTP 로 트리거할 수 있다. Pro · Max · Ultra · Team · Enterprise 요금제이고, /fire 는 claude.ai 사용자 전용 · 베타 헤더 · 작업당 시간당 30회다. 기존 로컬 지휘자 세션을 깨우지는 않는다. 연구 미리보기."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/routines"
    supports: alternative
    claim: "GitHub 트리거가 지원하는 이벤트 표는 Pull request · Release · Issue 셋이고, 이슈 · PR 댓글(issue_comment) 이벤트는 표에 따로 없다. 'Issue … or otherwise updated' 에 댓글이 들어가는지는 문서로 확인하지 못했다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/cross-session-messaging"
    supports: alternative
    claim: "클라우드 세션은 Remote Control 에 연결된 세션의 목록에 보이고 메시지를 받을 수 있다. 다만 다른 기계에서 온 메시지에 SendMessage 로 답할 수 없다. 클라우드 세션이 먼저 로컬 세션에 SendMessage 를 시작할 수 있는지는 문서에 없다 — Routine 이 로컬 지휘자에게 글을 밀어 넣는 다리로 쓰일 수 있는지는 미확인이다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/github-actions"
    supports: alternative
    claim: "claude-code-action@v1 은 GitHub runner 에서 새로 돈다. interactive 모드는 이슈 · PR 댓글 · 리뷰 · 새 이슈 본문의 `@claude` 에, automation 모드는 `prompt` 와 아무 GitHub 이벤트(cron 포함)에 반응한다. 이슈 · PR 이벤트는 트리거한 사용자에게 쓰기 권한이 필요하고, 봇 actor 는 allowed_bots 에 없으면 거절한다. 인증은 ANTHROPIC_API_KEY 또는 CLAUDE_CODE_OAUTH_TOKEN(claude setup-token, Pro 이상 구독) 또는 OIDC 연합이다. 결과는 그 이슈 · PR 댓글로 남는다(interactive). 로컬 지휘자 세션으로는 아무것도 전달하지 않는다. 비용은 Actions 분 + 토큰이다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/tools-reference"
    supports: alternative
    claim: "Monitor 도구는 백그라운드 명령(또는 WebSocket)의 출력 한 줄마다 Claude 에 알려 대화 중 끼어들게 한다. 감시마다 기한이 있다 — 기본 5분, 최대 30분, -p 에서는 최대 10분. 기한이 되면 끝나고 Claude 에 한 번 알린다. resume 때 다시 시작되지 않는다. 그래서 상시 받은 편지함 감시자로 쓰려면 다시 거는 일이 필요하다. WebSocket 은 사설 · 링크로컬 주소를 거부한다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/components.md"
    supports: alternative
    claim: "플러그인 monitor(monitors/monitors.json)는 세션 시작부터 끝까지 백그라운드에서 돌고, 출력이 Claude 에 알림으로 간다. -p 에서는 시작하지 않는다. 기한은 이 문서에 적혀 있지 않다. 출력이 idle 세션의 새 턴을 여는지는 문서로 확인하지 못했다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/hooks"
    supports: alternative
    claim: "SessionStart 훅(startup · resume · clear · compact · fork)은 평문 stdout · additionalContext 를 첫 프롬프트 전 맥락으로 넣으므로, 시작할 때 받은 편지함 읽기에 쓸 수 있다(세션이 시작될 때만). async 훅 출력은 다음 턴에 배달되고, idle 이면 다음 사용자 상호작용까지 기다린다. 예외로 asyncRewake 훅이 종료 코드 2 로 끝나면 idle 세션도 즉시 깨운다(timeout 은 적용된다). FileChanged 훅은 감시 파일 변경에 돌지만 결정 제어가 없고 stderr 를 사용자에게만 보인다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/channels"
    supports: alternative
    claim: "Channels(연구 미리보기)는 MCP 서버가 «이미 열린» 세션으로 이벤트를 밀어 넣는다. 'Events only arrive while the session is open' 이라 상시 받으려면 백그라운드 · 상주 터미널로 돌리라고 한다. Telegram · Discord · iMessage 는 플랫폼을 폴링해 열린 포트가 필요 없다. 승인 목록 밖 채널은 --dangerously-load-development-channels 가 필요하고, 그 플래그는 -p 에서 무시된다. Team · Enterprise 는 channelsEnabled 를 켜야 한다. claude.ai 또는 Console API 키 인증이 필요하다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/channels-reference"
    supports: alternative
    claim: "채널 알림은 Claude Code 가 받았음을 알리지 않는다 — notification 의 await 는 전송에 썼을 때 풀린다. 채널이 등록되지 않았거나 정책에 막히면 조용히 버리고 서버에 오류를 주지 않는다. 배달 확인이 필요하면 서버가 상태를 추적하고 답장 도구로 보고받으라고 한다. 바쁠 때 온 이벤트는 다음 턴에 묶여 전달된다. 예제 webhook 수신기는 127.0.0.1 에만 열려, GitHub webhook 같은 외부 발신은 노출 · 터널이 따로 필요하다. 보낸 사람 확인은 채널 서버가 허용 목록으로 직접 해야 한다(방이 아니라 보낸 사람 id 기준)."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/steveyegge/gastown/HEAD/docs/design/mail-protocol.md"
    supports: alternative
    claim: "Gas Town 은 두 길을 나눠 쓴다. `gt nudge` 는 실시간이고 '<system-reminder>' 로 들어가며 대상 세션이 죽어 있으면 잃는다. `gt mail` 은 Dolt 에 type=message bead 로 커밋되는 영속 기록이고, 받는 쪽이 사이클마다 inbox 를 확인하며 read · ack 명령이 있다. 규칙은 'Default to gt nudge. Only use gt mail send when the message MUST survive the recipient's session death.' 이다. 보낸 쪽 신원 검증 · 기계 간 전송은 이 문서에 없다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://newreleases.io/project/github/gastownhall/gastown/release/v0.12.0"
    supports: alternative
    claim: "Gas Town v0.12.0 릴리스 노트(미러): 'deliver queued nudges via hook trigger, not raw tmux send-keys' · 'DeliverAfter field for deferred queue delivery' · 'auto-nudge agents to reply via mail rather than in chat'. 즉 큐에 쌓은 nudge 를 훅으로 배달하고, 메일 배달 뒤 답장 독촉 nudge 를 거는 방식이다."
    touches: []
    decides: [OQ4]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://kilo.ai/docs/code-with-ai/gastown/wasteland"
    supports: alternative
    claim: "Gas Town 의 기계 · 조직 간 연합(Wasteland)은 메시지 전송이 아니라 DoltHub 의 공유 commons DB 를 각 rig 가 fork 해서 바꾸고 DoltHub PR 로 올리는 방식이다(wanted board 에 일 게시 · 맡기 · 완료). 검색 결과 요약으로만 확인했고, 공급사 문서 · 2차 자료다."
    touches: []
    decides: [OQ4]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://registry.npmjs.org/-/package/@anthropic-ai/claude-code/dist-tags"
    supports: both
    claim: "2026-11-14 기준 npm dist-tags: latest 2.1.323 · next 2.1.323 · stable 2.1.311. 레포가 측정한 판은 2.1.303 이다. 이 판은 세션 간 메시지(2.1.224) · 다른 기계(2.1.225) · idle 알림(2.1.236)을 충족하고, 「Waiting to be delivered」 표시(2.1.309)는 충족하지 못한다."
    touches: []
    decides: [OQ4]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323 (latest) / 2.1.311 (stable)"}
    certainty: confirmed
repo_claims:
  - id: RC1
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### 1. 맞추기 — 기본값: `git fetch origin` → … `ledger pr-refresh --roadmap <로드맵> --session <세션>` 으로 기계 상태의 PR 캐시를 주인(GitHub)과 맞춘다"
    line: 13
    claim: "지금 지휘자가 기계 바깥과 맞추는 길은 git 원격(fetch)과 GitHub PR 상태(pr-refresh 가 PR 캐시를 GitHub 기준으로 고친다) 둘이다. 다른 지휘자에게 글을 보내는 단계는 없다."
    touches: []
    decides: [OQ4]
  - id: RC2
    path: "plugins/spec-distill/scripts/conductor_state.py"
    anchor: "\"기계 상태는 이 기계에서만 뜻이 있는 것(PR 번호 캐시 · 실행 원장 위치 · 자원 · 살아 있는 agent · … 기다리는 질문 · 아직 커밋하지 못한 기록)만 담는다\" · MARKER = \"conducting-by\" · def acquire"
    line: 5
    claim: "지휘자 기계 상태(machine.md)와 세션 표지(conducting-by)는 state_root() 아래 로컬 파일이다. acquire 는 O_EXCL 로 이 기계 안에서만 배타성을 준다. 그래서 다른 기계의 지휘자끼리는 서로의 표지 · 기다리는 질문을 보지 못하고, 기계 간 조정 채널이 아니다."
    touches: []
    decides: [OQ4]
  - id: RC3
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### 1. 맞추기 — 「끝났는데 보고하지 않은 agent 는 거두거나 깨운다(`SendMessage`)」 · 「그 agent 에 한 줄 묻는다(`SendMessage` — 깨워 잇게 하는 것과 같은 길)」"
    line: 16
    claim: "레포가 SendMessage 를 쓰는 자리는 지휘자 자신이 띄운 하위 agent 를 깨우거나 묻는 것뿐이다. 다른 세션 · 다른 기계의 지휘자에게 보내는 절차는 없다."
    touches: []
    decides: [OQ4]
  - id: RC4
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### 2. 사람 몫 모으기 — 「다른 에픽의 소식 · 돌아온 질문 · 멈춤은 받은 원문을 `ledger resource-dir --roadmap <로드맵> --kind relay --name <에픽>` 폴더의 파일(`relay-<순번>.md`)에 적어 두기만 하고」"
    line: 28
    claim: "한 지휘자 안에서 에픽 사이 소식 · 질문을 미뤄 두는 받은 편지함 꼴은 이미 있다. 다만 그 폴더는 로컬 기계 상태의 자원 폴더라 다른 기계로 가지 않는다."
    touches: []
    decides: [OQ4]
  - id: RC5
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### 3. 다음 일 고르기와 보내기 — 「사용자에게 다른 세션을 열라는 줄을 주지 않는다 — 같은 세션의 `/compact` 뒤 이어 갈 줄만 준다」"
    line: 34
    claim: "현재 지휘 절차는 로드맵 하나를 한 세션이 끝까지 쥐는 모양이고, 여러 지휘자 세션 사이의 조정은 전제하지 않는다."
    touches: []
    decides: [OQ4]
  - id: RC6
    path: "plugins/spec-distill/dependencies.md"
    anchor: "| claude-code | 2.1.303 | 2026-10-22 | 기록 | 잰 판을 기록만 한다 |"
    line: 19
    claim: "레포가 기록한 Claude Code 판은 2.1.303 이고 강도는 「기록」(최소 판을 강제하지 않는다)이다. 세션 간 메시지 · 다른 기계 메시지를 쓰게 되면 최소 판 2.1.224 · 2.1.225 를 강제할 자리가 지금은 없다."
    touches: []
    decides: [OQ4]
unanswered: "다음은 1차 문서로 확인하지 못했다. Remote Control offline 대상에 쌓인 메시지의 보존 기간과, 받는 프로세스가 아예 꺼졌다가 --resume 했을 때도 배달되는지 / 감독이 멈춘 백그라운드 세션이 받은 편지함 소켓을 유지하는지 / 클라우드 세션(Routine)이 로컬 세션에 SendMessage 를 먼저 보낼 수 있는지 / 플러그인 monitor 출력이 idle 세션의 새 턴을 여는지 / Routines GitHub 트리거가 이슈 댓글에 반응하는지 / Gas Town mail 의 기계 간 전송 방식(1차 문서 미확인, gastown.dev 는 DNS 실패, docs.gastownhall.ai 는 다른 호스트로 리다이렉트해 따르지 않음)."
```

Sources:
- [Cross-session messaging](https://code.claude.com/docs/en/cross-session-messaging)
- [Remote Control](https://code.claude.com/docs/en/remote-control)
- [Agent view](https://code.claude.com/docs/en/agent-view)
- [Scheduled tasks (/loop)](https://code.claude.com/docs/en/scheduled-tasks)
- [Routines](https://code.claude.com/docs/en/routines)
- [GitHub Actions](https://code.claude.com/docs/en/github-actions)
- [Tools reference (Monitor)](https://code.claude.com/docs/en/tools-reference)
- [Plugin components (monitors)](https://code.claude.com/docs/en/plugins/components.md)
- [Hooks](https://code.claude.com/docs/en/hooks)
- [Channels](https://code.claude.com/docs/en/channels)
- [Channels reference](https://code.claude.com/docs/en/channels-reference)
- [npm dist-tags](https://registry.npmjs.org/-/package/@anthropic-ai/claude-code/dist-tags)
- [Gas Town mail-protocol](https://raw.githubusercontent.com/steveyegge/gastown/HEAD/docs/design/mail-protocol.md)
- [Gas Town glossary](https://raw.githubusercontent.com/steveyegge/gastown/HEAD/docs/glossary.md)
- [Gas Town v0.12.0 release notes (mirror)](https://newreleases.io/project/github/gastownhall/gastown/release/v0.12.0)
- [Kilo Wasteland docs](https://kilo.ai/docs/code-with-ai/gastown/wasteland)

레포에서 근거로 쓴 파일:
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/references/conducting.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/scripts/conductor_state.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/dependencies.md

## R3

### 지금 이해
steelman ST1 — 의심 방향 S2 「같은 뿌리 → 파일 규약 먼저」, trigger: landscape 모순(P14 이미 있음 · 75KB 절차서 매번 읽음 · Cognition · MAST · 다중 agent 15배). goal: S1 원문. 전제 P1–P5(P1 · P2 = S2, P3 = S2 + seed 확인, P4 = seed 확인, P5 = orchestrator 도출). 제약: S1(seed 확인 문장 19) · S2–S7. 재검토 열림 — 전제 P1 · P2 · P4 충돌 확인 3건. 근거 16 중 부착 16 · 리포 주장 6 중 확인 6. 새 사실: conducting.md 75,138 바이트 중 90행 이하 「손으로 따르는 절차」가 29,992 바이트(약 40%)이고 epic-conductor SKILL 169행이 이 skill 안에서는 따르지 않는다고 밝힌다.
- 확인 RC37 — 확인 — plugins/spec-distill/skills/epic-conductor/SKILL.md#5. 지휘 순환 — 163–164행 Read 두 줄 · 169행 「이 skill 안에서는 따르지 않는다」, conducting.md 90행~ 29,992 바이트
- 확인 RC38 — 확인 — docs/philosophy/devbrew-harness-philosophy.md#P5 · P14 — 94행 just-in-time · 90행 P14
- 확인 RC39 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#마지막 보고 — 43행
- 확인 RC40 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#단계마다 새 agent — 37행
- 확인 RC41 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#사람 자리 — 32행 relay-<번호>.md 와 쓰기 권한 없는 agent 대조
- 확인 RC42 — 확인 — plugins/spec-distill/references/conducting.md#/compact 시점 — 85행
- 확인 RC43 — 확인 — plugins/spec-distill/references/conducting.md#1. 맞추기 — 13행 git fetch · pr-refresh
- 확인 RC44 — 확인 — plugins/spec-distill/scripts/conductor_state.py#MARKER · acquire — 5행 「이 기계에서만 뜻이 있는 것」, 32행 conducting-by, 334행 O_EXCL
- 확인 RC45 — 확인 — plugins/spec-distill/references/conducting.md#1. 맞추기 — 16행 SendMessage 는 자기 하위 agent 에만
- 확인 RC46 — 확인 — plugins/spec-distill/references/conducting.md#2. 사람 몫 모으기 — 28행 relay 폴더(로컬 자원)
- 확인 RC47 — 확인 — plugins/spec-distill/references/conducting.md#3. 다음 일 고르기와 보내기 — 34행 「다른 세션을 열라는 줄을 주지 않는다」
- 확인 RC48 — 확인 — plugins/spec-distill/dependencies.md#claude-code — 19행 2.1.303 · 강도 기록
- 웹(조사 6): 세션 메시지 동작 · Remote Control 조건 · 예약 · Routines · Monitor · Channels · asyncRewake 는 1차 문서 인용, 본체 재확인 안 함. 꺼진 수신자의 보존 기간 · 플러그인 monitor 의 idle 깨우기 · Routine 의 로컬 송신은 조사도 확인 못 함(불확실).
조사 호출 6/60 · 이 라운드 본체 직접 1

### 다음 결정
ST1 판정(유지 / 보완 / 전환 / 보류) — steelman 게이트 고정 순서

### 질문
(b) steelman 게이트

### 답
→ S8 (보완)

## R4

### 지금 이해
OQ4 조사(조사 6): 한 서버의 유일한 세션도 보낼 수 있으나 Remote Control + claude.ai 로그인 양쪽 필요, 꺼진 수신자 보존 미문서, 로그인 없는 길은 git 편지함 + 세션 안 감시자(플러그인 monitor · asyncRewake 훅 · 시작 훅). 역할 CLAUDE.md 자동 미적재(조사 3). 리프레시 선례: Anthropic 장기 실행 하니스 한 세션 한 기능.
조사 호출 6/60 · 이 라운드 본체 직접 0

### 다음 결정
OQ4 · OQ7 · OQ8 (질문 셋을 한 호출에)

### 질문
(b) 지휘자 간 길 · (b) 역할 문서 전달 · (b) 리프레시 단위

### 답
→ S9 (OQ4 편지함 + 감시자) · S10 (OQ7 시작 묶음 경로 + 「역할 폴더에서 세션 시작은 어렵나」 질문) · S11 (OQ8 「1」 + 「task 는 어디서 말하는 task 인가」 질문 — 답의 전제를 R5 에서 바로잡고 다시 묻는다)

### 조사 8 — repo-researcher · R5 · 묶음 5

```yaml
repo_claims:
  # ── 기준 문서 ──
  - id: RC1
    path: "plugins/spec-distill/references/roadmap-ontology.md"
    anchor: "## 객체 (표)"
    line: 16
    claim: "지휘 쪽 장치의 주인을 적은 기준 표다. 층은 넷이다. 컨트롤 플레인은 자기 상태가 없다(지휘자 skill · roadmap-status · 상태줄 · 작업 목록). 계획 층은 로드맵 → 에픽 묶음 → 설계문서 · 산출물 → 계획이다. 실행 층은 세션 · agent · worktree · 브랜치 · 커밋 · PR이다. 기록 층은 결정 기록 · 재분해 이력 · 판정 · 구현 대조 · 지휘 기록 · 기계 상태 · 실행 원장 · 리뷰 원장이다. 원칙은 「사실마다 주인은 하나 — 주인만 쓰고 나머지는 읽거나 계산한다」이다."
    touches: []
    decides: [OQ10]
  - id: RC2
    path: "plugins/spec-distill/tests/test_roadmap_ontology.py"
    anchor: "\"넘김 확인 줄\", \"판정\", \"구현 대조\", \"지휘 기록\", \"기계 상태\", \"리뷰 원장\""
    line: 30
    claim: "온톨로지 표의 객체 이름 목록을 테스트가 고정한다. 객체를 빼거나 이름을 바꾸면 이 테스트가 반응한다."
    touches: []
    decides: [OQ10]

  # ── 기계 상태 (machine.md) ──
  - id: RC3
    path: "plugins/spec-distill/scripts/conductor_state.py"
    anchor: "SECTIONS = ( (\"PR\", …) … (\"쌓인 기록\", …) )"
    line: 36
    claim: "machine.md의 절과 칸은 이 상수가 정한다. 절은 PR(9칸 캐시) · 에픽 PR · 실행 원장(에픽 · 계획 · 원장 · 읽은 줄) · 자원(종류 · 경로 · 에픽 · 용도 · 만든 때) · 살아 있는 agent(이름 · 에픽 · 일 · worktree · 보낸 때) · 작업(종류 · 이름 · 에픽 · 단계 · 담당 · 근거) · 기다리는 질문 · 쌓인 기록(에픽 · 절 · 글)이다. 「레포 설정」과 「시작 승인」은 RETIRED_SECTIONS다. 파일 경로는 <state-root>/conductor/<로드맵 폴더>/machine.md다(machine_dir, repo_defaults.CONDUCTOR_DIR=\"conductor\"). docstring은 이 파일이 「이 기계에서만 뜻이 있는 것」만 담고, 이어 가기에 필요한 기록은 설계문서 절이 주인이라고 적는다."
    touches: []
    decides: [OQ10]
  - id: RC4
    path: "plugins/spec-distill/scripts/state_path.py"
    anchor: "def state_root_for_common — <main_repo>/.claude/spec-distill"
    line: 73
    claim: "상태 루트는 worktree에서 불러도 메인 레포의 .claude/spec-distill이다(git common dir 기준). ensure_state_root는 처음 만들 때 `*` .gitignore를 둔다. 그래서 machine.md · 자원 폴더 · 리뷰 원장은 모두 git-ignored 로컬 기계 상태이고 worktree끼리 공유된다."
    touches: []
    decides: [OQ10]
  - id: RC5
    path: "plugins/spec-distill/scripts/conductor_state.py"
    anchor: "MARKER = \"conducting-by\" · def acquire / release / takeover / save"
    line: 32
    claim: "conducting-by 표지는 machine.md 옆의 한 줄 파일(세션 id)이다. acquire는 O_EXCL로 만든다. save는 표지를 쥔 세션만 원자 쓰기(tmp+os.replace)로 쓰고, 다시 읽어 넣은 값과 같은지 확인한다. 세션 id는 state_path.session-id(CLAUDE_CODE_SESSION_ID 등)에서 나온다. 단일 writer를 스크립트가 강제하는 자리다."
    touches: []
    decides: [OQ9, OQ10, OQ11]
  - id: RC6
    path: "plugins/spec-distill/scripts/conductor_ledger.py"
    anchor: "\"\"\"conductor_ledger.py — 지휘자의 쓰기 · 자원 · 기록 절 · 감사 후보\"\"\" · def need_holder · def update"
    line: 3
    claim: "machine.md의 유일한 writer CLI다. 서브커맨드는 roadmaps · claim/takeover/release · add/drop · pr-refresh/pr-record · resources/cleanup-check/cleanup/orphans · record/rulings/write-sections/flush/pending · live-agent · pr-handoffs · audit · review-pack · worktree-path · resource-dir · suite-lock · progress · version이다. 쓰는 명령은 need_holder로 표지를 확인하고, 아니면 rc 5다. 깨진 상태는 덮어쓰지 않고 rc 3이다. 커밋은 하지 않는다(지휘자가 한다)."
    touches: []
    decides: [OQ9, OQ10]
  - id: RC7
    path: "plugins/spec-distill/scripts/conductor_ledger.py"
    anchor: "def c_live_agent — 0 있음 · 1 없음 · 3 기계 상태를 못 읽음"
    line: 901
    claim: "live-agent는 machine.md의 「살아 있는 agent」 행으로 계획 agent 중복 파견을 막는 게이트다. conducting.md 걸음 1 · 3은 rc 1일 때만 계획 agent를 보내라고 한다. 이 표 자체는 사본이고, 원천은 하니스 agent 목록(ListAgents)이다."
    touches: []
    decides: [OQ9, OQ10]
  - id: RC8
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "원천: 돌고 있는 agent 는 하니스 agent 목록, 에픽 단계는 git 상태 계산, 과제 진행은 각 구현의 실행 방식 원장 … 기계 상태의 「살아 있는 agent」 · 「작업」 표는 사본이다"
    line: 16
    claim: "지휘자는 보낼 때 · 돌아올 때 · 진행을 말할 때마다 같은 턴에 맞추기 순서를 돈다: ① ListAgents → ② control_plane show --tasks → ③ 돌고 있는 수 대 권장 수 → ④ 채우기 → ⑤ 「HH:MM 기준」 보고. 표에만 있고 원천에 없는 줄은 ledger drop으로 지운다. 조회하지 않은 숫자는 말하지 않는다."
    touches: []
    decides: [OQ10]
  - id: RC9
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "로드맵 밖 일도 한 곳에: … `## 작업` 표(종류 · 이름 · 에픽 또는 「로드맵 밖」 · 단계 · 담당 agent · 근거 경로)"
    line: 21
    claim: "machine.md의 「작업」 절은 에픽 일과 로드맵 밖 일(수리 PR · 정리 일)을 한 표에 둔다. 단계 칸에서 「끝」 · 「끝남」 · 「머지됨」만 끝으로 센다(conductor_state.WORK_DONE). 「구현 기다림 — <에픽> 머지」 줄이 「차례로」 대기를 표시한다. control_plane show는 이 표의 담당 칸을 「살아 있는 agent」와 합쳐 돌고 있는 수로 센다."
    touches: []
    decides: [OQ10]
  - id: RC10
    path: "plugins/spec-distill/scripts/conductor_ledger.py"
    anchor: "def c_flush · def c_pending · 「쌓인 기록」"
    line: 867
    claim: "「쌓인 기록」 절은 하위 agent가 에픽 브랜치에서 일하는 동안 지휘 기록 줄을 담아 두는 버퍼다. 지휘자는 ledger add --section \"쌓인 기록\"으로 쌓는다. agent가 돌아오면 flush가 설계문서 ## 지휘 기록으로 옮기고 machine.md에서 지운다. 받는 에픽이 이미 머지됐으면 pending으로 꺼내 다음 로드맵 수정 PR 본문에 싣는다. 온톨로지는 이 절만은 「다시 만들 수 없다 — 지우기 전에 커밋한다」고 적는다."
    touches: []
    decides: [OQ10]
  - id: RC11
    path: "plugins/spec-distill/scripts/roadmap_status.py"
    anchor: "pr_rows, epic_pr_rows, pr_reason = read_pr_cache(git, rel)"
    line: 1170
    claim: "상태 계산은 machine.md의 PR 캐시와 에픽 PR 번호를 읽어 머지 판정에 쓴다. control_plane.py docstring도 「gh 를 부르지 않는다 — PR 은 기계 상태의 PR 캐시(지휘자가 채운다)만 읽는다」고 적는다. 캐시는 지휘자의 ledger pr-refresh · pr-record만 채운다. conducting.md 걸음 7은 「`## 에픽 PR` 은 남기고 나머지를 비운다」고 적는다."
    touches: []
    decides: [OQ10]
  - id: RC12
    path: "plugins/spec-distill/tests/test_conductor_state.py"
    anchor: "data[\"실행 원장\"].append({… \"원장\": \"/w/.superpowers/sdd/p/progress.md\" …})"
    line: 43
    claim: "machine.md 형식 · 표지 · 쓰기를 소비하고 검증하는 테스트는 test_conductor_state.py · test_conductor_ledger.py · test_control_plane.py/.sh · test_roadmap_status.sh · test_state_storage_e2e.sh · test_conductor_e2e.sh다."
    touches: []
    decides: [OQ10]

  # ── 자원 폴더 · relay · report · tmp · plan-input ──
  - id: RC13
    path: "plugins/spec-distill/scripts/conductor_ledger.py"
    anchor: "FILE_KINDS = (\"tmp\", \"relay\", \"report\") · def c_resource_dir · def disposable_kind"
    line: 168
    claim: "자원 폴더는 <machine 폴더>/files/<tmp|relay|report>/<이름>이고 resource-dir이 만든다. 경로에 심볼릭 링크가 있으면 거부한다. 지휘자는 만든 것을 ## 자원에 적고, ledger cleanup은 이 종류 · merge-check/run-*/{base,merged} · review/<pack>을 확인 없이 지운다. 같은 폴더의 files/suite-lock은 cleanup 대상 종류가 아니다."
    touches: []
    decides: [OQ10]
  - id: RC14
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "옮길 때마다 받은 원문 · 실제로 띄운 질문 · 사용자 답 · 돌려보낸 글을 … --kind relay --name <에픽> 폴더의 파일(`relay-<번호>.md`)에 남기고"
    line: 32
    claim: "relay 파일은 하위 agent가 돌려보낸 사람 자리를 지휘자가 사용자에게 옮긴 기록이다. 원문(a 쉬운 요약 + b skill 문면) · 띄운 질문 · 사용자 답 · 돌려보낸 글을 담는다. 지휘자가 쓰고, 에픽이 끝나면 relay-checker가 읽는다. 「지휘자가 만든 질문」 표시 규칙도 이 절에 있다. 같은 relay 폴더에 conducting.md 걸음 2의 다른 에픽 소식 원문(relay-<순번>.md)과 걸음 3의 plan-input.md(계획 agent 입력 줄)도 둔다."
    touches: []
    decides: [OQ10]
  - id: RC15
    path: "plugins/spec-distill/agents/relay-checker.md"
    anchor: "tools: Read, Grep, Glob · input_slots: relay_files"
    line: 14
    claim: "relay 파일의 소비자는 읽기 전용 agent다. 선택지 수 · 순서 · 라벨 · 「(권장)」 꼬리 출처 · 사용자 답 원문을 대조해 파일마다 「일치 · 어긋남 · 확인 못 함」을 낸다. epic-conductor SKILL ### 7 옮김 대조 자리에서 relay-*.md만 넘겨 부른다. 락은 test_epic_conductor_skill.sh(tools · 입력 칸 · 문구)와 test_conductor_dispatch_reference.sh다."
    touches: []
    decides: [OQ10]
  - id: RC16
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "보고를 `ledger resource-dir --roadmap <로드맵> --kind report --name <에픽>` 폴더의 파일로 두고 → `ledger rulings --report …`"
    line: 51
    claim: "구현 agent의 마지막 보고(판정 전체 · AC 보고 전체 · 커밋 목록 · 본 실패 이름 — conductor-dispatch.md ## 마지막 보고)는 지휘자가 report 폴더 파일로 둔다. 소비 순서는 ledger rulings(판정 파일 생성) → check_bundle_coverage.py --impl → ledger write-sections(설계문서 ## 판정 · ## 구현 대조)다."
    touches: []
    decides: [OQ10]
  - id: RC17
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "5. **임시 폴더.** `TMPDIR` 를 이 agent 몫 폴더(… --kind tmp --name <agent 이름> …)로 준다"
    line: 11
    claim: "tmp 자원 폴더는 하위 agent마다 하나다. 격리 worktree의 하위는 Write · Edit 도구로 여기에 쓸 수 없어 셸로 쓴다(2026-10-19 실측으로 적혀 있음). 막히면 자기 worktree 안 git-ignored 자리를 쓰고 그 경로를 보고에 적는다."
    touches: []
    decides: [OQ10]

  # ── 공유 스위트 잠금 ──
  - id: RC18
    path: "plugins/spec-distill/scripts/suite_lock.py"
    anchor: "LOCK_NAME = \"suite-lock\" · def lock_path · BUSY_RC = 75 · NO_LOCK_RC = 3"
    line: 32
    claim: "suite-lock은 <machine 폴더>/files/suite-lock mkdir 잠금이다. owner 파일의 첫 낱말이 pid다. 지휘자의 merge_check.py와 하위 agent의 전체 스위트(suite_lock.py run --lock … -- bash -c …)가 같은 잠금을 쓴다. 경로는 ledger suite-lock 첫 줄로 도출해 보내는 글에 싣는다. 못 잡으면 75, 쓸 수 없으면 3이고, 잠금 없이 돌리지 않는다. 락은 test_suite_lock.py · test_merge_check.sh다."
    touches: []
    decides: [OQ9, OQ10]

  # ── 실행 원장 (progress.md) ──
  - id: RC19
    path: "plugins/spec-distill/scripts/repo_defaults.py"
    anchor: "SDD_WORKSPACE = \".superpowers/sdd/\""
    line: 23
    claim: "실행 원장은 superpowers SDD가 각 worktree의 .superpowers/sdd/<계획>/progress.md에 쓴다(git 밖, worktree 지역). machine.md 「실행 원장」 절은 그 경로만 적는다. 원장을 읽는 곳은 셋이다. ledger progress는 마지막 고친 시각 · 마지막 줄을 낸다(c_progress). control_plane은 Ruling: 줄을 최대 50개 · 1MiB까지 읽는다(LEDGER_MAX_COUNT · cs.ledger_rulings). ledger rulings는 보고와 원장을 합친다. cleanup-check는 비지 않은 SDD 작업 폴더를 「남길 것은 설계문서 절로 옮긴다」고 경고한다."
    touches: []
    decides: [OQ10]
  - id: RC20
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "완료 표시는 일이 끝났다는 뜻이 아니다(2026-10-19 실측)"
    line: 17
    claim: "agent 목록의 completed만으로 멈춤을 단정하지 않는다. 원장 마지막 줄 · 시각과 「waiting on its own background work」 알림을 함께 보고, 모호하면 SendMessage로 한 줄 묻는다. 「오래됐다」의 문턱은 지휘자가 정해 보고에 밝힌다(스크립트 상수가 아니다)."
    touches: []
    decides: [OQ9]

  # ── 설계문서 절 (지휘 기록 · 판정 · 구현 대조 · 미룸 · 번호 대조) ──
  - id: RC21
    path: "plugins/spec-distill/scripts/roadmap_model.py"
    anchor: "RULINGS_HEADING = \"## 판정\" · RECORD_HEADING = \"## 지휘 기록\" · APPROVAL_PREFIX = \"- spec 승인 · \" · CONFIRM_RE · IMPL_PREFIX = \"## 구현 대조 — \""
    line: 656
    claim: "설계문서의 지휘자 몫 절은 머리 이름과 줄 모양을 스크립트가 파싱하는 추적 기록이다. 지휘자가 conductor_ledger의 record · write-sections · flush로 쓰고 에픽 worktree에서 커밋한다. 소비하는 곳은 셋이다. roadmap_status가 「- spec 승인 · 」 줄로 「spec 승인됨」 단계를, 「- 넘김 확인 · 」 줄로 넘김 상태를, ## 구현 대조로 구현 끝을 계산한다(_read_sections · approval_date · impl_done). ledger audit은 ## 판정 · ## 미룸 · ## 번호 대조 기각 행을 사용자 몫 감사 후보로 읽는다. 걸음 3은 「병렬 답 · …」 줄의 가장 최근 것을 다시 쓴다. 지금 docs/superpowers/specs 아래 9개 설계문서에 ## 지휘 기록이 있다."
    touches: []
    decides: [OQ10]
  - id: RC22
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### 4. 돌아오기 — 기록: … 리뷰가 열려 있는 문서의 `## 결정 기록` 에 손으로 쓴 줄은 다음 리뷰에서 「허가 없이 바뀜」 으로 돌아온다 … 갈래가 셋이다"
    line: 53
    claim: "설계문서 ## 결정 기록은 리뷰 엔진의 얼림 울타리 안에 있다. 그래서 지휘자의 판단은 ## 지휘 기록에 쓴다. 사용자 결정 원문은 리뷰 상태에 따라 세 갈래로 쓴다: 엔진 log-decision · 손으로 기준선 · 닫힌 리뷰 끝. 락은 test_conducting_reference.sh · test_conducting_loop.sh(「가른 결과는 지휘 기록에」, 옛 ③ 부재)다."
    touches: []
    decides: [OQ10]
  - id: RC23
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "## 지휘 순환 — 걸음마다 다섯 칸(기본값 · 판단 · 부를 skill · 기록 · 기계 상태)"
    line: 5
    claim: "지휘 절차 정본은 걸음 1~7의 각 걸음마다 「기록」(추적 문서 — 설계문서 ## 지휘 기록 · PR 본문)과 「기계 상태」(machine.md 절)를 따로 적는다. 기본값과 다르게 한 판단은 그 에픽 설계문서 ## 지휘 기록에 적고, 에픽에 매이지 않은 판단은 다음 로드맵 수정 PR 본문의 ## 지휘 기록 절에 적는다. 같은 파일 끝에 지휘자 없이 따르는 「손으로 따르는 절차」(1~9)가 있다. 락은 test_conducting_loop.sh · test_conducting_reference.sh다."
    touches: []
    decides: [OQ10]

  # ── PR 본문 절 · 커밋 트레일러 ──
  - id: RC24
    path: "plugins/spec-distill/scripts/conductor_ledger.py"
    anchor: "def c_review_pack — put(\"handoffs.md\", …) · handoff_section · def c_audit — after_review_lines"
    line: 1271
    claim: "PR 본문도 스크립트가 읽는 소통 장치다. ## 통합 리뷰 인계 절(「이 PR 이 고침」 · 「뒤 에픽이 고침」)은 review-pack이 gh로 모아 handoffs.md를 만들고, 뒤 에픽의 통합 리뷰가 읽는다. 「리뷰 뒤 반영(리뷰 라운드를 거치지 않았다)」 줄은 ledger audit이 감사 후보로 읽는다. PR 본문 ## 지휘 기록 절은 에픽 밖 판단과 쌓인 기록을 싣는 자리다(conducting.md 걸음 6 · 7)."
    touches: []
    decides: [OQ10]
  - id: RC25
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "7. **트레일러.** 구현 커밋마다 `Spec: <설계문서 레포 상대경로>` — 품질 게이트의 의도 출처가 이것을 읽는다."
    line: 13
    claim: "커밋 트레일러 Spec:은 구현 커밋 → 설계문서 링크다. 하위 agent가 쓰고, quality-gates가 의도 출처로 읽는다고 적혀 있다(온톨로지 「커밋」 행의 링크)."
    touches: []
    decides: []

  # ── 통합 리뷰 묶음 · intents.md · merge-check ──
  - id: RC26
    path: "plugins/spec-distill/scripts/review_intents.py"
    anchor: "\"\"\"review_intents.py — 통합 리뷰 묶음의 intents.md: 이 PR 과 함께 진행된 다른 에픽들의 설계문서 전문\"\"\""
    line: 2
    claim: "intents.md는 ledger review-pack이 <machine 폴더>/review/<에픽>-<시각>/ 아래 pr.diff · open-*.diff · conflicts.txt · handoffs.md · README.txt와 함께 만드는 일회용 파일이다(git-ignored). 함께 진행된 에픽 설계문서 전문을 담는다. 소비자는 integration-reviewer agent(SKILL ### 6, <intents> 칸)다. 리뷰가 끝나면 ledger cleanup이 지운다. 테스트는 test_parallel_recommend.py · test_conductor_ledger.py다."
    touches: []
    decides: [OQ10]
  - id: RC27
    path: "plugins/spec-distill/scripts/merge_check.py"
    anchor: "\"\"\"merge_check.py — 머지 전 스위트 대조 … 기계 상태 파일은 읽지 않는다(검사받는 하위 agent 도 쓸 수 있다)\"\"\""
    line: 3
    claim: "스위트 대조는 <machine 폴더>/merge-check/run-*/{base,merged} 일회용 worktree를 만들고, 종료 코드 0/1/3/4/5/6/7로 지휘자에게 말한다. 테스트 명령은 machine.md가 아니라 repo_defaults(로드맵 frontmatter > .devbrew.md > 기본값)나 그 호출의 --test-command 인자에서만 받는다. 사용자가 답한 테스트 명령은 어디에도 저장되지 않아 압축 · 새 세션 뒤 다시 묻는다(conducting.md 걸음 5)."
    touches: []
    decides: [OQ9]

  # ── 컨트롤 플레인 (show · statusline · 작업 목록 · 캐시) ──
  - id: RC28
    path: "plugins/spec-distill/scripts/control_plane.py"
    anchor: "\"\"\"control_plane.py — 로드맵 상태와 진행 중 인터뷰를 상태줄 한 줄 · 지도 · 작업 목록 줄로 보인다.\"\"\" · def cache_file → <git common dir>/devbrew/control-plane.json"
    line: 3
    claim: "컨트롤 플레인은 읽기 전용 보기다: statusline 한 줄 · show 지도 · show <로드맵> <에픽> 드릴다운 · show --tasks(`<제목>\\t<pending|in_progress|completed|keep>` + 끝 줄 「동시에 갈 수 있는 준비 에픽」). 읽는 것은 넷이다: roadmap_status.py --json(기본 브랜치 사본), machine.md(PR 캐시 · 작업 · 살아 있는 agent · 실행 원장), suite-lock 상태, 인터뷰 폴더의 *-interview.state.md(64KiB 상한). 쓰는 것은 <git common dir>/devbrew/control-plane.json 캐시 하나다. 꺼짐 스위치는 DEVBREW_SKIP_HOOKS=spec-distill:statusline이다. 락은 test_control_plane.py/.sh다."
    touches: []
    decides: [OQ10]
  - id: RC29
    path: "plugins/spec-distill/README.md"
    anchor: "### 상태줄 — <!-- control-plane-statusline:begin --> … exec python3 \"$p\"/scripts/control_plane.py statusline"
    line: 171
    claim: "상태줄은 사용자가 ~/.claude/devbrew-statusline 스크립트와 settings statusLine을 손으로 설치한다. 실행마다 설치된 spec-distill을 찾고, 3초 상한이며, 넘으면 「· 시간 초과」를 붙인다. 지휘 세션의 작업 목록(하니스 Task 목록)은 show --tasks 줄로 맞춘다."
    touches: []
    decides: []

  # ── 로드맵 · 에픽 묶음 · 레포 설정 ──
  - id: RC30
    path: "docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md"
    anchor: "상태 칸은 없다 — 단계는 `plugins/spec-distill/scripts/roadmap_status.py` 가 git 에서 계산한다 · ## 지휘 절차 · ## 결정 기록 · ## 재분해 이력"
    line: 11
    claim: "로드맵은 추적 파일이고 frontmatter는 type: roadmap · source_brief · review_model · test_command 등이다. 에픽 블록(### R<n> — 칸: 의도 · 범위 · 의존 · 브랜치 · 묶음 · 경로 예약 · spec · 흐름 · 산출물 …), ## 지휘 절차, ## 결정 기록(「- <블록> · <결정|머지> · 날짜 · 「원문」」), ## 재분해 이력을 담는다. 상태 칸이 없고 단계는 git에서 계산한다. 쓰기는 인터뷰(roadmap_write.py)와 재분해 절차(redecompose.md) · 로드맵 수정 PR뿐이고, 읽기는 roadmap_model.py다."
    touches: []
    decides: [OQ10]
  - id: RC31
    path: "docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R5.md"
    anchor: "type: epic-bundle · epic · roadmap · source_brief · ids: […] · ## 0. 역참조"
    line: 1
    claim: "에픽 묶음은 로드맵 옆 <에픽>.md 추적 파일이다. 생성기는 roadmap_write.py · roadmap_render.py다. 배정 번호(ids) · brief 발췌 · Goal/Non-goal을 담는다. 설계 세션(지휘자 자신의 brainstorming)이 입력으로 읽고, 설계문서 frontmatter source_interview가 이 경로를 가리킨다. check_bundle_coverage.py가 설계문서 ## 번호 대조와 대조한다."
    touches: []
    decides: [OQ10]
  - id: RC32
    path: "plugins/spec-distill/references/epic-handoff.md"
    anchor: "# 에픽 넘김 줄 — 지휘자는 이 줄을 사용자에게 주지 않고 같은 내용을 자기 brainstorming 입력으로 쓴다"
    line: 3
    claim: "에픽 넘김 줄은 에픽 설계 세션에 싣는 긴 지시 한 줄이다. 묶음 첨부 · 번호 대조 · 있는 것 검토 · 상류 · 하류 연계 · spec-review 호출 등을 담는다. 지휘자가 있으면 자기 입력으로 쓰고, 없거나 사용자가 따로 진행할 때만 사용자에게 준다."
    touches: []
    decides: [OQ10]
  - id: RC33
    path: "plugins/spec-distill/scripts/repo_defaults.py"
    anchor: "SETTINGS_FILE = \".devbrew.md\" · KEYS = (\"specs_dir\", \"plans_dir\", \"roadmaps_dir\", \"interview_dir\", \"test_command\", …)"
    line: 35
    claim: "레포 설정 장치의 우선순위는 로드맵 frontmatter > 레포 루트 .devbrew.md(기본 브랜치 판) > 기본값이다. 온톨로지는 「기계 상태는 설정 층이 아니다(검사받는 하위 agent 도 쓸 수 있다)」고 적는다. 이 worktree에는 .devbrew.md 파일이 없다."
    touches: []
    decides: []

  # ── 인터뷰 state · audit ──
  - id: RC34
    path: "plugins/spec-distill/skills/pm-interview/SKILL.md"
    anchor: "## State location — 인터뷰 폴더(`interview_dir`)의 `<날짜>-<주제>-interview.state.md` — 작업 트리의 추적 파일"
    line: 126
    claim: "인터뷰 state는 작업 트리의 추적 파일이고 끝날 때 brief · audit와 함께 커밋한다. frontmatter는 session_id · phase · coverage(floor 5 + derived) · orchestration(research_dispatches · research_limit · saturation_limit · research_log · saturation_log · open_decisions[OQ<n>]) · user_statements · confirm_repost_count를 담는다. 본문은 ## 풀린 입력 · ## R<n> 라운드 기록 · 조사 원문 verbatim · ## audit §2 대기 줄이다. orchestrator가 쓰고 agent는 orchestration을 읽기만 한다. interview_state.py가 진입 판결(RESUME/ASK/LEGACY/NEW-SEED/NEW)을 낸다. control_plane statusline이 진행 중 인터뷰로 읽고, reviewing-brief는 brief_review_degradations degrade 원장으로 같은 파일에 덧붙인다(brief_review_state.py)."
    touches: []
    decides: [OQ10]
  - id: RC35
    path: "plugins/spec-distill/skills/pm-interview/references/state-file.md"
    anchor: "brief · audit 는 같은 줄기로 옆에 놓인다(`<줄기>.md` · `<줄기>.audit.md`) · ### 끝낼 때 … 상태 파일은 지우지 않는다"
    line: 3
    claim: "인터뷰 audit(<줄기>.audit.md)는 끝날 때 state의 ## audit §2 대기 줄을 글자 그대로 옮겨 받는 추적 파일이다(finishing.md). seed 리뷰의 결정 줄은 audit ## 6. 리뷰 결정에 seed_review_log.py와 엔진 --log-file로 적힌다. 락은 test_interview_state.py · test_interview_state_flow.sh · test_resume_candidate_names.sh다."
    touches: []
    decides: [OQ10]

  # ── docreview 원장 ──
  - id: RC36
    path: "shared/docreview/scripts/docreview_state.py"
    anchor: "\"\"\"docreview_state.py — 문서 리뷰 엔진의 세션 라운드 원장 … 파일은 `<state-dir>/docreview-state.md` 하나 … 상태 디렉토리는 **문서별**이다\"\"\""
    line: 2
    claim: "리뷰 원장은 <state-root>/.docreview/<stem>-<해시>/docreview-state.md다(git-ignored, 문서 단위 수명). frontmatter docreview: 트리에 라운드 · rereview_count · findings · decides · decision_log · snapshots를 담는다. 쓰는 것은 엔진 서브커맨드(init · begin-round · decide · fix · ask · defer · gate · log-decision)뿐이다. spec-review가 압축 · 재호출 뒤 「리뷰 원장이 라운드 · 상한을 잇는다」(conducting.md 걸음 3)의 근거다. 락은 shared/tests/test_docreview_state.sh 외 docreview 테스트들이다."
    touches: []
    decides: [OQ10]
  - id: RC37
    path: "plugins/spec-distill/scripts/ledger_marker.py"
    anchor: "MARKER = \"reviewing-by\" · LAST = \"last-session\""
    line: 20
    claim: "리뷰 원장에는 conducting-by와 같은 방식의 표지 reviewing-by(세션 id 한 줄)와 last-session이 있다. 리뷰 진입 블록이 라운드 시작에 acquire, 쓰기 전마다 check, 끝에 release를 부른다. conductor_state는 이 모듈의 _atomic_write · _read_line을 가져다 쓴다. 락은 test_ledger_marker.py다."
    touches: []
    decides: [OQ9]
  - id: RC38
    path: "plugins/spec-distill/scripts/ledger_sweep.py"
    anchor: "\"\"\"spec-distill — 리뷰 진입 때 한 번 도는 원장 정리 … TTL: DEVBREW_SPEC_DISTILL_TTL_HOURS(기본 24)\"\"\""
    line: 2
    claim: "리뷰 원장과 옛 세션 폴더(<state-root>/<sid>/state.local.md)의 정리는 훅이 아니라 리뷰 진입 때 도는 이 스크립트가 한다. README ## Hooks Installed는 「설치되는 훅이 없다」고 적는다. 락은 test_ledger_sweep.py다."
    touches: []
    decides: []

  # ── 압축 · 재개 · 알림 · 하니스 소통 도구 ──
  - id: RC39
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### /compact 시점 — 기록(설계문서 절)을 커밋하고 기계 상태를 저장한 뒤 두 줄을 준다 — `/compact` 와 `/spec-distill:epic-conductor <로드맵>`. 압축은 사용자만 한다. 압축 뒤에는 걸음 1 부터 한다."
    line: 84
    claim: "지휘 세션 리프레시의 현행 장치다. 지휘자가 「끊기 좋은 자리 · 맥락이 무거우면」을 판단해 /compact를 권하고, 사용자만 압축한다. 재개는 걸음 1 맞추기(git · machine.md · ListAgents · 원장)로 하고 「무엇이 끝났는지 기억에 기대지 않는다」. 문턱을 재는 스크립트 · 숫자는 이 절에 없다. 손 절차의 **/compact.**(117행)도 같은 꼴이다."
    touches: []
    decides: [OQ8, OQ11]
  - id: RC40
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "네 맥락은 가볍게 둔다 — … 맥락이 길어지면 밀려나기 전에 브랜치를 백업으로 push 하고 … 원장을 갱신한 뒤 다음 걸음을 적은 중간 보고(CHECKPOINT)로 돌려보낸다"
    line: 73
    claim: "하위(구현) agent의 맥락 관리는 이 장치가 맡는다. 과제 agent는 보고를 파일에 쓰고 짧은 상태만 돌려준다. 맥락이 길면 백업 push · 원장 갱신 · CHECKPOINT 중간 보고를 한다. 「단계마다 새 agent」 절은 계획 agent와 구현 agent를 분리하는 이유로 「한 agent 가 리뷰~계획을 이으면 맥락이 백만 토큰 가까이 커진다」를 든다."
    touches: []
    decides: [OQ8, OQ11]
  - id: RC41
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### 알림 — 사람 답이 없어 에픽이 멈췄을 때와 모두 끝났거나 더 갈 일이 없을 때만 알림 도구(`PushNotification`)를 보낸다"
    line: 87
    claim: "지휘의 하니스 소통 도구는 여섯이다. AskUserQuestion은 지휘자가 정할 질문용이다. SendMessage는 하위 agent를 깨워 잇게 하거나 상태를 물을 때 쓴다. ListAgents는 살아 있는 agent의 원천이다. TaskStop은 옛 agent의 하위를 내릴 때 쓴다. PushNotification은 멈춤 · 끝 알림용이다. 하니스 Task 목록은 show --tasks로 맞춘다. 모두 파일이 아니라 세션 안 도구이고, 기록은 남지 않는다."
    touches: []
    decides: [OQ10]
  - id: RC42
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "한 에픽의 설계 대화 … 가 도는 동안 다른 에픽의 소식 · 돌아온 질문 · 멈춤은 받은 원문을 … relay 폴더의 파일(`relay-<순번>.md`)에 적어 두기만 하고"
    line: 28
    claim: "machine.md ## 기다리는 질문(에픽 · 기대는 일 · 질문)과 relay 원문 파일이 진행 중 설계 대화를 방해하지 않는 지휘자의 inbox 역할을 한다. 걸음 2의 기계 상태 칸은 「받은 원문 파일은 `## 자원` 에 「질문 원문」 으로」라고 적는다."
    touches: []
    decides: [OQ10]

  # ── 다른 플러그인 상태 ──
  - id: RC43
    path: "CLAUDE.md"
    anchor: "런타임 state 는 `.claude/<plugin>/` 하위에 산다 … 수명은 넷이다 — 세션 단위(… 지금은 qg 다) · 문서 단위 리뷰 원장 · 로드맵 단위 지휘 기계 상태(`machine.md`) · 실행 단위 산출(plugin-audit 실행 폴더)"
    claim: "레포 규칙이 상태 수명 네 종류를 명시한다. 세션 단위는 quality-gates의 .claude/quality-gates/<sid>/(qg worktrees 포함)다. 문서 단위는 docreview 원장, 로드맵 단위는 machine.md, 실행 단위는 plugin-audit 실행 폴더다. 「인터뷰처럼 세션을 넘는 진행 기록은 docs 의 추적 파일에 두고 산출물과 함께 커밋한다」도 같은 절에 있다."
    touches: []
    decides: [OQ10]
unanswered: "(1) 레포에 INTENT.md · STATUS.md · inbox/ · HANDBOOK.md · 역할별 CLAUDE.md 같은 장치는 없다. 해당 이름은 이번 인터뷰 파일(docs/superpowers/interview/2026-11-13-conductor-context-economy-*)과 옛 기록에만 나온다. (2) 사용자 auto-memory(MEMORY.md · ~/.claude/sdd-mirror)는 레포 밖이라 조사 범위 밖이다. (3) quality-gates · plugin-audit 내부 상태는 CLAUDE.md 서술 말고는 구현을 깊이 읽지 않았다. (4) superpowers SDD progress.md의 형식 정본은 외부 플러그인에 있어 레포에서 확인하지 못했다."
```

주요 경로(절대):
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/references/conducting.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/references/conductor-dispatch.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/references/roadmap-ontology.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/scripts/conductor_state.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/scripts/conductor_ledger.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/scripts/control_plane.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/scripts/suite_lock.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/scripts/review_intents.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/scripts/merge_check.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/skills/epic-conductor/SKILL.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/agents/relay-checker.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/skills/pm-interview/SKILL.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/shared/docreview/scripts/docreview_state.py

## R5

### 지금 이해
R4 질문 둘에 직접 답함: 하위 agent 는 시작 폴더를 따로 정할 수 없고(띄운 쪽 폴더 · worktree 격리 시 그 worktree), 따로 띄운 세션은 역할 폴더에서 시작 가능하나 코드 worktree 를 따로 열어야 한다. 하위 폴더 CLAUDE.md 는 그 폴더 파일을 읽을 때 함께 실리므로 시작 묶음의 역할 파일 경로로 같은 효과. Task 는 writing-plans 계획의 「Task N」 절이고 SDD 는 이미 Task 마다 새 구현 일꾼을 쓴다(superpowers 7.0.2 subagent-driven-development SKILL 8 · 12 · 54행 「Fresh subagent per task」).
- 대체됨: R4 추천 「Task 하나마다 새 일꾼」이 새로 필요한 장치 → SDD 가 이미 Task 마다 새 일꾼을 쓰고 맥락이 쌓이는 쪽은 Task 들을 돌리는 진행 agent (본체 직접 확인 — superpowers SDD SKILL)
조사 8(repo-researcher, 묶음 5) — R5 질문과 서로 기대지 않아 함께 띄움.
- 확인 RC49 — 미확인 — plugins/spec-distill/references/roadmap-ontology.md:3 — 앵커 «주인만 쓰고» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC50 — 미확인 — plugins/spec-distill/tests/test_roadmap_ontology.py:30 — 앵커 «리뷰 원장» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC51 — 확인 — plugins/spec-distill/scripts/conductor_state.py:51 — 앵커 «RETIRED_SECTIONS» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC52 — 미확인 — plugins/spec-distill/scripts/state_path.py:73 — 앵커 «def state_root_for_common» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC53 — 확인 — plugins/spec-distill/scripts/conductor_state.py:334 — 앵커 «O_EXCL» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC54 — 미확인 — plugins/spec-distill/scripts/conductor_ledger.py:104 — 앵커 «def need_holder» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC55 — 미확인 — plugins/spec-distill/scripts/conductor_ledger.py:901 — 앵커 «def c_live_agent» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC56 — 확인 — plugins/spec-distill/references/conducting.md:16 — 앵커 «사본이다» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC57 — 미확인 — plugins/spec-distill/references/conducting.md:21 — 앵커 «로드맵 밖 일도 한 곳에» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC58 — 미확인 — plugins/spec-distill/scripts/conductor_ledger.py:867 — 앵커 «def c_flush» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC59 — 미확인 — plugins/spec-distill/scripts/roadmap_status.py:589 — 앵커 «read_pr_cache» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC60 — 미확인 — plugins/spec-distill/tests/test_conductor_state.py:43 — 앵커 «progress.md» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC61 — 미확인 — plugins/spec-distill/scripts/conductor_ledger.py:168 — 앵커 «FILE_KINDS» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC62 — 확인 — plugins/spec-distill/references/conductor-dispatch.md:32 — 앵커 «relay-<번호>.md» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC63 — 미확인 — plugins/spec-distill/agents/relay-checker.md:14 — 앵커 «tools: Read, Grep, Glob» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC64 — 미확인 — plugins/spec-distill/references/conducting.md:51 — 앵커 «--kind report» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC65 — 확인 — plugins/spec-distill/references/conductor-dispatch.md:11 — 앵커 «--kind tmp» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC66 — 미확인 — plugins/spec-distill/scripts/suite_lock.py:37 — 앵커 «BUSY_RC = 75» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC67 — 미확인 — plugins/spec-distill/scripts/repo_defaults.py:23 — 앵커 «SDD_WORKSPACE» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC68 — 확인 — plugins/spec-distill/references/conducting.md:17 — 앵커 «완료 표시는 일이 끝났다는 뜻이 아니다» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC69 — 미확인 — plugins/spec-distill/scripts/roadmap_model.py:657 — 앵커 «RECORD_HEADING» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC70 — 미확인 — plugins/spec-distill/references/conducting.md:53 — 앵커 «허가 없이 바뀜» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC71 — 확인 — plugins/spec-distill/references/conducting.md:3 — 앵커 «## 지휘 순환» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC72 — 미확인 — plugins/spec-distill/scripts/conductor_ledger.py:1193 — 앵커 «def c_review_pack» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC73 — 확인 — plugins/spec-distill/references/conductor-dispatch.md:13 — 앵커 «Spec: <설계문서» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC74 — 미확인 — plugins/spec-distill/scripts/review_intents.py:2 — 앵커 «intents.md» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC75 — 미확인 — plugins/spec-distill/scripts/merge_check.py:15 — 앵커 «하위 agent 도 쓸 수 있다» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC76 — 미확인 — plugins/spec-distill/scripts/control_plane.py:765 — 앵커 «def cache_file» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC77 — 미확인 — plugins/spec-distill/README.md:179 — 앵커 «control-plane-statusline:begin» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC78 — 미확인 — docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md:151 — 앵커 «재분해 이력» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC79 — 미확인 — docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R5.md:2 — 앵커 «type: epic-bundle» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC80 — 미확인 — plugins/spec-distill/references/epic-handoff.md:1 — 앵커 «에픽 넘김 줄» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC81 — 미확인 — plugins/spec-distill/scripts/repo_defaults.py:35 — 앵커 «SETTINGS_FILE» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC82 — 미확인 — plugins/spec-distill/skills/pm-interview/SKILL.md:126 — 앵커 «## State location» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC83 — 미확인 — plugins/spec-distill/skills/pm-interview/references/state-file.md:79 — 앵커 «상태 파일은 지우지 않는다» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC84 — 미확인 — shared/docreview/scripts/docreview_state.py:6 — 앵커 «docreview-state.md» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC85 — 미확인 — plugins/spec-distill/scripts/ledger_marker.py:2 — 앵커 «reviewing-by» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC86 — 미확인 — plugins/spec-distill/scripts/ledger_sweep.py:15 — 앵커 «DEVBREW_SPEC_DISTILL_TTL_HOURS» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC87 — 확인 — plugins/spec-distill/references/conducting.md:85 — 앵커 «압축은 사용자만 한다» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC88 — 확인 — plugins/spec-distill/references/conductor-dispatch.md:73 — 앵커 «CHECKPOINT» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC89 — 확인 — plugins/spec-distill/references/conducting.md:88 — 앵커 «PushNotification» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC90 — 확인 — plugins/spec-distill/references/conducting.md:28 — 앵커 «relay-<순번>.md» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC91 — 확인 — CLAUDE.md:70 — 앵커 «수명은 넷이다» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
조사 호출 7/60 · 이 라운드 본체 직접 1
사실로 보고 직접 답한 질문 2개 — 역할 폴더에서 세션 시작 · Task 의 정체

### 다음 결정
OQ8: 구현 진행 agent 교대 시점 · 추천: 문턱 넘으면 다음 Task 경계에서 · 트레이드오프: Task N개마다=예측 쉬움 / 에픽 끝까지=지금
OQ11: 지휘 세션 리프레시 · 추천: 자동 압축 + 시작 훅 복원 · 트레이드오프: 새 세션 교대=하위 agent 알림 끊김 / 사용자=지금
OQ9: 스크립트 강제 범위 · 추천: 순서 · 숫자는 스크립트, 단계 안은 모델

### 질문
(b) 진행 agent · (b) 지휘 세션 · (b) 스크립트 범위

### 답
→ S12 (OQ8 — 새로 만들지 말고 기존 장치에 맡김, 처음 생각은 에픽 대상) · S13 (OQ11 사용자가) · S14 (OQ9 권장)

## R6

### 지금 이해
R5 답 반영: 진행 agent 교대는 기존 장치에 맡김, 과제 = 에픽(S12 의 읽기 — 확인 질문 R7), 지휘 세션은 사용자 /compact, 순서 · 숫자는 스크립트. 조사 8 의 장치 43개를 새 용어와 겹침 표로 보임(INTENT ↔ 에픽 묶음 + 설계문서 결정 · 지휘 기록, STATUS ↔ machine.md + control_plane, inbox ↔ relay + 기다리는 질문, 결과 파일 ↔ report 폴더, 단계표 ↔ conducting.md, MEMORY → HANDBOOK 없음, 현황 ↔ 상태줄 → mod).
조사 호출 7/60 · 이 라운드 본체 직접 1

### 다음 결정
OQ10 갈아타기 · OQ12 INTENT.md · OQ13 STATUS.md · OQ14 절차서

### 질문
(b) 넷 묶음

### 답
→ S15 (OQ10 「1」 + 「프레이밍에서 바꾼 거 있어?」 질문 — R7 에서 답하고 확인) · S16 (OQ12 「1」 + 「어떤 영향?」 질문 — R7 에서 답하고 확인) · S17 (OQ13) · S18 (OQ14) · S19 (턴 중 새 요청: 세션 간 대화 수단을 이미 있는 것에서 더 조사 → 조사 9, OQ15)

## R7

### 지금 이해
R6 의 두 질문에 직접 답함 — 프레이밍 대비 바뀐 넷(되읽기 보증 → 산출물 대조 · 리프레시 새 장치 없음 · 토큰은 품질 신호 · 작은 일 가볍게), INTENT.md 영향(묶음 소비 스크립트 5 · 테스트 5 · source_interview · --bundle · 지휘 기록 파서 · 단계 계산). 조사 9 진행 중.
조사 호출 8/60 · 이 라운드 본체 직접 1
사실로 보고 직접 답한 질문 2개 — 프레이밍 대비 바뀐 것 · INTENT.md 영향

### 다음 결정
바뀐 넷 받기 · OQ12 INTENT.md 범위 · 과제 = 에픽 확인

### 질문
(b) 셋 묶음

### 답
→ S20 (바뀐 넷 그대로 받음 「1」 + 「파일 구조는 어떻게 되는데」) · S21 (OQ12 묶음 + 지휘 기록까지 「1」 + 「superpowers 같은 다른 플러그인과의 호환은?」) · S22 (과제 = 에픽 맞다)

### 조사 9 — open-researcher · R7 · 묶음 6

요약: S9(git 편지함이 정본 + 세션 안 감시자) 자리를 통째로 가져다 쓸 수 있는 «다른 기계 + API 키만 + 쉬는 세션 깨우기 + 확인 · 스레드 + 영속 + 런타임 추가 없음»을 모두 갖춘 기존 도구는 찾지 못했다. 후보는 크게 넷이다.
(a) Channels(MCP 채널) 위의 버스: peerbus · NATS 계열 · claude-peers 포크 · Slack 커뮤니티 채널. 미는 길이 있지만 연구 미리보기에 기대고, 허용 목록 밖이라 `--dangerously-load-development-channels` 가 필요하며, 인증 조건이 출처마다 다르다.
(b) 폴링 MCP 메일 서버: mcp_agent_mail. 확인 · 스레드 · 영속은 가장 풍부하다. 다만 서버가 상주해야 하고 미는 길이 없다.
(c) git 기반: Thrum · Beads · claude-coordinator. S9 와 거의 같은 꼴이고, 기계 간 기능 일부가 유료(계획)이거나 폴링에 의존한다.
(d) 가벼운 알림 층: ntfy. 단독 정본으로는 약하고(캐시 기본 12시간), S9 의 «알림 층»만 바꾸는 조합 후보다.
A2A 와 Agent Client Protocol 은 Claude Code 세션을 받는 쪽으로 만드는 기존 길이 확인되지 않았다.

```yaml
evidence:
  # --- 비교 기준 위에 얹히는 공통 사실 (Channels 기반 후보 전부에 걸림) ---
  - url: "https://code.claude.com/docs/en/channels"
    supports: current
    claim: "공식 문서: Channels 는 연구 미리보기이고 'claude.ai or a Console API key' 인증이 필요하다. --channels 는 Anthropic 허용 목록(claude-plugins-official 의 Telegram · Discord · iMessage · fakechat)만 받는다. 목록 밖 서버는 --dangerously-load-development-channels 가 필요하고, 조직은 Team/Enterprise 의 allowedChannelPlugins 로만 목록을 바꿀 수 있다. Console API 키 조직은 managed settings 를 배포하지 않으면 기본 허용이다. 또 'On the v2 MCP client runtime ... Claude Code doesn't register a channel server that negotiates protocol revision 2026-07-28' 라고 적혀 있다. 이 때문에 아래 제3자 채널 후보는 모두 이 미리보기 · 개발 플래그 조건을 물려받는다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "claude-code 2.1.303 (plugins/*/dependencies.md 잰 판)", latest: "확인 안 함"}
    certainty: confirmed
  - url: "https://github.com/louislva/claude-peers-mcp"
    supports: alternative
    claim: "[충돌 — 공식 문서와 어긋남] claude-peers README 는 'claude.ai login (channels require it — API key auth won't work)' 라고 적는다. 같은 취지를 RichelynScott 포크 README, nats-channel-mcp, repowire(PyPI 설명), jeremylongshore Slack 채널 README 도 적는다. 공식 Channels 문서는 Console API 키도 된다고 적는다. 어느 쪽이 현재 판에서 맞는지는 실측하지 않았다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain

  # --- 후보 1: MCP 기반 agent 메일 서버 ---
  - url: "https://github.com/Dicklesworthstone/mcp_agent_mail_rust"
    supports: alternative
    claim: "mcp_agent_mail(Rust 판) 개요: (1) 도달은 끌어오기다 — fetch_inbox · resource://inbox/{Agent}. 감시자용으로 fetch_inbox_events 가 있는데, README 는 이를 'a durable, recipient-scoped delivery feed for monitors' 라고 부르고 CLI 는 am inbox-events 다. README 에 Claude Code 훅 · 쉬는 세션 깨우기 언급은 없다. (2) acknowledge_message · mark_message_read · get_message_delivery_receipt · ack_required · am acks pending/overdue · thread_id 가 있다. 신원은 register_agent 이름(README 표현 'ephemeral by design')이고, v0.3.39 부터 MESSAGING_SESSION_IDENTITY 로 세션에 묶을 수 있다(opt-in). (3) Streamable HTTP 127.0.0.1:8765 에 bearer/JWT 다. 원격은 '--host 0.0.0.0' 과 토큰 설정을 하라고 할 뿐, 여러 기계 구성은 문서화돼 있지 않다. Claude 로그인 조건은 없다(MCP 도구라서). (4) 'SQLite for live state, Git for the durable ledger'. (5) 단일 바이너리 · 서버 상주 필요, 라이선스 'MIT+Rider'(라이더 본문 미확인), 최신 v0.3.40(2026-11-01), 253 stars. (6) MCP 표준이라 도구 종속은 낮지만, 서버 하나가 모든 기계의 단일 도달점이 된다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "레포 미사용", latest: "v0.3.40 (2026-11-01)"}
    certainty: confirmed
  - url: "https://github.com/Dicklesworthstone/mcp_agent_mail"
    supports: alternative
    claim: "Python 원판은 'no longer maintained; use the Rust version for new installs' 이다. 설치는 Python 3.14 + uv 다(레포 dependencies.md 의 python 최소 판은 3.9.6). 2.2k stars. 도달은 끌어오기(fetch_inbox, unread_only, read_ts/ack_ts)이고, 문서의 훅은 git pre-commit 예약 가드뿐이다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "레포 미사용", latest: "유지보수 중단 · PyPI 0.1.0 만 보임"}
    certainty: confirmed
  - url: "https://glama.ai/mcp/servers/@Dicklesworthstone/mcp_agent_mail/blob/caf48261b892b2a2071f9f59a119152b70b91ffb/scripts/hooks/check_inbox.sh"
    supports: alternative
    claim: "[2차 · 옛 커밋 미러] mcp_agent_mail 에 Claude Code PostToolUse(Bash matcher) 훅 scripts/hooks/check_inbox.sh 가 있었다. 속도 제한이 걸려 있고, 안 읽은 글이 있을 때만 한 줄 알린다. 훅이라 도구가 돌아야 보이므로 쉬는 세션은 깨우지 못한다. 현재 판에 남아 있는지는 확인하지 못했다."
    touches: []
    decides: [OQ15]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain

  # --- 후보 2: Channels 위의 기계 간 버스 (플러그인 · MCP) ---
  - url: "https://github.com/nnemirovsky/peerbus"
    supports: alternative
    claim: "peerbus 개요: (1) MCP claude/channel 어댑터다. README 는 'push-wake that creates a turn in an idle session (no polling)' 라고 하며, --dangerously-load-development-channels server:peerbus 로 띄운다. (2) 수신자마다 따로 ack 하고, 최소 1회 전달 · 재연결 때 재전달 · 보낸 쪽별 FIFO 를 준다. 신원은 bearer 토큰에 묶인 peer 이름 + HMAC-SHA256 종단 서명이다. 스레드는 문서에 없다. (3) WebSocket 브로커(ws://broker-host:47821)라 기계 간이 되고, TLS 언급은 없다. (4) 브로커 SQLite WAL 큐에 'persisted before any delivery attempt' 이고, blake3 해시 사슬 감사 로그가 있다. (5) Go 단일 바이너리이고 브로커를 상주 서비스로 돌려야 한다. MIT, 1 star, 릴리스 없음, 26 commits. (6) Channels 미리보기에 종속된다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://github.com/louislva/claude-peers-mcp"
    supports: alternative
    claim: "claude-peers-mcp(원판) 개요: 채널로 밀어 넣지만 'Everything is localhost-only'(브로커 localhost:7899)이고 SQLite(~/.claude-peers.db)에 둔다. ack · 스레드는 없다. 런타임은 Bun, MIT, 2.2k stars, 릴리스 없음, main 7 commits. 기계 간은 원판 범위 밖이다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://cdn.jsdelivr.net/npm/claude-peers@0.8.3/README.md"
    supports: alternative
    claim: "npm claude-peers 0.8.3 은 RichelynScott/claude-peers-mcp 포크다. LAN federation · mDNS · TLS/PSK/HMAC 를 더해 'across your LAN' 에서 기계 간이 된다. 로컬 통신은 bearer 토큰이다. 채널 푸시는 claude.ai 로그인이 필요하다고 적는다. 인터넷 너머(같은 LAN 이 아닌 서버) 구성은 문서에 없다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://github.com/exadev/agent-comms"
    supports: alternative
    claim: "agent-comms(자기 레포가 플러그인 마켓플레이스) 개요: (1) cc-peer 가 'Claude Code's own local cross-session peer protocol — a per-session Unix socket' 으로 붙는다. crossSessionInbound=accept(Claude Code 2.1.224+)가 아니면 보류된다. 다른 길로 ~/.agents/bus/pending/ 파일 + 훅 + asyncRewake 로 쉬는 세션을 깨운다. (2) delivered · read 영수증이 peer 사이에 전파되고, ECDSA P-256 키로 peer ID 를 준다. 스레드 언급은 없다. (3) LAN UDP 비컨 또는 중계 허브 wss://mesh.exadev.io/(E2E 암호, 고정 device ID)이고, 자체 호스팅 허브 문서는 확인하지 못했다. (4) 메시 상태는 메모리이고, 미전달 이벤트는 복제 큐에서 재생된다. durable 로그는 opt-in 이다. (5) Node(npx), MIT, 37 stars, 릴리스 표기 없음. 검색 2차 자료는 v1·v2 브리지가 서로 못 통한다고 적는다(미확인)."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://github.com/prassanna-ravishankar/repowire"
    supports: alternative
    claim: "repowire 개요: Claude Code 에는 'hooks plus MCP, with its authenticated native session inbox for delivery' 로 닿는다. 채널 길은 experimental opt-in 이다. ask 에는 명시 ack 답과 스레드가 닫힐 때까지 리마인더 주입이 붙고, 스레드는 git 커밋 trailer 에 기록된다. 상태는 ~/.repowire/state.db 다. 기본 흐름에 tmux 와 Claude Code 2.1.224+ 가 필요하고 Go 데몬이 127.0.0.1:8377 에 뜬다. MIT, 273 stars. [충돌] README 는 'Agents on different machines do not message each other' 이고 중계는 원격 대시보드용이라는데, PyPI 설명은 선택 hosted relay 가 'cross-machine mesh traffic' 을 나른다고 적는다. 자체 호스팅 중계도 출처마다 다르다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain

  # --- 후보 3: 경량 pub/sub ---
  - url: "https://docs.ntfy.sh/subscribe/api/"
    supports: both
    claim: "ntfy 구독은 '<topic>/json' 한 줄 JSON 스트림 · SSE · raw · WebSocket(/ws)이고, since=(기간 · 시각 · 메시지 ID · all)로 캐시분을 다시 받는다. poll=1 은 한 번 읽고 닫는다. 보호 토픽은 basic auth 또는 auth 파라미터를 받는다. 한 줄씩 나오는 스트림이라 기존 Monitor(줄마다 알림)나 asyncRewake 훅에 그대로 물릴 수 있다는 것은 이 조사의 추론이고, 문서가 말하는 것은 아니다. 기존 ntfy MCP 서버들(cyanheads 등)은 보내기 위주라 Claude Code 로 받아 들이는 기성 서버는 찾지 못했다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://docs.ntfy.sh/config/"
    supports: current
    claim: "ntfy 기본 cache-duration 은 12h 이다. 'keeps messages in-memory for 12 hours' 이고 cache-file/database-url 이 없으면 재시작에서 사라진다. 기본은 누구나 읽기 · 쓰기이고, 비공개 운영은 auth-default-access deny-all 이 권장이다. 액세스 토큰(tk_)은 토픽 범위가 아니라 계정 전체 권한이다. ack · 스레드 개념은 없다. 그래서 단독 정본이 아니라 알림 층 후보다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://github.com/binwiederhier/ntfy/releases"
    supports: both
    claim: "ntfy 최신 v2.37.2(2026-11-04), Apache-2.0/GPLv2 이중 라이선스, Go, 35.5k stars. 공개 서버 ntfy.sh 를 쓰거나 자체 호스팅할 수 있다. ntfy.sh 의 보존 기간은 문서에서 확인하지 못했다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "레포 미사용", latest: "v2.37.2 (2026-11-04)"}
    certainty: confirmed
  - url: "https://github.com/Piotr1215/agents-mcp-server"
    supports: alternative
    claim: "NATS 위 agent 간 메시징이다. --dangerously-load-development-channels server:agents 일 때 채널로 민다. 이력은 JetStream 'agents-history'(30일 · 512MiB)이고 등록 상태는 메모리뿐이다. 'This server does not authenticate HTTP callers', 'A name or MCP session ID does not authenticate a user' 이고 ack · 스레드는 없다. Node 18+, MIT, 1 star. NATS 서버 상주가 필요하다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://github.com/except-pass/nats-channel-mcp"
    supports: alternative
    claim: "NATS→채널 다리다. --jetstream 이면 꺼진 동안 온 글을 버퍼에 쌓았다가 재연결 때 준다. 다만 'Pauses longer than 1h lose messages' 이고, 'NATS auth not implemented', 'For now: local NATS only' 다. Bun, 0 stars. 기계 간 정본으로는 아직 해당 없음."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://pypi.org/project/mcmqtt/"
    supports: alternative
    claim: "[2차 · 검색 요약] MQTT MCP 서버들(mcmqtt · mqtt-mcp · mqtt-mcp-server)은 백그라운드로 구독해 캐시를 도구로 조회하는 끌어오기 방식이다. 쉬는 세션으로 미는 기성 MQTT 서버는 찾지 못했다. Redis Streams 계열(agent-walkie-talkie · agent-rtc · swarmcode · gptqueue 등)도 소규모 커뮤니티 프로젝트로만 보였다. 1차로 확인하지 않았다."
    touches: []
    decides: [OQ15]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain

  # --- 후보 4: 채팅 브리지 (공식 Channels 플러그인 포함) ---
  - url: "https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/external_plugins/discord/server.ts"
    supports: current
    claim: "공식 Discord 채널 플러그인 코드는 'if (msg.author.bot) return' 으로 봇이 쓴 글을 버린다. 그래서 지휘자 A 의 봇이 쓴 글이 지휘자 B 세션에 닿지 않는다. 길드 채널은 requireMention 기본 true 다. 이력 조회는 fetch_messages 이고 호출당 100건 상한이다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/external_plugins/telegram/server.ts"
    supports: alternative
    claim: "공식 Telegram 채널 플러그인은 is_bot 으로 걸러 내지 않고 그룹도 지원한다(access.groups 등록, requireMention 기본 true, 그룹에는 권한 중계 제외). 그러나 Telegram 플랫폼 쪽에서 봇은 원래 다른 봇의 글을 받지 못한다. 예외는 새 Bot-to-Bot Communication Mode(아래)다. 두 지휘자 봇이 서로 글을 주고받으려면 그 모드를 켜야 하고, 이 조합을 실측하지는 않았다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://core.telegram.org/api/bots/bot-to-bot"
    supports: alternative
    claim: "Telegram 봇 간 수신 조건은 '/command@TargetBot' 멘션이나 그 봇 글에 대한 직접 답장이고, 'At least one of the two bots must have Bot-to-Bot Communication Mode enabled' 이다. 모드를 켠 봇이 관리자이면서 Group Privacy 를 끄면 멘션 없이도 받는다. 도입 날짜는 페이지에 없다. 2차 블로그는 2026-05-07 이라고 적는데 미확인이다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://jeremylongshore.github.io/claude-code-slack-channel/"
    supports: alternative
    claim: "[2차 · 검색 요약] 공식 Slack 채널 플러그인은 없다. 커뮤니티 Slack 채널(Socket Mode, 공개 URL 불필요) 여럿이 있고, README 가 Claude Code 2.1.80+ 와 claude.ai 로그인을 요구한다고 한다. 허용 목록 밖이라 개발 플래그 조건을 물려받는다. 봇 간 글 처리는 확인하지 못했다."
    touches: []
    decides: [OQ15]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain

  # --- 후보 5: git · GitHub 기반 기존 도구 (S9 와 같은 꼴) ---
  - url: "https://github.com/thrum-team/thrum"
    supports: both
    claim: "Thrum 개요: (1) 메시지는 'dedicated orphan branch' 의 JSONL, 상태는 SQLite, 'Sync is plain Git'(또는 Tailscale 실시간 P2P)이다. Claude Code 플러그인(claude plugin marketplace add … / install thrum)이 slash 명령 · 'automatic context injection, hooks, and startup scripts' 를 준다. 2차 검색 요약은 SessionStart · PreCompact 에 thrum prime 주입, thrum wait(기본 30초, 재무장)를 적는다(현 판에서 미확인). (2) reply 로 스레드, 웹 UI 에서 클릭하면 읽음 처리, 'each worktree gets its own identity'. 전달 확인은 문서에 없다. (3) git 원격만 있으면 된다. Claude 로그인 조건 언급은 없다. (4) git 에 영속. (5) Go 단일 바이너리(CLI · 데몬 · 웹 UI · 선택 MCP), MIT, 28 stars, 최신 v0.10.6 · v0.10.7-rc.2(6월, 연도 미표기). (6) S9 와 거의 같은 구조의 기성품이다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://thrum.team/pricing.html"
    supports: current
    claim: "Thrum 은 Free/Pro(계획가, $15/월, 'Buying opens soon') 두 등급이다. Pro 에 'advanced features for sharing between your paired machines' 가 들어 있어 기계 간 기능 일부가 유료일 수 있다. 정확한 경계는 확인하지 못했다. EULA 링크가 있고, 라이선스 확인 때 하루 한 번 my.thrum.team 과 통신한다. 알림 페이지는 tmux 에서 돌리는 agent 가 터미널 한 줄 알림을 받는다고 적는다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://pypi.org/project/claude-coordinator/"
    supports: both
    claim: "claude-coordinator 0.5.45(2026-08-12)는 GitHub 이슈 댓글을 'the durable message bus' 로 쓰고 로컬 SQLite 와 서로 재구성한다. 세션에 미는 길은 없다. 'nothing advances on its own' 이라 cron · TUI 타이머(60초)로 coord notify 를 돌린다. 기계 간은 Tailscale 위 coord agent(7433)다. Python 3.12+, 라이선스 FSL-1.1-MIT(유예 뒤 MIT 로 바뀌는 소스 공개 라이선스)."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://github.com/steveyegge/beads"
    supports: both
    claim: "[2차 · 검색 요약] Beads(bd)는 git 기반 이슈 추적기다(.beads/issues.jsonl 정본 + SQLite 캐시, 내용 해시 ID 로 충돌 회피, 기계 간은 git push/pull). 메시징 · 알림 기능은 확인하지 못했다. 편지함이 아니라 공유 작업 원장 후보다."
    touches: []
    decides: [OQ15]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain

  # --- 후보 6: 표준 프로토콜 ---
  - url: "https://a2a-protocol.org/latest/specification/"
    supports: current
    claim: "A2A 1.0.0 사양 개요: JSON-RPC · gRPC · HTTP+JSON/REST 바인딩이 있다. 작업 상태는 submitted → working → input-required/auth-required → completed/failed/canceled/rejected 다. 비동기 갱신은 클라이언트가 등록한 webhook 으로 HTTP POST 한다(pushNotifications capability). 인증은 Agent Card 보안 스킴이고, contextId 로 대화를 묶는다. 다만 'Messages MUST NOT be considered a reliable delivery mechanism', 그리고 무엇을 남길지는 agent 가 정한다. 받는 쪽은 HTTP 서버로 늘 떠 있어야 하는 구조다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "레포 미사용", latest: "v1.0.1 (2026-05-28 릴리스, changelog 2026-05-26)"}
    certainty: confirmed
  - url: "https://github.com/TonPC64/mcp-a2a-bridge"
    supports: current
    claim: "A2A↔Claude Code 다리는 기존 것이 내보내기(outbound) 위주다(TonPC64/mcp-a2a-bridge: 원격 A2A agent 호출 + 작업 폴링). Claude Code 세션을 A2A 서버로 세워 받는 예는 문서에 없다(Codex · Copilot 어댑터만 127.0.0.1). 0 stars, MIT, Python 3.11+uv. GongRzhe/A2A-MCP-Server · a2anet/a2a-mcp 등도 검색 요약상 같은 내보내기 꼴이다(2차)."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://agentclientprotocol.com/overview/introduction"
    supports: current
    claim: "Agent Client Protocol 은 'standardizes communication between code editors/IDEs and coding agents' 이다(로컬은 stdio JSON-RPC, 원격은 'work in progress'). agent 간 · 세션 간 메시징을 다루지 않아 OQ15 의 수단이 아니다. IBM 의 Agent Communication Protocol 은 이름이 같은 다른 것으로, A2A 에 흡수됐다고 2차 자료가 적는다."
    touches: []
    decides: [OQ15]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
repo_claims:
  - id: RC1
    path: "plugins/spec-distill/dependencies.md"
    anchor: "| claude-code | 2.1.303 | 2026-10-22 | 기록 | 잰 판을 기록만 한다 |"
    claim: "레포가 잰 Claude Code 판은 2.1.303 이다(기록 강도). 후보들이 요구하는 하한(채널 2.1.80+, crossSessionInbound · repowire 2.1.224+)보다 높다. 같은 표의 python 최소 판은 3.9.6 이다. 이 표에 Bun · Node · Go 런타임 항목은 없다. 그래서 Bun 채널 플러그인 · Node · Python 3.14(mcp_agent_mail 원판)를 쓰는 후보는 새 의존 행을 더해야 한다."
    touches: []
    decides: [OQ15]
  - id: RC2
    path: "plugins/"
    anchor: "Grep '\"monitors\"|asyncRewake|CLAUDE_CODE_MESSAGING' 와 'mcpServers' — 0건"
    claim: "어느 플러그인도 지금 plugin monitor · asyncRewake 훅 · 네이티브 세션 받은 편지함 소켓 · MCP 서버(mcpServers)를 쓰지 않는다. S9 의 감시자나 MCP 기반 후보 중 무엇을 고르든 이 레포에는 새 표면이다."
    touches: []
    decides: [OQ15]
  - id: RC3
    path: "docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md"
    anchor: "{id: S9, source: chosen, round: 4, text: \"편지함 + 세션 안 감시자 (권장) — ...\"}"
    claim: "비교 기준인 S9 는 «git 원격 편지함이 정본 + 지휘자 세션의 감시자(monitor·훅)가 알림 + 시작 훅이 밀린 글을 읽음»이다. 같은 파일의 조사 6 주장은 Monitor 기한(기본 5분 · 최대 30분, resume 때 재시작 안 함)과 asyncRewake 종료 코드 2 로 idle 깨우기를 적어 둔다. 이번 후보 중 agent-comms 의 파일 경로와 repowire 가 바로 이 asyncRewake · 네이티브 세션 받은 편지함 구성 요소를 쓰는 기성 구현이다."
    touches: []
    decides: [OQ15]
unanswered: "다음은 확인하지 못했다. (1) Channels 의 Console API 키 허용 여부가 공식 문서와 제3자 README 사이에서 충돌하는데 실측하지 않았다. (2) Thrum 의 현 판 훅 이름 · 기계 간 기능 중 유료 경계 · 문서 사이트 일부(leonletto.github.io 하위)가 404 였다. (3) agent-comms 중계 허브의 자체 호스팅 가능 여부. (4) repowire 기계 간 메시징 지원 여부가 README 와 PyPI 사이에서 충돌한다. (5) mcp_agent_mail Python 원판 라이선스와 현 판에 check_inbox.sh 훅이 남아 있는지. (6) ntfy.sh 공개 서버의 보존 기간. (7) 공식 Telegram 플러그인으로 두 봇이 Bot-to-Bot 모드에서 실제로 서로 받는지 실측. (8) pinax-network/agent-bus · mlopresti/nats-mcp-server 는 404 로 1차 확인을 못 했다."
```

Sources:
- [mcp_agent_mail](https://github.com/Dicklesworthstone/mcp_agent_mail) · [mcp_agent_mail_rust](https://github.com/Dicklesworthstone/mcp_agent_mail_rust) · [mcp_agent_mail_rust releases](https://github.com/Dicklesworthstone/mcp_agent_mail_rust/releases) · [PyPI mcp-agent-mail](https://pypi.org/project/mcp-agent-mail/) · [check_inbox.sh 미러(2차)](https://glama.ai/mcp/servers/@Dicklesworthstone/mcp_agent_mail/blob/caf48261b892b2a2071f9f59a119152b70b91ffb/scripts/hooks/check_inbox.sh)
- [Claude Code Channels](https://code.claude.com/docs/en/channels) · [Discord plugin server.ts](https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/external_plugins/discord/server.ts) · [Discord plugin](https://github.com/anthropics/claude-plugins-official/tree/main/external_plugins/discord) · [Telegram plugin server.ts](https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/external_plugins/telegram/server.ts) · [Telegram bot-to-bot](https://core.telegram.org/api/bots/bot-to-bot) · [Telegram Bots FAQ](https://core.telegram.org/bots/faq)
- [peerbus](https://github.com/nnemirovsky/peerbus) · [claude-peers-mcp](https://github.com/louislva/claude-peers-mcp) · [claude-peers 0.8.3 README(포크)](https://cdn.jsdelivr.net/npm/claude-peers@0.8.3/README.md) · [agent-comms](https://github.com/exadev/agent-comms) · [repowire](https://github.com/prassanna-ravishankar/repowire) · [repowire PyPI](https://pypi.org/project/repowire/)
- [ntfy subscribe API](https://docs.ntfy.sh/subscribe/api/) · [ntfy config](https://docs.ntfy.sh/config/) · [ntfy repo](https://github.com/binwiederhier/ntfy) · [ntfy releases](https://github.com/binwiederhier/ntfy/releases) · [cyanheads ntfy-mcp-server(2차)](https://mcpservers.org/servers/cyanheads/ntfy-mcp-server)
- [agents-mcp-server](https://github.com/Piotr1215/agents-mcp-server) · [nats-channel-mcp](https://github.com/except-pass/nats-channel-mcp) · [mcmqtt(2차)](https://pypi.org/project/mcmqtt/) · [claude-code-slack-channel(2차)](https://jeremylongshore.github.io/claude-code-slack-channel/)
- [Thrum repo](https://github.com/thrum-team/thrum) · [Thrum releases](https://github.com/thrum-team/thrum/releases) · [Thrum messaging](https://thrum.team/docs/use-thrum/messaging-between-agents.html) · [Thrum pricing](https://thrum.team/pricing.html) · [claude-coordinator](https://pypi.org/project/claude-coordinator/) · [beads(2차)](https://github.com/steveyegge/beads) · [InfoWorld GitHub issues 글(2차)](https://www.infoworld.com/article/4224587/the-agent-coordination-protocol-hiding-in-plain-sight-github-issues.html)
- [A2A spec](https://a2a-protocol.org/latest/specification/) · [A2A releases](https://github.com/a2aproject/A2A/releases) · [LF A2A 보도자료(2차)](https://www.linuxfoundation.org/press/a2a-protocol-surpasses-150-organizations-lands-in-major-cloud-platforms-and-sees-enterprise-production-use-in-first-year?hsLang=en) · [mcp-a2a-bridge](https://github.com/TonPC64/mcp-a2a-bridge) · [Agent Client Protocol](https://agentclientprotocol.com/overview/introduction) · [Zed: Claude Code via ACP(2차)](https://zed.dev/blog/claude-code-via-acp)

레포 경로:
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/dependencies.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md

### 조사 10 — open-researcher · R8 · 묶음 7

## 요약

조사 대상은 세 묶음과 이 레포가 superpowers 에 묶인 자리다. 확인한 날은 모두 2026-11-14 이다.

주문에 적힌 전제와 1차 자료가 어긋나는 곳이 세 군데 있다.

1. **pstack 의 Claude Code 설치 경로.**
   - 주문 전제: 「공식은 Cursor 용, Claude Code 용은 커뮤니티 포팅」.
   - 공식 README(cursor/plugins/pstack): Claude Code 설치 명령 `/plugin marketplace add cursor/plugins` · `/plugin install pstack@cursor-plugins` 를 직접 싣는다.
   - 커뮤니티 포팅(michael-denyer/pstack-claude)도 따로 있다.
2. **pstack 의 skill 이름.**
   - 주문 전제: plan · execute · research · pr 라는 skill.
   - 실제로는 그런 이름의 skill 이 없다. 라우터 skill `poteto-mode` 와 플레이북 23개(`multi-phase-plan` · `feature` · `investigation` · `opening-a-pr` 등)가 그 자리를 맡는다.
   - README 원문은 "i don't believe in planning" 이고, 기본으로 계획 skill 이 없다고 쓴다.
3. **사람이 직접 불러야 하는 skill.**
   - Matt Pocock 의 사용자 호출 skill 들(to-spec · to-tickets · implement · implement-spec · grill-me · grill-with-docs)과 pstack 의 `poteto-mode` · `figure-it-out` 은 frontmatter 에 `disable-model-invocation: true` 를 단다.
   - Claude Code 공식 문서상 이 표시가 있으면 모델이 Skill 도구로 부를 수 없고, subagent 에 미리 실을 수도 없다.
   - superpowers skill 들에는 이 표시가 없다(설치본에서 확인).

이 레포의 판:
- `plugins/spec-distill/dependencies.md` 가 적은 superpowers 검증 판은 7.0.0 이다(잰 날 2026-10-22).
- 설치본 캐시는 7.0.2 이고, upstream 최신도 v7.0.2(11월 3일)다.

```yaml
evidence:
  # ── superpowers ──
  - url: "https://github.com/obra/superpowers/releases"
    supports: current
    claim: "superpowers 최신 릴리스는 v7.0.2(11월 3일)다. 그 앞은 v7.0.1(10월 21일), v7.0.0(10월 10일)이다. 설치본 plugin.json 은 version 7.0.2 · license MIT · 저자 Jesse Vincent 이다(~/.claude/plugins/cache/claude-plugins-official/superpowers/7.0.2/.claude-plugin/plugin.json 을 직접 읽음)."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "7.0.0 (dependencies.md 검증 판) · 설치본 7.0.2", latest: "7.0.2"}
    certainty: confirmed
  - url: "https://github.com/obra/superpowers (설치본 skills/brainstorming/SKILL.md 7.0.2)"
    supports: current
    claim: "brainstorming 의 입력은 대화와 레포다. 산출은 설계문서 `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` 이고 커밋한다. 원문은 'Your human partner's preferences override both' 로, 경로는 설정 키가 아니라 사람의 선호로 바꾼다. 묻는 자리는 접근 방식 고르기와 설계문서 승인(HARD-GATE)이다. 승인 뒤에는 'invoke superpowers:writing-plans and no other skill' 로 다음 skill 을 스스로 부른다. 프로젝트 크기의 일이면 builder-check subagent 를 하나 띄운다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "7.0.0", latest: "7.0.2"}
    certainty: confirmed
  - url: "https://github.com/obra/superpowers (설치본 skills/writing-plans/SKILL.md 7.0.2)"
    supports: current
    claim: "writing-plans 의 입력은 spec 이다. 산출은 `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md` 이고, 원문 '(User preferences for plan location override this default)' 대로 위치는 사람의 선호로 바꾼다. 계획 머리에 '**Spec:** [path …]' 줄을 반드시 둔다. 끝에서 사람에게 계획 검토와 실행 방식(Subagent-driven | Native)을 묻는다. 고른 쪽에 따라 subagent-driven-development 나 executing-plans 를 REQUIRED SUB-SKILL 로 이어 부른다. 실행 방식을 이미 받았으면 검토만 묻는다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "7.0.0", latest: "7.0.2"}
    certainty: confirmed
  - url: "https://github.com/obra/superpowers (설치본 skills/subagent-driven-development/SKILL.md · scripts/sdd-workspace 7.0.2)"
    supports: current
    claim: "SDD 의 입력은 계획 파일 경로다. 계획마다 작업 폴더 `<repo-root>/.superpowers/sdd/<plan-basename>/` 를 두고, 그 안에 원장 progress.md(첫 줄 `# SDD ledger — plan: <path>`)와 brief · report · review package 를 쓴다. 이 경로는 스크립트에 `base=\"$root/.superpowers/sdd\"` 로 박혀 있고 설정으로 바꾸는 길이 없다. task 마다 implementer subagent 와 reviewer subagent 를 띄우고, 끝에 브랜치 전체를 보는 최종 리뷰를 한 번 띄운다. task 사이에는 사람에게 묻지 않고 판정을 `Ruling: …` 줄로 원장에 적는다. 멈추는 자리는 넷(되돌릴 수 없는 일 · 보안 · worktree 밖 부작용 · 망가진 계획)뿐이다. 끝나면 finishing-a-development-branch 를 스스로 부른다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "7.0.0", latest: "7.0.2"}
    certainty: confirmed
  - url: "https://github.com/obra/superpowers (설치본 skills/executing-plans/SKILL.md 7.0.2)"
    supports: current
    claim: "executing-plans 는 SDD 와 같은 작업 폴더 · 원장 형식을 쓴다(원문 'same directory, same format'). 그래서 실행 중에 실행기를 바꿔도 같은 원장에서 이어 간다. 구현은 subagent 없이 같은 세션에서 하고, 끝에 가장 강한 모델로 최종 리뷰어 하나를 띄운다(subagent 도구가 없으면 스스로 리뷰). 끝나면 finishing-a-development-branch 로 간다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "7.0.0", latest: "7.0.2"}
    certainty: confirmed
  - url: "https://github.com/obra/superpowers (설치본 skills/finishing-a-development-branch/SKILL.md 7.0.2)"
    supports: current
    claim: "finishing 은 테스트가 통과한 뒤 사람에게 고정 메뉴 3개(로컬 머지 · push 하고 PR · 그대로 둠, detached HEAD 면 2개)를 내고 답을 기다린다. worktree 가 `.worktrees/` · `worktrees/` 아래에 있을 때만 스스로 정리한다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "7.0.0", latest: "7.0.2"}
    certainty: confirmed
  # ── Matt Pocock skills ──
  - url: "https://github.com/mattpocock/skills"
    supports: alternative
    claim: "MIT 라이선스다. GitHub Releases 는 비어 있고, .claude-plugin/plugin.json 의 version 은 1.3.2(name mattpocock-skills)다. Claude Code 설치는 `claude plugin install mattpocock-skills@claude-plugins-official` 이고 스스로 업데이트된다. npx skills 로 복사 설치하는 길도 있고, README 는 둘 다 깔면 skill 이 두 번 잡힌다고 경고한다. 레포마다 `/setup-matt-pocock-skills` 를 한 번 돌려야 한다. skill 은 engineering 20개와 productivity 7개이고, 사용자 호출용과 모델 호출용으로 나뉜다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "레포에 미기재(dependencies.md 에 없음)", latest: "1.3.2 (plugin.json, 릴리스 태그 없음)"}
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/setup-matt-pocock-skills/SKILL.md"
    supports: alternative
    claim: "setup skill 은 레포 CLAUDE.md(없으면 AGENTS.md)에 `## Agent skills` 절을 넣거나 고친다. 그리고 `docs/agents/issue-tracker.md` · `docs/agents/triage-labels.md`(triage 가 깔린 때만) · `docs/agents/domain.md` 를 쓴다. 이슈 트래커는 GitHub · GitLab · 로컬 markdown(.scratch/) · 기타 중에서 고른다. 도메인 문서 기본값은 루트의 GLOSSARY.md 와 docs/adr/ 다. to-spec · to-tickets · triage 가 이 설정을 읽는다. 경로와 트래커는 이 파일들을 고쳐 바꾼다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/setup-matt-pocock-skills/issue-tracker-local.md"
    supports: alternative
    claim: "트래커가 로컬일 때 spec 은 `.scratch/<feature-slug>/spec.md`, 티켓은 `.scratch/<feature-slug>/issues/<NN>-<slug>.md`(01부터)에 쓴다. 상태는 파일 위쪽 `Status:` 줄에 적는다. wayfinder 는 `.scratch/<effort>/map.md` 를 쓴다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/mattpocock/skills/main/skills/productivity/grilling/SKILL.md"
    supports: alternative
    claim: "grill-me(disable-model-invocation: true)는 본문에서 grilling skill 만 부른다. grill-with-docs 는 grilling 과 domain-modeling 을 부르고 ADR · 용어집을 만든다. grilling 은 결정 트리의 frontier 를 라운드로 묻는다. 질문마다 번호를 붙이고 권장 답을 ➡️ 로 표시한다. 환경 사실은 subagent 가 모은다. 정해진 산출 파일은 없다. frontier 가 비면 공유 이해를 사람에게 확인받고 끝나며, 다음 skill 을 부르지 않는다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/to-spec/SKILL.md"
    supports: alternative
    claim: "to-spec(disable-model-invocation: true)의 입력은 대화와 레포 · 용어집 · ADR 이다. 인자는 없고 사람을 인터뷰하지 않는다. 산출은 고정 틀(Problem Statement · Solution · User Stories · Implementation Decisions · Testing Decisions · Out of Scope · Further Notes)의 spec 이고, 파일 경로가 아니라 이슈 트래커에 `ready-for-agent` 라벨로 올린다. 묻는 자리는 쓰기 전 테스트 seam 확인 하나다. 끝에 다음 skill 을 부르지 않고 사람에게 돌아간다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/to-tickets/SKILL.md"
    supports: alternative
    claim: "to-tickets(disable-model-invocation: true)의 입력은 대화 또는 인자(spec 경로 · 이슈 번호 · URL)다. 산출은 tracer-bullet 티켓이고 blocking 관계를 함께 적는다. 트래커가 로컬이면 .scratch/<slug>/issues/NN-*.md 에, 아니면 이슈(가능하면 sub-issue)로 쓴다. 쪼갠 안을 사람에게 보이고 승인할 때까지 고친 뒤 올린다. 다음 skill 은 부르지 않는다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/implement/SKILL.md"
    supports: alternative
    claim: "implement(disable-model-invocation: true)의 입력은 spec 이나 티켓 참조 인자다. 산출은 지금 브랜치의 커밋이다. 정해진 seam 에서 tdd 를, 끝에 code-review 를 Skill 도구로 부른다. 티켓 참조가 모호할 때만 사람에게 묻는다. subagent 는 언급이 없다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/implement-spec/SKILL.md"
    supports: alternative
    claim: "implement-spec(disable-model-invocation: true)의 입력은 to-spec 과 to-tickets 의 결과(티켓 의존 그래프)와 이슈 트래커다. 산출은 통합 브랜치 하나와 티켓 해결이고, 트래커나 사람이 원하면 draft PR 을 연 뒤 ready 로 바꾼다. 탐색 노트는 레포 밖 markdown 에 둔다. subagent 를 스스로 띄운다 — 탐색(선택), 티켓마다 implementer(각자 worktree · 브랜치, 백그라운드, tdd 사용), merger, review-fix. 사람에게 묻는 자리가 없다. 끝에 implementer worktree 를 지운다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/code-review/SKILL.md"
    supports: alternative
    claim: "code-review(모델 호출 가능)의 입력은 고정 지점(commit · branch · tag · ref)이다. 없으면 사람에게 묻는다. spec 은 커밋 메시지의 이슈 참조, 인자 경로, docs/ · specs/ · .scratch/ 아래 파일 순으로 찾고, 못 찾으면 묻는다. Standards 와 Spec 두 subagent 를 병렬로 띄운다. 산출은 파일이 아니라 대화창 보고(`## Standards` · `## Spec` + 한 줄 요약)다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/tdd/SKILL.md"
    supports: alternative
    claim: "tdd(모델 호출 가능)는 테스트를 쓰기 전에 seam 을 적고 사람에게 확인받으라고 한다(원문 'confirm them with the user'). GLOSSARY.md 와 ADR 을 읽는다. 별도 산출 파일은 없고 subagent 도 띄우지 않는다. 리팩터는 code-review 로 넘긴다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/research/SKILL.md"
    supports: alternative
    claim: "research(모델 호출 가능)는 백그라운드 subagent 하나를 띄워 1차 출처로 조사한다. 결과는 레포 안 markdown 파일 하나이고, 위치는 레포 관례를 따르며 관례가 없으면 정해서 알린다. pr skill 은 PR 본문 틀(Summary · Evidence · Merge Danger)만 정하고 gh 로 PR 을 만드는지는 쓰지 않는다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  # ── pstack ──
  - url: "https://raw.githubusercontent.com/cursor/plugins/main/pstack/README.md"
    supports: both
    claim: "공식 pstack README 가 Claude Code 설치(`/plugin marketplace add cursor/plugins` · `/plugin install pstack@cursor-plugins`)를 직접 싣는다. 이 경로로 깔면 poteto-mode 는 `/pstack:poteto-mode` 로 부른다. 써드파티 마켓플레이스라 자동 업데이트는 꺼져 있다. 계획 skill 은 기본으로 없다('i don't believe in planning'). 사용자 원문의 「공식은 Cursor 용, Claude Code 용은 커뮤니티 포팅」과 어긋난다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/cursor/plugins/main/pstack/plugin.json"
    supports: alternative
    claim: "pstack plugin.json 은 version 0.15.36 · license MIT · author Lauren Tan · repository cursor/plugins 다. 파일에 agent-plugins.org 스키마 1.0.0 이 걸려 있다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "레포에 미기재", latest: "0.15.36"}
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/cursor/plugins/main/pstack/skills/poteto-mode/SKILL.md"
    supports: alternative
    claim: "poteto-mode(disable-model-invocation: true)는 라우터다. 일에 맞는 `playbooks/<title>.md` 를 열어 그 단계를 할 일 목록에 그대로 옮긴다. 플레이북은 23개다(Investigation · Bug fix · Feature · Multi-phase or multi-PR plan · Opening a PR · Orchestrate · Autopilot-full/stack 등). 다른 skill(architect · swarm · arena · interrogate 등)을 스스로 부른다. 플레이북 단계의 subagent 는 `subagent_type: \"poteto-agent\"` 로 백그라운드에서 띄운다. 사람에게는 되돌릴 수 없는 일과 실험으로 못 가리는 제품 · 선호 판단만 묻는다. 코드를 바꾸는 플레이북은 'Opening a PR' 로 끝난다. 설정으로 바꿀 수 있는 것은 역할별 모델(/setup-pstack)뿐이고, 경로 · 이름을 바꾸는 설정은 SKILL.md 에 없다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/cursor/plugins/main/pstack/skills/poteto-mode/playbooks/multi-phase-plan.md"
    supports: alternative
    claim: "계획 플레이북의 산출은 markdown 계획 파일 하나다. 운영자가 출력 경로를 정하고, 없으면 'the agent store's docs/' 아래에 둔다. 틀은 Program checklist · PR 마다 한 절 · Appendices A–D 이고, check-plan.mjs 로 검사한다. 원문 'The plan is the deliverable. Do not implement.' 대로 구현하지 않는다. 계획 경로를 보이고 멈추며, 실행은 운영자가 'go' 해야 정한 실행 플레이북(autopilot-full | autopilot-stack | orchestrate)으로 시작한다. 탐색은 poteto-agent subagent 가 한다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/cursor/plugins/main/pstack/skills/poteto-mode/playbooks/opening-a-pr.md"
    supports: alternative
    claim: "PR 플레이북의 입력은 main 에서 딴 worktree 브랜치다. 산출은 ready 상태(draft 아님) PR 이고 gh 나 Origin 으로 연다. 제목은 Conventional Commits, 본문은 `## Why` · `## What changed` · `## Scope` · `## Tradeoffs` · `## Blast Radius` · `## Verification` 순서이고 약 40줄을 넘지 않는다. URL 을 보이고 계속 일한다. babysit 은 사용자가 요청할 때만 한다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/cursor/plugins/main/pstack/skills/poteto-mode/playbooks/feature.md"
    supports: alternative
    claim: "Feature 플레이북은 how → architect → throughput checkpoint(할 일 4개) → 코드 작성 subagent 에 위임 → 검증 → 커밋 정리 → (설계에 이견이 있으면) interrogate → Opening a PR 순서다. 정해진 산출 파일은 없고, 열린 결정은 마지막 답에 싣는다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://github.com/michael-denyer/pstack-claude"
    supports: alternative
    claim: "커뮤니티 Claude Code 포팅이다(MIT). 설치는 `/plugin marketplace add michael-denyer/pstack-claude` · `/plugin install pstack@pstack-claude` 이고 Claude Code 2.1.292 이상이 필요하다. 공식 쪽은 Cursor 이름을 실행 중에 옮기는데, 포팅은 설치 전에 옮기고 SessionStart 훅을 더해 일을 poteto-mode 로 보낸다. 판 값과 upstream 동기 시점은 페이지에 없다."
    touches: []
    decides: [OQ18]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://flaviocopes.com/pstack"
    supports: alternative
    claim: "2차 해설이다. pstack 은 workflow skill 24 · principle skill 23 · playbook 22 · subagent 2 로 이루어졌다고 쓴다(공식 README 는 플레이북 23개라 수가 어긋난다). Claude Code 용으로는 pstack-claude 포팅을 권한다. 주문의 plan · execute · research · pr 이름은 이 글에도 skill 이름으로 나오지 않는다."
    touches: []
    decides: [OQ18]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain
  # ── Claude Code 플랫폼 ──
  - url: "https://code.claude.com/docs/en/skills"
    supports: both
    claim: "frontmatter `disable-model-invocation: true` 이면 Claude 가 스스로 그 skill 을 부를 수 없다. Skill 도구 호출은 막히고, subagent 의 `skills:` 에 미리 싣는 것도 막힌다. `/name` 으로 사람이 불러야 한다. Matt Pocock 의 사용자 호출 skill 과 pstack 의 poteto-mode · figure-it-out 이 이 표시를 단다. 그래서 지휘자 · 하위 agent 가 이 skill 들을 Skill 도구로 부르는 단계표는 플랫폼에서 막힌다. 다만 subagent 가 Skill 도구로 직접 부를 때에 대한 명시 문장은 문서에 없다."
    touches: []
    decides: [OQ18]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
repo_claims:
  - id: RC1
    path: "plugins/spec-distill/dependencies.md"
    anchor: "| superpowers | 7.0.0 | 2026-10-22 | 알림 |"
    line: 17
    claim: "이 레포가 검증한 superpowers 판은 7.0.0 이고 강도는 「알림」이다. 없으면 인터뷰는 brief 까지 만들고 알린 뒤 멈춘다. 지휘자 · 로드맵 흐름은 진입에서 멈춘다. Matt Pocock skills · pstack 행은 표에 없다."
    touches: []
    decides: [OQ18]
  - id: RC2
    path: "plugins/spec-distill/skills/epic-conductor/SKILL.md"
    anchor: "superpowers 확인 — skill 목록에 `superpowers:` 로 시작하는 skill 이 하나도 없으면"
    line: 64
    claim: "진입할 때 skill 목록에 superpowers: 로 시작하는 skill 이 하나도 없으면 「superpowers 가 필요하다」를 내고 지휘하지 않는다. 판 확인(check_deps.py superpowers)은 알리기만 하고 멈추지 않는다."
    touches: []
    decides: [OQ18]
  - id: RC3
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "부를 skill: `superpowers:brainstorming` · `superpowers:using-git-worktrees`"
    line: 44
    claim: "걸음 3 이 부르는 skill 은 superpowers 이름으로 박혀 있다(brainstorming · using-git-worktrees · dispatching-parallel-agents, 그리고 /spec-distill:spec-review). 걸음 4 는 'writing-plans 가 권한 실행 방식(superpowers:subagent-driven-development · superpowers:executing-plans)'(52행), 걸음 5 는 systematic-debugging · requesting-code-review(틀) · receiving-code-review · verification-before-completion(66행)이다. 95행은 superpowers skill 이 없으면 지휘 절차를 시작하지 않는다."
    touches: []
    decides: [OQ18]
  - id: RC4
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "실행 방식 원장(SDD 면 그 worktree 작업 폴더의 `progress.md`)의 `Ruling:` 줄을 읽어"
    line: 50
    claim: "지휘자는 구현 중에 실행 방식 원장의 `Ruling:` 줄을 읽어 판정 줄로 올리고, SDD 의 BLOCKED 를 멈춤 조건으로 쓴다. superpowers SDD · executing-plans 의 원장 형식(`Ruling: <…> — <…> — <…>` · BLOCKED 상태)에 기댄다."
    touches: []
    decides: [OQ18]
  - id: RC5
    path: "plugins/spec-distill/scripts/repo_defaults.py"
    anchor: "SPECS_DIR = \"docs/superpowers/specs/\" · PLANS_DIR = \"docs/superpowers/plans/\" · SDD_WORKSPACE = \".superpowers/sdd/\""
    line: 21
    claim: "외부 도구의 기본 경로는 이 모듈에만 글자로 둔다(모듈 docstring). specs_dir · plans_dir 는 로드맵 머리말 > 레포 설정 파일 .devbrew.md > 기계 상태 > 기본값 순으로 정하고 레포마다 바꿀 수 있다(KEYS · ROADMAP_LAYER_KEYS · _DEFAULTS). SDD_WORKSPACE 는 KEYS 에 없는 상수라 설정으로 바꿀 수 없다."
    touches: []
    decides: [OQ18]
  - id: RC6
    path: "plugins/spec-distill/scripts/conductor_ledger.py"
    anchor: "def dirty_lines(path: Path) -> list:"
    line: 154
    claim: "worktree 를 지우기 전 보고에 `path / repo_defaults.SDD_WORKSPACE` 폴더가 비어 있지 않으면 「실행 방식 작업 폴더(git 밖 기록…)」 줄을 더한다. SDD 작업 폴더 경로(.superpowers/sdd/)를 이름으로 안다."
    touches: []
    decides: [OQ18]
  - id: RC7
    path: "plugins/spec-distill/scripts/roadmap_status.py"
    anchor: "def plan_specs(text: str) -> set: … l.lstrip().startswith(\"**Spec:**\")"
    line: 321
    claim: "상태 계산은 계획 파일과 설계문서를 계획 안 `**Spec:**` 줄로 잇는다(branch_plans 341행: plans_dir 안에서 바뀐 계획 중 그 줄이 설계문서를 가리키는 것). 이 줄은 superpowers writing-plans 의 계획 머리 틀이 요구하는 줄이다. 다른 계획 형식(pstack 의 Program checklist 계획 · Matt 의 .scratch/<slug>/spec.md + issues/)은 이 줄이 없으면 「계획 없음」으로 셀 수 있다 — 코드 경로에서 추론한 것이고 실행해 보지는 않았다."
    touches: []
    decides: [OQ18]
  - id: RC8
    path: "plugins/spec-distill/scripts/roadmap_status.py"
    anchor: "def find_specs(git: Git, tree: str, block: dict, bundle_path, specs_dir: str):"
    line: 325
    claim: "묶음 에픽의 설계문서는 specs_dir 안에서 frontmatter `source_interview` 값이 그 묶음 경로와 같은 파일로 찾는다. source_interview 는 superpowers 가 아니라 devbrew 쪽 규약이다(roadmap_render.py 336행이 설계문서에 적으라고 안내). 블록에 `산출물` 칸이 있으면 그 경로들을 쓴다(326행)."
    touches: []
    decides: [OQ18]
  - id: RC9
    path: "plugins/spec-distill/skills/spec-review/SKILL.md"
    anchor: "`--bundle` 은 리뷰어에게 가지 않는다 — 리뷰어는 설계문서 frontmatter `source_interview` 로 정답 출처에 닿고"
    line: 157
    claim: "spec-review 는 첫 인자로 설계문서 경로, 선택 인자로 `--bundle <묶음|brief>` 를 받는다. spec_review_bundle.py entry 가 --bundle 값이 설계문서 frontmatter source_interview 와 같은 파일인지 확인한다(다르거나 없으면 거절 — spec_review_bundle.py 73–77행). 설계문서 후보 폴더는 `repo_defaults.py get specs_dir`(191행)로 정한다. 「이 에픽 다시 설계」 갈래는 Skill superpowers:brainstorming 을 다시 시작한다(699행)."
    touches: []
    decides: [OQ18]
unanswered: "pstack-claude 포팅의 판 값과 upstream 동기 시점, 포팅이 disable-model-invocation 표시를 유지하는지는 확인하지 못했다. Matt Pocock 로컬 트래커에서 to-spec 이 실제로 .scratch/<slug>/spec.md 를 쓰는지는 setup 템플릿에서만 확인했다. subagent 안에서 disable-model-invocation skill 을 Skill 도구로 부를 때의 동작은 공식 문서에 명시가 없다. Matt Pocock skills · pstack 은 이 기계 플러그인 캐시에 설치본이 없어 원격 원문만 읽었다."
```

## 참고

- WebFetch 가 돌려준 원문은 일부만 축자 인용이고 나머지는 요약이다. frontmatter 값(`disable-model-invocation: true` 등)은 요약 결과에서 옮긴 것이라, V1 에서 원문으로 다시 확인할 것을 권한다.
- superpowers 설치본 경로: `/Users/jeonghokim/.claude/plugins/cache/claude-plugins-official/superpowers/7.0.2/` (skills/*/SKILL.md · skills/subagent-driven-development/scripts/sdd-workspace · .claude-plugin/plugin.json · LICENSE).

Sources:
- [obra/superpowers releases](https://github.com/obra/superpowers/releases)
- [mattpocock/skills](https://github.com/mattpocock/skills)
- [mattpocock skills plugin.json](https://raw.githubusercontent.com/mattpocock/skills/main/.claude-plugin/plugin.json)
- [setup-matt-pocock-skills](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/setup-matt-pocock-skills/SKILL.md)
- [issue-tracker-local](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/setup-matt-pocock-skills/issue-tracker-local.md)
- [to-spec](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/to-spec/SKILL.md) · [to-tickets](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/to-tickets/SKILL.md) · [implement](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/implement/SKILL.md) · [implement-spec](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/implement-spec/SKILL.md) · [code-review](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/code-review/SKILL.md) · [tdd](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/tdd/SKILL.md) · [research](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/research/SKILL.md) · [pr](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/pr/SKILL.md) · [grill-me](https://raw.githubusercontent.com/mattpocock/skills/main/skills/productivity/grill-me/SKILL.md) · [grilling](https://raw.githubusercontent.com/mattpocock/skills/main/skills/productivity/grilling/SKILL.md) · [grill-with-docs](https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/grill-with-docs/SKILL.md)
- [cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack) · [pstack README](https://raw.githubusercontent.com/cursor/plugins/main/pstack/README.md) · [pstack plugin.json](https://raw.githubusercontent.com/cursor/plugins/main/pstack/plugin.json) · [poteto-mode](https://raw.githubusercontent.com/cursor/plugins/main/pstack/skills/poteto-mode/SKILL.md) · [multi-phase-plan](https://raw.githubusercontent.com/cursor/plugins/main/pstack/skills/poteto-mode/playbooks/multi-phase-plan.md) · [opening-a-pr](https://raw.githubusercontent.com/cursor/plugins/main/pstack/skills/poteto-mode/playbooks/opening-a-pr.md) · [feature](https://raw.githubusercontent.com/cursor/plugins/main/pstack/skills/poteto-mode/playbooks/feature.md) · [figure-it-out](https://raw.githubusercontent.com/cursor/plugins/main/pstack/skills/figure-it-out/SKILL.md)
- [michael-denyer/pstack-claude](https://github.com/michael-denyer/pstack-claude)
- [flaviocopes.com/pstack](https://flaviocopes.com/pstack)
- [Claude Code skills docs](https://code.claude.com/docs/en/skills)

## R8

### 지금 이해
R7 질문 둘에 직접 답함 — 파일 구조 초안(팀 폴더 = 로드맵 폴더: roadmap.md · STATUS.md · inbox/ · <에픽>/INTENT.md · results/, 역할 폴더 · 팀 규칙 목차 · HANDBOOK 위치 미정, 단계표 · 지시서 · mod 는 플러그인, superpowers 산출 · SDD 원장 그대로, machine.md 는 기계 캐시), superpowers 호환(RC6 결합을 단계표 칸으로 풀면 superpowers 쪽 수정 없음, Matt Pocock · pstack 은 조사 10 으로).
조사 9(묶음 6) · 조사 10(묶음 7) 결과:
- 확인 RC92 — 확인 — plugins/spec-distill/dependencies.md#python · claude-code — 14행 python 3.9.6, 19행 2.1.303, Bun · Node · Go 행 없음
- 확인 RC93 — 확인 — plugins/#monitors · asyncRewake · CLAUDE_CODE_MESSAGING · mcpServers — grep 0건
- 확인 RC94 — 확인 — docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md#S9 — 원문 일치
- 확인 RC95 — 확인 — plugins/spec-distill/dependencies.md#superpowers — 17행 7.0.0 · 알림
- 확인 RC96 — 확인 — plugins/spec-distill/skills/epic-conductor/SKILL.md#1.5 의존 확인 — 64행
- 확인 RC97 — 확인 — plugins/spec-distill/references/conducting.md#걸음 3 부를 skill — 44행 superpowers:brainstorming
- 확인 RC98 — 미확인 — plugins/spec-distill/references/conducting.md#50행 Ruling — 앵커 실재는 R1 에서 봄, BLOCKED 멈춤 조건 대조는 하지 않음
- 확인 RC99 — 확인 — plugins/spec-distill/scripts/repo_defaults.py#SPECS_DIR · PLANS_DIR — 21–22 · 41행
- 확인 RC100 — 확인 — plugins/spec-distill/scripts/conductor_ledger.py#dirty_lines — 154행
- 확인 RC101 — 확인 — plugins/spec-distill/scripts/roadmap_status.py#plan_specs — 321–322행 **Spec:** 줄로 계획 · 설계 연결
- 확인 RC102 — 미확인 — plugins/spec-distill/scripts/roadmap_status.py#find_specs — 앵커 실재만
- 확인 RC103 — 확인 — plugins/spec-distill/skills/spec-review/SKILL.md#--bundle — 157행
- 웹: Matt Pocock to-spec · pstack poteto-mode frontmatter 의 disable-model-invocation: true 는 본체가 원문(raw.githubusercontent.com)으로 확인. 그 밖 웹 주장은 조사 원문 인용, 본체 재확인 안 함.
- 대체됨: 「pstack 은 공식이 Cursor 용, Claude Code 용은 커뮤니티 포팅」(Phase 0 이름 조회) → 공식 README 가 Claude Code 설치(/plugin install pstack@cursor-plugins)를 직접 싣는다 (조사 10)
- 대체됨: 「pstack skill 은 plan · execute · research · pr」(Phase 0 이름 조회) → 라우터 poteto-mode + 플레이북 23개, 기본 계획 skill 없음 (조사 10)
조사 호출 10/60 · 이 라운드 본체 직접 2

### 다음 결정
OQ16 역할 폴더 위치 · OQ17 MEMORY 이름

### 질문
(b) 둘 묶음

### 답
→ S23 (OQ16 레포 공통 「1」 + HANDBOOK 쌓임 경계 원칙 · 실패 양식 목록 요청 · 원칙 저장 요청) · S24 (OQ17 이름 바꿈) · S25 (턴 중: 이렇게 가면 팀 간 나눈다는 의미가 약해지지 않나)

## R9

### 지금 이해
쌓인 맥락 실패 양식 11개를 사용자 예 셋 밖에서 나열(규칙 충돌 · 출처 없음 · 사라진 것 가리킴 · 과잉 일반화 · 주의 분산 · 고정비 · 리뷰 오염 · 과잉 억제 · 의역 손실 · 경고 무뎌짐 · 환경 섞임). 원칙을 메모리에 저장(feedback_wrong_context_worse_than_none.md) — brief 사용자 제약으로도 싣는다. S25 에 직접 답함: 팀은 일로 갈리고 규칙 · 역할로는 안 갈림 — 팀 전용 짧은 목록을 선택지로. 조사 9 · 10 요약 보임.
조사 호출 10/60 · 이 라운드 본체 직접 0
사실로 보고 직접 답한 질문 1개 — 팀 간 나눔의 의미가 약해지나 · 팀은 목표 · 상태 · 편지함 · 과제로 갈리고 규칙 · 역할로는 안 갈린다

### 다음 결정
OQ19 팀 규칙 · OQ20 경계 장치 · OQ15 대화 수단 · OQ18 작업 방식

### 질문
(b) 넷 묶음

### 답
→ S26 (OQ19) · S27 (OQ20 넷 다) · S28 (OQ15) · S29 (OQ18)

## R10

### 지금 이해
R9 답 반영. 설계로 넘길 열린 질문 12개(OQ21–OQ32)를 보임 — OQ31 · OQ32 는 seed 냉독의 미해결 모호점.
조사 호출 10/60 · 이 라운드 본체 직접 0

### 다음 결정
열린 질문 목록 확정 · 추천: 이대로 넘김

### 질문
(b) 열린 질문 목록

### 답
→ S30 (이대로 넘김)

### 판정 1 — saturation-judge · R10 (조사 블록 아님 — 판정 원문)

```yaml
verdict: not_saturated
novelty:
  - n: 1
    changed: []
    opened: "일꾼 실행 방식(OQ3) · 지휘자 간 운반(OQ4) · 토큰 측정(OQ5) · 작업 목록 원인(OQ2) 등 첫 결정 축을 염(derived 차원 10개 · RC1–RC14)"
    failed: false
  - n: 2
    changed: [OQ2]
    opened: "없음"
    failed: false
  - n: 3
    changed: [OQ3, OQ5, OQ6]
    opened: "역할 폴더 CLAUDE.md 는 자동 적재되지 않는다 → OQ7 · 레포 MEMORY.md 와 자동 메모리 이름 겹침 → OQ17"
    failed: false
  - n: 4
    changed: [OQ3, OQ4]
    opened: "없음"
    failed: false
  - n: 5
    changed: [OQ5, OQ6]
    opened: "없음"
    failed: false
  - n: 6
    changed: [OQ4]
    opened: "없음"
    failed: false
  - n: 7
    changed: [OQ1, OQ7, OQ8]
    opened: "읽기 설계 · 측정 기준선을 첫 단추로 올림 → 절차서 쪼개기(OQ14) · 측정 기준선(OQ27)"
    failed: false
  - n: 8
    changed: [OQ9, OQ10, OQ11]
    opened: "기존 설계문서 지휘 기록 · 도는 로드맵 이전(OQ29)"
    failed: false
  - n: 9
    changed: [OQ15]
    opened: "없음"
    failed: false
  - n: 10
    changed: [OQ18]
    opened: "상태 계산 · 지휘 원장 읽기가 superpowers 산출 형식(계획 머리 **Spec:** 줄 · .superpowers/sdd/ 상수 · Ruling: 줄)에 묶여 있어, 다른 작업 방식을 끼우려면 이 읽기를 어떻게 가를지"
    failed: false
basis: "최근 두 묶음 = 묶음 6(조사 9)과 묶음 7(조사 10). 묶음 표지 순서는 블록 9→10 이 묶음 6→7 로 어긋남 없음. 묶음 6: 조사 9 가 S9 대안 기성 도구를 전수 비교(mcp_agent_mail · peerbus · agent-comms · repowire · Thrum · ntfy · A2A)했고, 그 결과로 OQ15 가 S28 「지금 안 + 자체 세션 받은 편지함 · asyncRewake 기법 차용」으로 해결됐다 — 결정을 바꿨다(원장 derived 「플랫폼에 있는 것과 새 파일 규약의 경계」 evidence S28). 묶음 7: 조사 10 이 OQ18 의 규약을 확정했다. 주문 전제와 어긋나는 사실 셋(pstack 공식 Claude Code 설치 경로 · plan/execute 이름의 skill 부재 · Matt Pocock/pstack 사용자 호출 skill 의 disable-model-invocation: true 는 모델 · subagent 가 Skill 도구로 부를 수 없음)이 OQ18 을 바꾸고 OQ30(실행기 칸 「사람」 값)에도 닿는다. 또 RC5–RC7(repo_defaults.py SDD_WORKSPACE 는 설정 불가 상수, roadmap_status.py 321행 plan_specs 가 **Spec:** 줄로 계획-설계문서를 잇는다, conducting.md 50행 Ruling: 줄 읽기)은 열린 목록에 없는 새 결정을 연다. 두 묶음 모두 changed 가 비지 않았으므로 규칙 3 에 따라 not_saturated. 실패 항목 없음. 조사 10 스스로 frontmatter 값은 WebFetch 요약에서 옮긴 것이라 원문 재확인을 권했고, subagent 안 Skill 도구 호출 동작은 문서 명시가 없다고 적었다(unanswered). 조사 9 는 Channels 의 Console API 키 허용이 공식 문서와 제3자 README 사이에서 충돌한 채 남았다."
gaps:
  - kind: confirm
    look_at: "Matt Pocock skills(to-spec · to-tickets · implement · implement-spec · grill-me) · pstack(poteto-mode · figure-it-out) SKILL.md 의 frontmatter 원문 바이트에서 disable-model-invocation: true 를 직접 확인하고, 그 표시가 붙은 skill 을 하위 agent 가 Skill 도구로 부를 때의 실제 동작(거부 · 허용)을 공식 문서 · 이슈에서 확인. 요약을 거치지 않은 원문 대조"
    may_change: [OQ18, OQ30]
    opens: "없음"
    device: open-researcher
  - kind: explore
    look_at: "superpowers 형식에 묶인 레포 읽기 지점 전수 — roadmap_status.py plan_specs/branch_plans(**Spec:** 줄), find_specs(source_interview), repo_defaults.py SDD_WORKSPACE 상수, conductor_ledger.py dirty_lines, conducting.md 의 Ruling: · BLOCKED 읽기. pstack 계획(Program checklist) · Matt .scratch/<slug>/spec.md+issues/ 를 넣으면 「계획 없음」 · 원장 없음으로 세는지를 코드 경로로 확인"
    may_change: [OQ30, OQ10]
    opens: "상태 계산 · 실행 원장 읽기를 작업 방식별 어댑터(단계표 칸)로 가를지, superpowers 형식을 기본 규약으로 남길지"
    device: repo-researcher
  - kind: confirm
    look_at: "S28 이 빌린 기법(자체 세션 받은 편지함 · asyncRewake)의 실제 동작 조건 — crossSessionInbound=accept 와 bypassPermissions 받는 쪽 보류, asyncRewake 종료 코드 2 의 쉬는 세션 깨우기가 API 키 인증 · 다른 기계에서도 서는지, 그리고 Channels 의 Console API 키 허용 충돌을 공식 문서 · changelog 로 판정"
    may_change: [OQ15, OQ21]
    opens: "없음"
    device: blind-spot-prober
  - kind: explore
    look_at: "여러 기계의 지휘자가 같은 git 원격에 inbox/ · STATUS.md 를 동시에 쓰는 기성 해법 — Thrum 의 전용 orphan 브랜치 JSONL, Beads 의 내용 해시 ID 충돌 회피, append-only 한 파일 한 글(파일 이름에 기계 · 시각) 꼴의 비교"
    may_change: [OQ21, OQ13]
    opens: "없음"
    device: open-researcher
  - kind: explore
    look_at: "재설계 전후 토큰 비교의 기준선을 지금 무엇으로 잴 수 있는지 — /usage 귀속 표(24시간 · 7일), OTel query_source=subagent, mod turn.step/turn.complete 중 지금 레포 · 이 기계에서 당장 쓸 수 있는 것과 세션 기록 30일 삭제 전에 남겨야 할 것"
    may_change: [OQ27, OQ26]
    opens: "없음"
    device: steelman-builder
```

근거 파일:
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/.claude/tmp/interview-sat/research_outputs.md (조사 9 = 1461행~, 조사 10 = 1741행~)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/.claude/tmp/interview-sat/ledger.txt

비고: 조사 1–8 의 novelty 는 블록 머리말 · decides 칸 · 원장 evidence 를 맞대어 매겼다. 판정에 꼭 필요한 최근 두 묶음(조사 9 · 10)만 원문을 끝까지 읽었다. 조사 5 와 조사 8 은 중간 부분을 훑기만 했다.

### 조사 11 — repo-researcher · R11 · 묶음 8

```yaml
repo_claims:
  - id: RC1
    path: "plugins/spec-distill/scripts/repo_defaults.py"
    anchor: 'SPECS_DIR = "docs/superpowers/specs/" · PLANS_DIR = "docs/superpowers/plans/" · ROADMAPS_DIR · INTERVIEW_DIR · KEYS · _folder'
    line: 21
    claim: "superpowers 산출 폴더의 기본값은 이 모듈에만 글자로 있다. specs_dir · plans_dir 는 로드맵 머리말이나 레포 설정 파일(.devbrew.md, 기본 브랜치 판)로 바꿀 수 있다. 다만 값은 레포 상대 폴더 하나이고(_folder), 글롭 · pathspec 특수 글자(* ? [ ] \\ 와 맨 앞 :)를 넣으면 오류로 거부한다. 그래서 .scratch/<slug>/ 처럼 일마다 달라지는 폴더는 키 하나로 적을 수 없다. 폴더가 아니라 파일 이름 꼴(spec.md · issues/NN-*.md)을 정하는 키는 없다."
    touches: []
    decides: []
  - id: RC2
    path: "plugins/spec-distill/scripts/repo_defaults.py"
    anchor: 'SDD_WORKSPACE = ".superpowers/sdd/"'
    line: 23
    claim: "SDD 작업 폴더 경로는 상수일 뿐 KEYS 에 없다. 그래서 레포 설정이나 로드맵으로 바꿀 수 없다. 이 상수를 읽는 코드는 conductor_ledger.dirty_lines 하나다(RC15)."
    touches: []
    decides: [OQ25]
  - id: RC3
    path: "plugins/spec-distill/scripts/roadmap_status.py"
    anchor: "def spec_line_path / def plan_specs"
    line: 307
    claim: "계획 파일에서 설계문서를 찾을 때 줄 앞 공백을 뗀 뒤 `**Spec:**` 로 시작하는 줄만 읽는다. 경로는 그 줄의 백틱 안 글자를, 백틱이 없으면 첫 낱말을 쓴다. 그런 줄이 없으면 빈 집합을 낸다. 오류도 경고도 내지 않는다."
    touches: []
    decides: [OQ30]
  - id: RC4
    path: "plugins/spec-distill/scripts/roadmap_status.py"
    anchor: "def branch_plans / def progress"
    line: 341
    claim: "branch_plans 는 `git diff --name-only base...tip -- <plans_dir>` 이 낸 파일 가운데 plan_specs 가 그 에픽의 설계문서와 겹치는 것만 계획으로 센다. 다음 둘은 경고 없이 빠진다 — plans_dir 밖의 계획(예: .scratch/<slug>/issues/NN-*.md, 이슈 트래커)과 `**Spec:**` 줄이 없는 계획(예: pstack 의 Program checklist). 계획이 0개면 progress 가 impl_done · 트레일러를 보지 않고 바로 돌아간다. 이때 단계는 「설계 중」이고 이유는 「spec 승인됨(<날짜>) · 계획 없음」 아니면 「spec 있음」이다. 설계문서에 `## 구현 대조 — …` 절이 있어도 머지 전에는 「설계 중」에 머문다. 머지 판정은 PR 캐시 · 머지 커밋으로 따로 하므로 머지되면 「머지됨」이 된다."
    touches: []
    decides: [OQ30]
  - id: RC5
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "보내기: 계획 agent 는 승인을 고른 에픽(같은 턴)과 걸음 1 이 「spec 승인됨(…) · 계획 없음」 으로 센 에픽(끊김 · 압축 뒤)에 보낸다"
    line: 42
    claim: "지휘 절차는 상태 계산이 낸 「spec 승인됨 · 계획 없음」을 근거로 계획 agent 를 보낸다. 실제로 보내는 것은 ledger live-agent ... --work 계획 이 1(없음)일 때뿐이다. 따라서 RC4 처럼 다른 형식의 계획이 「계획 없음」으로 세어지면, 압축 · 끊김 뒤 이 절차는 그 에픽을 계획이 필요한 에픽으로 읽는다."
    touches: []
    decides: [OQ30]
  - id: RC6
    path: "plugins/spec-distill/scripts/roadmap_status.py"
    anchor: 'trailers = {"Spec: " + s for s in specs} · def trailer_after · impl_done(t, p)'
    line: 386
    claim: "계획이 있을 때 단계를 세는 근거는 두 가지다. 「구현 끝」은 계획마다 설계문서에 `## 구현 대조 — <그 계획 경로>` 절(roadmap_model.IMPL_PREFIX)이 있어야 한다. 「구현 중」은 계획을 처음 더한 커밋 뒤 커밋 메시지에 `Spec: <설계문서 경로>` 줄이 있어야 한다. 둘 다 없으면 「계획 · 계획 있음」이다. 두 형식 모두 superpowers 가 아니라 devbrew 지휘자가 정한 것이다(write-sections · 보내는 글의 트레일러 규칙)."
    touches: []
    decides: [OQ30]
  - id: RC7
    path: "plugins/spec-distill/scripts/roadmap_status.py"
    anchor: "def find_specs"
    line: 325
    claim: "블록 종류마다 설계문서를 찾는 길이 다르다. 「산출물:」 칸이 있으면 그 경로들 가운데 있는 것을 쓴다. branch 블록이면 「spec:」 칸 경로를 쓴다. 이 두 길은 경로 제약이 없다. bundle 블록만 `git grep -l -F <묶음 경로> <tree> -- <specs_dir>` 로 찾고 frontmatter source_interview 가 묶음 경로와 같아야 센다. specs_dir 밖에 있거나 source_interview 가 없는 설계문서는 []가 된다. 그러면 progress 는 「설계 중 · 브랜치 있음 · spec 없음」을 낸다. 같은 빈 결과가 started() 와 doc_added() 도 거짓 · 빈 값으로 만들고, 둘은 끝이 없는 브랜치의 PR 판정과 옛 PR 거르기에 쓰인다."
    touches: []
    decides: []
  - id: RC8
    path: "plugins/spec-distill/scripts/roadmap_status.py"
    anchor: "def started (compute 안) — plan_specs(git.blob(main, p) or \"\") & set(specs) … git.grep_files(main, s, settings[\"plans_dir\"])"
    line: 726
    claim: "브랜치 끝이 없을 때 같은 이름의 머지된 PR 을 이 에픽 것으로 셀지를 started() 가 가른다. 근거는 둘 중 하나다 — 기본 브랜치에서 설계문서 승인 줄이 있거나, plans_dir 안에 그 설계문서를 `**Spec:**` 로 가리키는 계획이 있거나. 둘 다 없고 doc_added 도 비면 그 PR 을 세지 않는다. 이때 알림 줄이 「설계문서의 승인 줄 · 계획의 `**Spec:**` 를 확인한다」고 안내한다(line 521)."
    touches: []
    decides: []
  - id: RC9
    path: "plugins/spec-distill/scripts/check_bundle_coverage.py"
    anchor: "class Repo · def specs_for (os.listdir)"
    line: 115
    claim: "check_bundle_coverage 는 작업 트리를 읽을 때 os.listdir 로 specs_dir 바로 아래 *.md 만 읽는다(하위 폴더로 내려가지 않는다). 폴더가 없으면 설계문서 없음([])이고, 폴더를 못 읽으면 「못 읽음」으로 남긴다. 반면 roadmap_status 의 find_specs · _GitTreeRepo.specs_for 는 git grep pathspec 으로 하위 폴더까지 찾는다. 그래서 설계문서가 중첩 배치(예: <dir>/<slug>/spec.md)면 두 읽기가 서로 다른 결과를 낸다."
    touches: []
    decides: []
  - id: RC10
    path: "plugins/spec-distill/scripts/check_bundle_coverage.py"
    anchor: "def plan_task_text — on = line.startswith(\"### Task\") · def check_plan"
    line: 493
    claim: "--plan 은 계획 파일에서 `### Task` 로 시작하는 절의 글만 모아 AC<n> 토큰을 센다. 다른 ## · ### 머리를 만나면 모으기를 멈춘다. `### Task` 머리가 없는 계획(예: 체크리스트 형식이나 이슈 파일)은 모은 글이 비어 설계문서의 모든 AC 를 「계획에 없는 AC」로 내고 status 1(경고)이 된다. 검사 불가(3)로 가지 않는다. 계획 파일 인자는 하나뿐이라 여러 이슈 파일로 나뉜 계획은 한 번에 대조하지 못한다."
    touches: []
    decides: [OQ30]
  - id: RC11
    path: "plugins/spec-distill/scripts/check_bundle_coverage.py"
    anchor: "def parse_report · def check_impl — raise FormatError(\"보고에 AC 판정 줄이 없다\")"
    line: 557
    claim: "--impl 은 보고 파일에서 `AC<n>: 구현됨|미룸|빠짐 — <한 줄>` 줄만 읽는다. 이 꼴은 superpowers 의 형식이 아니라 devbrew 가 보내는 글로 요구하는 것이다. 판정 줄이 하나도 없으면 status 3(검사 불가, 「보고에 AC 판정 줄이 없다」)이다."
    touches: []
    decides: []
  - id: RC12
    path: "plugins/spec-distill/scripts/conductor_state.py"
    anchor: "def ledger_rulings — return [l.strip() for l in text.splitlines() if \"Ruling:\" in l]"
    line: 388
    claim: "실행 방식 원장의 판정은 줄 어디에든 `Ruling:` 글자가 든 줄로만 센다. 그런 줄이 없는 원장(다른 실행 방식의 진행 파일)은 오류 없이 빈 목록이다."
    touches: []
    decides: [OQ25]
  - id: RC13
    path: "plugins/spec-distill/scripts/control_plane.py"
    anchor: "def _rulings · def overlay — for row in (machine or {}).get(\"실행 원장\", [])"
    line: 997
    claim: "화면의 판정 줄은 기계 상태 `## 실행 원장` 행의 원장 경로를 읽어 ledger_rulings 로 모은다. 상세 보기에서 단계가 구현 중 · 구현 끝 · PR · 일부 머지 · 머지됨일 때만 읽는다. 경우는 넷이다. ① 상대 경로면 「절대 경로가 아니다」 실패로 친다. ② 못 읽으면(예: 일꾼 worktree 가 지워짐) ledger_failures 에 넣고 설계문서 `## 판정` 보관본을 합친다. ③ 읽었는데 `Ruling:` 줄이 없으면 rulings=[] 이고 화면은 「판정 줄: 0개(실행 원장)」 또는 「없음」이다 — 「셀 수 없음」이 아니다. ④ 원장 행도 보관본도 없으면 「셀 수 없음 — 실행 원장도 설계문서 `## 판정` 도 없다」이다."
    touches: []
    decides: [OQ25]
  - id: RC14
    path: "plugins/spec-distill/scripts/conductor_ledger.py"
    anchor: "def harvest · def c_rulings — print(\"판정 줄 — 셀 수 없음(보고에도 원장에도 판정이 없다)\"); return 3"
    line: 839
    claim: "ledger rulings 는 하위 보고와 원장 사본에서 `Ruling:` 줄을 모은다. 둘 다 없으면 rc 3 이다. ledger write-sections 는 판정 파일에 `- ` 로 시작하는 줄만 있어야 하고 비어 있지 않아야 하며, 아니면 Fail 2 · 3 으로 아무것도 쓰지 않는다. write-sections 가 쓰지 않으면 `## 판정` 도 `## 구현 대조 — <계획>` 절도 생기지 않는다. 그 결과 RC6 의 「구현 끝」 근거(impl_done)가 이 경로로는 만들어지지 않는다(코드에서 추론)."
    touches: []
    decides: [OQ25, OQ30]
  - id: RC15
    path: "plugins/spec-distill/scripts/conductor_ledger.py"
    anchor: "def c_progress — rows = load(root, a.roadmap)[\"실행 원장\"]"
    line: 1349
    claim: "ledger progress 는 형식을 가리지 않는다. 원장 경로마다 mtime 과 비지 않은 마지막 줄(120자)만 보인다. 못 읽으면 「원장을 읽지 못했다(경로 · 예외)」, 행이 없으면 「실행 원장 없음」이다. 다만 원장 경로 행은 지휘자가 ledger add --section \"실행 원장\" 으로 손수 적어야 생긴다(자동 탐지는 없다)."
    touches: []
    decides: [OQ25]
  - id: RC16
    path: "plugins/spec-distill/scripts/conductor_ledger.py"
    anchor: "def dirty_lines — work = path / repo_defaults.SDD_WORKSPACE"
    line: 154
    claim: "worktree 를 지우기 전 확인은 두 가지를 본다 — git status --porcelain --untracked-files=all 의 줄과 <worktree>/.superpowers/sdd/ 폴더가 비지 않았는지. 다른 도구의 git 밖(무시된) 작업 폴더는 이 함수가 세지 않는다. 남은 것이 없으면 c_cleanup 은 `git worktree remove`(--force 없음)를 부르고, c_orphans 는 「깨끗」으로 보인다."
    touches: []
    decides: [OQ25]
  - id: RC17
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "구현 중에는 맞추기마다 실행 방식 원장(SDD 면 그 worktree 작업 폴더의 `progress.md`)의 `Ruling:` 줄을 읽어 … 구현이 막히면(SDD 의 BLOCKED 포함)"
    line: 50
    claim: "SDD 원장 이름 progress.md 와 BLOCKED 는 reference 글에만 나온다. 스크립트 가운데 BLOCKED · progress.md 를 읽는 것은 없다(scripts/ grep 0건). 원장 경로는 지휘자가 machine.md `## 실행 원장` 에 적는 절대 경로다. 막힘 판단은 모델이 글로 한다."
    touches: []
    decides: [OQ25, OQ30]
  - id: RC18
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "## 마지막 보고 — 판정 전체 — 실행 방식의 마지막 목록 그대로(줄마다 `Ruling:`) · 실행 방식이 작업 폴더를 지울 수 있어 경로만으로는 부족하다"
    line: 43
    claim: "하위 보고 계약이 `Ruling:` 줄 꼴과 「작업 폴더는 지워질 수 있다」는 가정을 함께 싣는다. 구현 agent 틀(line 73)의 중간 보고 이름 CHECKPOINT 는 글에만 있고 어떤 스크립트도 읽지 않는다."
    touches: []
    decides: [OQ25]
  - id: RC19
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "superpowers:writing-plans 를 단일 세션과 똑같이 … · <writing-plans 가 권한 실행 방식 skill> · 머지 메뉴(`superpowers:finishing-a-development-branch`) — 「브랜치 그대로 두기」(3번)"
    line: 57
    claim: "계획 · 구현 agent 틀은 superpowers skill 이름에 글자로 기댄다. 그리고 그 skill 들이 묻는 자리의 미리 받은 답(writing-plans 끝 질문 = 계획 검토 · 실행 방식, finishing 메뉴 3번)을 그 skill 의 문면 순서로 안다. conducting.md 걸음 3 · 4 · 5 는 brainstorming · using-git-worktrees · dispatching-parallel-agents · subagent-driven-development · executing-plans · systematic-debugging · requesting-code-review · receiving-code-review · verification-before-completion 을 부를 skill 로 적는다. 모두 모델이 읽는 글이고 이를 확인하는 스크립트는 없다."
    touches: []
    decides: [OQ30]
  - id: RC20
    path: "plugins/spec-distill/skills/epic-conductor/SKILL.md"
    anchor: "superpowers 확인 — skill 목록에 `superpowers:` 로 시작하는 skill 이 하나도 없으면 `[spec-distill] epic-conductor 멈춤 — superpowers 가 필요하다 …` 를 내고 멈춘다"
    line: 64
    claim: "지휘자 진입은 superpowers: skill 이 하나도 없으면 멈춘다. conducting.md 손 절차 머리(line 95)도 같다. 판이 다르면 check_deps.py superpowers 가 알리기만 하고 멈추지 않는다. dependencies.md 의 superpowers 행 강도는 「알림」이다."
    touches: []
    decides: []
  - id: RC21
    path: "plugins/spec-distill/skills/epic-conductor/SKILL.md"
    anchor: "### 6. 통합 리뷰어 — `REVIEW_REQUEST` 는 `superpowers:requesting-code-review` 의 리뷰 요청 틀(`code-reviewer.md`)을 이 PR 로 채운 글"
    line: 173
    claim: "통합 리뷰어에게 보내는 글의 틀이 superpowers 안의 파일 이름(code-reviewer.md)에 기댄다. 틀 칸만 빌리고, 리뷰어는 devbrew 의 integration-reviewer 다."
    touches: []
    decides: []
  - id: RC22
    path: "plugins/spec-distill/skills/spec-review/SKILL.md"
    anchor: "review-candidates 펜스 — git log … -- \"${SPECS}*-design.md\" · ls-files --others … -- \"${SPECS}*-design.md\""
    line: 193
    claim: "인자 없이 부르면 specs_dir 의 `*-design.md`(superpowers brainstorming 파일 이름 꼴)만 후보로 뽑는다. 이 꼴이 아닌 파일(예: spec.md)은 후보에 없고, 후보가 없으면 「대상 부재」로 게이트 없이 끝난다. 경로를 인자로 주면 이름과 상관없이 리뷰한다. 승인 뒤 다음 세션 줄(line 757)은 「Skill superpowers:writing-plans」을 부른다. 게이트 없이 끝나는 모든 문면은 「writing-plans 로 가기 전에 … brainstorming 이 설계문서 점검을 마친 뒤」를 싣는다."
    touches: []
    decides: []
  - id: RC23
    path: "plugins/spec-distill/scripts/spec_review_bundle.py"
    anchor: "def entry — return refuse(\"설계문서 frontmatter 에 source_interview 가 없다\")"
    line: 73
    claim: "--bundle 을 주면 설계문서 frontmatter 에 source_interview 가 없거나 다른 파일을 가리킬 때 bundle-entry: REFUSE 로 리뷰 없이 끝난다. --bundle 이 없으면 대조를 건너뛰고 PROCEED 한다. source_interview 는 superpowers 가 쓰는 키가 아니다 — epic-handoff.md 의 넘김 줄과 roadmap_render.py(line 336)의 묶음 글이 brainstorming 에게 쓰라고 지시하는 devbrew 키다."
    touches: []
    decides: []
  - id: RC24
    path: "plugins/spec-distill/scripts/roadmap_status.py"
    anchor: "def approval_of — approval_date(git.blob(tip, s) or \"\") · FormatError → \"지휘 기록 읽기 불가\""
    line: 352
    claim: "계획 없음 단계의 이유 「spec 승인됨(<날짜>)」는 설계문서 `## 지휘 기록` 의 `- spec 승인 · <YYYY-MM-DD> · 「…」` 줄(roadmap_model.APPROVAL_PREFIX)에서 읽는다. 절이 깨져 FormatError 가 나면 「설계 중 · spec 있음 · 지휘 기록 읽기 불가 — …」다. 그러니 기존 설계문서의 지휘 기록 절을 옮기거나 형식을 바꾸면 이 읽기가 영향을 받는다."
    touches: []
    decides: [OQ29]
  - id: RC25
    path: "plugins/spec-distill/references/roadmap-ontology.md"
    anchor: "| 계획 | 계획 | 레포 상대 경로 | task · 이 계획의 AC | `**Spec:**` → 설계문서 | 계획을 쓴 세션 | · | 판정 | … | 실행 중엔 실행 방식 원장, 끝나면 설계문서 `## 판정` |"
    line: 23
    claim: "온톨로지 문서는 계획 → 설계문서 링크를 `**Spec:**` 로, 커밋 → 설계문서 링크를 `Spec:` 트레일러로, 실행 중 판정의 주인을 실행 방식 원장으로 정의한다. tests/test_roadmap_ontology.py 의 ALLOW_LINK 에 \"**Spec:**\" · \"Spec:\" 가 들어 있다."
    touches: []
    decides: [OQ30]
  - id: RC26
    path: "plugins/spec-distill/skills/pm-interview/references/finishing.md"
    anchor: "#### B-1 — superpowers 가용성 분기 · `next_phase: superpowers:brainstorming`"
    line: 442
    claim: "인터뷰 끝 단계는 superpowers 가 없으면 brief 까지 만들고 알린 뒤 멈춘다. 있으면 다음 세션 줄로 brainstorming 을 부른다. brief frontmatter 의 next_phase 기본값은 superpowers:brainstorming(템플릿 line 7)인데, check_brief.py 를 포함해 이 값을 검사하는 스크립트는 없다(scripts grep 결과, build_brief_inline_blob.py 의 문서 언급 하나뿐)."
    touches: []
    decides: []
  - id: RC27
    path: "plugins/quality-gates/scripts/discover-spec.sh"
    anchor: "1. 범위 안 커밋의 `Spec:` 트레일러가 가리키는 설계문서 전부 … 2. 없으면 범위 안 커밋 메시지 + 열린 PR 본문"
    line: 4
    claim: "품질 게이트의 의도 출처는 devbrew 의 `Spec:` 트레일러를 먼저 보고 경로 꼴은 가리지 않는다. 트레일러가 없으면 커밋 메시지 + 열린 PR 본문으로 내려간다. 이 길은 superpowers 산출 경로를 모른다."
    touches: []
    decides: []
  - id: RC28
    path: "plugins/plugin-audit/scripts/check-integrity.sh"
    anchor: "is_foreign_state — .superpowers/*|*/.superpowers/*) return 0"
    line: 109
    claim: "plugin-audit 무결성 검사는 .superpowers/ 를 남의 상태로 보고 전역 비교에서 뺀다. 다른 도구의 작업 폴더(.scratch 등)는 이 목록에 없다."
    touches: []
    decides: []
  - id: RC29
    path: "plugins/spec-distill/tests/test_repo_literals.sh"
    anchor: "(\"레포 구조 경로\", re.compile(r\"docs/superpowers|\\.superpowers|plugins/spec-distill|\\.claude/worktrees\"))"
    line: 38
    claim: "락이 TARGETS(epic-conductor SKILL · conducting.md · conductor-dispatch.md · conductor_ledger.py · control_plane.py · roadmap_status.py · spec-review SKILL · finishing.md 등)에서 docs/superpowers · .superpowers 글자를 금지한다. repo_defaults 상수 값의 반복도 금지한다. 반면 `superpowers:brainstorming` 같은 skill 이름은 음성 대조로 허용한다(line 99). 그래서 경로는 상수 하나에 모여 있고 skill 이름은 글 곳곳에 흩어져 있다."
    touches: []
    decides: []
  - id: RC30
    path: "plugins/spec-distill/tests/test_control_plane.sh"
    anchor: "printf '# SDD ledger — plan: p\\nTask 1: Ruling: 가 — 왜 — 비용\\n' > \"$LEDGER\""
    line: 533
    claim: "테스트 fixture 가 SDD 원장 꼴(`# SDD ledger — plan:` · `Task n: Ruling:`)을 글자로 쓴다(test_conductor_state.py line 369 도 같다). 다른 fixture 의 꼴도 글자로 박혀 있다 — 계획의 `**Spec:**` 줄(test_conductor_e2e.sh line 82, test_roadmap_status.sh 다수), 계획의 `### Task` 절(test_bundle_coverage.sh line 344, test_coverage_scope.py). test_superpowers_presence.sh 는 superpowers 없을 때의 멈춤 문면을, test_conducting_reference.sh 는 손 절차에 실행 방식 이름(subagent-driven · executing-plans)을 고정하는 문장이 없음을 잠근다."
    touches: []
    decides: []
unanswered: "superpowers SDD 의 progress.md 가 실제로 `Ruling:` · BLOCKED · CHECKPOINT 를 쓰는지는 레포 밖(upstream skill) 사실이라 확인하지 못했다. 레포에는 그 꼴을 흉내 낸 fixture 만 있다. pstack Program checklist · Matt Pocock 의 .scratch 형식 · 이슈 트래커 spec 을 아는 코드는 레포에 없다(그 낱말은 이번 인터뷰 문서 셋에만 나온다)."
```

조사 범위와 읽은 구현:
- 스크립트: `roadmap_status.py`(spec_line_path · plan_specs · find_specs · branch_plans · progress · approval_of · started · _GitTreeRepo), `repo_defaults.py`, `conductor_ledger.py`(dirty_lines · c_progress · harvest · c_rulings · c_write_sections · insert_sections), `conductor_state.py`(ledger_rulings), `control_plane.py`(_rulings · overlay · 판정 줄 렌더 두 곳), `check_bundle_coverage.py`(Repo.specs_for · plan_task_text · check_plan · parse_report · check_impl), `spec_review_bundle.py`(entry), `check_deps.py`(superpowers 판 확인)
- reference · skill: `conducting.md` · `conductor-dispatch.md` · `epic-handoff.md` · `roadmap-ontology.md` · `skills/epic-conductor/SKILL.md` · `skills/spec-review/SKILL.md` · `skills/pm-interview/references/finishing.md`
- 다른 플러그인: `plugins/quality-gates/scripts/discover-spec.sh`, `plugins/plugin-audit/scripts/check-integrity.sh`
- 락 · 테스트: `test_repo_literals.sh` · `test_conducting_reference.sh` · `test_superpowers_presence.sh` · fixture 들

형식이 없을 때의 결과를 묶으면 이렇다.
- **오류(rc 3 · 거부)로 가는 자리:** 보고 · 원장 어디에도 `Ruling:` 줄이 없을 때 `ledger rulings` 와 `write-sections`(RC14), 보고에 `AC<n>:` 줄이 없을 때 `--impl`(RC11), `--bundle` 을 줬는데 `source_interview` 가 없을 때 spec-review 진입(RC23), superpowers: skill 이 하나도 없을 때 지휘자 진입(RC20).
- **조용히 「없음」이나 다른 단계로 세는 자리:**
  - 계획이 plans_dir 밖에 있거나 `**Spec:**` 줄이 없으면 「계획 없음」이 되고, 지휘 절차는 그 에픽을 계획이 필요한 에픽으로 읽는다(RC4 · RC5).
  - 설계문서가 specs_dir 밖에 있거나 source_interview 가 없으면 「spec 없음」이 된다(RC7).
  - 원장에 `Ruling:` 줄이 없으면 판정 「0개」가 된다(RC13).
  - SDD 가 아닌 작업 폴더는 지우기 전 확인에 잡히지 않는다(RC16).
  - `-design.md` 꼴이 아닌 파일은 리뷰 후보에 오르지 않는다(RC22).
- **경고는 내지만 판정이 틀리는 자리:** `### Task` 절이 없는 계획은 AC 전부를 「계획에 없음」으로 낸다(RC10).
- **형식을 가리지 않는 자리:** `ledger progress`(RC15), 품질 게이트의 의도 출처(RC27).

### 조사 14 — open-researcher · R11 · 묶음 8

(하니스 표시: 출력에 settings-json 꼴 문구가 있어 제어 태그를 무력화했다 — 설정 키 서술이고 지시가 아니다)

조사 주문: 재설계 전후 토큰 기준선을 지금 이 기계에서 무엇으로 잴 수 있는가. 확인한 날은 모두 2026-11-14 이다.

판: 레포가 기록한 Claude Code 판은 2.1.303 이다(plugins/spec-distill/dependencies.md:19, 2026-10-22 에 잼). 최신 upstream 은 2.1.323 이다(GitHub CHANGELOG.md 맨 위). npm 은 403 이라 stable/latest 태그 구분은 확인하지 못했다.

이 기계에서 확인한 것(레포 밖, 읽기만 함):
- `~/.claude/projects/-Users-jeonghokim-Downloads-devbrew/` 아래에 세션 기록과 `<session>/subagents/agent-*.jsonl` 이 실제로 있다(Glob 261건). worktree 세션은 `-Users-jeonghokim-Downloads-devbrew--claude-worktrees-<이름>/` 이라는 별도 프로젝트 폴더에 흩어져 있다(Glob 871건).
- `~/.claude/settings.json` 에 `cleanupPeriodDays` 와 `OTEL_*` 키가 없다. 기본 30일이 적용된다는 뜻이다.
- `~/.claude/stats-cache.json` 은 찾지 못했다.
- 파일 날짜는 Bash 가 없어 보지 못했다. 그래서 지난 로드맵 세션 중 무엇이 30일 안에 남아 있는지는 확인하지 못했다.

수단별 요약(아래 YAML 이 근거다):

| 수단 | 지휘 / 하위 구분 | 캐시읽기 · 캐시쓰기 · 새 입력 · 출력 구분 | 지난 세션 소급 |
|---|---|---|---|
| (1) /usage | 구독 귀속 표는 하위 agent 몫을 % 로 보인다 | 세션 블록만 네 칸을 가른다 | 24시간 · 7일 창까지 |
| (2) OTel | 됨 (query_source) | 됨 | 불가 |
| (3) mod | 됨 (e.agentId) | 됨 | 불가 |
| (4) `-p` json | modelUsage 만 하위 포함 | 됨 | 불가 |
| (5) 세션 기록 | 파일로 갈림 | 됨 (중복 제거 필요) | 유일하게 가능, 30일 한도 |

- (1) /usage: 구독 귀속 표는 하위 agent 몫을 % 로만 보이고 토큰 수는 보이지 않는다. 세션 블록은 지휘와 하위를 가르지 않는다.
- (2) OTel: 수집기 없는 파일 출력은 공식 문서에 없다. console 출력이 TUI 에서 보이는지는 불확실하다.
- (3) mod: 2.1.287 이상에서만 돈다.
- (4) `-p` json: usage 는 하위를 빼고, total_cost_usd 와 modelUsage 는 하위를 포함한다. 같은 일을 대화형이 아니라 headless 로 다시 돌려야 한다.
- (5) 세션 기록: 응답 하나가 content block 마다 같은 usage 를 되풀이하므로 message.id 로 중복을 빼야 한다. 출력 토큰은 placeholder 다. 2.1.293–2.1.306 의 하위 기록은 출력이 과소다. 30일 뒤 지워지므로 보관해야 한다.

```yaml
evidence:
  - url: "https://code.claude.com/docs/en/costs"
    supports: both
    claim: "구독 플랜의 /usage 에는 사용량 귀속 표가 있다. 최근 사용량을 skill · subagent · plugin · MCP 서버별로 전체 대비 % 로 보이고, d · w 키로 최근 24시간과 7일을 바꾼다. 원문: 'approximate and computed from local session history on this machine'. 세션 블록은 'Usage by model' 로 input · output · cache read · cache write 를 가르지만 /clear 때 0 으로 돌아가고, 지휘와 하위 agent 를 가르지 않는다. 'Prompt cache (main)' 줄은 'covers the main conversation only, not subagents' 다. 귀속 표는 % 만 내므로 7일보다 오래된 기준선이나 에픽 하나 단위는 잴 수 없다."
    touches: []
    decides: [OQ27, OQ26]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/anthropics/claude-code/refs/heads/main/CHANGELOG.md"
    supports: alternative
    claim: "/usage 정확도 수정이 레포 판보다 뒤에 나왔다. 2.1.311 은 'Fixed /usage never showing large prompt-cache misses', 2.1.323 은 'Fixed /usage showing a whole-session percentage beside a subagent type's name' 이다. 그래서 2.1.303 의 /usage 하위 agent 귀속 % 는 틀릴 수 있다."
    touches: []
    decides: [OQ27]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/91775"
    supports: alternative
    claim: "/usage 의 Stats 탭은 message.usage 를 기록 줄마다 더하고 message.id 로 중복을 빼지 않아 토큰 합계를 약 1.9–2.5배 부풀린다. 이슈는 열려 있고 2.1.322 에서도 재현이 보고됐다. stats-cache.json 은 지난 날을 다시 계산하지 않으므로 부푼 이력이 그대로 남는다. 댓글에 응답마다 쓰이는 'cost-state' 기록이 중복을 뺀 합계와 맞는다는 주장이 있으나 공식 문서로는 확인하지 못했다."
    touches: []
    decides: [OQ27]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/monitoring-usage"
    supports: current
    claim: "claude_code.token.usage 는 API 요청마다 늘어난다. type 은 input · output · cacheRead · cacheCreation 이고, input 에는 캐시 읽기 · 쓰기가 빠진다. query_source 는 main · subagent · auxiliary 중 하나다. 그래서 지휘와 하위, 네 칸이 모두 갈린다. 사용자 정의 agent 의 agent.name 은 OTEL_LOG_TOOL_DETAILS=1 이 아니면 'custom' 으로 가려진다(2.1.273 전에는 그 변수가 있어도 가려졌다). 이벤트의 agent_id · parent_agent_id 는 2.1.310 이상이 필요하므로 레포 판 2.1.303 에는 없다. CLAUDE_CODE_ENABLE_TELEMETRY=1 을 켠 뒤부터만 쌓이므로 지난 세션은 잴 수 없다. 레포의 .claude/settings*.json 에 둔 OTel 변수는 무시된다."
    touches: []
    decides: [OQ27, OQ26]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/monitoring-usage"
    supports: alternative
    claim: "수집기 없이 쓸 수 있는 exporter 로 console 과 prometheus(localhost:9464/metrics 를 긁어 가는 쪽이 필요하다)가 있다. 문서는 console 이 어디에 쓰는지(stdout · stderr · 파일)를 말하지 않고, 메트릭을 파일로 내는 exporter 도 없다. 파일로 남는 것은 OTEL_LOG_RAW_API_BODIES=file:<dir> 하나다. 이 옵션은 요청 · 응답 본문 전체를 .request.json · .response.json 으로 쓴다(본문 전체라 민감하다)."
    touches: []
    decides: [OQ27]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://claudeissues.com/issue/46338-bug-opentelemetry-not-emitting-in-non-interactive-p-mode"
    supports: alternative
    claim: "2차 미러 보고들이 서로 충돌한다. 대화형 TUI(ink)가 console 출력을 삼켜 console exporter 출력이 stdout 이나 리다이렉트에 남지 않는다는 보고가 있다. 반대로 -p 에서 console 이 token.usage 데이터 점을 stdout 에 찍는다는 보고(2.1.113)와 -p 에서 아무것도 나오지 않는다는 보고도 있다."
    touches: []
    decides: [OQ27]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/plugins/mods/events"
    supports: current
    claim: "turn.step 의 result.usage 는 요청마다 input_tokens · output_tokens · cache_read_input_tokens · cache_creation_input_tokens 와 model 을 담는다. 원문: 'The hook runs for subagents' requests too, so check e.agentId'. turn.complete 의 e.usage 는 턴 합계이고, 하위 agent 의 턴도 e.agentId 를 달고 발화한다. 그래서 지휘와 하위, 네 칸이 모두 갈린다. mod 는 $.fs.write 로 파일에 쓸 수 있다(원자 쓰기가 아니고 한 파일 4 MiB 까지). 설치한 뒤부터만 잰다."
    touches: []
    decides: [OQ26, OQ27]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/mods/overview"
    supports: both
    claim: "터미널에서 mod 는 v2.1.287 이상에서 기본으로 켜진다. claude -p 와 Agent SDK 에서도 훅은 돌지만 그리지는 않는다. disableAllHooks · --safe-mode · --bare 는 설치한 mod 를 끈다. mod 는 sandbox 밖에서 사용자 권한으로 돈다."
    touches: []
    decides: [OQ26, OQ27]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/mods/reference"
    supports: both
    claim: "$.session.usage() 는 { startedAt, context:{tokens, window, percent}, rateLimits, cost } 를 돌려준다. 컨텍스트 크기 · 창 · % 는 있지만 캐시 읽기와 새 입력은 가르지 않는다. 갈라 보려면 turn.step 의 result.usage 를 써야 한다. session.measure 는 매 턴 뒤와 플랜 한도 % 가 바뀔 때 발화한다. 이 reference 는 2.1.290(CLI)을 기준으로 쓰였다."
    touches: []
    decides: [OQ26]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/agent-sdk/cost-tracking"
    supports: both
    claim: "결과 칸마다 하위 agent 포함 여부가 다르다. usage 는 'Excluded'(최상위 루프만), total_cost_usd 는 'Included', modelUsage 는 'Included' 이고 모델별로 inputTokens · outputTokens · cacheReadInputTokens · cacheCreationInputTokens 를 준다. 원문: 'Use modelUsage ... for whole-tree token accounting'. 지휘와 하위를 따로 보려면 stream-json 의 parent_tool_use_id(지휘는 null)를 써야 한다. 단계별 output_tokens 는 placeholder 이고, 중복을 뺀 단계별 input 과 cache 값은 정확하다고 적혀 있다. total_cost_usd 는 클라이언트 쪽 추정이다."
    touches: []
    decides: [OQ27]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/headless"
    supports: alternative
    claim: "claude -p --output-format json 은 total_cost_usd 와 모델별 비용을 준다. --resume 으로 이으면 앞 실행분까지 더한 합계를 보고하고, 둘 다 'client-side estimates' 다. -p 세션은 세션 선택기에 나오지 않는다. --bare 를 쓰면 hooks · skills · plugins · CLAUDE.md 를 싣지 않는다. 그래서 같은 로드맵 에픽을 대화형과 같은 조건으로 재려면 --bare 없이 돌려야 하고, 지난 대화형 세션은 이 수단으로 소급할 수 없다."
    touches: []
    decides: [OQ27]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/sessions"
    supports: alternative
    claim: "세션 기록은 ~/.claude/projects/<project>/<session-id>.jsonl 에 있다. 원문: 'The entry format is internal to Claude Code and changes between versions, so scripts that parse these files directly can break on any release'. 보관 기간은 cleanupPeriodDays 로 바꾼다."
    touches: []
    decides: [OQ27]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/claude-directory"
    supports: both
    claim: "cleanupPeriodDays 는 기본 30일, 최소 1이고 0 은 검증 오류다. 지우는 대상은 <session>.jsonl, <session>/subagents/(원문: 'removed with the parent session transcript when it ages out'), tool-results/ 와 usage-data/ 등이다. stats-cache.json('Aggregated token and cost counts shown by /usage')은 지우지 않는다. --bare 실행에서는 정리 자체가 돌지 않는다. 30일 전에 남길 것은 메인 jsonl 과 subagents/ 폴더 전체이고, worktree 마다 다른 <project> 폴더도 포함한다. cleanupPeriodDays 를 올리면 이미 지워진 것은 돌아오지 않는다."
    touches: []
    decides: [OQ27]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/87303"
    supports: alternative
    claim: "세션 기록은 응답 하나를 content block 마다 assistant 항목으로 쓰고, 각 항목에 바이트까지 같은 usage 를 되풀이한다(측정: cache_read 1.59배, output 1.86배). 메인테이너(2026-08-17)는 이를 의도된 동작으로 보고 'consumers are expected to count each message.id once' 라고 답한 뒤 cost-tracking 문서를 가리키며 닫았다. 고친 판은 없다."
    touches: []
    decides: [OQ27]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/28197"
    supports: alternative
    claim: "JSONL 항목 75% 의 input_tokens 가 0 이나 1 인 placeholder 이고, 상태줄 합계보다 102–174배 작다는 보고다. 메인테이너 응답 없이 stale 로 닫혔다(not planned). 같은 보고에서 cache read · creation 은 상태줄과 약 1배로 맞았다. 그런데 공식 문서의 input 은 캐시를 뺀 새 입력이고(monitoring-usage), 중복을 뺀 단계별 input 과 cache 는 정확하다고 적혀 있다(cost-tracking). 그래서 이 '입력 placeholder' 주장은 캐시를 포함한 상태줄 total_input_tokens 와 비교한 오독일 수 있다. 공식 문서와 충돌하므로 둘 다 낸다."
    touches: []
    decides: [OQ27]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://github.com/anthropics/claude-code/issues/100381"
    supports: alternative
    claim: "2.1.293 부터 백그라운드 하위 agent 기록이 스트리밍 중의 usage 만 남긴다. stop_reason 은 null 이고 output_tokens 는 2–16 이라 하위 agent 출력이 과소 계수된다(최종 stop_reason 이 있는 비율: 2.1.289 99.5%, 2.1.293 40.5%). 이슈는 열려 있다. 그런데 CHANGELOG 2.1.307 에 'Fixed subagent transcripts recording placeholder token usage and an empty stop reason for streamed responses' 가 있다. 그래서 2.1.293–2.1.306 에 기록된 하위 기록은 출력이 과소일 공산이 크고, 레포 판 2.1.303 이 이 구간에 든다. 지난 로드맵 세션이 실제로 어느 판에서 돌았는지는 확인하지 못했다."
    touches: []
    decides: [OQ27]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: uncertain
  - url: "https://github.com/ryoppippi/ccusage/issues/913"
    supports: alternative
    claim: "/btw 가 subagents/ 아래에 agent-aside_question-*.jsonl 을 만들고 대화 전체를 cache_read 로 다시 싣는다. ccusage 가 이를 더해 /btw 한 번을 약 $10.28 로 보였다(상태줄 증가는 약 $0.08). 이 이슈는 2026-05-25 에 PR #1155 'fix(claude): dedupe sidechain replayed usage' 로 닫혔다. 이 보고는 ccusage 가 subagents/ 파일을 읽는다는 뜻이기도 하다."
    touches: []
    decides: [OQ27]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://github.com/ryoppippi/ccusage/issues/888"
    supports: alternative
    claim: "ccusage 18.0.10 은 message.id 와 requestId 를 키로 처음 본 항목을 남겼다. 첫 항목은 스트리밍 중간값이라 출력이 과소였다(하루치 130,785 대 648,562). 2026-05-17 에 닫혔고, 메인테이너는 'no longer uses simple first-seen-wins' 라며 더 완전한 기록을 남긴다고 했다. 연결된 PR 은 페이지에 보이지 않는다."
    touches: []
    decides: [OQ27]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://openskillindex.com/skills/tdimino-claude-code-minoan-claude-usage"
    supports: alternative
    claim: "3자 skill 문서가 'ccusage 가 {session}/subagents/*.jsonl 을 무시해 크게 과소 계수한다'고 주장한다. 바로 위 ccusage #913(subagents/ 의 aside 파일을 더해 과대 계수)과 충돌하고, ccusage 공식 문서(ccusage.com/guide/claude)는 subagents/ 처리를 말하지 않는다. 지금 판의 동작은 확인하지 못했다."
    touches: []
    decides: [OQ27]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://ccusage.com/guide/claude/"
    supports: alternative
    claim: "ccusage 는 ~/.config/claude/projects/ 와 ~/.claude/projects/ 를 읽고 CLAUDE_CONFIG_DIR(쉼표로 여러 개)로 바꿀 수 있다. 문서 스스로 'Claude Code can retain logs for only 30 days by default' 라고 적는다. 일반 가이드는 한계를 셋 적는다: 이 기계만 본다, Web Search 같은 도구 API 호출은 빠진다, 비용은 추정이다. 리포트는 daily · weekly · monthly · session · blocks 이고 캐시 생성과 읽기 토큰을 따로 보인다. 에픽 하나나 지휘 대 하위로 가르는 리포트는 문서에 없다."
    touches: []
    decides: [OQ27]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/statusline"
    supports: both
    claim: "상태줄 JSON 의 context_window.current_usage 는 마지막 API 호출의 input_tokens · cache_creation_input_tokens · cache_read_input_tokens 를 가른다. /compact 직후에는 null 이다. used_percentage 는 입력 셋의 합만으로 계산한다. prompt_cache 객체(2.1.251 이상)는 'doesn't count subagent requests' 다. cost.total_cost_usd 는 /clear 때 0 이 되는 클라이언트 추정이다. 하위 agent 를 합한 토큰 칸은 문서에 없다."
    touches: []
    decides: [OQ26, OQ27]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
repo_claims:
  - id: RC1
    path: "plugins/spec-distill/dependencies.md"
    anchor: "| claude-code | 2.1.303 | 2026-10-22 | 기록 | 잰 판을 기록만 한다 |"
    line: 19
    claim: "레포가 기록한 Claude Code 판은 2.1.303 이고 2026-10-22 에 쟀다. 이 판은 mod 바닥(2.1.287)보다 높고, OTel agent_id · parent_agent_id 바닥(2.1.310)과 하위 기록 placeholder 수정(2.1.307)보다는 낮다. 지금 이 기계에 깔린 판은 따로 재지 않았다."
    touches: []
    decides: [OQ27]
  - id: RC2
    path: "docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md"
    anchor: "input_tokens 에 스트리밍 placeholder(1)가 남고"
    line: 351
    claim: "이 인터뷰가 앞서 적은 위험 문장은 input_tokens placeholder 를 사실로 싣는다. 공식 cost-tracking 문서는 중복을 뺀 단계별 input 과 cache 가 정확하고 placeholder 는 output_tokens 라고 한다. 이 문장은 그 공식 문서와 충돌한다(근거는 #28197 · cost-tracking 항목)."
    touches: []
    decides: [OQ27]
  - id: RC3
    path: "docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md"
    anchor: "ccusage 가 {session}/subagents/{agent}.jsonl 을 무시해 크게 과소 계수한다는 보고가 있다(3자 출처, uncertain)."
    line: 429
    claim: "앞 조사가 실은 ccusage 하위 agent 과소 계수 주장은 3자 출처다. 1차 출처인 ccusage #913 은 ccusage 가 subagents/ 파일을 읽어 과대 계수했고 #1155 에서 중복 제거로 고쳤다고 보인다. 두 주장이 충돌한다."
    touches: []
    decides: [OQ27]
  - id: RC4
    path: "docs/superpowers/plans/2026-09-27-qg-public-contract-pr5.md"
    anchor: "init 의 `plugins` 목록과 `total_cost_usd` 를 `observations.md` 에 적어"
    line: 855
    claim: "레포에는 headless 실행의 total_cost_usd 를 관찰 기록에 남긴 선례가 있다(qg PR5 스파이크, 약 $0.23). 이 선례가 하위 agent 포함 여부나 modelUsage 의 캐시 칸 구분을 다루지는 않는다."
    touches: []
    decides: [OQ27]
unanswered: "확인하지 못한 것은 다섯이다. (1) console exporter 가 대화형 TUI 에서 어디로 출력되는지 — 공식 문서에 없고 2차 보고끼리 충돌한다. (2) 이 기계의 지난 로드맵 세션 기록 날짜, 남은 일수, 그 세션들이 돈 Claude Code 판 — Bash 가 없어 파일 날짜를 보지 못했다. (3) stats-cache.json 의 실제 위치 — ~/.claude 에서 찾지 못했다. (4) ccusage 최신 판과 지금 판의 subagents/ 처리 방식. (5) 로드맵 에픽 하나를 단위로 전후를 비교하는 기성 도구 — 찾지 못했다. ccusage 는 날짜 · 세션 · 5시간 블록 단위만 준다."
```

출처:
- [costs](https://code.claude.com/docs/en/costs)
- [monitoring-usage](https://code.claude.com/docs/en/monitoring-usage)
- [statusline](https://code.claude.com/docs/en/statusline)
- [sessions](https://code.claude.com/docs/en/sessions)
- [claude-directory](https://code.claude.com/docs/en/claude-directory)
- [headless](https://code.claude.com/docs/en/headless)
- [agent-sdk cost-tracking](https://code.claude.com/docs/en/agent-sdk/cost-tracking)
- [mods overview](https://code.claude.com/docs/en/plugins/mods/overview)
- [mods events](https://code.claude.com/docs/en/plugins/mods/events)
- [mods reference](https://code.claude.com/docs/en/plugins/mods/reference)
- [Claude Code CHANGELOG](https://raw.githubusercontent.com/anthropics/claude-code/refs/heads/main/CHANGELOG.md)
- [claude-code #87303](https://github.com/anthropics/claude-code/issues/87303)
- [claude-code #28197](https://github.com/anthropics/claude-code/issues/28197)
- [claude-code #100381](https://github.com/anthropics/claude-code/issues/100381)
- [claude-code #91775](https://github.com/anthropics/claude-code/issues/91775)
- [ccusage #913](https://github.com/ryoppippi/ccusage/issues/913)
- [ccusage #888](https://github.com/ryoppippi/ccusage/issues/888)
- [ccusage README](https://github.com/ryoppippi/ccusage)
- [ccusage guide](https://ccusage.com/guide/)
- [ccusage guide/claude](https://ccusage.com/guide/claude/)
- [openskillindex claude-usage (2차)](https://openskillindex.com/skills/tdimino-claude-code-minoan-claude-usage)
- [claudeissues 46338 미러 (2차)](https://claudeissues.com/issue/46338-bug-opentelemetry-not-emitting-in-non-interactive-p-mode)

### 조사 13 — open-researcher · R11 · 묶음 8

```yaml
evidence:
  # --- Thrum ---
  - url: "https://raw.githubusercontent.com/thrum-team/thrum/main/docs/sync.md"
    supports: alternative
    claim: "Thrum 은 `a-sync` 이라는 orphan 브랜치에 메시지를 둔다. `thrum init` 이 이 브랜치를 plumbing 명령으로 빈 트리에서 만든다. 그래서 main · 코드 브랜치와 공통 이력이 없다. JSONL 은 `.git/thrum-sync/a-sync/` 의 전용 sync worktree 에 산다. 이 경로는 `git rev-parse --git-common-dir` 로 푼다. 문서 원문은 'There is no `git checkout` or branch switching on the main working tree' 이다. 파일 배치는 `events.jsonl`(append-only 생명주기 이벤트)과 `messages/{agent_name}.jsonl`(agent 마다 파일 하나, 경합을 줄이는 목적)이다. 이벤트마다 전역 유일 `event_id`(ULID)가 붙고, 병합은 git merge 가 아니라 이 ID 로 중복을 걸러 내는 append-only JSONL 병합이다. 문서는 'Conflicts cannot occur' 라고 주장한다. push 가 non-fast-forward 로 거절되면 fetch+merge 뒤 최대 3번 다시 시도하고, 그래도 거절되면 실패한다. rebase 는 쓰지 않는다. 루프는 60초마다 fetch → merge → project → notify(구독자 채널) → commit → push 를 돈다. 원격 동기화는 기본으로 꺼져 있다(`local_only: true`). 보존 · 정리 정책은 문서에 없다. `.thrum/` 은 .gitignore 에 들어간다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "레포에 없음(이 레포는 Thrum 을 쓰지 않음)", latest: "v0.10.6 안정(Latest) · v0.10.7-rc.2 시험판(6월 30일, 연도 표기 없음)"}
    certainty: confirmed
  - url: "https://github.com/thrum-team/thrum"
    supports: alternative
    claim: "Thrum 의 라이선스는 MIT 다. README 는 메시지를 '전용 orphan 브랜치'에 두고 'no merge conflicts with your code' 라고 적는다. 상태는 SQLite 이고, 기계 간 전달은 git push/pull 또는 Tailscale P2P 다. 마지막 커밋은 2026-11-05 다(저작권자를 THRUM LLC 로 바꾼 커밋). 릴리스는 '-rc.N 으로 48시간 이상 시험한 뒤 안정판' 방식이다. 문서 사이트는 thrum.team 이고, 옛 사이트 leonletto.github.io/thrum 의 sync · architecture 페이지는 지금 404 다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://thrum.team/docs/sync.html"
    supports: alternative
    claim: "공식 사이트의 sync 문서는 문제 해결 안내다. git 원격 동기화가 기본으로 꺼져 있고, 원격에 메시지를 두면 그 원격에 접근할 수 있는 누구나 agent 메시지를 읽는다고 경고한다. 동기화 주기 · 충돌 처리 내부는 이 페이지에 없다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed

  # --- Beads ---
  - url: "https://github.com/steveyegge/beads"
    supports: alternative
    claim: "지금 판의 Beads 는 JSONL 이 정본이 아니다. 저장은 Dolt 다. 내장 모드는 쓰는 이가 하나이고, 서버 모드(`bd init --server`)는 여러 쓰는 이를 받는다. 기계 간 동기화는 `bd dolt push/pull` 이 git 원격의 `refs/dolt/data` 에 한다. `.beads/issues.jsonl` 은 'not the source of truth or a backup' 인 내보내기다. 해시 ID(`bd-a1b2`)는 여러 agent · 여러 브랜치에서 병합 충돌을 막는다고 적혀 있다. 라이선스는 MIT 다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "레포에 없음", latest: "v1.3.4(Latest, 11월 4일) · v1.4.0-rc.2(11월 13일)"}
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/steveyegge/beads/main/docs/reference/protected-branches.md"
    supports: alternative
    claim: "옛 판에는 `sync.branch` 모드(예: `beads-sync` 브랜치)가 있었다. `.git/beads-worktrees/` 아래 숨은 worktree 로 별도 브랜치에 커밋하는 방식이었다. 이 모드는 '더 이상 beads 에 없다'(removed). 남은 숨은 worktree 가 브랜치 checkout 을 막는 문제를 정리하는 안내가 있다. 지금 모델에서는 이슈 명령이 코드 브랜치에 커밋하지 않고, 코드는 평소 PR 흐름을 탄다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://pkg.go.dev/github.com/steveyegge/beads@v0.21.9"
    supports: alternative
    claim: "옛 판(v0.21.9) 문서에서는 'Source of truth is JSONL (`.beads/issues.jsonl`, committed to git)' 이었다. 기계마다 gitignore 된 SQLite 캐시를 두고, 5초 debounce 로 JSONL 을 내보냈다. 보호 브랜치용으로 `bd init --branch beads-metadata`(별도 동기화 브랜치)가 있었다. ID 는 'generated from random data' 라서 동시 생성에 충돌이 없다고 적혀 있고, 그래도 충돌하면 해시를 7~8자로 늘린다. issues.jsonl 충돌을 푸는 절차는 이 페이지에 없다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://beads.gascity.com/architecture"
    supports: alternative
    claim: "[2차 — 공식 여부를 페이지가 밝히지 않음, gastownhall/beads 로 연결됨] ID 를 'content-derived hashes' 라고 적는다. 위 v0.21.9 의 'random data' 와 엇갈린다(둘 다 냄). Dolt 의 셀 단위 병합이 대부분의 충돌을 자동으로 풀지만, 여러 clone 에서 동시에 동기화하면 race condition 이 날 수 있다고 경고한다."
    touches: []
    decides: [OQ21]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://newreleases.io/project/github/steveyegge/beads/release/v0.49.4"
    supports: alternative
    claim: "[2차 · 검색 요약] JSONL 시절 Beads 는 `bd init` 때 `.gitattributes` 에 `bd merge` 병합 드라이버를 등록했다. v0.49.4 릴리스 노트에는 이 드라이버가 이슈 칸을 조용히 버리던 버그의 수정이 있다. 릴리스 날짜는 확인하지 못했다."
    touches: []
    decides: [OQ21]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain

  # --- git refs 에 데이터 (git-bug, git-appraise, git notes) ---
  - url: "https://raw.githubusercontent.com/git-bug/git-bug/master/doc/design/data-model.md"
    supports: alternative
    claim: "git-bug 는 엔티티를 `refs/<namespace>/<id>` 아래의 커밋 사슬로 둔다. 커밋마다 연산 묶음(JSON blob)이 달린다. 최종 상태 대신 연산을 쌓고, Lamport clock 으로 부분 순서를 매긴다. 동시 편집은 pack id 의 사전순으로 정한다. 이력이 갈라지면 merge commit 에 해당하는 것을 만들어 'without conflict' 로 합친다. pull 은 로컬 ref 를, fast-forward push 는 원격 ref 를 앞으로 민다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://github.com/git-bug/git-bug"
    supports: alternative
    claim: "git-bug 는 'no files are added in your project' 이다. 동기화는 `git bug push/pull`, GitHub · GitLab · Jira 브리지가 있다. 라이선스는 GPLv3 이상이다. 최신판은 v0.12.0 이다(Latest, 2026-11-07 — 연도는 자산 시각으로 판단). 웹 UI 는 WIP 다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "레포에 없음", latest: "v0.12.0"}
    certainty: confirmed
  - url: "https://github.com/google/git-appraise"
    supports: alternative
    claim: "git-appraise 는 리뷰 데이터를 git notes(`refs/notes/devtools/reviews` 등)에 둔다. 항목 하나를 JSON 한 줄로 써서 `cat_sort_uniq` 전략으로 notes 를 자동 병합한다. 동기화는 `git appraise push/pull` 이고 서버 쪽 구성 요소가 필요 없다. 라이선스는 Apache-2.0 이다. 마지막 커밋은 2023-08-12 다(커밋 페이지). 보관(archived) 표시는 없다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://git-scm.com/docs/git-notes"
    supports: alternative
    claim: "git notes 는 객체(보통 커밋)에 붙는 blob 이다. 바꿀 때마다 notes ref(기본 `refs/notes/commits`)에 새 커밋이 생긴다. 병합 전략 기본값은 `manual` 이고, 이때 `.git/NOTES_MERGE_WORKTREE` 에서 손으로 푼다. 선택지로 ours · theirs · union · cat_sort_uniq 가 있다. notes 는 반드시 어떤 객체에 붙는다. 그래서 그 자체로 «편지함»이 되려면 붙일 대상 객체가 따로 있어야 한다(이 문장은 추론)."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "git 2.54.0(plugins/spec-distill/dependencies.md 측정값)", latest: "git-notes 페이지 2.50.0 이후 변경 없음, 2.56.1 까지 표기"}
    certainty: confirmed
  - url: "https://git-scm.com/book/en/v2/Git-Internals-The-Refspec"
    supports: alternative
    claim: "`git remote add` 가 쓰는 기본 fetch refspec 은 `+refs/heads/*:refs/remotes/origin/*` 이다. 즉 브랜치만 받는다. 다른 이름공간(refs/notes · refs/bugs · refs/dolt 등)은 refspec 을 더하거나 명시 push/fetch 해야 오간다. notes 에 대한 직접 예시는 이 페이지에 없다. 그 부분은 일반 지식이다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://github.blog/news-insights/the-library/git-notes-display/"
    supports: alternative
    claim: "GitHub 는 2014-08-14 갱신에서 git notes 를 웹에 보여 주는 기능을 끊었다고 밝혔다('no longer supported'). git notes · 사용자 정의 refs 에 둔 글은 GitHub 웹에서 사람이 볼 수 없다. 출처는 검색 결과 요약이고 블로그 본문은 직접 열지 않았다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain

  # --- git 기본 동작: 원자성 · 거절 · worktree ---
  - url: "https://git-scm.com/docs/git-push"
    supports: both
    claim: "브랜치(`refs/heads/*`)로 하는 push 는 fast-forward 만 허용한다. 그 밖에는 'rejected' 로 아무것도 보내지 않는다. `--atomic` 은 원격에서 '모든 ref 가 갱신되거나 하나도 안 된다'. `--force-with-lease=<ref>:<expect>` 는 원격 값이 기대값일 때만 덮어쓴다. 기대값을 비우면 'ref 가 아직 없어야 한다'는 조건이 된다. 커밋 하나에 글 하나를 담으면 ref 갱신 단위로 원자적으로 보이고, 반쯤 보이는 글은 생기지 않는다(이 문장은 추론). 동시에 쓰면 진 쪽이 non-fast-forward 거절을 받고 fetch 후 다시 시도해야 한다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "git 2.54.0(dependencies.md)", latest: "git-push 페이지 2.55.0(2026-06-29) 갱신"}
    certainty: confirmed
  - url: "https://git-scm.com/docs/git-worktree"
    supports: both
    claim: "`git worktree add` 는 브랜치가 이미 다른 worktree 에 checkout 돼 있으면 기본으로 거절한다(`-f` 로 넘김). `refs/` 로 시작하는 ref 는 worktree 사이에 공유되고 HEAD 는 worktree 마다 따로다. 한 기계에서 여러 worktree 가 같은 전용 데이터 브랜치를 쓰려면 checkout 을 하나로 모아야 한다(Thrum 은 common-dir 아래 sync worktree 하나) 또는 plumbing(commit-tree/update-ref)으로 checkout 없이 써야 한다(이 문장은 추론)."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "git 2.54.0(dependencies.md)", latest: "git-worktree 페이지 2.56.0 갱신"}
    certainty: confirmed
  - url: "https://git-scm.com/docs/gitattributes"
    supports: alternative
    claim: "내장 `merge=union` 드라이버는 충돌 표지 없이 양쪽 줄을 모두 취한다. 문서는 'tends to leave the added lines in the resulting file in random order and the user should verify the result. Do not use this if you do not understand the implications.' 라고 경고한다. append-only 한 파일에 여럿이 쓰는 꼴을 이것으로 풀면 충돌은 조용해지지만 순서는 보장되지 않는다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "git 2.54.0(dependencies.md)", latest: "gitattributes 페이지 2.56.0 갱신"}
    certainty: confirmed

  # --- «한 글 한 파일» 선례 ---
  - url: "https://about.gitlab.com/blog/solving-gitlabs-changelog-conflict-crisis/"
    supports: alternative
    claim: "GitLab(2018-07-03)은 여러 MR 이 CHANGELOG 한 파일에 줄을 더하며 'constantly see merge conflicts' 를 겪었다. 빈 자리 미리 두기는 'lessened, but not solved' 였다. 해법은 'Each changelog entry would be its own YAML file' 로 unreleased 폴더에 한 항목 한 파일을 두고, 릴리스 때 모아 Markdown 으로 컴파일한 뒤 지우는 것이다. 파일 이름 규칙(기계 · 시각 · 해시)은 글에 없다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://docs.gitlab.com/development/changelog/"
    supports: alternative
    claim: "GitLab 의 지금 방식은 파일 조각도 아니다. CHANGELOG.md 항목을 'generated from the subject line of a Git commit' 으로, `Changelog` git trailer 가 붙은 커밋에서 만든다. 공유 파일에 손으로 쓰지 않고 git 이력에서 계산해 쓰는 쪽으로 옮겨 갔다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://towncrier.readthedocs.io/en/stable/"
    supports: alternative
    claim: "towncrier 는 'having one single file which developers all write to and produce merge conflicts' 를 피하려고 변경마다 작은 news fragment 파일을 둔다. 릴리스 때 조각을 모으고 지우는 절차는 이 페이지에 없다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://public-inbox.org/public-inbox-v2-format.html"
    supports: alternative
    claim: "public-inbox(메일링 리스트를 git 에 두는 도구)는 메일을 blob 으로 둔다. 커밋 트리마다 최상위 파일이 하나다('m' 저장 또는 'd' 삭제, 동시에 둘은 없음). 이력은 약 1GB 단위의 epoch 저장소로 나눠 보존 · 복제 범위를 가른다. 삭제는 'd' 에 쓰는 것으로 기록한다. 비원자 연산에는 inbox.lock 에 flock 배타 잠금을 쓴다. 이 잠금은 한 기계의 파일시스템 잠금이다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed

  # --- 전용 브랜치에 push 재시도 · 쓰는 이 하나 ---
  - url: "https://raw.githubusercontent.com/benchmark-action/github-action-benchmark/master/README.md"
    supports: alternative
    claim: "github-action-benchmark 는 결과를 gh-pages 브랜치의 `dev/bench/data.js` 한 파일에 합쳐 auto-push 한다. 보존은 `max-items-in-chart` 이고, 넘으면 가장 오래된 것을 지운다. push 충돌 재시도 · 동시 작업 처리는 README 에 적혀 있지 않다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/stefanzweifel/git-auto-commit-action/master/README.md"
    supports: alternative
    claim: "git-auto-commit-action 은 'will not do a `git pull` before doing the `git push`' 이고 rebase · merge 를 지원하지 않는다. 최신 유지는 사용자 책임이다. matrix 처럼 병렬로 돌면 저장소가 낡아 push 가 실패할 수 있다고 적는다. GITHUB_TOKEN 커밋은 워크플로를 다시 깨우지 않고, PAT 커밋은 무한 루프가 날 수 있다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/control-the-concurrency-of-workflows-and-jobs"
    supports: alternative
    claim: "GitHub Actions concurrency group 은 'at most one running job or workflow in a concurrency group at any time' 이다. 기본으로 대기 중인 것은 하나이고, 새로 들어오면 기존 대기는 취소된다. `cancel-in-progress: true` 이면 도는 것까지 취소한다. «계산해 쓰는 STATUS.md 를 쓰는 이를 하나로 정함»을 서버 쪽에서 하는 선례 장치다."
    touches: []
    decides: [OQ21, OQ13]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches"
    supports: both
    claim: "리뷰 필수 보호가 켜진 브랜치에는 협업자가 'only push changes to a protected branch via a pull request' 할 수 있다. bypass 목록은 조직 소유 저장소에서만 쓸 수 있고, 관리자는 기본으로 우회한다. 규칙은 이름이나 fnmatch 패턴으로 브랜치를 고른다. 그래서 main 을 보호하면 STATUS.md · inbox 를 main 에 바로 push 하는 기계 커밋은 막히거나 우회가 필요하다. 보호 패턴에 들지 않는 전용 데이터 브랜치는 영향을 받지 않는다(이 문장은 추론)."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://docs.github.com/en/repositories/working-with-files/managing-files/customizing-how-changed-files-appear-on-github"
    supports: current
    claim: "생성 파일을 커밋할 때 `.gitattributes` 의 `linguist-generated` 로 표시하면 GitHub diff 에서 기본으로 숨겨진다. 계산해 쓴 STATUS.md 를 PR 에 실어 커밋하는 길에서 리뷰 소음을 줄이는 장치다. 충돌 자체를 막지는 않는다."
    touches: []
    decides: [OQ21, OQ13]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed

  # --- GitHub Issues / Discussions 를 정본으로 ---
  - url: "https://docs.github.com/en/rest/issues/comments"
    supports: alternative
    claim: "이슈 댓글 생성은 API 호출 하나다. 서버가 순서를 정하므로 git 병합 충돌 개념이 없다(이 문장은 추론). 생성은 'triggers notifications' 이고 'Creating content too quickly … may result in secondary rate limiting' 이다. 읽는 쪽은 `since`('last updated after the given time') 로 폴링해 새 글을 안다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "gh 2.88.1(plugins/spec-distill/dependencies.md 측정값)", latest: "확인 안 함"}
    certainty: confirmed
  - url: "https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api"
    supports: alternative
    claim: "REST 2차 한도는 'no more than 80 content-generating requests per minute and no more than 500 content-generating requests per hour' 이고 동시 요청 100 이다. 이슈 · 댓글을 편지함으로 쓰면 이 한도가 쓰기 상한이다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://docs.github.com/en/graphql/guides/using-the-graphql-api-for-discussions"
    supports: alternative
    claim: "Discussions 는 GraphQL API 로 만들기 · 읽기 · 고치기 · 지우기를 하고(`addDiscussionComment` 등), 저장소당 카테고리는 25개까지다. REST 지원 여부는 이 페이지에 없다. 비공개 저장소에는 `repo` 범위 토큰이 필요하다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed

repo_claims:
  - id: RC1
    path: "CLAUDE.md"
    anchor: "## Git Workflow — 「GitHub Flow. `main`에서 분기, PR로 merge back.」 · 「PR: merge commit」"
    claim: "이 레포의 흐름은 main 에서 feature/fix/docs/chore 브랜치를 따고, PR 을 merge commit 으로 되돌리는 GitHub Flow 다. inbox/ · STATUS.md 를 이 흐름 안(작업 브랜치 → PR)에 두면 머지 단위로만 다른 기계에 보인다. 흐름 밖에 두려면 이 절이 다루지 않는 자리(전용 브랜치 · 다른 refs · 외부)가 필요하다."
    touches: []
    decides: [OQ21]
  - id: RC2
    path: "docs/git-workflow/branch-strategy.md"
    anchor: "## Rules for Claude — 「**NEVER** `main`에 직접 commit」 · 「**ALWAYS** 기존 feature 브랜치는 `git merge origin/main`으로 sync, `git rebase`는 절대 안 됨. rebase는 commit SHA를 rewrite — push된 브랜치에 unsafe.」"
    line: 75
    claim: "main 직접 커밋은 금지다. 그래서 지휘자가 STATUS.md · inbox 글을 main 에 바로 push 하는 꼴은 이 규칙과 부딪힌다. rebase 금지는 «기존 feature 브랜치를 main 과 맞출 때» 범위로 적혀 있다. 전용 데이터 브랜치에서 push 전에 rebase 하고 다시 시도하는 꼴이 이 금지에 드는지는 문서가 정하지 않는다. 브랜치 이름 패턴 `^(feature|fix|docs|chore)/…$` 도 장수 데이터 브랜치(예: Thrum 의 `a-sync`)를 예상하지 않는다."
    touches: []
    decides: [OQ21]
  - id: RC3
    path: "docs/git-workflow/pr-process.md"
    anchor: "## Server-Side Enforcement — 「`main` (또는 보호 대상 브랜치) protection 권장 설정」 · 「**Do not allow force pushes**」"
    line: 63
    claim: "레포는 main 에 PR 리뷰 필수 · status check · force push 금지 보호를 권한다. 이 권장대로면 기계가 main 에 직접 쓰는 길은 서버에서도 막힌다. 보호 대상이 아닌 별도 브랜치나 refs 는 이 권장 밖이다."
    touches: []
    decides: [OQ21]
  - id: RC4
    path: "CLAUDE.md"
    anchor: "### 런타임 상태 & 훅 — 「로드맵 단위 지휘 기계 상태(`machine.md`)」 · 「인터뷰처럼 세션을 넘는 진행 기록은 docs 의 추적 파일에 두고 산출물과 함께 커밋한다」"
    claim: "machine.md 는 `.claude/<plugin>/` 아래 git-ignored 런타임 상태다. 세션을 넘는 기록은 docs 추적 파일로 «산출물과 함께» 커밋한다. 이 규칙은 «추적 파일 = 작업 브랜치 커밋 → PR» 을 기본으로 둔다. 기계 사이에 머지 없이 공유하는 추적 상태는 다루지 않는다."
    touches: []
    decides: [OQ21, OQ13]
  - id: RC5
    path: "plugins/spec-distill/scripts/state_path.py"
    anchor: "def state_root_for_common — 「이름이 `.git` 이면 그 부모(<main_repo>/.claude/spec-distill)」"
    line: 73
    claim: "지휘 상태 루트는 `git rev-parse --git-common-dir` 로 정해진다. 그래서 같은 기계의 모든 worktree 가 메인 레포 쪽 한 자리를 공유한다. Thrum 의 sync worktree 를 common-dir 아래(`.git/thrum-sync/a-sync/`)에 두는 것과 같은 원리다. 다만 이 자리는 git-ignored 이고 기계 밖으로 나가지 않는다."
    touches: []
    decides: [OQ21, OQ13]
  - id: RC6
    path: "plugins/spec-distill/scripts/roadmap_status.py"
    anchor: "모듈 docstring — 「읽기만 한다 — 파일을 쓰지 않고 네트워크에 나가지 않는다.」 · NOTICE 「번호 기록은 기계 상태라 이 기계에만 있다.」"
    line: 16
    claim: "레포에는 이미 «현황을 파일로 커밋하지 않고 읽을 때 git 에서 계산하는» 선례가 있다. roadmap_status.py 가 그것이고, fetch 는 지휘 절차가 계산 전에 한다. 같은 스크립트의 공지는 PR 번호 기록이 기계 상태라 다른 기계에는 없다고 밝힌다. 기계 간 현황이 갈리는 지점이 이미 이 자리에 공시돼 있다. 계산해 쓴 STATUS.md 를 커밋하는 S17 과, 커밋하지 않고 읽을 때 계산하는 대안 사이의 판단에 닿는다."
    touches: []
    decides: [OQ13, OQ21]
  - id: RC7
    path: "plugins/spec-distill/dependencies.md"
    anchor: "| git | 2.54.0 | 2026-10-22 | 멈춤 | … · | gh | 2.88.1 | 2026-10-22 | 멈춤 | …"
    line: 15
    claim: "이 레포가 측정한 판은 git 2.54.0 · gh 2.88.1 이고 둘 다 강도 「멈춤」이다. git plumbing · refspec · `--atomic` 길과 GitHub Issues/Discussions 길은 새 도구 의존 없이 이 둘 위에서 가능하다. Thrum · Beads(Dolt) · git-bug · git-appraise 는 새 의존이다."
    touches: []
    decides: [OQ21]

unanswered: "(1) Thrum 의 공식 문서(sync.md)는 같은 agent 파일(`messages/<agent>.jsonl`)에 두 기계가 동시에 쓸 때의 git 수준 병합 방식(커스텀 병합인지 · git archive 추출인지)과 3번 재시도 뒤 실패의 회복 절차, 보존 · 정리를 다루지 않는다. (2) Beads 의 ID 생성 근거는 옛 판 문서(무작위)와 2차 사이트(내용 유도 해시)가 엇갈리고, 지금 공식 README 는 «해시 기반»이라고만 적는다. `bd merge` 드라이버의 현재 존속 여부도 확인하지 못했다. (3) «전용 브랜치에 rebase 하고 다시 시도해 push 하는 꼴»을 설계 원칙으로 문서화한 1차 자료는 찾지 못했다. 찾은 선례(Thrum)는 rebase 가 아니라 fetch+merge 재시도다. (4) 계산해 쓴 현황 파일을 여러 쓰는 이가 커밋할 때의 일반 지침 문서는 찾지 못했다. 선례로 모은 것은 쓰는 이 하나(Actions concurrency) · 이력에서 계산(GitLab trailer · 레포의 roadmap_status.py) · 조각 파일(towncrier · GitLab 옛 방식) · 생성 표시(linguist-generated)다. (5) GitHub 의 git notes 웹 표시 중단(2014)은 검색 요약으로만 확인했고 원문 블로그는 직접 열지 않았다."
```

출처:
- [Thrum sync.md](https://raw.githubusercontent.com/thrum-team/thrum/main/docs/sync.md) · [Thrum repo](https://github.com/thrum-team/thrum) · [Thrum releases](https://github.com/thrum-team/thrum/releases) · [thrum.team sync](https://thrum.team/docs/sync.html)
- [Beads repo](https://github.com/steveyegge/beads) · [Beads protected-branches](https://raw.githubusercontent.com/steveyegge/beads/main/docs/reference/protected-branches.md) · [Beads git-integration](https://raw.githubusercontent.com/steveyegge/beads/main/docs/reference/git-integration.md) · [Beads v0.21.9](https://pkg.go.dev/github.com/steveyegge/beads@v0.21.9) · [beads.gascity.com (2차)](https://beads.gascity.com/architecture) · [newreleases v0.49.4 (2차)](https://newreleases.io/project/github/steveyegge/beads/release/v0.49.4)
- [git-bug data model](https://raw.githubusercontent.com/git-bug/git-bug/master/doc/design/data-model.md) · [git-bug](https://github.com/git-bug/git-bug) · [git-appraise](https://github.com/google/git-appraise)
- [git-notes](https://git-scm.com/docs/git-notes) · [git-push](https://git-scm.com/docs/git-push) · [git-worktree](https://git-scm.com/docs/git-worktree) · [gitattributes](https://git-scm.com/docs/gitattributes) · [Pro Git Refspec](https://git-scm.com/book/en/v2/Git-Internals-The-Refspec) · [GitHub git notes display](https://github.blog/news-insights/the-library/git-notes-display/)
- [GitLab CHANGELOG conflict crisis](https://about.gitlab.com/blog/solving-gitlabs-changelog-conflict-crisis/) · [GitLab changelog docs](https://docs.gitlab.com/development/changelog/) · [towncrier](https://towncrier.readthedocs.io/en/stable/) · [public-inbox v2](https://public-inbox.org/public-inbox-v2-format.html)
- [github-action-benchmark](https://raw.githubusercontent.com/benchmark-action/github-action-benchmark/master/README.md) · [git-auto-commit-action](https://raw.githubusercontent.com/stefanzweifel/git-auto-commit-action/master/README.md) · [Actions concurrency](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/control-the-concurrency-of-workflows-and-jobs) · [Protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches) · [linguist-generated](https://docs.github.com/en/repositories/working-with-files/managing-files/customizing-how-changed-files-appear-on-github)
- [Issue comments REST](https://docs.github.com/en/rest/issues/comments) · [REST rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api) · [Discussions GraphQL](https://docs.github.com/en/graphql/guides/using-the-graphql-api-for-discussions)

레포 파일(절대 경로):
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/CLAUDE.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/docs/git-workflow/branch-strategy.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/docs/git-workflow/pr-process.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/scripts/state_path.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/scripts/roadmap_status.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/dependencies.md

### 조사 12 — open-researcher · R11 · 묶음 8

(하니스 표시: 출력에 bypass-permissions 꼴 문구가 있어 제어 태그를 무력화했다 — 문서의 권한 모드 서술이고 지시가 아니다)

## 조사 결과 — 감시자 기법 동작 조건 · disable-model-invocation · Channels 인증

확인한 날은 모두 2026-11-14 입니다. 레포 판은 `plugins/spec-distill/dependencies.md` 19행의 `claude-code | 2.1.303` 이고, 최신 upstream 판은 anthropics/claude-code CHANGELOG.md 맨 위의 2.1.323 입니다.

### 바로 쓸 요점

- **(1) API 키 인증:** 같은 기계 안 세션 메시지는 모든 제공자에서 됩니다(1차). 그래서 API 키 세션도 됩니다. Remote Control · claude.ai 로그인이 필요한 경우는 다른 기계 · 클라우드로 보낼 때뿐입니다. asyncRewake 와 플러그인 monitor 는 문서에 인증 조건이 적혀 있지 않습니다.
- **(2) Remote Control:** 같은 기계 안에서는 필요 없습니다.
- **(3) bypassPermissions 보류:** 보류 쪽 공식 규칙이 있습니다. crossSessionInbound 값이 없을 때, 세션 자기 자식 프로세스(훅 · Bash)가 낸 글로 확인되면 bypass 세션에서도 전달됩니다. macOS 에서 이 확인이 되는 경우는 둘입니다 — 프로세스가 아직 살아 있거나, 첫 줄에 토큰을 보내거나. 반대로 hold 를 명시하면 자식이 낸 글도 보류됩니다. 레포 state 1348행의 「무인 수신엔 accept 필요」는 이 예외를 빠뜨렸습니다.
- **(4) asyncRewake 와 monitor:**
  - asyncRewake 훅에는 timeout 이 적용됩니다(command 기본 600초).
  - 훅은 이벤트마다 한 번씩 따로 돕니다. 스스로 반복하지 않습니다.
  - `-p` · 데스크톱에서는 동기로 돌고, 종료 코드 2 가 버려진다는 이슈(#89960)가 열려 있습니다.
  - 플러그인 monitor 는 세션 내내 돌며 문서상 기한이 없습니다.
  - monitor 출력이 쉬는 세션의 새 턴을 연다는 것은 공식 문서에 명시돼 있지 않습니다. 2차 자료만 그렇다고 말합니다.
  - 텔레메트리를 끄면 monitor 하한이 2.1.310 이 되어 레포 판 2.1.303 보다 높습니다.
- **(나) disable-model-invocation skill:**
  - 하위 agent 의 Skill 도구 호출은 거부됩니다. 프롬프트 맨 앞에 `/이름` 을 적으면 오류 없이 무시된다는 이슈가 열려 있습니다.
  - 세션 메시지 안의 `/명령` 도 실행되지 않습니다.
  - 공식 길은 `claude -p "/플러그인:skill 인자"` 입니다. 다만 disable-model-invocation skill 로 실제로 되는지는 실측하지 못했습니다.
- **Channels 인증:** claude.ai 와 Console API 키 둘 다 됩니다. 1차 문서와 changelog 2.1.128 이 같은 말을 합니다. 「claude.ai 로그인만」이라는 제3자 글은 2.1.128 이전 기준입니다.

```yaml
evidence:
  # ── (가) 세션 자체 받은 편지함 소켓 ──
  - url: "https://code.claude.com/docs/en/cross-session-messaging"
    supports: current
    claim: "같은 기계 세션 메시지는 Bedrock · Claude Platform on AWS · Agent Platform · Foundry 를 포함한 «모든 제공자»에서 되고, feature-flag fetching 이 꺼진 세션에서도 된다(그 경우 v2.1.248+). Anthropic 서버를 거치지 않는 세션별 소켓으로 간다. Remote Control 과 claude.ai 로그인은 «이 기계 밖» 세션(다른 기계 · 클라우드)을 찾을 때만 필요하고, API 키로는 그 세션들을 찾을 수 없다. → 소켓 길은 API 키 인증에서도, Remote Control 없이도 된다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/cross-session-messaging"
    supports: current
    claim: "받는 세션이 쉬고 있으면 Claude Code 가 그 메시지로 새 턴을 연다(활성 턴이면 도구 호출 사이에 읽는다). 소켓 경로는 CLAUDE_CODE_MESSAGING_SOCKET, 토큰은 CLAUDE_CODE_MESSAGING_TOKEN 으로 훅 · Bash 에 내보낸다(SessionStart 전부터). 첫 줄 {\"type\":\"auth\",\"token\":\"<token>\"} 은 macOS · Linux 에서는 선택, 네이티브 Windows 에서는 필수다. 30초 안에 완전한 한 줄을 보내지 않으면 연결을 닫으므로, 느린 명령의 출력은 먼저 모은 뒤 연결한다. bare 모드는 소켓을 만들지 않는다. claude -p 는 소켓을 만든다."
    touches: []
    decides: [OQ21, OQ30]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/cross-session-messaging"
    supports: both
    claim: "[bypassPermissions 보류 · 자기 자식 예외] crossSessionInbound 값이 없으면 두 세션의 권한 모드 등급으로 정한다 — 받는 세션이 bypass 면 보낸 쪽도 bypass 일 때만 전달하고 아니면 승인 대기로 보류한다. 예외: 값이 없을 때, 세션 자신의 자식 프로세스(자기 세션 소켓에 글을 넣는 훅 · Bash)에서 온 것으로 확인된 메시지는 전달한다. Linux 는 자식이 끝난 뒤에도 프로세스 증거로 확인한다. macOS 는 글을 넣는 프로세스가 살아 있을 때만 프로세스 증거로 확인하고, 끝난 뒤에는 auth 줄의 토큰으로 확인한다. 둘 다 안 되면 등급 없는 메시지로 취급해 bypass 세션은 보류한다. 소켓 글도 같은 inbound 통제를 거친다(예외는 이것 하나)."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/settings-reference"
    supports: both
    claim: "crossSessionInbound = accept | hold | refuse. 기본값은 없음(메시지마다 결정). 읽는 순서는 managed → --settings → user 이고 처음 찾은 값을 쓴다. 엄격한 순서는 refuse > hold > accept. project · local 값은 더 엄격할 때만 적용된다 — 신뢰 출처가 값을 정하지 않았을 때 project 의 hold · refuse 는 적용되지만 project 의 accept 는 효과가 없다. /config 행은 v2.1.232+. 잘못된 값은 v2.1.248+ 에서 경고하고 보류한다. 자기 자식 예외는 «값이 없을 때»만 서므로, hold 를 명시하면 자식이 낸 글도 보류된다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/cross-session-messaging"
    supports: both
    claim: "기본 규칙이 보류한 메시지의 처리. 대화형: 승인 창을 열고 dialogExpiry(기본 5분) 뒤 닫으며 버린다. 터미널이 안 붙은 백그라운드 세션: 붙기 전까지 창을 연 채 둔다. -p: 기한까지 보관하다 버리고 «expired» 로 보고한다. dialogExpiry=\"never\" 면 세션이 끝날 때까지 보관한다. 명시적 hold 로 묶인 글은 만료되지 않는다. 보류는 최대 100건(넘으면 오래된 것부터 버림), 받아 둔 메시지는 최대 50건 대기, 보낸 쪽별 속도 제한과 짧은 시간 동일 반복 버림이 있다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/env-vars"
    supports: current
    claim: "기능별 최소 판(1차 문서): CLAUDE_CODE_MESSAGING_SOCKET v2.1.224+, CLAUDE_CODE_MESSAGING_TOKEN v2.1.228+. 둘 다 Claude Code 가 세팅하고 settings env 블록으로는 못 정하며, 부모 세션 것을 물려받지 않는다."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md"
    supports: current
    claim: "changelog 근거. 2.1.224: cross-session SendMessage 추가, bypass 세션으로 보낸 메시지는 승인 대기로 보류(crossSessionInbound 도입). 2.1.232: /config 「Messages from your other sessions」. 2.1.236: notify_when_idle. 2.1.243: 30초 무입력 연결 닫기. 2.1.248: Bedrock · Vertex · Foundry · 텔레메트리 끔에서도 같은 기계 메시지. 2.1.271: 권한 모드 정책으로 보류된 메시지가 흔적 없이 남던 문제 수정. 2.1.288: 보류된 메시지를 «delivered» 로 보고하던 문제 수정. 2.1.290: --restricted 세션이 소켓을 여는 문제 수정. 2.1.309+(레포 판보다 위): 전사 끝의 «Waiting to be delivered» 목록."
    touches: []
    decides: [OQ21]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://github.com/PeterSR/claude-code-socket-transport"
    supports: alternative
    claim: "[2차] 소켓에 넣는 «메시지 줄»의 프레임 형식(msgV · msg_id · type · message.content · priority now|next|later · from · session_id — session_id 가 받는 세션과 다르면 버린다)은 공식 문서에 없고 바이너리에서 읽은 것이다. v2.1.233 에서 검증했고, «공개 인터페이스가 아니어서 어느 릴리스에서든 바뀔 수 있다»고 README 가 적는다. 공식 문서가 정하는 것은 auth 첫 줄뿐이다."
    touches: []
    decides: [OQ21]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain

  # ── (가) asyncRewake 훅 ──
  - url: "https://code.claude.com/docs/en/hooks"
    supports: both
    claim: "asyncRewake: true 는 백그라운드로 돌고 종료 코드 2 에서 Claude 를 깨운다. stderr(비면 stdout)를 system reminder 로 보인다. async 훅 출력은 원래 다음 턴에 배달되고 idle 이면 다음 사용자 상호작용까지 기다리지만, 예외로 asyncRewake 훅이 종료 코드 2 로 끝나면 idle 세션도 즉시 깨운다. async 훅에는 timeout 을 강제하지 않지만 asyncRewake 훅에는 강제한다(command 기본 600초, 훅마다 timeout 필드로 조정). 실행할 때마다 별도 백그라운드 프로세스를 만든다. 스스로 반복하는 장치는 없고, 이벤트가 올 때마다 한 번 돈다. 그래서 「몇 분마다 git fetch」는 훅 안에서 timeout 안쪽으로 반복하거나, 다시 발화할 이벤트에 묶어야 한다. 문서에 asyncRewake 의 인증 · Remote Control 조건은 없다."
    touches: []
    decides: [OQ21, OQ30]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/hooks"
    supports: alternative
    claim: "-p 모드에서는 teardown 때 아직 도는 async 훅을 죽이고 결과를 cancelled 로 마감한다. 훅의 일이 -p 세션보다 오래 살아야 하면 완전히 분리된 프로세스를 띄우라고 한다."
    touches: []
    decides: [OQ30]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/89960"
    supports: alternative
    claim: "[열린 버그, 메인테이너 답 없음] asyncRewake 는 문서와 달리 비대화형(-p · 데스크톱 stream-json)에서 async 를 함의하지 않아 동기로 돈다. 이 경로에서는 종료 코드 2 가 «non-blocking hook error» 로 기록되고 모델 메시지가 되지 않는다. 대화형 TUI 에서는 블록하지 않고 종료 코드 2 가 모델을 깨운다(2.1.284 macOS 댓글). 2.1.246(Windows) · 2.1.284 · 2.1.300(Linux, PostToolUse)에서 재현됐다. 우회는 \"async\": true 를 함께 주는 것인데, 그러면 깨우기를 잃는다."
    touches: []
    decides: [OQ30]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md"
    supports: both
    claim: "asyncRewake 의 도입 판은 changelog(2.0.32~2.1.323 훑음)와 hooks 문서 어디에도 없다. 2.1.246 에 이미 있었다(#89960). changelog 에 이름이 나오는 줄은 2.1.287 하나다: 스크립트 파일이 없을 때 asyncRewake 훅이 «found issues» 알림으로 Claude 를 계속 깨우던 문제를 고쳐 한 번만 보고. 관련 async 판: 2.1.295 async 훅 여러 줄 JSON 출력 · async SessionStart 같은 맥락 재주입 수정."
    touches: []
    decides: [OQ30]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: uncertain

  # ── (가) 플러그인 monitor ──
  - url: "https://code.claude.com/docs/en/plugins/components"
    supports: both
    claim: "플러그인 monitor(monitors/monitors.json 또는 experimental.monitors)는 세션 시작(또는 when: on-skill-invoke:<skill>)부터 세션 끝까지 백그라운드로 도는 셸 명령이고, 출력이 Claude 에 알림으로 간다. -p 에서는 시작하지 않는다(대화형 전용). 샌드박스 밖에서 사용자 권한으로 돈다. ${user_config.*} 와 CLAUDE_PLUGIN_OPTION_* 를 받지 않는다. 플러그인을 세션 중에 꺼도 이미 도는 monitor 는 세션 끝까지 남는다. Bedrock · AWS · Agent Platform · Foundry 이거나, DISABLE_TELEMETRY · CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 가 켜져 feature-flag fetching 이 꺼지면 v2.1.310+ 이 필요하다. 이 경우 레포 판 2.1.303 은 하한 미달이다. 문서에 claude.ai 로그인 조건은 없다."
    touches: []
    decides: [OQ30]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/tools-reference"
    supports: both
    claim: "Monitor «도구»(Claude 가 띄우는 감시)는 기본 5분 · 최대 30분 · -p 최대 10분의 기한이 있고, 기한에 끝나면 Claude 가 알림 한 번을 받아 다시 띄울 수 있다. 「Claude interjects when an event arrives」라고 쓰지만, 쉬는 세션의 새 턴을 여는지는 명시하지 않는다. 플러그인 monitor 쪽에는 이 기한 문구가 없다(세션 내내). 도입 판: Monitor 도구 2.1.98, 플러그인 monitor 2.1.105(최상위 monitors 키), 2.1.129 부터 experimental 아래로 옮김."
    touches: []
    decides: [OQ30]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/77300"
    supports: current
    claim: "[이슈 본문 — 사용자 진술, 메인테이너 확인 없음] «main session is not affected — its Monitor events re-invoke it between turns, as documented». 깨우기 결함은 agent 팀 teammate · 하위 agent 쪽에만 있다(2.1.206 · 2.1.250 · 2.1.301 에서 재현, 열림). → 메인 세션에서는 monitor 이벤트가 턴을 다시 연다는 간접 근거다. 공식 문서 문장으로는 확인하지 못했다."
    touches: []
    decides: [OQ30]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://nikiforovall.blog/ai/2026/08/21/claude-code-plugin-monitors.html"
    supports: current
    claim: "[2차 블로그] 플러그인 monitor 의 한 줄이 알림 하나가 되고 «The notification wakes the session into a turn» 이라고 종단 실행 스크린샷과 함께 주장한다. 대화형 CLI 전용이고 실험 기능이라 형식이 예고 없이 바뀔 수 있다고 적는다. 시험한 Claude Code 판 · 인증 방식은 밝히지 않았다."
    touches: []
    decides: [OQ30]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://github.com/anthropics/claude-code/issues/92264"
    supports: alternative
    claim: "[열린 버그] 쉬는 «백그라운드 세션»(claude agents)과 초점 없는 대화형 탭에서 세션 전체가 멈춰(«no timers run, no streams advance») 하위 agent 완료가 사람이 열거나 키를 칠 때까지 배달되지 않는다(2.1.260~2.1.286). monitor · 훅은 이슈에서 다루지 않았다. 그래도 «쉬는 세션 깨우기»를 백그라운드 세션에 기댈 때의 위험 신호다."
    touches: []
    decides: [OQ30]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain

  # ── (나) disable-model-invocation skill ──
  - url: "https://code.claude.com/docs/en/skills"
    supports: current
    claim: "disable-model-invocation: true 면 Claude 가 스스로 부를 수 없다. Claude 가 시도하면 Claude Code 가 호출을 막고 다른 방법으로 같은 단계를 재현하지 말라고 지시한다. 설명은 맥락에 올리지 않는다. 하위 agent 에 preload 할 수 없고, 세션 범위 예약 작업의 프롬프트로도 돌지 않는다. 사람이 메시지 맨 앞에 /이름 을 쓰면 직접 실행된다. 평문 뒤의 /이름 은 실행하지 않고 «그 메시지에 한한 허가»가 된다(사람 입력에 대한 규칙). 하위 agent 의 Skill 도구 호출에 이 차단이 적용되는지는 skills 문서가 명시하지 않는다."
    touches: []
    decides: [OQ30]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/sub-agents"
    supports: current
    claim: "하위 agent 는 Skill 도구로 등록되지 않은 project · user · plugin skill 도 부를 수 있다. 다만 disable-model-invocation skill 은 «preloading draws from the same set of skills Claude can invoke» 라서 preload 할 수 없다고 적는다. 곧 하위 agent 가 부를 수 있는 집합에 그 skill 은 없다. Agent 도구 프롬프트 안의 /명령 처리 여부는 문서에 없다. initialPrompt(--agent 로 메인 세션 agent 일 때)만 명령 · skill 을 처리한다."
    touches: []
    decides: [OQ30]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/77795"
    supports: current
    claim: "[열린 버그, 2.1.210, 메인테이너 답 없음] Agent 도구 프롬프트가 /my-workflow(disable-model-invocation) 로 시작해도 하위 agent 는 평문으로 받고 자기 판단으로 진행한다. Skill 호출이 전사에 없고 경고 · 오류도 없다(«inert by construction, and nothing says so»). → 「하위 agent 프롬프트에 /명령을 적는 것」은 통하지 않고, 조용히 실패한다."
    touches: []
    decides: [OQ30]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/93761"
    supports: current
    claim: "Skill 도구가 disable-model-invocation skill 을 거부할 때의 실제 문구(2.1.269, 메인 세션): «Skill <plugin>:<name> cannot be used with Skill tool due to disable-model-invocation. Ask the user to run /<plugin>:<name> themselves — it cannot be invoked via the Skill tool. Do not replicate this skill's workflow by other means — it is reserved for explicit user invocation.» 관련 #95469(쌓은 skill 의 2번째 이후 위치는 거부)는 열림이다. 페이지가 504 로 열리지 않아 검색 요약으로만 확인했다."
    touches: []
    decides: [OQ30]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/headless"
    supports: alternative
    claim: "[지휘자가 실행하게 할 공식 길] -p 모드에서 «User-invoked skills and custom commands work. Include /skill-name in the prompt string and Claude Code expands it before running.» 쌓으면 첫 skill 만 올리고 나머지 줄은 인자가 된다. 프롬프트로 띄운 forked skill 의 메시지 스트림은 v2.1.287+. 곧 지휘자가 Bash 로 `claude -p \"/<plugin>:<skill> <인자>\"` 를 띄우는 것이 문서화된 길이다. 이것이 disable-model-invocation skill 로 실제로 되는지는 실측하지 않았다 — 사람 입력도 막혔다는 옛 이슈(#26251 · #38969 · #86676)가 있다."
    touches: []
    decides: [OQ30]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/cross-session-messaging"
    supports: alternative
    claim: "다른 세션이 보낸 메시지 안의 명령(/compact 등)은 평문으로 도착하고 «Claude Code never executes it». 승인 · 설정 변경도 할 수 없다. → 소켓 · SendMessage 로 /skill 을 보내 지휘자가 실행하게 하는 길은 없다."
    touches: []
    decides: [OQ30]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md"
    supports: both
    claim: "disable-model-invocation 관련 판. 2.1.110: 평문 중간 /<skill> 호출 실패 수정. 2.1.133: 하위 agent 가 Skill 도구로 project · user · plugin skill 을 못 찾던 문제 수정. 2.1.222: 거부 시 사용자에게 실행을 부탁하도록 개선. 2.1.287: 평문 중간에 친 /skill 이름도 skill 이라고 Claude 에 알림(disable-model-invocation 포함)."
    touches: []
    decides: [OQ30]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed

  # ── Channels 인증 충돌 판정 ──
  - url: "https://code.claude.com/docs/en/channels"
    supports: current
    claim: "Channels(연구 미리보기)는 «claude.ai 또는 Console API 키» Anthropic 인증이 필요하고 Bedrock · Agent Platform · Foundry 에서는 안 된다. 개인 Pro · Max · Ultra(조직 없음)는 조직 검사를 건너뛴다. claude.ai Team · Enterprise 는 Owner 가 켜기 전까지 막힌다. Console API 키 인증은 기본 허용이지만, managed settings 를 배포한 조직은 channelsEnabled: true 가 필요하다. 어느 경우든 세션마다 --channels 로 켜야 하고, 미리보기 기간에는 허용 목록 플러그인만 등록된다."
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md"
    supports: current
    claim: "[충돌 판정] 2.1.128: «`--channels` now works with console (API key) authentication» (managed settings 가 있는 Console 조직은 channelsEnabled: true 필요). 도입은 2.1.80(연구 미리보기), 권한 릴레이는 2.1.81. 「claude.ai 로그인만」이라는 제3자 README · 글은 2.1.128 이전 상태를 적은 것이고, 레포 판 2.1.303 은 API 키 지원 판보다 위다."
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://claudeissues.com/issue/57442-bug-v2-1-132-notifications-claude-channel-rendered-to-prompt-but-not-auto-submit"
    supports: alternative
    claim: "[2차 미러 · 검색 요약] Channels 알림이 쉬는 REPL 의 턴을 열지 못한다는 보고가 여럿 있다(#57442 v2.1.132 «rendered to prompt but not auto-submitted», #44380 · #45404 · #48404 · #59499). 현재 판의 상태 · 수정 여부는 확인하지 못했다."
    touches: []
    decides: []
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain

repo_claims:
  - id: RC1
    path: "plugins/spec-distill/dependencies.md"
    anchor: "| claude-code | 2.1.303 | 2026-10-22 | 기록 | 잰 판을 기록만 한다 |"
    line: 19
    claim: "레포가 잰 Claude Code 판은 2.1.303(강도 «기록»)이다. 기능별 하한과 대조하면: 소켓 2.1.224 · 토큰 2.1.228 · crossSessionInbound /config 2.1.232 · notify_when_idle 2.1.236 · Channels API 키 2.1.128 · 플러그인 monitor 2.1.105 는 넘는다. 텔레메트리 · 비필수 트래픽 끔 또는 비 Anthropic 제공자에서의 monitor 하한 2.1.310 과 «Waiting to be delivered» 2.1.309 는 못 넘는다. asyncRewake 하한은 문서에 없다."
    touches: []
    decides: [OQ30]
  - id: RC2
    path: "docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md"
    anchor: "무인 수신에는 `crossSessionInbound: accept` 설정이 필요합니다."
    line: 1348
    claim: "이전 조사 요약은 bypassPermissions 지휘자의 무인 수신에 accept 가 필요하다고만 적는다. 공식 문서에는 «값이 없을 때 자기 자식 프로세스(훅 · Bash)가 낸 글은 bypass 세션에서도 전달» 예외가 있다. macOS 에서는 글을 넣는 프로세스가 살아 있거나 토큰 auth 줄이 있어야 확인된다. 그래서 감시자가 «자기 세션 소켓»에 넣는 길에는 이 문장이 그대로 맞지 않는다. 다른 세션 · 다른 프로세스 트리에서 넣는 글에는 맞는다."
    touches: []
    decides: [OQ21]
  - id: RC3
    path: "docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md"
    anchor: "출력이 idle 세션의 새 턴을 여는지는 문서로 확인하지 못했다."
    line: 1494
    claim: "이전 조사가 플러그인 monitor 의 idle 깨우기를 미확인으로 남겼다. 이번에도 공식 문서 문장으로는 확인하지 못했다. 근거는 2차뿐이다 — #77300 본문의 «main session ... re-invoke it between turns, as documented» 와 블로그."
    touches: []
    decides: [OQ30]
  - id: RC4
    path: "plugins/plugin-audit/skills/plugin-audit/SKILL.md"
    anchor: "사용자가 `/plugin-audit:plugin-audit` 를 부른 것이 이 Workflow 의 명시 요청이다. 모델은 이 skill 을 부르지 않는다(`disable-model-invocation: true`)."
    line: 236
    claim: "레포에 disable-model-invocation: true 인 진입 skill 이 있다(plugin-audit SKILL.md 10행, project-init SKILL.md 7행). plugin-audit 은 사람의 /호출을 Workflow 의 명시 요청으로 쓴다. 지휘자가 이런 skill 을 하위 agent 에 맡기면 Skill 도구에서 거부되거나(프롬프트에 /이름) 조용히 무시된다. -p 로 띄우면 «사람의 /호출»과 같은 지위인지가 이 문장의 전제와 닿는다."
    touches: []
    decides: [OQ30]

unanswered: "다음은 확인하지 못했다. (a) asyncRewake 의 도입 판과 timeout 상한 — 문서 · changelog 에 없다. (b) asyncRewake · 플러그인 monitor 의 인증 조건 — 문서가 말하지 않으므로 API 키 세션에서도 된다는 것은 추론이다. (c) 플러그인 monitor 출력이 쉬는 메인 세션의 새 턴을 연다는 공식 문서 문장. (d) `claude -p \"/<disable-model-invocation skill>\"` 가 현재 판에서 실제로 실행되는지(실측 없음). (e) 소켓 메시지 줄의 공식 형식 — 비공개, 제3자 역공학뿐. (f) #95469 본문 — 504 로 열지 못했다."
```

### Sources

- [Cross-session messaging (1차)](https://code.claude.com/docs/en/cross-session-messaging)
- [Hooks reference (1차)](https://code.claude.com/docs/en/hooks)
- [Env vars (1차)](https://code.claude.com/docs/en/env-vars)
- [Settings reference (1차)](https://code.claude.com/docs/en/settings-reference)
- [Plugin components (1차)](https://code.claude.com/docs/en/plugins/components)
- [Plugin manifest reference (1차)](https://code.claude.com/docs/en/plugins-reference)
- [Tools reference (1차)](https://code.claude.com/docs/en/tools-reference)
- [Skills (1차)](https://code.claude.com/docs/en/skills)
- [Subagents (1차)](https://code.claude.com/docs/en/sub-agents)
- [Headless / -p (1차)](https://code.claude.com/docs/en/headless)
- [Channels (1차)](https://code.claude.com/docs/en/channels)
- [CHANGELOG.md (1차)](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
- 이슈 [#89960](https://github.com/anthropics/claude-code/issues/89960) · [#77795](https://github.com/anthropics/claude-code/issues/77795) · [#93761](https://github.com/anthropics/claude-code/issues/93761) · [#77300](https://github.com/anthropics/claude-code/issues/77300) · [#92264](https://github.com/anthropics/claude-code/issues/92264) · [#95469(미열람)](https://github.com/anthropics/claude-code/issues/95469)
- 2차: [claude-code-socket-transport](https://github.com/PeterSR/claude-code-socket-transport) · [nikiforovall 블로그](https://nikiforovall.blog/ai/2026/08/21/claude-code-plugin-monitors.html) · [claudeissues #57442 미러](https://claudeissues.com/issue/57442-bug-v2-1-132-notifications-claude-channel-rendered-to-prompt-but-not-auto-submit)

### 관련 레포 파일

- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/dependencies.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/plugin-audit/skills/plugin-audit/SKILL.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/project-init/skills/project-init/SKILL.md

## R11

### 지금 이해
포화 판정 1 의 빈 곳 다섯을 조사(묶음 8: 조사 11–14, 서로 기대지 않아 함께). 빈 곳 1 의 frontmatter 는 본체가 원문으로 확인(to-tickets · implement · implement-spec · grill-me · figure-it-out = disable-model-invocation, code-review · tdd = 아님). 시간 급한 일로 세션 기록 보관을 먼저 물음(S31) — 백업 완료: ~/.claude/transcript-backup/devbrew-2026-11-14 · jsonl 2,579개(원본 2,579개와 같음) · 3.5G. 이 기계 설치 판 2.1.323(claude --version).
- 확인 RC104 — 미확인 — plugins/spec-distill/scripts/repo_defaults.py#def _folder — 70행 앵커 «def _folder» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC105 — 미확인 — plugins/spec-distill/scripts/repo_defaults.py#SDD_WORKSPACE — 23행 앵커 «SDD_WORKSPACE» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC106 — 확인 — plugins/spec-distill/scripts/roadmap_status.py#def spec_line_path — 307행 앵커 «def spec_line_path» 실재, 주장 내용의 구현 대조는 하지 않음 — 321–322행 plan_specs 를 R8 에서 읽어 「**Spec:** 줄만 센다」 일치
- 확인 RC107 — 미확인 — plugins/spec-distill/scripts/roadmap_status.py#def branch_plans — 341행 앵커 «def branch_plans» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC108 — 미확인 — plugins/spec-distill/references/conducting.md#계획 없음 — 14행 앵커 «계획 없음» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC109 — 미확인 — plugins/spec-distill/scripts/roadmap_status.py#def trailer_after — 222행 앵커 «def trailer_after» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC110 — 미확인 — plugins/spec-distill/scripts/roadmap_status.py#def find_specs — 325행 앵커 «def find_specs» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC111 — 미확인 — plugins/spec-distill/scripts/roadmap_status.py#def started — 726행 앵커 «def started» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC112 — 미확인 — plugins/spec-distill/scripts/check_bundle_coverage.py#def specs_for — 115행 앵커 «def specs_for» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC113 — 미확인 — plugins/spec-distill/scripts/check_bundle_coverage.py#startswith("### Task") — 500행 앵커 «startswith("### Task")» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC114 — 미확인 — plugins/spec-distill/scripts/check_bundle_coverage.py#보고에 AC 판정 줄이 없다 — 587행 앵커 «보고에 AC 판정 줄이 없다» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC115 — 미확인 — plugins/spec-distill/scripts/conductor_state.py#def ledger_rulings — 388행 앵커 «def ledger_rulings» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC116 — 미확인 — plugins/spec-distill/scripts/control_plane.py#def _rulings — 997행 앵커 «def _rulings» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC117 — 미확인 — plugins/spec-distill/scripts/conductor_ledger.py#보고에도 원장에도 판정이 없다 — 842행 앵커 «보고에도 원장에도 판정이 없다» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC118 — 미확인 — plugins/spec-distill/scripts/conductor_ledger.py#def c_progress — 1349행 앵커 «def c_progress» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC119 — 미확인 — plugins/spec-distill/scripts/conductor_ledger.py#def dirty_lines — 154행 앵커 «def dirty_lines» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC120 — 미확인 — plugins/spec-distill/references/conducting.md#BLOCKED — 50행 앵커 «BLOCKED» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC121 — 미확인 — plugins/spec-distill/references/conductor-dispatch.md#CHECKPOINT — 73행 앵커 «CHECKPOINT» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC122 — 미확인 — plugins/spec-distill/references/conductor-dispatch.md#finishing-a-development-branch — 24행 앵커 «finishing-a-development-branch» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC123 — 미확인 — plugins/spec-distill/skills/epic-conductor/SKILL.md#superpowers 가 필요하다 — 64행 앵커 «superpowers 가 필요하다» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC124 — 미확인 — plugins/spec-distill/skills/epic-conductor/SKILL.md#code-reviewer.md — 173행 앵커 «code-reviewer.md» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC125 — 미확인 — plugins/spec-distill/skills/spec-review/SKILL.md#*-design.md — 193행 앵커 «*-design.md» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC126 — 미확인 — plugins/spec-distill/scripts/spec_review_bundle.py#source_interview 가 없다 — 75행 앵커 «source_interview 가 없다» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC127 — 미확인 — plugins/spec-distill/scripts/roadmap_status.py#def approval_of — 352행 앵커 «def approval_of» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC128 — 미확인 — plugins/spec-distill/references/roadmap-ontology.md#**Spec:** — 23행 앵커 «**Spec:**» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC129 — 미확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#superpowers 가용성 — 281행 앵커 «superpowers 가용성» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC130 — 미확인 — plugins/quality-gates/scripts/discover-spec.sh#Spec: — 4행 앵커 «Spec:» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC131 — 미확인 — plugins/plugin-audit/scripts/check-integrity.sh#.superpowers/* — 109행 앵커 «.superpowers/*» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC132 — 미확인 — plugins/spec-distill/tests/test_repo_literals.sh#docs/superpowers — 38행 앵커 «docs/superpowers» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC133 — 미확인 — plugins/spec-distill/tests/test_control_plane.sh#SDD ledger — 533행 앵커 «SDD ledger» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC134 — 미확인 — plugins/spec-distill/dependencies.md#| claude-code | 2.1.303 — 19행 앵커 «| claude-code | 2.1.303» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC135 — 미확인 — docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md#crossSessionInbound: accept — 1348행 앵커 «crossSessionInbound: accept» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC136 — 미확인 — docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md#idle 세션의 새 턴을 여는지는 문서로 확인하지 못했다 — 1494행 앵커 «idle 세션의 새 턴을 여는지는 문서로 확인하지 못했다» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC137 — 미확인 — plugins/plugin-audit/skills/plugin-audit/SKILL.md#disable-model-invocation: true — 10행 앵커 «disable-model-invocation: true» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC138 — 미확인 — CLAUDE.md#GitHub Flow — 12행 앵커 «GitHub Flow» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC139 — 미확인 — docs/git-workflow/branch-strategy.md#main`에 직접 commit — 75행 앵커 «main`에 직접 commit» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC140 — 미확인 — docs/git-workflow/pr-process.md#force push — 68행 앵커 «force push» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC141 — 미확인 — CLAUDE.md#산출물과 함께 커밋한다 — 70행 앵커 «산출물과 함께 커밋한다» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC142 — 미확인 — plugins/spec-distill/scripts/state_path.py#def state_root_for_common — 73행 앵커 «def state_root_for_common» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC143 — 미확인 — plugins/spec-distill/scripts/roadmap_status.py#네트워크에 나가지 않는다 — 16행 앵커 «네트워크에 나가지 않는다» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC144 — 미확인 — plugins/spec-distill/dependencies.md#| gh | — 16행 앵커 «| gh |» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC145 — 미확인 — plugins/spec-distill/dependencies.md#| claude-code | 2.1.303 — 19행 앵커 «| claude-code | 2.1.303» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC146 — 미확인 — docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md#input_tokens 에 스트리밍 placeholder(1)가 남고 — 351행 앵커 «input_tokens 에 스트리밍 placeholder(1)가 남고» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC147 — 미확인 — docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md#ccusage 가 {session}/subagents/{agent}.jsonl 을 무시해 — 429행 앵커 «ccusage 가 {session}/subagents/{agent}.jsonl 을 무시해» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC148 — 미확인 — docs/superpowers/plans/2026-09-27-qg-public-contract-pr5.md#total_cost_usd — 855행 앵커 «total_cost_usd» 실재, 주장 내용의 구현 대조는 하지 않음
- 대체됨: 「세션 기록 input_tokens 에 스트리밍 placeholder(1)가 남는다」(조사 3) → 공식 cost-tracking 문서는 중복 뺀 단계별 input · cache 는 정확하고 placeholder 는 output_tokens 라 함 (조사 14)
- 대체됨: 「ccusage 가 subagents/*.jsonl 을 무시해 과소 계수」(조사 3, 3자 출처) → 1차 ccusage #913 은 subagents/ 를 읽어 과대 계수했고 #1155 로 중복 제거 수정 (조사 14)
- 대체됨: 「bypassPermissions 지휘자의 무인 수신엔 crossSessionInbound: accept 필요」(조사 6) → 값이 없으면 세션 자기 자식 프로세스(훅 · Bash · monitor)가 자기 소켓에 넣은 글은 bypass 에서도 전달, macOS 는 프로세스 생존 또는 토큰 auth 줄 (조사 12)
- 웹: 조사 12–14 의 공식 문서 · changelog 인용은 본체 재확인 안 함(디스크 사실만 본체 확인 — 설치 판 · 기록 날짜 · 백업 개수)
조사 호출 14/60 · 이 라운드 본체 직접 3

### 다음 결정
OQ33 superpowers 형식 결합 처리 · OQ21(S17 재개방 포함) 편지함 · STATUS 의 git 자리

### 질문
(b) 둘 묶음

### 답
→ S32 (OQ33 devbrew 파일 기준) · S33 (OQ21 — 데이터 브랜치보다 로드맵 지휘자 브랜치, 에픽을 거기서 취합하는 안과 상황별 트레이드오프 요청) → 팀 상태 배치와 기계 간 조정 재개방: S17 의 커밋 자리가 main 직접 커밋 금지와 충돌

## R12

### 지금 이해
S33 질문에 직접 답함 — 지금은 에픽마다 main 에 머지(의존 에픽은 쌓인 PR · 「차례로」, conducting.md 걸음 3 · 5 의 41 · 62행). 취합 안과 지금 방식을 상황 9개로 비교(독립 · 의존 · 여럿 다른 파일 · 여럿 같은 파일 · 로드맵 간 의존 · 긴 로드맵 · 핫픽스 · 중단 · 리뷰 장치). 편지함 · STATUS 를 지휘자 브랜치에 둘 때의 득실. 코드 취합과 소통 자리를 따로 정하자고 권함.
조사 호출 14/60 · 이 라운드 본체 직접 1
사실로 보고 직접 답한 질문 1개 — 지금 main 에 계속 머지하나 · 에픽마다 main, 의존 에픽은 쌓인 PR

### 다음 결정
OQ34 코드 취합 · OQ21 소통 자리

### 질문
(b) 둘 묶음

### 답
→ S34 (OQ34) · S35 (OQ21) — 팀 상태 배치와 기계 간 조정 다시 닫힘(S35)

### 판정 2 — saturation-judge · R12 (조사 블록 아님 — 판정 원문)

```yaml
verdict: not_saturated
novelty:
  - n: 1
    changed: []
    opened: "첫 결정 축 10개 — 걷어낼 장치 · 플랫폼 대 파일 규약 · 일꾼 실행 방식 · 역할 경계 · 믿음 경계 · 토큰 · P8 · 기계 간 조정 · 상태 배치 · 사람이 보는 면(OQ2–OQ10 의 바탕)"
    failed: false
  - n: 2
    changed: [OQ2]
    opened: 없음
    failed: false
  - n: 3
    changed: [OQ3, OQ4, OQ5, OQ6]
    opened: "역할 폴더 CLAUDE.md 는 자동으로 실리지 않는다 — 일꾼이 읽게 하는 길(OQ7)"
    failed: false
  - n: 4
    changed: [OQ3, OQ4]
    opened: 없음
    failed: false
  - n: 5
    changed: [OQ5, OQ6]
    opened: 없음
    failed: false
  - n: 6
    changed: [OQ4]
    opened: 없음
    failed: false
  - n: 7
    changed: [OQ7, OQ8]
    opened: "읽기 설계와 측정을 첫 단추로 — 절차서 쪼개기(OQ14) · 측정 기준선(OQ27)"
    failed: false
  - n: 8
    changed: [OQ9, OQ10, OQ11]
    opened: "INTENT.md · STATUS.md 와 지금 machine.md · 지휘 기록의 관계(OQ12 · OQ13)"
    failed: false
  - n: 9
    changed: [OQ15]
    opened: 없음
    failed: false
  - n: 10
    changed: [OQ18]
    opened: "상태 계산 · 지휘 원장 읽기가 superpowers 산출 형식(**Spec:** · Ruling: · -design.md)에 묶여 있다(OQ33). Matt Pocock · pstack 의 사용자 호출 skill 은 disable-model-invocation 이라 모델이 단계표에서 부를 수 없다(OQ30 실행기 칸으로)"
    failed: false
  - n: 11
    changed: [OQ33, OQ25, OQ30, OQ29]
    opened: "설계문서가 중첩 배치되면 check_bundle_coverage(os.listdir, 하위 폴더 안 봄)와 roadmap_status(git grep, 하위 폴더까지)가 다른 결과를 낸다(RC9). 다른 형식을 받아들일 때 두 읽기를 맞출지"
    failed: false
  - n: 12
    changed: []
    opened: 없음
    failed: true    # 본문이 없다 — 머리말 한 줄(판 2.1.303 · 2.1.323)만 있고 evidence · repo_claims · unanswered 가 모두 없다. 주문 주제(감시자 기법 동작 조건 · disable-model-invocation · Channels 인증)의 결과가 하나도 실려 오지 않았다
  - n: 13
    changed: [OQ21, OQ13]
    opened: "main 직접 커밋 금지 · 보호 권장이 S17(STATUS 를 계산해 커밋)과 부딪힌다 → 지휘자 상태 브랜치(S35) · 코드 취합 자리(OQ34). 이 전용 데이터 브랜치는 브랜치 이름 패턴 ^(feature|fix|docs|chore)/ 밖이고, 거기서 rebase 하고 다시 push 하는 꼴이 rebase 금지에 드는지 문서가 정하지 않는다(RC2)"
    failed: false
  - n: 14
    changed: [OQ27, OQ26]
    opened: "기준선 원천을 무엇으로 할지 — 세션 기록은 30일 뒤 지워지므로 보관하거나 cleanupPeriodDays 를 올린다. 레포 판 2.1.303 은 하위 agent 출력 과소 기록 구간(2.1.293–2.1.306)에 들고 OTel agent_id 바닥(2.1.310) 아래라 판 바닥을 올릴지. 또 state 파일 351행의 위험 문장(input_tokens placeholder)이 공식 cost-tracking 문서와 충돌한다(RC2)"
    failed: false
basis: "최근 두 묶음은 묶음 7(조사 10)과 묶음 8(조사 11–14)이다. 조사 10 부터 끝까지 묶음 표지 순서는 7,8,8,8,8 로 어긋남이 없다. 묶음 7: 조사 10 이 OQ18 을 정했고(설치본 superpowers 7.0.2 SKILL 원문 · Matt Pocock to-spec/to-tickets/implement 의 disable-model-invocation: true · pstack 에 plan/execute 이름의 skill 없음) RC7(roadmap_status plan_specs 가 **Spec:** 줄에 묶임)로 OQ33 을 열었다. 묶음 8: 조사 11 RC3–RC5 · RC10 · RC12–RC17 이 「**Spec:** 없는 계획은 경고 없이 『계획 없음』, Ruling: 없는 원장은 판정 0개, SDD 가 아닌 작업 폴더는 지우기 전 확인에서 안 잡힘」을 보여 OQ25 · OQ30 · OQ33 을 바꿨다. 조사 13 은 branch-strategy.md 75행 「NEVER main 에 직접 commit」 · pr-process.md 63행 보호 권장으로 S17 을 다시 열게 했다(원장 reopen_log round 11). 조사 14 는 2.1.303 이 하위 기록 과소 구간이고 /usage 정확도 수정이 2.1.311 · 2.1.323 에 나왔다는 사실로 OQ27 · OQ26 의 측정원을 바꿨다. 조사 12 는 실패다(본문 없음). 두 묶음 모두 결정을 바꾸고 열었고 실패 항목도 있으므로 saturated 가 아니다. 그 밖에 열린 결정 OQ22 · OQ23 · OQ24 · OQ28 · OQ31 · OQ32 에는 decides 로 닿은 조사가 하나도 없다."
gaps:
  - kind: explore
    look_at: "조사 실패 — 묶음 8 의 open-researcher(조사 12): 주제를 셋으로 나눠 따로 묻는다. (a) Monitor 기한 · asyncRewake 종료 코드 2 로 쉬는 세션 깨우기가 resume · 압축 뒤에도 도는가 (b) disable-model-invocation skill 을 subagent 안에서 Skill 도구로 부를 때의 실제 동작 — 공식 문서에 명시가 없다(조사 10 unanswered) (c) Channels 의 Console API 키 허용 — 공식 문서와 제3자 README 가 충돌한다(조사 9 unanswered)"
    may_change: [OQ30, OQ28, OQ15]
    opens: "Matt Pocock · pstack 의 사용자 호출 skill 을 단계표에서 「사람」 실행기로만 둘지"
    device: open-researcher
  - kind: confirm
    look_at: "조사 13 이 S17 을 다시 열어 정한 지휘자 상태 브랜치(S35): 그 브랜치 이름이 project-init 훅의 브랜치 이름 검사 · docs/git-workflow 이름 패턴 · rebase 금지 범위와 부딪히는지. 한 기계의 여러 worktree 가 같은 상태 브랜치를 checkout 없이 쓰는 길(plumbing commit-tree/update-ref 나 common-dir 아래 sync worktree 하나)이 레포 상태 루트(state_path.py) 규칙과 맞는지"
    may_change: [OQ21, OQ13, OQ34]
    opens: "project-init 훅 · 브랜치 규칙 문서에 상태 브랜치 예외를 둘지"
    device: repo-researcher
  - kind: confirm
    look_at: "조사 11 의 주장 RC4 · RC7 · RC14 는 코드 경로에서 추론했고 실행하지 않았다. **Spec:** 줄 없는 계획 · 중첩 설계문서 · Ruling: 없는 원장을 담은 fixture 로 roadmap_status · check_bundle_coverage · control_plane 을 돌려 「조용히 계획 없음 · 0개」를 확인한다. 설치본 superpowers 7.0.2 의 SDD progress.md 가 실제로 `Ruling:` · BLOCKED 를 쓰는지 원문으로 확인한다(조사 11 unanswered)"
    may_change: [OQ25, OQ30, OQ33]
    opens: 없음
    device: orchestrator
  - kind: confirm
    look_at: "조사 14 의 측정원 변경 확인: 이 기계에 깔린 Claude Code 판, 지난 로드맵 세션 jsonl 의 날짜 · version 필드 · 30일 안에 남은 양(Bash 로 파일 날짜 — 조사 14 는 Bash 가 없어 못 봤다). state 파일 351행의 input_tokens placeholder 문장을 공식 cost-tracking 문서와 대조해 고친다"
    may_change: [OQ27, OQ26]
    opens: "기준선용 세션 기록을 지금 보관할지"
    device: orchestrator
  - kind: explore
    look_at: "아직 조사가 닿지 않은 열린 결정을 본다. OQ32 — 레포의 quality-gates · 테스트 스위트 · 문서 리뷰 · 보고 장치가 관문 다섯 칸에 어떻게 대응하는지, 플러그인 마켓플레이스에서 「화면 · 테스트 서버 배포」에 해당하는 것이 있는지. OQ31 — 지금 지휘 절차의 반복 감지 · 멈춤 조건(같은 자리 연속 실패, 되돌림 횟수)이 어디에 있는지. OQ23 — 지금 1차 검수 주체(integration-reviewer · relay-checker 등)"
    may_change: [OQ32, OQ31, OQ23]
    opens: 없음
    device: repo-researcher
  - kind: explore
    look_at: "OQ28 — mod 의 권한 범위를 본다. 도구 승인 · PermissionRequest 꼴 이벤트를 받을 수 있는지, mod 를 끄는 공식 스위치(disableAllHooks · --safe-mode · --bare)와 devbrew kill switch 규칙이 어떻게 맞물리는지, sandbox 밖에서 사용자 권한으로 도는 위험을 플랫폼이 어떻게 공시하는지"
    may_change: [OQ28]
    opens: "mod 에 DEVBREW_<PLUGIN>_DISABLE 꼴 kill switch 를 둘지"
    device: open-researcher
  - kind: explore
    look_at: "OQ22 · OQ24 — 다른 결정에 가려진 숨은 가정이 있는지 본다. 팀 규칙 목차 · HANDBOOK 상한(120줄)이 일꾼 시작 묶음 전체의 읽기 예산(ST1 refined_drops a)과 맞는지, P8 새 문장이 CLAUDE.md 「기본값과 판단」 · 철학 P8 의 다른 인용처와 충돌하는지"
    may_change: [OQ22, OQ24]
    opens: 없음
    device: blind-spot-prober
```

**판정 근거 둘**

- **조사 12 를 실패로 매긴 이유.** 규칙 5 의 첫 조건은 「unanswered 가 있다」인데 조사 12 에는 그것조차 없다. 그래서 글자 그대로는 맞지 않는다. 그래도 본문이 통째로 빠져 있어 실려 온 결과가 하나도 없다(머리말과 판 두 값뿐이다). 아무것도 보지 못한 산출이라 「새로움 없음」의 근거가 될 수 없으므로 `failed: true` 로 매겼다. 이 판단과 별개로, 최근 두 묶음이 결정을 바꿨으므로 결론은 같다.
- **원장 행 하나의 키 중복.** `ledger.txt` 12행 「일꾼 실행 방식과 역할 경계 집행」 행에 `evidence` 키가 두 번 있고, 두 번째 값은 빈 문자열이다. YAML 로 읽으면 나중 값이 이겨 evidence 가 비어 버린다. 판정에는 쓰지 않았지만 원장 writer 가 고칠 대상이다.

읽은 파일:
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/.claude/tmp/interview-sat/decisions.txt
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/.claude/tmp/interview-sat/research_outputs.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/.claude/tmp/interview-sat/ledger.txt

조사 10–14(최근 두 묶음)는 원문 전체를 읽었다. 조사 1–9 는 블록 머리말 · `decides` 줄 · 앞뒤 부분만 읽고 novelty 를 매겼다.

### 조사 15 — orchestrator · R13 · 묶음 9

- 확인 RC149 — 확인 — ~/.claude/plugins/cache/claude-plugins-official/superpowers/7.0.2/skills/subagent-driven-development/references/fix-loop.md#64 · 70행 — SDD 원장은 `Task <N>: Ruling: …` 줄을 쓰고 implementer-prompt.md 142행이 Status DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT 를 정함 — devbrew 의 Ruling: · BLOCKED 읽기가 기대는 형식이 실재 [→ OQ33]
- 확인 RC150 — 확인 — plugins/spec-distill/scripts/roadmap_status.py#plan_specs — 실행: «## Program checklist» 계획 → set(), «**Spec:** `docs/x-design.md`» 계획 → {docs/x-design.md}. **Spec:** 없는 계획은 조용히 빈 집합(조사 11 RC106 · RC107 의 입력 경로를 실행으로 확인) [RC150 → OQ33]
- 확인 RC151 — 확인 — 설치 판 · 기록 — claude --version 2.1.323, 가장 오래 남은 devbrew 세션 기록 2026-10-15, 백업 2,579개(R11) [RC151 → OQ27]

### 조사 16 — repo-researcher · R13 · 묶음 10

repo_claims:
  # ── (가) 코드 없는 상태 전용 브랜치와 닿는 자리 ──
  - id: RC1
    path: "plugins/project-init/hooks/hooks.json"
    anchor: "\"matcher\": \"Bash|EnterWorktree\""
    line: 6
    claim: "project-init 의 훅은 PostToolUse 하나뿐이다. Bash 와 EnterWorktree 호출 뒤에만 돌고 timeout 은 10초다. 커밋이나 push 전에 도는 훅(PreToolUse · git hook)은 없다."
    touches: []
    decides: []
  - id: RC2
    path: "plugins/project-init/hooks/post-tool-use.py"
    anchor: "Both validators are non-blocking."
    line: 17
    claim: "브랜치 이름 검사와 커밋 메시지 검사 둘 다 막지 않는다. 사람에게는 systemMessage 로 경고하고, 브랜치 이름이 틀렸을 때만 모델에게 additionalContext 로 `git branch -m` 명령을 준다. 끝은 늘 exit 0 이다(main() 끝의 `sys.exit(0)`)."
    touches: []
    decides: [OQ25]
  - id: RC3
    path: "plugins/project-init/hooks/post-tool-use.py"
    anchor: "def new_branches / CREATED_PREFIX = \"branch: Created from \" / RENAMED_RE"
    line: 242
    claim: "검사 대상은 «방금 만든» 브랜치뿐이다. 공용 git 디렉토리의 logs/refs/heads/** reflog 를 직접 읽어, 60초(NEW_BRANCH_WINDOW) 안에 메시지가 'branch: Created from ' 으로 시작하거나 'Branch: renamed|copied … to refs/heads/<이름>' 꼴인 줄이 있는 브랜치만 고른다. 그 가운데서도 명령 글이 이름을 가리키거나, cwd 의 지금 브랜치이거나, EnterWorktree 가 만든 브랜치만 남긴다. 이미 있는 브랜치에 커밋하는 것은 검사하지 않는다. update-ref 같은 plumbing 으로 만든 브랜치가 어떤 reflog 메시지를 남기는지는 이 코드에서 정해지지 않는다(이번에 재지 않음)."
    touches: []
    decides: [OQ25]
  - id: RC4
    path: "plugins/project-init/hooks/post-tool-use.py"
    anchor: "PROTECTED_BRANCHES = {\"main\", \"master\", \"develop\", \"dev\"} / def read_branch_rule"
    line: 86
    claim: "규칙 regex 는 작업 트리가 아니라 `git show refs/remotes/origin/HEAD:docs/git-workflow/branch-strategy.md` 의 첫 ```regex 블록에서 읽는다. origin 이 없거나, 기본 ref 가 없거나, 파일·블록이 없거나 깨졌으면 알리고 건너뛴다(fail-open). main/master/develop/dev 는 검사하지 않는다. main 에 직접 커밋하는 것을 막거나 알리는 코드는 없다."
    touches: []
    decides: [OQ25]
  - id: RC5
    path: "plugins/project-init/hooks/post-tool-use.py"
    anchor: "def _judge … 이름 바꾸기는 다른 작업 트리가 쓰는 브랜치에 내지 않는다"
    line: 509
    claim: "규칙 밖 브랜치가 다른 worktree 에 체크아웃돼 있으면 rename 명령을 빼고 경고만 낸다. 이 브랜치를 이 명령이 만들었다는 근거가 없을 때도 같다(다른 세션의 것일 수 있다). worktree 목록을 읽지 못하면 명령을 내지 않는다."
    touches: []
    decides: []
  - id: RC6
    path: "docs/git-workflow/branch-strategy.md"
    anchor: "## Branch Naming Pattern — ^(feature|fix|docs|chore)/[a-z0-9][a-z0-9.-]*$"
    line: 12
    claim: "허용 접두는 feature · fix · docs · chore 넷이다. 이름은 소문자 · 숫자 · 하이픈 · 점만 쓴다. 표에는 kebab-case · 2–4 단어 · 50자 이하도 적혀 있지만 이 셋은 regex 밖이라 훅이 재지 않는다. 상태 전용 같은 다른 접두를 쓰면 훅이 경고한다(막지는 않는다)."
    touches: []
    decides: [OQ25]
  - id: RC7
    path: "docs/git-workflow/branch-strategy.md"
    anchor: "## Rules for Claude — \"**NEVER** `main`에 직접 commit\" / \"`git rebase`는 절대 안 됨\""
    line: 75
    claim: "main 직접 커밋 금지는 '변경 작업(파일 편집 · 커밋)을 시작하기 전' 브랜치를 확인하라는 문장과 함께 적힌 Claude 용 규칙이다. rebase 금지의 범위는 '기존 feature 브랜치는 `git merge origin/main`으로 sync' 하는 자리이고, 이유는 'rebase는 commit SHA를 rewrite — push된 브랜치에 unsafe' 다. 모든 브랜치는 '단명 브랜치' 이고, Model 절은 'develop, release, staging 브랜치 없음' 이라 적는다. main 에 머지하지 않는 오래 사는 브랜치를 다루는 문장은 없다."
    touches: []
    decides: [OQ25]
  - id: RC8
    path: "docs/git-workflow/pr-process.md"
    anchor: "## Merge Strategy — | **Rebase** | linear history 원할 때"
    line: 47
    claim: "PR 머지 전략 표는 Squash · Merge commit · Rebase 셋을 다 허용한다(기본은 merge commit). 그래서 rebase 금지는 브랜치 sync 에만 걸린다. Server-Side Enforcement 절은 이 훅이 client-side 검증만 한다고 밝힌다."
    touches: []
    decides: []
  - id: RC9
    path: "plugins/spec-distill/scripts/state_path.py"
    anchor: "def state_root_for_common / def state_root"
    line: 73
    claim: "상태 루트는 `git rev-parse --git-common-dir` 로 정한다. 공용 디렉토리 이름이 .git 이면 그 부모(본 체크아웃)/.claude/spec-distill, bare 면 <공용 디렉토리>/.claude/spec-distill 이다. 그래서 어느 worktree 에서 불러도 같은 폴더다. git 이 실패하면 cwd 기준으로 떨어지고 stderr 에 알린다. 지휘 기계 상태는 <state-root>/conductor/<로드맵 폴더 이름>/machine.md 다(conductor_state.machine_dir · MACHINE_FILE)."
    touches: []
    decides: [OQ25]
  - id: RC10
    path: "plugins/spec-distill/scripts/state_path.py"
    anchor: "def _write_ignore / def _check_state_root"
    line: 120
    claim: "--ensure 는 루트에 `*` 한 줄짜리 .gitignore 를 O_NOFOLLOW 로 만든다. 그다음 본 체크아웃에서 check-ignore 로 무시되는지, ls-files 로 추적 파일이 없는지 확인한다. 무시되지 않거나 추적 파일이 있으면 exit 3 으로 거부한다. 곧 상태 루트는 git 에 들어가지 않는 자리로 강제된다."
    touches: []
    decides: [OQ25]
  - id: RC11
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "하위 agent 의 자리(2026-10-15 · 10-18 실측)"
    line: 43
    claim: "레포의 실측 기록은 다음과 같다. 같은 브랜치를 쥔 worktree 가 둘이면 '옛 쪽 index 로 한 커밋이 agent 의 커밋을 조용히 되돌린다'. 그래서 보내기 전에 에픽 worktree 가 깨끗한지 보고 `switch --detach` 로 브랜치를 놓는다. agent 는 `git switch --ignore-other-worktrees <에픽 브랜치>` 로 선다. 지휘자 worktree 는 origin 기본 브랜치에 detached 로 둔다. 놓은 옛 worktree 에서는 커밋하지 않는다. 걸음 3 '에픽 worktree' 불릿(36줄)과 손 절차 2(100줄)는 '그 브랜치를 체크아웃한 worktree 가 둘 이상이면 쓰지 않고 멈춰 보인다' 라고 적는다."
    touches: []
    decides: [OQ25]
  - id: RC12
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "격리된 자리(세션 · agent)의 셸은 복합 명령을 막으므로 … 공유 체크아웃 쪽 파일(리뷰 엔진 원장 · 지휘 자원 폴더)은 Write 도구가 막혀 임시 파일에 쓴 뒤 `cp` 로 옮긴다"
    line: 43
    claim: "격리 worktree 의 agent 는 공유 체크아웃 쪽 상태 파일(지휘 자원 폴더 등)에 Write 도구로 쓰지 못한다. 실측된 우회는 임시 파일에 쓴 뒤 cp 로 옮기는 것이다."
    touches: []
    decides: [OQ25]
  - id: RC13
    path: "plugins/quality-gates/scripts/seal-worktree.sh"
    anchor: "commit-tree \"$TREE\" -p HEAD -m \"qg: sealed\""
    line: 62
    claim: "git plumbing 을 쓰는 레포 스크립트 하나다. 임시 GIT_INDEX_FILE(.git 안 `--git-path`)로 read-tree HEAD · add -A · write-tree · commit-tree 를 돌려, worktree 없이 작업 트리를 ref 없는 커밋 하나로 봉인한다. 결과 트리에 임시 인덱스가 섞였는지 검사한다."
    touches: []
    decides: [OQ25]
  - id: RC14
    path: "plugins/quality-gates/scripts/combine-tips.sh"
    anchor: "순차의 대가는 `commit-tree` 중간 커밋이 unreachable 로 남는 것이다 … qg 는 `git prune` 을 부르지 않는다"
    line: 12
    claim: "끝점을 merge-tree --write-tree 로 차례로 합치고 commit-tree 로 중간 커밋을 만든다(89줄). 그 커밋에는 ref 를 달지 않아 git prune 이 회수하게 둔다. 락은 tests/test_qg_objects_unreachable.sh 다."
    touches: []
    decides: []
  - id: RC15
    path: "plugins/plugin-audit/scripts/audit-sandbox.sh"
    anchor: "snap_hash_file() { … git -C \"$sandbox\" hash-object \"$1\" …"
    line: 114
    claim: "hash-object 를 쓰는 곳이다. 샌드박스 파일 · reflog · stash 목록의 스냅숏을 해시해 무결성을 확인한다(150 · 218 · 253 · 410줄). update-ref 를 «실행하는» 제품 스크립트는 찾지 못했다. update-ref 는 테스트 fixture 와 resolve-baseline.sh 의 위협 설명 주석(26줄)에만 나온다."
    touches: []
    decides: []
  - id: RC16
    path: "plugins/spec-distill/scripts/roadmap_status.py"
    anchor: "GIT_ALLOWED = frozenset({\"show\", \"rev-parse\", \"log\", \"diff\", \"merge-base\", \"cat-file\", \"grep\"})"
    line: 50
    claim: "상태 계산 층의 git 호출은 읽기 전용 허용 목록으로 묶여 있다. 테스트(tests/test_roadmap_status.sh:874)는 fetch · push · update-ref 를 부르기 전에 거부하는지 잰다. repo_defaults.py:245 의 허용 목록도 rev-parse · ls-tree · cat-file · config(--get 꼴만)다."
    touches: []
    decides: [OQ25]

  # ── (나) my-team 개념에 대응하는 지금 장치 ──
  - id: RC17
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "## Flow — iteration N = 1..CAP (CAP = 5 + 사용자가 연 반복)"
    line: 199
    claim: "qg 파이프라인의 단계는 다음과 같다. Preflight → trivia 판단 → 반복마다(① 리뷰 → ①' 리뷰 축 합성 → ② 차등 테스트(영향받는 테스트만, 기준선 대비) → ③ 합성 · 판정) → Fix-loop → e2e 질문 · 걷기(앱을 실제로 걸어 봄) → Final verdict → Publish(PR 코멘트 하나). 이 SKILL 에는 lint 단계가 없다(lint · 린트 · ruff · shellcheck 검색 0건)."
    touches: []
    decides: [OQ32]
  - id: RC18
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "### Step 3 — reviewers — 시작 구성 표"
    line: 383
    claim: "qg 리뷰 시작 구성은 다음과 같다. 정확성 pr-review-toolkit:code-reviewer · 보안 quality-gates:security-reviewer · 다른 모델 계열 codex 러너를 늘 쓴다. 테스트 품질 · 조용한 실패 · 타입 설계 · 주석 리뷰어는 조건부다. 재비판 quality-gates:code-recritic 은 늘 하나다(Step 3.5)."
    touches: []
    decides: [OQ23, OQ32]
  - id: RC19
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "### Max-iter decision — 기본 상한은 5 다(P18). … CAP = 5 + <$RD/extra-iterations.md 의 줄 수>"
    line: 928
    claim: "qg 반복 상한은 5 다. 상한에 닿고도 막는 지적이나 차등 defect 가 남으면 「한 번 더 돌기 / 지금 판정으로 끝내기 / 멈추기」를 묻는다. 한 번 더 돌기는 반복을 하나만 열고, 그 승인 한 줄을 extra-iterations.md 에 남긴다. 상한 아래(N < CAP)에서는 반복마다 Fix-loop decision 이 사람에게 고치고 다시 돌지를 묻는다(812줄). 같은 지적이 연속으로 반복되는지 감지하는 장치는 이 SKILL 에 없다."
    touches: []
    decides: [OQ31]
  - id: RC20
    path: "plugins/quality-gates/scripts/artifact_max_rounds.sh"
    anchor: "effective_max_rounds = clamp(env, 0..10), default 5"
    line: 2
    claim: "artifact-critique 의 라운드 상한은 기본 5 다. DEVBREW_QUALITY_GATES_CRITIQUE_MAX_ROUNDS 로 바꿀 수 있고 0..10 으로 잘린다. 상한에 닿으면 한 라운드 더 돌지 묻는다(SKILL.md 353줄)."
    touches: []
    decides: [OQ31]
  - id: RC21
    path: "plugins/quality-gates/scripts/artifact_stagnation.py"
    anchor: "stagnant ⟺ (b) changed == false OR (a) this_keys == prev_keys AND this_keys non-empty"
    claim: "레포에 있는 유일한 '반복 감지' 술어다. 이번 라운드 편집이 no-op 이거나, 지적 키 집합이 직전 라운드와 같고 비어 있지 않으면 정체로 보고 루프를 끝낸다. --changed 값이 잘못 오면 정체로 본다(fail-closed). 직전 한 라운드만 비교하고 횟수 문턱은 없다."
    touches: []
    decides: [OQ31]
  - id: RC22
    path: "shared/docreview/scripts/docreview_config.py"
    anchor: "DEFAULTS = {\"detectors\": 1, \"rereview_cap\": 2, …} / MAXIMUM rereview_cap 10"
    line: 13
    claim: "문서 리뷰 엔진(spec-review 등)의 재리뷰 상한은 기본 2 다. 범위는 0..10 이고 env DEVBREW_DOCREVIEW_REREVIEW_CAP 이나 프로필로 바꾼다. docreview_state.py cmd_begin_round(1066–1074줄)는 round > 1+cap 이면 추가 승인 없이 reason cap_reached · rc 3 으로 거부한다. 추가 승인을 받으면 extra_rounds 에 원문과 출처를 남긴다."
    touches: []
    decides: [OQ31, OQ32]
  - id: RC23
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "리뷰 뒤 반영 … 좁은 재리뷰는 PR 하나에 두 번까지다 — 첫 재리뷰를 보내기 전에 멈출 조건 … 을 PR 본문에 적는다"
    line: 61
    claim: "지휘자의 머지 전 리뷰 뒤 좁은 재리뷰 상한은 PR 하나에 2번이다. 두 번째 재리뷰 뒤에도 남는 지적은 미리 적은 멈출 조건대로 넘기거나 사용자에게 묻는다(손 절차 109줄도 같다)."
    touches: []
    decides: [OQ31]
  - id: RC24
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "같은 자리(한 메커니즘의 보안 리뷰 등)가 라운드마다 새 막는 지적을 내면 라운드를 더하지 않고 설계의 대안 갈래로 일찍 옮긴다"
    line: 50
    claim: "같은 자리에서 반복해 실패할 때 지휘자가 따르는 규칙은 숫자 없는 판단 문장이다. 같은 걸음에 '판정이 수용 기준 · 의도를 바꾸거나 구현이 막히면(SDD 의 BLOCKED 포함) 그 에픽만 멈추고 묻는다' 도 있다. '같은 단계 N회 연속 실패' 같은 숫자 문턱은 지휘 절차에 없다."
    touches: []
    decides: [OQ31]
  - id: RC25
    path: "plugins/spec-distill/scripts/merge_check.py"
    anchor: "종료 코드: 0 새 실패 없음 · 1 새 실패 있음 · 3 검사 불가 · 4 … · 5 … 공유 잠금 · 6 테스트 명령을 모른다 · 7 스위트 대조 없음"
    line: 21
    claim: "머지 전 스위트 대조다. 합친 사본(origin 기본 + 에픽 브랜치)과 기준선 사본을 일회용 worktree 로 만들어 두 쪽에서 스위트를 돌리고, 실패를 단위와 이름으로 대조한다. 공유 스위트 잠금(suite_lock.py)으로 다른 스위트와 동시에 돌지 않게 막는다. 하위가 본 실패가 진짜인지는 이 대조만 판정한다(conductor-dispatch.md 47줄)."
    touches: []
    decides: [OQ32]
  - id: RC26
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "## 마지막 보고"
    line: 41
    claim: "하위 agent 보고 계약이다. 판정 전체(줄마다 `Ruling:`), AC 마다 `AC<번호>: 구현됨 | 미룸 | 빠짐 — 근거`, 쓴 미리 받은 답과 그 자리, 커밋 목록(해시 · 한 줄), 브랜치, 남긴 파일, 하위가 본 테스트 실패 이름을 모두 싣는다. 이유는 '실행 방식이 작업 폴더를 지울 수 있어 경로만으로는 부족하다'."
    touches: []
    decides: [OQ25, OQ32]
  - id: RC27
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "마지막 전체 리뷰는 설계문서 ## Acceptance Criteria 가운데 <이 계획 몫 AC> 를 AC 마다 한 줄 … 과제 사이 이음매 … 와 계획이 쓴 테스트 코드도 묻게 한다"
    line: 72
    claim: "구현 agent 안의 검수는 이렇게 짜여 있다. 실행 방식(superpowers SDD 등) 안의 과제 리뷰가 있고, 그 끝에 '마지막 전체 리뷰' 가 AC 판정 · 과제 사이 이음매 · 계획이 쓴 테스트 코드를 본다. 과제 구현 · 리뷰 agent 는 보고를 파일에 쓰고 짧은 상태만 돌려준다(73줄). SDD 의 과제 리뷰 구성과 재시도 횟수는 superpowers(외부 플러그인)에 있어 이 레포에 없다."
    touches: []
    decides: [OQ23]
  - id: RC28
    path: "plugins/spec-distill/skills/epic-conductor/SKILL.md"
    anchor: "### 6. 통합 리뷰어 — subagent_type: \"spec-distill:integration-reviewer\""
    line: 171
    claim: "구현 agent 밖의 검수는 지휘자가 머지 전 확인(걸음 5)에서 부르는 통합 리뷰어다. tools 는 Read · Grep · Glob 이고 cost_class 는 medium 이다. 합친 사본 · PR diff · 다른 에픽 diff · 앞선 인계 절 · 함께 진행된 에픽 설계문서를 받아 지적을 「이 PR 이 고침」 · 「뒤 에픽이 고침」으로 나눈다. 순서는 스위트 대조(merge_check) → 통합 리뷰 → 리뷰 뒤 반영 → verification-before-completion 이다(conducting.md 57–65줄)."
    touches: []
    decides: [OQ23, OQ32]
  - id: RC29
    path: "plugins/spec-distill/skills/epic-conductor/SKILL.md"
    anchor: "### 7. 옮김 대조 — subagent_type: \"spec-distill:relay-checker\""
    line: 190
    claim: "relay-checker 는 코드 검수자가 아니다. 에픽이 끝난 뒤(걸음 6), 하위가 돌려보낸 질문을 지휘자가 사용자에게 옮긴 relay-*.md 파일을 원문과 대조한다(선택지 수 · 순서 · 라벨 · 「(권장)」 출처 · 돌려보낸 답). 쓰기 도구가 없고 cost_class 는 low 다. agent 본문은 '에픽 코드를 리뷰하지 않는다' 를 맡지 않는 일로 밝힌다(relay-checker.md 23줄)."
    touches: []
    decides: [OQ23]
  - id: RC30
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### 7. 끝 — 품질 게이트(`/quality-gates:quality-pipeline`)를 한 번, 로드맵 시작 커밋부터 지금 기본 브랜치까지 돌린다"
    line: 78
    claim: "지휘 흐름에서 qg 파이프라인은 PR 마다 돌지 않는다. 로드맵의 모든 에픽이 머지된 뒤 끝에서 끝 확인 때 범위를 주어 한 번 돈다. 설치돼 있지 않거나 범위 입력을 받지 않으면 알리고 건너뛴다."
    touches: []
    decides: [OQ32]
  - id: RC31
    path: ".claude-plugin/marketplace.json"
    anchor: "\"plugins\": [ … \"source\": \"./plugins/quality-gates\" …"
    claim: "마켓플레이스 게시는 이 레포의 main 그 자체다. marketplace.json 은 플러그인 넷(quality-gates · project-init · spec-distill · plugin-audit)을 ./plugins/<이름> 경로로 가리키고 버전 칸은 없다. 버전은 각 plugin.json 에 있다. .github/ 아래 파일은 없다(CI · 배포 워크플로 없음)."
    touches: []
    decides: [OQ32]
  - id: RC32
    path: "shared/tests/test_changelog_integrity.sh"
    anchor: "C1: v>=1.0.0 이면 CHANGELOG 필수"
    line: 203
    claim: "판 올림과 관련해 기계가 재는 것은 plugin.json 의 SemVer 추출과 CHANGELOG 의 있음 · 헤딩 연속성이다. 'PR 마다 bump 했는가' 를 main 과 비교해 재는 스크립트나 테스트는 찾지 못했다(plugin.json·bump 검색 결과는 fixture 문자열뿐). CLAUDE.md 의 PR 마다 bump 규칙은 문서 규칙이다."
    touches: []
    decides: [OQ32]
  - id: RC33
    path: "plugins/spec-distill/CHANGELOG.md"
    anchor: "〔격리 설치 실측〕 … `CLAUDE_CONFIG_DIR=<tmp>` 로 사용자 `~/.claude` 격리 증명 후 `plugin marketplace add` + `plugin install`"
    line: 3769
    claim: "'실제 배포 경로' 확인은 손으로 한 격리 설치 실측으로 기록돼 있다. 임시 CLAUDE_CONFIG_DIR 에 마켓플레이스를 더하고 설치한 뒤, 설치본 경로에 파일이 실리는지 본다. 이를 자동으로 돌리는 스크립트는 레포에 없다(CLAUDE_CONFIG_DIR 은 test_control_plane.sh 의 상태줄 테스트 등에서 env 격리용으로만 쓰인다)."
    touches: []
    decides: [OQ32]
  - id: RC34
    path: "plugins/quality-gates/scripts/artifact_branch_guard.sh"
    anchor: "[ \"$branch\" = \"main\" ] || [ \"$branch\" = \"master\" ] … echo \"branch_ok: false\""
    line: 30
    claim: "기본 브랜치나 main/master/develop/trunk, 또는 detached HEAD 에서 «커밋하는» 도구를 실제로 멈추는 장치는 레포에 이것 하나다. artifact-critique 「고치며 돌기」가 라운드마다 커밋하기 전에 이 검사로 멈춘다. project-init 훅에는 이런 검사가 없다(RC4)."
    touches: []
    decides: []
unanswered: "SDD(superpowers subagent-driven-development)의 과제 리뷰 · 최종 리뷰 구성과 재시도 · 되돌림 횟수는 외부 플러그인에 있어 이 레포에서 읽을 수 없다. update-ref 등 plumbing 으로 만든 브랜치가 남기는 reflog 메시지와 그에 대한 훅 반응은 코드로 정해지지 않아 재지 않았다. '테스트 서버 배포' 에 해당하는 자동 장치는 레포에 없다(격리 설치는 손 실측 기록뿐)."

다른 경로로 볼 만한 자리 두 개를 덧붙입니다. 하위 agent 자리 규칙의 원래 도입 기록은 /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/CHANGELOG.md 416줄에 있습니다. PR 하나의 수명 순서(리뷰 → 재리뷰 2회 상한 → 머지 하나씩 → 머지 큐)는 /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/references/conducting.md 걸음 5(56–68줄)가 정본입니다.

### 조사 18 — blind-spot-prober · R13 · 묶음 10

```yaml
hidden_assumptions:
  - assumption: "120줄 상한이면 팀 규칙 목차의 읽기 비용이 묶인다. 「세션마다 읽히니 120줄 안」이라는 근거는 이름을 바꾼(S24) 뒤에도 그대로 맞는다."
    why_risky: "120줄이라는 숫자는 Claude 자동 메모리 MEMORY.md 의 규약을 빌려 왔다. 그 파일은 앞 200줄 또는 25KB 를 자동으로 싣고, 넘친 부분은 잘라 낸다. 레포 파일로 이름을 바꾸면 이 자동 로드가 사라진다. 그러면 「세션마다 읽힌다」는 하니스가 지키는 사실이 아니라, 누군가 Read 하라고 지시해야만 일어나는 일이 된다. 지시하지 않으면 읽히지 않고, 지시하면 120줄 전체가 그 단계의 고정비가 된다. 그런데 S27 은 규칙마다 출처 · 조건 · 확인법을 한 줄에 싣게 한다. 그러면 줄이 길어져 줄 수는 바이트 · 토큰 예산을 대신하지 못한다. 결국 120줄 상한은 ST1 「보완」(S8)이 요구한 «역할 · 단계별 시작 묶음 전체의 예산»과 단위도 다르고 범위도 다르다. 묶음 안에는 레포 CLAUDE.md, 사용자 자동 메모리, 역할 파일, INTENT · STATUS 가 같이 든다."
    evidence:
      - url: "https://code.claude.com/docs/en/memory"
        supports: current
        claim: "MEMORY.md 는 «first 200 lines … or the first 25KB, whichever comes first» 만 대화 시작 때 싣고 넘친 것은 싣지 않는다. 이 한도는 «applies only to MEMORY.md» 이다. 하위 폴더 파일은 on demand 로 실린다. 줄 상한과 바이트 상한이 따로 있다는 공식 근거다."
        touches: []
        decides: [OQ22]
        source_kind: primary
        checked_at: "2026-11-14"
      - url: "https://code.claude.com/docs/en/memory"
        supports: alternative
        claim: "공식 문서는 일부에만 맞는 지시를 «path-scoped rules»(.claude/rules/ + paths:)로 옮겨 «load only when Claude works with matching files» 하게 하라고 권한다. 늘 싣는 목차 말고, 조건이 붙은 규칙을 조건이 맞을 때만 싣는 기존 장치가 있다는 뜻이다(있는 것 먼저)."
        touches: []
        decides: [OQ22]
        source_kind: primary
        checked_at: "2026-11-14"
  - assumption: "넘치면 «겹치는 줄은 합치고 오래된 것은 HANDBOOK 으로» 보내도 규칙의 뜻과 조건은 보존된다."
    why_risky: "합칠 때 가장 먼저 사라지는 것은 출처 · 적용 조건이다. 조건이 사라지면 조건부 규칙이 무조건 규칙이 된다. 사용자가 S23 에서 «이때는 맞았는데 다른 때는 틀린» 이라고 경계한 실패가 바로 이 모양이다. 120줄 압박이 S27 의 «규칙마다 출처 · 조건 · 확인법»을 거꾸로 깎아 낸다. 또 «오래된 것을 내보낸다»는 나이를 낡음으로 본다. 그런데 오래 살아남은 규칙은 반례를 가장 많이 견딘 규칙이다. 반대로 «새 규칙은 맨 위»는 가장 덜 검증된 규칙을 앞 자리에 둔다. 모델에게는 앞 지시를 더 따르는 쏠림이 있다. 결국 신뢰 순서와 노출 순서가 뒤집힌다."
    evidence:
      - url: "https://arxiv.org/abs/2510.04618"
        supports: current
        claim: "ACE(ICLR 2026)는 맥락을 반복해서 다시 쓰는 방식에서 두 실패를 이름 붙였다. brevity bias 는 간결한 요약을 위해 도메인 통찰을 버리는 것이고, context collapse 는 반복 재작성이 세부를 깎는 것이다. 이를 막으려고 통째 재작성 대신 «structured, incremental updates» 를 쓴다."
        touches: []
        decides: [OQ22]
        source_kind: primary
        checked_at: "2026-11-14"
        certainty: uncertain   # 초록 · 2차 요약으로 확인, 본문 미확인
      - url: "https://arxiv.org/abs/2507.11538"
        supports: current
        claim: "IFScale 은 지시 수가 늘면 준수율이 떨어지고(최상위 모델도 500개에서 68%), 앞쪽 지시에 쏠림(bias toward earlier instructions)이 있다고 측정했다. 「맨 위가 새 규칙」 배치는 덜 검증된 규칙에 이 쏠림을 몰아준다."
        touches: []
        decides: [OQ22]
        source_kind: primary
        checked_at: "2026-11-14"
  - assumption: "같은 지적이 두 번 나왔으면 그 규칙은 일반화할 만큼 검증된 것이다(승격 기준)."
    why_risky: "두 번 나온 것이 서로 독립된 근거가 아닐 수 있다. 같은 모델 계열, 같은 에픽, 같은 HANDBOOK 을 읽은 일꾼이 같은 오판을 되풀이한 것일 수 있다. 첫 번째 잘못된 규칙이 두 번째 발생을 만들었다면 승격은 오류를 굳힌다. S27 의 «승격 전 반례 확인»이 이를 막아야 하는데, 지금 기준은 «빈도»라서 반례를 찾을 동기가 없다."
    evidence:
      - url: "https://arxiv.org/abs/2505.16067"
        supports: current
        claim: "ACL 2026 실험에서 agent 는 비슷한 과거 기록의 출력을 그대로 따른다(experience-following). 기록에 틀린 출력이 있으면 그것을 «replicate and even amplify» 하고, 그 결과가 다시 메모리에 들어가 이후 과제로 퍼진다. 비슷하지만 맞지 않는 기록을 다시 쓰는 것(misaligned experience replay)도 성능을 떨어뜨린다. 대책은 넣기 전 품질 검사(Selective Addition)와 품질 · 사용 빈도에 따른 삭제다."
        touches: []
        decides: [OQ22]
        source_kind: primary
        checked_at: "2026-11-14"
  - assumption: "공통 HANDBOOK 과 팀 전용 규칙 몇 줄은 서로 부딪히지 않거나, 부딪히면 모델이 알아서 우선순위를 가른다."
    why_risky: "S26 은 두 겹(공통 + 팀 전용)을 만들었는데 우선순위 규칙이 없다. 두 지시가 어긋나면 모델은 하나를 임의로 고른다. 팀 전용 줄의 «적용 조건»이 공통 규칙을 덮는다는 뜻인지, 덧붙인다는 뜻인지가 정해지지 않으면 같은 입력이 일꾼마다 다른 행동을 낸다."
    evidence:
      - url: "https://code.claude.com/docs/en/memory"
        supports: current
        claim: "«if two instructions contradict each other, Claude may pick one arbitrarily» — 공식 문서는 낡았거나 서로 어긋나는 지시를 정기적으로 지우라고 하고, user 규칙과 project 규칙 사이에도 «Neither set overrides the other» 라고 적는다."
        touches: []
        decides: [OQ22]
        source_kind: primary
        checked_at: "2026-11-14"
  - assumption: "P8 을 «순서 · 숫자는 스크립트»로 바꿔야 S14 가 가능하다. 곧 «숫자» 쪽도 지금 P8 이 막고 있다."
    why_risky: "멈춤 횟수 같은 루프 상한, 사용자 승인 게이트, 보안 · 정확성 검사는 레포가 이미 load-bearing «유지» 목록에 올려 둔 결정론이다. CLAUDE.md Forbidden Patterns 의 Unbounded autonomy 도 상한을 요구한다. 그러니 P8 이 실제로 막는 것은 «순서 강제» 한 가지다. «숫자»까지 개정 문장에 넣으면 이미 허용된 것을 다시 쓰는 셈이고, 범위가 커져 다른 인용처와 더 많이 부딪힌다. 반대 경우도 있다. «동시 2개 강제»는 숫자이면서 «권장 · 레포 설정 값»을 «상한»으로 바꾸는 일이라, «숫자는 이미 허용»에 들지 않는다(RC2)."
    evidence: []
  - assumption: "«스크립트가 강제한다»고 쓰면 실제로 강제된다."
    why_risky: "skill 은 산문이고, 모델이 스크립트를 부를 때만 스크립트가 판정을 낸다. 모델이 부르지 않거나 rc 를 무시하면 순서 강제는 문서상 주장으로만 남는다. CLAUDE.md 가 «막지 않는 것을 막는다고 믿게 만드는 선언은 없는 것보다 나쁘다»고 경계한 바로 그 꼴이다. 진짜로 막으려면 훅(PreToolUse · Stop)에 걸어야 한다. 그러면 kill switch 를 의무로 붙여야 하고, Stop 훅의 exit 2 는 Claude 를 멈추지 못하게 하는 고리를 만들 수 있다. 개정 문장이 «강제 장소»(rc 를 읽는 스크립트인지, 훅인지)를 정하지 않으면 이 둘 사이에서 미끄러진다."
    evidence:
      - url: "https://code.claude.com/docs/en/memory"
        supports: current
        claim: "CLAUDE.md · 메모리는 «context, not enforced configuration» 이다. 무조건 막으려면 «use a PreToolUse hook» 이라고 적는다. 산문 · 지시로는 강제가 성립하지 않는다는 공식 근거다."
        touches: []
        decides: [OQ24]
        source_kind: primary
        checked_at: "2026-11-14"
      - url: "https://code.claude.com/docs/en/hooks"
        supports: current
        claim: "Stop · SubagentStop 훅의 exit 2 는 «Prevents Claude from stopping, continues the conversation» 이다. «Claude can't repair a hook that won't run» — 깨진 강제 훅은 모델이 우회하거나 고칠 수 없다."
        touches: []
        decides: [OQ24]
        source_kind: primary
        checked_at: "2026-11-14"
failure_modes:
  - mode: "단계표가 틀렸거나 그 에픽 모양에 안 맞을 때 스크립트가 정당한 경로를 막는다. 막힌 지휘자는 순서를 «맞추려고» 빈 단계를 형식으로 통과시키거나(theater), 멈춘 채 사람을 부른다. 단계표를 고칠 길이 없으면 봉인된 결정(Sealed decision)이 된다."
    trigger: "조사 · 측정 · 결정 에픽처럼 «흐름:» 칸으로 brainstorming 을 대신하는 에픽, 산출물만 내는 에픽, 하류(구현 · 리뷰)에서 앞 단계 결정이 반증돼 되돌아가야 하는 경우(P23). 지금 레포는 이 경우를 «모델이 판단해 맞추거나 건너뛰고 그 이유를 보고한다»로 열어 두고 락까지 걸었다(RC3 · RC4)."
    evidence:
      - url: "https://www.anthropic.com/engineering/building-effective-agents"
        supports: both
        claim: "«workflows offer predictability and consistency for well-defined tasks» 이고, agent 는 «flexibility and model-driven decision-making» 이 필요할 때 낫다. 단계가 미리 알려진 과제에만 정해진 경로가 맞다 — 단계표 강제는 에픽 종류가 정형일 때만 이득이다."
        touches: []
        decides: [OQ24]
        source_kind: primary
        checked_at: "2026-11-14"
  - mode: "P8 · CLAUDE.md 문장만 바뀌고, P8 을 이름으로 인용한 자리와 그 원칙을 옮겨 적은 문장은 옛 뜻 그대로 남는다. 모든 락은 GREEN 으로 통과한다. 그 결과 다음 세션의 brief · 넘김 줄은 «기본은 X … 모델이 판단»을 계속 싣고, 지휘 절차는 «스크립트가 강제»를 싣는다. 두 지시가 어긋나 모델이 하나를 임의로 고른다."
    trigger: "개정 PR 이 CLAUDE.md 30행 · 철학 82–84행만 고친다. 헌장 인용 락은 인용 «대상의 실재»만 재고 뜻의 일치는 재지 않는다(RC8). 옮겨 적은 문장은 다른 락이 글자 그대로 핀으로 박고 있다(RC6)."
    evidence:
      - url: "https://code.claude.com/docs/en/memory"
        supports: current
        claim: "«Review … periodically to remove outdated or conflicting instructions» — 지시 파일 사이의 충돌은 공식 문서가 직접 꼽는 불이행 원인이다."
        touches: []
        decides: [OQ24]
        source_kind: primary
        checked_at: "2026-11-14"
  - mode: "숫자 멈춤(동시 수 · 멈춤 횟수)을 스크립트가 상한으로 강제해 정상적인 병렬 · 반복을 끊는다. 레포마다 정하게 한 값을 하나의 리터럴로 박아, 다른 레포에서 조용히 틀린다."
    trigger: "S14 의 «동시 2개 강제»를 그대로 옮긴다. 지금 코드의 동시 수는 레포 설정(parallel_default)으로 바뀌는 «권장 3 — 상한이 아니다, 사용자가 늘린다»이다(RC2). P8 의 (이식성) 줄은 레포 전용 값을 박는 결정론을 금한다(RC1). 개정 때 (부과) · (흐름) 줄만 고치고 (이식성) 줄과의 관계를 정하지 않으면 한 원칙 안에서 모순이 생긴다."
    evidence: []
  - mode: "규칙 목차 · HANDBOOK 이 «넘침 → 합침 → 이관»의 연쇄 상한으로 운영된다. HANDBOOK 도 상한에 닿으면 갈 곳이 없어, 지울 규칙을 반증이 아니라 «크기» 때문에 고른다. S27 의 «반증 · 낡음이면 지움»이 «넘치면 지움»으로 바뀐다."
    trigger: "S27 이 HANDBOOK 에도 상한을 둔다. HANDBOOK 이 넘쳤을 때의 처리(삭제 기준 · 삭제 기록 · 사람 확인)를 정하지 않으면, 상한 집행 쪽이 증거 기준을 이긴다."
    evidence:
      - url: "https://arxiv.org/abs/2505.16067"
        supports: alternative
        claim: "삭제가 성능을 올린 경우는 «recent retrieval frequency» 와 품질을 함께 본 Combined Deletion 이었다. 크기만 보는 삭제 기준은 이 근거에 포함되지 않는다."
        touches: []
        decides: [OQ22]
        source_kind: primary
        checked_at: "2026-11-14"
  - mode: "잘못 쌓인 규칙이 «근거»로 쓰이는 오염(context poisoning)과 충돌(clash). 일꾼이 규칙 줄을 지금 확인하지 않고 근거로 삼는다. 규칙끼리 어긋나면 그중 하나를 고른다."
    trigger: "S27 의 «쓰기 전 지금 확인»이 «확인법» 칸을 채우는 형식으로만 남는다. 읽는 쪽이 확인을 실행했는지 대조하는 장치(산출물 · 행동 대조 — ST1 refined_drops b)가 없다."
    evidence:
      - url: "https://dbreunig.com/2025/06/22/how-contexts-fail-and-how-to-fix-them.html"
        supports: current
        claim: "긴 맥락의 실패를 넷으로 나눈다. poisoning(맥락에 들어간 오류가 계속 참조되며 쌓임) · distraction · confusion · clash(서로 어긋나는 정보가 경쟁함)."
        touches: []
        decides: [OQ22]
        source_kind: secondary
        checked_at: "2026-11-14"
        certainty: uncertain   # 원문 전문 미확인, 요약으로 확인
confidence: 0.72
repo_claims:
  - id: RC1
    path: "docs/philosophy/devbrew-harness-philosophy.md"
    anchor: "### P8 — Determinism Economy (Maintain Simplicity)"
    line: 78
    claim: "P8 에는 (제거 방향) · (부과 방향) · (흐름) · (재사용) · (이식성) 다섯 줄이 있다(79–86행). S14 가 직접 바꾸는 것은 (부과)의 «보안/정확성 게이트에만»과 (흐름)의 «순서를 강제하는 결정론은 두지 않는다»(84행)뿐이다. (이식성) 줄은 «레포 전용 값을 박는 것은 … 다른 레포에서 조용히 틀린다»라고 적는다. 그래서 «동시 2개» 같은 리터럴 강제와 같은 원칙 안에서 부딪힌다. 88행 예시(qg 판정 floor)는 정확성 한 점에만 결정론을 거는 꼴을 P8 의 모범으로 든다."
    touches: []
    decides: [OQ24]
  - id: RC2
    path: "plugins/spec-distill/scripts/repo_defaults.py"
    anchor: "PARALLEL_DEFAULT = 3"
    line: 27
    claim: "동시 큰 작업 수는 «권장 수 — 기본값이지 상한이 아니다(사용자가 늘린다)»이고, 레포 머리말 parallel_default 로 바뀐다(43행 · 226–231행). control_plane.py 312행은 사용자에게 «권장 %d(… — 상한이 아니다, 사용자가 늘린다)»를 낸다. S14 의 «동시 2개는 스크립트가 강제»는 값(2 대 3)과 성격(권장 대 상한)과 이식성(레포 설정 대 리터럴)을 모두 뒤집는다. 개정은 이 코드 · 출력 문구 · 사용자 공시를 함께 바꾸는 일이다."
    touches: []
    decides: [OQ24]
  - id: RC3
    path: "plugins/spec-distill/tests/test_epic_handoff.sh"
    anchor: "# R5 계획 2 AC31 — 흐름을 고정하지 않는다 · 재분해 보고 · 고른 실행 방식"
    line: 60
    claim: "에픽 넘김 줄에 «흐름: 칸이 있으면 brainstorming 대신 그 칸의 흐름» · «묶음을 다시 나눌 근거가 보이면» · «모델이 판단해 맞추거나 건너뛰고 그 이유를 보고한다»가 있음을 락이 단언한다(61–73행). 반대로 «묶음을 다시 나누지 않는다» · «그 흐름이 정한 대로 한다»는 없어야 한다고 단언한다. 스크립트가 단계 순서를 강제하면 이 락이 지키는 탈출구와 정면으로 부딪힌다. 개정 범위는 이 락과 그것이 지키는 references/epic-handoff.md 까지 닿는다."
    touches: []
    decides: [OQ24]
  - id: RC4
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "## 지휘 순환"
    line: 5
    claim: "지휘 절차는 «걸음마다 다섯 칸(기본값 · 판단 · 부를 skill · 기록 · 기계 상태)»이고, «기본값과 다르게 하면 무엇을 왜 다르게 했는지 … `## 지휘 기록` 에 적는다»(5행, 92행도 같은 뜻)이다. 지금의 단계표는 기본값 + 판단 기록 구조다. 순서 강제로 바꾸면 «판단» 칸과 이탈 기록 경로를 무엇으로 대신할지가 비어 있다."
    touches: []
    decides: [OQ24]
  - id: RC5
    path: "docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/flexibility-audit.md"
    anchor: "고치는 꼴: 「언제나 X」 를 「기본은 X, 일의 모양이 다르면 모델이 판단해 고르고 무엇을 왜 골랐는지 적는다」 로."
    line: 5
    claim: "흐름 고정 점검은 «유지»(load-bearing) 목록에 «사용자 승인 게이트(P17)와 AP2 · 루프 상한 · 보안 · 정확성 검사»를 이미 넣었다. 그러니 멈춤 횟수 · 승인 같은 «숫자 · 게이트»는 지금 P8 아래서도 허용된다. 같은 문서는 «에픽 넘김 줄의 brainstorming 고정 풀기»(53행) 등 순서 고정을 사용자 결정으로 풀었다(3 · 9행 원문). S14 의 순서 강제는 이 점검이 푼 것을 일부 되돌리는 일이다. 사용자 원칙 S6 대로 이것은 제약이 아니라 «고칠 후보»다. 다만 «그때 왜 풀었는가»(정석 흐름 의도는 지키되 가능성을 막지 않는다)를 새 문장이 다시 덮는지는 개정 때 확인해야 한다."
    touches: []
    decides: [OQ24]
  - id: RC6
    path: "plugins/spec-distill/tests/test_review_handoff_order.sh"
    anchor: "설계의 규칙은 「기본은 X, 일의 모양이 다르면 모델이 판단하고 이유를 적는다」로 쓰고 정석 흐름(설계 → 계획 → 구현)의 의도는 지킨다."
    line: 96
    claim: "CLAUDE.md «기본값과 판단» 문장을 옮겨 적은 문장이 brief 다음 세션 줄(finishing.md)에 있고, 락이 글자 그대로 핀으로 박는다(AC22). CLAUDE.md 만 고치면 이 사본은 옛 문장으로 남고 락은 GREEN 이다. 개정 때 사본 자리를 전수로 찾아 함께 고칠지, 다르게 둘 이유를 적을지 정해야 한다."
    touches: []
    decides: [OQ24]
  - id: RC7
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "**Scope transparency (P8 determinism-economy):**"
    line: 327
    claim: "qg 는 P8 을 이름으로 인용해 «이는 결정론 가드가 아니다 … non-load-bearing routing은 모델 신뢰»를 정당화한다. plugins/quality-gates/README.md 18행 · artifact_branch_guard.sh 44행(«P8: security-load-bearing엔 결정론»)도 같다. P8 의 뜻이 «순서 · 숫자는 스크립트»로 넓어지면, 이 인용들이 기대는 «결정론은 load-bearing 에만»의 범위가 말없이 바뀐다."
    touches: []
    decides: [OQ24]
  - id: RC8
    path: "shared/tests/test_charter_citations.sh"
    anchor: "# 헌장(CLAUDE.md + docs/philosophy/*.md)이 이름으로 박는 것은 실재해야 한다."
    line: 5
    claim: "헌장 인용 락은 헌장이 가리키는 경로 · 이름의 «실재»만 재고(8–13행), 다른 파일이 P8 을 인용하며 기대는 «뜻»과 새 P8 문장의 일치는 재지 않는다. P8 개정 뒤 RC6 · RC7 의 뜻이 어긋나도 이 락으로는 드러나지 않는다."
    touches: []
    decides: [OQ24]
```

**표면화된 blind-spot 요약**

**OQ22**
- 120줄은 자동 메모리 MEMORY.md 의 자동 로드 · 잘라냄 규약에서 빌려 온 숫자다. S24 로 이름을 바꾸면 그 근거가 사라진다. 그 뒤로는 줄 수가 읽기 예산의 단위가 아니다. 예산은 바이트 · 토큰이고 범위는 시작 묶음 전체여야 한다.
- 「합치기」와 「오래된 것 내보내기」는 S27 이 붙이려는 출처 · 조건을 깎는다(context collapse). 그 결과 조건부 규칙이 무조건 규칙이 되는데, 사용자가 S23 에서 경계한 실패가 바로 이것이다.
- 「새 규칙은 맨 위」는 가장 덜 검증된 규칙에 가장 큰 무게를 준다.
- 「두 번 나옴」을 승격 기준으로 삼으면 오류가 굳을 수 있다. 같은 오판이 되풀이된 것일 수 있기 때문이다(experience-following).
- 공통 HANDBOOK 과 팀 전용 규칙이 어긋날 때 무엇이 앞서는지가 없다.
- HANDBOOK 까지 상한을 두면 연쇄 상한 끝에 지울 규칙을 크기로 고르게 된다. 반증 기준이 아니게 된다.
- 기존 대안 하나가 있다. Claude Code 의 path-scoped rules(.claude/rules/ + paths:)로 조건 붙은 규칙을 조건이 맞을 때만 싣는 것이다.

**OQ24**
- 「숫자」 쪽(루프 상한 · 승인 게이트)은 이미 P8 · 유지 목록 안에 있다. 실제로 새로 바꾸는 것은 「순서 강제」 하나이고, 「동시 2」는 권장 · 레포 설정 값을 상한 리터럴로 바꾸는 별도 변경이다(RC2 · P8 이식성 줄).
- 「스크립트가 강제」의 강제 장소(rc 를 읽는 스크립트인지, 훅인지)가 정해지지 않았다. 산문 지시는 강제가 아니고, 훅이면 kill switch 와 Stop 훅 고리 위험이 따라온다.
- 단계표가 틀렸거나 에픽 모양에 안 맞을 때의 탈출구를 지금은 락(RC3)과 지휘 절차(RC4)가 지킨다. 순서 강제는 그 탈출구와 정면으로 부딪히고, P23 반증 경로를 함께 설계하지 않으면 Sealed decision 이 된다.
- CLAUDE.md · 철학만 고치면 사본 문장(RC6)과 P8 이름 인용(RC7)이 옛 뜻으로 남는다. 헌장 락(RC8)은 이 어긋남을 못 잰다.

참고: plugin-audit 의 fixture(`plugins/plugin-audit/tests/fixtures/ac6_baseline.json` 등)는 P8 (부과 방향) 원문을 인용하지만, 고정된 1회 추출본이라 개정의 영향은 낮다고 보고 주장에 올리지 않았다. 사용자 자동 메모리 MEMORY.md 의 실제 크기도 레포 밖이라 주장에 싣지 않았다.

Sources:
- https://code.claude.com/docs/en/memory
- https://code.claude.com/docs/en/hooks
- https://www.anthropic.com/engineering/building-effective-agents
- https://arxiv.org/abs/2510.04618
- https://arxiv.org/abs/2507.11538
- https://arxiv.org/abs/2505.16067
- https://dbreunig.com/2025/06/22/how-contexts-fail-and-how-to-fix-them.html

### 조사 17 — open-researcher · R13 · 묶음 10

(하니스 표시: 출력에 settings-json · bypass-permissions 꼴 문구가 있어 제어 태그를 무력화했다 — 설정 키 · 권한 모드 서술이고 지시가 아니다)

조사 주문(mod 를 현황 · 토큰 표시 용도로만 쓸 때의 권한 범위와 끄는 길)의 결과입니다. 1차 자료는 code.claude.com 의 mods 문서 묶음과 changelog 이고, 확인한 날은 2026-11-14 입니다.

판 정보:
- 레포가 기록한 판: plugins/spec-distill/dependencies.md 의 claude-code 2.1.303 (기록 강도, 잰 날 2026-10-22).
- 최신 upstream: changelog 기준 2.1.323 (2026-11-12).
- 이 기계의 판 2.1.323 은 주문문에 적힌 값입니다. 저는 실행 도구가 없어 직접 재지 못했습니다.
- 2.1.303 과 2.1.323 사이에 아래 두 변경이 있습니다.
  - 2.1.304: tool.check 의 `e.isReadOnly`, 인터럽트 뒤 호출 거절, settings.read 계층.
  - 2.1.321: mod 자신의 `$.tool.call` · `$.mcp.call` 이 권한 질문을 띄우지 않게 됨.

```yaml
evidence:
  # ── (1) 권한에 닿는 이벤트 · 구독하지 않을 때 · 기본 가드 ──
  - url: "https://code.claude.com/docs/en/plugins/mods/reference.md"
    supports: both
    claim: "도구 이벤트는 셋이다. tool.call(도구 실행 직전, 반환 next(e) | {deny} | {result})는 도구 호출을 대신 답하거나 거절하거나 바꿀 수 있다. tool.check(PreToolUse 다음에 허용 여부를 정하는 자리, 반환 {decision: allow|ask|deny})는 권한 결정 자체다. tool.describe 는 도구 설명을 다시 쓴다. 설정 훅 이벤트마다 classic.<Event> 이벤트가 있다(e = 그 훅의 stdin JSON). 그래서 classic.PreToolUse · classic.PermissionRequest 도 이름상 구독할 수 있다. 그 밖에 prompt.submit(프롬프트 재작성 · drop), session.receive(다른 세션 메시지 소비), session.append(저장 행 재작성), settings.read(설정 값 재작성)가 세션 동작을 바꿀 수 있는 자리다."
    touches: []
    decides: [OQ28]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/mods/events.md"
    supports: current
    claim: "한 이벤트의 처리기들은 하나의 미들웨어 사슬을 이룬다. 각 mod 의 next 가 다음 mod 를 부르고, 마지막 next 가 Claude Code 자신의 동작에 닿는다. 훅은 on(eventName, handler) 로 등록한 이벤트에서만 돈다. 실패한 훅(throw · timeout · 잘못된 모양)이 next 를 부르기 전에 실패하면 건너뛰고 다음 처리기가 대신 돈다. 즉 tool.call · tool.check 에 등록하지 않은 mod 는 그 사슬에 들어가지 않는다. 다만 「구독하지 않으면 권한에 영향이 없다」고 명시한 문장은 찾지 못했다. 이 부분은 사슬 모델에서 끌어낸 추론이다."
    touches: []
    decides: [OQ28]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/plugins/mods/admin.md"
    supports: both
    claim: "기본 가드 sec-default@builtin(/plugin 표기 cc-plugin-sec-default)은 사용자가 설치한 모든 mod 보다 먼저 돌고 사용자가 끌 수 없다. 이 가드는 기계에 managed settings 나 managed-mcp.json 이 있을 때, 또는 세션이 Team · Enterprise /login 자격으로 돌 때만 실린다. API 키 · Bedrock 류 · 장기 CLAUDE_CODE_OAUTH_TOKEN 세션은 그 로그인으로 치지 않는다. 가드가 실리면 사용자 mod 는 관리되는 훅 · 시스템 프롬프트 · 관리 지침 · 설정 읽기 · 관리 MCP 를 바꾸지 못한다. deny 규칙과 ask 규칙, PreToolUse 차단을 넘어 승인하지도 못한다. 또 classic.<Event> · prompt.compose/section/context/attachment · skill.prompt · attribution.text · session.compact · settings.read · session.append{door=attachment|hook-context|compaction} 에 건 사용자 mod 훅은 아예 돌지 않는다. 반대로 가드가 실려도 사용자 mod 는 사용자 권한으로 파일 · 프로세스 · 네트워크에 닿는다. 권한 규칙과 PreToolUse 는 mod 의 $.fs · $.process 호출에 적용되지 않는다(Read(.env) 를 deny 해도 $.fs.read 로 읽힌다)."
    touches: []
    decides: [OQ28]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/permissions.md"
    supports: both
    claim: "섹션 'Precedence among rules, hooks, and mods'. managed settings, managed-mcp.json, Team · Enterprise /login 이 모두 없는 구성에서는 tool.check 를 다루는 mod 가 deny 규칙이 거절한 호출이나 PreToolUse 훅이 막은 호출도 승인할 수 있다. ask 규칙의 질문도 띄우지 않고 지나간다. auto 모드에서는 mod 가 승인한 호출이 classifier 검사 없이 돈다. plan 모드에서는 read-only 가 아닌 호출을 승인하지 못한다. 이 기계 · 사용자가 그 구성인지는 레포에서 알 수 없다."
    touches: []
    decides: [OQ28]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/changelog"
    supports: alternative
    claim: "2.1.321 Changed: \"Changed mods' own tool calls (`$.tool.call`, `$.mcp.call`) to raise no permission prompt, even under your own ask rules or in `dontAsk` and `-p` runs; deny rules and organization policy still apply\". 따라서 이벤트를 구독하지 않는 표시용 mod 라도 $.tool.call · $.mcp.call 을 부르면 ask 규칙을 건너뛰는 길이 생긴다. 권한 경계는 구독 이벤트만이 아니라 호출 목록(calls:)으로도 그어진다. 레포 기록 판 2.1.303 에는 이 변경이 없다."
    touches: []
    decides: [OQ28]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/mods/admin.md"
    supports: current
    claim: "`claude plugin validate <dir>` 는 mod 를 돌리지 않고 `hooks:`(받는 이벤트)와 `calls:`(부르는 $ 메서드) 줄을 낸다. `env reads:` · `env writes:` 줄은 변수 이름을 낸다. --json 으로 기계가 읽는 보고서도 나온다(reference.md Commands 표). Claude Code 는 이 명령이 읽지 못하는 방식으로 $ 를 쓰는 mod 를 싣지 않는다. 문서가 주의할 호출로 꼽는 것은 $.fs.read/write, $.process.run/spawn, $.http.fetch, $.env.get/set, $.settings.read, $.mcp.call, $.model.complete, $.prompt.submit, $.session.send 이고, 주의할 훅으로 꼽는 것은 tool.call, prompt.submit, session.append, tool.check 다. 표시 전용 mod 의 경계를 기계로 재는 수단이다."
    touches: []
    decides: [OQ28]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/changelog"
    supports: alternative
    claim: "turn.step 훅은 관찰만 해도 요청 경로 안에 있다. 2.1.318 Fixed: \"Fixed `claude -p` and Agent SDK sessions reporting success when an API error cut off a reply while a mod hooked `turn.step`\" 와 \"Fixed a mod's `turn.step` hook making a stopped reply finish as a success in headless runs\". 요청별 토큰을 보려고 turn.step 에 걸면 레포 기록 판 2.1.303 에서는 headless 성공 보고가 틀어질 수 있었다."
    touches: []
    decides: [OQ26, OQ28]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  # ── (2) 끄는 스위치 ──
  - url: "https://code.claude.com/docs/en/plugins/mods/overview.md"
    supports: both
    claim: "Turn mods on or off 섹션의 공식 스위치는 넷이다. (a) mod 하나: /plugin Installed 탭에서 그 플러그인을 비활성 · 제거한다(shell 에서는 `claude plugin disable <name>@<mkt>`, install.md). (b) 한 세션의 모든 설치 mod: --safe-mode. (c) 모든 세션의 모든 설치 mod: ~/.claude/settings.json 에 \"disableAllHooks\": true 를 둔다. 이러면 settings 훅과 custom status line 도 멈추고, 조직이 관리하는 것은 계속 돈다. (d) 조직: allowManagedModsOnly. disableAllHooks 와 allowManagedModsOnly 는 mod 만 멈추고 같은 플러그인의 skill · command · agent · MCP 는 계속 싣는다. disableAllHooks · --bare · --safe-mode 는 내장 mod 를 멈추지 않는다. CLAUDE_CODE_ENABLE_FUNCTION_HOOKS 는 v2.1.287 부터 무시되므로 0 으로 둬도 mod 가 꺼지지 않는다."
    touches: []
    decides: [OQ28]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/cli-reference"
    supports: both
    claim: "--safe-mode 는 CLAUDE.md, skills, plugins, hooks, MCP servers, custom commands · agents, output styles, workflows, custom themes · keybindings, status line · file-suggestion 명령, LSP, auto memory 를 싣지 않는다. 인증 · 모델 · 내장 도구 · 권한은 정상이다. managed 정책(정책 훅 · 상태줄)은 그대로 적용된다. CLAUDE_CODE_SAFE_MODE 를 설정한다. --bare 는 hooks, skills, custom commands, subagents, installed plugins, MCP, auto memory, CLAUDE.md 자동 발견을 건너뛰고 CLAUDE_CODE_SIMPLE 을 설정한다. cross-session-messaging.md 에 따르면 bare 세션은 inbox socket 도 묶지 않는다. 결국 둘 다 devbrew 플러그인 전체(훅 · skill)를 함께 끈다."
    touches: []
    decides: [OQ28]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/settings-reference"
    supports: both
    claim: "disableAllHooks 를 managed 가 아닌 설정 파일에 두면 user · project · local · plugin 훅이 꺼지고, 사용자가 설치한 mod 가 멈추고, custom status line · file suggestion 명령이 꺼진다(관리값만 남도록 좁혀짐). /goal 은 돌지 못한다. managed 훅 · Agent SDK 훅 · managed 강제 활성 플러그인 훅 · 조직 mod 는 계속 돈다. managed settings 에 두면 조직 mod 를 포함해 모든 설치 mod 와 managed 훅까지 멈춘다. 내장 mod 는 어느 경우에도 계속 돈다. 즉 이 스위치로 mod 를 끄면 devbrew 의 settings · plugin 훅(project-init · qg 등)도 함께 꺼진다."
    touches: []
    decides: [OQ28]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/mods/api.md"
    supports: current
    claim: "mod 안에서 환경 변수를 읽을 수 있다. $.env 는 get · set 을 갖고, 이름은 문자열 리터럴로 써야 한다(validate 의 env reads: 줄에 나온다). types d.ts 에는 '`name` must be a string literal … a name the module does not spell is refused' 라고 적혀 있다. 그래서 훅 첫머리에서 `$.env.get('DEVBREW_…_DISABLE')` 를 읽고 next(e) 만 돌려주는 자기 no-op 은 API 상 가능하다. 다만 register(on, options) 는 $ 를 받지 않는다(reference.md: register receives on and options). 그래서 load 시점에 등록 자체를 건너뛸 수는 없고, 각 훅이나 session.start 에서 판정해야 한다. 이 경우 훅은 등록되어 사슬에 남는다. 또 manifest userConfig 값은 register 의 options 로 들어온다."
    touches: []
    decides: [OQ28]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/anthropics/claude-code/main/mods/types/claude-code.d.ts"
    supports: current
    claim: "$.env.get 이 Claude Code 프로세스의 실제 셸 환경을 읽는지, settings 의 env 블록까지 반영하는지는 이 판의 문서 · 타입에서 확정하지 못했다. 타입 주석은 env.set 에 대해서만 'Sets the variable for this process and everything it starts after' 라고 적는다. GitHub 사본은 설치 판보다 오래될 수 있다고 문서가 공시한다."
    touches: []
    decides: [OQ28]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: uncertain
  # ── (3) 파일 읽기 · 타이머 · 프로세스의 제한 ──
  - url: "https://code.claude.com/docs/en/plugins/mods/reference.md"
    supports: both
    claim: "Limits 표의 값은 이렇다. 훅 자기 실행시간은 이벤트당 10초다(next · $ 호출 안의 시간은 빼고, $.clock.sleep 은 센다). .catch 처리기는 1초다. $.process.run 은 기본 30초, 최대 10분 timeout 이고 stdout · stderr 는 각 4 MiB(넘으면 isStdoutTruncated)다. $.fs.read · $.fs.write 는 파일 하나당 4 MiB다. $.store 는 전체 4 MiB 다. $.ui.invalidate('ui.render') 재그리기는 초당 10회(터미널의 보이는 pane · 띠 · 힌트줄은 30회)로 묶이고 초과분은 합쳐진다. $.fs 메서드는 read · write · list · exists · stat · ancestors 뿐이고 watch 는 없다. 그래서 파일 변화 감지는 $.clock.every 폴링(+ stat)으로 한다. $.fs.write 는 원자적이지 않다: \"replaces the file's content in place, so another process can read a partly written file. Keep data that several sessions change in `$.store`.\" 문서는 읽기 쪽 원자성은 따로 말하지 않는다. 다른 프로세스가 반쯤 쓴 파일을 mod 가 읽을 수 있다는 것은 추론이다."
    touches: []
    decides: [OQ26, OQ28]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/anthropics/claude-code/main/mods/types/claude-code.d.ts"
    supports: current
    claim: "clock.every 의 주석은 'Calls `fn` every `ms` milliseconds (at least 1) until `cancel()`.' 이고, 그 밖의 하한 · clamp 는 적혀 있지 않다. api.md 에 따르면 타이머 콜백은 이벤트 밖에서 돌아 turn 을 시작하지 않는다. 콜백이 throw 하면 debug log 로 가고 다음 주기에 다시 돈다. 모듈이 reload 되면 타이머가 멈춘다. process.run 옵션은 { cwd, env, stdin, timeoutMs } 이고 cwd 기본값은 세션 폴더다. GitHub 사본이 설치 판보다 오래될 수 있다."
    touches: []
    decides: [OQ26]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/plugins/mods/api.md"
    supports: both
    claim: "$.process.run 은 인자 목록을 받고 셸을 쓰지 않는다. exit code 와 무관하게 { exitCode, stdout, stderr } 로 끝나고, 시작 실패나 timeout 이면 reject 한다. 문서 예시가 이미 $.process.run(['git','branch','--show-current']) 와 $.clock.every(60_000, … $.process.run(['gh','pr','checks',…])) 를 쓴다. 그러니 git fetch 도 같은 길로 돌릴 수 있다. 근거는 셋이다: 사용자 권한으로 돌고, sandbox 밖이며, 권한 규칙 · PreToolUse 대상이 아니다(admin.md). 네트워크가 느리면 기본 30초 timeout 에 걸리므로 timeoutMs 를 올려야 한다(최대 10분). 조직 정책 mod 가 앞 사슬에서 process.run 이벤트를 거절할 수 있다."
    touches: []
    decides: [OQ28]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/mods/reference.md"
    supports: both
    claim: "토큰 표시용 자리는 다섯이다. (1) $.session.usage() 는 { startedAt, context:{tokens,window,percent}, rateLimits:[{kind,percentUsed,resetsAt}], cost } 를 돌려준다. d.ts 주석에 따르면 일반 호출은 비용이 없고, \"full\" 은 /context 처럼 token-count API 로 범주별로 센다. (2) session.measure 이벤트는 매 main-thread turn 뒤와 rate-limit 창이 한 포인트 움직일 때 발화한다(usage 수치를 push). (3) events.md 에 따르면 turn.step 결과의 result.usage 에 요청별 input_tokens · output_tokens · cache_read_input_tokens · cache_creation_input_tokens 가 있다. (4) turn.complete 의 e.usage 는 turn 합계다. (5) $.session 에는 compact 메서드도 있다(세부 동작 미확인)."
    touches: []
    decides: [OQ26]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code-playground/tree/main/claude-code/mods/token-weather"
    supports: current
    claim: "Anthropic 표본 mod token-weather 는 session.start · turn.complete · ui.render{component: AbovePrompt} 셋만 구독하고 $.session.usage() 로 context.tokens/window/percent 를 읽는다. 도구 · 권한 이벤트는 쓰지 않는다. tokens 는 uncached · cache-write · cache-read 를 합친 단일 값이라 캐시 읽기 · 새 입력 · 출력을 갈라 보이지 않는다. percent 는 auto-compact 문턱이 아니라 전체 창 기준이다. 표본은 지원 없이 공유된다."
    touches: []
    decides: [OQ26, OQ28]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  # ── (4) 세션 깨우기 · 감시자 겸임 ──
  - url: "https://code.claude.com/docs/en/plugins/mods/api.md"
    supports: alternative
    claim: "$.session.send({ to:{sessionId}|{agentId}|주소, text }) 는 SendMessage 도구와 같은 배달을 하고, 큐에 들어가면 { isDelivered:true } 로 끝난다. 자기 세션에서는 $.prompt.submit({ text }) 가 세션이 idle 이 될 때까지 기다렸다가 새 turn 을 시작한다(Claude 는 mod 이름을 밝힌 문장 뒤에 읽는다. asUser:true 면 사용자 말로 보낸다). 둘 다 $.clock.every 타이머 콜백에서 부를 수 있다. 그래서 '파일 변화를 폴링하다 지휘 세션을 깨우는' 감시자 역할을 API 상으로는 mod 가 겸할 수 있다. 제약도 있다. 사용자가 turn 을 멈춘 뒤에는 다음 사용자 입력까지 $.prompt.submit 은 {drop}, 끝난 subagent 로의 $.session.send 는 거절된다(v2.1.304+). 큐에 있던 prompt 는 버려지므로 turn.complete 에서 재시도해야 한다. -p 에서는 --max-turns · --max-budget-usd 에서 거절된다."
    touches: []
    decides: [OQ28]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/cross-session-messaging.md"
    supports: alternative
    claim: "받는 세션이 idle 이면 Claude Code 가 그 메시지로 새 turn 을 시작하고, 활동 중이면 도구 호출 사이에 읽는다. 받는 세션의 crossSessionInbound(accept · hold · refuse)가 적용된다. 값이 없으면 bypassPermissions 세션은 받은 메시지를 사용자 승인 대기로 잡는다. 받은 메시지는 권한 질문에 답할 수 없고, 설정을 바꾸게 할 수 없다. 안의 /compact 같은 명령은 평문으로 오고 실행되지 않는다. 같은 기계는 세션별 Unix socket(CLAUDE_CODE_MESSAGING_SOCKET · CLAUDE_CODE_MESSAGING_TOKEN, hooks · Bash 에 export)으로 배달하고 Anthropic 서버를 거치지 않는다. 자기 자식 프로세스가 자기 소켓에 쓴 메시지는 inbound 값이 없을 때 배달된다. 단 macOS 에서는 보낸 프로세스가 살아 있을 때만 프로세스 증거로 확인되고, 그 밖에는 토큰 auth 줄이 필요하다. 이 두 변수가 mod 의 $.process.run 자식에게도 export 되는지는 문서가 말하지 않는다. 받는 쪽은 반복 메시지를 rate-limit 하고 최대 50개만 큐에 둔다. 2.1.323 changelog 는 같은 기계 세션 간 무승인 전송 한도를 약 20에서 100,000 으로 바꿨다."
    touches: []
    decides: [OQ28]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  # ── (5) 위험 공시 · 승인 ──
  - url: "https://code.claude.com/docs/en/plugins/mods/overview.md"
    supports: both
    claim: "문서의 공시: 'A mod is code that runs with your permissions… Mods aren't sandboxed.' 할 수 있는 일로 사용자로서 파일 · 프로세스 · 네트워크 사용, env · 설정 파일의 비밀 읽기, 모든 프롬프트 · 도구 호출 보기 · 바꾸기, 다른 세션에 메시지 보내기, 질문 전에 도구 호출 승인하기, 사용량 쓰기를 꼽는다. sandbox 를 켜도 mod 가 시작한 프로세스는 그 밖에서 돈다. mod 는 권한 질문 화면을 다시 그리지 못한다(2.1.323 Fixed: mod 가 Claude Code 자신의 확인 질문 문구를 바꿀 수 있던 결함). 로드 확인은 /plugin 의 '1 mod active · <name>' 줄로 한다. 신뢰하지 않은 폴더에서는 trust prompt 에 답하기 전까지 어떤 mod 도 실리지 않는다(admin.md)."
    touches: []
    decides: [OQ28]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/security.md"
    supports: alternative
    claim: "설치 때 보이는 것은 /plugin 상세 창의 일반 신뢰 경고('Make sure you trust a plugin before installing, updating, or using it…', 어느 마켓플레이스든 같은 문구)와 'Will install' 목록이다. 이 목록은 commands · agents · skills · hooks · MCP/LSP 를 나열하는데, mod 를 따로 표시하는지는 문서에 없다. 설치하면 바로 활성된다(defaultEnabled:false 가 아니면). marketplace 로 설치하는 mod 에 대해 따로 동의 질문을 띄운다는 서술은 찾지 못했다. mod 전용 설치 경고가 없다고 확정한 것은 아니다. mod 를 켜는 질문이 있는 경우는 Claude 가 세션 안에서 쓴 mod 뿐이다(2.1.304 · 2.1.318 · 2.1.323 changelog). 2.1.321 부터는 그것도 auto · bypass 모드에서 묻지 않고 켜고, dontAsk 모드에서는 싣지 않는다."
    touches: []
    decides: [OQ28]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.323"}
    certainty: uncertain
repo_claims:
  - id: RC1
    path: "plugins/spec-distill/dependencies.md"
    anchor: "| claude-code | 2.1.303 | 2026-10-22 | 기록 | 잰 판을 기록만 한다 |"
    claim: "레포가 기록한 Claude Code 판은 2.1.303 이고 강도는 '기록'(최소 판을 강제하지 않음)이다. 2.1.304 의 tool.check isReadOnly · 인터럽트 뒤 호출 거절, 2.1.321 의 mod 자기 도구 호출 무질문은 이 기록 판 뒤의 변경이다."
    touches: []
    decides: [OQ28]
  - id: RC2
    path: "CLAUDE.md"
    anchor: "**모든 훅에 kill switch.** 진입 skill 도 같다. `DEVBREW_<PLUGIN>_DISABLE=1` 은 그 플러그인의 훅과 진입 skill 을 끈다"
    claim: "지금 규칙은 모든 훅이 DEVBREW_<PLUGIN>_DISABLE=1 · DEVBREW_SKIP_HOOKS=<plugin>:<이름> 을 존중해야 한다고 정한다. 문면의 '훅'은 settings · plugin 셸 훅을 전제로 쓰였다. mod(함수 훅)가 이 규칙에 드는지, 드는 경우 $.env.get 리터럴 이름으로 자기 no-op 을 구현하는지는 규칙에 적혀 있지 않다."
    touches: []
    decides: [OQ28]
  - id: RC3
    path: "CLAUDE.md"
    anchor: "**훅 공존.** 같은 event 내 훅은 교환 가능해야 함. `SessionStart` 훅은 read-only 조언자, 절대 mutate 안 함. 각 훅은 README의 Hooks Installed"
    claim: "지금 규칙은 같은 event 의 훅이 교환 가능하고 SessionStart 훅은 읽기 전용이라고 정한다. mod 는 사슬 순서(사용자 설치 mod 사이에서는 manifest dependencies 순, 모듈 안에서는 on 호출 순)가 결과를 바꿀 수 있다. 규칙 문면은 이 순서 의존을 다루지 않는다."
    touches: []
    decides: [OQ28]
unanswered: "넷을 확정하지 못했다. (1) 이 사용자 세션에서 기본 가드가 실리는지(managed settings 존재 · 로그인 종류)는 레포 밖 사실이라 모른다. (2) $.env.get 이 settings env 블록까지 반영하는지, mod 의 $.process.run 자식에게 CLAUDE_CODE_MESSAGING_SOCKET 이 export 되는지는 문서에 없다. (3) marketplace 로 설치하는 mod 에 따로 동의 질문이 뜨는지는 문서상 확인하지 못했다. (4) 설치 판 2.1.323 은 주문문 값이고 직접 재지 않았다. changelog 의 2.1.300 – 2.1.316 구간은 키워드 추출로만 훑었다."
```

참고 파일:
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/dependencies.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/CLAUDE.md

Sources:
- [Mods overview](https://code.claude.com/docs/en/plugins/mods/overview.md)
- [React to events with a mod](https://code.claude.com/docs/en/plugins/mods/events.md)
- [Use the mods API](https://code.claude.com/docs/en/plugins/mods/api.md)
- [Manage mods for your organization](https://code.claude.com/docs/en/plugins/mods/admin.md)
- [Mods reference](https://code.claude.com/docs/en/plugins/mods/reference.md)
- [Configure permissions](https://code.claude.com/docs/en/permissions.md)
- [Settings reference](https://code.claude.com/docs/en/settings-reference)
- [CLI reference](https://code.claude.com/docs/en/cli-reference)
- [Cross-session messaging](https://code.claude.com/docs/en/cross-session-messaging.md)
- [Plugin security and trust](https://code.claude.com/docs/en/plugins/security.md)
- [Install and manage plugins](https://code.claude.com/docs/en/plugins/install.md)
- [Changelog](https://code.claude.com/docs/en/changelog)
- [claude-code.d.ts (GitHub)](https://raw.githubusercontent.com/anthropics/claude-code/main/mods/types/claude-code.d.ts)
- [token-weather sample mod](https://github.com/anthropics/claude-code-playground/tree/main/claude-code/mods/token-weather)
- 2차(본문 근거로 쓰지 않음): [claudeissues.com 의 statusLine · disableAllHooks 이슈](https://claudeissues.com/issue/11744-bug-status-line-wont-show-if-disableallhooks-true)

## R13

### 지금 이해
포화 판정 2 의 빈 곳을 조사(묶음 9: 본체 직접 조사 15, 묶음 10: 조사 16 · 17 · 18 — 서로 기대지 않아 함께). 사용자 「재개하자」(턴 중) — 진행 중이었음을 알리고 이어 감. 판정자 입력 추출기 결함(블록 안 ### 소제목에서 잘림)을 고침.
- 확인 RC152 — 미확인 — plugins/project-init/hooks/hooks.json#Bash|EnterWorktree — 6행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC153 — 미확인 — plugins/project-init/hooks/post-tool-use.py#non-blocking — 17행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC154 — 미확인 — plugins/project-init/hooks/post-tool-use.py#branch: Created from  — 55행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC155 — 미확인 — plugins/project-init/hooks/post-tool-use.py#PROTECTED_BRANCHES — 86행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC156 — 미확인 — plugins/project-init/hooks/post-tool-use.py#def _judge — 497행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC157 — 미확인 — docs/git-workflow/branch-strategy.md#^(feature|fix|docs|chore)/ — 12행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC158 — 미확인 — docs/git-workflow/branch-strategy.md#직접 commit — 75행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC159 — 미확인 — docs/git-workflow/pr-process.md#Rebase — 47행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC160 — 미확인 — plugins/spec-distill/scripts/state_path.py#def state_root_for_common — 73행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC161 — 미확인 — plugins/spec-distill/scripts/state_path.py#def _write_ignore — 120행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC162 — 미확인 — plugins/spec-distill/references/conducting.md#하위 agent 의 자리 — 7행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC163 — 미확인 — plugins/spec-distill/references/conducting.md#cp — 43행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC164 — 미확인 — plugins/quality-gates/scripts/seal-worktree.sh#commit-tree — 62행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC165 — 미확인 — plugins/quality-gates/scripts/combine-tips.sh#commit-tree — 12행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC166 — 미확인 — plugins/plugin-audit/scripts/audit-sandbox.sh#hash-object — 114행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC167 — 미확인 — plugins/spec-distill/scripts/roadmap_status.py#GIT_ALLOWED — 16행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC168 — 미확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md### Flow — 197행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC169 — 미확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#security-reviewer — 65행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC170 — 미확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#Max-iter decision — 223행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC171 — 미확인 — plugins/quality-gates/scripts/artifact_max_rounds.sh#max_rounds — 2행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC172 — 미확인 — plugins/quality-gates/scripts/artifact_stagnation.py#stagnant — 4행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC173 — 미확인 — shared/docreview/scripts/docreview_config.py#rereview_cap — 13행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC174 — 미확인 — plugins/spec-distill/references/conducting.md#두 번까지 — 61행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC175 — 미확인 — plugins/spec-distill/references/conducting.md#대안 갈래로 일찍 옮긴다 — 50행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC176 — 미확인 — plugins/spec-distill/scripts/merge_check.py#종료 코드 — 15행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC177 — 미확인 — plugins/spec-distill/references/conductor-dispatch.md### 마지막 보고 — 14행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC178 — 미확인 — plugins/spec-distill/references/conductor-dispatch.md#마지막 전체 리뷰 — 72행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC179 — 미확인 — plugins/spec-distill/skills/epic-conductor/SKILL.md#spec-distill:integration-reviewer — 178행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC180 — 미확인 — plugins/spec-distill/skills/epic-conductor/SKILL.md#spec-distill:relay-checker — 197행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC181 — 미확인 — plugins/spec-distill/references/conducting.md#quality-pipeline — 78행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC182 — 미확인 — .claude-plugin/marketplace.json#./plugins/quality-gates — 12행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC183 — 미확인 — shared/tests/test_changelog_integrity.sh#CHANGELOG — 2행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC184 — 미확인 — plugins/spec-distill/CHANGELOG.md#CLAUDE_CONFIG_DIR — 3769행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC185 — 미확인 — plugins/quality-gates/scripts/artifact_branch_guard.sh#branch_ok: false — 12행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC186 — 미확인 — plugins/spec-distill/dependencies.md#| claude-code | 2.1.303 — 19행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC187 — 미확인 — CLAUDE.md#모든 훅에 kill switch — 71행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC188 — 미확인 — CLAUDE.md#훅 공존 — 72행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC189 — 미확인 — docs/philosophy/devbrew-harness-philosophy.md#### P8 — 78행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC190 — 미확인 — plugins/spec-distill/scripts/repo_defaults.py#PARALLEL_DEFAULT = 3 — 27행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC191 — 미확인 — plugins/spec-distill/tests/test_epic_handoff.sh#흐름을 고정하지 않는다 — 60행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC192 — 미확인 — plugins/spec-distill/references/conducting.md### 지휘 순환 — 3행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC193 — 미확인 — docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/flexibility-audit.md#기본은 X — 5행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC194 — 미확인 — plugins/spec-distill/tests/test_review_handoff_order.sh#기본은 X — 96행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC195 — 미확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#P8 determinism-economy — 327행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC196 — 미확인 — shared/tests/test_charter_citations.sh#헌장 — 3행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
→ 걷어낼 장치와 갈아타는 길 재개방: 조사 18 — seed 확인 문장(규칙 목차 120줄 · 새 규칙 맨 위 · 넘치면 합침 · 두 번 나오면 HANDBOOK 승격)의 근거가 이름 바꿈(S24)으로 사라지고, 합치기가 S27 의 출처 · 조건을 깎음
→ 결정론 경계(P8)와 단계표 재개방: 조사 18 — 숫자 멈춤은 지금 P8 아래서도 허용, 순서 강제는 기존 탈출구 락(test_epic_handoff.sh)과 정면 충돌, 동시 2 리터럴은 P8 이식성 줄 · PARALLEL_DEFAULT 권장 3 과 충돌 (S14 와 충돌)
조사 호출 17/60 · 이 라운드 본체 직접 1

### 다음 결정
OQ36 규칙 목차 운영 · OQ37 순서 강제의 탈출구와 동시 수 · OQ35 mod 의 감시자 겸임

### 질문
(b) 셋 묶음

### 답
→ S36 (OQ36) · S37 (OQ37) · S38 (OQ35) — 두 차원 다시 닫힘

### 조사 19 — orchestrator · R14 · 묶음 11

- 확인 RC197 — 확인 — ~/.claude/plugins/cache/claude-plugins-official/superpowers/7.0.2/skills/subagent-driven-development/references/fix-loop.md#20–59행 — 과제마다 고침 라운드 최대 5: 1–3 라운드는 원래 구현 일꾼을 이어 부르고, 4–5 라운드는 한 단계 강한 모델의 새 구현 일꾼, 5 라운드 재리뷰 뒤에도 남으면 차단기(breaker)로 멈춤. 라운드마다 원장에 `Task <N>: fix round <R>/5` [RC197 → OQ31]
- 확인 RC198 — 확인 — /Library/Application Support/ClaudeCode — 없음(이 기계에 macOS managed settings 없음) — 기본 가드 sec-default 는 Team · Enterprise 로그인일 때만 실리고 로그인 종류는 확인 못 함 [RC198 → OQ28]

## R14

### 지금 이해
포화 판정 3 의 빈 곳 둘을 본체가 직접 확인(조사 19, 묶음 11): SDD 고침 루프 과제당 5 라운드(1–3 이어 부름 · 4–5 강한 모델 · 차단기), 이 기계에 managed settings 없음. 남은 빈 곳 중 결정을 뒤집을 수 있는 것은 경로 조건 규칙 적재 하나, 셋은 설계 확인.
- 확인 RC197 · RC198 — 조사 19 블록 원문 그대로
[spec-distill] 포화 판정 3/5: 아직 — 빈 곳 6개, 다음: 기본 가드 · mod 자식 env 확인 · 조사 호출 17/60
조사 호출 17/60 · 이 라운드 본체 직접 2

### 다음 결정
OQ38 검수 상한 · 조사 범위(포화 판정 3 의 사용자 선택)

### 질문
(b) 둘 묶음

### 답
→ S39 (OQ38 SDD 에 맡김) · S40 (한 번만 더 — 경로 조건 규칙만 조사, 나머지는 OQ39 · OQ24 · OQ29 로 설계에)

## R15

### 지금 이해
S40 대로 경로 조건 규칙 적재 하나만 조사(조사 20, 묶음 12).
- 확인 RC199 — 확인 — .claude/#rules — 메인 체크아웃 · 이 worktree 둘 다 .claude/rules 없음(ls)
- 확인 RC200 — 확인 — .gitignore#/.claude/* · !/.claude/agents/ — 214–220행, .claude/ 아래는 agents/ 만 추적
- 확인 RC201 — 확인 — plugins/spec-distill/dependencies.md#claude-code — 19행 2.1.303
- 확인 RC202 — 확인 — plugins/project-init/CHANGELOG.md#2.2.0 — 258행 「.claude/rules/agent-tool-permission.md 를 만들던 경로를 제거한다」
- 확인 RC203 — 확인 — docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md#S36 — 원문 일치
- 웹: worktrees 문서 「default location under .claude/worktrees/ … doesn't load … .claude/rules/ … as it reads files there」 · plugins-reference rules 필드 없음 · 유지보수자 #72687 은 조사 원문 인용, 본체 재확인 안 함
→ 걷어낼 장치와 갈아타는 길 재개방: 조사 20 — S36 의 경로 조건 규칙이 격리 worktree 일꾼에 안 실림
조사 호출 18/60 · 이 라운드 본체 직접 1

### 다음 결정
OQ40 조건 붙은 규칙을 일꾼에게 닿게 하는 길

### 질문
(b) 하나

### 답
→ S41 (OQ40 시작 묶음에 골라 싣기) — 걷어낼 장치와 갈아타는 길 다시 닫힘

## R16

### 지금 이해
[spec-distill] 포화 판정 4/5: 아직 — 빈 곳 4개, 다음: 시작 묶음에 규칙을 다시 적는 이음매 확인 · 조사 호출 18/60
빈 곳 넷 모두 설계 단계 확인거리로 보임(OQ41 · OQ42 · OQ43 · OQ28). S40 「한 번만 더 — 그 뒤 마무리」.
조사 호출 18/60 · 이 라운드 본체 직접 0

### 다음 결정
마무리 여부 · 추천: 마무리

### 질문
(b) 하나

### 답
→ S42 (마무리) — 사용자 종료, 마지막 판정 아직

## 재결정 기록 (brief §5 기각 재료 — 원래 / 재결정 / 근거)

- seed 확인 「받는 쪽이 파일을 읽고 이해했음을 확인하는 약속(받음 확인 · 되읽기)」 → 되읽기를 전달 보증으로 쓰지 않고 산출물 대조로(받음 확인 · 대화 계약은 유지) — S8 · ST1 · S20
- seed 「리프레시 … 지휘 세션도 구현 담당자도 대상」 · 「토큰을 리프레시 신호로」 → 새 장치 없이 기존 장치 + 사용자 /compact, 리프레시는 품질 신호 — S7 · S12 · S13 · S20
- seed 확인 「설계문서 하나뿐인 작은 일도 지휘자를 거친다」 → 거치되 일꾼 하나 · 단계 최소로 가볍게 — S7 · S20
- seed 확인 「MEMORY.md 120줄 · 새 규칙 맨 위 · 넘치면 합치고 오래된 것은 HANDBOOK · 두 번 나오면 승격」 → 이름 바꿈(S24) · 조건 붙은 규칙은 적용 조건 칸 + 시작 묶음에 골라 싣기(S41 — 경로 조건 규칙은 격리 worktree 일꾼에 안 실려 버림) · 바이트 예산 · 반증 삭제 · 맨 위 안 함 · 반례 확인 승격 — S24 · S36 · 조사 18
- S17 「STATUS 는 계산해 쓴 추적 파일」의 자리 → 지휘자 상태 브랜치(main 에 머지 안 함) — S33 · S35 · 조사 13
- S14 「순서 · 숫자는 스크립트」 → 순서 강제 + 사람 승인 탈출구, 동시 수는 레포 설정 — S37 · 조사 18
- seed 확인 「구현 뒤 자체 검수가 … 세 번을 넘으면 더 돌리지 않고 보고한다」 → devbrew 가 따로 세지 않고 작업 방식(SDD 고침 루프 5 라운드 · 차단기)의 상한을 따름 — S39 · 조사 19
- S28 「감시자는 플러그인 monitor · 훅 + 자기 세션 소켓」 → mod 하나가 표시 + 감시 겸함 — S38 · 조사 12 · 17

### 판정 3 — saturation-judge · R13 (조사 블록 아님 — 판정 원문)

```yaml
verdict: not_saturated
novelty:
  - n: 1
    changed: []
    opened: "derived 축 10개(갈아타는 길 · 플랫폼 경계 · 실행 방식 능력표 · 역할 경계 집행 · 파일 믿음 경계 · 토큰 재기 · P8 경계 · 기계 간 조정 · 상태 배치 · 사람이 보는 면 · 작은 일) — OQ2–OQ10 의 바탕"
    failed: false
  - n: 2
    changed: [OQ2]
    opened: "없음"
    failed: false
  - n: 3
    changed: [OQ3, OQ5, OQ6]
    opened: "역할 폴더 CLAUDE.md 는 자동으로 실리지 않는다 — 일꾼이 역할 문서를 읽게 할 길(OQ7)"
    failed: false
  - n: 4
    changed: [OQ3, OQ4]
    opened: "없음"
    failed: false
  - n: 5
    changed: [OQ5, OQ6]
    opened: "없음"
    failed: false
  - n: 6
    changed: [OQ4]
    opened: "없음"
    failed: false
  - n: 7
    changed: [OQ7, OQ8]
    opened: "없음"
    failed: false
  - n: 8
    changed: [OQ8, OQ9, OQ10, OQ11]
    opened: "없음"
    failed: false
  - n: 9
    changed: [OQ15]
    opened: "없음"
    failed: false
  - n: 10
    changed: [OQ18]
    opened: "없음"
    failed: false
  - n: 11
    changed: [OQ25, OQ29, OQ30]
    opened: "상태 계산 · 지휘 원장 읽기가 superpowers 산출 형식(**Spec:** · Ruling:)에 묶임(OQ33)"
    failed: false
  - n: 12
    changed: [OQ21, OQ30]
    opened: "없음"
    failed: false
  - n: 13
    changed: [OQ21, OQ13]
    opened: "main 직접 커밋 금지와 STATUS 커밋 자리 충돌 — 상태 · 코드를 어느 브랜치에 모을까(OQ34 꼴)"
    failed: false
  - n: 14
    changed: [OQ26, OQ27]
    opened: "없음"
    failed: false
  - n: 15
    changed: []
    opened: "없음"
    failed: false
  - n: 16
    changed: [OQ31, OQ32]
    opened: "지휘자 상태 브랜치(S35)의 이름 접두와 branch-strategy 규칙(접두 넷 regex · 「모든 브랜치는 단명」 · main 에 머지 안 하는 오래 사는 브랜치에 대한 문장 없음) 사이의 예외를 어떻게 둘까"
    failed: false
  - n: 17
    changed: [OQ28, OQ26]
    opened: "현황 mod 가 기대는 Claude Code 판(2.1.304 · 2.1.321 변경)을 dependencies.md 의 기록 판 2.1.303 · 「기록」 강도에서 올릴지, 그리고 mod 가 CLAUDE.md kill switch · 훅 공존 규칙에 드는지"
    failed: false
  - n: 18
    changed: [OQ22, OQ24]
    opened: "seed 의 규칙 목차 운영을 조사 18 근거로 바꿀까(OQ36) · S14 순서 강제의 탈출구와 동시 수(OQ37) — 원장 R13 다시 열림 둘의 출처"
    failed: false
basis: "최근 두 묶음은 묶음 9(조사 15)와 묶음 10(조사 16 · 17 · 18)이다. 순서 검사 범위(블록 15–18)의 묶음 번호는 9,10,10,10 이라 어긋나지 않는다. 묶음 9: RC149 · RC150 은 조사 11 RC106 · RC107 의 입력 경로를 실행으로 다시 확인한 것이고, RC151(2.1.323 · 2026-10-15 · 백업 2,579)은 이미 있던 R11 값이다 — 새로움 없음. 묶음 10 은 결정을 바꾸고 새 결정을 열었다. 조사 16 RC17 「이 SKILL 에는 lint 단계가 없다」, RC24 「'같은 단계 N회 연속 실패' 같은 숫자 문턱은 지휘 절차에 없다」, RC21 「레포에 있는 유일한 '반복 감지' 술어」, unanswered 「'테스트 서버 배포' 에 해당하는 자동 장치는 레포에 없다」 가 OQ31 · OQ32 를 바꾼다. RC6 · RC7(상태 전용 접두는 훅이 경고, 「main 에 머지하지 않는 오래 사는 브랜치를 다루는 문장은 없다」)이 상태 브랜치 이름 결정을 새로 연다. 조사 17 의 2.1.321 「mods' own tool calls … raise no permission prompt」, disableAllHooks 가 「devbrew 의 settings · plugin 훅도 함께 꺼진다」, token-weather 는 「캐시 읽기 · 새 입력 · 출력을 갈라 보이지 않는다」 가 OQ28 · OQ26 을 바꾸고 최소 판 · kill switch 결정을 연다. 조사 18 의 120줄 근거 상실 · 합치기가 출처 · 조건을 깎음 · 동시 2 리터럴이 P8 이식성 줄과 충돌 · 강제 장소 미정은 원장 R13 다시 열림 둘(S27 · S14)의 출처이고, OQ22 · OQ24 를 바꾸고 OQ36 · OQ37 을 열었다. 실패한 조사는 없다."
gaps:
  - kind: confirm
    look_at: "조사 17 unanswered (1)(2): 이 사용자 세션에 기본 가드 sec-default 가 실리는지(managed settings · 로그인 종류), 그리고 mod 의 $.process.run 자식 · monitor 에게 CLAUDE_CODE_MESSAGING_SOCKET/TOKEN 이 export 되는지를 실제로 잰다. 시험 mod 를 `claude plugin validate` 로 돌려 hooks: · calls: 줄을 확인하고, 2.1.323 에서 env 를 출력한다. S28 감시자(자기 소켓)와 표시 전용 경계가 이 사실에 기댄다"
    may_change: [OQ28, OQ35]
    opens: "없음"
    device: orchestrator
  - kind: confirm
    look_at: "설치된 superpowers 7.0.2 캐시(subagent-driven-development 의 fix-loop.md · implementer/reviewer prompt)에서 과제 리뷰 · 최종 리뷰 구성과 재시도 · 되돌림 횟수를 읽는다. 조사 16 이 「외부 플러그인에 있어 읽을 수 없다」고 남긴 칸이다. 자체 검수 3회 · 같은 단계 2회 멈춤 · 1차 검수자가 이것과 겹치는지 본다"
    may_change: [OQ31, OQ23, OQ32]
    opens: "없음"
    device: orchestrator
  - kind: confirm
    look_at: "S35 지휘자 상태 브랜치를 branch-strategy.md(접두 regex · 「단명 브랜치」 · rebase 금지 범위)와 project-init 훅(만든 지 60초 안의 브랜치만 검사 · 이미 있는 브랜치 커밋은 검사 안 함)에 비춰 반대 논거를 세운다. 브랜치 문서를 고칠지, 접두를 어떻게 둘지, plumbing(commit-tree · update-ref)으로 쓸지를 따진다"
    may_change: [OQ21]
    opens: "상태 브랜치 이름 접두와 git workflow 문서 예외"
    device: steelman-builder
  - kind: confirm
    look_at: "조사 18 이 지적한 P8 개정의 파급을 전수로 센다. 「기본은 X … 모델이 판단」 사본 문장(finishing.md · test_review_handoff_order.sh AC22 핀, test_epic_handoff.sh AC31)과 P8 이름 인용(qg SKILL 327 · README 18 · artifact_branch_guard.sh 44 등)을 모두 찾는다. 그리고 「강제 장소」 후보(rc 를 읽는 스크립트인가, PreToolUse · Stop 훅인가)가 각각 무엇과 부딪히는지 적는다"
    may_change: [OQ24, OQ37]
    opens: "순서 강제를 거는 자리(스크립트 rc 대 훅)와 그 kill switch"
    device: repo-researcher
  - kind: confirm
    look_at: "S36 이 받은 경로 조건 규칙(.claude/rules/ + paths:)이 일꾼에게 실제로 실리는지 1차 문서에서 확인한다. 일꾼은 하위 agent · 격리 worktree 에서 돈다. 플러그인으로 배포되는 레포에서 이 규칙 파일이 어느 레포의 것인지도 본다. 조사 3 에서 역할 폴더 CLAUDE.md 가 자동으로 실리지 않았던 것과 같은 함정이 있는지 보는 것이다"
    may_change: [OQ22, OQ36, OQ16]
    opens: "없음"
    device: open-researcher
  - kind: explore
    look_at: "열린 OQ29(기존 설계문서 9개의 지휘 기록 · 도는 로드맵 이전)는 조사 11 의 한 줄 말고 닿은 조사가 없다. 9개 설계문서의 `## 지휘 기록` 꼴, 지금 도는 로드맵의 machine.md · relay 파일 · 실행 원장, 이들을 읽는 스크립트를 목록으로 낸다"
    may_change: [OQ29, OQ10]
    opens: "도는 로드맵을 새 구조로 옮길 때 끊김 없는 이전 순서"
    device: repo-researcher
```

판정은 아래 세 파일을 읽고 냈습니다.
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/.claude/tmp/interview-sat/decisions.txt
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/.claude/tmp/interview-sat/research_outputs.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/.claude/tmp/interview-sat/ledger.txt

조사 15–18(최근 두 묶음)은 원문을 끝까지 읽고 매겼습니다. 조사 1–14 는 판정에 필수가 아니어서 확인 정도가 다릅니다. 조사 1 · 2 는 원문을 다 읽었습니다. 조사 3–14 는 각 산출의 decides 칸 · unanswered 줄과 원장 다시 열림 기록으로 매겼고 원문을 다 읽지는 않았습니다. 그래서 OQ33 · OQ34 가 각각 조사 11 · 13 에서 열렸다는 귀속은 추정입니다.

### 조사 20 — open-researcher · R14 · 묶음 12

(하니스 표시: 출력에 settings-json 꼴 문구가 있어 제어 태그를 무력화했다 — 설정 서술이고 지시가 아니다)

조사 결과: 경로 조건 규칙(`.claude/rules/*.md` + `paths:`)에도 역할 폴더 하위 CLAUDE.md 와 같은 함정이 있다. 1차 문서가 직접 밝힌다.

- **실리는 때.** 이 규칙은 세션 시작 때 실리지 않는다. 맞는 파일에 Read · Write · Edit 을 쓸 때, 또는 단일 파일 `cat` · `head` 처럼 읽기로 치는 Bash 명령을 쓸 때 대화 기록에 실린다.
- **압축 뒤.** 압축하면 요약에 묻혀 사라지고, 다시 맞는 파일을 건드려야 다시 실린다.
- **하위 agent.** 메인이 이미 실은 경로 조건 규칙을 물려받지 않는다.
- **격리 worktree 하위 agent.** 기본 위치(`.claude/worktrees/`)의 worktree 에서 도는 하위 agent 는 그 worktree 루트의 `.claude/rules` 를 파일을 읽어도 싣지 않는다.
- **플러그인.** 플러그인 manifest 에 rules 구성 요소가 없다. Anthropic 담당자가 "아직 없다"고 답했다.
- **devbrew 레포.** `.claude/rules` 가 없다. `.gitignore` 가 `/.claude/*` 를 막고 `/.claude/agents/` 만 풀어 두어서, 지금 상태로 만들면 추적되지 않고 worktree 에도 생기지 않는다.

```yaml
evidence:
  # ── (1) 메인 세션 ──
  - url: "https://code.claude.com/docs/en/memory"
    supports: both
    claim: "A path-scoped rule loads when Claude uses the Read, Write, or Edit tool on a matching file. 단일 파일 cat · head 처럼 읽기로 치는 Bash 명령으로 봐도 실린다. paths 가 없는 규칙은 시작 때 .claude/CLAUDE.md 와 같은 우선순위로 실린다. 패턴의 기준 디렉토리는 프로젝트 규칙이면 그 규칙의 .claude 폴더를 담은 디렉토리, 사용자 규칙이면 세션의 primary working directory 다."
    touches: []
    decides: [OQ36, OQ22]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 (레포 기록)", latest: "2.1.325 (CHANGELOG 맨 위) — 문서는 최신판 기준"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/context-window"
    supports: both
    claim: "Path-scoped rules and nested CLAUDE.md files load into message history when Claude reads, writes, or edits their trigger file, so compaction summarizes them away. 압축 뒤에는 on demand 로 다시 실린다. 반드시 남아야 하는 규칙은 paths: 를 빼거나 루트 CLAUDE.md 로 옮기라고 한다. 한 번 실리면 다음 압축까지 기록에 남는다는 뜻이다."
    touches: []
    decides: [OQ36, OQ22]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/memory"
    supports: both
    claim: "Instructions seem lost after /compact 절: 루트 CLAUDE.md 는 디스크에서 다시 읽어 넣는다. 하위 CLAUDE.md 와 paths: 규칙은 다시 on demand 로 실린다. 압축 뒤 지시가 사라졌다면 «a path-scoped rule that hasn't matched a file since» 일 수 있다고 한다. on demand 로 실리는 규칙 파일에는 파일당 크기 상한이 있어 넘으면 앞부분만 실린다(v2.1.309 부터 적용)."
    touches: []
    decides: [OQ36]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/hooks"
    supports: both
    claim: "InstructionsLoaded hook 은 CLAUDE.md 나 .claude/rules 파일이 실릴 때마다 비동기로 발화한다. load_reason 값은 session_start · nested_traversal · path_glob_match · include · compact 이고, path_glob_match 일 때 globs 와 trigger_file_path 를 준다. 경로 조건 규칙이 실제로 실렸는지 관찰하는 공식 수단이다. 하위 agent 안에서도 발화하는지는 문서에 없다."
    touches: []
    decides: [OQ36]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/88565"
    supports: alternative
    claim: "열린 버그(유지보수자 응답 없음). Bash 로 하는 쓰기(sed -i · heredoc · python)와 파이프 · 리다이렉트 · `cd x && cat` 은 경로 조건 규칙을 싣지 않는다. 2.1.296 까지 재현됐다. auto · bypass 모드의 시스템 프롬프트가 Bash 편집을 권해 규칙이 조용히 빠진다고 보고한다. Edit 는 앞선 Read 를 요구해서 그 부작용으로 실린다."
    touches: []
    decides: [OQ36]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 (레포 기록)", latest: "2.1.325 — 이 판에서 고쳐졌다는 근거는 못 찾음"}
    certainty: confirmed
  # ── (2) 하위 agent ──
  - url: "https://code.claude.com/docs/en/sub-agents"
    supports: both
    claim: "What loads at startup: fork 가 아닌 하위 agent 는 새 문맥에서 시작한다. «doesn't see your conversation history ... or the files Claude has already read». 처음 문맥에는 메인 대화가 싣는 CLAUDE.md 계층(~/.claude/CLAUDE.md · project rules · CLAUDE.local.md · managed)이 들어간다. Explore 와 Plan 은 이를 건너뛴다. 규칙이 하위 agent 에 꼭 닿아야 하면 «restate it in the prompt» 하라고 한다."
    touches: []
    decides: [OQ36, OQ16, OQ22]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/sub-agents"
    supports: both
    claim: "omitClaudeMd: true(v2.1.271+)는 사용자 · 프로젝트 · 로컬 CLAUDE.md 없이 시작한다(managed 는 남는다). «For Explore, Plan, and subagents with omitClaudeMd, a subdirectory's CLAUDE.md and matching path-scoped rules still load when the subagent works with files there.» omitClaudeMd 는 시작 문맥만 막고, 그 하위 agent 가 직접 읽은 파일로 실리는 것은 막지 못한다. 플러그인 agent 도 omitClaudeMd 를 지원한다(plugins/components)."
    touches: []
    decides: [OQ36, OQ16]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/100366"
    supports: both
    claim: "2.1.293 에서 프록시로 잰 결과: omitClaudeMd 하위 agent 가 하위 디렉토리 파일을 Read 하면 그 디렉토리의 CLAUDE.md 와 맞는 paths: 규칙이 다음 요청에 system-reminder 로 붙었다. Explore 도 같았다. 같은 agent 에서 omitClaudeMd 를 빼면 시작 때 user · project · local · .claude/rules 를 모두 받았다. 보고자가 문서 반영을 확인하고 2026-10-15 에 닫았다(재측정은 안 함)."
    touches: []
    decides: [OQ36, OQ16]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/32906"
    supports: alternative
    claim: "메인이 src/test.ts 를 읽어 경로 규칙을 실은 뒤 general-purpose 하위 agent · teammate · context: fork skill 을 띄우면 셋 다 전역 규칙만 보고 경로 규칙은 못 봤다. 메인이 이미 켠 경로 트리거를 물려받지 않는다는 실측이다(2026-03). 문서 보강을 요청했지만 stale 로 자동 종료됐다."
    touches: []
    decides: [OQ36, OQ22]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/29423"
    supports: alternative
    claim: "2.1.62 보고: Task 하위 agent 가 프로젝트 CLAUDE.md · .claude/rules · ~/.claude/CLAUDE.md 를 싣지 않았다. 61467(2.1.148, 처음 문맥에 .claude/rules 블록이 없었다)이 이 이슈의 중복으로 닫혔다. 둘 다 유지보수자 응답 없이 자동 종료됐다. 위 100366(2.1.293 — 시작 때 다 받았다)과 지금 문서와 충돌하는 옛 판 실측이다. 둘 다 그대로 낸다."
    touches: []
    decides: [OQ36]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 (레포 기록)", latest: "2.1.325"}
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/sub-agents"
    supports: both
    claim: "옵션이 없는 평범한 하위 agent 가 맞는 파일을 직접 읽을 때 그 안에서 경로 규칙이 실리는지는 명시 문장이 없다. Explore · Plan · omitClaudeMd 에 대한 «still load» 문장과 worktrees 문서의 «also doesn't load ... as it reads files there» 문장이 평소에는 실린다는 것을 함의할 뿐이다. 실측(100366)은 omitClaudeMd · Explore 에 대해서만 있다. 메인이 실은 경로 규칙을 conversation fork 가 물려받는지도 문서가 직접 말하지 않는다. fork 는 부모 대화를 물려받으니 기록에 있는 규칙도 따라갈 것이라는 추론만 가능하다."
    touches: []
    decides: [OQ36]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  # ── (3) worktree ──
  - url: "https://code.claude.com/docs/en/worktrees"
    supports: alternative
    claim: "«A subagent in its own worktree takes the instruction files it starts with from your main conversation, not from its worktree. When that worktree is in the default location under .claude/worktrees/, the subagent also doesn't load the CLAUDE.md file or .claude/rules/ directory at the worktree's root as it reads files there, even if those differ on the worktree's branch.» 격리 worktree 하위 agent 는 시작 지시를 메인에서 받고, worktree 의 .claude/rules 는 읽기로도 싣지 않는다."
    touches: []
    decides: [OQ36, OQ16, OQ22]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/memory"
    supports: both
    claim: "«To have path-scoped rules load for files in a sibling git worktree, start Claude Code in that worktree or move the session there with /cd.» worktree 에서 연 세션의 프로젝트 규칙은 그 worktree 의 .claude 기준이다. 데스크톱 worktree 세션에서도 «CLAUDE.md files and .claude/rules/ still load from the worktree»(worktrees 문서)."
    touches: []
    decides: [OQ36]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/worktrees"
    supports: alternative
    claim: "worktree 는 «checks out only tracked files». 메인 체크아웃 읽어 오기는 .claude/skills · .claude/agents · .claude/commands 만 다룬다(skills 는 v2.1.277+). .claude/rules 는 이 목록에 없다. 추적되지 않는 .claude/rules 는 worktree 에 없고 대신 읽히지도 않는다. 옮기는 길은 .worktreeinclude(gitignore 된 파일 복사)뿐이다. sparsePaths 를 쓰면 .claude 를 목록에 넣어야 rules 가 worktree 에 있다(large-codebases)."
    touches: []
    decides: [OQ36]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/memory"
    supports: both
    claim: "User-level rules: «Claude Code loads user-level rules before project rules ... Neither set overrides the other: if a user rule and a project rule conflict, Claude may follow either one.» 사용자 경로 규칙의 기준은 세션의 primary working directory 다. 따라서 worktree 세션에서는 그 worktree 가 기준이 된다(추론)."
    touches: []
    decides: [OQ22]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/21858"
    supports: alternative
    claim: "2.1.25 보고: ~/.claude/rules 의 paths: 가 YAML 배열이면 무시되고 쉼표 문자열이면 됐다는 커뮤니티 관찰. 보고자가 유지보수자 확인 없이 'completed' 로 닫았다. 지금 문서는 둘 다 받는다고 쓴다."
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/worktrees"
    supports: alternative
    claim: "devbrew 처럼 worktree 가 메인 체크아웃 아래(.claude/worktrees/<name>)에 중첩될 때, 메인 세션이나 격리 하위 agent 가 worktree 안 파일을 읽으면 메인 체크아웃의 .claude/rules 패턴이 맞는지는 문서에 없다. 기준이 메인 루트라면 상대 경로가 .claude/worktrees/x/… 가 되어 `plugins/**` 류는 안 맞고 `**/…` 류만 맞을 것이라는 추론뿐이다."
    touches: []
    decides: [OQ36]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  # ── (4) 헤드리스 ──
  - url: "https://code.claude.com/docs/en/headless"
    supports: both
    claim: "--bare 가 없으면 claude -p 는 대화형 세션처럼 작업 디렉토리와 ~/.claude 의 구성을 찾아 싣는다. --bare(CLAUDE_CODE_SIMPLE)는 hooks · skills · commands · subagents · plugins · MCP · auto memory · CLAUDE.md 자동 탐색을 건너뛴다. 또 system reminder 를 보내지 않는다. .claude/rules 를 따로 이름 대지는 않는다."
    touches: []
    decides: [OQ36]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/headless"
    supports: alternative
    claim: "--bare 에서 경로 조건 규칙이 실리는지는 문서에 직접 문장이 없다. 하위 agent 에서는 경로 규칙이 system-reminder 로 붙었다(100366). bare 모드는 system reminder 를 보내지 않는다. 그래서 bare 에서는 실리지 않을 공산이 크다는 추론뿐이다. -p 에서 --bare 는 앞으로 기본값이 될 예정이라고 문서가 밝힌다. --setting-sources 에서 project 를 빼면 on demand 규칙도 빠진다(v2.1.211+)."
    touches: []
    decides: [OQ36]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  # ── (5) 플러그인 ──
  - url: "https://code.claude.com/docs/en/plugins-reference"
    supports: alternative
    claim: "plugin.json 구성 요소 필드는 skills · commands · agents · hooks · mcpServers · lspServers · outputStyles · workflows · experimental(themes · monitors · evals) · channels · userConfig 다. rules 필드는 없다. 모르는 최상위 키는 떼어 내고 로드한다. «A CLAUDE.md at the plugin root isn't loaded as context» — 지시를 넣으려면 skill 로 넣으라고 한다."
    touches: []
    decides: [OQ22, OQ16, OQ36]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 (레포 기록)", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/72687"
    supports: alternative
    claim: "Anthropic 유지보수자 bcherny(2026-08-17): 플러그인 수준 rules/ 디렉토리는 아직 없다. 우회로 플러그인 skill 의 SKILL.md 에 paths: 를 두면, 플러그인을 깐 어느 프로젝트에서든 맞는 파일을 다룰 때 그 skill 을 자동으로 싣는다. 1급 플러그인 규칙은 #14200 으로 추적한다. 따라서 플러그인을 쓰는 다른 레포에서 경로 조건 규칙 파일은 그 레포의 .claude/rules(또는 사용자 ~/.claude/rules)에 있어야 한다."
    touches: []
    decides: [OQ22, OQ36]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/14200"
    supports: alternative
    claim: "'Add rules support to Plugins' 는 열려 있다(2025-12 시작, 마지막 댓글 2026-10-26, 유지보수자 응답 없음). 커뮤니티 측정(2.1.310): paths: skill 은 description 만 실리고 본문은 모델이 부를 때만 실려 «hint rather than a rule» 로 작동했다. 이는 위 유지보수자 설명과 충돌하고 둘 다 낸다. --add-dir 과 CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD 조합에서는 paths: 규칙이 발화하지 않았다(memory 문서도 추가 디렉토리는 paths 규칙을 빼고 싣는다고 쓴다). 그 밖의 우회는 SessionStart hook 으로 ~/.claude/rules 에 복사하기와 PostToolUse(Read) hook 의 additionalContext(1만 자 상한)다."
    touches: []
    decides: [OQ22, OQ36]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/skills"
    supports: alternative
    claim: "skill frontmatter 의 paths 는 «When set, Claude loads the skill automatically only when working with files matching the patterns. Patterns are relative to Claude's current working directory». 플러그인 skill 을 포함해 모든 수준의 skill 이 이 필드를 받는다. 하위 agent · 압축 뒤 동작은 이 페이지에 없다."
    touches: []
    decides: [OQ22, OQ36]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/large-codebases"
    supports: both
    claim: "하위 디렉토리 CLAUDE.md(그 폴더 안, 소유자가 관리, on demand)와 .claude/rules 경로 규칙(레포 루트의 중앙 .claude, paths: glob 이 맞을 때)을 고르는 표를 준다. 층이 커지면 플러그인 skill · hook 으로 중앙화하라고 권한다. 이 페이지는 rules 를 플러그인 구성 요소로 들지 않는다."
    touches: []
    decides: [OQ16, OQ22, OQ36]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://releases.sh/anthropic/claude-code-releases.md"
    supports: both
    claim: "2차 요약에 따르면 v2.1.293 에서 단일 파일 cat · head · tail · sed -n · grep 으로 볼 때 경로 규칙과 하위 CLAUDE.md 가 안 실리던 문제가 고쳐졌다. 공식 CHANGELOG 원문에서는 이 항목을 확인하지 못했다(파일이 125만 자라 앞 10만 자만 읽음)."
    touches: []
    decides: []
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain
repo_claims:
  - id: RC1
    path: ".claude/"
    anchor: "rules/ 부재 — Glob `rules/**` 0건(메인 체크아웃 /Users/jeonghokim/Downloads/devbrew/.claude 와 이 worktree 둘 다)"
    claim: "devbrew 에는 지금 .claude/rules 가 없다. 사용자 전역 ~/.claude/rules 도 이 기계에 없다(디렉토리 부재)."
    touches: []
    decides: [OQ36, OQ22]
  - id: RC2
    path: ".gitignore"
    anchor: "`.claude/` · `!/.claude/` · `/.claude/*` · `!/.claude/agents/`"
    line: 214
    claim: "레포 루트의 .claude/ 아래는 agents/ 만 추적되고 나머지는 무시된다. .gitignore 에 `!/.claude/rules/` 를 더하지 않으면 새 .claude/rules 는 추적되지 않는다. 그러면 worktree(추적 파일만 체크아웃)에도 다른 클론에도 생기지 않는다. 문서상 메인 체크아웃 읽어 오기 대상(skills · agents · commands)에도 들지 않는다. .worktreeinclude 도 레포에 없다."
    touches: []
    decides: [OQ36]
  - id: RC3
    path: "plugins/spec-distill/dependencies.md"
    anchor: "| claude-code | 2.1.303 | 2026-10-22 | 기록 | 잰 판을 기록만 한다 |"
    line: 19
    claim: "레포가 기록한 Claude Code 판은 2.1.303 이다. 문서에 판 경계로 적힌 것 가운데 이 판보다 뒤에 오는 것은 on demand 규칙 파일당 크기 상한(v2.1.309)이다. omitClaudeMd(2.1.271) · bare 제한(2.1.286) · -p 규칙 제외(2.1.211)는 이 판보다 앞선다."
    touches: []
    decides: []
  - id: RC4
    path: "plugins/project-init/CHANGELOG.md"
    anchor: "## [2.2.0] — 2026-08-23 — `/project-init` 이 `.claude/rules/agent-tool-permission.md` 를 만들던 경로를 제거한다."
    line: 256
    claim: "devbrew 는 전에 플러그인이 대상 레포에 .claude/rules 파일을 쓰게 했다가 제거한 이력이 있다. 제거 이유는 개인 설정이고, 대상 레포에 git 제외 파일을 만들고 .gitignore 까지 고치는 것이 범위 밖 부작용이라는 것이다. 2.1.0 노트에는 「`.claude/` 통째 무시는 금지 — 대상 레포가 `.claude/settings.json` 등을 추적 중일 수 있다」가 있다. 플러그인 사용 레포에 규칙 파일을 두는 길의 선례다."
    touches: []
    decides: [OQ22, OQ36]
  - id: RC5
    path: "docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md"
    anchor: "S36 … 「조건 붙은 규칙은 경로 조건 규칙(.claude/rules)으로」"
    line: 128
    claim: "S36 은 조건 붙은 규칙을 경로 조건 규칙으로 옮기기로 정했다. 같은 파일 5156행 look_at 은 그 규칙이 하위 agent · 격리 worktree 의 일꾼에게 실리는지 확인하라는 이 조사의 출처다. 위 evidence 가운데 worktrees 문서 인용 · 32906 · plugins-reference 는 S36 의 전제(일꾼에게 실린다)를 흔드는 근거다."
    touches: []
    decides: [OQ36]
unanswered: "확인 못 한 것: 평범한 하위 agent 가 직접 읽을 때 경로 규칙이 실린다는 명시 문장 · fork 상속 · --bare 에서 규칙이 실리는지 · 중첩 worktree 안 파일에 메인 체크아웃 규칙 패턴이 맞는지 · InstructionsLoaded 가 하위 agent 안에서도 발화하는지. 모두 문서에 직접 문장이 없어 uncertain 이다. 공식 CHANGELOG 는 125만 자 가운데 앞 10만 자(2.1.318~2.1.325)만 읽었다. 기계 설치판 2.1.323 은 주문의 값을 그대로 썼고 직접 재지 않았다."
```

**본체가 판단할 때 볼 것** (판정은 하지 않는다):

1. **역할 폴더 함정과 같은 모양이다.** 경로 조건 규칙도 하위 CLAUDE.md 처럼 맞는 파일을 건드릴 때만 실린다. 하위 agent 는 메인이 실은 것을 물려받지 않는다. 격리 worktree 하위 agent 는 worktree 의 `.claude/rules` 를 읽기로도 싣지 않는다.
2. **문서가 권하는 대응.** 하위 agent 에 꼭 닿아야 하는 규칙은 위임 프롬프트에 다시 적거나 paths 없는 규칙 · 루트 CLAUDE.md 로 두라고 한다.
3. **실측끼리 충돌한다.** 옛 판(2.1.62 · 2.1.148)에서는 하위 agent 가 시작 때 `.claude/rules` 를 못 받았다. 2.1.293 측정과 지금 문서는 시작 때 받는다고 한다. 둘 다 냈다.
4. **플러그인 skill 의 `paths:` 를 대안으로 볼 때.** 유지보수자는 그 skill 이 자동으로 실린다고 했고, 커뮤니티 측정(2.1.310)은 description 만 실린다고 했다. 이 충돌도 그대로 둔다.

**확인한 레포 파일**
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/.gitignore (214–220행)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/dependencies.md (19행)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/project-init/CHANGELOG.md (256–311행)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md (128 · 5156행)

Sources:
- [memory](https://code.claude.com/docs/en/memory)
- [sub-agents](https://code.claude.com/docs/en/sub-agents)
- [worktrees](https://code.claude.com/docs/en/worktrees)
- [context-window](https://code.claude.com/docs/en/context-window)
- [headless](https://code.claude.com/docs/en/headless)
- [cli-reference](https://code.claude.com/docs/en/cli-reference)
- [env-vars](https://code.claude.com/docs/en/env-vars)
- [hooks](https://code.claude.com/docs/en/hooks)
- [plugins-reference](https://code.claude.com/docs/en/plugins-reference)
- [plugins/components](https://code.claude.com/docs/en/plugins/components)
- [skills](https://code.claude.com/docs/en/skills)
- [large-codebases](https://code.claude.com/docs/en/large-codebases)
- [CHANGELOG.md](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md)
- 이슈: [#32906](https://github.com/anthropics/claude-code/issues/32906) · [#29423](https://github.com/anthropics/claude-code/issues/29423) · [#61467](https://github.com/anthropics/claude-code/issues/61467) · [#100366](https://github.com/anthropics/claude-code/issues/100366) · [#21858](https://github.com/anthropics/claude-code/issues/21858) · [#88565](https://github.com/anthropics/claude-code/issues/88565) · [#14200](https://github.com/anthropics/claude-code/issues/14200) · [#72687](https://github.com/anthropics/claude-code/issues/72687)
- 2차: [releases.sh](https://releases.sh/anthropic/claude-code-releases.md)

### 판정 4 — saturation-judge · R15 (조사 블록 아님 — 판정 원문)

```yaml
verdict: not_saturated
novelty:
  - n: 15
    changed: []
    opened: "없음"
    failed: false
  - n: 16
    changed: []
    opened: "지휘자 상태 브랜치의 이름 접두 · git workflow 예외 · plumbing 으로 쓸지(OQ39)"
    failed: false
  - n: 17
    changed: []
    opened: "없음"
    failed: false
  - n: 18
    changed: [OQ22, OQ24]
    opened: "seed 의 규칙 목차 운영을 조사 18 근거로 바꿀까(OQ36) · S14 순서 강제의 탈출구와 동시 수(OQ37)"
    failed: false
  - n: 19
    changed: []
    opened: "자체 검수 되돌림 상한을 superpowers SDD 고침 루프(5 라운드 · 1–3 이어 부름 · 4–5 강한 모델 · 차단기)에 맡길까(OQ38)"
    failed: false
  - n: 20
    changed: [OQ36]
    opened: "조건 붙은 팀 규칙을 일꾼에게 닿게 하는 길 — 경로 조건 규칙이 격리 worktree 하위 agent 에 안 실림(OQ40)"
    failed: false
basis: "최근 두 묶음은 묶음 11(조사 19)과 묶음 12(조사 20)다. 순서 검사(조사 19부터 끝까지) 결과 11→12 로 어긋남이 없다. 실패한 조사는 없다. 두 묶음 모두 새로운 것을 냈다. (1) 조사 19 RC197 — fix-loop.md#20–59 「과제마다 고침 라운드 최대 5: 1–3 … 4–5 … 차단기(breaker)로 멈춤」. 결정 OQ38 이 이 문구를 그대로 담고 있어, 이 줄이 OQ38 을 연 것으로 매겼다. RC198 은 「로그인 종류는 확인 못 함」으로 OQ28 을 바꾸지 못했다. (2) 조사 20 — worktrees 문서 「the subagent also doesn't load … .claude/rules/ directory at the worktree's root as it reads files there」. 여기에 plugins-reference(rules 필드 없음)와 RC2(.gitignore `/.claude/*` 가 rules 를 추적 밖에 둠)가 겹쳐 S36 의 전제가 깨졌다. 원장 reopen_log round 14 에 conflicts_with: S36 이 있고, OQ36 이 바뀌었으며 OQ40 이 새로 열렸다. 규칙 3에 따라 not_saturated 다. 참고로 조사 1–14 의 novelty 는 최근 두 묶음 밖이라 매기지 않았다. 조사 15–18 은 앞뒤 사정을 보이려고 실었다. 그중 18 의 changed 는 원장 reopen_log round 13 과 OQ36·OQ37 문구에서 추정한 것이다."
gaps:
  - kind: confirm
    look_at: "S41(지휘자가 적용 조건 칸을 보고 시작 묶음에 골라 실음)이 실제로 닿는지 확인한다. 지금 지휘 절차서(plugins/spec-distill/references/conducting.md)와 하위 agent 자리 규칙(CHANGELOG 416줄 도입 기록)에서 위임 프롬프트를 짓는 자리를 찾는다. 그 자리에 규칙 본문을 다시 적는 이음매가 있는지, 그리고 S36 바이트 예산이 그 묶음 크기를 재는 단위와 맞는지 본다."
    may_change: [OQ40, OQ36, OQ22]
    opens: "없음"
    device: repo-researcher
  - kind: confirm
    look_at: "OQ38 을 SDD 고침 루프에 맡겼을 때 OQ31(같은 단계 2회 연속 실패 멈춤)과 이어지는지 확인한다. devbrew 가 `Task <N>: fix round <R>/5` 줄과 차단기 멈춤을 읽을 수 있는지(roadmap_status.py 등 원장 읽기)를 본다. superpowers 7.0.2 최소 판이 dependencies.md 에 적혀 있는지도 본다."
    may_change: [OQ38, OQ31]
    opens: "superpowers 고침 루프 형식에 대한 새 결합을 dependencies.md 에 어떻게 핀할까"
    device: repo-researcher
  - kind: explore
    look_at: "S41 의 숨은 가정을 찾는다. 하나는 지휘자 자신도 압축 뒤 규칙 파일의 조건 칸을 다시 읽어야 고를 수 있다는 점이다. 다른 하나는 플러그인을 쓰는 다른 레포에 rules 도 없고 skill paths: 는 「hint rather than a rule」로 갈린다는 점(조사 20 #14200 대 #72687 충돌)이다. 이 둘이 OQ22 의 상한 · 이름 결정에 무엇을 거꾸로 요구하는지 본다."
    may_change: [OQ40, OQ22]
    opens: "플러그인 사용 레포에서 조건 규칙 파일을 둘 자리"
    device: blind-spot-prober
  - kind: explore
    look_at: "RC198 이 남긴 빈칸을 채운다. 이 기계의 로그인 종류(Team · Enterprise 인지)와 sec-default 기본 가드가 실리는지를 직접 확인하고, 현황 mod 의 안전 경계에 닿는지 본다."
    may_change: [OQ28]
    opens: "없음"
    device: orchestrator
```

입력 파일:
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/.claude/tmp/interview-sat/decisions.txt
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/.claude/tmp/interview-sat/research_outputs.md (조사 15–20 은 원문을 직접 읽었다. 조사 1–14 는 블록 머리말만 확인했다.)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/.claude/tmp/interview-sat/ledger.txt

## 분해안

| 번호 | 이름 | 종류 | 의도 | 범위 | 의존 | 브랜치 | 경로 예약 | 배정 번호 | 받는 것 | 넘기는 것 | 크기 | 병렬 | 순서 이유 | 근거 | 흐름 | 산출물 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P1 | 토큰 기준선 | 묶음 | 재설계 전 지휘 세션 · 하위 agent 토큰을 갈라 재어 비교 기준을 남긴다 | 한다: 백업한 세션 기록으로 캐시 읽기 · 쓰기 · 새 입력 · 출력을 갈라 측정(message.id 중복 제거) / 안 한다: 측정 도구 제품화 | 없음 | feature/token-baseline | docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/token-baseline.md | C22 · D11 · D34 · OQ5 · OQ26 · OQ27 · RC34 · RC151 · K9 · K10 · S1 · S2 · S6 · S7 · S31 · S42 · «cc-issue-87303» · «cc-prompt-caching» · «cc-statusline» | 백업 세션 기록 | 기준선 수치 · 측정 방법 | 작음 | R1 과 병렬 | 재설계 전에 재야 비교가 된다 | S31 · 조사 14 | 조사 — 백업 기록에서 로드맵 세션을 골라 지휘 · 하위로 갈라 집계 | docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/token-baseline.md |
| R1 | 팀 파일 규약 | 묶음 | 과제 폴더 · INTENT.md · 역할 문서 · 규칙 목차 · 시작 묶음을 세워 읽기 설계의 바닥을 깐다 | 한다: 에픽 묶음 + 지휘 기록 → INTENT.md, results/, 역할 폴더(레포 공통) · 팀 전용 목록, 규칙 목차(새 이름) · HANDBOOK 운영과 경계 장치, 시작 묶음 고르기 스크립트, devbrew 파일 기준 단계 계산 / 안 한다: 지휘 절차서 개편 | 없음 | feature/team-file-contract, feature/team-file-read, feature/team-file-rules | plugins/spec-distill/scripts/roadmap_write.py, plugins/spec-distill/scripts/roadmap_render.py, plugins/spec-distill/scripts/roadmap_model.py, plugins/spec-distill/scripts/roadmap_status.py, plugins/spec-distill/scripts/check_bundle_coverage.py, plugins/spec-distill/scripts/spec_review_bundle.py, plugins/spec-distill/references/epic-handoff.md, plugins/spec-distill/scripts/team_layout.py, plugins/spec-distill/scripts/team_files.py, plugins/spec-distill/scripts/team_check.py, plugins/spec-distill/scripts/team_write.py, plugins/spec-distill/scripts/team_rules.py, plugins/spec-distill/scripts/start_bundle.py, plugins/spec-distill/scripts/job_results.py, plugins/spec-distill/scripts/workflow_superpowers.py, plugins/spec-distill/scripts/team_status.py, plugins/spec-distill/scripts/branch_tip.py, plugins/spec-distill/references/team-files.md, plugins/spec-distill/templates/team/, plugins/spec-distill/scripts/conductor_ledger.py, plugins/spec-distill/scripts/repo_defaults.py, plugins/spec-distill/scripts/control_plane.py, plugins/spec-distill/references/roadmap-ontology.md, REVIEW.md, docs/superpowers/roadmaps/HANDBOOK.md, docs/superpowers/roadmaps/leader/, docs/superpowers/roadmaps/designer/, docs/superpowers/roadmaps/writer/, docs/superpowers/roadmaps/worker/ | C1 · C2 · C4 · C10 · C15 · C22 · C35 · C36 · C38 · C42 · C47 · C49 · C50 · D7 · D12 · D14 · D20 · D21 · D23 · D24 · D25 · D28 · D30 · D33 · D48 · OQ1 · OQ7 · OQ8 · OQ10 · OQ12 · OQ16 · OQ17 · OQ19 · OQ20 · OQ22 · OQ25 · OQ33 · OQ36 · OQ40 · OQ41 · OQ43 · OQ45 · OQ47 · OQ48 · RC1 · RC5 · RC101 · RC199 · RC200 · RC202 · K2 · K3 · K4 · K8 · K11 · ST1 · S1 · S2 · S8 · S10 · S11 · S12 · S15 · S16 · S20 · S21 · S22 · S23 · S24 · S25 · S26 · S27 · S32 · S36 · S41 · S48 · S49 · S50 · «anthropic-context-eng» · «cc-memory» · «cc-worktrees» · «cognition» · «exp-following» · «mast» | 없음 | 과제 폴더 · INTENT.md · results/ 형식, 규칙 목차 형식, 시작 묶음 고르기 스크립트, 파일 기준 단계 계산 | 큼 | P1 과 병렬 | 나머지가 이 파일 형식을 읽는다 | S8 · S21 · S41 | 없음 | 없음 |
| R2 | 지휘 걸음과 관문 | 묶음 | 지휘의 걸음을 단계표로 세우고 순서 · 승인을 스크립트가 지키게 하며 사용자 자리를 걸음에 못 박는다 | 한다: 단계표(형식 · 실행기 칸 · 사람 단계), 순서 강제 + 사람 승인 탈출구(승인된 설계 없이는 계획 · 구현이 시작되지 않는다 · 해시 승인), 같은 단계 연속 실패 멈춤, 사용자 자리(방향 · 설계 대화, 계획이 나왔을 때 · 구현 중 설계에 닿는 물음 · PR 전), 담당자 물음을 원문 그대로 옮기기, 담당자는 시작 묶음으로만 보낸다(보내는 글 틀을 시작 묶음으로), 사람 줄은 세션 기록에서 사람이 한 말 · 고른 답을 찾아 적는다(모델이 지어낸 줄은 통과하지 못한다), 동시 수 레포 설정, SDD 고침 루프 위임, superpowers 결합을 단계 맞춤으로, P8 · CLAUDE.md 개정 / 안 한다: 세션으로 보내기 · 거두기, 절차서 쪼개기 · 리더 다시 띄우기, 상태 브랜치 | R1 | feature/conductor-stage-table, feature/conductor-walk-table | plugins/spec-distill/references/conducting.md, plugins/spec-distill/references/conductor-dispatch.md, plugins/spec-distill/skills/epic-conductor/SKILL.md, plugins/spec-distill/scripts/repo_defaults.py, plugins/spec-distill/scripts/start_bundle.py, plugins/spec-distill/scripts/team_status.py, docs/philosophy/devbrew-harness-philosophy.md, CLAUDE.md, plugins/spec-distill/references/docreview-profiles/design-doc.md, plugins/spec-distill/scripts/conductor_ledger.py, plugins/spec-distill/scripts/session_record.py, plugins/spec-distill/scripts/human_lines.py, plugins/spec-distill/scripts/walk_table.py, plugins/spec-distill/references/walk-table.md, plugins/spec-distill/scripts/team_files.py, plugins/spec-distill/scripts/roadmap_model.py, plugins/spec-distill/scripts/job_results.py, plugins/spec-distill/scripts/team_layout.py, plugins/spec-distill/references/proceed-gate.md, plugins/spec-distill/references/team-files.md, plugins/spec-distill/dependencies.md, plugins/spec-distill/templates/team/, docs/superpowers/roadmaps/leader/, docs/superpowers/roadmaps/designer/, docs/superpowers/roadmaps/writer/, docs/superpowers/roadmaps/worker/, plugins/spec-distill/scripts/control_plane.py | C2 · C6 · C39 · C40 · C41 · C44 · C46 · D11 · D17 · D27 · D28 · D32 · D45 · OQ9 · OQ18 · OQ23 · OQ24 · OQ30 · OQ31 · OQ32 · OQ37 · OQ38 · OQ42 · OQ44 · RC2 · RC6 · RC14 · RC149 · RC150 · RC189 · RC190 · RC191 · RC197 · K1 · K5 · K13 · K14 · S1 · S7 · S14 · S29 · S37 · S39 · S40 · S43 · S44 · S47 · «mattpocock» · «pstack» · «superpowers-sdd» | R1 의 파일 형식 · 시작 묶음 스크립트 | 단계표 형식 · 순서와 승인을 지키는 스크립트 · 사용자 자리 · 새 P8 · 시작 묶음으로 보내는 글 틀 | 큼 | R3 와 병렬 가능 | R1 형식 위에서 단계가 돈다 | S14 · S37 | 없음 | 없음 |
| E1 | 세션 담당자와 위아래 소통 | 묶음 | 계획부터의 담당자를 세션으로 띄우고 거두며 지휘자 – 담당자 – 하위 사이 소통 창구를 하나로 정한다 | 한다: 담당자를 세션으로 띄우기(herdr 권장 · 없으면 하위 agent), 결과 파일을 쓰고 닫기 · 띄운 세션 거두기 확인, 위아래 소통 계약(창구 하나 · 받았음과 답했음 · 글이 왔음을 아는 길 · 보낸 쪽 확인 — 양식으로 모델을 묶지 않는다), 도는 담당자에게 닿는 답 · 방향 고침, 사용자가 담당자에게 직접 한 말을 과제 파일로, 담당자끼리는 지휘자가 푼다, 새 형식을 기본으로 · 마지막 보고를 결과 파일로, 모델 고르기 지침, 스크립트 · 다른 모델 한곳으로 / 안 한다: 다른 서버에서 띄우기, 로드맵 사이 소통, 단계와 교대 사이 | R1, R2 | feature/session-workers | plugins/spec-distill/references/conductor-dispatch.md, plugins/spec-distill/references/team-files.md, plugins/spec-distill/scripts/start_bundle.py, plugins/spec-distill/scripts/team_write.py, plugins/spec-distill/scripts/job_results.py, plugins/spec-distill/scripts/conductor_ledger.py, plugins/spec-distill/templates/team/, docs/superpowers/roadmaps/leader/, docs/superpowers/roadmaps/worker/ | C4 · C5 · C38 · C42 · C50 · D9 · D33 · OQ3 · OQ41 · OQ48 · RC12 · RC13 · S4 · S41 · S50 · «anthropic-multiagent» · «cc-agent-teams» · «cc-cross-session» · «cc-subagents» · «herdr» | R1 의 과제 폴더 · 결과 파일, R2 의 단계표 · 관문 · 시작 묶음으로 보내는 글 틀 | 세션 담당자 보내기 · 거두기 절차, 위아래 소통 계약 | 큼 | R3 와 병렬 가능 | 관문이 선 뒤에 세션을 띄워야 설계 없이 개발하지 않는다 | S4 · 사용자 말 2026-11-17 · 2026-11-18 | 없음 | 없음 |
| E2 | 리더 덜기와 다시 띄우기 | 묶음 | 지휘 절차서를 걸음별 지시서로 쪼개 그 걸음에서만 읽고 손 일을 담당 세션으로 넘기며 리더 세션을 끊고 다시 띄울 수 있게 한다 | 한다: 걸음별 지시서 · 손 절차 분리, 머지 전 확인(스위트 대조 · 통합 리뷰 · PR 본문)을 담당 세션으로, 리더가 끊는 자리와 적고 나가는 것, 「지휘자」를 「리더」로 맞추는 낱말 / 안 한다: 상태 브랜치 | R2, E1 | feature/conductor-step-guides | plugins/spec-distill/references/conducting.md, plugins/spec-distill/references/conductor-dispatch.md, plugins/spec-distill/skills/epic-conductor/SKILL.md, plugins/spec-distill/scripts/conductor_ledger.py, docs/superpowers/roadmaps/leader/ | D16 · D19 · OQ8 · OQ11 · OQ14 · RC3 · RC4 · RC37 · K6 · S12 · S13 · S18 | R2 의 단계표, E1 의 세션 담당자 | 걸음별 지시서, 리더 이어받기 절차 | 중간 | R3 와 병렬 가능 | 걸음과 세션 담당자가 선 뒤에 리더의 일을 덜 수 있다 | S13 · S18 · 사용자 말 2026-11-18 | 없음 | 없음 |
| E3 | 다른 서버에서 띄우기 | 묶음 | 담당자 세션을 다른 서버에서 띄울 때의 위치 · 권한 · git 밖 파일을 정한다 | 한다: 등록된 서버에서 띄워 재 보기, 서버 계정 안 위치(되도록 같은 레포 위치), 서버 안 권한, git 에 없는 데이터 · env secret 을 부모 세션 기준 최신으로 모으기(값은 적지 않는다) / 안 한다: 로드맵 사이 편지함, 감시 · 표시 | E1 | feature/remote-session-spawn | plugins/spec-distill/references/conductor-dispatch.md, plugins/spec-distill/dependencies.md | C3 · C5 · «cc-cross-session» · «herdr» | E1 의 세션 담당자 보내기 절차 | 다른 서버 담당자 보내기 절차 | 중간 | R3 와 병렬 가능 | 이 기계에서 세션 담당자가 돈 뒤에 다른 서버로 넓힌다 | 사용자 말 2026-11-17 | 없음 | 없음 |
| R3 | 지휘자 상태 브랜치 · 편지함 | 묶음 | 기계를 넘는 지휘자 소통 자리를 세운다 | 한다: 지휘자 상태 브랜치(코드 없음 · main 에 머지 안 함), 편지함 한 글 한 파일, STATUS.md 계산 · 커밋, 지휘자끼리의 대화 계약(로드맵 사이), 브랜치 규칙 문서 예외 / 안 한다: 감시 · 표시 | R1 | feature/conductor-state-branch, feature/conductor-leader-seat | plugins/spec-distill/scripts/conductor_state.py, plugins/spec-distill/scripts/control_plane.py, plugins/spec-distill/scripts/state_path.py, docs/git-workflow/branch-strategy.md, plugins/project-init/hooks/post-tool-use.py, plugins/spec-distill/scripts/conductor_branch.py, plugins/spec-distill/scripts/conductor_status.py, plugins/spec-distill/scripts/conductor_mail.py, plugins/spec-distill/references/conductor-state-branch.md, plugins/spec-distill/references/conducting.md, plugins/spec-distill/scripts/repo_defaults.py, plugins/spec-distill/scripts/team_layout.py, plugins/spec-distill/scripts/start_bundle.py, plugins/spec-distill/scripts/team_status.py, plugins/spec-distill/scripts/team_write.py, plugins/spec-distill/scripts/team_files.py, plugins/spec-distill/scripts/conductor_ledger.py, plugins/spec-distill/scripts/workflow_superpowers.py, plugins/spec-distill/scripts/roadmap_status.py, plugins/spec-distill/references/team-files.md, plugins/project-init/.claude-plugin/plugin.json, plugins/project-init/CHANGELOG.md | C3 · C4 · C37 · C43 · C47 · D13 · D18 · D26 · D29 · OQ4 · OQ13 · OQ15 · OQ21 · OQ34 · OQ39 · OQ46 · RC8 · RC44 · K7 · S1 · S5 · S9 · S17 · S19 · S28 · S33 · S34 · S35 · S46 · «cc-cross-session» · «mcp-agent-mail» · «thrum» | R1 의 STATUS · INTENT 형식 | 상태 브랜치 쓰기 · 편지함 형식 · STATUS 계산기 | 중간 | R2 와 병렬 가능 | 감시 mod 가 이 편지함을 본다 | S35 · 조사 13 | 없음 | 없음 |
| R4 | 현황 · 감시 mod | 묶음 | mod 하나로 현황 · 토큰을 보이고 편지함을 감시한다 | 한다: 표시 전용 mod(권한 이벤트 미구독 · validate 락), 타이머 git fetch → 새 글이면 자기 세션 새 턴, kill switch, 최소 판 / 안 한다: 도구 승인 | R3, P1 | feature/conductor-status-mod | plugins/spec-distill/README.md, plugins/spec-distill/dependencies.md | C43 · D8 · D31 · OQ2 · OQ5 · OQ6 · OQ26 · OQ28 · OQ35 · OQ46 · RC10 · RC34 · K12 · S3 · S6 · S38 · S43 · S45 · S46 · «cc-mods» | R3 편지함 · STATUS, P1 측정 방식 | 현황 mod | 중간 | 없음 | 편지함과 측정 방식이 먼저 있어야 한다 | S38 · 조사 17 | 없음 | 없음 |
| R5 | 이전 · 재측정 | 묶음 | 기존 기록 · 도는 로드맵을 새 구조로 옮기고 옛 장치를 걷어낸 뒤 기준선과 다시 잰다 | 한다: 설계문서 지휘 기록 · 에픽 묶음 이전, 도는 로드맵 이전, 옛 장치 정리, 재측정 비교 / 안 한다: 새 기능 | R1, R2, R3, R4, E1, E2, E3 | feature/conductor-migration | docs/superpowers/specs/, docs/superpowers/roadmaps/, plugins/spec-distill/CHANGELOG.md | C1 · C49 · D20 · D21 · D34 · OQ10 · OQ27 · OQ29 · OQ47 · S20 · S30 | R1–R4 · E1–E3 결과 · P1 기준선 | 이전 완료 · 전후 비교 | 중간 | 없음 | 모든 새 장치가 선 뒤에 옮긴다 | S20 · S30 | 없음 | 없음 |

## audit §2 대기 줄

- 포화 판정 1: 아직 — 빈 곳 5개
- 포화 판정 2: 아직 — 빈 곳 7개
- 포화 판정 3: 아직 — 빈 곳 6개
- 포화 판정 4: 아직 — 빈 곳 4개
- 사용자 종료(@S42) — 마지막 판정 아직

## 생성 기록

- docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/P1.md
- docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R1.md
- docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R2.md
- docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R3.md
- docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R4.md
- docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R5.md
- docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md
