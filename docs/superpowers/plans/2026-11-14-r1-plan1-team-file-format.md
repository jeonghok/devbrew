# 팀 파일 규약 · 계획 1 — 형식과 생성 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 로드맵 하나를 팀 폴더 하나로 만드는 새 형식(`layout: team`)의 경로 · 틀 · 생성기 · 원자료 사본 · 검사를 세운다 — 옛 형식의 출력은 바이트 하나 바꾸지 않는다.

**Architecture:** 경로와 이름은 잎 모듈 `team_layout.py` 한 곳에서 나오고, 과제 파일(INTENT.md · sources.md · original.md)의 글은 `team_files.py`, 나무 검사는 `team_check.py`, 생성기의 team 몸통은 `team_write.py` 가 맡는다. 있던 파일(`roadmap_write.py` · `roadmap_render.py` · `roadmap_model.py` · `repo_defaults.py` · `roadmap_status.py`)에는 형식 갈림 몇 줄만 둔다. 단계 계산은 이 계획에서 team 형식을 읽지 않는다 — 번호 대조까지만 하고 「검사 불가」 로 멈춘다(읽기는 계획 2).

**Tech Stack:** Python 3.9 문법 · 표준 라이브러리만(레포 스위트가 `python3` 3.9.6 으로 돈다), bash 3.2 호환 셸 테스트(`shared/tests/assert.sh`), git.

**Spec:** `docs/superpowers/specs/2026-11-14-team-file-contract-design.md`

이 계획은 설계 §14 의 셋 가운데 첫째다. 수용 기준은 AC1 · AC2 · AC3 · AC4 · AC5 · AC6 · AC7 · AC8 · AC18 과 AC26 의 계획 1 몫(형식 정본 문서 §1–§4 · §6, 판 올림, CHANGELOG, README, 스크립트 락)이다. 계획 2(읽기) · 계획 3(규칙과 시작 묶음)의 일은 하지 않고, 넘기는 이음매만 끝 절에 적는다.

## Global Constraints

- 브랜치: `feature/team-file-contract`(이미 있다). 커밋은 Conventional Commits, 설명은 한국어(예: `feat(spec-distill): team 형식 경로 모듈`). 구현 커밋마다 트레일러 `Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md`. `git add -- <경로>` 로 고친 파일만 올린다.
- 역할 이름(글자 그대로, 이 순서): `leader` · `designer` · `writer` · `worker`. 사용자에게 보이는 말은 「리더」다.
- 형식 표시: 로드맵 머리말 `layout: team`. 없으면 옛 형식이고 출력은 지금과 바이트가 같다.
- INTENT.md 머리 키(이 순서): `type: job` · `job` · `kind`(`epic` | `task`) · `roadmap` · `branch` · `paths`. 2단계 제목 넷(이 순서): `## 목표` · `## 지시 원문` · `## 하지 않을 것` · `## 결정 기록`.
- sources.md 머리 키: `type: job-sources` · `job` · `ids: […]`. 사용자 원문 절은 싣지 않는다.
- 설정 키 둘: `rules_budget`(기본 8192) · `handbook_budget`(기본 16384). 단위는 UTF-8 바이트, 레포 층에서만 받는다.
- 경로 조각(`jobs/` · `intent/` · `results/` · `RULES.md` · `HANDBOOK.md`)의 글자는 `team_layout.py` 에만 둔다. 다른 스크립트는 그 모듈을 부른다. `roadmaps_dir` 은 해결자(`repo_defaults.resolve`)에서 읽는다.
- 대상 레포의 `.claude/` 아래에는 쓰지 않는다. 틀은 대상 자리에 없을 때만 깔고, 있는 파일은 바이트를 바꾸지 않는다.
- 역할 문서 틀에는 `## 할 일` · `## 하지 않을 일` 두 칸뿐이다. 「알림이고 막는 것은 도구 권한이다」 는 `references/team-files.md` 와 README 에만 쓴다.
- 새 스크립트: 파일을 열 때 `encoding="utf-8"`(바이트로 읽을 때는 `"rb"`), 인터프리터 이름 글자(`"python3"`)를 쓰지 않고 `sys.executable`, 모듈 수준 `re.compile` 에 `##` 로 시작하는 제목 패턴을 두지 않는다(제목은 문자열 비교로, brief §6 은 `section6.span` 으로). 비신뢰 입력의 꼴 검사는 `fullmatch`.
- 새 셸 테스트: `chmod +x` 뒤 `git ls-files -s <파일>` 이 `100755`. 한글 바로 앞의 변수는 `${v}`. 테스트는 `PYTHONDONTWRITEBYTECODE=1`. 픽스처 글은 `test_roadmap_write.sh` · `test_roadmap_status.sh` 와 다르게 쓴다(20줄 중복 락).
- 판: spec-distill `8.13.1` → `8.14.0`(새 surface — minor). CHANGELOG 머리 `## [8.14.0] — <커밋 날짜>`.
- 전체 스위트는 지휘자가 보낸 글의 공유 잠금 줄(`suite_lock.py run --lock <받은 경로> --owner <받은 이름> --wait <초> -- bash -c 'bash tools/suite/run-all.sh'`)로만 돌린다. 잠금을 못 잡으면 잠금 없이 돌리지 않고 주인 · 잡은 시각을 보고한다. 과제마다의 테스트는 그 파일만 돌린다.
- 지휘 세션이 같은 worktree 의 설계문서를 고칠 수 있다 — 설계문서를 되돌리거나 고치지 않는다.

## Review Focus

- **원자료 안의 제목 꼴 줄.** framing audit 의 `## 1. 원문` 절 안에 사용자가 붙인 `## …` 줄이 있어도(지금 audit 44행이 그렇다) 구간이 `## 2. 질문 전체` 앞까지다. 단순 작업의 받은 말에 `## 하지 않을 것` · `## 결정 기록` · `{{JOB}}` · `---` 줄이 있어도 네 칸이 갈리지 않고 지시 원문이 바이트 그대로다(Task 4 · Task 6 · Task 9).
- **커밋되지 않은 출처.** 출처 파일이 추적되지 않거나 작업 트리에서 고쳐진 채 `original` 을 부르면 옮기지 않고 「먼저 커밋한다」 로 멈춘다 — 조용히 커밋된 판을 옮기지 않는다(Task 6).
- **줄바꿈 꼴.** 출처가 CRLF 이거나 끝 줄바꿈이 없을 때, 받은 말(표준 입력)이 CRLF · 끝 줄바꿈 없음 · 빈 입력일 때(Task 6 · Task 9).
- **반쯤 있는 대상 자리.** 역할 문서가 넷 중 둘만 있을 때, 역할 폴더가 심볼릭 링크일 때, `roadmaps_dir` 이 `.claude/` 아래로 설정된 레포 — 있는 것은 바이트 그대로 두고 링크와 `.claude/` 는 쓰지 않고 멈춘다(Task 7).
- **깨진 범위.** 표의 지시 원문 범위가 뒤집혔거나(`57–23`) 0 으로 시작하거나 파일 길이 밖이거나 숫자가 아닐 때, 재분해로 `original.md` 가 길어진 뒤 옛 INTENT.md 의 범위가 그대로 맞는지(Task 4 · Task 7 · Task 8).

## 파일 구조

모두 `plugins/spec-distill/` 아래다.

| 파일 | 맡는 일 | 과제 |
|---|---|---|
| `scripts/team_layout.py` (새) | 형식 표시 · 역할 이름 · 파일 이름 · 경로 도출(잎 — 표준 라이브러리만 import), `check` 명령의 진입 | 2 · 6 |
| `scripts/team_files.py` (새) | INTENT.md · sources.md · original.md 의 글 만들기와 읽기(파일 · git 을 만지지 않는다) | 4 · 6 |
| `scripts/team_check.py` (새) | team 나무의 구조 검사 · 줄 범위 · 출처 대조 · 덧붙이기 검사 | 6 |
| `scripts/team_write.py` (새) | 생성기의 team 몸통 — 만들 파일 모으기 · `original` · `job new` | 6 · 7 · 8 · 9 |
| `templates/team/` (새) | `role-leader.md` · `role-designer.md` · `role-writer.md` · `role-worker.md` · `HANDBOOK.md` · `RULES.md` · `INTENT.md` | 4 |
| `references/team-files.md` (새) | 형식 정본 문서 — 이 계획은 §1–§4 · §6 | 10 |
| `scripts/repo_defaults.py` | 설정 키 둘 · 로드맵 머리말 `layout` 허용 | 3 |
| `scripts/roadmap_model.py` | 역할 이름 폴더 거절 · team 블록의 `묶음:` 값 · 번호 파일 머리 확인 | 2 · 5 |
| `scripts/roadmap_render.py` | 표의 「지시 원문 범위」 칸 · team 블록 · `bundle_parts` · team `extract` | 5 |
| `scripts/roadmap_status.py` | 형식 표시 읽기 — 모르는 값과 team 에서 멈춤 | 5 |
| `scripts/roadmap_write.py` | `--layout` · `original` · `job new` 진입, `update` · `extract` 의 형식 갈림, 종료 코드 4 | 6–9 |
| `references/roadmap-ontology.md` | 레포 설정 행에 키 둘(한 줄) | 3 |
| `README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json` | 설정 표 · team 형식 절 · Principles · 판 | 3 · 10 |
| `tests/test_team_layout.py` · `test_team_files.py` · `test_team_docs.py` · `test_team_write.sh` · `test_team_status_stub.sh` (새) | 아래 과제마다 | 2–10 |
| `tests/test_repo_defaults.py` · `test_roadmap_model.py` · `test_roadmap_render.py` · `test_roadmap_write.sh` | 있는 파일에 테스트 더하기(있는 단언은 고치지 않는다) | 2 · 3 · 5 · 7 |

테스트 코드의 별칭 — `L` = `team_layout` · `F` = `team_files` · `M` = `roadmap_model` · `R` = `roadmap_render` · `rd` = `repo_defaults`. `SCRIPTS` · `PLUGIN` · `REPO` 는 그 테스트 파일에서 `Path(__file__)` 로 얻은 스크립트 폴더 · 플러그인 폴더 · 레포 루트다. 셸 테스트의 `S` 는 스크립트 폴더, `SD` 는 플러그인 폴더, `RW` · `RS` 는 `roadmap_write.py` · `roadmap_status.py`, `W` 는 임시 레포, `T` 는 임시 폴더, `g` 는 그 레포의 git 이다(`test_roadmap_write.sh` 머리와 같은 꼴).

## AC 대응

| AC | 과제 | 재는 것 |
|---|---|---|
| AC1 | 2 | 경로 도출 · 다른 스크립트에 조각 글자 없음(양성 대조 포함) |
| AC2 | 3 | 키 둘 · README 행 · 로드맵 머리말에서 무시하고 알림 · `layout` 허용 |
| AC3 | 5 · 7 | 한 거래 · 구조 검사 통과 · 옛 출력 다이제스트 같음 |
| AC4 | 4 · 6 | 범위만 적음 · 범위 검사 1 · 덧붙이기 검사 · task 는 대상 아님 |
| AC5 | 6 | 구간 바이트 같음 · 구간 첫 줄 출처 · 파일 머리에 출처 없음 |
| AC6 | 5 · 8 | INTENT.md 그대로 · 손 고침 알림과 종료 코드 4 · sources.md 다시 씀 · 표 왕복 |
| AC7 | 9 | task INTENT.md · 바이트 같음 · 이름 거절 |
| AC8 | 2 · 7 | 역할 이름 폴더 거절 · 로드맵 수와 옛 출력 그대로 |
| AC18 | 4 · 7 | 틀 꼴 · 없을 때만 · `.claude/` 안 씀 |
| AC26 | 10 | 형식 정본 문서 절 · README · CHANGELOG · 판 · 스크립트 락 |

## 설계에 없던 결정

설계문서 `### Deferred to plan` 의 9 · 10 · 13 · 14 번과, 계획을 쓰며 설계가 비워 둔 것을 여기서 정했다. 지휘 세션이 사용자에게 묻는다 — 답이 바뀌면 해당 과제만 고친다.

| # | 결정 | 고른 이유 | 다른 길 |
|---|---|---|---|
| P1 (9번) | 재분해(`update`)가 목표 · 범위 · 지시 원문 범위가 바뀐 과제를 만나면 쓰기를 다 끝낸 뒤(로드맵 · 새 과제 폴더 · `sources.md`) 고칠 내용을 화면에 내고 **종료 코드 4**(새 코드 — 「썼다, 사람이 고칠 것이 남았다」)로 끝난다. 고칠 INTENT.md 는 과제 브랜치가 있으면 일꾼이 돌아온 뒤 그 브랜치의 것, 없으면 재분해 브랜치의 것이라고 그 글이 말한다. 생성기는 INTENT.md 를 읽어 견주지 않고 옛 블록과 새 표를 견준다. 사라진 에픽의 과제 폴더는 지우지 않고 알린다 | 리뷰 4라운드 지적(620f825b)이 권한 길이다. 쓰기를 막으면 새 과제와 번호 파일까지 묶인다. 결정 기록이 든 폴더를 스크립트가 지우면 사람 기록이 사라진다 | 아무것도 쓰지 않고 1(실패)로 끝낸다 · 사라진 에픽의 폴더를 지운다 |
| P2 (10번) | `original` 은 출처 파일이 커밋돼 있고 작업 트리가 그 커밋과 같을 때만 옮긴다. 구간 첫 줄은 `<!-- 출처: <경로>@<커밋 40자> · <절 이름> · <a>–<b>행 · <n>줄 -->` 이고 읽는 쪽은 줄 수만큼 건너뛴다(본문이 표지 줄을 흉내 내지 못한다). framing audit 는 상태 파일(`<brief 줄기>.state.md` 의 `seed:` → 그 seed 의 `audit_file`) → `--framing-audit` → 없으면 brief 쪽만 싣고 표지 줄 끝에 「framing audit 없음」. 다시 부르면 출처에서 **늘어난 꼬리만** 새 구간으로 붙이고, 출처의 앞부분이 바뀌었으면 그 절을 통째로 새 구간으로 붙이고 알린다. brief §6 이 audit §6 의 발화를 다 담고 있으면 audit 구간은 싣지 않는다. `create --layout team` 은 `original.md` 가 있으면 그대로 받아들여 검사만 하고, 없으면 같은 길로 만든다 | 커밋이 있어야 「출처와 바이트 같음」 을 출처 파일이 옮겨진 뒤에도 다시 잴 수 있다. 꼬리만 붙여야 같은 발화가 두 번 실리지 않고 앞 줄이 밀리지 않는다 | 커밋 없이 작업 트리에서 옮기고 표지에 「커밋 없음」 · 다시 부를 때 절 전체를 매번 다시 붙인다 |
| P3 (10번) | 원자료의 세 검사(줄 범위 · 덧붙이기만 · 출처와 바이트 같음)는 `team_layout.py check --roadmap <로드맵>` 하나에 구조 검사와 함께 있다. 생성기 명령(`original` · `create` · `update` · `job new`)이 쓴 직후 같은 함수를 돌려 실패하면 되돌린다. 덧붙이기 검사는 기본 브랜치(`origin/HEAD`) 판의 `original.md` 가 지금 파일의 앞머리인지를 본다(`--base <ref>` 로 바꾼다) — 기본 브랜치에 그 파일이 없으면 견줄 것이 없다 | 정본이 기본 브랜치이므로 「앞 줄을 바꿨나」 의 기준도 그 판이다. 검사가 한 명령이면 계획 2 의 읽는 쪽이 같은 함수를 부른다 | 덧붙이기 검사를 merge-base 와 견준다 · 검사마다 명령을 따로 둔다 |
| P4 (13번) | 「브랜치 하나에 계획 하나」 를 못 박는다 — 형식 정본 문서 §2 에 적고, 구조 검사가 `plan-<n>.md` 의 n 이 그 과제의 브랜치 수(단순 작업은 1)를 넘으면 오류로 낸다 | 설계 §10 이 이미 「n 번째 브랜치가 `plan-<n>.md`」 라고 한다 | 문서에만 적고 검사하지 않는다 |
| P5 (14번) | 이 계획만 머지된 동안 단계 계산(`roadmap_status.py`)은 `layout: team` 로드맵을 번호 대조(네 목록)까지만 하고 블록 단계를 「알 수 없음」, 사유 「이 판은 team 형식의 단계를 계산하지 않는다」, 종료 코드 3 으로 낸다. 모르는 `layout` 값은 「모르는 형식」 3 이다 — AC12 를 이 계획으로 당긴다 | `layout` 을 해결자가 받아들이는 순간(AC2) 지금 계산이 team 로드맵을 옛 형식으로 읽어 「계획 없음」 으로 센다 — 설계의 Anti-goal 이다 | 계획 2 까지 해결자가 `layout` 을 거절하게 두고 AC2 의 그 절을 계획 2 로 옮긴다 |
| P6 (14번) | 그 결과 team 형식의 `update` 는 이 계획에서 머지된 에픽을 가려 보호하지 못한다 — 「머지 여부를 확인하지 못했다」 를 알리고 진행한다. 계획 2 가 team 단계 계산을 넣으면 보호가 돌아오고 그 알림을 지운다 | AC6 가 이 계획의 기준이고, R2 가 새 형식을 켜기 전에는 team 로드맵이 실제로 돌지 않는다. 막지 못하는 것을 알린다 | team `update` 를 계획 2 까지 거절하고 AC6 의 `update` 몫을 계획 2 로 옮긴다 |
| P7 | team 로드맵 블록의 `- 묶음:` 값은 그 과제의 번호 파일을 가리킨다(`jobs/<번호>/sources.md` — 로드맵 폴더 기준). 블록 문법과 종류 판정은 그대로다 | 번호를 읽는 길(`로드맵 폴더 + 묶음 값`)이 옛 형식과 같아 읽는 쪽 고침이 가장 작다 | team 에서는 `묶음` 칸을 없앤다 · 옛 값(`<번호>.md`)을 그대로 둔다(없는 파일을 가리킨다) |
| P8 | team 분해안 표는 옛 칸 뒤 맨 끝에 「지시 원문 범위」 한 칸을 둔다(값 `23–57 · 75–87`, 입력은 `-` 도 받는다). 「묶음」 행은 범위가 하나 이상이어야 하고 「결정」 행은 「없음」 이며 과제 폴더를 만들지 않는다. 「브랜치 <설계문서 경로>」 행은 team 에서 받지 않는다 | 결정 블록은 일꾼이 없다. team 에서 설계문서 자리는 과제 폴더로 정해져 있어 경로를 따로 적는 종류가 뜻을 잃는다 | 결정 블록에도 과제 폴더를 만든다 · 브랜치 종류를 받아 그 설계문서를 `design.md` 로 옮긴다(R5 의 일) |
| P9 | 에픽 INTENT.md 의 글 — 「목표」 는 블록의 의도와 범위의 「한다」, 「하지 않을 것」 은 범위의 「안 한다」 다. 지시 원문 칸 첫 줄(「전체 그림에서 이 과제의 자리」)은 생성기가 쓰는 틀 문장이고 로드맵을 가리킨다 — 다른 과제의 범위를 베껴 적지 않는다 | INTENT.md 는 다시 쓰지 않으므로 다른 과제의 범위를 베끼면 재분해 뒤 낡는다 | 표에 「자리」 문장 칸을 하나 더 두어 사람이 쓴다 · 만들 때의 다른 과제 범위를 적는다 |
| P10 | `job new` 는 설계의 인자에 `--goal <한 줄>`(필수) · `--not <한 줄>`(여러 번, 없으면 「없음」)을 더한다. 파일만 쓴다 — 브랜치를 만들고 첫 커밋으로 두는 일은 부르는 쪽(리더 절차, R2)이다 | 네 칸 가운데 목표 · 하지 않을 것을 채울 입력이 설계의 인자에 없다. 생성기는 지금도 git 을 쓰지 않는다 | 두 칸을 비워 두고 리더가 손으로 채운다 · `job new` 가 브랜치와 커밋까지 한다 |
| P11 | 로드맵 찾기의 기준은 지금 것(로드맵 폴더 바로 아래 폴더의 `.md` + 머리말 `type: roadmap`)을 그대로 두고 역할 이름 폴더 거절만 더한다. 파일 이름을 `roadmap.md` 로 좁히지 않는다 | 있는 테스트(`test_any_md_name_in_folder_is_roadmap`)가 지금 기준을 못 박고 있고, 좁히면 다른 레포의 옛 로드맵이 사라진다 | AC8 의 글자대로 `roadmap.md` 만 센다(그 테스트를 고친다) |
| P12 | 설계의 새 파일 목록에 없는 모듈 셋(`team_files.py` · `team_check.py` · `team_write.py`)을 더하고, 역할 문서 틀의 파일 이름을 `role-<역할>.md` 로 둔다. 예약 밖 파일 `references/roadmap-ontology.md` 의 레포 설정 행에 키 둘을 더한다(한 줄) | 생성기 파일에 다섯 책임을 얹지 않는다. 플러그인 안에 `CLAUDE.md` 라는 이름의 파일을 두면 그 폴더를 읽는 세션에 저절로 실린다. 닫힌 키 목록이 낡는다 | 모두 `roadmap_write.py` · `team_layout.py` 에 넣는다 · 틀을 `<역할>/CLAUDE.md` 로 둔다 |
| P13 | `create --layout team` 을 다시 돌릴 때 — 자기 파일(로드맵 · INTENT.md · sources.md)은 지금처럼 생성 기록에 있으면 다시 쓰되, 결정 기록 줄이 하나라도 있는 INTENT.md 가 있으면 쓰지 않고 「`update` 를 쓴다」 로 멈춘다. 표에서 빠진 과제 폴더가 남아 있으면 지우지 않고 멈춘다. RULES.md · `original.md` · 역할 문서 · HANDBOOK.md 는 있으면 건드리지 않는다 | 사람이 쓴 줄을 덮지 않는다. 폴더 지우기를 되돌리는 장치를 새로 만들지 않는다 | 다시 돌릴 때 빠진 과제 폴더를 지운다 |
| P14 | 예산 키의 값이 1 이상의 정수가 아니면 기본값으로 세고 알린다(`parallel_default` 와 같다) | 있는 키와 같은 규칙이다 | 오류로 멈춘다 |

