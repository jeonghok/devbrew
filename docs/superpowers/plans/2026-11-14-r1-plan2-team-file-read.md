# 팀 파일 규약 · 계획 2 — 읽기 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 새 형식(`layout: team`) 로드맵의 단계를 과제 폴더의 파일과 git 으로 계산하고, 결과 파일을 대조한 뒤에만 단계가 넘어가게 하며, 대조 · 기록 스크립트와 superpowers 변환기를 새 형식에 맞춘다 — 옛 형식의 출력은 바이트 하나 바꾸지 않는다.

**Architecture:** 결과 파일 · 막힘 파일 · 결정 기록의 글은 `team_files.py` 가 읽고, 결과 대조와 받음 줄 다시 계산은 새 모듈 `job_results.py`, 단계 표 · 알림 · 로드맵 밖 과제는 새 모듈 `team_status.py`, 다른 작업 방식(superpowers)의 꼴 읽기는 새 모듈 `workflow_superpowers.py` 가 맡는다. 셋 모두 읽기만 하고 git 은 `roadmap_status.Git` 을 받아 쓴다. `roadmap_status.py` 에는 형식 갈림 몇 줄만 두고, 머지 판정(PR 캐시 · 머지 커밋)은 옛 형식과 같은 코드를 쓴다. 쓰는 쪽(결과 파일 맞추기 · 결정 기록 줄)은 있는 쓰기 길(`roadmap_write.py` 의 거래 · `conductor_ledger.py` 의 원자 쓰기)에 얹는다.

**Tech Stack:** Python 3.9 문법 · 표준 라이브러리만(레포 스위트가 `python3` 3.9.6 으로 돈다), bash 3.2 호환 셸 테스트(`shared/tests/assert.sh`), git.

**Spec:** `docs/superpowers/specs/2026-11-14-team-file-contract-design.md`

이 계획은 설계 §14 의 셋 가운데 둘째다. 수용 기준은 AC9 · AC10 · AC11 · AC13 · AC14 · AC15 · AC16 · AC17 · AC27 · AC28 · AC29 · AC30 과 AC26 의 계획 2 몫(형식 정본 문서 §5 · §10, 판 올림, CHANGELOG, README, 스크립트 락)이다. AC12 는 계획 1 이 당겨 넣었고 이 계획은 그 멈춤 가운데 「team 형식」 쪽만 실제 계산으로 바꾼다(모르는 값의 멈춤은 그대로). 사용자가 정한 것(결정 기록 B22 · B23)과 설계문서 `## 미룸` 표에서 받는 곳이 R1 인 행 셋을 함께 받는다. 계획 3(규칙과 시작 묶음 — AC19–AC25 · AC31)의 일은 하지 않고 이음매만 끝 절에 적는다.

## Global Constraints

- 브랜치: `feature/team-file-read`(이미 있다 — 계획 1 의 브랜치 끝에서 갈랐다). 커밋은 Conventional Commits, 설명은 한국어(예: `feat(spec-distill): team 형식의 결과 대조`). 구현 커밋마다 트레일러 `Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md`. `git add -- <경로>` 로 고친 파일만 올린다.
- 옛 형식(로드맵 머리말에 `layout` 없음)의 출력은 바이트까지 그대로다 — 단계 계산(글 · `--json`) · 현황(`control_plane.py show` · `show --tasks`) · 번호 대조(글 · `--json`). 새 칸 · 새 줄은 team 형식일 때만 나온다. 있는 테스트의 기대값은 `## 설계에 없던 결정` 의 T 행에 적은 자리만 고친다 — 그 밖의 있는 단언이 빨개지면 고치지 않고 멈춰 보고한다.
- 새 형식을 기본으로 켜지 않는다(R2). `roadmap_write.py create` 는 `--layout` 없이 지금처럼 옛 형식을 만든다.
- 단계 이름(글자 그대로, 이 순서): `design` · `plan` · `implement` · `review`. 결과 파일 이름: `<단계>-<시도>.md` 또는 `<단계>-plan-<n>-<시도>.md`(`design` 은 계획 번호를 받지 않는다). 막힘 파일: `BLOCKED.md`. 이 글자들은 `team_layout.py` 에만 둔다.
- 결정 기록의 종류(글자 그대로, 이 순서): `spec 승인` · `병렬 답` · `계획 검토` · `결과 받음` · `예약 밖 변경` · `넘김 확인` · `결정`. 받음 줄: `- 결과 받음 · <YYYY-MM-DD> · 「<결과 파일 이름> · <커밋> · <대조 첫 줄>」`.
- 결과 파일의 기계가 읽는 줄(줄 머리, 펜스 밖): `Task <n>/<전체>: 끝|막힘 — <커밋>` · `Ruling: …` · `AC<n>: 구현됨|미룸|빠짐 — 근거` · `규칙 반증: <규칙 줄 머리> — <무엇을 봤나>` · `산출물: <경로>` · `끝 — <커밋>`.
- 경로 조각(`jobs/` · `intent/` · `results/` · `RULES.md` · `HANDBOOK.md`)의 글자는 `team_layout.py` 에만 둔다(`tests/test_team_layout.py` 의 `LiteralsLiveInOnePlace` 가 `scripts/*.py` 의 주석 · docstring · 메시지 글자까지 잡는다). `### Task` 글자는 `workflow_superpowers.py` 에만 둔다(Task 4 의 락).
- `Team` 은 `team_layout.team_from_roadmap(roadmaps_dir, 로드맵 경로)` 로만 만든다(생성자를 직접 부르지 않는다 — 생성자는 값을 검증하지 않는다). `roadmaps_dir` 은 해결자(`repo_defaults.resolve`)에서 읽는다.
- 상태 계산이 기대는 모듈(`roadmap_status.py` 가 직접 · 간접으로 import 하는 것)은 읽기만 한다 — 쓰기 호출 · 쓰기 모드 `open` · `shutil` · 네트워크 모듈 · `["git", …]` 꼴 밖의 `subprocess` · `from subprocess import` 를 쓰지 않는다. 새 모듈 셋(`job_results.py` · `team_status.py` · `workflow_superpowers.py`)은 `subprocess` 를 import 하지 않고 git 은 받은 `roadmap_status.Git` 으로만 읽는다. `team_layout.py` 에는 `@dataclass` 를 쓰지 않는다(기계 상태 읽기의 정적 추적이 장식자 호출을 금지 호출로 잡는다 — 판정 R-H).
- 새 스크립트: 파일을 열 때 `encoding="utf-8"`(바이트로 읽을 때는 `"rb"`), 인터프리터 이름 글자(`"python3"`)를 쓰지 않고 `sys.executable`, 모듈 수준 `re.compile` 에 `##` 로 시작하는 제목 패턴을 두지 않는다(제목은 문자열 비교로). 비신뢰 입력의 꼴 검사는 `fullmatch`. 한글이 긴 줄은 인접 문자열로 나눈다.
- 새 셸 테스트: `chmod +x` 뒤 `git ls-files -s <파일>` 이 `100755`. 한글 바로 앞의 변수는 `${v}`. `PYTHONDONTWRITEBYTECODE=1`. 픽스처 글은 있는 테스트와 다르게 쓴다(20줄 중복 락). 여러 새 셸 테스트가 함께 쓰는 팀 레포 만들기는 `tests/fixtures/team_repo.sh` 한 곳에 둔다(스위트가 `fixtures/` 아래를 테스트로 고르지 않는다).
- 스크립트 사본을 만드는 테스트의 복사 목록: `roadmap_status.py` 나 `check_bundle_coverage.py` 에 로컬 import 를 더하면 그 모듈을 `tests/test_roadmap_status.sh` 의 사본 줄 둘 · `tests/test_bundle_coverage.sh` 의 사본 줄 둘에 더한다(T-f). `roadmap_model.py` · `repo_defaults.py` · `control_plane.py` 에는 로컬 import 를 더하지 않는다(그 사본을 만드는 테스트 셋의 목록을 건드리지 않는다).
- 판: 지금 판(계획 1 뒤 `8.15.0`)의 다음 minor — 목표 `8.16.0`. 머지 순서가 바뀌면 리더가 머지 때 다시 매긴다. 판 테스트는 판 글자를 못 박지 않는다(Task 16 — 판정 R-R 의 꼴). CHANGELOG 의 지난 판 항목은 고치지 않는다.
- 전체 스위트는 과제 구현자가 돌리지 않는다. 컨트롤러가 마지막 전체 리뷰의 수정 물결 뒤에 한 번, 공유 잠금 줄로만 돈다(한 번에 35–75분): `python3 "<SD>"/scripts/suite_lock.py run --lock <리더가 준 잠금 경로> --owner <agent 이름> --wait <초> -- bash -c 'bash tools/suite/run-all.sh'`. 잠금을 못 잡으면 잠금 없이 돌리지 않고 주인 · 잡은 시각을 보고한다. 과제마다의 테스트는 그 파일과, 바꾼 파일을 코퍼스로 읽는 락만 돈다.
- 예약 밖 파일은 Q9 의 `scripts/branch_tip.py` 하나뿐이다(Task 6 의 그 걸음은 Q9 가 받아들여진 뒤에만 한다). 지휘 절차서(`references/conducting.md` · `conductor-dispatch.md`) · skill 본문 · 끝맺음 절차(`finishing.md`) · 재분해 절차(`redecompose.md`) · 리뷰어 프로필 · `conductor_state.py` · `dependencies.md` 는 고치지 않는다.
- 리더 세션이 같은 worktree 의 설계문서를 고칠 수 있다 — 설계문서를 되돌리거나 고치지 않는다. 사용자에게 보이는 말은 「리더」다.

## Review Focus

- **결과 파일 본문 안의 기계 줄 꼴 글.** 일꾼이 펜스 안에 `끝 — abc1234` · `AC3: 구현됨 — …` · `Task 9/3: 끝 — …` 를 인용해도 기계 줄로 읽지 않는다(펜스 밖 · 줄 머리만). CRLF 이거나 끝 줄바꿈이 없는 결과 파일은 LF 와 같게 읽고, BOM 이 붙은 파일은 머리 없음으로 거절한다 — 어느 것도 죽지 않는다(Task 3 · Task 5).
- **이름과 머리가 어긋난 결과 파일.** `implement-plan-1-2.md` 인데 머리가 `attempt: 1` 이거나 `stage: plan` 이면 대조가 거절한다 — 이름으로 고른 「가장 새 시도」 와 머리가 말하는 시도가 다르면 옛 시도가 새것으로 세어진다(Task 5).
- **origin 에만 있는 브랜치 · 로컬에만 있는 브랜치.** 리더 기계가 fetch 만 해서 로컬 브랜치가 없는 과제는 origin 끝을 알림 없이 읽고, 한 번도 올리지 않은 로컬 브랜치는 「아직 안 올라옴」 을 낸다 — AC30 의 네 경우 밖의 흔한 둘이다(Task 6).
- **받은 뒤 기본 브랜치를 합친 과제 브랜치.** 받음 줄 뒤에 기본 브랜치를 merge 한 커밋만 있으면 「받은 뒤 바뀜」 이 나오지 않는다. 그 merge 로 들어온 다른 에픽의 변경이 이 과제의 고칠 자리를 지나가도 같다(Task 5 · Task 7).
- **기본 브랜치를 모르는 레포 · 얕은 클론.** origin 이 없거나 `origin/HEAD` 가 없는 레포에서 team 로드맵을 계산하면 블록이 「알 수 없음」(종료 코드 3)이고 죽지 않는다. 대체 대조(Q19)도 기준을 모르면 검사 불가 그대로다(Task 7 · Task 15).

## 파일 구조

모두 `plugins/spec-distill/` 아래다.

| 파일 | 맡는 일 | 과제 |
|---|---|---|
| `scripts/team_layout.py` | 단계 이름 · 결과 파일 이름 · 막힘 파일 · 계획 파일 이름 읽기 · 경로에서 과제 찾기. `STAGE_PENDING` 을 지운다 | 2 · 14 |
| `scripts/team_files.py` | 「한다 … / 안 한다 …」 읽기 한 곳 · INTENT.md 머리 읽기 · 결정 기록 줄 · 받음 줄 · 결과 파일 · 막힘 파일의 글 | 2 · 3 |
| `scripts/workflow_superpowers.py` (새) | superpowers 의 꼴 읽기 — 계획의 task 절 · 구현 원장의 완료 줄과 판정 줄 · 쓸 자리 문장. 읽기만 한다 | 4 |
| `scripts/job_results.py` (새) | 결과 대조 · 받음 줄 다시 계산 · 낡음 판정 · `check` 명령 | 5 |
| `scripts/team_status.py` (새 — Q8) | team 형식의 브랜치 끝 읽기 · 단계 표 · 알림 · 로드맵 밖 과제 | 6–9 |
| `scripts/branch_tip.py` (예약 밖 — Q9) | 읽기 전용 락이 받는 꼴로(동작 불변) | 6 |
| `scripts/roadmap_status.py` | `Git.names` · `Git.touched` · `compute` 의 형식 갈림 · `build` 의 team 몸 · 단계 글자 둘 | 5 · 7 · 8 · 9 |
| `scripts/roadmap_model.py` | `approval_in(lines)` 을 떼어 낸다 · `handoff_rows` 의 근거 글 인자 | 7 · 8 |
| `scripts/control_plane.py` | 진행 숫자 · team 블록의 정보 줄 · 「로드맵 밖 과제」 · 코드 지문 목록 | 10 |
| `scripts/check_bundle_coverage.py` | `--plan` 이 변환기를 거친다 · team 정답 출처 · `## 원문 대조` 표 | 4 · 11 |
| `scripts/spec_review_bundle.py` | `--bundle` 로 INTENT.md 를 받는다 | 12 |
| `references/epic-handoff.md` | team 형식의 넘김 줄 | 12 |
| `scripts/conductor_ledger.py` | `record` · `flush` 의 team 쓸 자리 · `write-sections` 의 알림 · 세지 못한 블록에서 멈춤 | 13 |
| `scripts/roadmap_write.py` · `team_write.py` · `roadmap_render.py` | `job sync` · 머지된 에픽 보호 되돌리기 · 범위만 바뀐 행 · 계획 1 잔여 | 2 · 4 · 14 |
| `scripts/team_check.py` | 출처 커밋 대체 대조(B22) · 이름 읽기를 `team_layout` 으로 | 2 · 15 |
| `templates/team/role-worker.md` · `role-writer.md` | 할 일 한 줄(AC28) | 8 |
| `references/team-files.md` · `README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json` | §5 · §10 · 고칠 문장 · Principles · 판 | 16 |
| `tests/fixtures/team_repo.sh` (새) | 새 셸 테스트가 함께 쓰는 팀 레포 만들기 | 4 |
| `tests/test_team_results.py` · `test_workflow_superpowers.py` (새) | 글 읽기 단위 테스트 | 3 · 4 |
| `tests/test_team_sync.sh` · `test_job_results.sh` · `test_team_status.sh` · `test_team_tasks.sh` · `test_team_coverage.sh` · `test_team_review_entry.sh` (새) | 임시 레포 끝에서 끝 | 4 · 5 · 6–8 · 9 · 11 · 12 |
| `tests/test_team_layout.py` · `test_team_files.py` · `test_team_docs.py` · `test_control_plane.py` · `test_conductor_ledger.py` · `test_roadmap_model.py` · `test_epic_handoff.sh` | 있는 파일에 테스트 더하기 | 2 · 7 · 10 · 12 · 13 · 16 |
| `tests/test_team_status_stub.sh` · `test_team_write.sh` · `test_roadmap_status.sh` · `test_bundle_coverage.sh` · `test_workspace_invariance.sh` | 있는 단언 · 목록을 고친다(T 행) | 4 · 6 · 7 · 14 · 15 |

테스트 코드의 별칭 — `L` = `team_layout` · `F` = `team_files` · `M` = `roadmap_model` · `WS` = `workflow_superpowers` · `JR` = `job_results` · `TS` = `team_status` · `cbc` = `check_bundle_coverage` · `cp` = `control_plane`. `SCRIPTS` · `PLUGIN` · `REPO` 는 그 테스트 파일에서 `Path(__file__)` 로 얻은 스크립트 폴더 · 플러그인 폴더 · 레포 루트다. 셸 테스트의 `S` 는 스크립트 폴더, `SD` 는 플러그인 폴더, `RW` · `RS` · `JRC` 는 `roadmap_write.py` · `roadmap_status.py` · `job_results.py`, `W` 는 임시 레포, `T` 는 임시 폴더, `g` 는 그 레포의 git, `RD` 는 해결자가 낸 `roadmaps_dir`, `js <json> <식>` 은 보고서 `r` 에 파이썬 식을 돌리는 도우미다(`tests/test_team_status_stub.sh` 머리와 같은 꼴).

## AC 대응

| AC | 과제 | 재는 것 |
|---|---|---|
| AC9 | 7 · 8 | 단계 표(단계마다 근거 하나만 다른 픽스처) · `create --layout team` 직후 종료 코드 0 · 결정 기록 · 계획 파일만으로는 「구현 중」 이 아님 · 과제 폴더 안 산출물의 `## 미룸` · `## 번호 대조` |
| AC10 | 3 · 5 · 7 | 「결과 있음 · 받음 없음」 · 대조의 거절 넷 · 받음 줄 다시 계산 · 「받은 뒤 바뀜」 · 합쳐 들어온 변경은 세지 않음 |
| AC11 | 8 | 「예약 밖 변경」 과 파일 이름 · 종료 코드 그대로 · 「경로 예약 위반」 그대로 |
| AC13 | 7 · 10 · 11 · 14 · 16 | 옛 형식 출력의 변경 전후 다이제스트 · 있는 테스트 그대로(T 행 밖) |
| AC14 | 9 · 10 | 따로 된 목록 · 현황의 「로드맵 밖 과제」 · 브랜치 끝에만 있는 과제 · 머리 `branch` 가 다른 사본 |
| AC15 | 11 | 번호 파일의 `ids` 가 정답 · 결과 파일의 `AC<n>:` 줄 · `## 원문 대조` 표의 알림과 얕은 답 · 종료 코드 불변 |
| AC16 | 12 · 13 | INTENT.md 를 `--bundle` 로 · 알림 한 줄 · `record` · `flush` 의 쓸 자리 · `write-sections` 의 알림 · 옛 형식 그대로 |
| AC17 | 4 · 12 | 쓸 자리 문장 · 원장의 `Ruling:` 줄 옮기기 · `--plan` 이 변환기를 거친다 · `### Task` 글자가 변환기 밖에 없다 · team 넘김 줄의 지시 넷 |
| AC26 | 16 | 형식 정본 문서 §5 · §10 · README · CHANGELOG · 판 · 스크립트 락 |
| AC27 | 3 · 4 · 7 · 10 | 진행 칸 · 현황과 작업 목록의 `<n>/<전체>` · 「진행 줄 없음」 · 깨진 숫자 · 두 번 돌려도 줄이 한 번 |
| AC28 | 8 | INTENT.md 와 블록의 어긋남 알림 · 틀과 형식 정본 문서의 「옮겨 싣지 말고 커밋과 경로로 가리킨다」 |
| AC29 | 2 · 3 · 7 | 막힘 알림과 단계 · 시도 · 결과 파일로 세지 않음 · 지우면 사라짐 |
| AC30 | 6 | 끝 고르기 네 경우와 둘 더 · `branch_tip.tip()` 을 부른다 |

## 설계에 없던 결정

설계문서 `### Deferred to plan` 의 1 · 4 · 5 · 11 · 12 · 15 · 16 번(이 계획 몫)과, 사용자가 이 계획에 맡긴 것(B22 의 세부), 계획을 쓰며 설계가 비워 둔 것을 여기서 정했다. 리더 세션이 사용자에게 묻는다 — 답이 바뀌면 해당 과제만 고친다. **★** 는 승인된 설계의 글자(AC · 본문 · 경로 예약)와 달라지는 자리다.

| # | 결정 | 고른 이유 | 다른 길 |
|---|---|---|---|
| Q1 (1번) | 끊겼다 이어 가는 일꾼(압축 뒤 · 같은 일꾼을 다시 깨움)은 「끝」 줄이 없는 가장 새 시도 파일을 잇는다. 「끝」 줄이 있는 시도 뒤의 재작업과 반려 뒤 다시 보냄은 새 시도 번호다. 진행 숫자와 받음 판정은 그 단계 · 그 계획의 가장 큰 시도 번호 파일 하나만 읽는다. 앞 시도 · 검수 결과를 「읽을 것」 에 싣는 일은 계획 3 이다 | 시도 하나가 파일 하나라는 설계 §5 를 지키면서 다시 시작할 때마다 번호가 늘지 않는다 | 다시 시작할 때마다 새 시도 번호 |
| Q2 (4번) | 단순 작업 과제를 찾으려고 훑는 것은 기본 브랜치에 들어가지 않은 로컬 · origin 브랜치 끝이다(지금 `Git.unmerged_tips` 가 내는 것 — 로드맵 사본을 훑는 범위와 같다). 수의 상한은 두지 않는다. 찾은 과제 폴더는 머리 `branch` 가 가리키는 브랜치의 끝에서 다시 읽어, 그 끝에 같은 폴더가 있고 머리 `branch` 가 그 이름일 때만 센다. 이름이 맞는 브랜치가 없을 때만 알리고 다른 브랜치의 사본은 조용히 건너뛴다 | 있는 훑기와 범위가 같아 느려지는 자리가 하나 더 생기지 않는다. 머리가 가리키는 브랜치에서 다시 읽으면 사본이 몇 개든 과제는 한 번 세어진다 | 과제 폴더를 가진 모든 브랜치를 이름과 견준다 · 브랜치 수 상한을 둔다 |
| Q3 (5번) | 로컬에만 있고 한 번도 올리지 않은 브랜치는 「아직 안 올라옴」 을 낸다. `branch_tip.tip()` 의 반환은 바꾸지 않고, 부르는 쪽(`team_status.read_tip`)이 두 ref 를 읽어 알림 글을 만든다 | 스위트 대조와 통합 리뷰 묶음이 같은 함수의 지금 반환에 기댄다 | `tip()` 이 로컬뿐일 때도 알릴 줄을 내게 고친다 |
| Q4 (11번) | 계획 n 의 수용 기준 범위는 `plan-<n>.md` 의 task 절에 나오는 AC 번호 가운데 설계문서에 있는 것이다(`--plan` 대조가 읽는 것과 같은 글). 계획 파일이 없으면 설계문서의 AC 전부다. 결과 대조는 범위의 AC 마다 `AC<n>:` 줄이 하나 있고 설계문서에 없는 AC 줄이 없을 때 통과한다. 「미룸」 · 「빠짐」 줄은 거절 사유가 아니고 대조 첫 줄에 수로 실린다(미룸 표 대조는 지금처럼 `--impl` 이 경고로 낸다) | 범위를 따로 적는 자리를 만들지 않는다 — 같은 내용을 두 번 짓지 않는다 | 계획 머리에 `acs:` 줄을 새로 둔다 · 「빠짐」 이 하나라도 있으면 거절한다 |
| Q5 (12번) | 과제의 흐름은 둘로 가른다 — 로드맵 블록에 `산출물:` 칸이 있거나 `kind: task` 면 설계 없는 흐름(준비 → 진행 중 → 결과 받음), 그 밖의 에픽은 설계 흐름이다. 설계 파일이 있고 없음으로 가르지 않는다 | 설계 파일이 아직 없는 에픽은 「설계 중」 이어야 한다 | `design.md` 가 없으면 설계 없는 흐름으로 본다 |
| Q6 (15번) | 받음 줄이 적는 커밋은 결과 파일 머리의 `head` 이고, `head` 는 「끝」 줄의 커밋과 같아야 한다(다르면 대조가 거절한다). 「받은 뒤 바뀜」 은 `head` 뒤에 과제 브랜치가 더한 커밋(merge 커밋과 기본 브랜치에서 닿는 커밋은 뺀다)이 그 과제의 고칠 자리 · `design.md` · `plan-<n>.md` · 블록의 산출물을 바꿨는지로 잰다. 자기 과제 폴더의 다른 파일(결과 파일 · INTENT.md)은 세지 않는다. 설계 없는 과제도 같은 규칙으로 낡는다. merge 커밋 안에서 손으로 고친 것은 보지 못한다(형식 정본 문서 §10 에 한계로 적는다) | 커밋 하나가 「무엇을 받았나」 와 「그 뒤 바뀌었나」 의 기준을 함께 맡는다 | 받음 줄에 리더가 대조한 때의 브랜치 끝을 적는다 · 설계 없는 과제는 낡음을 재지 않는다 |
| Q7 (16번) | 단계 계산이 「막힘」 으로 알리는 것은 `BLOCKED.md` 뿐이다. `Task <n>/<전체>: 막힘` 줄은 진행 숫자에서 끝난 수를 n−1 로 세는 데만 쓴다 | 설계 §10 이 「단계 계산은 뒤의 것만 읽는다」 고 적었다 | 막힘 줄도 알림으로 낸다 |
| Q8 **★** | 새 모듈 `scripts/team_status.py` 를 둔다(설계의 새 파일 목록과 R1 경로 예약에 없다 — 예약에 더해야 한다). team 형식의 브랜치 끝 읽기 · 단계 표 · 알림 · 로드맵 밖 과제가 여기 살고 `roadmap_status.py` 에는 갈림 몇 줄만 둔다 | `roadmap_status.py` 가 이미 1300줄이고 옛 형식의 몸과 섞이면 AC13 을 눈으로 확인하기 어렵다 | `roadmap_status.py` 안에 넣는다(예약 변경 없음 · 300줄쯤 는다) |
| Q9 **★** | 예약 밖 파일 `scripts/branch_tip.py`(아무 에픽도 예약하지 않았다)를 읽기 전용 락이 받는 꼴로 고친다 — `shutil` 로 git 을 찾는 줄을 빼고 `["git", …]` 꼴로 부르며 `GIT_ALLOWED = frozenset({"rev-parse", "merge-base"})` 를 둔다. 동작은 같다. 그 파일을 정적 락의 닫힌 목록에 더한다. Task 6 의 그 걸음은 이 결정이 받아들여진 뒤에만 한다 | AC30 이 「끝 고르기는 `branch_tip.py` 의 `tip()` 을 부른다」 고 못 박았는데, 상태 계산의 읽기 전용 락(`tests/test_roadmap_status.sh` 5절)은 지금 꼴의 그 파일을 import 하면 빨개진다(`shutil` · git 이 아닌 `subprocess` · `GIT_ALLOWED` 없음). 락의 규칙을 넓히는 것은 락을 약하게 한다 | 단계 계산이 같은 네 갈래를 `Git.commit` · `Git.is_ancestor` 로 직접 가른다(둘째 구현 — AC30 의 「둘째 구현이 없다」 를 고쳐야 한다) |
| Q10 | 둘이 갈라진 과제 — 에픽 블록은 단계 「알 수 없음」 · 사유 「갈라짐 — …」 이고 다른 블록은 그대로 계산한다(종료 코드는 지금 규칙대로 「알 수 없음」 블록이 있으면 3). 단순 작업은 목록에 싣지 않고 「갈라짐」 알림 줄만 낸다(종료 코드 불변) | 셀 수 없는 것을 0 으로 내지 않는 지금 규칙을 따른다. 단순 작업은 블록이 아니라 종료 코드에 드는 자리가 없다 | 갈라진 에픽도 알림만 내고 종료 코드를 그대로 둔다 |
| Q11 | 「결과 있음 · 받음 없음」 은 `implement` 결과 파일이 있고 그 파일을 가리키는 받음 줄이 없을 때 늘 내되, 「끝」 줄이 없으면 「도는 중」, 있으면 「대조를 기다린다」 를 붙인다 | AC10 의 글자를 지키면서 리더가 지금 대조할 것과 아직 도는 것을 가른다 | 「끝」 줄이 있을 때만 낸다 |
| Q12 **★** | 설계 없는 흐름의 단계 글자 「진행 중」 · 「결과 받음」 을 더한다(작업 상태는 둘 다 진행 중, 현황의 묶음은 「구현」). 단순 작업 과제의 단계는 진행 중 · 결과 받음 · 머지됨 셋이다 — 과제 폴더가 기본 브랜치에 있으면 「머지됨」 이고 「준비」 는 없다(과제 폴더가 그 브랜치의 첫 커밋이다). 단순 작업의 「PR」 단계는 싣지 않는다 — PR 캐시가 작업 브랜치를 모른다(§미룸 후보) | 설계 §10 의 글자를 그대로 쓴다. PR 캐시를 채우는 길은 블록의 브랜치만 돈다 | 「구현 중」 · 「구현 끝」 을 그대로 쓴다 · `pr-refresh` 가 작업 브랜치도 채우게 한다 |
| Q13 | 「예약 밖 변경」 은 그 브랜치가 바꾼 파일 가운데 공유 파일 · 자기 고칠 자리 · 자기 과제 폴더 · 다른 과제가 예약한 파일(그것은 「경로 예약 위반」 이다)을 뺀 나머지다. 로드맵 파일과 팀 폴더의 다른 파일도 든다. 결정 기록에 `예약 밖 변경` 줄이 있어도 알림은 그대로 나온다 | 한 파일에 알림 둘이 나오지 않는다. 알림을 끄는 장치를 만들지 않는다 | 결정 기록의 줄이 그 파일의 알림을 끈다 |
| Q14 | 계산 결과의 새 칸은 team 로드맵의 보고에만 있다 — 맨 위 `layout` · `jobs` · `job_notes`, 블록의 `progress` · `job`. 옛 형식의 `--json` 은 칸 하나 늘지 않는다. 현황(`show`)은 team 로드맵에서만 블록의 「정보:」 줄을 보인다(막힘 · 받음 없음 같은 알림이 지도에 보여야 한다) | AC13. 계획 1 은 `settings` 에 칸을 더했는데 이번에는 더하지 않는 쪽이 대조가 쉽다 | 옛 형식에도 빈 칸을 싣는다 |
| Q15 | 결과 파일을 맞추는 명령은 `roadmap_write.py job sync` 다 — 파일이 없으면 이름과 인자로 머리를 만들고, 원장과 계획 파일을 주면 변환기가 낸 `Task` · `Ruling:` 줄 가운데 없는 것만 덧붙이며, `--end <커밋>` 이면 머리의 `head` 를 고치고 「끝」 줄을 단다. 「끝」 줄이 있는 파일은 고치지 않는다. 변환기 모듈(`workflow_superpowers.py`)은 글만 다루고 쓰지 않는다 | 번호 대조가 변환기를 import 하므로 변환기는 읽기 전용 락 안에 있어야 한다. 쓰기는 있는 거래 코드에 얹는다 | 변환기가 줄만 화면에 내고 일꾼이 `>>` 로 붙인다 |
| Q16 **★** | 결정 기록에 쓰는 줄은 종류 일곱 가운데 하나로 시작해야 한다(아니면 `record` 가 거절한다). `넘김 확인` 줄은 지금 꼴(`- 넘김 확인 · <준 에픽> · <8자> · <근거>`) 그대로 받는다 — 날짜 칸이 없다. 나머지 여섯은 둘째 칸이 날짜다. 「」 로 감싸는 것은 `결과 받음`(스크립트가 읽는다)에만 강제한다 | 설계 §2 의 두 문장(「줄 꼴은 `- <종류> · <날짜> · 「…」`」 · 「지금 지휘 기록이 받던 줄이 같은 꼴로 여기 온다」)이 `넘김 확인` 에서 어긋난다. 넘김 상태 계산이 지금 꼴을 읽는다 | `넘김 확인` 도 날짜 칸을 두고 넘김 읽기를 고친다 |
| Q17 | `record` · `flush` · `write-sections` 는 `--spec` 으로 받은 경로가 `layout: team` 로드맵의 과제 폴더 안이면(그 폴더의 어느 파일이든) team 으로 본다 — 줄은 그 과제의 INTENT.md 에 간다. 대기 줄의 「절」 칸 값은 지금 글자(「지휘 기록」) 그대로다 | 부르는 쪽(지휘 절차서 — R2)의 명령 꼴을 바꾸지 않는다. 대기 줄의 자리와 꼴은 R3 다 | `--job` 인자를 새로 둔다 |
| Q18 | `pr-handoffs` · `pr-refresh` 는 단계 계산이 세지 못한 블록(단계 「알 수 없음」 이고 브랜치 칸에 글이 있는데 브랜치 목록이 빈 것)을 만나면 형식과 무관하게 종료 코드 3 으로 사유를 낸다. `pr-refresh` 는 셀 수 있는 블록은 채운 뒤 3 이다 | 「브랜치 없음」 과 「브랜치를 읽지 못함」 은 다른 사실이다. 형식이 깨진 옛 로드맵도 같은 조용한 오답을 냈다 | team 형식일 때만 고친다 |
| Q19 (B22) | 출처 커밋을 읽지 못한 구간은 덧붙이기 검사와 같은 기준(`--base <ref>`, 없으면 기본 브랜치 `origin/HEAD`)의 같은 파일 · 같은 줄과 견준다. 바이트가 같으면 통과이고 구간마다 알림 줄 하나를 낸다(「출처 커밋 <12자> 를 읽지 못해 기준 <ref> 의 같은 줄과 견줬다 — 같다」). 다르거나, 기준에 그 파일이 없거나, 기준을 모르면 검사 불가(3) 그대로이고 무엇과 견줬는지를 적는다 | 기준이 하나면 `check` 의 두 검사가 같은 판을 본다. 기준의 지금 판과 다르다는 것은 사본이 틀렸다는 증거가 아니다(출처가 그 뒤 고쳐졌을 수 있다) — 어긋남(1)으로 내면 없는 잘못을 짚는다 | 어긋나면 1 로 낸다 · 기본 브랜치 이력의 판들을 모두 훑어 같은 판을 찾는다 |
| Q20 | team 형식의 번호 대조 — 번호 파일을 정답 출처로 받으면 로드맵 경로는 옆 INTENT.md 머리의 `roadmap` 에서 읽는다. `## 원문 대조` 표의 알림과 얕은 답, 결과의 `notices` 칸은 정답 출처가 번호 파일일 때만 낸다. 다른 과제가 그 번호를 받드는지는 그 과제 폴더의 `design.md` 로 본다 | 옛 형식의 `--json` 을 바꾸지 않는다 | 모든 설계문서에 `## 원문 대조` 를 본다 |
| Q21 | `spec_review_bundle.py entry` 는 머리가 `type: job` 인 파일을 `--bundle` 로 받는다. 진입 번호 대조는 같은 폴더의 번호 파일로 하고, 번호 파일이 없는 과제(단순 작업)는 건너뛴다고 한 줄 낸다. `neighbors` 는 `job` · `roadmap` 머리로 같은 일을 한다 | 설계 §12 가 정답 출처를 INTENT.md 로 못 박았고 번호는 옆 파일에 있다 | `--sources` 인자를 새로 둔다 |
| Q22 | 계획 1 PR 본문 「잔여」 열하나를 이 계획이 모두 받는다(Task 2 · 7 · 8 · 14). 형식 정본 문서의 글 셋 가운데 「이 판 / 다음 판」 과 「(R3)」 는 이 계획이 고치고(Task 16), 「계획 3 이 §15 로 적는다」 넷은 §15 를 쓰는 계획 3 에 넘긴다 | 열하나 모두 이 계획이 고치는 파일 안에 있다 | 생성기 쪽 여섯을 R2 로 미룬다 |
| Q23 | `git ls-tree` 를 상태 계산의 허용 명령에 더한다(`Git.names` — 폴더의 이름 목록). 정적 락의 읽기 명령 집합에 이미 있는 명령이다 | 결과 폴더와 과제 폴더의 이름을 나열할 길이 지금 허용 명령에 없다 | `git grep -l` 로 머리 글자를 찾아 나열한다 |
| Q24 | 코드 지문 목록(`control_plane.CODE_STAMP_FILES`)은 손으로 고르지 않고 테스트가 도출한다 — `roadmap_status.py` 가 직접 · 간접으로 import 하는 로컬 모듈 가운데 기계 상태 쪽(`state_path.py` · `ledger_marker.py`)을 뺀 전부가 목록에 있어야 한다. 그래서 `gh_repo.py` 도 더해진다 | 계획 1 이 `team_layout.py` 를 빠뜨렸다가 리뷰에서 잡혔다. `state_path.py` 가 목록에 없다는 것은 있는 테스트가 못 박고 있다 | `team_check.py` · `team_files.py` 둘만 더한다 |
| T-a **★** | `tests/test_team_status_stub.sh` — team 로드맵이 「검사 불가(3) · 이 판은 계산하지 않는다」 라는 단언 여섯(종료 코드 둘 · 사유 · 블록 단계 · 블록 사유 · 번호가 빠진 때의 종료 코드)을 실제 단계 기대값으로 바꾼다(계획 1 의 P5 를 되돌린다). 모르는 `layout` 값과 옛 형식의 단언은 그대로다. 글자로 적힌 `docs/superpowers/roadmaps/t1` 은 해결자에서 읽게 고친다(잔여) | AC9 가 그 멈춤을 계산으로 바꾼다 | — |
| T-b **★** | `tests/test_team_write.sh` 의 「team update: 머지 여부 알림」 단언 둘을 뒤집는다(알림이 없다 · 머지된 에픽을 바꾸면 거절) | 계획 1 의 P6 를 되돌린다(계획 1 이 「계획 2 가 뒤집는다」 고 적어 둔 자리) | — |
| T-c **★** | `tests/test_team_write.sh` 의 「출처 커밋이 없다」 묶음(새 clone `sq2`) — `check` 3 → 0 과 알림 줄, `update` · `create` 1 → 0, `original` · `job new` 의 검사 불가 줄 없음으로 바꾼다. 검사 불가가 남는 갈래는 새 픽스처 셋으로 잰다(Task 15) | B22 가 그 경우를 통과로 바꿨다 | — |
| T-d **★** | `tests/test_roadmap_status.sh` 정적 락의 파일 목록에 `team_status.py` · `job_results.py` · `workflow_superpowers.py` · `branch_tip.py` 를 더하고 `CHECKED 10` → `CHECKED 14` 와 그 라벨의 수 낱말을 고친다. 규칙과 허용 목록은 그대로다 | 판정 R-I 와 같다 — 목록이 길어지면 검사받는 파일이 는다 | — |
| T-e **★** | `tests/test_team_docs.py` `test_sections_of_this_plan` 의 제목 다섯을 일곱으로(§5 · §10) | AC26 의 계획 2 몫 | — |
| T-f | 단언은 그대로 두고 목록만 고치는 자리 — `tests/test_roadmap_status.sh` 의 변이 사본 줄 둘에 `team_status.py` · `job_results.py` · `team_files.py` · `branch_tip.py` · `workflow_superpowers.py`, `tests/test_bundle_coverage.sh` 의 사본 줄 둘에 `workflow_superpowers.py` · `team_files.py` | 사본 폴더에서 import 가 풀려야 한다 | — |
| T-g | `tests/test_workspace_invariance.sh` 5행 머리 주석의 「열 키」 를 「열두 키」 로(주석뿐 — 잔여) | 계획 1 이 단언만 고치고 주석을 남겼다 | — |

