---
type: interview-audit
payload: 2026-09-02-seam-channel-verification-interview.md
created_at: 2026-09-02
session_id: 9c86cff5-c2db-443f-999f-e78461a75f7a
source: spec-distill conducting-interview v0.47.0
---

# 이음매 채널 검증 — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

- floor:root_problem — closed — R1 에서 사용자가 「채널 미검증」을 뿌리로 선택(S3). 확인된 다섯 자리의 공통점이 강제 부족이 아니라 도달 검사층 부재
- floor:landscape — closed — web sweep 3회 + 두 적대 에이전트의 근거 수집. 취함 4·피함 2·중립 5. URL 은 §7 에만
- floor:skepticism — closed — ST1 steelman → verdict switched(부분). 원안 유지 + 하드코딩 추출을 범위에 추가(S9). 전면 전환은 기각
- floor:blind_spot — closed — blind-spot-prober(자기 confidence 0.78) 가 숨은 가정 8 + 실패 양식 12 를 표면화하고 사용자에게 확인됨. payload §5 위험 항목으로 기록
- floor:open_questions — closed — OQ 11건 박제. 빈도·대화형·파일변경훅 원인·목록 오표시 판정 포함
- derived:seam-typology — closed — 「이 넷이 전부인가」는 열거로 답 불가, 축 조합으로 생성해야 답 가능; 축 넷에서 자리 11개 도출, 범위 넷 확정(S5)
- derived:transport-channel — closed — 채널마다 도달률이 다르고 프로덕션이 정확히 반대로 배선됨; 재측정으로 압축 사슬 3/3·커맨드 확장 1/1 확인, 파일변경 훅은 반증
- derived:failure-direction-and-observer — closed — 방향 선택이 어디에도 명시 없음; 소비자가 0이므로 구별 포기(S10)
- derived:deployment-unit-boundary — closed — 판정 기준을 설치본에서 참으로 못 박아야 세 갈래를 고를 수 있음; 대체물 없이 걷어내기(S8)
- derived:evidence-shelf-life — closed — 근거가 전부 단일 버전·변형당 1회; 사용자 요청으로 5건 재측정(S14), 빈도·대화형은 OQ 로 이월

## 2. Budget

- 질문 라운드: 7 · agent dispatch: 3 (coverage-mapper 1 · blind-spot-prober 1 · steelman-builder 1) · codex 실호출: 0 (성공 0)
- 추가 지출: web 검색 3회 · web fetch 1회 · 헤드리스 하니스 실측 6 세션
- 분리 리뷰 지출: agent 5/5 (direction 1 · critic 3 · readback 1) · codex 4/4 (direction 1 · fidelity 3) · critic 재라운드 2/2 — 셋 다 상한 도달

## 3. Steelman 원문

#### ST1 — 자리별 처방 대신 검증된 강제기의 목적지·스코프 하드코딩을 데이터로 빼낸다

