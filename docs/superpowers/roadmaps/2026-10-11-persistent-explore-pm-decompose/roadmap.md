---
type: roadmap
source_brief: docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md
---

# 집요한 탐색 · PM 분해 · 에픽별 지휘 · 의도 왜곡 장치 제거 — 로드맵

승인된 분해안(S47)의 에픽 지도다. 에픽마다 원본 brief · 이 로드맵 · 에픽 묶음을 넘긴다(D39). 상태 칸은 없다 — 단계는 `plugins/spec-distill/scripts/roadmap_status.py` 가 git 에서 계산한다. 단위는 로드맵 > 에픽(spec 하나) > plan(PR 하나) > task 이고 에픽 하나가 plan · PR 여럿을 낼 수 있다 — 다만 지금의 상태 계산은 에픽 하나를 브랜치 하나로 센다(에픽 하나의 PR 여러 개 추적은 R5).

## 에픽

### P1 — 다음 세션 @ 명령 브랜치 머지
- 의도: 인터뷰 종료가 다음 세션 @ 명령으로 넘기게 하는 브랜치를 먼저 머지한다
- 범위: 한다 그 브랜치의 계획 실행 · 머지 / 안 한다 이번 로드맵의 에픽 작업
- 의존: 없음
- 브랜치: feature/next-session-at-handoff
- 묶음: 없음
- 경로 예약: 없음
- spec: docs/superpowers/specs/2026-10-11-next-session-at-handoff-design.md
- 발화: S37
- 항목: D38 · OQ19 · RC17 · RC71

### P2 — qg v10 ⑤ 차등 테스트 머지
- 의도: qg 를 건드리는 에픽 앞에 qg v10 ⑤ 차등 테스트를 머지한다
- 범위: 한다 그 브랜치 머지 / 안 한다 이번 로드맵의 qg 변경
- 의존: 없음
- 브랜치: feature/qg-v10-differential
- 묶음: 없음
- 경로 예약: 없음
- spec: docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md
- 발화: S47 · S51
- 항목: RC73 · RC77

### P3 — qg 진입 이름 결정
- 의도: qg 를 건드리는 에픽 앞에 qg 진입 이름을 정한다
- 범위: 한다 진입 이름 결정 기록 / 안 한다 qg 코드 변경
- 의존: 없음
- 완료: 결정 기록
- 묶음: 없음
- 경로 예약: 없음
- 발화: S47 · S51
- 항목: RC85

### P4 — 옛 훅 쓰기 경로 브랜치 고아 확인
- 의도: 옛 훅 쓰기 경로 계획이 지금 없는 파일을 전제하는지 확인하고 처분을 정한다
- 범위: 한다 고아 여부 확인 · 처분 결정 기록 / 안 한다 그 계획의 구현
- 의존: 없음
- 완료: 결정 기록
- 묶음: 없음
- 경로 예약: 없음
- 발화: S47
- 항목: RC81

### R0 — 로드맵 · 에픽 묶음 · 상태 계산의 걷는 뼈대
- 의도: 에픽을 한 곳에서 보고 에픽마다 받은 번호를 흘리지 않게 하는 가장 얇은 끝에서 끝까지를 만든다
- 범위: 한다 손으로 만든 로드맵 · 묶음 · 공통 형식 다섯 · 상태 계산 · 번호 대조 · 실측 M1~M3 · 락 지도 · 충돌표 / 안 한다 묶음 자동 생성 · 깊이 검사 · 컨트롤 플레인 · 지휘자 skill
- 의존: P1
- 브랜치: feature/interview-explore-decompose
- 묶음: 없음
- 경로 예약: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/, plugins/spec-distill/scripts/roadmap_status.py, plugins/spec-distill/scripts/check_bundle_coverage.py, plugins/spec-distill/tests/test_roadmap_status.sh, plugins/spec-distill/tests/test_bundle_coverage.sh
- spec: docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md
- 발화: S9 · S11 · S12 · S13 · S14 · S16 · S17 · S18 · S25 · S26 · S27 · S31 · S37 · S39 · S40 · S41 · S47 · S48 · S51
- 항목: C8 · C19 · D22 · D24 · D28 · D29 · D33 · C27 · D20 · D21 · D38 · C25 · D26 · D39 · D40 · D41 · D42 · D45 · D47 · OQ30 · OQ33 · C30 · OQ34 · OQ37 · OQ38 · RC18 · RC35 · RC36 · RC38 · RC72 · RC74 · RC75 · RC76 · RC78 · RC80 · K5 · K8 · K9 · K10 · K14 · K15

