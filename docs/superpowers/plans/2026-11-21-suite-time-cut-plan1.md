# 스위트 시간 줄이기 — 계획 1(시간 기록 · 느린 테스트 · 앞뒤 바퀴) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 전체 스위트가 대상마다 걸린 시간과 다른 스위트와의 겹침을 기록 파일에 남기게 하고(값을 주지 않으면 지금과 글자까지 같다), 느린 테스트 넷(스위트 안의 스위트 · 임포트 색인 · 변이 매트릭스의 깨끗한 사본 실행 · 바이트코드 캐시)에서 되풀이를 덜며, 고치기 전후 두 바퀴를 재어 지휘자가 대조 구조를 고칠지 판단할 숫자를 낸다.

**Architecture:** 다른 스위트 수를 세는 일은 새 모듈 `tools/suite/suite_peers.py` 하나가 맡는다 — 프로세스 표를 읽어 「다른 러너」 를 세는 순수 함수와, 러너 · 사람이 부르는 명령줄(`--stamp` · `--list` · `--wait`). `run-all.sh` 는 `SUITE_TIMING_FILE` 이 절대 경로일 때만 대상이 끝날 때마다 그 명령을 불러 줄을 덧붙이고, `run_unittest_dir.py` 는 결과 객체를 넓혀 모듈마다 시간을 합쳐 `pymod` 줄을 낸다. 두 러너는 그 변수를 테스트에게 물려주지 않는다. 느린 테스트는 각자 파일 안에서만 고친다 — 지키던 판정과 단언 수는 그대로다.

**Tech Stack:** bash(macOS 3.2 — 연관 배열 없음) · Python 3.9.6(레포의 `python3`) · unittest · git · `ps`(macOS) · 기존 셸 테스트 도구(`shared/tests/assert.sh`).

**Spec:** `docs/superpowers/specs/2026-11-21-suite-time-cut-design.md` — 이 계획은 그 문서가 「계획 1」 이라 부르는 몫이다. 계획 2(대조 구조 · §4)와 계획 3(느린 넷 · §6)은 이 계획에 없다.

## AC 가르기

설계문서 `## Acceptance Criteria` 머리 문장과 `## Metadata` 의 계획 나누기로 갈랐다.

| AC | 몫 | 과제 |
|---|---|---|
| AC1 · AC2 · AC3 · AC4 · AC5 · AC27 | 계획 1 — 시간 기록 | 과제 2(AC3 의 세는 규칙) · 과제 3(AC5 · AC27 의 python 쪽) · 과제 4(AC1 · AC2 · AC3 · AC4 · AC27) |
| AC6 · AC7 | 계획 1 — 스위트 안의 스위트 | 과제 6 |
| AC8 | 계획 1 — 임포트 색인 | 과제 7 |
| AC9 | 계획 1 — 변이 매트릭스 | 과제 8 |
| AC10 | 계획 1 — 바이트코드 캐시(재 보고 넣기) | 과제 9 |
| AC11 · AC12 · AC13 · AC29 | 계획 1 — 앞뒤 바퀴와 보고 | 과제 5(「앞」 바퀴 — AC12 · AC13 의 앞쪽) · 과제 10(「뒤」 바퀴 — AC11 · AC12 · AC13 · AC29) |
| AC22 | 계획 1 — PR 본문 알림 | 과제 11 |
| AC14–AC20 · AC24 · AC28 · AC30 | 계획 2 | 이 계획에 없다 |
| AC26 | 계획 3 | 이 계획에 없다 |
| AC21 · AC23 · AC25 | 지휘자 기록 | 이 계획에 없다 — 과제 10 · 11 이 지휘자가 쓸 숫자를 넘긴다 |

대조 스크립트에 주는 목록: `AC1~AC13 · AC22 · AC27 · AC29`.

## Global Constraints

- **값이 없으면 지금과 같다.** `SUITE_TIMING_FILE` 이 없거나 빈 값이면 `run-all.sh` 와 `run_unittest_dir.py` 의 표준 출력 · 표준 오류 · 종료 코드가 고치기 전과 글자까지 같다. 값이 있어도 표준 출력과 종료 코드는 같다(설계 Anti-goals).
- **`run-all.sh` 의 찾기 줄은 바꾸지 않는다.** 27행 `done < <(find shared/tests plugins/*/tests -name 'test_*.sh' -not -path '*/spike/*' -not -path '*/fixtures/*' | LC_ALL=C sort)` 는 `shared/tests/test_shell_tests_executable.sh` 가 정규식 `s/.*< <\((find [^|]*[^| ]) *\|.*/\1/p` 로 꺼내 쓴다 — 그 줄의 글자를 그대로 둔다.
- **표준 오류 알림은 실패 줄 꼴로 시작하지 않는다.** 대조(`merge_check.py`)는 표준 출력과 표준 오류를 합쳐 `.devbrew.md` 의 `test_failure_pattern: "^FAILED (.+)$"` 로 읽고, `run-all.sh` 는 python 러너의 출력에서 `^(FAIL|ERROR): ` 를 읽는다. 알림은 `run-all: ` · `run_unittest_dir: ` 로 시작한다.
- **기록 줄의 꼴(탭으로 가른다 · 글자 그대로).** 시작 `start<TAB><epoch><TAB><다른 스위트 수><TAB><작업 트리 꼭대기 경로>` · 대상 `<걸린 초><TAB><sh|py|node><TAB><대상 경로><TAB><다른 스위트 수>` · 모듈 `<걸린 초><TAB>pymod<TAB><폴더>/<모듈 파일>` · 끝 `end<TAB><epoch><TAB><다른 스위트 수>`. 초와 epoch 는 소수 셋째 자리(`%.3f`). 셀 수 없으면 수 칸은 `?` 다 — 0 으로 적지 않는다(설계 Anti-goals 「재지 못한 것을 0 이나 통과로 적는다」).
- **기록 변수는 절대 경로만.** 상대 경로면 표준 오류에 한 줄 알리고 기록 파일을 만들지 않는다(설계 「기록 변수는 절대 경로로 준다」).
- **bash 3.2.** 연관 배열 · `${var,,}` · `EPOCHREALTIME` 없음. `$var` 바로 뒤에 한글 · 괄호 「」 같은 비ASCII 글자가 오면 `${var}` 로 감싼다(3.2 가 그 바이트를 먹는다). `$( )` 안에 here-doc 을 두지 않는다. 새 셸 코드는 `/bin/bash`(3.2)로 돌려 본다.
- **Python 3.9 문법만.** `match` · `X | Y` 타입 표기 금지. 파일 읽기 · 쓰기에 `encoding="utf-8"` 를 적는다.
- **테스트를 고치는 일은 리뷰어 프로필을 고치는 일만큼 조심한다(CLAUDE.md).** 고친 테스트마다 고치기 전에 잡던 것을 고친 뒤에도 잡는지 사본에 변이를 넣어 한 번 보인다. 변이는 커밋한 뒤 `git clone --no-local <이 worktree> <임시 폴더>` 사본에서만 넣는다 — 이 worktree 의 파일에 변이를 넣지 않는다. 같은 길이 변이는 `PYTHONDONTWRITEBYTECODE=1` 로 돌린다.
- **고치지 않는 파일.** `plugins/spec-distill/tests/test_finish_pr_merge.sh` · `test_control_plane.sh`(AC11)와 지휘 로드맵의 느린 넷(`test_human_gate.sh` · `test_human_gate_e2e.sh` · `test_team_status.sh` · `test_roadmap_status.sh`)은 한 글자도 바꾸지 않는다. 플러그인의 `scripts/` · `plugin.json` · `CHANGELOG.md` 도 바꾸지 않는다 — 판을 올리지 않는다(설계 Constraints).
- **전체 스위트는 공유 잠금 아래에서만, 과제 5 · 과제 10 에서만.** 명령은
  `python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.25.0"/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-20-test-method-rework-brief/files/suite-lock --owner <담당자 이름> --wait 7200 -- bash -c 'bash tools/suite/run-all.sh'`
  이고 기록 변수는 그 앞에 `env SUITE_TIMING_FILE=<절대 경로>` 로 준다(잠금 스크립트는 환경을 물려 돌린다). 백그라운드로 띄우지 않는다. 잠금을 못 잡으면 같은 스크립트의 `show --lock <같은 경로>` 출력(주인 · 잡은 시각)을 보고하고 멈춘다. 그 밖의 과제는 자기가 고친 파일을 덮는 테스트만 돌린다.
- **경로 예약.** 과제 6 이 고치는 `plugins/quality-gates/tests/codex-blessed-red.txt` · `test_runtime_contract_invariance.sh` 는 로드맵 E1 블록의 경로 예약에 아직 없다 — 지휘자가 계획 검토 전에 예약을 맞춘다(설계 Files to Modify). 맞춰지지 않았으면 과제 6 을 시작하지 않고 보고한다.
- **기록 · 임시 파일 자리.** 담당자의 임시 파일과 기록 파일은 지휘자가 준 TMPDIR(절대 경로, git 밖) 아래에 둔다. 그 폴더에 쓰지 못하면 이 worktree 의 `.claude/tmp/<담당자 이름>/` 을 쓰고 `git check-ignore -q` 로 무시되는지 먼저 확인한다.
- **커밋.** Conventional Commits, 설명은 한국어(`<type>(<scope>): <설명>`). 커밋은 pathspec 으로 그 과제의 파일만. push 하지 않는다.

## Review Focus

설계가 뜻하지만 어느 수용 기준도 이름 대지 않는 입력이다. 줄마다 그 코드를 가진 과제에 테스트가 있다.

1. **바퀴가 중간에 죽는다(시간 초과 · 끊김).** 그때까지 끝난 대상의 줄과 시작 줄은 남고 끝 줄은 없다 — 끝 줄이 없는 바퀴는 판단에 쓰지 않는다는 §2 의 전제다(과제 4 `test_killed_round_keeps_lines_without_end`).
2. **한 파일에 바퀴 둘(대조의 기준 사본 · 합친 사본).** 시작 줄 둘의 꼭대기 경로가 달라 가를 수 있다(과제 4 `test_two_rounds_in_one_file_are_told_apart`).
3. **프로세스 표를 읽지 못한다.** 수 칸이 `?` 이고 0 이 아니다(과제 2 `test_cli_unknown_rows_print_question_mark` · 과제 4 `test_unknown_peer_count_written_as_question_mark`).
4. **작업 트리 경로에 빈칸이 있다(`~/My Folder/...`).** 그 러너도 러너로 센다(과제 2 `test_is_runner_cases` 의 빈칸 경로 줄).
5. **python 테스트 모듈이 임포트에서 죽는다.** `pymod` 줄이 그 모듈 파일 이름으로 남는다(과제 3 `test_import_failure_module_keyed_by_file`).