> **alternative_statement** — "자리별 처방을 버리고 이음매를 **생성하는 규칙**을 고친다 — (a) 유일하게 검증된 강제기(`review-dispatch.py` + `arm_ledger.py`)의 «목적지»와 «스코프»를 코드 리터럴에서 데이터로 빼내 모든 이음매가 같은 7/7 채널을 쓰게 하고, (b) 이음매의 방향을 뒤집어 수신자가 자기 진입 조건을 선언하게 한다(skill `description` = 조건 · 훅 matcher = 호스트 발화). 넷이 아니라 열한 자리와 아직 존재하지 않는 자리까지 같은 검사를 받는다."
>
> **strongest_case** — "devbrew 는 이 변환을 이미 한 번 성공적으로 했다 — `shared/tests/test_dispatch_disposition.sh` 헤더가 «열거는 fail-open 이다, 저자가 두 번 물렸다»고 적고 ∀ 정의집합에서 도출한다. 이음매 쪽만 아직 열거다. 그리고 그 열거를 강제한 것은 설계 판단이 아니라 **하드코딩 한 곳**이다: `review-dispatch.py` 가 `reviewing-spec` 을 7자리에 리터럴로 박고 `arm_ledger.py:41` 이 `PREFIX` 로 스코프를 박았기 때문에, 검증된 유일한 메커니즘을 재사용할 길이 없어 자리마다 새 운반자를 발명해야 했다. 즉 자리별 처방은 원인이 아니라 **그 하드코딩의 증상**이다. 더구나 수신자-선언 표면은 이미 존재하고 devbrew 가 안 쓰고 있다 — `reviewing-brief` 는 `description` 에 「무엇을 하는가」만 적고 「언제 깨어나는가」를 안 적었으며, `disable-model-invocation` 을 안 걸었으므로 자동 로드 경로가 열린 채로 비어 있다."
>
> **weakness_of_current** — "현재 방향은 **자기가 고르는 자리 목록의 근거를 스스로 무너뜨린 상태**에서 그 목록대로 간다. 축을 세우자 4자리가 11자리가 됐고 깨진 것은 전부 같은 축값(payload·모델운반)이었는데, 처방은 여전히 넷이다 — 나머지 일곱과 «아직 만들어지지 않은 이음매»는 처방 밖이다. 그리고 이 리포의 락 헤더가 그 실패 양식을 이미 이름 붙여 두었다: 「열거는 fail-open 이다 — 저자가 두 번 물렸다」. 결정적으로, 네 자리를 각각 열어 채널을 붙이면 검증된 채널은 하나뿐이므로 자리마다 arm-once 급 재발동 가드(선례 589줄)를 새로 만들게 되고, 그것이 바로 whack-a-mole 의 비용 형태다."
>
> **confidence** — 0.62
>
> **builder 자신이 제출한 반대 근거** — Sandi Metz: *"duplication is far cheaper than the wrong abstraction."* 알려진 이음매 인스턴스가 3~4개뿐이면 rule of three 를 겨우 만족하는 수준이고, 틀린 추상은 파라미터와 조건문으로 부패한다.
>
> **구현 가능성 판단** — 갈래 B(검사를 한 곳으로 모은다)는 지금 구현 가능하며 새 표면 0개다. 갈래 A(방향을 뒤집는다)는 층에 따라 갈리고 결정론 부분이 전부 미측정이다. 순서는 «B 먼저 → A 는 matcher 재측정 뒤».
>
> **builder 의 계약 충돌 자진 신고** — evidence URL 은 builder 계약이 요구한 것이므로 audit 에만 남기고 payload 본문으로 전파하지 말 것.

## 4. 게이트 실행 기록

- check_brief.py gate — pass (2026-09-02) — web: enabled — 총 7회 실행(확정 반영 후 포함) 전부 통과(최초 · C4 재결정 후 · 충실도 R1·R2·R3 후 · 냉독 반영 후), failures 0 · advisories 0
- check_verbatim_coverage.py — exit 0 (2026-09-02) — 총 6회 실행 전부 exit 0, missing_ids 0 · not_contained 0 · advisories 0

## 5. 프로세스 로그

- round 0: path (a) — seed 의 코드 주장 대조. 네 곳 어긋남 발견 (권한 키 항목 수 163→59 · 넷째 인자가 산문 지체가 아니라 실제 결손 · probe 자산이 둘로 갈림 · 처분 앵커 20→21)
- round 1: path (d) ontological ROOT_CAUSE — 진짜 문제 선택. teach-heavy
- round 2: path (b) judgment — qg 발행 이음매. 발견: offer 가 「제어가 커맨드로 돌아오면」이라는, 하니스가 제공하지 않는 제어흐름을 전제
- round 3: path (b) judgment ×2 — 축 넷에서 자리 11개 도출, 범위와 형제 경계. 사용자가 「앞의 선택이면 변경되나?」를 함께 물어 답변
- round 4: path (b) judgment — probe 선결조건. 사용자가 하드코딩 점검을 함께 요청
- round 5: path (b) judgment — steelman 게이트. 사용자가 다른 곳 하드코딩 점검을 함께 요청
- round 6: path (b) judgment ×2 — 구별 포기 · systemMessage 수신자 오배정
- round 8: Step B proceed 게이트 — 사용자가 옵션 ①(확정 후 /compact → brainstorming) 선택. 31항목 전부 provisional→confirmed, sentinel 한 줄 제거, §0 문면 갱신. 게이트·완전성 재실행 둘 다 통과. **세 라운드 연속 지적된 sentinel 귀속 문제가 이 전이로 해소됨** — 그 문구는 확정 전에만 참이라 두 계약이 서로 다른 시점을 보고 있었다
- round 7: path (a) 실측 — 사용자 「재측정 해봐」. 5건 측정, 픽스처를 `shared/tests/fixtures/seamprobe/` 로 체크인
- 정정 1: round 3 표가 압축 이음매의 갭을 「압축 전 훅 0개」로 적었으나, 올바른 자리는 세션 시작 훅의 matcher 이며 압축 전 훅도 별도 용도로 유효함이 실측으로 밝혀짐
- 정정 2: seed 의 systemMessage 프레이밍이 반쪽 — 그 채널의 수신자는 사람이므로 degrade advisory 자리는 결함이 아니고, 결함은 모델 지시를 그 채널에 실은 한 자리

