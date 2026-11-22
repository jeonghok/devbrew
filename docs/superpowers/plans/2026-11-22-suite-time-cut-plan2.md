# 스위트 시간 줄이기 — 계획 2(대조를 한 바퀴로 · 계획 2 에 더한 일) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 머지 전 대조가 합친 사본을 먼저 돌고, 합친 쪽이 깨끗하면 기준 사본을 돌지 않으며, 실패가 있으면 그 실패가 속한 대상만 기준 사본에서 다시 돌게 한다 — 새 실패와 원래 실패의 판정은 지금과 같다. 함께 계획 1 이 남긴 다섯 일(python 모듈별 시간의 정리 시간 귀속 · 품질 게이트의 제안 · 대조의 임시 폴더 자리 · 구현 담당자가 미룬 것 · 지휘 절차서의 예약)을 한다.

**Architecture:** `tools/suite/run-all.sh` 가 환경 변수 `SUITE_ONLY_FAILED_FILE`(절대 경로)을 읽어 목록에 나온 대상만 돌고, 읽지 못하면 전부 돈다 — 두 러너는 그 변수를 테스트에게 물려주지 않는다. `merge_check.py` 의 `compare_command` 는 합친 사본을 먼저 돌고, 실패 이름이 있으면 그 이름을 목록 파일로 써서 그 변수로 건넨 채 기준 사본을 돈다 — 목록을 모르는 명령은 전부 돌아 판정이 같다. 대조가 테스트에 주는 임시 폴더는 git 작업 트리 밖에 만든다. 나머지는 각자 파일 안의 작은 고침이다.

**Tech Stack:** bash(macOS 3.2 — 연관 배열 없음) · Python 3.9.6(레포의 `python3`) · unittest · git · `ps`(macOS) · `shared/tests/assert.sh`.

**Spec:** `docs/superpowers/specs/2026-11-21-suite-time-cut-design.md` — 그 문서가 「계획 2」 라 부르는 몫(§4 · §5 의 계획 2 줄 · `## 계획 2 에 더한 일`)이다. 계획 3(§6)은 열지 않는다(결정 기록 B4) — 느린 넷 · python 묶음 · 문서 리뷰 엔진 케이스는 이 계획에 없다.

## AC 가르기

| AC · 일 | 과제 |
|---|---|
| AC14 · AC15 · AC16 · AC17 · AC18 | 과제 6(대조) — AC15 의 「목록을 아는 명령」 은 과제 5 의 러너 |
| AC19 | 과제 5(러너) · 과제 6(끝에서 끝) |
| AC20 | 과제 9 |
| AC24 | 과제 5(러너가 버리고 전부 돈다 · 없는 대상 줄 건너뛰기) · 과제 6(대조 판정) |
| AC28 | 과제 5 |
| AC30 | 과제 5(일부만 돌았다는 알림) · 과제 6(대조가 변수를 빼고 돈다) |
| 더한 일 1 — 정리 시간 귀속(AC5) | 과제 2 |
| 더한 일 2 — 품질 게이트의 제안 열다섯 | 과제 2(`run_unittest_dir.py` 넷) · 과제 3(`suite_peers.py` 둘 · `test_suite_timing.py` 둘) · 과제 4(`run-all.sh` 넷 · `test_suite_timing.py:430`) · 과제 8(`test_codex_backward_compat.sh:108` · `test_copy_of_contract.sh:861`) |
| 더한 일 3 — 대조의 임시 폴더 | 과제 7 |
| 더한 일 4 — 구현 담당자가 미룬 것 | 과제 2(모듈 키 가장자리) · 과제 3(`suite_peers.py` 손질) |
| 더한 일 5 — 지휘 절차서의 예약 | 과제 9 · 과제 10(PR 본문) |
| Deferred 455e8a2d#r2.1 · f8cceba6#r3.1 | 과제 1(두 관측) · 과제 10(「아직 재지 못했다」) |
| Deferred aee216b2#r2.1 | 과제 5(러너가 두 변수를 뺀다) · 과제 6(대조는 기준 사본 부분 실행에만 건넨다) |
| AC23 | 지휘자 기록 — 이 계획은 과제 10 의 PR 본문에 「부분 실행의 시간은 아직 재지 못했다」 만 적는다 |

대조 스크립트에 주는 목록: `AC14~AC20 · AC24 · AC28 · AC30`.

## Global Constraints

- **값이 없으면 지금과 같다.** `SUITE_ONLY_FAILED_FILE` 이 없거나 빈 값이면 `run-all.sh` 의 표준 출력 · 표준 오류 · 종료 코드가 지금과 글자까지 같다. 목록을 받아도 표준 출력의 꼴과 종료 코드의 뜻은 같다(설계 §4 · AC30).
- **`run-all.sh` 의 찾기 줄은 바꾸지 않는다.** 78행 `done < <(find shared/tests plugins/*/tests -name 'test_*.sh' -not -path '*/spike/*' -not -path '*/fixtures/*' | LC_ALL=C sort)` 는 `shared/tests/test_shell_tests_executable.sh` 11행이 정규식으로 꺼내 쓴다 — 그 줄의 글자를 그대로 둔다. 거르기는 반복문 몸통 안에서 한다.
- **표준 오류 알림은 실패 줄 꼴로 시작하지 않는다.** 대조는 표준 출력과 오류를 합쳐 `.devbrew.md` 의 `test_failure_pattern: "^FAILED (.+)$"` 로 읽는다. 러너 알림은 `run-all: ` · `run_unittest_dir: ` · `suite_peers: ` 로 시작한다.
- **두 변수는 테스트에게 물려주지 않는다.** `run-all.sh` 와 `run_unittest_dir.py` 는 `SUITE_TIMING_FILE` · `SUITE_ONLY_FAILED_FILE` 을 읽은 뒤 테스트를 띄우는 환경에서 뺀다(설계 「러너의 두 변수는 테스트에게 물려주지 않는다」).
- **대조가 그 변수를 건네는 자리는 하나다.** 기준 사본의 부분 실행뿐이다. 합친 사본을 돌 때와 기준 사본을 전부 돌 때는 호출한 쪽 환경의 `SUITE_ONLY_FAILED_FILE` 을 빼고 돈다(설계 §4). `SUITE_TIMING_FILE` 은 지금처럼 물려 돈다(§1).
- **새 설정 키를 만들지 않는다. 탐지 경로(`compare_detected`)의 한 바퀴 구조는 건드리지 않는다**(설계 §4).
- **bash 3.2.** 연관 배열 · `${var,,}` 없음. `$var` 바로 뒤에 한글 · 「」 · `(` 같은 비ASCII 글자가 오면 `${var}` 로 감싼다. `$( )` 안에 here-doc 을 두지 않는다. 새 셸 코드는 `/bin/bash` 로 돌려 본다. Bash 도구의 셸은 zsh 다 — 파이프의 종료 코드는 `bash -c` 안에서 잡는다.
- **Python 3.9 문법만.** 파일 읽기 · 쓰기에 `encoding="utf-8"` 를 적는다(`plugins/quality-gates/tests/test_utf8_explicit.py` 가 `plugins/*/scripts/*.py` 의 `open(` 을 글자로 본다). `plugins/**/*.py` 에 `"python3"` 리터럴을 쓰지 않는다(`shared/tests/test_python_floor.sh`) — `sys.executable` 을 쓴다. 긴 한글 문자열은 인접 문자열로 나눈다.
- **레포 락.** 같은 블록 20줄(200자 이상)을 `plugins/*` · `shared/*` 두 파일에 두지 않는다(`shared/tests/test_no_new_duplication.sh`). CHANGELOG 새 머리는 바로 다음 판이고 `plugin.json` 과 같다(`shared/tests/test_changelog_integrity.sh`). 새 셸 테스트 파일은 만들지 않는다 — 만들게 되면 `chmod +x` 뒤 `git ls-files -s` 로 100755 를 확인한다.
- **테스트를 고치는 일은 리뷰어 프로필을 고치는 일만큼 조심한다(CLAUDE.md).** 고친 기존 테스트마다 고치기 전에 잡던 것을 고친 뒤에도 잡는지 사본에 변이를 넣어 한 번 보인다. 변이는 커밋한 뒤 `git clone --no-local <이 worktree> <임시 폴더>` 사본에서만 넣고, `PYTHONDONTWRITEBYTECODE=1` 로 돌린다.
- **고치지 않는 파일.** `plugins/plugin-audit/tests/` 아래 전부(E4 의 예약 — `test_run_own_tests.py` 포함). `plugins/quality-gates/tests/` 에서는 `test_codex_backward_compat.sh` 만. `plugins/spec-distill/references/conducting.md` 는 142행의 스위트 대조 설명 한 자리만. 느린 넷 · `test_finish_pr_merge.sh` · `test_control_plane.sh` 는 한 글자도 바꾸지 않는다.
- **전체 스위트는 돌리지 않는다.** 지휘자의 머지 전 대조가 돈다. 과제 1 의 관측처럼 무거운 대상을 돌릴 때는 공유 잠금 아래에서만:
  `python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.25.0"/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-20-test-method-rework-brief/files/suite-lock --owner <담당자 이름> --wait <초> -- bash -c '<명령>'`
  (지휘자의 대조와 같은 잠금이다). 못 잡으면 같은 스크립트의 `show --lock <같은 경로>` 출력(주인 · 잡은 시각)을 보고하고 멈춘다. 셸 호출 상한(10분)을 넘을 실행은 Bash 백그라운드로 띄우고 끝 알림을 기다린다. 하위 agent 에게 보내는 글에도 이 줄과 경로를 그대로 싣는다. 파일 하나짜리 테스트는 잠금 없이 돌린다.
- **판 번호.** spec-distill 의 판은 「머지 직전 기본 브랜치의 판 위의 다음 minor」 다 — 숫자를 박지 않는다. 계획을 쓸 때 기본 브랜치는 8.30.0 이다. 합치기 전에 `git diff origin/main -- plugins/spec-distill/.claude-plugin/plugin.json` 로 기준 쪽 판을 직접 견준다(같은 판으로 올린 두 PR 은 충돌 없이 합쳐진다).
- **기록 · 임시 파일 자리.** 담당자의 임시 파일 · 보고는 지휘자가 준 TMPDIR 에 셸로 쓴다(Write · Edit 도구는 그 폴더에 못 쓴다). 셸로도 막히면 이 worktree 의 `.claude/tmp/<담당자 이름>/` 을 쓰고 `git check-ignore -q` 로 무시되는지 먼저 본다. 공유 임시 폴더를 glob 으로 지우지 않는다.
- **커밋.** Conventional Commits, 설명은 한국어. pathspec 으로 그 과제의 파일만. 끝 줄은 지휘자가 준 공동 작성자 줄. `git stash` · reset · rebase · force 를 쓰지 않는다. push 는 지휘자 지시대로.

## Review Focus

설계가 뜻하지만 어느 수용 기준도 이름 대지 않는 입력이다. 줄마다 그 코드를 가진 과제에 테스트가 있다.

