---
type: interview-state
seed: docs/superpowers/interview/2026-11-14-framing-interview-constraint-audit-interview.md
session_id: ee276545-0999-4e89-aeab-9cec39e6c504
phase: 1
coverage:
  floor:
    root_problem:   {status: closed, evidence: "S1 「이 일의 목적은 request-framing 과 인터뷰가 새 코어와 맞지 않는 부분을 개선하고 강화하고 낡은 부분을 고치는 것이다. (사용자 확인)」 · S4 「새 코어에 맞추기 (권장)」", reopened: 0, reopen_log: []}
    landscape:      {status: closed, evidence: "S6 「공식 쪽으로 옮길 후보로 본다」 — 공식 문서 대조(조사 3 · 5)의 처분", reopened: 0, reopen_log: []}
    skepticism:     {status: closed, evidence: "ST1 S11 「공식을 따라가 」 · ST2 S12 「공식대로 가고 기존 판올림도 다시 다 검토해봐 」 · ST3 S13 「유지」 — steelman 판정 셋", reopened: 0, reopen_log: []}
    blind_spot:     {status: closed, evidence: "S19 「원자료의 비밀값 (권장), 질문 · 선택지의 의역 (권장), 한 일에 너무 많이 실림」 — 숨은 가정 · 실패 양식(조사 10)의 처분", reopened: 0, reopen_log: []}
    open_questions: {status: closed, evidence: "S25 「이대로 싣는다 (권장)」 — 설계로 넘길 열린 질문 목록(OQ25–OQ35)의 확인 · S29 「이대로 싣는다 (권장)」 — 더해진 둘(OQ36 · OQ37)의 확인 · S30 「포화로 보고 종료 (권장)」 — 새로 열린 결정(OQ38)을 열린 질문에 더하는 것의 확인", reopened: 1, reopen_log: ["R11 — 확인 범위(OQ25–OQ35) 밖에서 열린 결정 OQ36 · OQ37 이 더해졌다"]}
  derived:
    - {name: internal_research, rationale: "조사 1 · 2 가 repo_claims 를 냈다 — 레포 주장의 처분 S 로 닫는다", status: closed, evidence: "S24 「그대로 싣고 미확인은 표시 (권장)」 — 레포 주장 156건의 처분", reopened: 0, reopen_log: []}
    - {name: 원자료_정본_사슬, rationale: "S1 이 seed 전문이고 brief 리뷰 정답이 그 §6 이라 원자료 파일을 정본으로 올리면 seed 문법 · 출처 분류기 · 리뷰 프로필 · 묶음 생성기가 한 사슬로 바뀐다 (조사 1)", status: closed, evidence: "S5 「사본이 없다 (권장), 원자료는 글자 그대로 (권장), 로드맵 없는 일도 같은 자리, 3 시작이 framing일수도 있고 아닐수도 있긴함 」", reopened: 0, reopen_log: []}
    - {name: 역할과_이름, rationale: "이름 바꾸기의 대상(어느 단계가 의도 싱크인가)과 파급 — 호출 이름 · 설정 키 · 머리 키 · 접미사 · 옛 기록 · 진입 표면 락 (조사 1 · 2, 옆 세션이 전한 사용자 말)", status: closed, evidence: "S2 · S8 · S17 「컨텍스트 쌓기 (권장)」", reopened: 0, reopen_log: []}
    - {name: 옆_로드맵_경계와_순서, rationale: "예약 파일 겹침 · 머지 순서 · 승인 전 설계문서가 잣대라는 것 · 그 문서가 이 일 몫으로 적은 것 (조사 1 의 제안 둘을 합침 · 조사 2)", status: closed, evidence: "S3 · S16 「그대로 이 일이 맡는다 (권장)」", reopened: 0, reopen_log: []}
    - {name: 게이트와_락, rationale: "작은 일의 가벼운 길은 구조 게이트 통과 조건을 바꾸고, 앞단 글 줄이기는 글자를 단언하는 테스트에 닿는다 (조사 1 의 제안 둘을 합침)", status: closed, evidence: "S20 「사람에게 보이고 통과 (권장)」", reopened: 0, reopen_log: []}
    - {name: 표준_대조_범위, rationale: "공식 자료는 참고 — 저술 가이드 · 철학 문서에서 의도한 차이와 낡음을 가른다 (조사 1)", status: closed, evidence: "S6 · S9 · S10 · S11 · S12 · S13 · S14 · S15 · S18 「판은 두고 올림 단위를 푼다 (권장)」", reopened: 0, reopen_log: []}
    - {name: 승인_화면, rationale: "사용자가 직접 개선을 요구한 seed 리뷰의 덩어리 처분 화면 (조사 1)", status: closed, evidence: "S21 「문단 전체가 두 번 나온다 (권장), 어느 지적 때문인지 안 보인다 (권장), 덩어리마다 질문이 따로다, 추천이 없다」", reopened: 0, reopen_log: []}
orchestration:
  focused_dimension: open_questions
  research_dispatches: {coverage_mapper: 1, blind_spot_prober: 1, steelman_builder: 3, repo_researcher: 6, open_researcher: 2}
  research_limit: 60
  saturation_limit: 5
  research_log:
    - {n: 1, device: coverage-mapper, round: 1, batch: 1, changed: [], opened: [OQ2], summary: "파생 차원 여덟 제안(일곱으로 admit) · seed 다시 검증할 것 대조 — 틀린 것 하나 · 반만 맞는 것 하나 · seed 에 없는 겹침 둘"}
    - {n: 2, device: repo-researcher, round: 1, batch: 1, changed: [], opened: [OQ2], summary: "옆 로드맵 · 묶음 · 설계문서 지금 판 전문 — 앞단에 닿는 결정 · 미룸 · 예약과 문서 사이 어긋남 다섯"}
    - {n: 4, device: orchestrator, round: 1, batch: 2, changed: [], opened: [], summary: "열린 PR #274 의 파일 목록 직접 확인"}
    - {n: 3, device: open-researcher, round: 1, batch: 1, changed: [], opened: [OQ6], summary: "Claude Code 공식 문서와 저술 가이드 · CLAUDE.md 대조 — 같은 자리 · 다른 자리 · devbrew 고유 자리 (R2 에 실음)"}
    - {n: 5, device: orchestrator, round: 2, batch: 3, changed: [], opened: [], summary: "조사 1 · 3 의 웹 주장 가운데 결정에 닿는 것을 공식 페이지 다섯에서 원문으로 재확인"}
    - {n: 6, device: orchestrator, round: 3, batch: 4, changed: [], opened: [], summary: "항목별로 물을 공식 문서 사실 여섯을 공식 페이지 여섯에서 원문으로 재확인"}
    - {n: 7, device: steelman-builder, round: 3, batch: 5, changed: [OQ10], opened: [], summary: "ST1 model 키 허용 — 양쪽 논거 · P6 충돌 · 추천 보완"}
    - {n: 8, device: steelman-builder, round: 3, batch: 5, changed: [OQ11], opened: [], summary: "ST2 plugin.json 필수 · 판 올림 완화 — 양쪽 논거 · P6 충돌 · 추천 보완"}
    - {n: 9, device: steelman-builder, round: 3, batch: 5, changed: [OQ12], opened: [], summary: "ST3 kill switch · 상태 자리 — 양쪽 논거 · P6 충돌 · 추천 보완"}
    - {n: 11, device: orchestrator, round: 4, batch: 6, changed: [], opened: [], summary: "게이트 셋의 부착 주장을 공식 페이지와 이 기계의 플러그인 캐시에서 원문으로 재확인"}
    - {n: 10, device: blind-spot-prober, round: 3, batch: 5, changed: [OQ16, OQ17], opened: [OQ16, OQ17, OQ18], summary: "숨은 가정 아홉 · 실패 양식 여덟 — S3 의 근거 문장이 바뀜 · 이름 낱말이 선택지에서 나옴 · 원자료와 비밀값"}
    - {n: 12, device: repo-researcher, round: 7, batch: 7, changed: [OQ13], opened: [], summary: "판 올림 재검토 — 판 헤딩 460개 종류별 수 · 판을 읽는 자리 · CLAUDE.md 에 없는 올림 관행 둘 · 사고와 우회 기록"}
    - {n: 13, device: orchestrator, round: 8, batch: 8, changed: [], opened: [], summary: "런타임 상태 자리 목록 직접 확인(사용자 요청 보고)"}
    - {n: 14, device: orchestrator, round: 9, batch: 9, changed: [], opened: [OQ36], summary: "빈 곳 셋 직접 확인 — 설치 방식은 캐시 사본 · 링크로 배송되는 정본 43개 · 공식 데이터 폴더 쓰기 실측"}
    - {n: 15, device: repo-researcher, round: 9, batch: 10, changed: [OQ32], opened: [], summary: "상태 폴더 하나하나의 내용 · 쓰는 스크립트 · 수명 · 다시 만들 수 있는지 · 레포 안이어야 하는 이유"}
    - {n: 16, device: orchestrator, round: 10, batch: 11, changed: [], opened: [], summary: "이 세션의 샌드박스 설정 · 끄기 명령의 실재와 옵션 · 두 PR 과 옆 설계문서의 지금 상태"}
    - {n: 17, device: repo-researcher, round: 10, batch: 12, changed: [OQ32], opened: [], summary: "스위치 전수 — 변수 · 토큰 · 읽는 자리 · 끄는 것 · 공시 자리"}
    - {n: 18, device: repo-researcher, round: 10, batch: 12, changed: [OQ36], opened: [], summary: "공유 파일의 배송 꼴(링크 · 글자 사본 · 실리지 않음)과 사본 일치 락 · 판 올림 기록"}
    - {n: 19, device: repo-researcher, round: 10, batch: 12, changed: [OQ28, OQ31, OQ27], opened: [], summary: "옆 설계문서의 지금 판 — 단순 작업 자리 · 의도 폴더 · 미룸 표 · 고칠 파일 · 열린 것, 로드맵의 경로 예약"}
    - {n: 20, device: open-researcher, round: 10, batch: 12, changed: [OQ32], opened: [OQ37], summary: "공식 문서 — 플러그인 경로 변수 · 샌드박스 · 플러그인 끄기 · 훅 일괄 끄기 · 설정 값 받기"}
  saturation_log:
    - {k: 1, round: 9, verdict: not_saturated, basis: "최근 두 묶음(조사 12 · 조사 13)이 둘 다 결정을 바꿨다(OQ13 · OQ32)", gaps: ["설치 방식(제자리 · 캐시 사본) — OQ13 · orchestrator", "링크 배송분과 설치본 밖 공유 파일의 올림 — OQ13 · repo-researcher", "상태 폴더를 쓰는 스크립트와 수명 · 작업 사본의 자리 — OQ32 · OQ15 · OQ24 · repo-researcher", "스크립트가 공식 데이터 폴더에 실제로 쓸 수 있는가(실측) — OQ12 · OQ15 · OQ32 · orchestrator"], user_choice: null}
    - {k: 2, round: 10, verdict: not_saturated, basis: "최근 두 묶음(조사 14 · 조사 15)이 둘 다 결정을 바꿨다(OQ13 · OQ32 · OQ36 / OQ32 · OQ28)", gaps: ["샌드박스를 켠 세션에서 공식 데이터 폴더 쓰기와 그 경로를 얻는 길 — OQ32 · orchestrator", "스위치 전수(변수 · 토큰 · 읽는 자리) — OQ32 · repo-researcher", "공식 스위치의 실제 동작(끄기 명령 · 설정 키 · 훅 일괄 끄기) — OQ32 · orchestrator", "shared 정본의 사본으로 실리는 파일과 사본 일치 락 — OQ36 · repo-researcher", "옆 설계문서의 지금 판과 두 PR 의 상태 — OQ28 · OQ31 · OQ27 · repo-researcher"], user_choice: null}
    - {k: 3, round: 11, verdict: not_saturated, basis: "최근 두 묶음(조사 16 · 조사 17–20)이 열린 결정을 바꾸고 새 결정을 열었다(OQ31 · OQ32 / OQ32 · OQ36 · OQ26 · OQ27 · OQ28 · OQ31)", gaps: ["샌드박스를 켠 세션의 실측(보호 경로 · 쓰기 · 쓰기 허용 · 사전 실행 줄) — OQ37 · OQ32 · orchestrator", "치환 실측(펜스 · 사전 실행 줄 · 보조 파일 안의 데이터 폴더 변수와 설정 값) — OQ32 · OQ37 · orchestrator", "플러그인 끄기 뒤의 동작 실측 — OQ32 · orchestrator", "링크 · 글자 사본의 파일 단위 표 — OQ36 · OQ32 · orchestrator", "승인된 옆 설계문서의 뒤처리(로드맵 수정 PR · 대조표 · PR #274 의 고친 구간 · 열린 지적 다섯) — OQ31 · OQ26 · orchestrator", "값 변수 열넷과 레포에 있는 설정 길의 겹침 — OQ32 · OQ35 · repo-researcher", "상태를 공식 데이터 폴더로 옮기는 방향의 실패 양식 다시 뽑기 — OQ32 · OQ37 · blind-spot-prober", "공식 장치별 판 조건과 변경 기록 구간 — OQ32 · OQ37 · open-researcher"], user_choice: S30}
  open_decisions:
    - {id: OQ1, text: "옆 세션이 전한 역할 말씀에 따라 이름 바꾸기를 어떻게 고칠까", dimension: 역할과_이름, status: resolved, resolved_by: S2}
    - {id: OQ2, text: "앞단이 의도 폴더에 바로 쓰게 하는 일을 이 일이 맡을까", dimension: 옆_로드맵_경계와_순서, status: resolved, resolved_by: S3}
    - {id: OQ3, text: "이 일의 중심은 새 코어에 맞추기인가 원문 보존인가", dimension: root_problem, status: resolved, resolved_by: S4}
    - {id: OQ4, text: "인터뷰의 새 이름을 무엇으로 할까", dimension: 역할과_이름, status: resolved, resolved_by: S8}
    - {id: OQ5, text: "의도 폴더에 바로 쓰기를 맡았을 때 이 일이 끝나면 꼭 참이어야 하는 것은 무엇인가", dimension: 원자료_정본_사슬, status: resolved, resolved_by: S5}
    - {id: OQ6, text: "공식 문서와 다른 자리를 저술 가이드에서 어떻게 다룰까", dimension: 표준_대조_범위, status: resolved, resolved_by: S6}
    - {id: OQ7, text: "공식과 다른 자리 가운데 어느 것을 공식 쪽으로 옮길까 (1/2 — cost_class · integrity · disallowed-tools · 의존 선언)", dimension: 표준_대조_범위, status: resolved, resolved_by: S9}
    - {id: OQ8, text: "인터뷰를 맥락 쌓기와 로드맵 잡기 두 단계로 나눌까", dimension: 역할과_이름, status: resolved, resolved_by: S8}
    - {id: OQ9, text: "공식과 다른 자리 가운데 어느 것을 공식 쪽으로 옮길까 (2/2 — model 키 · plugin.json 필수와 판 올림 · kill switch 와 상태 자리)", dimension: 표준_대조_범위, status: resolved, resolved_by: S10}
    - {id: OQ10, text: "agent 의 model 키를 허용하는 방향을 유지할까 (의심 게이트 ST1)", dimension: skepticism, status: resolved, resolved_by: S11}
    - {id: OQ11, text: "plugin.json 필수 키와 판 올림을 완화하는 방향을 유지할까 (의심 게이트 ST2)", dimension: skepticism, status: resolved, resolved_by: S12}
    - {id: OQ12, text: "kill switch 와 상태 자리를 공식 장치로 옮기는 방향을 유지할까 (의심 게이트 ST3)", dimension: skepticism, status: resolved, resolved_by: S13}
    - {id: OQ13, text: "판 올림을 공식의 두 길(릴리스마다 올림 · version 비움) 가운데 어느 쪽으로 할까 — 기존 판 올림 재검토 뒤 정한다", dimension: 표준_대조_범위, status: resolved, resolved_by: S18}
    - {id: OQ14, text: "kill switch 를 공식으로 옮길 때 공식 설정이 닿지 않는 자리(진입 skill 끄기 · 기능 단위 스위치)를 어떻게 할까", dimension: 표준_대조_범위, status: resolved, resolved_by: S14}
    - {id: OQ15, text: "프로젝트 · 문서 · 로드맵 단위 상태를 공식 데이터 폴더로 옮길 때 무엇이 지켜져야 하나", dimension: 표준_대조_범위, status: resolved, resolved_by: S15}
    - {id: OQ16, text: "근거 문장이 바뀐 뒤에도 의도 폴더에 바로 쓰기를 이 일이 맡을까 (S3 재확인)", dimension: 옆_로드맵_경계와_순서, status: resolved, resolved_by: S16}
    - {id: OQ17, text: "인터뷰 앞 단계의 이름은 「컨텍스트 쌓기」인가 「맥락 쌓기」인가", dimension: 역할과_이름, status: resolved, resolved_by: S17}
    - {id: OQ18, text: "숨은 가정 · 실패 양식 가운데 이 일이 반드시 다뤄야 할 것은 무엇인가", dimension: blind_spot, status: resolved, resolved_by: S19}
    - {id: OQ19, text: "작은 일에서 필수 조사 · 리뷰를 건너뛰는 것을 구조 게이트가 어떻게 받을까", dimension: 게이트와_락, status: resolved, resolved_by: S20}
    - {id: OQ20, text: "덩어리 승인 화면에서 무엇이 보기 어려웠나", dimension: 승인_화면, status: resolved, resolved_by: S21}
    - {id: OQ21, text: "이 일이 철학 문서를 어디까지 고칠까 — 옆 로드맵의 지휘 절차 에픽과 어떻게 나눌까", dimension: 옆_로드맵_경계와_순서, status: resolved, resolved_by: S23}
    - {id: OQ22, text: "레포 조사에서 확인한 사실을 결과물의 근거로 어떻게 실을까", dimension: internal_research, status: resolved, resolved_by: S24}
    - {id: OQ23, text: "설계로 넘길 열린 질문 목록이 맞는가", dimension: open_questions, status: resolved, resolved_by: S25}
    - {id: OQ24, text: "「나머지는 다 공식대로」 가 기록 성격의 둘(문서 리뷰 원장 · 감사 실행 폴더)까지 포함하는가", dimension: 표준_대조_범위, status: resolved, resolved_by: S26}
    - {id: OQ25, text: "두 단계(컨텍스트 쌓기 · 로드맵 잡기)의 호출 이름과 「의도 싱크」의 호출 이름, 인터뷰를 나누는 자리", dimension: 역할과_이름, status: open, resolved_by: null}
    - {id: OQ26, text: "이름이 박힌 나머지 층(설정 키 · 설계문서 머리 키 · 파일 이름 끝 · 산출물 종류 글자 · 폴더 이름)의 새 이름과 옛 기록을 읽는 길", dimension: 역할과_이름, status: open, resolved_by: null}
    - {id: OQ27, text: "원자료 파일이 정본이 되면 seed 가 맡을 일과 seed 문법", dimension: 원자료_정본_사슬, status: open, resolved_by: null}
    - {id: OQ28, text: "로드맵이 없는 일 · framing 없이 시작한 일에서 원자료와 결과물을 둘 자리", dimension: 원자료_정본_사슬, status: open, resolved_by: null}
    - {id: OQ29, text: "원자료를 글자 그대로 두면서 비밀값을 가리는 길", dimension: 원자료_정본_사슬, status: open, resolved_by: null}
    - {id: OQ30, text: "고른 선택지 문장과 사용자가 직접 쓴 말을 갈라 기록하는 길", dimension: 원자료_정본_사슬, status: open, resolved_by: null}
    - {id: OQ31, text: "옆 로드맵과의 머지 순서 — 끝맺음 절차 파일 · CLAUDE.md · 변경 기록 · 설정 키 파일 · 상태 자리 파일", dimension: 옆_로드맵_경계와_순서, status: open, resolved_by: null}
    - {id: OQ32, text: "스위치마다의 공식 대응물과 대응물이 없어 남길 것 · 상태 파일마다 공식 데이터 폴더로 갈 것과 꼭 둬야 해서 docs 아래로 갈 것", dimension: 표준_대조_범위, status: open, resolved_by: null}
    - {id: OQ33, text: "model 키를 든 agent 가 생길 때 품질 게이트의 「리뷰어 모델」 알림 줄", dimension: 표준_대조_범위, status: open, resolved_by: null}
    - {id: OQ34, text: "덩어리 승인 화면의 추천 표시와 지금 규칙(저자가 승인 여부를 가르지 않는다)의 긴장", dimension: 승인_화면, status: open, resolved_by: null}
    - {id: OQ35, text: "Phase 0 조사에서 나왔으나 묻지 않은 여섯 — 확인 표시가 사용자 원문 문장에 안 붙는 것 · 넘김 글의 「사용자 선호」 라벨 · 라운드 꼴 고정 · 의심 게이트의 추천 봉쇄 · 조사 호출 상한 60 · 쉬운 말 규칙이 사용자 이름에 예외를 두지 않는 것", dimension: open_questions, status: open, resolved_by: null}
    - {id: OQ36, text: "올림 단위의 정의 — 링크로 배송되는 공유 정본이 바뀌면 올리고, 설치본에 실리지 않는 공유 파일의 함께 올림은 그만두는가", dimension: 표준_대조_범위, status: open, resolved_by: null}
    - {id: OQ37, text: "샌드박스를 켠 세션에서 Bash 로 도는 스크립트가 공식 데이터 폴더에 쓰지 못할 때의 길 — 누가 언제 재고, 막히면 어디에 쓰는가", dimension: 표준_대조_범위, status: open, resolved_by: null}
    - {id: OQ38, text: "공식 장치(설정 값 받기 등)로 옮기면 Claude Code 의존을 「기록」 에서 최소 판 강제로 바꾸는가", dimension: 표준_대조_범위, status: open, resolved_by: null}
    - {id: OQ39, text: "[참고 · overdesign] altitude: 앞단 두 단계를 새 코어에 맞추는 일에, 네 플러그인 전체의 kill switch · 상태 자리 · 판 올림 규칙을 공식 장치로 옮기는 레포 전역 이전이 같은 로드맵으로 실려 있다. (리뷰 8199b8ed#r1.1)", dimension: 표준_대조_범위, status: resolved, resolved_by: S38}
trivia_escape_armed: false
user_statements:
  - id: S2
    source: chosen
    round: 1
    text: "framing 이 의도 싱크, 인터뷰는 새 이름 (권장) — request-framing 을 「의도 싱크」로 바꾸고, 인터뷰는 맥락 쌓기 · 로드맵 잡기에 맞는 새 이름을 이 인터뷰에서 따로 정한다. 호출 이름 둘이 다 바뀐다."
  - id: S3
    source: chosen
    round: 1
    text: "이 일이 맡는다 (권장) — 앞단이 원자료 파일과 결과물을 처음부터 그 폴더에 쓴다. 옆 로드맵은 사본을 만들지 않게 되고 옮길 때 확인만 한다. 이 일의 범위가 커진다."
  - id: S4
    source: chosen
    round: 1
    text: "새 코어에 맞추기 (권장) — 원문 보존은 그 안의 한 갈래다. 넘기는 곳 · 글 줄이기 · 가벼운 길 · 이름이 같은 무게로 간다."
  - id: S5
    source: verbatim
    round: 2
    text: "사본이 없다 (권장), 원자료는 글자 그대로 (권장), 로드맵 없는 일도 같은 자리, 3 시작이 framing일수도 있고 아닐수도 있긴함 "
  - id: S6
    source: chosen
    round: 2
    text: "공식 쪽으로 옮길 후보로 본다 — 다른 자리를 항목마다 다시 여쭤 공식 쪽으로 옮길지 정한다. 이 일이 CLAUDE.md 규칙 개정으로 넓어진다."
  - id: S7
    source: verbatim
    round: 2
    text: "파이프라인으로서 둘로 나눠도 되고 "
  - id: S8
    source: chosen
    round: 3
    text: "둘로 나누는 방향 (권장) — 인터뷰를 「맥락 쌓기」와 「로드맵 잡기」 두 단계로 나누고 이름도 그 둘로 한다. 나누는 자리와 호출 이름은 설계에서 정한다."
  - id: S9
    source: chosen
    round: 3
    text: "cost_class 를 metadata 아래로 (권장), integrity 규칙 걷어내기 (권장), disallowed-tools 반영 (권장)"
  - id: S10
    source: chosen
    round: 3
    text: "plugin.json 필수 · 판 올림 완화, agent 의 model 키 허용, kill switch · 상태 자리를 공식으로"
  - id: S11
    source: verbatim
    round: 4
    text: "공식을 따라가 "
  - id: S12
    source: verbatim
    round: 5
    text: "공식대로 가고 기존 판올림도 다시 다 검토해봐 "
  - id: S13
    source: chosen
    round: 6
    text: "유지 — 고르신 대로 환경변수 kill switch 를 없애고 공식 설정만 쓰며, 상태를 공식 데이터 폴더로 옮긴다. 진입 skill 끄기와 기능 단위 스위치가 사라진다."
  - id: S14
    source: chosen
    round: 7
    text: "다른 공식 장치로 대체 (권장) — 진입 skill 끄기는 공식 플러그인 끄기나 skill 거부 규칙으로, 기능 단위 스위치는 공식 플러그인 사용자 옵션으로 옮긴다. 공식 대응물이 없는 것만 환경변수로 남긴다."
  - id: S15
    source: verbatim
    round: 7
    text: "프로젝트마다 갈린다 (권장), 캐시만 옮긴다, 뭐가 옮겨질지 나에게 보고해줘 기존 이후 어떻게 될지"
  - id: S16
    source: chosen
    round: 7
    text: "그대로 이 일이 맡는다 (권장) — 앞 답을 유지한다. 이 일이 먼저 하고 옆 로드맵의 이전 에픽은 확인만 한다. 누가 먼저인지는 옆 세션에 알려 맞춘다."
  - id: S17
    source: chosen
    round: 7
    text: "컨텍스트 쌓기 (권장) — 말씀하신 글자 그대로 쓴다."
  - id: S18
    source: chosen
    round: 8
    text: "판은 두고 올림 단위를 푼다 (권장) — 공식의 「릴리스마다 올림」 길. 판 번호는 남기고, 「모든 PR 마다」와 함께 올리는 관행을 없애 설치본 동작이 바뀔 때만 올린다. 판을 읽는 코드는 그대로 돈다."
  - id: S19
    source: chosen
    round: 8
    text: "원자료의 비밀값 (권장), 질문 · 선택지의 의역 (권장), 한 일에 너무 많이 실림"
  - id: S20
    source: chosen
    round: 8
    text: "사람에게 보이고 통과 (권장) — 검사가 「모델 판단으로 건너뜀 — 이유」를 따로 받아 통과시키고, 끝의 승인 화면 앞에서 무엇을 왜 건너뛰었는지 사용자에게 보인다."
  - id: S21
    source: chosen
    round: 8
    text: "문단 전체가 두 번 나온다 (권장), 어느 지적 때문인지 안 보인다 (권장), 덩어리마다 질문이 따로다, 추천이 없다"
  - id: S22
    source: verbatim
    round: 9
    text: ".claude/<플러그인>/worktrees/ 이거보다는 그냥 워크트리를 쓰는게 좋을거 같고 나머지는 다 공식대로 옮기면 되겠는데?"
  - id: S23
    source: chosen
    round: 9
    text: "P8 은 옆에 두고 그 밖만 (권장) — 옆 로드맵이 고치는 원칙 P8 문장은 그쪽에 두고, 이 일은 그 밖의 공식과 다른 자리 · 낡은 서술 · 앞단에 닿는 문장만 고친다."
  - id: S24
    source: chosen
    round: 9
    text: "그대로 싣고 미확인은 표시 (권장) — 확인한 것은 근거로 싣고, 미확인 셋과 일부만 본 것은 그렇다고 표시해 싣는다. 설계가 필요하면 다시 연다."
  - id: S25
    source: chosen
    round: 9
    text: "이대로 싣는다 (권장) — 목록 열하나를 열린 질문으로 싣는다. 다음은 조사가 충분한지 판정한 뒤 이 일을 하나로 할지 나눌지를 여쭙는다."
  - id: S26
    source: verbatim
    round: 9
    text: "2, 둬야할 위치를 docs아래로 바꾼다 꼭 둬야하는 경우에만 "
  - id: S27
    source: chosen
    round: 11
    text: "방향 유지, 설계가 먼저 잰다 (권장) — 옮기는 방향은 그대로 둔다. 설계 첫 걸음에서 샌드박스를 켠 세션으로 재고, 막히면 설계가 대체 길을 제안해 다시 여쭌다."
  - id: S28
    source: chosen
    round: 11
    text: "이 일이 맡는다 (권장) — 그 파일은 이 일만 고치고 옆 로드맵이 넘긴 둘도 이 일이 받는다. 이 일이 커지고, 그 둘은 옆 로드맵 첫 에픽이 머지된 뒤에만 할 수 있다. 옆 세션에 알린다."
  - id: S29
    source: chosen
    round: 11
    text: "이대로 싣는다 (권장) — 둘을 더한 목록을 열린 질문으로 싣는다. 올림 단위는 설계가 어긋난 기록을 보고 정한다."
  - id: S30
    source: chosen
    round: 12
    text: "포화로 보고 종료 (권장) — 조사를 여기서 닫고 결과물로 간다. 빈 곳 여덟은 「설계가 먼저 볼 것」으로 싣고, 새로 열린 결정(Claude Code 최소 판을 강제할지)은 열린 질문에 더한다."
  - id: S31
    source: verbatim
    round: 13
    text: "1, 그래 꺼져있는걸 알 수 있게 하자"
  - id: S32
    source: chosen
    round: 13
    text: "고친다 — 고른 항목만, 나머지는 묻기 (권장) — 「공식 자료는 참고」를 그대로 두고, 공식 쪽을 고른 것은 그 항목에 한한 선택이며 남은 자리는 항목마다 여쭌다고 적는다(리뷰 지적 a6484ced#r1.1)."
  - id: S33
    source: chosen
    round: 13
    text: "고친다 — 방향 유지, 실측 넓히기 (권장) — 옮기는 방향은 그대로 두고, 실측을 샌드박스 쓰기에서 작업 폴더 밖 읽기 · 쓰기 승인과 하위 agent 의 읽기까지 넓힌다. 막히면 다시 여쭌다(리뷰 지적 abf668a4#r1.1)."
  - id: S34
    source: chosen
    round: 14
    text: "고친다 — 이름만 필수, 경고를 규칙에 적기 (권장) — 규칙을 이름만 필수로 풀고 감사 검사를 함께 고친다. 판 번호 · 소개 문구 · 저자를 빼면 공식 검증 명령이 경고를 낸다는 것을 규칙에 적는다(리뷰 지적 abf668a4#r2.1)."
  - id: S35
    source: chosen
    round: 15
    text: "열지 않음 (권장) — 열린 지적 7개를 두고 진행 — 고친 일곱은 결과물에 들어가 있고, 리뷰어의 재확인 없이 끝맺음(읽어 보기 · 확정 후보 · 다음 단계 질문)으로 간다."
  - id: S36
    source: chosen
    round: 15
    text: "지금대로 둔다 (권장) — 결과물은 71건을 싣고 나머지는 기록 파일을 가리킨다. 고르신 방식과 달라진 것을 사용자가 받아들였다고 결과물에 적는다."
  - id: S37
    source: chosen
    round: 15
    text: "(가)만 받는다 (권장) — 커밋 범위 행은 에픽 「앞단의 끝」 이 받는다. PR #274 잔여 셋은 받지 않고, 그 PR 쪽에서 고칠 일로 옆 세션에 알린다."
  - id: S38
    source: chosen
    round: 16
    text: "한 로드맵에 둔다 (권장) — 승인하신 에픽 여덟 그대로 간다. 이 지적은 사용자가 보고 그대로 두기로 했다고 결과물에 적는다."
  - id: S39
    source: chosen
    round: 16
    text: "이 일이 받는다 (권장) — 에픽 「앞단의 끝」 범위에 잔여 셋이 더해진다. 끝맺음 절차 파일은 계속 이 일만 고친다."
  - id: S40
    source: chosen
    round: 16
    text: "승인 (권장) — 위에 적은 변경과 두 답에 따른 변경을 반영해 로드맵을 다시 만든다. 에픽의 수 · 의존 · 브랜치는 그대로다(첫 질문에서 「뺀다」를 고르면 새 분해안을 따로 보여 드린다)."
confirm_repost_count: 0
brief_review_degradations:
  - component: readback
    reason: 냉독 전용 agent(brief-readback)는 도구가 없어 경로로 준 문서를 읽지 못했다 — 본문을 인라인하지 않고, 같은 지시문으로 읽기 도구가 있는 일반 agent 에게 그 파일 하나만 읽혀 대신 쟀다
    affected_axis: readback
    verification_status: degraded
---

## 풀린 입력

~~~~
---
type: interview-seed
next_phase: spec-distill:pm-interview
audit_file: 2026-11-14-framing-interview-constraint-audit-interview.audit.md
---

이 일의 목적은 request-framing 과 인터뷰가 새 코어와 맞지 않는 부분을 개선하고 강화하고 낡은 부분을 고치는 것이다. (사용자 확인) 새 코어는 지휘 재설계 로드맵이 세우는 팀 구조다. (사용자 확인) 사용자는 이 일이 치우침 정리가 아니라고 했고, 옆 세션을 잘 이해해야 한다고 했다. 옆 세션은 그 로드맵을 이끄는 리더 세션이다.

사용자는 옆 세션의 이름 바꾸기 대화에서 「내 의도가 interview지나면서 의역된거 같아서 그래」 라고 했다. 이 말은 옆 세션이 넘긴 글에 옮겨져 있다. 옆 세션의 원자료 대조표는 사용자가 프레이밍에서 준 글이 seed 의 산문, 인터뷰 결과물의 번호 항목, 에픽 묶음으로 가며 줄고 바뀌었다고 적는다. 이것이 이 일의 계기인지는 Phase 0 의 읽기이고 사용자에게 묻지 않았다. 옆 세션의 팀 파일 규약 설계는 내용마다 집을 하나로 정하고 나머지는 경로로 가리키게 했다. 사용자 원자료의 집은 로드맵 폴더 아래 `intent/original.md` 한 파일이고, 과제 파일과 설계문서는 그 파일의 줄 범위로 가리킨다. 지금은 그 파일을 앞단의 기록에서 옮겨 적은 사본으로 만든다.

사용자가 방향으로 고른 것은 넷이다. 붙여 넣은 글과 직접 쓴 말 같은 원자료를 파일로 그대로 두고, 사용자 원문 자리에는 seed 가 아니라 그 원자료가 가게 한다. (사용자 확인) 앞단의 끝은 작은 일도 리더로 넘기고, 넘김 글은 짧게 쓰고 자세한 지시는 파일 경로로 둔다. (사용자 확인) 앞단 skill 글에서 이유와 이력 설명, 낡은 서술, 옛 설계 번호를 걷어내 읽는 양을 줄인다. (사용자 확인) 작은 일에서는 필수 조사와 리뷰 일부를 모델이 이유를 적고 건너뛸 수 있게 한다. (사용자 확인) 이 넷은 사용자가 먼저 말한 것이 아니라 Phase 0 이 조사에서 잡아 제안한 것을 사용자가 고른 것이다. 사용자는 자기가 말한 것 밖의 문제도 잡아내 제안해 달라고 했다. 사용자는 이 seed 를 리뷰하던 중 편집 덩어리 넷을 처분한 직후 「이거 덩어리 승인하는과정 내가 보기 어려우니까 개선하자」 라고 했다.

인터뷰를 의도 싱크로 바꾸는 이름 바꾸기는 이 일에 합친다. (사용자 확인) 그 이름은 사용자가 붙여 넣은 글의 「방향을 나에게 먼저 보여줌(의도 싱크)」 에서 왔고, 이름 바꾸기는 옆 세션이 자기 로드맵에 에픽으로 더하지 않고 이 일로 넘긴 것이다. 호출 이름을 바꾸는 일이라 레포 규칙대로면 별칭 없이 한 번에 바꾸고 major 판을 올린다.

표준에 맞게 가자는 말과 추가보다 푸는 쪽으로 가자는 말은 철학 문서를 두고 한 말이다. (사용자 확인) 사용자가 철학 문서에 대해 한 말은 「내가 말하는거는 우리 레포에 바이어스 되게 보다 표준에 맞게 가자는거였어」 와 「가능하면 추가보다는 푸는 쪽으로 가고」 다. 맞출 표준이 무엇이냐는 물음에 사용자는 선택지 셋 가운데 Claude Code 공식을 골랐고 「참고내용으로 두는거야」 라고 덧붙였으며, 외부 작업 방식 관례와 일반 개발 관례는 고르지 않았다. Claude Code 공식 자료는 따라야 할 기준이 아니라 참고 내용으로 둔다. (사용자 확인) 플러그인 저술 가이드는 표준에 맞추는 방향과 새 코어에 맞추는 방향을 함께 적용해 고치고, 낡은 내용도 확인해 고친다. (사용자 확인) 사용자의 첫 요청은 「Framing request, interview 필로소피 레포내 컨텍스트나 글이 경우 최근 우리 방식에 제약이 되지 않는지 조사부터」 였다.

같은 파일을 여럿이 건드린다. 인터뷰 끝맺음 절차 파일은 인터뷰 끝에서 PR 을 열고 머지를 묻게 하는 열린 PR 이 고치고 있고, 이것은 옆 세션이 넘긴 글에 있다. 옆 세션 설계문서의 미룸 표는 분해 승인 화면을 바꾸는 일을 지휘 절차 에픽 앞으로 적어 두었는데, 그 에픽의 경로 예약에는 이 파일이 없다. 앞단의 끝을 바꾸는 방향도 이 파일에 닿을 수 있다는 것은 Phase 0 의 읽기다. 철학 문서와 CLAUDE.md 는 옆 로드맵의 지휘 절차 에픽이 원칙 P8 을 고치려고 예약해 두었다. 이름 바꾸기가 닿는 설정 키 파일과 로드맵 스크립트, 넘김 글 파일은 옆 로드맵의 에픽들이 예약해 두었고, 그 목록은 옆 세션이 넘긴 글에 있다. 옆 세션은 새로 생기는 파일에는 처음부터 새 이름을 쓴다고 했다. 리더 사이 편지함은 아직 없어서 순서를 맞출 일은 세션 메시지나 사용자를 거친다. 새 코어를 지금 가장 자세히 적은 글은 옆 세션의 팀 파일 규약 설계문서인데, 그 문서는 아직 리뷰와 승인 전이고 그 세션의 로컬 브랜치에만 있으며 이 회의 도중에도 한 번 바뀌었다. 메시지로 받은 요약보다 문서를 다시 읽어야 한다. 새 코어는 그 로드맵 전체가 세우는 팀 구조라 다른 에픽의 묶음과 로드맵 파일도 함께 읽어야 한다.

Phase 0 이 조사에서 찾은 자리는 이 seed 의 기록 파일 긴 초안 절에 파일과 줄 번호째 있고, 직접 확인한 것과 조사 agent 보고만 받은 것을 갈라 적었다. 다시 조사하기 전에 그 절을 읽어라.

다시 검증할 것 — 새 코어와 앞단이 안 맞는 자리를 무엇으로 볼지는 Phase 0 의 대조이지 사용자가 하나씩 확정한 것이 아니다. 사용자가 고른 것은 방향 넷이고, 그 방향을 어느 파일의 어느 장치로 옮길지는 열려 있다. 인터뷰 결과물의 사용자 원문 첫 칸에 seed 전문이 들어간다는 것, seed 문법이 목록과 표를 받지 않는다는 것, 넘김 글 한 줄에 레포 원칙과 사용자가 하지 않은 사용자 선호 라벨이 들어 있다는 것, 저술 가이드가 예시로 든 agent 하나가 지금은 없다는 것은 Phase 0 이 파일을 열어 확인했다. 프레이밍 원문 243줄 가운데 147줄이 손실이나 뒤집힘이라는 수치는 옆 세션이 만든 원자료 대조표의 측정이고 Phase 0 이 다시 재지 않았다. 그 대조표는 아직 그 세션의 임시 폴더에만 있고 로드맵 폴더에 올릴 예정이라, 올라오기 전에는 경로로 가리키지 않는다. 이유와 이력 설명이 앞단 글의 얼마를 차지하는지, 옛 설계 번호가 몇 곳인지, 필수 조사를 건너뛸 칸이 없다는 것, superpowers 가 없으면 끝 게이트가 없다는 것, 인터뷰 결과물 리뷰 기준이 레포 원칙을 깎는 잣대로 쓴다는 것은 조사 agent 의 보고이고 Phase 0 이 다시 열어 보지 않았다. CLAUDE.md 가 없는 레포에서 seed 리뷰 번들 조립이 실패한다는 것은 코드 줄을 읽은 것이고 돌려 보지 않았다. 저술 가이드가 agent 의 model 키를 금지하는 근거는 두 달 전 실측이라 지금도 맞는지 모른다. 공식 자료와의 대조는 하지 않았다. 새 이름을 무엇으로 할지, 옛 기록을 옮길지, request-framing 이라는 이름까지 바꿀지는 정하지 않았다. 폴더 이름도 바꿀지는 사용자가 옆 세션에서 물은 것이고, 어느 폴더를 가리키는지는 넘겨받은 글만으로는 알 수 없다. 옆 세션 설계문서의 미룸 표는 앞단이 의도 폴더에 바로 쓰게 하는 일과 설계문서 머리 키의 이름을 이름 바꾸기 쪽과 그 로드맵의 이전 에픽 앞으로 함께 적어 두었다. 머리 키 이름은 사용자가 받은 이름 바꾸기에 들지만, 앞단이 그 폴더에 바로 쓰게 하는 일을 이 일이 맡을지는 묻지 않았다. 표준에 맞게 가자는 말과 공식 자료를 참고 내용으로 둔다는 말이 어떻게 함께 가는지는 묻지 않았다. 이 일이 철학 문서를 어디까지 고칠지는 묻지 않았다. 철학 문서와 CLAUDE.md 를 이 일과 옆 로드맵의 지휘 절차 에픽이 어떻게 나눌지도 정하지 않았다. 작은 일의 가벼운 길이 작은 일도 리더를 거친다는 새 코어의 결정과 어떻게 함께 가는지는 Phase 0 이 본 긴장이다. 원자료 파일이 정본이 되면 seed 가 무슨 일을 맡는지, seed 문법을 풀지는 열려 있다. 덩어리 승인 과정에서 무엇이 보기 어려웠는지와 이 일에서 어떻게 고칠지는 묻지 않았다.
~~~~

### 조사 1 — coverage-mapper · R1 · 묶음 1

~~~~
계약(`<claims_contract>`)은 받았다. `<open_decisions>` 가 비어 있어 모든 `decides` 는 빈 배열이고, 전제 목록도 받지 않아 `touches` 도 비었다. `id` 는 임시값이다.

```yaml
derived_dimensions:
  - name: "원자료 정본 사슬 (원자료 → seed → S1 → brief 리뷰 정답 → 묶음)"
    rationale: "S1 이 seed 전문이고 brief 리뷰의 정답이 그 §6 이라, 원자료 파일을 정본으로 올리면 seed 문법 · 출처 분류기 · 리뷰 프로필 둘 · 묶음 생성기가 한 사슬로 함께 바뀐다. 어느 고리를 이 일이 맡는지가 열려 있다 (RC1 · RC2 · RC3 · RC4 · RC20 · RC25)."
  - name: "이름 바꾸기의 파급과 이전 (호출 이름 · 설정 키 · 머리 키 · 접미사 · 옛 기록 · 락)"
    rationale: "머리 키 `source_interview` 는 상태 계산이 설계문서를 에픽에 잇는 글자 대조 키이고, 호출 이름은 진입 표면 락의 등록 목록과 옛 이름 금지 목록에 묶여 있다. 옛 설계문서 · 옛 seed 를 읽는 길까지 정해야 한다 (RC16 · RC17 · RC18 · RC27)."
  - name: "옆 로드맵과의 동시 편집 · 머지 순서"
    rationale: "R1 · R2 가 예약한 파일(`roadmap_status.py` · `repo_defaults.py` · `epic-handoff.md` · 철학 문서 · CLAUDE.md)이 이 일의 이름 바꾸기 · 넘김 글 · 철학 수정과 겹치고, `finishing.md` 는 어느 예약에도 없다 (RC23 · RC16 · RC17)."
  - name: "움직이는 상류 의존 (승인 전 설계문서가 잣대)"
    rationale: "옆 세션 설계문서는 seed 리뷰 뒤에도 또 바뀌었고(미룸 표 줄이 555행에서 649행으로), 지금은 `intent/` 에 바로 쓰기를 이 일이 정한다고 적는다. seed 는 그 일을 맡을지 묻지 않았다고 적는다 (RC25 · RC24)."
  - name: "게이트 완화의 경계 (작은 일의 가벼운 길 대 fail-closed 게이트)"
    rationale: "필수 조사 건너뛰기는 구조 게이트(`check_brief.py`)의 통과 조건을 바꾸는 일이고, 게이트 스스로 그 문구가 피검자가 쓰는 것이라 구별 못 한다고 적는다. 리뷰 프로필 완화는 CLAUDE.md 상 보안 리뷰 대상이다 (RC8 · RC9 · RC11 · RC5)."
  - name: "글과 락의 결합 (앞단 글 줄이기가 닿는 테스트)"
    rationale: "앞단 세 파일을 경로로 읽는 테스트가 57개 파일 210곳이고 일부는 문장 글자를 단언한다. 이유 · 이력 문장을 걷어내면 락이 깨지거나 발동 조건이 사라진다 (RC19 · RC5 · RC21 · RC22)."
  - name: "표준 대조의 범위 (공식 자료는 참고 — 의도한 차이와 낡음 가르기)"
    rationale: "공식 자료와 대조하면 저술 가이드의 낡음 후보가 셋으로 갈린다 — 공식과 레포 규칙 둘 다와 어긋남(`command-development`), 공식과는 같고 레포 실체와 어긋남(`scripts/` 설명), 레포가 일부러 더 엄격함(필수 필드). 어느 것을 고칠지는 「참고 내용」의 뜻에 달렸다 (RC14 · RC15 · RC26, evidence 1–4)."
  - name: "사용자가 보는 승인 화면 (seed 리뷰의 덩어리 처분)"
    rationale: "사용자가 직접 개선을 요구한 자리다. 지금 규칙은 덩어리마다 질문 하나 · 추천 없음 · 본문 줄임 없음 · 공시마다 번호 다시 매김이고, 그 넷은 저자가 승인 여부를 가르지 못하게 하려는 장치와 묶여 있다 (RC22)."
neglect_flag: true
neglected_dimensions:
  - "글과 락의 결합 — seed 는 줄일 글을 말하지만 그 글을 단언하는 테스트는 한 번도 언급하지 않는다"
  - "게이트 완화의 경계 — 유지 근거가 있는 장치 목록이 「상시 규칙」으로 seed 에서 덜어져 기록 파일에만 남았다"
  - "이름 바꾸기의 하류 소비자 — seed 는 예약 충돌만 적고, 머리 키가 상태 계산의 대조 키라는 것과 옛 설계문서를 읽는 길은 적지 않는다"
confidence: 0.6
evidence:
  - url: "https://code.claude.com/docs/en/sub-agents"
    supports: current
    claim: "하위 agent 모델은 호출 인자 → 정의의 `model`(`inherit` 포함) → `CLAUDE_CODE_SUBAGENT_MODEL` → 세션 모델 순으로 정해진다. 저술 가이드가 `model` 키를 금지하는 근거(리터럴 · `inherit` 가 사용자 환경 변수를 덮는다)는 지금 공식 문서와 맞는다. 새로 생긴 것 — `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` 이면 정의의 `model` 을 무시한다. 공식 문서의 하위 agent 머리 필드는 19개다(`omitClaudeMd` · `skills` · `isolation` 포함)."
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/skills"
    supports: current
    claim: "공식 권고는 「Keep SKILL.md under 500 lines. Move detailed reference material to separate files.」 다. 앞단 진입 skill 둘은 1373줄 · 600줄이다(RC20) — 앞단 글 줄이기 방향을 뒷받침한다."
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/skills"
    supports: current
    claim: "`allowed-tools` 는 사전 허용이지 제한이 아니고(「It does not restrict which tools are available」), custom command 는 skill 로 합쳐졌다. CLAUDE.md 의 두 규칙(`allowed-tools` 는 제한이 아니다 · 새 command 파일을 만들지 않는다)은 공식과 맞는다. skill 이름을 바꿀 때의 별칭 장치는 읽은 범위(앞 10만 자)에서 찾지 못했다."
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/plugins-reference"
    supports: both
    claim: "표준 배치 표는 commands 에 「Prefer `skills/` for new plugins」 라고 적는다 — 저술 가이드 45행의 `command-development` 는 공식과도 어긋난다. 반대로 공식 예시는 `scripts/` 를 「a `scripts/` folder that its hooks call」 로 적어 가이드 17행과 같다 — 그 줄의 낡음은 표준이 아니라 레포 실체 기준이다. `plugin.json` 은 공식에서 선택이고 필수 키는 `name` 하나다 — 가이드의 필수 셋은 레포가 일부러 더 엄격한 것이다. `version` 을 적으면 그 판에 고정된다는 것은 PR 마다 bump 규칙을 뒷받침한다."
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
repo_claims:
  - id: RC1
    path: "plugins/spec-distill/skills/pm-interview/references/seed-input.md"
    anchor: "**§6 `S1` 은 「풀린 입력」 원문 그대로다**(frontmatter 포함)"
    line: 9
    claim: "인터뷰 결과물의 사용자 원문 첫 칸은 seed 전문이다. 실례는 옆 로드맵 `R2.md` 113행 「S1 🗣 최초 요청(Phase 0 seed 전문)」. seed 가 「Phase 0 이 파일을 열어 확인했다」 고 적은 것과 맞다."
    touches: []
    decides: []
  - id: RC2
    path: "plugins/spec-distill/references/docreview-profiles/brief.md"
    anchor: "ground_truth: \"payload 의 `## 6. 사용자 원문` — 사용자 원문 S1~Sn 전량이다"
    line: 3
    claim: "brief 리뷰의 정답은 payload §6 이고 그 S1 이 seed 다(RC1). seed 단계의 풀어 쓰기가 brief 리뷰에서 원문으로 대접받는다 — 조사 agent 보고가 맞다."
    touches: []
    decides: []
  - id: RC3
    path: "plugins/spec-distill/references/docreview-profiles/seed.md"
    anchor: "layer1: [unfounded_addition, example_as_requirement, premature_closure, inference_as_decision, omission]"
    line: 9
    claim: "seed 프로필의 범주는 다섯이고 뜻이 바뀐 풀어 쓰기를 이름으로 잡는 범주가 없다(brief 프로필 층 2 에는 `distortion` 이 있다). `omission` 은 덜어 낸 것 표에 있으면 빠짐이 아니다(29행). 다만 이번 seed 리뷰는 첫 요청의 풀어 쓰기를 `premature_closure` 로 잡았다(기록 파일 c6) — 범주가 없다고 전혀 못 잡는 것은 아니다."
    touches: []
    decides: []
  - id: RC4
    path: "plugins/spec-distill/scripts/seed_body.py"
    anchor: "**받는 문법(허용 목록)을 적고, 그 밖은 전부 거부한다**"
    line: 5
    claim: "seed 본문은 산문 줄만 받는다 — 제목 · 인용 · 목록 · 표 · 펜스 · `[` `]` · URL 은 거부된다(16–24행). 붙여 넣은 표 · 트리는 seed 에 그대로 실을 수 없다. seed 의 확인과 맞다."
    touches: []
    decides: []
  - id: RC5
    path: "plugins/spec-distill/skills/pm-interview/references/finishing.md"
    anchor: "- **superpowers 부재 시**: 현행 graceful degradation 그대로"
    line: 444
    claim: "superpowers 가 없으면 brief 를 만들고 알린 뒤 멈춘다 — 「게이트 없음(다음 세션에 넘길 대상 자체가 없음)」. `tests/test_superpowers_presence.sh` 106–112행이 이 문장들의 글자를 단언한다. seed 는 이것을 조사 agent 보고로 분류했는데 기록 파일은 「직접, 그 줄만」 이다 — 이번에 열어 읽어 맞음을 확인했다."
    touches: []
    decides: []
  - id: RC6
    path: "plugins/spec-distill/skills/pm-interview/references/finishing.md"
    anchor: "**다음 세션 줄 — 분해된 일 ①/② 공통**"
    line: 666
    claim: "분해된 일만 `/spec-distill:epic-conductor <roadmap-path>` 로 간다. 하나짜리 brief 는 brainstorming 을 부르는 줄(551행)이나 둘째 질문에서 고른 skill 로 간다(534행). 옆 로드맵의 확정(RC24)과 어긋난다 — 조사 agent 보고가 맞다."
    touches: []
    decides: []
  - id: RC7
    path: "plugins/spec-distill/skills/pm-interview/references/finishing.md"
    anchor: "사용자 선호: 이 brief 의 설계는 설계문서를 쓰는 크기다"
    line: 551
    claim: "하나짜리 일의 다음 세션 줄은 한 줄짜리 긴 글이고, 「기본은 X, 일의 모양이 다르면…」 레포 원칙과 사용자가 말하지 않은 「사용자 선호」 라벨이 들어 있다. 같은 라벨이 `plugins/spec-distill/references/epic-handoff.md` 7행에도 있다(R1 예약 파일). seed 의 확인과 맞다."
    touches: []
    decides: []
  - id: RC8
    path: "plugins/spec-distill/scripts/check_brief.py"
    anchor: "budget_mapper_failures"
    line: 1559
    claim: "audit §2 의 `coverage-mapper 0` 은 `(unavailable: <이유>)` 가 붙을 때만 통과하고(advisory), 다른 사유는 「coverage-mapper 0 without unavailable reason」 으로 실패한다(1576행) — 모델이 이유를 적고 건너뛸 칸이 없다는 보고가 맞다. 포화 판정은 다르다 — `saturation_failures`(1585행)는 사용자 종료와 사용자 판단 포화를 통과시킨다. 「포화 판정을 건너뛸 칸이 없다」 는 사용자에게는 틀리고 모델 판단에만 맞다. docstring 은 이 문구가 피검자가 쓰는 것이라 dispatch 를 건너뛴 것과 도구 부재를 구별하지 못한다고 적는다."
    touches: []
    decides: []
  - id: RC9
    path: "plugins/spec-distill/skills/pm-interview/SKILL.md"
    anchor: "필수 자리 둘(첫 질문 전 `coverage-mapper`, blind_spot 차원의 첫"
    line: 298
    claim: "필수 조사 자리는 둘이고 본문이 두 번(298 · 532행) 「그대로다」 라고 적는다. 강등 길은 계약 배달 실패(261행)와 웹 비활성 때의 inline premortem(495행)뿐이다 — 일이 작다는 이유의 길은 없다. trivia 판정(84행)은 seed 입력이면 건너뛴다(86행)."
    touches: []
    decides: []
  - id: RC10
    path: "plugins/spec-distill/scripts/build_seed_inline_blob.py"
    anchor: "main"
    line: 143
    claim: "세 경로 중 하나라도 파일이 아니면 rc 2 다(143–146행). `skills/request-framing/SKILL.md` 589–590행은 셋째 인자로 cwd 상대 리터럴 `CLAUDE.md` 를 넘기고, rc 가 0 이 아니면 그 라운드를 시작하지 않는다(599행). `tests/test_seed_inline_blob.sh` 99–101행이 `claude_md_file` 부재의 rc 2 를 락으로 지킨다 — 의도된 동작이다. 실행은 하지 않았다(이 agent 에 실행 도구가 없다). cwd 가 레포 루트가 아닐 때도 같은 실패가 나는지는 확인하지 못했다."
    touches: []
    decides: []
  - id: RC11
    path: "plugins/spec-distill/references/docreview-profiles/brief.md"
    anchor: "### 판정 절차 — 사다리"
    line: 55
    claim: "seed 의 「인터뷰 결과물 리뷰 기준이 레포 원칙을 깎는 잣대로 쓴다」 는 절반만 맞다. 사다리 2단 「이미 리포에 있는 원칙·메커니즘으로 되나」(60행)는 과함 판정의 줄이는 근거가 맞다. 그러나 74행 「Law 1·2·3 과 kill switch 는 어떤 모드에서도 안 자른다」 는 「자르지 않는 것」 절 아래의 보호 조항이다 — 깎는 잣대가 아니라 깎지 못하게 하는 줄이다. 이 축의 처분은 모두 `decide` 이고 동점은 자르지 않는 쪽으로 간다(57 · 65행)."
    touches: []
    decides: []
  - id: RC12
    path: "plugins/spec-distill/references/compression.md"
    anchor: "3. 레포 `CLAUDE.md`·`AGENTS.md` 에 이미 있는가. 있으면 빼고, 빼면 표에 남긴다."
    line: 46
    claim: "압축 규약은 CLAUDE.md 에 이미 있는 것을 seed 에서 뺀다. 그 규칙이 낡았을 때 올리는 길은 이 파일에 없다(71행까지 읽음). 이번 seed 의 덜어 낸 것 표가 유지 근거 목록을 「상시 규칙」 으로 뺀 것이 이 규약의 적용이다."
    touches: []
    decides: []
  - id: RC13
    path: "plugins/spec-distill/references/research-claims.md"
    anchor: "출처: `docs/archive/interview/2026-07-12-project-init-audit-interview.md`"
    line: 38
    claim: "조사 주장 계약에 이 레포의 아카이브 경로가 박혀 있고 조사 agent 프롬프트에 그대로 실린다 — 이번 dispatch 가 받은 계약 전문에 같은 줄이 있었다. 보고가 맞다."
    touches: []
    decides: []
  - id: RC14
    path: "docs/plugin-authoring.md"
    anchor: "`quality-gates:doc-recritic`(Phase 1.5 재비판, 공유 정본의 copy-of 사본)"
    line: 23
    claim: "예시로 든 agent 는 없다. `plugins/quality-gates/agents/` 에는 artifact-adversarial · artifact-critic · code-recritic · security-reviewer 넷뿐이고, `doc-recritic` 은 `shared/docreview/agents/` 와 `plugins/spec-distill/agents/` 에 있다."
    touches: []
    decides: []
  - id: RC15
    path: "docs/plugin-authoring.md"
    anchor: "`plugin-dev:skill-development` / `command-development` / `agent-development`"
    line: 45
    claim: "구현 단계 목록에 `command-development` 가 남아 있다. CLAUDE.md 「새 command 파일은 만들지 않는다」 와 공식 문서 둘 다와 어긋난다. 22행의 `model` 키 금지 근거(CLI 2.1.261 실측, 2026-09-06)는 지금 공식 문서의 순서와 맞는다(evidence 1)."
    touches: []
    decides: []
  - id: RC16
    path: "plugins/spec-distill/scripts/roadmap_status.py"
    anchor: "find_specs"
    line: 336
    claim: "상태 계산은 설계문서 머리의 `source_interview` 값이 묶음 경로와 글자가 같은 파일을 찾는다(336 · 680행). 키 이름을 바꾸면 옛 설계문서가 조용히 「설계 없음」 으로 세어진다 — 두 키를 함께 읽거나 옛 문서를 고쳐야 한다. 이 파일은 R1 예약이다(RC23)."
    touches: []
    decides: []
  - id: RC17
    path: "plugins/spec-distill/scripts/repo_defaults.py"
    anchor: "KEYS = (\"specs_dir\", \"plans_dir\", \"roadmaps_dir\", \"interview_dir\""
    line: 36
    claim: "설정 키 `interview_dir` 는 KEYS · `_FOLDER_KEYS` · `_DEFAULTS` · `check-path` 선택지(545행)에 있고, 끝내기 커밋 펜스(`finishing.md` 606행)가 이 키로 brief 자리를 검사한다. 이 파일은 R2 예약이다."
    touches: []
    decides: []
  - id: RC18
    path: "shared/tests/test_invocation_surface.sh"
    anchor: "ENTRY = [(\"spec-distill\", \"request-framing\", False), (\"spec-distill\", \"pm-interview\", False),"
    line: 34
    claim: "호출 이름은 진입 표면 락에 등록돼 있고, 지난 이름 바꾸기의 옛 이름(`conducting-interview` · `spec-interview` · `spec-distill:interview`)을 금지하는 축 I 이 있다(135–157행). fixture 와 `docs/superpowers/interview/` 경로 조각은 면제다(146 · 158행). 이번 이름 바꾸기는 이 목록과 면제 규칙을 함께 고쳐야 하고, 폴더 이름까지 바꾸면 경로 면제가 달라진다."
    touches: []
    decides: []
  - id: RC19
    path: "plugins/spec-distill/tests/test_superpowers_presence.sh"
    anchor: "FIN=\"$SD/skills/pm-interview/references/finishing.md\""
    line: 16
    claim: "`finishing.md` · request-framing `SKILL.md` · pm-interview `SKILL.md` 를 경로로 가리키는 테스트는 `plugins/` · `shared/` 에 57개 파일 210곳이다(Grep 계수 — 심볼릭 링크는 건너뛰므로 하한). 이 파일 106–125행처럼 본문 문장의 글자를 단언하는 락이 있다."
    touches: []
    decides: []
  - id: RC20
    path: "plugins/spec-distill/skills/request-framing/SKILL.md"
    anchor: "파일 전체 줄 수"
    claim: "줄 수(Grep `^` 계수): request-framing 1373 · pm-interview 600 · reviewing-brief 741 · spec-review 828 · epic-conductor 206. 기록 파일의 1373 · 600 과 같고, reviewing-brief 는 742 가 아니라 741 이다. 이유 · 이력 설명의 비율(5분의 1 · 6–8% · 35%)은 이 agent 의 도구로 재지 못했다."
    touches: []
    decides: []
  - id: RC21
    path: "plugins/spec-distill/skills/pm-interview/references/finishing.md"
    anchor: "#### B-2 — 단일 `AskUserQuestion` proceed 게이트 (4옵션, AC2)"
    line: 461
    claim: "옛 설계 번호는 실재한다 — 「(4옵션, AC2)」(461행) · 「규약의 거처 (C5)」 · 「C4 재결정 프로토콜」(538–539행) · 「(NG4·P17)」(569 · 574행) · 「(NG7)」(685행). 같은 파일 551행이 「AC1 · AC2 …」 를 살아 있는 번호로 쓰게 지시해 글자가 겹친다. 「약 45곳」 은 재현하지 못했다 — 좁은 패턴으로 `skills/**/*.md` 에서 20건(이 파일 12건)이 나왔고 수는 패턴에 달렸다."
    touches: []
    decides: []
  - id: RC22
    path: "plugins/spec-distill/skills/request-framing/SKILL.md"
    anchor: "### 저자 편집 공시 — 라운드 게이트 앞 · 확정 게이트 앞"
    line: 907
    claim: "사용자가 보기 어렵다고 한 덩어리 승인의 규칙은 여기다 — 덩어리마다 질문 하나(「그대로 둔다 / 되돌린다」), 추천 없음, 덩어리 본문을 질문 텍스트에 줄임 없이 싣기(933–935행), 공시마다 번호 다시 매기기(913행). 추천 없음과 줄임 없음에는 이유가 함께 적혀 있다(저자가 승인 여부를 가르지 않게 · 줄이면 공시가 아니다). 무엇이 보기 어려웠는지는 사용자만 답할 수 있다."
    touches: []
    decides: []
  - id: RC23
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md"
    anchor: "### R2 — 지휘 절차 개편"
    line: 44
    claim: "R2 의 경로 예약에 `repo_defaults.py` · 철학 문서 · `CLAUDE.md` 가 있다. R1(32행)은 `roadmap_status.py` · `epic-handoff.md` 를 포함한 일곱, R5(79행)는 `docs/superpowers/specs/` · `roadmaps/` · spec-distill `CHANGELOG.md` 다. `finishing.md` · 두 진입 `SKILL.md` · `docs/plugin-authoring.md` 는 어느 예약에도 없다. CHANGELOG 가 R5 예약이라 이 일의 major bump 기록과 겹친다 — seed 에 없는 겹침이다."
    touches: []
    decides: []
  - id: RC24
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R2.md"
    anchor: "**C2** — devbrew 파이프라인의 모든 단계가 팀을 쓰고, 설계문서 하나뿐인 작은 일도 지휘자를 거친다"
    line: 42
    claim: "「작은 일도 지휘자를 거친다」(C2, 🗣 confirmed)와 「작은 일은 가볍게 돌린다」(D11, 52행)가 같은 묶음에 나란히 확정돼 있고, 위험 K1(105행)이 그 긴장을 「대응: 작은 일은 가볍게(D11)」 로 적는다. seed 가 본 긴장은 옆 로드맵 안에 이미 있고 풀 곳은 R2 다."
    touches: []
    decides: []
  - id: RC25
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "| brief · audit 를 `intent/` 에 바로 쓰기 · `source_interview` 키 이름 |"
    line: 649
    claim: "이 파일은 이 worktree 에 없다 — 옆 worktree(`.claude/worktrees/team-file-contract`, 브랜치 `feature/team-file-contract`)에서 읽었다. 미룸 표의 그 줄은 이제 649행이고(seed 리뷰 때 555행 — 그 뒤 또 바뀌었다) 받는 곳 칸은 「R5」, 이유 칸은 「이름 바꾸기 로드맵(B13)이 먼저 하면 R5 는 옮길 때 확인만 한다」 다. 737행은 더 나아가 「그 로드맵이 `source_interview` 키와 `intent/` 에 바로 쓰기를 정한다」 고 적는다 — 옆 문서는 이 일이 그 둘을 정한다고 전제하고, seed 는 맡을지 묻지 않았다고 적는다. 204행 「사용자 원문 절은 싣지 않는다 — `intent/original.md` 가 정본이다」, 176행 「앞단이 `intent/` 에 바로 쓰게 되기 전까지 audit · brief 에서 옮긴 사본」, 401행 「키 이름은 이름 바꾸기 로드맵이 정할 때까지 그대로 둔다」 도 확인했다. 승인 여부는 이 파일에서 확인하지 못했다."
    touches: []
    decides: []
  - id: RC26
    path: "docs/philosophy/devbrew-harness-philosophy.md"
    anchor: "### P8 — Determinism Economy (Maintain Simplicity)"
    line: 84
    claim: "P8 「(흐름)」 줄은 「정석 흐름(brainstorming → 계획 → 구현)」 으로 superpowers skill 이름을 박는다. CLAUDE.md Law 1 과 `finishing.md` 551행의 사본은 「설계 → 계획 → 구현」 이다 — 정본과 사본이 이미 글자가 다르다. 82행 「결정론은 보안/정확성 게이트(fail-closed)…에만」 은 R2 가 개정 대상으로 잡은 문장이다."
    touches: []
    decides: []
  - id: RC27
    path: "plugins/spec-distill/skills/request-framing/SKILL.md"
    anchor: "git commit -q --only -m 'docs(interview): <topic> interview seed + audit'"
    line: 1157
    claim: "커밋 메시지가 리터럴이다 — 여기는 영어, `finishing.md` 640행은 한국어. 둘 다 scope 가 `interview` 라 이름 바꾸기 표면이기도 하다. seed 템플릿 머리(`interview-seed-audit-template.md` 11행)는 원자료가 남는 유일한 파일을 「순수 텔레메트리」 라 부르고 호출 이름 `pm-interview` 를 싣는다."
    touches: []
    decides: []
```

**seed 의 「다시 검증할 것」 과 달라진 것**

- 틀린 것 하나: 인터뷰 결과물 리뷰 기준이 Law 1·2·3 을 깎는 잣대로 쓴다는 보고(RC11). Law 줄은 보호 조항이다.
- 반만 맞는 것 하나: 포화 판정을 건너뛸 칸이 없다는 보고(RC8). 사용자 종료 칸은 있고 모델 판단 칸만 없다.
- 분류가 어긋난 것 하나: superpowers 부재 때 끝 게이트가 없다는 것(RC5). seed 는 agent 보고로, 기록 파일은 직접 확인으로 적었고 내용은 맞다.
- seed 에 없는 겹침 둘: spec-distill `CHANGELOG.md` 가 R5 예약이다(RC23). 옆 설계문서가 `intent/` 에 바로 쓰기를 이 일의 몫으로 적는다(RC25).
- 지금도 맞는 것: `model` 키 금지 근거(evidence 1).

**확인하지 못한 것**

- 이유 · 이력 설명의 비율과 옛 설계 번호 「약 45곳」.
- 번들 조립 실패의 실제 실행(코드와 락만 읽었다).
- 열린 PR #274 의 내용.
- 옆 설계문서의 승인 상태.
- 옆 세션 원자료 대조표의 수치.

**읽은 파일**

- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/interview/2026-11-14-framing-interview-constraint-audit-interview.audit.md` — 1–461행만 읽었다. 그 뒤(재비판 이후 라운드 · 리뷰 결정)는 읽지 않았다.
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/skills/pm-interview/references/finishing.md` — 425–685행
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/skills/pm-interview/references/seed-input.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/skills/request-framing/SKILL.md` — 560–604행 · 905–938행
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/check_brief.py` — 1555–1612행 · 1730–1799행
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/build_seed_inline_blob.py`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/seed_body.py` — 1–80행
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/roadmap_status.py` — 322–341행
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/references/docreview-profiles/seed.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/references/docreview-profiles/brief.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/references/epic-handoff.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/references/compression.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/references/research-claims.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/plugin-authoring.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/philosophy/devbrew-harness-philosophy.md` — 76–89행
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R2.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md` — 옆 worktree, Grep 으로 맞은 줄만

Sources:
- [Claude Code — sub-agents](https://code.claude.com/docs/en/sub-agents)
- [Claude Code — skills](https://code.claude.com/docs/en/skills)
- [Claude Code — plugins reference](https://code.claude.com/docs/en/plugins-reference)
~~~~

### 조사 2 — repo-researcher · R1 · 묶음 1

~~~~
레포 근거 조사 결과다. 열린 결정 목록이 비어 있어 `decides` 는 전부 빈 배열이고, 전제도 받지 않아 `touches` 도 비어 있다.

읽은 판:
- main 머지 판 (repo 상대경로의 뿌리): `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/`
- team-file-contract worktree 판 (절대경로로 적음): `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/`
- 설계문서 741줄은 처음부터 끝까지 읽었다. roadmap.md 는 두 판 모두 전문을 읽었고, 묶음 여섯은 main 판 전문을 읽었다.
- 묶음의 두 판 비교는 줄 수와 `ids:` 줄 대조까지만 했다. 바이트 대조는 하지 못했다.

```yaml
repo_claims:
  # ── 두 판 비교 ──
  - id: RC1
    path: "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md"
    anchor: "### 2026-11-14 · 처음 로드맵"
    line: 98
    claim: "team-file-contract worktree 의 roadmap.md 는 main 판과 119줄 전부 같은 글이다 — 더 새로운 판이 아니다. 묶음 여섯도 두 판의 줄 수(P1 193 · R1 242 · R2 239 · R3 201 · R4 194 · R5 191)와 ids 줄이 같다. 두 판 모두 `## 결정 기록` 에 줄이 없고 재분해 이력은 처음 로드맵 하나뿐이라, 설계문서가 올린 재분해 신호 ①–④ 는 어느 판의 로드맵에도 아직 없다."
    touches: []
    decides: []

  # ── roadmap.md (main 판) ──
  - id: RC2
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md"
    anchor: "- 경로 예약: (P1 · R1–R5 블록)"
    line: 18
    claim: "에픽별 경로 예약. P1: 로드맵 폴더의 token-baseline.md. R1: spec-distill scripts 의 roadmap_write.py · roadmap_render.py · roadmap_model.py · roadmap_status.py · check_bundle_coverage.py · spec_review_bundle.py 와 references/epic-handoff.md. R2: references/conducting.md · references/conductor-dispatch.md · skills/epic-conductor/SKILL.md · scripts/repo_defaults.py · docs/philosophy/devbrew-harness-philosophy.md · CLAUDE.md. R3: scripts/conductor_state.py · control_plane.py · state_path.py · docs/git-workflow/branch-strategy.md · plugins/project-init/hooks/post-tool-use.py. R4: plugins/spec-distill/README.md · dependencies.md. R5: docs/superpowers/specs/ · docs/superpowers/roadmaps/ · plugins/spec-distill/CHANGELOG.md. 어느 에픽도 skills/request-framing · skills/pm-interview(끝맺음 절차 finishing.md 포함) · scripts/interview_state.py · scripts/conductor_ledger.py · docs/superpowers/interview/ 를 예약하지 않았다."
    touches: []
    decides: []
  - id: RC3
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md"
    anchor: "에픽마다 원본 brief · 이 로드맵 · 에픽 묶음을 넘긴다"
    line: 8
    claim: "로드맵이 정한 넘김 단위는 원본 brief · 로드맵 · 에픽 묶음 셋이다. frontmatter `source_brief:` 는 인터뷰 폴더의 brief(docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.md)를 가리킨다. framing seed 나 framing audit 는 넘김 단위에 없다."
    touches: []
    decides: []
  - id: RC4
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md"
    anchor: "### R2 — 지휘 절차 개편"
    line: 40
    claim: "철학 문서와 CLAUDE.md 는 R2 의 몫이다 — 범위에 「P8 · CLAUDE.md 개정」 이 있고 두 파일이 R2 경로 예약에 있다. 위험 K14 는 「P8 · CLAUDE.md 만 고치면 사본 문장과 P8 이름 인용이 옛 뜻으로 남는다」 를 적는다(119행)."
    touches: []
    decides: []
  - id: RC5
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md"
    anchor: "### R5 — 이전 · 재측정"
    line: 75
    claim: "R5 범위는 「설계문서 지휘 기록 · 에픽 묶음 이전, 도는 로드맵 이전, 옛 장치 정리, 재측정 비교 / 안 한다: 새 기능」 이다. 예약은 specs/ · roadmaps/ · CHANGELOG 뿐이고 인터뷰 폴더는 없다 — 인터뷰 산출물(brief · audit · seed)의 이전은 R5 블록 문면에 없다."
    touches: []
    decides: []
  - id: RC6
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md"
    anchor: "K1 — 위험 — 숨은 가정: 모든 단계 · 작은 일까지 팀과 지휘자를 거치게 해도 토큰이 준다"
    line: 106
    claim: "작은 일에 대해 로드맵이 적은 것은 위험 K1 과 그 대응 「작은 일은 가볍게(D11)」 한 줄이다. 작은 일의 길을 다루는 에픽 블록 · 범위 문장은 따로 없다."
    touches: []
    decides: []

  # ── 에픽 묶음 (main 판) ──
  - id: RC7
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R1.md"
    anchor: "## 0. 역참조 — 이 에픽의 설계문서는 frontmatter `source_interview:` 에 이 묶음 경로를"
    line: 15
    claim: "묶음 여섯(P1 · R1–R5) 모두 §0 에서 설계문서 frontmatter `source_interview:` 에 묶음 경로를, `roadmap:` 에 로드맵 경로를 적고 `## 번호 대조` 표에 ids 전부를 실으라고 지시한다. 곧 `source_interview` 라는 키가 실제로 가리키는 것은 인터뷰가 아니라 에픽 묶음이다. 이 문장은 plugins/spec-distill/scripts/roadmap_render.py 336행이 찍는다."
    touches: []
    decides: []
  - id: RC8
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R1.md"
    anchor: "## 6. 사용자 원문 — **S1** 최초 요청(Phase 0 seed 전문)"
    line: 116
    claim: "묶음이 싣는 사용자 원자료는 framing seed 의 산문 전문(S1)과 인터뷰 발화 · 선택 S2–S50 이고, 여섯 묶음 모두 같은 §6 을 되풀이 싣는다. framing audit 의 원문 절(붙여 넣은 my-team 구조 · 규칙 목차 글 · 영상 구조)은 묶음에 없다. S1 안의 seed 머리는 `type: interview-seed` · `next_phase: spec-distill:pm-interview` · `audit_file: 2026-11-13-conductor-context-economy-interview.audit.md` 다."
    touches: []
    decides: []
  - id: RC9
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R2.md"
    anchor: "**C2** · **D11**"
    line: 42
    claim: "작은 일의 길에 대한 묶음의 확정 항목은 둘이다. C2(confirmed, R1 · R2 묶음) 「설계문서 하나뿐인 작은 일도 지휘자를 거친다」. D11(confirmed, R2 · P1 묶음 — R1 묶음에는 없다) 「작은 일은 가볍게 돌린다」. 위험 K1 은 R2 묶음에 있다. S1 원문은 「지휘자 없이 도는 흐름을 따로 두지 않는다. (사용자 확인)」 이다."
    touches: []
    decides: []
  - id: RC10
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R5.md"
    anchor: "OQ47 [열림] — devbrew 산출물의 「한곳」은 무엇인가"
    line: 53
    claim: "인터뷰 산출물의 자리는 묶음에서 열린 질문이다 — OQ47(R1 · R5 묶음 둘 다 [열림])이 「로드맵(팀) 폴더 하나 아래에 인터뷰 · 설계 · 계획 · INTENT · 결과를 다 둘지, 단계별 폴더(interview · specs · plans · roadmaps)를 두고 색인만 둘지」 를 묻는다. S49 는 「팀 파일 규약(R1) · 이전(R5) 설계가 정한다. 인터뷰는 다시 열지 않는다」 고 받는 곳을 적었다."
    touches: []
    decides: []
  - id: RC11
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R2.md"
    anchor: "OQ24 [열림] — P8 과 CLAUDE.md 의 새 문장"
    line: 70
    claim: "철학 문서 · CLAUDE.md 의 새 문면은 정해지지 않았다 — R2 묶음 OQ24 가 [열림]이고 근거는 RC2 · RC189, 위험은 K5 · K14 다. S1 원문은 「devbrew 원칙 P8 의 결정론은 보안 · 정확성 게이트에만 내용은 바꾼다. (사용자 확인)」 이고 C10(R1 묶음)은 「기존 규칙은 고칠 후보로 본다」 다. R1 묶음 OQ45 [열림]는 S23 원칙 「잘못 쌓인 맥락은 없는 것보다 나쁘다」 를 「레포 원칙 문서 · HANDBOOK · CLAUDE.md 중」 어디에 둘지 묻는다."
    touches: []
    decides: []
  - id: RC12
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R2.md"
    anchor: "OQ23 [열림] — 역할 목록과 devbrew 이름"
    line: 69
    claim: "이름에 대해 묶음이 가진 것은 역할 이름(OQ23 [열림], R2)과 규칙 목차 이름(D24 · OQ22, R1)뿐이다. 「인터뷰」 명칭 · `interview_dir` · `source_interview` 키 · 인터뷰 폴더 이름을 바꾸거나 유지한다는 항목은 여섯 묶음 어디에도 없다(전문을 읽어 확인). S1 은 「역할 이름은 devbrew 가 쓰는 말로 바꾼다. (사용자 확인)」 고 적는다."
    touches: []
    decides: []
  - id: RC13
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R2.md"
    anchor: "ids: [C2, C5, C6, C39, C40, C41, C44, C46, C50, …]"
    line: 6
    claim: "R2 묶음의 ids 와 §2 제약에는 C50 이 이미 있고(50행) S50 은 ids 에 없다. 두 worktree 의 R2.md 가 같다. 설계문서 재분해 신호 ④ 의 「R2 의 묶음에 그 번호가 없다」 와 C50 에 대해 어긋난다(RC27)."
    touches: []
    decides: []
  - id: RC14
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R1.md"
    anchor: "## 7. 인터페이스"
    line: 241
    claim: "묶음의 에픽 사이 넘김. R1 받는 것 없음, 넘기는 것 「과제 폴더 · INTENT.md · results/ 형식, 규칙 목차 형식, 시작 묶음 고르기 스크립트, 파일 기준 단계 계산」. R2 받는 것 「R1 의 파일 형식 · 시작 묶음 스크립트」, 넘기는 것 「단계표 형식 · 지시서 · 강제 스크립트 · 새 P8」. R3 받는 것 「R1 의 STATUS · INTENT 형식」. R5 받는 것 「R1–R4 결과 · P1 기준선」. 앞단(framing · 인터뷰)에서 받는다고 적은 묶음은 없다."
    touches: []
    decides: []

  # ── 팀 파일 규약 설계문서 (team-file-contract worktree 판 · 승인 전) ──
  - id: RC15
    path: "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "## Context / Why — 「내 의도가 interview지나면서 의역된거 같아서 그래」"
    line: 34
    claim: "(team-file-contract 판) 설계의 진단: 사용자가 framing 에서 붙여 넣은 폴더 구조와 행동양식이 「seed 의 산문 → brief 의 번호 항목 → 에픽 묶음으로 가며 줄었고, R1 묶음에는 역할 이름 목록조차 없었다」. 정한 것: 「과제 파일은 원자료를 글자 그대로 싣고, 설계는 원자료 전체를 기준으로 대조해야 한다」. 28행은 지금 산출물이 인터뷰 `interview_dir` · 설계 `specs_dir` · 계획 `plans_dir` · 묶음 `roadmaps_dir/<로드맵>/` 넷에 흩어져 있다고 적는다."
    touches: []
    decides: []
  - id: RC16
    path: "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "### §3 원자료 — `intent/`"
    line: 180
    claim: "(team-file-contract 판) 사용자 원자료의 집은 로드맵 폴더의 `intent/original.md` 한 파일이다. framing audit 의 원문 절과 질문 전체 절을 글자 그대로 옮기고, 인터뷰 발화(brief 와 그 audit 의 사용자 원문 절)를 이어 붙이고, 머리에 출처 경로와 커밋을 적는다. 옮긴 구간은 출처와 바이트가 같아야 한다(AC5). brief · audit 파일 자체를 `intent/` 로 옮기는 일은 「이 설계가 하지 않는다 — 의도 싱크 skill 이 쓰는 자리를 바꾸는 일이라 이름 바꾸기와 함께 간다」. 그때까지 `intent/` 에는 `original.md` 와 brief · audit 의 지금 경로를 적은 `README.md` 만 있다. 176행은 `original.md` 가 「앞단이 `intent/` 에 바로 쓰게 되기 전까지 audit · brief 에서 옮긴 사본」 이라고 적는다."
    touches: []
    decides: []
  - id: RC17
    path: "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "### §1 팀 폴더 — `intent/` 행"
    line: 114
    claim: "(team-file-contract 판 · 문서 안 어긋남) §1 의 파일 표는 `intent/` 에 「원자료(줄이지 않음) · brief」 를 적고 쓰는 사람을 생성기로, 나무 그림(98행)은 「원자료와 의도 싱크 결과」 로 적는다. §3(188행)은 brief · audit 를 `intent/` 로 옮기지 않고 `original.md` 와 `README.md` 만 둔다고 적는다. 원문 대조 표(498행)도 「brief · audit 는 아직 옛 자리다(§3)」 라고 한다. 두 자리가 `intent/` 의 내용을 다르게 말한다."
    touches: []
    decides: []
  - id: RC18
    path: "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "### §2 과제 폴더와 INTENT.md — **한 번만 짓는다.**"
    line: 161
    claim: "(team-file-contract 판) 앞단 산출물을 쓰는 자리. INTENT.md 의 지시 원문 칸은 원자료를 다시 싣지 않고 `intent/original.md` 의 줄 범위로 가리킨다. 번호 항목(제약 · 열린 질문 · 근거)의 집은 과제 폴더의 `sources.md` 로, brief 의 번호 항목에서 생성기가 내고 다시 쓴다. 설계하는 쪽은 `original.md` 전체를 읽고 설계문서 `## 원문 대조` 표를 전체 기준으로 채운다(190행). `sources.md` 는 사용자 원문 절을 싣지 않아 「묶음마다 seed 전문을 되풀이 싣던 것이 사라진다」(204행). 묶음을 INTENT.md(짧게)와 sources.md 로 가른 것은 D21 에서 바꾼 것으로 표시돼 있다(509행)."
    touches: []
    decides: []
  - id: RC19
    path: "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "### §11 생성기"
    line: 391
    claim: "(team-file-contract 판) 앞단 끝과 생성기의 이음. `roadmap_write.py original --brief <brief>` 가 분해안을 쓰기 전에 `original.md` 를 따로 만든다. framing audit 는 인터뷰 상태 파일의 seed 경로에서 찾고(seed 와 같은 폴더의 audit), 없으면 `--framing-audit` 로 받고, 그것도 없으면 brief 쪽 사용자 원문만 싣고 그 사실을 머리에 적는다. `create --layout team` 이 새 형식을 만들고 `--layout` 없이는 옛 묶음 형식이다. 새 형식을 기본으로 켜는 것은 R2 다(390행). 과제마다 지시 원문 범위의 글을 분해 승인 질문에 끼우는 일은 「인터뷰 끝맺음 절차의 몫이라 새 형식을 켤 때 함께 한다」(392행). 상류 연계(546행)는 「분해 승인(인터뷰 끝맺음)이 `roadmap_write.py create` 를 부른다」 고 적는다."
    touches: []
    decides: []
  - id: RC20
    path: "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "## 미룸 — 분해 승인 화면에 과제마다 지시 원문 범위의 글을 보이기 · 분해 전에 `original` 을 부르기"
    line: 642
    claim: "(team-file-contract 판 · 문서 사이 어긋남) 미룸 표는 인터뷰 끝맺음 절차를 고치는 두 일을 「인터뷰 끝맺음 절차 파일은 이 에픽의 예약 밖」 이라며 R2 로 넘긴다. 그러나 roadmap.md 의 R2 경로 예약(RC2)에 그 파일은 없다. 실제 파일은 plugins/spec-distill/skills/pm-interview/references/finishing.md 로, 229행이 `roadmap_write.py create --brief` 를 부르고 어느 에픽도 예약하지 않았다."
    touches: []
    decides: []
  - id: RC21
    path: "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "### §12 대조 스크립트 — `references/epic-handoff.md`"
    line: 405
    claim: "(team-file-contract 판) 넘김 글. R1 이 예약한 `references/epic-handoff.md` 에 team 형식 넘김 줄을 더한다 — 묶음 대신 INTENT.md 를 첨부하고, `intent/original.md` 전체와 `sources.md` 를 읽고, 설계문서에 `## 원문 대조` 표를 두고, 바꾼 것은 근거를 적거나 「작성자 제안」 으로 표시하라는 지시 넷이다(AC17). `spec_review_bundle.py --bundle` 은 INTENT.md 를 받고 설계문서 머리 `source_interview` 가 그 경로와 같아야 한다 — 「키 이름은 이름 바꾸기 로드맵이 정할 때까지 그대로 둔다」(401행). 리뷰어 프로필에 과제 파일 모드를 넣는 일은 R2 로 넘겼다."
    touches: []
    decides: []
  - id: RC22
    path: "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "## Non-goals — 「인터뷰」 명칭을 「의도 싱크」로 바꾸기(skill 호출 이름 · 설정 키 · 머리 키)"
    line: 51
    claim: "(team-file-contract 판) 이름 바꾸기는 이 로드맵 밖이다 — 「다른 로드맵으로 넘겼다(§결정 기록 B13)」. B13 원문(671행): 「의도 싱크로 바꾸고 따로 에픽으로 두자」 · 「의도 싱크 이름 바꾸기 에픽을 하는거는 다른 로드맵에 넘길 수 있을까 지금 framing 시작한 클로드 세션 하나 있거든」 · 「맞아 devbrew-7b 로 보내줘」. Handoff Context(737행): 받은 쪽은 framing 을 하던 다른 세션이고 브랜치는 `feature/framing-interview-constraint-audit`, 「그 로드맵이 `source_interview` 키와 `intent/` 에 바로 쓰기를 정한다」."
    touches: []
    decides: []
  - id: RC23
    path: "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "## 미룸 — brief · audit 를 `intent/` 에 바로 쓰기 · `source_interview` 키 이름"
    line: 649
    claim: "(team-file-contract 판 · 문서 안 어긋남) 미룸 표의 이 행은 받는 곳 칸이 R5 이고 이유 칸은 「이름 바꾸기 로드맵(B13)이 먼저 하면 R5 는 옮길 때 확인만 한다」 다. 같은 문서의 Non-goals(51행) · §3(188행) · §12(401행) · Handoff Context(737행)는 이 일을 정하는 쪽을 다른 로드맵(이름 바꾸기)으로 적는다. 받는 곳이 R5 인지 다른 로드맵인지가 문서 안에서 갈린다. roadmap.md 의 R5 블록 범위 · 예약(RC5)에는 인터뷰 폴더도 `source_interview` 도 없다."
    touches: []
    decides: []
  - id: RC24
    path: "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "### §2 — 과제는 에픽이거나 단순 작업(로드맵 밖 수리 · 정리)이다. 어느 쪽이든 과제 폴더 없이 도는 일은 없다."
    line: 127
    claim: "(team-file-contract 판) 작은 일의 길. 단순 작업도 `jobs/<과제>/` 폴더(INTENT.md · results/ 필수, `kind: task`, 머리의 `branch` · `paths`)를 갖는다. `job new --roadmap … --name … --branch … --paths …` 가 그 작업 브랜치의 첫 커밋으로 만들고 지시 원문은 받은 말 그대로다(396행 · AC7). 설계가 없는 과제의 단계는 준비 → 진행 중 → 결과 받음 → PR · 머지됨이고 현황에 「로드맵 밖 과제」 로 따로 보인다(371 · 376행 · AC14). 근거는 B3 · B9(「단순 작업오 jobs에 들어가야 한다는거야」). 미룬 것: 「도는 로드맵이 없을 때 단순 작업을 어느 팀의 `jobs/` 에 둘지」 → R2(643행). 번호 대조 C2 행(685행)은 「모든 단계가 팀으로 도는 절차는 R2」 다. D11(작은 일은 가볍게)은 R1 ids 에 없어 이 설계의 번호 대조에 행이 없다."
    touches: []
    decides: []
  - id: RC25
    path: "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "## Constraints — 사용자에게 보이는 말은 「리더」다"
    line: 71
    claim: "(team-file-contract 판) 이 설계가 정한 이름과 폴더. 사용자에게 보이는 말은 「리더」(지휘자 · 대장 아님, B6)이고 skill 이름 `epic-conductor` 는 바꾸지 않는다. 규칙 목차는 RULES.md(B7), 문서 역할 폴더는 writer(D1.1), 역할 폴더는 leader · designer · writer · worker 넷. 원자료 폴더 이름은 `intent/`. `roadmaps_dir` 기본값은 바꾸지 않고 devbrew 의 로드맵 폴더를 레포 맨 위 `roadmaps/` 로 옮기는 일은 R5 가 한 번에 한다(B16 · 409행). `.devbrew.md` 는 만들지 않는다(597행). `interview_dir` 은 Context 와 있는 것 검토 표에 지금 있는 키로만 나오고 이 설계가 바꾸지 않는다. 새 설정 키는 `rules_budget` · `handbook_budget` 와 로드맵 머리말의 `layout` 이다(410–411행)."
    touches: []
    decides: []
  - id: RC26
    path: "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "## Files to Modify"
    line: 585
    claim: "(team-file-contract 판) 이 설계는 철학 문서와 레포 CLAUDE.md 를 고치지 않는다 — Files to Modify 에 둘 다 없다. 닿는 자리 넷: ① S23 원칙의 자리(OQ45)는 HANDBOOK.md 머리말로 정했다(308 · 711행). ② 팀 공통 CLAUDE.md 는 두지 않는다(52 · 468행, B9). ③ 역할 문서는 `roadmaps/<역할>/CLAUDE.md` 이고 「하지 않을 일은 알림이지 집행이 아니다. 막는 것은 도구 권한이고 그 자리는 R2 가 정한다」(69행). ④ 있는 것 검토는 규칙 저장소로 「레포 CLAUDE.md · docs/philosophy/」 를 적고 HANDBOOK · `.claude/rules` 는 없다고 확인한다(535행)."
    touches: []
    decides: []
  - id: RC27
    path: "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "## Metadata — 재분해 신호(로드맵 수정 PR 로 올린다)"
    line: 726
    claim: "(team-file-contract 판) 설계가 로드맵에 요구하는 변경 넷. ① R1 블록 `브랜치:` 에 계획 2 · 3 브랜치(`feature/team-file-read` · `feature/team-file-rules`) 더하기. ② R1 경로 예약에 `scripts/conductor_ledger.py` 와 새 파일들을 더하고, `scripts/repo_defaults.py`(R2 예약) · `scripts/control_plane.py`(R3 예약)를 R1 이 먼저 고친다고 적기. ③ framing 원자료 대조표를 로드맵 폴더에 `framing-ledger.md` 로 올려 R2–R5 설계의 입력으로 삼기. ④ C50 · S50 을 R2 번호 목록에 더하기 — 「R2 의 묶음에 그 번호가 없다(D1.2)」. ④ 는 C50 에 대해 R2.md 실물과 어긋난다(RC13). 591행은 예약 밖으로 고치는 파일 셋을 적는다."
    touches: []
    decides: []
  - id: RC28
    path: "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "## Handoff Context — **원자료 대조표.**"
    line: 736
    claim: "(team-file-contract 판) 뒤 에픽으로 가는 넘김 글. framing 원자료를 한 줄씩 적은 표(F 번호 243행 — 인용 · 맡은 에픽 · 묶음에 실린 꼴 · 잃은 것 — 과 에픽별 넘김 목록)가 「아직 레포에 없다」. 로드맵 수정 PR 이 로드맵 폴더의 `framing-ledger.md` 로 올리고, R2–R5 설계는 자기 몫 넘김 목록을 첫 입력으로 읽는다. 올라가 있지 않으면 설계 전에 그 PR 부터 확인한다(B11). 미룸 표 650–653행이 R2 · R3 · R4 · R5 몫 넘김 목록을 받는 곳별로 넘기고 이유는 「뒤 에픽의 묶음은 seed 산문만 싣는다」 다. `framing-ledger.md` 는 두 worktree 어디에도 없다(Glob 0건)."
    touches: []
    decides: []
  - id: RC29
    path: "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "## 미룸 (표 전체)"
    line: 628
    claim: "(team-file-contract 판) 미룸 표의 받는 곳별 정리. R2: 새 형식을 `create` 기본으로 켜기 · 보내는 글 틀을 시작 묶음으로 · 마지막 보고 규칙을 결과 파일로 / 단계 이름 · 단계마다 읽을 것 · 단계와 역할 대응 · 관문 다섯 칸 · 검수 두 번 / 도구로 막기 / 리더가 첫 설계 제안 전에 원자료 대응표부터 만들기 / 에픽 세션 따로 띄우기 · 끝낸 담당자 다시 깨우지 않기 / 분해 승인 화면과 `original` 부르기 / 도는 로드맵 없을 때 단순 작업의 자리 / 규칙 골라 싣기 · 묶음 예산(B17) / 스크립트 · 다른 모델(codex) 한곳으로(D1.2) / 리뷰어 프로필 과제 파일 모드 / 구현 중 리뷰에 REVIEW.md 잇기 / 「대장은 상주 하나 · 등록만 하고 직접 만들지 않는다 · 마지막 판정은 대장」. R3: 같은 팀 안 세션 메시지 / 리더 상태 브랜치 · 대기 줄 꼴 · 읽을 ref / 과제 폴더 없는 작업 행 알리기 / STATUS.md · inbox/ 내용과 계약. R4: mod 표시 / 「멈추면 세션 밖으로 알린다(메일)」. R5: 옛 묶음 · 설계문서 지휘 기록 · 도는 로드맵 이전과 로드맵 폴더 옮기기(B16) / brief · audit 를 `intent/` 에 바로 쓰기 · `source_interview` 키 이름. quality-gates 가 REVIEW.md 를 읽게 하기는 「이 로드맵 밖」 이다(56행)."
    touches: []
    decides: []
  - id: RC30
    path: "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "## 인터뷰와 달라진 것 — D33 행"
    line: 513
    claim: "(team-file-contract 판 · 문서 사이 어긋남) roadmap.md R1 범위와 R1 묶음 §7 은 「시작 묶음 고르기 스크립트」 를 R1 이 만들고 넘긴다고 적는다(roadmap.md 28행 · R1.md 242행). 설계는 고르기를 미루고 시작 묶음이 규칙을 통째로 싣게 했다(B17 「통째로 싣고 고르기는 미룬다」 · AC22). 켜는 판단은 R2 로 넘겼다(644행). 로드맵 블록 문면은 고쳐지지 않았다."
    touches: []
    decides: []
  - id: RC31
    path: "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "## 원문 대조 — 원자료:"
    line: 463
    claim: "(team-file-contract 판) 설계의 원문 대조는 framing audit(docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.audit.md)의 원문 절 줄 범위 — my-team 구조 23–57행 · 규칙 목차 글 75–87행 · 영상 구조 121–176행 — 를 기준으로 삼는다. main 판의 그 audit 에서 `my-team/` 은 24행, `MEMORY.md - 한 줄에 규칙 하나` 는 76행, `pipeline/` 나무는 137–139행, `## 2. 질문 전체` 는 184행이어서 범위가 실물과 맞는다. 설계문서 frontmatter `source_interview:` 는 R1.md 묶음 경로, `next_phase:` 는 `superpowers:writing-plans` 다(5–7행)."
    touches: []
    decides: []

  # ── 설계 · 로드맵 문면이 가리키는 구현 (main 판) ──
  - id: RC32
    path: "plugins/spec-distill/scripts/repo_defaults.py"
    anchor: "KEYS · ROADMAP_META_KEYS = (\"type\", \"source_brief\")"
    line: 36
    claim: "`interview_dir` 설정 키는 repo_defaults.py 의 KEYS · _FOLDER_KEYS · _DEFAULTS 에 살고 `check-path` 의 선택지에도 있다(545행). 이 파일은 R2 예약이다. 로드맵 머리말 허용 키는 `type` · `source_brief` 둘뿐이어서 설계 §13 의 「`layout` 을 모르는 키로 거절한다」 는 진술과 맞는다. `interview_dir` 글자는 plugins 아래 21개 파일에 119번 나오며 그 가운데 state_path.py · control_plane.py(R3 예약) · repo_defaults.py(R2 예약) · README.md(R4 예약)를 뺀 skills/request-framing/SKILL.md · skills/pm-interview/SKILL.md · finishing.md · interview_state.py 와 테스트들은 예약한 에픽이 없다."
    touches: []
    decides: []
  - id: RC33
    path: "plugins/spec-distill/scripts/roadmap_status.py"
    anchor: "find_specs"
    line: 325
    claim: "`source_interview` 를 읽는 구현은 roadmap_status.py `find_specs`(336 · 680행) · spec_review_bundle.py(73–77행, 없거나 다르면 거절) · check_bundle_coverage.py(132행)이고 찍는 쪽은 roadmap_render.py 336행이다 — 넷 다 R1 예약이다. 이 글자는 plugins 아래 24개 파일에 65번 나오며 references/conducting.md(R2 예약) · references/epic-handoff.md(R1 예약) 밖의 skills/spec-review/SKILL.md · references/docreview-profiles/design-doc.md · finishing.md · references/roadmap-ontology.md 는 예약한 에픽이 없다."
    touches: []
    decides: []
  - id: RC34
    path: "plugins/spec-distill/references/epic-handoff.md"
    anchor: "**에픽 넘김 줄**"
    line: 5
    claim: "지금의 에픽 넘김 글은 묶음 절대경로를 첨부해 `superpowers:brainstorming` 을 열고 「설계문서 frontmatter source_interview 에 <bundle-rel> 을, roadmap 에 <roadmap-rel> 을 적는다」 · 「묶음의 모든 번호 … 를 번호째 설계의 입력으로 읽는다」 를 지시한다. 사용자 원자료(framing audit)를 읽으라는 지시나 원문 대조 표 지시는 없다. 3행은 이 줄이 pm-interview finishing.md 의 B-3 「다음 세션 줄」 과 같은 모양이라고 적는다. R1 예약 파일이다."
    touches: []
    decides: []
  - id: RC35
    path: "plugins/spec-distill/skills/pm-interview/references/finishing.md"
    anchor: "payload frontmatter: `type: interview-brief`, `next_phase: superpowers:brainstorming`"
    line: 76
    claim: "인터뷰 끝의 넘김은 finishing.md 가 쥔다. brief 는 `interview_dir` 아래 `<YYYY-MM-DD>-<kebab-topic>-interview.md` 이고 기본 `next_phase` 는 `superpowers:brainstorming` 이다(74–76행). 분해된 일은 229행이 `roadmap_write.py create --brief` 를 부르고, 556행은 로드맵 에픽의 설계를 여는 줄이 epic-handoff.md 의 에픽 넘김 줄이라고 가리킨다. brief 가 `interview_dir` 바로 아래가 아니면 커밋하지 않는다(588 · 606행). 이 파일은 로드맵의 어느 에픽 예약에도 없다."
    touches: []
    decides: []
  - id: RC36
    path: "docs/superpowers/interview/2026-11-14-framing-interview-constraint-audit-interview.md"
    anchor: "인터뷰를 의도 싱크로 바꾸는 이름 바꾸기는 이 일에 합친다. (사용자 확인)"
    line: 13
    claim: "받는 쪽(이 worktree 의 seed)도 같은 넘김을 적는다 — 「이름 바꾸기는 옆 세션이 자기 로드맵에 에픽으로 더하지 않고 이 일로 넘긴 것이다」. 설계문서 B13 · Handoff Context 의 「다른 로드맵으로 넘겼다」 와 방향이 맞고, 미룸 표 649행의 받는 곳 R5 와는 맞지 않는다(RC23)."
    touches: []
    decides: []

unanswered: "framing-ledger.md(F 번호 원자료 대조표와 에픽별 넘김 목록)가 두 worktree 어디에도 없어 R2–R5 몫 넘김 목록의 실제 내용은 확인하지 못했다. 그 밖에 레포가 답하지 못한 것은 아래 목록이다."
```

레포가 답하지 못한 부분:
- **철학 문서 · CLAUDE.md 의 새 문면**: R2 묶음 OQ24 가 열려 있어 정해진 것이 없다. Law 1 의 가벼운 꼴 · trivia escape 를 작은 일의 길과 어떻게 맞출지는 로드맵 · 묶음 · 설계 어디에도 문장이 없다.
- **인터뷰 폴더 이름과 `interview_dir` 의 앞날**: 정한 문서가 없고 예약한 에픽도 없다.
- **token-baseline.md**: P1 산출물이자 설계 Context 가 가리키는 파일인데 두 worktree 모두에 없다. 설계는 PR #275 로 적는다.

읽을 때 주의할 점:
- 설계문서는 승인 전 판이다.
- roadmap.md 의 결정 기록과 재분해 이력은 설계가 바꾼 것(B1–B17 · D1.1 · D1.2 · 재분해 신호 넷)을 하나도 반영하지 않았다.

서로 어긋난 자리 다섯 (양쪽을 그대로 실었다):
1. **`intent/` 의 내용** (RC17): 설계 §1 은 「원자료 · brief」 로, §3 은 `original.md` 와 `README.md` 만으로 적는다.
2. **`source_interview` 와 `intent/` 에 바로 쓰기의 받는 곳** (RC23 · RC36): 미룸 표는 R5, 같은 문서의 Non-goals · §3 · §12 · Handoff Context 와 받는 쪽 seed 는 이름 바꾸기 로드맵이다.
3. **인터뷰 끝맺음 절차 고침** (RC20): 설계는 R2 로 넘기지만 R2 경로 예약에 finishing.md 가 없다.
4. **C50** (RC13 · RC27): 설계의 재분해 신호 ④ 는 R2 묶음에 없다고 하지만 R2.md ids 와 §2 에 이미 있다. S50 만 없다.
5. **시작 묶음 고르기 스크립트** (RC30): 로드맵 R1 범위와 R1 묶음 인터페이스는 R1 이 만든다고 적고, 설계 B17 은 미뤘다.
~~~~

### 조사 3 — open-researcher · R1 · 묶음 1

~~~~
확인한 날: 2026-11-14. 레포가 기록한 판은 claude-code 2.1.303(2026-10-22), `model` 키 규칙의 실측 판은 CLI 2.1.261(2026-09-06), 최신 upstream 은 2.1.325(2026-11-13)다.

읽을 때 주의 둘:
- WebFetch 는 작은 모델을 거친다. 페이지 원문이 통째로 돌아온 곳(manifest-reference · components · loading · dependencies · platform skill best-practices · memory · best-practices)은 원문 인용이다. sub-agents · skills · model-config · settings-reference · hooks · changelog · plugin-dev raw 파일은 요약 모델이 뽑아 준 인용이라 한 단계 간접이고, 일부 페이지는 10만 자에서 잘렸다.
- `supports` 는 `current` = 레포 서술과 같은 자리, `alternative` = 다른 자리, `both` = 일부 같고 일부 다름으로 썼다.

## 세 갈래 요약

**같은 자리**
- `model` 해석 순서: dispatch 인자 → frontmatter `model`(`inherit` 포함) → `CLAUDE_CODE_SUBAGENT_MODEL` → 세션 모델. 레포 문장 · 실측 F1–F4 와 일치한다.
- agent 의 `tools` 는 allowlist, `disallowedTools` 는 denylist 이고, camelCase 가 정확히 맞아야 하며 모르는 필드는 오류 없이 무시된다.
- skill 의 `allowed-tools` 는 제한이 아니라 사전 허용이다.
- command 는 옛 형식이고 새 것은 skill 로 쓴다. `!` 사전 실행은 skill 기능이다.
- `plugin.json` 의 `version` 을 안 올리면 사용자는 캐시본에 머문다.
- `scripts/` 는 관례일 뿐이다.
- skill 본문은 "State what to do rather than narrating how or why" — Self-narrating artifact 금지와 같은 방향이다.
- 이름: gerund 권장, `helper` · `utils` 회피, "I can help you" 회피.
- 꼭 지켜야 하는 규칙은 CLAUDE.md 가 아니라 hook 으로.

**다른 자리**
- 공식 문서는 `model` 키를 금지하지 않는다. 공식 예시가 플러그인 agent 에 `model: sonnet`, 일반 예시에 `model: inherit` 를 쓴다.
- 공식 플러그인 `plugin-dev:agent-development` 는 `model` 을 required 로, `inherit` 를 recommended 로 적는다. 공식 문서(필수는 `name` · `description` 뿐)와도, 레포 규칙과도 어긋난다.
- `plugin.json` 의 필수는 `name` 하나이고 manifest 자체가 선택이다. 레포는 `name` · `description` · `version` 을 필수로 둔다.
- `integrity` 는 공식 필드 표에 없다. 모르는 최상위 키는 벗겨지고 validate 가 경고한다.
- 플러그인 간 의존은 공식적으로 `plugin.json` `dependencies`(semver 범위)다. 레포는 `dependencies.md` 표를 쓴다.
- `cost_class` 같은 사용자 키의 공식 자리는 `metadata` 맵이다. 최상위 미인식 키는 Claude Code 에서 조용히 무시되고, claude.ai 업로드 · Skills API · `package_skill.py` 에서는 hard error 다.
- skill 에는 실제로 도구를 빼는 `disallowed-tools` 가 있다. 레포 CLAUDE.md 는 언급하지 않는다.
- hook 을 끄는 공식 수단은 `disableAllHooks` 설정뿐이다. 환경변수 kill switch 는 공식 문서에 없다.
- 플러그인 지속 데이터의 공식 자리는 `${CLAUDE_PLUGIN_DATA}` 다. 레포는 프로젝트의 `.claude/<plugin>/` 을 쓴다.
- 공식 표준 레이아웃에는 레포 트리에 없는 `commands/` · `output-styles/` · `workflows/` · `themes/` · `monitors/` · `bin/` · `.mcp.json` · `.lsp.json` 이 있다.
- 플러그인 agent 에서 무시되는 필드는 `permissionMode` · `hooks` · `mcpServers` · `initialPrompt` 다.

**공식 문서에 없는 자리 (devbrew 고유)**
- README 필수 · "Principles Instantiated" · CHANGELOG 규칙
- `templates/` · `tests/` 디렉토리
- 처분 앵커
- SessionStart read-only 규칙
- 진입 skill 「kebab 두 단어 이상」 규칙
- dispatch 인자를 게이트 판정 agent 에 넘기지 말라는 규칙
- 모든 PR 마다 SemVer bump 의무 (공식은 version 문자열을 semver 로 검사하지 않는다)

```yaml
evidence:
  # ── 3. subagent frontmatter · model ──
  - url: "https://code.claude.com/docs/en/sub-agents"
    supports: current
    claim: >
      'Choose a model' 절의 순서: "When more than one source sets a model, Claude Code uses the first in this order:
      1. The per-invocation `model` parameter ... 2. The `model` field in the subagent's definition, including `inherit`
      3. The `CLAUDE_CODE_SUBAGENT_MODEL` environment variable 4. The main conversation's model".
      레포의 「`inherit` 는 CLAUDE_CODE_SUBAGENT_MODEL 을 덮어쓴다 · 키가 없으면 사용자 설정 → 세션 모델」과 같다.
      기본값: "By default, a subagent you define runs on the same model as the conversation that starts it."
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "CLI 2.1.261 실측(2026-09-06) · dependencies.md 기록 2.1.303(2026-10-22)", latest: "2.1.325 (2026-11-13)"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/env-vars"
    supports: current
    claim: >
      CLAUDE_CODE_SUBAGENT_MODEL 행 원문: "Two sources take precedence over it: a model Claude passes when it spawns the agent,
      and a `model` field in the agent's definition, including `inherit`. ... Setting it to `inherit` is the same as leaving it unset.
      Before v2.1.251, this variable overrode both the per-invocation model and the definition's `model` field".
      레포 실측 판 2.1.261 은 2.1.251 이후라 지금 문서의 순서와 같은 동작 구간이다.
      CLAUDE_CODE_SUBAGENT_MODEL_FORCE 행: "Set to `1` to force one model onto subagents, teammates, and workflow agents ... Requires Claude Code v2.1.257 or later".
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.261 실측 · 2.1.303 기록", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/sub-agents"
    supports: both
    claim: >
      `model` 값은 "Model alias: `sonnet`, `opus`, `haiku`, or `fable`" · "Full model ID" · "`inherit`". 레포 문장은 리터럴 티어를 opus/sonnet/haiku 셋만 든다.
      dispatch 인자: "On an Agent tool call, the parameter takes a model alias, not a full model ID or `inherit`."
      FORCE: "While `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` is on, Claude Code ignores the `model` field in subagent definitions, and Claude can't pass a model when it starts a subagent."
      레포 spec 이 미실측으로 남긴 U1(dispatch 인자가 환경변수보다 우선) · U2(FORCE 가 dispatch 인자를 막음)에 대해 문서는 이렇게 적는다. 실측은 아니다.
      "Setting `CLAUDE_CODE_SUBAGENT_MODEL` by itself doesn't change the model the built-in Explore and Plan subagents run on."
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.261 실측 · 2.1.303 기록", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/sub-agents"
    supports: both
    claim: >
      지원 frontmatter 필드(요약 모델이 뽑은 표): name · description(이 둘만 필수) · tools · disallowedTools · model · permissionMode · maxTurns ·
      autoCompactWindow(v2.1.296+) · skills · mcpServers · hooks · memory · background · omitClaudeMd(v2.1.271+) · effort · isolation · color ·
      initialPrompt · experimental(cacheTtl, v2.1.248+).
      "Multi-word field names use camelCase, such as `maxTurns` and `disallowedTools`, and must match the table exactly:
      Claude Code ignores a field it doesn't recognize without reporting an error."
      "To restrict tools, use the `tools` field as an allowlist or the `disallowedTools` field as a denylist. If both are set,
      `disallowedTools` is applied first, then `tools` is resolved against the remaining pool."
      `tools` 생략 시 "Inherits every tool available to subagents".
      같은 자리: 도구를 가르는 필드는 tools/disallowedTools 둘, camelCase 오기는 조용히 무시.
      레포에 없는 것: 요약 표는 v2.1.296 부터 debug 로그가 미인식 필드를 보고한다고 적었다(원문 미확인). disallowedTools 의 specifier(`Bash(git push *)`)는 도구 전체를 뺀다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 기록", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/components"
    supports: both
    claim: >
      'Frontmatter fields in plugin agents' 원문: "Supported fields: `name`, `description`, `model`, `effort`, `maxTurns`, `autoCompactWindow`,
      `tools`, `disallowedTools`, `skills`, `memory`, `background`, `omitClaudeMd`, `isolation`, `color`, and the `cacheTtl` key of `experimental`."
      "Ignored fields: `permissionMode`, `hooks`, `mcpServers`, and `initialPrompt`."
      "Frontmatter that doesn't parse: the agent still loads with every field ignored."
      같은 페이지의 플러그인 agent 예시는 frontmatter 에 `model: sonnet` 을 쓴다.
      공식 문서는 플러그인 agent 의 `model` 을 지원 필드로 싣고 금지 · 비권장 문구가 없다. 레포의 `model` 키 금지는 공식 권고가 아니라 devbrew 정책이다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 기록", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/plugin-dev/skills/agent-development/SKILL.md"
    supports: alternative
    claim: >
      공식 플러그인 plugin-dev 의 agent-development skill 은 헤딩을 "### name (required)" · "### description (required)" ·
      "### model (required)" · "### color (required)" · "### tools (optional)" 로 두고, `inherit` 를 "(recommended)" 로,
      "Use `inherit` unless agent needs specific model capabilities" 로 적는다(요약 모델 경유).
      공식 문서(필수는 name · description 뿐, inherit 는 환경변수보다 앞선다)와도, 레포 규칙(`model` 키를 두지 않는다)과도 다르다.
      레포 `docs/plugin-authoring.md` 는 구현 단계에 이 skill 을 로드하라고 적는다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "레포에 plugin-dev 판 기록 없음", latest: "plugin-dev plugin.json 0.1.2 · skill frontmatter version 0.1.0 (요약 모델 경유)"}
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/sub-agents"
    supports: alternative
    claim: >
      `tools` 행: "If no entry in the list resolves to a tool, the subagent usually fails to launch with an error naming the entries."
      'Restrict which tools' 절: "When nothing in the `tools` list resolves to a tool, for example because every entry is misspelled or names a tool
      that isn't available to subagents, Claude Code usually refuses to launch the subagent".
      레포에는 `tools: []` 인 agent 가 둘 있다. 명시적 빈 목록이 이 거절에 드는지는 공식 문서에서 확인하지 못했다(errors 페이지의 해당 절이 잘린 범위 밖).
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 기록", latest: "2.1.325"}
    certainty: uncertain
  - url: "https://claudeissues.com/issue/82562-subagent-with-tools-is-listed-to-its-parent-as-tools-all-tools"
    supports: current
    claim: >
      2차 자료(GitHub 이슈 미러, 검색 요약으로만 확인): 빈 `tools: []` 는 spawn 에서 받아들여지고 zero-tools 거절은 적힌 항목이
      아무것으로도 해석되지 않을 때만 난다. 다만 그런 agent 가 부모에게 "(Tools: All tools)" 로 표시된다는 보고다.
    touches: []
    decides: []
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/settings-reference"
    supports: current
    claim: >
      settings 키 색인(advisorModel … wslInheritsWindowsSettings)에 subagent 기본 모델을 정하는 키가 없다. agent 관련 키는 agent ·
      agentPushNotifEnabled · disableAgentView · subagentPromptCacheTtl · strictPluginOnlyCustomization.agents 다섯이다.
      레포 spec F5(「`subagentModel` settings 키는 동작하지 않는다」)와 어긋나지 않는다. 색인 표만 확인했고 상세 절은 잘렸다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.261 실측", latest: "2.1.325"}
    certainty: uncertain

  # ── 1. 플러그인 구조 · plugin.json · command 대 skill ──
  - url: "https://code.claude.com/docs/en/plugins/manifest-reference"
    supports: alternative
    claim: >
      "The manifest is optional." · "`name` is the only required key." · `version`: "A version string, not checked against semver."
      `claude plugin validate` 는 "a missing `version`, `description`, or `author`" 를 경고로 낸다(`--strict` 면 실패).
      레포 CLAUDE.md 는 name · description · version 을 필수로, SemVer bump 를 의무로 둔다. 공식 최소보다 엄격한 devbrew 정책이다.
      (/plugins-reference 로 요청한 주소가 이 'Plugin manifest reference' 페이지를 돌려줬다.)
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 기록", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/manifest-reference"
    supports: alternative
    claim: >
      Fields 표의 최상위 키: $schema · name · displayName · version · description · author · homepage · repository · license · keywords ·
      metadata · icon · documentationUrl · supportUrl · privacyPolicyUrl · termsOfServiceUrl · defaultEnabled · dependencies · userConfig ·
      types · channels · skills · commands · agents · hooks · mcpServers · lspServers · outputStyles · workflows · experimental(themes · monitors · evals).
      `integrity` 는 표에 없다. "Top-level fields: the field is stripped and the plugin loads. `claude plugin validate` reports each
      unrecognized top-level field as a warning". 사용자 데이터 자리는 `metadata`("Free-form object for your own data. Claude Code doesn't read it").
      레포 CLAUDE.md 의 「optional `integrity` field 로 pin」은 공식 필드 표에 대응이 없다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 기록", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/manifest-reference"
    supports: both
    claim: >
      'Standard layout' 의 기본 위치: `.claude-plugin/plugin.json`(Optional) · `skills/` · `commands/`("Flat Markdown command files.
      Prefer `skills/` for new plugins") · `agents/` · `hooks/hooks.json` · `.mcp.json` · `.lsp.json` · `output-styles/` · `workflows/` ·
      `themes/` · `monitors/monitors.json` · `bin/`.
      같은 자리: skills/ · agents/ · hooks/ · .claude-plugin/plugin.json.
      레포 트리에 없는 공식 자리: commands/ · output-styles/ · workflows/ · themes/ · monitors/ · bin/ · .mcp.json · .lsp.json.
      공식에 없는 레포 자리: README.md(필수) · CHANGELOG.md · templates/ · tests/.
      "A `CLAUDE.md` at the plugin root isn't loaded as context, and `claude plugin validate` warns when it finds one.
      To include instructions that load into Claude's context, put them in a skill."
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 기록", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/components"
    supports: current
    claim: >
      command 의 지위: "Commands are the older format, and skills supersede them for new work. ... Keep `commands/` for files you're moving
      over from `.claude/commands/`." · "write new ones as skills and keep `commands/` for files you already have" ·
      "Command files take the same frontmatter as skills."
      scripts/: "The name `scripts/` is a convention, not something Claude Code looks for".
      레포의 「새 command 파일은 만들지 않는다」 · 「scripts/ optional」과 같다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 기록", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/manifest-reference"
    supports: both
    claim: >
      manifest 의 `commands` 객체 맵 항목은 `source` | `content` · `description` · `argumentHint` · `model` · `allowedTools`
      ("Tools the command may use without prompting")를 받는다. camelCase `allowedTools` 는 plugin.json 의 commands 맵 안에서는 실재 키다.
      레포 CLAUDE.md 의 「agent 에 camelCase 로 옮겨 적으면 존재하지 않는 필드」는 agent frontmatter 에 한해 공식 문서와 같다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 기록", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/loading"
    supports: both
    claim: >
      'Versions and updates': 판 계산 순서는 manifest `version` → marketplace entry `version` → 소스 종류별(git 은 commit SHA 12자).
      "a manifest that pins `\"version\": \"1.0.0\"` keeps every user on the cached copy until its author changes the string, however many
      commits they push. To let users track commits instead, leave `version` out of both the manifest and the entry." · "The version also names the plugin's cache directory."
      같은 자리: bump 하지 않으면 캐시가 낡는다. 다른 길: version 을 비워 commit 을 따라가게 하는 선택지를 공식 문서가 함께 든다.
      예외: 로컬 경로로 더한 marketplace 의 상대경로 플러그인은 in-place 로 읽혀 "you don't need to increase the version".
      "Files outside the plugin directory aren't copied, so when a script inside a copied plugin reads a path above the plugin root,
      such as `../shared`, it doesn't find them" — 레포의 「설치본에서 다른 플러그인의 스크립트는 도달 불가」와 같은 방향이다.
      이전 판 디렉토리는 `.orphaned_at` 표시 뒤 14일 후 정리된다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 기록", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/dependencies"
    supports: alternative
    claim: >
      플러그인 간 의존의 공식 자리는 plugin.json `dependencies` 배열이다: `"name"` · `"name@marketplace"` ·
      `{name, version, marketplace}`. version 은 semver 범위(`~2.1.0` · `^2.0` · `>=1.4` · `=2.1.0`)이고 `<plugin-name>--v<version>` git 태그로 해석된다.
      범위를 못 맞추면 의존하는 플러그인이 disabled 된다. `integrity` · 해시 핀 필드는 이 페이지에 없다.
      레포는 최소 판을 `dependencies.md` 표와 `check_deps.py` 로 다룬다. 공식 장치와 다른 자리다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 기록", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/components"
    supports: alternative
    claim: >
      지속 데이터: "`${CLAUDE_PLUGIN_ROOT}` ... the path changes when the plugin updates. Don't write state there" ·
      "`${CLAUDE_PLUGIN_DATA}`: a directory that survives updates ... resolves to `~/.claude/plugins/data/<id>/`".
      프로젝트 안 `.claude/<plugin>/` 에 런타임 state 를 두라는 공식 서술은 찾지 못했다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 기록", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/hooks"
    supports: both
    claim: >
      "To temporarily disable all hooks without removing them, set `\"disableAllHooks\": true` in your settings file." ·
      "There is no way to disable an individual hook while keeping it in the configuration."
      환경변수 kill switch 관례는 공식 문서에 없다. `DEVBREW_<PLUGIN>_DISABLE` · `DEVBREW_SKIP_HOOKS` 는 devbrew 고유다.
      "When an event fires, its matching hooks run in parallel." — 레포의 「같은 event 내 훅은 교환 가능해야 함」과 맞는다.
      SessionStart 가 read-only 여야 한다는 서술은 확인한 범위에 없다(페이지가 10만 자에서 잘림).
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 기록", latest: "2.1.325"}
    certainty: uncertain

  # ── 2. skill 저술 ──
  - url: "https://code.claude.com/docs/en/skills"
    supports: current
    claim: >
      "Keep `SKILL.md` under 500 lines. Move detailed reference material to separate files." ·
      "Keep the body itself concise. Once a skill loads, its content stays in context across turns, so every line is a recurring token cost.
      State what to do rather than narrating how or why, and apply the same conciseness test you would for CLAUDE.md content."
      레포 Forbidden Patterns 의 Self-narrating artifact(산출물에 출처 · 배경 · 정당화를 담지 않는다)와 같은 방향이다.
      이유 · 이력 서술에 대한 공식 언급은 이 한 문장이다. 「이력」을 직접 겨눈 문구는 Claude Code skills 페이지에 없다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 기록", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/skills"
    supports: both
    claim: >
      frontmatter 키: name · description · when_to_use · argument-hint · arguments · disable-model-invocation · user-invocable ·
      allowed-tools · disallowed-tools · model · effort · context · agent · background · hooks · paths · shell · metadata · license · compatibility.
      "All fields are optional. Only `description` is recommended ... Claude Code ignores a field it doesn't recognize without reporting an error."
      `metadata`: "Free-form YAML map for your own key-value data ... Claude Code doesn't act on its contents".
      Claude Code 밖(claude.ai 업로드 · Skills API · `package_skill.py`)은 name · description · license · compatibility · metadata · allowed-tools 만 받고
      "packaging or upload fails with a hard error instead of ignoring the field".
      레포의 최상위 `cost_class` 는 Claude Code 에서 조용히 무시되는 미인식 키다. 공식이 사용자 데이터에 두는 자리는 `metadata` 다.
      `user-invocable: false` · `disable-model-invocation` 은 실재 키로 레포 쓰임과 같다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 기록", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/skills"
    supports: both
    claim: >
      `allowed-tools`: "grants permission for the listed tools during the turn that invokes the skill ... The grant clears when you send your
      next message ... It does not restrict which tools are available: every tool remains callable, and your permission settings still govern tools that are not listed."
      레포의 「`allowed-tools` 는 제한이 아니다」와 같다.
      레포가 다루지 않는 것: `disallowed-tools` — "Tools removed from Claude's available pool while this skill is active ... The restriction clears when you send your next message."
      skill 계층에도 실제로 도구를 빼는 키가 있다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 기록", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/skills"
    supports: current
    claim: >
      "Custom commands have been merged into skills. A file at `.claude/commands/deploy.md` and a skill at `.claude/skills/deploy/SKILL.md`
      both create `/deploy` and work the same way. Your existing `.claude/commands/` files keep working." · "Prefer a skill for new work".
      `` !`<command>` `` 는 skill 본문이 Claude 에게 가기 전에 실행되고 "A failed command aborts the entire skill invocation."
      플러그인 skill 이름: `my-plugin/skills/review/SKILL.md` → `/my-plugin:review`. frontmatter `name` 은 마지막 조각만 바꾼다.
      레포의 「사전 단계는 진입 skill 의 `!` 로」 · 「디렉토리 이름 = name」 · `/plugin:name` 완전명과 맞는다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 기록", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/skills"
    supports: both
    claim: >
      목록 예산: description + when_to_use 는 skill 당 1,536자에서 잘린다. 전체 목록 예산은 "1% of the model's context window" 이고, 넘치면 덜 쓰는 skill 의 설명부터 뺀다.
      수명: 불린 SKILL.md 는 한 메시지로 들어가 남고 "Claude Code does not re-read the skill file on later turns".
      compaction 뒤에는 skill 당 앞 5,000 토큰, 합계 25,000 토큰만 다시 붙는다 — "put the most important instructions near the top of `SKILL.md`".
      레포 두 파일에는 이 수치에 대응하는 서술이 없다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 기록", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices"
    supports: both
    claim: >
      "Keep the `SKILL.md` body under 500 lines" · "Only add context Claude doesn't already have. Challenge each piece of information" ·
      "Keep references one level deep from `SKILL.md`" · "For reference files longer than 100 lines, include a table of contents at the top" ·
      "Avoid time-sensitive information"(옛 방식은 접힌 'Old patterns' 절로).
      이름: "Consider using gerund form" · "Avoid: Vague names: `helper`, `utils`, `tools`". 설명은 3인칭 — "Avoid: \"I can help you process Excel files\"".
      name ≤64자, 소문자 · 숫자 · 하이픈, 예약어 anthropic · claude 금지. description ≤1,024자.
      같은 자리: 레포의 gerund(내부 skill) · helper/utils/"I can help you..." 금지.
      다른 자리: 공식은 gerund 를 전체에 권하고 명사구 · 동사형을 "Acceptable alternatives" 로 둔다. 레포는 진입 skill 을 「kebab 두 단어 이상」으로 따로 정한다.
      목차 문턱은 공식 100줄(reference 파일), 레포 ~300줄(docs 문서)로 대상이 다르다. description 상한도 표면마다 다르다(platform 1,024자 · Claude Code 목록 1,536자).
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/plugin-dev/skills/skill-development/SKILL.md"
    supports: alternative
    claim: >
      공식 플러그인 plugin-dev 의 skill-development 는 길이를 낱말 수로 잡는다: "Target 1,500-2,000 words for the body" ·
      "Keep under 3,000 words" · checklist "<5k max". 3단 공개(metadata ~100 words / body <5k words / bundled resources).
      "Information should live in either SKILL.md or references files, not both." 명령형으로 쓰고 2인칭을 피한다.
      공식 문서의 500줄 기준과 단위 · 수치가 다르다(요약 모델 경유).
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "레포에 plugin-dev 판 기록 없음", latest: "skill frontmatter version 0.1.0"}
    certainty: uncertain
  - url: "https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/plugin-dev/skills/plugin-structure/SKILL.md"
    supports: alternative
    claim: >
      plugin-dev 의 plugin-structure skill 은 plugin.json 필수를 name 하나로 적는다(공식 문서와 같고 레포 정책과 다르다).
      commands 를 옛 형식으로 표시하지 않고 "integrate as native slash commands" 로 소개한다. 공식 문서의 "older format" 과 어긋난다(요약 모델 경유).
      트리 주석은 plugin.json 을 "Required: Plugin manifest" 로 적는다. 공식 문서는 "The manifest is optional" 이다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "레포에 plugin-dev 판 기록 없음", latest: "skill frontmatter version 0.1.0"}
    certainty: uncertain

  # ── 4. CLAUDE.md · 메모리 저술 ──
  - url: "https://code.claude.com/docs/en/memory"
    supports: both
    claim: >
      "Size: target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence." ·
      "Imports help you organize a long file but don't reduce its context cost" ·
      "Keep it to facts Claude should hold in every session: build commands, conventions, project layout, \"always do X\" rules.
      If an entry is a multi-step procedure or only matters for one part of the codebase, move it to a skill or a path-scoped rule instead." ·
      "Consistency: if two instructions contradict each other, Claude may pick one arbitrarily." ·
      "Claude treats CLAUDE.md files as context, not enforced configuration" ·
      "CLAUDE.md content is delivered as a user message after the system prompt" ·
      "Block-level HTML comments ... are stripped before the content is injected".
      Auto memory: "The first 200 lines of `MEMORY.md`, or the first 25KB, whichever comes first, are loaded at the start of every conversation."
      `/doctor prompt-audit`(v2.1.283+)가 낡은 · 충돌하는 지시를 찾는다. 길이 초과 파일은 시작 때와 `/status` 에서 경고가 뜬다.
      레포 CLAUDE.md 는 103줄로 줄 수 기준 안이다. 줄당 길이가 길어 바이트 기준 경고에 드는지는 재지 않았다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 기록", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/best-practices"
    supports: both
    claim: >
      'Keep CLAUDE.md short': "the file works best when it only holds what Claude couldn't work out from the code itself" —
      확인 명령 · 코드가 오도하는 자리 · 레포에 없는 결정 · "Anything you've had to correct twice already".
      "If Claude keeps ignoring a line that is in `CLAUDE.md`, adding IMPORTANT probably won't fix it." ·
      "If something has to happen every time, make it a hook, a deny rule, or a managed setting. `CLAUDE.md` is for guidelines" ·
      "The `CLAUDE.md` rule applies to skills too: only write down what Claude can't find on its own."
      'What you can stop doing' 표: "Add IMPORTANT or ALL CAPS ..." 는 내려놓을 옛 조언. "Describe your architecture and file layout in `CLAUDE.md` | Claude reads the repo itself. Only write down what isn't in there."
      같은 자리: 레포의 「결정론은 보안 · 정확성 게이트에만」 · 훅 · 락으로 집행하는 구조.
      어긋나는 문장 둘: memory 페이지는 CLAUDE.md 에 "project layout" 을 넣으라 하고, best-practices 는 file layout 을 적지 말라 한다. 공식 문서 안의 충돌로 둘 다 보고한다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 기록", latest: "2.1.325"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/sub-agents"
    supports: current
    claim: >
      subagent 시작 때: CLAUDE.md 계층 전부가 실린다(내장 Explore · Plan 과 `omitClaudeMd` 는 예외). 주 대화의 auto memory 는 "isn't loaded".
      agent description 합계가 15,000 토큰을 넘으면 시작 경고가 뜬다 — "Trim the `description` fields ... move detail into each subagent's system prompt".
      Best practices: "Design focused subagents" · "Limit tool access: grant only necessary permissions for security and focus".
      레포의 「모든 agent 는 `tools:` allowlist」와 같은 방향이다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 기록", latest: "2.1.325"}
    certainty: confirmed

  # ── 판 ──
  - url: "https://code.claude.com/docs/en/changelog"
    supports: both
    claim: >
      최신 판 2.1.325(2026-11-13). 그 아래 2.1.323(11-12) · 2.1.322(11-10) · 2.1.321(11-09) · 2.1.319(11-06).
      2.1.325: "Fixed subagents with their own model being moved to the plan-mode model when the model setting is `opusplan` or `haiku`" ·
      "Changed scheduled tasks and `/loop` to ask before running a skill that declares `allowed-tools` or hooks".
      2.1.323: "Deprecated a plugin's `agent` setting" · "Fixed a slash command's `allowed-tools` grants applying to background agents woken during or after its turn".
      레포 기록 판 2.1.303 과 22 patch 차이다. 2.1.304–2.1.325 사이에 model 해석 순서를 바꾼 항목은 읽은 범위(changelog 앞 10만 자)에서 찾지 못했다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 (2026-10-22 기록)", latest: "2.1.325 (2026-11-13)"}
    certainty: uncertain

repo_claims:
  - id: RC1
    path: "docs/plugin-authoring.md"
    anchor: "**agent frontmatter 에 `model` 키를 두지 않는다.**"
    line: 22
    claim: >
      리터럴 티어(opus/sonnet/haiku)는 세션의 모델 선택을 덮어쓰고 `inherit` 는 `CLAUDE_CODE_SUBAGENT_MODEL` 을 덮어쓴다 —
      「CLI 2.1.261 실측(2026-09-06)」. 키가 없으면 「사용자 설정 → 세션 모델」 순으로 위임한다.
      금지의 근거는 P8(Determinism Economy)로 적혀 있다. 공식 권고를 근거로 들지 않는다.
    touches: []
    decides: []
  - id: RC2
    path: "docs/plugin-authoring.md"
    anchor: "**dispatch 시점의 `model` 인자는 오케스트레이터의 재량이다.**"
    line: 23
    claim: >
      dispatch 인자로 티어를 고를 수 있으나, 게이트 판정 · 측정에 들어가는 agent 에는 넘기지 않는다(Law 2 취지).
      공식 문서는 dispatch 인자가 순서 1위라는 것만 적는다. 넘기지 말라는 제한은 devbrew 정책이다.
    touches: []
    decides: []
  - id: RC3
    path: "docs/plugin-authoring.md"
    anchor: "**Starter 디렉토리 트리**"
    line: 5
    claim: >
      필수: `.claude-plugin/plugin.json`(name · version · description) · `README.md`. 조건부: `CHANGELOG.md`(≥1.0.0).
      optional: `skills/<name>/SKILL.md` · `agents/` · `hooks/` · `scripts/` · `templates/` · `tests/`.
      `commands/` · `bin/` · `.mcp.json` · `output-styles/` · `monitors/` · `workflows/` · `themes/` · `references/` 는 트리에 없다
      (같은 파일 29행은 quality-gates 가 `references/` 를 shipping 한다고 적는다).
    touches: []
    decides: []
  - id: RC4
    path: "docs/plugin-authoring.md"
    anchor: "`plugin-dev`가 주는 것은 **문법**이다. devbrew **정책**(...)은 이 문서가 유일한 소스이며 충돌 시 우선한다."
    line: 48
    claim: >
      문법 레퍼런스로 `plugin-dev`(claude-plugins-official)의 skill(plugin-structure · skill-development · command-development ·
      agent-development · hook-development · mcp-integration)을 단계별로 로드하라고 하고, 충돌 시 devbrew 정책이 우선한다고 적는다.
      이 문서에 plugin-dev 의 판 · 확인 날짜는 없다.
    touches: []
    decides: []
  - id: RC5
    path: "docs/superpowers/specs/2026-09-06-agent-model-unpin-design.md"
    anchor: "## A. 측정 여섯"
    line: 43
    claim: >
      2026-09-06, CLI 2.1.261 헤드리스 프로브 여섯 건.
      F1 키 없는 agent 는 환경변수 → 세션 모델. F2 `model: inherit` 는 환경변수를 무효화. F3 환경변수는 settings `env` 블록으로 줄 수 있다.
      F4 `_FORCE=1` 은 `inherit` 까지 덮는다. F5 settings 키 `subagentModel` 은 동작하지 않고 바이너리에 문자열이 없다.
      미실측: U1(dispatch 인자 대 환경변수) · U2(FORCE 가 dispatch 인자 · 외부 리터럴 핀에 미치는 영향).
    touches: []
    decides: []
  - id: RC6
    path: "plugins/spec-distill/dependencies.md"
    anchor: "| claude-code | 2.1.303 | 2026-10-22 | 기록 | 잰 판을 기록만 한다 |"
    line: 19
    claim: >
      네 플러그인(plugin-audit · spec-distill · project-init · quality-gates)의 dependencies.md 가 모두 claude-code 2.1.303(2026-10-22)을 강도 「기록」으로 적는다.
      spec-distill 은 superpowers 7.0.0(2026-10-22, 알림)도 적는다. `plugin-dev` 행은 어느 dependencies.md 에도 없다(`plugins/**/dependencies.md` grep 0건).
    touches: []
    decides: []
  - id: RC7
    path: "CLAUDE.md"
    anchor: "**모든 PR마다 SemVer bump가 붙는 `plugin.json`.**"
    claim: >
      필수 `name` · `description` · `version`. 플러그인을 건드리는 모든 PR 마다 bump — 「안 그러면 cache key가 silent stale」.
      「보안-critical 의존성은 optional `integrity` field로 pin」.
      실제 `plugins/spec-distill/.claude-plugin/plugin.json` 은 name · description · version(8.13.1) · author 넷만 갖는다. `integrity` · `dependencies` 키는 없다
      (plugin.json 넷 가운데 이 하나만 읽었다).
    touches: []
    decides: []
  - id: RC8
    path: "CLAUDE.md"
    anchor: "**Scoped agents — default-everything 금지.**"
    claim: >
      모든 agent 는 `tools:` allowlist 를 선언하고 denylist(`disallowedTools`) 단독은 금지다. 「agent frontmatter의 실재 필드는 `tools`(allowlist)와
      `disallowedTools`(denylist) 둘뿐」 · camelCase `allowedTools` 는 「존재하지 않는 필드가 되어 조용히 무시된다」.
      구현 확인: `plugins/*/agents/*.md` 20개 모두 `^tools:` 줄이 있고 `^model:` 줄은 0건이다.
    touches: []
    decides: []
  - id: RC9
    path: "CLAUDE.md"
    anchor: "**`allowed-tools` 는 제한이 아니다.**"
    claim: >
      command 에서는 쓰지 않고, skill 에서는 진입 사전 검사 한 줄의 사전 허용으로만 쓴다. 「목록 밖 도구도 실행되고 스코프 표기도 범위 밖 명령을 막지 못한다」.
      구현 확인: 진입 skill 9개(spec-review · pm-interview · request-framing · epic-conductor · roadmap-status · project-init · artifact-critique · plugin-audit · quality-pipeline)가
      `allowed-tools:` 를 선언한다. `disallowed-tools` 를 쓰는 SKILL.md 는 0건이다.
    touches: []
    decides: []
  - id: RC10
    path: "CLAUDE.md"
    anchor: "**Progressive disclosure.**"
    claim: >
      진입 skill 은 짧은 kebab 두 단어 이상 · 디렉토리 이름 = `name`. 내부 skill(`user-invocable: false`)은 동명사. 안내는 `/plugin:name` 완전명.
      「새 command 파일은 만들지 않는다 — 사전 단계는 진입 skill 의 `!` 로」. 모호한 이름(`helper` · `utils` · "I can help you...") 금지.
    touches: []
    decides: []
  - id: RC11
    path: "CLAUDE.md"
    anchor: "**모든 skill에 `cost_class` 선언**"
    claim: >
      `cost_class`(low|medium|high|variable)를 SKILL.md frontmatter 최상위 키로 선언한다(확인한 SKILL.md 11개 전부).
      agent frontmatter 에도 비표준 키가 있다 — `plugins/spec-distill/agents/brief-readback.md` 의 `cost_class: low` · `input_slots:`.
      둘 다 공식 필드 표에 없는 키다.
    touches: []
    decides: []
  - id: RC12
    path: "CLAUDE.md"
    anchor: "### 런타임 상태 & 훅"
    claim: >
      런타임 state 는 `.claude/<plugin>/` 하위 마크다운(git-ignored). 모든 훅 · 진입 skill 에 kill switch(`DEVBREW_<PLUGIN>_DISABLE=1` · `DEVBREW_SKIP_HOOKS=<plugin>:<이름>`).
      `SessionStart` 훅은 read-only 조언자. 같은 event 내 훅은 교환 가능해야 한다.
    touches: []
    decides: []
  - id: RC13
    path: "CLAUDE.md"
    anchor: "**Self-narrating artifact**"
    claim: >
      모델이 읽고 행동하는 산출물(생성 템플릿 · 룰 파일 · 프롬프트)에 출처 · 배경 · 존재 정당화를 담지 않는다.
      「근거와 이력은 CHANGELOG·PR·리뷰에 남기고 산출물에는 행동에 필요한 것만 둔다」.
    touches: []
    decides: []
  - id: RC14
    path: "plugins/spec-distill/agents/brief-readback.md"
    anchor: "tools: []"
    line: 13
    claim: >
      도구가 하나도 없는 agent 를 빈 목록으로 선언한다(`plugins/spec-distill/agents/seed-readback.md` 15행도 같다).
      공식 문서의 「목록이 아무 도구로도 해석되지 않으면 보통 launch 실패」 문장이 명시적 빈 목록에 닿는지는 확인하지 못했다.
    touches: []
    decides: []
  - id: RC15
    path: "CLAUDE.md"
    anchor: "## Doc Conventions"
    claim: >
      CLAUDE.md 는 103줄이다(Grep count). 「~300줄을 넘는 오래 사는 docs 문서는 `## 목차`」 규칙을 둔다.
      공식 권고의 줄 수 기준(파일당 200줄 미만)과는 대상 · 문턱이 다른 별개 규칙이다.
    touches: []
    decides: []

unanswered: >
  (1) 명시적 빈 `tools: []` 가 「zero tools」 거절에 드는지 — errors 페이지의 해당 절이 잘린 범위 밖이라 원문을 못 읽었고 2차 자료(이슈 미러)만 있다.
  (2) 2.1.261 → 2.1.325 사이에 model 해석 순서가 실제로 그대로인지 — 문서 서술만 확인했고 재실측은 하지 않았다(read-only). changelog 는 앞 10만 자만 읽었다.
  (3) hooks 페이지가 SessionStart 의 변경 금지를 말하는지 — 읽은 범위에 없고 페이지가 잘렸다.
  (4) plugin-dev skill 세 개의 인용은 요약 모델 경유다. plugin-dev 판(0.1.2)도 같은 경로이고 레포에는 대응 기록이 없다.
  (5) 플러그인 캐시 파일을 subagent 가 못 읽을 수 있다는 레포 서술(`docs/plugin-authoring.md` 56행)에 대응하는 공식 문장은 찾지 못했다.
```

읽은 레포 파일(절대 경로):
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/plugin-authoring.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/CLAUDE.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/specs/2026-09-06-agent-model-unpin-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/dependencies.md (그리고 plugin-audit · project-init · quality-gates 의 dependencies.md 는 grep 으로만)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/.claude-plugin/plugin.json
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/agents/brief-readback.md

Sources:
- [Plugin manifest reference](https://code.claude.com/docs/en/plugins/manifest-reference)
- [Add components to a plugin](https://code.claude.com/docs/en/plugins/components)
- [Plugin loading reference](https://code.claude.com/docs/en/plugins/loading)
- [Plugin dependencies](https://code.claude.com/docs/en/plugins/dependencies)
- [Subagents](https://code.claude.com/docs/en/sub-agents)
- [Skills](https://code.claude.com/docs/en/skills)
- [Memory](https://code.claude.com/docs/en/memory)
- [Best practices](https://code.claude.com/docs/en/best-practices)
- [Model config](https://code.claude.com/docs/en/model-config)
- [Environment variables](https://code.claude.com/docs/en/env-vars)
- [Settings reference](https://code.claude.com/docs/en/settings-reference)
- [Hooks](https://code.claude.com/docs/en/hooks)
- [Errors](https://code.claude.com/docs/en/errors)
- [Changelog](https://code.claude.com/docs/en/changelog)
- [Skill authoring best practices (platform)](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [plugin-dev agent-development SKILL.md](https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/plugin-dev/skills/agent-development/SKILL.md)
- [plugin-dev plugin-structure SKILL.md](https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/plugin-dev/skills/plugin-structure/SKILL.md)
- [plugin-dev skill-development SKILL.md](https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/plugin-dev/skills/skill-development/SKILL.md)
- [plugin-dev plugin.json](https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/plugin-dev/.claude-plugin/plugin.json)
- [Issue mirror: subagent with `tools: []` listed as "All tools" (2차)](https://claudeissues.com/issue/82562-subagent-with-tools-is-listed-to-its-parent-as-tools-all-tools)
~~~~

### 조사 4 — orchestrator · R1 · 묶음 2

- 확인 RC64 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#열린 PR 274 — `gh pr view 274`: 열림 · 브랜치 `feature/interview-pr-merge` · 제목 「분해된 인터뷰가 끝맺음에서 PR 을 열고 머지를 묻는다」 · 고치는 파일은 spec-distill 의 plugin.json · CHANGELOG.md · README.md · dependencies.md · finishing.md 와 shared/tests/fixtures/ask-sites.tsv

## R1

### 지금 이해
경로 (a). 옆 로드맵의 로드맵 파일 · 묶음 여섯 · 팀 파일 규약 설계문서 지금 판(커밋 6ce36ffd, 740줄, 승인 전)을 다시 읽었고 seed 의 「다시 검증할 것」 가운데 레포로 확인되는 항목을 다시 열었다 — 조사 셋을 한 묶음으로 함께 띄웠다(범위 제안 · 옆 로드맵 읽기 · 공식 문서 대조가 서로 기대지 않는다). 옆 세션이 사용자 말을 전해 왔다(세션 메시지 — 사용자가 이 세션에 친 말이 아니다): 「외부 내부 조사를 담당하는거도 그쪽 역할인데 사실 의도 싱크는 framing에서 주 역할이고 interview는 컨텍스트 쌓기와 로드맵 잡는게 주 역할이야」.
조사 호출 3/60 · 이 라운드 본체 직접 1
밀린 질문 4개 — 공식 문서 대조 결과의 처분(조사 3 은 이 질문 직전에 끝났고 본체 대조가 아직이다 — 다음 라운드에 싣는다) · 작은 일의 가벼운 길과 구조 게이트 · 철학 문서를 어디까지 고칠지 · 덩어리 승인 화면에서 무엇이 보기 어려웠는지
줄인 사실 12개

줄인 사실 전문:
- 옆 설계문서 737행은 「그 로드맵이 `source_interview` 키와 `intent/` 에 바로 쓰기를 정한다」 고 이 일을 가리키고, 같은 문서 미룸 표 649행은 받는 곳을 R5 로 적는다 — 문서 안에서 갈린다(RC25 · RC50).
- 옆 설계문서 §1 은 `intent/` 에 「원자료 · brief」 를, §3 은 `original.md` 와 `README.md` 만 둔다고 적는다(RC44).
- 인터뷰 끝맺음 절차 파일(finishing.md)은 옆 로드맵의 어느 에픽도 예약하지 않았는데 옆 설계문서는 그 파일을 고치는 일 둘을 R2 로 넘긴다(RC47). 열린 PR #274 도 그 파일을 고친다(RC64).
- spec-distill 의 CHANGELOG.md 는 R5 예약, README.md · dependencies.md 는 R4 예약이다 — 이 일의 major 판 올림 기록과 겹친다. seed 에 없던 겹침이다(RC23 · RC29).
- 머리 키 `source_interview` 가 실제로 가리키는 것은 인터뷰가 아니라 에픽 묶음(새 형식에서는 과제의 INTENT.md)이다. 상태 계산 · 리뷰 진입 · 묶음 대조 셋이 이 키의 글자 대조로 설계문서를 에픽에 잇는다(RC16 · RC34 · RC48 · RC60).
- 옆 로드맵 묶음 여섯 어디에도 「의도 싱크」 · `interview_dir` 을 바꾸거나 유지한다는 항목이 없다(RC39).
- 작은 일: 옆 로드맵에 「설계문서 하나뿐인 작은 일도 지휘자를 거친다」(C2)와 「작은 일은 가볍게 돌린다」(D11)가 나란히 확정돼 있고, 옆 설계문서는 단순 작업도 과제 폴더를 갖게 했다. 도는 로드맵이 없을 때 단순 작업을 어디 둘지는 R2 로 미뤘다(RC24 · RC36 · RC51).
- 필수 조사: 범위 조사 0회는 「도구 부재」 사유로만 통과한다. 포화 판정은 사용자 종료 · 사용자 판단 칸이 있고 모델 판단 칸만 없다(RC8 · RC9).
- 호출 이름은 진입 표면 락의 등록 목록과 옛 이름 금지 목록에 묶여 있다(RC18). 앞단 세 파일을 경로로 읽는 테스트는 58개 파일이고 일부는 문장 글자를 단언한다(RC5 · RC19).
- 덩어리 승인 규칙 넷(덩어리마다 질문 하나 · 추천 없음 · 본문 줄임 없음 · 공시마다 번호 다시)은 request-framing SKILL.md 907–936행에 있고 둘에는 이유가 함께 적혀 있다(RC22).
- 옆 세션의 원자료 대조표(`framing-ledger.md`)는 두 worktree 어디에도 없다(RC55). 옆 로드맵의 결정 기록 절은 비어 있다 — 설계가 바꾼 것이 로드맵에 아직 없다(RC28).
- 웹 주장 넷(조사 1 의 evidence — 공식 문서의 하위 agent 모델 순서 · SKILL.md 500줄 권고 · `allowed-tools` 는 사전 허용 · commands 보다 skills 권고)은 본체가 1차 자료로 다시 확인하지 않았다 — 확인 못 함. 조사 3 결과와 함께 다음 라운드에 본다.

- 대체됨: seed 「옆 세션 설계문서의 미룸 표는 앞단이 의도 폴더에 바로 쓰게 하는 일과 설계문서 머리 키의 이름을 이름 바꾸기 쪽과 그 로드맵의 이전 에픽 앞으로 함께 적어 두었다」 → 지금 판은 받는 곳 칸이 R5 하나이고 이유 칸이 「이름 바꾸기 로드맵(B13)이 먼저 하면 R5 는 옮길 때 확인만 한다」, 737행은 「그 로드맵이 … 정한다」 (조사 1 · 조사 2)
- 대체됨: seed 「인터뷰 결과물 리뷰 기준이 레포 원칙을 깎는 잣대로 쓴다」 → 사다리 2단 「이미 리포에 있는 원칙·메커니즘으로 되나」 는 줄이는 근거가 맞고, 「Law 1·2·3 과 kill switch 는 어떤 모드에서도 안 자른다」 는 깎지 못하게 하는 보호 줄이다 (조사 1)
- 대체됨: Phase 0 기록 「필수 조사 둘과 포화 판정을 모델이 건너뛸 칸이 없다」 → 포화 판정에는 사용자 종료 · 사용자 판단 포화 칸이 있고 모델 판단 칸만 없다 (조사 1)
- 대체됨: Phase 0 기록 「약 2천 자 한 줄」 → finishing.md 551행은 3736자다 (조사 4 와 함께 본체가 잼)
- 대체됨: 옆 세션 넘김 글의 「인터뷰 → 의도 싱크」 한 덩어리 → 옆 세션이 그 등치는 자기 해석이었다고 알렸다(세션 메시지). 사용자 확인은 이 라운드 질문으로 받는다

- 확인 RC1 — 확인 — plugins/spec-distill/skills/pm-interview/references/seed-input.md#「§6 `S1` 은 「풀린 입력」 원문 그대로다」 — 주장과 일치
- 확인 RC2 — 확인 — plugins/spec-distill/references/docreview-profiles/brief.md#ground_truth — 주장과 일치
- 확인 RC3 — 확인 — plugins/spec-distill/references/docreview-profiles/seed.md#layer1 — 주장과 일치(범주 다섯 · 29행 omission 규칙)
- 확인 RC4 — 확인 — plugins/spec-distill/scripts/seed_body.py#「받는 문법(허용 목록)을 적고, 그 밖은 전부 거부한다」 — 주장과 일치
- 확인 RC5 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#「superpowers 부재 시」 — 주장과 일치(444행 · 테스트 107–112행)
- 확인 RC6 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#「다음 세션 줄 — 분해된 일 ①/② 공통」 — 주장과 일치
- 확인 RC7 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#「사용자 선호: 이 brief 의 설계는 설계문서를 쓰는 크기다」 — 주장과 일치(epic-handoff.md 7행에도 같은 라벨)
- 확인 RC8 — 확인 — plugins/spec-distill/scripts/check_brief.py#budget_mapper_failures — 주장과 일치(saturation_failures 포함)
- 확인 RC9 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#「필수 자리 둘(첫 질문 전 `coverage-mapper`」 — 주장과 일치
- 확인 RC10 — 확인 — plugins/spec-distill/scripts/build_seed_inline_blob.py#main — 코드와 락은 주장과 일치, 실행은 하지 않았다
- 확인 RC11 — 확인 — plugins/spec-distill/references/docreview-profiles/brief.md#「판정 절차 — 사다리」 — 주장과 일치(seed 의 서술은 절반만 맞다)
- 확인 RC12 — 확인 — plugins/spec-distill/references/compression.md#「3. 레포 `CLAUDE.md`·`AGENTS.md` 에 이미 있는가」 — 46행은 일치, 「올리는 길이 없다」 는 부재 주장이라 다시 세지 않았다
- 확인 RC13 — 확인 — plugins/spec-distill/references/research-claims.md#「출처: `docs/archive/interview/2026-07-12-project-init-audit-interview.md`」 — 주장과 일치
- 확인 RC14 — 확인 — docs/plugin-authoring.md#「quality-gates:doc-recritic」 — 주장과 일치(quality-gates agents 넷 · doc-recritic 은 spec-distill 에 있다)
- 확인 RC15 — 확인 — docs/plugin-authoring.md#「command-development」 — 주장과 일치(45행 · 22행)
- 확인 RC16 — 확인 — plugins/spec-distill/scripts/roadmap_status.py#find_specs — 주장과 일치(336 · 680행 글자 대조)
- 확인 RC17 — 확인 — plugins/spec-distill/scripts/repo_defaults.py#KEYS — 주장과 일치
- 확인 RC18 — 확인 — shared/tests/test_invocation_surface.sh#ENTRY — 주장과 일치(34행 · 135–158행)
- 확인 RC19 — 확인 — plugins/spec-distill/tests/test_superpowers_presence.sh#FIN — 주장과 일치, 파일 수는 본체 계수 58(보고 57)
- 확인 RC20 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#파일 전체 줄 수 — 줄 수 일치(1373 · 600 · 741 · 685), 비율은 재지 않았다
- 확인 RC21 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#「B-2 — 단일 `AskUserQuestion` proceed 게이트 (4옵션, AC2)」 — 인용한 줄은 일치, 「약 45곳」 은 확인하지 못했다
- 확인 RC22 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#「저자 편집 공시 — 라운드 게이트 앞 · 확정 게이트 앞」 — 주장과 일치
- 확인 RC23 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#「R2 — 지휘 절차 개편」 — 주장과 일치(32 · 44 · 79행)
- 확인 RC24 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R2.md#C2 — 주장과 일치(42 · 52 · 105행)
- 확인 RC25 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「brief · audit 를 `intent/` 에 바로 쓰기 · `source_interview` 키 이름」 — 주장과 일치(649 · 737 · 204 · 176 · 401행)
- 확인 RC26 — 확인 — docs/philosophy/devbrew-harness-philosophy.md#「P8 — Determinism Economy」 — 주장과 일치(82 · 84행)
- 확인 RC27 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#「git commit -q --only -m 'docs(interview): <topic> interview seed + audit'」 — 주장과 일치(1157행 · finishing.md 640행 · 템플릿 11행)
- 확인 RC28 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#「2026-11-14 · 처음 로드맵」 — 주장과 일치(두 판 파일 일곱이 바이트 동일 · 결정 기록 절 비어 있음)
- 확인 RC29 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#「경로 예약」 — 주장과 일치
- 확인 RC30 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#「에픽마다 원본 brief · 이 로드맵 · 에픽 묶음을 넘긴다」 — 주장과 일치
- 확인 RC31 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#「R2 — 지휘 절차 개편」 — 주장과 일치(40행 범위 · 119행 K14)
- 확인 RC32 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#「R5 — 이전 · 재측정」 — 주장과 일치(75 · 79행)
- 확인 RC33 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#K1 — 주장과 일치
- 확인 RC34 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R1.md#「0. 역참조」 — 주장과 일치(묶음 여섯 모두 한 줄씩 · roadmap_render.py 336행)
- 확인 RC35 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R1.md#「S1 최초 요청(Phase 0 seed 전문)」 — 116행은 일치, 묶음에 framing 원문 절이 없다는 부분은 다시 세지 않았다
- 확인 RC36 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R2.md#「C2 · D11」 — 주장과 일치
- 확인 RC37 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R5.md#OQ47 — 주장과 일치(53행 · S49 184행)
- 확인 RC38 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R2.md#OQ24 — 주장과 일치(R1.md 86행 OQ45 포함)
- 확인 RC39 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R2.md#OQ23 — 주장과 일치(로드맵 폴더 일곱 파일에 「의도 싱크」 · `interview_dir` 0건)
- 확인 RC40 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R2.md#ids — 주장과 일치(C50 은 있고 S50 은 ids 에 없다)
- 확인 RC41 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R1.md#「7. 인터페이스」 — R1 은 일치, 다른 묶음은 다시 열지 않았다
- 확인 RC42 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「Context / Why」 — 주장과 일치(28 · 34행)
- 확인 RC43 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「§3 원자료 — `intent/`」 — 주장과 일치
- 확인 RC44 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「§1 팀 폴더 — `intent/` 행」 — 주장과 일치(98 · 114 · 188 · 498행이 서로 다르게 적는다)
- 확인 RC45 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「한 번만 짓는다.」 — 주장과 일치
- 확인 RC46 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「§11 생성기」 — 주장과 일치(390–392 · 546행)
- 확인 RC47 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「분해 승인 화면에 과제마다 지시 원문 범위의 글을 보이기」 — 주장과 일치(642행 · 로드맵 44행에 그 파일 없음)
- 확인 RC48 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「`references/epic-handoff.md`」 — 주장과 일치(401 · 405행)
- 확인 RC49 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「Non-goals」 — 주장과 일치(51 · 671 · 737행)
- 확인 RC50 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「미룸 — brief · audit 를 `intent/` 에 바로 쓰기」 — 주장과 일치(문서 안에서 받는 곳이 갈린다)
- 확인 RC51 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「과제는 에픽이거나 단순 작업」 — 주장과 일치(127 · 371 · 376 · 396 · 643 · 685행)
- 확인 RC52 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「사용자에게 보이는 말은 「리더」다」 — 주장과 일치(71 · 409–411 · 597행)
- 확인 RC53 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「Files to Modify」 — 주장과 일치(철학 문서 · 레포 CLAUDE.md 없음 · 308 · 468 · 535 · 711행)
- 확인 RC54 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「재분해 신호」 — 주장과 일치(726행 ④ 가 R2.md 실물과 C50 에서 어긋난다)
- 확인 RC55 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「Handoff Context — 원자료 대조표」 — 주장과 일치(736행 · 두 worktree 에 `framing-ledger.md` 없음)
- 확인 RC56 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「미룸」 — 주장과 일치(628–655행)
- 확인 RC57 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「D33 행」 — 주장과 일치(513 · 644행 · 로드맵 28행)
- 확인 RC58 — 미확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「원문 대조 — 원자료:」 — 463행의 줄 범위 인용은 있으나 그 범위가 옛 audit 실물과 맞는지는 대조하지 않았다
- 확인 RC59 — 확인 — plugins/spec-distill/scripts/repo_defaults.py#ROADMAP_META_KEYS — 주장과 일치, `interview_dir` 글자 수는 본체 계수 21개 파일 125번(보고 119번)
- 확인 RC60 — 확인 — plugins/spec-distill/scripts/roadmap_status.py#find_specs — 주장과 일치, `source_interview` 글자 수는 본체 계수 24개 파일 72번(보고 65번)
- 확인 RC61 — 확인 — plugins/spec-distill/references/epic-handoff.md#「에픽 넘김 줄」 — 주장과 일치
- 확인 RC62 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#「payload frontmatter」 — 주장과 일치(74–76 · 229 · 556 · 588 · 606행)
- 확인 RC63 — 확인 — docs/superpowers/interview/2026-11-14-framing-interview-constraint-audit-interview.md#「인터뷰를 의도 싱크로 바꾸는 이름 바꾸기는 이 일에 합친다. (사용자 확인)」 — 주장과 일치
- 확인 RC64 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#열린 PR 274 — 본체가 직접 확인(조사 4)

### 다음 결정
OQ1: 옆 세션이 전한 역할 말씀에 따라 이름 바꾸기를 어떻게 고칠까 · 추천: framing 이 의도 싱크, 인터뷰는 새 이름 · 트레이드오프: 둘 다 바꾸면 호출 이름 둘과 major 판 올림 / framing 만 바꾸면 인터뷰 쪽 키 · 폴더는 그대로 / 역할만 고치면 이름 바꾸기가 이 일에서 빠진다 / 원래대로면 전한 말과 어긋난다
OQ2: 앞단이 의도 폴더에 바로 쓰게 하는 일을 이 일이 맡을까 · 추천: 이 일이 맡는다 · 트레이드오프: 맡으면 사본 기간이 없어지고 이 일이 커진다 / 원자료 파일만 맡으면 결과물 자리 옮기기는 R5 에 남는다 / 맡지 않으면 옆 로드맵이 계속 사본을 만든다
OQ3: 이 일의 중심은 새 코어에 맞추기인가 원문 보존인가 · 추천: 새 코어에 맞추기 · 트레이드오프: 새 코어가 중심이면 방향 넷과 이름이 같은 무게 / 원문 보존이 중심이면 원자료 사슬이 첫 순서

### 질문
경로 (b) — 판단. 한 호출에 셋(서로 기대지 않는다).
1. 옆 세션이 사용자 말씀을 이렇게 전해 왔습니다 — 「외부 내부 조사를 담당하는거도 그쪽 역할인데 사실 의도 싱크는 framing에서 주 역할이고 interview는 컨텍스트 쌓기와 로드맵 잡는게 주 역할이야」. seed 에서 확인하신 문장은 「인터뷰를 의도 싱크로 바꾸는 이름 바꾸기는 이 일에 합친다」 였습니다. 이름 바꾸기를 어떻게 고칠까요?
2. 옆 세션의 팀 파일 규약 설계문서(승인 전)는 앞단이 원자료와 결과물을 로드맵의 의도 폴더(`intent/`)에 바로 쓰게 하는 일을 이 일이 정한다고 적었습니다. 지금은 그쪽이 앞단 기록에서 옮겨 적은 사본을 만듭니다. 이 일이 맡을까요?
3. seed 는 「내 의도가 interview지나면서 의역된거 같아서 그래」 가 이 일의 계기인지 여쭙지 않았다고 적었습니다. 이 일에서 무엇이 중심인가요?

### 답
→ S2 · S3 · S4

- 재결정(P23): 원래 — seed 「인터뷰를 의도 싱크로 바꾸는 이름 바꾸기는 이 일에 합친다. (사용자 확인)」 / 재결정 — request-framing 이 「의도 싱크」가 되고 인터뷰는 새 이름을 따로 정한다(S2) / 근거 — 옆 세션이 전한 사용자 말 「외부 내부 조사를 담당하는거도 그쪽 역할인데 사실 의도 싱크는 framing에서 주 역할이고 interview는 컨텍스트 쌓기와 로드맵 잡는게 주 역할이야」 를 질문에 그대로 싣고 사용자가 골랐다
- root_problem 닫음 — S1 의 목적 문장과 S4

### 조사 5 — orchestrator · R2 · 묶음 3

- 하위 agent 모델 순서 「1. The per-invocation `model` parameter … 2. The `model` field in the subagent's definition, including `inherit` 3. The `CLAUDE_CODE_SUBAGENT_MODEL` environment variable 4. The main conversation's model」 — https://code.claude.com/docs/en/sub-agents 「Choose a model」 (1차 · 확인 2026-11-14) [→ OQ6]
- 「Multi-word field names use camelCase … Claude Code ignores a field it doesn't recognize without reporting an error.」 — https://code.claude.com/docs/en/sub-agents 「Frontmatter reference」 (1차 · 확인 2026-11-14) [→ OQ6]
- 「Keep `SKILL.md` under 500 lines. Move detailed reference material to separate files.」 — https://code.claude.com/docs/en/skills 「Add supporting files」 (1차 · 확인 2026-11-14) [→ 없음]
- 「Keep the body itself concise.」 · 「State what to do rather than narrating how or why」 — https://code.claude.com/docs/en/skills 「Types of skill content」 (1차 · 확인 2026-11-14) [→ 없음]
- `allowed-tools` 「It does not restrict which tools are available」 — https://code.claude.com/docs/en/skills 「Pre-approve tools for a skill」 (1차 · 확인 2026-11-14) [→ OQ6]
- 「Custom commands have been merged into skills.」 — https://code.claude.com/docs/en/skills 도입부 (1차 · 확인 2026-11-14) [→ OQ6]
- skill frontmatter `metadata` 「Free-form YAML map for your own key-value data … Claude Code doesn't act on its contents」 · 모르는 필드는 오류 없이 무시 · Claude Code 밖 업로드 경로는 「fails with a hard error」 — https://code.claude.com/docs/en/skills 「Frontmatter reference」 · 「Using skill frontmatter outside Claude Code」 (1차 · 확인 2026-11-14) [→ OQ6]
- 「Commands are the older format, and skills supersede them for new work.」 — https://code.claude.com/docs/en/plugins/components 「Commands」 (1차 · 확인 2026-11-14) [→ OQ6]
- 플러그인 agent 지원 필드에 `model` 포함 · 무시 필드 `permissionMode` · `hooks` · `mcpServers` · `initialPrompt` — https://code.claude.com/docs/en/plugins/components 「Frontmatter fields in plugin agents」 (1차 · 확인 2026-11-14) [→ OQ6]
- 「The name `scripts/` is a convention, not something Claude Code looks for」 — https://code.claude.com/docs/en/plugins/components (1차 · 확인 2026-11-14) [→ OQ6]
- 「The manifest is optional.」 · 「`name` is the only required key.」 · 모르는 최상위 필드는 벗겨지고 validate 가 경고 — https://code.claude.com/docs/en/plugins/manifest-reference (1차 · 확인 2026-11-14) [→ OQ6]
- 「Size: target under 200 lines per CLAUDE.md file.」 — https://code.claude.com/docs/en/memory 「Write effective instructions」 (1차 · 확인 2026-11-14) [→ 없음]

## R2

### 지금 이해
경로 (a) 외부. Claude Code 공식 문서와 저술 가이드 · CLAUDE.md 를 대조했고(조사 3), 결정에 닿는 인용 열둘은 본체가 공식 페이지 다섯에서 원문으로 다시 확인했다(조사 5). 저술 가이드의 `model` 키 금지 근거(해석 순서)는 지금 공식 문서와 같다 — 다만 공식 문서는 그 키를 금지하지 않고, 금지는 devbrew 정책이다.
조사 호출 3/60 · 이 라운드 본체 직접 1
밀린 질문 3개 — 작은 일의 가벼운 길과 구조 게이트 · 철학 문서를 어디까지 고칠지 · 덩어리 승인 화면에서 무엇이 보기 어려웠는지
줄인 사실 3개

줄인 사실 전문:
- 공식과 같은 자리: `model` 해석 순서 · agent 의 `tools`/`disallowedTools` 와 camelCase · `allowed-tools` 는 제한이 아님 · command 는 옛 형식 · `scripts/` 는 관례 · skill 본문은 할 일만(이유 · 방법 서술 줄이기) · SKILL.md 500줄 권고(앞단 진입 skill 둘은 1373 · 600줄).
- 공식과 다른 자리(레포가 더 엄격하거나 다른 장치): `model` 키 금지 · `plugin.json` 필수 셋(공식은 `name` 하나) · PR 마다 SemVer bump · `integrity` 키(공식 표에 없음) · 의존을 `dependencies.md` 표로(공식은 `plugin.json` `dependencies`) · `cost_class` 최상위 키(공식의 사용자 키 자리는 `metadata`) · 환경변수 kill switch(공식은 `disableAllHooks`) · 런타임 상태를 `.claude/<plugin>/` 에(공식은 `${CLAUDE_PLUGIN_DATA}`). 조사 3 이 「요약 모델 경유 · 불확실」 로 낸 것(공식 플러그인 plugin-dev 의 서술 · 빈 `tools: []` 의 동작 · SessionStart)은 본체가 다시 확인하지 않았다 — 확인 못 함.
- 저술 가이드의 낡음은 셋으로 갈린다: 공식 · 레포 규칙 둘 다와 어긋남(`command-development`, 없는 예시 agent) · 공식과 같고 레포 실체와 어긋남(`scripts/` 를 hook 헬퍼로 적은 줄) · 레포가 일부러 다름(위 「다른 자리」).

- 확인 RC65 — 확인 — docs/plugin-authoring.md#「agent frontmatter 에 `model` 키를 두지 않는다.」 — 주장과 일치(22행, 근거는 P8)
- 확인 RC66 — 확인 — docs/plugin-authoring.md#「dispatch 시점의 `model` 인자는 오케스트레이터의 재량이다.」 — 주장과 일치
- 확인 RC67 — 확인 — docs/plugin-authoring.md#「Starter 디렉토리 트리」 — 주장과 일치(5–20행 · 29행)
- 확인 RC68 — 확인 — docs/plugin-authoring.md#「`plugin-dev`가 주는 것은 **문법**이다.」 — 주장과 일치(48행)
- 확인 RC69 — 확인 — docs/superpowers/specs/2026-09-06-agent-model-unpin-design.md#「A. 측정 여섯」 — 43행 · 미실측 U1 · U2(71–73행)는 일치, F1–F5 본문은 다시 읽지 않았다
- 확인 RC70 — 확인 — plugins/spec-distill/dependencies.md#「claude-code | 2.1.303 | 2026-10-22」 — 주장과 일치(네 플러그인 · superpowers 7.0.0 · plugin-dev 행 없음)
- 확인 RC71 — 확인 — CLAUDE.md#「모든 PR마다 SemVer bump가 붙는 `plugin.json`.」 — 주장과 일치(spec-distill plugin.json 키는 author · description · name · version)
- 확인 RC72 — 확인 — CLAUDE.md#「Scoped agents — default-everything 금지.」 — 주장과 일치(agent 20개 모두 `tools:` · `model:` 0건)
- 확인 RC73 — 확인 — CLAUDE.md#「`allowed-tools` 는 제한이 아니다.」 — 주장과 일치(SKILL.md 9개가 선언 · `disallowed-tools` 0건)
- 확인 RC74 — 확인 — CLAUDE.md#「Progressive disclosure.」 — 주장과 일치
- 확인 RC75 — 확인 — CLAUDE.md#「모든 skill에 `cost_class` 선언」 — 주장과 일치, SKILL.md 는 본체 계수 10개(보고 11개)
- 확인 RC76 — 확인 — CLAUDE.md#「런타임 상태 & 훅」 — 주장과 일치
- 확인 RC77 — 확인 — CLAUDE.md#「Self-narrating artifact」 — 주장과 일치
- 확인 RC78 — 확인 — plugins/spec-distill/agents/brief-readback.md#「tools: []」 — 주장과 일치(13행 · seed-readback.md 15행)
- 확인 RC79 — 확인 — CLAUDE.md#「Doc Conventions」 — 주장과 일치(103줄)

### 다음 결정
OQ5: 의도 폴더에 바로 쓰기를 맡았을 때 이 일이 끝나면 꼭 참이어야 하는 것은 무엇인가 · 추천: 사본이 없다 · 원자료는 글자 그대로 · 트레이드오프: 로드맵 없는 일도 같은 자리면 framing 이 폴더를 먼저 만들어야 한다 / 옛 기록도 옮기면 77개 파일과 그것을 가리키는 경로가 움직인다
OQ6: 공식 문서와 다른 자리를 저술 가이드에서 어떻게 다룰까 · 추천: 낡은 것만 고치고 다른 자리는 드러낸다 · 트레이드오프: 낡은 것만 고치면 다른 자리가 계속 안 보인다 / 공식 쪽으로 옮길 후보로 보면 CLAUDE.md 규칙 개정으로 범위가 넓어진다
OQ4: 인터뷰의 새 이름을 무엇으로 할까 · 추천: 없음 — 사용자가 고를 이름이고 본체에 근거가 없다 · 트레이드오프: 지금 정하면 옆 세션이 새 파일에 바로 쓴다 / 미루면 옆 세션은 옛 이름으로 쓰거나 기다린다

### 질문
경로 (b) — 판단. 한 호출에 셋. 첫 질문은 S3 의 되묻기다 — 기본은 되묻기를 따로 묻지만 세 결정이 서로 기대지 않아 묶었다(모델 판단: 따로 물으면 한 문항짜리 라운드가 는다).
1. 앞 질문에서 「의도 폴더에 바로 쓰기를 이 일이 맡는다」 를 고르셨습니다. 이 일이 끝났을 때 꼭 참이어야 하는 것을 고르세요(여럿 고를 수 있습니다).
2. Claude Code 공식 문서와 저술 가이드 · CLAUDE.md 를 대조했습니다. 공식과 다른 자리를 저술 가이드에서 어떻게 다룰까요?
3. 인터뷰는 맥락 쌓기 · 로드맵 잡기 · 조사에 맞는 새 이름을 따로 정하기로 하셨습니다. 사용자에게 보이는 이름을 무엇으로 할까요?

### 답
→ S5 · S6 · S7

- landscape 닫음 — S6(공식 문서 대조의 처분)
- S5 의 덧붙인 말 「3 시작이 framing일수도 있고 아닐수도 있긴함」 은 셋째 선택지(로드맵 없는 일도 같은 자리)에 붙은 조건으로 읽었다 — 본체의 읽기이고 확인받지 않았다. 「옛 기록도 옮긴다」 는 고르지 않았다.

### 조사 6 — orchestrator · R3 · 묶음 4

- skill frontmatter `disallowed-tools` 「Tools removed from Claude's available pool while this skill is active.」 — https://code.claude.com/docs/en/skills 「Frontmatter reference」 (1차 · 확인 2026-11-14) [→ OQ7]
- `plugin.json` Fields 표의 최상위 키 31개에 `integrity` 없음 · `metadata` 「Free-form object for your own data. Claude Code doesn't read it」 · `dependencies` 「Plugins that must be enabled for this one to work.」 — https://code.claude.com/docs/en/plugins/manifest-reference 「Fields」 (1차 · 확인 2026-11-14) [→ OQ7]
- 「List dependencies in the `dependencies` array of your plugin's `.claude-plugin/plugin.json`.」 · 판 범위 「A semantic-version range such as `~2.1.0`, `^2.0`, `>=1.4`, or `=2.1.0`.」 — https://code.claude.com/docs/en/plugins/dependencies (1차 · 확인 2026-11-14) [→ OQ7]
- `${CLAUDE_PLUGIN_ROOT}` 「the path changes when the plugin updates. Don't write state there」 · `${CLAUDE_PLUGIN_DATA}` 「a directory that survives updates, for `node_modules`, virtual environments, and caches.」 — https://code.claude.com/docs/en/plugins/components 「Reference plugin paths and store data」 (1차 · 확인 2026-11-14) [→ OQ7]
- 「To temporarily disable all hooks without removing them, set `"disableAllHooks": true` in your settings file.」 · 「There is no way to disable an individual hook while keeping it in the configuration.」 — https://code.claude.com/docs/en/hooks 「Disable or remove hooks」 (1차 · 확인 2026-11-14) [→ OQ7]
- 「a manifest that pins `"version": "1.0.0"` keeps every user on the cached copy until its author changes the string」 · 「To let users track commits instead, leave `version` out of both the manifest and the entry.」 — https://code.claude.com/docs/en/plugins/loading 「How Claude Code computes the version」 (1차 · 확인 2026-11-14) [→ OQ7]

## R3

### 지금 이해
경로 (a) 외부. 항목별로 물을 공식 문서 사실 여섯을 본체가 원문으로 다시 확인했다(조사 6) — skill 계층에 도구를 실제로 빼는 `disallowed-tools` 키가 있고, `plugin.json` 공식 키 31개에 `integrity` 는 없다. S7 「파이프라인으로서 둘로 나눠도 되고」 는 인터뷰를 두 단계로 나눌 수 있다는 말로 읽었으나 확인받지 않았다.
조사 호출 3/60 · 이 라운드 본체 직접 1
밀린 질문 3개 — 작은 일의 가벼운 길과 구조 게이트 · 철학 문서를 어디까지 고칠지 · 덩어리 승인 화면에서 무엇이 보기 어려웠는지
줄인 사실 2개

줄인 사실 전문:
- CLAUDE.md 는 「`allowed-tools` … 이 계층은 제한이 아니다」 라고 적는데 공식 문서에는 skill 계층에서 도구를 실제로 빼는 `disallowed-tools` 가 있다. 레포 SKILL.md 가운데 그 키를 쓰는 것은 0건이다(RC73).
- 공식 `${CLAUDE_PLUGIN_DATA}` 는 사용자 홈 아래 플러그인별 자리이고 용도가 의존 설치물 · 캐시로 적혀 있다. 레포의 런타임 상태는 프로젝트 · 문서 · 로드맵 단위라 쓰임이 다르다(본체의 대조).

### 다음 결정
OQ8: 인터뷰를 맥락 쌓기와 로드맵 잡기 두 단계로 나눌까 · 추천: 둘로 나누는 방향 · 트레이드오프: 나누면 이름 둘과 단계 사이 넘김이 하나 더 생긴다 / 한 단계로 두면 이름을 다시 정해야 한다 / 설계에 맡기면 옆 세션이 새 이름을 늦게 받는다
OQ7: 공식과 다른 자리 가운데 어느 것을 공식 쪽으로 옮길까 · 추천: `cost_class` 자리 · `integrity` 키 · `disallowed-tools` 반영 · 트레이드오프: 옮기면 그 규칙을 쓰는 모든 플러그인 파일과 락이 함께 바뀐다 / 그대로 두면 공식과 다른 자리로 남는다

### 질문
경로 (b) — 판단. 한 호출에 셋. 첫 질문은 S7 의 되묻기다 — R2 와 같은 이유로 묶었다(세 결정이 서로 기대지 않는다). OQ7 은 항목이 여덟이라 두 질문으로 나눴다.
1. 「파이프라인으로서 둘로 나눠도 되고」 를 저는 「인터뷰를 맥락 쌓기(조사)와 로드맵 잡기(분해) 두 단계로 나눌 수 있다」 로 읽었습니다. 어느 쪽인가요?
2. 공식과 다른 자리 가운데 공식 쪽으로 옮길 것을 고르세요 (1/2 · 여럿 고를 수 있습니다). 고르지 않은 것은 지금 규칙 그대로 둡니다.
3. 공식과 다른 자리 가운데 공식 쪽으로 옮길 것을 고르세요 (2/2 · 여럿 고를 수 있습니다). 고르지 않은 것은 지금 규칙 그대로 둡니다.

### 답
→ S8 · S9 · S10

- S8 로 인터뷰의 새 이름도 정해졌다 — 「맥락 쌓기」 와 「로드맵 잡기」(고른 선택지의 설명 문장). 호출 이름과 나누는 자리는 설계 몫이다.
- S9 에서 「의존을 plugin.json 에도 선언」 은 고르지 않았다 — 지금 규칙 그대로 둔다.
- S10 의 셋은 본체 추천(「이 셋은 옮기지 않는다」)과 다른 선택이다. 셋 다 의심 trigger 에 든다 — 기존 사용자 제약(CLAUDE.md 의 kill switch 보안 컨트롤 · model 키 금지의 실측 근거 · PR 마다 판 올림)과의 충돌, landscape 모순(공식에는 개별 hook 끄기가 없다 · 공식 데이터 폴더의 용도). 방향마다 steelman 을 띄운다(ST1 · ST2 · ST3).
- blind_spot 차원 첫 open → in-progress: blind-spot-prober 를 같은 묶음으로 띄운다(steelman 셋과 서로 기대지 않는다).

#### ST 공통 dispatch 입력
- goal: S4 「새 코어에 맞추기 (권장) — 원문 보존은 그 안의 한 갈래다. 넘기는 곳 · 글 줄이기 · 가벼운 길 · 이름이 같은 무게로 간다.」 (goal 을 담은 가장 최근 발화)
- 전제: P1 「내가 말하는거는 우리 레포에 바이어스 되게 보다 표준에 맞게 가자는거였어」 — 철학 문서를 두고 한 말(S1) · P2 「Claude Code 공식 자료는 따라야 할 기준이 아니라 참고 내용으로 둔다.」(S1) · P3 공식과 다른 자리는 공식 쪽으로 옮길 후보로 본다(S6) · P4 「가능하면 추가보다는 푸는 쪽으로 가고」(S1) · P5 플러그인 저술 가이드는 표준에 맞추는 방향과 새 코어에 맞추는 방향을 함께 적용해 고친다(S1) · P6 공식 장치로 옮겨도 지금 장치가 사용자에게 주던 것이 유지된다(orchestrator 도출)
- 제약: S1–S10 (S1 은 상태 파일 `## 풀린 입력` 블록의 경로로, S2–S10 은 원문으로 실었다)
- ST1 의심 방향: agent 머리말의 `model` 키를 허용한다 / ST2: plugin.json 필수 키를 줄이거나 PR 마다 판 올림을 완화한다 / ST3: 환경변수 kill switch 대신 공식 설정만 쓰고 런타임 상태를 공식 플러그인 데이터 폴더로 옮긴다

### 조사 8 — steelman-builder · R3 · 묶음 5

~~~~
```yaml
case_for_alternative:
  statement: >-
    `version` 은 명시 SemVer 로 남기고(CHANGELOG 판 헤딩 · 호출 이름 변경 시 major 올림도 그대로), 완화는 두 곳에만 건다 —
    규칙 문면에서 「로더가 요구하는 키는 `name` 하나」 와 「devbrew 가 쓰는 키(`version` · `description`)」 를 가르고,
    판 올림은 「플러그인을 건드리는 모든 PR」 에서 「설치본 동작에 닿는 변경」 으로 좁힌다(닿지 않으면 이유를 적고 건너뛴다).
  strongest: >-
    devbrew 에서 판 번호는 캐시 키만이 아니라 «순서가 있는 값»으로 읽힌다. 지휘자는 `plugin.json` 의 `version` 이 비면
    기계 상태를 쓰지 못하고 멈추고(「플러그인 판이 비어 있다」), 더 새 판이 쓴 기계 상태를 옛 판이 읽지 못하게 막고,
    설치본이 레포 사본보다 옛 판인지 알리며, spec-distill 은 quality-gates 의 최소 판(14.6.0)을 그 값에서 잰다(RC3–RC6).
    커밋 SHA 는 순서가 없어 이 넷을 대신하지 못한다.
    이 일 자체가 호출 이름 둘을 바꾸고(S2 · S8) 레포 규칙은 그 깨짐 신호를 major 올림으로 낸다(RC2) — `version` 을 비우면
    goal 의 「이름」 갈래가 신호를 실을 자리를 잃는다.
    「공식 쪽」도 한 겹이 아니다. `name` 하나는 로더의 바닥이고, 공식 검증기는 `version` · `description` · `author` 가 없으면
    경고하며(`--strict` 는 실패), Anthropic 자신의 플러그인은 넷을 다 적고, 공식 의존 장치(semver 범위 →
    `<plugin-name>--v<version>` 태그)는 명시 판을 전제한다. 공식 문서는 「판을 올리거나 비우거나」 를 둘 다 정식 선택지로 적는다 —
    지금의 필수 셋과 판 올림은 이미 공식 안에 있고, devbrew 고유인 것은 「필수」 라는 낱말과 「PR 마다」 라는 단위뿐이다.
    캐시 신선도는 두 길이 거의 같다(플러그인을 건드린 머지마다 새 사본). 다른 것은 판 문자열이 순서 있는 SemVer 인가
    해시인가 하나이고, goal 의 네 갈래(넘기는 곳 · 글 줄이기 · 가벼운 길 · 이름) 어느 것도 `version` 을 비워야 얻어지지 않는다.
case_for_current:
  strongest: >-
    새 코어는 에픽을 병렬로 돌리는 팀 구조인데, 지금 규칙은 플러그인을 건드리는 모든 PR 이 같은 `plugin.json` 판 줄과
    같은 CHANGELOG 머리를 고치게 만든다. 지휘 코드가 이미 이 둘을 「에픽이 함께 건드려 겹치기 쉬운 공유 파일」 로 이름 붙이고
    「버전은 머지 직전에 정한다」 는 우회 규칙을 따로 둔다(RC10) — 규칙이 만든 충돌을 다른 규칙으로 막는 꼴이다.
    `version` 을 비우면 그 충돌 자리가 구조로 사라지고, CLAUDE.md 가 두려워하는 「silent stale」 은 올림을 잊을 수 없으니
    일어날 수 없다. 공식 문서가 이 길을 정식으로 적는다(「To let users track commits instead, leave `version` out of both
    the manifest and the entry」).
    비용은 레포에 실측돼 있다 — CHANGELOG 판 헤딩 460개(RC11), 문서 전용 올림이 릴리스 노트를 건너뛴 두 건과 그것을 막는
    366줄 락(RC7), 판 리터럴 핀이 문서 전용 올림마다 stale-red 가 됐다는 테스트 주석(RC12).
    goal 의 「가벼운 길」 · 「글 줄이기」 기준에서 한 줄 수정에 판 올림과 CHANGELOG 항목이 붙는 의식은 가장 먼저 풀 대상이고,
    P4(추가보다 푸는 쪽)와 같은 방향이다. CLAUDE.md 가 제3자 설치를 아직 «확인되면» 의 일로 적는 지금(RC2)이 옮기는 값이
    가장 싼 때다.
premise_refutation:
  hits: [P6]
  why: >-
    P6 「공식 장치로 옮겨도 지금 장치가 사용자에게 주던 것이 유지된다」 는 「`version` 을 비워 커밋을 따라가게 한다」 갈래에서
    깨진다(캐시 신선도 한 가지만 유지 · 강화된다).
    (1) plugins/spec-distill/scripts/conductor_state.py `own_version` · `_check_writer` — `version` 이 문자열이 아니거나 비면
    `WriterStop("플러그인 판이 비어 있다 … 플러그인을 다시 설치한다")` 로 멈추고, 기계 상태 머리말의 writer 판이 지금 판보다
    크면 「이 기계 상태는 더 새 판이 썼다 — 플러그인을 업데이트하고 세션을 다시 연다」 로 막는다. 숫자 셋의 대소 비교라
    커밋 SHA 로는 성립하지 않는다 — 사용자가 받던 「옛 판이 새 판의 상태를 건드리지 못함」 이 사라진다.
    (2) plugins/spec-distill/scripts/conductor_ledger.py `version_report` — 설치본 `plugin.json` 의 `version` 에서 숫자 셋을
    못 뽑으면 rc 1 「판을 비교하지 못했다」, 뽑으면 「설치된 … 이 레포 사본 … 보다 옛 판이다 … 플러그인을 갱신하거나 레포
    사본으로 지휘한다」 를 낸다. 낡은 설치본 경고가 판 순서에 기댄다.
    (3) shared/deps/check_deps.py `_measure_row` 의 `quality-gates` 갈래가 그 플러그인 `plugin.json` 의 `version` 을 읽고,
    plugins/spec-distill/dependencies.md 는 「quality-gates | 14.6.0」 을 최소 판으로 둔다 — 판이 없으면 「판을 뽑지 못했다」 다.
    (4) https://code.claude.com/docs/en/plugins/dependencies — 공식 의존 장치도 같다: 태그는 `<plugin-name>--v<version>` 이고
    「`<version>` matches the `version` field in that commit's `plugin.json`」, npm · archive · command 소스에서는
    「a `plugin.json` that sets no version satisfies no constraint」.
    (5) CLAUDE.md 「호출 이름(slash 명령 · skill 이름)의 변경·제거는 alias 없이 즉시 하고 major bump 한다」 — 올릴 major 가
    없어지면 이 일이 하는 이름 바꾸기(S2 · S8)의 깨짐 신호가 사용자에게 가지 않는다.
    (6) https://code.claude.com/docs/en/plugins/loading — `version` 이 없으면 판은 「The commit SHA of the installed directory」
    이고 그 문자열이 캐시 폴더 이름이 된다. `claude plugin list` 의 판과 CHANGELOG 헤딩을 잇던 길이 끊긴다.
    「필수 키를 `name` 하나로」 갈래는 문면만 바꾸면 P6 에 닿지 않는다. 다만 실제로 `version` · `description` 을 빼는 순간
    (1)–(3)과 소개 문구 동등 락(RC9)이 같은 이유로 걸린다.
premise_list_challenge: >-
  결함 셋과 닫힌 경로 하나.
  (가) P6 은 ST1–ST3 세 항목에 한 문장으로 붙어 있어 이 항목에서는 둘로 갈린다 — 캐시 신선도는 유지되고(오히려 강해지고),
  순서 있는 판 번호에 기대는 것은 유지되지 않는다. 전제를 「캐시 갱신」 과 「판 순서 · 깨짐 신호」 로 나눠 적어야 판정이 선다.
  (나) 빠진 전제 — 「공식」 의 층위. trigger 는 「공식은 필수 키를 `name` 하나로 적는다」 만 들었는데, 같은 공식 자료에
  로더 바닥(`name`) · 검증기 경고선(`version` · `description` · `author`) · Anthropic 자기 플러그인의 관행(넷 다 적음) ·
  릴리스 방식 둘(「either increase `version` on each release or omit it」)이 함께 있다. 그래서 P3 의 「공식 쪽」 은 이
  항목에서 방향이 하나가 아니고, 「명시 판 + 릴리스마다 올림」 은 「공식과 다른 자리」 가 아니라 공식이 적은 두 길 중 하나다.
  devbrew 고유인 것은 「필수」 라는 낱말, 「PR 마다」 라는 단위, CHANGELOG · major 올림 규칙이다.
  (다) 빠진 전제 — 캐시 사본을 쓰는 사람이 누구인가. CLAUDE.md 는 제3자 설치를 「확인되면」 의 일로 적고, README 는 github
  소스 등록을 안내한다. 로컬 폴더로 더한 마켓플레이스면 플러그인이 제자리에서 읽혀 판 문자열이 갱신에 아무 일도 하지 않는다
  (공식 문서). 사용자가 어느 길로 설치해 쓰는지는 이 인터뷰에서 확인되지 않았고, 그 답이 「판 올림이 사용자에게 주던 것」 의
  크기를 정한다.
  (라) 닫힌 경로 — 「이 셋은 옮기지 않는다」 는 S10 이 고르지 않았으므로 대안으로 내지 않았다. 다만 `version` 키의 존재와
  CHANGELOG 판 헤딩 · major 올림 규칙에 한해서는 그 경로(그대로 둔다)가 최선이라 판단한다 — 이유는 위 P6 반증이다.
  항목 전체를 그대로 두는 것이 최선이라고는 보지 않는다(문면과 올림 단위는 풀 값이 있다).
  같은 입력을 다시 받은 것은 아니다 — 이 방향의 첫 dispatch 다.
recommendation: refined
refined_takes: >-
  (1) 필수 키 문면을 공식 층위에 맞춘다 — CLAUDE.md 「메타데이터 & 버전 관리」 와 docs/plugin-authoring.md 의 트리 주석에
  「로더가 요구하는 키는 `name` 하나」 를 적고, `version` · `description` 은 「필수」 가 아니라 devbrew 가 쓰는 이유(코드가 읽는
  판 · 마켓플레이스 소개 문구 동등 락)와 함께 적는다.
  (2) 「모든 PR마다」 의무를 푼다 — 기본은 설치본에 복사되는 내용(플러그인 폴더 + 링크로 배송되는 shared 정본)이 바뀌는
  머지마다 올림이고, 설치본 동작에 닿지 않는 변경은 이유를 적고 건너뛴다. 건너뛴 변경은 캐시 사본에 전달되지 않는다는 것을
  규칙이 함께 적는다. CHANGELOG 는 「올린 판마다 헤딩」 으로 따라가 지금 락(맨 위 헤딩 == `plugin.json` 판 · 건너뛴 판 없음)과
  그대로 맞는다.
  (3) 판을 머지 직전에 정하는 지금의 지휘 관행(RC10)을 규칙 문면으로 올려 병렬 에픽의 충돌 비용을 줄인다.
refined_drops: >-
  `version` 을 비워 커밋을 따라가게 하는 것. 필수 키에서 `version` 을 빼는 것(문면이 아니라 실물로). CHANGELOG 판 헤딩 규칙과
  호출 이름 변경 시 major 올림 규칙을 푸는 것.
evidence:
  - url: "https://code.claude.com/docs/en/plugins/loading"
    supports: both
    claim: >-
      「Versions and updates」 · 「How Claude Code computes the version」 원문. 판 계산 순서는 manifest `version` → 마켓플레이스
      entry `version` → 소스 종류이고, 「Relative path inside a Git-hosted marketplace | The commit SHA of the installed directory」.
      「a manifest that pins `"version": "1.0.0"` keeps every user on the cached copy until its author changes the string,
      however many commits they push. To let users track commits instead, leave `version` out of both the manifest and the entry.」
      「The version also names the plugin's cache directory.」 이전 판 폴더는 `.orphaned_at` 표시 뒤 14일 후 지워진다.
      자동 갱신 기본값은 공식 마켓플레이스만 켜짐이고 「off for every other marketplace」 다.
      로컬 경로 마켓플레이스의 상대경로 플러그인은 제자리에서 읽혀 「you don't need to increase the version」.
      문서는 그 「commit SHA」 가 저장소 HEAD 인지 그 폴더를 마지막으로 건드린 커밋인지 적지 않는다 — HEAD 라면 문서 전용
      커밋도 네 플러그인 모두의 새 판이 된다(확인 못 함).
    touches: [P6]
    decides: [OQ11]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/host-marketplace"
    supports: both
    claim: >-
      「Release a new version」 원문: 「either increase `version` on each release or omit it」 — 「Bump `version` on each release:
      users stay on their cached copy until the string changes. If you set `"version": "1.0.0"` and push new commits without
      changing it, users don't receive them.」 · 「Omit `version`: users track your commits instead.」 공식 문서는 두 길을 나란히
      적고 어느 쪽도 기본으로 권하지 않는다. 「Don't set `version` in both `plugin.json` and the marketplace entry.」
      자동 갱신은 「off for your marketplace by default, and `marketplace.json` has no field to turn it on」.
    touches: [P3]
    decides: [OQ11]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/manifest-reference"
    supports: both
    claim: >-
      「The manifest is optional.」 · 「`name` is the only required key.」 · `version`: 「A version string, not checked against
      semver. Setting it pins the plugin to that version until you change it」. 같은 페이지의 검증기 절: 「Validation passed with
      warnings: … a missing `version`, `description`, or `author`. Pass `--strict` to turn warnings into failures in CI」.
      `name` 하나는 로더의 바닥이고, 경고 없는 선은 `version` · `description` · `author` 를 포함한다.
    touches: [P3]
    decides: [OQ11]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/dependencies"
    supports: alternative
    claim: >-
      공식 의존 장치는 명시 판을 전제한다. 「Tag each release as `<plugin-name>--v<version>`, where `<version>` matches the
      `version` field in that commit's `plugin.json`.」 `claude plugin tag` 는 「builds the tag name from the plugin's manifest」.
      npm · archive · command 소스에서는 「a `plugin.json` that sets no version satisfies no constraint」. 상대경로 플러그인은
      맞는 태그가 없으면 마켓플레이스의 지금 사본을 쓰고 제약은 로드 때 그 사본의 판으로 검사한다.
    touches: [P6]
    decides: [OQ11]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/marketplace-reference"
    supports: both
    claim: >-
      entry `version`: 「When `plugin.json` also sets `version`, `plugin.json` takes precedence and `claude plugin validate`
      warns.」 검증 메시지 「Entry declares version "x" but <path>/plugin.json says "y". At install time, plugin.json wins」.
      상대경로 소스는 git · github · file · directory 마켓플레이스에서만 풀린다. `version` 을 비우려면 manifest 와 entry
      양쪽에서 빼야 한다는 loading 문서와 맞물린다.
    touches: []
    decides: [OQ11]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/agent-sdk-dev/.claude-plugin/plugin.json"
    supports: alternative
    claim: >-
      Anthropic 공식 플러그인의 manifest 원문이 `name` · `description` · `version`("1.0.1") · `author` 넷을 적는다.
      같은 저장소의 plugin-dev(0.1.2) · code-review(1.0.1)도 판을 적는다 — 이 둘은 요약 모델을 거쳐 확인했다.
      devbrew 의 필수 셋은 공식 플러그인의 실제 관행과 같은 자리다.
    touches: [P1]
    decides: [OQ11]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/.claude-plugin/marketplace.json"
    supports: both
    claim: >-
      공식 마켓플레이스 entry 가운데 읽은 범위(19만 자 중 앞 10만 자, entry 167개)에서 entry 층위에 `version` 을 적은 것은 7개다.
      entry 에서 판을 빼는 것은 흔하지만, 위 근거대로 상대경로 플러그인의 `plugin.json` 은 판을 적으므로 「공식 플러그인은 판을
      비운다」 의 근거는 되지 못한다. 파일 뒷부분은 읽지 못했다.
    touches: []
    decides: []
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/plugin-dev/skills/plugin-structure/SKILL.md"
    supports: both
    claim: >-
      CLAUDE.md 가 새 플러그인 설계의 기본 skill 로 지목한 `plugin-dev:plugin-structure` 는 필수 예시를 `{"name": "plugin-name"}`
      하나로 들고, 권장 메타데이터에 `version` · `description` 을 넣으며 「Version format: Follow semantic versioning
      (MAJOR.MINOR.PATCH)」 · 「Version consistently: Update version in plugin.json for releases」 라고 적는다(요약 모델 경유).
      필수는 `name` 하나, 판은 SemVer 로 릴리스마다 올림 — 두 케이스에 하나씩 닿는다.
    touches: [P3]
    decides: [OQ11]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://raw.githubusercontent.com/obra/superpowers/main/.claude-plugin/plugin.json"
    supports: alternative
    claim: >-
      devbrew 가 의존하는 superpowers 의 manifest 는 `"version": "7.0.2"` 를 명시한다. devbrew 의 `dependencies.md` 가
      superpowers 최소 판(7.0.0)을 잴 수 있는 것은 상류가 명시 판을 내기 때문이다 — 판을 비운 플러그인은 하류가 최소 판을
      적을 수 없다.
    touches: []
    decides: [OQ11]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "7.0.0 (plugins/spec-distill/dependencies.md, 2026-10-22)", latest: "7.0.2"}
    certainty: confirmed
  - url: "https://dev.classmethod.jp/articles/claude-code-plugin-update-not-applied/"
    supports: both
    claim: >-
      실패 사례. `plugin.json` 의 판을 올리지 않아 갱신 명령이 「already at the latest version」 을 내고 옛 동작이 남았다
      (「`plugin.json` のversionを上げていなかったためキャッシュが効いたままになっていました」). 글쓴이는 고친 길로 판 올림을,
      다른 길로 `version` 비우기를 들고, 비우면 판이 커밋 해시가 되어 읽을 수 있는 릴리스 신호를 잃으며 릴리스 주기가 정해진
      플러그인에는 명시 판이 맞다고 적는다. 원안에는 「잊은 올림은 실제로 난다」, 대안에는 「비우기의 값은 릴리스 신호」 로 닿는다.
    touches: []
    decides: [OQ11]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: confirmed
repo_claims:
  - id: RC1
    path: "CLAUDE.md"
    anchor: "모든 PR마다 SemVer bump가 붙는 `plugin.json`."
    claim: >-
      지금 규칙의 원문. 필수는 `name` · `description` · `version` 이고 올림 이유를 「안 그러면 cache key가 silent stale」 로 적는다.
      규칙이 댄 이유는 캐시 키 하나이고, 아래 RC3–RC6 이 보이는 「순서 있는 판」 의 쓰임은 규칙 문면에 없다.
    touches: []
    decides: [OQ11]
  - id: RC2
    path: "CLAUDE.md"
    anchor: "호출 이름(slash 명령 · skill 이름)의 변경·제거는 alias 없이 즉시 하고 major bump 한다."
    claim: >-
      호출 이름 변경의 깨짐 신호가 major 올림에 실린다. 같은 문단이 이 예외는 「제3자 설치가 확인되면(외부 이슈 · 설치 보고 ·
      마켓플레이스 공개 등록) 소멸한다」 고 적어 지금은 제3자 설치가 확인되지 않은 상태로 다룬다. `version` 이 없으면 이 규칙이
      올릴 대상이 없다 — 이 일은 호출 이름 둘을 바꾼다(S2 · S8).
    touches: [P6]
    decides: [OQ11]
  - id: RC3
    path: "plugins/spec-distill/scripts/conductor_state.py"
    anchor: "own_version"
    line: 102
    claim: >-
      `own_version()` 은 `.claude-plugin/plugin.json` 의 `version` 을 읽고, 문자열이 아니거나 비면
      `WriterStop("플러그인 판이 비어 있다: … — 플러그인을 다시 설치한다")` 를 던진다. `_check_writer`(123행)는 기계 상태 머리말의
      writer 판과 지금 판을 숫자 셋으로 비교해 `wrote > triple` 이면 「이 기계 상태는 더 새 판이 썼다」 로 멈춘다. 기계 상태를 쓸
      때(247행) `writer: <이름> <판>` 을 찍는다. `version` 을 비우면 지휘자의 기계 상태 쓰기가 멈춘다.
    touches: [P6]
    decides: [OQ11]
  - id: RC4
    path: "plugins/spec-distill/scripts/conductor_ledger.py"
    anchor: "version_report"
    line: 388
    claim: >-
      설치본 `plugin.json` 과 레포에 추적되는 같은 이름의 `plugin.json` 의 `version` 을 숫자 셋으로 비교한다. 설치본 판을 못 읽으면
      rc 1 「판을 비교하지 못했다 — 설치본 판 … 을 읽지 못했다」, 레포 쪽이 크면 rc 1 「설치된 … 이 레포 사본 … 보다 옛 판이다 …
      플러그인을 갱신하거나 레포 사본으로 지휘한다」. 하위 명령 `version --plugin-json` 으로 노출된다(1425행).
      plugins/spec-distill/references/conducting.md 14행이 `--plugin-json` 과 「옛 판」 을 담는 것은 grep 으로 확인했고 그 행
      전문은 읽지 못했다.
    touches: [P6]
    decides: [OQ11]
  - id: RC5
    path: "shared/deps/check_deps.py"
    anchor: "_measure_row"
    line: 250
    claim: >-
      `quality-gates` 행의 판은 `<plugin_root>/../quality-gates/.claude-plugin/plugin.json` 의 `version` 에서 잰다. 문자열이 아니거나
      숫자 셋이 없으면 「quality-gates 의 plugin.json 에서 판을 뽑지 못했다」 를 낸다.
    touches: [P6]
    decides: [OQ11]
  - id: RC6
    path: "plugins/spec-distill/dependencies.md"
    anchor: "| quality-gates | 14.6.0 | 2026-10-22 | 알림 |"
    line: 18
    claim: >-
      플러그인 사이 최소 판이 SemVer 로 적혀 있다. 같은 표의 superpowers 행(7.0.0)도 상류의 명시 판에 기댄다.
    touches: [P6]
    decides: [OQ11]
  - id: RC7
    path: "shared/tests/test_changelog_integrity.sh"
    anchor: "C2 맨 위 헤딩 버전 == plugin.json 버전."
    line: 62
    claim: >-
      366줄 락이 C1(판 1.0.0 이상이면 CHANGELOG 필수) · C2 · C3(순감소) · C4(헤딩 형식) · C5(건너뛴 판 없음)를 잰다.
      `plugin.json` 에서 SemVer 를 못 뽑으면 통과가 아니라 RED 다(197–200행 「추출 실패를 '문제 없음'으로 읽지 않는다」).
      머리 주석(29–37행)은 문서 전용 올림 두 건(project-init 1.7.1 · spec-distill 0.11.1)이 「실제로 배포된 버전인데 릴리스 노트를
      안 쓴」 경우라고 기록한다. 「PR 마다 올렸는가」 를 PR diff 와 대조하는 검사는 `**/*.{sh,py,js,json}` 의 `bump` 검색 범위에서
      찾지 못했다 — 올림 의무 자체는 문면 규칙이고 기계 게이트가 아니다.
    touches: []
    decides: [OQ11]
  - id: RC8
    path: "plugins/plugin-audit/scripts/check-shape-completeness.py"
    anchor: "plugin_json_fields"
    line: 44
    claim: >-
      plugin-audit 의 모양 점검이 `name` · `version` · `description` 셋이 모두 있고 `version` 이 문자열일 때만 통과로 적는다
      (출처 칸 「CLAUDE.md §메타데이터」). 같은 플러그인의 check-staleness.py 는 CHANGELOG 최신 헤딩과 `plugin.json` 판이 다르면
      낡음으로 낸다(269–274행). 필수 키를 실물로 줄이면 이 둘이 함께 바뀐다.
    touches: []
    decides: [OQ11]
  - id: RC9
    path: "shared/tests/test_plugin_description_parity.sh"
    anchor: "plugin.json 에 소개 문구가 없다"
    line: 50
    claim: >-
      플러그인마다 `plugin.json` 의 `description` 이 마켓플레이스 entry 의 소개 문구와 글자까지 같아야 하고, `plugin.json` 에
      소개 문구가 없으면 RED 다. `description` 을 필수에서 실물로 빼면 이 락이 걸린다.
    touches: []
    decides: [OQ11]
  - id: RC10
    path: "plugins/spec-distill/scripts/repo_defaults.py"
    anchor: "SHARED_FILES"
    line: 28
    claim: >-
      `SHARED_FILES = ("plugin.json", "CHANGELOG.md", "README.md")` — 주석 「에픽이 함께 건드려 겹치기 쉬운 공유 파일 이름」.
      plugins/spec-distill/scripts/roadmap_status.py 59행은 이 셋을 경로 예약 겹침 · 위반에서 빼며 「버전은 머지 직전에 정한다(N6)」
      라고 적는다. conducting.md 는 「공유 파일 · 코퍼스 락이 둘째 PR 에서만 깨지면 둘째 PR 에서 고치고」 를 둔다. 새 코어의 병렬
      에픽에서 판 줄과 CHANGELOG 머리가 충돌 자리라는 것을 지휘 코드가 이미 안다.
    touches: []
    decides: [OQ11]
  - id: RC11
    path: "plugins/spec-distill/CHANGELOG.md"
    anchor: "## [8.13.1] — 2026-10-30"
    line: 3
    claim: >-
      `^## \[` 헤딩 수는 spec-distill 179 · quality-gates 204 · project-init 42 · plugin-audit 35, 합 460 이다. 같은 파일 29행
      「patch 인 이유 — 링크로 배송하는 `scripts/codex_findings_to_yaml.py`(정본 `shared/codex/`)가 바뀌었다」 는 올림의 실제
      방아쇠가 「플러그인 폴더」 보다 넓은 「설치본에 복사되는 내용」 임을 보인다.
    touches: []
    decides: [OQ11]
  - id: RC12
    path: "plugins/spec-distill/tests/test_readme_sync.sh"
    anchor: "\"플러그인 건드리는 모든 PR은 patch-bump\" 규칙 때문에 리터럴 patch pin은 다음 doc-only"
    line: 10
    claim: >-
      판 리터럴을 핀한 테스트가 문서 전용 올림마다 stale-red 가 된 전례를 주석이 기록하고, 그래서 판 단언을 하한(0.26 이상)으로
      바꿨다. test_changelog_integrity.sh 45–47행도 같은 전례를 든다. PR 마다 올림이 낳은 반복 비용의 레포 안 기록이다.
    touches: []
    decides: [OQ11]
  - id: RC13
    path: ".claude-plugin/marketplace.json"
    anchor: "\"source\": \"./plugins/quality-gates\""
    line: 12
    claim: >-
      네 entry 모두 상대경로 소스이고 entry 층위 `version` 은 없다. 레포 README.md 는 github 소스(`Jeongho-K/devbrew`)로 등록하라고
      안내한다. 따라서 `plugin.json` 에서 `version` 을 빼면 공식 표의 「Relative path inside a Git-hosted marketplace」 행이 그대로
      적용된다 — entry 쪽에서 더 지울 것은 없다.
    touches: []
    decides: [OQ11]
  - id: RC14
    path: "plugins/spec-distill/.claude-plugin/plugin.json"
    anchor: "\"version\": \"8.13.1\""
    line: 4
    claim: >-
      네 플러그인의 manifest 가 모두 `name` · `description` · `version` · `author` 를 적는다(spec-distill 8.13.1 · quality-gates
      14.8.1 · project-init 5.4.1 · plugin-audit 1.7.0). 공식 검증기의 경고 없는 선(`version` · `description` · `author`)을 이미 넘는다.
    touches: []
    decides: [OQ11]
  - id: RC15
    path: "docs/plugin-authoring.md"
    anchor: "plugin.json           # 필수 — name, version (0.1.0로 시작), description"
    line: 10
    claim: >-
      저술 가이드의 트리 주석이 같은 필수 셋을 적고, 12행은 「CHANGELOG.md # version ≥ v1.0.0이면 필수」 다. 48행은 `plugin-dev` 가
      주는 것은 문법이고 devbrew 정책은 이 문서가 우선한다고 적는다. 문면을 고칠 자리는 CLAUDE.md 와 이 두 줄이다(P5).
    touches: [P5]
    decides: [OQ11]
# repo root: /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit
```
~~~~

### 조사 7 — steelman-builder · R3 · 묶음 5

~~~~
case_for_alternative:
  statement: >-
    agent frontmatter 의 `model` 키 금지를 그대로 둔다 — agent 마다 티어를 달리해야 하면 사용자 소유 설정값을 dispatch 인자로 넘기는, 지금 있는 길(`review_model` 꼴)을 쓴다.
  strongest: >-
    goal(S4)의 네 축(넘기는 곳 · 글 줄이기 · 가벼운 길 · 이름) 가운데 이 키를 요구하는 축이 없다. 키를 열면 부재를 단언하는 락 파일 최소 12개와 qg README · qg 공시 줄 · 저술 가이드가 이 일에 얹혀, 네 축이 같은 무게로 가야 할 일에 다섯째 짐이 생긴다.
    지금 상태는 「공식과 다른 장치」가 아니다. 공식 문서의 기본값이 키 없음이고(`model` 은 필수가 아니며 생략하면 공식 순서대로 고른다), devbrew agent 20개는 이미 공식 그대로다. 옮길 대상이 산출물에는 없고 저술 정책에만 있다.
    키 없음은 CLI 판이 바뀌어도 뜻이 같은 유일한 설정이다. 공식 환경변수 표에 따르면 2.1.251 앞에서는 환경변수가 정의의 `model` 을 이겼고 뒤에서는 정의가 이긴다. 키가 없으면 두 시기 모두 「사용자 환경변수 → 세션 모델」이다.
    사용자 레버 하나(`CLAUDE_CODE_SUBAGENT_MODEL`)가 20개 전부에 닿고, qg 가 매 반복 찍는 「리뷰어 모델」 공시 줄이 참으로 남는다. agent 별 티어는 이미 우선순위 1번 자리(dispatch 인자)에서 사용자 설정값 `review_model` 로 준다 — 정의에 값을 박지 않고도 된다.
    정의에 박은 값의 실패 사례가 upstream 에 쌓여 있다: 플러그인 agent 의 `model` 이 frontmatter 파싱 실패 때 오류 없이 빠진다는 열린 보고, 별칭이 Vertex 에서 옛 모델로 풀린다는 보고, 플러그인이 실은 agent 의 한 칸을 설치 사용자가 바꾸려면 파일을 통째로 복사해야 한다는 요청(비활동으로 닫힘).
    사용자는 이 주제에서 두 번(2026-09-06 · 2026-10-17) 고정을 푸는 쪽으로 결정했다.
case_for_current:
  strongest: >-
    키 금지는 이 레포가 진 무게다 — 절대 금지 한 줄, 부재 락 최소 12개 파일, 변이 락 하나, plugin-dev 검증기가 `model` 없는 agent 에서 죽는 것을 감싸는 plugin-audit 분기. 금지를 풀면 저술 가이드 22행의 실측 이력 문장(판 · 날짜 · 설계문서 경로)이 사라지고(글 줄이기), 새 코어가 역할마다 값싼 티어를 정의 한 줄로 실을 수 있다(가벼운 길). 공식 문서가 subagent 의 쓸모로 드는 것이 바로 「더 빠르고 싼 모델로 일을 보내 비용을 줄인다」다.
    공식 문서는 `model` 을 플러그인 agent 지원 필드로 싣고, 예시 플러그인의 `security-reviewer` agent 에 `model: sonnet` 을 쓴다. 공식 플러그인도 고정한다(pr-review-toolkit `code-reviewer` 는 `model: opus`, feature-dev `code-explorer` 는 `model: sonnet`). 금지 · 비권장 문구는 없다.
    절대 금지는 레포 자신의 꼴과 어긋난다. 철학 P8 은 규칙을 「기본은 X, 일의 모양이 다르면 판단하고 이유를 적는다」로 쓰라 하고 결정론은 보안 · 정확성 게이트에만 두라 한다. 티어 선택은 그 게이트가 아니다. 2026-10-08 사용자 지시 「리뷰는 opus」는 이 규칙을 재결정으로 넘어야 했다 — 절대형이 사용자 자신의 요구와 이미 한 번 부딪혔다.
    사용자가 잃는 것은 되돌릴 수 있다. `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` 이 정의의 `model` 을 무시하게 하고(공식 문서 · 레포 실측 F4), dispatch 인자는 여전히 정의보다 앞선다. 이 레포는 제3자 설치를 확인된 사실로 두지 않으므로 agent 정의를 쓰는 사람과 환경변수를 정하는 사람이 같다 — 정의의 키도 사용자의 선택이고 git 으로 되돌린다. 환경변수 하나는 20개를 한 값으로만 묶지만 키는 agent 마다 다르게 준다.
    S10 에서 사용자는 「적으면 환경변수로 정한 기본 모델을 덮는다」는 결과를 읽고 골랐다.
premise_refutation:
  hits: [P6]
  why: >-
    P6 「공식 장치로 옮겨도 지금 장치가 사용자에게 주던 것이 유지된다」 —
    (1) https://code.claude.com/docs/en/env-vars 의 `CLAUDE_CODE_SUBAGENT_MODEL` 행: 「Two sources take precedence over it: a model Claude passes when it spawns the agent, and a `model` field in the agent's definition, including `inherit`.」 https://code.claude.com/docs/en/sub-agents 「Choose a model」의 순서도 같다(정의의 `model` 이 2번, 환경변수가 3번). 지금 장치가 주던 것은 「환경변수 하나가 devbrew agent 20개 전부에 닿는다」인데, 키를 든 agent 에는 그 환경변수가 닿지 않는다. 레포 실측 F2(docs/superpowers/specs/2026-09-06-agent-model-unpin-design.md 「A. 측정 여섯」)가 `inherit` 에 대해 같은 결과를 CLI 2.1.261 에서 쟀다.
    (2) plugins/quality-gates/skills/quality-pipeline/SKILL.md 의 공시 줄 `echo "> [quality-gates] 리뷰어 모델: ${CLAUDE_CODE_SUBAGENT_MODEL:-세션 모델}…"` 은 환경변수만 보고 값을 낸다. 키를 든 리뷰어가 생기면 이 줄은 실제와 다른 모델을 알린다 — 사용자에게 주던 정확한 공시가 유지되지 않는다.
    (3) 되찾는 길 `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` 은 전부 아니면 전무다: 공식 문서 「While `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` is on, Claude Code ignores the `model` field in subagent definitions, and Claude can't pass a model when it starts a subagent.」 dispatch 인자 길(`review_model`)까지 함께 막는다. 레포 README 는 이 변수를 권하지 않는다.
    범위: 키를 «허용»만 하고 어느 agent 도 쓰지 않는 동안에는 P6 이 참이다. 충돌은 키를 실제로 든 agent 부터 생긴다.
premise_list_challenge: >-
  (1) P6 은 orchestrator 가 도출한 전제인데, S10 선택지 설명이 이미 그 반대(「적으면 사용자가 환경변수로 정한 하위 agent 기본 모델을 덮는다」)를 사용자에게 알렸다. 이 항목에서 P6 은 사용자가 믿고 고른 전제가 아니라 알고 넘은 전제다 — 위 hit 는 새 사실이 아니라 이미 알린 사실의 원문 확인이다.
  (2) 빠진 전제 셋. (가) 이 주제의 가장 최근 사용자 결정 — 2026-10-17 「qg 리뷰어 모델 opus 고정 → 세션 모델을 따르게(사용자 결정)」. 키 허용이 판정에 들어가는 agent 에도 미치는지 묻지 않았다. (나) CLAUDE.md 상시 원칙 「레포 전용 값 금지. 경로 · 테스트 명령 · 브랜치 · 모델 같은 값은 도출하거나 레포마다 정하게 한다」 — 리터럴 티어를 플러그인 agent 에 적는 것과 바로 닿고, 허용하려면 이 줄과 맞춰야 한다. (다) 2026-09-06 수용 근거 「하향을 하니스가 아니라 사용자가 고르고 되돌릴 수 있다」.
  (3) P3 의 분류가 이 항목에는 헐겁다. S9 항목(최상위 `cost_class` · `integrity`)은 산출물이 공식 밖 자리에 있었다. 여기는 산출물이 공식 기본값 그대로이고 저술 정책만 공식보다 좁다 — 「공식과 다른 자리」보다 「공식보다 좁게 쓰는 자리」다.
  (4) goal(S4)의 네 축에 `model` 키가 없다. 이 방향은 goal 이 아니라 S6 갈래에서 나왔고, goal 만으로 재면 양쪽 다 약하게 닿는다.
  (5) 규칙 22행의 앞 절 「리터럴 티어는 세션의 모델 선택을 덮어쓰고」는 2026-09-06 측정 여섯에 없다 — 그 표는 키 없음과 `inherit` 만 쟀다. 리터럴 티어 대 환경변수는 공식 문서 서술에만 기대고, 2.1.303 이후 재실측은 없다(이 dispatch 는 읽기 전용이라 재지 않았다).
  (6) 대안이 S10 의 고르지 않은 첫 선택지와 겹친다. OQ10 이 바로 그 재검토라 냈다. 같은 입력을 다시 받은 것은 아니다.
recommendation: refined
refined_takes: >-
  금지를 푼다는 것. 규칙을 「기본은 `model` 키를 두지 않는다. 일의 모양이 다르면 둘 수 있고, 둘 때는 그 agent 가 사용자의 `CLAUDE_CODE_SUBAGENT_MODEL` 을 덮는다는 사실과 이유를 그 플러그인 README 에 적는다」 꼴로 다시 쓴다 — 사용자가 2026-10-17 에 정한 고치는 꼴(「언제나 X」 → 「기본은 X, … 무엇을 왜 골랐는지 적는다」)과 같다. 22행의 실측 이력 서술(판 · 날짜 · 설계문서 경로)은 걷어낸다. `model` 이 공식 지원 필드라는 사실을 가이드에 그대로 둔다. 절대 부재 단언은 「키가 있으면 공시가 있다」 쪽으로 바꾸되 락의 꼴은 설계가 정한다.
refined_drops: >-
  기본값 없는 전면 허용(「공식처럼」 정책 없이 여는 것). 지금 agent 20개에 키를 더하는 것 — plugin-dev 검증기를 통과시키려는 `inherit` 일괄 추가 포함(환경변수를 다시 막는다, F2). 판정에 들어가는 qg 리뷰어 둘의 티어를 이 일에서 다시 고정하는 것(2026-10-17 사용자 결정은 사용자가 따로 뒤집을 때까지 그대로). 부재 락을 대체 없이 지우는 것. qg 공시 줄이 환경변수만 보는 채로 키 든 리뷰어를 부르는 것.
evidence:
  - url: "https://code.claude.com/docs/en/sub-agents"
    supports: both
    claim: >-
      「Choose a model」 원문 — 「By default, a subagent you define runs on the same model as the conversation that starts it.」 순서는 1. per-invocation `model` parameter 2. 「The `model` field in the subagent's definition, including `inherit`」 3. `CLAUDE_CODE_SUBAGENT_MODEL` 4. main conversation's model. frontmatter 표의 `model` 행은 Required 「No」, 「When you omit it, Claude Code picks the model in the subagent model order」. FORCE: 「While `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` is on, Claude Code ignores the `model` field in subagent definitions, and Claude can't pass a model when it starts a subagent.」(v2.1.257 이상). 쓸모: 「Control costs by routing tasks to faster, lower-cost models like Haiku」. 플러그인 agent 의 `model` 을 금지 · 비권장하는 문구는 없다. 페이지 116,580자 가운데 앞 10만 자만 읽었다.
    touches: [P6, P3]
    decides: [OQ10]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303 (plugins/*/dependencies.md 의 claude-code 행)", latest: "확인 못 함 — 이 dispatch 에서 다시 재지 않았다"}
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/env-vars"
    supports: alternative
    claim: >-
      `CLAUDE_CODE_SUBAGENT_MODEL` 행 원문 — 「The default model for subagents, agent team teammates, and workflow agents that aren't assigned a model another way. … Two sources take precedence over it: a model Claude passes when it spawns the agent, and a `model` field in the agent's definition, including `inherit`. … Setting it to `inherit` is the same as leaving it unset. Before v2.1.251, this variable overrode both the per-invocation model and the definition's `model` field」. 정의에 키가 있으면 사용자 환경변수가 그 agent 에 닿지 않고, 그 우선순위 자체가 2.1.251 에서 뒤집혔다. 키가 없으면 두 시기 모두 환경변수 → 세션 모델이다.
    touches: [P6]
    decides: [OQ10]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/components"
    supports: current
    claim: >-
      「Frontmatter fields in plugin agents」 원문 — 「Supported fields: `name`, `description`, `model`, `effort`, `maxTurns`, …」, 「Ignored fields: `permissionMode`, `hooks`, `mcpServers`, and `initialPrompt`」. 같은 페이지의 예시 플러그인 agent `security-reviewer` 는 frontmatter 에 `model: sonnet` 을 쓴다. `model` 을 권하거나 말리는 문장은 없다.
    touches: [P3]
    decides: [OQ10]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/pr-review-toolkit/agents/code-reviewer.md"
    supports: current
    claim: >-
      공식 플러그인 pr-review-toolkit 의 `code-reviewer` agent 는 frontmatter 에 `model: opus` 를 둔다(`tools` 키는 없다). WebFetch 의 요약 모델을 거친 값이다.
    touches: [P3]
    decides: [OQ10]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/feature-dev/agents/code-explorer.md"
    supports: current
    claim: >-
      공식 플러그인 feature-dev 의 `code-explorer` agent 는 frontmatter 에 `model: sonnet` 을 둔다. WebFetch 의 요약 모델을 거친 값이다.
    touches: [P3]
    decides: [OQ10]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/79866"
    supports: alternative
    claim: >-
      「Configure a subagent's model and effort from settings, without forking its prompt (plugin-shipped agents)」 — 2026-07-21 열림, 2026-09-17 비활동으로 닫힘(not planned, 메인테이너 답 없음). 원문: 「the only supported way to change one field of a subagent you did not author is to copy its entire markdown file — prompt body and all — into `.claude/agents/`.」 agent 별 설정 맵은 없다. 플러그인 정의에 박힌 값을 설치 사용자가 agent 하나만 골라 바꾸는 길은 파일 복사뿐이다(모델은 환경변수 · dispatch 인자로도 닿지만 환경변수는 정의의 키에 진다).
    touches: [P6]
    decides: [OQ10]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://github.com/anthropics/claude-code/issues/89723"
    supports: alternative
    claim: >-
      「Plugin subagents: `model:` frontmatter in a plugin's agents/*.md is ignored」 — 2026-08-26 열림, 지금 열려 있음, 메인테이너 답 없음. 커뮤니티 댓글의 측정(CLI 2.1.263 · 2.1.296): frontmatter 가 YAML 로 파싱되지 않으면(따옴표 없는 description 안의 「: 」) 플러그인 로더가 블록 전체를 버리고 agent 는 오류 없이 부모 모델로 돈다. 정의의 `model` 은 적혀 있어도 조용히 안 먹을 수 있다.
    touches: []
    decides: [OQ10]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://github.com/anthropics/claude-code/issues/36242"
    supports: alternative
    claim: >-
      「Vertex/Bedrock subagents silently downgraded to older models (not fully fixed)」 — 2026-03-19 열림, CLI 2.1.76, 비활동으로 닫힘. Vertex 에서 sonnet 하위 agent 가 부모와 다른 옛 판으로 풀린다는 보고. 별칭으로 적은 티어는 제공자에 따라 다른 모델이 된다. 오래된 판의 보고이고 지금 판에서 다시 확인하지 않았다.
    touches: []
    decides: [OQ10]
    source_kind: secondary
    checked_at: "2026-11-14"
    certainty: uncertain
repo_claims:
  - id: RC1
    path: "docs/plugin-authoring.md"
    anchor: "**agent frontmatter 에 `model` 키를 두지 않는다.**"
    line: 22
    claim: >-
      규칙은 예외 없는 금지이고 근거를 P8 위반으로 적는다. 규칙 문장 안에 실측 판(CLI 2.1.261) · 날짜(2026-09-06) · 설계문서 경로가 들어 있다. 하위 bullet(23행)은 dispatch 인자를 오케스트레이터 재량으로 두되 게이트 판정 · 측정에 들어가는 agent 에는 넘기지 않게 한다.
    touches: [P4, P5]
    decides: [OQ10]
  - id: RC2
    path: "docs/superpowers/specs/2026-09-06-agent-model-unpin-design.md"
    anchor: "A. 측정 여섯"
    line: 43
    claim: >-
      CLI 2.1.261 실측: 키 없는 agent 는 환경변수 → 세션 모델(F1), `model: inherit` 는 환경변수를 무효화(F2), `_FORCE=1` 은 `inherit` 까지 덮는다(F4). 프로브는 `probe-nomodel` 과 `probe-inherit` 둘뿐이라 리터럴 티어 대 환경변수는 이 표에 없다. dispatch 인자 대 환경변수(U1)와 FORCE 의 범위(U2)는 미실측으로 적혀 있다. 사용자는 「환경변수를 켠 세션에서 리뷰어가 writer 보다 약해진다」는 트레이드오프를 수용했다.
    touches: [P6]
    decides: [OQ10]
  - id: RC3
    path: "plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh"
    anchor: "예외는 없다 — qg 리뷰 agent 도 키가 없다(R2a 사용자 결정 「세션 모델을 따른다」)"
    line: 8
    claim: >-
      스윕은 `plugins/*/agents/*.md` 의 frontmatter 에 `model` 키가 하나라도 있으면 RED 이고, qg README 의 문장 「모델을 고정하지 않는다 — `CLAUDE_CODE_SUBAGENT_MODEL` 이 있으면 그 값, 없으면 세션 모델을 따른다.」의 실재도 단언한다. 키를 허용하면 이 락은 규칙과 모순된다.
    touches: [P6]
    decides: [OQ10]
  - id: RC4
    path: "plugins/quality-gates/tests/test_agent_model_mutation.sh"
    anchor: "pairs=("
    line: 24
    claim: >-
      변이 락이 스윕과 per-agent 락 8개 파일(security_reviewer_persona · code_recritic_frontmatter · artifact_critic_frontmatter · artifact_adversarial_frontmatter · blind_spot_prober_frontmatter · coverage_mapper_frontmatter · steelman_builder_scope · brief_agents)이 키 삽입에 RED 임을 증명한다. 여기에 규약 문장 락(`test_governance_no_capability_caps.sh` 의 AC8d — `NEW_RULE` 리터럴)과 `shared/tests/test_docreview_agents.sh`(「frontmatter 에 model 키 없음(main 규약)」)를 더하면 키 부재를 단언하는 락 파일이 최소 12개다. 키 허용은 이들을 뒤집거나 지우는 일을 낳는다.
    touches: [P4]
    decides: [OQ10]
  - id: RC5
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "echo \"> [quality-gates] 리뷰어 모델: ${CLAUDE_CODE_SUBAGENT_MODEL:-세션 모델}"
    line: 372
    claim: >-
      qg 가 매 반복 찍는 리뷰어 모델 공시 줄은 환경변수만 보고 값을 낸다. 리뷰어 정의에 `model` 키가 생기면 이 줄은 실제와 다른 모델을 알린다. 이 줄의 문면은 `plugins/quality-gates/tests/test_skill_run_contract.sh` 215행이 글자 그대로 고정한다.
    touches: [P6]
    decides: [OQ10]
  - id: RC6
    path: "plugins/quality-gates/README.md"
    anchor: "**Choosing a cheaper tier for devbrew subagents is the user's call, not the plugin's.**"
    line: 141
    claim: >-
      README 가 사용자에게 「티어를 고르는 것은 플러그인이 아니라 사용자」라고 약속하고 `~/.claude/settings.json` 의 `env` 예시를 준다. `_FORCE=1` 은 존재만 적고 권하지 않는다고 적는다.
    touches: [P6]
    decides: [OQ10]
  - id: RC7
    path: "docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md"
    anchor: "K1. 리뷰는 opus 다."
    line: 102
    claim: >-
      2026-10-08 사용자 지시 「리뷰는 opus」로 qg 소유 리뷰 agent 둘을 `model: opus` 로 고정했다. 같은 문서 재결정 표의 R3 행이 「qg agent 에 모델 키 없음(agent-model-unpin)」 → 「qg 소유 리뷰 agent 는 `model: opus`」로 적는다 — 절대 금지 규칙이 사용자 요구로 한 번 넘어졌다.
    touches: []
    decides: [OQ10]
  - id: RC8
    path: "docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md"
    anchor: "리뷰어 모델 opus 고정 둘"
    line: 107
    claim: >-
      2026-10-17 처분 「제거 — 세션 모델을 따른다(사용자 결정, `flexibility-audit.md`)」. qg CHANGELOG 14.1.0(2026-10-19) 「리뷰어 모델 고정(`model: opus`)을 풀어 `CLAUDE_CODE_SUBAGENT_MODEL`, 없으면 세션 모델을 따른다.」로 실렸다. 이 주제의 가장 최근 사용자 결정이고 전제 목록에 없다.
    touches: []
    decides: [OQ10]
  - id: RC9
    path: "docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/flexibility-audit.md"
    anchor: "고치는 꼴: 「언제나 X」 를 「기본은 X, 일의 모양이 다르면 모델이 판단해 고르고 무엇을 왜 골랐는지 적는다」 로."
    line: 5
    claim: >-
      사용자가 정한 고치는 꼴이고, 9행의 사용자 원문 「넷 모두 기본값 + 모델 판단으로: … qg 리뷰어 모델 opus 고정 …」이 모델 고정을 그 꼴의 대상으로 든다. 절대 금지를 「기본은 키 없음」으로 바꾸는 것은 이 꼴과 같다.
    touches: [P4]
    decides: [OQ10]
  - id: RC10
    path: "CLAUDE.md"
    anchor: "**레포 전용 값 금지.** 경로 · 테스트 명령 · 브랜치 · 모델 같은 값은 도출하거나 레포마다 정하게 한다(철학 P8)."
    line: 31
    claim: >-
      상시 원칙이 「모델」을 박지 말아야 할 값으로 이름 붙여 든다. 플러그인 agent 정의에 리터럴 티어를 적는 것은 이 줄과 바로 닿는다. `plugins/spec-distill/tests/test_conducting_reference.sh` 395–397행은 `review_model: opus` · `review_model: sonnet` · 「haiku 로 부른다」를 금지 리터럴의 양성 대조로 쓴다.
    touches: []
    decides: [OQ10]
  - id: RC11
    path: "plugins/spec-distill/skills/epic-conductor/SKILL.md"
    anchor: "모델 칸은 해결자 `repo_defaults.py get review_model --roadmap <로드맵>` 의 값이 이 dispatch 의 모델 칸이 받는 이름일 때만 그 값을 준다."
    line: 173
    claim: >-
      agent 하나에만 다른 티어를 주는 길이 이미 있다 — 사용자가 레포 설정에 적은 `review_model` 을 통합 리뷰어 dispatch 의 `model` 인자로 넘기고, 값이 없으면 인자를 빼 세션 모델로 가며 그 사실을 알린다. 정의에 값을 박지 않고 공식 순서의 1번 자리를 쓴다.
    touches: [P6]
    decides: [OQ10]
  - id: RC12
    path: "plugins/plugin-audit/scripts/check-plugin-structure.sh"
    anchor: "has_model_key()"
    line: 63
    claim: >-
      plugin-dev 의 `validate-agent.sh` 가 `model` 키 없는 agent 에서 ❌ 줄 없이 rc=1 로 죽어, devbrew 는 그 경우를 집계 한 줄로 묶는 분기를 따로 진다. 키 금지가 낳은 유지 비용이다. 규칙만 풀고 agent 가 키를 들지 않으면 이 분기는 그대로 남는다.
    touches: [P4]
    decides: [OQ10]
  - id: RC13
    path: "plugins/quality-gates/agents/security-reviewer.md"
    anchor: "frontmatter (model 키 없음)"
    claim: >-
      `plugins/*/agents/*.md` 20개(Glob) 어디에도 frontmatter `model` 줄이 없다(Grep `^model:` 0건 — Grep · Glob 은 심볼릭 링크를 건너뛰므로 20 은 하한이다). 산출물은 공식 기본값(키 생략) 그대로다.
    touches: [P3]
    decides: [OQ10]
  - id: RC14
    path: "CLAUDE.md"
    anchor: "이 예외는 제3자 설치가 확인되면(외부 이슈 · 설치 보고 · 마켓플레이스 공개 등록) 소멸한다."
    line: 49
    claim: >-
      레포 규칙이 제3자 설치를 아직 확인되지 않은 조건으로 다룬다. agent 정의를 쓰는 사람과 환경변수를 정하는 사람이 같다는 원안 쪽 논거의 근거이고, 그 조건이 깨지면 논거도 함께 깨진다. 줄번호는 다시 재지 않은 보조 값이다.
    touches: []
    decides: [OQ10]
# 확인 못 함: (1) 2.1.303 이후 판에서 해석 순서 재실측(읽기 전용 dispatch). (2) 공식 changelog 의 2.1.251 · 2.1.325 항목 원문 — env-vars 행의 「Before v2.1.251」 문장으로만 확인. (3) 옆 세션의 팀 파일 규약 설계문서(이 worktree 에 없음) — 새 코어가 역할별 티어를 요구하는지는 읽지 못했다.
# 읽은 자리(절대 경로): /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/plugin-authoring.md · /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/specs/2026-09-06-agent-model-unpin-design.md · /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh · /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/tests/test_agent_model_mutation.sh · /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/interview/2026-11-14-framing-interview-constraint-audit-brief-interview.state.md (조사 3 · 5 · 6)
~~~~

### 조사 10 — blind-spot-prober · R3 · 묶음 5

~~~~
계약(`<claims_contract>`)은 받았다. 전제 목록은 받지 않아 `touches` 는 전부 빈 배열이다. `decides` 는 OQ10–OQ12 가운데 실제로 닿는 한 곳(OQ11)에만 붙였고 나머지는 비웠다. `id` 는 임시값이다.

가장 무거운 발견 셋을 먼저 적는다.

- **S3 의 근거 문장이 옆 설계문서에서 사라졌다.** R1 질문 2 가 사용자에게 보인 「그 로드맵이 `source_interview` 키와 `intent/` 에 바로 쓰기를 정한다」 는 지금 판에 없다(Grep 0건). 문서는 740줄에서 771줄이 됐고, 남은 문장은 「R5 가 받고, 앞단을 고치는 다른 로드맵이 먼저 하면 R5 는 확인만 한다」 다(RC6).
- **원자료 글자 그대로와 P21 이 부딪친다.** request-framing 에는 secret 치환이 없고, 옆 설계의 AC4 · AC5 는 `original.md` 의 앞 줄 수정과 바이트 차이를 거절한다(RC3 · RC4 · RC5).
- **의역은 질문 · 선택지를 쓰는 자리에서도 생긴다.** 이 인터뷰의 S2–S10 아홉 가운데 일곱이 모델이 쓴 선택지 문장이고, 인터뷰의 새 이름 둘도 선택지 설명 문장에서 나왔다(RC8).

```yaml
hidden_assumptions:
  - assumption: "의역은 직렬화 단계(seed 산문 → brief 번호 항목 → 묶음)에서 생기므로 원자료 파일을 정본으로 올리면 고쳐진다"
    why_risky: "의역은 질문과 선택지를 쓰는 자리에서도 들어온다. 사용자가 고른 선택지 문장은 모델이 쓴 글인데 `source: chosen` 사용자 원문으로 남는다. 이 인터뷰의 S2–S10 아홉 가운데 일곱이 그렇다(RC8). S7 「파이프라인으로서 둘로 나눠도 되고」 는 S8 에서 「둘로 나눈다」 로 확정됐고, 새 이름 「맥락 쌓기」 · 「로드맵 잡기」 는 선택지 설명 문장에서 나왔다. 옆 설계도 원자료에 질문 · 선택지 절을 넣는다(RC7). 원자료 사슬을 다 고쳐도 이 층의 치우침은 글자 그대로 보존될 뿐이다."
    evidence:
      - url: "https://www.pewresearch.org/writing-survey-questions/"
        supports: current
        claim: "선택지를 주면 답이 달라진다 — 「When explicitly offered the economy as a response, more than half of respondents (58%) chose this answer」 대 열린 질문 「only 35% … volunteered the economy」. 첫 자리 효과 — 「they tend to choose items at the top of the list (a “primacy” effect)」. 「Even small wording differences can substantially affect the answers people provide.」 레포 규칙은 추천을 첫 자리에 두고 「(권장)」 을 단다. 이 인터뷰의 chosen 일곱 가운데 다섯이 권장 선택지였고 S6 · S10 은 권장과 달랐다. 설문 방법론을 유추로 가져온 것이다."
        touches: []
        decides: []
        source_kind: secondary
        checked_at: "2026-11-14"
        certainty: uncertain

  - assumption: "승인 전인 옆 설계문서를 이 일의 잣대로 삼아도 사용자 결정의 전제가 유지된다"
    why_risky: "S3(「이 일이 맡는다」)의 질문은 옆 문서가 「이 일이 정한다고 적었다」 는 서술 위에서 물었다. 그 문장은 지금 판에 없다. 지금 문면은 받는 곳을 R5 로 적고 「먼저 하면 확인만」 이라는 조건을 단다(RC6). 두 일 가운데 누가 먼저인지를 정하는 장치는 없다. 옆 문서의 「함께 도는 충돌은 없다」 는 R2 · R3 가 R1 뒤에 시작한다는 로드맵 안 순서에만 기대고, 로드맵 밖인 이 일은 그 논거에 들지 않는다(RC10)."
    evidence:
      - url: "https://martinfowler.com/bliki/SemanticConflict.html"
        supports: current
        claim: "이름 바꾸기와 다른 브랜치의 새 사용처는 글자 병합은 통과하고 뜻이 깨진다 — 「the textual merge will work fine, but the program will not run the same way」. 줄이는 길로 드는 것은 「merge more often」 이다. 이 일의 이름 바꾸기와 옆 로드맵 · PR #274 가 같은 파일에 옛 이름으로 새 줄을 더하는 상황이 이 모양이다."
        touches: []
        decides: []
        source_kind: secondary
        checked_at: "2026-11-14"
        certainty: confirmed

  - assumption: "맞출 대상인 「새 코어」는 검증이 끝난 목표다"
    why_risky: "옆 로드맵 스스로 「모든 단계 · 작은 일까지 팀과 지휘자를 거치게 해도 토큰이 준다」 를 숨은 가정 K1 로 적었다. 비교 기준선(P1 의 token-baseline.md)은 이 worktree 에 없다(RC11). 앞단의 끝을 「작은 일도 리더로」 로 바꾸면 측정 전인 가설에 앞단을 묶게 된다. 그 가설이 재측정(R5)에서 틀리면 앞단의 끝 · 넘김 글 · 원자료 자리가 함께 되돌려진다."
    evidence:
      - url: "https://www.anthropic.com/engineering/built-multi-agent-research-system"
        supports: current
        claim: "「multi-agent systems use about 15× more tokens than chats」. 맞는 일의 조건 — 「multi-agent systems require tasks where the value of the task is high enough」. 작은 질의에는 「prevent overinvestment in simple queries」. 인용은 요약 모델이 뽑은 조각이다."
        touches: []
        decides: []
        source_kind: primary
        checked_at: "2026-11-14"
        certainty: confirmed

  - assumption: "원자료를 글자 그대로 · 덧붙이기만으로 추적 파일에 두는 것은 안전하다"
    why_risky: "pm-interview 는 사용자 답의 token · key 를 치환해 적지만(P21) request-framing 의 원문 보존 걸음에는 그 치환이 없다(RC3). 옆 설계의 검사는 `original.md` 의 앞 줄을 바꾸거나 지운 변경을 거절하고 출처와 바이트가 같기를 요구한다(RC5). 붙여 넣은 로그의 비밀값이 정본에 들어가면 치환이 곧 게이트 실패다. request-framing 이 지금 허용하는 유일한 제자리 수정(제목과 겹치는 줄 앞에 `> ` 붙이기)도 같은 검사에 걸린다(RC4)."
    evidence:
      - url: "https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository"
        supports: current
        claim: "올라간 비밀은 「as a first step you need to revoke and/or rotate that secret」. 지우려면 이력을 다시 써야 하고 부작용이 있다 — 「Rewriting history will change the hashes of the commits」 · 「We recommend merging or closing all open pull requests before removing files」 · 「You cannot remove sensitive data from other users' clones」. 옆 설계는 원자료를 `<커밋>:<경로>` 와 줄 범위로 가리키므로 이력 재작성은 그 포인터도 깬다."
        touches: []
        decides: []
        source_kind: primary
        checked_at: "2026-11-14"
        certainty: confirmed

  - assumption: "원자료 전체를 설계 쪽에 읽히는 것이 새 코어의 목적(읽는 양 줄이기)과 함께 간다"
    why_risky: "`original.md` 는 framing 원문과 질문 전체, 인터뷰 발화를 덧붙이기만 하는 파일이고 옆 설계는 「설계하는 쪽은 전체를 읽는다」 고 적는다(RC7). 로드맵이 길어지고 다시 나눌수록 이 파일은 커지기만 한다. 같은 일이 앞단 skill 글은 줄이면서 모든 에픽의 설계가 통째로 읽는 파일은 상한 없이 키운다."
    evidence:
      - url: "https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents"
        supports: both
        claim: "「as the number of tokens in the context window increases … the model's ability to accurately recall information from that context decreases」 · 목표는 「the smallest possible set of high-signal tokens」. 같은 글은 줄이는 쪽의 위험도 적는다 — 「overly aggressive compaction can result in the loss of subtle but critical context」. 원문 보존과 읽는 양 줄이기 양쪽을 다 받친다. 인용은 요약 모델이 뽑은 조각이다."
        touches: []
        decides: []
        source_kind: primary
        checked_at: "2026-11-14"
        certainty: confirmed

  - assumption: "호출 이름 바꾸기는 「별칭 없이 즉시 + major 판」 으로 한 시점에 끝난다"
    why_risky: "이름은 호출 이름 말고도 산출물 `type:` 리터럴과 파일 이름 줄기에 박혀 있고(RC12) 상태 기록의 「역할과_이름」 차원이 든 층 목록에는 `type:` 리터럴이 없다. 도는 세션은 자기가 실은 판을 그대로 쓴다. 새 코어는 상주 리더와 여러 세션을 전제하므로 옛 이름 세션과 새 이름 세션이 함께 도는 창이 구조적으로 생긴다. 깨는 변경을 알리는 길이 major 판 하나인데, 같은 일이 판 올림 완화(OQ11)도 함께 실었다."
    evidence:
      - url: "https://code.claude.com/docs/en/plugins/loading"
        supports: current
        claim: "「Changes to settings or to disk don't reach this layer until you run `/reload-plugins` or start a new session.」 · 「The running session keeps the versions it loaded」 · 옛 판 폴더는 14일 뒤 지워져 「a session that already loaded the old version keeps running」. 판 계산 — 「a manifest that pins \"version\": \"1.0.0\" keeps every user on the cached copy until its author changes the string」. 반대쪽 사실 — 「A plugin loaded in place from a marketplace you added from a local path loads its current source files at every session start, whatever its version string says.」 페이지 원문 전체를 받아 읽었다."
        touches: []
        decides: [OQ11]
        source_kind: primary
        checked_at: "2026-11-14"
        certainty: confirmed
      - url: "https://code.claude.com/docs/en/skills"
        supports: current
        claim: "별칭은 내장 skill 에만 적혀 있다 — 「Some bundled skills have aliases, such as `checkup` for `/doctor`.」 사용자 · 플러그인 skill 의 별칭이나 폐기 예고 장치는 읽은 범위(앞 10만 자)에서 찾지 못했다."
        touches: []
        decides: []
        source_kind: primary
        checked_at: "2026-11-14"
        certainty: uncertain

  - assumption: "앞단 글에서 이유 · 이력 문장을 걷어내면 순수한 이득이고 문제의 본체는 길이다"
    why_risky: "공식 자료 둘이 다른 쪽을 가리킨다. 이유를 걷어내면 모델이 규칙을 넓게 맞춰 쓰는 근거가 같이 사라질 수 있다. 길이 말고 순서의 문제도 있다. 맥락이 압축되면 skill 본문은 앞 5,000 토큰만 다시 붙고, `Read` 로 읽은 reference(끝맺음 절차)는 다시 붙지 않는다. request-framing 은 1373줄이라 어느 문장이 앞에 있느냐가 총 줄 수보다 크게 작용할 수 있다."
    evidence:
      - url: "https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices"
        supports: alternative
        claim: "「Providing context or motivation behind your instructions, such as explaining to Claude why such behavior is important, can give Claude more information about your goals」 · 「Claude can generalize from the explanation.」 skills 문서의 「State what to do rather than narrating how or why」(상태 파일 조사 5)와 방향이 다르다. 원문을 받아 Grep 으로 확인했다."
        touches: []
        decides: []
        source_kind: primary
        checked_at: "2026-11-14"
        certainty: confirmed
      - url: "https://code.claude.com/docs/en/skills"
        supports: current
        claim: "「Claude Code re-attaches the most recent invocation of each skill after the summary, keeping the first 5,000 tokens of each. Re-attached skills share a combined budget of 25,000 tokens. … older skills can be dropped entirely after compaction if you have invoked many in one session.」 · 「Claude Code does not re-read the skill file on later turns」. 인용은 요약 모델이 뽑은 조각이다."
        touches: []
        decides: []
        source_kind: primary
        checked_at: "2026-11-14"
        certainty: confirmed

  - assumption: "인터뷰에는 「맥락 쌓기」와 「로드맵 잡기」로 가를 깨끗한 솔기가 있다"
    why_risky: "지금 끝맺음은 두 일이 맞물려 돈다. 분해 판단이 brief 를 쓰기 전에 돌고, 분해안 표의 번호 배정은 「brief 를 쓰기 전이라 모델이 한다」. brief 의 위험 번호는 그 표가 미리 배정한 순서를 따른다. 로드맵 생성은 brief 게이트 통과 직후이고 brief 리뷰 뒤에 다시 생성한다(RC1 · RC2). 어디를 잘라도 한쪽 단계가 다른 쪽이 아직 내지 않은 산출물을 읽는다. 가른 자리에는 넘김이 하나 더 생기는데, 이 일의 계기가 넘김을 지나며 생긴 의역이었다."
    evidence:
      - url: "https://cognition.com/blog/dont-build-multi-agents"
        supports: current
        claim: "「Share context, and share full agent traces, not just individual messages」 · 「Actions carry implicit decisions, and conflicting decisions carry bad results」. 단계를 가르면 「The decision-making ends up being too dispersed and context isn't able to be shared thoroughly enough」. 단계 사이를 줄여 넘기는 일은 「It takes investment into figuring out what ends up being the key information」. 인용은 요약 모델이 뽑은 조각이다."
        touches: []
        decides: []
        source_kind: secondary
        checked_at: "2026-11-14"
        certainty: confirmed

  - assumption: "새 코어에 맞추기와 공식 표준 쪽으로 옮기기를 한 일 · 한 brief 가 실어도 된다"
    why_risky: "CLAUDE.md 규칙 여섯은 새 코어에서 나온 것이 아니라 저술 가이드 대조에서 따라 들어왔다. 닿는 곳도 spec-distill 앞단이 아니다. `cost_class` 를 `metadata` 아래로 옮기면 plugin-audit 의 검사가 최상위 키만 인정해 모든 skill 을 빠짐으로 세고, quality-gates 의 테스트는 CLAUDE.md 의 그 문장 전체를 글자로 박아 두었다(RC9). 그 CLAUDE.md 는 옆 로드맵 R2 의 예약 파일이다(RC10). 이름 바꾸기 · 나누기 · 글 줄이기 · 원자료 사슬 · 규칙 개정이 같은 파일들에 겹쳐 떨어진다."
    evidence:
      - url: "https://google.github.io/eng-practices/review/developer/small-cls.html"
        supports: current
        claim: "「In general, the right size for a CL is one self-contained change.」 · 「It's usually best to do refactorings in a separate CL from feature changes or bug fixes.」 · 큰 변경은 「you will have lots of conflicts when you merge」 · 「reviewers have discretion to reject your change outright for the sole reason of it being too large.」 인용은 요약 모델이 뽑은 조각이다."
        touches: []
        decides: []
        source_kind: secondary
        checked_at: "2026-11-14"
        certainty: confirmed

failure_modes:
  - mode: "사용자가 고른 결정의 근거 문장이 상류에서 조용히 바뀐 채 설계가 진행된다"
    trigger: "옆 설계문서가 승인 전에 계속 고쳐진다(이 회의 중 740줄 → 771줄, RC6). 편지함이 없어 바뀐 사실이 이쪽에 오지 않는다. 「먼저 하면 확인만」 조건에 순서를 정하는 장치가 없어 R5 와 이 일이 둘 다 하거나 둘 다 안 한다."
    evidence:
      - url: "https://martinfowler.com/bliki/SemanticConflict.html"
        supports: current
        claim: "글자 병합이 통과해도 뜻이 어긋나는 충돌은 병합 도구가 못 잡는다 — 「This is why we are such big fans of continuous integration.」 승인 전 문서 둘이 서로를 전제로 인용하는 것도 같은 꼴이다."
        touches: []
        decides: []
        source_kind: secondary
        checked_at: "2026-11-14"
        certainty: confirmed

  - mode: "이름을 바꾼 뒤 옛 이름 세션과 새 이름 세션이 함께 돌고, 실패가 오타와 구별되지 않는다"
    trigger: "이름 바꾸기가 머지된 뒤에도 옆 리더 세션은 옛 판을 싣고 돈다. 그 세션이 내는 넘김 줄과 추적 문서의 다음 세션 줄은 옛 이름을 쓴다. 옛 기록은 옮기지 않기로 했다(S5). `docs/` 아래 106개 파일에 옛 이름 글자가 842번 있다(Grep 계수 — 하한). 새 세션이 그 줄을 받아 부르면 못 찾는다."
    evidence:
      - url: "https://github.com/anthropics/claude-code/issues/87507"
        supports: current
        claim: "「A running session can resolve skills from a plugin cache version significantly older than what `installed_plugins.json` reports as installed, and no available diagnostic reveals this from inside the session.」 · 실패는 「`Unknown skill` … indistinguishable from a typo, a renamed skill, or a routing bug」. 2026-08-18 에 열렸고 2026-10-04 에 봇이 not planned 로 닫았다. 사용자 보고이고 지금 판에서 재현하지는 않았다."
        touches: []
        decides: []
        source_kind: secondary
        checked_at: "2026-11-14"
        certainty: uncertain

  - mode: "비밀값이 든 붙여넣기 글이 지울 수 없는 정본이 된다"
    trigger: "사용자가 framing 에 로그 · 설정 조각을 붙여 넣는다. request-framing 은 치환 없이 그대로 옮긴다(RC3). 그 글이 기본 브랜치의 `intent/original.md` 로 커밋된다. 치환하려 하면 앞 줄 수정 거절과 바이트 대조(RC5)에 걸린다. 과제 파일들은 이미 그 줄 범위를 커밋째 가리킨다."
    evidence:
      - url: "https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository"
        supports: current
        claim: "이력을 다시 써도 「the commits with sensitive data may still be accessible elsewhere」 — 다른 사람의 clone, fork, GitHub 캐시 화면에 남는다."
        touches: []
        decides: []
        source_kind: primary
        checked_at: "2026-11-14"
        certainty: confirmed

  - mode: "가벼운 길이 기본 길이 된다 — 건너뛰는 쪽이 스스로 작다고 판정한다"
    trigger: "「작은 일」 의 정의가 세 곳에 따로 생긴다 — CLAUDE.md Law 1 의 trivia escape 와 가벼운 꼴, 옆 로드맵의 D11, 이 일의 「이유를 적고 건너뛰기」. 판정자는 건너뛰면 일이 줄어드는 모델이다. 구조 게이트는 그 사유 문구가 피검자가 쓴 글이라 건너뛴 것과 도구 부재를 못 가른다(상태 파일 조사 1 의 RC8 — 이미 확인된 사실이고 다시 주장하지 않는다)."
    evidence:
      - url: "https://code.claude.com/docs/en/memory"
        supports: current
        claim: "지시 글은 집행이 아니다 — 「Claude treats them as context, not enforced configuration. To block an action regardless of what Claude decides, use a PreToolUse hook instead.」 · 「there's no guarantee of strict compliance, especially for vague or conflicting instructions」 · 「if two instructions contradict each other, Claude may pick one arbitrarily」. 원문을 받아 Grep 으로 확인했다."
        touches: []
        decides: []
        source_kind: primary
        checked_at: "2026-11-14"
        certainty: confirmed

  - mode: "락이 의도한 변경과 회귀를 가르지 못한다"
    trigger: "이름 바꾸기(경로 · 리터럴), 나누기(파일 가르기), 글 줄이기(문장 삭제), 원자료 사슬(S1 의 뜻)이 같은 세 파일과 그것을 읽는 테스트 58개에 겹쳐 들어간다. 문장 글자를 단언하는 락을 변경마다 손으로 다시 쓰게 되고, 다시 쓴 락의 통과는 지키던 것이 남았다는 증거가 되지 못한다."
    evidence:
      - url: "https://google.github.io/eng-practices/review/developer/small-cls.html"
        supports: current
        claim: "작은 변경은 「Reviewed more thoroughly.」 이고 리팩터링은 동작 변경과 다른 변경으로 가르라고 한다. 이름 바꾸기 · 파일 가르기는 리팩터링, 원자료 사슬 · 가벼운 길은 동작 변경이다."
        touches: []
        decides: []
        source_kind: secondary
        checked_at: "2026-11-14"
        certainty: confirmed

  - mode: "가른 두 단계 사이에서 맥락이 한 번 더 줄어든다"
    trigger: "「맥락 쌓기」 끝과 「로드맵 잡기」 시작 사이에 세션 경계나 압축이 낀다. 분해안의 번호 배정은 지금 모델이 세션 안 맥락과 상태 파일로 한다(RC1). 파일에 적히지 않은 조사 맥락은 둘째 단계에 오지 않는다. 한 세션에서 이어 돌면 압축 뒤 앞 skill 본문은 앞 5,000 토큰만 남는다."
    evidence:
      - url: "https://www.anthropic.com/engineering/built-multi-agent-research-system"
        supports: both
        claim: "넘김에서 정보가 깎이는 것을 「game of telephone」 이라 부르고, 줄이는 길로 산출물을 밖에 두는 것을 든다 — 「implement artifact systems where specialized agents can create outputs that persist independently」. 넘길 글이 모자라면 「agents duplicate work, leave gaps, or fail to find necessary information」. 파일에 두고 경로로 넘기는 방향은 받치고, 넘김 횟수를 늘리는 것은 위험 쪽이다. 인용은 요약 모델이 뽑은 조각이다."
        touches: []
        decides: []
        source_kind: primary
        checked_at: "2026-11-14"
        certainty: confirmed

  - mode: "로드맵이 없는 일과 framing 없이 시작한 일에 원자료의 집이 없다"
    trigger: "S5 는 「로드맵 없는 일도 같은 자리」 와 「시작이 framing일수도 있고 아닐수도」 를 함께 실었다. 로드맵 폴더는 인터뷰 끝의 분해 승인 뒤에야 생기고, 「spec 하나로」 를 고르면 영영 생기지 않는다. 폴더 이름은 brief 파일 이름에서 나오는데 그 이름은 framing 시점에 없다(RC1). 도는 로드맵이 없을 때 단순 작업의 자리는 옆 설계가 R2 로 미뤘다(RC11). 레포 근거만 있는 실패 양식이라 웹 근거는 붙이지 않았다."
    evidence: []

  - mode: "CLAUDE.md 를 두 일이 다른 잣대로 함께 고친다"
    trigger: "R2 는 새 코어 기준으로 P8 · CLAUDE.md 를 고치고(문면은 OQ24 로 열려 있다 — 상태 파일 조사 2), 이 일은 공식 표준 기준으로 규칙 여섯을 고친다. 문장 전체를 박은 테스트(RC9)는 둘째로 머지하는 쪽에서 깨진다. 충돌을 풀며 한쪽 문장이 조용히 옛 글로 돌아갈 수 있다."
    evidence:
      - url: "https://code.claude.com/docs/en/memory"
        supports: current
        claim: "규칙 파일의 어긋난 문장은 모델이 아무 쪽이나 따른다 — 「If two files give different guidance for the same behavior, Claude may pick one arbitrarily.」 공식 권고는 「Review your CLAUDE.md files … periodically to remove outdated or conflicting instructions」 다."
        touches: []
        decides: []
        source_kind: primary
        checked_at: "2026-11-14"
        certainty: confirmed

confidence: 0.7

repo_claims:
  - id: RC1
    path: "plugins/spec-distill/skills/pm-interview/references/finishing.md"
    anchor: "### 분해 판단 — Step A 직전"
    line: 24
    claim: "분해 판단은 brief 를 쓰기 전에 돈다. 「spec 하나로」 면 「로드맵을 만들지 않는다」(26행). 분해안 표의 미배정 계산은 「brief 를 쓰기 전이라 이 계산은 모델이 한다」(63행). 로드맵 폴더 이름은 「brief 파일 이름(`<줄기>.md`)에서 끝의 `-interview.md` 를 뗀 것」(65행)이다. pm-interview `SKILL.md` 562행은 종료가 정해진 뒤에야 이 파일의 분해 판단부터 돌게 한다. 로드맵 폴더는 framing 시점에 없고, 이름의 재료(brief 파일 이름)도 그때 없다."
    touches: []
    decides: []
  - id: RC2
    path: "plugins/spec-distill/skills/pm-interview/references/finishing.md"
    anchor: "**위험 번호.** … (분해 판단 표가 이 순서로 미리 배정했다)"
    line: 148
    claim: "brief §5 의 위험 번호는 분해안 표가 미리 배정한 순서를 따른다. 로드맵과 묶음은 brief 게이트 통과 직후 `roadmap_write.py create --brief … --plan-table <상태 파일>` 로 만든다(210–232행). brief 리뷰 뒤에는 「B-R — 로드맵 다시 생성」 절(655행 — 제목만 확인했다)이 있다. brief 쓰기와 로드맵 생성은 순서대로 이어진 두 덩어리가 아니라 서로의 산출물을 읽으며 맞물린다."
    touches: []
    decides: []
  - id: RC3
    path: "plugins/spec-distill/skills/request-framing/SKILL.md"
    anchor: "1. **원문 보존** — 사용자가 준 원문(요청·생각·대화 로그·자료)을 **`$AUDIT` 파일의 `## 1. 원문` 절**에 그대로 옮겨 적습니다(append-only"
    line: 220
    claim: "request-framing 의 원문 보존 걸음에 secret 치환이 없다. 이 파일에서 「P21」 은 kill switch 설명(643행)에만 나온다. pm-interview `SKILL.md` 172행은 「**Secret 기록 금지** (P21): 사용자 답변에 token/key/credential 패턴 감지 시 placeholder로 치환 후 기록」 을 둔다. 치환은 인터뷰 발화에만 걸리고 framing 에 붙여 넣은 원자료에는 안 걸린다. 부재 주장은 이 파일의 Grep(`P21|치환|REDACT`)에 기댄다."
    touches: []
    decides: []
  - id: RC4
    path: "plugins/spec-distill/skills/request-framing/SKILL.md"
    anchor: "`## 1` append-only 의 유일한 예외입니다"
    line: 609
    claim: "붙여 넣은 원문에 audit 템플릿 절 제목과 같은 줄이 있으면 사용자 선택에 따라 `## 1. 원문` 안의 그 줄 앞에 `> ` 를 붙인다(605–610행). 원문 절의 제자리 수정이다. 같은 절이 `original.md` 의 출처이거나 그 파일 자체가 되면 옆 설계의 앞 줄 수정 거절 · 바이트 대조(RC5)와 부딪친다."
    touches: []
    decides: []
  - id: RC5
    path: "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "AC4: … `original.md` 는 덧붙이기만 받는다 — 앞 줄을 바꾸거나 지운 변경은 검사가 거절한다."
    line: 563
    claim: "(옆 worktree · 승인 전 · 771줄 판) AC4 는 `original.md` 의 앞 줄 수정 · 삭제를 거절한다. AC5(564행)는 옮긴 구간이 「출처 파일의 그 구간과 바이트가 같」기를 요구한다. 177행은 이 대조가 「앞단이 `intent/` 에 바로 쓰게 되기 전까지」 의 사본에 대한 것이라고 적는다. 바로 쓰게 된 뒤 덧붙이기 검사를 누가 어떻게 지키는지는 이 문서에 없다. 줄 범위는 `<커밋>:<경로>` 로 가리킨다(349 · 436행)."
    touches: []
    decides: []
  - id: RC6
    path: "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "brief · audit 파일 자체를 `intent/` 로 옮기는 일은 이 설계가 하지 않는다 — … 이 로드맵 안에서는 R5 가 받고, 앞단을 고치는 다른 로드맵(B13)이 먼저 하면 R5 는 확인만 한다"
    line: 189
    claim: "(옆 worktree · 승인 전) 이 문서는 지금 771줄이다(상태 파일 조사 2 때 740–741줄). 상태 파일 R1 이 737행으로 인용한 「그 로드맵이 `source_interview` 키와 `intent/` 에 바로 쓰기를 정한다」 는 지금 판에 없다(Grep `바로 쓰기를 정한다` 0건). 「의도 싱크 skill」 · 「의도 싱크 결과」 도 0건이다. 남은 문면은 189행과 미룸 표 660행(받는 곳 칸 「R5」)이다. Handoff Context(768행)가 이 일에 넘긴다고 적는 것은 「어느 단계를 무엇이라 부를지」 다. B18(709행)이 새로 들어와 사용자의 역할 말을 싣는다. S3 를 물은 질문의 근거 서술은 지금 판과 글자가 다르다."
    touches: []
    decides: []
  - id: RC7
    path: "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "### §3 원자료 — `intent/`"
    line: 181
    claim: "(옆 worktree · 승인 전) `original.md` 는 「생성기가 로드맵을 만들 때 채운다」(183행). 내용은 framing audit 의 「원문 절과 질문 전체 절(질문 · 선택지 · 사용자가 답한 것)」(185행)과 인터뷰 발화(186행)다. 모델이 쓴 질문 · 선택지가 원자료에 든다. 185행의 조건 「framing 을 거친 일이면」 은 framing 없이 시작한 일에 이 구간이 없음을 뜻한다. 191행은 「설계하는 쪽은 `intent/original.md` 전체를 읽는다」 다. 쓰는 사람이 생성기에서 앞단 skill 로 바뀌면 183행의 채우는 시점(로드맵 생성)과 앞단이 쓰는 시점(framing 첫 라운드)이 어긋난다."
    touches: []
    decides: []
  - id: RC8
    path: "docs/superpowers/interview/2026-11-14-framing-interview-constraint-audit-brief-interview.state.md"
    anchor: "user_statements:"
    line: 48
    claim: "S2–S10 아홉 가운데 일곱(S2 · S3 · S4 · S6 · S8 · S9 · S10)이 `source: chosen` 이고 `text` 는 orchestrator 가 쓴 선택지 문장이다. 사용자가 친 글은 S5 · S7 둘이다. 1551행은 「S8 로 인터뷰의 새 이름도 정해졌다 — 「맥락 쌓기」 와 「로드맵 잡기」(고른 선택지의 설명 문장)」 이라고 적는다. 그 앞 발화는 S7 「파이프라인으로서 둘로 나눠도 되고」 다. 이름 둘의 글자는 사용자 원문이 아니라 선택지 설명에서 나왔다."
    touches: []
    decides: []
  - id: RC9
    path: "plugins/plugin-audit/scripts/check-shape-completeness.py"
    anchor: "_has_cost_class"
    line: 104
    claim: "frontmatter 의 최상위 `^cost_class:` 만 인정한다(108행). 키를 `metadata` 아래로 옮기면 들여쓴 줄이 맞지 않아 모든 skill 이 빠짐으로 판정된다. `plugins/quality-gates/tests/test_governance_no_capability_caps.sh` 131행은 CLAUDE.md 의 「**모든 skill에 `cost_class` 선언**」 줄을 grep 하고 144행 `FIXED_CLAUDE` 는 그 문장 전체를 글자로 박는다. CLAUDE.md 규칙 개정은 spec-distill 밖 두 플러그인의 스크립트와 테스트에 닿고, 레포 규칙대로면 그 플러그인들의 판도 올려야 한다. 실행해 보지는 않았다."
    touches: []
    decides: []
  - id: RC10
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md"
    anchor: "### R2 — 지휘 절차 개편"
    line: 38
    claim: "R2 의 범위에 「P8 · CLAUDE.md 개정」(40행), 경로 예약에 `docs/philosophy/devbrew-harness-philosophy.md` 와 `CLAUDE.md`(44행)가 있다. 옆 설계문서 598행은 예약 밖 수정을 「R2 · R3 는 R1 뒤에 시작하므로 함께 도는 충돌은 없다」 로 정당화한다. 이 논거는 로드맵 안의 의존 순서에만 선다. 이 일은 그 로드맵의 에픽이 아니라 순서가 정해져 있지 않다."
    touches: []
    decides: []
  - id: RC11
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md"
    anchor: "K1 — 위험 — 숨은 가정: 모든 단계 · 작은 일까지 팀과 지휘자를 거치게 해도 토큰이 준다"
    line: 106
    claim: "새 코어의 중심 가정이 로드맵에 「숨은 가정」 으로 올라 있고 대응은 「작은 일은 가볍게(D11)」 한 줄이다. 비교 기준선 `token-baseline.md`(P1 산출물, 18 · 24행)는 이 worktree 에 없다(Glob 0건). 옆 설계문서 미룸 표 652행은 「도는 로드맵이 없을 때 단순 작업을 어느 팀의 `jobs/` 에 둘지」 를 R2 로 넘긴다. 이 일의 「작은 일도 리더로」 와 「로드맵 없는 일도 같은 자리」 가 기대는 자리는 아직 정해지지 않았다."
    touches: []
    decides: []
  - id: RC12
    path: "plugins/spec-distill/scripts/state_path.py"
    anchor: "_SLOTS = ((\".state.md\", \"interview-state\"), (\".md\", \"interview-brief\"), (\".audit.md\", \"interview-audit\"))"
    line: 213
    claim: "「인터뷰」 라는 이름은 산출물 `type:` 리터럴과 파일 이름 줄기(350행 `\"{0}-{1}-interview\"`)에도 박혀 있다. `check_brief.py` 1633행은 `type: interview-brief` 가 아니면 실패시킨다. `spec_review_bundle.py` 31행 `KINDS` 와 `check_bundle_coverage.py` 389 · 730행은 그 리터럴로 모드를 가른다. `interview_state.py` 137 · 211행은 `interview-seed` · `interview-seed-audit` 로 seed 를 알아본다. `scripts/` 아래 10개 파일에 이 리터럴과 호출 이름이 42번 있다(Grep 계수). 이 층을 바꾸면 옛 기록(옮기지 않기로 한 것)과 도는 로드맵의 brief 가 새 코드에 안 읽히고, 안 바꾸면 새 이름 skill 이 옛 이름 `type:` 을 계속 쓴다."
    touches: []
    decides: []
```

**읽을 때 주의**

- 옆 설계문서의 줄 번호는 이번에 읽은 771줄 판 기준이다. 이 문서는 이 인터뷰 중에도 바뀌었으니 인용 전에 다시 여는 편이 안전하다.
- WebFetch 는 작은 모델을 거친다. 페이지 원문을 받아 직접 확인한 곳은 `plugins/loading` · `memory` · prompting best practices 셋이고, 나머지 인용은 요약 모델이 뽑은 조각이다.
- 실행 도구가 없어 아무것도 돌려 보지 않았다. RC9 의 「빠짐으로 판정된다」 는 정규식을 읽은 결론이다.

**확인하지 못한 것**

- 제3자 설치 여부(「별칭 없이 즉시」 예외가 소멸하는 조건). `README.md` · `.claude-plugin/` · 저술 가이드에서 관련 글자를 찾지 못했고 GitHub 쪽은 보지 못했다.
- 이 레포가 로컬 경로 마켓플레이스로 깔려 도는지 여부. 그렇다면 판 문자열과 무관하게 세션 시작마다 지금 소스를 읽는다(공식 문서). OQ11 과 「혼합 판 창」 의 무게가 여기에 달렸다.
- `finishing.md` 「B-R — 로드맵 다시 생성」 절의 본문(제목만 확인).
- skills 문서의 뒤 1만 9천 자. 별칭 장치가 없다는 것은 읽은 범위 안의 부재다.

**읽은 파일**

- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/interview/2026-11-14-framing-interview-constraint-audit-interview.md` — 전문
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/interview/2026-11-14-framing-interview-constraint-audit-brief-interview.state.md` — 1–778행 · 1342–1561행 (조사 3 의 779–1341행은 읽지 않았다)
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/skills/pm-interview/references/finishing.md` — 20–65 · 144–151 · 196–245행
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/skills/request-framing/SKILL.md` — 214–227 · 600–611행과 Grep
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/skills/pm-interview/SKILL.md` — 168–177행
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/roadmap_write.py` — 200–329행
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/state_path.py` — Grep 으로 맞은 줄
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/plugin-audit/scripts/check-shape-completeness.py` — 96–111행
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/tests/test_governance_no_capability_caps.sh` — Grep 으로 맞은 줄
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/tests/test_invocation_surface.sh` — 128–167행
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md` — 전문
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md` — 172–193행과 Grep 으로 맞은 줄

Sources:
- [Pew Research Center — Writing Survey Questions](https://www.pewresearch.org/writing-survey-questions/)
- [Martin Fowler — SemanticConflict](https://martinfowler.com/bliki/SemanticConflict.html)
- [Anthropic — How we built our multi-agent research system](https://www.anthropic.com/engineering/built-multi-agent-research-system)
- [GitHub Docs — Removing sensitive data from a repository](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)
- [Anthropic — Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Claude Code — Plugin loading reference](https://code.claude.com/docs/en/plugins/loading)
- [Claude Code — Skills](https://code.claude.com/docs/en/skills)
- [Claude Code — Memory](https://code.claude.com/docs/en/memory)
- [Claude — Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices)
- [Cognition — Don't Build Multi-Agents](https://cognition.com/blog/dont-build-multi-agents)
- [Google Engineering Practices — Small CLs](https://google.github.io/eng-practices/review/developer/small-cls.html)
- [anthropics/claude-code issue #87507](https://github.com/anthropics/claude-code/issues/87507)
~~~~

### 조사 9 — steelman-builder · R3 · 묶음 5

~~~~
이 dispatch 는 OQ12 만 다뤘다. 계약(`<claims_contract>`)은 받았다. `id` 는 임시값이다.

```yaml
case_for_alternative:
  statement: "공식 장치를 «대신»이 아니라 «나란히» 둔다 — 환경변수 kill switch 와 프로젝트 안 `.claude/<plugin>/` 상태 자리는 지금 읽는 그대로 두고, 플랫폼이 집행하는 공식 스위치(`enabledPlugins` · `claude plugin disable --scope` · `disableAllHooks`)를 끄는 첫 길로 문서에 올리며, `${CLAUDE_PLUGIN_DATA}` 는 설치물 · 캐시 자리로만 저술 가이드에 들인다."
  strongest: |
    goal(S4)은 앞단을 새 코어에 맞추는 일이고 갈래는 넘기는 곳 · 글 줄이기 · 가벼운 길 · 이름 넷이다. 원안의 두 이동은 그 넷 어디에도 서지 않으면서 범위는 가장 크다 — kill switch 변수는 docs 밖 127개 파일 647곳(RC3), 상태 루트는 spec-distill 테스트만 23개 파일 242곳(RC6)이고 무게 중심은 앞단이 아닌 quality-gates · plugin-audit 다. 게다가 `state_path.py` · `control_plane.py` · `conductor_state.py` · 레포의 유일한 훅 `post-tool-use.py` 는 옆 로드맵 R3 예약, CLAUDE.md 는 R2 예약이다(RC9). 새 코어 스스로가 상태를 다시 짜는 중이다 — STATUS.md 는 상태 브랜치의 추적 파일, machine.md 는 「이 기계 캐시로 줄임」(RC10). 지금 상태 자리를 옮기면 새 코어에 맞추는 것이 아니라 새 코어를 앞질러 정하는 것이다.
    기능으로도 `disableAllHooks` 는 필요한 것보다 많이 끄고 필요한 것은 못 끈다. 공식 문서상 그 설정이 끄는 것은 hook · 사용자 상태줄 · `@` 파일 제안이고 개별 hook 은 못 끈다 — 사용자의 다른 플러그인 hook 과 자기 hook 까지 함께 꺼진다. 반대로 레포에 등록된 훅은 project-init 의 PostToolUse 하나뿐이고(RC1), 환경변수가 실제로 끄는 것은 진입 skill 열 개의 사전 검사(RC2)와 기능 단위 경로다 — 외부 codex 호출 · PR 코멘트 게시 · 「리뷰 대상 저장소의 코드를 호스트 권한으로 돌리지 않는다」 는 차등 테스트(RC4) · 훅이 아닌 이름 붙은 자리(RC5). 이 가운데 `disableAllHooks` 가 닿는 것은 훅 하나와 상태줄뿐이다.
    상태 자리도 같다. `${CLAUDE_PLUGIN_DATA}` 는 `~/.claude/plugins/data/<id>/` — 플러그인 단위이지 프로젝트 단위가 아니고, 플러그인을 마지막 자리에서 지우면 함께 지워지며, Bash 도구로 도는 명령의 환경에는 그 변수가 없고, 샌드박스는 `~/.claude` 의 대부분을 쓰기 거부한다. devbrew 의 상태 작성자는 전부 skill 이 Bash 로 부르는 스크립트이고(RC6 · RC7 · RC8) 상태의 수명은 세션 · 문서 · 로드맵 · 실행 단위다. Anthropic 의 공식 플러그인 plugin-dev 자신이 프로젝트 단위 설정 · 상태의 자리를 프로젝트 안 `.claude/plugin-name.local.md` 로 가르치고, Claude Code 자신이 `CLAUDE_CODE_DISABLE_*` 변수를 쉰 개 넘게 싣고 settings 의 `env` 키로 그것을 나르게 한다 — 지금 두 자리는 「공식과 다른 자리」 라기보다 공식이 쓰는 꼴과 같은 꼴이다.
case_for_current:
  strongest: |
    보안 컨트롤이라면 플랫폼이 집행하는 스위치가 플러그인이 집행하는 스위치보다 강하다. 환경변수 스위치는 읽는 자리마다 읽어 줘야 듣는다 — 레포의 정본 모듈이 그 실패를 실측으로 적는다: 같은 책임이 열두 곳에 따로 살았고 한 곳은 `DEVBREW_SKIP_HOOKS` 를 「아예 읽지 않았다」, 「사용자가 껐다고 믿는 스위치가 어떤 지점에서는 무반응이었다」, 그 결함의 방향은 「언제나 fail-open」(RC3). README 에는 은퇴한 토큰의 묘지가 있고 그중 하나는 「이 토큰으로 자동 리뷰를 꺼 두었다면 이제 리뷰가 돈다」 다(RC5). `disableAllHooks` 와 플러그인 끄기는 플러그인 코드 밖에서 집행돼 훅 스크립트가 깨져도 듣고, settings 파일 편집은 재시작 없이 도는 세션에 반영된다 — 환경변수는 「전부 세션 스코프 env var 라 재시작이 필요하다」(RC5).
    잃는 것도 작다. 레포 전체에 등록된 훅이 하나라(RC1) 「개별 hook 끄기가 사라진다」 는 훅 하나의 이야기이고, 사용자는 그 손실을 선택지 설명에서 읽고 골랐다(S10). 얻는 것은 goal 의 「글 줄이기」 와 P4(푸는 쪽)에 바로 선다 — 앞단 skill 본문의 스위치 서술(request-framing 11곳 · pm-interview 9곳 · reviewing-brief 12곳 · spec-distill README 21줄), 플러그인마다 실린 판정 모듈 사본, 그것을 지키는 테스트가 걷힌다.
    상태 자리는 프로젝트 안에 두기 때문에 생긴 장치가 통째로 사라진다 — 스스로 `.gitignore` 를 쓰고 추적 파일을 탐침하고 링크를 거부하고 worktree 에서 메인 레포를 찾아가는 코드(RC6), `.claude` 가 제자리의 실제 디렉토리인지 삭제 전에 재는 가드(RC7). 리뷰 대상 레포의 내용은 비신뢰 입력인데 상태 폴더가 그 트리 안에 있어서 필요한 방어다. 사용자 홈의 데이터 폴더는 그 트리 밖이라 링크 심기와 git 오염이 구조적으로 없고, worktree 가 사라져도 남으며, 공식 hooks 문서는 그 폴더를 「for dependencies and state that should survive plugin updates」 라고 적는다 — 상태는 용도 안이다.
premise_refutation:
  hits: [P6]
  why: |
    P6 「공식 장치로 옮겨도 지금 장치가 사용자에게 주던 것이 유지된다」 는 kill switch 쪽과 상태 쪽 둘 다에서 근거와 충돌한다.
    (kill switch) https://code.claude.com/docs/en/hooks 「Disable or remove hooks」 는 「There is no way to disable an individual hook while keeping it in the configuration.」 이라 적고, https://code.claude.com/docs/en/settings-reference 의 `disableAllHooks` 행은 그 설정이 끄는 것을 「hooks, a custom status line, and a custom `@` file suggestion command」 로 적는다 — skill 은 닿지 않는다. 지금 장치가 주는 것은 `shared/entry/entry_preflight.py#sentinel` 이 진입 skill 을 `DEVBREW_<PLUGIN>_DISABLE=1` 로 끄는 것(RC2)과 기능 단위 스위치(RC4) · 훅이 아닌 이름 붙은 자리(RC5)다. 「disableAllHooks 만」 으로 가면 이 셋이 유지되지 않는다. S10 선택지 설명이 알린 손실은 「개별 hook 끄기가 사라진다」 하나였고 이 셋은 알리지 않았다.
    (상태) https://code.claude.com/docs/en/plugins/manifest-reference 「Environment variables」 는 `${CLAUDE_PLUGIN_DATA}` 를 `~/.claude/plugins/data/<id>/` 로 풀고 「The variables aren't present in the environment of commands Claude runs through the Bash tool, in the main session or in a subagent.」 이라 적는다. https://code.claude.com/docs/en/plugins/cli-reference 는 마지막 자리에서 uninstall 하면 「its data directory, `~/.claude/plugins/data/<id>/`」 를 지운다고 적는다. https://code.claude.com/docs/en/sandboxing 「Protected paths」 는 `~/.claude` 를 「most of its contents」 쓰기 거부로 적고 `allowWrite` 로도 풀리지 않는다고 적는다. 지금 장치가 주는 것은 프로젝트 · 문서 · 로드맵 · 실행 단위의 수명(CLAUDE.md 「런타임 상태 & 훅」 — plugin-audit 실행 폴더는 「지우지 않는다」), Bash 로 도는 스크립트가 권한 없이 쓰는 자리(RC6 · RC7 · RC8)다. 플러그인 단위 · uninstall 때 삭제 · Bash 환경에 없음 · 샌드박스 쓰기 거부는 그것이 유지되지 않음을 뜻한다.
premise_list_challenge: |
  결함이 여섯 있다.
  1. 빠진 전제 — 「devbrew 의 kill switch 가 끄는 것은 hook 이다」. 방향 문장과 조사 3 의 「hook 을 끄는 공식 수단은 `disableAllHooks` 설정뿐이다」 는 이 전제 위에 서 있는데 레포에서는 거짓이다. 등록된 훅은 하나이고(RC1) 스위치의 수신처 대부분은 진입 skill 과 스크립트 경로다. 조사 3 의 문장은 hook 에 대해서만 맞다.
  2. 빠진 전제 — 「이 두 자리는 공식과 다른 자리다」. 비교 대상이 같은 종류가 아니다. `${CLAUDE_PLUGIN_DATA}` 는 플러그인 단위 자리이고 레포의 상태는 프로젝트 단위다. 프로젝트 단위 플러그인 상태에 대해 Anthropic 의 plugin-dev 는 프로젝트 안 `.claude/plugin-name.local.md` 를 가르친다. 환경변수 스위치도 공식 제품이 쓰는 꼴이다(`CLAUDE_CODE_DISABLE_*` · settings `env`). P3 의 「후보」 자격 자체가 약하다.
  3. P6 은 orchestrator 가 도출한 전제인데, S10 선택지 설명이 이미 「개별 hook 끄기가 사라진다」 고 알렸다 — 사용자는 P6 이 통째로 참이라고 듣고 고른 것이 아니다. 받아들인 손실은 그 하나이고, 위 hits 가 적은 나머지 손실은 사용자가 보지 못했다.
  4. 방향이 서로 기대지 않는 결정 둘(kill switch · 상태 자리)을 한 문장에 묶었다. 근거의 세기가 다르다 — 상태 쪽이 더 단단히 반증된다. 사용자에게는 둘로 갈라 묻는 것이 맞다.
  5. 방향이 「공식 설정」 을 `disableAllHooks` 하나로 좁혔다. 공식에는 그 밖에 플러그인 단위 끄기(`enabledPlugins` · `claude plugin disable <plugin> --scope local` — 「turns off a project-enabled plugin for you alone」), skill 단위 거부 규칙(`Skill(name)`), 한 번 실행만 덮는 `--settings`, 플러그인 사용자 옵션 `userConfig` 가 있다. `DEVBREW_<PLUGIN>_DISABLE=1` 의 공식 대응물은 `disableAllHooks` 가 아니라 플러그인 끄기다. 다만 `userConfig` 로 기능 단위 스위치를 옮기는 길은 새 장치를 짓는 일이라 P4(푸는 쪽)와 반대 방향이고 이번에 대안으로 내지 않았다.
  6. 범위가 모호하다. 방향 문장은 두 꼴(`DEVBREW_<PLUGIN>_DISABLE=1` · `DEVBREW_SKIP_HOOKS`)만 이름 붙였는데 레포에는 기능 단위 변수(`…_DISABLE_CODEX` · `…_DISABLE_WEB` · `…_DISABLE_PUBLISH` · `…_DISABLE_DIFFERENTIAL_TEST` 등)가 따로 있다. 「환경변수 kill switch 대신」 이 이것까지 뜻하는지 전제 목록이 말하지 않는다.
  덧붙임 둘. S10 에서 고르지 않은 「이 셋은 옮기지 않는다」 를 그대로 대안으로 내지 않았다(규칙 9) — 낸 대안은 공식 장치를 나란히 들이는 것이라 그 선택지와 다르다. 다만 상태 자리 절반에 한해서는 근거가 가리키는 최선이 「옮기지 않는다」 와 사실상 같다는 것을 숨기지 않는다. 그리고 goal(S4)은 앞단을 재는 기준이라 quality-gates · plugin-audit 에 무게가 실린 이 방향을 약하게만 가른다 — 네 갈래와의 거리, 옆 로드맵 예약과의 겹침으로 쟀다. 같은 입력을 다시 받았다는 느낌은 없다(ST3 첫 dispatch).
recommendation: refined
refined_takes: |
  「공식 쪽으로」 라는 방향과, 플랫폼이 집행하는 스위치를 끄는 첫 길로 올리는 것. 플러그인 전체 끄기는 `enabledPlugins` / `claude plugin disable <plugin> --scope local`, 훅 전부 끄기는 `disableAllHooks`(한 번 실행만이면 `--settings`)를 CLAUDE.md 「런타임 상태 & 훅」 과 각 README 에 적는다 — 플러그인 코드가 깨져도 듣고 재시작 없이 반영되는 길이다. `${CLAUDE_PLUGIN_DATA}` 는 저술 가이드에 플러그인 단위 설치물 · 캐시의 자리로 들인다(지금 저술 가이드와 CLAUDE.md 에는 언급이 0건이다). 새 코어가 machine.md 를 「이 기계 캐시」 로 줄이면 그 파일의 자리는 R3 가 이 구분으로 정한다.
refined_drops: |
  「disableAllHooks 만」 — 환경변수 스위치의 제거. `DEVBREW_<PLUGIN>_DISABLE` · `DEVBREW_SKIP_HOOKS` · 기능 단위 변수는 지금 읽는 그대로 읽는다(공식 장치가 닿지 않는 자리: 진입 skill 사전 검사 · 훅이 아닌 이름 붙은 자리 · codex · 게시 · 차등 테스트). CLAUDE.md 의 「kill switch는 보안 컨트롤」 조항 삭제. 세션 · 문서 · 로드맵 · 실행 단위 상태를 `${CLAUDE_PLUGIN_DATA}` 로 옮기는 것.
evidence:
  - url: "https://code.claude.com/docs/en/hooks"
    supports: both
    claim: "「Disable or remove hooks」 — 「To temporarily disable all hooks without removing them, set `\"disableAllHooks\": true` in your settings file.」 · 「There is no way to disable an individual hook while keeping it in the configuration.」 · 한 번 실행만은 `--settings '{\"disableAllHooks\": true}'` · 관리 설정으로 배포된 hook 은 사용자 · 프로젝트 · 로컬의 `disableAllHooks` 로 못 끈다. 원안 쪽 — 플랫폼이 집행하는 끄기가 실재한다. 대안 쪽 — 개별 끄기가 없고 전부를 끈다."
    touches: [P6]
    decides: [OQ12]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/hooks"
    supports: current
    claim: "「Reference scripts by path」 — `${CLAUDE_PLUGIN_DATA}`: 「the plugin's persistent data directory, for dependencies and state that should survive plugin updates.」 hooks 문서는 그 폴더의 용도에 state 를 넣는다. hook 프로세스에는 `CLAUDE_PROJECT_DIR` · `CLAUDE_PLUGIN_ROOT` · `CLAUDE_PLUGIN_DATA` 가 환경변수로 실린다."
    touches: [P6]
    decides: [OQ12]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/manifest-reference"
    supports: alternative
    claim: "「Environment variables」 — `${CLAUDE_PLUGIN_DATA}` 는 「`~/.claude/plugins/data/<id>/`, created on first reference and kept across plugin updates」, 용도 칸은 「Installed dependencies such as `node_modules`, generated code, and caches」. 「By default, Claude Code deletes the `${CLAUDE_PLUGIN_DATA}` directory when you uninstall the plugin from the last place it's installed.」 「The variables aren't present in the environment of commands Claude runs through the Bash tool, in the main session or in a subagent.」 — skill 본문에서는 `${...}` 를 인라인으로 치환받아야 한다. 플러그인 단위 자리이고 프로젝트를 가르는 성분이 없다. (옛 주소 `/docs/en/plugins-reference` 로 받아 이 페이지 전문을 읽었다.)"
    touches: [P6]
    decides: [OQ12]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/plugins/cli-reference"
    supports: both
    claim: "uninstall — 「When you uninstall a plugin from the last scope it's installed at, Claude Code also deletes the plugin's stored options and secrets and its data directory, `~/.claude/plugins/data/<id>/`.」 예외는 `--keep-data` 등 셋. disable — 「`claude plugin disable formatter --scope local` turns off a project-enabled plugin for you alone」. 대안 쪽 — 데이터 폴더의 상태는 플러그인 삭제와 함께 사라진다. 원안 쪽 — 플러그인 단위 · 프로젝트 단위로 끄는 공식 스위치가 있다."
    touches: [P6]
    decides: [OQ12]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/settings-reference"
    supports: both
    claim: "색인 행 — `disableAllHooks`: 「Turn off hooks, a custom status line, and a custom `@` file suggestion command at once.」 · `enabledPlugins`: 「Turn individual plugins on or off per scope.」 · `env`: 「Set environment variables for every session and its subprocesses.」 셋 다 Scope 는 Any file. `disableAllHooks` 는 skill 을 끄지 않고 사용자 상태줄까지 끈다. `env` 키는 환경변수 스위치를 공식 설정 파일로 나르는 길이다. 각 키의 본문 항목은 페이지가 길어 읽지 못했다 — 색인 행만 확인했다."
    touches: [P6]
    decides: [OQ12]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/settings"
    supports: current
    claim: "「Claude Code watches your settings files and reloads them when they change, so it applies most edits to the running session without a restart, including edits to `permissions`, `hooks`」 · `--settings` 는 그 세션에만 적용되고 프로젝트 · 사용자 파일 위에 선다 · 「Environment variables aren't a level in this stack.」 설정 파일 기반 스위치는 도는 세션에 반영되고 범위(사용자 · 프로젝트 · 로컬 · 관리)를 갖는다."
    touches: [P6]
    decides: [OQ12]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/skills"
    supports: both
    claim: "「Plugin skills are not affected by `skillOverrides`. Manage those through `/plugin` instead.」 · skill 단위 차단은 권한 거부 규칙 `Skill(name)` · `${CLAUDE_PLUGIN_DATA}` 는 「Substituted only in plugin skills. Use this to reference installed dependencies, generated files, or caches that must outlive an update.」 플러그인 skill 을 끄는 공식 길은 플러그인 끄기와 거부 규칙이고 `disableAllHooks` 는 이 페이지의 skill 끄기 수단에 없다."
    touches: [P6]
    decides: [OQ12]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://code.claude.com/docs/en/sandboxing"
    supports: alternative
    claim: "기본 쓰기 — 「read and write access to the current working directory and its subdirectories, any directories you've added …, plus the per-user temp directory」. 「Protected paths」 — 「In `~/.claude`, or the directory `CLAUDE_CONFIG_DIR` points to: most of its contents」, 「If you add an `allowWrite` entry or an `Edit` allow rule that covers one of these paths, the protection still applies.」 「The sandbox covers shell commands only. Claude's file tools, MCP servers, and hooks run outside it.」 데이터 폴더는 샌드박스 밖에서 도는 hook · MCP 프로세스에는 열려 있고 Bash 로 도는 스크립트에는 기본으로 닫혀 있다. `~/.claude/plugins/data` 가 「most」 의 예외인지는 이 페이지가 적지 않는다."
    touches: [P6]
    decides: [OQ12]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: uncertain
  - url: "https://code.claude.com/docs/en/env-vars"
    supports: alternative
    claim: "Claude Code 자신이 끄기 스위치를 환경변수로 싣는다 — 읽은 범위(앞 10만 자)에서 이름에 DISABLE 이 든 변수가 54개다(`CLAUDE_CODE_DISABLE_WEB_FETCH` · `CLAUDE_CODE_DISABLE_AUTO_MEMORY` 등, 하한). 「Add variables under the `env` key in a `settings.json` file」. 환경변수 kill switch 는 공식 제품의 관례와 같은 꼴이다."
    touches: [P3]
    decides: [OQ12]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/plugin-dev/skills/plugin-settings/SKILL.md"
    supports: alternative
    claim: "Anthropic 의 plugin-dev 플러그인이 가르치는 자리 — 「Plugins can store user-configurable settings and state in `.claude/plugin-name.local.md` files within the project directory.」 · 「Purpose: Per-project plugin configuration and state」 · 「Lifecycle: User-managed (not in git, should be in `.gitignore`)」 · 「Pattern 1: Temporarily Active Hooks」 는 그 파일의 `enabled` 값으로 hook 이 스스로 빠져나가게 한다. 프로젝트 단위 플러그인 상태를 프로젝트의 `.claude/` 아래에 두는 것과 hook 이 자기 스위치를 스스로 읽는 것 둘 다 공식 플러그인의 관례다. 조사 3 은 plugin-dev 가 공식 문서와 어긋나는 자리가 있다고 적었다 — 이것은 문서가 아니라 공식 플러그인의 서술이다."
    touches: [P3]
    decides: [OQ12]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
  - url: "https://pre-commit.com/"
    supports: alternative
    claim: "「pre-commit solves this by querying a `SKIP` environment variable.」 · 「The `SKIP` environment variable is a comma separated list of hook ids.」 · 「This allows you to skip a single hook instead of `--no-verify`ing the entire commit.」 `DEVBREW_SKIP_HOOKS` 와 같은 꼴(콤마 구분 hook id · 환경변수)의 선행 사례이고, 전부 끄기만 있는 것의 결함을 이유로 든다. 사용자는 맞출 표준으로 일반 개발 관례를 고르지 않았다(S1) — 표준 근거가 아니라 선행 사례로만 쓴다."
    touches: []
    decides: [OQ12]
    source_kind: primary
    checked_at: "2026-11-14"
    certainty: confirmed
repo_claims:
  - id: RC1
    path: "plugins/project-init/hooks/hooks.json"
    anchor: "\"PostToolUse\""
    line: 4
    claim: "레포에 등록된 훅은 이것 하나다. `plugins/*/hooks/**` 는 이 파일과 `post-tool-use.py` 둘뿐이고 플러그인 넷의 `.claude-plugin/plugin.json` 에 `hooks` 키가 없다. 그 훅은 `post-tool-use.py#main` 첫 줄에서 `kill_switch_active(\"project-init\", \"post-tool-use\", \"PostToolUse\")` 를 읽는다(609행). 「개별 hook 끄기」 가 가르는 대상은 훅 하나다."
    touches: [P6]
    decides: [OQ12]
  - id: RC2
    path: "shared/entry/entry_preflight.py"
    anchor: "sentinel"
    line: 44
    claim: "진입 skill 사전 검사는 `DEVBREW_<PLUGIN>_DISABLE` 값이 정확히 `1` 이면 `[devbrew-entry] disabled …` 줄을 내고 skill 을 세운다(50–51행). 수신처가 hook 이 아니라 skill 이라 `disableAllHooks` 가 닿지 않는다. `DEVBREW_SKIP_HOOKS` 는 진입에 걸리지 않는다 — `shared/tests/test_entry_preflight.sh` 74–75행이 그것을, 63–71행이 변수명 도출이 정본과 같음을 락으로 지킨다. 세 플러그인의 `scripts/entry_preflight.py` 는 이 파일을 가리키는 링크다(같은 테스트 20–29행)."
    touches: [P6]
    decides: [OQ12]
  - id: RC3
    path: "shared/killswitch/kill_switch_active.py"
    anchor: "kill_switch_active"
    line: 29
    claim: "판정 정본이다. 머리말이 실측을 적는다 — 같은 책임이 「열두 곳」 에 따로 살았고 한 곳은 `DEVBREW_SKIP_HOOKS` 를 「아예 읽지 않았다」, 「사용자가 껐다고 믿는 스위치가 어떤 지점에서는 무반응이었다」, 그 결함의 방향은 「언제나 fail-open」(3–13행). 전역 변수명은 열거하지 않고 도출한다(46행). 플러그인이 스스로 집행하는 스위치의 약점(원안 쪽 근거)이자 그 약점을 이미 한 정본으로 모았다는 사실(대안 쪽 근거)이다. 이 두 변수 이름은 docs 밖에서 127개 파일 647곳에 나온다(Grep 계수 — 숨김 폴더 · 링크를 건너뛰므로 하한). 그중 앞단 skill 본문은 request-framing 11 · pm-interview 9 · reviewing-brief 12곳이다."
    touches: [P6]
    decides: [OQ12]
  - id: RC4
    path: "plugins/quality-gates/README.md"
    anchor: "`DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` | ② 차등 테스트를 통째로 건너뛴다(리뷰 대상 저장소의 코드를 호스트 권한으로 돌리지 않는다)"
    line: 477
    claim: "기능 단위 스위치는 hook 이 아닌 자리에서 집행된다 — 차등 테스트(`run-test-selection.sh` · `e2e-state.sh`), 외부 codex 호출(469행, `detect_codex.sh`), PR 코멘트 게시(487행, sink `publish-comment.sh` 의 첫 검사 — gh 호출 0), 보안 리뷰어(470행). quality-gates 에는 등록된 훅이 없다(RC1). 공식 설정 가운데 이것들을 하나씩 끄는 것은 없다."
    touches: [P6]
    decides: [OQ12]
  - id: RC5
    path: "plugins/spec-distill/README.md"
    anchor: "`DEVBREW_SKIP_HOOKS=spec-distill:review-entry` — 같은 효과의 이름 붙은 스위치."
    line: 294
    claim: "spec-distill 의 `DEVBREW_SKIP_HOOKS` 토큰은 전부 훅이 아닌 자리를 끈다 — `review-entry`(294행 「훅이 아니지만 지목할 이름을 갖는다」), `statusline`(288행), 원장 정리(295행 「설치되는 훅은 없다」). 282행은 환경변수 스위치의 한계를 적는다 — 「전부 세션 스코프 env var 라 재시작이 필요하다」. 320행은 은퇴한 토큰이 조용히 뜻을 잃은 사례다 — 「이 토큰으로 자동 리뷰를 꺼 두었다면 이제 리뷰가 돈다」."
    touches: [P6]
    decides: [OQ12]
  - id: RC6
    path: "plugins/spec-distill/scripts/state_path.py"
    anchor: "ensure_state_root"
    line: 138
    claim: "상태 루트는 cwd 가 worktree 여도 `<메인 레포>/.claude/spec-distill` 이다(`state_root` 98행 · `state_root_for_common` 73행). 프로젝트 안에 두기 때문에 드는 장치가 여기 있다 — `*` 한 줄 `.gitignore` 를 링크를 따르지 않고 쓰기(`_write_ignore` 120행), 무시되는지 · 추적 파일이 없는지 탐침하고 아니면 exit 3(`_check_state_root` 161–207행), 링크 성분 거부(`inside_root` 251행). 이 스크립트는 skill 이 Bash 로 부르는 CLI 라 `CLAUDE_PLUGIN_DATA` 환경변수를 받지 못한다. spec-distill 테스트 23개 파일 242곳이 이 자리를 가리킨다(Grep 계수 — `test_state_root.sh` 71 · `test_ledger_root.sh` 48 · `test_ledger_wiring.sh` 40 등, 본문은 읽지 않았다)."
    touches: [P6]
    decides: [OQ12]
  - id: RC7
    path: "plugins/quality-gates/scripts/setup-qg.sh"
    anchor: "STATE_ROOT=\".claude/quality-gates\""
    line: 194
    claim: "qg 세션 폴더는 리포 최상위의 `.claude/quality-gates/<session-id>/` 다(188–201행). `.claude` 나 상태 루트가 제자리의 실제 디렉토리가 아니면 지우지도 쓰지도 않는다(`root_escapes` 213–223 · 255–256행). 같은 루트 아래 `worktrees/` 에 기준선 · HEAD 축의 git worktree 가 선다(`qg-worktree.sh` 50행). 리뷰 대상 레포와 한 묶음으로 사는 상태다."
    touches: [P6]
    decides: [OQ12]
  - id: RC8
    path: "plugins/plugin-audit/scripts/prepare-run-dir.py"
    anchor: "<repo-root>/.claude/plugin-audit/<date>-<target>[-N]/ 을 os.mkdir 로 원자적으로 만들고"
    line: 4
    claim: "plugin-audit 실행 폴더는 넘겨받은 `--repo-root`(기본 cwd) 아래에 서고 기존 폴더를 덮거나 비우지 않는다(4–6 · 57행). CLAUDE.md 「런타임 상태 & 훅」 은 이 수명을 「실행 단위 산출(plugin-audit 실행 폴더 — 지우지 않는다)」 로 적는다. 플러그인을 지울 때 함께 지워지는 데이터 폴더의 수명과 맞지 않는다."
    touches: [P6]
    decides: [OQ12]
  - id: RC9
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md"
    anchor: "### R3 — 지휘자 상태 브랜치 · 편지함"
    line: 50
    claim: "R3 의 경로 예약(56행)에 `conductor_state.py` · `control_plane.py` · `state_path.py` · `plugins/project-init/hooks/post-tool-use.py` 가 있다 — 상태 루트를 정하는 구현과 레포의 유일한 훅이 옆 로드맵 몫이다. CLAUDE.md 는 R2 예약이다(44행). 원안은 이 예약 파일 다섯을 모두 고쳐야 한다."
    touches: []
    decides: [OQ12]
  - id: RC10
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R3.md"
    anchor: "**D18** — STATUS.md 는 스크립트가 계산해 쓰는 추적 파일로, 로드맵 지휘자의 코드 없는 상태 브랜치에 두고 main 에 머지하지 않는다"
    line: 47
    claim: "새 코어는 상태 자리를 스스로 다시 정했다 — 현황은 git 의 추적 파일(D18), 사용자 선택 원문은 「machine.md 는 이 기계 캐시로 줄임」(130행), 근거 줄은 「지휘 기계 상태는 이 기계에서만 뜻이 있다」(70행). 상태를 레포 쪽(추적 파일)으로 당기는 방향이고, 남는 machine.md 만 캐시 성격이다 — 공식 데이터 폴더의 용도(캐시)에 맞는 유일한 후보이며 그 파일은 R3 몫이다."
    touches: []
    decides: [OQ12]
  - id: RC11
    path: "plugins/plugin-audit/scripts/check-shape-completeness.py"
    anchor: "_hooks_killswitch_present"
    line: 136
    claim: "plugin-audit 가 CLAUDE.md 의 「모든 훅에 kill switch」 를 감사 기준으로 기계 집행한다 — 대상 플러그인의 등록된 훅 스크립트가 자기 이름의 스위치(`DEVBREW_SKIP_HOOKS` 또는 `kill_switch_active(\"<own>\"`)를 읽는지 본다(177–187행). 훅이 없으면 요건도 없다(149행). 원안은 이 감사 기준과 그 테스트(`test_check_shape_completeness.py`)의 삭제를 함께 뜻한다."
    touches: []
    decides: [OQ12]
  - id: RC12
    path: "plugins/spec-distill/references/docreview-profiles/brief.md"
    anchor: "- Law 1·2·3 과 kill switch 는 어떤 모드에서도 안 자른다."
    line: 74
    claim: "앞단의 brief 리뷰 프로필이 kill switch 를 Law 셋과 같은 줄에서 「안 자른다」 로 보호한다. 원안을 따르면 이 인터뷰가 내는 brief 자체가 자기 리뷰 프로필의 보호 조항과 부딪힌다 — 이 프로필 줄도 함께 고쳐야 하고, CLAUDE.md 는 persona 약화를 보안 리뷰 대상으로 적는다."
    touches: []
    decides: [OQ12]
  - id: RC13
    path: "CLAUDE.md"
    anchor: "kill switch 이름은 이 예외에 들지 않는다 — 은퇴시키려면 CHANGELOG `Removed` 와 README 에 공시가 필수다."
    claim: "레포 규칙은 kill switch 이름의 은퇴를 금지하지 않고 공시를 조건으로 허용한다. 「런타임 상태 & 훅」 은 「모든 훅에 kill switch. 진입 skill 도 같다.」 와 「어떤 훅도 자신의 kill switch 존중을 거부할 수 없음 — kill switch는 보안 컨트롤.」 을 적는다. 원안은 규칙 위반이 아니라 규칙 개정이고(S6 이 연 범위), 개정 대상 문장은 이 둘과 상태 수명 넷을 적은 문단이다. `CLAUDE_PLUGIN_DATA` · `disableAllHooks` 는 레포에서 인터뷰 상태 파일 둘에만 나온다(Grep — 하한)."
    touches: []
    decides: [OQ12]
```

읽은 자리(절대경로):
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/interview/2026-11-14-framing-interview-constraint-audit-brief-interview.state.md` — 1–448행, 조사 3 의 678–727 · 940–979행, 조사 5 · 6 과 R3 블록 1456–1561행
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/interview/2026-11-14-framing-interview-constraint-audit-interview.md` — 전문(S1)
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/killswitch/kill_switch_active.py` — 전문
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/entry/entry_preflight.py` — 전문
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/tests/test_entry_preflight.sh` — 전문
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/state_path.py` — 전문
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/project-init/hooks/hooks.json` — 전문, `post-tool-use.py` 는 kill switch 줄만
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/scripts/setup-qg.sh` — 185–279행
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/plugin-audit/scripts/prepare-run-dir.py` — 1–60행
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md` · `R3.md` — Grep 으로 맞은 줄만
- README 넷 · SKILL.md · `check-shape-completeness.py` · `brief.md` · 철학 문서 — Grep 으로 맞은 줄만

확인하지 못한 것:
- `settings-reference` 의 `disableAllHooks` · `enabledPlugins` 본문 항목(색인 행만 읽었다) — 플러그인이 실은 hook 이 `disableAllHooks` 에 드는지는 hooks 문서의 「all hooks」 로만 읽었다.
- `enabledPlugins` 를 `--settings` 로 한 번 실행에만 덮을 수 있는지.
- `~/.claude/plugins/data` 가 샌드박스 보호 경로의 예외인지(문서는 「most of its contents」 까지만 적는다).
- 실제 CLI 에서의 동작 — 전부 문서 대조이고 실측하지 않았다(이 agent 에 실행 도구가 없다).
- spec-distill 상태 루트를 가리키는 테스트 23개 파일의 본문.

Sources:
- [Claude Code — hooks](https://code.claude.com/docs/en/hooks)
- [Claude Code — plugin manifest reference](https://code.claude.com/docs/en/plugins/manifest-reference)
- [Claude Code — plugin commands reference](https://code.claude.com/docs/en/plugins/cli-reference)
- [Claude Code — settings reference](https://code.claude.com/docs/en/settings-reference)
- [Claude Code — settings files and precedence](https://code.claude.com/docs/en/settings)
- [Claude Code — skills](https://code.claude.com/docs/en/skills)
- [Claude Code — sandboxing](https://code.claude.com/docs/en/sandboxing)
- [Claude Code — environment variables](https://code.claude.com/docs/en/env-vars)
- [anthropics/claude-plugins-official — plugin-dev plugin-settings skill](https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/plugin-dev/skills/plugin-settings/SKILL.md)
- [pre-commit — Temporarily disabling hooks](https://pre-commit.com/)
~~~~

### 조사 11 — orchestrator · R4 · 묶음 6

- `CLAUDE_CODE_SUBAGENT_MODEL` 「Two sources take precedence over it: a model Claude passes when it spawns the agent, and a `model` field in the agent's definition, including `inherit`. … Before v2.1.251, this variable overrode both the per-invocation model and the definition's `model` field」 — https://code.claude.com/docs/en/env-vars 「Variables」 (1차 · 확인 2026-11-14) [→ OQ10]
- 「While `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` is on, Claude Code ignores the `model` field in subagent definitions, and Claude can't pass a model when it starts a subagent.」 — https://code.claude.com/docs/en/sub-agents 「Run every subagent on one model」 (1차 · 확인 2026-11-14) [→ OQ10]
- 플러그인 agent 예시 frontmatter 에 `model: sonnet` — https://code.claude.com/docs/en/plugins/components 「Agents」 (1차 · 확인 2026-11-14) [→ OQ10]
- 공식 플러그인 설치본: pr-review-toolkit 1.0.1 `code-reviewer.md` 4행 `model: opus` · feature-dev 1.0.1 `code-explorer.md` 5행 `model: sonnet` · plugin-dev 0.1.2 agent-development 95행 「### model (required)」 · 100행 「`inherit` … (recommended)」 — 이 기계의 플러그인 캐시에서 직접 읽음 (1차 · 확인 2026-11-14) [→ OQ10]
- 「either increase `version` on each release or omit it」 · 「Bump `version` on each release: users stay on their cached copy until the string changes.」 · 「Omit `version`: users track your commits instead.」 — 어느 쪽도 권하지 않는다 — https://code.claude.com/docs/en/plugins/host-marketplace 「Release a new version」 (1차 · 확인 2026-11-14) [→ OQ11]
- 「Validation passed with warnings: … a missing `version`, `description`, or `author`. Pass `--strict` to turn warnings into failures in CI」 — https://code.claude.com/docs/en/plugins/manifest-reference 「Validate the manifest」 (1차 · 확인 2026-11-14) [→ OQ11]
- 「Tag each release as `<plugin-name>--v<version>`, where `<version>` matches the `version` field in that commit's `plugin.json`.」 · npm · archive · command 소스에 한해 「a `plugin.json` that sets no version satisfies no constraint」 — https://code.claude.com/docs/en/plugins/dependencies (1차 · 확인 2026-11-14) [→ OQ11]
- 「Relative path inside a Git-hosted marketplace | The commit SHA of the installed directory」 — https://code.claude.com/docs/en/plugins/loading 「How Claude Code computes the version」 (1차 · 확인 2026-11-14) [→ OQ11]
- 공식 플러그인 agent-sdk-dev 의 `plugin.json` 은 name · description · version(1.0.1) · author 를 적는다(구조만 확인) · plugin-dev 0.1.2 plugin-structure 54행 `"name": "plugin-name"` · 83행 「Version format: Follow semantic versioning」 — raw 파일과 이 기계의 플러그인 캐시 (1차 · 확인 2026-11-14) [→ OQ11]
- `${CLAUDE_PLUGIN_DATA}` 는 「`~/.claude/plugins/data/<id>/`」 · 용도 「Installed dependencies such as `node_modules`, generated code, and caches」 · 「By default, Claude Code deletes the `${CLAUDE_PLUGIN_DATA}` directory when you uninstall the plugin from the last place it's installed.」 · 「The variables aren't present in the environment of commands Claude runs through the Bash tool, in the main session or in a subagent.」 — https://code.claude.com/docs/en/plugins/manifest-reference 「Environment variables」 (1차 · 확인 2026-11-14) [→ OQ12]
- uninstall 은 「its data directory, `~/.claude/plugins/data/<id>/`」 를 지운다(`--keep-data` 예외) · `plugin disable` 의 `--scope` 는 user · project · local — https://code.claude.com/docs/en/plugins/cli-reference (1차 · 확인 2026-11-14) [→ OQ12]
- `disableAllHooks` 「Turn off hooks, any custom status line, and any custom file suggestion command.」 · `enabledPlugins` 「Turn individual plugins on or off, keyed by `plugin-name@marketplace-name`.」 — https://code.claude.com/docs/en/settings-reference (1차 · 확인 2026-11-14) [→ OQ12]
- 「`${CLAUDE_PLUGIN_DATA}`: the plugin's persistent data directory, for dependencies and state that should survive plugin updates.」 — https://code.claude.com/docs/en/hooks 「Reference scripts by path」 (1차 · 확인 2026-11-14) [→ OQ12]
- plugin-dev 0.1.2 plugin-settings 11행 「Plugins can store user-configurable settings and state in `.claude/plugin-name.local.md` files within the project directory.」 — 이 기계의 플러그인 캐시 (1차 · 확인 2026-11-14) [→ OQ12]

## R4

### 지금 이해
steelman 게이트 ST1 — 의심 방향: agent 머리말의 `model` 키를 허용한다(S10). trigger: 기존 사용자 제약과의 충돌(2026-09-06 실측 근거로 승인한 금지 규칙). builder 출력 원문은 조사 7 블록에 있다.
조사 호출 7/60 · 이 라운드 본체 직접 1

- 확인 RC80 — 확인 — docs/plugin-authoring.md#「agent frontmatter 에 `model` 키를 두지 않는다.」 — 주장과 일치
- 확인 RC81 — 확인 — docs/superpowers/specs/2026-09-06-agent-model-unpin-design.md#「A. 측정 여섯」 — 주장과 일치(프로브 둘 · 트레이드오프 수용 17 · 92행)
- 확인 RC82 — 확인 — plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh#「예외는 없다」 — 주장과 일치(8행 · README 134행 문장을 46행이 단언)
- 확인 RC83 — 확인 — plugins/quality-gates/tests/test_agent_model_mutation.sh#「pairs=(」 — 주장과 일치(짝 아홉 · 테스트 파일 여덟 · 규약 문장 락 · docreview 락)
- 확인 RC84 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#「리뷰어 모델:」 — 주장과 일치(372행 · 계약 테스트 215행)
- 확인 RC85 — 확인 — plugins/quality-gates/README.md#「Choosing a cheaper tier for devbrew subagents is the user's call」 — 주장과 일치(141 · 147행)
- 확인 RC86 — 확인 — docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md#「K1. 리뷰는 opus 다.」 — 주장과 일치(102 · 675행)
- 확인 RC87 — 확인 — docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md#「리뷰어 모델 opus 고정 둘」 — 주장과 일치(107행 · qg CHANGELOG 155행)
- 확인 RC88 — 확인 — docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/flexibility-audit.md#「고치는 꼴」 — 주장과 일치(5 · 9행)
- 확인 RC89 — 확인 — CLAUDE.md#「레포 전용 값 금지.」 — 주장과 일치(31행 · test_conducting_reference.sh 395–397행)
- 확인 RC90 — 확인 — plugins/spec-distill/skills/epic-conductor/SKILL.md#「모델 칸은 해결자」 — 주장과 일치(173 · 180행)
- 확인 RC91 — 확인 — plugins/plugin-audit/scripts/check-plugin-structure.sh#has_model_key — 주장과 일치(63행)
- 확인 RC92 — 확인 — plugins/quality-gates/agents/security-reviewer.md#frontmatter — 주장과 일치(agent 20개 · `model:` 0건)
- 확인 RC93 — 확인 — CLAUDE.md#「이 예외는 제3자 설치가 확인되면」 — 문장은 일치(줄은 43행 — 보고의 49행과 다르다)

#### ST1 게이트-전 확인
- 부착 확인: sub-agents 순서 → P6 · P3 확인(충돌) · env-vars → P6 확인(충돌) · components → P3 확인 · pr-review-toolkit → P3 확인 · feature-dev → P3 확인 · issue 79866 → P6 확인 못 함(2차 자료, 본체가 열지 않았다 — M 에 세지 않는다)
- 비부착: issue 89723 · issue 36242
- 자격: 재검토 열림 — 전제 P6 충돌 확인 3건(정의의 `model` 이 환경변수보다 앞선다 · qg 공시 줄이 환경변수만 본다 · FORCE 는 dispatch 인자까지 막는다)
- 근거 8 중 부착 5 · 리포 주장 14 중 확인 14

### 다음 결정
OQ10: agent 의 model 키를 허용하는 방향을 유지할까 · 추천: builder 보완 · orchestrator 보완 — 사용자가 2026-10-17 에 정한 고치는 꼴(기본은 X, 다르면 이유를 적는다)과 같고 금지의 실측 근거는 지금도 맞다 · 트레이드오프: 유지는 사용자 환경변수가 키 든 agent 에 닿지 않는다 / 전환은 절대 금지와 락 12개가 그대로 남는다

### 질문
steelman 규약(고정 순서 유지 / 보완 / 전환 / 보류 · 출처 라벨). 「agent 의 `model` 키 허용」 방향을 어떻게 할까요?

### 답
→ (R6 뒤에 함께 적는다)

## R5

### 지금 이해
steelman 게이트 ST2 — 의심 방향: `plugin.json` 필수 키와 판 올림 규칙을 완화한다(S10). trigger: 기존 사용자 제약과의 충돌(PR 마다 판 올림 · CHANGELOG · major 올림 규칙). builder 출력 원문은 조사 8 블록에 있다.
조사 호출 7/60 · 이 라운드 본체 직접 0

- 확인 RC94 — 확인 — CLAUDE.md#「모든 PR마다 SemVer bump가 붙는 `plugin.json`.」 — 주장과 일치
- 확인 RC95 — 확인 — CLAUDE.md#「호출 이름(slash 명령 · skill 이름)의 변경·제거는 alias 없이 즉시 하고 major bump 한다.」 — 주장과 일치
- 확인 RC96 — 확인 — plugins/spec-distill/scripts/conductor_state.py#own_version — 주장과 일치(102 · 110 · 123 · 247행)
- 확인 RC97 — 확인 — plugins/spec-distill/scripts/conductor_ledger.py#version_report — 주장과 일치(388 · 391 · 423 · 1425행), conducting.md 14행은 다시 열지 않았다
- 확인 RC98 — 확인 — shared/deps/check_deps.py#_measure_row — 주장과 일치(232 · 250 · 259행)
- 확인 RC99 — 확인 — plugins/spec-distill/dependencies.md#「quality-gates | 14.6.0」 — 주장과 일치
- 확인 RC100 — 확인 — shared/tests/test_changelog_integrity.sh#「C2 맨 위 헤딩 버전 == plugin.json 버전.」 — 주장과 일치(366줄 · 30 · 62 · 199행), 「PR 마다 올렸는지 재는 검사가 없다」 는 부재 주장이라 다시 세지 않았다
- 확인 RC101 — 확인 — plugins/plugin-audit/scripts/check-shape-completeness.py#plugin_json_fields — 주장과 일치(8 · 44행 · check-staleness.py 269–274행)
- 확인 RC102 — 확인 — shared/tests/test_plugin_description_parity.sh#「plugin.json 에 소개 문구가 없다」 — 주장과 일치
- 확인 RC103 — 확인 — plugins/spec-distill/scripts/repo_defaults.py#SHARED_FILES — 주장과 일치(28행 · roadmap_status.py 59행)
- 확인 RC104 — 확인 — plugins/spec-distill/CHANGELOG.md#「[8.13.1] — 2026-10-30」 — 주장과 일치(헤딩 179 · 204 · 42 · 35)
- 확인 RC105 — 확인 — plugins/spec-distill/tests/test_readme_sync.sh#「플러그인 건드리는 모든 PR은 patch-bump」 — 주장과 일치
- 확인 RC106 — 확인 — .claude-plugin/marketplace.json#「"source": "./plugins/quality-gates"」 — 주장과 일치(상대경로 넷 · entry 에 version 없음 · README 는 github 소스 안내)
- 확인 RC107 — 확인 — plugins/spec-distill/.claude-plugin/plugin.json#「"version": "8.13.1"」 — 주장과 일치(네 플러그인 모두 네 키)
- 확인 RC108 — 확인 — docs/plugin-authoring.md#「plugin.json # 필수 — name, version (0.1.0로 시작), description」 — 주장과 일치(10 · 12행)

#### ST2 게이트-전 확인
- 부착 확인: loading → P6 확인(충돌) · host-marketplace → P3 확인 · manifest-reference → P3 확인 · dependencies → P6 확인(충돌 — 「no version satisfies no constraint」 는 npm · archive · command 소스에 한한다) · agent-sdk-dev plugin.json → P1 확인 · plugin-structure skill → P3 확인(설치본)
- 비부착: marketplace-reference · 공식 marketplace.json · superpowers plugin.json · classmethod 글
- 자격: 재검토 열림 — 전제 P6 충돌 확인 6건(지휘자가 빈 판에서 멈춘다 · 설치본 낡음 경고 · 최소 판 재기 · 공식 의존 태그 · 호출 이름 변경의 major 신호 · 판이 커밋 해시가 된다)
- 근거 10 중 부착 6 · 리포 주장 15 중 확인 15

### 다음 결정
OQ11: plugin.json 필수 키와 판 올림을 완화하는 방향을 유지할까 · 추천: builder 보완 · orchestrator 보완 — 판 번호를 코드 넷이 순서 있는 값으로 읽고, 이 일이 호출 이름을 바꾸며 그 신호가 major 올림이다 · 트레이드오프: 유지는 지휘자 기계 상태 쓰기가 멈춘다 / 전환(builder 대안)과 보완은 거의 같다

### 질문
steelman 규약. 「plugin.json 필수 · 판 올림 완화」 방향을 어떻게 할까요?

### 답
→ (R6 뒤에 함께 적는다)

## R6

### 지금 이해
steelman 게이트 ST3 — 의심 방향: 환경변수 kill switch 대신 공식 설정만 쓰고 런타임 상태를 공식 플러그인 데이터 폴더로 옮긴다(S10). trigger: 기존 사용자 제약과의 충돌 + landscape 모순. builder 출력 원문은 조사 9 블록에 있다.
조사 호출 7/60 · 이 라운드 본체 직접 0

- 확인 RC109 — 확인 — plugins/project-init/hooks/hooks.json#「"PostToolUse"」 — 주장과 일치(훅 파일 둘 · plugin.json 넷에 hooks 키 없음 · post-tool-use.py 609행)
- 확인 RC110 — 확인 — shared/entry/entry_preflight.py#sentinel — 주장과 일치(44–51행 · 테스트 74–75행)
- 확인 RC111 — 확인 — shared/killswitch/kill_switch_active.py#kill_switch_active — 주장과 일치(3–13 · 29행), 127개 파일 647곳은 다시 세지 않았다
- 확인 RC112 — 확인 — plugins/quality-gates/README.md#「DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1」 — 주장과 일치(469 · 470 · 477 · 487행)
- 확인 RC113 — 확인 — plugins/spec-distill/README.md#「DEVBREW_SKIP_HOOKS=spec-distill:review-entry」 — 주장과 일치(282 · 288 · 294 · 295 · 320행)
- 확인 RC114 — 확인 — plugins/spec-distill/scripts/state_path.py#ensure_state_root — 주장과 일치(73 · 98 · 120 · 138 · 161 · 251행), 테스트 23개 파일 242곳은 다시 세지 않았다
- 확인 RC115 — 확인 — plugins/quality-gates/scripts/setup-qg.sh#「STATE_ROOT=".claude/quality-gates"」 — 주장과 일치(194 · 213 · 255행)
- 확인 RC116 — 확인 — plugins/plugin-audit/scripts/prepare-run-dir.py#「os.mkdir 로 원자적으로 만들고」 — 주장과 일치(4–6행)
- 확인 RC117 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#「R3 — 지휘자 상태 브랜치 · 편지함」 — 주장과 일치(50 · 56 · 44행)
- 확인 RC118 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R3.md#D18 — 주장과 일치(47 · 70 · 130행)
- 확인 RC119 — 확인 — plugins/plugin-audit/scripts/check-shape-completeness.py#_hooks_killswitch_present — 주장과 일치(136행)
- 확인 RC120 — 확인 — plugins/spec-distill/references/docreview-profiles/brief.md#「Law 1·2·3 과 kill switch 는 어떤 모드에서도 안 자른다.」 — 주장과 일치(74행)
- 확인 RC121 — 확인 — CLAUDE.md#「kill switch 이름은 이 예외에 들지 않는다」 — 주장과 일치

#### ST3 게이트-전 확인
- 부착 확인: hooks(끄기) → P6 확인(충돌) · hooks(데이터 폴더 용도) → P6 확인 · manifest-reference → P6 확인(충돌) · cli-reference → P6 확인(충돌) · settings-reference → P6 확인(충돌 — 색인 행과 본문 항목 둘 다 읽었다) · plugin-dev plugin-settings → P3 확인(설치본) · settings → P6 확인 못 함 · skills → P6 확인 못 함 · sandboxing → P6 확인 못 함(builder 도 불확실로 냈다) · env-vars(DISABLE 변수 54개) → P3 확인 못 함 — 확인 못 한 넷은 M 에 세지 않는다
- 비부착: pre-commit
- 자격: 재검토 열림 — 전제 P6 충돌 확인 4건(개별 hook 끄기가 없다 · `disableAllHooks` 는 skill 에 닿지 않는다 · 데이터 폴더는 플러그인 단위이고 Bash 로 도는 명령 환경에 없다 · 플러그인을 지우면 데이터 폴더도 지워진다)
- 근거 11 중 부착 6 · 리포 주장 13 중 확인 13
- builder 의 `premise_list_challenge` 3번: S10 선택지 설명이 알린 손실은 「개별 hook 끄기가 사라진다」 하나였다 — 진입 skill 끄기 · 기능 단위 스위치 · 훅이 아닌 이름 붙은 자리가 함께 사라진다는 것은 본체가 선택지에 싣지 않았다(본체의 누락)

### 다음 결정
OQ12: kill switch 와 상태 자리를 공식 장치로 옮기는 방향을 유지할까 · 추천: builder 보완 · orchestrator 보완 — 공식 설정이 닿는 것은 훅 하나와 상태줄뿐이고, 공식 데이터 폴더는 프로젝트 단위 상태를 담지 못한다 · 트레이드오프: 유지는 진입 skill 끄기와 기능 단위 스위치가 사라진다 / 전환(builder 대안)과 보완은 거의 같다

### 질문
steelman 규약. 「kill switch · 상태 자리를 공식으로」 방향을 어떻게 할까요?

### 답
→ S13 (R4 의 답은 S11 · R5 의 답은 S12)

- ST1 판정: 유지(kept) — 사용자 문구 「공식을 따라가 」 를 유지로 읽었다(본체의 읽기 — 원안이 「공식처럼 허용」이다). §5 줄: `- 기각 — agent frontmatter 의 model 키 금지를 그대로 둔다 → 사용자: 「공식을 따라가 」 — verdict: kept — ST1 — 부착 5/8`
- ST2 판정: 유지(kept) — 사용자 문구 「공식대로 가고 기존 판올림도 다시 다 검토해봐 」. 공식이 적은 길이 둘(릴리스마다 올림 · version 비움)이라 어느 쪽인지는 OQ13 으로 연다. §5 줄: `- 기각 — version 은 명시 SemVer 로 남기고 완화는 두 곳에만 건다 → 사용자: 「공식대로 가고 기존 판올림도 다시 다 검토해봐 」 — verdict: kept — ST2 — 부착 6/10`
- ST3 판정: 유지(kept) — builder · orchestrator 추천(보완)과 다른 선택이다. §5 줄: `- 기각 — 공식 장치를 대신이 아니라 나란히 둔다 → 사용자: 「유지」 — verdict: kept — ST3 — 부착 6/11`
- skepticism 닫음 — S11 · S12 · S13
- 「기존 판올림도 다시 다 검토해봐」 는 조사 주문으로도 읽었다 — repo-researcher 를 띄운다(조사 12).

## R7

### 지금 이해
경로 (a). 숨은 가정 조사(조사 10)의 레포 주장 열둘을 직접 대조했다. 옆 설계문서는 그 사이 또 바뀌어 771줄이고(커밋 37fab27e) R1 에서 S3 를 물을 때 든 문장 「그 로드맵이 `source_interview` 키와 `intent/` 에 바로 쓰기를 정한다」 는 지금 판에 없다 → 옆_로드맵_경계와_순서: S3 의 근거 서술이 바뀌었다. S8 로 정한 이름 「맥락 쌓기」 는 본체의 선택지 문장에서 나왔고 사용자 말은 「컨텍스트 쌓기」 였다.
조사 호출 8/60 · 이 라운드 본체 직접 0
밀린 질문 5개 — 숨은 가정 · 실패 양식의 처분 · 작은 일의 가벼운 길과 구조 게이트 · 철학 문서를 어디까지 고칠지 · 덩어리 승인 화면 · 판 올림을 공식의 어느 길로(조사 12 뒤)
줄인 사실 2개

줄인 사실 전문:
- 옆 설계문서 지금 판의 문면: 189행 「이 로드맵 안에서는 R5 가 받고, 앞단을 고치는 다른 로드맵(B13)이 먼저 하면 R5 는 확인만 한다」 · 미룸 표 660행 받는 곳 「R5」 · 768행 「어느 단계를 무엇이라 부를지는 그 로드맵이 정한다」 · 결정 기록 B18 이 사용자의 역할 말을 싣는다(RC127).
- 옆 설계의 검사는 `original.md` 의 앞 줄 수정 · 삭제를 거절하고 출처와 바이트가 같기를 요구하는데(AC4 · AC5), request-framing 의 원문 보존 걸음에는 비밀값 치환이 없다(RC124 · RC126).

- 대체됨: R1 «지금 이해» 「옆 설계문서 737행은 「그 로드맵이 `source_interview` 키와 `intent/` 에 바로 쓰기를 정한다」 고 이 일을 가리키고」 → 지금 판(771줄, 37fab27e)에는 그 문장이 없고 받는 곳은 R5, 조건은 「다른 로드맵이 먼저 하면 확인만」 이다 (조사 10)
- 대체됨: R3 답 기록 「S8 로 인터뷰의 새 이름도 정해졌다 — 「맥락 쌓기」 와 「로드맵 잡기」」 → 「맥락 쌓기」 는 본체가 쓴 선택지 문장이고 사용자 말은 「컨텍스트 쌓기」 다. 낱말은 OQ17 로 다시 묻는다 (조사 10)

- 확인 RC122 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#「분해 판단 — Step A 직전」 — 주장과 일치(24 · 26 · 63 · 65행), pm-interview SKILL.md 562행은 다시 열지 않았다
- 확인 RC123 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#「위험 번호.」 — 148행 · 655행 제목은 일치, 210–232행은 R1 때 229행만 보았다
- 확인 RC124 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#「원문 보존」 — 주장과 일치(220행 · 이 파일의 P21 은 643행 하나 · pm-interview SKILL.md 172행)
- 확인 RC125 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#「`## 1` append-only 의 유일한 예외입니다」 — 주장과 일치(605–610행)
- 확인 RC126 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#AC4 — 주장과 일치(563 · 564 · 177행 — 771줄 판)
- 확인 RC127 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「이 로드맵 안에서는 R5 가 받고」 — 주장과 일치(771줄 · 「바로 쓰기를 정한다」 0건 · 189 · 660 · 709 · 768행)
- 확인 RC128 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「§3 원자료 — `intent/`」 — 주장과 일치(183–191행)
- 확인 RC129 — 확인 — docs/superpowers/interview/2026-11-14-framing-interview-constraint-audit-brief-interview.state.md#user_statements — 주장과 일치(S2–S10 가운데 선택지 문장이 일곱)
- 확인 RC130 — 확인 — plugins/plugin-audit/scripts/check-shape-completeness.py#_has_cost_class — 주장과 일치(104–108행 · 테스트 144행 `FIXED_CLAUDE`), 실행은 하지 않았다
- 확인 RC131 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#「R2 — 지휘 절차 개편」 — 주장과 일치(40 · 44행 · 옆 설계문서 598행)
- 확인 RC132 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#K1 — 주장과 일치(106행 · 옆 설계문서 652행 · token-baseline.md 없음)
- 확인 RC133 — 확인 — plugins/spec-distill/scripts/state_path.py#_SLOTS — 주장과 일치(213 · 350행 · check_brief.py 1633행 · spec_review_bundle.py 31행 · interview_state.py 137 · 211행)

### 다음 결정
OQ14: kill switch 를 공식으로 옮길 때 공식 설정이 닿지 않는 자리(진입 skill 끄기 · 기능 단위 스위치)를 어떻게 할까 · 추천: 다른 공식 장치로 대체하고 대응물이 없는 것만 남긴다 · 트레이드오프: 대체는 새 장치(플러그인 사용자 옵션)를 짓는 일이 낄 수 있다 / 없애면 외부 호출 · 게시 · 차등 테스트를 따로 끌 길이 사라진다 / 설계에 맡기면 범위가 설계 때 정해진다
OQ15: 프로젝트 · 문서 · 로드맵 단위 상태를 공식 데이터 폴더로 옮길 때 무엇이 지켜져야 하나 · 추천: 프로젝트마다 갈린다 · 플러그인을 지워도 사람이 볼 기록은 남는다 · 트레이드오프: 조건이 늘수록 데이터 폴더 안에 프로젝트별 구조를 따로 지어야 한다
OQ16: 근거 문장이 바뀐 뒤에도 의도 폴더에 바로 쓰기를 이 일이 맡을까 · 추천: 그대로 맡는다 · 트레이드오프: 맡으면 옆 로드맵의 이전 에픽은 확인만 한다 / 넘기면 사본 기간이 이전 에픽까지 간다
OQ17: 인터뷰 앞 단계의 이름은 「컨텍스트 쌓기」인가 「맥락 쌓기」인가 · 추천: 컨텍스트 쌓기 — 사용자가 쓴 낱말 · 트레이드오프: 「맥락」 은 레포 문서의 한국어 우선 관례에 맞고 사용자가 쓴 글자는 아니다

### 질문
경로 (b) — 판단. 한 호출에 넷. 앞의 둘은 S13(한 단어 답)의 되묻기다 — 서로 기대지 않는 나머지 둘과 묶었다(모델 판단: R2 · R3 와 같은 이유).
1. kill switch 를 공식 설정으로 옮기기로 하셨습니다. 공식 설정(모든 hook 끄기)이 닿지 않는 자리 — 진입 skill 끄기, 외부 codex 호출 · PR 코멘트 게시 · 차등 테스트 같은 기능 단위 스위치 — 는 어떻게 할까요?
2. 런타임 상태를 공식 데이터 폴더로 옮기기로 하셨습니다. 그 폴더는 플러그인 단위이고 플러그인을 지우면 함께 지워집니다. 옮긴 뒤에도 꼭 참이어야 하는 것을 고르세요(여럿 고를 수 있습니다).
3. 「의도 폴더에 바로 쓰기를 이 일이 맡는다」 를 여쭐 때 근거로 든 옆 설계문서 문장이 그 사이 바뀌었습니다. 지금 판은 「그쪽 이전 에픽이 받고, 다른 로드맵이 먼저 하면 확인만 한다」 입니다. 그래도 이 일이 맡을까요?
4. 인터뷰 앞 단계의 이름을 「맥락 쌓기」 로 적었는데 그 낱말은 제 선택지 문장에서 나왔고, 말씀하신 낱말은 「컨텍스트 쌓기」 였습니다. 어느 쪽으로 할까요?

### 답
→ S14 · S15 · S16 · S17

- 역할과_이름 · 옆_로드맵_경계와_순서 · 원자료_정본_사슬 닫음 — 각 차원의 질문에 답한 S(머리말 evidence)
- S15 의 덧붙인 말 「뭐가 옮겨질지 나에게 보고해줘 기존 이후 어떻게 될지」 는 보고 요청이다 — R8 «지금 이해» 에 상태 자리 목록을 싣는다(조사 13).
- 재결정(P23): 원래 — R3 답 기록의 이름 「맥락 쌓기」 / 재결정 — 「컨텍스트 쌓기」(S17) / 근거 — 사용자 말 「interview는 컨텍스트 쌓기와 로드맵 잡는게 주 역할이야」 의 글자


### 조사 12 — repo-researcher · R7 · 묶음 7

~~~~
레포 루트: `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit` (아래 `path` 는 모두 이 루트 기준 상대경로다).

**읽은 범위 — 종류별 수의 신뢰도가 플러그인마다 다르다.**
- `plugins/plugin-audit/CHANGELOG.md`(35) · `plugins/project-init/CHANGELOG.md`(42)는 전문을 읽고 갈랐다.
- `plugins/spec-distill/CHANGELOG.md`(179) · `plugins/quality-gates/CHANGELOG.md`(204)는 약 1만 1천 줄이라 전문을 읽지 못했다. 헤딩마다 첫 항목 앞머리 60자 안팎, 「동작 무변경 · 함께 bump · cache key · 문서만 · 테스트만」 같은 자가 선언 줄, 「patch/minor/major 인 이유」 줄, 일부 구간 정독으로 갈랐다. 이 둘의 「설치본 동작」 수는 상한 쪽이다(첫 항목이 동작 변경이면 뒤 항목은 보지 않았다).
- 분류 기준: 모델이 읽는 SKILL · agent · 템플릿 문면 변경은 「설치본 동작」으로 셌다. README · 주석 · docstring · 처분 앵커 선언 · CHANGELOG 정정은 「문서만」이다. 자기 파일 변경이 없거나, 링크 배송 바이트만 바뀌고 「호출자 0 · 동작은 같다」고 자가 선언한 것은 「판만」이다.
- git 이력은 읽지 않았다. 판 올림 하나가 PR 하나였는지는 CHANGELOG 문면으로만 봤다.

```yaml
repo_claims:
  - id: RC1
    path: "plugins/plugin-audit/CHANGELOG.md"
    anchor: "## [0.9.4] — 2026-09-22"
    line: 191
    claim: >-
      전문을 읽어 가른 판 헤딩 35개: 설치본 동작 20 · 문서만 7(1.1.5 · 1.1.3 · 0.9.2 · 0.8.2 · 0.7.2 · 0.7.1 · 0.6.2) ·
      테스트만 3(1.0.1 · 0.6.4 · 0.6.3) · 판만 3(0.9.4 · 0.8.1 · 0.7.3) · 문서+테스트 혼합(동작 무변경) 1(0.9.1) ·
      가를 수 없음 1(0.8.0 — 락만 읽는 frontmatter `input_slots`).
      판만 셋의 자가 서술: 0.9.4 「이 플러그인 자신의 표면·동작은 바뀌지 않았다」(다른 세 플러그인이 바뀌어 cache key 무효화),
      0.8.1 「이 플러그인의 파일 자체는 변경 없음」, 0.7.3 「플러그인 자체는 아니지만 … 함께 bump」.
    touches: []
    decides: [OQ13]
  - id: RC2
    path: "plugins/project-init/CHANGELOG.md"
    anchor: "(v1.7.1은 marketplace description 압축에 따른 doc-only patch bump — 동작 변경 없음.)"
    line: 449
    claim: >-
      전문을 읽어 가른 판 헤딩 42개: 설치본 동작 36(템플릿 · SKILL 문면 변경 포함) ·
      문서만 4(5.0.5 README · 4.0.3 주석+README 「동작은 바뀌지 않았다」 · 3.1.1 README · 2.0.1 `allowed-tools` 줄 제거 「동작 무변경」) ·
      테스트만 1(1.7.5) · 문서+테스트 혼합 1(1.7.4) · 판만 0 · 가를 수 없음 0.
      헤딩 없는 판이 하나 더 있다 — 1.7.1 은 문서 전용 올림이고 `[1.7.2]` 본문 괄호 한 줄로만 남았다.
    touches: []
    decides: [OQ13]
  - id: RC3
    path: "plugins/spec-distill/CHANGELOG.md"
    anchor: "patch 인 이유 — 링크로 배송하는 `render_disposition.py` 가 바뀌었다"
    line: 785
    claim: >-
      첫 항목 + 자가 선언 기준으로 가른 판 헤딩 179개(전문 미독): 설치본 동작 약 140 ·
      문서만 9(7.4.1 · 7.2.1 · 4.5.4 · 0.52.2 · 0.51.7 · 0.35.1 · 0.32.6 · 0.30.1 · 0.24.15) ·
      테스트만 11(7.0.1 · 5.1.1 · 4.5.3 · 0.52.3 · 0.51.5 · 0.51.4 · 0.35.3 · 0.32.7 · 0.26.2 · 0.26.1 · 0.11.3) ·
      판만 8(4.5.1 · 4.4.1 · 0.58.0 · 0.56.0 · 0.52.1 · 0.51.8 · 0.51.6 · 0.51.1) ·
      가를 수 없음 11(0.53.1 · 0.53.0 · 0.52.4 · 0.52.0 · 0.32.5 · 0.32.4–0.32.0 · 0.24.4).
      4.5.1 · 4.4.1 은 「spec-distill 은 `disposition_lines()` 를 부르지 않으므로 동작은 바뀌지 않는다」 고 적고도 patch 를 올렸다.
      0.58.0 · 0.56.0 은 「호출자 0」 인 공유 엔진 변경이다.
    touches: []
    decides: [OQ13]
  - id: RC4
    path: "plugins/quality-gates/CHANGELOG.md"
    anchor: "quality-gates 는 이 서브커맨드를 부르지 않아 동작은 같다(배포 바이트 변경에 따른 cache key bump)"
    line: 207
    claim: >-
      첫 항목 + 자가 선언 기준으로 가른 판 헤딩 204개(전문 미독): 설치본 동작 약 130 ·
      문서만 12(14.0.2 · 8.2.2 · 7.5.2 · 6.6.4 · 6.5.4 · 4.3.2 · 4.2.3 · 4.2.2 · 4.1.7 · 4.1.4 · 4.1.3 · 1.23.0) ·
      테스트만 31(14.1.1 · 10.0.2 · 9.3.6 · 7.6.2 · 7.5.3 · 6.6.3 · 6.6.2 · 6.5.2 · 6.4.1 · 6.3.1 · 6.2.1 · 4.3.5 · 4.2.1 ·
      4.1.13 · 4.1.12 · 4.1.11 · 4.1.9 · 4.1.8 · 4.1.5 · 3.2.2 · 3.2.1 · 2.14.18 · 2.14.8 · 2.14.3 · 2.14.2 · 2.14.1 · 2.14.0 ·
      1.30.0 · 1.26.0 · 1.12.0 · 1.8.1) ·
      판만 14(14.0.3 · 13.0.3 · 8.2.4 · 8.2.3 · 8.2.1 · 7.6.0 · 7.5.1 · 7.5.0 · 7.4.0 · 6.6.1 · 6.5.5 · 6.5.3 · 6.4.3 · 6.4.2) ·
      가를 수 없음 17(14.8.1 · 10.0.3 · 8.5.1 — 링크 배송분 변경이고 자기 동작 변화는 미확인 — 와
      7.2.1 · 7.2.0 · 7.1.2 · 7.1.1 · 6.6.5 · 6.6.0 · 4.1.10 · 4.1.6 · 4.1.2 · 4.1.1 · 3.2.3 · 2.14.14 · 2.14.12 · 2.14.11).
      판만 가운데 9개(14.0.3 · 13.0.3 · 8.2.4 · 8.2.3 · 8.2.1 · 7.6.0 · 7.5.1 · 7.5.0 · 7.4.0)는 `shared/` 로의 심볼릭 링크 대상이 바뀐 것이고,
      「호출자는 여전히 0」 또는 「qg 의 동작은 달라지지 않는다」 를 함께 적는다.
    touches: []
    decides: [OQ13]
  - id: RC5
    path: "plugins/quality-gates/CHANGELOG.md"
    anchor: "## [14.8.1] — 2026-10-30"
    line: 6
    claim: >-
      RC1–RC4 를 합친 넷의 판 헤딩 460개: 설치본 동작 약 326(71%) · 문서만 32 · 테스트만 46 · 판만 25 ·
      문서+테스트 혼합 2 · 가를 수 없음 29. 설치본 동작에 닿지 않는다고 볼 수 있는 올림이 적어도 105개(23%)다.
      spec-distill · quality-gates 몫은 첫 항목 기준이라 「설치본 동작」 은 상한이고 나머지는 하한이다.
      넷의 맨 위 헤딩은 quality-gates 14.8.1 · spec-distill 8.13.1 · project-init 5.4.1 · plugin-audit 1.7.0 이다(2026-10-29~30).
      그 뒤 2026-11-14 까지 새 헤딩이 없다.
    touches: []
    decides: [OQ13]
  - id: RC6
    path: "plugins/quality-gates/CHANGELOG.md"
    anchor: "심볼릭\n링크라 그 대상이 바뀐 이상 배포 트리 안의 코드가 바뀐 것이고 bump 대상이다\n(안 올리면 cache key 가 조용히 stale)"
    line: 723
    claim: >-
      CLAUDE.md 에 없는 올림 관행 하나가 CHANGELOG 에서 규칙처럼 되풀이된다 — 「링크로 배송되는 `shared/` 정본이 바뀌면
      그 링크를 싣는 플러그인을 전부 올린다」. [8.2.1] · [8.2.3](706행)이 이유를 cache key 로 적는다.
      [7.5.2](862행)는 「동작 무변경 — 주석만 바뀌지만 배포 파일 바이트가 바뀌므로 bump 한다(cache key)」 다.
      공유 파일 하나의 수정이 플러그인 둘의 판 헤딩 둘을 만든다
      (예: spec-distill 8.12.1 ↔ quality-gates 14.7.4, spec-distill 8.13.1 ↔ quality-gates 14.8.1).
    touches: []
    decides: [OQ13]
  - id: RC7
    path: "plugins/spec-distill/CHANGELOG.md"
    anchor: "이 브랜치의 선례대로\n  agent-transparency·plugin-audit·quality-gates·spec-distill 을 함께 bump"
    line: 1995
    claim: >-
      둘째 관행 — 플러그인 밖 공유 파일(`shared/tests/` 락 · `tools/adjudication/` 판정기)이 바뀌면 그 락의 코퍼스에 파일이 있는
      플러그인을 「함께 bump」 한다. 자기 파일이 하나도 안 바뀐 플러그인도 판이 오른다.
      [0.52.1] · [0.51.8](2032행) · [0.51.6] 「공유 파일이라 두 플러그인 다 bump」,
      plugin-audit [0.8.1] · [0.7.3], quality-gates [6.6.1] · [6.5.5] · [6.5.3] · [6.4.3] · [6.4.2].
      설치본에는 `shared/tests/` 도 `tools/` 도 실리지 않는다.
    touches: []
    decides: [OQ13]
  - id: RC8
    path: "plugins/quality-gates/CHANGELOG.md"
    anchor: "## [6.6.3] — 2026-09-04"
    line: 1365
    claim: >-
      판 올림의 실제 단위가 PR 이 아니라 Task · fix round 였던 구간이 있다. 헤딩 날짜로 세면
      quality-gates 는 2026-09-04 하루에 20개(6.0.1 · 6.2.1–6.6.3 · 7.0.0), 2026-08-21 하루에 10개(4.1.0–4.1.9)다.
      spec-distill 은 2026-09-04 에 15개(0.50.0–0.52.3), 2026-08-21 에 8개(0.30.0–0.32.4)다.
      첫 줄이 「Task 31 fix round 1…5」 · 「Task 14 수정 라운드 2」 꼴이다.
      이 구간이 문서만 · 테스트만 · 판만 · 가를 수 없음 올림의 대부분을 낸다.
    touches: []
    decides: [OQ13]
  - id: RC9
    path: "plugins/quality-gates/CHANGELOG.md"
    anchor: "## [8.3.0] — 2026-09-22"
    line: 675
    claim: >-
      판 순서와 날짜 순서가 어긋난 자리가 있다.
      quality-gates: [8.3.0] 09-22 가 [8.2.5] 09-24 · [8.2.4] 09-24 · [8.2.3] 09-23 위에 있다.
      [7.0.0] 09-04 가 [6.6.5] · [6.6.4] 09-05 위에, [6.1.0] 09-03 이 [6.0.1] 09-04 위에 있다.
      spec-distill: [0.25.0] 08-02 가 [0.24.17] 08-05 … [0.24.5] 08-03 위에 있다(4403 · 4557행).
      판 번호가 머지 순서가 아니라 브랜치에서 미리 정해졌다는 흔적이다. 정합 락은 판의 순감소만 재고 날짜는 재지 않는다(RC12).
    touches: []
    decides: [OQ13]
  - id: RC10
    path: "plugins/quality-gates/CHANGELOG.md"
    anchor: "이 절은 `2.15.0` 으로 작성됐다가 머지 시점에 `3.1.0` 으로 재산정됐다"
    line: 3169
    claim: >-
      판 올림이 병렬 브랜치와 부딪힌 기록. [3.1.0] 머리말: 「브랜치가 분기한 뒤 main 에 `3.0.0` … 이 들어와 원래 번호가 **퇴행**이었기 때문이다.
      bump 규칙은 "PR 마다 올린다"이지만, 그 규칙은 분기 이후 base 가 움직이지 않는다는 것을 암묵 전제한다 — 움직였으면 새 base 에서 다시 센다.」
    touches: []
    decides: [OQ13]
  - id: RC11
    path: "plugins/spec-distill/CHANGELOG.md"
    anchor: "Task 14 수정 라운드 2 — v0.52.0 이 이 파일의 `## [0.51.8]` 헤딩을 `## [0.52.0]`\n  으로 제자리 교체했다"
    line: 1970
    claim: >-
      판 헤딩을 손으로 끼우다 생긴 사고가 둘 기록돼 있다.
      (1) 이 자리 — v0.52.0 이 `[0.51.8]` 헤딩을 덮어써 그 판이 사라졌다. 같은 항목은 그때 통과 중이던 정합 락이 왜 못 잡았는지도 적는다
      (`ver_adjacent()` 가 minor 경계에서 아래 판의 patch 를 읽지 않는다 — 「이 락은 고치지 않는다」).
      (2) `shared/tests/test_changelog_integrity.sh` 6–12행 — quality-gates 에서 `[4.1.1]` 헤딩을 `[4.1.2]` 로 제자리에서 덮어써
      「4.1.1 은 존재한 적 없는 버전이 됐다 … 그 3일 동안 리포의 어떤 테스트도 RED 가 되지 않았다」.
      이것이 그 락의 기원이다. 복구는 quality-gates [4.1.4] 다.
    touches: []
    decides: [OQ13]
  - id: RC12
    path: "shared/tests/test_changelog_integrity.sh"
    anchor: "C3 헤딩 버전이 위에서 아래로 **순감소**."
    line: 63
    claim: >-
      이 락이 판에 기대는 것은 넷이다(이미 확인된 C2 「맨 위 헤딩 == plugin.json」 의 같음 비교 말고):
      C1 하한(`v>=1.0.0` 이면 CHANGELOG 필수) · C3 순서(헤딩 판의 순감소) · C4 표시 형식(`## [x.y.z] — <꼬리>`, 날짜면 유효한 날짜) ·
      C5a/b 인접(건너뛴 판 없음 + floor 래칫).
      판 문자열이 숫자 셋 SemVer 여야 성립한다(`HEAD_RE='^## \[[0-9]+\.[0-9]+\.[0-9]+\] — .'`, 91행.
      plugin.json 쪽도 `[0-9]+\.[0-9]+\.[0-9]+` 로 뽑는다, 197행).
    touches: []
    decides: [OQ13]
  - id: RC13
    path: "plugins/quality-gates/CHANGELOG.md"
    anchor: "**SKILL 제목 두 개가 8.0.0 bump 뒤에도 `(v7.0.0)` 이었다**"
    line: 718
    claim: >-
      판 올림이 만든 다른 낡음 — SKILL 제목에 박은 판 표기.
      `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` 236–268행이 plugin.json 의 major 를 뽑아,
      판을 단 SKILL 제목의 major 가 그것과 «같은지»(음의 락)와 그런 제목이 하나 이상 있는지(양의 락)를 잰다.
      주석: 「major 는 계약이고 minor/patch 는 그렇지 않다」.
      지금 `plugins/quality-gates/skills/quality-pipeline/SKILL.md` 45행 제목이 `(v14.0.0)` 이다(판을 단 SKILL 제목은 이 하나).
      `version` 을 비우면 이 락은 「plugin.json 에서 major 를 못 읽음」 으로 FAIL 한다.
    touches: []
    decides: [OQ13]
  - id: RC14
    path: "plugins/quality-gates/tests/test_artifact_metadata.sh"
    anchor: "floor는 minor(>=2.11) invariant다"
    line: 7
    claim: >-
      plugin.json 판을 «하한»으로 단언하는 테스트 자리 다섯과 판 헤딩 핀(RC105 의 `test_readme_sync.sh` 말고):
      (a) 이 파일 10–11행 — 정규식으로 `>= 2.11` + CHANGELOG `[2.11.0]` 헤딩 실재.
      주석: 「리터럴 major "2" 로 짠 원래 regex는 v3.0.0 major bump … 에서 stale-red 됐다」.
      (b) `plugins/quality-gates/tests/test_impact_runtime_docs.sh` 14–44행 — major `-ge 3` + `[3.0.0]` 헤딩 · Added/Changed/Removed 절 실재.
      주석: 「`"version": "3.0.0"` 리터럴을 핀하면 doc-only patch bump 마다 stale-red」.
      (c) `plugins/spec-distill/tests/test_brief_review_meta.sh` 18–29행 — `>= 0.26` 정규식 + `[0.24.0]` 헤딩.
      (d) `plugins/spec-distill/tests/test_distortion_devices.sh` 191–193행 — major `-ge 7` + `## [7.0.0] — 2026-10-17` 아래 「그래서 major.」 줄.
      (e) `plugins/spec-distill/tests/test_parallel_recommend_docs.sh` 124–133행 — 숫자 튜플 `>= (8, 11, 0)` + `## [8.11.0] — 2026-10-25`
      헤딩이 정확히 1개 + 그 절의 문구 핀.
      다섯 모두 `version` 키가 있고 점으로 나뉜 숫자여야 통과한다. `test_readme_sync.sh` 44–58행은 옛 헤딩
      [0.20.0] · [0.23.0] · [0.24.0] 을 「append-only」 로 핀한다.
    touches: []
    decides: [OQ13]
  - id: RC15
    path: "plugins/spec-distill/tests/test_conductor_state.py"
    anchor: "test_writer_stamp_roundtrip"
    line: 178
    claim: >-
      지휘자 쪽 판 읽기의 테스트(RC96 · RC97 은 확인됨): 181–185행이 `cs.own_version()` == plugin.json `version`(같음)과
      기계 상태 머리말 `writer: spec-distill <판>` 표시를 단언한다. 236행이 `""` · `"dev"` · 깨진 JSON 을 거부 입력으로 둔다.
      `plugins/spec-distill/tests/test_conductor_ledger.py` 780–994행이 설치본 5.3.0 대 레포 7.3.0 같은 순서 비교와
      `"dev"` · `"x"` 를 「비교하지 못했다」 로 잰다.
      `plugins/spec-distill/tests/test_roadmap_status.sh` 1637행이 「더 새 판(spec-distill 99.0.0)이 썼다 — 플러그인을 업데이트하고
      세션을 다시 연다」 경고를 핀한다.
    touches: []
    decides: [OQ13]
  - id: RC16
    path: "shared/deps/check_deps.py"
    anchor: "superpowers_version"
    line: 221
    claim: >-
      `check_deps.py` 가 플러그인 판에 기대는 것(RC98 의 `_measure_row` quality-gates 갈래 말고):
      (a) `superpowers_version` 은 판을 manifest 가 아니라 캐시 폴더 경로 `…/superpowers/<판>/skills/…` 의 폴더 이름에서 뽑는다.
      `superpowers_check`(338–361행)는 `dependencies.md` 의 판과 «같음»을 비교해 「검증한 판과 같다 / 다르다 / 확인하지 못했다」 를 내고 멈추지 않는다.
      (b) `entry`(304–335행)는 `triple >= floor` 하한 비교로 멈춤 · 알림을 가른다.
      (c) quality-gates 갈래(251행)는 `plugin_root/../quality-gates/.claude-plugin/plugin.json` 이라는 레포 배치의 형제 경로를 읽는다.
      진입 SKILL 의 사전 검사 줄 10곳은 `--need python` 으로만 잡혔다. 다른 자리가 `--need quality-gates` 를 부르는지는 전수 확인하지 못했다.
    touches: []
    decides: [OQ13]
  - id: RC17
    path: "plugins/plugin-audit/scripts/check-staleness.py"
    anchor: "_semver_at_least_1_0_0"
    line: 535
    claim: >-
      plugin-audit 가 감사 대상의 판에 기대는 자리(RC101 이 본 8 · 44행 · 269–274행 말고):
      535–552행 `scan_category_absence` 가 `(major, minor, patch) >= (1, 0, 0)` 하한으로 「CHANGELOG.md 없음」 을 낸다.
      `plugins/plugin-audit/scripts/check-shape-completeness.py` 51–55행은 `version` 이 없으면 `"0.0.0"` 으로 보고
      `changelog_if_v1` 을 통과시킨다(판을 비운 플러그인은 CHANGELOG 규범 밖으로 읽힌다).
      `plugins/plugin-audit/scripts/audit-workflow.js` 197 · 243행은 `pack.plugin_version` 을 감사 프롬프트 · 리포트 머리에 표시로만 쓴다.
    touches: []
    decides: [OQ13]
  - id: RC18
    path: "plugins/spec-distill/README.md"
    anchor: "버전 붙은 플러그인 폴더를 박아 두지 않고, 실행할 때마다 설치된 spec-distill 을 찾습니다"
    line: 177
    claim: >-
      판 이름이 캐시 폴더 이름이라는 사실을 피해 가는 우회가 문서에 있다. 상태줄 스크립트는 `plugins/installed_plugins.json` 의
      `installPath` 로 설치본을 찾는다(「2026-10-15 · 2.1.299 실측」).
      `plugins/spec-distill/tests/test_control_plane.sh` 665행 fixture 가 `…/cache/devbrew/spec-distill/9.9.9` · `"version": "9.9.9"` 꼴을 쓴다.
      이 길은 폴더 이름이 SemVer 인지에 기대지 않는다.
    touches: []
    decides: [OQ13]
  - id: RC19
    path: "plugins/spec-distill/references/conductor-dispatch.md"
    anchor: "10. **판 번호.**"
    line: 16
    claim: >-
      판 올림 충돌을 막는 지휘 규칙이 셋 있다(RC103 의 `SHARED_FILES` · `roadmap_status.py` 59행 말고):
      이 줄 — 같은 에픽의 계획을 동시에 돌리면 지휘자가 「판 올림 순서를 정하고 각 계획에 목표 판 번호를 적어 준다 …
      머지 순서가 바뀌면 … 뒤에 머지되는 계획이 그때 기본 브랜치 판 위의 다음 번호를 쓴다」.
      `plugins/spec-distill/references/conducting.md` 65 · 113행 — 「릴리스 번호는 머지 직전에 정한다 — 먼저 머지되는 쪽이 낮은 번호다」.
      `plugins/spec-distill/CHANGELOG.md` 219행([8.4.0])이 이 규칙을 더한 기록이다.
    touches: []
    decides: [OQ13]
  - id: RC20
    path: "docs/git-workflow/commit-conventions.md"
    anchor: "## SemVer Mapping"
    line: 51
    claim: >-
      판 올림 · CHANGELOG 규칙을 적은 자리(CLAUDE.md RC94 · RC95, `docs/plugin-authoring.md` 10 · 12행 RC108 말고):
      이 절이 commit type → SemVer 올림 표를 두고 「자동 릴리스 도구 (`release-please`, `semantic-release`)가 이 매핑으로
      version bump + CHANGELOG 생성」 이라 적는다. 레포는 그런 도구 없이 손으로 올린다.
      `docs/plugin-authoring.md` 58행 「시작 버전 `0.1.0`」.
      `docs/git-workflow/` · `docs/plugin-authoring.md` · 루트 `README.md` · `AGENTS.md` · `.github/` 를 `version|CHANGELOG|버전|bump` 로 훑은
      결과는 이 넷뿐이다. 「PR 마다 올림」 은 CLAUDE.md 와 테스트 주석(`test_readme_sync.sh` 6–10행)에만 있다. PR 절차 문서에는 없다.
    touches: []
    decides: [OQ13]
  - id: RC21
    path: "plugins/plugin-audit/CHANGELOG.md"
    anchor: "minor 인 이유 — 옛 consent.json(`approved: true`)을 검증기가 그대로 받고"
    line: 11
    claim: >-
      올림 크기(major/minor/patch)를 헤딩 아래 한 줄로 변론하는 관행이 있다. 「patch/minor/major 인 이유」 줄이
      spec-distill · quality-gates 에 41곳이고 plugin-audit · project-init 에도 있다.
      commit type 과 올림 크기가 갈린 기록: 이 줄과 `plugins/spec-distill/CHANGELOG.md` 80행 [8.10.0] 은 동작 제거인데 minor 로 올리고
      「커밋의 `!` 는 동작 제거를 알리는 표시다」 라고 적는다 — RC20 의 매핑(`!` → MAJOR)과 다르게 쓴 사례다.
    touches: []
    decides: [OQ13]
  - id: RC22
    path: "plugins/project-init/CHANGELOG.md"
    anchor: "CLAUDE.md §메타데이터의 one-minor deprecation window 없이 훅과 토큰을 같은 릴리스에서 제거한다"
    line: 218
    claim: >-
      CHANGELOG 규칙(제거 전 one-minor deprecation window)을 건너뛴 기록이 project-init 에만 셋이다:
      [3.0.0] 이 줄, [2.2.0] 271–273행 「window 를 거치지 않고 바로 제거했다 … 다운스트림이 없어 window 가 보호할 대상이 없다는 사용자 판단」,
      [2.0.0] 340–343행 「fallback 없이 즉시 제거 … 근거: 현재 제3자 설치가 없다 … 제3자 설치가 생기면 이 근거가 바뀐다」.
      plugin-audit [1.6.0] 14행도 「사용자가 정한 재건이라 deprecation 창 없이 제거한다」 다.
    touches: []
    decides: []
unanswered: >-
  spec-distill · quality-gates 는 전문을 읽지 않았다. 이 둘의 종류별 수는 첫 항목 기준 근사이고,
  「가를 수 없음」 28개(spec-distill 11 · quality-gates 17)와 「설치본 동작」 으로 센 다항목 판의 뒤 항목은 가르지 못했다.
  판 올림이 PR 과 일대일이었는지와 올림을 잊은 PR 이 있었는지는 git 이력 없이 답할 수 없다.
  네 plugin.json 과 marketplace.json 은 다시 열지 않았다(RC106 · RC107 과 정합 락 C2 에 기댔다).
```

정독한 자리(절대경로):
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/plugin-audit/CHANGELOG.md` (전문)
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/project-init/CHANGELOG.md` (전문)
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/CHANGELOG.md` (217–220 · 1967–2103행 + 전 헤딩 첫 항목)
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/CHANGELOG.md` (173–209 · 704–733 · 807–816 · 858–887 · 3167–3172행 + 전 헤딩 첫 항목)
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/tests/test_changelog_integrity.sh` (1–110행)
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/deps/check_deps.py` (219–252 · 300–369행)
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/plugin-audit/scripts/check-staleness.py` (252–276 · 530–552행)
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/plugin-audit/scripts/check-shape-completeness.py` (36–65행)
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/tests/test_artifact_metadata.sh`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/tests/test_impact_runtime_docs.sh`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` (222–270행)
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/tests/test_readme_sync.sh`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/tests/test_brief_review_meta.sh`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/tests/test_distortion_devices.sh`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/tests/test_parallel_recommend_docs.sh`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/tests/test_conductor_state.py`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/references/conductor-dispatch.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/references/conducting.md`
~~~~

### 조사 13 — orchestrator · R8 · 묶음 8

- 확인 RC156 — 확인 — plugins/spec-distill/scripts/state_path.py#state_root — 메인 레포의 `.claude/` 아래 실제 폴더: `spec-distill/`(`.docreview` · `conductor` · `.gitignore`) · `quality-gates/`(세션 폴더 · `baseline-cache` · `worktrees`) · `plugin-audit/`(`worktrees` — 실행 폴더는 `<date>-<target>` 꼴로 생긴다). project-init 은 상태 폴더가 없다(스크립트에 그 경로 0건)

## R8

### 지금 이해
경로 (a). 판 올림 재검토(조사 12)의 인용 자리를 직접 대조했다 — 네 플러그인의 판 헤딩 460개 가운데 설치본 동작에 닿지 않는다고 볼 수 있는 올림이 적어도 105개(23%)이고(종류별 수는 조사가 첫 항목 기준으로 센 근사 — 본체가 다시 세지 않았다), CLAUDE.md 에 없는 올림 관행 둘(링크로 배송되는 공유 파일이 바뀌면 싣는 플러그인을 전부 올림 · 공유 락이 바뀌면 함께 올림)과 Task · 수정 라운드마다 올린 구간이 그 대부분을 냈다. 사용자가 요청한 상태 자리 보고를 싣는다(조사 13).
조사 호출 8/60 · 이 라운드 본체 직접 1
밀린 질문 3개 — 철학 문서를 어디까지 고칠지 · 레포 조사 결과의 처분 · 열린 질문 목록 확인
줄인 사실 3개

줄인 사실 전문:
- 판을 순서 있는 숫자 셋으로 읽는 자리: 지휘자 기계 상태의 writer 판 비교 · 설치본 낡음 경고 · 의존 최소 판 · CHANGELOG 정합 락(순감소 · 건너뛴 판 없음 · 맨 위 헤딩과 같음) · plugin-audit 의 1.0.0 하한 · SKILL 제목의 major 표기 락 · 판 하한을 단언하는 테스트 다섯(RC145–RC150).
- 판 올림이 낳은 사고와 우회의 기록: 병렬 브랜치에서 판이 퇴행해 머지 때 다시 센 것 · 판 헤딩을 제자리에서 덮어써 판이 사라진 것 둘 · 판 순서와 날짜 순서가 어긋난 자리 · 「판은 머지 직전에 정한다」 는 지휘 규칙 셋(RC142–RC144 · RC152).
- `docs/git-workflow/commit-conventions.md` 는 자동 릴리스 도구가 판을 올린다고 적는데 레포는 손으로 올린다. 「PR 마다 올림」 은 CLAUDE.md 와 테스트 주석에만 있다(RC153).

- 확인 RC134 — 확인 — plugins/plugin-audit/CHANGELOG.md#「[0.9.4] — 2026-09-22」 — 인용 자리는 일치(191행), 종류별 수(35개)는 다시 세지 않았다
- 확인 RC135 — 확인 — plugins/project-init/CHANGELOG.md#「v1.7.1은 marketplace description 압축에 따른 doc-only patch bump」 — 인용 자리는 일치(449행), 종류별 수(42개)는 다시 세지 않았다
- 확인 RC136 — 확인 — plugins/spec-distill/CHANGELOG.md#「patch 인 이유 — 링크로 배송하는 `render_disposition.py` 가 바뀌었다」 — 인용 자리는 일치(785행), 종류별 수(179개)는 다시 세지 않았다
- 확인 RC137 — 확인 — plugins/quality-gates/CHANGELOG.md#「배포 바이트 변경에 따른 cache key bump」 — 인용 자리는 일치(207행), 종류별 수(204개)는 다시 세지 않았다
- 확인 RC138 — 미확인 — plugins/quality-gates/CHANGELOG.md#「[14.8.1] — 2026-10-30」 — 헤딩 합 460 은 본체 계수와 같다. 종류별 합(326 · 32 · 46 · 25 · 2 · 29)과 23% 는 조사의 근사이고 본체가 확정하지 못했다
- 확인 RC139 — 확인 — plugins/quality-gates/CHANGELOG.md#「링크라 그 대상이 바뀐 이상 배포 트리 안의 코드가 바뀐 것이고 bump 대상이다」 — 주장과 일치(726행 — 보고의 723행과 다르다)
- 확인 RC140 — 확인 — plugins/spec-distill/CHANGELOG.md#「을 함께 bump」 — 주장과 일치(1996행)
- 확인 RC141 — 확인 — plugins/quality-gates/CHANGELOG.md#「[6.6.3] — 2026-09-04」 — 주장과 일치(같은 날 헤딩 수 qg 20 · 10, spec-distill 15 · 8 — 본체 계수)
- 확인 RC142 — 확인 — plugins/quality-gates/CHANGELOG.md#「[8.3.0] — 2026-09-22」 — 주장과 일치(675행이 686 · 696 · 704행 위), 다른 어긋난 자리는 다시 보지 않았다
- 확인 RC143 — 확인 — plugins/quality-gates/CHANGELOG.md#「머지 시점에 `3.1.0` 으로 재산정됐다」 — 주장과 일치(3169행)
- 확인 RC144 — 확인 — plugins/spec-distill/CHANGELOG.md#「제자리 교체했다」 — 주장과 일치(1971행 · test_changelog_integrity.sh 9행)
- 확인 RC145 — 확인 — shared/tests/test_changelog_integrity.sh#「C3 헤딩 버전이 위에서 아래로 **순감소**.」 — 주장과 일치(63행)
- 확인 RC146 — 확인 — plugins/quality-gates/CHANGELOG.md#「SKILL 제목 두 개가 8.0.0 bump 뒤에도 `(v7.0.0)` 이었다」 — 주장과 일치(718행 · SKILL.md 45행 · 테스트 226행)
- 확인 RC147 — 확인 — plugins/quality-gates/tests/test_artifact_metadata.sh#「floor는 minor(>=2.11) invariant다」 — 7행은 일치, 나머지 테스트 넷은 파일 실재만 확인했다
- 확인 RC148 — 확인 — plugins/spec-distill/tests/test_conductor_state.py#test_writer_stamp_roundtrip — 178행은 일치, 다른 테스트 줄은 다시 열지 않았다
- 확인 RC149 — 확인 — shared/deps/check_deps.py#superpowers_version — 221행은 일치
- 확인 RC150 — 확인 — plugins/plugin-audit/scripts/check-staleness.py#_semver_at_least_1_0_0 — 주장과 일치(535행 · check-shape-completeness.py 51–55행)
- 확인 RC151 — 확인 — plugins/spec-distill/README.md#「버전 붙은 플러그인 폴더를 박아 두지 않고」 — 주장과 일치(177행)
- 확인 RC152 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#「판 번호.」 — 주장과 일치(16행 · conducting.md 113행)
- 확인 RC153 — 확인 — docs/git-workflow/commit-conventions.md#「SemVer Mapping」 — 주장과 일치(51 · 61행)
- 확인 RC154 — 확인 — plugins/plugin-audit/CHANGELOG.md#「minor 인 이유 — 옛 consent.json」 — 11행은 일치, 「이유」 줄 수는 본체 계수 53(보고 41)
- 확인 RC155 — 확인 — plugins/project-init/CHANGELOG.md#「one-minor deprecation window 없이」 — 218행은 일치, 다른 두 자리는 다시 열지 않았다
- 확인 RC156 — 확인 — plugins/spec-distill/scripts/state_path.py#state_root — 본체가 직접 확인(조사 13)

### 다음 결정
OQ13: 판 올림을 공식의 두 길 가운데 어느 쪽으로 할까 · 추천: 판은 두고 올림 단위를 푼다 · 트레이드오프: 판을 비우면 판을 읽는 자리 일곱 갈래를 다시 짠다 / 설계에 맡기면 지금은 정해지지 않는다
OQ18: 숨은 가정 · 실패 양식 가운데 이 일이 반드시 다뤄야 할 것은 무엇인가 · 추천: 원자료의 비밀값 · 질문과 선택지에서 생기는 의역 · 트레이드오프: 고른 것은 요구가 되고 고르지 않은 것은 위험으로만 실린다
OQ19: 작은 일에서 필수 조사 · 리뷰를 건너뛰는 것을 구조 게이트가 어떻게 받을까 · 추천: 건너뛴 사실을 사람에게 보이고 통과 · 트레이드오프: 사용자가 고를 때만이면 질문이 하나 는다 / 기준을 먼저 정하면 기준 밖 일은 못 건너뛴다
OQ20: 덩어리 승인 화면에서 무엇이 보기 어려웠나 · 추천: 문단 전체가 두 번 나온다 · 어느 지적 때문인지 안 보인다(본체의 추측) · 트레이드오프: 없음 — 사용자만 답할 수 있다

### 질문
경로 (b) · (d). 한 호출에 넷(서로 기대지 않는다).
1. 판 올림을 공식의 두 길 가운데 어느 쪽으로 할까요?
2. 숨은 가정 조사가 찾은 위험 가운데 이 일이 반드시 다뤄야 할 것을 고르세요(여럿 고를 수 있습니다). 고르지 않은 것도 결과물에 위험으로 실립니다.
3. 작은 일에서 필수 조사 · 리뷰를 모델이 건너뛸 때, 끝의 구조 검사는 그것을 어떻게 받을까요?
4. seed 리뷰의 덩어리 승인 화면에서 무엇이 보기 어려우셨나요(여럿 고를 수 있습니다)?

### 답
→ S18 · S19 · S20 · S21

- blind_spot · 표준_대조_범위 · 게이트와_락 · 승인_화면 닫음 — 각 차원의 질문에 답한 S(머리말 evidence)
- S19 에서 고르지 않은 「이름을 바꾼 뒤 옛 이름이 남는 동안」 과 선택지에 싣지 못한 위험 넷은 요구가 아니라 위험으로 싣는다.
- S21 은 넷을 모두 골랐다 — 「추천이 없다」 는 request-framing 의 지금 규칙(덩어리 처분에 추천을 달지 않는다 — 저자가 승인 여부를 가르지 않게)과 부딪힌다. 이 긴장은 설계로 넘길 열린 질문에 싣는다.

## R9

### 지금 이해
경로 (b). floor 다섯 가운데 넷(root_problem · landscape · skepticism · blind_spot)과 파생 차원 여섯이 닫혔다. 남은 것은 철학 문서의 범위, 레포 조사 결과의 처분(internal_research), 설계로 넘길 열린 질문 목록의 확인(open_questions)이다.
조사 호출 8/60 · 이 라운드 본체 직접 0
줄인 사실 1개

줄인 사실 전문:
- 레포 주장 156건 가운데 확인 153 · 미확인 3(RC58 옆 설계문서의 원문 대조 줄 범위 · RC138 판 올림 종류별 합 · 그리고 확인으로 적었으나 일부만 본 것은 줄마다 그 사실을 적었다). 반증 0. seed 의 서술을 바로잡은 것은 「대체됨」 줄 일곱이다.

### 다음 결정
OQ21: 이 일이 철학 문서를 어디까지 고칠까 · 추천: 옆 로드맵이 고치는 문장(P8)은 그쪽에 두고 그 밖만 · 트레이드오프: 전체를 이 일이 보면 같은 문서를 두 일이 다른 잣대로 고친다 / 빼면 「표준에 맞게 · 푸는 쪽으로」 가 이 일에서 실행되지 않는다
OQ22: 레포 조사에서 확인한 사실을 결과물의 근거로 어떻게 실을까 · 추천: 그대로 싣고 미확인은 표시한다 · 트레이드오프: 마저 확인하면 조사가 더 돈다
OQ23: 설계로 넘길 열린 질문 목록이 맞는가 · 추천: 이대로 싣는다 · 트레이드오프: 지금 더 정하면 라운드가 는다

### 질문
경로 (b). 한 호출에 셋(서로 기대지 않는다).
1. 철학 문서는 옆 로드맵의 지휘 절차 에픽이 원칙 P8 을 고치려고 예약해 두었습니다. 이 일은 철학 문서를 어디까지 고칠까요?
2. 레포 조사에서 확인한 사실(주장 156건 — 확인 153 · 미확인 3 · 반증 0)을 결과물의 근거로 어떻게 실을까요?
3. 아래 목록을 설계로 넘길 열린 질문으로 싣고 인터뷰를 닫아도 될까요?
4. (질문을 띄우기 전에 들어온 사용자 말 S22 「.claude/<플러그인>/worktrees/ 이거보다는 그냥 워크트리를 쓰는게 좋을거 같고 나머지는 다 공식대로 옮기면 되겠는데?」 의 확인 — OQ24) 「나머지는 다 공식대로」 가 기록 성격의 둘(문서 리뷰 원장 · 감사 실행 폴더)까지 포함하나요? 본체의 읽기: 비교용 작업 사본은 플러그인 폴더 아래에 따로 두지 않고 표준 git 작업 사본 자리를 쓴다 · 나머지 캐시 성격의 것은 공식 데이터 폴더로 옮긴다. S15 의 「캐시만 옮긴다」 와 기록 둘의 자리는 이 답으로 정한다.

### 답
→ S22(질문 전에 들어온 말) · S23 · S24 · S25 · S26

- internal_research · open_questions 닫음 — floor 다섯과 파생 차원 일곱이 모두 닫혔다.
- S26 「2, 둬야할 위치를 docs아래로 바꾼다 꼭 둬야하는 경우에만 」 은 둘째 선택지(기록 둘까지 전부 옮긴다)에 조건을 붙인 말로 읽었다 — 프로젝트의 `.claude/<플러그인>/` 에는 상태를 남기지 않고, 꼭 남겨야 하는 기록만 docs 아래에 둔다(본체의 읽기 — 확인받지 않았다).
- 재결정(P23): 원래 — S15 「캐시만 옮긴다」(기록 둘은 프로젝트에 남는다고 본체가 표에 적음) / 재결정 — 기록까지 공식 데이터 폴더로 옮기고, 꼭 둬야 하는 것만 docs 아래에 둔다(S22 · S26) / 근거 — 사용자 말 「나머지는 다 공식대로 옮기면 되겠는데?」 · 「둬야할 위치를 docs아래로 바꾼다 꼭 둬야하는 경우에만」
- 비교용 작업 사본: 플러그인 폴더 아래에 따로 두지 않고 「그냥 워크트리」 를 쓴다(S22) — 어느 자리인지는 설계 몫(OQ32).
- 설계로 넘길 열린 질문 열하나를 OQ25–OQ35 로 발급했다(전부 열림).

### 조사 14 — orchestrator · R9 · 묶음 9

- 확인 RC157 — 확인 — shared/docreview/scripts/docreview_state.py#플러그인이 링크로 싣는 정본 — `git ls-files` 의 링크(mode 120000)는 `plugins/` 아래 43개이고 대상은 `shared/` 의 adjudication · codex · deps · docreview · entry · test-selection 여섯 폴더다. `shared/` 의 gc · killswitch · python · style · tests 와 레포 루트의 `tools/` 는 링크 대상이 아니다(설치본에 링크로 실리지 않는다)
- 실측(이 기계 · 2026-11-14): devbrew 마켓플레이스의 소스 종류는 git 이고 자동 갱신이 켜져 있다. 네 플러그인 모두 사용자 범위로 판 이름 캐시 폴더(`cache/devbrew/<플러그인>/<판>`)에 깔려 있다 — 제자리 읽기가 아니라 캐시 사본이다 [→ OQ13]
- 실측(이 세션 · 2026-11-14): Bash 로 도는 명령의 환경에 `CLAUDE_PLUGIN_DATA` · `CLAUDE_PLUGIN_ROOT` 가 없다. `~/.claude/plugins/data/` 는 있고 `spec-distill-devbrew` · `quality-gates-devbrew` · `project-init-devbrew` 폴더가 이미 있다. Bash 에서 그 폴더 아래에 빈 폴더와 파일을 만들었다 지우는 쓰기가 성공했다(샌드박스를 켠 세션에서는 재지 않았다) [→ OQ32]

### 조사 15 — repo-researcher · R9 · 묶음 10

~~~~
레포 루트: `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit` (아래 `path` 는 이 루트 기준 상대경로). 상태 파일 `## R6`(RC109–RC121) · `### 조사 13`(RC156)에 이미 있는 것은 되풀이하지 않았다.

```yaml
repo_claims:
  # ── spec-distill: 상태 루트 ─────────────────────────────────────────────
  - id: RC1
    path: "plugins/spec-distill/scripts/state_path.py"
    anchor: "_check_state_root"
    line: 161
    claim: "상태 루트가 레포 트리 안이어야 한다는 검사가 코드에 있다. (a) 루트가 본 체크아웃(공용 git 디렉토리의 부모) 밖이면 StateRootError 「상태 폴더({0})가 본 체크아웃({1}) 밖이다」, (b) `git check-ignore -q <rel>/probe` 가 1 이면 「상태 폴더가 git 무시 목록에 들지 않는다」, (c) `git ls-files -- <rel>` 에 줄이 있으면 「상태 폴더 아래 파일이 이미 추적된다」, (d) `inside_root(root, root.parent.parent)` 로 `.claude` · `spec-distill` 성분이 링크면 거부. 공용 git 디렉토리 이름이 `.git` 이 아니거나 bare 거나 git 레포가 아니면 (a)–(c) 를 건너뛴다. 루트의 `.gitignore`(`*` 한 줄)는 `_write_ignore` 가 O_EXCL|O_NOFOLLOW 로 처음 한 번 만든다."
    touches: []
    decides: [OQ32]
  - id: RC2
    path: "plugins/spec-distill/scripts/gc_common.py"
    anchor: "root_escapes"
    line: 64
    claim: "정리(GC)의 안전 검사가 상태 루트의 꼴을 `<부모의 부모>/.claude/<namespace>` 로 박아 둔다 — `os.path.realpath(root) != join(realpath(root.parent.parent), '.claude', namespace)` 면 탈출로 보고 아무것도 지우지 않는다. `locked_root` 는 잠금 파일 없이 루트 디렉토리 fd 에 flock 을 건다(이유 원문: 「루트 아래 고정 이름은 저장소가 링크로 커밋할 수 있어서」). 이 파일은 `shared/gc/gc_common.py` 의 사본이고 quality-gates 도 같은 사본을 쓴다."
    touches: []
    decides: [OQ32]
  - id: RC3
    path: "plugins/spec-distill/skills/spec-review/SKILL.md"
    anchor: "path-inside --root \"${ROOT%/.claude/spec-distill}\" \"$STATE_DIR\""
    line: 269
    claim: "skill 의 bash 펜스가 상태 루트 문자열 끝에서 `/.claude/spec-distill` 을 잘라 레포 루트를 얻고, 원장 폴더가 그 레포 안이고 링크를 안 거치는지 `state_path.py path-inside` 로 잰다. 실패하면 `STATE_DIR` 을 비우고 리뷰 없이 끝낸다(「비었거나 레포 밖이거나 링크를 지난다」). 같은 문자열이 spec-review · reviewing-brief · request-framing(418행) · pm-interview/references/finishing.md(362 · 411행) 펜스에 되풀이된다(전체 자리 수는 세지 않았다 — grep 이 20줄에서 잘렸다)."
    touches: []
    decides: [OQ32]

  # ── spec-distill: .docreview/ ────────────────────────────────────────────
  - id: RC4
    path: "plugins/spec-distill/scripts/docreview_state.py"
    anchor: "state_dir_for"
    line: 916
    claim: "원장 폴더는 `<root>/.docreview/<파일 stem 이름표 40자>-<sha256(realpath(doc)) 앞 16자>` — 문서 «절대 실경로»의 순수 함수이고 세션과 무관하다. 상대 루트 · 상대 문서는 거부한다(`root_not_absolute` · `doc_not_absolute`). 열쇠가 레포 상대경로가 아니라 실경로 해시라서, 문서나 레포가 옮겨지면 다른 폴더가 된다. (이 경로는 Glob 목록에 안 나온다 — `shared/docreview/scripts/docreview_state.py` 로 가는 링크로 보이고, 테스트는 shared 쪽 경로를 부른다.)"
    touches: []
    decides: [OQ32]
  - id: RC5
    path: "plugins/spec-distill/scripts/docreview_state.py"
    anchor: "save_state"
    line: 311
    claim: "엔진이 쓰는 파일은 둘이다. `docreview-state.md` — frontmatter 첫 줄 `docreview_digest: <sha256>` 뒤 `docreview:` 트리(doc · profile · round · rereview_count · extra_rounds · snapshots · findings · decides · fixes · asks · permits · applied_scopes · decision_log · rounds · pending_recritic · rejected_lineages · escalated · reraise · engine_lines · count_logged), 본문은 `# docreview 원장` 아래 `- r<n>: <사건>` 로그. `docreview-digest-era` — 빈 표지 파일(있는데 원장에 확인값 줄이 없으면 `ledger_corrupt`). 쓰기는 O_NOFOLLOW 제자리 덮어쓰기이고 링크 · 하드링크(nlink≠1)면 `ledger_not_plain_file` 로 거부한다. 읽는 쪽은 `load_state`(엔진 전 서브커맨드 · `ledger_sweep.recorded_doc` · `ledger_marker.cmd_resume_note`)."
    touches: []
    decides: [OQ32]
  - id: RC6
    path: "plugins/spec-distill/scripts/docreview_state.py"
    anchor: "RECOVER"
    line: 260
    claim: "원장을 지우면 다시 만들 수는 있으나 이력을 잃는다고 코드가 적는다 — 깨진 원장의 복구 안내 원문: 「그 문서의 상태 폴더를 지우고 1라운드부터 다시 리뷰한다 — 라운드 · 재리뷰 횟수 · 지적 이력을 잃는다」. `cmd_init` 은 원장이 없으면 빈 원장(round 0)을 새로 쓴다."
    touches: []
    decides: [OQ32]
  - id: RC7
    path: "plugins/spec-distill/skills/request-framing/SKILL.md"
    anchor: "**원장 자리의 수명**"
    line: 1071
    claim: "seed 리뷰 원장의 수명과 소실 결과: 「`.docreview/` 아래 seed 마다 하나이고, 세션이 끝나도 남습니다」 · 정리는 「seed 가 더는 없고 TTL(기본 24시간) 동안 쓰기가 없는 원장만」 · 「원장이 사라지면 엔진 호출이 `state_missing` 으로 죽고, 저자 편집 공시는 기준 사본 부재(rc 3 경로)로 떨어집니다. 사용자 결정은 audit `## 6. 리뷰 결정` 에 남아 있어 잃지 않고, 확정 직전 drop 검사는 엔진 원장 없이 그 기록으로 대조합니다」. 즉 사용자 결정의 사람이 볼 사본은 추적되는 audit 문서 쪽이고 원장 폴더는 엔진 작업 상태다."
    touches: []
    decides: [OQ32]
  - id: RC8
    path: "plugins/spec-distill/skills/request-framing/SKILL.md"
    anchor: "BUNDLE=\"${STATE_DIR:+$STATE_DIR/seed-bundle.md}\""
    line: 421
    claim: "원장 폴더에 엔진 파일 말고 skill 펜스가 두는 작업 파일들: seed 리뷰 — `seed-bundle.md` · `seed-bundle-recritic.md` · `docreview-codex.yaml` · `seed-baseline.md`(저자 편집 공시의 기준 사본; `seed_edit_diff.py` 가 `.shown` · `.reverted` 짝을 쓴다 — tests/test_state_dir_writes.sh 3행) · `critic.txt` · `critic-<i>.txt` · `recritic.txt` · `said-r<n>.txt` · `said-extra-r<n>.txt` · `said-<id>.txt` · `note-<id>.txt` · `said-hunk-<k>.txt` · `absent-note.txt` · `gate-drops.json` · `hunks.json` · `hunks-final.json` · `gate-final.json` · `readback.txt`. brief 리뷰(reviewing-brief/SKILL.md 61 · 63 · 378행) — `brief-bundle.md` · `brief-degrade-fallback.txt` · `docreview-codex.yaml` · `critic*.txt`. 설계문서 리뷰(spec-review/SKILL.md 384 · 479행) — `docreview-codex.yaml` · `critic*.txt`. `said-*` · `note-*` 는 audit 에 옮겨 적은 뒤 같은 펜스가 `rm -f` 한다(839 · 855 · 886행)."
    touches: []
    decides: [OQ32]
  - id: RC9
    path: "plugins/spec-distill/scripts/ledger_marker.py"
    anchor: "MARKER = \"reviewing-by\""
    line: 20
    claim: "원장 폴더의 표지 둘 — `reviewing-by`(지금 리뷰 중인 세션 id 한 줄, O_EXCL|O_NOFOLLOW 로 잡고 `release` 가 unlink) · `last-session`(release 때 원자 쓰기로 남기는 직전 세션 id; `resume-note` 가 「이전 리뷰 라운드 N 에서 이어 간다」 줄을 낼지 정할 때 읽는다). 진입은 원장 폴더와 그 부모가 링크가 아니고 `inside_root(d, parent)` 를 통과해야 한다."
    touches: []
    decides: [OQ32]
  - id: RC10
    path: "plugins/spec-distill/scripts/ledger_sweep.py"
    anchor: "sweep_ledgers"
    line: 105
    claim: "`.docreview/<키>/` 를 지우는 것은 이 스크립트 하나다(리뷰 진입 펜스가 표지를 잡기 전에 부른다 — spec-review 274행 · reviewing-brief 150행 · request-framing 518행). 지우는 조건: 원장에 적힌 `doc` 절대경로가 더는 없고 `gc_one` 의 TTL(`DEVBREW_SPEC_DISTILL_TTL_HOURS`, 기본 24시간 — 폴더 아래 모든 항목의 최신 mtime 기준)을 넘었을 때. 원장을 못 읽거나 `doc` 이 상대경로면 지우지 않고 「읽지 못한 원장」 으로 알린다. 문서가 있는 한 원장은 시간과 무관하게 남는다. 같은 스크립트가 옛 세션 폴더 `<root>/<sid>/docreview/<x>/` 를 새 자리로 옮기고, `state.local.md` 가 든 옛 세션 폴더는 지우지 않고 알린다."
    touches: []
    decides: [OQ32]
  - id: RC11
    path: "shared/docreview/scripts/nofollow_write.py"
    anchor: "마지막 경로 성분의 링크를 따라가지 않고 파일을 쓴다."
    line: 2
    claim: "펜스의 상태 폴더 쓰기가 거치는 writer 는 세 모드(`run --out P -- <명령>` · `empty --out P` · `append --out P`)이고 P 옆 임시 파일 + `os.replace` 로 놓는다. 막는 것은 «마지막 성분» 의 링크 · 하드링크뿐이고 레포 안/밖은 재지 않는다 — 자리와 무관하게 도는 방어다. 실패는 rc 73."
    touches: []
    decides: [OQ32]

  # ── spec-distill: conductor/ ─────────────────────────────────────────────
  - id: RC12
    path: "plugins/spec-distill/scripts/conductor_state.py"
    anchor: "machine_dir"
    line: 82
    claim: "지휘자 상태 폴더는 `<state-root>/conductor/<로드맵 경로의 끝에서 둘째 성분>` — 로드맵 «폴더 이름» 이 열쇠다. 로드맵 경로에서 폴더 이름을 못 얻으면 MachineError 다(로드맵 없이 부르는 길이 없다). `machine.md` 의 `## 작업` 절만 모듈 머리말이 「작업(로드맵 밖 일 포함)」 이라 적는다 — 그 줄도 어떤 로드맵의 machine.md 안에 산다."
    touches: []
    decides: [OQ32, OQ28]
  - id: RC13
    path: "plugins/spec-distill/scripts/conductor_state.py"
    anchor: "SECTIONS"
    line: 36
    claim: "`machine.md` 내용: frontmatter(`type: conductor-machine` · `roadmap:` · `writer: spec-distill <판>`) 뒤 절 여덟 — PR(브랜치 · 번호 · 상태 · 확인한 때 · headRefOid · 교차 레포 · baseRefName · mergeCommit · 쓴 세션) · 에픽 PR · 실행 원장 · 자원 · 살아 있는 agent · 작업 · 기다리는 질문 · 쌓인 기록. `레포 설정` · `시작 승인` 은 읽을 때 버리는 옛 절. 모듈 머리말: 「이 기계에서만 뜻이 있는 것 … 만 담는다. 이어 가기에 필요한 기록은 에픽 설계문서의 절이 주인이다」. 쓰기는 `save`(표지 `conducting-by` 를 쥔 세션만, mkstemp + os.replace)이고 부르는 쪽은 `conductor_ledger.update`. 읽기는 `load`(파일이 없으면 빈 상태 · 링크면 거부) — `conductor_ledger.py` · `merge_check.py`(옛 절 유무만) · `control_plane.machine_for`(읽기 전용, 896–931행) · `roadmap_status.py`(머리말이 그렇게 적는다 — 본문은 열지 않았다)."
    touches: []
    decides: [OQ32]
  - id: RC14
    path: "plugins/spec-distill/references/roadmap-ontology.md"
    anchor: "쌓인 기록만은 다시 만들 수 없다 — 지우기 전에 커밋한다"
    line: 38
    claim: "기계 상태에서 다시 만들 수 없다고 문서가 적는 것은 둘이다. (1) 이 줄의 「쌓인 기록」(아직 설계문서 절로 커밋하지 못한 기록), (2) references/conducting.md 82행 「에픽 PR 번호 기록은 다시 만들 수 없고, 정리 뒤에도 상태 계산이 같은 번호로 머지를 판정한다」 — 그래서 로드맵 끝에서도 `## 에픽 PR` 은 남기고 나머지만 비운다. PR 캐시는 `conductor_ledger.py pr-refresh [--reset]`(머리말 13행: 「PR 캐시를 head 이름의 PR 전부로 채운다」)로 다시 채워진다. 기계 상태 «폴더» 를 지우는 스크립트는 찾지 못했다 — 끝맺음은 절을 비우고 표지를 푸는 데까지다(conducting.md 79 · 82행)."
    touches: []
    decides: [OQ32]
  - id: RC15
    path: "plugins/spec-distill/scripts/conductor_ledger.py"
    anchor: "disposable_kind"
    line: 169
    claim: "기계 상태 폴더 아래 하위 자리와 지우는 규칙: `merge-check/run-<ts>-<pid>/{base,merged}`(스위트 대조 사본) · `review/<에픽>-<ts>`(리뷰 묶음, 1206행) · `files/{tmp,relay,report}/<이름>`(`resource-dir` 이 만드는 agent 몫 임시 폴더 · 옮김 기록 · 하위 보고, 1318행) — 이 셋만 `cleanup` 이 「확인 없이 지운다」(729행). 판정은 레포가 아니라 «기계 상태 폴더 기준» 경로 모양으로 한다(`rp.parent.parent == mdir / …`). 그 밖 경로는 등록된 worktree 여야 하고 더러우면 지우지 않고 사용자에게 보인다(790행). `files/suite-lock` 은 자원 폴더 아래지만 cleanup 대상 종류가 아니다(suite_lock.py 42행)."
    touches: []
    decides: [OQ32]
  - id: RC16
    path: "plugins/spec-distill/scripts/merge_check.py"
    anchor: "make_copies"
    line: 152
    claim: "스위트 대조는 `<기계 상태 폴더>/merge-check/run-<YYYYmmddHHMMSS>-<pid>/` 에 `git worktree add --detach` 로 `base` · `merged` 두 사본을 만든다(455–459행) — 상태 폴더 안에 git worktree 가 등록된다. 끝나면 `finally` 가 `git worktree remove --force`(실패하면 rmtree)로 사본을 지우고 `--keep-merged` 가 아니면 실행 폴더째 rmtree 한다(472–482행). 진입 때 `ensure_state_root` 를 부른다(441행). 실행마다 새로 만드는 일회용이고 결과는 stdout 보고로만 남는다. 사본 자리가 레포 트리 안이어야 한다는 검사는 이 파일에 없다 — 자리는 `state_root` 도출을 따를 뿐이다."
    touches: []
    decides: [OQ32]
  - id: RC17
    path: "plugins/spec-distill/scripts/suite_lock.py"
    anchor: "lock_path"
    line: 41
    claim: "공유 스위트 잠금은 `<기계 상태 폴더>/files/suite-lock/` 폴더(mkdir 로 잡음)와 그 안 `owner` 파일(`<pid> <이름> <시각>`)이다. 지휘자의 `merge_check.py` 와 하위 agent 의 전체 스위트가 같은 잠금을 쓴다 — 경로를 `conductor_ledger.py suite-lock` 이 도출해 하위에게 보내는 글에 싣는다. 주인 프로세스가 죽은 잠금은 `take` 가 `<이름>.stale-<pid>-<ms>` 로 옮긴 뒤 rmtree 한다. 수명은 스위트 한 번이고 지워져도 다음 `take` 가 다시 만든다. 다른 worktree 의 agent 도 같은 잠금을 봐야 하므로 worktree 마다가 아니라 한 자리여야 하는 상태다(메인 레포 쪽 상태 루트에서 도출)."
    touches: []
    decides: [OQ32]

  # ── quality-gates ────────────────────────────────────────────────────────
  - id: RC18
    path: "plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md"
    anchor: "## 생명주기"
    line: 69
    claim: "세션 폴더 `.claude/quality-gates/<session-id>/` 의 내용과 수명. `result.md`(frontmatter session_id · started_at + 절: 판정 · 범위 · 문서 경로 · 지적 · 낮춘 지적 · 제외 패치 · 추가 반복 · 차등 테스트 · e2e · 뒤집기 · 게시) — 「게시 코멘트에 실리지 않는 것 — 지적 전부(SUGGESTION 포함) · 제외 패치 · 차등 요약 — 이 여기 남는다」. 같은 폴더의 다른 파일: `intent.md` · `excluded.md` · `extra-iterations.md` · `differential.yaml` · `differential-not-counted.md` · `verdict.out` · `topic-scope.txt` · `range-scope.txt` · `review-tree.txt` · `comment-head.md` · `comment.md` · `publish.out` · `publish.err` · `e2e-*.{md,tsv,txt,pgid,log}` · `review-i<N>.{names,full.diff,diff,doc-paths,self-state}`. 만드는 것은 `setup-qg.sh`(매 실행 폴더를 새로), 덧붙이는 것은 파이프라인 펜스, 지우는 것은 `qg-gc.py`(TTL 기본 24시간, `result.md` 가 세션 폴더 표지). 즉 한 실행의 결과가 사람이 볼 수 있는 꼴로 남지만 같은 세션의 다음 실행이나 24시간 뒤 GC 에 사라진다."
    touches: []
    decides: [OQ32]
  - id: RC19
    path: "plugins/quality-gates/scripts/setup-qg.sh"
    anchor: "rm -rf -- \"./.claude/quality-gates/${SESSION_ID:?}\""
    line: 270
    claim: "qg 의 상태 루트는 메인 레포가 아니라 «지금 worktree 의 최상위» 다 — `git rev-parse --show-toplevel` 로 옮겨 간 뒤 상대경로 `.claude/quality-gates` 를 쓴다(188–194행; git 밖이면 cwd). spec-distill(`--git-common-dir` 로 메인 레포)과 다르다. 자기 세션 폴더는 마커 없이도 지우고 다시 만들며, 지우기 전에 `e2e-state.sh stop --dir` 로 앞 실행이 남긴 앱을 내린다. `.claude` 나 state root 가 「제자리의 실제 디렉토리」(`$here/.claude/quality-gates` 로 풀림)가 아니면 지우기 · 만들기를 모두 거부한다(`root_escapes`, 213–256행). SKILL.md P2 펜스(100–101행)는 실행 시작마다 앞 실행의 파일 목록을 `rm -f` 하고 `e2e-app.pgid` 만 남긴다."
    touches: []
    decides: [OQ32]
  - id: RC20
    path: "plugins/quality-gates/scripts/qg-gc.py"
    anchor: "_is_session_folder"
    line: 75
    claim: "GC 는 `ROOT = Path('.claude/quality-gates')`(cwd 상대)에서 이름이 세션 정규식에 맞고 «마커 파일» (`result.md` 또는 옛 마커 `files.md` · `publish-eligible.md` · `pipeline.md` · `runtime-evidence.md`)이 든 폴더만 TTL 로 지운다. 자기 세션과 링크 자식은 건너뛴다. 그래서 형제 폴더 `worktrees` · `baseline-cache` 는 GC 가 지우지 않는다(마커가 없다). 부르는 곳은 `setup-qg.sh` 274행 하나(매 실행, 실패해도 진행). 끄는 스위치는 `DEVBREW_QUALITY_GATES_DISABLE=1` · `DEVBREW_SKIP_HOOKS=quality-gates:qg-gc`."
    touches: []
    decides: [OQ32]
  - id: RC21
    path: "plugins/quality-gates/README.md"
    anchor: "**`.claude/quality-gates/baseline-cache/`** — 12.x 까지의 판이 남긴 기준선 캐시 폴더다."
    line: 427
    claim: "`baseline-cache/` 는 지금 코드에 쓰는 스크립트도 읽는 스크립트도 지우는 스크립트도 없는 옛 잔재다 — 「13.0.0 은 이 폴더를 쓰지도 읽지도 않고 GC 도 지우지 않는다 — 남아 있으면 직접 지워도 된다」. `scripts/` 에 `baseline-cache.sh` 가 없고(Glob), 남은 참조는 예약 이름 거부(`setup-qg.sh` 196–200행: 세션 id 가 `worktrees` · `baseline-cache` 면 거부)와 GC 주석 · 테스트뿐이다. CHANGELOG 249행이 생산자 제거를 적는다. 지금 차등 테스트의 실행 안 메모(기준선 행 · 배정 · 대조 산출)는 레포 «밖» `${TMPDIR:-/tmp}/qg-memo.XXXXXX` 에 두고 레포 안이면 거부한다(`qg-worktree.sh` memo-init 173–186행: 「검사 대상 트리 밖이어야 봉인(HEAD 축)에 섞이지 않는다」)."
    touches: []
    decides: [OQ32]
  - id: RC22
    path: "plugins/quality-gates/scripts/qg-worktree.sh"
    anchor: "make_detached_worktree"
    line: 38
    claim: "`worktrees/` 는 차등 테스트 두 축과 범위 모드 리뷰 트리의 일회용 git worktree 다 — `<show-toplevel>/.claude/quality-gates/worktrees/{base,head}-<세션 id 앞 8자>`, `git worktree add --detach`. 같은 이름이 남아 있으면 지우고 다시 만든다(66–75행). 자리가 레포 안이어야 한다는 검사가 코드에 있다: 만들기 전 가장 깊은 기존 조상의 실경로가 `$main_root/` 아래가 아니면 「일회용 트리 자리가 리포 밖을 가리킨다 — 만들지 않는다」, 만든 뒤 parent 실경로가 `$main_root/.claude/quality-gates/worktrees` 와 글자로 같지 않으면 거부(51–63행). `remove` 는 대상 실경로가 그 이름공간 아래일 때만 지운다(148–167행: 「refuse to remove outside namespace」). 주석이 적는 이유는 git worktree 의 요구가 아니라 커밋된 `.claude` 링크가 레포 밖 강제 삭제로 이어지는 것을 막는 것이다. 범위 모드 리뷰 트리는 같은 `create-head --range` 로 만들고 경로를 세션 폴더 `review-tree.txt` 에 적어 실행 끝에 `remove` 한다(SKILL.md 145–148 · 1497–1506행). 차등 축 트리를 실행 끝에 지우는 자리는 references/differential-test.md 쪽이고 열지 않았다."
    touches: []
    decides: [OQ32]
  - id: RC23
    path: "plugins/quality-gates/scripts/seal-worktree.sh"
    anchor: "qg 자신의 네임스페이스(.claude/quality-gates/)는 워킹트리 쪽에서 집지 않는다(R-X)."
    line: 41
    claim: "상태가 레포 트리 안에 있어서 생긴 대응 코드가 둘 있다. (1) 봉인: `git check-ignore -q .claude/quality-gates` 로 무시 여부를 물어 무시돼 있으면 plain `add -A`, 아니면 `':(exclude).claude/quality-gates'` pathspec 으로 뺀다 — 무시 규칙에 따라 갈래가 갈린다. SKILL.md 257행: 「스코프 파일은 cwd 가 아니라 **리포 루트**의 `.claude/quality-gates/<session-id>/` 에 둔다(봉인이 빼는 자리는 리포 루트의 그 네임스페이스뿐이다)」. (2) 리뷰 diff: `review-diff.sh` 212–252행이 세션 폴더 바로 아래의 알려진 이름(`QG_NAMES`)과 `worktrees/(base|head)-<sid8>/` 를 qg 자기 상태로 보고 건너뛴다 — 「대상 리포가 `.claude/quality-gates` 를 무시하지 않아도 앞 반복의 산출물이 다음 반복의 변경으로 세어지지 않게」, 그리고 「--dir 가 리포 밖이면(DIR_REL 없음) 아무것도 건너뛰지 않는다」. 봉인용 임시 인덱스 자체는 레포 트리가 아니라 `.git` 안(`git rev-parse --git-path qg-seal-<sid8>.<pid>.index`)에 둔다."
    touches: []
    decides: [OQ32]

  # ── plugin-audit ─────────────────────────────────────────────────────────
  - id: RC24
    path: "plugins/plugin-audit/skills/plugin-audit/SKILL.md"
    anchor: "4. **실행 디렉토리**"
    line: 94
    claim: "실행 폴더 `.claude/plugin-audit/<date>-<target>[-N]/` 의 내용: `.gitignore`(`*`) · `consent.json`({at, fanout, axes}) · 무결성 스냅샷 `before.txt` · `before-harness.txt` · `after.txt` · `after-harness.txt` · 축 질문 파일 · `wf.json` · `codex.json` · `meta.json` · `assigned.json` · `audit-data.json` · `audit-journal.jsonl`(secret 스캔을 통과한 Workflow journal) · `audit.md`(리포트) · 무효 때 `VOID`. 쓰는 것은 `prepare-run-dir.py`(폴더 · .gitignore)와 orchestrator 펜스 · `assemble-audit-data.py --out` · `render-audit-report.py --out`. 읽는 것은 `validate-audit-data.py --artifacts … --report …`. `audit-workflow.js` 는 이 폴더 경로를 쓰지 않는다(파일 안 `.claude` 일치는 감사 대상 설명문뿐 — grep). 지우는 스크립트는 없다: 「중간 abort … 디렉토리를 지우지 않고」(111행), 무효 때도 「실행 디렉토리와 산출을 지우지 않고」(283행). 성격은 300행: 「리포트는 한 번 읽는 작업 산출물이다 — 실행 디렉토리는 git-ignore 되고 커밋하지 않는다」 — 사람이 열어 보는 기록(`audit.md`)이고 감사를 다시 돌리면 `-2` 폴더가 새로 생길 뿐 같은 내용이 복원되지는 않는다."
    touches: []
    decides: [OQ32]
  - id: RC25
    path: "plugins/plugin-audit/scripts/prepare-run-dir.py"
    anchor: "parent = args.repo_root.resolve() / \".claude\" / \"plugin-audit\""
    line: 69
    claim: "실행 폴더의 자리는 git 으로 도출하지 않는다 — `--repo-root`(기본 `.`, skill 은 `--repo-root .` 로 부른다)를 resolve 한 뒤 `.claude/plugin-audit` 을 붙이고 `os.mkdir` 로 만든다. 링크 검사 · 무시 탐침 · 레포 안 검사가 없다(무시는 폴더 안 `.gitignore` 가 스스로 진다). 이 스크립트에는 실행 폴더가 레포 트리 안이어야 도는 이유가 없다 — 넘겨받은 경로 아래면 어디든 만든다. 하류 스크립트는 `$RUN_DIR` 절대경로를 인자로 받는다."
    touches: []
    decides: [OQ32]
  - id: RC26
    path: "plugins/plugin-audit/scripts/audit-sandbox.sh"
    anchor: "create-sandbox"
    line: 29
    claim: "`worktrees/` 는 자체 테스트 격리용 일회용 git worktree 다 — `<show-toplevel>/.claude/plugin-audit/worktrees/rt-<id 앞 8자>`, `git worktree add --detach … HEAD` 뒤 추적 · 무시 안 된 파일을 덮어 복사하고 기준 커밋 B 를 봉인한다. id 는 `prepare-run-dir.py` 가 낸 실행 키의 SHA-256 앞 8 hex 다. 같은 이름이 있으면 지우고 다시 만든다(52–56행). 부르는 것은 `run-own-tests.sh`(33행 create, 134행 remove). 레포 안 자리라서 생긴 코드: 복사 루프가 `.claude/plugin-audit/worktrees/*` 를 건너뛴다(72행 「never copy a sandbox into itself」) — 덮어 복사 대상이 `ls-files --others --exclude-standard` 라 그 자리가 무시돼 있지 않을 때를 막는다. `remove` 는 대상 실경로가 `<top>/.claude/plugin-audit/worktrees/` 아래일 때만 지운다(454–465행). 변이 감지 스냅숏 `qg-mutation-snapshot` 은 상태 폴더가 아니라 worktree 별 gitdir 에 둔다(105–112행: 「so `git worktree remove` auto-cleans it」). create 쪽에는 qg 와 달리 parent 가 레포 밖으로 풀리는지 재는 검사가 없다."
    touches: []
    decides: [OQ32]

  # ── 공통: 무시 규칙 ──────────────────────────────────────────────────────
  - id: RC27
    path: ".gitignore"
    anchor: "plugin state dirs (.claude/<plugin>/…) at any depth — including plugins/**/.claude/."
    line: 217
    claim: "이 레포의 무시 규칙은 `.claude/` 를 깊이 무관하게 무시하고 루트 `/.claude/` 에서는 `/.claude/agents/` 만 되살린다(214–220행). 플러그인마다 무시를 지는 방식이 다르다 — spec-distill 은 상태 루트에 자기 `.gitignore` 를 두고 무시 탐침이 실패하면 멈춘다(RC1), plugin-audit 은 실행 폴더마다 `.gitignore` 를 둔다(RC25 — `worktrees/` 에는 두지 않는다), quality-gates 는 자기 `.gitignore` 를 쓰지 않고 대상 레포가 무시하지 않는 경우를 봉인 · 리뷰 diff 코드로 받는다(RC23)."
    touches: []
    decides: [OQ32]

unanswered: "레포가 답하지 못한 것 — (1) `baseline-cache/` 의 파일 단위 내용: 생산자가 지워져 구현으로 확인할 수 없다(테스트 fixture 의 `<!-- qg-baseline-cache:v1 -->` 한 줄과 CHANGELOG 서술만 남았다). (2) 「그 자리가 레포 트리 안이어야만 돈다」 는 적극적 근거는 어느 플러그인에도 없다 — 있는 것은 지금 자리를 전제로 한 검사 · 방어(본 체크아웃 밖 거부 · `.claude/<ns>` 꼴 고정 · `${ROOT%/.claude/spec-distill}` 접미 자르기 · worktree 이름공간 가드 · 봉인 제외 pathspec)이고, git worktree 가 레포 안 경로를 요구한다는 서술이나 검사는 찾지 못했다. (3) 기계 상태 폴더와 plugin-audit 실행 폴더를 지우는 스크립트는 찾지 못했다(부재 확인은 읽은 파일 범위 안). 덜 본 자리 — `control_plane.py` 는 기계 상태를 읽는 896–950행만, `audit-workflow.js` 는 grep 만, `docreview_state.py` 는 원장 I/O · 경로 도출 · init 만, `e2e-state.sh` · `references/differential-test.md` · `roadmap_status.py` 는 열지 않았다."
```

읽은 주요 파일(절대경로):
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/state_path.py`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/docreview_state.py`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/ledger_sweep.py`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/ledger_marker.py`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/gc_common.py`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/conductor_state.py`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/conductor_ledger.py`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/merge_check.py`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/suite_lock.py`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/control_plane.py`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/repo_defaults.py`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/docreview/scripts/nofollow_write.py`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/skills/request-framing/SKILL.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/skills/spec-review/SKILL.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/references/roadmap-ontology.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/references/conducting.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/scripts/setup-qg.sh`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/scripts/qg-gc.py`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/scripts/qg-worktree.sh`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/scripts/seal-worktree.sh`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/scripts/review-diff.sh`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/skills/quality-pipeline/SKILL.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/README.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/plugin-audit/scripts/prepare-run-dir.py`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/plugin-audit/scripts/audit-sandbox.sh`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/plugin-audit/scripts/run-own-tests.sh`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/plugin-audit/skills/plugin-audit/SKILL.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/.gitignore`

연결 메모: `decides` 는 전부 OQ32 이고 RC12 만 OQ28 을 함께 달았다(지휘자 상태의 열쇠가 로드맵 폴더 이름이라 로드맵 없는 일의 자리가 없다는 점). OQ31(머지 순서)에 닿는 새 주장은 찾지 못해 달지 않았다.
~~~~

## R10

### 지금 이해
경로 (a). 포화 판정 1 이 짚은 빈 곳 넷을 조사했다(조사 14 · 15). 사용자에게 돌아갈 새 질문은 없고 설계로 넘길 열린 질문 하나(OQ36)가 늘었다. 판정자를 다시 부를 차례다.
조사 호출 9/60 · 이 라운드 본체 직접 1
줄인 사실 6개

줄인 사실 전문:
- 어느 플러그인에도 「상태가 레포 트리 안이어야만 돈다」 는 적극적 근거는 없다. 있는 것은 지금 자리를 전제로 한 검사와 방어다 — 본 체크아웃 밖이면 거부(spec-distill 상태 루트) · `.claude/<이름공간>` 꼴 고정(정리) · skill 펜스가 경로 끝에서 `/.claude/spec-distill` 을 잘라 레포 루트를 얻는 것 · 작업 사본 자리가 레포 밖이면 만들지 않는 가드(quality-gates)(RC158 · RC159 · RC160 · RC179).
- `baseline-cache/` 는 지금 코드가 쓰지도 읽지도 지우지도 않는 옛 잔재다(RC178).
- 비교용 작업 사본 셋(quality-gates 의 차등 테스트 축 · plugin-audit 의 자체 테스트 격리 · spec-distill 의 스위트 대조 사본)은 모두 실행마다 새로 만드는 일회용 작업 사본이다(RC173 · RC179 · RC183).
- 지휘 기계 상태에서 다시 만들 수 없다고 문서가 적는 것은 둘이다 — 에픽 PR 번호 기록과 아직 커밋하지 못한 쌓인 기록(RC171).
- 문서 리뷰 원장은 지우면 라운드 · 재리뷰 횟수 · 지적 이력을 잃지만, 사용자 결정의 사람이 볼 사본은 추적되는 기록 문서 쪽에 있다(RC163 · RC164).
- plugin-audit 실행 폴더는 지우는 스크립트가 없고 리포트가 사람이 여는 기록이다. quality-gates 세션 폴더의 결과 파일은 사람이 볼 수 있지만 다음 실행이나 24시간 뒤 정리에 사라진다(RC175 · RC181).

- 대체됨: R8 보고의 「품질 게이트의 기준선 캐시 — 다시 만들 수 있다 — 공식 데이터 폴더 아래 프로젝트별 자리」 → 그 폴더는 지금 코드가 쓰지 않는 옛 잔재라 옮길 대상이 아니다 (조사 15)
- 대체됨: R8 보고의 「지휘 기계 상태 — 캐시로 줄어든 몫만 옮김」 → 에픽 PR 번호 기록과 쌓인 기록은 다시 만들 수 없어 「꼭 둬야 하는 것」 후보다 (조사 15)

- 확인 RC158 — 확인 — plugins/spec-distill/scripts/state_path.py#_check_state_root — 함수와 무시 · 추적 검사 줄은 일치, 오류 문구는 다시 읽지 않았다
- 확인 RC159 — 미확인 — plugins/spec-distill/scripts/gc_common.py#root_escapes — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC160 — 미확인 — plugins/spec-distill/skills/spec-review/SKILL.md#path-inside --root — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC161 — 미확인 — plugins/spec-distill/scripts/docreview_state.py#state_dir_for — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC162 — 미확인 — plugins/spec-distill/scripts/docreview_state.py#save_state — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC163 — 미확인 — plugins/spec-distill/scripts/docreview_state.py#RECOVER — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC164 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#「원장 자리의 수명」 — 주장과 일치(1071–1075행)
- 확인 RC165 — 미확인 — plugins/spec-distill/skills/request-framing/SKILL.md#BUNDLE= — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC166 — 미확인 — plugins/spec-distill/scripts/ledger_marker.py#MARKER — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC167 — 미확인 — plugins/spec-distill/scripts/ledger_sweep.py#sweep_ledgers — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC168 — 미확인 — shared/docreview/scripts/nofollow_write.py#「마지막 경로 성분의 링크를 따라가지 않고 파일을 쓴다.」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC169 — 미확인 — plugins/spec-distill/scripts/conductor_state.py#machine_dir — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC170 — 미확인 — plugins/spec-distill/scripts/conductor_state.py#SECTIONS — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC171 — 확인 — plugins/spec-distill/references/roadmap-ontology.md#「쌓인 기록만은 다시 만들 수 없다」 — 주장과 일치(38행 · conducting.md 82행)
- 확인 RC172 — 미확인 — plugins/spec-distill/scripts/conductor_ledger.py#disposable_kind — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC173 — 미확인 — plugins/spec-distill/scripts/merge_check.py#make_copies — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC174 — 미확인 — plugins/spec-distill/scripts/suite_lock.py#lock_path — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC175 — 미확인 — plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md#「생명주기」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC176 — 확인 — plugins/quality-gates/scripts/setup-qg.sh#「세션 폴더를 지우고 다시 만드는 줄」 — 주장과 일치(188–193행 — 상태 루트가 지금 작업 사본의 최상위)
- 확인 RC177 — 미확인 — plugins/quality-gates/scripts/qg-gc.py#_is_session_folder — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC178 — 확인 — plugins/quality-gates/README.md#「12.x 까지의 판이 남긴 기준선 캐시 폴더다」 — 주장과 일치(427행)
- 확인 RC179 — 확인 — plugins/quality-gates/scripts/qg-worktree.sh#make_detached_worktree — 주장과 일치(51–57행 — 레포 밖이면 만들지 않는 가드)
- 확인 RC180 — 미확인 — plugins/quality-gates/scripts/seal-worktree.sh#「워킹트리 쪽에서 집지 않는다」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC181 — 확인 — plugins/plugin-audit/skills/plugin-audit/SKILL.md#「실행 디렉토리」 — 300행은 일치, 파일 목록은 다시 세지 않았다
- 확인 RC182 — 미확인 — plugins/plugin-audit/scripts/prepare-run-dir.py#「parent = args.repo_root.resolve()」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC183 — 미확인 — plugins/plugin-audit/scripts/audit-sandbox.sh#create-sandbox — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC184 — 미확인 — .gitignore#「plugin state dirs」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다

- 옆 세션 메시지(R10 뒤, 2026-11-14 — 사용자 말이 아니다): 팀 파일 규약 설계문서가 승인됐다고 알려 왔다. 본체 확인 — 그 문서의 마지막 커밋 「eaff8a4f docs(spec): R1 설계문서 — spec 승인 기록」 · 870줄. 원자료 대조표는 PR #276(OPEN · docs/framing-ledger)으로 올라가 있고 머지 전이다. PR #274 는 끝맺음 절차 파일에 절을 더하며 머지 전이다(옆 세션의 말 — PR #274 의 상태는 조사 4 때 열림으로 확인).
- 대체됨: seed 「그 문서는 아직 리뷰와 승인 전이고」 → 옆 세션이 승인됐다고 알렸다(승인 사실 자체는 본체가 문서에서 확인하지 못했다 — 마지막 커밋과 줄 수만 확인) (옆 세션 메시지)
- 대체됨: seed 「그 대조표는 아직 그 세션의 임시 폴더에만 있고」 → PR #276 으로 올라가 있다(머지 전이라 기본 브랜치의 경로로는 아직 가리킬 수 없다) (옆 세션 메시지 · 본체 확인)

### 다음 결정
(새 결정 없음 — 포화 판정 2 를 부른다)

### 질문
(이 라운드는 사용자 질문 없이 판정으로 간다)

### 답
(없음)

### 조사 16 — orchestrator · R10 · 묶음 11

- 실측(이 기계 · 2026-11-14): 사용자 설정 두 파일(`~/.claude/settings.json` · `~/.claude/settings.local.json`)에 `sandbox` 키가 없고, 프로젝트 설정 파일(본 체크아웃과 이 worktree 의 `.claude/settings.json` · `.claude/settings.local.json`)은 없다. Bash 환경에 이름에 sandbox 가 든 변수는 0개다 — 조사 14 의 쓰기 실측은 샌드박스를 켜지 않은 세션의 값이다. 샌드박스를 켠 세션의 쓰기는 이번에도 재지 못했다 [→ OQ32]
- 실측(이 기계 · Claude Code 2.1.325 · 2026-11-14): `claude plugin disable [plugin]` 명령이 있고 `-s, --scope <user|project|local>`(기본은 자동 감지) · `-a, --all` 을 받는다. 사용자 설정의 `enabledPlugins` 에 devbrew 네 플러그인이 `true` 로 있다. 끈 뒤의 동작(진입 skill · 훅이 멈추는지 · 재시작이 필요한지)은 재지 않았다 — 끄면 이 인터뷰가 도는 플러그인이 꺼진다 [→ OQ32]
- 실측(2026-11-14): PR #274(`feature/interview-pr-merge`) · PR #276(`docs/framing-ledger`) 둘 다 OPEN 이고 머지 전이다. 옆 worktree 설계문서의 마지막 커밋은 eaff8a4f(「R1 설계문서 — spec 승인 기록」) · 870줄 · 워킹트리 변경 없음 [→ OQ31]

### 조사 19 — repo-researcher · R10 · 묶음 12

~~~~
조사 범위와 한계 먼저.

- 읽은 것: 옆 worktree 의 설계문서 1–871행 전부(다섯 번에 나눠 끝까지), 이 worktree 의 `roadmap.md` 1–120행 전부, 옆 worktree 의 같은 `roadmap.md` 블록 줄(브랜치 · 경로 예약 · 의존)을 대조.
- 설계문서는 이 worktree(브랜치 `feature/framing-interview-constraint-audit`)에는 없다 — `docs/superpowers/specs/2026-11-14-*` 글롭 0건. 아래 RC1–RC24 의 `path` 는 레포 상대경로지만 그 파일은 옆 worktree(브랜치 `feature/team-file-contract`)에만 있다. 절대경로: `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md`
- 나는 read-only 라 `git` · `roadmap_status.py` 를 돌리지 못했다. 머지 여부와 에픽 단계는 `.git` 의 ref · reflog 파일을 직접 읽은 것이고(RC25 · RC28), 단계는 계산값이 아니라 관찰이다.

```yaml
repo_claims:
  - id: RC1
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "§2 과제 폴더와 INTENT.md — 「과제는 에픽이거나 단순 작업(로드맵 밖 수리 · 정리)이다. 어느 쪽이든 과제 폴더 없이 도는 일은 없다.」"
    line: 128
    claim: "(옆 worktree 의 판) 단순 작업도 `roadmaps/<로드맵>/jobs/<과제>/` 폴더를 갖는다. 폴더 안은 `INTENT.md`(반드시) · `results/`(반드시) · `sources.md`(에픽만) · `design.md`(설계를 거치는 과제만) · `plan-<n>.md`(계획이 있는 과제만). INTENT.md 머리는 `kind: epic | task` 로 가르고 `branch` · `paths` 는 task 만 채운다. 단순 작업의 지시 원문 칸은 「받은 말을 이 칸에 그대로 적는다 — 그 말의 집이 여기다」(155행) — 즉 단순 작업의 원자료는 `intent/original.md` 가 아니라 그 과제의 INTENT.md 에 산다. 근거 결정은 B9 「그래서 단순 작업오 jobs에 들어가야 한다는거야」(692행)."
    touches: []
    decides: [OQ28]
  - id: RC2
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "§11 생성기 — 「`job new --roadmap <로드맵> --name <이름> --branch <브랜치> --paths <…>` 가 단순 작업의 과제 폴더를 만든다. 지시 원문은 표준 입력으로 받은 사용자 말 그대로다.」"
    line: 407
    claim: "(옆 worktree 의 판) 단순 작업 과제는 `job new` 가 만들고 `--roadmap` 인자가 필수 꼴이다 — 과제 폴더는 언제나 어떤 로드맵(팀) 폴더 아래다. §10(387행): 「단순 작업 과제(`kind: task`)는 에픽 지도 뒤에 「로드맵 밖 과제」로 따로 보인다. 에픽 지도는 고치지 않는다. `job new` 는 그 작업의 브랜치에 과제 폴더를 만들어 첫 커밋으로 둔다 — 등록만을 위한 PR 을 열지 않는다.」 단계는 「준비 → 진행 중(브랜치 있음) → 결과 받음 → PR · 머지됨」(382행). AC7 · AC14 가 이것을 수용 기준으로 둔다."
    touches: []
    decides: [OQ28]
  - id: RC3
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "미룸 표 행 — 「도는 로드맵이 없을 때 단순 작업을 어느 팀의 `jobs/` 에 둘지 | 리더가 과제를 받는 절차의 몫이다. 이 에픽의 `job new` 는 로드맵을 인자로 받기만 한다 | R2」"
    line: 665
    claim: "(옆 worktree 의 판) 로드맵이 없는 일의 자리는 이 문서가 정하지 않았다 — 「도는 로드맵이 없을 때」 어느 팀의 `jobs/` 에 둘지를 R2(지휘 절차 개편)로 미뤘다. 같은 표의 661행은 「과제 폴더 없는 작업 행을 현황에서 알리기」 를 R3 로 넘긴다. framing 없이 시작한 일에 대해서는 §11(402행)이 원자료 쪽만 적는다: 「framing audit 는 인터뷰 상태 파일의 seed 경로에서 찾고(seed 와 같은 폴더의 audit), 없으면 `--framing-audit` 로 받고, 그것도 없으면 brief 쪽 사용자 원문만 싣고 그 사실을 그 구간의 출처 줄에 적는다.」 framing 도 인터뷰도 없이 시작한 일의 결과물 자리는 따로 적은 문장이 없다(단순 작업 규칙 RC1 · RC2 만 있다)."
    touches: []
    decides: [OQ28]
  - id: RC4
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "§3 원자료 — `intent/` — 「`intent/original.md` 는 사용자가 준 것을 줄이지 않고 옮긴 한 벌이다. 생성기가 로드맵을 만들 때 채운다.」"
    line: 183
    claim: "(옆 worktree 의 판) `intent/` 에 지금 들어가는 것은 `original.md` 하나다. 채우는 주체는 생성기(`roadmap_write.py`), 때는 로드맵을 만들 때이고 분해안보다 먼저다(§11 402행 「원자료가 먼저다. `roadmap_write.py original --brief <brief>` 가 `original.md` 를 따로 만든다(분해안을 쓰기 전에 부른다)」). 내용 셋: ① 「framing 을 거친 일이면 그 audit 의 원문 절과 질문 전체 절(질문 · 선택지 · 사용자가 답한 것)을 글자 그대로 옮긴다」 ② 「인터뷰에서 나온 사용자 발화(brief 와 그 audit 의 사용자 원문 절)를 이어 붙인다」 ③ 「옮긴 구간마다 그 구간의 첫 줄에 출처 경로와 커밋을 적는다. 파일 머리에는 적지 않는다」. §1 표(114행): `intent/` | 원자료(줄이지 않음) | 쓰는 사람 생성기 | 정본 기본 브랜치. 덧붙이기만 한다(404행 「재분해 때 새 사용자 말은 끝에 붙고 앞 줄은 밀리지 않으므로」). ①의 「질문 · 선택지 · 사용자가 답한 것」 은 한 덩어리로 글자 그대로 옮긴다고만 적고, 고른 선택지 문장과 직접 쓴 말을 가르는 표시는 적지 않는다."
    touches: []
    decides: [OQ27, OQ30]
  - id: RC5
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "§3 — 「brief · audit 파일 자체를 `intent/` 로 옮기는 일은 이 설계가 하지 않는다 — 앞단 skill(framing · 인터뷰)이 쓰는 자리를 바꾸는 일이다.」"
    line: 189
    claim: "(옆 worktree 의 판) brief · audit 는 지금의 옛 자리(`interview_dir`)에 그대로 있고 `intent/original.md` 는 그 사본이다. 전문: 「이 로드맵 안에서는 R5 가 받고, 앞단을 고치는 다른 로드맵(B13)이 먼저 하면 R5 는 확인만 한다(§미룸). 그때까지 `intent/` 에는 `original.md` 하나가 있고, brief · audit 의 지금 경로는 그 파일의 출처 줄이 말한다.」 §2(177행): 「`intent/original.md` 는 앞단이 `intent/` 에 바로 쓰게 되기 전까지 audit · brief 에서 옮긴 사본이다 — 옮긴 구간이 출처와 바이트가 같은지 대조한다(AC5).」 원문 대조 표(511행)도 「brief · audit 는 아직 옛 자리다(§3)」 라고 한곳에 두지 못한 것으로 적는다. seed · 인터뷰 상태 파일의 자리와 이름은 이 문서가 새로 정하지 않는다 — 402행에서 「인터뷰 상태 파일의 seed 경로」 를 읽는 입력으로만 나온다. brief · audit 의 새 파일 이름도 정하지 않았다."
    touches: []
    decides: [OQ26, OQ27]
  - id: RC6
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "AC5 — 「`intent/original.md` 의 옮긴 구간은 출처 파일의 그 구간과 바이트가 같고, 구간마다 첫 줄에 출처 경로와 커밋이 있다.」"
    line: 575
    claim: "(옆 worktree 의 판) 원자료 사본은 출처와 바이트 동일을 수용 기준으로 건다(AC5). AC4 는 「`original.md` 는 덧붙이기만 받는다 — 앞 줄을 바꾸거나 지운 변경은 검사가 거절한다」. 같은 방식의 기존 장치로 `scripts/check_verbatim_coverage.py` 를 든다(554행). 문서 전체에 비밀값 · 가리기에 대한 문장은 없다(「비밀」 · 「secret」 검색 0건) — 바이트 동일과 덧붙이기 전용 규칙만 있고, 원자료 안의 비밀값을 어떻게 다룰지는 적지 않았다."
    touches: []
    decides: [OQ29]
  - id: RC7
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "§4 `sources.md` — 「사용자 원문 절은 싣지 않는다 — `intent/original.md` 가 정본이다. 묶음마다 seed 전문을 되풀이 싣던 것이 사라진다.」"
    line: 205
    claim: "(옆 worktree 의 판) 원자료의 정본은 `intent/original.md` 이고, 에픽 묶음이 seed 전문을 되풀이 싣던 것은 없어진다고 적는다. seed 가 그 뒤 무슨 일을 맡는지, seed 문법은 적지 않는다. seed 에 대한 나머지 문장: Context(34행) 「사용자가 framing 에서 붙여 넣은 폴더 구조와 행동양식은 seed 의 산문 → brief 의 번호 항목 → 에픽 묶음으로 가며 줄었고, R1 묶음에는 역할 이름 목록조차 없었다.」 · 인터뷰와 달라진 것(521행) 「seed — 역할 이름은 devbrew 가 쓰는 말로」 → 바꿈 · 미룸(675행) 「뒤 에픽의 묶음은 seed 산문만 싣는다. 각 에픽 설계가 대조표를 첫 입력으로 읽는다(B11 · Handoff Context)」."
    touches: []
    decides: [OQ27]
  - id: RC8
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "## 미룸 표 (헤딩) — R2 로 가는 행"
    line: 650
    claim: "(옆 worktree 의 판) 미룸 표에서 받는 곳이 R2 인 행(행 순서대로): ① 새 형식을 `create` 의 기본으로 켜기 · 보내는 글 틀을 시작 묶음으로 바꾸기 · 마지막 보고 규칙을 결과 파일로 바꾸기 ② 단계 이름의 글자 · 단계마다 읽을 것 · 단계와 역할의 대응 · 관문 다섯 칸의 칸 · 검수 두 번의 절차 ③ 도구로 막기(규칙 파일 · 다른 과제 폴더 · 자기 과제의 INTENT.md) ④ 리더가 첫 설계 제안 전에 원자료 대응표부터 만든다 · 병렬 표기를 읽고 질문 없는 일부터 띄운다 ⑤ 에픽 세션을 따로 띄우기 · 끝낸 담당자를 다시 깨우지 않기 ⑥ 분해 승인 화면에 과제마다 지시 원문 범위의 글을 보이기 · 분해 전에 `original` 을 부르기(이유: 「인터뷰 끝맺음 절차 파일은 이 에픽의 예약 밖이고, 새 형식을 켤 때 함께 바꿔야 한다」) ⑦ 도는 로드맵이 없을 때 단순 작업을 어느 팀의 `jobs/` 에 둘지 ⑧ 규칙 줄을 조건으로 골라 싣기 · 묶음 예산 ⑨ 스크립트 · 다른 모델(codex) 다루기를 한곳으로 ⑩ 리뷰어 프로필에 과제 파일 모드 넣기 · 표시 없는 원문 변형을 지적하게 하기 ⑪ 구현 중 리뷰에 REVIEW.md 잇기 ⑫ 검수자의 답 전문을 리더 손을 거치지 않고 남기기 · superpowers 리뷰 두 번과 먼저 견주기 ⑬ 원자료 대조표의 R2 몫 넘김 목록 ⑭ 어느 에픽 범위에도 없던 원자료 항목 — 대장은 상주 하나 · 등록만 하고 직접 만들지 않는다 · 마지막 판정은 대장."
    touches: []
    decides: [OQ28, OQ31]
  - id: RC9
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "## 미룸 표 (헤딩) — R3 · R4 · R5 · #277 로 가는 행"
    line: 659
    claim: "(옆 worktree 의 판) 받는 곳 R3: 같은 팀 안 세션 메시지 / 리더 상태 브랜치 만들기 · 대기 줄 파일의 꼴 · 「리더가 쓰는 파일을 읽을 ref」 를 그 브랜치로 바꾸기 · 기본 브랜치로 올리는 주기 / 과제 폴더 없는 작업 행을 현황에서 알리기(이유: 「작업 표는 기계 상태에 있고 그 파일은 R3 가 예약했다」) / `STATUS.md` · `inbox/` 의 내용과 계약 / 규칙을 읽은 커밋과 공통 문서를 읽은 커밋이 갈릴 때 결과 파일 머리에 칸 더하기 / 원자료 대조표의 R3 몫. 받는 곳 R4: mod 가 과제 폴더 · 결과 파일 · 진행 숫자 · 「묶음 낡음」 을 보이기 / 원자료 대조표의 R4 몫 / 「멈추면 세션 밖으로 알린다(메일)」. 받는 곳 R5: 옛 묶음 · 설계문서 지휘 기록 · 도는 로드맵을 새 형식으로 옮기기 · devbrew 의 로드맵 폴더를 `roadmaps/` 로 옮기기 / brief · audit 를 `intent/` 에 바로 쓰기 · `source_interview` 키 이름 / 원자료 대조표의 R5 몫. 받는 곳 #277(GitHub 이슈): quality-gates 가 REVIEW.md 를 검수 기준으로 읽게 하기. 표의 「받는 곳」 칸에 「다른 로드맵」 을 적은 행은 없다 — 앞단 로드맵은 R5 행의 이유 칸에만 나온다(RC10)."
    touches: []
    decides: [OQ31]
  - id: RC10
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "미룸 표 행 — 「brief · audit 를 `intent/` 에 바로 쓰기 · `source_interview` 키 이름 | 앞단 skill(framing · 인터뷰)의 쓸 자리와 이름을 바꾸는 일이다. 앞단을 고치는 다른 로드맵(B13)이 먼저 하면 R5 는 옮길 때 확인만 한다 | R5」"
    line: 674
    claim: "(옆 worktree 의 판) 앞단 산출물의 쓸 자리(brief · audit → `intent/`)와 설계문서 머리 키 `source_interview` 의 이름은 받는 곳이 R5 이되, 「앞단을 고치는 다른 로드맵(B13)」 이 먼저 하면 R5 는 확인만 한다는 조건부 넘김이다. §12(412행)도 같은 키에 대해 「설계문서 머리 `source_interview` 가 그 경로와 같아야 한다(키 이름은 이름 바꾸기 로드맵이 정할 때까지 그대로 둔다)」 라고 적는다. 이 문서 자신의 frontmatter 도 `source_interview: docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R1.md` 를 쓴다(5행). 리뷰 2라운드의 참고 지적 6af1a927#r2.1(855행)은 「brief · audit 를 `intent/` 에 바로 쓰게 바꾸는 일을 누가 받는지가 자리마다 다르다 — 미룸 표는 R5, 원자료 절과 Handoff Context 는 이름 바꾸기 로드맵이다」 를 남겼고, 지금 판의 §3 문장은 둘을 「R5 가 받고 … 먼저 하면 확인만」 으로 묶어 적는다."
    touches: []
    decides: [OQ26, OQ31]
  - id: RC11
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "Non-goals — 「앞단(framing · 인터뷰)의 이름 바꾸기(skill 호출 이름 · 설정 키 · 머리 키) — 다른 로드맵으로 넘겼다(§결정 기록 B13). 어느 단계를 무엇이라 부를지는 그 로드맵이 정한다(B18).」"
    line: 51
    claim: "(옆 worktree 의 판) 앞단의 이름 바꾸기 — skill 호출 이름 · 설정 키 · 머리 키 셋을 괄호로 명시 — 를 Non-goal 로 두고 다른 로드맵에 넘겼으며, 어느 단계를 무엇이라 부를지도 그 로드맵 몫이라고 적는다. 문서 안에 `request-framing` · 「컨텍스트 쌓기」 라는 호출 이름 후보나 새 이름 제안은 없다(`request-framing` 리터럴 0건, `pm-interview` 는 798행의 `finishing.md` 경로 안에서 한 번)."
    touches: []
    decides: [OQ25, OQ26]
  - id: RC12
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "결정 기록 B13 — 「의도 싱크로 바꾸고 따로 에픽으로 두자」 · 「… 의도 싱크 이름 바꾸기 에픽을 하는거는 다른 로드맵에 넘길 수 있을까 지금 framing 시작한 클로드 세션 하나 있거든」 · 「맞아 devbrew-7b 로 보내줘」"
    line: 696
    claim: "(옆 worktree 의 판) B13(2026-11-14, 사용자 원문 인용)이 앞단 이름 바꾸기를 다른 로드맵으로 보낸 결정의 출처다. 같은 줄에 「QUALITY_GATES.md 이거는 리뷰 결과를 채우는 템플릿이었구나R2에서 고민하자」 도 있다. Handoff Context(809행)가 받는 쪽을 못 박는다: 「받은 쪽은 framing 을 하던 다른 세션이고 그 브랜치는 `feature/framing-interview-constraint-audit` 다 — 결정 기록의 「devbrew-7b」 는 그 세션의 이름이다.」 — 즉 받는 브랜치가 이 조사가 도는 worktree 의 브랜치다."
    touches: []
    decides: [OQ25, OQ31]
  - id: RC13
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "결정 기록 B18 — 「외부 내부 조사를 담당하는거도 그쪽 역할인데 사실 의도 싱크는 framing에서 주 역할이고 interview는 컨텍스트 쌓기와 로드맵 잡는게 주 역할이야」"
    line: 723
    claim: "(옆 worktree 의 판) B18(2026-11-14, 사용자): 「앞단 두 단계의 역할 — 의도 싱크는 framing 의 주 역할이고 인터뷰는 맥락 쌓기(내부 · 외부 조사)와 로드맵 잡기가 주 역할이다. 이 설계는 「인터뷰」 를 「의도 싱크」 로 바꿔 부르지 않는다」. Handoff Context(809행)가 같은 것을 되적는다: 「의도 싱크는 framing 의 주 역할이고, 인터뷰는 컨텍스트 쌓기(내부 · 외부 조사)와 로드맵 잡기가 주 역할이다(B18). 어느 단계를 무엇이라 부를지는 그 로드맵이 정한다.」 B13 의 「의도 싱크로 바꾸고」 와 B18 은 같은 날의 두 결정이고, B18 이 뒤에 적혀 「인터뷰 = 의도 싱크」 등치를 거둔다 — 둘 다 문서에 남아 있다."
    touches: []
    decides: [OQ25]
  - id: RC14
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "§1 팀 폴더 나무 — 「intent/                      원자료 — 앞단(framing · 인터뷰)에서 온 사용자 말」"
    line: 98
    claim: "(옆 worktree 의 판) 앞단에 대한 나머지 문장(위 RC5 · RC10–RC13 밖): §1 나무 주석(98행, 앵커) · Context(34행) 「그 빈자리를 설계가 지어낸 이름으로 채웠고 사용자가 「내 의도가 interview지나면서 의역된거 같아서 그래」 라고 짚었다. 과제 파일은 원자료를 글자 그대로 싣고, 설계는 원자료 전체를 기준으로 대조해야 한다.」 · B11(694행) 「내가 framing에서 이야기한거 행동양식들이나 의도들 있자나 모두, 뒤의 R에서도 잊으면 안돼」 · B4(687행) 「인터뷰의 파일 형식 문제인지 내 의도가 희석되네」 · 상류 연계(564행) 「받는 곳. 분해 승인(인터뷰 끝맺음)이 `roadmap_write.py create` 를 부른다.」 · §11(403행) 「그 화면을 분해 승인 질문에 끼우는 일은 인터뷰 끝맺음 절차의 몫이라 새 형식을 켤 때 함께 한다(§미룸).」 · Handoff Context(807–808행) 원자료는 `docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.audit.md` 의 원문 절과 질문 전체 절, framing 원자료 대조표는 PR #276 이 `…/framing-ledger.md` 로 올린다(F 번호 243행). 840행의 「다른 로드맵」 은 앞단 로드맵이 아니라 「그 사이 다른 로드맵이 새 자리에서 시작하면 두 자리 읽기가 필요하다」 는 `roadmaps_dir` 옮기기의 천장 조건이다."
    touches: []
    decides: [OQ25, OQ27]
  - id: RC15
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "## Files to Modify (헤딩)"
    line: 603
    claim: "(옆 worktree 의 판) R1 이 고친다고 적은 것. 새 파일: `scripts/team_layout.py` · `team_rules.py` · `start_bundle.py` · `job_results.py` · `workflow_superpowers.py` · `references/team-files.md` · `templates/team/`. 고치는 파일(예약 안): `scripts/roadmap_write.py` · `roadmap_render.py` · `roadmap_model.py` · `roadmap_status.py` · `check_bundle_coverage.py` · `spec_review_bundle.py` · `references/epic-handoff.md`. 고치는 파일(예약 밖): 「`scripts/repo_defaults.py`(R2 예약, 설정 키 둘과 로드맵 머리말의 `layout` 허용) · `scripts/control_plane.py`(R3 예약, …) · `scripts/conductor_ledger.py`(예약 없음, …)」. 공유 파일: 「`plugin.json` · `CHANGELOG.md` · `README.md`」. 레포: 「`REVIEW.md` 와, 지금 로드맵 폴더(`roadmaps_dir`) 아래의 `HANDBOOK.md` · `{leader,designer,writer,worker}/CLAUDE.md`. `.devbrew.md` 는 만들지 않는다」. 다섯 항목 대조 — 설정 키 파일(`repo_defaults.py`): 들어 있다(예약 밖으로). CHANGELOG(`plugins/spec-distill/CHANGELOG.md`): 들어 있다(공유 파일, §14 에서 계획 셋마다 판 올림 · CHANGELOG). `finishing.md`: R1 의 Files to Modify 에 없다. 레포 맨 위 `CLAUDE.md`: R1 목록에 없다(`{역할}/CLAUDE.md` 는 새 역할 문서이지 레포 CLAUDE.md 가 아니다). 상태 자리 스크립트 `state_path.py`: R1 목록에 없다."
    touches: []
    decides: [OQ31]
  - id: RC16
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "Metadata 재분해 신호 ⑥ — 「… 인터뷰 끝맺음 절차 파일(`skills/pm-interview/references/finishing.md`)을 고치는 일인데 R2 의 경로 예약에 그 파일이 없다 — 예약에 더하거나, 그 파일을 함께 고치는 앞단 로드맵(B13)과 나눈다.」"
    line: 798
    claim: "(옆 worktree 의 판) `finishing.md` 는 R2 로 넘긴 일(분해 승인 화면에 지시 원문 범위 보이기 · 분해 전에 `original` 부르기)이 고치게 되는 파일인데 R2 의 경로 예약에 없고, 문서는 두 길을 열어 둔 채 적는다 — R2 예약에 더하거나 앞단 로드맵(B13)과 나눈다. 같은 재분해 신호의 나머지: ① R1 블록 `브랜치:` 에 계획 2 · 3 브랜치 더하기 ② R1 경로 예약에 `conductor_ledger.py` 와 새 파일들을 더하고 `repo_defaults.py`(R2 예약) · `control_plane.py`(R3 예약)를 R1 이 먼저 고친다고 적기 ③ S50 을 R2, C47 을 R3, D33 · OQ48 · OQ41 · S41 을 R2 번호 목록에 ④ 리뷰어 프로필 `references/docreview-profiles/design-doc.md` 고치기도 R2 로 넘겼는데 R2 예약에 없다 ⑤ 계획 3 이 두는 HANDBOOK.md · 역할 문서 넷은 R5 가 통째로 예약한 로드맵 폴더 아래라 「경로 예약 위반」 알림이 예상된 일. 이 신호들은 「로드맵 수정 PR 로 올린다」 고 적혀 있고, 두 worktree 의 `roadmap.md` 어느 쪽에도 아직 반영돼 있지 않다(RC26 참고)."
    touches: []
    decides: [OQ31]
  - id: RC17
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "§13 설정과 옮겨 가는 동안 — 「새 설정 키는 둘이다 — `rules_budget`(기본 8192) · `handbook_budget`(기본 16384). 단위는 UTF-8 바이트다. 레포 층에서만 받는다.」"
    line: 421
    claim: "(옆 worktree 의 판) R1 이 설정 키 파일에 더하는 것은 키 둘(`rules_budget` · `handbook_budget`)과 로드맵 머리말 `layout` 허용이다 — 「지금은 로드맵 머리말의 허용 키가 `type` · `source_brief` 뿐이라 `layout` 을 모르는 키로 거절한다(`repo_defaults.py` `ROADMAP_META_KEYS`)」. `roadmaps_dir` 기본값은 바꾸지 않는다(420행 「다른 레포의 옛 로드맵이 깨진다」); devbrew 의 `roadmaps_dir` 을 `roadmaps/` 로 바꾸는 것은 R5(B16). 424행: 「설정 해결자(`repo_defaults.py`)는 R2 가 예약한 파일이다. … R2 는 R1 뒤에 시작하므로 함께 도는 충돌은 없지만 예약 밖이라 재분해 신호로 올린다」. `interview_dir` · `specs_dir` · `plans_dir` 키는 Context(28행)와 있는 것 검토(539행)에서 지금 있는 키로만 나오고 이름을 바꾸지 않는다. 이 worktree 의 구현 대조: `plugins/spec-distill/scripts/repo_defaults.py` 38행이 실제로 `ROADMAP_META_KEYS = (\"type\", \"source_brief\")` 이고 36행 `KEYS` 에 네 폴더 키가 있다 — 문서의 서술과 맞는다."
    touches: []
    decides: [OQ26, OQ31]
  - id: RC18
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "Constraints — 「사용자에게 보이는 말은 「리더」다(지휘자 · 대장이 아니다). skill 이름 `epic-conductor` 는 이 설계가 바꾸지 않는다.」"
    line: 71
    claim: "(옆 worktree 의 판) R1 이 이름 층에서 실제로 바꾸는 것과 두는 것: 사람에게 보이는 말은 「리더」 로 바꾸되 skill 이름 `epic-conductor` 는 두고, 새 산출물 종류 글자(frontmatter `type:`)로 `job` · `job-sources` · `job-result` · `job-blocked` 를 새로 들이며(143 · 199 · 215 · 243행) 로드맵 머리말에 `layout: team` 을 더한다(§10 371행 — 없으면 옛 형식, 모르는 값이면 「모르는 형식」으로 멈춤). 옛 기록을 읽는 길은 Constraints(70행) 「이 에픽이 머지된 뒤에도 옛 형식 로드맵(지금 도는 이 로드맵 포함)의 계산 결과는 바뀌지 않는다」 와 AC13, 그리고 옮기기는 R5(Handoff 812행 「옛 형식. 지금 도는 이 로드맵은 옛 형식이고 … 새 형식으로 옮기는 것은 R5 다」)."
    touches: []
    decides: [OQ26]
  - id: RC19
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "## 지휘 기록 — 「- spec 승인 · 2026-11-14 · 「열린 지적 5개를 두고 진행 — 계획 담당자에게」」"
    line: 870
    claim: "(옆 worktree 의 판) 승인 기록은 문서 맨 끝 `## 지휘 기록` 절의 한 줄이다(앵커). 문서 안에 머지를 적은 줄은 없다. frontmatter 는 `next_phase: superpowers:writing-plans`(7행). 리뷰 이력은 결정 기록의 docreview 계수 줄 넷(746–749행, r1–r4: advice_new 8 · 9 · 6 · 5)과 Metadata(796행 「리뷰: 설계문서 점검(builder check) → `spec-distill:spec-review --bundle …/R1.md`」)에 있다. 835행: 「마지막 라운드 뒤에 반영해 리뷰를 다시 거치지 않은 수정 — 시작 묶음을 건네는 두 길과 `bundle_at` · `job_at` 검사(§9 · §5), 검수 결과 파일에 적는 것(§5), 변환기가 구현 원장에서 진행 줄과 판정 줄을 내는 것(§5 · §10).」"
    touches: []
    decides: []
  - id: RC20
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "### Deferred to plan — 「계획이 실제로 정할 것은 이 목록이다(리뷰 3 · 4라운드에서 남은 것 — 작성자 정리).」"
    line: 814
    claim: "(옆 worktree 의 판) 문서가 아직 열려 있다고 적은 것 ①: 계획으로 미룬 16항(818–833행). 요지 — 1 다시 보낸 일꾼의 읽을 것 · 시도 번호 2 과제 브랜치가 아직 없을 때의 시작 묶음 3 단순 작업 과제의 시작 묶음(원자료 줄 범위 칸을 내지 않는다) 4 단순 작업 과제를 찾으려고 훑는 브랜치 범위 5 한 번도 올리지 않은 로컬 브랜치의 알림 6 「묶음 낡음」 에 REVIEW.md 를 넣을지 7 규칙 검사를 누가 언제 돌리는지 8 규칙 파일 예산 기본값(8KB · 16KB)은 작성자 제안이고 측정 근거가 없다 9 `update` 가 목표 · 범위가 바뀐 과제를 만났을 때 10 `original` 명령의 수용 기준 — 「framing audit 를 찾는 세 길, 재분해 때 끝에만 덧붙는 것. 원자료의 세 검사(줄 범위 · 덧붙이기만 · 출처와 바이트 같음)가 어느 명령이고 언제 도는지, 덧붙이기 검사가 무엇과 견주는지」 11 계획을 나눴을 때 AC 범위 12 설계를 거치는 흐름인지 가르는 기준 13 브랜치 하나에 계획 하나 14 첫 계획만 머지된 동안 `layout: team` 다루기 15 `head` 와 받음 줄 커밋의 관계 16 막힘 신호 둘의 관계. 3 · 4 · 10 번이 단순 작업 자리와 원자료 검사에 닿는다."
    touches: []
    decides: [OQ27, OQ28]
  - id: RC21
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "§6 — 「리더의 틀에 적을 것 가운데 원자료의 「등록만 하고 직접 만들지 않는다」 는 아직 정해지지 않았다(§미룸).」"
    line: 289
    claim: "(옆 worktree 의 판) 문서가 아직 열려 있다고 적은 것 ②(Deferred to plan 밖): §6(앵커) · 미룸 679–680행의 두 행 이유 칸 「인터뷰가 정하기로 하고 정하지 않았다」(대장은 상주 하나 · 등록만 하고 직접 만들지 않는다 · 마지막 판정은 대장 → R2 / 멈추면 세션 밖으로 알린다(메일) → R4) · Handoff(811행) 「계획 2 · 3 의 브랜치는 로드맵 블록에 아직 없다」 · 지휘 기록의 「열린 지적 5개를 두고 진행」(870행 — 그 다섯이 어느 지적인지는 문서에 번호로 적혀 있지 않다) · §5(253행) 단계 이름 넷의 출처를 R2 단계표로 바꾸는 것(작성자 판단) · 「역할 폴더에서 세션을 띄우는 길을 쓸지는 … R2 의 몫」(291행). `## 열린 질문` 같은 이름의 절은 문서에 없다."
    touches: []
    decides: []
  - id: RC22
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "§15 브랜치 사이 흐름 — 「이 에픽이 하는 만큼. 리더 상태 브랜치를 만들고 올리는 일은 R3 다. … 대기 줄은 지금처럼 기계 상태에 쌓았다가 `flush` 로 옮긴다. R3 는 그 함수의 값과 대기 줄의 자리만 바꾼다.」"
    line: 452
    claim: "(옆 worktree 의 판) 상태 자리에 대해 R1 이 적은 것: 리더가 쓰는 것(RULES.md 고침 · 아직 옮기지 않은 결정 줄 · STATUS.md · 편지함)은 R3 뒤 리더 상태 브랜치에 살고, R3 전에는 대기 줄이 지금의 기계 상태에 그대로 있다. R1 은 `team_layout.py` 의 함수 하나(「리더가 쓰는 파일을 읽을 ref」, R3 전 값 `origin/HEAD`)만 둔다. Constraints(68행): 「팀 파일의 틀은 플러그인이 싣고, 대상 레포에는 없을 때만 깔며 `.claude/` 아래에는 쓰지 않는다.」 상태 자리 스크립트(`state_path.py`)를 R1 이 고친다는 문장은 없다 — 그 파일은 로드맵에서 R3 의 예약이다(RC27)."
    touches: []
    decides: [OQ31]
  - id: RC23
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "§14 계획 나누기 — 「크기가 커서 계획 셋으로 나눈다. 순서대로 머지한다.」"
    line: 428
    claim: "(옆 worktree 의 판) R1 은 PR 셋으로 나뉘어 순서대로 머지된다 — 계획 1 형식과 생성(`feature/team-file-contract`) · 계획 2 읽기(`feature/team-file-read`) · 계획 3 규칙과 시작 묶음(`feature/team-file-rules`)(브랜치 이름은 Metadata 797행). 434행: 「계획마다 따로 머지하므로 AC26 은 세 계획 모두의 기준이다 — 계획마다 `plugin.json` 판 올림 · CHANGELOG · 스크립트 락 통과가 있고」. 즉 spec-distill 의 `plugin.json` 판과 `CHANGELOG.md` 가 R1 에서만 세 번 올라간다 — 같은 플러그인을 건드리는 옆 로드맵의 PR 과 판 번호 · CHANGELOG 머리에서 만난다."
    touches: []
    decides: [OQ31]
  - id: RC24
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "상류 · 하류 연계 — 「넘기는 곳. R2 — 단계표가 시작 묶음의 `--stage` · `읽을 것` 과 결과 파일의 단계 이름 · 관문 칸을 정하고, 보내는 글 틀을 시작 묶음으로 바꾼다.」"
    line: 565
    claim: "(옆 worktree 의 판) 이 문서가 로드맵의 다른 에픽이 고친다고 적은 것(문서 본문 기준): R2 — 지휘 절차서 · 보내는 글 틀(`conductor-dispatch.md` 의 마지막 보고 문면, 548행 「그 문면을 고치는 것은 R2」) · 새 형식을 `create` 기본으로 켜기(401행) · 리뷰어 프로필 과제 파일 모드(412행 「프로필은 보안 리뷰가 붙는 페르소나 파일이다」) · `finishing.md`(RC16). R3 — 리더 상태 브랜치 · `STATUS.md` · `inbox/` · 대기 줄의 자리. R4 — 현황이 과제 폴더와 결과 파일을 읽는다. R5 — 옛 묶음 · 설계문서 지휘 기록 이전, devbrew `roadmaps_dir` 을 `roadmaps/` 로(설정 한 줄 + 폴더 옮기기, 420행), brief · audit 의 `intent/` 이전(조건부, RC10)."
    touches: []
    decides: [OQ31]
  - id: RC25
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md"
    anchor: "「상태 칸은 없다 — 단계는 spec-distill 의 `scripts/roadmap_status.py` 가 git 에서 계산한다.」"
    line: 8
    claim: "이 worktree 의 `roadmap.md` 에는 에픽 단계(준비 · 진행 · 끝남)가 적혀 있지 않다 — 단계는 파일이 아니라 `roadmap_status.py` 가 git 에서 계산한다고 적혀 있고, `## 결정 기록` 절(92–94행)에는 줄 형식 설명만 있고 결정 · 머지 줄이 하나도 없다. `## 재분해 이력` 은 「2026-11-14 · 처음 로드맵 — 「승인 (권장)」」 하나뿐이다. 나는 그 스크립트를 돌리지 못했다. 대신 `.git` ref 를 직접 읽은 관찰: `origin/main` 의 마지막 fetch 값은 8b7ddf4d(reflog 마지막 줄, 설계문서 첫 커밋보다 앞 시각) · P1 브랜치 `feature/token-baseline` 은 origin 에 push 됨(두 번) · R1 브랜치 `feature/team-file-contract` 는 로컬 ref eaff8a4f 로만 있고 origin 추적 ref 가 없다 · R2–R5 브랜치(`feature/conductor-stage-table` · `-state-branch` · `-status-mod` · `-migration`)는 로컬 · origin ref 어디에도 없다 · `token-baseline.md` · `framing-ledger.md` 는 두 worktree 의 로드맵 폴더에 없다(폴더에는 P1.md · R1–R5.md · roadmap.md 뿐). 이 관찰로는 P1 · R1 은 브랜치가 있는 진행 쪽, R2–R5 는 시작 전으로 보이나, 마지막 fetch 뒤의 원격 머지는 로컬에서 알 수 없다."
    touches: []
    decides: [OQ31]
  - id: RC26
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md"
    anchor: "### R1 — 팀 파일 규약 — 「- 경로 예약: plugins/spec-distill/scripts/roadmap_write.py, …roadmap_render.py, …roadmap_model.py, …roadmap_status.py, …check_bundle_coverage.py, …spec_review_bundle.py, plugins/spec-distill/references/epic-handoff.md」"
    line: 32
    claim: "P1 — 브랜치 `feature/token-baseline`, 의존 없음, 경로 예약 `docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/token-baseline.md`(산출물도 같은 파일), 흐름 조사, R1 과 병렬. R1 — 브랜치 `feature/team-file-contract` 하나만 적혀 있음, 의존 없음, 경로 예약은 앵커의 일곱 파일, 크기 큼, P1 과 병렬. 설계문서가 재분해 신호로 올린다고 한 것(계획 2 · 3 브랜치 · `conductor_ledger.py` 와 새 파일 예약)은 이 worktree 와 옆 worktree 의 `roadmap.md` 양쪽 모두에 아직 없다 — 두 사본의 블록 줄(브랜치 · 경로 예약 · 의존)이 같은 행 번호에 같은 글자다."
    touches: []
    decides: [OQ31]
  - id: RC27
    path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md"
    anchor: "### R2 — 지휘 절차 개편 — 「- 경로 예약: plugins/spec-distill/references/conducting.md, plugins/spec-distill/references/conductor-dispatch.md, plugins/spec-distill/skills/epic-conductor/SKILL.md, plugins/spec-distill/scripts/repo_defaults.py, docs/philosophy/devbrew-harness-philosophy.md, CLAUDE.md」"
    line: 44
    claim: "R2 — 브랜치 `feature/conductor-stage-table`, 의존 R1, 크기 큼, R3 와 병렬 가능, 경로 예약에 설정 키 파일 `repo_defaults.py` · 철학 문서 · 레포 맨 위 `CLAUDE.md` 가 들어 있다(범위 「P8 · CLAUDE.md 개정」). `finishing.md` 는 R2 예약에 없다. R3 — 브랜치 `feature/conductor-state-branch`, 의존 R1, 경로 예약 `plugins/spec-distill/scripts/conductor_state.py` · `control_plane.py` · `state_path.py`(상태 자리 스크립트) · `docs/git-workflow/branch-strategy.md` · `plugins/project-init/hooks/post-tool-use.py`(56행). R4 — 브랜치 `feature/conductor-status-mod`, 의존 R3 · P1, 경로 예약 `plugins/spec-distill/README.md` · `plugins/spec-distill/dependencies.md`(68행). R5 — 브랜치 `feature/conductor-migration`, 의존 R1 · R2 · R3 · R4, 경로 예약 `docs/superpowers/specs/` · `docs/superpowers/roadmaps/` · `plugins/spec-distill/CHANGELOG.md`(79행) — 설계문서 · 로드맵 폴더 두 개를 통째로, CHANGELOG 를 파일로 예약한다. 어느 에픽의 예약에도 `skills/pm-interview/` · `skills/request-framing/` 아래 파일, `docs/superpowers/interview/` 는 없다. 예약에 적힌 파일들은 이 worktree 에 실재한다(`finishing.md` · `repo_defaults.py` · `state_path.py` · `control_plane.py` · `conductor_state.py` · `conductor_ledger.py` · `CHANGELOG.md` · `references/docreview-profiles/design-doc.md` 글롭 확인)."
    touches: []
    decides: [OQ31]
  - id: RC28
    path: "docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
    anchor: "있는 것 검토 — 「설계 전에 지금 코드에서 확인했다(2026-11-14, `origin/main` 8b7ddf4d).」"
    line: 535
    claim: "(옆 worktree 의 판) 머지 여부 — 문서 밖 관찰. 설계문서는 브랜치 `feature/team-file-contract` 에 커밋 10개로 있다(`.git/logs/refs/heads/feature/team-file-contract`: 8b7ddf4d 에서 갈라 「docs(spec): R1 팀 파일 규약 설계문서」 → … → 리뷰 1–4라운드 반영 → 「계획이 정할 것 목록」 → 마지막 「docs(spec): R1 설계문서 — spec 승인 기록」, 끝 eaff8a4f). 열 커밋 모두 `docs(spec)` 이고 구현 커밋은 없다. 그 브랜치의 origin 추적 ref 와 reflog 는 없다(push 흔적 없음). 로컬이 아는 `origin/main` 은 문서의 기준과 같은 8b7ddf4d 이고 이 worktree 의 base 도 같다 — 설계문서는 이 worktree 에 없다. 옆 worktree 의 `docs/superpowers/plans/` 에 2026-11-14 계획 파일은 없다. 문서가 든 PR 번호는 #275(P1 기준선) · #276(`framing-ledger.md`, 브랜치 `docs/framing-ledger` — origin 에 push 된 ref 있음) · 이슈 #277 이고, R1 설계문서 자신의 PR 번호는 문서에 없다."
    touches: []
    decides: [OQ31]
unanswered: "레포가 답하지 못한 것 — (a) 에픽 단계의 계산값(`roadmap_status.py` 를 돌리지 못했고 roadmap.md 에는 단계 칸이 없다) (b) 마지막 fetch(8b7ddf4d) 뒤 원격에서 #275 · #276 · R1 이 머지됐는지 (c) 설계문서는 seed 가 맡을 일 · seed 문법 · 인터뷰 상태 파일과 brief · audit 의 새 이름 · 비밀값 가리기 · 고른 선택지와 직접 쓴 말의 구분 · 로드맵이 아예 없는 일의 자리(R2 로 미룸)를 정하지 않았다 (d) 지휘 기록의 「열린 지적 5개」 가 어느 다섯인지 문서에 적혀 있지 않다."
```

짚어 둘 것 셋.

1. **주장끼리의 긴장(둘 다 냈다).** B13 의 「의도 싱크로 바꾸고 따로 에픽으로 두자」(RC12)와 B18 의 「이 설계는 「인터뷰」 를 「의도 싱크」 로 바꿔 부르지 않는다」(RC13)가 같은 문서에 함께 남아 있다. 문서는 B18 을 뒤에 적고 Non-goals · Handoff Context 에서 B18 쪽 문장을 쓴다.
2. **`finishing.md` 의 주인이 열려 있다(RC16).** R1 은 고치지 않고 R2 로 넘겼는데 R2 예약에 없으며, 문서 자신이 「예약에 더하거나 … 앞단 로드맵(B13)과 나눈다」 로 두 길을 남겼다. 로드맵 두 사본 어디에도 아직 반영되지 않았다.
3. **OQ29 · OQ30 연결은 약하다.** RC6(바이트 동일 · 덧붙이기 전용)과 RC4(「질문 · 선택지 · 사용자가 답한 것」을 한 덩어리로 옮김)는 그 결정에 제약으로 닿을 뿐, 문서가 그 질문을 다룬 것은 아니다. V1 에서 연결을 떼어도 된다.

관련 파일(절대경로):
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/repo_defaults.py`
- `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/skills/pm-interview/references/finishing.md`
- `/Users/jeonghokim/Downloads/devbrew/.git/logs/refs/heads/feature/team-file-contract`
- `/Users/jeonghokim/Downloads/devbrew/.git/logs/refs/remotes/origin/main`
~~~~

### 조사 18 — repo-researcher · R10 · 묶음 12

~~~~
레포 루트(절대): /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit
아래 `path` 는 계약대로 레포 상대경로다. 읽기 전용이라 락을 돌리지 않았다 — 「같다」는 내가 Read 로 대조한 결과이고, 락이 지금 GREEN 인지는 재지 않았다.

## 한눈 분류 (가 링크 · 나 글자 사본 · 다 플러그인 안에 없음)

| 정본 | 꼴 | 플러그인 안 자리 |
|---|---|---|
| `shared/gc/gc_common.py` | 나 | `plugins/quality-gates/scripts/` · `plugins/spec-distill/scripts/` (2) |
| `shared/killswitch/kill_switch_active.py` | 나 | `plugins/project-init/scripts/` · `plugins/quality-gates/scripts/` · `plugins/spec-distill/scripts/` (3) |
| `shared/python/devbrew-python.sh` | 나 | `plugins/project-init/scripts/` 하나뿐 |
| `shared/style/plain-language.md` | 나(본문에 끼운 블록) | `plugins/*/skills/*/SKILL.md` 10개 전부. `plugins/*/commands/*.md` 는 0개 |
| `shared/tests/**` | 다 | 같은 이름 파일 없음. 플러그인 테스트가 정본을 직접 source |
| `shared/README.md` | 다 | — |
| `tools/adjudication` · `tools/plain-language` · `tools/suite` | 다 | 같은 이름 파일 없음 |

`shared/` 최상위는 `README.md` + 폴더 11개(adjudication · codex · deps · docreview · entry · gc · killswitch · python · style · test-selection · tests)다. 질문이 든 것 밖의 폴더는 없다.

```yaml
repo_claims:
  - id: RC1
    path: "plugins/spec-distill/scripts/gc_common.py"
    anchor: "# copy-of: shared/gc/gc_common.py"
    line: 1
    claim: "shared/gc/gc_common.py 는 글자 사본으로 실린다. plugins/spec-distill/scripts/gc_common.py 와 plugins/quality-gates/scripts/gc_common.py 둘 다 1행에 copy-of 마커를 단 일반 파일이고(정본 241줄, 사본 242줄), 정본과 두 사본을 전문 Read 로 대조한 결과 마커 줄 말고는 같다. plugin-audit · project-init 에는 이 파일이 없다."
    touches: []
    decides: [OQ36]

  - id: RC2
    path: "plugins/project-init/scripts/kill_switch_active.py"
    anchor: "# copy-of: shared/killswitch/kill_switch_active.py"
    line: 1
    claim: "shared/killswitch/kill_switch_active.py 는 글자 사본으로 세 플러그인(project-init · quality-gates · spec-distill)의 scripts/ 에 실린다(정본 65줄, 사본 66줄). 정본과 세 사본을 전문 Read 로 대조한 결과 마커 줄 말고는 같다. plugin-audit 에는 없다."
    touches: []
    decides: [OQ36]

  - id: RC3
    path: "plugins/project-init/scripts/devbrew-python.sh"
    anchor: "# copy-of: shared/python/devbrew-python.sh"
    line: 2
    claim: "shared/python/devbrew-python.sh 의 글자 사본은 plugins/project-init/scripts/devbrew-python.sh 하나뿐이다(정본 221줄, 사본 222줄, 전문 Read 대조 — 2행 마커 말고 같다). plugins/spec-distill/scripts/devbrew-python.sh 와 plugins/quality-gates/scripts/devbrew-python.sh 는 직접 Read 하니 파일이 없다. 훅 폴더도 plugins/project-init/hooks/ 하나뿐이고, 그 hooks.json 10행이 `/bin/sh ${CLAUDE_PLUGIN_ROOT}/scripts/devbrew-python.sh …` 로 사본을 부른다."
    touches: []
    decides: [OQ36]

  - id: RC4
    path: "shared/README.md"
    anchor: "`python/` | 훅의 Python 인터프리터 해석기 … 세 플러그인에 **물리 사본**으로 배포된다"
    line: 33
    claim: "shared/README.md 의 디렉토리 표는 python/ 이 「세 플러그인에 물리 사본」 이라고 적는다. 트리에는 사본이 project-init 하나뿐이다(RC3). 두 자리가 어긋난다 — 어느 쪽이 맞는지는 고르지 않고 둘 다 낸다."
    touches: []
    decides: []

  - id: RC5
    path: "plugins/spec-distill/skills/pm-interview/SKILL.md"
    anchor: "<!-- plain-language:begin --> … <!-- plain-language:end -->"
    line: 19
    claim: "shared/style/plain-language.md(13줄, 표시 줄 한 쌍 사이 블록)는 SKILL.md 본문에 끼운 글자 사본으로 실린다. 플러그인의 SKILL.md 10개(spec-distill 6 · quality-gates 2 · project-init 1 · plugin-audit 1) 전부에 표시 줄 한 쌍이 13줄 간격으로 있다. 넷(pm-interview · quality-pipeline · project-init · plugin-audit)은 블록 전체를 Read 로 정본과 대조해 같았고, 열 개 전부는 정본의 서로 다른 여섯 줄을 줄 전체 일치로 찾아 파일마다 6/6 이었다. plugins/*/commands/*.md 는 한 개도 없다."
    touches: []
    decides: [OQ36]

  - id: RC6
    path: "shared/tests/test_plain_language_block.sh"
    anchor: "「사람에게 쓰는 글」 블록 동일성 — 대상은 두 글롭에서 도출한다"
    line: 4
    claim: "쉬운 말 블록의 정본·사본 일치는 shared/tests/test_plain_language_block.sh 가 재고 판정 본체는 shared/tests/plain_language_block.py 의 check() 다. 대상은 `plugins/*/skills/*/SKILL.md` · `plugins/*/commands/*.md` 글롭에서 도출하고, 대상마다 표시 줄이 각각 정확히 한 번 · 블록이 H1 바로 다음 · 표시 줄 사이(포함) 바이트가 정본과 같음을 본다(`if region != canon`). 사본을 만들어 주는 동기화 스크립트는 이 두 파일에 없다."
    touches: []
    decides: [OQ36]

  - id: RC7
    path: "shared/tests/test_copy_of_contract.sh"
    anchor: "# ── 축 1b: copy-of 물리 사본이 정본과 바이트 동일"
    line: 571
    claim: "copy-of 사본의 일치는 shared/tests/test_copy_of_contract.sh 가 잰다. 축 1b: `plugins/*` · `shared/*` 의 추적+미추적 파일 중 머리 20줄 안에 copy-of 마커가 있는 것마다 가리키는 정본이 실재하고 shared/ 아래이며 `sed \"${lineno}d\" \"$f\" | diff -q - \"$target\"` 로 마커 줄만 빼고 바이트가 같아야 한다. 같은 축이 shared/ 정본과 같은 basename 의 일반 파일이 plugins/ 에 있으면 마커가 있어야 한다고 따로 묻는다(shared/tests/ · 최상위 *.md · README.md 는 정본 basename 에서 뺀다). 축 1c(720행~)는 import 로만 소비되는 shared/*.py 정본이 소비자가 있는 배포 디렉토리마다 형제 사본을 갖는지를 ∀ 로 묻는다 — 정본 docstring 은 gc_common.py · kill_switch_active.py 가 이 축 1b·1c 대상이라고 적는다. 축 1a(295행~)는 심볼릭 링크 쪽 계약이다."
    touches: []
    decides: [OQ36]

  - id: RC8
    path: "shared/tests/test_python_floor.sh"
    anchor: "── 축 B: 배포 — 물리 사본 (AC11 · C9 · C10)"
    line: 526
    claim: "devbrew-python.sh 사본은 test_python_floor.sh 축 B 가 한 번 더 잰다: 있는 사본 집합(shared/python/ 밖의 devbrew-python.sh 전부)이 hooks.json 이 해석기를 부르는 플러그인 집합과 같아야 하고(남는 사본도 빠진 사본도 RED), 사본이 심볼릭 링크면 RED(「감사기 containment 가 shared/ 로 풀려 거짓 gap 을 낸다」), 마커가 머리 20줄 안에 있고 마커 줄을 뺀 바이트가 정본과 같아야 한다."
    touches: []
    decides: [OQ36]

  - id: RC9
    path: "shared/tests/test_no_new_duplication.sh"
    anchor: "**①② 는 마커의 *존재*만 본다.** 실제 동일성은 test_copy_of_contract.sh 의 GREEN 에 기댄다"
    line: 21
    claim: "shared/tests/test_no_new_duplication.sh 는 일치를 재는 락이 아니라 새 중복을 막는 락이다 — 20줄 이상 같은 블록이 두 파일 이상에 있는데 copy-of(또는 검증된 variant-of) · 심볼릭 링크로 설명되지 않으면 RED. 사본의 실제 동일성은 test_copy_of_contract.sh 에 맡긴다고 스스로 적는다. 코퍼스는 `plugins/*` · `shared/*` 이고 tools/ 와 docs/ 는 들어 있지 않다."
    touches: []
    decides: []

  - id: RC10
    path: "plugins/quality-gates/scripts/codex_prompt_common.py"
    anchor: "`{ echo \"# copy-of: shared/codex/codex_prompt_common.py\"; cat <이 파일>; }`"
    line: 18
    claim: "사본을 만드는 길로 레포에서 찾은 것은 docstring 에 적힌 손 명령 한 줄뿐이다(마커 줄을 앞에 붙이고 정본을 cat). 정본에서 사본을 다시 만들어 주는 동기화 스크립트는 shared/ · tools/ 파일 목록과 「copy-of」 검색에서 나오지 않았다 — 사본은 사람이 고치고 락이 어긋남을 잡는 구조다."
    touches: []
    decides: [OQ36]

  - id: RC11
    path: "plugins/spec-distill/scripts/runner_common.sh"
    anchor: "# copy-of: shared/codex/runner_common.sh"
    line: 2
    claim: "「링크로 실린다」 고 받은 여섯 폴더 안에도 링크가 아니라 글자 사본으로 실리는 파일이 있다(마커를 단 일반 파일로 직접 확인): shared/codex/codex_jsonl.py → plugin-audit · quality-gates · spec-distill 의 scripts/(정본 111줄, 사본 112줄), shared/codex/codex_prompt_common.py → quality-gates · spec-distill 의 scripts/, shared/codex/runner_common.sh → quality-gates · spec-distill 의 scripts/, shared/docreview/agents/doc-critic.md · doc-critic-web.md · doc-recritic.md → plugins/spec-distill/agents/. 즉 「폴더 = 링크」 로 가르면 이 파일들이 빠진다 — 꼴은 폴더가 아니라 파일마다 다르다. 링크 43개 수는 다시 세지 않았다."
    touches: []
    decides: [OQ36]

  - id: RC12
    path: "shared/tests/assert.sh"
    anchor: "**사본이 없다.** 테스트는 리포에서만 돌고 `${CLAUDE_PLUGIN_ROOT}` 에서 도달할 필요가 없으므로"
    line: 4
    claim: "shared/tests/ 의 파일은 플러그인 안에 사본도 링크도 없다. assert.sh · abort_trigger.sh · adopter_derivation.sh · presence_corpus.sh · docreview_fixture_corpus.sh · variant_of.py · ask_recommendation.py · plain_language_block.py 와 같은 이름의 파일을 plugins/** 에서 찾으면 0건이다. plugins/*/tests/ 의 테스트가 `shared/tests/…` 경로를 직접 가리킨다(200개 넘는 파일). shared/README.md 10–11행도 같은 구분을 적는다 — 배포되는 것은 링크나 copy-of 사본, 리포에서만 도는 plugins/*/tests/ 는 직접 source."
    touches: []
    decides: [OQ36]

  - id: RC13
    path: "tools/plain-language/README.md"
    anchor: "리포 안에서만 도는 쉬운 말 출력 도구 둘이다. 플러그인에 들어가지 않는다."
    line: 3
    claim: "tools/ 의 파일 11개(adjudication 5 · plain-language 4 · suite 2)는 플러그인 안에 없다 — 같은 이름 파일을 plugins/** 에서 찾으면 0건이다. 쓰는 쪽은 리포에서만 도는 것들이다: tools/adjudication/check_*.py · cite.py 는 shared/tests/ 의 락 넷(test_adjudication_wiring · test_adjudication_consumed · test_agent_input_slots · test_dispatch_name_defined)의 `# guards:` 에 판정기로 올라 있고, tools/plain-language/token_boundary.py 는 plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh 202행이 `sys.path.insert(0,\"tools/plain-language\")` 로 import 하며, tools/suite/run-all.sh 는 머리 주석대로 로드맵 frontmatter 의 test_command 가 부른다. 플러그인 README 둘(plugin-audit 79행 · spec-distill 80행)은 tools/adjudication/check_slots.py 를 이름으로 인용만 한다."
    touches: []
    decides: [OQ36]

  - id: RC14
    path: "shared/README.md"
    anchor: "**설치본에 들어가지 않는다** — 플러그인 캐시는 `plugins/<name>/` 서브트리만 담기 때문이다"
    line: 3
    claim: "shared/README.md 는 shared/ 가 설치본에 들어가지 않는다고 적고, 배포되는 것의 기본은 상대 심볼릭 링크(설치 시점에 실제 내용으로 풀린다)이며 링크를 못 쓰는 잔여만 바이트 동일 사본 + copy-of 마커라고 적는다. 판 올림에 대한 문장은 이 파일에 없다."
    touches: []
    decides: [OQ36]

  - id: RC15
    path: "CLAUDE.md"
    anchor: "플러그인을 건드리는 모든 PR마다 bump (major = breaking, minor = 새 surface, patch = fix) — 안 그러면 cache key가 silent stale"
    claim: "CLAUDE.md 의 판 올림 규칙은 「플러그인을 건드리는 모든 PR마다 bump」 한 문장이다. shared/ 나 tools/ 의 파일이 바뀔 때 어느 플러그인을 올리는지는 CLAUDE.md 에 적혀 있지 않다. docs/plugin-authoring.md · docs/git-workflow/ · docs/philosophy/ 를 bump · SemVer · cache key 로 찾아도 shared/ · tools/ 변경과 판 올림을 잇는 문장은 없다(commit-conventions.md 의 커밋 종류↔SemVer 표뿐)."
    touches: []
    decides: [OQ36]

  - id: RC16
    path: "shared/tests/test_changelog_integrity.sh"
    anchor: "플러그인 CHANGELOG 와 `plugin.json` 사이의 **구조적 정합**을 잰다."
    line: 4
    claim: "판 올림을 기계로 강제하는 락은 찾지 못했다. 판과 닿는 락 test_changelog_integrity.sh 는 CHANGELOG ↔ plugin.json 정합(v≥1.0.0 이면 CHANGELOG 필수 · 맨 위 헤딩 = plugin.json 판 · 순감소 · 헤딩 형식 · 건너뛴 판 없음)만 재고, 어떤 파일이 바뀌었는데 판이 그대로인지는 보지 않는다. shared/** · tools/** · plugins/*/tests · hooks · scripts 를 bump · cache key 로 찾아도 shared/ · tools/ 변경과 판을 잇는 검사는 나오지 않았다."
    touches: []
    decides: [OQ36]

  - id: RC17
    path: "docs/superpowers/specs/2026-08-22-subagent-adjudication-contract-design.md"
    anchor: "`shared/` 는 플러그인이 아니라 bump 대상이 아니지만, 배포 링크를 받는 플러그인은 bump 한다."
    line: 725
    claim: "「링크로 실리는 정본이 바뀌면 그 링크를 받는 플러그인을 올린다」 는 규칙 파일이 아니라 설계문서 · 계획 · CHANGELOG 에 관행으로 적혀 있다. 같은 내용: plugins/quality-gates/CHANGELOG.md 706행 [8.2.3] 「`shared/` 로의 심볼릭 링크라 그 대상이 바뀐 이상 배포 트리 안의 코드가 바뀐 것이다(안 올리면 cache key 가 조용히 stale)」, docs/superpowers/plans/2026-09-03-adjudication-topology.md 18행 「심볼릭 링크(git mode 120000) 되어 있으므로 그것을 고치면 두 플러그인 다 bump」. 사본 쪽도 같은 식으로 다뤄졌다 — docs/superpowers/plans/2026-10-23-r9-plan1-rules-docs-cleanup.md 17행 「쉬운 말 사본을 바꾼 네 플러그인 … 모두 patch 하나」, docs/superpowers/plans/2026-09-11-spec-review-hook-removal.md 2147행 「`docreview_state.py` 는 두 플러그인에 심볼릭 링크로, `codex_prompt_common.py` 는 물리 사본으로 실리므로 quality-gates 도 patch bump」."
    touches: []
    decides: [OQ36]

  - id: RC18
    path: "docs/superpowers/plans/2026-09-03-adjudication-topology.md"
    anchor: "`shared/tests/` 다섯을 건드리므로 **두 플러그인 다** bump 한다(그 락들이 두 플러그인의 파일을 검사한다)."
    line: 3473
    claim: "설치본에 실리지 않는 공유 파일(shared/tests/ · tools/)만 바뀌었을 때 올리는지는 기록끼리 어긋난다. 올린 쪽: 이 계획 3473행, 그리고 plugins/spec-distill/CHANGELOG.md 2071행 「`shared/tests/`·`tools/adjudication/` 공유 파일이라 두 플러그인 다 bump」. 안 올린 쪽은 RC19."
    touches: []
    decides: [OQ36]

  - id: RC19
    path: "docs/superpowers/plans/2026-09-24-qg-recritic-swap-pr4a.md"
    anchor: "`shared/tests/` 에 락 하나가 느는 것은 플러그인 표면이 아니다"
    line: 186
    claim: "RC18 과 반대 방향의 기록. 이 계획은 「`shared/docreview` 와 `shared/adjudication` 은 한 바이트도 안 바뀌므로 spec-distill 은 bump 하지 않는다」 고 정하며 shared/tests/ 의 락 추가를 판 올림 이유로 치지 않는다. 같은 방향: docs/superpowers/plans/2026-09-03-adjudication-topology.md 976행 「`shared/` 만 건드렸으므로 bump 없음」(RC18 과 같은 문서 안이다), docs/superpowers/plans/2026-08-23-subagent-adjudication-contract.md 44행 · docs/superpowers/plans/2026-08-27-request-framing-phase0.md 78행 「`shared/` 는 플러그인이 아니다 — bump 대상이 아니고 설치본에 들어가지 않는다」."
    touches: []
    decides: [OQ36]

  - id: RC20
    path: "tools/suite/run-all.sh"
    anchor: "find shared/tests plugins/*/tests -name 'test_*.sh'"
    line: 27
    claim: "일치 락이 언제 도는지에 대한 두 자리. shared/README.md 21행은 두 락(test_copy_of_contract · test_no_new_duplication)이 「`/quality-gates:quality-pipeline` 의 차등 테스트가 고를 때만 돈다」 고 적는다. tools/suite/run-all.sh 는 shared/tests 와 plugins/*/tests 의 test_*.sh 를 전부 돌리며 머리 주석은 로드맵 frontmatter 의 test_command 가 이것을 부른다고 적는다. 두 락 다 `# guards: plugins/** shared/**` 를 선언한다 — tools/ 는 그 선언에 없다."
    touches: []
    decides: []
unanswered: "셋을 재지 못했다 — (1) 일반 파일인지 링크인지는 git 인덱스 모드(120000)가 아니라 Read 한 내용에 copy-of 마커가 있는가로 갈랐다(링크라면 마커 없는 정본 내용이 보인다). (2) test_copy_of_contract.sh 는 1–935행만 읽었다 — 축 1c 뒷부분과 축 2 · 3(형제 설정 codex-killswitch.conf)은 읽지 않았다. (3) 락을 돌리지 않아 지금 GREEN 인지 모른다. 그리고 「shared/ 나 tools/ 가 바뀌면 어느 플러그인을 올린다」 를 적은 규칙 파일이나 락은 레포에 없다 — 있는 것은 설계문서 · 계획 · CHANGELOG 의 관행 기록뿐이고 shared/tests · tools 에 대해서는 서로 어긋난다(RC18 · RC19)."
```

## 읽은 주요 파일(절대 경로)

- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/README.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/tests/test_copy_of_contract.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/tests/test_plain_language_block.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/tests/plain_language_block.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/tests/test_python_floor.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/tests/test_no_new_duplication.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/tests/test_changelog_integrity.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/tests/assert.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/gc/gc_common.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/killswitch/kill_switch_active.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/python/devbrew-python.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/style/plain-language.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/gc_common.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/scripts/gc_common.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/project-init/scripts/kill_switch_active.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/scripts/kill_switch_active.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/kill_switch_active.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/project-init/scripts/devbrew-python.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/project-init/hooks/hooks.json
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/scripts/codex_prompt_common.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/runner_common.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/agents/doc-critic.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/tools/plain-language/README.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/tools/suite/run-all.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/tools/adjudication/check_wiring.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/specs/2026-08-22-subagent-adjudication-contract-design.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/plans/2026-09-03-adjudication-topology.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/plans/2026-09-24-qg-recritic-swap-pr4a.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/CHANGELOG.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/CHANGELOG.md

V1 재확인 때 볼 점: RC17 · RC18 · RC19 의 줄 가운데 725 · 3473 · 186 행은 Read 로, 나머지 행(706 · 2071 · 976 · 44 · 78 · 18 · 17 · 2147)은 검색 결과에 실린 원문 줄로 확인했다.
~~~~

### 조사 17 — repo-researcher · R10 · 묶음 12

~~~~
레포 루트(절대 경로): /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit — 아래 `path` 는 모두 이 루트 기준 상대 경로다.

조사 방법: `plugins/` · `shared/` · `tools/` · 최상위 문서에서 `DEVBREW_` 전수 grep 뒤, 읽는 자리의 구현을 직접 읽었다. 링크로 배송되는 파일(`detect_codex.sh` · `entry_preflight.py` · `run_docreview_codex_reviewer.sh` · `run-test-selection.sh` · `docreview_config.py`)은 `shared/` 정본에서 읽었다. `docs/` 아래 설계문서 · 계획 · 인터뷰 기록은 질문 범위 밖이라 세지 않았다.

표기: 【끄기】 = 값 `1` 로 끄는 스위치 · 【값】 = 숫자 · 경로 · 목록을 받는 변수 · 【토큰】 = `DEVBREW_SKIP_HOOKS` 가 받는 `<plugin>:<이름>` · 【은퇴】 = 더는 아무것도 끄지 않는 이름.

```yaml
repo_claims:
  # ── 공통 장치 ─────────────────────────────────────────────────────────────
  - id: RC1
    path: "shared/killswitch/kill_switch_active.py"
    anchor: "def kill_switch_active(plugin, hook, event=\"\")"
    line: 29
    claim: "판정 정본. (a) 전역 변수 이름을 열거하지 않고 플러그인 이름에서 도출한다 — `\"DEVBREW_\" + plugin.upper().replace(\"-\", \"_\") + \"_DISABLE\"` 가 정확히 \"1\" 이면 참. (b) `DEVBREW_SKIP_HOOKS` 는 쉼표로 가르고 양끝 공백을 뗀 «전체 토큰» 으로 `<plugin>:<hook>` 또는 `<plugin>:<event>` 와 대조한다(부분 일치 없음 · event 가 빈 값이면 별칭을 만들지 않는다). 플러그인마다 `scripts/kill_switch_active.py` 물리 사본(`# copy-of:`)으로 실린다 — spec-distill · quality-gates · project-init 에 사본이 있다. 코드에서 이 함수를 부르는 자리는 다섯이다: `plugins/project-init/hooks/post-tool-use.py:609` · `plugins/spec-distill/scripts/review_entry.py:44` · `plugins/spec-distill/scripts/control_plane.py:1139` · `plugins/spec-distill/scripts/ledger_sweep.py:54-55` · `plugins/quality-gates/scripts/qg-gc.py:88`."
    touches: []
    decides: [OQ32]
  - id: RC2
    path: "shared/entry/entry_preflight.py"
    anchor: "def switch_name(plugin) / def sentinel(argv, environ, cwd)"
    line: 25
    claim: "진입 사전 검사. `DEVBREW_<PLUGIN>_DISABLE` 하나만 읽는다(값이 정확히 \"1\" 이면 `[devbrew-entry] disabled … switch=<이름>=1` 감시줄, rc 는 늘 0). `DEVBREW_SKIP_HOOKS` 는 읽지 않는다. 이 스크립트를 `!` 사전 검사 줄로 부르는 SKILL 은 여덟이다 — spec-distill 의 spec-review · pm-interview · request-framing · epic-conductor · roadmap-status, quality-gates 의 quality-pipeline · artifact-critique, plugin-audit 의 plugin-audit, project-init 의 project-init. 내부 skill `reviewing-brief` 는 사전 검사 줄이 없다(본문 산문이 `DEVBREW_SPEC_DISTILL_DISABLE=1 → 진입하지 않는다` 로 적는다, `plugins/spec-distill/skills/reviewing-brief/SKILL.md:86`)."
    touches: []
    decides: [OQ32]
  - id: RC3
    path: "shared/python/devbrew-python.sh"
    anchor: "kill_switch_active() { … eval \"_dis=\\${DEVBREW_${_up}_DISABLE-}\" / # ── 1. $DEVBREW_PYTHON (탈출구)"
    line: 62
    claim: "훅의 Python 해석기. (a) 어떤 일보다 먼저 `--plugin` · `--hook` · `--event` 인자로 `DEVBREW_<PLUGIN>_DISABLE` 와 `DEVBREW_SKIP_HOOKS` 의 `<plugin>:<hook>` · `<plugin>:<event>` 를 판정해 맞으면 exit 0. (b) 【값 · 경로】 `DEVBREW_PYTHON` — 인터프리터 경로를 받는다. 바닥(3.12) 이상이면 그것으로 exec, 아니면 무시하고 PATH 탐색으로 간다. (c) `DEVBREW_PYTHON_IGNORED` 는 입력이 아니라 이 스크립트가 «내보내는» 변수이고 주석이 「지금 읽는 훅은 없다」 고 적는다. 사본은 `plugins/project-init/scripts/devbrew-python.sh` 하나다. 공시: `README.md:48`(`$DEVBREW_PYTHON`) · `plugins/project-init/README.md:86`. `DEVBREW_PYTHON_IGNORED` 는 README 에 없고 CHANGELOG 에만 있다(`plugins/quality-gates/CHANGELOG.md:395` · `plugins/spec-distill/CHANGELOG.md:747` · `plugins/project-init/CHANGELOG.md:135`)."
    touches: []
    decides: [OQ32]
  - id: RC4
    path: "shared/codex/detect_codex.sh"
    anchor: "if [[ \"${!CODEX_KILL_SWITCH_VAR:-0}\" == \"1\" ]]; then emit_skip 'kill_switch'"
    line: 61
    claim: "codex 끄기 스위치의 읽는 자리는 이 감지기 하나다. 변수 이름은 형제 파일 `codex-killswitch.conf` 의 `CODEX_KILL_SWITCH_VAR` 에서 온다(없거나 비었거나 식별자가 아니면 fail-closed 로 codex 를 쓰지 않는다). 세 conf 의 값: `plugins/spec-distill/scripts/codex-killswitch.conf:12` = `DEVBREW_SPEC_DISTILL_DISABLE_CODEX` · `plugins/quality-gates/scripts/codex-killswitch.conf:12` = `DEVBREW_QUALITY_GATES_DISABLE_CODEX` · `plugins/plugin-audit/scripts/codex-killswitch.conf:12` = `DEVBREW_PLUGIN_AUDIT_DISABLE_CODEX`. 러너는 이 변수를 읽지 않는다 — 감지기 출력(`codex_available`)으로 러너 호출을 가르는 것은 호출자(SKILL 펜스 또는 산문)의 몫이다."
    touches: []
    decides: [OQ32]
  - id: RC5
    path: "plugins/project-init/hooks/hooks.json"
    anchor: "\"PostToolUse\" … \"matcher\": \"Bash|EnterWorktree\" … devbrew-python.sh --event PostToolUse --plugin project-init --hook post-tool-use"
    line: 4
    claim: "`plugins/*` 에서 설치되는 훅은 이것 하나다. `plugins/*/hooks/**` 글롭은 project-init 의 `hooks.json` · `post-tool-use.py` 둘만 내고, 네 플러그인의 `plugin.json` 에는 `\"hooks\"` 키가 없다. spec-distill README 도 「이 플러그인에는 훅이 없어」 라고 적는다(`plugins/spec-distill/README.md:342`). 따라서 `DEVBREW_SKIP_HOOKS` 의 살아 있는 토큰 여덟(RC6 · RC8 · RC9 · RC10 · RC22) 가운데 훅을 가리키는 것은 project-init 의 둘뿐이고 나머지 여섯은 훅이 아닌 이름 붙은 자리다."
    touches: []
    decides: [OQ32]

  # ── project-init ─────────────────────────────────────────────────────────
  - id: RC6
    path: "plugins/project-init/hooks/post-tool-use.py"
    anchor: "if kill_switch_active(\"project-init\", \"post-tool-use\", \"PostToolUse\"):"
    line: 609
    claim: "【끄기】 `DEVBREW_PROJECT_INIT_DISABLE=1` · 【토큰】 `project-init:post-tool-use` · `project-init:PostToolUse`. 읽는 자리 셋: 훅 본문(이 줄 — `{}` 를 내고 끝난다) · 해석기 `scripts/devbrew-python.sh`(인자에서 도출, 훅 본문보다 앞) · 진입 사전 검사(전역 변수만). 끄는 것: 전역 변수는 PostToolUse 훅(브랜치 이름 · 커밋 메시지 알림)과 `/project-init` 진입 skill 을 함께 끄고, 두 토큰은 훅만 끈다. 공시: `plugins/project-init/README.md:101-102` · `plugins/project-init/skills/project-init/SKILL.md:26` · `docs/git-workflow/pr-process.md:61`(과 그 템플릿 `plugins/project-init/templates/shared/pr-process.md:61`)."
    touches: []
    decides: [OQ32]

  # ── spec-distill ─────────────────────────────────────────────────────────
  - id: RC7
    path: "plugins/spec-distill/README.md"
    anchor: "### 스위치 목록 — `DEVBREW_SPEC_DISTILL_DISABLE=1` — plugin 전체 abort, state 보존"
    line: 286
    claim: "【끄기】 `DEVBREW_SPEC_DISTILL_DISABLE=1`. 기계가 읽는 자리: 진입 사전 검사(진입 skill 다섯) · `scripts/review_entry.py:44-46`(설계문서 리뷰 진입) · `scripts/control_plane.py:1137`(상태줄 · 지도) · `scripts/ledger_sweep.py:54`(원장 정리 — `kill_switch_active` 경유). 산문으로만 읽는 자리: `skills/reviewing-brief/SKILL.md:86` · `shared/docreview/references/reviewing-document.md:17`(엔진 2단계 「`DEVBREW_<HOST>_DISABLE`(전체)」). 끄는 것: 진입 skill 다섯 · 설계문서 리뷰 · 컨트롤 플레인 · 원장 정리. 공시: 이 README 절 · `CLAUDE.md:71` · `templates/roadmap-template.md:15` · `references/epic-handoff.md:3`."
    touches: []
    decides: [OQ32]
  - id: RC8
    path: "plugins/spec-distill/scripts/review_entry.py"
    anchor: "def disabled_reason() — ENTRY_TOKEN = \"spec-distill:review-entry\" / DESIGN_MODE_VAR"
    line: 42
    claim: "【토큰】 `spec-distill:review-entry` · 【끄기】 `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1`. 둘 다 `/spec-distill:spec-review` 의 설계문서 리뷰 진입을 끈다(수동 호출 포함). 소비자는 `skills/spec-review/SKILL.md` 의 `review-entry` 펜스 — JSON 계약을 검사하고 어긋나거나 rc≠0 이면 끔으로 친다(`SKILL.md:102-123`). 훅이 아니라 이름 붙은 자리다. 공시: `plugins/spec-distill/README.md:282 · 293 · 294` · `skills/spec-review/SKILL.md:133-134` · `CLAUDE.md:71`(예시로 `spec-distill:review-entry`)."
    touches: []
    decides: [OQ32]
  - id: RC9
    path: "plugins/spec-distill/scripts/control_plane.py"
    anchor: "def switch_name() — kill_switch_active(\"spec-distill\", \"statusline\")"
    line: 1136
    claim: "【토큰】 `spec-distill:statusline`. 컨트롤 플레인을 끈다 — `cmd_statusline` 은 빈 줄(`:1196-1198`), `cmd_show` 는 `꺼져 있다 — <스위치>` 한 줄, `--tasks` 면 stderr 로 내고 rc 3(`:1301-1307`). `DEVBREW_SPEC_DISTILL_DISABLE=1` 도 같은 함수에서 같은 효과다. 훅이 아니다. 공시: `plugins/spec-distill/README.md:288` · `skills/roadmap-status/SKILL.md:47`."
    touches: []
    decides: [OQ32]
  - id: RC10
    path: "plugins/spec-distill/scripts/ledger_sweep.py"
    anchor: "def disabled() / ttl = ttl_ns(\"DEVBREW_SPEC_DISTILL_TTL_HOURS\")"
    line: 53
    claim: "【토큰】 `spec-distill:session-end-cleanup` · `spec-distill:SessionEnd` · `spec-distill:spec-distill-gc` — 셋 다 리뷰 진입 때의 원장 정리(문서 없는 원장 삭제 · 옛 세션 폴더 정리 · 옛 원장 옮기기)를 끈다. 가리키던 훅은 없고(README 「설치되는 훅은 없다」), 옛 시간 기준 정리를 꺼 둔 사용자에게 삭제가 다시 켜지지 않게 이름만 계속 읽는다. 이 스크립트를 부르는 자리는 세 SKILL 의 원장 열기 펜스다(`skills/spec-review/SKILL.md:274` · `skills/reviewing-brief/SKILL.md:150` · `skills/request-framing/SKILL.md:518`). 【값 · 정수(시간)】 `DEVBREW_SPEC_DISTILL_TTL_HOURS`(기본 24) — `shared/gc/gc_common.py:46` `ttl_ns` 가 0 이하 · 비정수를 기본값으로 떨어뜨린다. 공시: `plugins/spec-distill/README.md:295-297` · `plugins/spec-distill/CHANGELOG.md:542`."
    touches: []
    decides: [OQ32]
  - id: RC11
    path: "plugins/spec-distill/scripts/review_entry.py"
    anchor: "REVIEW_TOKENS / GONE_TOKENS / AUTOREVIEW_VAR — def retired_advisories(reason)"
    line: 29
    claim: "【은퇴】 토큰 여섯과 변수 하나를 이 스크립트가 아직 «읽는다» — 끄려고가 아니라 설정돼 있으면 「더는 아무것도 끄지 않는다」 를 알리려고. 토큰: `spec-distill:Stop` · `spec-distill:review-dispatch`(리뷰를 막지 않는다 + 대체 스위치 안내) · `spec-distill:validator` · `spec-distill:PostToolUse` · `spec-distill:reminder` · `spec-distill:UserPromptSubmit`(대상 삭제). 변수: `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW`. 공시: `plugins/spec-distill/README.md:316-324`(「은퇴한 스위치」 절). 같은 절의 `DEVBREW_SPEC_DISTILL_GC_VERBOSE`(6.0.0, 진단 출력 변수였다)는 읽는 곳이 없고 진입 검사도 알리지 않는다(`README.md:324` · `CHANGELOG.md:559`)."
    touches: []
    decides: [OQ32]
  - id: RC12
    path: "plugins/spec-distill/skills/spec-review/SKILL.md"
    anchor: "<!-- codex-gate:end --> 앞 펜스 — DETECT_OUT=\"$(bash \"$SD/scripts/detect_codex.sh\")\""
    line: 428
    claim: "【끄기】 `DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1`. 감지기(RC4)가 `skip_reason: kill_switch` 로 옮기고 SKILL 의 `codex-gate` 펜스가 `codex_avail == true` 일 때만 러너를 부른다. 끄는 것: 문서 리뷰 엔진의 codex 축 하나(탐지 · 재비판은 그대로). README 는 적용 자리를 셋으로 적는다 — spec-review · reviewing-brief · request-framing(`plugins/spec-distill/README.md:289`). 공시: 그 줄과 `README.md:348` · 세 SKILL 본문 · `CHANGELOG.md:3055`."
    touches: []
    decides: [OQ32]
  - id: RC13
    path: "plugins/spec-distill/skills/request-framing/SKILL.md"
    anchor: "`DEVBREW_SPEC_DISTILL_DISABLE_RECRITIC=1` 이면 dispatch 하지 않고 7단계를 `--recritic-skipped` 로 돕니다."
    line: 725
    claim: "【끄기】 `DEVBREW_SPEC_DISTILL_DISABLE_RECRITIC=1`. 이 변수를 읽는 스크립트도 bash 펜스도 없다 — `plugins/` · `shared/` 의 실행 코드에서 이 이름은 0건이고 SKILL 산문 넷(`spec-review/SKILL.md:471` · `reviewing-brief/SKILL.md:96` · `request-framing/SKILL.md:725 · 1371`)과 `shared/docreview/references/reviewing-document.md:17` 에만 있다. 모델이 산문을 따라 `doc-recritic` dispatch 를 건너뛰고 엔진에 `--recritic-skipped` 를 넘기는 꼴이다. 끄는 것: 재비판 단계 하나. 공시: `plugins/spec-distill/README.md:290`."
    touches: []
    decides: [OQ32]
  - id: RC14
    path: "plugins/spec-distill/README.md"
    anchor: "`DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` — 이 kill switch 가 **두 자리**의 웹 접근을 끈다"
    line: 298
    claim: "【끄기 · 웹】 `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`. 기계가 읽는 자리 일곱: bash 펜스 다섯(`skills/pm-interview/SKILL.md:324`(open-researcher 를 띄우지 않음) · `:431`(coverage-mapper 에 `web_disabled`) · `skills/pm-interview/references/steelman.md:28`(steelman 생략) · `skills/reviewing-brief/SKILL.md:519`(탐지를 웹 없는 `doc-critic` 으로 지명) · `skills/request-framing/SKILL.md:342`(이름 조회 생략)) + `scripts/check_brief.py:92`(§4 sentinel 하나 완화와 advisory) + 공유 러너 `shared/docreview/scripts/run_docreview_codex_reviewer.sh:477`(codex 웹 검색 끔). 산문으로만 적힌 자리도 있다(`pm-interview/SKILL.md:482 · 535` — blind-spot-prober 의 inline premortem 전환 · landscape 생략). 설계문서 리뷰는 대상이 아니다(README 가 명시). 공시: `README.md:87 · 298-308` · 세 SKILL 의 `## kill switch` 절."
    touches: []
    decides: [OQ32]
  - id: RC15
    path: "plugins/spec-distill/skills/request-framing/SKILL.md"
    anchor: "`DEVBREW_SPEC_DISTILL_DISABLE_WORKTREE=1` 이거나 `EnterWorktree` 도구가 없으면 **묻지 않고** 현재 디렉토리에서 진행한다."
    line: 131
    claim: "【끄기】 `DEVBREW_SPEC_DISTILL_DISABLE_WORKTREE=1`. 읽는 스크립트 · 펜스가 없다 — SKILL 산문(`:131 · 205 · 1373`)과 audit 템플릿(`templates/interview-seed-audit-template.md:68`)에만 있다. 끄는 것: request-framing 진입 직후의 워크트리 질문 · 생성(audit §5 에 사유 한 줄). 공시: `plugins/spec-distill/README.md:309-311` · `CHANGELOG.md:1566 · 1663`."
    touches: []
    decides: [OQ32]
  - id: RC16
    path: "plugins/spec-distill/skills/reviewing-brief/SKILL.md"
    anchor: "`DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW=1` → 리뷰 전체 skip. record(`pipeline` / `all` / `skipped`)를 남기고 loud advisory 후 Step B 로 돌아간다"
    line: 87
    claim: "【끄기】 `DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW=1`. 읽는 스크립트 · 펜스가 없다 — 이 산문과 `skills/pm-interview/references/finishing.md:261` 에만 있다. 끄는 것: brief 리뷰 전체(엔진 라운드 · 냉독), skip record 가 Step B 게이트 질문에 표시된다. 공시: `plugins/spec-distill/README.md:312-314`."
    touches: []
    decides: [OQ32]
  - id: RC17
    path: "plugins/spec-distill/skills/pm-interview/references/saturation.md"
    anchor: "### 상한 값 — lim=\"${DEVBREW_SPEC_DISTILL_RESEARCH_LIMIT:-60}\" / sat=\"${DEVBREW_SPEC_DISTILL_SATURATION_LIMIT:-5}\""
    line: 16
    claim: "【값 · 양의 정수】 `DEVBREW_SPEC_DISTILL_RESEARCH_LIMIT`(기본 60) · `DEVBREW_SPEC_DISTILL_SATURATION_LIMIT`(기본 5). 이 reference 의 bash 펜스가 읽는다 — 양의 정수가 아니면 기본값으로 두고 한 줄로 알린다. 조사 agent 호출 상한 · 포화 판정 상한의 «시작값» 이고 state 의 `research_limit` · `saturation_limit` 에 적혀 연장마다 더해진다. SKILL 이 「상한은 끄는 스위치가 아니라 닿으면 사용자에게 묻는 자리다」 라고 적는다(`skills/pm-interview/SKILL.md:599`). 공시: `plugins/spec-distill/README.md:291-292` · `CHANGELOG.md:324 · 627`."
    touches: []
    decides: [OQ32, OQ35]
  - id: RC18
    path: "plugins/spec-distill/skills/reviewing-brief/SKILL.md"
    anchor: "if [ \"${DEVBREW_SPEC_DISTILL_SKIP_VC_ONCE:-}\" = 1 ] && [ \"$vc_rc\" -ne 0 ] && [ \"$vc_rc\" -ne 1 ]; then"
    line: 245
    claim: "【끄기 · 한 번】 `DEVBREW_SPEC_DISTILL_SKIP_VC_ONCE=1`. 사용자가 환경에 두는 스위치가 아니라, 사용자가 「검사 없이 계속」을 고른 뒤 skill 이 같은 펜스를 다시 돌릴 때 덧붙이는 변수다. 변수가 있고 «그리고» audit `## 4. 게이트 실행 기록` 에 오늘 날짜 · 같은 종료 코드의 `skipped_by_user` 줄이 있을 때만 원문 완전성 검사 하나를 건너뛴다(위반 rc 1 은 건너뛰지 않는다). 공시: `plugins/spec-distill/CHANGELOG.md:371` 과 SKILL 본문(`:261`)뿐이고 README 스위치 목록에는 없다."
    touches: []
    decides: [OQ32]
  - id: RC19
    path: "plugins/spec-distill/scripts/state_path.py"
    anchor: "def resolve_session_id(payload) — os.environ.get(\"DEVBREW_SPEC_DISTILL_SESSION_ID\") or os.environ.get(\"CLAUDE_CODE_SESSION_ID\")"
    line: 52
    claim: "【값 · 세션 id】 `DEVBREW_SPEC_DISTILL_SESSION_ID`. `CLAUDE_CODE_SESSION_ID` 보다 앞서는 override 이고 docstring 은 「test override」 라고 부른다. `skills/reviewing-brief/SKILL.md:312` 의 실패 안내가 「세션 id 미해석 — DEVBREW_SPEC_DISTILL_SESSION_ID 로 명시하라」 로 사용자에게 이 이름을 댄다. 공시: README 에는 없고 `plugins/spec-distill/CHANGELOG.md:5456 · 5466` 에만 있다."
    touches: []
    decides: [OQ32]
  - id: RC20
    path: "shared/docreview/scripts/docreview_config.py"
    anchor: "ENV = {\"detectors\": \"DEVBREW_DOCREVIEW_DETECTORS\", …} / def resolve(prof, entry, env)"
    line: 14
    claim: "【값 · 정수 넷】 `DEVBREW_DOCREVIEW_DETECTORS`(1~6, 기본 1) · `DEVBREW_DOCREVIEW_REREVIEW_CAP`(0~10, 기본 2) · `DEVBREW_DOCREVIEW_RENDER_CAP`(1~100, 기본 8) · `DEVBREW_DOCREVIEW_SUMMARY_WIDTH`(1~500, 기본 60). 플러그인 이름이 없는 공유 엔진 변수다. 순서는 기본 < 프로필 < 진입 < 환경이고, ASCII 숫자가 아니거나 범위 밖이면 `ConfigInvalid` 로 라운드를 시작하지 않는다. 환경을 넘기는 자리는 `shared/docreview/scripts/docreview_state.py:1042 · 2609`(`_cfg.resolve(prof, …, os.environ)`). 공시: `plugins/spec-distill/README.md:213-222`(「설정」 표) · `plugins/spec-distill/CHANGELOG.md:232 · 362` · `plugins/quality-gates/CHANGELOG.md:101` · `shared/docreview/references/reviewing-document.md:5`. quality-gates README 에는 이 넷이 없다."
    touches: []
    decides: [OQ32]

  # ── quality-gates ────────────────────────────────────────────────────────
  - id: RC21
    path: "plugins/quality-gates/README.md"
    anchor: "**전역 (모든 reviewer + GC 비활성화):** | `DEVBREW_QUALITY_GATES_DISABLE=1` |"
    line: 463
    claim: "【끄기】 `DEVBREW_QUALITY_GATES_DISABLE=1`. 기계가 읽는 자리 여섯: 진입 사전 검사(quality-pipeline · artifact-critique) · `scripts/setup-qg.sh:15`(exit 1) · `scripts/publish-comment.sh:35`(`skipped: kill-switch`) · `scripts/artifact_commit.sh:19`(`error: killed_by_switch`, exit 1) · `scripts/e2e-state.sh:38`(fingerprint · compare · boot 가 exit 3) · `scripts/qg-gc.py:88`(`kill_switch_active` 경유 no-op). 산문 자리: `skills/quality-pipeline/SKILL.md:84`(Preflight P1) · `skills/artifact-critique/SKILL.md:82`(E0). 끄는 것: 두 진입 skill · setup · 게시 · 산출물 비평 커밋 · e2e · GC. 공시: 이 README 표 · `README.md:37 · 487` · `docs/philosophy/devbrew-harness-philosophy.md:51`."
    touches: []
    decides: [OQ32]
  - id: RC22
    path: "plugins/quality-gates/scripts/qg-gc.py"
    anchor: "if kill_switch_active(\"quality-gates\", \"qg-gc\"): / ttl_ns(\"DEVBREW_QUALITY_GATES_TTL_HOURS\") / def _verbose()"
    line: 88
    claim: "【토큰】 `quality-gates:qg-gc` — 세션 폴더 TTL-GC 스크립트 하나만 끈다(훅이 아니다 — docstring 이 「훅이 아니지만 … 토큰으로 지목할 이름을 갖는다」). 【값 · 정수(시간)】 `DEVBREW_QUALITY_GATES_TTL_HOURS`(기본 24, 0 이하 · 비정수는 기본값). 【끄기가 아닌 진단】 `DEVBREW_QUALITY_GATES_GC_VERBOSE=1` — 지운 폴더가 있을 때 요약 한 줄을 낸다. 공시: `plugins/quality-gates/README.md:406-407 · 489-496 · 517` · `CLAUDE.md:71`(예시로 `quality-gates:qg-gc`). 충돌 하나 — 코드는 요약 줄을 `print(…)` 로 stdout 에 내는데(`qg-gc.py:127-128`, docstring 도 「on stdout」) README 는 「GC sweep 진단을 stderr로」 라고 적는다(`README.md:407`)."
    touches: []
    decides: [OQ32]
  - id: RC23
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "kill switch는 `DEVBREW_QUALITY_GATES_DISABLE_CODEX=1`이다. 이 게이트는 현재 **산문**이며 모델이 detect를 돌린다"
    line: 488
    claim: "【끄기】 `DEVBREW_QUALITY_GATES_DISABLE_CODEX=1`. 변수를 읽는 것은 감지기(RC4)뿐이고, quality-pipeline 에서 감지기를 돌려 러너 호출을 가르는 게이트는 리터럴 펜스가 아니라 산문이다(SKILL 이 스스로 그렇게 적는다). 러너 `scripts/run_codex_reviewer.sh` 는 이 변수를 주석 · 안내 문구에서만 언급한다(`:181 · 234`). 끄는 것: codex 리뷰(다른 전제 각도 `absent`), artifact-critique 의 codex co-review. 공시: `plugins/quality-gates/README.md:130 · 381 · 469` · `skills/quality-pipeline/SKILL.md:1625` · `skills/artifact-critique/SKILL.md:71`."
    touches: []
    decides: [OQ32]
  - id: RC24
    path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
    anchor: "**Kill switch — `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1`.** 매 iteration, 아래 `security-reviewer` Agent 리터럴을 발행하기 **직전에** 이 게이트를 통과시킨다"
    line: 412
    claim: "【끄기】 `DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1`. 읽는 스크립트 · 펜스가 없다 — SKILL 산문(`:412-422 · 638 · 1626`)만 있다. 끄는 것: 보안 각도의 `security-reviewer` dispatch 하나. 판정이 `not-certified (angle-absent)` 로 바뀐다(탐지 0 이어도). 공시: `plugins/quality-gates/README.md:23 · 74 · 470` · `CHANGELOG.md:554`."
    touches: []
    decides: [OQ32]
  - id: RC25
    path: "shared/test-selection/run-test-selection.sh"
    anchor: "adapter_usable() — if [[ \"${DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST:-}\" == \"1\" ]]; then … USABLE_REASON=kill_switch"
    line: 294
    claim: "【끄기】 `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1`. 기계가 읽는 자리 둘: 이 공유 스크립트(`run` 이 저장소 코드를 돌리지 않는다)와 `plugins/quality-gates/scripts/e2e-state.sh:38`(e2e 지문 · 부팅도 exit 3). 산문 자리: `skills/quality-pipeline/SKILL.md:774-778`(② 를 통째로 건너뛰고 `--reason kill-switch`) · `references/differential-test.md:39 · 164`(조사용 실행도 하지 않는다). 판정은 `not-certified (kill-switch)`. 공유본이라 어느 플러그인에서 불러도 이 이름이다 — `shared/test-selection/README.md:9` 가 「이름을 바꾸려면 kill switch 는 옛 이름을 별칭으로 계속 읽어야 한다」 고 적는다. 공시: `plugins/quality-gates/README.md:63 · 161 · 296 · 340 · 439 · 477` · `CHANGELOG.md:159 · 257`."
    touches: []
    decides: [OQ32]
  - id: RC26
    path: "plugins/quality-gates/scripts/e2e-state.sh"
    anchor: "killed_by_switch() / cmd_boot() — timeout=\"${DEVBREW_QUALITY_GATES_E2E_BOOT_TIMEOUT:-90}\""
    line: 36
    claim: "【끄기】 `DEVBREW_QUALITY_GATES_DISABLE_E2E=1` — fingerprint · compare · boot 가 exit 3 으로 끝난다(stop · propose 는 막지 않는다 — 꺼진 뒤에도 남은 앱을 내릴 수 있게). 【값 · 정수(초)】 `DEVBREW_QUALITY_GATES_E2E_BOOT_TIMEOUT`(기본 90) — e2e 부팅 준비 신호 대기 상한. 공시: `plugins/quality-gates/README.md:340 · 405 · 441 · 452 · 478` · `skills/quality-pipeline/SKILL.md:1070 · 1629` · `CHANGELOG.md:285`."
    touches: []
    decides: [OQ32]
  - id: RC27
    path: "plugins/quality-gates/scripts/publish-comment.sh"
    anchor: "# 1. kill switch — 어떤 gh 호출보다 먼저 … skip kill-switch"
    line: 35
    claim: "【끄기】 `DEVBREW_QUALITY_GATES_DISABLE_PUBLISH=1` — PR 코멘트 게시만 끈다(gh 호출 0, `skipped: kill-switch`). 판정 · 로컬 결과는 그대로다. 읽는 자리는 이 sink 하나다. 공시: `plugins/quality-gates/README.md:3 · 36-37 · 487` · `skills/quality-pipeline/SKILL.md:1628` · `docs/philosophy/devbrew-harness-philosophy.md:51` · `CHANGELOG.md:324`."
    touches: []
    decides: [OQ32]
  - id: RC28
    path: "plugins/quality-gates/scripts/artifact_max_rounds.sh"
    anchor: "v=\"${DEVBREW_QUALITY_GATES_CRITIQUE_MAX_ROUNDS:-5}\" … echo \"effective_max_rounds: $v\""
    line: 6
    claim: "【값 · 정수 0~10】 `DEVBREW_QUALITY_GATES_CRITIQUE_MAX_ROUNDS`(기본 5, 비정수는 5, 10 초과는 10) — `/quality-gates:artifact-critique` 의 라운드 상한. SKILL E3 이 이 스크립트를 불러 고지 문구와 루프 한도에 같은 값을 쓴다(`skills/artifact-critique/SKILL.md:174-178`). 이 변수 이름은 README 에 없다 — SKILL 은 「env clamp, 기본 5」 라고만 적고 이름을 대지 않으며, 공시는 `plugins/quality-gates/CHANGELOG.md:2626`(개명 표)뿐이다. 【끄기】 `DEVBREW_QUALITY_GATES_DISABLE_CRITIQUE=1` — 읽는 자리는 `scripts/artifact_commit.sh:19`(커밋 sink 에서 거부)와 SKILL E0 산문(`skills/artifact-critique/SKILL.md:83`). 진입 사전 검사는 이 변수를 읽지 않는다. 공시는 `plugins/quality-gates/README.md:38`(Principles 줄)과 SKILL 뿐이고 README 의 「Kill switches」 표들(`:459-496`)에는 행이 없다."
    touches: []
    decides: [OQ32]
  - id: RC29
    path: "plugins/quality-gates/scripts/doc_paths.py"
    anchor: "ENV_KEY = \"DEVBREW_QUALITY_GATES_DOC_PATHS\" / DEFAULT_DOC_PATHS = (\"README*\", \"CHANGELOG*\")"
    line: 35
    claim: "【값 · 쉼표 목록】 `DEVBREW_QUALITY_GATES_DOC_PATHS` — 리뷰 diff 에서 뺄 문서 경로 패턴. 없으면 기본 목록, 빈 값은 「아무것도 빼지 않음」. 리뷰하는 변경이 `.claude/settings.json` · `.claude/settings.local.json` 의 그 키를 바꾸면 이 값을 쓰지 않고 기본 목록으로 돌아간다(docstring `:4-7`, 읽는 자리 `:162-164 · 242`). 공시: `plugins/quality-gates/README.md:81 · 404 · 409-425` · `CHANGELOG.md:144`."
    touches: []
    decides: [OQ32]
  - id: RC30
    path: "shared/docreview/scripts/run_docreview_codex_reviewer.sh"
    anchor: "# 웹 스위치 — 이 if/else 가 WEB_ARGS 를 만드는 **유일한 자리**다 … && \"${DEVBREW_QUALITY_GATES_DISABLE_WEB:-0}\" != \"1\""
    line: 478
    claim: "【끄기 · 웹】 `DEVBREW_QUALITY_GATES_DISABLE_WEB=1`. `plugins/` · `shared/` 실행 코드에서 이 변수를 읽는 자리는 이 공유 러너 하나다 — 프로필이 `web: true` 여도 이 변수나 `DEVBREW_SPEC_DISTILL_DISABLE_WEB` 중 하나라도 `1` 이면 codex 웹 검색을 끈다(「공유 러너는 자기 호스트를 모르므로 과잉 적용(둘 다 검사)」). quality-gates README 에는 이 이름이 없다. 공시는 `plugins/spec-distill/README.md:301` · `plugins/spec-distill/skills/reviewing-brief/SKILL.md:433` · `plugins/quality-gates/CHANGELOG.md:2618 · 2662`(「의도적으로 예약해둔 이름 — 두 ON 사이트가 아직 없어」)뿐이다."
    touches: []
    decides: [OQ32]
  - id: RC31
    path: "plugins/quality-gates/scripts/run_codex_reviewer.sh"
    anchor: "# 없어진 스위치다 — 켜 둔 사용자에게 의도가 여전히 실린다는 것을 알린다(막지 않는다)."
    line: 180
    claim: "【은퇴 · 아직 읽음】 `DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE` — 값이 `1` 이면 stderr 한 줄로 「없어졌다 … codex 를 끄려면 DEVBREW_QUALITY_GATES_DISABLE_CODEX=1」 을 알리고 그대로 진행한다. 아무것도 끄지 않는다. 공시: `plugins/quality-gates/README.md:476`(「제거됨(13.0.0)」) · `CHANGELOG.md:247 · 346`."
    touches: []
    decides: [OQ32]

  # ── plugin-audit ─────────────────────────────────────────────────────────
  - id: RC32
    path: "plugins/plugin-audit/skills/plugin-audit/SKILL.md"
    anchor: "이 표가 보는 kill switch 는 `DEVBREW_PLUGIN_AUDIT_DISABLE=1` 하나다."
    line: 58
    claim: "【끄기】 `DEVBREW_PLUGIN_AUDIT_DISABLE=1`. 읽는 자리는 진입 사전 검사(RC2) 하나다 — plugin-audit 스크립트에는 이 변수를 읽는 코드가 없고 `kill_switch_active` 사본도 없다. 끄는 것: 진입 skill(감사 시작). 도는 중인 감사는 멈추지 않는다 — SKILL 이 「kill switch … 는 다음 진입에서 듣는다」 고 적는다(`:93`). plugin-audit 이 받는 `DEVBREW_SKIP_HOOKS` 토큰은 없다. 공시: `plugins/plugin-audit/README.md:20-21` · SKILL `:77 · 306`."
    touches: []
    decides: [OQ32]
  - id: RC33
    path: "plugins/plugin-audit/skills/plugin-audit/SKILL.md"
    anchor: "kill switch는 `DEVBREW_PLUGIN_AUDIT_DISABLE_CODEX=1`이며 `detect_codex.sh`가 그것을 읽는다 — 러너는 읽지 않는다(게이트는 호출자 책임)."
    line: 183
    claim: "【끄기】 `DEVBREW_PLUGIN_AUDIT_DISABLE_CODEX=1` — codex 감사 co-reviewer 를 끈다. 읽는 자리는 감지기(RC4), 집행은 SKILL 의 `codex-gate` 펜스(`:186`). plugin-audit README 에서 이 이름은 개명 표의 한 칸(`plugins/plugin-audit/README.md:47`)에만 나오고 효과를 설명하는 줄은 없다."
    touches: []
    decides: [OQ32]
  - id: RC34
    path: "plugins/plugin-audit/scripts/run_audit_codex_reviewer.sh"
    anchor: "WEB_ARGS=(-c 'tools.web_search=true' -c 'web_search=\"live\"') / if [[ \"${DEVBREW_PLUGIN_AUDIT_DISABLE_WEB:-0}\" == \"1\" ]]; then"
    line: 122
    claim: "【끄기 · 웹】 `DEVBREW_PLUGIN_AUDIT_DISABLE_WEB=1` — codex 감사의 웹 검색만 끈다(기본은 켜짐 `live`). 꺼지면 stderr 로 「web 비활성 — codex 감사가 리포 근거만 사용」 을 낸다. 읽는 자리는 이 러너 하나다. 공시: `plugins/plugin-audit/README.md:28-31 · 48`."
    touches: []
    decides: [OQ32]
  - id: RC35
    path: "plugins/plugin-audit/scripts/audit-sandbox.sh"
    anchor: "create-sandbox) … if [[ \"${DEVBREW_PLUGIN_AUDIT_DISABLE_RUNTIME_SANDBOX:-0}\" == \"1\" ]] … exit 3 / if [[ \"${DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX:-0}\" == \"1\" ]] … exit 3"
    line: 33
    claim: "【끄기】 `DEVBREW_PLUGIN_AUDIT_DISABLE_RUNTIME_SANDBOX=1` 과 옛 이름 별칭 `DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX=1` — 둘 다 `create-sandbox` 를 exit 3 으로 멈춰 감사 대상의 자체 테스트 실행을 끈다(`scripts/run-own-tests.sh:34` 가 rc 3 을 skip 사유로 옮긴다). 옛 이름이면 stderr 한 줄이 개명을 알린다. 다른 플러그인 이름을 단 변수를 plugin-audit 이 읽는 자리다. 공시: `plugins/plugin-audit/README.md:33-37 · 50-52` · SKILL `:307-308` · `plugins/plugin-audit/CHANGELOG.md:146`(0.11.1 Security — 옛 이름이 조용히 무시되던 fail-open 을 닫음). 문서끼리의 충돌 — `plugins/plugin-audit/CHANGELOG.md:159`(0.11.0)는 「옛 이름은 더 읽지 않는다(fallback 없음)」, `plugins/quality-gates/CHANGELOG.md:396` 은 「옛 스위치 이름은 어디서도 읽지 않는다」 고 적는데, 지금 코드는 읽는다(0.11.1 이 되돌렸다). `plugins/quality-gates/README.md:480-481` 은 새 이름만 가리킨다."
    touches: []
    decides: [OQ32]
  - id: RC36
    path: "plugins/plugin-audit/scripts/check-staleness.py"
    anchor: "_REGISTRY_ENV = \"DEVBREW_PLUGIN_AUDIT_STALENESS_REGISTRY\" / def _registry_path()"
    line: 318
    claim: "【값 · 경로】 `DEVBREW_PLUGIN_AUDIT_STALENESS_REGISTRY` — 설치 레지스트리(`~/.claude/plugins/installed_plugins.json`) 경로의 override. docstring 은 목적을 「테스트 격리」 로 적는다. 공시: `plugins/plugin-audit/README.md:39 · 49`."
    touches: []
    decides: [OQ32]

  # ── 최상위 문서의 공시 · 은퇴한 이름 · 스위치가 아닌 것 ─────────────────────
  - id: RC37
    path: "CLAUDE.md"
    anchor: "- **모든 훅에 kill switch.** 진입 skill 도 같다. `DEVBREW_<PLUGIN>_DISABLE=1` 은 그 플러그인의 훅과 진입 skill 을 끈다(진입 사전 검사)."
    line: 71
    claim: "최상위 문서가 공시하는 것은 «꼴» 둘과 예시 둘이다 — `DEVBREW_<PLUGIN>_DISABLE=1`(훅 + 진입 skill) · `DEVBREW_SKIP_HOOKS=<plugin>:<이름>`(이름 붙은 한 곳, 진입 사전 검사는 읽지 않음), 예시 `spec-distill:review-entry` · `quality-gates:qg-gc`. 개별 기능 스위치 · 값 변수의 목록은 CLAUDE.md 에 없다. 같은 문서의 「메타데이터 & 버전 관리」 절은 kill switch 이름의 은퇴에 CHANGELOG `Removed` 와 README 공시를 요구한다. 루트 `README.md` 에서 `DEVBREW_` 는 `$DEVBREW_PYTHON` 한 번뿐이다(`README.md:48`). 그 밖의 최상위 문서: `docs/plugin-authoring.md:16`(「hooks/ — 각각 DEVBREW_<PLUGIN>_DISABLE=1 opt-out」) · `docs/philosophy/devbrew-harness-philosophy.md:51`(게시 스위치 둘)."
    touches: []
    decides: [OQ32]
  - id: RC38
    path: "plugins/quality-gates/CHANGELOG.md"
    anchor: "Task 25(무게 감축): 환경변수 어순을 `DEVBREW_<PLUGIN>_<REST>` 하나로 통일 — … 옛 이름 → 새 이름 매핑 표"
    line: 2609
    claim: "CHANGELOG · README 개명 표에만 남고 `plugins/` · `shared/` · `tools/` 의 실행 코드 · SKILL 에서 읽는 자리가 없는 이름들이다. quality-gates: 옛 어순 `DEVBREW_DISABLE_QUALITY_GATES` · `DEVBREW_DISABLE_QG_{CODEX,WEB,SECURITY_REVIEWER}` · `DEVBREW_QG_*` · `DEVBREW_GATE3_MAX_RESOLUTIONS` · `DEVBREW_DISABLE_GATE3_TEST_VALIDATION` · `DEVBREW_QG_DEADLINE_MIN` · `DEVBREW_QG_NO_SIGNAL_MAX` · `DEVBREW_QG_DISABLE_SCOPE_REDIRECT`, 제거된 `DEVBREW_QUALITY_GATES_DISABLE_BRANCH_WORKTREE` · `DEVBREW_QUALITY_GATES_KEEP_WORKTREE`(`CHANGELOG.md:392`) · `DEVBREW_QUALITY_GATES_RUNTIME_MAX_RESOLUTIONS`(`:545`) · `DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_TEST_VALIDATION`(`:2654`), 제거된 토큰 `quality-gates:session-start-advisor`(`:frontmatter-scan`) · `quality-gates:session-end-cleanup` 과 이벤트 별칭(`:395`). spec-distill(`plugins/spec-distill/CHANGELOG.md`): `DEVBREW_DISABLE_SPEC_DISTILL{,_CODEX,_BRIEF_REVIEW}` · `DEVBREW_RHYTHM_GUARD_THRESHOLD`(`:3931-3934`) · `DEVBREW_SPEC_DISTILL_RHYTHM_GUARD_THRESHOLD`(`:640`) · `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC`(`:1407`) · `DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK`(`:1488`) · `DEVBREW_SPEC_DISTILL_PROBE_CAP`(`:3079`) · `DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC`(`:4546`) · `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN`(`:5265`) · `DEVBREW_SPEC_DISTILL_SKIP_RECONSENSUS`(`:5340`). project-init: `DEVBREW_DISABLE_PROJECT_INIT`(`plugins/project-init/CHANGELOG.md:333`). plugin-audit: `DEVBREW_DISABLE_PLUGIN_AUDIT{,_CODEX,_WEB}` · `DEVBREW_STALENESS_REGISTRY`(`plugins/plugin-audit/README.md:46-49` — 「표의 옛 이름은 마지막 줄을 빼고 더는 읽지 않는다」). 옛 어순 이름에 별칭 읽기는 없다 — 별칭으로 남은 것은 RC35 의 하나뿐이다."
    touches: []
    decides: [OQ32]
  - id: RC39
    path: "plugins/plugin-audit/scripts/check-shape-completeness.py"
    anchor: "def _has_killswitch(text, own_name)"
    line: 177
    claim: "스위치 이름을 «글자로» 읽는 감사 기준 — 스위치 자체가 아니다. 대상 플러그인의 훅 스크립트 본문에 `DEVBREW_SKIP_HOOKS` · 그 플러그인 자기 이름의 `DEVBREW_<OWN>_DISABLE`(뒤에 `[A-Z0-9_]` 가 이어지지 않는 것) · `kill_switch_active(\"<own>\"` 중 하나가 있어야 통과시킨다(남의 스위치 · 하위 스위치는 인정하지 않는다). `scripts/check-staleness.py:530 · 573-576` 은 훅이 있는데 README 에 `DEVBREW_[A-Z0-9_]*_DISABLE|DEVBREW_SKIP_HOOKS|kill switch` 가 없으면 「미문서화」 사실을 낸다. `scripts/audit-workflow.js:389` 는 감사자 프롬프트에 같은 두 꼴을 싣는다. 스위치의 이름 꼴을 바꾸면 이 세 자리가 함께 걸린다. 공시: `plugins/plugin-audit/README.md:94` · `CHANGELOG.md:42`."
    touches: []
    decides: [OQ32]
  - id: RC40
    path: "tools/plain-language/measure_output.py"
    anchor: "DEVBREW_PLUGINS = (\"spec-distill\", \"quality-gates\", \"plugin-audit\", \"project-init\")"
    line: 49
    claim: "`DEVBREW_` 로 시작하지만 환경 변수가 아닌 것들 — 전수에서 뺀다. (a) `tools/` 의 유일한 일치인 이 Python 상수. (b) SKILL · reference 의 heredoc 구분자 `DEVBREW_PATH_EOF` · `DEVBREW_EXTRA_APPROVAL_EOF` · `DEVBREW_DECISION_LINE_EOF` · `DEVBREW_DECISION_QUOTE_EOF` · `DEVBREW_ROADMAP_TITLE_EOF` · `DEVBREW_ROADMAP_APPROVAL_EOF` · `DEVBREW_REDECOMPOSE_{PATH,CHANGE,TABLE,APPROVAL}_EOF`. (c) 테스트 전용: `DEVBREW_QUALITY_GATES_AGENT_TOOLS_LOCK_EMIT`(`plugins/quality-gates/tests/test_agent_tools_lock_*.sh` · `test_agent_frontmatter_keys.sh`, CHANGELOG 가 「test-only」 로 적는다) · fixture 이름 `DEVBREW_FIX_TURE_DISABLE`(`shared/tests/test_python_floor.sh:176`). `DEVBREW_BEHAVIOR_TESTS` 는 `plugins/spec-distill/CHANGELOG.md:3155` 에만 있고 테스트에서도 읽는 자리를 찾지 못했다. `tools/` 에는 `DEVBREW_` 환경 변수를 읽는 자리가 없다."
    touches: []
    decides: []
unanswered: "레포가 답하지 못한 부분 셋 — ① 각 스위치의 «공식 대응물»(Claude Code 가 제공하는 설정 · 권한 · 훅 끄기 수단)은 레포에 적혀 있지 않다. ② Grep · Glob 이 심볼릭 링크를 건너뛰어 어느 플러그인이 어느 shared 정본을 실제로 링크하는지는 확인하지 못했다(SKILL 펜스의 호출 경로와 README 서술로만 읽었다). 특히 quality-gates 가 `run_docreview_codex_reviewer.sh` 를 실제로 부르는 자리(= `DEVBREW_QUALITY_GATES_DISABLE_WEB` 이 효과를 내는 자리)가 있는지는 확정하지 못했다 — `git ls-files -s` 로 mode 120000 을 봐야 한다. ③ 산문으로만 집행되는 스위치 넷(RC13 · RC15 · RC16 · RC24)과 quality-pipeline 의 codex 게이트(RC23)가 실행 때 실제로 지켜지는지는 코드로 확인할 수 없다."
```

요약 집계(위 주장의 색인):

- **플러그인 전체 끄기 넷** — `DEVBREW_{SPEC_DISTILL,QUALITY_GATES,PLUGIN_AUDIT,PROJECT_INIT}_DISABLE`. 이름은 도출된다(RC1 · RC2 · RC3).
- **`DEVBREW_SKIP_HOOKS` 의 살아 있는 토큰 여덟** — 훅을 가리키는 것은 `project-init:post-tool-use` · `project-init:PostToolUse` 둘뿐이다. 나머지 여섯(`spec-distill:review-entry` · `:statusline` · `:session-end-cleanup` · `:SessionEnd` · `:spec-distill-gc`, `quality-gates:qg-gc`)은 훅이 아닌 자리다. 은퇴했지만 알림용으로 아직 읽는 토큰이 spec-distill 에 여섯 있다(RC11).
- **기능 끄기 스위치 열넷 + 별칭 하나**
  - spec-distill 여섯: `DESIGN_MODE_DISABLE` · `DISABLE_CODEX` · `DISABLE_RECRITIC` · `DISABLE_WEB` · `DISABLE_WORKTREE` · `DISABLE_BRIEF_REVIEW`.
  - quality-gates 여섯: `DISABLE_CODEX` · `DISABLE_SECURITY_REVIEWER` · `DISABLE_DIFFERENTIAL_TEST` · `DISABLE_E2E` · `DISABLE_PUBLISH` · `DISABLE_CRITIQUE`.
  - plugin-audit 둘: `DISABLE_CODEX` · `DISABLE_WEB`.
  - 여기에 `DEVBREW_QUALITY_GATES_DISABLE_WEB`(공유 러너만 읽음, RC30), `DEVBREW_PLUGIN_AUDIT_DISABLE_RUNTIME_SANDBOX` 와 그 옛 이름 별칭(RC35), 한 번 건너뛰기 `DEVBREW_SPEC_DISTILL_SKIP_VC_ONCE`(RC18)가 더 있다.
- **값을 받는 변수 열넷**
  - 정수 열: `DEVBREW_SPEC_DISTILL_{RESEARCH_LIMIT,SATURATION_LIMIT,TTL_HOURS}` · `DEVBREW_DOCREVIEW_{DETECTORS,REREVIEW_CAP,RENDER_CAP,SUMMARY_WIDTH}` · `DEVBREW_QUALITY_GATES_{TTL_HOURS,E2E_BOOT_TIMEOUT,CRITIQUE_MAX_ROUNDS}`.
  - 목록 하나: `DEVBREW_QUALITY_GATES_DOC_PATHS`.
  - 경로 둘: `DEVBREW_PYTHON` · `DEVBREW_PLUGIN_AUDIT_STALENESS_REGISTRY`.
  - 세션 id 하나: `DEVBREW_SPEC_DISTILL_SESSION_ID`.
  - 이 밖에 진단 플래그 `DEVBREW_QUALITY_GATES_GC_VERBOSE` 와, 입력이 아니라 내보내기만 하는 `DEVBREW_PYTHON_IGNORED` 가 있다.
- **공시가 비는 자리**
  - `DEVBREW_QUALITY_GATES_CRITIQUE_MAX_ROUNDS` — README 에 이름이 없다(RC28).
  - `DEVBREW_QUALITY_GATES_DISABLE_CRITIQUE` — README 의 Kill switches 표에 행이 없다(RC28).
  - `DEVBREW_QUALITY_GATES_DISABLE_WEB` — quality-gates README 에 없다(RC30).
  - `DEVBREW_PLUGIN_AUDIT_DISABLE_CODEX` — README 의 개명 표 한 칸뿐이다(RC33).
  - `DEVBREW_SPEC_DISTILL_SKIP_VC_ONCE` · `DEVBREW_SPEC_DISTILL_SESSION_ID` — README 에 없다(RC18 · RC19).
  - `DEVBREW_DOCREVIEW_*` — spec-distill README 에만 있다(RC20).
- **문서와 코드의 충돌 둘** — GC_VERBOSE 의 출력 스트림(RC22), RUNTIME_SANDBOX 옛 이름을 읽는지에 대한 CHANGELOG 문장들(RC35).
- **결정 연결** — 스위치를 다루는 주장은 모두 OQ32 에 닿고, RC17 은 조사 호출 상한 60 때문에 OQ35 에도 닿는다. RC40 은 연결이 없다.

읽은 주요 파일(절대 경로):
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/killswitch/kill_switch_active.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/entry/entry_preflight.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/python/devbrew-python.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/codex/detect_codex.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/docreview/scripts/docreview_config.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/docreview/scripts/run_docreview_codex_reviewer.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/test-selection/run-test-selection.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/gc/gc_common.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/project-init/hooks/hooks.json
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/project-init/hooks/post-tool-use.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/review_entry.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/control_plane.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/ledger_sweep.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/state_path.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/check_brief.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/scripts/qg-gc.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/scripts/e2e-state.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/scripts/artifact_max_rounds.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/scripts/doc_paths.py
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/plugin-audit/scripts/audit-sandbox.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/plugin-audit/scripts/run_audit_codex_reviewer.sh
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/plugin-audit/scripts/check-staleness.py
- 네 플러그인의 README.md · CHANGELOG.md · SKILL.md, 그리고 /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/CLAUDE.md · /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/README.md
~~~~

### 조사 20 — open-researcher · R10 · 묶음 12

~~~~
조사 결과 (확인한 날 2026-11-14 · 전부 code.claude.com/docs 본문을 직접 읽음 · 레포 판은 `dependencies.md` 에서 읽음)

`supports` 라벨 기준(주문에 기대 결론이 없어 내가 임시로 정함 — 본체가 다시 붙여도 됨): `current` = 지금 레포 방식(자체 스위치 · 자체 상태 자리)을 남길 근거, `alternative` = 공식 대응물로 옮길 수 있다는 근거, `both` = 양쪽에 걸리거나 중립 사실.

판: 레포가 쓰는 판 = claude-code 2.1.303(잰 날 2026-10-22, RC1) · 최신 upstream = 2.1.325(2026-11-13, changelog 맨 위). 아래 `version` 칸은 모두 이 값이고, 판 조건이 붙은 항목만 claim 안에 따로 적었다.

```yaml
evidence:
  # ── 1. ${CLAUDE_PLUGIN_ROOT} · ${CLAUDE_PLUGIN_DATA} ──────────────────────────
  - url: "https://code.claude.com/docs/en/plugins/manifest-reference#environment-variables"
    supports: both
    claim: >
      (가져온 주소는 /en/plugins-reference 이고 그 본문이 「Plugin manifest reference」다.)
      치환 자리와 환경 변수 자리를 한 표로 적는다 — 「Where each variable resolves」:
      Hook commands = "Anywhere in `command` and `args`" / 프로세스에 `CLAUDE_PLUGIN_ROOT`, `CLAUDE_PLUGIN_DATA`, `CLAUDE_PROJECT_DIR`, `CLAUDE_PLUGIN_OPTION_<KEY>` export ·
      Monitor commands = "Anywhere in `command`" / "Not exported" ·
      MCP `stdio` servers = `command`, `args`, `env` / 세 경로 변수 export ·
      MCP `http`,`sse`,`ws` = `url`, `headers`, `headersHelper` / "Not applicable" ·
      LSP servers = `command`, `args`, `env`, `workspaceFolder` / 세 경로 변수 export ·
      "Skill, command, and agent content" = "Anywhere in the Markdown body" / "Not applicable".
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  - url: "https://code.claude.com/docs/en/plugins/manifest-reference#where-each-variable-resolves"
    supports: current
    claim: >
      Bash 도구 프로세스에는 이 변수들이 없다고 문서가 명시한다. 원문:
      "The variables aren't present in the environment of commands Claude runs through the Bash tool, in the main session or in a subagent. In skill, command, and agent content, write the `${...}` reference in the Markdown body instead, and Claude Code substitutes the path inline when it loads the content."
      즉 Bash 도구로 도는 스크립트가 경로를 얻는 길로 문서가 적는 것은 「본문에 `${...}` 를 써서 글자 치환된 경로를 명령에 싣는 것」 하나다.
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  - url: "https://code.claude.com/docs/en/skills#available-string-substitutions"
    supports: both
    claim: >
      skill 쪽 치환 자리는 둘이다. 원문:
      "Claude Code substitutes `${CLAUDE_SKILL_DIR}` and `${CLAUDE_PROJECT_DIR}` in two places: the skill's markdown content, and Bash rules in the `allowed-tools` frontmatter. In a plugin skill, Claude Code substitutes `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_PLUGIN_DATA}` in the same two places."
      표 행: "`${CLAUDE_PLUGIN_ROOT}`: The plugin's installation directory. Substituted only in plugin skills." / "`${CLAUDE_PLUGIN_DATA}`: The plugin's persistent data directory, which survives plugin updates. Substituted only in plugin skills."
      `${CLAUDE_SKILL_DIR}` 행에는 "Use this in bash injection commands to reference scripts or files bundled with the skill" 이 있다.
      문서에 없음: (a) skill 이 Read 로 여는 보조 파일(references 등) 안의 `${...}` 가 치환되는지, (b) `!` 사전 실행 줄 안의 `${CLAUDE_PLUGIN_ROOT}`/`${CLAUDE_PLUGIN_DATA}` 를 직접 짚은 문장(「markdown content」에 포함된다고 읽히지만 명시 문장은 `${CLAUDE_SKILL_DIR}` 에만 있다), (c) bash 코드 펜스를 따로 다룬 문장(본문 "Anywhere in the Markdown body" 로만 덮인다).
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: uncertain

  - url: "https://code.claude.com/docs/en/skills#inject-dynamic-context"
    supports: both
    claim: >
      `!` 사전 실행: "The `` !`<command>` `` syntax runs shell commands before the skill content is sent to Claude." · "Substitution runs once over the original file." · 줄 머리나 공백 뒤의 `!` 만 인식 · 작업 폴더는 "the session shell's current working directory" ·
      "Injected commands never prompt for permission while the skill renders. Claude Code checks each one against your permission rules first." · "Outside auto mode, when a command's permission check returns anything other than allow, Claude Code aborts the invocation. To keep an unmatched command from aborting, pre-approve it with `allowed-tools`." ·
      끄는 키 `disableSkillShellExecution`(플러그인 skill 포함, 명령이 `[shell command execution disabled by policy]` 로 바뀜).
      문서에 없음: `!` 사전 실행 줄이 샌드박스 안에서 도는지 · 그 프로세스에 플러그인 경로 환경 변수가 실리는지.
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  - url: "https://code.claude.com/docs/en/plugins/manifest-reference#environment-variables"
    supports: alternative
    claim: >
      데이터 폴더 경로 규칙과 수명(문장 그대로):
      "`${CLAUDE_PLUGIN_DATA}` | `~/.claude/plugins/data/<id>/`, created on first reference and kept across plugin updates. `<id>` is the plugin identifier with every character other than a letter, digit, `_`, or `-` replaced by `-` | Installed dependencies such as `node_modules`, generated code, and caches"
      "`${CLAUDE_PLUGIN_ROOT}` changes when the plugin updates, so don't write state there."
      "By default, Claude Code deletes the `${CLAUDE_PLUGIN_DATA}` directory when you uninstall the plugin from the last place it's installed."
      components 문서의 예: "`my-plugin@my-marketplace` becomes `my-plugin-my-marketplace`".
      문서가 적는 용도는 의존 설치물 · 생성 코드 · 캐시(components 문서는 "for `node_modules`, virtual environments, and caches")이고, loading 문서는 "Keep a plugin's durable files in `${CLAUDE_PLUGIN_DATA}` instead." 라고 적는다.
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  - url: "https://code.claude.com/docs/en/plugins/cli-reference#plugin-uninstall"
    supports: both
    claim: >
      지워지는 때: "When you uninstall a plugin from the last scope it's installed at, Claude Code also deletes the plugin's stored options and secrets and its data directory, `~/.claude/plugins/data/<id>/`. There are three exceptions:" — `--keep-data` · 같은 폴더를 쓰는 다른 설치 플러그인(대소문자만 다른 ID) · 설치 목록을 다시 못 읽을 때.
      마켓플레이스를 마지막 scope 에서 지워도 그 플러그인들이 제거되고 options · secrets · data 가 "where it can" 지워진다(같은 문서 `plugin marketplace remove` 경고).
      끄기(disable)는 "Disable a plugin without uninstalling it" — 데이터 폴더 삭제는 uninstall 쪽에만 적혀 있다.
      크기 재기: `claude plugin list --json --data-size`(v2.1.285 이상).
      문서에 없음: `--plugin-dir`(`@inline`) · skills-dir(`@skills-dir`) 플러그인의 데이터 폴더 id 와 그 폴더가 지워지는 때(삭제 규칙은 마켓플레이스 설치 기준으로만 적힘).
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  - url: "https://code.claude.com/docs/en/plugins/loading#find-plugins-on-disk"
    supports: both
    claim: >
      플러그인 루트는 "`~/.claude/plugins` unless you set `CLAUDE_CODE_PLUGIN_CACHE_DIR`" 이고 표의 모든 경로(`cache/<marketplace>/<plugin>/<version>/` · `data/<plugin-id>/` 등)는 그 루트 기준이다. `~/.claude` 자체는 `CLAUDE_CONFIG_DIR` 로 옮겨진다(claude-directory 문서). 따라서 데이터 폴더의 실제 절대 경로는 이 두 변수에 따라 달라진다.
      "Claude Code creates it when a plugin component first uses it and keeps it across updates."
      로컬 경로 마켓플레이스의 상대 경로 플러그인은 제자리에서 읽히고("loads in place"), hook · MCP · LSP 프로세스는 소스 폴더를 가리키는 `CLAUDE_PLUGIN_ROOT` 를 받는다. 그 밖의 마켓플레이스 플러그인은 cache 로 복사되고 "Files outside the plugin directory aren't copied".
      claude-directory 문서의 「Cleaned up automatically」 표에 `plugins/data` 는 없다(자동 청소 대상은 `plugins/.trash/` · `plugins/mcpb/` · set-aside 사본).
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  - url: "https://code.claude.com/docs/en/hooks#persist-environment-variables"
    supports: both
    claim: >
      hook 이 뒤따르는 Bash 명령에 환경 변수를 넘기는 일반 길이 있다: "SessionStart hooks have access to the `CLAUDE_ENV_FILE` environment variable, which provides a file path where you can persist environment variables for the shell commands Claude runs later in the session." / "`CLAUDE_ENV_FILE` is available for SessionStart, Setup, CwdChanged, and FileChanged hooks."
      hook 프로세스는 `CLAUDE_PLUGIN_ROOT`·`CLAUDE_PLUGIN_DATA` 를 받으므로 둘을 이으면 Bash 도구에 경로를 실을 수 있어 보이지만, 플러그인 경로 변수를 이 길로 넘기라고 적은 문장은 문서에 없음 — 두 문서 조각의 조합은 내 추론이다.
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: uncertain

  # ── 2. 샌드박스 ────────────────────────────────────────────────────────────
  - url: "https://code.claude.com/docs/en/sandboxing#filesystem-isolation"
    supports: both
    claim: >
      기본 쓰기: "read and write access to the current working directory and its subdirectories, any directories you've added with `--add-dir`, `/add-dir`, or `permissions.additionalDirectories`, plus the per-user temp directory that `$TMPDIR` points to".
      기본 읽기: "read access to the entire computer, except certain denied directories."
      적용 범위: "The sandbox covers shell commands only." — Bash · PowerShell · Monitor 명령과 그 자식 프로세스. subagent 의 Bash 도 부모 세션 설정대로 샌드박스된다.
      샌드박스 밖: Read/Edit/Write/WebFetch/WebSearch 같은 내장 도구(권한 규칙을 따름) · "command hooks, local MCP servers, plugin monitors, LSP servers, and helper commands … run with your full access" · mods.
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  - url: "https://code.claude.com/docs/en/sandboxing#protected-paths"
    supports: current
    claim: >
      `~/.claude` 에 대해 문서가 적는 것(쓰기 가능 폴더 안에서도 쓰기가 막히는 보호 경로 넷 중 하나):
      "**In `~/.claude`, or the directory `CLAUDE_CONFIG_DIR` points to**: most of its contents, plus `~/.claude.json` and the `.credentials.json` credential store"
      "If you add an `allowWrite` entry or an `Edit` allow rule that covers one of these paths, the protection still applies. To turn the protection off, set `filesystem.disabled`, which also turns off the rest of filesystem isolation."
      작업 폴더 쪽 보호 경로는 "the `.claude` settings files, the `.claude/skills`, `.claude/agents`, `.claude/commands`, and `.claude/hooks` directories, `.mcp.json`, … `.claude/workflows` and `.claude/scheduled_tasks.json`" 로 열거된다.
      문서에 없음: `~/.claude/plugins/data/` 가 "most of its contents" 에 드는지 — 열거가 없고 "run `/sandbox` and open the **Config** tab" 으로 확인하라고만 적는다. 확실한 것은 그 폴더가 기본 쓰기 자리(작업 폴더 · 임시 폴더 · 더한 폴더) 밖이라 기본으로는 샌드박스된 Bash 가 쓸 수 없다는 것까지다. `allowWrite` 로 열 수 있는지는 문서로 판정되지 않는다.
      최신 판 변경(2.1.325 changelog): "Changed the sandbox to refuse sandboxed writes to `.claude` settings, skills, agents, commands and hooks in added directories, as it does in the launch folder".
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: uncertain

  - url: "https://code.claude.com/docs/en/settings-reference#sandbox-filesystem-allowwrite"
    supports: both
    claim: >
      쓰기 자리를 더하는 키: `sandbox.filesystem.allowWrite`(경로 배열, scope "Any file" — 프로젝트 · 로컬 설정에는 제한이 있다) · `permissions.additionalDirectories` · `--add-dir` · `/add-dir` · `Edit(...)` allow 규칙("Grant write access to specific paths, the same way `sandbox.filesystem.allowWrite` does"). 막는 쪽은 `sandbox.filesystem.denyWrite`.
      "An `allowWrite` entry can't lift a protected path." · Linux/WSL2 에서는 "an entry for a path that doesn't exist yet has no effect, so create the path first."
      경로 접두: `/` 절대 · `~/` 홈 · `./` 또는 접두 없음 = "Relative to the project root for project settings, or to `~/.claude` for user settings".
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  - url: "https://code.claude.com/docs/en/sandboxing#the-unsandboxed-retry-escape-hatch"
    supports: both
    claim: >
      샌드박스 밖으로 빠지는 길 셋: (1) 재시도 — "Claude analyzes the failure and may retry the command with the `dangerouslyDisableSandbox` parameter." 승인 주체는 권한 모드에 따른다(bypassPermissions 는 프롬프트 없음 · manual/acceptEdits 는 "Bash command (unsandboxed)" 프롬프트 · auto 는 분류기 · dontAsk 는 거부). 맞는 allow 규칙이 있으면 재시도도 프롬프트 없이 돈다. `sandbox.allowUnsandboxedCommands: false` 면 이 파라미터가 무시된다(엄격 모드).
      (2) `sandbox.excludedCommands` — 호출 안의 모든 명령을 덮어야 빠지고, `cd` · 명령 치환 · 서브셸 · 제어 블록 · 리다이렉션(`2>&1` 제외) · heredoc 이 든 호출은 그래도 샌드박스에 남는다. "Exclusion is a convenience, not a security boundary".
      (3) 사용자가 `!` 셸 모드 프롬프트에 직접 친 명령(대부분의 세션에서 샌드박스 밖).
      판 차이: `sandbox.autoAllowBashIfSandboxed` 기본값 — "**Default**: `false`. Before v2.1.324, the default was `true`" → 레포가 쓰는 2.1.303 과 최신 2.1.325 의 기본값이 다르다.
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  - url: "https://code.claude.com/docs/en/permission-modes#protected-paths"
    supports: current
    claim: >
      샌드박스와 별개로 권한 체계에도 보호 경로가 있다(Write/Edit 도구 쪽). 보호 폴더 목록에 "`.claude`, with a few exceptions, such as:" 가 있고 예외로 든 것은 `.claude/worktrees/` · `~/.claude/plans/` · `~/.claude/jobs/<id>/tmp/` · auto memory 의 Markdown · subagent memory 의 Markdown 이다. 보호 경로 쓰기는 default · acceptEdits 에서 "Prompted", dontAsk 에서 "Denied", 설정 파일의 `permissions.allow` 는 이를 미리 승인하지 못한다("do not pre-approve protected-path writes").
      문서에 없음: `~/.claude/plugins` · `plugins/data` 는 이 절에 언급되지 않는다(예외 목록이 "such as" 라 전수인지도 알 수 없다). 프로젝트의 `.claude/<임의 폴더>/` 가 예외인지도 적혀 있지 않다.
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: uncertain

  # ── 3. 플러그인 끄기 ─────────────────────────────────────────────────────────
  - url: "https://code.claude.com/docs/en/plugins/cli-reference#plugin-disable"
    supports: alternative
    claim: >
      `claude plugin disable [plugin] [options]` — `-a, --all`(이름 · `--scope` 와 함께 못 씀) · `-s, --scope <scope>`("`user`, `project`, or `local`. Auto-detected when omitted") · `--json`.
      "`--scope` takes `user`, `project`, or `local`, and names the settings file the command writes to."
      scope 를 안 주면 local → project → user 순으로 그 플러그인을 언급한 첫 설정 파일을 쓴다.
      선언되지 않은 scope 를 주면: 선언 scope 보다 우선하는 scope 면 덮어쓰기를 쓴다 — "`claude plugin disable formatter --scope local` turns off a project-enabled plugin for you alone" — 아니면 실패한다.
      이미 꺼져 있으면 `Plugin "formatter" is already disabled` 와 exit 1. 켜진 다른 플러그인이 의존하면 실패, 조직이 요구하는 synced 플러그인도 실패.
      scope 별 파일(install 문서): user = `enabledPlugins` in `~/.claude/settings.json` · project = `.claude/settings.json` · local = `.claude/settings.local.json`. 쓰이는 값의 꼴은 `"<name>@<marketplace>": false`(loading 문서의 synced 예: "save `\"<name>@synced\": false` in your user-level `enabledPlugins`" · install 문서: "Claude Code writes `false` for the plugin in your `.claude/settings.local.json`").
      worktree 주의(settings 문서): `.claude/settings.local.json` 은 git 레포에서는 레포 루트에 두고 "In a worktree, it uses the file at the main checkout's root."
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  - url: "https://code.claude.com/docs/en/plugins/loading#find-where-a-plugin-is-enabled"
    supports: alternative
    claim: >
      `enabledPlugins` 의 꼴(settings-reference): "object mapping `plugin-name@marketplace-name` to a Boolean", 항목이 어느 scope 에도 없으면 manifest 의 `defaultEnabled` 를 따른다(기본 `true`).
      출처 여섯과 우선순위(낮은 것부터): `--add-dir`(그 폴더의 설정 파일 · `true` 만 효과) < `user`(`~/.claude/settings.json`) < `project`(`.claude/settings.json`) < `local`(`.claude/settings.local.json`) < `flag`("The `--settings` value you pass at launch" — "This session only") < `managed`("`true` force-enables and `false` blocks, and no other source overrides them").
      "These sources merge key by key. For each plugin id, the value that applies is the one from the highest-precedence source that mentions the id."
      그래서 user 에 `false` 를 써도 project 가 `true` 면 계속 켜진다 — 목록에 "Disabled in ~/.claude/settings.json but still loads — project settings enable it…" 가 뜬다.
      `--plugin-dir` 로 읽힌 플러그인은 `"<name>@inline": false` 로, skills-dir 플러그인은 `"<name>@skills-dir"` 로 끈다.
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  - url: "https://code.claude.com/docs/en/settings#change-a-setting-for-one-session"
    supports: alternative
    claim: >
      한 번 실행에만 끄는 길: `--settings` 가 `enabledPlugins` 의 한 출처(`flag`)이고 "This session only" 다. `--settings` 는 "pass a key as JSON, inline or as a path to a file. Claude Code applies it above your user, project, and local files and below managed settings." · "`--settings` lasts one session and doesn't write to any file."
      전부 끄는 실행 옵션: `--safe-mode`("Start with all customizations disabled … CLAUDE.md, skills, plugins, hooks, MCP servers, custom commands and agents … do not load." `CLAUDE_CODE_SAFE_MODE` 를 세팅) · `--bare`("skip auto-discovery of hooks, skills, custom commands, subagents, installed plugins, MCP servers, auto memory, and CLAUDE.md") · `--disable-slash-commands`("Disable all skills and commands for this session") · `--setting-sources`(읽을 설정 출처 고르기).
      문서에 없음: 특정 플러그인 하나를 끄는 환경 변수. env-vars 표에서 이름에 PLUGIN·HOOK·SKILL 이 든 행을 훑었고, 있는 것은 `CLAUDE_CODE_PLUGIN_CACHE_DIR` · `CLAUDE_CODE_PLUGIN_DIRS` · `CLAUDE_CODE_PLUGIN_SEED_DIR` · `CLAUDE_CODE_SYNC_PLUGIN_INSTALL` · `CLAUDE_CODE_DISABLE_BUNDLED_SKILLS`("Skills from plugins … are unaffected") · `CLAUDE_CODE_DISABLE_POLICY_SKILLS` 등으로 플러그인 하나를 끄는 변수는 없었다. `CLAUDE_PLUGIN_ROOT`·`CLAUDE_PLUGIN_DATA` 는 env-vars 표에 행이 없다.
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  - url: "https://code.claude.com/docs/en/plugins/cli-reference#reload-plugins"
    supports: both
    claim: >
      도는 세션에 반영되는 때(loading 문서): "Changes to settings or to disk don't reach this layer until you run `/reload-plugins` or start a new session."
      `/reload-plugins`: "Apply pending plugin changes to the running session without restarting it. Pending changes are plugins you installed, updated, enabled, disabled, or edited on disk since the session started." `/plugin` 패널에서 바꾸고 닫으면 자동으로 돈다. 다른 터미널에서 `claude plugin …` 을 돌렸다면 직접 실행한다. `/plugin list` 는 아직 적용 안 된 것에 "— run /reload-plugins to apply" 를 붙인다.
      MCP 서버 · `LSP` 도구가 바뀌어 프롬프트 캐시가 깨지는 reload 는 적용되지 않고 `--force` 를 요구한다. 대화형 터미널이 없는 세션(`-p` · 데스크톱 앱 · SDK, v2.1.260 이상)에서는 사용자가 직접 입력했을 때만 돌고 플러그인 MCP 서버 연결 변경은 다음 세션에 반영된다.
      설정 파일 일반은 감시되어 재시작 없이 다시 읽히지만(settings 문서 "When edits take effect") 플러그인 적재 층은 위 문장대로 reload 나 새 세션을 기다린다.
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  - url: "https://code.claude.com/docs/en/plugins/components"
    supports: both
    claim: >
      끈 플러그인에서 멈추는 것을 한 문장으로 열거한 자리는 문서에 없음. 조각으로는:
      hook — hooks 문서 위치 표 "Plugin `hooks/hooks.json` | When plugin is enabled" · "When a plugin is enabled, its hooks merge with your user and project hooks." · 등록 시점은 "Claude Code registers them when a session loads the plugin".
      MCP · LSP — security 문서 "Claude Code connects to the MCP servers an enabled plugin declares"; reload 요약 줄이 skills · agents · hooks · plugin MCP servers · plugin LSP servers 수를 센다.
      skill — skills 문서 "**Plugin skill**: disable or uninstall the plugin that provides it" · "Plugin skills are not affected by `skillOverrides`."
      `bin/` — "on the `PATH` of the Bash tool's shell while the plugin is enabled".
      monitor — "**Disabling mid-session**: if you disable a plugin mid-session, Claude Code doesn't stop monitors that are already running. They stop when the session ends".
      agent — 끈 뒤의 동작을 직접 적은 문장은 못 찾았다(관리 설정으로 건너뛴 폴더에 대해서만 "Its `/<name>:<skill>` commands and agents are missing, as are its hooks and MCP servers.").
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: uncertain

  # ── 4. disableAllHooks ───────────────────────────────────────────────────────
  - url: "https://code.claude.com/docs/en/settings-reference#disableallhooks"
    supports: alternative
    claim: >
      플러그인 hook 에도 미친다. 원문: "**In any other settings file**: Claude Code disables user, project, local, and plugin hooks; managed hooks, Agent SDK hooks, and hooks from plugins force-enabled in managed `enabledPlugins` keep running" · "**In managed settings**: Claude Code disables every configured hook, including managed ones, and keeps running the hooks the Agent SDK registers in process".
      Scope: "`Any file`. Only managed settings can disable managed hooks." 함께 꺼지는 것: custom status line · custom file suggestion 명령 · mods. `/goal` 은 hook 이 꺼진 동안 못 돈다.
      판 조건: Agent SDK `managedSettings` 옵션 쪽 동작은 v2.1.309 이상(레포가 쓰는 2.1.303 보다 뒤).
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  - url: "https://code.claude.com/docs/en/hooks#disable-or-remove-hooks"
    supports: current
    claim: >
      hook 하나만 끄는 공식 길은 없다고 문서가 명시한다: "There is no way to disable an individual hook while keeping it in the configuration."
      우선순위: "Claude Code reads the value left after settings precedence applies, so a `\"disableAllHooks\": false` in a project's `.claude/settings.json` overrides a `true` in your user settings. To turn hooks off for one run whatever the project's settings say, pass `--settings '{\"disableAllHooks\": true}'`, which takes precedence over project and local settings."
      관리 hook: "`disableAllHooks` set in user, project, or local settings can't disable those managed hooks. Only `disableAllHooks` set at the managed settings level can disable managed hooks."
      `/hooks` 는 "a read-only browser" 다. 관리 설정 `allowManagedHooksOnly` 는 사용자 · 프로젝트 · 로컬 · 플러그인 hook 을 막고 관리 설정이 force-enable 한 플러그인의 hook 은 예외다.
      플러그인 단위로 hook 만 끄는 길(skill 은 두고)은 문서에 없음 — 문서가 적는 단위는 「hook 전부」(disableAllHooks) 또는 「플러그인 통째」(enabledPlugins false)다.
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  # ── 5. 플러그인 설정 값 받기 ─────────────────────────────────────────────────
  - url: "https://code.claude.com/docs/en/plugins/manifest-reference#user-configuration"
    supports: alternative
    claim: >
      공식 길은 `plugin.json` 의 `userConfig` 다: "`userConfig` declares values Claude Code prompts the user for when the plugin is enabled, so users don't edit `settings.json` themselves."
      키는 글자 · 숫자 · 밑줄(숫자로 시작 불가). 값은 strict 객체(모르는 키는 오류로 플러그인이 안 읽힘): `type`(필수 — `string`·`number`·`boolean`·`directory`·`file`) · `title`(필수) · `description`(필수) · `required` · `default` · `options`(v2.1.271 이상 — 선언하면 그 전 판 사용자는 플러그인을 못 읽는다) · `multiple` · `sensitive` · `min`/`max`.
      저장: "Non-sensitive values are saved under `pluginConfigs` in the user's `settings.json`. Sensitive values go to the platform's secure credential store instead." `pluginConfigs` 꼴은 `{"<plugin-id>": {"options": {"<key>": <값>}}}`, scope 는 "User or managed" — "Claude Code ignores project and local entries because it substitutes these values into plugin hook, MCP, and LSP configurations, and a cloned repository must not be able to supply them." 민감 값은 macOS Keychain(거절되면 `~/.claude/.credentials.json`).
      읽는 길 둘: "`${user_config.KEY}`: substituted in MCP server config, LSP server config, exec-form hook `args`, and skill and agent content. In skill and agent content, only non-sensitive values are substituted, and a sensitive value there becomes a placeholder" · "`CLAUDE_PLUGIN_OPTION_<KEY>`: exported to hook processes for every option, with `<KEY>` uppercased."
      못 쓰는 자리: shell-form hook 명령 · monitor 명령 · MCP `headersHelper` 는 `${user_config.*}` 를 거부한다(오류로 실패). monitor 프로세스는 `CLAUDE_PLUGIN_OPTION_<KEY>` 도 못 받는다.
      문서에 없음: Bash 도구로 도는 스크립트가 옵션 값을 환경 변수로 받는 길(`CLAUDE_PLUGIN_OPTION_<KEY>` 는 hook 프로세스에만 적혀 있다) — skill 본문의 `${user_config.KEY}` 치환으로 값을 글자로 싣는 길만 적혀 있다. `!` 사전 실행 줄에서의 `${user_config.*}` 도 따로 적혀 있지 않다.
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  - url: "https://code.claude.com/docs/en/plugins/cli-reference#plugin-configure"
    supports: alternative
    claim: >
      값을 넣는 표면: (1) 대화형 `/plugin` 에서 설치 · 켜기 때 아직 안 정한 옵션에 대해 대화상자가 뜬다. 언제든 `/plugin configure <plugin>@<marketplace>`. (2) `/config` 패널에 옵션 행이 뜬다(`sensitive` · `multiple` 제외, v2.1.269 이상). (3) 셸: `claude plugin install --config <key=value>`(반복) · `claude plugin configure <plugin> --values-stdin`(JSON 객체, "Requires Claude Code v2.1.285 or later", 완전한 `name@marketplace` id 만 받음, 저장 뒤 "Configuration saved. Restart Claude Code to apply it.").
      "The `claude plugin install` shell command never prompts for `userConfig` values."
      레포가 쓰는 2.1.303 은 위 판 조건(2.1.269 · 2.1.271 · 2.1.285)을 모두 넘는다.
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

  - url: "https://code.claude.com/docs/en/changelog"
    supports: both
    claim: "최신 upstream 판은 2.1.325(2026-11-13)이고 그 아래가 2.1.323(11-12) · 2.1.322(11-10) · 2.1.321(11-09) · 2.1.319(11-06)다. changelog 는 앞 10만 자만 읽었다 — 2.1.303 과 2.1.325 사이의 플러그인 · 샌드박스 변경 전수는 확인하지 못했다."
    touches: []
    decides: [OQ32]
    source_kind: primary
    checked_at: "2026-11-14"
    version: {used: "2.1.303", latest: "2.1.325"}
    certainty: confirmed

repo_claims:
  - id: RC1
    path: "plugins/spec-distill/dependencies.md"
    anchor: "| claude-code | 2.1.303 | 2026-10-22 | 기록 | 잰 판을 기록만 한다 |"
    line: 19
    claim: "이 레포가 개발 · 검증 때 쓴 Claude Code 판은 2.1.303(잰 날 2026-10-22)이고 강도는 「기록」이다. 같은 행이 plugins/plugin-audit · project-init · quality-gates 의 dependencies.md 에도 같은 값으로 있다. 바닥 판을 강제하지 않는다."
    touches: []
    decides: [OQ32]
  - id: RC2
    path: "plugins/"
    anchor: "문자열 `CLAUDE_PLUGIN_DATA` 검색 — 0건"
    claim: "플러그인 넷 어디에도 `CLAUDE_PLUGIN_DATA` 가 쓰이지 않는다(검색 0건). 반면 `CLAUDE_PLUGIN_ROOT` 는 81개 파일 468곳에 나온다. Grep 은 심볼릭 링크를 건너뛰므로 0건은 링크 대상 파일을 뺀 범위의 값이다."
    touches: []
    decides: [OQ32]
  - id: RC3
    path: "plugins/spec-distill/.claude-plugin/plugin.json"
    anchor: "문자열 `userConfig` · `defaultEnabled` 검색 — 0건(네 플러그인의 plugin.json 전부)"
    claim: "네 플러그인의 manifest 는 `userConfig` 도 `defaultEnabled` 도 선언하지 않는다 — 공식 설정 값 받기 길을 지금은 쓰지 않는다."
    touches: []
    decides: [OQ32]
  - id: RC4
    path: "plugins/spec-distill/skills/pm-interview/SKILL.md"
    anchor: "SD=\"${CLAUDE_PLUGIN_ROOT}\"; [ -n \"$SD\" ] || { echo \"[spec-distill] 플러그인 루트 미해석 …"
    line: 56
    claim: "skill 본문의 bash 펜스가 `${CLAUDE_PLUGIN_ROOT}` 의 글자 치환에 기대고, 빈 값이면 멈추는 가드를 둔다(같은 줄이 100 · 255행에도 있다). 109행은 「그 파일의 플러그인 루트 변수(`CLAUDE_PLUGIN_ROOT`)는 치환되지 않은 채로 온다」 고 적어 Read 로 여는 reference 파일은 치환되지 않는다는 전제로 쓰여 있다 — 공식 문서는 치환 자리를 본문과 `allowed-tools` 둘로만 적고 보조 파일은 말하지 않는다."
    touches: []
    decides: [OQ32]
  - id: RC5
    path: "plugins/project-init/hooks/hooks.json"
    anchor: "\"command\": \"/bin/sh ${CLAUDE_PLUGIN_ROOT}/scripts/devbrew-python.sh --event PostToolUse --plugin project-init --hook post-tool-use ${CLAUDE_PLUGIN_ROOT}/hooks/post-tool-use.py\""
    line: 10
    claim: "hook 명령이 shell-form 이고 `${CLAUDE_PLUGIN_ROOT}` 를 따옴표 없이 쓴다. 공식 문서는 shell-form 에서 이 변수를 큰따옴표로 감싸라고 적고, 따옴표 밖이면 `claude plugin validate` 가 경고한다고 적는다."
    touches: []
    decides: [OQ32]
  - id: RC6
    path: "plugins/project-init/scripts/devbrew-python.sh"
    anchor: "_ks_skip_has() {   # DEVBREW_SKIP_HOOKS 에 «전체 토큰» $1 이 있는가 (부분 일치 금지)"
    line: 46
    claim: "레포의 자체 스위치는 환경 변수 둘로 구현돼 있다 — `DEVBREW_<PLUGIN>_DISABLE=1`(플러그인 통째)과 `DEVBREW_SKIP_HOOKS=<plugin>:<hook|event>`(쉼표 목록 · 전체 토큰 대조, hook 하나 또는 이벤트 하나). 같은 판정이 plugins/project-init/scripts/kill_switch_active.py(`os.environ.get(\"DEVBREW_SKIP_HOOKS\", \"\")`, 55행)에도 있고, plugins/project-init/hooks/post-tool-use.py 26–28행이 세 꼴을 적는다. 공식 쪽에는 hook 하나만 끄는 길이 없고(문서 명시) 플러그인 하나를 끄는 환경 변수도 문서에 없다."
    touches: []
    decides: [OQ32]
  - id: RC7
    path: "plugins/spec-distill/skills/pm-interview/SKILL.md"
    anchor: "이 표가 보는 kill switch 는 `DEVBREW_SPEC_DISTILL_DISABLE=1` 하나다. `DEVBREW_SKIP_HOOKS` 는 진입 skill 에 걸리지 않는다."
    line: 49
    claim: "진입 skill 의 사전 검사는 `DEVBREW_SPEC_DISTILL_DISABLE=1` 만 본다. 같은 파일에 기능 스위치 `DEVBREW_SPEC_DISTILL_DISABLE_WEB`(324행의 bash 판정)와 값 스위치 `DEVBREW_SPEC_DISTILL_RESEARCH_LIMIT`(기본 60) · `DEVBREW_SPEC_DISTILL_SATURATION_LIMIT`(기본 5)가 환경 변수로 있다 — 값 받기의 공식 대응물 후보는 `userConfig`(type `number`·`boolean`)다."
    touches: []
    decides: [OQ32]

unanswered: "문서로 판정되지 않은 것 — `~/.claude/plugins/data/` 가 샌드박스 보호 경로(\"most of its contents\")와 권한 체계 보호 폴더(`.claude` 예외 목록)에 드는지 · `allowWrite` 로 열리는지(실측은 `/sandbox` Config 탭) · `!` 사전 실행 줄이 샌드박스 안에서 도는지와 그 줄 안의 `${CLAUDE_PLUGIN_DATA}`·`${user_config.*}` 치환 · 보조 파일 안의 변수 치환 · 끈 플러그인의 agent 동작 · `@inline`/`@skills-dir` 플러그인의 데이터 폴더 id 와 수명. 읽지 못한 범위 — hooks 문서 뒤쪽 약 9만 자, changelog 의 2.1.319 이전 항목."
```

읽은 공식 문서 페이지: plugins/manifest-reference(= /en/plugins-reference 로 가져옴) · plugins/components · plugins/loading · plugins/cli-reference · plugins/install · plugins/security · skills · hooks(앞 20만 자) · settings · settings-reference(10만 자부터 끝까지 네 구간) · sandboxing(전체) · permission-modes(앞 10만 자) · cli-reference · env-vars · claude-directory · prompt-caching · changelog(앞 10만 자) · llms.txt 색인(페이지 찾기에만 씀).

레포에서 읽은 파일(절대 경로):
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/dependencies.md
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/project-init/hooks/hooks.json
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/skills/pm-interview/SKILL.md (검색으로 해당 줄만)
- /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/project-init/scripts/devbrew-python.sh · kill_switch_active.py · hooks/post-tool-use.py (검색으로 해당 줄만 — 판정 함수 본문 전체는 읽지 않았다)

본체가 V1 에서 다시 볼 만한 것 셋:
1. RC6 · RC7 은 검색으로 맞은 줄만 근거로 삼았다. 스위치의 실제 판정 흐름 전체(예: `devbrew-python.sh` 가 어느 순서로 무엇을 끄는지)는 구현 본문을 통독하지 않았다.
2. 「Bash 도구에 플러그인 경로를 `CLAUDE_ENV_FILE` 로 싣는다」 는 문서 두 조각을 내가 이은 추론이다(`certainty: uncertain`).
3. `sandbox.autoAllowBashIfSandboxed` 기본값이 v2.1.324 에서 `true` → `false` 로 바뀌었다 — 레포가 쓰는 판과 최신 판의 동작이 갈리는 유일하게 확인된 지점이고, 어느 쪽을 기준으로 삼을지는 사용자 몫이다.
~~~~

## R11

### 지금 이해
경로 (a) · (b). 포화 판정 2 가 짚은 빈 곳 다섯을 조사했다(조사 16 본체 직접 · 조사 17–20 을 한 메시지에서 함께 띄움 — 서로 기대지 않는 빈 곳 넷이라서). 레포 주장 95건(RC185–RC279) 가운데 51건 확인 · 44건 미확인 · 반증 0건이고, S24 의 처분(그대로 싣고 미확인은 표시)을 같은 방식으로 적용했다(본체의 적용). 열린 결정이 하나 늘었다(OQ37).
→ open_questions 재개방: 확인 범위(OQ25–OQ35) 밖에서 열린 결정 OQ36 · OQ37 이 더해졌다
[spec-distill] 포화 판정 2/5: 아직 — 빈 곳 5개, 다음: 샌드박스를 켠 세션에서 Bash 가 `~/.claude/plugins/data/<플러그인>-devbrew/` 에 쓸 수 있는지, 그리고 그 경로를 얻는 길 · 조사 호출 9/60
판정자의 표시와 본체의 조사 기록이 다르다 — 조사 12(판정자: OQ36 을 열었다 / 본체: 연 것 없음) · 조사 13(판정자: OQ15 · OQ24 를 바꿨다 / 본체: 없음) · 조사 14(판정자: OQ13 · OQ32 · OQ36 을 바꿨다 / 본체: 바꾼 것 없이 OQ36 을 열었다) · 조사 15(판정자: OQ32 · OQ28 / 본체: OQ32). 멈춤은 판정자의 것을 따른다.
조사 호출 13/60 · 이 라운드 본체 직접 1
줄인 사실 13개

줄인 사실 전문:
- 스위치: 테스트와 변경 기록 밖에서 `DEVBREW_` 이름이 57개 나온다. 살아 있는 것은 플러그인 전체 끄기 넷 · 이름 붙은 한 곳 끄기 토큰 여덟 · 기능 끄기 열넷 남짓 · 값을 받는 변수 열넷이다(조사 17).
- 토큰 여덟 가운데 실제 훅을 가리키는 것은 project-init 의 둘뿐이다 — 설치되는 훅이 project-init 하나뿐이다(RC189).
- 기능 끄기 넷(재비판 · 워크트리 · brief 리뷰 · 보안 리뷰어)은 읽는 코드가 없고 skill 본문의 문장으로만 꺼진다(RC197 · RC199 · RC200 · RC208).
- 공식 쪽: 훅 하나만 끄는 길은 없다(문서 명시). 플러그인 하나를 끄는 환경 변수는 문서에 없다. 플러그인 통째 끄기는 설정의 `enabledPlugins` 에 `false` 이고 명령은 `claude plugin disable`(범위 user · project · local), 한 번 실행에만 끄려면 `--settings`(「This session only」), 도는 세션에는 `/reload-plugins` 나 새 세션 뒤에 닿는다(조사 20 · 본체 1차 확인).
- 공식 쪽 값 받기: `plugin.json` 의 `userConfig`(종류 string · number · boolean · directory · file). 민감하지 않은 값은 사용자 설정의 `pluginConfigs` 에 저장되고, skill · agent 본문에 `${user_config.KEY}` 로 글자 치환되며 훅 프로세스에는 `CLAUDE_PLUGIN_OPTION_<KEY>` 로 실린다. Bash 도구로 도는 스크립트에 환경 변수로 실린다는 문장은 없다(조사 20 · 본체 1차 확인).
- 플러그인 경로 변수: 「The variables aren't present in the environment of commands Claude runs through the Bash tool」 — skill 본문에 `${...}` 로 써서 글자 치환으로 받는다. Read 로 여는 보조 파일 안의 치환은 문서에 없다(조사 20 · 본체 1차 확인).
- 샌드박스: 샌드박스된 Bash 의 기본 쓰기 자리는 작업 폴더 · 임시 폴더 · 더한 폴더다. `~/.claude` 는 「most of its contents」 가 보호 경로이고 `allowWrite` 로도 풀리지 않는다. `~/.claude/plugins/data` 가 거기 드는지는 문서에 없다. 훅은 샌드박스 밖에서 돈다(조사 20 · 본체 1차 확인).
- 샌드박스를 켠 세션의 쓰기는 재지 못했다 — 샌드박스를 켠 별도 세션 셋(끔 · 켬 · 쓰기 허용 더함)을 띄워 재려 했으나 이 세션의 권한 판정이 거절했다. 우회하지 않았다.
- 공유 파일의 배송 꼴은 폴더가 아니라 파일마다 다르다 — 링크 43개 밖에 글자 사본(표시 줄 `copy-of:`)으로 실리는 정본이 있고(gc · killswitch · python 의 파일과 codex 의 세 파일 · 리뷰어 agent 정의 셋), 쉬운 말 블록은 SKILL.md 10개에 끼워 실린다. `shared/tests` 와 `tools/` 는 실리지 않는다(RC225–RC237).
- 판 올림 기록: 링크 · 사본으로 실리는 정본이 바뀌면 받는 플러그인을 올린 기록은 일관된다. 실리지 않는 공유 파일만 바뀌었을 때는 올린 기록과 안 올린 기록이 함께 있다 — 같은 계획 문서 안에도 둘 다 있다(RC241 · RC242 · RC243). 그 규칙을 적은 규칙 파일이나 락은 없다(RC239).
- 옆 설계문서: 끝맺음 절차 파일은 옆 로드맵의 어느 예약에도 없다. 그 파일을 고칠 일 둘(분해 승인 화면에 지시 원문 범위 보이기 · 분해 전에 원자료 파일 만들기)을 R2 로 넘기며 「예약에 더하거나, 그 파일을 함께 고치는 앞단 로드맵(B13)과 나눈다」 로 두 길을 남겼다(RC260 · RC271).
- 옆 설계문서: 로드맵이 아예 없는 일의 자리는 정하지 않고 R2 로 미뤘다. 단순 작업은 언제나 어떤 로드맵 폴더의 `jobs/` 아래다(RC245 · RC246 · RC247). 원자료 사본은 출처와 바이트가 같아야 하고 비밀값에 대한 문장은 없다(RC250).
- 옆 로드맵의 첫 에픽은 PR 셋으로 나뉘어 순서대로 머지되고 계획마다 spec-distill 의 판과 CHANGELOG 를 올린다(RC267).

- 웹 1차 확인(본체 · 2026-11-14 · code.claude.com/docs/en/plugins-reference): Bash 도구 환경에 플러그인 경로 변수가 없다는 문장 · 변수가 풀리는 자리 표(훅 명령 · skill 본문) · 데이터 폴더의 경로와 수명 · userConfig 의 저장과 읽는 길 · 종류 다섯 · defaultEnabled — 원문 그대로 있다
- 웹 1차 확인(본체 · 2026-11-14 · code.claude.com/docs/en/hooks): 「There is no way to disable an individual hook while keeping it in the configuration.」 · disableAllHooks 의 우선순위와 `--settings` 로 한 번 실행에만 끄기 · 플러그인 훅은 「When plugin is enabled」 — 원문 그대로 있다
- 웹 1차 확인(본체 · 2026-11-14 · code.claude.com/docs/en/sandboxing): 기본 쓰기 자리 · 보호 경로의 `~/.claude` 줄 · 「If you add an `allowWrite` entry or an `Edit` allow rule that covers one of these paths, the protection still applies.」 · 훅은 샌드박스 밖 · 샌드박스 밖 재시도와 `allowUnsandboxedCommands` — 원문 그대로 있다. `~/.claude/plugins` · `plugins/data` 는 그 절에 없다
- 웹 1차 확인(본체 · 2026-11-14 · plugins/cli-reference · plugins/loading · settings): 끄기 명령의 옵션 · `enabledPlugins` 출처의 우선순위와 `flag` 행 「This session only」 · 「Changes to settings or to disk don't reach this layer until you run `/reload-plugins` or start a new session.」 · worktree 의 로컬 설정 파일은 본 체크아웃 것 · `--settings` 는 한 세션이고 파일에 쓰지 않는다 — 원문 그대로 있다. 플러그인 하나를 끄는 환경 변수는 세 페이지에 없다
- 확인 못 함: 사용자 · 프로젝트 설정의 disableAllHooks 가 플러그인 훅까지 끄는지 — 조사 20 은 설정 참조 문서의 문장을 인용했으나 본체의 재확인은 그 항목을 요약으로만 받았고 hooks 문서에는 그 문장이 없다
- 확인 못 함: 끄기 명령이 설정 파일에 쓰는 값의 글자(`false`) — 명령 문서에서 원문으로 받지 못했다. loading 문서는 「`"<name>@<marketplace>": true` or `false` under `enabledPlugins`」 까지 적는다
- 확인 못 함: 샌드박스를 켠 세션에서 공식 데이터 폴더에 쓸 수 있는지(실측 거절) · `!` 사전 실행 줄과 Read 로 여는 보조 파일 안의 변수 치환(문서에 없음)

- 대체됨: 조사 14 의 「`shared/` 의 gc · killswitch · python · style · tests 와 레포 루트의 `tools/` 는 링크 대상이 아니다(설치본에 링크로 실리지 않는다)」 를 「실리지 않는다」 로 읽은 것 → gc · killswitch · python 의 파일과 쉬운 말 블록은 글자 사본으로 실린다. 실리지 않는 것은 `shared/tests` 와 `tools/` 다 (조사 18)
- 대체됨: 조사 14 의 「Bash 에서 그 폴더 아래에 쓰는 쓰기가 성공했다」 가 어느 세션에서나 통한다는 읽기 → 그 실측은 샌드박스를 켜지 않은 세션의 값이고, 샌드박스된 Bash 의 기본 쓰기 자리에 그 폴더는 없다 (조사 16 · 조사 20)

- 확인 RC185 — 미확인 — shared/killswitch/kill_switch_active.py#def kill_switch_active — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC186 — 확인 — shared/entry/entry_preflight.py#def switch_name — 이 스크립트를 부르는 SKILL 의 이름 아홉은 일치한다 — 보고가 적은 「여덟」 은 틀렸다(아홉). 읽는 변수는 다시 읽지 않았다
- 확인 RC187 — 미확인 — shared/python/devbrew-python.sh#kill_switch_active() — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC188 — 미확인 — shared/codex/detect_codex.sh#CODEX_KILL_SWITCH_VAR — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC189 — 확인 — plugins/project-init/hooks/hooks.json#PostToolUse — 추적되는 훅 폴더 파일은 project-init 의 둘뿐이고(테스트 fixture 제외) 네 plugin.json 에 hooks 키가 없다
- 확인 RC190 — 미확인 — plugins/project-init/hooks/post-tool-use.py#kill_switch_active("project-init", "post-tool-use", "PostToolUse") — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC191 — 미확인 — plugins/spec-distill/README.md#「스위치 목록」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC192 — 미확인 — plugins/spec-distill/scripts/review_entry.py#def disabled_reason — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC193 — 미확인 — plugins/spec-distill/scripts/control_plane.py#kill_switch_active("spec-distill", "statusline") — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC194 — 미확인 — plugins/spec-distill/scripts/ledger_sweep.py#def disabled — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC195 — 미확인 — plugins/spec-distill/scripts/review_entry.py#GONE_TOKENS — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC196 — 미확인 — plugins/spec-distill/skills/spec-review/SKILL.md#codex-gate — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC197 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#DEVBREW_SPEC_DISTILL_DISABLE_RECRITIC — 실행 코드(테스트 밖 .py · .sh · .js · .conf · .json)에서 이 이름을 읽는 자리 0건 — skill 본문의 문장으로만 꺼진다
- 확인 RC198 — 미확인 — plugins/spec-distill/README.md#DEVBREW_SPEC_DISTILL_DISABLE_WEB — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC199 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#DEVBREW_SPEC_DISTILL_DISABLE_WORKTREE — 실행 코드(테스트 밖 .py · .sh · .js · .conf · .json)에서 이 이름을 읽는 자리 0건 — skill 본문의 문장으로만 꺼진다
- 확인 RC200 — 확인 — plugins/spec-distill/skills/reviewing-brief/SKILL.md#DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW — 실행 코드(테스트 밖 .py · .sh · .js · .conf · .json)에서 이 이름을 읽는 자리 0건 — skill 본문의 문장으로만 꺼진다
- 확인 RC201 — 확인 — plugins/spec-distill/skills/pm-interview/references/saturation.md#「상한 값」 — 주장과 일치 — 본체가 그 절을 직접 읽었다(16–22행)
- 확인 RC202 — 미확인 — plugins/spec-distill/skills/reviewing-brief/SKILL.md#DEVBREW_SPEC_DISTILL_SKIP_VC_ONCE — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC203 — 미확인 — plugins/spec-distill/scripts/state_path.py#def resolve_session_id — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC204 — 미확인 — shared/docreview/scripts/docreview_config.py#ENV — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC205 — 미확인 — plugins/quality-gates/README.md#DEVBREW_QUALITY_GATES_DISABLE=1 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC206 — 확인 — plugins/quality-gates/scripts/qg-gc.py#kill_switch_active("quality-gates", "qg-gc") — 요약 줄은 print 로 stdout 에 내고(127–128행) README 407행은 「stderr로」 라고 적는다 — 어긋남은 주장 그대로. 나머지는 다시 읽지 않았다
- 확인 RC207 — 미확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#DEVBREW_QUALITY_GATES_DISABLE_CODEX=1 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC208 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1 — 실행 코드(테스트 밖 .py · .sh · .js · .conf · .json)에서 이 이름을 읽는 자리 0건 — skill 본문의 문장으로만 꺼진다
- 확인 RC209 — 미확인 — shared/test-selection/run-test-selection.sh#adapter_usable — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC210 — 미확인 — plugins/quality-gates/scripts/e2e-state.sh#killed_by_switch — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC211 — 미확인 — plugins/quality-gates/scripts/publish-comment.sh#「kill switch — 어떤 gh 호출보다 먼저」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC212 — 확인 — plugins/quality-gates/scripts/artifact_max_rounds.sh#DEVBREW_QUALITY_GATES_CRITIQUE_MAX_ROUNDS — 끄기 변수(DISABLE_CRITIQUE)를 읽는 실행 코드는 artifact_commit.sh 하나다. README 에 이름이 없다는 부분은 다시 보지 않았다
- 확인 RC213 — 미확인 — plugins/quality-gates/scripts/doc_paths.py#ENV_KEY — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC214 — 확인 — shared/docreview/scripts/run_docreview_codex_reviewer.sh#DEVBREW_QUALITY_GATES_DISABLE_WEB — 실행 코드에서 이 이름을 읽는 자리는 이 러너 하나다
- 확인 RC215 — 미확인 — plugins/quality-gates/scripts/run_codex_reviewer.sh#DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC216 — 미확인 — plugins/plugin-audit/skills/plugin-audit/SKILL.md#DEVBREW_PLUGIN_AUDIT_DISABLE=1 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC217 — 미확인 — plugins/plugin-audit/skills/plugin-audit/SKILL.md#DEVBREW_PLUGIN_AUDIT_DISABLE_CODEX=1 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC218 — 미확인 — plugins/plugin-audit/scripts/run_audit_codex_reviewer.sh#DEVBREW_PLUGIN_AUDIT_DISABLE_WEB — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC219 — 확인 — plugins/plugin-audit/scripts/audit-sandbox.sh#create-sandbox — 새 이름과 옛 이름(DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX) 둘 다 읽어 exit 3 으로 끝낸다(33–38행). CHANGELOG 문장끼리의 충돌은 다시 보지 않았다
- 확인 RC220 — 미확인 — plugins/plugin-audit/scripts/check-staleness.py#_REGISTRY_ENV — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC221 — 확인 — CLAUDE.md#「모든 훅에 kill switch」 — 꼴 둘과 예시 둘은 주장과 일치(71행). 다른 최상위 문서 부분은 다시 보지 않았다
- 확인 RC222 — 미확인 — plugins/quality-gates/CHANGELOG.md#「환경변수 어순을 DEVBREW_<PLUGIN>_<REST> 하나로 통일」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC223 — 미확인 — plugins/plugin-audit/scripts/check-shape-completeness.py#def _has_killswitch — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC224 — 확인 — tools/plain-language/measure_output.py#DEVBREW_PLUGINS — 테스트 · CHANGELOG 밖의 DEVBREW_ 이름 57개에 이 상수와 heredoc 구분자들이 들어 있다 — 환경 변수가 아니다
- 확인 RC225 — 확인 — plugins/spec-distill/scripts/gc_common.py## copy-of: shared/gc/gc_common.py — 두 사본 모두 일반 파일(100644)이고 표시 줄 하나를 빼면 정본과 같다
- 확인 RC226 — 확인 — plugins/project-init/scripts/kill_switch_active.py## copy-of: shared/killswitch/kill_switch_active.py — 세 사본 모두 일반 파일이고 표시 줄 하나를 빼면 정본과 같다
- 확인 RC227 — 확인 — plugins/project-init/scripts/devbrew-python.sh## copy-of: shared/python/devbrew-python.sh — 사본은 project-init 하나이고 정본과 같다 — spec-distill · quality-gates 에는 그 파일이 추적되지 않는다
- 확인 RC228 — 확인 — shared/README.md#「세 플러그인에 물리 사본으로 배포된다」 — 33행이 그렇게 적는다 — 트리의 사본은 하나라 어긋난다
- 확인 RC229 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#<!-- plain-language:begin --> — SKILL.md 10개 모두에 정본과 같은 블록이 있고 commands 파일은 0개다
- 확인 RC230 — 미확인 — shared/tests/test_plain_language_block.sh#「대상은 두 글롭에서 도출한다」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC231 — 미확인 — shared/tests/test_copy_of_contract.sh#「축 1b」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC232 — 미확인 — shared/tests/test_python_floor.sh#「축 B」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC233 — 미확인 — shared/tests/test_no_new_duplication.sh#「실제 동일성은 test_copy_of_contract.sh 의 GREEN 에 기댄다」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC234 — 미확인 — plugins/quality-gates/scripts/codex_prompt_common.py## copy-of: shared/codex/codex_prompt_common.py — 사본임은 확인했다. 「동기화 스크립트가 없다」 는 부분은 다시 찾지 않았다
- 확인 RC235 — 확인 — plugins/spec-distill/scripts/runner_common.sh## copy-of: shared/codex/runner_common.sh — codex_jsonl.py(셋) · codex_prompt_common.py(둘) · runner_common.sh(둘) · 리뷰어 agent 정의 셋 모두 일반 파일 사본이고 표시 줄을 빼면 정본과 같다
- 확인 RC236 — 확인 — shared/tests/assert.sh#「사본이 없다」 — shared/README.md 11행(「직접 source한다. 사본도 링크도 필요 없다」)과 일치. plugins 안 같은 이름 0건은 다시 세지 않았다
- 확인 RC237 — 확인 — tools/plain-language/README.md#「플러그인에 들어가지 않는다」 — tools 의 파일과 같은 이름의 추적 파일이 plugins 아래에 0건이다. 쓰는 쪽 목록은 다시 보지 않았다
- 확인 RC238 — 확인 — shared/README.md#「설치본에 들어가지 않는다」 — 주장과 일치(3행 · 10행)
- 확인 RC239 — 확인 — CLAUDE.md#「플러그인을 건드리는 모든 PR마다 bump」 — CLAUDE.md 에 shared · tools 변경과 판 올림을 잇는 문장은 없다(42행). docs 쪽 부재는 다시 찾지 않았다
- 확인 RC240 — 미확인 — shared/tests/test_changelog_integrity.sh#「구조적 정합」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC241 — 확인 — docs/superpowers/specs/2026-08-22-subagent-adjudication-contract-design.md#「배포 링크를 받는 플러그인은 bump 한다」 — 725행 · quality-gates CHANGELOG 706행은 주장과 일치. 다른 계획의 줄은 다시 읽지 않았다
- 확인 RC242 — 확인 — docs/superpowers/plans/2026-09-03-adjudication-topology.md#「두 플러그인 다 bump 한다」 — 3473행 · spec-distill CHANGELOG 2071행은 주장과 일치
- 확인 RC243 — 확인 — docs/superpowers/plans/2026-09-24-qg-recritic-swap-pr4a.md#「플러그인 표면이 아니다」 — 186행 · 같은 계획 문서(adjudication-topology) 976행 「shared/ 만 건드렸으므로 bump 없음」 은 주장과 일치. 다른 두 계획의 줄은 다시 읽지 않았다
- 확인 RC244 — 확인 — tools/suite/run-all.sh#find shared/tests plugins/*/tests — 27행 · shared/README.md 21행은 주장과 일치
- 확인 RC245 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「어느 쪽이든 과제 폴더 없이 도는 일은 없다」 — (옆 worktree 에만 있는 파일) 128행 · 155행은 주장과 일치. 692행 인용은 다시 읽지 않았다
- 확인 RC246 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「job new --roadmap <로드맵>」 — (옆 worktree 에만 있는 파일) 407행은 주장과 일치. 382 · 387행은 다시 읽지 않았다
- 확인 RC247 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「도는 로드맵이 없을 때 단순 작업을 어느 팀의 jobs/ 에 둘지」 — (옆 worktree 에만 있는 파일) 665행(받는 곳 R2) · 402행은 주장과 일치
- 확인 RC248 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「사용자가 준 것을 줄이지 않고 옮긴 한 벌이다」 — (옆 worktree 에만 있는 파일) 183행 앵커와 402행은 주장과 일치. 나머지 인용은 다시 읽지 않았다
- 확인 RC249 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「brief · audit 파일 자체를 intent/ 로 옮기는 일은 이 설계가 하지 않는다」 — (옆 worktree 에만 있는 파일) 189행은 주장과 일치
- 확인 RC250 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「바이트가 같고」 — (옆 worktree 에만 있는 파일) 575행 앵커가 실재하고 문서 전체에 「비밀」 · secret 이 든 줄이 0개다
- 확인 RC251 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「사용자 원문 절은 싣지 않는다」 — (옆 worktree 에만 있는 파일) 205행 앵커가 주장 그 문장이다. seed 에 대한 나머지 인용은 다시 읽지 않았다
- 확인 RC252 — 미확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「미룸」 표 — R2 로 가는 행 — (옆 worktree 에만 있는 파일) 665행만 보았고 나머지 행은 본체가 다시 읽지 않았다
- 확인 RC253 — 미확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「미룸」 표 — R3 · R4 · R5 · #277 로 가는 행 — (옆 worktree 에만 있는 파일) 674행(R5)만 보았고 나머지 행은 본체가 다시 읽지 않았다
- 확인 RC254 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「brief · audit 를 intent/ 에 바로 쓰기 · source_interview 키 이름」 — (옆 worktree 에만 있는 파일) 674행 · 412행은 주장과 일치
- 확인 RC255 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「앞단(framing · 인터뷰)의 이름 바꾸기」 — (옆 worktree 에만 있는 파일) 51행 앵커가 실재하고 request-framing 리터럴 0건 · pm-interview 1건이다
- 확인 RC256 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「의도 싱크로 바꾸고 따로 에픽으로 두자」 — (옆 worktree 에만 있는 파일) 696행 앵커가 실재하고 809행(받는 브랜치가 이 worktree 의 브랜치)은 주장과 일치
- 확인 RC257 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「컨텍스트 쌓기와 로드맵 잡는게 주 역할이야」 — (옆 worktree 에만 있는 파일) 723행 앵커가 실재하고 809행은 주장과 일치
- 확인 RC258 — 미확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「원자료 — 앞단(framing · 인터뷰)에서 온 사용자 말」 — (옆 worktree 에만 있는 파일) 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC259 — 미확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「Files to Modify」 — (옆 worktree 에만 있는 파일) 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC260 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「재분해 신호」 ⑥ — (옆 worktree 에만 있는 파일) 798행 ⑥ 은 주장과 일치 — 끝맺음 절차 파일이 R2 예약에 없고 「예약에 더하거나, 그 파일을 함께 고치는 앞단 로드맵(B13)과 나눈다」
- 확인 RC261 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「새 설정 키는 둘이다」 — (옆 worktree 에만 있는 파일) 421행 앵커가 실재하고 이 worktree 의 repo_defaults.py 36 · 38행(KEYS · ROADMAP_META_KEYS)은 주장과 일치
- 확인 RC262 — 미확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「skill 이름 epic-conductor 는 이 설계가 바꾸지 않는다」 — (옆 worktree 에만 있는 파일) 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC263 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「spec 승인 · 2026-11-14」 — (옆 worktree 에만 있는 파일) 870행은 주장과 일치 — 승인 줄이 문서에 있다
- 확인 RC264 — 미확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「Deferred to plan」 — (옆 worktree 에만 있는 파일) 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC265 — 미확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「등록만 하고 직접 만들지 않는다」 는 아직 정해지지 않았다 — (옆 worktree 에만 있는 파일) 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC266 — 미확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「리더 상태 브랜치를 만들고 올리는 일은 R3 다」 — (옆 worktree 에만 있는 파일) 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC267 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「크기가 커서 계획 셋으로 나눈다」 — (옆 worktree 에만 있는 파일) 428행 앵커가 실재하고 434행(계획마다 판 올림 · CHANGELOG)은 주장과 일치
- 확인 RC268 — 미확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「넘기는 곳. R2」 — (옆 worktree 에만 있는 파일) 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC269 — 미확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#「상태 칸은 없다」 — 앵커는 실재한다. ref 관찰은 본체가 다시 보지 않았다 — PR #274 · #276 이 열려 있다는 것만 따로 확인했다(조사 16)
- 확인 RC270 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#R1 의 「경로 예약」 — 두 worktree 의 roadmap.md 가 글자까지 같다. R1 블록의 줄은 다시 읽지 않았다
- 확인 RC271 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#R2 의 「경로 예약」 — 44 · 56 · 68 · 79행은 주장과 일치 — R2 예약에 설정 키 파일 · 철학 문서 · CLAUDE.md 가 있고 끝맺음 절차 파일은 없다. R3 예약에 상태 자리 스크립트가, R5 예약에 CHANGELOG 가 있다
- 확인 RC272 — 미확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「origin/main 8b7ddf4d」 — (옆 worktree 에만 있는 파일) 그 문서의 마지막 커밋이 eaff8a4f 인 것은 본체가 확인했다. 나머지 ref 관찰은 다시 보지 않았다
- 확인 RC273 — 확인 — plugins/spec-distill/dependencies.md#「claude-code | 2.1.303」 — 네 플러그인의 dependencies.md 가 같은 행을 갖는다
- 확인 RC274 — 확인 — plugins/#CLAUDE_PLUGIN_DATA — 추적 파일 전체(plugins · shared · tools)에서 0건이다
- 확인 RC275 — 확인 — plugins/spec-distill/.claude-plugin/plugin.json#userConfig — 네 plugin.json 에 userConfig · defaultEnabled 가 없다
- 확인 RC276 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#SD="${CLAUDE_PLUGIN_ROOT}" — 56행 · 109행은 주장과 일치
- 확인 RC277 — 확인 — plugins/project-init/hooks/hooks.json#「command」 — 10행의 훅 명령은 shell 꼴이고 변수를 따옴표 없이 쓴다. 공식 문서의 따옴표 권고는 본체가 다시 확인하지 않았다
- 확인 RC278 — 확인 — plugins/project-init/scripts/devbrew-python.sh#_ks_skip_has — 46행은 주장과 일치. 판정 흐름 전체는 다시 읽지 않았다
- 확인 RC279 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#「이 표가 보는 kill switch 는 DEVBREW_SPEC_DISTILL_DISABLE=1 하나다」 — 49행은 주장과 일치

### 다음 결정
OQ37: 샌드박스를 켠 세션에서 Bash 로 도는 스크립트가 공식 데이터 폴더에 쓰지 못할 때의 길 — 누가 언제 재고, 막히면 어디에 쓰는가 · 추천: 방향 유지, 설계가 먼저 잰다 · 트레이드오프: 방향 유지 = 재기 전에 정하지 않는다, 막히면 다시 묻는다 / 지금 재 본다 = 사용자가 명령을 직접 돌려야 한다 / 막히면 프로젝트 안 자리로 = 상태가 두 자리에 있을 수 있다 / 옮기지 않는다 = S22 를 되돌린다
OQ31: 끝맺음 절차 파일의 주인 — 이 일 · 옆 로드맵 · 설계에서 · 추천: 이 일이 맡는다 · 트레이드오프: 이 일 = 한 파일에 주인 하나, 이 일에 두 가지가 더 실리고 옆 로드맵 첫 에픽 뒤에만 할 수 있다 / 옆 로드맵 = 이 일은 그 파일을 그 뒤에만 고친다 / 설계에서 = 지금 정하지 않는다
OQ36: 올림 단위의 정의를 열린 질문으로 싣는가(새 사실 — 글자 사본 부류 · 어긋난 기록) · 추천: 이대로 싣는다 · 트레이드오프: 싣는다 = 설계가 정한다 / 지금 정한다 = 실리지 않는 공유 파일만 바뀌면 올리지 않는다를 지금 못 박는다

### 질문
(1) 상태를 공식 데이터 폴더로 옮기는 방향에 걸린 것 — 샌드박스를 켠 세션에서 그 폴더에 쓸 수 있는지를 문서로도 실측으로도 확정하지 못했다. 어떻게 할까: 「방향 유지, 설계가 먼저 잰다 (권장)」 · 「지금 재 본다」 · 「막히면 프로젝트 안 자리로」 · 「옮기지 않는다」
(2) 끝맺음 절차 파일을 누가 고칠까 — 옆 로드맵이 두 길을 열어 두었다: 「이 일이 맡는다 (권장)」 · 「옆 로드맵이 맡는다」 · 「설계에서 정한다」
(3) 설계로 넘길 열린 질문이 둘 늘었다(올림 단위의 정의 · 샌드박스에서의 상태 자리). 목록을 이대로 실을까: 「이대로 싣는다 (권장)」 · 「올림 단위는 지금 정한다」

### 답
→ S27 · S28 · S29

- OQ37 은 열린 채로 설계에 넘긴다(S27) — 옮기는 방향은 그대로이고, 설계 첫 걸음에서 샌드박스를 켠 세션으로 재고 막히면 대체 길을 제안해 다시 묻는다.
- 끝맺음 절차 파일은 이 일이 고치고, 옆 로드맵이 넘긴 둘(분해 승인 화면에 지시 원문 범위 보이기 · 분해 전에 원자료 파일 만들기)도 이 일이 받는다(S28). 그 둘은 옆 로드맵 첫 에픽이 머지된 뒤에만 할 수 있다. OQ31(머지 순서)은 나머지 파일(CLAUDE.md · 변경 기록 · 설정 키 파일 · 상태 자리 파일) 때문에 열린 채다.
- open_questions 다시 닫음(S29) — 열린 질문 목록은 OQ25–OQ37 이다.
- 옆 세션 메시지(R11 뒤, 2026-11-14 — 사용자 말이 아니다): 끝맺음 절차 파일 알림을 받아 그쪽 로드맵 수정 PR #279 에서 R2 의 경로 예약에 그 파일을 넣지 않았다고 알려 왔다. 본체 확인 — PR #279(OPEN · feature/roadmap-r1-reservations) · 옆 설계문서의 마지막 커밋 「d3911050 docs(spec): R1 설계문서 — 계획 1 검토의 사용자 결정 둘과 R2 넘김 셋」 · 878줄. 그 문서의 미룸 표에서 그 파일에 닿는 행은 2개이고 받는 곳은 아직 R2 로 적혀 있다 — 이 일에 에픽 번호가 생기면 알려 달라고 했다. PR #274 는 통합 리뷰 지적을 고치는 중이라 같은 파일의 「PR 과 머지」 절이 더 바뀐다고 했다(옆 세션의 말 — 본체는 확인하지 않았다).

## R12

### 지금 이해
경로 (b). 포화 판정 3 이 「아직」 이고 빈 곳 여덟 가운데 하나가 판정 2 의 빈 곳과 같다 — 닿는 결정이 OQ32 하나이고 장치가 본체 직접인 것(판정 2: 샌드박스에서의 쓰기 · 공식 스위치의 실제 동작 / 판정 3: 플러그인 끄기 뒤의 동작 실측). 본체가 혼자 다시 돌리지 않고 사용자에게 묻는다.
[spec-distill] 포화 판정 3/5: 아직 — 빈 곳 8개, 다음: 샌드박스를 켠 세션의 실측 · 조사 호출 13/60
판정자는 입력을 끝까지 읽지 못했다고 적었다 — 조사 3 · 7 은 일부, 조사 8 · 9 · 10 은 머리 줄만 읽었고, 판정에 필수인 최근 두 묶음(조사 16–20)은 전문을 읽었다.
판정자의 표시와 본체의 조사 기록이 다르다 — 조사 16(판정자: OQ31 · OQ32 를 바꿨다 / 본체: 없음) · 조사 17(판정자: OQ32 · OQ35 / 본체: OQ32) · 조사 19(판정자: OQ26 을 더 바꿨고 「넘긴 둘을 이 일이 받는가」 를 열었다 / 본체: 연 것 없음 — 그 결정은 S28 로 이미 답을 받았다) · 조사 20(판정자: OQ37 과 「Claude Code 최소 판을 두는가」 를 열었다 / 본체: OQ37). 멈춤은 판정자의 것을 따른다.
판정자가 연 것 가운데 목록에 없는 하나 — 공식 장치(설정 값 받기 등)로 옮기면 Claude Code 의존을 「기록」 에서 최소 판 강제로 바꾸는가 — 는 사용자가 종료를 고르면 OQ38 로 발급해 열린 질문에 싣는다(선택지 설명에 밝혔다).
빈 곳 여덟 가운데 셋(샌드박스 실측 · 치환 실측 · 끄기 뒤 동작 실측)은 별도 세션을 띄워야 재는 것이고, 이 세션에서 그런 실측은 권한 판정이 거절했다.
조사 호출 13/60 · 이 라운드 본체 직접 0

### 다음 결정
(새 결정 없음 — 반복 빈 곳의 처분을 묻는다) · 추천: 포화로 보고 종료 · 트레이드오프: 포화로 보고 종료 = 빈 곳 여덟을 「설계가 먼저 볼 것」 으로 싣고 결과물로 간다 / 한 번 더 조사 = 이 세션에서 할 수 있는 다섯을 조사하고 판정을 다시 받는다(실측 셋은 이 세션에서 못 한다) / 인터뷰 종료 = 판정 없이 끝낸다

### 질문
조사가 충분한지 판정이 세 번째도 「아직」 이고, 빈 곳 하나가 지난번과 겹친다. 어떻게 할까: 「포화로 보고 종료 (권장)」 · 「한 번 더 조사」 · 「인터뷰 종료」

### 답
→ S30

- 사용자가 반복 빈 곳에서 「포화로 보고 종료」 를 골랐다(S30). 끝맺음 절차로 간다.
- 판정 3 의 빈 곳 여덟은 결과물에 「설계가 먼저 볼 것」 으로 싣는다.
- OQ38 발급(열림) — 선택지 설명에 밝힌 대로 열린 질문에 더한다. 열린 질문 목록은 OQ25–OQ38 이다.

## 분해안

| 번호 | 이름 | 종류 | 의도 | 범위 | 의존 | 브랜치 | 경로 예약 | 배정 번호 | 받는 것 | 넘기는 것 | 크기 | 병렬 | 순서 이유 | 근거 | 흐름 | 산출물 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P1 | 공식 장치 실측 | 묶음 | 공식 장치(데이터 폴더 · 설정 값 받기 · 플러그인 끄기)가 devbrew 가 쓰는 방식(skill 이 Bash 로 부르는 스크립트)에서 실제로 되는지 재어 F7 설계가 쓸 사실을 남긴다 | 한다: 샌드박스를 켠 세션에서 데이터 폴더 쓰기와 쓰기 허용 설정, 작업 폴더 밖 읽기와 쓰기의 승인과 하위 agent 의 읽기, skill 본문 펜스 · 사전 실행 줄 · 보조 파일 안의 변수 치환, 플러그인 끄기 뒤 진입 skill · 훅의 동작과 반영 시점, 장치마다 필요한 Claude Code 판 / 안 한다: 스위치 · 상태를 실제로 옮기는 일 | 없음 | feature/official-device-probe | docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/official-device-probe.md | D21 · D31 · D35 · OQ12 · OQ32 · OQ37 · OQ38 · OQ39 · RC273 · RC274 · RC275 · RC276 · K10 · K11 · S1 · S13 · S27 · S30 · S33 · S38 · «cc-hooks» · «cc-plugins-cli» · «cc-plugins-loading» · «cc-plugins-reference» · «cc-sandboxing» · «cc-settings» | 없음 | 실측 표 — 장치마다 되는가 · 조건 · 필요한 판 | 작음 | F2 · F3 · F4 · F6 과 병렬 | F7 설계가 이 사실 위에서 대체 길을 정한다 | S27 · 조사 16 · 조사 20 | 조사 — 격리한 별도 세션에서 재고 표로 남긴다 | docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/official-device-probe.md |
| F1 | 앞단 이름 정하기 | 결정 | 의도 싱크 · 컨텍스트 쌓기 · 로드맵 잡기 세 단계의 호출 이름을 정해 옆 로드맵이 새 파일에 처음부터 새 이름을 쓰게 한다 | 한다: 호출 이름 셋을 사용자가 정하고 결정 기록에 남기고 옆 세션에 알린다 / 안 한다: 이름을 실제로 바꾸는 일(F5) | 없음 | 없음 | 없음 | S1 · S2 · S7 · S8 · S17 · C36 · D10 · D15 · D16 · OQ1 · OQ4 · OQ8 · OQ17 · OQ25 | 없음 | 없음 | 작음 | 모든 에픽과 병렬 | 옆 로드맵이 새 파일에 쓸 이름을 기다린다 | S2 · S8 · S17 | 없음 | 없음 |
| F2 | 덩어리 승인 화면 | 묶음 | seed 리뷰에서 저자가 고친 덩어리를 승인하는 화면을 읽기 쉽게 고친다 | 한다: 달라진 문장만 보이기, 덩어리마다 어느 지적 때문인지 보이기, 덩어리 질문 묶기, 추천 표시와 지금 규칙(저자가 승인 여부를 가르지 않는다)의 긴장 정하기 / 안 한다: 리뷰 엔진의 판정 규칙 | 없음 | feature/chunk-approval-screen | plugins/spec-distill/skills/request-framing/SKILL.md | C9 · C37 · C38 · D1 · D27 · OQ20 · OQ34 · RC22 · S1 · S21 | 없음 | 고친 덩어리 승인 규칙 | 작음 | P1 · F4 · F6 과 병렬 | 작고 독립이며 F3 과 같은 파일이라 먼저 끝낸다 | S21 | 없음 | 없음 |
| F3 | 원자료 정본 사슬 | 묶음 | 사용자가 준 원자료를 줄이지 않은 글이 정본이 되고, framing 뒤의 모든 단계가 seed(모델이 줄인 글)가 아니라 그 원자료를 사용자의 말로 읽는다 | 한다: 원자료를 찾는 길을 한 곳에 두기(새 모듈), framing 이 사용자의 말을 적는 모든 길의 비밀값 가리기, 고른 선택지 문장과 직접 쓴 말의 구분, 원문 절의 구분 줄, 인터뷰가 원자료 읽기, 인터뷰 결과물의 사용자 원문 첫 칸(원문 절과 질문 전체 절)과 리뷰 정답 출처(결과물 리뷰 기준과 설계문서 리뷰 기준), 끝맺음이 비밀값으로 보이는 값에서 멈추기, seed 가 맡을 일과 seed 문법, framing 에서 다른 다음 단계로 바로 가는 길, CLAUDE.md 없는 레포의 seed 리뷰 재료 / 안 한다: 원자료와 결과물을 의도 폴더에 처음부터 쓰기(옆 로드맵으로 넘김 — 설계 대화의 재결정), 로드맵 없는 일 · framing 없이 시작한 일의 새 자리(옆 로드맵 둘째 에픽), 옛 기록 옮기기, 옆 로드맵의 생성기 고치기 | F2 | feature/raw-source-canon, feature/raw-source-readers | plugins/spec-distill/scripts/raw_source.py, plugins/spec-distill/skills/request-framing/SKILL.md, plugins/spec-distill/templates/interview-seed-audit-template.md, plugins/spec-distill/templates/interview-seed-template.md, plugins/spec-distill/scripts/seed_body.py, plugins/spec-distill/scripts/build_seed_inline_blob.py, plugins/spec-distill/references/docreview-profiles/seed.md, plugins/spec-distill/skills/pm-interview/SKILL.md, plugins/spec-distill/skills/pm-interview/references/seed-input.md, plugins/spec-distill/skills/pm-interview/references/finishing.md, plugins/spec-distill/skills/pm-interview/references/state-file.md, plugins/spec-distill/skills/pm-interview/references/steelman.md, plugins/spec-distill/agents/coverage-mapper.md, plugins/spec-distill/agents/blind-spot-prober.md, plugins/spec-distill/templates/interview-brief-template.md, plugins/spec-distill/scripts/check_verbatim_coverage.py, plugins/spec-distill/scripts/build_brief_bundle.py, plugins/spec-distill/references/docreview-profiles/brief.md, plugins/spec-distill/references/docreview-profiles/design-doc.md, plugins/spec-distill/skills/reviewing-brief/SKILL.md | C37 · C38 · D1 · D2 · D3 · D11 · D12 · D13 · D25 · OQ2 · OQ5 · OQ16 · OQ18 · OQ27 · OQ28 · OQ29 · OQ30 · OQ31 · OQ35 · RC1 · RC2 · RC4 · RC10 · RC11 · RC124 · RC126 · RC127 · RC128 · RC129 · RC247 · RC249 · RC250 · RC254 · K1 · K2 · K4 · K5 · K12 · K14 · K18 · S1 · S3 · S4 · S5 · S16 · S19 · «anthropic-context-eng» · «github-sensitive-data» · «pew-survey» | 옆 로드맵의 생성기가 기대는 기록 파일 경계 줄과 도출 규칙(이 로드맵 밖 — 읽기만 하고 깨지 않는다) | 원자료를 읽는 뒤 단계 · 원자료를 찾는 모듈 · seed 의 새 역할 | 큼 | F4 · F6 과 병렬 | 옆 로드맵을 기다리지 않고 읽는 쪽부터 고친다 — 둘째 계획(인터뷰와 결과물 리뷰 쪽)은 첫째 계획의 PR 이 머지된 뒤다 | S3 · S5 · S16 | 없음 | 없음 |
| F4 | 앞단의 끝 | 묶음 | 앞단의 끝이 넘김 글을 짧게 쓰고, 작은 일에서 건너뛴 조사 · 리뷰를 검사가 받아 사용자에게 보인다 | 한다: 끝맺음 절차 파일 고치기(넘김 글은 짧게 · 자세한 지시는 파일 경로로 · superpowers 가 없을 때의 끝 게이트), 머지된 PR #274 의 재리뷰가 남긴 잔여 셋 고치기(질문이 떠 있는 동안 손으로 머지됐거나 gh 가 실패로 끝났는데 실제로는 머지된 PR 이 「머지하지 않았다」 로 읽히고 origin 을 받지 않는다 · 취소가 머지 요청이 나간 직후에 닿으면 판결 줄이 없어 「머지하지 않았다」 로 읽는데 실제로는 머지됐을 수 있다 · 경로 판정이 「값의 출처」 줄을 사용자에게 한 번 더 보인다), 「모델 판단으로 건너뜀 — 이유」 를 구조 검사가 받고 승인 화면 앞에서 보이기 / 안 한다: 단계 나누기와 이름 바꾸기(F5), 작은 일을 리더로 넘기기(F5), 옆 로드맵이 넘긴 넷(F5), PR #274 가 더한 「PR 과 머지」 절을 잔여 셋 밖에서 다시 짜기 | 없음 | feature/front-stage-exit | plugins/spec-distill/skills/pm-interview/references/finishing.md, plugins/spec-distill/scripts/check_brief.py, plugins/spec-distill/skills/pm-interview/SKILL.md, plugins/spec-distill/skills/pm-interview/references/saturation.md, plugins/spec-distill/skills/reviewing-brief/SKILL.md, plugins/spec-distill/references/brief-handoff.md | C37 · C38 · D1 · D2 · D4 · D6 · D12 · D26 · D32 · D41 · D42 · OQ19 · OQ31 · OQ35 · RC5 · RC7 · RC8 · RC9 · RC64 · RC132 · RC260 · RC267 · RC271 · K2 · K3 · K15 · K23 · S1 · S4 · S20 · S28 · S37 · S39 · S40 · «cc-memory» · «fowler-semantic-conflict» | 없음 | 고친 끝맺음 절차 · 건너뜀을 받는 구조 검사 | 중간 | P1 · F2 · F3 · F6 과 병렬 | 끝맺음 파일의 주인이 이 일로 정해졌다 — 옆 로드맵을 기다리지 않는다 | S20 · S28 | 없음 | 없음 |
| F5 | 앞단 다시 짜기 | 묶음 | 앞단 skill 글을 줄이고, 인터뷰를 컨텍스트 쌓기와 로드맵 잡기 두 단계로 나누고, F1 이 정한 이름으로 바꾼다 | 한다: 이유 · 이력 설명 · 낡은 서술 · 옛 설계 번호 걷어내기, 단계 나누기와 단계 사이 넘김, 이름이 박힌 층(호출 이름 · 설정 키 · 설계문서 머리 키 · 파일 이름 끝 · 산출물 종류 글자 · 폴더 이름) 가운데 바꿀 것 정하기, 옛 기록을 읽는 길, major 판 올림, 작은 일을 리더로 넘기기(옆 로드맵 둘째 에픽이 받는 길을 정한 뒤), 옆 로드맵이 넘긴 넷(분해 전에 원자료 파일 만들기 · 분해 승인 화면에 지시 원문 범위 보이기 · 끝내기 커밋 범위와 PR 파일 세기에 역할 문서 넷과 HANDBOOK.md 넣기 · 로드맵 생성을 인터뷰 커밋 뒤로), 묻지 않은 다섯(확인 표시가 사용자 원문 문장에 안 붙는 것 · 라운드 꼴 고정 · 의심 게이트의 추천 봉쇄 · 조사 호출 상한 · 쉬운 말 규칙의 사용자 이름)과 에픽 넘김 줄의 「사용자 선호」 라벨, 저술 가이드를 새 코어(팀 구조)에 맞추기(F6 이 넘김 — 옆 로드맵의 팀 구조가 머지된 뒤), 철학 문서의 P8 밖에서 앞단에 닿는 문장과 낡은 서술 훑기(F6 이 넘김), F4 가 넘긴 것(에픽 넘김 글의 낡은 문장 하나 · 끝맺음 마지막 리뷰가 남긴 작은 지적들 · 인터뷰 소개 문구와 종료 조건 문장이 건너뜀을 말하지 않는 것 — 할지는 설계 대화에서 다시 묻는다), 나눈 두 단계 모두가 원자료를 읽게 하기(F3 이 넘김) / 안 한다: 옛 기록 파일 옮기기, 옆 로드맵이 예약한 파일을 순서 맞추기 없이 고치기 | F1, F3, F4, F6 | feature/front-stage-restructure | plugins/spec-distill/skills/request-framing/SKILL.md, plugins/spec-distill/skills/pm-interview/SKILL.md, plugins/spec-distill/skills/pm-interview/references/finishing.md, shared/tests/test_invocation_surface.sh, docs/plugin-authoring.md, docs/philosophy/devbrew-harness-philosophy.md | C36 · C37 · C38 · D1 · D2 · D4 · D5 · D8 · D10 · D12 · D15 · D16 · D29 · D32 · D41 · OQ3 · OQ25 · OQ26 · OQ31 · OQ35 · RC16 · RC17 · RC18 · RC19 · RC20 · RC122 · RC123 · RC133 · RC255 · RC260 · K6 · K7 · K8 · K9 · K13 · K16 · K17 · K23 · S1 · S2 · S4 · S8 · S17 · S28 · S37 · «anthropic-multiagent» · «cc-issue-87507» · «cc-skills» · «claude-prompting» · «cognition» | F1 의 이름 셋 · F3 · F4 가 고친 앞단 · 옆 로드맵 첫 에픽의 생성기 명령과 둘째 에픽이 정하는 새 형식 켜는 값 · 리더가 일을 받는 길(이 로드맵 밖) · F6 이 고친 규칙과 넘긴 둘 | 새 이름의 두 단계 skill · 옛 기록을 읽는 길 | 큼 | 없음 | 동작을 바꾸는 에픽이 끝난 뒤에 글 줄이기 · 나누기 · 이름 바꾸기를 한다 — 락이 의도한 변경과 회귀를 가르게 | S2 · S8 · S17 · 조사 10 | 없음 | 없음 |
| F6 | 규칙 개정 | 묶음 | CLAUDE.md · 저술 가이드 · 철학 문서에서 공식과 다른 자리 가운데 사용자가 고른 것을 공식 쪽으로 옮기고 낡은 서술을 고친다 | 한다: cost_class 를 metadata 아래로, integrity 규칙 걷어내기, skill 의 disallowed-tools 반영, plugin.json 필수 키 완화, 판 올림을 설치본 동작이 바뀔 때로(올림 단위의 정의 포함), 저술 가이드의 낡은 예시와 문법 안내, 철학 문서의 P8 밖 두 문장(integrity · cost_class 를 말하는 자리), 그 규칙을 글자로 박은 락과 감사 검사 / 안 한다: agent 의 model 키 허용(설계 대화에서 다시 정했다 — 이 로드맵은 하지 않는다), 저술 가이드를 새 코어에 맞추기(F5), 철학 문서의 앞단에 닿는 문장과 낡은 서술 훑기(F5), 원칙 P8 문장(옆 로드맵), 의존을 plugin.json 에 선언하기, kill switch 와 상태 자리(F7) | 없음 | feature/rules-toward-official | CLAUDE.md, docs/plugin-authoring.md, docs/philosophy/devbrew-harness-philosophy.md, docs/git-workflow/commit-conventions.md, shared/README.md, shared/entry/check_invocation_surface.py, plugins/plugin-audit/scripts/check-shape-completeness.py, plugins/plugin-audit/scripts/check-staleness.py, plugins/plugin-audit/skills/plugin-audit/SKILL.md, plugins/project-init/skills/project-init/SKILL.md, plugins/quality-gates/skills/artifact-critique/SKILL.md, plugins/quality-gates/skills/quality-pipeline/SKILL.md, plugins/spec-distill/skills/epic-conductor/SKILL.md, plugins/spec-distill/skills/pm-interview/SKILL.md, plugins/spec-distill/skills/request-framing/SKILL.md, plugins/spec-distill/skills/reviewing-brief/SKILL.md, plugins/spec-distill/skills/roadmap-status/SKILL.md, plugins/spec-distill/skills/spec-review/SKILL.md | C19 · C20 · C37 · C38 · D7 · D8 · D14 · D17 · D18 · D24 · D29 · D34 · D40 · OQ6 · OQ7 · OQ9 · OQ10 · OQ11 · OQ13 · OQ21 · OQ22 · OQ23 · OQ31 · OQ33 · OQ36 · OQ39 · RC14 · RC23 · RC65 · RC71 · RC73 · RC75 · RC84 · RC96 · RC100 · RC101 · RC130 · RC131 · RC138 · RC153 · RC157 · RC235 · RC237 · RC239 · RC241 · RC242 · RC243 · K9 · K19 · K21 · ST1 · ST2 · S1 · S6 · S9 · S10 · S11 · S12 · S18 · S23 · S24 · S25 · S29 · S32 · S34 · S35 · S36 · S38 · «cc-host-marketplace» · «cc-memory» · «cc-plugins-components» · «cc-plugins-dependencies» · «cc-plugins-loading» · «cc-plugins-reference» · «cc-skills» · «cc-sub-agents» · «fowler-semantic-conflict» · «google-small-cls» | 없음 | 고친 규칙 · 올림 단위의 정의 | 큼 | P1 · F2 · F3 · F4 와 병렬 | 옆 로드맵 둘째 에픽과 같은 파일이라 머지 순서를 맞춘다 | S6 · S9 · S10 · S18 · S23 | 없음 | 없음 |
| F7 | 스위치와 상태 자리 이전 | 묶음 | 플러그인을 통째로 끄는 길을 Claude Code 의 플러그인 끄기로 바꾸고 끄는 환경변수를 줄이며, 플러그인 폴더 아래의 일회용 작업 사본을 `.claude/worktrees/` 로 옮긴다 | 한다: 통째 끄기를 공식 플러그인 끄기로 바꾸기(통째 끄기 변수 넷 은퇴), 끄는 환경변수를 일곱만 남기고 스물을 은퇴시키기(첫 판은 옛 변수가 그대로 듣고 알리고 둘째 판에서 읽는 코드와 문장을 지운다), 켜진 끄기 변수를 skill 첫머리에 보이기(플러그인마다 끄기 변수 표 하나), 둘째 판에서 은퇴한 통째 끄기 변수가 켜져 있으면 계속할지 한 번 묻기, 품질 게이트와 감사의 일회용 작업 사본을 `.claude/worktrees/` 로 옮기기, 상태 자리의 규칙을 성격별 네 갈래로 CLAUDE.md 에 적기, 감사 검사에서 훅 kill switch 요건을 빼고 끄기 변수마다 읽는 코드 요건을 더하기, kill switch 은퇴 공시, 모델 판단으로 건너뛴 재비판을 리뷰 엔진이 kill switch 사유로 적는 글자 고치기(F4 가 넘김), CLAUDE.md 의 런타임 상태 · 훅 절과 감사 검사의 「모든 훅에 kill switch」 문장(F6 이 넘김), F6 의 마지막 리뷰가 남긴 작은 지적 가운데 고치기로 한 둘 / 안 한다: 실측(P1), 상태 파일을 공식 데이터 폴더나 docs 로 옮기기, 플러그인 사용자 옵션과 skill 거부 규칙 쓰기, Claude Code 최소 판 강제, 지휘 기계 상태와 지휘자의 스위트 대조 사본 옮기기(옆 로드맵) | P1, F6 | feature/official-switches-state, feature/switch-retirement | CLAUDE.md, shared/entry/entry_preflight.py, shared/killswitch/kill_switch_active.py, shared/python/devbrew-python.sh, plugins/spec-distill/switches.md, plugins/quality-gates/switches.md, plugins/plugin-audit/switches.md, plugins/project-init/switches.md, plugins/spec-distill/README.md, plugins/quality-gates/README.md, plugins/plugin-audit/README.md, plugins/project-init/README.md, plugins/spec-distill/skills/epic-conductor/SKILL.md, plugins/spec-distill/skills/pm-interview/SKILL.md, plugins/spec-distill/skills/request-framing/SKILL.md, plugins/spec-distill/skills/roadmap-status/SKILL.md, plugins/spec-distill/skills/spec-review/SKILL.md, plugins/quality-gates/skills/quality-pipeline/SKILL.md, plugins/quality-gates/skills/artifact-critique/SKILL.md, plugins/plugin-audit/skills/plugin-audit/SKILL.md, plugins/project-init/skills/project-init/SKILL.md, plugins/quality-gates/scripts/qg-worktree.sh, plugins/quality-gates/scripts/review-diff.sh, plugins/quality-gates/scripts/seal-worktree.sh, plugins/quality-gates/scripts/e2e-state.sh, plugins/plugin-audit/scripts/audit-sandbox.sh, plugins/plugin-audit/scripts/check-shape-completeness.py, plugins/plugin-audit/scripts/check-staleness.py, plugins/plugin-audit/scripts/audit-workflow.js, plugins/quality-gates/tests/test_governance_no_capability_caps.sh, shared/tests/test_entry_preflight.sh, shared/tests/test_switch_tables.sh, shared/tests/test_python_floor.sh, docs/plugin-authoring.md, plugins/spec-distill/scripts/review_entry.py, plugins/spec-distill/scripts/control_plane.py, plugins/spec-distill/scripts/ledger_sweep.py, plugins/quality-gates/scripts/qg-gc.py, plugins/quality-gates/scripts/setup-qg.sh, plugins/project-init/hooks/post-tool-use.py, shared/docreview/scripts/docreview_route.py, docs/philosophy/devbrew-harness-philosophy.md | C28 · C30 · C33 · C37 · C38 · D14 · D18 · D21 · D22 · D23 · D31 · D34 · D35 · D39 · OQ9 · OQ12 · OQ14 · OQ15 · OQ24 · OQ32 · OQ37 · OQ38 · OQ39 · RC76 · RC111 · RC114 · RC156 · RC158 · RC171 · RC179 · RC186 · RC189 · RC197 · RC199 · RC200 · RC208 · RC273 · RC274 · RC275 · RC276 · K10 · K11 · K20 · K22 · ST3 · S1 · S10 · S13 · S14 · S15 · S22 · S26 · S27 · S30 · S31 · S32 · S33 · S38 · «cc-hooks» · «cc-plugins-cli» · «cc-plugins-loading» · «cc-plugins-reference» · «cc-sandboxing» · «cc-settings» | P1 의 실측 표 · F6 이 고친 규칙 · F4 · F6 이 넘긴 둘 | 끄는 길과 상태 자리의 규칙 · 플러그인마다의 끄기 변수 표 · 진입 사전 검사가 보이는 켜진 끄기 변수 줄 | 큼 | 없음 | 실측과 규칙 개정이 먼저 있어야 무엇으로 옮길지 정한다. 둘째 계획(은퇴한 변수를 실제로 지우는 판)은 F3 의 둘째 계획과 F5 가 머지된 뒤에 시작한다 — 옛 변수를 한 판 동안 듣는 기간이 실제 기간이 되고 F5 가 다시 짠 skill 글에서 한 번만 지운다 | S13 · S14 · S22 · S26 · S27 | 없음 | 없음 |

## audit §2 대기 줄

- 포화 판정 1: 아직 — 빈 곳 4개
- 포화 판정 2: 아직 — 빈 곳 5개
- 포화 판정 3: 아직 — 빈 곳 8개
- 포화 판정 3: 사용자 판단 포화(@S30) — 반복 빈 곳

## 생성 기록

- docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/F2.md
- docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/F3.md
- docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/F4.md
- docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/F5.md
- docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/F6.md
- docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/F7.md
- docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/P1.md
- docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/roadmap.md
