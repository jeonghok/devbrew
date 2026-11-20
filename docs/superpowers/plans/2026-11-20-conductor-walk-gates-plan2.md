# 지휘 걸음과 관문 — 계획 2(걸음표 · 담당자 보내기 · 사용자 자리 · P8) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** team 형식 로드맵의 걸음을 마크다운 표 한 장(걸음표)으로 세워 리더가 `walk_table.py next` 로 지금 걸음 · 다음 걸음 · 막는 것을 받게 하고, 담당자는 시작 묶음 명령 한 줄과 고정 꼬리로만 보내며, 지휘 절차 · 승인 게이트 · 역할 문서 · 리뷰 프로필 · P8 을 그 길에 맞추고, 계획 1 이 남긴 판정 구멍(물러선 승인 · 판 커밋 · 둘째 브랜치 · 받음 줄 낡음)과 작은 잔여를 닫는다.

**Architecture:** 새 모듈 하나(`scripts/walk_table.py`)와 새 표 파일 하나(`references/walk-table.md`)다. `walk_table.py` 는 표를 읽어 검사하고(`check`), 상태 계산(`roadmap_status.build` · `team_status.Reader.progress`)과 사람 줄의 꼴 판정(`human_lines.missing(..., deep=False)`)을 빌려 걸음을 고른다(`next`) — 관문은 표에서 읽지 않는다(`human_lines.GATES` 고정). 사람 줄 판정의 고침은 `human_lines.match` · `conductor_ledger.c_human_check` · `job_results.receipt` 의 자리 고침이다. 나머지는 문서(지휘 절차 · 보내는 글 틀 · 승인 게이트 · 역할 문서 틀과 사본 · 리뷰 프로필 · 철학 · CLAUDE.md · 형식 정본 · README · CHANGELOG)와 그 락이다. 옛 형식 로드맵의 명령 · 글 · 틀은 건드리지 않는다.

**Tech Stack:** Python 3(레포의 `python3` 는 3.9.6 — 3.9 문법만) · git · bash(macOS 3.2 호환) · unittest · 기존 셸 테스트 도구(`shared/tests/assert.sh` · `plugins/spec-distill/tests/fixtures/team_repo.sh` · `plugins/spec-distill/tests/fixtures/session_fixture.py`).