### R1 — 인터뷰 탐색 개편
- 의도: 인터뷰가 한 번에 닫지 않고 결정에 닿는 새 사실이 없을 때까지 조사하게 한다
- 범위: 한다 조사 장치 예산 · 자격 · 리듬 강제 · subagent 자리 제한의 제거 또는 수정 · 독립 판정자의 포화 판정 · 조사 상한 20회 · 문제 재구성 단계 제거 / 안 한다 압축 · 리뷰 장치(R2 · R2a) · 번호 인계(R3) · 분해(R4)
- 의존: R0
- 브랜치: feature/interview-persistent-explore
- 묶음: R1.md
- 경로 예약: plugins/spec-distill/skills/spec-interview/SKILL.md, plugins/spec-distill/skills/spec-interview/references/steelman.md, plugins/spec-distill/agents/coverage-mapper.md, plugins/spec-distill/agents/blind-spot-prober.md, plugins/spec-distill/agents/steelman-builder.md, plugins/spec-distill/scripts/check_brief.py, plugins/spec-distill/tests/test_conducting_interview_stage.sh

### R2 — spec-distill 안쪽 압축 · 리뷰 장치
- 의도: spec-distill 안에서 비용 · 압축으로 품질을 깎거나 사용자 결정을 덮는 장치를 제거하거나 공시 · 사용자가 여는 형태로 고친다
- 범위: 한다 압축 규약 · request-framing 압축 · seed · brief · 설계문서 리뷰 프로필의 절감 장치 · brief 템플릿 형식 제약 / 안 한다 인터뷰 조사 장치(R1) · 공유 리뷰 엔진과 qg(R2a)
- 의존: R0, P1
- 브랜치: feature/distill-distortion-devices
- 묶음: R2.md
- 경로 예약: plugins/spec-distill/references/compression.md, plugins/spec-distill/skills/request-framing/SKILL.md, plugins/spec-distill/references/docreview-profiles/seed.md, plugins/spec-distill/references/docreview-profiles/brief.md, plugins/spec-distill/references/docreview-profiles/design-doc.md, plugins/spec-distill/templates/interview-brief-template.md

### R7 — 상태 저장 재설계 흡수
- 의도: 미구현 상태 저장 재설계 결정 D1~D4 를 이 로드맵 위에서 구현한다
- 범위: 한다 인터뷰 상태는 docs · 임시 폴더는 리뷰 상태만 · 이어 하기는 로드맵 기반 · 긴 · 병렬 실행 중 리뷰 원장 소실 방지 / 안 한다 리뷰 엔진 동작 변경(R2a)
- 의존: R0
- 브랜치: feature/state-storage-redesign
- 묶음: R7.md
- 경로 예약: plugins/spec-distill/scripts/state_path.py, plugins/spec-distill/hooks/session-end-cleanup.py, plugins/spec-distill/scripts/spec-distill-gc.py

### R3 — 번호 인계 · 대조 · 깊이
- 의도: brief 의 모든 번호가 spec · 계획 · 구현까지 가고 빠지거나 얕거나 미뤄지면 경고되게 한다
- 범위: 한다 넘김 글의 덮어쓰기 문장 제거 · /compact 보존에 조사 · 위험 · spec 리뷰에 묶음을 정해진 입력으로 넘기기 · 번호마다 깊이 검사 · 설계문서 항목의 계획 · 구현 대조(미룬 항목은 받는 곳이 생길 때까지 경고) / 안 한다 묶음 생성(R4) · 표시(R6)
- 의존: R0, P1
- 브랜치: feature/numbered-handoff-coverage
- 묶음: R3.md
- 경로 예약: plugins/spec-distill/skills/spec-interview/references/finishing.md, plugins/spec-distill/skills/spec-review/SKILL.md, plugins/spec-distill/references/proceed-gate.md, plugins/spec-distill/references/docreview-profiles/design-doc.md

