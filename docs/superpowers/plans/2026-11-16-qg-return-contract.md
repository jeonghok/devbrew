# 돌려주는 꼴 계약 · qg 안쪽 뒤처리(R5) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `intent-critic` 단계의 결과 파일 `intent-return.md` 를 2판 꼴로 굳혀 그 파일 하나만 읽고 질문을 사람에게 옮길 수 있게 하고, R1 · R2 가 미룬 qg 안쪽 행 가운데 오류 없이 틀리는 것과 몇 줄로 멈춤 · 죽음을 막는 것을 고친다.

**Architecture:** 쓰는 자리는 그대로 `_write_return` 하나다. 칸 목록과 닫힌 어휘를 `intent_critic.py` 의 이름 붙은 상수로 두고, 상태 문서(`state-file-format.md`)의 칸 목록을 테스트가 그 상수와 글자로 잇는다. 질문의 상태 다섯은 한 함수(`_question_state`)가 정하고 결과 줄 · `result.md` 표 · 돌려주는 꼴이 모두 그 함수를 쓴다. 다른 팀 읽기(`other_teams.py`)와 문서 읽기(`intent_origin.py`)의 git 호출에 시간 한도를 두고, 넘긴 읽기는 읽는 쪽마다 「확인 못 함」 · 「읽지 못함」 으로 드러낸다.

**Tech Stack:** Python 3.9 표준 라이브러리 + PyYAML, bash 3.2 호환 셸 테스트(`shared/tests/assert.sh`), git.

**Spec:** `docs/superpowers/specs/2026-11-15-qg-return-contract-design.md` — 본문 §1–§8 과 `## Acceptance Criteria` 가 정본이다. `## 결정 기록` 의 D12 는 리뷰 결정 D1.2 가 고쳤다(본문 §5 의 6a 행 · AC13 이 지금 규칙). 앞쪽 결정 줄과 본문이 어긋나 보이면 본문과 뒤의 결정 줄(D1.1 · D1.2 · D13 · D14 · D15)을 따른다.

## Global Constraints

- **브랜치 · 커밋.** 브랜치 `feature/qg-return-contract` 에서만 일한다. 커밋은 pathspec 으로만. 쓰지 않는 것: `git add -A` · `git stash` · reset · rebase · force · push · 다른 worktree 의 git.
- **커밋 메시지.** Conventional Commits, 설명은 한국어(예: `feat(qg): 돌려주는 꼴 2판 머리`). 구현 커밋마다 트레일러 `Spec: docs/superpowers/specs/2026-11-15-qg-return-contract-design.md` 와 실행 세션의 `Co-Authored-By` 줄.
- **고치는 파일.** 설계 `## Files to Modify` 안: `scripts/intent_critic.py` · `intent_answers.py` · `intent_origin.py` · `other_teams.py` · `skills/quality-pipeline/references/intent-critic.md` · `state-file-format.md` · `tests/` · `.claude-plugin/plugin.json` · `CHANGELOG.md`(모두 `plugins/quality-gates/` 아래). **건드리지 않는 것:** `skills/quality-pipeline/SKILL.md` · `README.md` · `agents/intent-critic.md` · `scripts/setup-qg.sh`.
- **판정 불변.** 어떤 코드도 `findings.yaml` · `verdict.out` · `comment*.md` 를 쓰지 않고 `qg-verdict-args:` 줄을 내지 않는다(AC18).
- **꼴 2판의 값(글자 그대로 — 설계 §1 · §2).**
  - 머리 칸 차례: `contract` · `status` · `reason` · `reason_text` · `outcome` · `result_line` · `none_reason` · `mode` · `reviewed_head` · `reviewed_base` · `session_dir` · `answers_dir` · `answers_dir_source` · `commit` · `breadth` · `other_teams` · `overlaps` · `questions`
  - 질문 칸 차례: `n` · `id` · `state` · `answer` · `answer_text` · `wrong_choice` · `failure` · `file` · `evidence` · `question` · `target_source` · `target_id` · `label` · `quote` · `observation`
  - `contract: 2` · `status`: `ran` · `uncountable` · `skipped` · `failed` · `reason`(skipped): `kill-switch` · `halted` · `trivia` · `empty-diff` · `no-evidence` · `reason`(failed): `tree-failed` · 그 밖은 `-` · `outcome`(ran): `questions` · `none` · `no-evidence` · `all-filtered` · 그 밖은 `-`
  - 질문 `state`: `답함` · `답 기록 실패` · `답하지 않음` · `묻지 않음` · `상한 넘어 남김` · `wrong_choice`: 글자 `true` · `false` · `n`: 정수.
  - 글 칸(`reason_text` · `result_line` · `none_reason` · `session_dir` · 질문의 `id` · `answer` · `failure` · `file` · `evidence` · `question` · `target_source` · `target_id` · `label` · `quote`, 목록 칸 `observation` · `answer_text` 의 줄마다)은 `_one_line` 으로 접은 뒤 `json.dumps(…, ensure_ascii=False)` 로 따옴표에 싼다. 닫힌 어휘 칸은 `_scalar`.
- **끄기 스위치.** 전역 `DEVBREW_QUALITY_GATES_DISABLE=1` · 단계 `DEVBREW_QUALITY_GATES_DISABLE_INTENT_CRITIC=1`. 둘 다 변수를 직접 읽는다 — `kill_switch_active.py` 를 쓰지 않고 새 이름 붙은 스위치(`DEVBREW_SKIP_HOOKS=…`)를 열지 않는다(설계 §4 · D11). 읽는 하위 명령은 `gate` · `prepare` · `record` 뿐이다.
- **시간 한도.** `intent_origin.py` 에 `GIT_TIMEOUT = 30` 하나. `other_teams.py` 의 `PR_TIMEOUT` 은 `io_.GIT_TIMEOUT` 을 가리킨다(같은 상수 — 리터럴 30 을 둘 두지 않는다). 한도는 호출 하나의 것이고 전체를 묶는 한도는 두지 않는다.
- **열린 PR 조회 상한.** `other_teams.py` 에 `PR_LIMIT = 200`(지금 `--limit "200"` 의 값을 상수로).
- **새 상한 없음.** 7b · 7c · 6d 는 「하지 않음」 이다 — 어떤 자리에도 새 상한을 두지 않는다(설계 Anti-goals).
- **파이썬 규칙.** 3.9 문법(이 기계의 `python3` 은 3.9.6). 파일을 열 때 `encoding="utf-8"`(주석 속 `open(` 도 검사된다). 테스트에 `"python3"` 리터럴 금지(`sys.executable`). 헤딩 · 표시 · 백틱 토큰은 정규식이 아니라 문자열 메서드로 가른다. 비신뢰 글의 꼴 검사에 `re.match` + `$` 금지. 테스트는 `PYTHONDONTWRITEBYTECODE=1`. 20줄 이상 같은 블록을 두 파일에 두지 않는다(`shared/tests/test_no_new_duplication.sh`).
- **회계 배선(`intent_critic.py`).** 이 파일의 모든 `for` 문은 `tools/adjudication/check_wiring.py` 의 모집단이다 — `continue` · `break` · `return` 이 있는 갈래는 같은 갈래에 `Ledger` 처분 호출이 있어야 한다. 새 반복문은 이른 빠짐 없이(`if`/`else` 로) 쓴다. 컴프리헨션을 새로 쓰지 않는다(`COMP_BASELINE`). `intent_origin.py` · `intent_answers.py` · `other_teams.py` 는 `adjudication` 을 import 하지 않는다.
- **참고 문서 글자 함정.** 줄 머리에 `agent: ` 를 쓰지 않는다. 산문에 `Agent(` 를 쓰지 않는다. `AskUserQuestion` 글자는 질문 펜스 한 곳에만. 셸 펜스에서 한글 바로 앞 변수는 `${v}`.
- **gh 글자.** `gh` 뒤에 하위 명령이 이어지는 글자는 `scripts/other_teams.py` 와 테스트 · CHANGELOG 에만(`tests/test_publish_gh_two_files.sh`).
- **새 테스트 파일.** 파이썬 `tests/test_intent_return.py` 하나를 새로 둔다(아래 「계획이 정한 것」). 새 셸 테스트는 만들지 않는다 — 있는 `tests/test_intent_critic_wiring.sh`(100755)에 더한다.
- **변이.** 락의 이빨은 변이로 잰다 — 변이 전에 커밋하고, 복원은 `git checkout HEAD -- <파일>` 뒤 `git diff HEAD` 가 비었는지 본다. 변이는 지우기만이 아니라 값 바꾸기 · 칸 더하기로도.
- **판 올림.** quality-gates **major bump · 번호는 머지 직전에 지휘자가 정한다.** 구현은 이 브랜치의 판(`14.10.0`)의 다음 major(`15.0.0`)를 적어 락을 맞추고, 머지 직전에 지휘자가 기본 브랜치에 맞춰 번호를 고친다.
- **전체 스위트.** 과제 구현자는 돌리지 않는다 — 고친 파일을 덮는 테스트만 돈다. 전체는 Task 8 에서 공유 잠금으로만(worktree 루트에서):
  `python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.13.1"/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-qg-epic-roadmap-intent-review-brief/files/suite-lock --owner r5-impl --wait 5400 -- bash -c 'bash tools/suite/run-all.sh'`
  잠금을 못 잡으면 주인과 잡은 시각을 보고한다. worktree 에서는 `TestCrossResolverAdvisory` 가 기존 실패로 뜬다 — 기준 커밋에서도 같은지 견준다.
- **하위 agent.** 과제마다 띄울 하위 agent 의 모델은 역할에 맞는 등급을 superpowers:subagent-driven-development 의 Model Selection 절대로 고른다. 보내는 글에 위 잠금 줄 · 금지 목록 · TMPDIR(`/Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-qg-epic-roadmap-intent-review-brief/files/tmp/r5-impl`)을 그대로 싣고, 계획이 쓴 테스트 코드(plan-mandated)도 리뷰 대상이라고 적는다.

## Review Focus

- **사용자가 질문 창을 열고 하나도 답하지 않고 닫은 경우** — 기대: 그 질문은 `답하지 않음` 이고(묻기 전에 끊긴 실행의 `묻지 않음` 과 갈린다) 결과 줄은 「질문 k개를 물었다 · 답 0개(잘못 골랐다 0개) · 답하지 않음 k개」. 절차가 빈 입력으로 `record` 를 돌려야 성립한다. 테스트: Task 4 `test_empty_input_marks_unanswered`.
- **직접 쓴 답 안에 `===` 로 시작하는 줄(붙여 넣은 글 · 구분선)이 있는 경우** — 기대: 답 머리 꼴(`=== n: ` · `=== id: `)이 아닌 줄은 그 답의 원문으로 남는다. 머리 꼴 판별이 넓으면 사용자의 글이 잘린다. 테스트: Task 4 `test_typed_line_starting_with_equals_stays_text`.
- **리뷰어가 낸 질문 글 · 관찰에 줄바꿈 · U+2028 · 글 방향 글자 · 큰따옴표 · `: ` 가 든 경우** — 기대: 돌려주는 꼴이 YAML 로 읽히고, 칸마다 한 줄이며, 그 글자들이 그대로 실리지 않는다. 테스트: Task 3 `test_text_fields_are_folded_and_parse`.
- **두 스위치가 함께 켜졌거나 전역 스위치만 켠 채 `record` 를 부른 경우** — 기대: `reason_text` 가 켜진 변수를 모두 밝히고, `record` 는 전역 스위치만으로도 답 파일을 쓰지 않는다. 테스트: Task 2 `test_both_switches_named` · Task 4 `test_record_global_switch_writes_nothing`.
- **`topic-scope.txt` 가 `status: ok` 인데 `branches: -` 이거나 줄이 깨진 경우** — 기대: 아무 브랜치도 빼지 않고 단계가 멈추지 않는다(뺀 수 공시 없음). 테스트: Task 5 `test_topic_scope_without_members_excludes_nothing`.

---

## 다시 확인한 것 (계획 쓸 때 · 2026-11-16 · 이 브랜치 `3cc63b0a`)

설계 `## Metadata` 「고칠 자리」 의 함수 · 파일과 테스트의 잠금 단언을 지금 코드에서 봤다. 네 테스트(`test_intent_critic.py` · `test_intent_wide.py` · `test_other_teams.py` · `test_intent_critic_wiring.sh` — 172 통과)는 초록이다.

