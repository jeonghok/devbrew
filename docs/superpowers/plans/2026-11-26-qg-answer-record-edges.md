# R8 — qg 답 기록 · 다른 팀 읽기 뒤처리 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 의도 점검이 받은 답을 남기고 읽는 길과 다른 팀 작업을 읽는 길에서 조용히 사라지거나 틀린 말로 남는 가장자리를 닫는다 — 직접 쓴 답은 버려지지 않고, 읽지 못한 것은 맞는 이유와 함께 「확인 못 함」 으로 남고, 올리지 않은 작업의 글은 git 에 실리지 않는다.

**Architecture:** 고치는 파일 묶음은 둘이고 서로 독립이다 — 답 기록(`intent_critic.py` · `intent_answers.py` · 의도 점검 reference · 세션 파일 꼴 문서 · `setup-qg.sh`, Task 1–8)과 다른 팀 읽기 · 의도 출처(`other_teams.py` · `intent_origin.py`, Task 9–12). 답 기록은 질문 기록을 커밋 앞에 한 번 원자 쓰기로 쓰고 커밋 뒤에는 커밋 결과만 덧쓰며, 결과를 짓는 `render` 가 세션 폴더의 답 입력 파일을 `record` 와 같은 읽기로 다시 갈라 답 파일에 실리지 않은 글을 결과 파일에 남긴다. 다른 팀 읽기는 같은 이름 사본을 가른 뒤 로컬 후보 가운데 끝 커밋이 원격 브랜치에서 닿지 않는 것을 git 물음 한 번으로 가려 이름과 겹치는 파일만 싣고, 원격보다 앞서거나 갈라진 로컬 브랜치는 원격 사본 끝에서 읽는다.

**Tech Stack:** python3(스위트의 맨 `python3` 는 3.9 일 수 있다 — 3.9 문법만) · PyYAML(이미 쓰는 곳만) · unittest · bash(3.2 호환 — `shared/tests/assert.sh` 꼴) · git · 마크다운.

**Spec:** `docs/superpowers/specs/2026-11-24-qg-answer-record-edges-design.md`(승인 2026-11-26). 설계문서 끝 「### Deferred to plan」 의 불릿 셋이 이 계획이 정할 것이다 — 처리는 아래 「설계가 넘긴 것의 처리」 표. 그 밑의 리뷰 참고 표(11줄)는 본문에 이미 반영된 리뷰 기록이라 과제로 잡지 않는다.

## Global Constraints

- **구현은 R7(`feature/qg-planted-text-suite-lock`)이 기본 브랜치에 머지된 뒤 시작한다.** 같은 파일을 고친다 — 닿는 자리는 아래 「R7 과 닿는 자리」 표. Task 0 이 그때의 코드로 다시 확인한다.
- **판 번호는 지휘자가 준다**(R7 머지 뒤 quality-gates 판의 다음 번호 · minor). 받기 전에는 `plugin.json` · CHANGELOG 의 판 칸을 쓰지 않는다 — Task 13 에서 한 번에 쓴다. 판 글자를 테스트에 박지 않는다.
- **돌려주는 꼴은 3판 그대로다** — `RETURN_KEYS` · `QUESTION_KEYS` · `QUESTION_STATES` · `RETURN_OUTCOMES` 의 칸과 값의 종류를 바꾸지 않는다. 달라지는 것은 `result_line` 의 글 · `answer_text` 에 실리는 글 · `commit` 칸의 새 값 하나(`unknown — 커밋 해시 확인 못 함`)뿐이다.
- **새 훅 · 새 진입 skill · 새 kill switch 가 없다. 리뷰어 정의(`agents/intent-critic.md`)는 고치지 않는다.** spec-distill 은 고치지 않는다.
- **설계에 없는 글자 · 수용 기준 · 보이는 동작을 더하거나 바꿔야 할 것 같으면 스스로 정하지 말고 멈춰 지휘자에게 보고한다.** 아래 「정한 이름과 꼴」 은 설계가 계획에 넘긴 자리다.
- **설계가 박은 글자 — 그대로 쓴다**(「정한 이름과 꼴」 의 글자 칸이 정본).
- 새 python 코드는 `encoding="utf-8"` 을 쓰고, 긴 한글 리터럴은 인접 문자열로 나눈다(CPython 긴 비ASCII 줄). 새 셸 테스트는 bash 3.2 에서 돈다(변수 뒤 한글 · 낫표는 `${v}`), 실행 비트(100755)를 준다.
- **알려진 한계(설계 D33)** — `read_tracked` 는 시간 한도가 아닌 다른 까닭의 실패도 「추적 안 된 파일 또는 없음」 으로 돌려준다. 그런 실패는 지운 문서와 섞여 말없이 빠진다. 이 계획은 고치지 않는다.
- 문서는 한국어가 기본이다. 사람에게 보이는 보고는 첫 줄에 상태, 번호 · 해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 끝에 할 일.
- 커밋: Conventional Commits(`type(scope):` 영어 · 설명 한국어), pathspec 으로만(`git add <경로>` · `git commit -m … -- <경로>`). 메시지 끝 줄은 그 세션의 `Co-Authored-By` 한 줄. 레포에 커밋하는 파일에 사용자 이름이 든 절대경로를 넣지 않는다.
- 금지: 공유 임시 폴더 glob 삭제 · `git stash` · 다른 worktree 의 git · HEAD 뒤로 옮기기(reset · rebase · force). 지우는 것은 자기가 만든 경로를 이름으로만. `TMPDIR` 은 지휘자가 준 실행 임시 폴더를 쓰고, 복합 셸 명령은 그 폴더의 스크립트 파일로 돌린다.
- **전체 스위트는 이 꼴로만 돌린다:** `python3 <지휘자가 준 spec-distill 캐시의 scripts/suite_lock.py> run --lock <지휘자가 준 잠금 폴더> --owner <이 agent 이름> --wait 1800 -- bash -c 'bash tools/suite/run-all.sh'`(지휘자 대조와 같은 공유 잠금 — 못 잡으면 잠금 없이 돌리지 않고 주인 · 잡은 시각을 보고). 과제 안에서는 그 과제의 좁은 테스트만 잠금 없이 돌린다. 하위 agent 에게 보내는 글에는 이 줄과 실제 경로를 그대로 싣는다.
- 하위 agent 를 띄울 때마다 모델을 이름으로 싣는다(superpowers subagent-driven-development 「Model Selection」 으로 고르고 이유 한 줄 — 지휘자가 정해 주면 그것).

## 정한 이름과 꼴

설계가 계획에 넘긴 이름 · 꼴과, 설계가 박은 글자를 한곳에 모은다. 과제들은 이 표를 따른다.

| 무엇 | 정한 것 |
|---|---|
| 구분 글자(§1 라벨 읽기) | 선택지 글자 바로 뒤가 글의 끝이거나, 공백 글자(`str.isspace()` — 빈칸 · 줄바꿈 · 탭)이거나, `—` · `-` · `:` · `,` · `.` 가운데 하나일 때만 그 선택지. 그 밖(`!` · `?` · `)` · 전각 `：` 등)이 붙으면 라벨 없는 글(`지금은 모르겠다`, 원문은 남는다) |
| 남긴 글 머리 줄 | `답 기록 실패 — 답 파일에 실리지 않은 답 입력의 글:` |
| 통째로 실은 갈래의 알림 줄 | `어느 글이 답 파일에 실렸는지 가르지 못해 답 입력의 글을 모두 실었다 — 답 파일에 이미 실린 글이 섞여 있을 수 있다`(줄 앞 표지 없음) |
| 남긴 글의 줄 앞 표지 | `> `(줄마다 · 원래 줄 차례 · 길이 상한 없음 · 줄 끝 `\r` 은 뗀다) |
| 답 입력 파일을 못 읽은 줄 | `- 남긴 글을 확인하지 못했다 — 답 입력 파일(<절대경로>)을 읽지 못함`(결과 파일에만 · 화면에 내지 않는다) |
| 결과 파일에서 묶음의 자리 | `## intent-critic` 절의 공시 줄들과 커밋 줄 뒤, 질문 표 앞 — 빈 줄 하나, 머리 줄, (통째 갈래면) 알림 줄, `> ` 줄들. 남길 줄이 하나도 없으면 통째 갈래라도 묶음을 내지 않는다 — 머리 줄도 알림 줄도 없다(설계 D59) |
| 답 입력 파일이 없을 때 | 질문 기록에 `record_ran` 이 있으면 「남긴 글을 확인하지 못했다」 줄. 질문 기록에 `record_ran` 이 없거나 질문 기록을 읽지 못했으면 아무 줄도 내지 않는다 — 답 기록 걸음이 돌았는지 가를 수 없다(설계 D62) |
| 답 입력 파일 이름 | `intent-answers.txt`(세션 폴더 — reference 가 `record --answers "$RD/intent-answers.txt"` 로 넘기는 파일). `render` 는 이 고정 이름을 읽는다 |
| 커밋 앞 쓰기 실패 화면 줄 | `질문 기록을 쓰지 못해 답 파일 <n>개를 커밋하지 않았다 — <사유>(파일은 남겼다)` — `<n>` 은 이번 실행이 쓴 답 파일 수(0 이어도 같은 줄) |
| 커밋 결과 덧쓰기 실패 화면 줄 | `질문 기록에 커밋 결과를 적지 못했다 — <사유>` — 커밋 줄 바로 뒤 |
| `<사유>` | 그 `OSError` 의 `strerror`(없으면 예외 이름) — `_one_line` 으로 접는다 |
| `record` 의 종료 코드 | 두 실패 갈래만 1, 그 밖은 지금처럼 0. 마지막 줄 `record: <n>` 은 두 갈래에도 낸다 |
| 질문 기록 원자 쓰기 | 같은 폴더에 `tempfile.mkstemp(dir=<rd>, prefix="intent-questions.yaml.tmp.")`(O_EXCL — 링크를 따라가지 않고 새로 만든다) → 쓰기 → `flush` · `os.fsync` → 닫기 → `os.replace`. 어느 걸음에서든 실패하면 임시 파일을 지우고 `OSError` 를 다시 던진다. 이름이 `intent-` 로 시작해 P2 의 `intent-*` 지우기가 남은 것을 치운다 |
| 커밋 앞 기록의 `commit` | 빈 글(`""`) · `commit_line` 없음. 덧쓰기가 그 둘을 채운다 |
| 커밋 앞 기록이 실패한 실행의 결과 줄 | `intent-critic — 질문 <k>개를 물었지만 답 기록을 끝내지 못했다 · 작업 트리의 답 자리에 커밋되지 않은 답 파일이 있으면 커밋한다`(`<k>` = `state: ask` 인 질문 수) · `commit: -` |
| 커밋 해시를 모르는 실행 | 결과 줄 끝 ` · 커밋 해시 확인 못 함` · `commit: unknown — 커밋 해시 확인 못 함`(「답함」 행이 있는데 `commit` 이 비었을 때) |
| 「질문 없음」 꼬리 | 이미 「잘못 골랐다」 답이 있어 거른 질문만: ` — 이미 「잘못 골랐다」 답이 있는 질문은 다시 묻지 않았다` · 그 밖에 이미 답한 질문만: ` — 이미 답한 질문은 다시 묻지 않았다` · 둘 다: ` — 이미 「잘못 골랐다」 답이 있는 질문과 그 밖에 이미 답한 질문은 다시 묻지 않았다`. 「잘못 골랐다」 쪽 = `state == "wrong-choice-filtered" and not handed`(결과 파일의 그 목록과 같은 조건), 그 밖 = 나머지 `FILTERED_STATES` |
| 답 폴더 알림 | `답 폴더를 읽지 못함 — 전에 한 답을 확인 못 함`(폴더가 없으면 지금처럼 말없이 「답 없음」. 있는데 폴더가 아니거나 `stat` · `listdir` 이 `FileNotFoundError` 밖의 `OSError` 면 이 줄) |
| 답 파일 머리 값의 종류 | `answered_at` · `target` 은 글(`str`) 또는 없음(`None` → `""`)만 받는다. 그 밖(목록 · 사전 · 날짜 · 수)은 읽지 못한 답 파일 |
| 답 파일 읽기 상한 | `ia.HANDED_MAX_BYTES`(같은 상수 — 새 상수를 두지 않는다). 연 뒤 `fstat` 크기와 실제로 읽은 바이트 수(상한+1 까지 읽는다) 둘 다로 본다 |
| 넘겨받은 답의 입출력 오류 사유 | `입출력 오류(<예외 이름>)` → 공시 `넘겨받은 답을 읽지 못함 — 입출력 오류(PermissionError)` 꼴(설계 D60 · AC9). 열기는 `os.open(path, O_RDONLY | O_NOFOLLOW)` → `fstat` 이 보통 파일 · 상한 안인지 다시 본다 |
| 넘겨받은 답 열쇠의 파일 이름 몫 | `name.isprintable()` 이 거짓인 항목이 하나라도 있으면 그 파일 전체를 받지 않는다 — 공시 `넘겨받은 답을 읽지 못함 — 꼴이 맞지 않음`(지금처럼 항목 하나라도 틀리면 파일 전체 · 설계 D61 · AC9) |
| 넘겨받은 답의 두 답 | `ia.HANDED_ANSWERS = ("의도다", "잘못 골랐다")` — `ANSWERS[:2]` 를 대신한다(제안 4). `ia._handed_entry` 는 `ia.handed_entry` 로 이름을 바꾸고 부르는 두 자리를 함께 고친다(제안 10) |
| 넘겨받은 답 파일 경로의 빈칸 | `setup-qg.sh` 의 모르는 인자 갈래가, 바로 앞 인자가 `--answered` 의 값이었으면 `❌ 모르는 인자다(Unknown argument): <인자> — --answered 의 경로에 빈칸이 있으면 받지 못한다` 를 낸다(rc 1 그대로) |
| 같은 이름 사본 고르기의 돌려주는 값 | `_same_name_drops(repo, refs, end) -> (drops: set, folded: int, diverged: List[str], carry: Dict[str, str])` — `carry` 는 남긴 원격 ref(전체 이름) → 그 로컬 끝 sha |
| 후보 | `_tips(repo, end, notes=None) -> Optional[List[dict]]` — 키 `name` · `sha` · `time` · `local_sha`(앞섬 · 범위 밖 갈라짐으로 남긴 원격 후보만, 아니면 None) · `unpushed`(bool). `notes` 키: `folded` · `diverged` · `push_unknown`(가르는 물음이 실패했을 때 로컬 후보 수, 아니면 0) |
| 올리지 않은 브랜치를 가르는 git 물음 | 로컬 후보가 하나 이상일 때만 한 번: `git rev-list <로컬 후보 끝들…> --not --remotes --`. 출력에 든 끝이 올리지 않은 것. 실패 · 시간 한도면 로컬 후보를 모두 올리지 않은 것으로 — 원격 사본과 끝이 같아 하나로 접힌 로컬 브랜치도(설계 D62) · `notes["push_unknown"]` = 로컬 후보 수(같은 이름 사본을 가른 뒤 남은 로컬 후보 — 뒤처져 버려진 로컬은 세지 않는다) |
| 항목에 더하는 키 | `_branch_entry` 의 항목: `doc_paths`(의도 문서를 고르는 경로 — 보통 브랜치는 `paths` 와 같다 · 원격 후보는 `git log --name-only <원격 끝> --not <기본> <리뷰 끝>` · 올리지 않은 브랜치는 빈 집합) · `paths`(겹침에 쓰는 경로 — 원격 후보는 두 끝에서 모은 합) · `local_sha` · `unpushed` |
| 작업 줄 표시 | `### <이름> · <sha7> · <날짜> · <PR 표시> · <표시>` — 올리지 않은 브랜치 `올리지 않은 브랜치 — 내용은 읽지 않았다`, 원격 후보 `원격에 없는 로컬 커밋은 파일 이름만 겹침에 넣었다 — 내용은 읽지 않았다`. diff 를 싣지 않는 겹치는 파일은 `#### 겹치는 파일 <경로>` 머리만 둔다 |
| 브랜치 수 줄 | `그 밖의 브랜치 <n>개 — 겹침 · 의도 문서 없음`(내용을 다 읽은 브랜치만) · `올리지 않은 브랜치 <n>개 — 겹침 없음 · 내용은 읽지 않았다` · `원격에 없는 로컬 커밋이 있는 브랜치 <n>개 — 겹침 · 의도 문서 없음 · 그 커밋은 내용을 읽지 않았다`. 0 이면 내지 않는다 |
| 「확인 못 함」 새 줄 | `올린 브랜치인지 가르지 못해 로컬 브랜치 <n>개의 내용을 읽지 않았다` · `브랜치 목록을 읽지 못해 열린 PR <n>개를 견주지 못했다`(`<n>` = 받은 열린 PR 수 — 끝 커밋 이름표를 읽지 못한 실행은 PR 마다의 「그 브랜치가 이 리포에 없다」 를 내지 않는다) · 읽지 못한 문서 `<브랜치> 의 <문서> 를 읽지 못함 — <사유>`(사유: 시간 한도 · `심볼릭 링크` · `보통 파일이 아님` · `여러 줄 또는 제어 문자` · `절대 경로` · `상위 경로(..)` · `.git 아래` — `추적 안 된 파일 또는 없음` 은 싣지 않는다) |
| 고정 줄 | `다른 컴퓨터의 작업은 볼 수 없음 · 이 컴퓨터의 올리지 않은 브랜치는 이름과 겹치는 파일만 본다` |
| 의도 출처의 시간 한도 줄 | `원문 없음 — 시간 한도로 읽지 못함` · `로드맵 없음 — 시간 한도로 읽지 못함`(실제 거부가 하나라도 있으면 지금의 「링크 거부」 가 이긴다) |
| 표지 없는 옛 원문 | 원문 절 머리(`_ORIGIN_HEADS`)는 찾았는데 그 절들의 글에 `🗣` 도 `☑` 도 없으면 지금 줄 `직접 쓴 말 · 고른 라벨을 가르지 못함` 을 낸다 |
| 머리를 못 읽은 바뀐 문서 | `review_breadth` 가 넷째 값으로 그 수를 돌려주고, `_breadth` 가 `의도 문서인지 확인 못 한 문서 <n> — 머리를 읽지 못함` 을 낸다 |
| 리뷰 기록 빼기 | `io_.REVIEW_RECORD_TYPE = "roadmap-review"` — `review_breadth` 의 의도 문서 고르기와 `other_teams._intent_docs` 가 함께 쓴다 |
| 좁은 리뷰의 넓이 글(`intent-scope.md`) | 차례대로 처음 맞는 것: 바뀐 파일 목록을 모르거나 비었으면 `좁게 본다 — 바뀐 파일 목록을 모른다`(설계 D58) · 문서 아닌 파일이나 모델이 읽는 파일이 있으면 `좁게 본다 — 코드가 바뀐 PR` · 모두 문서이고 머리를 읽지 못했거나 파일 자체를 읽지 못한(추적되지 않음 · 링크 · 보통 파일 아님 · 시간 한도) 문서가 있으면 `좁게 본다 — 의도 문서인지 확인 못 한 문서가 있다`(설계 D62 · D63 — 공시 줄은 지금처럼 사유별로 따로) · 그 밖(모두 문서인데 의도 문서가 없음) `좁게 본다 — 의도 문서가 바뀌지 않았다` |
| 설정 도움말 | `config` 의 `help` 를 `docs 답 자리 · 입력 상한 · 다른 팀 기록 상한 · 의도 문서 표시를 읽는다` 로 |
| 질문 앞 머리말 첫 줄 | `<리뷰 범위> 리뷰` — 브랜치 범위면 `git rev-parse --abbrev-ref HEAD`(분리된 HEAD 면 `HEAD <해시 앞 8자>`) · 세션 범위 `이번 세션에서 바뀐 파일 <n>개` · 토픽 범위 `토픽 <토픽 열쇠>` · `--paths` 범위 `고른 파일 <n>개` |

