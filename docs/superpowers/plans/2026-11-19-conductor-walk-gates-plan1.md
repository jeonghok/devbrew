# 지휘 걸음과 관문 — 계획 1(사람 줄과 관문) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** team 형식 로드맵에서 사람 줄(설계 승인 · 계획 확인 · 흐름 승인 · 건너뜀)을 스크립트가 세션 기록의 질문 창 답에서만 적게 하고, 시작 묶음과 결과 대조가 그 줄을 세션 기록과 대조해 승인 없는 계획 · 구현을 내주지도 받지도 않게 한다.

**Architecture:** 새 모듈 둘이다 — `session_record.py` 가 세션 기록 파일을 찾아 질문 창의 답을 읽고, `human_lines.py` 가 사람 줄의 꼴 · 통과 라벨 표 · 관문 표 · 판정 둘(꼴 판정 · 대조 판정)을 가진다. 쓰는 자리는 `conductor_ledger.py record --human` 하나다. 단계 계산(`team_status.py`)은 꼴 판정만, 시작 묶음(`start_bundle.py`)과 결과 대조(`job_results.py check`)는 대조 판정을 부른다. 옛 형식 로드맵의 명령과 출력은 건드리지 않는다.

**Tech Stack:** Python 3(레포의 `python3` 는 3.9.6 — 3.9 문법만) · git · bash(macOS 3.2 호환) · unittest · 기존 셸 테스트 도구(`shared/tests/assert.sh` · `plugins/spec-distill/tests/fixtures/team_repo.sh`).

**Spec:** `docs/superpowers/specs/2026-11-18-conductor-walk-gates-design.md` — 이 계획은 그 문서가 나눈 둘 가운데 **계획 1(사람 줄과 관문)** 만 한다. 계획 2(걸음표 · 담당자 보내기 · 사용자 자리 · P8)는 브랜치 `feature/conductor-walk-table` 에서 따로 계획한다. 아래에서 경로는 따로 적지 않으면 `plugins/spec-distill/` 아래다.

## AC 가르기

설계문서 `## Files to Modify` 의 「계획」 칸과 「계획 나누기」 문단으로 갈랐다.

| AC | 몫 | 계획 1 이 하는 부분 | 계획 2 에 남는 부분 |
|---|---|---|---|
| AC3 – AC8 · AC10 – AC14 | 계획 1 | 전부 | — |
| AC9 | 걸침 | 시작 묶음의 관문 확인 전부. 관문 표가 스크립트 상수이고 설정으로 바뀌지 않는다는 테스트 | 걸음표의 관문 칸을 비워도 관문이 그대로라는 테스트(걸음표가 생긴 뒤) |
| AC15 | 걸침 | 계획 단계의 기본 역할 worker · 설계 단계의 기본 역할 leader · 설계 단계의 과제 묶음이 leader 역할을 받는다 | 역할 문서 틀과 이 레포의 사본에서 할 일을 옮기기 |
| AC16 | 걸침 | 시작 묶음의 「맞추는 명령」 줄을 그대로 돌릴 수 있는 꼴로 | 보내는 글 틀 · 고정 꼬리 · 지휘 절차의 보내기 걸음 |
| AC20 | 걸침 | `human_gate` 키와 꺼졌을 때의 동작 · 알림 | `walk_table` 키 |
| AC21 | 걸침 | 옛 형식에서 승인 줄을 적는 옛 명령과 단계 계산이 그대로다 | 옛 형식의 보내는 글 틀이 그대로다 |
| AC22 | 걸침 | `references/team-files.md` · README · CHANGELOG 의 사람 줄 · 관문 · `human_gate` · 바뀐 기본 역할, `dependencies.md` 의 세션 기록 사실 | 걸음표 · `walk_table` |
| AC23 | 걸침 | `conductor_ledger.py human-check` 명령 | 지휘 절차가 PR 전 확인에서 그 출력을 보인다고 적기 |
| AC1 · AC2 · AC17 · AC18 · AC19 | 계획 2 | — | 전부 |

대조 스크립트에 주는 목록: `AC3~AC16 · AC20~AC23`.

## Global Constraints

- **team 형식에서만.** 관문과 사람 줄은 머리말이 `layout: team` 인 로드맵에만 걸린다. 옛 형식 로드맵의 명령 · 출력 · 테스트는 diff 가 없어야 한다(AC21). `tests/test_conductor_ledger.py` 에서 고칠 수 있는 것은 `team_tree` 를 쓰는 클래스뿐이다.
- **통과 라벨(글자 그대로).** `spec 승인` → 「승인 — 계획 담당자에게」 · `계획 검토` → 「계획대로 구현한다」 · `흐름 승인` → 「설계 없이 진행」 · `걸음 건너뜀` → 「건너뛴다」 · 「다시 시도한다」. 고른 글에서 떼는 꼬리는 `(권장)` 하나다.
- **판정 글자.** `지남` · `근거 없음` · `어긋남` · `확인 못 함` · `낡음`.
- **사람 줄 꼴.** `- <종류> · <YYYY-MM-DD> · 「<라벨>」 · <파일>@<판> · 근거 <세션>:<항목>`. `걸음 건너뜀` 은 라벨 뒤에 ` · <관문 이름>` 이 하나 더 온다. 판은 커밋 번호의 앞 8자다. 날짜는 인자로 받지 않는다 — 그 답 항목의 시각에서 스크립트가 정한다(J28).
- **질문 머리.** `<과제 번호> @<판>` 이고 `계획 검토` 만 `<과제 번호> plan <n> @<판>` 이다(예: `R2 @51f1b64d` · `R2 plan 1 @51f1b64d`). 질문 글은 머리로 **시작**해야 한다.
- **관문 이름.** `spec 승인` · `계획 검토 plan <n>` · `다시 시도 plan <n> 시도 <k>` · 설계 없는 흐름은 `다시 시도 구현 시도 <k>`. 이름과 머리는 부분 글자로 찾지 않는다 — 이름 바로 뒤에 숫자가 이어지면 그 이름이 아니다(`plan 1` 은 `plan 12` 안에서 맞지 않는다).
- **관문 표(스크립트 상수).** `design` → 없음 · `plan` → `spec 승인` · `implement` · `review`(계획 n) → `spec 승인` · `계획 검토`(계획 n) · 설계 없는 흐름의 과제(어느 단계든) → `흐름 승인`. 걸음표나 설정에서 읽지 않는다.
- **연속 실패 멈춤 수는 2 로 고정한다.** 설정 키를 두지 않는다.
- **`human_gate`.** 레포 설정 파일(`.devbrew.md`)의 키다. 값은 `켬`(기본) · `끔` 둘이다. 환경 변수로는 꺼지지 않는다. 로드맵 머리말에서는 받지 않는다.
- **종료 코드.** 시작 묶음 · 결과 대조: 관문을 지나지 못하면 1(「확인 못 함」 도 1). `record --human` · `ask-head`: 0 · 1(쓸 답이 없다 · 통과 라벨이 아니다 · 커밋되지 않았다 · 다른 브랜치다) · 2(사용법) · 3(「확인 못 함」 — 세션 기록을 찾지 못함 · 읽지 못함 · 아는 칸이 없거나 꼴이 다름 · 표지 없음). 3 의 글에는 끄는 길(`레포 설정 human_gate: 끔`)을 함께 적는다.
- **세션 기록은 읽기만 한다.** Claude 설정 폴더는 환경 변수 `CLAUDE_CONFIG_DIR` 이 있으면 그 값, 없으면 홈의 `.claude` 다. 테스트는 늘 `CLAUDE_CONFIG_DIR` 를 임시 폴더로 준다 — 실제 설정 폴더를 읽는 테스트를 쓰지 않는다.
- **개인 정보.** 세션 기록에서 추적 파일 · 보고 · 커밋 메시지로 옮기는 것은 칸 이름과 꼴(값의 종류 · 고정 낱말)뿐이다. 대화 내용 · 이메일 · 경로 속 이름 · secret 은 옮기지 않는다. 자료 파일의 글자 값은 자리표시 글자로 바꾼다(과제 1 의 락이 잰다).
- **import 방향.** `session_record` 는 표준 라이브러리만. `human_lines` 는 `session_record` · `team_files` · `team_layout` 을 가져온다. `team_files` · `team_layout` 은 `human_lines` 를 가져오지 않는다. `team_status` · `job_results` · `start_bundle` · `conductor_ledger` 가 `human_lines` 를 가져온다(`job_results` 는 `team_status` 처럼 `roadmap_status` 를 함수 안에서 가져온다).
- **상태 계산의 잠금 목록.** `tests/test_roadmap_status.sh` 의 정적 검사는 상태 계산이 가져오는 스크립트를 이름으로 잠근다(지금 열넷). `human_lines.py` · `session_record.py` 는 그 목록에 든다(과제 5 가 열여섯으로 고친다 — J29). 그래서 두 모듈은 그 검사의 규칙을 지킨다 — **이름이 `replace` · `remove` · `rename` · `mkdir` · `touch` · `unlink` · `write_text` · `write_bytes` · `chmod` · `makedirs` · `rmtree` · `system` · `popen` 인 호출을 쓰지 않는다(글자 · 목록의 `.replace(` · `.remove(` 도 걸린다 — `re.sub` · `split` · `join` · 조각 자르기로 쓴다)** · `open` 은 읽기 모드만 · `subprocess` · `shutil` · `socket` · `urllib` · `http` 를 가져오지 않는다 · 가져오는 로컬 모듈은 그 목록 안의 것뿐이다(`human_lines` 는 `session_record` · `team_files` · `team_layout` · `section6` · `roadmap_model`, `session_record` 는 로컬 모듈 없음). 뒤 과제가 이 두 모듈에 더하는 코드도 같다.
- **레포 락.** `plugins/**/*.py` 에 `"python3"` 따옴표 리터럴 금지(`shared/tests/test_python_floor.sh`) · 스크립트의 `open(` · `.read_text(` 에 `encoding` 필수(주석의 `open(` 도 걸린다 — `plugins/quality-gates/tests/test_utf8_explicit.py`) · `re.compile` 리터럴이 `## ` 로 시작하는 글과 3글자 이상 맞으면 RED(`tests/test_check_brief.sh` — 제목 줄은 정규식이 아니라 문자열 메서드로 가른다) · 같은 20줄(200자 이상) 블록이 두 파일에 있으면 RED(`shared/tests/test_no_new_duplication.sh`) · 새 셸 테스트는 100755 로 커밋한다(`git ls-files -s` 로 확인) · CHANGELOG 새 머리는 바로 다음 판만(`shared/tests/test_changelog_integrity.sh`).
- **정규식은 `fullmatch`.** 줄 꼴과 세션 번호는 `re.fullmatch` 로 본다(`$` 는 끝 줄바꿈 앞에서도 맞는다).
- **bash 3.2.** `set -u` 아래 빈 배열은 `${arr[@]+"${arr[@]}"}` 로 펼친다 · `$var` 바로 뒤에 한글이 오면 `${var}` 로 쓴다.
- **변이.** 변이는 커밋한 뒤에 한다. `PYTHONDONTWRITEBYTECODE=1` 로 돌리고, 되돌림은 `git checkout HEAD -- <파일>` 뒤 `git diff HEAD --stat` 이 비었는지로 확인한다. 통과가 정답인 단언에는 양성 대조(같은 준비에서 관문이 열리는 경우)를 짝으로 둔다.
- **설계문서는 고치지 않는다.** 설계의 글자 · 수용 기준 · 사용자에게 보이는 동작을 더하거나 바꿔야 한다고 보면 멈추고 지휘자에게 돌려보낸다. 설계문서의 `## 미룸` 표에 올릴 것은 보고에 적고 지휘자가 올린다.
- **판.** spec-distill 을 **minor** 로 올린다. 번호는 머지 직전 기본 브랜치(`origin/main`) 위의 다음 minor 다 — 지금 번호를 박지 않는다(과제 13).
- **커밋.** 한국어 Conventional Commits(type · scope 는 영어), pathspec 으로 커밋한다. `git stash` · HEAD 뒤로 옮기기 · 다른 worktree 의 git 을 쓰지 않는다.
- **전체 스위트**는 아래 줄로만 돈다(지휘자 대조와 같은 공유 잠금 — 못 잡으면 주인 · 잡은 시각을 보고한다. `--owner` 는 도는 agent 의 이름으로 바꾼다). 과제 안에서는 그 과제가 이름 댄 테스트만 돈다. 구현 담당이 하위 agent 를 띄우면 그 글에도 이 줄과 경로를 그대로 싣는다:
  `python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.19.2"/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-conductor-context-economy-brief/files/suite-lock --owner r2-plan-1 --wait 10800 -- bash -c 'bash tools/suite/run-all.sh'`

## Review Focus

설계가 뜻하지만 어느 수용 기준도 이름 대지 않는 입력이다. 줄마다 그 코드를 가진 과제에 테스트가 있다.

1. **지금 쓰이고 있는 세션 기록** — `record --human` 은 그 세션이 도는 중에 불린다. 마지막 줄이 반만 쓰인 JSON 이거나 깨진 줄이 섞여도 읽은 줄로 판정하고, 그 줄 때문에 「확인 못 함」 이 되지 않는다(과제 2).
2. **큰 세션 기록** — 지휘 세션의 기록은 수만 줄이다. 질문 창 답이 맨 뒤에 하나 있는 5만 줄 기록에서 답을 찾는다(과제 2).
3. **머리 앞에 글자가 붙은 질문** — 리더가 머리 앞에 공백 · 줄바꿈 · 굵게 표시(`**`)를 붙이면 그 답으로는 쓰지 않고, 사유가 기다린 머리(`<과제> @<판>`)를 그대로 보인다(과제 7).
4. **코드 펜스 안의 제목 줄** — 설계문서 본문의 코드 펜스 안에 `## 결정 기록` 같은 줄이 있어도 거기서 본문이 잘리지 않는다. 펜스 안 글을 고치면 낡음이다(과제 5).
5. **다른 브랜치 · 브랜치 없는 HEAD 에서 부른 `ask-head` · `record --human`** — 쓸 브랜치가 아닌 worktree 에서 부르면 쓰지 않고, 가야 할 브랜치 이름을 보인다(과제 7).

---

## 계획의 판단

설계가 계획에 넘긴 것(Handoff Context · `### Deferred to plan`)과 설계가 정하지 않아 이 계획이 정한 것이다. 범위 · 인터페이스 · 파일 배치 · 사용자에게 보이는 글과 동작에 닿는 것을 모두 적었다.

| # | 자리 | 정한 것 | 이유 | 다른 길 |
|---|---|---|---|---|
| J1 | 근거 칸의 「항목 번호」 | 질문 창 답이 실린 기록 항목의 `uuid` 뒤에 `#<그 호출 안 질문의 순번(1부터)>` 을 붙인다 — `근거 <세션>:<uuid>#<n>` | 이어받은 세션은 앞 기록을 같은 `uuid` 로 복사한다(계획을 쓸 때 잰 것: 질문 창 항목 5건이 파일 둘에 있었다). 줄 번호로 적으면 복사된 같은 답을 두 번 쓸 수 있다. 한 호출의 질문 여럿은 순번으로 가른다 | 파일의 줄 번호 |
| J2 | 사람이 답했는지 가르는 칸 | 답 항목의 `permissionDecision` 이다(설계 §2 — 4bb70b98). `decision` 이 `accept` 이고 `source` 가 허용 목록(`user_temporary`)에 있으면 사람. 칸이 없거나 사전이 아니거나 **수락인데 출처가 허용 목록에도 사람 아님 목록에도 없는 값**이면 「확인 못 함」. `decision` 이 `accept` 가 아니거나 출처가 사람 아님 목록(측정으로 채운다 — 지금은 비었다)에 있으면 사람 아님(「어긋남」) | 사용자가 정했다(2026-11-19). 계획을 쓸 때 잰 답 592건(2.1.296 – 2.1.326)이 모두 허용 목록의 꼴이었다 | 모르는 출처를 「어긋남」 으로 |
| J3 | 이어받은 세션 | 기록 파일은 이름으로 찾고, 항목 안의 `sessionId` 는 대조하지 않는다. 같은 답인지는 `uuid#순번` 으로만 가른다 — 앞 세션을 이어받은 세션은 복사된 앞 답으로 줄을 적을 수 있고, 같은 답은 세션이 달라도 한 번만 근거가 된다(설계 §2 — 4bb70b98) | 계획을 쓸 때 세션 파일 643개에서 파일 이름과 다른 `sessionId` 는 없었고 같은 `uuid` 가 파일 둘에 있는 것이 5건이었다 | `sessionId` 가 파일 이름과 다르면 「어긋남」 |
| J4 | 본문을 견줄 때의 다듬기 | 뺄 절을 뺀 뒤 끝의 빈 줄만 뗀다. 줄 안의 글자는 그대로 견준다 | 기록 절을 빼면 끝의 빈 줄 수가 달라진다 | 줄 끝 공백도 떼기 |
| J5 | 「본문을 마지막으로 바꾼 커밋」 을 찾는 법 | 그 브랜치 끝에서 그 파일을 건드린 커밋을 새것부터 보며, 본문이 끝의 본문과 같은 동안 거슬러 올라간 가장 오래된 커밋 | 승인 게이트가 기록 절만 고친 커밋은 판을 바꾸지 않아야 한다 | 그 파일을 마지막으로 건드린 커밋 |
| J6 | `ask-head` · `record --human` 을 부르는 자리 | 쓸 브랜치를 체크아웃한 worktree 에서 부른다(`--root` 로 줄 수 있다). 지금 브랜치가 쓸 브랜치가 아니면 쓰지 않고 1 로 멈춘다 | AC7 「시작 묶음이 읽는 브랜치 끝의 INTENT.md 에 쓴다」 를 작업 폴더에 쓰는 명령이 지키는 길이 이것뿐이다 | 경로 인자(`--spec`)를 받는다 |
| J7 | 쓸 브랜치 | `계획 검토`(계획 n) → 블록의 n 번째 브랜치. `spec 승인` · `흐름 승인` → 아직 머지되지 않은 가장 앞 브랜치. `걸음 건너뜀` → 관문 이름에 계획 번호가 있으면 그 계획의 브랜치, 없으면 아직 머지되지 않은 가장 앞 브랜치. 로드맵 밖 과제는 INTENT.md 머리의 `branch` | 설계 §2 「쓰는 곳과 때」 를 건너뜀 줄과 로드맵 밖 과제까지 넓혔다 | — |
| J8 | 건너뛸 관문을 주는 인자와 이름 | `--gate "<관문 이름>"`. 이름은 Global Constraints 의 넷이다(설계 없는 흐름의 다시 시도는 `다시 시도 구현 시도 <k>` — 설계 §2 · §4, 4bb70b98). 「건너뛴다」 는 `spec 승인` · `계획 검토 plan <n>`, 「다시 시도한다」 는 다시 시도 이름 둘에만 맞는다 | 인자 이름은 설계 §4 의 `--gate` 그대로다 | — |
| J9 | `human_gate: 끔` 일 때 「줄이 있다」 | 그 종류의 줄이 그 과제의 결정 기록에 하나라도 있으면 지난 것이다(`계획 검토` 는 계획 번호를 가리지 않는다). `걸음 건너뜀` 은 관문 이름이 글자 그대로 든 줄이다(이름 바로 뒤에 숫자가 이어지는 자리는 세지 않는다). `spec 승인` 은 옛 형식과 같은 읽기 규칙(`approval_in`)이다 | 설계 §8 「관문은 줄이 있는지만 본다」. 글로 적은 줄에는 정해진 칸이 없다 | 글로 적은 줄에도 계획 번호 칸을 요구한다 |
| J10 | 꺼져 있다는 알림이 실리는 자리 | 상태 보기는 **도는 과제마다 첫 알림 줄**이다(설계 §8 · AC20 — 4bb70b98) — 단계 계산(`Reader.progress`)이 설계 흐름 · 설계 없는 흐름 · 로드맵 밖 과제 어느 갈래든 그 과제 알림 목록의 맨 앞에 넣는다. 도는 과제가 없으면 실리지 않는다. 시작 묶음은 첫 `알림:` 줄, 결과 대조는 첫 줄 바로 아래 `알림:` 줄, `human-check` 는 첫 줄이다. 글자는 「사람 줄 대조가 꺼져 있다」 | 사용자가 정했다(2026-11-19 「과제마다 첫 알림 줄」). 상태 보기 스크립트의 출력 코드는 고치지 않는다 | — |
| J11 | 머지된 계획을 아는 길(브랜치를 지운 뒤에도) | 상태 보기와 같은 머지 판정(머지 커밋 · PR 캐시 · 머지 메시지)을 쓰고, 여기에 하나를 더한다 — 그 브랜치의 끝이 로컬에도 origin 에도 없는데 기본 브랜치에 그 계획 파일(설계 없는 흐름은 `implement` 결과 파일)이 있으면 머지된 것이다. `team_status.plan_merged` 한 곳에 둔다(계획 2 의 「계획 n/m」 이 같은 함수를 쓴다). **이 더한 갈래로 멈출 때 상태 보기는 그 블록을 머지로 세지 못한다**(머지 수는 `roadmap_status.py` 가 세고 그 스크립트는 고치지 않는다) — 멈춤 글이 그 사실을 함께 적고 `references/team-files.md` 에도 적는다 | Handoff 가 계획에 넘겼다. 계획 파일은 그 계획의 브랜치에서만 생기므로(브랜치 하나에 계획 하나) 브랜치 없이 기본 브랜치에 있으면 머지돼 지워진 것이다. GitHub 가 아닌 origin 에서도 선다 | 더한 갈래를 빼서 두 표면을 맞춘다(GitHub 도 아니고 PR 캐시도 없는 레포에서 지운 브랜치는 둘 다 모른다) · 상태 보기 스크립트의 머지 판정에 같은 갈래를 더한다(설계 §8 의 예외가 하나 더 필요하다) |
| J12 | 연속 실패에서 「산 받음 줄」 이 있는 시도 | 그 결과 파일의 이름과 `head` 를 가리키는 꼴 맞는 받음 줄이 결정 기록에 있고, **그 결과 파일이 결과 대조(`check_result`)를 다시 지난다** — 사유 가운데 「같은 단계 · 같은 계획의 더 새 시도가 있다」 하나만 빼고 본다. 손으로 쓴 받음 줄만으로는(결과 파일이 대조를 지나지 못하면) 받은 시도가 아니다. 「받은 뒤 바뀜」 은 재지 않는다. 「끝」 줄이 없는 시도 · 읽지 못한 시도는 실패로 세지 않고 이어짐을 끊는다 | 설계 §4 · AC13 「산 받음 줄」. R1 의 받음 줄 다시 세기는 가장 새 시도만 재므로 앞 시도는 「더 새 시도가 있다」 로 늘 낡음이 된다 — 그 사유만 뺀다. 다음 시도의 커밋이 앞 시도의 파일을 바꾸므로 「받은 뒤 바뀜」 은 앞 시도에 늘 걸린다 | 꼴만 본다(손으로 쓴 줄 하나로 멈춤이 풀린다) |
| J13 | 「맞추는 명령」 줄 | `맞추는 명령: python3 <roadmap_write.py 의 절대 경로> job sync --result <쓸 것> --role <역할> --bundle-at <기준 커밋> --job-at <과제 브랜치 커밋>` — 경로는 시작 묶음 스크립트와 같은 폴더의 것이고, 셸에 그대로 붙여도 되게 낱말로 감싼다 | AC16 「인자가 채워져 담당자가 그대로 돌릴 수 있다」. 이 플러그인의 다른 넘김 줄이 `python3 <경로>` 꼴이다 | 플러그인 폴더를 환경 변수로 |
| J14 | `roadmap_model.py` | 코드를 고치지 않는다. 지금의 승인 줄 읽기(`approval_in`)가 판 · 근거 칸이 붙은 줄의 날짜를 그대로 읽는다는 것을 테스트로 못 박는다 | 설계 Files to Modify 는 「승인 줄 읽기가 판과 근거 칸을 받게」 라고 적었는데 지금 규칙이 이미 받는다. 판 · 근거 칸을 읽는 곳은 `human_lines` 한 곳이다 | `approval_in` 이 칸을 돌려주게 |
| J15 | 단계 계산의 사유 글자 | 승인 줄이 없으면 지금 글자 그대로(`design.md 있음 · spec 승인 줄 없음`). 줄은 있는데 꼴 판정을 지나지 못하면 `design.md 있음 · spec 승인 줄이 지나지 못했다 — <판정> — <사유>`. 건너뜀 줄로 지났으면 `spec 승인 건너뜀(<날짜>) · …` | AC8 「사유에 판정을 적는다」 | — |
| J16 | 설계 없는 흐름의 단계 계산 | 바꾸지 않는다 — `흐름 승인` 은 관문 두 자리(시작 묶음 · 결과 대조)에서만 본다 | 설계 §3 의 단계 계산 글머리는 `spec 승인` 만 말한다 | 「진행 중」 사유에 흐름 승인 유무를 적는다 |
| J17 | 사람 줄을 모으는 끝과 「지금 본문」 | 줄은 그 과제의 브랜치 끝들과 기본 브랜치에서 모은다(끝을 고를 수 없는 브랜치는 빼고 알린다). 「지금 본문」 은 관문을 묻는 그 브랜치 끝의 파일이다. `human-check` 는 줄마다 고른다 — 계획 번호가 있는 줄은 그 계획의 브랜치 끝, 그 밖은 아직 머지되지 않은 가장 앞 브랜치 끝이고, 끝이 없으면 기본 브랜치다 | 설계 §2 「그 과제의 브랜치들과 기본 브랜치의 끝에서 줄을 모아 읽는다」 | — |
| J18 | 관문 여럿이 닫혔을 때의 사유 줄 | 관문 표의 차례로 첫 관문 하나만 적는다 | 설계 §3 「다음에 할 일 하나」 | 닫힌 관문을 모두 적는다 |
| J19 | 단계 계산이 `human_gate` 를 아는 길 | `team_status.Reader` 가 처음 필요할 때 레포 설정을 스스로 읽는다. 읽지 못하면 켜진 것으로 본다 | `roadmap_status.py` 를 고치지 않는다(설계 §8) | 만드는 쪽이 인자로 준다 |
| J20 | 통과 라벨 표와 승인 질문 글을 함께 지키는 테스트 | 계획 1 은 테스트를 만들고 지금 문서에 질문 글이 있는 `spec 승인` 라벨을 건다. 나머지 라벨 넷은 그 질문 글을 쓰는 계획 2 가 같은 테스트에 더한다 | 나머지 질문 글이 사는 파일(`references/conducting.md` · `references/proceed-gate.md`)은 계획 2 몫이다 | 계획 1 이 그 파일들에 질문 글을 먼저 쓴다 |
| J21 | 두 계획 사이의 역할 문서 | 계획 1 이 머지되면 계획 묶음은 worker 문서를 싣는데 계획 걸음의 할 일은 계획 2 가 옮길 때까지 designer 문서에 있다. PR 본문에 적는다 | 도는 team 형식 로드맵이 없다(설계 Non-goals) | 역할 문서를 계획 1 에서 옮긴다 |
| J22 | 직접 적은 답 · 여럿 고르기 | 사람이 「Other」 로 통과 라벨과 같은 글자를 직접 적은 답은 통과다. 여럿 고르는 질문의 답은 라벨 하나만 골랐을 때만 통과다(여럿이면 쉼표로 이어진 글자라 라벨과 같지 않다) | 기록에는 고른 글자만 남는다. 둘 다 사람이 한 것이다 | 여럿 고르는 질문은 통째로 쓰지 않는다 |
| J23 | 같은 답으로 `record --human` 을 다시 부름 | 쓸 줄이 글자까지 같은 줄로 이미 있으면 쓰지 않고 0, 그 답이 다른 줄의 근거면 1 | 지금 `record` 의 「이미 있어 쓰지 않았다」 와 같게 | 늘 1 |
| J24 | `human-check` 가 내는 것과 종료 코드 | 줄마다 한 줄씩 낸다 — ① 그 과제의 사람 줄마다 `<판정> — <줄>`, `지남` 이 아니면 그 아래 `    사유: <사유>` ② 관문 표로 볼 때 **있어야 하는데 지난 줄이 없는 관문**마다 ``줄 없음 — `<종류>` 줄[(계획 <n>)]`` 과 그 아래 `    사유: <자취>`(예: ``줄 없음 — `계획 검토` 줄(계획 1)`` / `    사유: implement-plan-1-1.md 가 있다`). 있어야 하는 때 — 설계 흐름: 계획 파일 · `plan` · `implement` · `review` 결과 파일 · 받음 줄 가운데 하나라도 있으면 `spec 승인`, 계획 n 의 `implement` · `review` 결과 파일이나 받음 줄이 있으면 `계획 검토`(계획 n). 설계 없는 흐름: 결과 파일이나 받음 줄이 있으면 `흐름 승인`. 그 종류의 줄이 있는데 지나지 못한 것은 ① 이 이미 보이므로 ② 에 다시 내지 않는다. 낼 줄이 하나도 없으면 `사람 줄 없음` 한 줄. 종료 코드: 0 모든 줄이 `지남` 이고 `줄 없음` 이 없다 · 1 그 밖 · 2 사용법 · 3 로드맵 · 레포를 읽지 못함 | AC23 은 줄마다 판정을 낸다고만 한다. 설계 §3(D4.16)이 드러내려는 길 — 승인 줄 없이 받음 줄을 손으로 적은 것 — 은 있는 줄만 보면 0 으로 깨끗하게 나온다 | 있는 줄만 판정한다 |
| J25 | 테스트가 사람 줄을 만드는 길 | 손으로 줄을 적지 않는다. 자료에서 만든 가짜 세션 기록(`tests/fixtures/session_fixture.py`)과 `ask-head` · `record --human` 을 실제로 부르는 도우미(`tests/fixtures/team_repo.sh` 의 `human`)로 만든다 | 관문 아래에서는 손으로 적은 승인 줄이 「근거 없음」 이다. R1 의 team 테스트가 계획 · 구현 묶음을 받으려면 진짜 꼴의 줄이 필요하다 | 테스트 레포를 `human_gate: 끔` 으로 |
| J26 | 사람 없이 답이 나오는 길의 측정 | 구현 담당은 Claude Code 를 다시 띄우지 않는다. 지휘자가 따로 재서 값을 보낸다(헤드리스 · 권한 모드 · 훅 · 모델이 `answers` 를 스스로 채우는 길). 받은 값을 반영하는 자리는 이 계획 끝 「측정 값을 받으면」 한 곳이다. 받기 전에는 허용 목록(J2)으로 가고 「재지 못함」 에 적는다 | 허용 목록은 모르는 값을 「확인 못 함」 으로 본다 — 닫힌 쪽이다 | 구현 담당이 `claude -p` 로 잰다 |
| J27 | `started()` 가 쓰는 승인 읽기 | 그대로 둔다(`Reader.approved`) | 그 함수는 관문이 아니라 「지워진 브랜치인가 아직 만들지 않은 브랜치인가」 를 가르는 흔적이다 | 꼴 판정으로 바꾼다 |
| J28 | 사람 줄의 날짜 | 인자로 받지 않는다(`--date` 없음). `record --human` 은 **그 답 항목의 `timestamp`** 를 이 기계의 지역 시각으로 바꾼 날짜를 적는다. 대조 판정은 줄의 날짜가 그 시각의 날짜(UTC)와 하루 넘게 다르면 「어긋남」 이다(시간대 차이는 하루를 넘지 않는다). 답 항목에 `timestamp` 가 없거나 읽지 못하면 「확인 못 함」 | 설계의 명령 꼴(§2 「쓰는 길」)에 날짜 인자가 없다. 날짜가 단계 사유(`spec 승인됨(<날짜>)`)에 그대로 실리므로 지어낼 길을 남기지 않는다 — 근거 자신에서 나온다 | 명령이 도는 날의 날짜(시계를 믿는다) · UTC 날짜(아침 일찍 한 승인이 전날로 적힌다) |
| J29 | 상태 계산의 잠금 목록 | 새 모듈 둘을 `tests/test_roadmap_status.sh` 의 정적 검사 목록(열넷 → 열여섯)과 변이 사본 목록 둘에 넣는다. 두 모듈은 그 검사의 규칙(Global Constraints)을 지켜 쓴다 — 상태 계산이 가져오는 쪽과 아닌 쪽으로 가르지 않는다 | 두 모듈 모두 읽기만 한다. `team_status` · `job_results` 가 `human_lines` 를 가져오고 `human_lines` 가 `session_record` 를 가져온다 | 대조 판정을 다른 파일로 갈라 상태 계산이 `session_record` 를 가져오지 않게 한다 |
| J30 | 머지된 계획 멈춤이 걸리는 단계 | 모든 단계다(`design` 포함 — `--plan` 이 없으면 첫째 브랜치를 본다) | 설계 §3 「머지가 끝난 계획」 과 AC14 에 단계 제한이 없다. R1 이 단순 작업에 정한 것(B35)도 단계를 가리지 않는다 | `plan` · `implement` · `review` 에만 |
| J31 | 결과 대조가 관문을 보는 결과 | 대조하는 결과 파일의 **단계로 §3 표를 본다** — `design` 결과는 없음 · `plan` 결과는 `spec 승인` · `implement` · `review` 결과는 `spec 승인` 과 `계획 검토`(계획 n) · 설계 없는 흐름의 결과는 `흐름 승인` | §3 표의 머리가 「달라는 묶음 · 받는 결과」 이고 `plan` 줄이 `spec 승인` 이다. AC10 · §3 글머리가 말하는 구현 결과는 이 규칙의 한 줄이다. 받음 줄이 단계를 넘기는 것은 구현뿐이지만(§4) 명령은 `plan` 결과도 대조하고 받음 줄을 낸다(R1 §5) | `implement` 결과에만 건다 |
| J32 | 결과 대조가 흐름을 정하는 길 | 로드맵에서만 정한다 — 그 과제가 블록이면 `Reader.flow(블록)`(산출물 칸이 있으면 설계 없는 흐름 — R1), 블록이 아니면(로드맵 밖 과제) 설계 없는 흐름이다. `--branch` 는 읽을 브랜치만 정하고 흐름을 바꾸지 않는다 | 블록 과제에 `--branch` 를 준다고 관문이 `흐름 승인` 으로 바뀌면 안 된다 | — |
| J33 | 꼴이 달라진 기록 항목 | 질문 창 호출에 짝지어진 결과 항목인데 읽을 칸이 없거나 꼴이 다르면(`isSidechain` 칸 없음 · `sourceToolAssistantUUID` 없음 또는 호출 항목과 다름 · `toolUseResult` 가 사전이 아님 · `answers` 가 사전이 아님 · 그 질문의 답이 없거나 글자가 아님 · `timestamp` 없음) 「답이 아니다」 로 넘기지 않고 `알 수 없음` 으로 싣는다 — `record --human` 은 3, 대조 판정은 「확인 못 함」 이다. 답이 아닌 것으로 넘기는 것은 꼴을 아는 것뿐이다 — 거절(`is_error: true`) · `isSidechain: true` · 짝이 되는 호출이 그 파일에 없는 결과 | 칸 이름이 바뀐 판에서 조용히 「없다」(1 · 「어긋남」)가 되면 다시 묻고 또 1 이 나오는 일을 되풀이한다. 3 은 끄는 길을 안내한다(AC6) | 꼴이 다르면 답이 아닌 것으로 넘긴다 |