**Spec:** `docs/superpowers/specs/2026-11-18-conductor-walk-gates-design.md` — 이 계획은 그 문서가 나눈 둘 가운데 **계획 2** 다. 계획 1(`docs/superpowers/plans/2026-11-19-conductor-walk-gates-plan1.md`, PR #305 머지)이 사람 줄과 관문을 만들었다. 아래에서 경로는 따로 적지 않으면 `plugins/spec-distill/` 아래다.

## AC 가르기

설계문서 `## Files to Modify` 의 「계획」 칸 · 「계획 나누기」 문단 · `## 미룸` 표의 받는 곳이 R2 인 행 · 계획 1 의 `## AC 가르기` 표로 갈랐다.

| AC | 몫 | 계획 1 이 한 부분 | 계획 2 가 하는 부분 · 과제 |
|---|---|---|---|
| AC1 · AC2 · AC17 · AC18 · AC19 | 계획 2 | — | 전부 — 과제 3 · 4(AC1 · AC2 · AC17 의 걸음 보기) · 13(AC17) · 14(AC18) · 15(AC19) |
| AC9 | 걸침 | 시작 묶음 관문 전부 · 관문 표가 상수이고 설정으로 안 바뀐다는 테스트 | 걸음표의 관문 칸을 비워도 관문이 그대로라는 테스트 — 과제 4 |
| AC11 | 걸침(미룸 표) | 대조 판정 전부 | 미룸 표가 더한 조건 둘 — 「그 머리의 가장 뒤 답이다」 · 「줄의 판 커밋이 그 파일을 실제로 고쳤다」 — 과제 5 |
| AC15 | 걸침 | 기본 역할(계획 worker · 설계 leader) · 설계 단계 묶음의 leader 역할 | 역할 문서 틀과 이 레포의 사본에서 할 일 옮기기 — 과제 11 |
| AC16 | 걸침 | 「맞추는 명령」 줄을 그대로 돌릴 수 있게 | 보내는 글 틀 · 고정 꼬리(과제 12) · 지휘 절차의 보내기 걸음(과제 13) |
| AC20 | 걸침 | `human_gate` | `walk_table` 키 — 과제 2 |
| AC21 | 걸침 | 옛 형식의 승인 줄 명령 · 단계 계산 | 옛 형식의 보내는 글 틀이 그대로다 — 과제 12 |
| AC22 | 걸침 | 사람 줄 · 관문 · `human_gate` · 기본 역할 · 세션 기록 사실 | 걸음표 · `walk_table` — 과제 16 |
| AC23 | 걸침 | `human-check` 명령 | 지휘 절차가 PR 전 확인에서 그 출력을 그대로 보인다고 적기(과제 13) · 계획이 둘 이상인 과제에서 계획 번호 없는 줄을 머지되지 않은 브랜치 끝 모두에서 판정하기(미룸 표 — 과제 7) |
| AC3 – AC8 · AC10 · AC12 – AC14 | 계획 1 | 전부 | — (과제 9 · 10 이 계획 1 리뷰 잔여의 테스트를 더할 뿐 동작은 바꾸지 않는다) |

AC 번호가 없는 미룸 행도 이 계획이 받는다 — 받음 줄의 낡음을 본문으로(과제 8) · 시작 묶음 종료 코드 1 과 3 의 경계(과제 10) · 고른 라벨의 꼬리 규칙(과제 6 — 사용자 2026-11-20 「넷 모두 권장대로」 · (가)) · 통과 라벨 락에 `skills/spec-review/SKILL.md`(과제 13) · 계획 1 리뷰 잔여(과제 9 · 10) · 계획 1 의 J20(과제 13).

리뷰 잔여 가운데 받는 과제가 없는 한 줄 — `job_results.py` 의 「빈 「끝」 판정이 줄 앞머리 훑기다 · 다시 시도 이름을 따로 정규식으로 읽는다」. 앞쪽은 기존 테스트(`tests/test_job_results.sh` 141–142행의 빈 끝 거절 · `tests/test_team_results.py` 382행의 빈 끝 연속 실패)가 이미 동작을 못 박아 더할 것이 없고, 뒤쪽은 미룸 468행(E1 — 관문 이름 정규식 다섯 곳을 한 곳으로)에 든다. 과제 10 의 이름 왕복 테스트가 그때까지 두 정규식이 같은 답을 내는지 잰다.

대조 스크립트에 주는 목록: `AC1 · AC2 · AC9 · AC11 · AC15~AC23`.

## Global Constraints

- **team 형식에서만.** 걸음표 · 걸음 보기 · 새 보내는 글 틀 · 지휘 절차의 새 절은 머리말이 `layout: team` 인 로드맵에만 닿는다. 옛 형식 로드맵의 명령 · 출력 · 보내는 글 틀(`references/conductor-dispatch.md` 의 `### 계획 agent` · `### 구현 agent` · `### 이어 부르기`) · 지휘 절차의 지금 문장은 diff 가 없어야 한다(AC21). 지휘 절차(`references/conducting.md`)에는 새 절과 「team 형식이면 그 절」 을 가리키는 새 줄만 더한다 — 있는 줄은 고치지 않는다.
- **걸음표의 칸(글자 그대로).** `걸음` · `누가` · `단계` · `관문` · `작업 방식` · `상한` · `도구` 일곱, 이 차례. 빈 칸은 `—` 다(빈 글자도 `—` 로 읽는다). 두 표의 절 제목은 `## 설계 흐름` · `## 설계 없는 흐름`(`team_status.DESIGN_FLOW` · `team_status.PLAIN_FLOW` 의 글자).
- **기본 표의 행(설계 §1 그대로).** 설계 흐름 열한 걸음 — 방향 확인 · 설계 대화 · 설계 검토 · 설계 승인 · 계획 · 계획 확인 · 구현 · 검수 · PR 전 확인 · 머지 · 회고. 설계 없는 흐름 세 걸음 — 방향 확인 · 진행 · 결과 확인. 칸 값은 설계 §1 의 두 표에서 글자 그대로 옮긴다.
- **관문은 표에서 읽지 않는다.** 걸음 보기의 「막는 것」 도 `human_lines.GATES` · `human_lines.PLAIN_GATES` 로 센다. 표의 관문 칸은 보여 주기다(설계 §1 · §3).
- **통과 라벨(글자 그대로 — 계획 1 과 같다).** `spec 승인` → 「승인 — 계획 담당자에게」 · `계획 검토` → 「계획대로 구현한다」 · `흐름 승인` → 「설계 없이 진행」 · `걸음 건너뜀` → 「건너뛴다」 · 「다시 시도한다」.
- **질문 머리.** `<과제 번호> @<판>` · `계획 검토` 는 `<과제 번호> plan <n> @<판>` — `conductor_ledger.py ask-head` 가 낸다.
- **설정 키.** `walk_table` 은 레포 설정 파일(`.devbrew.md`)에서만 받는다(로드맵 머리말이면 오류 — `human_gate` 와 같다). 값은 레포 상대 파일 경로이고 기본은 없음(플러그인 기본 표). 파일은 설정 파일처럼 기본 브랜치(`origin/HEAD`)의 커밋에서 읽는다. 깨졌으면 기본 표로 넘어가지 않는다.
- **종료 코드.** `walk_table.py`: 0 냈다 · 2 사용법(인자 · team 형식이 아님 · 모르는 과제) · 3 검사 불가(표가 깨짐 · 표 파일이 기본 브랜치에 없음 · 레포 설정 오류 · 과제의 단계가 「알 수 없음」 · git 읽기 실패). 0 이 아니면 표준 출력은 비고 사유는 표준 오류의 한 줄(`[spec-distill] 사용법 오류 — …` · `[spec-distill] 검사 불가 — …`)이다.
- **상태 계산의 잠금 목록.** `walk_table.py` 는 상태 계산(`roadmap_status.py`)이 가져오지 않는다 — `tests/test_roadmap_status.sh` 의 정적 검사 목록과 `control_plane.CODE_STAMP_FILES` 에 넣지 않는다. 그래도 읽기만 한다(쓰기 · `subprocess` 직접 호출 없음 — git 은 `roadmap_status.Git` 으로). 과제 3 의 `ReadOnly` 테스트가 AST 로 잰다. docstring · 주석에도 `jobs/` · `intent/` · `results/` · `RULES.md` · `HANDBOOK.md` 같은 꼴 글자를 쓰지 않는다(`tests/test_team_layout.py` 의 `LiteralsLiveInOnePlace` 가 `scripts/*.py` 를 전수로 훑는다).
- **레포 락.** `plugins/**/*.py` 에 `"python3"` 따옴표 리터럴 금지(`shared/tests/test_python_floor.sh`) · 스크립트의 `open(` · `.read_text(` 에 `encoding` 필수(주석의 `open(` 도 걸린다 — `plugins/quality-gates/tests/test_utf8_explicit.py`) · `re.compile` 리터럴이 `## ` 로 시작하는 글과 3글자 이상 맞으면 RED(`tests/test_check_brief.sh` — 걸음표의 절 제목은 정규식이 아니라 문자열 비교로 가른다) · 같은 20줄(200자 이상) 블록이 두 파일에 있으면 RED(`shared/tests/test_no_new_duplication.sh`) · 새 셸 테스트는 100755 로 커밋한다(`git ls-files -s` 로 확인 — 아니면 품질 게이트가 세지 않는다) · CHANGELOG 새 머리는 바로 다음 판만(`shared/tests/test_changelog_integrity.sh`) · 역할 문서 틀은 `tests/test_team_files.py` 의 `Templates` 규칙(두 칸 · 글머리만 · 첫 셋 공통 줄 · 리더 틀의 할 일 끝 줄은 규칙 검사 줄 · 「알림」 · 「도구 권한」 · 「집행」 · 「이 문서」 금지)을 지킨다.
- **정규식은 `fullmatch`.** 줄 꼴 · 칸 값은 `re.fullmatch` 나 글자 비교로 본다.
- **bash 3.2.** `set -u` 아래 빈 배열은 `${arr[@]+"${arr[@]}"}` · `$var` 바로 뒤에 한글이 오면 `${var}`.
- **변이.** 변이는 커밋한 뒤에 한다. `PYTHONDONTWRITEBYTECODE=1` 로 돌리고, 되돌림은 `git checkout HEAD -- <파일>` 뒤 `git diff HEAD --stat` 이 비었는지로 확인한다. 통과가 정답인 단언(「없다」 · 「그대로다」)에는 양성 대조를 짝으로 둔다. 계획에 적힌 테스트마다 「붉어질 변이」 를 적었다 — 과제 보고에 그 변이를 실제로 돌려 붉어진 단언 이름을 적는다.
- **설계문서는 고치지 않는다.** 설계의 글자 · 수용 기준 · 사용자에게 보이는 동작을 더하거나 바꿔야 한다고 보면 멈추고 지휘자에게 돌려보낸다. 이 계획이 스스로 정한 것은 `## 계획의 판단` 에 있고, 설계문서에 적을 글의 제안은 지휘자가 사용자에게 확인받는다.
- **판.** spec-distill 을 **minor** 로 올린다. 번호는 머지 직전 기본 브랜치(`origin/main`) 위의 다음 minor 다 — 상태 브랜치 계획(R3 계획 1)이 8.26.0 으로 먼저 머지되면 8.27.0 이다. 테스트는 판 번호 리터럴에 기대지 않는다 — `.claude-plugin/plugin.json` 의 판으로 CHANGELOG 절을 고른다(과제 16).
- **커밋.** 한국어 Conventional Commits(type · scope 는 영어), pathspec 으로 커밋한다. `git stash` · HEAD 뒤로 옮기기(reset · rebase · force) · 다른 worktree 의 git · push 를 하지 않는다. 테스트가 임시 레포 안에서 ref 를 옮기는 것은 된다.
- **개인 정보.** 세션 기록 · 사용자 대화에서 테스트 자료 · 문서 · 커밋 메시지로 옮기는 것은 칸 이름 · 꼴 · 열거된 값뿐이다. 질문 글 · 답 글은 자리표시 글자로 쓴다.
- **전체 스위트**는 아래 줄로만 돈다(지휘자 대조와 같은 공유 잠금 — 기다림은 줄이고, 못 잡으면 주인 · 잡은 시각을 보고한다. `--owner` 는 도는 agent 의 이름으로 바꾼다). 과제 안에서는 그 과제가 이름 댄 테스트만 돈다. 구현 담당이 하위 agent 를 띄우면 그 글에도 이 줄과 경로를 그대로 싣는다:
  `python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.19.2"/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-conductor-context-economy-brief/files/suite-lock --owner <도는 agent 이름> --wait 7200 -- bash -c 'bash tools/suite/run-all.sh'`

## Review Focus

설계가 뜻하지만 어느 수용 기준도 이름 대지 않는 입력이다. 줄마다 그 코드를 가진 과제에 테스트가 있다.

1. **레포가 고친 걸음표에 설명 글 · CRLF · 앞뒤 공백 · 빈 칸이 섞인 경우** — 절 밖의 글과 빈 줄은 건너뛰고, 칸은 앞뒤 공백을 떼고, 빈 칸은 `—` 로, 줄 끝 `\r` 은 떼고 읽는다. 표 행의 칸 수가 일곱이 아니면 그 줄 번호를 짚고 3 이다(과제 3).
2. **`walk_table` 이 가리키는 파일이 기본 브랜치에 없거나 · 링크이거나 · 작업 트리에만 있는 경우** — 기본 표로 넘어가지 않고 3 과 사유(「기본 브랜치에 없다」 · 「일반 파일이 아니다」)를 낸다. 작업 트리에만 있으면 기본 브랜치의 판이 기준이라 「없다」 다(과제 3).
3. **과제의 브랜치가 갈라졌거나 단계가 「알 수 없음」 인 경우** — 걸음을 짐작해 내지 않고 3 과 상태 계산의 사유를 낸다(과제 4).
4. **로드맵 밖 과제(`kind: task`)를 `--job` 으로 준 경우** — 블록이 없다고 2 로 멈추지 않고 설계 없는 흐름의 표로 걷는다. 「계획 n/m」 의 m 은 상태 보고가 센 브랜치 수다(과제 4 의 b10 · w1).
5. **같은 머리로 「승인」 을 두 번 고른 경우(다시 물어 다시 승인)** — 앞 답을 가리키는 줄도 그대로 지난다. 물러선 답(라벨이 다른 더 뒤 답)만 앞 줄을 막는다(과제 5).

---

## 계획의 판단

설계가 정하지 않아 이 계획이 정한 것이다 — 「설계에 없던 결정」. 범위 · 인터페이스 · 파일 배치 · 사용자에게 보이는 글과 동작에 닿는 것을 모두 적었다. 설계문서의 글자를 바꿔야 하는 것(✎ 표시)은 사용자 확인(2026-11-20 「넷 모두 권장대로」 · 「계획대로 구현한다」) 뒤 설계문서에 적었다(커밋 d687916a). 고르지 않은 길은 다른 길 칸에 기록으로 남긴다.

| # | 자리 | 정한 것 | 이유 | 다른 길 |
|---|---|---|---|---|
| K1 | 걸음표 파일의 꼴 | 첫 줄 `# 걸음표`, 절 제목 `## 설계 흐름` · `## 설계 없는 흐름`(각 한 번), 그 아래 머리 행이 일곱 칸 이름과 같은 마크다운 표. 절 밖의 줄 · 표 앞뒤의 빈 줄 · 설명 글은 건너뛴다. 걸음 이름은 절 안에서 겹치지 않는다. 각 절에 걸음이 하나 이상 | 사람이 읽고 고치는 파일이라 설명 글을 허용하되 표의 꼴은 엄격하게 본다 | 표 밖의 줄도 오류로 |
| K2 | 검사가 보는 칸 | `단계`(`team_layout.STAGES` 이거나 `—`) · `관문`(`human_lines.KINDS` 이거나 `—`) · 칸 수 · 머리 행 · 이름 겹침 · 절 유무. `누가` 는 검사하지 않는다 | AC1 이 두 칸을 꼽았다. 누가 칸을 무엇으로 돌리나는 E1 몫(미룸)이라 값을 닫지 않는다 | 누가 칸도 역할 이름 · 「사람」 으로 닫는다 |
| K3 | `walk_table.py` 의 명령 | `check [<파일>]`(인자가 없으면 걸음 보기가 쓸 표, 있으면 작업 트리의 그 파일을 검사) · `next --roadmap <로드맵> --job <과제>`. 표를 그대로 찍는 명령은 두지 않는다 | 레포가 자기 표를 머지하기 전에 검사할 길이 필요하다 | `show` 를 더한다 |
| K4 | 걸음 보기가 걸음을 찾는 법 | **걸음 이름이 닻**이다 — 자취마다 기본 표의 이름 묶음(아래 과제 4 의 표)이 지금 걸음이다. 레포 표에서 기본 이름이 아닌 행은 바로 앞의 닻 행과 같은 묶음으로 낸다(설계 §1 「레포가 더한 걸음은 묶어서」). 지금 묶음의 닻 이름이 레포 표에 없으면 3(「걸음표에 <이름> 걸음이 없어 지금 걸음을 가를 수 없다」). `check` 는 닻 이름이 빠진 표에 `알림:` 줄을 내고 0 이다 | 자취가 가리키는 자리를 표의 구조(단계 · 관문 칸)로만 찾으면 검수 · PR 전 확인 · 머지를 가를 표지가 없다 | 단계 · 관문 칸을 표지로 자리를 찾는다 |
| K5 | 「PR 이 열렸으면 머지」 를 아는 길 | 지휘 기계 상태의 PR 캐시(`roadmap_status.read_pr_cache`)에 그 계획 브랜치의 줄이 상태 `열림` 이면 머지. 캐시를 읽지 못하면 검수 · PR 전 확인 · 머지를 한 묶음으로 내고 `알림:` 줄에 사유를 싣는다 | 상태 계산과 같은 원천이다. gh 를 새로 부르지 않는다 | gh 로 PR 을 묻는다 |
| K6 | 「막는 것」 이 세는 것 | 둘 — 블록이 「대기」 면 그 사유(의존 미완료), 다음 걸음의 **닻 이름에 고정된 단계**(`walk_table.ANCHOR_STAGES` — 레포 표의 단계 칸은 보여 주기다, H2)가 있으면 그 단계의 관문 표 줄 가운데 꼴 판정을 지나지 못한 첫 줄(`human_lines.missing(..., deep=False)` 의 첫 사유). 연속 실패 멈춤 · 머지된 계획 멈춤은 세지 않는다 — 시작 묶음이 멈추고 사유를 낸다 | 설계 §1 · 「계층과 온톨로지」 가 걸음 보기를 꼴 판정 자리로 적었다. 세션 기록을 읽지 않는다 | 연속 실패도 센다 |
| K7 | 걸음 보기의 출력 꼴 | 아래 과제 4 의 여섯 줄(`알림:` · `표:` · `흐름:` · `지금 걸음:` · `다음 걸음:` · `막는 것:`). `계획 n/m` 은 m 이 2 이상일 때만 `흐름:` 줄에 붙는다. 꺼짐 알림은 첫 줄이다 | AC2 의 「한 줄씩」 · AC20 의 「관문 출력의 첫머리」 를 걸음 보기에도 | 꺼짐 알림을 싣지 않는다 |
| K8 | 계획 n 이 머지됐고 n < m 이며 계획 n+1 의 브랜치가 아직 없을 때 | 지금 걸음 `머지 (계획 n — 끝남)` · 다음 걸음 `계획 (계획 n+1)` | 설계 §1 은 다음 걸음만 정했다 | 지금 걸음을 비운다 |
| K9 | 「그 머리의 가장 뒤 답」(AC11 · 미룸) ✎ **사용자 2026-11-20 「넷 모두 권장대로」 — ①** | ① 근거가 가리키는 답보다 **뒤에** 같은 기록 파일에 같은 물음의 답이 있고 그 라벨(꼬리를 뗀 것)이 줄의 라벨과 다르면 `어긋남`(「그 머리로 더 뒤에 고른 답이 있다(「<라벨>」) — 다시 묻고 가장 뒤 답으로 적는다」). 「같은 물음」 — 같은 머리로 시작하고: `spec 승인` · `계획 검토` 줄은 **관문 이름으로 거르지 않고** 고른 라벨이 건너뜀 · 다시 시도 라벨(「건너뛴다」 · 「다시 시도한다」)인 답만 뺀다(「<머리> — spec 승인 다시 확인」 에 「수정 필요」 를 고른 답도 같은 물음이다) · `흐름 승인` 줄은 관문 이름을 쓴 질문(건너뛰기 질문 — INTENT.md 판 머리를 함께 쓴다)을 뺀다 · `걸음 건너뜀` 줄은 같은 관문 이름을 쓴 질문만이다. 사람이 아니라고 잰 답(`NOT_HUMAN`)은 세지 않는다. 사람인지 모르는 답(`UNKNOWN`)은 `확인 못 함` | 미룸 행이 막으려는 것은 승인 뒤의 「수정 필요」 다. 같은 라벨을 다시 고른 답까지 막으면 다시 물을 때마다 앞 줄이 `human-check` 에서 붉어진다(Review Focus 5). spec · 계획 검토 줄에 관문 이름 거르기를 쓰면 리더가 「spec 승인」 이라는 낱말을 넣어 다시 물은 「수정 필요」 를 놓친다(검수 지적) | ② 글자 그대로 — 라벨과 상관없이 같은 물음의 가장 뒤 답만 지난다(다시 승인할 때마다 앞 줄이 `human-check` 에서 `어긋남` 이 된다). 어느 길이든 관문 이름 거르기 고침은 같다 |
| K10 | 「줄의 판 커밋이 그 파일을 실제로 고쳤다」(AC11 · 미룸) ✎ | `git log -1 --format=%H <판 커밋> -- :(top,literal)<파일>` 의 출력이 판 커밋 자신이 아니면 `어긋남`(「줄의 판 <판> 은 <파일> 을 고친 커밋이 아니다」). git 이 실패하면 `확인 못 함`. 꼴 판정(`shape`)이 아니라 대조 판정(`match`)에 둔다 | `ask-head` 의 판(`human_lines.version`)도 같은 `git log` 길에서 나와 진짜 줄은 늘 지난다. 미룸 행이 「대조 판정에」 라고 적었다 | 꼴 판정에도 둔다(단계 계산이 git log 를 한 번 더 부른다) |
| K11 | 고른 라벨의 꼬리 규칙(미룸) ✎ **사용자 2026-11-20 「넷 모두 권장대로」 — (가)** | 과제 6 이 (가)를 실행한다 — `human_lines.clean_label` 이 「(권장)」 · 「(Recommended)」 둘 가운데 끝에 붙은 하나를 뗀다 | 승인 게이트(`references/proceed-gate.md` 와 다른 skill 들)는 두 꼬리를 떼고 읽는다. 지금은 「(Recommended)」 가 붙은 승인 답을 게이트는 승인으로 읽는데 `record --human` 은 거절한다(닫는 쪽) | (나) 지금대로 「(권장)」 하나 — 문서에 어긋남을 적는다 · (다) 게이트도 「(권장)」 하나만 — 다른 skill 의 읽기 규칙 여럿을 고친다 |
| K12 | `human-check` 의 계획 번호 없는 줄(미룸) | `spec 승인` · `흐름 승인` · 계획 번호 없는 `걸음 건너뜀` 줄은 머지되지 않은 브랜치 끝 **모두**(끝이 같은 브랜치는 한 번)에서 대조 판정하고, 브랜치 차례로 첫 `지남` 아닌 판정을 낸다. 사유 앞에 `<브랜치> 끝에서: ` 를 붙인다. 머지되지 않은 끝이 없으면 지금처럼 기본 브랜치. 「줄 없음」 절은 고치지 않는다 | 미룸 행 — 둘째 브랜치에서 승인 뒤 고친 설계가 PR 전 점검에 드러나지 않는다. 시작 묶음은 그 계획의 브랜치 끝으로 「낡음」 을 낸다 | 브랜치마다 한 줄씩 낸다 |
| K13 | 받음 줄의 낡음(미룸) | `job_results.receipt` 가 받은 뒤 바뀐 파일로 센 경로마다 받은 head 와 지금 끝의 글을 견준다 — 설계 파일 · 계획 파일 · INTENT.md 는 `human_lines.body_of` 의 본문으로, 그 밖은 글 전체로. 같으면 세지 않는다(없음 · 없음도 같다) | 미룸 행 — 받은 뒤 미룸 절만 고치거나 고쳤다 되돌려도 「받은 뒤 바뀜」 이다 | 설계 파일만 본문으로 |
| K14 | 역할 문서의 「묶음 명령이 실패했을 때의 할 일」 | 네 틀 모두의 넷째 공통 줄로 둔다 — `- 시작 묶음 명령이 0 이 아닌 종료 코드로 끝나면 일하지 않고 그 사유를 돌려보낸다.` | 설계 §5 의 고정 꼬리 문장과 같은 글. 묶음을 돌리는 것은 네 역할 모두다 | worker 틀에만 |
| K15 | 역할 문서의 새 할 일 글 | leader — `- 설계 걸음에서는 원자료(`intent/original.md`) 전체를 읽고 설계문서의 원문 대조 표부터 채운다.` · `- 원자료와 다르게 바꾼 것은 근거를 적거나 「작성자 제안」으로 표시한다.` · `- 혼자 정해 둔 것은 설계문서를 쓰기 전에 목록으로 보이고 하나씩 답을 받는다.`, 하지 않을 일에 `- 원자료를 풀어 다시 쓰기` · `- 계획 · 구현을 직접 하기(한 문장으로 설명되는 작은 고침만 한다)`. worker — `- 계획 걸음에서는 승인된 설계로 계획을 쓰고, 설계에 없던 결정은 표시해 리더에게 돌려보낸다.` · `- 설계의 글자 · 수용 기준 · 사용자에게 보이는 동작에 닿는 물음은 스스로 정하지 않고 멈춰 돌려보낸다.`. designer — 설계 걸음의 두 줄과 `원자료를 풀어 다시 쓰기` 를 뺀다. 디자인 일의 새 줄은 더하지 않는다(공통 줄과 `승인 전에 다음 단계로 가기` 만 남는다) | 설계 §1 「역할」 · §6. 디자인 일의 할 일은 디자이너를 보내는 길(E1)이 생길 때 정한다 | designer 에 디자인 일 줄을 지어 넣는다 |
| K16 | 보내는 글 틀의 고정 꼬리에 더한 자리표시 | `<작업 방식>`(걸음 보기의 다음 걸음 작업 방식 칸) · `<설계 파일>`(설계 파일 경로 — `Spec:` 트레일러와 계획 대조 명령). 그 밖의 자리표시는 자리 · 잠금 · 임시 폴더뿐이다 — 과제를 설명하는 칸은 없다 | 설계 §5 첫 글머리 「그 출력의 누가 · 작업 방식을 쓴다」 · 품질 게이트가 `Spec:` 트레일러로 의도 출처를 읽는다. 작업 방식의 출처는 H11 | 작업 방식을 역할 문서가 정한다 |
| H1 | 지금 걸음과 다음 걸음 가운데 어느 칸으로 보내나 ✎ **사용자 2026-11-20 「넷 모두 권장대로」 — (가)** | (가) 관문을 지났는데 담당자의 결과가 아직 없는 걸음은 「다음 걸음」 으로 낸다. 지금 걸음은 K8 과 같은 꼴(「설계 승인 (끝남)」 · 「계획 확인 (끝남)」 · 「방향 확인 (끝남)」)로 쓴다. 보내는 법은 늘 「다음 걸음의 칸으로」 하나다(과제 4 의 표 · w4 · w6 · w12) | 설계 §1 의 자취 문장(「계획」 이고 계획 파일이 없으면 「계획」)과 §5(다음 걸음으로 보낸다)가 부딪힌다 — 그대로면 승인 직후 출력의 다음 걸음이 「계획 확인」 · 「검수」 · 「결과 확인」 이라 보낼 담당자 칸이 없다(검수 지적) | (나) 자취 문장 그대로 두고 지금 걸음 줄에도 칸을 붙여, 절차를 「지금 걸음이 담당자 걸음이고 결과가 없으면 지금 걸음의 칸으로, 아니면 다음 걸음의 칸으로」 로 쓴다 · (다) 「보낼 걸음:」 줄을 따로 둔다(지금 · 다음 두 줄은 자취 그대로) |
| H11 | 구현 작업 방식의 출처 ✎ **사용자 2026-11-20 「넷 모두 권장대로」 — ①** | ① team 형식에서는 걸음표의 작업 방식 칸이 이긴다(레포가 자기 걸음표로 바꿀 수 있다). writing-plans 끝의 실행 방식 질문은 사용자에게 띄우지 않고 그 칸으로 답한다 — 새 틀(과제 12 의 5번 줄)과 지휘 절차의 team 절(과제 13)에 「작업 방식은 걸음 보기가 낸 칸이다. 계획 skill 이 끝에 묻는 실행 방식은 그 칸으로 답한다」 | 옛 흐름은 writing-plans 가 권하고 사용자가 고른 실행 방식(subagent-driven · native)을 썼다(`conductor-dispatch.md` 26 · 71행). team 형식의 새 틀은 걸음표 칸에서 채워 사용자 답이 닿을 길이 없다(검수 지적) | ② 계획 확인 질문에 실행 방식을 함께 묻고 답을 결정 기록에 적어 표 칸을 덮는다 · ③ 표 칸은 기본값이고 writing-plans 질문의 답이 이긴다 |
| H2 | 막는 것의 단계를 어디서 읽나 | 닻 이름에 고정된 단계(`ANCHOR_STAGES`). 레포 표의 단계 칸은 보여 주기다 | 레포 표가 다음 걸음 행의 단계 칸을 `—` 로 바꾸면 「막는 것: 없음」 이 나와 리더가 보내게 된다(시작 묶음은 그대로 막지만 출력이 틀린다) | 표의 단계 칸을 읽는다 |
| H3 | 「계획 n/m」 의 n | 머지되지 않았고 끝이 있는 첫 브랜치의 차례. 그런 브랜치가 없으면 — 머지된 것도 없으면 1, 있으면 가장 뒤 머지된 브랜치의 차례(모두 머지면 m) | w1(브랜치 없음 → 1/2)과 w9(계획 1 머지 · 계획 2 브랜치 없음 → 1/2)가 둘 다 맞게 | n = 머지된 수 + 1 |
| K23 | 새 틀이 싣는 단계별 지시(옛 틀이 싣던 것) | 고정 꼬리에 단계 조건 줄 둘 — 계획 걸음이면 「첫 과제는 가벼운 다시 확인 · 계획을 커밋한 뒤 `check_bundle_coverage.py --plan`(계획을 나눴으면 이 계획 몫 AC 를 설계의 계획 나누기에서 정해 `--acs`)」, 구현 걸음이면 「마지막 전체 리뷰의 AC 보고 · 이음매 · 계획이 쓴 테스트 · 있는 것 검토」. 마지막 보고는 `"<SD>"/references/conductor-dispatch.md` 의 `## 마지막 보고` 를 경로로 가리킨다 | 리더가 과제를 설명해 채우는 칸을 만들지 않고 실을 자리는 고정 꼬리뿐이다 — 역할 문서는 단계마다 갈리지 않고, 묶음은 그 글을 싣지 않는다 | 역할 문서(worker)에 싣는다 · 시작 묶음이 단계마다 싣는다(스크립트를 고친다) |
| K24 | 걸음표 모듈의 예외 | `walk_table.Usage = team_rules.Usage` · `walk_table.Unchecked = team_rules.Unchecked`(`start_bundle.py` 36–37행과 같다) | 과제 4 가 쓰는 `start_bundle.open_base` → `team_rules.open_team` 이 그 클래스를 던진다 — 새 클래스면 b9(기대 2)가 「그 밖 예외 → 3」 이 된다 | 새 클래스를 만들고 바꿔 던진다 |
| K25 | 역할 대응을 부르는 말 | 형식 정본 §6 · §9 에 같은 문장 — 「스크립트의 기본 역할(`--role` 을 주지 않을 때)은 `team_layout` 의 기본값이고, 걸음표의 누가 칸은 리더가 `--role` 로 줄 역할을 보인다.」 | 과제 11 과 16 이 「정본」 · 「보이는 기본」 으로 갈라 적었다 — 코드의 기본은 `team_layout._DEFAULT_ROLES` 다 | 걸음표를 정본으로 하고 스크립트가 표를 읽는다 |
| K17 | 지휘 절차의 team 형식 글 | `references/conducting.md` 의 `## 손으로 따르는 절차` 바로 앞에 `## team 형식 로드맵` 절을 새로 두고(`tests/test_conducting_loop.sh:11` 이 끝 절을 못 박는다), 지휘 순환 걸음 2 · 3 · 4 · 5 의 「- 부를 skill:」 줄 바로 앞에(판단 칸 밑의 하위 글머리를 끊지 않게) 「team 형식 로드맵이면 아래 `## team 형식 로드맵` 절을 따른다 — 걸음표와 이 절의 문장이 다르면 걸음표를 따른다」 한 줄씩을 **새 줄**로 더한다. 있는 줄(특히 걸음 2 의 「앞머리에 에픽 이름」 줄 — 상태 브랜치 계획이 같은 줄을 고친다)은 고치지 않는다 | AC21 · 같은 파일을 고치는 상태 브랜치 계획과 줄이 겹치지 않게 | 걸음마다 문장을 갈라 고친다 |
| K18 | 새 질문의 통과 밖 선택지 | 계획 확인 · 흐름 승인 · 건너뛰기 질문의 통과 라벨만 글자로 적고, 나머지 선택지는 리더가 정한다고 적는다 | 설계 Anti-goals — 리더의 글에 요구하는 것은 질문 머리와 통과 선택지뿐이다 | 선택지 셋을 글자로 닫는다 |
| K19 | 리뷰 프로필 줄의 자리 | `references/docreview-profiles/design-doc.md` 층 1 의 `scope` 글머리 끝에 한 문장 — 범주는 `scope`, 처분은 `decide` | 새 범주를 만들면 엔진의 범주 목록을 고쳐야 한다 | 새 글머리 · 새 범주 |
| K20 | 계획 1 리뷰 잔여 가운데 동작에 닿는 넷 | 동작을 바꾸지 않는다는 설계 미룸 행대로 — `{…}` 꼴 줄을 JSON 으로 세는 것 · 기록 절이 수준 1 제목에서 끝나지 않는 것 · 기록 제목 뒤 공백과 CRLF 를 본문으로 세는 것은 **지금 동작을 테스트로 못 박고** 주석을 단다. 폴더를 읽지 못한 경우의 글은 「찾지 못했다」 대신 「폴더를 읽지 못했다」 로 다듬는다(종료 코드 · 판정은 그대로 3 · 확인 못 함). 시작 묶음의 「계획 n 의 브랜치가 아직 없다」 힌트는 그 사유(설계 파일을 그 끝에서 읽지 못했다)일 때만 붙인다(종료 코드는 그대로 1) | 미룸 행 「동작을 바꾸지 않는 테스트 보강과 글 다듬기다」 | 넷을 모두 고친다 |
| K21 | 세션 기록 자료의 읽지 않는 칸 | 이 계획은 하지 않는다 | 리뷰 잔여 목록 첫 줄과 미룸 표 467행(받는 곳 E1)이 겹친다 — 받는 곳이 적힌 행을 따른다 | 이 계획이 한다 |
| K22 | 종료 코드 1 과 3 의 경계(미룸) | 형식 정본(`references/team-files.md` §9 「종료 코드와 멈추는 조건」)에 한 문장 — INTENT.md 머리를 읽지 못하면 로드맵 블록의 과제는 1(멈춤), 로드맵 밖 과제는 3(검사 불가 — 과제로 세지 못했다). 에픽 쪽 1 을 재는 테스트를 더한다(로드맵 밖 쪽 3 은 이미 `test_start_bundle.sh` 가 잰다). 코드는 고치지 않는다 | 미룸 행 「형식 정본 문서의 목록에 적고 테스트로 재기」 | 둘을 같은 코드로 맞춘다 |

## 머지 전 다시 셀 것

상태 브랜치 계획(R3 계획 1 · PR #306, `origin/feature/conductor-state-branch` · 끝 `a0290234`)이 먼저 머지될 예정이고 같은 파일을 고친다. 그 브랜치는 기본 브랜치(`3b4e582a`)를 이미 합쳤다. 이 계획은 `origin/main` 기준으로 쓰되, 겹치는 파일은 `git show origin/feature/conductor-state-branch:<경로>` 로 그쪽 글도 읽어 편집의 닻을 양쪽에 다 있는 글에 둔다. 그 머지 뒤(또는 이 PR 의 머지 직전) `git merge origin/main` 으로 합친 다음 아래를 하나씩 다시 센다 — 충돌 목록에 없어도 `git diff origin/main -- <경로>` 로 본다. 「R3 끝」 칸은 2026-11-20 에 `a0290234` 에서 읽은 값이다.

| # | 자리 | 지금(main 3b4e582a) | R3 끝(a0290234) | 이 계획 뒤(R3 위) |
|---|---|---|---|---|
| 1 | `scripts/repo_defaults.py` 의 `KEYS` | `… + BUDGET_KEYS + ("human_gate",)` 열셋 | `… + BUDGET_KEYS + ("human_gate", "state_branch")` 열넷 | `walk_table` 을 `human_gate` **앞**에 둔다 — `("walk_table", "human_gate", "state_branch")` 열다섯. R3 의 `tests/test_repo_defaults.py` 341행이 `rd.KEYS[-1] == "state_branch"` 를 단언한다 — 끝에 두면 깨진다 |
| 2 | `tests/test_repo_defaults.py` 의 `len(rd.KEYS)`(171행) | 13 | 14 | 15 |
| 3 | `README.md` 「키는 위 …뿐이다」 · 설정 표 행 · `.devbrew.md` 예시 블록 | 열셋 | 열넷(303행) · `state_branch` 행과 예시 줄 `state_branch: 켬` | 열다섯 · `walk_table` 행과 주석 예시 줄 |
| 4 | `references/roadmap-ontology.md` 24행 「닫힌 집합 …」 · 키 목록 칸 | 열셋 · 키 끝 `` `handbook_budget` · `human_gate` `` | 열넷 · 키 끝 `` `human_gate` · `state_branch` `` | 열다섯 · 키 칸에 `` `handbook_budget` · `walk_table` · `human_gate` · `state_branch` `` |
| 5 | `tests/test_parallel_recommend_docs.sh` | 136 「열셋뿐」 · 141 「닫힌 집합 열셋)」 · 143 `` '· `shared_files` · `rules_budget` · `handbook_budget` · `human_gate` |' `` | 136 · 141 「열넷」 · 143 `` '· `human_gate` · `state_branch` |' `` · 144 `` '· `shared_files` · `rules_budget` · `handbook_budget` · `human_gate` ·' `` | 「열다섯」 둘 · 144 를 `` '· `handbook_budget` · `walk_table` · `human_gate` ·' `` 로(143 은 그대로 지난다) |
| 6 | `tests/test_workspace_invariance.sh` | 5행 「열셋 키」 · 30행 `KEYS=…human_gate` · 169행 `NFILES=$(( (13 * 2 + 3) * 3 ))` · 189행 메시지 「열셋 키」 | 5행 「열넷 키」 · 30행 `…human_gate state_branch` · 169행 `(14 * 2 + 3)` · 189행 「열넷 키」 | 「열다섯」 · 30행 `…handbook_budget walk_table human_gate state_branch` · 169행 `(15 * 2 + 3)`. 과제 10 이 같은 파일의 설정 자료에 `human_gate: 끔` 을 더한다 |
| 7 | `.claude-plugin/plugin.json` 판 · `CHANGELOG.md` 맨 위 머리 | 8.25.0 | 8.26.0 | 그때 기본 브랜치 위의 다음 minor(예상 8.27.0) — 이 계획의 테스트는 판 번호로 절을 고른다 |
| 8 | R3 의 CHANGELOG 락 | — | `tests/test_conductor_state_branch_docs.py` 161행이 `split("\n## [")[1]` 로 **맨 위 절**에서 R3 낱말을 찾는다 — 이 계획이 새 절을 맨 위에 두면 붉어진다 | 지휘자가 PR #306 에서 판 번호(8.26.0)로 고르게 고치도록 넘겼다. 합친 뒤 그 줄이 판 번호로 고르는지 확인하고, 아니면 과제 16 이 그 줄을 `changelog_entries` · `version_tuple`(`tests/test_team_docs.py`)로 8.26.0 절을 고르게 고친다 |
| 9 | `references/conducting.md` | — | 걸음 1 · 걸음 2 기본값 줄(「앞머리에 에픽 이름」 줄) · 걸음 7 을 고친다 | 이 계획은 그 줄들을 고치지 않고 새 줄(걸음 2–5 의 「- 부를 skill:」 앞) · 새 절만 더한다(K17). 합친 뒤 가리킴 줄 넷의 자리를 본다 |
| 10 | `references/team-files.md` | — | §1 트리 · §1 표 · §15 표를 고친다(16 · 35 · 667행 근처) | 이 계획은 §2 · §5 · §6 · §9 · §10 과 새 `### 걸음표` 를 고친다. 합친 뒤 `## 목차` 가 있으면 맞춘다 |
| 11 | `README.md` 「Principles Instantiated」 · 「지휘자 상태 브랜치」 절 · `## 한계` 첫 줄 | — | 원칙 줄 셋 · 절 하나를 더하고 한계 첫 줄을 `WRITER_TRUST_NOTICE` 로 되돌린다(`test_roadmap_status.sh` 가 못 박는다) | 이 계획의 원칙 줄은 그 뒤에 이어 단다. 한계 절은 건드리지 않는다 |
| 12 | `tests/test_repo_literals.sh` 21행 `TARGETS=` | — | R3 가 자기 새 스크립트를 더한다 | 과제 3 이 `scripts/walk_table.py` 를 더한다 — 합칠 때 두 쪽 이름을 모두 남긴다 |

`scripts/conductor_ledger.py` · `scripts/control_plane.py` 는 R3 의 diff 에 없다(2026-11-20 확인) — 다시 셀 것이 없다.

## 파일 표

| 파일 | 과제 | 하는 일 |
|---|---|---|
| `scripts/repo_defaults.py` · `tests/test_repo_defaults.py` · `README.md`(설정 표 · 키 수) · `references/roadmap-ontology.md` · `tests/test_parallel_recommend_docs.sh` · `tests/test_workspace_invariance.sh` | 2 | `walk_table` 키 |
| `references/walk-table.md`(새로) · `scripts/walk_table.py`(새로) · `tests/test_walk_table.py`(새로) | 3 | 기본 걸음표 · 읽기 · 검사 |
| `scripts/walk_table.py` · `tests/test_walk_next.sh`(새로 · 100755) | 4 | 걸음 보기 `next` |
| `scripts/human_lines.py` · `tests/test_human_judge.py` · `tests/test_human_record.sh` | 5 · 6 | 대조 판정 조건 둘 · 라벨 꼬리 |
| `scripts/conductor_ledger.py` · `tests/test_human_record.sh` | 7 | `human-check` 의 브랜치 끝 |
| `scripts/job_results.py` · `tests/test_team_status.sh` | 8 | 받음 줄 낡음을 본문으로 |
| `tests/test_session_fixture.py` · `scripts/session_record.py` · `tests/test_session_record.py` · `tests/test_human_lines.py` · `tests/test_human_judge.py` · `tests/test_team_status.sh` | 9 | 읽기 쪽 리뷰 잔여 |
| `tests/test_conductor_ledger.py` · `tests/test_human_record.sh` · `scripts/start_bundle.py` · `tests/test_human_gate.sh` · `tests/test_start_bundle.sh` · `tests/test_workspace_invariance.sh` · `references/team-files.md`(§9) | 10 | 쓰기 · 묶음 쪽 리뷰 잔여 · 종료 코드 경계 |
| `templates/team/role-{leader,designer,worker,writer}.md` · `docs/superpowers/roadmaps/{leader,designer,worker,writer}/CLAUDE.md` · `tests/test_team_files.py` · `references/team-files.md`(§6) | 11 | 역할 문서 |
| `references/conductor-dispatch.md` · `tests/test_walk_docs.py`(새로) | 12 | 보내는 글 틀 |
| `references/conducting.md` · `skills/epic-conductor/SKILL.md` · `references/proceed-gate.md` · `skills/spec-review/SKILL.md` · `tests/test_walk_docs.py` · `tests/test_human_lines.py` | 13 | 지휘 절차 · 승인 게이트 · 통과 라벨 락 |
| `references/docreview-profiles/design-doc.md` · `tests/test_walk_docs.py` | 14 | 리뷰 프로필 한 줄 |
| `docs/philosophy/devbrew-harness-philosophy.md` · `CLAUDE.md` · `tests/test_walk_docs.py` | 15 | P8 · CLAUDE.md |
| `references/team-files.md` · `README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json` · `tests/test_walk_docs.py` | 16 | 문서와 판 · 전체 스위트 |

고치지 않는 것: `scripts/roadmap_status.py` · `scripts/control_plane.py` · `scripts/team_status.py`(과제 9 의 테스트만) · `scripts/session_record.py` 의 판정(글 한 줄만 — K20) · `dependencies.md`(걸음표는 새 의존이 없다) · 설계문서 · 지나간 계획 · 인터뷰 기록.

---

### Task 1: 다시 확인

설계문서가 근거로 든 자리가 지금 코드(계획 1 머지 뒤 `origin/main` 3b4e582a)에서도 그런지 본다. 기대와 다르면 **멈추고** 지휘자에게 보고한다(어느 줄 · 무엇이 달랐나 · 어느 과제가 닿나). 고치지 않는다. 계획을 쓸 때(2026-11-20) 아래 기대는 모두 맞았다.

**Files:** 없음(읽기만)

- [ ] **Step 1: 근거 자리를 읽는다**

레포 뿌리에서 돈다.

```bash
cd plugins/spec-distill
grep -c 'start_bundle' references/conducting.md references/conductor-dispatch.md skills/epic-conductor/SKILL.md references/proceed-gate.md   # 0 · 0 · 0 · 0 — 지휘 절차와 틀에 시작 묶음이 없다
grep -n '^_DEFAULT_ROLES' scripts/team_layout.py                       # (ROLES[0], ROLES[3], ROLES[3], None) — 설계 leader · 계획 worker(계획 1)
grep -c '원자료(`intent/original.md`) 전체를 읽고' templates/team/role-designer.md templates/team/role-leader.md   # 1 · 0 — 설계 걸음의 할 일이 아직 designer 에
for r in leader designer writer worker; do cmp -s templates/team/role-$r.md ../../docs/superpowers/roadmaps/$r/CLAUDE.md && echo same; done   # same 넷
grep -n 'ledger record --spec <설계문서> --approval' references/conducting.md   # 한 줄(걸음 3 승인 게이트) — 옛 형식 승인 줄 명령
grep -n '질문 문장 앞머리에 에픽 이름' references/conducting.md skills/epic-conductor/SKILL.md   # 27행 · 208행 근처 한 줄씩
grep -n '정답 출처 파일(brief · 에픽 묶음)\|파일(brief · 에픽 묶음)의 §6' references/docreview-profiles/design-doc.md   # 31 · 86행(PR #303)
grep -n 'DESIGN_LINE' tests/test_raw_source_profiles.sh | head -1        # 76행 — 31행을 고정 문장으로 잡는다
grep -n '순서를 강제하는 결정론은 두지 않는다' ../../docs/philosophy/devbrew-harness-philosophy.md   # 84행
grep -n '결정론은 보안 · 정확성 게이트에만(철학 P8)' ../../CLAUDE.md     # 30행
grep -n 'human_gate",)$' scripts/repo_defaults.py                      # KEYS 끝이 human_gate — 열셋
grep -n 'def test_spec_label_is_the_one_the_approval_question_offers' tests/test_human_lines.py   # J20 의 테스트 — spec 승인 라벨 하나만
grep -n '^RECOMMENDED = ' scripts/human_lines.py                        # "(권장)" 하나
grep -n 'def plan_merged\|^NOT_COUNTED_AS_MERGED' scripts/team_status.py   # 계획 n 머지 판정이 한 곳에 있다(걸음 보기가 같은 판정을 쓴다)
grep -n 'def read_pr_cache' scripts/roadmap_status.py                  # PR 캐시 읽기(K5)
grep -n 'front = next' scripts/conductor_ledger.py                     # human-check 가 계획 번호 없는 줄을 가장 앞 브랜치 끝에서만 본다(K12)
grep -n 'changed = git.touched' scripts/job_results.py                 # 받음 줄 낡음을 건드린 경로로 센다(K13)
git diff --stat origin/main -- scripts tests references templates skills README.md CHANGELOG.md   # 빈 출력 — 이 브랜치가 아직 아무것도 고치지 않았다
```

- [ ] **Step 2: 상태 브랜치 계획의 겹침을 본다**

```bash
git fetch origin
git diff --stat origin/main...origin/feature/conductor-state-branch -- plugins/spec-distill | tail -1
```

기대 — `conducting.md` · `team-files.md` · `repo_defaults.py` · `README.md` · `CHANGELOG.md` · `plugin.json` · `test_repo_defaults.py` · `test_workspace_invariance.sh` · `roadmap-ontology.md` 가 그 목록에 있다. 그 브랜치가 이미 머지됐으면 `git merge origin/main` 으로 합치고 `## 머지 전 다시 셀 것` 을 지금 센다. 목록이 다르면 보고한다(멈추지 않는다).

---

### Task 2: 설정 키 `walk_table`

**AC:** AC20(계획 2 몫 — `walk_table` 키)

**Files:**
- Modify: `plugins/spec-distill/scripts/repo_defaults.py` · `plugins/spec-distill/README.md` · `plugins/spec-distill/references/roadmap-ontology.md`
- Test: `plugins/spec-distill/tests/test_repo_defaults.py` · `plugins/spec-distill/tests/test_parallel_recommend_docs.sh` · `plugins/spec-distill/tests/test_workspace_invariance.sh`

**Interfaces:**
- Produces: `repo_defaults.KEYS` 에 `"walk_table"`(`"human_gate"` 바로 앞) · `_DEFAULTS["walk_table"] = None` · `repo_defaults.file_path(key: str, raw: str) -> tuple[str | None, str | None]` — (레포 상대 파일 경로, 사유). 과제 3 이 `resolve(cwd)["values"]["walk_table"]` 로 읽는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_repo_defaults.py` 의 `self.assertEqual(len(rd.KEYS), 13)` 을 14 로 고치고 클래스를 더한다:

```python
class WalkTable(unittest.TestCase):   # R2 AC20 — 계획 2 몫
    def merged(self, repo=None, roadmap=None):
        return rd.merge_layers(roadmap, repo, "레포 설정", [])

    def test_default_is_none_and_place_is_before_human_gate(self):
        out = self.merged()
        self.assertEqual((out["values"]["walk_table"], out["sources"]["walk_table"]), (None, "기본값"))
        self.assertEqual(rd.KEYS[rd.KEYS.index("walk_table") + 1], "human_gate")

    def test_repo_relative_file_path(self):
        out = self.merged(repo={"walk_table": "docs/walk.md"})
        self.assertEqual((out["values"]["walk_table"], out["errors"]), ("docs/walk.md", []))
        self.assertEqual(self.merged(repo={"walk_table": '"docs/a #1.md"'})["values"]["walk_table"], "docs/a #1.md")

    def test_bad_paths_are_errors(self):
        for raw in ("/abs/walk.md", "~/walk.md", "docs/", "a/../walk.md", "./walk.md", ".git/walk.md", "docs/*.md", ":walk.md", ""):
            out = self.merged(repo={"walk_table": raw})
            self.assertIsNone(out["values"]["walk_table"], raw)
            self.assertTrue(out["errors"] and "walk_table" in out["errors"][0], raw)

    def test_roadmap_layer_does_not_take_it(self):
        out = self.merged(roadmap={"type": "roadmap", "walk_table": "docs/walk.md"})
        self.assertTrue(any("walk_table" in e for e in out["errors"]))
        self.assertIsNone(out["values"]["walk_table"])
```

`ReadmeTable.test_every_key_has_a_row` 는 그대로 둔다(`walk_table` 행이 없으면 붉어진다).

`tests/test_parallel_recommend_docs.sh` 136 · 141행의 「열셋」 을 「열넷」 으로, 143행의 온톨로지 키 단언 `` '· `shared_files` · `rules_budget` · `handbook_budget` · `human_gate` |' `` 을 `` '· `handbook_budget` · `walk_table` · `human_gate` |' `` 로. `tests/test_workspace_invariance.sh` 의 5행 「열셋 키」 → 「열넷 키」 · 30행 `KEYS=` 의 `human_gate` 앞에 `walk_table` · 169행 `NFILES` 식의 `13` → `14` · 189행 메시지의 「열셋 키」 → 「열넷 키」(R3 뒤에는 `## 머지 전 다시 셀 것` 대로 다시 센다 — 그때 열다섯 · `(15 * 2 + 3)`).

붉어질 변이: `walk_table` 을 `KEYS` 끝에 둔다(첫 테스트) · `file_path` 가 끝 `/` 를 받는다(셋째 — `docs/`) · `_FOLDER_KEYS` 에 넣어 폴더로 읽는다(둘째 — 값이 `docs/walk.md/`).

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_repo_defaults.py 2>&1 | tail -3`
Expected: `WalkTable` 네 테스트와 `len(rd.KEYS)` 가 FAIL(`ReadmeTable` 은 키를 더하기 전이라 아직 지난다 — Step 3 에서 키만 더하고 README 행을 빼먹으면 붉어진다)

- [ ] **Step 3: 키를 더한다**

- `repo_defaults.py` — `KEYS` 를 `… + BUDGET_KEYS + ("walk_table", "human_gate")` 로, `_DEFAULTS` 에 `"walk_table": None`. `file_path(key, raw)` 는 `_folder` 와 같은 거절(비었음 · `/` · `~` 로 시작 · 빈 조각 · `.` · `..` · `.git` 조각 · 글롭 · pathspec 글자)에 끝 `/` 거절을 더하고 끝 `/` 를 붙이지 않는다 — 두 함수가 같은 검사를 쓰게 공통 부분을 한 도우미로 뽑는다(20줄 중복 락). `merge_layers` 에 `elif key == "walk_table":` 갈래 — 사유가 있으면 값 `None` 과 `"%s: %s" % (at, why)` 오류.
- `README.md` — 설정 표의 `human_gate` 행 앞에 ``| `walk_table` | 걸음 보기(`walk_table.py next`)가 읽는 레포의 걸음표 파일(레포 상대경로 — 관문은 이 표로 바뀌지 않는다) | 없음(플러그인 기본 표 `references/walk-table.md`) | 오류 |`` · 예시 블록의 `# review_model:` 줄 뒤에 `# walk_table: <레포 걸음표 파일 경로>` · 「키는 위 열셋뿐이다」 → 「열넷」.
- `references/roadmap-ontology.md` 24행 — 「닫힌 집합 열셋」 → 「열넷」, 뜻 칸에 「걸음표 파일」, 키 칸의 `` `handbook_budget` · `human_gate` `` 사이에 `` `walk_table` `` (`KEYS` 차례와 같게).

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_repo_defaults.py plugins/spec-distill/tests/test_roadmap_ontology.py 2>&1 | tail -1; bash plugins/spec-distill/tests/test_parallel_recommend_docs.sh | tail -1; bash plugins/spec-distill/tests/test_workspace_invariance.sh | tail -1; bash shared/tests/test_no_new_duplication.sh | tail -1`
Expected: `OK` · 실패 0 · 실패 0 · 실패 0

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/repo_defaults.py plugins/spec-distill/README.md plugins/spec-distill/references/roadmap-ontology.md plugins/spec-distill/tests/test_repo_defaults.py plugins/spec-distill/tests/test_parallel_recommend_docs.sh plugins/spec-distill/tests/test_workspace_invariance.sh
git commit -m "feat(spec-distill): 레포 설정에 걸음표 파일 키 walk_table 을 더한다"
```

---

### Task 3: 기본 걸음표와 읽기 · 검사

**AC:** AC1

**Files:**
- Create: `plugins/spec-distill/references/walk-table.md` · `plugins/spec-distill/scripts/walk_table.py`
- Test: `plugins/spec-distill/tests/test_walk_table.py`

**Interfaces:**
- Consumes: `repo_defaults.resolve(cwd)` · `repo_defaults._toplevel` · `repo_defaults._default_commit` · `repo_defaults._read_blob(top, commit, path, "repo")` · `repo_defaults.SettingsError` · `team_layout.STAGES` · `human_lines.KINDS` · `team_status.DESIGN_FLOW` · `team_status.PLAIN_FLOW`
- Produces (`scripts/walk_table.py` — 과제 4 가 쓴다):
  - `COLUMNS = ("걸음", "누가", "단계", "관문", "작업 방식", "상한", "도구")` · `EMPTY = "—"` · `DEFAULT_TABLE: Path`(플러그인의 `references/walk-table.md`) · `ANCHORS: dict[str, tuple[str, ...]]` — 흐름 → 기본 표의 걸음 이름들(차례대로)
  - `class Step(NamedTuple): name: str · who: str · stage: str · gate: str · method: str · limit: str · tool: str · line: int`
  - `class TableError(ValueError)` — 글은 `<어디>:<n>행: <사유>` 꼴(절 · 표가 없으면 `<어디>: <사유>`)
  - `ANCHOR_STAGES: dict[tuple[str, str], str]` — (흐름, 닻 이름) → 그 걸음의 단계(기본 표의 단계 칸 값 — `계획` → `plan` · `구현` → `implement` · `검수` → `review` · `설계 대화` · `설계 검토` → `design` · 설계 없는 흐름의 `진행` → `implement`). 막는 것이 이 값을 읽는다(H2)
  - `Usage = team_rules.Usage` · `Unchecked = team_rules.Unchecked`(K24 — 새 클래스를 만들지 않는다)
  - `parse(text: str, where: str) -> dict[str, list[Step]]` — 흐름 이름 → 그 절의 걸음들
  - `load(cwd: str) -> tuple[dict[str, list[Step]], str]` — (표, 출처 글). 출처는 `플러그인 기본 표` 또는 `레포 설정 walk_table: <경로>@<커밋 8자>`
  - `missing_anchors(tables) -> list[str]` — 표에 없는 닻 이름들(`<흐름>: <이름>`)
  - 명령줄 `walk_table.py check [<파일>]` — 0 · 2 · 3

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_walk_table.py`(머리는 `tests/test_human_judge.py` 처럼 `REPO` · `SCRIPTS` 를 잡고 `import walk_table as W`):

```python
GOOD = (W.DEFAULT_TABLE).read_text(encoding="utf-8")


def swap(text, old, new):
    assert old in text, old
    return text.replace(old, new, 1)


class DefaultTable(unittest.TestCase):   # AC1
    def test_two_tables_and_the_design_rows(self):
        t = W.parse(GOOD, "기본")
        self.assertEqual(sorted(t), sorted([W.team_status.DESIGN_FLOW, W.team_status.PLAIN_FLOW]))
        self.assertEqual([s.name for s in t[W.team_status.DESIGN_FLOW]],
                         ["방향 확인", "설계 대화", "설계 검토", "설계 승인", "계획", "계획 확인", "구현", "검수", "PR 전 확인", "머지", "회고"])
        self.assertEqual([s.name for s in t[W.team_status.PLAIN_FLOW]], ["방향 확인", "진행", "결과 확인"])
        rows = {s.name: s for s in t[W.team_status.DESIGN_FLOW]}
        self.assertEqual(rows["계획"][1:7], ("worker", "plan", "—", "superpowers:writing-plans", "—", "—"))
        self.assertEqual(rows["설계 승인"].gate, "spec 승인")
        self.assertEqual(rows["계획 확인"].gate, "계획 검토")
        self.assertEqual(rows["구현"].method, "superpowers:subagent-driven-development")
        self.assertEqual(rows["검수"].tool, "spec-distill:integration-reviewer")
        self.assertEqual(rows["회고"].tool, "spec-distill:relay-checker")
        self.assertEqual(t[W.team_status.PLAIN_FLOW][0].gate, "흐름 승인")
        self.assertEqual(W.ANCHORS[W.team_status.DESIGN_FLOW], tuple(s.name for s in t[W.team_status.DESIGN_FLOW]))
        self.assertEqual(W.missing_anchors(t), [])

    def test_the_file_is_only_a_title_two_headings_and_tables(self):   # 자기 설명 글이 없다
        for line in GOOD.splitlines():
            self.assertTrue(line == "" or line.startswith("|") or line in ("# 걸음표", "## 설계 흐름", "## 설계 없는 흐름"), line)


class Broken(unittest.TestCase):   # AC1 — 줄을 짚고 멈춘다
    def bad(self, text, *words):
        with self.assertRaises(W.TableError) as cm:
            W.parse(text, "t.md")
        for w in words:
            self.assertIn(w, str(cm.exception))

    def test_stage_and_gate_cells(self):
        self.bad(swap(GOOD, "| worker | plan |", "| worker | build |"), "t.md:", "행", "build")
        self.bad(swap(GOOD, "| spec 승인 |", "| 설계 승인 줄 |"), "t.md:", "설계 승인 줄")

    def test_shape(self):
        self.bad(swap(GOOD, "| 작업 방식 |", "| 방식 |"), "머리")                                   # 머리 행
        self.bad(swap(GOOD, "| 회고 | leader | — |", "| 회고 | leader |"), "칸")                    # 칸 수
        self.bad(GOOD.replace("## 설계 없는 흐름", "## 설계 없는 흐름 그리고"), "설계 없는 흐름")       # 절이 없다(제목은 글자 그대로)
        self.bad(GOOD + "\n## 설계 흐름\n", "설계 흐름")                                             # 절이 둘
        self.bad(swap(GOOD, "| 회고 |", "| 머지 |"), "머지")                                          # 이름 겹침

    def test_tolerated_noise(self):   # Review Focus 1 — 양성 대조
        noisy = GOOD.replace("\n", "\r\n").replace("| 계획 | worker |", "|  계획  |worker|")
        noisy = noisy.replace("## 설계 흐름", "설명 글 한 줄\r\n\r\n## 설계 흐름")
        noisy = swap(noisy, "| 회고 | leader | — |", "| 회고 | leader |  |")
        t = W.parse(noisy, "t.md")
        self.assertEqual(t[W.team_status.DESIGN_FLOW][4].name, "계획")
        self.assertEqual(t[W.team_status.DESIGN_FLOW][-1].stage, "—")

    def test_missing_anchor_is_only_a_notice(self):
        t = W.parse(swap(GOOD, "| 검수 |", "| 확인 |"), "t.md")
        self.assertEqual(W.missing_anchors(t), ["설계 흐름: 검수"])

    def test_anchor_stages_match_the_default_table(self):   # H2 — 막는 것의 단계는 이 상수에서
        t = W.parse(GOOD, "기본")
        for flow, steps in t.items():
            for s in steps:
                self.assertEqual(W.ANCHOR_STAGES.get((flow, s.name), "—"), s.stage, (flow, s.name))
        self.assertIs(W.Usage, W.team_rules.Usage)
        self.assertIs(W.Unchecked, W.team_rules.Unchecked)


class ReadOnly(unittest.TestCase):   # Global Constraints — 읽기만 한다
    def test_no_writes_no_subprocess(self):
        tree = ast.parse((W.Path(W.__file__)).read_text(encoding="utf-8"))
        names = {n.name for node in ast.walk(tree) if isinstance(node, (ast.Import, ast.ImportFrom)) for n in node.names}
        mods = {node.module for node in ast.walk(tree) if isinstance(node, ast.ImportFrom)}
        self.assertEqual((names | mods) & {"subprocess", "shutil", "socket"}, set())
        calls = {node.func.attr for node in ast.walk(tree) if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)}
        self.assertEqual(calls & {"write_text", "write_bytes", "replace", "unlink", "mkdir", "rename", "rmtree", "system", "popen"}, set())
        for node in ast.walk(tree):   # open 은 읽기 모드만
            if isinstance(node, ast.Call) and getattr(node.func, "id", None) == "open":
                modes = [a.value for a in node.args[1:2] if isinstance(a, ast.Constant)] + \
                        [k.value.value for k in node.keywords if k.arg == "mode" and isinstance(k.value, ast.Constant)]
                self.assertTrue(all(m in ("r", "rb") for m in modes), modes)

    def test_probe_has_teeth(self):   # 양성 대조 — 같은 훑기가 쓰는 모듈을 잡는다
        tree = ast.parse("import subprocess\nopen('x', 'w')\n")
        self.assertIn("subprocess", {n.name for node in ast.walk(tree) if isinstance(node, ast.Import) for n in node.names})