### brief 리뷰 라운드 (reviewing-brief, v0.24.0)

- 방향성: Claude 11건 / codex 7건 (block 2) — 사용자 재결정 2건(C3·C12) + 재확인 1건(C7) + 범위 추가 2건(C18·C19). 두 리뷰어가 독립 수렴한 지점 셋이 전부 사용자 결정을 뒤집자는 것이었고 둘은 수용, 하나는 재확인됨
- 충실도 상세: R1 critic 9 + codex 5 (겹침 3) → needs_revise · R2 critic 9 + codex 6 → needs_revise · R3 critic 7 + codex 4 → needs_revise. 최종 라운드에서 codex 는 approved(전부 medium), Claude critic 은 needs_revise(high 1) 로 갈렸고 fail-closed 합집합이 needs_revise 를 냈다. 재라운드 상한 2 도달 → forced escalate. 누적 27건 중 26건 반영, 1건 미반영
- 미반영 1건: frontmatter sentinel 「confirmed 0건 — 사용자가 전부 잠정으로 판단」의 사용자 귀속. 세 라운드 연속 지적됐고 지적이 옳으나, 그 문구는 구조 게이트가 요구하는 리터럴이라 지우면 게이트가 red 를 낸다 — brief 의 결함이 아니라 spec-distill 의 두 계약이 충돌하는 자리다
- 최종 라운드 이후 적용한 수정(critic R3 7건 + codex R3 4건 + 냉독 3건)은 **어느 리뷰어도 검증하지 않았다** — 재dispatch 상한 소진
- 충실도 기록(게이트 아님, 마지막 관측 verdict만 기재): 미실행 — critic 0건 / codex 0건 — 재라운드 0/2
- 냉독: 실행됨. 문서의 진짜 결함 4건 지적 — OQ 번호 역순 · 「열하나」의 실물 미기재 · C11 시제 충돌 · 리포 고유 용어의 지시 대상 부재. 넷 다 반영
- 냉독 신뢰도 하향: 오케스트레이터가 blob 을 바이트 그대로 인라인하지 않고 축약했다. 냉독이 「§2·§4·§5·§6 이 내용이 아니라 내용에 대한 설명으로 렌더돼 있다」·「S2~S18 을 확인할 방법이 없다」를 지적한 것은 문서가 아니라 그 축약의 성질이다 — 독립 재현이므로 degrade 판정의 근거로 삼되 문서 결함으로 세지 않는다
- degrade: 5건 — critic/fidelity degraded ×2 (번들 위생 rc=3, frontmatter audit_file 이 구조적 원인) · critic/fidelity degraded (재리뷰 상한 초과 + 최종 수정 미검증) · readback/readback degraded ×2 (blob rc=3 는 S1 안의 seed audit 파일명 = 정당한 원문 보존 · 오케스트레이터 축약). fallback 채널 0건
- 격리: zero-tool probe **ZERO_TOOL_OK** — 충실도 verdict 는 hard gate 분기. `codex_isolated: false`

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S2** 🗣 발화:
  > 구현은 워크트리 생성해서 진행

- **S3** ☑ 선택 (진짜 문제):
  > 「채널 미검증 (추천)」 선택 — 뿌리 = 이음매마다 「지시가 실제로 도달하는가」가 검증된 적이
  > 없다. 목표 = 각 자리에 채널 + 도달 증거를 붙이고, 못 붙이는 자리는 약속을 거둔다.
  > 강제/알림/삭제는 자리마다 갈리되 근거 없는 자리를 남기지 않는다. 확인된 다섯 자리의
  > 공통점은 「강제 부족」이 아니라 「도달 검사층 부재」다.

- **S4** ☑ 선택 (qg 발행 이음매):
  > qg 발행 이음매 = 「같은 턴 안쪽으로 (추천)」 선택. offer 를 qg.md 산문에서
  > quality-pipeline SKILL 종료 지점으로 옮긴다. 전제되던 「제어가 이 커맨드로 돌아오면」이
  > 사라진다. 새 훅 없음, 폭주 가드 없음, 동의 게이트 두 겹 그대로. 대가로 「게이트 뒤에
  > 얹힌 opt-in 연속」이라는 층위 구분이 흐려지는 것을 받아들인다.