---

## 계획의 판단

설계가 정하지 않아 이 계획이 정한 것이다 — 「설계에 없던 결정」. 범위 · 인터페이스 · 파일 배치 · 사람에게 보이는 글과 동작에 닿는 것을 모두 적었다. ✎ 는 설계문서의 글자와 어긋나 지휘자에게 보고하는 자리다(이 계획은 설계문서를 고치지 않는다).

| # | 자리 | 정한 것 | 이유 | 다른 길 |
|---|---|---|---|---|
| K1 | 세는 길(§2 「러너에 세기만 하는 길을 두거나 … 계획이 정한다」) | 새 파일 `tools/suite/suite_peers.py` — 러너도 사람(구현 담당자 · 지휘자)도 이것으로 센다. 설계 Files to Modify 에 없던 새 파일이다 | 세는 규칙이 한 곳에 있어야 러너의 기록과 대조 앞의 기다림이 같은 수를 본다. 순수 함수로 두면 가짜 프로세스 표로 시험할 수 있다 | `run-all.sh` 안에 `ps | awk` 한 줄 |
| K2 | 러너 판별 | 명령줄을 빈칸으로 가른 첫 토큰의 이름이 `bash · sh · zsh · dash · ksh`(앞의 `-` 는 뗀다)이고, 이어지는 `-` 로 시작하는 토큰에 `-c` 가 없으며, 그 뒤 나머지 전체(빈칸 포함)의 마지막 경로 성분이 `run-all.sh` 인 프로세스 | 설계 §1 「셸이 `run-all.sh` 를 직접 실행하는 프로세스」. 잠금 스크립트 · `bash -c '…'` 은 감싼 것이라 빠진다. 러너는 인자를 받지 않으므로 나머지 전체를 경로로 읽어 빈칸 경로도 센다 | 둘째 토큰만 본다 |
| K3 | 같은 바퀴를 하나로 | 이 실행 자신 · 조상 · 자손을 빼고, 남은 러너 가운데 **조상에 러너가 하나도 없는 것만** 센다 | 러너는 `{ … } | sort` 와 `$( )` 로 같은 명령줄의 하위 셸을 낳는다 — 다른 러너 하나가 둘로 세지지 않고(Deferred 0f77adb0#r3.1), 스위트 안 테스트가 돌린 안쪽 러너도 바깥 바퀴와 하나로 센다 | 명령줄이 같은 부모-자식만 합친다 |
| K4 | 프로세스 표 · 갈아 끼우는 자리 | `ps -axww -o pid=,ppid=,command=`. 환경 변수 `SUITE_PEERS_PS_FILE` 이 있으면 `ps` 대신 그 파일(같은 꼴)을 읽는다 — 테스트만 쓴다 | 「다른 러너가 없으면 0」 을 실제 표로 재면 다른 작업 폴더의 스위트에 흔들린다(Deferred 0b618227#r1.1 · 02cbe68b#r2.1) | 테스트가 실제 표만 쓴다 |
| K5 | 셀 수 없을 때 | 수 칸에 `?`. 명령줄은 기본 · `--list` 에서 종료 코드 3 | 설계 Anti-goals | 0 으로 적는다 |
| K6 | 걸린 초를 재는 법 | `run-all.sh` 는 대상이 끝날 때마다 `suite_peers.py --pid $$ --stamp`(출력 `<epoch> <수>` — 빈칸 하나)를 부르고, 걸린 초 = 이 stamp − 앞 stamp(첫 대상은 시작 줄의 stamp). `pymod` 는 직전 테스트가 끝난 때부터 이 테스트가 끝날 때까지를 그 모듈에 더한다(다음 클래스의 `setUpClass` 가 그 모듈에 든다) | bash 3.2 에는 소수 시각이 없다 — 대상마다 python 한 번으로 시각과 수를 함께 얻는다. 기록 변수가 있을 때만 부르므로 바퀴마다 약 320회 · 십수 초가 기록 바퀴에만 더해진다 | 대상 앞뒤로 두 번 부른다 |
| K7 | 기다리는 길(§2 「0 이 될 때까지 기다린다. 상한은 30분」) | `suite_peers.py --wait <초> [--interval <초>]` — 수가 0 이 되면 `waited=<정수 초><TAB>peers=0` 과 종료 코드 0, 상한이 지나면 `waited=<초><TAB>peers=<수|?>` 와 1. 간격 기본 15초. `?` 는 0 이 아니라 기다림을 잇는다 | 구현 담당자의 「뒤」 바퀴(과제 10)와 지휘자의 대조 앞 기다림이 같은 명령을 쓴다. 지휘 절차서는 이 계획이 고치지 않는다 | 담당자가 셸 반복문을 손으로 쓴다 |
| K8 | `pymod` 줄을 쓰는 때 · 키 | python 폴더 하나의 실행이 끝날 때 한꺼번에, 경로 차례로. 키는 모듈 파일의 현재 폴더 기준 상대 경로. 임포트에서 죽은 모듈(`unittest.loader._FailedTest`)은 `<폴더>/<이름>.py` | 대상 줄(`py`)이 그 폴더의 단위다 — 모듈 줄은 그 안의 나눔이다 | 모듈이 바뀔 때마다 쓴다 |
| K9 | 변수를 물려주지 않는 범위 | 계획 1 은 `SUITE_TIMING_FILE` 만 뺀다. `run-all.sh` 는 읽은 뒤 `unset` 하고 python 러너에게는 `SUITE_TIMING_FILE="$TIMING"` 으로 명시해 건넨다. `run_unittest_dir.py` 는 테스트를 찾기 전에 `os.environ` 에서 뺀다. `SUITE_ONLY_FAILED_FILE` 은 계획 2 가 읽고 뺀다 | 계획 2 의 변수는 계획 2 가 읽는 자리와 함께 들어와야 한다 | 지금 둘 다 뺀다 |
| K10 | 쓰기 확인 | `run-all.sh` 는 시작에서 `: >> "$TIMING"` 로 한 번 확인하고 실패면 알림 한 줄 뒤 기록을 끈다. 도중에 덧붙이기가 실패하면 그 줄만 잃고 알림을 한 번 낸다 | AC4 · 설계 §1 「바퀴는 끝까지 돈다」 | 줄마다 알린다 |
| K11 | 새 테스트 파일 | `tools/suite/test_suite_timing.py` 하나(세는 규칙 · python 러너 · 셸 러너). 스위트는 `tools/*/test_*.py` 로 이것을 돈다 | 설계 Files to Modify 「`tools/suite/` 의 새 테스트 하나」 | 파일을 셋으로 |
| K12 | 실제 프로세스 표 시험 | 수의 합계가 아니라 **목록 소속**만 본다 — 띄운 가짜 러너의 PID 가 `--list` 에 있고 그 하위 셸 PID 는 없다. 자기 자신 · 조상 · 자식은 가짜 러너 안에서 `--list` 를 불러 본다. 「다른 자리」 로 보일 가짜 러너는 두 번 갈라 띄워(부모가 곧 끝난다) 테스트 프로세스의 자손이 아니게 하고 5초 안에 끝낸다 | 다른 작업 폴더의 스위트가 돌아도 흔들리지 않는다(Deferred 02cbe68b#r2.1). 그 5초 동안 다른 작업 폴더의 기록에 1 로 스칠 수 있다 — §2 의 5% 허용이 받는 몫이다 | 「띄우기 전보다 1 이상 는다」 |
| K13 | 스위트 안의 스위트 — 원장 읽기 | 원장의 주석 · 빈 줄이 아닌 줄을 `<파일 이름> <지문>` 으로 읽는다. 원장 파일이 없으면 FAIL. 등재된 파일이 테스트 폴더에 없으면 FAIL(「대상이 없어진 등재」). 이 파일 자신을 등재하면 돌리지 않고 FAIL. 등재 0건이면 PASS 한 줄 `등재 0건 — 다시 돌린 테스트 0개`. 단언 수는 넷에서 셋으로 준다(제외 목록 알람이 걷힌다) | 다시 돌리는 범위가 원장으로 바뀌면 원장 자체를 못 읽는 경우가 새로 생긴다 — 조용히 0 으로 지나가지 않게 막는다 | 원장이 없으면 0건으로 친다 |
| K14 | 임포트 색인 | 임시 파일 `IMPINDEX` 에 `git ls-files -- '*.py'` 전부를 한 번 파싱한 `<경로><TAB><최상위 이름들(빈칸)>` 을 둔다. `impscan <모듈>` 은 이름과 계약(표준 입력의 후보 · 표준 출력의 소비자 · 차례)을 그대로 두고 색인을 찾는다. 색인에 없는 후보는 지금처럼 그 자리에서 파싱한다. 술어는 함수 하나(`imported_names`)로 두어 색인과 그 자리 파싱이 같은 뜻을 쓴다 | 부르는 두 자리(`CONSUMED_PY` · 축 1c 의 `consumers=`)와 코퍼스 도출을 건드리지 않는다(설계 §3) | 부르는 자리마다 색인을 직접 읽는다 |
| K15 | 깨끗한 사본 결과 캐시 | `$BASE_MUT/.clean-results/<케이스 함수 이름>` 파일에 `run_case` 의 한 줄을 둔다. 맨 앞 양성 대조 반복문도 같은 캐시를 쓴다. 계측기 탐침(`_case_subshell_refusal_probe`)은 캐시하지 않는다 | 케이스 이름은 함수 이름이라 파일 이름으로 안전하다. 빈 출력도 그대로 캐시해 「계측기 고장」 판정이 같다 | 양성 대조는 따로 돈다 |
| K16 | 바이트코드 캐시 넣기 | 세 테스트에서 케이스 모음을 불러온 바로 뒤에 `unset PYTHONDONTWRITEBYTECODE` · `PYTHONPYCACHEPREFIX="$(mktemp -d -t docreview-pyc-XXXXXX)"` · `export` · `trap 'rm -rf "$PYTHONPYCACHEPREFIX"' EXIT`. 재기는 같은 세션에서 앞(지금 커밋) · 뒤(고친 작업 트리) 한 번씩 차례로, 각 실행 직전의 다른 스위트 수를 함께 적는다 | 설계 §3 · AC10. 공유 도우미 파일을 새로 두면 케이스 모음 코퍼스(`docreview_fixture_corpus.sh`)가 바뀐다 | `fixtures/docreview/` 에 도우미 |
| K17 | 변이를 넣는 자리 | AC6 은 `plugins/quality-gates` 폴더 사본, AC8 · AC9 는 `git clone --no-local` 사본 — 영구 테스트로 남기지 않는다 | 설계 Verification Plan 「사본에 변이를 넣어 보인다」. 설계 Files to Modify 에 새 테스트가 없다 | 변이 검사를 영구 테스트로 |
| K18 | 「앞」 바퀴의 기다림 | 「앞」 은 기다리지 않는다 — 수는 줄에 남는다. 「뒤」 만 `--wait 1800` 뒤에 돈다 | §2 는 판단에 쓰는 바퀴(「뒤」 · 대조)만 기다리게 한다 | 둘 다 기다린다 |
| K19 | AC13 의 다시 돌리기 | 갈린 대상만 잠금 아래 한 번 — 셸 파일은 `bash <파일>`, python 폴더는 `python3 tools/suite/run_unittest_dir.py <폴더>`, node 는 `node --test --test-reporter=tap <파일>` | 러너가 그 대상을 도는 명령과 같다 | 전체를 다시 돈다 |
| K20 ✎ | AC9 「깨끗한 사본에서 빨간 케이스를 겨냥한 변이는 지금처럼 「측정 불가」 로 나온다」 | 「지금처럼」 을 따른다 — 지금 그 변이는 `instrument_broken`(출력 「계측기 고장 — 양성 대조 실패(clean=N)」)로 나온다. 고친 뒤에도 같은 출력이어야 한다(과제 8 Step 6) | 설계 §3 은 「판정은 그대로다」 다. AC9 의 「측정 불가」 는 코드의 다른 판정(`unmeasurable` — 변이 실행의 traceback) 이름이다 | AC9 글자대로 「측정 불가」 로 바꾼다 |
| K21 | PR 본문 | 과제 11 이 초안 파일을 쓴다 — 판을 올리지 않는 이유 · 「지휘 로드맵의 느린 넷은 건드리지 않았다」 · `## 지휘 로드맵에 알림`. `## 기준선` 절은 쓰지 않는다(지휘자 몫 — AC21) | 설계 §2 · §5 | — |

---

## 파일 표

| 파일 | 맡는 일 | 과제 |
|---|---|---|
| `tools/suite/suite_peers.py`(새) | 다른 스위트 러너 수 — 순수 함수 · 명령줄(`--pid` · `--list` · `--stamp` · `--wait` · `--interval`) | 2 |
| `tools/suite/test_suite_timing.py`(새) | 세는 규칙 · python 러너 · 셸 러너의 시간 기록 테스트 | 2 · 3 · 4 |
| `tools/suite/run_unittest_dir.py` | 모듈별 시간(`pymod`) · 변수 빼기 | 3 |
| `tools/suite/run-all.sh` | 시작 · 대상 · 끝 줄 · 변수 빼기 · 알림 | 4 |
| `plugins/quality-gates/tests/test_codex_backward_compat.sh` | 셋째 확인을 원장 등재분으로 | 6 |
| `plugins/quality-gates/tests/codex-blessed-red.txt` | 머리말만 | 6 |
| `plugins/quality-gates/tests/test_runtime_contract_invariance.sh` | 110행 근처 주석 한 자리만 | 6 |
| `shared/tests/test_copy_of_contract.sh` | 임포트 색인 | 7 |
| `shared/tests/test_docreview_mutations.sh` | 깨끗한 사본 결과 캐시 | 8 |
| `shared/tests/test_docreview_state.sh` · `test_docreview_route.sh` · `test_docreview_advice.sh` | 바이트코드 캐시(재 보고 줄 때만) | 9 |

---

### Task 1: 다시 확인

설계문서가 근거로 든 자리가 지금 코드에서도 그런지 본다. 기대와 다르면 **멈추고** 지휘자에게 보고한다(어느 줄 · 무엇이 달랐나 · 어느 과제가 닿나). 고치지 않는다. 계획을 쓸 때(2026-11-21, 브랜치 끝 4563d6c4) 아래 기대는 「이미 달라진 것」 두 줄 밖에 모두 맞았다. AC11 의 기준 해시도 여기서 적는다.

**Files:** 없음(읽기만)

- [ ] **Step 1: 근거 자리를 읽는다**

레포 뿌리에서 돈다(복합 명령은 스크립트 파일로 써서 `bash <파일>` 로).

```bash
grep -n 'for d in plugins/\*/tests shared/tests\|for d in tools/\*/\|git ls-files .plugins/\*/tests/\*.test.mjs.' tools/suite/run-all.sh  # 셋 — 차례로 돌고 고르는 인자가 없다(RC1)
grep -n "done < <(find shared/tests plugins/\*/tests -name 'test_\*.sh'" tools/suite/run-all.sh   # 27행 — 찾기 줄
grep -n 'find_cmd=' shared/tests/test_shell_tests_executable.sh    # 11행 — 그 줄을 정규식으로 꺼낸다
grep -n 'TextTestRunner' tools/suite/run_unittest_dir.py            # 폴더마다 프로세스 하나 · 시간 보고 없음
grep -n 'env=dict(os.environ, TMPDIR' plugins/spec-distill/scripts/merge_check.py   # 201행 근처 — 테스트 명령이 환경을 물려 돈다
grep -n 'p.stdout + "\\n" + p.stderr' plugins/spec-distill/scripts/merge_check.py    # 표준 출력과 오류를 합쳐 읽는다
grep -n 'test_failure_pattern' .devbrew.md                          # "^FAILED (.+)$"
find plugins/quality-gates/tests -maxdepth 1 \( -name 'test_*.sh' -o -name 'test_*.py' \) | wc -l   # 130 — 제외 여섯을 빼면 124
grep -vcE '^[[:space:]]*(#|$)' plugins/quality-gates/tests/codex-blessed-red.txt   # 0 — 등재 0건
grep -n '^EXCLUDED_TESTS_PIN=6\|^CODEX_TOUCHING_TESTS=' plugins/quality-gates/tests/test_codex_backward_compat.sh   # 97 · 115행
grep -n '미등재.로 RED' plugins/quality-gates/tests/codex-blessed-red.txt          # 13행
grep -n '의식적 갱신 강제' plugins/quality-gates/tests/test_runtime_contract_invariance.sh   # 110행
grep -n '^impscan()\|impscan "\$cm"\|impscan "\$mod"' shared/tests/test_copy_of_contract.sh   # 정의 하나 · 부르는 자리 둘(841 · 1034행 근처)
git ls-files -- 'shared/*.py' | wc -l                               # 61
grep -cE '^(mut|mut_expect) ' shared/tests/test_docreview_mutations.sh   # 119
grep -n '_split3 "$(run_case "$CLEAN" "$case")"' shared/tests/test_docreview_mutations.sh   # 187행 — 셀마다 깨끗한 사본 실행
grep -n '^export PYTHONDONTWRITEBYTECODE=1' shared/tests/test_docreview_mutations.sh shared/tests/fixtures/docreview/cases.sh   # 둘
grep -c 'trap' shared/tests/test_docreview_state.sh shared/tests/test_docreview_route.sh shared/tests/test_docreview_advice.sh   # 0 · 0 · 0
ls -d tools/*/                                                      # plain-language · suite — 테스트가 있는 tools 폴더는 지금 plain-language 하나
```

이미 달라진 것으로 본 자리(계획을 쓸 때 — 멈출 일은 아니다, 보고에만 적는다):

- 추적 python 파일 수 `git ls-files -- '*.py' | wc -l` 이 **324** 다(설계 Context 는 310). 임포트 색인이 덜 수 있는 몫이 조금 크다는 뜻일 뿐 AC 에 닿지 않는다.
- AC9 의 「측정 불가」 는 코드의 이름과 다르다 — K20.

- [ ] **Step 2: AC11 과 느린 넷의 기준 해시를 적는다**

```bash
git rev-parse HEAD
git hash-object plugins/spec-distill/tests/test_finish_pr_merge.sh plugins/spec-distill/tests/test_control_plane.sh plugins/spec-distill/tests/test_human_gate.sh plugins/spec-distill/tests/test_human_gate_e2e.sh plugins/spec-distill/tests/test_team_status.sh plugins/spec-distill/tests/test_roadmap_status.sh
```

출력 일곱 줄을 담당자 보고에 그대로 싣는다(과제 10 Step 6 이 견준다).

- [ ] **Step 3: 경로 예약을 본다**

```bash
grep -n '^- 경로 예약: tools/suite/' docs/superpowers/roadmaps/2026-11-20-test-method-rework-brief/roadmap.md   # E1 블록의 예약 줄
```

E1 줄에 `codex-blessed-red.txt` 와 `test_runtime_contract_invariance.sh` 가 있어야 과제 6 을 시작한다. 없으면 과제 2–5 는 진행하고 과제 6 앞에서 멈춰 보고한다.

---

### Task 2: 다른 스위트 수 — `suite_peers.py`

AC3 의 세는 규칙(자기 자신과 자식을 세지 않는다 · 다른 러너가 없으면 0)을 한 곳에 둔다. 러너가 부르는 것은 과제 4 다.

**Files:**
- Create: `tools/suite/suite_peers.py`
- Create: `tools/suite/test_suite_timing.py`

**Interfaces:**
- Produces:
  - `parse_ps(text: str) -> list` — `(pid: int, ppid: int, command: str)` 의 목록. 셋으로 가를 수 없는 줄은 건너뛴다.
  - `is_runner(command: str) -> bool` — K2.
  - `peer_pids(rows: list, self_pid: int) -> list` — K3, 정렬된 PID 목록.
  - `read_rows() -> list | None`(주석으로 표기 — 3.9) — `SUITE_PEERS_PS_FILE` 이 있으면 그 파일, 없으면 `ps -axww -o pid=,ppid=,command=`. 못 읽으면(파일 없음 · `ps` 종료 코드 ≠ 0) `None`.
  - 명령줄 `python3 tools/suite/suite_peers.py [--pid N] [--list | --stamp | --wait S [--interval I]]` — `--pid` 기본은 부른 셸(`os.getppid()`). 기본 출력 `<수>` 또는 `?`(종료 코드 3) · `--list` 는 센 PID 한 줄씩(못 읽으면 3) · `--stamp` 는 `<epoch %.3f> <수|?>`(늘 0) · `--wait` 는 K7.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tools/suite/test_suite_timing.py` 첫 판. `HERE = os.path.dirname(os.path.abspath(__file__))` 를 `sys.path` 앞에 넣고 `import suite_peers`. 하위 프로세스 환경은 늘 `SUITE_TIMING_FILE` · `SUITE_PEERS_PS_FILE` 을 뺀 사본에서 시작한다(바깥 스위트의 값이 새지 않게).

```python
class PeerCountTests(unittest.TestCase):
    def test_is_runner_cases(self):
        yes = ["bash /r/tools/suite/run-all.sh", "/bin/bash ./tools/suite/run-all.sh",
               "-bash tools/suite/run-all.sh", "bash /Users/x/My Folder/tools/suite/run-all.sh",
               "sh -e tools/suite/run-all.sh"]
        no = ["bash -c bash tools/suite/run-all.sh",
              "python3 suite_lock.py run --lock L --owner o -- bash -c bash tools/suite/run-all.sh",
              "bash shared/tests/test_x.sh", "vim tools/suite/run-all.sh", "bash tools/suite/run-all.sh.bak", ""]
        for c in yes: self.assertTrue(suite_peers.is_runner(c), c)
        for c in no: self.assertFalse(suite_peers.is_runner(c), c)

    def test_peer_pids_fake_rows(self):
        R = "bash /w/tools/suite/run-all.sh"
        self.assertEqual(suite_peers.peer_pids([], 50), [])
        # 다른 러너 하나와 그 하위 셸(같은 명령줄) → 하나
        rows = [(1, 0, "launchd"), (100, 1, R), (101, 100, R), (102, 101, "bash shared/tests/test_a.sh")]
        self.assertEqual(suite_peers.peer_pids(rows, 50), [100])
        # 자기 자신 · 자기 하위 셸 · 자기를 감싼 조상 러너만 → 0
        rows = [(1, 0, "launchd"), (40, 1, R), (45, 40, "python3 x.py"), (50, 45, R), (51, 50, R)]
        self.assertEqual(suite_peers.peer_pids(rows, 50), [])
        # 다른 바퀴 안에서 테스트가 돌린 안쪽 러너 → 바깥 하나만
        rows = [(1, 0, "launchd"), (200, 1, R), (210, 200, "python3 run_unittest_dir.py tools/suite"),
                (220, 210, "bash /tmp/t/tools/suite/run-all.sh")]
        self.assertEqual(suite_peers.peer_pids(rows, 50), [200])
        # 감싼 프로세스(잠금 스크립트)는 러너가 아니다
        rows = [(1, 0, "launchd"), (300, 1, "python3 suite_lock.py run -- bash -c bash tools/suite/run-all.sh"), (301, 300, R)]
        self.assertEqual(suite_peers.peer_pids(rows, 50), [301])

    def test_cli_fake_ps_file(self):            # 파일에 다른 러너 하나 → 출력 "1", rc 0 · 빈 파일 → "0"
    def test_cli_unknown_rows_print_question_mark(self):   # 없는 파일 → 기본 "?" rc 3 · --stamp 는 re r"^\d+\.\d{3} \?$" rc 0
    def test_stamp_format(self):                # 빈 파일 → re r"^\d+\.\d{3} 0$"
    def test_wait_returns_at_zero_and_times_out(self):
        # 빈 파일 · --wait 5 → rc 0, 출력 "waited=0\tpeers=0"
        # 러너 한 줄 파일 · --wait 1 --interval 0.2 → rc 1, 출력이 "\tpeers=1" 로 끝난다

    @unittest.skipUnless(shutil.which("ps"), "ps 없음")
    def test_real_ps_detached_runner_counted_once(self):
        # 임시 폴더 f/run-all.sh = 'echo $$ > pid; ( sleep 5; : ) & echo $! > child; wait'
        # bash -c 'bash f/run-all.sh >/dev/null 2>&1 &' 로 두 번 갈라 띄우고 pid · child 파일이 생길 때까지 기다린다
        # python3 suite_peers.py --pid <os.getpid()> --list 출력에 pid 가 있고 child 는 없다. 끝에 두 PID 를 kill 한다

    @unittest.skipUnless(shutil.which("ps"), "ps 없음")
    def test_real_ps_self_ancestor_child_excluded(self):
        # a/run-all.sh = 'echo $$ > a.pid; bash b/run-all.sh'
        # b/run-all.sh = 'echo $$ > b.pid; ( sleep 3; : ) & echo $! > b.child; python3 <suite_peers.py> --pid $$ --list > out; wait'
        # bash a/run-all.sh 를 직접(자식으로) 돌린 뒤: out 에 a.pid · b.pid · b.child 가 하나도 없다
```

- [ ] **Step 2: 실패를 본다**

Run: `cd tools/suite && python3 -m unittest test_suite_timing.PeerCountTests -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'suite_peers'`

- [ ] **Step 3: `tools/suite/suite_peers.py` 를 쓴다**

`peer_pids` 의 알고리즘(서명과 테스트가 정하지 않는 부분):

```text
by_pid = {pid: (ppid, cmd)}
ancestors(p) = ppid 를 따라 올라간 PID 집합(없는 PID · 0 에서 멈춘다, 방문 집합으로 고리를 끊는다)
descendants(s) = ppid 가 집합 안에 있는 PID 를 더해 가는 넓이 우선
excluded = {self} ∪ ancestors(self) ∪ descendants(self)
runners = {p | is_runner(cmd(p))}
결과 = sorted(p ∈ runners − excluded 이고 ancestors(p) ∩ runners 가 빈 것)
```

`--wait` 는 `time.monotonic()` 으로 잰다. 파일 머리 docstring 에 명령줄 꼴과 「세는 것 · 세지 않는 것」 을 설계 §1 의 말로 두 줄 적는다.

- [ ] **Step 4: 통과를 본다**

Run: `cd tools/suite && python3 -m unittest test_suite_timing.PeerCountTests -v`
Expected: PASS — 8 tests

- [ ] **Step 5: 하위 셸 관측을 적는다**

Deferred 0f77adb0#r3.1 의 관측이다. 임시 레포 하나에서 `bash tools/suite/run-all.sh` 를 띄워 둔 동안(과제 4 뒤라면 실제 러너, 지금은 위 테스트의 가짜 러너로 충분하다) `ps -axww -o pid=,ppid=,command= | grep run-all.sh` 를 한 번 찍어 같은 명령줄의 하위 셸이 보이는지와 `--list` 가 그중 하나만 내는지를 담당자 보고에 두세 줄로 싣는다.

- [ ] **Step 6: 커밋**

```bash
git add tools/suite/suite_peers.py tools/suite/test_suite_timing.py
git commit -m "feat(suite): 다른 스위트 러너 수를 세는 suite_peers (E1)"
```

---

### Task 3: python 폴더 러너 — 모듈별 시간과 변수 빼기

AC5 와 AC27 의 python 쪽이다.

**Files:**
- Modify: `tools/suite/run_unittest_dir.py`
- Test: `tools/suite/test_suite_timing.py`

**Interfaces:**
- Consumes: 없음
- Produces: `run_unittest_dir.py` 가 환경 변수 `SUITE_TIMING_FILE`(절대 경로)을 받으면 실행 끝에 `<초 %.3f>\tpymod\t<폴더>/<모듈 파일>` 줄을 모듈 경로 차례로 덧붙인다. 빈 값은 없는 것과 같다. 상대 경로는 표준 오류 `run_unittest_dir: SUITE_TIMING_FILE 은 절대 경로여야 한다 — 기록하지 않는다: <값>` 한 줄. 쓰기 실패는 `run_unittest_dir: 시간 기록 파일에 쓸 수 없다 — 기록하지 않는다: <값>` 한 줄. 표준 출력 · 종료 코드는 그대로. 과제 4 가 이 동작에 기댄다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

임시 폴더를 현재 폴더로 `python3 <HERE>/run_unittest_dir.py pkg/tests` 를 돌린다. 표준 출력을 견줄 때 `Ran N tests in X.XXXs` 줄의 시간은 `re.sub(r"in \d+\.\d+s", "in Xs", out)` 로 지운다.

```python
class UnittestDirTimingTests(unittest.TestCase):
    def test_pymod_lines_per_module(self):
        # pkg/tests/test_a.py(통과 둘) · test_b.py(통과 하나 — time.sleep(0.2))
        lines = timing lines
        self.assertEqual(sorted(l.split("\t")[2] for l in lines), ["pkg/tests/test_a.py", "pkg/tests/test_b.py"])
        self.assertTrue(all(l.split("\t")[1] == "pymod" for l in lines))
        self.assertGreaterEqual(float(<test_b 줄의 첫 칸>), 0.2)

    def test_stdout_and_rc_same_with_and_without_var(self):
        # 통과 하나 · 실패 하나(FAIL: 줄이 나온다) — 두 실행의 정규화한 표준 출력과 rc(1) 가 같다

    def test_var_not_inherited_by_tests(self):
        # pkg/tests/test_env.py: assertNotIn("SUITE_TIMING_FILE", os.environ) — 변수를 준 실행의 rc 가 0

    def test_relative_path_refused(self):
        # SUITE_TIMING_FILE="rel.tsv" → 표준 오류에 "run_unittest_dir: SUITE_TIMING_FILE 은 절대 경로여야 한다" 한 줄,
        # 현재 폴더에 rel.tsv 없음, 표준 출력 · rc 는 변수 없는 실행과 같다

    def test_import_failure_module_keyed_by_file(self):
        # pkg/tests/test_broken.py 가 맨 위에서 raise ImportError("x") → pymod 줄 키 "pkg/tests/test_broken.py", rc 1
```

- [ ] **Step 2: 실패를 본다**

Run: `cd tools/suite && python3 -m unittest test_suite_timing.UnittestDirTimingTests -v`
Expected: FAIL — 기록 파일이 생기지 않는다(`FileNotFoundError` 또는 빈 줄 목록) · `test_var_not_inherited_by_tests` 는 rc 1

- [ ] **Step 3: `run_unittest_dir.py` 를 고친다**

- `main` 첫머리(찾기 전)에 `timing = os.environ.pop("SUITE_TIMING_FILE", "")` — 절대 경로 검사(`os.path.isabs`).
- `class _TimedResult(unittest.TextTestResult)` — `startTestRun` 에서 `self.module_secs = {}` · `self._last = time.monotonic()`, `stopTest` 에서 `now - self._last` 를 `module_key(test, start)` 에 더하고 `self._last = now` 뒤 `super().stopTest(test)`. 출력은 더하지 않는다.
- `module_key(test, start: str) -> str` — `sys.modules[type(test).__module__].__file__` 의 `os.path.relpath(…, os.getcwd())`. `unittest.loader._FailedTest` 면 `os.path.join(start, test._testMethodName + ".py")`.
- `TextTestRunner(stream=sys.stdout, verbosity=1, resultclass=_TimedResult)` 는 변수와 무관하게 늘 쓴다. 실행 뒤 `timing` 이 있으면 덧붙이고 `OSError` 는 알림 한 줄.
- docstring 에 변수 한 줄을 더한다.

- [ ] **Step 4: 통과를 본다**

Run: `cd tools/suite && python3 -m unittest test_suite_timing -v`
Expected: PASS — 13 tests(과제 2 의 8 + 5)

- [ ] **Step 5: 커밋**

```bash
git add tools/suite/run_unittest_dir.py tools/suite/test_suite_timing.py
git commit -m "feat(suite): python 폴더 러너가 모듈별 시간을 남긴다 (E1)"
```

---

### Task 4: 셸 러너 — 시작 · 대상 · 끝 줄

AC1 · AC2 · AC3 · AC4 · AC27 이다.

**Files:**
- Modify: `tools/suite/run-all.sh`
- Test: `tools/suite/test_suite_timing.py`

**Interfaces:**
- Consumes: `suite_peers.py --pid <PID> --stamp`(과제 2) · `run_unittest_dir.py` 의 `SUITE_TIMING_FILE`(과제 3)
- Produces: `SUITE_TIMING_FILE=<절대 경로> bash tools/suite/run-all.sh` 가 Global Constraints 의 네 줄 꼴을 덧붙인다. 알림 두 가지(글자 그대로): `run-all: SUITE_TIMING_FILE 은 절대 경로여야 한다 — 기록하지 않는다: <값>` · `run-all: 시간 기록 파일에 쓸 수 없다 — 기록하지 않는다: <값>`. 과제 5 · 10 과 지휘자의 대조가 이 파일을 읽는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

도우미 둘을 테스트 클래스에 둔다.

- `make_repo(self, files: dict, node: bool = False) -> str` — 임시 폴더에 `git init -q`, `tools/suite/` 에 이 폴더의 `run-all.sh` · `run_unittest_dir.py` · `suite_peers.py` 를 복사, `files`(경로 → 내용)를 쓰고 셸 파일은 실행 비트, `node` 면 `plugins/p/tests/n.test.mjs`(통과 하나)를 더하고 `git add -A`. 돌려주는 경로는 `os.path.realpath`(macOS `/var` → `/private/var` — 시작 줄의 꼭대기 경로와 견주려면 실경로다).
- `run_all(self, repo, extra_env=None) -> tuple` — `BASH = "/bin/bash" if os.path.exists("/bin/bash") else shutil.which("bash")` 로 `[BASH, "tools/suite/run-all.sh"]` 를 `cwd=repo` 에서 돌려 `(rc, stdout, stderr)`.

기본 레포(`BASE`): `shared/tests/test_pass.sh`(`echo "  ✓ ok"`) · `plugins/p/tests/test_fail.sh`(`echo "  ✗ broke"; exit 1`) · `plugins/p/tests/test_u.py`(통과 하나) · `tools/x/test_t.py`(통과 하나). node 는 `shutil.which("node")` 가 있을 때만 더하고, 대상 줄의 기대 수를 그에 맞춘다(셸 2 + python 폴더 3 — `plugins/p/tests` · `shared/tests` · `tools/x` — + node 0|1).

```python
class RunAllTimingTests(unittest.TestCase):
    def test_ac1_without_var_fail_and_pass(self):
        rc, out, err = self.run_all(self.make_repo(BASE))
        self.assertEqual((rc, out, err), (1, "FAILED plugins/p/tests/test_fail.sh: broke\n", ""))
        rc, out, err = self.run_all(self.make_repo(BASE_WITHOUT_FAIL))
        self.assertEqual((rc, out, err), (0, "", ""))

    def test_ac2_lines_and_same_stdout(self):
        # 변수 없는 실행과 rc · stdout 이 같다. kinds = 대상 줄 둘째 칸
        self.assertEqual([l.split("\t")[0] for l in lines].count("start"), 1)
        self.assertEqual([l.split("\t")[0] for l in lines].count("end"), 1)
        self.assertEqual(len(target_lines), 2 + 3 + node)
        self.assertEqual(sorted(kinds), sorted(["sh"] * 2 + ["py"] * 3 + ["node"] * node))
        self.assertTrue(any(l.split("\t")[1] == "pymod" for l in lines))   # python 러너가 같은 파일에 썼다

    def test_ac3_start_count_from_fake_ps(self):
        # SUITE_PEERS_PS_FILE = 빈 파일 → 시작 줄 셋째 칸 "0" · 끝 줄 "0"
        # 러너 한 줄("100 1 bash /o/tools/suite/run-all.sh") → 시작 줄 "1"

    def test_ac3_peer_appearing_mid_round(self):
        # 레포에 plugins/p/tests/test_1_up.sh(ps 파일 절대 경로를 글자로 박아 러너 한 줄을 쓴다) · test_2_down.sh(그 파일을 비운다)
        # → 시작 "0" · test_1_up.sh 줄 넷째 칸 ≥ 1 · test_2_down.sh 줄 "0" · 끝 "0"

    def test_ac3_toplevel_in_start_line(self):
        self.assertEqual(start_line.split("\t")[3], repo)

    def test_ac4_unwritable_file(self):
        # SUITE_TIMING_FILE = <일반 파일>/x.tsv → stderr 에 "run-all: 시간 기록 파일에 쓸 수 없다" 한 줄, stdout · rc 는 AC1 과 같다

    def test_ac27_nested_runner_single_start(self):
        # 둘째 임시 레포 INNER(통과 셸 하나)를 만들고, BASE 에 더한다:
        #   plugins/p/tests/test_nested.sh: (cd INNER && bash tools/suite/run-all.sh)
        #   tools/x/test_nested.py: subprocess 로 같은 일
        # → 기록 파일의 start 줄 하나, end 줄 하나. 대상 줄의 경로에 INNER 의 것이 없다

    def test_ac27_relative_path(self):
        # SUITE_TIMING_FILE="rel.tsv" → stderr 에 "run-all: SUITE_TIMING_FILE 은 절대 경로여야 한다" 한 줄,
        # repo 와 현재 폴더에 rel.tsv 없음, stdout · rc 는 AC1 과 같다

    def test_unknown_peer_count_written_as_question_mark(self):
        # SUITE_PEERS_PS_FILE = 없는 경로 → 시작 · 대상 · 끝 줄의 수 칸이 모두 "?"

    def test_killed_round_keeps_lines_without_end(self):
        # BASE 에 shared/tests/test_zzz_slow.sh(sleep 30) — 셸 대상 가운데 마지막 차례
        # start_new_session=True 로 띄우고, 기록 파일에 sh 줄이 둘 생기면 os.killpg(SIGTERM)
        # → start 줄 하나 · sh 줄 ≥ 2 · end 줄 없음

    def test_two_rounds_in_one_file_are_told_apart(self):
        # 서로 다른 레포 둘을 같은 기록 파일로 차례로 → start 줄 둘의 넷째 칸이 두 레포 경로 · end 줄 둘
```

- [ ] **Step 2: 실패를 본다**

Run: `cd tools/suite && python3 -m unittest test_suite_timing.RunAllTimingTests -v`
Expected: `test_ac1_without_var_fail_and_pass` 만 PASS, 나머지는 기록 파일이 생기지 않거나 알림이 없어 FAIL

- [ ] **Step 3: `run-all.sh` 를 고친다**

- `cd` 다음에 `TOP="$(pwd)"` · `SELF_PID=$$` · `PEERS="tools/suite/suite_peers.py"` · `TIMING="${SUITE_TIMING_FILE:-}"` · `unset SUITE_TIMING_FILE`. 값이 있으면 절대 경로 검사 → 쓰기 확인(K10) → 실패면 알림 한 줄 · `TIMING=""`.
- 함수 `timing_mark <kind> <target>` — `TIMING` 이 비면 바로 돌아간다. `python3 "$PEERS" --pid "$SELF_PID" --stamp 2>/dev/null` 의 출력을 `${s%% *}` · `${s#* }` 로 가르고, 걸린 초는 `awk -v a="$now" -v b="$T_PREV" 'BEGIN{printf "%.3f", a-b}'`(어느 쪽이 비면 `?`), 줄을 덧붙인 뒤 `T_PREV="$now"`. 덧붙이기 실패는 K10.
- 시작 줄은 `{ … } | LC_ALL=C sort` 앞에서 쓰고 `T_PREV` 를 그 stamp 로 둔다. 네 반복문의 `emit` 다음 줄마다 `timing_mark sh "$f"` · `timing_mark py "$d"`(두 반복문) · `timing_mark node "$f"`. python 러너 부르기는 `SUITE_TIMING_FILE="$TIMING" python3 "$RUNNER" "$d"` 로 바꾼다(K9). 끝 줄은 `cat "$LIST"` 앞에서.
- 머리 주석에 변수 한 줄(무엇을 언제 덧붙이나 · 절대 경로만)을 더한다. 27행 찾기 줄은 그대로다(Global Constraints).

- [ ] **Step 4: 통과를 본다**

Run: `cd tools/suite && python3 -m unittest test_suite_timing -v`
Expected: PASS — 24 tests(node 가 없으면 node 몫만 줄어든 기대로 같은 수)

Run: `bash shared/tests/test_shell_tests_executable.sh; echo rc=$?`
Expected: rc=0 — 찾기 줄을 여전히 꺼낸다

- [ ] **Step 5: 고치기 전 러너와 한 번 견준다(AC1)**

과제 1 의 HEAD 에서 옛 러너를 꺼내(`git show <과제 1 HEAD>:tools/suite/run-all.sh > <TMPDIR>/old-run-all.sh` · 같은 꼴로 `run_unittest_dir.py`) `make_repo` 와 같은 임시 레포 둘(실패 있음 · 없음)에서 옛 · 새 러너를 변수 없이 돌려 표준 출력 · 표준 오류 · 종료 코드가 같음을 보인다. 결과 두 줄을 담당자 보고에 싣는다. 이 견줌은 커밋하지 않는다.

- [ ] **Step 6: 커밋**

```bash
git add tools/suite/run-all.sh tools/suite/test_suite_timing.py
git commit -m "feat(suite): 전체 러너가 대상마다 걸린 시간과 겹침을 남긴다 (E1)"
```

---

### Task 5: 「앞」 바퀴

느린 테스트를 고치기 전의 숫자다 — python 묶음과 한 바퀴 전체의 첫 실측이다(설계 §2 · OQ23). AC12 · AC13 의 앞쪽이다. 이 과제는 코드를 고치지 않는다.

**Files:** 없음(기록은 TMPDIR)

- [ ] **Step 1: 시간 기록만 들어간 커밋인지 본다**

```bash
git log --oneline <과제 1 HEAD>..HEAD
git diff --stat <과제 1 HEAD> HEAD
```

Expected: 과제 2 · 3 · 4 의 커밋 셋, 바뀐 파일은 `tools/suite/` 의 넷뿐이다.

- [ ] **Step 2: 잠금 아래 한 바퀴를 돈다**

```bash
T=<TMPDIR 절대 경로>
python3 tools/suite/suite_peers.py --pid $$ > "$T/before.peers-at-start"
env SUITE_TIMING_FILE="$T/timing-before.tsv" python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.25.0"/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-20-test-method-rework-brief/files/suite-lock --owner <담당자 이름> --wait 7200 -- bash -c 'bash tools/suite/run-all.sh' > "$T/before.out" 2>&1; echo "rc=$?" >> "$T/before.out"
```

Expected: `timing-before.tsv` 에 끝 줄이 있다. 잠금을 못 잡았으면 `show --lock` 출력과 함께 멈춘다.

- [ ] **Step 3: 숫자를 뽑는다**

기록을 읽는 도구는 만들지 않는다(설계 §1). 아래 두 줄로 뽑아 담당자 보고에 싣는다 — 합계(끝 시각 − 시작 시각) · 종류별 합 · 시작과 끝의 다른 스위트 수 · 겹친 대상 줄의 초 합과 그 비율 · 가장 느린 스물(대상 줄만 — `pymod` 는 그 폴더의 `py` 줄 안에 든다). `?` 칸은 겹친 것으로 센다.

```bash
awk -F'\t' '$1=="start"{s=$2;sp=$3} $1=="end"{e=$2;ep=$3} ($2=="sh"||$2=="py"||$2=="node"){k[$2]+=$1; if($4!="0") ov+=$1} END{printf "합계 %.0f초 · 시작 수 %s · 끝 수 %s · sh %.0f · py %.0f · node %.0f · 겹친 대상 %.0f초 (%.1f%%)\n", e-s, sp, ep, k["sh"], k["py"], k["node"], ov, (e>s?100*ov/(e-s):0)}' "$T/timing-before.tsv"
awk -F'\t' '$2=="sh"||$2=="py"||$2=="node"' "$T/timing-before.tsv" | sort -t"$(printf '\t')" -k1,1 -rn | head -20
```

python 폴더별 `py` 줄과 그 폴더의 `pymod` 상위 다섯도 함께 싣는다(OQ23 — `awk -F'\t' '$2=="pymod"' … | sort -rn | head -5` 를 폴더마다). 겹치지 않은 바퀴인지(시작 · 끝 수 0, 겹친 대상 초 ≤ 합계의 5%)를 한 줄로 적는다.

- [ ] **Step 4: 실패 이름 집합을 남긴다**

```bash
grep '^FAILED ' "$T/before.out" | LC_ALL=C sort > "$T/before.failed"
```

과제 10 이 이것과 견준다. 커밋하지 않는다.

---

### Task 6: 스위트 안의 스위트 — 원장에 등재된 것만

AC6 · AC7 이다. 과제 1 Step 3 의 경로 예약이 맞춰졌을 때만 시작한다.

**Files:**
- Modify: `plugins/quality-gates/tests/test_codex_backward_compat.sh`
- Modify: `plugins/quality-gates/tests/codex-blessed-red.txt`(머리말 3 · 11–13행)
- Modify: `plugins/quality-gates/tests/test_runtime_contract_invariance.sh`(108–111행 주석)

**Interfaces:**
- Consumes: 원장 `codex-blessed-red.txt` 의 꼴(`<파일 이름> <지문>`) · 지금의 `fingerprint` · `EMPTY_DIGEST_SHA256` · `ledger` 판정(K13)
- Produces: 셋째 확인의 PASS 한 줄 — 등재 0건이면 `  PASS: 등재 0건 — 다시 돌린 테스트 0개`, 등재가 있으면 `  PASS: 등재 <n>건 — 지문 일치 · stale 등재 0`. FAIL 줄은 사유마다(`stale 등재` · `해시불일치` · `빈지문` · `원장 없음` · `등재된 파일 없음` · `자기 등재`).

- [ ] **Step 1: 고치기 전 출력을 남긴다**

Run: `bash plugins/quality-gates/tests/test_codex_backward_compat.sh > <TMPDIR>/compat.before; echo rc=$?`
Expected: rc=0, `Total: 4, pass: 4, fail: 0`

Run: `bash plugins/quality-gates/tests/test_runtime_contract_invariance.sh > <TMPDIR>/invariance.before; echo rc=$?`
Expected: rc=0 — 요약 줄을 적어 둔다

- [ ] **Step 2: 셋째 확인을 고친다**

- 머리 주석의 「Three checks」 셋째 줄을 「3. 원장(codex-blessed-red.txt)에 등재된 red 만 다시 돌려 지문을 대조한다 — 등재되지 않은 실패는 전체 러너가 그 테스트를 직접 돌려 자기 `FAILED` 줄로 낸다」 꼴로 바꾼다.
- 걷는 것(설계 §3): `CODEX_TOUCHING_TESTS` · `EXCLUDED_TESTS_PIN` · `is_excluded` · 제외 목록 알람 블록(정당성 · 크기 검사와 그 PASS/FAIL) · `existing_run` 과 `total_candidates` 바닥 · 72–96 · 99–114 · 127–140 · 238–248행의 그것들을 설명하는 주석. `SELF` 는 자기 등재 검사에 남긴다.
- 원장 판정 블록(161–175행)의 「양방향이다: 미등재·해시 불일치 실패는 RED」 를 「등재된 테스트가 다른 이유로 실패하면(해시 불일치) RED, 등재됐는데 GREEN 이면 RED」 로 바꾼다. 정규화 · L3 빈 지문 문단은 그대로 둔다.
- 반복문은 테스트 폴더가 아니라 원장의 등재 줄을 돈다(K13). 등재 테스트마다 판정은 지금과 같다 — rc 0 이면 stale, 아니면 `fingerprint` 를 지문과 견준다(빈 지문은 받아들이지 않는다).

- [ ] **Step 3: 원장 머리말과 다른 테스트의 인용을 고친다**

- `codex-blessed-red.txt` 3행을 Step 2 의 새 문장과 같은 뜻으로, 11–13행의 「새 red를 여기 등재하지 않으면 test_codex_backward_compat.sh가 `미등재`로 RED를 낸다」 를 「등재하지 않은 red 는 전체 러너가 그 테스트의 `FAILED` 줄로 낸다」 로. 날짜가 박힌 경위 문단(15–36행)은 고치지 않는다(AC7).
- `test_runtime_contract_invariance.sh` 110행의 괄호(`test_codex_backward_compat.sh 헤더의 "의식적 갱신 강제"와 같은 패턴`)를 지운다 — 앞뒤 문장만으로 뜻이 선다.

- [ ] **Step 4: 통과와 걷힌 것을 본다**

Run: `bash plugins/quality-gates/tests/test_codex_backward_compat.sh; echo rc=$?`
Expected: rc=0, `PASS: 등재 0건 — 다시 돌린 테스트 0개` 줄, `Total: 3, pass: 3, fail: 0`. 실행 시간이 몇 초다(지금 460초 안팎).

Run: `bash plugins/quality-gates/tests/test_runtime_contract_invariance.sh; echo rc=$?`
Expected: rc=0, 요약 줄이 `<TMPDIR>/invariance.before` 와 같다

Run(AC7):
```bash
git grep -n -e CODEX_TOUCHING_TESTS -e EXCLUDED_TESTS_PIN -e existing_run -e is_excluded -e '제외 목록' -e '미등재' -e '의식적 갱신 강제' -e 'All existing qg test files' -- plugins/quality-gates/tests/test_codex_backward_compat.sh plugins/quality-gates/tests/codex-blessed-red.txt plugins/quality-gates/tests/test_runtime_contract_invariance.sh
git grep -n test_codex_backward_compat -- plugins shared tools ':!*CHANGELOG.md'
```
Expected: 첫 명령은 빈 출력. 둘째는 원장 머리말의 경위 문단(날짜가 박힌 지난 기록)과 그 파일 자신만 — 다른 테스트 · 스크립트에서 걷힌 동작을 지금 것으로 설명하는 줄이 없다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/quality-gates/tests/test_codex_backward_compat.sh plugins/quality-gates/tests/codex-blessed-red.txt plugins/quality-gates/tests/test_runtime_contract_invariance.sh
git commit -m "test(qg): 스위트 안의 스위트를 원장 등재분만 다시 돌리게 (E1)"
```

- [ ] **Step 6: 사본에서 판정을 보인다(AC6)**

`plugins/quality-gates` 폴더를 TMPDIR 아래로 `cp -R` 한다(테스트는 자기 폴더에서 `PLUGIN_ROOT` 를 도출한다). 사본의 `tests/` 에 카나리아 둘을 둔다 — `test_zz_canary_pass.sh`(실행되면 `<TMPDIR>/canary.ran` 을 만들고 통과) · `test_zz_canary_fail.sh`(`echo "  FAIL: canary"; exit 1`). 사본의 테스트를 넷 번 돌린다.

| 사본의 원장 | 기대 |
|---|---|
| 등재 0건 | rc 0 · `등재 0건` 줄 · `canary.ran` 이 생기지 않는다(다른 테스트 파일을 하나도 띄우지 않는다) |
| `test_zz_canary_pass.sh <아무 지문>` | rc 1 · `stale 등재` FAIL |
| `test_zz_canary_fail.sh 0000…`(틀린 지문) | rc 1 · `해시불일치:<지문>` FAIL — 이 지문을 적어 둔다 |
| `test_zz_canary_fail.sh <앞 줄에서 적은 지문>` | rc 0 |

네 줄의 결과를 담당자 보고에 싣는다. 사본은 지운다(그 폴더만 — glob 삭제 금지).

---

### Task 7: `test_copy_of_contract.sh` — 임포트 색인

AC8 이다.

**Files:**
- Modify: `shared/tests/test_copy_of_contract.sh`(800–833행의 `IMPSCAN` · `impscan`)

**Interfaces:**
- Consumes: 없음
- Produces: `impscan <모듈명>` — 계약 그대로(표준 입력 후보 경로 → 그 모듈을 임포트하는 것만 같은 차례로 표준 출력). 안쪽: `IMPSCAN` python 의 `imported_names(path) -> set | None`(파싱 실패는 `None` — 소비하지 않는 것으로 친다) · 모드 `--index`(표준 입력 경로 → `<경로>\t<이름들>`) · 모드 `<모듈명>`(지금의 동작). `IMPINDEX` 는 `lock_tmp_add` 로 정리한다.

- [ ] **Step 1: 고치기 전 출력과 소비자 집합을 남긴다**

Run: `bash shared/tests/test_copy_of_contract.sh > <TMPDIR>/copyof.before 2>&1; echo rc=$?`
Expected: rc=0. 걸린 시간을 적는다(약 112초).

소비자 집합 대조용으로, 고치기 전 `IMPSCAN` heredoc 의 안쪽(803행 `# argv: <모듈명>.` 부터 `IMPEOF` 앞 줄까지)을 `<TMPDIR>/impscan_old.py` 로 꺼내 둔다.

- [ ] **Step 2: 색인을 넣는다**

- `IMPSCAN` heredoc 을 K14 대로 — 술어는 `imported_names` 하나에 둔다: `ast.Import` 는 각 이름의 첫 성분, `ast.ImportFrom` 은 `module` 이 있으면 그 첫 성분(이름 쪽은 보지 않는다), `module` 이 없고 `level` 이 있으면 각 이름. 지금 815–824행의 주석 셋을 그 갈래에 그대로 옮긴다.
- heredoc 바로 뒤에서 색인을 한 번 만든다: `IMPINDEX="$(mktemp -t copyof-impindex-XXXXXX)"` · `lock_tmp_add "$IMPINDEX"` · `git ls-files -- '*.py' | python3 "$IMPSCAN" --index > "$IMPINDEX"`.
- `impscan()` 은 `awk -F'\t'` 로 색인을 읽어 후보가 색인에 있으면 이름 집합에 모듈이 있을 때 내고, 없는 후보는 모아 `python3 "$IMPSCAN" "$1"` 에 넘긴다. 머리 주석에 「색인은 추적 python 파일을 한 번만 파싱한다 — 색인에 없는 후보는 그 자리에서 같은 술어로」 한 줄.
- 1124행의 `rm -f` 줄에 `"$IMPINDEX"` 를 더한다.
- 부르는 두 자리(841 · 1034행 근처)와 `CORPUS=` · `CONSUMED_PY=` · `consumers=` 의 도출은 글자 그대로다.

- [ ] **Step 3: 통과와 같은 출력을 본다**

Run: `bash shared/tests/test_copy_of_contract.sh > <TMPDIR>/copyof.after 2>&1; echo rc=$?; diff <TMPDIR>/copyof.before <TMPDIR>/copyof.after`
Expected: rc=0 · diff 빈 출력(단언 수 · `축-실행` 줄 · `Total:` 줄이 같다). 걸린 시간을 적는다.

Run: `bash shared/tests/test_no_new_duplication.sh; echo rc=$?`
Expected: rc=0 — 이 락이 사본 계약 락에 맡긴 동일성 판정이 그대로 선다(설계 §3)

- [ ] **Step 4: 소비자 집합을 한 번 견준다(AC8)**

임시 스크립트로(커밋하지 않는다): `git ls-files -- 'shared/*.py'` 의 모듈마다 ① `git ls-files -- '*.py' | grep -v "/<모듈>\.py$"` ② `git ls-files -- 'plugins/*' | grep -vE '/(fixtures|mocks|harness)/' | grep -E '\.py$' | grep -v "/<모듈>\.py$"` 두 후보 묶음을 옛 `impscan_old.py <모듈>` 과 새 `impscan`(고친 파일에서 함수와 heredoc 을 그대로 꺼내 쓴다)에 넣어 출력이 같은지 본다. 「모듈 61개 × 후보 묶음 2 — 다른 것 0」 꼴 한 줄을 담당자 보고에 싣는다.

- [ ] **Step 5: 커밋**

```bash
git add shared/tests/test_copy_of_contract.sh
git commit -m "test(shared): 사본 계약 락이 임포트 색인을 한 번만 만든다 (E1)"
```

- [ ] **Step 6: 술어 변이(AC8)**

커밋 뒤 `git clone --no-local <이 worktree 경로> <TMPDIR>/clone-copyof` 사본에서, `imported_names` 의 갈래 넷을 하나씩 지운 판을 만들어 `bash shared/tests/test_copy_of_contract.sh` 를 돈다(`PYTHONDONTWRITEBYTECODE=1`). `ImportFrom` 의 `module` 갈래를 지운 판은 rc 1 이어야 한다. 나머지 셋의 rc 와 처음 나온 `✗` 줄을 표로 담당자 보고에 싣는다(그 갈래를 쓰는 소비자가 없으면 GREEN 일 수 있다 — 그 사실을 적는다). 변이 없는 사본이 rc 0 인 것도 같은 표에 적는다(양성 대조). 사본은 그 폴더만 지운다.

---

### Task 8: `test_docreview_mutations.sh` — 깨끗한 사본 실행은 케이스마다 한 번

AC9 이다.

**Files:**
- Modify: `shared/tests/test_docreview_mutations.sh`(80–91 · 187행 근처)

**Interfaces:**
- Consumes: `run_case <scripts-dir> <case-fn>` · `_split3` · `CLEAN` · `BASE_MUT`(그대로)
- Produces: `clean_result <case-fn>` — `$BASE_MUT/.clean-results/<case-fn>` 이 있으면(빈 파일이어도) 그 내용을, 없으면 `run_case "$CLEAN" "<case-fn>"` 의 한 줄을 그 파일에 쓰고 낸다(K15).

- [ ] **Step 1: 고치기 전 출력을 남긴다**

Run: `bash shared/tests/test_docreview_mutations.sh > <TMPDIR>/mut.before 2>&1; echo rc=$?`
Expected: rc=0. 걸린 시간을 적는다(약 340초).

- [ ] **Step 2: 캐시를 넣는다**

- `CLEAN=…; mkclone "$CLEAN"` 다음에 `mkdir -p "$BASE_MUT/.clean-results"` 와 `clean_result()` 정의. 파일이 있는지는 `[ -f ]` 로 가른다(빈 출력도 캐시된 값이다 — `classify_result` 가 형태 검사로 「계측기 고장」 을 그대로 낸다).
- 82–91행 양성 대조 반복문의 `run_case "$CLEAN" "$c"` 와 187행의 `run_case "$CLEAN" "$case"` 를 `clean_result` 로. 95행의 계측기 탐침은 그대로 `run_case`.
- `clean_result` 위에 「깨끗한 사본의 결과는 케이스마다 한 번 재고 다시 쓴다 — 「깨끗한 사본에서 초록이어야 잰 것으로 친다」 는 판정은 그대로다」 한 줄.

- [ ] **Step 3: 같은 출력을 본다**

Run: `bash shared/tests/test_docreview_mutations.sh > <TMPDIR>/mut.after 2>&1; echo rc=$?; diff <TMPDIR>/mut.before <TMPDIR>/mut.after`
Expected: rc=0 · diff 빈 출력(변이 수 · 잡힌 수 · 측정 불가 수 · `Total:` 이 같다). 걸린 시간을 적는다.

- [ ] **Step 4: 커밋**

```bash
git add shared/tests/test_docreview_mutations.sh
git commit -m "test(shared): 변이 매트릭스의 깨끗한 사본 실행을 케이스마다 한 번 (E1)"
```

- [ ] **Step 5: 케이스마다 한 번인지 센다(AC9)**

`git clone --no-local` 사본에서 `run_case` 첫 줄에 `[ "$1" = "$CLEAN" ] && echo "$2" >> <TMPDIR>/clean-runs.txt` 를 넣고 돈다. `sort <TMPDIR>/clean-runs.txt | uniq -d` 에서 탐침(`_case_subshell_refusal_probe`)만 빼면 빈 출력이고, 줄 수가 (탐침 1 + 셀과 양성 대조가 겨냥한 서로 다른 케이스 수) 와 같다 — 계획을 쓸 때 서로 다른 케이스는 89개였다. 두 숫자를 보고에 싣는다.

- [ ] **Step 6: 깨끗한 사본에서 빨간 케이스(AC9 · K20)**

새 사본(Step 5 의 계측 줄은 남긴다)과, 과제 1 HEAD 를 체크아웃한 `git clone --no-local` 옛 사본 둘에 같은 주입을 넣는다 — 첫 셀 앞에 `case_zz_clean_red() { no "고의 실패"; }` 를 정의하고, `finish` 앞에 같은 케이스를 겨냥한 셀 둘을 더한다(치환은 `canary_crash` 셀이 쓰는 것이라 churn 이 1/1 로 맞는다).

```bash
mut 1/1 zz_red_a case_zz_clean_red sed_route 's/if v.get("evidence"):/if True:/'
mut 1/1 zz_red_b case_zz_clean_red sed_route 's/if v.get("evidence"):/if True:/'
```

두 사본의 출력에서 두 셀의 줄이 글자까지 같아야 한다(지금 판정 — `판정=instrument_broken 기대=caught 불일치 — 계측기 고장 — 양성 대조 실패(clean=…)`). 새 사본의 `clean-runs.txt` 에 `case_zz_clean_red` 가 한 번만 있어 둘째 셀이 캐시를 탔음을 보인다. 결과를 보고에 싣는다. 사본들은 그 폴더만 지운다.

---

### Task 9: 바이트코드 캐시 — 재 보고 줄 때만 넣는다

AC10 이다.

**Files:**
- Modify(조건부): `shared/tests/test_docreview_state.sh` · `shared/tests/test_docreview_route.sh` · `shared/tests/test_docreview_advice.sh`

**Interfaces:**
- Consumes: `fixtures/docreview/cases.sh` 가 켜 둔 `PYTHONDONTWRITEBYTECODE=1`(그대로 둔다)
- Produces: 없음 — 세 테스트의 단언과 출력은 그대로다.

- [ ] **Step 1: 「앞」 을 잰다**

세 테스트를 차례로, 각 실행 직전 `python3 tools/suite/suite_peers.py --pid $$` 를 적고, `python3 -c 'import time; print(time.time())'` 를 앞뒤에 찍어 걸린 초를 잰다. 출력은 `<TMPDIR>/pyc.before.<state|route|advice>` 로 남긴다. 합계를 적는다.

- [ ] **Step 2: 세 파일에 네 줄을 넣는다**

K16 의 네 줄을 케이스 모음을 부르는 마지막 `. "$HERE/fixtures/docreview/…"` 줄 바로 뒤에 넣는다. 그 위에 「세 테스트는 스크립트를 변이하지 않는다 — 바이트코드를 이 실행의 임시 폴더에 둔다(레포 안에는 생기지 않는다). 변이 매트릭스는 그대로 쓰지 않는다」 한 줄.

- [ ] **Step 3: 「뒤」 를 재고 넣을지 정한다**

시작 전에 `touch <TMPDIR>/pyc.marker`. Step 1 과 같은 꼴로 세 테스트를 돌려 `<TMPDIR>/pyc.after.*` 와 합계를 남긴다.

- 세 출력이 앞과 diff 빈 출력이어야 한다(단언 수가 같다).
- `find . -name __pycache__ -type d -newer <TMPDIR>/pyc.marker -not -path './.git/*'` 가 빈 출력이어야 한다(레포 안에 새 `__pycache__` 없음).
- 합계가 앞보다 10% 이상 줄었으면(`뒤 ≤ 0.9 × 앞`) Step 4 로. 아니면 `git checkout HEAD -- shared/tests/test_docreview_state.sh shared/tests/test_docreview_route.sh shared/tests/test_docreview_advice.sh` 로 되돌리고 `git diff HEAD --stat` 빈 출력을 본 뒤 커밋 없이 끝낸다.
- 어느 쪽이든 앞 · 뒤 합계와 각 실행 직전의 다른 스위트 수를 담당자 보고에 싣는다. `test_docreview_mutations.sh` 의 48행은 그대로다.

- [ ] **Step 4: 커밋(넣을 때만)**

```bash
git add shared/tests/test_docreview_state.sh shared/tests/test_docreview_route.sh shared/tests/test_docreview_advice.sh
git commit -m "test(shared): 문서 리뷰 행동 락 셋이 바이트코드를 임시 폴더에 둔다 (E1)"
```

---

### Task 10: 「뒤」 바퀴와 보고

AC11 · AC12 · AC13 · AC29 다. 코드를 고치지 않는다.

**Files:** 없음(기록은 TMPDIR)

- [ ] **Step 1: 빈 때를 기다린다(AC29)**

```bash
T=<TMPDIR 절대 경로>
python3 tools/suite/suite_peers.py --pid $$ > "$T/after.peers-before-wait"
python3 tools/suite/suite_peers.py --pid $$ --wait 1800 > "$T/after.wait"; echo "rc=$?" >> "$T/after.wait"
```

rc 1(30분이 지나도 0 이 아니다)이면 그대로 Step 2 로 가고, 보고에 「겹친 채 돌았다」 를 적는다 — 사용자에게 묻지 않는다.

- [ ] **Step 2: 잠금 아래 한 바퀴를 돈다**

과제 5 Step 2 와 같은 명령에서 파일 이름만 `timing-after.tsv` · `after.out` 으로.

- [ ] **Step 3: 숫자를 뽑는다(AC12)**

과제 5 Step 3 의 두 줄을 `timing-after.tsv` 에 돈다. 「앞」 과 「뒤」 를 나란히 둔 표를 담당자 보고에 싣는다: 합계 · 종류별 합 · 가장 느린 스물 · 시작과 끝의 다른 스위트 수 · 겹친 대상 줄의 초 합 · 겹치지 않은 바퀴인지. 「뒤」 줄에는 기다리기 전 다른 스위트 수 · 기다린 초(`after.wait`) · 상한을 넘겼는지를 더한다.

- [ ] **Step 4: 실패 이름 집합을 견준다(AC13)**

```bash
grep '^FAILED ' "$T/after.out" | LC_ALL=C sort > "$T/after.failed"
diff "$T/before.failed" "$T/after.failed"
```

허용되는 차이는 하나다 — 「앞」 의 `FAILED plugins/quality-gates/tests/test_codex_backward_compat.sh: 예상 밖 실패 → <이름>(미등재)` 줄이 「뒤」 에서 그 괄호 속 테스트 자신의 `FAILED` 줄로 나온 것. 그 밖에 갈린 이름이 있으면 갈린 대상만 잠금 아래 한 번 다시 돈다(K19, 같은 잠금 명령의 `--` 뒤를 그 명령으로). 다시 돌려도 「뒤」 에만 있는 실패가 남으면 **멈추고** 보고한다(그 이름 · 두 바퀴의 출력 줄 · 다시 돈 출력).

- [ ] **Step 5: 바뀌지 않은 파일을 본다(AC11)**

과제 1 Step 2 의 명령을 다시 돌려 여섯 해시가 같은지 보고, `git diff --stat <과제 1 HEAD> HEAD -- plugins/spec-distill/` 가 빈 출력인지 본다.

- [ ] **Step 6: 담당자 보고에 싣는다**

과제 1 의 해시 · 과제 2 Step 5 의 관측 · 과제 4 Step 5 의 견줌 · 과제 5 와 이 과제의 표 · 과제 6–9 의 앞뒤 시간과 변이 결과 · AC13 견줌 결과. 기록 파일 네 개(`timing-before.tsv` · `timing-after.tsv` · `before.out` · `after.out`)의 절대 경로도 싣는다 — 지휘자가 기준선을 적을 때 읽는다(AC21 은 지휘자 몫).

---

### Task 11: PR 본문 초안

AC22 다. PR 을 만들고 push 하는 것은 지휘자의 지시를 따른다 — 이 과제는 본문 파일만 쓴다.

**Files:** 없음(`<TMPDIR>/pr-body.md`)

- [ ] **Step 1: 본문을 쓴다**

한국어로, 아래 절과 줄을 담는다.

- 요약 — 시간 기록(변수 · 줄 꼴 · `suite_peers.py`) · 고친 느린 테스트(과제 9 를 넣었는지 포함)와 앞뒤 시간.
- 「판을 올리지 않았다 — 바뀐 것은 `tools/` 와 테스트 폴더 · 원장 머리말뿐이라 설치본에 실리지 않는다」(설계 Constraints · CLAUDE.md 판 올림 규칙).
- 「지휘 로드맵의 느린 넷(`test_human_gate.sh` · `test_human_gate_e2e.sh` · `test_team_status.sh` · `test_roadmap_status.sh`)은 건드리지 않았다」 한 줄(설계 §5).
- `## 지휘 로드맵에 알림` — 스위트가 겹쳐 도는 원인은 스위트 잠금이 로드맵마다 따로라는 것(RC4)이고, 이번에 잰 두 바퀴의 겹침(시작 · 끝의 다른 스위트 수 · 겹친 대상 줄의 초 합)을 과제 10 의 표에서 옮긴다. 잠금을 합치는 일은 이 에픽이 하지 않는다(설계 미룸).
- 계획의 판단 가운데 사람에게 보이는 것(K5 의 `?` · K7 의 `--wait` · K13 의 원장 판정 · K20).
- `## 기준선` 절은 쓰지 않는다 — 지휘자가 대조 뒤에 적는다(AC21).

- [ ] **Step 2: 보고에 경로를 싣는다**

본문 파일 경로를 담당자 보고에 싣는다.

---

## 실행 방식의 마지막 전체 리뷰

고른 실행 방식의 마지막 전체 리뷰(subagent-driven 의 브랜치 전체 리뷰 · native 의 마지막 리뷰)의 리뷰어에게 아래를 그대로 싣는다.

- 설계문서 `## Acceptance Criteria` 의 AC 목록 원문과 이 계획의 `## AC 가르기` 표 · `## 계획의 판단` 표.
- 요청: 계획 1 몫 AC(`AC1~AC13 · AC22 · AC27 · AC29`)마다 한 줄씩 `AC<n>: <구현됨|미룸|빠짐> — <근거(파일:줄 · 테스트 이름 · 명령 결과 · 담당자 보고의 자리)>` 꼴로 보고하라. AC10 은 과제 9 가 넣지 않았어도 잰 두 숫자가 보고에 있으면 `구현됨` 이다. AC12 · AC13 · AC29 는 담당자 보고의 숫자로 판정한다. AC9 의 「측정 불가」 는 K20 으로 읽는다.
- 요청: 설계문서 `## 있는 것 검토` 가 고른 것을 실제로 썼는지, 같은 것을 다시 만들지 않았는지 줄마다 답하라 — 시간 기록이 `run-all.sh` · `run_unittest_dir.py` 안에 들어가고 바깥 관찰기(프로세스 표를 주기로 읽는 스크립트)를 두지 않았는가 · 기록을 읽는 보고 스크립트를 만들지 않았는가 · 스위트 안의 스위트가 원장(`codex-blessed-red.txt`)과 지문 대조를 그대로 쓰는가 · 공유 테스트 고르기(`shared/test-selection/`)를 쓰지 않았는가 · 공유 스위트 잠금(`suite_lock.py`)을 그대로 쓰고 고치지 않았는가 · `merge_check.py` 를 고치지 않았는가. 새 파일 `suite_peers.py` 가 있는 것과 겹치지 않는지도 답하라(K1).
- 끝에서 끝 흐름 셋을 따로 물어라 — 각 이음매의 종료 코드 소비와 상태 가정: ① 잠금 스크립트 → `bash -c` → `run-all.sh`(변수 읽고 뺌) → python 러너(명시로 받고 뺌) → 테스트(변수 없음) → 기록 파일 ② 대조(`merge_check.py` 의 `compare_command`)가 변수를 물린 채 기준 사본 · 합친 사본을 차례로 돌 때 한 파일에 시작 줄 둘이 꼭대기 경로로 갈리는가 ③ `suite_peers.py --wait` 의 종료 코드를 담당자 · 지휘자가 어떻게 읽나 · `?` 가 0 으로 읽히는 자리가 없는가.
- 이 계획이 쓴 테스트 코드(과제 2–4 의 `test_suite_timing.py`)와 계획이 정한 판정(과제 6 의 K13 · 과제 8 의 K15)은 계획이 정한 것이라는 표시를 붙여, 덜 보지 말고 같은 눈으로 보라고 적는다. 고친 기존 테스트 넷에서 단언이 지워지거나 느슨해지지 않았는지 `git diff <과제 1 HEAD> -- plugins/quality-gates/tests shared/tests` 로 보라고 적는다 — 과제 6 이 걷은 제외 목록 알람 · 실행 수 바닥은 설계 §3 이 걷으라고 한 것이다.

리뷰 보고는 git 이 추적하지 않는 파일에 적는다 — 지휘자가 준 TMPDIR 의 `e1-plan1-ac-report.md`(쓸 수 없으면 이 worktree 의 `.claude/tmp/<담당자 이름>/e1-plan1-ac-report.md` — `git check-ignore -q` 로 확인). 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올린다 — 올릴 행을 보고에 적고 지휘자가 올린다. PR 을 만들기 전에

`python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.25.0"/scripts/check_bundle_coverage.py --impl /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/suite-time-cut/docs/superpowers/specs/2026-11-21-suite-time-cut-design.md <보고 파일 경로> --acs "AC1~AC13 · AC22 · AC27 · AC29"`

을 돌려 경고를 사용자에게 보인다.