## 설계가 넘긴 것의 처리

| 설계 「Deferred to plan」 | 처리 |
|---|---|
| 과제 나누기 — PR 을 둘로 나눌지 | 한 PR 로 간다(설계 Approaches 1). 과제를 파일 묶음 둘(Task 1–8 · Task 9–12)로 나눠 리뷰하고, 두 묶음은 서로의 인터페이스를 쓰지 않는다. 나누면 README · CHANGELOG · 판 · 테스트 파일이 겹쳐 R7 과의 순서 맞추기가 두 번 든다 |
| 구분 글자의 정확한 집합 · 새 줄의 정확한 글자 · 올리지 않은 브랜치를 가리는 git 명령 | 「정한 이름과 꼴」 표 |
| 첫 과제 — 가벼운 다시 확인 | 계획 담당자가 2026-11-26 에 했다(결과는 Task 0 머리). 구현 시작 때 R7 이 머지된 코드로 Task 0 을 한 번 더 돈다 |

설계 본문이 계획에 맡긴 그 밖의 자리: R6 머지 뒤 리뷰 제안 가운데 동작이 달라지지 않는 열(D8) — 모두 받는다(Task 2 · Task 7 · PR 본문 표). 판 올림 번호 — 지휘자가 준다(Task 13).

## R7 과 닿는 자리

R7 계획(그 브랜치의 `docs/superpowers/plans/2026-11-26-qg-planted-text-suite-lock.md`)이 바꾸는 자리 가운데 이 계획의 과제와 닿는 곳이다. R7 이 먼저 머지된다 — 이 계획의 과제는 R7 이 바꾼 뒤의 글 위에서 고친다.

| 파일 · 자리 | R7 이 바꾸는 것(R7 과제) | 이 계획이 바꾸는 것(과제) | 맞추는 법 |
|---|---|---|---|
| `references/intent-critic.md` 답 기록 문단(「번호와 정체가 맞지 않는 머리 줄은 받지 않는다 — …」 와 같은 문단) | 답 펜스의 「새로 고른 16진수 8자」 문장을 `qg_nonce.py hex` 값 받기 문장으로 · here-doc 끝 표지 `QG_INTENT_ANSWERS_<8 hex>`(Task 2) | 「어느 답에도 실리지 않고」 문장을 남긴 글 동작으로(Task 6) | 같은 문단의 다른 문장이다 — R7 의 값 받기 문장은 그대로 둔다 |
| `references/intent-critic.md` I7 돌려주기 | `commit:` 이 커밋 해시일 때의 push 안내를 한 문장으로(`posted:` 가르기 없앰)(Task 7) | 남긴 글 묶음 보이기 · `commit: unknown` 할 일 · 「물었지만 끝내지 못했다」 할 일 · `묻지 않음` 행 문장 가르기(Task 6) | R7 의 push 문장은 그대로 두고 그 옆에 불릿을 더한다. Task 6 의 테스트가 R7 의 `i7_sentence` 단언과 함께 통과해야 한다 |
| `references/intent-critic.md` 질문 dispatch · 칸 채우기 · 응답 쓰기 | 칸이 경로가 되고 `slots` · `check-output --call` 을 쓴다(Task 7) | 닿지 않음 — 이 계획은 머리말 첫 줄(질문 앞 글)만 고친다(Task 6) | — |
| `references/state-file-format.md` | 「같은 폴더의 다른 파일」 목록에 새 세션 파일 · 생명주기 2 문장(Task 5 · 7 · 10 · 14) | 결과 줄 목록 · 결과 절에 남긴 글 묶음 · `commit` 값 · `state` 뜻 문장(약 142행 · Task 5) | 다른 절이다. 이 계획은 새 세션 파일을 만들지 않는다(임시 파일은 `intent-*` 지우기가 치운다) |
| `scripts/intent_origin.py` `_add_origin_doc` · `_follow_roadmaps` | 본문의 표지 꼴 줄 · 표지 필드의 `-->` 무력화(Task 7) | 표지 없는 옛 원문 알림 · 로드맵 시간 한도 사유(Task 12) | 같은 함수다 — R7 의 무력화 뒤에 알림 판정을 둔다(무력화된 글에서 🗣 · ☑ 를 찾아도 같다) |
| `scripts/intent_critic.py` | `slots` 부속 명령 · `check-output --call` · `_candidates` 대조(Task 7) | `parse_answer_input` · `_answers_in_input` · `_record` · `_write_questions` · `_outcome` · `_section` · `cmd_render` · `_why` · `_prepare` 의 입력 크기 · `config` 도움말(Task 1 · 3 · 4 · 5 · 7) | 함수가 겹치지 않는다. `_parser` 는 둘 다 고친다 — R7 의 새 부속 명령 뒤에 `config` 의 `help` 만 고친다 |
| `scripts/setup-qg.sh` | `--suite-lock` 소비 · 값 검사 · 도움말 · `--answered` 를 값과 함께 건너뛰는 자리에 `--suite-lock` 도(Task 14) | 모르는 인자 갈래의 빈칸 경로 문구(Task 8) | 「바로 앞 인자가 `--answered` 의 값이었나」 표시는 `--suite-lock` 등 다른 갈래를 지나면 꺼진다 |
| `tests/test_intent_critic.py` · `test_intent_return.py` · `test_intent_critic_wiring.sh` | 칸 사본 · 대조 · I7 문장 · here-doc 이름 자리(`verdict_fence.fill_heredoc` 의 `<이름>_<8 hex>` 꼴)(Task 2 · 7) | 새 케이스 더함(Task 1–7) | 이 계획의 테스트가 reference 펜스를 뽑을 때는 R7 의 `fill_heredoc` 새 꼴을 쓴다 |
| `README.md` · `CHANGELOG.md` · `plugin.json` | 판 · 항목(Task 18) | 판 · 항목(Task 13) | 지휘자가 R7 판의 다음 번호를 준다 |

열린 PR #332 는 2026-11-24 에 머지됐고 이 브랜치의 바탕에 들어 있다(순서 맞추기 할 일 없음). 그 PR 이 고친 quality-gates 파일 가운데 이 설계의 파일과 겹치는 것은 일곱이다 — `intent_origin.py` · `other_teams.py` · 의도 점검 reference · README · `test_intent_critic.py` · `test_intent_wide.py` · `test_other_teams.py`(설계 Constraints 의 「여섯」 은 일곱의 잘못 센 수다 — 설계 글자는 고치지 않는다).

## Review Focus

설계가 함의하지만 AC 의 시험이 직접 재지 않는, 사람이 가장 먼저 부딪힐 다섯이다. 각 줄의 시험은 그 코드를 맡는 과제에 넣었다.

1. **답 입력이 CRLF 줄 끝이다**(윈도 편집기 · 붙여 넣은 글) — 머리 줄은 지금처럼 읽히고, 남긴 글의 `> ` 줄 끝에 `\r` 이 남지 않는다. 기대: 머리 줄 판정 그대로 · 남긴 줄은 `\r` 을 뗀 글(Task 4 시험 `test_leftover_crlf_input`).
2. **답 입력이 비었거나 빈 줄뿐인데 질문 기록을 읽지 못했다** — 통째로 싣는 갈래라도 실을 줄이 없으면 머리 줄 · 알림 줄만 덩그러니 남지 않는다. 기대: 묶음 없음 — 머리 줄도 알림 줄도 없다(설계 D59 · Task 4 시험 `test_leftover_blank_input_no_block`).
3. **라벨 뒤에 목록 밖 글자가 붙은 직접 쓴 답**(「의도다!」 · 「잘못 골랐다)」) — 설계의 구분 글자 집합 밖이라 라벨 없는 글로 읽히고 원문이 남는다. 기대: `answer: 지금은 모르겠다` · `answer_text` 에 원문(Task 1 시험 `test_label_followed_by_other_punctuation`).
4. **원격 사본이 이미 기본 브랜치에 든, 로컬이 앞선 브랜치** — 다른 작업인지 가르는 물음을 두 끝에서 모으므로 로컬에만 있는 커밋으로 다른 작업이 된다. 기대: 원격 사본 끝의 의도 문서 · diff 없음, 로컬 커밋이 바꾼 파일 이름만 겹침에 · 표시 붙음, 겹침이 없으면 「원격에 없는 로컬 커밋이 있는 브랜치 1개」(Task 9 시험 `test_ahead_remote_already_in_default`).
5. **같은 이름 사본이 원격 둘(origin · upstream)에 있고 로컬이 둘보다 앞섰다** — 원격 사본마다 따로 갈라 로컬 끝이 두 번 버려져도 예외가 없고, 로컬에만 있는 커밋의 내용은 어느 후보에서도 실리지 않는다. 기대: 원격 후보 각각에 표시 · 로컬 커밋에 심은 글 없음(Task 9 시험 `test_ahead_of_two_remotes`).

## 테스트할 자리

설계문서에 `## 테스트할 자리` 절이 없다(`docs/testing.md` 가 요구한다) — 이 표가 그 자리를 대신하고, PR 본문에 같은 표를 싣는다. 보안 갈래(믿지 않는 입력의 검증 · 경로와 링크의 울타리 · 올리지 않은 글이 git 으로 새지 않는가)의 확인은 변이 넷(삭제 · 추가 · 반전 · 형태)과 양성 대조로 이빨을 본다.

