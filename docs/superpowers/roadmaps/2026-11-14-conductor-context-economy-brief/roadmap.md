---
type: roadmap
source_brief: docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.md
test_command: bash tools/suite/run-all.sh
test_failure_pattern: "^FAILED (.+)$"
---

# 지휘 맥락 경제 — my-team 구조로 지휘 재설계 — 로드맵

승인된 분해안의 에픽 지도다. 에픽마다 원본 brief · 이 로드맵 · 에픽 묶음을 넘긴다. 상태 칸은 없다 — 단계는 spec-distill 의 `scripts/roadmap_status.py` 가 git 에서 계산한다. 단위는 로드맵 > 에픽(spec 하나) > plan(PR 하나) > task 다.

## 에픽

### P1 — 토큰 기준선
- 의도: 재설계 전 지휘 세션 · 하위 agent 토큰을 갈라 재어 비교 기준을 남긴다
- 범위: 한다: 백업한 세션 기록으로 캐시 읽기 · 쓰기 · 새 입력 · 출력을 갈라 측정(message.id 중복 제거) / 안 한다: 측정 도구 제품화
- 의존: 없음
- 브랜치: feature/token-baseline
- 묶음: P1.md
- 경로 예약: docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/token-baseline.md
- 크기: 작음
- 병렬: R1 과 병렬
- 순서 이유: 재설계 전에 재야 비교가 된다
- 근거: S31 · 조사 14
- 흐름: 조사 — 백업 기록에서 로드맵 세션을 골라 지휘 · 하위로 갈라 집계
- 산출물: docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/token-baseline.md

### R1 — 팀 파일 규약
- 의도: 과제 폴더 · INTENT.md · 역할 문서 · 규칙 목차 · 시작 묶음을 세워 읽기 설계의 바닥을 깐다
- 범위: 한다: 에픽 묶음 + 지휘 기록 → INTENT.md, results/, 역할 폴더(레포 공통) · 팀 전용 목록, 규칙 목차(새 이름) · HANDBOOK 운영과 경계 장치, 시작 묶음 고르기 스크립트, devbrew 파일 기준 단계 계산 / 안 한다: 지휘 절차서 개편
- 의존: 없음
- 브랜치: feature/team-file-contract, feature/team-file-read, feature/team-file-rules
- 묶음: R1.md
- 경로 예약: plugins/spec-distill/scripts/roadmap_write.py, plugins/spec-distill/scripts/roadmap_render.py, plugins/spec-distill/scripts/roadmap_model.py, plugins/spec-distill/scripts/roadmap_status.py, plugins/spec-distill/scripts/check_bundle_coverage.py, plugins/spec-distill/scripts/spec_review_bundle.py, plugins/spec-distill/references/epic-handoff.md, plugins/spec-distill/scripts/team_layout.py, plugins/spec-distill/scripts/team_files.py, plugins/spec-distill/scripts/team_check.py, plugins/spec-distill/scripts/team_write.py, plugins/spec-distill/scripts/team_rules.py, plugins/spec-distill/scripts/start_bundle.py, plugins/spec-distill/scripts/job_results.py, plugins/spec-distill/scripts/workflow_superpowers.py, plugins/spec-distill/scripts/team_status.py, plugins/spec-distill/scripts/branch_tip.py, plugins/spec-distill/references/team-files.md, plugins/spec-distill/templates/team/, plugins/spec-distill/scripts/conductor_ledger.py, plugins/spec-distill/scripts/repo_defaults.py, plugins/spec-distill/scripts/control_plane.py, plugins/spec-distill/references/roadmap-ontology.md, REVIEW.md, docs/superpowers/roadmaps/HANDBOOK.md, docs/superpowers/roadmaps/leader/, docs/superpowers/roadmaps/designer/, docs/superpowers/roadmaps/writer/, docs/superpowers/roadmaps/worker/
- 크기: 큼
- 병렬: P1 과 병렬
- 순서 이유: 나머지가 이 파일 형식을 읽는다
- 근거: S8 · S21 · S41

