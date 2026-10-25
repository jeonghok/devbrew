---
type: interview-state
seed: 없음
session_id: 2c4cd0b0-bc55-4ac6-9130-0e998a7b92e7
phase: 1
coverage:
  floor:
    root_problem:   {status: closed, evidence: "사용자 원문 @S1 · @S5 · @S10", reopened: 0, reopen_log: []}
    landscape:      {status: closed, evidence: "외부 근거 셋 처분 @S5 — 받아들임 + 의도 갈라짐도 봐야 함", reopened: 0, reopen_log: []}
    skepticism:     {status: closed, evidence: "steelman ST1 판정 @S13 — refined", reopened: 0, reopen_log: []}
    blind_spot:     {status: closed, evidence: "숨은 가정 · 실패 양식 처분 @S11", reopened: 0, reopen_log: []}
    open_questions: {status: closed, evidence: "OQ 목록 확인 @S15", reopened: 0, reopen_log: []}
  derived:
    - {name: "추천 신호가 고르는 자리에 닿는 길", rationale: "걸음 3 이 부르는 show --tasks 에 동시 가능 목록이 없다(RC1 · RC2)", status: closed, evidence: "@S8", reopened: 0, reopen_log: []}
    - {name: "한 번에 한 에픽씩 묻는 규칙과 병렬 권장의 경계", rationale: "사람 질문 단계는 규칙상 직렬(RC5)", status: closed, evidence: "@S3 · @S13", reopened: 0, reopen_log: []}
    - {name: "겹침 판정의 정의", rationale: "경로 예약 기준 · 공유 파일 제외(RC3 · RC4)", status: closed, evidence: "@S9 · @S12", reopened: 0, reopen_log: []}
    - {name: "병렬 뒤 회귀와 통합 안전망", rationale: "있는 안전망을 줄이지 않음을 보증(RC7)", status: closed, evidence: "@S7 · @S11", reopened: 0, reopen_log: []}
    - {name: "조사를 어디에 둘지와 범위 나누기", rationale: "계획 첫 과제 조사 vs spec 단계 조사(RC8 · RC9)", status: closed, evidence: "@S6", reopened: 0, reopen_log: []}
    - {name: "권장을 보이는 모양과 고를 기회", rationale: "공시 한 줄 vs 질문 · 지휘자가 만든 질문 표시", status: closed, evidence: "@S2 · @S13", reopened: 0, reopen_log: []}
    - {name: "검증 방법", rationale: "권장 줄이 실제로 나오는지 무엇으로 증명하나", status: closed, evidence: "@S14", reopened: 0, reopen_log: []}
    - {name: internal_research, rationale: "레포 주장 첫 산출(조사 1)", status: closed, evidence: "레포 주장 처분 @S13(ST1 리포 주장 11 중 확인 10) · @S11", reopened: 0, reopen_log: []}
orchestration:
  focused_dimension: null
  research_dispatches: {coverage_mapper: 1, blind_spot_prober: 1, steelman_builder: 1, repo_researcher: 2, open_researcher: 0}
  research_limit: 60
  saturation_limit: 5
  research_log:
    - {n: 5, device: repo-researcher, round: 9, batch: 5, changed: [OQ9, OQ11, OQ12], opened: [OQ11, OQ12], summary: "병렬 PR 머지 순서 규칙 없음(⑦ 있다는 전제 반증) · neighbors 는 B 결정 줄만 봐 엔진 D 줄을 놓침"}
    - {n: 6, device: repo-researcher, round: 9, batch: 5, changed: [OQ5, OQ8], opened: [OQ13, OQ14], summary: "--tasks 소비 계약 여섯 자리 · 설정 키 아홉 닫힌 집합 · 빈 값이면 상태 계산 멈춤"}
    - {n: 4, device: orchestrator, round: 9, batch: 4, changed: [OQ4], opened: [], summary: "판정 목록이 설계문서 ## 판정 에 보관됨 — 의도 대조 원천은 설계문서 하나로 족함"}
    - {n: 3, device: steelman-builder, round: 6, batch: 3, changed: [OQ9], opened: [], summary: "recommendation refined · hits 0 · 레포 주장 RC19~RC29(RC29 반증) · 웹 일곱"}
    - {n: 2, device: blind-spot-prober, round: 4, batch: 2, changed: [OQ4], opened: [OQ7], summary: "숨은 가정 여섯 · 실패 양식 다섯 · 레포 주장 RC11~RC18(전부 확인) · 웹 근거 일곱"}
    - {n: 1, device: coverage-mapper, round: 1, batch: 1, changed: [], opened: [OQ1], summary: "파생 차원 일곱 제안 · 레포 주장 RC1~RC9(전부 확인) · 웹 근거 셋(2차)"}
  saturation_log:
    - {k: 2, round: 10, verdict: not_saturated, basis: "묶음 5 가 결정 넷을 바꾸고 새 결정을 열었다", gaps: ["OQ15","OQ16","OQ17","OQ18","OQ19"], user_choice: S17}
    - {k: 1, round: 8, verdict: not_saturated, basis: "최근 두 묶음(조사 2 · 3) 모두 결정을 바꿨다", gaps: ["의도 대조 원천에 구현 중 판정 포함?(steelman)", "잇단 머지 창 사실 확정(repo)", "--tasks 소비자 전수(repo)", "near 확장의 결정 기록 시점(repo)", "공유 파일 설정 키 · 빈 값 동작(repo)", "OQ10 수단 견주기(mapper)"], user_choice: null}
  open_decisions:
    - {id: OQ1, text: "준비된 에픽이 둘 이상이고 겹치지 않을 때 지휘자가 무엇을 하나(묻기 · 공시하고 진행 · 공시만)", dimension: "권장을 보이는 모양과 고를 기회", status: resolved, resolved_by: S2}
    - {id: OQ2, text: "「병렬」 이 사람 질문 단계까지 포함하나", dimension: "한 번에 한 에픽씩 묻는 규칙과 병렬 권장의 경계", status: resolved, resolved_by: S3}
    - {id: OQ3, text: "조사 자리 규칙(설계 전 꼼꼼한 조사 · 계획 첫 과제 가벼운 다시 확인)을 이번 범위에 넣나", dimension: "조사를 어디에 둘지와 범위 나누기", status: resolved, resolved_by: S6}
    - {id: OQ5, text: "병렬 판단 신호를 어디서 얻나(show --tasks 출력에 싣기 · 절차 글만)", dimension: "추천 신호가 고르는 자리에 닿는 길", status: resolved, resolved_by: S8}
    - {id: OQ6, text: "같은 플러그인의 공유 파일(plugin.json · CHANGELOG · README)만 겹칠 때 병렬을 권하나", dimension: "겹침 판정의 정의", status: resolved, resolved_by: S9}
    - {id: OQ7, text: "premortem 의 숨은 가정 · 실패 양식을 설계 범위에 어떻게 반영하나", dimension: "blind_spot", status: resolved, resolved_by: S11}
    - {id: OQ8, text: "겹침에서 빼는 공유 파일 목록(지금 plugin.json · CHANGELOG.md · README.md 고정)을 레포마다 정하게 하나", dimension: "겹침 판정의 정의", status: resolved, resolved_by: S12}
    - {id: OQ9, text: "의심 방향(여덟 변경을 한 에픽에)을 유지 · 보완 · 전환 · 보류 중 무엇으로 하나", dimension: "skepticism", status: resolved, resolved_by: S13}
    - {id: OQ10, text: "권장 줄이 실제로 나오는지 무엇으로 증명하나", dimension: "검증 방법", status: resolved, resolved_by: S14}
    - {id: OQ11, text: "준비된 머지 명령 줄을 한 번에 하나만 내나", dimension: "병렬 뒤 회귀와 통합 안전망", status: resolved, resolved_by: S16}
    - {id: OQ12, text: "spec 리뷰 이웃 결정 노출을 진행 중인 병렬 에픽까지 넓히면 실제로 결정이 보이나", dimension: "병렬 뒤 회귀와 통합 안전망", status: resolved, resolved_by: S16}
    - {id: OQ13, text: "--tasks 출력 계약을 바꾸면 그 출력을 읽는 다른 표면도 함께 바꿔야 하나", dimension: "추천 신호가 고르는 자리에 닿는 길", status: resolved, resolved_by: S16}
    - {id: OQ14, text: "공유 파일 설정값이 없거나 비었을 때 겹침 판정의 기본 동작", dimension: "겹침 판정의 정의", status: resolved, resolved_by: S16}
    - {id: OQ15, text: "이웃 결정 노출 정규식을 엔진 D 줄까지 넓히는 범위와 B 줄 · D 줄 설계문서 수", dimension: "병렬 뒤 회귀와 통합 안전망", status: open, resolved_by: null}
    - {id: OQ16, text: "공유 파일 목록 값의 한 줄 문법(쉼표 등)과 머리말 파서의 맞춤", dimension: "겹침 판정의 정의", status: open, resolved_by: null}
    - {id: OQ17, text: "겹침 판정의 공유 파일 비대칭(_shared 가 앞 항목에만 걸림)을 이번에 고치나", dimension: "겹침 판정의 정의", status: open, resolved_by: null}
    - {id: OQ18, text: "머지 뒤 재대조에 통합 리뷰 재실행을 넣나 · 대조 기준 커밋을 남겨 낡음을 알리나", dimension: "병렬 뒤 회귀와 통합 안전망", status: open, resolved_by: null}
    - {id: OQ19, text: "새 병렬 줄이 로드맵만으로 계산되어 기계 상태 삭제 전후 같음(e2e AC17)을 지키는지 · 손 절차 1 「에픽 하나에 작업 하나」 문장 정정", dimension: "추천 신호가 고르는 자리에 닿는 길", status: open, resolved_by: null}
    - {id: OQ20, text: "머지 큐 없이 「최신 기본 브랜치 반영 필수」 규칙만 있는 레포에서 무엇을 맡기나 — D16 은 그 규칙도 들고 D19(S26)는 머지 큐만 좁혔다. 같은 좁힘(순서만 맡기고 테스트는 확인)을 적용하는 쪽이 모델 추론의 권장이다", dimension: "병렬 뒤 회귀와 통합 안전망", status: open, resolved_by: null}
    - {id: OQ4, text: "병렬로 머지될 때 앞 에픽의 의도가 뒤 머지로 갈라지거나 망가지는 것을 무엇으로 잡나(기계 검사 밖)", dimension: "병렬 뒤 회귀와 통합 안전망", status: resolved, resolved_by: S7}
trivia_escape_armed: false
user_statements:
  - id: S2
    source: chosen
    round: 1
    text: "병렬을 권하며 묻는다 (권장) — 「병렬 (권장)」 · 「차례로」 질문 하나를 띄우고 사용자가 고른다"
  - id: S3
    source: chosen
    round: 2
    text: "설계는 차례로 — 설계 대화는 한 에픽씩 하고, 계획 · 구현만 겹친다"
  - id: S4
    source: verbatim
    round: 2
    text: "뭐를 말하는거지?"
  - id: S5
    source: verbatim
    round: 2
    text: "1, 서로의 의도가 갈라지거나 망가지게 되는거도 파악할필요 있을거 같아 다른거 머지로 이전게 망가지면 안되니 기계적인거 보는거도 좋지만 "
  - id: S6
    source: chosen
    round: 3
    text: "기본으로 적는다 (권장) — 에픽마다 설계 전 꼼꼼한 조사, 계획 첫 단계는 가벼운 다시 확인"
  - id: S7
    source: chosen
    round: 4
    text: "통합 리뷰어에 더한다 (권장) — 같은 파일을 고친 앞 에픽의 설계 의도도 읽고 대조"
  - id: S8
    source: chosen
    round: 5
    text: "작업 목록 출력에 싣는다 (권장) — 지휘자가 고를 때 보는 출력에 「동시에 갈 수 있는 준비 에픽」 한 줄"
  - id: S9
    source: chosen
    round: 5
    text: "권한다 (권장) — 같은 플러그인의 공유 파일만 겹쳐도 병렬을 권하고 머지 때 판 번호를 차례로 올려 푼다"
  - id: S10
    source: verbatim
    round: 6
    text: "근데 이거도 이 레포만 고려하는게 아니라 보편적 고려해야하는거야"
  - id: S11
    source: chosen
    round: 6
    text: "다섯 모두 작게 반영 (권장)"
  - id: S12
    source: chosen
    round: 6
    text: "레포가 정한다 (권장) — 공유 파일 목록은 기본값 셋, 레포가 설정으로 바꾼다"
  - id: S13
    source: chosen
    round: 7
    text: "보완 (builder·orchestrator 추천) — 한 에픽 유지, ⑥⑦⑧은 있는 장치를 넓히거나 가리키는 한 줄, 질문은 준비 에픽 집합이 바뀔 때만 다시"
  - id: S14
    source: chosen
    round: 8
    text: "출력 테스트 + 변이 (권장)"
  - id: S15
    source: chosen
    round: 8
    text: "닫는다 (권장) — 검증 방법 말고 열린 질문 없음"
  - id: S16
    source: verbatim
    round: 9
    text: "진행"
  - id: S17
    source: chosen
    round: 10
    text: "설계로 넘기고 마친다 (권장) — 남은 세부 다섯을 brief 열린 질문으로 설계에 넘긴다"
  - id: S18
    source: chosen
    round: 10
    text: "spec 하나로"
  - id: S19
    source: verbatim
    round: 11
    text: "앞 에픽이 스펙리뷰로 넘기면 그때부터 병렬가능 스펙 설계를 한다고 보면 돼 "
  - id: S20
    source: chosen
    round: 11
    text: "고친다 — 함께 진행된 에픽 전부 (권장)"
  - id: S21
    source: chosen
    round: 11
    text: "고친다 — 있으면 그것에 맡김 (권장)"
  - id: S22
    source: chosen
    round: 11
    text: "맞다 — 그대로 둔다 (권장)"
  - id: S23
    source: chosen
    round: 11
    text: "설계에서 고친다 (권장)"
  - id: S24
    source: verbatim
    round: 12
    text: "그냥 2번으로 하자, 병렬 차례로를 판단하는 대상은 구현을 이야기하는거야 "
  - id: S25
    source: verbatim
    round: 12
    text: "1, 차례로 에서 구현은 병렬로 못해도 설계는 되는건 1번으로 가면 되겠지 "
  - id: S26
    source: chosen
    round: 12
    text: "순서만 맡기고 테스트는 확인 (권장)"
