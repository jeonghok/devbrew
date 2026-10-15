---
name: roadmap-control-plane
type: design
created_at: 2026-10-15
source_interview: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R6.md
roadmap: docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md
next_phase: superpowers:writing-plans
---

# R6 — 컨트롤 플레인 · Design

> 에픽 지도 · 단계 · 빠진 것 · 드리프트를 Claude Code 화면 안에서 늘 보이게 한다 — 상태줄 한 줄, 자세히는 명령 하나, 세션 안에서는 작업 목록.

승인된 로드맵(S47)의 에픽 R6 이다. 로드맵 전체에서의 자리는 `roadmap.md` 의 `### R6` 블록이고, 이웃 에픽 R1 · R2 · R3 · R4 ·
R7 과 병렬로 간다(의존 R0). 이 에픽은 표시만 하고 상태 계산은 R0 · R5 의 몫이다.

## 목차

- [Handoff Context](#handoff-context)
- [Context / Why](#context--why)
- [Goals](#goals) · [Non-goals](#non-goals) · [Constraints](#constraints)
- [설계](#설계)
  - [§1 표시 스크립트](#1-표시-스크립트)
  - [§2 진입 skill · 상태줄 설치 · 작업 목록 · 끄기 스위치](#2-진입-skill--상태줄-설치--작업-목록--끄기-스위치)
  - [§3 위험에 대한 답](#3-위험에-대한-답)
- [Acceptance Criteria](#acceptance-criteria) · [Files to Modify](#files-to-modify) · [Verification Plan](#verification-plan)
- [Rejected Alternatives](#rejected-alternatives) · [결정 기록](#결정-기록) · [번호 대조](#번호-대조) · [Metadata](#metadata)

## Handoff Context

- 입력: 에픽 묶음 `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R6.md` (원본 brief
  `docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md` 와 로드맵을 거꾸로 가리킴).
- 실측 근거: 같은 폴더 `measurements.md` 의 M2(작업 목록은 `/compact` 뒤 남고 `/new` 뒤 빈다 — 세션 안 표시로만) · M3(플러그인은 메인
  `statusLine` 을 줄 수 없다 — 사용자 · 프로젝트 설정만). brainstorming 중 실측: `roadmap_status.py --json` 한 번 0.55~0.57초(세 번).
- brainstorming 결정: `## 결정 기록` B1~B8.
- 브랜치 `feature/roadmap-control-plane` · worktree `.claude/worktrees/roadmap-control-plane`.

## Context / Why

사용자는 통제가 살아 있다는 것을 「전체 조각과 순서 · 의존, 각 조각이 어느 단계에 있는지를 한 곳에서 볼 수 있다」로 정했고(C8), 그
한 곳은 파일이 아니라 Claude Code 안이며(C19 · D22), 모르는 사이의 드리프트는 피한다(C19). 실행 판정(Ruling)도 보이기로 했다(C27).
보여야 할 것은 여럿의 산출물이다 — 에픽 단계(R0 `roadmap_status.py`), 빠짐 · 얕음 · 받드는 에픽 없는 발화 · 받는 곳 없는 미룸(R3),
포화 판정 · 조사 상한 도달(R1 — D23 · D43), 판정 줄(R5).

지금은 지휘 세션이 상태 계산을 돌려 작업 목록을 손으로 맞춘다. 작업 목록은 `/new` 뒤 비고(M2), 메인 상태줄은 플러그인이 켤 수
없다(M3). 상태 계산은 한 번에 약 0.56초라 매 화면 갱신마다 돌리기에는 무겁다.

## Goals

- G1 상태줄 한 줄이 에픽 단계 요약 · 경고 수 · 진행 중 인터뷰 조사 수 · 마지막 fetch 경과를 늘 보인다. 상태줄 명령이 플러그인을 못
  찾으면 빈 줄이 아니라 그 사실을 보인다.
- G2 명령 하나로 에픽 지도 · 경고 · 인터뷰 · 판정 줄을 자세히 본다.
- G3 지휘 세션의 작업 목록을 기계 줄로 맞춘다.
- G4 「없음」과 「확인 못 함」을 섞지 않는다 — 검사 실패는 「검사 불가」로 보인다.

## Non-goals

- 상태 계산 자체 · 판정 줄 형식 — R0 · R5. 경고를 만드는 일 — R1 · R3.
- 훅 알림(TaskCreated · TaskCompleted) — B5 로 쓰지 않는다.
- devbrew 밖 레포의 경로 규약 일반화 — R8.

## Constraints

- 외부 플러그인은 건드리지 않는다(C25 · C35 · D26). 실험 기능은 기반으로 쓰지 않는다(D33) — 기반은 작업 목록 · 상태줄 설정 · 진입 skill.
- 있는 것을 다시 만들지 않는다(C32) — 단계 · 경고는 `roadmap_status.py --json` 을 읽기만 한다.
- 레포 · git 상태를 바꾸지 않는다. 쓰는 것은 캐시 파일 하나.
- 새 command 파일을 만들지 않는다 — 진입 skill 로(레포 skill 전용 진입 규칙).
- 매번 도는 명령도 끄기 스위치를 존중한다.

## 설계

### §1 표시 스크립트

새 `plugins/spec-distill/scripts/control_plane.py`.

1. **읽는 것.** ① `roadmap_status.py --json` — 블록 단계 · 이유 · 의존(`deps`) · 블록 `warnings[]` · `exit`, 그리고 맨 위 칸
   `orphans`(받드는 에픽 없는 발화) · `unassigned`(미배정 번호) · `unknown_ids`(brief 에 없는 번호). 맨 위 세 칸도 경고로 읽어
   경고 수에 넣고 `show` 에 보인다 — 값이 `null` 이면 「셀 수 없음」이다. ② R7 의 인터뷰 상태 파일
   (`docs/superpowers/interview/*-interview.state.md`) 중 짝 brief 가 없는 것의 R1 포화 판정 줄과 조사 상한 줄(`research_dispatches` ·
   `research_limit`). R7 이 아직 머지되지 않았으면 이 항목은 「셀 수 없음」. ③ `roadmap_status.py --json` 블록의 `rulings[]` — R5 가 더할
   칸 이름을 여기서 약속한다. 없으면 그 절을 내지 않는다.
2. **로드맵 고르기.** origin/main 트리의 `docs/superpowers/roadmaps/*/roadmap.md` 중 끝나지 않은 블록(머지됨 · 끝남이 아닌)이 있는 것 전부.
   인자로 경로를 주면 그것만. 상태 계산은 `roadmap_status.py <경로> --json`(origin/main 사본 — 지휘 절차 1번과 같은 사본)으로 부르고,
   작업 트리 사본(`--roadmap-file`)은 쓰지 않는다. 그래서 아직 main 에 없는 로드맵은 고르기 대상이 아니고, 인자로 주면 상태 계산이
   「로드맵을 못 읽었다」로 3 을 내 `· 검사 불가` 로 보인다.
3. **`statusline`.** 한 줄: `<로드맵 폴더 이름> · 설계 <a> · 구현 <b> · 준비 <c> · 경고 <w> · 받은 지 <분>분`. 경고 0 이면 `경고 없음`.
   진행 중 인터뷰가 있으면 `· 인터뷰 조사 <n>/<limit>`. 상태 계산이 3 이면 `· 검사 불가`. 로드맵이 없으면 로드맵 부분을 빼고, 진행 중
   인터뷰가 있으면 `인터뷰 조사 <n>/<limit>` 만, 그것도 없으면 빈 줄.
4. **`show`.** 첫 줄은 상태 계산의 쉬운 첫 줄 그대로. 이어 블록마다 `<번호> <이름> — <단계> · <이유>` 와 들여쓴 경고, 인터뷰 절, 판정 줄 절.
   의존(`deps`) 중 단계가 머지됨 · 끝남이 아닌 것이 있으면 블록 줄 끝에 `← 기다림: R2 · R7` 처럼 기다리는 에픽을 붙인다. 맨 위 경고
   (`orphans` · `unassigned` · `unknown_ids`)는 블록 뒤에 「받드는 에픽 없는 발화」 · 「미배정 번호」 · 「brief 에 없는 번호」 줄로 낸다.
5. **`show --tasks`.** 블록마다 한 줄 `<번호> <이름> — <단계>\t<pending|in_progress|completed>` — 지휘 절차가 작업 목록을 맞출 때 읽는다
   (상태 계산의 `task_status` 매핑을 그대로 쓴다). `task_status` 가 `null` 인 블록(매핑에 없는 단계)도 줄을 내되 첫 칸 끝에
   「알 수 없음(<이유>)」을 붙이고 둘째 칸을 `keep` 으로 해 지휘자가 작업 상태를 바꾸지 않게 한다. 상태 계산이 3 이면 표준 출력에 아무것도
   내지 않고 「검사 불가」 사유를 표준 오류에 내며 0 이 아닌 코드로 끝난다 — 지휘 절차 1번의 「종료 코드가 3 이면 작업 목록을 바꾸지
   않는다」를 기계 쪽에서 지킨다.
6. **캐시.** `<git rev-parse --git-common-dir>/devbrew/control-plane.json`. 키 = `origin/main` 커밋 · `git for-each-ref` 의 브랜치 머리
   목록 해시 · 대상 로드맵의 origin/main 사본 내용 해시 · 진행 중 인터뷰 상태 파일의 mtime. 키가 같으면 캐시를 쓰고, 다르면 다시 계산해 원자적으로
   쓴다(임시 파일 + `os.replace`). 캐시가 깨졌거나 쓸 수 없으면 캐시 없이 계산하고 `show` 에 「캐시를 쓰지 못했다 — <사유>」 한 줄.
7. **받은 지 N분.** 캐시 밖에서 매 호출마다 읽는다 — 상태 계산의 `fetched_at` 과 같은 출처(이 워크트리와 공용 git 디렉토리의
   `FETCH_HEAD` 수정 시각 중 새것)를 직접 본다. 그래서 새 커밋 없는 fetch(캐시 키 불변)도 경과를 새로 맞춘다. 숫자 기준으로 경고하지 않는다.
8. **읽기 전용.** 레포 파일과 git 상태를 바꾸지 않는다. Python 은 `-I` 없이 스크립트로 부르고 인라인 python 은 쓰지 않는다(레포 규칙).

### §2 진입 skill · 상태줄 설치 · 작업 목록 · 끄기 스위치

1. **진입 skill `roadmap-status`**(`plugins/spec-distill/skills/roadmap-status/SKILL.md`, 호출 `/spec-distill:roadmap-status [<로드맵 경로>]`):
   다른 진입 skill 과 같은 `!` 사전 검사 줄 · `## 진입 단계` 표를 두고, `control_plane.py show` 출력을 그대로 보인다. 쉬운 말 규칙(첫 줄 상태 ·
   끝 할 일 하나). `cost_class: low`.
2. **상태줄 설치 안내.** README 에 사용자 설정 `~/.claude/settings.json` 의 `statusLine` 덩어리와, 이미 상태줄을 쓰는 사용자를 위한
   「기존 명령 뒤에 이어 붙이기」 예. 규칙: 설치 명령은 버전이 붙은 플러그인 폴더를 박아 두지 않는다 — 플러그인이 갱신되면 그 폴더가
   바뀌기 때문이다. 명령은 실행 때마다 설치된 spec-distill 의 최신 사본을 찾아 `control_plane.py statusline` 을 부르고, 못 찾으면 빈 줄
   대신 「상태줄 꺼짐 — 플러그인을 못 찾음」을 낸다(「로드맵 없음」의 빈 줄과 구별된다). 설치 위치를 찾는 정확한 명령은 이 문서가 단정하지
   않는다 — 계획이 실제 설치본에서 재서 정한다. 플러그인이 대신 켜 줄 수 없다는 사실(M3)을 적는다. devbrew 레포의 프로젝트 설정에는 커밋하지 않는다.
3. **작업 목록.** 로드맵 `## 지휘 절차` 1번이 `roadmap_status.py` 를 직접 읽는 대신 `control_plane.py show --tasks` 줄로 작업 목록을 맞추게
   한 줄 고친다 — 로드맵 수정 PR(지휘 절차 6). R5 지휘자가 같은 줄을 쓴다.
4. **끄기 스위치.** `control_plane.py` 는 `DEVBREW_SPEC_DISTILL_DISABLE=1` 또는 `DEVBREW_SKIP_HOOKS` 에 `spec-distill:statusline` 이 있으면
   `statusline` 은 빈 줄, `show` 는 「꺼져 있다 — <스위치>」 한 줄을 내고 rc 0. README 스위치 목록에 공시.

### §3 위험에 대한 답

- K6 · K13(spec 승인 하나만 남은 통제점이 도장 찍기로 무너지고 실행 판정이 보이지 않음) — 실행 판정 · 경고가 상태줄 · 지도에 늘 보여
  승인 밖에도 통제 자리가 생긴다(§1-3 · §1-4). 승인 때의 이웃 결정 · 위치는 R3(§4-4)가 보인다.
- OQ34 · RC80(작업 목록 · 패널로 보일 수 있는 범위, 훅 배달지 실측) — 확인된 자리 셋(작업 목록 · 상태줄 · 명령)으로 닫는다. 훅 알림은 쓰지
  않는다(B5) — 훅을 더하면 끄기 스위치 · README 공시 · 훅 공존 규칙이 따르고 얻는 것은 단계 변경 한 줄뿐이다.

## Acceptance Criteria

- AC1 `control_plane.py statusline` 이 §1-3 모양의 한 줄을 내고, 경고 0 · 진행 중 인터뷰 · 검사 불가 · 로드맵 없음(인터뷰도 없으면 빈 줄,
  진행 중 인터뷰가 있으면 인터뷰 조각만) 의 모양이 고정된다. 경고 수에 맨 위 `orphans` · `unassigned` · `unknown_ids` 가 들어간다.
- AC2 `show` 의 첫 줄이 상태 계산의 첫 줄과 같고, 블록 · 경고 · 인터뷰 · 판정 줄 절이 §1-4 대로다. `rulings[]` 가 없으면 그 절이 없다.
  끝나지 않은 의존이 있는 블록 줄에 `← 기다림: <번호들>` 이 붙고 의존이 다 끝난 블록에는 붙지 않는다. 맨 위 `orphans` 가 비지 않으면
  「받드는 에픽 없는 발화」 줄이 그 번호들과 함께 나온다.
- AC3 `show --tasks` 가 블록마다 탭으로 나뉜 두 칸을 내고 상태가 `task_status` 와 같다. `task_status` 가 `null` 인 블록은 첫 칸 끝
  「알 수 없음(<이유>)」 · 둘째 칸 `keep` 이다. 상태 계산이 3 이면 표준 출력이 비고 표준 오류에 사유가 있고 종료 코드가 0 이 아니다.
- AC4 캐시 키가 같으면 상태 계산을 다시 부르지 않고(호출 수 단언), 키 요소 하나가 바뀌면 다시 계산한다(요소별 넷).
- AC5 깨진 캐시 · 쓸 수 없는 캐시 디렉토리에서 캐시 없이 맞는 결과를 내고 `show` 에 사유 한 줄.
- AC6 끄기 스위치 둘에서 `statusline` 빈 줄 · `show` 한 줄 · rc 0.
- AC7 `control_plane.py` 실행 전후 `git status --porcelain` 과 HEAD 가 같다(캐시 파일은 git 디렉토리 안).
- AC8 진입 skill `roadmap-status` 가 진입 규칙(사전 검사 줄 · `## 진입 단계` · `cost_class`)을 지키고 호출 표면 락을 통과한다.
- AC9 README 에 `statusLine` 설치 덩어리 · 이어 붙이기 예 · 스위치 공시가 있다. 설치 명령은 버전 붙은 플러그인 폴더를 박지 않고
  실행 때 설치본을 찾으며, 못 찾으면 「상태줄 꺼짐 — 플러그인을 못 찾음」을 낸다(설치본 없는 환경에서 재 확인).
- AC10 실데이터(이 로드맵)에서 캐시가 맞을 때 `statusline` 시간을 재 계획에 적고, 캐시 없는 경우보다 짧다.
- AC11 통과가 정답인 새 단언(AC4 · AC6 · AC7)은 변이로 이빨을 확인하고 양성 대조를 둔다.
- AC12 spec-distill minor bump.
- AC13 캐시가 맞는 두 호출 사이에 새 커밋 없이 `FETCH_HEAD` 수정 시각만 바뀌면 둘째 호출의 「받은 지 N분」이 새 시각을 따른다(상태 계산은
  다시 부르지 않음).

## Files to Modify

- 새 `plugins/spec-distill/scripts/control_plane.py`, 새 `plugins/spec-distill/skills/roadmap-status/SKILL.md`
- `plugins/spec-distill/README.md`(상태줄 설치 · 스위치 · 진입 skill), `CHANGELOG.md`, `.claude-plugin/plugin.json`
- 테스트: 새 `test_control_plane.sh`(버릴 git 저장소 픽스처), 호출 표면 락 갱신(새 진입 skill)
- 로드맵 `## 지휘 절차` 1번 한 줄 — 로드맵 수정 PR

## Verification Plan

- 작업 전 기준선: spec-distill · shared 스위트의 FAIL «이름» 집합(선재 RED `test_hook_output_schema.py test_python_and_bash_resolvers_agree`).
- 픽스처 git 저장소로 AC1~AC7 · AC13(캐시 키 요소별 · 깨진 캐시 · 스위치 · 읽기 전용 · 캐시 밖 받은 시각).
- 진입 skill 은 `shared/tests/test_invocation_surface.sh` 와 진입 사전 검사 락.
- 실데이터 시간 측정(AC10)은 세 번 재서 중앙값.
- 닿은 소비자 전부의 스위트를 레포 루트에서. 새 셸 테스트는 실행 비트(100755).

## Rejected Alternatives

- 상태줄만, 캐시 없이 — 매 갱신 0.56초, 자세히 보기가 스크립트 출력(B3).
- 세션 시작 훅 주입 — 세션 중간 드리프트를 놓치고 새 훅이 생긴다(B3).
- 프로젝트 설정에 `statusLine` 커밋 — 다른 레포로 가지 않는다(B1).
- 상태줄 포기 — 「항상 보임」(B2)이 사라진다.
- 세션 시작 때 한 번 + 명령 · 명령으로만 — 모르는 사이의 드리프트를 놓친다(B2).
- 훅 알림 실측 · 도입 — 구현 중 사람 정지가 생기고 훅 무게가 는다(B5).
- `.claude/` 아래 캐시 — R7 의 「`.claude` 는 리뷰 원장만」과 어긋난다.

## 결정 기록

줄 형식은 로드맵과 같다. 인터뷰 뒤의 사용자 말은 새 S 번호 없이 원문 그대로 인용한다.

- B1 · 결정 · 2026-10-15 · 상태줄을 켜는 방법 — 「명령만 주고 설치 안내 (권장)」
- B2 · 결정 · 2026-10-15 · 경고를 보이는 때 — 「상태줄에 항상 + 상세는 명령 (권장)」
- B3 · 결정 · 2026-10-15 · 컨트롤 플레인 모양 — 「A. 스크립트 + 진입 skill + 캐시 (권장)」
- B4 · 결정 · 2026-10-15 · R6 이해 확인 — 「맞다 (권장)」
- B5 · 결정 · 2026-10-15 · 패널로 훅 알림 실측 — 「실측 없이, 확인된 자리로 (권장)」
- B6 · 결정 · 2026-10-15 · 설계 1절 표시 스크립트 — 「맞다, 다음 절로 (권장)」
- B7 · 결정 · 2026-10-15 · 설계 2절 진입 skill · 설치 · 작업 목록 · 스위치 — 「맞다, 설계문서 작성 (권장)」
- B8 · 판정 · 2026-10-15 · 새 세션 작업 목록 재충전은 지휘 절차(나중 R5)가 `show --tasks` 로 — 상태 계산은 R0 · R5 의 몫이라는 로드맵 범위에서.
- B9 · 결정 · 2026-10-15 · 마지막 리뷰 항목 처리 — 「여섯 다 반영 · 라운드 없음 (권장)」
  - 물은 두 항목을 받아들였다: 2a35df00#r1.1(`show` 블록 줄에 기다리는 에픽 — §1-4 · AC2) · 716bc436#r1.3(받은 시각을 캐시 밖에서
    매번 — §1-7 · AC13).
  - 권고 네 항목은 리뷰 뒤 반영(리뷰 라운드를 거치지 않았다): 5c99a996#r1.1(설치 명령이 버전 폴더를 박지 않음 · 못 찾음 표시 — §2-2 ·
    AC9 · G1) · 716bc436#r1.1(로드맵 없이 진행 중 인터뷰 — §1-3 · AC1) · b0fc0ffb#r1.2(`show --tasks` 의 `keep` 표시와 3 일 때 빈 출력 —
    §1-5 · AC3) · 716bc436#r1.5(맨 위 `orphans` · `unassigned` · `unknown_ids` 를 경고로 — §1-1 · §1-4 · 번호 대조 D41).
  - 계획으로 미룬 두 항목: 716bc436#r1.2 · 716bc436#r1.4 — `### Deferred to plan`.

## 번호 대조

| 번호 | 처리 | 자리 · 이유 |
|---|---|---|
| C7 | 반영 | §3 — 사용자 결정권 · 검토가 승인 밖에서도 보이는 자리 |
| C8 | 반영 | Goals · §1 — 전체 · 순서 · 의존 · 단계를 한 곳에서 |
| C17 | 반영 | §1 — 「구조적으로 정리」: 표시를 스크립트 하나로 |
| C19 | 반영 | §1-3 · §1-7 — 컨트롤 플레인으로 소비, 드리프트(받은 지 N분 · 경고)를 늘 보임 |
| C25 | 반영 | Constraints |
| C27 | 반영 | §1-1 · §1-4 — 판정 줄 절(R5 칸) |
| C32 | 반영 | Constraints — 상태 계산 재사용 |
| C35 | 반영 | Constraints |
| D21 | 반영 | §3 — 위험에 답함 |
| D22 | 반영 | Goals · §2 — Claude Code 안(상태줄 · 명령 · 작업 목록) |
| D23 | 반영 | §1-1 · §1-4 — 포화 판정 결과를 보임 |
| D24 | 반영 | §1-1 — 생략 경고를 보임 |
| D26 | 반영 | Constraints |
| D33 | 반영 | Constraints — 작업 목록 · 기존 기능 기반, 실험 기능 아님 |
| D40 | 반영 | §1-1 — 얕음 경고를 보임 |
| D41 | 반영 | §1-1 · §1-4 — 상태 계산 맨 위 `orphans`(받드는 에픽 없는 발화)를 경고로 세고 `show` 에 보임 |
| D43 | 반영 | §1-3 — 인터뷰 조사 n/limit 을 상태줄에 |
| OQ4 | 반영 | §1 — 경고 없는 생략이 통제 표면에 |
| OQ6 | 반영 | §2 — 상태줄 · 명령 · 작업 목록 |
| OQ34 | 반영 | §3 — 확인된 세 자리로 닫음(B5) |
| RC80 | 반영 | §3 — 훅 배달지 선례를 보고 훅 알림을 쓰지 않음 |
| K6 | 반영 | §3 |
| K13 | 반영 | §3 |
| S1 | 반영 | Context — 「한 곳에서 볼 수 있다」 |
| S9 | 반영 | §1 — 생략 경고를 통제 표면으로 |
| S11 | 반영 | Context · §1-7 — 드리프트 회피, 컨트롤 플레인 소비 |
| S13 | 반영 | §3 |
| S14 | 반영 | §2 — Claude Code 안 |
| S15 | 반영 | §1-1 — 포화 판정 결과를 컨트롤 플레인에 |
| S17 | 반영 | Constraints |
| S18 | 반영 | Constraints |
| S22 | 반영 | §1-4 — 실행 판정을 보이기로 |
| S30 | 반영 | Constraints |
| S31 | 반영 | Constraints — 실험 기능 제외 |
| S34 | 반영 | Constraints |
| S41 | 반영 | §1-1 — 받드는 발화 경고(승인 때 위치는 R3) |
| S43 | 반영 | §1-3 — 조사 상한 알림 |
| S49 | 반영 | Goals — 범위를 줄이지 않음 |

## Metadata

- 에픽: R6 · 브랜치 `feature/roadmap-control-plane` · 의존 R0(머지됨 `6e55f593`)
- 플러그인: spec-distill minor bump(번호는 머지 직전)
- 기댐(정보): R3 의 경고(`warnings[]` 확장) · R7 의 인터뷰 상태 파일 위치 · R5 의 `rulings[]` — 먼저 머지되지 않은 쪽은 「셀 수 없음」 · 절 생략으로 동작한다.

### Deferred to plan

- 상태줄 명령의 정확한 설치 덩어리(실행 때 설치된 최신 spec-distill 을 찾는 방법 — 실제 설치본에서 잰다)와 시간 측정 숫자.
- brief 가 생긴 뒤의 포화 판정 표시 — 짝 brief 가 생겨 진행 중이 아닌 인터뷰의 포화 판정을 어디에 · 언제까지 보일지(716bc436#r1.2).
- R7 의 상태 파일 이름(`<날짜>-<주제>-interview.state.md`, seed 로 시작한 것 `<날짜>-<주제>-brief-interview.state.md`)에 맞추기와,
  R7 · R5 가 머지되기 전 「셀 수 없음」과 「없음」을 상태줄 · `show` 에서 어떻게 다르게 그리는지(716bc436#r1.4).
- 「설계 · 구현 · 준비」 묶음에 상태 계산의 어떤 단계 이름들이 들어가는지의 매핑표.
- 로드맵이 여럿일 때 상태줄의 모양(첫 로드맵 + `외 <n>`).