| 자리 | 확인할 동작 | 잡는 것 · 못 잡는 것 | 테스트 파일 |
|---|---|---|---|
| `intent_critic.py record` 명령줄 | 라벨 읽기 · 어긋난 머리의 원문과 「잘못 골랐다」 · 커밋 앞 기록 · 덧쓰기 · 두 실패 갈래의 화면 줄과 종료 코드 · 원자 쓰기 | 스크립트 출력 · 질문 기록 · git 끝 커밋 / 실제 디스크가 찬 경우(쓰기 실패는 `os` 호출에 실패를 넣어 잰다) | `tests/test_intent_return.py` · `tests/test_intent_critic.py`(케이스 더함) |
| `intent_critic.py render` 명령줄 | 남긴 글 도출 · 묶음의 꼴 · 결과 줄 · `commit` 값 · 화면 출력이 결과 줄로 끝남 | 결과 파일 · 돌려주는 꼴 · 표준 출력 / 사람이 그 묶음을 실제로 보는지(reference 문장으로 지킴) | `tests/test_intent_return.py`(케이스 더함) |
| `intent_answers.py` 함수 | 라벨 칸 무력화 · 답 파일 읽기 상한 · 값의 종류 · 답 폴더 알림 · 넘겨받은 답의 열쇠 · 입출력 오류 · 연 뒤 다시 보기 | 반환값 · 공시 / 다른 프로세스의 실제 경합(링크 바꿔치기는 연 뒤 크기 · 종류 검사로 잰다) | `tests/test_intent_critic.py` · `tests/test_intent_handed.py`(케이스 더함) |
| 의도 점검 reference 문장 | 답 기록 문단 · `record` 출력 표 두 행 · 머리말 첫 줄 · I7 의 묶음 보이기와 할 일 둘 | 문장의 가장 짧은 낱말 / 모델이 실제로 따르는지 | `tests/test_intent_critic_wiring.sh`(케이스 더함) |
| 세션 파일 꼴 문서 · README | 새 결과 줄 · `commit` 새 값 · `묻지 않음` 뜻 · 고정 줄 · 빈칸 경로 한계 | 문서 글자 / — | `tests/test_intent_return.py`(`TestReturnDoc` — 코드 상수에서 도출) · `tests/test_intent_critic_wiring.sh` |
| `setup-qg.sh` | 빈칸 경로 멈춤 문구 | 스크립트 출력 · 종료 코드 | `tests/test_setup_qg.sh`(케이스 더함) |
| `other_teams.collect` | 올리지 않은 브랜치 · 앞섬 · 갈라짐(범위 안 · 밖) · 가르는 물음 실패 · 조상 물음 실패 · 수 줄 · 읽지 못한 문서 사유 · 브랜치 목록 실패 · 0개 실행 | 임시 리포의 기록 글 / 원격을 실제로 받는 경우(이 단계는 받지 않는다) | `tests/test_other_teams.py`(케이스 더함 · 픽스처 고침) |
| `intent_origin` 함수 · `prepare` | 시간 한도 사유 · 표지 없는 원문 · 머리를 못 읽은 문서 · 리뷰 기록 빼기 · 좁은 리뷰의 넓이 글 | 반환값 · 공시 · scope 칸 / — | `tests/test_intent_wide.py` · `tests/test_intent_critic.py`(케이스 더함) |

## AC 대조

AC1 · AC4 → Task 1 / AC2 · AC26 → Task 4 / AC3 → Task 3 · 5 / AC5 · AC7 · AC8 · AC9 → Task 2 / AC6 → Task 8 / AC10 → Task 5 / AC11 → Task 9 · 10 / AC12 · AC13 · AC14 → Task 11 / AC15 · AC16 · AC17 · AC18 · AC19 → Task 12(AC19 의 도움말은 Task 7) / AC20 → Task 1(T2) · 7(T1 · T5 · T7 둘째) · 9(T4 둘째) · 11(T4 첫째 · T6 · T7 첫째) · 12(T3) / AC21 → Task 2(5 · 6) · 6(18) · 7(11 · 14) · 13(PR 본문 표) / AC22 → Task 13 / AC23 → Task 3 · 4 / AC24 → Task 3 · 4 · 5 / AC25 → Task 3 / AC27 → Task 6 / AC28 → Task 10 / AC29 → Task 9.

---

### Task 0: 시작 확인

계획 담당자가 2026-11-26(브랜치 끝 1fe49c5c — 기본 브랜치 35a232e1 포함)에 본 결과 — 설계가 근거로 든 자리는 모두 그대로다:

- `other_teams.py` — `_ancestor` 는 `merge-base --is-ancestor` 로 답하고 실패 · 시간 한도면 None · `_same_name_drops(repo, refs)` 는 리뷰 끝을 받지 않고, 원격이 로컬의 조상이면 원격을 버림(묶음) · 로컬이 원격의 조상이면 로컬을 버림(묶음) · 서로 조상이 아니면 원격을 버리고 갈라짐에 남김 · 답 못 하면 둘 다 둠 · `_tips(repo, notes)` 는 리뷰 끝을 받지 않음 · `_branch_entry` 는 `git log --name-only <끝> --not <기본> <리뷰 끝>` 과 기본 브랜치와의 이름 diff 로 고름 · `_intent_docs` 는 항목의 `paths` 전체를 돌며 끝 커밋에서 읽고 시간 한도만 「확인 못 함」 에 남김 · `collect` 는 묶은 수가 있으면 항목 수와 상관없이 「묶었다」 줄을 냄 · 브랜치 목록 실패면 `by_tip` 이 None 이라 PR 마다 「그 브랜치가 이 리포에 없다」 · 고정 줄 `다른 컴퓨터 · 올리지 않은 작업은 볼 수 없음`.
- `intent_critic.py` — `_answers_in_input` 은 번호만 맞은 머리를 `(질문, 고른 답 | None, 정체가 맞지 않는 답 머리)` 로 넣고, 고른 답은 선택지 라벨일 때만 남김(직접 쓴 답이면 None) · `_row` 의 `wrong_choice` 는 `answer == "잘못 골랐다"` 이고 「답 기록 실패」 행의 `answer` 는 `failed_answer` — 선택지로 고른 「잘못 골랐다」 는 지금도 표시된다 · `parse_answer_input` 은 어긋난 머리 아래 글과 고른 것을 읽지 못한 머리 아래 글을 버림 · `_read_pick` 은 앞부분 맞춤(`startswith`)이고 라벨 없는 글은 `지금은 모르겠다` + 원문 · `QUESTION_STATES` 에 「답 기록 실패」 있음 · 질문 기록은 커밋 뒤에 한 번만(`_write` 는 여는 순간 비움) · `cmd_record` 는 늘 rc 0 · `FILTERED_STATES` 셋 · 입력 크기(`total`)에 `<answered>` 없음 · `_why` 는 줄바꿈이 있으면 `-` · `config` 도움말은 값 둘만 말함.
- `intent_answers.py` — 라벨 칸만 `_defang` 을 거치지 않음 · `read_answered` 는 크기 상한 없음 · 값을 `str()` 로 바꿈 · `listdir` 실패면 말없이 `{}` · `read_handed` 는 `lstat` 뒤 다시 열고 여는 실패를 「꼴이 맞지 않음」 으로 접음 · `_handed_key_ok` 에 제어 글자 검사 없음.
- `intent_origin.py` — 시간 한도도 `st["rejected"]` 를 세워 「원문 링크 거부」 · 로드맵은 「로드맵 링크 거부」 · 표지 알림은 원문 절 머리를 못 찾을 때만 · `review_breadth` 는 머리를 못 읽은 문서를 의도 문서 아님으로 침(설계가 「세는 함수」 라 한 것은 `frontmatter_unreadable` 판정 함수다) · 리뷰 기록을 빼지 않음 · 좁은 넓이 글은 늘 「코드가 바뀐 PR」.
- `setup-qg.sh` — 빈칸이 든 `--answered` 경로의 뒷부분은 `❌ 모르는 인자다(Unknown argument): …` 로 멈춤.
- 덧붙여 본 것: `tests/test_other_teams.py` 의 `_teams_repo` 는 `feature/other` 만 원격 사본을 갖고 나머지 다른 팀 브랜치(`feature/far` · `feature/mine-next` · `feature/squashed` …)는 로컬에만 있다 — Task 10 이 들어오면 그 브랜치들이 「올리지 않은 브랜치」 가 되어 내용을 읽던 기존 시험이 뜻을 잃는다. Task 10 Step 1 이 픽스처에 원격 사본을 세운다.

- [ ] **Step 1: 기본 브랜치를 합친 뒤 같은 자리를 다시 본다**

Run: `git fetch origin main && git merge-base --is-ancestor origin/main HEAD || git merge --no-ff origin/main`(충돌이면 멈춰 보고). 그 뒤 위 자리마다 `grep -n` 한 줄씩(예: `grep -n 'def _same_name_drops' plugins/quality-gates/scripts/other_teams.py` · `grep -n 'QG_INTENT_ANSWERS' plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md`), 그리고 「R7 과 닿는 자리」 표의 R7 쪽 변경이 들어왔는지 본다(`git log --oneline origin/main -- plugins/quality-gates/scripts/qg_nonce.py` 가 비지 않음).
Expected: R7 이 머지됐고 위 자리는 뜻이 그대로다. R7 이 아직이면 멈춰 보고한다. 동작이 달라진 자리가 있으면 멈춰 보고한다(줄 번호만 달라졌으면 진행).

---

### Task 1: 직접 쓴 답 읽기 — 라벨 읽기 · 어긋난 머리의 원문과 「잘못 골랐다」(§1 · AC1 · AC4 · T2)

**Files:**
- Modify: `plugins/quality-gates/scripts/intent_critic.py`(`parse_answer_input` · `_read_pick` · `_answers_in_input` · `_record` 의 기록하지 않는 갈래)
- Test: `plugins/quality-gates/tests/test_intent_return.py`(`TestAnswerInput` · `TestQuestionRows` 에 더함)

**Interfaces:**
- Produces:
  - `read_label(text: str) -> str` — `ia.ANSWERS` 가운데 하나. 「정한 이름과 꼴」 의 구분 글자 규칙. 앞 공백(`lstrip`)은 뗀다. `_read_pick` 이 직접 쓴 답에 쓴다.
  - `parse_answer_input(text, known) -> dict` — 키 `entries` · `orphan` · `duplicates` 는 그대로, `mismatched` 는 `[{"n": int | None, "pick": str | None, "lines": List[str]}]`(`pick` 은 라벨 · `typed` 일 때만, 아니면 None · `lines` 는 그 머리 아래 줄), 새 키 `blocks: [{"n": int | None, "accepted": bool, "lines": List[str]}]` — 첫 머리 앞 글을 뺀 모든 줄을 머리 줄째 차례대로 덮는다(`lines[0]` 이 머리 줄), 새 키 `preamble: List[str]`(첫 머리 앞 줄들). `accepted` 는 번호 · 정체가 맞는 그 번호의 첫 머리. 줄은 `\r` 을 떼지 않은 원래 글이다. Task 4 가 `blocks` · `preamble` 을 쓴다.
  - `_answers_in_input(parsed, by_n)` 의 `own` 항목 고른 답: 라벨이면 그 라벨, `typed` 면 `read_label(<그 머리 아래 글>)`, 아니면 None. 번호만 맞은 머리의 아래 글이 빈 줄뿐이 아니면 그 질문의 `answer_text` 에 그 줄들(앞뒤 빈 줄을 뗀 목록)을 싣는다.

- [ ] **Step 1: 실패하는 시험을 하나씩 쓴다** — `test_intent_return.py`:

```python
def test_typed_label_needs_separator(self):   # AC4
    # "의도다만 아닌 것 같다" → answer "지금은 모르겠다", answer_text 원문
    # "의도다 — 이유" · "의도다" · "의도다\n둘째 줄" · "의도다: x" · "의도다, x" · "의도다. x" · "의도다-x" → "의도다"
def test_label_followed_by_other_punctuation(self):   # Review Focus 3
    # "의도다!" · "잘못 골랐다)" → "지금은 모르겠다", answer_text 원문
def test_mismatched_typed_text_kept_and_wrong_choice(self):   # AC1
    # 번호 맞고 정체 틀린 머리 + pick: typed + "잘못 골랐다 — 이유\n둘째 줄"
    # → 그 질문 state "답 기록 실패" · answer "잘못 골랐다" · wrong_choice True
    #   · answer_text ["잘못 골랐다 — 이유", "둘째 줄"] · failure "정체가 맞지 않는 답 머리" · file "-"
    # 답 자리에 답 파일이 생기지 않는다
def test_mismatched_typed_not_wrong_when_text_negates(self):   # AC1
    # 같은 꼴에 "잘못 골랐다고 보진 않는다" → wrong_choice False · answer_text 원문
def test_mismatched_label_wrong_choice_kept(self):   # AC1 — 지금 동작 그대로
    # pick: 잘못 골랐다 → wrong_choice True
def test_mismatched_label_text_below_kept(self):     # AC1
    # 번호 맞고 정체 틀린 머리 + pick: 잘못 골랐다 + 그 아래 "이유 한 줄" → answer_text ["이유 한 줄"] · wrong_choice True
def test_typed_wrong_choice_survives_switch(self):   # T2
    # kill switch 켬 + 맞는 머리 pick: typed "잘못 골랐다 — 이유\n둘째 줄"
    # → answer "잘못 골랐다" · wrong_choice True · answer_text 두 줄 · failure == KILL_FAILURE % <변수 이름>
def test_typed_wrong_choice_survives_unreadable_config(self):   # T2
    # intent-config.txt 를 지운 같은 입력 → 같은 단언, failure 는 「거르기 결과 · 설정 · 답 입력 중 읽지 못한 것이 있다」
```

- [ ] **Step 2: 돌려 실패를 본다** — Run: `cd plugins/quality-gates/tests && python3 -m unittest test_intent_return.TestAnswerInput test_intent_return.TestQuestionRows -v` · Expected: 위 일곱 가운데 `test_mismatched_label_wrong_choice_kept` · `test_typed_wrong_choice_survives_*` 둘 말고는 FAIL(T2 둘은 지금 동작을 잠그는 시험이라 통과가 맞다 — Step 5 의 변이로 이빨을 본다).

- [ ] **Step 3: 구현한다** — 위 Interfaces. 기록하지 않는 갈래의 `failed` 는 `_answers_in_input` 이 낸 `own` 의 고른 답을 그대로 쓴다. `parse_answer_input` 의 `entries` 를 쓰는 다른 자리(`_input_notices` 의 `mismatched` 수)는 목록 길이로 그대로 센다.

- [ ] **Step 4: 돌려 통과를 본다** — Step 2 의 명령 + `python3 -m unittest test_intent_critic.TestRecord test_intent_handed -v`. Expected: 모두 PASS. `mismatched` 꼴이 바뀌어 고친 기존 단언이 있으면 커밋 메시지에 적는다.

- [ ] **Step 5: 지금 동작을 잠그는 시험의 이빨을 본다** — 커밋한 뒤 사본 없이 이 브랜치에서 변이를 하나씩 넣고 RED 인지 본다: ① 기록하지 않는 갈래의 고른 답을 `entry["pick"]` 으로(그러면 `answer: typed`) → `test_typed_wrong_choice_survives_*` ② 그 갈래에서 `_keep_typed` 를 부르지 않게 → 같은 시험 ③ 번호만 맞은 머리의 선택지 라벨을 고른 답으로 넣지 않게(None 으로 뒤집음) → `test_mismatched_label_wrong_choice_kept`. 각 변이 뒤 `git checkout HEAD -- plugins/quality-gates/scripts/intent_critic.py` 와 `git diff HEAD --stat` 가 빈 것을 확인한다. `PYTHONDONTWRITEBYTECODE=1` 로 돌린다.

- [ ] **Step 6: 커밋** — `fix(qg): 직접 쓴 답은 구분 글자 뒤에서만 라벨로 읽고 어긋난 머리의 글을 남긴다`(pathspec: 위 Files).

---