confirm_repost_count: 0
brief_review_degradations: []
---

## 풀린 입력

~~~~
지휘자(epic-conductor)가 준비된 에픽이 여럿이고 경로 예약 · 파일이 겹치지 않으면 에픽 단위 병렬 진행을 먼저 권하게 한다. 사용자 원문: 「왜 병렬진행 추천이 안온걸까」 · 「태스크별로3개 채우는건 아니더라도 에픽별로면 추천이 오는쪽이 좋을텐데」 · 「파일이 안 겹치면 병렬 권장 이긴한데 회귀나 병렬 진행으로 인한 통한은 여전히 잘해야해」 · 「작업하는겇가장 먼저에 꼼꼼히 조사도 넣어주고 놓친거 있을 수 있으니」 · 「아님 스펙 만들때 조사가 더 좋으려나」. 끝에서 끝 확인(지휘 걸음 7)으로 기본 경로를 걷는 작은 주제다.
~~~~

### 조사 1 — coverage-mapper · R1 · 묶음 1

```yaml
derived_dimensions:
  - name: "추천 신호가 지휘자에게 닿는 길 (상태 계산 출력에서 걸음 3 의 고르는 자리까지)"
    rationale: "걸음 3 이 기본으로 부르는 `show --tasks` 는 에픽마다 제목·단계·작업 상태만 내고 동시 가능 목록을 내지 않는다. 전체 보기 `show` 는 경로 예약 겹침만 낸다. 동시에 갈 수 있는 에픽은 에픽 하나를 보는 `show <로드맵> <에픽>` 에만 나온다. 그래서 지휘자가 고르는 자리에서 이 신호를 보지 못한다. 고칠 자리를 정해야 한다 — 절차 글(conducting.md)만 고칠지, 상태 계산 출력도 고칠지."
  - name: "한 번에 한 에픽씩 묻는 규칙과 병렬 권장의 경계"
    rationale: "conducting.md 걸음 3 과 손 절차 2·3 은 사람에게 묻는 단계(brainstorming·설계문서 점검·spec 승인)를 한 번에 한 에픽씩, 의존 사슬 앞쪽부터 하라고 한다. 또 다른 세션을 열라는 줄을 주지 말라고 한다. 같은 걸음은 동시에 보내기를 계획·구현 agent 에만 허용한다. 지난번 R14 · R9 가 직렬로 간 것은 이 규칙을 따른 결과다. 준비된 에픽 둘을 병렬로 권한다는 말이 무엇인지 정해야 한다. 후보는 ① 설계는 줄 세우고 계획·구현을 겹치기 ② 사용자 세션으로 넘기기(에픽 넘김 줄 — 지금은 사용자가 먼저 말할 때만 허용) ③ 규칙 자체를 고치기다. 규칙과 정면으로 부딪히는 자리다."
  - name: "겹침 판정의 정의 (경로 예약과 실제 파일, 공유 파일 제외)"
    rationale: "seed 는 「파일이 안 겹치면」이 조건이다. 그런데 상태 계산은 실제 diff 가 아니라 로드맵의 경로 예약으로 겹침을 잰다. 그리고 plugin.json · CHANGELOG.md · README.md 를 겹침에서 뺀다(SHARED_BASENAMES). 같은 플러그인을 고치는 에픽 둘은 이 세 파일에서 반드시 충돌한다. 예약이 없거나 넓은 에픽을 어떻게 볼지, 공유 파일 충돌을 정보로 둘지 권장을 낮출지, 의존 판정(_reachable)만으로 충분한지 정해야 한다."
  - name: "병렬 뒤 회귀와 통합 안전망 (줄이지 않음을 보증하기)"
    rationale: "사용자 단서는 「회귀나 병렬 진행으로 인한 통한은 여전히 잘해야해」다. 지금 있는 장치는 스위트 대조(merge_check), 통합 리뷰(review-pack 과 인계 절), 머지 뒤 열린 브랜치에 기본 브랜치 합치기, 먼저 머지되는 쪽이 낮은 번호인 릴리스 번호, 공유 스위트 잠금이다. 병렬 권장이 이 장치를 건너뛰지 않음을 수용 기준으로 묶을지, 병렬 수가 늘 때 스위트 잠금 줄이 병목이 되는지(걸음 1 이 병목으로 이미 적음) 다뤄야 한다."
  - name: "조사를 어디에 둘지 (계획 첫 과제의 전수 조사 · spec 단계 조사 · 인터뷰 조사)"
    rationale: "사용자 원문은 「작업하는것 가장 먼저에 꼼꼼히 조사」와 「아님 스펙 만들때 조사가 더 좋으려나」 사이에서 갈린다. 레포에는 이미 조사 장치가 셋 있다. 에픽 넘김 줄의 '있는 것 검토' 절(brainstorming 입력), R10 이 인터뷰에 연 조사 열기, 계획 틀(conductor-dispatch.md)이다. 계획 틀에는 첫 과제로 조사를 넣는 조항이 없다. 기본값을 어디에 둘지, 둘 다면 중복인지, superpowers 를 고치지 않는다는 제약 아래 어느 표면이 맡을지 정해야 한다. 병렬 권장과는 다른 결정이라 seed 하나에 묶어 둘지(범위 나누기)도 이 차원에서 정한다."
  - name: "권장을 보이는 모양과 사용자가 고를 기회"
    rationale: "지난번 실패의 핵심은 판단을 알리지 않아 사용자가 고를 기회를 잃은 것이다. 이 판단이 한 줄 공시인지(준비된 에픽 전부 · 겹침 · 「병렬 (권장)」), 아니면 AskUserQuestion 게이트인지 정해야 한다. 정할 것은 셋이다. brainstorming 메시지에 지휘 소식을 얹지 말라는 규칙과의 관계, 지휘자가 만든 선택지임을 표시하는 관례, 권장 수 3(parallel_default)과의 관계다. 권장 수 3 은 큰 작업 수이고 에픽 수가 아니다."
  - name: "검증 방법 (끝에서 끝 확인과 락의 이빨)"
    rationale: "seed 는 이 주제를 지휘 걸음 7 의 끝에서 끝 확인으로 걷는다고 한다. 권장 줄이 실제로 나오는지 무엇으로 증명할지 정해야 한다. 후보는 상태 계산 출력 테스트나 절차 문서 문구 락이다. 문구 락은 헤더만으로 통과하거나 변이 없이 공허하게 통과하기 쉽다(레포 교훈). 받는 쪽(지휘 SKILL·conducting.md)과 같은 상태를 읽는 표면(control_plane show·상태줄)이 함께 바뀌어야 하는지도 이 차원이다."
neglect_flag: false
neglected_dimensions: []
confidence: 0.8
evidence:
  - url: "https://www.morphllm.com/claude-code-worktrees"
    supports: current
    claim: "worktree 격리는 작업 중 충돌을 막지만 같은 파일을 고친 변경은 머지 때 그대로 충돌한다 — 파일 겹침 판정과 머지 단계 안전망이 따로 필요하다."
    touches: []
    decides: []
  - url: "https://www.verdent.ai/guides/how-to-run-parallel-claude-code-agents"
    supports: current
    claim: "병렬 agent 는 겹치지 않는 코드 영역에 나눠 주고, 머지는 빠른 것부터 차례로 하며, 어느 브랜치가 어느 모듈을 건드렸는지 기록하라고 권한다(3~4 agent 이상에서 특히). 병렬이 안전해 보였던 일이 머지 충돌로 더 오래 걸린 사례도 보고한다."
    touches: []
    decides: []
  - url: "https://dev.to/jcamarate/claude-code-worktrees-parallel-agents-without-the-conflicts-3fnl"
    supports: both
    claim: "세션마다 맥락이 따로라 한 세션의 결정(이름 규칙 등)이 다른 세션에 보이지 않는다 — 병렬 에픽 사이 이음매 리뷰가 필요하다는 근거. 외부 블로그(secondary)다."
    touches: []
    decides: []
repo_claims:
  - {id: RC1, path: "plugins/spec-distill/scripts/control_plane.py", anchor: "def tasks_output", line: 383, claim: "걸음 3 이 기본으로 부르는 `show --tasks` 출력은 에픽마다 `<id> <제목> — <단계>\\t<작업 상태>` 만 내고, 동시 가능 목록과 겹침 정보는 싣지 않는다.", touches: [], decides: []}
  - {id: RC2, path: "plugins/spec-distill/scripts/control_plane.py", anchor: "def epic_view — row(\"동시에 갈 수 있는 에픽\", ...)", line: 1219, claim: "「동시에 갈 수 있는 에픽」은 에픽 하나를 보는 `show <로드맵> <에픽>` 에서만 나온다. 전체 보기 show_text(322행~)는 「경로 예약 겹침(정보)」만 낸다.", touches: [], decides: []}
  - {id: RC3, path: "plugins/spec-distill/scripts/roadmap_status.py", anchor: "def parallel_with", line: 1014, claim: "동시 가능 판정은 끝나지 않은 블록 가운데 의존 도달성(_reachable)이 어느 쪽으로도 없는 것이다. 경로 예약 겹침은 막지 않고 정보로만 붙는다. 단계(준비인지, 사람 질문 단계인지)는 따지지 않는다.", touches: [], decides: []}
  - {id: RC4, path: "plugins/spec-distill/scripts/roadmap_status.py", anchor: "SHARED_BASENAMES = (\"plugin.json\", \"CHANGELOG.md\", \"README.md\")", line: 60, claim: "경로 예약 겹침에서 plugin.json · CHANGELOG.md · README.md 를 뺀다. 같은 플러그인을 고치는 병렬 에픽이 반드시 충돌하는 자리가 겹침 판정에 보이지 않는다(NOTICE 는 충돌을 머지 때 푼다고 밝힌다).", touches: [], decides: []}
  - {id: RC5, path: "plugins/spec-distill/references/conducting.md", anchor: "### 3. 다음 일 고르기와 보내기 — 「사람에게 묻는 단계(...)는 이 세션이 한 번에 한 에픽씩, 의존 사슬의 앞쪽부터 직접 한다. 사용자에게 다른 세션을 열라는 줄을 주지 않는다」", line: 34, claim: "준비된 에픽의 설계 단계는 규칙상 직렬이다. 동시에 보내기는 같은 걸음 보내기 불릿(40행)의 계획·구현 agent 에만 걸린다. 지난번에 병렬 권장이 오지 않은 직접 원인이 이 규칙이다. 판단을 알리라는 조항도 없다.", touches: [], decides: []}
  - {id: RC6, path: "plugins/spec-distill/references/conducting.md", anchor: "병렬 권장 수: 세는 것은 지휘자가 돌리는 큰 작업(계획 · 구현 담당자 · 수리 구현처럼 오래 도는 일)이다", line: 19, claim: "권장 수 3(parallel_default)은 큰 작업 agent 수다. 에픽 단위 병렬 권장과 단위가 다르다. 걸음 1 은 병목을 공유 스위트 잠금 줄 · 같은 파일 겹침 · 지휘자의 옮김 부하라고 적는다.", touches: [], decides: []}
  - {id: RC7, path: "plugins/spec-distill/references/conducting.md", anchor: "### 5. 머지 전 확인 — 스위트 대조 · 통합 리뷰 · 리뷰 뒤 반영", line: 55, claim: "병렬 뒤 회귀 안전망(merge_check 스위트 대조, review-pack 통합 리뷰와 인계 절, 걸음 6 의 열린 브랜치 합치기와 재대조)은 이미 있다. 병렬 권장은 이것을 줄이지 않는다는 보증이 범위다.", touches: [], decides: []}
  - {id: RC8, path: "plugins/spec-distill/references/conductor-dispatch.md", anchor: "2. **흐름.** 고른 흐름과 그 이유 한 줄(기본은 설계 흐름), 조사 · 결정 흐름이면 산출물 경로.", line: 8, claim: "하위에게 보내는 틀에 계획의 첫 과제로 전수 조사를 넣는 조항이 없다. 이 파일에서 '조사'는 흐름 종류로만 나온다. 이미 있는 조사 자리는 epic-handoff.md 의 '있는 것 검토' 절(brainstorming 입력)이다.", touches: [], decides: []}
  - {id: RC9, path: "plugins/spec-distill/references/epic-handoff.md", anchor: "있는 것 검토 절(레포 안에 이미 있는 것을 먼저 찾아 쓰고, ...)", line: 7, claim: "spec 을 만드는 단계(brainstorming)에는 이미 조사 장치가 있다. 「스펙 만들때 조사」 쪽을 고르면 새 장치가 아니라 이 절을 넓히는 일이 된다. 여기에 R10 인터뷰 조사 열기까지 있어 조사 자리가 여럿이다.", touches: [], decides: []}
```

## R1

### 지금 이해
지금 지휘 절차는 사람에게 묻는 단계를 한 번에 한 에픽씩 하고, 동시에 보내는 것은 계획 · 구현 담당자뿐이며, 그 판단을 사용자에게 알리는 자리가 없다. 동시에 갈 수 있는 에픽 목록은 에픽 하나를 볼 때만 나오고 걸음 3 이 쓰는 출력에는 없다.
조사 호출 1/60 · 이 라운드 본체 직접 1
- 확인 RC1 — 확인 — plugins/spec-distill/scripts/control_plane.py#def tasks_output — 주장과 일치
- 확인 RC2 — 확인 — plugins/spec-distill/scripts/control_plane.py#def epic_view — row("동시에 갈 수 있는 에픽", ...) — 주장과 일치(:1220-1222)
- 확인 RC3 — 확인 — plugins/spec-distill/scripts/roadmap_status.py#def parallel_with — 주장과 일치
- 확인 RC4 — 확인 — plugins/spec-distill/scripts/roadmap_status.py#SHARED_BASENAMES — 주장과 일치(:60)
- 확인 RC5 — 확인 — plugins/spec-distill/references/conducting.md#### 3. 다음 일 고르기와 보내기 — 주장과 일치(:34 · :40)
- 확인 RC6 — 확인 — plugins/spec-distill/references/conducting.md#병렬 권장 수 — 주장과 일치(:19)
- 확인 RC7 — 확인 — plugins/spec-distill/references/conducting.md#### 5. 머지 전 확인 — 주장과 일치
- 확인 RC8 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#2. **흐름.** — 주장과 일치(:8)
- 확인 RC9 — 확인 — plugins/spec-distill/references/epic-handoff.md#있는 것 검토 — 주장과 일치(:7)

