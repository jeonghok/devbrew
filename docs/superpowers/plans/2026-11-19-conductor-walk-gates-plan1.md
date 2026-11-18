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
- **사람 줄 꼴.** `- <종류> · <YYYY-MM-DD> · 「<라벨>」 · <파일>@<판> · 근거 <세션>:<항목>`. `걸음 건너뜀` 은 라벨 뒤에 ` · <관문 이름>` 이 하나 더 온다. 판은 커밋 번호의 앞 8자다.
- **관문 표(스크립트 상수).** `design` → 없음 · `plan` → `spec 승인` · `implement` · `review`(계획 n) → `spec 승인` · `계획 검토`(계획 n) · 설계 없는 흐름의 과제(어느 단계든) → `흐름 승인`. 걸음표나 설정에서 읽지 않는다.
- **연속 실패 멈춤 수는 2 로 고정한다.** 설정 키를 두지 않는다.
- **`human_gate`.** 레포 설정 파일(`.devbrew.md`)의 키다. 값은 `켬`(기본) · `끔` 둘이다. 환경 변수로는 꺼지지 않는다. 로드맵 머리말에서는 받지 않는다.
- **종료 코드.** 시작 묶음 · 결과 대조: 관문을 지나지 못하면 1(「확인 못 함」 도 1). `record --human` · `ask-head`: 0 · 1(쓸 답이 없다 · 통과 라벨이 아니다 · 커밋되지 않았다 · 다른 브랜치다) · 2(사용법) · 3(「확인 못 함」 — 세션 기록을 찾지 못함 · 읽지 못함 · 아는 칸 없음 · 표지 없음).
- **세션 기록은 읽기만 한다.** Claude 설정 폴더는 환경 변수 `CLAUDE_CONFIG_DIR` 이 있으면 그 값, 없으면 홈의 `.claude` 다. 테스트는 늘 `CLAUDE_CONFIG_DIR` 를 임시 폴더로 준다 — 실제 설정 폴더를 읽는 테스트를 쓰지 않는다.
- **개인 정보.** 세션 기록에서 추적 파일 · 보고 · 커밋 메시지로 옮기는 것은 칸 이름과 꼴(값의 종류 · 고정 낱말)뿐이다. 대화 내용 · 이메일 · 경로 속 이름 · secret 은 옮기지 않는다. 자료 파일의 글자 값은 자리표시 글자로 바꾼다(과제 1 의 락이 잰다).
- **import 방향.** `session_record` 는 표준 라이브러리만. `human_lines` 는 `session_record` · `team_files` · `team_layout` 을 가져온다. `team_files` · `team_layout` 은 `human_lines` 를 가져오지 않는다. `team_status` · `job_results` · `start_bundle` · `conductor_ledger` 가 `human_lines` 를 가져온다(`job_results` 는 `team_status` 처럼 `roadmap_status` 를 함수 안에서 가져온다).
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
| J2 | 사람이 답했는지 가르는 칸 | 답 항목의 `permissionDecision` 이다 — `decision` 이 `accept` 이고 `source` 가 허용 목록(`user_temporary`)에 있으면 사람, 칸이 없으면 「아는 칸 없음」(확인 못 함), 그 밖은 사람 아님 | 계획을 쓸 때 잰 답 592건(2.1.296 – 2.1.326)이 모두 이 꼴이었다. 설계가 든 `turnOrigin` · `origin.kind` 는 사람이 친 말(프롬프트 항목)의 칸이고 답 항목에는 없다 | 답 항목이 속한 턴의 `turnOrigin` 을 거슬러 찾기 |
| J3 | 이어받은 세션 | 기록 파일은 이름으로 찾고, 항목 안의 `sessionId` 는 대조하지 않는다. 같은 답인지는 `uuid#순번` 으로만 가른다(세션이 달라도 같은 답이다) | 계획을 쓸 때 세션 파일 643개에서 파일 이름과 다른 `sessionId` 는 없었지만 설계의 Handoff 는 다를 수 있다고 적었다 — 어느 쪽이어도 맞게 | `sessionId` 가 파일 이름과 다르면 「어긋남」 |
| J4 | 본문을 견줄 때의 다듬기 | 뺄 절을 뺀 뒤 끝의 빈 줄만 뗀다. 줄 안의 글자는 그대로 견준다 | 기록 절을 빼면 끝의 빈 줄 수가 달라진다 | 줄 끝 공백도 떼기 |
| J5 | 「본문을 마지막으로 바꾼 커밋」 을 찾는 법 | 그 브랜치 끝에서 그 파일을 건드린 커밋을 새것부터 보며, 본문이 끝의 본문과 같은 동안 거슬러 올라간 가장 오래된 커밋 | 승인 게이트가 기록 절만 고친 커밋은 판을 바꾸지 않아야 한다 | 그 파일을 마지막으로 건드린 커밋 |
| J6 | `ask-head` · `record --human` 을 부르는 자리 | 쓸 브랜치를 체크아웃한 worktree 에서 부른다(`--root` 로 줄 수 있다). 지금 브랜치가 쓸 브랜치가 아니면 쓰지 않고 1 로 멈춘다 | AC7 「시작 묶음이 읽는 브랜치 끝의 INTENT.md 에 쓴다」 를 작업 폴더에 쓰는 명령이 지키는 길이 이것뿐이다 | 경로 인자(`--spec`)를 받는다 |
| J7 | 쓸 브랜치 | `계획 검토`(계획 n) → 블록의 n 번째 브랜치. `spec 승인` · `흐름 승인` → 아직 머지되지 않은 가장 앞 브랜치. `걸음 건너뜀` → 관문 이름에 계획 번호가 있으면 그 계획의 브랜치, 없으면 아직 머지되지 않은 가장 앞 브랜치. 로드맵 밖 과제는 INTENT.md 머리의 `branch` | 설계 §2 「쓰는 곳과 때」 를 건너뜀 줄과 로드맵 밖 과제까지 넓혔다 | — |
| J8 | 건너뛸 관문을 주는 인자와 이름 | `--gate "<관문 이름>"`. 이름은 `spec 승인` · `계획 검토 plan <n>` · `다시 시도 plan <n> 시도 <k>` 이고, 설계 없는 흐름(계획 번호가 없다)의 다시 시도는 `다시 시도 시도 <k>` 다. 「건너뛴다」 는 앞의 둘, 「다시 시도한다」 는 뒤의 둘에만 맞는다 | 설계 없는 흐름의 구현에도 받음 줄이 있어 연속 실패가 세어지는데 설계는 계획 번호 있는 이름만 적었다 | 설계 없는 흐름에는 연속 실패 멈춤을 두지 않는다 |
| J9 | `human_gate: 끔` 일 때 「줄이 있다」 | 그 종류의 줄이 그 과제의 결정 기록에 하나라도 있으면 지난 것이다(`계획 검토` 는 계획 번호를 가리지 않는다). `걸음 건너뜀` 은 관문 이름이 글자 그대로 든 줄이다. `spec 승인` 은 옛 형식과 같은 읽기 규칙(`approval_in`)이다 | 설계 §8 「관문은 줄이 있는지만 본다」. 글로 적은 줄에는 정해진 칸이 없다 | 글로 적은 줄에도 계획 번호 칸을 요구한다 |
| J10 | 꺼져 있다는 알림이 실리는 자리 | 상태 보기는 그 블록의 첫 `정보:` 줄, 시작 묶음은 첫 `알림:` 줄, 결과 대조는 첫 줄 바로 아래 `알림:` 줄이다. 글자는 「사람 줄 대조가 꺼져 있다」 | 설계는 「상태 보기 스크립트는 고치지 않는다」 고 했고 그 스크립트가 단계 계산에서 받아 보이는 것은 블록의 알림 줄뿐이다 | 상태 보기 스크립트를 고쳐 출력 맨 위에 한 줄 |
| J11 | 머지된 계획을 아는 길(브랜치를 지운 뒤에도) | 상태 보기와 같은 머지 판정(머지 커밋 · PR 캐시 · 머지 메시지)을 쓰고, 여기에 하나를 더한다 — 그 브랜치의 끝이 로컬에도 origin 에도 없는데 기본 브랜치에 그 계획 파일(설계 없는 흐름은 `implement` 결과 파일)이 있으면 머지된 것이다. `team_status.plan_merged` 한 곳에 둔다(계획 2 의 「계획 n/m」 이 같은 함수를 쓴다) | Handoff 가 계획에 넘겼다. 계획 파일은 그 계획의 브랜치에서만 생기므로(브랜치 하나에 계획 하나) 브랜치 없이 기본 브랜치에 있으면 머지돼 지워진 것이다. GitHub 가 아닌 origin 에서도 선다 | PR 캐시에만 기댄다 |
| J12 | 연속 실패에서 「받은 시도」 | 그 결과 파일의 이름과 `head` 를 가리키는 꼴 맞는 받음 줄이 결정 기록에 있다. 받은 뒤 바뀜(낡음)은 여기서 재지 않는다. 「끝」 줄이 없는 시도 · 읽지 못한 시도는 실패로 세지 않고 이어짐을 끊는다 | R1 의 받음 줄 다시 세기는 가장 새 시도만 잰다 — 앞 시도는 「더 새 시도가 있다」 로 늘 낡음이 된다 | 앞 시도도 받음 줄 다시 세기로 잰다 |
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
| J24 | `human-check` 의 종료 코드 | 0 모두 「지남」(사람 줄이 하나도 없어도 0 — 「사람 줄 없음」 한 줄) · 1 하나라도 지나지 못함 · 2 사용법 · 3 로드맵 · 레포를 읽지 못함 | AC23 은 줄마다 판정을 낸다고만 한다 | 늘 0 |
| J25 | 테스트가 사람 줄을 만드는 길 | 손으로 줄을 적지 않는다. 자료에서 만든 가짜 세션 기록(`tests/fixtures/session_fixture.py`)과 `ask-head` · `record --human` 을 실제로 부르는 도우미(`tests/fixtures/team_repo.sh` 의 `human`)로 만든다 | 관문 아래에서는 손으로 적은 승인 줄이 「근거 없음」 이다. R1 의 team 테스트가 계획 · 구현 묶음을 받으려면 진짜 꼴의 줄이 필요하다 | 테스트 레포를 `human_gate: 끔` 으로 |
| J26 | 사람 없이 답이 나오는 길의 측정 | 구현 담당은 Claude Code 를 다시 띄우지 않는다. 읽기 전용으로 잴 수 있는 것만 재고, 네 길(헤드리스 · 권한 모드 · 훅 · 다른 세션의 키 입력)의 측정 값은 지휘자가 보낸 글로 받는다. 받지 못하면 허용 목록(J2)으로 가고 「재지 못함」 에 적는다 | 앞 로드맵의 계획이 같은 제약을 뒀다. 허용 목록은 모르는 값을 사람 아님으로 본다 | 구현 담당이 `claude -p` 로 잰다 |
| J27 | `started()` 가 쓰는 승인 읽기 | 그대로 둔다(`Reader.approved`) | 그 함수는 관문이 아니라 「지워진 브랜치인가 아직 만들지 않은 브랜치인가」 를 가르는 흔적이다 | 꼴 판정으로 바꾼다 |

