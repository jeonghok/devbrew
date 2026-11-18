# 팀 파일 규약 · 계획 3 — 규칙과 시작 묶음 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 팀 규칙 파일(RULES.md · HANDBOOK.md)을 검사하는 명령과, 일꾼에게 줄 글을 커밋을 못 박아 만드는 시작 묶음 명령을 두고, 도는 일꾼의 묶음이 낡았는지를 현황에 알리며, devbrew 레포에 REVIEW.md · HANDBOOK.md · 역할 문서 넷을 둔다 — 옛 형식의 출력은 바이트 하나 바꾸지 않는다.

**Architecture:** 규칙 줄의 문법을 아는 곳은 새 모듈 `team_rules.py` 하나이고, 묶음을 짓는 곳은 새 모듈 `start_bundle.py` 하나다. 둘 다 읽기만 하고 git 은 `roadmap_status.Git` 으로 읽는다. 「리더가 쓰는 파일을 읽을 ref」 는 `team_layout.leader_ref()` 한 함수가 내고, 묶음과 「묶음 낡음」 알림이 그 함수를 부른다. 「묶음 낡음」 은 있는 `team_status.Reader` 에 얹어 상태 계산이 새 로컬 모듈을 import 하지 않게 한다. 앞 계획이 넘긴 수리(결과 파일 이름 꼴 · 얕은 클론 가드 · task 절 수 · `roadmap:` 경로)는 그 코드가 사는 모듈에서 고친다.

**Tech Stack:** Python 3.9 문법 · 표준 라이브러리만(레포 스위트가 `python3` 3.9.6 으로 돈다), bash 3.2 호환 셸 테스트(`shared/tests/assert.sh` · `tests/fixtures/team_repo.sh`), git.

**Spec:** `docs/superpowers/specs/2026-11-14-team-file-contract-design.md`

이 계획은 설계 §14 의 셋 가운데 셋째다. 수용 기준은 AC19 · AC20 · AC21 · AC22 · AC23 · AC24 · AC25 · AC31 과 AC26 의 계획 3 몫(형식 정본 문서 §7 · §8 · §9 · §15, 판 올림, CHANGELOG, README, 스크립트 락)이다. 앞 계획 둘이 넘긴 것은 `## 앞 계획이 넘긴 것` 표에서 과제로 받았다. 설계의 글자 · 수용 기준 · 사용자에게 보이는 동작에 닿는 결정은 이 계획이 정하지 않았다 — `## 설계에 없던 결정` 의 U 행으로 모았고, 과제는 추천 안을 바탕으로 쓰되 답이 다르면 바뀌는 자리를 과제마다 「다른 안이면」 줄이나 괄호 안의 「U… 이 나 면」 으로 적었다.

## Global Constraints

- 브랜치: `feature/team-file-rules`(이미 있다 — 계획 2 의 브랜치 위에 쌓였다). 커밋은 Conventional Commits, 설명은 한국어(예: `feat(spec-distill): 시작 묶음`). 구현 커밋마다 끝에 두 줄 — `Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md` 와 하니스가 일러 준 `Co-Authored-By:` 줄. `git add -- <경로>` 로 고친 파일만 올린다.
- 옛 형식(로드맵 머리말에 `layout` 없음)의 출력은 바이트까지 그대로다 — 단계 계산(글 · `--json`) · 현황(`control_plane.py show` · `show --tasks`) · 번호 대조(글 · `--json`). 있는 테스트의 기대값은 `## 설계에 없던 결정` 의 T 행에 적은 자리만 고친다 — 그 밖의 있는 단언이 빨개지면 고치지 않고 멈춰 보고한다.
- 새 형식을 기본으로 켜지 않는다(R2). 지휘 절차서(`references/conducting.md` · `conductor-dispatch.md`) · skill 본문 · 끝맺음 절차(`finishing.md`) · 재분해 절차(`redecompose.md`) · 리뷰어 프로필 · `conductor_state.py` · `dependencies.md` · 설계문서는 고치지 않는다. 설계문서에 올릴 것(미룸 행 · 지휘 기록 줄)은 보고에 싣고 리더가 올린다.
- 경로 조각(`jobs/` · `intent/` · `results/` · `RULES.md` · `HANDBOOK.md`)의 글자는 `team_layout.py` 에만 둔다 — `tests/test_team_layout.py` 의 `LiteralsLiveInOnePlace` 가 `scripts/*.py` 의 주석 · docstring · 메시지 글자까지 잡는다. 새 스크립트의 메시지는 `team_layout.RULES_FILE` 같은 상수나 받은 경로로 짓는다. 단계 이름 · 역할 이름도 `team_layout` 밖에서는 글자로 쓰지 않는다(`team_layout.STAGES[i]` · `team_layout.ROLES` · 이 계획이 더하는 `LEADER_ROLE` · `default_role`).
- 규칙 줄의 표지(`조건:` · `출처:` · `확인:` · `반례 확인:`)와 조건 키(`역할` · `단계` · `경로`)는 `team_rules.py` 에만 둔다. 시작 묶음과 단계 계산은 규칙 줄을 풀어 읽지 않는다.
- 읽기 전용: `team_rules.py` · `start_bundle.py` 는 파일을 쓰지 않고(쓰기 모드 `open` · `shutil` 없음) `subprocess` 를 import 하지 않으며 git 은 `roadmap_status.Git`(`GIT_ALLOWED` 의 하위 명령)으로만 읽는다. 묶음은 표준 출력으로만 나간다.
- 상태 계산이 기대는 모듈(`roadmap_status.py` 가 직접 · 간접으로 import 하는 것)에 새 로컬 import 를 더하지 않는다 — `team_status.py` 는 `team_rules.py` · `start_bundle.py` 를 import 하지 않는다. 그래서 `tests/test_roadmap_status.sh` 의 정적 검사 수(`CHECKED 14`)와 `control_plane.CODE_STAMP_FILES` 는 그대로다. 구현하다 import 가 필요해지면 그 두 곳과 사본 줄 둘을 함께 고치고 보고한다.
- 새 스크립트의 레포 락: 파일을 열 때 `encoding="utf-8"`(바이트는 `"rb"`), 인터프리터 이름 글자(`"python3"`)를 쓰지 않고 `sys.executable`, 모듈 수준 `re.compile` 에 `##` 로 시작하는 제목 패턴이나 `r".*"` · `r"^(\S+)"` 같은 넓은 패턴을 두지 않는다(제목은 문자열 비교), 비신뢰 입력의 꼴 검사는 `fullmatch`, 한글이 긴 줄은 인접 문자열로 나눈다, 다른 파일과 20줄이 같은 블록을 두지 않는다.
- 새 셸 테스트: `chmod +x` 뒤 `git ls-files -s <파일>` 이 `100755`. 한글 바로 앞의 변수는 `${v}`. `PYTHONDONTWRITEBYTECODE=1`. 팀 레포는 `tests/fixtures/team_repo.sh` 를 source 해 만든다(픽스처 글을 테스트마다 다시 쓰지 않는다 — 20줄 중복 락).
- 변이는 worktree 밖의 버리는 사본에서만 돈다 — `git archive HEAD | tar -x -C <리더가 준 임시 폴더>/mut` 로 푼 사본의 스크립트를 고쳐 그 사본의 테스트를 돌린다. worktree 의 추적 파일을 바꿨다 되돌리지 않는다. 변이를 돌리기 전에 그때까지의 일을 커밋한다.
- 판: 목표 `8.18.0`(지금 이 브랜치 `8.17.0` 의 다음 minor). 다른 로드맵의 PR 이 먼저 그 번호를 쓰면 PR 을 열 때 그때 기본 브랜치 판의 다음 번호를 쓴다. 판 글자가 박히는 자리는 넷이고 Task 11 한 걸음에 모았다 — `plugin.json` · CHANGELOG 머리 · `tests/test_team_docs.py` 의 `FLOOR` · 같은 파일의 「한 판 아래」 단언 글자.
- CHANGELOG: 새 머리는 바로 다음 판 하나(`shared/tests/test_changelog_integrity.sh`). 지난 판 항목은 고치지 않는다. 이 계획의 항목에는 `--layout team` 과 `종료 코드 4` 글자를 쓰지 않는다 — `tests/test_team_docs.py` 는 다섯 낱말(`--layout team` · `rules_budget` · `handbook_budget` · `job new` · `종료 코드 4`)을 모두 담은 절이 하나뿐이어야 통과한다.
- 전체 스위트는 과제 구현자가 돌리지 않는다. 컨트롤러가 마지막 전체 리뷰의 수정 물결 뒤에 한 번, 공유 잠금 줄로만 돈다: `python3 "<SD>"/scripts/suite_lock.py run --lock <리더가 준 잠금 경로> --owner <agent 이름> --wait <초> -- bash -c 'bash tools/suite/run-all.sh'`. 잠금을 못 잡으면 잠금 없이 돌리지 않고 주인 · 잡은 시각을 보고한다. 과제마다의 테스트는 그 파일과, 바꾼 파일을 코퍼스로 읽는 락만 돈다.
- 고치는 파일은 로드맵의 R1 경로 예약 안이다 — 새 스크립트 둘 · 레포 맨 위 `REVIEW.md` · 로드맵 폴더 바로 아래의 다섯(공통 규칙 파일 · 역할 문서 넷)도 그 예약에 있다(로드맵 폴더는 R5 의 예약과 겹친다). 예약 밖의 파일(테스트 · 공유 파일 셋은 빼고)을 고쳐야 하면 멈춰 보고한다.
- 일꾼의 모델은 이 계획이 정하지 않는다 — 띄우는 쪽이 그때 고른다.
- 사용자에게 보이는 말은 「리더」다. 과제마다 「계획이 정한 테스트」 라고 표시한 코드는 리뷰어가 구현과 따로 본다 — 통과가 정답인 단언에는 그 단언을 빨갛게 만드는 변이를 한 줄씩 적었다.

## Review Focus

- **규칙 글 안의 가름 글자와 표지 글자.** 규칙 글이나 `확인` 칸에 ` · ` 가 들었거나 `출처:` 같은 글이 문장 가운데 나오는 줄. 첫 표지 앞은 통째로 규칙 글이고, 표지로 시작하지 않는 조각은 앞 칸에 다시 붙으며, 같은 표지가 둘이면 그 줄을 형식 오류로 짚는다 — 죽지 않는다(Task 3).
- **CRLF · BOM · 끝 줄바꿈 없는 규칙 파일과 역할 문서.** 검사는 CRLF 줄을 LF 줄과 같게 읽고 예산은 실제 바이트로 잰다. 묶음은 글을 그대로 싣되 끝 줄바꿈이 없으면 하나를 붙여 다음 머리 줄이 앞 글에 붙지 않는다(Task 3 · Task 4).
- **기본 브랜치를 모르는 레포 · fetch 하지 않은 worktree.** `origin/HEAD` 가 없으면 묶음을 내지 않고 검사 불가(3)로 멈춘다. `origin/HEAD` 가 낡았으면 그 레포가 아는 커밋을 기준으로 내고 첫 줄이 그 커밋을 말한다 — 조용히 작업 폴더로 돌아가 읽지 않는다(Task 4).
- **경로를 벗어나는 인자.** `--job ../x` · 절대 경로의 `--roadmap` · 역할 이름인 과제 이름은 파일을 읽기 전에 사용법 오류(2)다. INTENT.md 머리의 `roadmap:` 이 절대 경로이거나 `..` 를 품으면 레포 밖 파일을 열지 않는다(Task 5 · Task 8).
- **`bundle_at` 이 이 레포에 없는 결과 파일.** 얕은 클론이거나 다른 클론에서 쓴 결과 파일이면 「묶음 낡음」 을 지어내지 않고 「재지 못했다」 를 알린다. 종료 코드는 그대로다(Task 6).

## 파일 구조

`plugins/spec-distill/` 아래다(레포 맨 위 파일은 따로 적었다).

| 파일 | 맡는 일 | 과제 |
|---|---|---|
| `scripts/team_layout.py` | 단계의 기본 역할 · 리더 역할 이름 · 「리더가 쓰는 파일을 읽을 ref」 | 2 |
| `scripts/team_rules.py` (새) | 규칙 줄 문법 · 형식 · 조건 값 · 예산 · 같은 규칙 글 · 승격 후보 · `check` · `candidates` 명령 | 3 |
| `scripts/start_bundle.py` (새) | 시작 묶음 — 기준 커밋 · 과제 브랜치 커밋 · 읽을 것 · 쓸 것 · 역할 문서 · 규칙 · 검수 기준 | 4 · 5 |
| `scripts/team_status.py` | 「묶음 낡음」 알림 · 결과 파일 이름 꼴 알림(U1) · 얕은 클론 가드(U15) | 6 · 7 |
| `scripts/team_files.py` | 진행 줄 읽기(U13) · INTENT.md 머리 `roadmap:` 검사 | 8 |
| `scripts/team_write.py` | `job sync` 의 머리 두 커밋(U2) · 주석 | 8 |
| `scripts/check_bundle_coverage.py` · `spec_review_bundle.py` | `roadmap:` 을 `team_files.roadmap_rel` 로 읽는다 | 8 |
| `templates/team/role-leader.md` | 할 일 한 줄(U10) | 10 |
| `references/team-files.md` | §7 · §8 · §9 · §15 와 앞 계획이 넘긴 문장 | 11 |
| `README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json` | Principles · 명령 줄 · 판 | 11 |
| `tests/test_team_rules.py` · `test_team_rules.sh` (새) | 규칙 줄 단위 · 명령 끝에서 끝 | 3 |
| `tests/test_start_bundle.sh` (새) | 묶음 끝에서 끝(임시 레포) | 4 · 5 |
| `tests/test_team_stale.sh` (새) | 「묶음 낡음」 | 6 |
| `tests/test_team_layout.py` · `test_team_results.py` · `test_team_sync.sh` · `test_team_status.sh` · `test_team_tasks.sh` · `test_team_coverage.sh` · `test_team_review_entry.sh` · `test_conductor_ledger.py` · `test_team_files.py` · `test_team_docs.py` | 있는 파일에 테스트 더하기 · T 행 | 2 · 7 · 8 · 9 · 10 · 11 |
| (레포) `REVIEW.md` | 검수 기준 | 10 |
| (레포) `<roadmaps_dir>HANDBOOK.md` · `<roadmaps_dir>{leader,designer,writer,worker}/CLAUDE.md` | devbrew 의 공통 문서 | 10 |

테스트 코드의 별칭 — `L` = `team_layout` · `F` = `team_files` · `TR` = `team_rules` · `SB` = `start_bundle` · `TS` = `team_status`. 셸 테스트의 `S` · `RW` · `RS` · `W` · `T` · `g` · `js` · `status` · `put` · `decide` · `sync` · `TM` · `RM` · `RD` 는 `tests/fixtures/team_repo.sh` 가 주는 것이다(그 파일 머리의 설명). 이 계획의 새 셸 테스트는 `B` = `g rev-parse origin/main`(기준 커밋), `SBP` = `$S/start_bundle.py`, `TRP` = `$S/team_rules.py` 를 더 쓴다. 픽스처 팀의 블록은 P1(결정) · E1(브랜치 `feature/tm-e1`, `feature/tm-e1b` · 지시 원문 범위 2–4) · E2(브랜치 `feature/tm-e2` · 범위 5–7) · E3 이다.

## AC 대응

| AC | 과제 | 재는 것 |
|---|---|---|
| AC19 | 3 | 형식(출처 · 확인 · 반례 확인 · 조건 키) · 조건 값 · 예산 초과 · 두 파일에 걸친 같은 규칙 글이 종료 코드 1 과 그 줄 · 작업 폴더가 기본 · `--ref` |
| AC20 | 3 | `출처` 가 둘 이상인 RULES.md 줄 |
| AC21 | 2 · 4 · 5 | 묶음의 줄들 · `design` 의 원자료 전체와 번호 파일 · 쓸 자리 문장 · 검수 단계 · `--role leader` · 작업 폴더의 사본을 고쳐도 같은 바이트 |
| AC22 | 4 | 조건과 무관하게 전부 · 예산을 넘으면 알림 줄과 종료 코드 0 |
| AC23 | 6 | 「묶음 낡음」 이 나온다 · 안 나온다 · 종료 코드 그대로 |
| AC24 | 5 · 8 · 11 | 두 번 실행의 같은 바이트 · 시도 번호 · `bundle_at` · `job_at` 이 없는 커밋이면 거절(계획 2 가 구현 — 단언으로 못 박는다) · 문서의 두 길 |
| AC25 | 10 · 12 | 레포의 파일 여섯 · `roadmaps_dir` 설정 그대로 · 옛 로드맵 출력 같음 |
| AC26 | 3 · 4 · 11 | 형식 정본 문서 §7 · §8 · §9 · §15 · README · CHANGELOG · 판 · 스크립트 락 |
| AC31 | 2 · 4 · 6 · 11 | ref 함수 · 함수 값을 바꾼 테스트(묶음 · 「묶음 낡음」) · 문서의 흐름 표 |

## 설계에 없던 결정

리더 세션이 사용자에게 묻는다. **U 행은 사용자 몫이다** — 설계의 글자 · 수용 기준 · 사용자에게 보이는 동작(출력 · 종료 코드 · 파일 이름과 형식의 값)을 더하거나 바꾼다. 이 계획은 고르지 않았고 「추천」 은 제안이다. 과제는 추천 안으로 쓰여 있고, 답이 다르면 「기대는 과제」 의 「다른 안이면」 줄과 괄호 안의 「U… 이 나 면」 대로 고친다. 답이 오기 전에는 그 과제를 시작하지 않는다(Task 1 Step 4). **★** 는 승인된 설계의 글자(AC · 본문)나 앞 계획에서 받아들여진 결정과 달라지는 자리다. 출처의 「미리 정할 것 n번」 은 설계문서 `### Deferred to plan` 의 번호다.