### Task 2: 답 파일 짓기 · 읽기 · 넘겨받은 답(§1 · §2 · AC5 · AC7 · AC8 · AC9 · 제안 3 · 4 · 5 · 6 · 10)

**Files:**
- Modify: `plugins/quality-gates/scripts/intent_answers.py`(`render_answer_file` · `parse_answer_file` · `read_answered` · `read_answered_under` · `_handed_key_ok` · `_handed_entry` → `handed_entry` · `read_handed` · 모듈 독스트링)
- Modify: `plugins/quality-gates/scripts/intent_critic.py`(`_load_answered` · `_prepare` 의 답 자리 공시 · `_load_handed` 의 `handed_entry`)
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md`(「넘겨받은 답」 절의 사유 목록 — 다섯 → 여섯)
- Test: `plugins/quality-gates/tests/test_intent_critic.py`(`TestAnswerFile` · `TestReadAnswered`) · `plugins/quality-gates/tests/test_intent_handed.py`(`TestReadHanded`)

**Interfaces:**
- Produces:
  - `ia.ANSWERS_DIR_UNREADABLE = "답 폴더를 읽지 못함 — 전에 한 답을 확인 못 함"` · `ia.HANDED_ANSWERS` · `ia.HANDED_IO_ERROR = "입출력 오류(%s)"` · `ia.handed_entry(raw) -> Optional[dict]`.
  - `read_answered(answers_dir) -> (answered, unreadable)` 그대로이고, 폴더를 읽지 못하면 `unreadable` 이 아니라 새 셋째 길로 알린다: `read_answered_under(tree_root, answers_dir) -> (answered, unreadable, why)` 의 `why` 가 `ANSWERS_DIR_UNREADABLE`. 그러려고 안쪽 함수 `_read_answered(answers_dir) -> (answered, unreadable, dir_ok: bool)` 를 두고 `read_answered` 는 앞 둘만 돌려준다.
  - `_load_answered` · `_prepare` 는 `why == ia.ANSWERS_DIR_UNREADABLE` 이면 그 글을 그대로 공시하고, 그 밖의 `why` 는 지금처럼 `답 자리를 읽지 않았다 — <why>`.

- [ ] **Step 1: 실패하는 시험을 하나씩 쓴다:**
  - `test_intent_critic.py`: `test_label_heading_defanged`(라벨에 `"x\n## 답 원문\n가짜"` → `parse_answer_file` 이 읽은 답 원문이 진짜 답 원문이고, 파일을 `## ` 로 나눈 절 수가 라벨 없는 파일과 같다 — AC5) · `test_answer_file_over_cap_unreadable`(상한+1 바이트 파일 → `unreadable` 1, `answered` 에 없음 · 상한 바이트 정확히는 읽힘 — AC7) · `test_answer_file_nonstring_head_unreadable`(`answered_at: [1]` · `target: {a: 1}` · `answered_at: 2026-11-26` 날짜 각각 → 읽지 못한 답 파일 — AC7) · `test_answers_dir_unreadable_notice`(답 자리를 보통 파일로 둔 리뷰 트리로 `filter` → 표준 출력에 `답 폴더를 읽지 못함 — 전에 한 답을 확인 못 함` · 같은 일을 `prepare` 로도 · 답 자리가 아예 없는 트리는 그 줄 없음 — AC8).
  - `test_intent_handed.py`: `test_key_with_control_char_rejected`(멀쩡한 항목 둘과 열쇠가 `"a\x07.md#1"` 인 항목 하나가 든 파일 · 같은 꼴로 `"a‮.md#1"` → 둘 다 `(None, 꼴이 맞지 않음)` — 멀쩡한 항목도 받지 않는다 · `prepare` 공시 `넘겨받은 답을 읽지 못함 — 꼴이 맞지 않음` — AC9 · 설계 D61) · `test_open_failure_is_io_error`(권한 0 인 파일 → 사유가 `입출력 오류(PermissionError)` 이고 `꼴이 맞지 않음` 이 아님 · `prepare` 공시가 `넘겨받은 답을 읽지 못함 — 입출력 오류(PermissionError)` — AC9 · 제안 6. root 로 돌면 건너뛴다) · `test_swapped_after_lstat`(제안 5 — 크기를 본 뒤 여는 사이의 바꿔치기는 두 프로세스를 맞물려 재지 않고, `unittest.mock.patch("os.lstat")` 이 「작은 보통 파일」 의 stat 을 돌려주게 한 채 실제 경로는 ① 큰 보통 파일 ② 다른 파일을 가리키는 링크로 둔다 → 둘 다 받지 않는다(①은 연 뒤의 크기 · 읽은 바이트 수로, ②는 `O_NOFOLLOW` 로). 짝: 같은 가짜 stat 에 실제로 작은 보통 파일이면 받는다).
  - 보안 갈래(라벨 무력화 · 상한 · 열쇠 · 연 뒤 검사): 위 시험마다 변이 넷(검사 지우기 · 반대 조건 · 상한을 `>=` 에서 `>` 로 바꾸는 형태 · 무력화를 라벨에만 두 번 거는 추가)을 하나씩 넣어 RED, 손대지 않은 코드 GREEN(양성 대조).

- [ ] **Step 2: 돌려 실패를 본다** — Run: `cd plugins/quality-gates/tests && python3 -m unittest test_intent_critic.TestAnswerFile test_intent_critic.TestReadAnswered test_intent_handed.TestReadHanded -v` · Expected: 새 케이스 FAIL.

- [ ] **Step 3: 구현한다** — 위 Interfaces 와 「정한 이름과 꼴」 의 상한 · 값의 종류 · 입출력 오류 · 열쇠 행. 모듈 독스트링에 `read_handed` 를 더한다(제안 3). reference 「넘겨받은 답」 절의 「읽지 못하는 사유는 다섯이다」 를 여섯으로 고치고 `입출력 오류(<예외 이름>)` 를 든다.

- [ ] **Step 4: 돌려 통과를 본다** — Step 2 + `python3 -m unittest test_intent_wide.TestAnswerOddValues test_intent_return -v` · `bash test_intent_critic_wiring.sh`. Expected: 모두 PASS.

- [ ] **Step 5: 변이 넷 · 양성 대조** — Step 1 의 보안 갈래 변이를 이 브랜치에서 하나씩(커밋한 뒤, 매번 `git checkout HEAD -- <파일>` · `git diff HEAD --stat` 빈 것 확인, `PYTHONDONTWRITEBYTECODE=1`). 결과(변이마다 RED 인 시험 이름)를 커밋 메시지 본문에 적는다.

- [ ] **Step 6: 커밋** — `fix(qg): 답 파일 읽기에 넘겨받은 답과 같은 방어를 두고 답 폴더를 못 읽으면 알린다`.

---

### Task 3: 질문 기록 — 원자 쓰기와 쓰는 차례(§1 · AC3 · AC23 · AC24 · AC25)

**Files:**
- Modify: `plugins/quality-gates/scripts/intent_critic.py`(`_write_questions` · `_save_record` · `_record` · `cmd_record`)
- Test: `plugins/quality-gates/tests/test_intent_return.py`(새 클래스 `TestRecordOrder`)

**Interfaces:**
- Consumes: Task 1 의 `_answers_in_input`.
- Produces:
  - `_write_atomic(path: str, text: str) -> None` — 「정한 이름과 꼴」 의 원자 쓰기. `_write_questions` 는 이것만 쓴다.
  - `_record(args) -> (notices: List[str], count: int, rc: int)`, `cmd_record` 는 공시 · `record: <count>` 를 내고 `rc` 로 끝난다.
  - 질문 기록 키: 커밋 앞 기록에 `record_ran: true` · 질문마다 상태 · 답 · `answer_text` · `failed_answer` · `failure` · `file` · `record_notices` 를 모두 싣고 `commit: ""`. 덧쓰기는 `commit` · `commit_line` 만 바꾼다. 답 파일이 하나도 생기지 않은 실행(쓰기 실패 · 기록하지 않는 갈래 · 받은 답 없음)은 지금처럼 한 번만 쓰고, 그 한 번의 기록에도 `record_ran: true` 를 싣는다 — kill switch · 준비 파일 · 설정 · 답 입력을 읽지 못한 갈래도 질문 기록을 읽었으면 「답 기록 걸음이 돌았다」 이다(지금 코드가 갈래를 가르기 전에 세우는 그 표시). 그래서 그 실행은 Task 4 · 5 에서 통째 갈래나 「물었지만 답 기록을 끝내지 못했다」 로 가지 않는다.
  - Task 4 · 5 가 기대는 신호: 커밋 앞 쓰기가 실패하면 질문 기록은 거르기 결과 그대로(`record_ran` 없음).

- [ ] **Step 1: 실패하는 시험을 하나씩 쓴다** — `TestRecordOrder`. 쓰기 실패는 `intent_critic.main([...])` 을 같은 프로세스에서 부르고 `unittest.mock.patch` 로 표준 라이브러리 호출에 넣는다(이 레포의 함수는 바꾸지 않는다): 여는 단계 실패는 세션 폴더를 `chmod 0o555`(root 면 건너뜀), 쓰는 도중 실패는 `os.fsync` 에 `OSError(28, "No space left on device")`, 바꿔치기 실패는 대상이 `intent-questions.yaml` 인 `os.replace` 호출에만 — 몇 번째 호출에 넣을지는 케이스마다 센다.

```python
def test_pre_commit_record_has_rows_and_empty_commit(self):   # AC3
    # 답한 질문 · 답하지 않은 질문이 함께 있는 입력. 커밋 뒤 덧쓰기를 실패시키고
    # 질문 기록을 읽어: 답한 질문 state answered · answer · file · (typed 면 answer_text) / 답하지 않은 질문 state ask
    # / record_ran True / commit ""
def test_post_commit_overwrite_failure(self):   # AC3
    # 둘째 os.replace(대상 intent-questions.yaml) 실패 → 표준 출력 차례: … "답 파일 1개를 커밋했다(<해시>)",
    # "질문 기록에 커밋 결과를 적지 못했다 — No space left on device", "record: 1" · rc 1 · 예외 없음
    # · 세션 폴더에 intent-questions.yaml.tmp.* 없음 · 커밋 표지 파일 같은 새 파일 없음(세션 폴더 파일 목록이 실행 앞 + 결과물만)
def test_post_commit_overwrite_failure_after_commit_failure(self):   # AC3 · AC25
    # 커밋을 실패시키고(답 자리를 git 이 무시하게) 덧쓰기도 실패 → "답 파일을 커밋하지 못했다 — …(파일은 남겼다)" 뒤
    # "질문 기록에 커밋 결과를 적지 못했다 — …" · rc 1
def test_commit_failure_rows_answered(self):   # AC25
    # 커밋만 실패 → 덧쓰기 성공, 답한 질문 state answered · commit "failed — <사유>" · commit_line 그 줄
def test_pre_commit_write_fails_no_commit(self):   # AC24
    # 첫 os.replace 실패 → 브랜치 끝 커밋이 실행 앞과 같다 · 답 자리에 답 파일 1개(추적 안 됨) ·
    # "질문 기록을 쓰지 못해 답 파일 1개를 커밋하지 않았다 — No space left on device(파일은 남겼다)" · rc 1
    # · 질문 기록 바이트 == 실행 앞 바이트(거르기 결과) · 임시 파일 없음
def test_pre_commit_write_fails_without_answer_files(self):   # AC24 끝 문장
    # 받은 답 없이(머리 줄 없는 입력) 한 번만 쓰는 쓰기를 실패 → "질문 기록을 쓰지 못해 답 파일 0개를 커밋하지 않았다 — …" · rc 1
def test_atomic_write_keeps_previous_bytes(self):   # AC23
    # 여는 단계 실패(chmod) · 쓰는 도중 실패(fsync) 각각: 질문 기록 바이트가 앞 기록 그대로 · 임시 파일 없음
    # · 커밋 앞 기록이 있는 상태에서 덧쓰기 도중 실패 → 커밋 앞 기록 바이트 그대로
def test_blocked_single_write_has_record_ran(self):   # 과제 사이 이음매
    # kill switch 켬 · 설정 파일 지움 각각 → 질문 기록에 record_ran True · commit 칸이 지금 값 그대로
def test_state_values_unchanged(self):   # AC3
    # ic.QUESTION_STATES · ic.RETURN_OUTCOMES 가 아는 글자 값 튜플과 같다
```

- [ ] **Step 2: 돌려 실패를 본다** — Run: `cd plugins/quality-gates/tests && python3 -m unittest test_intent_return.TestRecordOrder -v` · Expected: FAIL(`test_state_values_unchanged` · `test_commit_failure_rows_answered` 는 지금도 통과가 맞다).

- [ ] **Step 3: 구현한다** — 위 Interfaces 와 「정한 이름과 꼴」 의 화면 줄 · 종료 코드 · 원자 쓰기. `_save_record` 의 쓰기도 같은 실패 처리(화면 줄 + rc 1)를 탄다 — 그 갈래의 `<n>` 은 0.

- [ ] **Step 4: 돌려 통과를 본다** — Step 2 + `python3 -m unittest test_intent_critic.TestRecord test_intent_return test_intent_handed -v`. Expected: PASS.

- [ ] **Step 5: 커밋** — `fix(qg): 질문 기록을 커밋 앞에 원자 쓰기로 쓰고 커밋 뒤에는 커밋 결과만 덧쓴다`.

---

### Task 4: 남긴 글 — 도출과 싣는 꼴(§1 · AC2 · AC26 · AC23 · AC24)

**Files:**
- Modify: `plugins/quality-gates/scripts/intent_critic.py`(새 `_leftover` · `_section` · `cmd_render`)
- Test: `plugins/quality-gates/tests/test_intent_return.py`(새 클래스 `TestLeftover`)

**Interfaces:**
- Consumes: Task 1 의 `parse_answer_input(...)["blocks"]` · `["preamble"]`, Task 3 의 `record_ran` 신호.
- Produces:
  - `_leftover(rd: str, data: Optional[dict], mode: str) -> Optional[dict]` — None(묶음 없음) · `{"unread": <절대경로>}` · `{"lines": List[str], "whole": bool}`. 규칙:
    - 범위 모드면 None.
    - 답 입력 파일이 없으면: 질문 기록에 `record_ran` 이 있으면 `unread`, 질문 기록에 그 표시가 없거나 질문 기록을 읽지 못했으면 None(설계 D62). 있는데 읽지 못하면 `unread`.
    - `whole` = 질문 기록이 없음(None) 또는 `record_ran` 없음. 그때 `lines` = 답 입력의 빈 줄 아닌 줄 전부.
    - 아니면 `known` = `state` 가 `ask` · `answered` 이고 `n` 이 정수인 질문의 `{n: id}`, `answered_ns` = `state == "answered"` 인 `n`. `parse_answer_input(text, known)` 의 `preamble` 과, `accepted and n in answered_ns` 가 아닌 `blocks` 의 줄 가운데 빈 줄 아닌 줄.
    - 줄은 끝 `\r` 을 뗀다. `lines` 가 비면 None.
  - `_section(..., leftover=None)` — 「정한 이름과 꼴」 의 자리 · 꼴로 묶음을 넣는다. `cmd_render` 는 화면 출력(공시 · 결과 줄)을 바꾸지 않는다.

