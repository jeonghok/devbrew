---
type: roadmap
source_brief: docs/superpowers/interview/2026-11-14-framing-interview-constraint-audit-brief-interview.md
---

# 앞단(framing · 인터뷰)을 새 코어에 맞추기 — 로드맵

승인된 분해안의 에픽 지도다. 에픽마다 원본 brief · 이 로드맵 · 에픽 묶음을 넘긴다. 상태 칸은 없다 — 단계는 spec-distill 의 `scripts/roadmap_status.py` 가 git 에서 계산한다. 단위는 로드맵 > 에픽(spec 하나) > plan(PR 하나) > task 다.

## 에픽

### P1 — 공식 장치 실측
- 의도: 공식 장치(데이터 폴더 · 설정 값 받기 · 플러그인 끄기)가 devbrew 가 쓰는 방식(skill 이 Bash 로 부르는 스크립트)에서 실제로 되는지 재어 F7 설계가 쓸 사실을 남긴다
- 범위: 한다: 샌드박스를 켠 세션에서 데이터 폴더 쓰기와 쓰기 허용 설정, 작업 폴더 밖 읽기와 쓰기의 승인과 하위 agent 의 읽기, skill 본문 펜스 · 사전 실행 줄 · 보조 파일 안의 변수 치환, 플러그인 끄기 뒤 진입 skill · 훅의 동작과 반영 시점, 장치마다 필요한 Claude Code 판 / 안 한다: 스위치 · 상태를 실제로 옮기는 일
- 의존: 없음
- 브랜치: feature/official-device-probe
- 묶음: P1.md
- 경로 예약: docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/official-device-probe.md
- 크기: 작음
- 병렬: F2 · F3 · F4 · F6 과 병렬
- 순서 이유: F7 설계가 이 사실 위에서 대체 길을 정한다
- 근거: S27 · 조사 16 · 조사 20
- 흐름: 조사 — 격리한 별도 세션에서 재고 표로 남긴다
- 산출물: docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/official-device-probe.md

### F1 — 앞단 이름 정하기
- 의도: 의도 싱크 · 컨텍스트 쌓기 · 로드맵 잡기 세 단계의 호출 이름을 정해 옆 로드맵이 새 파일에 처음부터 새 이름을 쓰게 한다
- 범위: 한다: 호출 이름 셋을 사용자가 정하고 결정 기록에 남기고 옆 세션에 알린다 / 안 한다: 이름을 실제로 바꾸는 일(F5)
- 의존: 없음
- 완료: 결정 기록
- 묶음: 없음
- 경로 예약: 없음
- 발화: S1 · S2 · S7 · S8 · S17
- 항목: C36 · D10 · D15 · D16 · OQ1 · OQ4 · OQ8 · OQ17 · OQ25
- 크기: 작음
- 병렬: 모든 에픽과 병렬
- 순서 이유: 옆 로드맵이 새 파일에 쓸 이름을 기다린다
- 근거: S2 · S8 · S17

### F2 — 덩어리 승인 화면
- 의도: seed 리뷰에서 저자가 고친 덩어리를 승인하는 화면을 읽기 쉽게 고친다
- 범위: 한다: 달라진 문장만 보이기, 덩어리마다 어느 지적 때문인지 보이기, 덩어리 질문 묶기, 추천 표시와 지금 규칙(저자가 승인 여부를 가르지 않는다)의 긴장 정하기 / 안 한다: 리뷰 엔진의 판정 규칙
- 의존: 없음
- 브랜치: feature/chunk-approval-screen
- 묶음: F2.md
- 경로 예약: plugins/spec-distill/skills/request-framing/SKILL.md
- 크기: 작음
- 병렬: P1 · F4 · F6 과 병렬
- 순서 이유: 작고 독립이며 F3 과 같은 파일이라 먼저 끝낸다
- 근거: S21