| 자리 | 지금 | 설계와 |
|---|---|---|
| 꼴 · 상태 · 결과 줄 | `intent_critic.py` 의 `_write_return(rd, status, mode, commit, rows, breadth, other_teams, overlaps)` · `_rows` · `_outcome` · `RETURN_STATES` · `_killed` · `cmd_gate` · `cmd_render` 가 있다. `status` 는 `"skipped — <글>"` · `ran` · `uncountable` | 같음 |
| 답 입력 | `_record` · `_answer_header`(머리 `=== id: <정체> · pick: <답>` — 정체만으로 붙인다) · `_stray_lines` · `_failed_notices`(질문에 `record_failed` 표지) | 같음 |
| 다른 팀 | `other_teams.py` 의 `_tips`(같은 sha 의 로컬 · 원격은 이미 하나로 — 로컬 이름이 이긴다) · `_later_base` · `_overlap_diff` · `collect` · `_git`(시간 한도 없음) · `one_line` · `--limit "200"`. 다른 팀 바이트 공시는 `intent_critic._prepare` 의 `io_.total_bytes(teams_text)`(기록 원문) | 같음 |
| 문서 읽기 | `intent_origin.py` 의 `frontmatter_value`(`str(value)`) · `_run_git`(시간 한도 없음) · `verify_quotes` · `_differential_state`(`yaml.YAMLError` 만 잡는다) | 같음. **이 기계의 파이썬 3.9.6 은 큰 정수의 `str()` 이 예외를 내지 않는다**(3.9.14 · 3.10.7 · 3.11 부터 낸다) — 11b 테스트는 예외를 주입해 잰다(Task 6) |
| 답 파일 | `intent_answers.parse_answer_file` 은 `yaml.YAMLError` 만 잡고, `read_answered` 는 파싱 예외를 잡지 않는다 | 같음 |
| 절차 I2 「꺼짐」 행 | 범위 모드면 「I5 끝의 리뷰 트리 지우기를 지나 I7」 | 같음. 트리 지우기 문단은 「`intent-call: none` 으로 온 실행과 표에 없는 종료 코드로 온 실행도 이 펜스를 지난다. 그래서 `render` 의 결과 줄이 마지막 스크립트 출력으로 남고」 라고만 적어, `render` 를 돌지 않는 꺼짐 실행이 빠져 있다(12a) |
| 절차 I5 | 머리 줄 `=== id: …` · 「답한 질문이 하나도 없으면 `record` 를 돌리지 않고」 | 같음 |
| 절차 I7 | 할 일을 `wrong_choice: yes` · 공시 줄의 `답 기록 실패 질문 — …` 에서 정한다 | 같음 |
| 잠금 단언 | `test_intent_wide.py::test_return_block_fields` 의 칸 목록 · `test_intent_critic.py` 의 `wrong_choice` 단언(`TestRender` 둘 · `TestRecord` 의 두 실패 테스트) · `test_intent_critic_wiring.sh` 머리 주석(「gh 는 PATH 앞의 가짜이고 불리지 않는다」 — kill 짝 실행에서는 불린다) · kill 짝 실행(가짜 `gh` 가 있는지 먼저 보지 않는다) | 같음 |
| 4b 의 반대 잠금 | `TestRecordUnreadAnswers` 가 「붙이지 못한 답 글이 있으면 답이 없던 질문까지 `답 기록 실패`」 를 지금 규칙으로 잠근다 | 설계 4b 가 뒤집는 규칙 — Task 4 가 이 클래스를 새 규칙으로 고쳐 쓴다 |

---

## 계획이 정한 것

설계 `### Deferred to plan` 의 다섯:

1. **「답 기록이 이 실행에서 돌았다」 표지(§2).** `record` 가 질문 기록(`intent-questions.yaml`)을 읽은 모든 갈래에서 `record_ran: true` 를 그 파일에 쓴다(범위 모드에서 아무것도 하지 않고 끝나는 갈래는 빼고). `render` 가 읽는다. 이유: 질문의 상태를 정하는 파일이 이미 그 파일이고, 따로 된 세션 파일을 두면 P2 지우기 목록(SKILL — R4 예약)을 고쳐야 한다.
2. **`reviewed_head` · `reviewed_base` 를 나르는 파일.** 계획 파일 `intent-plan.txt` 의 새 키 `reviewed_head:` · `reviewed_base:`. `prepare` 가 `call: none` 갈래에서도 쓴다. `render` 가 읽고, 계획 파일이 없거나 키가 없으면 `-`. 이유: `prepare` 가 쓰고 `render` 가 읽는 파일이 이미 그것이다.
3. **정확한 글.**

   | 자리 | 글 |
   |---|---|
   | `reason_text` — kill-switch | `intent-critic 꺼짐(kill switch — <변수>=1)` · 둘 다 켜졌으면 `<전역>=1 · <단계>=1`(전역이 앞) |
   | `reason_text` — halted · trivia · empty-diff · tree-failed | 지금 `GATE_SKIPS` 의 둘째 글 그대로(`멈춘 실행` · `작은 수정 — trivia` · `리뷰할 diff 없음` · `리뷰 트리를 만들지 못함`) |
   | `reason_text` — no-evidence · uncountable · ran | `근거 없음` · 공시 줄의 첫 줄(없으면 `-`) · `-` |
   | `record` 스위치 줄 | `intent-critic 꺼짐(kill switch — <변수>=1) — 답 파일을 쓰지 않고 커밋하지 않았다` |
   | 그때 질문의 `failure` | `kill switch(<변수>=1)가 켜져 있어 기록하지 않음` |
   | 4a 공시 · `failure` | `정체가 맞지 않는 답 머리 <n>개` · `정체가 맞지 않는 답 머리`(설계 글 그대로) |
   | 같은 번호 머리가 또 나옴 | `같은 질문 번호의 답 머리를 한 번만 받았다 — 더 나온 머리 <n>개` |
   | 번호 · 정체는 맞는데 고른 답을 읽지 못함 | `failure` 에 지금 `PICK_UNREAD`(`답을 읽지 못함`), `answer` 는 `-` |
   | 결과 줄 — 묻지 않음 | `intent-critic — 질문 <k>개 묻지 않음(범위 모드)` · `intent-critic — 질문 <k>개 묻지 않음(묻기 전에 끝남)`(설계 글 그대로) |
   | 6a — 묶음(다른 팀 기록 `## 다른 작업` 끝) | `같은 이름의 원격 사본 <n>개를 로컬 브랜치와 한 작업으로 묶었다` |
   | 6a — 갈라짐(「확인 못 함」) | `같은 이름의 원격 사본이 갈라져 있다 — <이름>`(설계 글 그대로) |
   | 6e — 뺀 수(다른 팀 기록 `## 다른 작업` 끝) | `토픽 리뷰의 형제 브랜치 <n>개를 다른 팀에서 뺐다 — 이번 리뷰 범위다` |
   | 6b(「확인 못 함」) | `열린 PR 이 조회 상한에 닿아 일부를 못 봤을 수 있다`(설계 글 그대로) |
   | 6g — 사유 | `REASON_TIMEOUT = "git 읽기가 시간 한도 %d초를 넘김" % GIT_TIMEOUT` |
   | 6g — 다른 팀(「확인 못 함」) | `git 읽기 <n>번이 시간 한도 <s>초를 넘겨 그 읽기를 확인 못 함` · 다른 브랜치의 의도 문서: `<브랜치> 의 <경로> 를 읽지 못함 — <REASON_TIMEOUT>` |
   | 6g — 원문 · 로드맵 · 바뀐 문서 | `<경로> 를 읽지 못함 — <REASON_TIMEOUT>` · `로드맵 <경로> 를 읽지 못함 — <REASON_TIMEOUT>` · `의도 문서인지 확인 못 한 문서 <n> — <REASON_TIMEOUT>` |
   | 9 | `리뷰 트리가 없어 읽은 인용을 확인하지 못함`(설계 글 그대로) |

4. **답 입력 머리 줄.** `=== n: <번호> · id: <정체> · pick: <의도다|잘못 골랐다|지금은 모르겠다|typed>`. 「답 머리 꼴」 은 `=== n: ` 또는 `=== id: `(옛 꼴)로 시작하는 줄뿐이다 — `===` 로 시작하는 다른 줄은 답 원문이다. 옛 꼴 머리는 받지 않고 4a 의 셈에 든다.
5. **테스트 자리 · 픽스처.** 새 `tests/test_intent_return.py` — 2판 꼴 · 상태 다섯 · `status`/`reason`/`outcome` · 답 입력(번호 · 4a · 4b · 스위치) · 문서 칸 목록 락. `test_intent_critic.py` 를 `import test_intent_critic as tic` 로 불러 헬퍼(`_cli` · `_env` · `_write` · `_read` · `_git` · `_git_repo` · `_filter_rd` · `_q` · `_out` · `_last` · `_questions` · `_return_block` · `_load`)만 빌린다. 다른 팀(6a · 6e · 6b · 6c · 6g · 10a)은 `test_other_teams.py` 에, 문서 읽기 · 답 파일 · `filter` 의 리뷰 트리(6g 의 원문 쪽 · 11b · 11c · 9 · 10c · 7a)는 `test_intent_wide.py` 에. 있는 락은 제자리에서 2판에 맞춘다. 이유: `test_intent_critic.py` 가 3174줄이다.

그 밖에 계획이 정한 것:

- **6a ② 의 이름.** 원격이 앞선 갈래는 로컬 끝을 목록에서 빼고 원격 끝을 그 원격 이름(`<원격>/<이름>`) 그대로 싣는다 — 원격 사본의 끝이라는 것이 이름에 보인다. 같은 sha 의 로컬 · 원격(지금도 하나로 접힌다)은 묶은 수에 세지 않는다 — 새로 묶는 것이 아니다. 두 끝의 관계를 git 이 답하지 못하면(실패 · 시간 한도) 지금처럼 둘 다 싣는다.
- **6e 의 구성원 판별.** 다른 작업 항목의 이름, 또는 그 끝 커밋을 가리키는 이름들(`_names_by_tip` — 원격 이름은 첫 마디를 뗀다) 가운데 하나가 `branches:` 의 이름이면 형제다.
- **입력 파일을 읽지 못한 `record`.** 지금처럼 물은 질문 모두를 `답 기록 실패`(`answer: "-"`)로 둔다(아래 「설계에 없던 결정 후보」 2).
- **`_one_line` 은 이미 U+2028 · 제어 · 글 방향 글자를 접는다**(`str.isprintable` 이 거짓인 글자를 빈칸으로). 새 정리 함수를 만들지 않는다.
- **6c 의 바꿔 쓰기.** 다른 팀 기록 전체를 쓰기 전에 `\n` · `\t` 밖의 인쇄할 수 없는 글자를 `?` 로(지금 `one_line` 과 같은 글자) — 기존 `_clean` 을 넓힌다.

## 설계에 없던 결정 (사용자가 2026-11-16 계획 검토에서 다섯 모두 받았다 — 「다섯 다 받는다 (권장)」)

설계문서가 말하지 않는 보이는 동작이다. 지휘자가 다르게 정하면 해당 과제의 테스트 · 글만 바꾼다.

1. **토픽 형제를 뺀 수의 자리(6e).** 설계는 「뺀 수를 공시한다」 만 적었다. 기본값: 6a 의 묶은 수와 같은 자리 — 다른 팀 기록의 `## 다른 작업` 끝 한 줄(리뷰어 입력에 실리고, `result.md` 의 겹침 · 확인 못 함 목록에는 나오지 않는다). Task 5.
2. **답 입력 파일 자체를 읽지 못한 `record`.** 설계 4b · AC12 는 설정을 읽지 못한 경우와 읽지 못한 줄만 말한다. 기본값: 지금처럼 묻는 질문 모두 `답 기록 실패`(`answer: "-"`) — 답이 있었는지 알 수 없어 「잘못 골랐다」 를 잃지 않는 쪽. Task 4.
3. **같은 질문 번호의 머리가 두 번 이상.** 기본값: 첫 머리만 받고 새 공시 줄 `같은 질문 번호의 답 머리를 한 번만 받았다 — 더 나온 머리 <n>개`. Task 4.
4. **번호 · 정체는 맞는데 고른 답이 라벨이 아닌 머리.** 지금은 머리가 아니라 앞 답의 원문이 된다. 기본값: 그 질문 `답 기록 실패`(`answer: "-"` · `failure: 답을 읽지 못함`). Task 4.
5. **I7 의 `묻지 않음` 할 일 글.** 범위 모드 「질문 <k>개를 묻지 않았다 — 부르는 쪽이 사람에게 옮긴다」 · PR 범위 「질문 <k>개를 묻기 전에 끝났다 — 다시 돌려 묻는다」. Task 7.

---

## 파일 구조