- [ ] **Step 1: 실패하는 시험을 하나씩 쓴다** — 질문 셋을 묻고 `record` → `render` 를 진짜로 돌린다(쓰기 실패가 필요한 케이스만 Task 3 의 넣는 법). 남긴 줄 읽기는 결과 파일에서 머리 줄 다음의 `> ` 줄들을 모으는 시험 도우미 `_leftover_lines(result_text) -> List[str]`(표지를 뗀 글)로 한다.

```python
# 경우마다 (AC2) — 각 케이스: 그 글의 줄이 _leftover_lines 에 있다 · 받아들여 답 파일이 된 머리 줄은 없다
def test_leftover_mismatched_identity(self): ...      # 번호 맞고 정체 틀린 머리와 그 아래 글
def test_leftover_unknown_number(self): ...           # 붙일 질문이 없는 머리와 그 아래 글
def test_leftover_wrong_identity_when_matched_exists(self): ...
def test_leftover_duplicate_header(self): ...         # 더 나온 같은 번호 머리와 그 아래 글
def test_leftover_preamble(self): ...                 # 첫 머리 앞의 글
def test_leftover_pick_unread(self): ...              # 번호 · 정체 맞고 pick 을 못 읽은 머리 아래 글
def test_leftover_blocked_branch(self): ...           # kill switch · 설정 못 읽음 각각 — 받은 답의 머리 줄과 글 모두
def test_leftover_answer_write_failure(self): ...     # 답 자리를 쓸 수 없게 해 답 파일이 생기지 않은 질문의 답
def test_leftover_questions_unreadable(self):         # AC2 · AC23
    # record 뒤 intent-questions.yaml 을 지우고 render → status uncountable · 결과 줄 UNREADABLE · 질문 행 없음
    # · commit "-" · 남긴 글 = 답 입력의 빈 줄 아닌 줄 전부 · 머리 줄 바로 아래 줄이 통째 알림 줄(표지 없음)
def test_leftover_pre_commit_failure(self):           # AC24 · AC26
    # 커밋 앞 쓰기 실패 → 남긴 글 = 답 입력의 빈 줄 아닌 줄 전부(답 파일이 남은 질문의 글 포함)
    # · 머리 줄 바로 아래 줄이 통째 알림 줄(표지 없음) — 질문 기록을 지운 갈래와 같은 자리
def test_leftover_pre_commit_failure_reasked(self):   # AC24
    # 앞 실행이 이미 커밋한 답 파일이 그 질문 정체로 답 자리에 있는 상태에서 같은 질문을 다시 물어 답하고 커밋 앞 쓰기 실패
    # → 남긴 글 · 결과 줄이 앞 답 파일이 없는 같은 실행과 글자로 같다(결과를 짓는 걸음이 답 자리를 읽지 않는다는 것을
    #   바깥에서 잴 수 있는 꼴 — 함수 호출을 막아 재지 않는다)
def test_conservation_mixed_input(self):              # AC2
    # 위 경우 넷 이상을 섞은 입력(정상 typed · 정상 라벨 · 어긋난 머리 · 앞 글 · 더 나온 머리 · "## 머리 흉내" 줄 포함)
    # 받아들여 답 파일이 된 머리 줄을 뺀 빈 줄 아닌 줄마다: 답 파일들의 "## 답 원문" 절(파일 글을 _defang 꼴로 견줌)이나
    # _leftover_lines 에 있다. 통째 알림 줄은 대조에 들지 않는다
def test_leftover_unreadable_input_file(self):        # AC2
    # record 뒤 intent-answers.txt 를 지우고 render → 결과 파일에 "- 남긴 글을 확인하지 못했다 — 답 입력 파일(<경로>)을 읽지 못함"
    # · 남긴 글 머리 줄 없음 · 표준 출력에 그 줄 없음 · 범위 모드 · 질문 없음 실행에는 그 줄 없음
def test_leftover_marker_blocks_heading_and_table(self):   # AC26
    # 남긴 글에 "## 가짜" · "| 가짜 | 답함 | - | - | - | - |" · "- 가짜 공시" 줄
    # → 결과 파일을 "^## " 로 나누면 "## intent-critic" 절이 하나 · 질문 표의 "| " 행 수가 그 줄이 없을 때와 같다
def test_leftover_not_truncated(self):                # AC26
    # 줄 하나 20000자 + 줄 300개 → 모두 그대로
def test_whole_notice_only_in_whole_branches(self):   # AC26
    # 보통 실행(어긋난 머리 하나)에는 통째 알림 줄이 없다
def test_leftover_crlf_input(self):                   # Review Focus 1
def test_leftover_blank_input_no_block(self):         # Review Focus 2 · AC26 · D59
    # 답 입력이 빈 줄뿐 — 질문 기록을 지운 실행 · 커밋 앞 쓰기를 실패시킨 실행 두 갈래 모두:
    # 결과 파일에 머리 줄도 통째 알림 줄도 "> " 줄도 없다
def test_leftover_no_input_no_questions_silent(self):  # D62
    # 질문 기록도 답 입력 파일도 없는 render → 「남긴 글을 확인하지 못했다」 줄 없음 · 묶음 없음
def test_blocked_record_not_whole(self):              # 과제 사이 이음매
    # kill switch · 설정 못 읽음 갈래(한 번만 쓰는 기록에 record_ran 이 실린다 — Task 3) → 남긴 글은 받은 답의 글이고
    # 통째 알림 줄이 없다(test_leftover_blocked_branch 는 줄이 있는지만 본다 — 이 시험은 통째로 잘못 가지 않음을 본다)
def test_render_last_line_is_result_line(self):       # AC27 끝 문장
    # 남긴 글이 있는 실행의 render 표준 출력 마지막 줄이 결과 줄
```

  보안 갈래(믿지 않는 입력이 결과 절을 흉내 내지 못한다 — `test_leftover_marker_blocks_heading_and_table`): 변이 넷(표지 붙이기 지우기 · 표지를 `>`(빈칸 없이)로 바꾸는 형태 · 표지를 첫 줄에만 붙이는 반전 · 머리 줄을 `## ` 로 시작하게 하는 추가) RED, 양성 대조 GREEN.

- [ ] **Step 2: 돌려 실패를 본다** — Run: `cd plugins/quality-gates/tests && python3 -m unittest test_intent_return.TestLeftover -v` · Expected: FAIL.

- [ ] **Step 3: 구현한다** — 위 Interfaces.

- [ ] **Step 4: 돌려 통과를 본다** — Step 2 + `python3 -m unittest test_intent_return test_intent_critic test_intent_wide -v`. Expected: PASS.

- [ ] **Step 5: 변이 넷 · 양성 대조** — Step 1 의 보안 갈래 변이(Task 2 Step 5 와 같은 절차).

- [ ] **Step 6: 커밋** — `fix(qg): 답 파일에 실리지 않은 답 입력의 글을 결과 파일에 남긴다`.

---

### Task 5: 결과 줄과 `commit` 값 · 세션 파일 꼴 문서(§1 · §3 · AC3 · AC10 · AC24)

**Files:**
- Modify: `plugins/quality-gates/scripts/intent_critic.py`(`_outcome` · `cmd_render` · 새 상수)
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md`(결과 줄 목록 · 결과 절의 남긴 글 묶음 · 「남긴 글을 확인하지 못했다」 줄 · `commit` 칸 · `state` 뜻 문장)
- Modify: `plugins/quality-gates/README.md`(돌려주는 꼴 문단 옆에 결과 줄 문단 하나 — 새 결과 줄 셋 · ` · 커밋 해시 확인 못 함` 꼬리 · 「물었지만 답 기록을 끝내지 못했다」 줄 · `commit` 의 `unknown — 커밋 해시 확인 못 함`)
- Test: `plugins/quality-gates/tests/test_intent_return.py`(`TestReturnHead` · `TestReturnDoc` 에 더함)

**Interfaces:**
- Consumes: Task 3 의 신호, Task 4 의 `_leftover`.
- Produces: `_outcome(plan, data, mode, answers_present: bool) -> dict` — 키 `commit_unknown: bool` 를 더한다. `answers_present` = 세션 폴더에 `intent-answers.txt` 가 있음. 결과 줄 규칙(「정한 이름과 꼴」 의 글자):
  - 묻는 질문 0 · `outcome: none` 갈래 → 거른 상태에 따라 꼬리.
  - `record_ran` 없음 · PR 범위 · `answers_present` → 「물었지만 답 기록을 끝내지 못했다」 줄(지금의 「묻지 않음(묻기 전에 끝남)」 대신). `answers_present` 가 거짓이면 지금 줄 그대로.
  - 보통 줄인데 「답함」 이 하나 이상이고 `data["commit"]` 이 비었으면 꼬리 ` · 커밋 해시 확인 못 함` · `commit_unknown` 참 → `cmd_render` 가 돌려주는 꼴의 `commit` 을 `unknown — 커밋 해시 확인 못 함` 으로.

- [ ] **Step 1: 실패하는 시험을 하나씩 쓴다:**
  - `TestReturnHead`: `test_none_tail_wrong_only` · `test_none_tail_other_only`(답 폴더의 「의도다」 · 미뤄 둔 넘겨받은 「잘못 골랐다」 각각) · `test_none_tail_both` · `test_none_without_filtered_unchanged`(결과 줄이 `intent-critic — 질문 없음` 그대로) — 넷 모두 `outcome: none` · `answered_filtered` 가 세 상태를 합친 수 · 결과 줄에 숫자가 없다(AC10) · `test_return_keys_unchanged`(돌려주는 꼴 블록의 키 차례가 `RETURN_KEYS` 를 아는 글자 값으로 적은 목록과 같고 `contract: 3` — AC10) · `test_hash_unknown_line_and_commit`(Task 3 의 덧쓰기 실패 → 결과 줄 `intent-critic — 질문 2개를 물었다 · 답 1개(잘못 골랐다 0개) · 답하지 않음 1개 · 커밋 해시 확인 못 함`, `commit: unknown — 커밋 해시 확인 못 함`, 행: 답한 질문 「답함」 · 고른 답 · `wrong_choice` · 답하지 않은 질문 「답하지 않음」 — AC3) · `test_not_finished_line`(커밋 앞 쓰기 실패 → 결과 줄이 「물었지만 답 기록을 끝내지 못했다」 줄 · 숫자는 묻는 질문 수 하나뿐 · `commit: -` · 행 상태 「묻지 않음」 · 「묻기 전에 끝남」 없음 — AC24) · `test_not_finished_line_without_answer_files`(답 파일 없이 한 번 쓰는 쓰기 실패 → 같은 결과 줄 — AC24) · `test_blocked_record_result_line`(kill switch · 설정 못 읽음 갈래 → 결과 줄이 「물었지만 답 기록을 끝내지 못했다」 가 아니라 보통 줄(`질문 <n>개를 물었다 · 답 0개…`)이고 행은 「답 기록 실패」 — 과제 사이 이음매).
  - `TestReturnDoc`: `test_doc_lists_new_result_lines`(state-file-format.md 결과 줄 목록과 README 에 코드 상수에서 지은 새 글 넷 — 꼬리 셋은 꼬리 글자로 · ` · 커밋 해시 확인 못 함` · 「물었지만」 줄의 고정 부분 — 이 있고, `commit` 줄에 `unknown — 커밋 해시 확인 못 함` — AC10) · `test_doc_not_asked_meaning`(`state` 뜻 문장의 `묻지 않음` 이 커밋 앞 기록이 실패한 실행을 든다 — 낱말 「질문 기록을 쓰지 못한」).

- [ ] **Step 2: 돌려 실패를 본다** — Run: `cd plugins/quality-gates/tests && python3 -m unittest test_intent_return.TestReturnHead test_intent_return.TestReturnDoc -v`.

- [ ] **Step 3: 구현 · 문서** — 위 Interfaces. state-file-format.md 의 `## intent-critic` 결과 절 설명에 남긴 글 묶음 줄(자리 · 꼴 · 통째 알림 줄 · 「남긴 글을 확인하지 못했다」)을 더하고, `state` 뜻 문장을 `묻지 않음 은 범위 모드이거나 묻기 전에 끝났거나 질문 기록을 쓰지 못한(커밋 앞 기록 실패) 실행이다` 꼴로 고친다.

- [ ] **Step 4: 돌려 통과를 본다** — Step 2 + `python3 -m unittest test_intent_return test_intent_handed test_intent_wide -v` · `bash test_intent_critic_wiring.sh`.

- [ ] **Step 5: 커밋** — `fix(qg): 「질문 없음」 의 거른 까닭 · 커밋 해시를 모르는 실행 · 답 기록을 끝내지 못한 실행을 결과 줄이 가른다`.

---

### Task 6: 의도 점검 reference(§1 · §6 제안 18 · AC27 · AC21-18)

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md`(질문 앞 머리말 첫 줄과 채우는 법 · 답 기록 문단 · `record` 출력 표 · I7)
- Test: `plugins/quality-gates/tests/test_intent_critic_wiring.sh`(케이스 더함)

**Interfaces:**
- Consumes: Task 3 · 4 · 5 의 글자.
- Produces(문장 — 글자는 「정한 이름과 꼴」):
  - 머리말 첫 줄 `<리뷰 범위> 리뷰` 와 채우는 법 불릿 — 범위마다 글.
  - 답 기록 문단: 번호 · 정체가 맞지 않는 머리 줄은 답 파일로 쓰지 않고, 그 줄과 아래 글은 결과 파일의 남긴 글 묶음에 원문으로 남는다(번호가 맞으면 그 질문의 실패 기록에도).
  - `record` 출력 표 두 행 — `질문 기록을 쓰지 못해 답 파일 <n>개를 커밋하지 않았다 — <사유>(파일은 남겼다)` · `질문 기록에 커밋 결과를 적지 못했다 — <사유>` → 그대로 보이고 I6, 할 일은 I7.
  - I7: (가) `## intent-critic` 의 남긴 글 묶음과 「남긴 글을 확인하지 못했다」 줄을 그대로 보인다 (나) `commit:` 이 `unknown — 커밋 해시 확인 못 함` 이면 「답 파일이 커밋됐는지 확인한다 — `record` 의 화면 줄이 `답 파일 <n>개를 커밋했다(<해시>)` 면 그 커밋을 push 하고, `답 파일을 커밋하지 못했다 — …` 면 답 파일 <`file:` 이 `-` 가 아닌 경로들>을 커밋한다」 (다) 결과 줄이 「물었지만 답 기록을 끝내지 못했다」 면 「작업 트리의 답 자리에 커밋되지 않은 답 파일이 있으면 커밋하고 push 한다 — 수는 `record` 의 화면 줄 `질문 기록을 쓰지 못해 답 파일 <n>개를 커밋하지 않았다` 가 말한다」 를 내고, 그 실행의 `묻지 않음` 행에 「다시 돌려 묻는다」 를 내지 않는다.