### F3 — 원자료 정본 사슬
- 의도: 사용자가 준 원자료를 줄이지 않은 글이 정본이 되고, framing 뒤의 모든 단계가 seed(모델이 줄인 글)가 아니라 그 원자료를 사용자의 말로 읽는다
- 범위: 한다: 원자료를 찾는 길을 한 곳에 두기(새 모듈), framing 이 사용자의 말을 적는 모든 길의 비밀값 가리기, 고른 선택지 문장과 직접 쓴 말의 구분, 원문 절의 구분 줄, 인터뷰가 원자료 읽기, 인터뷰 결과물의 사용자 원문 첫 칸(원문 절과 질문 전체 절)과 리뷰 정답 출처(결과물 리뷰 기준과 설계문서 리뷰 기준), 끝맺음이 비밀값으로 보이는 값에서 멈추기, seed 가 맡을 일과 seed 문법, framing 에서 다른 다음 단계로 바로 가는 길, CLAUDE.md 없는 레포의 seed 리뷰 재료 / 안 한다: 원자료와 결과물을 의도 폴더에 처음부터 쓰기(옆 로드맵으로 넘김 — 설계 대화의 재결정), 로드맵 없는 일 · framing 없이 시작한 일의 새 자리(옆 로드맵 둘째 에픽), 옛 기록 옮기기, 옆 로드맵의 생성기 고치기
- 의존: F2
- 브랜치: feature/raw-source-canon, feature/raw-source-readers
- 묶음: F3.md
- 경로 예약: plugins/spec-distill/scripts/raw_source.py, plugins/spec-distill/skills/request-framing/SKILL.md, plugins/spec-distill/templates/interview-seed-audit-template.md, plugins/spec-distill/templates/interview-seed-template.md, plugins/spec-distill/scripts/seed_body.py, plugins/spec-distill/scripts/build_seed_inline_blob.py, plugins/spec-distill/references/docreview-profiles/seed.md, plugins/spec-distill/skills/pm-interview/SKILL.md, plugins/spec-distill/skills/pm-interview/references/seed-input.md, plugins/spec-distill/skills/pm-interview/references/finishing.md, plugins/spec-distill/skills/pm-interview/references/state-file.md, plugins/spec-distill/skills/pm-interview/references/steelman.md, plugins/spec-distill/agents/coverage-mapper.md, plugins/spec-distill/agents/blind-spot-prober.md, plugins/spec-distill/templates/interview-brief-template.md, plugins/spec-distill/scripts/check_verbatim_coverage.py, plugins/spec-distill/scripts/build_brief_bundle.py, plugins/spec-distill/references/docreview-profiles/brief.md, plugins/spec-distill/references/docreview-profiles/design-doc.md, plugins/spec-distill/skills/reviewing-brief/SKILL.md
- 크기: 큼
- 병렬: F4 · F6 과 병렬
- 순서 이유: 옆 로드맵을 기다리지 않고 읽는 쪽부터 고친다 — 둘째 계획(인터뷰와 결과물 리뷰 쪽)은 첫째 계획의 PR 이 머지된 뒤다
- 근거: S3 · S5 · S16

### F4 — 앞단의 끝
- 의도: 앞단의 끝이 넘김 글을 짧게 쓰고, 작은 일에서 건너뛴 조사 · 리뷰를 검사가 받아 사용자에게 보인다
- 범위: 한다: 끝맺음 절차 파일 고치기(넘김 글은 짧게 · 자세한 지시는 파일 경로로 · superpowers 가 없을 때의 끝 게이트), 머지된 PR #274 의 재리뷰가 남긴 잔여 셋 고치기(질문이 떠 있는 동안 손으로 머지됐거나 gh 가 실패로 끝났는데 실제로는 머지된 PR 이 「머지하지 않았다」 로 읽히고 origin 을 받지 않는다 · 취소가 머지 요청이 나간 직후에 닿으면 판결 줄이 없어 「머지하지 않았다」 로 읽는데 실제로는 머지됐을 수 있다 · 경로 판정이 「값의 출처」 줄을 사용자에게 한 번 더 보인다), 「모델 판단으로 건너뜀 — 이유」 를 구조 검사가 받고 승인 화면 앞에서 보이기 / 안 한다: 단계 나누기와 이름 바꾸기(F5), 작은 일을 리더로 넘기기(F5), 옆 로드맵이 넘긴 넷(F5), PR #274 가 더한 「PR 과 머지」 절을 잔여 셋 밖에서 다시 짜기
- 의존: 없음
- 브랜치: feature/front-stage-exit
- 묶음: F4.md
- 경로 예약: plugins/spec-distill/skills/pm-interview/references/finishing.md, plugins/spec-distill/scripts/check_brief.py, plugins/spec-distill/skills/pm-interview/SKILL.md, plugins/spec-distill/skills/pm-interview/references/saturation.md, plugins/spec-distill/skills/reviewing-brief/SKILL.md, plugins/spec-distill/references/brief-handoff.md
- 크기: 중간
- 병렬: P1 · F2 · F3 · F6 과 병렬
- 순서 이유: 끝맺음 파일의 주인이 이 일로 정해졌다 — 옆 로드맵을 기다리지 않는다
- 근거: S20 · S28