## 계획 2 · 3 에 넘기는 이음매

- `team_layout` — `LAYOUT_TEAM` · `LAYOUTS` · `ROLES` · `layout_of(meta)` · `Team` · `team_from_roadmap` · `handbook` · `role_doc` · `STAGE_PENDING`. 단계 이름 집합(§5)과 「리더가 쓰는 파일을 읽을 ref」 함수(§15 · AC31)는 여기 없다 — 계획 2 · 3 이 이 모듈에 더한다. 결과 파일 이름(`results/<단계>…`)도 계획 2 가 `Team.results(job)` 위에 더한다.
- `team_files` — `intent_sections` · `intent_ranges` · `intent_drift`(목표 · 하지 않을 것이 블록과 다른지 — AC28 의 견줌을 계획 2 의 단계 계산이 부른다) · `parse_original` · `sources_interface`. 결정 기록에 줄을 덧붙이는 함수는 없다(계획 2 의 `conductor_ledger`).
- `team_check.check_tree(top, team, base)` — (오류, 검사 불가, 알림) 셋을 돌려준다. 시작 묶음 · 단계 계산이 같은 함수를 부를 수 있다.
- `roadmap_model.collect_assigned` · `parse_roadmap` 은 team 로드맵을 읽는다(번호 파일 머리 확인 포함). `roadmap_status.build` 의 team 갈림(P5)은 계획 2 가 실제 계산으로 바꾸고, `roadmap_write.stages` 의 team 허용(P6)과 그 알림을 지운다 — 이 계획의 테스트 「team update: 머지 여부 알림」 이 그때 뒤집혀야 한다.
- `check_bundle_coverage.py` · `spec_review_bundle.py` · `conductor_ledger.py` · `control_plane.py` 는 이 계획에서 고치지 않는다. 해결자가 `layout` 을 받아들이므로 이 넷은 team 로드맵을 옛 형식처럼 읽는다 — 계획 2 가 형식을 가르게 한다.
- 틀 — RULES.md 는 제목 한 줄(`# RULES`), HANDBOOK.md 는 제목과 머리말 인용 한 줄이다. 규칙 줄은 `- [` 로 시작하는 줄이다(계획 3 의 `team_rules.py` 가 그 밖의 줄을 규칙으로 세지 않는다). AC28 의 「옮겨 싣지 말고 커밋과 경로로 가리킨다」 문장은 계획 2 가 worker · writer 틀과 형식 정본 문서 §5 에 더한다.
- `roadmap_status --json` 의 `settings` 칸에 키 둘이 더해진다(더하기뿐 — 사람이 보는 출력은 같다).
- 경로 예약에 더할 새 파일: `scripts/team_layout.py` · `team_files.py` · `team_check.py` · `team_write.py` · `templates/team/` · `references/team-files.md`. 예약 밖으로 고치는 파일: `scripts/repo_defaults.py`(설계가 이미 알림) · `references/roadmap-ontology.md`(P12).

---

### Task 1: 다시 확인 — 설계가 근거로 든 자리가 지금도 그런가

**Files:** 고치지 않는다.

**Interfaces:**
- Produces: 「달라진 것 없음」 또는 달라진 자리 목록. 달라졌으면 Task 2 로 가지 않고 멈춰 보고한다.

- [ ] **Step 1: 기준 커밋을 견준다**

Run: `git rev-parse origin/HEAD` 와 `git diff --stat 8b7ddf4d origin/HEAD -- plugins/spec-distill/scripts plugins/spec-distill/templates plugins/spec-distill/references`
Expected: 설계가 확인한 커밋(`8b7ddf4d`)과 같거나, 다르면 diff 에 아래 파일이 없다 — `repo_defaults.py` · `roadmap_model.py` · `roadmap_render.py` · `roadmap_write.py` · `roadmap_status.py` · `roadmap-template.md`. 있으면 그 diff 를 읽고 멈춰 보고한다.

- [ ] **Step 2: 이 계획이 기대는 줄을 확인한다**

아래 여덟을 `grep -n` 으로 본다. 하나라도 다르면 멈춰 보고한다.

| 자리 | 있어야 하는 것 |
|---|---|
| `scripts/repo_defaults.py` | `ROADMAP_META_KEYS = ("type", "source_brief")` · `merge_layers` 가 로드맵 층의 `shared_files` 를 빼고 경고한다 |
| `scripts/roadmap_model.py` | `def _roadmap_shape(path: str, roadmaps_dir: str)` · `BUNDLE_NAME_RE` · `def collect_assigned(blocks, meta, roadmap_rel, read, exists)` |
| `scripts/roadmap_render.py` | `COLUMNS` 가 열하나 · `def render_bundle(r, idx, roadmap_rel, brief_rel, audit_rel)` · `def extract_rows(roadmap_text, read_bundle)` |
| `scripts/roadmap_write.py` | `class Txn` · `def run_txn` · `def validate(top, roadmap)` · `def stages(top, roadmap)` · 종료 코드 0 · 1 · 2 |
| `scripts/roadmap_status.py` | `build()` 가 `parse_roadmap` → `resolve` → `collect_assigned` → 세 목록 → `compute` 순이다 |
| `tests/test_repo_defaults.py` | `self.assertEqual(len(rd.KEYS), 10)` |
| `tests/test_roadmap_model.py` | `test_any_md_name_in_folder_is_roadmap` |
| `scripts/*.py` 전체 | `grep -n 'jobs/\|intent/\|results/\|RULES\.md\|HANDBOOK\.md'` 가 0줄 |

- [ ] **Step 3: 판과 틀을 확인한다**

Run: `grep -n '"version"' plugins/spec-distill/.claude-plugin/plugin.json` · `ls plugins/spec-distill/templates`
Expected: `8.13.1` · `team` 폴더 없음. 판이 올라 있으면 Task 10 의 새 판을 그 다음 minor 로 읽는다.

커밋 없음.

---

### Task 2: `team_layout.py` — 이름과 경로 한 곳 (AC1 · AC8)

**Files:**
- Create: `plugins/spec-distill/scripts/team_layout.py`
- Modify: `plugins/spec-distill/scripts/roadmap_model.py`(`_roadmap_shape`)
- Test: `plugins/spec-distill/tests/test_team_layout.py`(새) · `plugins/spec-distill/tests/test_roadmap_model.py`

**Interfaces:**
- Produces(모두 `team_layout`):
  - 상수 — `LAYOUT_KEY = "layout"` · `LAYOUT_TEAM = "team"` · `LAYOUTS = (LAYOUT_TEAM,)` · `ROLES = ("leader", "designer", "writer", "worker")` · `ROADMAP_FILE = "roadmap.md"` · `RULES_FILE = "RULES.md"` · `HANDBOOK_FILE = "HANDBOOK.md"` · `ROLE_DOC = "CLAUDE.md"` · `REVIEW_FILE = "REVIEW.md"` · `STATUS_FILE = "STATUS.md"` · `INBOX_DIR = "inbox"` · `INTENT_DIR = "intent"` · `ORIGINAL_FILE = "original.md"` · `JOBS_DIR = "jobs"` · `INTENT_FILE = "INTENT.md"` · `SOURCES_FILE = "sources.md"` · `DESIGN_FILE = "design.md"` · `RESULTS_DIR = "results"` · `KEEP_FILE = ".gitkeep"` · `STAGE_PENDING = "이 판은 team 형식의 단계를 계산하지 않는다 — 번호 대조까지만 했다"`
  - `class UnknownLayout(ValueError)` — `.value` 에 머리말 값
  - `layout_of(meta: dict) -> str | None` — 키가 없으면 None, 따옴표를 벗긴 값이 `LAYOUTS` 에 있으면 그 값, 아니면(빈 값 포함) `UnknownLayout`
  - `team_name_problem(name: str) -> str | None` — 역할 이름이면 사유 한 줄
  - `job_name_problem(name: str) -> str | None` — 역할 이름 · `[A-Za-z0-9][A-Za-z0-9_-]*` 밖(`fullmatch`)이면 사유 한 줄
  - 팀 폴더 기준 경로 — `job_rel(job: str, *names: str) -> str`(`jobs/<job>[/…]`) · `sources_rel(job) -> str` · `intent_rel(job) -> str` · `original_rel() -> str`
  - 레포 기준 경로 — `handbook(roadmaps_dir: str) -> str` · `role_doc(roadmaps_dir: str, role: str) -> str`(역할이 아니면 ValueError)
  - `@dataclass(frozen=True) class Team(roadmaps_dir: str, name: str)` — 속성 `dir` · `roadmap` · `rules` · `original` · `status` · `inbox`, 메서드 `path(team_rel: str) -> str` · `job(job: str, *names: str) -> str` · `intent(job)` · `sources(job)` · `results(job)` · `keep(job)` · `design(job)` · `plan(job, n: int)`(`plan-<n>.md`, n < 1 이면 ValueError). 모두 레포 기준 posix 문자열이고 `roadmaps_dir` 은 `/` 로 끝난다
  - `team_from_roadmap(roadmaps_dir: str, roadmap_rel: str) -> Team` — `<roadmaps_dir><팀>/roadmap.md` 꼴이 아니거나 팀 이름이 역할 이름이면 ValueError
- `roadmap_model._roadmap_shape` 는 폴더 이름이 `team_layout.ROLES` 에 있으면 사유 `"역할 이름(%s)은 로드맵 폴더 이름으로 쓰지 않는다"` 를 돌려준다(모듈 맨 위에서 `import team_layout`).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_team_layout.py`(unittest, `sys.path` 에 `scripts` 를 넣는 꼴은 `test_roadmap_write.py` 와 같다):

```python
D = "docs/x/roadmaps/"

class Paths(unittest.TestCase):
    def test_team_paths(self):
        t = L.Team(D, "2026-a")
        self.assertEqual(t.dir, D + "2026-a")
        self.assertEqual(t.roadmap, D + "2026-a/roadmap.md")
        self.assertEqual(t.rules, D + "2026-a/RULES.md")
        self.assertEqual(t.original, D + "2026-a/intent/original.md")
        self.assertEqual((t.status, t.inbox), (D + "2026-a/STATUS.md", D + "2026-a/inbox"))
        self.assertEqual(t.intent("R3"), D + "2026-a/jobs/R3/INTENT.md")
        self.assertEqual(t.sources("R3"), D + "2026-a/jobs/R3/sources.md")
        self.assertEqual(t.keep("R3"), D + "2026-a/jobs/R3/results/.gitkeep")
        self.assertEqual(t.design("R3"), D + "2026-a/jobs/R3/design.md")
        self.assertEqual(t.plan("R3", 2), D + "2026-a/jobs/R3/plan-2.md")
        self.assertRaises(ValueError, t.plan, "R3", 0)

    def test_common_and_team_relative(self):
        self.assertEqual(L.handbook(D), D + "HANDBOOK.md")
        self.assertEqual(L.role_doc(D, "writer"), D + "writer/CLAUDE.md")
        self.assertRaises(ValueError, L.role_doc, D, "reviewer")
        self.assertEqual((L.sources_rel("R3"), L.intent_rel("R3"), L.original_rel()),
                         ("jobs/R3/sources.md", "jobs/R3/INTENT.md", "intent/original.md"))

    def test_team_from_roadmap(self):
        self.assertEqual(L.team_from_roadmap(D, D + "2026-a/roadmap.md"), L.Team(D, "2026-a"))
        for bad in (D + "2026-a/other.md", D + "a/b/roadmap.md", "elsewhere/2026-a/roadmap.md", D + "worker/roadmap.md"):
            self.assertRaises(ValueError, L.team_from_roadmap, D, bad)

class Names(unittest.TestCase):
    def test_roles_and_names(self):
        self.assertEqual(L.ROLES, ("leader", "designer", "writer", "worker"))
        for r in L.ROLES:
            self.assertTrue(L.team_name_problem(r)); self.assertTrue(L.job_name_problem(r))
        self.assertIsNone(L.team_name_problem("2026-11-14-x")); self.assertIsNone(L.job_name_problem("fix-typo_2"))
        for bad in ("", ".", "..", "a/b", ".hidden", "한글", "a b", "R1\n"):
            self.assertTrue(L.job_name_problem(bad), bad)

    def test_layout_of(self):
        self.assertIsNone(L.layout_of({"type": "roadmap"}))
        self.assertEqual(L.layout_of({"layout": '"team"'}), "team")
        for bad in ("", "Team", "teams", "old"):
            with self.assertRaises(L.UnknownLayout) as c:
                L.layout_of({"layout": bad})
            self.assertEqual(c.exception.value, bad)