- [ ] **Step 1: 실패하는 락을 쓴다** — `test_intent_critic_wiring.sh` 에 `note "[R8 — 남긴 글 · 기록 실패 · 머리말]"` 아래(`section` 도우미로 그 절만 읽는다 — 헤더-satisfiable 함정을 피해 본문에만 있는 낱말을 문다):
  - `header_scope`: 질문 앞 글 펜스 첫 줄이 `<리뷰 범위> 리뷰` · `<브랜치 이름> 리뷰` 없음 · 채우는 법에 `이번 세션에서 바뀐 파일 <n>개` · `토픽 <토픽 열쇠>` · `고른 파일 <n>개` · `git rev-parse --abbrev-ref HEAD` 가 브랜치 범위 불릿에만(AC21-18).
  - `record_paragraph`: 답 기록 문단에 `어느 답에도 실리지 않고` 없음 · `답 파일에 실리지 않은 답 입력의 글` 있음.
  - `record_table_rows`: 표에 `질문 기록을 쓰지 못해 답 파일` 행 · `질문 기록에 커밋 결과를 적지 못했다` 행.
  - `i7_leftover`: I7 에 `남긴 글을 확인하지 못했다` · `답 파일에 실리지 않은 답 입력의 글` (가).
  - `i7_hash_unknown`: I7 에 `unknown — 커밋 해시 확인 못 함` 과 같은 불릿 안에 `커밋됐는지 확인한다` 와 두 갈래 — `커밋했다(` 와 `push` 가 한 갈래, `커밋하지 못했다` 와 `커밋한다` 가 다른 갈래 (나).
  - `i7_not_finished`: I7 에 `물었지만 답 기록을 끝내지 못했다` 와 같은 불릿 안에 `커밋되지 않은 답 파일` · `push 한다` · `record` 의 화면 줄 (다). 「그 실행의 `묻지 않음` 행에 다시 돌려 묻는다를 내지 않는다」 는 부분 문자열로 물면 뜻을 뒤집어도 남을 수 있다 — 같은 불릿의 한 줄 안에서 `다시 돌려 묻는다[^\n]*내지 않는다` 가 맞는지로 문다. 그리고 `묻지 않음` 불릿(「질문 <k>개를 묻기 전에 끝났다 — 다시 돌려 묻는다」 가 있는 불릿)에 「물었지만 답 기록을 끝내지 못했다」 실행을 빼는 낱말 `끝내지 못했다` 가 있다(짝).
  - `render_answers_path`: 답 기록 펜스의 `record` 줄이 `--answers "$RD/intent-answers.txt"`(렌더가 같은 고정 이름을 읽는다 — 이름이 갈라지면 남긴 글이 「확인하지 못했다」 로 떨어진다).

- [ ] **Step 2: 돌려 실패를 본다** — Run: `bash plugins/quality-gates/tests/test_intent_critic_wiring.sh` · Expected: 새 케이스 FAIL(`render_answers_path` 는 지금도 통과가 맞다 — Step 5 에서 변이로 본다).

- [ ] **Step 3: reference 를 고친다** — 위 Produces. R7 이 바꾼 I7 의 push 문장 · 답 펜스의 값 받기 문장은 그대로 둔다.

- [ ] **Step 4: 돌려 통과를 본다** — Step 2 + R7 의 `i7_sentence` 단언(같은 파일)도 통과.

- [ ] **Step 5: 글자 락의 이빨** — 새 케이스마다 그 문장을 지운 사본(삭제)과 뜻을 뒤집은 사본(예: (다) 불릿의 「내지 않는다」 를 「낸다」 로 · (나) 의 push 갈래를 지움 · (다) 의 「push 한다」 를 지움 · `묻지 않음` 불릿에서 「끝내지 못했다」 빼기를 지움 · 머리말 첫 줄을 `<브랜치 이름> 리뷰` 로 되돌림 · `--answers` 경로를 다른 이름으로)을 시험 안의 임시 사본으로 돌려 RED, 손대지 않은 사본 GREEN 을 본다. 뒤집는 변이 하나라도 GREEN 이면 그 락을 고쳐 다시 본다(시험 파일 안에 사본 케이스로 둔다 — `mktemp -d` 뒤 `cd ""` 함정을 피해 경로를 변수로 확인한다).

모델이 이 문장들을 실제로 따르는지는 스크립트로 재지 못한다 — 질문 창의 답을 기다리는 흐름이라 평가 케이스의 쓰는 조건 3(사람의 답 없이 한 번의 실행에서 드러난다)에 들지 않는다(`docs/testing.md`). 글자 락과 Step 5 의 변이로 대신 지킨다.

- [ ] **Step 6: 커밋** — `docs(qg): 의도 점검 reference — 남긴 글 보이기 · 기록 실패 두 줄 · 머리말의 리뷰 범위`.

---

### Task 7: intent_critic.py 의 나머지 제안 · 테스트 틈(§6 · AC19 도움말 · AC20 T1 · T5 · T7 둘째 · AC21 11 · 14 · 제안 7 · 8 · 9 · 12 · 13 · 19 · 20)

**Files:**
- Modify: `plugins/quality-gates/scripts/intent_critic.py`(`_prepare` 의 입력 크기 · `_why` · `config` 도움말 · 주석 · 독스트링)
- Test: `plugins/quality-gates/tests/test_intent_critic.py` · `test_intent_return.py` · `test_intent_handed.py`(케이스 더함 · 보이지 않는 글자 이스케이프)

**Interfaces:**
- Produces:
  - `_prepare`: `total = io_.total_bytes(run_text, origin, roadmap, intent_kept, doubts, answered_text)` — `answered_text` 는 `_answered_lines(answered, handed)` 의 글(쓰기 전에 짓는다). 나눠 부르기 판정과 공시 줄 「입력 <n>바이트」 가 이 크기를 쓴다(제안 11).
  - `_why(item) -> str` — 문자열 끝의 줄바꿈 하나(`\n` 또는 `\r\n`)만 떼고 본다. 그 뒤 줄바꿈이 남으면 `-`(제안 14).
  - `config` 의 `help` — 「정한 이름과 꼴」 의 글(AC19 둘째).

- [ ] **Step 1: 실패하는 시험을 하나씩 쓴다:**
  - `test_intent_critic.py`: `test_answered_counts_toward_size`(돌려 본 글은 상한 아래 · 넘겨받은 답 줄을 더하면 상한 위가 되는 실행 → `intent-call: single` · 공시 `입력 <n>바이트` 의 `<n>` 이 `<answered>` 글의 바이트를 포함한 값 — 손으로 더한 기대값 · 넘겨받은 답 없이 같은 실행은 `first-only` — AC21-11) · `test_why_trailing_newline`(`"한 줄\n"` → `한 줄` · `"한 줄\r\n"` → `한 줄` · `"가\n나"` → `-` · `"가\n나\n"` → `-` — AC21-14) · `test_config_help_names_four`(`config --help` 출력의 `help` 줄에 「다른 팀 기록 상한」 · 「의도 문서 표시」 — AC19).
  - `test_intent_return.py`: `test_reviewed_head_survives_answer_commit_when_asked`(T1 — `e2e-record.md` 를 둔 `prepare`(→ `first-only`) → `filter` → `record`(진짜 답 커밋) → `render`: `reviewed_head` == `prepare` 때 HEAD 해시 · `reviewed_head` != 답 커밋 해시 · `commit` == 답 커밋 해시) · `test_range_switch_record_line`(T5 — 범위 모드 계획 + 스위치 켬 → `record` 표준 출력이 `KILL_RECORD % <변수>` 와 `record: 0` 두 줄) · `test_uncountable_reason_without_questions`(T5 — `intent-questions.yaml` 없이 `render` → `reason_text: 거르기 결과(intent-questions.yaml)가 없음`).
  - `test_intent_handed.py`: `test_fix_and_changed_observation_reason`(제안 19 — 「이 에픽 안에서 고친다」 넘겨받은 답 + 관찰이 바뀐 근거 → `asked_before` 넷째 칸이 지금 코드가 고르는 쪽 하나로 핀) · `test_uncountable_answered_filtered_dash`(제안 20 — 셀 수 없는 실행의 `answered_filtered: -`).
  - T7 둘째: `test_intent_return.py` · `test_other_teams.py` 의 테스트 소스에 날글자로 박힌 U+2028 · U+202E · U+200F 를 ` ` · `‮` · `‏` 이스케이프로 바꾼다(동작 같음). 동작이 없는 소스 고침이라 변이로 잴 틈이 없다 — 대신 두 파일에 그 세 글자가 0개인지 보는 시험 `test_no_raw_invisible_chars`(두 파일을 바이트로 읽어 셈)를 `test_intent_return.py` 에 두고, 날글자 하나를 되살린 사본에서 RED 를 한 번 본다.

- [ ] **Step 2: 돌려 실패를 본다** — 새 케이스(제안 19 · 20 · T1 · T5 는 지금 동작을 잠그는 시험이라 통과가 맞다 — Step 5 에서 변이로 본다).

- [ ] **Step 3: 구현 · 주석** — 위 Produces. 주석 · 독스트링: 모듈 머리 파일 목록에 `intent-handed.yaml`(제안 7) · `answered_filtered` 가 `-` 인 경우 셋(건너뜀 · 셀 수 없음 · 실패)(제안 8) · `_prior` 독스트링에 돌려주는 사전의 키와 불변식, None 을 돌려주는 경우(제안 9 · 13 — 구조는 바꾸지 않는다: 동작이 같은 구조 바꿈은 이 에픽의 다른 과제가 그 함수를 고치지 않아 리뷰 비용만 든다) · 「두 파일」 주석을 지우는 파일 수에 맞게(제안 12).

- [ ] **Step 4: 돌려 통과를 본다** — `cd plugins/quality-gates/tests && python3 -m unittest test_intent_critic test_intent_return test_intent_handed test_intent_wide -v`.

- [ ] **Step 5: T1 · T5 · 제안 19 · 20 의 이빨** — 변이를 하나씩: T1 은 리뷰어를 부르는 갈래의 `_write_plan(..., reviewed=reviewed)` 에서 `reviewed=` 를 지움 · T5 는 범위 모드 스위치 공시 줄을 지움 / `reason_text` 를 비움 · 제안 19 는 사유를 고르는 차례를 뒤집음 · 제안 20 은 셀 수 없음에서 `answered_filtered` 를 0 으로 → 각각 RED(Task 1 Step 5 의 절차).

- [ ] **Step 6: 커밋** — `fix(qg): 넘겨받은 답을 입력 크기에 넣고 끝 줄바꿈 한 줄 why 를 살린다 · 테스트 틈`.

---

### Task 8: `--answered` 빈칸 경로(§1 · AC6)

**Files:**
- Modify: `plugins/quality-gates/scripts/setup-qg.sh`(`--answered)` 갈래 · `*)` 갈래)
- Modify: `plugins/quality-gates/README.md`(`--answered <경로>` 문단에 한계 한 문장)
- Test: `plugins/quality-gates/tests/test_setup_qg.sh`

**Interfaces:**
- Produces: `--answered` 의 값을 소비한 직후 `AFTER_ANSWERED=1`, 다른 갈래를 지날 때마다 0. `*)` 갈래는 `AFTER_ANSWERED=1` 이면 「정한 이름과 꼴」 의 문구, 아니면 지금 문구(rc 1 그대로). README 문장: `경로에 빈칸이 있으면 받지 못한다 — 빈칸 없는 경로로 옮겨 넘긴다`.

- [ ] **Step 1: 실패하는 시험** — `answered_space_message`(`--ensure --answered /tmp/a b.yaml` 꼴 → rc 1 · stderr 에 `--answered 의 경로에 빈칸이 있으면 받지 못한다`) · `unknown_arg_plain`(`--ensure bogus` → 지금 문구 그대로 · 빈칸 문구 없음 — 짝) · README 문장 단언(`test_intent_critic_wiring.sh` 의 README 절에 한 줄).
- [ ] **Step 2: 실패를 본다** — Run: `bash plugins/quality-gates/tests/test_setup_qg.sh`.
- [ ] **Step 3: 구현** — 위 Produces.
- [ ] **Step 4: 통과를 본다** — Step 2 + `bash plugins/quality-gates/tests/test_intent_critic_wiring.sh`.
- [ ] **Step 5: 커밋** — `fix(qg): --answered 경로의 빈칸으로 멈추면 그 까닭을 말한다`.

---

### Task 9: 같은 이름 사본 고르기 — 앞섬 · 갈라짐(§4 · AC11 · AC29 · T4 둘째 · Review Focus 4 · 5)

**Files:**
- Modify: `plugins/quality-gates/scripts/other_teams.py`(`_same_name_drops` · `_tips` · `other_work` · `_branch_entry` · `_intent_docs` · `_branch_unit` · `collect`)
- Test: `plugins/quality-gates/tests/test_other_teams.py`(`TestSameNameRemote` 고침 · 더함)

**Interfaces:**
- Produces: 「정한 이름과 꼴」 의 `_same_name_drops` · `_tips`(이 과제에서는 `unpushed` 를 늘 거짓으로 둔다 — Task 10 이 채운다) · 항목 키 `doc_paths` · `local_sha` 와 원격 후보 표시. 규칙:
  - 앞섬(원격이 로컬의 조상) → 로컬 ref 를 버리고 원격 ref 를 남겨 `carry[원격 ref] = 로컬 sha` · 묶은 수 +1.
  - 갈라짐 → `_ancestor(repo, 로컬 sha, end)` 를 한 번 더: 참이거나 None → 지금처럼 원격을 버리고 로컬을 남김 / 거짓 → 로컬을 버리고 원격을 남겨 `carry`. 어느 쪽이든 갈라진 이름 목록에 넣고 묶은 수에는 넣지 않는다.
  - 뒤짐 · 같음 · 첫 조상 물음이 None → 지금 코드 그대로.
  - `_branch_entry` 는 `local_sha` 가 있으면 다른 작업인지 가르는 `rev-list` · `log --name-only` 의 `<끝>` 자리에 두 끝을 함께 넣고, 이름 diff 는 두 끝 각각의 합. `doc_paths` 는 원격 끝 하나로 모은 `log --name-only`. `base` 는 원격 끝으로.
  - `_intent_docs` 는 `entry["doc_paths"]` 만 돈다. `_branch_unit` 은 겹치는 파일 가운데 `doc_paths` 에 든 것만 diff 를 싣고 나머지는 머리만. 원격 후보면 작업 줄에 표시.
  - `collect` 의 수 줄: 원격 후보이면서 의도 문서도 겹침도 없으면 「원격에 없는 로컬 커밋이 있는 브랜치」 로 센다(그 밖의 브랜치에 세지 않는다).