### F5 — 앞단 다시 짜기
- 의도: 앞단 skill 글을 줄이고, 인터뷰를 컨텍스트 쌓기와 로드맵 잡기 두 단계로 나누고, F1 이 정한 이름으로 바꾼다
- 범위: 한다: 이유 · 이력 설명 · 낡은 서술 · 옛 설계 번호 걷어내기, 단계 나누기와 단계 사이 넘김, 이름이 박힌 층(호출 이름 · 설정 키 · 설계문서 머리 키 · 파일 이름 끝 · 산출물 종류 글자 · 폴더 이름) 가운데 바꿀 것 정하기, 옛 기록을 읽는 길, major 판 올림, 작은 일을 리더로 넘기기(옆 로드맵 둘째 에픽이 받는 길을 정한 뒤), 옆 로드맵이 넘긴 넷(분해 전에 원자료 파일 만들기 · 분해 승인 화면에 지시 원문 범위 보이기 · 끝내기 커밋 범위와 PR 파일 세기에 역할 문서 넷과 HANDBOOK.md 넣기 · 로드맵 생성을 인터뷰 커밋 뒤로), 묻지 않은 다섯(확인 표시가 사용자 원문 문장에 안 붙는 것 · 라운드 꼴 고정 · 의심 게이트의 추천 봉쇄 · 조사 호출 상한 · 쉬운 말 규칙의 사용자 이름)과 에픽 넘김 줄의 「사용자 선호」 라벨, 저술 가이드를 새 코어(팀 구조)에 맞추기(F6 이 넘김 — 옆 로드맵의 팀 구조가 머지된 뒤), 철학 문서의 P8 밖에서 앞단에 닿는 문장과 낡은 서술 훑기(F6 이 넘김), F4 가 넘긴 것(에픽 넘김 글의 낡은 문장 하나 · 끝맺음 마지막 리뷰가 남긴 작은 지적들 · 인터뷰 소개 문구와 종료 조건 문장이 건너뜀을 말하지 않는 것 — 할지는 설계 대화에서 다시 묻는다), 나눈 두 단계 모두가 원자료를 읽게 하기(F3 이 넘김) / 안 한다: 옛 기록 파일 옮기기, 옆 로드맵이 예약한 파일을 순서 맞추기 없이 고치기
- 의존: F1, F3, F4, F6
- 브랜치: feature/front-stage-restructure
- 묶음: F5.md
- 경로 예약: plugins/spec-distill/skills/request-framing/SKILL.md, plugins/spec-distill/skills/pm-interview/SKILL.md, plugins/spec-distill/skills/pm-interview/references/finishing.md, shared/tests/test_invocation_surface.sh, docs/plugin-authoring.md, docs/philosophy/devbrew-harness-philosophy.md
- 크기: 큼
- 순서 이유: 동작을 바꾸는 에픽이 끝난 뒤에 글 줄이기 · 나누기 · 이름 바꾸기를 한다 — 락이 의도한 변경과 회귀를 가르게
- 근거: S2 · S8 · S17 · 조사 10

### F6 — 규칙 개정
- 의도: CLAUDE.md · 저술 가이드 · 철학 문서에서 공식과 다른 자리 가운데 사용자가 고른 것을 공식 쪽으로 옮기고 낡은 서술을 고친다
- 범위: 한다: cost_class 를 metadata 아래로, integrity 규칙 걷어내기, skill 의 disallowed-tools 반영, plugin.json 필수 키 완화, 판 올림을 설치본 동작이 바뀔 때로(올림 단위의 정의 포함), 저술 가이드의 낡은 예시와 문법 안내, 철학 문서의 P8 밖 두 문장(integrity · cost_class 를 말하는 자리), 그 규칙을 글자로 박은 락과 감사 검사 / 안 한다: agent 의 model 키 허용(설계 대화에서 다시 정했다 — 이 로드맵은 하지 않는다), 저술 가이드를 새 코어에 맞추기(F5), 철학 문서의 앞단에 닿는 문장과 낡은 서술 훑기(F5), 원칙 P8 문장(옆 로드맵), 의존을 plugin.json 에 선언하기, kill switch 와 상태 자리(F7)
- 의존: 없음
- 브랜치: feature/rules-toward-official
- 묶음: F6.md
- 경로 예약: CLAUDE.md, docs/plugin-authoring.md, docs/philosophy/devbrew-harness-philosophy.md, docs/git-workflow/commit-conventions.md, shared/README.md, shared/entry/check_invocation_surface.py, plugins/plugin-audit/scripts/check-shape-completeness.py, plugins/plugin-audit/scripts/check-staleness.py, plugins/plugin-audit/skills/plugin-audit/SKILL.md, plugins/project-init/skills/project-init/SKILL.md, plugins/quality-gates/skills/artifact-critique/SKILL.md, plugins/quality-gates/skills/quality-pipeline/SKILL.md, plugins/spec-distill/skills/epic-conductor/SKILL.md, plugins/spec-distill/skills/pm-interview/SKILL.md, plugins/spec-distill/skills/request-framing/SKILL.md, plugins/spec-distill/skills/reviewing-brief/SKILL.md, plugins/spec-distill/skills/roadmap-status/SKILL.md, plugins/spec-distill/skills/spec-review/SKILL.md
- 크기: 큼
- 병렬: P1 · F2 · F3 · F4 와 병렬
- 순서 이유: 옆 로드맵 둘째 에픽과 같은 파일이라 머지 순서를 맞춘다
- 근거: S6 · S9 · S10 · S18 · S23