**AC13 과 T 행.** AC13 의 「있는 테스트가 고치지 않은 채 통과한다」 는 옛 형식 로드맵의 출력에 대한 문장이다. T-a · T-b · T-c 는 계획 1 이 새 형식의 임시 동작을 못 박은 단언이고, T-d · T-e 는 목록과 절 수다 — 옛 형식의 단계 계산 · 현황 · 번호 대조의 기대값은 하나도 고치지 않는다. 마지막 전체 리뷰가 이 분류를 다시 확인한다.

## 코드 분기 × 픽스처

계획 1 의 마지막 리뷰가 남긴 말 — 「픽스처가 「출처 커밋은 늘 닿는다 · 범위는 늘 한 조각」 으로 쓰여 변이 11행이 모두 빨개져도 Important 갈래는 드러나지 않았다. 계획 2 · 3 은 변이 표를 쓰기 전에 새 함수의 분기를 픽스처와 대조하라.」 아래 표가 그 대조다. 구현자는 과제를 끝낼 때 자기 함수의 분기가 이 표에 다 있는지 보고, 없는 분기를 만들었으면 픽스처를 더한 뒤 표 끝에 줄을 덧붙인다. Task 16 의 변이 표는 이 표의 「픽스처」 칸이 모두 채워진 뒤에 흔든다.

| 함수 | 분기 | 픽스처(테스트 이름 · 라벨의 머리) |
|---|---|---|
| `team_layout.parse_result_name` | 계획 번호 있음 · 없음 · `plan` 단계에 계획 번호 · 0 으로 시작하는 수 · `BLOCKED.md` · `.gitkeep` | `test_team_layout.py` `ResultNames` |
| `team_files.parse_result` | 머리 없음 · 닫히지 않음 · 키 빠짐 · 단계 밖 값 · 기계 줄 여섯 가지 · 펜스 안의 기계 줄 꼴 · 「끝」 줄 둘 · 「끝」 뒤의 기계 줄 · CRLF · BOM · 끝 줄바꿈 없음 | `test_team_results.py` `Parse` |
| `team_files.progress_of` | `Task` 줄 없음 · 끝 · 막힘 · n > 전체 · n < 1 · 전체가 줄마다 다름 | `test_team_results.py` `Progress` |
| `team_files.append_decision` | 빈 칸 · 줄이 있는 칸 · 같은 줄 다시 · 종류 밖 · 날짜 없음 · `넘김 확인` · 줄 나눔 글자 · 받은 말 안의 `## 결정 기록` 꼴 줄 | `test_team_results.py` `Decisions` |
| `team_files.received` | 꼴이 맞는 줄 · 「」 없음 · 커밋 꼴 아님 · 받음 줄 둘(뒤의 것이 이긴다) | `test_team_results.py` `Received` |
| `workflow_superpowers.ledger_lines` | 완료 줄(커밋 있음 · 「커밋 없음」) · 완료가 아닌 Task 줄 · `Ruling:` 줄(불릿 · 맨 줄) · 같은 판정 두 번 · 같은 번호의 완료 줄 두 번 | `test_workflow_superpowers.py` `Ledger` |
| `team_write.cmd_job_sync` | 파일 없음(머리 값 있음 · 없음) · 있음 · 「끝」 줄 있음 · 원장만 · 계획 파일만 · `--end` · 두 번 돌림 · 이름과 머리 어긋남 | `test_team_sync.sh` |
| `job_results.check_result` | 설계 흐름(AC 줄) · 설계 없음(산출물 줄) · 머리 없음 · 「끝」 없음 · `head` ≠ 「끝」 · `head` 가 브랜치에 없음 · `bundle_at` · `job_at` 이 없는 커밋 · 더 새 시도 · 범위 AC 빠짐 · 설계에 없는 AC · 산출물 줄 없음 · 산출물 경로가 `head` 에 없음 · 이름과 머리 어긋남 · 계획 파일 없음(범위 = 전부) | `test_job_results.sh` 「대조:」 |
| `job_results.receipt` | 받음 줄 없음 · 통과 · 대조 불통 · 받음 커밋 ≠ `head` · 더 새 시도 · `head` 뒤 고칠 자리 변경 · `design.md` 변경 · 계획 파일 변경 · 결과 파일 · INTENT.md 만 변경 · 기본 브랜치 merge 뿐 | `test_team_status.sh` 「받음:」 |
| `team_status.read_tip` | 같음 · 로컬 앞섬 · origin 앞섬 · 갈라짐 · 로컬뿐 · origin 뿐 · 둘 다 없음 | `test_team_status.sh` 「끝:」 |
| `team_status.Reader.progress` | 설계 흐름 다섯 단계(설계 중 둘 · 계획 둘 · 구현 중 · 구현 끝) · 설계 없는 흐름 둘 · INTENT.md 못 읽음 · 결정 기록 꼴 깨짐 · 둘째 브랜치(계획 2) | `test_team_status.sh` 「단계:」 |
| `team_status.Reader.notices` | 막힘 있음 · 깨진 막힘 파일 · 받음 없음(도는 중 · 끝남) · 어긋남(목표 · 하지 않을 것) · 예약 밖 변경(없음 · 있음 · 다른 과제 예약 · 공유 파일 · 자기 과제 폴더) | `test_team_status.sh` 「알림:」 |
| `team_status.task_jobs` | 기본 브랜치에 있음 · 브랜치 끝에만 · 머리 `branch` 가 다른 사본 · 이름이 맞는 브랜치 없음 · 갈라진 브랜치 · 같은 과제 이름 두 브랜치 · 받음 있음 | `test_team_tasks.sh` |
| `check_bundle_coverage.check`(team) | 번호 파일 정답 · `## 원문 대조` 없음 · 「바꿈」 에 근거 없음 · 「바꿈」 에 근거 있음 · 「그대로」 · 표 깨짐 · 다른 과제의 `design.md` 가 기각 · 옆 INTENT.md 없음(로드맵 모름) · 옛 묶음 입력 | `test_team_coverage.sh` |
| `team_check.check_tree` 8번 | 출처 커밋 읽힘 · 못 읽고 기준과 같음 · 못 읽고 기준과 다름 · 기준에 파일 없음 · 기준 모름 · `--base` 로 준 기준 | `test_team_write.sh` 「대체 대조:」 |
| `conductor_ledger` 의 team 갈림 | `record`(과제 폴더 안 · 밖 · 모르는 `layout`) · `flush`(옮김 · 이미 있음) · `write-sections` · `pr-handoffs` 의 세지 못한 블록 | `test_conductor_ledger.py` `TeamRecords` · `UncountedBlock` |

## 계획 3 에 넘기는 이음매

- `team_layout` — `STAGES` · `PLANNED_STAGES` · `BLOCKED_FILE` · `result_name` · `parse_result_name` · `plan_name` · `plan_number` · `job_of_path` · `Team.jobs` · `Team.result` · `Team.blocked`. 단계의 기본 역할(§9)과 「리더가 쓰는 파일을 읽을 ref」 함수(§15 · AC31)는 여기 없다 — 계획 3 이 더한다. `STAGE_PENDING` 은 없어졌다.
- `team_files` — `parse_result`(머리의 `bundle_at` · `job_at` 포함) · `progress_of` · `parse_blocked` · `decision_lines` · `append_decision` · `received` · `received_line` · `intent_meta` · `scope_line`. 「묶음 낡음」(AC23)은 `parse_result(…).bundle_at` 을 읽으면 된다.
- `job_results.result_names(git, tip, team, job)` · `newest(names, stage, plan)` — 시작 묶음의 「쓸 것」 시도 번호(AC24)가 이 둘을 부른다. 결과 대조는 `bundle_at` · `job_at` 이 실재하는 커밋인지를 이미 본다(AC24 의 그 절 — 계획 3 은 테스트 한 줄로 못 박으면 된다).
- `team_status.read_tip(git, branch)` — 과제 브랜치 끝과 알림. 시작 묶음이 과제 폴더를 읽을 커밋(`job_at`)을 이 함수로 고른다. `team_status.Reader.notices` 가 블록의 `notes` 에 알림을 더하는 한 곳이다 — 「묶음 낡음」 도 여기에 더한다.
- `workflow_superpowers.place_sentence(path, stage)` — 시작 묶음이 `design` · `plan` 단계에 싣는 「쓸 자리」 문장(AC21). `roadmap_write.py job sync` 의 명령 줄을 시작 묶음이 일꾼에게 실어 주면 일꾼이 인자를 지어내지 않는다(계획 3 이 정한다).
- 현황 — `control_plane.py show` 는 team 로드맵에서 블록의 `notes` 를 「정보:」 줄로 보인다. 계획 3 의 알림이 `notes` 에 있으면 그대로 보인다.
- 형식 정본 문서 — §5 · §10 을 이 계획이 썼다. 「계획 3 이 §15 로 적는다」 넷(§1 의 표 셋 · §2 의 결정 기록 항목)은 계획 3 이 §15 를 쓰며 그 절을 가리키는 글로 바꾼다. §6 의 「지휘 절차 개편(R2)」 둘은 그대로 뒀다.
- 경로 예약에 더할 새 파일: `scripts/team_status.py`(Q8). 예약 밖으로 고치는 파일: `scripts/branch_tip.py`(Q9).
- 리더가 설계문서 `## 미룸` 표에 올릴 후보(이 계획이 하지 않는 것) — ① 단순 작업 과제의 「PR」 단계와 PR 캐시에 작업 브랜치 채우기(Q12) ② 출처 파일이 기본 브랜치에서 그 뒤 고쳐져 대체 대조도 어긋나는 팀 폴더를 푸는 길(Q19) ③ `conductor_state.ledger_rulings` 를 변환기로 모으기(원장의 `Ruling:` 꼴을 아는 곳이 둘이다 — 그 파일은 R3 예약) ④ `team_check.py` 의 덧붙이기 검사가 기준 판을 읽지 못한 것(없음이 아닌 실패)을 조용히 건너뛰는 것(계획 1 마지막 리뷰 Minor 2 — 잔여 목록에 없다) ⑤ `conductor_ledger.py audit` · `review-pack` 의 team 형식(판정을 결과 파일에서 읽기 — 지휘 절차와 함께 R2) ⑥ merge 커밋 안에서 손으로 고친 고칠 자리는 「받은 뒤 바뀜」 이 보지 못한다(Q6).

---

### Task 1: 다시 확인 — 이 계획이 기대는 자리가 지금도 그런가

**Files:** 고치지 않는다.

**Interfaces:**
- Produces: 「달라진 것 없음」 또는 달라진 자리 목록, 그리고 시작 커밋 `BASE`(Task 16 의 옛 형식 대조가 쓴다). 달라졌으면 Task 2 로 가지 않고 멈춰 보고한다.

- [ ] **Step 1: 계획 1 의 브랜치가 그 뒤 움직였는지 본다**

Run: `git fetch origin` 뒤 `git log --oneline d00d99f4..origin/feature/team-file-contract -- plugins/spec-distill` 와 `git merge-base --is-ancestor d00d99f4 HEAD; echo $?`
Expected: 첫 명령은 0줄(계획 1 의 PR 이 이 계획을 쓴 뒤 고쳐지지 않았다), 둘째는 `0`. 줄이 있으면 그 커밋들의 diff 를 읽어 아래 Step 2 의 표와 견주고, 표의 자리가 바뀌었으면 멈춰 보고한다(합치는 것은 리더가 정한다). `git rev-parse HEAD` 를 `BASE` 로 원장에 적는다.

- [ ] **Step 2: 이 계획이 기대는 줄을 확인한다**

아래를 `grep -n` 으로 본다. 하나라도 다르면 멈춰 보고한다.

| 자리 | 있어야 하는 것 |
|---|---|
| `scripts/team_layout.py` | `class Team(NamedTuple)` · `def team_from_roadmap(roadmaps_dir: str, roadmap_rel: str) -> Team` · `STAGE_PENDING = ` · `RESULTS_DIR = "results"` · `def plan(self, job: str, n: int)` |
| `scripts/team_files.py` | `def intent_sections(text: str) -> dict` · `def intent_drift(text: str, intent: str, scope: str) -> list` · `def _split_scope(scope: str)` · `SECTIONS = ("목표", "지시 원문", "하지 않을 것", "결정 기록")` |
| `scripts/team_check.py` | `def check_tree(top: Path, team, base=None) -> tuple` · `def _scope(value) -> str` · `_PLAN_RE = ` · `unknown.append("%s: 출처 커밋 %s 의 파일을 읽지 못했다"` · `GIT_ALLOWED = frozenset({"cat-file", "log", "rev-parse"})` |
| `scripts/roadmap_status.py` | `GIT_ALLOWED = frozenset({"show", "rev-parse", "log", "diff", "merge-base", "cat-file", "grep"})` · `def compute(git: Git, main, blocks: list, records: list, bundles: dict, roadmap_dir: str, settings: dict,` · `def progress(git: Git, main: str, tip: str, block: dict, bundle_path, settings: dict)` · `if layout == team_layout.LAYOUT_TEAM:` 아래 `team_layout.STAGE_PENDING` 둘 · `TASK_STATUS = {` |
| `scripts/roadmap_model.py` | `def approval_date(doc_text: str)` · `def handoff_rows(givers, stages: dict, records: dict) -> list` · `CONFIRM_RE = ` |
| `scripts/roadmap_write.py` | `def stages(top: Path, roadmap: Path, layout=None) -> dict` · `STAGE_PENDING_NOTICE = ` · `def cmd_job(a) -> int` 가 `{"new": team_write.cmd_job_new}` 를 쓴다 · `class Txn` · `def run_txn` |
| `scripts/team_write.py` | `def hand_fixes(top: Path, team, old: dict, new: dict, W) -> list` · `def job_name_refusal(top: Path, team, name: str, roadmap_text: str)` · `FRAMING_HEADS = ` |
| `scripts/check_bundle_coverage.py` | `def plan_task_text(plan_text: str) -> str` · `def check(bundle_text: str, spec_text: str, *, audit_text=None, repo=None) -> dict` · `def check_impl(spec_text: str, report_text: str, only=None, epic_ids=None, receiver_problem=None) -> dict` · `def _block_specs(block: dict, view: dict, repo)` |
| `scripts/spec_review_bundle.py` | `KINDS = ("epic-bundle", "interview-brief")` · `def entry(spec: str, bundle: str, root: str) -> list` |
| `scripts/conductor_ledger.py` | `def c_record(root, a) -> int` · `def c_flush(root, a) -> int` · `def c_write_sections(root, a) -> int` · `print("%s 브랜치 없음" % a.epic)` · `def write_atomic(path: Path, text: str) -> None` |
| `scripts/control_plane.py` | `CODE_STAMP_FILES = ("roadmap_status.py", "roadmap_model.py", "team_layout.py",` · `BUCKETS = ` · `def show_text(items, interview, notes, first_line_fn, select_error=None) -> str` · `def tasks_output(items, select_error=None)` |
| `scripts/branch_tip.py` | `GIT = shutil.which("git") or "git"` · `def tip(root, branch: str)` · `class TipError(Exception)` — 다른 스크립트가 `branch_tip.GIT` 을 쓰지 않는다(`grep -rn -e 'branch_tip\.GIT' -e 'branch_tip_mod\.GIT' plugins` 0줄) |
| `tests/test_roadmap_status.sh` | 정적 락 줄에 파일 열 개와 `"CHECKED 10"` · 사본 줄 둘(`M="$T/mut"` · `M3="$T/mut3"`) |
| `tests/test_team_status_stub.sh` | `"team 로드맵: 단계 계산은 검사 불가(3)로 멈춘다"` |
| `tests/test_team_write.sh` | `"team update: 머지 여부 알림(계획 2 가 뒤집는다)"` · `"출처 커밋이 없다: check rc 3(검사 불가)"` |
| `tests/test_control_plane.py` | `self.assertNotIn("state_path.py", cp.CODE_STAMP_FILES)` |
| `tools/suite/run-all.sh` | 셸 테스트를 고르는 `find` 에 `-not -path '*/fixtures/*'` |
| superpowers `subagent-driven-development/SKILL.md` | 완료 줄의 꼴 `Task <N>: complete (commits <base7>..<head7>, review clean)` 과 판정 줄의 꼴 `Ruling: <what you decided> — <why> — <what it costs if wrong>`(불러온 skill 의 기준 폴더에서 그 두 글을 `grep -n` 으로 찾는다) |

- [ ] **Step 3: 고칠 테스트가 지금 초록인지와 판을 확인한다**

Run:
```bash
export PYTHONDONTWRITEBYTECODE=1
python3 -m unittest plugins/spec-distill/tests/test_team_layout.py plugins/spec-distill/tests/test_team_files.py plugins/spec-distill/tests/test_team_docs.py plugins/spec-distill/tests/test_control_plane.py plugins/spec-distill/tests/test_conductor_ledger.py plugins/spec-distill/tests/test_roadmap_model.py
for t in test_team_status_stub test_team_write test_roadmap_status test_bundle_coverage test_spec_review_bundle test_epic_handoff test_merge_check; do bash plugins/spec-distill/tests/$t.sh | tail -n 1; done
grep -n '"version"' plugins/spec-distill/.claude-plugin/plugin.json
```
Expected: 모두 통과 · 판 `8.15.0`. 이미 떨어지는 테스트가 있으면 이름을 적어 「기존 실패」 로 보고하고, 판이 다르면 Task 16 의 새 판을 그 다음 minor 로 읽는다.

커밋 없음.

---

### Task 2: 이름과 읽기 한 곳 — 단계 · 결과 파일 이름 · 「한다 / 안 한다」 · INTENT.md 머리 (AC29 의 이름 규칙 · AC26 의 락)

**Files:**
- Modify: `plugins/spec-distill/scripts/team_layout.py` · `team_files.py` · `team_check.py` · `roadmap_render.py`
- Test: `plugins/spec-distill/tests/test_team_layout.py` · `test_team_files.py`

**Interfaces:**
- Produces(`team_layout`):
  - `STAGES = ("design", "plan", "implement", "review")` · `PLANNED_STAGES = ("plan", "implement", "review")` · `BLOCKED_FILE = "BLOCKED.md"`
  - `plan_name(n: int) -> str`(`plan-<n>.md`, n < 1 이면 ValueError — `Team.plan` 이 이것을 쓴다) · `plan_number(name: str) -> Optional[int]`(`fullmatch`, 수는 0 으로 시작하지 않는다)
  - `result_name(stage: str, attempt: int, plan: Optional[int] = None) -> str` — 단계가 `STAGES` 밖 · 시도 < 1 · 계획 < 1 · `design` 에 계획 번호면 ValueError
  - `parse_result_name(name: str) -> Optional[tuple]` — `(단계, 계획 | None, 시도)`. 꼴이 아니면 None(`BLOCKED.md` · `.gitkeep` 포함)
  - `job_of_path(roadmaps_dir: str, rel: str) -> Optional[tuple]` — `<roadmaps_dir><팀>/jobs/<과제>/<나머지>` 꼴이면 `(Team, 과제, 나머지)`, 아니면(나머지가 비었거나 팀 · 과제 이름이 못 쓰는 이름이면) None
  - `Team.jobs`(속성 — 과제 폴더들의 부모) · `Team.result(job, stage, attempt, plan=None) -> str` · `Team.blocked(job) -> str`
- Produces(`team_files`):
  - `SCOPE_RE`(지금 `roadmap_render.SCOPE_RE` 의 그 패턴 — `roadmap_render.SCOPE_RE = team_files.SCOPE_RE` 로 한 객체다)
  - `scope_line(value) -> str` — 로드맵 범위 칸(글 또는 하위 항목 목록)을 `한다 … / 안 한다 …` 한 줄로. `team_check._scope` 의 몸을 옮기고 그 함수는 지운다
  - `intent_meta(text: str) -> dict` — INTENT.md 머리의 키 → 따옴표 벗긴 값. 머리가 없거나 닫히지 않았으면 `FormatError`
  - `intent_ranges` 는 `intent_meta(text).get("kind")` 로 단순 작업을 가린다(정확한 줄 비교를 버린다 — 잔여)
- `team_check` 는 `_PLAN_RE` 대신 `L.plan_number`, `_scope` 대신 `F.scope_line` 을 부른다. 동작은 같다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_team_layout.py` 에 더한다:

```python
class ResultNames(unittest.TestCase):   # 계획 2 — 단계와 결과 파일 이름
    def test_stages_and_names(self):
        self.assertEqual(L.STAGES, ("design", "plan", "implement", "review"))
        self.assertEqual(L.PLANNED_STAGES, ("plan", "implement", "review"))
        self.assertEqual(L.BLOCKED_FILE, "BLOCKED.md")
        self.assertEqual(L.result_name("implement", 2, plan=1), "implement-plan-1-2.md")
        self.assertEqual(L.result_name("design", 1), "design-1.md")
        self.assertEqual(L.result_name("plan", 3, plan=2), "plan-plan-2-3.md")
        for bad in (("deploy", 1, None), ("implement", 0, None), ("implement", 1, 0), ("design", 1, 1)):
            self.assertRaises(ValueError, L.result_name, *bad)

    def test_parse_result_name(self):
        for name, want in (("implement-plan-1-2.md", ("implement", 1, 2)), ("review-4.md", ("review", None, 4)),
                           ("plan-plan-2-3.md", ("plan", 2, 3)), ("plan-3.md", ("plan", None, 3)), ("design-10.md", ("design", None, 10))):
            self.assertEqual(L.parse_result_name(name), want, name)
            self.assertEqual(L.result_name(want[0], want[2], want[1]), name)   # 왕복
        for bad in ("BLOCKED.md", ".gitkeep", "implement-plan-01-2.md", "implement-0.md", "design-plan-1-1.md", "implement-1.md\n",
                    "implement-plan-1.2.md", "Implement-1.md", "implement-1.txt", "implement--1.md", ""):
            self.assertIsNone(L.parse_result_name(bad), bad)

    def test_plan_names(self):
        self.assertEqual((L.plan_name(2), L.plan_number("plan-2.md")), ("plan-2.md", 2))
        self.assertEqual(L.Team(D, "2026-a").plan("R3", 2), D + "2026-a/jobs/R3/" + L.plan_name(2))
        for bad in ("plan-02.md", "plan-0.md", "plan-2.md.bak", "plan-.md", "plan-2.MD", "plan-2.md\n"):
            self.assertIsNone(L.plan_number(bad), bad)

    def test_job_paths(self):
        t = L.Team(D, "2026-a")
        self.assertEqual(t.jobs, D + "2026-a/jobs")
        self.assertEqual(t.result("R3", "implement", 1, plan=2), D + "2026-a/jobs/R3/results/implement-plan-2-1.md")
        self.assertEqual(t.blocked("R3"), D + "2026-a/jobs/R3/results/BLOCKED.md")
        self.assertEqual(L.job_of_path(D, t.result("R3", "implement", 1)), (t, "R3", "results/implement-1.md"))
        self.assertEqual(L.job_of_path(D, t.intent("fix-typo"))[1:], ("fix-typo", "INTENT.md"))
        for bad in (t.roadmap, t.rules, t.job("R3"), t.job("R3") + "/", "elsewhere/2026-a/jobs/R3/INTENT.md",
                    D + "worker/jobs/R3/INTENT.md", D + "2026-a/jobs/leader/INTENT.md", D + "2026-a/jobs/a b/INTENT.md", D + "jobs/R3/INTENT.md"):
            self.assertIsNone(L.job_of_path(D, bad), bad)