| 파일 | 맡는 일 | 과제 |
|---|---|---|
| `plugins/quality-gates/scripts/intent_critic.py` (고침) | 꼴 2판 상수 · `_write_return` · `_outcome` · `_question_state` · `_rows` · 스위치 판정 · 계획 파일의 리뷰 커밋 · 질문 번호 · 답 입력(번호 · 4a · 4b · 스위치) · 다른 팀 바이트 · 토픽 형제 넘기기 · 리뷰 트리 없음 · 바뀐 문서 시간 한도 공시 | 2 · 3 · 4 · 5 · 6 |
| `plugins/quality-gates/scripts/other_teams.py` (고침) | 같은 이름 원격 사본 · 토픽 형제 빼기 · git 시간 한도 · PR 조회 상한 · 본문 글자 정리 | 5 |
| `plugins/quality-gates/scripts/intent_origin.py` (고침) | `GIT_TIMEOUT` · `REASON_TIMEOUT` · 시간 한도 · 머리 값 예외 · 차등 결과 예외 · 다른 팀 줄 바이트 | 5 · 6 |
| `plugins/quality-gates/scripts/intent_answers.py` (고침) | 답 파일 읽기의 예외 | 6 |
| `plugins/quality-gates/tests/test_intent_return.py` (새) | 2판 꼴 · 상태 · 답 입력 · 문서 락 | 2 · 3 · 4 · 7 |
| `plugins/quality-gates/tests/test_intent_critic.py` · `test_intent_wide.py` · `test_other_teams.py` (고침) | 있는 락을 2판에 · 새 단위 테스트 | 2–7 |
| `plugins/quality-gates/tests/test_intent_critic_wiring.sh` (고침) | 머리 주석 · 가짜 gh 확인 · 머리 줄 · 결과 줄 글자 · 전역 스위치 실행 | 3 · 4 · 7 |
| `plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md` (고침) | I5(번호 머리 · 빈 입력도 `record`) · I2 꺼짐 행과 트리 지우기 · I7 · 수명 | 4 · 7 |
| `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md` (고침) | 결과 줄 · 표 상태 · 2판 절 · 수명 | 7 |
| `plugins/quality-gates/.claude-plugin/plugin.json` · `CHANGELOG.md` (고침) | major 판 · 바뀐 칸과 값 | 8 |

---

### Task 1: 다시 확인 (실행 시점)

**덮는 AC:** 없음(전제 확인)

위 「다시 확인한 것」 이 실행 시점에도 그런지 본다. 하나라도 다르면 멈추고 무엇이 어떻게 다른지 보고한다(고치지 않는다). 판만 다르면 Task 8 의 판을 그 다음 major 로 맞춰 진행한다.

**Files:** 읽기만 한다.

- [ ] **Step 1: 자리를 본다**

Run (각각, `plugins/quality-gates/` 아래):
```bash
grep -n '^def _write_return(rd: str, status: str, mode: str, commit: str, rows: List\[dict\],$\|^def _rows(\|^def _outcome(\|^RETURN_STATES = \|^def _killed(\|^def cmd_gate(\|^def cmd_render(\|^def _record(\|^def _answer_header(\|^def _stray_lines(\|^def _failed_notices(\|^def _one_line(' scripts/intent_critic.py
grep -c 'NOTICE_BYTES % (total, io_.total_bytes(teams_text),' scripts/intent_critic.py
grep -n '^def _tips(\|^def _later_base(\|^def _overlap_diff(\|^def collect(\|^def _git(\|^def one_line(\|^PR_TIMEOUT = 30$\|"--limit", "200"' scripts/other_teams.py
grep -n '^def frontmatter_value(\|^def _run_git(\|^def verify_quotes(\|^def _differential_state(\|    except yaml.YAMLError:' scripts/intent_origin.py
grep -n '^def read_answered(\|^def parse_answer_file(\|    except yaml.YAMLError:' scripts/intent_answers.py
grep -n '^| `intent-critic 꺼짐(kill switch)` | `gate` 뒤에\|`intent-call: none` 으로 온 실행과 표에 없는 종료 코드로 온 실행도 이 펜스를 지난다\|답한 질문이 하나도 없으면 `record` 를 돌리지 않고\|^=== id: <첫 질문의 id>\|`wrong_choice: yes` 인 질문이 있으면' skills/quality-pipeline/references/intent-critic.md
grep -n 'self.assertEqual(fields, \["id", "state", "answer", "wrong_choice", "file", "evidence"\])' tests/test_intent_wide.py
grep -n 'wrong_choice: yes\|wrong_choice: no\|class TestRecordUnreadAnswers' tests/test_intent_critic.py
grep -n 'gh 는 PATH 앞의 가짜이고 불리지 않는다\|^note "\[kill switch — 끈 prepare 검사의 양의 짝\]"' tests/test_intent_critic_wiring.sh
grep -n '"version"' .claude-plugin/plugin.json
```
Expected: 함수 머리 · 상수 · 문장이 모두 한 번씩 나온다. 판은 `14.10.0`.

- [ ] **Step 2: 네 테스트가 초록인지 본다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 plugins/quality-gates/tests/test_intent_critic.py` · `… test_intent_wide.py` · `… test_other_teams.py` · `bash plugins/quality-gates/tests/test_intent_critic_wiring.sh`
Expected: 파이썬 셋 `OK`, 셸 `Fail: 0`.

---

### Task 2: 꼴 2판 머리 — 닫힌 어휘 · 결과 줄 · 리뷰 커밋 · 스위치(gate · prepare)

**덮는 AC:** AC5 · AC6 · AC7 · AC10(gate · prepare)

**Files:**
- Modify: `plugins/quality-gates/scripts/intent_critic.py`
- Create: `plugins/quality-gates/tests/test_intent_return.py`
- Modify: `plugins/quality-gates/tests/test_intent_critic.py`(`TestGate` 셋 · `TestRender.test_render_missing_plan_is_uncountable` · `test_render_no_evidence` 의 `status` 단언) · `tests/test_intent_wide.py`(`test_return_block_fields` 의 머리 칸 목록)

**Interfaces:**
- Produces (`intent_critic.py`):
  - 상수 `CONTRACT = 2` · `RETURN_KEYS`(머리 칸 17개 — `questions` 뺌, 차례는 Global Constraints) · `QUESTION_KEYS`(질문 칸 15개) · `RETURN_STATUSES` · `SKIP_REASONS` · `FAIL_REASONS = ("tree-failed",)` · `RETURN_OUTCOMES` · `GLOBAL_KILL_ENV = "DEVBREW_QUALITY_GATES_DISABLE"`.
  - `GATE_SKIPS[path] = (줄, reason_text, status, reason)` — `aborted → skipped/halted` · `trivia → skipped/trivia` · `scope-empty → skipped/empty-diff` · `tree-failed → failed/tree-failed`. `--path` 의 값은 그대로다.
  - `_switches_on() -> List[str]` — 켜진(`== "1"`) 변수 이름, `GLOBAL_KILL_ENV` 가 앞.
  - `_kill_text(names: List[str]) -> str` — `"intent-critic 꺼짐(kill switch — %s)" % " · ".join(n + "=1" …)`.
  - `_write_return(rd: str, head: dict, rows: List[dict]) -> None` — `head` 에 없는 칸은 `-`. `contract` 는 늘 `CONTRACT`, `session_dir` 은 늘 `os.path.abspath(rd)`, `answers_dir` · `answers_dir_source` 는 지금처럼 설정 파일에서. `overlaps` 는 정수면 날 수로. 질문 행 쓰기는 Task 3 이 채운다 — 이 과제에서는 지금의 행 칸을 그대로 쓴다.
  - `_outcome(plan, data, mode) -> dict` — 키 `status` · `reason` · `reason_text` · `outcome` · `result_line` · `notices`.
  - `_resolve_commit(repo: str, rev: str) -> str` — `rev` 가 `-` 이거나 `-` 로 시작하면 `-`. 아니면 `_git_out(repo, "rev-parse", "--verify", "--quiet", rev + "^{commit}")` 의 40자 16진, 못 풀면 `-`.
  - `PLAN_KEYS` 에 `reviewed_head` · `reviewed_base`. `_write_plan(…, breadth="narrow", reviewed=("-", "-"))`. `_read_plan` 의 기본값 `-`.
  - `_candidates(plan, rd, ledger, notices, reasons: List[str])` — 쓴 출력(첫째 · 둘째 · 한 번)의 `none_reason` 이 빈 글 아닌 글이면 `_one_line` 해서 `reasons` 에 더한다. `cmd_filter` 가 질문 기록에 `none_reason`(` / ` 로 이음, 없으면 `-`)을 쓴다.

- [ ] **Step 1: 갈래 × 픽스처 표대로 실패하는 테스트를 쓴다** (`tests/test_intent_return.py` · `class TestReturnHead`)

| 갈래 | 픽스처 | 기대 `status` · `reason` · `outcome` · `result_line` |
|---|---|---|
| gate 단계 스위치 | `gate --path final` + `KILL=1` | `skipped` · `kill-switch` · `-` · `intent-critic 꺼짐(kill switch)` |
| gate 전역 스위치 | `gate --path trivia` + `DEVBREW_QUALITY_GATES_DISABLE=1` | 같음 |
| prepare 전역 스위치 | `prepare …` + 전역 | 같음, `reason_text` 가 전역 변수 이름 |
| halted · trivia · empty-diff | `gate --path aborted · trivia · scope-empty` | `skipped` · 그 부호 · `-` · 지금 줄 |
| tree-failed | `gate --path tree-failed --mode range` | `failed` · `tree-failed` · `-` |
| no-evidence | `_filter_rd(call="none")` → `render` | `skipped` · `no-evidence` · `-` · `intent-critic — 근거 없음` |
| uncountable | 계획 파일 없음 → `render` | `uncountable` · `-` · `-`, `reason_text` = 공시 첫 줄 |
| questions | 물은 질문 1 → `render` | `ran` · `-` · `questions` |
| none(없음) | `_out([], none_reason="물을 것이 없다")` → `filter` → `render` | `ran` · `-` · `none`, `none_reason: "물을 것이 없다"` |
| none(모두 이미 답함) | 이미 답한 질문만 낸 출력 | `ran` · `-` · `none` |
| no-evidence(좁게 걸러짐) | 근거 줄 없는 후보만 | `ran` · `-` · `no-evidence` |
| all-filtered | 넓은 계획(`breadth: range`) + 근거 없는 후보 | `ran` · `-` · `all-filtered` |

테스트 이름: `test_skip_and_fail_codes`(gate 여섯 · `reason_text` 가 지금 `GATE_SKIPS` 의 둘째 글) · `test_both_switches_named`(둘 다 켜면 `reason_text == "intent-critic 꺼짐(kill switch — DEVBREW_QUALITY_GATES_DISABLE=1 · DEVBREW_QUALITY_GATES_DISABLE_INTENT_CRITIC=1)"`) · `test_prepare_global_switch_reads_nothing`(전역만 켜고 `prepare` — 마지막 줄 꺼짐 줄, `other-teams.md` · `intent-scope.md` 없음, `ic._teams` 를 터지는 함수로 바꿔도 rc 0) · `test_outcomes`(표 아래 다섯 줄 — `result_line` 이 `render` 마지막 줄과 글자로 같다) · `test_none_reason_two_calls_joined`(`split` 두 출력의 `none_reason` 이 ` / ` 로) · `test_contract_and_session_dir`(모든 갈래에서 `contract == 2`, `session_dir == os.path.abspath(rd)`) · `test_reviewed_commits_survive_answer_commit`(임시 리포에서 `prepare --review-commit HEAD --base <첫 커밋>` → 커밋 하나 더 → `render`: `reviewed_head` 는 앞 HEAD 의 40자 해시이고 새 HEAD 가 아니며, `reviewed_base` 는 첫 커밋 해시, `os.path.join(session_dir, other_teams)` 가 있다).

모든 갈래에서 `status in ic.RETURN_STATUSES`, `reason` 은 `skipped` 면 `SKIP_REASONS`, `failed` 면 `FAIL_REASONS`, 그 밖은 `-`, `outcome` 은 `ran` 이면 `RETURN_OUTCOMES`, 그 밖은 `-` 임을 함께 단언한다.

- [ ] **Step 2: 실패를 본다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 plugins/quality-gates/tests/test_intent_return.py`
Expected: FAIL — `KeyError: 'contract'` · `AttributeError: … RETURN_STATUSES` 꼴.

- [ ] **Step 3: 위 Interfaces 대로 구현한다**

`cmd_gate` · `_killed` · `cmd_render` 가 `_write_return(rd, head, rows)` 를 부른다. `_killed` 는 `_switches_on()` 이 비지 않으면 지금 하던 꺼짐 처리(지우기 · 꼴 · `KILL_LINE` 출력)를 하고, 꼴의 `reason_text` 에 `_kill_text`. `prepare` 는 `_resolve_commit(args.repo, args.review_commit)` · `_resolve_commit(args.repo, args.base)` 를 두 `_write_plan` 호출 모두에 넘긴다. `render` 는 계획 파일의 두 값을 머리에 싣는다.

- [ ] **Step 4: 있는 락을 2판에 맞춘다**

- `TestGate.test_kill_switch_first` · `test_paths` · `test_tree_failed_writes_return_block`: `"status: skipped — "` 단언을 `(block["status"], block["reason"])` 단언으로.
- `TestRender.test_render_no_evidence`: `("skipped", "no-evidence")`.
- `test_intent_wide.py::test_return_block_fields`: 머리 칸 목록을 Global Constraints 의 차례(`contract` … `overlaps`, `questions`)로. 질문 칸 목록은 Task 3 이 바꾼다.