```

(테스트 파일은 `import ast` 를 더한다. `replace` 를 막으므로 `walk_table.py` 의 글자 바꾸기는 `split` · `join` · `re.sub` 로 쓴다. `W.team_rules` · `W.team_status` · `W.Path` 는 `walk_table` 이 가져온 이름이다.)

같은 파일에 `Load` 클래스 — 임시 git 레포(원격 `origin` · `git remote set-head origin main`)를 `test_human_judge.Repo` 처럼 세운다:

| # | 준비 | 기대 |
|---|---|---|
| l1 | 설정 파일 없음 | `load(dir)` 의 출처가 `플러그인 기본 표` · 표가 `parse(GOOD)` 와 같다 |
| l2 | `.devbrew.md` 에 `walk_table: docs/walk.md` · `docs/walk.md`(GOOD 에서 `구현` 행의 작업 방식을 `superpowers:executing-plans` 로) — 둘 다 main 에 커밋 · push | 출처가 `레포 설정 walk_table: docs/walk.md@<main 의 앞 8자>` · `구현` 의 작업 방식이 바뀐 값 |
| l3 | l2 뒤 작업 트리에서만 `docs/walk.md` 를 GOOD 으로 고침(커밋하지 않음) | 출처 · 값이 l2 그대로(기본 브랜치의 판) |
| l4 | 설정만 main 에 있고 `docs/walk.md` 는 작업 트리에만 | `Unchecked` · 글에 `기본 브랜치에 없다` · 기본 표로 넘어가지 않는다 |
| l5 | main 의 `docs/walk.md` 가 단계 칸 `build` | `TableError` · 글에 `docs/walk.md:` |
| l6 | main 의 `docs/walk.md` 가 심볼릭 링크 | `Unchecked` · 글에 `일반 파일이 아니다` |
| l7 | `.devbrew.md` 의 `walk_table: /abs.md` | `Unchecked` · 글에 `walk_table` |

명령줄(같은 클래스 — `subprocess` 로 `python3 walk_table.py`, cwd 는 임시 레포): `check` → 0 · 표준 출력 첫 줄이 `걸음표 맞음 — 플러그인 기본 표 · 설계 흐름 11걸음 · 설계 없는 흐름 3걸음` · `check <깨진 파일>` → 3 · 표준 출력 빔 · 표준 오류가 `[spec-distill] 검사 불가 — ` 로 시작 · `check <닻 이름이 빠진 파일>` → 0 · 둘째 줄 `알림: 걸음 보기가 쓰는 걸음 이름이 없다 — 설계 흐름: 검수` · `check a b` → 2.

붉어질 변이: 단계 칸 검사를 지운다(`test_stage_and_gate_cells`) · 빈 칸을 `—` 로 읽지 않는다(`test_tolerated_noise`) · 절 제목을 `startswith` 로 가른다(`test_shape` 셋째) · 설정 파일 값을 작업 트리에서 읽는다(l3 · l4) · 표 파일을 못 읽으면 기본 표로 넘어간다(l4 · l5).

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_walk_table.py 2>&1 | tail -3`
Expected: `ModuleNotFoundError: No module named 'walk_table'`