```

`test_team_files.py` 에 더한다:

```python
class OneScopeReader(unittest.TestCase):   # 잔여 — 「한다 … / 안 한다 …」 를 읽는 곳이 하나
    def test_same_pattern_object_and_no_private_copy(self):
        import roadmap_render as R
        import team_check as C
        self.assertIs(R.SCOPE_RE, F.SCOPE_RE)
        self.assertFalse(hasattr(C, "_scope"))
        self.assertFalse(hasattr(C, "_PLAN_RE"))

    def test_scope_line(self):
        self.assertEqual(F.scope_line(["한다: 가", "한다: 나", "안 한다: 다"]), "한다 가 · 나 / 안 한다 다")
        self.assertEqual(F.scope_line("한다 가 / 안 한다 나"), "한다 가 / 안 한다 나")
        self.assertEqual(F.scope_line(["한다: 가"]), M.field_text(["한다: 가"]))   # 둘 다 있지 않으면 칸 글 그대로
        self.assertEqual(F.scope_line(["한다: 가", "메모"]), M.field_text(["한다: 가", "메모"]))

    def test_split_matches_the_table_rule(self):   # 표가 받는 꼴과 INTENT.md 가 가르는 꼴이 같다
        for scope, goal_tail, not_do in (("한다 가 / 안 한다 나", "가", "- 나"), ("한다 가 / 안 한다 나 / 안 한다 다", None, "- 없음"),
                                         ("한다  가 / 안 한다 나", None, "- 없음"), ("그냥 글", None, "- 없음")):
            self.assertEqual(F.goal_text("의도", scope), "의도\n\n- 범위: %s" % (goal_tail or scope), scope)
            self.assertEqual(F.not_text(scope), not_do, scope)


class IntentMeta(unittest.TestCase):   # 잔여 — kind 판정이 줄 비교가 아니다
    HEAD = "---\ntype: job\njob: fix\nkind: %s\nroadmap: r/t/roadmap.md\nbranch: fix/x\npaths: [a.py]\n---\n\n"
    BODY = "## 목표\n\n가\n\n## 지시 원문\n\n- 범위: intent/original.md 2–3행\n\n## 하지 않을 것\n\n- 없음\n\n## 결정 기록\n"

    def test_meta_unquotes_and_trims(self):
        for kind in ("task", '"task"', "task  ", "'task'"):
            text = self.HEAD % kind + self.BODY
            self.assertEqual(F.intent_meta(text)["kind"], "task", kind)
            self.assertEqual(F.intent_ranges(text), [], kind)   # 받은 말 안의 범위 줄 꼴을 범위로 읽지 않는다
        self.assertEqual(F.intent_ranges(self.HEAD % "epic" + self.BODY), [(2, 3)])
        self.assertRaises(F.FormatError, F.intent_meta, "머리 없는 글\n")
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_layout.py plugins/spec-distill/tests/test_team_files.py`
Expected: `AttributeError: module 'team_layout' has no attribute 'PLANNED_STAGES'` 류의 ERROR 와 `OneScopeReader` · `IntentMeta` FAIL.

- [ ] **Step 3: 네 파일을 고친다**

`team_layout.py` — 결과 파일 이름의 패턴은 `STAGES` 를 이어 만든다(단계 글자를 두 번 쓰지 않는다). `design` 에 계획 번호가 붙은 이름은 None 이다. `job_of_path` 는 `team_name_problem` · `job_name_problem` 으로 이름을 거른다. `STAGE_PENDING` 은 이 과제에서 지우지 않는다(Task 14). `team_files.py` — `_split_scope` 는 `SCOPE_RE.fullmatch` 와 「` / 안 한다 ` 가 한 번」 으로 가른다(`roadmap_write.py` 의 분해안 표 검사와 같은 규칙).

- [ ] **Step 4: 통과와 회귀를 확인한다**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_team_layout.py plugins/spec-distill/tests/test_team_files.py plugins/spec-distill/tests/test_roadmap_render.py plugins/spec-distill/tests/test_roadmap_model.py
bash plugins/spec-distill/tests/test_team_write.sh | tail -n 1; bash plugins/spec-distill/tests/test_roadmap_write.sh | tail -n 1; bash plugins/spec-distill/tests/test_roadmap_status.sh | tail -n 1
```
Expected: 모두 통과(`test_roadmap_write.sh` 의 옛 형식 다이제스트 단언 포함 · 정적 락은 목록을 고치지 않은 채 초록).

- [ ] **Step 5: 커밋**

```bash
git add -- plugins/spec-distill/scripts/team_layout.py plugins/spec-distill/scripts/team_files.py plugins/spec-distill/scripts/team_check.py plugins/spec-distill/scripts/roadmap_render.py plugins/spec-distill/tests/test_team_layout.py plugins/spec-distill/tests/test_team_files.py
git commit -m "feat(spec-distill): 단계 · 결과 파일 이름과 범위 읽기를 한 곳에 둔다" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

---

### Task 3: 결과 파일 · 막힘 파일 · 결정 기록의 글 (AC10 · AC27 · AC29 의 읽는 규칙)

**Files:**
- Modify: `plugins/spec-distill/scripts/team_files.py`
- Test: `plugins/spec-distill/tests/test_team_results.py`(새)

**Interfaces:**
- Consumes: `team_layout.STAGES` · `ROLES` · `parse_result_name`, `roadmap_model.CONFIRM_RE`.
- Produces(`team_files` — 글만 다룬다, 파일 · git 을 만지지 않는다):
  - `RESULT_TYPE = "job-result"` · `BLOCKED_TYPE = "job-blocked"` · `BLOCKED_HEADS = ("## 무엇에 막혔나", "## 풀려면 무엇이 필요한가")`
  - `class Result` — 속성 `stage` · `plan`(없으면 None) · `attempt` · `role` · `head` · `bundle_at` · `job_at`(못 읽은 값은 None) · `tasks`(`(n, 전체, "끝" | "막힘", 커밋 글)` 목록) · `rulings`(줄 목록) · `refutes` · `outputs`(경로 목록) · `end`(「끝」 줄의 커밋 글, 없으면 None) · `machine_text`(머리와 펜스 안을 뺀 본문) · `problems`(사유 줄 목록)
  - `parse_result(text: str) -> Result` — 던지지 않는다. 읽지 못한 것은 `problems` 에 한 줄씩 적는다
  - `progress_of(result) -> tuple` — `(끝난 수, 전체, None)` 또는 `(None, None, 사유)`. 사유는 `"진행 줄 없음"` 이거나 `"진행 줄 깨짐 — <그 줄>"` 이다
  - `class Blocked`(`stage` · `plan` · `attempt` · `head` · `problems`) · `parse_blocked(text: str) -> Blocked`
  - `DECISION_KINDS`(Global Constraints 의 일곱, 그 순서) · `decision_lines(intent_text: str) -> list`(결정 기록 칸의 `- ` 줄들) · `decision_problem(line: str) -> Optional[str]` · `append_decision(intent_text: str, line: str) -> str`(같은 줄이 있으면 글 그대로 · 못 받는 줄이면 `FormatError`)
  - `class Received`(`date` · `name` · `commit` · `first` · `raw`) · `received(intent_text: str) -> tuple`(`(받음 줄 목록, 꼴이 깨진 받음 줄 목록)`) · `received_line(date: str, name: str, commit: str, first: str) -> str`

읽는 규칙(설계 §5 가 정한 값과 Q6 · Q7 · Q16):

- 머리 — 첫 줄 `---` 부터 다음 `---` 까지. `type` 이 `job-result`, `stage` 가 `STAGES` 의 하나, `attempt` 가 1 이상의 수(0 으로 시작하지 않는다), `plan` 은 있으면 1 이상의 수, `role` 이 `ROLES` 의 하나, `head` · `bundle_at` · `job_at` 이 커밋 번호 꼴(16진 40자 또는 64자, `fullmatch`)이어야 한다. 줄 끝의 `\r` 은 떼고 읽는다(CRLF 와 LF 를 같게 읽는다). 끝 줄바꿈이 없어도 읽는다. 첫 글자가 BOM 이면 머리가 없는 것이다.
- 기계 줄 — 머리 뒤, 펜스(줄 머리 공백 뒤 백틱 셋) 밖, 줄 머리에서만 읽는다. `Task ` 뒤가 숫자로 시작하는데 `Task <n>/<전체>: 끝|막힘 — <커밋>` 꼴이 아니면 사유다. 「끝」 줄이 둘이거나 「끝」 줄 뒤에 다른 기계 줄(`Task` · `Ruling:` · `AC<n>:` · `규칙 반증:` · `산출물:`)이 있으면 사유다. `산출물:` 뒤가 비었으면 사유다. `AC<n>:` 줄의 꼴은 여기서 보지 않는다(구현 대조가 본다 — Task 5).
- 진행 — `Task` 줄이 없으면 「진행 줄 없음」. 어느 줄이든 n < 1 · 전체 < 1 · n > 전체이거나 전체가 줄마다 다르면 「진행 줄 깨짐」. 아니면 마지막 `Task` 줄의 n(「막힘」 이면 n − 1)이 끝난 수다.
- 막힘 파일 — 머리 `type: job-blocked` · `stage` · `attempt` · `head`(같은 꼴 규칙), `plan` 은 있으면. 본문의 펜스 밖 `## ` 줄이 `BLOCKED_HEADS` 둘, 그 순서뿐이어야 한다.
- 결정 기록 줄 — `- ` 뒤 첫 칸(` · ` 앞)이 `DECISION_KINDS` 의 하나. `넘김 확인` 은 `roadmap_model.CONFIRM_RE` 에 `fullmatch`. 나머지는 둘째 칸이 실제 달력 날짜(`YYYY-MM-DD`)이고 셋째 칸이 비지 않았다. `결과 받음` 은 `- 결과 받음 · <날짜> · 「<결과 파일 이름> · <커밋 40자 또는 64자> · <첫 줄>」` 에 `fullmatch` 이고 이름이 `parse_result_name` 으로 읽혀야 한다. 줄 나눔 글자(`\n` · `\r` · U+2028 등)가 든 줄은 받지 않는다.
- 덧붙이기 — 결정 기록 칸은 `intent_sections` 와 같은 규칙(마지막 `## 결정 기록` 줄)으로 찾는다. 칸이 비었으면 제목 뒤에 빈 줄 하나를 두고 줄을 적고, 줄이 있으면 마지막 줄 바로 아래에 적는다. 그 칸 앞의 바이트는 바꾸지 않고 글은 줄바꿈 하나로 끝난다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_team_results.py`(unittest — `sys.path` 에 `scripts` 를 넣는 꼴은 `test_team_files.py` 와 같다). `H`(40자 `"a" * 40`) · `B` · `J` 는 테스트가 만든 커밋 번호 꼴 글이다:

```python
def result(body="", **over):
    keys = dict(type="job-result", stage="implement", plan="1", attempt="2", role="worker", head=H, bundle_at=B, job_at=J)
    keys.update(over)
    head = "".join("%s: %s\n" % (k, v) for k, v in keys.items() if v is not None)
    return "---\n" + head + "---\n\n" + body


class Parse(unittest.TestCase):
    def test_reads_head_and_machine_lines(self):
        r = F.parse_result(result("Task 1/3: 끝 — abc1234\nRuling: R-A — 하나 — 둘 — 셋\n메모 한 줄\nTask 2/3: 끝 — 없음\n"
                                  "AC9: 구현됨 — a.py\n규칙 반증: [테스트] 고친 곳엔 — 테스트가 없는 파일이었다\n산출물: docs/x.md\n끝 — " + H + "\n"))
        self.assertEqual(r.problems, [])
        self.assertEqual((r.stage, r.plan, r.attempt, r.role, r.head, r.bundle_at, r.job_at), ("implement", 1, 2, "worker", H, B, J))
        self.assertEqual(r.tasks, [(1, 3, "끝", "abc1234"), (2, 3, "끝", "없음")])
        self.assertEqual(r.rulings, ["Ruling: R-A — 하나 — 둘 — 셋"])
        self.assertEqual((r.outputs, r.end, len(r.refutes)), (["docs/x.md"], H, 1))
        self.assertIn("AC9: 구현됨 — a.py", r.machine_text)

    def test_fenced_lookalikes_are_body(self):   # Review Focus 1
        r = F.parse_result(result("Task 1/2: 끝 — abc1234\n```\n끝 — " + H + "\nAC3: 구현됨 — 인용\nTask 9/2: 끝 — x\n산출물: no.md\n```\n"))
        self.assertEqual((r.problems, r.end, r.outputs, r.tasks), ([], None, [], [(1, 2, "끝", "abc1234")]))
        self.assertNotIn("AC3:", r.machine_text)

    def test_line_endings(self):   # Review Focus 1
        text = result("Task 1/1: 끝 — abc1234\n끝 — " + H)
        for variant in (text, text.replace("\n", "\r\n"), text + "\n\n"):
            r = F.parse_result(variant)
            self.assertEqual((r.problems, r.end, r.head), ([], H, H), repr(variant[-12:]))
        self.assertTrue(F.parse_result("﻿" + text).problems)

    def test_problems_name_what_is_wrong(self):
        for text, word in ((result(), None), ("본문뿐\n", "머리"), ("---\ntype: job-result\n", "닫히지"), (result(type="job-blocked"), "type"),
                           (result(stage="deploy"), "stage"), (result(attempt="0"), "attempt"), (result(attempt="02"), "attempt"),
                           (result(plan="0"), "plan"), (result(role="reviewer"), "role"), (result(head="abc1234"), "head"),
                           (result(bundle_at=None), "bundle_at"), (result(job_at="x" * 40), "job_at"),
                           (result("Task 2: 끝 — a\n"), "Task"), (result("Task 1/2: 진행 — a\n"), "Task"),
                           (result("끝 — " + H + "\n끝 — " + H + "\n"), "끝"), (result("끝 — " + H + "\nRuling: 뒤\n"), "끝"),
                           (result("산출물: \n"), "산출물")):
            problems = F.parse_result(text).problems
            if word is None:
                self.assertEqual(problems, [])
            else:
                self.assertTrue(any(word in p for p in problems), (word, problems))
        self.assertIsNone(F.parse_result(result(plan=None)).plan)   # 계획 번호가 없는 결과 파일


class Progress(unittest.TestCase):
    def p(self, body):
        return F.progress_of(F.parse_result(result(body)))

    def test_numbers(self):
        self.assertEqual(self.p(""), (None, None, "진행 줄 없음"))
        self.assertEqual(self.p("Task 1/7: 끝 — a\nTask 3/7: 끝 — b\n"), (3, 7, None))
        self.assertEqual(self.p("Task 1/7: 끝 — a\nTask 2/7: 막힘 — b\n"), (1, 7, None))   # Q7
        for body in ("Task 9/7: 끝 — a\n", "Task 0/7: 끝 — a\n", "Task 1/0: 끝 — a\n", "Task 1/7: 끝 — a\nTask 2/8: 끝 — b\n"):
            done, total, why = self.p(body)
            self.assertEqual((done, total), (None, None), body)
            self.assertTrue(why.startswith("진행 줄 깨짐 — "), why)


class BlockedFile(unittest.TestCase):
    TEXT = "---\ntype: job-blocked\nstage: implement\nplan: 1\nattempt: 2\nhead: %s\n---\n\n## 무엇에 막혔나\n\n가\n\n## 풀려면 무엇이 필요한가\n\n나\n"

    def test_shape(self):
        b = F.parse_blocked(self.TEXT % H)
        self.assertEqual((b.problems, b.stage, b.plan, b.attempt, b.head), ([], "implement", 1, 2, H))
        for bad in (self.TEXT.replace("job-blocked", "job-result") % H, self.TEXT.replace("## 풀려면 무엇이 필요한가", "## 다음") % H,
                    (self.TEXT % H) + "\n## 덧붙임\n", self.TEXT % "zz", (self.TEXT % H).replace("## 무엇에 막혔나\n\n가\n\n", "")):
            self.assertTrue(F.parse_blocked(bad).problems, bad[-40:])


INTENT = ("---\ntype: job\njob: R3\nkind: epic\nroadmap: r/t/roadmap.md\nbranch:\npaths: []\n---\n\n## 목표\n\n가\n\n## 지시 원문\n\n"
          "- 범위: intent/original.md 2–3행\n\n## 하지 않을 것\n\n- 없음\n\n## 결정 기록\n")


class Decisions(unittest.TestCase):
    def test_append_into_empty_then_below(self):
        one = F.append_decision(INTENT, "spec 승인 · 2026-11-20 · 「이대로 승인 (권장)」")
        self.assertEqual(one, INTENT + "\n- spec 승인 · 2026-11-20 · 「이대로 승인 (권장)」\n")
        two = F.append_decision(one, "- 결정 · 2026-11-21 · 막힘을 풀었다")
        self.assertEqual(two, one + "- 결정 · 2026-11-21 · 막힘을 풀었다\n")
        self.assertEqual(F.append_decision(two, "- 결정 · 2026-11-21 · 막힘을 풀었다"), two)   # 같은 줄은 한 번
        self.assertEqual(F.decision_lines(two), ["- spec 승인 · 2026-11-20 · 「이대로 승인 (권장)」", "- 결정 · 2026-11-21 · 막힘을 풀었다"])
        self.assertTrue(two.startswith(INTENT))   # 앞 바이트 그대로

    def test_kinds_and_shapes(self):
        self.assertEqual(F.DECISION_KINDS, ("spec 승인", "병렬 답", "계획 검토", "결과 받음", "예약 밖 변경", "넘김 확인", "결정"))
        ok = ["- 넘김 확인 · R1 · 0a1b2c3d · 계획에 넣었다", "- 예약 밖 변경 · 2026-11-20 · README 한 줄",
              "- 결과 받음 · 2026-11-20 · 「implement-plan-1-2.md · %s · 결과 대조: 통과 — …」" % H]
        for line in ok:
            self.assertIsNone(F.decision_problem(line), line)
        bad = ["- 메모 · 2026-11-20 · 글", "- 결정 · 11/20 · 글", "- 결정 · 2026-02-30 · 글", "- 결정 · 2026-11-20 · ", "- 결정",
               "- 넘김 확인 · 2026-11-20 · 글", "- 결과 받음 · 2026-11-20 · implement-1.md · %s · 글" % H,
               "- 결과 받음 · 2026-11-20 · 「BLOCKED.md · %s · 글」" % H, "- 결과 받음 · 2026-11-20 · 「implement-1.md · abc1234 · 글」"]
        for line in bad:
            self.assertTrue(F.decision_problem(line), line)
            self.assertRaises(F.FormatError, F.append_decision, INTENT, line)
        for line in ("- 결정 · 2026-11-20 · 한 줄\n둘째 줄", "- 결정 · 2026-11-20 · 가 나"):
            self.assertRaises(F.FormatError, F.append_decision, INTENT, line)

    def test_heading_lookalike_in_received_words(self):   # 받은 말 안의 `## 결정 기록` 꼴 줄
        task = INTENT.replace("kind: epic", "kind: task").replace("- 범위: intent/original.md 2–3행", "받은 말\n## 결정 기록\n- 결정 · 흉내")
        out = F.append_decision(task, "- 결정 · 2026-11-20 · 진짜")
        self.assertEqual(F.decision_lines(out), ["- 결정 · 2026-11-20 · 진짜"])
        self.assertIn("받은 말\n## 결정 기록\n- 결정 · 흉내", F.intent_sections(out)["지시 원문"])


class ReceivedLines(unittest.TestCase):
    def test_roundtrip_and_broken(self):
        line = F.received_line("2026-11-20", "implement-plan-1-2.md", H, "결과 대조: 통과 — 글")
        self.assertEqual(line, "- 결과 받음 · 2026-11-20 · 「implement-plan-1-2.md · %s · 결과 대조: 통과 — 글」" % H)
        text = F.append_decision(F.append_decision(INTENT, line), F.received_line("2026-11-22", "implement-plan-1-3.md", J, "둘째"))
        got, broken = F.received(text)
        self.assertEqual([(r.date, r.name, r.commit, r.first) for r in got],
                         [("2026-11-20", "implement-plan-1-2.md", H, "결과 대조: 통과 — 글"), ("2026-11-22", "implement-plan-1-3.md", J, "둘째")])
        self.assertEqual(broken, [])
        hand = INTENT + "\n- 결과 받음 · 2026-11-20 · implement-1.md 받았다\n"   # 손으로 쓴 꼴이 깨진 줄은 세지 않고 따로 낸다
        self.assertEqual(F.received(hand), ([], ["- 결과 받음 · 2026-11-20 · implement-1.md 받았다"]))
        self.assertRaises(F.FormatError, F.received_line, "2026-11-20", "BLOCKED.md", H, "글")
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_results.py`
Expected: `AttributeError: module 'team_files' has no attribute 'parse_result'` 류의 ERROR.

- [ ] **Step 3: `team_files.py` 에 위 인터페이스를 쓴다**

제목 줄(`## …`)은 문자열 비교로 읽는다(모듈 수준 `re.compile` 에 `##` 패턴을 두지 않는다). 날짜는 꼴(`fullmatch`)과 `datetime.date.fromisoformat` 둘 다 본다. 파일 맨 위 docstring 의 「과제 파일(INTENT · sources)과 원자료 사본」 에 결과 파일 · 막힘 파일을 더한다.

- [ ] **Step 4: 통과와 락을 확인한다**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_team_results.py plugins/spec-distill/tests/test_team_files.py plugins/spec-distill/tests/test_team_layout.py
python3 -m unittest plugins/quality-gates/tests/test_utf8_explicit.py
bash plugins/spec-distill/tests/test_roadmap_status.sh | tail -n 1; bash plugins/spec-distill/tests/test_check_brief.sh | tail -n 1
```
Expected: 모두 통과(경로 조각 락 `LiteralsLiveInOnePlace` · 정적 락 · §6 단일화 락 포함).

- [ ] **Step 5: 커밋**

```bash
git add -- plugins/spec-distill/scripts/team_files.py plugins/spec-distill/tests/test_team_results.py
git commit -m "feat(spec-distill): 결과 파일 · 막힘 파일 · 결정 기록 줄을 읽는다" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

---

### Task 4: superpowers 변환기와 결과 파일 맞추기 — `workflow_superpowers.py` · `job sync` (AC17 · AC27)

**Files:**
- Create: `plugins/spec-distill/scripts/workflow_superpowers.py` · `plugins/spec-distill/tests/fixtures/team_repo.sh`
- Modify: `plugins/spec-distill/scripts/check_bundle_coverage.py`(`plan_task_text` 를 떼어 낸다) · `team_write.py`(`cmd_job_sync`) · `roadmap_write.py`(`job sync` 진입)
- Test: `plugins/spec-distill/tests/test_workflow_superpowers.py`(새) · `test_team_sync.sh`(새) · `test_roadmap_status.sh` · `test_bundle_coverage.sh`(T-d · T-f 의 이 과제 몫)

**Interfaces:**
- Consumes: `team_files.parse_result` · `team_layout.job_of_path` · `parse_result_name` · `ROLES`.
- Produces(`workflow_superpowers` — 읽기만 한다, `subprocess` 를 import 하지 않는다):
  - `TASK_HEAD = "### Task"` — 이 글자가 있는 스크립트는 이 파일뿐이다
  - `task_text(plan_text: str) -> str` — 지금 `check_bundle_coverage.plan_task_text` 의 몸 그대로(펜스 밖의 2단계 · 3단계 제목이 절을 가르고, `TASK_HEAD` 로 시작하는 절만 잇는다)
  - `task_total(plan_text: str) -> int` — 펜스 밖에서 `TASK_HEAD` 로 시작하는 줄 수
  - `ledger_lines(ledger_text: str, total: int) -> list` — 구현 원장에서 결과 파일에 실을 줄들(원장의 차례)
  - `place_sentence(path: str, stage: str) -> str` — `design` 이면 `사용자 선호: 설계문서는 기본 자리 대신 <path> 에 쓴다.`, `plan` 이면 `사용자 선호: 계획은 기본 자리 대신 <path> 에 쓴다.`, 그 밖의 단계면 ValueError
  - 명령줄 `workflow_superpowers.py place --roadmap <로드맵 레포 상대경로> --job <과제> --stage design|plan [--plan <n>] [--root <레포>]` — 그 문장 한 줄. 종료 코드 0 · 2(사용법 — `plan` 단계에 `--plan` 없음 · 다른 단계 · 로드맵 자리가 아님) · 3(레포 설정을 못 읽음)
- `check_bundle_coverage` 는 `from workflow_superpowers import task_text` 로 읽고 `plan_task_text` 는 없앤다. 맨 위 docstring 의 「계획 `### Task` 절」 은 「계획의 task 절」 로 고친다.
- Produces(`team_write`): `cmd_job_sync(a, W) -> int` — `roadmap_write.py job sync --result <결과 파일 경로> [--role <역할> --bundle-at <커밋> --job-at <커밋>] [--ledger <원장> --plan-file <계획>] [--end <커밋>]`. 종료 코드 0 · 1(거절 — 쓰지 않았다) · 2(사용법).

`ledger_lines` 의 규칙(superpowers 의 꼴은 Task 1 Step 2 에서 확인한 것):

- 줄마다 앞뒤 공백과 앞의 `- ` · `* ` 를 뗀다.
- `Task <N>: complete` 로 시작하는 줄(N 은 1 이상) → `Task <N>/<total>: 끝 — <커밋>`. 커밋은 그 줄의 `commits <a>..<b>` 에서 `<b>`(16진 7–64자), 없으면 `없음`. 같은 N 의 완료 줄이 또 나오면 처음 것만 쓴다.
- `Ruling:` 이 든 줄 → `Ruling: <그 뒤 글>`. 같은 줄은 한 번만.
- 그 밖의 줄(`Task 5: 진행 중 …` · `Task 2: fix round …` 등)은 내지 않는다.

`job sync` 의 규칙(Q15):

- `--result` 는 `layout: team` 로드맵의 과제 폴더 안 결과 폴더의 결과 파일 이름이어야 한다(`job_of_path` 와 `parse_result_name`) — 아니면 거절. 로드맵 폴더는 `team_for`(있는 함수)와 같은 길로 얻는다.
- 파일이 없으면 `--role` · `--bundle-at` · `--job-at` 이 모두 있어야 하고(없으면 거절 「머리를 만들 값이 없다」), 머리를 만든다 — `type` · `stage` · `plan`(이름에 있을 때) · `attempt` 는 이름에서, `head` 는 `--job-at` 값으로. 머리 키의 차례는 `type · stage · plan · attempt · role · head · bundle_at · job_at` 이고 머리 뒤에 빈 줄 하나를 둔다.
- 파일이 있으면 `parse_result` 가 사유 없이 읽고 머리의 단계 · 계획 · 시도가 이름과 같아야 한다(아니면 거절). 머리 값 인자를 줘도 있는 머리는 고치지 않는다.
- `--ledger` 와 `--plan-file` 은 함께만 받는다(하나만이면 사용법 오류). `ledger_lines(원장 글, task_total(계획 글))` 가운데 파일에 같은 글자의 줄이 없는 것만 끝에 덧붙인다.
- `--end <커밋>`(커밋 번호 꼴 40자 또는 64자)은 머리의 `head:` 줄을 그 값으로 바꾸고 맨 끝에 `끝 — <커밋>` 을 단다.
- 「끝」 줄이 있는 파일은 고치지 않는다 — 바꿀 것이 없으면 0(「바뀐 것 없음」), 있으면 거절(「끝난 결과 파일은 고치지 않는다 — 다시 하는 일은 새 시도 번호다」).
- 쓰기는 `cmd_job_new` 와 같은 거래(`W.Txn` · `W.run_txn`)로 한 파일이다. 일꾼이 손으로 더한 줄(`AC<n>:` · `산출물:` · 산문)은 바이트 그대로 남는다. git 은 부르지 않는다(커밋이 실재하는지는 결과 대조가 본다).
- 화면: `[spec-distill] 결과 파일을 맞췄다: <경로> — 머리 만듦 · Task 줄 +<n> · Ruling 줄 +<m> · 끝 줄`(한 일만 ` · ` 로 잇는다) 또는 `[spec-distill] 바뀐 것 없음: <경로>`.

`tests/fixtures/team_repo.sh` — 새 셸 테스트가 source 하는 한 곳(부르는 쪽이 `ROOT` · `T` 를 정하고 `shared/tests/assert.sh` 를 먼저 source 한다):

- `team_repo` — `$T/origin.git`(bare · 기본 브랜치 `main`)과 `W="$T/repo"`(clone)를 만들고, 새로 쓴 brief · audit(번호 `C1` · `D2` · `C3` · `OQ1` · `S1`–`S4` — 꼴은 `test_team_status_stub.sh` 의 것을 따르되 글은 다르게)을 커밋한 뒤 `create --layout team` 으로 팀 `tm` 을 만들어 커밋 · push 하고 `origin/HEAD` 를 세운다. `RD`(해결자 `repo_defaults.py get roadmaps_dir` 의 값) · `TM="${RD}tm"` · `RM="$TM/roadmap.md"` 를 정한다.
- 팀 `tm` 의 블록 — `P1` 결정(`S3 · OQ1`), `E1` 묶음(브랜치 `feature/tm-e1, feature/tm-e1b` · 경로 예약 `src/e1/` · `C1 · S1`), `E2` 묶음(브랜치 `feature/tm-e2` · 경로 예약 `src/e2/` · `D2 · S2` · 블록에 `- 흐름: 조사 — 파일을 읽어 표로 낸다` 와 `- 산출물: <TM>/jobs/E2/survey.md`), `E3` 묶음(의존 `E1` · 브랜치 `feature/tm-e3` · 경로 예약 `src/e3/` · `C3 · S1 · S4` — 발화 `S1` 은 `E1` 과 `E3` 둘에 배정한다. 생성기가 그 표를 거절하면 멈춰 보고한다). 지시 원문 범위는 묶음마다 원자료 사본의 앞 구간 안이다.
- `g <git 인자…>`(이름 · 메일을 주고 서명을 끈 W 의 git) · `js <json> <식>` · `status <json 파일> [<인자…>]`(`(cd "$W" && python3 "$RS" "$RM" --json "$@") > 파일`, rc 를 echo) · `put <경로> <글>`(쓰고 `g add`) · `decide <과제> <줄>`(작업 폴더의 그 과제 INTENT.md 에 `team_files.append_decision` 으로 한 줄 — `conductor_ledger.py record` 가 team 을 아는 것은 Task 13 이다) · `sync <과제> <결과 파일 이름> <job sync 인자…>`(그 과제 결과 폴더의 그 이름으로 `job sync` 를 부른다 — 출력은 `$T/out.txt`, rc 를 echo). `status` 는 기본 브랜치와 브랜치 끝을 읽으므로 걸음마다 커밋하고 push 한 뒤에 부른다.

- [ ] **Step 1: 변환기의 실패하는 테스트를 쓴다**