### R4 — PM 분해 · 로드맵 · 에픽 묶음 · 재분해 경로
- 의도: 인터뷰가 일을 에픽으로 나눠 로드맵과 묶음을 내고 하류의 재분해 · 축소 신호를 같은 지도로 되돌리게 한다
- 범위: 한다 분해 판단 · 로드맵 · 묶음 자동 생성(R0 형식) · 재분해 경로 / 안 한다 지휘(R5) · 표시(R6)
- 의존: R0
- 브랜치: feature/interview-pm-decompose
- 묶음: R4.md
- 경로 예약: 없음

### R6 — 컨트롤 플레인
- 의도: 에픽 지도 · 단계 · 빠진 것 · 드리프트 알림을 Claude Code 안에서 보이게 한다
- 범위: 한다 상태줄 · 패널 · 작업 목록 표시(M2 · M3 결과에 맞춤) / 안 한다 상태 계산 자체(R0 · R5)
- 의존: R0
- 브랜치: feature/roadmap-control-plane
- 묶음: R6.md
- 경로 예약: 없음

### R2a — 공유 리뷰 엔진 · qg 파급 · persona 보안 리뷰
- 의도: 공유 리뷰 엔진과 qg · 다른 플러그인의 의도 왜곡 장치를 제거하거나 고치고 persona 편집은 보안 리뷰를 거친다
- 범위: 한다 공유 리뷰 엔진 상한 · 조언 접기 · qg 리뷰어 · 루프 상한 · 다른 플러그인의 장치 · qg 진입 이름 적용(P3 결정 — `commands/qg.md` 삭제 · `artifact-critique` 개명 · 호출 표면 락의 qg 위반 해소) / 안 한다 spec-distill 안쪽 장치(R2)
- 의존: R1, R2, R7, R3, R4, R6, P2, P3
- 브랜치: feature/shared-review-engine-devices
- 묶음: R2a.md
- 경로 예약: shared/docreview/, plugins/spec-distill/references/reviewing-document.md, plugins/quality-gates/, plugins/project-init/, plugins/plugin-audit/

### R5 — 지휘자
- 의도: 한 세션이 로드맵을 따라 에픽을 끝까지 지휘하되 사용자의 결정권과 내용 검토가 남게 한다
- 범위: 한다 사람 몫은 지금 답할 수 있는지 판단해 배경 설명과 함께 몰아 받고 나머지는 멈추지 않고 병렬로 끝까지 · 외부 정지는 사용자에게(미리 받은 답이 있으면 그 답으로) · 실행 기록 회수 · 재개 · 부분 계속 · 머지 원칙 · qg 의도 회귀 · 에픽 사이 이음매 · base 이동 · 구현 이후 단계 / 안 한다 상태줄 · 패널(R6)
- 의존: R1, R2, R7, R3, R4, R6, P2, P3
- 브랜치: feature/epic-conductor
- 묶음: R5.md
- 경로 예약: 없음

### R8 — 의존 선언 · 부재 시 강등 · devbrew 밖 경로
- 의도: 이 장치들이 devbrew 밖 레포와 superpowers 부재에서도 통하게 한다
- 범위: 한다 의존 최소 버전 선언 · 부재 시 강등 · 경로 규약 범용화 · squash · rebase 머지 자동 판정 / 안 한다 규칙 문서(R9)
- 의존: R2a, R5
- 브랜치: feature/dependency-portability
- 묶음: R8.md
- 경로 예약: 없음