- [ ] **Step 3: 표 파일과 모듈을 쓴다**

- `references/walk-table.md` — 첫 줄 `# 걸음표`, 빈 줄, `## 설계 흐름`, 빈 줄, 설계 §1 의 첫 표(머리 행 · 구분 행 · 열한 행) 글자 그대로, 빈 줄, `## 설계 없는 흐름`, 빈 줄, 설계 §1 의 둘째 표. 그 밖의 글은 쓰지 않는다.
- `scripts/walk_table.py` — 머리 docstring 에 명령줄 두 줄과 종료 코드. `parse` 는 줄마다 끝 `\r` 를 떼고, 절 제목은 줄 글자 비교(`line == "## " + 흐름`)로 가른다 — 다른 `## ` 제목을 만나면 절이 끝난다. 표 행은 `|` 로 시작하는 줄이고 칸은 `split("|")[1:-1]` 을 `strip()` 한 것(끝 `|` 가 없는 줄은 칸 수 오류). 머리 행은 `COLUMNS` 와 같아야 하고 둘째 행은 구분 행(칸마다 `-` 와 `:` 뿐). `load` 는 `resolve(cwd)` 의 `errors` 가 있으면 첫 오류로 `Unchecked`, 값이 `None` 이면 `DEFAULT_TABLE` 을 읽고, 아니면 `_default_commit` 이 없을 때 `Unchecked`(기본 브랜치를 모른다), `_read_blob` 이 `None` 이면 `Unchecked("걸음표 파일이 기본 브랜치에 없다(<경로>) — 기본 표로 넘어가지 않는다")`, `SettingsError` 는 `Unchecked(str(exc))` 로 바꾼다. `main(argv)` 는 `start_bundle.main` 과 같은 예외 → 종료 코드 사상(`Usage` 2 · `TableError` · `Unchecked` · 그 밖 예외 3 — 반쯤 낸 출력이 없게 글을 다 만든 뒤 쓴다). docstring · 주석에 과제 폴더 꼴 글자(`jobs/` 등 — Global Constraints)를 쓰지 않는다.
- `tests/test_repo_literals.sh` 21행 `TARGETS=` 끝에 `scripts/walk_table.py` 를 더한다(R3 가 같은 줄에 자기 스크립트를 더한다 — 합칠 때 둘 다 남긴다, `## 머지 전 다시 셀 것` 12).

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_walk_table.py plugins/spec-distill/tests/test_team_layout.py plugins/spec-distill/tests/test_workflow_superpowers.py 2>&1 | tail -1; bash plugins/spec-distill/tests/test_check_brief.sh | tail -1; bash plugins/spec-distill/tests/test_repo_literals.sh | tail -1; bash shared/tests/test_python_floor.sh | tail -1; python3 -m unittest plugins/quality-gates/tests/test_utf8_explicit.py 2>&1 | tail -1`
Expected: `OK` · 실패 0 · 실패 0 · 실패 0 · `OK`

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/references/walk-table.md plugins/spec-distill/scripts/walk_table.py plugins/spec-distill/tests/test_walk_table.py plugins/spec-distill/tests/test_repo_literals.sh
git commit -m "feat(spec-distill): 기본 걸음표와 그 표를 읽고 검사하는 walk_table.py 를 더한다"
```

---

### Task 4: 걸음 보기(`walk_table.py next`)

**AC:** AC2 · AC9(계획 2 몫 — 관문 칸을 비운 표) · AC17(걸음 보기가 자취로 지금 걸음을 고르고 가를 수 없는 걸음은 묶어서 낸다)

**Files:**
- Modify: `plugins/spec-distill/scripts/walk_table.py`
- Test: `plugins/spec-distill/tests/test_walk_next.sh`(새로 · 100755)

**Interfaces:**
- Consumes: 과제 3 의 `load` · `ANCHORS` · `ANCHOR_STAGES` · `Step` · `Usage` · `Unchecked`(= `team_rules` 의 것) · `start_bundle.open_base(git, roadmap_rel)` · `start_bundle._blocks(git, base)` · `start_bundle._reader(git, base)` · `start_bundle._block(blocks, job)` · `roadmap_status.build(git, Namespace(roadmap=…, roadmap_file=None, json=False))` · `roadmap_status.read_pr_cache(git, roadmap_rel)` · `team_status.Reader.progress(tip, block, n)` · `team_status.Reader.scope(tip, job, branches)` · `team_status.task_jobs` · `human_lines.missing(scope, stage, plan, plain, deep=False)` · `human_lines.passed(scope, kind, plan, deep=False)` · `human_lines.GATE_OFF`
- Produces: `next_lines(cwd: str, roadmap: str, job: str) -> list[str]` · 명령줄 `walk_table.py next --roadmap <로드맵> --job <과제>`

**n 과 m.** m 은 상태 보고 블록의 `branches` 수다. n 은 머지되지 않았고 끝이 있는 첫 브랜치의 차례(1 부터)다. 그런 브랜치가 없으면 — 머지된 브랜치도 없으면 n = 1, 있으면 n = 머지된 브랜치 가운데 가장 뒤의 차례(모두 머지면 m). 끝이 있는 브랜치에서는 `Reader.progress(끝, 블록 사본, n)` 의 단계를 쓴다(블록 사본은 `_blocks` 의 로드맵 블록에 상태 보고의 `branches` 와 `notes=[]` 를 얹은 것).

**자취 → 지금 걸음 · 다음 걸음(기본 표 이름).** 리더는 늘 **다음 걸음**의 칸으로 담당자를 보낸다(H1 (가) — 사용자 2026-11-20 「넷 모두 권장대로」). 그래서 관문을 지났는데 담당자의 결과가 아직 없는 자리는 그 담당자 걸음을 다음 걸음으로 내고, 지금 걸음은 지난 관문 걸음에 ` (끝남)` 을 붙여 낸다(K8 과 같은 꼴).

| 자취 | 설계 흐름 — 지금 걸음 → 다음 걸음 | 설계 없는 흐름 — 지금 걸음 → 다음 걸음 |
|---|---|---|
| 끝 있는 브랜치도 머지된 브랜치도 없다 | 방향 확인 → 설계 대화 | 방향 확인 → 진행 |
| 단계 「설계 중」 · 설계 파일 없음 | 설계 대화 → 설계 검토 | — |
| 단계 「설계 중」 · 설계 파일 있음 | 설계 검토 · 설계 승인 → 계획 | — |
| 단계 「계획」 · 계획 n 파일 없음 | 설계 승인 (끝남) → 계획(n ≥ 2 면 지금 걸음은 `머지 (계획 n-1 — 끝남)`) | — |
| 단계 「계획」 · 계획 n 파일 있음 · `계획 검토`(n) 줄이 꼴 판정을 지나지 못함 | 계획 확인 → 구현 | — |
| 단계 「계획」 · 그 줄이 지남 | 계획 확인 (끝남) → 구현 | — |
| 단계 「구현 중」 | 구현 → 검수 | — |
| 단계 「구현 끝」 · PR 캐시에 그 브랜치의 `열림` 줄 없음 | 검수 · PR 전 확인 → 머지 | — |
| 단계 「구현 끝」 · `열림` 줄 있음 | 머지 → 회고(n < m 이면 `계획 (계획 n+1)`) | — |
| 단계 「구현 끝」 · PR 캐시를 읽지 못함 | 검수 · PR 전 확인 · 머지 → 회고(n < m 이면 `계획 (계획 n+1)`)(K5) | — |
| 계획 k 까지 머지 · k < m · 계획 k+1 끝 없음 | 머지 (계획 k — 끝남) → 계획 (계획 k+1)(K8) | — |
| 모두 머지 | 회고 → 없음 | 결과 확인 → 없음 |
| 브랜치 있음 · `흐름 승인` 이 꼴 판정을 지나지 못함 | — | 방향 확인 → 진행 |
| 「진행 중」 · `흐름 승인` 지남 · 결과 파일 없음 | — | 방향 확인 (끝남) → 진행 |
| 「진행 중」 · 결과 파일 있음 | — | 진행 → 결과 확인 |
| 「결과 받음」 | — | 결과 확인 → 없음 |
| 단계 「알 수 없음」 · 블록 「알 수 없음」 · 브랜치가 갈라짐 | 3 · 상태 계산의 사유 | 3 |

걸음 보기는 다시 보내기를 가르지 않는다 — 돌던 담당자가 끊겼거나 시도가 받아지지 않아 같은 걸음을 다시 보내는 것은 시작 묶음이 정한다(이어 쓰기 · 다음 시도 · 연속 실패 멈춤 — 형식 정본 §9). 결과 파일 유무는 `progress` 가 채우는 블록의 `job.result` 로 본다. 로드맵 밖 과제(`kind: task`)는 `team_status.task_jobs` 의 그 과제 줄(단계 · 브랜치)로 설계 없는 흐름 칸을 쓴다. 지금 걸음 묶음은 그 이름들의 행과 그 뒤에 이어진 기본 이름이 아닌 행들이다(K4). 다음 걸음은 늘 닻 이름의 행이다(레포가 더한 행은 앞 묶음에 붙으므로).

**출력(한 줄씩).**

```
알림: 사람 줄 대조가 꺼져 있다                                   ← 꺼졌을 때만 · 첫 줄
알림: <PR 캐시 사유>                                             ← K5 의 경우만
표: <출처>
흐름: 설계 흐름 · 계획 1/2                                        ← m < 2 면 「 · 계획 n/m」 없음
지금 걸음: 설계 검토 · 설계 승인
다음 걸음: 계획 — 누가 worker · 작업 방식 superpowers:writing-plans · 상한 — · 도구 —
막는 것: `spec 승인` 줄이 지나지 못했다 — <사유>                 ← 없으면 「막는 것: 없음」
```

다음 걸음이 없으면 `다음 걸음: 없음` · `막는 것: 없음`. 다음 걸음이 다음 계획이면 `다음 걸음: 계획 (계획 n+1) — …`. 다음 걸음의 칸 값은 표(기본 표 또는 레포 표)의 그 행에서 읽는다. **막는 것(K6 · H2)** — 블록 단계가 「대기」 면 `막는 것: <상태 보고의 사유>`. 아니면 다음 걸음의 닻 이름으로 `ANCHOR_STAGES` 에서 단계를 읽고(레포 표의 단계 칸은 보여 주기다), 그 단계가 있으면 `human_lines.missing(scope, 그 단계, 계획 번호(설계 흐름의 plan · implement · review 만), plain, deep=False)` 의 첫 사유, 없으면 `없음`. 설계 없는 흐름의 `진행` 은 `ANCHOR_STAGES` 가 `implement` 로 준다. scope 는 지금 끝(끝이 없으면 기준 커밋)에서 `Reader.scope` 로 만든다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_walk_next.sh` — `tests/test_human_gate.sh` 의 머리(`ROOT` · `assert.sh` · `T0` · `trap` · `team_repo.sh`)를 그대로 쓰고 `wn() { (cd "$W" && python3 "$S/walk_table.py" next --roadmap "$RM" "$@") > "$T/w.txt" 2> "$T/w.err"; echo $?; }` · `line() { sed -n "s/^$1: //p" "$T/w.txt"; }` 를 둔다. 손으로 적는 사람 줄은 없다 — `approved` · `finish_attempt` 도우미로 짓는다. 줄 묶음 A 는 레포 하나를 세워 차례로 걷는다(앞 행의 상태 위에서 다음 행).

| # | 준비 | `wn --job …` | 기대 |
|---|---|---|---|
| w1 | `new_repo` 직후 | E1 | 0 · `표` = `플러그인 기본 표` · `흐름` = `설계 흐름 · 계획 1/2` · `지금 걸음` = `방향 확인` · `다음 걸음` 이 `설계 대화 — 누가 사람 · leader · 작업 방식 superpowers:brainstorming · 상한 — · 도구 —` · `막는 것` = `없음` · 첫 줄이 `알림:` 이 아니다 |
| w2 | `feature/tm-e1` 을 만들어 빈 커밋 하나 · push | E1 | `지금 걸음` = `설계 대화` |
| w3 | E1 `design.md`(본문과 `## 미룸` 절) 커밋 · push | E1 | `지금 걸음` = `설계 검토 · 설계 승인` · `다음 걸음` 이 `계획 — 누가 worker` 로 시작 · `막는 것` 이 `` `spec 승인` `` 을 담는다 |
| w4 | `approved "spec 승인" E1` · push | E1 | `지금 걸음` = `설계 승인 (끝남)` · `다음 걸음` 이 `계획 — 누가 worker · 작업 방식 superpowers:writing-plans` 로 시작 · `막는 것` = `없음` |
| w4b | w4 그대로 `CLAUDE_CONFIG_DIR` 만 빈 새 폴더로 바꾸고 | E1 | `막는 것` = `없음`(꼴 판정 — 세션 기록을 읽지 않는다). 뒤 행 전에 `CLAUDE_CONFIG_DIR` 를 되돌린다 |
| w5 | `plan-1.md` 커밋 · push | E1 | `지금 걸음` = `계획 확인` · `다음 걸음` 이 `구현 — 누가 worker` 로 시작 · `막는 것` 이 `` `계획 검토` `` 를 담는다 |
| w6 | `approved "계획 검토" E1 1` · push | E1 | `지금 걸음` = `계획 확인 (끝남)` · `다음 걸음` 이 `구현 — 누가 worker · 작업 방식 superpowers:subagent-driven-development` 로 시작 · `막는 것` = `없음` |
| w6b | `finish_attempt 1` 직후(받음 줄 전) | E1 | `지금 걸음` = `구현` · `다음 걸음` 이 `검수 — 누가 leader · 작업 방식 — · 상한 — · 도구 spec-distill:integration-reviewer` |
| w7 | 받음 줄(`rcheck` 의 받음 줄을 `led record --spec … --line` 로 적어 커밋 · push) | E1 | `지금 걸음` = `검수 · PR 전 확인` · `다음 걸음` 이 `머지 — 누가 사람` 으로 시작 |
| w8 | 지휘 기계 상태의 `## PR` 절에 `feature/tm-e1` · 상태 `열림` 줄(`led add --roadmap "$RM" --session "$SID" --section PR --cells "…"` — 칸은 `conductor_state` 의 PR 머리 아홉 칸. `add` 가 그 절을 받지 않으면 `conductor_state` 의 쓰기 함수로 줄을 넣는 파이썬 한 줄을 쓴다) | E1 | `지금 걸음` = `머지` · `다음 걸음` 이 `계획 (계획 2)` 로 시작 |
| w9 | `feature/tm-e1` 을 main 에 머지(`g merge --no-ff`) · push · `feature/tm-e1b` 는 아직 없다. 상태 보고가 그 블록을 「일부 머지 1/2」 로 세는지 먼저 단언한다(아니면 그 준비를 바꾸고 보고한다) | E1 | `흐름` = `설계 흐름 · 계획 1/2` · `지금 걸음` = `머지 (계획 1 — 끝남)` · `다음 걸음` 이 `계획 (계획 2) — 누가 worker` 로 시작 |
| w10 | E3(의존 E1 — 아직 「일부 머지」) | E3 | `지금 걸음` = `방향 확인` · `막는 것` 이 `의존 미완료` 를 담는다 |
| w11 | E2(설계 없는 흐름) — 브랜치 없음 | E2 | `흐름` = `설계 없는 흐름` · `지금 걸음` = `방향 확인` · `다음 걸음` 이 `진행 — 누가 worker` · `막는 것` 이 `` `흐름 승인` `` 을 담는다 |
| w12 | `feature/tm-e2` 를 만들고 `approved "흐름 승인" E2` · push | E2 | `지금 걸음` = `방향 확인 (끝남)` · `다음 걸음` 이 `진행 — 누가 worker` 로 시작 · `막는 것` = `없음` |

줄 묶음 B — 새 레포(`new_repo "$T0/b"`), 「막지 않는다」 를 재는 쪽과 그 양성 대조:

| # | 준비 | 명령 | 기대 |
|---|---|---|---|
| b1 | main 에 `.devbrew.md`(`walk_table: docs/walk.md`)와 `docs/walk.md`(기본 표에서 관문 칸 셋과 `계획` 행의 단계 칸을 모두 `—` 로) 커밋 · push. E1 `design.md` 를 `feature/tm-e1` 에 커밋 · push(승인 줄 없음) | `wn --job E1` | 0 · `표` 가 `레포 설정 walk_table: docs/walk.md@` 로 시작 · `막는 것` 이 `` `spec 승인` `` 을 담는다(AC9 — 관문과 막는 것의 단계는 표에서 읽지 않는다) |
| b2 | 같은 상태 | `bundle --job E1 --stage plan --plan 1` | 1 · 표준 출력 빔(AC9) |
| b3 | 같은 상태 | `python3 "$S/walk_table.py" check` | 0 |
| b4 | `docs/walk.md` 의 단계 칸 하나를 `build` 로 고쳐 main 에 커밋 · push | `wn --job E1` | 3 · 표준 출력 빔 · 표준 오류에 `docs/walk.md:` 와 `build` |
| b5 | `docs/walk.md` 를 main 에서 지운다(설정은 남김) | `wn --job E1` | 3 · 표준 오류에 `기본 브랜치에 없다` |
| b6 | 설정을 지우고 `human_gate: 끔` 만 둔다 | `wn --job E1` | 0 · 첫 줄 `알림: 사람 줄 대조가 꺼져 있다` |
| b7 | `feature/tm-e1` 에 커밋 하나 · push 한 뒤 `g commit --amend -qm 갈라짐`(`tests/test_start_bundle.sh` 311행과 같은 준비 — 로컬과 origin 이 서로의 조상이 아니다) | `wn --job E1` | 3 · 표준 오류에 `갈라` |
| b8 | — | `wn --job ZZ` · `wn`(인자 없음) | 2 · 2 |
| b9 | 옛 형식 로드맵(머리말에 `layout` 없음)을 main 에 하나 더 둔다 | `walk_table.py next --roadmap <옛 로드맵> --job A1` | 2 · 표준 오류에 `team 형식` |
| b10 | 로드맵 밖 과제 하나를 `tests/test_team_tasks.sh` 의 준비대로 만든다(INTENT.md 머리 `kind: task` · 그 브랜치 push) | `wn --job <그 과제>` | 0 · `흐름` = `설계 없는 흐름` · `지금 걸음` 이 `방향 확인`(그 과제에 `흐름 승인` 줄이 없다) |

붉어질 변이: 막는 것을 걸음표의 관문 칸이나 단계 칸에서 센다(b1) · `deep=True` 로 부른다(w4b — 빈 설정 폴더에서 「확인 못 함」 이 나온다) · 「알 수 없음」 에서 방향 확인을 낸다(b7) · PR 캐시를 보지 않는다(w8) · m 을 1 로 센다(w1) · 꺼짐 알림을 빼거나 끝에 낸다(b6) · 레포 표가 깨지면 기본 표로 넘어간다(b4) · 관문을 지난 자리에서 담당자 걸음을 지금 걸음으로 낸다(w4 · w6 · w12) · `team_rules.Usage` 를 3 으로 바꾼다(b9).

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `chmod +x plugins/spec-distill/tests/test_walk_next.sh && bash plugins/spec-distill/tests/test_walk_next.sh | tail -1`
Expected: 실패가 여럿(`next` 명령이 없다)

- [ ] **Step 3: `next_lines` 를 쓴다**

위 두 표와 문단이 규칙이다. 로드맵이 team 형식이 아니면 `open_base` 가 던지는 `team_rules.Usage` 그대로 2, 과제가 블록도 로드맵 밖 과제도 아니면 `Usage`. 상태 보고(`roadmap_status.build`)가 git 읽기 실패를 냈으면 `Unchecked`.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `bash plugins/spec-distill/tests/test_walk_next.sh | tail -1; python3 -m unittest plugins/spec-distill/tests/test_walk_table.py plugins/spec-distill/tests/test_team_layout.py plugins/spec-distill/tests/test_workflow_superpowers.py 2>&1 | tail -1; bash plugins/spec-distill/tests/test_repo_literals.sh | tail -1; git ls-files -s plugins/spec-distill/tests/test_walk_next.sh`
Expected: 실패 0 · `OK` · 실패 0 · `100755`(커밋 뒤)

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/walk_table.py plugins/spec-distill/tests/test_walk_next.sh
git commit -m "feat(spec-distill): 걸음 보기 walk_table.py next 가 지금 걸음 · 다음 걸음 · 막는 것을 낸다"
```

---

### Task 5: 대조 판정의 조건 둘 — 물러선 승인 · 판 커밋

**AC:** AC11(미룸 표가 더한 조건 둘)

**Files:**
- Modify: `plugins/spec-distill/scripts/human_lines.py`(`match`)
- Test: `plugins/spec-distill/tests/test_human_judge.py` · `plugins/spec-distill/tests/test_human_record.sh`

**Interfaces:**
- Consumes: `session_record.answers(path)`(파일 차례) · `Answer.key` · `starts_with_head` · `names_gate` · `gate_names_in` · `clean_label`
- Produces: `human_lines.match` 의 새 `어긋남` 사유 둘 — `LATER_ANSWER = "그 머리로 더 뒤에 고른 답이 있다"` · `NOT_TOUCHED = "은 그 파일을 고친 커밋이 아니다"`(문서와 테스트가 상수로 읽는다)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_human_judge.py` 의 `Match` 에 더한다:

```python
    def test_a_later_answer_with_another_label_stops_the_line(self):   # K9 — 미룸(AC11) · 승인 뒤 「수정 필요」
        real = self.approve(self.tip)
        l = H.parse(real)
        self.assertEqual(self.v(real), H.PASS)                                         # 양성 대조
        SF.add_answer(self.conf, S, [(H.head(JOB, l.rev) + " — 다시 묻는 자리표시 질문", "수정 필요")])
        got = H.match(self.scope(self.tip, (real,)), real)
        self.assertEqual(got.verdict, H.MISMATCH)
        self.assertIn(H.LATER_ANSWER, got.why)
        self.assertIn("수정 필요", got.why)

    def test_same_label_again_or_other_questions_do_not_stop_it(self):   # Review Focus 5 — 양성 대조
        real = self.approve(self.tip)
        l = H.parse(real)
        SF.add_answer(self.conf, S, [(H.head(JOB, l.rev) + " — 다시 승인", "승인 — 계획 담당자에게 (권장)")])
        SF.add_answer(self.conf, S, [(H.head(JOB, l.rev) + " — spec 승인 건너뛸까요", "건너뛴다")])   # 건너뜀 라벨인 답은 다른 물음이다
        SF.add_answer(self.conf, S, [(H.head(JOB, l.rev) + " — 훅", "수정 필요")], who="hook")     # 사람 아님은 세지 않는다
        SF.add_answer(self.conf, S, [(H.head(JOB, "0" * 8) + " — 다른 판", "수정 필요")])
        self.assertEqual(self.v(real), H.PASS)

    def test_a_gate_word_in_the_requestion_does_not_hide_it(self):   # 검수 지적 — 「spec 승인」 낱말을 넣어 다시 물은 「수정 필요」
        real = self.approve(self.tip)
        SF.add_answer(self.conf, S, [(H.head(JOB, H.parse(real).rev) + " — spec 승인 다시 확인", "수정 필요")])
        self.assertEqual(self.v(real), H.MISMATCH)
        plan = self.approve(self.tip, H.KIND_PLAN, 1)
        SF.add_answer(self.conf, S, [(H.head(JOB, H.parse(plan).rev, 1) + " — 계획 검토 plan 1 다시", "계획 고침")])
        self.assertEqual(self.v(plan), H.MISMATCH)

    def test_flow_lines_skip_gate_named_questions(self):   # 흐름 승인 — INTENT.md 판 머리를 건너뛰기 질문과 함께 쓴다
        real = self.approve(self.tip, H.KIND_FLOW)
        rev = H.parse(real).rev
        SF.add_answer(self.conf, S, [(H.head(JOB, rev) + " — 계획 검토 plan 1 건너뛸까요", "멈춤")])
        self.assertEqual(self.v(real), H.PASS)
        SF.add_answer(self.conf, S, [(H.head(JOB, rev) + " — 설계 없이 가도 될까요", "설계하고 간다")])
        self.assertEqual(self.v(real), H.MISMATCH)

    def test_a_later_unknown_answer_is_unchecked(self):
        real = self.approve(self.tip)
        SF.add_answer(self.conf, S, [(H.head(JOB, H.parse(real).rev) + " — 다시", "수정 필요")], who="unknown")
        self.assertEqual(self.v(real), H.UNCHECKED)

    def test_skip_lines_compare_only_the_same_gate(self):
        real = self.approve(self.tip, H.KIND_SKIP, gate="계획 검토 plan 2")
        rev = H.parse(real).rev
        SF.add_answer(self.conf, S, [(H.head(JOB, rev) + " — 계획 검토 plan 1 건너뛸까요", "멈춤")])
        self.assertEqual(self.v(real), H.PASS)
        SF.add_answer(self.conf, S, [(H.head(JOB, rev) + " — 계획 검토 plan 2 건너뛸까요", "멈춤")])
        self.assertEqual(self.v(real), H.MISMATCH)

    def test_the_line_rev_must_have_changed_the_file(self):   # K10 — 미룸(AC11)
        # c2 는 plan-1.md 만 고친 커밋이다 — 설계 본문은 c1 과 같아 꼴 판정은 지나지만 그 판으로 물은 답은 근거가 아니다
        line = self.approve(self.tip, rev=self.c2[:8])
        self.assertEqual(H.shape(self.scope(self.tip, (line,)), line).verdict, H.PASS)
        got = H.match(self.scope(self.tip, (line,)), line)
        self.assertEqual(got.verdict, H.MISMATCH)
        self.assertIn(H.NOT_TOUCHED, got.why)
```

`tests/test_human_record.sh` 에 한 행 — E1 설계를 커밋하고 `ask-head` 머리로 「승인 — 계획 담당자에게 (권장)」 답을 지어 `record --human "spec 승인"` → 0 · 같은 머리로 「수정 필요」 답을 덧붙이고 → `human-check --job E1` 이 1 · 출력에 `어긋남` 과 `그 머리로 더 뒤에 고른 답이 있다`. 그 뒤 `record --human "spec 승인"` 을 다시 부르면 1 · 출력에 `사람이 고른 라벨: 「수정 필요」`(가장 뒤 답을 고른다 — 지금 동작을 못 박는다).

붉어질 변이: 뒤 답 검사를 지운다(첫 테스트) · 라벨 비교 없이 뒤 답이면 막는다(둘째) · spec · 계획 검토 줄에 관문 이름 거르기를 쓴다(셋째 — `test_a_gate_word…`) · 건너뜀 라벨 빼기를 지운다(둘째) · 흐름 승인 줄의 관문 이름 거르기를 지운다(넷째의 앞 단언) · 건너뜀 줄의 같은 관문 거르기를 지운다(`test_skip_lines…`) · `NOT_HUMAN` 을 센다(둘째) · `UNKNOWN` 을 사람으로 센다(`test_a_later_unknown…`) · 판 커밋 검사를 지운다(`test_the_line_rev…`) · 그 검사를 `shape` 로 옮긴다(그 테스트의 `shape` 단언). 실제로 붉어지는지는 Step 2 에서 고치기 전의 결과로, 변이는 커밋 뒤에 재서 과제 보고에 적는다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_human_judge.py 2>&1 | tail -3`
Expected: 새 일곱 테스트 가운데 `test_same_label_again…` 과 `test_flow_lines…` 의 앞 단언은 지금도 지난다(양성 대조). 나머지는 FAIL — `AttributeError: … LATER_ANSWER` · `NOT_TOUCHED` 거나 `PASS != MISMATCH` · `PASS != UNCHECKED`

- [ ] **Step 3: `match` 를 고친다**

`shape` 가 지난 직후(세션 기록을 읽기 전) 판 커밋 검사(K10) — `scope.git.run_err("log", "-1", "--format=%H", <판 커밋>, "--", ":(top,literal)" + 경로)` 의 출력이 판 커밋의 전체 번호가 아니면 `어긋남`(사유 `"줄의 판 %s %s" % (rev, NOT_TOUCHED)`), 실패면 `_unchecked`. 라벨 · 관문 이름 검사를 지난 뒤, 쌍둥이 검사 앞에 뒤 답 검사(K9) — `session_record.answers(path)` 에서 근거 키의 첫 자리 뒤의 답 가운데 같은 물음이고 `NOT_HUMAN` 이 아닌 것: `UNKNOWN` 이면 `_unchecked(…, True)`, 꼬리를 뗀 라벨이 줄의 라벨과 다르면 `어긋남`(사유 `"%s(「%s」) — 다시 묻고 가장 뒤 답으로 적는다" % (LATER_ANSWER, 라벨)`). 같은 물음 — `starts_with_head(질문, 과제, 판, 계획)` 이고, `걸음 건너뜀` 줄이면 `names_gate(질문, 줄의 관문)`, `흐름 승인` 줄이면 `gate_names_in(질문) == []`, `spec 승인` · `계획 검토` 줄이면 관문 이름으로 거르지 않고 `clean_label(답의 라벨)` 이 `PASS_LABELS[KIND_SKIP]` 에 든 답만 뺀다(K9).

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_human_judge.py plugins/spec-distill/tests/test_human_lines.py 2>&1 | tail -1; bash plugins/spec-distill/tests/test_human_record.sh | tail -1; bash plugins/spec-distill/tests/test_human_gate.sh | tail -1; bash plugins/spec-distill/tests/test_human_gate_e2e.sh | tail -1`
Expected: `OK` · 실패 0 · 실패 0 · 실패 0

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/human_lines.py plugins/spec-distill/tests/test_human_judge.py plugins/spec-distill/tests/test_human_record.sh
git commit -m "fix(spec-distill): 물러선 승인과 그 파일을 고치지 않은 판 커밋을 대조 판정에서 막는다"
```

---

### Task 6: 고른 라벨의 꼬리 규칙 — (가) 실행

**AC:** —(설계 §2 「쓰는 길」 3 — K11 · 사용자 2026-11-20 「넷 모두 권장대로」)

설계 §2 「쓰는 길」 3 대로 끝의 「(권장)」 · 「(Recommended)」 꼬리 하나를 뗀다(승인 게이트의 읽기 규칙과 같다). 고르지 않은 길((나) · (다))은 `## 계획의 판단` K11 의 다른 길 칸에 있다.

**Files:**
- Modify: `plugins/spec-distill/scripts/human_lines.py` · `plugins/spec-distill/references/team-files.md`(§2 사람 줄의 「떼는 꼬리」)
- Test: `plugins/spec-distill/tests/test_human_lines.py` · `plugins/spec-distill/tests/test_human_judge.py`

**Interfaces:**
- Produces: `human_lines.RECOMMENDED_TAILS = ("(권장)", "(Recommended)")` · `clean_label(text)` 가 끝에 붙은 둘 가운데 하나를 한 번만 뗀다. `RECOMMENDED` 는 그대로 둔다(문서 락이 쓴다).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```python
    def test_both_recommend_tails_come_off_once(self):   # test_human_lines.py LineShape — K11 (가)
        self.assertEqual(H.clean_label("승인 — 계획 담당자에게 (Recommended)"), "승인 — 계획 담당자에게")
        self.assertEqual(H.clean_label("승인 — 계획 담당자에게 (권장)"), "승인 — 계획 담당자에게")
        self.assertEqual(H.clean_label("승인 — 계획 담당자에게 (권장) (Recommended)"), "승인 — 계획 담당자에게 (권장)")   # 한 번만
        self.assertEqual(H.clean_label("(Recommended) 승인"), "(Recommended) 승인")                                           # 끝만
```

`test_human_judge.Match.test_real_line_passes` 에 `self.assertEqual(self.v(self.approve(self.tip, picked="승인 — 계획 담당자에게 (Recommended)")), H.PASS)` 한 줄.

붉어질 변이: 꼬리 목록에서 「(Recommended)」 를 뺀다(첫 단언) · 둘 다 뗀다(셋째) · `in` 으로 찾아 지운다(넷째).

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_human_lines.py plugins/spec-distill/tests/test_human_judge.py 2>&1 | tail -3`
Expected: 두 테스트 FAIL

- [ ] **Step 3: 고친다**

`clean_label` 을 `RECOMMENDED_TAILS` 로. `references/team-files.md` §2 의 사람 줄 글에서 「(권장)」 꼬리만 뗀다는 문장을 「라벨 끝의 「(권장)」 · 「(Recommended)」 꼬리 하나를 뗀다 — 승인 게이트의 읽기 규칙과 같다」 로.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_human_lines.py plugins/spec-distill/tests/test_human_judge.py plugins/spec-distill/tests/test_team_docs.py 2>&1 | tail -1`
Expected: `OK`

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/human_lines.py plugins/spec-distill/references/team-files.md plugins/spec-distill/tests/test_human_lines.py plugins/spec-distill/tests/test_human_judge.py
git commit -m "fix(spec-distill): 사람 줄의 고른 라벨에서 승인 게이트와 같은 꼬리 둘을 뗀다"
```

---

### Task 7: `human-check` 가 계획 번호 없는 줄을 브랜치 끝 모두에서 본다

**AC:** AC23(미룸 표 — 계획이 둘 이상인 과제)

**Files:**
- Modify: `plugins/spec-distill/scripts/conductor_ledger.py`(`_check_tips` · `c_human_check`)
- Test: `plugins/spec-distill/tests/test_human_record.sh`

**Interfaces:**
- Produces: `_check_tips(rs, branches, merged, main) -> tuple[Callable[[Optional[int]], str], list[tuple[str, str]], list[str]]` — (계획 번호 → 끝 고르기, 머지되지 않은 (브랜치, 끝)들 — 끝이 같으면 한 번, 알림들). `c_human_check` 만 부른다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_human_record.sh` 에 새 레포(`new_repo`) 한 묶음:

| # | 준비 | 기대 |
|---|---|---|
| h1 | `feature/tm-e1` 에 E1 설계(`## Goals` 아래 본문과 `## 미룸` 절이 있는 글) · `approved "spec 승인" E1` · push. `feature/tm-e1b` 를 `feature/tm-e1` 끝에서 만들어 push | `human-check --job E1` → 0 · `지남 — - spec 승인` 줄이 정확히 한 번(양성 대조) |
| h2 | `feature/tm-e1b` 에서 설계 본문(`## Goals` 아래 글)을 고쳐 커밋 · push | 1 · `낡음 — - spec 승인` · 그 아래 `    사유: feature/tm-e1b 끝에서: ` 로 시작하는 줄 |
| h3 | h2 를 되돌려(`git revert`) push 하고, 대신 `feature/tm-e1b` 에서 `## 미룸` 절만 고친다 | 0(본문 밖 고침) |

붉어질 변이: 가장 앞 브랜치 끝만 본다(h2) · 끝마다 한 줄씩 낸다(h1 의 「한 번」) · 머지된 브랜치 끝도 본다는 변이는 이 묶음에 머지가 없어 재지 않는다 — 과제 보고에 그 사실을 적는다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_human_record.sh | tail -3`
Expected: h2 FAIL(지금은 `지남`)

- [ ] **Step 3: 고친다**

`c_human_check` 의 켜진 갈래에서 계획 번호가 없는 줄은 `_check_tips` 의 머지되지 않은 끝들마다 `HL.match` 를 부르고 첫 `지남` 아닌 것을 낸다(K12). 그 끝들이 없으면 지금처럼 `pick(None)`. 계획 번호가 있는 줄 · 꺼진 갈래 · `줄 없음` 절은 그대로다.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `bash plugins/spec-distill/tests/test_human_record.sh | tail -1; bash plugins/spec-distill/tests/test_human_gate_e2e.sh | tail -1; python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py 2>&1 | tail -1`
Expected: 실패 0 · 실패 0 · `OK`

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/conductor_ledger.py plugins/spec-distill/tests/test_human_record.sh
git commit -m "fix(spec-distill): human-check 가 계획 번호 없는 사람 줄을 머지되지 않은 브랜치 끝 모두에서 판정한다"
```

---

### Task 8: 받음 줄의 낡음을 본문으로 견준다

**AC:** —(R1 의 받음 줄 · 미룸 표 「받음 줄의 낡음을 본문으로 견주기」)

**Files:**
- Modify: `plugins/spec-distill/scripts/job_results.py`(`receipt`)
- Test: `plugins/spec-distill/tests/test_team_status.sh`

**Interfaces:**
- Produces: `job_results._same_since(git, head: str, tip: str, path: str) -> bool` — 그 경로의 글이 받은 head 와 지금 끝에서 같은가(K13). `receipt` 만 부른다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_team_status.sh` 에 묶음 하나(그 파일의 받음 줄 준비 — 구현 결과 · 받음 줄이 있는 E1 — 를 새 레포에서 다시 쓴다):

| # | 받은 뒤 고침(커밋 · push) | E1 의 단계 · 근거 |
|---|---|---|
| r1 | 없음 | `구현 끝`(양성 대조) |
| r2 | 설계 파일의 `## 미룸` 절에 한 줄 | `구현 끝` |
| r3 | 예약 경로 파일 하나를 고치고 다음 커밋에서 되돌림 | `구현 끝` |
| r4 | 설계 본문(`## Goals` 아래)에 한 줄 | `구현 중` · 알림에 `받은 뒤 바뀜` 과 설계 파일 경로 |
| r5 | 예약 경로 파일 하나를 고침(되돌리지 않음) | `구현 중` · 알림에 그 경로 |

붉어질 변이: 거르기를 지운다(r2 · r3) · 설계 파일을 글 전체로 견준다(r2) · 모든 파일을 본문 규칙으로 견준다(r5 는 그대로 붉지 않으니 r4 와 짝으로 본다) · 같으면 세고 다르면 거른다(뒤집기 — r4 · r5).

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_team_status.sh | tail -3`
Expected: r2 · r3 FAIL

- [ ] **Step 3: 고친다**

`receipt` 에서 `left` 를 만든 뒤 `_same_since` 가 참인 경로를 뺀다. `_same_since` — 두 커밋의 `git.blob`(없으면 `None`). 이름이 설계 파일 · 계획 파일 · INTENT.md 면 `human_lines.body_of` 로 견주고, 둘 다 `None` 이면 같다, 하나만 `None` 이면 다르다. git 이 읽지 못한 것은 다르다로 본다(낡음 쪽 — 닫는 쪽).

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `bash plugins/spec-distill/tests/test_team_status.sh | tail -1; bash plugins/spec-distill/tests/test_job_results.sh | tail -1; python3 -m unittest plugins/spec-distill/tests/test_team_results.py 2>&1 | tail -1; bash plugins/spec-distill/tests/test_roadmap_status.sh | tail -1`
Expected: 실패 0 · 실패 0 · `OK` · 실패 0

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/job_results.py plugins/spec-distill/tests/test_team_status.sh
git commit -m "fix(spec-distill): 받음 줄의 낡음을 건드린 커밋이 아니라 받은 판과 지금 본문으로 견준다"
```