**`### Deferred to plan` 확인.** 표의 항목을 Handoff 가 말한 둘로 갈랐다. 장치를 빼서 해당 없는 것 — `964aa074`(물음 옮기기 대조) · `56f7a2b9`(PR 전 확인 줄) · `f29944a4`(연속 실패 설정 키) · `0764aeb1` · `a94449da`(옛 형식 검사) · `68f5b017` 의 옮긴 물음 부분. 계획 1 이 받는 것 — `2e6610eb`(훅 · 키 입력을 측정 목록에 → 과제 1 · J26) · `eac92f65`(부른 세션을 기록으로 증명하는 길이 되는지 → 과제 1 이 재서 보고만 한다. 동작은 더하지 않는다) · `d0120803#r4.1`(머지된 계획을 아는 길 → J11). 그 밖은 설계 본문에 반영돼 있고 계획 1 의 과제가 그 본문을 따른다(`4e9c6b95` → 과제 7 의 커밋 검사 · `d0120803#r2.1` → 과제 11 · `a7e7e856` · `dd52ae68` → 과제 4 · `abcf8f1a` → Global Constraints · `226040f3` · `0dad47c7`(막힘은 세지 않는다) → 과제 10 · `f5a6cb16` · `71edd879` → J9 · `4c69520b` → 과제 6). 걸음표 · 원문 대조 · 번호 대조에 관한 항목(`16e0e602` · `52cb7c7a` · `17563e51` · `a86f8ade` · `fccf272b` · `7c2453be` · `a231cc98` · `9665f71d` · `e1b5b3be`)은 본문에 반영됐고 계획 1 에 닿는 코드가 없다.

## 파일 표

| 파일 | 과제 | 하는 일 |
|---|---|---|
| `tests/fixtures/session-record/*.jsonl` (새로) · `tests/fixtures/session_fixture.py` (새로) · `tests/test_session_fixture.py` (새로) | 1 | 개인 정보를 지운 세션 기록 자료 · 그 자료로 가짜 기록을 짓는 도우미 · 자료의 락 |
| `scripts/session_record.py` (새로) · `tests/test_session_record.py` (새로) | 2 | 세션 기록 찾기 · 질문 창 답 읽기 |
| `scripts/repo_defaults.py` · `scripts/team_files.py` · `tests/test_repo_defaults.py` · `tests/test_team_results.py` · `tests/test_roadmap_model.py` | 3 | `human_gate` 키 · 결정 줄 종류 둘 · 승인 줄 읽기 테스트(J14) |
| `scripts/team_layout.py` · `scripts/start_bundle.py` · `tests/test_team_layout.py` · `tests/test_start_bundle.sh` | 4 | 기본 역할 · 설계 단계의 leader 역할 |
| `scripts/human_lines.py` (새로) · `tests/test_human_lines.py` (새로) · `tests/test_human_judge.sh` (새로) | 5 · 6 | 줄 꼴 · 본문 · 판 · 꼴 판정 · 대조 판정 · 관문 표 |
| `scripts/conductor_ledger.py` · `tests/fixtures/team_repo.sh` · `tests/test_human_record.sh` (새로) | 7 · 11 | `ask-head` · `record --human` · 옛 인자 막기 · `human-check` · 테스트 도우미 |
| `scripts/team_status.py` · `tests/test_team_status.sh` 와 team 형식 셸 테스트 | 8 | 꼴 판정을 지난 승인 줄만 세기 · 건너뜀 줄 · 꺼짐 알림 |
| `scripts/start_bundle.py` · `scripts/job_results.py` · `tests/test_human_gate.sh` (새로) · `tests/test_start_bundle.sh` · `tests/test_team_sync.sh` | 9 · 10 | 관문 확인 · 머지된 계획 멈춤 · 연속 실패 멈춤 · 맞추는 명령 줄 |
| `scripts/job_results.py` · `tests/test_job_results.sh` 와 결과 대조를 부르는 셸 테스트 | 11 | 결과 대조의 관문 확인 |
| `tests/test_human_gate_e2e.sh` (새로) | 12 | 끝에서 끝 · 지어낸 줄 · 옛 형식 · 변이 |
| `references/team-files.md` · `README.md` · `CHANGELOG.md` · `dependencies.md` · `.claude-plugin/plugin.json` · `tests/test_team_docs.py` | 3 · 4 · 13 | 문서와 판 |

고치지 않는 것: `scripts/roadmap_status.py` · `scripts/control_plane.py`(설계 §8) · `scripts/roadmap_model.py`(J14) · `references/conducting.md` · `references/conductor-dispatch.md` · `references/proceed-gate.md` · `skills/epic-conductor/SKILL.md` · `templates/team/` · 역할 문서 사본 · 철학 문서 · `CLAUDE.md`(모두 계획 2).

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
  - `add_answer(config_dir, session, questions, who="human", sidechain=False, subagent=False, entry=None, project="fixture") -> str` — `questions` 는 `[(질문 글, 고른 글), …]`. 호출 항목과 답 항목 두 줄을 그 세션 기록에 덧붙이고(파일 · 폴더가 없으면 만든다) 답 항목의 `uuid` 를 돌려준다. `who` 는 `"human"`(자료 그대로) · `"unknown"`(답 항목에서 `permissionDecision` 칸을 뺀다) · `"other"`(`permissionDecision.source` 를 `fixture_other` 로 바꾼다). `sidechain=True` 면 두 항목의 `isSidechain` 이 참이다. `subagent=True` 면 `<config_dir>/projects/<project>/<session>/subagents/agent-fixture.jsonl` 에 쓴다. `entry` 를 주면 답 항목의 `uuid` 가 그 값이다
  - `add_lines(config_dir, session, name, project="fixture") -> None` — 자료 파일 `session-record/<name>.jsonl` 의 줄을 그대로 덧붙인다
  - 명령줄: `session_fixture.py answer --config <폴더> --session <세션> --question <글> --label <글> [--question <글> --label <글> …] [--who human|unknown|other] [--entry <uuid>]` → 답 항목의 `uuid` 한 줄 · `session_fixture.py lines --config <폴더> --session <세션> --name <자료 이름>` → `add_lines` 와 같다

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

구현 담당은 Claude Code 를 다시 띄우지 않는다. 지휘자가 보낸 글에 아래 다섯 줄의 측정 값이 있으면 그 값으로 간다.

| 길 | 받을 값 |
|---|---|
| 헤드리스(`-p` · SDK) | 질문 창 호출이 되는가. 되면 답 항목의 `permissionDecision` · `entrypoint` 값 |
| 권한 모드(자동 · 묻지 않음) | 질문 창이 사람을 기다리지 않고 답을 내는가. 내면 답 항목의 `permissionDecision` 값 |
| 훅(`PreToolUse` 가 질문 창의 답을 채움) | 답 항목의 `permissionDecision` 값 |
| 다른 세션의 키 입력 | 답 항목의 `permissionDecision` 값 |
| `record --human` 을 부른 Bash 호출 항목 | 명령이 도는 때에 그 호출 항목이 기록 파일에 이미 쓰여 있는가(보고만 — 동작을 더하지 않는다) |

값마다 이렇게 한다.

- 그 길의 답이 허용 목록(`decision: accept` · `source: user_temporary`) 밖의 값으로 남는다 → 그 꼴을 자료 `not-human-<길>.jsonl` 로 더하고, 과제 2 의 `test_not_human_sources` 에 그 값을 한 줄 더한다.
- 그 길의 답이 사람 답과 **같은 값**으로 남는다 → 멈추고 지휘자에게 돌려보낸다. 설계 Constraints 의 「막지 못한다」 목록과 Verification Plan 의 문장에 닿는다 — 구현 담당이 정하지 않는다.
- 값을 받지 못했다 → 허용 목록 그대로 가고, 이 계획 끝 「재지 못함」 의 그 줄을 과제 보고에 그대로 옮긴다.

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

과제 보고에 적는다 — 「다시 확인 — 설계 · 계획과 같다」(또는 달랐던 줄), Step 2 에서 다시 잰 판의 범위, Step 3 의 다섯 줄마다 받은 값 또는 「재지 못함」.

---

### Task 2: 세션 기록 읽기(`session_record.py`)

**AC:** AC5(주 대화 · 질문 창 결과 · 질문마다 따로) · AC6(찾지 못함 · 읽지 못함 · 아는 칸 없음)

**Files:**
- Create: `plugins/spec-distill/scripts/session_record.py`
- Test: `plugins/spec-distill/tests/test_session_record.py`

**Interfaces:**
- Consumes: 과제 1 의 `session_fixture`(테스트만).
- Produces:
  - `TOOL = "AskUserQuestion"` · `HUMAN_SOURCES = ("user_temporary",)` · `HUMAN, NOT_HUMAN, UNKNOWN = "사람", "사람 아님", "알 수 없음"`
  - `class Unreadable(Exception)` — 「확인 못 함」 의 사유(`str(exc)` 가 한 줄 한국어)
  - `class Answer(NamedTuple)` — `session: str`(파일 이름의 세션 번호) · `entry: str`(답 항목의 `uuid`) · `index: int`(그 호출 안 질문의 순번, 1부터) · `question: str`(호출 항목의 질문 글) · `label: str`(고른 글자 그대로) · `who: str`. `key` 속성은 `"%s#%d" % (entry, index)`
  - `config_dir(environ=None) -> pathlib.Path` — `CLAUDE_CONFIG_DIR` 이 비지 않았으면 그 값, 아니면 `Path.home() / ".claude"`
  - `locate(session: str, environ=None) -> pathlib.Path` — `<설정 폴더>/projects/*/<session>.jsonl` 이 정확히 하나면 그 경로. 세션 번호 꼴(`[A-Za-z0-9_-]{8,}` — `state_path.SESSION_PATTERN` 과 같은 글자)이 아니거나 없거나 둘 이상이면 `Unreadable`
  - `answers(path) -> list` — 그 파일의 주 대화 질문 창 답들(파일 차례). 읽은 JSON 줄이 하나도 없으면 `Unreadable`
  - `find(path, key: str) -> Optional[Answer]` — `key` 가 `<uuid>#<n>` 인 답

읽는 규칙(과제 1 의 표):