class LiteralsLiveInOnePlace(unittest.TestCase):   # AC1
    def fragments(self):
        return [L.JOBS_DIR + "/", L.INTENT_DIR + "/", L.RESULTS_DIR + "/", L.RULES_FILE, L.HANDBOOK_FILE]

    def hits(self, text):
        return [f for f in self.fragments() if re.search(r"(?<![\w-])" + re.escape(f), text)]

    def test_no_other_script_spells_the_fragments(self):
        bad = {p.name: self.hits(p.read_text(encoding="utf-8")) for p in sorted(SCRIPTS.glob("*.py")) if p.name != "team_layout.py"}
        self.assertEqual({k: v for k, v in bad.items() if v}, {})
        self.assertGreater(len(list(SCRIPTS.glob("*.py"))), 40)   # 스캔이 비지 않았다

    def test_scan_has_teeth(self):   # 양성 · 음성 대조
        self.assertEqual(self.hits('p = "jobs/" + x'), ["jobs/"])
        self.assertEqual(self.hits("see RULES.md"), ["RULES.md"])
        self.assertEqual(self.hits("tool-results/x · reintent/"), [])
        self.assertEqual(len(self.fragments()), 5)
```

`test_roadmap_model.py` 에 더한다(그 파일의 `self.DIR` 을 쓴다):

```python
    def test_role_folders_are_not_roadmaps(self):   # R1 AC8
        text = "---\ntype: roadmap\nsource_brief: b.md\n---\n"
        for role in ("leader", "designer", "writer", "worker"):
            verdict, why = M.judge_roadmap(self.DIR + role + "/roadmap.md", lambda p: text, self.DIR)
            self.assertEqual(verdict, "not_roadmap"); self.assertIn("역할 이름", why)
        paths = [self.DIR + "HANDBOOK.md", self.DIR + "leader/CLAUDE.md", self.DIR + "x/roadmap.md"]
        entries = M.tree_entries(b"".join(("100644 blob 0\t%s\0" % p).encode("utf-8") for p in paths), self.DIR)
        self.assertEqual(sorted(entries), [self.DIR + "x/roadmap.md"])   # 역할 폴더의 글은 읽지도 않는다
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_layout.py plugins/spec-distill/tests/test_roadmap_model.py`
Expected: `ModuleNotFoundError: No module named 'team_layout'` 와 `test_role_folders_are_not_roadmaps` FAIL.

- [ ] **Step 3: `team_layout.py` 를 쓰고 `_roadmap_shape` 에 역할 이름 거절을 넣는다**

`team_layout.py` 는 표준 라이브러리만 import 한다(`roadmap_model` 이 이 모듈을 import 하므로 거꾸로 import 하면 돈다). 경로는 상수를 `/` 로 이어 만들고 글자를 다시 쓰지 않는다. `main()` 은 Task 6 에서 더한다.

- [ ] **Step 4: 통과를 확인한다**

Run: 위와 같은 명령 + `python3 -m unittest plugins/spec-distill/tests/test_roadmap_ontology.py`
Expected: 모두 OK(`test_any_md_name_in_folder_is_roadmap` 포함 — 있는 테스트는 고치지 않는다).

- [ ] **Step 5: 커밋**

```bash
git add -- plugins/spec-distill/scripts/team_layout.py plugins/spec-distill/scripts/roadmap_model.py plugins/spec-distill/tests/test_team_layout.py plugins/spec-distill/tests/test_roadmap_model.py
git commit -m "feat(spec-distill): team 형식의 이름 · 경로 모듈과 역할 이름 폴더 거절" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

---

### Task 3: 설정 키 둘과 `layout` 허용 (AC2)

**Files:**
- Modify: `plugins/spec-distill/scripts/repo_defaults.py` · `plugins/spec-distill/README.md`(`### 레포 설정 파일` 의 예시 블록 · 표 · 「키는 위 열뿐이다」 문단) · `plugins/spec-distill/references/roadmap-ontology.md`(레포 설정 행)
- Test: `plugins/spec-distill/tests/test_repo_defaults.py`

**Interfaces:**
- Produces: `repo_defaults.RULES_BUDGET = 8192` · `HANDBOOK_BUDGET = 16384` · `BUDGET_KEYS = ("rules_budget", "handbook_budget")`. `KEYS` 끝에 두 키(열둘). `resolve(...)["values"]["rules_budget"]` 는 int. `ROADMAP_META_KEYS = ("type", "source_brief", team_layout.LAYOUT_KEY)`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_repo_defaults.py` 의 `test_repo_layer_accepts_all_ten_keys_and_not_meta` 에서 `10` 을 `12` 로 고치고(이름은 `..._all_keys_...` 로), 아래를 더한다:

```python
class Budgets(unittest.TestCase):   # R1 AC2
    def test_defaults_and_repo_layer(self):
        m = rd.merge_layers(None, {}, LABEL, [])
        self.assertEqual((m["values"]["rules_budget"], m["values"]["handbook_budget"]), (8192, 16384))
        m = rd.merge_layers(None, {"rules_budget": "4096", "handbook_budget": '"20000"'}, LABEL, [])
        self.assertEqual((m["values"]["rules_budget"], m["values"]["handbook_budget"]), (4096, 20000))
        self.assertEqual((m["sources"]["rules_budget"], m["errors"]), (LABEL, []))

    def test_broken_value_falls_back_with_warning(self):
        for bad in ("0", "-1", "8k", "", "８１９２"):
            m = rd.merge_layers(None, {"rules_budget": bad}, LABEL, [])
            self.assertEqual(m["values"]["rules_budget"], 8192, bad)
            self.assertTrue(any("rules_budget" in w for w in m["warnings"]), bad)

    def test_roadmap_layer_ignores_and_warns(self):
        m = rd.merge_layers({"type": "roadmap", "rules_budget": "1", "handbook_budget": "1"}, {"rules_budget": "4096"}, LABEL, [],
                            roadmap_path="r/roadmap.md")
        self.assertEqual((m["values"]["rules_budget"], m["values"]["handbook_budget"], m["errors"]), (4096, 16384, []))
        self.assertEqual(len([w for w in m["warnings"] if "레포 설정 파일" in w and "budget" in w]), 2)

    def test_layout_is_roadmap_meta_not_setting(self):
        rd.check_layer({"type": "roadmap", "source_brief": "b.md", "layout": "team"}, "roadmap")
        rd.check_layer({"layout": "no-such"}, "roadmap")   # 값은 해결자가 판정하지 않는다
        with self.assertRaises(rd.SettingsError) as c:
            rd.check_layer({"layout": "team"}, "repo")
        self.assertEqual(c.exception.kind, "unknown_key")
        self.assertNotIn("layout", rd.KEYS)

class ReadmeTable(unittest.TestCase):
    def test_every_key_has_a_row(self):
        text = (REPO / "plugins/spec-distill/README.md").read_text(encoding="utf-8")
        for key in rd.KEYS:
            self.assertEqual(len([l for l in text.splitlines() if l.startswith("| `%s` |" % key)]), 1, key)
        for key in rd.BUDGET_KEYS:
            row = next(l for l in text.splitlines() if l.startswith("| `%s` |" % key))
            self.assertTrue(row.rstrip().endswith("| 무시하고 경고 |"), row)
```

(`REPO` 가 그 파일에 없으면 `Path(__file__).resolve().parents[3]` 로 둔다.)

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_repo_defaults.py`
Expected: `Budgets` 넷 · `ReadmeTable` · 고친 키 수 테스트 FAIL/ERROR.

- [ ] **Step 3: 해결자를 고친다**

`merge_layers` 에서 로드맵 층의 `shared_files` 를 빼고 경고하던 자리를 「레포 층에서만 읽는 키」(`("shared_files",) + BUDGET_KEYS`) 반복으로 넓힌다 — 경고 문장은 키 이름만 바뀐 같은 꼴(`<로드맵 자리>: <키> 는 레포 설정 파일(.devbrew.md)에서만 읽는다 — 이 값은 무시하고 레포 설정 값(없으면 기본값)을 쓴다`). `shared_files` 의 지금 경고 문장은 글자 그대로 둔다(있는 테스트가 못 박는다). 예산 값 읽기는 `parallel_default` 갈래와 같은 규칙(ASCII 숫자 · 1 이상, 아니면 기본값 + 출처 `기본값(머리말 값이 깨졌다)` + 경고)이다. `main()` 의 `get` 은 int 를 그대로 찍는다.

- [ ] **Step 4: README 와 온톨로지 행을 고친다**

README 예시 블록에 `rules_budget: 8192` · `handbook_budget: 16384` 두 줄, 표에 두 행:

```
| `rules_budget` | 팀 규칙 파일(RULES.md)의 바이트 예산(UTF-8) | 8192 | 무시하고 경고 |
| `handbook_budget` | 팀 간 공유 규칙 파일(HANDBOOK.md)의 바이트 예산(UTF-8) | 16384 | 무시하고 경고 |
```

「키는 위 열뿐이다」 문단의 「열」 을 「열둘」 로, 그 문단 끝에 「`rules_budget` · `handbook_budget` 이 1 이상의 정수가 아니면 기본값으로 세고 알리고, 로드맵 머리말에 적혔으면 그 값은 무시하고 알린다. 로드맵 머리말의 `layout` 은 설정이 아니라 형식 표시다(`references/team-files.md`).」 를 더한다. `roadmap-ontology.md` 레포 설정 행의 링크 칸 끝에 `` · `rules_budget` · `handbook_budget` `` 를, 속성 칸 끝에 「 · 규칙 파일 바이트 예산 둘」 을 더한다.

- [ ] **Step 5: 통과를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_repo_defaults.py plugins/spec-distill/tests/test_roadmap_ontology.py plugins/spec-distill/tests/test_parallel_recommend.py` · `bash plugins/spec-distill/tests/test_repo_defaults_git.sh` · `bash plugins/spec-distill/tests/test_roadmap_status.sh`
Expected: 모두 통과. `test_roadmap_status.sh` 가 `settings` 전체를 못 박은 줄에서 떨어지면 그 기대값에 두 키만 더하고, 그 밖의 있는 단언은 고치지 않는다.

- [ ] **Step 6: 커밋**

```bash
git add -- plugins/spec-distill/scripts/repo_defaults.py plugins/spec-distill/README.md plugins/spec-distill/references/roadmap-ontology.md plugins/spec-distill/tests/test_repo_defaults.py
git commit -m "feat(spec-distill): 규칙 파일 예산 키 둘과 로드맵 머리말 layout 허용" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

---

### Task 4: 틀과 과제 파일의 글 — `templates/team/` · `team_files.py` (AC4 · AC18)

**Files:**
- Create: `plugins/spec-distill/templates/team/{role-leader,role-designer,role-writer,role-worker,HANDBOOK,RULES,INTENT}.md` · `plugins/spec-distill/scripts/team_files.py`
- Test: `plugins/spec-distill/tests/test_team_files.py`(새)

**Interfaces:**
- Consumes: `team_layout`(Task 2) · `roadmap_model.frontmatter` · `section_body` · `FormatError`.
- Produces(모두 `team_files`, 파일과 git 을 만지지 않는다):
  - `TEMPLATES: Path`(`templates/team`) · `role_template(role: str) -> Path`(`role-<역할>.md`) · `SECTIONS = ("목표", "지시 원문", "하지 않을 것", "결정 기록")` · `KIND_EPIC = "epic"` · `KIND_TASK = "task"` · `FormatError`(`roadmap_model` 의 것을 그대로 내보낸다 — 새 예외 클래스를 만들지 않는다)
  - `parse_ranges(cell: str) -> list` — `"23–57 · 75–87"` → `[(23, 57), (75, 87)]`. 구분은 ` · `, 줄표는 `–` 와 `-` 를 받는다. ASCII 숫자가 아니거나 0 이거나 뒤집혔으면 ValueError(그 조각을 메시지에)
  - `format_ranges(ranges) -> str` — 늘 `–`, ` · ` 로 잇는다
  - `goal_text(intent: str, scope: str) -> str` — `"<의도>\n\n- 범위: <한다 쪽>"`(`roadmap_render.SCOPE_RE` 꼴이 아니면 범위 전체). `not_text(scope: str) -> str` — `"- <안 한다 쪽>"`, 그 꼴이 아니면 `"- 없음"`. `SCOPE_RE` 는 `roadmap_render` 를 import 하지 않고 같은 꼴을 문자열로 가른다(`" / 안 한다 "` 한 번 · `"한다 "` 로 시작)
  - `original_pointer(ranges, roadmap_rel: str) -> str` — 에픽의 지시 원문 칸 글. 아래 Step 3 의 문장 그대로
  - `render_intent(template: str, job: str, kind: str, roadmap_rel: str, goal: str, original: str, not_do: str, branch: str = "", paths=()) -> str`
  - `intent_sections(text: str) -> dict` — 네 칸의 본문. 읽는 규칙은 Step 3
  - `intent_ranges(text: str) -> list` — 지시 원문 칸의 `- 범위: intent/original.md …` 줄을 `[(a, b)]` 로. 줄이 없으면 `[]`
  - `intent_drift(text: str, intent: str, scope: str) -> list` — 목표 · 하지 않을 것 칸이 `goal_text` · `not_text` 와 다르면 칸 이름을 담은 한 줄씩
  - `render_sources(job: str, title: str, ids: list, parts: dict, receives: str, gives: str) -> str` — `parts` 의 키는 `"제약"` · `"열린 질문"` · `"웹 근거"` · `"기각 · 위험"`(값은 줄 목록, 비면 `- 없음`)
  - `sources_interface(text: str) -> tuple` — `(받는 것, 넘기는 것)`, 둘 다 없으면 FormatError

- [ ] **Step 1: 틀 일곱을 쓴다 (글자 그대로)**

`role-leader.md`:

```markdown
## 할 일

- 받은 명령으로 시작 묶음을 첫 걸음에 돌리고, 첫 줄의 두 커밋을 결과 파일 머리에 옮긴다.
- 받은 규칙은 쓰기 전에 지금도 맞는지 확인한다.
- 시작 묶음의 `<커밋>:<경로>` 는 작업 폴더의 파일이 아니라 `git show <커밋>:<경로>` 로 읽는다.
- 과제를 받으면 바로 시작하지 않고 방향을 사용자에게 먼저 보인다.
- 과제를 일꾼에게 배정한다.
- 결과 파일을 산출물과 대조한 뒤에만 받음 줄을 쓴다.
- 규칙을 쓰고, 반증됐거나 낡은 규칙은 지운다.

## 하지 않을 일

- 대조 없이 받음 줄 쓰기
- 일꾼의 결과 파일 고치기
```

나머지 셋은 앞의 세 줄(공통)이 같고 그 뒤가 다르다:

| 틀 | 공통 셋 뒤의 할 일 | 하지 않을 일 |
|---|---|---|
| `role-designer.md` | `- 원자료(`intent/original.md`) 전체를 읽고 설계문서의 원문 대조 표부터 채운다.` / `- 원자료와 다르게 바꾼 것은 근거를 적거나 「작성자 제안」으로 표시한다.` | `- 원자료를 풀어 다시 쓰기` / `- 승인 전에 다음 단계로 가기` |
| `role-writer.md` | `- 과제마다 INTENT.md 부터` / `- 고친 문서의 목차와 앵커를 맞춘다.` | `- 코드 고치기` / `- 다른 폴더 파일 고치기` |
| `role-worker.md` | `- 과제마다 INTENT.md 부터` / `- 설계안 승인 뒤에 코드` / `- task 하나를 끝낼 때마다 변환기를 돌려 결과 파일에 진행 줄과 판정 줄을 낸다.` / `- 결과 파일을 커밋하면 push 한다.` | `- 실서비스 배포` / `- 다른 폴더 파일 고치기` / `- 승인 전 코딩` |

`HANDBOOK.md`:

```markdown
# HANDBOOK

> 잘못 쌓인 맥락은 없는 것보다 나쁘다. 이 파일의 줄은 쓰기 전에 지금 확인하고, 틀렸으면 지운다.
```

`RULES.md` 는 `# RULES` 한 줄이다. `INTENT.md`:

```markdown
---
type: job
job: {{JOB}}
kind: {{KIND}}
roadmap: {{ROADMAP}}
branch: {{BRANCH}}
paths: [{{PATHS}}]
---

## 목표

{{GOAL}}

## 지시 원문

{{ORIGINAL}}

## 하지 않을 것

{{NOT}}

## 결정 기록
```

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`test_team_files.py`:

```python
class Templates(unittest.TestCase):   # AC18 — 두 칸뿐, 문서의 성격을 설명하는 문장이 없다
    COMMON = ["- 받은 명령으로 시작 묶음을 첫 걸음에 돌리고, 첫 줄의 두 커밋을 결과 파일 머리에 옮긴다.",
              "- 받은 규칙은 쓰기 전에 지금도 맞는지 확인한다.",
              "- 시작 묶음의 `<커밋>:<경로>` 는 작업 폴더의 파일이 아니라 `git show <커밋>:<경로>` 로 읽는다."]

    def test_role_templates_have_two_sections_only(self):
        self.assertEqual(sorted(p.name for p in F.TEMPLATES.glob("role-*.md")), sorted("role-%s.md" % r for r in L.ROLES))
        for role in L.ROLES:
            lines = F.role_template(role).read_text(encoding="utf-8").splitlines()
            self.assertEqual([l for l in lines if l.startswith("#")], ["## 할 일", "## 하지 않을 일"], role)
            self.assertEqual(lines[0], "## 할 일", role)
            self.assertEqual([l for l in lines if l and not l.startswith("#") and not l.startswith("- ")], [], role)
            self.assertEqual(lines[2:5], self.COMMON, role)
            for word in ("알림", "도구 권한", "집행", "이 문서"):
                self.assertNotIn(word, "\n".join(lines), (role, word))

    def test_worker_lines_are_the_users_words(self):
        text = F.role_template("worker").read_text(encoding="utf-8")
        for line in ("- 과제마다 INTENT.md 부터", "- 설계안 승인 뒤에 코드", "- 실서비스 배포", "- 다른 폴더 파일 고치기", "- 승인 전 코딩"):
            self.assertIn(line + "\n", text)

    def test_no_file_named_like_auto_loaded_memory(self):
        self.assertEqual([p.name for p in F.TEMPLATES.rglob(L.ROLE_DOC)], [])

    def test_rules_empty_and_handbook_principle(self):
        self.assertEqual((F.TEMPLATES / L.RULES_FILE).read_text(encoding="utf-8"), "# RULES\n")
        self.assertIn("> 잘못 쌓인 맥락은 없는 것보다 나쁘다. 이 파일의 줄은 쓰기 전에 지금 확인하고, 틀렸으면 지운다.\n",
                      (F.TEMPLATES / L.HANDBOOK_FILE).read_text(encoding="utf-8"))

class Ranges(unittest.TestCase):
    def test_round_trip_and_hyphen_input(self):
        self.assertEqual(F.parse_ranges("23–57 · 75–87"), [(23, 57), (75, 87)])
        self.assertEqual(F.format_ranges(F.parse_ranges("23-57 · 9-9")), "23–57 · 9–9")

    def test_rejects(self):
        for bad in ("", "없음", "57–23", "0–3", "3", "a–b", "２–３", "1–2,4–5", "1–2 · ", "1–2–3", "-1–2"):
            self.assertRaises(ValueError, F.parse_ranges, bad)

class Intent(unittest.TestCase):
    T = (F.TEMPLATES / L.INTENT_FILE).read_text(encoding="utf-8")

    def epic(self):
        return F.render_intent(self.T, "R3", F.KIND_EPIC, "d/t/roadmap.md", F.goal_text("의도 글", "한다 가 · 나 / 안 한다 다"),
                               F.original_pointer([(23, 57), (75, 87)], "d/t/roadmap.md"), F.not_text("한다 가 · 나 / 안 한다 다"))

    def test_epic_header_and_sections(self):
        text = self.epic()
        self.assertTrue(text.startswith("---\ntype: job\njob: R3\nkind: epic\nroadmap: d/t/roadmap.md\nbranch:\npaths: []\n---\n\n## 목표\n\n"))
        s = F.intent_sections(text)
        self.assertEqual(list(s), list(F.SECTIONS))
        self.assertEqual(s["목표"], "의도 글\n\n- 범위: 가 · 나")
        self.assertEqual(s["하지 않을 것"], "- 다")
        self.assertEqual(s["결정 기록"], "")
        self.assertIn("- 범위: intent/original.md 23–57행 · 75–87행", s["지시 원문"])
        self.assertTrue(s["지시 원문"].startswith("전체 그림에서 이 과제의 자리 — "))
        self.assertEqual(F.intent_ranges(text), [(23, 57), (75, 87)])
        self.assertTrue(text.endswith("## 결정 기록\n"))

    def test_scope_without_the_two_halves(self):
        self.assertEqual((F.goal_text("의도", "자유 범위"), F.not_text("자유 범위")), ("의도\n\n- 범위: 자유 범위", "- 없음"))

    def test_task_original_is_byte_exact_even_with_heading_lines(self):   # AC7 · Review Focus 1 · 3
        for said in ("한 줄", "줄 하나\n## 하지 않을 것\n## 결정 기록\n- 결정 · 2026-01-01 · 「가짜」\n", "{{JOB}} 과 {{NOT}}\n---\n",
                     "CRLF 줄\r\n둘째\r\n", "끝 빈 줄 둘\n\n\n", "## 목표\n## 지시 원문\n"):
            text = F.render_intent(self.T, "fix-x", F.KIND_TASK, "d/t/roadmap.md", "목표 한 줄", said, "- 없음",
                                   branch="fix/x", paths=("a/b.py", "c.md"))
            s = F.intent_sections(text)
            self.assertEqual(s["지시 원문"], said, repr(said))
            self.assertEqual((s["목표"], s["하지 않을 것"], s["결정 기록"]), ("목표 한 줄", "- 없음", ""), repr(said))
            self.assertIn("\nbranch: fix/x\npaths: [a/b.py, c.md]\n---\n", text)
            self.assertEqual(F.intent_ranges(text), [])

    def test_decision_lines_survive(self):
        text = self.epic() + "\n- spec 승인 · 2026-11-20 · 「이대로」\n"
        self.assertEqual(F.intent_sections(text)["결정 기록"], "- spec 승인 · 2026-11-20 · 「이대로」")

    def test_broken_shapes(self):
        text = self.epic()
        for broken in (text.replace("## 하지 않을 것\n", "", 1), text.replace("## 목표\n", "## 목 표\n", 1),
                       text.replace("## 지시 원문\n\n", "## 지시 원문\n", 1)):
            self.assertRaises(F.FormatError, F.intent_sections, broken)

    def test_drift(self):
        text = self.epic()
        self.assertEqual(F.intent_drift(text, "의도 글", "한다 가 · 나 / 안 한다 다"), [])
        self.assertEqual(len(F.intent_drift(text, "다른 의도", "한다 가 · 나 / 안 한다 라")), 2)

class Sources(unittest.TestCase):
    def test_render_and_read_back(self):
        text = F.render_sources("R3", "셋째 에픽", ["C1", "OQ2", "S4"], {"제약": ["- 🗣 confirmed **C1** — 가"], "열린 질문": ["- OQ2 [열림] — 나"],
                                                                      "웹 근거": [], "기각 · 위험": []}, "없음", "R4 에 x")
        self.assertTrue(text.startswith("---\ntype: job-sources\njob: R3\nids: [C1, OQ2, S4]\n---\n\n# R3 — 셋째 에픽 · 번호 항목\n\n## 제약\n\n"))
        self.assertEqual(M.bundle_ids(text), ["C1", "OQ2", "S4"])
        self.assertEqual(F.sources_interface(text), ("없음", "R4 에 x"))
        self.assertIn("## 웹 근거\n\n- 없음\n", text)
        self.assertNotIn("사용자 원문", text)
```

- [ ] **Step 3: 실패를 확인한 뒤 `team_files.py` 를 쓴다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_files.py` → `ModuleNotFoundError`.

정해 둔 것(테스트만으로 정해지지 않는 규칙):

- `render_intent` 는 자리표를 **한 번의 치환**(`re.sub` 에 함수)으로 채운다 — 채운 글 안의 `{{…}}` 를 다시 읽지 않는다. 모르는 자리표가 틀에 있으면 FormatError. 채운 뒤 머리말(닫는 `---` 까지)의 줄 끝 공백만 지운다. `paths` 는 `, ` 로 잇는다.
- `original_pointer` 의 글:

  ```
  전체 그림에서 이 과제의 자리 — 원자료 가운데 아래 줄 범위가 이 과제 몫이다. 나머지가 어느 과제로 갔는지는 로드맵(<roadmap_rel>)의 에픽 지도와 각 과제의 이 칸에 있다.

  - 범위: <team_layout.original_rel()> <a>–<b>행 · <c>–<d>행
  ```

- `intent_sections` 의 읽는 규칙 — 줄을 `\n` 으로만 나눈다. 머리말 뒤에서 `## 목표` 는 처음 나오는 줄, `## 지시 원문` 은 그 뒤 처음 나오는 줄, `## 결정 기록` 은 **마지막에** 나오는 줄, `## 하지 않을 것` 은 지시 원문 뒤 · 결정 기록 앞에서 **마지막에** 나오는 줄이다(받은 말 안에 같은 제목 줄이 있어도 칸이 갈리지 않는다). 칸 본문은 제목 줄 다음의 빈 줄 하나와 다음 제목 줄 앞의 빈 줄 하나를 뺀 사이의 글자 그대로다 — 그 두 빈 줄이 없으면 FormatError. 결정 기록 본문은 제목 뒤 글의 앞뒤 빈 줄을 뗀 것이다.
- `render_sources` 의 절 순서: `## 제약` · `## 열린 질문` · `## 웹 근거` · `## 기각 · 위험` · `## 인터페이스`(`- 받는 것: …` · `- 넘기는 것: …`). 절 사이는 빈 줄 하나.

- [ ] **Step 4: 통과를 확인하고 커밋한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_files.py plugins/spec-distill/tests/test_team_layout.py`
Expected: OK(`LiteralsLiveInOnePlace` 포함 — `team_files.py` 가 경로 조각을 글자로 쓰지 않았다).

```bash
git add -- plugins/spec-distill/templates/team plugins/spec-distill/scripts/team_files.py plugins/spec-distill/tests/test_team_files.py
git commit -m "feat(spec-distill): 팀 파일 틀 일곱과 과제 파일 글 모듈" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

---

### Task 5: 로드맵 글의 형식 갈림 — 블록 · 표 · 번호 파일 · 단계 계산 멈춤 (AC3 · AC6 과 AC12 당김)

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_model.py`(`parse_roadmap` · `_validate_block` · `collect_assigned`) · `roadmap_render.py` · `roadmap_status.py`(`build`)
- Test: `plugins/spec-distill/tests/test_roadmap_render.py` · `test_roadmap_model.py` · `test_roadmap_write.sh`(단언 하나 더하기) · `plugins/spec-distill/tests/test_team_status_stub.sh`(새, 실행 비트)

**Interfaces:**
- Consumes: `team_layout`(Task 2) · `team_files.parse_ranges` · `format_ranges` · `sources_interface` · `intent_ranges`(Task 4).
- Produces:
  - `roadmap_model.parse_roadmap(text)` — 머리말 `layout` 이 `team` 이면 묶음 블록의 `묶음` 값이 `team_layout.sources_rel(<번호>)` 여야 하고(아니면 오류 `"%s: team 형식의 묶음 값은 %s 다"`), 브랜치 블록(`묶음: 없음` + `spec`)은 오류 `"%s: team 형식에서는 브랜치 블록을 쓰지 않는다"` 다. 그 밖의 값(없음 · 모르는 값)은 지금 검사 그대로
  - `roadmap_model.collect_assigned(blocks, meta, roadmap_rel, read, exists)` — 시그니처 그대로. `meta` 의 형식이 team 이면 번호 파일 머리를 `type == "job-sources"` · `job == <번호>` 로 확인한다(오류 머리 `"%s 번호 파일 — …"`)
  - `roadmap_render.TEAM_COLUMN = "지시 원문 범위"` · `Row.ranges: list`(기본 빈 목록) · `parse_table(text: str, layout=None) -> list` · `format_table(rows: list, layout=None) -> str` · `render_block(r: Row, layout=None) -> str` · `bundle_parts(r: Row, idx: BriefIndex) -> tuple`(`(ids, {"제약": […], "열린 질문": […], "웹 근거": […], "기각 · 위험": […]})` — 찾지 못한 번호는 지금과 같은 `TableError`) · `extract_rows(roadmap_text, read_bundle)`(시그니처 그대로 — team 이면 `read_bundle(<묶음 값>)` 이 번호 파일, `read_bundle(team_layout.intent_rel(<번호>))` 이 INTENT.md)
  - `roadmap_status.build` — Step 5 의 두 갈림

- [ ] **Step 1: 옛 출력의 다이제스트를 먼저 못 박는다 (코드를 고치기 전)**

`test_roadmap_write.sh` 의 첫 `create` 성공 단언들(`create: 로드맵 하나 · 묶음 둘` 다음 줄)에 단언 하나를 더한다. 값은 이 과제의 어떤 코드도 고치기 전에 그 줄을 `echo` 로 한 번 찍어 얻는다 — 지금 뜨지 않으면 견줄 「변경 전」 이 사라진다.

```bash
digest() { (cd "$1" && find . -type f | LC_ALL=C sort | while IFS= read -r f; do printf '%s ' "$f"; shasum -a 256 < "$f"; done) | shasum -a 256 | cut -d' ' -f1; }
assert_eq "$(digest "$W/docs/rm")" "<지금 찍은 64자>" "R1 AC3: 옛 형식 create 의 나무가 변경 전과 바이트가 같다"
```

Run: `bash plugins/spec-distill/tests/test_roadmap_write.sh` → 통과(아직 아무것도 바꾸지 않았다). 이 단언은 Task 7 · 8 뒤에도 그대로 통과해야 한다.

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`test_roadmap_render.py` 에 더한다(그 파일의 표 · 색인 픽스처 도우미를 쓴다 — 표 머리는 `R.COLUMNS` 에서 만든다):

```python
TEAM_E = "| E1 | 첫 에픽 | 묶음 | 의도 | 한다 가 / 안 한다 나 | 없음 | feature/e1 | a/x.py | C1 · S1 | 없음 | 없음 | 3-9 · 12–12 |"
TEAM_P = "| P1 | 결정 | 결정 | 정한다 | 한다 결정 / 안 한다 코드 | 없음 | 없음 | 없음 | S2 · OQ1 | 없음 | 없음 | 없음 |"


def cut_last(row):   # 마지막 칸을 뗀 행(끝의 `|` 없이)
    return row.rsplit("|", 2)[0]


def team_table(*rows, cols=None):
    cols = cols or (R.COLUMNS + (R.TEAM_COLUMN,))
    return "## 분해안\n\n| " + " | ".join(cols) + " |\n|" + "---|" * len(cols) + "\n" + "\n".join(rows) + "\n"


class TeamTable(unittest.TestCase):   # R1 AC6
    def test_parse_and_round_trip(self):
        rows = R.parse_table(team_table(TEAM_E, TEAM_P), "team")
        self.assertEqual((rows[0].ranges, rows[1].ranges), ([(3, 9), (12, 12)], []))
        out = R.format_table(rows, "team")
        self.assertIn("| 3–9 · 12–12 |", out)
        self.assertEqual(R.parse_table(out, "team"), rows)

    def test_wide_table_keeps_team_column_last(self):
        cols = R.COLUMNS + R.EXTRA_COLUMNS + (R.TEAM_COLUMN,)
        rows = R.parse_table(team_table(cut_last(TEAM_E) + "| 큼 | 없음 | 없음 | 없음 | 없음 | 없음 | 3–9 |", cols=cols), "team")
        self.assertEqual((rows[0].extras, rows[0].ranges), ({"크기": "큼"}, [(3, 9)]))
        self.assertTrue(R.format_table(rows, "team").splitlines()[2].rstrip().endswith("| %s |" % R.TEAM_COLUMN))

    def test_rejects(self):
        for text, layout in ((team_table(TEAM_E), None),                                        # 옛 형식은 그 칸을 받지 않는다
                             (team_table(cut_last(TEAM_E) + "|", cols=R.COLUMNS), "team"),       # team 은 그 칸이 있어야 한다
                             (team_table(cut_last(TEAM_E) + "| 없음 |"), "team"),                # 묶음 행은 범위가 있어야 한다
                             (team_table(cut_last(TEAM_E) + "| 9–3 |"), "team"),
                             (team_table(cut_last(TEAM_P) + "| 1–2 |"), "team"),                 # 결정 행은 없음
                             (team_table(TEAM_E.replace("| 묶음 |", "| 브랜치 docs/x-design.md |")), "team")):
            self.assertRaises(R.TableError, R.parse_table, text, layout)

    def test_old_table_output_unchanged(self):
        text = team_table(cut_last(TEAM_E) + "|", cols=R.COLUMNS)
        self.assertEqual(R.format_table(R.parse_table(text)), text)


class TeamBlock(unittest.TestCase):
    def test_bundle_field_points_at_sources(self):
        row = R.parse_table(team_table(TEAM_E), "team")[0]
        self.assertIn("- 묶음: jobs/E1/sources.md\n", R.render_block(row, "team"))
        self.assertIn("- 묶음: E1.md\n", R.render_block(row))
```

`test_roadmap_model.py` 에 더한다:

```python
    def roadmap(self, bundle_value, layout="layout: team\n"):
        return ("---\ntype: roadmap\n%ssource_brief: b.md\n---\n\n## 에픽\n\n### E1 — 첫\n- 의도: 가\n- 범위: 나\n- 의존: 없음\n"
                "- 브랜치: feature/e1\n- 묶음: %s\n- 경로 예약: 없음\n\n## 재분해 이력\n\n### 2026-01-01 · 처음\n- 원문:\n  - 「가」\n" % (layout, bundle_value))

    def test_team_block_bundle_value(self):   # R1 P7
        self.assertEqual(M.parse_roadmap(self.roadmap("jobs/E1/sources.md"))[4], [])
        self.assertTrue(any("team 형식의 묶음 값" in e for e in M.parse_roadmap(self.roadmap("E1.md"))[4]))
        self.assertTrue(any("team 형식의 묶음 값" in e for e in M.parse_roadmap(self.roadmap("jobs/E2/sources.md"))[4]))
        self.assertEqual(M.parse_roadmap(self.roadmap("E1.md", layout=""))[4], [])            # 옛 형식은 그대로
        self.assertTrue(M.parse_roadmap(self.roadmap("jobs/E1/sources.md", layout=""))[4])    # 옛 형식에 team 값은 오류

    def test_collect_assigned_reads_job_sources(self):
        meta, blocks, _r, _k, errs = M.parse_roadmap(self.roadmap("jobs/E1/sources.md"))
        good = "---\ntype: job-sources\njob: E1\nids: [C1, S1]\n---\n"
        for text, want_err in ((good, False), (good.replace("job: E1", "job: E9"), True), (good.replace("job-sources", "epic-bundle"), True)):
            _b, union, errors = M.collect_assigned([dict(b) for b in blocks], meta, "r/t/roadmap.md",
                                                   lambda p: text if p == "r/t/jobs/E1/sources.md" else None, lambda p: True)
            self.assertEqual((bool(errors), union), (want_err, set() if want_err else {"C1", "S1"}))