---

### Task 9: 계획 1 리뷰 잔여 — 읽기 쪽

**AC:** —(설계문서 `## 구현 대조` 「리뷰 잔여」 · 미룸 표 474행. 동작을 바꾸지 않는다 — K20)

**Files:**
- Modify: `plugins/spec-distill/scripts/session_record.py`(`locate` 의 글 한 줄과 `_scan` 의 주석)
- Test: `plugins/spec-distill/tests/test_session_fixture.py` · `plugins/spec-distill/tests/test_session_record.py` · `plugins/spec-distill/tests/test_human_lines.py` · `plugins/spec-distill/tests/test_human_judge.py` · `plugins/spec-distill/tests/test_team_status.sh`

- [ ] **Step 1: 테스트를 더한다(대부분 지금 동작을 못 박는 것이라 처음부터 지난다 — 변이로 이빨을 잰다)**

| 파일 · 테스트 | 하는 일 | 붉어질 변이 |
|---|---|---|
| `test_session_fixture.py` · `test_main_answer_prints_the_uuid` | `SF.main(["answer", "--config", d, "--session", SID, "--question", "q", "--label", "a"])` 의 표준 출력 한 줄이 기록 파일의 답 항목 `uuid` 와 같다 | `main` 이 uuid 를 찍지 않는다 |
| 〃 · `test_main_rejects_mismatched_counts` | `--question` 둘 · `--label` 하나 → `SystemExit` 코드 2 | 수 검사를 지운다 |
| 〃 · `test_unknown_who_and_drop_raise` | `add_answer(..., who="x")` · `drop=("x",)` → `ValueError` 둘 | 두 `raise` 를 지운다 |
| 〃 · `test_main_lines_and_text` | `main(["lines", …, "--name", "typed"])` 뒤 기록 줄 수가 자료 `typed.jsonl` 의 줄 수만큼 늘고, `main(["text", …, "--name", "typed", "--text", "글"])` 뒤 한 줄이 더 는다 | 두 갈래를 바꿔 부른다 |
| `test_session_record.py` · `test_brace_looking_line_counts_as_json` | 기록이 `{x}` 한 줄뿐이면 `answers()` 가 `[]`(`Unreadable` 이 아니다 — 지금 동작, K20) | 그 갈래를 지운다(`Unreadable` 로 바뀐다) |
| 〃 · `test_unlistable_projects_dir` | `projects` 를 보통 파일로 두면 `Unreadable` · 글에 `폴더를 읽지 못했다` | Step 2 의 글 다듬기 전에는 붉다 |
| 〃 · `test_session_name_must_fullmatch` | `add_answer(d, OTHER, …, subagent=True)` 로 `projects/fixture/OTHER/` 를 만들고 `OTHER2.jsonl` 도 둔 뒤 `locate(OTHER + "/../" + OTHER2)` → `Unreadable` | `re.fullmatch` 를 `re.match` 로 |
| `test_human_lines.py` · `Body.test_all_blank_text_trims_to_empty` | 세 이름(`design.md` · `INTENT.md` · `plan-1.md`) 모두 `body_of(name, "\n\n") == ""` | `_trim_blank_tail` 의 `end > 0` 를 지운다(IndexError) |
| 〃 · `Body.test_level1_heading_ends_deferred_but_not_record` | `### Deferred to plan` 표 뒤의 `# 새 최상위` 와 그 글은 본문에 남고, `## 결정 기록` 뒤의 같은 줄은 본문에서 빠진다(지금 동작, K20) | 245행 `1 <= level <= 3` → `2 <= level <= 3` |
| 〃 · `Body.test_record_title_with_space_or_cr_is_body` | `## 결정 기록 ` · `## 결정 기록\r` 제목 아래 줄은 본문이다 — 설계 파일 · INTENT.md 둘 다(지금 동작) | `_is_head` 의 `line == title` → `line.rstrip() == title` |
| `test_human_judge.py` · `Version.test_version_stops_at_a_commit_without_the_file` | 설계 c1 · `git rm` c2 · 같은 본문으로 다시 c3 → `version(git, c3, path) == c3[:8]` | 288행 `break` → `continue` |
| `test_team_status.sh` · 행 하나 | 설계 흐름 과제의 INTENT.md 결정 기록 칸을 깨고(같은 제목 둘이 아닌, 칸을 읽지 못하는 꼴) 구현 결과 파일이 있을 때 단계가 `설계 중` · 근거가 `결정 기록 읽기 불가 — ` 로 시작 | `progress` 의 `except FormatError` 설계 흐름 갈래를 지운다(그래도 지나면 그 갈래는 닿지 않는다 — 과제 보고에 「닿지 않음」 으로 적고 고치지 않는다) |

- [ ] **Step 2: 글을 다듬는다**

`session_record.locate` — `projects` 를 훑다 `OSError` 가 나면 「세션 기록 폴더를 읽지 못했다: <폴더>」 로 `Unreadable`(지금은 「찾지 못했다」 로 이어진다). `_scan` 의 `{…}` 갈래에 「JSON 으로 풀지 않고 센다 — 반쯤 쓰인 줄로 「읽은 줄 없음」 이 되지 않게(지금 동작)」 주석. `human_lines._design_body` 의 기록 절 끝 조건에 「수준 2 제목에서만 끝난다 — 수준 1 제목은 기록 절 안의 글로 둔다(지금 동작)」 주석.

- [ ] **Step 3: 돌려서 통과를 보고 변이를 잰다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_session_fixture.py plugins/spec-distill/tests/test_session_record.py plugins/spec-distill/tests/test_human_lines.py plugins/spec-distill/tests/test_human_judge.py 2>&1 | tail -1; bash plugins/spec-distill/tests/test_team_status.sh | tail -1`
Expected: `OK` · 실패 0. 커밋한 뒤 표의 변이를 하나씩 돌려 붉어진 테스트 이름을 과제 보고에 적는다.

- [ ] **Step 4: 커밋**

```bash
git add plugins/spec-distill/scripts/session_record.py plugins/spec-distill/scripts/human_lines.py plugins/spec-distill/tests/test_session_fixture.py plugins/spec-distill/tests/test_session_record.py plugins/spec-distill/tests/test_human_lines.py plugins/spec-distill/tests/test_human_judge.py plugins/spec-distill/tests/test_team_status.sh
git commit -m "test(spec-distill): 계획 1 리뷰가 남긴 읽기 쪽 빈 곳을 테스트로 못 박는다"
```

---

### Task 10: 계획 1 리뷰 잔여 — 쓰기 · 묶음 쪽과 종료 코드 경계

**AC:** —(리뷰 잔여 · 미룸 표 474 · 476행 — K20 · K22)

**Files:**
- Modify: `plugins/spec-distill/scripts/start_bundle.py`(힌트 조건) · `plugins/spec-distill/references/team-files.md`(§9 의 「맞추는 명령」 예시 따옴표 · 종료 코드 경계 문장)
- Test: `plugins/spec-distill/tests/test_conductor_ledger.py` · `plugins/spec-distill/tests/test_human_record.sh` · `plugins/spec-distill/tests/test_human_gate.sh` · `plugins/spec-distill/tests/test_start_bundle.sh` · `plugins/spec-distill/tests/test_workspace_invariance.sh` · `plugins/spec-distill/tests/test_team_docs.py`

- [ ] **Step 1: 테스트를 더한다**

| 파일 · 자리 | 하는 일 | 붉어질 변이 |
|---|---|---|
| `test_conductor_ledger.py` · `test_record_human_checks_itself_before_writing` | team 레포에서 `record --human` 이 쓸 답을 찾는 상태를 만들고 `mock.patch.object(L.HL, "match", return_value=HL.Verdict(HL.MISMATCH, "x", None, ""))` → 1 · INTENT.md 바이트 그대로. `HL.UNCHECKED` 면 3 | 쓰기 전 자가 검사를 지운다 |
| 〃 · `test_old_args_open_while_the_gate_is_off` | 기본 브랜치의 설정이 `human_gate: 끔` 인 team 레포에서 `record --spec <INTENT.md> --approval --date 2026-11-20 --choice "승인 — 계획 담당자에게"` → 0 | 옛 인자 막기에서 `_gate_on(root)` 를 빼고 늘 막는다 |
| 〃 · `test_plan_and_retry_names_round_trip` | `_retry_of(HL.retry_name(2, 3)) == (2, 3)` · `_retry_of(HL.retry_name(None, 3)) == (None, 3)` · `HL.parse(<계획 검토 plan 12 줄>).plan == 12` | `_retry_of` 의 묶음 차례를 바꾼다 |
| `test_human_record.sh` · 시간대 행 | `--when 2026-11-20T23:30:00.000Z` 답으로 `TZ=Asia/Seoul` 에서 `record --human` → 줄이 `- spec 승인 · 2026-11-21 · ` 로 시작 | `day(when, True)` 를 `False` 로 |
| 〃 · 갈라진 형제 브랜치 행 | E1 의 둘째 브랜치(`feature/tm-e1b`)에 커밋 하나 · push 한 뒤 `commit --amend` 로 갈라 둔 채(`tests/test_start_bundle.sh` 311행과 같은 준비 — origin 을 조상 커밋으로 옮기면 갈라지지 않고 로컬을 쓴다) 첫째 브랜치의 `record --human` → 0 · 출력에 `알림: feature/tm-e1b 의 줄을 읽지 않았다` | 알림을 찍지 않는다 |
| 〃 · 종료 코드 3 의 글 | 세션 기록 파일이 없는 행(있는 행에 붙인다)의 출력이 `[spec-distill] 확인 못 함 — ` 로 시작하고 `human_gate: 끔 으로 연다` 로 끝난다(`case` 로 끝 글자를 잰다) | 꼬리 붙이기를 지운다 |
| `test_human_gate.sh` · 13번 행 뒤 | 계획 2 의 브랜치가 **있는데** 관문이 닫힌 행에서 표준 오류에 `가 아직 없다` 가 없다 | 힌트 조건을 늘 참으로 |
| 〃 · 묶음 C 의 힌트 행 옆 | 설계는 main 에 있고 `CLAUDE_CONFIG_DIR` 를 빈 폴더로 바꿔 「확인 못 함」 이 다른 사유로 나는 `--stage plan --plan 2` → 1 · `가 아직 없다` 가 없다 | Step 2 전에는 붉다 |
| `test_start_bundle.sh` · 깨진 머리(에픽) | 로드맵 블록 과제의 INTENT.md 머리말을 닫지 않고 커밋 → `--stage design` 1 · 표준 출력 빔 · 표준 오류에 `멈춤 — ` 와 `머리를 읽지 못했다`(로드맵 밖 쪽 3 은 389–395행이 잰다 — 짝) | `_intent` 의 `Refused` 를 `Unchecked` 로 |
| `test_workspace_invariance.sh` · 설정 자료 | 172행 근처 설정 자료에 `human_gate: 끔` · A · B 의 `get-human_gate.out` 이 `끔` 으로 같고, 양성 대조 레포(211행 근처)는 `켬` 이라 `$DIFF` 에 `get-human_gate.out` 이 든다 | — (불변 락의 자료 넓히기) |
| `test_team_docs.py` · `HumanLines` | 한 줄 더하기 — `team-files.md` 에 과제 10 의 경계 문장이 있다(Step 2 의 글을 상수로 두고 그 글 통째로) · `맞추는 명령: python3 "<roadmap_write.py` 가 없다. 358행의 `assertIn("위 꼴의 따옴표는 자리표시의 표기이고", text)` 를 새 문장 `assertIn("위 꼴의 `<…>` 는 자리표시다", text)` 와 옛 문장의 `assertNotIn` 으로 바꾼다 | 문장을 지운다 · 옛 문장을 남긴다 |

- [ ] **Step 2: 고친다**

- `start_bundle._job_bundle` — 계획 n 브랜치 힌트의 조건에 「사유가 설계 파일을 그 끝에서 읽지 못한 것」(`"%s 을 %s 에서 읽지 못했다" % (team_layout.DESIGN_FILE, commit[:8])` 이 사유에 든다)을 더한다(K20).
- `references/team-files.md` §9 — 출력 꼴 블록의 `맞추는 명령:` 줄에서 경로 둘레 따옴표를 뗀다. 같은 절 561행 글머리의 끝 문장 「위 꼴의 따옴표는 자리표시의 표기이고 실제 줄의 경로는 안전한 글자뿐이면 따옴표 없이 나온다.」 를 「위 꼴의 `<…>` 는 자리표시다.」 로 바꾼다(앞 문장 — 안전한 글자면 그대로 · 아니면 그 낱말만 작은따옴표 — 은 그대로). 「종료 코드와 멈추는 조건」 문단에 문장 하나 — `INTENT.md 머리를 읽지 못하면 로드맵 블록의 과제는 1(멈춤)이고, 로드맵 밖 과제는 과제로 세지 못해 3(검사 불가)이다.`

- [ ] **Step 3: 돌려서 통과를 보고 변이를 잰다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py plugins/spec-distill/tests/test_team_docs.py 2>&1 | tail -1; for t in test_human_record test_human_gate test_start_bundle test_workspace_invariance; do bash plugins/spec-distill/tests/$t.sh | tail -1; done`
Expected: `OK` · 실패 0 넷. 커밋한 뒤 표의 변이를 돌려 과제 보고에 적는다 — 계획 1 이 「재지 못했다」 고 남긴 변이(옛 인자 막기가 늘 적용되는 경우)의 결과를 여기서 적는다.

- [ ] **Step 4: 커밋**

```bash
git add plugins/spec-distill/scripts/start_bundle.py plugins/spec-distill/references/team-files.md plugins/spec-distill/tests/test_conductor_ledger.py plugins/spec-distill/tests/test_human_record.sh plugins/spec-distill/tests/test_human_gate.sh plugins/spec-distill/tests/test_start_bundle.sh plugins/spec-distill/tests/test_workspace_invariance.sh plugins/spec-distill/tests/test_team_docs.py
git commit -m "test(spec-distill): 계획 1 리뷰의 쓰기 · 묶음 쪽 잔여와 시작 묶음 종료 코드 경계를 잰다"
```

---

### Task 11: 역할 문서 — 계획 걸음은 worker, 설계 걸음은 leader

**AC:** AC15(계획 2 몫)

**Files:**
- Modify: `plugins/spec-distill/templates/team/role-leader.md` · `role-designer.md` · `role-worker.md` · `role-writer.md` · `docs/superpowers/roadmaps/{leader,designer,worker,writer}/CLAUDE.md` · `plugins/spec-distill/references/team-files.md`(§6)
- Test: `plugins/spec-distill/tests/test_team_files.py`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_team_files.py` 의 `Templates` 에 더한다:

```python
    BUNDLE_FAILED = "- 시작 묶음 명령이 0 이 아닌 종료 코드로 끝나면 일하지 않고 그 사유를 돌려보낸다."
    DESIGN_STEP = ("- 설계 걸음에서는 원자료(`intent/original.md`) 전체를 읽고 설계문서의 원문 대조 표부터 채운다.",
                   "- 원자료와 다르게 바꾼 것은 근거를 적거나 「작성자 제안」으로 표시한다.")
    PLAN_STEP = "- 계획 걸음에서는 승인된 설계로 계획을 쓰고, 설계에 없던 결정은 표시해 리더에게 돌려보낸다."

    def test_fourth_common_line_is_what_to_do_when_the_bundle_fails(self):   # R2 §5 · K14
        for role in L.ROLES:
            self.assertEqual(F.role_template(role).read_text(encoding="utf-8").splitlines()[5], self.BUNDLE_FAILED, role)

    def test_design_step_is_leaders_and_plan_step_is_workers(self):   # R2 AC15
        todo = {r: F.role_template(r).read_text(encoding="utf-8").split("## 하지 않을 일")[0] for r in L.ROLES}
        for line in self.DESIGN_STEP:
            self.assertIn(line + "\n", todo["leader"])
            for other in ("designer", "writer", "worker"):
                self.assertNotIn(line, todo[other], other)
        self.assertIn(self.PLAN_STEP + "\n", todo["worker"])
        for other in ("leader", "designer", "writer"):
            self.assertNotIn("계획 걸음", todo[other], other)
        self.assertNotIn("원자료", F.role_template("designer").read_text(encoding="utf-8"))

    def test_repo_copies_are_the_templates(self):   # 이 레포의 사본 — AC15 「틀과 이 레포의 사본에서」
        for role in L.ROLES:
            self.assertEqual((REPO / "docs/superpowers/roadmaps" / role / "CLAUDE.md").read_bytes(),
                             F.role_template(role).read_bytes(), role)
```

(`REPO` 는 그 파일 머리의 경로 상수 — 없으면 `Path(__file__).resolve().parents[3]` 로 더한다. 레포 설정의 `roadmaps_dir` 이 이 레포에서 `docs/superpowers/roadmaps/` 다.)

붉어질 변이: leader 틀에 설계 줄을 더하되 designer 에서 지우지 않는다(둘째) · 사본 하나를 고치지 않는다(셋째) · 넷째 줄을 worker 에만 둔다(첫째).

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_files.py 2>&1 | tail -3`
Expected: 첫째 · 둘째 FAIL(셋째는 지금도 지난다 — 양성 대조이자 Step 3 뒤의 락)

- [ ] **Step 3: 틀과 사본을 고친다(K14 · K15)**

- 네 틀 — 공통 셋 바로 뒤에 `BUNDLE_FAILED` 줄.
- leader — 「과제를 받으면 바로 시작하지 않고 방향을 사용자에게 먼저 보인다.」 뒤에 K15 의 leader 세 줄(「규칙을 고친 뒤 규칙 검사…」 가 할 일의 끝 줄로 남는다). 하지 않을 일에 K15 의 두 줄.
- worker — 「설계안 승인 뒤에 코드」 뒤에 K15 의 worker 두 줄.
- designer — 설계 걸음 두 줄과 「원자료를 풀어 다시 쓰기」 를 뺀다.
- writer — 넷째 공통 줄만.
- `docs/superpowers/roadmaps/<역할>/CLAUDE.md` 넷 — 틀을 그대로 복사한다(`cp`).
- `references/team-files.md` §6 — 「네 틀이 함께 두는 할 일 셋」 → 「넷」 과 넷째 줄의 글, 「단계와 역할의 대응은 기본값이다. 지휘 절차 개편(R2)의 단계표가 서면 그 표가 정본이다.」 → K25 의 문장(「스크립트의 기본 역할(`--role` 을 주지 않을 때)은 `team_layout` 의 기본값이고, 걸음표의 누가 칸은 리더가 `--role` 로 줄 역할을 보인다.」), 표 아래에 「설계 걸음의 할 일은 leader 문서, 계획 걸음의 할 일은 worker 문서에 있다」 한 줄.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_files.py plugins/spec-distill/tests/test_team_docs.py 2>&1 | tail -1; bash plugins/spec-distill/tests/test_team_write.sh | tail -1; bash plugins/spec-distill/tests/test_start_bundle.sh | tail -1`
Expected: `OK` · 실패 0 · 실패 0(묶음이 역할 문서 글을 싣는 단언이 있으면 새 글로 맞춘다 — 단언을 지우지 않는다)

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/templates/team/role-leader.md plugins/spec-distill/templates/team/role-designer.md plugins/spec-distill/templates/team/role-worker.md plugins/spec-distill/templates/team/role-writer.md docs/superpowers/roadmaps/leader/CLAUDE.md docs/superpowers/roadmaps/designer/CLAUDE.md docs/superpowers/roadmaps/worker/CLAUDE.md docs/superpowers/roadmaps/writer/CLAUDE.md plugins/spec-distill/references/team-files.md plugins/spec-distill/tests/test_team_files.py
git commit -m "feat(spec-distill): 역할 문서의 설계 걸음은 leader 로, 계획 걸음은 worker 로 옮긴다"
```

---

### Task 12: 보내는 글 틀 — 시작 묶음 명령 한 줄과 고정 꼬리

**AC:** AC16(보내는 글 틀 · 고정 꼬리) · AC21(옛 형식의 보내는 글 틀이 그대로다)

**Files:**
- Modify: `plugins/spec-distill/references/conductor-dispatch.md`
- Test: `plugins/spec-distill/tests/test_walk_docs.py`(새로)

**Interfaces:**
- Produces: `conductor-dispatch.md` 의 새 절 `### team 형식 — 계획 · 구현 담당자`(`### 이어 부르기` 뒤)와 그 아래 `text` 펜스 하나. 과제 13 의 지휘 절차가 이 절을 가리킨다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_walk_docs.py` — 머리는 `tests/test_first_cell_check.py` 처럼 이 파일의 폴더와 `scripts` 를 `sys.path` 에 넣는다(`_HERE = Path(__file__).resolve().parent` · `sys.path.insert(0, str(_HERE.parent / "scripts"))` · `sys.path.insert(0, str(_HERE))` — `python3 -m unittest <파일>` 로 돌려도 `test_team_docs` 를 가져올 수 있게). `PLUGIN = _HERE.parent` · `REF = PLUGIN / "references"` · `REPO = PLUGIN.parents[1]`.