`test_workflow_superpowers.py`(unittest):

```python
PLAN = ("# 계획\n\n## Global\n\nAC1 은 여기 있어도 세지 않는다\n\n### Task 1: 하나 (AC2)\n\n```\n### Task 9: 펜스 안\n```\n\n"
        "### Task 2: 둘\n\nAC3\n\n### 다른 절\n\nAC4\n\n### Task 3: 셋\n")
LEDGER = ("# SDD ledger — plan: docs/p.md\n\n- Task 1: complete (커밋 없음 — 읽기뿐)\n- Ruling: R-A — 하나 — 둘 — 셋\n"
          "- Task 2: 구현자 DONE_WITH_CONCERNS (abc1234)\n- Task 2: fix round 1/5 (1 addressed)\n"
          "- Task 2: complete (commits d391105..d91837e — 둘, review clean after round 1)\nRuling: R-A — 하나 — 둘 — 셋\n"
          "* Ruling: R-B — 넷\n- Task 2: complete (commits 1111111..2222222, review clean)\n- Task 5: 진행 중\n")


class Plan(unittest.TestCase):
    def test_task_sections(self):
        text = WS.task_text(PLAN)
        self.assertIn("### Task 1: 하나 (AC2)", text)
        self.assertIn("### Task 9: 펜스 안", text)      # 펜스 안 줄은 절 경계가 아니고 본문에 든다
        self.assertNotIn("AC1", text); self.assertNotIn("AC4", text)
        self.assertEqual(WS.task_total(PLAN), 3)          # 펜스 안의 제목 꼴은 세지 않는다


class Ledger(unittest.TestCase):
    def test_lines_in_ledger_order(self):
        self.assertEqual(WS.ledger_lines(LEDGER, 3), ["Task 1/3: 끝 — 없음", "Ruling: R-A — 하나 — 둘 — 셋",
                                                     "Task 2/3: 끝 — d91837e", "Ruling: R-B — 넷"])
        self.assertEqual(WS.ledger_lines("", 3), [])

    def test_lines_are_read_back_by_the_result_reader(self):   # 변환기가 낸 줄을 결과 파일 읽기가 그대로 읽는다
        body = "\n".join(WS.ledger_lines(LEDGER, 3)) + "\n"
        r = F.parse_result("---\ntype: job-result\nstage: implement\nattempt: 1\nrole: worker\nhead: %s\nbundle_at: %s\njob_at: %s\n---\n\n%s"
                           % (H, H, H, body))
        self.assertEqual((r.problems, F.progress_of(r)), ([], (2, 3, None)))
        self.assertEqual(len(r.rulings), 2)


class Place(unittest.TestCase):
    def test_sentences(self):
        self.assertEqual(WS.place_sentence("r/t/jobs/R3/design.md", "design"), "사용자 선호: 설계문서는 기본 자리 대신 r/t/jobs/R3/design.md 에 쓴다.")
        self.assertEqual(WS.place_sentence("r/t/jobs/R3/plan-2.md", "plan"), "사용자 선호: 계획은 기본 자리 대신 r/t/jobs/R3/plan-2.md 에 쓴다.")
        self.assertRaises(ValueError, WS.place_sentence, "x", "implement")


class OnePlaceForTheTaskShape(unittest.TestCase):   # AC17 — 변환기 밖에 그 꼴을 읽는 코드가 없다
    def test_only_the_adapter_spells_the_heading(self):
        hits = [p.name for p in sorted(SCRIPTS.glob("*.py"))
                if p.name != "workflow_superpowers.py" and WS.TASK_HEAD in p.read_text(encoding="utf-8")]
        self.assertEqual(hits, [])
        self.assertIn(WS.TASK_HEAD, (SCRIPTS / "workflow_superpowers.py").read_text(encoding="utf-8"))   # 양성 대조
        self.assertGreater(len(list(SCRIPTS.glob("*.py"))), 40)

    def test_plan_check_reads_through_the_adapter(self):
        self.assertIs(cbc.task_text, WS.task_text)
        self.assertFalse(hasattr(cbc, "plan_task_text"))
        spec = "## Acceptance Criteria\n\n- AC1: 가\n- AC2: 나\n- AC3: 다\n- AC4: 라\n"
        self.assertEqual(cbc.check_plan(spec, PLAN)["missing"], ["AC1", "AC4"])
```

- [ ] **Step 2: 끝에서 끝 테스트를 쓴다**

`test_team_sync.sh`(머리는 `test_team_status_stub.sh` 와 같은 꼴 — `fixtures/team_repo.sh` 를 source 하고 `team_repo` 를 부른다). 단언:

```bash
R="$TM/jobs/E1/results/implement-plan-1-1.md"
B="$(g rev-parse origin/main)"; J="$(g rev-parse HEAD)"
assert_eq "$(sync E1 implement-plan-1-1.md)" "1" "job sync: 파일도 머리 값도 없으면 거절"
assert_contains "$(cat "$T/out.txt")" "머리를 만들 값이 없다" "job sync: 거절 사유"
[ ! -e "$W/$R" ] && ok "job sync: 거절하면 파일을 만들지 않는다" || no "job sync: 거절했는데 파일이 생겼다"
assert_eq "$(sync E1 implement-plan-1-1.md --role worker --bundle-at "$B" --job-at "$J")" "0" "job sync: 머리를 만든다"
assert_eq "$(cat "$W/$R")" "$(printf -- '---\ntype: job-result\nstage: implement\nplan: 1\nattempt: 1\nrole: worker\nhead: %s\nbundle_at: %s\njob_at: %s\n---' "$J" "$B" "$J")" "job sync: 머리 글과 키의 차례"
# 원장과 계획 — LEDGER · PLAN 은 test_workflow_superpowers.py 의 것과 다른 글로 쓴다(Task 셋, Task 1 · 2 완료, Ruling 하나)
assert_eq "$(sync E1 implement-plan-1-1.md --ledger "$T/ledger.md" --plan-file "$T/plan.md")" "0" "job sync: 원장에서 줄을 낸다"
assert_eq "$(grep -c '^Task ' "$W/$R"):$(grep -c '^Ruling: ' "$W/$R")" "2:1" "job sync: Task 줄 둘 · Ruling 줄 하나"
printf 'AC1: 구현됨 — src/e1/a.txt\n\n손으로 쓴 메모\n' >> "$W/$R"; cp "$W/$R" "$T/before.md"
assert_eq "$(sync E1 implement-plan-1-1.md --ledger "$T/ledger.md" --plan-file "$T/plan.md")" "0" "AC27: 같은 원장으로 두 번째"
cmp -s "$W/$R" "$T/before.md" && ok "AC27: 두 번 돌려도 같은 줄이 두 번 생기지 않는다(바이트 그대로)" || no "AC27: 두 번째 실행이 파일을 바꿨다"
assert_contains "$(cat "$T/out.txt")" "바뀐 것 없음" "job sync: 바뀐 것이 없다고 말한다"
printf -- '- Task 3: complete (commits 3333333..4444444, review clean)\n' >> "$T/ledger.md"
assert_eq "$(sync E1 implement-plan-1-1.md --ledger "$T/ledger.md" --plan-file "$T/plan.md")" "0" "job sync: 원장이 늘면"
assert_eq "$(tail -n 1 "$W/$R")" "Task 3/3: 끝 — 4444444" "job sync: 늘어난 줄만 끝에 붙는다"
assert_contains "$(cat "$W/$R")" "손으로 쓴 메모" "job sync: 손으로 쓴 줄은 그대로"
assert_eq "$(sync E1 implement-plan-1-1.md --end "$J")" "0" "job sync: 끝낸다"
assert_eq "$(tail -n 1 "$W/$R")" "끝 — $J" "job sync: 끝 줄이 마지막 줄"
assert_eq "$(sync E1 implement-plan-1-1.md --end "$J")" "0" "job sync: 끝난 파일에 같은 끝 — 바뀐 것 없음"
printf -- '- Task 4: complete (commits 5555555..6666666, review clean)\n' >> "$T/ledger.md"; cp "$W/$R" "$T/closed.md"
assert_eq "$(sync E1 implement-plan-1-1.md --ledger "$T/ledger.md" --plan-file "$T/plan.md")" "1" "job sync: 끝난 파일은 고치지 않는다"
cmp -s "$W/$R" "$T/closed.md" && ok "job sync: 거절하면 바이트 그대로" || no "job sync: 끝난 파일을 바꿨다"
# 거절 · 사용법: 이름과 머리가 어긋남(머리 attempt 를 2 로 고친 사본) → 1 · 결과 폴더 밖 경로 → 1 · 이름 꼴이 아님(BLOCKED.md) → 1 ·
#   --ledger 만 → 2 · --end abc1234(짧은 번호) → 2 · --role reviewer → 2 · team 형식이 아닌 로드맵의 폴더 → 1
# place: 그 문장에 "$TM/jobs/E1/design.md" · --stage plan --plan 2 는 "$TM/jobs/E1/plan-2.md" · --stage plan 만 → 2 · --stage implement → 2
```

주석으로 적은 줄도 모두 단언으로 옮긴다.

- [ ] **Step 3: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_workflow_superpowers.py; bash plugins/spec-distill/tests/test_team_sync.sh | tail -n 3`
Expected: `ModuleNotFoundError: No module named 'workflow_superpowers'` 와 셸 테스트의 실패 줄들.

- [ ] **Step 4: 변환기 · `job sync` · 번호 대조의 import 를 쓴다**

`roadmap_write.py` 의 `job` 하위 명령에 `sync` 를 더하고 `cmd_job` 의 표에 `"sync": team_write.cmd_job_sync` 를 넣는다. 인자 꼴 검사(역할 이름 · 커밋 번호 꼴 · 함께 주는 인자)는 사용법 오류(`W.Usage`)다.

- [ ] **Step 5: 락의 목록을 고친다 (T-d · T-f 의 이 과제 몫)**

`tests/test_roadmap_status.sh` — 정적 락 줄의 파일 목록 끝에 `"$S/workflow_superpowers.py"` 를 더하고 `CHECKED 10` → `CHECKED 11`, 두 라벨의 「열 스크립트」 → 「열한 스크립트」. 사본 줄 둘(`M="$T/mut"` · `M3="$T/mut3"`)의 `cp` 에 `"$S/workflow_superpowers.py"`. `tests/test_bundle_coverage.sh` 의 사본 줄 둘(`cp "$S/section6.py" …`)에 `"$S/workflow_superpowers.py"`. 단언의 뜻과 규칙은 고치지 않는다.

- [ ] **Step 6: 통과와 회귀를 확인한다**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_workflow_superpowers.py plugins/spec-distill/tests/test_team_results.py plugins/spec-distill/tests/test_team_layout.py
chmod +x plugins/spec-distill/tests/test_team_sync.sh && bash plugins/spec-distill/tests/test_team_sync.sh | tail -n 1
bash plugins/spec-distill/tests/test_bundle_coverage.sh | tail -n 1; bash plugins/spec-distill/tests/test_roadmap_status.sh | tail -n 1; bash plugins/spec-distill/tests/test_team_write.sh | tail -n 1
```
Expected: 모두 통과(`test_bundle_coverage.sh` 의 `--plan` 단언은 고치지 않은 채).

- [ ] **Step 7: 커밋**

```bash
git add -- plugins/spec-distill/scripts/workflow_superpowers.py plugins/spec-distill/scripts/check_bundle_coverage.py plugins/spec-distill/scripts/team_write.py plugins/spec-distill/scripts/roadmap_write.py plugins/spec-distill/tests/fixtures/team_repo.sh plugins/spec-distill/tests/test_workflow_superpowers.py plugins/spec-distill/tests/test_team_sync.sh plugins/spec-distill/tests/test_roadmap_status.sh plugins/spec-distill/tests/test_bundle_coverage.sh
git ls-files -s plugins/spec-distill/tests/test_team_sync.sh   # 100755 여야 한다
git commit -m "feat(spec-distill): superpowers 변환기와 결과 파일 맞추기(job sync)" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

---

### Task 5: 결과 대조 — `job_results.py` (AC10 · AC29)

**Files:**
- Create: `plugins/spec-distill/scripts/job_results.py`
- Modify: `plugins/spec-distill/scripts/roadmap_status.py`(`Git.names` · `Git.touched` · 허용 명령)
- Test: `plugins/spec-distill/tests/test_job_results.sh`(새) · `test_roadmap_status.sh`(T-d 의 이 과제 몫)

**Interfaces:**
- Consumes: `team_files.parse_result` · `received` · `received_line`, `team_layout.parse_result_name` · `Team`, `workflow_superpowers.task_text`, `check_bundle_coverage.acceptance_ids` · `check_impl` · `AC_TOKEN_RE`.
- Produces(`roadmap_status.Git`):
  - `GIT_ALLOWED` 에 `"ls-tree"` 를 더한다(집합 글의 끝에 — `"show"` 가 첫 원소인 것은 있는 변이가 기댄다)
  - `names(self, rev: str, folder: str) -> Optional[list]` — 그 트리의 `folder` 바로 아래 이름들(정렬). 폴더가 없으면 `[]`, git 이 실패하면 `failures` 에 남기고 None
  - `touched(self, tip: str, excludes: list, paths: list) -> Optional[list]` — `tip` 에서 닿고 `excludes` 의 어느 커밋에서도 닿지 않는 커밋 가운데 merge 가 아닌 것이 바꾼 파일(`paths` 아래, 정렬 · 겹침 없음). `paths` 가 비면 git 을 부르지 않고 `[]`. 실패하면 `failures` 에 남기고 None
- Produces(`job_results` — 읽기만 한다. git 은 받은 `Git` 으로만):
  - `class Check`(NamedTuple — `ok: bool` · `first: str` · `problems: list` · `unknown: list` · `result`(읽힌 `team_files.Result` 또는 None))
  - `result_names(git, tip: str, team, job: str) -> Optional[list]` — 결과 폴더의 이름 가운데 `parse_result_name` 이 읽는 것(막힘 파일 · `.gitkeep` 은 들지 않는다)
  - `newest(names: list, stage: str, plan) -> Optional[str]` — 그 단계 · 그 계획(None 은 계획 번호 없는 이름)의 가장 큰 시도
  - `plan_scope(plan_text, acs: list) -> list` — 계획의 task 절에 나오는 AC 가운데 `acs` 에 있는 것(`acs` 의 차례). `plan_text` 가 None 이면 `acs` 전부
  - `check_result(git, tip: str, team, job: str, name: str) -> Check`
  - `RECEIVED, NOT_RECEIVED, NOT_COUNTED, STALE = "받음", "없음", "세지 않음", "낡음"`
  - `receipt(git, main: str, tip: str, team, job: str, intent_text: str, stage: str, plan, reserved: list, outputs: list) -> tuple` — `(상태, 알림 줄 목록, 가장 새 결과 파일 이름 | None)`
  - 명령줄 `job_results.py check --roadmap <로드맵 레포 상대경로> --job <과제> --result <결과 파일 이름> [--branch <브랜치>] [--date <YYYY-MM-DD>]` — 종료 코드 0 통과 · 1 거절 · 2 사용법 · 3 검사 불가

`check_result` 가 보는 것(모두 모아 `problems` 에 한 줄씩 — 하나에서 멈추지 않는다):

1. `name` 이 결과 파일 이름 꼴이 아니다(막힘 파일을 주면 여기서 걸린다 — AC29).
2. 그 끝에 파일이 없다 · `parse_result` 의 사유.
3. 머리의 단계 · 계획 · 시도가 이름과 다르다.
4. 「끝」 줄이 없다(「아직 도는 중이다」) · 「끝」 줄의 커밋이 머리의 `head` 와 다르다.
5. `head` 가 없는 커밋이다 · `tip` 의 조상이 아니다. `bundle_at` · `job_at` 이 없는 커밋이다.
6. 같은 단계 · 같은 계획의 더 새 시도가 있다(`newest`).
7. 그 끝의 과제 폴더에 `design.md` 가 있으면 — 수용 기준 범위(`plan_scope` — 머리에 `plan` 이 있으면 그 계획 파일, 없으면 전부)로 `check_impl(설계문서 글, result.machine_text, only=범위)` 를 돌려 검사 불가 사유 · 보고에 없는 AC · 설계문서에 없는 AC 를 사유로 낸다. 「미룸」 · 「빠짐」 은 사유가 아니다(Q4). 설계문서에 수용 기준 절이 없으면 `unknown`.
8. `design.md` 가 없으면 — `산출물:` 줄이 하나도 없다 · 적힌 경로가 `head` 커밋에 없다.
9. 읽는 동안 `git.failures` 가 늘었으면 `unknown` 에 옮긴다.

`first` 는 통과면 `결과 대조: 통과 — <이름> · head <8자> · AC <n>개(구현됨 <a> · 미룸 <b> · 빠짐 <c>)`(설계 없는 과제는 괄호까지 대신 `산출물 <n>개`), 아니면 `결과 대조: 거절 <n>건 — <이름>`, 검사 불가면 `결과 대조: 검사 불가 — <이름>` 이다.

`receipt` 의 규칙(Q1 · Q6):

- `newest(결과 파일 이름들, stage, plan)` 이 None 이면 `(NOT_RECEIVED, [], None)`.
- `received(intent_text)` 가운데 그 단계 · 그 계획의 이름을 가진 줄만 본다. 꼴이 깨진 받음 줄이 있으면 알림(`받음 줄을 세지 않았다: 꼴이 깨졌다 — <줄>`)을 더한다. 맞는 줄이 없으면 `NOT_RECEIVED`.
- 맞는 줄 가운데 마지막 줄을 쓴다. 그 이름이 가장 새 시도가 아니면 `STALE` — `받은 뒤 바뀜: <받은 이름> — 더 새 시도 <이름> 이 있다`.
- `check_result` 가 통과하지 않거나 받음 줄의 커밋이 결과 파일의 `head` 와 다르면 `NOT_COUNTED` — `받음 줄을 세지 않았다: <이름> — <첫 사유>`.
- `git.touched(tip, [head, main], 볼 자리)` 에서 자기 과제 폴더의 다른 파일을 뺀 것이 비지 않으면 `STALE` — `받은 뒤 바뀜: <이름> — <파일 · 파일 …>`(다섯까지, 넘으면 `외 <n>개`). 볼 자리는 `reserved`(블록의 경로 예약 또는 단순 작업의 `paths`) · `outputs`(블록의 산출물) · 그 과제의 `design.md` · 과제 폴더(계획 파일을 고르려고)이고, 과제 폴더에서는 `design.md` · `plan_number` 가 읽는 이름 · `outputs` 에 든 경로만 남긴다. `touched` 가 None 이면 `NOT_COUNTED` — `받음 줄을 세지 않았다: <이름> — 받은 뒤의 변경을 읽지 못했다`.
- 그 밖에는 `(RECEIVED, [], 이름)`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_job_results.sh`(`fixtures/team_repo.sh` 를 source). 픽스처는 한 번 만든다 — `feature/tm-e1` 에서 `design.md`(수용 기준 `AC1` · `AC2` · `AC3` 과 머리 줄만 있는 `## 미룸` 표) · `plan-1.md`(task 절 하나에 `AC1 · AC2`) · `src/e1/a.txt` 를 커밋하고(`CODE`), `job sync` 로 만든 결과 파일에 `AC1: 구현됨 — src/e1/a.txt` · `AC2: 미룸 — 다음 계획` 을 더해 `--end "$CODE"` 로 끝내고 커밋 · push 한다(`GOOD`). 갈래마다 `GOOD` 에서 가른 브랜치 `v/<이름>` 에 결과 파일만 고쳐 커밋하고 `--branch v/<이름>` 으로 부른다. `jr <브랜치> <결과 파일 이름> [인자…]` 는 `(cd "$W" && python3 "$JRC" check --roadmap "$RM" --job E1 --branch "$1" --result "$2" --date 2026-11-20 …) > "$T/out.txt" 2>&1; echo $?` 다:

```bash
assert_eq "$(jr feature/tm-e1 implement-plan-1-1.md)" "0" "대조: 통과 rc 0"
assert_eq "$(sed -n 1p "$T/out.txt")" "결과 대조: 통과 — implement-plan-1-1.md · head ${CODE:0:8} · AC 2개(구현됨 1 · 미룸 1 · 빠짐 0)" "대조: 첫 줄(범위는 계획 1 의 AC 둘 — AC3 은 범위 밖)"
assert_contains "$(cat "$T/out.txt")" "- 결과 받음 · 2026-11-20 · 「implement-plan-1-1.md · $CODE · 결과 대조: 통과 — implement-plan-1-1.md · head ${CODE:0:8} · AC 2개(구현됨 1 · 미룸 1 · 빠짐 0)」" "대조: 리더가 적을 받음 줄을 낸다"
# 갈래 — variant <이름> <결과 파일을 고치는 명령> 뒤 reject <이름> <말> <라벨> 이 rc 1 과 말을 단언한다
#   no-end(끝 줄을 지운다 — 「끝 줄이 없다」) · end-differs(끝 줄의 커밋을 GOOD 으로 — 「head 와 다르다」) · no-head(머리를 지운다 — 「머리」)
#   head-elsewhere(head · 끝을 main 의 다른 브랜치 커밋으로 — 「과제 브랜치에 없다」) · bundle-ghost(bundle_at 을 "d" 40개로 — 「bundle_at」)
#   job-ghost(job_at 을 "e" 40개로 — 「job_at」) · ac-missing(AC2 줄을 지운다 — 「AC2」) · ac-unknown(AC9: 구현됨 줄을 더한다 — 「AC9」)
#   ac-shape(AC1 줄을 「AC1: 했다」 로 — 「보고 줄」) · renamed(파일을 implement-plan-1-2.md 로 옮기고 머리는 그대로 — 「이름과 다르다」)
#   newer(implement-plan-1-2.md 를 더한 뒤 implement-plan-1-1.md 를 대조 — 「더 새 시도」) · fenced(끝 줄을 펜스 안으로 옮긴다 — 「끝 줄이 없다」)
#   bom(파일 앞에 BOM — 「머리」) · crlf(줄 끝을 CRLF 로 — rc 0, 통과 그대로)
assert_eq "$(jr feature/tm-e1 BLOCKED.md)" "1" "AC29: 막힘 파일은 결과 대조의 대상이 아니다"
assert_contains "$(cat "$T/out.txt")" "결과 파일 이름 꼴이 아니다" "AC29: 그 사유"
# 계획 파일이 없는 사본(v/no-plan — plan-1.md 를 지운다): 범위가 AC 전부라 「AC3」 이 빠졌다고 거절
# 설계 없는 흐름 — feature/tm-e2 에 survey.md 와 implement-1.md(산출물: $TM/jobs/E2/survey.md) : rc 0 · 첫 줄 끝이 「산출물 1개」
#   산출물 줄 없음 → 1 「산출물 줄이 없다」 · 산출물: src/e2/none.md → 1 「head 커밋에 없다」
# 끝 — 로컬에만 있는 브랜치: rc 0 과 「아직 안 올라옴」 줄 · 갈라진 브랜치: rc 3 「갈라짐」 (Task 6 뒤에 초록 — 이 과제에서는 --branch 가 로컬 끝을 읽는 것까지)
# 사용법 — --result 없음 → 2 · team 형식이 아닌 로드맵 → 2 · 블록이 아닌 과제에 --branch 없음 → 2
# result_names · newest — python3 -c 로: 결과 폴더에 BLOCKED.md · .gitkeep · implement-plan-1-1.md · implement-plan-1-3.md · implement-plan-2-1.md · review-1.md 를 둔 커밋에서
#   names == 넷(막힘 파일 · .gitkeep 없음) · newest(names, "implement", 1) == "implement-plan-1-3.md" · newest(names, "implement", None) is None · newest(names, "review", None) == "review-1.md"
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_job_results.sh | tail -n 3`
Expected: `job_results.py` 가 없어 모든 `jr` 이 실패한다.

- [ ] **Step 3: `Git.names` · `Git.touched` 와 `job_results.py` 를 쓴다**

`job_results.py` 는 모듈 맨 위에서 `roadmap_status` · `team_status` 를 import 하지 않는다(그 둘이 이 모듈을 import 한다) — `main()` 안에서 `import roadmap_status` 로 `Git` 을 만들고 기본 브랜치의 로드맵을 읽어 블록의 브랜치(`--branch` 가 없으면 머리 `plan` 번째, 계획 번호가 없으면 첫째)를 고른다. 이 과제에서 `--branch` 의 끝은 로컬 ref, 없으면 origin ref 다(Task 6 이 `team_status.read_tip` 으로 바꾼다). `--date` 가 없으면 오늘 날짜다. `receipt` 의 단언은 Task 7 의 단계 테스트가 맡는다 — 이 과제는 함수를 쓰고 `python3 -c` 로 `RECEIVED` 한 갈래만 돌려 본다.

- [ ] **Step 4: 락의 목록을 고치고 통과를 확인한다 (T-d 의 이 과제 몫)**

`tests/test_roadmap_status.sh` 정적 락 줄에 `"$S/job_results.py"` 를 더하고 `CHECKED 11` → `CHECKED 12`, 라벨의 수 낱말을 「열두」 로.

Run:
```bash
chmod +x plugins/spec-distill/tests/test_job_results.sh && bash plugins/spec-distill/tests/test_job_results.sh | tail -n 1
bash plugins/spec-distill/tests/test_roadmap_status.sh | tail -n 1; bash plugins/spec-distill/tests/test_team_sync.sh | tail -n 1
python3 -m unittest plugins/spec-distill/tests/test_team_layout.py plugins/quality-gates/tests/test_utf8_explicit.py
```
Expected: 모두 통과(「끝 — 로컬에만 · 갈라진」 두 단언은 Task 6 에서 켠다 — 이 과제에서는 주석으로 남긴다).

- [ ] **Step 5: 커밋**

```bash
git add -- plugins/spec-distill/scripts/job_results.py plugins/spec-distill/scripts/roadmap_status.py plugins/spec-distill/tests/test_job_results.sh plugins/spec-distill/tests/test_roadmap_status.sh
git ls-files -s plugins/spec-distill/tests/test_job_results.sh   # 100755
git commit -m "feat(spec-distill): team 형식의 결과 대조(job_results.py check)" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

---

### Task 6: 브랜치 끝 읽기 — `team_status.read_tip` (AC30)

**Files:**
- Create: `plugins/spec-distill/scripts/team_status.py`
- Modify: `plugins/spec-distill/scripts/branch_tip.py`(예약 밖 — Q9) · `job_results.py`(`check` 의 끝 고르기)
- Test: `plugins/spec-distill/tests/test_team_status.sh`(새 — 이 과제는 「끝:」 묶음) · `test_job_results.sh` · `test_roadmap_status.sh`(T-d 의 마지막 몫)

**Interfaces:**
- Consumes: `branch_tip.tip(root, branch) -> (커밋 | None, 알릴 줄 | None)` · `branch_tip.TipError`, `roadmap_status.Git.commit`.
- Produces(`team_status`):
  - `UNPUSHED = "아직 안 올라옴"` · `SPLIT = "갈라짐"`
  - `read_tip(git, branch: str) -> tuple` — `(읽을 커밋 | None, 알림 줄 | None, 갈라짐 사유 | None)`. 끝 고르기는 `branch_tip.tip(git.cwd, branch)` 가 한다. 그 뒤 로컬 ref 와 origin ref 를 읽어, 고른 커밋이 로컬 끝이고 origin 끝과 다르면(origin 이 없거나 뒤다) 알림 `아직 안 올라옴 — <브랜치> 의 로컬 끝 <8자> 이 origin 에 없다(로컬을 읽었다)` 를 낸다. `TipError` 면 `(None, None, "갈라짐 — <그 예외의 글>")`. 둘 다 없으면 `(None, None, None)`.

- [ ] **Step 0: Q9 가 받아들여졌는지 확인한다**

리더가 넘긴 답에 Q9(예약 밖 파일 `branch_tip.py` 고치기)가 「받아들임」 이 아니면 이 과제를 시작하지 않고 멈춰 보고한다 — 다른 길(둘째 구현)은 AC30 의 글자를 고쳐야 해서 계획을 고친 뒤에 간다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_team_status.sh`(`fixtures/team_repo.sh` 를 source). 「끝:」 묶음 — `tipof <브랜치>` 는 `python3 -c` 로 `team_status.read_tip(roadmap_status.Git(W), 브랜치)` 의 세 값을 `<커밋 8자 또는 None>|<알림 유무 yes/no>|<갈라짐 유무 yes/no>` 로 낸다. `U="$T/other"` 는 같은 origin 의 둘째 clone 이다:

```bash
g checkout -q -b t/same main && put t-same.txt a && g commit -qm same && g push -q origin t/same
assert_eq "$(tipof t/same)" "$(g rev-parse --short=8 t/same)|no|no" "끝: 같음 — 그 커밋 · 알림 없음"
put t-same.txt b && g commit -qm ahead
assert_eq "$(tipof t/same)" "$(g rev-parse --short=8 t/same)|yes|no" "끝: 로컬이 앞섬 — 로컬 · 「아직 안 올라옴」"
assert_contains "$(tipnote t/same)" "아직 안 올라옴 — t/same 의 로컬 끝" "끝: 알림 글"
g checkout -q -b t/behind main && put t-behind.txt a && g commit -qm one && g push -q origin t/behind
(둘째 clone U 에서 t/behind 에 커밋 하나를 더해 push) && g fetch -q origin
assert_eq "$(tipof t/behind)" "$(g rev-parse --short=8 origin/t/behind)|no|no" "끝: origin 이 앞섬 — origin · 알림 없음"
put t-behind.txt c && g commit -qm fork
assert_eq "$(tipof t/behind)" "None|no|yes" "끝: 갈라짐 — 읽지 않는다"
g checkout -q -b t/local main && put t-local.txt a && g commit -qm local
assert_eq "$(tipof t/local)" "$(g rev-parse --short=8 t/local)|yes|no" "끝: 로컬에만 있는 브랜치 — 「아직 안 올라옴」(Q3)"
g checkout -q main && g branch -q -D t/same && g fetch -q origin
assert_eq "$(tipof t/same)" "$(g rev-parse --short=8 origin/t/same)|no|no" "끝: origin 에만 있는 브랜치 — origin · 알림 없음"
assert_eq "$(tipof t/none)" "None|no|no" "끝: 둘 다 없다"
# AC30 — 둘째 구현이 없다: read_tip 의 몸에 branch_tip.tip( 이 있고 is_ancestor · merge-base 글자가 없다(inspect.getsource)
# 양성 대조 — branch_tip.tip 을 늘 ("f" * 40, None) 을 내는 것으로 바꿔 끼우면 read_tip 의 첫 값이 그 값이다
```