- 줄마다 JSON 객체 하나다. JSON 이 아닌 줄(반만 쓰인 마지막 줄 포함)은 건너뛴다. `"AskUserQuestion"` 이나 `"tool_result"` 글자가 없는 줄은 JSON 으로 풀지 않는다(큰 기록).
- 호출: `type` 이 `assistant` 이고 `isSidechain` 이 `False` 인 항목의 `message.content` 블록 가운데 `type: tool_use` · `name: AskUserQuestion`. `input.questions` 가 목록이고 질문마다 `question` 이 글자여야 한다 — 아니면 그 호출은 쓰지 않는다. 같은 호출 안에 질문 글이 같은 것이 둘이면 그 호출은 쓰지 않는다.
- 답: `type` 이 `user` 이고 `isSidechain` 이 `False` 인 항목의 `tool_result` 블록 가운데 `tool_use_id` 가 **같은 파일에서 앞서 읽은** 호출의 `id` 이고, 항목의 `sourceToolAssistantUUID` 가 그 호출 항목의 `uuid` 이고, `is_error` 가 참이 아니고, `toolUseResult` 가 사전이고 그 `answers` 가 사전인 것. 질문마다 `answers[질문 글]` 이 글자면 `Answer` 하나다(없으면 그 질문은 건너뛴다).
- `who`: 답 항목에 `permissionDecision` 칸이 없으면 `UNKNOWN`. 사전이고 `decision == "accept"` 이고 `source` 가 `HUMAN_SOURCES` 에 있으면 `HUMAN`. 그 밖은 `NOT_HUMAN`.

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
        self.assertEqual(got, [R.Answer(SID, uid, 1, "R2 @0123abcd — 질문", "승인 — 계획 담당자에게 (권장)", R.HUMAN)])
        self.assertEqual(got[0].key, uid + "#1")
        self.assertEqual(R.find(SF.record_path(d, SID), uid + "#1"), got[0])
        for key in (uid + "#2", uid, "x#1", uid + "#0", uid + "#1\n"):
            self.assertIsNone(R.find(SF.record_path(d, SID), key), key)

    def test_each_question_of_one_call_has_its_own_label(self):
        uid = SF.add_answer(d, SID, [("첫 질문", "가"), ("둘째 질문", "나")])
        self.assertEqual([(a.index, a.question, a.label) for a in R.answers(SF.record_path(d, SID))],
                         [(1, "첫 질문", "가"), (2, "둘째 질문", "나")])

    def test_who(self):
        SF.add_answer(d, SID, [("q1", "a")], who="unknown")
        SF.add_answer(d, SID, [("q2", "a")], who="other")
        SF.add_answer(d, SID, [("q3", "a")])
        self.assertEqual([a.who for a in R.answers(SF.record_path(d, SID))], [R.UNKNOWN, R.NOT_HUMAN, R.HUMAN])

    def test_not_human_sources(self):   # 과제 1 Step 3 이 값을 받으면 여기에 한 줄씩 더한다
        for decision, source in (("accept", "fixture_other"), ("reject", "user_reject"), ("accept", ""), ("allow", "user_temporary")):
            ...  # 답 항목의 permissionDecision 을 이 값으로 바꾼 기록 → who 가 NOT_HUMAN

    def test_what_is_not_an_answer(self):
        for name in ("rejected", "typed", "peer", "notification"):
            SF.add_lines(d, SID, name)
        SF.add_answer(d, SID, [("곁가지 질문", "a")], sidechain=True)
        SF.add_answer(d, SID, [("같은 글", "a"), ("같은 글", "b")])
        self.assertEqual(R.answers(SF.record_path(d, SID)), [])

    def test_pairing_is_checked(self):
        # ① 답 항목의 tool_use_id 가 없는 호출을 가리킨다 ② sourceToolAssistantUUID 가 호출 항목의 uuid 와 다르다
        # ③ 호출의 name 이 AskUserQuestion 이 아니다 ④ toolUseResult 가 글자다 ⑤ 답 항목이 호출 항목보다 앞 줄에 있다
        ...  # 다섯 변형 각각 answers() == []; 변형하지 않은 기록은 답 하나(양성 대조)

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

`...` 로 적은 두 테스트는 기록 파일을 읽어 그 항목의 칸을 바꿔 다시 쓰는 도우미 `rewrite(path, line_no, change)` 를 테스트 파일 안에 두고 주석이 적은 변형을 그대로 만든다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_session_record.py`
Expected: `ModuleNotFoundError: No module named 'session_record'`

- [ ] **Step 3: `session_record.py` 를 쓴다**

위 Interfaces 와 읽는 규칙대로 쓴다. 표준 라이브러리만 가져온다. 파일은 `encoding="utf-8", errors="replace"` 로 한 줄씩 읽는다. 읽지 못한 파일(`OSError`)은 `Unreadable("세션 기록을 읽지 못했다: <파일 이름> — <사유>")` — 사유 글에 설정 폴더의 온 경로를 넣지 않는다(파일 이름까지만).

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

`tests/test_repo_defaults.py` 에 더한다(그 파일의 `merge_layers` 를 부르는 기존 테스트와 같은 방식):

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

    def test_environment_does_not_turn_it_off(self):   # 양성 대조는 test_off_only_by_the_exact_word
        names = ("DEVBREW_SPEC_DISTILL_HUMAN_GATE", "DEVBREW_HUMAN_GATE", "DEVBREW_SPEC_DISTILL_DISABLE_HUMAN_GATE", "HUMAN_GATE")
        for word in ("끔", "1"):
            with mock.patch.dict(os.environ, dict.fromkeys(names, word)):
                self.assertTrue(D.gate_on(self.merged()["values"]), word)
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
  - `head(job: str, rev: str) -> str` — `"%s @%s" % (job, rev)` · `starts_with_head(question, job, rev) -> bool` — 질문 글이 머리로 **시작하고** 머리 바로 뒤 글자가 16진 글자(`0-9a-f`)가 아니다
  - `bound_name(kind, plan=None) -> str` · `gate_name(kind, plan=None) -> str`(`spec 승인` · `계획 검토 plan <n>`) · `retry_name(plan, attempt) -> str`(`다시 시도 plan <n> 시도 <k>` · 계획이 `None` 이면 `다시 시도 시도 <k>`)
  - `body_of(name: str, text: str) -> str` — `name` 은 파일 이름(경로의 마지막 조각)
  - `version(git, tip: str, path: str) -> Optional[str]` — J5. 그 끝에 파일이 없으면 `None`
  - `shape(scope: Scope, raw: str) -> Verdict` — 꼴 판정. 세션 기록을 읽지 않는다

줄 꼴(`parse` 가 받는 것 — 하나라도 어긋나면 `None`):

- `team_files.decision_problem(raw)` 가 `None` 이다(한 줄 · 있는 날짜).
- `- <종류> · <날짜> · 「<라벨>」[ · <관문 이름>] · <파일>@<판> · 근거 <세션>:<uuid>#<순번>` 이고 그 뒤에 글자가 없다. 판은 `[0-9a-f]{8}`, 세션은 `[A-Za-z0-9_-]{8,}`, uuid 는 `[0-9a-f-]{36}`, 순번은 0 으로 시작하지 않는 1 이상의 수다.
- 라벨이 그 종류의 `PASS_LABELS` 가운데 하나다(꼬리 `(권장)` 이 남은 글자는 아니다).
- 파일이 종류와 맞는다 — `spec 승인` 은 `design.md`, `계획 검토` 는 `plan-<n>.md`(n 은 1 이상), `흐름 승인` · `걸음 건너뜀` 은 `INTENT.md`.
- 관문 이름 칸은 `걸음 건너뜀` 에만 있고 꼭 있다. 이름은 `spec 승인` · `계획 검토 plan <n>` · `다시 시도 plan <n> 시도 <k>` · `다시 시도 시도 <k>` 이고, 라벨 「건너뛴다」 는 앞의 둘, 「다시 시도한다」 는 뒤의 둘과만 짝이다.

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
        self.assertEqual(H.parse(retry.replace("다시 시도 plan 1 시도 3", "다시 시도 시도 3")).plan, None)
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
        self.assertEqual(H.head("R2", "51f1b64d"), "R2 @51f1b64d")
        for q in ("R2 @51f1b64d — 설계를 승인할까요?", "R2 @51f1b64d", "R2 @51f1b64d\n둘째 줄"):
            self.assertTrue(H.starts_with_head(q, "R2", "51f1b64d"), q)
        for q in (" R2 @51f1b64d — 질문", "**R2 @51f1b64d** 질문", "\nR2 @51f1b64d", "R21 @51f1b64d 질문", "R2 @51f1b64d0 질문",
                  "R2 @51F1B64D 질문", "R2  @51f1b64d 질문", "r2 @51f1b64d 질문", "질문 R2 @51f1b64d", ""):
            self.assertFalse(H.starts_with_head(q, "R2", "51f1b64d"), q)
        self.assertEqual([H.bound_name(H.KIND_SPEC), H.bound_name(H.KIND_PLAN, 2), H.bound_name(H.KIND_FLOW), H.bound_name(H.KIND_SKIP)],
                         ["design.md", "plan-2.md", "INTENT.md", "INTENT.md"])
        self.assertEqual([H.gate_name(H.KIND_SPEC), H.gate_name(H.KIND_PLAN, 2), H.retry_name(2, 3), H.retry_name(None, 3)],
                         ["spec 승인", "계획 검토 plan 2", "다시 시도 plan 2 시도 3", "다시 시도 시도 3"])


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

위 Interfaces · 줄 꼴 · 본문 · 꼴 판정 표대로 쓴다. 제목 줄은 정규식이 아니라 `str.startswith` 로 가른다(레포 락). `version` 은 `git.run_err("log", "--format=%H", tip, "--", ":(top,literal)" + path)` 의 커밋들을 새것부터 읽는다 — git 이 실패하면 `git.fail("log", rc, err)` 로 남기고 `None`.

- [ ] **Step 5: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_human_lines.py plugins/spec-distill/tests/test_human_judge.py 2>&1 | tail -3; bash plugins/spec-distill/tests/test_check_brief.sh | tail -1`
Expected: `OK` · 셸 테스트 요약 줄에 실패 0

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/scripts/human_lines.py plugins/spec-distill/tests/test_human_lines.py plugins/spec-distill/tests/test_human_judge.py
git commit -m "feat(spec-distill): 사람 줄의 꼴 · 본문 · 판과 꼴 판정을 더한다"
```

---

### Task 6: 대조 판정과 관문 표(`human_lines.py`)

**AC:** AC5(쓰는 조건) · AC9(관문 표) · AC11 · AC12 · AC20(꺼졌을 때 줄의 유무만)

**Files:**
- Modify: `plugins/spec-distill/scripts/human_lines.py`
- Test: `plugins/spec-distill/tests/test_human_judge.py`

**Interfaces:**
- Consumes: 과제 2 의 `session_record.locate` · `find` · `Unreadable` · `HUMAN` · `UNKNOWN`. 과제 5 의 모든 것. `roadmap_model.approval_in`.
- Produces:
  - `GATES = {"design": (), "plan": (KIND_SPEC,), "implement": (KIND_SPEC, KIND_PLAN), "review": (KIND_SPEC, KIND_PLAN)}` · `PLAIN_GATES = (KIND_FLOW,)` · `RETRY_STOP = 2` · `GATE_OFF = "사람 줄 대조가 꺼져 있다"` · `NO_LINE = "줄이 없다"`
  - `class Passed(NamedTuple)` — `date: str` · `skipped: bool`(건너뜀 줄로 지났다)
  - `match(scope, raw) -> Verdict` — 대조 판정
  - `needed(stage, plan, plain) -> list` — `[(종류, 계획 | None), …]`. 설계 없는 흐름이면 어느 단계든 `[(KIND_FLOW, None)]`, 아니면 `GATES[stage]` 의 차례이고 `KIND_PLAN` 에만 계획 번호가 붙는다
  - `passed(scope, kind, plan, deep: bool) -> tuple` — `(Passed | None, 사유 | None)`. `deep` 이 참이면 대조 판정, 거짓이면 꼴 판정으로 본다
  - `missing(scope, stage, plan, plain, deep) -> list` — 지나지 못한 관문마다 사유 한 줄(관문 표의 차례)
  - `retry_open(scope, plan, attempt, deep) -> bool` — 그 시도를 푸는 산 `걸음 건너뜀` 줄이 있는가
  - `collect(git, team, job, tips) -> tuple` — `(겹침 없는 결정 기록 줄들(튜플 · 처음 나온 차례), 알림 줄들)`. `tips` 의 커밋마다 그 과제 INTENT.md 의 결정 기록 줄을 모은다. 그 커밋에 INTENT.md 가 없으면 건너뛰고, 있는데 결정 기록 칸을 읽지 못하면 건너뛰고 `"<커밋 8자> 의 결정 기록을 읽지 못했다 — <사유>"` 를 알린다