| # | 무엇을 정하나 | 안마다 무엇이 달라지나 | 추천과 이유 | 기대는 과제 |
|---|---|---|---|---|
| U1 **★** | implement 결과 파일의 이름 꼴 — 계획 번호를 언제 붙이나. 지금 단계 계산은 설계 흐름이면 `implement-plan-<n>-<시도>.md` 만, 설계 없는 흐름(산출물 블록 · 단순 작업)이면 `implement-<시도>.md` 만 세고, `job sync` 와 결과 대조는 두 꼴을 다 받는다. 설계 §9 는 「계획이 있는 단계에서는 `--plan` 을 반드시 준다」 고 적었고 단순 작업도 `plan-1.md` 를 둘 수 있다(PR #290 통합 리뷰 ①) | **가.** 규칙을 문장으로 못 박는다 — 설계 흐름은 번호 붙은 이름, 설계 없는 흐름은 번호 없는 이름. 시작 묶음의 「쓸 것」 은 흐름에 맞는 이름만 내고, 단계 계산은 흐름과 다른 꼴의 implement 결과 파일을 보면 알림 한 줄을 낸다. §9 의 문장은 「설계 흐름의 plan · implement · review 단계」 로 좁혀진다. **나.** 읽는 쪽이 두 꼴을 다 센다 — 단계 계산이 흐름과 무관하게 두 이름을 모두 찾아 가장 새 것을 읽는다. 시작 묶음은 `--plan` 을 받으면 번호를 붙인다. 두 꼴이 함께 있을 때 어느 것이 「가장 새 시도」 인지 규칙이 하나 더 필요하다. **다.** 쓰는 쪽도 막는다 — 가 에 더해 `job sync` 와 결과 대조가 흐름과 다른 꼴을 거절한다(그 둘이 로드맵 블록을 읽어야 한다) | **가.** 고칠 곳이 가장 적고 조용히 빠지던 길에 알림이 생긴다. 나 는 「가장 새 시도」 가 두 이름에 걸쳐 흐려진다. 근거: `scripts/team_status.py` 의 `progress`(`number = None if plain else plan`) · `scripts/job_results.py` 의 `newest` · `_ac_check` · `scripts/team_write.py` 의 `sync_result_path` · 설계 §9 「계획이 있는 단계에서는 `--plan` 을 반드시 준다」 | 5 · 7 · 11 |
| U2 **★** | 끊겼다 이어 가는 일꾼이 묶음을 다시 돌렸을 때의 「쓸 것」. AC24 는 「같은 단계 · 같은 계획의 결과 파일 다음 번호」 이고, 계획 2 에서 받아들여진 결정(Q1 — 형식 정본 문서 §5 「시도 번호」)은 「끝 줄 없는 가장 새 시도 파일을 잇는다」 다. 둘이 어긋난다 | **가.** 잇는다 — 가장 새 시도에 끝 줄이 없으면 그 파일을, 있으면 다음 번호를 낸다. 이어 쓰는 파일의 머리 `bundle_at` · `job_at` 은 `job sync` 가 새 값으로 고친다(지금은 있는 머리를 그대로 둔다 — T-c). AC24 의 문장이 「끝난 시도의 다음 번호」 로 좁혀진다. **나.** AC24 글자 그대로 늘 다음 번호 — 다시 시작할 때마다 시도 번호가 늘고 끝 줄 없는 앞 파일이 남는다. `job sync` 는 그대로다. 형식 정본 문서 §5 의 「잇는다」 문장을 고쳐야 한다 | **가.** 이미 받아들여진 결정을 지키고 시도 번호가 다시 시작마다 늘지 않는다. 머리를 고치지 않으면 다시 받은 묶음이 새것인데도 「묶음 낡음」 이 남는다 | 5 · 8 · 11 |
| U3 | 「읽을 것」 에 앞 시도와 검수 결과를 넣나(미리 정할 것 1번 · 계획 2 가 넘김) | **가.** 넣는다 — 같은 단계 · 같은 계획의 바로 앞 시도 결과 파일 하나와 가장 새 `review` 결과 파일 하나(있을 때만). **나.** 넣지 않는다 — 설계 §9 의 글자대로 INTENT.md 와 설계 · 계획 파일만 | **가.** 반려 뒤 다시 보낸 일꾼이 무엇이 걸렸는지 읽을 길이 묶음에 생긴다. 경로 두 개뿐이라 묶음이 커지지 않는다 | 5 |
| U4 | 과제 브랜치가 아직 없을 때의 묶음(미리 정할 것 2번) | **가.** 낸다 — 과제 폴더를 기준 커밋에서 읽고 첫 줄의 과제 브랜치 커밋 자리에 기준 커밋을 적으며 시도 번호는 1 이다. 알림 한 줄(「과제 브랜치 … 가 아직 없다」)을 낸다. 브랜치는 묶음이 만들지 않는다(읽기만 한다 — 만드는 쪽은 R2 의 절차). **나.** 멈춘다 — 브랜치를 먼저 만들라고 알리고 종료 코드 1 | **가.** 에픽의 첫 보내기(설계 단계)는 늘 이 경우다. 멈추면 리더가 빈 브랜치를 먼저 만들어 올려야 한다 | 5 |
| U5 | 단순 작업 과제의 묶음에 「원자료」 줄을 내나(미리 정할 것 3번) | **가.** 내지 않는다 — 받은 말이 INTENT.md 의 지시 원문 칸에 있다. **나.** 「원자료: 없음 — 받은 말은 INTENT.md 에 있다」 한 줄을 낸다 | **가.** 설계문서의 그 항목이 「내지 않는다」 로 적었다 | 5 |
| U6 | 알림 줄의 자리와 꼴. 설계 §9 는 「일꾼은 묶음 첫 줄의 두 커밋을 옮긴다」 와 「예산을 넘었으면 묶음 첫머리에 한 줄로 알린다」 를 함께 적었다 | **가.** 첫 줄은 늘 `기준 커밋:` 줄이고 알림은 바로 다음 줄들에 `알림: <글>` 로 온다. **나.** 알림이 맨 위에 오고 `기준 커밋:` 줄이 그 뒤다(역할 문서 틀의 「첫 줄의 두 커밋」 을 「`기준 커밋:` 줄의 두 커밋」 으로 고쳐야 한다) | **가.** 틀과 설계의 「첫 줄」 이 그대로 맞고 알림은 둘째 줄이라 여전히 첫머리다 | 4 · 5 |
| U7 | 두 새 명령의 종료 코드와 멈추는 조건. 설계는 AC19(검사 어긋남 1)와 AC22(예산을 넘은 묶음 0)만 적었다 | **가.** 플러그인의 지금 규칙을 따른다 — 0 냈다 · 1 낼 수 없다 · 2 사용법 · 3 검사 불가. 묶음이 1 로 멈추는 것: 읽을 커밋에 과제의 INTENT.md 가 없다 · 그 머리의 `job` · `roadmap` 이 인자와 다르다 · 블록에 그 계획의 브랜치가 적혀 있지 않다 · 같은 이름의 로드맵 밖 과제가 둘이다 · **역할 문서가 기준 커밋에 없다**. 규칙 파일이 기준 커밋에 없으면 멈추지 않고 알림 한 줄을 낸다. 규칙 검사는 팀의 규칙 파일이 없으면 어긋남(1), 공통 규칙 파일이 없으면 알림만 낸다. **나.** 가 와 같되 역할 문서가 없어도 「역할 문서: 없음」 한 줄을 내고 계속 간다(검수 기준의 「없음」 과 같은 꼴) | **가.** 역할 문서가 없으면 일꾼이 「첫 줄의 두 커밋을 결과 파일 머리에 옮긴다」 를 모른 채 떠 결과 대조에서 걸린다 — 보낼 때 멈추는 쪽이 싸다. 새 형식을 켜기 전에는 공통 파일이 기본 브랜치에 닿지 않은 레포가 있어(§미룸 — #285) 이 멈춤이 그 사실을 드러낸다 | 3 · 4 · 5 |
| U8 | 묶음에 결과 파일을 맞추는 명령 줄을 싣나(계획 2 가 넘긴 제안 — 일꾼이 인자를 지어내지 않게) | **가.** 싣는다 — `쓸 것` 다음 줄에 `맞추는 명령: roadmap_write.py job sync --result <쓸 것> --role <역할> --bundle-at <기준 커밋> --job-at <과제 브랜치 커밋>` 한 줄(스크립트 폴더 경로는 싣지 않는다 — 설치 자리마다 달라 「같은 바이트」 가 깨진다). **나.** 싣지 않는다 — 설계 §9 의 출력 그대로 | **가.** 역할 문서 틀이 「두 커밋을 머리에 옮긴다」 고만 말하고 어떻게 옮기는지는 말하지 않는다 | 5 |
| U9 | 「묶음 낡음」 이 보는 것 둘. ① REVIEW.md — 설계 §15 의 표는 「낡았을 때: 묶음 낡음」 에 REVIEW.md 를 넣었고 AC23 은 규칙 파일 둘과 그 역할 문서만 적었다(미리 정할 것 6번). ② 어느 결과 파일의 `bundle_at` 을 보나 | ① **가.** AC23 대로 넣지 않는다 — 검수 묶음은 결과 파일을 쓰는 일꾼에게 가지 않아(검수 결과 파일은 리더가 쓴다) 잴 `bundle_at` 이 없다. 형식 정본 문서의 흐름 표에서 REVIEW.md 의 「낡았을 때」 칸을 「다음 검수 묶음이 새로 읽는다」 로 적는다(설계 §15 의 표와 달라진다 ★). **나.** 넣는다 — 모든 도는 결과 파일에 REVIEW.md 의 바뀜도 알린다(구현 일꾼은 REVIEW.md 를 받지 않았는데 알림이 뜬다). ② **가.** 단계 · 계획마다 가장 새 시도이고 끝 줄이 없는 결과 파일 모두(설계 · 계획 단계의 일꾼 포함). **나.** 단계 계산이 이미 읽는 implement 결과 파일 하나만 | ① **가** · ② **가.** 설계 §5 가 「끝 줄이 없는 결과 파일은 아직 도는 중이다」 로 정했고 설계 일꾼도 오래 돈다 | 6 · 11 |
| U10 | 규칙 검사를 누가 언제 돌리나(미리 정할 것 7번). 설계 §7 은 「검사는 규칙을 쓸 때 돈다」 고만 적었다 | **가.** 리더 역할 문서 틀의 할 일에 한 줄 — 「규칙을 고친 뒤 규칙 검사를 돌린다.」 알림이지 막는 장치가 아니다. 틀이 바뀌므로 이미 깐 레포는 손으로 그 줄을 더한다(CHANGELOG 에 적는다). **나.** 규칙을 쓰는 명령(`team_rules.py` 의 더하기 · 지우기)을 만들고 그 명령이 쓰기 전에 검사한다 — 설계에 없는 새 명령이다. **다.** 아무것도 두지 않는다 | **가.** 가장 가볍다. 규칙이 아직 한 줄도 없어 쓰는 명령의 꼴을 정할 근거가 없다 | 10 · 11 |
| U11 | 규칙 파일 예산의 기본값 8KB · 16KB(미리 정할 것 8번 — 측정 근거가 없는 작성자 제안이고 계획 1 이 이미 넣었다) | **가.** 값은 두고 형식 정본 문서 §7 에 「작성자 제안이고 근거가 되는 측정은 없다 — 레포 설정으로 바꾼다」 를 적는다. **나.** 값을 바꾼다(사용자가 숫자를 준다) | **가.** 규칙이 한 줄도 없어 잴 것이 없다. 묶음에 통째로 실리는 상한이라는 뜻만 문서에 남긴다 | 11 |
| U12 | 규칙 줄 문법의 빈 곳. 설계 §7 은 예시 한 줄과 칸의 뜻만 적었다 | 이 계획의 읽는 법(Task 3 머리의 「문법」): 규칙 줄은 `- [` 로 시작하는 줄뿐이고 그 밖의 줄은 검사하지 않는다(계획 1 이 넘긴 약속) · 조각은 ` · ` 로 나누고 표지로 시작하지 않는 조각은 앞 칸에 붙는다 · `조건` 은 `키=값` 을 `, ` 로 잇는다 · `출처` 는 세로 막대(공백 · `\|` · 공백)로 나눈다 · 「같은 규칙 글」 은 태그를 뺀 규칙 글의 글자 비교다(앞뒤 공백만 뗀다) · RULES.md 줄의 `반례 확인` 은 있어도 된다. **갈리는 곳 하나:** 한 파일 안의 같은 규칙 글 — **가.** 함께 잡는다(설계 §7 「같은 지적이 다시 나오면 새 줄을 쓰지 않고 출처에 덧붙인다」). **나.** AC19 의 글자대로 두 파일에 걸친 것만 잡는다 | 읽는 법은 예시 줄에서 끌어낸 것이라 다르게 읽을 자리가 있으면 여기서 고친다. 갈리는 곳은 **가** | 3 |
| U13 | 구현 중에 계획의 task 절 수가 바뀔 때(PR #290 통합 리뷰 ③). 지금은 `job sync` 가 `Task k/5` 옆에 `Task k/6` 을 붙이고 읽는 쪽이 「진행 줄 깨짐」 으로 숫자를 버리며, 그 시도 파일에서는 되돌릴 길이 없다 | **가.** 읽는 쪽이 마지막 줄의 전체를 쓴다 — 전체가 줄마다 달라도 깨진 것이 아니고, 깨짐은 번호가 1 보다 작거나 그 줄의 전체보다 클 때뿐이다(T-b). **나.** 쓰는 쪽이 거절한다 — 있는 `Task` 줄의 전체와 다르면 `job sync` 가 쓰지 않고 종료 코드 1 로 알린다(그 시도에서는 진행 줄을 더 남길 수 없다). **다.** 그대로 두고 형식 정본 문서에 한계로만 적는다 | **가.** 계획이 구현 중에 고쳐지는 일은 흔하고(리뷰 뒤 task 를 더한다) 그때도 진행 숫자가 살아 있다. AC27 의 「숫자가 깨졌으면(n 이 전체보다 크다 등)」 은 그대로 지켜진다 | 8 · 11 |
| U14 | 단순 작업 머리 `paths` 의 폴더 꼴(PR #290 통합 리뷰 ④). 예약 알림은 끝이 `/` 인 원소만 폴더로 보고 「받은 뒤 바뀜」 은 `/` 없이도 그 아래를 센다 | **가.** 형식 정본 문서 §2 에 「폴더는 `/` 로 끝낸다」 한 문장만. **나.** 가 에 더해 `job new` 가 있는 폴더를 가리키는 원소에 `/` 를 붙여 적는다(쓴 글자가 받은 인자와 달라진다) | **가.** 예약 읽기(`_reserves`)는 옛 형식의 블록 예약과 함께 쓰는 규칙이라 그쪽을 고치면 옛 형식 출력이 흔들린다 | 11 |
| U15 | 얕은 클론 가드를 좁히면 종료 코드가 바뀌는 자리(§미룸 — PR #290 좁은 재리뷰). 지금은 과제 단계가 「알 수 없음」 이면 예약을 재지 않는다 | **가.** 가드를 「얕은 클론일 때만」 으로 좁히고, 얕은지 묻는 git 호출의 실패를 git 읽기 실패로 남긴다 — 그 호출만 실패하는 환경에서 예약 알림이 다시 나오고 종료 코드가 0 에서 3(검사 불가)이 된다. **나.** 가드만 좁힌다 — 알림은 다시 나오고 종료 코드는 0 그대로다(얕은지 모르는 채 통과한다) | **가.** 형식 정본 문서가 이미 「읽지 못함은 검사 불가다」 로 적었고 미룸 행이 둘을 함께 적었다 | 7 |
| U16 | devbrew 레포 `REVIEW.md` 의 글. 설계 §8 은 「처음 내용은 사용자 원자료의 검수 문장에서 옮긴다」, §1 의 표는 「리뷰가 지적할 것 · 심각도 · 건너뛸 것」 이라고만 적었다. 이 파일은 관리형 Code Review 가 레포의 모든 PR 에서 읽는다 | **가.** 원자료의 두 문장만 — Task 10 의 초안(반려 조건 둘 · 반려는 한 줄). 심각도 · 건너뛸 것은 적지 않는다. **나.** 가 에 「심각도」 · 「건너뛸 것」 칸을 더해 devbrew 의 규칙으로 채운다(무엇을 적을지 사용자가 준다) | **가.** 원자료에 있는 것만 옮긴다. 나머지 칸은 쓸 일이 생길 때 사람이 PR 로 더한다 | 10 |
| U17 | devbrew 의 역할 문서 넷과 HANDBOOK.md 의 글 | **가.** 플러그인 틀과 같은 글 — 생성기가 깔았을 내용 그대로(U10 이 가 면 리더 문서에 그 한 줄 포함). **나.** devbrew 에 맞춰 고친 글(무엇을 고칠지 사용자가 준다) | **가.** 틀이 사용자가 붙인 글에서 나왔고 devbrew 만의 차이를 설계가 적지 않았다 | 10 |
| U18 | 규칙을 읽은 커밋이 기준 커밋과 다를 때 묶음의 규칙 머리 줄. 이 에픽에서는 둘이 늘 같아 실제 실행에서는 나오지 않고 AC31 의 테스트에서만 나온다(R3 가 둘을 가른다) | **가.** 다를 때만 머리 줄에 덧붙인다 — `규칙 (<기준 커밋> · 팀 규칙은 <그 커밋>):`. 같으면 설계의 꼴 그대로다. **나.** 머리 줄은 늘 설계의 꼴이고 다른 커밋을 알림 줄로 낸다 | **가.** 어느 커밋의 글인지가 그 글 바로 위에 있다. 꼴은 R3 가 다시 정할 수 있다 | 4 |

**구현 선택**(설계가 정한 것을 어떻게 짓나 — 이 계획이 정했다. 틀렸다고 보면 그 과제만 고친다)

| # | 선택 | 이유 |
|---|---|---|
| I1 | 새 모듈 둘 — `team_rules.py`(규칙 줄) · `start_bundle.py`(묶음). 둘 다 읽기만 하고 git 은 `roadmap_status.Git` 을 쓴다 | 설계 Files to Modify 의 이름 그대로다. git 호출 꼴이 한 곳이면 허용 명령 목록이 하나다 |
| I2 | `team_layout.leader_ref(default_ref: str) -> str` 은 받은 기본 브랜치 ref 를 그대로 돌려준다. 부르는 쪽은 `team_layout.leader_ref(…)` 를 부를 때마다 모듈에서 찾아 부른다(`from team_layout import leader_ref` 를 쓰지 않는다) | AC31 의 테스트가 그 함수를 바꿔 끼운다. 환경 변수 같은 새 표면을 만들지 않는다. `team_layout.py` 는 표준 라이브러리만 import 해 기본 ref 의 글자를 스스로 알 수 없다 |
| I3 | 「묶음 낡음」 은 `team_status.Reader` 안에 둔다 | 상태 계산이 새 모듈을 import 하지 않아 정적 락의 수와 코드 지문 목록이 그대로다. 알림을 `notes` 에 더하는 한 곳이 거기다(계획 2 의 이음매) |
| I4 | 낡음은 글 비교로 잰다 — `bundle_at` 의 그 파일 글과 지금 읽을 커밋의 글이 다르면 낡았다 | 고쳤다 되돌려 글이 같으면 일꾼이 받은 것이 지금 것과 같다 |
| I5 | `design` 단계의 번호 파일은 `읽을 것` 의 첫 원소로 `<기준 커밋>:<경로>` 꼴로 싣는다 | 설계 §9 의 출력 틀에 번호 파일의 줄 이름이 따로 없다 |
| I6 | 쓸 자리 문장은 `쓸 자리: <문장>` 한 줄이고 문장은 `workflow_superpowers.place_sentence` 가 낸다 | 그 문장의 꼴을 아는 곳이 변환기 하나다 |
| I7 | 규칙은 두 파일의 글을 통째로 싣는다(팀 규칙 먼저, 제목 줄과 머리말 포함) | 설계 §9 「줄 전부」. 공통 규칙 파일의 머리말(운영 원칙)이 일꾼에게 닿는다 |
| I8 | 단순 작업의 과제 브랜치는 `team_status.task_jobs` 로 찾는다 — 인자를 더하지 않는다 | 설계 §9 의 명령 줄에 `--branch` 가 없다. 과제를 세는 규칙(머리 `branch` 가 가리키는 끝)이 한 곳이다 |
| I9 | 규칙 검사의 명령 꼴은 `team_rules.py check --roadmap <로드맵> [--ref <ref>]` · `candidates --roadmap <로드맵> [--ref <ref>]` 이고, 어긋남 줄은 `<경로>:<줄 번호>: <사유> — <그 줄>` 이다 | 다른 team 명령과 같은 `--roadmap`. AC19 의 「그 줄로 알린다」 |
| I10 | 예산은 바이트 수로 잰다 — 작업 폴더는 파일 바이트, 커밋은 `git cat-file -s` | `Git.blob` 은 줄바꿈을 고쳐 읽어 바이트 수가 달라진다 |
| I11 | INTENT.md 머리 `roadmap:` 의 꼴 검사는 `team_files.roadmap_rel(meta)` 한 곳이고, 거절은 그 과제의 로드맵을 읽지 못한 것과 같은 길(있는 검사 불가)로 간다 | 새 종료 코드를 만들지 않는다 |
| I12 | 묶음의 「과제 브랜치」 는 에픽이면 블록 `브랜치:` 의 `--plan` 번째(없으면 첫째)이고 끝은 `team_status.read_tip` 이 고른다 | 설계 §10 「n 번째 브랜치가 `plan-<n>.md` 를 맡는다」 · §15 「끝을 고르는 규칙은 `branch_tip.py` 의 것」 |

**있는 테스트를 고치는 자리**

| # | 자리 | 왜 |
|---|---|---|
| T-a **★** | `tests/test_team_docs.py` `test_sections_of_this_plan` 의 제목 일곱을 열하나로(§7 · §8 · §9 를 §6 과 §10 사이에, §15 를 끝에) | AC26 의 계획 3 몫 |
| T-b **★** | `tests/test_team_results.py` `Progress` — `test_numbers` 의 깨짐 목록에서 `"Task 1/7: 끝 — a\nTask 2/8: 끝 — b\n"` 을, `test_reason_carries_the_line_as_written` 에서 `"Task 2/8: 끝 — b"` 갈래를 빼고 「마지막 줄의 전체로 센다」 는 새 테스트로 옮긴다(U13 이 가 일 때만) | U13 |
| T-c **★** | `tests/test_team_sync.sh` 「머리 인자: 있는 머리는 고치지 않는다(바이트 그대로)」 와 그 앞의 「바뀐 것 없음」 단언 — 끝 줄 없는 파일이면 `bundle_at` · `job_at` 두 줄만 새 값이고 `role` 은 그대로라는 단언으로(U2 가 가 일 때만) | U2 |
| T-d | `tests/test_team_docs.py` 의 `FLOOR` 와 「한 판 아래」 단언의 판 글자(Task 11) | 판 올림 |

## 앞 계획이 넘긴 것

| 넘긴 것 | 출처 | 이 계획에서 |
|---|---|---|
| 단계의 기본 역할 · 「리더가 쓰는 파일을 읽을 ref」 함수 | 계획 2 이음매 | Task 2 |
| 「묶음 낡음」 은 `parse_result(…).bundle_at` 으로, 알림은 `Reader` 의 `notes` 에 | 계획 2 이음매 | Task 6 |
| 「쓸 것」 시도 번호는 `job_results.result_names` · `newest` 로 · `bundle_at` · `job_at` 검사는 단언 한 줄로 | 계획 2 이음매 | Task 5 |
| 과제 폴더를 읽을 커밋은 `team_status.read_tip` 으로 · 쓸 자리 문장은 `place_sentence` 로 · `job sync` 명령 줄 싣기 | 계획 2 이음매 | Task 5(명령 줄은 U8) |
| 형식 정본 문서의 「계획 3 이 §15 로 적는다」 넷 | 계획 2 이음매 · §미룸 | Task 11 |
| 앞 시도 · 검수 결과를 「읽을 것」 에 | 계획 2 의 Q1 | Task 5(U3) |
| INTENT.md 머리 `roadmap:` 이 절대 경로이거나 `..` 를 품는 것 | §미룸 | Task 8 |
| 얕은 클론 가드의 열쇠 · `Reader.shallow()` 의 실패 | §미룸 · 좁은 재리뷰 | Task 7(U15) |
| implement 결과 파일의 이름 꼴 | 통합 리뷰 ① | Task 5 · 8 · 12(U1) |
| 기본 브랜치에 커밋된 단순 작업 폴더가 「머지됨」 으로 세어진다는 문장 | 통합 리뷰 ② | Task 11(문장). 절차는 R2 — 미룸 표에 행이 있다 |
| 구현 중 task 절 수가 바뀌면 「진행 줄 깨짐」 | 통합 리뷰 ③ | Task 8(U13) |
| 단순 작업 `paths` 의 폴더 꼴 | 통합 리뷰 ④ | Task 11(U14) |
| 계획 2 잔여를 미룸 표에서 받는 곳별 행으로 가르기 | 통합 리뷰 ⑤ | 이미 됐다 — 이 브랜치의 첫 설계문서 커밋이 행을 갈랐다. Task 1 이 확인만 한다 |
| 같은 입력의 종료 코드가 블록(3)과 로드맵 밖 과제(0)에서 다르다 | PR #290 잔여 Minor 1 | Task 11(문서가 두 쪽을 따로 적는다) |
| 얕은 클론 픽스처가 깊이 하나뿐이다 | 잔여 Minor 9 | Task 9 |
| 계획 2 의 결정이 AC14 의 글자를 좁힌다(이름이 맞는 브랜치에서 센 과제의 다른 브랜치 사본은 알림 없이 건너뛴다) | 잔여 Minor 10 | Task 11(문서 한 문장) + 보고에 「지휘 기록 한 줄」 을 리더에게 청한다 |
| 테스트 보강 — 펜스 아닌 꼴 뒤의 진짜 펜스 · 머리 뒤 빈 줄 하나 · 「갈라짐」 과 조상 판정 실패 · BOM 걸음의 진행 칸 · 얕은 클론 사유 · 끝 상태 · 종류 밖 줄 거절의 사유 | 잔여 표의 「계획 3」 줄 | Task 9 |
| 얕은 클론에서 브랜치를 지운 team 블록 | 잔여 표 | Task 11(문서 한 줄 — 옛 형식과 같은 한계) |
| 얕은 클론 픽스처의 종료 코드 단언 | 잔여 표 | 이미 됐다(`tests/test_team_tasks.sh` 가 깊이 1 · 3 의 종료 코드를 잰다) — Task 1 이 확인만 한다 |
| 출처 커밋을 읽지 못할 때의 대체 대조 · framing audit 를 직접 준 팀 폴더의 뒷일 | §미룸(받는 곳 R1) | 계획 2 가 했다 — Task 1 이 확인만 한다. 열려 있으면 멈춰 보고한다 |
| 계획 1 PR 의 잔여 열하나 · 「(R3)」 · 「이 판 / 다음 판」 글 | §미룸 | 계획 2 가 받았다(그 계획의 Q22) — 이 계획 몫은 「계획 3 이 §15 로 적는다」 넷뿐이다 |

## 이 계획이 하지 않는 것

- 지휘 절차가 시작 묶음을 쓰게 하기 · 보내는 글 틀 바꾸기 · 마지막 보고 규칙을 결과 파일로 바꾸기 — R2(§미룸).
- 규칙 줄을 조건으로 골라 싣기와 묶음 예산 — 미룸(결정 기록 B17). 이 계획은 조건 값 검사까지만 한다.
- 규칙을 쓰는 명령(더하기 · 지우기 · 승격) — 설계에 없다(U10 의 나 가 골라질 때만).
- 리더 상태 브랜치 · 대기 줄의 자리 · 결과 파일 머리에 규칙 커밋 칸 더하기 — R3. 이 계획은 ref 함수 하나와 그 테스트만 둔다.
- PR #290 잔여 가운데 받는 곳이 R2 · R3 인 줄(문구와 갈래 정리 · 펜스를 읽는 코드 넷 모으기 · 현황 쪽) — 미룸 표의 그 행들이 받는다. `conductor_ledger.py` · `control_plane.py` 는 이 계획에서 고치지 않는다(테스트 보강은 한다 — Task 9).
- 같은 판 번호를 올린 두 PR 의 잘못 푼 merge 를 잡는 확인 — R2(§미룸). 이 계획은 판 글자를 한 걸음에 모으기만 한다.
- 모델 고르기 지침 — R2(§지휘 기록 2026-11-15 「R2에만」).
- devbrew 의 `roadmaps_dir` 바꾸기 · `.devbrew.md` 만들기 — R5(결정 기록 B16).
- quality-gates 와 구현 중 리뷰가 REVIEW.md 를 읽게 하기 — 이슈 #277 · R2.

## 코드 분기 × 픽스처

앞 두 계획의 리뷰가 남긴 말 — 「변이 표를 쓰기 전에 새 함수의 분기를 픽스처와 대조하라.」 구현자는 과제를 끝낼 때 자기 함수의 분기가 이 표에 다 있는지 보고, 없는 분기를 만들었으면 픽스처를 더한 뒤 원장에 그 줄을 적는다. Task 12 의 변이는 이 표의 픽스처가 모두 있는 뒤에 흔든다.

| 함수 | 분기 | 픽스처 |
|---|---|---|
| `team_rules.parse_rules` | 규칙 줄 아님(제목 · 빈 줄 · 인용 · `- ` 뿐인 줄) · 좋은 줄 · 태그 꼴 아님 · 규칙 글 빔 · 표지 겹침 · 출처 없음 · 확인 없음 · 반례 확인 없음(공통 파일만) · 조건 키 밖 · 조건 꼴 아님 · 역할 값 밖 · 단계 값 밖 · 값 여럿(세로 막대로 이음) · 경로 글롭 · 출처 둘 · 규칙 글 안의 ` · ` · CRLF | `test_team_rules.py` `Parse` |
| `team_rules.check_files` | 통과 · 예산과 같은 바이트 · 한 바이트 넘김 · 두 파일에 걸친 같은 글 · 한 파일 안의 같은 글 · 팀 규칙 파일 없음 · 공통 규칙 파일 없음 | `test_team_rules.py` `Files` |
| `team_rules` 명령 | 작업 폴더 · `--ref` · 레포 설정의 예산 · 없는 ref · team 이 아닌 로드맵 · 후보 있음 · 없음 | `test_team_rules.sh` |
| `start_bundle` 리더 묶음 | 통과 · 예산 넘김 · 규칙 파일 없음 · 역할 문서 없음 · 기본 브랜치 모름 · 작업 폴더의 사본 고침 · ref 함수 바꿈 | `test_start_bundle.sh` 「리더:」 |
| `start_bundle` 과제 묶음 | 단계 넷 · `--role writer` · 과제 브랜치 없음 · 로컬 앞섬 · 갈라짐 · 설계 없는 흐름 블록 · 단순 작업(브랜치 끝 · 못 찾음) · 검수 기준 없음 · 인자 조합 오류 여덟 | `test_start_bundle.sh` 「과제:」 · 「사용법:」 |
| `start_bundle.attempt_of` | 결과 파일 없음 · 끝난 시도 · 끝 줄 없는 시도 · 읽지 못하는 시도 · 다른 단계 · 다른 계획의 파일 | `test_start_bundle.sh` 「쓸 것:」 |
| `team_status.Reader.stale` | 안 바뀜 · 팀 규칙 바뀜 · 공통 규칙 바뀜 · 그 역할 문서 바뀜 · 다른 역할 문서만 바뀜 · 끝 줄 있음 · `bundle_at` 이 없는 커밋 · 설계 단계의 결과 파일 · ref 함수 바꿈 | `test_team_stale.sh` |
| `team_status.Reader.progress` 의 이름 꼴 알림 | 설계 흐름에 번호 없는 이름 · 설계 없는 흐름에 번호 붙은 이름 · 맞는 꼴만 | `test_team_status.sh` 「이름 꼴:」 |
| `team_status.task_jobs` 의 가드 | 진짜 얕은 클론(깊이 1 · 3) · 얕은지 묻는 호출만 실패 · 얕지 않음 | `test_team_tasks.sh` 「가드:」 |
| `team_files.progress_of` | 전체가 줄마다 다름(늘어남 · 줄어듦) · n 이 그 줄의 전체보다 큼 · n < 1 | `test_team_results.py` `Progress` |
| `team_files.roadmap_rel` | 레포 상대 경로 · 절대 경로 · `..` 조각 · 역슬래시 · 빈 값 | `test_team_files.py` `RoadmapRel` |

---

### Task 1: 다시 확인 — 이 계획이 기대는 자리가 지금도 그런가

**Files:** 고치지 않는다.

**Interfaces:**
- Produces: 「달라진 것 없음」 또는 달라진 자리 목록, 시작 커밋 `BASE`(Task 12 의 옛 형식 대조가 쓴다), 목표 판. 달라졌으면 Task 2 로 가지 않고 멈춰 보고한다.

- [ ] **Step 1: 앞 브랜치와 기본 브랜치가 움직였는지 본다**

Run: `git fetch origin` 뒤 `git log --oneline HEAD..origin/feature/team-file-read -- plugins/spec-distill` · `git log --oneline HEAD..origin/main -- plugins/spec-distill` · `git show origin/main:plugins/spec-distill/.claude-plugin/plugin.json`
Expected: 첫 명령 0줄(계획 2 의 PR 이 이 계획을 쓴 뒤 고쳐지지 않았다). 둘째에 줄이 있으면 그 커밋들의 diff 를 읽어 Step 2 의 표와 견주고, 표의 자리가 바뀌었으면 멈춰 보고한다(합치는 것은 리더가 정한다). 셋째의 판이 `8.17.0` 이하이면 목표 판은 `8.18.0`, 그보다 높으면 그 판의 다음 minor 다. `git rev-parse HEAD` 를 `BASE` 로, 목표 판을 함께 원장에 적는다.

- [ ] **Step 2: 이 계획이 기대는 줄을 확인한다**

아래를 `grep -n` 으로 본다. 하나라도 다르면 멈춰 보고한다.

| 자리 | 있어야 하는 것 |
|---|---|
| `scripts/team_layout.py` | `ROLES = ("leader", "designer", "writer", "worker")` · `STAGES = ("design", "plan", "implement", "review")` · `REVIEW_FILE = "REVIEW.md"` · `def role_doc(roadmaps_dir: str, role: str) -> str` · `def handbook(roadmaps_dir: str) -> str` · `class Team(NamedTuple)` 의 칸 `roadmaps_dir` · `name` · `default_role` · `leader_ref` 가 **없다** |
| `scripts/team_files.py` | `def intent_meta(text: str) -> dict` · `def intent_ranges(text: str) -> list` · `def format_ranges(ranges) -> str` · `def parse_result(text: str) -> Result` · `Result` 의 칸 `role` · `bundle_at` · `end` · `def lost_lines(result: Result) -> list` · `progress_of` 안의 `whole != total` |
| `scripts/job_results.py` | `def result_names(git, tip: str, team, job: str) -> Optional[list]` · `def newest(names: list, stage: str, plan) -> Optional[str]` · `class Usage` · `class Unchecked` |
| `scripts/team_status.py` | `def read_tip(git, branch: str) -> tuple` · `class Reader` 의 `def shallow(self)`(안에서 `self.git.run("rev-parse", "--is-shallow-repository")`) · `def flow(self, block: dict) -> str` · `progress` 안의 `number = None if plain else plan` · `task_jobs` 안의 `if stage == UNKNOWN:` 과 `RESERVE_UNSCANNED` · `def task_jobs(reader, blocks: list, scan=None) -> tuple` |
| `scripts/roadmap_status.py` | `GIT_ALLOWED = frozenset({"show", "rev-parse", "log", "diff", "merge-base", "cat-file", "grep", "ls-tree"})` · `class Git` 의 `blob` · `exists` · `absent` · `commit` · `names` · `default_branch` · `run_err` · `fail` · `def _reserves(entry: str, path: str) -> bool` |
| `scripts/workflow_superpowers.py` | `def place_sentence(path: str, stage: str) -> str` |
| `scripts/team_write.py` | `def cmd_job_sync(a, W) -> int` · `def _swap_head(text: str, commit: str) -> str` · 주석 `읽는 쪽이 「진행 줄 깨짐」 으로 부르는 꼴이다` |
| `scripts/repo_defaults.py` | `BUDGET_KEYS = ("rules_budget", "handbook_budget")` · `RULES_BUDGET = 8192` · `HANDBOOK_BUDGET = 16384` |
| `scripts/check_bundle_coverage.py` · `spec_review_bundle.py` | INTENT.md 머리의 `roadmap` 을 읽는 줄들(`fm.get("roadmap", "")` · `intent_meta(text).get("roadmap")`) — 몇 곳인지 원장에 적는다(Task 8 가 모두 바꾼다) |
| `scripts/control_plane.py` | `CODE_STAMP_FILES` 에 `team_status.py` · `team_layout.py` 가 있다 · team 블록의 `notes` 를 `정보:` 줄로 낸다(`job_lines` 와 블록 줄) |
| `templates/team/` | `role-leader.md` · `role-designer.md` · `role-writer.md` · `role-worker.md` · `HANDBOOK.md`(머리말 「잘못 쌓인 맥락은 없는 것보다 나쁘다.」) · `RULES.md`(`# RULES` 한 줄) |
| `references/team-files.md` | 2단계 제목 일곱(§1–§6 · §10) · 「계획 3 이 §15 로 적는다」 네 곳 · §5 의 「**시도 번호.** 끊겼다 이어 가는 일꾼」 문장 |
| `tests/test_team_docs.py` | `FLOOR = (8, 17, 0)` · `below = version_problems("8.16.0", log)` · `test_sections_of_this_plan` 의 제목 일곱 |
| `tests/test_team_sync.sh` | `"머리 인자: 있는 머리는 고치지 않는다(바이트 그대로)"` |
| `tests/test_roadmap_status.sh` | `"CHECKED 14"` |
| `tests/fixtures/team_repo.sh` | `team_repo()` 가 `$TM` 만 커밋한다(`g add -- "$TM"`) — 공통 문서(`$RD` 바로 아래)는 커밋하지 않는다 · E2 블록에 `산출물:` 칸을 더한다 |
| 설계문서 `## 미룸` | 받는 곳이 R1 인 행 일곱 — 계획 2 가 닫은 둘(출처 커밋 대체 대조 · framing audit 뒷일)은 `references/team-files.md` 에 그 글이 있는지 본다(「기준 … 의 같은 줄과 견줬다」 · 표지 `framing audit 없음`) |

- [ ] **Step 3: 고칠 테스트가 지금 초록인지 본다**

Run:
```bash
export PYTHONDONTWRITEBYTECODE=1
python3 -m unittest plugins/spec-distill/tests/test_team_layout.py plugins/spec-distill/tests/test_team_files.py plugins/spec-distill/tests/test_team_results.py plugins/spec-distill/tests/test_team_docs.py plugins/spec-distill/tests/test_conductor_ledger.py
for t in test_team_sync test_team_status test_team_tasks test_team_coverage test_team_review_entry test_job_results; do bash plugins/spec-distill/tests/$t.sh | tail -n 1; done
```
Expected: 모두 통과. 이미 떨어지는 테스트가 있으면 이름을 적어 「기존 실패」 로 보고한다.

- [ ] **Step 4: U 행의 답을 확인한다**

리더가 준 답(「설계에 없던 결정」 U1–U18)을 원장에 옮긴다. 답이 없는 U 행에 기대는 과제는 시작하지 않고 그 번호를 보고한다. 답이 추천과 다른 행은 그 과제의 「다른 안이면」 줄을 원장에 옮겨 적는다.

커밋 없음.

---

### Task 2: 기본 역할과 리더 ref — `team_layout.py` (AC21 의 기본 역할 · AC31 의 함수)

**Files:**
- Modify: `plugins/spec-distill/scripts/team_layout.py`
- Test: `plugins/spec-distill/tests/test_team_layout.py`

**Interfaces:**
- Produces:
  - `team_layout.LEADER_ROLE` — `ROLES[0]`.
  - `team_layout.default_role(stage: str) -> Optional[str]` — `design` · `plan` 은 `"designer"`, `implement` 는 `"worker"`, `review` 는 `None`(역할 문서를 주지 않는다 — 설계 §6). `STAGES` 밖이면 `ValueError`.
  - `team_layout.leader_ref(default_ref: str) -> str` — 리더가 쓰는 파일(팀 규칙 파일)을 읽을 ref. 받은 값을 그대로 돌려준다(I2). docstring 에 「R3 가 이 함수의 값만 바꾼다」 를 적는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다** (계획이 정한 테스트)

```python
class RolesAndRefs(unittest.TestCase):   # 계획 3 — 기본 역할(§9) · 리더가 쓰는 파일을 읽을 ref(§15 · AC31)
    def test_default_roles(self):
        self.assertEqual([L.default_role(s) for s in L.STAGES], ["designer", "designer", "worker", None])
        self.assertRaises(ValueError, L.default_role, "deploy")
        self.assertEqual(L.LEADER_ROLE, "leader")

    def test_leader_ref_is_the_default_branch_in_this_epic(self):
        self.assertEqual(L.leader_ref("refs/remotes/origin/HEAD"), "refs/remotes/origin/HEAD")
        self.assertEqual(L.leader_ref("0" * 40), "0" * 40)   # 커밋을 줘도 그대로
```

변이(사본에서): `default_role` 이 `implement` 에 `designer` 를 내게 → 첫 테스트 빨강. `leader_ref` 가 고정 글자를 내게 → 둘째 테스트 빨강.

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_layout.py -k RolesAndRefs`
Expected: FAIL — `AttributeError: module 'team_layout' has no attribute 'default_role'`

- [ ] **Step 3: 셋을 `team_layout.py` 에 더한다** — 기본 역할 표는 `STAGES` 의 차례에 맞춘 한 줄 표로 둔다(단계 글자를 다시 쓰지 않는다).

- [ ] **Step 4: 통과를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_layout.py`
Expected: OK(`LiteralsLiveInOnePlace` 포함)

- [ ] **Step 5: 커밋** — `git add -- plugins/spec-distill/scripts/team_layout.py plugins/spec-distill/tests/test_team_layout.py` · `feat(spec-distill): 단계의 기본 역할과 리더가 쓰는 파일을 읽을 ref`

---

### Task 3: 규칙 검사 — `team_rules.py` (AC19 · AC20 · AC26 의 락)

U7 · U12 에 기댄다.

**Files:**
- Create: `plugins/spec-distill/scripts/team_rules.py`
- Test: `plugins/spec-distill/tests/test_team_rules.py`(새) · `plugins/spec-distill/tests/test_team_rules.sh`(새 · 100755)

**문법**(U12 — 설계 §7 의 예시 줄에서 끌어낸 읽는 법):

- 규칙 줄은 줄 머리가 `- [` 인 줄이다(줄 끝의 CR 은 뗀다). 그 밖의 줄은 규칙으로 세지 않고 검사하지 않는다.
- 줄을 ` · `(공백 · 가운뎃점 · 공백)로 나눈다. 표지(`조건:` · `출처:` · `확인:` · `반례 확인:`)로 시작하는 조각이 칸을 연다. 표지로 시작하지 않는 조각은 바로 앞 칸(첫 표지 앞이면 규칙 글)에 ` · ` 로 다시 붙는다.
- 첫 칸은 `- [<태그>] <규칙 글>` 이다. 태그와 규칙 글은 비면 안 된다. 「규칙 줄 머리」 는 `[<태그>] <규칙 글>` 이다(결과 파일의 `규칙 반증:` 줄이 가리키는 것).
- `조건:` 의 값은 `키=값` 을 `, ` 로 이은 것이고 값이 여럿이면 `|` 로 잇는다. 키는 `역할` · `단계` · `경로` 뿐이다. `역할` 의 값은 `team_layout.ROLES`, `단계` 의 값은 `team_layout.STAGES` 가운데 하나여야 하고 `경로` 는 비지 않은 글롭 글자다.
- `출처:` 의 값은 ` | ` 로 나눈다. `출처:` · `확인:` 은 반드시 있고 값이 비면 없는 것이다. 공통 규칙 파일의 줄은 `반례 확인:` 도 반드시 있다. 같은 표지가 한 줄에 둘이면 형식 오류다.
- 「같은 규칙 글」 은 태그를 뺀 규칙 글이 앞뒤 공백을 떼고 글자가 같은 것이다. 두 파일에 걸쳐도, 한 파일 안에서도 잡는다(U12 가 나 면 두 파일에 걸친 것만).
- 예산은 파일의 UTF-8 바이트 수가 예산보다 **클 때** 넘은 것이다.

**Interfaces:**
- Consumes: `team_layout.ROLES` · `STAGES` · `RULES_FILE` · `HANDBOOK_FILE` · `Team.rules` · `handbook(roadmaps_dir)` · `team_from_roadmap` · `repo_defaults.resolve`(값 `rules_budget` · `handbook_budget` · `roadmaps_dir`) · `roadmap_status.Git`.
- Produces:
  - `team_rules.Rule` — `NamedTuple(line_no: int, raw: str, tag: str, text: str, conds: dict, sources: tuple, confirm: Optional[str], counter: Optional[str], problems: tuple)`. `conds` 는 `키 → 값들의 tuple`.
  - `team_rules.parse_rules(text: str, handbook: bool = False) -> list` — 규칙 줄마다 `Rule`. 던지지 않는다.
  - `team_rules.head_of(rule) -> str`
  - `team_rules.candidates(rules: list) -> list` — `sources` 가 둘 이상인 `Rule`.
  - `team_rules.check_files(rules_label: str, rules_data: Optional[bytes], handbook_label: str, handbook_data: Optional[bytes], rules_budget: int, handbook_budget: int) -> list` — 어긋남 줄들(I9 의 꼴). `None` 은 그 파일이 없다는 뜻이다 — 팀 규칙 파일이 없으면 어긋남 한 줄, 공통 규칙 파일이 없으면 줄을 내지 않는다(U7). UTF-8 이 아닌 바이트는 `replace` 로 읽고 어긋남 한 줄을 낸다.
  - `team_rules.budget_note(label: str, size: int, budget: int, key: str) -> Optional[str]` — 넘었으면 `<label>: 예산 초과 — <size>바이트 · 예산 <budget>바이트(<key>) — 먼저 지우거나 승격하라`, 아니면 `None`. 시작 묶음(Task 4)이 같은 함수를 부른다.
  - `team_rules.MARKERS = ("조건:", "출처:", "확인:", "반례 확인:")` · `COND_KEYS = ("역할", "단계", "경로")`.
  - 사유 상수 — `BAD_TAG` · `NO_TEXT` · `MISSING`(`%s` 에 표지) · `TWICE`(`%s` 에 표지) · `BAD_KEY`(`%s` 에 키) · `BAD_COND`(`%s` 에 그 조각) · `BAD_VALUE`(`%s` 둘 — 키 · 값).
  - 명령 `team_rules.py check --roadmap <로드맵> [--ref <ref>]` — 첫 줄 `규칙 검사: 통과 — 규칙 줄 <n>개 · 공통 규칙 줄 <m>개` 또는 `규칙 검사: 어긋남 <k>개`, 이어서 어긋남 줄들(표준 출력). 공통 규칙 파일이 없으면 표준 오류에 알림 한 줄. 종료 코드 0 통과 · 1 어긋남 · 2 사용법(로드맵 경로 꼴 · team 형식이 아님) · 3 검사 불가(레포 밖 · 레포 설정 · `--ref` 를 읽지 못함). `--ref` 가 없으면 레포 뿌리의 작업 폴더 파일을, 있으면 그 커밋의 파일을 읽는다.
  - 명령 `team_rules.py candidates --roadmap <로드맵> [--ref <ref>]` — 후보 줄을 글자 그대로 한 줄씩, 없으면 `승격 후보 없음`. 종료 코드 0(사용법 2 · 검사 불가 3 은 `check` 와 같다).

- [ ] **Step 1: 단위 테스트를 쓴다** (계획이 정한 테스트 — `tests/test_team_rules.py`)

```python
GOOD = ("- [테스트] 고친 곳엔 테스트 먼저 · 조건: 역할=worker, 단계=implement"
        " · 출처: R3 결정 기록 2026-11-20 · 확인: 테스트 명령을 돌려 본다")   # 설계 §7 의 예시 줄 그대로


class Parse(unittest.TestCase):
    def one(self, line, handbook=False):
        rules = TR.parse_rules(line + "\n", handbook=handbook)
        self.assertEqual(len(rules), 1, line)
        return rules[0]

    def test_the_design_example(self):
        r = TR.parse_rules("# RULES\n\n" + GOOD + "\n")[0]
        self.assertEqual((r.line_no, r.tag, r.text), (3, "테스트", "고친 곳엔 테스트 먼저"))
        self.assertEqual(r.conds, {"역할": ("worker",), "단계": ("implement",)})
        self.assertEqual((r.sources, r.confirm, r.counter, r.problems),
                         (("R3 결정 기록 2026-11-20",), "테스트 명령을 돌려 본다", None, ()))
        self.assertEqual(TR.head_of(r), "[테스트] 고친 곳엔 테스트 먼저")

    def test_only_dash_bracket_lines_are_rules(self):
        text = "# RULES\n\n> 머리말\n- 산문 불릿\n-[붙은] 것\n  - [들여쓴] 것 · 출처: a · 확인: b\n" + GOOD + "\n"
        self.assertEqual([r.line_no for r in TR.parse_rules(text)], [7])

    def test_separator_and_marker_words_inside_the_text(self):   # Review Focus 1
        r = self.one("- [문서] 목차 · 앵커를 함께 고친다 · 출처: R1 결정 기록 | R2 결정 기록 · 확인: 목차 · 앵커를 눈으로 본다")
        self.assertEqual((r.text, r.sources, r.confirm, r.problems),
                         ("목차 · 앵커를 함께 고친다", ("R1 결정 기록", "R2 결정 기록"), "목차 · 앵커를 눈으로 본다", ()))
        r = self.one("- [보고] 글 가운데 출처: 라는 낱말 · 출처: a · 확인: b")
        self.assertEqual((r.text, r.problems), ("글 가운데 출처: 라는 낱말", ()))

    def test_conditions(self):
        r = self.one("- [폴더] 남의 폴더 고치지 않기 · 조건: 역할=worker|writer, 경로=plugins/**/*.py · 출처: a · 확인: b")
        self.assertEqual((r.conds, r.problems), ({"역할": ("worker", "writer"), "경로": ("plugins/**/*.py",)}, ()))

    def test_problems(self):
        for line, handbook, want in (
                ("- [] 글 · 출처: a · 확인: b", False, TR.BAD_TAG),
                ("- [태그 글 · 출처: a · 확인: b", False, TR.BAD_TAG),
                ("- [태그] · 출처: a · 확인: b", False, TR.NO_TEXT),
                ("- [태그] 글 · 확인: b", False, TR.MISSING % "출처:"),
                ("- [태그] 글 · 출처: a", False, TR.MISSING % "확인:"),
                ("- [태그] 글 · 출처:  · 확인: b", False, TR.MISSING % "출처:"),
                ("- [태그] 글 · 출처: a · 확인: b", True, TR.MISSING % "반례 확인:"),
                ("- [태그] 글 · 출처: a · 출처: c · 확인: b", False, TR.TWICE % "출처:"),
                ("- [태그] 글 · 조건: 팀=x · 출처: a · 확인: b", False, TR.BAD_KEY % "팀"),
                ("- [태그] 글 · 조건: 역할 · 출처: a · 확인: b", False, TR.BAD_COND % "역할"),
                ("- [태그] 글 · 조건: 경로= · 출처: a · 확인: b", False, TR.BAD_COND % "경로="),
                ("- [태그] 글 · 조건: 역할=reviewer · 출처: a · 확인: b", False, TR.BAD_VALUE % ("역할", "reviewer")),
                ("- [태그] 글 · 조건: 단계=deploy · 출처: a · 확인: b", False, TR.BAD_VALUE % ("단계", "deploy")),
                ("- [태그] 글 · 조건: 역할=worker|boss · 출처: a · 확인: b", False, TR.BAD_VALUE % ("역할", "boss")),
        ):
            self.assertEqual(self.one(line, handbook).problems[:1], (want,), line)
        ok = self.one("- [태그] 글 · 출처: a · 확인: b · 반례 확인: 2026-11-20 없었다", True)
        self.assertEqual((ok.problems, ok.counter), ((), "2026-11-20 없었다"))
        self.assertEqual(self.one("- [태그] 글 · 출처: a · 확인: b · 반례 확인: c").problems, ())   # 팀 규칙 줄에도 있어도 된다

    def test_crlf(self):   # Review Focus 2
        self.assertEqual(TR.parse_rules(GOOD + "\r\n")[0].confirm, "테스트 명령을 돌려 본다")


class Files(unittest.TestCase):
    def check(self, rules, handbook, rb=8192, hb=16384):
        return TR.check_files("t/R", rules, "H", handbook, rb, hb)

    def test_passes(self):
        self.assertEqual(self.check(("# RULES\n" + GOOD + "\n").encode("utf-8"), b"# HANDBOOK\n"), [])

    def test_budget_edge(self):   # 설계 Verification Plan — 한 바이트 넘기기
        body = ("# RULES\n" + GOOD + "\n").encode("utf-8")
        self.assertEqual(self.check(body, b"", rb=len(body)), [])
        got = self.check(body, b"", rb=len(body) - 1)
        self.assertEqual(len(got), 1)
        for part in ("t/R: 예산 초과", "%d바이트" % len(body), "rules_budget", "먼저 지우거나 승격하라"):
            self.assertIn(part, got[0])

    def test_same_text_across_files_and_within_one(self):
        other = "- [다른 태그] 고친 곳엔 테스트 먼저 · 출처: x · 확인: y · 반례 확인: z\n".encode("utf-8")
        got = self.check((GOOD + "\n").encode("utf-8"), other)
        self.assertEqual(len(got), 1)
        self.assertIn("t/R:1", got[0])
        self.assertIn("H:1", got[0])
        twice = (GOOD + "\n" + GOOD.replace("[테스트]", "[또]") + "\n").encode("utf-8")
        self.assertEqual(len(self.check(twice, b"")), 1)   # U12 가 나 면 이 기대값은 0 이다

    def test_missing_files(self):
        self.assertEqual(len(self.check(None, b"")), 1)    # 팀 규칙 파일이 없다 — 어긋남
        self.assertEqual(self.check(b"# RULES\n", None), [])   # 공통 규칙 파일이 없다 — 알림은 명령이 낸다

    def test_bad_bytes_and_bom_do_not_crash(self):   # Review Focus 2
        self.assertTrue(self.check(b"- [\xff] x \xc2\xb7 \n", b""))
        self.assertEqual(self.check(b"\xef\xbb\xbf# RULES\n", b""), [])   # BOM 뒤의 제목 줄은 규칙 줄이 아니다


class Candidates(unittest.TestCase):   # AC20
    def test_two_or_more_sources(self):
        text = GOOD + "\n- [문서] 바꾼 건 CHANGELOG에 · 출처: R1 결정 기록 | R4 결정 기록 · 확인: CHANGELOG 를 본다\n"
        self.assertEqual([r.tag for r in TR.candidates(TR.parse_rules(text))], ["문서"])
```

파일 머리는 `tests/test_team_results.py` 와 같은 꼴(`SCRIPTS` 를 `sys.path` 에 넣고 `import team_rules as TR`)이다. 변이(사본에서, 하나씩): 표지 겹침 검사를 뺀다 → `TWICE` 줄 빨강 · `단계` 값 검사를 뺀다 → `deploy` 줄 빨강 · 예산 비교를 `>=` 로 → `test_budget_edge` 첫 단언 빨강 · `handbook` 인자를 무시한다 → `반례 확인:` 줄 빨강 · `candidates` 가 출처 하나도 낸다 → 마지막 테스트 빨강.

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_rules.py`
Expected: FAIL — `ModuleNotFoundError: No module named 'team_rules'`

- [ ] **Step 3: `team_rules.py` 의 글 쪽(위 Produces 의 함수 · 상수)을 짓는다** — 사유 글은 `MARKERS` · `COND_KEYS` 의 원소로 짓는다(표지 글자를 두 번 쓰지 않는다). 줄 나누기는 정규식 없이 `str.split` 으로 한다.

- [ ] **Step 4: 단위 테스트 통과를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_rules.py`
Expected: OK

- [ ] **Step 5: 명령 테스트를 쓴다** (계획이 정한 테스트 — `tests/test_team_rules.sh`)

`team_repo` 뒤에 `main` 에 선 채로 한다. 단언(라벨 머리 「규칙:」):

```bash
BAD='- [태그] 글 · 조건: 단계=deploy · 출처: a · 확인: b'
run() { (cd "$W" && python3 "$TRP" "$@") > "$T/out.txt" 2> "$T/err.txt"; echo $?; }
assert_eq "$(run check --roadmap "$RM")" "0" "규칙: 빈 틀은 통과"
assert_eq "$(sed -n 1p "$T/out.txt")" "규칙 검사: 통과 — 규칙 줄 0개 · 공통 규칙 줄 0개" "규칙: 첫 줄에 상태"
printf '%s\n' "$BAD" >> "$W/$TM/RULES.md"                       # 커밋하지 않는다
assert_eq "$(run check --roadmap "$RM")" "1" "규칙: 작업 폴더의 파일을 읽어 어긋남(1)"
assert_eq "$(sed -n 2p "$T/out.txt")" "$TM/RULES.md:2: $(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import team_rules as t; print(t.BAD_VALUE % ("단계", "deploy"))' "$S") — ${BAD}" "규칙: 그 줄을 경로 · 줄 번호 · 사유와 함께 낸다"
assert_eq "$(run check --roadmap "$RM" --ref origin/main)" "0" "규칙: --ref 는 그 커밋의 파일을 읽는다(작업 폴더의 고침을 보지 않는다)"
assert_eq "$(run check --roadmap "$RM" --ref no-such-ref)" "3" "규칙: 없는 ref 는 검사 불가(3)"
assert_eq "$(run check --roadmap "${RD}nope/roadmap.md")" "3" "규칙: 없는 팀은 검사 불가(3) — 통과로 내지 않는다"
```

이어서: ① 공통 문서를 커밋하지 않은 지금(작업 폴더에는 `create` 가 깐 공통 규칙 파일이 있다) 그 파일을 지우고 돌리면 종료 코드는 팀 규칙 파일의 상태 그대로이고 표준 오류에 그 경로가 든 알림이 한 줄 있다. ② 팀 규칙 파일을 지우면 `1` 이고 출력에 그 경로가 있다. ③ 레포 설정 `.devbrew.md`(`---` · `rules_budget: 40` · `---`)를 `main` 에 커밋 · push · fetch 한 뒤 좋은 줄 하나(설계 예시 줄)를 가진 팀 규칙 파일은 `1` 이고 출력에 `예산 초과` 와 `40바이트` 가 있다 — 설정을 지워 다시 올리면 `0` 이다. ④ `${RD}old/roadmap.md` 에 `layout` 없는 로드맵 글(머리말 `type: roadmap` 만)을 두고 그 경로를 주면 `2` 다(team 형식이 아니다). ⑤ `candidates` — 출처가 둘인 줄과 하나인 줄을 두면 둘인 줄만 글자 그대로 나오고 `0`, 후보가 없으면 `승격 후보 없음`. ⑥ `--ref` 로 읽을 때 예산은 그 커밋의 파일 바이트로 잰다(작업 폴더의 파일이 예산을 넘어도 `--ref origin/main` 은 `0`).

변이(사본에서): `--ref` 를 무시하고 늘 작업 폴더를 읽는다 → 「--ref 는 그 커밋의 파일을 읽는다」 빨강 · 없는 ref 에서 빈 파일로 읽는다 → 「없는 ref」 빨강.

- [ ] **Step 6: 명령(`check` · `candidates` · `main`)을 짓는다** — 인자 풀이와 종료 코드 갈래는 `job_results.py` 의 `main` 과 같은 꼴(`Usage` → 2 · `Unchecked` → 3 · 그 밖의 예외도 3)로 둔다. 커밋의 바이트 수는 `git.run("cat-file", "-s", "<rev>:<path>")`, 글은 `git.blob` 이다. 확인된 없음과 읽기 실패는 `git.absent` 로 가른다.

- [ ] **Step 7: 통과와 락을 확인한다**

Run: `bash plugins/spec-distill/tests/test_team_rules.sh | tail -n 1` · `python3 -m unittest plugins/spec-distill/tests/test_team_layout.py plugins/quality-gates/tests/test_utf8_explicit.py` · `bash shared/tests/test_python_floor.sh | tail -n 1` · `bash plugins/spec-distill/tests/test_check_brief.sh | tail -n 1` · `git ls-files -s plugins/spec-distill/tests/test_team_rules.sh`
Expected: 모두 통과 · 마지막은 `100755`(add 한 뒤)

- [ ] **Step 8: 커밋** — 세 파일 · `feat(spec-distill): 팀 규칙 파일의 검사와 승격 후보`

---

### Task 4: 시작 묶음의 뼈대와 리더 묶음 — `start_bundle.py` (AC21 의 리더 · AC22 · AC31)

U6 · U7 · U18 에 기댄다.

**Files:**
- Create: `plugins/spec-distill/scripts/start_bundle.py`
- Test: `plugins/spec-distill/tests/test_start_bundle.sh`(새 · 100755)

**Interfaces:**
- Consumes: Task 2 의 `LEADER_ROLE` · `leader_ref` · Task 3 의 `team_rules.budget_note` · `roadmap_status.Git`(`default_branch` · `commit` · `blob` · `absent` · `run`) · `repo_defaults.resolve` · `roadmap_model.DEFAULT_REF` · `team_layout.role_doc` · `handbook` · `Team.rules`.
- Produces:
  - 명령 `start_bundle.py --roadmap <로드맵> --role leader` — 리더 묶음. 과제 · 단계 없이 부른다.
  - `start_bundle.Usage` · `Refused` · `Unchecked` — 종료 코드 2 · 1 · 3(U7). 사용법 오류와 멈춤 · 검사 불가의 글은 표준 오류로, 묶음은 표준 출력으로만 낸다. 0 이 아닌 종료 코드에서는 표준 출력이 비어 있다(반쯤 나온 묶음을 일꾼이 읽지 않는다).
  - `start_bundle.Base` — `NamedTuple(commit: str, rules_commit: str, roadmaps_dir: str, team, settings: dict)`. `rules_commit` 은 `git.commit(team_layout.leader_ref(DEFAULT_REF))` 이다.
  - `start_bundle.open_base(git, roadmap_rel: str) -> Base` — 레포 · 설정 · 기본 브랜치 · 로드맵(`layout: team`)을 확인한다. 못 하면 `Unchecked` 나 `Usage`(갈래는 `job_results._check` 와 같다).
  - `start_bundle.role_block(git, base, role: str) -> list` — `역할 문서 (<기준 커밋>):` 줄과 그 글의 줄들. 기준 커밋에 없으면 `Refused`(U7 이 나 면 `역할 문서: 없음 — <경로> 가 기준 커밋에 없다` 한 줄).
  - `start_bundle.rules_block(git, base) -> tuple` — `(줄들, 알림들)`. 줄들은 `규칙 (<기준 커밋>):` 과 팀 규칙 파일 · 공통 규칙 파일의 글(I7)이다. 두 커밋이 다르면 머리 줄은 `규칙 (<기준 커밋> · 팀 규칙은 <rules_commit>):`(U18). 알림들은 예산을 넘은 파일마다 `budget_note` 한 줄, 기준 커밋에 없는 파일마다 `<경로> 가 기준 커밋에 없다` 한 줄이다.
  - `start_bundle.emit(first: str, notices: list, body: list) -> str` — 첫 줄 · `알림: <글>` 줄들 · 본문 줄들을 이은 글(U6). 싣는 파일 글은 끝 줄바꿈이 없으면 하나를 붙인다.

리더 묶음의 꼴:

```
기준 커밋: <40자 커밋>
알림: <글>                          ← 있을 때만, 한 줄에 하나
역할 문서 (<기준 커밋>):
<리더 역할 문서의 글>
규칙 (<기준 커밋>):
<팀 규칙 파일의 글>
<공통 규칙 파일의 글>
```

- [ ] **Step 1: 실패하는 테스트를 쓴다** (계획이 정한 테스트 — 라벨 머리 「리더:」)

준비: `team_repo` 뒤에 공통 문서를 올린다(픽스처는 팀 폴더만 커밋한다) — `g add -- "${RD}leader" "${RD}designer" "${RD}writer" "${RD}worker" "${RD}HANDBOOK.md"` · 커밋 · `g push -q origin main` · `g fetch -q origin`. 팀 규칙 파일에 조건이 서로 다른 규칙 줄 셋(`조건: 역할=writer` · `조건: 단계=review` · `조건: 경로=nowhere/**`)을 더해 함께 올린다. `B="$(g rev-parse origin/main)"`.

```bash
lead() { (cd "$W" && python3 "$SBP" --roadmap "$RM" --role leader) > "$T/lead.txt" 2> "$T/lead.err"; echo $?; }
show() { g show "$B:$1"; }
assert_eq "$(lead)" "0" "리더: 종료 코드 0"
printf '기준 커밋: %s\n역할 문서 (%s):\n%s\n규칙 (%s):\n%s\n%s\n' "$B" "$B" "$(show "${RD}leader/CLAUDE.md")" "$B" \
  "$(show "$TM/RULES.md")" "$(show "${RD}HANDBOOK.md")" > "$T/lead.want"
cmp -s "$T/lead.txt" "$T/lead.want" && ok "리더: 기준 커밋 · 리더 역할 문서 · 규칙뿐이고 글은 기준 커밋의 것이다" || no "리더: 묶음이 기대와 다르다"
assert_eq "$(grep -c '^- \[' "$T/lead.txt")" "3" "AC22: 조건이 맞지 않는 줄도 전부 실린다"
cp "$T/lead.txt" "$T/lead.first"
printf '\n- 작업 폴더에서만 고친 줄\n' >> "$W/${RD}leader/CLAUDE.md"; printf 'x\n' >> "$W/$TM/RULES.md"; printf 'x\n' >> "$W/${RD}HANDBOOK.md"
lead > /dev/null; cmp -s "$T/lead.txt" "$T/lead.first" && ok "AC21: 작업 폴더의 사본을 고쳐도 출력이 같다" || no "AC21: 작업 폴더의 사본이 묶음에 샜다"
g checkout -q -- "$RD"
```

이어서: ① 예산 — 레포 설정에 `rules_budget: 40` 을 올리면 종료 코드는 `0` 이고 둘째 줄이 `알림: ` 으로 시작하며 `예산 초과` 와 팀 규칙 파일 경로를 담고, 그 한 줄을 뺀 나머지가 예산을 올리기 전 묶음과 줄마다 같다(기준 커밋 글자만 새 커밋이다). ② 팀 규칙 파일을 `main` 에서 지워 올리면 `0` 이고 `알림: ` 줄에 그 경로와 「기준 커밋에 없다」 가 있다. ③ 리더 역할 문서를 `main` 에서 지워 올리면 종료 코드 `1` 이고 표준 출력이 비었으며 표준 오류에 그 경로가 있다(U7 이 나 면 `0` 이고 `역할 문서: 없음` 줄). ④ `g remote set-head origin -d` 뒤에는 `3` 이고 표준 출력이 비었다(되돌린다). ⑤ 끝 줄바꿈 없는 역할 문서를 올리면 그 글 다음 줄이 `규칙 (` 으로 시작한다(앞 글에 붙지 않는다). ⑥ `--role worker` 만 주면 `2`, `--role boss` 는 `2`. ⑧ 로컬 `main` 에 올리지 않은 커밋(팀 규칙 파일을 고친 것)을 하나 두면 첫 줄은 여전히 `origin/main` 의 커밋이고 묶음에 그 고침이 없다 — 되돌린다(Review Focus 3). ⑦ AC31 — `leader-state` 브랜치를 `main` 에서 갈라 팀 규칙 파일 · 공통 규칙 파일 · 리더 역할 문서를 모두 고쳐 커밋하고, 아래처럼 함수 값을 바꿔 부른다:

```bash
(cd "$W" && python3 - "$S" "$RM" > "$T/patched.txt" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import team_layout
team_layout.leader_ref = lambda ref: "refs/heads/leader-state"
import start_bundle
sys.exit(start_bundle.main(["--roadmap", sys.argv[2], "--role", "leader"]))
PY
)
```

기대: 팀 규칙 파일의 글은 `leader-state` 의 것이고, 공통 규칙 파일과 리더 역할 문서의 글은 `$B` 의 것이며, 규칙 머리 줄은 `규칙 (<B> · 팀 규칙은 <leader-state 의 커밋>):` 다(U18 이 나 면 머리 줄은 그대로이고 `알림: ` 줄에 그 커밋이 있다). 바꾸지 않고 부른 묶음에는 `leader-state` 의 글이 한 줄도 없다(음의 짝).

변이(사본에서): `rules_block` 이 작업 폴더의 파일을 읽는다 → 「작업 폴더의 사본」 빨강 · 예산을 넘으면 `Refused` 를 던진다 → 「예산」 의 `0` 빨강 · `leader_ref` 를 부르지 않고 기준 커밋에서 읽는다 → ⑦ 빨강 · 공통 규칙 파일도 `leader_ref` 의 커밋에서 읽는다 → ⑦ 의 「공통 규칙 파일은 `$B` 의 것」 빨강.

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_start_bundle.sh | tail -n 3`
Expected: FAIL — `start_bundle.py` 가 없다

- [ ] **Step 3: 위 Produces 의 것과 `main(argv=None) -> int` 를 짓는다** — `main` 은 인자 풀이 뒤 `--job` · `--stage` 가 둘 다 없고 `--role` 이 `LEADER_ROLE` 일 때만 리더 묶음으로 간다(그 밖의 조합은 Task 5 이 채운다 — 이 과제에서는 `Usage`). `team_layout.leader_ref` 는 I2 대로 부른다.

- [ ] **Step 4: 통과와 락을 확인한다**

Run: `bash plugins/spec-distill/tests/test_start_bundle.sh | tail -n 1` · `python3 -m unittest plugins/spec-distill/tests/test_team_layout.py plugins/quality-gates/tests/test_utf8_explicit.py`
Expected: 통과

- [ ] **Step 5: 커밋** — `feat(spec-distill): 시작 묶음 — 기준 커밋의 역할 문서와 규칙`

---

### Task 5: 과제 묶음 — 과제 브랜치 커밋 · 원자료 · 읽을 것 · 쓸 것 · 검수 단계 (AC21 · AC24)

U1 · U2 · U3 · U4 · U5 · U8 에 기댄다(U6 · U7 은 Task 4 와 같다).

**Files:**
- Modify: `plugins/spec-distill/scripts/start_bundle.py`
- Test: `plugins/spec-distill/tests/test_start_bundle.sh`

**Interfaces:**
- Consumes: Task 4 의 `open_base` · `role_block` · `rules_block` · `emit` · Task 2 의 `default_role` · `team_status.Reader`(`flow`) · `PLAIN_FLOW` · `read_tip` · `task_jobs` · `job_results.result_names` · `newest` · `team_files.intent_meta` · `intent_ranges` · `format_ranges` · `parse_result` · `lost_lines` · `workflow_superpowers.place_sentence` · `roadmap_model.parse_roadmap` · `team_layout.result_name` · `parse_result_name` · `plan_number` · `job_name_problem` · `REVIEW_FILE` · Task 8 의 `team_files.roadmap_rel`(Task 8 이 뒤에 오므로 그때 잇는다 — 이 과제에서는 머리의 `roadmap` 을 인자와 글자로 견준다).
- Produces:
  - 명령 `start_bundle.py --roadmap <로드맵> --job <과제> --stage <단계> [--plan <n>] [--role <역할>]`.
  - `start_bundle.result_number(plain: bool, stage: str, plan: Optional[int]) -> Optional[int]` — 결과 파일 이름에 붙는 계획 번호(U1 가: 설계 없는 흐름이면 늘 `None`, 설계 흐름이면 `design` 은 `None` 이고 그 밖은 `plan`).
  - `start_bundle.attempt_of(names: list, read, stage: str, number: Optional[int]) -> tuple` — `(시도 번호, 바로 앞 시도의 이름 | None)`. `read(이름)` 은 그 결과 파일의 글이나 `None` 이다. 결과 파일이 없으면 `(1, None)`. 가장 새 시도에 끝 줄이 없고 읽지 못한 줄도 없으면 그 번호를 잇고(U2 가), 끝 줄이 있거나 읽지 못하면 다음 번호다.
  - `start_bundle.locate(git, base, blocks: list, job: str, plan: Optional[int]) -> tuple` — `(과제 브랜치 커밋, 흐름이 설계 없는 흐름인가, 단순 작업인가, 알림들)`. 에픽은 I12, 단순 작업은 I8.

과제 묶음의 꼴(줄의 차례 그대로):

```
기준 커밋: <기준 커밋> · 과제 브랜치 <과제 브랜치 커밋>
알림: <글>                                              ← 있을 때만
과제: <과제의 INTENT.md 경로>
원자료: <기준 커밋>:<원자료 경로> <범위>                ← design 은 범위 없이 · 단순 작업은 줄이 없다(U5)
읽을 것: <경로> · <경로> …
쓸 것: <결과 파일 경로>                                 ← 검수 단계는 없다
맞추는 명령: roadmap_write.py job sync --result <쓸 것> --role <역할> --bundle-at <기준 커밋> --job-at <과제 브랜치 커밋>   ← U8 · 검수 단계는 없다
쓸 자리: <place_sentence 의 문장>                       ← design · plan 만
역할 문서 (<기준 커밋>):                                ← 검수 단계는 없다
<글>
규칙 (<기준 커밋>):
<글>
검수 기준 (<기준 커밋>):                                ← 검수 단계만
<REVIEW.md 의 글>
```

- 범위는 INTENT.md 의 범위 줄에서 읽어 `2–4행 · 9–12행` 꼴로 적는다(`intent_ranges` → 조각마다 `%d–%d행`).
- `읽을 것` 은 과제 브랜치 커밋의 과제 폴더에서 — INTENT.md, 있으면 설계 파일, 계획 파일들(번호 차례), 그리고 U3 가 면 바로 앞 시도의 결과 파일과 가장 새 `review` 결과 파일(같은 계획의 것, 있을 때만). `design` 단계는 맨 앞에 `<기준 커밋>:<번호 파일 경로>` 가 온다(I5 — 기준 커밋에 그 파일이 있을 때만).
- 검수 기준 파일이 기준 커밋에 없으면 `검수 기준 (…):` 과 글 대신 `검수 기준: 없음 — <REVIEW_FILE> 가 없다` 한 줄이다(설계 §9).
- 과제 브랜치가 아직 없으면 과제 폴더를 기준 커밋에서 읽고 둘째 커밋 자리에 기준 커밋을 적으며 `알림: 과제 브랜치 <이름> 가 아직 없다 — 과제 폴더를 기준 커밋에서 읽었다` 를 낸다(U4 가). `read_tip` 의 알림(「아직 안 올라옴 …」)도 `알림:` 줄로 낸다. 갈라졌으면 `Unchecked`.
- 인자 규칙(어기면 `Usage`): `--job` 과 `--stage` 는 함께만 · 둘 다 없으면 `--role leader` 만 · 과제 묶음에 `--role leader` 는 안 된다 · `design` 에 `--plan` 은 안 된다 · 설계 흐름의 `plan` · `implement` · `review` 는 `--plan` 이 반드시 있다(설계 §9) · 설계 없는 흐름은 `plan` 단계에서만 `--plan` 을 받고(쓸 자리 문장의 번호) 그 밖의 단계에 주면 「설계 없는 흐름의 결과 파일에는 계획 번호가 붙지 않는다」 로 거절한다(U1 가) · `review` 에 `--role` 은 안 된다 · 과제 이름은 `job_name_problem` 을 지난다.
- 멈춤(`Refused`): 읽을 커밋에 과제의 INTENT.md 가 없다 · 머리의 `job` · `roadmap` 이 인자와 다르다 · 블록의 `브랜치:` 에 그 계획 번째가 없다(브랜치 칸이 아예 빈 블록은 「아직 없다」 로 본다) · 같은 이름의 로드맵 밖 과제가 둘이다 · 블록도 로드맵 밖 과제도 아닌 이름이다.

- [ ] **Step 1: 실패하는 테스트를 쓴다** (계획이 정한 테스트 — 라벨 머리 「과제:」 · 「쓸 것:」 · 「사용법:」)

준비(Task 4 의 준비 뒤): `feature/tm-e1` 을 `main` 에서 갈라 `$TM/jobs/E1/design.md` · `plan-1.md`(글은 한 줄씩)를 커밋 · push 하고 `J="$(g rev-parse feature/tm-e1)"`, `main` 으로 돌아온다. `job() { (cd "$W" && python3 "$SBP" --roadmap "$RM" "$@") > "$T/job.txt" 2> "$T/job.err"; echo $?; }` · `line() { sed -n "${1}p" "$T/job.txt"; }`.

```bash
E1="$TM/jobs/E1"
assert_eq "$(job --job E1 --stage implement --plan 1)" "0" "과제: implement 묶음"
assert_eq "$(line 1)" "기준 커밋: ${B} · 과제 브랜치 ${J}" "과제: 첫 줄의 두 커밋"
assert_eq "$(line 2)" "과제: ${E1}/INTENT.md" "과제: INTENT.md 경로"
assert_eq "$(line 3)" "원자료: ${B}:${TM}/intent/original.md 2–4행" "과제: 원자료는 커밋 · 경로 · 줄 범위"
assert_eq "$(line 4)" "읽을 것: ${E1}/INTENT.md · ${E1}/design.md · ${E1}/plan-1.md" "과제: 읽을 것"
assert_eq "$(line 5)" "쓸 것: ${E1}/results/implement-plan-1-1.md" "과제: 쓸 것은 시도 1"
assert_eq "$(line 6)" "맞추는 명령: roadmap_write.py job sync --result ${E1}/results/implement-plan-1-1.md --role worker --bundle-at ${B} --job-at ${J}" "과제: 맞추는 명령(U8)"
assert_eq "$(line 7)" "역할 문서 (${B}):" "과제: implement 의 기본 역할은 worker"
assert_eq "$(sed -n '8,$p' "$T/job.txt" | head -n "$(g show "$B:${RD}worker/CLAUDE.md" | wc -l | tr -d ' ')")" "$(g show "$B:${RD}worker/CLAUDE.md")" "과제: 역할 문서의 글"
assert_eq "$(grep -c 'sources.md' "$T/job.txt")" "0" "AC21: design 밖의 단계에는 번호 파일이 없다"
cp "$T/job.txt" "$T/job.first"; (cd "$W/docs" && python3 "$SBP" --roadmap "$RM" --job E1 --stage implement --plan 1) > "$T/job.second"
cmp -s "$T/job.first" "$T/job.second" && ok "AC24: 두 번 실행의 바이트가 같다(선 폴더가 달라도)" || no "AC24: 두 번 실행이 다르다"
assert_eq "$(job --job E1 --stage implement --plan 1 --role writer)" "0" "과제: --role writer"
assert_contains "$(cat "$T/job.txt")" "- 고친 문서의 목차와 앵커를 맞춘다." "과제: writer 의 역할 문서"
assert_eq "$(grep -c '^- 실서비스 배포$' "$T/job.txt")" "0" "과제: worker 의 줄은 없다"
```

이어서(같은 꼴로 줄을 단언한다):

- `--job E1 --stage plan --plan 1` — 쓸 것 `…/results/plan-plan-1-1.md` · `쓸 자리: 사용자 선호: 계획은 기본 자리 대신 ${E1}/plan-1.md 에 쓴다.` · 역할 문서는 designer 의 것 · 원자료에 범위가 있다.
- `--job E3 --stage design`(브랜치 `feature/tm-e3` 가 없다) — 첫 줄 `기준 커밋: ${B} · 과제 브랜치 ${B}` · 둘째 줄 `알림: 과제 브랜치 feature/tm-e3 가 아직 없다 — 과제 폴더를 기준 커밋에서 읽었다` · `원자료: ${B}:${TM}/intent/original.md`(범위 없이 줄이 거기서 끝난다) · `읽을 것: ${B}:${TM}/jobs/E3/sources.md · ${TM}/jobs/E3/INTENT.md` · `쓸 것: ${TM}/jobs/E3/results/design-1.md` · `쓸 자리: 사용자 선호: 설계문서는 기본 자리 대신 ${TM}/jobs/E3/design.md 에 쓴다.`(U4 가 나 면 종료 코드 `1` 이고 표준 출력이 비었다).
- `--job E1 --stage review --plan 1` — `역할 문서 (` 줄 · `쓸 것:` 줄 · `맞추는 명령:` 줄이 없고 `규칙 (${B}):` 이 있으며 마지막 줄이 `검수 기준: 없음 — REVIEW.md 가 없다`. 레포 맨 위에 검수 기준 파일(두 줄)을 `main` 에 올린 뒤에는 `검수 기준 (<새 기준 커밋>):` 과 그 두 줄로 끝난다.
- E2(블록에 `산출물:` 칸 — 설계 없는 흐름): 브랜치 `feature/tm-e2` 를 만들어 올린 뒤 `--job E2 --stage implement` 의 쓸 것은 `…/jobs/E2/results/implement-1.md`(U1 가). `--job E2 --stage implement --plan 1` 은 `2`(U1 이 나 면 `0` 이고 쓸 것이 `implement-plan-1-1.md`).
- 단순 작업: `chore/tm-fix` 브랜치에서 `printf '오타를 고친다\n' | python3 "$RW" job new --roadmap "$RM" --name fix-typo --branch chore/tm-fix --paths docs/tv/ --goal "오타 고치기"` 를 커밋 · push 하고 `main` 으로 돌아온다. `--job fix-typo --stage implement` — 첫 줄의 둘째 커밋이 `chore/tm-fix` 의 끝이고 `원자료:` 줄이 없으며(U5 가) 쓸 것이 `…/jobs/fix-typo/results/implement-1.md`. `--job no-such --stage implement` 는 `1` 이고 표준 출력이 비었다.
- 「쓸 것:」 — `feature/tm-e1` 에서 `sync E1 implement-plan-1-1.md --role worker --bundle-at "$B" --job-at "$J"`(끝 줄 없음)를 커밋 · push 하면 쓸 것은 여전히 `implement-plan-1-1.md` 다(U2 가 — 나 면 `-2.md`). `--end` 로 끝 줄을 달아 올리면 `implement-plan-1-2.md` 이고 읽을 것 끝에 `${E1}/results/implement-plan-1-1.md` 가 붙는다(U3 가 — 나 면 붙지 않는다). `review-plan-1-1.md`(리더가 쓴 꼴의 머리)를 올리면 읽을 것 끝에 그 경로도 붙는다. `plan-plan-1-1.md` 나 계획 2 의 결과 파일이 있어도 implement · 계획 1 의 시도 번호는 바뀌지 않는다. 머리가 깨진 `implement-plan-1-2.md` 를 올리면 쓸 것은 `-3.md` 다.
- 로컬이 앞선 과제 브랜치 — `feature/tm-e1` 에 올리지 않은 커밋을 하나 두면 첫 줄의 둘째 커밋이 로컬 끝이고 `알림: 아직 안 올라옴` 으로 시작하는 줄이 있다. origin 과 갈라지게 하면(`g push` 뒤 로컬을 `--amend`) `3` 이고 표준 출력이 비었다.
- 「사용법:」 — 아래는 모두 `2` 이고 표준 출력이 비었다: `--job E1`(단계 없음) · `--stage implement`(과제 없음) · `--job E1 --stage implement --role leader` · `--job E1 --stage design --plan 1` · `--job E1 --stage implement`(설계 흐름에 `--plan` 없음) · `--job E1 --stage review --plan 1 --role worker` · `--job ../x --stage design` · `--roadmap "/abs/${RM}" --role leader`. `--job E1 --stage implement --plan 3`(블록의 브랜치는 둘)은 `1` 이다.

변이(사본에서): `attempt_of` 가 끝 줄을 보지 않고 늘 다음 번호 → 「쓸 것은 여전히 -1」 빨강 · `result_number` 가 늘 `plan` 을 낸다 → E2 의 쓸 것 빨강 · 원자료 줄에 `design` 에서도 범위를 싣는다 → E3 의 원자료 빨강 · 번호 파일을 모든 단계에 싣는다 → 「design 밖의 단계에는 번호 파일이 없다」 빨강 · 과제 폴더를 작업 폴더에서 읽는다(`main` 에 선 채라 설계 파일이 없다) → 「읽을 것」 빨강 · 검수 단계에 역할 문서를 싣는다 → 검수 단언 빨강.

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_start_bundle.sh | tail -n 3`
Expected: 「과제:」 · 「쓸 것:」 · 「사용법:」 줄이 모두 실패(리더 묶음의 줄은 통과 그대로)

- [ ] **Step 3: `result_number` · `attempt_of` · `locate` 와 과제 묶음을 짓는다** — 로드맵 블록은 기준 커밋의 로드맵 글을 `parse_roadmap` 으로 읽는다. 흐름은 `team_status.Reader(git, base.commit, base.team, …).flow(block)` 가 가른다(같은 규칙을 다시 쓰지 않는다). 과제 폴더의 이름은 `git.names(<과제 브랜치 커밋>, team.job(job))` 으로 읽는다 — 작업 폴더를 읽지 않는다.

- [ ] **Step 4: 통과와 락을 확인한다**

Run: `bash plugins/spec-distill/tests/test_start_bundle.sh | tail -n 1` · `python3 -m unittest plugins/spec-distill/tests/test_team_layout.py plugins/quality-gates/tests/test_utf8_explicit.py` · `bash shared/tests/test_python_floor.sh | tail -n 1` · `bash shared/tests/test_no_new_duplication.sh | tail -n 1`
Expected: 통과

- [ ] **Step 5: 커밋** — `feat(spec-distill): 시작 묶음 — 과제의 읽을 것 · 쓸 것 · 검수 단계`

---

### Task 6: 「묶음 낡음」 알림 (AC23 · AC31)

U9 에 기댄다.

**Files:**
- Modify: `plugins/spec-distill/scripts/team_status.py`
- Test: `plugins/spec-distill/tests/test_team_stale.sh`(새 · 100755)

**Interfaces:**
- Consumes: Task 2 의 `team_layout.leader_ref` · `team_layout.role_doc` · `handbook` · `Team.rules` · `job_results.result_names` · `team_files.parse_result` · `lost_lines`.
- Produces:
  - `team_status.STALE = "묶음 낡음"`.
  - `team_status.Reader.stale(self, tip: str, block: dict) -> list` — 알림 줄들. 그 끝의 결과 파일 가운데 단계 · 계획마다 가장 새 시도이고 끝 줄이 없으며 읽지 못한 줄이 없는 것마다(U9 ② 가), 머리 `bundle_at` 의 글과 지금 글을 견준다(I4) — 팀 규칙 파일은 `git.commit(team_layout.leader_ref(self.main))` 에서, 공통 규칙 파일과 머리 `role` 의 역할 문서는 `self.main` 에서 읽는다. 다른 것이 있으면 `묶음 낡음: <결과 파일 이름> — 묶은 커밋 <8자> 뒤에 바뀜: <경로> · <경로>`. `bundle_at` 이 이 레포에 없는 커밋이면 `묶음 낡음을 재지 못했다: <결과 파일 이름> — 묶은 커밋 <8자> 가 이 레포에 없다`. 종료 코드에 드는 것(`git.failures`)을 남기지 않는다 — `git.blob` · `git.commit` 만 쓴다.
  - `Reader.progress` 가 얕은 클론 갈래를 지난 뒤(INTENT.md 를 읽은 뒤) `block["notes"]` 에 `self.stale(tip, block)` 을 더한다. 단계 글자 · 근거 · 종료 코드는 바꾸지 않는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다** (계획이 정한 테스트 — 라벨 머리 「낡음:」)

준비: Task 4 의 준비(공통 문서를 `main` 에 올린다) 뒤 `feature/tm-e1` 을 갈라 `sync E1 implement-plan-1-1.md --role worker --bundle-at "$B" --job-at "$(g rev-parse HEAD)"` 로 끝 줄 없는 결과 파일을 만들어 커밋 · push 하고 `main` 으로 돌아온다. `notes() { js "$T/s.json" "[n for b in r['blocks'] if b['id']=='$1' for n in b['notes'] if n.startswith('묶음 낡음')]"; }` · `bump() { printf '%s\n' "$2" >> "$W/$1"; g add -- "$1"; g commit -qm "고침 $1"; g push -q origin main; g fetch -q origin; }`.

```bash
RC0="$(status "$T/s.json")"
assert_eq "$(notes E1)" "[]" "낡음: 바뀐 것이 없으면 나오지 않는다"
bump "$TM/RULES.md" '- [문서] 바꾼 건 CHANGELOG에 · 출처: a · 확인: b'
assert_eq "$(status "$T/s.json")" "$RC0" "AC23: 종료 코드는 그대로다"
assert_eq "$(notes E1)" "['묶음 낡음: implement-plan-1-1.md — 묶은 커밋 ${B:0:8} 뒤에 바뀜: ${TM}/RULES.md']" "AC23: 팀 규칙이 바뀌면 나온다"
assert_contains "$(cd "$W" && python3 "$S/control_plane.py" show "$RM")" "정보: 묶음 낡음: implement-plan-1-1.md" "AC23: 현황의 그 과제 줄 아래에 보인다"
```

이어서: ① 그 줄을 지워 글을 되돌려 올리면 `[]`(I4). ② 공통 규칙 파일에 한 줄을 올리면 그 경로가 든 알림. 되돌린다. ③ `designer` 역할 문서만 고쳐 올리면 `[]`(결과 파일의 `role` 은 worker 다). `worker` 역할 문서를 고쳐 올리면 그 경로가 든 알림. ④ 둘이 함께 바뀌면 한 줄에 두 경로가 ` · ` 로 이어진다. ⑤ `feature/tm-e1` 에서 `--end` 로 끝 줄을 달아 올리면 `[]`(끝난 일꾼은 도는 일꾼이 아니다). ⑥ 끝 줄 없는 `implement-plan-1-2.md` 를 `--bundle-at` 에 이 레포에 없는 40자 16진(`1` 을 40번)으로 만들어 올리면 `묶음 낡음을 재지 못했다: implement-plan-1-2.md` 로 시작하는 줄 하나뿐이고 `묶음 낡음: ` 으로 시작하는 줄은 없으며 종료 코드가 `$RC0` 이다. ⑦ 설계 단계 — `feature/tm-e3` 에 끝 줄 없는 `design-1.md`(`--role designer`)를 올리고 `designer` 역할 문서를 고쳐 올리면 `notes E3` 에 알림이 있다(U9 ② 가 나 면 `[]`). ⑧ 검수 기준 파일을 레포 맨 위에 올려도 알림이 늘지 않는다(U9 ① 가 — 나 면 그 경로가 든다). ⑨ 로드맵 밖 과제 — `chore/tm-fix` 의 `fix-typo` 에 끝 줄 없는 `implement-1.md` 를 두면 `js "$T/s.json" "[n for j in r['jobs'] for n in j['notes'] if n.startswith('묶음 낡음')]"` 에 알림이 있다. ⑩ AC31 — 팀 규칙 파일을 `main` 과 같게 되돌린 뒤 `leader-state` 브랜치에서만 팀 규칙 파일과 공통 규칙 파일을 고치고, Task 4 ⑦ 과 같은 꼴로 `team_layout.leader_ref` 를 바꿔 `roadmap_status.main([RM, "--json"])` 을 돌린 보고에는 팀 규칙 파일 경로만 든 알림이 있다(공통 규칙 파일 경로는 없다). 바꾸지 않은 보고에는 알림이 없다.

변이(사본에서): `stale` 이 끝 줄을 보지 않는다 → ⑤ 빨강 · 역할 문서를 `role` 과 무관하게 넷 다 본다 → ③ 의 첫 단언 빨강 · 팀 규칙 파일을 `self.main` 에서 읽는다 → ⑩ 빨강 · 없는 커밋에서 「바뀜」 을 낸다 → ⑥ 빨강 · 알림을 낼 때 `git.fail` 을 부른다 → 「종료 코드는 그대로다」 빨강.

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_team_stale.sh | tail -n 3`
Expected: FAIL — 알림 줄이 없다(「바뀐 것이 없으면 나오지 않는다」 만 통과)

- [ ] **Step 3: `STALE` · `Reader.stale` 을 더하고 `progress` 에 잇는다** — 새 로컬 import 를 더하지 않는다. `team_layout.leader_ref` 는 I2 대로 부른다.

- [ ] **Step 4: 통과와 있는 테스트 · 락을 확인한다**

Run: `bash plugins/spec-distill/tests/test_team_stale.sh | tail -n 1` · `for t in test_team_status test_team_tasks test_roadmap_status; do bash plugins/spec-distill/tests/$t.sh | tail -n 1; done` · `python3 -m unittest plugins/spec-distill/tests/test_control_plane.py plugins/spec-distill/tests/test_team_layout.py`
Expected: 모두 통과(`CHECKED 14` 그대로 · 코드 지문 목록 그대로). 있는 단언이 빨개지면 고치지 않고 멈춰 보고한다.

- [ ] **Step 5: 커밋** — `feat(spec-distill): 도는 일꾼의 묶음이 낡았는지 현황에 알린다`

---

### Task 7: 단계 계산 쪽 수리 — 결과 파일 이름 꼴 알림 · 얕은 클론 가드 (통합 리뷰 ① · §미룸)

U1 · U15 에 기댄다.

**Files:**
- Modify: `plugins/spec-distill/scripts/team_status.py`
- Test: `plugins/spec-distill/tests/test_team_status.sh` · `plugins/spec-distill/tests/test_team_tasks.sh`

**Interfaces:**
- Produces:
  - `team_status.UNCOUNTED_SHAPE = "세지 않은 결과 파일"`. `Reader.progress` 가 그 끝의 implement 결과 파일 이름 가운데 계획 번호의 있고 없음이 흐름과 다른 것마다 `block["notes"]` 에 `세지 않은 결과 파일: <이름> — <흐름> 의 implement 결과 파일은 <맞는 이름 꼴> 이다` 를 더한다(맞는 이름 꼴은 `team_layout.result_name` 으로 지은 예 — 설계 흐름 `implement-plan-<계획>-1.md` · 설계 없는 흐름 `implement-1.md` 의 시도 자리만 그 파일의 시도로). 단계 · 근거 · 종료 코드는 그대로다.
  - `Reader.shallow()` — 얕은지 묻는 호출이 실패하거나 `true` · `false` 가 아닌 값을 내면 `self.git.fail("rev-parse", rc, err)` 로 남긴다(`run_err` 로 부른다). 돌려주는 글은 지금 그대로다.
  - `task_jobs` 의 가드 — `stage == UNKNOWN` 을 `reader.shallow() == SHALLOW` 로 바꾼다. `RESERVE_UNSCANNED` 구절은 진짜 얕은 클론일 때만 붙는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다** (계획이 정한 테스트)

`test_team_status.sh` 끝에 「이름 꼴:」 묶음 — 그 파일의 끝 상태에서 새 블록 브랜치를 쓰지 않고, 있는 브랜치에 결과 파일을 더해 잰다(끝 상태가 무엇인지는 그 파일 끝의 단언이 말한다 — 브랜치를 새로 만들어야 하면 `feature/tm-e3`):

- 설계 흐름 블록의 과제 브랜치에 `implement-1.md`(번호 없는 이름, `job sync` 로 만든다)만 있으면 — 단계 · 근거는 그 파일을 두기 전과 같고, 그 블록의 `notes` 에 `세지 않은 결과 파일: implement-1.md — 설계 흐름 의 implement 결과 파일은 implement-plan-1-1.md 이다` 가 있다.
- 설계 없는 흐름 블록(E2)의 브랜치에 `implement-plan-1-1.md` 가 있으면 — 단계는 「진행 중」 그대로이고 `세지 않은 결과 파일: implement-plan-1-1.md — 설계 없는 흐름 의 implement 결과 파일은 implement-1.md 이다` 가 있다.
- 꼴이 맞는 결과 파일만 있는 블록의 `notes` 에는 `세지 않은 결과 파일` 로 시작하는 줄이 없다(음의 짝). 세 경우 모두 종료 코드가 그 파일을 두기 전과 같다.

`test_team_tasks.sh` 끝에 「가드:」 묶음 — 얕지 않은 레포 `$W` 에서 얕은지 묻는 호출만 실패시키는 가짜 git 을 `PATH` 앞에 둔다:

```bash
FG="$T/fakegit"; mkdir -p "$FG"; REAL_GIT="$(command -v git)"
cat > "$FG/git" <<SH
#!/bin/sh
case " \$* " in *" --is-shallow-repository "*) echo "fatal: simulated shallow probe" >&2; exit 128;; esac
exec "$REAL_GIT" "\$@"
SH
chmod +x "$FG/git"
G_RC=0; (cd "$W" && PATH="$FG:$PATH" python3 "$RS" "$RM" --json) > "$T/guard.json" 2>/dev/null || G_RC=$?
assert_eq "$G_RC" "3" "가드: 얕은지 읽지 못하면 검사 불가(3)다"
assert_contains "$(js "$T/guard.json" "r['unknown_reasons']")" "git 읽기 실패 — git rev-parse 실패(rc 128): fatal: simulated shallow probe" "가드: 사유에 그 호출이 있다"
assert_contains "$(js "$T/guard.json" "[n for j in r['jobs'] if j['id']=='shal' for n in j['notes']]")" "예약 밖 변경: docs/shal-extra.md" "가드: 얕지 않은 레포의 예약 알림은 떨어지지 않는다"
assert_eq "$(js "$T/guard.json" "[j['reason'] for j in r['jobs'] if j['id']=='shal'][0].endswith('예약도 재지 않았다')")" "False" "가드: 구절은 진짜 얕은 클론에만 붙는다"
```

(과제 이름 `shal` 과 파일 `docs/shal-extra.md` 는 그 파일의 얕은 클론 묶음이 이미 쓰는 것이다 — 그 묶음의 「얕지 않은 레포에서 shal 은 예약 알림을 낸다」 단언 바로 뒤에 둔다.) 있는 깊이 1 · 3 단언은 고치지 않고 그대로 통과해야 한다.

변이(사본에서): 가드를 `stage == UNKNOWN` 으로 되돌린다 → 「예약 알림은 떨어지지 않는다」 빨강 · `shallow()` 가 실패를 남기지 않는다 → 「검사 불가(3)」 빨강 · 이름 꼴 알림이 흐름을 뒤집어 본다 → 「꼴이 맞는 결과 파일만」 빨강.

**다른 안이면:** U1 이 나 — 알림을 두지 않고 `progress` 가 두 꼴의 이름을 모두 찾아 시도 번호가 가장 큰 것을 읽는다(번호가 같으면 흐름에 맞는 꼴). 위 「이름 꼴:」 의 기대값은 「그 파일로 단계가 넘어간다」 로 바뀐다. U1 이 다 — 가 에 더해 `job sync` 와 `job_results.check_result` 가 흐름과 다른 꼴을 종료 코드 1 로 거절한다(둘 다 기본 브랜치의 로드맵 블록을 읽어 흐름을 가른다). U15 가 나 — `shallow()` 를 고치지 않고 「검사 불가(3)」 단언을 `0` 으로, 사유 단언을 뺀다.

- [ ] **Step 2: 실패를 확인한다** — Run: `bash plugins/spec-distill/tests/test_team_status.sh | tail -n 3` · `bash plugins/spec-distill/tests/test_team_tasks.sh | tail -n 3`. Expected: 새 단언만 실패.

- [ ] **Step 3: 셋을 고친다** — 이름 꼴은 `job_results.result_names` 가 낸 이름을 `team_layout.parse_result_name` 으로 읽어 가른다.

- [ ] **Step 4: 통과를 확인한다** — Run: 위 둘과 `bash plugins/spec-distill/tests/test_roadmap_status.sh | tail -n 1` · `bash plugins/spec-distill/tests/test_team_stale.sh | tail -n 1`. Expected: 모두 통과.

- [ ] **Step 5: 커밋** — `fix(spec-distill): 흐름과 다른 꼴의 결과 파일을 알리고 얕은 클론 가드를 얕은 클론으로 좁힌다`

---

### Task 8: 쓰는 쪽과 글 읽기 수리 — task 절 수 · 이어 쓰는 머리 · `roadmap:` 경로 (통합 리뷰 ③ · §미룸)

U13 · U2 에 기댄다.

**Files:**
- Modify: `plugins/spec-distill/scripts/team_files.py` · `team_write.py` · `check_bundle_coverage.py` · `spec_review_bundle.py` · `start_bundle.py`
- Test: `plugins/spec-distill/tests/test_team_results.py`(T-b) · `test_team_sync.sh`(T-c) · `test_team_files.py` · `test_team_coverage.sh` · `test_team_review_entry.sh` · `test_start_bundle.sh`

**Interfaces:**
- Produces:
  - `team_files.progress_of(result) -> tuple` — 전체는 마지막 `Task` 줄의 것이다. 깨짐은 어느 줄이든 번호가 1 보다 작거나 그 줄의 전체가 1 보다 작거나 번호가 그 줄의 전체보다 클 때뿐이다(U13 가).
  - `job sync` — 있는 결과 파일에 끝 줄이 없고 `--bundle-at` · `--job-at` 을 주면 머리의 그 두 줄을 새 값으로 고친다(다른 머리 줄과 본문은 바이트 그대로 · 화면 줄에 `묶은 커밋 고침`). 둘 가운데 하나만 주면 사용법 오류(2). 끝 줄이 있는 파일은 지금처럼 고치지 않는다. `--role` 은 있는 파일에서 지금처럼 쓰지 않는다(U2 가).
  - `team_write.py` 의 진행 줄 주석 — 「계획의 task 절 수보다 큰 번호와 task 절이 없는 계획만 거절한다. 전체가 앞 줄과 달라지는 것은 쓴다 — 읽는 쪽이 마지막 줄의 전체를 쓴다」 로.
  - `team_files.roadmap_rel(meta: dict) -> str` — 머리 `roadmap` 의 값. 비었거나, `/` 로 시작하거나, 역슬래시가 들었거나, `/` 로 나눈 조각에 `..` 이 있으면 `FormatError`(`머리 roadmap 이 레포 상대 경로가 아니다: <값>`).
  - INTENT.md(머리 `type: job`)의 `roadmap` 을 읽는 자리(Task 1 이 센 곳 가운데 과제 파일을 읽는 것)가 `roadmap_rel` 을 거친다. `FormatError` 는 그 과제의 로드맵을 읽지 못한 것과 같은 갈래로 간다(I11). **옛 묶음(`type: epic-bundle`)의 `roadmap:` 읽기는 건드리지 않는다** — 옛 형식 출력이 그대로여야 한다. `start_bundle.py` 는 머리의 `roadmap` 을 `roadmap_rel` 로 읽어 인자와 견준다.

- [ ] **Step 1: 실패하는 테스트를 쓴다** (계획이 정한 테스트)

`test_team_results.py` `Progress` — T-b: `test_numbers` 의 깨짐 목록에서 전체가 줄마다 다른 한 원소(`Task 1/7` 뒤의 `Task 2/8`)를, `test_reason_carries_the_line_as_written` 에서 `Task 2/8: 끝 — b` 갈래를 빼고(그 클래스의 다른 깨짐 줄은 그대로 둔다) 아래 둘을 더한다.

```python
    def test_total_follows_the_last_line(self):   # 구현 중에 계획의 task 절이 늘거나 줄었다(U13)
        grew = "Task 1/5: 끝 — aaa1111\nTask 2/5: 끝 — bbb2222\nTask 3/6: 끝 — ccc3333\n"
        self.assertEqual(self.p(grew), (3, 6, None))
        shrank = "Task 1/5: 끝 — aaa1111\nTask 2/4: 막힘 — bbb2222\n"
        self.assertEqual(self.p(shrank), (1, 4, None))

    def test_a_number_above_its_own_total_is_still_broken(self):
        why = self.p("Task 6/5: 끝 — aaa1111\nTask 2/6: 끝 — bbb2222\n")[2]
        self.assertTrue(why.startswith("진행 줄 깨짐 — Task 6/5"), why)
```

(`self.p` 는 그 클래스가 이미 쓰는 도우미다 — 본문 글에 머리를 붙여 `progress_of(parse_result(…))` 를 낸다.)

`test_team_sync.sh` — T-c: 「머리 인자: 있는 파일에 다른 머리 값을 줘도 rc 0」 뒤의 두 단언(「바뀐 것 없음」 · 「있는 머리는 고치지 않는다(바이트 그대로)」)을 아래로 바꾼다.

```bash
assert_contains "$(cat "$T/out.txt")" "묶은 커밋 고침" "머리 인자: 끝 줄 없는 파일은 묶은 커밋 둘을 고친다"
assert_eq "$(grep -c "^bundle_at: ${J0}\$" "$F8") $(grep -c "^job_at: ${J0}\$" "$F8") $(grep -c '^role: worker$' "$F8")" "1 1 1" "머리 인자: 두 커밋만 새 값이고 role 은 그대로다"
assert_eq "$(diff <(grep -v -e '^bundle_at:' -e '^job_at:' "$T/h8.before") <(grep -v -e '^bundle_at:' -e '^job_at:' "$F8") | wc -l | tr -d ' ')" "0" "머리 인자: 그 두 줄 밖은 바이트 그대로다"
```

이어서 둘을 더한다 — 끝 줄이 있는 파일에 다른 `--bundle-at` 을 주면 파일이 바이트 그대로다(`cmp`) · `--bundle-at` 만 주고 `--job-at` 을 빼면 `2` 다.

`test_team_files.py` 에 `RoadmapRel` — `{"roadmap": "docs/x/tm/roadmap.md"}` 는 그 값, `""` · 키 없음 · `"/abs/roadmap.md"` · `"../out/roadmap.md"` · `"docs/../../out.md"` · `"docs\\x\\roadmap.md"` 는 `FormatError`. `"docs/a..b/roadmap.md"` 는 받는다(조각이 `..` 인 것만 막는다).

`test_team_coverage.sh` · `test_team_review_entry.sh` 에 하나씩 — 과제의 INTENT.md 머리 `roadmap:` 을 `../../outside/roadmap.md` 로 바꾼 사본으로 번호 대조와 spec-review 진입을 돌리면 통과(0)가 아니고, 출력에 「레포 상대 경로가 아니다」 가 있다(그 파일들에서 「옆 INTENT.md 없음」 을 재는 단언과 같은 종료 코드다 — 그 값을 그대로 쓴다). `test_start_bundle.sh` 에 하나 — 과제 브랜치의 INTENT.md 머리 `job:` 을 다른 이름으로 바꿔 올리면 `1` 이다.

변이(사본에서): `progress_of` 가 첫 줄의 전체를 쓴다 → `test_total_follows_the_last_line` 빨강 · 번호 > 전체 검사를 뺀다 → 둘째 테스트 빨강 · `job sync` 가 끝 줄 있는 파일의 머리도 고친다 → 「끝 줄이 있는 파일」 빨강 · `roadmap_rel` 이 `..` 를 받는다 → `RoadmapRel` 빨강.

**다른 안이면:** U13 이 나 — `progress_of` 와 T-b 를 고치지 않고, `job sync` 가 있는 `Task` 줄의 전체와 다른 전체의 줄을 쓰려 하면 종료 코드 1(`계획의 task 절 수가 <앞>개에서 <뒤>개로 바뀌었다 — 진행 줄을 쓰지 않았다`)이고 `test_team_sync.sh` 에 그 단언을 더한다. U13 이 다 — 코드와 테스트를 고치지 않는다(문서만 — Task 11). U2 가 나 — `job sync` 와 T-c 를 고치지 않는다.

- [ ] **Step 2: 실패를 확인한다** — Run: `python3 -m unittest plugins/spec-distill/tests/test_team_results.py plugins/spec-distill/tests/test_team_files.py` · `bash plugins/spec-distill/tests/test_team_sync.sh | tail -n 3`. Expected: 새 · 바꾼 단언만 실패.

- [ ] **Step 3: 넷을 고친다.**

- [ ] **Step 4: 통과와 옛 형식을 확인한다** — Run: 위와 `for t in test_team_coverage test_team_review_entry test_bundle_coverage test_spec_review_bundle test_team_status test_start_bundle; do bash plugins/spec-distill/tests/$t.sh | tail -n 1; done`. Expected: 모두 통과. `test_bundle_coverage.sh` · `test_spec_review_bundle.sh`(옛 형식)는 한 줄도 고치지 않은 채 통과해야 한다.

- [ ] **Step 5: 커밋** — `fix(spec-distill): 진행 줄은 마지막 줄의 전체로 세고, 이어 쓰는 결과 파일의 묶은 커밋을 고치며, 과제 머리의 로드맵 경로를 레포 안으로 묶는다`

---

### Task 9: 앞 계획이 넘긴 테스트 보강 (PR #290 잔여의 「계획 3」 줄)

**Files:**
- Test: `plugins/spec-distill/tests/test_team_results.py` · `test_team_sync.sh` · `test_team_status.sh` · `test_roadmap_status.sh`(라벨 글만) · `test_conductor_ledger.py`

코드는 고치지 않는다. 있는 단언의 기대값을 바꾸지 않는다 — 단언을 더하거나 조인다. 새 단언이 지금 코드에서 빨개지면 고치지 않고 그 사실을 보고한다(받는 곳은 리더가 정한다). 모두 계획이 정한 테스트다.

- [ ] **Step 1: 펜스 아닌 꼴 뒤의 진짜 펜스** — `test_team_results.py` `Parse` 에: 본문이 「네 칸 들여쓴 백틱 세 개 줄(펜스가 아니다) → 빈 줄 → 진짜 펜스 열림 → `끝 — abc1234` → 펜스 닫힘 → 펜스 밖의 `끝 — def5678`」 이면 `r.end == "def5678"` 이고 `r.problems == []` 다. 변이: 들여쓴 줄을 펜스 열림으로 읽게 → 빨강.
- [ ] **Step 2: 머리 뒤 빈 줄 하나** — `test_team_sync.sh` 의 「머리를 만든다」 뒤에: 새로 만든 결과 파일의 바이트가 `---\n` 으로 닫힌 머리 뒤에 `\n` 하나로 끝난다(파이썬 한 줄로 `data.endswith(b"---\n\n") and not data.endswith(b"---\n\n\n")`). 변이: `_new_head` 가 빈 줄 둘을 붙인다 → 빨강.
- [ ] **Step 3: 「갈라짐」 과 조상 판정 실패** — `test_team_status.sh` 「끝:」 에: 조상 판정(`merge-base`)만 실패시키는 가짜 git(Task 7 의 꼴)으로 같은 블록을 계산해, 근거가 진짜 갈라짐일 때의 근거와 같은지 다른지를 **잰 대로** 단언으로 못 박는다. 같게 나오면(조상 판정 실패가 「갈라짐」 으로 보인다) 단언은 지금 동작대로 쓰고 보고에 「미룸 후보 — `branch_tip.tip` 이 조상 판정 실패와 갈라짐을 가르지 않는다」 로 올린다. `test_roadmap_status.sh` 의 정적 락 아래 `branch_tip` 라벨(「… 끝 고르기 …」 를 말하는 줄)이 단언보다 넓게 말하면 라벨 글만 단언이 재는 만큼으로 줄인다(단언은 그대로).
- [ ] **Step 4: BOM 걸음 · 얕은 클론 사유 · 끝 상태** — `test_team_status.sh` 에: ① BOM 이 붙은 결과 파일의 걸음에 그 블록 `progress` 칸의 `why` 가 `머리(첫 줄 \`---\`)가 없다` 를 담는다는 단언. ② 깊이 1 얕은 클론의 사유 단언을 E2 뿐 아니라 브랜치가 있는 다른 블록에도. ③ 파일 끝의 끝 상태 단언에 `origin/main` 과 기능 브랜치들의 끝 커밋(그 파일이 변수로 든 것)을 더한다. ④ 깊이 3 얕은 클론을 「일부 머지」 가 아닌 블록에도 잰다(잔여 Minor 9 — 단계 「알 수 없음」 · 근거가 `얕은 클론이라` 로 시작).
- [ ] **Step 5: 종류 밖 줄 거절의 사유** — `test_conductor_ledger.py` `TeamRecords` 의 종류 밖 줄 거절 테스트 둘에: 종료 코드 2 와 함께 표준 오류가 결정 기록의 종류 이름(`team_files.DECISION_KINDS` 의 첫 원소)을 담는다(argparse 의 사용법 오류와 가른다). 「준비 블록」 을 전제로 적은 틀린 주석을 그 테스트가 실제로 만드는 상태로 고친다. 날짜 칸 없는 `넘김 확인` 줄을 team `record` 가 받는(종료 코드 0 · INTENT.md 에 그 줄) 테스트 하나를 더한다(계획 2 의 Q16).
- [ ] **Step 6: 통과를 확인한다** — Run: `python3 -m unittest plugins/spec-distill/tests/test_team_results.py plugins/spec-distill/tests/test_conductor_ledger.py` · `for t in test_team_sync test_team_status test_roadmap_status; do bash plugins/spec-distill/tests/$t.sh | tail -n 1; done`. Expected: 통과(빨개진 새 단언은 Step 머리의 규칙대로 보고한다).
- [ ] **Step 7: 커밋** — `test(spec-distill): 앞 계획의 리뷰가 넘긴 단언의 빈틈을 메운다`

---

### Task 10: devbrew 레포의 REVIEW.md · HANDBOOK.md · 역할 문서 넷, 리더 틀 한 줄 (AC25)

U10 · U16 · U17 에 기댄다. **이 과제는 세 답이 모두 온 뒤에만 시작한다** — 레포의 모든 PR 리뷰가 읽는 파일과 사람이 PR 로만 고치는 파일을 만든다.

**Files:**
- Create: `REVIEW.md`(레포 맨 위) · `<roadmaps_dir>HANDBOOK.md` · `<roadmaps_dir>{leader,designer,writer,worker}/CLAUDE.md` — `<roadmaps_dir>` 은 `python3 plugins/spec-distill/scripts/repo_defaults.py get roadmaps_dir` 가 내는 값이다(설정을 바꾸지 않는다 — `.devbrew.md` 를 만들지 않는다).
- Modify: `plugins/spec-distill/templates/team/role-leader.md`(U10 가)
- Test: `plugins/spec-distill/tests/test_team_docs.py` · `test_team_files.py`

**Interfaces:**
- Produces: 레포의 파일 여섯. 리더 틀 `## 할 일` 끝에 `- 규칙을 고친 뒤 규칙 검사(team_rules.py check)를 돌린다.` 한 줄.

`REVIEW.md` 의 글(U16 가 의 초안 — 설계 §8 의 문장을 옮겼다. 사용자가 고친 글이 오면 그 글을 쓴다):

    # REVIEW

    ## 반려

    - 테스트가 하나라도 실패하면 반려한다.
    - 실제로 돌려 보거나 화면을 봤을 때 잘못됐으면 반려한다.

    ## 반려는 한 줄

    - 어디서 · 무엇이 · 어떤 기준에 걸렸는지 한 줄로 적어 되돌려 보낸다.

(위 열 줄은 네 칸 들여쓴 것이다 — 파일에는 들여쓰기 없이 쓴다.)

- [ ] **Step 1: 실패하는 테스트를 쓴다** (계획이 정한 테스트)

```python
class RepoFiles(unittest.TestCase):   # R1 AC25 — devbrew 레포의 공통 문서
    def rd(self):
        import repo_defaults
        self.assertFalse((REPO / repo_defaults.SETTINGS_FILE).exists())   # 설정을 바꾸지 않았다
        return repo_defaults.ROADMAPS_DIR

    def test_review_file_at_the_top(self):
        text = (REPO / L.REVIEW_FILE).read_text(encoding="utf-8")
        for part in ("테스트가 하나라도 실패", "실제로 돌려 보거나 화면을 봤을 때", "어디서 · 무엇이 · 어떤 기준에 걸렸는지 한 줄"):
            self.assertIn(part, text)

    def test_handbook_carries_the_principle(self):
        text = (REPO / L.handbook(self.rd())).read_text(encoding="utf-8")
        self.assertIn("잘못 쌓인 맥락은 없는 것보다 나쁘다. 이 파일의 줄은 쓰기 전에 지금 확인하고, 틀렸으면 지운다.", text)

    def test_four_role_docs_with_two_sections(self):
        for role in L.ROLES:
            lines = (REPO / L.role_doc(self.rd(), role)).read_text(encoding="utf-8").splitlines()
            self.assertEqual([l for l in lines if l.startswith("#")], ["## 할 일", "## 하지 않을 일"], role)
            self.assertIn("- 받은 규칙은 쓰기 전에 지금도 맞는지 확인한다.", lines, role)
            self.assertEqual(sorted(p.name for p in (REPO / self.rd() / role).iterdir()), [L.ROLE_DOC], role)   # 역할 폴더는 로드맵 폴더가 아니다
```

`test_team_files.py` `Templates` 에 — 리더 틀의 `## 할 일` 칸에 `- 규칙을 고친 뒤 규칙 검사(team_rules.py check)를 돌린다.` 가 있고 다른 세 틀에는 없다. 변이: `REVIEW.md` 를 `docs/` 아래에 둔다 → 첫 테스트 빨강 · 역할 폴더에 `roadmap.md` 를 둔다 → 셋째 테스트 빨강.

**다른 안이면:** U10 이 나 · 다 — 틀을 고치지 않고 그 단언을 뺀다. U16 이 나 — 사용자가 준 칸을 초안 뒤에 더하고 첫 테스트는 그대로다. U17 이 나 — 사용자가 준 글로 쓰고 Step 3 의 `cmp` 를 뺀다.

- [ ] **Step 2: 실패를 확인한다** — Run: `python3 -m unittest plugins/spec-distill/tests/test_team_docs.py -k RepoFiles`. Expected: FAIL — `FileNotFoundError`.

- [ ] **Step 3: 틀을 고치고 파일 여섯을 둔다** — 역할 문서 넷과 HANDBOOK.md 는 플러그인 틀을 그대로 복사한다(`templates/team/role-<역할>.md` → `<roadmaps_dir><역할>/CLAUDE.md`, `templates/team/HANDBOOK.md` → `<roadmaps_dir>HANDBOOK.md`). 복사 뒤 `cmp` 로 다섯이 틀과 바이트가 같은지 한 번 본다(영구 락으로 두지 않는다 — 이 파일들은 뒤에 사람이 PR 로 고친다).

- [ ] **Step 4: 통과와 레포 락을 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_docs.py plugins/spec-distill/tests/test_team_files.py plugins/spec-distill/tests/test_review_hook_removed.py` · `for t in test_stale_terms test_repo_literals test_roadmap_status test_team_write; do bash plugins/spec-distill/tests/$t.sh | tail -n 1; done` · `(python3 plugins/spec-distill/scripts/control_plane.py show; echo "rc=$?") | tail -n 5`
Expected: 통과. 마지막 명령의 로드맵 목록이 이 과제 앞과 같다(역할 폴더가 로드맵으로 세어지지 않는다 — 바이트 대조는 Task 12). 이 여섯 파일은 R1 의 경로 예약에 있어 이 브랜치의 단계 계산에 「경로 예약 위반」 알림이 나오지 않아야 한다(설계 §Metadata ⑤ 는 예약에 넣기 전의 글이다) — 나오면 그 줄을 보고에 적는다.

- [ ] **Step 5: 커밋** — 둘로 나눈다(틀과 레포 파일은 되돌릴 단위가 다르다). 첫째 `feat(spec-distill): 리더 틀에 규칙 검사 한 줄` 에 틀과 `test_team_files.py`, 둘째 `docs: devbrew 의 검수 기준 · 공통 규칙 파일 · 역할 문서 넷` 에 레포의 파일 여섯과 `test_team_docs.py` 의 `RepoFiles`.

---

### Task 11: 형식 정본 문서 §7 · §8 · §9 · §15 · README · CHANGELOG · 판 (AC26 · AC24 의 두 길 · AC31 의 흐름 표)

U 행 모두의 답이 문서 문장에 닿는다 — 문장은 고른 안대로 쓴다.

**Files:**
- Modify: `plugins/spec-distill/references/team-files.md` · `README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json`
- Test: `plugins/spec-distill/tests/test_team_docs.py`(T-a · T-d)

**문서에 적을 것**(문장은 구현자가 쓴다 — 아래는 빠지면 안 되는 내용이다. 「계획 3」 · 「다음 판」 같은 만드는 차례의 말은 쓰지 않는다. `## 목차` 는 두지 않는다 — 계획 2 에서 받은 답이다):

- **§7 RULES.md 와 HANDBOOK.md**(§6 뒤) — 줄 꼴과 Task 3 의 문법 여덟 줄 · 사용자가 붙인 예시 줄 여섯을 펜스 안에 글자 그대로(`[테스트] 고친 곳엔 테스트 먼저` · `[배포] 실 서비스는 사람만` · `[문서] 바꾼 건 CHANGELOG에` · `[폴더] 남의 폴더 고치지 않기` · `[보고] 끝나면 leader에게` · `[설계] 승인 전엔 코드 짜지 않기`)와 「다른 팀의 규칙이라 살아 있는 규칙으로 깔지 않는다」 · 운영 다섯(쓰는 사람은 리더뿐 · 쓰기 전에 지금 확인 · 바이트 예산과 설정 키 둘 · 승격과 `반례 확인` · 지우기) · 같은 지적은 출처에 덧붙인다 · 조건으로 골라 싣지 않는다 · `check` 와 `candidates` 의 명령 꼴 · 출력 첫 줄 · 어긋남 줄 꼴 · 종료 코드 · 작업 폴더가 기본이고 `--ref` · 검사를 언제 돌리나(U10) · 예산 기본값의 근거 표시(U11).
- **§8 REVIEW.md** — 레포 맨 위인 까닭(공식 파일) · 생성기는 깔지 않는다 · 닿는 길은 검수 단계의 묶음 하나 · 구현 중 리뷰와 quality-gates 에는 닿지 않는다 · 팀마다 다른 검수 규칙은 팀 규칙 파일의 줄로.
- **§9 시작 묶음** — 명령 줄 둘(과제 · 리더) · 출력의 줄과 차례(Task 4 · Task 5 의 꼴) · 단계마다 다른 것(`design` 의 원자료 전체와 번호 파일 · `design` · `plan` 의 쓸 자리 · 검수 단계) · 기본 역할 · 인자 규칙 · 종료 코드와 멈추는 조건 · 알림 줄 · **건네는 두 길**(셸이 있는 일꾼은 받은 명령으로 직접 돌린다 / 셸이 없는 일꾼에게는 리더가 출력을 임시 파일로 받아 그 경로를 넘긴다 — 리더는 그 출력을 읽지 않는다) · 묶음은 레포에 남기지 않는다 · 같은 바이트의 조건 · 시도 번호(U2) · 결과 파일 이름의 계획 번호(U1) · 과제 브랜치가 없을 때(U4) · 단순 작업(U5) · `<커밋>:<경로>` 를 읽는 법.
- **§15 브랜치 사이 흐름**(끝) — 설계 §15 의 흐름 표 여덟 행(REVIEW.md 의 「낡았을 때」 칸은 U9 ①) · 리더가 쓰는 자리와 지금의 값(기본 브랜치) · 그 ref 를 내는 함수 `team_layout.leader_ref` · 기준 커밋 · 퍼지는 길은 시작 묶음 하나 · 브랜치 끝의 정본은 origin · 옆 과제.
- **있는 절의 고침** — §1 표 셋과 §2 결정 기록 항목의 「계획 3 이 §15 로 적는다」 를 「§15」 로 · §2 에 「기본 브랜치에 커밋된 단순 작업 폴더는 머리의 `branch` 와 무관하게 머지됨으로 센다 — `job new` 는 그 작업의 브랜치에서 돌려 그 브랜치에 커밋한다」(통합 리뷰 ②) · §2 의 `paths` 에 「폴더는 `/` 로 끝낸다 — 끝에 `/` 가 없으면 예약 알림은 파일 하나로 본다」(U14) · §5 의 시도 번호 문장(U2) · 진행 줄의 전체(U13) · `job sync` 가 고치는 머리 줄(U2) · §6 에 리더 틀의 한 줄(U10) · §10 에 「묶음 낡음」 두 알림 줄과 보는 파일 · 이름 꼴 알림(U1) · 얕은 클론 가드 문장(U15 — 「알 수 없음」 이 아니라 얕은 클론일 때만 재지 않는다 · 얕은지 읽지 못하면 검사 불가) · 「결과 파일이 블롭이 아닐 때 블록은 판정 읽기 불가로 검사 불가(3)이고 로드맵 밖 과제는 알림만 낸다(판정 줄을 읽지 않는다)」(잔여 Minor 1) · 「이름이 맞는 브랜치에서 이미 센 과제의 다른 브랜치 사본은 알림 없이 건너뛴다」(잔여 Minor 10) · 「얕은 클론에서 브랜치가 지워진 블록은 옛 형식과 같이 브랜치 없음으로 읽힌다」(잔여 표).

- [ ] **Step 1: 실패하는 테스트를 쓴다** (계획이 정한 테스트 — `test_team_docs.py`)

T-a: `test_sections_of_this_plan` 의 기대 목록을 `["## §1 팀 폴더", "## §2 과제 폴더와 INTENT.md", "## §3 원자료", "## §4 sources.md", "## §5 결과 파일", "## §6 역할 문서", "## §7 RULES.md 와 HANDBOOK.md", "## §8 REVIEW.md", "## §9 시작 묶음", "## §10 단계 계산", "## §15 브랜치 사이 흐름"]` 로.

```python
class RulesAndBundleDoc(unittest.TestCase):   # R1 AC26 — 계획 3 몫
    def doc(self, head):
        return section(DOC.read_text(encoding="utf-8"), head)

    def test_section7_grammar_and_the_users_six_lines(self):
        s = self.doc("## §7 RULES.md 와 HANDBOOK.md")
        for line in ("[테스트] 고친 곳엔 테스트 먼저", "[배포] 실 서비스는 사람만", "[문서] 바꾼 건 CHANGELOG에",
                     "[폴더] 남의 폴더 고치지 않기", "[보고] 끝나면 leader에게", "[설계] 승인 전엔 코드 짜지 않기"):
            self.assertIn("\n" + line + "\n", s)   # 원문 대조 — 글자 그대로
        for word in TR.MARKERS + repo_defaults.BUDGET_KEYS + ("team_rules.py check", "team_rules.py candidates", "--ref"):
            self.assertIn(word, s)

    def test_section9_two_ways_and_the_lines(self):   # AC24 — 묶음을 건네는 두 길
        s = self.doc("## §9 시작 묶음")
        for part in ("일꾼이 직접 돌린다", "임시 파일로 받아 그 경로를 넘긴다", "리더는 그 출력을 읽지 않는다",
                     "start_bundle.py --roadmap", "--role " + L.LEADER_ROLE, "기준 커밋:", "읽을 것:", "쓸 것:", "검수 기준"):
            self.assertIn(part, s)

    def test_section15_flow_table(self):   # AC31
        s = self.doc("## §15 브랜치 사이 흐름")
        rows = [l for l in s.splitlines() if l.startswith("| ")]
        self.assertEqual(len(rows), 9)   # 머리 행 하나 · 파일 여덟 행(가름 행은 `|---` 로 시작해 들지 않는다)
        for part in ("leader_ref", "기준 커밋", TS.STALE, "origin"):
            self.assertIn(part, s)

    def test_no_pointer_to_a_later_plan_is_left(self):   # 음의 락 + 양의 짝
        text = DOC.read_text(encoding="utf-8")
        self.assertNotIn("계획 3 이", text)
        self.assertGreaterEqual(text.count("리더가 쓰는 자리(§15)"), 3)

    def test_section10_new_notices(self):
        s = self.doc("## §10 단계 계산")
        for part in (TS.STALE + ": ", TS.STALE + "을 재지 못했다", TS.UNCOUNTED_SHAPE, "얕은지"):
            self.assertIn(part, s)

    def test_readme_names_the_new_commands(self):
        text = README.read_text(encoding="utf-8")
        for part in ("scripts/start_bundle.py", "scripts/team_rules.py", TS.STALE):
            self.assertIn(part, text)
```

(`section` · `DOC` · `README` · `PLUGIN` · `TS` 는 그 파일에 이미 있다. `import team_rules as TR` 와 `import repo_defaults` 를 그 파일 머리의 import 에 더한다. `REPO` 는 `PLUGIN.parents[1]` 로 그 파일 머리에 더한다.) U1 가 가 아니면 `TS.UNCOUNTED_SHAPE` 를 그 목록에서 뺀다.

판 쪽 — T-d 는 Step 4 에서 함께 고친다. 이 계획의 CHANGELOG 항목을 글로 고르는 테스트 하나를 `ReadSideVersion` 옆에 둔다:

```python
RULE_WORDS = ("team_rules.py", "start_bundle.py", "묶음 낡음", "REVIEW.md")


class RulesVersion(unittest.TestCase):   # 판 글자를 못 박지 않는다 — 읽기 쪽 항목보다 뒤의 판 가운데 가장 이른 것
    def test_entry_chosen_by_its_words(self):
        log = (PLUGIN / "CHANGELOG.md").read_text(encoding="utf-8")
        entries = changelog_entries(log)
        read_side = min(v for v, body in entries if all(w in body for w in READ_WORDS))
        mine = sorted(v for v, body in entries if v > read_side and all(w in body for w in RULE_WORDS))
        self.assertTrue(mine, "읽기 쪽 판 뒤에 RULE_WORDS 를 모두 담은 항목이 없다")
        body = dict(entries)[mine[0]]
        self.assertFalse(all(w in body for w in ("--layout team", "rules_budget", "handbook_budget", "job new", "종료 코드 4")))
        self.assertIn("이미 깐", body)   # 리더 틀이 바뀐 것을 이미 깐 레포가 손으로 맞춘다(U10 가 일 때)
```

(`changelog_entries` 가 내는 꼴은 그 파일의 `pick_entry` 가 쓰는 대로다 — `(판 tuple, 절 글)`.) 변이(사본에서): 문서 §9 에서 「리더는 그 출력을 읽지 않는다」 를 지운다 → 빨강 · CHANGELOG 항목에 `--layout team` 과 `종료 코드 4` 를 적는다 → `RulesVersion` 과 있는 `Version` 테스트 빨강 · §1 표의 「§15」 를 지운다 → 양의 짝 빨강.

- [ ] **Step 2: 실패를 확인한다** — Run: `python3 -m unittest plugins/spec-distill/tests/test_team_docs.py`. Expected: 새 · 바꾼 테스트만 실패.

- [ ] **Step 3: 문서 · README 를 쓴다** — README 는 Principles Instantiated 에 두 줄(「Law 3 — 규칙은 쌓이기만 하지 않는다」: 바이트 예산 · 반증 삭제 · 반례 확인 뒤 승격 · `scripts/team_rules.py check` / 「Law 1 — 일꾼에게 닿는 길은 시작 묶음 하나」: 커밋을 못 박은 글 · `scripts/start_bundle.py` · 「묶음 낡음」)과, 명령 목록에 두 스크립트의 한 줄씩, team 단계 문단에 「묶음 낡음」 을 더한다. Hooks · Prerequisites 는 바뀌지 않는다(새 의존 없음).

- [ ] **Step 4: 판 글자 넷을 한 번에 고친다** — Task 1 이 적은 목표 판 `X.Y.Z`(기본 `8.18.0`)로: ① `plugin.json` 의 `version` ② `CHANGELOG.md` 맨 위에 `## [X.Y.Z] — <오늘 날짜>` 절(Added: 규칙 검사 · 승격 후보 · 시작 묶음 · 「묶음 낡음」 · 문서 네 절 / Changed: 리더 역할 문서 틀의 한 줄 — 「이미 깐 레포는 이 줄을 손으로 더한다」 · 진행 줄의 전체 · `job sync` 의 묶은 커밋 · 얕은 클론 가드와 그 종료 코드 · 결과 파일 이름 꼴 알림 · 과제 머리의 로드맵 경로. `--layout team` 과 `종료 코드 4` 글자는 쓰지 않는다) ③ `tests/test_team_docs.py` 의 `FLOOR = (X, Y, Z)` ④ 같은 파일 `test_logic_has_teeth` 의 `below = version_problems("<지금 기본 브랜치에 있는 가장 높은 판>", log)`(기본 `"8.17.0"`). PR 을 열 때 기본 브랜치의 판이 그 사이 올랐으면 이 넷만 다시 고친다 — 다른 자리에 판 글자를 두지 않는다(`git grep -n -F "X.Y.Z" -- plugins/spec-distill shared` 가 이 넷과 CHANGELOG 뿐인지 본다).

- [ ] **Step 5: 통과와 문서 락을 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_docs.py plugins/spec-distill/tests/test_review_hook_removed.py` · `for t in test_readme_sync test_repo_literals test_stale_terms; do bash plugins/spec-distill/tests/$t.sh | tail -n 1; done` · `bash shared/tests/test_changelog_integrity.sh | tail -n 1`
Expected: 통과

- [ ] **Step 6: 커밋** — `docs(spec-distill): 형식 정본 문서의 규칙 · 검수 기준 · 시작 묶음 · 브랜치 사이 흐름` 과 `chore(spec-distill): 판 X.Y.Z` 둘로.

---

### Task 12: 끝에서 끝 · 옛 형식 대조 · 변이 (설계 Verification Plan · AC13 · AC25 의 「그대로 읽힌다」)

**Files:**
- Test: `plugins/spec-distill/tests/test_start_bundle.sh`(끝에서 끝 묶음)
- 그 밖에 고치지 않는다(대조 · 변이의 스크립트와 출력은 리더가 준 임시 폴더에 둔다).

- [ ] **Step 1: 끝에서 끝을 한 흐름으로 잰다** (계획이 정한 테스트 — 라벨 머리 「끝에서 끝:」)

새 임시 레포에서(같은 파일 안의 둘째 `team_repo` — `T` 를 새 폴더로 바꿔 부른다): `create --layout team`(픽스처) → 공통 문서 올리기 → `job new`(단순 작업, 그 브랜치에서 커밋 · push) → `start_bundle.py --job <그 과제> --stage implement` → 출력의 `맞추는 명령:` 줄에서 `roadmap_write.py` 뒤를 떼어 `python3 "$RW"` 로 그대로 실행(U8 이 나 면 첫 줄의 두 커밋을 떼어 인자를 짓는다) → 결과 파일에 `산출물: <고친 파일>` 줄을 더하고 `job sync --end <커밋>` → 커밋 · push → `job_results.py check` 가 `0` 이고 받음 줄을 낸다 → 그 줄을 `decide` 로 INTENT.md 에 적어 커밋 · push → 단계 계산에서 그 과제가 「결과 받음」 이다. 단언: 각 걸음의 종료 코드, 결과 파일 머리의 `bundle_at` · `job_at` 이 묶음 첫 줄의 두 커밋과 같다, 마지막 단계 글자. 이어서 AC24 — 같은 결과 파일의 `bundle_at` 을 이 레포에 없는 커밋으로 바꿔 올리면 `job_results.py check` 가 `1` 이고 사유에 `bundle_at` 이 있다(계획 2 가 구현한 것을 여기서 묶음과 이어 못 박는다).

- [ ] **Step 2: 옛 형식 대조** — `BASE`(Task 1)의 스크립트를 `git archive` 로 임시 폴더에 풀고(`plugin.json` 의 판만 지금 것으로 맞춘다), 같은 입력(이 레포의 로드맵 폴더들 — Task 10 이 더한 역할 폴더와 공통 규칙 파일이 있는 지금 나무)에 `BASE` 스크립트와 지금 스크립트로 `roadmap_status.py <로드맵>` · `--json` · `control_plane.py show <로드맵>` · `show --tasks` · 경로 없는 `control_plane.py show` 와 묶음 짝마다의 `check_bundle_coverage.py`(글 · `--json`)를 돌려 출력과 종료 코드를 통째로 견준다(계획 2 Task 16 의 대조 스크립트와 같은 꼴 — 그 계획의 그 걸음을 읽고 따른다).
Expected: 「옛 형식 출력 같음」(호출 수 · 줄 수를 적는다) · `"layout"` 칸 0개. 다르면 고치지 않고 멈춰 보고한다. 로드맵 수가 `BASE` 의 나무에서 센 수와 같다(역할 폴더가 로드맵으로 세어지지 않는다).

- [ ] **Step 3: 변이를 사본에서 흔든다** — 그때까지의 일을 커밋한 뒤 `git archive HEAD` 로 푼 사본에서, 과제 2 · 3 · 4 · 5 · 6 · 7 · 8 · 10 · 11 의 「변이」 줄을 하나씩 넣어 그 과제의 테스트를 돌린다. 설계 Verification Plan 의 것 가운데 이 계획 몫 — 규칙 파일 예산(한 바이트 넘기기) · 조건 값(틀린 역할 · 단계 이름) · 작업 폴더의 사본 고치기(묶음이 바뀌지 않아야 한다) — 이 그 줄들에 들어 있는지 표로 확인한다. 변이마다 (넣은 것 · 빨개진 단언의 라벨 · 결과) 한 줄을 원장에 적는다. 변이 없는 사본에서 같은 테스트가 초록인지 먼저 본다(양성 대조). 살아남은 변이는 테스트를 조이고 다시 돈다. 지우기뿐 아니라 더하기 · 뒤집기 변이가 과제마다 하나 이상인지 본다.

- [ ] **Step 4: 락 묶음을 한 번 돈다**

Run:
```bash
export PYTHONDONTWRITEBYTECODE=1
python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_team_*.py'
python3 -m unittest plugins/spec-distill/tests/test_control_plane.py plugins/spec-distill/tests/test_conductor_ledger.py plugins/spec-distill/tests/test_repo_defaults.py plugins/spec-distill/tests/test_review_hook_removed.py plugins/quality-gates/tests/test_utf8_explicit.py
for t in test_team_rules test_start_bundle test_team_stale test_team_status test_team_tasks test_team_sync test_team_write test_team_coverage test_team_review_entry test_job_results test_roadmap_status test_bundle_coverage test_spec_review_bundle test_readme_sync test_repo_literals test_stale_terms test_check_brief; do bash plugins/spec-distill/tests/$t.sh | tail -n 1; done
for t in test_python_floor test_no_new_duplication test_changelog_integrity test_dispatch_disposition test_invocation_surface; do bash shared/tests/$t.sh | tail -n 1; done
git ls-files -s plugins/spec-distill/tests/test_team_rules.sh plugins/spec-distill/tests/test_start_bundle.sh plugins/spec-distill/tests/test_team_stale.sh
```
Expected: 모두 통과 · 새 셸 테스트 셋이 `100755`. (`test_merge_check.sh` 는 실제 codex 를 부를 수 있어 돌리지 않는다.)

- [ ] **Step 5: 커밋** — `test(spec-distill): 시작 묶음에서 결과 받음까지 끝에서 끝`

---

## 뒤 에픽에 넘기는 이음매

- `team_layout.leader_ref(default_ref)` — R3 가 이 함수의 값만 리더 상태 브랜치로 바꾼다. 부르는 곳은 `start_bundle.rules_block` 과 `team_status.Reader.stale` 둘이다. 두 커밋이 갈릴 때 결과 파일 머리에 칸을 더하는 것 · 묶음의 규칙 머리 줄 꼴(U18)은 R3 가 정한다.
- `start_bundle.py` — R2 가 지휘 절차의 보내는 글 틀을 이 명령 한 줄로 바꾼다. `읽을 것` 은 R2 의 단계표가 서면 그 표에서 온다(지금은 과제 폴더의 설계 · 계획 파일 전부). 단계의 기본 역할(`team_layout.default_role`)도 그 표가 정본이 된다.
- `team_rules.py` — 조건으로 골라 싣기를 켤 때(R2) `Rule.conds` 가 이미 풀려 있다. 규칙을 쓰는 명령은 없다(U10).
- 리더가 설계문서 `## 미룸` 표에 올릴 후보(이 계획이 하지 않는 것) — ① `branch_tip.tip` 이 조상 판정 실패와 갈라짐을 가르지 않으면 그 사실(Task 9 가 재서 보고한다) ② U1 이 가 일 때 쓰는 쪽(`job sync` · 결과 대조)은 여전히 두 꼴을 받는다는 것 ③ 검수 기준 파일이 바뀐 것을 도는 검수에 알리는 길이 없다는 것(U9 ① 가) ④ U13 이 가 일 때 계획의 task 절이 줄어 이미 적힌 번호가 새 전체보다 큰 줄이 남으면 「진행 줄 깨짐」 이 된다는 것.
- 리더에게 청하는 지휘 기록 한 줄 — 계획 2 의 결정이 AC14 의 글자를 좁힌 것(잔여 Minor 10).

## 마지막 전체 리뷰 (실행 방식 공통)

고른 실행 방식의 마지막 전체 리뷰에 설계문서 `## Acceptance Criteria` 의 AC 목록(AC1–AC31)을 싣고, 리뷰가 AC 마다 한 줄씩 `AC1: 구현됨 — 근거` 꼴(판정은 구현됨 · 미룸 · 빠짐 가운데 하나)로 보고하게 한다. 이 계획의 몫은 AC19 · AC20 · AC21 · AC22 · AC23 · AC24 · AC25 · AC31 과 AC26(계획 3 몫)이다. AC1–AC18 · AC27–AC30 은 앞 계획 둘이 구현했다 — 근거에 그 계획을 적는다.

리뷰에 함께 묻는 것:

- 끝에서 끝 — 묶음 첫 줄의 두 커밋이 `job sync` 의 머리로, 그 머리가 결과 대조와 「묶음 낡음」 으로 한 줄로 이어지는가(세 과제의 글자가 같은가). 각 명령의 종료 코드를 다음 걸음이 어떻게 읽는가(`start_bundle.py` 의 1 · 2 · 3 에서 표준 출력이 비는가 · `team_rules.py check` 의 1 과 3).
- 읽기 전용 — 새 스크립트 둘이 쓰지 않고, 묶음이 작업 폴더의 파일을 한 번도 읽지 않는가(과제 폴더 포함). 상태 계산이 새 로컬 모듈을 import 하지 않아 정적 락의 수와 코드 지문 목록이 그대로인가.
- 옛 형식 — Task 12 Step 2 의 대조가 「같음」 인가, 있는 테스트를 고친 곳이 T-a – T-d 뿐인가(고친 단언마다 기대값 · 목록 · 새 단언으로 갈라 표로). 옛 형식의 기대값이 하나라도 바뀌었으면 Important 다.
- 계획이 적어 준 테스트 코드 자체(계획이 정한 테스트) — 통과가 정답인 단언뿐이라 이빨이 없는 곳, 픽스처가 분기 하나를 통째로 가리는 곳. `## 코드 분기 × 픽스처` 의 줄마다 그 분기가 실제로 테스트에 닿는지 본다.
- 「설계에 없던 결정」 U1–U18 의 받은 답이 코드와 문서에 그대로 반영됐는가 — 답이 추천과 다른 행은 「다른 안이면」 이 지켜졌는가. 사용자가 답하지 않은 U 행을 구현이 스스로 정한 자리가 있으면 Important 다.
- 레포의 새 파일 — `REVIEW.md` 의 글이 사용자가 받아들인 글과 같은가, 역할 폴더가 로드맵으로 세어지지 않는가.

그 보고를 git 이 추적하지 않는 파일(리더가 준 임시 폴더)에 적는다. 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올리고(구현 담당자는 설계문서를 고치지 않는다 — 후보를 보고에 싣고 리더가 올린다), PR 을 만들기 전에

```bash
python3 <spec-distill>/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-14-team-file-contract-design.md <보고 파일> --acs "AC19,AC20,AC21,AC22,AC23,AC24,AC25,AC26,AC31"
```

를 돌려 경고를 사용자에게 보인다. 사람에게 쓰는 글은 첫 줄에 상태, 번호 · 해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 끝에 할 일(기본 하나 — 여럿이거나 병렬이면 밝힌다)을 둔다.