- [ ] **Step 5: 통과를 본다**

Run: `test_intent_return.py` · `test_intent_critic.py` · `test_intent_wide.py` · `bash plugins/quality-gates/tests/test_intent_critic_wiring.sh` · `bash shared/tests/test_adjudication_wiring.sh`
Expected: 실패 0. 배선 테스트의 kill 검사(`kill-return` 은 `intent-critic 꺼짐(kill switch)` 글을 찾는다)가 그대로 통과한다 — `result_line` 칸에 그 글이 있다.

- [ ] **Step 6: 커밋**

```bash
git add plugins/quality-gates/scripts/intent_critic.py plugins/quality-gates/tests/test_intent_return.py plugins/quality-gates/tests/test_intent_critic.py plugins/quality-gates/tests/test_intent_wide.py
git commit -m "feat(qg): 돌려주는 꼴 2판 머리 — 닫힌 어휘 · 결과 줄 · 리뷰 커밋"   # 트레일러 둘
```

---

### Task 3: 질문 칸 · 상태 다섯 · 질문 번호

**덮는 AC:** AC1(칸 · 번호 매김 · 한 줄 정리) · AC2 · AC4 · AC8

**Files:**
- Modify: `plugins/quality-gates/scripts/intent_critic.py`
- Modify: `plugins/quality-gates/tests/test_intent_return.py` · `tests/test_intent_critic.py`(`TestRender` 의 상태 · `wrong_choice` 단언 · `test_render_range_not_asked` · `test_render_separates_unanswered_questions` · `TestRecord` 의 두 실패 테스트의 행 단언) · `tests/test_intent_wide.py`(`test_r1_record_kind_is_dash` 의 표 줄 · `test_return_block_fields` 의 질문 칸) · `tests/test_intent_critic_wiring.sh`(범위 결과 줄 글자)

**Interfaces:**
- Consumes: Task 2 의 `_write_return(rd, head, rows)` · `QUESTION_KEYS`.
- Consumes (Task 4 가 쓰는 질문 기록의 키 — 이 과제의 테스트는 직접 심는다): 데이터 `record_ran: true`, 레코드 `record_failed: true` · `failed_answer` · `failure` · `answer_text`(줄 목록).
- Produces:
  - `cmd_filter` 가 `ordered`(물을 것 + 상한 넘어 남김, 고른 순서)의 레코드마다 `n`(1부터)을 단다. 이미 답해 거른 레코드에는 달지 않는다.
  - `QUESTION_STATES = ("답함", "답 기록 실패", "답하지 않음", "묻지 않음", "상한 넘어 남김")` — `RETURN_STATES` 를 대신한다.
  - `_question_state(record: dict, mode: str, record_ran: bool) -> Optional[str]` — `answered` → 답함 · `over-cap` → 상한 넘어 남김 · `ask` 이면 범위 모드 → 묻지 않음, `record_failed` → 답 기록 실패, `record_ran` → 답하지 않음, 아니면 묻지 않음 · 그 밖(거른 상태) → None.
  - `_rows(data, mode) -> List[dict]` — 행 키 = `QUESTION_KEYS`. `answer`: 답함이면 `answer`, 답 기록 실패면 `failed_answer`(없으면 `-`), 그 밖 `-`. `wrong_choice`: `answer == "잘못 골랐다"`. `answer_text`: 레코드의 줄 목록, 없으면 `-`. `failure`: 답 기록 실패면 `failure`, 그 밖 `-`. `file`: 범위 모드 `-`, 아니면 `file` 또는 `-`. `observation`: 레코드의 목록(없으면 빈 목록).
  - 결과 줄 상수 `NOT_ASKED_RANGE = "intent-critic — 질문 %d개 묻지 않음(범위 모드)"` · `NOT_ASKED_EARLY = "intent-critic — 질문 %d개 묻지 않음(묻기 전에 끝남)"`. `_outcome` 은 `_question_state` 로 센다: 범위 모드 → `NOT_ASKED_RANGE % 묻지 않음 수`, PR 범위에서 `record_ran` 이 아니면 → `NOT_ASKED_EARLY % 묻지 않음 수`, 아니면 지금 줄(물은 수 = 답함 + 답 기록 실패 + 답하지 않음 · `UNANSWERED % 답하지 않음 수`).

- [ ] **Step 1: 실패하는 테스트를 쓴다** (`tests/test_intent_return.py` · `class TestQuestionRows`)

갈래 × 픽스처(갈래마다 질문 기록 하나를 직접 쓴다 — `_filter_rd` 뒤 `intent-questions.yaml` 을 심는다):

| 기대 `state` | mode | `record_ran` | 레코드 |
|---|---|---|---|
| 답함 | pr | true | `state: answered` · `answer: 잘못 골랐다` · `file` |
| 답 기록 실패 | pr | true | `state: ask` · `record_failed: true` · `failed_answer: 잘못 골랐다` · `failure: 답 자리가 심볼릭 링크다` |
| 답하지 않음 | pr | true | `state: ask` |
| 묻지 않음(범위) | range | — | `state: ask` |
| 묻지 않음(PR · 끊김) | pr | 없음 | `state: ask` |
| 상한 넘어 남김 | pr | true | `state: over-cap` |

- `test_six_paths_give_five_states` — 위 여섯 갈래, `render` 뒤 돌려주는 꼴의 `state` 와 `result.md` 표의 상태 칸이 같은 글(AC8). 답 기록 실패 행은 `answer: 잘못 골랐다` · `wrong_choice: true` · `failure` 가 실린다.
- `test_result_line_counts_match_states` — 답함 1 · 답 기록 실패 1 · 답하지 않음 2: 결과 줄 `intent-critic — 질문 4개를 물었다 · 답 1개(잘못 골랐다 1개) · 답하지 않음 2개`, 돌려주는 꼴의 `답하지 않음` 수 2.
- `test_not_asked_lines` — 범위 모드 둘: `intent-critic — 질문 2개 묻지 않음(범위 모드)`. PR · `record_ran` 없음 둘: `intent-critic — 질문 2개 묻지 않음(묻기 전에 끝남)`. 두 결과 줄 모두 `물었다` 를 담지 않는다.
- `test_wrong_choice_is_bool_text` — 꼴 글에 `    wrong_choice: true\n` · `    wrong_choice: false\n` 줄이 있고 `yes` · `no` 는 없다(AC4).
- `test_question_fields_carried` — 실제 `filter` 를 거친 질문 하나(`_q("D1", lines=[1, 2])`): 행의 `question` · `target_source` · `target_id` · `label` · `quote` 가 질문 기록과 같고 `observation` 이 근거 줄 둘 전부, `n == 1`.
- `test_numbers_unique_per_run` — 같은 정체의 후보 둘 + 다른 후보 셋(상한 넘음 포함): 행의 `n` 이 1..5 로 겹치지 않고, 상한 넘은 행에도 있다. 이미 답해 거른 레코드에는 `n` 이 없다.
- `test_text_fields_are_folded_and_parse` — 질문 글 `"줄\n바꿈 가름‮방향 \"따옴표\" a: b"` · 관찰 줄에 `\x07`: 꼴이 `yaml.safe_load` 로 읽히고, 그 글자들(`\n` · ` ` · `‮` · `\x07`)이 칸 값에 없으며, 꼴 글에서 질문 칸이 한 줄이다(AC1 · Review Focus).
- `test_question_keys_in_order` — 첫 질문 행의 칸 차례가 Global Constraints 의 질문 칸 차례와 같다(계획에 적힌 목록을 리터럴로 — `ic.QUESTION_KEYS` 를 쓰지 않는다).

- [ ] **Step 2: 실패를 본다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 plugins/quality-gates/tests/test_intent_return.py -k TestQuestionRows`
Expected: FAIL — 상태가 `아직 묻지 않음` · 칸 없음.

- [ ] **Step 3: Interfaces 대로 구현한다**

`_write_return` 이 행을 `QUESTION_KEYS` 차례로 쓴다 — `n` 은 정수, `wrong_choice` 는 `true`/`false`, `answer_text` 는 `-` 면 `"-"`, 목록이면 줄마다 `      - "<글>"`, `observation` 은 빈 목록이면 `[]`. `_section` 의 표는 `_rows` 의 `state` 를 그대로 쓴다.

- [ ] **Step 4: 있는 락을 맞춘다**

- `test_intent_critic.py`: `"    wrong_choice: no\n"` · `yes` → `false` · `true`. `assertIs(… wrong_choice, True)` 는 그대로 참이다. `아직 묻지 않음` 을 갈래에 맞는 새 값으로 — `TestRecord` 의 실패 테스트 둘(답 자리가 링크 · 부분 쓰기)은 그 질문이 `답 기록 실패`(그 답 · 사유가 실린다)다. `test_render_separates_unanswered_questions` 의 `states` 사전은 `record_ran` 을 심은 갈래와 함께 새 상태로. `test_render_range_not_asked` 의 결과 줄은 `NOT_ASKED_RANGE`.
- `test_intent_wide.py::test_r1_record_kind_is_dash` — 질문 기록에 `record_ran` 이 없으므로 표 줄은 `| … | 묻지 않음 | - | - | - | Q |`. `test_return_block_fields` 의 질문 칸 목록을 Global Constraints 의 차례로.
- `test_intent_critic_wiring.sh` 380행 근처의 범위 결과 줄을 `intent-critic — 질문 1개 묻지 않음(범위 모드)` 로.

- [ ] **Step 5: 통과를 본다**

Run: 파이썬 셋(`test_intent_return.py` · `test_intent_critic.py` · `test_intent_wide.py`) · 배선 테스트 · `bash shared/tests/test_adjudication_wiring.sh`
Expected: 실패 0.

- [ ] **Step 6: 커밋**

```bash
git add plugins/quality-gates/scripts/intent_critic.py plugins/quality-gates/tests/test_intent_return.py plugins/quality-gates/tests/test_intent_critic.py plugins/quality-gates/tests/test_intent_wide.py plugins/quality-gates/tests/test_intent_critic_wiring.sh
git commit -m "feat(qg): 돌려주는 꼴의 질문 칸과 상태 다섯 · 질문 번호"   # 트레일러 둘
```

---

### Task 4: 답 입력 — 번호 머리 · 4a · 4b · `record` 의 스위치 · 절차 I5

**덮는 AC:** AC1(둘째 질문만 답함) · AC2(창을 보였는데 답이 없음) · AC3 · AC10(record) · AC11 · AC12

**Files:**
- Modify: `plugins/quality-gates/scripts/intent_critic.py`
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md`(I5 만)
- Modify: `plugins/quality-gates/tests/test_intent_return.py` · `tests/test_intent_critic.py`(머리 줄 30곳 · `TestRecordSilentDrops.test_wrong_id_header_is_disclosed` · `TestRecordUnreadAnswers` · `TestProcedureDoc.test_unanswered_questions_are_not_recorded`) · `tests/test_intent_critic_wiring.sh`(머리 줄 printf 둘)

**Interfaces:**
- Consumes: Task 3 의 `n` · 레코드 키(`record_failed` · `failed_answer` · `failure` · `answer_text`) · 데이터 키 `record_ran`.
- Produces:
  - `HEADER = "=== n: "` · `ID_SEP = " · id: "` · `PICK_SEP = " · pick: "`(그대로) · `HEADER_SHAPES = ("=== n: ", "=== id: ")`.
  - `parse_answer_input(text: str, known: dict) -> dict` — `known` 은 `{n: 정체}`(묻는 질문만). 돌려주는 것 `{"entries": [{"n", "id", "pick", "lines"}], "orphan": int, "mismatched": [(n | None, pick | None)], "duplicates": int}`.
  - 질문 기록에 쓰는 것: 데이터 `record_ran: true`(Task 3 이 읽는다), 실패 레코드에 `record_failed` · `failed_answer` · `failure`, 직접 쓴 답이면(성공 · 실패 모두) `answer_text`(원문 줄 목록 — 쓰기는 `_rows` 가 줄마다 접는다).

**머리 줄 읽기 규칙**(시그니처와 테스트가 정하지 않는 것):
1. 줄(끝 `\r` 를 걷은)이 `HEADER_SHAPES` 가운데 하나로 시작하면 「답 머리 꼴」 이다. 아니면 지금 답의 원문 줄이거나(첫 머리 앞이면) `orphan` 에 센다(빈 줄 제외).
2. 머리 꼴이면 늘 지금 답을 끝낸다. `HEADER` 로 시작하고 `ID_SEP` 앞이 ASCII 숫자이며 그 수가 `known` 에 있고, `PICK_SEP` 를 오른쪽에서 갈라 얻은 정체가 `known[n]` 과 같으면:
   - 그 `n` 의 답이 이미 있으면 `duplicates += 1`, 그 줄과 아래 글은 어디에도 싣지 않는다.
   - 고른 답이 `ia.ANSWERS + (TYPED,)` 가운데 하나면 새 답이다. 아니면 그 질문은 `답 기록 실패`(`answer: "-"`, `failure: PICK_UNREAD`)이고 아래 글은 싣지 않는다.