### F7 — 스위치와 상태 자리 이전
- 의도: 환경변수 kill switch 와 프로젝트 안 상태 폴더를 공식 장치로 옮긴다
- 범위: 한다: 스위치마다 공식 대응물 정하기(플러그인 끄기 · skill 거부 규칙 · 플러그인 사용자 옵션)와 대응물이 없는 것만 환경변수로 남기기, 상태 파일마다 공식 데이터 폴더(프로젝트마다 갈리게)로 갈 것과 꼭 둬야 해서 docs 아래로 갈 것 가르기, 비교용 작업 사본을 그냥 워크트리로, 쓰기가 막히는 세션의 길, 옛 환경변수를 한 판 동안 함께 읽고 꺼져 있음을 알리기, kill switch 은퇴 공시, Claude Code 최소 판, 모델 판단으로 건너뛴 재비판을 리뷰 엔진이 kill switch 사유로 적는 글자 가르기(F4 가 넘김), CLAUDE.md 의 런타임 상태 · 훅 절과 감사 검사의 「모든 훅에 kill switch」 문장(F6 이 넘김) / 안 한다: 실측(P1)
- 의존: P1, F6
- 브랜치: feature/official-switches-state
- 묶음: F7.md
- 경로 예약: CLAUDE.md, shared/killswitch/kill_switch_active.py, shared/entry/entry_preflight.py, plugins/spec-distill/scripts/state_path.py, plugins/quality-gates/scripts/setup-qg.sh, plugins/plugin-audit/scripts/prepare-run-dir.py
- 크기: 큼
- 순서 이유: 실측과 규칙 개정이 먼저 있어야 무엇으로 옮길지 정한다
- 근거: S13 · S14 · S22 · S26 · S27

## 지휘 절차

이 로드맵은 지휘자가 이끈다 — `/spec-distill:epic-conductor docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/roadmap.md`. 다시 불러도 git 과 기계 상태에서 상태를 다시 계산해 같은 자리에서 잇는다. `DEVBREW_SPEC_DISTILL_DISABLE=1` 로 꺼 두면 spec-distill 전체(리뷰 · 상태 계산 포함)가 꺼진다 — 지휘자 없이 진행하려면 끄지 말고 지휘자를 부르지 않은 채 spec-distill 의 `references/conducting.md` 끝 절 「손으로 따르는 절차」 를 따른다.

- 사람 몫(brainstorming · spec 승인 · 계획의 설계에 없던 결정)은 지휘 세션이 한 번에 한 에픽씩 배경과 함께 묻는다.
- 실행 방식은 writing-plans 가 권하는 방식이고, 계획 검토는 계획에 설계에 없던 결정이 있을 때만 기다린다.
- 머지는 사용자가 한다.

## 결정 기록

줄 형식은 `- <블록> · <결정|머지> · <YYYY-MM-DD> · 「원문」` 이다. 인터뷰 뒤의 사용자 말은 새 S 번호 없이 원문 그대로 인용한다. 「머지」 줄은 PR 없이 로컬에서 머지한 에픽에만 적는다 — PR 로 머지한 에픽은 지휘자가 채운 PR 상태로 머지됨이 된다(squash · rebase 포함).