1. **실패 목록에 같은 대상의 이름이 여럿이다**(python 폴더 하나에 실패 둘). 그 대상은 한 번만 돌고 「대상 N개」 의 N 에도 한 번 센다(과제 5 `test_duplicate_names_same_target_once`).
2. **호출한 쪽에 빈 값 `SUITE_ONLY_FAILED_FILE=` 이 남아 있다.** 없는 것과 같다 — 전부 돌고 알림이 없다(과제 5 `test_empty_value_same_as_absent`).
3. **목록 파일에 빈 줄이 있거나 줄이 하나도 없다.** 빈 줄은 건너뛴다. 읽을 줄이 하나도 없으면 「일부만(0개)」 이 아니라 전부 돈다(과제 5 `test_blank_lines_skipped_and_empty_list_runs_all`).
4. **합친 사본의 테스트 명령이 실행되지 않는다(rc 127).** 기준 사본을 돌리지 않고 검사 불가(rc 3)로 멈춘다(과제 6 장면 17).
5. **호출한 쪽 `TMPDIR` 이 git 작업 트리 안이다**(지휘자의 자원 폴더가 그렇다). 대조가 테스트에 주는 임시 폴더는 그래도 git 밖이다(과제 7 장면 18).

---

## 계획의 판단

설계가 계획에 맡겼거나 정하지 않아 이 계획이 정한 것이다. ✎ 는 「설계에 없던 결정」 — 사람에게 보이는 글 · 동작에 닿거나 설계의 글자와 다르게 읽힐 수 있어 지휘자에게 돌려보내는 자리다(이 계획은 설계문서를 고치지 않는다).