### R2 — 지휘 걸음과 관문
- 의도: 지휘의 걸음을 단계표로 세우고 순서 · 승인을 스크립트가 지키게 하며 사용자 자리를 걸음에 못 박는다
- 범위: 한다: 단계표(형식 · 실행기 칸 · 사람 단계), 순서 강제 + 사람 승인 탈출구(승인된 설계 없이는 계획 · 구현이 시작되지 않는다 · 해시 승인), 같은 단계 연속 실패 멈춤, 사용자 자리(방향 · 설계 대화, 계획이 나왔을 때 · 구현 중 설계에 닿는 물음 · PR 전), 담당자 물음을 원문 그대로 옮기기, 동시 수 레포 설정, SDD 고침 루프 위임, superpowers 결합을 단계 맞춤으로, P8 · CLAUDE.md 개정 / 안 한다: 세션으로 보내기 · 거두기, 절차서 쪼개기 · 리더 다시 띄우기, 상태 브랜치
- 의존: R1
- 브랜치: feature/conductor-stage-table
- 묶음: R2.md
- 경로 예약: plugins/spec-distill/references/conducting.md, plugins/spec-distill/references/conductor-dispatch.md, plugins/spec-distill/skills/epic-conductor/SKILL.md, plugins/spec-distill/scripts/repo_defaults.py, plugins/spec-distill/scripts/start_bundle.py, plugins/spec-distill/scripts/team_status.py, docs/philosophy/devbrew-harness-philosophy.md, CLAUDE.md, plugins/spec-distill/references/docreview-profiles/design-doc.md
- 크기: 큼
- 병렬: R3 와 병렬 가능
- 순서 이유: R1 형식 위에서 단계가 돈다
- 근거: S14 · S37

### E1 — 세션 담당자와 위아래 소통
- 의도: 계획부터의 담당자를 세션으로 띄우고 거두며 지휘자 – 담당자 – 하위 사이 소통 창구를 하나로 정한다
- 범위: 한다: 담당자를 세션으로 띄우기(시작 묶음으로만 · herdr 권장 · 없으면 하위 agent), 결과 파일을 쓰고 닫기 · 띄운 세션 거두기 확인, 위아래 소통 계약(창구 하나 · 받았음과 답했음 · 글이 왔음을 아는 길 · 보낸 쪽 확인 — 양식으로 모델을 묶지 않는다), 도는 담당자에게 닿는 답 · 방향 고침, 사용자가 담당자에게 직접 한 말을 과제 파일로, 담당자끼리는 지휘자가 푼다, 새 형식을 기본으로 · 보내는 글 틀을 시작 묶음으로 · 마지막 보고를 결과 파일로, 모델 고르기 지침, 스크립트 · 다른 모델 한곳으로 / 안 한다: 다른 서버에서 띄우기, 로드맵 사이 소통, 단계와 교대 사이
- 의존: R1, R2
- 브랜치: feature/session-workers
- 묶음: E1.md
- 경로 예약: plugins/spec-distill/references/conductor-dispatch.md, plugins/spec-distill/references/team-files.md, plugins/spec-distill/scripts/start_bundle.py, plugins/spec-distill/scripts/team_write.py, plugins/spec-distill/scripts/job_results.py, plugins/spec-distill/scripts/conductor_ledger.py, plugins/spec-distill/templates/team/, docs/superpowers/roadmaps/leader/, docs/superpowers/roadmaps/worker/
- 크기: 큼
- 병렬: R3 와 병렬 가능
- 순서 이유: 관문이 선 뒤에 세션을 띄워야 설계 없이 개발하지 않는다
- 근거: S4 · 사용자 말 2026-11-17 · 2026-11-18

### E2 — 리더 덜기와 다시 띄우기
- 의도: 지휘 절차서를 걸음별 지시서로 쪼개 그 걸음에서만 읽고 손 일을 담당 세션으로 넘기며 리더 세션을 끊고 다시 띄울 수 있게 한다
- 범위: 한다: 걸음별 지시서 · 손 절차 분리, 머지 전 확인(스위트 대조 · 통합 리뷰 · PR 본문)을 담당 세션으로, 리더가 끊는 자리와 적고 나가는 것, 「지휘자」를 「리더」로 맞추는 낱말 / 안 한다: 상태 브랜치
- 의존: R2, E1
- 브랜치: feature/conductor-step-guides
- 묶음: E2.md
- 경로 예약: plugins/spec-distill/references/conducting.md, plugins/spec-distill/references/conductor-dispatch.md, plugins/spec-distill/skills/epic-conductor/SKILL.md, plugins/spec-distill/scripts/conductor_ledger.py, docs/superpowers/roadmaps/leader/
- 크기: 중간
- 병렬: R3 와 병렬 가능
- 순서 이유: 걸음과 세션 담당자가 선 뒤에 리더의 일을 덜 수 있다
- 근거: S13 · S18 · 사용자 말 2026-11-18