`test_job_results.sh` 의 주석으로 남긴 둘(로컬에만 있는 브랜치 rc 0 과 「아직 안 올라옴」 줄 · 갈라진 브랜치 rc 3 「갈라짐」)을 단언으로 켠다.

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_team_status.sh | tail -n 3`
Expected: `No module named 'team_status'`.

- [ ] **Step 3: `branch_tip.py` 를 읽기 전용 락의 꼴로 고친다 (Q9 — 동작 불변)**

`import shutil` 과 `GIT = shutil.which("git") or "git"` 를 지우고, `GIT_ALLOWED = frozenset({"rev-parse", "merge-base"})` 를 두며, `_git` 은 첫 인자가 그 집합 밖이면 `ValueError`, 안이면 `subprocess.run(["git", *args], …)` 로 부른다(나머지 인자는 그대로). `tip` · `resolve` · `_is_ancestor` · `TipError` 의 몸과 글자는 고치지 않는다.

- [ ] **Step 4: `team_status.py` 를 쓰고 `job_results.py check` 가 그것으로 끝을 고르게 한다**

`check` 는 `read_tip` 의 알림을 첫 줄 뒤에 한 줄로 내고, 갈라짐이면 사유를 내고 3 으로 끝난다. `job_results.py` 는 `team_status` 를 `main()` 안에서 import 한다.

- [ ] **Step 5: 락의 목록을 고치고 통과를 확인한다 (T-d 의 마지막 몫)**

`tests/test_roadmap_status.sh` 정적 락 줄에 `"$S/team_status.py"` · `"$S/branch_tip.py"` 를 더하고 `CHECKED 12` → `CHECKED 14`, 라벨의 수 낱말을 「열네」 로. 양성 대조 하나를 더한다 — `branch_tip.py` 사본의 `["git", *args]` 를 `[GIT, *args]` 로 되돌린 파일에서 정적 검사가 「git 이 아닌 subprocess」 를 낸다(그 파일이 실제로 검사받는다).

Run:
```bash
chmod +x plugins/spec-distill/tests/test_team_status.sh && bash plugins/spec-distill/tests/test_team_status.sh | tail -n 1
bash plugins/spec-distill/tests/test_job_results.sh | tail -n 1; bash plugins/spec-distill/tests/test_roadmap_status.sh | tail -n 1
bash plugins/spec-distill/tests/test_merge_check.sh | tail -n 1; python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py 2>&1 | tail -n 3
```
Expected: 모두 통과 — `test_merge_check.sh` 와 `test_conductor_ledger.py`(통합 리뷰 묶음의 끝 고르기)는 고치지 않은 채 초록이다. 빨개지면 `branch_tip.py` 를 되돌리고 멈춰 보고한다.

- [ ] **Step 6: 커밋**

```bash
git add -- plugins/spec-distill/scripts/team_status.py plugins/spec-distill/scripts/branch_tip.py plugins/spec-distill/scripts/job_results.py plugins/spec-distill/tests/test_team_status.sh plugins/spec-distill/tests/test_job_results.sh plugins/spec-distill/tests/test_roadmap_status.sh
git ls-files -s plugins/spec-distill/tests/test_team_status.sh   # 100755
git commit -m "feat(spec-distill): team 형식의 브랜치 끝 읽기 — 끝 고르기는 branch_tip 하나" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

---

### Task 7: team 형식의 단계 계산 — 단계 표 · 진행 숫자 · 받음 · 막힘 (AC9 · AC10 · AC27 · AC29 · AC12 의 team 쪽 · AC13)

**Files:**
- Modify: `plugins/spec-distill/scripts/team_status.py`(`Reader`) · `roadmap_status.py`(`compute` · `build` · 단계 글자) · `roadmap_model.py`(`approval_in`)
- Test: `plugins/spec-distill/tests/test_team_status.sh`(「단계:」 · 「받음:」 묶음) · `test_roadmap_model.py` · `test_team_status_stub.sh`(T-a) · `test_roadmap_status.sh`(T-f 의 남은 몫)

**Interfaces:**
- Consumes: `team_status.read_tip`, `job_results.receipt` · `result_names` · `newest`, `team_files.intent_sections` · `parse_result` · `progress_of` · `parse_blocked`, `team_layout.Team`.
- Produces(`roadmap_model`): `approval_in(lines: list)` — `approval_date` 의 줄 읽기 몸을 떼어 낸 것(반환 · 예외는 같다). `approval_date(doc_text)` 는 `approval_in(section_lines(doc_text, RECORD_HEADING) or [])` 를 부른다 — 동작 불변.
- Produces(`team_status`):
  - `DESIGN_FLOW, PLAIN_FLOW = "설계 흐름", "설계 없는 흐름"`
  - `class Reader` — `__init__(self, git, main, team, read_default)`(`read_default(path)` 는 로드맵을 읽은 사본에서 글을 읽는 함수 — 과제 브랜치가 없는 블록의 과제 폴더가 여기서 읽힌다)
  - `Reader.read(self, tree, path)` — `tree` 가 None 이면 `read_default`, 아니면 `git.blob(tree, path)`
  - `Reader.flow(self, block) -> str` — 블록에 `산출물` 칸이 있으면 `PLAIN_FLOW`, 아니면 `DESIGN_FLOW`(Q5)
  - `Reader.specs(self, tree, block) -> list` — `PLAIN_FLOW` 면 `산출물` 칸의 경로 가운데 그 트리에 있는 것, `DESIGN_FLOW` 면 그 과제의 `design.md` 가 있으면 그 경로 하나(결정 블록은 `[]`)
  - `Reader.approved(self, tree, block) -> tuple` — `(spec 승인 날짜 | None, 읽기 불가 사유 | None)`. INTENT.md 결정 기록 칸의 줄을 `roadmap_model.approval_in` 으로 읽는다
  - `Reader.planned(self, tree, block) -> bool` — 그 트리의 과제 폴더에 계획 파일이 하나라도 있다
  - `Reader.progress(self, tip: str, block: dict, plan: int) -> tuple` — `(단계, 근거, 설계문서들, 계획들)`. `block["approved"]` · `block["progress"]` 를 채우고 알림을 `block["notes"]` 에 더한다
- `roadmap_status.compute(…, epic_pr_rows=None, team=None)` — `team` 은 `Reader` 또는 None. `build` 는 team 로드맵이면 `Reader` 를 만들어 넘기고, 보고에 `layout`, 결정 블록이 아닌 블록에 `progress`(구현 중이 아니면 None) 와 `job`(`{"intent": <INTENT.md 경로>, "plan": <지금 계획 번호 | None>, "result": <그 계획의 가장 새 implement 결과 파일 이름 | None>}`)을 싣는다. 옛 형식의 보고에는 이 칸들이 없다(Q14).
- `TASK_STATUS` 에 `"진행 중": "in_progress"` · `"결과 받음": "in_progress"` 를 더한다(Q12).

단계 표(설계 §10 — `plan` 은 그 브랜치가 블록 `브랜치:` 의 몇 번째인가, 1 부터):

| 흐름 | 조건(위에서부터 처음 맞는 것) | 단계 | 근거 글 |
|---|---|---|---|
| 둘 다 | INTENT.md 를 그 끝에서 읽지 못했다 | 알 수 없음 | `<INTENT.md 경로> 를 읽지 못했다` |
| 설계 | 결정 기록을 읽지 못했다(승인 줄 꼴) | 설계 중 | `결정 기록 읽기 불가 — <사유>` |
| 설계 | `spec 승인` 줄 없음 | 설계 중 | `브랜치 있음 · <design.md 이름> 없음` 또는 `<design.md 이름> 있음 · spec 승인 줄 없음` |
| 설계 | 그 계획의 `implement` 결과 파일 없음 | 계획 | `spec 승인됨(<날짜>) · <계획 파일 이름> 없음 · implement 결과 파일 없음`(계획 파일이 있으면 「없음」 자리가 「있음」) |
| 설계 | 받음 상태가 `RECEIVED` | 구현 끝 | `결과 받음 줄 있음: <결과 파일 이름>` |
| 설계 | 그 밖 | 구현 중 | `implement 결과 파일 있음: <결과 파일 이름>` |
| 설계 없음 | 받음 상태가 `RECEIVED`(계획 번호 없는 `implement` 결과) | 결과 받음 | `결과 받음 줄 있음: <결과 파일 이름>` |
| 설계 없음 | 그 밖 | 진행 중 | `브랜치 있음` |

- 받음 상태는 `job_results.receipt(git, main, tip, team, job, INTENT.md 글, "implement", 계획 번호, 블록의 경로 예약, 블록의 산출물 경로)` 다. 돌려받은 알림 줄을 블록의 알림에 더한다.
- 「결과 있음 · 받음 없음」 — 가장 새 `implement` 결과 파일이 있고 받음 상태가 `NOT_RECEIVED` 면 `결과 있음 · 받음 없음: <이름>(도는 중 — 끝 줄 없음)` 또는 `…(대조를 기다린다)` 를 더한다(Q11). `design` · `plan` 결과 파일에는 내지 않는다.
- 진행 — 단계가 「구현 중」 이면 `progress_of` 로 `block["progress"]` 를 채운다: `{"done": n, "total": m}` 또는 `{"done": None, "total": None, "why": <사유>}`. 사유가 「진행 줄 깨짐」 이면 `진행 줄을 믿지 않았다: <이름> — <그 줄>` 을 알림에 더한다. 단계 글자에는 숫자를 넣지 않는다.
- 막힘 — 그 끝의 결과 폴더에 막힘 파일이 있으면 `막힘: <단계>[ plan <n>] 시도 <a> — <경로>` 를, 읽지 못하면 `막힘 파일을 읽지 못했다: <경로> — <첫 사유>` 를 더한다. 단계는 바꾸지 않는다.
- 이 알림들은 모두 블록의 `notes`(정보)에 간다 — 종료 코드를 바꾸지 않는다.

`compute` 의 갈림(옛 형식의 줄은 `team` 이 None 일 때 지금 그대로 돈다):

1. `find_specs(git, <트리>, block, …)` 를 부르는 다섯 자리(`started` · `doc_added` · 머지됨 · 일부 머지 · 대조 앞)를 한 도우미로 모은다 — `team` 이면 `team.specs(<트리>, block)`.
2. `started` — `team` 이면 `team.approved(main, block)` 의 날짜가 있거나 `team.planned(main, block)`.
3. 진행 중인 브랜치를 고른 뒤 — `team` 이면 `read_tip(git, 브랜치)` 로 끝을 다시 고른다. 갈라짐이면 그 블록을 단계 「알 수 없음」 · 사유 `갈라짐 — …` 으로 두고 그 블록의 나머지 계산을 건너뛴다(Q10). 알림이 있으면 블록 알림에 더한다. 고른 커밋이 블록의 `tip` 이다.
4. `progress(…)` 를 부르는 자리 — `team` 이면 `team.progress(tip, block, 브랜치의 차례)`.

`build` 의 갈림 — 지금 `team_layout.STAGE_PENDING` 을 내고 돌아가는 자리에서: `team_layout.team_from_roadmap(settings["roadmaps_dir"], rel)` 이 ValueError 면 형식 깨짐(`team 로드맵의 자리가 아니다 — <사유>`)으로 돌아가고, 아니면 `Reader(git, main, team, src.read)` 를 만들어 옛 형식과 같은 길(`read_pr_cache` → `compute` → …)로 내려간다.

- [ ] **Step 1: 옛 형식 출력을 먼저 못 박는다 (코드를 고치기 전)**

`BASE` 의 스크립트 사본을 TMPDIR 에 풀어 둔다 — `git archive "$BASE" plugins/spec-distill/scripts plugins/spec-distill/.claude-plugin | tar -x -C "$TMPDIR/base"`. Task 16 Step 5 가 이 사본과 지금 스크립트의 옛 형식 출력을 견준다. 이 과제에서는 `bash plugins/spec-distill/tests/test_roadmap_status.sh | tail -n 1` 의 통과 수를 원장에 적는다(고친 뒤에도 같은 수여야 한다 — 락 목록 단언은 수가 그대로다).

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`test_roadmap_model.py` 에:

```python
    def test_approval_in_is_the_line_reader(self):   # 계획 2 — INTENT.md 결정 기록이 같은 규칙으로 읽힌다
        lines = ["- 계획 검토 · 2026-11-19 · 글", "- spec 승인 · 2026-11-20 · 「이대로 승인 (권장)」", "- spec 승인 · 2026-11-18 · 「먼저」"]
        self.assertEqual(M.approval_in(lines), "2026-11-20")
        self.assertIsNone(M.approval_in(["- 결정 · 2026-11-20 · spec 승인 대기"]))
        self.assertRaises(M.FormatError, M.approval_in, ["- spec 승인 · 11/20 · 「글」"])
        doc = "# 문서\n\n## 지휘 기록\n\n" + "\n".join(lines) + "\n"
        self.assertEqual(M.approval_date(doc), M.approval_in(lines))
```

`test_team_status.sh` 에 「단계:」 · 「받음:」 묶음을 더한다. 도우미 — `st <번호>`(그 블록의 단계) · `why <번호>`(근거) · `notes <번호>`(알림을 ` | ` 로 이은 글) · `prog <번호>`(`progress` 칸) · `rc`(마지막 `status` 의 종료 코드) · `step <메시지>`(`g add -A && g commit -qm … && g push -q origin HEAD` 뒤 `status "$T/s.json"`). 걸음마다 근거 하나만 바꾼다:

```bash
status "$T/s.json" >/dev/null
assert_eq "$(js "$T/s.json" "[(b['id'], b['stage']) for b in r['blocks']]")" "[('P1', '준비'), ('E1', '준비'), ('E2', '준비'), ('E3', '대기')]" "단계: create --layout team 이 만든 로드맵 — 대기 · 준비"
assert_eq "$(js "$T/s.json" "(r['exit'], r['layout'], r['unknown_reasons'], r['format_errors'])")" "(0, 'team', [], [])" "AC9: 종료 코드 0 · 검사 불가 없음"
# 커밋 전의 새 팀도 읽힌다 — create --layout team 으로 tm2 를 만들고 커밋하지 않은 채 --roadmap-file 로: rc 0
g checkout -q -b feature/tm-e1 main && put src/e1/a.txt a && step "코드 하나"
assert_eq "$(st E1) · $(why E1)" "설계 중 · 브랜치 있음 · design.md 없음" "단계: 브랜치만 — 설계 중"
put "$TM/jobs/E1/design.md" "$DESIGN" && step "설계문서"
assert_eq "$(st E1) · $(why E1)" "설계 중 · design.md 있음 · spec 승인 줄 없음" "단계: 설계문서가 있어도 승인 줄이 없으면 설계 중"
decide E1 "spec 승인 · 2026-11-20 · 「이대로 승인 (권장)」" && step "승인"
assert_eq "$(st E1) · $(why E1)" "계획 · spec 승인됨(2026-11-20) · plan-1.md 없음 · implement 결과 파일 없음" "단계: 승인 줄 — 계획"
put "$TM/jobs/E1/plan-1.md" "$PLAN1" && step "계획 파일"
assert_eq "$(st E1)" "계획" "AC9: 계획 파일만 바꾼 커밋으로는 구현 중이 아니다"
decide E1 "계획 검토 · 2026-11-21 · 설계에 없던 결정 없음" && step "결정 기록 한 줄"
assert_eq "$(st E1)" "계획" "AC9: 결정 기록만 바꾼 커밋으로는 구현 중이 아니다"
sync E1 implement-plan-1-1.md --role worker --bundle-at "$(g rev-parse origin/main)" --job-at "$(g rev-parse HEAD)" >/dev/null && step "결과 파일 시작"
assert_eq "$(st E1) · $(why E1)" "구현 중 · implement 결과 파일 있음: implement-plan-1-1.md" "단계: implement 결과 파일 — 구현 중"
assert_eq "$(prog E1)" "{'done': None, 'total': None, 'why': '진행 줄 없음'}" "AC27: Task 줄이 없으면 숫자 없이 「진행 줄 없음」"
assert_contains "$(notes E1)" "결과 있음 · 받음 없음: implement-plan-1-1.md(도는 중 — 끝 줄 없음)" "AC10: 결과 있음 · 받음 없음(도는 중)"
sync E1 implement-plan-1-1.md --ledger "$T/ledger.md" --plan-file "$W/$TM/jobs/E1/plan-1.md" >/dev/null && step "Task 둘"
assert_eq "$(st E1) · $(prog E1)" "구현 중 · {'done': 2, 'total': 3}" "AC27: 단계 글자는 그대로이고 진행은 따로 된 칸"
# 깨진 숫자: 결과 파일에 「Task 9/3: 끝 — x」 를 손으로 더한 커밋 → prog 가 why 「진행 줄 깨짐 — Task 9/3: 끝 — x」 · notes 에 「진행 줄을 믿지 않았다」 → 그 줄을 지운 커밋으로 되돌린다
# 막힘(AC29): BLOCKED.md(머리 implement · plan 1 · attempt 1, 본문 두 칸) 커밋 → st 그대로 「구현 중」 · notes 에 「막힘: implement plan 1 시도 1 — $TM/jobs/E1/results/BLOCKED.md」
#   · job.result 는 그대로 implement-plan-1-1.md(막힘 파일은 결과 파일로 세지 않는다) → 본문 한 칸을 지운 커밋 → 「막힘 파일을 읽지 못했다」 → 파일을 지운 커밋 → notes 에 「막힘」 이 없다
# 끝남: 코드 커밋(CODE) 뒤 AC 줄 둘을 더하고 sync --end "$CODE" → notes 에 「결과 있음 · 받음 없음: implement-plan-1-1.md(대조를 기다린다)」 · st 는 「구현 중」
LINE="$(cd "$W" && python3 "$JRC" check --roadmap "$RM" --job E1 --result implement-plan-1-1.md --date 2026-11-22 | grep '^- 결과 받음 · ')"
decide E1 "$LINE" && step "받음 줄"
assert_eq "$(st E1) · $(why E1) · $(prog E1)" "구현 끝 · 결과 받음 줄 있음: implement-plan-1-1.md · None" "단계: 대조를 통과한 받음 줄 — 구현 끝"
assert_not_contains "$(notes E1)" "받음 없음" "받음: 받은 뒤에는 받음 없음 알림이 없다"
RECEIVED_AT="$(g rev-parse HEAD)"
# 받음: 갈래마다 RECEIVED_AT 에서 가른 브랜치를 feature/tm-e1 로 삼지 않고, feature/tm-e1 에 커밋을 하나 더하고 단언한 뒤 `g reset -q --hard "$RECEIVED_AT" && g push -q -f origin HEAD` 로 되돌린다(임시 레포라 된다)
#   고칠 자리(src/e1/b.txt) 커밋 → 「구현 중」 · notes 「받은 뒤 바뀜: implement-plan-1-1.md — src/e1/b.txt」
#   design.md 를 고친 커밋 → 받은 뒤 바뀜 · plan-1.md 를 고친 커밋 → 받은 뒤 바뀜
#   INTENT.md 에 「결정」 줄만 더한 커밋 → 「구현 끝」 그대로 · 결과 폴더에 review-1.md 만 더한 커밋 → 「구현 끝」 그대로
#   main 에 src/e1/z.txt 를 더해 push 한 뒤 feature/tm-e1 에 main 을 merge 한 커밋 → 「구현 끝」 그대로(Review Focus 4 — 합쳐 들어온 변경은 세지 않는다)
#   implement-plan-1-2.md 를 시작한 커밋 → 「구현 중」 · notes 「받은 뒤 바뀜: implement-plan-1-1.md — 더 새 시도 implement-plan-1-2.md 가 있다」
#   받음 줄의 커밋을 GOOD 이 아닌 다른 실재 커밋으로 바꿔 쓴 사본 → 「구현 중」 · notes 「받음 줄을 세지 않았다: implement-plan-1-1.md — 」
#   꼴이 깨진 받음 줄(「- 결과 받음 · 2026-11-22 · 받았다」)만 있는 사본 → 「구현 중」 · notes 「꼴이 깨졌다」
# 끝: feature/tm-e1 에 push 하지 않은 커밋 하나 → notes 에 「아직 안 올라옴」 · 단계는 로컬 끝으로 계산 / 둘째 clone 이 다른 커밋을 push 해 갈라지면 → st E1 「알 수 없음」 · why 가 「갈라짐 — 」 로 시작 · rc 3 · st E2 는 「준비」 그대로
# 둘째 브랜치(계획 2): feature/tm-e1 을 main 에 merge 커밋으로 합쳐 push → st E1 「일부 머지 1/2」 → feature/tm-e1b 를 main 에서 갈라 커밋 하나 →
#   why 에 「feature/tm-e1b — 계획 · spec 승인됨(2026-11-20) · plan-2.md 없음」 → implement-plan-2-1.md 시작 → why 에 「구현 중」 · job.plan == 2 · job.result == implement-plan-2-1.md
# 설계 없는 흐름: feature/tm-e2 에 커밋 하나 → st E2 「진행 중」 · why 「브랜치 있음」 · task_status in_progress → survey.md 와 implement-1.md(산출물 줄 · 끝) → 받음 줄 → 「결과 받음」
# 못 읽는 것: INTENT.md 를 지운 브랜치 → 「알 수 없음」 / 「- spec 승인 · 11/20 · 「글」」 줄 → 「설계 중」 · why 「결정 기록 읽기 불가 — 」
# Review Focus 5: `g remote set-head origin -d` 뒤 --roadmap-file 로 → rc 3 · 블록이 모두 「알 수 없음」 · 죽지 않는다(표준 오류에 Traceback 없음) → `g remote set-head origin main` 으로 되돌린다
```

주석으로 적은 걸음도 모두 단언으로 옮긴다. `DESIGN` 은 수용 기준 셋과 머리 줄만 있는 `## 미룸` 표, `PLAN1` 은 task 절 셋(하나에 `AC1 · AC2`)이다.

- [ ] **Step 3: `test_team_status_stub.sh` 의 team 단언을 고친다 (T-a)**

「team: 번호 대조까지 하고 멈춘다」 묶음의 단언을 바꾼다 — 종료 코드 `3` → `0`, 사유에 「이 판은」 이 **없다**, 번호 네 목록은 그대로 빈 목록, 블록 단계 `['알 수 없음']` → `['준비']`, 블록 사유 → `의존 완료 · 브랜치 없음`(ids 는 그대로). 「D2 를 뺀다」 묶음의 종료 코드 단언은 `3` → `1`(미배정 번호는 경고다). 「번호 파일이 없으면」 · 「모르는 layout」 · 「옛 형식」 묶음은 고치지 않는다. 옛 형식 묶음의 단언은 그대로 둔다(「이 판은 …」 부재 단언도 — 그 글이 코드에서 사라져도 참이다). 파일 머리 주석의 설명은 고친다. `D="docs/superpowers/roadmaps/t1"` 은 해결자에서 읽는다 — `RD="$(cd "$W" && python3 "$S/repo_defaults.py" get roadmaps_dir)"; D="${RD}t1"`(잔여).

- [ ] **Step 4: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_team_status.sh | grep -c '✗'; bash plugins/spec-distill/tests/test_team_status_stub.sh | tail -n 1`
Expected: 「단계:」 단언들이 실패한다(지금은 모든 블록이 「알 수 없음」 이다).

- [ ] **Step 5: `approval_in` · `Reader` · `compute` · `build` 를 쓴다**

`roadmap_status.py` 는 `import team_status` 를 맨 위에 더한다. 옛 형식의 줄은 옮기거나 다시 쓰지 않는다 — 갈림은 `if team` 한 줄씩이다. `build` 의 블록 사전에 team 일 때만 칸을 더한다(옛 형식의 키 차례와 수가 그대로다).

- [ ] **Step 6: 사본 목록을 고치고 통과와 회귀를 확인한다 (T-f 의 남은 몫)**

`tests/test_roadmap_status.sh` 의 사본 줄 둘에 `"$S/team_status.py" "$S/job_results.py" "$S/team_files.py" "$S/branch_tip.py"` 를 더한다.

Run:
```bash
bash plugins/spec-distill/tests/test_team_status.sh | tail -n 1; bash plugins/spec-distill/tests/test_team_status_stub.sh | tail -n 1
bash plugins/spec-distill/tests/test_roadmap_status.sh | tail -n 1; bash plugins/spec-distill/tests/test_control_plane.sh | tail -n 1; bash plugins/spec-distill/tests/test_default_branch.sh | tail -n 1
python3 -m unittest plugins/spec-distill/tests/test_roadmap_model.py plugins/spec-distill/tests/test_roadmap_approval.py plugins/spec-distill/tests/test_roadmap_status_merge_base.py plugins/spec-distill/tests/test_control_plane.py
```
Expected: 모두 통과. `test_roadmap_status.sh` 의 통과 수는 Step 1 에서 적은 수와 같다. `test_team_write.sh` 의 「team update: 머지 여부 알림」 둘은 이 과제 뒤에 빨개진다 — Task 14 가 뒤집는다(그 사이에는 그 둘만 빨갛다는 것을 원장에 적는다).

- [ ] **Step 7: 커밋**

```bash
git add -- plugins/spec-distill/scripts/team_status.py plugins/spec-distill/scripts/roadmap_status.py plugins/spec-distill/scripts/roadmap_model.py plugins/spec-distill/tests/test_team_status.sh plugins/spec-distill/tests/test_team_status_stub.sh plugins/spec-distill/tests/test_roadmap_model.py plugins/spec-distill/tests/test_roadmap_status.sh
git commit -m "feat(spec-distill): team 형식의 단계를 과제 폴더와 받음 줄로 계산한다" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

---

### Task 8: 알림과 읽는 자리 — 예약 밖 변경 · INTENT.md 어긋남 · 넘김 · 판정 · 과제 폴더 안 산출물 (AC11 · AC28 · AC9 의 조사 흐름)

**Files:**
- Modify: `plugins/spec-distill/scripts/team_status.py` · `roadmap_status.py` · `roadmap_model.py`(`handoff_rows`) · `plugins/spec-distill/templates/team/role-worker.md` · `role-writer.md`
- Test: `plugins/spec-distill/tests/test_team_status.sh`(「알림:」 묶음) · `test_team_files.py`

**Interfaces:**
- Consumes: `team_files.intent_drift` · `scope_line` · `decision_lines` · `parse_result`, `job_results.result_names`.
- Produces(`team_status`):
  - `outside(team, block: dict, blocks: list, changed: list, shared_names) -> list` — 그 브랜치가 바꾼 파일(`changed`) 가운데 공유 파일 · 그 블록의 경로 예약 · 그 과제 폴더 아래 · 다른 블록이 예약한 파일을 뺀 것(정렬)
  - `Reader.drift(self, tree, block) -> list` — 알림 줄들. INTENT.md 를 읽지 못하면 `<경로> 를 읽지 못했다` 한 줄, 읽으면 `team_files.intent_drift` 의 줄마다 `INTENT.md 가 로드맵 블록과 다르다: <번호> — <그 줄>`
  - `Reader.record_text(self, tree, block) -> str` — 그 과제 INTENT.md 결정 기록 칸의 줄들(넘김 확인 줄을 읽는 글). 읽지 못하면 `FormatError`
  - `Reader.rulings(self, tree, block) -> list` — 그 과제 결과 파일들(이름 순)의 `Ruling:` 줄을 `- ` 를 붙여 이은 것. 결과 파일이 없으면 `[]`
- `roadmap_model.handoff_rows(givers, stages, records, record_label=None)` — `record_label` 이 있으면 확인됨의 근거 글이 `<받는 에픽> <record_label>` 이다. 없으면 지금 글 그대로.
- `compute` 의 마지막 「경로 예약 위반」 고리에서 `team` 이면 같은 `changed` 목록으로 `outside(…)` 를 불러, 비지 않으면 `예약 밖 변경: <파일 · 파일 …>` 한 줄을 그 블록 알림에 더한다. 「경로 예약 위반」 줄은 지금 그대로 나온다. `team` 이면 블록마다(결정 블록 빼고) `drift` 의 줄도 더한다 — 읽는 트리는 블록의 `tip`, 없으면 로드맵을 읽은 사본이다.
- `build` 의 지휘 기록 · 판정 읽기 — `team` 이면 `_read_sections` 대신 `record_text` · `rulings` 를 쓰고(읽지 못하면 지금처럼 그 블록의 경고와 검사 불가 사유로), `handoff_rows(…, record_label=<INTENT.md 이름> + " 의 결정 기록")` 을 부른다.
- 역할 문서 틀 둘(`role-worker.md` · `role-writer.md`)의 「할 일」 끝에 한 줄: `- 결과 파일에 테스트 출력을 옮겨 싣지 않고 커밋과 경로로 가리킨다.`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_team_files.py` 의 `Templates` 에:

```python
    def test_results_point_instead_of_copying(self):   # AC28
        line = "- 결과 파일에 테스트 출력을 옮겨 싣지 않고 커밋과 경로로 가리킨다.\n"
        for role in ("worker", "writer"):
            text = F.role_template(role).read_text(encoding="utf-8")
            self.assertIn(line, text.split("## 하지 않을 일")[0], role)
        for role in L.ROLES:   # 어느 틀도 테스트 출력을 실으라고 하지 않는다
            for row in F.role_template(role).read_text(encoding="utf-8").splitlines():
                if "테스트 출력" in row:
                    self.assertIn("싣지 않", row, (role, row))