3. 그 밖의 머리 꼴(번호 없음 · 옛 `=== id:` 꼴 · 모르는 번호 · 정체가 다름)은 `mismatched` 에 `(n 또는 None, 읽힌 고른 답 또는 None)` 로 남기고 그 줄과 아래 글은 어디에도 싣지 않는다. `n` 이 묻는 질문을 가리키고 정체만 다르면 그 질문은 `답 기록 실패`(`answer` = 머리의 고른 답 — 고른 답이 라벨이 아니면 `-`, `failure: 정체가 맞지 않는 답 머리`). 같은 `n` 에 받은 답이 따로 있으면 받은 답이 이긴다.
4. `mismatched` 가 있으면 `정체가 맞지 않는 답 머리 <len>개`, `duplicates` 가 있으면 `같은 질문 번호의 답 머리를 한 번만 받았다 — 더 나온 머리 <n>개` 를 공시한다(record 출력과 `record_notices`). `머리 앞의 답 글을 읽지 못함 <n>줄` · `답 입력에서 묻는 질문의 머리를 찾지 못함 — 묻는 질문 <n>개` 는 지금 조건대로 남는다.

**실패 표지 규칙(4b).** `답 기록 실패` 는 입력에 그 질문의 답이 있던 질문(받은 답 · 규칙 2 의 읽지 못한 고른 답 · 규칙 3 의 번호만 맞은 머리)에만 단다. 설정 · 계획 · 질문 기록을 읽지 못한 갈래(`blocked`)와 답 파일 쓰기 실패도 같다 — 답이 없던 질문은 `답하지 않음` 이다. 붙이지 못한 글(`_stray_lines` · `UNREAD_INPUT` 갈래)로 다른 질문을 실패시키지 않는다 — `UNREAD_INPUT` 갈래를 지운다. 예외: 답 입력 파일 자체를 읽지 못하면(`text is None`) 지금처럼 묻는 질문 모두가 `답 기록 실패`(`answer: "-"`).

**스위치.** `_record` 는 맨 먼저 `_switches_on()` 을 본다. 켜져 있으면 답 파일을 쓰지 않고 커밋하지 않으며 `intent-critic 꺼짐(kill switch — <변수들>) — 답 파일을 쓰지 않고 커밋하지 않았다` 한 줄을 낸다. 질문 기록과 입력을 읽을 수 있으면 입력을 위 규칙으로 읽어 답이 있던 질문을 `답 기록 실패`(`failure: kill switch(<변수들>)가 켜져 있어 기록하지 않음`, `answer` = 고른 답)로 두고 `record_ran: true` 와 함께 질문 기록에 쓴다. 꼴은 쓰지 않는다(뒤의 `render` 가 쓴다). 마지막 줄은 지금처럼 `record: 0`.

- [ ] **Step 1: 실패하는 테스트를 쓴다** (`tests/test_intent_return.py` · `class TestAnswerInput`, 임시 리포는 `tic._git_repo`)

- `test_second_of_same_identity` — 정체가 같은 두 질문(질문 글 `첫째 글` · `둘째 글`)에 `=== n: 2 · id: <정체> · pick: 의도다` 하나: 둘째만 `답함`, 첫째 `답하지 않음`, 답 파일 하나의 `## 질문` 이 `둘째 글`(AC1).
- `test_empty_input_marks_unanswered` — 빈 입력으로 `record`: 출력 `record: 0` 만, 질문 둘 `답하지 않음`, 결과 줄 `… 답 0개(잘못 골랐다 0개) · 답하지 않음 2개`(AC2 · Review Focus).
- `test_wrong_header_after_typed_answer` — `=== n: 1 · id: <정체1> · pick: typed` / `이유 글` / `=== n: 2 · id: 틀린#정체#방향 · pick: 잘못 골랐다` / `딸린 글`: 답 파일의 원문은 `이유 글` 뿐(`딸린 글` · 머리 줄 없음), 질문 2 는 `답 기록 실패` · `answer: 잘못 골랐다` · `wrong_choice: true` · `failure: 정체가 맞지 않는 답 머리`, 출력에 `정체가 맞지 않는 답 머리 1개`(AC11).
- `test_unknown_number_only_disclosed` — `=== n: 9 · id: x · pick: 의도다` 와 옛 꼴 `=== id: <정체1> · pick: 의도다`: 공시 `정체가 맞지 않는 답 머리 2개`, 질문 모두 `답하지 않음`.
- `test_duplicate_number_first_wins` — 같은 `n` 의 머리 둘(의도다 · 잘못 골랐다): 답 파일 하나 · 답 `의도다` · 공시 `같은 질문 번호의 답 머리를 한 번만 받았다 — 더 나온 머리 1개`.
- `test_typed_line_starting_with_equals_stays_text` — typed 답 아래 `=== 메모 ===` · `===` 줄: 둘 다 답 원문에 남는다(Review Focus).
- `test_failed_answer_carried` — 답 자리가 링크라 쓰기 실패 · `pick: typed` 원문 둘째 줄까지: `답 기록 실패` · `answer` 는 원문 첫머리 라벨 · `answer_text` 가 원문 두 줄 · `failure` 가 쓰기 사유(AC3).
- `test_typed_answer_text_on_success` — 기록에 성공한 typed 답도 `answer_text` 가 원문 줄들, 라벨을 고른 답은 `answer_text: "-"`(AC3).
- `test_unreadable_config_fails_only_answered` — 설정 파일을 지우고 질문 둘 가운데 하나만 답: 답한 질문 `답 기록 실패`, 다른 질문 `답하지 않음`, 공시 `답 기록 실패 1개 — …`(AC12).
- `test_stray_text_does_not_fail_others` — 첫 머리 앞 `잘못 골랐다` 한 줄 + 질문 1 답: 질문 2 는 `답하지 않음`, 공시 `머리 앞의 답 글을 읽지 못함 1줄`(AC12).
- `test_unreadable_input_file_keeps_failure` — 입력 파일이 없음: 묻는 질문 모두 `답 기록 실패`(`answer: "-"`).
- `test_record_stage_switch_writes_nothing` · `test_record_global_switch_writes_nothing` — 각 스위치로 `record`: 답 파일 폴더 없음 · HEAD 그대로 · 스위치 줄 한 줄 · 답한 질문 `답 기록 실패`(고른 답 · 스위치 사유) · 답하지 않은 질문 `답하지 않음` · `intent-return.md` 를 쓰지 않음(AC10 · Review Focus).

- [ ] **Step 2: 실패를 본다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 plugins/quality-gates/tests/test_intent_return.py -k TestAnswerInput`
Expected: FAIL.

- [ ] **Step 3: 위 규칙대로 구현한다**

`_record` 의 짝짓기는 `n` 으로 한다(`pending` 을 정체가 아니라 `n` 으로). 답 파일의 질문 글 · 구절 · 관찰은 그 `n` 의 레코드에서. 질문 기록은 읽을 수 있으면 모든 갈래에서 쓴다(`_save_record` 는 `data` 가 있으면 늘 쓴다). `parse_answer_input` · `_record` 의 새 반복문은 이른 빠짐 없이 쓴다(회계 배선).

- [ ] **Step 4: 절차 I5 를 맞춘다** (`references/intent-critic.md`)

- 질문 창 `header: "의도 점검 <n>"`, 자리 채우기의 `<k>` 항목을 `- `<n>` — 그 항목의 `n`.` 으로.
- 「질문 창을 닫거나 답하지 않은 질문은 머리 줄을 쓰지 않는다. 답한 질문이 하나도 없으면 …」 문장을: 「질문 창을 닫거나 답하지 않은 질문은 머리 줄을 쓰지 않는다. 질문 창을 보였으면 답한 질문이 하나도 없어도 `record` 를 돈다 — 입력 파일을 머리 줄 없이 비워 둔다. `record` 가 돈 실행의 답하지 않은 질문은 돌려주는 꼴에 `답하지 않음` 으로 남고 결과 줄이 `답하지 않음 <k>개` 로 가른다 — 할 일은 [I7](#i7-돌려주기).」
- **답 기록.** 머리 줄 꼴을 `=== n: <그 항목의 n> · id: <그 항목의 id> · pick: <고른 것>` 으로, 펜스의 예시 줄을 `=== n: <첫 질문의 n> · id: <첫 질문의 id> · pick: <…>` 로. 「번호 없는 머리 줄 · 번호와 정체가 맞지 않는 머리 줄은 받지 않는다 — 그 줄과 아래 글은 어느 답에도 실리지 않고 `정체가 맞지 않는 답 머리 <n>개` 로 공시된다」 한 문장을 더한다.
- 표의 `범위 모드` 행: 「질문은 모두 `묻지 않음` 으로 돌려준다」.
- 표에 `intent-critic 꺼짐(kill switch — …) — 답 파일을 쓰지 않고 커밋하지 않았다` 행(그대로 보이고 I6 — 답이 있던 질문은 `답 기록 실패` 로 남는다)을 더한다.
- `답 기록 실패 <n>개 — <사유>` 행의 「답 파일을 쓰지 못했거나 답 입력에서 읽지 못한 답이다」 를 「답 파일을 쓰지 못했거나 · 스위치로 막혔거나 · 머리가 맞지 않은 답이다」 로.

- [ ] **Step 5: 있는 테스트를 맞춘다**

- `test_intent_critic.py` 의 `=== id: %s · pick:` 머리 30곳을 번호 꼴로(질문 기록의 `n` 을 읽어 넣는다 — 헬퍼 하나 `_header(rd, ident, pick, nth=1)` 를 이 파일에 두고 `test_intent_return.py` 가 빌린다).
- `TestRecordSilentDrops.test_wrong_id_header_is_disclosed` — 옛 꼴 머리는 `정체가 맞지 않는 답 머리 1개` 로 공시되고 `머리 앞의 답 글을 읽지 못함` 은 나오지 않는다.
- `TestRecordUnreadAnswers` — 클래스 설명과 테스트를 4b 로: 머리가 하나도 맞지 않음 → 질문 모두 `답하지 않음` · 4a 공시 · `답 기록 실패` 줄 없음. 하나만 맞고 다른 머리는 번호만 맞음 → 그 질문 `답 기록 실패`(4a 사유). 첫 머리 앞 글 → 다른 질문 `답하지 않음`. 설정 · 입력을 읽지 못함 → 위 `test_unreadable_*` 와 같은 규칙.
- `TestProcedureDoc.test_unanswered_questions_are_not_recorded` — 이름과 문장을 새 I5 문장으로(그 문장이 한 번 · 질문 앵커 뒤 · **답 기록.** 앞).
- 배선 테스트 printf 두 줄: `=== n: 1 · id: diff#… · pick: 의도다`.

- [ ] **Step 6: 통과를 보고 변이로 이빨을 잰다**

Run: 파이썬 셋 · 배선 · `bash shared/tests/test_adjudication_wiring.sh`. Expected: 실패 0.
커밋한 뒤 변이 둘 — ① 짝짓기에서 정체 비교를 지운다(번호만 맞으면 받음) ② 4b 실패 표지를 묻는 질문 모두에 단다 — 각각 `test_wrong_header_after_typed_answer` · `test_unreadable_config_fails_only_answered` 가 RED 인지 보고 `git checkout HEAD -- plugins/quality-gates/scripts/intent_critic.py` 로 되돌린다(`git diff HEAD` 빈 것 확인).

- [ ] **Step 7: 커밋**

```bash
git add plugins/quality-gates/scripts/intent_critic.py plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md plugins/quality-gates/tests/test_intent_return.py plugins/quality-gates/tests/test_intent_critic.py plugins/quality-gates/tests/test_intent_critic_wiring.sh
git commit -m "fix(qg): 답 입력을 질문 번호로 붙이고 실패 표지를 답이 있던 질문에만"   # 트레일러 둘
```

---

### Task 5: 다른 팀 읽기 — 같은 이름 원격 사본 · 토픽 형제 · 시간 한도 · PR 상한 · 글자 · 바이트

**덮는 AC:** AC13 · AC14 · AC15 · AC16(다른 팀 쪽 시간 한도 · PR 상한 · 제어 · 방향 글자) · AC17(10a)

**Files:**
- Modify: `plugins/quality-gates/scripts/other_teams.py` · `scripts/intent_origin.py`(`GIT_TIMEOUT` · `REASON_TIMEOUT` · `TIMED_OUT` · `teams_bytes`) · `scripts/intent_critic.py`(`_teams` · 토픽 범위 읽기 · 바이트 공시)
- Modify: `plugins/quality-gates/tests/test_other_teams.py` · `tests/test_intent_wide.py`