- F1 · 결정 · 2026-11-15 · 「앞단 이름 정하기(F1) — 지금의 /spec-distill:request-framing(「의도 싱크」 단계)을 앞으로 무슨 이름으로 부를까요?」 → 「intent-sync (권장)」
- F1 · 결정 · 2026-11-15 · 「앞단 이름 정하기(F1) — 인터뷰를 둘로 나눈 앞 단계(「컨텍스트 쌓기」 — 조사로 맥락을 쌓는 단계)를 무슨 이름으로 부를까요?」 → 「context-build (권장)」
- F1 · 결정 · 2026-11-15 · 「앞단 이름 정하기(F1) — 인터뷰를 둘로 나눈 뒤 단계(「로드맵 잡기」 — 일을 에픽으로 나눠 로드맵을 만드는 단계)를 무슨 이름으로 부를까요?」 → 「roadmap-draft (권장)」

## 재분해 이력

### 2026-11-14 · 처음 로드맵
- 원문:
  - 「승인 (권장)」

### 2026-11-15 · 옆 로드맵이 넘긴 넷과 작은 일을 리더로 넘기기를 F4 에서 F5 로 옮긴다 — 넷은 지금 끝맺음의 순서로는 돌 수 없고 F5 가 만드는 「로드맵 잡기」 단계의 일이다
- 바뀜: 바뀐 에픽 F4 · F5 「추천으로」 · 「이대로 다시 나눈다 (권장)」
- 원문:
  - 「추천으로」
  - 「이대로 다시 나눈다 (권장)」

### 2026-11-17 · 설계 대화에서 정한 것을 에픽 칸에 맞춘다 — F3 은 의도 폴더에 쓰기를 옆 로드맵으로 넘기고(길 1) 범위 · 브랜치 · 경로 예약을 승인된 설계에 맞춘다, F6 은 agent 의 model 키 허용을 범위에서 빼고(설계 대화의 재결정) 넘긴 둘을 F5 가 받는다, F7 은 F4 · F6 이 넘긴 둘을 받는다
- 바뀜: 바뀐 에픽 F3 · F5 · F6 · F7 「길 1로 가자」 · 「이대로 다시 나눈다 (권장)」
- 원문:
  - 「길 1로 가자」
  - 「이대로 다시 나눈다 (권장)」

## 위험 번호표

번호는 brief §5 위험 줄마다 박힌 번호(`- 위험 K<n> — …`)다. 박은 번호는 그 위험의 정체다 — 지운 위험의 번호는 다시 쓰지 않는다. 번호가 박히지 않은 옛 brief 만 숨은 가정 · 실패 양식 · 리뷰 참고 순으로 줄 순서대로 번호를 달고, 그렇게 매겼다고 알린다. 오른쪽은 brief 원문 그대로다.