### 다음 결정
OQ1: 준비된 에픽이 둘 이상이고 겹치지 않을 때 지휘자가 무엇을 하나 · 추천: 병렬을 권하며 묻는다 · 트레이드오프: 묻기 = 사용자가 고르지만 질문 하나 늘어남 / 공시하고 진행 = 질문 없음, 원치 않으면 멈춰야 함 / 공시만 = 지금처럼 직렬, 사용자가 말해야 병렬

### 질문
(b) 판단 — 준비된 에픽이 둘 이상이고 파일이 겹치지 않을 때 지휘자가 어떻게 하면 좋을까요?

### 답
→ S2

## R2

### 지금 이해
S2 로 「병렬 (권장)」 질문을 띄우기로 했다. 지난 R14 · R9 에서는 사용자가 「병렬로 할건?」 이라고 물은 뒤 이 세션이 두 에픽의 설계 질문을 번갈아 묻고 계획 · 구현 담당자를 동시에 돌렸고, 끝까지 문제없이 머지됐다(#254 · #255 · #256). 외부 근거 셋(2차): 병렬은 겹치지 않는 영역에 나누고 빠른 것부터 차례로 머지 · worktree 는 머지 충돌을 막지 못한다 · 세션마다 맥락이 따로라 이음매 리뷰가 필요하다 — 지금 장치(스위트 대조 · 통합 리뷰 · 머지 뒤 합치기)와 같은 쪽이다.
조사 호출 1/60 · 이 라운드 본체 직접 0

### 다음 결정
OQ2: 「병렬」 이 사람 질문 단계까지 포함하나 · 추천: 설계 질문도 번갈아, 계획 · 구현은 동시에 · 트레이드오프: 번갈아 = 빠르지만 한 세션에서 두 에픽 질문이 섞임 / 설계는 차례로 = 질문이 안 섞이나 앞 에픽 설계가 끝나야 다음이 시작 / 다른 세션 = 섞이지 않으나 지휘가 둘로 갈림
OQ3: 조사 자리 규칙을 이번 범위에 넣나 · 추천: 넣는다(설계 전 꼼꼼한 조사 + 계획 첫 과제는 가벼운 다시 확인) · 트레이드오프: 넣음 = 일이 조금 커짐 / 따로 = 다음 일 / 넣지 않음 = 지금처럼 지휘자 재량
landscape 처분: 외부 근거 셋을 받아들이나

### 질문
(b) 판단 · 묶음 셋 — OQ2 · OQ3 · 외부 근거 처분

### 답
→ S3 · S4 · S5

## R3

### 지금 이해
S3 으로 병렬은 계획 · 구현만 겹치고 설계 대화는 한 에픽씩 하기로 했다. S5 로 외부 근거를 받아들였고, 기계 검사 밖에서 앞 에픽의 의도가 뒤 머지로 갈라지거나 망가지는 것도 잡아야 한다는 새 요구가 나왔다(OQ4 — 다음 라운드). S4 는 OQ3 을 이해하지 못했다는 답이라 OQ3 을 풀어 다시 묻는다(되묻기).
조사 호출 1/60 · 이 라운드 본체 직접 0
밀린 질문 1개 — OQ4: 의도 갈라짐을 무엇으로 잡나

### 다음 결정
OQ3: 에픽마다 「설계 전 꼼꼼한 조사 · 계획 첫 과제는 가벼운 다시 확인」 을 지휘 절차의 기본으로 적나 · 추천: 적는다 · 트레이드오프: 적음 = 매 에픽이 같은 순서로 조사, 일이 조금 커짐 / 따로 = 이번엔 병렬 권장만 / 안 적음 = 지휘자 재량

### 질문
(b) 판단 · 되묻기 — OQ3 을 풀어서

### 답
→ S6

## R4

### 지금 이해
S6 으로 「설계 전 꼼꼼한 조사 · 계획 첫 단계 가벼운 다시 확인」 을 지휘 절차 기본으로 적는다. 통합 리뷰어는 이음매 여섯(이름 · 같은 파일 문구 순서 · 상태 경로 규약 · 합계 제약 · 되살아난 문구 · 인계)을 보고, 앞서 머지된 에픽의 설계 의도(Goals · Non-goals · 사용자 결정)와 이 PR 을 대조하는 항목은 없다(RC10). blind_spot 차원을 열어 숨은 가정 조사를 보냈다(조사 2).
조사 호출 2/60 · 이 라운드 본체 직접 1
- 확인 RC10 — 확인 — plugins/spec-distill/agents/integration-reviewer.md#볼 이음매 — 1~6 이 이름 · 문구 순서 · 경로 규약 · 합계 · 되살아난 문구 · 인계뿐이고 앞 에픽 설계 의도 대조는 없다

### 다음 결정
OQ4: 앞 에픽의 의도가 뒤 머지로 망가지는 것을 무엇으로 잡나 · 추천: 통합 리뷰어에 일곱째 이음매(겹치는 파일을 고친 앞 에픽의 설계 의도 대조)를 더한다 · 트레이드오프: 리뷰어에 더함 = 있는 자리를 넓힘, 리뷰가 조금 길어짐 / 새 리뷰어 = 더 깊지만 장치가 늘어남 / 지금대로 = 인계 · 문구 대조에만 기댐

### 질문
(b) 판단 — OQ4

### 답
→ S7

## R5

### 지금 이해
S7 로 통합 리뷰어에 일곱째 이음매(같은 파일을 고친 앞 에픽의 설계 의도 대조)를 더한다 — 리뷰어 규칙 강화라 보안 리뷰 대상 표시가 붙는다. 남은 것은 병렬 판단 신호를 어디서 얻을지와 겹침을 무엇으로 셀지다. 지난번 R14 · R9 는 둘 다 spec-distill 의 plugin.json · CHANGELOG · README 를 고쳤지만 머지 때 판 번호를 차례로 올려 문제없이 끝났다.
조사 호출 2/60 · 이 라운드 본체 직접 0

### 다음 결정
OQ5: 병렬 판단 신호를 어디서 얻나 · 추천: 지휘자가 고를 때 보는 작업 목록 출력(show --tasks)에 「동시에 갈 수 있는 준비 에픽」 한 줄을 싣는다 · 트레이드오프: 출력에 실음 = 작은 코드 변경, 지휘자가 놓치지 않음 / 절차 글만 = 코드 변경 없음, 지휘자가 에픽마다 따로 봐야 함
OQ6: 같은 플러그인의 공유 파일만 겹칠 때 병렬을 권하나 · 추천: 권한다(지금 규칙 — 공유 파일은 머지 때 판 번호를 차례로 올려 푼다) · 트레이드오프: 권함 = 병렬 기회가 많음, 머지 때 판 번호 충돌을 풀어야 함 / 같은 플러그인이면 차례로 = 충돌 없음, 병렬 기회가 줄어듦

### 질문
(b) 판단 · 묶음 둘 — OQ5 · OQ6

### 답
→ S8 · S9

### 조사 2 — blind-spot-prober · R4 · 묶음 2

```yaml
hidden_assumptions:
  - assumption: "경로 예약이 겹치지 않으면 두 에픽의 의도도 서로 닿지 않는다"
    why_risky: "병렬을 권하는 기준과, 설계 리뷰에서 이웃 에픽의 결정을 보여 주는 기준이 같은 술어(의존 · 경로 겹침)다. 그래서 병렬로 권해진 에픽끼리는 서로의 결정 기록을 설계 · spec 리뷰 내내 한 번도 보지 못한다. 파일이 안 겹쳐도 동작이 엮이는 경우(이름 · 의미 · 상태 불변식)는 머지 뒤에야 드러난다."
    evidence:
      - {url: "https://martinfowler.com/bliki/SemanticConflict.html", supports: current, claim: "텍스트로는 안전하게 합쳐지는데 프로그램 동작을 바꾸는 변경이 의미 충돌(semantic conflict)이다. 예: 한쪽은 메서드 이름을 바꾸고, 다른 쪽은 옛 이름을 새로 부른다.", touches: [], decides: [OQ4], source_kind: secondary}
      - {url: "https://homes.cs.washington.edu/~mernst/pubs/vc-conflicts-tse2013-abstract.html", supports: current, claim: "Brun 등(TSE 2013): 충돌은 겹치는 텍스트 편집만이 아니라 그 뒤의 빌드 · 테스트 실패로도 나타나고, 잦고 오래 남는다. 일찍 찾으면 도움이 된다.", touches: [], decides: [OQ4], source_kind: primary}
      - {url: "https://lore.kernel.ime.usp.br/git/xmqqzfuznn7g.fsf@gitster.g/T/", supports: current, claim: "Git 메인테이너: git 은 같은 줄이나 이웃한 줄을 건드린 경우만 잡는다. 의미 충돌은 git 이 도울 수 없다.", touches: [], decides: [OQ4], source_kind: primary}
  - assumption: "의도가 갈라지는 위험은 «머지할 때» 생기므로 머지 전 점검에서 잡으면 된다(OQ4 의 틀)"
    why_risky: "S3(설계는 차례로)이면 B 의 설계 대화는 A 가 승인됐지만 아직 머지되지 않은 동안, 옛 기준선(main) 위에서 돈다. 갈라짐은 B 의 설계 시점에 생긴다. 머지 때 발견하면 이미 승인된 B 설계를 다시 열어야 한다(Sealed decision 비용). 병렬과 차례로가 실제로 가르는 것은 처리량보다 'B 를 A 머지 전 기준선에서 설계하느냐'다."
    evidence:
      - {url: "https://cognition.com/blog/dont-build-multi-agents", supports: current, claim: "행동은 암묵적 결정을 담고, 결정이 충돌하면 나쁜 결과가 난다. 맥락을 나누지 않은 병렬 하위 agent 들이 서로 어긋난 산출물을 냈다(Flappy Bird 예).", touches: [], decides: [OQ4], source_kind: secondary}
      - {url: "https://arxiv.org/html/2503.13657v2", supports: current, claim: "MAST(Cemri 등): 다중 agent LLM 시스템의 실패는 주로 시스템 설계 문제와 agent 사이의 정렬 불일치(inter-agent misalignment)에서 온다. 모델 자체의 한계만이 원인이 아니다.", touches: [], decides: [OQ4], source_kind: primary}
  - assumption: "뒤 PR 의 머지 전 점검이 앞서 머지된 에픽의 의도를 볼 수 있다"
    why_risky: "통합 리뷰 묶음은 이미 기본 브랜치에 들어간 에픽의 diff 를 건너뛴다. 앞 에픽에 대해 남는 것은 그 에픽의 리뷰가 미리 적어 둔 「통합 리뷰 인계」 절뿐이다. 앞 리뷰가 예상하지 못한 의도 손상은 구조적으로 보이지 않는다. 리뷰어의 이음매 여섯에도 의도 대조는 없다."
    evidence: []
  - assumption: "설계문서의 Goals · 결정 기록이 그 에픽의 실제 의도다"
    why_risky: "구현 중 설계 범위 안의 판정(Ruling)은 멈추지 않고 쌓인다. 그래서 머지된 동작은 설계문서와 어긋날 수 있다. 의도 대조를 설계문서에만 대면 실제 동작의 변화를 놓친다."
    evidence: []
  - assumption: "경로 예약(설계 전에 적은 값)이 실제로 고칠 파일을 예측한다"
    why_risky: "병렬 권장은 다음 일을 고를 때, 그러니까 S6 의 꼼꼼한 조사보다 «먼저» 정해진다. 그 조사는 바로 놓친 파일을 찾는 단계다. 조사가 파일 범위를 넓히면 이미 「병렬 (권장)」으로 출발한 두 에픽이 도중에 겹친다. 예약 밖 편집은 정보로만 남고 막히지 않는다."
    evidence: []
  - assumption: "지금은 에픽 병렬이 아예 없고, 새 권장 규칙이 처리량을 늘린다"
    why_risky: "걸음 1 · 3 은 이미 겹침 없는 계획 · 구현 agent 를 동시에 보낸다. 빠진 것은 그 판단을 알리는 일과 `show --tasks` 출력의 동시 가능 목록이다. 거기에 병목은 공유 스위트 잠금 · 지휘자의 옮김 부하라고 레포가 스스로 적는다. 「병렬 (권장)」 질문이 「차례로」와 동작이 거의 다르지 않으면 질문 의식(ceremony)이 된다. 두 선택지가 무엇을 다르게 하는지 정의가 필요하다."
    evidence: []
failure_modes:
  - mode: "같은 main 에 대해 따로 초록인 두 PR 을 잇달아 머지해 main 이 깨진다(기계 회귀든 의도 손상이든)"
    trigger: "병렬 에픽 둘이 걸음 5 에 비슷한 때 닿는다. 사용자가 준비된 머지 명령을 연달아 실행한다. 둘째 PR 의 재대조는 걸음 6(머지 뒤)에야 돈다."
    evidence:
      - {url: "https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue", supports: current, claim: "머지 큐는 PR 의 변경이 대상 브랜치의 최신판과 큐에서 앞선 PR 들에 얹혔을 때도 필수 검사를 통과하도록 보장한다. 홀로 통과한 PR 끼리의 비호환을 잡는 장치다.", touches: [], decides: [OQ4], source_kind: primary}
  - mode: "B 의 승인된 설계가 A 의 승인 결정과 모순되는데, 이것이 머지 직전 통합 리뷰나 머지 뒤에야 드러난다"
    trigger: "경로 비겹침으로 병렬이 권해진다. B 의 spec 리뷰 묶음에 A 의 결정 기록이 실리지 않는다(이웃 판정이 의존 · 경로 겹침뿐이라서)."
    evidence:
      - {url: "https://cognition.com/blog/dont-build-multi-agents", supports: current, claim: "맥락을 공유하지 않은 병렬 작업은 서로 충돌하는 암묵적 결정을 낳는다.", touches: [], decides: [OQ4], source_kind: secondary}
  - mode: "테스트 · 스위트 대조가 의미 충돌 대부분을 통과시킨다. 기계 검사 밖 손상이 예외가 아니라 기본이다."
    trigger: "두 에픽 변경이 같은 상태 · 규약을 다른 가정으로 쓴다. 그 조합을 덮는 테스트가 없다."
    evidence:
      - {url: "https://research.chalmers.se/publication/541567", supports: current, claim: "Da Silva 등(단위 테스트 생성으로 의미 충돌 탐지): 가장 좋은 구성도 의미 충돌 29건 중 9건만 잡았다.", touches: [], decides: [OQ4], source_kind: primary, certainty: uncertain}
      - {url: "https://martinfowler.com/bliki/SemanticConflict.html", supports: both, claim: "자체 테스트 코드는 실무에서 의미 충돌을 많이 잡고, 잦은 통합은 남이 바꾼 것을 몇 시간 안에 알게 해 옛 의미 위에 쌓는 양을 줄인다.", touches: [], decides: [OQ4], source_kind: secondary}
  - mode: "겹침 계산에서 뺀 공유 파일과 코퍼스 락에서 두 에픽이 함께 깨진다"
    trigger: "같은 플러그인의 두 에픽이 각자 README(Principles Instantiated · 설치된 Hook 절)를 고친다. 또는 서로 다른 파일에 비슷한 20줄 블록을 더해, 둘 다 머지된 뒤에만 중복 락이 RED 가 된다. 둘째 머지 쪽이 앞 에픽 탓으로 막힌다."
    evidence: []
  - mode: "조사(S6)가 파일 범위를 넓힌 뒤에도 병렬 권장이 다시 평가되지 않는다"
    trigger: "계획 첫 단계의 전수 조사가 다른 에픽의 예약 파일을 찾는다. 예약 밖 편집은 정보로만 보고된다."
    evidence: []
confidence: 0.7
repo_claims:
  - {id: RC1, path: "plugins/spec-distill/scripts/spec_review_bundle.py", anchor: "overlap = {x for o in report[\"overlaps\"] ...}; near = set(deps) | set(dependents) | overlap", line: 113, claim: "spec 리뷰 묶음은 이웃 에픽의 결정 기록을 의존 · 피의존 · 경로 예약 겹침 에픽에만 싣는다. 병렬로 권해질 «겹침 없는» 에픽끼리는 설계 리뷰 때 서로의 결정을 보지 못한다.", touches: [], decides: [OQ4]}
  - {id: RC2, path: "plugins/spec-distill/scripts/conductor_ledger.py", anchor: "c_review_pack — merge-base --is-ancestor other DEFAULT_REF … continue  # 이미 기본 브랜치에 들어갔다", line: 1234, claim: "통합 리뷰 묶음은 이미 머지된 에픽의 diff 를 빼고 열린 브랜치 diff · 충돌 미리 보기 · 앞선 PR 의 인계 절만 담는다. 앞 에픽의 설계 의도(Goals · 결정)는 묶음에 없다.", touches: [], decides: [OQ4]}
  - {id: RC3, path: "plugins/spec-distill/agents/integration-reviewer.md", anchor: "## 볼 이음매", line: 41, claim: "통합 리뷰어가 보는 이음매 여섯(이름 · 같은 파일 문구 순서 · 상태 경로 규약 · 합계 제약 · 되살아난 문구 · 인계)에 앞 에픽 의도와의 대조는 없다. 입력 칸에도 설계문서가 없다.", touches: [], decides: [OQ4]}
  - {id: RC4, path: "plugins/spec-distill/scripts/roadmap_status.py", anchor: "def overlaps(blocks) — a[\"reserved\"] · b[\"reserved\"] 만 비교, _shared(ea) 제외", line: 1001, claim: "겹침은 설계 전에 적은 예약 경로만 비교하고 SHARED_BASENAMES(plugin.json · CHANGELOG.md · README.md, 60행)를 뺀다. 머리 주석(14행)대로 경로 예약 겹침과 다른 에픽 예약 파일의 편집은 정보일 뿐 종료 코드를 바꾸지 않는다.", touches: [], decides: [OQ4]}
  - {id: RC5, path: "plugins/spec-distill/references/conducting.md", anchor: "### 3. 다음 일 고르기와 보내기 — 보내기: 의존 · 같은 파일 겹침(상태 계산의 동시 가능 목록)이 없으면 동시에 보낸다", line: 40, claim: "계획 agent 의 동시 보내기는 이미 규칙에 있다(걸음 1 의 19 · 20행 채우기 규칙도 같다). 19행은 병목이 개수가 아니라 공유 스위트 잠금 · 같은 파일 겹침 · 지휘자의 옮김 부하라고 적는다. 빠진 것은 정책보다 공시와 데이터 배관이다.", touches: [], decides: []}
  - {id: RC6, path: "plugins/spec-distill/references/conducting.md", anchor: "### 5. 머지 전 확인 — 머지 명령 줄만 준비하고 머지는 사용자가 한다 / ### 6. 머지 뒤 — 열린 에픽 브랜치마다 기본 브랜치를 merge 하고 스위트 대조를 다시 돈다", line: 61, claim: "스위트 대조는 그 브랜치와 main 을 합친 사본만 본다. 다른 열린 PR 과 합친 상태의 재대조는 머지 «뒤»(67행)다. 두 PR 을 잇달아 머지하는 사이의 창을 막는 장치는 없다.", touches: [], decides: [OQ4]}
  - {id: RC7, path: "plugins/spec-distill/references/conducting.md", anchor: "### 4. 돌아오기 — 설계 안의 판정은 멈추지 않고 끝에 목록 전체를 보인다", line: 48, claim: "구현 중 판정이 설계문서 밖에서 실제 동작을 옮길 수 있다. 설계문서만으로 하는 의도 대조는 이 변화를 보지 못한다.", touches: [], decides: [OQ4]}
  - {id: RC8, path: "shared/tests/test_no_new_duplication.sh", anchor: "20줄 이상 완전히 같은 블록이 2개 이상 파일에 있는데 … copy-of 로 설명되지 않으면 RED", line: 6, claim: "파일이 겹치지 않는 두 에픽이 각자 비슷한 블록을 더하면, 둘 다 머지된 뒤에만 RED 가 되는 코퍼스 락이 있다. 경로 비겹침과 독립은 같은 말이 아니라는 레포 안 사례다.", touches: [], decides: []}
```

## R6

### 지금 이해
S8 · S9 로 작업 목록 출력에 「동시에 갈 수 있는 준비 에픽」 한 줄을 싣고, 공유 파일만 겹쳐도 병렬을 권한다. 숨은 가정 조사(조사 2)가 다섯 갈래를 냈다 — ① 경로가 안 겹쳐도 의도는 엮일 수 있는데 spec 리뷰가 병렬 에픽의 결정을 보여 주지 않는다 ② 통합 리뷰 묶음에 앞 에픽의 설계 의도가 없어 S7 이 쓸 입력이 없다 ③ 「병렬」 과 「차례로」 가 S3 아래 무엇을 다르게 하는지 정의가 없으면 질문 의식이 된다(실제 차이 = 뒤 에픽 설계가 앞 에픽 머지 전 기준선 위에서 도는가) ④ 따로 초록인 두 PR 을 잇달아 머지하는 창 ⑤ 조사(S6)가 파일 범위를 넓히면 병렬 판단을 다시 해야 한다.
조사 호출 2/60 · 이 라운드 본체 직접 1
- 확인 RC11 — 확인 — plugins/spec-distill/scripts/spec_review_bundle.py#near = set(deps) | set(dependents) | overlap — 주장과 일치(:114)
- 확인 RC12 — 확인 — plugins/spec-distill/scripts/conductor_ledger.py#c_review_pack is-ancestor — 주장과 일치(:1234)
- 확인 RC13 — 확인 — plugins/spec-distill/agents/integration-reviewer.md#볼 이음매 — 주장과 일치(RC10 과 같은 자리)
- 확인 RC14 — 확인 — plugins/spec-distill/scripts/roadmap_status.py#def overlaps — 주장과 일치(:1001)
- 확인 RC15 — 확인 — plugins/spec-distill/references/conducting.md#보내기 — 주장과 일치(:40)
- 확인 RC16 — 확인 — plugins/spec-distill/references/conducting.md#머지 명령 줄만 준비 — 주장과 일치(:61 · :67)
- 확인 RC17 — 확인 — plugins/spec-distill/references/conducting.md#### 4. 돌아오기 — 주장과 일치
- 확인 RC18 — 확인 — shared/tests/test_no_new_duplication.sh#20줄 이상 완전히 같은 블록 — 주장과 일치(:6)

### 다음 결정
OQ7: premortem 다섯 갈래를 설계 범위에 어떻게 반영하나 · 추천: 다섯 모두 작게 반영 · 트레이드오프: 모두 = 빠짐 없이, 일이 조금 커짐 / 머지 쪽만(②·④) = 작지만 설계 시점 갈라짐(①·③)은 남음 / 기록만 = 위험으로 brief 에만

### 질문
(b) 판단 · 숨은 가정 처분 — OQ7

### 지금 이해 덧붙임 (R6 중 사용자 발화)
S10 — 이 레포만이 아니라 devbrew 를 쓰는 아무 레포에서나 맞게 설계해야 한다. 지금 공유 파일 목록(plugin.json · CHANGELOG.md · README.md)은 코드에 고정된 이 레포 꼴 값이다(RC4 · RC14) — 레포 전용 값 금지 원칙과 부딪힌다. 「판 번호를 차례로 올려 푼다」 도 판 파일이 있는 레포의 말이라 일반화가 필요하다.
OQ8: 공유 파일 목록을 레포마다 정하게 하나 · 추천: 기본값은 지금 셋, 레포가 머리말(roadmap frontmatter · 레포 설정)로 바꿀 수 있게 · 트레이드오프: 설정 가능 = 다른 레포에서도 맞음, 설정 한 칸 늘어남 / 고정 = 단순하나 다른 레포에서 틀림

### 답
→ S11 · S12

### 조사 3 — steelman-builder · R6 · 묶음 3

```yaml
case_for_alternative:
  statement: "여덟 가지를 둘로 나눈다. 에픽 A(권장 신호: ①②③)를 먼저 내고, 에픽 B(통합 안전: ④⑤)를 뒤에 낸다. ⑥⑦⑧은 새로 만들지 않는다. 레포에 이미 있는 장치(이웃 에픽 결정 · 머지 뒤 재대조 · 재분해 신호)가 맡는다."
  strongest: "S1의 불만(「왜 병렬진행 추천이 안온걸까」)은 ①② 둘로 바로 풀린다. 여덟을 한 에픽에 넣으면 conducting.md · control_plane.py · roadmap_status.py · repo_defaults · spec_review_bundle.py · conductor_ledger.py · integration-reviewer.md · redecompose.md를 한 번에 고친다. Google 소형 CL 지침의 「one self-contained change」를 넘는 크기이고, 리뷰가 흐려지며 되돌리기도 어려워진다. 여덟 중 셋은 레포에 이미 있다. ⑥은 spec_review_bundle.neighbors()가 겹치는 이웃 에픽의 결정을 그 브랜치 끝에서 읽는다. ⑦은 conducting.md 걸음 6 · 손 절차 8이 머지 뒤 재대조와 「기본 브랜치가 움직이면 다시 돈다」를 이미 정해 둔다. ⑧은 redecompose.md §1이 열린 신호 목록에 예약 파일 겹침을 이미 둔다. 이 셋을 새 규칙으로 다시 적으면 YAGNI가 말하는 carry 비용이 생기고, 같은 규칙을 두 군데 적어 둔 사본이 시간이 지나며 서로 어긋난다. ① 질문은 문제가 더 크다. 앞 에픽 계획을 보낸 뒤 다음 에픽 설계로 넘어가는 것이 이미 기본 동작이다. 고를 때마다 「차례로」를 다시 물으면 NN/g가 말하는 cry-wolf 확인창이 된다. 이것이 premortem이 지목한 질문 의식이다."
case_for_current:
  strongest: "사용자 goal은 「병렬 권장」과 「회귀 · 통합은 여전히 잘해야해」를 한 문장에 묶었다. A만 먼저 나가면 병렬은 권하는데 의도 이음매(⑤)는 아직 없는 기간이 생긴다. 지금 기계 검사는 스위트 대조와 문구 · 순서 이음매(seam 2)뿐이다. 생성 테스트로 semantic conflict를 잡은 연구의 최선 설정도 28건 중 9건만 잡았다(SAM). P3에 따라 ⑤가 이 결정의 무게를 진다. 둘로 나눠도 병렬 이득은 없다. A와 B가 모두 conducting.md와 control_plane.py를 예약하므로 레포 자신의 규칙상 겹침이다. 결국 차례로 갈 수밖에 없고, 남는 것은 리뷰 두 번과 브랜치 두 개의 비용이다. ③은 과설계가 아니다. 지금 SHARED_BASENAMES(plugin.json · CHANGELOG.md · README.md)는 devbrew 플러그인 레포 전용 이름이다. package.json이나 pyproject.toml을 쓰는 레포에서는 P4(S10)와 CLAUDE.md 「레포 전용 값 금지」를 어긴다. 사용자는 S11에서 다섯 모두 작게 반영하라고 이미 골랐다. 한 설계 리뷰가 여덟 사이의 이음매(②의 출력 계약과 ①의 판단, ⑧과 ②의 재계산)를 한꺼번에 본다."
premise_refutation:
  hits: []
premise_list_challenge: "반증은 아니지만 결함과 빠진 전제가 넷 있다. (1) 「이미 있는 것」 전제가 없다. 여덟 중 ⑥(RC5) · ⑦(RC8) · ⑧(RC9 · RC10)은 레포에 상당 부분 있다. 전제 목록이 이를 적지 않아서 에픽이 있는 장치를 다시 만들 위험이 있다(CLAUDE.md 「있는 것 먼저」). 전제로 더해야 한다: 「⑥⑦⑧은 기존 장치를 넓히거나 가리키는 것으로 족하다」. (2) P1은 범위를 좁혀야 한다. 동시 가능 신호는 에픽 보기(`show <로드맵> <에픽>`)의 「동시에 갈 수 있는 에픽」 줄에 이미 있다(RC2). 원인은 「신호가 없다」가 아니라 「고르는 자리가 읽는 --tasks 출력과 걸음 3 공시 규칙에 없다」이다. 또 기존 parallel_with()는 「준비」만 고르지 않고 끝나지 않은 모든 에픽을 낸다. ②는 「준비」만 걸러야 한다. (3) ②가 기대는 출력 계약 전제가 빠졌다. --tasks는 줄마다 `<제목><탭><작업 상태>`이고 에픽 하나에 작업 하나라는 소비 계약이 있다(RC3). 새 줄이 이 꼴이면 지휘자가 그 줄을 작업으로 만든다. S8(작업 목록 출력에 싣는다)은 닫힌 결정이므로 꼴만 바꾼다. 탭 없는 줄로 내고 소비 규칙에 「탭 없는 줄은 작업이 아니다」를 적는 식이다. (4) 질문 빈도 전제가 빠졌다. P2와 RC4를 보면, 앞 에픽 계획을 보낸 뒤 다음 설계로 가는 것이 이미 기본이다. 그래서 ①의 「차례로」는 기본에서 빠지는 선택이다. 언제 다시 묻는지(같은 세션에서 준비 집합이 바뀔 때만인지)가 정해지지 않으면 질문 의식이 된다. 선례: CLAUDE.md의 epic-conductor 같은 세션 승인 재사용(RC11). 같은 입력으로 다시 불린 것은 아니다(첫 호출)."
recommendation: refined
refined_takes: "한 에픽을 유지한다(나누면 같은 파일 예약으로 어차피 차례로 가고, 권장과 안전 사이에 틈이 생긴다). ①은 S2 그대로 권하며 묻는다. 다만 같은 세션에서 준비 에픽 집합이 바뀔 때만 다시 묻는다. ②는 기존 parallel_with() 계산을 「준비」로 걸러 --tasks에 싣는다. 탭 없는 한 줄로 내서 작업 줄 계약을 지킨다. ③은 기존 해결자(repo_defaults의 parallel_default와 같은 길)에 키 하나를 더하고, 기본값은 지금 세 이름이다. ④는 conducting.md 걸음 3에 기본값 문장 하나로 넣는다. ⑤는 integration-reviewer.md에 이음매 7을 넣고 review-pack에 같은 파일을 고친 앞 에픽의 설계문서 의도 절을 싣는다. 실제 빈자리이고 P3의 중심이다."
refined_drops: "⑥의 새 장치: spec_review_bundle.neighbors()의 near 집합에 진행 중인 병렬 에픽을 더하는 확장으로 낮춘다. ⑦의 새 규칙: 걸음 5 · 6과 손 절차 8에 이미 있으므로 새 절을 만들지 않고, 필요하면 병렬 PR에 적용된다는 한 줄 상호 참조만 둔다. ⑧의 새 메커니즘: 동시 가능 목록은 agent를 보내고 거둘 때마다 로드맵 예약에서 다시 계산된다. 그래서 「조사가 예약 밖 경로를 찾으면 재분해 절차로 예약을 고친다」 한 줄(④ 문장 또는 redecompose.md §1 신호 목록)로 족하다. 고를 때마다 반복하는 ① 질문도 버린다."
evidence:
  - {url: "https://google.github.io/eng-practices/review/developer/small-cls.html", supports: alternative, claim: "변경의 적정 크기는 「one self-contained change」이다. 큰 CL은 리뷰에서 중요한 지적이 빠지고 되돌리기가 어렵다. 리팩터링은 기능 변경과 나누는 것이 보통 낫다.", touches: [], decides: [OQ9]}
  - {url: "https://arxiv.org/abs/2310.02395v1", supports: current, claim: "merge 도구는 semantic 수준 충돌을 놓친다. 생성 단위 테스트로 잡는 최선 설정도 9/28이다. 기계 검사만으로는 의도 충돌을 다 잡지 못한다.", touches: [P3], decides: [OQ9]}
  - {url: "https://arxiv.org/abs/2507.06762v1", supports: current, claim: "단위 테스트 기반 semantic conflict 탐지기(SMAT)는 false negative 비율이 높다(검색 요약 기준, certainty: uncertain).", touches: [P3], decides: [OQ9]}
  - {url: "https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue", supports: both, claim: "merge queue는 각 PR을 최신 대상 브랜치와 앞에 줄 선 PR을 합친 상태에서 검사한 뒤 머지한다. 업계는 ⑦의 원리(하나씩 머지하고 합친 뒤 재대조)를 쓴다. devbrew는 이를 걸음 5 · 6에 이미 손 절차로 갖고 있다(RC8).", touches: [], decides: [OQ9]}
  - {url: "https://docs.aviator.co/mergequeue", supports: current, claim: "서로 기대는 코드를 고친 두 PR은 각자 검사를 통과해도 합친 뒤 빌드가 깨질 수 있다. 같은 파일 겹침이 없어도 통합 위험은 남는다(검색 요약 기준, certainty: uncertain).", touches: [P3], decides: [OQ9]}
  - {url: "https://www.nngroup.com/articles/confirmation-dialog/", supports: alternative, claim: "일상 동작에 확인을 자주 물으면 사용자는 읽지 않고 누른다(「cry wolf」). 확인은 심각하고 드문 동작에만 쓴다. ①이 고를 때마다 뜨면 질문 의식이 된다.", touches: [], decides: [OQ9]}
  - {url: "https://martinfowler.com/bliki/Yagni.html", supports: both, claim: "앞당겨 만든 기능은 만드는 비용 · 늦어지는 비용 · 안고 가는(carry) 비용을 치른다. 이미 있는 장치를 다시 적는 ⑥⑦⑧이 여기에 걸린다. 다만 고치기 쉽게 만드는 노력은 YAGNI 대상이 아니다. 실제 다른 레포의 필요(P4)에 답하는 ③ 설정화는 이쪽에 가깝다.", touches: [P4], decides: [OQ9]}
repo_claims:
  - {id: RC1, path: "plugins/spec-distill/scripts/roadmap_status.py", anchor: "SHARED_BASENAMES = (\"plugin.json\", \"CHANGELOG.md\", \"README.md\")", line: 60, claim: "겹침에서 빼는 공유 파일이 devbrew 플러그인 레포 이름으로 코드에 박혀 있다. 다른 레포(package.json · pyproject.toml 등)에서는 맞지 않아, ③이 P4에 답하는 실제 빈자리다.", touches: [P4], decides: [OQ9]}
  - {id: RC2, path: "plugins/spec-distill/scripts/control_plane.py", anchor: "row(\"동시에 갈 수 있는 에픽\"", line: 1222, claim: "동시 가능 신호는 에픽 보기(`show <로드맵> <에픽>`)에 이미 있다. 고르는 자리가 읽는 --tasks(tasks_output)에는 없다. parallel_with()는 준비 단계만이 아니라 끝나지 않은 에픽 전부를 낸다(roadmap_status.py `def parallel_with`).", touches: [P1], decides: [OQ9]}
  - {id: RC3, path: "plugins/spec-distill/scripts/control_plane.py", anchor: "def tasks_output", line: 383, claim: "--tasks 출력은 줄마다 `<제목>\\t<상태>`이다. conducting.md 손 절차 1의 「줄마다 `<제목><탭><작업 상태>` 이고 에픽 하나에 작업 하나다」가 그 소비 계약이다. ②의 새 줄이 이 꼴이면 지휘자가 그 줄을 작업으로 만든다.", touches: [], decides: [OQ9]}
  - {id: RC4, path: "plugins/spec-distill/references/conducting.md", anchor: "spec 이 승인되면 지휘 세션은 계획 · 구현으로 들어가지 않고 그 에픽 브랜치의 백그라운드 agent 에 계획을 보낸 뒤 다음 에픽의 설계로 간다", line: 97, claim: "앞 에픽 계획 · 구현이 도는 동안 다음 에픽 설계로 가는 파이프라인 병렬은 이미 기본이다(걸음 3 보내기에도 「같은 턴에 다음 에픽의 설계로 간다」). ①의 「차례로」는 이 기본에서 빠지는 선택이다. 빠진 것은 고른 판단을 공시하는 규칙이다.", touches: [P1, P2], decides: [OQ9]}
  - {id: RC5, path: "plugins/spec-distill/scripts/spec_review_bundle.py", anchor: "def neighbors / near = set(deps) | set(dependents) | overlap", line: 114, claim: "spec 리뷰 묶음은 의존 · 피의존 · 경로 겹침 이웃 에픽의 `## 결정 기록`을 이미 보인다. 머지 전 에픽은 그 브랜치 끝(tip)에서 읽는다. ⑥의 빈자리는 공유 파일만 겹치거나 겹침이 없는 병렬 에픽이 near에서 빠진다는 것뿐이다. near 집합을 넓히는 확장으로 족하다.", touches: [], decides: [OQ9]}
  - {id: RC6, path: "plugins/spec-distill/scripts/conductor_ledger.py", anchor: "readme = [\"이 폴더는 통합 리뷰 묶음이다", line: 1279, claim: "통합 리뷰 묶음(review-pack)은 pr.diff · open-*.diff · conflicts.txt · handoffs.md만 싣는다. 같은 파일을 고친 앞 에픽의 설계 의도는 없다. ⑤는 실제 빈자리다.", touches: [P3], decides: [OQ9]}
  - {id: RC7, path: "plugins/spec-distill/agents/integration-reviewer.md", anchor: "## 볼 이음매", line: 41, claim: "이음매 1~6은 이름 · 문구 순서 · 규약 · 합계 · 되살아난 옛 문구 · 인계 확인이다. 앞 에픽 설계 의도와 대조하는 이음매는 없다. ⑤의 일곱째는 새 축이다.", touches: [P3], decides: [OQ9]}
  - {id: RC8, path: "plugins/spec-distill/references/conducting.md", anchor: "### 6. 머지 뒤 — 열린 에픽 브랜치마다 기본 브랜치를 merge 하고 스위트 대조를 다시 돈다", line: 67, claim: "⑦(하나씩 머지하고 합친 뒤 재대조)은 이미 있다. 걸음 6이 머지 뒤 재merge · 재대조를, 손 절차 8이 「기본 브랜치가 움직이면 다시 돈다」를, 손 절차 6이 「머지는 사용자가 한다」를 정하고, 통합 리뷰어는 「epics merge one PR at a time」을 전제한다.", touches: [P3], decides: [OQ9]}
  - {id: RC9, path: "plugins/spec-distill/references/redecompose.md", anchor: "## 1. 신호 — 목록은 닫혀 있지 않다", line: 11, claim: "재분해 신호 목록은 열려 있고, 이미 「다른 에픽이 예약한 파일을 고쳐야만 AC 를 채운다」를 담는다. ⑧(조사가 범위를 넓힘)의 길은 예약을 고치는 이 절차로 이미 있다.", touches: [], decides: [OQ9]}
  - {id: RC10, path: "plugins/spec-distill/references/conducting.md", anchor: "agent 를 보내거나 거둘 때마다 상태 계산의 동시 가능 목록과 승인된 설계의 남은 계획을 훑어", line: 14, claim: "동시 가능 목록은 보내고 거둘 때마다 로드맵 예약에서 다시 계산된다. 예약을 고치면 병렬 재판단은 저절로 따라온다. ⑧에 새 재판단 메커니즘은 필요 없다.", touches: [], decides: [OQ9]}
  - {id: RC11, path: "CLAUDE.md", anchor: "`epic-conductor` 를 같은 세션에서 같은 규모로 다시 부르면 이미 받은 승인을 다시 쓰고 공시만 한다", claim: "같은 세션 안에서는 받은 답을 다시 쓰고 공시만 하는 선례가 레포에 있다. ①을 고를 때마다 묻지 않고 준비 집합이 바뀔 때만 다시 묻는 refined 경계의 근거다.", touches: [], decides: [OQ9]}
```

## R7

### 지금 이해
steelman(ST1) 결과 builder 추천은 보완(refined). 전제 충돌은 0건이다. 한 에픽은 유지하되 ⑥⑦⑧은 새 장치 없이 있는 것을 넓히거나 가리키는 한 줄로 줄이고, ① 질문은 같은 세션에서 준비 에픽 집합이 바뀔 때만 다시 묻는다.
조사 호출 3/60 · 이 라운드 본체 직접 1
- 확인 RC19 — 확인 — plugins/spec-distill/scripts/roadmap_status.py#SHARED_BASENAMES — 주장과 일치
- 확인 RC20 — 확인 — plugins/spec-distill/scripts/control_plane.py#row("동시에 갈 수 있는 에픽" — 주장과 일치
- 확인 RC21 — 확인 — plugins/spec-distill/scripts/control_plane.py#def tasks_output — 주장과 일치(소비 계약 conducting.md:95 「에픽 하나에 작업 하나」)
- 확인 RC22 — 확인 — plugins/spec-distill/references/conducting.md#다음 에픽의 설계로 간다 — 주장과 일치(:40 · :97)
- 확인 RC23 — 확인 — plugins/spec-distill/scripts/spec_review_bundle.py#near = set(deps) | set(dependents) | overlap — 주장과 일치
- 확인 RC24 — 확인 — plugins/spec-distill/scripts/conductor_ledger.py#이 폴더는 통합 리뷰 묶음이다 — 주장과 일치(:1279)
- 확인 RC25 — 확인 — plugins/spec-distill/agents/integration-reviewer.md#볼 이음매 — 주장과 일치
- 확인 RC26 — 확인 — plugins/spec-distill/references/conducting.md#### 6. 머지 뒤 — 주장과 일치(:67)
- 확인 RC27 — 확인 — plugins/spec-distill/references/redecompose.md#1. 신호 — 주장과 일치(:16 예 「다른 에픽이 예약한 파일을 고쳐야만 AC 를 채운다」)
- 확인 RC28 — 확인 — plugins/spec-distill/references/conducting.md#보내거나 거둘 때마다 — 주장과 일치
- 확인 RC29 — 반증 — CLAUDE.md#`epic-conductor` 를 같은 세션에서 같은 규모로 다시 부르면 — 그 자리는 R9(#256)가 지운 뒤라 지금 CLAUDE.md 에 없고 주장은 그 문장이 있다고 했다

### 다음 결정
OQ9: 의심 방향을 유지 · 보완 · 전환 · 보류 중 무엇으로 하나 · steelman 질문(고정 순서)

### 질문
steelman 의심 게이트 — ST1

### 답
→ S13

## R8

### 지금 이해
S13 으로 범위를 보완했다 — 한 에픽 유지, ⑥⑦⑧ 은 있는 장치를 넓히거나 가리키는 한 줄, 병렬 질문은 준비 에픽 집합이 바뀔 때만 다시 묻는다. 확인 축 다섯 가운데 넷이 닫혔고, 파생 차원 중 남은 것은 검증 방법 하나다.
조사 호출 3/60 · 이 라운드 본체 직접 0

### 다음 결정
OQ10: 권장 줄이 실제로 나오는지 무엇으로 증명하나 · 추천: 작업 목록 출력을 실제 상태 계산 픽스처로 재는 테스트(준비 에픽 둘 · 겹침 없음이면 줄이 나오고, 하나거나 의존이 있으면 안 나옴) + 절차 문장은 본문 고유 문구 락과 변이 · 트레이드오프: 출력 테스트 = 동작을 잰다, 픽스처가 필요 / 문구 락만 = 싸지만 헤더만으로 통과하는 공허한 락이 되기 쉽다
열린 질문 확인: OQ10 말고 열린 결정이 없다 — 이대로 닫나

### 질문
(b) 판단 · 묶음 둘 — OQ10 · 열린 질문 확인

### 답
→ S14 · S15

## audit §2 대기 줄
- 포화 판정 1: 아직 — 빈 곳 6개
- 포화 판정 2: 아직 — 빈 곳 5개
- 사용자 종료(@S17) — 마지막 판정 아직

### 조사 4 — orchestrator · R9 · 묶음 4
- 확인 RC30 — 확인 — plugins/spec-distill/references/conducting.md#판정 보관본(`## 판정` 아래 `### <계획>`) — 구현 중 판정 목록은 설계문서 `## 판정` 절에 보관된다(:51) — 의도 대조가 설계문서를 읽으면 판정도 함께 본다

### 조사 6 — repo-researcher · R9 · 묶음 5

repo_claims:
  - id: RC1
    path: "plugins/spec-distill/scripts/control_plane.py"
    anchor: "def tasks_output(items, select_error=None)"
    line: 383
    claim: "--tasks 출력은 이 함수 하나가 만든다. 에픽 블록마다 한 줄 `clean(제목) + \"\\t\" + 상태`를 낸다. 상태는 TASK_STATES(pending · in_progress · completed)이고, 그 밖이면 제목 뒤에 `· 알 수 없음(사유)`를 붙이고 상태 칸은 `keep`이다. 그 뒤에 기계 상태 `## 작업` 표의 「로드맵 밖」 줄을 붙이고, 단계가 WORK_DONE이면 completed, 아니면 in_progress로 낸다. rc가 0이 아니면(2 · 3 · 4) 표준 출력은 비고 사유는 표준 오류로 간다. 지금은 모든 줄이 탭 두 칸이고, 탭 없는 줄을 내는 분기는 없다."
    touches: []
    decides: [OQ13]
  - id: RC2
    path: "plugins/spec-distill/scripts/control_plane.py"
    anchor: "def clean(value) — \"제어 문자(탭 · 줄바꿈 · ESC 포함)를 공백으로 — 한 줄 출력과 탭 두 칸을 깨지 않게.\""
    line: 65
    claim: "제목에 든 탭 · 줄바꿈은 공백으로 바뀐다. 「한 줄 = 탭으로 나뉜 두 칸」이라는 불변식을 코드가 일부러 지킨다."
    touches: []
    decides: [OQ13]
  - id: RC3
    path: "plugins/spec-distill/scripts/control_plane.py"
    anchor: "if tasks: out, err, rc = tasks_output(v[\"items\"], shown_error)"
    line: 1319
    claim: "레포 안에서 tasks_output을 부르는 프로덕션 코드는 cmd_show의 --tasks 분기 하나뿐이다(grep 결과 tasks_output은 383 · 1320에만 있다). 상태줄(cmd_statusline → statusline_text, 1171행)은 같은 gather 보고서를 쓰지만 tasks_output도 그 줄도 읽지 않는다. 그래서 --tasks 줄 모양이 바뀌어도 상태줄은 영향을 받지 않는다."
    touches: []
    decides: [OQ13]
  - id: RC4
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "손 절차 1. **맞추기.** — \"줄마다 `<제목><탭><작업 상태>` 이고 에픽 하나에 작업 하나다 — 제목은 그대로 쓰고, 상태가 `keep`(알 수 없음)이면 작업 상태는 두고 제목만 바꾼다.\""
    line: 95
    claim: "줄 모양을 소비자 쪽에서 적은 정본은 이 문장이다. 줄을 파싱하는 것은 스크립트가 아니라 모델(지휘 세션)이다. 탭 앞은 제목으로 그대로 쓰고, 탭 뒤 상태 토큰으로 작업 상태를 정한다. 탭 없는 줄을 어떻게 다룰지는 이 절차에 없다. 같은 문장의 「에픽 하나에 작업 하나」는 로드맵 밖 줄이 더해지는 지금 동작과 어긋나 보인다. 같은 줄 뒤쪽에 「로드맵 밖 일도 에픽 일과 같은 목록에 둔다」가 함께 있다."
    touches: []
    decides: [OQ13]
  - id: RC5
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### 1. 맞추기 — \"`python3 \"<SD>\"/scripts/control_plane.py show --tasks <로드맵>` 으로 작업 목록을 맞춘다(종료 코드 3 · 4 의 뜻은 손 절차 1 과 같다)\""
    line: 13
    claim: "지휘 순환 걸음 1(13행) · 맞추기 순서 ②(15행) · 걸음 3(34행)이 --tasks를 부른다. 줄 모양과 rc의 뜻은 손 절차 1(95행)로 미룬다. 21행은 「작업 목록(`show --tasks`)은 「로드맵 밖」 줄을 더한다」고 출력 내용을 적는다."
    touches: []
    decides: [OQ13]
  - id: RC6
    path: "plugins/spec-distill/skills/epic-conductor/SKILL.md"
    anchor: "cd \"<root>\" && python3 \"$SD/scripts/control_plane.py\" show \"<로드맵>\""
    line: 153
    claim: "epic-conductor SKILL.md는 --tasks를 직접 부르지 않는다. `show <로드맵>`(114 · 153행)만 부르고, 걸음 1~7은 conducting.md로 넘긴다(163 · 169행). 96행의 `<경로><탭><끝나지 않은 에픽 수>`는 `conductor_ledger.py roadmaps`의 출력으로, --tasks와는 다른 계약이다. test_epic_conductor_skill.sh:28이 그 문장을 잠근다."
    touches: []
    decides: [OQ13]
  - id: RC7
    path: "plugins/spec-distill/skills/roadmap-status/SKILL.md"
    anchor: "cd \"<root>\" && python3 \"$SD/scripts/control_plane.py\" show \"<경로>\" \"<에픽>\""
    line: 72
    claim: "roadmap-status skill은 --tasks 없이 `show`(지도)만 부르고 출력을 고치지 않고 보인다. --tasks 출력의 소비자가 아니다."
    touches: []
    decides: [OQ13]
  - id: RC8
    path: "plugins/spec-distill/tests/test_control_plane.py"
    anchor: "class Tasks / def test_every_line_has_exactly_two_fields — self.assertEqual([len(x.split(\"\\t\")) for x in out], [2])"
    line: 313
    claim: "모든 줄이 탭 두 칸이라는 형식 고정 락이다. 탭 든 제목 fixture 한 개로 `[2]`를 단언한다. 그 fixture에서 탭 없는 줄이 하나라도 섞이면 RED다. 다른 fixture에 섞이는 줄은 이 락이 보지 못한다. test_lines(307) · test_tasks_add_outside_roadmap_rows(294)는 출력 줄 목록을 등호로 통째 비교한다. 그래서 그 fixture에 줄이 더해지거나 모양이 바뀌면 둘 다 RED다."
    touches: []
    decides: [OQ13]
  - id: RC9
    path: "plugins/spec-distill/tests/test_control_plane.sh"
    anchor: "=== 작업 목록(AC3) === / assert_eq \"$rc|$(printf '%s\\n' \"$out\" | wc -l | tr -d ' ')\" \"0|3\" \"경로를 주면 그 로드맵만\""
    line: 222
    claim: "셸 끝에서 끝 락은 셋이다. 첫 줄을 `R1 하나 — 설계 중\\tin_progress`와 정확히 비교한다(195행). 로드맵 rn의 줄 수를 3으로 고정한다(222행). 꺼짐이나 상태 계산 3이면 표준 출력이 비고 rc 3이다(177 · 199행). --tasks 출력 아무 데나 줄을 더하면 222행 줄 수 락이 깨진다. 첫 줄 앞에 넣으면 195행도 깨진다."
    touches: []
    decides: [OQ13]
  - id: RC10
    path: "plugins/spec-distill/tests/test_conductor_e2e.sh"
    anchor: "tasks_of() { (cd \"$W\" && python3 \"$S/control_plane.py\" show --tasks \"$RM\"); } / assert_eq \"$after\" \"$before\" \"기계 상태를 지워도 작업 목록이 같다\""
    line: 111
    claim: "e2e는 「E1 포함」(39행)을 보고, 기계 상태 파일을 지우기 전후 --tasks 출력 전체가 같은지 본다(105–111행, AC17). 기계 상태(예: `## 작업` 로드맵 밖 줄)에서 오는 줄이 --tasks에 들어가면, 이 비교는 그 줄이 지울 때 사라져도 같다고 보는 전제 위에 있다. 지금 fixture에는 로드맵 밖 줄이 없어 통과한다. 새 줄이 기계 상태에서 온다면 이 락과 충돌할 수 있다."
    touches: []
    decides: [OQ13]
  - id: RC11
    path: "plugins/spec-distill/tests/test_conducting_reference.sh"
    anchor: "for lit in 'control_plane.py show --tasks <로드맵>' '종료 코드 4' 'roadmap_status.py --roadmap-file <로드맵>' '기억에 기대지 않는다'"
    line: 31
    claim: "conducting.md 락(test_conducting_reference.sh:31 · test_conducting_loop.sh:20)은 명령 리터럴과 rc 문구만 잠근다. 손 절차 1의 `<제목><탭><작업 상태>` 줄 모양 문장을 잠그는 테스트는 찾지 못했다(tests/에서 '탭' grep 결과 없음)."
    touches: []
    decides: [OQ13]
  - id: RC12
    path: "plugins/spec-distill/README.md"
    anchor: "`python3 <플러그인>/scripts/control_plane.py show --tasks <로드맵>` 의 줄(`<제목>` 탭 `<pending|in_progress|completed|keep>`)로 맞춥니다."
    line: 173
    claim: "사용자 문서도 줄 모양을 공시한다(173행). 286행은 kill switch가 켜지면 --tasks가 표준 출력을 비우고 rc 3이라고 적는다. scripts/control_plane.py:9 docstring도 같은 모양을 적는다. 모양을 바꾸면 이 공시들도 함께 고칠 곳이다."
    touches: []
    decides: [OQ13]
  - id: RC13
    path: "plugins/spec-distill/scripts/repo_defaults.py"
    anchor: "KEYS = (\"specs_dir\", ... \"parallel_default\", \"branch_prefix\") / ROADMAP_LAYER_KEYS / MACHINE_LAYER_KEYS / _DEFAULTS / COUNT_KEYS = (\"parallel_default\",)"
    line: 36
    claim: "설정 키는 닫힌 집합 KEYS(아홉)다. 층마다 받는 키는 따로 정한다(레포 설정 파일 = KEYS 전부, 로드맵 = ROADMAP_LAYER_KEYS 여섯, 기계 상태 = test_command · test_failure_pattern). 기본값은 _DEFAULTS에 있다. 새 키를 더하려면 KEYS · _DEFAULTS를 고치고, 받을 층을 정하고(ROADMAP_LAYER_KEYS 등), 종류 상수(DIR_KEYS · TEXT_KEYS · COUNT_KEYS — test_roadmap_ontology.py:21 · 59가 import한다)를 정해야 한다. 목록 값을 받는 키는 지금 없다. 값은 모두 한 줄 스칼라(폴더 · 글자 · 정수)다."
    touches: []
    decides: [OQ14]
  - id: RC14
    path: "plugins/spec-distill/scripts/repo_defaults.py"
    anchor: "def strict_frontmatter — \"줄 규칙은 roadmap_model.frontmatter 와 같고(들여쓴 줄 · 목록 줄 · `#` 줄은 건너뜀)\" / if not line or line[0] in \" \\t-#\": continue"
    line: 116
    claim: "머리말 파서는 `-`로 시작하는 줄과 들여쓴 줄을 조용히 건너뛴다. 그래서 YAML 블록 목록(`key:` 다음 줄에 `- a`)을 쓰면 값이 빈 문자열로 읽힌다. 목록 값 키를 만들려면 한 줄 안의 구분 문법(예: 쉼표)을 새로 정하거나 파서를 바꿔야 한다. 따옴표 없는 ` #`은 unquoted_hash 오류다(137행)."
    touches: []
    decides: [OQ14]
  - id: RC15
    path: "plugins/spec-distill/scripts/repo_defaults.py"
    anchor: "def merge_layers — elif key == \"parallel_default\": ... out[\"sources\"][key] = \"기본값(머리말 값이 깨졌다)\" / else: ... out[\"errors\"].append(\"%s 의 값이 비었다(%s) — 값을 채우거나 키를 지운다\")"
    line: 193
    claim: "키가 없으면 _DEFAULTS 값을 쓰고 출처는 「기본값」이다. 키가 있는데 값이 깨졌을 때는 두 갈래다. parallel_default만 「게이트가 아니라서」 기본 3으로 세고 warnings에 적는다(166 · 193–201행). 그 밖의 비폴더 키는 값이 비면 errors에 적고 값은 None이다(203–208행) — docstring 표현으로는 「기본값으로 조용히 바꾸지 않는다」. 테스트: test_repo_defaults.py:215–221(깨진 parallel_default → 3 · 경고 · 출처 라벨)."
    touches: []
    decides: [OQ14]
  - id: RC16
    path: "plugins/spec-distill/scripts/roadmap_status.py"
    anchor: "errors = errors + resolved[\"errors\"]; report[\"format_errors\"] = errors; if errors: report[\"blocks\"] = [{... \"stage\": \"알 수 없음\", \"reason\": \"로드맵 형식 깨짐\", \"task_status\": None ...}]; return report"
    line: 1088
    claim: "해결자 errors는 상태 계산의 format_errors가 된다. 그러면 모든 블록이 「알 수 없음」이 되고 계산은 exit 3으로 일찍 끝난다(overlaps 계산 전에 반환한다). tasks_output은 exit 3이면 줄 없이 rc 3을 낸다(control_plane.py:395). 그래서 새 키를 「빈 값 = errors」 갈래에 두면, 빈 설정 하나가 상태 계산과 작업 목록 전체를 멈춘다. parallel_default 갈래(경고 + 기본값)에 두면 멈추지 않는다."
    touches: []
    decides: [OQ14]
  - id: RC17
    path: "plugins/spec-distill/scripts/roadmap_status.py"
    anchor: "# 경로 예약 겹침 · 위반에서 빼는 공유 파일 — 버전은 머지 직전에 정한다(N6). SHARED_BASENAMES = (\"plugin.json\", \"CHANGELOG.md\", \"README.md\")"
    line: 60
    claim: "공유 파일 목록은 모듈 상수다. 레포 설정이나 해결자를 거치지 않는다. 쓰는 곳은 `_shared(path)` 하나뿐이다(267행: 경로의 basename이 목록에 있는가). 레포 안에서 SHARED_BASENAMES라는 이름을 import하거나 참조하는 다른 스크립트는 없다. shared/tests/test_copy_of_contract.sh:683의 같은 이름 셸 변수는 shared/* 정본 basename을 뜻하는 다른 개념이다."
    touches: []
    decides: [OQ14]
  - id: RC18
    path: "plugins/spec-distill/scripts/roadmap_status.py"
    anchor: "def overlaps(blocks) — shared = sorted({ea for ea in a[\"reserved\"] for eb in b[\"reserved\"] if not _shared(ea) and (_reserves(ea, eb) or _reserves(eb, ea))})"
    line: 1001
    claim: "_shared는 두 자리에서 쓴다. (1) overlaps: 의존 관계가 없는 블록 쌍의 예약 항목이 서로 덮으면 겹침이고, 공유 파일이면 뺀다. 이때 _shared는 앞 블록 a의 항목 ea에만 건다. 그래서 a가 폴더(`plugins/x/`)를, b가 `plugins/x/README.md`를 예약하면 겹침(경로 `plugins/x/`)으로 잡힌다. 순서가 반대면 ea가 README.md라 빠진다(순서에 따라 결과가 다르다). (2) 973–982행 경로 예약 위반: 브랜치가 바꾼 파일이 공유 파일이면 건너뛴다. _shared는 설정을 받지 않는다. build는 compute에 settings를 넘기지만(1126행) overlaps(blocks)는 settings 없이 부른다(1131행)."
    touches: []
    decides: [OQ14]
  - id: RC19
    path: "plugins/spec-distill/scripts/roadmap_status.py"
    anchor: "def _shared(path: str) -> bool: return path.rsplit(\"/\", 1)[-1] in SHARED_BASENAMES"
    line: 267
    claim: "목록이 비면(빈 튜플) _shared는 늘 False다. 그러면 plugin.json · CHANGELOG.md · README.md를 예약한 블록끼리도 겹침으로 잡히고, 그 파일을 바꾼 브랜치는 경로 예약 위반 정보가 된다. 지금은 설정이 없으므로 「값 없음」은 언제나 상수 세 이름이다. 빈 목록 동작은 코드 경로로 추론한 것이고, 테스트로 고정된 것은 아니다."
    touches: []
    decides: [OQ14]
  - id: RC20
    path: "plugins/spec-distill/scripts/roadmap_status.py"
    anchor: "def parallel_with(blocks, overlap_list) — \"경로 예약 겹침은 정보로 함께\" / def counts — \"notes · overlaps 는 정보라 세지 않는다.\""
    line: 1014
    claim: "겹침 목록의 하류 소비자는 넷이다. parallel_with는 동시 가능 목록의 `overlap` 칸을 만든다. 겹침은 경고 수에 들지 않는 정보다(1169 · 1183행). 사람용 글은 「경로 예약 겹침(정보): N개」로 보인다(1205행). 겹침은 종료 코드나 동시 가능 여부를 바꾸지 않는다(NOTICE 51–58행: 「경로 예약 겹침과 … 편집은 경고가 아니라 정보다」)."
    touches: []
    decides: [OQ14]
  - id: RC21
    path: "plugins/spec-distill/scripts/control_plane.py"
    anchor: "ov = report.get(\"overlaps\") or [] ... \"경로 예약 겹침(정보): %d개\" / row(\"동시에 갈 수 있는 에픽\", [p[\"id\"] + (\"(경로 예약 겹침: %s)\" ...)])"
    line: 356
    claim: "control_plane은 지도(show)의 겹침 줄(356–359행)과 에픽 보기의 동시 가능 칸(1222행)에서 report[\"overlaps\"] · parallel을 보인다. --tasks(tasks_output)는 겹침을 읽지 않는다."
    touches: []
    decides: [OQ13, OQ14]
  - id: RC22
    path: "plugins/spec-distill/scripts/spec_review_bundle.py"
    anchor: "overlap = {x for o in report[\"overlaps\"] if epic in o[\"blocks\"] for x in o[\"blocks\"] if x != epic}; near = set(deps) | set(dependents) | overlap"
    line: 113
    claim: "spec-review 묶음 진입은 rs.build(--roadmap-file)의 overlaps로 「가까운 에픽」을 고르고, 그 에픽들의 설계문서 결정을 읽는다. 공유 파일 목록이 바뀌면(특히 비면) 가까운 에픽 집합이 넓어져 읽는 설계문서가 늘어난다."
    touches: []
    decides: [OQ14]
  - id: RC23
    path: "plugins/spec-distill/tests/test_roadmap_status.sh"
    anchor: "assert_eq \"$(field_of OVERLAPS)\" \"[{'blocks': ['R2', 'R3'], ...}]\" \"실데이터: 의존 없이 겹치는 경로 예약은 정보 일곱 …\""
    line: 1072
    claim: "실데이터 락이 이 레포 로드맵의 rs.overlaps(blocks) 결과(겹침 일곱 쌍과 경로)를 글자 그대로 고정한다(1023행에서 출력). 공유 파일 판정이 바뀌어 겹침이 더해지거나 빠지면 RED다. 경로 예약 위반 정보는 I1/J1 fixture(260–263 · 298 · 320행)가 잠근다. 다만 공유 파일을 빼는 동작 자체(plugin.json 등이 겹침 · 위반에서 빠짐)를 직접 단언하는 테스트는 찾지 못했다."
    touches: []
    decides: [OQ14]
  - id: RC24
    path: "plugins/spec-distill/tests/test_repo_defaults.py"
    anchor: "def test_repo_layer_accepts_all_nine_keys_and_not_meta: self.assertEqual(len(rd.KEYS), 9)"
    line: 170
    claim: "키를 더하면 함께 바뀌는 락과 공시가 여럿이다. test_repo_defaults.py는 키 수 9(170행)와 values 순서 = KEYS(188행)를 단언한다. test_workspace_invariance.sh:30은 키 아홉을 리터럴로 나열하고, 189행이 「아홉 키 × 두 꼴」 파일 수를 센다. test_roadmap_ontology.py:59는 KEYS를 온톨로지 표 토큰과 대조한다. 공시 쪽은 references/roadmap-ontology.md:24(「닫힌 집합 아홉」) · README.md:253–258(키 표 · 「키는 위 아홉뿐이다」)이다."
    touches: []
    decides: [OQ14]
unanswered: "--tasks 출력을 기계로 파싱하는 소비자(스크립트 · 훅 · 상태줄)는 레포에 없다. 소비자는 지휘 세션 모델(conducting.md 손 절차 1)과 테스트뿐이다. 그래서 탭 없는 줄이 섞일 때 모델이 어떻게 처리할지는 레포가 정하지 않는다. 빈 목록일 때 겹침 판정은 코드로 추론한 것이고, 테스트로 실측된 것은 아니다."

### 조사 5 — repo-researcher · R9 · 묶음 5

질문 (1)부터 답한다. 이 레포의 절차는 병렬 PR 둘을 만났을 때 머지 명령 줄을 하나씩만 내라고도, 둘을 함께 내도 된다고도 적지 않았다. 순서를 강제하는 규칙은 쌓인 PR(stacked PR)에만 있다. (2)의 핵심은 셋이다. neighbors()는 이웃 에픽의 결정을 커밋된 브랜치 끝에서만 읽는다. 진행 중인 병렬 에픽을 따로 고르는 신호는 단계 값이 아니라 `parallel` 필드인데 neighbors()는 그것을 쓰지 않는다. 그리고 `B<n> · 결정` 꼴의 줄만 보이므로 최근 설계문서 대다수에서는 「결정 줄 없음」이 나온다. 근거는 아래 repo_claims 다.

```yaml
repo_claims:
  - id: RC1
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### 5. 머지 전 확인 — 「끝으로 `superpowers:verification-before-completion`. 릴리스 번호는 이때 정한다(먼저 머지되는 쪽이 낮은 번호). 머지 명령 줄만 준비하고 머지는 사용자가 한다.」"
    line: 61
    claim: "걸음 5 는 PR 마다 pr-refresh → 스위트 대조 → 통합 리뷰 → 리뷰 뒤 반영 → 완료 전 확인을 한 뒤 머지 명령 줄만 준비한다. PR 이 둘일 때 그 줄을 한 번에 하나만 내라는 문장도, 둘을 함께 내도 된다는 문장도 없다. 「먼저 머지되는 쪽이 낮은 번호」는 준비할 때 두 PR 의 머지 순서가 정해진다는 전제만 담는다."
    touches: []
    decides: [OQ11]
  - id: RC2
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### 5. 머지 전 확인 — 「쌓인 PR: … 앞 PR 부터 머지하고, 머지 뒤 그 바탕 브랜치를 지우기 전에 위 PR 의 바탕을 기본 브랜치로 바꾼다 … 머지 명령을 준비하기 전에 `ledger pr-record` … → `ledger pr-refresh` …」"
    line: 60
    claim: "머지 순서를 강제하는 규칙은 쌓인 PR(앞 계획 브랜치를 바탕으로 연 PR)에만 있다. 앞 PR 머지 → 바탕 변경 → pr-record → pr-refresh → 머지 명령 준비 순서다(test_conducting_reference.sh:287-293 의 AC17 체인 락이 이 순서를 고정한다). 바탕이 기본 브랜치인 병렬 에픽 PR 둘에는 이 순서 규칙이 닿지 않는다."
    touches: []
    decides: [OQ11]
  - id: RC3
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### 6. 머지 뒤 — 「머지를 확인하면(상태 계산의 「머지됨」) 열린 에픽 브랜치마다 기본 브랜치를 merge 하고 스위트 대조를 다시 돈다.」"
    line: 67
    claim: "첫 PR 이 머지되면 열린 에픽 브랜치마다 기본 브랜치를 merge 하고 스위트 대조를 다시 돈다. 다시 도는 것은 스위트 대조뿐이고 통합 리뷰를 다시 돈다는 말은 없다. 이미 준비해 둔 둘째 PR 의 머지 명령 줄을 거두거나 보류하라는 말도 없다."
    touches: []
    decides: [OQ11]
  - id: RC4
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "손으로 따르는 절차 6. **머지 뒤.** — 「열린 에픽 브랜치에는 기본 브랜치를 merge 하고 대조(8)를 다시 돈다 — 그 브랜치에서 agent 가 일하는 중이면 직접 merge 하지 않고 돌아올 때까지 기다린다.」"
    line: 100
    claim: "손 절차 6 은 머지 뒤 「대조(8)」를 다시 돈다고만 적는다. 8 의 세 항목(스위트 대조 · 통합 리뷰 · 리뷰 뒤 반영) 가운데 어디까지가 「대조」인지 정하지 않았다. 둘째 PR 의 머지 명령 줄이 이 재대조를 기다려야 한다는 문장은 없다."
    touches: []
    decides: [OQ11]
  - id: RC5
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "손으로 따르는 절차 8 **스위트 대조.** — 「기본 브랜치가 움직이면 다시 돈다.」 / 「릴리스 번호는 머지 직전에 정한다 — 먼저 머지되는 쪽이 낮은 번호다. 머지 명령 줄만 준비하고 머지는 사용자가 한다.」"
    line: 103
    claim: "손 절차 8 은 기본 브랜치가 움직이면 스위트 대조를 다시 돌라고 한다. 그래서 첫 PR 머지 뒤 둘째 PR 의 대조는 낡은 것이 되지만, 머지 명령 줄을 그 재대조 뒤로 미루라는 규칙으로 이어지지는 않는다. 손 절차에서는 릴리스 번호를 「머지 직전」에 정하고(107행), 걸음 5 에서는 「이때」(완료 전 확인 때) 정한다. 두 표현이 다르다."
    touches: []
    decides: [OQ11]
  - id: RC6
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "손으로 따르는 절차 8 **통합 리뷰.** — 「합친 사본 · 이 PR 의 diff · 아직 열린 다른 에픽의 기본 브랜치 대비 diff · 앞선 통합 리뷰가 이 PR 에 넘긴 항목을 주고 … 「이 PR 이 머지 전 고침」과 「뒤에 머지되는 에픽이 고침」으로 나눠」"
    line: 104
    claim: "통합 리뷰는 아직 열린 다른 에픽의 diff 와 충돌 미리 보기(merge-tree)를 함께 본다. 걸음 5 의 `ledger review-pack` 도 열린 다른 에픽 diff 와 충돌 미리 보기를 모은다. 그래서 둘째 PR 리뷰는 첫 PR 이 머지되기 전에도 첫 PR 의 변경을 본다. 지적은 「뒤 에픽이 고침」 인계로 순서에 따라 나뉜다."
    touches: []
    decides: [OQ11]
  - id: RC7
    path: "plugins/spec-distill/scripts/merge_check.py"
    anchor: "rc, base_sha, _e = git(root, \"rev-parse\", \"--verify\", \"--quiet\", DEFAULT_REF + \"^{commit}\")"
    line: 137
    claim: "스위트 대조는 실행하는 순간의 기본 브랜치(DEFAULT_REF) SHA 로 합친 사본을 만든다. 앞선 대조의 기준 SHA 를 저장해 두었다가 기본 브랜치가 움직였을 때 낡았다고 알리는 장치는 이 파일에 없다."
    touches: []
    decides: [OQ11]
  - id: RC8
    path: "plugins/spec-distill/scripts/spec_review_bundle.py"
    anchor: "def neighbors — `tree = main if b[\"stage\"] == \"머지됨\" else (b.get(\"tip\") or main)` · `text = git.blob(tree, spec) if tree else None`"
    line: 120
    claim: "neighbors() 는 이웃이 「머지됨」이면 기본 브랜치(origin/HEAD 커밋)에서 설계문서를 읽고, 아니면 그 에픽 브랜치 끝(roadmap_status 의 tip)에서 읽는다. tip 이 없을 때만 기본 브랜치로 돌아간다."
    touches: []
    decides: [OQ12]
  - id: RC9
    path: "plugins/spec-distill/scripts/roadmap_status.py"
    anchor: "def blob — `self.run(\"cat-file\", \"blob\", \"%s:%s\" % (rev, path))` / def judge — `local = git.commit(\"refs/heads/\" + br)` · `remote = git.commit(\"refs/remotes/origin/\" + br)` · `st = {\"branch\": br, \"tip\": local or remote, ...}`"
    line: 122
    claim: "blob 은 커밋된 객체만 읽는다(git cat-file). 이웃 worktree 의 커밋하지 않은 작업 트리 내용은 보이지 않는다. tip 은 로컬 refs/heads/<브랜치>가 있으면 그것, 없으면 origin 쪽 ref 다. 한 clone 의 worktree 들은 refs/heads 를 함께 쓰므로, 같은 레포의 다른 worktree 에서 커밋만 하고 push 하지 않은 것도 보인다."
    touches: []
    decides: [OQ12]
  - id: RC10
    path: "plugins/spec-distill/scripts/spec_review_bundle.py"
    anchor: "def neighbors — `if b[\"id\"] not in near or not b[\"specs\"]: continue`"
    line: 118
    claim: "specs 가 빈 이웃은 출력에서 조용히 빠진다(「결정 줄 없음」 줄도 없다). 브랜치는 있는데 아직 spec 이 커밋되지 않은 에픽(roadmap_status progress 의 「설계 중 · 브랜치 있음 · spec 없음」)과 브랜치가 없는 준비 · 대기 에픽이 여기에 든다. 이 단계들의 specs 는 빈 목록으로 나온다(roadmap_status.py:348, 824 초기화)."
    touches: []
    decides: [OQ12]
  - id: RC11
    path: "plugins/spec-distill/scripts/spec_review_bundle.py"
    anchor: "near = set(deps) | set(dependents) | overlap"
    line: 114
    claim: "지금 near 는 의존 · 이 에픽에 의존하는 에픽 · 경로 예약 겹침의 합집합이다. 겹침(roadmap_status.overlaps)은 서로 의존이 없는 블록 쌍 가운데 경로 예약이 겹치는 것만이다(공유 파일 plugin.json · CHANGELOG.md · README.md 는 뺀다). 의존도 경로 겹침도 없는 병렬 에픽은 near 에 들지 않는다(test_spec_review_bundle.sh:105 「의존도 겹침도 없는 R6 은 내지 않는다」가 이것을 고정한다)."
    touches: []
    decides: [OQ12]
  - id: RC12
    path: "plugins/spec-distill/scripts/roadmap_status.py"
    anchor: "def parallel_with — 「블록마다 함께 갈 수 있는 끝나지 않은 블록 — 의존 관계가 어느 쪽으로도 없는 것」 / build — `\"parallel\": parallel.get(b[\"id\"], [])`"
    line: 1014
    claim: "상태 계산 보고서는 블록마다 `parallel` 목록을 이미 낸다. 끝나지 않았고(DONE 아님) 어느 쪽으로도 의존이 없는 블록들이다. 이 목록은 준비 · 대기처럼 아직 시작하지 않은 블록도 담는다. neighbors() 는 이 필드를 쓰지 않는다."
    touches: []
    decides: [OQ12]
  - id: RC13
    path: "plugins/spec-distill/scripts/roadmap_status.py"
    anchor: "TASK_STATUS = {\"대기\": \"pending\", \"준비\": \"pending\", \"설계 중\": \"in_progress\", \"계획\": \"in_progress\", \"구현 중\": ..., \"구현 끝\": ..., \"PR\": ..., ...} / def progress — `return \"설계 중\", \"spec 승인됨(%s) · 계획 없음\" % when, ...`"
    line: 61
    claim: "단계 값으로 진행 중(in_progress)을 가를 수 있다. 설계 중 · 계획 · 구현 중 · 구현 끝 · PR · 일부 머지가 진행 중이다. 다만 「설계 중」 하나에 서로 다른 넷이 섞인다. 브랜치만 있고 spec 이 없는 것, spec 이 있는 것, 지휘 기록을 못 읽은 것, spec 승인 · 계획 없음이다. 이 넷은 단계가 아니라 reason 문자열과 block[\"approved\"] 날짜로만 갈린다."
    touches: []
    decides: [OQ12]
  - id: RC14
    path: "plugins/spec-distill/references/conducting.md"
    anchor: "### 3 spec 리뷰 — 「설계문서는 이 세션이 brainstorming 끝에 써서 에픽 worktree 에서 커밋하고 … 리뷰 반영 커밋도 그 worktree 에서 한다」 / 승인 게이트 — 「미커밋 확인 → 승인 줄 기록(`ledger record … --approval`) · 그 에픽 worktree 에서 커밋」"
    line: 38
    claim: "커밋 시점은 다음과 같다. ① brainstorming 대화 중(첫 메시지부터 설계문서 작성 전)에는 설계문서가 브랜치에 없다. ② brainstorming 이 끝나면 설계문서가 커밋된다. ③ 리뷰 중 반영은 그 worktree 에서 커밋하지만, 엔진이 쓰는 계수 줄 · 박제는 2단계 앞 advisory 펜스에서 작업 트리에 쓰이고 승인 직전 미커밋 확인 때 커밋된다(spec-review/SKILL.md:589-596). ④ 승인 줄은 승인 직후 커밋된다. 따라서 설계 대화 중인 에픽은 neighbors 가 읽을 커밋된 결정이 없고, spec 이 승인된 직후의 에픽은 커밋된 설계문서와 결정 기록이 브랜치 끝에 있다."
    touches: []
    decides: [OQ12]
  - id: RC15
    path: "plugins/spec-distill/scripts/spec_review_bundle.py"
    anchor: "DECISION_LINE_RE = re.compile(r\"- B\\d+ · 결정 · \")"
    line: 32
    claim: "neighbors() 는 `## 결정 기록` 에서 `- B<n> · 결정 · ` 꼴 줄만 보인다. 리뷰 엔진의 decide 가 쓰는 결정 줄은 `- D<r>.<n> · r<n> · <choice> · …` 꼴(docreview_state.py `_log_line`, 1416행)이라 이 정규식에 걸리지 않는다. B 줄은 brainstorming 의 결정을 손으로 적은 줄이거나 결정 줄 펜스(기각 되돌림 · 재결정 · 재분해)로 쓴 줄이다. 실측하면 docs/superpowers/specs 에서 B 줄이 있는 설계문서는 8개다. D 줄만 있고 B 줄이 없는 설계문서도 많다(예: 2026-10-23-r8-device-leftovers-design.md 의 D 줄 19개 · B 줄 0개). 이런 이웃은 near 에 들어도 「결정 줄 없음」으로 나온다."
    touches: []
    decides: [OQ12]
  - id: RC16
    path: "plugins/spec-distill/skills/spec-review/SKILL.md"
    anchor: "**로드맵 속 위치와 이웃 결정 — 2단계 질문 바로 앞.** / `<!-- roadmap-position:begin -->`"
    line: 673
    claim: "neighbors 는 승인 게이트 2단계 질문 바로 앞에서 한 번 돈다. 이웃 결정은 그 순간 이웃 브랜치에 커밋돼 있는 것만 반영되고, 이후 이웃이 커밋하는 결정은 이 게이트에 다시 오지 않는다."
    touches: []
    decides: [OQ12]
unanswered: "병렬 PR 둘의 머지 명령 줄을 하나씩 내야 하는지 둘을 함께 내도 되는지는 레포가 어느 쪽으로도 정하지 않았다(RC1–RC5). 손 절차 6 의 「대조(8)」가 통합 리뷰 재실행까지 포함하는지도 레포가 답하지 않는다."

## R9

### 지금 이해
빈 곳 조사(조사 4 · 5 · 6)가 결정 넷을 흔들었다. ① 병렬 PR 둘의 머지 순서를 정한 규칙이 레포에 없다 — 첫 PR 머지 뒤 다시 도는 것은 스위트 대조뿐이고 통합 리뷰는 다시 돌지 않는다(RC31~RC35). S13 은 ⑦ 이 「이미 있다」 는 전제로 한 줄로 줄였는데 그 전제가 반증됐다. ② spec 리뷰가 이웃 에픽 결정을 보이는 장치는 `- B<n> · 결정 ·` 줄만 읽고, 리뷰 엔진이 쓰는 `- D<r>.<n> ·` 결정 줄은 읽지 않는다 — R14 설계문서는 D 줄 19개 · B 줄 0개라 「결정 줄 없음」 으로 보인다(RC45). ③ 작업 목록 출력은 줄마다 제목 · 탭 · 상태 두 칸이라는 계약이 코드 · 테스트 · README · 절차 문서 여섯 자리에 걸려 있다. ④ 설정 키는 닫힌 집합이고 목록 값을 받는 키가 없으며, 빈 값을 오류로 두면 상태 계산 전체가 멈춘다.
조사 호출 5/60 · 이 라운드 본체 직접 1
- 확인 RC31 — 확인 — plugins/spec-distill/references/conducting.md#### 5. 머지 전 확인 — 병렬 PR 머지 순서 규칙 없음(:61)
- 확인 RC45 — 확인 — plugins/spec-distill/scripts/spec_review_bundle.py#DECISION_LINE_RE — `- B\d+ · 결정 · ` 만(:32) · R14 설계 B 0 · D 19
- 확인 RC46 — 확인 — plugins/spec-distill/scripts/control_plane.py#def tasks_output — 호출자 하나(:1320)
- 확인 RC47 — 확인 — plugins/spec-distill/scripts/repo_defaults.py#KEYS — 닫힌 집합(:36) · COUNT_KEYS(:30)
(조사 5 · 6 의 나머지 RC 는 원문 블록 그대로 — 경로 · 앵커 실재 확인)

### 다음 결정
OQ11: 병렬 PR 머지 순서 · 추천: 머지 명령 줄은 한 번에 하나, 첫 머지 뒤 둘째는 스위트 대조와 통합 리뷰를 다시 돈 뒤 낸다(S13 의 ⑦ 재결정)
OQ12: 이웃 결정 노출 · 추천: 결정 줄 꼴을 D 줄까지 읽게 고치고 진행 중인 병렬 에픽을 near 에 넣는다
OQ13: 작업 목록 줄 계약 · 추천: 작업 목록 끝에 탭 없는 한 줄로 싣고 계약 문장 · 테스트를 함께 고친다(S8 유지)
OQ14: 공유 파일 설정 · 추천: 한 줄 쉼표 목록, 없거나 깨지면 기본 셋으로 쓰고 경고(멈추지 않음)

### 질문
(b) 판단 · 묶음 넷 — OQ11 · OQ12 · OQ13 · OQ14

### 답
→ S16 「진행」 — 묶음 넷 질문을 거두고 「진행」 이라 해 넷 모두 추천안으로 정했다(OQ11 하나씩 · 다시 확인 뒤 / OQ12 두 꼴 · 병렬도 / OQ13 끝에 탭 없는 한 줄 / OQ14 기본 셋 + 경고). 다르게 원하면 사용자가 말한다고 알렸다.

## R10

### 지금 이해
포화 판정 2: 아직 — 빈 곳 다섯(OQ15~OQ19). 대부분 정한 것의 세부라 설계로 넘기기를 권했다.

### 답
→ S17