### E3 — 다른 서버에서 띄우기
- 의도: 담당자 세션을 다른 서버에서 띄울 때의 위치 · 권한 · git 밖 파일을 정한다
- 범위: 한다: 등록된 서버에서 띄워 재 보기, 서버 계정 안 위치(되도록 같은 레포 위치), 서버 안 권한, git 에 없는 데이터 · env secret 을 부모 세션 기준 최신으로 모으기(값은 적지 않는다) / 안 한다: 로드맵 사이 편지함, 감시 · 표시
- 의존: E1
- 브랜치: feature/remote-session-spawn
- 묶음: E3.md
- 경로 예약: plugins/spec-distill/references/conductor-dispatch.md, plugins/spec-distill/dependencies.md
- 크기: 중간
- 병렬: R3 와 병렬 가능
- 순서 이유: 이 기계에서 세션 담당자가 돈 뒤에 다른 서버로 넓힌다
- 근거: 사용자 말 2026-11-17

### R3 — 지휘자 상태 브랜치 · 편지함
- 의도: 기계를 넘는 지휘자 소통 자리를 세운다
- 범위: 한다: 지휘자 상태 브랜치(코드 없음 · main 에 머지 안 함), 편지함 한 글 한 파일, STATUS.md 계산 · 커밋, 지휘자끼리의 대화 계약(로드맵 사이), 브랜치 규칙 문서 예외 / 안 한다: 감시 · 표시
- 의존: R1
- 브랜치: feature/conductor-state-branch
- 묶음: R3.md
- 경로 예약: plugins/spec-distill/scripts/conductor_state.py, plugins/spec-distill/scripts/control_plane.py, plugins/spec-distill/scripts/state_path.py, docs/git-workflow/branch-strategy.md, plugins/project-init/hooks/post-tool-use.py
- 크기: 중간
- 병렬: R2 와 병렬 가능
- 순서 이유: 감시 mod 가 이 편지함을 본다
- 근거: S35 · 조사 13

### R4 — 현황 · 감시 mod
- 의도: mod 하나로 현황 · 토큰을 보이고 편지함을 감시한다
- 범위: 한다: 표시 전용 mod(권한 이벤트 미구독 · validate 락), 타이머 git fetch → 새 글이면 자기 세션 새 턴, kill switch, 최소 판 / 안 한다: 도구 승인
- 의존: R3, P1
- 브랜치: feature/conductor-status-mod
- 묶음: R4.md
- 경로 예약: plugins/spec-distill/README.md, plugins/spec-distill/dependencies.md
- 크기: 중간
- 순서 이유: 편지함과 측정 방식이 먼저 있어야 한다
- 근거: S38 · 조사 17

### R5 — 이전 · 재측정
- 의도: 기존 기록 · 도는 로드맵을 새 구조로 옮기고 옛 장치를 걷어낸 뒤 기준선과 다시 잰다
- 범위: 한다: 설계문서 지휘 기록 · 에픽 묶음 이전, 도는 로드맵 이전, 옛 장치 정리, 재측정 비교 / 안 한다: 새 기능
- 의존: R1, R2, R3, R4, E1, E2, E3
- 브랜치: feature/conductor-migration
- 묶음: R5.md
- 경로 예약: docs/superpowers/specs/, docs/superpowers/roadmaps/, plugins/spec-distill/CHANGELOG.md
- 크기: 중간
- 순서 이유: 모든 새 장치가 선 뒤에 옮긴다
- 근거: S20 · S30

## 지휘 절차

이 로드맵은 지휘자가 이끈다 — `/spec-distill:epic-conductor docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md`. 다시 불러도 git 과 기계 상태에서 상태를 다시 계산해 같은 자리에서 잇는다. `DEVBREW_SPEC_DISTILL_DISABLE=1` 로 꺼 두면 spec-distill 전체(리뷰 · 상태 계산 포함)가 꺼진다 — 지휘자 없이 진행하려면 끄지 말고 지휘자를 부르지 않은 채 spec-distill 의 `references/conducting.md` 끝 절 「손으로 따르는 절차」 를 따른다.