```

`test_team_status_stub.sh`(실행 비트. 임시 레포 · origin · brief/audit 픽스처는 이 파일만의 글로 쓴다 — 번호는 `C1` · `D2` · `OQ1` · `S1` · `S2` 면 된다):

```bash
# 손으로 쓴 team 로드맵(`layout: team` · 묶음 블록 E1 · 번호 파일 jobs/E1/sources.md)을 작업 트리에 둔다
js() { python3 -c 'import json,sys; r=json.load(open(sys.argv[1], encoding="utf-8")); print(eval(sys.argv[2]))' "$1" "$2"; }
rc=0; (cd "$W" && python3 "$RS" --roadmap-file docs/rm/t1/roadmap.md --json) > "$T/team.json" 2>/dev/null || rc=$?
assert_eq "$rc" "3" "team 로드맵: 단계 계산은 검사 불가(3)로 멈춘다"
assert_contains "$(js "$T/team.json" "' | '.join(r['unknown_reasons'])")" "이 판은 team 형식의 단계를 계산하지 않는다" "team: 사유를 낸다"
assert_eq "$(js "$T/team.json" "[r[k] for k in ('format_errors','unassigned','orphans','unknown_ids')]")" "[[], [], [], []]" "team: 번호 네 목록은 센다"
assert_eq "$(js "$T/team.json" "sorted(set(b['stage'] for b in r['blocks']))")" "['알 수 없음']" "team: 블록 단계를 옛 계산으로 세지 않는다"
# 번호 하나를 번호 파일에서 빼면 unassigned 에 나온다(번호 대조가 실제로 그 파일을 읽는다)
# layout: no-such 로 바꾸면
assert_eq "$rc" "3" "모르는 layout: 검사 불가(3)"
assert_contains "$(js "$T/unk.json" "' | '.join(r['unknown_reasons'])")" "모르는 형식" "모르는 layout: 사유"
assert_eq "$(js "$T/unk.json" "r['unassigned']")" "None" "모르는 layout: 번호도 세지 않는다"
# layout 줄을 지우고 묶음 값을 E1.md 로 되돌린 옛 형식 로드맵은 rc 가 3 이 아니고 unknown_reasons 에 위 두 사유가 없다
```

- [ ] **Step 3: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_roadmap_render.py plugins/spec-distill/tests/test_roadmap_model.py` · `bash plugins/spec-distill/tests/test_team_status_stub.sh`
Expected: 새 테스트 FAIL(`TEAM_COLUMN` 없음 · team 값 오류 · rc 가 3 이 아님).

- [ ] **Step 4: `roadmap_model` · `roadmap_render` 를 고친다**

- `parse_roadmap` 은 `meta.get("layout")` 의 따옴표 벗긴 값이 `team_layout.LAYOUT_TEAM` 인지만 본다(모르는 값의 판정은 `roadmap_status` 몫이다 — 여기서 오류로 내지 않는다).
- `render_bundle` 의 번호 고르기(지금 `pick` · `keys` · `c_d` · `oq` · `rest`)를 `bundle_parts` 로 꺼내고 `render_bundle` 이 그것을 부른다 — 옛 묶음의 바이트는 그대로다(있는 `test_bundle` 이 잰다). 20줄 같은 블록이 두 파일에 생기지 않게 team 쪽은 이 함수를 부른다.
- 표: team 이면 머리가 `COLUMNS + (TEAM_COLUMN,)` 또는 `COLUMNS + EXTRA_COLUMNS + (TEAM_COLUMN,)` 여야 하고, 옛 형식이면 지금 두 머리만 받는다. 범위 칸의 ValueError 는 `TableError("%s: 지시 원문 범위 — %s")` 로 바꾼다.
- `extract_rows` 는 로드맵 머리말에서 형식을 읽는다. team 의 인터페이스는 `team_files.sources_interface`, 범위는 `team_files.intent_ranges` — INTENT.md 를 못 읽으면 `TableError("%s 의 INTENT.md 를 읽지 못했다: %s")`.

- [ ] **Step 5: `roadmap_status.build` 에 형식 갈림 둘을 넣는다**

`parse_roadmap` 바로 뒤, 형식 오류를 보고하기 **전에**: `team_layout.layout_of(meta)` 가 `UnknownLayout` 이면 `unknown_reasons` 에 `"모르는 형식 — 로드맵 머리말 layout: %s (아는 값: %s)"` 를 넣고 블록을 「알 수 없음」(사유 「모르는 형식」)으로 채워 돌려준다. 세 목록(`unassigned` · `orphans` · `unknown_ids`)을 채운 뒤 · `read_pr_cache` 앞에서: 형식이 team 이면 `unknown_reasons` 에 `team_layout.STAGE_PENDING` 을 넣고 블록을 「알 수 없음」(사유 같은 글, `ids` 는 배정 번호)으로 채워 돌려준다. 블록을 채우는 dict 는 지금 형식 오류 갈래(1136–1143행)의 것과 같으므로 작은 도우미 하나로 꺼내 세 곳이 부른다. `compute` 는 team 에서 부르지 않는다.

- [ ] **Step 6: 통과와 옛 형식 회귀를 확인한다**

Run: Step 3 의 명령 + `bash plugins/spec-distill/tests/test_roadmap_status.sh` · `bash plugins/spec-distill/tests/test_roadmap_write.sh` · `python3 -m unittest plugins/spec-distill/tests/test_roadmap_write.py plugins/spec-distill/tests/test_roadmap_migrate.py plugins/spec-distill/tests/test_control_plane.py`
Expected: 모두 통과 — 있는 테스트는 고치지 않는다.

- [ ] **Step 7: 커밋**

```bash
chmod +x plugins/spec-distill/tests/test_team_status_stub.sh
git add -- plugins/spec-distill/scripts/roadmap_model.py plugins/spec-distill/scripts/roadmap_render.py plugins/spec-distill/scripts/roadmap_status.py plugins/spec-distill/tests/test_roadmap_render.py plugins/spec-distill/tests/test_roadmap_model.py plugins/spec-distill/tests/test_roadmap_write.sh plugins/spec-distill/tests/test_team_status_stub.sh
git ls-files -s plugins/spec-distill/tests/test_team_status_stub.sh   # 100755
git commit -m "feat(spec-distill): 로드맵 블록 · 분해안 표의 team 갈림과 단계 계산 멈춤" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

---

### Task 6: 원자료 사본과 검사 — `original` · `team_check.py` · `team_layout.py check` (AC4 · AC5)

**Files:**
- Create: `plugins/spec-distill/scripts/team_check.py` · `plugins/spec-distill/scripts/team_write.py`
- Modify: `plugins/spec-distill/scripts/team_files.py`(original.md 의 글) · `team_layout.py`(`main`) · `roadmap_write.py`(`original` 진입)
- Test: `plugins/spec-distill/tests/test_team_files.py` · `plugins/spec-distill/tests/test_team_write.sh`(새, 실행 비트)

**Interfaces:**
- Consumes: Task 2 · 4 · 5.
- Produces:
  - `team_files.LABELS = ("원문", "질문 전체", "사용자 원문")` · `@dataclass class Section(source: str, commit: str, label: str, first: int, last: int, note: str, start: int, body: bytes)`(`start` 는 `original.md` 안에서 본문 첫 줄의 번호) · `marker_line(source, commit, label, first, last, note="") -> str` · `parse_original(data: bytes) -> list`(구간 밖의 줄 · 줄 수가 모자란 구간 · 범위와 줄 수가 어긋난 표지는 FormatError) · `line_count(data: bytes) -> int` · `extend_original(existing: bytes, wanted: list) -> tuple`(`wanted` 는 `(source, commit, label, first, lines: list[bytes], note)` 들, 반환 `(새 바이트, 알림 줄들)`)
  - `team_check.git_bytes(top, *args) -> tuple`(`(rc, 바이트)`) · `show(top, commit: str, rel: str)`(바이트, 그 커밋에 없으면 None) · `check_tree(top: Path, team: Team, base: str | None = None) -> tuple`(`(오류 줄들, 검사 불가 줄들, 알림 줄들)`) · `run(argv) -> int`
  - `team_layout.py check --roadmap <로드맵 파일> [--base <ref>]` — 종료 코드 0 · 1 어긋남 · 2 사용법 · 3 검사 불가. `main` 은 함수 안에서 `team_check` 를 import 한다(모듈 맨 위에서 하면 import 가 돈다)
  - `team_write.team_for(top: Path, roadmap_dir: Path, W) -> Team`(해결자의 `roadmaps_dir` 바로 아래가 아니거나 · 역할 이름이거나 · 경로 조각에 `.claude` 가 있거나 · 해결자 오류면 `W.Refused`) · `team_write.wanted_sections(top, brief: Path, framing_audit, W) -> list` · `team_write.cmd_original(a, W) -> int`
  - `roadmap_write.py original --brief <brief> --out <로드맵 폴더> [--framing-audit <경로>]` — 0 · 1 · 2. audit 은 brief 경로의 `.md` 를 `.audit.md` 로 바꾼 파일이다

`W` 는 `roadmap_write` 모듈 객체다 — `roadmap_write.py` 가 `sys.modules[__name__]` 을 넘긴다. `team_write` 에서 `import roadmap_write` 를 하지 않는다: 스크립트로 돌 때 그 모듈은 `__main__` 이라 다시 import 하면 `Refused` · `Usage` 가 다른 클래스가 되어 `main()` 의 `except` 가 잡지 못한다.

- [ ] **Step 1: `original.md` 글의 실패하는 테스트를 쓴다**

`test_team_files.py` 에 더한다:

```python
C = "a" * 40

class Original(unittest.TestCase):
    def test_marker_and_parse(self):
        line = F.marker_line("docs/iv/x.audit.md", C, "원문", 15, 17)
        self.assertEqual(line, "<!-- 출처: docs/iv/x.audit.md@%s · 원문 · 15–17행 · 3줄 -->" % C)
        data = (line + "\n").encode("utf-8") + b"## 1. \xec\x9b\x90\xeb\xac\xb8\n\n## inner heading\n"
        [s] = F.parse_original(data)
        self.assertEqual((s.source, s.commit, s.label, s.first, s.last, s.start), ("docs/iv/x.audit.md", C, "원문", 15, 17, 2))
        self.assertEqual(s.body, data.split(b"\n", 1)[1])
        self.assertEqual(F.line_count(data), 4)

    def test_body_cannot_forge_a_marker(self):   # 줄 수로 읽는다
        fake = F.marker_line("evil.md", "b" * 40, "원문", 1, 1)
        data = (F.marker_line("x.md", C, "사용자 원문", 5, 6) + "\n" + fake + "\n본문\n").encode("utf-8")
        self.assertEqual([s.source for s in F.parse_original(data)], ["x.md"])

    def test_broken(self):
        ok = (F.marker_line("x.md", C, "원문", 1, 2) + "\n가\n나\n").encode("utf-8")
        for bad in (b"\xea\xb0\x80\n" + ok, ok[:-4], ok + b"tail\n", ok.replace("2줄".encode("utf-8"), "3줄".encode("utf-8")), b""):
            self.assertRaises(F.FormatError, F.parse_original, bad)

    def test_extend_appends_only_the_tail(self):   # Review Focus 5 — 앞 줄이 밀리지 않는다
        first, notes = F.extend_original(b"", [("x.md", C, "원문", 10, [b"h\n", b"a\n"], "")])
        again, notes = F.extend_original(first, [("x.md", "c" * 40, "원문", 10, [b"h\n", b"a\n"], "")])
        self.assertEqual((again, notes), (first, []))
        grown, notes = F.extend_original(first, [("x.md", "c" * 40, "원문", 10, [b"h\n", b"a\n", b"b\n"], "")])
        self.assertTrue(grown.startswith(first))
        tail = F.parse_original(grown)[-1]
        self.assertEqual((tail.first, tail.last, tail.body, tail.commit), (12, 12, b"b\n", "c" * 40))

    def test_extend_changed_head_reappends_whole_and_says_so(self):
        first, _ = F.extend_original(b"", [("x.md", C, "원문", 10, [b"h\n", b"a\n"], "")])
        grown, notes = F.extend_original(first, [("x.md", "c" * 40, "원문", 10, [b"h\n", b"A\n"], "")])
        self.assertTrue(grown.startswith(first))
        self.assertEqual((F.parse_original(grown)[-1].body, len(notes)), (b"h\nA\n", 1))

    def test_last_line_without_newline_is_refused(self):   # Review Focus 3
        self.assertRaises(F.FormatError, F.extend_original, b"", [("x.md", C, "원문", 1, [b"no newline"], "")])

    def test_note_is_kept_on_the_marker(self):
        data, _ = F.extend_original(b"", [("b.md", C, "사용자 원문", 3, [b"x\n"], "framing audit 없음")])
        self.assertTrue(data.decode("utf-8").splitlines()[0].endswith("· 1줄 · framing audit 없음 -->"))
        self.assertEqual(F.parse_original(data)[0].note, "framing audit 없음")
```

같은 출처(경로 + 절 이름)의 구간 본문을 순서대로 이은 것이 지금 줄들의 앞머리면 남은 줄만, 같으면 아무것도, 아니면 통째로 붙인다 — 이것이 `extend_original` 의 규칙이다.

- [ ] **Step 2: 끝에서 끝 테스트의 뼈대와 실패하는 단언을 쓴다**

`test_team_write.sh`(실행 비트). 임시 레포에 bare origin 을 두고 `origin/HEAD` 를 맞춘다. 로드맵 폴더는 `RD="$(cd "$W" && python3 "$S/repo_defaults.py" get roadmaps_dir 2>/dev/null)"` 로 얻는다. 픽스처(모두 이 파일만의 글):

- brief `docs/iv/t-brief-interview.md`(§0–§7, 번호 `C1` · `D2` · `OQ1` · `«ext-a»` · `RC1` · `ST1` · `K1`, §6 에 `S1`) 와 audit `…-interview.audit.md`(§6 에 `S2` · `S3`).
- 상태 파일 `docs/iv/t-brief-interview.state.md`(`type: interview-state` · `seed: docs/iv/t-seed-interview.md`), seed(`type: interview-seed` · `audit_file: t-seed-interview.audit.md`), framing audit(`type: interview-seed-audit`, `## 1. 원문` 안에 `## 목표 / ## 지시 원문` 꼴의 줄 하나, `## 2. 질문 전체`, `## 3. 긴 초안`).
- 모두 커밋하고 push 한다.

```bash
orig() { (cd "$W" && python3 "$RW" original --brief docs/iv/t-brief-interview.md --out "${RD}t1" "$@") > "$T/out.txt" 2>&1; echo $?; }
check() { (cd "$W" && python3 "$S/team_layout.py" check --roadmap "${RD}t1/roadmap.md" "$@") > "$T/chk.txt" 2>&1; echo $?; }
O="$W/${RD}t1/intent/original.md"

assert_eq "$(orig)" "0" "original: rc 0"
assert_eq "$(grep -c '^<!-- 출처: ' "$O")" "4" "original: 구간 넷(원문 · 질문 전체 · brief §6 · audit §6)"
assert_grep "$(head -n 1 "$O")" '^<!-- 출처: docs/iv/t-seed-interview\.audit\.md@[0-9a-f]{40} · 원문 · [0-9]+–[0-9]+행 · [0-9]+줄 -->$' "AC5: 첫 줄이 구간의 출처 줄이다(파일 머리가 따로 없다)"
assert_file_has "$O" "## 목표 / ## 지시 원문" "Review Focus 1: 원문 절 안의 제목 꼴 줄까지 옮겼다"
# 구간마다 출처 파일의 그 줄들과 바이트가 같다 — python 으로 parse_original 뒤 `git show <commit>:<source>` 의 first..last 줄과 견준다
assert_eq "$(sections_match)" "ok" "AC5: 옮긴 구간이 출처와 바이트가 같다"
cp "$O" "$T/o1"; assert_eq "$(orig)" "0" "original 다시: rc 0"; cmp -s "$O" "$T/o1" && ok "다시 불러도 바이트가 같다" || no "다시 부르니 바뀌었다"

# 커밋되지 않은 출처 (Review Focus 2)
printf -- '- **S4** 🗣 발화 (round 3):\n  > 넷째 말\n' >> "$W/docs/iv/t-brief-interview.audit.md"   # §6 끝에 닿게 픽스처를 짠다
assert_eq "$(orig)" "1" "커밋 안 된 출처: 옮기지 않는다"
assert_contains "$(cat "$T/out.txt")" "먼저 커밋" "커밋 안 된 출처: 할 일을 말한다"
cmp -s "$O" "$T/o1" && ok "커밋 안 된 출처: 파일 그대로" || no "커밋 안 된 출처인데 파일이 바뀌었다"
g add -- docs/iv && g commit -qm s4
assert_eq "$(orig)" "0" "커밋 뒤: rc 0"
head -c "$(wc -c < "$T/o1")" "$O" | cmp -s - "$T/o1" && ok "AC5: 새 구간을 붙여도 앞 바이트가 그대로다" || no "앞 줄이 바뀌었다"
assert_eq "$(grep -c '^<!-- 출처: ' "$O")" "5" "늘어난 꼬리만 새 구간 하나"

# framing audit 를 찾는 세 길
#  · 상태 파일의 seed 가 「없음」 이고 --framing-audit 도 없으면: rc 0, brief 쪽 구간의 출처 줄 끝이 「framing audit 없음 -->」
#  · --framing-audit 로 주면: 그 파일의 두 절이 실린다
#  · 상태 파일이 가리키는 audit 과 --framing-audit 이 다르면: rc 2
#  · --framing-audit 이 type: interview-seed-audit 이 아니면: rc 1
# CRLF 출처(brief 사본을 CRLF 로 커밋)는 구간 바이트에 \r\n 이 그대로 있고, 끝 줄바꿈 없는 출처는 rc 1 「끝에 줄바꿈」 (Review Focus 3)
```