- **S5** ☑ 선택 (범위):
  > 새로 도출된 자리 중 범위 = 「A — 결함 확인된 셋」 + 「B — /compact 이음매」.
  > 즉 #5 펜스→펜스(finishing.md 죽은 셸 변수 + <file> 자리표 + 인자 3/4) ·
  > #6 sentinel(publish-eligible 생산 2 · 소비 산문 1 · 매 실행 삭제) ·
  > #7 레포→설치본(probe 선결조건) · #8 /compact 이음매(세 자리, PreCompact 훅 0개).
  > C(devbrew→superpowers) 와 D(subagent·스크립트 왕복) 는 미선택.

- **S6** ☑ 선택 (형제 경계):
  > 형제 세션 경계 = 「경계를 축으로 다시 그어라」 선택. 저쪽 = 처분이 무엇으로 판정되고
  > 어떻게 회계되는가(내용), 이쪽 = 그 dispatch 와 복귀가 이음매로서 성립하는가(운반).
  > 같은 코드를 다른 질문으로 본다. 겹치는 파일이 생기므로 통지 경로를 먼저 정해야 한다.
  > 사용자가 함께 물음: 「앞의 선택이면 변경되나?」

- **S7** ☑ 선택 (#10 운반):
  > #10(스킬→subagent→복귀)의 운반 절반 = 「아니오 — A+B 로 닫는다」 선택. 이번엔
  > #5·#6·#7·#8 넷을 끝낸다. #10 운반은 brief 의 Non-goals 에 「이쪽 소관 · 이번 미착수」로
  > 명시한다 — 「저쪽 것」이 아니라 「이쪽 것인데 나중」이라서, 서로 미룰 것이 아니라
  > 임자가 있는 연기가 된다.

- **S8** ☑ 선택 (probe 선결조건):
  > #7 probe 선결조건 = 「그냥 걷어낸다」 선택. reviewing-brief/SKILL.md:107 절과
  > test_brief_agents.sh 의 probe 게이트를 삭제하고 대체물을 두지 않는다. 「가능하면
  > 걷어내는 쪽으로」에 가장 충실하고 가장 가볍다. 남는 방어는 테스트 스위트의 AC4 토큰
  > 검사뿐이고 그것은 스킬 진입 시점엔 돌지 않는다 — Law 2 가드가 CI 없는 리포에서
  > 수동 테스트 실행에만 의존하게 된다.
  > 함께 요청: 「우리 레포의 하드코딩이 있는 경우도 봐줘.」

- **S9** ☑ 선택 (steelman 게이트):
  > steelman 게이트 = 「부분 전환 — 하드코딩만」 선택. 원안(자리별 처방)을 유지하되
  > 하드코딩 세 줄(목적지 리터럴 · PREFIX 중복 · stop_hook_active 미참조)을 범위에
  > #12 로 추가한다. 새 추상은 만들지 않는다 — 데이터로 빼내기만 해서 다음이 재사용할
  > 수 있게 한다. 전면 전환(강제기 데이터-구동 재설계)은 기각.
  > 함께 요청: 「다른곳 하드코딩 있는지 확인해줘.」

- **S10** ☑ 선택 (안돌림 vs 깨끗):
  > 「안 돌림 vs 깨끗함」 구별 = 「구별 포기 — 소비자가 없다」 선택. 지금 이 신호를 읽는
  > 소비자가 0이다. check_brief.py:25 의 「brief 파일만 읽는다」 불변식과 arm_ledger.py:41
  > 의 PREFIX(= interview 디렉토리 제외) 둘 다 그대로 두면 세 번째 층을 안 만들어도 된다.

- **S11** ☑ 선택 (systemMessage):
  > systemMessage 두 자리 = 「수신자 오배정만 고친다」 선택. 모델에게 하는 말을 사람 채널에
  > 실은 것만 결함이다 — qg post-tool-use.py:85 의 「You MUST now … Skill(...)」.
  > 사람에게 하는 말(review-dispatch.py :337 :381 :463 :647 의 degrade advisory)은 손대지
  > 않는다 — 걷어내면 loud logging 규범 위반.

- **S12** ☑ 선택 (재측정 범위):
  > 태울 측정 = 「FileChanged 재측정」 + 「SessionStart matcher=compact 실측」 둘.
  > 빈도(전이가 매번 되는가)와 대화형(allowed-tools 게이트)은 미선택 — §3 Open Questions 로.

- **S13** ☑ 선택 (#8 채널):
  > #8(/compact 이음매) 채널 = 「SessionStart matcher=compact」 선택. 훅이 운반하고 사람은
  > 여전히 진행을 트리거한다(P17 승인 게이트 유지). 지금은 사용자가 /compact 프롬프트에
  > 「다음 단계: Skill superpowers:brainstorming <brief-path>」를 실제로 붙여넣어야 한다.

- **S14** 🗣 발화:
  > 재측정 해봐

- **S15** ☑ 선택 (#8 채널 재결정):
  > C4 재결정 — #8 /compact 채널을 「PreCompact matcher=manual 로 변경」으로 뒤집는다.
  > SessionStart matcher=compact 는 수동/자동을 구별하지 못해 「사람이 트리거」 보장이
  > 깨진다는 두 리뷰어의 수렴 지적을 수용. PreCompact 는 manual 만 걸리고 stdout 이 압축을
  > 넘어 모델에 3/3 도달하며 payload 의 custom_instructions 로 도달 증거까지 낼 수 있다.
  > 함께 요청: 「이게 뭐를 하는지 쉽게 설명해줘.」

- **S16** ☑ 선택 (qg 이음매 재결정):
  > C4 재결정 — qg 발행 이음매를 「약속 철회 + /qg-publish 를 정본으로」로 뒤집는다.
  > qg.md 의 offer 절을 걷어내고 이미 출하된 /qg-publish 를 유일 경로로 명시한다. 사본이
  > 0 이 되고 NG6(no-skill-nesting) 락을 건드리지 않는다. 앞서 고른 「같은 턴 안쪽으로」는
  > NG6 위반 + 사본 1→3 + lost-in-middle 기전 사정권이라는 두 리뷰어의 지적으로 기각.

- **S17** ☑ 선택 (#7 재확인):
  > #7 probe 선결조건 = 「전부 지운다」 재확인. 리뷰어가 제기한 우려(양의 락 소실 · 충실도
  > verdict 의 hard-gate/advisory 분기 미정의)를 듣고도 원래 결정을 유지한다.

- **S18** ☑ 선택 (샌 자리 둘):
  > 어느 범위에도 없던 자리 둘을 범위에 넣는다 — project-init 의 유일 출력 채널
  > (post-tool-use.py:212) 과 check_brief.py:909 의 superpowers:brainstorming 하드 요구.
  > 둘 다 사용자 원문이 이름을 댔거나 #7 과 같은 실패 모양(devbrew 밖 차단)이다.

## 7. 확산 원자료

- «vscode-activation» — https://code.visualstudio.com/api/references/activation-events — 수신자가 기동 조건을 선언하고 호스트가 발화하는 모델
- «vscode-implicit-activation» — https://github.com/microsoft/vscode/pull/165783 — 선언에서 트리거를 자동 생성하는 후속
- «fowler-ioc» — https://martinfowler.com/bliki/InversionOfControl.html — 제어 역전이 프레임워크의 정의적 특성
- «shotgun-surgery» — https://refactoring.guru/smells/shotgun-surgery — 여러 자리의 작은 수정 = 빠진 추상의 이름
- «wrong-abstraction» — https://sandimetz.com/blog/2016/1/20/the-wrong-abstraction — 중복이 틀린 추상보다 싸다
- «lost-in-middle» — https://arxiv.org/abs/2307.03172 — 컨텍스트 중간의 정보가 덜 쓰인다
- «state-machine-orchestration» — https://hackernoon.com/deterministic-orchestration-how-state-machines-are-replacing-agent-loops-in-regulated-ai — 상태기계가 에이전트 루프를 대체한다는 처방
- «blueprint-first» — https://arxiv.org/pdf/2508.02721 — 결정론 워크플로 프레임워크
- «mast» — https://arxiv.org/abs/2503.13657 — 멀티에이전트 실패 분류와 전술적 수정의 한계
- «compliance-gap» — https://arxiv.org/pdf/2605.01771 — 프로세스 지시를 이해하고도 이탈하는 잔차
- «owasp-excessive-agency» — https://www.reversinglabs.com/blog/owasp-top-10-for-llm-apps-excessive-agency — 권한 결정을 모델 밖 결정론 시스템으로
- «pdp-pep» — https://docs.aws.amazon.com/prescriptive-guidance/latest/saas-multitenant-api-access-authorization/opa.html — 정책 결정과 집행의 분리
- «cc-hooks-registry» — https://code.claude.com/docs/en/hooks — 훅 이벤트·matcher·출력 계약. 번들 안 레지스트리가 더 정확하며 그 추출법은 `shared/tests/fixtures/seamprobe/MEASUREMENT.md`
- «nondeterminism» — https://arxiv.org/pdf/2408.04667 — temperature 0 에서도 비결정적