```

`test_team_status.sh` 에 「알림:」 묶음(Task 7 의 `feature/tm-e1` 가 「구현 끝」 인 자리에서 잇는다 — `RECEIVED_AT` 으로 되돌린 뒤):

```bash
before_rc="$(status "$T/n0.json")"
assert_not_contains "$(notes E1)" "예약 밖 변경" "알림: 고칠 자리와 과제 폴더만 바꾼 브랜치에는 예약 밖 변경이 없다"
put docs/free.md x && put README.md y && put src/e3/steal.txt z && put "$TM/RULES.md" "# RULES" && step "예약 밖 파일들"
OUTLINE="$(js "$T/s.json" "[n for b in r['blocks'] if b['id']=='E1' for n in b['notes'] if n.startswith('예약 밖 변경: ')][0]")"
assert_contains "$OUTLINE" "docs/free.md" "AC11: 아무도 예약하지 않은 파일이 이름과 함께 나온다"
assert_contains "$OUTLINE" "$TM/RULES.md" "AC11: 팀 폴더의 다른 파일도 예약 밖 변경이다(Q13)"
assert_not_contains "$OUTLINE" "README.md" "AC11: 공유 파일은 뺀다"
assert_not_contains "$OUTLINE" "src/e3/steal.txt" "AC11: 다른 과제가 예약한 파일은 예약 밖 변경이 아니다"
assert_not_contains "$OUTLINE" "src/e1/" "AC11: 자기 고칠 자리는 예약 밖 변경이 아니다"
assert_not_contains "$OUTLINE" "$TM/jobs/E1/" "AC11: 자기 과제 폴더는 예약 밖 변경이 아니다"
assert_contains "$(notes E1)" "경로 예약 위반: src/e3/steal.txt 은 E3 만 예약했다" "AC11: 경로 예약 위반 알림은 그대로다"
assert_eq "$(rc)" "$before_rc" "AC11: 종료 코드는 그대로다"
# 어긋남(AC28): 작업 폴더의 E1 INTENT.md 목표 칸 한 글자를 고친 커밋 → notes 에 「INTENT.md 가 로드맵 블록과 다르다: E1 — 목표 칸이 로드맵의 의도 · 범위와 다르다」 · rc 그대로
#   하지 않을 것 칸을 고친 커밋 → 「하지 않을 것 칸이」 · 브랜치가 없는 E3 의 INTENT.md 를 main 에서 고쳐 push → E3 의 notes 에 같은 알림(기본 브랜치에서 읽는다)
#   고치지 않은 E2 에는 알림이 없다(양의 짝)
# 넘김: E1 의 design.md `## 미룸` 표에 「넘길 일 | 이유 | E3」 한 행 → r['handoffs'] 에 giver E1 · receiver E3 · state 「열림」
#   → E3 의 INTENT.md(main)에 `python3 -c` 로 conductor_state.confirm_line("E1", "넘길 일", "받았다") 의 줄을 decide 로 적어 push → state 「확인됨」 · basis 「E3 INTENT.md 의 결정 기록」
# 판정: E1 의 rulings_archived 가 결과 파일의 Ruling 줄(「- Ruling: …」)이다 · 결과 파일이 없는 E3 는 []
# 조사 흐름(AC9): feature/tm-e2 의 $TM/jobs/E2/survey.md 에 `## 번호 대조` 표(D2 · S2 반영)와 `## 미룸` 표(한 행, 받는 곳 E3) →
#   E2 의 specs == [그 경로] · warnings 에 「번호 대조 건너뜀」 이 없다 · handoffs 에 giver E2 행이 있다 → `## 번호 대조` 에서 S2 행을 지우면 warnings 에 「생략」 과 S2
```

- [ ] **Step 2: 실패를 확인한 뒤 고친다**

Run: `bash plugins/spec-distill/tests/test_team_status.sh | grep '✗' | head`
Expected: 「알림:」 단언들이 실패한다. 그 뒤 위 인터페이스대로 쓴다. `outside` 의 「예약」 판정은 `roadmap_status._reserves` 와 같은 규칙(같은 경로이거나 `/` 로 끝나는 예약 아래)이다 — `team_status` 가 그 함수를 받아 쓰도록 인자로 넘기거나 `compute` 쪽에서 걸러 넘긴다(같은 규칙을 두 번 쓰지 않는다).

- [ ] **Step 3: 통과와 회귀를 확인한다**

Run:
```bash
bash plugins/spec-distill/tests/test_team_status.sh | tail -n 1; bash plugins/spec-distill/tests/test_roadmap_status.sh | tail -n 1; bash plugins/spec-distill/tests/test_team_write.sh | tail -n 1
python3 -m unittest plugins/spec-distill/tests/test_team_files.py plugins/spec-distill/tests/test_roadmap_model.py plugins/spec-distill/tests/test_conductor_state.py
```
Expected: `test_team_write.sh` 는 Task 7 뒤와 같은 둘만 빨갛고(역할 문서 틀은 만든 것과 틀을 견주므로 초록) 나머지는 통과.

- [ ] **Step 4: 커밋**

```bash
git add -- plugins/spec-distill/scripts/team_status.py plugins/spec-distill/scripts/roadmap_status.py plugins/spec-distill/scripts/roadmap_model.py plugins/spec-distill/templates/team/role-worker.md plugins/spec-distill/templates/team/role-writer.md plugins/spec-distill/tests/test_team_status.sh plugins/spec-distill/tests/test_team_files.py
git commit -m "feat(spec-distill): team 형식의 알림 — 예약 밖 변경 · INTENT.md 어긋남 · 넘김과 판정 읽기" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

---

### Task 9: 로드맵 밖 과제 — `kind: task` (AC14)

**Files:**
- Modify: `plugins/spec-distill/scripts/team_status.py` · `roadmap_status.py`(`build`)
- Test: `plugins/spec-distill/tests/test_team_tasks.sh`(새)

**Interfaces:**
- Consumes: `Git.names` · `Git.unmerged_tips`, `read_tip`, `team_files.intent_meta` · `intent_sections`, `job_results.receipt`.
- Produces(`team_status`): `task_jobs(reader, blocks: list) -> tuple` — `(과제 목록, 알림 줄 목록)`. 과제 하나는 `{"id", "kind": "task", "title"(목표 칸의 첫 줄), "stage", "reason", "task_status", "branch", "tip", "intent"(INTENT.md 경로), "progress", "notes"}` 다.
- `build` 는 team 로드맵이면 보고에 `jobs` 와 `job_notes` 를 싣는다. 블록 목록(`blocks`)과 종료 코드는 바꾸지 않는다.

찾는 규칙(Q2 · Q10 · Q12):

1. 기본 브랜치의 과제 폴더 이름 가운데 블록 번호가 아닌 것 — INTENT.md 머리의 `kind` 가 `task` 면 단계 「머지됨」(근거 `기본 브랜치에 있음`)으로 싣는다. `kind` 가 `task` 가 아니면 건너뛴다(블록 없는 에픽 폴더는 나무 검사의 알림이다).
2. `git.unmerged_tips(main)` 의 끝마다 과제 폴더 이름 가운데 블록 번호도 1번의 이름도 아닌 것을 모은다 — `(과제 이름, 그 INTENT.md 머리의 branch)` 의 집합.
3. 모은 짝마다 `read_tip(git, branch)` 로 그 브랜치의 끝을 고른다. 갈라짐이면 싣지 않고 알림 `로드맵 밖 과제 <이름>: <갈라짐 사유>`. 끝이 없거나, 그 끝에 그 과제의 INTENT.md 가 없거나, 그 머리의 `branch` 가 그 브랜치 이름이 아니면 싣지 않고 알림 `로드맵 밖 과제 <이름> 을 세지 않았다 — 머리의 branch(<값>) 와 이름이 맞는 브랜치에 이 과제 폴더가 없다`.
4. 실린 과제의 단계 — `receipt(…, "implement", None, 머리의 paths, [])` 가 `RECEIVED` 면 「결과 받음」, 아니면 「진행 중」(근거 `브랜치 있음`). 알림(아직 안 올라옴 · 받음 · 막힘 · 받음 없음)과 진행 칸은 블록과 같은 함수로 채운다.
5. 같은 과제 이름이 둘 이상의 브랜치에서 실리면 둘 다 싣고 알림 `로드맵 밖 과제 이름이 겹친다: <이름> — <브랜치 · 브랜치>`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_team_tasks.sh`(`fixtures/team_repo.sh` 를 source). `jobs` 는 `js "$T/s.json" "[(j['id'], j['stage'], j['branch']) for j in r['jobs']]"`, `jnotes` 는 `job_notes` 를 이은 글, `newjob <이름> <브랜치> [<머리에 적을 branch>]` 는 그 브랜치를 main 에서 갈라 `job new` 를 돌리고 커밋한다:

```bash
status "$T/s.json" >/dev/null
assert_eq "$(js "$T/s.json" "(r['jobs'], r['job_notes'])")" "([], [])" "과제: 처음에는 없다"
n_blocks="$(js "$T/s.json" "len(r['blocks'])")"
newjob fix-typo fix/typo && g push -q origin fix/typo && status "$T/s.json" >/dev/null
assert_eq "$(jobs)" "[('fix-typo', '진행 중', 'fix/typo')]" "AC14: 브랜치 끝에만 있는 과제 폴더를 찾는다"
assert_eq "$(js "$T/s.json" "[(j['kind'], j['task_status'], j['intent'], j['title']) for j in r['jobs']]")" "[('task', 'in_progress', '$TM/jobs/fix-typo/INTENT.md', '오타 고치기')]" "AC14: 과제의 칸"
assert_eq "$(js "$T/s.json" "len(r['blocks'])")" "$n_blocks" "AC14: 에픽 목록과 따로다 — 블록 수는 그대로"
g checkout -q -b fix/typo-copy fix/typo && put note.txt n && g commit -qm copy && g push -q origin fix/typo-copy && status "$T/s.json" >/dev/null
assert_eq "$(jobs) · $(jnotes)" "[('fix-typo', '진행 중', 'fix/typo')] · " "과제: 다른 브랜치의 사본은 조용히 건너뛴다(한 번만 센다)"
newjob wrong fix/wrong-name fix/absent && g push -q origin fix/wrong-name && status "$T/s.json" >/dev/null
assert_not_contains "$(jobs)" "wrong" "AC14: 머리의 branch 가 그 브랜치와 다르면 세지 않는다"
assert_contains "$(jnotes)" "로드맵 밖 과제 wrong 을 세지 않았다 — 머리의 branch(fix/absent)" "AC14: 세지 않은 것을 알린다"
assert_eq "$(js "$T/s.json" "r['exit']")" "0" "과제: 알림은 종료 코드를 바꾸지 않는다"
# 로컬에만 있는 브랜치의 과제(newjob solo fix/solo, push 하지 않는다) → jobs 에 있고 그 notes 에 「아직 안 올라옴」
# 갈라진 브랜치의 과제 → jobs 에 없고 jnotes 에 「로드맵 밖 과제 <이름>: 갈라짐 — 」
# 결과 받음: fix/typo 에 docs/a.md 커밋 → implement-1.md(산출물: docs/a.md · 끝) → job_results check --branch fix/typo 의 받음 줄을 decide → 「결과 받음」 · 그 뒤 docs/a.md 를 또 고치면 「진행 중」 과 notes 「받은 뒤 바뀜」(Q6 — 설계 없는 과제도 낡는다)
# 머지됨: fix/typo 를 main 에 merge 커밋으로 합쳐 push → jobs 의 fix-typo 가 ('fix-typo', '머지됨', 'fix/typo') · reason 「기본 브랜치에 있음」
# 이름 겹침: 두 브랜치 fix/dup-a · fix/dup-b 가 각자 과제 dup 을 만들고 머리가 제 브랜치를 가리킨다 → jobs 에 둘 · jnotes 에 「로드맵 밖 과제 이름이 겹친다: dup — fix/dup-a · fix/dup-b」
# 에픽 번호 꼴의 폴더가 블록 없이 브랜치에만 있는 경우(kind: epic) → jobs 에 없다 · jnotes 에도 없다
```

- [ ] **Step 2: 실패를 확인한 뒤 `task_jobs` 와 `build` 의 두 칸을 쓴다**

Run: `bash plugins/spec-distill/tests/test_team_tasks.sh | tail -n 3`
Expected: `KeyError: 'jobs'` 로 실패한다. 그 뒤 쓴다 — 기본 브랜치를 모르면(`main` 이 None) `([], [])` 이다.

- [ ] **Step 3: 통과와 회귀를 확인하고 커밋한다**

Run: `chmod +x plugins/spec-distill/tests/test_team_tasks.sh && bash plugins/spec-distill/tests/test_team_tasks.sh | tail -n 1; bash plugins/spec-distill/tests/test_team_status.sh | tail -n 1; bash plugins/spec-distill/tests/test_roadmap_status.sh | tail -n 1`
Expected: 모두 통과.

```bash
git add -- plugins/spec-distill/scripts/team_status.py plugins/spec-distill/scripts/roadmap_status.py plugins/spec-distill/tests/test_team_tasks.sh
git ls-files -s plugins/spec-distill/tests/test_team_tasks.sh   # 100755
git commit -m "feat(spec-distill): 로드맵 밖 과제(kind: task)를 브랜치 끝에서 찾아 따로 싣는다" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

---

### Task 10: 현황 — 진행 숫자 · 알림 · 「로드맵 밖 과제」 · 코드 지문 (AC14 · AC27 · AC13)

**Files:**
- Modify: `plugins/spec-distill/scripts/control_plane.py`
- Test: `plugins/spec-distill/tests/test_control_plane.py`

**Interfaces:**
- Consumes: 상태 계산 보고의 `layout` · `jobs` · `job_notes` 와 블록의 `progress` · `job`(Task 7 · 9).
- Produces(`control_plane`):
  - `stage_text(b: dict) -> str` — `progress` 칸이 없거나 None 이면 단계 글자 그대로. 숫자가 있으면 `<단계> <n>/<전체>`(단계가 「일부 머지」 로 시작하면 `<단계> · 진행 <n>/<전체>`), 사유만 있으면 `<단계>(<사유의 「 — 」 앞부분>)`
  - `show_text` — 블록 줄의 단계 자리에 `stage_text(b)` 를 쓴다. 보고에 `layout` 이 있으면 블록의 경고 줄 뒤에 `    정보: <알림>` 줄을 낸다. 보고에 `jobs` 나 `job_notes` 가 있으면 블록들 뒤에 `로드맵 밖 과제:` 한 줄, 과제마다 `    <이름> <제목> — <stage_text> · <근거>` 와 그 알림의 `        정보: …`, `job_notes` 마다 `    정보: …` 를 낸다
  - `tasks_output` — 블록 줄의 단계 자리에 `stage_text(b)` 를 쓰고, `jobs` 마다 `로드맵 밖 과제 <이름> — <stage_text>` 와 탭 뒤 작업 상태 한 줄을 더한다
  - `epic_view` — 첫 줄의 단계 자리에 `stage_text(b)`, 블록에 `job` 칸이 있으면 `  과제 파일: <INTENT.md 경로>` 와 `  결과 파일: <이름 또는 없음>` 줄을 `계획` 줄 뒤에 낸다
  - `BUCKETS` 의 「구현」 과 `IMPL_STAGES` 에 `진행 중` · `결과 받음` 을 더하고, `overlay` 가 `구현 끝` 일 때 하던 PR 덧씌움을 `결과 받음` 에도 한다. `overlay` 는 보고에 `layout` 이 있으면 판정의 출처 라벨을 「결과 파일」 로 쓴다
  - `CODE_STAMP_FILES` 에 `team_files.py` · `team_check.py` · `team_status.py` · `job_results.py` · `workflow_superpowers.py` · `branch_tip.py` · `gh_repo.py` 를 더한다(Q24)
- 옛 형식의 보고(`layout` · `progress` · `jobs` 칸이 없다)에서는 모든 출력이 지금과 바이트가 같다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_control_plane.py` 에(그 파일의 `report` · `blk` · `RM` 도우미를 쓴다):

```python
class TeamView(unittest.TestCase):   # R1 AC14 · AC27
    def team_report(self):
        e1 = dict(blk("E1", "구현 중", "in_progress"), reason="implement 결과 파일 있음: implement-plan-1-1.md", progress={"done": 3, "total": 7},
                  notes=["막힘: implement plan 1 시도 1 — r/t/jobs/E1/results/BLOCKED.md"], job={"intent": "r/t/jobs/E1/INTENT.md", "plan": 1, "result": "implement-plan-1-1.md"})
        e2 = dict(blk("E2", "구현 중", "in_progress"), progress={"done": None, "total": None, "why": "진행 줄 없음"}, notes=[], job=None)
        e3 = dict(blk("E3", "구현 중", "in_progress"), progress={"done": None, "total": None, "why": "진행 줄 깨짐 — Task 9/3: 끝 — x"}, notes=[])
        e4 = dict(blk("E4", "일부 머지 1/2", "in_progress"), progress={"done": 1, "total": 4}, notes=[])
        e5 = dict(blk("E5", "준비", "pending"), progress=None, notes=[])
        job = {"id": "fix-typo", "kind": "task", "title": "오타 고치기", "stage": "진행 중", "reason": "브랜치 있음", "task_status": "in_progress",
               "branch": "fix/typo", "tip": "a" * 40, "intent": "r/t/jobs/fix-typo/INTENT.md", "progress": None, "notes": ["아직 안 올라옴 — fix/typo 의 로컬 끝"]}
        return report([e1, e2, e3, e4, e5], layout="team", jobs=[job], job_notes=["로드맵 밖 과제 wrong 을 세지 않았다"])

    def test_stage_text(self):
        b = {x["id"]: x for x in self.team_report()["blocks"]}
        self.assertEqual([cp.stage_text(b[k]) for k in ("E1", "E2", "E3", "E4", "E5")],
                         ["구현 중 3/7", "구현 중(진행 줄 없음)", "구현 중(진행 줄 깨짐)", "일부 머지 1/2 · 진행 1/4", "준비"])
        self.assertEqual(cp.stage_text(blk("R1", "구현 중", "in_progress")), "구현 중")   # 옛 형식 블록 — 칸이 없다

    def test_show_lines(self):
        lines = cp.show_text([(RM, self.team_report())], None, [], cp.first_line).split("\n")
        self.assertTrue(any(l.startswith("E1 ") and "— 구현 중 3/7 · " in l for l in lines), lines)
        self.assertIn("    정보: 막힘: implement plan 1 시도 1 — r/t/jobs/E1/results/BLOCKED.md", lines)
        at = lines.index("로드맵 밖 과제:")
        self.assertEqual(lines[at + 1:at + 4], ["    fix-typo 오타 고치기 — 진행 중 · 브랜치 있음",
                                                 "        정보: 아직 안 올라옴 — fix/typo 의 로컬 끝", "    정보: 로드맵 밖 과제 wrong 을 세지 않았다"])

    def test_task_list(self):
        out, err, rc = cp.tasks_output([(RM, dict(self.team_report(), exit=0))])
        self.assertEqual((err, rc), ("", 0))
        self.assertIn("E1 %s — 구현 중 3/7\tin_progress" % self.team_report()["blocks"][0]["title"], out)
        self.assertIn("로드맵 밖 과제 fix-typo — 진행 중\tin_progress", out)

    def test_old_reports_render_as_before(self):   # AC13 — 새 칸이 없는 보고는 한 글자도 달라지지 않는다
        old = report([blk("R1", "구현 중", "in_progress"), blk("R2", "준비", "pending")])
        old["blocks"][0]["notes"] = ["경로 예약 위반: a 은 R2 만 예약했다"]
        text = cp.show_text([(RM, old)], None, [], cp.first_line)
        self.assertNotIn("정보: 경로 예약 위반", text)        # 옛 형식의 지도는 블록 알림을 보이지 않는다(지금 그대로)
        self.assertNotIn("로드맵 밖 과제:", text)
        self.assertIn("R1 %s — 구현 중 · " % old["blocks"][0]["title"], text)

    def test_buckets_count_plain_flow_stages(self):
        counts, other = cp.bucket_counts([(RM, report([blk("E2", "진행 중", "in_progress"), blk("E3", "결과 받음", "in_progress")]))])
        self.assertEqual((counts["구현"], other), (2, 0))


class CodeStampClosure(unittest.TestCase):   # Q24 — 목록을 고르지 않고 도출한다
    OUTSIDE_THE_CACHE = {"state_path.py", "ledger_marker.py"}   # 기계 상태 쪽 — 캐시 열쇠가 아니다(있는 테스트가 못 박는다). 그 너머로는 따라가지 않는다

    def closure(self, start):
        import ast
        seen, todo = set(), [start]
        while todo:
            name = todo.pop()
            if name in seen or name in self.OUTSIDE_THE_CACHE:
                continue
            seen.add(name)
            tree = ast.parse((cp.SCRIPTS / name).read_text(encoding="utf-8"))
            for node in ast.walk(tree):
                mods = [a.name for a in node.names] if isinstance(node, ast.Import) else [node.module or ""] if isinstance(node, ast.ImportFrom) else []
                todo += [m.split(".")[0] + ".py" for m in mods if (cp.SCRIPTS / (m.split(".")[0] + ".py")).is_file()]
        return seen

    def test_every_module_the_status_computation_loads_is_stamped(self):
        need = self.closure("roadmap_status.py")
        self.assertEqual(sorted(need - set(cp.CODE_STAMP_FILES)), [])
        for name in ("team_status.py", "job_results.py", "team_files.py", "team_check.py", "workflow_superpowers.py", "branch_tip.py"):
            self.assertIn(name, need)   # 양성 대조 — 도출이 새 모듈에 닿는다
```

`report(...)` 도우미가 맨 위 칸을 인자로 받지 않으면 돌려받은 사전에 `layout` · `jobs` · `job_notes` 를 넣는다.

- [ ] **Step 2: 실패를 확인한 뒤 `control_plane.py` 를 고친다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_control_plane.py 2>&1 | tail -n 5`
Expected: `AttributeError: module 'control_plane' has no attribute 'stage_text'` 와 `CodeStampClosure` FAIL. 그 뒤 고친다 — `control_plane.py` 에 로컬 import 를 더하지 않는다(보고의 칸만 읽는다).

- [ ] **Step 3: 통과와 회귀를 확인하고 커밋한다**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_control_plane.py
bash plugins/spec-distill/tests/test_control_plane.sh | tail -n 1; bash plugins/spec-distill/tests/test_default_branch.sh | tail -n 1
```
Expected: 모두 통과(있는 `CodeStamp` · `test_code_stamp_covers_state_computation_modules` 는 고치지 않은 채 — `state_path.py` 는 목록에 없다).

```bash
git add -- plugins/spec-distill/scripts/control_plane.py plugins/spec-distill/tests/test_control_plane.py
git commit -m "feat(spec-distill): 현황이 team 형식의 진행 숫자 · 알림 · 로드맵 밖 과제를 보인다" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

---

### Task 11: team 형식의 번호 대조 — 번호 파일 · 결과 파일 · `## 원문 대조` (AC15 · AC13)

**Files:**
- Modify: `plugins/spec-distill/scripts/check_bundle_coverage.py` · `roadmap_status.py`(`_GitTreeRepo` · 대조를 부르는 자리)
- Test: `plugins/spec-distill/tests/test_team_coverage.sh`(새) · `test_bundle_coverage.sh`(T-f 의 남은 몫)

**Interfaces:**
- Consumes: `team_layout.team_from_roadmap` · `INTENT_FILE`, `team_files.parse_result`(결과 파일의 본문), `roadmap_model.is_team`.
- Produces(`check_bundle_coverage`):
  - `SOURCES_TYPE = "job-sources"` · `ORIGIN_HEADING = "## 원문 대조"` · `ORIGIN_SHALLOW = "원문 대조의 「바꿈」 행에 근거가 없다"`
  - `origin_rows(spec_text: str) -> Optional[list]` — 그 절의 표 행 `(원문 요소, 설계 요소, 그대로/바꿈, 근거)` 들. 절이 없으면 None, 행의 칸이 넷이 아니면 `FormatError`
  - `check(bundle_text, spec_text, *, audit_text=None, repo=None, roadmap_rel=None) -> dict` — 정답 출처 머리의 `type` 이 `SOURCES_TYPE` 이면 team 이다: `mode` 는 `"sources"`, 에픽 번호는 머리의 `job`, 로드맵 경로는 `roadmap_rel`(번호 파일에는 그 키가 없다). team 일 때만 결과에 `notices`(글 목록) 칸이 있고, 절이 없으면 ``설계문서에 `## 원문 대조` 표가 없다``, 표가 깨졌으면 ``원문 대조 표를 읽지 못했다 — <사유>``, 셋째 칸이 `바꿈` 이고 넷째 칸이 빈 행마다 `shallow` 에 `{"id": <원문 요소 글 40자까지>, "reason": ORIGIN_SHALLOW}` 를 더한다. `status` 는 지금 규칙 그대로다(빠진 번호만 1)
  - `_roadmap_view(fm, repo, roadmap_rel=None)` — 돌려주는 사전에 `team`(로드맵이 team 형식이면 `Team`, 아니면 None)을 더한다. `roadmaps_dir` 은 `repo` 의 속성 `roadmaps_dir` 이 있으면 그것, 없으면 지금 `specs_dir` 을 얻는 해결자 호출에서 함께 읽는다
  - `_block_specs` — `view["team"]` 이 있고 묶음 블록이면 그 과제의 `design.md` 하나를 읽는다(없음이 확인되면 `[]`, 읽지 못하면 못 읽은 목록)
  - `coverage(first_path, spec_path)` — 첫 파일이 번호 파일이면 같은 폴더 INTENT.md 머리의 `roadmap` 으로 레포를 찾아 `check(…, repo=…, roadmap_rel=…)` 를 부른다. INTENT.md 를 읽지 못하면 로드맵 없이 부른다(기각 행은 「셀 수 없음」 으로 나온다)
  - `render` — `mode` 가 `"sources"` 면 첫 줄의 「묶음 번호」 자리에 「번호 파일 번호」, `notices` 마다 `알림 — <글>` 줄을 끝에 낸다
  - `--impl` — 보고 파일의 머리 `type` 이 결과 파일이면(`team_files.RESULT_TYPE`) 머리와 펜스 안을 뺀 본문(`parse_result(…).machine_text`)에서 `AC<n>:` 줄을 읽는다. 그 밖의 보고 파일은 지금 그대로다
- `roadmap_status` — `_GitTreeRepo(git, tree, specs_dir, roadmaps_dir=None)` 가 속성 `roadmaps_dir` 을 갖고, 대조를 부르는 자리가 `roadmap_rel` 을 넘기며, 결과의 `notices` 를 그 블록 알림에 `번호 대조 알림: <글>` 로 싣는다(종료 코드 불변).
- 옛 형식의 입력(묶음 · brief)에서는 결과의 칸 · 글 · 종료 코드가 지금과 같다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_team_coverage.sh`(`fixtures/team_repo.sh` 를 source). `cov [인자…]` 는 `(cd "$W" && python3 "$S/check_bundle_coverage.py" "$TM/jobs/E1/sources.md" "$TM/jobs/E1/design.md" "$@") > "$T/out.txt" 2>&1; echo $?` 다. `design <번호 대조 행들> <원문 대조 절 글>` 은 작업 폴더에 E1 의 `design.md`(수용 기준 둘 · `## §1 하나` 절 · `## 번호 대조` 표 · 받은 원문 대조 절)를 쓴다:

```bash
design "$ROWS_ALL" "$ORIGIN_OK"
assert_eq "$(cov)" "0" "AC15: 번호 파일의 ids 가 정답 출처 — 모두 있으면 0"
assert_contains "$(sed -n 1p "$T/out.txt")" "번호 파일 번호" "AC15: 첫 줄이 정답 출처를 번호 파일이라 말한다"
assert_not_contains "$(cat "$T/out.txt")" "알림 — " "AC15: 원문 대조 표가 있으면 알림이 없다"
design "$ROWS_NO_C1" "$ORIGIN_OK"
assert_eq "$(cov)" "1" "AC15: 번호 파일의 번호가 표에 없으면 1"
assert_contains "$(cat "$T/out.txt")" "C1" "AC15: 빠진 번호를 낸다"
design "$ROWS_ALL" ""
assert_eq "$(cov)" "0" "AC15: 원문 대조 표가 없어도 종료 코드는 그대로"
assert_contains "$(cat "$T/out.txt")" '알림 — 설계문서에 `## 원문 대조` 표가 없다' "AC15: 알림 한 줄"
assert_eq "$(cov --json >/dev/null; python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["notices"])' "$T/out.txt")" '['"'"'설계문서에 `## 원문 대조` 표가 없다'"'"']' "AC15: --json 의 notices"
design "$ROWS_ALL" "$ORIGIN_CHANGED_NO_REASON"     # 「| 팀 폴더 | 과제 폴더 | 바꿈 |  |」 한 행
assert_eq "$(cov)" "0" "AC15: 얕은 답은 종료 코드를 바꾸지 않는다"
assert_contains "$(cat "$T/out.txt")" "원문 대조의 「바꿈」 행에 근거가 없다" "AC15: 근거 칸이 빈 「바꿈」 은 얕은 답"
# 「바꿈」 에 근거가 있는 행 · 「그대로」 에 근거가 빈 행 → 얕은 답 0개 · 칸이 셋인 행 → 알림 「읽지 못했다」 · rc 0
# 받듦(team 의 다른 과제 설계문서): E1 의 표에서 S1 을 「기각 | E3 가 받는다」 로 → rc 0 · 「받드는 에픽 없는 발화」 가 없다(E3 에 배정됐고 E3 의 design.md 가 없다)
#   → 작업 폴더에 $TM/jobs/E3/design.md 를 쓰고 그 `## 번호 대조` 에서 S1 을 기각 → 「받드는 에픽 없는 발화 1개」 와 S1 (과제 폴더의 설계문서를 읽었다는 증거)
# 옆 INTENT.md 가 없는 번호 파일(임시 폴더에 번호 파일과 설계문서만 복사): 기각 행이 「셀 수 없음」 · rc 는 빠진 번호 규칙 그대로
# --impl: 결과 파일(머리 + 「AC1: 구현됨 — a」 · 펜스 안의 「AC1: 구현됨 — 인용」 · 「AC2: 미룸 — 뒤」)로 → 「보고에 AC1 가 두 번」 이 아니다 · 첫 줄이 「구현 대조:」 로 시작
# 옛 형식: 임시 폴더의 옛 묶음(type: epic-bundle)과 원문 대조 절이 없는 설계문서로 --json → 'notices' 키가 없다 · 글 출력에 「알림 — 」 이 없다
# 단계 계산을 거쳐: feature/tm-e1 에 원문 대조 절이 없고 C1 이 빠진 design.md 를 커밋 → 블록 E1 의 warnings 에 「생략」 과 C1 · notes 에 「번호 대조 알림: 설계문서에 `## 원문 대조` 표가 없다」
```

- [ ] **Step 2: 실패를 확인한 뒤 `check_bundle_coverage.py` 와 부르는 자리를 고친다**

Run: `bash plugins/spec-distill/tests/test_team_coverage.sh | tail -n 3`
Expected: 「번호 파일 번호」 · 「알림 — 」 단언이 실패한다. 그 뒤 고친다 — `check_bundle_coverage.py` 는 `team_files` · `team_layout` 을 import 한다(둘 다 정적 락의 목록에 이미 있다).

- [ ] **Step 3: 사본 목록을 고치고 통과와 회귀를 확인한다 (T-f 의 남은 몫)**

`tests/test_bundle_coverage.sh` 의 사본 줄 둘에 `"$S/team_files.py"` 를 더한다(`test_roadmap_status.sh` 의 사본 줄에는 Task 7 이 이미 넣었다).

Run:
```bash
chmod +x plugins/spec-distill/tests/test_team_coverage.sh && bash plugins/spec-distill/tests/test_team_coverage.sh | tail -n 1
bash plugins/spec-distill/tests/test_bundle_coverage.sh | tail -n 1; bash plugins/spec-distill/tests/test_spec_review_bundle.sh | tail -n 1; bash plugins/spec-distill/tests/test_roadmap_status.sh | tail -n 1; bash plugins/spec-distill/tests/test_team_status.sh | tail -n 1
```
Expected: 모두 통과 — `test_bundle_coverage.sh` 의 단언은 하나도 고치지 않았다.

- [ ] **Step 4: 커밋**

```bash
git add -- plugins/spec-distill/scripts/check_bundle_coverage.py plugins/spec-distill/scripts/roadmap_status.py plugins/spec-distill/tests/test_team_coverage.sh plugins/spec-distill/tests/test_bundle_coverage.sh
git ls-files -s plugins/spec-distill/tests/test_team_coverage.sh   # 100755
git commit -m "feat(spec-distill): team 형식의 번호 대조 — 번호 파일이 정답이고 원문 대조 표를 본다" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

---

### Task 12: spec-review 진입과 넘김 줄 (AC16 · AC17)

**Files:**
- Modify: `plugins/spec-distill/scripts/spec_review_bundle.py` · `plugins/spec-distill/references/epic-handoff.md`
- Test: `plugins/spec-distill/tests/test_team_review_entry.sh`(새) · `test_epic_handoff.sh`