대조 판정(`match`) — 꼴 판정을 먼저 하고 `지남` 이 아니면 그 판정을 그대로 낸다. 그 뒤 위에서부터 처음 걸리는 것:

| 본 것 | 판정 · 사유 |
|---|---|
| `session_record.locate(줄의 세션)` 이 `Unreadable` | `확인 못 함` — `<사유> — 질문 창으로 다시 승인받는다` |
| `find(파일, 줄의 key)` 가 `None`, 또는 읽다가 `Unreadable` | 없으면 `어긋남` — `근거가 가리키는 질문 창 답이 세션 기록에 없다`. 읽지 못하면 `확인 못 함` |
| 답의 `who` 가 `UNKNOWN` | `확인 못 함` — `그 답을 사람이 했는지 가를 칸이 기록에 없다 — 질문 창으로 다시 승인받는다` |
| 답의 `who` 가 `HUMAN` 이 아니다 | `어긋남` — `그 답은 사람이 질문 창에서 고른 것이 아니다` |
| 질문 글이 `head(과제, 줄의 판)` 으로 시작하지 않는다 | `어긋남` — `그 질문은 머리 <머리> 로 시작하지 않는다` |
| `clean_label(답의 글자)` 가 줄의 라벨과 다르다 | `어긋남` — `사람이 고른 라벨은 「<고른 글>」 이다` |
| 건너뜀 줄인데 질문 글에 관문 이름이 글자 그대로 없다 | `어긋남` — `그 질문에 관문 이름 <이름> 이 없다` |
| `scope.lines` 에 글자가 다른 줄이면서 `parse` 되고 `key` 가 같은 줄이 있다 | `어긋남` — `같은 답을 근거로 쓴 줄이 또 있다` |
| 그 밖 | `지남` |

관문 하나(`passed`):

- `scope.gate_on` 이 참이면 — 후보는 `is_human(raw) == kind` 인 줄이다(`KIND_PLAN` 은 `parse` 되면 `plan` 이 같은 줄만, `parse` 되지 않는 줄은 후보로 남는다). 후보 가운데 판정이 `지남` 인 줄이 있으면 `(Passed(그 날짜, False), None)`. 없으면 `KIND_SPEC` · `KIND_PLAN` 은 `parse` 된 `걸음 건너뜀` 줄 가운데 `gate == gate_name(kind, plan)` 이고 판정이 `지남` 인 줄을 찾아 있으면 `(Passed(그 날짜, True), None)`. 그래도 없으면 `(None, 사유)` — 후보가 없으면 `NO_LINE`, 있으면 마지막 후보의 `"%s — %s" % (판정, 사유)`.
- `scope.gate_on` 이 거짓이면(J9) — `KIND_SPEC` 은 `approval_in(scope.lines)` 의 날짜가 있으면 지남, 그 밖의 종류는 `- <종류> · <날짜> · ` 로 시작하는 줄이 있으면 지남(날짜는 그 줄의 것), `KIND_SPEC` · `KIND_PLAN` 은 `- 걸음 건너뜀 · ` 줄에 `gate_name(kind, plan)` 이 글자 그대로 있어도 지남(`skipped=True`). 세션 기록도 판도 보지 않는다.

`missing` 의 사유 줄(관문마다 하나):

- 줄이 없다 → `` `<종류>` 줄이 없다[(계획 <n>)] — 질문 창으로 승인받고 `conductor_ledger.py record --human "<종류>"` 로 적는다 ``
- 줄이 지나지 못했다 → `` `<종류>` 줄이 지나지 못했다[(계획 <n>)]: <판정> — <사유> ``(사유에 다음 할 일이 들어 있다. `근거 없음` · `어긋남` 에는 `` — 질문 창으로 승인받고 `conductor_ledger.py record --human "<종류>"` 로 다시 적는다 `` 를 붙인다)

`retry_open` — 켜져 있으면 `parse` 된 `걸음 건너뜀` 줄 가운데 `gate == retry_name(plan, attempt)` 이고 판정(`deep` 에 따라)이 `지남` 인 줄이 있는가. 꺼져 있으면 `- 걸음 건너뜀 · ` 줄에 그 이름이 글자 그대로 있는가.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_human_judge.py` 에 더한다. `Repo.setUp` 이 `self.conf`(임시 설정 폴더)를 만들고 `mock.patch.dict(os.environ, {"CLAUDE_CONFIG_DIR": self.conf})` 를 건다. 도우미:

```python
    def approve(self, tip, kind=H.KIND_SPEC, plan=None, gate=None, picked=None, question=None, rev=None, who="human", session=S, date="2026-11-18", **kw):
        """그 끝의 묶인 파일로 머리를 만들고, 그 머리로 시작하는 질문 창 답을 기록에 지어 넣고, 그 답을 가리키는 줄을 돌려준다."""
        name = H.bound_name(kind, plan)
        rev = rev or H.version(self.git, tip, TEAM.job(JOB, name))
        label = H.RETRY_LABEL if (gate or "").startswith("다시 시도") else H.PASS_LABELS[kind][0]
        text = question or "%s — %s자리표시 질문" % (H.head(JOB, rev), (gate + " ") if gate else "")
        uid = SF.add_answer(self.conf, session, [(text, picked or label + " (권장)")], who=who, **kw)
        return H.render(kind, date, label, name, rev, session, uid + "#1", gate=gate)
```

`setUp` 뒤의 레포: `c1` 설계(`DESIGN`) · `c2` `plan-1.md` · `c3` `plan-2.md` · `c4` `INTENT.md`(상수 `INTENT` — 과제 5 의 `test_plan_and_intent_bodies` 가 쓴 글과 같은 글) — 파일마다 다른 커밋이다. `tip = c4`. `DESIGN` · `INTENT` · `S` · `E` 는 이 파일에도 상수로 둔다(테스트 파일끼리 가져오지 않는다).

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
            "사람 아님": (self.approve(self.tip, who="other"), H.MISMATCH),
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
        uid = SF.add_answer(self.conf, S, [(H.head(JOB, rev) + " 승인할까요", "수정 필요"), ("다음 에픽도 함께 할까요", "승인 — 계획 담당자에게")])
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
        SF.add_answer(self.conf, other, [(H.head(JOB, self.c1[:8]) + " 질문", "승인 — 계획 담당자에게")], entry=H.parse(real).entry)
        copy = real.replace(S + ":", other + ":").replace("2026-11-18", "2026-11-19")
        self.assertEqual(self.v(copy, [real, copy]), H.MISMATCH)


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
        plain = self.approve(self.tip, H.KIND_SKIP, gate="다시 시도 시도 3")
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
  - `conductor_ledger.py ask-head --human <종류> --roadmap <로드맵> --job <과제> [--plan <n>]` — 표준 출력에 머리 한 줄(`<과제> @<판>`)만 낸다. 0 · 1 · 2 · 3
  - `conductor_ledger.py record --human <종류> --roadmap <로드맵> --job <과제> [--plan <n>] [--gate "<관문 이름>"] [--date <YYYY-MM-DD>]` — 0 적었다(또는 같은 줄이 이미 있다) · 1 · 2 · 3. 커밋은 하지 않는다
  - `record` 의 `--spec` 은 `--human` 이 없을 때만 필요하다(없으면 2)
- Produces (`tests/fixtures/team_repo.sh` — 뒤 과제의 셸 테스트가 쓴다):

```bash
SID="00000000-0000-4000-8000-00000000c0de"          # 지휘 표지를 쥔 가짜 세션
export CLAUDE_CONFIG_DIR="$T/claude"                  # 세션 기록 자리 — 실제 설정 폴더를 읽지 않는다
CL="$S/conductor_ledger.py"
SFX="$ROOT/plugins/spec-distill/tests/fixtures/session_fixture.py"
led() { (cd "$W" && python3 "$CL" "$@") > "$T/led.txt" 2>&1; echo $?; }   # 지휘 원장 명령 — rc 를 echo, 출력은 $T/led.txt
claim() { [ "$(led claim --roadmap "$RM" --session "$SID")" = "0" ]; }
answer() {  # answer <질문 글> <고른 글> [--who …] — 지휘 세션 기록에 질문 창 답 하나를 덧붙인다. 답 항목의 uuid 는 $T/entry.txt
  local q="$1" a="$2"; shift 2
  python3 "$SFX" answer --config "$CLAUDE_CONFIG_DIR" --session "$SID" --question "$q" --label "$a" "$@" > "$T/entry.txt"
}
human() {  # human <종류> <과제> [계획|-] [관문 이름|-] [날짜] — 머리를 받아 통과 라벨로 답한 기록을 짓고 줄을 적는다. rc 를 echo(커밋은 부르는 쪽)
  local kind="$1" job="$2" plan="${3:--}" gate="${4:--}" date="${5:-}" label
  case "$kind" in
    "spec 승인") label="승인 — 계획 담당자에게 (권장)" ;;
    "계획 검토") label="계획대로 구현한다" ;;
    "흐름 승인") label="설계 없이 진행" ;;
    *) case "$gate" in "다시 시도"*) label="다시 시도한다" ;; *) label="건너뛴다" ;; esac ;;
  esac
  set -- --human "$kind" --roadmap "$RM" --job "$job"
  [ "$plan" = "-" ] || set -- "$@" --plan "$plan"
  [ "$(led ask-head "$@")" = "0" ] || { echo "ask-head 실패 — $(cat "$T/led.txt")" >&2; echo 1; return; }
  if [ "$gate" = "-" ]; then answer "$(cat "$T/led.txt") — 자리표시 질문" "$label"
  else answer "$(cat "$T/led.txt") — ${gate} 자리표시 질문" "$label"; set -- "$@" --gate "$gate"; fi
  [ -z "$date" ] || set -- "$@" --date "$date"
  led record "$@"
}
approved() {  # approved <human 의 인자…> — 줄을 적고 그 과제의 INTENT.md 를 커밋한다
  [ "$(human "$@")" = "0" ] && g add -- "$TM/jobs/$2/INTENT.md" && g commit -qm "$1 — $2"
}
```

동작(둘 다 team 형식 로드맵에서만 — 아니면 2 `team 형식 로드맵에서만 쓴다`):

1. **인자.** `--human` 은 종류 넷 가운데 하나다. `--plan` 은 `계획 검토` 에만 주고 꼭 준다. `--gate` 는 `record` 의 `걸음 건너뜀` 에만 주고 꼭 주며, 이름 꼴(J8)이 아니면 2 다. `record --human` 에 `--spec` · `--line` · `--approval` · `--choice` 를 함께 주면 2 다(AC3).
2. **과제와 쓸 브랜치(J7).** `_status` 의 보고에서 과제를 찾는다 — 블록이면 `branch_states`, 로드맵 밖 과제면 보고의 `jobs` 에서 그 `branch`. 없으면 2. 쓸 브랜치가 모두 머지됐으면 1 `이미 기본 브랜치에 머지됐다`. 지금 브랜치(`git symbolic-ref --short -q HEAD`)가 쓸 브랜치가 아니면 1 `이 worktree 는 <지금 브랜치 | 브랜치 없는 HEAD> 다 — <쓸 브랜치> 를 체크아웃한 worktree 에서 부른다`.
3. **커밋돼 있는가.** 묶일 파일(`human_lines.bound_name`)이 `HEAD` 에 없으면 1 `<파일> 이 커밋돼 있지 않다`. 작업 폴더의 글과 `HEAD` 의 글의 **본문**이 다르면 1 `<파일> 의 본문에 커밋되지 않은 변경이 있다 — 커밋한 뒤 다시 묻는다`. 기록 절만 다른 것은 지난다.
4. **머리.** `human_lines.head(과제, human_lines.version(git, "HEAD", 경로))`. `ask-head` 는 여기서 머리를 내고 끝난다.
5. **세션 기록(`record` 만).** 표지의 세션(`cs.holder(mpath(root, roadmap).parent)`)이 없으면 3 `확인 못 함 — 이 로드맵의 지휘 표지가 없다(먼저 claim)`. `session_record.locate` · `answers` 가 `Unreadable` 이면 3 `확인 못 함 — <사유>`.
6. **답 고르기.** 그 과제의 줄을 모은다 — 쓸 브랜치를 뺀 그 과제의 브랜치 끝들(`team_status.read_tip`) · 기본 브랜치 · `HEAD` 를 `human_lines.collect` 로 읽고, 작업 폴더 INTENT.md 의 결정 기록 줄을 더한다. 기록의 답을 **뒤에서부터** 보아 다음을 모두 채우는 첫 답을 고른다 — 질문 글이 머리로 시작한다(`starts_with_head`) · 건너뜀이면 질문 글에 `--gate` 의 이름이 글자 그대로 있다 · 그 답의 `key` 를 근거로 쓴 줄이 모은 줄에 없다(쓰려는 줄과 글자가 같은 줄은 빼고 본다). 고른 답의 `who` 가 `UNKNOWN` 이면 3 `확인 못 함 — 그 답을 사람이 했는지 가를 칸이 기록에 없다`. `HUMAN` 이 아닌 답은 고르지 않고 지나간다. 고른 답이 없으면 1 `쓰지 않았다 — 머리 <머리> 로 시작하는 질문 창 답이 지휘 세션 기록에 없다`.
7. **라벨.** `clean_label(고른 글)` 이 그 종류의 통과 라벨이 아니면(건너뜀은 관문 이름과 짝인 라벨이 아니면) 1 `쓰지 않았다 — 사람이 고른 라벨: 「<고른 글>」`. 더 앞의 답을 찾지 않는다.
8. **쓰기.** `human_lines.render(…)` 의 줄을 작업 폴더 INTENT.md 의 결정 기록에 덧붙인다(`_append_decisions` · `write_atomic`). 같은 줄이 이미 있으면 `이미 있어 쓰지 않았다 — …` 0, 썼으면 `적었다(커밋은 리더가) — <INTENT.md> 의 결정 기록: <줄>` 0. 날짜는 `--date`, 없으면 오늘이다.

**옛 인자 막기(AC3).** `record --spec … --approval` · `--line` 과 `flush` 가 team 형식 과제의 INTENT.md 에 쓰려는 줄 가운데 `human_lines.is_human(줄)` 이 참인 것이 있고 `human_gate` 가 켜져 있으면 아무것도 쓰지 않고 2 `사람 줄(<종류>)은 record --human 으로만 적는다 — 고른 글을 인자로 받지 않는다`. `human_gate` 가 꺼져 있으면 지금처럼 적는다. 옛 형식 문서에는 지금과 똑같이 적는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_human_record.sh`(머리 · `team_repo` · `finish` 는 `tests/test_start_bundle.sh` 와 같다). 준비:

```bash
team_repo && claim && ok "팀 레포와 지휘 표지" || { no "준비 실패 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; }
E1="$TM/jobs/E1"
intent_tail() { tail -n 1 "$W/$E1/INTENT.md"; }
g checkout -q -b feature/tm-e1 main
put "$E1/design.md" "$(printf '# 설계\n\n본문 하나\n\n## 지휘 기록\n')" && g commit -qm "E1 설계"; C1="$(g rev-parse HEAD)"
HEAD1="E1 @$(printf '%s' "$C1" | cut -c1-8)"
```

| # | 준비 | 명령 | 기대 |
|---|---|---|---|
| 1 | — | `led ask-head --human "spec 승인" --roadmap "$RM" --job E1` | rc 0 · 출력이 정확히 `$HEAD1` |
| 2 | 답이 없다 | `led record --human "spec 승인" --roadmap "$RM" --job E1` | rc 1 · 출력에 `$HEAD1` · INTENT.md 가 그대로(`g status --short -- "$TM"` 빔) |
| 3 | `answer " $HEAD1 — 질문" "승인 — 계획 담당자에게"` 와 `answer "**$HEAD1** 질문" "승인 — 계획 담당자에게"` | 위와 같다 | rc 1 · 출력에 `$HEAD1`(머리 앞에 글자가 붙은 두 답은 고르지 않고, 기다린 머리를 그대로 보인다 — Review Focus 3) · 그대로 |
| 4 | `answer "$HEAD1 — 질문" "수정 필요"` | 위와 같다 | rc 1 · 출력에 `사람이 고른 라벨: 「수정 필요」` · 그대로 |
| 5 | `python3 "$SFX" lines …` 로 `typed` · `peer` · `notification` 을 덧붙이고, `answer "$HEAD1 — 질문" "승인 — 계획 담당자에게" --who other` | 위와 같다 | rc 1 · 출력에 `「수정 필요」`(여전히 4 의 답이 고른 답이다 — 다른 세션의 글 · 알림 · 사람 아닌 답으로는 쓰지 않는다) |
| 6 | `answer "$HEAD1 — 질문" "승인 — 계획 담당자에게 (권장)"`(uuid 를 `U1` 로) | `… --date 2026-11-20` | rc 0 · `intent_tail` 이 `- spec 승인 · 2026-11-20 · 「승인 — 계획 담당자에게」 · design.md@<C1 8자> · 근거 ${SID}:${U1}#1` · 커밋은 되지 않았다(`g status --short -- "$TM"` 에 INTENT.md) |
| 7 | — | 6 을 한 번 더 | rc 0 · 출력에 `이미 있어 쓰지 않았다` · 줄 수 그대로 |
| 8 | — | `… --date 2026-11-21` | rc 1 · 줄 수 그대로(그 답은 이미 다른 줄의 근거라 고르지 않는다) |
| 9 | 6 의 줄을 커밋한다. `design.md` 의 본문을 고치고 커밋하지 않는다 | `ask-head` · `record` | 둘 다 rc 1 · 출력에 `커밋되지 않은 변경` |
| 10 | 9 를 되돌리고 `## 지휘 기록` 아래에만 한 줄 더하고 커밋하지 않는다 | `ask-head` | rc 0 · `$HEAD1`(본문만 견준다). 그 뒤 되돌린다 |
| 11 | `g checkout -q main` | `ask-head` | rc 1 · 출력에 `feature/tm-e1` |
| 12 | `g checkout -q --detach feature/tm-e1` | `ask-head` | rc 1 · 출력에 `feature/tm-e1`(Review Focus 5). 그 뒤 `g checkout -q feature/tm-e1` |
| 13 | `plan-1.md` 를 커밋(`C2`) | `ask-head --human "계획 검토" … --plan 1` | rc 0 · `E1 @<C2 8자>` |
| 14 | `answer "E1 @<C2 8자> — 질문" "계획대로 구현한다"` | `record --human "계획 검토" … --plan 1 --date 2026-11-21` | rc 0 · 줄에 `plan-1.md@<C2 8자>` |
| 15 | — | `human "걸음 건너뜀" E1 - "계획 검토 plan 1" 2026-11-22` | `0` · 줄이 `- 걸음 건너뜀 · 2026-11-22 · 「건너뛴다」 · 계획 검토 plan 1 · INTENT.md@<8자> · 근거 …` |
| 16 | 건너뜀 머리로 시작하되 관문 이름이 없는 답 | `record --human "걸음 건너뜀" … --gate "spec 승인"` | rc 1 |
| 17 | 건너뜀 머리 + `다시 시도 plan 1 시도 3` 이 든 질문에 「건너뛴다」 로 답 | `record … --gate "다시 시도 plan 1 시도 3"` | rc 1 · 출력에 `사람이 고른 라벨: 「건너뛴다」` |
| 18 | `g checkout -q -b feature/tm-e2 main`(설계 없는 흐름의 블록) | `human "흐름 승인" E2 - - 2026-11-22` | `0` · 줄에 `INTENT.md@` |
| 19 | 사용법 | `record --human "spec 승인" … --choice x` · `… --line x` · `… --approval` · `… --spec x` · `--human "결정"` · `--human "계획 검토"`(`--plan` 없음) · `--human "spec 승인" --plan 1` · `--human "걸음 건너뜀"`(`--gate` 없음) · `--gate "아무 관문"` · `record`(`--spec` 도 `--human` 도 없음) | 모두 rc 2 · INTENT.md 그대로 |
| 20 | `feature/tm-e1` 에서 | `led record --spec "$W/$E1/design.md" --approval --date 2026-11-23 --choice "이대로"` · `led record --spec "$W/$E1/design.md" --line "계획 검토 · 2026-11-23 · 「글」"` | 둘 다 rc 2 · 출력에 `record --human` · 그대로 |
| 21 | — | `led record --spec "$W/$E1/design.md" --line "결정 · 2026-11-23 · 「글」"` | rc 0(사람 줄 종류가 아닌 줄은 지금처럼) |
| 22 | 표지를 푼다(`led release …`) | `record --human "계획 검토" … --plan 1` | rc 3 · 출력에 `확인 못 함`. 그 뒤 `claim` |
| 23 | `CLAUDE_CONFIG_DIR` 를 빈 폴더로 | 위와 같다 | rc 3 · 출력에 `확인 못 함` |
| 24 | 새 머리의 답을 `--who unknown` 으로 | 그 종류의 `record` | rc 3 |
| 25 | 기본 브랜치의 `.devbrew.md` 에 `human_gate: 끔` 을 올린다(`publish`) | 20 의 두 명령 | 둘 다 rc 0 · 줄이 적혔다. 그 뒤 설정을 되돌려 올리고 20 이 다시 rc 2 인지 본다(양성 대조) |

표의 줄마다 `assert_eq` · `assert_contains` 로 쓴다. 이름은 `AC<n>: <무엇>` 으로 시작한다(1 · 9 · 10 = AC4, 2 – 8 · 13 – 18 = AC5 · AC7, 19 – 21 · 25 = AC3, 22 – 24 = AC6). 6 의 `U1` 은 `answer` 뒤의 `$(cat "$T/entry.txt")` 다.

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
- Test: `plugins/spec-distill/tests/test_team_status.sh` 와, 손으로 적은 승인 줄로 team 형식의 단계를 넘기던 셸 테스트

**Interfaces:**
- Consumes: `human_lines.passed` · `collect` · `Scope` · `KIND_SPEC` · `GATE_OFF` · `NO_LINE`(과제 6) · `repo_defaults.resolve` · `gate_on`(과제 3) · 과제 7 의 `human` · `approved` 도우미(테스트).
- Produces (`team_status.Reader`):
  - `gate_on() -> bool` — 처음 불릴 때 `repo_defaults.resolve(self.git.cwd)` 를 읽어 둔다. 읽지 못하면(`SettingsError` · 오류 목록) 참(J19)
  - `job_tips(branches: list) -> list` — 이름마다 `read_tip` 이 고른 끝(끝이 없거나 갈라진 브랜치는 뺀다) 뒤에 기본 브랜치 커밋(`self.main`), 겹침 없이
  - `scope(tip, job, branches) -> human_lines.Scope` — `lines` 는 `collect(git, team, job, [tip] + job_tips(branches))` 의 줄
  - `progress()` 의 설계 흐름 갈래: 승인 날짜는 `human_lines.passed(scope, KIND_SPEC, None, deep=False)` 에서 받는다