- [ ] **Step 1: 실패하는 시험을 하나씩 쓴다** — 픽스처 도우미 `_far_local`(지금 것)과 `_commit_off` 를 쓴다. 로컬에만 있는 커밋에는 심은 글(`LOCAL-ONLY-PLANT`)을 넣는다.
  - `test_ahead_reads_remote_and_names_local`(AC11 — 로컬이 앞섬: 원격 끝의 의도 문서 본문 · diff 가 기록에 · `LOCAL-ONLY-PLANT` 없음 · 로컬 커밋만 바꾼 겹치는 파일 이름은 겹침 목록과 `#### 겹치는 파일` 머리에 있고 그 아래 diff 없음 · 작업 줄에 표시 · 「묶었다」 줄 있음).
  - `test_diverged_outside_review_reads_remote`(AC11 — 리뷰 끝 밖 갈라짐: 같은 단언 + 「갈라져 있다」 줄 · 「묶었다」 수에 안 듦 · 올리지 않은 브랜치로 실리지 않음).
  - `test_local_only_intent_doc_not_selected`(AC11 — 로컬에만 있는 커밋이 의도 문서를 고쳤고 원격 끝에서 닿는 커밋은 그 문서를 건드리지 않음 → `#### 의도 문서 <그 문서>` 없음, 원격 끝의 옛 글도 없음).
  - `test_diverged_inside_review_not_read`(AC29 — 리뷰 브랜치 자신(`feature/mine`)의 원격 사본을 갈라 둔다. 원격 사본에만 있는 커밋에 심은 글 `REMOTE-ONLY-PLANT` 를 의도 문서와 이 변경과 겹치는 파일 둘 다에 넣는다 → 다른 팀 기록 어디에도 `REMOTE-ONLY-PLANT` 없음(「원격 사본의 글 없음」 의 기준) · 작업 줄 · 수 줄에 없음 · 「갈라져 있다 — feature/mine」 있음. 로컬 끝 == 리뷰 끝 · 로컬 끝이 리뷰 끝의 조상 두 경우).
  - `test_diverged_inside_review_ancestor_timeout`(AC29 · T4 둘째 — `TestGitTimeout` 의 `_slow` 꼴로 둘째 조상 물음만 시간 한도 → `REMOTE-ONLY-PLANT` 없음).
  - 짝(양성): `test_diverged_outside_review_reads_remote` 에도 원격 사본에만 있는 커밋에 같은 꼴의 심은 글을 넣어, 범위 밖이면 그 글이 기록에 **있는지** 본다 — 「없음」 단언이 늘 통과하는 단언이 아니게.
  - `test_ancestor_unknown_keeps_both`(T4 둘째 — 첫 조상 물음(`merge-base --is-ancestor <원격> <로컬>`)을 시간 한도로 → 두 끝 모두 남고 시간 한도 줄이 난다).
  - `test_ahead_remote_already_in_default`(Review Focus 4) · `test_ahead_of_two_remotes`(Review Focus 5).
  - `test_local_only_count_line`(AC28 둘째 — 원격 후보인데 원격 끝에서 닿는 경로에 의도 문서가 없고 겹침도 없음 → `원격에 없는 로컬 커밋이 있는 브랜치 1개 — …` · 「그 밖의 브랜치」 에 안 듦).
  - 고치는 기존 시험(동작 변경): `test_remote_behind_local_folded`(로컬 앞섬 → 이제 원격 후보가 실린다) · `test_diverged_not_listed`(리뷰 끝 밖이면 이제 원격 끝이 실린다 — 이름을 `test_diverged_outside_review_reads_remote` 로 합친다) · `test_notes_filled`(키 `push_unknown` 더함) · `test_entry_fields`(약 253행 — 항목 키 집합 단언에 `doc_paths` · `local_sha` · `unpushed` 가 더해진다). 고친 까닭을 커밋 메시지와 PR 본문의 「동작 변경으로 고친 시험」 에 적는다.
  - 보안 갈래(로컬에만 있는 글이 기록으로 새지 않는다 — `LOCAL-ONLY-PLANT` 단언): 변이 넷(`_intent_docs` 를 `paths` 로 되돌림 · diff 를 로컬 끝에서 읽음 · 표시를 지움 · 범위 안 갈라짐에서 원격을 남김) RED, 양성 대조 GREEN.

- [ ] **Step 2: 실패를 본다** — Run: `cd plugins/quality-gates/tests && python3 -m unittest test_other_teams.TestSameNameRemote test_other_teams.TestGitTimeout -v`.
- [ ] **Step 3: 구현** — 위 Produces.
- [ ] **Step 4: 통과를 본다** — `python3 -m unittest test_other_teams test_other_teams_review_records test_intent_wide -v`.
- [ ] **Step 5: 변이 넷 · 양성 대조** — Task 2 Step 5 의 절차.
- [ ] **Step 6: 커밋** — `fix(qg): 원격보다 앞서거나 갈라진 로컬 브랜치는 원격 사본 끝에서 읽고 로컬 커밋은 파일 이름만 싣는다`.

---

### Task 10: 올리지 않은 브랜치(§4 · AC11 · AC28 · 고정 줄)

**Files:**
- Modify: `plugins/quality-gates/scripts/other_teams.py`(`_tips` 의 `unpushed` · 새 `_unpushed` · `_branch_entry` · `collect` · `LINE_UNSEEN`)
- Modify: `plugins/quality-gates/README.md`(다른 팀 읽기 「못 보는 것」 문단 — 고친 고정 줄 · 「올린 브랜치인지 가르지 못해 …」 줄 · 올리지 않은 브랜치는 이름과 겹치는 파일만)
- Test: `plugins/quality-gates/tests/test_other_teams.py`(픽스처 · 새 클래스 `TestUnpushed`) · 다른 팀 기록을 짓는 다른 시험의 픽스처(`grep -ln 'ot.collect\|other_work\|_teams_repo\|_other_branch' plugins/quality-gates/tests/*.py` 로 찾는다 — 계획 담당자가 본 것: `test_other_teams.py` · `test_intent_wide.py` 의 `_other_branch` · `test_other_teams_review_records.py`)

**Interfaces:**
- Consumes: Task 9 의 `_tips` · 항목.
- Produces: `_unpushed(repo: str, local_shas: List[str]) -> Optional[set]` — 「정한 이름과 꼴」 의 git 물음. `_tips` 는 남은 로컬 후보에 `unpushed` 를 채우고 실패면 모두 참 · `notes["push_unknown"]`. `_branch_entry` 는 `unpushed` 면 `doc_paths` 를 빈 집합으로(이름 목록 · 이름 diff 는 그대로 — 파일 이름은 내용이 아니다). `collect`: 올리지 않은 항목은 의도 문서를 읽지 않고, 겹침이 있으면 작업 줄(표시 · 겹치는 파일 머리만), 없으면 「올리지 않은 브랜치 <n>개」 수 줄. `push_unknown` 이 0 이 아니면 「확인 못 함」 에 그 줄. 고정 줄 교체.

- [ ] **Step 1: 픽스처를 먼저 고친다** — `_teams_repo` 가 다른 팀 브랜치마다(`feature/merged` · `feature/squashed` · `feature/rebased` · `feature/far` · `feature/mine-next`) `refs/remotes/origin/<이름>` 을 그 끝에 세운다(올린 브랜치로 — 기존 시험이 재던 「내용을 읽는 다른 작업」 의 뜻을 지킨다). `_on_branch` 는 이미 원격 ref 를 함께 옮긴다. 시험 안에서 새로 만드는 로컬 전용 브랜치에도 같은 원격 ref 를 세운다 — `test_other_teams.py` 의 `feature/signed`(약 336행) · `feature/glob`(약 1152행 — 경로 꼴 git 읽기 검사) · `feature/sib-a` · `feature/sib-b`(약 1320행), `test_other_teams_review_records.py` 의 `feature/x`, `test_intent_wide.py` 의 `_other_branch`(`feature/other`), 그리고 위 grep 이 찾은 다른 자리. 원격 ref 를 세우지 않고 단언을 고쳐 맞추지 않는다 — 그러면 그 시험이 재던 내용 읽기(경로 꼴 검사 등)가 조용히 빠진다. 이 걸음만으로 `python3 -m unittest test_other_teams test_intent_wide test_other_teams_review_records` 가 이 과제의 구현 전에도 GREEN 인지 본다(픽스처 변경이 기존 단언을 바꾸지 않았다는 증거) — 바뀐 단언이 있으면 그 이유를 적는다.
- [ ] **Step 2: 실패하는 시험을 하나씩 쓴다** — `TestUnpushed`(로컬에만 있는 브랜치 `feature/local` 에 `UNPUSHED-PLANT` 를 심은 의도 문서와 겹치는 파일 커밋):
  - `test_unpushed_names_only`(AC11 — 작업 줄 `### feature/local · … · 올리지 않은 브랜치 — 내용은 읽지 않았다` · 겹치는 파일 머리만 · `UNPUSHED-PLANT` 없음 · `#### 의도 문서` 없음 · `prepare` 까지 돌려 `intent-evidence.txt` · `other-teams.md` 어디에도 `UNPUSHED-PLANT` 없음).
  - `test_pushed_branch_still_read`(AC11 — 원격 사본이 같은 끝인 브랜치는 지금처럼 의도 문서 · diff).
  - `test_unpushed_no_overlap_count`(AC28 — 겹침 없는 올리지 않은 브랜치 → `올리지 않은 브랜치 1개 — 겹침 없음 · 내용은 읽지 않았다` · 「그 밖의 브랜치」 수에 안 듦 · 0 이면 줄 없음).
  - `test_push_check_failure_hides_locals`(AC11 — `_slow("rev-list", …)` 꼴로 `--remotes` 가 든 `rev-list` 만 시간 한도 → 로컬 후보 모두 이름만(원격 사본과 끝이 같은 로컬 브랜치도 — 설계 D62) · 「확인 못 함」 에 `올린 브랜치인지 가르지 못해 로컬 브랜치 <n>개의 내용을 읽지 않았다` 이고 `<n>` 은 같은 이름 사본을 가른 뒤 남은 로컬 후보 수 — 픽스처에서 손으로 센 값. 픽스처에 로컬이 원격 사본보다 뒤처져 로컬이 버려지는 같은 이름 쌍 하나를 둬서, 「로컬 브랜치(`refs/heads`) 전부를 센다」 는 변이와 수가 달라지게 한다).
  - `test_unseen_fixed_line`(AC11 — 「확인 못 함」 끝 줄이 새 고정 줄 · 옛 글 없음 — 기존 `TestLineInterviewWords` 옆 단언을 고친다).
  - README 단언(`test_intent_critic_wiring.sh` 에 한 줄 — 새 고정 줄과 「올린 브랜치인지 가르지 못해」 낱말).
  - 보안 갈래(`UNPUSHED-PLANT` 단언): 변이 넷(`doc_paths` 비우기를 지움 · `_unpushed` 실패를 「모두 올림」 으로 뒤집음 · `--remotes` 를 `--branches` 로 바꾸는 형태 · 작업 줄에 diff 를 더함) RED, 양성 대조 GREEN. 수 세기 변이(「`refs/heads` 전부를 센다」) → `test_push_check_failure_hides_locals` RED.
- [ ] **Step 3: 실패를 본다** — Run: `cd plugins/quality-gates/tests && python3 -m unittest test_other_teams.TestUnpushed -v`.
- [ ] **Step 4: 구현 · README** — 위 Produces.
- [ ] **Step 5: 통과를 본다** — `python3 -m unittest test_other_teams test_other_teams_review_records test_intent_wide test_intent_critic -v` · `bash test_intent_critic_wiring.sh`.
- [ ] **Step 6: 변이 넷 · 양성 대조** — Task 2 Step 5 의 절차.
- [ ] **Step 6a: 기존 시험이 아직 내용 읽기를 재는지 본다** — Step 1 에서 원격 ref 를 세운 시험들이 구현 뒤에도 다른 브랜치의 의도 문서 · diff 를 재는지(양성 단언이 살아 있는지) 확인한다: `_unpushed` 가 늘 「모든 로컬 후보가 올리지 않음」 을 돌려주는 변이를 넣고 `python3 -m unittest test_other_teams test_intent_wide test_other_teams_review_records` 를 돌려, Step 1 의 브랜치를 쓰는 시험(`feature/signed` · `feature/glob` · `feature/x` · `_other_branch` 를 쓰는 것 등)이 RED 인지 본다. GREEN 으로 남는 시험이 있으면 그 시험이 내용 읽기를 잃은 것이다 — 원격 ref 가 그 브랜치에 섰는지 다시 보고 고친다. 변이를 되돌리고 `git diff HEAD --stat` 가 빈 것을 확인한다.
- [ ] **Step 7: 커밋** — `fix(qg): 올리지 않은 브랜치는 이름과 겹치는 파일만 싣고 내용은 읽지 않는다`(픽스처 커밋을 따로 두려면 Step 1 뒤에 `test(qg): 다른 팀 픽스처의 브랜치를 올린 브랜치로 세운다`).

---

### Task 11: 다른 팀 기록의 사유 줄 · 0개 실행(§4 · AC12 · AC13 · AC14 · T4 첫째 · T6 · T7 첫째)

**Files:**
- Modify: `plugins/quality-gates/scripts/other_teams.py`(`_intent_docs` 의 사유 · `collect` 의 PR 줄 · 「묶었다」 줄 조건 · `LINE_DOC_TIMEOUT` → `LINE_DOC_UNREAD`)
- Test: `plugins/quality-gates/tests/test_other_teams.py` · `plugins/quality-gates/tests/test_intent_wide.py`(T6)

**Interfaces:**
- Consumes: Task 9 · 10.
- Produces: 「정한 이름과 꼴」 의 읽지 못한 문서 줄 · PR 줄. 「묶었다」 줄은 `collect` 가 형제를 뺀 뒤의 항목 목록이 비어 있지 않을 때만. 「갈라져 있다」 줄은 지금처럼 늘.

- [ ] **Step 1: 실패하는 시험을 하나씩 쓴다:**
  - `test_doc_unread_reasons`(AC12 — 다른 브랜치가 고친 문서 가운데: 심볼릭 링크 문서 · 폴더로 바뀐 경로(보통 파일 아님) · 줄바꿈이 든 이름의 문서 · 지운 문서. 앞 셋은 `<브랜치> 의 <문서> 를 읽지 못함 — <사유>` 가 「확인 못 함」 에, 지운 문서는 그 줄이 없음).
  - `test_refs_unreadable_one_pr_line`(AC13 — `for-each-ref` 를 실패시키고(픽스처의 가짜 git 꼴) 열린 PR 셋을 넣은 실행 → 「그 브랜치가 이 리포에 없다」 0줄 · `브랜치 목록을 읽지 못해 열린 PR 3개를 견주지 못했다` 한 줄).
  - `test_zero_work_no_folded_line_diverged_kept`(AC14 · T4 첫째 — 다른 작업이 0개인 리포: 로컬 `main` 이 `origin/main` 보다 한 커밋 뒤 · 리뷰 브랜치 자신의 원격 사본을 갈라 둠 → `### ` 항목 0 · 수 줄 0 · 「묶었다」 줄 없음 · 「갈라져 있다」 줄 있음).
  - `test_count_lines_only_still_folded`(AC14 — 브랜치 수 줄만 있는 실행은 「묶었다」 줄이 난다).
  - `test_mode_has_no_effect_on_collect`(T7 첫째 — `inspect.signature(ot.collect)` 에 모드 인자가 없고, `ic._teams` 를 `args.mode` 가 `pr` · `range` 인 두 호출로 불러 `collect` 에 넘긴 인자가 같다 — `collect=` 자리에 인자를 적어 두는 기록 함수를 넘긴다(`_teams` 가 이미 받는 주입 자리)). 지금 `test_range_and_pr_same_rule` 은 이 시험으로 바꾼다(아무것도 가르지 못하던 시험 — PR 본문에 적는다).
  - `test_topic_scope_from_emitter`(T6 — `scripts/topic-head.sh` 에서 `emit() {` 부터 짝 `}` 까지를 뽑아 `KEY=t1 BRANCHES=feature/x,origin/feature/y` 로 `emit ok -` 를 돌린 출력을 `ic._topic_siblings` 가 읽는 파일로 → `{"feature/x", "origin/feature/y"}` · 그 출력 뒤에 `status: bad` · `branches: z` 를 덧붙인 글 → 첫 값만 · 뽑기가 0줄이면 실패(조용히 통과하지 않게)).
  - 고치는 기존 시험: 시간 한도만 재던 문서 읽기 단언(상수 이름 바뀜).