```python
TAIL_SENTENCES = ("시작 묶음 명령이 0 이 아닌 종료 코드로 끝나면 일하지 않고 그 사유를 돌려보낸다",
                  "설계의 글자 · 수용 기준 · 사용자에게 보이는 동작에 닿는 물음은 스스로 정하지 않고 멈춰 돌려보낸다")
ALLOWED = {"<SD>", "<로드맵>", "<과제>", "<단계>", "<n>", "<역할>", "<작업 방식>", "<브랜치>", "<백업 경로 | 없음>",
           "<에픽 worktree 절대경로>", "<스위트 잠금 경로>", "<이 agent 이름>", "<초>", "<스위트 명령>", "<이 agent 폴더>", "<설계 파일>"}
BASE = "3b4e582a"   # 계획 2 가 시작한 기본 브랜치 커밋 — 옛 틀의 견줌 기준


def fence_under(text, heading):
    body = text.split("\n" + heading + "\n", 1)[1]
    return body.split("```text\n", 1)[1].split("\n```", 1)[0]


class DispatchTemplate(unittest.TestCase):   # R2 AC16 · AC21
    TEXT = (REF / "conductor-dispatch.md").read_text(encoding="utf-8")

    def test_team_template_is_one_command_and_the_fixed_tail(self):
        block = fence_under(self.TEXT, "### team 형식 — 계획 · 구현 담당자")
        first = block.splitlines()[0]
        self.assertTrue(first.startswith('python3 "<SD>"/scripts/start_bundle.py --roadmap <로드맵> --job <과제> --stage <단계>'), first)
        for flag in ("--plan <n>", "--role <역할>"):
            self.assertIn(flag, first)
        for s in TAIL_SENTENCES:
            self.assertIn(s, block)
        for word in ("git switch --ignore-other-worktrees <브랜치>", "「브랜치 그대로 두기」(3번)", "기준 브랜치 <브랜치>",
                     "작업 방식: <작업 방식>", "실행 방식은", "check_bundle_coverage.py --plan", "가벼운 다시 확인",
                     "AC<번호>: 구현됨 | 미룸 | 빠짐", "suite_lock.py run --lock <스위트 잠금 경로>", "git stash",
                     "TMPDIR=<이 agent 폴더>", "Spec: <설계 파일>", '"<SD>"/references/conductor-dispatch.md 의 `## 마지막 보고`'):
            self.assertIn(word, block, word)

    def test_no_slot_for_describing_the_job(self):
        block = fence_under(self.TEXT, "### team 형식 — 계획 · 구현 담당자")
        self.assertEqual(set(re.findall(r"<[^<>\n]+>", block)) - ALLOWED - {"<번호>"}, set())
        old = fence_under(self.TEXT, "### 계획 agent")                       # 양성 대조 — 찾는 식이 칸을 잡는다
        self.assertIn("<이유>", set(re.findall(r"<[^<>\n]+>", old)) - ALLOWED)

    def test_old_templates_do_not_change(self):   # AC21
        for heading in ("### 계획 agent", "### 구현 agent"):
            block = fence_under(self.TEXT, heading)
            self.assertNotIn("start_bundle", block, heading)
            self.assertTrue(block.startswith("너는 <에픽> 의 "), heading)
        got = subprocess.run(["git", "show", "%s:plugins/spec-distill/references/conductor-dispatch.md" % BASE],
                             cwd=REPO, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        if got.returncode != 0:
            self.skipTest("기준 커밋 %s 을 읽지 못했다(얕은 클론) — 옛 세 틀의 바이트 견줌을 건너뛴다" % BASE)
        old = got.stdout.decode("utf-8")
        for heading in ("### 계획 agent", "### 구현 agent", "### 이어 부르기"):
            self.assertEqual(fence_under(self.TEXT, heading), fence_under(old, heading), heading)
```

붉어질 변이: 꼬리에 `<이유>` 같은 칸을 더한다(둘째) · 두 문장 하나를 지운다(첫째) · 계획 걸음 줄(다시 확인 · 대조)이나 구현 걸음 줄(AC 보고)을 지운다(첫째) · 옛 계획 틀에 시작 묶음 줄을 넣는다(셋째) · 새 절을 옛 틀 안으로 넣어 옛 펜스가 바뀐다(셋째의 바이트 견줌 — 기준은 이 PR 이 머지된 뒤에도 바뀌지 않는 커밋이다).

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_walk_docs.py 2>&1 | tail -3`
Expected: 첫째 · 둘째 FAIL(절이 없다)

- [ ] **Step 3: 틀을 쓴다**

`### 이어 부르기` 의 펜스 뒤에 절 하나. 머리 글(펜스 밖) — 「team 형식 로드맵(머리말 `layout: team`)의 계획 · 구현 담당자에게 보내는 글은 이 펜스 하나이고, 위 `## 늘 싣는 것` 목록을 대신한다 — 흐름 · 과제의 무엇과 왜는 묶음이 가리키는 과제 파일이, 판 번호처럼 이 일에만 줄 말은 보내기 전에 리더가 과제의 결정 기록에 적어 묶음이 싣는다. 채우는 것은 걸음 보기(`walk_table.py next`)의 다음 걸음 칸 · 자리 · 잠금 · 임시 폴더 · 설계 파일 경로뿐이다. 설계 단계 · 설계 없는 흐름이면 명령에서 `--plan <n>` 을 뺀다.」 펜스의 줄 차례:

1. `python3 "<SD>"/scripts/start_bundle.py --roadmap <로드맵> --job <과제> --stage <단계> --plan <n> --role <역할>`
2. 「위 명령을 첫 걸음으로 그대로 돌린다. 시작 묶음 명령이 0 이 아닌 종료 코드로 끝나면 일하지 않고 그 사유를 돌려보낸다.」
3. 「작업 방식: <작업 방식> — 단일 세션과 똑같이, 단계를 빼거나 다시 쓰지 말고 끝까지 돈다. skill 안의 테스트 실행도 그대로 둔다.」
4. 자리 — 옛 계획 틀 첫 줄의 자리 문장 그대로(`<브랜치>` · `<백업 경로 | 없음>` · `<에픽 worktree 절대경로>`).
5. 미리 받은 답 — 「머지 메뉴는 「브랜치 그대로 두기」(3번) · 기준 브랜치 <브랜치>. 실행 방식은 걸음 보기가 낸 구현 걸음의 작업 방식 칸이다(H11 ① — 사용자 2026-11-20 「넷 모두 권장대로」). writing-plans 끝의 계획 검토 질문은 미리 받은 답이 없다 — 멈추고 (a) 쉬운 요약 (b) 원문을 돌려보낸다.」
6. 「설계의 글자 · 수용 기준 · 사용자에게 보이는 동작에 닿는 물음은 스스로 정하지 않고 멈춰 돌려보낸다.」
7. 계획 걸음이면 — 「계획의 첫 과제는 가벼운 다시 확인이다 — 설계가 근거로 든 자리가 지금 코드에서도 그런지 보고, 달라졌으면 멈춰 보고한다. 계획을 커밋한 뒤 python3 "<SD>"/scripts/check_bundle_coverage.py --plan <설계 파일> 에 묶음 「쓸 자리」 의 계획 파일 경로를 붙여 돌려 빠진 AC 를 계획에 더한다 — 설계가 계획을 여럿으로 나눴으면 이 계획 몫 AC 를 설계의 계획 나누기에서 정해 --acs 로 준다.」(K23)
8. 구현 걸음이면 — 「마지막 전체 리뷰는 설계 파일 ## Acceptance Criteria 가운데 이 계획 몫 AC(계획의 AC 가르기)를 AC 마다 한 줄 AC<번호>: 구현됨 | 미룸 | 빠짐 — 근거 로 보고하게 하고, 과제 사이 이음매와 계획이 쓴 테스트 코드, 설계의 있는 것 검토가 고른 것을 실제로 썼는지도 묻게 한다. 구현 커밋마다 Spec: <설계 파일> 트레일러.」(K23)
9. 스위트 잠금 줄 — 옛 틀의 문장 그대로.
10. 「마지막 보고는 "<SD>"/references/conductor-dispatch.md 의 `## 마지막 보고` 칸이다.」
11. 금지 줄 — 옛 틀 그대로.

자리 · 잠금 · 금지 줄은 옛 틀의 문장을 그대로 써도 된다(펜스가 20줄보다 짧아 중복 락에 걸리지 않는다 — Step 4 가 잰다). 펜스와 머리 글에 `AskUserQuestion` 낱말을 쓰지 않는다(`shared/tests/test_ask_recommendation.sh` 가 그 낱말의 자리를 모두 목록과 견준다).

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_walk_docs.py 2>&1 | tail -1; bash plugins/spec-distill/tests/test_conductor_dispatch_reference.sh | tail -1; bash plugins/spec-distill/tests/test_repo_literals.sh | tail -1; bash shared/tests/test_no_new_duplication.sh | tail -1; bash shared/tests/test_ask_recommendation.sh | tail -1`
Expected: `OK` · 실패 0 넷

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/references/conductor-dispatch.md plugins/spec-distill/tests/test_walk_docs.py
git commit -m "feat(spec-distill): team 형식 담당자에게 보내는 글을 시작 묶음 명령 한 줄과 고정 꼬리로 둔다"
```

---

### Task 13: 지휘 절차 · 승인 게이트 — 사용자 자리 다섯 · 질문 머리 · 승인 줄 명령 · 통과 라벨 락

**AC:** AC17 · AC16(지휘 절차의 보내기 걸음) · AC23(PR 전 확인에서 `human-check` 출력을 그대로 보인다)

**Files:**
- Modify: `plugins/spec-distill/references/conducting.md` · `plugins/spec-distill/skills/epic-conductor/SKILL.md` · `plugins/spec-distill/references/proceed-gate.md` · `plugins/spec-distill/skills/spec-review/SKILL.md`
- Test: `plugins/spec-distill/tests/test_walk_docs.py` · `plugins/spec-distill/tests/test_human_lines.py`

**Interfaces:**
- Consumes: 과제 12 의 절 이름 · 과제 4 의 명령과 출력 · 계획 1 의 `ask-head` · `record --human` · `human-check`
- Produces: `conducting.md` 의 `## team 형식 로드맵` 절 — `## 손으로 따르는 절차` **바로 앞**에 둔다(`tests/test_conducting_loop.sh:11` 이 끝 절이 `## 손으로 따르는 절차` 임을 단언한다). 이 절을 읽는 테스트는 다음 `## ` 앞에서 끊는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_human_lines.py` 의 `test_spec_label_is_the_one_the_approval_question_offers` 를 아래로 바꾼다(J20 — 나머지 라벨 넷과 승인 질문을 내는 skill):

```python
    def test_pass_labels_are_the_ones_the_questions_offer(self):   # 계획 1 J20 · 미룸(통과 라벨 락에 spec-review)
        ref = REPO / "plugins/spec-distill"
        text = (ref / "references/conducting.md").read_text(encoding="utf-8")
        team = text.split("\n## team 형식 로드맵\n", 1)[1].split("\n## ", 1)[0]
        spec = "「%s %s」" % (H.PASS_LABELS[H.KIND_SPEC][0], H.RECOMMENDED)
        for path in ("references/conducting.md", "references/proceed-gate.md", "skills/spec-review/SKILL.md"):
            self.assertIn(spec, (ref / path).read_text(encoding="utf-8"), path)
        self.assertIn("「%s %s」" % (H.PASS_LABELS[H.KIND_PLAN][0], H.RECOMMENDED), team)
        self.assertIn("「%s %s」" % (H.PASS_LABELS[H.KIND_FLOW][0], H.RECOMMENDED), team)
        for label in H.PASS_LABELS[H.KIND_SKIP]:
            self.assertIn("「%s」" % label, team)
```

`tests/test_walk_docs.py` 에 클래스를 더한다:

```python
POINTER = "team 형식 로드맵이면 아래 `## team 형식 로드맵` 절을 따른다"


def team_section(text):
    return text.split("\n## team 형식 로드맵\n", 1)[1].split("\n## ", 1)[0] if "\n## team 형식 로드맵\n" in text else ""


def step(text, n):
    body = text.split("\n### %d. " % n, 1)[1]
    return body.split("\n### ", 1)[0].split("\n## ", 1)[0]


class ConductingTeam(unittest.TestCase):   # R2 AC17 · AC16 · AC23
    TEXT = (REF / "conducting.md").read_text(encoding="utf-8")
    TEAM = team_section(TEXT)

    def test_five_seats_and_the_walk_first(self):
        for seat in ("방향 확인", "설계 대화와 승인", "계획 확인", "구현 중 물음", "PR 전 확인"):
            self.assertIn("| %s |" % seat, self.TEAM, seat)
        for word in ("scripts/walk_table.py next --roadmap <로드맵> --job <과제>", "걸음표를 따른다", "다음 걸음의 칸으로",
                     "conductor-dispatch.md` 의 `### team 형식 — 계획 · 구현 담당자",
                     "ledger ask-head --human <종류> --roadmap <로드맵> --job <과제>", "ledger record --human <종류> --roadmap <로드맵> --job <과제>",
                     "ledger human-check --roadmap <로드맵> --job <과제>", "그대로 보인다", "계획이 나올 때마다", "목록으로 보이고",
                     "실행 방식은 그 칸으로 답한다"):
            self.assertIn(word, self.TEAM, word)
        self.assertNotIn("--approval", self.TEAM)
        self.assertNotIn("--choice", self.TEAM)

    def test_section_sits_before_the_manual_steps(self):   # test_conducting_loop.sh:11 과 같은 사실을 여기서도
        heads = [l for l in self.TEXT.splitlines() if l.startswith("## ")]
        self.assertEqual(heads[-2:], ["## team 형식 로드맵", "## 손으로 따르는 절차"])

    def test_one_pointer_per_step_before_the_skill_cell(self):   # AC21 · K17 — 걸음마다 「- 부를 skill:」 바로 앞
        self.assertIn("ledger record --spec <설계문서> --approval --date <YYYY-MM-DD> --choice", self.TEXT)   # 옛 형식 줄은 그대로
        for n in (2, 3, 4, 5):
            lines = step(self.TEXT, n).splitlines()
            at = [i for i, l in enumerate(lines) if POINTER in l]
            self.assertEqual(len(at), 1, n)
            self.assertTrue(lines[at[0] + 1].startswith("- 부를 skill:"), n)
        for n in (1, 6, 7):
            self.assertNotIn(POINTER, step(self.TEXT, n), n)

    def test_gate_docs_carry_the_head_record_human_and_the_off_path(self):
        for path in (REF / "proceed-gate.md", PLUGIN / "skills/spec-review/SKILL.md", PLUGIN / "skills/epic-conductor/SKILL.md"):
            self.assertIn("ask-head", path.read_text(encoding="utf-8"), path.name)
        for path in (REF / "proceed-gate.md", PLUGIN / "skills/spec-review/SKILL.md"):
            text = path.read_text(encoding="utf-8")
            self.assertIn('record --human "spec 승인"', text, path.name)
            self.assertIn("human_gate: 끔", text, path.name)
```

붉어질 변이: team 절에서 `계획대로 구현한다 (권장)` 를 다른 글로(라벨 락) · `PASS_LABELS` 의 글을 바꾼다(라벨 락) · spec-review SKILL.md 에서 승인 라벨을 지운다 · 가리킴 줄 하나를 「- 판단:」 바로 뒤로 옮긴다(넷째의 다음 줄 단언) · 걸음 1 에 가리킴 줄을 더한다 · team 절을 파일 끝으로 옮긴다(셋째 · `test_conducting_loop.sh`) · team 절에 `--approval` 을 쓴다 · 꺼졌을 때의 문장을 지운다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_walk_docs.py plugins/spec-distill/tests/test_human_lines.py 2>&1 | tail -3`
Expected: `ConductingTeam` 넷과 라벨 테스트 FAIL

- [ ] **Step 3: 문서를 쓴다**

글 어디에도 `AskUserQuestion` 낱말을 새로 쓰지 않는다 — 「질문 창」 이라고 쓴다(`shared/tests/test_ask_recommendation.sh` 가 그 낱말의 자리를 모두 `shared/tests/fixtures/ask-sites.tsv` 와 견준다. 써야 하면 그 목록에 행을 더한다).

- `references/conducting.md`
  - 걸음 2 · 3 · 4 · 5 마다 그 걸음의 「- 부를 skill:」 줄 **바로 앞**에 새 줄 `- team 형식 로드맵이면 아래 `## team 형식 로드맵` 절을 따른다 — 걸음표와 이 절의 문장이 다르면 걸음표를 따른다.` 넷(판단 칸 밑의 하위 글머리를 끊지 않는다). 있는 줄은 고치지 않는다.
  - `## 손으로 따르는 절차` 바로 앞에 `## team 형식 로드맵` 절:
    - **걸음 보기 먼저.** 담당자를 보내기 전에 `python3 "<SD>"/scripts/walk_table.py next --roadmap <로드맵> --job <과제>` 를 돌린다. 담당자는 늘 그 출력의 **다음 걸음의 칸으로** 보낸다(누가 → `--role` · 단계 → `--stage` · 작업 방식 → 틀의 `<작업 방식>`). 막는 것이 `없음` 이 아니면 보내지 않는다. 지휘 절차의 문장과 표가 다르면 걸음표를 따른다. 같은 걸음을 다시 보내는 것(끊긴 담당자 · 받아지지 않은 시도)은 시작 묶음의 이어 쓰기 · 다음 시도 규칙이 정한다.
    - **작업 방식.** 작업 방식은 걸음 보기가 낸 칸이다. 계획 skill 이 끝에 묻는 실행 방식은 그 칸으로 답한다 — 사용자에게 따로 묻지 않는다(H11 ① — 사용자 2026-11-20 「넷 모두 권장대로」).
    - **사용자 자리 다섯** — 설계 §6 의 표(자리 · 리더가 보이는 것 · 남는 것) 다섯 행 그대로와, 그 아래 글머리 넷(설계 §6 의 「PR 전 확인은 줄로 남기지 않는다」 · 「리더는 직접 만들지 않는다」 · 「검수의 기준」 · 설계 대화에서 「리더가 혼자 정해 둔 것이 있으면 문서를 쓰기 전에 목록으로 보이고 하나씩 답을 받는다」 와 그 표시 「작성자 제안」).
    - **사람 줄이 될 질문.** 띄우기 전에 `ledger ask-head --human <종류> --roadmap <로드맵> --job <과제> [--plan <n>]` 의 머리를 질문 글 맨 앞에 그대로 붙인다. 통과 선택지는 정해진 글자다 — 설계 승인 「승인 — 계획 담당자에게 (권장)」 · 계획 확인 「계획대로 구현한다 (권장)」 · 흐름 승인 「설계 없이 진행 (권장)」 · 건너뛰기 「건너뛴다」 · 멈춘 구현 다시 하기 「다시 시도한다」. 다른 선택지와 설명은 리더가 정한다(K18). 건너뛰기 질문은 건너뛸 관문의 이름 하나만 쓴다. 답을 받으면 같은 세션에서 바로 `ledger record --human <종류> --roadmap <로드맵> --job <과제> [--plan <n>] [--gate "<관문 이름>"]` 을 돌리고, 그 브랜치 worktree 에서 INTENT.md 를 바로 커밋 · push 한다. 승인받을 글은 질문 전에 커밋돼 있어야 한다(`ask-head` 가 1 이면 커밋하고 다시). 같은 머리로 다시 물었을 때 사람이 다른 라벨을 고르면 앞 줄은 더 지나지 않는다(K9).
    - **계획 확인.** 계획이 나올 때마다 리더가 검수하고, 검수 결과 · 계획 요약 · 설계에 없던 결정을 보인 뒤 위 질문(머리 `<과제> plan <n> @<판>`)을 띄운다. 설계에 없던 결정이 없어도 묻는다.
    - **보내기.** 글은 `conductor-dispatch.md` 의 `### team 형식 — 계획 · 구현 담당자` 펜스 하나다. 덧붙일 말은 결정 기록에 먼저 적는다.
    - **멈춘 묶음.** 담당자가 돌려보낸 시작 묶음의 종료 코드를 읽는다 — 1 은 관문 · 머지된 계획 · 연속 실패 등 사유 줄의 할 일 하나를 한다, 3 은 읽지 못한 것이라 사유를 보이고 고친 뒤 다시 보낸다(INTENT.md 머리를 읽지 못한 경우 로드맵 블록은 1 · 로드맵 밖 과제는 3 — 형식 정본 §9). 연속 실패 멈춤은 사용자에게 가서 다시 할지 묻는다(위 「다시 시도한다」).
    - **PR 전 확인.** 구현 중 내려진 판정 전부 · 설계 대조 · 스위트 대조 결과 · 승인 뒤 달라진 미룬 항목(`spec 승인` 줄의 판과 브랜치 끝 사이에서 설계문서 `## 미룸` 절과 계획으로 미룬 항목 표의 `git diff`) · `ledger human-check --roadmap <로드맵> --job <과제>` 의 출력을 고치지 않고 그대로 보인다. `REVIEW.md` 의 기준에 비춘 결과도 함께.
    - **관문이 정당한 길을 막으면.** 건너뛰기 질문 → `걸음 건너뜀` 줄. 기록의 꼴이 바뀌어 모든 관문이 닫히면 레포 설정 `human_gate: 끔`(사용자의 머지) — 그때 줄을 적는 길은 형식 정본(`team-files.md`) §5 의 꺼졌을 때 글을 따른다(이 절은 옛 인자 이름을 쓰지 않는다 — 위 락).
- `skills/epic-conductor/SKILL.md` — 208행 근처 「지휘자가 정할 질문 … 앞머리에 에픽 이름을 쓴다」 문단 끝에 한 문장(그 줄의 글은 고치지 않는다 — `test_epic_conductor_skill.sh:235` 가 잡는다): 「team 형식 로드맵에서 사람 줄이 될 질문은 `ledger ask-head` 의 머리로 시작한다 — 절차는 지휘 절차의 `## team 형식 로드맵` 절이다.」
- `references/proceed-gate.md` 「지휘자 아래 — 승인 질문 하나」 문단 끝과 `skills/spec-review/SKILL.md` 「지휘 세션이 돌린 리뷰면 — 승인 질문 하나」 문단 끝에 같은 뜻의 문장: 「team 형식 로드맵의 과제(설계 파일 옆에 INTENT.md 가 있는 과제 폴더)면 질문 글은 `conductor_ledger.py ask-head --human "spec 승인" --roadmap <로드맵> --job <과제>` 가 낸 머리로 시작하고, 승인 줄은 고른 글을 넘기지 않고 `conductor_ledger.py record --human "spec 승인" --roadmap <로드맵> --job <과제>` 가 쓴다 — 그 줄을 쓴 뒤 커밋한다. 레포 설정이 `human_gate: 끔` 이면 형식 정본(`team-files.md`) §5 의 꺼졌을 때 길로 적는다.」 두 문단은 `ask-sites.tsv` 의 「꼬리」 행(끝이 비어 문단 전체가 범위)이 덮는다 — 더한 문장에 도구 이름과 「얻음:」 · 「내줌:」 을 쓰지 않으면 덮는 수 · 설명 수가 그대로다. `test_entry_guidance.sh` 의 순서 검사는 문단에서 처음 나오는 글자만 보므로 문단 끝 문장에 닿지 않는다.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_walk_docs.py plugins/spec-distill/tests/test_human_lines.py 2>&1 | tail -1; for t in test_conducting_reference test_conducting_loop test_epic_conductor_skill test_proceed_gate_adopters test_end_gates test_entry_guidance test_seed_at_path_handoff test_repo_literals test_parallel_recommend_docs test_roadmap_status; do bash plugins/spec-distill/tests/$t.sh | tail -1; done; bash shared/tests/test_invocation_surface.sh | tail -1; bash shared/tests/test_ask_recommendation.sh | tail -1`
Expected: `OK` · 실패 0 열둘. 옛 형식 문장을 잡는 락이 붉으면 있는 줄을 고친 것이다 — 고친 줄을 되돌린다(락을 느슨하게 하지 않는다).

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/references/conducting.md plugins/spec-distill/skills/epic-conductor/SKILL.md plugins/spec-distill/references/proceed-gate.md plugins/spec-distill/skills/spec-review/SKILL.md plugins/spec-distill/tests/test_walk_docs.py plugins/spec-distill/tests/test_human_lines.py
git commit -m "feat(spec-distill): 지휘 절차에 team 형식의 사용자 자리 · 질문 머리 · 승인 줄 · 보내기 걸음을 둔다"
```

---

### Task 14: 설계문서 리뷰 프로필 — 표시 없는 결정을 짚는다

**AC:** AC18

**Files:**
- Modify: `plugins/spec-distill/references/docreview-profiles/design-doc.md`
- Test: `plugins/spec-distill/tests/test_walk_docs.py`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```python
class ReviewProfile(unittest.TestCase):   # R2 AC18 · K19
    def test_scope_axis_flags_unmarked_decisions(self):
        text = (REF / "docreview-profiles/design-doc.md").read_text(encoding="utf-8")
        scope = next(l for l in text.splitlines() if l.startswith("- `scope` — "))
        for word in ("「작성자 제안」", "근거가 없", "표시도 없는 결정"):
            self.assertIn(word, scope, word)
```

붉어질 변이: 그 문장을 `scope` 가 아닌 글머리로 옮긴다 · 지운다. 이 줄은 옛 형식 로드맵과 로드맵 밖 리뷰를 포함한 모든 설계문서 리뷰에 닿는다(설계가 요구한 것) — PR 본문에 「AC18 은 옛 형식 리뷰에도 닿는다」 를 밝힌다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_walk_docs.py -k ReviewProfile 2>&1 | tail -3`
Expected: FAIL

- [ ] **Step 3: 한 문장을 더한다**

`- `scope` — …` 글머리 끝에: 「사용자 원문이나 정답 출처의 번호 항목에 근거가 없는데 「작성자 제안」 표시도 없는 결정은 그 자리를 짚어 `scope` 로 낸다(처분 `decide` — 표시를 달거나 근거를 적을지는 사용자가 정한다).」 31행 · 86행(「brief · 에픽 묶음」 괄호)은 건드리지 않는다.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_walk_docs.py 2>&1 | tail -1; for t in test_raw_source_profiles test_design_profile_source test_handoff_context_section_required test_reviewing_spec_residue test_reviewing_spec_entry_fence; do bash plugins/spec-distill/tests/$t.sh | tail -1; done`
Expected: `OK` · 실패 0 다섯

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/references/docreview-profiles/design-doc.md plugins/spec-distill/tests/test_walk_docs.py
git commit -m "feat(spec-distill): 설계문서 리뷰가 근거도 작성자 제안 표시도 없는 결정을 짚는다"
```

---

### Task 15: P8 과 CLAUDE.md

**AC:** AC19

**Files:**
- Modify: `docs/philosophy/devbrew-harness-philosophy.md`(84행) · `CLAUDE.md`(30행) — 그리고 사본 훑기에서 고칠 것으로 고른 자리
- Test: `plugins/spec-distill/tests/test_walk_docs.py`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```python
NEW_P8 = ("정석 흐름(brainstorming → 계획 → 구현)의 걸음 안은 모델이 판단한다. 사람이 정하는 자리(설계 승인 · 계획 확인)를 건너뛰지 못하게 "
          "하는 것은 정확성 게이트라 스크립트가 지키고, 사람이 승인하면 건너뛰거나 바꾼다. 게이트가 재는 것은 모델이 적은 줄이 아니라 사람이 한 것이다.")
OLD_P8 = "정석 흐름(brainstorming → 계획 → 구현)의 의도는 지키되 순서를 강제하는 결정론은 두지 않는다."
NEW_CLAUDE = "결정론은 보안 · 정확성 게이트에만 — 사람이 정하는 자리를 지키는 관문이 그 게이트다(철학 P8)."
OLD_CLAUDE = "결정론은 보안 · 정확성 게이트에만(철학 P8)."


class Philosophy(unittest.TestCase):   # R2 AC19 — §7 의 문장 그대로
    def test_p8_flow_line(self):
        text = (REPO / "docs/philosophy/devbrew-harness-philosophy.md").read_text(encoding="utf-8")
        flow = [l for l in text.splitlines() if l.startswith("- (흐름) ")]
        self.assertEqual(len(flow), 1)
        self.assertIn(NEW_P8, flow[0])
        self.assertNotIn(OLD_P8, text)
        self.assertNotIn("순서를 강제하는 결정론", text)   # 뜻으로 — 옛 문장의 가운데 말

    def test_claude_md_bullet(self):
        text = (REPO / "CLAUDE.md").read_text(encoding="utf-8")
        line = next(l for l in text.splitlines() if l.startswith("- **기본값과 판단.**"))
        self.assertIn(NEW_CLAUDE, line)
        self.assertNotIn(OLD_CLAUDE, text)
```

붉어질 변이: 옛 문장을 남긴 채 새 문장을 덧붙인다(부재 단언) · 새 문장을 (흐름) 줄이 아닌 줄에 둔다 · 「순서를 강제하는 결정론」 을 다른 줄에 남긴다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_walk_docs.py -k Philosophy 2>&1 | tail -3`
Expected: 둘 FAIL

- [ ] **Step 3: 문장을 바꾸고 사본을 훑는다**

- 철학 84행 — (흐름) 줄의 「— 」 뒤 옛 문장을 `NEW_P8` 으로(앞의 「규칙은 「기본은 X, …」로 쓴다」 는 그대로). CLAUDE.md 30행 — 옛 문장을 `NEW_CLAUDE` 로.
- 사본 훑기(설계 §7) — 낱말이 아니라 뜻으로: `git grep -n -e '순서를 강제' -e '정석 흐름' -e '순서를 고정하지 않' -e '흐름을 고정하지 않' -e 'P8' -- ':!docs/superpowers/plans' ':!docs/superpowers/specs' ':!docs/superpowers/interview' ':!docs/superpowers/roadmaps/*/R*.md' ':!docs/superpowers/roadmaps/*/E*.md' ':!docs/superpowers/roadmaps/*/P*.md' ':!docs/superpowers/roadmaps/*/framing-ledger.md'`. 계획을 쓸 때 본 후보 — `plugins/spec-distill/references/conducting.md` 5행 · 92행(「정석 흐름 … 의 뜻은」) · `plugins/spec-distill/references/brief-handoff.md` 12행과 그 인용 `plugins/spec-distill/tests/test_review_handoff_order.sh` 86행 · `plugins/spec-distill/README.md` 107행과 `plugins/spec-distill/tests/test_epic_handoff.sh` 62행의 「흐름을 고정하지 않는다」 락. 줄마다 새 뜻(걸음 안은 모델 · 사람 자리는 스크립트)과 맞는지 보고, 어긋나면 고치고(지휘 절차의 줄은 K17 대로 옛 형식 줄이라 그대로 두되 그 이유를 적는다) 맞으면 그대로 둔다. 지나간 계획 · 설계 · 인터뷰 · 로드맵 기록은 고치지 않는다. **고친 것과 그대로 둔 것과 이유의 목록을 과제 보고에 적는다 — PR 본문에 그대로 싣는다(AC19).**

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_walk_docs.py 2>&1 | tail -1; bash plugins/spec-distill/tests/test_review_handoff_order.sh | tail -1; bash plugins/spec-distill/tests/test_epic_handoff.sh | tail -1`
Expected: `OK` · 실패 0 · 실패 0. 철학 문서 · CLAUDE.md 를 코퍼스로 읽는 다른 락은 `git grep -l 'devbrew-harness-philosophy.md\|CLAUDE.md' -- '*.sh' '*.py'` 로 찾아 함께 돈다.

- [ ] **Step 5: 커밋**

```bash
git add docs/philosophy/devbrew-harness-philosophy.md CLAUDE.md plugins/spec-distill/tests/test_walk_docs.py
git commit -m "docs(philosophy): P8 흐름 줄과 CLAUDE.md 를 사람 자리를 지키는 관문의 뜻으로 고친다"
```

(사본 훑기에서 고친 파일이 있으면 같은 커밋의 pathspec 에 더한다.)

---

### Task 16: 문서와 판 · 전체 스위트

**AC:** AC22(계획 2 몫 — 걸음표 · `walk_table`)

**Files:**
- Modify: `plugins/spec-distill/references/team-files.md` · `plugins/spec-distill/README.md` · `plugins/spec-distill/CHANGELOG.md` · `plugins/spec-distill/.claude-plugin/plugin.json`
- Test: `plugins/spec-distill/tests/test_walk_docs.py`

- [ ] **Step 1: 문서 락을 쓴다(실패하는 테스트)**

```python
class Docs(unittest.TestCase):   # R2 AC22 — 계획 2 몫
    def test_team_files_documents_the_walk_table(self):
        text = (REF / "team-files.md").read_text(encoding="utf-8")
        for word in ("### 걸음표", "references/walk-table.md", "walk_table", "walk_table.py next --roadmap <로드맵> --job <과제>",
                     "walk_table.py check", "관문은 이 표로 바뀌지 않는다", "기본 표로 넘어가지 않는다", "계획 n/m") + W.COLUMNS:
            self.assertIn(word, text, word)

    def test_readme_and_changelog(self):
        readme = (PLUGIN / "README.md").read_text(encoding="utf-8")
        for word in ("walk_table", "walk_table.py next", "걸음표"):
            self.assertIn(word, readme, word)
        version = json.loads((PLUGIN / ".claude-plugin/plugin.json").read_text(encoding="utf-8"))["version"]
        sections = [body for ver, body in changelog_entries((PLUGIN / "CHANGELOG.md").read_text(encoding="utf-8"))
                    if ver == version_tuple(version)]
        self.assertEqual(len(sections), 1, version)   # 판 번호로 고른다 — 리터럴 판을 박지 않는다
        for word in ("walk_table", "walk_table.py", "걸음표", "conductor-dispatch.md", "P8"):
            self.assertIn(word, sections[0], word)
```

(`changelog_entries` · `version_tuple` 은 `tests/test_team_docs.py` 에서 가져온다 — `from test_team_docs import changelog_entries, version_tuple`(과제 12 의 머리가 이 파일의 폴더를 `sys.path` 에 넣어 `python3 -m unittest <파일>` 로도 가져온다). `W` 는 `import walk_table as W`, `H` 는 `import human_lines as H`.) 첫 테스트의 낱말 목록에 `H.LATER_ANSWER` · `H.NOT_TOUCHED` · `"(끝남)"` · `"다음 걸음의 칸으로"` 를 더한다 — 문서가 코드의 상수 글을 그대로 싣는지 잰다.

붉어질 변이: plugin.json 판을 올리고 CHANGELOG 절을 쓰지 않는다 · 절에 `walk_table` 을 빼먹는다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_walk_docs.py -k Docs 2>&1 | tail -3`
Expected: 둘 FAIL

- [ ] **Step 3: 문서를 쓴다**

- `references/team-files.md` — §10 뒤(`### 사람 줄의 판정` 다음, `## §15` 앞)에 `### 걸음표`: 파일 자리(플러그인 `references/walk-table.md` · 레포 설정 `walk_table` — 기본 브랜치의 커밋에서 읽고 깨졌거나 없으면 기본 표로 넘어가지 않는다) · 꼴(K1 · 칸 일곱 · 빈 칸 `—` · 검사하는 칸 K2) · 「관문은 이 표로 바뀌지 않는다」 · 명령 둘과 종료 코드 · 걸음 보기의 출력 여섯 줄과 자취 표(과제 4 의 표 그대로) · 닻 이름(K4) · 막는 것(K6) · PR 캐시(K5). §9 의 단계별 「기본 역할」 글머리 끝에 K25 의 문장(과제 11 이 §6 에 쓴 것과 글자까지 같게). §10 의 받음 줄 다시 계산 글머리(645–648행 — 「받은 뒤 바뀜」 과 그 셈)에 K13(받은 head 와 지금 끝의 글을 견주고 같으면 세지 않는다 — 설계 · 계획 · INTENT.md 는 본문으로). §2 사람 줄 판정에 K9 · K10 의 두 사유. 문서가 300줄을 넘으므로 `## 목차` 가 있으면 같은 커밋에서 맞춘다.
- `README.md` — 지휘자 절에 걸음표 세 문장(무엇 · `walk_table.py next` · 레포가 바꾸는 길 `walk_table` 과 관문은 바뀌지 않는다는 것). 「Principles Instantiated」 에 줄 둘 — `P8 — 걸음 안은 모델, 사람이 정하는 자리는 스크립트` · `Law 2 — 검수 걸음의 도구 칸은 쓰기 도구 없는 agent 정의다`. 과제 2 의 설정 행은 이미 있다.
- `CHANGELOG.md` — 새 머리 `## [<다음 minor>] — <날짜>`. Added: 기본 걸음표 · `walk_table.py check` · `next` · 레포 설정 `walk_table` · team 형식 보내는 글 틀 · 지휘 절차의 `## team 형식 로드맵` 절 · 리뷰 프로필의 표시 없는 결정 줄. Changed: 역할 문서(설계 걸음 leader · 계획 걸음 worker · 넷째 공통 줄) · 대조 판정의 두 조건 · `human-check` 의 브랜치 끝 · 받음 줄 낡음(본문으로) · (과제 6 을 했으면) 라벨 꼬리 · 철학 P8 (흐름) 줄과 CLAUDE.md. 옛 형식 로드맵은 달라지지 않는다는 한 줄.
- `plugin.json` — 판.

판 번호: `git fetch origin` 뒤 `git show origin/main:plugins/spec-distill/.claude-plugin/plugin.json` 의 판 다음 minor. 기본 브랜치가 그 사이 올랐으면 `git merge origin/main` 으로 먼저 합치고 `## 머지 전 다시 셀 것` 을 센 뒤 그 위의 다음 minor 로 한다(충돌 목록에 없어도 `git diff origin/main -- plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md` 로 직접 견준다).

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_walk_docs.py plugins/spec-distill/tests/test_team_docs.py 2>&1 | tail -1; bash shared/tests/test_changelog_integrity.sh | tail -1; bash shared/tests/test_no_new_duplication.sh | tail -1; python3 -m unittest plugins/quality-gates/tests/test_utf8_explicit.py 2>&1 | tail -1`
Expected: `OK` · 실패 0 · 실패 0 · `OK`

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/references/team-files.md plugins/spec-distill/README.md plugins/spec-distill/CHANGELOG.md plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/tests/test_walk_docs.py
git commit -m "docs(spec-distill): 걸음표 · walk_table · 걸음 보기를 문서에 적고 판을 올린다"
```

- [ ] **Step 6: 전체 스위트**

Global Constraints 의 잠금 줄 그대로 돈다. 못 잡으면 주인 · 잡은 시각을 보고한다. `FAILED` 줄마다 이 브랜치의 변경과 닿는지 적는다 — worktree 에서만 나는 기존 실패는 그렇다고 적는다. 이 브랜치에만 있는 실패가 0 이 될 때까지 그 과제의 뜻 안에서 고친다(pathspec 커밋). 기본 브랜치와의 대조는 지휘자의 머지 전 확인이 한다.

---

## 실행 방식의 마지막 전체 리뷰

고른 실행 방식의 마지막 전체 리뷰(subagent-driven 의 브랜치 전체 리뷰 · native 의 마지막 리뷰)의 리뷰어에게 아래를 그대로 싣는다.

- 설계문서 `## Acceptance Criteria` 의 AC 목록 원문과 이 계획의 `## AC 가르기` 표.
- 요청: 계획 2 몫 AC(`AC1 · AC2 · AC9 · AC11 · AC15~AC23`)마다 한 줄씩 `AC<n>: <구현됨|미룸|빠짐> — <근거(파일:줄 · 테스트 이름 · 명령 결과)>` 꼴로 보고하라. 걸친 AC 는 계획 1 몫과 계획 2 몫이 함께 다 됐으면 `구현됨` 이다. AC11 은 미룸 표가 더한 조건 둘(K9 · K10)로 판정한다.
- 요청: 설계문서 `## 있는 것 검토` 가 고른 것을 실제로 썼는지, 같은 것을 다시 만들지 않았는지 줄마다 답하라 — 걸음 보기가 R1 의 단계 계산(`team_status.Reader.progress`)과 상태 보고(`roadmap_status.build`)를 쓰고 단계를 다시 세지 않는가 · 막는 것을 사람 줄의 꼴 판정(`human_lines.missing`)으로 세고 관문 표를 따로 두지 않았는가 · 표 파일을 설정 파일과 같은 길(`repo_defaults._read_blob` · 기본 브랜치)로 읽는가 · 보내는 글이 R1 의 건네는 길(담당자가 받은 명령으로 묶음을 스스로 돌린다)을 쓰는가 · 승인 게이트의 질문 하나를 그대로 근거로 쓰고 새 질문 창을 만들지 않았는가 · 훅을 만들지 않았는가.
- 끝에서 끝 흐름 넷을 따로 물어라 — 각 이음매의 종료 코드 소비와 상태 가정: ① `walk_table.py next` → 리더가 다음 걸음 칸으로 보내는 글 채움 → 담당자가 시작 묶음 명령을 돌림 → 0 아닌 종료 코드면 일하지 않고 돌려보냄 ② 설계 커밋 → `ask-head` → 승인 질문(통과 라벨 글자) → `record --human` → 커밋 → 걸음 보기의 지금 걸음이 「계획」 으로 넘어감 ③ 승인 뒤 같은 머리로 「수정 필요」 → 대조 판정 `어긋남` → 시작 묶음 1 · `human-check` 1 ④ 레포 걸음표의 관문 칸을 비움 → 걸음 보기 · 시작 묶음 · 결과 대조가 모두 그대로 막음.
- 요청: 모델이 적은 글만으로 걸음 보기의 「막는 것: 없음」 이나 관문이 열리는 길이 새로 생겼는지 따로 답하라 — 걸음표 · 설정 · 역할 문서 · 보내는 글 틀을 고쳐서. 설계 Constraints 가 「막지 못한다」 로 적은 것은 빼고 답한다.
- 이 계획이 쓴 테스트 코드(과제 2 · 3 · 5 · 6 · 11 · 12 · 13 · 14 · 15 · 16 의 파이썬 테스트와 과제 4 · 7 · 8 · 9 · 10 의 표)는 계획이 정한 것이라는 표시를 붙여, 덜 보지 말고 같은 눈으로 보라고 적는다. 기존 테스트를 고친 곳(과제 2 의 키 수 · 과제 13 의 J20 테스트 교체)에서 단언이 지워지거나 느슨해지지 않았는지 `git diff origin/main -- plugins/spec-distill/tests` 로 보라고 적는다.
- 옛 형식: `git diff origin/main -- plugins/spec-distill/references/conducting.md` 에서 지워진 줄(`-` 로 시작)이 없는지, `conductor-dispatch.md` 의 옛 세 펜스가 바이트까지 같은지 보라고 적는다.

리뷰 보고는 git 이 추적하지 않는 파일에 적는다 — 지휘자가 준 임시 폴더의 `r2-plan2-ac-report.md`(없으면 상태 루트 `python3 plugins/spec-distill/scripts/state_path.py state-root` 가 내는 폴더 아래 같은 이름). 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올린다 — 올릴 행을 보고에 적고 지휘자가 올린다. PR 을 만들기 전에

`python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.19.2"/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-18-conductor-walk-gates-design.md <보고 파일 경로> --acs "AC1 · AC2 · AC9 · AC11 · AC15~AC23"`

을 돌려 경고를 사용자에게 보인다. PR 본문에는 과제 15 의 사본 훑기 목록(고친 것 · 그대로 둔 것과 이유 — AC19) · 사용자가 정한 넷(H1 (가) · H11 ① · K9 ① · K11 (가) — 2026-11-20 「넷 모두 권장대로」) · 「AC18 의 리뷰 프로필 줄은 옛 형식 로드맵과 로드맵 밖 설계문서 리뷰에도 닿는다」 · `## 머지 전 다시 셀 것` 을 센 결과 · 과제 9 · 10 의 변이 결과 표를 적는다.