- K1 — 위험 — 숨은 가정: 의역은 seed 산문 · 번호 항목 · 묶음으로 옮기는 단계에서만 생긴다 — 질문과 선택지를 쓰는 자리에서도 생긴다 — 사용자가 반드시 다룰 것으로 골랐다(S19) · 조사 10
- K2 — 위험 — 숨은 가정: 옆 설계문서를 잣대로 삼아도 사용자 결정의 전제가 그대로다 — 그 문서는 인터뷰 동안 여러 번 바뀌었고 S3 의 근거 문장이 사라져 S16 으로 다시 물었다 — 조사 10 · 조사 19
- K3 — 위험 — 숨은 가정: 맞출 대상인 새 코어는 검증이 끝난 목표다 — 옆 로드맵 스스로 토큰이 준다는 것을 숨은 가정으로 적었고 비교 기준선이 아직 없다 — 조사 10
- K4 — 위험 — 숨은 가정: 원자료를 글자 그대로 추적 파일에 두는 것은 안전하다 — 붙여 넣은 글에 비밀값이 있으면 정본에 들어간다 — 사용자가 반드시 다룰 것으로 골랐다(S19) · 조사 10
- K5 — 위험 — 숨은 가정: 원자료 전체를 설계마다 읽히는 것이 읽는 양 줄이기와 함께 간다 — 원자료 파일은 덧붙이기만 해서 커지기만 한다 — 조사 10
- K6 — 위험 — 숨은 가정: 호출 이름 바꾸기는 한 시점에 끝난다 — 이름은 산출물 종류 글자와 파일 이름에도 박혀 있고 옛 판을 실은 세션이 함께 돈다 — 조사 10
- K7 — 위험 — 숨은 가정: 앞단 글에서 이유와 이력 문장을 걷어내면 순수한 이득이다 — 이유가 사라지면 모델이 규칙을 넓게 맞춰 쓰는 근거도 사라지고, 압축 뒤에는 skill 본문의 앞부분만 다시 붙는다 — 조사 10
- K8 — 위험 — 숨은 가정: 인터뷰에는 컨텍스트 쌓기와 로드맵 잡기로 가를 깨끗한 솔기가 있다 — 지금 끝맺음은 두 일이 맞물려 돈다 — 조사 10
- K9 — 위험 — 숨은 가정: 새 코어에 맞추기와 공식 쪽으로 옮기기를 한 일이 실어도 된다 — 닿는 파일과 락이 다르다. 에픽으로 나눠 다뤘다 — 사용자가 반드시 다룰 것으로 골랐다(S19) · 조사 10
- K10 — 위험 — 숨은 가정: skill 이 Bash 로 부르는 스크립트가 공식 데이터 폴더에 쓸 수 있다 — 샌드박스를 켠 세션에서는 재지 못했다 — 조사 16 · 조사 20 · S27
- K11 — 위험 — 숨은 가정: 공식 설정 값 받기가 스크립트까지 닿는다 — 문서가 적는 길은 skill 본문 치환과 훅 프로세스뿐이다 — 조사 20
- K12 — 위험 — 실패 양식: 사용자가 고른 결정의 근거 문장이 상류에서 조용히 바뀐 채 설계가 진행된다 — 두 로드맵 사이에 바뀐 사실을 알리는 길이 세션 메시지뿐이다 — 조사 10
- K13 — 위험 — 실패 양식: 이름을 바꾼 뒤 옛 이름 세션과 새 이름 세션이 함께 돌고 실패가 오타와 구별되지 않는다 — 옛 기록의 다음 세션 줄은 옛 이름을 쓴다 — 조사 10 — 사용자가 반드시 다룰 것으로 고르지는 않았다
- K14 — 위험 — 실패 양식: 비밀값이 든 붙여넣기 글이 지울 수 없는 정본이 된다 — 가리려 하면 앞 줄 수정 거절과 바이트 대조에 걸린다 — 조사 10
- K15 — 위험 — 실패 양식: 가벼운 길이 기본 길이 된다 — 건너뛰는 쪽이 스스로 작다고 판정하고 사유도 그쪽이 쓴다 — 조사 10
- K16 — 위험 — 실패 양식: 락이 의도한 변경과 회귀를 가르지 못한다 — 이름 바꾸기 · 나누기 · 글 줄이기 · 원자료 사슬이 같은 세 파일과 테스트 58개에 겹쳐 들어간다 — 조사 10
- K17 — 위험 — 실패 양식: 가른 두 단계 사이에서 맥락이 한 번 더 줄어든다 — 파일에 적히지 않은 조사 맥락은 둘째 단계에 오지 않는다 — 조사 10
- K18 — 위험 — 실패 양식: 로드맵이 없는 일과 framing 없이 시작한 일에 원자료의 집이 없다 — 로드맵 폴더는 분해 승인 뒤에야 생긴다 — 조사 10 · 조사 19
- K19 — 위험 — 실패 양식: CLAUDE.md 를 두 로드맵이 다른 잣대로 함께 고친다 — 문장 전체를 박은 테스트가 둘째로 머지하는 쪽에서 깨진다 — 조사 10
- K20 — 위험 — 실패 양식: 기능 끄기 스위치 넷은 문장으로만 꺼져서, 공식 장치로 옮길 때 옮길 코드가 없다 — 조사 17
- K21 — 위험 — 실패 양식: 올림 단위를 풀 때 글자 사본으로 실리는 정본을 놓쳐 설치본이 바뀌었는데 판이 그대로 남는다 — 조사 18
- K22 — 위험 — 실패 양식: 공식 데이터 폴더는 플러그인을 지우면 함께 지워져 다시 만들 수 없는 기록을 잃는다 — 조사 15 · 조사 20
- K23 — 위험 — 실패 양식: 작은 일이 조사와 리뷰는 건너뛰면서 리더 넘김은 다 밟는 꼴로 굳는다 — 작은 일의 가벼운 길(D6 · D26)과 작은 일도 리더로 넘기는 끝(D4)이 만나는 자리를 seed 가 풀리지 않은 긴장으로 적었다. 앞단의 끝 에픽이 둘을 함께 설계한다 — seed 의 「다시 검증할 것」 · 리뷰 지적 c1fa84d8#r1.1