**Interfaces:**
- Consumes: `check_bundle_coverage.coverage`(번호 파일을 받는다 — Task 11), `team_layout.SOURCES_FILE` · `INTENT_FILE` · `original_rel`, `workflow_superpowers.place_sentence`.
- Produces(`spec_review_bundle`):
  - `JOB_KIND = "job"` · `TEAM_NOTICE` — `[spec-distill] team 형식 — 리뷰어가 번호 항목(<번호 파일 이름>)과 원자료(<원자료 사본의 팀 폴더 기준 경로>)를 정답으로 읽지 못한다. 리뷰어에게 가는 정답 출처는 <INTENT.md 이름> 하나다.`(이름들은 `team_layout` 에서)
  - `entry` — `--bundle` 의 머리 `type` 이 `job` 이면 받는다. `source_interview` 대조는 지금과 같다. 같은 폴더에 번호 파일이 있으면 그것으로 `coverage` 를 돌리고, 없으면 `번호 대조 건너뜀 — 번호 파일이 없는 과제다(단순 작업).` 한 줄이다. 줄의 차례는 번호 대조 글 → `TEAM_NOTICE` → `번호 대조 경고 <N>개` → `bundle-entry: PROCEED <INTENT.md 절대경로>` 다(마지막 두 줄의 계약은 지금 그대로)
  - `neighbors` — 머리 `type` 이 `job` 이면 `job` 을 에픽 번호로, `roadmap` 을 로드맵 경로로 같은 일을 한다
  - 번호 파일을 `--bundle` 로 주면 지금처럼 거절한다(정답 출처는 INTENT.md 다)
- `references/epic-handoff.md` — `## team 형식의 넘김 줄` 절을 `## 자리표` 절 뒤에 더한다. 있는 넘김 줄(`> \`@<bundle-abs> …`)과 자리표 절은 한 글자도 고치지 않는다.

team 넘김 줄은 있는 넘김 줄을 그대로 옮기고 아래 자리만 바꾼 한 줄이다(인용 줄 하나 — `> \`@<intent-abs> …\``):

| 있는 줄의 글 | team 줄의 글 |
|---|---|
| `@<bundle-abs> 이 에픽 묶음으로` | `@<intent-abs> 이 과제 파일로` |
| `이 묶음은 승인된 로드맵 <roadmap-rel> 의 에픽 <epic-id> 다` | `이 과제 파일은 승인된 로드맵 <roadmap-rel>(team 형식)의 에픽 <epic-id> 다` |
| `묶음을 다시 나눌 근거가 보이면` | `과제를 다시 나눌 근거가 보이면` |
| `묶음의 근거가 지금도 맞는지` | `번호 파일의 근거가 지금도 맞는지` |
| `묶음의 모든 번호(확정 · 열린 질문 · 조사 · 위험 · 발화)를 번호째 설계의 입력으로 읽는다 — /compact 요약에 기대지 말고 첨부한 묶음을 다시 읽는다.` | `설계 전에 원자료 <original-rel> 전체와 번호 파일 <sources-rel> 을 읽는다 — 과제 파일의 지시 원문 줄 범위는 일꾼용이고 설계는 원자료 전체를 기준으로 한다. 번호 파일의 모든 번호(확정 · 열린 질문 · 조사 · 위험)를 번호째 설계의 입력으로 읽는다 — /compact 요약에 기대지 말고 그 두 파일을 다시 읽는다.` |
| `묶음 ids 의 모든 번호를 싣고` | `번호 파일 ids 의 모든 번호를 싣고` |
| (그 문장 뒤에 더한다) | `설계문서에 ## 원문 대조 표(칸: 원문 요소 · 설계 요소 · 그대로/바꿈 · 근거)를 두어 원자료의 요소마다 한 행을 싣고, 바꾼 것은 근거를 적거나 「작성자 제안」 으로 표시한다.` |
| `source_interview 에 <bundle-rel> 을` | `source_interview 에 <intent-rel> 을` |
| `묶음의 확정 항목은 다시 묻지 않고` | `번호 파일의 확정 항목은 다시 묻지 않고` |
| `설계문서를 쓰고 커밋한 뒤,` 앞에 더한다 | `<place-sentence>` |
| `--bundle <bundle-rel>` | `--bundle <intent-rel>` |

그 절의 자리표 설명 — `<intent-abs>` · `<intent-rel>`(그 과제 INTENT.md 의 절대경로 · 레포 기준 경로), `<original-rel>` · `<sources-rel>`(원자료 사본 · 그 과제 번호 파일의 레포 기준 경로), `<place-sentence>`(`scripts/workflow_superpowers.py place --roadmap <roadmap-rel> --job <epic-id> --stage design` 이 낸 한 줄). 있는 줄에 위 표의 왼쪽 글이 없으면(Task 1 뒤 그 문서가 바뀌었다) 멈춰 보고한다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_team_review_entry.sh`(`fixtures/team_repo.sh` 를 source). `ent <설계문서> <--bundle 값>` 은 `python3 "$S/spec_review_bundle.py" entry --spec "$1" --bundle "$2" --root "$W" > "$T/out.txt"; echo $?` 다:

```bash
I="$TM/jobs/E1/INTENT.md"
design_with_source "$I"          # 작업 폴더의 E1 design.md — 머리 source_interview: $I · 번호 대조 표 · 원문 대조 표
assert_eq "$(ent "$TM/jobs/E1/design.md" "$I")" "0" "AC16: INTENT.md 를 --bundle 로"
assert_eq "$(tail -n 1 "$T/out.txt")" "bundle-entry: PROCEED $W/$I" "AC16: PROCEED 와 INTENT.md 의 절대경로"
assert_eq "$(tail -n 2 "$T/out.txt" | head -n 1)" "번호 대조 경고 0개" "AC16: PROCEED 바로 앞 줄은 지금 계약 그대로"
assert_eq "$(grep -c 'team 형식 — 리뷰어가 번호 항목(sources.md)과 원자료(intent/original.md)를 정답으로 읽지 못한다' "$T/out.txt")" "1" "AC16: 알림 한 줄"
assert_contains "$(sed -n 1p "$T/out.txt")" "번호 대조: 빠진 번호 없음 (번호 파일 번호" "AC16: 진입 번호 대조는 옆 번호 파일로 한다"
# 번호 하나를 표에서 뺀 설계문서 → 「번호 대조 경고 1개」 · PROCEED 그대로
# source_interview 가 다른 과제의 INTENT.md → 「bundle-entry: REFUSE」 · --bundle 로 번호 파일 → REFUSE 와 지금 글(「type 이 epic-bundle · interview-brief 가 아니다(job-sources)」)
# 단순 작업의 INTENT.md(작업 폴더에서 job new) → 「번호 대조 건너뜀 — 번호 파일이 없는 과제다(단순 작업).」 · PROCEED
# neighbors --bundle "$I" → 첫 줄 「로드맵 속 위치 — $RM」 · E1 줄 · 「이 에픽에 의존: E3」 줄
```

`test_epic_handoff.sh` 에 더한다(그 파일의 변수 이름을 쓴다):

```bash
assert_eq "$(grep -c '^> `@<bundle-abs> ' "$EH")" "1" "있는 넘김 줄은 하나 그대로"
assert_eq "$(grep -c '^> `@<intent-abs> 이 과제 파일로 Skill superpowers:brainstorming 을 시작하라' "$EH")" "1" "AC17: team 형식의 넘김 줄이 하나 있다"
TEAM_LINE="$(grep -m1 '^> `@<intent-abs> ' "$EH")"
for lit in '원자료 <original-rel> 전체와 번호 파일 <sources-rel> 을 읽는다' '설계문서에 ## 원문 대조 표(칸: 원문 요소 · 설계 요소 · 그대로/바꿈 · 근거)를 두어' \
           '바꾼 것은 근거를 적거나 「작성자 제안」 으로 표시한다' 'source_interview 에 <intent-rel> 을' '--bundle <intent-rel>' '<place-sentence>'; do
  assert_contains "$TEAM_LINE" "$lit" "AC17: team 넘김 줄 — $lit"
done
assert_not_contains "$TEAM_LINE" "bundle-" "AC17: team 넘김 줄에 묶음 자리표가 남지 않았다"
for ph in '<intent-abs>' '<intent-rel>' '<original-rel>' '<sources-rel>' '<place-sentence>'; do
  assert_eq "$(sed -n '/^## team 형식의 넘김 줄/,$p' "$EH" | grep -c -- "^- \`$ph\`")" "1" "AC17: 자리표 $ph 의 설명이 있다"
done
```

- [ ] **Step 2: 실패를 확인한 뒤 두 파일을 고친다**

Run: `bash plugins/spec-distill/tests/test_team_review_entry.sh | tail -n 3; bash plugins/spec-distill/tests/test_epic_handoff.sh | tail -n 3`
Expected: REFUSE(「type 이 … 아니다(job)」)와 넘김 줄 단언 실패.

- [ ] **Step 3: 통과와 회귀를 확인하고 커밋한다**

Run:
```bash
chmod +x plugins/spec-distill/tests/test_team_review_entry.sh && bash plugins/spec-distill/tests/test_team_review_entry.sh | tail -n 1
for t in test_epic_handoff test_spec_review_bundle test_decompose_surface test_end_gates test_entry_guidance test_conducting_reference test_roadmap_status; do bash plugins/spec-distill/tests/$t.sh | tail -n 1; done
bash shared/tests/test_skill_reference_pointers.sh | tail -n 1
```
Expected: 모두 통과(넘김 줄을 읽는 있는 락 다섯은 고치지 않은 채).

```bash
git add -- plugins/spec-distill/scripts/spec_review_bundle.py plugins/spec-distill/references/epic-handoff.md plugins/spec-distill/tests/test_team_review_entry.sh plugins/spec-distill/tests/test_epic_handoff.sh
git ls-files -s plugins/spec-distill/tests/test_team_review_entry.sh   # 100755
git commit -m "feat(spec-distill): spec-review 진입이 INTENT.md 를 받고 team 형식의 넘김 줄을 둔다" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

---

### Task 13: 리더의 기록 — `record` · `flush` · `write-sections` 와 세지 못한 블록 (AC16)

**Files:**
- Modify: `plugins/spec-distill/scripts/conductor_ledger.py`
- Test: `plugins/spec-distill/tests/test_conductor_ledger.py`

**Interfaces:**
- Consumes: `team_layout.job_of_path` · `layout_of` · `UnknownLayout`, `team_files.append_decision` · `decision_lines` · `FormatError`, 있는 `_roadmaps_dir(root)` · `write_atomic` · `approval_line`.
- Produces(`conductor_ledger`):
  - `team_intent(root, spec) -> Optional[Path]` — `spec` 경로가 `layout: team` 로드맵의 과제 폴더 안이면 그 과제 INTENT.md 의 경로, 아니면 None. 그 로드맵의 `layout` 이 모르는 값이면 `Fail(3, …)`(Q17)
  - `c_record` — `team_intent` 가 있으면 줄을 `append_decision` 으로 그 파일에 쓰고 `적었다(커밋은 리더가) — <INTENT.md 경로> 의 결정 기록: <줄>` 을 낸다. 못 받는 줄이면 `Fail(2, …)` 이고 쓰지 않는다. None 이면 지금 몸 · 지금 글 그대로다
  - `c_flush` — `team_intent` 가 있으면 쌓인 기록(절 칸 「지휘 기록」)의 줄을 같은 함수로 옮기고 `쌓인 기록 <n>줄을 옮겼고 <m>줄은 이미 있어 건너뛰었다(커밋은 리더가) — <INTENT.md 경로> 의 결정 기록` 을 낸다. 표지 검사 · 대기 줄 지우기는 지금 그대로다
  - `c_write_sections` — `team_intent` 가 있으면 아무것도 쓰지 않고 `[spec-distill] team 형식 — 설계문서를 고치지 않았다. 판정은 결과 파일의 Ruling 줄이, 구현 대조는 결과 파일의 AC 줄과 받음 줄이 대신한다(<INTENT.md 경로>)` 를 내고 0
  - `c_pr_handoffs` — 고른 블록이 단계 「알 수 없음」 이고 브랜치 칸에 글이 있는데 브랜치 목록이 비었으면 `Fail(3, "<번호> 의 단계를 세지 못해 브랜치를 읽지 못했다 — <블록 사유>")`(Q18)
  - `c_pr_refresh` — 대상 블록 가운데 그런 블록은 건너뛰고 같은 글을 줄로 내며, 셀 수 있는 블록을 채운 뒤 그런 블록이 하나라도 있었으면 3 으로 끝난다. `--epic` 으로 고른 블록이 그러면 gh 를 부르기 전에 `Fail(3, …)`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_conductor_ledger.py` 에(그 파일의 `Repo` · `sh` · `self.cli` 를 쓴다). `team_tree(self)` 는 작업 폴더에 해결자의 `roadmaps_dir` 아래 팀 `tq` 의 로드맵(머리말 `layout: team`)과 `jobs/E1/` 의 INTENT.md(틀 `templates/team/INTENT.md` 를 `team_files.render_intent` 로 채운 것) · 빈 `design.md` 를 쓰고 그 둘의 경로를 돌려준다:

```python
class TeamRecords(Repo):   # R1 AC16
    def test_record_goes_to_the_job_file(self):
        intent, design = team_tree(self)
        before = design.read_bytes()
        rc, out = self.cli("record", "--spec", str(design), "--approval", "--date", "2026-11-20", "--choice", "이대로 승인 (권장)")
        self.assertEqual(rc, 0, out)
        self.assertEqual(TF.decision_lines(intent.read_text(encoding="utf-8")), ["- spec 승인 · 2026-11-20 · 「이대로 승인 (권장)」"])
        self.assertEqual(design.read_bytes(), before)                    # 설계문서에는 쓰지 않는다
        self.assertIn(str(intent), out); self.assertIn("결정 기록", out)   # 쓴 자리를 낸다
        rc, out = self.cli("record", "--spec", str(intent), "--line", "- 결정 · 2026-11-21 · 막힘을 풀었다")
        self.assertEqual((rc, len(TF.decision_lines(intent.read_text(encoding="utf-8")))), (0, 2), out)

    def test_record_refuses_lines_outside_the_seven_kinds(self):
        intent, _design = team_tree(self)
        before = intent.read_bytes()
        for line in ("- 메모 · 2026-11-20 · 글", "- 결정 · 11/20 · 글", "- 결과 받음 · 2026-11-20 · 받았다"):
            rc, out = self.cli("record", "--spec", str(intent), "--line", line)
            self.assertEqual(rc, 2, (line, out))
        self.assertEqual(intent.read_bytes(), before)

    def test_old_layout_and_other_paths_behave_as_before(self):
        intent, design = team_tree(self, layout=None)           # 머리말에 layout 이 없는 로드맵의 같은 자리
        rc, out = self.cli("record", "--spec", str(design), "--line", "- 메모 한 줄")
        self.assertEqual(rc, 0, out)
        self.assertIn("## 지휘 기록\n\n- 메모 한 줄\n", design.read_text(encoding="utf-8"))
        self.assertTrue(out.startswith("적었다(커밋은 지휘자가) — "), out)   # 옛 글 그대로
        notes = self.w / "notes.md"                                 # 로드맵 폴더 밖의 문서
        rc, out = self.cli("record", "--spec", str(notes), "--line", "- 메모 한 줄")
        self.assertEqual(rc, 0, out)

    def test_unknown_layout_is_uncheckable(self):
        intent, design = team_tree(self, layout="no-such")
        rc, out = self.cli("record", "--spec", str(design), "--line", "- 결정 · 2026-11-20 · 글")
        self.assertEqual(rc, 3, out)

    def test_flush_and_write_sections(self):
        intent, design = team_tree(self)
        # 표지를 쥐고(claim) 쌓인 기록 둘(「E1 · 지휘 기록 · - 결정 · 2026-11-20 · 하나」 · 같은 줄 다시)을 add 한 뒤
        # flush --epic E1 --spec <design> → rc 0 · 결정 기록에 한 줄 · 출력에 「1줄을 옮겼고 1줄은 이미 있어」 와 INTENT.md 경로 · pending 은 「쌓인 기록 없음」
        # write-sections --spec <design> --plan p.md --rulings <파일> --impl-line x --counts y → rc 0 · design 바이트 그대로 · 출력에 「team 형식 — 설계문서를 고치지 않았다」


class UncountedBlock(Repo):   # Q18 — 「브랜치 없음」 과 「브랜치를 읽지 못함」 은 다르다
    def test_handoffs_stop_instead_of_saying_no_branch(self):
        # 기본 브랜치의 로드맵 머리말에 `layout: no-such` 를 넣어 push(블록의 브랜치 칸은 feature/a1 그대로) → 가짜 gh
        # pr-handoffs --epic A1 → rc 3 · 출력에 「A1 의 단계를 세지 못해 브랜치를 읽지 못했다」 · 「브랜치 없음」 이 없다
        # pr-refresh(표지를 쥐고) → rc 3 · 같은 글 · PR 캐시에 줄이 생기지 않았다
        ...
```

`...` 와 주석으로 적은 몸도 단언으로 쓴다. 있는 `PrHandoffEdges.test_block_without_branch`(브랜치 칸이 「없음」 인 블록 → 「브랜치 없음」 · 0)는 고치지 않는다 — 그 블록은 단계가 「준비」 다.

- [ ] **Step 2: 실패를 확인한 뒤 `conductor_ledger.py` 를 고친다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py -k TeamRecords -k UncountedBlock 2>&1 | tail -n 5`
Expected: FAIL(줄이 설계문서에 쓰인다 · 「브랜치 없음」 과 0). 그 뒤 고친다. 맨 위 docstring 의 「기록은 에픽 설계문서의 절에 쓰고」 문장에 team 형식의 자리(INTENT.md 결정 기록)를 더한다.

- [ ] **Step 3: 통과와 회귀를 확인하고 커밋한다**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py 2>&1 | tail -n 3
bash plugins/spec-distill/tests/test_repo_literals.sh | tail -n 1; bash plugins/spec-distill/tests/test_conductor_e2e.sh | tail -n 1; python3 -m unittest plugins/spec-distill/tests/test_team_layout.py
```
Expected: 모두 통과(`conductor_ledger.py` 는 레포 전용 글자 락과 경로 조각 락의 대상이다).

```bash
git add -- plugins/spec-distill/scripts/conductor_ledger.py plugins/spec-distill/tests/test_conductor_ledger.py
git commit -m "feat(spec-distill): 리더의 기록 명령이 team 형식에서 INTENT.md 결정 기록에 쓴다" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

---

### Task 14: 생성기 뒷정리 — 머지된 에픽 보호를 되돌리고 계획 1 의 잔여를 닫는다 (AC13 · AC9 가 열어 준 것)

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_write.py` · `team_write.py` · `team_layout.py` · `roadmap_render.py`
- Test: `plugins/spec-distill/tests/test_team_write.sh`(T-b 와 새 단언) · `test_team_files.py` · `test_workspace_invariance.sh`(T-g)

**Interfaces:**
- `team_layout.STAGE_PENDING` · `roadmap_write.STAGE_PENDING_NOTICE` 를 지운다. `roadmap_write.stages(top, roadmap) -> dict` — `layout` 인자와 team 일 때 `{}` 를 내던 갈림을 없앤다(단계 계산이 team 을 센다 — 계획 1 의 P6 를 되돌린다).
- `team_write.hand_fixes(top, team, old, new, W) -> tuple` — `(손으로 고칠 과제 번호 목록, 화면 줄 목록)`. 지시 원문 범위의 비교는 차례를 무시한다(정렬해 견준다 — 잔여).
- `roadmap_write.cmd_update` — team 이면 손으로 고칠 과제 번호를 먼저 얻어, 그 번호와 바뀐 · 사라진 번호 가운데 단계가 「머지됨」 · 「끝남」 인 것이 있으면 지금 글(`머지되거나 끝난 에픽은 바꾸거나 지우지 않는다 — <번호>`)로 거절한다. 범위만 다른 표도 같다 — 그때는 단계를 물은 뒤에 「아무것도 쓰지 않았다」 로 간다(§미룸 표의 「범위만 바뀐 행」).
- `team_write.update_files` — 새로 묶음이 된 과제 자리에 생성기가 만들지 않은 번호 파일이 있으면 거절한다(`이 생성기가 만들지 않은 파일은 덮어쓰지 않는다 — <경로>` — 옛 형식의 묶음 규칙과 같은 글. 잔여).
- `roadmap_write.cmd_extract`(team) — 에픽 INTENT.md 에 지시 원문 범위 줄이 없으면 그 INTENT.md 경로를 대고 거절한다(`<경로>: 지시 원문에 줄 범위가 없다 — 표의 그 행을 만들 수 없다`. 잔여 — 지금은 표가 틀렸다고 말한다).
- `team_write.render_team_roadmap` — 머리말 줄과 넘김 문장을 그려진 글이 아니라 틀에서 바꾼 뒤 그린다(사용자 글에 옛 넘김 문장이 있어도 거절하지 않는다 — 잔여). 틀에 두 자리가 한 번씩이 아니면 지금처럼 `TableError`.
- `team_write.job_name_refusal` — 블록 번호 꼴(`roadmap_model.BLOCK_ID_RE` 에 `fullmatch`)의 이름을 거절한다(`<이름> 은 에픽 번호 꼴이다 — 뒤에 올 에픽의 과제 폴더 자리를 막는다`. 잔여).

- [ ] **Step 1: 테스트를 고치고 더한다 (T-b · T-g)**

`test_team_write.sh` — 「team update: 머지 여부 알림」 단언 둘(590–591행 근처)을 아래로 바꾼다:

```bash
assert_not_contains "$(cat "$T/out.txt")" "머지 여부를 확인하지 못했다" "team update: 단계를 세므로 머지 여부 알림이 없다"
```

그리고 같은 파일에 더한다:

```bash
# ── 머지된 에픽은 team 에서도 바꾸지 않는다(계획 1 의 P6 를 되돌린다) ─────────────
# 픽스처: fresh mg → create --layout team → 커밋 · push → feature/t-e1 을 만들어 커밋 하나 → main 에 merge 커밋으로 합쳐 push(E1 이 「머지됨」)
#   E1 의 의도를 바꾼 표로 update → rc 1 · 「머지되거나 끝난 에픽은 바꾸거나 지우지 않는다 — E1」 · 나무 그대로
#   E1 의 지시 원문 범위만 바꾼 표로 update → rc 1 · 같은 글 · 나무 그대로(「아무것도 쓰지 않았다」 와 종료 코드 4 가 아니다)
#   머지되지 않은 E2 의 범위만 바꾼 표 → 종료 코드 4 그대로(양의 짝)
#   E2 의 범위를 「9–12 · 2–4」 로 적은 INTENT.md 와 「2–4 · 9–12」 인 표 → 손으로 고칠 것이 없다(rc 0 — 차례만 다르다)
# ── 잔여 ───────────────────────────────────────────────────────────────────
#   종류 전환: 묶음 E2 를 결정으로 바꾼 표 → rc 0 · jobs/E2 폴더 그대로 · 「사라진 에픽 E2」 알림 / 결정 P1 을 묶음으로 바꾼 표(범위 칸 채움) → jobs/P1/INTENT.md · .gitkeep 이 생긴다
#   「범위」 칸만 바꾼 표 → 종료 코드 4 와 「하지 않을 것:」 글
#   새 에픽 E3 자리에 손으로 둔 jobs/E3/sources.md 가 있으면 update → rc 1 · 「이 생성기가 만들지 않은 파일은 덮어쓰지 않는다」 · 그 파일 바이트 그대로
#   E1 의 INTENT.md 에서 범위 줄을 지운 뒤 extract → rc 1 · 출력에 그 INTENT.md 경로와 「지시 원문에 줄 범위가 없다」
#   brief 의 사용자 글에 「에픽마다 원본 brief · 이 로드맵 · 에픽 묶음을 넘긴다.」 가 든 사본으로 create --layout team → rc 0
#   job new --name E7 → rc 1 · 「에픽 번호 꼴」 · job new --name e7x → rc 0(꼴이 아니다)
```

`test_team_files.py` 에:

```python
class FramingHeads(unittest.TestCase):   # 잔여 — 경계 제목을 두 곳이 따로 적지 않는다
    def test_same_headings_as_the_audit_reader(self):
        import seed_review_log
        import team_write
        self.assertEqual(tuple(team_write.FRAMING_HEADS), tuple(seed_review_log.AUDIT_HEADINGS[:3]))

    def test_stage_pending_is_gone(self):
        import roadmap_write
        self.assertFalse(hasattr(L, "STAGE_PENDING"))
        self.assertFalse(hasattr(roadmap_write, "STAGE_PENDING_NOTICE"))
```

`test_workspace_invariance.sh` 5행 머리 주석의 「열 키」 를 「열두 키」 로 고친다(주석뿐 — T-g).

- [ ] **Step 2: 실패를 확인한 뒤 고친다**

Run: `bash plugins/spec-distill/tests/test_team_write.sh | grep '✗' | head; python3 -m unittest plugins/spec-distill/tests/test_team_files.py 2>&1 | tail -n 3`
Expected: 새 단언들이 실패한다. 그 뒤 위 인터페이스대로 고친다. `stages` 를 부르는 다른 자리가 `layout` 을 넘기면 함께 고친다(`grep -n 'stages(' plugins/spec-distill/scripts/*.py`).

- [ ] **Step 3: 통과와 회귀를 확인하고 커밋한다**

Run:
```bash
bash plugins/spec-distill/tests/test_team_write.sh | tail -n 1; bash plugins/spec-distill/tests/test_roadmap_write.sh | tail -n 1; bash plugins/spec-distill/tests/test_team_status_stub.sh | tail -n 1; bash plugins/spec-distill/tests/test_workspace_invariance.sh | tail -n 1
python3 -m unittest plugins/spec-distill/tests/test_team_files.py plugins/spec-distill/tests/test_team_layout.py plugins/spec-distill/tests/test_roadmap_render.py plugins/spec-distill/tests/test_roadmap_write.py
```
Expected: 모두 통과 — `test_team_write.sh` 가 Task 7 뒤 처음으로 전부 초록이다. `test_roadmap_write.sh` 의 옛 형식 다이제스트 단언은 고치지 않았다.

```bash
git add -- plugins/spec-distill/scripts/roadmap_write.py plugins/spec-distill/scripts/team_write.py plugins/spec-distill/scripts/team_layout.py plugins/spec-distill/scripts/roadmap_render.py plugins/spec-distill/tests/test_team_write.sh plugins/spec-distill/tests/test_team_files.py plugins/spec-distill/tests/test_workspace_invariance.sh
git commit -m "fix(spec-distill): team 형식의 재분해가 머지된 에픽을 다시 보호하고 계획 1 의 잔여를 닫는다" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

---

### Task 15: 출처 커밋을 읽지 못할 때의 대체 대조 — 결정 기록 B22 (AC13 은 그대로 · AC26 의 문서는 Task 16)

**Files:**
- Modify: `plugins/spec-distill/scripts/team_check.py`
- Test: `plugins/spec-distill/tests/test_team_write.sh`(T-c 와 「대체 대조:」 묶음)

**Interfaces:**
- `team_check.check_tree(top, team, base=None)` — 8번(출처와 바이트 같음)에서 출처 커밋의 파일을 읽지 못한 구간을 기준의 같은 파일 · 같은 줄과 견준다(Q19). 기준은 9번(덧붙이기 검사)과 같은 ref 다 — `base` 가 있으면 그것, 없으면 `roadmap_model.DEFAULT_REF`. 그 ref 를 커밋으로 푸는 일을 8번 앞으로 옮겨 한 번만 한다.
- 구간마다의 결과(`<자리>` 는 지금 8번이 쓰는 `<원자료 사본> <a>–<b>행(출처 <경로> · <절 이름> <c>–<d>행)` 글 그대로):

| 경우 | 어디에 | 글 |
|---|---|---|
| 출처 커밋에서 읽힌다 | (지금 그대로) | — |
| 못 읽었고 기준의 같은 줄과 바이트가 같다 | 알림 | `<자리>: 출처 커밋 <12자> 를 읽지 못해 기준 <ref> 의 같은 줄과 견줬다 — 같다` |
| 못 읽었고 기준의 같은 줄과 다르다 | 검사 불가 | `<자리>: 출처 커밋 <12자> 의 파일을 읽지 못했고 기준 <ref> 의 같은 줄과도 다르다 — 사본이 틀렸는지 출처가 그 뒤 고쳐졌는지 알 수 없다` |
| 못 읽었고 기준에 그 파일이 없다 | 검사 불가 | `<자리>: 출처 커밋 <12자> 의 파일을 읽지 못했고 기준 <ref> 에도 그 파일이 없다` |
| 못 읽었고 기준을 모른다 | 검사 불가 | `<자리>: 출처 커밋 <12자> 의 파일을 읽지 못했다 — 기준(<ref>)을 몰라 같은 줄과 견주지 못했다` |

- 종료 코드와 화면은 지금 길 그대로다 — 알림은 `check` 가 표준 오류로, 생성기 명령(`create --layout team` · `update` · `original` · `job new`)이 화면으로 낸다. 검사 불가가 남으면 `check` 는 3 이고 `create` · `update` 는 쓰지 않는다.

- [ ] **Step 1: 있는 묶음의 기대값을 고친다 (T-c)**

`test_team_write.sh` 의 「출처 커밋이 사라진 팀 폴더」 묶음에서 새 clone `sq2` 의 단언을 바꾼다(픽스처는 그대로 — 옮긴 두 절의 바이트가 기본 브랜치와 같다):

```bash
assert_eq "$(sqcheck "$T/sq2")" "0" "대체 대조: 출처 커밋이 없어도 기준의 같은 줄과 같으면 check rc 0"
assert_eq "$(grep -c "출처 커밋 ${stamp:0:12} 를 읽지 못해 기준 refs/remotes/origin/HEAD 의 같은 줄과 견줬다 — 같다" "$T/chk.txt")" "2" "대체 대조: 구간마다 알림 한 줄(원문 · 질문 전체)"
assert_not_contains "$(cat "$T/chk.txt")" "검사 불가" "대체 대조: 통과하면 검사 불가가 없다"
assert_eq "$(squpdate "$T/sq2" "$T/sq2-moved.md")" "0" "대체 대조: update 가 쓴다"
assert_contains "$(cat "$T/out.txt")" "를 읽지 못해 기준 " "대체 대조: update 가 알림을 화면에 낸다"
assert_eq "$(ttc "$T/sq2" "$T/sq.md" "${RD}sq")" "0" "대체 대조: create 다시 rc 0"
assert_eq "$(sqorig "$T/sq2")" "0" "대체 대조: original rc 0"
assert_not_contains "$(cat "$T/out.txt")" "검사 불가" "대체 대조: original 에 검사 불가 줄이 없다"
assert_eq "$(sqjob "$T/sq2")" "0" "대체 대조: job new rc 0"
assert_not_contains "$(cat "$T/out.txt")" "검사 불가" "대체 대조: job new 에 검사 불가 줄이 없다"
```

지우는 단언 — 「출처 커밋이 없다: check rc 3」 부터 그 묶음 끝까지의 `sq2` 단언(검사 불가 줄 · `update` · `create` 의 rc 1 · 「나무 그대로」). 양의 짝(`sq`)의 단언은 그대로 두고 하나를 더한다 — `sq` 의 `check` 출력에 「를 읽지 못해 기준」 이 **없다**(읽히는 커밋에는 대체 대조가 돌지 않는다).

- [ ] **Step 2: 검사 불가가 남는 갈래의 픽스처를 더한다**

```bash
# ── 대체 대조: 기준과도 다른 경우 · 기준에 파일이 없는 경우 · 기준을 모르는 경우 ─────────────
# sq3 — sq 의 main 에 커밋 하나를 더한다: framing audit 의 「원문」 절 안 한 줄의 글자 하나를 바꾼다(줄 수는 그대로) → push → 새 clone
#   check rc 3 · 「검사 불가 — 」 줄이 하나(원문 구간) · 「기준 refs/remotes/origin/HEAD 의 같은 줄과도 다르다」 · 질문 전체 구간은 알림 「 — 같다」
#   update rc 1 · 나무 그대로(snap 견줌) · create 다시 rc 1
# sq4 — sq3 의 main 에서 framing audit 파일을 git rm → push → 새 clone
#   check rc 3 · 「기준 refs/remotes/origin/HEAD 에도 그 파일이 없다」 가 두 줄
# sq5 — sq2 와 같은 새 clone 에서 `git remote set-head origin -d`
#   check rc 3 · 「기준(refs/remotes/origin/HEAD)을 몰라 같은 줄과 견주지 못했다」 · 「덧붙이기 검사를 건너뛰었다」 알림은 지금 그대로
#   check --base main → rc 0 · 「기준 main 의 같은 줄과 견줬다 — 같다」
#   check --base no-such-ref → rc 3(지금 그대로 — 기준을 읽지 못했다)
# 줄 수가 달라진 기준(sq 의 main 에서 「원문」 절 맨 앞에 한 줄을 더한 사본 sq6) → 같은 줄 번호의 글이 달라 검사 불가(「같은 줄과도 다르다」)
```

주석으로 적은 것도 단언으로 옮긴다.

- [ ] **Step 3: 실패를 확인한 뒤 `team_check.py` 를 고친다**

Run: `bash plugins/spec-distill/tests/test_team_write.sh | grep '✗' | head`
Expected: 「대체 대조:」 단언들이 실패한다(지금은 `sq2` 가 3 이다). 그 뒤 고친다 — 읽기는 지금 있는 `show(top, commit, rel)` 하나로 한다(`GIT_ALLOWED` 를 넓히지 않는다).

- [ ] **Step 4: 통과와 회귀를 확인하고 커밋한다**

Run: `bash plugins/spec-distill/tests/test_team_write.sh | tail -n 1; bash plugins/spec-distill/tests/test_roadmap_status.sh | tail -n 1; python3 -m unittest plugins/spec-distill/tests/test_team_files.py`
Expected: 모두 통과.

```bash
git add -- plugins/spec-distill/scripts/team_check.py plugins/spec-distill/tests/test_team_write.sh
git commit -m "fix(spec-distill): 출처 커밋을 읽지 못하면 기준의 같은 줄과 견준다" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