`progress()` 의 바뀌는 곳(설계 흐름만 — 설계 없는 흐름은 그대로다, J16):

- 지금의 `self._approval(intent)` 는 그대로 먼저 부른다 — `FormatError` 사유(`결정 기록 읽기 불가 — …`)의 갈래를 지킨다.
- 그 뒤 `scope = self.scope(tip, job, block.get("branches") or [])` 로 `passed` 를 부른다. 지났으면 `block["approved"]` 는 그 날짜이고 뒤의 갈래는 지금과 같다 — 다만 건너뜀 줄로 지났으면 근거의 앞머리가 `spec 승인됨(<날짜>)` 대신 `spec 승인 건너뜀(<날짜>)` 이다.
- 지나지 못했으면 「설계 중」 이다. 사유가 `NO_LINE` 이면 근거는 지금 글자 그대로, 아니면 `design.md 있음 · spec 승인 줄이 지나지 못했다 — <사유>`(J15).
- `self.gate_on()` 이 거짓이면 `block["notes"]` 맨 앞에 `human_lines.GATE_OFF` 를 넣는다(이미 있으면 넣지 않는다).

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
| e | 설정을 되돌려 올린다 | 「설계 중」 · `notes` 에 그 줄이 없다(양성 대조) |

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_team_status.sh | grep -E '✗' | head`
Expected: `AC8: 손으로 적은 승인 줄로는 계획이 되지 않는다` 와 새 줄들이 ✗

- [ ] **Step 3: 구현한다** — 위 Produces 와 바뀌는 곳 넷대로. `roadmap_status.py` 는 고치지 않는다.

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
- 옛 형식 로드맵을 쓰는 걸음(`## 지휘 기록` 의 승인 줄)은 고치지 않는다. 붉으면 멈춰 보고한다(AC21).

고친 걸음마다 파일 · 줄 · 무엇을 무엇으로 바꿨는지를 과제 보고에 적는다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/team_status.py plugins/spec-distill/tests
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
- Produces: `start_bundle.py --job … --stage …` 는 묶음을 만들기 전에 `human_lines.missing(scope, stage, a.plan, plain, deep=True)` 를 부르고, 사유가 있으면 `Refused(첫 사유)` 다 — 종료 코드 1 · 표준 출력 빔 · 표준 오류 `[spec-distill] 멈춤 — <사유>` 한 줄(J18). `scope` 의 `tip` 은 그 묶음이 읽는 과제 브랜치 커밋이고, 줄은 블록의 브랜치 전부(로드맵 밖 과제는 그 과제의 브랜치)와 기본 브랜치에서 모은다. `human_gate` 가 꺼져 있으면 알림 목록 맨 앞에 `human_lines.GATE_OFF` 를 넣는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_human_gate.sh`. 준비: `team_repo` · `claim` · 공통 문서(역할 문서 넷 · `HANDBOOK.md`)를 `tests/test_start_bundle.sh` 처럼 기본 브랜치에 올린다. `bundle() { (cd "$W" && python3 "$S/start_bundle.py" --roadmap "$RM" "$@") > "$T/b.txt" 2> "$T/b.err"; echo $?; }` · `refused() { [ "$(bundle "$@")" = "1" ] && [ ! -s "$T/b.txt" ]; }`. `feature/tm-e1` 에 설계 파일을 커밋해 올린다(`jpush`).

| # | 준비 | 명령 | 기대 |
|---|---|---|---|
| 1 | 승인 줄 없음 | `bundle --job E1 --stage design` | `0`(design 은 관문이 없다) |
| 2 | 〃 | `bundle --job E1 --stage plan --plan 1` | `1` · 표준 출력 빔 · 표준 오류가 한 줄이고 `멈춤 — \`spec 승인\` 줄이 없다` 와 `record --human` 이 있다 |
| 3 | 손으로 `decide E1 "spec 승인 · 2026-11-20 · 「승인 — 계획 담당자에게」"` 를 커밋해 올린다 | 위와 같다 | `1` · 표준 오류에 `근거 없음` |
| 4 | `approved "spec 승인" E1 - - 2026-11-20` 뒤 올린다 | 위와 같다 | `0` · 묶음 첫 줄이 `기준 커밋: ` 으로 시작(양성 대조) |
| 5 | 4 의 줄을 커밋만 하고 올리지 않은 채, 작업 폴더의 INTENT.md 에 손으로 줄을 더 적는다(커밋 안 함) | 위와 같다 | 4 와 같은 결과 — 관문은 커밋된 끝만 읽는다. 그 뒤 되돌린다 |
| 6 | `plan-1.md` 를 커밋해 올린다 | `bundle --job E1 --stage implement --plan 1` | `1` · 표준 오류에 `` `계획 검토` 줄 `` 과 `계획 1` |
| 7 | `approved "계획 검토" E1 1 - 2026-11-21` 뒤 올린다 | 위와 같다 · `--stage review --plan 1` | 둘 다 `0` |
| 8 | 세션 기록 폴더를 치운다(`mv`) | `bundle --job E1 --stage implement --plan 1` | `1` · 표준 오류에 `확인 못 함` 과 `다시 승인받는다`. 그 뒤 되돌린다 |
| 9 | 승인 뒤 `design.md` 본문을 고쳐 커밋해 올린다 | 위와 같다 | `1` · 표준 오류에 `낡음` |
| 10 | 9 를 `git revert` 로 되돌려 올린다(본문이 승인한 판과 같아진다) | 위와 같다 | `0` |
| 11 | 승인 뒤 `design.md` 의 `## 미룸` 절만 고쳐 커밋해 올린다 | 위와 같다 | `0` |
| 12 | `feature/tm-e1b`(블록의 둘째 브랜치)를 `feature/tm-e1` 의 **승인 줄을 적기 전 커밋**에서 만들어 `plan-2.md` 를 커밋해 올린다 | `bundle --job E1 --stage plan --plan 2` | `0` — 승인 줄이 `feature/tm-e1` 끝에만 있어도 모아 읽는다(AC9) |
| 13 | 〃 | `bundle --job E1 --stage implement --plan 2` | `1` · `계획 2`(계획 1 의 확인 줄은 계획 2 를 열지 않는다) |
| 14 | `feature/tm-e1b` 에서 `approved "걸음 건너뜀" E1 - "계획 검토 plan 2" 2026-11-22` 뒤 올린다 | 위와 같다 · `--stage implement --plan 1` 도 | 계획 2 는 `0`(AC12). 계획 1 은 7 의 줄로 `0` 그대로 |
| 15 | `feature/tm-e2`(설계 없는 흐름)에 과제 폴더가 있다 | `bundle --job E2 --stage implement` | `1` · 표준 오류에 `` `흐름 승인` 줄이 없다 `` |
| 16 | `approved "흐름 승인" E2 - - 2026-11-22` 뒤 올린다 | 위와 같다 | `0` |
| 17 | 기본 브랜치의 `.devbrew.md` 에 `human_gate: 끔` 을 올린다. 3 의 손으로 적은 줄만 있는 새 과제 브랜치(`feature/tm-e3` · 설계 커밋 · `decide`) | `bundle --job E3 --stage plan --plan 1` | `0` · 묶음 둘째 줄이 `알림: 사람 줄 대조가 꺼져 있다`(AC20) |
| 18 | 설정을 되돌려 올린다 | 위와 같다 | `1`(양성 대조) |
| 19 | 걸음표 · 설정으로 관문이 바뀌지 않는다 | `.devbrew.md` 에 `human_gate: 켬` 과 함께 아는 다른 키만 둔 채 2 를 다시 | `1` — 관문을 끄는 길은 `human_gate: 끔` 하나다 |

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `chmod +x plugins/spec-distill/tests/test_human_gate.sh && bash plugins/spec-distill/tests/test_human_gate.sh | grep -E '✗' | head -5`
Expected: 2 · 3 · 6 · 8 · 9 · 13 · 15 · 18 의 줄이 ✗(지금은 묶음이 나간다)

- [ ] **Step 3: 구현한다**

`_job_bundle` 에서 INTENT.md 를 읽은 바로 뒤, 묶음 글을 짓기 전에 관문을 본다. 블록의 브랜치 목록은 `block.get("branches")`, 로드맵 밖 과제는 `locate` 가 찾은 그 과제의 브랜치다(`locate` 가 브랜치 이름도 돌려주게 한다).

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
- Test: `plugins/spec-distill/tests/test_human_gate.sh` · `tests/test_start_bundle.sh` · `tests/test_team_results.py`

**Interfaces:**
- Consumes: `roadmap_status.build`(보고의 블록마다 `branch_states` — `branch` · `tip` · `merged` · 있을 때 `uncountable`) · `human_lines.retry_open` · `RETRY_STOP` · `retry_name` · `roadmap_status._sh_word`.
- Produces:
  - `team_status.plan_merged(reader, block: dict, n: int) -> tuple` — `(머지 근거 | None, 셀 수 없는 사유 | None)`(J11). `block` 은 상태 보고의 블록이다. `branch_states[n-1]` 에 `uncountable` 이 있으면 `(None, 그 글)`, `merged` 가 있으면 `(그 글, None)`, `tip` 이 `None` 이고 기본 브랜치에 그 계획의 자취(설계 흐름은 `team.plan(job, n)` · 설계 없는 흐름은 결과 폴더의 `implement` 결과 파일)가 있으면 `("브랜치는 없고 기본 브랜치에 <경로> 가 있다", None)`, 아니면 `(None, None)`. 브랜치 칸에 n 번째가 없으면 `(None, None)`
  - `job_results.failed_streak(git, tip, team, job, intent_text, plan, before: int) -> int` — 그 계획의 `implement` 시도 가운데 번호가 `before` 보다 작은 것을 큰 번호부터 보아, 「끝」 줄이 있고 받음 줄이 없는 시도가 이어지는 수(J12). 「끝」 줄이 없거나 읽지 못한 시도, 받은 시도를 만나면 멈춘다
  - `start_bundle.SYNC_LINE = "맞추는 명령: python3 %s job sync --result %s --role %s --bundle-at %s --job-at %s"` — 첫 `%s` 는 `roadmap_status._sh_word(str(Path(__file__).resolve().parent / "roadmap_write.py"))`(J13)

`_job_bundle` 의 차례: 인자 규칙 → 브랜치 고르기 → **머지된 계획 멈춤** → INTENT.md 읽기 → 관문(과제 9) → 시도 번호 → **연속 실패 멈춤** → 묶음.