**Interfaces:**
- Produces (`intent_origin.py`): `GIT_TIMEOUT = 30` · `REASON_TIMEOUT = "git 읽기가 시간 한도 %d초를 넘김" % GIT_TIMEOUT` · `TIMED_OUT`(`returncode = -1` · `stdout = b""` · `stderr = b""` 인 한 객체 — 시간 한도를 넘긴 git 호출이 `None` 대신 돌려준다) · `teams_bytes(evidence: str) -> int` = 근거 글에서 `evidence_kind(줄) == KIND_TEAMS` 인 줄들을 `"\n"` 으로 이은 글의 UTF-8 바이트. `_run_git` 은 `timeout=GIT_TIMEOUT` 으로 부르고 `subprocess.TimeoutExpired` 면 `TIMED_OUT`. `read_tracked` · `read_tree` 는 그 git 호출이 `TIMED_OUT` 이면 `(None, REASON_TIMEOUT)`.
- Produces (`other_teams.py`): `PR_TIMEOUT = io_.GIT_TIMEOUT` · `PR_LIMIT = 200` · `LINE_PR_LIMIT` · `LINE_DIVERGED = "같은 이름의 원격 사본이 갈라져 있다 — %s"` · `LINE_FOLDED` · `LINE_SIBLINGS` · `LINE_TIMEOUTS` · `LINE_DOC_TIMEOUT`(글은 「계획이 정한 것」 3).
  - `_git` 은 `timeout=PR_TIMEOUT`, `TimeoutExpired` 면 모듈의 셈(`collect` 가 시작에 비운다)에 하나 더하고 `io_.TIMED_OUT`.
  - `_tips(repo, notes: Optional[dict] = None)` — 돌려주는 꼴은 그대로. sha 로 접기 전에 같은 이름 원격 사본을 가른다(규칙은 설계 §5 6a 행 · 「계획이 정한 것」). `notes` 가 있으면 `notes["folded"]`(int) · `notes["diverged"]`(로컬 이름의 정렬된 목록)를 채운다. `other_work(repo, default_ref, end, notes=None)` 가 넘긴다.
  - `collect(…, list_prs=open_prs, siblings: Optional[set] = None)` — `siblings` 의 형제를 다른 작업 항목에서 뺀다(겹침 표시 · PR 붙이기 전에). 받은 PR 목록 길이가 `PR_LIMIT` 이면 `LINE_PR_LIMIT`. 다른 브랜치의 의도 문서를 `REASON_TIMEOUT` 으로 못 읽으면 `LINE_DOC_TIMEOUT`. 시간 한도 셈이 0 이 아니면 `LINE_TIMEOUTS`. `LINE_FOLDED` · `LINE_SIBLINGS` 는 0 이 아닐 때만 `## 다른 작업` 끝(「그 밖의 브랜치 …」 줄 뒤)에. `LINE_DIVERGED` 는 이름마다 「확인 못 함」 에.
  - `_clean(text)` — 짝 없는 surrogate 에 더해 `\n` · `\t` 밖의 인쇄할 수 없는 글자를 `?` 로.
- Produces (`intent_critic.py`): `_topic_siblings(rd: str) -> Optional[set]` — 세션 폴더 `topic-scope.txt` 의 `status:` 가 `ok` 이고 `branches:` 가 `-` 아닌 쉼표 목록일 때만 그 이름들(빈 조각 뺌), 아니면 None. `_teams(args, names, roadmaps, cfg, siblings=None, collect=ot.collect)` 가 `collect(…, siblings=siblings)` 로 넘긴다(`test_intent_wide.py:452` 의 `lambda *a` 대역이 계속 돌게 `_prepare` 는 `siblings` 를 위치 인자로 넘긴다). `NOTICE_BYTES` 의 둘째 수는 `io_.teams_bytes(evidence)`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_other_teams.py` — 고치는 테스트는 `_fresh()` 리포에서 ref 만 세운다(`update-ref`):
- `class TestSameNameRemote`: `test_remote_behind_local_folded`(로컬 `feature/far` 에 커밋 하나 더 · `refs/remotes/origin/feature/far` = 옛 끝 → 원격 사본이 항목에 없고 `## 다른 작업` 에 `같은 이름의 원격 사본 1개를 로컬 브랜치와 한 작업으로 묶었다`) · `test_remote_ahead_listed_and_counted`(원격이 로컬보다 하나 앞 → `origin/feature/far` 항목의 sha 가 원격 끝, 로컬 항목 없음, 묶은 수 1. 로컬이 리뷰 끝(`end`)이어도 실린다) · `test_diverged_not_listed`(서로 갈라짐 → 원격 항목 없음, 「확인 못 함」 에 `같은 이름의 원격 사본이 갈라져 있다 — feature/far`, 겹침 목록에 그 이름 없음) · `test_other_remote_name_also_folds`(`refs/remotes/upstream/feature/far` 도 같은 규칙) · `test_range_and_pr_same_rule`(같은 리포에서 `review_commit` 을 끝 커밋 sha 로 준 `collect` 와 `HEAD` 로 준 `collect` 의 다른 작업 · 「확인 못 함」 이 같다)(AC13).
- `class TestTopicSiblings`: `test_members_excluded_and_counted`(`siblings={"feature/mine-next", "feature/other"}` → 두 항목 없음 · 겹침 목록에 `feature/other` 없음 · `토픽 리뷰의 형제 브랜치 2개를 다른 팀에서 뺐다 — 이번 리뷰 범위다`. 원격 이름 `origin/feature/other` 도 빠진다) · `test_ancestor_sibling_excluded`(다른 형제의 조상인 형제도 이름으로 빠진다) · `test_no_siblings_keeps_all`(`siblings=None` → 지금과 같은 글)(AC14).
- `class TestGitTimeout`: `subprocess.run` 을 감싸 `for-each-ref` 에서만 `subprocess.TimeoutExpired` 를 내는 대역으로 `collect` → 예외 없이 끝나고 「확인 못 함」 에 `git 읽기 1번이 시간 한도 30초를 넘겨 그 읽기를 확인 못 함` 과 `브랜치 목록을 읽지 못함 — 다른 브랜치를 읽지 않았다`. 의도 문서 `show` 에서만 내면 `feature/other 의 team/other-design.md 를 읽지 못함 — git 읽기가 시간 한도 30초를 넘김`. 모든 git 호출의 `timeout` 인자가 `30`(대역이 받은 kwargs 로)(AC16).
- `class TestOpenPrLimit`: 주입한 `list_prs` 가 200개를 돌려주면 「확인 못 함」 에 `열린 PR 이 조회 상한에 닿아 일부를 못 봤을 수 있다`, 199개면 없다. `open_prs` 의 argv 가 `--limit` 뒤 `str(ot.PR_LIMIT)`(AC16).
- `class TestBodyCharacters`: 다른 브랜치 의도 문서 본문에 `‮` · `\x1b[31m` · ` ` · `\r` 를 넣은 커밋 → 기록 글에 그 글자들이 없고 `?` 가 있으며 `\t` 와 줄바꿈은 남는다. 그 기록으로 만든 근거 파일(`io_.build_evidence(None, None, text)`)의 줄 수가 기록의 빈 줄 아닌 줄 수와 같다(AC16).
- `class TestLaterBase.test_bases_differ_not_ancestor_takes_default` — 기본 쪽 커밋 `d1` 과 끝 쪽 커밋 `e1`(둘 다 `c0` 위, 서로 조상 아님)을 합친 브랜치: `_later_base` 가 `d1` 을 돌려준다(AC17 · 10a).

`test_intent_wide.py`:
- `test_topic_scope_members_excluded` — `topic-scope.txt`(`status: ok` · `branches: feature/x,feature/y`)를 둔 세션 폴더로 `prepare`(대역 `collect` 가 받은 `siblings` 를 적는다) → `{"feature/x", "feature/y"}`. `status: merge-failed` 면 None(AC14).
- `test_topic_scope_without_members_excludes_nothing` — `status: ok` · `branches: -`, 그리고 `branches:` 줄이 없는 파일 → None, rc 0(Review Focus).
- `test_teams_bytes_match_evidence` — 다른 팀 기록이 실린 넓은 `prepare`: 공시 `입력 <a>바이트 · 다른 팀 기록 <b>바이트(…)` 의 `<b>` 가 `intent-evidence.txt` 의 `[다른 팀] ` 줄들을 `"\n"` 으로 이은 글의 바이트와 같다(AC15).

- [ ] **Step 2: 실패를 본다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 plugins/quality-gates/tests/test_other_teams.py` · `… test_intent_wide.py`
Expected: 새 테스트 FAIL.

- [ ] **Step 3: Interfaces 대로 구현한다**

`_tips` 의 갈래 규칙: 로컬 이름 집합을 먼저 모으고, 원격 ref(`refs/remotes/<원격>/<이름>`, `HEAD` 제외)의 `<이름>` 이 로컬에 있고 sha 가 다르면 `merge-base --is-ancestor` 두 번으로 가른다 — 원격이 로컬의 조상 → 원격을 버리고 묶음 +1 · 로컬이 원격의 조상 → 로컬을 버리고 묶음 +1 · 둘 다 아님 → 원격을 버리고 갈라짐에 로컬 이름 · git 이 답하지 못함 → 둘 다 둔다. 그다음 지금처럼 sha 로 접는다.

- [ ] **Step 4: 통과를 보고 변이로 잰다**

Run: `test_other_teams.py` · `test_intent_wide.py` · `test_intent_critic.py` · 배선 · `bash plugins/quality-gates/tests/test_publish_gh_two_files.sh`
Expected: 실패 0.
커밋한 뒤 변이 셋 — ① `_tips` 의 갈라짐 갈래를 「원격을 둔다」 로 ② `collect` 의 `PR_LIMIT` 비교를 `>` 로 ③ `_git` 의 `timeout=` 인자를 지운다 — 각각 `test_diverged_not_listed` · `TestOpenPrLimit` · `TestGitTimeout` 이 RED 인지 보고 되돌린다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/scripts/other_teams.py plugins/quality-gates/scripts/intent_origin.py plugins/quality-gates/scripts/intent_critic.py plugins/quality-gates/tests/test_other_teams.py plugins/quality-gates/tests/test_intent_wide.py
git commit -m "fix(qg): 다른 팀 읽기 — 같은 이름 원격 사본 · 토픽 형제 · git 시간 한도"   # 트레일러 둘
```

---

### Task 6: 문서 읽기 · 답 파일 · 거르기 — 시간 한도(원문 쪽) · 머리 값 · 읽다 난 예외 · 리뷰 트리 없음 · 같은 무게 순서

**덮는 AC:** AC16(원문 · 문서 머리 시간 한도 · 리뷰 트리 없음 · 머리 값 · 답 파일 · 차등 결과) · AC17(10c)

**Files:**
- Modify: `plugins/quality-gates/scripts/intent_origin.py` · `scripts/intent_answers.py` · `scripts/intent_critic.py`(`_breadth` · `cmd_filter`)
- Modify: `plugins/quality-gates/tests/test_intent_wide.py`

**Interfaces:**
- Consumes: Task 5 의 `GIT_TIMEOUT` · `REASON_TIMEOUT` · `TIMED_OUT` · `read_tracked`/`read_tree` 의 `(None, REASON_TIMEOUT)`.
- Produces:
  - `intent_origin._open_doc` — 사유가 `REASON_TIMEOUT` 이면 `"%s 를 읽지 못함 — %s" % (rel, REASON_TIMEOUT)` 를 남기고(라벨 「원문 링크 거부」 를 쓰지 않는다), `_follow_roadmaps` 는 `"로드맵 %s 를 읽지 못함 — %s"`.
  - `intent_origin.read_changed_doc(tree_root, rel, timed_out: Optional[list] = None)` — 시간 한도로 못 읽으면 `timed_out` 에 `rel` 을 더하고 None. `intent_critic._breadth` 가 목록을 넘겨, 읽지 못한 수에서 시간 한도 수를 뺀 것만 `NOTICE_UNREAD_DOCS`(추적되지 않는다)로, 시간 한도 수는 `"의도 문서인지 확인 못 한 문서 %d — " + REASON_TIMEOUT` 으로 공시한다.
  - `intent_origin._frontmatter` — 읽은 dict 의 맨 위 값 가운데 `_SCALARS` 인 것을 `str()` 로 바꾸다 예외가 나면 `(None, True)`(읽지 못한 머리). `frontmatter_value` 의 `str(value)` 도 예외를 잡아 None.
  - `intent_origin._differential_state` — `yaml.safe_load` 의 어떤 예외든 `(False, False, True)`.
  - `intent_answers.parse_answer_file` — `yaml.safe_load` 의 어떤 예외든 None. `answered_at` · `target` 의 `str()` 예외도 None. `read_answered` 는 `parse_answer_file` 을 `try/except Exception` 으로 감싸 읽지 못한 수에 더한다.
  - `intent_critic.cmd_filter` — 계획의 넓이가 `narrow` 가 아니고 `tree_root` 가 비었거나 폴더가 아니면 후보를 거르지 않고 `status: uncountable`, `ledger.uncountable("intent-critic 후보", NOTICE_NO_TREE)`, 공시 `NOTICE_NO_TREE = "리뷰 트리가 없어 읽은 인용을 확인하지 못함"`. 좁은 리뷰는 그대로다.