- 사람 몫(brainstorming · spec 승인 · 계획의 설계에 없던 결정)은 지휘 세션이 한 번에 한 에픽씩 배경과 함께 묻는다.
- 실행 방식은 writing-plans 가 권하는 방식이고, 계획 검토는 계획에 설계에 없던 결정이 있을 때만 기다린다.
- 머지는 사용자가 한다.

## 결정 기록

줄 형식은 `- <블록> · <결정|머지> · <YYYY-MM-DD> · 「원문」` 이다. 인터뷰 뒤의 사용자 말은 새 S 번호 없이 원문 그대로 인용한다. 「머지」 줄은 PR 없이 로컬에서 머지한 에픽에만 적는다 — PR 로 머지한 에픽은 지휘자가 채운 PR 상태로 머지됨이 된다(squash · rebase 포함).

## 재분해 이력

### 2026-11-14 · 처음 로드맵
- 원문:
  - 「승인 (권장)」

### 2026-11-14 · R1 설계 승인 뒤 브랜치 · 경로 예약 · 번호 목록을 맞춘다 — 에픽 경계 · 범위 · 의존은 그대로
- 바뀜: 바뀐 에픽 R1 · R2 · R3 「이대로 다시 나눈다 (권장)」
- 원문:
  - 「이대로 다시 나눈다 (권장)」

### 2026-11-14 · R2 경로 예약에서 인터뷰 끝맺음 절차 파일을 뺀다 — 그 파일은 앞단 개선 로드맵이 맡는다
- 바뀜: 바뀐 에픽 R2 「뺀다 (권장)」
- 원문:
  - 「뺀다 (권장)」

### 2026-11-15 · R1 경로 예약에 계획 2 가 고치는 스크립트 둘을 더한다 — team 형식의 단계 계산을 담는 새 파일 team_status.py 와 읽기 전용 검사가 받는 꼴로 고치는 branch_tip.py
- 바뀜: 바뀐 에픽 R1 「둘 다 더한다 (권장)」
- 원문:
  - 「둘 다 더한다 (권장)」