Task 7 이 이 파일에 `create` 단언을 더한다. 이 과제에서는 `check` 를 `original.md` 만 있는 나무에 돌리지 않는다(로드맵이 없다) — 검사의 단언은 Task 7 에서 로드맵이 선 뒤에 쓴다(Step 5).

- [ ] **Step 3: 실패를 확인한 뒤 `team_files` 의 original 몫 · `team_write.cmd_original` · 진입을 쓴다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_files.py` · `bash plugins/spec-distill/tests/test_team_write.sh` → 새 단언 FAIL.

`wanted_sections` 의 규칙:

- framing audit 찾기: brief 경로의 `.md` 를 `.state.md` 로 바꾼 파일이 있고 그 머리의 `seed:` 가 `없음` 이 아니면, 그 seed(레포 상대 경로) 머리의 `audit_file`(같은 폴더의 파일 이름 — 없으면 seed 의 `.md` 를 `.audit.md` 로 바꾼 이름)이 가리키는 파일이다. 그 파일이 없으면 못 찾은 것이다. 찾은 것과 `--framing-audit` 이 다른 파일이면 `W.Usage`, 못 찾았으면 `--framing-audit` 을 쓰고, 둘 다 없으면 framing 구간 없이 brief 쪽 구간의 표지에 `framing audit 없음` 을 적는다. 쓰기로 한 파일의 머리 `type` 이 `interview-seed-audit` 이 아니면 Refused.
- 출처 커밋: `git log -1 --format=%H -- <경로>` 가 비었거나 `git show <커밋>:<경로>` 가 작업 트리의 바이트와 다르면 `W.Refused("출처 파일에 커밋되지 않은 변경이 있다: %s — 먼저 커밋한 뒤 다시 돈다")`.
- framing audit 의 두 절: 줄이 정확히 `## 1. 원문` · `## 2. 질문 전체` · `## 3. 긴 초안` 인 줄을 문자열 비교로 찾는다. 각각 한 번씩 이 순서로 있어야 하고(아니면 Refused — 줄 번호를 보인다), 「원문」 구간은 첫째 줄부터 둘째 줄 앞까지, 「질문 전체」 구간은 둘째 줄부터 셋째 줄 앞까지다. 그 사이의 다른 `## ` 줄은 경계가 아니다.
- brief · audit 의 「사용자 원문」 구간: `section6.span(text)` 의 `start` 부터 `end` 앞까지의 줄. None 이면 Refused. audit §6 의 발화 번호(`brief_body.anchor_lines`)가 모두 brief §6 에 있으면 audit 구간은 만들지 않는다.
- 순서: framing 원문 · framing 질문 전체 · brief · audit.

`cmd_original` 은 `team_for` 로 자리를 확인하고, `extend_original` 의 결과가 지금 파일과 같으면 쓰지 않고 0, 다르면 `W.Txn` 으로 쓴다(폴더는 `ensure_dir`). 알림 줄은 `[spec-distill] ` 머리로 낸다. 로드맵이 이미 있으면 쓴 뒤 `check_tree` 를 돌려 오류면 되돌린다.

- [ ] **Step 4: `team_check.py` 와 `team_layout.py check` 를 쓴다**

`check_tree` 가 보는 것(각 어긋남은 그 파일 경로와 무엇이 어긋났는지를 한 줄로 — 범위는 `23–57` 꼴 그대로 짚는다):

1. 로드맵 파일이 있고 머리말이 `type: roadmap` · `layout: team` 이며 `parse_roadmap` 오류가 없다.
2. RULES.md 와 `original.md` 가 있고, `original.md` 가 `parse_original` 로 끝까지 읽힌다.
3. `roadmaps_dir` 바로 아래에 역할 문서 넷과 HANDBOOK.md 가 있다.
4. 결정 블록이 아닌 블록마다 과제 폴더에 INTENT.md(머리 `type: job` · `job: <번호>` · `kind: epic` · `roadmap: <로드맵 경로>`, 네 칸이 읽힌다) · sources.md(머리 `type: job-sources` · `job: <번호>` · `ids` 가 읽힌다) · 결과 폴더가 있다.
5. 과제 폴더 가운데 블록이 없는 것: 머리가 `kind: task` 면 `branch` · `paths` 가 비지 않고 네 칸이 읽히고 결과 폴더가 있어야 한다. `kind: epic` 이면 오류가 아니라 알림(「로드맵에 없는 에픽 과제 폴더」)이다. 폴더 이름은 `job_name_problem` 을 통과한다.
6. `plan-<n>.md` 의 n 이 그 과제의 브랜치 수(에픽은 블록의 브랜치 수, 단순 작업은 1)를 넘지 않는다(P4).
7. 에픽 INTENT.md 의 범위마다 `1 ≤ a ≤ b ≤ original.md 줄 수`, 범위가 하나 이상이다. `kind: task` 는 보지 않는다(AC4).
8. `original.md` 의 구간마다 `show(top, commit, source)` 의 `first..last` 줄이 본문과 바이트가 같다. 그 커밋이나 파일을 읽지 못하면 오류가 아니라 **검사 불가** 줄이다.
9. 덧붙이기: `base`(없으면 `roadmap_model.DEFAULT_REF`)의 `original.md` 가 있으면 그 바이트가 지금 파일의 앞머리여야 한다. 기본 ref 가 없으면 알림 한 줄, `--base` 로 준 ref 를 못 읽으면 검사 불가.
10. 알림: `intent_drift` 가 낸 줄(에픽마다 블록의 의도 · 범위와 견준다).

`run`: 오류와 검사 불가 줄을 `[spec-distill] ` 머리로 표준 출력에, 알림은 표준 오류에 낸다. 검사 불가가 있으면 3, 없고 오류가 있으면 1, 아니면 0. `--roadmap` 의 팀은 `repo_defaults.resolve` 의 `roadmaps_dir` 과 `team_from_roadmap` 으로 얻는다.

- [ ] **Step 5: 통과를 확인하고 커밋한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_files.py plugins/spec-distill/tests/test_team_layout.py` · `bash plugins/spec-distill/tests/test_team_write.sh` · `python3 -m unittest plugins/quality-gates/tests/test_utf8_explicit.py` · `bash shared/tests/test_python_floor.sh`
Expected: 통과.

```bash
chmod +x plugins/spec-distill/tests/test_team_write.sh
git add -- plugins/spec-distill/scripts/team_files.py plugins/spec-distill/scripts/team_check.py plugins/spec-distill/scripts/team_write.py plugins/spec-distill/scripts/team_layout.py plugins/spec-distill/scripts/roadmap_write.py plugins/spec-distill/tests/test_team_files.py plugins/spec-distill/tests/test_team_write.sh
git ls-files -s plugins/spec-distill/tests/test_team_write.sh   # 100755
git commit -m "feat(spec-distill): 원자료 사본(original) 명령과 team 나무 검사" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

---

### Task 7: `create --layout team` — 한 거래로 만들기 (AC3 · AC4 · AC5 · AC8 · AC18)

**Files:**
- Modify: `plugins/spec-distill/scripts/team_write.py` · `roadmap_write.py`(`cmd_create` · `build_parser`)
- Test: `plugins/spec-distill/tests/test_team_write.sh`

**Interfaces:**
- Consumes: Task 4–6.
- Produces:
  - `roadmap_write.py create … [--layout team]` — `--layout` 의 choices 는 `team_layout.LAYOUTS`
  - `roadmap_render.render_roadmap(template, rows, idx, title, brief_rel, roadmap_rel, history, layout=None) -> str` — 인자 하나를 더한다(블록을 `render_block(r, layout)` 로 그린다). 옛 호출의 출력은 그대로다
  - `team_write.render_team_roadmap(template: str, rows, idx, title, brief_rel, roadmap_rel, history) -> str`
  - `team_write.seed_common(top: Path, roadmaps_dir: str, W) -> dict`(없는 역할 문서 · HANDBOOK.md 의 `{Path: 글}`)
  - `team_write.create_files(top: Path, team: Team, rows, idx, title, brief_rel, roadmap_rel, history, brief: Path, W) -> tuple` — `(다시 쓰는 파일 {Path: 글}, 없을 때만 까는 파일 {Path: 글})`

- [ ] **Step 1: 실패하는 단언을 쓴다**

`test_team_write.sh` 에 더한다. 표는 `HEAD_T`(옛 머리 + `| 지시 원문 범위 |`)와 행 셋 — 결정 `P1`(범위 `없음`) · 묶음 `E1`(범위는 `original.md` 안의 실제 줄, 예 `2–4`) · 묶음 `E2`:

```bash
tcreate() { (cd "$W" && python3 "$RW" create --layout team --brief docs/iv/t-brief-interview.md --audit docs/iv/t-brief-interview.audit.md \
   --plan-table "$1" --out "$2" --title "팀 픽스처" --date 2026-11-14 --approval "이대로 승인 (권장)") > "$T/out.txt" 2>&1; echo $?; }

assert_eq "$(tcreate "$T/state.md" "${RD}t1")" "0" "AC3: create --layout team rc 0"
assert_eq "$(tree_of "$W/${RD}t1")" "$(printf './RULES.md\n./intent/original.md\n./jobs/E1/INTENT.md\n./jobs/E1/results/.gitkeep\n./jobs/E1/sources.md\n./jobs/E2/INTENT.md\n./jobs/E2/results/.gitkeep\n./jobs/E2/sources.md\n./roadmap.md')" "AC3: §11 의 파일(결정 블록은 과제 폴더가 없다)"
assert_eq "$(sed -n 1,5p "$W/${RD}t1/roadmap.md")" "$(printf -- '---\ntype: roadmap\nlayout: team\nsource_brief: docs/iv/t-brief-interview.md\n---')" "AC3: 머리말 layout: team"
assert_file_has "$W/${RD}t1/roadmap.md" "- 묶음: jobs/E1/sources.md" "블록의 묶음 값이 번호 파일을 가리킨다"
assert_file_has "$W/${RD}t1/roadmap.md" "에픽마다 과제 폴더의 INTENT.md 를 넘긴다." "로드맵 머리 글이 team 문장이다"
for r in leader designer writer worker; do cmp -s "$W/${RD}${r}/CLAUDE.md" "$SD/templates/team/role-${r}.md" && ok "AC18: 역할 문서 ${r} 를 틀 그대로 깔았다" || no "AC18: 역할 문서 ${r}"; done
cmp -s "$W/${RD}HANDBOOK.md" "$SD/templates/team/HANDBOOK.md" && ok "AC18: HANDBOOK.md 를 깔았다" || no "AC18: HANDBOOK.md"
[ ! -e "$W/REVIEW.md" ] && ok "생성기는 REVIEW.md 를 깔지 않는다" || no "REVIEW.md 를 깔았다"
assert_eq "$(check)" "0" "AC3: 만든 나무가 구조 검사를 통과한다"
assert_file_has "$W/${RD}t1/jobs/E1/INTENT.md" "- 범위: intent/original.md 2–4행" "AC4: 지시 원문은 줄 범위를 적는다"
assert_eq "$(grep -c '둘째 말' "$W/${RD}t1/jobs/E1/INTENT.md" "$W/${RD}t1/jobs/E1/sources.md" | awk -F: '{s+=$2} END{print s}')" "0" "AC4: 원자료의 글을 다시 싣지 않는다"
assert_contains "$(cat "$T/out.txt")" "E1 지시 원문 2–4행" "create 가 과제마다 그 범위의 글을 화면에 낸다"
assert_eq "$(grep -c . "$T/state.md.record")" "5" "생성 기록: 로드맵 · INTENT.md 둘 · sources.md 둘"   # RULES · original · 역할 문서는 기록하지 않는다

# 한 거래 (AC3) — 실패하면 아무것도 남지 않는다
before="$(tree_of "$W")"
#  · 표의 배정 번호에서 C1 을 뺀 표(unassigned) → rc 1, tree_of "$W" 가 before 와 같다(새 팀 폴더 · 그 안 폴더 없음)
#  · 범위가 파일 밖(9999–10000) → rc 1, 출력에 「9999–10000」, 나무 그대로 (AC4)
#  · 뒤집힌 범위(4–2) · 0 으로 시작 · 묶음 행의 「없음」 · 브랜치 종류 행 → rc 1, 나무 그대로 (Review Focus 5)
#  · --out "${RD}worker" → rc 1 「역할 이름」 (AC8) — 옛 형식(--layout 없이)도 같다
#  · --out docs/elsewhere/t9 (로드맵 폴더 밖) → rc 1
#  · --layout nope → rc 2

# 있는 것은 건드리지 않는다 (AC18 · Review Focus 4)
#  · 새 레포 사본에서 leader/CLAUDE.md 와 HANDBOOK.md 에 다른 글을 미리 두고 create → 그 둘은 바이트 그대로, 나머지 셋만 깔린다
#  · designer 가 다른 폴더로 가는 심볼릭 링크면 → rc 1 「링크」, 링크 대상 폴더에 파일이 생기지 않는다
#  · origin 의 .devbrew.md 가 `roadmaps_dir: .claude/roadmaps/` 인 레포 사본 → rc 1 「.claude」, .claude 아래에 아무것도 없다
#  · RULES.md 에 규칙 한 줄을 손으로 더한 뒤 create 를 다시 돌려도 RULES.md 는 그대로다

# 다시 돌리기 (P13)
#  · 같은 표로 다시 → rc 0, 나무 바이트 같음
#  · INTENT.md 의 결정 기록에 `- 결정 · 2026-11-15 · 「가」` 를 더한 뒤 다시 → rc 1 「update」, 파일 그대로
#  · 표에서 E2 를 빼고(번호는 E1 로 옮김) 다시 → rc 1 「jobs/E2」, 파일 그대로

# 검사의 이빨 (AC4 · AC5) — 만든 나무를 커밋 · push 한 뒤
#  · original.md 본문의 글자 하나를 바꾼다 → check rc 1, 출력에 그 구간의 출처 경로와 절 이름 (AC5)
#  · 되돌리고 첫 줄(표지)을 지운다 → check rc 1 (앞 줄을 지움)
#  · 되돌리고 끝에 구간이 아닌 줄을 붙인다 → rc 1
#  · 되돌리고 audit 에 발화를 더해 커밋한 뒤 original 을 다시 → check rc 0 (덧붙이기는 받는다), E1 의 범위 2–4 가 가리키는 줄이 그대로다
#  · --base no-such-ref → rc 3
#  · INTENT.md 의 범위 줄을 `9–3` 으로 고친다 → rc 1 「9–3」; 범위 줄을 지운다 → rc 1
#  · jobs/E1/plan-2.md 를 둔다(브랜치 하나) → rc 1 「plan-2.md」 (P4)
#  · jobs/E1/INTENT.md 의 목표 한 글자를 바꾼다 → rc 0, 표준 오류에 「목표」 알림

# 옛 형식은 그대로 (AC3 · AC8)
#  · 같은 레포에 --layout 없이 옛 create(--out "${RD}old1") → 나무가 old1/{E1.md,E2.md,roadmap.md}, jobs · intent 없음
#  · 옛 나무의 바이트는 Task 5 Step 1 이 test_roadmap_write.sh 에 못 박은 다이제스트 단언이 잰다 — 이 과제 뒤에도 그 테스트가 통과해야 한다
#  · old1 을 커밋 · push 한 뒤 `roadmap_status.py --roadmap ${RD}old1/roadmap.md --json` 의 blocks · format_errors · unknown_reasons · exit 를
#    역할 문서 넷 · HANDBOOK.md 를 push 하기 전과 뒤로 견준다 — 같다
#  · 기본 브랜치 트리에서 `roadmap_model.tree_entries` → `find_roadmaps` 로 센 로드맵이 old1 · t1 둘이고 검사 불가 목록이 비었다
```