- [ ] **Step 1: 실패하는 테스트를 쓴다** (`test_intent_wide.py`)

- `class TestOriginTimeout`: `io_.subprocess.run` 을 `show` 에서만 `TimeoutExpired` 를 내는 대역으로 바꾸고 `build_origin`(설계문서 하나) → 공시에 `<설계문서 경로> 를 읽지 못함 — git 읽기가 시간 한도 30초를 넘김`, `추적 안 된` 을 담은 줄 없음, 예외 없음. 같은 대역으로 `prepare` 의 넓이 판정(바뀐 의도 문서 하나) → `의도 문서인지 확인 못 한 문서 1 — git 읽기가 시간 한도 30초를 넘김` 이 나고 `… — 추적되지 않는다` 는 나지 않는다. 대역이 받은 `timeout` 이 30(AC16).
- `test_unstringable_frontmatter_is_unreadable` — `str()` 에서 `ValueError` 를 내는 `int` 하위 클래스 값을 `io_._frontmatter` 가 쓰는 `yaml.safe_load` 의 결과로 주입(`mock.patch.object(io_.yaml, "safe_load", …)`): `frontmatter_unreadable` 참 · `frontmatter_value` None · `is_intent_doc` 거짓 · 예외 없음. `sys` 에 `set_int_max_str_digits` 가 있으면(파이썬 ≥3.11) 실제 큰 16진 정수 머리(`roadmap: 0x` + `f` × 5000)로도 같은지 본다(없으면 그 부분만 건너뛴다)(AC16 · 11b).
- `test_answer_file_odd_values_unreadable` — 답 자리에 `answered_at: 2026-02-30`(YAML 날짜 생성이 `ValueError`) 인 답 파일 하나와 정상 답 파일 하나: `prepare` 가 rc 0 · 공시 `읽지 못한 답 파일 1` · 정상 답은 읽힌다. `filter` 의 이미 답함 판정도 같은 답 자리로 돈다(AC16 · 11c).
- `test_differential_odd_yaml_unreadable` — `differential.yaml` 이 `a: 2026-02-30` 꼴: `has_evidence` 가 예외 없이 `차등 결과를 읽지 못함 — 근거로 세지 않았다` 를 낸다(AC16 · 11c).
- `test_wide_filter_without_tree_is_uncountable` — 넓은 계획의 `tree_root` 를 없는 폴더로: `filter` → 질문 기록 `status: uncountable` · 공시 `리뷰 트리가 없어 읽은 인용을 확인하지 못함` · `인용이 그 파일에 없어 거름` 없음 · `render` 결과 줄 `intent-critic — 리뷰어 출력을 읽지 못함(셀 수 없음)` · 꼴 `status: uncountable` · `reason_text` 가 그 공시(AC16 · 9). 좁은 계획은 지금처럼 거른다(짝).
- `test_same_weight_teams_and_read_keep_input_order` — 같은 무게 `방향` 의 후보 둘(다른 팀 줄만 · 읽은 인용만)을 두 차례(앞뒤를 바꿔): 남은 질문의 차례가 늘 입력 차례다 — 둘 사이에 앞서는 쪽이 없다(AC17 · 10c).

- [ ] **Step 2: 실패를 본다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 plugins/quality-gates/tests/test_intent_wide.py`
Expected: 새 테스트 FAIL(10c 는 지금 코드에서도 통과할 수 있다 — 그러면 그대로 둔다, 빠진 것은 테스트였다).

- [ ] **Step 3: Interfaces 대로 구현한다**

- [ ] **Step 4: 통과를 본다**

Run: `test_intent_wide.py` · `test_intent_critic.py` · `test_intent_return.py` · `test_other_teams.py` · `bash shared/tests/test_adjudication_wiring.sh`
Expected: 실패 0.

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/scripts/intent_origin.py plugins/quality-gates/scripts/intent_answers.py plugins/quality-gates/scripts/intent_critic.py plugins/quality-gates/tests/test_intent_wide.py
git commit -m "fix(qg): 문서 · 답 파일 읽기의 예외와 시간 한도 · 리뷰 트리 없는 거르기"   # 트레일러 둘
```

---

### Task 7: 상태 문서 · 절차 I2 · I7 · 문서 칸 락 · 배선 테스트

**덮는 AC:** AC9 · AC17(12a · 12c) · AC18 · AC10(배선)

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md` · `references/intent-critic.md`(I2 · 트리 지우기 · I7)
- Modify: `plugins/quality-gates/tests/test_intent_return.py` · `tests/test_intent_critic.py`(`TestProcedureDoc` 의 I7 락) · `tests/test_intent_critic_wiring.sh`

**Interfaces:**
- Consumes: Task 2 · 3 의 상수(`RETURN_KEYS` · `QUESTION_KEYS` · `RETURN_STATUSES` · `SKIP_REASONS` · `FAIL_REASONS` · `RETURN_OUTCOMES` · `QUESTION_STATES` · `NOT_ASKED_RANGE` · `NOT_ASKED_EARLY`).

- [ ] **Step 1: 상태 문서를 고친다** (`state-file-format.md`)

- 결과 줄 목록의 `intent-critic — 질문 <k>개 아직 묻지 않음(범위 모드)` 을 `intent-critic — 질문 <k>개 묻지 않음(범위 모드)` · `intent-critic — 질문 <k>개 묻지 않음(묻기 전에 끝남)` 으로. 표 설명의 상태 괄호를 다섯 값으로.
- 생명주기 3 「지운다」 를: 「세션 폴더는 같은 세션의 다음 qg 시작에 지워진다(`scripts/setup-qg.sh`). 그 세션이 qg 를 다시 부르지 않으면, 폴더가 정리 기한(기본 24시간)보다 오래된 뒤 어느 세션이든 qg 를 시작할 때 지워진다(`scripts/qg-gc.py`). `result.md` 가 세션 폴더의 표지다.」
- 파일 끝에 새 절 `## 돌려주는 꼴 — \`intent-return.md\` (2판)`: 쓰는 쪽(`gate` · `prepare` 의 건너뜀 · `render`) · 펜스 이름 `qg-intent-return` · 읽는 쪽은 `contract` 가 모르는 판이면 읽지 않고 알린다 · 그 칸이 없는 파일은 1판 · 글 칸은 한 줄로 접혀 따옴표에 싸인다 · 부르는 쪽은 이 파일에서 시작해 `session_dir` → `other_teams` 로 내려가고 내부 파일(`intent-questions.yaml`)을 읽지 않는다 · 가져갈 것은 이 파일과(다른 팀 기록이 필요하면) `session_dir` 아래 `other_teams` 값의 파일 둘이다. 그리고 락이 읽는 여섯 줄(글자 그대로의 머리, 뒤는 백틱 토큰만):
  ```
  - 머리 칸(차례대로): `contract` · `status` · … · `overlaps` · `questions`
  - 질문 칸(차례대로): `n` · `id` · … · `observation`
  - 칸 `status` 의 값: `ran` · `uncountable` · `skipped` · `failed`
  - 칸 `reason` 의 값(skipped): `kill-switch` · `halted` · `trivia` · `empty-diff` · `no-evidence`
  - 칸 `reason` 의 값(failed): `tree-failed`
  - 칸 `outcome` 의 값(ran): `questions` · `none` · `no-evidence` · `all-filtered`
  - 질문 칸 `state` 의 값: `답함` · `답 기록 실패` · `답하지 않음` · `묻지 않음` · `상한 넘어 남김`
  ```
  그 아래 칸마다 뜻 한 줄(설계 §1 표 · §2 표를 줄여).

- [ ] **Step 2: 절차를 고친다** (`references/intent-critic.md`)