- [ ] **Step 2: 실패를 본다** — Run: `cd plugins/quality-gates/tests && python3 -m unittest test_other_teams test_intent_wide.TestWidePrepare -v`.
- [ ] **Step 3: 구현** — 위 Produces.
- [ ] **Step 4: 통과를 본다** — Step 2 + `python3 -m unittest test_other_teams_review_records test_intent_critic -v`.
- [ ] **Step 5: T4 첫째 · T6 의 이빨** — 「묶었다」 줄 조건을 지움 → `test_zero_work_…` RED · `_topic_siblings` 의 「첫 키」 가드 둘을 지움 → `test_topic_scope_from_emitter` RED(Task 1 Step 5 의 절차).
- [ ] **Step 6: 커밋** — `fix(qg): 다른 팀 기록의 읽지 못한 문서 · 브랜치 목록 실패를 맞는 사유로 알리고 0개 실행의 묶음 줄을 뺀다`.

---

### Task 12: 의도 출처(§5 · AC15 · AC16 · AC17 · AC18 · AC19 · T3)

**Files:**
- Modify: `plugins/quality-gates/scripts/intent_origin.py`(`_open_doc` · `_follow_roadmaps` · `build_origin` · `_add_origin_doc` · `_intent_docs` · `review_breadth` · `render_scope` · `BREADTH_LABELS` · 새 `REVIEW_RECORD_TYPE`)
- Modify: `plugins/quality-gates/scripts/intent_critic.py`(`_breadth` — 넷째 값 · 새 공시) · `plugins/quality-gates/scripts/other_teams.py`(`roadmap-review` 글자를 `io_.REVIEW_RECORD_TYPE` 로)
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md`(공시 줄 목록에 `원문 없음 — 시간 한도로 읽지 못함` 꼴 · `의도 문서인지 확인 못 한 문서 <n> — 머리를 읽지 못함`)
- Test: `plugins/quality-gates/tests/test_intent_wide.py`(`TestOriginTimeout` · `TestBreadth` · `TestWidePrepare`) · `plugins/quality-gates/tests/test_intent_critic.py`(`TestSections` 또는 `TestOriginLink`)

**Interfaces:**
- Produces:
  - `review_breadth(mode, names, read_doc, markers) -> (breadth, docs, unread, head_unread)` — `head_unread` 는 읽었는데 `frontmatter_unreadable` 인 문서 수(의도 문서로 세지 않는다). `type` 이 `REVIEW_RECORD_TYPE` 인 문서는 의도 문서로 세지 않는다.
  - `render_scope(breadth, names, repo, base, end, unsure: int = 0)` — 좁은 넓이 글을 `names` 와 `unsure`(파일 자체를 읽지 못한 문서 수 `unread` + 머리를 읽지 못한 문서 수 `head_unread`)로 가른다(「정한 이름과 꼴」 의 차례). `BREADTH_LABELS["narrow"]` 를 쓰던 자리는 새 함수 `narrow_label(names: Optional[set], unsure: int) -> str` 를 쓴다. `_prepare` 는 `_breadth` 가 돌려준 `unread + head_unread` 를 `render_scope` 에 넘긴다(`_breadth` 의 돌려주는 값에 넷째로 더한다). 공시 줄은 지금처럼 사유별로 따로다(`… — 추적되지 않는다` · `… — <시간 한도>` · `… — 머리를 읽지 못함`).
  - `_open_doc` · `_follow_roadmaps` 는 시간 한도면 `st["timed_out"]` · `st["timed_out_roadmap"]` 를 세우고 `rejected` 를 세우지 않는다. 요약 줄은 「정한 이름과 꼴」.

- [ ] **Step 1: 실패하는 시험을 하나씩 쓴다:**
  - `TestOriginTimeout`(T3 · AC15): 가짜 `subprocess.run` 이 넘길 git 부속 명령을 케이스마다 받게 고친다 — `test_ls_tree_timeout_reason`(`ls-tree` 만 시간 한도 → `<경로> 를 읽지 못함 — git 읽기가 시간 한도 30초를 넘김` · `추적` 글 없음 · 요약 `원문 없음 — 시간 한도로 읽지 못함`) · `test_roadmap_show_timeout_reason`(설계문서 `show` 는 통과 · 로드맵 경로의 `show` 만 시간 한도 → `로드맵 <경로> 를 읽지 못함 — …` · `로드맵 링크 거부` 없음 · 요약 `로드맵 없음 — 시간 한도로 읽지 못함`) · `test_real_link_rejection_unchanged`(링크 문서 → 지금처럼 `원문 링크 거부`).
  - `test_markerless_origin_noticed`(AC16 — `## 6. 사용자 원문` 절은 있고 🗣 · ☑ 가 없는 묶음 → `직접 쓴 말 · 고른 라벨을 가르지 못함` / 짝: 표지가 있는 같은 꼴 문서는 그 줄 없음 — `_ORIGIN_DOC` 픽스처).
  - `TestBreadth`: `test_head_unreadable_counted`(AC17 — 머리가 YAML 로 안 읽히는 바뀐 문서 → 넷째 값 1 · 의도 문서 아님 · `prepare` 공시 `의도 문서인지 확인 못 한 문서 1 — 머리를 읽지 못함`) · `test_review_record_not_intent_doc`(AC18 — 범위 모드에서 바뀐 문서가 `type: roadmap-review` + 의도 표시 → 의도 문서 목록에 없음 · 의도 출처 칸에 그 글 없음).
  - `test_narrow_label_by_change`(AC19 — 코드 파일이 든 PR → scope 칸 첫 줄 `넓이: 좁게 본다 — 코드가 바뀐 PR` · 문서만 바뀌고 의도 문서 없음 → `넓이: 좁게 본다 — 의도 문서가 바뀌지 않았다` · 바뀐 파일 목록(`review-i<N>.names`)을 지운 실행 → `넓이: 좁게 본다 — 바뀐 파일 목록을 모른다` · 문서만 바뀌고 그 가운데 머리가 YAML 로 안 읽히는 문서가 있음 → `넓이: 좁게 본다 — 의도 문서인지 확인 못 한 문서가 있다` · 문서만 바뀌고 그 가운데 추적되지 않는 문서 · 심볼릭 링크 문서가 있음(각각 — 설계 D63) → 같은 글, 공시는 `의도 문서인지 확인 못 한 문서 1 — 추적되지 않는다` 그대로 · 문서 아닌 파일과 머리를 못 읽은 문서가 함께 바뀐 PR → `코드가 바뀐 PR`(차례 확인)).
  - 고치는 기존 시험: `review_breadth` 세 값 언패킹(넷으로).
- [ ] **Step 2: 실패를 본다** — Run: `cd plugins/quality-gates/tests && python3 -m unittest test_intent_wide -v`.
- [ ] **Step 3: 구현 · 문서** — 위 Produces.
- [ ] **Step 4: 통과를 본다** — `python3 -m unittest test_intent_wide test_intent_critic test_other_teams test_other_teams_review_records -v`.
- [ ] **Step 5: T3 의 이빨** — `read_tracked` 의 `ls-tree` 시간 한도 갈래를 지움 · `_follow_roadmaps` 의 시간 한도 갈래를 지움 → 각 RED. 넓이 글의 차례: `narrow_label` 에서 머리를 못 읽은 문서 갈래를 「코드가 바뀐 PR」 갈래 앞으로 옮김 → `test_narrow_label_by_change` 의 차례 확인 RED(Task 1 Step 5 의 절차).
- [ ] **Step 6: 커밋** — `fix(qg): 의도 출처의 시간 한도 · 표지 없는 원문 · 머리를 못 읽은 문서 · 리뷰 기록 · 좁은 넓이 글을 맞는 말로`.

---

### Task 13: 판 · CHANGELOG · README · PR 본문 표(AC21 · AC22)

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` · `plugins/quality-gates/CHANGELOG.md` · `plugins/quality-gates/README.md`(Principles Instantiated — 바뀌면)

- [ ] **Step 1: 지휘자에게 판 번호를 받는다** — 받기 전에는 이 과제를 시작하지 않는다.
- [ ] **Step 2: 판 · CHANGELOG** — `## [<판>] — <날짜>` · Changed(직접 쓴 답의 라벨 읽기 · 질문 기록 쓰는 차례 · 결과 줄 · 다른 팀 읽기의 앞섬 · 갈라짐 · 고정 줄) · Fixed(어긋난 머리의 글 · 남긴 글 · 답 파일 읽기 방어 · 답 폴더 알림 · 넘겨받은 답 · 올리지 않은 브랜치 · 사유 줄 · 의도 출처 · 빈칸 경로 문구 · `why` · 입력 크기).
- [ ] **Step 3: 확인** — Run: `bash plugins/quality-gates/tests/test_intent_critic_wiring.sh` · `claude plugin validate plugins/quality-gates` · `grep -rn 'DISABLE_' plugins/quality-gates/scripts | sed 's/.*\(DEVBREW_[A-Z_]*\).*/\1/' | sort -u` 가 이 브랜치 앞(`git show origin/main:` 으로 같은 명령)과 같은 집합 · `git diff origin/main --stat -- plugins/quality-gates/agents/intent-critic.md` 가 빔(AC22).
- [ ] **Step 4: PR 본문에 실을 표를 미리 쓴다**(git 이 추적하지 않는 자리 — `.claude/` 아래, `git check-ignore -q` 로 확인): R6 머지 뒤 리뷰 제안 열다섯의 「받음 · 남김(이유)」(설계 §6 표의 번호마다 — 이 계획은 모두 받음: 3 · 4 · 5 · 6 · 10 은 Task 2, 7 · 8 · 9 · 11 · 12 · 13 · 14 · 19 · 20 은 Task 7, 18 은 Task 6 — 9 · 13 은 독스트링으로 받고 구조는 바꾸지 않은 까닭을 함께), 「테스트할 자리」 표, 동작 변경으로 고친 기존 시험 목록(Task 9 · 10 · 11 · 12 의 「고치는 기존 시험」 · 픽스처 변경 — 「지우기 · 합치기 · 줄이기」 가 아니라 설계 §4 · §5 의 동작 변경), 평가 케이스 검색 결과(`plugins/quality-gates/tests/evals` 에 고친 reference 경로가 있으면 그 요약 줄, 없으면 「해당 케이스 없음」), 그리고 **인계 절** — `skills/quality-pipeline/references/state-file-format.md` 는 R9 가 이름으로 예약한 파일이라, 이 PR 이 고친 문단(결과 줄 목록 · 결과 절의 남긴 글 묶음과 「남긴 글을 확인하지 못했다」 줄 · `commit` 칸의 `unknown — 커밋 해시 확인 못 함` · `state` 뜻 문장의 `묻지 않음` · 공시 줄 목록의 시간 한도 줄과 「머리를 읽지 못함」 줄)을 하나씩 적어 R9 가 합칠 때 찾게 한다.
- [ ] **Step 5: 커밋** — `chore(qg): 판 올림 · CHANGELOG`.

---

### Task 14: 전체 스위트 · 마지막 리뷰 · 미룸 · 구현 대조

- [ ] **Step 1: 전체 스위트를 공유 잠금 아래 한 번 돌린다** — Global Constraints 의 줄 그대로. 실패는 이름째 적고 이 브랜치가 만든 것만 고친다(worktree 전용 기존 실패 `TestCrossResolverAdvisory` 는 기존 실패로 적는다).
- [ ] **Step 2: 마지막 전체 리뷰를 띄운다** — 고른 실행 방식의 마지막 리뷰(쓰기 도구 없는 리뷰어)에게 싣는 것:
  - 설계문서 `## Acceptance Criteria` 의 AC 목록 전부(AC1–AC29)를 붙이고, AC 마다 한 줄 `AC<n>: <구현됨|미룸|빠짐> — <근거(파일:줄 · 시험 이름)>` 로 보고하게 한다. AC 번호가 과제 머리에 있는 것으로 끝내지 말고 그 시험이 그 동작을 실제로 재는지 보게 한다.
  - 설계문서 `## 있는 것 검토` 표의 열 행을 붙이고, 고른 것을 실제로 썼는지(같은 것을 다시 만들지 않았는지) 행마다 묻는다 — 특히 상한은 `ia.HANDED_MAX_BYTES` 하나 · 무력화는 `_defang` · 「확인 못 함」 줄 꼴은 `other_teams` 의 기존 줄 꼴 · 리뷰 기록 빼기는 `REVIEW_RECORD_TYPE` 하나 · 거른 상태는 `FILTERED_STATES` · 조상 판정은 `_ancestor` · 답 입력 읽기는 `parse_answer_input` 하나(남긴 글 도출이 따로 머리 줄을 읽지 않는다).
  - 과제 사이 이음매를 명시해 묻는다 — Task 1 의 `blocks` 를 Task 4 가 그대로 쓰는지, Task 3 의 `record_ran` 신호와 `commit: ""` 을 Task 4 · 5 가 같은 뜻으로 읽는지, Task 6 의 reference 글자가 Task 3 · 5 의 상수와 같은지, Task 9 의 `carry` · `doc_paths` 를 Task 10 · 11 이 같은 뜻으로 쓰는지, `record` 의 rc 1 을 누가 소비하는지(reference 표는 출력 줄로 가른다).
  - 계획이 실은 시험 코드는 「계획이 쓴 시험」 이라고 라벨을 단다.
  - 리뷰어의 AC 보고는 git 이 추적하지 않는 파일(`.claude/` 아래, `git check-ignore -q` 로 확인)에 그대로 적는다.
- [ ] **Step 3: 미룸 표를 고친다** — 리뷰 보고의 「미룸」 · 「빠짐」 과 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 더해 커밋한다(`docs(spec): R8 미룸 표 — 구현 대조`).
- [ ] **Step 4: 구현 대조를 돌려 경고를 사용자에게 보인다** — PR 을 만들기 전에: `python3 <spec-distill 캐시>/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-24-qg-answer-record-edges-design.md <Step 2 의 보고 파일>`.
- [ ] **Step 5: PR 본문** — Task 13 Step 4 의 표들(state-file-format.md 의 R9 인계 절 포함)과 설계 Constraints 의 「여섯」 이 일곱이라는 보고 한 줄(설계 글자는 고치지 않았다).