### R9 — 규칙 · 문서 정리
- 의도: 바뀐 장치에 맞춰 레포 규칙 · 철학 · README · CHANGELOG 를 정리한다
- 범위: 한다 지출 승인 조항 · P22 개정 문안(사용자 승인) · 문서 정리 / 안 한다 장치 동작 변경
- 의존: R8
- 브랜치: feature/rules-docs-cleanup
- 묶음: R9.md
- 경로 예약: CLAUDE.md, docs/philosophy/devbrew-harness-philosophy.md

## 지휘 절차

R5 전까지 지휘 세션이 따르는 절차다. 장치가 아니라 절차다 — 지휘자 skill 은 R5 가 만든다. 지휘 세션은 `/new` 뒤 첫 줄에 `@docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md` 를 붙여 연다.

1. `git fetch origin` → `python3 plugins/spec-distill/scripts/roadmap_status.py docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md` → 작업 목록을 결과에 맞춘다. 에픽 하나에 작업 하나, 제목은 「<번호> <이름> — <단계>」. 대기 · 준비는 시작 전, 설계 중 · 계획은 진행 중, 머지됨 · 끝남은 완료다. 알 수 없음은 작업 상태를 바꾸지 않고 제목 끝에 「알 수 없음(이유)」을 붙인다. 종료 코드가 3 이면 작업 목록을 바꾸지 않고 「검사 불가」 사유를 사용자에게 그대로 보인다 — 일부 단계가 계산돼 보여도 믿지 않는다.
2. 준비 단계 에픽을 고른다. 블록의 `브랜치:` 이름으로 `origin/main` 에서 브랜치와 worktree 를 먼저 만들고, 그 에픽의 설계문서 · 계획은 모두 그 브랜치에 커밋한다. 설계 단계(brainstorming → 설계문서 → spec-review 승인)는 이 세션에서 한 에픽씩 돈다 — spec 승인은 사용자가 에픽마다 한다. 상태를 git 에서 계산하므로 에픽마다 세션을 따로 열어 설계(brainstorming)도 병렬로 할 수 있다 — 한 세션 안에서는 한 에픽씩이다(실측 M1).
3. 설계문서를 커밋한 뒤 spec-review 를 부르기 전에 `python3 plugins/spec-distill/scripts/check_bundle_coverage.py <묶음> <설계문서>` 를 돌려 결과를 사용자에게 보인다. 빠진 번호가 있으면 spec-review 전에 고친다. 종료 코드가 3 이면(표가 없거나 깨짐) 표를 고쳐 다시 돌리고, 0 이 나오기 전에는 spec-review 로 가지 않는다.
4. superpowers 가 묻는 자리(plan 검토 · 실행 방식 · 머지 메뉴)는 그대로 사용자에게 간다.
5. 구현은 에픽마다 worktree 에서 돌리고 그동안 다음 에픽의 설계를 진행하는 것이 목표다. 백그라운드 실행이 되는지는 실측 M1 이 정한다 — 안 되면 구현도 순차로 하고 그 사실을 알린다. SDD 가 마지막 메시지로 내는 판정 목록(「Rulings I made」)은 그대로 사용자에게 보이고 멈추지 않는다.
6. 에픽이 머지될 때마다 남은 에픽을 재평가하고, 바뀔 때만 사용자 승인 뒤 로드맵 수정을 전용 작은 브랜치(`feature/roadmap-<요지>`)와 PR 로 올린다. 머지는 사용자가 한다.
7. 구현 커밋에는 `Spec: <에픽 설계문서 레포 상대경로>` 트레일러를 단다.

## 결정 기록

줄 형식은 `- <블록> · <결정|머지> · <YYYY-MM-DD> · 「원문」` 이다. 인터뷰 뒤의 사용자 말은 새 S 번호 없이 원문 그대로 인용한다. squash · rebase 로 머지해 머지 커밋이 없는 에픽은 「머지」 줄로 적는다.