- 12a: 트리 지우기 문단의 「I2 에서 `intent-call: none` 으로 온 실행과 표에 없는 종료 코드로 온 실행도 이 펜스를 지난다. 그래서 `render` 의 결과 줄이 마지막 스크립트 출력으로 남고, …」 를 「I2 에서 `intent-call: none` 으로 온 실행 · `prepare` 가 꺼짐 줄을 낸 실행 · 표에 없는 종료 코드로 온 실행도 이 펜스를 지난다. `render` 가 도는 실행은 그 결과 줄이 마지막 스크립트 출력으로 남고, 지우기에 실패하면 그 안내가 결과 줄보다 먼저 나온다. 꺼짐 줄로 온 실행은 `render` 를 돌지 않는다 — 이 펜스의 출력이 꺼짐 줄 뒤에 오고, I7 에서 꺼짐 줄을 다시 보인다.」 로. I2 표의 꺼짐 행 · [지킬 것](#지킬-것) 의 「마지막 스크립트 출력」 문장이 이 문단과 어긋나지 않게 맞춘다(꺼짐 행은 「돌려주는 꼴은 `prepare` 가 썼다」 를 둔다).
- I7: 첫 줄의 꼴 설명을 2판으로(질문마다 `n` · 정체 · 상태 다섯 · 고른 답 · 직접 쓴 답의 원문 · 실패 사유 · 질문 글 · 의심하는 대상 · 관찰, 머리의 `status` · `reason` · `outcome` · `result_line` · `none_reason` · 리뷰 커밋 · `session_dir` 등). 할 일은 꼴의 칸에서 정한다:
  - `wrong_choice: true` 인 질문(`답함` · `답 기록 실패` 모두) — 「같은 브랜치에서 이어 고친다」(그 질문을 함께). 기록에 실패했으면 「이 질문에 잘못 골랐다고 답했다 — 기록되지 않았다」 를 붙인다.
  - `commit:` 해시 · `failed — …` 두 줄은 지금 그대로.
  - `state: 답 기록 실패` 인 질문 — 「답 <n>개가 기록되지 않았다(<failure>) — 사유를 고친다. 다음 실행이 같은 질문을 내면 다시 답한다」(질문 · `answer` 를 함께. `answer` 가 `-` 면 「이 질문의 답을 읽지 못했다」).
  - `state: 답하지 않음` — 「답하지 않은 질문 <k>개가 남았다 … 다음 실행이 같은 질문을 내면 다시 묻는다」(지금 문장).
  - `state: 묻지 않음` — 범위 모드면 「질문 <k>개를 묻지 않았다 — 부르는 쪽이 사람에게 옮긴다」, PR 범위면 「질문 <k>개를 묻기 전에 끝났다 — 다시 돌려 묻는다」.
  - 「공시 줄에서 `답 기록 실패 질문 — …` 줄을 주워 적는다」 문장을 지운다(꼴이 싣는다).
  - 수명 · 가져갈 것 두 문장을 상태 문서의 글자 그대로 더한다: 「세션 폴더는 같은 세션의 다음 qg 시작에 지워진다. 그 세션이 qg 를 다시 부르지 않으면, 폴더가 정리 기한(기본 24시간)보다 오래된 뒤 어느 세션이든 qg 를 시작할 때 지워진다.」 · 「나중에 쓸 부르는 쪽은 qg 를 다시 부르기 전에 `intent-return.md` 와, 다른 팀 기록이 필요하면 `session_dir` 아래 `other_teams` 값의 파일을 가져간다.」

- [ ] **Step 3: 문서 락을 쓴다** (`tests/test_intent_return.py` · `class TestReturnDoc`)

- `_doc_tokens(text, head) -> Optional[List[str]]` — 상태 문서에서 `head` 로 시작하는 줄이 정확히 하나면 그 뒤를 `` ` `` 로 갈라 홀수 조각들, 아니면 None.
- `test_doc_lists_match_code` — 일곱 줄의 토큰이 차례로 `list(ic.RETURN_KEYS) + ["questions"]` · `ic.QUESTION_KEYS` · `ic.RETURN_STATUSES` · `ic.SKIP_REASONS` · `ic.FAIL_REASONS` · `ic.RETURN_OUTCOMES` · `ic.QUESTION_STATES` 와 같다.
- `test_written_keys_match_code` — 실제 `render` 가 쓴 꼴의 머리 키 차례 = `list(ic.RETURN_KEYS) + ["questions"]`, 질문 키 차례 = `ic.QUESTION_KEYS`(문서 · 상수 · 쓰인 파일 셋을 잇는다).
- `test_doc_lock_has_teeth` — 같은 비교 함수를 변이한 문서 글에 돌려 셋 모두 불일치를 본다: 토큰 하나 지우기 · 토큰 하나 값 바꾸기(`skipped` → `skip`) · 토큰 하나 더하기(`contract` 뒤 `extra`). 변이한 상수 튜플(하나 지움 · 하나 더함)로도 불일치를 본다. 바꾸지 않은 글은 일치(양성 대조).
- `test_lifetime_sentence_in_both_docs` — 수명 문장이 상태 문서와 절차 I7 에 글자 그대로 한 번씩, 가져갈 것 문장이 I7 에 한 번.
- `test_kill_row_and_tree_removal_agree` — 트리 지우기 문단이 `prepare` 가 꺼짐 줄을 낸 실행을 들고, I2 꺼짐 행이 범위 모드에서 그 펜스를 지난다고 한다(두 문장을 글자로)(AC17 · 12a).
- `test_i7_decides_from_fields` — I7 이 `wrong_choice: true` · `state: 답 기록 실패` · `state: 답하지 않음` · `state: 묻지 않음` 을 한 번씩 들고, 옛 `wrong_choice: yes` · 「`아직 묻지 않음` 으로 남고 고른 답은 실리지 않는다」 가 없다(AC9).

- [ ] **Step 4: 있는 I7 락을 맞춘다** (`test_intent_critic.py` · `TestProcedureDoc`)

`test_record_failure_is_a_todo` — 할 일 줄의 근거가 공시 줄이 아니라 `state: 답 기록 실패` 라는 것을 잠그게 고친다(`RECORD_FAILED` 글 그대로의 I5 표 행 단언은 남긴다 — `record` 출력은 그대로다). `test_result_section_only_on_rendered_runs` · `test_commit_todo_names_only_written_files` · `test_answer_commit_needs_a_push_todo` 는 I7 의 그 문장이 남으므로 그대로 통과해야 한다. 고친 락마다 지우기 변이 하나로 RED 를 본다.

- [ ] **Step 5: 배선 테스트를 고친다** (`test_intent_critic_wiring.sh`)

- 머리 주석(1–5행): 변이 수 · 실행 모드(`kill` · `kill-global` · `pr` · `range` · `wide` · `prwide`)를 지금대로 적고, 「gh 는 PATH 앞의 가짜이고 넓게 본 실행에서 불리지 않는다. kill 짝 실행은 스위치를 끈 채 그 실행만의 가짜 gh 를 부른다」 로 고친다(12c).
- kill 짝 실행 앞에 `[ -x "$KD/fakebin/gh" ]` 를 본다 — 없으면 `no "kill 짝 실행: 가짜 gh 가 없다 — 진짜 gh 를 부를 수 있어 돌리지 않는다"` 를 내고 짝 실행 셋을 건너뛴다(12c).
- `kill_run` 이 켤 변수 이름을 첫 인자로 받는다. `run_stage` · `check_stage` 에 모드 `kill-global`(같은 픽스처 · `DEVBREW_QUALITY_GATES_DISABLE=1`)을 더하고, `ic_run` 과 `kill_run` 이 다른 스위치 변수를 비운다. 두 kill 모드의 검사에 `grep -q -x 'reason: kill-switch' "$rd/intent-return.md"` 를 더한다. `expect_checks` 를 새 수로 맞추고 모드 목록 루프에 `kill-global` 을 넣는다(AC10).
- 셸 줄에서 한글 바로 앞 변수는 `${v}`.

- [ ] **Step 6: 통과를 보고 배선 변이로 잰다**

Run: `bash plugins/quality-gates/tests/test_intent_critic_wiring.sh` · 파이썬 넷 · `bash plugins/quality-gates/tests/test_publish_gh_two_files.sh`
Expected: 실패 0 — 판정 불변 검사(`same:*` · `no-verdict-args` · 변이 a–f)가 그대로 통과한다(AC18).
커밋한 뒤 사본 변이 하나 — `_killed` 가 `GLOBAL_KILL_ENV` 를 읽지 않게 — 로 `kill-global` 의 `prepare-kill-line` · `no-gh-call` 이 RED 인지 본다(`mkcopy` · `mutate` · `run_mutant … kill-global` 을 이 파일의 변이 절에 더해 상시 검사로 둔다).

- [ ] **Step 7: 커밋**

```bash
git add plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md plugins/quality-gates/tests/test_intent_return.py plugins/quality-gates/tests/test_intent_critic.py plugins/quality-gates/tests/test_intent_critic_wiring.sh
git commit -m "docs(qg): 돌려주는 꼴 2판 · 수명을 상태 문서와 절차에 — 칸 목록 락"   # 트레일러 둘
```

---

### Task 8: 판 · CHANGELOG · 전체 스위트

**덮는 AC:** AC19

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` · `plugins/quality-gates/CHANGELOG.md`

- [ ] **Step 1: 판 · CHANGELOG**

`plugin.json` 의 판을 다음 major 로(`14.10.0` → `15.0.0` — 번호는 머지 직전에 지휘자가 기본 브랜치에 맞춰 고친다). CHANGELOG 맨 위 `## [15.0.0] — <커밋 날짜>`:
- `### Changed` — 돌려주는 꼴 2판(`contract: 2`): `status` 닫힌 어휘(`ran` · `uncountable` · `skipped` · `failed` — 리뷰 트리를 만들지 못함은 `failed`) · 새 칸 `reason` · `reason_text` · `outcome` · `result_line` · `none_reason` · `reviewed_head` · `reviewed_base` · `session_dir` · 질문의 `n` · `answer_text` · `failure` · `question` · `target_source` · `target_id` · `label` · `quote` · `observation` · 질문 `state` 다섯(`아직 묻지 않음` 이 `답 기록 실패` · `답하지 않음` · `묻지 않음` 으로 갈림) · `wrong_choice` 가 `true` · `false` · 결과 줄 `묻지 않음(범위 모드)` · `묻지 않음(묻기 전에 끝남)` · 답 입력 머리 줄에 질문 번호(`=== n: <n> · id: <정체> · pick: <답>` — 번호 없는 머리는 받지 않는다) · 질문 창을 보인 실행은 답이 없어도 `record` 를 돈다 · 「답 기록 실패」 는 입력에 답이 있던 질문에만 · 다른 팀 바이트 공시가 리뷰어에게 보낸 줄 기준 · 세션 파일 수명 문장.
- `### Added` — 전역 스위치 `DEVBREW_QUALITY_GATES_DISABLE=1` 을 `gate` · `prepare` · `record` 가 읽는다(`record` 는 어느 스위치든 켜져 있으면 답 파일을 쓰지 않는다) · git 호출의 시간 한도(30초 — 열린 PR 조회와 같은 상수) · 공시 줄(「계획이 정한 것」 3 의 새 글 전부).
- `### Fixed` — 4a · 6a · 6e · 6b · 6c · 9 · 11b · 11c 를 행마다 한 줄.

- [ ] **Step 2: 레포 락과 전체 스위트**

Run: `bash shared/tests/test_changelog_integrity.sh` · `bash shared/tests/test_no_new_duplication.sh` · `bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh` · `bash shared/tests/test_adjudication_wiring.sh`
Expected: 실패 0.
그다음 전체 스위트를 Global Constraints 의 잠금 줄로 한 번 돈다. Expected: `FAILED` 줄이 없다(worktree 의 기존 실패는 기준 커밋과 견줘 보고한다).

- [ ] **Step 3: 커밋**

```bash
git add plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md
git commit -m "chore(qg): 돌려주는 꼴 2판 — major 판 · CHANGELOG"   # 트레일러 둘
```

---

### Task 9: 마지막 전체 리뷰 · AC 대조 · 미룸 · 묶음 검사

**덮는 AC:** AC1 – AC19 대조(마지막 리뷰)

- [ ] **Step 1: 전체 리뷰를 부른다**

브랜치 전체를 가장 능력 있는 모델이 본다. 리뷰어에게 보내는 글에 싣는 것:
- 설계문서 `## Acceptance Criteria` 의 AC1 – AC19 원문 그대로.
- AC 마다 한 줄씩 `AC<n>: <구현됨|미룸|빠짐> — <근거(파일:줄 · 테스트 이름)>` 꼴로 보고하게 한다.
- 끝에서 끝 흐름(gate → prepare → 리뷰어 → filter → 질문 창 → record(빈 입력 포함) → render → I7)에서 볼 것: rc 소비 · 질문 기록의 `record_ran` 이 없는 실행(묻기 전에 끊김 · record 의 질문 기록 쓰기 실패) · 꼴에 새로 싣는 글 칸이 모두 `_one_line` 을 거치는가 · `intent_critic.py` 반복문의 새 이른 빠짐에 회계 처분이 있는가 · 묶거나 뺀 것(같은 이름 원격 사본 · 토픽 형제 · 같은 번호 머리 · 맞지 않는 머리)이 모두 세어지는가 · 절차 문서와 스크립트의 머리 줄이 같은 판인가 · 테스트가 네트워크에 닿는가.
- 계획이 쓴 테스트 코드(plan-mandated)도 같은 엄격함으로 보라고 적는다 — 특히 Task 4 · 7 이 고쳐 쓴 기존 락(`TestRecordUnreadAnswers` · `TestProcedureDoc`)이 약해지지 않았는가.

- [ ] **Step 2: 보고를 git 이 추적하지 않는 파일에 적는다**

경로: `/Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-qg-epic-roadmap-intent-review-brief/files/r5-ac-report.md`(셸로 쓴다).

- [ ] **Step 3: 미룸을 올린다**

「미룸」 · 「빠짐」 판정과 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 행으로 더해 커밋한다(`docs(qg): R5 미룸 갱신`). `### Deferred to plan` 표와 `## 결정 기록` 은 리뷰 엔진이 쓰는 절이라 고치지 않는다.

- [ ] **Step 4: PR 을 만들기 전에 묶음 검사를 돌려 경고를 사용자에게 보인다**

Run: `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.13.1/scripts/check_bundle_coverage.py --impl /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-return-contract/docs/superpowers/specs/2026-11-15-qg-return-contract-design.md /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-qg-epic-roadmap-intent-review-brief/files/r5-ac-report.md`
Expected: 출력 전부를 사용자에게 보인다(경고가 있으면 그대로).

---

## AC 대조

| AC | 과제 · 테스트 |
|---|---|
| AC1 칸 전부 · 관찰 전부 · 번호 · 한 줄 정리 | Task 3 `test_question_fields_carried` · `test_numbers_unique_per_run` · `test_text_fields_are_folded_and_parse` · Task 4 `test_second_of_same_identity` |
| AC2 상태 다섯 · 여섯 갈래 · 빈 창 · 결과 줄 | Task 3 `test_six_paths_give_five_states` · `test_result_line_counts_match_states` · `test_not_asked_lines` · Task 4 `test_empty_input_marks_unanswered` · I5 문장 |
| AC3 실패한 답 · `wrong_choice` · `answer_text` | Task 4 `test_failed_answer_carried` · `test_typed_answer_text_on_success` · `test_wrong_header_after_typed_answer` |
| AC4 `true` · `false` | Task 3 `test_wrong_choice_is_bool_text` |
| AC5 `status` · `reason` 여섯 | Task 2 `test_skip_and_fail_codes` · `test_outcomes`(no-evidence) |
| AC6 `outcome` · `result_line` · `none_reason` | Task 2 `test_outcomes` · `test_none_reason_two_calls_joined` |
| AC7 리뷰 커밋 · `session_dir` | Task 2 `test_reviewed_commits_survive_answer_commit` · `test_contract_and_session_dir` |
| AC8 표 상태 = `state` | Task 3 `test_six_paths_give_five_states` |
| AC9 상태 문서 · 락 · I7 | Task 7 `TestReturnDoc` |
| AC10 스위치 | Task 2 `test_prepare_global_switch_reads_nothing` · `test_both_switches_named` · Task 4 `test_record_*_switch_writes_nothing` · Task 7 배선 `kill-global` |
| AC11 4a | Task 4 `test_wrong_header_after_typed_answer` · `test_unknown_number_only_disclosed` |
| AC12 4b | Task 4 `test_unreadable_config_fails_only_answered` · `test_stray_text_does_not_fail_others` |
| AC13 같은 이름 원격 사본 세 갈래 · 두 범위 | Task 5 `TestSameNameRemote` |
| AC14 토픽 형제 | Task 5 `TestTopicSiblings` · `test_topic_scope_members_excluded` |
| AC15 다른 팀 바이트 | Task 5 `test_teams_bytes_match_evidence` |
| AC16 §6 여섯 | Task 5 `TestGitTimeout` · `TestOpenPrLimit` · `TestBodyCharacters` · Task 6 `TestOriginTimeout` · `test_wide_filter_without_tree_is_uncountable` · `test_unstringable_frontmatter_is_unreadable` · `test_answer_file_odd_values_unreadable` · `test_differential_odd_yaml_unreadable` |
| AC17 테스트 틈 · 배선 · 꺼짐 행 | Task 5 `test_bases_differ_not_ancestor_takes_default` · Task 6 `test_same_weight_teams_and_read_keep_input_order` · Task 7 배선 머리 주석 · 가짜 gh 확인 · `test_kill_row_and_tree_removal_agree` |
| AC18 판정 불변 | Task 7 배선 판정 불변 검사 · 변이 a–f |
| AC19 major 판 · CHANGELOG · 전체 스위트 | Task 8 |