### 2026-11-18 · R2 를 넷으로 나눈다 — 지휘 걸음과 관문 · 세션 담당자와 위아래 소통 · 리더 덜기와 다시 띄우기 · 다른 서버에서 띄우기. 사용자가 일꾼의 기본을 세션으로, 지휘 세션을 새로 띄우는 길을 다시 정했고 리더와 담당자 사이 대화 계약을 R3 에서 새 에픽으로 옮긴다
- 바뀜: 바뀐 에픽 R2 · R3 · R5 · 새 에픽 E1 · E2 · E3 「이대로 다시 나눈다 (권장)」 · 「내가 세션을 다시 시작한 이유는 이걸 반드시 반영하고 싶어서야 — 지휘에서 herdr 기본으로 쓰게 권장 하드코딩하지 말것 다만 있는게 좋을듯함, herdr의 세션 스폰 위치에 대해서 고려 필요 보면 알겠지만 다른 서버 그 서버 계정내 위치(가능하면 같은 레포 위치면 좋을거임) 그리고 그 서버 내 권한 해소 그리고 깃으로 추적안되는거(이건 부모 세션을 중점으로 최신이 되게 모이면 좋을듯). 담당자간 담당자와 리더간 서로 대화하는거도 이거로 해소될 수 있음. 이러면 복잡한 방식보다 로드맵간 대화만 해소하면 될듯함. 그리고 이 방식이면 사람인 나도 주도권을 가질 수 있는건지 궁금함 내가 바닐라로 써봤을 때는 대화를 여러번 주고 받느라 지휘자가 정신을 못차리는게 있더라. 우리 intend방식이면 이게 어느정도 해소 되려나, 그리고 brainstorming 무시되는거 설계 안하고 임의로 넘어가는거도 해소 되려나 그리고 몇번 설계 같이 할까요 물어보다가 혼자 설계하더라고, 지휘자가 보고를 대충하고 넘어가는 경우도 꽤 생기더라고. 새로운 지휘 방식에 이미 이야기가 되었겠지만 지휘자는 가능하면 리더, 팀장 pm po 같은 직무로서 오너십을 가지는 주체야.」 · 「물론 이거는 맥미니 하나만이지만 다른 서버에 붙는 경우로도 많이 쓰걷느」 · 「앞으로는 E로 통일하자, herdr 권장으로는 하도록 하자 환경이 되면 까는거로, 추적안되는거 중 필요한거는 대부분 데이터나 env secret이겠지」 · 「지휘자는 지휘에 집중했으면 하는 의미였어 안그래도 지휘로 바쁘니까 그런게 구현을 위해 세션 스폰하는걸 안쓰는 경유도 있더라고 서브에이전트를 써서 에픽을 담당하거나 하는 느낌 가능하면 세션을 스폰하여 각 메인 대화에서 진행되게 하길 원하는 거였던거지」 · 「그리고 판단 근거로 낡을 수 있지만 방향적으로 서브에이전트는 5분 캐시가 유지되고 메인세션은 1시간 캐시가 유지돼 그러니 재시작이나 일을 시킬때 일을 마무리 시킬때 등 토큰 효율을 생각할 부분이 있는거지 꼭 이어서 해야하는거 아니면 휴식이런거 보다 세션을 죽이고 다시 띄우는게 좋고 그걸 위해 우리 파일 구조를 만든거자나」 · 「그리고 자신이 지휘하는 세션 리스트는 네이티브 기능으로 관리 되나? 회수를 안하는 경우가 많네」 · 「주도권은 이미 herdr로 아래 세션에대해 해소되고 서브에이전트도 그래 즉 워커쪽에 내가 주도할 수 있단거지 말한건 리더쪽에서 결정하는것과 나의 의도 결정 이런게 어떻게 가져가야할지인거지 특히 스펙 설계를 안하고 넘기거나 대충하는걸 몇번봐서 더 생각이 들었지」 · 「리더가 오너십가지는거 맞아 그런데 스펙과같이 초반에 방향과 틀을 잡는거와 중반이수 싱크를 맞추는거 등은 내가 해주지 않으면 퀄리티가 떨어질거야」 · 「그리고 세션띄우는거 봤는데 그냥 개발하지는 않겠지? brainstorming으로 가는게 아니라 메시지 받고 그냥 개발하기도 하더라고 물론 이건 r1패치전이야」 · 「담당자한테 넘길때는 계획부터 였자나 그게 맞아 스펙까지는 지금처럼 지휘자가 하는게 맞아」 · 「맞아 그런종류야 앞에 대화가 너무 많아지거나 하는 문제 같긴한데 이거는 지휘 세션을 새로 시작하거나 로드맵을 유사한거끼리만 묶고 다른 로드맵으로 쪼게거나 등 할까생각하는데 다른 에픽에서 문제해결이 필요할거같아 내 생각을 다른쪽으로 해야할거 같음 이야기해」 · 「좋아 그리고 지휘는 나랑 방향잡고 스펙짜는거 까지 포함인거야 계획부터 담당자에게 넘기는거고 이전과동일하지?」 · 「없을때 길은 서브에이전트지뭐 너무 무겁게가지말고」 · 「워커 레이어랑 리더레이어간에 소통방식에대한 내용이 부실하네 다만 모델 제약이 되어선 안돼」 · 「우리 파일방식 r1에서 만든거랑 인터뷰 브리프등 있자나 그거 잊지말고」 · 「다 뼈아프지만 지휘자-담당자-하위 이간 위아래ㅜ소통이 잘되어야겠지 그리고 소통 창구가 뭔지 통일되어야 서로 대화가 될거고 담당자끼리는 지휘자가 풀어야하고」 · 「단계와 교대 사이는 다른 에픽이 풀자」
- 원문:
  - 「이대로 다시 나눈다 (권장)」
  - 「내가 세션을 다시 시작한 이유는 이걸 반드시 반영하고 싶어서야 — 지휘에서 herdr 기본으로 쓰게 권장 하드코딩하지 말것 다만 있는게 좋을듯함, herdr의 세션 스폰 위치에 대해서 고려 필요 보면 알겠지만 다른 서버 그 서버 계정내 위치(가능하면 같은 레포 위치면 좋을거임) 그리고 그 서버 내 권한 해소 그리고 깃으로 추적안되는거(이건 부모 세션을 중점으로 최신이 되게 모이면 좋을듯). 담당자간 담당자와 리더간 서로 대화하는거도 이거로 해소될 수 있음. 이러면 복잡한 방식보다 로드맵간 대화만 해소하면 될듯함. 그리고 이 방식이면 사람인 나도 주도권을 가질 수 있는건지 궁금함 내가 바닐라로 써봤을 때는 대화를 여러번 주고 받느라 지휘자가 정신을 못차리는게 있더라. 우리 intend방식이면 이게 어느정도 해소 되려나, 그리고 brainstorming 무시되는거 설계 안하고 임의로 넘어가는거도 해소 되려나 그리고 몇번 설계 같이 할까요 물어보다가 혼자 설계하더라고, 지휘자가 보고를 대충하고 넘어가는 경우도 꽤 생기더라고. 새로운 지휘 방식에 이미 이야기가 되었겠지만 지휘자는 가능하면 리더, 팀장 pm po 같은 직무로서 오너십을 가지는 주체야.」
  - 「물론 이거는 맥미니 하나만이지만 다른 서버에 붙는 경우로도 많이 쓰걷느」
  - 「앞으로는 E로 통일하자, herdr 권장으로는 하도록 하자 환경이 되면 까는거로, 추적안되는거 중 필요한거는 대부분 데이터나 env secret이겠지」
  - 「지휘자는 지휘에 집중했으면 하는 의미였어 안그래도 지휘로 바쁘니까 그런게 구현을 위해 세션 스폰하는걸 안쓰는 경유도 있더라고 서브에이전트를 써서 에픽을 담당하거나 하는 느낌 가능하면 세션을 스폰하여 각 메인 대화에서 진행되게 하길 원하는 거였던거지」
  - 「그리고 판단 근거로 낡을 수 있지만 방향적으로 서브에이전트는 5분 캐시가 유지되고 메인세션은 1시간 캐시가 유지돼 그러니 재시작이나 일을 시킬때 일을 마무리 시킬때 등 토큰 효율을 생각할 부분이 있는거지 꼭 이어서 해야하는거 아니면 휴식이런거 보다 세션을 죽이고 다시 띄우는게 좋고 그걸 위해 우리 파일 구조를 만든거자나」
  - 「그리고 자신이 지휘하는 세션 리스트는 네이티브 기능으로 관리 되나? 회수를 안하는 경우가 많네」
  - 「주도권은 이미 herdr로 아래 세션에대해 해소되고 서브에이전트도 그래 즉 워커쪽에 내가 주도할 수 있단거지 말한건 리더쪽에서 결정하는것과 나의 의도 결정 이런게 어떻게 가져가야할지인거지 특히 스펙 설계를 안하고 넘기거나 대충하는걸 몇번봐서 더 생각이 들었지」
  - 「리더가 오너십가지는거 맞아 그런데 스펙과같이 초반에 방향과 틀을 잡는거와 중반이수 싱크를 맞추는거 등은 내가 해주지 않으면 퀄리티가 떨어질거야」
  - 「그리고 세션띄우는거 봤는데 그냥 개발하지는 않겠지? brainstorming으로 가는게 아니라 메시지 받고 그냥 개발하기도 하더라고 물론 이건 r1패치전이야」
  - 「담당자한테 넘길때는 계획부터 였자나 그게 맞아 스펙까지는 지금처럼 지휘자가 하는게 맞아」
  - 「맞아 그런종류야 앞에 대화가 너무 많아지거나 하는 문제 같긴한데 이거는 지휘 세션을 새로 시작하거나 로드맵을 유사한거끼리만 묶고 다른 로드맵으로 쪼게거나 등 할까생각하는데 다른 에픽에서 문제해결이 필요할거같아 내 생각을 다른쪽으로 해야할거 같음 이야기해」
  - 「좋아 그리고 지휘는 나랑 방향잡고 스펙짜는거 까지 포함인거야 계획부터 담당자에게 넘기는거고 이전과동일하지?」
  - 「없을때 길은 서브에이전트지뭐 너무 무겁게가지말고」
  - 「워커 레이어랑 리더레이어간에 소통방식에대한 내용이 부실하네 다만 모델 제약이 되어선 안돼」
  - 「우리 파일방식 r1에서 만든거랑 인터뷰 브리프등 있자나 그거 잊지말고」
  - 「다 뼈아프지만 지휘자-담당자-하위 이간 위아래ㅜ소통이 잘되어야겠지 그리고 소통 창구가 뭔지 통일되어야 서로 대화가 될거고 담당자끼리는 지휘자가 풀어야하고」
  - 「단계와 교대 사이는 다른 에픽이 풀자」