---

### Task 16: 형식 정본 문서 §5 · §10 · README · 판 · 끝에서 끝 · 옛 형식 대조 · 변이 (AC26 · AC13 · AC28)

**Files:**
- Modify: `plugins/spec-distill/references/team-files.md` · `README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json`
- Test: `plugins/spec-distill/tests/test_team_docs.py`(T-e 와 새 테스트) · `test_team_tasks.sh`(끝에서 끝 묶음)

**Interfaces:**
- Consumes: 앞 과제의 모든 이름. 새 인터페이스는 없다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_team_docs.py` — `test_sections_of_this_plan` 의 기대 목록을 일곱으로 고친다(T-e): `["## §1 팀 폴더", "## §2 과제 폴더와 INTENT.md", "## §3 원자료", "## §4 sources.md", "## §5 결과 파일", "## §6 역할 문서", "## §10 단계 계산"]`. 그리고 더한다:

```python
def section(text, head):
    return text.split(head + "\n", 1)[1].split("\n## ", 1)[0]


class ReadSideDoc(unittest.TestCase):   # R1 AC26 — 계획 2 몫
    def test_section5_names_come_from_the_code(self):
        s5 = section(DOC.read_text(encoding="utf-8"), "## §5 결과 파일")
        for name in L.STAGES + F.DECISION_KINDS + F.BLOCKED_HEADS + (L.BLOCKED_FILE, F.RESULT_TYPE, F.BLOCKED_TYPE, "bundle_at", "job_at", "job sync",
                                                                     "job_results.py check", "Task <n>/<전체>: 끝|막힘 — <커밋>", "끝 — <커밋>",
                                                                     "- 결과 받음 · <YYYY-MM-DD> · 「<결과 파일 이름> · <커밋> · <대조 첫 줄>」"):
            self.assertIn(name, s5, name)

    def test_section10_names_the_stages_and_notices(self):
        s10 = section(DOC.read_text(encoding="utf-8"), "## §10 단계 계산")
        for word in ("설계 중", "계획", "구현 중", "구현 끝", "진행 중", "결과 받음", "결과 있음 · 받음 없음", "받은 뒤 바뀜", "받음 줄을 세지 않았다",
                     "막힘", "예약 밖 변경", "경로 예약 위반", TS.UNPUSHED, TS.SPLIT, "로드맵 밖 과제", "진행 줄 없음", "branch_tip.py"):
            self.assertIn(word, s10, word)

    def test_results_point_instead_of_copying(self):   # AC28
        text = DOC.read_text(encoding="utf-8")
        self.assertIn("옮겨 싣지 않고 커밋과 경로로 가리킨다", section(text, "## §5 결과 파일"))
        for row in text.splitlines():
            if "테스트 출력" in row:
                self.assertTrue("싣지 않" in row, row)   # 어디에도 테스트 출력을 실으라는 요구가 없다

    def test_no_build_schedule_words(self):   # 잔여 — 설치본만 읽는 사람이 풀 수 없는 글
        text = DOC.read_text(encoding="utf-8")
        for word in ("이 판은", "이 판의", "이 판에는", "다음 판", "(R3)", "계획 2"):
            self.assertNotIn(word, text, word)
        self.assertNotIn("머지 여부를 확인하지 못했다", text)
        self.assertIn("기준", section(text, "## §3 원자료"))   # 대체 대조(B22)를 적었다

    def test_readme_names_the_read_side(self):
        text = README.read_text(encoding="utf-8")
        principles = text.split("## Principles Instantiated", 1)[1].split("\n## ", 1)[0]
        self.assertIn("job_results.py", principles)
        for name in ("job sync", "job_results.py check", "workflow_superpowers.py", "로드맵 밖 과제", "결과 받음"):
            self.assertIn(name, text, name)
        self.assertNotIn("이 판에는 출처 줄의 커밋을 고치는 명령이 없습니다", text)


READ_WORDS = ("job_results.py", "job sync", "workflow_superpowers.py", "결과 받음", "로드맵 밖 과제")


class ReadSideVersion(unittest.TestCase):   # 판 글자를 못 박지 않는다(판정 R-R 의 꼴)
    def entries(self, words):
        log = (PLUGIN / "CHANGELOG.md").read_text(encoding="utf-8")
        out = []
        for chunk in log.split("\n## [")[1:]:
            version = chunk.split("]", 1)[0]
            if all(w in chunk for w in words):
                out.append(version_tuple(version))
        return out

    def test_one_entry_after_the_format_entry(self):
        mine, first = self.entries(READ_WORDS), self.entries(WORDS)
        self.assertEqual((len(mine), len(first)), (1, 1), (mine, first))
        self.assertGreater(mine[0], first[0])   # 읽기 쪽 판이 형식 쪽 판 뒤다
        current = version_tuple(json.loads((PLUGIN / ".claude-plugin" / "plugin.json").read_text(encoding="utf-8"))["version"])
        self.assertGreaterEqual(current, mine[0])
```

`test_team_docs.py` 맨 위에 `import team_status as TS` 를 더한다.

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_docs.py 2>&1 | tail -n 5`
Expected: 절 수 · §5 · §10 · 판 FAIL.

- [ ] **Step 3: `references/team-files.md` 를 고친다**

구현된 대로 적는다. 이 문서는 자기 출처(어느 설계 · 어느 계획이 만들었나)를 적지 않고 `## ` 로 시작하는 줄은 일곱 제목뿐이다(예시의 제목 꼴 줄은 펜스 안 · 들여쓴 꼴로).

- **§5 결과 파일**(§4 와 §6 사이) — 이름 규칙(`<단계>[-plan-<n>]-<시도>.md`, 단계 넷, `design` 은 계획 번호 없음) · 머리 키 여덟과 값의 꼴 · 기계가 읽는 줄 여섯(펜스 밖 · 줄 머리) · 「끝」 줄과 머리 `head` 가 같아야 한다 · 시도 번호의 규칙(Q1) · `roadmap_write.py job sync` 의 세 쓰임(만들기 · 원장에서 줄 내기 · 끝내기)과 종료 코드 · 원장이 정본이고 `Task` · `Ruling:` 줄은 스크립트가 낸 사본이다 · 「결과 파일에는 테스트 출력을 옮겨 싣지 않고 커밋과 경로로 가리킨다」 · 검수 결과 파일은 리더가 쓴다(첫 줄에 반려 여부, 그 아래 지적 목록) · 막힘 파일(머리 · 두 칸 · 결과 파일로 세지 않는다 · 풀면 지우고 `결정` 줄) · 결과 대조(`job_results.py check` 의 인자 · 보는 것 아홉 · 첫 줄의 꼴 · 종료 코드 0 · 1 · 2 · 3) · 받음 줄의 꼴과 쓰는 길(`conductor_ledger.py record --spec <과제 폴더의 파일> --line …`) · 결정 기록에 쓸 수 있는 줄(종류 일곱 · `넘김 확인` 의 꼴) · 계획마다의 수용 기준 범위(Q4).
- **§10 단계 계산**(맨 끝) — 형식 표시가 가르는 것(없음 · `team` · 모르는 값) · 단계 표(Task 7 의 표 — 설계 흐름과 설계 없는 흐름, 가르는 기준 Q5) · PR · 머지됨 · 일부 머지는 옛 형식과 같은 판정 · 브랜치 하나가 계획 하나 · 알림 목록과 뜻(결과 있음 · 받음 없음 · 받음 줄을 세지 않았다 · 받은 뒤 바뀜 · 막힘 · 진행 줄 · 예약 밖 변경 · 경로 예약 위반 · INTENT.md 어긋남 · 번호 대조 알림)과 「모두 종료 코드를 바꾸지 않는다」 · 받은 뒤 바뀜이 보는 것과 보지 못하는 것(merge 커밋 안의 손 고침 — Q6) · 브랜치 끝 읽기 네 경우와 둘 더(끝 고르기는 `scripts/branch_tip.py` 하나) · 갈라진 과제의 다룸(Q10) · 로드맵 밖 과제(찾는 범위 · 머리 `branch` · 단계 셋 · PR 단계는 싣지 않는다) · 계산 결과의 칸(`layout` · `jobs` · `job_notes` · 블록의 `progress` · `job` — team 로드맵에만) · 현황에 보이는 꼴(`<단계> <n>/<전체>` · 「정보:」 줄 · 「로드맵 밖 과제:」) · 번호 대조(번호 파일이 정답 · 기본 브랜치의 것을 읽는다 · `## 원문 대조` 표) · 넘김과 미룸은 설계문서의 `## 미룸` 표, 판정은 결과 파일의 `Ruling:` 줄에서.
- **고칠 문장** — §1 의 「이 판의 단계 계산」 항목을 「단계 계산」 으로 바꿔 §10 을 가리키게 한다(번호 파일이 없으면 형식 오류라는 문장은 남긴다). §1 의 「(R3)」 둘은 「내용과 계약은 아직 정하지 않았다」 로. §2 의 `update` 끝 항목(「이 판은 … 머지된 에픽을 가려 보호하지 못한다」)은 「머지되거나 끝난 에픽은 바꾸거나 지우지 않는다 — 지시 원문 범위만 바꾼 표도 같다」 로. §2 의 「로드맵 블록의 의도 · 범위는 …」 항목에 「단계 계산도 그 과제 번호와 함께 알린다(§10)」 를 더한다. §2 의 `job new` 거절 목록에 에픽 번호 꼴의 이름을 더한다. §3 의 「출처와 바이트 같음」 항목을 대체 대조(Task 15 의 표)로 다시 쓴다 — 「이 판에는 … 명령이 없다」 와 「지금 할 수 있는 것은 둘이다」 문장은 지우고, 검사 불가가 남는 세 경우와 그때 할 수 있는 일(출처 파일을 기준에서 되돌리거나 `--base` 로 그 줄이 그대로인 ref 를 준다)을 적는다. 「계획 3 이 §15 로 적는다」 넷과 §6 의 「지휘 절차 개편(R2)」 둘은 고치지 않는다(Q22).

- [ ] **Step 4: README · CHANGELOG · 판을 고친다**

- README `## 로드맵 · 에픽 묶음` — team 항목 뒤에 항목 셋을 더한다: `scripts/roadmap_write.py job sync`(결과 파일 맞추기) · `scripts/job_results.py check`(결과 대조 — 종료 코드 0 · 1 · 2 · 3, 통과하면 리더가 적을 받음 줄을 낸다) · `scripts/workflow_superpowers.py`(다른 작업 방식의 꼴을 읽는 한 곳). 단계 계산 설명에 team 형식 한 문단(단계 표는 `references/team-files.md` §10 · 알림은 종료 코드를 바꾸지 않는다 · 「로드맵 밖 과제」). `team_layout.py check` 항목의 출처 커밋 문장을 대체 대조로 고친다(「이 판에는 … 없습니다」 를 지운다). `conductor_ledger.py` 항목에 team 형식의 쓸 자리 한 문장.
- README `## Principles Instantiated` 에 한 줄: `- **Law 2 — 결과는 대조한 뒤에만 받는다** — team 형식의 일꾼 보고는 과제 폴더의 결과 파일이다. 일꾼이 쓸 수 있는 파일이라 그대로 믿지 않는다 — 리더가 `scripts/job_results.py check` 로 대조한 뒤에만 받음 줄을 쓰고, 단계 계산은 그 줄이 가리키는 결과 파일로 대조를 다시 계산해 통과할 때만 센다. 받은 뒤 산출물이 바뀌면 그 줄은 낡는다.`
- `plugin.json` 의 판을 지금 판의 다음 minor 로(Task 1 Step 3 에서 `8.15.0` 이었으면 `8.16.0`). CHANGELOG 맨 위에 `## [<새 판>] — <커밋 날짜>`:
  - `### Added` — team 형식의 단계 계산(단계 표 · 진행 칸 · 알림 · 로드맵 밖 과제) · `job_results.py check` 와 결과 받음 줄 · `roadmap_write.py job sync` · `workflow_superpowers.py`(`place`) · `team_status.py` · 번호 대조의 team 형식(번호 파일 · `## 원문 대조` 표 · 결과 파일의 AC 줄) · spec-review 진입이 INTENT.md 를 받는다 · team 형식의 넘김 줄 · 현황의 진행 숫자와 「로드맵 밖 과제」.
  - `### Changed` — `conductor_ledger.py record` · `flush` 가 team 형식에서 INTENT.md 결정 기록에 쓴다 · `write-sections` 는 team 형식에서 쓰지 않고 알린다 · `pr-handoffs` · `pr-refresh` 가 단계를 세지 못한 블록에서 3 으로 멈춘다(전에는 「브랜치 없음」 과 0) · team 형식의 `update` 가 머지되거나 끝난 에픽을 다시 보호한다(범위만 바꾼 표 포함) · 출처 커밋을 읽지 못하면 기준의 같은 줄과 견준다 · `branch_tip.py` 가 읽기 전용 락의 대상이 됐다 · 상태 계산이 기대는 읽기 전용 모듈과 코드 지문 목록에 더해진 파일들 · `check_bundle_coverage.plan_task_text` 가 `workflow_superpowers.task_text` 로 옮겨졌다.
  - `### Fixed` — 계획 1 의 잔여(범위 읽기 한 곳 · `kind` 판정 · `extract` 의 오류 자리 · 남의 번호 파일 덮어쓰기 · 에픽 번호 꼴의 과제 이름 · 범위 차례).
  - 이 항목에 `rules_budget` 과 `handbook_budget` 을 함께 적지 않는다(지난 판 항목을 고르는 판 테스트가 낱말 다섯으로 항목을 찾는다). 지난 판 항목은 고치지 않는다.

- [ ] **Step 5: 끝에서 끝과 옛 형식 대조를 돈다**

`test_team_tasks.sh` 끝에 한 흐름을 더한다(설계 Verification Plan 의 「끝에서 끝」 가운데 이 계획 몫 — 시작 묶음은 계획 3 이 끼운다):

```bash
# create --layout team(team_repo) → job new(e2e-job · 브랜치 fix/e2e · --paths docs/e2e.md) → 커밋 → docs/e2e.md 커밋(CODE)
#   → job sync(머리 만들기) → 「산출물: docs/e2e.md」 를 더하고 job sync --end "$CODE" → 커밋 · push
#   → job_results.py check --branch fix/e2e 의 받음 줄을 conductor_ledger.py --root "$W" record --spec <그 과제 INTENT.md> --line 으로 적는다 → 커밋 · push
#   → status: jobs 의 e2e-job 이 「결과 받음」 · control_plane.py show 에 「로드맵 밖 과제:」 와 그 줄
assert_eq "$(js "$T/s.json" "[j['stage'] for j in r['jobs'] if j['id']=='e2e-job']")" "['결과 받음']" "끝에서 끝: 대조 → record 의 받음 줄 → 단계가 넘어간다"
```

옛 형식 대조(AC13) — Task 7 Step 1 의 `$TMPDIR/base`(시작 커밋의 스크립트)와 지금 스크립트를 같은 입력에 돌려 바이트로 견준다:

```bash
git clone -q . "$TMPDIR/cmp" && git -C "$TMPDIR/cmp" remote set-head origin --auto >/dev/null
RD="$(cd "$TMPDIR/cmp" && python3 plugins/spec-distill/scripts/repo_defaults.py get roadmaps_dir)"; SP="$(cd "$TMPDIR/cmp" && python3 plugins/spec-distill/scripts/repo_defaults.py get specs_dir)"
for side in base head; do
  S="$TMPDIR/base/plugins/spec-distill/scripts"; [ "$side" = head ] && S="$PWD/plugins/spec-distill/scripts"
  ( cd "$TMPDIR/cmp" && for rm in $(git ls-tree -r --name-only origin/HEAD -- "$RD" | grep '/roadmap\.md$'); do
      python3 "$S/roadmap_status.py" "$rm"; python3 "$S/roadmap_status.py" "$rm" --json
      python3 "$S/control_plane.py" show "$rm"; python3 "$S/control_plane.py" show --tasks "$rm"
      d="$(dirname "$rm")"; for b in "$d"/R*.md "$d"/P*.md; do [ -f "$b" ] || continue
        for sp in $(grep -l "source_interview: $b" "$SP"*.md 2>/dev/null); do
          python3 "$S/check_bundle_coverage.py" "$b" "$sp"; python3 "$S/check_bundle_coverage.py" "$b" "$sp" --json; done; done
    done ) > "$TMPDIR/out.$side" 2>&1
done
cmp "$TMPDIR/out.base" "$TMPDIR/out.head" && echo "옛 형식 출력 같음"
```

Expected: 「옛 형식 출력 같음」. 다르면 `diff` 를 읽는다 — 줄이 「받은 시각」 · 캐시 알림처럼 실행마다 달라지는 것이면 그 줄을 빼고 다시 견주고, 그 밖의 차이는 고친다(옛 형식의 출력은 한 글자도 바뀌지 않아야 한다). 이 레포의 로드맵은 모두 옛 형식이다. 견준 명령과 결과를 마지막 리뷰에 싣는다.

- [ ] **Step 6: 통과와 락을 확인하고 커밋한다**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_team_docs.py plugins/spec-distill/tests/test_team_layout.py plugins/spec-distill/tests/test_team_files.py plugins/spec-distill/tests/test_team_results.py plugins/spec-distill/tests/test_workflow_superpowers.py plugins/spec-distill/tests/test_control_plane.py plugins/spec-distill/tests/test_conductor_ledger.py plugins/spec-distill/tests/test_roadmap_model.py
for t in test_team_status test_team_status_stub test_team_tasks test_team_sync test_job_results test_team_coverage test_team_review_entry test_team_write test_roadmap_status test_roadmap_write test_bundle_coverage test_spec_review_bundle test_control_plane test_default_branch test_seed_gate_wiring test_merge_check test_readme_sync test_repo_literals test_check_brief test_parallel_recommend_docs test_workspace_invariance; do printf '%s ' "$t"; bash plugins/spec-distill/tests/$t.sh | tail -n 1; done
python3 -m unittest plugins/quality-gates/tests/test_utf8_explicit.py
for t in test_python_floor test_no_new_duplication test_changelog_integrity test_shell_tests_executable test_skill_reference_pointers; do bash shared/tests/$t.sh | tail -n 1; done
```
Expected: 모두 통과.

```bash
git add -- plugins/spec-distill/references/team-files.md plugins/spec-distill/README.md plugins/spec-distill/CHANGELOG.md plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/tests/test_team_docs.py plugins/spec-distill/tests/test_team_tasks.sh
git commit -m "docs(spec-distill): 팀 파일 형식 정본 문서 §5 · §10 과 읽기 쪽 판" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

- [ ] **Step 7: 분기와 픽스처를 다시 대조한 뒤 변이로 이빨을 본다 (커밋한 뒤에 흔든다)**

먼저 `## 코드 분기 × 픽스처` 표를 지금 코드와 견준다 — 표의 함수마다 실제 분기(`if` · `except` · 일찍 돌아가는 자리)를 읽어, 표에 없는 분기가 있으면 픽스처를 더해 커밋하고 표 끝에 줄을 덧붙인다(계획 파일을 고쳐 같은 커밋에 넣는다). 그 뒤 변이마다 한 줄을 바꾸고 → 해당 테스트가 빨개지는지 보고 → `git checkout HEAD -- <파일>` 로 되돌리고 `git diff HEAD --stat` 이 비었는지 확인한다. `PYTHONDONTWRITEBYTECODE=1` 로 돈다. 지우기뿐 아니라 더하기 · 뒤집기로도 흔든다.

| 변이 | 축 | 빨개져야 하는 것 |
|---|---|---|
| `team_status.read_tip` 이 알림을 늘 None 으로 낸다 | 지우기 | `test_team_status.sh` 「끝: 로컬이 앞섬」 · 「끝: 로컬에만 있는 브랜치」 |
| `read_tip` 이 `TipError` 를 삼키고 로컬 끝을 낸다 | 뒤집기 | 「끝: 갈라짐 — 읽지 않는다」 |
| `build` 가 team 로드맵에도 `Reader` 를 넘기지 않는다(옛 계산으로 읽는다) | 지우기 | 「단계: 승인 줄 — 계획」 |
| `Reader.progress` 가 받음 상태를 늘 `RECEIVED` 로 본다 | 뒤집기 | 「단계: implement 결과 파일 — 구현 중」 · 「AC10: 결과 있음 · 받음 없음」 |
| `job_results.receipt` 가 `touched` 를 부르지 않는다 | 지우기 | 「받은 뒤 바뀜: implement-plan-1-1.md — src/e1/b.txt」 |
| `Git.touched` 에서 `--no-merges` 와 기본 브랜치 제외를 뺀다 | 지우기 | 「합쳐 들어온 변경은 세지 않는다」 |
| `receipt` 가 과제 폴더의 모든 파일을 볼 자리에 남긴다 | 더하기 | 「INTENT.md 에 「결정」 줄만 더한 커밋 → 구현 끝 그대로」 |
| `check_result` 가 「끝」 줄 없음을 사유로 내지 않는다 | 지우기 | `test_job_results.sh` 「no-end」 |
| `check_result` 가 `head` 와 「끝」 의 커밋을 견주지 않는다 | 지우기 | 「end-differs」 |
| `plan_scope` 가 늘 수용 기준 전부를 낸다 | 뒤집기 | 「대조: 첫 줄(범위는 계획 1 의 AC 둘 …)」 |
| `parse_result` 가 펜스를 보지 않는다 | 지우기 | `test_team_results.py` `test_fenced_lookalikes_are_body` |
| `ledger_lines` 가 같은 줄을 거르지 않는다 | 지우기 | `test_workflow_superpowers.py` `test_lines_in_ledger_order` |
| `cmd_job_sync` 가 있는 줄도 다시 붙인다 | 더하기 | `test_team_sync.sh` 「AC27: 두 번 돌려도 …」 |
| `team_status.outside` 가 다른 과제의 예약을 빼지 않는다 | 지우기 | 「AC11: 다른 과제가 예약한 파일은 예약 밖 변경이 아니다」 |
| `task_jobs` 가 머리 `branch` 를 그 브랜치 이름과 견주지 않는다 | 지우기 | `test_team_tasks.sh` 「AC14: 머리의 branch 가 그 브랜치와 다르면 세지 않는다」 |
| `control_plane.show_text` 가 옛 형식에서도 「정보:」 줄을 낸다 | 더하기 | `test_control_plane.py` `test_old_reports_render_as_before` |
| `check`(번호 대조)가 옛 묶음에도 `notices` 칸을 싣는다 | 더하기 | `test_team_coverage.sh` 「옛 형식: … 'notices' 키가 없다」 |
| `check` 가 「그대로」 행도 얕은 답으로 센다 | 더하기 | `test_team_coverage.sh` 「「그대로」 에 근거가 빈 행 → 얕은 답 0개」 |
| `c_record` 의 team 갈림을 지운다 | 지우기 | `test_conductor_ledger.py` `TeamRecords.test_record_goes_to_the_job_file` |
| `cmd_update` 가 범위만 바뀐 과제를 머지 검사에서 뺀다 | 지우기 | `test_team_write.sh` 「E1 의 지시 원문 범위만 바꾼 표 → rc 1」 |
| `team_check` 의 대체 대조에서 견줌을 늘 참으로 둔다 | 뒤집기 | 「대체 대조: sq3 — check rc 3」 |
| `team_check` 의 대체 대조를 지운다(읽지 못하면 바로 검사 불가) | 지우기 | 「대체 대조: 출처 커밋이 없어도 … check rc 0」 |
| `workflow_superpowers.py` 밖의 스크립트 하나에 `"### Task"` 글자를 더한다 | 더하기 | `test_workflow_superpowers.py` `test_only_the_adapter_spells_the_heading` |

살아남는 변이가 있으면 그 테스트(또는 픽스처)를 고쳐 다시 커밋한다.

- [ ] **Step 8: 전체 스위트는 컨트롤러가 끝에 한 번 돈다**

Global Constraints 의 공유 잠금 줄로 `bash tools/suite/run-all.sh` 를 돈다(과제 구현자가 아니라 컨트롤러가, 마지막 전체 리뷰의 수정 물결 뒤에).
Expected: `FAILED` 줄이 없다. 이 브랜치의 시작 커밋에서도 떨어지는 기존 실패(계획 1 의 끝 스위트가 본 다섯 — 설계문서 `## 지휘 기록` 2026-11-15 줄에 이름이 있다)가 보이면 `BASE` 사본에서도 떨어지는지 확인해 「기존 실패」 로 보고하고, 그 밖의 실패는 고친다.

---

## 마지막 전체 리뷰 (실행 방식 공통)

고른 실행 방식의 마지막 전체 리뷰에 설계문서 `## Acceptance Criteria` 의 AC 목록(AC1–AC31)을 싣고, 리뷰가 AC 마다 한 줄씩 `AC1: 구현됨 — 근거` 꼴(판정은 구현됨 · 미룸 · 빠짐 가운데 하나)로 보고하게 한다. 이 계획의 몫은 AC9 · AC10 · AC11 · AC13 · AC14 · AC15 · AC16 · AC17 · AC27 · AC28 · AC29 · AC30 과 AC26(계획 2 몫)이다. AC1–AC8 · AC12 · AC18 은 계획 1 이 구현했고, AC19–AC25 · AC31 은 「미룸 — 계획 3」 이다(설계 §14 의 나눔). AC24 의 「`bundle_at` · `job_at` 이 실재하는 커밋이 아니면 대조가 거절한다」 는 이 계획의 결과 대조가 이미 한다 — 판정은 「미룸 — 계획 3」 으로 두고 근거에 그 사실을 적는다.

리뷰에 함께 묻는 것:

- 끝에서 끝 — `create --layout team` → `job new` → `job sync` → 결과 파일 커밋 → `job_results.py check` → `conductor_ledger.py record` 의 받음 줄 → 단계 계산이 넘어가는 것이 한 임시 레포에서 이어지는가. 각 명령의 종료 코드를 다음 걸음이 어떻게 읽는가(`job_results.py check` 의 3 과 1 · `pr-refresh` 의 3 · `job sync` 의 1).
- 옛 형식 — Task 16 Step 5 의 대조가 「같음」 인가, 그리고 있는 테스트를 고친 곳이 `## 설계에 없던 결정` 의 T-a – T-g 뿐인가(고친 단언마다 (a) 기대값 · (b) 목록 · (c) 새 단언으로 갈라 표로). 옛 형식의 단계 계산 · 현황 · 번호 대조의 기대값이 하나라도 바뀌었으면 Important 다.
- 계획이 적어 준 테스트 코드 자체(plan-mandated) — 단언이 통과가 정답인 꼴뿐이라 이빨이 없는 곳, 픽스처가 분기 하나를 통째로 가리는 곳. `## 코드 분기 × 픽스처` 표의 줄마다 그 분기가 실제로 테스트에 닿는지 본다(표에 이름만 있고 단언이 없는 줄을 찾는다).
- 읽기 전용 — 새 모듈 셋과 `branch_tip.py` 가 정적 락의 목록에 있고 규칙과 허용 목록이 그대로인가. 상태 계산이 team 로드맵을 읽으며 쓰는 것이 없는가(실행 전후 나무 비교).
- 과제 사이 이음매 — `job sync` 가 쓴 머리를 `parse_result` 가 읽고, `job_results.py check` 가 낸 받음 줄을 `append_decision` 이 받으며, 그 줄을 `receipt` 가 다시 읽는가(세 과제의 글자가 한 줄로 이어지는가). `control_plane.py` 가 읽는 칸 이름이 `build` 가 싣는 이름과 같은가.
- 「설계에 없던 결정」 Q1–Q24 가 코드와 문서에 그대로 반영됐는가.

그 보고를 git 이 추적하지 않는 파일(리더가 준 임시 폴더)에 적는다. 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올리고(구현 담당자는 설계문서를 고치지 않는다 — 후보를 보고에 싣고 리더가 올린다), PR 을 만들기 전에

```bash
python3 <spec-distill>/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-14-team-file-contract-design.md <보고 파일> --acs "AC9~AC11 · AC13~AC17 · AC26~AC30"
```

를 돌려 경고를 사용자에게 보인다. 사람에게 쓰는 글은 첫 줄에 상태, 번호 · 해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 끝에 할 일(기본 하나 — 여럿이거나 병렬이면 밝힌다)을 둔다.