- 머지된 계획 — 블록의 과제이고 단계가 `plan` · `implement` · `review` 일 때 `roadmap_status.build(git, argparse.Namespace(roadmap=a.roadmap, roadmap_file=None, json=False))` 의 그 블록으로 `plan_merged(reader, 블록, a.plan or 1)` 을 부른다. 근거가 있으면 `Refused("%s 의 계획 %d 는 이미 기본 브랜치에 머지됐다(%s) — 머지 뒤에 고칠 일은 새 계획이나 새 과제로 연다" % …)`(설계 없는 흐름은 「의 계획 n」 을 뺀다), 셀 수 없는 사유면 `Unchecked`. 보고에 그 블록이 없으면 `Unchecked`.
- 연속 실패 — 단계가 `implement` 일 때 `failed_streak(…, before=이번 시도 번호) >= human_lines.RETRY_STOP` 이고 `human_lines.retry_open(scope, 결과 파일의 계획 번호, 이번 시도 번호, deep=True)` 가 거짓이면 `Refused("구현 시도 %d번이 이어서 받아지지 않았다(%s) — 사용자에게 가서 다시 할지 정한다. 다시 하기로 하면 질문 창으로 확인받고 `걸음 건너뜀` 줄(%s)을 적는다" % (수, 그 결과 파일 이름들, retry_name(…)))`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_team_results.py` 에 `failed_streak` 의 표를 더한다(그 파일이 결과 파일 글을 짓는 도우미와 가짜 git 을 쓰는 방식 그대로 — 없으면 `tests/test_human_judge.py` 의 `Repo` 를 따라 임시 레포를 만든다):

| 시도들(1부터) | `before` | 기대 |
|---|---|---|
| 없음 | 1 | 0 |
| 1 끝 · 받음 없음 | 2 | 1 |
| 1 끝 · 받음 없음 / 2 끝 · 받음 없음 | 3 | 2 |
| 1 끝 · 받음 **있음** / 2 끝 · 받음 없음 | 3 | 1 |
| 1 끝 · 받음 없음 / 2 **끝 줄 없음**(도는 중) | 3 | 0 |
| 1 끝 · 받음 없음 / 2 끝 · 받음 없음 / 3 끝 줄 없음(잇는 중) | 3 | 2 |
| 1 끝 · 받음 줄의 커밋이 그 파일의 `head` 와 다르다 | 2 | 1 |
| 1 끝 · 받음 없음(계획 1) / 다른 계획(2)의 시도 둘이 실패 | 계획 1 · 2 | 1 |
| `design` · `plan` 단계의 결과 파일 둘(끝 · 받음 없음) | 1 | 0(구현 시도만 센다) |
| 막힘 파일(`BLOCKED.md`)이 있다 | 1 | 0(막힘은 세지 않는다) |

`tests/test_human_gate.sh` 에 더한다:

| # | 준비 | 명령 | 기대 |
|---|---|---|---|
| 20 | 과제 9 의 E1(계획 1 이 열려 있다). `implement-plan-1-1.md` 를 `job sync` 로 만들고 `--end` 로 끝 줄을 적어 올린다(받음 줄은 적지 않는다) | `bundle --job E1 --stage implement --plan 1` | `0` · `쓸 것:` 줄이 `…/implement-plan-1-2.md`(실패 하나로는 멈추지 않는다) |
| 21 | 시도 2 도 같은 식으로 끝낸다 | 위와 같다 | `1` · 표준 출력 빔 · 표준 오류에 `구현 시도 2번이 이어서 받아지지 않았다` 와 `다시 시도 plan 1 시도 3` |
| 22 | 〃 | `bundle --job E1 --stage plan --plan 1` · `--stage design` | 둘 다 `0`(설계 · 계획 단계에는 이 멈춤이 없다) |
| 23 | `approved "걸음 건너뜀" E1 - "다시 시도 plan 1 시도 3" 2026-11-23` 뒤 올린다 | 21 의 명령 | `0` · `쓸 것:` 이 `…/implement-plan-1-3.md` |
| 24 | 시도 3 도 끝낸다(받음 없음) | 위와 같다 | `1` · 표준 오류에 `다시 시도 plan 1 시도 4`(그 줄은 시도 3 하나만 풀었다) |
| 25 | 시도 3 에 받음 줄을 `decide` 로 적어 올린다 — `- 결과 받음 · 2026-11-24 · 「implement-plan-1-3.md · <그 결과 파일 머리의 head> · 결과 대조: 통과 — 자리표시」`(J12 — 이름과 `head` 를 가리키는 꼴 맞는 줄이면 받은 시도다) | 위와 같다 | `0` · `쓸 것:` 이 `…/implement-plan-1-4.md`(받은 시도가 이어짐을 끊는다) |
| 26 | `BLOCKED.md` 만 있는 새 과제 | 구현 묶음 | 연속 실패로 멈추지 않는다 |
| 27 | `feature/tm-e1` 을 기본 브랜치에 `--no-ff` 로 머지해 올린다(브랜치는 남긴다) | `bundle --job E1 --stage implement --plan 1` · `--stage plan --plan 1` · `--stage review --plan 1` | 셋 다 `1` · 표준 출력 빔 · 표준 오류에 `이미 기본 브랜치에 머지됐다`(AC14) |
| 28 | 그 브랜치를 로컬과 origin 에서 지운다 | 위 셋 | 27 과 같다(브랜치를 지웠든 남겼든 같다) |
| 29 | 〃 | `bundle --job E1 --stage plan --plan 2` | 머지 때문에 멈추지 않는다(계획 2 는 머지되지 않았다) |
| 30 | 한 번도 만든 적 없는 브랜치의 블록(E3 의 새 레포 사본) | `bundle --job E3 --stage design` | `0` · 알림에 `과제 브랜치 … 가 아직 없다`(없는 브랜치를 머지된 것으로 읽지 않는다 — 양성 대조) |

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

- [ ] **Step 3: 구현한다** — 위 Produces 와 차례대로. `references/team-files.md` §9 의 「맞추는 명령」 줄 보기(코드 블록의 한 줄)를 새 꼴로 고친다.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_results.py plugins/spec-distill/tests/test_team_docs.py 2>&1 | tail -3; for t in test_human_gate test_start_bundle test_team_sync test_team_status test_roadmap_status; do printf '%s: ' "$t"; bash plugins/spec-distill/tests/$t.sh | tail -1; done; bash shared/tests/test_python_floor.sh | tail -1`
Expected: `OK` · 모두 실패 0. 28 이 붉으면(지운 브랜치가 머지된 것으로 읽히지 않는다) `plan_merged` 의 셋째 갈래(끝이 없고 기본 브랜치에 계획 파일이 있다)를 본다 — 테스트 레포의 origin 은 GitHub 가 아니라 머지 메시지 길이 서지 않는다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/start_bundle.py plugins/spec-distill/scripts/team_status.py plugins/spec-distill/scripts/job_results.py plugins/spec-distill/references/team-files.md plugins/spec-distill/tests/test_human_gate.sh plugins/spec-distill/tests/test_start_bundle.sh plugins/spec-distill/tests/test_team_results.py
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
- Consumes: `human_lines.missing` · `match` · `is_human` · `parse` · `collect` · `GATE_OFF` · `Reader.scope` · `Reader.flow` · `Reader.job_tips` · `team_status.plan_merged`(과제 6 · 8 · 10).
- Produces:
  - `job_results.check_result(git, tip, team, job, name, extra=()) -> Check` — `extra` 의 글을 거절 사유에 더한 뒤 첫 줄을 짓는다(받음 줄 다시 세기 `receipt` 는 `extra` 를 주지 않는다 — 꼴만 본다)
  - `job_results.py check` — 결과 파일 이름의 단계가 `implement` 면 대조 전에 `human_lines.missing(scope, "implement", 이름의 계획 번호, 흐름, deep=True)` 를 불러 그 사유를 `extra` 로 넘긴다. 지나지 못하면 첫 줄이 `결과 대조: 거절 <n>건 — <이름>`, 사유는 `거절 사유: <사유>` 줄, 받음 줄은 내지 않고 종료 코드 1 이다. `human_gate` 가 꺼져 있으면 첫 줄 바로 아래에 `알림: 사람 줄 대조가 꺼져 있다` 를 낸다. 흐름은 블록이면 `Reader.flow(블록)`, 블록이 아닌 과제(`--branch`)면 설계 없는 흐름이다
  - `conductor_ledger.py human-check --roadmap <로드맵> --job <과제>` — 그 과제의 사람 줄(`is_human` 이 참인 줄 — 근거 없는 줄 포함)마다 `<판정> — <줄>` 한 줄, `지남` 이 아니면 그 아래 `    사유: <사유>` 한 줄을 낸다. 줄이 없으면 `사람 줄 없음`. 아무것도 쓰지 않는다. 종료 코드는 J24. 줄마다 「지금 본문」 의 끝은 J17 로 고른다

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_human_gate.sh` 에 더한다. `check() { (cd "$W" && python3 "$S/job_results.py" check --roadmap "$RM" "$@" --date 2026-11-30) > "$T/c.txt" 2>&1; echo $?; }`.

| # | 준비 | 명령 | 기대 |
|---|---|---|---|
| 31 | 새 레포. E1 설계 · `approved "spec 승인"` · `plan-1.md` · **`계획 검토` 줄 없이** `implement-plan-1-1.md` 를 끝까지 써 올린다(시작 묶음 없이 띄워진 담당자) | `check --job E1 --result implement-plan-1-1.md` | `1` · 첫 줄이 `결과 대조: 거절 ` 로 시작 · `거절 사유:` 줄에 `` `계획 검토` 줄이 없다 `` · `- 결과 받음` 줄이 없다(AC10) |
| 32 | `approved "계획 검토" E1 1 - 2026-11-21` 뒤 올린다 | 위와 같다 | `0` · `- 결과 받음 · 2026-11-30 · 「implement-plan-1-1.md · …」` 한 줄(양성 대조) |
| 33 | 세션 기록 폴더를 치운다 | 위와 같다 | `1` · `거절 사유:` 줄에 `확인 못 함` 과 `다시 승인받는다`(AC11). 그 뒤 되돌린다 |
| 34 | 32 의 계획 검토 줄을 손으로 고친다 — 근거의 uuid 를 없는 값으로 | 위와 같다 | `1` · `어긋남` |
| 35 | 34 를 되돌리고 `plan-1.md` 를 고쳐 커밋한 뒤 줄의 판만 새 커밋으로 고쳐 쓴다 | 위와 같다 | `1` · `어긋남`(AC11 — 진짜 옛 답 · 판만 새것) |
| 36 | 계획 검토 줄을 지우고 `approved "걸음 건너뜀" E1 - "계획 검토 plan 1" 2026-11-22` | 위와 같다 | `0`(AC12) |
| 37 | E2(설계 없는 흐름)의 `implement-1.md` 를 끝까지 써 올린다. `흐름 승인` 줄 없음 | `check --job E2 --result implement-1.md` | `1` · `` `흐름 승인` 줄이 없다 ``(AC10) |
| 38 | `approved "흐름 승인" E2 - - 2026-11-22` 뒤 올린다 | 위와 같다 | `0` |
| 39 | `design` · `plan` 결과 파일 | `check … --result plan-plan-1-1.md` | 관문 사유가 붙지 않는다(구현 결과만 본다) |
| 40 | `human_gate: 끔` 을 올리고 손으로 적은 줄 둘 | 31 의 명령(새 과제에서) | `0` · 둘째 줄이 `알림: 사람 줄 대조가 꺼져 있다`. 되돌리면 `1` |
| 41 | 32 의 상태 | `led human-check --roadmap "$RM" --job E1` | `0` · 줄 수가 사람 줄 수와 같고 모두 `지남 — ` 로 시작 · INTENT.md 와 `g status --short` 가 그대로(아무것도 쓰지 않는다) |
| 42 | 손으로 적은 `- spec 승인 · …` 줄 하나 · 없는 uuid 를 가리키는 줄 하나 · 승인 뒤 본문이 바뀐 줄 하나 · 세션 기록이 없는 세션을 가리키는 줄 하나를 더해 커밋 | 위와 같다 | `1` · 출력에 `근거 없음 — ` · `어긋남 — ` · `낡음 — ` · `확인 못 함 — ` 로 시작하는 줄이 하나씩 있고 진짜 줄은 `지남 — `(AC23 의 판정 다섯) |
| 43 | 사람 줄이 없는 과제 | `led human-check --roadmap "$RM" --job E3` | `0` · `사람 줄 없음` |
| 44 | 없는 과제 · 옛 형식 로드맵 | `led human-check …` | `2` |

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_human_gate.sh | grep -E '✗' | tail -8`
Expected: 31 · 33 – 35 · 37 · 41 – 44 가 ✗

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
4. `ask-head` → 머리. 그 머리로 답한 기록 → `record --human "spec 승인"` → 커밋 · push.
5. `--stage plan --plan 1` → 0. `맞추는 명령` 줄의 역할이 `worker` 다. 그 줄을 그대로 돌려 `plan-plan-1-1.md` 의 머리를 만든다.
6. `plan-1.md` 를 커밋한다. `--stage implement --plan 1` → 1(계획 확인 없음).
7. `계획 검토` 를 같은 길로 적는다 → `--stage implement --plan 1` → 0. 맞추는 명령을 그대로 돌린다.
8. 예약 경로의 파일 하나를 커밋하고 결과 파일에 `AC` 줄과 「끝」 줄을 적어 올린다(설계 파일의 `## Acceptance Criteria` 에 `AC1` 하나를 두고 `plan-1.md` 의 task 절이 `AC1` 을 부른다).
9. `job_results.py check` → 0 · 받음 줄. 그 줄을 `record --spec … --line` 으로 적어 올린다.
10. 상태 계산 → E1 이 「구현 끝」.
11. `human-check` → 0 · 두 줄 모두 `지남`.