**`### Deferred to plan` 확인.** 표의 항목을 Handoff 가 말한 둘로 갈랐다. 장치를 빼서 해당 없는 것 — `964aa074`(물음 옮기기 대조) · `56f7a2b9`(PR 전 확인 줄) · `f29944a4`(연속 실패 설정 키) · `0764aeb1` · `a94449da`(옛 형식 검사) · `68f5b017` 의 옮긴 물음 부분. 계획 1 이 받는 것 — `2e6610eb`(훅 · 키 입력을 측정 목록에 → 과제 1 · J26) · `eac92f65`(부른 세션을 기록으로 증명하는 길이 되는지 → 과제 1 이 재서 보고만 한다. 동작은 더하지 않는다) · `d0120803#r4.1`(머지된 계획을 아는 길 → J11). 그 밖은 설계 본문에 반영돼 있고 계획 1 의 과제가 그 본문을 따른다(`4e9c6b95` → 과제 7 의 커밋 검사 · `d0120803#r2.1` → 과제 11 · `a7e7e856` · `dd52ae68` → 과제 4 · `abcf8f1a` → Global Constraints · `226040f3` · `0dad47c7`(막힘은 세지 않는다) → 과제 10 · `f5a6cb16` · `71edd879` → J9 · `4c69520b` → 과제 6). 걸음표 · 원문 대조 · 번호 대조에 관한 항목(`16e0e602` · `52cb7c7a` · `17563e51` · `a86f8ade` · `fccf272b` · `7c2453be` · `a231cc98` · `9665f71d` · `e1b5b3be`)은 본문에 반영됐고 계획 1 에 닿는 코드가 없다.

## 파일 표

| 파일 | 과제 | 하는 일 |
|---|---|---|
| `tests/fixtures/session-record/*.jsonl` (새로) · `tests/fixtures/session_fixture.py` (새로) · `tests/test_session_fixture.py` (새로) | 1 | 개인 정보를 지운 세션 기록 자료 · 그 자료로 가짜 기록을 짓는 도우미 · 자료의 락 |
| `scripts/session_record.py` (새로) · `tests/test_session_record.py` (새로) | 2 | 세션 기록 찾기 · 질문 창 답 읽기 |
| `scripts/repo_defaults.py` · `scripts/team_files.py` · `tests/test_repo_defaults.py` · `tests/test_team_results.py` · `tests/test_roadmap_model.py` | 3 | `human_gate` 키 · 결정 줄 종류 둘 · 승인 줄 읽기 테스트(J14) |
| `scripts/team_layout.py` · `scripts/start_bundle.py` · `tests/test_team_layout.py` · `tests/test_start_bundle.sh` | 4 | 기본 역할 · 설계 단계의 leader 역할 |
| `scripts/human_lines.py` (새로) · `tests/test_human_lines.py` (새로) · `tests/test_human_judge.py` (새로) · `tests/test_roadmap_status.sh` | 5 · 6 | 줄 꼴 · 본문 · 판 · 꼴 판정 · 대조 판정 · 관문 표. `test_roadmap_status.sh` 는 정적 검사 목록(열넷 → 열여섯 · 수 단언)과 변이 사본 목록 둘에 새 모듈 둘을 더하는 줄만 고친다(J29) |
| `scripts/conductor_ledger.py` · `tests/fixtures/team_repo.sh` · `tests/test_human_record.sh` (새로) | 7 · 11 | `ask-head` · `record --human` · 옛 인자 막기 · `human-check` · 테스트 도우미 |
| `scripts/team_status.py` · `scripts/control_plane.py` · `tests/test_control_plane.py` · `tests/test_team_status.sh` 와 team 형식 셸 테스트 | 8 | 꼴 판정을 지난 승인 줄만 세기 · 건너뜀 줄 · 꺼짐 알림. `control_plane.py` 는 **한 줄만** 고친다 — 캐시가 지켜보는 파일 목록(`CODE_STAMP_FILES`)에 새 모듈 둘(설계 §8 의 예외) |
| `scripts/start_bundle.py` · `scripts/job_results.py` · `tests/test_human_gate.sh` (새로) · `tests/test_start_bundle.sh` · `tests/test_team_sync.sh` | 9 · 10 | 관문 확인 · 머지된 계획 멈춤 · 연속 실패 멈춤 · 맞추는 명령 줄 |
| `scripts/job_results.py` · `tests/test_job_results.sh` 와 결과 대조를 부르는 셸 테스트 | 11 | 결과 대조의 관문 확인 |
| `tests/test_human_gate_e2e.sh` (새로) | 12 | 끝에서 끝 · 지어낸 줄 · 옛 형식 · 변이 |
| `references/team-files.md` · `README.md` · `CHANGELOG.md` · `dependencies.md` · `.claude-plugin/plugin.json` · `tests/test_team_docs.py` | 3 · 4 · 13 | 문서와 판 |

고치지 않는 것: `scripts/roadmap_status.py`(설계 §8) · `scripts/control_plane.py` 의 그 한 줄 밖 전부 · `scripts/roadmap_model.py`(J14) · `references/conducting.md` · `references/conductor-dispatch.md` · `references/proceed-gate.md` · `skills/epic-conductor/SKILL.md` · `templates/team/` · 역할 문서 사본 · 철학 문서 · `CLAUDE.md`(모두 계획 2).

---

### Task 1: 다시 확인과 세션 기록 자료

설계문서가 근거로 든 자리가 지금 코드에서도 그런지 보고, 세션 기록의 꼴을 다시 잰 뒤 개인 정보를 지운 자료로 굳힌다. 확인이나 측정이 아래 기대와 다르면 **멈추고** 지휘자에게 보고한다(어느 줄 · 무엇이 달랐나 · 어느 과제가 닿나). 고치지 않는다.

**AC:** AC5 · AC6 의 근거(읽는 규칙) — 판정은 과제 2 · 6 · 7 이 한다.

**Files:**
- Create: `plugins/spec-distill/tests/fixtures/session-record/answer.jsonl` · `answer-multi.jsonl` · `rejected.jsonl` · `typed.jsonl` · `peer.jsonl` · `notification.jsonl`
- Create: `plugins/spec-distill/tests/fixtures/session_fixture.py`
- Test: `plugins/spec-distill/tests/test_session_fixture.py`

**Interfaces:**
- Produces (`tests/fixtures/session_fixture.py` — 뒤 과제의 테스트가 가져온다):
  - `record_path(config_dir, session, project="fixture") -> pathlib.Path` — `<config_dir>/projects/<project>/<session>.jsonl`
  - `add_answer(config_dir, session, questions, who="human", sidechain=False, subagent=False, entry=None, when="2026-01-01T12:00:00.000Z", drop=(), project="fixture") -> str` — `questions` 는 `[(질문 글, 고른 글), …]`. 호출 항목과 답 항목 두 줄을 그 세션 기록에 덧붙이고(파일 · 폴더가 없으면 만든다) 답 항목의 `uuid` 를 돌려준다.
    - `who` — `"human"`(자료 그대로) · `"unknown"`(답 항목에서 `permissionDecision` 칸을 뺀다) · `"other"`(`permissionDecision.source` 를 `fixture_other` 로 — 수락인데 모르는 출처) · `"denied"`(`decision` 을 `reject`, `source` 를 `user_reject` 로 — `answers` 는 그대로 둔다)
    - `sidechain=True` 면 두 항목의 `isSidechain` 이 참이다. `subagent=True` 면 `<config_dir>/projects/<project>/<session>/subagents/agent-fixture.jsonl` 에 쓴다. `entry` 를 주면 답 항목의 `uuid` 가 그 값이다. `when` 은 답 항목의 `timestamp` 다
    - `drop` — 뺄 칸 이름들: `"isSidechain"`(두 항목에서 칸을 뺀다) · `"sourceToolAssistantUUID"` · `"timestamp"`(답 항목에서 뺀다) · `"answers"`(`toolUseResult` 에서 `answers` 를 뺀다) · `"toolUseResult"`(사전을 글자 `자리표시` 로 바꾼다)
  - `add_lines(config_dir, session, name, project="fixture") -> None` — 자료 파일 `session-record/<name>.jsonl` 의 줄을 그대로 덧붙인다
  - `add_text(config_dir, session, name, text, project="fixture") -> None` — 자료 `<name>.jsonl`(`typed` · `peer` · `notification`)의 첫 항목을 틀로 `message.content` 를 `text` 로 바꿔 한 줄 덧붙인다
  - 명령줄: `session_fixture.py answer --config <폴더> --session <세션> --question <글> --label <글> [--question <글> --label <글> …] [--who human|unknown|other|denied] [--entry <uuid>] [--when <시각>] [--drop <칸>]… [--sidechain] [--subagent]` → 답 항목의 `uuid` 한 줄 · `session_fixture.py lines --config <폴더> --session <세션> --name <자료 이름>` · `session_fixture.py text --config <폴더> --session <세션> --name <자료 이름> --text <글>`
- [ ] **Step 1: 다시 확인**

레포 뿌리에서 돈다. 기대와 다르면 멈춘다.

```bash
cd plugins/spec-distill
grep -c -- '--human' scripts/conductor_ledger.py                      # 0 — 승인 줄은 --approval --choice 로만 쓴다
grep -n '"record": (c_record' scripts/conductor_ledger.py             # --spec · --line · --approval · --date · --choice
grep -c 'human_lines\|spec 승인\|approval' scripts/start_bundle.py scripts/job_results.py   # 둘 다 0 — 묶음 · 결과 대조가 승인을 보지 않는다
grep -c 'start_bundle' references/conducting.md references/conductor-dispatch.md skills/epic-conductor/SKILL.md   # 0 · 0 · 0
grep -n '^_DEFAULT_ROLES' scripts/team_layout.py                      # (ROLES[1], ROLES[1], ROLES[3], None) — 설계 · 계획이 designer
grep -n '과제 묶음에는 --role' scripts/start_bundle.py                 # 한 줄 — 과제 묶음에 leader 를 주지 못한다
grep -n '^NO_BRANCH = ' scripts/start_bundle.py                       # 없는 브랜치는 「아직 없다」 로 읽고 묶음을 낸다
grep -n '^DECISION_KINDS' scripts/team_files.py                       # 일곱 — spec 승인 · 병렬 답 · 계획 검토 · 결과 받음 · 예약 밖 변경 · 넘김 확인 · 결정
grep -n '^SYNC_LINE' scripts/start_bundle.py                          # "맞추는 명령: roadmap_write.py job sync …" — 경로가 없다
grep -n '^MARKER\|^def holder' scripts/conductor_state.py             # conducting-by · holder(d)
grep -n 'CLAUDE_CODE_SESSION_ID\|^SESSION_PATTERN' scripts/state_path.py
grep -c '승인 — 계획 담당자에게' references/conducting.md              # 1 이상
git grep -lE '\.jsonl|/projects' -- scripts ../../shared ':!../../shared/tests'   # shared/docreview/scripts/run_docreview_codex_reviewer.sh 하나(codex 출력) — 세션 기록을 읽는 코드가 없다
git diff --stat origin/main -- scripts/conductor_ledger.py scripts/team_files.py scripts/team_status.py scripts/start_bundle.py scripts/job_results.py scripts/team_layout.py scripts/repo_defaults.py   # 빈 출력 — 이 브랜치가 아직 이 파일들을 고치지 않았다
```

- [ ] **Step 2: 세션 기록의 꼴을 다시 잰다(읽기 전용)**

지휘자가 준 임시 폴더에 버릴 스크립트를 써서 Claude 설정 폴더의 `projects` 아래 `.jsonl` 을 읽는다. 내는 것은 **칸 이름 · 값의 종류 · 고정 낱말 · 개수뿐**이다 — 글 내용과 경로를 찍지 않는다. 스크립트는 커밋하지 않는다. 계획을 쓸 때의 값(2026-11-19 · Claude Code 2.1.296 – 2.1.326 · 세션 파일 643 · 하위 agent 파일 2372 · 질문 창 호출 600 · 답 592):

| 잰 것 | 값 |
|---|---|
| 파일 자리 | 세션은 `projects/<프로젝트 폴더>/<세션 번호>.jsonl`, 하위 agent 는 `projects/<프로젝트 폴더>/<세션 번호>/subagents/agent-*.jsonl` |
| 호출 항목 | `type: assistant` · `uuid` · `isSidechain: false` · `message.content[]` 의 블록 `type: tool_use` · `name: AskUserQuestion` · `id` · `input.questions[]`(`question` · `header` · `multiSelect` · `options[]` 의 `label` · `description`) |
| 답 항목 | `type: user` · `uuid` · `isSidechain: false` · `sourceToolAssistantUUID` · `parentUuid`(둘 다 호출 항목의 `uuid` — 592/592) · `message.content[]` 의 블록 `type: tool_result` · `tool_use_id` · `content`(글자) · 거절일 때만 `is_error: true` |
| 답 항목의 `toolUseResult` | 답이면 사전(`questions` · `answers` · 있을 때 `annotations`), 거절이면 글자 |
| `toolUseResult.answers` | 질문 글 → 고른 글자(590/590 에서 열쇠가 질문 글). 여럿 고르기는 라벨을 쉼표로 이은 글자, 직접 적은 답은 적은 글자 |
| 답 항목의 `permissionDecision` | 사전 — `decision` · `source` · 있을 때 `grantScope` · `reasonCode`. 답 590건 모두 `decision: accept` · `source: user_temporary`. 거절은 `source: user_reject` 1건 · 칸 없음 1건 |
| 답 항목의 `origin` · `turnOrigin` · `promptSource` | 없다(0/592). 이 칸들은 프롬프트 항목(사람이 친 말 · 다른 세션의 글 · 알림)에 있고 판마다 조합이 섞여 있다 — 셋 다 · `turnOrigin` + `promptSource` · `origin.kind` + `promptSource` · 없음 |
| 하위 agent 파일의 질문 창 호출 | 0 |
| 파일 이름과 다른 `sessionId` 를 가진 세션 파일 | 0/643 |
| 같은 `uuid` 의 질문 창 항목이 파일 둘에 있는 것 | 5(이어받은 세션이 앞 기록을 복사한다) |
| 호출 줄과 답 줄 사이 | 바로 다음 줄 1 · 2 – 5줄 369 · 그보다 멂 222 — 사이에 다른 항목이 낀다 |

기대 — 칸 이름과 값의 종류가 표와 같다(개수는 달라도 된다). 새 판에서 칸 이름이 바뀌었거나 `permissionDecision.source` 에 표에 없는 값이 있으면 멈춰 보고한다.

- [ ] **Step 3: 사람 없이 답이 나오는 길(J26)**

구현 담당은 Claude Code 를 다시 띄우지 않는다. 이 측정은 지휘자가 따로 한다 — 기다리지 않는다. 지휘자가 보낸 글에 측정 값이 있으면 이 계획 끝 「측정 값을 받으면」 절의 다섯 자리에 그대로 반영하고, 없으면 허용 목록(`decision: accept` · `source: user_temporary`)만으로 가며 「재지 못함」 의 그 줄을 과제 보고에 그대로 옮긴다. 어느 길의 답이 사람 답과 **같은 값**으로 남는다는 값을 받았으면 멈추고 지휘자에게 돌려보낸다 — 설계 Constraints 의 「막지 못한다」 목록과 Verification Plan 의 문장에 닿으므로 구현 담당이 정하지 않는다.
- [ ] **Step 4: 자료의 락을 쓴다(실패하는 테스트)**