| # | 자리 | 정한 것 | 이유 | 다른 길 |
|---|---|---|---|---|
| L1 | 과제 1 의 두 관측 | 이 worktree 에서(과제 1 시점의 코드가 기본 브랜치와 같은지 먼저 본다) 계획 1 대조 2회차의 「양쪽 다 있는 실패」 가 속한 대상 일곱을 러너와 같은 명령으로 혼자 돌려, 이름 집합을 그 대조의 이름과 견준다. `TMPDIR` 을 git 안 · 밖 두 번 준다. 혼자 돈 이름이 git 안 실행에서 전체 실행과 다르면 멈춘다 | 기준 사본의 부분 실행이 바로 「그 대상만 혼자」 다(Deferred f8cceba6#r3.1). git 안 실행이 지금 대조의 조건이다 | 일회용 worktree 를 따로 만든다 |
| L2 | 정리 시간 귀속(더한 일 1) | 테스트 몸통(`startTest` → `stopTest`)은 그 테스트의 모듈에, 정리(`_tearDownPreviousClass` · `_handleModuleTearDown`)는 **앞 테스트의 모듈**에, 준비(`_handleClassSetUp` · `_handleModuleFixture` 에서 안에 든 정리를 뺀 몫)는 **이번 테스트의 모듈**에 더한다. `unittest.TestSuite` 를 넓힌 `_TimedSuite` 를 기록 변수가 있을 때만 로더의 `suiteClass` 로 쓴다 | 정리는 다음 테스트 앞 · 바퀴 끝에 돌아 `stopTest` 사이 시간으로는 모듈을 가를 수 없다. 넷은 레포의 `python3`(3.9.6)에 있는 `unittest.suite.TestSuite` 의 내부 메서드다(계획을 쓸 때 확인 — `_handleModuleFixture` 가 안에서 `_handleModuleTearDown` 을 부른다) — 변수가 없으면 쓰지 않으므로 바뀌어도 기록 바퀴만 영향을 받는다 | 모듈마다 스위트를 따로 돌린다(픽스처 차례가 바뀐다) |
| L3 | 모듈 키 한 규칙 | `__file__` 이 있으면 `relpath(__file__, base)`, 없거나 임포트에서 죽은 모듈이면 `relpath(join(abspath(start), *점_이름.split(".")) + ".py", base)`. `abspath(start)` 는 테스트가 돌기 전에 한 번 잰다 | 품질 게이트 `run_unittest_dir.py:18` · 미룬 것(중첩 패키지 · `__file__` 없음) — 두 키의 꼴이 같아진다 | 지금 꼴 그대로 |
| L4 | 기록 쓰기 | 줄 전체를 먼저 만들고 utf-8 로 바꾼 뒤 한 번에 덧붙인다 — 바꾸기가 실패하면 한 줄도 쓰지 않고 「기록하지 않는다」 | `:46` — 알림이 사실과 같다 | 줄마다 쓰고 알림 글을 바꾼다 |
| L5 | 결과 객체 설정 | `timed_result_class(start_abs, base) -> type` 이 설정을 닫아 넣은 하위 클래스를 돌려준다. `module_secs` 는 `__init__` 에서 만든다 | `:70` — 프로세스 전역 상태가 없고 `suite.run(result)` 로도 쓴다 | 클래스 속성 |
| L6 | 러너 판별(`:42`) | 플래그 뒤 첫 토큰이 마지막 토큰이 아닌데 `.sh` 로 끝나면 그 토큰이 실행되는 스크립트다 — 러너가 아니다. 그 밖은 지금처럼 나머지 전체의 마지막 경로 성분이 `run-all.sh` 인지 본다(빈칸 경로는 여전히 센다) | 러너는 인자를 받지 않는다. 빈칸 경로와 「다른 스크립트의 인자」 를 명령줄 글자만으로 가르는 가장 작은 규칙이다 | 파일이 있는지 본다(프로세스의 현재 폴더를 모른다) |
| L7 ✎ | `--wait` 와 읽지 못한 표(`:116`) | 표를 읽지 못하면 기다리지 않고 바로 `waited=<초>\tpeers=?` 와 종료 코드 3 | 기다려도 표는 읽히지 않는다. 계획 1 의 K7(「`?` 는 기다림을 잇는다」)을 바꾼다 — 설계 §2 「0 이 될 때까지 기다린다」 의 대상이 아니던 경우라 사람에게 보이는 종료 코드가 하나 는다 | 상한까지 기다린다 |
| L8 | `--interval` | 0 이하면 argparse 오류(종료 코드 2) | 미룬 것 — 0 이면 바쁜 반복 | 0 을 15 로 바꾼다 |
| L9 | 실제 표 시험의 노출(`:177` · `:199`) | 가짜 러너는 고정 `sleep` 대신 「풀어 줌 파일이 생길 때까지(상한 10초)」 기다리고, 테스트는 목록을 읽자마자 그 파일을 만든다. 자기 · 조상 · 자식 시험에 「다른 가짜 러너 하나는 목록에 있다」 양성 대조와 `--list` 종료 코드 0 을 더한다 | 다른 작업 폴더의 기록에 스치는 시간이 목록 한 번 읽는 동안으로 준다. 빈 목록으로도 통과하던 시험에 이빨이 생긴다 | 가짜 러너 이름을 바꾸는 변수 |
| L10 ✎ | 다른 스위트 수를 세지 못한 까닭(`run-all.sh:44`) | 기록 변수가 있고 세기가 실패하면 바퀴마다 한 번 표준 오류에 `run-all: 다른 스위트 수를 세지 못했다 — <까닭>` 한 줄. 까닭은 `suite_peers.py --stamp` 가 표준 오류에 낸 첫 줄, 없으면 `종료 코드 <n>` · `출력이 없다`. `suite_peers.py` 는 표를 읽지 못하면 표준 오류에 `suite_peers: 프로세스 표를 읽지 못했다 — <까닭>` 을 낸다 | 기록에 `?` 만 남고 터미널에는 까닭이 없었다. 기록 변수가 있을 때만이라 AC1 은 그대로다. 계획 1 의 시험 둘(`check_stamp_unavailable`)의 기대 표준 오류가 빈 글에서 이 한 줄로 바뀐다 | 알리지 않는다 |
| L11 | python 러너의 알림(`:82`) | 기록 변수가 있을 때, python 러너 출력에서 `run_unittest_dir: ` 로 시작하는 줄을 표준 오류로 옮긴다 | 지금은 `FAIL:` · `ERROR:` 만 남기고 버린다. 변수가 없을 때는 옮기지 않아 AC1 이 그대로다 | 러너의 표준 오류를 따로 받는다(출력 차례가 바뀐다) |
| L12 | 쓰기 실패 알림은 한 번(`:94` · `:101`) | 「이미 알렸다」 를 `$LIST.warned` 파일로 둔다(`{ … } \| sort` 하위 셸을 넘는다). trap 이 함께 지운다. 시험은 「정확히 한 줄」 로 조인다 | AC4 「알림 한 줄」 | 하위 셸을 없앤다(찾기 줄 · 출력 정렬이 바뀐다) |
| L13 | 목록 읽기(§4 · AC19 · AC24) | 빈 값은 없는 것과 같다. 절대 경로가 아니거나 · 읽지 못하거나 · 읽을 줄(빈 줄 뺀)이 0개거나 · `<대상>: ` 앞부분이 아래 꼴이 아닌 줄이 하나라도 있으면 목록을 버리고 전부 돈다. 꼴: 셸 `shared/tests/…test_*.sh` · `plugins/<p>/tests/…test_*.sh`, python `shared/tests` · `plugins/<p>/tests` · `tools/<d>`, node `plugins/<p>/tests/…*.test.mjs`(`<p>` · `<d>` 에 `/` 없음, `…` 에는 있어도 된다). 꼴은 맞는데 이 사본에 없는 대상은 그 줄만 건너뛴다. 같은 대상은 한 번 | 「한 줄이라도 읽지 못하면 버린다」 의 「읽는다」 를 러너가 내는 대상 꼴로 정했다. 빈 목록 · 상대 경로를 전부 도는 쪽으로 떨어뜨린 것은 판정이 지금과 같은 쪽이다 | 빈 목록이면 아무것도 돌지 않는다 |
| L14 | 러너 알림 글 | 일부만: `run-all: 일부만 돌았다 — 대상 <N>개(SUITE_ONLY_FAILED_FILE)` — N 은 고른 대상 가운데 이 사본에 있는 것의 수, 돌기 전에 낸다. 버림: `run-all: 실패 목록을 읽지 못해 전부 돈다 — <까닭>: <값>`, 까닭은 `절대 경로가 아니다` · `파일을 읽지 못했다` · `읽을 줄이 없다` · `대상 경로 꼴이 아닌 줄이 있다`(값은 그 줄) | 설계 §4 「일부만 돌았다 — 대상 몇 개」 · 「그 사실을 한 줄 알린다」 | 끝에 센다(하위 셸을 넘어야 한다) |
| L15 | 새 테스트 파일 | `tools/suite/test_suite_only_failed.py`. 임시 레포 도우미(`make_repo` · `run_all` · `lines` · `target_lines` · `out_file`)를 `test_suite_timing.py` 의 `RepoMixin`(TestCase 가 아닌 클래스)으로 옮겨 두 파일이 쓴다 | 새 책임은 새 모듈로. TestCase 를 임포트하면 그 파일의 시험이 두 번 돈다 — 섞는 클래스만 임포트한다 | `test_suite_timing.py` 에 더한다 |
| L16 | 「고쳐짐」 줄(AC18) | 기준 사본을 돌지 않았거나 **목록을 건네 돌았으면** `기본 브랜치에만 있는 실패(고쳐짐) — 재지 않았다(<사유>)`. 이름을 뽑지 못해 기준 사본을 전부 돈 경우(AC17)만 지금처럼 센다 | 목록을 모르는 명령은 실제로 전부 돌지만, 대조는 러너의 말을 읽지 않고는 그것을 알 수 없다 — 「0 개」 를 거짓으로 내지 않는 쪽이다. 판정과 종료 코드는 그 줄을 쓰지 않는다(지금도) | 러너의 「일부만 돌았다」 줄을 읽어 가른다(러너 글에 묶인다) |
| L17 | 대조의 알림 줄 | `기준 사본은 돌리지 않았다 — 합친 사본이 종료 코드 0 이고 실패 이름이 없다` · `기준 사본은 합친 사본의 실패 이름 <n>개를 목록(SUITE_ONLY_FAILED_FILE)으로 건네 돌렸다 — 목록을 아는 명령은 그 대상만 돈다` · `기준 사본은 전부 돌렸다 — 합친 사본이 실패했으나 이름을 뽑지 못했다` | AC14 의 「기준 사본은 돌리지 않았다」 와 나머지 두 길을 사람이 가른다 | — |
| L18 | 목록 파일 | 실행 폴더의 `only-failed.txt` — 합친 쪽 이름(경로 자리표시를 바꾼 뒤)을 정렬해 한 줄에 하나, utf-8 | 실행 폴더는 대조가 끝나면 지워진다 | 임시 폴더 |
| L19 ✎ | 대조의 임시 폴더(더한 일 3) | 후보 `tempfile.gettempdir()` · `/tmp` · `/var/tmp` 차례로, 있는 폴더이고 쓸 수 있고 `git -C <후보> rev-parse --is-inside-work-tree` 가 `true` 가 아닌(`GIT_DIR` · `GIT_WORK_TREE` 를 뺀 환경) 첫 후보 아래에 사본마다 `tempfile.mkdtemp(prefix="merge-check-<base|merged>-")`. 대조가 끝나면 지운다. 후보가 없으면 지금 자리(실행 폴더 안)를 쓰고 `[spec-distill] git 작업 트리 밖 임시 폴더를 찾지 못해 실행 폴더 안을 쓴다 — 임시 폴더가 git 밖이라고 가정한 테스트가 다르게 돌 수 있다` 를 알린다. 탐지 경로의 단위 실행에도 같은 자리를 준다 | 지휘자의 TMPDIR 도 git 안이라 호출한 쪽 값만으로는 모자란다. 멈추지 않고 알리는 것이 graceful degradation 이다. §4 의 「탐지 경로는 건드리지 않는다」 는 한 바퀴 구조에 대한 말로 읽었다 — 임시 폴더는 두 경로가 같은 뜻이다 | 못 찾으면 검사 불가(rc 3) · 테스트 명령 경로에만 |
| L20 | 다시 돌리는 갈래 시험(`:108`) | `test_codex_backward_compat.sh` 에 넷째 확인을 둔다 — 임시 사본에 그 파일 자신과 가짜 테스트 · 가짜 원장을 두고 `CODEX_COMPAT_INNER=1` 로 셋째 확인만 돌려, 지문 일치(등재 둘 · 표준 입력을 먹는 테스트 포함) PASS · 지문 불일치 FAIL · 통과하는 등재 FAIL 을 본다. 안쪽 실행은 넷째 확인을 돌지 않는다. 단언 수는 셋에서 넷 | 원장이 0건이라 그 갈래가 스위트 어디에서도 돌지 않았다. 고칠 수 있는 테스트 파일이 이것 하나다(그 폴더의 다른 자리는 E4 예약) | 하지 않고 이유를 적는다 |
| L21 | 임포트 색인의 실패(`:861`) | 0 아닌 모든 종료 코드에서 그 자리 파싱으로 간다. 색인 만들기가 실패하면 색인을 비워 모든 후보가 그 자리 파싱으로 가게 한다 | 락이 조용히 약해지지 않는다 — 느려질 뿐이다 | 실패하면 락이 FAIL |
| L22 | 판 · 예약 | spec-distill minor. 로드맵 E1 예약 줄 편집은 로드맵 수정 PR #320 이 기본 브랜치에 머지된 뒤 기본 브랜치를 합치고 한다 — 아직이면 편집하지 않고 보고한다 | #320 이 같은 줄을 고친다 — 먼저 고치면 충돌한다 | 지금 고친다 |
| L23 | 확인 범위 | 구현 담당자는 전체 스위트를 돌지 않는다. 과제 10 이 바꾼 파일의 이름을 읽는 테스트를 도출해 하나씩 돈다 | 지휘자의 잠긴 대조가 전체를 판정한다(conductor-dispatch). 대조가 공유 잠금을 쥐고 있다 | 잠금 아래 전체 한 바퀴 |
| L24 ✎ | 설계 전제와 어긋날 수 있는 사실(보고만) | 계획 1 대조 1회차에서 plugin-audit 의 `test_default_helper_is_the_sibling_script_not_cwd` 는 기준 사본의 전체 바퀴에서 통과했는데, 같은 폴더를 혼자 돌린 두 번(옛 러너 · 새 러너, 합친 사본)은 모두 실패했다. 부분 실행이었다면 그 실패는 「새 실패」 가 아니라 「양쪽 다」 로 갈렸을 것이다 — §4 의 「부분이든 전부든 판정이 같다」 가 그 테스트에서는 서지 않았을 수 있다. 또 대조 두 번 모두 「양쪽 다 있는 실패」 가 9–10개라 합친 쪽이 깨끗한 때가 없고, 그중 둘이 python 폴더(특히 `plugins/spec-distill/tests` — 한 번 146–646초)라 기준 사본의 부분 실행이 생각보다 무겁다. 과제 1 이 다시 관측하고, 과제 7(임시 폴더를 git 밖으로)이 첫째의 알려진 원인을 없앤다 | 계획이 설계를 바꾸지 않는다 — 지휘자가 사용자에게 보일지 정한다 | — |

---

## 파일 표

| 파일 | 맡는 일 | 과제 |
|---|---|---|
| `tools/suite/run_unittest_dir.py` | 모듈별 시간의 귀속 · 모듈 키 · 기록 쓰기 · 두 변수 빼기 | 2 · 5 |
| `tools/suite/suite_peers.py` | 러너 판별 · `--wait` · `--interval` · 읽지 못한 까닭 | 3 · 4 |
| `tools/suite/run-all.sh` | 알림(까닭 · python 알림 · 한 번) · 실패 목록 읽기 | 4 · 5 |
| `tools/suite/test_suite_timing.py` | 기존 시험 손질 · `RepoMixin` | 2 · 3 · 4 · 5 |
| `tools/suite/test_suite_only_failed.py`(새) | 실패 목록 시험 | 5 |
| `plugins/spec-distill/scripts/merge_check.py` | 한 바퀴 대조 · 임시 폴더 자리 | 6 · 7 |
| `plugins/spec-distill/tests/test_merge_check.sh` | 장면 4 고침 · 장면 12–18 | 6 · 7 |
| `plugins/quality-gates/tests/test_codex_backward_compat.sh` | 넷째 확인 | 8 |
| `shared/tests/test_copy_of_contract.sh` | 색인 실패 길 | 8 |
| `plugins/spec-distill/.claude-plugin/plugin.json` · `CHANGELOG.md` | 판 | 9 |
| `plugins/spec-distill/references/conducting.md` | 142행 한 자리 | 9 |
| `docs/superpowers/roadmaps/2026-11-20-test-method-rework-brief/roadmap.md` | E1 예약 줄에 `conducting.md` | 9 |

---

### Task 1: 다시 확인과 두 관측

설계문서가 근거로 든 자리가 지금 코드에서도 그런지 보고(달라졌으면 **멈추고** 지휘자에게 보고한다 — 어느 줄 · 무엇이 · 어느 과제가 닿나), 설계가 이 과제에 맡긴 두 관측을 한다. 고치지 않는다.

**Files:** 없음(읽기 · 실행만)

- [ ] **Step 1: 근거 자리를 읽는다** — 레포 뿌리에서, 복합 명령은 스크립트 파일로 써서 `bash <파일>`.

```bash
grep -n 'b_rc, b_out = run_command\|m_rc, m_out = run_command' plugins/spec-distill/scripts/merge_check.py   # 212 · 213 — 기준 사본을 먼저 돈다
grep -n 'env=dict(os.environ, TMPDIR=str(tmp))' plugins/spec-distill/scripts/merge_check.py   # 201 — 환경을 물려 돈다
grep -n 'work / "tmp-base"\|"tmp-" + side' plugins/spec-distill/scripts/merge_check.py   # 212 · 216 · 286 · 340 — 임시 폴더가 실행 폴더 안
grep -n 'work = mdir / ("run-' plugins/spec-distill/scripts/merge_check.py   # 455 — 실행 폴더는 상태 루트(메인 레포 안) 아래
grep -n '기본 브랜치에만 있는 실패(고쳐짐)' plugins/spec-distill/scripts/merge_check.py plugins/spec-distill/tests/test_merge_check.sh   # 364 · 119
grep -n 'test_failure_pattern' .devbrew.md   # "^FAILED (.+)$"
grep -n '^unset SUITE_TIMING_FILE\|SUITE_ONLY_FAILED_FILE' tools/suite/run-all.sh tools/suite/run_unittest_dir.py   # run-all.sh:13 하나뿐
grep -n "done < <(find shared/tests" tools/suite/run-all.sh   # 78
grep -n -- '--stamp 2>/dev/null\|SUITE_TIMING_FILE="\$TIMING" python3' tools/suite/run-all.sh   # 45 · 63 · 99 · 81 · 88
grep -n 'def stopTest\|_TimedResult.start_dir = start\|_testMethodName + ".py"' tools/suite/run_unittest_dir.py   # 38 · 70 · 19
grep -n 'rest.rsplit("/", 1)\[-1\] == "run-all.sh"\|if waited >= a.wait\|"--interval"' tools/suite/suite_peers.py   # 42 · 116 · 94
grep -n 'sleep 5\|1 <= len(err_lines) <= 2\|rows = suite_peers.read_rows() or \[\]' tools/suite/test_suite_timing.py   # 182 · 599 · 57
grep -vcE '^[[:space:]]*(#|$)' plugins/quality-gates/tests/codex-blessed-red.txt   # 0
grep -n 'while read -r b listed _rest <&3' plugins/quality-gates/tests/test_codex_backward_compat.sh   # 116
grep -n '"\$rc" -eq 9\|IMPSCAN" --index' shared/tests/test_copy_of_contract.sh   # 861 · 847
grep -n '양방향으로 대조한다' plugins/spec-distill/references/conducting.md   # 142
git show origin/main:plugins/spec-distill/.claude-plugin/plugin.json | grep '"version"'   # 계획을 쓸 때 8.30.0
grep -n '^- 경로 예약: tools/suite/' docs/superpowers/roadmaps/2026-11-20-test-method-rework-brief/roadmap.md   # E1 줄 — conducting.md 없음
git diff --stat origin/main HEAD -- . ':!docs'   # 빈 출력 — 이 브랜치의 코드는 기본 브랜치와 같다
```

계획을 쓸 때(2026-11-22, 브랜치 끝 aafe7c3c) 모두 맞았다. 판 줄이 8.30.0 이 아니면 멈추지 않고 그 숫자를 보고에 적는다(과제 9 가 그 위의 다음 minor 를 쓴다).

- [ ] **Step 2: 관측 (1) — 대조 사본에서 늘 실패하는 테스트**

계획 1 의 대조 두 번의 출력에서 「양쪽 다 있는 실패」 를 읽어 교집합을 낸다.

```bash
D=/Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-20-test-method-rework-brief/files/report/E1
python3 -c 'import sys
def both(p):
    for l in open(p, encoding="utf-8"):
        if l.startswith("- 양쪽 다 있는 실패"):
            return set(x.strip() for x in l.split(": ", 1)[1].split(" · "))
    return set()
a, b = both(sys.argv[1]), both(sys.argv[2])
print(len(a), len(b), len(a & b)); print("\n".join(sorted(a & b)))' "$D/mc-1.out" "$D/mc-2.out"
```

Expected(계획을 쓸 때): `9 10 9` 와 이름 아홉 — 늘 실패하는 테스트가 있다. 그러면 합친 쪽이 깨끗한 때가 없어 대조는 늘 기준 사본을 (부분으로) 다시 돈다. 그 사실과 대상 일곱(`plugins/plugin-audit/tests` · `plugins/quality-gates/tests/test_findings_parser.sh` · `plugins/spec-distill/tests/test_detect_codex.sh` · `test_epic_conductor_skill.sh` · `test_finish_commit_roadmap.sh` · `plugins/spec-distill/tests` · `shared/tests/test_invocation_surface.sh`)을 보고에 싣는다.

- [ ] **Step 3: 관측 (2) — 실패하는 대상을 혼자 돌린 결과와 전체 속 결과**

대상 일곱을 러너와 같은 명령으로 혼자 돌려 `FAILED <대상>: <이름>` 꼴의 이름 집합을 만든다 — 셸 파일은 `bash <파일> 2>&1 </dev/null | sed -nE 's/^ *(✗|FAIL:) //p'`, python 폴더는 `python3 tools/suite/run_unittest_dir.py <폴더> 2>&1 | sed -nE '/^(FAIL|ERROR): /p'`, 앞에 `<대상>: ` 를 붙인다. 이것을 스크립트 파일 하나(`<TMPDIR>/observe.sh <TMPDIR 값> <출력 파일>`)로 써서 공유 잠금 아래 두 번 돈다(Global Constraints 의 잠금 줄 — `--wait 7200`, 백그라운드):

1. `TMPDIR` = 이 worktree 의 `.claude/tmp/<담당자 이름>/tmp-in`(git 작업 트리 안 — 지금 대조의 조건. `git check-ignore -q` 로 무시되는지 먼저 본다)
2. `TMPDIR` = `mktemp -d /tmp/e1-obs.XXXXXX`(git 밖 — 과제 7 의 조건. 끝나면 그 폴더 하나만 지운다. 만들 수 없으면 「재지 못했다」 로 적는다)

두 결과를 Step 2 의 대조 2회차 이름 열 개와 견준 표(대상 · 전체 속 · 혼자(git 안) · 혼자(git 밖))를 보고에 싣는다.
**멈출 조건:** 혼자(git 안)의 이름 집합이 전체 속과 다른 대상이 있으면 멈추고 보고한다 — 부분 실행의 판정이 전부 실행과 같다는 설계 §4 의 전제가 그 대상에서 서지 않는다(계획의 판단 L24). git 밖 실행에서만 다른 것(예: plugin-audit 테스트가 통과)은 멈추지 않고 적는다 — 과제 7 이 바꾸는 조건이다.

---

### Task 2: python 모듈별 시간 — 정리 시간 귀속과 키

더한 일 1(AC5)과 품질 게이트의 `run_unittest_dir.py:18` · `:38` · `:46` · `:70`, 미룬 것(중첩 패키지의 임포트 실패 키 · `__file__` 없는 모듈)이다. 사용자가 정한 첫 구현 과제다(결정 기록 B7).

**Files:**
- Modify: `tools/suite/run_unittest_dir.py`
- Test: `tools/suite/test_suite_timing.py`(`UnittestDirTimingTests`)

**Interfaces:**
- Consumes: 없음
- Produces: `module_key(modname: str, start_abs: str, base: str) -> str` · `test_module_key(test, start_abs: str, base: str) -> str`(`_FailedTest` 를 가른다) · `timed_result_class(start_abs: str, base: str) -> type`(`unittest.TextTestResult` 하위, 인스턴스에 `module_secs: dict` 와 `charge(key: str, secs: float) -> None`) · `class _TimedSuite(unittest.TestSuite)` · `write_timing(path: str, module_secs: dict) -> None`. 줄 꼴(`<초 %.3f>\tpymod\t<키>`)과 알림 글은 그대로다.

- [ ] **Step 1: 실패하는 시험을 쓴다** — 지금 파일의 `write` · `run_runner` · `timing_lines` 도우미를 쓴다. 각 시험은 기록 변수 없이 돈 표준 출력 · 종료 코드와 같은지도 본다.

```python
def test_teardown_time_charged_to_own_module(self):
    # test_a.py: tearDownClass 에서 time.sleep(0.3), tearDownModule 에서 time.sleep(0.2) / test_b.py: 통과 하나
    self.assertGreaterEqual(secs["pkg/tests/test_a.py"], 0.5)
    self.assertLess(secs["pkg/tests/test_b.py"], 0.25)

def test_last_module_teardown_kept(self):
    # test_a.py: 통과 하나 / test_z.py(차례가 마지막): tearDownModule 에서 time.sleep(0.3)
    self.assertGreaterEqual(secs["pkg/tests/test_z.py"], 0.3)

def test_setupclass_failure_module_has_line(self):
    # test_c.py: setUpClass 에서 time.sleep(0.2) 뒤 raise RuntimeError("boom")
    self.assertGreaterEqual(secs["pkg/tests/test_c.py"], 0.2)
    self.assertEqual(rc, 1)   # 표준 출력에 "ERROR: setUpClass (test_c.C)" — 변수 없는 실행과 같다

def test_nested_package_import_failure_key(self):
    # pkg/tests/sub/__init__.py · pkg/tests/sub/test_bad.py 가 맨 위에서 raise ImportError("x")
    self.assertIn("pkg/tests/sub/test_bad.py", secs)

def test_dot_slash_start_same_keys(self):
    # 러너 인자를 "./pkg/tests" 로 — test_a.py(통과) · test_broken.py(임포트 실패)
    self.assertEqual(sorted(secs), ["pkg/tests/test_a.py", "pkg/tests/test_broken.py"])

def test_module_without_file_key(self):
    # test_nofile.py 맨 위에 `del __file__` 뒤 TestCase 하나
    self.assertIn("pkg/tests/test_nofile.py", secs)

def test_write_timing_encoding_failure_writes_nothing(self):
    # write_timing(path, {"a.py": 1.0, "\udcff": 1.0}) → 알림 한 줄, path 가 없거나 비었다

def test_result_class_usable_without_runner(self):
    # cls = run_unittest_dir.timed_result_class(<임시 폴더>, <임시 폴더>); r = cls(io.StringIO(), True, 1)
    # unittest.TestSuite([<통과하는 TestCase>]).run(r) 가 예외 없이 돌고 r.module_secs 에 키 하나
```

(`secs` = 기록 줄을 `{키: float(초)}` 로 읽은 것.) 계획 1 의 `test_import_failure_module_keyed_by_file` · `test_deleted_cwd_same_as_old_runner` 는 그대로 통과해야 한다.

- [ ] **Step 2: 실패를 본다**

Run: `cd tools/suite && python3 -m unittest test_suite_timing.UnittestDirTimingTests -v`
Expected: FAIL — 정리 시간이 다음 모듈에 · 마지막 정리가 없음 · `test_c.py` 줄 없음 · 중첩 키가 `pkg/tests/sub.test_bad.py` · `timed_result_class` 없음

- [ ] **Step 3: `run_unittest_dir.py` 를 고친다**

- 귀속 규칙은 계획의 판단 L2 다. `_TimedSuite` 는 `_tearDownPreviousClass` · `_handleModuleTearDown`(정리 → `result._previousTestClass` 의 모듈) 과 `_handleClassSetUp` · `_handleModuleFixture`(준비 → 이번 `test` 의 모듈) 를 `super()` 로 감싸 잰다. `_handleModuleFixture` 는 안에서 `_handleModuleTearDown` 을 부르므로, 결과 객체에 「안쪽에서 이미 더한 초」 누계를 두고 바깥 몫에서 뺀다. `result` 에 `charge` 가 없으면 재지 않고 `super()` 만 부른다. 앞 클래스가 없으면(첫 테스트) 정리 몫은 더하지 않는다.
- 몸통은 `startTest` 에서 시각을 잡고 `stopTest` 에서 그 테스트의 모듈에 더한다(앞 `stopTest` 부터 재지 않는다).
- 키는 L3. `start_abs = os.path.abspath(start)` 와 `base = os.getcwd()`(실패하면 지금처럼 빈 글 — `module_key` 는 예외를 내지 않는다)를 테스트가 돌기 전에 한 번 잰다.
- 기록 변수가 있을 때만 `loader = unittest.TestLoader(); loader.suiteClass = _TimedSuite` 로 찾고 `resultclass=timed_result_class(start_abs, base)` 로 돈다. 변수가 없으면 지금 길 그대로(기본 로더 · 기본 결과).
- `write_timing` 은 L4.

- [ ] **Step 4: 통과를 본다**

Run: `cd tools/suite && python3 -m unittest test_suite_timing -v`
Expected: PASS — 모든 시험(새 여덟 포함)

- [ ] **Step 5: 고친 시험의 이빨을 보인다** — 커밋 뒤 `git clone --no-local` 사본에서 `_TimedSuite` 의 정리 감싸기 하나를 지우면 `test_teardown_time_charged_to_own_module` 이 빨개지는지 본다. 결과를 보고에 적는다.

- [ ] **Step 6: 커밋**

```bash
git add tools/suite/run_unittest_dir.py tools/suite/test_suite_timing.py
git commit -m "fix(suite): python 모듈별 시간이 정리 시간을 제 모듈에 귀속한다 (E1)"
```

---

### Task 3: `suite_peers.py` 손질과 실제 표 시험

품질 게이트의 `suite_peers.py:42` · `:116` · `test_suite_timing.py:177` · `:199`, 미룬 것(`--interval` 0 이하 · 정리에서 `SUITE_PEERS_PS_FILE` 빼기 · `ps -p` 시간 상한 · `--list` 종료 코드)이다.

**Files:**
- Modify: `tools/suite/suite_peers.py`
- Test: `tools/suite/test_suite_timing.py`(`PeerCountTests` · 모듈 도우미)

**Interfaces:**
- Consumes: 없음
- Produces: `is_runner(command: str) -> bool`(L6) · `read_rows_why() -> (rows | None, why: str | None)`(`read_rows()` 는 그 첫 값을 돌려주는 얇은 덮개로 남긴다) · `--wait` 가 읽지 못한 표에서 `waited=<초>\tpeers=?` · 종료 코드 3(L7) · `--interval` 0 이하 종료 코드 2(L8). 과제 4 가 `read_rows_why` 의 까닭 글에 기댄다.

- [ ] **Step 1: 실패하는 시험을 쓴다**

```python
def test_is_runner_cases(self):   # 기존에 no 두 줄을 더한다
    no += ["bash some_test.sh tools/suite/run-all.sh", "bash /x/foo.sh /y/run-all.sh"]
    # yes 의 "bash /Users/x/My Folder/tools/suite/run-all.sh" 는 그대로 True

def test_wait_unreadable_rows_returns_at_once(self):
    r = run_peers(["--pid", "50", "--wait", "30", "--interval", "0.2"], <없는 파일>)
    self.assertEqual(r.returncode, 3); self.assertRegex(r.stdout.strip(), r"^waited=0\tpeers=\?$")

def test_interval_not_positive_refused(self):
    for v in ("0", "-1"):
        self.assertEqual(run_peers(["--wait", "1", "--interval", v], self.ps_file("")).returncode, 2)

def test_read_rows_why_names_reason(self):
    # SUITE_PEERS_PS_FILE=<없는 파일> → (None, "표 파일을 열지 못했다: <경로>") 꼴 — why 가 비지 않았다
```

`test_real_ps_detached_runner_counted_once` · `test_real_ps_self_ancestor_child_excluded` 는 L9 대로 고친다 — 가짜 러너는 `release` 파일을 기다리고(상한 10초), 테스트는 `--list` 를 읽은 뒤 바로 만든다. 두 시험 모두 `--list` 의 종료 코드 0 을 본다(가짜 러너 안에서 부르는 것은 `echo $? > <파일>.rc`). 둘째 시험은 a 보다 먼저 「다른 자리」 가짜 러너 c 를 두 번 갈라 띄우고, b 안의 목록에 c 의 PID 가 **있다**(양성 대조)와 a · b · b 의 자식 PID 가 **없다**를 본다. `out_a`(b 가 끝난 뒤 읽는 목록)는 a 의 PID 만 본다.

`kill_tree_if_ours` 는 `ps -p` 에 `timeout=10` 을 주고, 자손 표는 `SUITE_PEERS_PS_FILE` 을 뺀 실제 표로 읽는다(`read_rows_why` 를 그 변수가 빠진 환경에서 — 바깥 테스트 환경에 변수가 남아 있어도 가짜 표로 정리하지 않게).

- [ ] **Step 2: 실패를 본다**

Run: `cd tools/suite && python3 -m unittest test_suite_timing.PeerCountTests -v`
Expected: FAIL — 새 no 두 줄이 True · `--wait` 가 30초를 다 기다리고 1 · `--interval 0` 이 0 · `read_rows_why` 없음

- [ ] **Step 3: `suite_peers.py` 를 고친다** — L6 · L7 · L8, 그리고 `read_rows_why`. `--stamp` 는 표를 읽지 못하면 표준 오류에 `suite_peers: 프로세스 표를 읽지 못했다 — <까닭>` 한 줄을 내고 지금처럼 `<epoch> ?` 와 0 으로 끝난다. 까닭은 `ps 종료 코드 <n>` · `ps 를 실행하지 못했다: <예외 이름>` · `빈 표` · `표 파일을 열지 못했다: <경로>`. 모듈 docstring 의 명령줄 줄을 고친다.

- [ ] **Step 4: 통과를 본다**

Run: `cd tools/suite && python3 -m unittest test_suite_timing -v`
Expected: PASS

- [ ] **Step 5: 이빨** — 사본에서 L6 의 `.sh` 갈래를 지우면 `test_is_runner_cases` 가, 둘째 실제 표 시험에서 `peer_pids` 가 늘 `[]` 를 내게 하면 그 시험이 빨개지는지 본다(고치기 전에는 그 변이에 초록이었다).

- [ ] **Step 6: 커밋**

```bash
git add tools/suite/suite_peers.py tools/suite/test_suite_timing.py
git commit -m "fix(suite): 다른 스위트 세기가 인자로 받은 run-all.sh 를 세지 않고 읽지 못한 표에서 기다리지 않는다 (E1)"
```

---

### Task 4: `run-all.sh` 알림 — 까닭 · python 알림 · 한 번

품질 게이트의 `run-all.sh:44` · `:82` · `:94` · `:101` · `test_suite_timing.py:430` 이다.

**Files:**
- Modify: `tools/suite/run-all.sh`
- Test: `tools/suite/test_suite_timing.py`(`RunAllTimingTests`)

**Interfaces:**
- Consumes: 과제 3 의 `suite_peers.py --stamp` 표준 오류 까닭 줄
- Produces: 「이미 알렸다」 파일 `"$LIST.warned"`(과제 5 의 알림도 같은 trap 아래) · 알림 글 `run-all: 다른 스위트 수를 세지 못했다 — <까닭>`(L10)

- [ ] **Step 1: 시험을 고치고 더한다**

```python
def check_stamp_unavailable(self, body):   # 기대 표준 오류를 바꾼다
    # sys.exit(1) → err == "run-all: 다른 스위트 수를 세지 못했다 — 종료 코드 1\n"
    # 빈 파일   → err == "run-all: 다른 스위트 수를 세지 못했다 — 출력이 없다\n"
    # 나머지(기록 줄의 ? · 표준 출력 · 종료 코드) 단언은 그대로

def test_unreadable_ps_reason_once(self):
    # SUITE_PEERS_PS_FILE=<없는 파일> 로 기록 바퀴 → 표준 오류가 정확히
    # "run-all: 다른 스위트 수를 세지 못했다 — suite_peers: 프로세스 표를 읽지 못했다 — 표 파일을 열지 못했다: <경로>\n" 한 줄

def test_python_runner_notice_surfaced(self):
    # 임시 레포의 tools/suite/run_unittest_dir.py 를, 표준 오류에
    # "run_unittest_dir: 시간 기록 파일에 쓸 수 없다 — 기록하지 않는다: X" 를 내고 0 으로 끝나는 가짜로 바꾼다
    # 기록 바퀴 → 그 줄이 python 폴더 수만큼 표준 오류에 있다 · 표준 출력은 변수 없는 바퀴와 같다
    # 변수 없는 바퀴 → 표준 오류가 빈 글(AC1)

def test_mid_round_write_failure_notes_without_bash_errors(self):   # 1 <= len <= 2 를 조인다
    self.assertEqual(err_lines, [notice])

def test_ac2_lines_and_same_stdout(self):   # 값 단언을 더한다
    # BASE 에 "shared/tests/test_slow.sh": "sleep 0.4\n" 를 더하고 그 대상 줄의 초 >= 0.4, 다른 셸 대상 줄의 초 < 0.4
```

(`test_ac2` 의 대상 수 기대는 셸 하나가 늘어난 만큼 고친다.)

- [ ] **Step 2: 실패를 본다**

Run: `cd tools/suite && python3 -m unittest test_suite_timing.RunAllTimingTests -v`
Expected: FAIL — 표준 오류가 빈 글 · python 알림 없음 · 알림 두 줄

- [ ] **Step 3: `run-all.sh` 를 고친다**

- stamp 를 부르는 세 자리(`timing_mark` · 시작 · 끝)는 표준 오류를 버리지 않고 받아, 결과가 `?` 이면 L10 의 알림을 낸다 — 바퀴에 한 번(`"$LIST.peers-warned"` 파일로, trap 이 지운다).
- python 러너 두 자리는 기록 변수가 있을 때만 `out` 에서 `^run_unittest_dir: ` 줄을 골라 표준 오류로 낸다(L11).
- 쓰기 실패 알림 세 자리는 `"$LIST.warned"` 가 없을 때만 내고 그 파일을 만든다(L12). `TIMING_WARNED` 변수는 걷는다.
- trap 을 `rm -f -- "$LIST" "$LIST.warned" "$LIST.peers-warned"` 로.
- 78행 찾기 줄은 글자 그대로.

- [ ] **Step 4: 통과를 본다**

Run: `cd tools/suite && python3 -m unittest test_suite_timing -v && bash shared/tests/test_shell_tests_executable.sh`
Expected: PASS · 찾기 줄 락 PASS

- [ ] **Step 5: 이빨** — 사본에서 `"$LIST.warned"` 확인을 지우면 `test_mid_round_write_failure…` 가 빨개지는지 본다.

- [ ] **Step 6: 커밋**

```bash
git add tools/suite/run-all.sh tools/suite/test_suite_timing.py
git commit -m "fix(suite): 시간 기록 알림이 까닭을 보이고 한 번만 나며 python 러너 알림을 버리지 않는다 (E1)"
```

---

### Task 5: 러너가 실패 목록의 대상만 돈다

AC19 · AC24(러너) · AC28 · AC30(러너 알림)이다.

**Files:**
- Modify: `tools/suite/run-all.sh` · `tools/suite/run_unittest_dir.py`(변수 빼기 한 줄)
- Modify: `tools/suite/test_suite_timing.py`(도우미를 `RepoMixin` 으로 — L15)
- Create: `tools/suite/test_suite_only_failed.py`

**Interfaces:**
- Consumes: 과제 4 의 trap · 알림 파일
- Produces: 환경 변수 `SUITE_ONLY_FAILED_FILE`(L13) · 알림 두 글(L14). 과제 6 의 대조가 이 러너를 끝에서 끝으로 부른다.

- [ ] **Step 1: 도우미를 옮긴다** — `RunAllTimingTests` 의 `make_repo` · `run_all` · `ps_file` · `out_file` · `lines` · `target_lines` 를 `class RepoMixin(object)` 로 옮기고 `RunAllTimingTests(RepoMixin, unittest.TestCase)` 로 둔다(`setUp` 은 각 TestCase 가). `python3 -m unittest test_suite_timing` 이 그대로 PASS 인지 본다.

- [ ] **Step 2: 실패하는 시험을 쓴다** — `test_suite_only_failed.py` 는 `from test_suite_timing import RepoMixin, BASE, BASE_WITHOUT_FAIL, NODE, NODE_TEST, FAIL_OUT, PASS_PY, clean_env` 만 임포트한다(TestCase 를 임포트하지 않는다). 목록 파일은 `self.tmp` 아래 절대 경로로 쓴다. 어느 대상이 돌았는지는 기록 변수를 함께 줘 대상 줄로 읽는다.

```python
class OnlyFailedTests(RepoMixin, unittest.TestCase):
    def test_ac19_only_listed_targets_each_kind(self):
        # BASE + node(있으면). 목록: "plugins/p/tests/test_fail.sh: broke" · "tools/x: FAIL: test_1 (test_t.T)" · (node 면) "plugins/p/tests/n.test.mjs: ok"
        self.assertEqual(sorted(대상 줄의 경로), sorted(["plugins/p/tests/test_fail.sh", "tools/x"] + node 경로))
        self.assertEqual((rc, out), (1, FAIL_OUT))
        self.assertEqual(err, "run-all: 일부만 돌았다 — 대상 %d개(SUITE_ONLY_FAILED_FILE)\n" % (2 + NODE))

    def test_ac19_absent_runs_all(self):          # 변수 없음 → 대상 줄 2 + 3 + NODE 개, err == ""
    def test_empty_value_same_as_absent(self):     # SUITE_ONLY_FAILED_FILE="" → 변수 없는 바퀴와 (rc, out, err) 가 같다
    def test_ac24_unreadable_line_runs_all(self):
        # 목록: "broke" · "plugins/p/tests/test_fail.sh: broke"
        # → 전부 돈다 · (rc, out) 가 변수 없는 바퀴와 같다
        # · err == "run-all: 실패 목록을 읽지 못해 전부 돈다 — 대상 경로 꼴이 아닌 줄이 있다: broke\n"
    def test_ac24_placeholder_target_unreadable(self):   # "<tree>/shared/tests/test_pass.sh: x" → 전부 · 같은 꼴의 알림
    def test_unreadable_file_and_relative_path_run_all(self):
        # 없는 파일 → "… — 파일을 읽지 못했다: <경로>" / "rel.txt" → "… — 절대 경로가 아니다: rel.txt" — 둘 다 전부 돈다
    def test_blank_lines_skipped_and_empty_list_runs_all(self):
        # "\nplugins/p/tests/test_fail.sh: broke\n\n" → 그 대상 하나 · 「대상 1개」
        # 빈 파일 → 전부 · "… — 읽을 줄이 없다: <경로>"
    def test_ac24_missing_target_line_skipped(self):
        # "plugins/p/tests/test_gone.sh: x" · "plugins/p/tests/test_fail.sh: broke" → test_fail.sh 만 · 「대상 1개」
    def test_duplicate_names_same_target_once(self):
        # "plugins/p/tests: FAIL: a (m.C)" · "plugins/p/tests: FAIL: b (m.C)" → 대상 줄 하나 · 「대상 1개」
    def test_ac30_partial_pass_stdout_rc_unchanged(self):
        # 목록이 통과하는 대상 하나("shared/tests/test_pass.sh: x") → (rc, out) == (0, "") · err 는 「대상 1개」 한 줄
    def test_ac28_nested_runner_gets_no_list(self):
        # 안쪽 레포: 셸 시험 둘이 각자 <표지 폴더>/<이름> 을 만든다
        # 바깥 레포: test_nested.sh(목록에 있다)가 안쪽 run-all.sh 를 돌고, test_unlisted.sh 가 <표지>/unlisted 를 만든다
        # → 안쪽 표지 둘이 있다 · unlisted 표지는 없다
    def test_python_tests_do_not_inherit_list(self):
        # run_unittest_dir.py 를 SUITE_ONLY_FAILED_FILE=<파일> 로 직접 — 시험이 assertNotIn("SUITE_ONLY_FAILED_FILE", os.environ), rc 0
```

- [ ] **Step 3: 실패를 본다**

Run: `cd tools/suite && python3 -m unittest test_suite_only_failed -v`
Expected: FAIL — 목록을 무시하고 전부 돈다 · 알림 없음 · python 시험이 변수를 본다

- [ ] **Step 4: 고친다**

- `run-all.sh`: `cd` 뒤, 시간 기록 읽기 옆에서 `ONLY="${SUITE_ONLY_FAILED_FILE:-}"` · `unset SUITE_ONLY_FAILED_FILE`. 값이 있으면 L13 대로 읽어 고른 대상 목록을 임시 파일 `"$LIST.only"`(trap 이 지운다)에 한 줄에 하나 두고 L14 알림을 낸다. 세 반복문의 몸통 첫 줄에서 고른 목록이 있으면 그 대상이 목록에 없을 때 `continue`(`grep -qxF -- "$f" "$LIST.only"`). 꼴 검사는 `case` 로 — bash 의 `case` 에서 `*` 는 `/` 도 맞으므로, `plugins/*/tests` · `tools/*` 는 `<p>` · `<d>` 자리에 `/` 가 없는지 따로 본다.
- `run_unittest_dir.py`: `main` 첫머리에서 `os.environ.pop("SUITE_ONLY_FAILED_FILE", None)`. docstring 에 한 줄.
- `run-all.sh` 머리 주석에 변수 한 줄.

- [ ] **Step 5: 통과를 본다**

Run: `cd tools/suite && python3 -m unittest test_suite_timing test_suite_only_failed -v && bash shared/tests/test_shell_tests_executable.sh`
Expected: PASS

- [ ] **Step 6: 커밋**

```bash
git add tools/suite/run-all.sh tools/suite/run_unittest_dir.py tools/suite/test_suite_timing.py tools/suite/test_suite_only_failed.py
git commit -m "feat(suite): 러너가 실패 목록의 대상만 돌고 읽지 못하면 전부 돈다 (E1)"
```

---

### Task 6: 대조를 한 바퀴로

AC14 · AC15 · AC16 · AC17 · AC18 · AC24(대조) · AC30(대조) 이다.

**Files:**
- Modify: `plugins/spec-distill/scripts/merge_check.py`
- Test: `plugins/spec-distill/tests/test_merge_check.sh`

**Interfaces:**
- Consumes: 과제 5 의 러너(장면 13 · 16 이 임시 레포에 복사해 돈다)
- Produces: 상수 `ONLY_FAILED_ENV = "SUITE_ONLY_FAILED_FILE"` · `run_command(cmd: str, tree: Path, tmp: Path, only_failed=None) -> (int, str)`(환경에서 `ONLY_FAILED_ENV` 를 빼고, `only_failed` 가 있을 때만 그 경로를 넣는다) · `compare_command(...)` 의 결과에 `"fixed_unmeasured": str | None` · `report(res)` 가 그 값이 있으면 고쳐짐 줄을 `- 기본 브랜치에만 있는 실패(고쳐짐) — 재지 않았다(<사유>)` 로 낸다(`res.get` — 탐지 경로의 결과에는 없다). 과제 7 이 `compare_command` 에 임시 폴더 인자를 더한다.

- [ ] **Step 1: 장면 4 를 고치고 장면 12–17 을 쓴다** — `test_merge_check.sh` 의 `finish` 앞, 지금 도우미(`mkrepo` · `put` · `push_base` · `branch_with` · `mc`)를 쓴다. 테스트 명령 스크립트는 `printf '%s\t%s\n' "$PWD" "${SUITE_ONLY_FAILED_FILE:-}" >> "$MC_LOG"` 로 어느 사본에서 무엇을 받고 돌았는지 남긴다(`MC_LOG="$T/<이름>.log" mc …` — 함수 앞 대입은 그 안의 명령에 물려진다). 사본은 로그 첫 칸의 끝이 `/base` · `/merged` 인 것으로 가른다. 러너가 필요한 장면은 `with_runner() { mkdir -p "$W/tools/suite"; cp "$ROOT"/tools/suite/{run-all.sh,run_unittest_dir.py,suite_peers.py} "$W/tools/suite/"; }`.

```bash
# 4(고침) — 119행: 목록을 모르는 명령이라도 기준 사본은 목록을 받고 돌았다 → 고쳐짐은 재지 않는다
assert_contains "$out" "기본 브랜치에만 있는 실패(고쳐짐) — 재지 않았다" "test_command: 목록을 건넨 대조는 고쳐짐을 재지 않았다고 말한다"

# 12 — AC14: 합친 사본이 깨끗하면 기준 사본을 돌지 않는다
#   run.sh: 로그 한 줄 + echo "  ✓ fine" (rc 0)
assert_eq "$rc" "0"; assert_contains "$out" "판정: 새 실패 없음"
assert_contains "$out" "기준 사본은 돌리지 않았다"
assert_contains "$out" "기본 브랜치에만 있는 실패(고쳐짐) — 재지 않았다"
assert_eq "<로그의 /base 줄 수>" "0"; assert_eq "<로그의 /merged 줄 수>" "1"

# 13 — AC15 · AC19 · AC24(없는 대상) · AC30: 실제 러너, 원래 실패 하나 + 브랜치가 더한 새 실패 하나,
#      호출한 쪽에 살아 있는 목록(SUITE_ONLY_FAILED_FILE="$T/stale-list", 내용 "shared/tests/test_old.sh: old")
#   기본: shared/tests/test_old.sh(✗ old, rc 1) · shared/tests/test_seen.sh(로그 한 줄) / 브랜치: + shared/tests/test_new.sh(✗ new, rc 1)
#   test_command: bash tools/suite/run-all.sh · test_failure_pattern: "^FAILED (.+)$"
assert_eq "$rc" "1"
assert_contains "$out" "이 브랜치에만 있는 실패 1개: shared/tests/test_new.sh: new"
assert_contains "$out" "양쪽 다 있는 실패 1개: shared/tests/test_old.sh: old"
assert_contains "$out" "목록(SUITE_ONLY_FAILED_FILE)으로 건네 돌렸다"
assert_eq "<로그의 /merged 줄 수>" "1"   # 합친 사본은 호출한 쪽 목록을 무시하고 전부 돌았다(AC30)
assert_eq "<로그의 /base 줄 수>" "0"     # 기준 사본은 test_old.sh 만 돌았다(AC19)

# 14 — AC16: 목록을 모르는 명령 — run.sh 가 늘 "FAILED a.sh: old"(브랜치는 + "FAILED b.sh: new") · rc 1
assert_eq "$rc" "1"; assert_contains "$out" "이 브랜치에만 있는 실패 1개: b.sh: new"
assert_contains "$out" "양쪽 다 있는 실패 1개: a.sh: old"
assert_eq "<로그 /base 줄의 둘째 칸이 비지 않았다>" "1"   # 목록을 받았지만 전부 돌았다

# 15 — AC17 · AC30: 합친 사본이 이름 없이 실패(rc 1, 출력 없음) · 기본은 rc 0, 호출한 쪽에 살아 있는 목록
assert_eq "$rc" "1"; assert_contains "$out" "(test_command) 전체 — 이름 대조 불가 — 단위 수준만"
assert_contains "$out" "기준 사본은 전부 돌렸다"
assert_contains "$out" "기본 브랜치에만 있는 실패(고쳐짐) 0개"
assert_eq "<로그 /base 줄의 둘째 칸>" ""   # 전부 돌 때도 변수를 빼고 돈다

# 16 — AC24: 장면 13 과 같은 레포 꼴, test_failure_pattern: "^FAILED [^:]+: (.+)$"(대상 경로를 뺀다)
assert_eq "$rc" "1"; assert_contains "$out" "이 브랜치에만 있는 실패 1개: new"
assert_contains "$out" "양쪽 다 있는 실패 1개: old"
assert_eq "<로그의 /base 줄 수>" "1"   # 러너가 목록을 버리고 전부 돌았다

# 17 — Review Focus 4: test_command: no-such-cmd-e1p2 → rc 3, "테스트 명령을 실행하지 못했다(rc 127)"
```

- [ ] **Step 2: 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_merge_check.sh 2>&1 | tail -30`
Expected: FAIL — 장면 4 · 12 · 13 · 14 · 15 · 16 의 새 단언(기준 사본이 먼저 · 늘 돈다 · 「재지 않았다」 없음)

- [ ] **Step 3: `compare_command` 를 고친다**

```text
합친 사본을 돈다(목록 변수 없이) → rc 127 이면 Stop(3) — 기준 사본은 돌지 않는다
m_names, shape = side_names(합친 쪽)
m_rc == 0 이고 m_names 가 비었으면: 알림(L17 첫째) · fixed_unmeasured = "기준 사본을 돌지 않았다" · new/both 빈 채 돌려준다
m_names 가 있으면: work/only-failed.txt 에 sorted(m_names) 를 쓰고(L18) 그 경로로 기준 사본을 돈다 · 알림(L17 둘째) · fixed_unmeasured = "기준 사본을 실패 목록으로만 돌렸다"
그 밖(m_rc != 0, 이름 없음): 기준 사본을 목록 변수 없이 전부 돈다 · 알림(L17 셋째) · fixed_unmeasured = None
기준 사본 rc 127 → Stop(3)
그 뒤의 이름 대조(named · new · fixed · both · unit_only)는 지금 글 그대로. fixed_unmeasured 가 있으면 res["fixed"] 는 보고에 쓰지 않는다
```

`report` 는 고쳐짐 줄만 바꾼다 — 판정 줄과 종료 코드 규칙은 그대로. 모듈 docstring 의 「무엇을 돌리나」 에 한 바퀴 구조를 두 줄로 적는다.

- [ ] **Step 4: 통과를 본다**

Run: `bash plugins/spec-distill/tests/test_merge_check.sh 2>&1 | tail -5 && bash plugins/spec-distill/tests/test_conductor_e2e.sh 2>&1 | tail -3 && bash plugins/spec-distill/tests/test_default_branch.sh 2>&1 | tail -3`
Expected: 셋 다 실패 0

- [ ] **Step 5: 이빨** — 사본에서 (a) 합친 사본 실행에서 `ONLY_FAILED_ENV` 빼기를 지우면 장면 13 이, (b) 기준 사본 실행 자리를 「늘 전부」 로 바꾸면 장면 12 · 13 이, (c) `fixed_unmeasured` 를 늘 None 으로 하면 장면 4 · 12 가 빨개지는지 본다.

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/scripts/merge_check.py plugins/spec-distill/tests/test_merge_check.sh
git commit -m "feat(spec-distill): 머지 전 대조가 합친 사본을 먼저 돌고 실패한 대상만 기준 사본에서 다시 돈다 (E1)"
```

---

### Task 7: 대조의 임시 폴더를 git 밖에

더한 일 3 이다. `plugins/plugin-audit/tests/` 는 고치지 않는다.

**Files:**
- Modify: `plugins/spec-distill/scripts/merge_check.py`
- Test: `plugins/spec-distill/tests/test_merge_check.sh`

**Interfaces:**
- Consumes: 과제 6 의 `run_command` · `compare_command`
- Produces: `tmp_candidates() -> list`(시험이 갈아 끼운다) · `side_tmps(root: Path, work: Path) -> (dict, note | None)`(`{"base": Path, "merged": Path}`) · `compare_command(..., tmps)` · `compare_detected(..., tmps)` · `run_side(..., tmp)` 가 그 폴더를 쓴다. `run()` 이 만들고 `finally` 에서 지운다(`--keep-merged` 여도 지운다).

- [ ] **Step 1: 실패하는 장면 18 을 쓴다**

```bash
# 18 — 임시 폴더는 git 밖(호출한 쪽 TMPDIR 이 git 안이어도)
#   mkrepo tg 'test_command: bash run.sh\ntest_failure_pattern: "^FAILED (.+)$"\n' · push_base · put b.txt b · branch_with feature/tg
#   run.sh: if git -C "$TMPDIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then echo "FAILED tmp: inside-git"; exit 1; fi; echo ok
mkdir -p "$W/tmpin"; echo tmpin >> "$W/.git/info/exclude"
out="$(TMPDIR="$W/tmpin" mc --branch feature/tg)"; rc=$?
assert_eq "$rc" "0" "호출한 쪽 TMPDIR 이 git 안이어도 대조가 주는 임시 폴더는 git 밖이다"
CT="$(mktemp -d /tmp/mc-ct.XXXXXX)"   # trap 이 함께 지운다. git 안이면 no 로 알린다(전제)
out="$(TMPDIR="$CT" mc --branch feature/tg)"; rc=$?
assert_eq "$rc" "0"; assert_eq "$(ls -A "$CT")" "" "대조가 끝나면 만든 임시 폴더를 지운다"
# 대체 길: 후보를 git 안 하나로 갈아 끼우면 알리고 실행 폴더 안을 쓴다 — 그때 run.sh 가 git 안을 잡는다(양성 짝)
out="$(cd "$W" && python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import merge_check as m
m.tmp_candidates = lambda: [sys.argv[3]]
sys.exit(m.main(["run", "--roadmap", sys.argv[2], "--no-fetch", "--branch", "feature/tg"]))' "$ROOT/plugins/spec-distill/scripts" "$RM" "$W" 2>&1)"; rc=$?
assert_contains "$out" "git 작업 트리 밖 임시 폴더를 찾지 못해 실행 폴더 안을 쓴다"
assert_contains "$out" "tmp: inside-git"
```

- [ ] **Step 2: 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_merge_check.sh 2>&1 | tail -10`
Expected: FAIL — 장면 18 첫 단언 rc 1(지금 임시 폴더는 실행 폴더 안 · 그 레포의 git 안) · `tmp_candidates` 없음

- [ ] **Step 3: 고친다** — L19. `neutral` 은 사본마다 그 사본의 임시 폴더를 받는다(지금처럼 자리표시 `<tmp>`). 장면 9 의 「실행 폴더에는 합친 사본만 남는다」 가 그대로 서야 한다.

- [ ] **Step 4: 통과를 본다**

Run: `bash plugins/spec-distill/tests/test_merge_check.sh 2>&1 | tail -5 && bash plugins/spec-distill/tests/test_conductor_e2e.sh 2>&1 | tail -3`
Expected: 실패 0

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/merge_check.py plugins/spec-distill/tests/test_merge_check.sh
git commit -m "fix(spec-distill): 머지 전 대조가 테스트에 주는 임시 폴더를 git 작업 트리 밖에 만든다 (E1)"
```

---

### Task 8: 다시 돌리는 갈래와 임포트 색인의 실패 길

품질 게이트의 `test_codex_backward_compat.sh:108` · `test_copy_of_contract.sh:861` 이다.

**Files:**
- Modify: `plugins/quality-gates/tests/test_codex_backward_compat.sh`
- Modify: `shared/tests/test_copy_of_contract.sh`

**Interfaces:**
- Consumes: 없음
- Produces: 환경 변수 `CODEX_COMPAT_INNER=1`(그 테스트 안에서만 — 셋째 확인만 돈다) · `impscan` 의 계약(표준 입력 · 출력 · 차례)은 그대로

- [ ] **Step 1: 넷째 확인을 쓴다** — L20. 셋째 확인 뒤, `CODEX_COMPAT_INNER` 가 없을 때만:
  - 임시 폴더(`mktemp -d`, trap 으로 지운다)에 `tests/` 를 만들고 이 파일 자신과 가짜 셋을 둔다 — `test_fake_red.sh`(`cat >/dev/null; echo "  ✗ red-a"; exit 1` — 표준 입력을 먹는다) · `test_fake_red2.sh`(`echo "  ✗ red-b"; exit 1`) · `test_fake_green.sh`(`exit 0`).
  - 지문은 이 파일의 `fingerprint` 로 잰다. 원장 셋으로 안쪽을 `CODEX_COMPAT_INNER=1 bash <임시>/tests/test_codex_backward_compat.sh` 로 돈다:
    (a) red · red2 를 맞는 지문으로 → 안쪽 rc 0 · `PASS: 등재 2건`
    (b) red 를 틀린 지문으로 → 안쪽 rc 1 · `해시불일치`
    (c) green 을 아무 지문으로 → 안쪽 rc 1 · `stale 등재`
  - 셋이 다 맞으면 `PASS: 다시 돌리는 갈래 — 지문 일치 · 불일치 · stale 을 가짜 원장으로 확인`, 아니면 갈린 경우마다 `FAIL:` 한 줄. 안쪽 실행에서는 첫째 · 둘째 · 넷째 확인을 건너뛴다. 머리 주석의 「Three checks」 를 넷으로 고친다.

- [ ] **Step 2: 돈다** — Run: `bash plugins/quality-gates/tests/test_codex_backward_compat.sh` · Expected: `Total: 4, pass: 4, fail: 0`

- [ ] **Step 3: 이빨** — 사본에서 (a) 셋째 확인의 `<&3` 을 지우면(원장을 표준 입력으로 읽게) · (b) stale 갈래를 지우면 넷째 확인이 FAIL 인지 본다.

- [ ] **Step 4: 임포트 색인의 실패 길을 고친다** — L21. 861행을 `if [ "$rc" -ne 0 ]; then` 으로, 847행 색인 만들기가 실패하면(`… > "$IMPINDEX" || : > "$IMPINDEX"`) 빈 색인으로 둔다. 그 자리 주석을 「색인에 없는 후보가 있거나 색인 읽기가 실패하면」 으로.

- [ ] **Step 5: 돈다 · 이빨** — `bash shared/tests/test_copy_of_contract.sh` 의 단언 수 · 축별 계측이 고치기 전과 같다(Step 4 전의 출력과 견준다). 사본에서 awk 프로그램에 문법 오류를 넣으면 고치기 전에는 소비자 집합이 비어 계측이 달라지고, 고친 뒤에는 계측이 같다는 것을 보인다.

- [ ] **Step 6: 커밋**

```bash
git add plugins/quality-gates/tests/test_codex_backward_compat.sh shared/tests/test_copy_of_contract.sh
git commit -m "test: 원장 다시 돌리기 갈래를 가짜 원장으로 돌리고 임포트 색인 실패가 락을 약하게 하지 않는다 (E1)"
```

---

### Task 9: 판 · 변경 기록 · 지휘 절차서 · 경로 예약

AC20 과 더한 일 5 다.

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` · `plugins/spec-distill/CHANGELOG.md`
- Modify: `plugins/spec-distill/references/conducting.md`(142행 한 자리)
- Modify: `docs/superpowers/roadmaps/2026-11-20-test-method-rework-brief/roadmap.md`(E1 예약 줄)

**Interfaces:**
- Consumes: 과제 6 · 7 의 동작
- Produces: 없음

- [ ] **Step 1: 판을 올린다** — `git fetch origin` 뒤 `git show origin/main:plugins/spec-distill/.claude-plugin/plugin.json` 의 판 위의 다음 minor 를 `plugin.json` 에, 같은 판 머리를 `CHANGELOG.md` 맨 위에(`## [<판>] — <오늘>`). 내용:
  - Changed — 머지 전 대조(`merge_check.py`, 테스트 명령 경로)가 합친 사본을 먼저 돈다. 합친 사본이 깨끗하면 기준 사본을 돌지 않고, 실패 이름이 있으면 그 목록을 환경 변수 `SUITE_ONLY_FAILED_FILE` 로 건네 기준 사본을 돈다(목록을 아는 러너는 그 대상만, 모르는 명령은 전부). 이름을 뽑지 못하면 지금처럼 전부 돈다. 기준 사본을 전부 돌지 않은 대조는 「기본 브랜치에만 있는 실패(고쳐짐)」 를 「재지 않았다」 로 낸다. 판정과 종료 코드는 같다. 합친 사본 · 기준 사본을 전부 돌 때는 호출한 쪽의 그 변수를 빼고 돈다.
  - Fixed — 대조가 테스트에 주는 임시 폴더를 git 작업 트리 밖에 만든다(못 찾으면 알리고 실행 폴더 안).
  - Changed — 지휘 절차서의 스위트 대조 설명.

- [ ] **Step 2: 지휘 절차서 한 자리** — `conducting.md` 142행의 `실패 «이름» 을 양방향으로 대조한다 — 이 브랜치에만 있는 실패와 기본 브랜치에만 있는 실패.` 를 다음으로 바꾼다(그 줄의 나머지는 그대로):

  > 합친 사본을 먼저 돌리고, 실패가 있을 때만 기본 브랜치 사본에서 다시 돌려 실패 «이름» 을 대조한다 — 이 브랜치에만 있는 실패와 양쪽 다 있는 실패. 합친 사본이 깨끗하면 기본 브랜치 사본은 돌리지 않는다. 다시 돌 때는 실패 이름을 목록 파일(`SUITE_ONLY_FAILED_FILE`)로 건네 목록을 아는 러너가 그 대상만 돌고, 이름을 뽑지 못했으면 전부 돈다. 기본 브랜치 사본을 전부 돌지 않았으면 기본 브랜치에만 있는 실패(고쳐짐)는 「재지 않았다」 다.

- [ ] **Step 3: 경로 예약** — L22. `gh pr view 320 --json state -q .state` 가 `MERGED` 면 `git fetch origin && git merge --no-edit origin/main`(충돌이면 멈추고 보고) 뒤 E1 블록 `- 경로 예약:` 줄 끝에 `, plugins/spec-distill/references/conducting.md` 를 더한다. `MERGED` 가 아니면 편집하지 않고 「#320 이 머지되지 않아 예약 줄을 고치지 않았다 — 머지 전에 지휘자가 맞춘다」 를 보고에 적는다.

- [ ] **Step 4: 돈다**

Run(하나씩): `bash shared/tests/test_changelog_integrity.sh` · `git grep -l 'conducting.md' -- 'plugins/*/tests/*' 'shared/tests/*'` 가 낸 테스트 전부(셸은 `bash`, `.py` 는 `python3`) · `bash plugins/spec-distill/tests/test_merge_check.sh`
Expected: 실패 0 — 단, worktree 에서만 실패하는 것으로 알려진 시험(대조 두 번의 「양쪽 다」 목록에 있는 것)은 고치기 전에도 같은 실패인지 과제 1 HEAD 의 `git clone --no-local` 사본에서 견준다

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/spec-distill/references/conducting.md docs/superpowers/roadmaps/2026-11-20-test-method-rework-brief/roadmap.md
git commit -m "chore(spec-distill): 판을 올리고 지휘 절차서의 스위트 대조 설명과 경로 예약을 새 구조에 맞춘다 (E1)"
```

(예약 줄을 고치지 않았으면 `roadmap.md` 를 pathspec 에서 뺀다.)

---

### Task 10: 확인과 PR 본문 초안

**Files:** 없음(`<TMPDIR>/e1-plan2-pr-body.md`)

- [ ] **Step 1: 바꾼 파일을 읽는 락을 돈다** — 과제 1 의 HEAD 를 `B` 라 하고, `git diff --name-only B HEAD` 의 파일마다 그 이름(basename)을 글자로 읽는 테스트를 `git grep -l -F <이름> -- 'plugins/*/tests' 'shared/tests' 'tools/*/test_*.py'` 로 모아 하나씩 돈다. 여기에 `shared/tests/test_no_new_duplication.sh` · `test_python_floor.sh` · `test_changelog_integrity.sh` · `test_shell_tests_executable.sh` · `plugins/quality-gates/tests/test_utf8_explicit.py` · `plugins/spec-distill/tests/test_review_hook_removed.py` 를 더한다. 실패마다 과제 1 HEAD 의 사본에서도 같은지 견주어 「이 브랜치가 만든 실패」 와 「원래 있던 실패」 를 가른 표를 보고에 싣는다. 이 브랜치가 만든 실패가 있으면 고친다.

- [ ] **Step 2: PR 본문을 쓴다** — 한국어, 아래를 담는다.
  - 요약 — 한 바퀴 대조(합친 쪽 먼저 · 깨끗하면 기준을 돌지 않음 · 실패한 대상만 기준에서 · 「고쳐짐」 은 재지 않음) · 러너의 실패 목록 · 임시 폴더 · 더한 일 다섯이 어느 커밋인가.
  - 판 — spec-distill 을 다음 minor 로(머지 직전에 기본 브랜치 판을 다시 보고 맞춘다).
  - 「부분 실행의 시간은 아직 재지 못했다」 — 이 PR 의 대조에서는 기준 사본이 기본 브랜치의 옛 러너를 돈다. 둘째 판단은 이 PR 이 머지되고 설치본이 새 판이 된 뒤 처음 도는 대조에서 한다(설계 §2 · AC23).
  - `## 지휘 로드맵에 알림` — 바뀐 구조(합친 쪽 먼저 · 실패만 기준에서 다시 · 「고쳐짐」 은 재지 않음 · 변수 이름 `SUITE_ONLY_FAILED_FILE` · 임시 폴더가 git 밖)와 지휘 절차서(`references/conducting.md`) 142행의 한 자리를 고쳤고 그 예약을 이 로드맵 E1 블록에 실었다는 것(과제 9 Step 3 에서 싣지 못했으면 그렇게). 받는 쪽은 머지 전 확인을 담당 세션으로 옮기는 대기 중 에픽이다(설계 §5).
  - 과제 1 의 두 관측 결과 표.
  - 품질 게이트 제안 열다섯 가운데 하지 않은 것과 이유(없으면 「모두 했다」).
  - 계획의 판단 가운데 사람에게 보이는 것 — L7 · L10 · L14 · L16 · L17 · L19.

- [ ] **Step 3: 보고에 싣는다** — 본문 파일 경로, 과제 1 의 관측 표, Step 1 의 표, 그리고 지휘자에게: 이 PR 의 대조는 브랜치의 `merge_check.py` 를 직접 불러(설치본은 옛 판이다) 「합친 쪽이 깨끗하면 기준을 돌지 않는다」 를 확인한다(설계 §2) — 합친 쪽에 늘 실패하는 테스트가 남아 있으면 그 확인은 이 PR 에서 일어나지 않는다는 것도 함께.

---

## 실행 방식의 마지막 전체 리뷰

고른 실행 방식의 마지막 전체 리뷰(subagent-driven 의 브랜치 전체 리뷰 · native 의 마지막 리뷰)의 리뷰어에게 아래를 그대로 싣는다.

- 설계문서 `## Acceptance Criteria` 의 AC 목록 원문과 `## 계획 2 에 더한 일` 원문, 이 계획의 `## AC 가르기` · `## 계획의 판단` 표.
- 요청: 계획 2 몫 AC(`AC14~AC20 · AC24 · AC28 · AC30`)마다 한 줄씩 `AC<n>: <구현됨|미룸|빠짐> — <근거(파일:줄 · 테스트 이름 · 명령 결과)>` 꼴로 보고하라. AC18 은 L16 으로 읽는다. 더한 일 다섯도 같은 꼴(`더한 일 <n>: …`)로, 품질 게이트 제안은 위치마다 한 줄로 보고하라.
- 요청: 설계문서 `## 있는 것 검토` 가 고른 것을 실제로 썼는지, 같은 것을 다시 만들지 않았는지 답하라 — 이름 대조(`side_names` · `report`)를 그대로 쓰고 새 대조기를 만들지 않았는가 · `run-all.sh` · `run_unittest_dir.py` 안에서 목록을 읽고 바깥 거르개를 두지 않았는가 · 공유 테스트 고르기(`shared/test-selection/`)를 쓰지 않았는가 · 공유 스위트 잠금(`suite_lock.py`)을 고치지 않았는가 · 원장과 지문 대조를 그대로 쓰는가 · 기록을 읽는 보고 스크립트를 만들지 않았는가 · 새 설정 키가 없는가.
- 끝에서 끝 흐름 셋을 따로 물어라 — 각 이음매의 종료 코드 소비와 상태 가정: ① 호출한 쪽 환경(`SUITE_ONLY_FAILED_FILE` 이 남아 있을 수 있다) → `merge_check.py` 의 합친 사본(변수 뺌) → 이름 뽑기 → `only-failed.txt` → 기준 사본(그 변수만) → `run-all.sh`(읽고 뺌 · 꼴 검사 · 버리면 전부) → 테스트(변수 없음) → 이름 대조 → 「고쳐짐」 줄 ② 이름이 없는 실패 · rc 127 · 목록을 모르는 명령에서 판정과 종료 코드가 지금과 같은가 ③ 임시 폴더를 만드는 자리와 지우는 자리(`--keep-merged` · 예외 · 대체 길)가 짝이 맞는가.
- 이 계획이 쓴 테스트 코드(과제 2–8)와 계획이 정한 판정(L13 · L16 · L19 · L20)은 계획이 정한 것이라는 표시를 붙여, 덜 보지 말고 같은 눈으로 보라고 적는다. 고친 기존 시험에서 단언이 지워지거나 느슨해지지 않았는지 `git diff <과제 1 HEAD> -- tools/suite plugins/spec-distill/tests plugins/quality-gates/tests shared/tests` 로 보라고 적는다 — 장면 4 의 고쳐짐 단언과 `check_stamp_unavailable` 의 표준 오류 기대는 설계(AC18)와 L10 이 바꾼 것이다.

리뷰 보고는 git 이 추적하지 않는 파일에 적는다 — 지휘자가 준 TMPDIR 의 `e1-plan2-ac-report.md`(쓸 수 없으면 이 worktree 의 `.claude/tmp/<담당자 이름>/e1-plan2-ac-report.md` — `git check-ignore -q` 로 확인). 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올린다 — 올릴 행을 보고에 적고 지휘자가 올린다. PR 을 만들기 전에

`python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.25.0"/scripts/check_bundle_coverage.py --impl <이 worktree>/docs/superpowers/specs/2026-11-21-suite-time-cut-design.md <보고 파일 경로> --acs "AC14~AC20 · AC24 · AC28 · AC30"`

을 돌려 경고를 사용자에게 보인다.