그 뒤 같은 레포에서 Verification Plan 의 경우를 본다(이미 과제 9 – 11 이 따로 잰 것을 한 흐름 위에서 다시 잰다): 승인 뒤 설계 본문을 고친 것(구현 묶음 1 · 상태 「설계 중」 · `human-check` 에 `낡음`) → 되돌림 · 승인 뒤 미룸 절만 고친 것(그대로 0) · 설계 없는 흐름(E2: 흐름 승인 없이는 묶음도 결과도 1, 있으면 0).

- [ ] **Step 2: 옛 형식이 그대로인지 재는 절을 더한다(AC21)**

같은 파일에 옛 형식 레포를 하나 만든다(`tests/test_conductor_ledger.py` 의 `roadmap()` 이 짓는 꼴의 로드맵 — 머리말에 `layout` 이 없다 — 과 `## 지휘 기록` 절이 있는 설계문서).

| # | 명령 | 기대 |
|---|---|---|
| o1 | `conductor_ledger.py record --spec <옛 설계문서> --approval --date 2026-11-20 --choice "승인 — 계획 담당자에게"` | 0 · `## 지휘 기록` 의 마지막 줄이 정확히 `- spec 승인 · 2026-11-20 · 「승인 — 계획 담당자에게」`(판 · 근거 칸이 없다) |
| o2 | `… --line "계획 검토 · 2026-11-20 · 「글」"` | 0 · 그 줄이 적혔다 |
| o3 | `conductor_ledger.py record --human "spec 승인" --roadmap <옛 로드맵> --job A1` · `ask-head …` · `human-check …` | 셋 다 2 · 출력에 `team 형식` |
| o4 | `roadmap_status.py <옛 로드맵>` | o1 의 줄로 그 에픽이 「계획」 이다(근거 칸 없는 줄이 옛 형식에서는 그대로 센다) |
| o5 | 설정에 `human_gate: 끔` · `켬` 을 번갈아 올리고 o1 · o4 | 결과가 같다(옛 형식은 이 키를 보지 않는다) |

그리고 `git diff origin/main --stat -- plugins/spec-distill/tests/test_roadmap_status.sh plugins/spec-distill/tests/test_roadmap_model.py` 를 과제 보고에 붙인다 — 옛 형식 테스트에서 바뀐 것은 과제 3 이 더한 테스트 하나뿐이어야 한다.

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
                     "· 근거 <세션>:<항목>", "계획 검토 plan <n>", "다시 시도 plan <n> 시도 <k>", "다시 시도 시도 <k>"):
            self.assertIn(word, text, word)
        self.assertNotIn("`design` · `plan` 은 designer", text)
        self.assertNotIn("종류는 일곱", text)

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
  - §2 「결정 기록」 글머리 — 사람 줄 넷은 대기 줄로 쌓지 않고 `record --human` 이 그 브랜치의 INTENT.md 에 바로 쓰며 리더가 바로 커밋한다는 문장. 사람 줄의 꼴 · 종류와 묶이는 파일 · 통과 라벨 표(Global Constraints 의 글자) · 관문 이름 넷 · 근거 칸(`근거 <세션>:<항목>` — 항목은 답 항목의 번호와 질문의 순번).
  - §5 「결정 기록에 쓰는 줄」 — `--approval` · `--line` 은 team 형식에서 사람 줄 종류를 받지 않는다(2). `ask-head` · `record --human` 의 인자 · 종료 코드 · 「커밋된 뒤에 묻는다」 · 「쓸 브랜치의 worktree 에서 부른다」. 결과 대조가 구현 결과에서 관문을 본다는 것과 `human-check`.
  - §9 시작 묶음 — 관문 표 · 멈춤의 종료 코드와 사유 줄 · 머지된 계획 멈춤 · 연속 실패 멈춤(2 로 고정 · 막힘은 세지 않는다 · 설계와 계획 단계에는 없다) · `알림: 사람 줄 대조가 꺼져 있다`.
  - §10 단계 계산 — 표의 「설계 중」 · 「계획」 줄을 꼴 판정으로 고친다(판정 다섯과 표 · 세션 기록을 읽지 않는다 · 건너뜀 줄 · 근거 글자 J15). 「`계획 검토` 줄도 단계의 근거가 아니다」 문장은 남기고 「구현 묶음과 구현 결과의 관문이다(§9 · §5)」 를 잇는다.
  - 판정 표(설계 §2 의 다섯 줄)와 「막지 못하는 것」 넷(설계 Constraints 그대로)을 §10 뒤에 `### 사람 줄의 판정` 으로 둔다. 문서가 300줄을 넘으므로 `## 목차` 가 있으면 같은 커밋에서 맞춘다.
- `README.md` — 지휘자 절에 사람 줄과 관문을 세 문장으로(무엇을 막나 · 어떻게 적나 · 끄는 길 `human_gate: 끔` 과 그때 보이는 알림). 설정 키 표에 `human_gate`. 「Principles Instantiated」 에 Law 1(승인된 설계 없이는 계획 · 구현이 시작되지 않는다 — 스크립트가 지킨다)과 P8 줄. 바뀐 기본 역할 한 줄.
- `dependencies.md` — 표 아래에 `## 세션 기록` 절: 사람 줄이 Claude Code 의 세션 기록 파일에 기댄다는 것, 읽는 칸(과제 1 의 표에서 칸 이름만), 확인한 판의 범위(과제 1 Step 2 가 잰 값), 칸은 Claude Code 의 문서에 없고 판에 따라 바뀔 수 있으며 바뀌면 「확인 못 함」 이 되고 여는 길은 `human_gate: 끔` 이라는 것, 과제 1 Step 3 의 다섯 줄(잰 값 또는 「재지 못함」). 표의 판 칸은 손으로 고치지 않고 `python3 scripts/check_deps.py measure …`(그 파일 머리의 명령)로 다시 잰다.
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
- 끝에서 끝 흐름 넷을 따로 물어라 — 각 이음매의 종료 코드 소비와 상태 가정: ① 설계 커밋 → `ask-head` → 질문 창 답 → `record --human` → 커밋 → 시작 묶음 ② 구현 결과 → `job_results.py check` → 받음 줄 → 단계 계산 ③ 승인 뒤 본문 고침 → 단계 계산 「설계 중」 · 묶음 멈춤 · `human-check` 의 `낡음` 이 같은 판정에서 나오는가 ④ `human_gate: 끔` → 옛 인자가 열림 · 관문이 줄의 유무만 봄 · 알림 세 자리.
- 이 계획이 쓴 테스트 코드(과제 1 · 2 · 5 · 6 의 파이썬 테스트와 과제 7 · 9 · 10 · 11 의 표)는 계획이 정한 것이라는 표시를 붙여, 덜 보지 말고 같은 눈으로 보라고 적는다. 기존 테스트를 옮긴 곳(과제 8 · 9 · 11 의 Step 4)에서 단언이 지워지거나 느슨해지지 않았는지 `git diff origin/main -- plugins/spec-distill/tests` 로 보라고 적는다.
- 개인 정보: `tests/fixtures/session-record/` 와 `dependencies.md` 에 대화 내용 · 경로 속 이름 · 이메일이 없는지 보라고 적는다.

리뷰 보고는 git 이 추적하지 않는 파일에 적는다 — 지휘자가 준 임시 폴더의 `r2-plan1-ac-report.md`(없으면 상태 루트 `python3 plugins/spec-distill/scripts/state_path.py state-root` 가 내는 폴더 아래 같은 이름). 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올린다 — 올릴 행을 보고에 적고 지휘자가 올린다(걸친 AC 의 받는 곳은 R2 다). PR 을 만들기 전에

`python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.19.2"/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-18-conductor-walk-gates-design.md <보고 파일 경로> --acs "AC3~AC16 · AC20~AC23"`

을 돌려 경고를 사용자에게 보인다. PR 본문에는 J21(두 계획 사이의 역할 문서) · 아래 「재지 못함」 · 기존 테스트를 옮긴 목록을 적는다.

## 재지 못함

- **질문 창이 사람 없이 답을 내는 길 넷**(헤드리스 · 권한 모드 · 훅 · 다른 세션의 키 입력) — 구현 담당은 Claude Code 를 다시 띄우지 않는다(J26). 지휘자가 측정 값을 주지 않으면 사람 답의 허용 목록(`permissionDecision` 의 `decision: accept` · `source: user_temporary`)으로 가고, 그 길들이 기록에 무엇을 남기는지는 재지 못한 채다. 다른 세션의 키 입력은 터미널에 글쇠가 들어가는 것이라 기록에서 사람 답과 갈리지 않을 수 있다 — 그렇다면 설계 Constraints 의 「막지 못한다」 목록에 닿는다.
- **`record --human` 을 부른 호출이 그때 기록에 쓰여 있는지**(`eac92f65`) — 같은 이유. 동작에는 쓰지 않는다.
- **설치본에서의 한 번** — 진짜 지휘 세션에서 질문 창으로 승인하고 `record --human` 이 그 답을 찾는지는 team 형식 로드맵이 도는 때(E1 이 새 형식을 켠 뒤)에 처음 실제로 돈다. PR 본문에 손으로 한 번 확인하는 법을 적는다 — 임시 레포에 team 형식 로드맵을 만들고(`roadmap_write.py create --layout team`), 지휘 세션에서 `ask-head` 의 머리로 질문 창을 띄워 답한 뒤 `record --human` 을 부른다.