`plugins/spec-distill/tests/test_session_fixture.py`:

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""세션 기록 자료 — 개인 정보가 없고, 도우미가 자료와 같은 꼴의 항목을 짓는다.

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_session_fixture.py
"""
from __future__ import annotations

import json
import re
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "fixtures"))
import session_fixture as SF  # noqa: E402

DATA = HERE / "fixtures" / "session-record"
NAMES = ("answer", "answer-multi", "rejected", "typed", "peer", "notification")
SAFE = [re.compile(p) for p in (
    r"자리표시( [가-힣]+)*( [0-9]+)?",                       # 질문 · 라벨 · 글
    r"[A-Za-z_-]{1,24}",                                      # 고정 낱말(type · name · source …)
    r"0{8}-0{4}-4000-8000-0{9}[0-9a-f]{3}",                   # 가짜 uuid
    r"toolu_fixture_[0-9]+", r"2\.1\.[0-9]{3}", r"2026-01-01T00:00:[0-9]{2}\.000Z")]


def strings(value, under_answers=False):
    """값 안의 모든 글자 값. `answers` 사전은 열쇠(질문 글)도 낸다."""
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for v in value:
            yield from strings(v)
    elif isinstance(value, dict):
        for k, v in value.items():
            if under_answers:
                yield k
            yield from strings(v, under_answers=(k == "answers"))


def entries(name):
    return [json.loads(line) for line in (DATA / (name + ".jsonl")).read_text(encoding="utf-8").splitlines() if line]


class Privacy(unittest.TestCase):
    def test_files_exist_and_parse(self):
        self.assertEqual(sorted(p.stem for p in DATA.glob("*.jsonl") if not p.stem.startswith("not-human-")), sorted(NAMES))
        for name in NAMES:
            self.assertTrue(entries(name), name)

    def test_every_string_is_a_placeholder_or_a_fixed_word(self):
        for path in sorted(DATA.glob("*.jsonl")):
            for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                for s in strings(json.loads(line)):
                    self.assertTrue(any(r.fullmatch(s) for r in SAFE), "%s:%d %r" % (path.name, n, s[:12]))

    def test_the_lock_bites(self):   # 양성 대조 — 경로 · 이메일 · 한글 문장은 걸린다
        for bad in ("/Users/someone/x", "a@b.example", "설계를 승인할까요?", "0123abcd-0000-4000-8000-000000000001"):
            self.assertFalse(any(r.fullmatch(bad) for r in SAFE), bad)


class Shape(unittest.TestCase):
    def test_answer_fixture_has_the_measured_columns(self):
        use, res = entries("answer")
        block = use["message"]["content"][0]
        self.assertEqual((use["type"], block["type"], block["name"], use["isSidechain"]), ("assistant", "tool_use", "AskUserQuestion", False))
        self.assertEqual(sorted(block["input"]["questions"][0]), ["header", "multiSelect", "options", "question"])
        out = res["message"]["content"][0]
        self.assertEqual((res["type"], out["type"], out["tool_use_id"], res["isSidechain"]), ("user", "tool_result", block["id"], False))
        self.assertEqual(res["sourceToolAssistantUUID"], use["uuid"])
        self.assertEqual(sorted(res["toolUseResult"]), ["answers", "questions"])
        self.assertEqual(res["permissionDecision"]["decision"], "accept")
        self.assertEqual(res["permissionDecision"]["source"], "user_temporary")
        self.assertEqual(list(res["toolUseResult"]["answers"]), [block["input"]["questions"][0]["question"]])
        for col in ("origin", "turnOrigin", "promptSource"):
            self.assertNotIn(col, res)

    def test_other_fixtures(self):
        self.assertEqual(len(entries("answer-multi")[0]["message"]["content"][0]["input"]["questions"]), 2)
        self.assertEqual(len(entries("answer-multi")[1]["toolUseResult"]["answers"]), 2)
        rejected = entries("rejected")[1]
        self.assertIs(rejected["message"]["content"][0]["is_error"], True)
        self.assertIsInstance(rejected["toolUseResult"], str)
        kinds = [set(k for k in ("origin", "turnOrigin", "promptSource") if k in e) for e in entries("typed")]
        self.assertEqual(kinds, [{"origin", "turnOrigin", "promptSource"}, {"turnOrigin", "promptSource"}, set()])
        for name in ("typed", "peer", "notification"):
            for e in entries(name):
                self.assertEqual(e["type"], "user")
                self.assertIsInstance(e["message"]["content"], str, name)   # 도구 결과가 아니다


class Builder(unittest.TestCase):
    def test_add_answer_matches_the_fixture_shape(self):
        with tempfile.TemporaryDirectory() as d:
            sid = "00000000-0000-4000-8000-000000000a01"
            uid = SF.add_answer(d, sid, [("R2 @0123abcd — 자리표시 질문", "자리표시 라벨")])
            use, res = [json.loads(l) for l in SF.record_path(d, sid).read_text(encoding="utf-8").splitlines()]
            base_use, base_res = entries("answer")
            self.assertEqual(sorted(use), sorted(base_use))
            self.assertEqual(sorted(res), sorted(base_res))
            self.assertEqual(res["uuid"], uid)
            self.assertEqual(res["sourceToolAssistantUUID"], use["uuid"])
            self.assertEqual(res["toolUseResult"]["answers"], {"R2 @0123abcd — 자리표시 질문": "자리표시 라벨"})
            self.assertEqual(use["message"]["content"][0]["input"]["questions"][0]["question"], "R2 @0123abcd — 자리표시 질문")

    def test_who_and_place(self):
        with tempfile.TemporaryDirectory() as d:
            sid = "00000000-0000-4000-8000-000000000a02"
            SF.add_answer(d, sid, [("q", "a")], who="unknown")
            SF.add_answer(d, sid, [("q2", "a")], who="other")
            SF.add_answer(d, sid, [("q3", "a")], sidechain=True)
            rows = [json.loads(l) for l in SF.record_path(d, sid).read_text(encoding="utf-8").splitlines()]
            self.assertNotIn("permissionDecision", rows[1])
            self.assertEqual(rows[3]["permissionDecision"]["source"], "fixture_other")
            self.assertEqual((rows[4]["isSidechain"], rows[5]["isSidechain"]), (True, True))
            SF.add_answer(d, sid, [("q4", "a")], subagent=True)
            self.assertTrue((Path(d) / "projects" / "fixture" / sid / "subagents" / "agent-fixture.jsonl").is_file())
            self.assertEqual(len(SF.record_path(d, sid).read_text(encoding="utf-8").splitlines()), 6)
            self.assertEqual(SF.add_answer(d, sid, [("q5", "a")], entry="00000000-0000-4000-8000-000000000fff"),
                             "00000000-0000-4000-8000-000000000fff")
            SF.add_answer(d, sid, [("q6", "a")], who="denied", when="2026-11-20T12:00:00.000Z", drop=("sourceToolAssistantUUID", "answers"))
            last = json.loads(SF.record_path(d, sid).read_text(encoding="utf-8").splitlines()[-1])
            self.assertEqual((last["permissionDecision"]["decision"], last["permissionDecision"]["source"], last["timestamp"]),
                             ("reject", "user_reject", "2026-11-20T12:00:00.000Z"))
            self.assertNotIn("sourceToolAssistantUUID", last)
            self.assertNotIn("answers", last["toolUseResult"])
            SF.add_answer(d, sid, [("q7", "a")], drop=("isSidechain", "timestamp", "toolUseResult"))
            use, res = [json.loads(l) for l in SF.record_path(d, sid).read_text(encoding="utf-8").splitlines()[-2:]]
            self.assertEqual(("isSidechain" in use, "isSidechain" in res, "timestamp" in res, res["toolUseResult"]), (False, False, False, "자리표시"))
            SF.add_text(d, sid, "peer", "R2 @0123abcd — 자리표시 질문")
            self.assertEqual(json.loads(SF.record_path(d, sid).read_text(encoding="utf-8").splitlines()[-1])["message"]["content"],
                             "R2 @0123abcd — 자리표시 질문")
```

- [ ] **Step 5: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_session_fixture.py`
Expected: `ModuleNotFoundError: No module named 'session_fixture'`

- [ ] **Step 6: 자료를 굳힌다**

실제 세션 기록에서 항목을 골라 아래 규칙으로 바꿔 `tests/fixtures/session-record/` 에 한 줄에 항목 하나로 쓴다. 칸(열쇠)은 실제 항목의 것을 모두 남긴다 — 읽는 코드가 실제와 같은 군더더기 칸을 만나야 한다.

- 글자 값: `type` · `name` · `decision` · `source` 같은 고정 낱말은 그대로. `uuid` 류는 `00000000-0000-4000-8000-000000000001` 부터 차례로. 도구 호출 번호는 `toolu_fixture_1` 부터. `version` 은 `2.1.326` 꼴 그대로. 시각은 `2026-01-01T00:00:00.000Z` 부터 1초씩. 그 밖의 모든 글자(질문 · 라벨 · 설명 · 결과 글 · `cwd` · `gitBranch` · `slug` …)는 `자리표시 질문 1` · `자리표시 라벨 1` · `자리표시` 같은 자리표시 글자로.
- 값이 사전 · 목록인데 읽는 규칙에 쓰지 않는 칸(`serverClassifierContext` 등)은 빈 사전 · 빈 목록으로.

| 파일 | 줄 |
|---|---|
| `answer.jsonl` | 호출 항목(질문 하나 · 선택지 둘) · 답 항목 |
| `answer-multi.jsonl` | 호출 항목(질문 둘) · 답 항목(`answers` 둘) |
| `rejected.jsonl` | 호출 항목 · 거절 항목(`is_error: true` · `toolUseResult` 글자 · `toolDenialKind`) |
| `typed.jsonl` | 사람이 친 말 셋 — `origin`+`turnOrigin`+`promptSource` 가 다 있는 것 · `turnOrigin`+`promptSource` 만 있는 것 · 셋 다 없는 것. `message.content` 는 글자 |
| `peer.jsonl` | 다른 세션이 보낸 글 하나(`origin.kind` 가 사람이 아닌 값) |
| `notification.jsonl` | 작업 알림 하나(`origin.kind: task-notification`) |

`session_fixture.py` 는 `answer.jsonl` 의 두 항목을 틀로 읽어 질문 · 선택지 · 답 · `uuid` · 도구 호출 번호를 바꿔 넣는다(질문마다 선택지는 고른 글과 `자리표시 다른 선택지` 둘). 새 `uuid` 는 `uuid.uuid4()` 다.

- [ ] **Step 7: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_session_fixture.py`
Expected: `OK`

- [ ] **Step 8: 커밋**

```bash
git add plugins/spec-distill/tests/fixtures/session-record plugins/spec-distill/tests/fixtures/session_fixture.py plugins/spec-distill/tests/test_session_fixture.py
git commit -m "test(spec-distill): 세션 기록 자료와 가짜 기록 도우미를 더한다"
```

과제 보고에 적는다 — 「다시 확인 — 설계 · 계획과 같다」(또는 달랐던 줄), Step 2 에서 다시 잰 판의 범위, Step 3 에서 받은 측정 값을 어디에 반영했는지 또는 「재지 못함」.

---

### Task 2: 세션 기록 읽기(`session_record.py`)

**AC:** AC5(주 대화 · 질문 창 결과 · 질문마다 따로) · AC6(찾지 못함 · 읽지 못함 · 아는 칸 없음)

**Files:**
- Create: `plugins/spec-distill/scripts/session_record.py`
- Test: `plugins/spec-distill/tests/test_session_record.py`

**Interfaces:**
- Consumes: 과제 1 의 `session_fixture`(테스트만).
- Produces:
  - `TOOL = "AskUserQuestion"` · `HUMAN_SOURCES = ("user_temporary",)` · `NOT_HUMAN_SOURCES = ()`(측정으로 채운다 — 이 계획 끝 「측정 값을 받으면」) · `HUMAN, NOT_HUMAN, UNKNOWN = "사람", "사람 아님", "알 수 없음"`
  - `class Unreadable(Exception)` — 「확인 못 함」 의 사유(`str(exc)` 가 한 줄 한국어)
  - `class Answer(NamedTuple)` — `session: str`(파일 이름의 세션 번호) · `entry: str`(답 항목의 `uuid`) · `index: int`(그 호출 안 질문의 순번, 1부터) · `question: str`(호출 항목의 질문 글) · `label: str`(고른 글자 그대로 — 읽지 못했으면 `""`) · `who: str` · `why: str`(`who` 가 `HUMAN` 이 아닐 때 사유 한 줄, 아니면 `""`) · `when: str`(답 항목의 `timestamp` 글자 — 없으면 `""`). `key` 속성은 `"%s#%d" % (entry, index)`
  - `config_dir(environ=None) -> pathlib.Path` — `CLAUDE_CONFIG_DIR` 이 비지 않았으면 그 값, 아니면 `Path.home() / ".claude"`
  - `locate(session: str, environ=None) -> pathlib.Path` — `<설정 폴더>/projects/*/<session>.jsonl` 이 정확히 하나면 그 경로. 세션 번호 꼴(`[A-Za-z0-9_-]{8,}` — `state_path.SESSION_PATTERN` 과 같은 글자)이 아니거나 없거나 둘 이상이면 `Unreadable`
  - `answers(path) -> list` — 그 파일의 질문 창 답들(파일 차례). 파일을 열지 못하거나 읽은 JSON 줄이 하나도 없으면 `Unreadable`
  - `find(path, key: str) -> Optional[Answer]` — `key` 가 `<uuid>#<n>` 인 답
  - `day(when: str, local: bool) -> Optional[str]` — 그 시각의 날짜(`YYYY-MM-DD`). `local` 이 참이면 이 기계의 지역 날짜, 거짓이면 UTC 날짜. 읽지 못하면 `None`(J28)

읽는 규칙(과제 1 의 표 · J2 · J33):

- 줄마다 JSON 객체 하나다. JSON 이 아닌 줄(반만 쓰인 마지막 줄 포함)은 건너뛴다. `"AskUserQuestion"` 이나 `"tool_result"` 글자가 없는 줄은 JSON 으로 풀지 않는다(큰 기록).
- **호출.** `type` 이 `assistant` 인 항목의 `message.content` 블록 가운데 `type: tool_use` · `name: AskUserQuestion`. `input.questions` 가 목록이고 질문마다 `question` 이 글자여야 한다 — 아니면 그 호출은 쓰지 않는다. 같은 호출 안에 질문 글이 같은 것이 둘이면 그 호출은 쓰지 않는다.
- **결과.** `type` 이 `user` 인 항목의 `tool_result` 블록 가운데 `tool_use_id` 가 **같은 파일에서 앞서 읽은** 호출의 `id` 인 것. 짝이 되는 호출이 없으면 답이 아니다.
- **답이 아닌 것으로 넘기는 것(꼴을 아는 것).** 호출 항목이나 결과 항목의 `isSidechain` 이 `True` 다 · 결과 블록의 `is_error` 가 참이다(거절).
- **그 밖의 결과는 질문마다 `Answer` 하나로 싣는다.** 아래에서 처음 걸리는 것이 `who` 와 `why` 를 정한다.
  1. 호출 항목이나 결과 항목에 `isSidechain` 칸이 없다 → `UNKNOWN` — `주 대화인지 가를 칸(isSidechain)이 없다`
  2. 결과 항목에 `sourceToolAssistantUUID` 가 없거나 호출 항목의 `uuid` 와 다르다 → `UNKNOWN` — `호출과 결과를 잇는 칸(sourceToolAssistantUUID)이 없거나 다르다`
  3. `toolUseResult` 가 사전이 아니거나 그 `answers` 가 사전이 아니거나 `answers[질문 글]` 이 글자가 아니다 → `UNKNOWN` — `고른 답을 읽을 칸(toolUseResult.answers)이 없거나 꼴이 다르다`. `label` 은 `""` 다
  4. 결과 항목의 `timestamp` 를 `day` 가 읽지 못한다 → `UNKNOWN` — `답한 시각(timestamp)을 읽지 못했다`
  5. `permissionDecision` 칸이 없거나 사전이 아니다 → `UNKNOWN` — `사람이 답했는지 가를 칸(permissionDecision)이 없다`
  6. `decision` 이 `accept` 가 아니다, 또는 `source` 가 `NOT_HUMAN_SOURCES` 에 있다 → `NOT_HUMAN` — `사람이 질문 창에서 고른 답이 아니다(<decision> · <source>)`
  7. `source` 가 `HUMAN_SOURCES` 에 없다 → `UNKNOWN` — `수락의 출처(<source>)가 아는 값이 아니다`
  8. 그 밖 → `HUMAN`
- `day` — 시각 글자의 앞 19자(`YYYY-MM-DDTHH:MM:SS`)를 UTC 로 읽는다(`calendar.timegm(time.strptime(…))` — 이 모듈은 이름이 `replace` 인 호출을 쓰지 못한다).
- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/spec-distill/tests/test_session_record.py` — 머리(`REPO` · `SCRIPTS` 를 `sys.path` 에 넣기)는 `tests/test_team_files.py` 와 같고, `fixtures` 폴더도 넣어 `session_fixture as SF` · `session_record as R` 을 가져온다. `SID = "00000000-0000-4000-8000-00000000aaaa"`. `setUp` 이 `tempfile.TemporaryDirectory()` 로 설정 폴더 `self.d` 와 `self.env = {"CLAUDE_CONFIG_DIR": self.d}` 를 만든다 — 아래 코드는 `self.d` · `self.env` 를 `d` · `env` 로 줄여 적었다.

```python
class Locate(unittest.TestCase):
    def test_finds_the_one_file(self):
        SF.add_answer(d, SID, [("q", "a")])
        self.assertEqual(R.locate(SID, env), SF.record_path(d, SID))

    def test_missing_two_and_bad_names_are_unreadable(self):
        for sid in (SID, "../" + SID, "short", ""):
            self.assertRaises(R.Unreadable, R.locate, sid, env)            # 없음 · 꼴 아님
        SF.add_answer(d, SID, [("q", "a")]); SF.add_answer(d, SID, [("q", "a")], project="other")
        self.assertRaises(R.Unreadable, R.locate, SID, env)                 # 둘

    def test_subagent_files_are_not_session_files(self):
        SF.add_answer(d, SID, [("q", "a")], subagent=True)
        self.assertRaises(R.Unreadable, R.locate, SID, env)
        self.assertRaises(R.Unreadable, R.locate, "agent-fixture", env)

    def test_config_dir_follows_the_environment(self):
        self.assertEqual(R.config_dir({"CLAUDE_CONFIG_DIR": "/x/y"}), Path("/x/y"))
        self.assertEqual(R.config_dir({"CLAUDE_CONFIG_DIR": ""}), Path.home() / ".claude")
        self.assertEqual(R.config_dir({}), Path.home() / ".claude")


class Answers(unittest.TestCase):
    def test_one_answer(self):
        uid = SF.add_answer(d, SID, [("R2 @0123abcd — 질문", "승인 — 계획 담당자에게 (권장)")])
        got = R.answers(SF.record_path(d, SID))
        self.assertEqual(got, [R.Answer(SID, uid, 1, "R2 @0123abcd — 질문", "승인 — 계획 담당자에게 (권장)", R.HUMAN, "", "2026-01-01T12:00:00.000Z")])
        self.assertEqual(got[0].key, uid + "#1")
        self.assertEqual(R.find(SF.record_path(d, SID), uid + "#1"), got[0])
        for key in (uid + "#2", uid, "x#1", uid + "#0", uid + "#1\n"):
            self.assertIsNone(R.find(SF.record_path(d, SID), key), key)

    def test_each_question_of_one_call_has_its_own_label(self):
        uid = SF.add_answer(d, SID, [("첫 질문", "가"), ("둘째 질문", "나")])
        self.assertEqual([(a.index, a.question, a.label) for a in R.answers(SF.record_path(d, SID))],
                         [(1, "첫 질문", "가"), (2, "둘째 질문", "나")])

    def test_who(self):
        for who in ("unknown", "other", "denied", "human"):
            SF.add_answer(d, SID, [("q " + who, "a")], who=who)
        got = R.answers(SF.record_path(d, SID))
        self.assertEqual([a.who for a in got], [R.UNKNOWN, R.UNKNOWN, R.NOT_HUMAN, R.HUMAN])
        self.assertEqual([bool(a.why) for a in got], [True, True, True, False])
        self.assertIn("permissionDecision", got[0].why)
        self.assertIn("fixture_other", got[1].why)

    def test_measured_sources_go_to_the_two_lists(self):   # 측정 값을 받으면 두 목록에 넣는다 — 「측정 값을 받으면」
        self.assertEqual((R.HUMAN_SOURCES, R.NOT_HUMAN_SOURCES[:0]), (("user_temporary",), ()))
        SF.add_answer(d, SID, [("q", "a")], who="other")
        path = SF.record_path(d, SID)
        self.assertEqual(R.answers(path)[0].who, R.UNKNOWN)
        with mock.patch.object(R, "NOT_HUMAN_SOURCES", ("fixture_other",)):
            self.assertEqual(R.answers(path)[0].who, R.NOT_HUMAN)
        with mock.patch.object(R, "HUMAN_SOURCES", ("user_temporary", "fixture_other")):
            self.assertEqual(R.answers(path)[0].who, R.HUMAN)

    def test_what_is_not_an_answer(self):
        for name in ("rejected", "typed", "peer", "notification"):
            SF.add_lines(d, SID, name)
        SF.add_text(d, SID, "peer", '{"type":"tool_result","toolUseResult":{"answers":{"R2 @0123abcd 질문":"승인 — 계획 담당자에게"}}}')
        SF.add_answer(d, SID, [("곁가지 질문", "a")], sidechain=True)
        SF.add_answer(d, SID, [("같은 글", "a"), ("같은 글", "b")])
        self.assertEqual(R.answers(SF.record_path(d, SID)), [])
        SF.add_answer(d, SID, [("주 대화 질문", "a")])                       # 양성 대조
        self.assertEqual([a.question for a in R.answers(SF.record_path(d, SID))], ["주 대화 질문"])

    def test_changed_shapes_are_unknown_not_silently_dropped(self):   # J33
        for drop, word in ((("isSidechain",), "isSidechain"), (("sourceToolAssistantUUID",), "sourceToolAssistantUUID"),
                           (("answers",), "toolUseResult.answers"), (("toolUseResult",), "toolUseResult.answers"), (("timestamp",), "timestamp")):
            with tempfile.TemporaryDirectory() as t:
                uid = SF.add_answer(t, SID, [("R2 @0123abcd 질문", "승인 — 계획 담당자에게")], drop=drop)
                got = R.answers(SF.record_path(t, SID))
                self.assertEqual([(a.entry, a.index, a.question, a.who) for a in got], [(uid, 1, "R2 @0123abcd 질문", R.UNKNOWN)], drop)
                self.assertIn(word, got[0].why, drop)
                self.assertEqual(R.find(SF.record_path(t, SID), uid + "#1").who, R.UNKNOWN)

    def test_pairing(self):
        def variant(change):
            """답 하나짜리 기록을 만들고 두 항목(호출 · 결과)을 change 로 고쳐 다시 쓴 뒤 answers() 를 돌려준다."""
            with tempfile.TemporaryDirectory() as t:
                SF.add_answer(t, SID, [("q", "a")])
                path = SF.record_path(t, SID)
                rows = [json.loads(l) for l in path.read_text(encoding="utf-8").splitlines()]
                rows = change(rows) or rows
                path.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows), encoding="utf-8")
                return R.answers(path)

        def no_call(rows): rows[1]["message"]["content"][0]["tool_use_id"] = "toolu_none"
        def other_tool(rows): rows[0]["message"]["content"][0]["name"] = "Bash"
        def result_first(rows): return [rows[1], rows[0]]
        def other_source(rows): rows[1]["sourceToolAssistantUUID"] = "00000000-0000-4000-8000-00000000dead"
        def no_key(rows): rows[1]["toolUseResult"]["answers"] = {"다른 질문": "a"}
        self.assertEqual([a.who for a in variant(lambda rows: None)], [R.HUMAN])       # 양성 대조
        for change in (no_call, other_tool, result_first):                             # 짝이 되는 호출이 없다 — 답이 아니다
            self.assertEqual(variant(change), [], change.__name__)
        for change in (other_source, no_key):                                          # 짝은 맞는데 칸이 다르다 — 알 수 없음
            self.assertEqual([a.who for a in variant(change)], [R.UNKNOWN], change.__name__)

    def test_day(self):
        self.assertEqual(R.day("2026-11-20T23:30:00.000Z", local=False), "2026-11-20")
        for bad in ("", "어제", "2026-13-40T00:00:00.000Z", "2026-11-20"):
            self.assertIsNone(R.day(bad, local=False), bad)
            self.assertIsNone(R.day(bad, local=True), bad)
        old = os.environ.get("TZ")
        try:
            os.environ["TZ"] = "Asia/Seoul"; time.tzset()
            self.assertEqual(R.day("2026-11-20T23:30:00.000Z", local=True), "2026-11-21")
            os.environ["TZ"] = "UTC"; time.tzset()
            self.assertEqual(R.day("2026-11-20T23:30:00.000Z", local=True), "2026-11-20")
        finally:
            if old is None:
                os.environ.pop("TZ", None)
            else:
                os.environ["TZ"] = old
            time.tzset()
    def test_broken_lines_and_empty_files(self):
        uid = SF.add_answer(d, SID, [("q", "a")])
        with open(SF.record_path(d, SID), "a", encoding="utf-8") as f:
            f.write('{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"toolu_x"')   # 반만 쓰인 마지막 줄
        self.assertEqual([a.entry for a in R.answers(SF.record_path(d, SID))], [uid])
        empty = SF.record_path(d, "00000000-0000-4000-8000-00000000bbbb"); empty.parent.mkdir(parents=True, exist_ok=True)
        empty.write_text("not json\n", encoding="utf-8")
        self.assertRaises(R.Unreadable, R.answers, empty)
        self.assertRaises(R.Unreadable, R.answers, Path(d) / "no-such.jsonl")

    def test_large_record(self):
        path = SF.record_path(d, SID); path.parent.mkdir(parents=True, exist_ok=True)
        filler = json.dumps({"type": "assistant", "isSidechain": False, "uuid": "x", "message": {"content": [{"type": "text", "text": "자리표시 " * 40}]}})
        path.write_text((filler + "\n") * 50000, encoding="utf-8")
        uid = SF.add_answer(d, SID, [("끝 질문", "끝 답")])
        t0 = time.monotonic()
        self.assertEqual([a.entry for a in R.answers(path)], [uid])
        self.assertLess(time.monotonic() - t0, 10)
```

이 파일은 `json` · `os` · `tempfile` · `time` · `unittest.mock` 을 가져온다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_session_record.py`
Expected: `ModuleNotFoundError: No module named 'session_record'`

- [ ] **Step 3: `session_record.py` 를 쓴다**

위 Interfaces 와 읽는 규칙대로 쓴다. 표준 라이브러리만 가져온다. 파일은 `encoding="utf-8", errors="replace"` 로 한 줄씩 읽는다. 읽지 못한 파일(`OSError`)은 `Unreadable("세션 기록을 읽지 못했다: <파일 이름> — <사유>")` — 사유 글에 설정 폴더의 온 경로를 넣지 않는다(파일 이름까지만). 이 모듈은 상태 계산의 잠금 목록에 든다(Global Constraints) — 이름이 `replace` · `remove` 인 호출을 쓰지 않고 `open` 은 읽기 모드만 쓴다.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_session_record.py && python3 -m unittest plugins/quality-gates/tests/test_utf8_explicit.py && bash shared/tests/test_python_floor.sh | tail -1`
Expected: `OK` 둘 · 셸 테스트 요약 줄에 실패 0

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/session_record.py plugins/spec-distill/tests/test_session_record.py
git commit -m "feat(spec-distill): 세션 기록에서 질문 창의 답을 읽는 모듈을 더한다"
```

---

### Task 3: 설정 키 `human_gate` 와 결정 줄 종류 둘

**AC:** AC20(키) · AC7(줄 종류)

**Files:**
- Modify: `plugins/spec-distill/scripts/repo_defaults.py`(`KEYS` · `_DEFAULTS` · `merge_layers`)
- Modify: `plugins/spec-distill/scripts/team_files.py`(`DECISION_KINDS`)
- Modify: `plugins/spec-distill/references/team-files.md`(§2 의 「종류는 일곱」 문장 · §5 의 「받는 줄은 종류 일곱」 문장 — 종류 목록만)
- Test: `plugins/spec-distill/tests/test_repo_defaults.py` · `tests/test_team_results.py` · `tests/test_roadmap_model.py`

**Interfaces:**
- Produces:
  - `repo_defaults.HUMAN_GATE_ON = "켬"` · `repo_defaults.HUMAN_GATE_OFF = "끔"` · `KEYS` 끝에 `"human_gate"` · `_DEFAULTS["human_gate"] = HUMAN_GATE_ON`
  - `repo_defaults.gate_on(values: dict) -> bool` — `values.get("human_gate") != HUMAN_GATE_OFF`(값이 없거나 깨져 `None` 이어도 켜진 것이다)
  - `team_files.DECISION_KINDS` — 지금 일곱 **뒤에** `"흐름 승인"` · `"걸음 건너뜀"` 을 붙인다(앞 일곱의 자리는 그대로 — `_KIND_RECEIVED` · `_KIND_CONFIRM` 이 자리 번호로 읽는다)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_repo_defaults.py` 에 더한다(그 파일의 `merge_layers` 를 부르는 기존 테스트와 같은 방식 · `ast` 를 가져온다):

```python
class HumanGate(unittest.TestCase):
    def merged(self, repo=None, roadmap=None):
        return D.merge_layers(roadmap, repo, "레포 설정", [])

    def test_default_is_on(self):
        out = self.merged()
        self.assertEqual((out["values"]["human_gate"], out["sources"]["human_gate"]), ("켬", "기본값"))
        self.assertTrue(D.gate_on(out["values"]))

    def test_off_only_by_the_exact_word(self):
        out = self.merged(repo={"human_gate": "끔"})
        self.assertEqual((out["values"]["human_gate"], out["errors"]), ("끔", []))
        self.assertFalse(D.gate_on(out["values"]))
        self.assertTrue(D.gate_on(self.merged(repo={"human_gate": '"켬"'})["values"]))

    def test_other_words_are_errors_and_stay_on(self):
        for word in ("off", "false", "0", "꺼짐", ""):
            out = self.merged(repo={"human_gate": word})
            self.assertIsNone(out["values"]["human_gate"], word)
            self.assertEqual(len(out["errors"]), 1, word)
            self.assertIn("human_gate", out["errors"][0])
            self.assertTrue(D.gate_on(out["values"]), word)

    def test_roadmap_layer_does_not_take_it(self):
        out = self.merged(roadmap={"type": "roadmap", "human_gate": "끔"})
        self.assertTrue(any("human_gate" in e for e in out["errors"]))
        self.assertTrue(D.gate_on(out["values"]))

    def test_gate_reading_code_does_not_look_at_the_environment(self):   # AC20 — 환경 변수로는 꺼지지 않는다
        def reads_environment(path, name):
            """그 파일에서 이름이 name 인 함수의 몸에 environ · getenv 가 나오는가."""
            tree = ast.parse(path.read_text(encoding="utf-8"))
            found = [n for n in ast.walk(tree) if isinstance(n, ast.FunctionDef) and n.name == name]
            self.assertTrue(found, name)
            return any(getattr(x, "attr", getattr(x, "id", "")) in ("environ", "getenv") for f in found for x in ast.walk(f))
        self.assertFalse(reads_environment(SCRIPTS / "repo_defaults.py", "gate_on"))
        self.assertFalse(reads_environment(SCRIPTS / "repo_defaults.py", "merge_layers"))
        self.assertTrue(reads_environment(SCRIPTS / "state_path.py", "resolve_session_id"))   # 양성 대조 — 탐침이 환경 읽기를 본다
```

`tests/test_team_results.py` 의 `DECISION_KINDS` 단언(지금 일곱 줄)을 아홉으로 고치고 더한다:

```python
    def test_new_kinds_are_accepted(self):
        for line in ("- 흐름 승인 · 2026-11-18 · 「설계 없이 진행」 · INTENT.md@0123abcd · 근거 00000000-0000-4000-8000-00000000aaaa:00000000-0000-4000-8000-000000000001#1",
                     "- 걸음 건너뜀 · 2026-11-18 · 「건너뛴다」 · 계획 검토 plan 2 · INTENT.md@0123abcd · 근거 00000000-0000-4000-8000-00000000aaaa:00000000-0000-4000-8000-000000000001#1"):
            self.assertIsNone(F.decision_problem(line), line)
        self.assertEqual(F.DECISION_KINDS[:7], ("spec 승인", "병렬 답", "계획 검토", "결과 받음", "예약 밖 변경", "넘김 확인", "결정"))
        self.assertIsNotNone(F.decision_problem("- 흐름승인 · 2026-11-18 · 「설계 없이 진행」"))
```

`tests/test_roadmap_model.py` 에 더한다(J14 — 코드를 고치지 않고 못 박는다):

```python
    def test_approval_reader_takes_the_version_and_evidence_cells(self):
        line = "- spec 승인 · 2026-11-18 · 「승인 — 계획 담당자에게」 · design.md@51f1b64d · 근거 00000000-0000-4000-8000-00000000aaaa:00000000-0000-4000-8000-000000000001#1"
        self.assertEqual(M.approval_in([line]), "2026-11-18")
        self.assertEqual(M.approval_in(["- spec 승인 · 2026-10-20 · 「승인」", line]), "2026-11-18")
```

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_repo_defaults.py plugins/spec-distill/tests/test_team_results.py plugins/spec-distill/tests/test_roadmap_model.py 2>&1 | tail -5`
Expected: `HumanGate` 의 테스트들이 `KeyError: 'human_gate'` 또는 `AttributeError: … 'gate_on'` 로, `test_new_kinds_are_accepted` 가 실패한다. `test_approval_reader_takes_the_version_and_evidence_cells` 는 **통과한다**(J14) — 실패하면 멈춰 보고한다.

- [ ] **Step 3: 구현한다**

`repo_defaults.merge_layers` 의 키 분기에 `human_gate` 를 더한다 — 따옴표를 벗긴 값이 `켬` · `끔` 이면 그 값, 아니면 값은 `None` 이고 `errors` 에 `"%s: human_gate 는 켬 · 끔 가운데 하나다(%r) — 값을 고치거나 키를 지운다" % (자리, 값)`. `ROADMAP_LAYER_KEYS` 에는 넣지 않는다(로드맵 머리말에 있으면 `check_layer` 가 지금 규칙대로 오류를 낸다). `team_files.DECISION_KINDS` 끝에 둘을 붙인다. `references/team-files.md` 의 두 문장에서 「일곱」 을 「아홉」 으로, 목록 끝에 `` `흐름 승인` · `걸음 건너뜀` `` 을 더한다.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_repo_defaults.py plugins/spec-distill/tests/test_team_results.py plugins/spec-distill/tests/test_roadmap_model.py plugins/spec-distill/tests/test_team_docs.py plugins/spec-distill/tests/test_team_files.py 2>&1 | tail -3 && bash plugins/spec-distill/tests/test_repo_defaults_git.sh | tail -1`
Expected: `OK` · 셸 테스트 요약 줄에 실패 0. 설정 키 목록을 세는 다른 테스트가 붉으면(키 수 · 키 이름 목록) 그 기대값에 `human_gate` 를 더한다 — 단언을 지우지 않는다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/repo_defaults.py plugins/spec-distill/scripts/team_files.py plugins/spec-distill/references/team-files.md plugins/spec-distill/tests/test_repo_defaults.py plugins/spec-distill/tests/test_team_results.py plugins/spec-distill/tests/test_roadmap_model.py
git commit -m "feat(spec-distill): 레포 설정 human_gate 와 결정 줄 종류 둘을 더한다"
```

---

### Task 4: 기본 역할 — 계획은 worker, 설계는 leader

**AC:** AC15(계획 1 몫)

**Files:**
- Modify: `plugins/spec-distill/scripts/team_layout.py`(`_DEFAULT_ROLES`)
- Modify: `plugins/spec-distill/scripts/start_bundle.py`(`_check_args`)
- Modify: `plugins/spec-distill/references/team-files.md`(§6 의 역할 – 단계 표 · §9 의 「기본 역할」 글머리)
- Test: `plugins/spec-distill/tests/test_team_layout.py` · `tests/test_start_bundle.sh`

**Interfaces:**
- Produces: `team_layout.default_role("design") == "leader"` · `default_role("plan") == "worker"` · `default_role("implement") == "worker"` · `default_role("review") is None`. `start_bundle.py --job <과제> --stage design --role leader` 는 받는다. 다른 단계의 과제 묶음에 `--role leader` 는 지금처럼 사용법 오류 2 다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_team_layout.py` 의 `test_default_roles` 기대를 `["leader", "worker", "worker", None]` 로 고친다.

`tests/test_start_bundle.sh` — 기본 역할을 재는 두 줄(「과제: plan 의 기본 역할은 designer」 · 「과제: design 의 맞추는 명령」)의 기대에서 `--role designer` 를 각각 `--role worker` · `--role leader` 로 고치고 이름을 「plan 의 기본 역할은 worker」 로 바꾼다. 그 design 묶음 뒤에 더한다:

```bash
assert_eq "$(job --job E3 --stage design --role leader)" "0" "AC15: design 과제 묶음은 --role leader 를 받는다"
assert_contains "$(cat "$T/job.txt")" "$(show "${RD}leader/CLAUDE.md" | sed -n 1p)" "AC15: design 묶음의 역할 문서는 leader 것이다"
assert_eq "$(job --job E3 --stage design --role designer)" "0" "AC15: design 에 다른 역할을 주면 그 역할이다"
assert_contains "$(grep '^맞추는 명령: ' "$T/job.txt")" "--role designer " "AC15: 준 역할이 맞추는 명령에 실린다"
assert_eq "$(job --job E1 --stage plan --plan 1 --role leader)" "2" "AC15: plan 과제 묶음에 --role leader 는 2"
assert_eq "$(job --job E1 --stage implement --plan 1 --role leader)" "2" "AC15: implement 과제 묶음에 --role leader 는 2"
```

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_layout.py 2>&1 | tail -3; bash plugins/spec-distill/tests/test_start_bundle.sh | grep -E '✗|AC15'`
Expected: `test_default_roles` FAIL · 셸 테스트에서 기본 역할 두 줄과 `AC15: design 과제 묶음은 --role leader 를 받는다` 가 ✗

- [ ] **Step 3: 구현한다**

`_DEFAULT_ROLES` 를 `dict(zip(STAGES, (ROLES[0], ROLES[3], ROLES[3], None)))` 로 고치고 그 위 주석을 사실대로 고친다. `_check_args` 의 leader 거절을 `a.role == leader and a.stage != DESIGN` 일 때만으로 바꾸고 글을 `"과제 묶음의 --role %s 는 %s 단계에서만 준다" % (leader, DESIGN)` 로 고친다. `references/team-files.md` §6 의 표에서 `design` 을 `leader` 줄로, `plan` 을 `worker` 줄로 옮기고(designer 줄의 단계 칸은 `—` — 디자인 일을 맡길 때 `--role designer` 로 준다), §9 의 글머리를 「`--role` 을 주지 않으면 `design` 은 leader, `plan` · `implement` 는 worker 다. designer · writer 는 `--role` 로 줄 때만 쓴다. 과제 묶음의 `--role leader` 는 `design` 단계에서만 준다. `review` 에는 `--role` 을 주지 않는다.」 로 고친다.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_layout.py plugins/spec-distill/tests/test_team_docs.py 2>&1 | tail -3; for t in test_start_bundle test_team_sync test_team_stale test_team_status; do bash plugins/spec-distill/tests/$t.sh | tail -1; done`
Expected: `OK` · 네 셸 테스트 요약 줄에 실패 0. 기본 역할 글자(`designer`)를 기대하던 다른 단언이 붉으면 새 기본 역할로 고친다 — `test_team_docs.py` 가 문서의 옛 문장을 기대하면 위 새 문장으로 고친다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/team_layout.py plugins/spec-distill/scripts/start_bundle.py plugins/spec-distill/references/team-files.md plugins/spec-distill/tests/test_team_layout.py plugins/spec-distill/tests/test_start_bundle.sh plugins/spec-distill/tests/test_team_docs.py
git commit -m "feat(spec-distill): 계획 단계의 기본 역할을 worker 로, 설계 단계를 leader 로 바꾼다"
```

---

### Task 5: 사람 줄의 꼴 · 본문 · 판 · 꼴 판정(`human_lines.py`)

**AC:** AC7(줄 꼴) · AC8(꼴 판정 · 기록 절은 승인을 낡게 하지 않는다) · AC4(판 · 머리)

**Files:**
- Create: `plugins/spec-distill/scripts/human_lines.py`
- Test: `plugins/spec-distill/tests/test_human_lines.py`(git 없이) · `plugins/spec-distill/tests/test_human_judge.py`(임시 git 레포)
- Modify: `plugins/spec-distill/tests/test_roadmap_status.sh`(정적 검사 목록 · 수 단언 · 변이 사본 목록 둘 — J29)

**Interfaces:**
- Consumes: `team_files.decision_problem` · `team_layout.Team` · `team_layout.plan_name` · `section6.fence_spans_in` · `roadmap_status.Git` 의 `blob` · `commit` · `run_err("log", …)`(테스트와 부르는 쪽이 넘긴다 — 이 모듈은 `roadmap_status` 를 가져오지 않는다).
- Produces:
  - `KIND_SPEC, KIND_PLAN, KIND_FLOW, KIND_SKIP = "spec 승인", "계획 검토", "흐름 승인", "걸음 건너뜀"` · `KINDS`(이 차례의 튜플)
  - `SKIP_LABEL, RETRY_LABEL = "건너뛴다", "다시 시도한다"` · `PASS_LABELS = {KIND_SPEC: ("승인 — 계획 담당자에게",), KIND_PLAN: ("계획대로 구현한다",), KIND_FLOW: ("설계 없이 진행",), KIND_SKIP: (SKIP_LABEL, RETRY_LABEL)}` · `RECOMMENDED = "(권장)"`
  - `PASS, NO_EVIDENCE, MISMATCH, UNCHECKED, STALE = "지남", "근거 없음", "어긋남", "확인 못 함", "낡음"`
  - `RECORD_HEADS = ("## 결정 기록", "## 지휘 기록", "## 미룸", "## 판정", "## 구현 대조")` · `DEFERRED_HEAD = "### Deferred to plan"`
  - `class Line(NamedTuple)` — `kind` · `date` · `label` · `gate`(건너뜀이 아니면 `None`) · `file`(`design.md` · `plan-<n>.md` · `INTENT.md`) · `rev`(8자) · `session` · `entry` · `index: int` · `raw`. 속성 `key` 는 `"%s#%d" % (entry, index)`, 속성 `plan` 은 `file` 이 `plan-<n>.md` 면 n, `gate` 에 `plan <n>` 이 있으면 n, 아니면 `None`
  - `class Verdict(NamedTuple)` — `verdict` · `why` · `line: Optional[Line]` · `raw`
  - `class Scope(NamedTuple)` — `git` · `team` · `job` · `tip`(「지금 본문」 을 읽는 커밋) · `lines: tuple`(그 과제의 결정 기록 줄 — 겹침 없이) · `gate_on: bool`
  - `is_human(raw: str) -> Optional[str]` — `- <사람 줄 종류> · ` 로 시작하면 그 종류
  - `parse(raw: str) -> Optional[Line]` — 꼴이 끝까지 맞을 때만
  - `render(kind, date, label, file, rev, session, key, gate=None) -> str`
  - `clean_label(text: str) -> str` — 앞뒤 공백을 떼고 끝의 `(권장)` 하나와 그 앞 공백을 뗀다
  - `head(job: str, rev: str, plan: Optional[int] = None) -> str` — `"%s @%s" % (job, rev)`, `plan` 을 주면 `"%s plan %d @%s" % (job, plan, rev)`(`계획 검토` 의 머리 — 부르는 쪽이 그 종류일 때만 `plan` 을 준다) · `starts_with_head(question, job, rev, plan=None) -> bool` — 질문 글이 그 머리로 **시작하고** 머리 바로 뒤 글자가 16진 글자(`0-9a-f`)가 아니다
  - `bound_name(kind, plan=None) -> str` · `gate_name(kind, plan=None) -> str`(`spec 승인` · `계획 검토 plan <n>`) · `retry_name(plan, attempt) -> str`(`다시 시도 plan <n> 시도 <k>` · 계획이 `None` 이면 `다시 시도 구현 시도 <k>`)
  - `names_gate(text: str, name: str) -> bool` — `text` 에 `name` 이 글자 그대로 있고 그 바로 뒤 글자가 숫자가 아닌 자리가 하나라도 있다(`계획 검토 plan 1` 은 `계획 검토 plan 12` 안에서 맞지 않는다)
  - `body_of(name: str, text: str) -> str` — `name` 은 파일 이름(경로의 마지막 조각)
  - `version(git, tip: str, path: str) -> Optional[str]` — J5. 그 끝에 파일이 없으면 `None`
  - `shape(scope: Scope, raw: str) -> Verdict` — 꼴 판정. 세션 기록을 읽지 않는다

줄 꼴(`parse` 가 받는 것 — 하나라도 어긋나면 `None`):

- `team_files.decision_problem(raw)` 가 `None` 이다(한 줄 · 있는 날짜).
- `- <종류> · <날짜> · 「<라벨>」[ · <관문 이름>] · <파일>@<판> · 근거 <세션>:<uuid>#<순번>` 이고 그 뒤에 글자가 없다. 판은 `[0-9a-f]{8}`, 세션은 `[A-Za-z0-9_-]{8,}`, uuid 는 `[0-9a-f-]{36}`, 순번은 0 으로 시작하지 않는 1 이상의 수다.
- 라벨이 그 종류의 `PASS_LABELS` 가운데 하나다(꼬리 `(권장)` 이 남은 글자는 아니다).
- 파일이 종류와 맞는다 — `spec 승인` 은 `design.md`, `계획 검토` 는 `plan-<n>.md`(n 은 1 이상), `흐름 승인` · `걸음 건너뜀` 은 `INTENT.md`.
- 관문 이름 칸은 `걸음 건너뜀` 에만 있고 꼭 있다. 이름은 `spec 승인` · `계획 검토 plan <n>` · `다시 시도 plan <n> 시도 <k>` · `다시 시도 구현 시도 <k>` 이고(n · k 는 0 으로 시작하지 않는 1 이상의 수), 라벨 「건너뛴다」 는 앞의 둘, 「다시 시도한다」 는 뒤의 둘과만 짝이다.

본문(`body_of`):

- `design.md` — 코드 펜스 밖의 2단계 제목 줄 가운데 `RECORD_HEADS` 의 하나와 같거나 그 뒤에 공백이 이어지는 줄(예: `## 구현 대조 — plan-1.md`)부터 다음 2단계 제목 줄 앞까지를 뺀다. 코드 펜스 밖의 `### Deferred to plan` 줄부터 다음 1 – 3단계 제목 줄 앞까지도 뺀다. 펜스는 `section6.fence_spans_in` 으로 센다.
- `plan-<n>.md` — 글 전체.
- `INTENT.md` — 마지막 `## 결정 기록` 줄 앞까지(`team_files.intent_sections` 가 결정 기록 칸을 찾는 규칙과 같다).
- 어느 것이든 끝의 빈 줄을 뗀다(J4).

꼴 판정(`shape`) — 위에서부터 처음 걸리는 것:

| 본 것 | 판정 · 사유 |
|---|---|
| `parse(raw)` 가 `None` | `근거 없음` — `근거 칸이 없거나 줄 꼴이 아니다(옛 줄 · 손으로 쓴 줄)` |
| `scope.tip` 에 묶인 파일이 없거나 읽지 못한다 | `확인 못 함` — `<파일> 을 <끝 8자> 에서 읽지 못했다` |
| `git.commit(판)` 이 `None` 이거나 그 커밋에서 파일을 읽지 못한다 | `확인 못 함` — `줄의 판 <판> 을 이 레포에서 읽지 못한다 — 질문 창으로 다시 승인받는다` |
| 그 판의 본문과 `scope.tip` 의 본문이 다르다 | `낡음` — `<파일> 의 본문이 승인한 판 <판> 뒤에 바뀌었다 — 달라진 곳을 보이고 다시 승인받는다` |
| 그 밖 | `지남` |

- [ ] **Step 1: git 없는 테스트를 쓴다**

`tests/test_human_lines.py`(머리는 `tests/test_team_files.py` 와 같다 — `human_lines as H` · `team_files as F`):

```python
S, E = "00000000-0000-4000-8000-00000000aaaa", "00000000-0000-4000-8000-000000000001"
SPEC = "- spec 승인 · 2026-11-18 · 「승인 — 계획 담당자에게」 · design.md@51f1b64d · 근거 %s:%s#1" % (S, E)
SKIP = "- 걸음 건너뜀 · 2026-11-18 · 「건너뛴다」 · 계획 검토 plan 2 · INTENT.md@51f1b64d · 근거 %s:%s#1" % (S, E)


class LineShape(unittest.TestCase):
    def test_tables(self):
        self.assertEqual(H.KINDS, ("spec 승인", "계획 검토", "흐름 승인", "걸음 건너뜀"))
        self.assertEqual(H.PASS_LABELS, {"spec 승인": ("승인 — 계획 담당자에게",), "계획 검토": ("계획대로 구현한다",),
                                         "흐름 승인": ("설계 없이 진행",), "걸음 건너뜀": ("건너뛴다", "다시 시도한다")})
        self.assertEqual((H.PASS, H.NO_EVIDENCE, H.MISMATCH, H.UNCHECKED, H.STALE), ("지남", "근거 없음", "어긋남", "확인 못 함", "낡음"))
        self.assertEqual(len(set(l for v in H.PASS_LABELS.values() for l in v)), 5)   # 종류마다 라벨이 다르다
        for kind in H.KINDS:
            self.assertIn(kind, F.DECISION_KINDS)

    def test_spec_label_is_the_one_the_approval_question_offers(self):   # J20 — 계획 2 가 나머지 라벨을 더한다
        text = (REPO / "plugins/spec-distill/references/conducting.md").read_text(encoding="utf-8")
        self.assertIn("「%s %s」" % (H.PASS_LABELS[H.KIND_SPEC][0], H.RECOMMENDED), text)

    def test_parse_and_render_round_trip(self):
        l = H.parse(SPEC)
        self.assertEqual((l.kind, l.date, l.label, l.gate, l.file, l.rev, l.session, l.entry, l.index, l.raw, l.key, l.plan),
                         ("spec 승인", "2026-11-18", "승인 — 계획 담당자에게", None, "design.md", "51f1b64d", S, E, 1, SPEC, E + "#1", None))
        self.assertEqual(H.render("spec 승인", "2026-11-18", "승인 — 계획 담당자에게", "design.md", "51f1b64d", S, E + "#1"), SPEC)
        k = H.parse(SKIP)
        self.assertEqual((k.kind, k.label, k.gate, k.file, k.plan), ("걸음 건너뜀", "건너뛴다", "계획 검토 plan 2", "INTENT.md", 2))
        self.assertEqual(H.render("걸음 건너뜀", "2026-11-18", "건너뛴다", "INTENT.md", "51f1b64d", S, E + "#1", gate="계획 검토 plan 2"), SKIP)
        p = H.parse(SPEC.replace("spec 승인", "계획 검토").replace("승인 — 계획 담당자에게", "계획대로 구현한다").replace("design.md", "plan-12.md"))
        self.assertEqual((p.file, p.plan), ("plan-12.md", 12))
        for raw in (SPEC, SKIP):
            self.assertIsNone(F.decision_problem(raw))
            self.assertEqual(H.is_human(raw), H.parse(raw).kind)

    def test_lines_that_are_human_kind_but_do_not_parse(self):
        retry = SKIP.replace("건너뛴다", "다시 시도한다").replace("계획 검토 plan 2", "다시 시도 plan 1 시도 3")
        self.assertEqual(H.parse(retry).gate, "다시 시도 plan 1 시도 3")                     # 양성 대조
        self.assertEqual(H.parse(retry.replace("다시 시도 plan 1 시도 3", "다시 시도 구현 시도 3")).plan, None)
        self.assertIsNone(H.parse(retry.replace("다시 시도 plan 1 시도 3", "다시 시도 시도 3")))   # 설계 없는 흐름의 이름은 「구현 시도」 다
        bad = [
            "- spec 승인 · 2026-11-18 · 「승인 — 계획 담당자에게」",                           # 옛 줄
            SPEC.replace("승인 — 계획 담당자에게", "이대로 승인"),                              # 통과 라벨이 아니다
            SPEC.replace("담당자에게」", "담당자에게 (권장)」"),                               # 꼬리가 남았다
            SPEC.replace("design.md", "plan-1.md"), SPEC.replace("design.md", "INTENT.md"),  # 파일이 종류와 다르다
            SPEC.replace("@51f1b64d", "@51f1b64"), SPEC.replace("@51f1b64d", "@51f1b64d0"), SPEC.replace("@51f1b64d", "@51F1B64D"),
            SPEC.replace("2026-11-18", "2026-02-30"), SPEC.replace("#1", "#0"), SPEC.replace("#1", "#01"),
            SPEC + " x", SPEC + "\n", SPEC.replace(" · 근거 ", " · 근거: "), SPEC.replace(S + ":", "short:"),
            SPEC.replace("」 · design", "」 · spec 승인 · design"),                            # 건너뜀이 아닌데 관문 이름
            SKIP.replace(" · 계획 검토 plan 2", ""), SKIP.replace("계획 검토 plan 2", "아무 관문"),
            SKIP.replace("계획 검토 plan 2", "계획 검토 plan 0"), SKIP.replace("계획 검토 plan 2", "다시 시도 plan 1 시도 3"),
            retry.replace("다시 시도 plan 1 시도 3", "spec 승인"), SKIP.replace("INTENT.md", "design.md"),
        ]
        for raw in bad:
            self.assertIsNone(H.parse(raw), raw)
            self.assertIn(H.is_human(raw), H.KINDS, raw)
        for raw in ("- 결정 · 2026-11-18 · 「글」", "- spec 승인됨 · 2026-11-18 · 「글」", "spec 승인 · 2026-11-18 · 「글」", ""):
            self.assertIsNone(H.is_human(raw), raw)

    def test_labels_heads_and_names(self):
        for text, want in (("승인 — 계획 담당자에게 (권장)", "승인 — 계획 담당자에게"), ("승인 — 계획 담당자에게(권장)", "승인 — 계획 담당자에게"),
                           ("  건너뛴다 ", "건너뛴다"), ("(권장) 승인", "(권장) 승인"), ("승인 (권장) (권장)", "승인 (권장)")):
            self.assertEqual(H.clean_label(text), want)
        self.assertEqual((H.head("R2", "51f1b64d"), H.head("R2", "51f1b64d", 1)), ("R2 @51f1b64d", "R2 plan 1 @51f1b64d"))
        self.assertTrue(H.starts_with_head("R2 plan 1 @51f1b64d — 계획대로 갈까요?", "R2", "51f1b64d", 1))
        for q in ("R2 plan 12 @51f1b64d 질문", "R2 plan 2 @51f1b64d 질문", "R2 @51f1b64d 질문", "R2 plan 1@51f1b64d 질문"):
            self.assertFalse(H.starts_with_head(q, "R2", "51f1b64d", 1), q)
        self.assertFalse(H.starts_with_head("R2 plan 1 @51f1b64d 질문", "R2", "51f1b64d"))      # 계획 번호 없는 머리와도 갈린다
        self.assertTrue(H.names_gate("다시 시도 plan 1 시도 3 을 풀까요", "다시 시도 plan 1 시도 3"))
        self.assertTrue(H.names_gate("spec 승인을 건너뛸까요 · 계획 검토 plan 1", "계획 검토 plan 1"))
        for text, name in (("다시 시도 plan 1 시도 31 을 풀까요", "다시 시도 plan 1 시도 3"), ("계획 검토 plan 12 를 건너뛸까요", "계획 검토 plan 1"), ("", "spec 승인")):
            self.assertFalse(H.names_gate(text, name), text)
        for q in ("R2 @51f1b64d — 설계를 승인할까요?", "R2 @51f1b64d", "R2 @51f1b64d\n둘째 줄"):
            self.assertTrue(H.starts_with_head(q, "R2", "51f1b64d"), q)
        for q in (" R2 @51f1b64d — 질문", "**R2 @51f1b64d** 질문", "\nR2 @51f1b64d", "R21 @51f1b64d 질문", "R2 @51f1b64d0 질문",
                  "R2 @51F1B64D 질문", "R2  @51f1b64d 질문", "r2 @51f1b64d 질문", "질문 R2 @51f1b64d", ""):
            self.assertFalse(H.starts_with_head(q, "R2", "51f1b64d"), q)
        self.assertEqual([H.bound_name(H.KIND_SPEC), H.bound_name(H.KIND_PLAN, 2), H.bound_name(H.KIND_FLOW), H.bound_name(H.KIND_SKIP)],
                         ["design.md", "plan-2.md", "INTENT.md", "INTENT.md"])
        self.assertEqual([H.gate_name(H.KIND_SPEC), H.gate_name(H.KIND_PLAN, 2), H.retry_name(2, 3), H.retry_name(None, 3)],
                         ["spec 승인", "계획 검토 plan 2", "다시 시도 plan 2 시도 3", "다시 시도 구현 시도 3"])


DESIGN = "# 설계\n\n## Goals\n\n본문 하나\n\n```\n## 결정 기록\n펜스 안 글\n```\n\n## Handoff\n\n넘김\n\n### Deferred to plan\n\n| a | b |\n\n### 남는 소제목\n\n남는 글\n\n## 미룸\n\n| 항목 |\n\n## 결정 기록\n\n- D1\n\n## 지휘 기록\n\n- 기록\n"


class Body(unittest.TestCase):
    def test_design_body_leaves_out_record_sections(self):
        body = H.body_of("design.md", DESIGN)
        for kept in ("본문 하나", "펜스 안 글", "## Handoff", "넘김", "### 남는 소제목", "남는 글"):
            self.assertIn(kept, body)
        for gone in ("| a | b |", "| 항목 |", "- D1", "- 기록", "### Deferred to plan"):
            self.assertNotIn(gone, body)
        same = [DESIGN.replace("- D1", "- D1\n- D2"), DESIGN.replace("| 항목 |", "| 항목 |\n| 새 미룸 |"), DESIGN.replace("| a | b |", "| c |"),
                DESIGN + "\n## 판정\n\n- 판정\n\n## 구현 대조 — plan-1.md\n\n- 대조\n", DESIGN + "\n\n\n"]
        for text in same:
            self.assertEqual(H.body_of("design.md", text), body)
        for text in (DESIGN.replace("본문 하나", "본문 둘"), DESIGN.replace("펜스 안 글", "펜스 안 다른 글"), DESIGN.replace("남는 글", "바뀐 글"),
                     DESIGN + "\n## 미룸표 아닌 새 절\n\n글\n", DESIGN.replace("## Goals", "## Goals 2")):
            self.assertNotEqual(H.body_of("design.md", text), body)

    def test_plan_and_intent_bodies(self):
        self.assertEqual(H.body_of("plan-1.md", "# 계획\n\n## 결정 기록\n\n- x\n\n"), "# 계획\n\n## 결정 기록\n\n- x")
        intent = "---\njob: E1\n---\n\n## 목표\n\n목표 글\n\n## 지시 원문\n\n## 결정 기록\n받은 말 안의 제목 꼴\n\n## 하지 않을 것\n\n- 없음\n\n## 결정 기록\n"
        body = H.body_of("INTENT.md", intent)
        self.assertIn("받은 말 안의 제목 꼴", body)
        self.assertEqual(H.body_of("INTENT.md", intent + "\n- 결정 · 2026-11-18 · 「글」\n"), body)
        self.assertNotEqual(H.body_of("INTENT.md", intent.replace("목표 글", "다른 목표")), body)
```

- [ ] **Step 2: 임시 레포 테스트를 쓴다**

`tests/test_human_judge.py`. `setUp` 이 임시 폴더에 git 레포를 만든다(`git init -q -b main`, 사용자 이름 · 메일은 `-c` 로, `GIT_CONFIG_GLOBAL=/dev/null`). 도우미 `commit(path, text, msg) -> 커밋 번호` 는 파일을 쓰고 pathspec 으로 커밋한다. `TEAM = team_layout.Team("docs/r/", "tm")` · `JOB = "E1"` · `GIT = roadmap_status.Git(레포)` · `scope(tip, lines=(), gate_on=True) -> H.Scope`.

```python
class Version(Repo):
    def test_version_is_the_last_commit_that_changed_the_body(self):
        path = TEAM.design(JOB)
        c1 = self.commit(path, DESIGN, "설계")
        self.assertEqual(H.version(self.git, c1, path), c1[:8])
        c2 = self.commit(path, DESIGN.replace("- 기록", "- 기록\n- 둘째"), "기록 절만")
        self.assertEqual(H.version(self.git, c2, path), c1[:8])
        c3 = self.commit(path, DESIGN.replace("본문 하나", "본문 둘"), "본문")
        c4 = self.commit("other.txt", "x", "다른 파일")
        self.assertEqual(H.version(self.git, c4, path), c3[:8])
        c5 = self.commit(path, DESIGN, "본문을 처음 글로 되돌림")
        self.assertEqual(H.version(self.git, c5, path), c5[:8])            # c1 과 본문이 같아도 이어진 구간이 아니다
        self.assertEqual(H.version(self.git, c1, path), c1[:8])            # 끝마다 따로 센다
        self.assertIsNone(H.version(self.git, c5, TEAM.plan(JOB, 1)))


class ShapeVerdict(Repo):
    def line(self, rev, file="design.md", kind="spec 승인", label="승인 — 계획 담당자에게"):
        return H.render(kind, "2026-11-18", label, file, rev, S, E + "#1")

    def test_verdicts(self):
        path = TEAM.design(JOB)
        c1 = self.commit(path, DESIGN, "설계")
        c2 = self.commit(path, DESIGN.replace("| 항목 |", "| 항목 |\n| 새 미룸 |").replace("- 기록", "- 기록\n- 승인 직전 기록"), "미룸 · 기록 절만")
        c3 = self.commit(path, DESIGN.replace("본문 하나", "본문 둘"), "본문")
        with mock.patch.dict(os.environ, {"CLAUDE_CONFIG_DIR": "/nonexistent/claude"}):   # 꼴 판정은 세션 기록을 읽지 않는다
            self.assertEqual(H.shape(self.scope(c1), self.line(c1[:8])).verdict, H.PASS)
            self.assertEqual(H.shape(self.scope(c2), self.line(c1[:8])).verdict, H.PASS)      # AC8 — 기록 절 · 미룸 절
            stale = H.shape(self.scope(c3), self.line(c1[:8]))
            self.assertEqual((stale.verdict, "다시 승인받는다" in stale.why, stale.line.rev), (H.STALE, True, c1[:8]))
            self.assertEqual(H.shape(self.scope(c3), self.line(c3[:8])).verdict, H.PASS)
            self.assertEqual(H.shape(self.scope(c3), self.line("deadbeef")).verdict, H.UNCHECKED)
            self.assertEqual(H.shape(self.scope(c3), self.line(c3[:8], "plan-1.md", "계획 검토", "계획대로 구현한다")).verdict, H.UNCHECKED)
            none = H.shape(self.scope(c3), "- spec 승인 · 2026-11-18 · 「승인 — 계획 담당자에게」")
            self.assertEqual((none.verdict, none.line), (H.NO_EVIDENCE, None))
```

- [ ] **Step 3: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_human_lines.py plugins/spec-distill/tests/test_human_judge.py 2>&1 | tail -3`
Expected: `ModuleNotFoundError: No module named 'human_lines'`

- [ ] **Step 4: `human_lines.py` 를 쓴다(이 과제의 Produces 까지)**

위 Interfaces · 줄 꼴 · 본문 · 꼴 판정 표대로 쓴다. 제목 줄은 정규식이 아니라 `str.startswith` 로 가른다(레포 락). `version` 은 `git.run_err("log", "--format=%H", tip, "--", ":(top,literal)" + path)` 의 커밋들을 새것부터 읽는다 — git 이 실패하면 `git.fail("log", rc, err)` 로 남기고 `None`. Global Constraints 의 「상태 계산의 잠금 목록」 규칙을 지킨다 — 이름이 `replace` 인 호출을 쓰지 않는다.

- [ ] **Step 5: 새 모듈 둘을 상태 계산의 잠금 목록에 넣는다(J29)**

`tests/test_roadmap_status.sh` 의 세 곳만 고친다.

- 정적 검사를 부르는 줄(`out="$(LOCAL_DIR="$S" static_check "$RS" …`)의 인자 끝에 `"$S/human_lines.py" "$S/session_record.py"` 를 더한다.
- 그 아래 두 단언의 글자 — `"CHECKED 14"` 를 `"CHECKED 16"` 으로, 이름의 「열네 스크립트」 를 「열여섯 스크립트」 로(두 줄).
- 변이 사본을 만드는 `cp` 두 곳(`"$M/"` 로 가는 것과 `"$M3/"` 로 가는 것)의 목록에 `"$S/human_lines.py" "$S/session_record.py"` 를 더한다.

- [ ] **Step 6: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_human_lines.py plugins/spec-distill/tests/test_human_judge.py 2>&1 | tail -3; bash plugins/spec-distill/tests/test_check_brief.sh | tail -1; bash plugins/spec-distill/tests/test_roadmap_status.sh | grep -E '✗|정적' ; git diff --stat -- plugins/spec-distill/tests/test_roadmap_status.sh`
Expected: `OK` · 셸 테스트 요약 줄에 실패 0 · `정적: 열여섯 스크립트에 … 가 없다` 와 `정적 검사가 열여섯 스크립트를 셌다` 가 ✓ 이고 ✗ 줄이 없다 · diff 는 다섯 줄 안팎(위 세 곳)뿐이다. 정적 검사가 두 새 모듈의 줄을 짚으면(`쓰기 호출 replace` · `잠긴 파일 밖 로컬 모듈 import …`) 검사 목록을 줄이지 않고 그 모듈의 코드를 규칙에 맞게 고친다.
- [ ] **Step 7: 커밋**

```bash
git add plugins/spec-distill/scripts/human_lines.py plugins/spec-distill/tests/test_human_lines.py plugins/spec-distill/tests/test_human_judge.py plugins/spec-distill/tests/test_roadmap_status.sh
git commit -m "feat(spec-distill): 사람 줄의 꼴 · 본문 · 판과 꼴 판정을 더한다"
```

---

### Task 6: 대조 판정과 관문 표(`human_lines.py`)

**AC:** AC5(쓰는 조건) · AC9(관문 표) · AC11 · AC12 · AC20(꺼졌을 때 줄의 유무만)

**Files:**
- Modify: `plugins/spec-distill/scripts/human_lines.py`
- Test: `plugins/spec-distill/tests/test_human_judge.py`

**Interfaces:**
- Consumes: 과제 2 의 `session_record.locate` · `find` · `day` · `Unreadable` · `HUMAN` · `NOT_HUMAN` · `UNKNOWN` 과 `Answer` 의 `who` · `why` · `when`. 과제 5 의 모든 것. `roadmap_model.approval_in`.
- Produces:
  - `GATES = {"design": (), "plan": (KIND_SPEC,), "implement": (KIND_SPEC, KIND_PLAN), "review": (KIND_SPEC, KIND_PLAN)}` · `PLAIN_GATES = (KIND_FLOW,)` · `RETRY_STOP = 2` · `GATE_OFF = "사람 줄 대조가 꺼져 있다"` · `NO_LINE = "줄이 없다"`
  - `class Passed(NamedTuple)` — `date: str` · `skipped: bool`(건너뜀 줄로 지났다)
  - `match(scope, raw) -> Verdict` — 대조 판정
  - `needed(stage, plan, plain) -> list` — `[(종류, 계획 | None), …]`. 설계 없는 흐름이면 어느 단계든 `[(KIND_FLOW, None)]`, 아니면 `GATES[stage]` 의 차례이고 `KIND_PLAN` 에만 계획 번호가 붙는다
  - `passed(scope, kind, plan, deep: bool) -> tuple` — `(Passed | None, 사유 | None)`. `deep` 이 참이면 대조 판정, 거짓이면 꼴 판정으로 본다
  - `missing(scope, stage, plan, plain, deep) -> list` — 지나지 못한 관문마다 사유 한 줄(관문 표의 차례)
  - `retry_open(scope, plan, attempt, deep) -> bool` — 그 시도를 푸는 산 `걸음 건너뜀` 줄이 있는가
  - `collect(git, team, job, tips) -> tuple` — `(겹침 없는 결정 기록 줄들(튜플 · 처음 나온 차례), 알림 줄들)`. `tips` 의 커밋마다 그 과제 INTENT.md 의 결정 기록 줄을 모은다. 그 커밋에 INTENT.md 가 없으면 건너뛰고, 있는데 결정 기록 칸을 읽지 못하면 건너뛰고 `"<커밋 8자> 의 결정 기록을 읽지 못했다 — <사유>"` 를 알린다
  - `expected(plain: bool, plan_files: list, result_names: list, received_names: list) -> list` — 자취로 볼 때 **있어야 하는** 사람 줄(J24). `[(종류, 계획 | None, 자취 글), …]` 이고 차례는 `spec 승인` · `계획 검토`(계획 번호 차례) 다. 설계 흐름: 계획 파일 · 단계가 `plan` · `implement` · `review` 인 결과 파일 · 받음 줄 가운데 하나라도 있으면 `(KIND_SPEC, None, …)`, 계획 n 의 `implement` · `review` 결과 파일이나 계획 n 의 받음 줄이 있으면 `(KIND_PLAN, n, …)`. 설계 없는 흐름: 결과 파일이나 받음 줄이 있으면 `(KIND_FLOW, None, …)`. 자취 글은 그 줄을 있어야 하게 만든 첫 자취다 — 계획 파일(이름 차례) · 결과 파일(이름 차례) · 받음 줄의 차례로 찾고 `<이름> 가 있다`, 받음 줄이면 `<결과 파일 이름> 의 받음 줄이 있다`

대조 판정(`match`) — 꼴 판정을 먼저 하고 `지남` 이 아니면 그 판정을 그대로 낸다. 그 뒤 위에서부터 처음 걸리는 것:

| 본 것 | 판정 · 사유 |
|---|---|
| `session_record.locate(줄의 세션)` 이 `Unreadable` | `확인 못 함` — `<사유> — 질문 창으로 다시 승인받는다` |
| `find(파일, 줄의 key)` 가 `None`, 또는 읽다가 `Unreadable` | 없으면 `어긋남` — `근거가 가리키는 질문 창 답이 세션 기록에 없다`. 읽지 못하면 `확인 못 함` |
| 답의 `who` 가 `UNKNOWN`(칸이 없다 · 꼴이 다르다 · 모르는 출처 — J2 · J33) | `확인 못 함` — `<답의 why> — 질문 창으로 다시 승인받는다. 기록의 꼴이 바뀐 것이면 레포 설정 human_gate: 끔 으로 연다` |
| 답의 `who` 가 `NOT_HUMAN` | `어긋남` — `<답의 why>` |
| 질문 글이 그 줄의 머리로 시작하지 않는다 — 머리는 `head(과제, 줄의 판)`, `계획 검토` 줄은 `head(과제, 줄의 판, 줄의 계획 번호)` | `어긋남` — `그 질문은 머리 <머리> 로 시작하지 않는다` |
| `clean_label(답의 글자)` 가 줄의 라벨과 다르다 | `어긋남` — `사람이 고른 라벨은 「<고른 글>」 이다` |
| 줄의 날짜가 `session_record.day(답의 when, local=False)` 와 하루 넘게 다르다(J28) | `어긋남` — `줄의 날짜 <날짜> 가 답한 날 <그 날짜> 와 다르다` |
| 건너뜀 줄인데 `names_gate(질문 글, 관문 이름)` 이 거짓이다 | `어긋남` — `그 질문에 관문 이름 <이름> 이 없다` |
| `scope.lines` 에 글자가 다른 줄이면서 `parse` 되고 `key` 가 같은 줄이 있다(세션이 달라도 같은 답이다 — J3) | `어긋남` — `같은 답을 근거로 쓴 줄이 또 있다` |
| 그 밖 | `지남` |

관문 하나(`passed`):

- `scope.gate_on` 이 참이면 — 후보는 `is_human(raw) == kind` 인 줄이다(`KIND_PLAN` 은 `parse` 되면 `plan` 이 같은 줄만, `parse` 되지 않는 줄은 후보로 남는다). 후보 가운데 판정이 `지남` 인 줄이 있으면 `(Passed(그 날짜, False), None)`. 없으면 `KIND_SPEC` · `KIND_PLAN` 은 `parse` 된 `걸음 건너뜀` 줄 가운데 `gate == gate_name(kind, plan)` 이고 판정이 `지남` 인 줄을 찾아 있으면 `(Passed(그 날짜, True), None)`. 그래도 없으면 `(None, 사유)` — 후보가 없으면 `NO_LINE`, 있으면 마지막 후보의 `"%s — %s" % (판정, 사유)`.
- `scope.gate_on` 이 거짓이면(J9) — `KIND_SPEC` 은 `approval_in(scope.lines)` 의 날짜가 있으면 지남, 그 밖의 종류는 `- <종류> · <날짜> · ` 로 시작하는 줄이 있으면 지남(날짜는 그 줄의 것), `KIND_SPEC` · `KIND_PLAN` 은 `- 걸음 건너뜀 · ` 줄 가운데 `names_gate(줄, gate_name(kind, plan))` 이 참인 줄이 있어도 지남(`skipped=True`). 세션 기록도 판도 보지 않는다.

`missing` 의 사유 줄(관문마다 하나):

- 줄이 없다 → `` `<종류>` 줄이 없다[(계획 <n>)] — 질문 창으로 승인받고 `conductor_ledger.py record --human "<종류>"` 로 적는다 ``
- 줄이 지나지 못했다 → `` `<종류>` 줄이 지나지 못했다[(계획 <n>)]: <판정> — <사유> ``(사유에 다음 할 일이 들어 있다. `근거 없음` · `어긋남` 에는 `` — 질문 창으로 승인받고 `conductor_ledger.py record --human "<종류>"` 로 다시 적는다 `` 를 붙인다)

`retry_open` — 켜져 있으면 `parse` 된 `걸음 건너뜀` 줄 가운데 `gate == retry_name(plan, attempt)` 이고 판정(`deep` 에 따라)이 `지남` 인 줄이 있는가. 꺼져 있으면 `- 걸음 건너뜀 · ` 줄 가운데 `names_gate(줄, 그 이름)` 이 참인 줄이 있는가.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_human_judge.py` 에 더한다. `Repo.setUp` 이 `self.conf`(임시 설정 폴더)를 만들고 `mock.patch.dict(os.environ, {"CLAUDE_CONFIG_DIR": self.conf})` 를 건다. 도우미:

```python
    def approve(self, tip, kind=H.KIND_SPEC, plan=None, gate=None, picked=None, question=None, rev=None, session=S, when="2026-11-18T12:00:00.000Z", **kw):
        """그 끝의 묶인 파일로 머리를 만들고, 그 머리로 시작하는 질문 창 답을 기록에 지어 넣고, 그 답을 가리키는 줄을 돌려준다."""
        name = H.bound_name(kind, plan)
        rev = rev or H.version(self.git, tip, TEAM.job(JOB, name))
        label = H.RETRY_LABEL if (gate or "").startswith("다시 시도") else H.PASS_LABELS[kind][0]
        text = question or "%s — %s자리표시 질문" % (H.head(JOB, rev, plan if kind == H.KIND_PLAN else None), (gate + " ") if gate else "")
        uid = SF.add_answer(self.conf, session, [(text, picked or label + " (권장)")], when=when, **kw)   # who · drop · sidechain · subagent 는 kw 로
        return H.render(kind, when[:10], label, name, rev, session, uid + "#1", gate=gate)
```

`setUp` 뒤의 레포: `c1` 설계(`DESIGN`) · `c2` `plan-1.md` · `c3` `plan-2.md` · `c4` `INTENT.md`(상수 `INTENT` — 과제 5 의 `test_plan_and_intent_bodies` 가 쓴 글과 같은 글) — 파일마다 다른 커밋이다. `tip = c4`. `DESIGN` · `INTENT` · `S` · `E` 는 이 파일에도 상수로 둔다(테스트 파일끼리 가져오지 않는다). 도우미 `commit_many({경로: 글, …}, msg) -> 커밋 번호` 는 파일 여럿을 한 커밋으로 넣는다. 이 파일은 `re` 를 가져온다.

```python
class Match(Repo):
    def v(self, raw, lines=None, tip=None):
        return H.match(self.scope(tip or self.tip, tuple(lines if lines is not None else [raw])), raw).verdict

    def test_real_line_passes(self):                                     # 양성 대조
        self.assertEqual(self.v(self.approve(self.tip)), H.PASS)
        self.assertEqual(self.v(self.approve(self.tip, H.KIND_PLAN, 1)), H.PASS)
        self.assertEqual(self.v(self.approve(self.tip, H.KIND_SKIP, gate="계획 검토 plan 2")), H.PASS)
        self.assertEqual(self.v(self.approve(self.tip, picked="승인 — 계획 담당자에게")), H.PASS)

    def test_forged_lines_do_not_pass(self):
        real = self.approve(self.tip)
        l = H.parse(real)
        cases = {
            "손으로 쓴 줄": ("- spec 승인 · 2026-11-18 · 「승인 — 계획 담당자에게」", H.NO_EVIDENCE),
            "없는 항목": (real.replace(l.entry, "00000000-0000-4000-8000-00000000dead"), H.MISMATCH),
            "없는 순번": (real.replace("#1", "#2"), H.MISMATCH),
            "다른 과제의 답": (self.approve(self.tip, question="E2 @%s — 질문" % l.rev), H.MISMATCH),
            "라벨만 바꾼 줄": (self.approve(self.tip, picked="수정 필요"), H.MISMATCH),
            "머리 앞에 공백": (self.approve(self.tip, question=" " + H.head(JOB, l.rev) + " 질문"), H.MISMATCH),
            "사람 아님(수락이 아니다)": (self.approve(self.tip, who="denied"), H.MISMATCH),
            "모르는 출처": (self.approve(self.tip, who="other"), H.UNCHECKED),
            "곁가지 항목": (self.approve(self.tip, sidechain=True), H.MISMATCH),
            "하위 agent 기록": (self.approve(self.tip, subagent=True), H.MISMATCH),
            "아는 칸 없음": (self.approve(self.tip, who="unknown"), H.UNCHECKED),
            "기록 파일 없음": (real.replace(S + ":", "00000000-0000-4000-8000-00000000ffff:"), H.UNCHECKED),
            "다른 계획 파일의 답": (self.approve(self.tip, H.KIND_PLAN, 1).replace("plan-1.md@%s" % self.c2[:8], "plan-2.md@%s" % self.c3[:8]), H.MISMATCH),
            "건너뜀 — 질문에 관문 이름 없음": (self.approve(self.tip, H.KIND_SKIP, gate="계획 검토 plan 2", question=H.head(JOB, self.c4[:8]) + " 건너뛸까요"), H.MISMATCH),
            "건너뜀 — 다른 관문의 답": (self.approve(self.tip, H.KIND_SKIP, gate="계획 검토 plan 1").replace("계획 검토 plan 1", "계획 검토 plan 2"), H.MISMATCH),
        }
        for name, (raw, want) in cases.items():
            self.assertEqual(self.v(raw), want, name)
        self.assertIn("다시 승인받는다", H.match(self.scope(self.tip, (cases["기록 파일 없음"][0],)), cases["기록 파일 없음"][0]).why)

    def test_other_question_of_the_same_call(self):
        rev = self.c1[:8]
        uid = SF.add_answer(self.conf, S, [(H.head(JOB, rev) + " 승인할까요", "수정 필요"), ("다음 에픽도 함께 할까요", "승인 — 계획 담당자에게")],
                            when="2026-11-18T12:00:00.000Z")
        for n in (1, 2):
            raw = H.render(H.KIND_SPEC, "2026-11-18", "승인 — 계획 담당자에게", "design.md", rev, S, "%s#%d" % (uid, n))
            self.assertEqual(self.v(raw), H.MISMATCH, n)

    def test_old_answer_with_a_rewritten_version(self):
        real = self.approve(self.tip)                                    # c1 의 본문을 보고 한 답
        c5 = self.commit(TEAM.design(JOB), DESIGN.replace("본문 하나", "본문 둘"), "승인 뒤 본문 고침")
        self.assertEqual(self.v(real, tip=c5), H.STALE)
        rewritten = real.replace("design.md@" + self.c1[:8], "design.md@" + c5[:8])
        self.assertEqual(H.shape(self.scope(c5, (rewritten,)), rewritten).verdict, H.PASS)   # 꼴만 보면 지난다
        self.assertEqual(self.v(rewritten, tip=c5), H.MISMATCH)                               # 사람이 본 질문에는 옛 판이 있다

    def test_one_answer_two_lines(self):
        real = self.approve(self.tip)
        twin = real.replace("2026-11-18", "2026-11-19")
        self.assertEqual(self.v(real, [real, twin]), H.MISMATCH)
        self.assertEqual(self.v(twin, [real, twin]), H.MISMATCH)
        self.assertEqual(self.v(real, [real, "- 결정 · 2026-11-18 · 「글」"]), H.PASS)   # 여러 끝에서 모은 같은 줄은 한 줄이다(겹침 없이 넘긴다)
        other = "00000000-0000-4000-8000-00000000bbbb"                                    # 이어받은 세션이 같은 uuid 를 복사했다
        SF.add_answer(self.conf, other, [(H.head(JOB, self.c1[:8]) + " 질문", "승인 — 계획 담당자에게")], entry=H.parse(real).entry,
                      when="2026-11-18T12:00:00.000Z")
        self.assertEqual(self.v(copy_alone := real.replace(S + ":", other + ":"), [copy_alone]), H.PASS)   # 이어받은 세션의 답만 있으면 지난다(J3)
        copy = real.replace(S + ":", other + ":").replace("2026-11-18", "2026-11-19")
        self.assertEqual(self.v(copy, [real, copy]), H.MISMATCH)


    def test_plan_head_carries_the_plan_number(self):   # 설계 §2 — 계획 파일 둘을 한 커밋이 마지막으로 고쳤다
        both = self.commit_many({TEAM.plan(JOB, 1): "# 계획 1 고침\n", TEAM.plan(JOB, 2): "# 계획 2 고침\n"}, "두 계획을 한 커밋에서")
        self.assertEqual(H.version(self.git, both, TEAM.plan(JOB, 1)), H.version(self.git, both, TEAM.plan(JOB, 2)))   # 판이 같다
        one = self.approve(both, H.KIND_PLAN, 1)
        self.assertIn("근거", one)
        self.assertEqual(self.v(one, tip=both), H.PASS)
        as_two = re.sub(r"plan-1\.md@", "plan-2.md@", one)
        self.assertEqual(H.shape(self.scope(both, (as_two,)), as_two).verdict, H.PASS)      # 꼴만 보면 지난다
        self.assertEqual(self.v(as_two, tip=both), H.MISMATCH)                               # 머리의 계획 번호로 갈린다
        two = self.approve(both, H.KIND_PLAN, 2)
        self.assertEqual(self.v(two, [one, two], tip=both), H.PASS)

    def test_date_comes_from_the_answer(self):   # J28
        real = self.approve(self.tip, when="2026-11-18T23:30:00.000Z")
        self.assertIn(" · 2026-11-18 · ", real)
        for near in ("2026-11-18", "2026-11-19", "2026-11-17"):                              # 시간대 차이는 하루를 넘지 않는다
            self.assertEqual(self.v(re.sub("2026-11-18", near, real)), H.PASS, near)
        for forged in ("2026-11-20", "2026-11-16", "2025-11-18"):
            self.assertEqual(self.v(re.sub("2026-11-18", forged, real)), H.MISMATCH, forged)

    def test_gate_names_are_not_matched_as_substrings(self):
        q = H.head(JOB, self.c4[:8]) + " — 계획 검토 plan 12 를 건너뛸까요"
        twelve = self.approve(self.tip, H.KIND_SKIP, gate="계획 검토 plan 12", question=q)
        self.assertEqual(self.v(twelve), H.PASS)
        one = re.sub("계획 검토 plan 12 · ", "계획 검토 plan 1 · ", twelve)
        self.assertEqual(H.parse(one).gate, "계획 검토 plan 1")
        self.assertEqual(self.v(one), H.MISMATCH)

    def test_changed_record_shapes_are_unchecked(self):   # J33 — 조용히 「어긋남」 이 되지 않는다
        for drop in (("isSidechain",), ("sourceToolAssistantUUID",), ("answers",), ("toolUseResult",), ("timestamp",)):
            raw = self.approve(self.tip, drop=drop)
            got = H.match(self.scope(self.tip, (raw,)), raw)
            self.assertEqual(got.verdict, H.UNCHECKED, drop)
            self.assertIn("human_gate: 끔", got.why, drop)


class Gates(Repo):
    def miss(self, lines, stage, plan=None, plain=False, deep=True, gate_on=True):
        return H.missing(self.scope(self.tip, tuple(lines), gate_on), stage, plan, plain, deep)

    def test_gate_table_is_fixed(self):
        self.assertEqual(H.GATES, {"design": (), "plan": ("spec 승인",), "implement": ("spec 승인", "계획 검토"), "review": ("spec 승인", "계획 검토")})
        self.assertEqual((H.PLAIN_GATES, H.RETRY_STOP, H.GATE_OFF), (("흐름 승인",), 2, "사람 줄 대조가 꺼져 있다"))
        self.assertEqual([H.needed("design", None, False), H.needed("plan", 1, False), H.needed("implement", 2, False), H.needed("review", 2, False)],
                         [[], [("spec 승인", None)], [("spec 승인", None), ("계획 검토", 2)], [("spec 승인", None), ("계획 검토", 2)]])
        for stage in ("design", "plan", "implement", "review"):
            self.assertEqual(H.needed(stage, None, True), [("흐름 승인", None)])
        source = (SCRIPTS / "human_lines.py").read_text(encoding="utf-8")
        for word in ("repo_defaults", "walk_table", "os.environ"):       # AC9 — 관문 표는 설정 · 걸음표 · 환경에서 읽지 않는다
            self.assertNotIn(word, source, word)

    def test_missing(self):
        spec, plan1 = self.approve(self.tip), self.approve(self.tip, H.KIND_PLAN, 1)
        self.assertEqual(self.miss([], "design"), [])
        none = self.miss([], "implement", 1)
        self.assertEqual(len(none), 2)
        self.assertTrue(none[0].startswith("`spec 승인` 줄이 없다") and 'record --human "spec 승인"' in none[0], none[0])
        self.assertTrue(none[1].startswith("`계획 검토` 줄이 없다(계획 1)"), none[1])
        self.assertEqual(self.miss([spec], "plan", 1), [])
        self.assertEqual(len(self.miss([spec], "implement", 1)), 1)
        self.assertEqual(self.miss([spec, plan1], "implement", 1), [])
        self.assertEqual(self.miss([spec, plan1], "review", 1), [])
        two = self.miss([spec, plan1], "implement", 2)                   # 계획 1 의 줄은 계획 2 를 열지 않는다
        self.assertEqual((len(two), "계획 2" in two[0]), (1, True))
        hand = "- spec 승인 · 2026-11-18 · 「승인 — 계획 담당자에게」"
        self.assertIn("근거 없음", self.miss([hand], "plan", 1)[0])
        self.assertIn("record --human", self.miss([hand], "plan", 1)[0])

    def test_skip_line_opens_only_its_gate(self):
        spec, plan1 = self.approve(self.tip), self.approve(self.tip, H.KIND_PLAN, 1)
        skip2 = self.approve(self.tip, H.KIND_SKIP, gate="계획 검토 plan 2")
        self.assertEqual(self.miss([spec, skip2], "implement", 2), [])
        self.assertEqual(len(self.miss([spec, skip2], "implement", 1)), 1)       # 다른 관문은 그대로
        self.assertEqual(len(self.miss([skip2], "implement", 2)), 1)             # spec 승인은 그대로
        skip_spec = self.approve(self.tip, H.KIND_SKIP, gate="spec 승인")
        self.assertEqual(self.miss([skip_spec], "plan", 1), [])
        got, why = H.passed(self.scope(self.tip, (skip_spec,)), H.KIND_SPEC, None, True)
        self.assertEqual((got, why), (H.Passed("2026-11-18", True), None))
        self.assertEqual(H.passed(self.scope(self.tip, (spec,)), H.KIND_SPEC, None, True)[0], H.Passed("2026-11-18", False))
        self.assertEqual(H.passed(self.scope(self.tip, ()), H.KIND_SPEC, None, True), (None, H.NO_LINE))

    def test_collect_reads_every_tip_once(self):
        one = "- 결정 · 2026-11-18 · 「하나」"
        a = self.commit(TEAM.intent(JOB), INTENT + "\n" + one + "\n", "줄 하나")
        b = self.commit(TEAM.intent(JOB), INTENT + "\n" + one + "\n- 결정 · 2026-11-19 · 「둘」\n", "줄 둘")
        self.assertEqual(H.collect(self.git, TEAM, JOB, [a, b, a, self.c1]), ((one, "- 결정 · 2026-11-19 · 「둘」"), []))   # c1 에는 INTENT.md 가 없다
        broken = self.commit(TEAM.intent(JOB), "머리 없는 글\n", "깨진 INTENT")
        lines, notes = H.collect(self.git, TEAM, JOB, [broken, b])
        self.assertEqual((len(lines), len(notes), broken[:8] in notes[0]), (2, 1, True))

    def test_expected_lines_from_traces(self):   # J24 — human-check 가 「있어야 하는데 없는 줄」 을 찾는 표
        self.assertEqual(H.expected(False, [], [], []), [])
        self.assertEqual(H.expected(False, [], ["design-1.md"], []), [])
        self.assertEqual(H.expected(False, ["plan-1.md"], [], []), [("spec 승인", None, "plan-1.md 가 있다")])
        self.assertEqual(H.expected(False, ["plan-1.md", "plan-2.md"], ["plan-plan-1-1.md", "implement-plan-2-1.md", "review-plan-2-1.md"], []),
                         [("spec 승인", None, "plan-1.md 가 있다"), ("계획 검토", 2, "implement-plan-2-1.md 가 있다")])
        self.assertEqual(H.expected(False, [], [], ["implement-plan-1-2.md"]),
                         [("spec 승인", None, "implement-plan-1-2.md 의 받음 줄이 있다"), ("계획 검토", 1, "implement-plan-1-2.md 의 받음 줄이 있다")])
        self.assertEqual(H.expected(False, [], ["plan-plan-3-1.md"], []), [("spec 승인", None, "plan-plan-3-1.md 가 있다")])
        self.assertEqual(H.expected(True, [], [], []), [])
        self.assertEqual(H.expected(True, [], ["implement-1.md"], []), [("흐름 승인", None, "implement-1.md 가 있다")])
        self.assertEqual(H.expected(True, [], [], ["implement-1.md"]), [("흐름 승인", None, "implement-1.md 의 받음 줄이 있다")])
    def test_shallow_and_deep(self):
        spec = self.approve(self.tip)
        with mock.patch.dict(os.environ, {"CLAUDE_CONFIG_DIR": "/nonexistent/claude"}):
            self.assertEqual(self.miss([spec], "plan", 1, deep=False), [])
            self.assertIn("확인 못 함", self.miss([spec], "plan", 1, deep=True)[0])

    def test_plain_flow(self):
        flow = self.approve(self.tip, H.KIND_FLOW)
        self.assertEqual(self.miss([flow], "implement", None, plain=True), [])
        self.assertEqual(len(self.miss([self.approve(self.tip)], "implement", None, plain=True)), 1)
        self.assertIn("흐름 승인", self.miss([], "implement", None, plain=True)[0])

    def test_retry(self):
        retry = self.approve(self.tip, H.KIND_SKIP, gate="다시 시도 plan 1 시도 3")
        sc = self.scope(self.tip, (retry,))
        self.assertEqual([H.retry_open(sc, 1, 3, True), H.retry_open(sc, 1, 4, True), H.retry_open(sc, 2, 3, True), H.retry_open(sc, None, 3, True)],
                         [True, False, False, False])
        plain = self.approve(self.tip, H.KIND_SKIP, gate="다시 시도 구현 시도 3")
        self.assertTrue(H.retry_open(self.scope(self.tip, (plain,)), None, 3, True))
        self.assertTrue(self.miss([retry], "plan", 1)[0].startswith("`spec 승인` 줄이 없다"))   # 다시 시도 줄은 다른 관문을 열지 않는다

    def test_gate_off_looks_only_for_lines(self):
        with mock.patch.dict(os.environ, {"CLAUDE_CONFIG_DIR": "/nonexistent/claude"}):
            self.assertEqual(len(self.miss([], "implement", 1, gate_on=False)), 2)
            lines = ["- spec 승인 · 2026-11-18 · 「승인」", "- 계획 검토 · 2026-11-18 · 「좋다」"]
            self.assertEqual(self.miss(lines, "implement", 7, gate_on=False), [])
            self.assertEqual(self.miss(lines[:1], "plan", 1, gate_on=False), [])
            self.assertEqual(len(self.miss(lines[:1], "implement", 1, gate_on=False)), 1)
            skip = "- 걸음 건너뜀 · 2026-11-18 · 「건너뛴다」 · 계획 검토 plan 1"
            self.assertEqual(self.miss([lines[0], skip], "implement", 1, gate_on=False), [])
            self.assertEqual(len(self.miss([lines[0], skip], "implement", 2, gate_on=False)), 1)
            self.assertEqual(self.miss(["- 흐름 승인 · 2026-11-18 · 「설계 없이 진행」"], "implement", None, plain=True, gate_on=False), [])
            self.assertTrue(H.retry_open(self.scope(self.tip, ("- 걸음 건너뜀 · 2026-11-18 · 「다시 시도한다」 · 다시 시도 plan 1 시도 3",), False), 1, 3, True))
            self.assertEqual(len(self.miss(lines, "implement", 1, gate_on=True)), 2)   # 양성 대조 — 켜면 같은 줄이 지나지 못한다
```

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_human_judge.py 2>&1 | tail -3`
Expected: `AttributeError: module 'human_lines' has no attribute 'match'`(과제 5 의 테스트는 통과)

- [ ] **Step 3: 구현한다** — 위 표 셋과 `passed` · `missing` · `retry_open` 의 규칙대로.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_human_lines.py plugins/spec-distill/tests/test_human_judge.py 2>&1 | tail -3`
Expected: `OK`

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/human_lines.py plugins/spec-distill/tests/test_human_judge.py
git commit -m "feat(spec-distill): 사람 줄의 대조 판정과 관문 표를 더한다"
```

- [ ] **Step 6: 흔들어 본다(커밋한 뒤)**

`match` 의 조건을 하나씩 바꾸고 `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_human_judge.py` 가 붉어지는지 본다. 변이마다 붉어진 테스트 이름을 과제 보고에 적고, 붉어지지 않는 변이가 있으면 그 조건을 재는 테스트를 더해 다시 커밋한다. 변이 뒤에는 `git checkout HEAD -- plugins/spec-distill/scripts/human_lines.py` 와 빈 `git diff HEAD --stat` 으로 되돌림을 확인한다.

| 변이 | 종류 |
|---|---|
| `who` 검사를 지운다 | 지우기 |
| `who != HUMAN` 을 `who == HUMAN` 으로 | 뒤집기 |
| 머리 검사를 `in`(어디든 들어 있으면)으로 | 값 바꾸기 |
| 머리 뒤 16진 글자 검사를 지운다 | 지우기 |
| 라벨 비교에서 `clean_label` 을 뺀다 | 값 바꾸기 |
| 건너뜀의 관문 이름 검사를 지운다 | 지우기 |
| 같은 `key` 검사를 「세션도 같을 때만」 으로 | 값 바꾸기 |
| 꼴 판정을 먼저 하지 않는다 | 지우기 |
| `passed` 의 건너뜀 줄 비교를 `gate_name(kind, None)` 으로 | 값 바꾸기 |
| `gate_on` 이 거짓일 때의 갈래를 켜진 갈래로 | 뒤집기 |
| `RETRY_STOP` 과 무관하게 `retry_open` 이 늘 참 | 값 바꾸기 |
| `계획 검토` 줄의 머리에서 계획 번호를 뺀다(`head(과제, 판)`) | 값 바꾸기 |
| 날짜 검사를 지운다 · 하루를 이틀로 | 지우기 · 값 바꾸기 |
| `names_gate` 를 `name in text` 로 | 값 바꾸기 |
| `who` 가 `UNKNOWN` 일 때 「어긋남」 을 낸다 | 값 바꾸기 |
| `expected` 가 받음 줄을 보지 않는다 | 지우기 |

---

### Task 7: `ask-head` · `record --human` 과 옛 인자 막기(`conductor_ledger.py`)

**AC:** AC3 · AC4 · AC5 · AC6 · AC7

**Files:**
- Modify: `plugins/spec-distill/scripts/conductor_ledger.py`(`COMMANDS` · `c_record` · `c_flush` · 새 함수)
- Modify: `plugins/spec-distill/tests/fixtures/team_repo.sh`(도우미)
- Test: `plugins/spec-distill/tests/test_human_record.sh`(새로 · 100755)

**Interfaces:**
- Consumes: `human_lines`(과제 5 · 6) · `session_record`(과제 2) · `repo_defaults.gate_on`(과제 3) · 이 파일의 `_status` · `_block` · `mpath` · `cs.holder` · `team_intent` · `_append_decisions` · `write_atomic` · `team_status.read_tip`(함수 안에서 가져온다) · `roadmap_status.Git`(함수 안에서 가져온다).
- Produces (명령줄):
  - `conductor_ledger.py ask-head --human <종류> --roadmap <로드맵> --job <과제> [--plan <n>]` — 표준 출력에 머리 한 줄만 낸다(`<과제> @<판>` · `계획 검토` 는 `<과제> plan <n> @<판>`). 0 · 1 · 2 · 3
  - `conductor_ledger.py record --human <종류> --roadmap <로드맵> --job <과제> [--plan <n>] [--gate "<관문 이름>"]` — 0 적었다(또는 같은 줄이 이미 있다) · 1 · 2 · 3. 커밋은 하지 않는다. **날짜 인자가 없다**(J28)
  - `record` 의 `--spec` 은 `--human` 이 없을 때만 필요하다(없으면 2)
- Produces (`tests/fixtures/team_repo.sh` — 뒤 과제의 셸 테스트가 쓴다):

```bash
SID="00000000-0000-4000-8000-00000000c0de"          # 지휘 표지를 쥔 가짜 세션
SID2="00000000-0000-4000-8000-00000000c0df"         # 그 세션을 이어받은 가짜 세션
export CLAUDE_CONFIG_DIR="$T/claude"                  # 세션 기록 자리 — 실제 설정 폴더를 읽지 않는다
export TZ=UTC                                         # 사람 줄의 날짜는 답한 시각의 지역 날짜다 — 테스트는 UTC 로 고정한다
CL="$S/conductor_ledger.py"
SFX="$ROOT/plugins/spec-distill/tests/fixtures/session_fixture.py"
led() { (cd "$W" && python3 "$CL" "$@") > "$T/led.txt" 2>&1; echo $?; }   # 지휘 원장 명령 — rc 를 echo, 출력은 $T/led.txt
claim() { [ "$(led claim --roadmap "$RM" --session "$SID")" = "0" ]; }
answer() {  # answer <질문 글> <고른 글> [session_fixture answer 의 나머지 인자…] — 지휘 세션 기록에 질문 창 답 하나를 덧붙인다. 답 항목의 uuid 는 $T/entry.txt
  local q="$1" a="$2"; shift 2
  python3 "$SFX" answer --config "$CLAUDE_CONFIG_DIR" --session "$SID" --question "$q" --label "$a" "$@" > "$T/entry.txt"
}
human() {  # human <종류> <과제> [계획|-] [관문 이름|-] [날짜] — 머리를 받아 통과 라벨로 답한 기록을 짓고 줄을 적는다. 날짜를 주면 그날 낮 12시(UTC)에 답한 것으로 짓는다. rc 를 echo(커밋은 부르는 쪽)
  local kind="$1" job="$2" plan="${3:--}" gate="${4:--}" date="${5:-}" label head q
  case "$kind" in
    "spec 승인") label="승인 — 계획 담당자에게 (권장)" ;;
    "계획 검토") label="계획대로 구현한다" ;;
    "흐름 승인") label="설계 없이 진행" ;;
    *) case "$gate" in "다시 시도"*) label="다시 시도한다" ;; *) label="건너뛴다" ;; esac ;;
  esac
  set -- --human "$kind" --roadmap "$RM" --job "$job"
  [ "$plan" = "-" ] || set -- "$@" --plan "$plan"
  [ "$(led ask-head "$@")" = "0" ] || { echo "ask-head 실패 — $(cat "$T/led.txt")" >&2; echo 1; return; }
  head="$(cat "$T/led.txt")"
  if [ "$gate" = "-" ]; then q="${head} — 자리표시 질문"; else q="${head} — ${gate} 자리표시 질문"; set -- "$@" --gate "$gate"; fi
  if [ -n "$date" ]; then answer "$q" "$label" --when "${date}T12:00:00.000Z"; else answer "$q" "$label"; fi
  led record "$@"
}
approved() {  # approved <human 의 인자…> — 줄을 적고 그 과제의 INTENT.md 를 커밋한다
  [ "$(human "$@")" = "0" ] && g add -- "$TM/jobs/$2/INTENT.md" && g commit -qm "$1 — $2"
}
```

동작(둘 다 team 형식 로드맵에서만 — 아니면 2 `team 형식 로드맵에서만 쓴다`):

1. **인자.** `--human` 은 종류 넷 가운데 하나다. `--plan` 은 `계획 검토` 에만 주고 꼭 준다. `--gate` 는 `record` 의 `걸음 건너뜀` 에만 주고 꼭 주며, 이름 꼴(Global Constraints 의 넷)이 아니면 2 다. `record --human` 에 `--spec` · `--line` · `--approval` · `--choice` · `--date` 를 함께 주면 2 다(AC3 · J28).
2. **과제와 쓸 브랜치(J7).** `_status` 의 보고에서 과제를 찾는다 — 블록이면 `branch_states`, 로드맵 밖 과제면 보고의 `jobs` 에서 그 `branch`. 없으면 2. 쓸 브랜치가 모두 머지됐으면 1 `이미 기본 브랜치에 머지됐다`. 지금 브랜치(`git symbolic-ref --short -q HEAD`)가 쓸 브랜치가 아니면 1 `이 worktree 는 <지금 브랜치 또는 「브랜치 없는 HEAD」> 다 — <쓸 브랜치> 를 체크아웃한 worktree 에서 부른다`.
3. **커밋돼 있는가.** 묶일 파일(`human_lines.bound_name`)이 `HEAD` 에 없으면 1 `<파일> 이 커밋돼 있지 않다`. 작업 폴더의 글과 `HEAD` 의 글의 **본문**이 다르면 1 `<파일> 의 본문에 커밋되지 않은 변경이 있다 — 커밋한 뒤 다시 묻는다`. 기록 절만 다른 것은 지난다.
4. **머리.** `human_lines.head(과제, human_lines.version(git, "HEAD", 경로), 계획)` — 계획 번호는 `계획 검토` 일 때만 준다. `ask-head` 는 여기서 머리를 내고 끝난다.
5. **세션 기록(`record` 만).** 표지의 세션(`cs.holder(mpath(root, roadmap).parent)`)이 없으면 3 `확인 못 함 — 이 로드맵의 지휘 표지가 없다(먼저 claim)`. `session_record.locate` · `answers` 가 `Unreadable` 이면 3 `확인 못 함 — <사유>`. 3 의 글 끝에는 늘 ` — 세션 기록의 꼴이 바뀐 것이면 레포 설정 human_gate: 끔 으로 연다` 를 붙인다(AC6).
6. **답 고르기.** 그 과제의 줄을 모은다 — 쓸 브랜치를 뺀 그 과제의 브랜치 끝들(`team_status.read_tip`) · 기본 브랜치 · `HEAD` 를 `human_lines.collect` 로 읽고, 작업 폴더 INTENT.md 의 결정 기록 줄을 더한다. 기록의 답을 **뒤에서부터** 보아 다음을 모두 채우는 첫 답을 고른다 — 질문 글이 머리로 시작한다(`starts_with_head`) · 건너뜀이면 `names_gate(질문 글, --gate 의 이름)` 이 참이다 · `who` 가 `NOT_HUMAN` 이 아니다 · 그 답의 `key` 를 근거로 쓴 줄이 모은 줄에 없다(쓰려는 줄과 글자가 같은 줄은 빼고 본다 — 세션이 달라도 `key` 가 같으면 쓴 것이다). 고른 답의 `who` 가 `UNKNOWN` 이면 3 `확인 못 함 — <답의 why>`(5 의 꼬리를 붙인다). 고른 답이 없으면 1 `쓰지 않았다 — 머리 <머리> 로 시작하는 질문 창 답이 지휘 세션 기록에 없다`.
7. **라벨.** `clean_label(고른 글)` 이 그 종류의 통과 라벨이 아니면(건너뜀은 관문 이름과 짝인 라벨이 아니면) 1 `쓰지 않았다 — 사람이 고른 라벨: 「<고른 글>」`. 더 앞의 답을 찾지 않는다.
8. **쓰기.** 날짜는 `session_record.day(답의 when, local=True)` 다(J28). `human_lines.render(…)` 의 줄을 작업 폴더 INTENT.md 의 결정 기록에 덧붙인다(`_append_decisions` · `write_atomic`). 같은 줄이 이미 있으면 `이미 있어 쓰지 않았다 — …` 0, 썼으면 `적었다(커밋은 리더가) — <INTENT.md> 의 결정 기록: <줄>` 0.

**옛 인자 막기(AC3).** `record --spec … --approval` · `--line` 과 `flush` 가 team 형식 과제의 INTENT.md 에 쓰려는 줄 가운데 `human_lines.is_human(줄)` 이 참인 것이 있고 `human_gate` 가 켜져 있으면 아무것도 쓰지 않고 2 `사람 줄(<종류>)은 record --human 으로만 적는다 — 고른 글을 인자로 받지 않는다`(`flush` 는 쌓인 줄도 그대로 둔다). `human_gate` 가 꺼져 있으면 지금처럼 적는다. 옛 형식 문서에는 지금과 똑같이 적는다. 막는 자리는 `_append_decisions` 한 곳이다(`record` · `flush` 가 함께 지난다).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_human_record.sh`(머리 · `team_repo` · `finish` 는 `tests/test_start_bundle.sh` 와 같다). 준비:

```bash
team_repo && claim && ok "팀 레포와 지휘 표지" || { no "준비 실패 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; }
E1="$TM/jobs/E1"
intent_tail() { tail -n 1 "$W/$E1/INTENT.md"; }
intent_lines() { wc -l < "$W/$E1/INTENT.md" | tr -d ' '; }
rec() { led record --human "spec 승인" --roadmap "$RM" --job E1; }
PASSL="승인 — 계획 담당자에게"
g checkout -q -b feature/tm-e1 main
put "$E1/design.md" "$(printf '# 설계\n\n본문 하나\n\n## 지휘 기록\n')" && g commit -qm "E1 설계"; C1="$(g rev-parse HEAD)"
HEAD1="E1 @$(printf '%s' "$C1" | cut -c1-8)"
```

표의 차례가 뜻이 있다 — 기록은 뒤에서부터 읽으므로 뒤에 덧붙인 답이 앞의 답을 가린다.

| # | 준비 | 명령 | 기대 |
|---|---|---|---|
| 1 | — | `led ask-head --human "spec 승인" --roadmap "$RM" --job E1` | rc 0 · 출력이 정확히 `$HEAD1`(AC4) |
| 2 | 답이 없다 | `rec` | rc 1 · 출력에 `$HEAD1` · INTENT.md 가 그대로(`g status --short -- "$TM"` 빔) |
| 3 | `answer " $HEAD1 — 질문" "$PASSL"` 와 `answer "**$HEAD1** 질문" "$PASSL"` | `rec` | rc 1 · 출력에 `$HEAD1`(머리 앞에 글자가 붙은 답은 고르지 않고 기다린 머리를 보인다 — Review Focus 3) |
| 4 | `python3 "$SFX" text … --name <이름> --text "$HEAD1 — 질문 「$PASSL」"` 을 `peer` · `notification` · `typed` 로 한 번씩 | `rec` | rc 1 · 출력에 `$HEAD1`(AC5 — 다른 세션이 보낸 글 · 알림 · 사람이 친 말에 머리와 라벨 글자가 있어도 답이 아니다) |
| 5 | `answer "$HEAD1 — 질문" "$PASSL" --subagent` 와 `answer "$HEAD1 — 질문" "$PASSL" --sidechain` | `rec` | rc 1 · 출력에 `$HEAD1`(AC5 — 하위 agent 의 기록 · 곁가지 항목) |
| 6 | `answer "E3 @<C1 8자> — 질문" "$PASSL"`(다른 과제 번호) 와 `answer "E1 @0123abcd — 질문" "$PASSL"`(번호는 같고 판이 다르다 — 번호가 같은 다른 과제의 파일) | `rec` | rc 1 · 출력에 `$HEAD1`(AC5) |
| 7 | 한 호출에 질문 둘 — `answer "$HEAD1 — 설계를 승인할까요" "수정 필요" --question "다음 에픽도 함께 시작할까요" --label "$PASSL"` | `rec` | rc 1 · 출력에 `사람이 고른 라벨: 「수정 필요」`(AC5 — 같은 호출의 다른 질문에서 고른 라벨로는 쓰지 않는다) · 그대로 |
| 8 | `answer "$HEAD1 — 질문" "$PASSL" --who denied` | `rec` | rc 1 · 출력에 `「수정 필요」`(수락이 아닌 답은 지나가고 7 의 답이 고른 답이다) |
| 9 | 꼴이 달라진 답을 하나씩 덧붙이며 다섯 번 — `--who unknown` · `--who other` · `--drop answers` · `--drop sourceToolAssistantUUID` · `--drop isSidechain`(질문은 `"$HEAD1 — 질문"`, 고른 글은 `"$PASSL"`) | 덧붙일 때마다 `rec` | 다섯 번 모두 rc 3 · 출력에 `확인 못 함` 과 `human_gate: 끔` · 그대로(AC6 — 조용히 1 이 되지 않는다) |
| 10 | 기록 파일을 읽지 못하게 한다(`chmod 000` — 그래도 읽히면(root) 이 줄은 건너뛰고 그렇다고 적는다) | `rec` | rc 3 · 출력에 `확인 못 함`(AC6 — 읽지 못함). 그 뒤 `chmod 644` |
| 11 | `answer "$HEAD1 — 질문" "$PASSL (권장)" --when 2026-11-20T12:00:00.000Z`(uuid 를 `U1` 로) | `rec` | rc 0 · `intent_tail` 이 `- spec 승인 · 2026-11-20 · 「승인 — 계획 담당자에게」 · design.md@<C1 8자> · 근거 ${SID}:${U1}#1`(날짜는 답한 시각에서 온다 — J28) · 커밋은 되지 않았다(`g status --short -- "$TM"` 에 INTENT.md) |
| 12 | — | `rec` 을 한 번 더 | rc 0 · 출력에 `이미 있어 쓰지 않았다` · `intent_lines` 그대로 |
| 13 | — | `led record --human "spec 승인" --roadmap "$RM" --job E1 --date 2026-11-25` | rc 2 · 그대로(날짜 인자는 없다) |
| 14 | 11 의 줄을 커밋한다. 표지를 `SID2` 로 넘기고(`led takeover --roadmap "$RM" --session "$SID2"`) `SID2` 의 기록에 같은 답을 복사한다(`python3 "$SFX" answer --config "$CLAUDE_CONFIG_DIR" --session "$SID2" --question "$HEAD1 — 질문" --label "$PASSL" --entry "$U1" --when 2026-11-20T12:00:00.000Z`) | `rec` | rc 1 · `intent_lines` 그대로(같은 답은 세션이 달라도 한 번만 근거가 된다 — J3) |
| 15 | `design.md` 의 본문을 고치고 커밋하지 않는다 | `ask-head` · `rec` | 둘 다 rc 1 · 출력에 `커밋되지 않은 변경`(AC4) |
| 16 | 15 를 되돌리고 `## 지휘 기록` 아래에만 한 줄 더하고 커밋하지 않는다 | `ask-head` | rc 0 · `$HEAD1`(본문만 견준다). 그 뒤 되돌린다 |
| 17 | `g checkout -q main` | `ask-head` | rc 1 · 출력에 `feature/tm-e1` |
| 18 | `g checkout -q --detach feature/tm-e1` | `ask-head` | rc 1 · 출력에 `feature/tm-e1`(Review Focus 5). 그 뒤 `g checkout -q feature/tm-e1` |
| 19 | `plan-1.md` 와 `plan-2.md` 를 **한 커밋**으로 넣는다(`C2`) | `led ask-head --human "계획 검토" --roadmap "$RM" --job E1 --plan 1` | rc 0 · 출력이 정확히 `E1 plan 1 @<C2 8자>`(AC4) |
| 20 | 계획 1 의 답을 이어받기 전 세션 `SID` 의 기록에만 넣는다 — `answer "E1 plan 1 @<C2 8자> — 질문" "계획대로 구현한다" --when 2026-11-21T12:00:00.000Z`(uuid 를 `U2` 로). 표지는 14 에서 `SID2` 다 | `led record --human "계획 검토" --roadmap "$RM" --job E1 --plan 1` | rc 1(새 세션 `SID2` 의 기록에는 그 답이 없다 — 다시 묻는다) |
| 21 | `SID2` 의 기록에 그 답을 복사한다(`--entry "$U2"` · 같은 질문 · 같은 시각) | 위와 같다 | rc 0 · 줄이 `- 계획 검토 · 2026-11-21 · 「계획대로 구현한다」 · plan-1.md@<C2 8자> · 근거 ${SID2}:${U2}#1`(이어받은 세션은 앞 답을 적을 수 있다 — J3). 커밋한다 |
| 22 | `feature/tm-e1b` 를 지금 끝에서 만든다(계획 2 의 브랜치 · `plan-2.md` 의 판도 `C2` 다) | `led ask-head --human "계획 검토" … --plan 2` · `led record --human "계획 검토" … --plan 2` | 머리가 `E1 plan 2 @<C2 8자>` · record 는 rc 1(판이 같아도 계획 1 의 답으로 계획 2 줄을 쓰지 못한다 — AC5 다른 계획). 그 뒤 `g checkout -q feature/tm-e1` |
| 23 | — | `human "걸음 건너뜀" E1 - "계획 검토 plan 1" 2026-11-22`(`answer` 가 `SID` 에 쓰므로 먼저 `led takeover … --session "$SID"`) | `0` · 줄이 `- 걸음 건너뜀 · 2026-11-22 · 「건너뛴다」 · 계획 검토 plan 1 · INTENT.md@<8자> · 근거 …` |
| 24 | 건너뜀 머리로 시작하되 관문 이름이 없는 답, 그리고 `계획 검토 plan 12` 만 이름 붙인 답 | `led record --human "걸음 건너뜀" … --gate "spec 승인"` · `… --gate "계획 검토 plan 1"` | 둘 다 rc 1 · `intent_lines` 그대로(이름을 부분 글자로 찾지 않는다 — `plan 12` 를 이름 붙인 답은 `plan 1` 의 답이 아니고, 23 의 답은 이미 근거다) |
| 25 | 건너뜀 머리 + `다시 시도 plan 1 시도 3` 이 든 질문에 「건너뛴다」 로 답 | `… --gate "다시 시도 plan 1 시도 3"` | rc 1 · 출력에 `사람이 고른 라벨: 「건너뛴다」` |
| 26 | `g checkout -q -b feature/tm-e2 main`(설계 없는 흐름의 블록) | `human "흐름 승인" E2 - - 2026-11-22` | `0` · 줄에 `INTENT.md@` |
| 27 | 사용법 | `record --human "spec 승인" … --choice x` · `… --line x` · `… --approval` · `… --spec x` · `--human "결정"` · `--human "계획 검토"`(`--plan` 없음) · `--human "spec 승인" --plan 1` · `--human "걸음 건너뜀"`(`--gate` 없음) · `--gate "아무 관문"` · `--gate "다시 시도 시도 3"` · `record`(`--spec` 도 `--human` 도 없음) | 모두 rc 2 · INTENT.md 그대로 |
| 28 | `feature/tm-e1` 에서 | `led record --spec "$W/$E1/design.md" --approval --date 2026-11-23 --choice "이대로"` · `led record --spec "$W/$E1/design.md" --line "계획 검토 · 2026-11-23 · 「글」"` | 둘 다 rc 2 · 출력에 `record --human` · 그대로(AC3) |
| 29 | — | `led record --spec "$W/$E1/design.md" --line "결정 · 2026-11-23 · 「글」"` | rc 0(사람 줄 종류가 아닌 줄은 지금처럼) |
| 30 | 쌓인 기록에 E1 의 줄 둘을 쌓는다 — `흐름 승인 · 2026-11-23 · 「글」` 과 `결정 · 2026-11-23 · 「쌓인 결정」`(`tests/test_conductor_ledger.py` 의 flush 테스트가 쌓는 방식 그대로) | `led flush --roadmap "$RM" --session "$SID" --epic E1 --spec "$W/$E1/design.md"` | rc 2 · 출력에 `record --human` · INTENT.md 그대로 · `led pending --roadmap "$RM" --epic E1` 에 두 줄이 그대로 있다(AC3 · AC7 — 사람 줄은 쌓아 옮기지 못한다) |
| 31 | 쌓인 `흐름 승인` 줄만 지운다(`led drop …`) | 위 flush | rc 0 · `쌓인 결정` 줄이 INTENT.md 에 옮겨졌다(양성 대조) |
| 32 | 표지를 푼다(`led release …`) | `led record --human "계획 검토" … --plan 1` | rc 3 · 출력에 `확인 못 함`. 그 뒤 `claim` |
| 33 | `CLAUDE_CONFIG_DIR` 를 빈 폴더로 | 위와 같다 | rc 3 · 출력에 `확인 못 함` 과 `human_gate: 끔` |
| 34 | 기본 브랜치의 `.devbrew.md` 에 `human_gate: 끔` 을 올린다(`publish`) | 28 의 두 명령 · 30 의 쌓기와 flush | 모두 rc 0 · 줄이 적혔다(AC20). 그 뒤 설정을 되돌려 올리고 28 이 다시 rc 2 인지 본다(양성 대조) |

표의 줄마다 `assert_eq` · `assert_contains` 로 쓴다. 이름은 `AC<n>: <무엇>` 으로 시작한다(1 · 15 · 16 · 19 = AC4, 2 – 8 · 11 – 14 · 20 – 26 = AC5 · AC7, 27 – 31 · 34 = AC3, 9 · 10 · 32 · 33 = AC6). `U1` · `U2` 는 `answer` 뒤의 `$(cat "$T/entry.txt")` 다.
- [ ] **Step 2: 돌려서 실패를 본다**

Run: `chmod +x plugins/spec-distill/tests/test_human_record.sh && bash plugins/spec-distill/tests/test_human_record.sh | grep -c '✗'`
Expected: 0 보다 크다 — `ask-head` 가 없는 명령이라 argparse 가 2 를 낸다. `claim` 은 통과한다.

- [ ] **Step 3: 구현한다** — 위 동작 여덟과 옛 인자 막기대로. 새 함수는 `c_ask_head` · `c_record_human`(`c_record` 가 `a.human` 이면 넘긴다) 과 둘이 함께 쓰는 `_human_target(root, a) -> (team, job, kind, plan, 경로, 머리, git)` 이다.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `bash plugins/spec-distill/tests/test_human_record.sh | tail -1; python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py 2>&1 | tail -3; git ls-files -s plugins/spec-distill/tests/test_human_record.sh | cut -c1-6`
Expected: 요약 줄에 실패 0 · `OK` · `100755`(커밋 전이면 `git add` 뒤에 본다). `test_conductor_ledger.py` 의 `team_tree` 클래스에서 `--approval` 로 승인 줄을 적던 테스트가 붉으면 그 테스트의 뜻(줄이 과제 파일로 간다)을 `--line "결정 · …"` 으로 재도록 고치고, 승인 줄을 적는 team 테스트는 2 를 기대하게 고친다. 옛 형식 클래스는 고치지 않는다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/conductor_ledger.py plugins/spec-distill/tests/fixtures/team_repo.sh plugins/spec-distill/tests/test_human_record.sh plugins/spec-distill/tests/test_conductor_ledger.py
git commit -m "feat(spec-distill): 사람 줄을 세션 기록의 답에서만 적는 record --human 과 ask-head 를 더한다"
```

---

### Task 8: 단계 계산이 꼴 판정을 지난 승인 줄만 센다(`team_status.py`)

**AC:** AC8 · AC12(단계 계산) · AC20(알림)

**Files:**
- Modify: `plugins/spec-distill/scripts/team_status.py`(`Reader`)
- Modify: `plugins/spec-distill/scripts/control_plane.py`(`CODE_STAMP_FILES` 한 줄 — 설계 §8 의 예외)
- Test: `plugins/spec-distill/tests/test_team_status.sh` 와, 손으로 적은 승인 줄로 team 형식의 단계를 넘기던 셸 테스트 · `plugins/spec-distill/tests/test_control_plane.py`(`CodeStampClosure`)

**Interfaces:**
- Consumes: `human_lines.passed` · `collect` · `Scope` · `KIND_SPEC` · `GATE_OFF` · `NO_LINE`(과제 6) · `repo_defaults.resolve` · `gate_on`(과제 3) · 과제 7 의 `human` · `approved` 도우미(테스트).
- Produces (`team_status.Reader`):
  - `gate_on() -> bool` — 처음 불릴 때 `repo_defaults.resolve(self.git.cwd)` 를 읽어 둔다. 읽지 못하면(`SettingsError` · 오류 목록) 참(J19)
  - `job_tips(branches: list) -> list` — 이름마다 `read_tip` 이 고른 끝(끝이 없거나 갈라진 브랜치는 뺀다) 뒤에 기본 브랜치 커밋(`self.main`), 겹침 없이
  - `scope(tip, job, branches) -> human_lines.Scope` — `lines` 는 `collect(git, team, job, [tip] + job_tips(branches))` 의 줄
  - `progress()` 의 설계 흐름 갈래: 승인 날짜는 `human_lines.passed(scope, KIND_SPEC, None, deep=False)` 에서 받는다

`progress()` 의 바뀌는 곳(단계를 세는 규칙은 설계 흐름만 바뀐다 — 설계 없는 흐름의 단계는 그대로다, J16):

- **꺼짐 알림(J10).** `progress()` 의 첫머리에서 — 흐름을 가르기 전에 — `self.gate_on()` 이 거짓이면 `block["notes"]` 맨 앞에 `human_lines.GATE_OFF` 를 넣는다(이미 있으면 넣지 않는다). `progress()` 는 도는 과제(설계 흐름의 블록 · 설계 없는 흐름의 블록 · 로드맵 밖 과제)마다 불리므로 셋 모두에 실리고, 도는 과제가 없으면 실리지 않는다.

- 지금의 `self._approval(intent)` 는 그대로 먼저 부른다 — `FormatError` 사유(`결정 기록 읽기 불가 — …`)의 갈래를 지킨다.
- 그 뒤 `scope = self.scope(tip, job, block.get("branches") or [])` 로 `passed` 를 부른다. 지났으면 `block["approved"]` 는 그 날짜이고 뒤의 갈래는 지금과 같다 — 다만 건너뜀 줄로 지났으면 근거의 앞머리가 `spec 승인됨(<날짜>)` 대신 `spec 승인 건너뜀(<날짜>)` 이다.
- 지나지 못했으면 「설계 중」 이다. 사유가 `NO_LINE` 이면 근거는 지금 글자 그대로, 아니면 `design.md 있음 · spec 승인 줄이 지나지 못했다 — <사유>`(J15).

`control_plane.py` 는 한 줄만 고친다 — `CODE_STAMP_FILES` 튜플 끝에 `"human_lines.py", "session_record.py"` 를 더한다(상태 계산이 가져오는 모듈이 바뀌면 현황 캐시가 옛 결과를 내지 않게 — `tests/test_control_plane.py` 의 `CodeStampClosure` 가 도출해 잰다). 그 파일의 다른 줄은 건드리지 않는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_team_status.sh` 의 「승인」 걸음(지금 `decide E1 "spec 승인 · 2026-11-20 · 「이대로 승인 (권장)」"`)을 아래로 바꾼다. 파일 앞의 준비에 `claim` 을 더한다.

```bash
decide E1 "spec 승인 · 2026-11-20 · 「이대로 승인 (권장)」" && step "손으로 적은 승인 줄" || fail_step "손으로 적은 승인 줄"
assert_eq "$(st E1)" "설계 중" "AC8: 손으로 적은 승인 줄로는 계획이 되지 않는다"
assert_contains "$(why E1)" "design.md 있음 · spec 승인 줄이 지나지 못했다 — 근거 없음" "AC8: 사유에 판정"
[ "$(human "spec 승인" E1 - - 2026-11-20)" = "0" ] && step "승인" || fail_step "승인"
assert_eq "$(st E1) · $(why E1)" "계획 · spec 승인됨(2026-11-20) · plan-1.md 없음 · implement 결과 파일 없음" "단계: 승인 줄 — 계획"
mv "$CLAUDE_CONFIG_DIR" "$T/claude.away" && restat
assert_eq "$(st E1)" "계획" "AC8: 단계 계산은 세션 기록을 읽지 않는다"
mv "$T/claude.away" "$CLAUDE_CONFIG_DIR"
```

(`step` · `fail_step` · `st` · `why` · `restat` 는 그 파일에 있는 도우미다. `step` 이 `g add -A` · 커밋 · push · 다시 계산을 하므로 여기서는 커밋까지 하는 `approved` 대신 `human` 을 쓴다.) 그 파일 끝(`finish` 앞)에 새 레포로 더한다:

| # | 준비(브랜치 `feature/tm-e3` · 설계 커밋 · `approved "spec 승인" E3 - - 2026-11-25`) | 기대 |
|---|---|---|
| a | 승인 뒤 `design.md` 의 `## 미룸` · `## 지휘 기록` 절만 고쳐 커밋 | 「계획」 그대로(`AC8: 기록 절 · 미룸 절은 승인을 낡게 하지 않는다`) |
| b | 승인 뒤 본문을 고쳐 커밋 | 「설계 중」 · 사유에 `낡음` |
| c | b 뒤 `approved "걸음 건너뜀" E3 - "spec 승인" 2026-11-26` | 「계획」 · 사유가 `spec 승인 건너뜀(2026-11-26)` 로 시작(`AC12`) |
| d | c 의 건너뜀 줄 없이, 기본 브랜치의 `.devbrew.md` 에 `human_gate: 끔` 을 올리고 손으로 `decide E3 "spec 승인 · 2026-11-27 · 「글」"` | 「계획」 · 그 블록 `notes` 의 첫 줄이 `사람 줄 대조가 꺼져 있다`(`AC20`) |
| e | d 의 상태(꺼짐)에서 설계 없는 흐름의 블록 E2 의 브랜치(`feature/tm-e2`)와 로드맵 밖 과제 하나(`roadmap_write.py job new` — `tests/test_start_bundle.sh` 의 「끝에서 끝」 이 만드는 방식)를 만들어 올린다 | E2 블록 `notes` 의 첫 줄 · 그 로드맵 밖 과제(`r['jobs']`) `notes` 의 첫 줄이 모두 `사람 줄 대조가 꺼져 있다`(`AC20: 도는 과제마다 첫 알림 줄 — 설계 없는 흐름 · 로드맵 밖 과제`) |
| f | 〃 | 브랜치가 없는 블록(「준비」)의 `notes` 에는 그 줄이 없다(도는 과제가 아니다) |
| g | 설정을 되돌려 올린다 | E3 는 「설계 중」 · E3 · E2 · 로드맵 밖 과제의 `notes` 어디에도 그 줄이 없다(양성 대조) |

`tests/test_control_plane.py` 의 `CodeStampClosure.test_every_module_the_status_computation_loads_is_stamped` — 양성 대조 목록(`for name in ("team_status.py", …)`)에 `"human_lines.py"` · `"session_record.py"` 를 더한다(도출이 새 모듈에 닿는지 잰다).

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_team_status.sh | grep -E '✗' | head`
Expected: `AC8: 손으로 적은 승인 줄로는 계획이 되지 않는다` 와 새 줄들이 ✗. `python3 -m unittest plugins/spec-distill/tests/test_control_plane.py` 는 `CodeStampClosure` 의 양성 대조(`human_lines.py` 가 도출에 없다)로 FAIL

- [ ] **Step 3: 구현한다** — 위 Produces 와 바뀌는 곳대로, 그리고 `control_plane.py` 의 그 한 줄. `roadmap_status.py` 는 고치지 않는다. `team_status.py` 가 새로 가져오는 로컬 모듈은 `human_lines` · `repo_defaults` 둘뿐이다(둘 다 상태 계산의 잠금 목록 안이다 — 과제 5 Step 5).

- [ ] **Step 4: 기존 테스트를 관문 아래로 옮긴다**

Run:
```bash
for t in test_team_status test_team_status_stub test_team_stale test_team_coverage test_team_tasks test_team_review_entry test_team_write test_team_sync test_team_rules test_start_bundle test_job_results test_roadmap_status; do
  printf '%s: ' "$t"; bash plugins/spec-distill/tests/$t.sh | tail -1
done
python3 -m unittest plugins/spec-distill/tests/test_control_plane.py plugins/spec-distill/tests/test_team_docs.py 2>&1 | tail -3
```
Expected: 모두 실패 0 · `OK`. 붉은 단언은 아래 규칙으로만 고친다 — 단언을 지우거나 기대를 느슨하게 하지 않는다.

- team 형식 레포에서 `decide <과제> "spec 승인 · <날짜> · 「…」"` 로 단계를 「계획」 뒤로 넘기던 걸음 → 그 자리에서 `approved "spec 승인" <과제> - - <날짜>` 로 바꾼다(그 브랜치를 체크아웃한 채, 설계 파일이 커밋된 뒤에). 파일 앞 준비에 `claim` 을 더한다.
- 승인 줄의 **글자 자체**를 재는 걸음(꼴이 깨진 승인 줄 `spec 승인 · 11/20 · …` 의 「결정 기록 읽기 불가」 · 기본 브랜치에 승인만 있는 블록의 시작 흔적)은 그대로 둔다 — 그 갈래는 바뀌지 않는다.
- 옛 형식 로드맵을 쓰는 걸음(`## 지휘 기록` 의 승인 줄)은 고치지 않는다. 붉으면 멈춰 보고한다(AC21). `tests/test_roadmap_status.sh` 에서 이 계획이 고치는 것은 과제 5 Step 5 의 세 곳(정적 검사 목록 · 수 단언 · 변이 사본 목록)뿐이다 — 정적 검사가 `team_status.py` 의 새 import 나 호출을 짚으면 목록을 넓히지 않고 코드를 규칙에 맞춘다(Global Constraints 「상태 계산의 잠금 목록」).

고친 걸음마다 파일 · 줄 · 무엇을 무엇으로 바꿨는지를 과제 보고에 적는다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/team_status.py plugins/spec-distill/scripts/control_plane.py plugins/spec-distill/tests
git commit -m "feat(spec-distill): 단계 계산이 근거 있는 승인 줄만 세고 건너뜀 줄과 꺼짐을 알린다"
```

(`git add plugins/spec-distill/tests` 앞에 `git status --short plugins/spec-distill/tests` 로 이 과제가 고친 파일만 있는지 본다.)

---

### Task 9: 시작 묶음의 관문 확인(`start_bundle.py`)

**AC:** AC9 · AC12(시작 묶음) · AC20(알림)

**Files:**
- Modify: `plugins/spec-distill/scripts/start_bundle.py`(`_job_bundle`)
- Test: `plugins/spec-distill/tests/test_human_gate.sh`(새로 · 100755) · `tests/test_start_bundle.sh` · `tests/test_team_sync.sh`

**Interfaces:**
- Consumes: `human_lines.missing` · `Scope` · `GATE_OFF`(과제 6) · `Reader.scope` · `Reader.gate_on`(과제 8) · 과제 7 의 도우미.
- Produces: `start_bundle.locate(git, base, blocks, job, plan) -> tuple` 이 다섯째 값으로 그 과제의 브랜치 이름들(블록은 `브랜치:` 칸 전부 · 로드맵 밖 과제는 그 과제의 브랜치 하나)을 돌려준다. `start_bundle.py --job … --stage …` 는 묶음을 만들기 전에 `human_lines.missing(scope, stage, a.plan, plain, deep=True)` 를 부르고, 사유가 있으면 `Refused(첫 사유)` 다 — 종료 코드 1 · 표준 출력 빔 · 표준 오류 `[spec-distill] 멈춤 — <사유>` 한 줄(J18). `scope` 의 `tip` 은 그 묶음이 읽는 과제 브랜치 커밋이고, 줄은 블록의 브랜치 전부(로드맵 밖 과제는 그 과제의 브랜치)와 기본 브랜치에서 모은다. `human_gate` 가 꺼져 있으면 알림 목록 맨 앞에 `human_lines.GATE_OFF` 를 넣는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_human_gate.sh`. 준비: `team_repo` · `claim` · 공통 문서(역할 문서 넷 · `HANDBOOK.md`)를 `tests/test_start_bundle.sh` 처럼 기본 브랜치에 올린다. `bundle() { (cd "$W" && python3 "$S/start_bundle.py" --roadmap "$RM" "$@") > "$T/b.txt" 2> "$T/b.err"; echo $?; }` · `refused() { [ "$(bundle "$@")" = "1" ] && [ ! -s "$T/b.txt" ]; }`. `feature/tm-e1` 에 설계 파일을 커밋해 올린다(`jpush`).

| # | 준비 | 명령 | 기대 |
|---|---|---|---|
| 1 | 승인 줄 없음 | `bundle --job E1 --stage design` | `0`(design 은 관문이 없다) |
| 2 | 〃 | `bundle --job E1 --stage plan --plan 1` | `1` · 표준 출력 빔 · 표준 오류가 한 줄이고 `멈춤 — ` · `` `spec 승인` 줄이 없다 `` · `record --human` 이 있다 |
| 3 | 손으로 `decide E1 "spec 승인 · 2026-11-20 · 「승인 — 계획 담당자에게」"` 를 커밋해 올린다 | 위와 같다 | `1` · 표준 오류에 `근거 없음` |
| 4 | `human "spec 승인" E1 - - 2026-11-20` 으로 줄을 작업 폴더에만 적는다(커밋하지 않는다) | 위와 같다 | `1` — 관문은 커밋된 끝만 읽는다 |
| 5 | 4 의 줄을 커밋해 올린다 | 위와 같다 | `0` · 묶음 첫 줄이 `기준 커밋: ` 으로 시작(양성 대조) |
| 6 | `plan-1.md` 를 커밋해 올린다 | `bundle --job E1 --stage implement --plan 1` | `1` · 표준 오류에 `` `계획 검토` 줄 `` 과 `계획 1` |
| 7 | `approved "계획 검토" E1 1 - 2026-11-21` 뒤 올린다 | 위와 같다 · `--stage review --plan 1` | 둘 다 `0` |
| 8 | 세션 기록 폴더를 치운다(`mv`) | `bundle --job E1 --stage implement --plan 1` | `1` · 표준 오류에 `확인 못 함` 과 `다시 승인받는다`. 그 뒤 되돌린다 |
| 9 | 승인 뒤 `design.md` 본문을 고쳐 커밋해 올린다 | 위와 같다 | `1` · 표준 오류에 `낡음` |
| 10 | 9 를 `git revert` 로 되돌려 올린다(본문이 승인한 판과 같아진다) | 위와 같다 | `0` |
| 11 | 승인 뒤 `design.md` 의 `## 미룸` 절만 고쳐 커밋해 올린다 | 위와 같다 | `0` |
| 12 | `feature/tm-e1b`(블록의 둘째 브랜치)를 `feature/tm-e1` 의 **승인 줄을 적기 전 커밋**에서 만들어 `plan-2.md` 를 커밋해 올린다 | `bundle --job E1 --stage plan --plan 2` | `0` — 승인 줄이 `feature/tm-e1` 끝에만 있어도 모아 읽는다(AC9) |
| 13 | 〃 | `bundle --job E1 --stage implement --plan 2` | `1` · `계획 2`(계획 1 의 확인 줄은 계획 2 를 열지 않는다) |
| 14 | `feature/tm-e1b` 에서 `approved "걸음 건너뜀" E1 - "계획 검토 plan 2" 2026-11-22` 뒤 올린다 | 위와 같다 · `--stage implement --plan 1` 도 | 계획 2 는 `0`(AC12). 계획 1 은 7 의 줄로 `0` 그대로 |
| 14b | `feature/tm-e1b` 에 `feature/tm-e1` 을 합쳐 올린다(`g merge`) — 이제 `spec 승인` 줄과 계획 1 의 `계획 검토` 줄이 두 브랜치 끝의 INTENT.md 에 글자 그대로 함께 있다 | `bundle --job E1 --stage plan --plan 2` · `bundle --job E1 --stage implement --plan 2` · `bundle --job E1 --stage implement --plan 1` | 셋 다 `0` — 같은 줄이 여러 끝에 있는 것은 한 줄로 세고 「같은 답을 근거로 쓴 줄이 또 있다」 로 걸리지 않는다(AC9 · Verification Plan) |
| 15 | `feature/tm-e2`(설계 없는 흐름)에 과제 폴더가 있다 | `bundle --job E2 --stage implement` | `1` · 표준 오류에 `` `흐름 승인` 줄이 없다 `` |
| 16 | `approved "흐름 승인" E2 - - 2026-11-22` 뒤 올린다 | 위와 같다 | `0` |
| 17 | 기본 브랜치의 `.devbrew.md` 에 `human_gate: 끔` 을 올린다. 3 의 손으로 적은 줄만 있는 새 과제 브랜치(`feature/tm-e3` · 설계 커밋 · `decide`) | `bundle --job E3 --stage plan --plan 1` | `0` · 묶음 둘째 줄이 `알림: 사람 줄 대조가 꺼져 있다`(AC20) |
| 18 | 설정을 되돌려 올린다 | 위와 같다 | `1`(양성 대조) |
| 19 | 걸음표 · 설정으로 관문이 바뀌지 않는다 | `.devbrew.md` 에 `human_gate: 켬` 과 함께 아는 다른 키만 둔 채 2 를 다시 | `1` — 관문을 끄는 길은 `human_gate: 끔` 하나다 |

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `chmod +x plugins/spec-distill/tests/test_human_gate.sh && bash plugins/spec-distill/tests/test_human_gate.sh | grep -E '✗' | head -5`
Expected: 2 · 3 · 4 · 6 · 8 · 9 · 13 · 15 · 18 의 줄이 ✗(지금은 묶음이 나간다)

- [ ] **Step 3: 구현한다**

`_job_bundle` 에서 INTENT.md 를 읽은 바로 뒤, 묶음 글을 짓기 전에 관문을 본다. 줄을 모을 브랜치는 `locate` 의 다섯째 값이다.

- [ ] **Step 4: 기존 테스트를 관문 아래로 옮긴다**

Run: `for t in test_human_gate test_start_bundle test_team_sync test_team_status; do printf '%s: ' "$t"; bash plugins/spec-distill/tests/$t.sh | tail -1; done`
Expected: 모두 실패 0. `tests/test_start_bundle.sh` 에서 `plan` · `implement` · `review` 묶음을 받던 걸음과 끝의 「끝에서 끝」 절은 묶음을 달라기 전에 그 과제에 필요한 줄을 `approved` 로 적어 올린다(`spec 승인` → 설계 파일이 커밋된 뒤 · `계획 검토` → 그 계획 파일이 커밋된 뒤 · 설계 없는 흐름 → `흐름 승인`). 설계 파일이나 계획 파일이 없어서 줄을 적을 수 없는 걸음(파일 없이 묶음의 꼴만 재던 걸음)은 그 파일을 먼저 커밋한다 — 그 때문에 묶음의 `읽을 것` 줄 기대가 달라지면 새 값으로 고치고 과제 보고에 적는다. 사용법 오류(2)를 재는 걸음은 관문보다 앞이라 그대로다. 단언을 지우지 않는다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/start_bundle.py plugins/spec-distill/tests/test_human_gate.sh plugins/spec-distill/tests/test_start_bundle.sh plugins/spec-distill/tests/test_team_sync.sh
git commit -m "feat(spec-distill): 시작 묶음이 사람 줄을 대조하고 지나지 못하면 묶음을 내지 않는다"
```

---

### Task 10: 머지된 계획 · 연속 실패 멈춤 · 그대로 돌리는 「맞추는 명령」

**AC:** AC13 · AC14 · AC16(계획 1 몫)

**Files:**
- Modify: `plugins/spec-distill/scripts/start_bundle.py`(`_job_bundle` · `SYNC_LINE`)
- Modify: `plugins/spec-distill/scripts/team_status.py`(`plan_merged`)
- Modify: `plugins/spec-distill/scripts/job_results.py`(`failed_streak`)
- Test: `plugins/spec-distill/tests/test_human_gate.sh` · `tests/test_start_bundle.sh` · `tests/test_team_results.py` · `tests/test_job_results.sh`

**Interfaces:**
- Consumes: `roadmap_status.build`(보고의 블록마다 `branch_states` — `branch` · `tip` · `merged` · 있을 때 `uncountable`) · `human_lines.retry_open` · `RETRY_STOP` · `retry_name` · `roadmap_status._sh_word`.
- Produces:
  - `team_status.plan_merged(reader, block: dict, n: int) -> tuple` — `(머지 근거 | None, 셀 수 없는 사유 | None)`(J11). `block` 은 상태 보고의 블록이다. `branch_states[n-1]` 에 `uncountable` 이 있으면 `(None, 그 글)`, `merged` 가 있으면 `(그 글, None)`, `tip` 이 `None` 이고 기본 브랜치에 그 계획의 자취(설계 흐름은 `team.plan(job, n)` · 설계 없는 흐름은 결과 폴더의 `implement` 결과 파일)가 있으면 `("브랜치는 없고 기본 브랜치에 <경로> 가 있다 — 상태 보기는 이 브랜치를 머지로 세지 못한다", None)`, 아니면 `(None, None)`. 브랜치 칸에 n 번째가 없으면 `(None, None)`
  - `job_results.check_result(…, newer_ok=False)` — 키워드로만 주는 새 인자. 참이면 사유 「같은 단계 · 같은 계획의 더 새 시도 … 가 있다」 하나를 넣지 않는다(다른 사유는 그대로)
  - `job_results.failed_streak(git, tip, team, job, intent_text, plan, before: int) -> int` — 그 계획의 `implement` 시도 가운데 번호가 `before` 보다 작은 것을 큰 번호부터 보아, 「끝」 줄이 있고 **산 받음 줄이 없는** 시도가 이어지는 수(J12). 산 받음 줄 — 그 결과 파일의 이름과 머리 `head` 를 가리키는 꼴 맞는 받음 줄(`team_files.received`)이 있고 `check_result(git, tip, team, job, 이름, newer_ok=True).ok` 가 참이다. 「끝」 줄이 없거나 읽지 못한 시도, 산 받음 줄이 있는 시도를 만나면 멈춘다. 막힘 파일은 시도가 아니다
  - `start_bundle.SYNC_LINE = "맞추는 명령: python3 %s job sync --result %s --role %s --bundle-at %s --job-at %s"` — 첫 `%s` 는 `roadmap_status._sh_word(str(Path(__file__).resolve().parent / "roadmap_write.py"))`(J13)

`_job_bundle` 의 차례: 인자 규칙 → 브랜치 고르기 → **머지된 계획 멈춤** → INTENT.md 읽기 → 관문(과제 9) → 시도 번호 → **연속 실패 멈춤** → 묶음.

- 머지된 계획 — 블록의 과제면 **어느 단계든**(J30) `roadmap_status.build(git, argparse.Namespace(roadmap=a.roadmap, roadmap_file=None, json=False))` 의 그 블록으로 `plan_merged(reader, 블록, a.plan or 1)` 을 부른다. 근거가 있으면 `Refused("%s 의 계획 %d 는 이미 기본 브랜치에 머지됐다(%s) — 머지 뒤에 고칠 일은 새 계획이나 새 과제로 연다" % …)`(설계 없는 흐름은 「의 계획 n」 을 뺀다), 셀 수 없는 사유면 `Unchecked`. 보고에 그 블록이 없으면 `Unchecked`. 로드맵 밖 과제는 R1 의 멈춤(`_task`)이 그대로 한다.
- 연속 실패 — 단계가 `implement` 일 때 `failed_streak(…, before=이번 시도 번호) >= human_lines.RETRY_STOP` 이고 `human_lines.retry_open(scope, 결과 파일의 계획 번호, 이번 시도 번호, deep=True)` 가 거짓이면 `Refused("구현 시도 %d번이 이어서 받아지지 않았다(%s) — 사용자에게 가서 다시 할지 정한다. 다시 하기로 하면 질문 창으로 확인받고 `걸음 건너뜀` 줄(%s)을 적는다" % (수, 그 결과 파일 이름들, retry_name(…)))`. 설계 없는 흐름은 계획 번호가 `None` 이라 이름이 `다시 시도 구현 시도 <k>` 다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_team_results.py` 에 `failed_streak` 의 표를 더한다. 결과 폴더와 결정 기록은 그 파일의 도우미(`result(…)`)와 가짜 git(이름 목록과 글을 돌려주는 작은 객체)으로 짓고, 결과 대조는 `mock.patch.object(job_results, "check_result", …)` 로 갈아 끼워 「대조」 칸의 값을 돌려주게 한다(이어짐을 세는 규칙만 잰다 — 진짜 대조와의 이음매는 아래 셸 표가 잰다). 갈아 끼운 함수는 `newer_ok=True` 로 불렸는지도 단언한다.

| 시도들(1부터) | `before` | 기대 |
|---|---|---|
| 없음 | 1 | 0 |
| 1 끝 · 받음 줄 없음 | 2 | 1 |
| 1 · 2 끝 · 받음 줄 없음 | 3 | 2 |
| 1 끝 · 받음 줄 있음 · 대조 통과 / 2 끝 · 받음 줄 없음 | 3 | 1 |
| 1 끝 · **받음 줄은 있는데 대조 거절**(손으로 쓴 받음 줄) / 2 끝 · 받음 줄 없음 | 3 | 2(J12 — 꼴만 맞는 줄은 산 받음 줄이 아니다) |
| 1 끝 · 받음 줄의 커밋이 그 파일의 `head` 와 다르다(대조는 통과) | 2 | 1 |
| 1 끝 · 받음 줄 없음 / 2 **끝 줄 없음**(도는 중) | 3 | 0 |
| 1 · 2 끝 · 받음 줄 없음 / 3 끝 줄 없음(잇는 중) | 3 | 2 |
| 계획 1 의 1 끝 · 받음 줄 없음 / 계획 2 의 시도 둘이 실패 | 계획 1 · 2 | 1 |
| 구현 1 끝 · 받음 줄 없음 / `design` · `plan` 결과 파일 둘(끝 · 받음 줄 없음) | 2 | 1(구현 시도만 센다 — 셋이 아니다) |
| 1 끝 · 받음 줄 없음 / 막힘 파일(`BLOCKED.md`)이 있다 | 2 | 1(막힘은 수를 늘리지 않는다 — 둘이 아니다) |
| 1 · 2 끝 · 받음 줄 없음 / 막힘 파일이 있다 | 3 | 2(막힘은 이어짐을 끊지도 않는다) |

`tests/test_job_results.sh` — 「같은 단계 · 같은 계획의 더 새 시도」 를 재는 걸음 옆에 단언 둘을 더한다: 같은 결과 파일을 `check_result(…, newer_ok=True)` 로 부르면 그 사유가 없고 다른 사유는 그대로다 · `newer_ok` 없이 부르면 지금처럼 그 사유가 있다(양성 대조).

`tests/test_human_gate.sh` 에 더한다. 과제 9 의 준비를 고친다 — E1 의 설계 파일에 `## Acceptance Criteria` 절(`- AC1: 자리표시`)을, `plan-1.md` 에 `### Task 1: 자리표시` 절과 그 안의 `AC1` 을 둔다(결과 대조가 결과 파일의 `AC1:` 줄로 통과와 거절을 가를 수 있게). `finish_attempt <k> [AC 줄]` 은 `implement-plan-1-<k>.md` 를 `job sync` 로 만들고(받은 묶음의 「맞추는 명령」 줄 그대로) 준 줄을 본문에 넣은 뒤 `--end` 로 끝 줄을 적어 올리는 도우미다.

| # | 준비 | 명령 | 기대 |
|---|---|---|---|
| 20 | 과제 9 의 E1(계획 1 이 열려 있다). `finish_attempt 1`(AC 줄 없음 — 받음 줄도 적지 않는다) | `bundle --job E1 --stage implement --plan 1` | `0` · `쓸 것:` 줄이 `…/implement-plan-1-2.md`(실패 하나로는 멈추지 않는다) |
| 21 | 결과 폴더에 막힘 파일(`BLOCKED.md` — R1 의 꼴)을 더해 올린다 | 위와 같다 | `0`(AC13 — 실패 하나와 막힘으로는 멈추지 않는다. 막힘을 세면 여기서 멈춘다) |
| 22 | `finish_attempt 2` | 위와 같다 | `1` · 표준 출력 빔 · 표준 오류에 `구현 시도 2번이 이어서 받아지지 않았다` 와 `다시 시도 plan 1 시도 3`(막힘 파일이 있어도 「3번」 이 아니다) |
| 23 | 〃 | `bundle --job E1 --stage plan --plan 1` · `--stage design` | 둘 다 `0`(설계 · 계획 단계에는 이 멈춤이 없다) |
| 24 | `approved "걸음 건너뜀" E1 - "다시 시도 plan 1 시도 3" 2026-11-23` 뒤 올린다 | 22 의 명령 | `0` · `쓸 것:` 이 `…/implement-plan-1-3.md` |
| 25 | `finish_attempt 3`(AC 줄 없음) | 위와 같다 | `1` · 표준 오류에 `다시 시도 plan 1 시도 4`(그 줄은 시도 3 하나만 풀었다) |
| 26 | 시도 3 에 **손으로** 받음 줄을 `decide` 로 적어 올린다 — `- 결과 받음 · 2026-11-24 · 「implement-plan-1-3.md · <그 결과 파일 머리의 head> · 결과 대조: 통과 — 자리표시」`(꼴은 맞다. 그 결과 파일은 AC 줄이 없어 결과 대조를 지나지 못한다) | 위와 같다 | 여전히 `1` · `다시 시도 plan 1 시도 4`(AC13 — 리더가 손으로 쓴 받음 줄로는 멈춤이 풀리지 않는다) |
| 27 | `approved "걸음 건너뜀" E1 - "다시 시도 plan 1 시도 4" 2026-11-24` 뒤 올리고 묶음을 받아 `finish_attempt 4 "AC1: 구현됨 — 자리표시"`. `job_results.py check --job E1 --result implement-plan-1-4.md` 가 낸 받음 줄을 `record --spec … --line` 으로 적어 올린다 | `bundle --job E1 --stage implement --plan 1` | `0` · `쓸 것:` 이 `…/implement-plan-1-5.md`(결과 대조를 지난 받음 줄이 이어짐을 끊는다 — 26 의 양성 대조) |
| 28 | `feature/tm-e1` 을 기본 브랜치에 `--no-ff` 로 머지해 올린다(브랜치는 남긴다) | `bundle --job E1 --stage implement --plan 1` · `--stage plan --plan 1` · `--stage review --plan 1` · `--stage design` | 넷 다 `1` · 표준 출력 빔 · 표준 오류에 `이미 기본 브랜치에 머지됐다`(AC14 · J30 — 단계를 가리지 않는다) |
| 29 | 그 브랜치를 로컬과 origin 에서 지운다 | 위 넷 | 28 과 같다(브랜치를 지웠든 남겼든 같다). 표준 오류에 `상태 보기는 이 브랜치를 머지로 세지 못한다` 가 있다(J11 — 더한 갈래로 멈췄다) |
| 30 | 〃 | `bundle --job E1 --stage plan --plan 2` | 표준 오류에 `머지됐다` 가 없다(계획 2 는 머지되지 않았다) |
| 31 | 한 번도 만든 적 없는 브랜치의 블록 E3 | `bundle --job E3 --stage design` · `bundle --job E3 --stage plan --plan 1` | 앞은 `0` · 알림에 `과제 브랜치 … 가 아직 없다`. 뒤는 `1` 이되 사유가 `` `spec 승인` 줄이 없다 `` 이고 `머지됐다` 가 아니다(머지 검사가 도는 두 단계에서 없는 브랜치를 머지로 읽지 않는다 — 28 · 29 의 양성 대조) |
| 32 | 설계 없는 흐름의 블록 E2 — `approved "흐름 승인"` 뒤 `implement-1.md` 를 끝까지 써 올리고 `feature/tm-e2` 를 기본 브랜치에 머지해 올린다 | `bundle --job E2 --stage implement` | `1` · `이미 기본 브랜치에 머지됐다`(AC14 — 설계 없는 흐름) |
| 33 | 그 브랜치를 로컬과 origin 에서 지운다 | 위와 같다 | `1` · 표준 오류에 `implement-1.md` 와 `머지됐다`(설계 없는 흐름의 자취는 기본 브랜치의 `implement` 결과 파일이다) |
| 34 | 브랜치를 만든 적 없는 설계 없는 흐름의 블록(새 레포 사본의 E2) | 위와 같다 | 표준 오류에 `머지됐다` 가 없다(양성 대조) |

`tests/test_start_bundle.sh` — 「맞추는 명령」 을 재는 줄들의 기대를 새 꼴로 고치고(`맞추는 명령: python3 ${S}/roadmap_write.py job sync --result …` — `$S` 는 그 테스트가 쓰는 스크립트 폴더의 절대 경로다), 「끝에서 끝」 절의 「맞추는 명령을 그대로 돌리면」 걸음을 인자를 다시 가르지 않고 줄을 그대로 돌리게 고친다:

```bash
CMD="$(grep '^맞추는 명령: ' "$T/e2e.txt")"
assert_eq "$(printf '%s' "$CMD" | cut -d' ' -f1-3)" "맞추는 명령: python3" "AC16: 맞추는 명령 줄이 해석기부터 적혀 있다"
S_RC=0; (cd "$W" && bash -c "${CMD#맞추는 명령: }") > "$T/out.txt" 2>&1 || S_RC=$?
assert_eq "${S_RC} · $(cat "$T/out.txt")" "0 · [spec-distill] 결과 파일을 맞췄다: ${EJ}/results/implement-1.md — 머리 만듦" "AC16: 맞추는 명령을 그대로 돌리면 결과 파일의 머리를 만든다"
```

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_results.py 2>&1 | tail -3; bash plugins/spec-distill/tests/test_human_gate.sh | grep -cE '✗'; bash plugins/spec-distill/tests/test_start_bundle.sh | grep -E '✗.*AC16'`
Expected: `AttributeError: … 'failed_streak'` · 0 보다 큰 수 · AC16 두 줄이 ✗

- [ ] **Step 3: 구현한다** — 위 Produces 와 차례대로. `references/team-files.md` §9 의 「맞추는 명령」 줄 보기(코드 블록의 한 줄)를 새 꼴로 고친다. `team_status.py` · `job_results.py` 에 더하는 코드는 상태 계산의 잠금 규칙 안에서 쓴다(Global Constraints).

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_results.py plugins/spec-distill/tests/test_team_docs.py 2>&1 | tail -3; for t in test_human_gate test_start_bundle test_team_sync test_team_status test_roadmap_status; do printf '%s: ' "$t"; bash plugins/spec-distill/tests/$t.sh | tail -1; done; bash shared/tests/test_python_floor.sh | tail -1`
Expected: `OK` · 모두 실패 0. 29 · 33 이 붉으면(지운 브랜치가 머지된 것으로 읽히지 않는다) `plan_merged` 의 셋째 갈래(끝이 없고 기본 브랜치에 자취가 있다)를 본다 — 테스트 레포의 origin 은 GitHub 가 아니라 머지 메시지 길이 서지 않는다. `test_start_bundle.sh` 에서 머지된 블록에 `design` 묶음을 받던 걸음이 붉으면 그 기대를 멈춤(1)으로 고치고 과제 보고에 적는다(J30).

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/start_bundle.py plugins/spec-distill/scripts/team_status.py plugins/spec-distill/scripts/job_results.py plugins/spec-distill/references/team-files.md plugins/spec-distill/tests/test_human_gate.sh plugins/spec-distill/tests/test_start_bundle.sh plugins/spec-distill/tests/test_team_results.py plugins/spec-distill/tests/test_job_results.sh
git commit -m "feat(spec-distill): 머지된 계획과 이어진 구현 실패에서 시작 묶음을 멈추고 맞추는 명령을 그대로 돌릴 수 있게 한다"
```

---

### Task 11: 결과 대조의 관문 확인과 `human-check`

**AC:** AC10 · AC11 · AC12(결과 대조) · AC23(계획 1 몫) · AC20(알림)

**Files:**
- Modify: `plugins/spec-distill/scripts/job_results.py`(`check_result` · `_check`)
- Modify: `plugins/spec-distill/scripts/conductor_ledger.py`(`COMMANDS` · `c_human_check`)
- Test: `plugins/spec-distill/tests/test_human_gate.sh` · `tests/test_job_results.sh` 와 결과 대조를 부르는 셸 테스트

**Interfaces:**
- Consumes: `human_lines.missing` · `passed` · `expected` · `match` · `is_human` · `parse` · `collect` · `GATE_OFF` · `Reader.scope` · `Reader.flow` · `Reader.job_tips` · `team_status.plan_merged`(과제 6 · 8 · 10) · `team_files.received`(꼴 맞는 받음 줄).
- Produces:
  - `job_results.check_result(…, extra=())` — 키워드로만 주는 새 인자(과제 10 의 `newer_ok` 와 함께 선다). `extra` 의 글을 거절 사유에 더한 뒤 첫 줄을 짓는다(받음 줄 다시 세기 `receipt` 와 `failed_streak` 은 `extra` 를 주지 않는다)
  - `job_results.py check` — 대조 전에 `human_lines.missing(scope, 결과 파일 이름의 단계, 이름의 계획 번호, 흐름, deep=True)` 를 불러 그 사유를 `extra` 로 넘긴다(J31 — 결과의 단계로 §3 표를 본다: `design` 결과는 없음 · `plan` 결과는 `spec 승인` · `implement` · `review` 결과는 둘 · 설계 없는 흐름은 `흐름 승인`). 지나지 못하면 첫 줄이 `결과 대조: 거절 <n>건 — <이름>`, 사유는 `거절 사유: <사유>` 줄, 받음 줄은 내지 않고 종료 코드 1 이다. `human_gate` 가 꺼져 있으면 첫 줄 바로 아래에 `알림: 사람 줄 대조가 꺼져 있다` 를 낸다. **흐름은 로드맵에서만 정한다**(J32) — 그 과제가 블록이면 `Reader.flow(블록)`, 블록이 아니면 설계 없는 흐름이다. `--branch` 는 읽을 브랜치만 정한다
  - `conductor_ledger.py human-check --roadmap <로드맵> --job <과제>` — J24 의 두 가지를 낸다. ① 그 과제의 사람 줄(`is_human` 이 참인 줄 — 근거 없는 줄 포함)마다 `<판정> — <줄>`, `지남` 이 아니면 그 아래 `    사유: <사유>` ② `human_lines.expected(흐름, 계획 파일 이름들, 결과 파일 이름들, 꼴 맞는 받음 줄의 결과 파일 이름들)` 의 줄마다 `human_lines.passed(scope, 종류, 계획, deep=True)` 가 지나지 못했고 **그 종류(와 계획)의 줄이 하나도 없으면** ``줄 없음 — `<종류>` 줄[(계획 <n>)]`` 과 그 아래 `    사유: <자취>`. 자취(계획 파일 · 결과 파일 이름)는 그 과제의 브랜치 끝들과 기본 브랜치에서 모은다. 낼 줄이 하나도 없으면 `사람 줄 없음`. `human_gate` 가 꺼져 있으면 첫 줄이 `사람 줄 대조가 꺼져 있다` 이고 판정은 줄의 유무로만 한다. 아무것도 쓰지 않는다. 줄마다 「지금 본문」 의 끝은 J17 로 고른다. 종료 코드는 J24

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_human_gate.sh` 에 더한다. `check() { (cd "$W" && python3 "$S/job_results.py" check --roadmap "$RM" "$@" --date 2026-11-30) > "$T/c.txt" 2>&1; echo $?; }`(이 `--date` 는 R1 의 받음 줄 날짜다 — 사람 줄이 아니다).

| # | 준비 | 명령 | 기대 |
|---|---|---|---|
| 41 | 새 레포. E1 설계 · `approved "spec 승인"` · `plan-1.md` · **`계획 검토` 줄 없이** `implement-plan-1-1.md` 를 끝까지 써 올린다(시작 묶음 없이 띄워진 담당자) | `check --job E1 --result implement-plan-1-1.md` | `1` · 첫 줄이 `결과 대조: 거절 ` 로 시작 · `거절 사유:` 줄에 `` `계획 검토` 줄이 없다 `` · `- 결과 받음` 줄이 없다(AC10) |
| 42 | 〃 | `check --job E1 --result implement-plan-1-1.md --branch feature/tm-e1` | 41 과 같다 — 사유가 `계획 검토` 이고 `흐름 승인` 이 아니다(J32 — `--branch` 가 흐름을 바꾸지 않는다) |
| 43 | `approved "계획 검토" E1 1 - 2026-11-21` 뒤 올린다 | 41 의 명령 | `0` · `- 결과 받음 · 2026-11-30 · 「implement-plan-1-1.md · …」` 한 줄(양성 대조) |
| 44 | 세션 기록 폴더를 치운다 | 위와 같다 | `1` · `거절 사유:` 줄에 `확인 못 함` 과 `다시 승인받는다`(AC11). 그 뒤 되돌린다 |
| 45 | 43 의 계획 검토 줄을 손으로 고친다 — 근거의 uuid 를 없는 값으로 | 위와 같다 | `1` · `어긋남` |
| 46 | 45 를 되돌리고 `plan-1.md` 를 고쳐 커밋한 뒤 줄의 판만 새 커밋으로 고쳐 쓴다 | 위와 같다 | `1` · `어긋남`(AC11 — 진짜 옛 답 · 판만 새것) |
| 47 | 계획 검토 줄을 지우고 `approved "걸음 건너뜀" E1 - "계획 검토 plan 1" 2026-11-22` | 위와 같다 | `0`(AC12) |
| 48 | E2(설계 없는 흐름)의 `implement-1.md` 를 끝까지 써 올린다. `흐름 승인` 줄 없음 | `check --job E2 --result implement-1.md` | `1` · `` `흐름 승인` 줄이 없다 ``(AC10) |
| 49 | `approved "흐름 승인" E2 - - 2026-11-22` 뒤 올린다 | 위와 같다 | `0` |
| 50 | 새 과제 브랜치(E3)에 설계 파일과 `plan-plan-1-1.md` · `design-1.md` 결과 파일을 끝까지 써 올린다. `spec 승인` 줄 없음 | `check --job E3 --result plan-plan-1-1.md` · `check --job E3 --result design-1.md` | 앞은 `거절 사유:` 에 `` `spec 승인` 줄이 없다 `` 가 있다(J31 — `plan` 결과는 §3 표의 `plan` 줄). 뒤는 관문 사유가 하나도 붙지 않는다(`design` 은 없음) |
| 51 | `approved "spec 승인" E3 - - 2026-11-22` 뒤 올린다 | `check --job E3 --result plan-plan-1-1.md` | `거절 사유:` 에 `spec 승인` 이 없다(양성 대조) |
| 52 | `human_gate: 끔` 을 올리고 손으로 적은 줄 둘 | 41 의 명령(새 과제에서) | `0` · 둘째 줄이 `알림: 사람 줄 대조가 꺼져 있다`. 되돌리면 `1` |
| 53 | 43 의 상태 | `led human-check --roadmap "$RM" --job E1` | `0` · 줄 수가 사람 줄 수와 같고 모두 `지남 — ` 로 시작 · INTENT.md 와 `g status --short -- "$TM"` 가 그대로(아무것도 쓰지 않는다) |
| 54 | 손으로 적은 `- spec 승인 · …` 줄 하나 · 없는 uuid 를 가리키는 줄 하나 · 승인 뒤 본문이 바뀐 줄 하나 · 세션 기록이 없는 세션을 가리키는 줄 하나를 더해 커밋 | 위와 같다 | `1` · 출력에 `근거 없음 — ` · `어긋남 — ` · `낡음 — ` · `확인 못 함 — ` 로 시작하는 줄이 하나씩 있고 진짜 줄은 `지남 — `(AC23 의 판정 다섯) · 지나지 못한 줄 바로 아래가 `    사유: ` 로 시작한다 |
| 55 | 41 의 상태에서(진짜 `spec 승인` 만 있다 · `계획 검토` 줄 없음 · 구현 결과 있음) 받음 줄을 손으로 적어 올린다 | 위와 같다 | `1` · 출력에 ``줄 없음 — `계획 검토` 줄(계획 1)`` 과 그 아래 `    사유: implement-plan-1-1.md 가 있다` · `spec 승인` 줄은 `지남 — `(J24 — 승인 줄 없이 받음 줄을 손으로 적은 길이 드러난다) |
| 56 | 설계 없는 흐름의 과제에 결과 파일만 있고 `흐름 승인` 줄이 없다 · 설계 흐름의 과제에 계획 파일만 있고 사람 줄이 없다 | 각 과제에 `led human-check …` | 둘 다 `1` · 각각 ``줄 없음 — `흐름 승인` 줄`` · ``줄 없음 — `spec 승인` 줄`` |
| 57 | 자취도 사람 줄도 없는 과제(브랜치만 있다) | `led human-check --roadmap "$RM" --job <그 과제>` | `0` · 출력이 정확히 `사람 줄 없음` |
| 58 | `human_gate: 끔` 을 올린다 | 53 의 명령 | 첫 줄이 `사람 줄 대조가 꺼져 있다` |
| 59 | 없는 과제 · 옛 형식 로드맵 | `led human-check …` | `2` |

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_human_gate.sh | grep -E '✗' | tail -8`
Expected: 41 · 42 · 44 – 46 · 48 · 50 · 53 – 59 가 ✗

- [ ] **Step 3: 구현한다** — 위 Produces 대로.

- [ ] **Step 4: 기존 테스트를 관문 아래로 옮긴다**

Run: `for t in test_human_gate test_job_results test_team_tasks test_team_write test_team_status test_start_bundle test_team_stale; do printf '%s: ' "$t"; bash plugins/spec-distill/tests/$t.sh | tail -1; done; python3 -m unittest plugins/spec-distill/tests/test_team_results.py plugins/spec-distill/tests/test_conductor_ledger.py 2>&1 | tail -3`
Expected: 모두 실패 0 · `OK`. `job_results.py check` 로 구현 결과를 통과시키던 걸음은 대조 전에 그 과제의 줄을 `approved` 로 적어 올린다(과제 9 Step 4 와 같은 규칙). `check_result` 를 파이썬으로 바로 부르는 테스트는 `extra` 의 기본값 덕에 그대로다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/job_results.py plugins/spec-distill/scripts/conductor_ledger.py plugins/spec-distill/tests
git commit -m "feat(spec-distill): 승인 없는 구현 결과를 받지 않고 사람 줄 전부를 대조해 보이는 human-check 를 더한다"
```

---

### Task 12: 끝에서 끝 · 옛 형식 · 흔들어 보기

**AC:** AC21(계획 1 몫) · AC5 – AC14 의 이음매

**Files:**
- Test: `plugins/spec-distill/tests/test_human_gate_e2e.sh`(새로 · 100755)

**Interfaces:**
- Consumes: 과제 1 – 11 의 명령줄 전부와 `team_repo.sh` 의 도우미.

- [ ] **Step 1: 끝에서 끝 테스트를 쓴다**

새 레포 하나에서 손으로 적는 줄 없이 한 번을 돈다. 걸음마다 앞 걸음의 출력을 다음 걸음이 받는다.

1. `team_repo` · `claim` · 공통 문서를 올린다. `feature/tm-e1` 을 만든다.
2. `start_bundle.py --job E1 --stage design` → 0. 묶음의 `역할 문서` 가 leader 것이다.
3. 설계 파일을 커밋한다. `--stage plan --plan 1` → 1(승인 없음).
4. `ask-head` → 머리. 그 머리로 답한 기록 → `record --human "spec 승인"`(날짜 인자 없이 — 줄의 날짜가 그 답의 시각에서 온 것인지 본다) → 커밋 · push.
5. `--stage plan --plan 1` → 0. `맞추는 명령` 줄의 역할이 `worker` 다. 그 줄을 그대로 돌려 `plan-plan-1-1.md` 의 머리를 만든다.
6. `plan-1.md` 를 커밋한다. `--stage implement --plan 1` → 1(계획 확인 없음).
7. `계획 검토` 를 같은 길로 적는다(머리가 `E1 plan 1 @<판>` 이다) → `--stage implement --plan 1` → 0. 맞추는 명령을 그대로 돌린다.
8. 예약 경로의 파일 하나를 커밋하고 결과 파일에 `AC` 줄과 「끝」 줄을 적어 올린다(설계 파일의 `## Acceptance Criteria` 에 `AC1` 하나를 두고 `plan-1.md` 의 task 절이 `AC1` 을 부른다).
9. `job_results.py check` → 0 · 받음 줄. 그 줄을 `record --spec … --line` 으로 적어 올린다.
10. 상태 계산 → E1 이 「구현 끝」.
11. `human-check` → 0 · 두 줄 모두 `지남` 이고 `줄 없음` 줄이 없다.

**지어낸 줄 × 세 자리.** 같은 레포의 새 과제 브랜치(E3 — 설계 파일 · `plan-1.md` · 끝까지 쓴 `implement-plan-1-1.md`)에서, 아래 줄을 하나씩 **손으로** INTENT.md 에 적어 커밋해 올리고(진짜 줄은 두지 않는다 — 줄마다 그 줄 하나만 `spec 승인` 또는 `계획 검토` 의 후보다) 세 자리를 본다 — `start_bundle.py --job E3 --stage plan --plan 1`(또는 계획 검토 줄이면 `--stage implement --plan 1`)은 1 이고 표준 출력이 비었다 · `job_results.py check --job E3 --result implement-plan-1-1.md` 는 1 이고 받음 줄이 없다 · `human-check` 는 1 이고 그 줄이 표의 판정으로 시작한다. 줄을 본 뒤에는 그 커밋을 되돌린다(`git revert`). 줄의 글자는 `human_lines.render` 의 꼴로 짓고 근거는 `answer` 가 낸 uuid 다.

| 지어낸 줄 | 기록에 지어 넣는 것 | 판정 |
|---|---|---|
| 손으로 쓴 줄(근거 칸 없음) | — | `근거 없음` |
| 없는 항목을 가리키는 줄 | — (uuid 가 기록에 없다) | `어긋남` |
| 다른 과제의 답을 가리키는 줄 | 머리가 `E1 @<E3 설계의 판>` 인 질문에 통과 라벨로 답한 것 | `어긋남` |
| 라벨만 바꾼 줄 | E3 의 머리로 시작하는 질문에 「수정 필요」 로 답한 것 | `어긋남` |
| 같은 호출의 다른 질문에서 고른 라벨 | 한 호출에 질문 둘 — E3 의 머리로 시작하는 질문에 「수정 필요」, 머리 없는 둘째 질문에 통과 라벨. 줄은 `#2` 를 가리킨다 | `어긋남` |
| 같은 근거를 두 번 쓴 줄 | 진짜 답 하나를 가리키는 줄 둘(둘째는 날짜만 하루 다르다) | 둘 다 `어긋남` |
| 진짜 옛 답 · 판만 새 커밋 | 진짜 답 뒤에 설계 본문을 고쳐 커밋하고 줄의 판을 새 커밋으로 | `어긋남` |
| 다른 계획의 답 | `plan-1.md` · `plan-2.md` 를 한 커밋에서 고친 뒤 머리 `E3 plan 2 @<판>` 에 답한 것을 `plan-1.md@<판>` 줄의 근거로 | `어긋남` |
| 날짜만 바꾼 줄 | 진짜 답 · 줄의 날짜를 열흘 뒤로 | `어긋남` |
| 모르는 출처의 답 | `--who other` | `확인 못 함` |

끝으로 양성 대조 — 같은 과제에 진짜 줄(`approved`)을 적으면 세 자리가 0 이다. 그리고 그 줄이 두 브랜치 끝에 함께 있을 때(과제 9 의 14b 와 같은 준비) `human-check` 가 그 줄을 **한 번만** 내고 `지남` 이다.

그 뒤 같은 레포에서 Verification Plan 의 경우를 본다(이미 과제 9 – 11 이 따로 잰 것을 한 흐름 위에서 다시 잰다): 승인 뒤 설계 본문을 고친 것(구현 묶음 1 · 상태 「설계 중」 · `human-check` 에 `낡음`) → 되돌림 · 승인 뒤 미룸 절만 고친 것(그대로 0) · 설계 없는 흐름(E2: 흐름 승인 없이는 묶음도 결과도 1, 있으면 0).

- [ ] **Step 2: 옛 형식이 그대로인지 재는 절을 더한다(AC21)**

같은 파일에 옛 형식 레포를 하나 만든다(`tests/test_conductor_ledger.py` 의 `roadmap()` 이 짓는 꼴의 로드맵 — 머리말에 `layout` 이 없다 — 과 `## 지휘 기록` 절이 있는 설계문서).

| # | 명령 | 기대 |
|---|---|---|
| o1 | `conductor_ledger.py record --spec <옛 설계문서> --approval --date 2026-11-20 --choice "승인 — 계획 담당자에게"` | 0 · `## 지휘 기록` 의 마지막 줄이 정확히 `- spec 승인 · 2026-11-20 · 「승인 — 계획 담당자에게」`(판 · 근거 칸이 없다) |
| o2 | `… --line "계획 검토 · 2026-11-20 · 「글」"` | 0 · 그 줄이 적혔다 |
| o3 | `conductor_ledger.py record --human "spec 승인" --roadmap <옛 로드맵> --job A1` · `ask-head …` · `human-check …` | 셋 다 2 · 출력에 `team 형식` |
| o4 | `roadmap_status.py <옛 로드맵> --json`(그 에픽 브랜치에 설계문서가 있고 계획은 없다) | 그 블록의 근거가 `spec 승인됨(2026-11-20) · 계획 없음` 이다 — 근거 칸 없는 줄이 옛 형식에서는 지금처럼 승인으로 세어진다 |
| o5 | 설정에 `human_gate: 끔` · `켬` 을 번갈아 올리고 o1 · o4 | 결과가 같다(옛 형식은 이 키를 보지 않는다) |
| o6 | 옛 형식 에픽의 쌓인 기록에 `spec 승인 · 2026-11-20 · 「승인」` 과 `계획 검토 · 2026-11-20 · 「글」` 을 쌓고 `conductor_ledger.py flush --roadmap <옛 로드맵> --session … --epic A1 --spec <옛 설계문서>` | 0 · 두 줄이 `## 지휘 기록` 에 옮겨졌고 쌓인 기록이 비었다(AC21 — 옛 형식의 `flush` 는 사람 줄 종류의 글자를 막지 않는다) |

그리고 `git diff origin/main -- plugins/spec-distill/tests/test_roadmap_status.sh plugins/spec-distill/tests/test_roadmap_model.py` 를 과제 보고에 붙인다 — 옛 형식 테스트에서 바뀐 것은 과제 3 이 `test_roadmap_model.py` 에 더한 테스트 하나와, 과제 5 Step 5 가 `test_roadmap_status.sh` 에서 고친 세 곳(정적 검사 목록 · 수 단언 둘 · 변이 사본 목록 둘 — 새 모듈 이름과 수 글자뿐)이어야 한다. 그 밖의 줄이 바뀌었으면 멈춰 보고한다.

- [ ] **Step 3: 돌려서 통과를 본다**

Run: `chmod +x plugins/spec-distill/tests/test_human_gate_e2e.sh && bash plugins/spec-distill/tests/test_human_gate_e2e.sh | tail -1`
Expected: 실패 0. 붉으면 그 이음매의 과제(1 – 11)로 돌아가 고치고 그 과제의 테스트에 빠졌던 경우를 더한다 — 이 파일의 기대를 느슨하게 하지 않는다.

- [ ] **Step 4: 커밋**

```bash
git add plugins/spec-distill/tests/test_human_gate_e2e.sh
git commit -m "test(spec-distill): 사람 줄과 관문의 끝에서 끝과 옛 형식 그대로를 잰다"
```

- [ ] **Step 5: 흔들어 본다(커밋한 뒤)**

변이마다 `PYTHONDONTWRITEBYTECODE=1` 로 `test_human_record.sh` · `test_human_gate.sh` · `test_human_gate_e2e.sh` · `test_team_status.sh` 를 돌려 붉어지는 단언 이름을 과제 보고의 표에 적는다. 붉어지지 않는 변이는 그 조건을 재는 테스트를 더해 커밋한다. 변이마다 되돌림을 확인한다(Global Constraints).

| 파일 | 변이 | 종류 |
|---|---|---|
| `start_bundle.py` | 관문 호출의 `deep=True` 를 `False` 로 | 값 바꾸기 |
| `start_bundle.py` | 관문 호출을 지운다 | 지우기 |
| `start_bundle.py` | 사유가 있을 때가 아니라 없을 때 멈춘다 | 뒤집기 |
| `start_bundle.py` | 연속 실패 비교를 `>` 로(셋부터 멈춘다) | 값 바꾸기 |
| `start_bundle.py` | 머지된 계획 검사를 지운다 | 지우기 |
| `start_bundle.py` | 머지된 계획 검사를 `design` 단계에서 건너뛴다 | 값 바꾸기 |
| `job_results.failed_streak` | 결과 대조를 다시 하지 않는다(받음 줄의 꼴만 본다) | 지우기(손으로 쓴 받음 줄의 줄이 붉어야 한다) |
| `job_results.failed_streak` | `newer_ok=True` 를 주지 않는다 | 값 바꾸기(받은 시도 뒤의 묶음이 멈추는 줄이 붉어야 한다) |
| `job_results.failed_streak` | 막힘 파일을 시도로 센다 | 값 바꾸기 |
| `job_results.py` | `check` 의 관문을 `implement` 결과에만 건다 | 값 바꾸기(`plan` 결과의 줄이 붉어야 한다) |
| `job_results.py` | `--branch` 가 있으면 설계 없는 흐름으로 본다 | 값 바꾸기 |
| `team_status.py` | 꺼짐 알림을 설계 흐름 갈래에서만 넣는다 | 값 바꾸기(설계 없는 흐름 · 로드맵 밖 과제의 줄이 붉어야 한다) |
| `conductor_ledger.py` | `human-check` 가 `줄 없음` 을 내지 않는다 | 지우기 |
| `conductor_ledger.py` | `record --human` 이 날짜를 오늘로 적는다 | 값 바꾸기 |
| `conductor_ledger.py` | `record --human` 이 `UNKNOWN` 인 답을 건너뛴다(3 을 내지 않는다) | 값 바꾸기 |
| `conductor_ledger.py` | 옛 인자 막기를 `record` 에만 걸고 `flush` 에는 걸지 않는다 | 지우기 |
| `job_results.py` | `check` 의 관문 사유를 `extra` 로 넘기지 않는다 | 지우기 |
| `job_results.py` | 설계 없는 흐름을 설계 흐름으로 본다 | 값 바꾸기 |
| `team_status.py` | `passed` 를 `deep=True` 로 부른다 | 값 바꾸기(세션 기록 없이도 「계획」 인 단언이 붉어야 한다) |
| `team_status.py` | 승인 날짜를 다시 `self._approval(intent)` 에서 받는다 | 값 바꾸기 |
| `team_status.plan_merged` | 셋째 갈래(끝이 없고 계획 파일이 있다)를 지운다 | 지우기 |
| `conductor_ledger.py` | `record --human` 의 「이미 근거인 답」 검사를 지운다 | 지우기 |
| `conductor_ledger.py` | 브랜치 검사를 지운다 | 지우기 |
| `conductor_ledger.py` | 옛 인자 막기에서 `human_gate` 를 보지 않고 늘 막는다 · 늘 지나게 한다 | 값 바꾸기 둘 |
| `conductor_ledger.py` | 답을 뒤가 아니라 앞에서부터 고른다 | 뒤집기 |
| `repo_defaults.py` | `gate_on` 이 값이 `None` 일 때 거짓 | 뒤집기 |

---

### Task 13: 문서와 판

**AC:** AC22(계획 1 몫)

**Files:**
- Modify: `plugins/spec-distill/references/team-files.md` · `plugins/spec-distill/README.md` · `plugins/spec-distill/CHANGELOG.md` · `plugins/spec-distill/dependencies.md` · `plugins/spec-distill/.claude-plugin/plugin.json`
- Test: `plugins/spec-distill/tests/test_team_docs.py`

- [ ] **Step 1: 문서 락을 쓴다(실패하는 테스트)**

`tests/test_team_docs.py` 에 더한다:

```python
class HumanLines(unittest.TestCase):   # R2 AC22 — 계획 1 몫
    def test_team_files_documents_human_lines_and_gates(self):
        text = (REF / "team-files.md").read_text(encoding="utf-8")
        for kind in HL.KINDS:
            for label in HL.PASS_LABELS[kind]:
                self.assertIn("「%s」" % label, text, label)
        for word in (HL.PASS, HL.NO_EVIDENCE, HL.MISMATCH, HL.UNCHECKED, HL.STALE, HL.GATE_OFF, "human_gate", "record --human", "ask-head", "human-check",
                     "· 근거 <세션>:<항목>", "계획 검토 plan <n>", "다시 시도 plan <n> 시도 <k>", "다시 시도 구현 시도 <k>",
                     "<과제 번호> plan <n> @<판>", "줄 없음", "상태 보기는 이 브랜치를 머지로 세지 못한다"):
            self.assertIn(word, text, word)
        self.assertNotIn("`design` · `plan` 은 designer", text)
        self.assertNotIn("종류는 일곱", text)
        self.assertNotIn("다시 시도 시도 <k>", text)
        self.assertIn("날짜는 인자로 받지 않는다", text)

    def test_readme_changelog_and_dependencies(self):
        readme = (PLUGIN / "README.md").read_text(encoding="utf-8")
        for word in ("human_gate", "record --human", "사람 줄"):
            self.assertIn(word, readme, word)
        deps = (PLUGIN / "dependencies.md").read_text(encoding="utf-8")
        for word in ("세션 기록", "AskUserQuestion", "toolUseResult", "permissionDecision", "sourceToolAssistantUUID", "isSidechain"):
            self.assertIn(word, deps, word)
        top = (PLUGIN / "CHANGELOG.md").read_text(encoding="utf-8").split("\n## [")[1]
        for word in ("record --human", "human_gate", "worker"):
            self.assertIn(word, top, word)
```

(`HL` 은 `import human_lines as HL`, `PLUGIN` 은 그 파일에 있는 경로 상수이고 `REF = PLUGIN / "references"` 를 더한다.)

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_docs.py 2>&1 | tail -3`
Expected: `HumanLines` 의 두 테스트 FAIL

- [ ] **Step 3: 문서를 쓴다**

- `references/team-files.md`
  - §2 「결정 기록」 글머리 — 사람 줄 넷은 대기 줄로 쌓지 않고 `record --human` 이 그 브랜치의 INTENT.md 에 바로 쓰며 리더가 바로 커밋한다는 문장. 사람 줄의 꼴 · 종류와 묶이는 파일 · 통과 라벨 표(Global Constraints 의 글자) · 질문 머리(`<과제 번호> @<판>` · `계획 검토` 는 `<과제 번호> plan <n> @<판>`) · 관문 이름 넷 · 근거 칸(`근거 <세션>:<항목>` — 항목은 답 항목의 번호와 질문의 순번) · 날짜(「날짜는 인자로 받지 않는다 — 답한 시각에서 온다」 · 대조는 하루 넘게 다르면 어긋남) · 이어받은 세션은 앞 답을 적을 수 있고 같은 답은 세션이 달라도 한 번만 근거가 된다.
  - §5 「결정 기록에 쓰는 줄」 — `--approval` · `--line` · `flush` 는 team 형식에서 사람 줄 종류를 받지 않는다(2). `ask-head` · `record --human` 의 인자 · 종료 코드(3 은 끄는 길을 함께 보인다) · 「커밋된 뒤에 묻는다」 · 「쓸 브랜치의 worktree 에서 부른다」. 결과 대조가 결과의 단계로 관문 표를 본다는 것(J31) · 흐름은 로드맵에서만 정한다는 것(J32) · `human-check` 의 출력 두 가지와 예시(`<판정> — <줄>` · ``줄 없음 — `<종류>` 줄`` · `    사유: …`)와 종료 코드(J24).
  - §9 시작 묶음 — 관문 표 · 멈춤의 종료 코드와 사유 줄 · 머지된 계획 멈춤(단계를 가리지 않는다 · 브랜치 끝이 없고 기본 브랜치에 그 계획의 자취가 있을 때의 글 「상태 보기는 이 브랜치를 머지로 세지 못한다」 와 그 까닭 — J11) · 연속 실패 멈춤(2 로 고정 · 산 받음 줄은 결과 대조를 다시 지나는 것 · 막힘은 세지 않는다 · 설계와 계획 단계에는 없다 · 설계 없는 흐름의 이름 `다시 시도 구현 시도 <k>`) · `알림: 사람 줄 대조가 꺼져 있다`.
  - §10 단계 계산 — 표의 「설계 중」 · 「계획」 줄을 꼴 판정으로 고친다(판정 다섯과 표 · 세션 기록을 읽지 않는다 · 건너뜀 줄 · 근거 글자 J15). 「`계획 검토` 줄도 단계의 근거가 아니다」 문장은 남기고 「구현 묶음과 구현 결과의 관문이다(§9 · §5)」 를 잇는다.
  - 판정 표(설계 §2 의 다섯 줄)와 「막지 못하는 것」 넷(설계 Constraints 그대로)을 §10 뒤에 `### 사람 줄의 판정` 으로 둔다. 문서가 300줄을 넘으므로 `## 목차` 가 있으면 같은 커밋에서 맞춘다.
- `README.md` — 지휘자 절에 사람 줄과 관문을 세 문장으로(무엇을 막나 · 어떻게 적나 · 끄는 길 `human_gate: 끔` 과 그때 보이는 알림). 설정 키 표에 `human_gate`. 「Principles Instantiated」 에 Law 1 한 줄(승인된 설계 없이는 계획 · 구현이 시작되지 않는다 — 스크립트가 지킨다). 바뀐 기본 역할 한 줄. **P8 은 적지 않는다** — 철학 문서의 P8 줄을 고치는 것은 계획 2 다(두 문서가 다른 말을 하지 않게).
- `dependencies.md` — 표 아래에 `## 세션 기록` 절: 사람 줄이 Claude Code 의 세션 기록 파일에 기댄다는 것, 읽는 칸(과제 1 의 표에서 칸 이름만 — `permissionDecision` · `sourceToolAssistantUUID` · `toolUseResult.answers` · `isSidechain` · `timestamp`), 확인한 판의 범위(과제 1 Step 2 가 잰 값), 칸은 Claude Code 의 문서에 없고 판에 따라 바뀔 수 있으며 바뀌면 「확인 못 함」 이 되고 여는 길은 `human_gate: 끔` 이라는 것, 사람 없이 답이 나오는 길의 측정(받은 값 또는 「재지 못함」 — 이 계획 끝 「측정 값을 받으면」). 표의 판 칸은 손으로 고치지 않고 `python3 scripts/check_deps.py measure …`(그 파일 머리의 명령)로 다시 잰다.
- `CHANGELOG.md` — 새 머리 `## [<다음 minor>] — <날짜>`. Added: `record --human` · `ask-head` · `human-check` · `human_gate` · 결정 줄 종류 둘 · 시작 묶음과 결과 대조의 관문 · 머지된 계획 멈춤 · 연속 실패 멈춤. Changed: team 형식에서 `--approval` · `--line` 이 사람 줄 종류를 받지 않는다 · 단계 계산이 근거 있는 승인 줄만 센다 · 기본 역할(계획 worker · 설계 leader) · 「맞추는 명령」 줄의 꼴. 옛 형식 로드맵은 달라지지 않는다는 한 줄.
- `plugin.json` — 판.

판 번호: `git fetch origin` 뒤 `git show origin/main:plugins/spec-distill/.claude-plugin/plugin.json` 의 판 다음 minor 다. 기본 브랜치가 그 사이 올랐으면 `git merge origin/main` 으로 먼저 합치고(충돌 목록에 `plugin.json` 이 없어도 `git diff origin/main -- plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md` 로 직접 견준다) 그 위의 다음 minor 로 한다.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_docs.py 2>&1 | tail -3; bash shared/tests/test_changelog_integrity.sh | tail -1; bash shared/tests/test_no_new_duplication.sh | tail -1; python3 -m unittest plugins/quality-gates/tests/test_utf8_explicit.py 2>&1 | tail -1`
Expected: `OK` · 실패 0 · 실패 0 · `OK`

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/references/team-files.md plugins/spec-distill/README.md plugins/spec-distill/CHANGELOG.md plugins/spec-distill/dependencies.md plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/tests/test_team_docs.py
git commit -m "docs(spec-distill): 사람 줄 · 관문 · human_gate 를 문서에 적고 판을 올린다"
```

- [ ] **Step 6: 전체 스위트**

Global Constraints 의 잠금 줄 그대로 돈다. 못 잡으면 주인 · 잡은 시각을 보고한다. `FAILED` 줄마다 이 브랜치의 변경과 닿는지 적는다 — worktree 에서만 나는 기존 실패는 그렇다고 적는다. 이 브랜치에만 있는 실패가 0 이 될 때까지 그 과제의 뜻 안에서 고친다(pathspec 커밋). 기본 브랜치와의 대조는 지휘자의 머지 전 확인이 한다.

---

## 실행 방식의 마지막 전체 리뷰

고른 실행 방식의 마지막 전체 리뷰(subagent-driven 의 브랜치 전체 리뷰 · native 의 마지막 리뷰)의 리뷰어에게 아래를 그대로 싣는다.

- 설계문서 `## Acceptance Criteria` 의 AC 목록 원문과 이 계획의 `## AC 가르기` 표.
- 요청: 계획 1 몫 AC(`AC3~AC16 · AC20~AC23`)마다 한 줄씩 `AC<n>: <구현됨|미룸|빠짐> — <근거(파일:줄 · 테스트 이름 · 명령 결과)>` 꼴로 보고하라. 걸친 AC(AC9 · AC15 · AC16 · AC20 · AC21 · AC22 · AC23)는 계획 1 이 하는 부분이 다 됐으면 `미룸 — 계획 1 몫은 구현됨(<근거>) · 남은 부분은 계획 2` 로 적는다.
- 요청: 설계문서 `## 있는 것 검토` 가 고른 것을 실제로 썼는지, 같은 것을 다시 만들지 않았는지 줄마다 답하라 — R1 의 받음 줄 판정 방식(`job_results.receipt`)과 나란히 읽히는가 · `conductor_ledger.py record` 의 쓰는 자리가 하나로 남았는가 · 시작 묶음과 결과 대조의 멈추는 길(종료 코드 1 · 빈 출력 · 받음 줄 없음)을 그대로 썼는가 · `tools/plain-language/` 의 읽는 규칙(질문 창 입력 풀기 · 겹친 항목 거르기)을 새 모듈이 가져왔는가 · 훅을 만들지 않았는가.
- 끝에서 끝 흐름 다섯을 따로 물어라 — 각 이음매의 종료 코드 소비와 상태 가정: ① 설계 커밋 → `ask-head` → 질문 창 답 → `record --human` → 커밋 → 시작 묶음 ② 구현 결과 → `job_results.py check` → 받음 줄 → 단계 계산 ③ 승인 뒤 본문 고침 → 단계 계산 「설계 중」 · 묶음 멈춤 · `human-check` 의 `낡음` 이 같은 판정에서 나오는가 ④ `human_gate: 끔` → 옛 인자가 열림 · 관문이 줄의 유무만 봄 · 알림이 도는 과제마다(설계 흐름 · 설계 없는 흐름 · 로드맵 밖 과제) ⑤ 구현 실패 둘 → 멈춤 → 손으로 쓴 받음 줄로는 풀리지 않음 → 질문 창의 「다시 시도한다」 로만 풀림.
- 요청: 모델이 적은 글만으로 열리는 관문이 남아 있는지 따로 답하라 — 받음 줄 · 날짜 · 관문 이름 · 머리 · 근거 칸을 손으로 적거나 고쳐서 시작 묶음 · 결과 대조 · 연속 실패 멈춤 · `human-check` 를 지나는 길. 설계 Constraints 가 「막지 못한다」 로 적은 넷은 빼고 답한다.
- 요청: 상태 계산의 잠금 목록(`tests/test_roadmap_status.sh` 의 정적 검사)에 든 스크립트가 새 모듈 둘을 가져오는 줄과 `control_plane.py` 의 `CODE_STAMP_FILES` 가 맞는지 본다.
- 이 계획이 쓴 테스트 코드(과제 1 · 2 · 5 · 6 의 파이썬 테스트와 과제 7 · 9 · 10 · 11 의 표)는 계획이 정한 것이라는 표시를 붙여, 덜 보지 말고 같은 눈으로 보라고 적는다. 기존 테스트를 옮긴 곳(과제 8 · 9 · 11 의 Step 4)에서 단언이 지워지거나 느슨해지지 않았는지 `git diff origin/main -- plugins/spec-distill/tests` 로 보라고 적는다.
- 개인 정보: `tests/fixtures/session-record/` 와 `dependencies.md` 에 대화 내용 · 경로 속 이름 · 이메일이 없는지 보라고 적는다.

리뷰 보고는 git 이 추적하지 않는 파일에 적는다 — 지휘자가 준 임시 폴더의 `r2-plan1-ac-report.md`(없으면 상태 루트 `python3 plugins/spec-distill/scripts/state_path.py state-root` 가 내는 폴더 아래 같은 이름). 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올린다 — 올릴 행을 보고에 적고 지휘자가 올린다(걸친 AC 의 받는 곳은 R2 다). PR 을 만들기 전에

`python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.19.2"/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-18-conductor-walk-gates-design.md <보고 파일 경로> --acs "AC3~AC16 · AC20~AC23"`

을 돌려 경고를 사용자에게 보인다. PR 본문에는 J21(두 계획 사이의 역할 문서) · J11(더한 갈래로 멈출 때 상태 보기는 머지로 세지 못한다) · 아래 「재지 못함」 · 기존 테스트를 옮긴 목록을 적는다.

## 측정 값을 받으면(J26)

지휘자가 따로 재는 것 — 질문 창이 사람 없이 답을 내는 길(헤드리스 · 권한 모드 · 훅)과 모델이 `answers` 를 스스로 채우는 길. 값(그 길의 답 항목에 남는 `permissionDecision` 의 `decision` · `source` 와 `entrypoint`, 또는 「그 길로는 답 항목이 생기지 않는다」)을 받으면 아래 다섯 자리에만 반영한다. 받는 때가 구현 중이든 뒤든 같다.

| # | 자리 | 무엇을 |
|---|---|---|
| 1 | `scripts/session_record.py` 의 `HUMAN_SOURCES` | 사람이 고른 답에 남는다고 잰 출처 값(지금 `user_temporary` 하나) |
| 2 | `scripts/session_record.py` 의 `NOT_HUMAN_SOURCES` | 사람 없이 나온 답에 남는다고 잰 출처 값(지금 비었다). 여기 든 값은 「어긋남」, 두 목록 어디에도 없는 값은 「확인 못 함」 이다 |
| 3 | `tests/fixtures/session-record/not-human-<길>.jsonl` 과 `tests/test_session_record.py` 의 `test_measured_sources_go_to_the_two_lists` | 그 길의 답 항목을 개인 정보를 지워 자료로 넣고(과제 1 의 규칙 · 락), 그 자료를 읽으면 `who` 가 `NOT_HUMAN` 이라는 단언 한 줄 |
| 4 | `dependencies.md` 의 `## 세션 기록` 절 | 길마다 잰 값과 잰 Claude Code 의 판 |
| 5 | 이 계획의 「재지 못함」 첫 줄 | 잰 길을 지운다 |

값이 **사람 답과 같은 값**(`decision: accept` · `source: user_temporary`)이면 다섯 자리에 반영하지 않고 멈춘다 — 허용 목록으로는 가를 수 없다. 설계 Constraints 의 「막지 못한다」 목록과 Verification Plan 의 문장에 닿으므로 지휘자와 사용자가 정한다(다른 칸으로 가를 수 있는지 — 예: `entrypoint` — 도 그때 정한다).

## 재지 못함

- **질문 창이 사람 없이 답을 내는 길**(헤드리스 · 권한 모드 · 훅 · 모델이 `answers` 를 스스로 채우는 길 · 다른 세션의 키 입력) — 구현 담당은 Claude Code 를 다시 띄우지 않는다(J26). 앞의 넷은 지휘자가 따로 재고 있고 값은 「측정 값을 받으면」 의 다섯 자리에 반영한다. 받기 전에는 사람 답의 허용 목록(`permissionDecision` 의 `decision: accept` · `source: user_temporary`)으로 가고 모르는 출처는 「확인 못 함」 이다. 다른 세션의 키 입력은 터미널에 글쇠가 들어가는 것이라 기록에서 사람 답과 갈리지 않을 수 있다 — 그렇다면 설계 Constraints 의 「막지 못한다」 목록에 닿는다.
- **`record --human` 을 부른 호출이 그때 기록에 쓰여 있는지**(`eac92f65`) — 같은 이유. 동작에는 쓰지 않는다.
- **설치본에서의 한 번** — 진짜 지휘 세션에서 질문 창으로 승인하고 `record --human` 이 그 답을 찾는지는 team 형식 로드맵이 도는 때(E1 이 새 형식을 켠 뒤)에 처음 실제로 돈다. PR 본문에 손으로 한 번 확인하는 법을 적는다 — 임시 레포에 team 형식 로드맵을 만들고(`roadmap_write.py create --layout team`), 지휘 세션에서 `ask-head` 의 머리로 질문 창을 띄워 답한 뒤 `record --human` 을 부른다.