`"$T/state.md.record"` 는 표 파일의 `## 생성 기록` 절 줄만 뽑아 둔 것이다(도우미로 뽑는다).

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_team_write.sh`
Expected: `create --layout team` 단언 FAIL(argparse 가 `--layout` 을 모른다 — rc 2).

- [ ] **Step 3: `team_write` 의 만들기와 `cmd_create` 의 갈림을 쓴다**

- `cmd_create` 맨 앞: `out_dir.name` 이 `team_name_problem` 에 걸리면 형식과 무관하게 Refused. `a.layout` 이 없으면 그 아래는 지금 코드 그대로다(옛 출력의 바이트가 같아야 한다).
- team 일 때 `cmd_create` 가 다르게 하는 것 넷: 표를 `R.parse_table(text, a.layout)` 로 읽는다 · 만들 파일을 `team_write.create_files` 에서 받는다 · 거래 안에서 `validate` 뒤에 `team_check.check_tree` 를 돌려 오류나 검사 불가가 있으면 Refused · 성공 줄 뒤에 과제마다 `[spec-distill] <번호> 지시 원문 <범위>행:` 과 그 줄들을 낸다(화면에만 — 파일에 남기지 않는다).
- `create_files`: 다시 쓰는 파일은 로드맵 · 묶음 행마다 INTENT.md 와 sources.md 다. 없을 때만 까는 파일은 RULES.md · `original.md`(없으면 `wanted_sections` + `extend_original`) · 묶음 행마다 결과 폴더의 `.gitkeep` · `seed_common` 의 것이다. 「있다」 는 `os.path.lexists` 로 본다. 역할 폴더나 그 위 경로가 심볼릭 링크면 Refused.
- 생성 기록에는 다시 쓰는 파일만 적는다. 지금 `stray` 검사(자기가 만들지 않은 파일은 덮어쓰지 않는다)는 다시 쓰는 파일에 그대로 건다. 생성 기록에 있는 INTENT.md 에 결정 기록 줄(`- ` 로 시작)이 있으면 Refused(P13). 생성 기록에 있는데 이번 표에 없는 과제의 파일이 남아 있으면 Refused — 지금 `stale` 지우기는 team 에서 하지 않는다.
- `render_team_roadmap`: `R.render_roadmap(…, layout="team")` 의 결과에서 두 곳을 바꾼다 — 맨 앞 `"---\ntype: roadmap\n"` 뒤에 `"layout: team\n"` 을 넣고, 문장 `에픽마다 원본 brief · 이 로드맵 · 에픽 묶음을 넘긴다.` 를 `에픽마다 과제 폴더의 INTENT.md 를 넘긴다.` 로 바꾼다. 두 자리 가운데 하나라도 정확히 한 번 나오지 않으면 Refused(틀이 바뀌었다). 틀 파일을 따로 두지 않는다 — 로드맵 틀의 사본을 두면 20줄 중복 락에 걸리고 두 틀이 따로 낡는다.
- 로드맵 틀의 그 문장이 그대로 있는지는 `test_roadmap_render.py` 에 단언 하나로 못 박는다(`self.assertEqual(TEMPLATE_TEXT.count("에픽마다 원본 brief · 이 로드맵 · 에픽 묶음을 넘긴다."), 1)`) — 틀이 바뀌면 실행 때가 아니라 스위트에서 걸린다.

- [ ] **Step 4: 통과와 옛 형식 회귀를 확인한다**

Run: `bash plugins/spec-distill/tests/test_team_write.sh` · `bash plugins/spec-distill/tests/test_roadmap_write.sh` · `python3 -m unittest plugins/spec-distill/tests/test_roadmap_write.py plugins/spec-distill/tests/test_roadmap_write_atomic.py plugins/spec-distill/tests/test_roadmap_render.py plugins/spec-distill/tests/test_team_layout.py` · `bash plugins/spec-distill/tests/test_finish_commit_roadmap.sh`
Expected: 통과.

- [ ] **Step 5: 커밋**

```bash
git add -- plugins/spec-distill/scripts/team_write.py plugins/spec-distill/scripts/roadmap_write.py plugins/spec-distill/scripts/roadmap_render.py plugins/spec-distill/tests/test_team_write.sh plugins/spec-distill/tests/test_roadmap_render.py
git commit -m "feat(spec-distill): create --layout team 이 팀 폴더를 한 거래로 만든다" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

---

### Task 8: team 형식의 `update` · `extract` (AC6)

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_write.py`(`cmd_update` · `cmd_extract` · `stages` · `main` 의 종료 코드) · `team_write.py`
- Test: `plugins/spec-distill/tests/test_team_write.sh`

**Interfaces:**
- Consumes: Task 5–7.
- Produces:
  - `roadmap_write.EXIT_TODO = 4` — 「썼다 — 사람이 고칠 것이 남았다」. 모듈 docstring 의 종료 코드 줄에 더한다
  - `roadmap_write.stages(top, roadmap, layout=None) -> dict` — team 이고 「알 수 없음」 블록의 사유가 모두 `team_layout.STAGE_PENDING` 이면 `{}` 를 돌려주고 한 줄을 낸다: `[spec-distill] 머지 여부를 확인하지 못했다 — 이 판은 team 형식의 단계를 계산하지 않는다. 머지된 에픽을 바꾸지 않았는지 직접 확인한다`
  - `team_write.update_files(top: Path, team: Team, old: dict, new: dict, changed: list, added: list, removed: list, idx, roadmap_rel: str, W) -> tuple` — `(쓸 파일 {Path: 글}, 없을 때만 까는 파일 {Path: 글}, 손으로 고칠 것 줄들, 알림 줄들)`

- [ ] **Step 1: 실패하는 단언을 쓴다**

`test_team_write.sh` 에 더한다(Task 7 의 `t1` 을 커밋 · push 한 뒤):

```bash
extract() { (cd "$W" && python3 "$RW" extract --roadmap "${RD}t1/roadmap.md"); }
tupdate() { (cd "$W" && python3 "$RW" update --roadmap "${RD}t1/roadmap.md" --brief docs/iv/t-brief-interview.md --audit docs/iv/t-brief-interview.audit.md \
   --plan-table "$1" --date 2026-11-15 --change "픽스처 재분해" --approval "다시 나눈다") > "$T/out.txt" 2>&1; echo $?; }

extract > "$T/x1.md"
assert_grep "$(sed -n 3p "$T/x1.md")" '\| 지시 원문 범위 \|$' "AC6: team extract 의 표 끝에 지시 원문 범위 칸"
assert_contains "$(grep '^| E1 ' "$T/x1.md")" "| 2–4 |" "AC6: 범위는 INTENT.md 에서 뽑는다"
assert_contains "$(grep '^| P1 ' "$T/x1.md")" "| 없음 |" "결정 행의 범위는 없음"
assert_eq "$(tupdate "$T/x1.md")" "0" "AC6: 뽑은 표를 그대로 받는다"
assert_contains "$(cat "$T/out.txt")" "바뀐 에픽이 없다" "뽑은 표 그대로면 쓰지 않는다"

# 번호만 옮긴다(E1 의 D2 를 E2 로) — 목표 · 범위는 그대로
cp "$W/${RD}t1/jobs/E1/INTENT.md" "$T/i1"
assert_eq "$(tupdate "$T/moved.md")" "0" "번호만 바뀌면 rc 0"
assert_contains "$(cat "$T/out.txt")" "머지 여부를 확인하지 못했다" "team update: 머지 여부 알림(계획 2 가 뒤집는다)"
cmp -s "$W/${RD}t1/jobs/E1/INTENT.md" "$T/i1" && ok "AC6: INTENT.md 는 바이트 그대로" || no "AC6: INTENT.md 가 바뀌었다"
assert_file_has "$W/${RD}t1/jobs/E2/sources.md" "D2" "AC6: sources.md 는 다시 쓴다"
assert_eq "$(check)" "0" "update 뒤에도 구조 검사를 통과한다"

# 목표가 바뀐다(E1 의 의도) + 새 에픽 E3(번호는 E2 에서 하나 옮긴다 — 범위는 original.md 안의 줄)
assert_eq "$(tupdate "$T/goal.md")" "4" "AC6: 목표가 바뀌면 종료 코드 4"
assert_contains "$(cat "$T/out.txt")" "손으로 고칠 것" "AC6: 고칠 내용을 낸다"
assert_contains "$(cat "$T/out.txt")" "새 의도 글" "AC6: 새 목표 글이 화면에 있다"
assert_contains "$(cat "$T/out.txt")" "과제 브랜치가 있으면" "어느 INTENT.md 를 고치는지 말한다"
cmp -s "$W/${RD}t1/jobs/E1/INTENT.md" "$T/i1" && ok "AC6: 목표가 바뀌어도 INTENT.md 는 그대로" || no "INTENT.md 를 다시 썼다"
assert_file_has "$W/${RD}t1/roadmap.md" "- 의도: 새 의도 글" "쓰기는 끝났다 — 로드맵 블록이 바뀌었다"
[ -f "$W/${RD}t1/jobs/E3/INTENT.md" ] && [ -f "$W/${RD}t1/jobs/E3/sources.md" ] && [ -f "$W/${RD}t1/jobs/E3/results/.gitkeep" ] && ok "새 과제 폴더를 만들었다" || no "새 과제 폴더가 없다"
assert_eq "$(check)" "0" "종료 코드 4 뒤의 나무도 구조 검사를 통과한다"
assert_contains "$(cat "$T/chk.txt")" "목표" "검사가 INTENT.md 와 블록의 어긋남을 알린다"
assert_eq "$(tupdate "$T/goal.md")" "0" "같은 표로 다시: 바뀐 에픽이 없다"

#  · 범위만 바뀐 표(E2 의 범위 5–6 → 5–7) → rc 4, 출력에 「5–7」, INTENT.md 그대로
#  · 파일 밖 범위로 바꾼 표 → rc 1, 나무 그대로(되돌림)
#  · E3 을 뺀 표 → rc 0, jobs/E3 은 그대로 있고 출력에 「사라진 에픽 E3」 과 그 폴더 경로, check rc 0 · 알림에 「로드맵에 없는 에픽 과제 폴더」
#  · 새 에픽 E4 인데 jobs/E4/INTENT.md 가 이미 있다 → rc 1 「덮어쓰지 않는다」
#  · 옛 형식 로드맵(old1)의 extract 출력에는 그 칸이 없고, 그 표에 칸을 더해 update 하면 rc 1 (옛 형식의 표는 바뀌지 않는다)
#  · 옛 형식 update 의 있는 테스트는 그대로 통과한다(test_roadmap_write.sh)
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_team_write.sh`
Expected: `extract` · `update` 단언 FAIL.

- [ ] **Step 3: `cmd_update` · `cmd_extract` 의 갈림을 쓴다**

`cmd_update` 는 한 함수로 두고 형식에 따라 다섯 곳만 가른다(통째로 복사한 둘째 함수를 만들지 않는다 — 20줄 중복 락):

1. `layout = team_layout.layout_of(frontmatter(old_text))`(`UnknownLayout` 은 Refused). 새 표는 `R.parse_table(…, layout)`.
2. `stages(top, roadmap, layout)`.
3. 블록 다시 그리기는 `R.render_block(r, layout)`.
4. team 이면 쓸 파일을 `team_write.update_files` 에서 받고(옛 형식의 묶음 쓰기 · 지우기 갈래는 건너뛴다), 거래 안에서 `validate` 뒤에 `check_tree` 를 돌린다.
5. 성공 줄 뒤에 알림 줄을 내고, 손으로 고칠 것이 있으면 내고 `EXIT_TODO` 를 돌려준다.

`update_files` 의 규칙: 바뀌었거나 새로 온 묶음 행의 sources.md 는 글이 다르면 다시 쓴다. 새로 온 묶음 행(그리고 결정에서 묶음으로 바뀐 행)은 INTENT.md 와 `.gitkeep` 을 만든다 — INTENT.md 가 이미 있으면 Refused. 이미 있던 과제의 INTENT.md 는 쓰지 않는다: 옛 행과 새 행의 의도 · 범위 · 지시 원문 범위 가운데 하나라도 다르면 손으로 고칠 것에 올린다. 사라졌거나 묶음에서 결정으로 바뀐 과제의 폴더는 건드리지 않고 알림에 올린다(`사라진 에픽 <번호>: 과제 폴더 <경로> 를 그대로 뒀다 — 필요 없으면 손으로 지운다`).

손으로 고칠 것의 글(과제마다):

```
[spec-distill] 손으로 고칠 것 — <번호> 의 INTENT.md(<경로>)는 다시 쓰지 않았다. 사용자 승인 뒤 아래대로 고치고 결정 기록에 `- 결정 · <날짜> · 「…」` 한 줄을 남긴다. 과제 브랜치가 있으면 일꾼이 돌아온 뒤 그 브랜치의 INTENT.md 를, 없으면 이 브랜치의 것을 고친다.
  목표:
<goal_text 의 글, 줄마다 네 칸 들여서>
  지시 원문 범위: <format_ranges>
  하지 않을 것:
<not_text 의 글, 줄마다 네 칸 들여서>
```

`cmd_extract` 는 로드맵 머리말의 형식으로 `R.format_table(rows, layout)` 을 낸다(읽기는 `R.extract_rows` 가 이미 가른다).

- [ ] **Step 4: 통과와 회귀를 확인한다**

Run: `bash plugins/spec-distill/tests/test_team_write.sh` · `bash plugins/spec-distill/tests/test_roadmap_write.sh` · `python3 -m unittest plugins/spec-distill/tests/test_roadmap_write.py plugins/spec-distill/tests/test_roadmap_migrate.py` · `bash shared/tests/test_no_new_duplication.sh`
Expected: 통과.

- [ ] **Step 5: 커밋**

```bash
git add -- plugins/spec-distill/scripts/roadmap_write.py plugins/spec-distill/scripts/team_write.py plugins/spec-distill/tests/test_team_write.sh
git commit -m "feat(spec-distill): team 형식의 재분해와 표 뽑기 — INTENT.md 는 다시 쓰지 않는다" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

---

### Task 9: `job new` — 단순 작업의 과제 폴더 (AC7)

**Files:**
- Modify: `plugins/spec-distill/scripts/team_write.py` · `roadmap_write.py`(`build_parser` · `COMMANDS`)
- Test: `plugins/spec-distill/tests/test_team_write.sh`

**Interfaces:**
- Consumes: `team_files.render_intent` · `team_for` · `team_check.check_tree`.
- Produces: `roadmap_write.py job new --roadmap <로드맵> --name <이름> --branch <브랜치> --paths <쉼표 목록> --goal <한 줄> [--not <한 줄>]…` — 지시 원문은 표준 입력의 바이트 그대로. 0 · 1 · 2. `team_write.cmd_job_new(a, W) -> int`.

- [ ] **Step 1: 실패하는 단언을 쓴다**

```bash
jobnew() { (cd "$W" && python3 "$RW" job new --roadmap "${RD}t1/roadmap.md" "$@") > "$T/out.txt" 2>&1; echo $?; }
printf '줄 하나\n## 하지 않을 것\n{{JOB}} 그대로\r\n끝 줄바꿈 없음' > "$T/said.bin"
assert_eq "$(jobnew --name fix-typo --branch fix/typo --paths "a/b.py, docs/c.md" --goal "오타를 고친다" --not "코드 동작 바꾸기" < "$T/said.bin")" "0" "AC7: job new rc 0"
J="$W/${RD}t1/jobs/fix-typo"
assert_eq "$(sed -n 1,8p "$J/INTENT.md")" "$(printf -- '---\ntype: job\njob: fix-typo\nkind: task\nroadmap: %st1/roadmap.md\nbranch: fix/typo\npaths: [a/b.py, docs/c.md]\n---' "$RD")" "AC7: 머리"
[ -f "$J/results/.gitkeep" ] && ok "AC7: results/ 를 만든다" || no "AC7: results/ 없음"
cat > "$T/sec.py" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import team_files as F
s = F.intent_sections(open(sys.argv[2], "rb").read().decode("utf-8"))
print(s["지시 원문"].encode("utf-8") == open(sys.argv[3], "rb").read(), s["목표"], s["하지 않을 것"], repr(s["결정 기록"]))
PY
assert_eq "$(python3 "$T/sec.py" "$S" "$J/INTENT.md" "$T/said.bin")" "True 오타를 고친다 - 코드 동작 바꾸기 ''" "AC7: 지시 원문이 받은 글과 바이트가 같다(제목 꼴 줄 · 자리표 · CRLF · 끝 줄바꿈 없음)"
assert_eq "$(check)" "0" "task 과제 폴더가 든 나무도 구조 검사를 통과한다(범위 검사의 대상이 아니다)"
[ ! -e "$J/sources.md" ] && ok "task 에는 sources.md 가 없다" || no "task 에 sources.md 가 있다"

#  · --not 없이 → 하지 않을 것이 「- 없음」
#  · --name worker / leader → rc 1 「역할 이름」 (AC7)
#  · --name fix-typo 다시 → rc 1 「이미 있다」, 파일 그대로 (AC7)
#  · --name E1(에픽 번호) · --name P1(결정 블록 번호 — 폴더는 없다) → rc 1
#  · --name "a/b" · ".x" · "한글" → rc 1
#  · 빈 표준 입력 → rc 1 「받은 말이 비었다」 (Review Focus 3)
#  · UTF-8 이 아닌 바이트 → rc 1
#  · --goal 에 줄바꿈 · --branch 가 빈 글 · --paths 가 비었거나 원소에 `[` `]` `,` 줄바꿈 → rc 2
#  · 옛 형식 로드맵(old1)에 → rc 1 「team 형식 로드맵이 아니다」
#  · 실패한 경우마다 jobs/ 아래 나무가 그대로다
```