쉬운 말 PR 3(`feature/plain-language-voice`)은 이미 머지됐다(#198) — 선행 둘째의 그 부분은 블록을 두지 않는다.

- P3 · 결정 · 2026-10-13 · 「quality-pipeline 을 진입으로 (권장)」 · 「따로 진입 artifact-critique」
  - 앞 답은 코드 검사(`/qg`)의 진입이다 — `commands/qg.md` 를 지우고 `quality-pipeline` skill 을 진입으로 세운다(완전명 `/quality-gates:quality-pipeline`). 뒤 답은 문서 비평(`/qg critique`)의 진입이다 — `critiquing-artifacts` 를 따로 진입 skill `artifact-critique` 로 바꾼다(완전명 `/quality-gates:artifact-critique`). 적용은 R2a 가 한다.
- P4 · 결정 · 2026-10-13 · 「끝난 기록으로 둠 (권장)」
  - 옛 훅 쓰기 경로 계획(`docs/superpowers/plans/2026-08-23-hook-write-path-bypass.md`)은 고아가 아니다 — 구현 브랜치가 #134 로 머지됐고 main 밖 커밋은 0이다. 전제 파일이 없는 것은 계획 자신이 지웠거나(쓰기 감시 훅 셋 · qg 사전 검사 · docs-lint) 뒤 개편이 대체했기 때문이다(검사를 넘겨받은 Stop 훅 `review-dispatch.py` 는 e7c6bbb9 가 지웠다). 계획 파일과 브랜치는 기록으로 둔다.

## 재분해 이력

- 2026-10-11 · 처음 로드맵 · 승인 원문 S47 「이대로 승인 (권장) — 고친 분해안(선행 3: @ 브랜치 머지 · qg ⑤·PR3·진입 이름 · hook 브랜치 고아 확인 + R0~R9, 순서 @ 브랜치 → R0 → R1‖R2‖R7‖R3‖R4‖R6 → R2a·R5 → R8 → R9) 승인」 · 선행 3 을 P1~P4 블록으로 나눴다(R0 설계 §1).
- 2026-10-11 · 승인 뒤 수정(R0 설계 B11~B13) · R6 묶음에 D24 · D40 을 더했다 「더한다 (권장)」 · 경로 예약 겹침은 병렬을 막지 않는 정보로 낮추고 겹침 때문에만 있던 R3 → R2 의존을 뺐다 「병렬 유지, 정보로만 (권장)」 · 단위 이름을 「에픽」으로 정했다 「에픽 (권장)」.
- 2026-10-13 · P3 결정 뒤 수정 · qg 진입 이름 적용을 R2a 범위에 더했다 「R2a 범위에 더함 (권장)」.
- 2026-10-15 · R7 착수 중 수정 · 사람 몫을 판단해 몰아 받고 나머지는 쭉 병렬로 가는 지휘를 R5 범위에 더했다 「사람이 있을때 사람이 진행해야 하는걸 몰아 하는거지」 · 「그게 되게끔 구현도 해야한단 말이야」 · 「근데 이 몰아서 물어보는거는 억지로 하는게 아니라 되는거까지 하는거야 판단하는 과정이 있어야겠지」 · 「그래 이런 느낌은 맞는데 설명과 배경 이해는 더 기켜줘야 겠어」 · 「너무 질문만 몰아치는 느낌이네」 · 「기존 brainstorming방식을 해치진 말아줘」 · 「R5 지휘자 범위에 더함 (권장)」 · superpowers 가 묻는 세 자리(계획 검토 · 실행 방식 · 머지 메뉴)는 미리 답해 둔다(S36 재결정) 「미리 답해 둠 (권장)」.
- 2026-10-15 · R3 설계 중 수정 · 번호 인계를 설계문서에서 계획 · 구현까지 넓혔다 「구현을 다 안하는거도 문제이고」 · 「R3 를 넓힘 (권장)」.

## 위험 번호표

brief §5 의 번호 없는 위험 줄에 줄 순서대로 번호를 단다 — 숨은 가정 K1~K7 · 실패 양식 K8~K14 · 리뷰 참고 K15. 오른쪽은 brief 원문 그대로다.

- K1 — 위험 — 숨은 가정: 장치를 없애면 늘 의도를 지키는 쪽으로만 작동한다 — 멈춤 판정의 주인이 조사하는 모델 자신으로 옮겨 무한 조사·조기 「충분」 선언이 사용자 모르게 열린다 — 근거 포화 개념의 불안정·조기 종료 실패 양식·무한 루프 사례
- K2 — 위험 — 숨은 가정: plan·구현을 쭉 가는 것과 왜곡 장치 제거가 서로 맞는다 — 실행 중 혼자 판정(Ruling)은 쭉 가게 하는 장치이고 plan 검토 게이트는 PM 이 plan 을 볼 마지막 자리 — 근거 superpowers SDD·brainstorming 원문
- K3 — 위험 — 숨은 가정: 사용자 말 그대로가 하류에서도 그대로 읽힌다 — brainstorming 은 자기 이해 요약을 새 정본으로 삼아 조각 N개면 N번 재해석 — 근거 Cognition 병렬 에이전트·brainstorming 원문
- K4 — 위험 — 숨은 가정: 인터뷰 시점에 나눈 경계가 맞고 하류가 따른다 — 하류의 2차 분해와 충돌하고 승인된 분해가 봉인되기 쉽다 — 근거 ADaPT·brainstorming 분해 문구
- K5 — 위험 — 숨은 가정: 한 세션이 압축을 여러 번 겪어도 의도와 조각 지도를 잃지 않는다 — 근거 Anthropic 장시간 하니스
- K6 — 위험 — 숨은 가정: 조각이 늘어도 spec 승인이 실질 검토로 남는다 — 도장 찍기로 쇠퇴 — 근거 승인 피로(근거 약함)
- K7 — 위험 — 숨은 가정: 찾은 장치 목록이 완전하고 전부 왜곡이다 — 사용자 자신의 통제 자리가 섞여 있고 모델은 사용자 말에 맞추는 경향 — 근거 Sycophancy 연구
- K8 — 위험 — 실패 양식: 병렬 조각의 암묵 결정 충돌과 버전·CHANGELOG 같은 공유 파일 겹침 — 근거 Cognition·Anthropic 멀티에이전트
- K9 — 위험 — 실패 양식: 압축 뒤 조각 지도·결정 내력 소실 또는 덮어쓰기로 「한 곳」이 실제와 어긋남 — 근거 Anthropic 장시간 하니스
- K10 — 위험 — 실패 양식: 두꺼운 brief 의 역설 — 가운데 묻힌 조사·위험·열린 질문을 하류가 덜 씀 — 근거 Lost in the Middle
- K11 — 위험 — 실패 양식: 외부 문구가 바뀌면 devbrew 쪽 넘김 글이 조용히 무력화됨(설치본과 최신본이 이미 다름) — 근거 superpowers 원문 비교
- K12 — 위험 — 실패 양식: 무한 조사 또는 포화를 가장한 조기 종료 — 근거 무한 루프 사례·조기 종료 실패 양식
- K13 — 위험 — 실패 양식: spec 승인 하나만 남은 통제점이 도장 찍기로 무너지고 실행 판정이 보이지 않음 — 근거 승인 피로(근거 약함)
- K14 — 위험 — 실패 양식: 승인된 분해가 봉인돼 조각 사이를 되돌릴 경로가 없음 — 근거 ADaPT·재결정 규약이 확정 항목 단위뿐
- K15 — 위험 — 리뷰 참고 | [overdesign] #2-제약 — 번호로 추적하는 장치가 다섯 결정(D24·D40·D41·D42·D45)에 나뉘고 번호 체계가 셋이다(D24·D42 의 빠짐 경고는 같은 검사) — 사용자 발화 S 번호에 매단 원장 하나와 spec 리뷰 검사 하나로 합치는 쪽을 설계에서 검토한다(판정은 모두 남기고 구조만 합침) (리뷰 41df26ba#r1.1)