## 위험 번호표

번호는 brief §5 위험 줄마다 박힌 번호(`- 위험 K<n> — …`)다. 박은 번호는 그 위험의 정체다 — 지운 위험의 번호는 다시 쓰지 않는다. 번호가 박히지 않은 옛 brief 만 숨은 가정 · 실패 양식 · 리뷰 참고 순으로 줄 순서대로 번호를 달고, 그렇게 매겼다고 알린다. 오른쪽은 brief 원문 그대로다.

- K1 — 위험 — 숨은 가정: 모든 단계 · 작은 일까지 팀과 지휘자를 거치게 해도 토큰이 준다 — 다중 agent 는 단일 agent 보다 크게 더 쓴다(조사 3, 2차) · 대응: 작은 일은 가볍게(D11)
- K2 — 위험 — 숨은 가정: 역할 폴더 CLAUDE.md · 경로 조건 규칙이 일꾼에게 실린다 — on-demand · 하위 agent 미상속 · 격리 worktree 미적재(조사 3 · 20) · 대응: 시작 묶음(D14 · D33) [RC199 → OQ40]
- K3 — 위험 — 숨은 가정: 120줄 목차 상한이 읽기 비용을 묶는다 — 근거는 자동 메모리 규약이고 줄 수는 바이트 예산이 아니다(조사 18) · 대응: 바이트 예산(D30)
- K4 — 위험 — 숨은 가정: 두 번 나온 지적은 일반화할 만큼 검증됐다 — 같은 오판의 되풀이일 수 있다(조사 18) · 대응: 반례 확인 승격(D30)
- K5 — 위험 — 숨은 가정: 「스크립트가 강제」라고 쓰면 실제로 강제된다 — 강제 장소(rc 를 읽는 스크립트 · 훅)가 정해지지 않았다(조사 18) [RC2 → OQ24]
- K6 — 위험 — 실패 양식: 지휘 세션을 새 세션으로 바꾸면 돌던 하위 agent 의 완료 알림이 끊기고, agent 팀이면 팀이 증발한다(조사 3) · 대응: 사용자 /compact(D16)
- K7 — 위험 — 실패 양식: STATUS 현황이 실제와 어긋난다 — 일꾼이 갱신 없이 끝나거나 멈출 때(조사 3) · 대응: 계산해 쓰는 STATUS(D18)
- K8 — 위험 — 실패 양식: 받음 확인 · 되읽기가 형식만 남아 오해한 채 진행한다(조사 3) · 대응: 산출물 대조(D12)
- K9 — 위험 — 실패 양식: 토큰 계측이 조용히 틀린다 — usage 반복 · 2.1.293–2.1.306 하위 출력 과소(조사 3 · 14) [RC151 → OQ27]
- K10 — 위험 — 실패 양식: 캐시 재작성 폭풍 — 리프레시가 맥락 퍼센트만 낮추고 비용은 올린다(조사 3) · 대응: 품질 신호(D11)
- K11 — 위험 — 실패 양식: 다른 작업 방식의 산출이 조용히 「계획 없음」으로 세어져 압축 뒤 계획 agent 를 다시 보낸다(조사 11) [RC150 → OQ33]
- K12 — 위험 — 실패 양식: mod 가 sandbox 없이 도구 호출을 승인할 수 있고, 이 기계에는 기본 가드를 싣는 관리 설정이 없다(조사 17 · 19) · 대응: 표시 · 감시 전용, validate 락
- K13 — 위험 — 실패 양식: 순서 강제가 정당한 경로를 막아 봉인된 결정이 된다(조사 18) [RC191 → OQ37]
- K14 — 위험 — 실패 양식: P8 · CLAUDE.md 만 고치면 사본 문장과 P8 이름 인용이 옛 뜻으로 남는다(조사 18) [RC189 → OQ24]