- [ ] **Step 2: 실패를 확인한 뒤 `cmd_job_new` 와 진입을 쓴다**

Run: `bash plugins/spec-distill/tests/test_team_write.sh` → `job new` 단언 FAIL.

표준 입력은 `sys.stdin.buffer.read()` 로 읽어 `decode("utf-8")`(엄격)한 글을 그대로 `render_intent` 에 넘긴다 — 줄바꿈을 바꾸지 않는다. `--paths` 는 쉼표로 나눠 앞뒤 공백을 뗀다. 이름은 `job_name_problem` · 그 로드맵의 블록 번호 · 이미 있는 과제 폴더(`lexists`)에 걸리면 Refused. 쓰기는 `W.Txn` 이고 쓴 뒤 `check_tree` 를 돌려 오류면 되돌린다. 브랜치를 만들거나 커밋하지 않는다(P10).

- [ ] **Step 3: 통과를 확인하고 커밋한다**

Run: `bash plugins/spec-distill/tests/test_team_write.sh` · `python3 -m unittest plugins/spec-distill/tests/test_team_layout.py`
Expected: 통과.

```bash
git add -- plugins/spec-distill/scripts/team_write.py plugins/spec-distill/scripts/roadmap_write.py plugins/spec-distill/tests/test_team_write.sh
git commit -m "feat(spec-distill): job new 가 단순 작업의 과제 폴더를 만든다" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

---

### Task 10: 형식 정본 문서 · README · 판 · 변이 확인 (AC26)

**Files:**
- Create: `plugins/spec-distill/references/team-files.md` · `plugins/spec-distill/tests/test_team_docs.py`
- Modify: `plugins/spec-distill/README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json`

**Interfaces:**
- Consumes: 앞 과제의 형식 전부.
- Produces: `references/team-files.md` 의 2단계 제목 — `## §1 팀 폴더` · `## §2 과제 폴더와 INTENT.md` · `## §3 원자료` · `## §4 sources.md` · `## §6 역할 문서`. 계획 2 가 `## §5 결과 파일` · `## §10 단계 계산` 을, 계획 3 이 `## §7`–`## §9` · `## §15` 를 번호 순서 자리에 끼운다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_team_docs.py`:

```python
DOC = PLUGIN / "references" / "team-files.md"
README = PLUGIN / "README.md"

class TeamFilesDoc(unittest.TestCase):   # R1 AC26 — 계획 1 몫
    def test_sections_of_this_plan(self):
        heads = [l for l in DOC.read_text(encoding="utf-8").splitlines() if l.startswith("## ")]
        self.assertEqual(heads, ["## §1 팀 폴더", "## §2 과제 폴더와 INTENT.md", "## §3 원자료", "## §4 sources.md", "## §6 역할 문서"])

    def test_names_come_from_the_code(self):
        text = DOC.read_text(encoding="utf-8")
        for name in L.ROLES + (L.RULES_FILE, L.HANDBOOK_FILE, L.INTENT_FILE, L.SOURCES_FILE, L.ORIGINAL_FILE, L.REVIEW_FILE, L.STATUS_FILE,
                               "layout: team", "type: job", "type: job-sources", "kind: epic", "kind: task", R.TEAM_COLUMN) + F.SECTIONS:
            self.assertIn(name, text, name)
        self.assertIn("<!-- 출처: ", text)   # 구간 첫 줄의 머리

    def test_users_example_is_verbatim(self):   # 원문 대조 — INTENT.md 예시 「로그인 개선」
        text = DOC.read_text(encoding="utf-8")
        for line in ("예시) 로그인 개선", "목표 - 재설정 뒤 다시 로그인 하는 단계 없애기",
                     "지시 원문 - 재설정 뒤에 다시 로그인 하는 단계 없애고, 디자인 톤은 유지",
                     "하지 않을 것 - 로그인 화면 디자인 바꾸기 소셜 로그인 추가", "결정 기록 - 10/22 방향 1 승인 단계가 가장 적음"):
            self.assertIn("\n" + line + "\n", text)

    def test_notice_not_enforcement_lives_here_and_in_readme_only(self):   # D2.19
        sentence = "역할 문서는 알림이고 막는 것은 도구 권한이다"
        self.assertIn(sentence, DOC.read_text(encoding="utf-8"))
        self.assertIn(sentence, README.read_text(encoding="utf-8"))

    def test_one_plan_per_branch_and_exit_codes(self):
        text = DOC.read_text(encoding="utf-8")
        self.assertIn("브랜치 하나에 계획 하나", text)
        self.assertIn("종료 코드 4", text)

class Readme(unittest.TestCase):
    def test_team_layout_is_documented(self):
        text = README.read_text(encoding="utf-8")
        principles = text.split("## Principles Instantiated", 1)[1].split("\n## ", 1)[0]
        self.assertIn("team-files.md", principles)
        for name in ("--layout team", "team_layout.py check", "job new", "original --brief", "references/team-files.md"):
            self.assertIn(name, text, name)
        self.assertIn("`roadmap_write.py` 는 0 성공 · 1 쓰지 않음 · 2 사용법 오류 · 4 ", text)

class Version(unittest.TestCase):
    def test_bumped_with_changelog(self):
        version = json.loads((PLUGIN / ".claude-plugin" / "plugin.json").read_text(encoding="utf-8"))["version"]
        self.assertGreaterEqual(tuple(int(x) for x in version.split(".")), (8, 14, 0))
        log = (PLUGIN / "CHANGELOG.md").read_text(encoding="utf-8")
        self.assertIn("## [%s] — " % version, log)
        entry = log.split("## [%s] — " % version, 1)[1].split("\n## [", 1)[0]
        for word in ("--layout team", "rules_budget", "handbook_budget", "job new", "종료 코드 4"):
            self.assertIn(word, entry, word)
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_docs.py`
Expected: 파일 없음 ERROR · 판 FAIL.

- [ ] **Step 3: `references/team-files.md` 를 쓴다**

사람이 읽는 형식 정본이다. 설계 §1–§4 · §6 의 내용을 구현된 대로 적는다 — 절마다 싣는 것:

- **§1 팀 폴더** — 설계 §1 의 나무와 「파일 · 무엇만 적나 · 쓰는 사람 · 정본」 표(글자 그대로 옮기되 「리더가 쓰는 자리(§15)」 는 「계획 3 이 §15 로 적는다」 로 가리킨다). 로드맵은 머리말 `type: roadmap` 인 파일이 있는 폴더이고 역할 이름은 로드맵 폴더 이름으로 받지 않는다. `layout: team` 이 형식 표시이고, 이 판의 단계 계산은 team 형식을 번호 대조까지만 한다.
- **§2 과제 폴더와 INTENT.md** — 과제 폴더의 파일 목록, 머리 키, 네 칸과 읽는 규칙(받은 말 안의 제목 줄), 결정 기록의 줄 꼴과 종류 일곱, 「한 번만 짓는다」 표, 「브랜치 하나에 계획 하나」(n 번째 브랜치가 `plan-<n>.md`), 사용자 예시 다섯 줄(펜스 안에 글자 그대로), `update` 의 종료 코드 4 와 손으로 고치는 길, `job new` 의 인자.
- **§3 원자료** — `original.md` 의 구간과 출처 줄 꼴, 덧붙이기만 받는다, `original` 명령과 framing audit 를 찾는 세 길, 세 검사와 `team_layout.py check` 의 종료 코드.
- **§4 sources.md** — 머리, 절 다섯, 사람이 고치지 않고 생성기가 다시 쓴다, 로드맵 블록의 `묶음:` 이 이 파일을 가리킨다, 분해안 표의 「지시 원문 범위」 칸.
- **§6 역할 문서** — 넷과 기본으로 맡는 단계 표, 두 칸뿐, 「역할 문서는 알림이고 막는 것은 도구 권한이다 — 도구로 막는 자리는 지휘 절차 개편(R2)이 정한다」, 없을 때만 깐다, `.claude/` 아래에는 쓰지 않는다.

이 문서는 자기 출처(어느 설계 · 어느 계획이 만들었나)를 적지 않는다. `## 목차` 는 두지 않는다 — `docs/` 밖이라 목차 규칙의 대상이 아니고, Step 1 의 제목 단언이 2단계 제목을 다섯으로 못 박는다. 사용자 예시 다섯 줄은 `## ` 로 시작하는 줄과 함께 펜스 안에 둔다(펜스 밖에 두면 제목으로 읽힌다).

- [ ] **Step 4: README · CHANGELOG · 판을 고친다**

- README `## 로드맵 · 에픽 묶음` 의 `scripts/roadmap_write.py create · update · extract · migrate` 항목 뒤에 항목 둘을 더한다 — `scripts/roadmap_write.py create --layout team · original --brief · job new`(무엇을 만들고, 지휘 절차는 아직 옛 형식을 쓰며 새 형식을 기본으로 켜는 일은 지휘 절차 개편이 한다는 것, 역할 문서는 알림이고 막는 것은 도구 권한이다)와 `scripts/team_layout.py check --roadmap <로드맵>`(종료 코드 0 · 1 · 2 · 3). 형식은 `references/team-files.md` 를 가리킨다. 종료 코드 문단의 `roadmap_write.py` 문장을 「`roadmap_write.py` 는 0 성공 · 1 쓰지 않음 · 2 사용법 오류 · 4 썼고 사람이 고칠 것이 남음(team 형식의 재분해)입니다」 로 고친다.
- README `## Principles Instantiated` 의 Three Laws 목록에 한 줄: `- **Law 1 · Law 3 — 내용마다 집 하나** — 팀 형식은 사용자 원자료를 한 벌(`intent/original.md`)만 두고 과제 파일은 줄 범위로 가리킨다. 옮긴 구간은 출처 커밋과 바이트가 같아야 하고 덧붙이기만 받는다(`scripts/team_layout.py check`). 경로와 이름은 `scripts/team_layout.py` 한 곳에서 나오고 형식은 `references/team-files.md` 가 정본이다.`
- `plugin.json` 판을 `8.14.0` 으로(Task 1 Step 3 에서 판이 달랐으면 그 다음 minor). CHANGELOG 맨 위에 `## [8.14.0] — <오늘 날짜>` 와 `### Added`: `create --layout team` · `original` · `job new` · `team_layout.py check` · 설정 키 `rules_budget` · `handbook_budget` · 로드맵 머리말 `layout` · `update` 의 종료 코드 4 · 틀 일곱. `### Changed`: 역할 이름(`leader` · `designer` · `writer` · `worker`)의 폴더는 로드맵으로 세지 않는다 · 단계 계산이 `layout: team` 과 모르는 `layout` 값에서 검사 불가로 멈춘다(team 형식의 단계 계산은 다음 판).

- [ ] **Step 5: 통과와 락을 확인한다**

Run:
```bash
python3 -m unittest plugins/spec-distill/tests/test_team_docs.py plugins/spec-distill/tests/test_team_layout.py plugins/spec-distill/tests/test_team_files.py plugins/spec-distill/tests/test_review_hook_removed.py
python3 -m unittest plugins/quality-gates/tests/test_utf8_explicit.py
bash shared/tests/test_python_floor.sh; bash shared/tests/test_no_new_duplication.sh; bash shared/tests/test_changelog_integrity.sh; bash shared/tests/test_shell_tests_executable.sh
bash plugins/spec-distill/tests/test_readme_sync.sh; bash plugins/spec-distill/tests/test_check_brief.sh; bash plugins/spec-distill/tests/test_repo_literals.sh
```
Expected: 모두 통과(`test_check_brief.sh` 의 §6 단일화 락이 새 스크립트의 `re.compile` 을 걸지 않는다).

- [ ] **Step 6: 변이로 이빨을 본다 (커밋한 뒤에 흔든다)**

먼저 Step 4 까지를 커밋한다(아래 Step 7). 그 뒤 변이마다 한 줄을 바꾸고 → 해당 테스트가 빨개지는지 보고 → `git checkout HEAD -- <파일>` 로 되돌리고 `git diff HEAD --stat` 이 비었는지 확인한다. `PYTHONDONTWRITEBYTECODE=1` 로 돈다.

| 변이 | 빨개져야 하는 것 |
|---|---|
| `team_write.py` 에 `"jobs/"` 글자를 한 줄 더한다 | `test_team_layout.py` `LiteralsLiveInOnePlace` |
| `_roadmap_shape` 의 역할 이름 거절을 지운다 | `test_roadmap_model.py` `test_role_folders_are_not_roadmaps` |
| `merge_layers` 가 로드맵 층의 `rules_budget` 을 빼지 않게 한다 | `test_repo_defaults.py` `test_roadmap_layer_ignores_and_warns` |
| `check_tree` 의 출처 대조에서 견줌을 늘 참으로 | `test_team_write.sh` 「글자 하나를 바꾼다」 |
| `check_tree` 의 범위 검사에서 `a ≤ b` 를 뺀다 | `test_team_write.sh` 「9–3」 |
| 덧붙이기 검사를 건너뛴다 | `test_team_write.sh` 「첫 줄을 지운다」 |
| `update_files` 가 있던 INTENT.md 를 다시 쓰게 한다 | `test_team_write.sh` 「INTENT.md 는 바이트 그대로」 |
| `intent_sections` 가 `## 하지 않을 것` 을 처음 나오는 줄로 읽게 한다 | `test_team_files.py` `test_task_original_is_byte_exact_even_with_heading_lines` |
| `seed_common` 이 있는 파일도 쓰게 한다 | `test_team_write.sh` 「그 둘은 바이트 그대로」 |
| `roadmap_status.build` 의 team 갈림을 지운다 | `test_team_status_stub.sh` 「검사 불가(3)」 |
| `role-worker.md` 첫 줄 위에 설명 문장 한 줄을 더한다 | `test_team_files.py` `test_role_templates_have_two_sections_only` |

살아남는 변이가 있으면 그 테스트를 고쳐 다시 커밋한다.

- [ ] **Step 7: 커밋**

```bash
git add -- plugins/spec-distill/references/team-files.md plugins/spec-distill/tests/test_team_docs.py plugins/spec-distill/README.md plugins/spec-distill/CHANGELOG.md plugins/spec-distill/.claude-plugin/plugin.json
git commit -m "docs(spec-distill): 팀 파일 형식 정본 문서와 8.14.0" -m "Spec: docs/superpowers/specs/2026-11-14-team-file-contract-design.md"
```

- [ ] **Step 8: 전체 스위트를 한 번 돈다**

Global Constraints 의 공유 잠금 줄로 `bash tools/suite/run-all.sh` 를 돈다.
Expected: `FAILED` 줄이 없다. worktree 에서만 떨어지는 기존 실패(`TestCrossResolverAdvisory`)가 보이면 이 브랜치의 변경 전 커밋에서도 떨어지는지 확인해 「기존 실패」 로 보고하고, 그 밖의 실패는 고친다.

---

## 마지막 전체 리뷰 (실행 방식 공통)

고른 실행 방식의 마지막 전체 리뷰에 설계문서 `## Acceptance Criteria` 의 AC 목록(AC1–AC31)을 싣고, 리뷰가 AC 마다 한 줄씩 `AC1: 구현됨 — 근거` 꼴(판정은 구현됨 · 미룸 · 빠짐 가운데 하나)로 보고하게 한다. 이 계획의 몫은 AC1 · AC2 · AC3 · AC4 · AC5 · AC6 · AC7 · AC8 · AC18 · AC26(계획 1 몫)이고, 나머지는 「미룸 — 계획 2」 또는 「미룸 — 계획 3」 이다(설계 §14 의 나눔). AC12 는 이 계획이 당겨 구현했다(P5) — 「구현됨」 으로 보고하고 계획 2 가 team 갈림을 실제 계산으로 바꾼다고 적는다.

리뷰에 함께 묻는 것:

- 끝에서 끝 — `original` → `create --layout team` → `team_layout.py check` → `extract` → `update` → `job new` 가 한 임시 레포에서 이어지는가. 각 명령의 종료 코드를 다음 걸음이 어떻게 읽는가(특히 4).
- 옛 형식 — `--layout` 없는 `create` · `update` · `extract` · 단계 계산의 출력이 변경 전과 같은가(있는 테스트를 고친 곳은 `test_repo_defaults.py` 의 키 수 하나뿐이어야 한다).
- 계획이 적어 준 테스트 코드 자체 — 단언이 통과가 정답인 꼴뿐이라 이빨이 없는 곳, 픽스처가 분기 하나를 통째로 가리는 곳(예: 범위가 늘 한 조각뿐, 출처가 늘 LF).
- 「설계에 없던 결정」 P1–P14 가 코드와 문서에 그대로 반영됐는가.

그 보고를 git 이 추적하지 않는 파일(지휘자가 준 임시 폴더)에 적는다. 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올리고, PR 을 만들기 전에

```bash
python3 <spec-distill>/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-14-team-file-contract-design.md <보고 파일> --acs "AC1~AC8 · AC18 · AC26"
```

를 돌려 경고를 사용자에게 보인다. 사람에게 쓰는 글은 첫 줄에 상태, 번호 · 해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 끝에 할 일(기본 하나)을 둔다.
