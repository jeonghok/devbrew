# 있는 테스트 정리 PR 2 — 지휘 상태 레포 준비물 · python 묶음 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 승인된 PR 2 판정 표(23행)대로 지휘 상태 레포를 케이스마다 새로 짓던 python 시험 여섯을 「클래스마다 한 번 지어 케이스마다 복사」 로 바꾸고, `plugins/spec-distill/tests/` 폴더를 돌린 뒤 임시 폴더를 남기던 시험 넷의 정리를 고친다. 확인(단언)은 하나도 옮기거나 지우지 않는다 — 준비만 바꾼다.

**Architecture:** 있는 도우미 `plugins/spec-distill/tests/conductor_branch_fixture.py` 에 진입점 둘을 더하고 `StateRepo` 는 그대로 둔다 — 함수 `copy_repo(src, dst)`(견본 폴더를 복사하고 클론마다 원격을 사본으로 돌리고 index 를 새로 한다)와 클래스 `StateRepoCopy(StateRepo)`(`setUpClass` 에서 견본을 짓고 `setUp` 에서 복사한다 · 클래스의 준비는 `build` 훅에 둔다). StateRepo 를 쓰는 다섯 파일은 바탕을 `StateRepoCopy` 로 바꾸고 하위 클래스의 `setUp` 을 `build` 로 옮긴다. `test_conductor_ledger.py` 의 `Repo`(StateRepo 가 아니다 · 원격이 경로 꼴)는 `copy_repo` 만 쓴다. 준비를 바꾼 보안 확인은 고치기 전 사본과 고친 뒤 사본에 같은 변이 넷을 걸어 같은 케이스가 붉어지는지 견준다.

**Tech Stack:** python3(이 기계의 스위트 `python3` 는 3.9 — 3.9 문법만 · `addClassCleanup` · `copytree(dirs_exist_ok=True)` 는 3.8+) · unittest · git · bash(스크래치 스크립트) · 시간 기록은 `tools/suite/run_unittest_dir.py` 의 `SUITE_TIMING_FILE`.

**Spec:** `docs/superpowers/specs/2026-11-26-test-prune-design.md` — §1 의 PR 2 몫 · §3 · §5 · §6 · §7 · 「테스트할 자리」. 범위는 사용자가 승인한 판정 표가 정한다: `/Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-20-test-method-rework-brief/files/relay/E4/table-pr2-final.md`(다시 읽은 담당자 B 의 표 · 원문 `table-pr2-a.md` · `table-pr2-b.md` — 같은 폴더). 승인 줄은 설계문서 끝 「판정 표 승인 · 2026-11-28 · PR 2」. 사용자 답(2026-11-28): 표 「승인 (권장)」 · 명령줄을 `main()` 으로 내리지 않는다 · 고정 `/tmp` 시험(`test_codex_findings_to_yaml.py`)은 PR 4 · `test_parallel_recommend.py` 는 둔다 · 복사 도우미 확인 케이스 하나가 `file://` 와 경로 꼴 원격을 둘 다 고치는지 본다(B-1) · 쓰지 않는 구현을 대비하는 확인은 더하지 않는다. 표의 행은 아래에서 `표 1절 <첫 칸>` 처럼 부른다.

## AC 가르기

| AC | 과제 |
|---|---|
| AC1 · AC2 | 과제 9 Step 9(PR 본문 재료 — 승인 표 · 승인 줄 · 읽은 담당자 A · 다시 읽은 담당자 B · 갈린 4행) |
| AC4 | 과제 2–5(① — 견본을 클래스마다 한 번) · 과제 6 · 과제 9 Step 2(폴더 한 바퀴 뒤 남은 폴더 0) · 과제 1 Step 5 · 과제 9 Step 1(앞 · 뒤 초) |
| AC7 | 과제 8 Step 1–3(변이 넷 × 자리 일곱 · 양성 대조) |
| AC9 | 과제 9 Step 3(지운 파일 없음) |
| AC10 | 과제 9 Step 3(§5 점검 · 테스트 다섯) |
| AC11 | 과제 7 |
| AC12 · AC14 | 과제 9 Step 4 |
| AC13 | 미룸 — 지휘자 대조(전체 스위트는 이 계획에 없다) |
| AC8 | 해당 없음 — 이 PR 은 확인을 지우지 않는다(`docs/removed-tests.md` 에 줄이 없다). 구현 중 사라지는 확인이 생기면 멈추고 보고한다 |
| AC3 · AC5 · AC6 · AC15 · AC16 · AC17 | 이 PR 몫이 아니다 — 리뷰가 「미룸 — 다른 PR(PR 1 · 3 · 정리 PR · 로드맵 끝)」 으로 적는다 |

대조 스크립트에 주는 목록: `AC1,AC2,AC4,AC7,AC9,AC10,AC11,AC12,AC13,AC14`.

## Global Constraints

- **고치는 파일은 아래뿐이다**(표에 없는 테스트는 고치지 않는다 — 설계 §2 걸음 3). 모두 `plugins/spec-distill/tests/` 아래: `conductor_branch_fixture.py` · `test_conductor_branch.py` · `test_conductor_cross.py` · `test_conductor_status.py` · `test_conductor_mail.py` · `test_leader_seat.py` · `test_conductor_ledger.py` · `test_ledger_marker.py` · `test_brief_review_state.py` · `test_suite_lock.py`. 그리고 설계문서(과제 1 의 §8 한 문장 · 과제 9 의 `## 미룸` 줄). `test_parallel_recommend.py` · `test_codex_findings_to_yaml.py` · `test_conductor_state_branch_docs.py` 는 고치지 않는다(뒤의 것은 돌리기만 한다).
- **확인은 옮기지도 지우지도 않는다.** 바꾸는 것은 준비(`setUp` · `setUpClass` · 정리 차례)와 이력 주석뿐이다. 과제마다 케이스 id 목록이 고치기 전과 같다(과제 2 의 새 케이스 하나만 는다). 단언 줄은 이력 주석 덜기 밖에서 바뀌지 않는다.
- **복사 계약(표 1절 도우미 행).** ① 견본은 `setUpClass` 에서 `mock.patch.dict(os.environ, GIT_ENV)` 아래 짓고 `addClassCleanup` 으로 푼다 — 프로세스 안에서 부르는 `CB.ensure` · `CB.write` 의 git(push 포함)이 사용자 전역 설정 · 훅을 타지 않게. ② 복사 뒤 클론마다 원격을 사본의 bare 레포로 돌리고(`git remote set-url origin`) `git update-index -q --refresh` 를 한다. ③ 복사는 `shutil.copytree(..., symlinks=True)` 의 기본 `copy2` 다 — 표지 파일의 수정 시각은 견본을 지은 때로 실린다(`conductor_status._claimed_at` 이 읽는다). 그 값에 기대는 status 케이스는 스스로 `os.utime` 을 건다. ④ ledger 바탕의 원격은 경로 꼴(`file://` 아님)이다 — `copy_repo` 가 두 꼴을 다 고친다. ⑤ `team`(`CB.team_of` · `TL.Team`)은 상대 경로만 담는 객체라 견본의 값을 쓴다.
- **보안 확인**(표 「보안 확인이 섞였는가」 칸의 줄 범위)은 준비만 바뀐다. 그 범위가 든 클래스는 과제 8 에서 고치기 전 사본(옛)과 고친 뒤 사본(새)에 같은 변이 넷(삭제 · 추가 · 반전 · 형태 바꾸기)을 걸어 같은 케이스가 붉어지는지 견주고, 변이 없는 사본으로 양성 대조를 본다(`docs/testing.md` 「망가뜨려 보기」). **옛만 잡는 변이가 나오면** 받는 쪽은 같은 케이스다 — 사본이 그 확인의 이빨을 뺀 것이니 진입점(복사 계약)을 고쳐 다시 견준다. 진입점으로 고칠 수 없으면 멈추고 보고한다.
- **변이 사본의 꼴.** `git archive <커밋> | tar -x -C "$TMPDIR/e4-pr2/<이름>"` 로 뜬다(작업 트리를 고치지 않는다). 사본마다 같은 변이를 같은 글자로 건다 — 변이 자리가 0개 · 둘 이상이면 그 변이는 무효로 보고 자리를 고친다. 변이가 옛에서도 붉지 않으면 무효다 — 같은 갈래의 다른 자리를 골라 까닭을 적는다. 돌릴 때 `PYTHONDONTWRITEBYTECODE=1`.
- 새 파일을 만들지 않는다(도우미 확인은 그 준비물을 쓰는 테스트 파일 안 — 설계 「테스트할 자리」). 판을 올리지 않는다. `plugin.json` · `CHANGELOG.md` · `plugins/spec-distill/tests/test_stage_prose_trim.sh` · `docs/testing.md` 를 바꾸지 않는다(AC12 · AC14).
- python 파일 읽기 · 쓰기는 `encoding="utf-8"`(바이트 검색은 `read_bytes`). 긴 한글 줄은 인접 문자열로 나눈다(CPython 토크나이저).
- **전체 스위트(`tools/suite/run-all.sh`)는 이 계획에서 돌지 않는다.** 과제는 고친 파일 · 그 파일을 import 하는 시험 · 그 파일을 읽는 레포 락만 돈다. 전체 스위트는 지휘자의 머지 전 대조가 한 번 돈다(AC13 은 「미룸 — 지휘자 대조」).
- **시간 재기 · 폴더 한 바퀴는 공유 잠금 아래에서만**: `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.25.0/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-20-test-method-rework-brief/files/suite-lock --owner e4-impl-conductor-state --wait 7200 -- <명령>`. 못 잡으면 잠금 없이 돌리지 않고 주인 · 잡은 시각을 보고한다.
- **케이스 id 를 남기는 실행기.** 시간 재기는 `tools/suite/run_unittest_dir.py`(실패마다 `FAIL:` · `ERROR:` 줄), 순서 섞기는 과제 8 의 `shuffle.py`(`verbosity=2` — 케이스마다 id 와 결과)로 돈다. 한 번 났던 `test_conductor_branch.py` 실패(표 6절 — 재현 안 됨)가 다시 나오면 그 id 와 traceback 을 보고에 싣는다.
- git: 커밋은 pathspec 으로만(`git add -- <경로>` · `git commit -m … -- <경로>`). Conventional Commits(`test(spec-distill): …` · `docs(spec): …` — 설명은 한국어). 본문 끝: `Spec: docs/superpowers/specs/2026-11-26-test-prune-design.md` 와 `Co-Authored-By: <그 agent 의 모델 이름> <noreply@anthropic.com>`. 금지: `git stash` · `git checkout --` · HEAD 뒤로 옮기기 · 공유 임시 폴더 glob 삭제 · 다른 worktree 의 git. 경로 꼴은 `'plugins/*/tests/*'`(`'plugins/*/tests'` 는 0건이다).
- `TMPDIR` 은 지휘자가 준 폴더이고 기준값 · 보고 · 사본은 그 아래 `e4-pr2/` 에 둔다. 격리 자리의 셸이 복합 명령을 막으면 스크립트 파일로 써서 `bash <파일>` 로 돈다. Bash 도구의 셸은 zsh 다 — 파이프 종료 코드는 `bash -c` 안에서 잡는다.
- 하위 agent 를 띄울 때마다 superpowers subagent-driven-development 의 「Model Selection」 으로 모델을 골라 이름으로 지정하고 이유를 한 줄 적는다. 과제 리뷰어에게 「계획이 쓴 테스트 코드」(과제 2 Step 1)를 그렇다고 밝힌다.
- 설계 · 승인 표의 판정 · 수용 기준을 바꿔야 할 것 같으면 스스로 정하지 말고 멈춰 지휘자에게 보고한다.

## Review Focus

1. **사본이 견본 원격에 push 한다.** set-url 을 빠뜨리거나 경로 꼴 원격을 못 고치면 한 케이스의 push 가 견본 bare 에 쌓여 다음 케이스의 사본에 실린다 — 과제 2 의 도우미 확인(두 꼴 · 견본 원격에 안 보임)과 과제 5 Step 3(ledger 의 원격 주소).
2. **작업 폴더 지문이 복사 뒤 흔들린다.** index 의 파일 정보가 견본 것이라 첫 `git status` 가 index 를 다시 써 `snap()` 두 번이 갈린다 — 과제 2 의 snap 단언과 refresh 를 지운 변이.
3. **견본을 짓는 동안 사용자 전역 git 설정 · 훅이 돈다.** 과제 8 Step 5(가짜 전역 pre-push 훅이 돌지 않는다 · 이빨은 `GIT_CONFIG_GLOBAL` 을 뺀 사본).
4. **케이스끼리 같은 클래스 견본을 나눠 순서에 기댄다.** 견본은 읽기만 하고 사본에만 쓴다 — 과제 8 Step 4(클래스 안 순서 섞기 · 남긴 폴더 0).
5. **정리 차례가 chmod 되돌리기보다 앞선다.** `tearDown` 의 rmtree 가 cleanup(chmod 되돌리기)보다 먼저 돌아 폴더가 남는다 — 과제 5 Step 2 · 과제 6(모듈마다 빈 TMPDIR 에서 남은 폴더 0) · 과제 9 Step 2(폴더 한 바퀴).

## 계획의 판단

설계 · 표가 계획에 맡겼거나 정하지 않아 이 계획이 정한 것이다. ✎ 는 「설계 · 표에 없던 결정」 — 지휘자에게 돌려보내는 자리다.

| # | 자리 | 정한 것 | 이유 | 다른 길 |
|---|---|---|---|---|
| K1 ✎ | 진입점의 꼴 · 이름 | 함수 `copy_repo(src, dst)` 와 클래스 `StateRepoCopy(StateRepo)` 를 `conductor_branch_fixture.py` 에 더한다. 클래스의 준비는 `build(self)` 훅(하위 클래스가 `super().build()` 를 먼저) | 표 「옆에 진입점을 더하고 StateRepo 는 그대로」. 하위 클래스 준비가 상속으로 쌓이는 지금 꼴(`super().setUp()`)을 그대로 옮길 수 있다. ledger `Repo` 는 StateRepo 가 아니라 함수만 쓴다 | StateRepo 에 스위치를 더함 · 파일마다 setUpClass 를 손으로 |
| K2 ✎ | 옮길 인스턴스 속성 | 손으로 적지 않고 도출한다 — 견본을 짓는 동안 인스턴스에 더해진 속성 가운데 견본 폴더 아래 `Path` 는 사본 폴더 아래로 바꾸고, 나머지는 `copy.deepcopy` 해 준다 | 표의 실측 다섯(t · o · w · m2 · mdir)을 빠짐없이 덮고, 하위 클래스가 속성을 더해도 목록을 고칠 일이 없다. 나머지(`team` · `a1` · `b1` · `received`)는 깊은 복사라 케이스끼리 같은 객체를 나누지 않는다 | 다섯을 손으로 적음 · 나머지를 나눠 씀 |
| K3 ✎ | 하위 클래스의 `setUp` | `Write` · `WriteFloorGuards` · `Publish` · `Delete` · `CrossRepo` · `Show` · `StatusRepo` · `MailRepo` · `TeamRepo` 의 `setUp` 을 `build` 로 이름만 바꾼다(몸은 그대로 · `super().setUp()` → `super().build()`) | 표 1절이 이 아홉의 준비를 견본으로 올렸다(「클래스 견본 넷」 · 「견본 둘」 · 「견본 하나」) | 준비를 케이스에 남김 |
| K4 ✎ | `test_conductor_cross.py` `Quiet`(StateRepo 직속 1케이스) | 그대로 `StateRepo` 를 쓴다 | 표가 「받든 두든 0.1초」 로 남겼고 행이 없다 — 표에 없는 것은 고치지 않는다 | 바탕 견본 |
| K5 ✎ | ledger `Repo` 의 환경 | 견본 짓기에 클래스 GIT_ENV 패치를 걸지 않는다 — 지금처럼 하위 프로세스에 `ENV` 를 준다 | 지금 `Repo.setUp` 도 패치하지 않는다. 조건 ① 은 StateRepo 견본(표 도우미 행)의 것이다 | 패치를 더함 |
| K6 ✎ | 도우미 확인 케이스의 꼴 | `test_conductor_branch.py` `Fixture` 안 한 케이스 — 클래스 견본을 한 번 떠 표지 · 상태 브랜치 · 기계 상태를 얹은 것을 다시 견본으로 사본 둘을 뜨고, 경로 꼴 원격의 작은 레포 하나를 케이스 안에서 지어 함께 잰다 | 표 도우미 확인 행 + B-1 권장안(한 케이스가 두 꼴). 상태 폴더에 견본 경로가 없는지를 재려면 견본에 상태 폴더가 있어야 한다 | ledger 에 케이스 하나 더 |
| K7 ✎ | 보안 변이의 자리 | 표의 보안 줄 범위를 덮는 스크립트 자리 일곱(M1–M7 — 과제 8)에 변이 넷씩, 그 범위가 든 클래스만 골라 옛 · 새에서 돈다 | 확인은 그대로이고 준비만 바뀌므로, 옛 · 새에서 붉어지는 케이스 id 가 같으면 복사가 이빨을 빼지 않았다는 증거다. 클래스로 좁혀 옛 사본 실행(브랜치 파일 약 3분)을 줄인다 | 파일 전체를 돈다 |
| K8 ✎ | 설계 §8 바로잡기의 범위 | 사용자가 짚은 두 파일만이 아니라 그 문장 전체를 지금 diff 로 다시 쓴다 — 2026-11-28 실측으로 `origin/main...origin/feature/switch-retirement` 에서 그 문장이 든 일곱 가운데 남은 것은 `test_epic_conductor_skill.sh` 하나다 | 한 문장 안의 다른 다섯도 같은 까닭으로 낡았다 | 두 파일만 |
| K9 | 시간 재기 | 파일마다 `run_unittest_dir.py plugins/spec-distill/tests <파일 이름>` 을 `SUITE_TIMING_FILE` 와 `/usr/bin/time -p` 로 한 번(과제 1 · 9) | 사용자 규칙(대상 파일만 · 공유 잠금) · 설계 「있는 것 검토」 의 `tools/suite/` 시간 기록 · 케이스 id 를 남긴다 | — |
| K10 ✎ | 폴더 한 바퀴 | 고친 뒤 `plugins/spec-distill/tests` python 폴더 전체를 빈 TMPDIR 로 잠금 아래 한 번(과제 9 Step 2) | AC4 「폴더를 한 번 돌린 뒤 이 PR 의 대상이 남긴 임시 폴더가 없다」 와 지휘자 지시 「지운 뒤 폴더를 한 번 돌려」. 전체 스위트가 아니다 | 대상 모듈만 하나씩 |
| K11 ✎ | GIT_ENV 확인의 꼴 | 가짜 전역 설정(`core.hooksPath` → 표지 파일을 만드는 pre-push 훅)을 가리킨 채 견본을 짓는 클래스를 돌려 훅이 안 돌았음을 본다. 양성 대조는 같은 설정의 맨 push, 이빨은 `GIT_ENV` 에서 `GIT_CONFIG_GLOBAL` 을 뺀 사본 | 표 「확인 방법 — 견본 짓기의 환경」 의 예시 그대로 · 구현 보고에만 싣고 테스트로 더하지 않는다(사용자 「쓰지 않는 구현을 대비하는 확인은 더하지 않는다」) | 테스트 케이스로 더함 |
| K12 | 이력 주석 | 고친 열 파일에서 꼴 목록(`과제 \d+` · `Task \d+` · `검수 지적` · `리뷰 지적` · `R\d+ 수정` · `Review Focus` · `Deferred <해시>` · 커밋 해시 · 날짜+고쳤다)으로 한 번 훑는다. 요구 앵커(AC · M · I · J · B · § · R3 AC 등)와 픽스처 글(`- Task 1 끝` 같은 시험 데이터)은 남긴다 | 지휘자 지시 · 앞 PR 의 교훈 | — |
| K13 | PR | PR 을 여는 것은 지휘 흐름이다. 이 계획은 PR 본문 재료까지 만든다 | 앞 PR 들과 같다 | — |

---

## 파일 표

`plugins/spec-distill/tests/` 기준.

| 파일 | 맡는 일 | 과제 |
|---|---|---|
| `conductor_branch_fixture.py` | `copy_repo` · `StateRepoCopy` 더함(`StateRepo` 그대로) | 2 |
| `test_conductor_branch.py` | 도우미 확인 한 케이스 · StateRepo 클래스 전부를 `StateRepoCopy` 로 · 넷의 `setUp` → `build` | 2 · 3 |
| `test_conductor_cross.py` · `test_conductor_status.py` · `test_conductor_mail.py` · `test_leader_seat.py` | 바탕을 `StateRepoCopy` 로 · `setUp` → `build`(`Quiet` 은 그대로) | 4 |
| `test_conductor_ledger.py` | `Repo` 를 클래스 견본 + `copy_repo`(경로 꼴) · 정리를 `addCleanup` 으로(LiveAgent) · `PendingSeat` 는 `TeamRepo` 를 따라 바뀐다 | 4 · 5 |
| `test_ledger_marker.py` · `test_brief_review_state.py` · `test_suite_lock.py` | 임시 폴더 정리 | 6 |
| 위 열 파일 | 이력 주석 | 7 |
| `docs/superpowers/specs/2026-11-26-test-prune-design.md` | §8 한 문장 · `## 미룸` 줄(있을 때만) | 1 · 9 |

---

### Task 1: 다시 확인 · 기준값 · 고치기 전 시간 · 설계 §8 바로잡기

**Files:**
- Modify: `docs/superpowers/specs/2026-11-26-test-prune-design.md`(§8 첫 글머리의 「그 브랜치는 PR 2 · 3 의 대상 일부(…)도 고친다.」 한 문장)
- 기록: `$TMPDIR/e4-pr2/`(git 밖)

**Interfaces:**
- Produces: `B0`(이 과제 끝 HEAD — 과제 8 의 옛 사본) · `$TMPDIR/e4-pr2/before-ids/<파일>.txt`(케이스 id 목록) · `before-times.tsv` · `targets.txt` · `time.sh`.

- [ ] **Step 1: 근거 자리가 그대로인지 본다** — 아래를 이 HEAD 에서 연다. 줄이 밀렸으면 `anchors.tsv` 에 새 번호를, 글이 달라졌으면 그 행을 고치기 전에 멈추고 보고한다.
  - `conductor_branch_fixture.py` `StateRepo.setUp` 의 환경 패치(:50–52) · `clone` 의 `file://` 원격(:78).
  - `setUp` 을 가진 StateRepo 하위 클래스: `test_conductor_branch.py` Write(:415) · WriteFloorGuards(:502) · Publish(:595) · Delete(:1030) · `test_conductor_cross.py` CrossRepo(:40) · Show(:172) · `test_conductor_status.py` StatusRepo(:40) · `test_conductor_mail.py` MailRepo(:58) · `test_leader_seat.py` TeamRepo(:36). 다섯 파일에 이 밖의 `setUp` · `setUpClass` · `tearDown` 이 없다.
  - status 에서 표지 수정 시각에 기대는 케이스가 스스로 `os.utime` 을 건다(:181 · :187 · :204 · :214 · :271) · `conductor_status._claimed_at`(scripts/conductor_status.py:246–250).
  - `test_conductor_ledger.py` `Repo`(:64–81 — 경로 꼴 클론 `git clone -q str(self.o)`) · 하위 `setUp` 여섯(:1036 · :1448 · :1627 · :1718 · :2108 · :2363 — 그 가운데 RecordedPrs :1718 는 `self.t` 를 가짜 gh 본문에 박는다) · LiveAgent.test_unexpected_error_is_rc3_not_none(:755–768).
  - `test_ledger_marker.py` MarkerTest(:29–30) · ResumeNoteTest(:157–158) · `test_brief_review_state.py` `_state`(:256–266) · `test_suite_lock.py` Lock(:35–38 · `_unmovable_stale` :173–177).
- [ ] **Step 2: #347 과의 겹침** — `git fetch -q origin feature/switch-retirement` 뒤 `git diff --name-only origin/main...origin/feature/switch-retirement -- 'plugins/spec-distill/tests/*'` 에 Global Constraints 의 고칠 열 파일이 없다. 양성 대조: 같은 명령이 `plugins/spec-distill/tests/test_epic_conductor_skill.sh` 를 찾는다. 겹치면 멈추고 보고한다.
- [ ] **Step 3: 설계 §8 한 문장을 바로잡는다(K8)** — Step 2 의 diff 로 그 문장이 든 일곱(`test_conductor_ledger.py` · `test_parallel_recommend.py` · `test_framing_review_contract.sh` · `test_seed_edit_screen.sh` · `test_handover_repairs.sh` · `test_merge_check.sh` · `test_epic_conductor_skill.sh`)이 지금 diff 에 있는지 본다. 2026-11-28 실측대로 `test_epic_conductor_skill.sh` 하나뿐이면 문장을 이렇게 바꾼다: 「그 브랜치(2026-11-28 머리 `56b5117c` 기준)가 고치는 파일 가운데 이 설계의 대상은 §4 의 받은 것 `test_epic_conductor_skill.sh` 하나다 — PR 2 · 3 의 대상(`test_conductor_ledger.py` · `test_parallel_recommend.py` 등)은 고치지 않는다(두 파일을 마지막으로 고친 것은 #345 다).」 실측이 다르면 실측대로 쓴다. 그 아래 글머리 셋은 그대로 둔다. 커밋: `git commit -m "docs(spec): 끄기 변수 은퇴 브랜치가 고치는 대상 문장을 지금 diff 로 바로잡는다" -- docs/superpowers/specs/2026-11-26-test-prune-design.md`.
- [ ] **Step 4: 기준값** — `B0=$(git rev-parse HEAD)` 를 `$TMPDIR/e4-pr2/B0` 에. 고칠 아홉 시험 파일과 `test_conductor_state_branch_docs.py` 를 하나씩 `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v plugins/spec-distill/tests/<파일>` 로 돌려 표준 오류의 `^test_\S+ \(` 줄을 정렬해 `before-ids/<파일>.txt`, 끝의 `Ran N` · `OK`/`FAILED` 를 `before-totals.tsv` 에 적는다. 실패가 있으면 이름을 적는다(이 PR 이 만든 것이 아니다).
- [ ] **Step 5: 고치기 전 시간** — `targets.txt` 에 아홉 파일 이름(경로 없이)을 한 줄씩. `time.sh <목록> <결과 tsv> <로그 폴더>` 를 쓴다: 목록의 이름마다 `SUITE_TIMING_FILE=<결과 tsv의 절대 경로> /usr/bin/time -p python3 tools/suite/run_unittest_dir.py plugins/spec-distill/tests <이름> > <로그 폴더>/<이름>.log 2>&1` 을 한 번 돌리고, `<이름>\t<real 초>\t<시작 uptime>\t<끝 uptime>\t<rc>` 줄을 `<결과 tsv>.real` 에 더한다. 잠금 명령으로 `bash "$TMPDIR/e4-pr2/time.sh" targets.txt before-times.tsv before-logs` 를 돈다. 로그에 `FAIL:` · `ERROR:` 줄이 있으면 케이스 id 를 보고에 적는다.
- [ ] **Step 6: 기록** — `$TMPDIR/e4-pr2/recheck.md` 에 Step 1–5 의 결과를 한 줄씩. 이 과제의 커밋은 Step 3 하나다.

### Task 2: 복사 진입점과 도우미 확인 케이스

**Files:**
- Modify: `plugins/spec-distill/tests/conductor_branch_fixture.py`(끝에 함수 하나 · 클래스 하나 · import `copy`)
- Modify: `plugins/spec-distill/tests/test_conductor_branch.py`(import 줄 · `class Fixture(StateRepo)` → `StateRepoCopy` · 새 케이스 하나)

**Interfaces:**
- Produces:
  - `copy_repo(src: Path, dst: Path) -> None` — `shutil.copytree(str(src), str(dst), symlinks=True, dirs_exist_ok=True)`(기본 `copy2` — 수정 시각을 옮긴다). 그 뒤 `dst` 바로 아래 폴더 가운데 `.git` 폴더가 있는 것(클론)마다: `git config --get remote.origin.url` 이 값을 내면, 그 값이 `file://` 로 시작하면 그 뒤를, 아니면 값 전체를 경로로 보고 머리의 `str(src)` 를 `str(dst)` 로 바꿔(꼴은 그대로 — `file://` 는 `file://` 로) `git remote set-url origin <새 값>` 을 하고, 이어 `git update-index -q --refresh` 를 한다. git 은 이 모듈의 `ENV` 로 부르고 실패하면 예외(`check=True`).
  - `class StateRepoCopy(StateRepo)` — 
    - `build(self) -> None`: 클래스의 견본 준비. 기본은 아무것도 하지 않는다. 하위 클래스는 `super().build()` 를 먼저 부른다.
    - `setUpClass(cls)`: `super().setUpClass()` → `mock.patch.dict(os.environ, GIT_ENV)` 시작 · `cls.addClassCleanup(<그 patcher>.stop)` → `maker = cls()`(메서드 이름 없이 — `runTest` 기본) → 만든 직후의 `vars(maker)` 키를 적어 둔다 → `StateRepo.setUp(maker)` → `cls.addClassCleanup(shutil.rmtree, str(maker.t), True)` → `maker.build()` → (`try/finally` 로 실패해도) `maker.doCleanups()`. `cls._tpl = maker.t`, `cls._tpl_attrs = {이름: 값}` = 그 뒤 `vars(maker)` 에 더해진 것 가운데 `t` 를 뺀 것(K2).
    - `setUp(self)`: `StateRepo.setUp` 과 같은 환경 패치(`addCleanup` 으로 되돌림) → `self.t = Path(tempfile.mkdtemp())` → `copy_repo(self._tpl, self.t)` → `_tpl_attrs` 마다: 값이 `self._tpl` 아래 `Path` 면 `self.t / <상대 경로>`, 아니면 `copy.deepcopy(값)` 을 그 이름으로 둔다. `tearDown` 은 `StateRepo` 것(rmtree)을 그대로 쓴다.
  - 클래스 독스트링 · 함수 독스트링은 무엇을 하는지와 복사 계약 ③(수정 시각이 견본 때로 실린다 — 그 값에 기대는 케이스는 스스로 `os.utime`)만 적는다. 배경 · 이력을 적지 않는다.

- [ ] **Step 1: 실패하는 도우미 확인을 쓴다** — `test_conductor_branch.py` 의 import 줄에 `StateRepoCopy` · `copy_repo` 를 더하고, `class Fixture(StateRepo):` 를 `class Fixture(StateRepoCopy):` 로 바꾼 뒤 그 클래스 끝에 넣는다(계획이 쓴 테스트 코드):

```python
    def test_copies_keep_their_own_remote_and_no_template_path(self):
        """한 번 지어 복사하는 진입점(copy_repo) — 사본마다 원격은 그 사본의 bare 레포이고, 사본의 어느 파일에도 견본 경로가 없고,
        작업 폴더 지문이 두 번 같다. 원격 주소는 `file://` 꼴(StateRepo)과 경로 꼴(지휘 원장 Repo) 둘 다 고친다."""
        tpl = self.t / "tpl"
        copy_repo(self._tpl, tpl)
        self.claim(repo=tpl / "w")
        CB.ensure(tpl / "w", rm(ALPHA), SID)                                     # 견본에 표지 · 상태 브랜치 · 기계 상태를 둔다
        a, b = self.t / "a", self.t / "b"
        copy_repo(tpl, a)
        copy_repo(tpl, b)
        for c in (a, b):
            self.assertEqual(self.g("remote", "get-url", "origin", repo=c / "w"), "file://%s" % (c / "o.git"))
            self.assertEqual(self.snap(c / "w"), self.snap(c / "w"))
        self.assertTrue((a / "w" / ".claude").is_dir())                         # 양성 대조 — 상태 폴더가 실려 왔다
        needle = str(tpl).encode("utf-8")
        left = [str(p) for p in a.rglob("*") if p.is_file() and "objects" not in p.parts and needle in p.read_bytes()]
        self.assertEqual(left, [])
        self.g("push", "-q", "origin", "trunk:refs/heads/only-a", repo=a / "w")
        self.assertEqual(self.g("rev-parse", "refs/heads/only-a", repo=a / "o.git"), self.g("rev-parse", "trunk", repo=a / "w"))   # 양성 대조
        for other in (b / "o.git", tpl / "o.git", self._tpl / "o.git"):
            self.assertEqual(self.g("rev-parse", "--verify", "-q", "refs/heads/only-a", repo=other, check=False), "", other)
        p, q = self.t / "p", self.t / "q"                                       # 경로 꼴 원격
        subprocess.run(["git", "init", "-q", "--bare", "-b", "trunk", str(p / "o.git")], env=ENV, check=True)
        subprocess.run(["git", "clone", "-q", str(p / "o.git"), str(p / "w")], env=ENV, capture_output=True, check=True)
        copy_repo(p, q)
        self.assertEqual(self.g("remote", "get-url", "origin", repo=q / "w"), str(q / "o.git"))
```

- [ ] **Step 2: 실패를 본다** — `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v plugins/spec-distill/tests/test_conductor_branch.py -k Fixture`. 기대: `ImportError`(`StateRepoCopy` · `copy_repo` 가 없다).
- [ ] **Step 3: `copy_repo` · `StateRepoCopy` 를 쓴다** — 위 Interfaces 그대로.
- [ ] **Step 4: 지나는지 본다** — 같은 명령. 기대: Fixture 다섯 케이스 OK(있던 넷 + 새 하나). 그리고 `python3 -m unittest -v plugins/spec-distill/tests/test_conductor_branch.py` 전체 OK, 케이스 id 목록 = `before-ids` + 새 케이스 하나.
- [ ] **Step 5: 새 케이스의 이빨(구현 보고에 싣는다)** — `git archive HEAD` 사본(고친 두 파일을 덮은 것)에서 `copy_repo` 를 셋으로 따로 망가뜨려 `-k Fixture` 를 돈다: (가) `remote set-url` 부름을 지움 → `file://` url 단언 ✗ · (나) `update-index` 부름을 지움 → snap 단언 ✗ · (다) 경로 꼴 갈래를 지움(`file://` 로 시작하지 않으면 그대로 둔다) → 마지막 url 단언 ✗. 망가뜨리지 않은 사본은 OK(양성 대조). 셋 가운데 하나라도 붉지 않으면 멈추고 보고한다.
- [ ] **Step 6: 커밋** — `git commit -m "test(spec-distill): 지휘 상태 레포를 한 번 지어 복사하는 진입점과 그 확인을 더한다" -- plugins/spec-distill/tests/conductor_branch_fixture.py plugins/spec-distill/tests/test_conductor_branch.py`.

### Task 3: `test_conductor_branch.py` — StateRepo 클래스 전부를 견본 복사로

**Files:**
- Modify: `plugins/spec-distill/tests/test_conductor_branch.py`(`(StateRepo)` 바탕 22곳 · 넷의 `setUp`)

**Interfaces:**
- Consumes: 과제 2 의 `StateRepoCopy`(`build` 훅).

- [ ] **Step 1: 바꾼다** — 이 파일의 `class <이름>(StateRepo):` 를 모두 `(StateRepoCopy)` 로(Fixture 는 과제 2 에서 바꿨다). Write · WriteFloorGuards · Publish · Delete 의 `def setUp(self):` 를 `def build(self):` 로, 그 첫 줄 `super().setUp()` 을 `super().build()` 로 — 몸의 다른 줄은 그대로. `unittest.TestCase` 직속 클래스(Showing · WriteBoundary · LetterNames · PublishBoundary · DeleteBoundary · PathShape · DoneStages)는 그대로. 쓰지 않게 된 import(`StateRepo`)가 있으면 지운다.
- [ ] **Step 2: 돈다** — `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v plugins/spec-distill/tests/test_conductor_branch.py`. 기대: OK, 케이스 id 목록 = 과제 2 Step 4 와 같다. 실패가 나면 그 케이스 id 와 traceback 을 적고, 그 케이스가 견본의 무엇(수정 시각 · 원격 · index · 깊은 복사한 값)에 기대는지 가린 뒤 복사 계약 안에서 고친다 — 케이스의 단언은 고치지 않는다. 계약 밖이면 멈추고 보고한다.
- [ ] **Step 3: 견본을 클래스마다 한 번만 짓는지 본다(AC4 — 구현 보고)** — `$TMPDIR` 의 스크립트로 `conductor_branch_fixture.StateRepo.setUp` 을 부른 횟수를 세는 감싸개를 `mock.patch.object` 로 걸고 이 파일의 suite 를 돌린다. 기대: 그 횟수 = 이 파일에서 테스트가 있는 `StateRepoCopy` 하위 클래스 수(케이스 수가 아니다).
- [ ] **Step 4: 커밋** — `git commit -m "test(spec-distill): conductor_branch 테스트가 지휘 상태 레포를 클래스마다 한 번 지어 복사한다" -- plugins/spec-distill/tests/test_conductor_branch.py`.

### Task 4: cross · status · mail · leader_seat — 견본 복사로

**Files:**
- Modify: `plugins/spec-distill/tests/test_conductor_cross.py`(CrossRepo :38–44 · Show :171–176 · import)
- Modify: `plugins/spec-distill/tests/test_conductor_status.py`(StatusRepo :39–44 · import)
- Modify: `plugins/spec-distill/tests/test_conductor_mail.py`(MailRepo :56–64 · import)
- Modify: `plugins/spec-distill/tests/test_leader_seat.py`(TeamRepo :33–42 · import)

**Interfaces:**
- Consumes: 과제 2 의 `StateRepoCopy`.

- [ ] **Step 1: 바꾼다** — CrossRepo · StatusRepo · MailRepo · TeamRepo 의 바탕을 `StateRepoCopy` 로, 넷과 Show 의 `setUp` → `build`(`super().setUp()` → `super().build()`). `Quiet` 은 `StateRepo` 그대로(K4). `TeamRepo.foreign_edit` 은 고치지 않는다 — `self.t` · `self.o` 가 사본 쪽이라 둘째 클론이 사본의 원격에서 뜬다.
- [ ] **Step 2: 돈다** — 네 파일과 `test_conductor_ledger.py`(`PendingSeat` 가 `TLS.TeamRepo` 를 바탕으로 쓴다)를 하나씩 `-v` 로. 기대: 다섯 모두 OK, 케이스 id 목록이 `before-ids` 와 같다. 실패는 과제 3 Step 2 와 같이 다룬다. status 실패면 그 케이스가 표지 수정 시각에 기대는지 먼저 본다(복사 계약 ③).
- [ ] **Step 3: 커밋** — `git commit -m "test(spec-distill): cross · status · mail · leader_seat 테스트가 지휘 상태 레포 견본을 복사한다" -- <네 경로>`.

### Task 5: `test_conductor_ledger.py` — 바탕 견본(경로 꼴 원격)과 정리 차례

**Files:**
- Modify: `plugins/spec-distill/tests/test_conductor_ledger.py:31`(import) · `:64-81`(`Repo`)

**Interfaces:**
- Consumes: 과제 2 의 `copy_repo`.
- Produces(이 파일 안): `Repo.setUpClass` — `cls._tpl = Path(tempfile.mkdtemp())` · `cls.addClassCleanup(shutil.rmtree, str(cls._tpl), True)` · 지금 `Repo.setUp` 의 짓는 줄 그대로를 `cls._tpl` 아래에서(o.git bare · 경로 꼴 클론 w · 로드맵 · notes · 커밋 · push · set-head). `Repo.setUp` — `self.t = Path(tempfile.mkdtemp())` → `self.addCleanup(shutil.rmtree, str(self.t), True)`(가장 먼저 건다 — 가장 늦게 돈다) → `copy_repo(self._tpl, self.t)` → `self.o, self.w = self.t / "o.git", self.t / "w"`. `Repo.tearDown` 은 지운다. 하위 클래스 `setUp` 여섯은 그대로(케이스마다 돈다 — RecordedPrs 의 가짜 gh 본문은 사본 경로를 박는다).

- [ ] **Step 1: 실패를 먼저 본다(정리 차례)** — 빈 폴더 `$TMPDIR/e4-pr2/sweep-ledger-before` 를 TMPDIR 로 주고 `python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py -k LiveAgent` 를 돈 뒤 그 안의 `tmp*` 를 센다. 기대: 1(chmod 0 폴더 안 machine.md · conducting-by).
- [ ] **Step 2: 바꾼다** — Interfaces 그대로. import 줄을 `from conductor_branch_fixture import BETA, copy_repo` 로.
- [ ] **Step 3: 돈다** — 파일 전체 `-v`. 기대: OK · 케이스 id 목록 = `before-ids`. 새 빈 TMPDIR 로 Step 1 을 다시 돌리면 0. `Repo` 하위 클래스의 사본 하나에서 `git -C <사본 w> remote get-url origin` 이 `<사본>/o.git`(경로 꼴)인지 `$TMPDIR` 의 스크립트로 한 번 본다(구현 보고).
- [ ] **Step 4: 커밋** — `git commit -m "test(spec-distill): conductor_ledger 테스트가 바탕 레포를 클래스마다 한 번 지어 복사하고 정리를 cleanup 으로 돈다" -- plugins/spec-distill/tests/test_conductor_ledger.py`.

### Task 6: 임시 폴더를 남기던 시험 셋의 정리

**Files:**
- Modify: `plugins/spec-distill/tests/test_ledger_marker.py:29-30 · :157-158`
- Modify: `plugins/spec-distill/tests/test_brief_review_state.py:256-266`
- Modify: `plugins/spec-distill/tests/test_suite_lock.py:35-38`

- [ ] **Step 1: 실패를 먼저 본다** — 파일마다 새 빈 TMPDIR(`$TMPDIR/e4-pr2/sweep-<이름>-before`)로 `python3 -m unittest plugins/spec-distill/tests/<파일>` 을 돌려 남은 `tmp*` 를 센다. 기대: ledger_marker 20 · brief_review_state 8 · suite_lock 2.
- [ ] **Step 2: 고친다** —
  - `test_ledger_marker.py` 두 `setUp`: `base = Path(tempfile.mkdtemp())` · `self.addCleanup(shutil.rmtree, str(base), True)` · `self.d = base / "k"`(MarkerTest 는 이어 `self.d.mkdir()`). `shutil` import 가 없으면 더한다.
  - `test_brief_review_state.py` `_state`: mkdtemp 바로 뒤 `self.addCleanup(shutil.rmtree, str(d), True)`.
  - `test_suite_lock.py` `Lock`: `setUp` 첫머리에서 `self.addCleanup(shutil.rmtree, str(self.t), True)` 를 걸고(mkdtemp 바로 뒤) `tearDown`(:37–38)을 지운다 — `_unmovable_stale` 이 뒤에 건 chmod 되돌리기가 먼저 돈다. 다른 클래스의 `tearDown`(:242)은 그대로.
- [ ] **Step 3: 돈다** — 세 파일 각각 OK · 케이스 id 목록 = `before-ids`. Step 1 을 새 빈 TMPDIR 로 다시 돌려 셋 다 0.
- [ ] **Step 4: 커밋** — `git commit -m "test(spec-distill): 임시 폴더를 남기던 표지 · 원장 · 잠금 시험이 끝에 지운다" -- <세 경로>`.

### Task 7: 이력 주석(AC11)

**Files:** Modify — Global Constraints 의 고칠 열 파일(주석 · 독스트링만)

- [ ] **Step 1: 덜기 전 커밋** — `B7=$(git rev-parse HEAD)`.
- [ ] **Step 2: 꼴 목록으로 한 번 훑는다** — `git grep -n -E '과제 ?[0-9]+|Task ?[0-9]+|검수 지적|리뷰 지적|R[0-9]+ 수정|Review Focus|Deferred [0-9a-f]{8}|\b[0-9a-f]{7,40}\b|20[0-9]{2}-[0-9]{2}-[0-9]{2}.*고쳤' -- <열 파일>` 의 줄을 `history.tsv` 에 적고 줄마다 가른다: 주석 · 독스트링 안의 이력 조각(예: `# 과제 5 리뷰 M4` · `# R3 AC21 · Review Focus 1 · B3` 의 `Review Focus 1` · ledger 머리 「(R5 계획 3 Task 4). 뒤 Task 가 클래스를 더한다.」 · `(R8 계획 2 Task 2 · AC17 · §4)` 의 `R8 계획 2 Task 2`)은 덜고, 요구 앵커(AC · M · I · J · B · § · R3 AC 등)와 무엇을 지키는지 · 왜 그 꼴인지 말하는 글은 남긴다(예: :495 · :532 의 「과제 6 이 받아 오게 한다」 는 「받아 오는 길은 Publish 가 잰다」 처럼 지키는 것으로 다시 쓴다). 문자열 안의 시험 데이터(`"- Task 1 끝\n"` · `"aaaa1111"` · `"abc12345"` 등)는 건드리지 않는다.
- [ ] **Step 3: 지운 이름을 부르는 주석이 없는지 본다** — 열 파일의 주석 · 독스트링에 `tearDown`(ledger `Repo` · suite_lock `Lock` 에서 지웠다) · 이름을 바꾼 `setUp`(과제 3 · 4 의 아홉 클래스)을 그 클래스의 것으로 부르는 글이 없다(`git grep -n -E '#.*(setUp|tearDown)|""".*(setUp|tearDown)'`). 있으면 지금 이름(`build` · cleanup)으로 고친다.
- [ ] **Step 4: 주석만 바뀌었는지 본다** — 파일마다 `python3 -c 'import ast,sys; print(ast.dump(ast.parse(open(sys.argv[1],encoding="utf-8").read())))'` 를 `git show "$B7":<파일>` 과 지금 파일에 돌려 `cmp`. 독스트링을 고친 파일은 다르게 나온다 — 그때는 `git diff "$B7" -- <파일>` 의 hunk 가 모두 주석 · 독스트링인지 사람이 읽어 보고에 싣는다.
- [ ] **Step 5: 돈다 · 커밋** — 고친 파일을 다시 돌려 OK · 케이스 id 목록 그대로. `git commit -m "test(spec-distill): 지휘 상태 레포 테스트에서 이력 주석을 덜어 낸다" -- <고친 경로>`. 후보가 없던 파일은 「없음」 으로 보고한다.

### Task 8: 보안 변이 견주기 · 순서 섞기 · 견본 짓기의 환경(AC7 — 구현 보고)

**Files:** 없음(`$TMPDIR/e4-pr2/` — 코드를 바꾸지 않는다)

**Interfaces:**
- Consumes: `B0`(과제 1) · HEAD(과제 7 뒤).

- [ ] **Step 1: 사본 둘** — 옛 = `git archive "$B0"`, 새 = `git archive HEAD` 를 `$TMPDIR/e4-pr2/old` · `new` 아래에 뜬다. 변이마다 두 사본을 새로 뜨거나, 건 변이를 되돌린 뒤 `cmp` 로 원본과 같은지 확인하고 다음으로 간다.
- [ ] **Step 2: 자리 일곱 × 변이 넷** — 사본마다 같은 글자로 걸고, 그 줄의 클래스만 `cd <사본> && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v plugins/spec-distill/tests/<파일> -k <클래스>…` 로 돈다(자리는 `plugins/spec-distill/scripts/` 아래).
  - **M1 지우기 확인 끝**(`conductor_branch.py` — branch `Delete` · `DeleteGateGuards`): 삭제 = `delete()` 의 `if confirmed is not None and not re.fullmatch(r"(?:[0-9a-f]{40}|[0-9a-f]{8})", confirmed):` 와 그 아래 `raise` 두 줄을 지움 · 추가 = 같은 정규식에 `|[0-9a-f]{7}` 을 더함 · 반전 = `if not _counted_tip_ok(confirmed, tip):` → `if _counted_tip_ok(confirmed, tip):` · 형태 = `_counted_tip_ok` 의 `return counted == tip[:8]` → `return counted[:4] == tip[:4]`.
  - **M2 git 문**(`conductor_branch.py` `_check_write_form` · `_check_delete_form` — branch `PublishGateGuards` · `DeleteGateGuards` · `GitGateGuards`): 삭제 = `bad = [a for a in rest if a.startswith("-") and a not in forms]` → `bad = []` · 추가 = `plain[:1] != ["origin"]` → `plain[:1] not in (["origin"], ["other"])` · 반전 = `if bad or plain[:1] != ["origin"]:` → `if not (bad or plain[:1] != ["origin"]):` · 형태 = `_check_delete_form` 의 update-ref 갈래 `OID_RE.fullmatch(rest[2])` → `OID_RE.match(rest[2])`.
  - **M3 제어 글자 거르기**(`conductor_branch.py` `visible` — cross `Show` · mail `Closures` · `Inbox` · status `Scrub`): 삭제 = 루프 몸을 `out.append(ch)` 한 줄로 · 추가 = 범주 튜플에 `"Zs"` 를 더함 · 반전 = 그 줄의 `in (` → `not in (` · 형태 = `"\\x%02x" % code` → `"\\x%x" % code`.
  - **M4 남의 고침 확인**(`leader_seat.py` `confirm` — leader_seat `Confirm` · `RulesEditForeign` · ledger `PendingSeat`): 삭제 = `if confirmed is not None and (not isinstance(confirmed, str) or not CB.OID_RE.fullmatch(confirmed)):` 와 그 아래 `raise` 두 줄을 지움 · 추가 = `if confirmed == seen:` → `if confirmed == seen or confirmed is not None:` · 반전 = `if confirmed == seen:` → `if confirmed != seen:` · 형태 = 같은 함수의 `CB.OID_RE.fullmatch(confirmed)` → `CB.OID_RE.match(confirmed)`.
  - **M5 지휘 표지**(`conductor_state.py` `acquire` — ledger `Marker` · `MarkerWrites`): 삭제 = `os.O_EXCL | ` 를 지움 · 추가 = `return "held" if owner == session else` → `return "held" if owner in (session, "") else` · 반전 = `owner == session` → `owner != session`(그 줄) · 형태 = `(session + "\n")` → `(session)`.
  - **M6 STATUS 가리기**(`conductor_status.py` `scrub` — status `Scrub` · `Shape`): 삭제 = `if CB.looks_absolute(tok):` 와 그 아래 줄을 지움 · 추가 = `roots = CM.private_roots(root)` → `roots = CM.private_roots(root) | {""}` · 반전 = `if hits:` → `if not hits:` · 형태 = `tok[:min(hits)]` → `tok[:max(hits)]`.
  - **M7 편지 about**(`conductor_mail.py` `_check_about` — mail `Send` · `Closures`): 삭제 = `if any(w.startswith(("/", "~")) for w in about.split()) or CB.looks_absolute(about):` 와 그 아래 `raise` 두 줄을 지움 · 추가 = `for base in private_roots(root):` 앞에 `if about.startswith("~/"): return` 한 줄 · 반전 = `if CB.visible(about) != about:` → `if CB.visible(about) == about:` · 형태 = `w.startswith(("/", "~"))` → `w.startswith("/")`.
  기대: 변이마다 옛 ✗ 케이스 id 집합 = 새 ✗ 케이스 id 집합(확인이 그대로이니 같아야 한다). 변이 없는 두 사본은 고른 클래스가 모두 OK(양성 대조). 옛만 잡는 id 가 있으면 Global Constraints 의 「옛만 잡는 변이」 대로 진입점을 고쳐 다시 견준다. 결과 표(자리 · 변이 · 옛 ✗ id · 새 ✗ id · 무효와 그 까닭)를 `mutations.md` 에.
- [ ] **Step 3: 도우미 확인의 이빨을 HEAD 에서 한 번 더** — 과제 2 Step 5 의 (가)–(다)를 새 사본에서 다시 걸어 같은 ✗ 를 본다(이력 주석 덜기 뒤의 HEAD).
- [ ] **Step 4: 클래스 안 순서 섞기** — `$TMPDIR/e4-pr2/shuffle.py` 를 쓴다(git 밖 · 계획이 쓴 도구):

```python
#!/usr/bin/env python3
"""클래스 안의 케이스 순서만 섞어 돈다 — 클래스 묶음은 그대로라 견본은 클래스마다 한 번 짓는다. 케이스 id 와 결과를 남긴다."""
import importlib.util
import random
import sys
import unittest
from pathlib import Path

path, seed = Path(sys.argv[1]).resolve(), int(sys.argv[2])
sys.path.insert(0, str(path.parent))
spec = importlib.util.spec_from_file_location(path.stem, str(path))
mod = importlib.util.module_from_spec(spec)
sys.modules[path.stem] = mod
spec.loader.exec_module(mod)
rng, outer = random.Random(seed), unittest.TestSuite()
for per_class in unittest.defaultTestLoader.loadTestsFromModule(mod):
    cases = list(per_class)
    rng.shuffle(cases)
    outer.addTest(unittest.TestSuite(cases))
print("seed", seed, file=sys.stderr)
sys.exit(0 if unittest.TextTestRunner(verbosity=2).run(outer).wasSuccessful() else 1)
```

  고친 여섯 파일(`test_conductor_branch.py` · `test_conductor_cross.py` · `test_conductor_status.py` · `test_conductor_mail.py` · `test_leader_seat.py` · `test_conductor_ledger.py`)을 새 빈 TMPDIR 로 `PYTHONDONTWRITEBYTECODE=1 python3 "$TMPDIR/e4-pr2/shuffle.py" plugins/spec-distill/tests/<파일> 20261128` 로 한 번씩 돌려 출력을 `shuffle-<파일>.log` 에. 기대: 여섯 모두 rc 0 · 남은 `tmp*` 0. 붉으면 그 id · traceback · seed 를 적고, 같은 seed 로 `B0` 사본에서도 붉은지 가른다(표 머리: 지금 코드의 mail · status 섞기는 통과했다 — 새로 붉으면 복사 탓이다). 복사 탓이면 진입점을 고친다.
- [ ] **Step 5: 견본 짓기의 환경(K11)** — `$TMPDIR/e4-pr2/hook/` 에 `fired` 를 만드는 실행 가능한 `pre-push` 훅과 `[core]\n\thooksPath = <그 폴더>` 인 `gitconfig` 를 둔다. (가) 양성 대조: 그 폴더의 빈 bare · 클론에서 `GIT_CONFIG_GLOBAL=<gitconfig> git push` → `fired` 가 생긴다(지운다). (나) 새 사본에서 `GIT_CONFIG_GLOBAL=<gitconfig> python3 -m unittest plugins/spec-distill/tests/test_conductor_branch.py -k Write -k Publish -k Delete` → OK · `fired` 없음. (다) 이빨: 새 사본의 `conductor_branch_fixture.py` `GIT_ENV` 에서 `"GIT_CONFIG_GLOBAL": "/dev/null", ` 를 지우고 (나)를 돌린다 → `fired` 가 생긴다. 세 결과를 보고에.
- [ ] **Step 6: 기록** — `mutations.md` · 섞기 로그 · 환경 결과를 `$TMPDIR/e4-pr2/impl-report.md` 에 옮긴다. 커밋 없음.

### Task 9: 마무리 — 뒤 시간 · 폴더 한 바퀴 · 점검 · 리뷰 · 미룸 · 대조 · PR 재료

**Files:**
- Modify: `docs/superpowers/specs/2026-11-26-test-prune-design.md`(`## 미룸` 표 — 미룬 것이 있을 때만)

- [ ] **Step 1: 뒤 시간(AC4)** — 잠금 명령으로 `bash "$TMPDIR/e4-pr2/time.sh" targets.txt after-times.tsv after-logs`. 파일마다 앞 · 뒤 · 차이 · 부하(uptime)를 표로(`times.md`). 표 「줄어드는 초」 가 음수인 여섯에서 뒤가 앞보다 작지 않거나, 정리만 고친 셋(≈0)의 뒤가 앞보다 크면 까닭(부하 · 흔들림 · 다른 세션과 겹침)을 적어 지휘자에게 알린다(PR 본문에 싣고 사용자 승인을 받는다). 로그의 `FAIL:` · `ERROR:` 줄은 케이스 id 와 함께 보고한다.
- [ ] **Step 2: 폴더 한 바퀴 — 남은 폴더 0(AC4 · K10)** — 새 빈 폴더 `$TMPDIR/e4-pr2/sweep-all` 을 TMPDIR 로 주고 잠금 명령으로 `python3 tools/suite/run_unittest_dir.py plugins/spec-distill/tests` 를 한 번 돈다(`> sweep-all.log 2>&1`). 기대: rc 0 · 그 폴더 안의 항목 0(`find "$TMPDIR/e4-pr2/sweep-all" -mindepth 1 -maxdepth 1 | wc -l`). 남은 것이 있으면 이름과 안의 파일로 어느 모듈인지 가리고 — 이 PR 의 대상이면 고치고, 대상 밖이면 설계 `## 미룸` 후보로 보고에 적는다. 실패 줄은 케이스 id 와 함께 적고, 같은 모듈을 `B0` 사본에서도 돌려 이 PR 의 실패인지 가른다.
- [ ] **Step 3: §5 점검(AC9 · AC10)** — 구현 보고에 기대는 꼴마다 한 줄: 지움을 막는 문서(지운 파일 없음 — `git diff --name-only --diff-filter=D origin/main...HEAD` 가 비었다) · 실행 · 목록 요구(대상 파일 이름을 `git grep -l -F` 로 `'plugins/*/tests/*' 'shared/tests/*'` 에서 찾아 부르는 쪽이 그대로 도는지) · import(`test_conductor_ledger.py` ← `test_leader_seat.py` · 픽스처를 import 하는 `test_conductor_state_branch_docs.py` 를 돌려 OK) · `# guards:` · 실패 원장 등재(대상 이름 그대로) · 부재 락 코퍼스. 그리고 하나씩 돌려 통과를 본다: `bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh` · `bash shared/tests/test_charter_citations.sh` · `bash plugins/spec-distill/tests/test_epic_conductor_skill.sh` · `bash plugins/spec-distill/tests/test_begin_round_snapshot.sh` · `bash shared/tests/test_presence_corpus_behavior.sh` · `bash shared/tests/test_no_new_duplication.sh`. 실패가 있으면 `B0` 사본에서도 같은지 가른다.
- [ ] **Step 4: 판 · 금지 파일(AC12 · AC14)** — `git diff --name-only origin/main...HEAD` 에 `plugin.json` · `CHANGELOG.md` · `test_stage_prose_trim.sh` · `docs/testing.md` · `docs/removed-tests.md` 가 없고, 바뀐 파일이 Global Constraints 의 열 파일 · 설계문서 · 이 계획뿐이다. `git ls-files -s` 로 바뀐 파일의 모드가 `B0` 와 같다.
- [ ] **Step 5: push** — `git push`.
- [ ] **Step 6: 마지막 전체 리뷰** — 아래 「마지막 전체 리뷰에 싣는 것」 대로 띄우고, 리뷰의 AC 보고를 git 이 추적하지 않는 `$TMPDIR/e4-pr2/ac-report.md` 에 쓴다. 이 PR 몫이 아닌 AC 는 보고에 이렇게 적게 한다: AC3 · AC5 · AC6 · AC15 · AC16 · AC17 「미룸 — 다른 PR」, AC8 「해당 없음 — 사라진 확인 없음」(지운 단언이 없음을 리뷰가 확인한 뒤).
- [ ] **Step 7: 미룸** — 리뷰가 「미룸」 · 「빠짐」 으로 낸 AC(AC13 과 다른 PR 몫은 올리지 않는다)와 리뷰 후속으로 미룬 것 · Step 2 의 대상 밖 남은 폴더를 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 한 줄씩 더하고 커밋한다(`docs(spec): …` · 같은 꼬리). 없으면 건너뛴다.
- [ ] **Step 8: 묶음 대조** — `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/9.3.0/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-26-test-prune-design.md "$TMPDIR/e4-pr2/ac-report.md" --acs "AC1,AC2,AC4,AC7,AC9,AC10,AC11,AC12,AC13,AC14"` 의 출력(경고 포함)을 그대로 지휘자에게 보인다.
- [ ] **Step 9: PR 본문 재료(AC1 · AC2)** — 지휘자에게 넘긴다: 승인 표(`table-pr2-final.md` 그대로) · 승인 줄(설계문서 끝 「판정 표 승인 · 2026-11-28 · PR 2」) · 읽은 담당자 A 와 다시 읽은 담당자 B(서로 다른 Opus 하위 agent)와 갈린 4행(표 「A·B 갈림」 칸이 「예」 인 행 — A · B 원문 그대로) · 앞 · 뒤 초 표 · 변이 표 · 섞기 · 환경 결과 · §5 점검 · 폴더 한 바퀴의 남은 폴더 0 · 「사라진 확인 없음 — `docs/removed-tests.md` 줄 없음」. PR 을 여는 일은 지휘자의 흐름이다.

## 마지막 전체 리뷰에 싣는 것

- 범위: `origin/main...HEAD` 전체. 리뷰어는 쓰기 도구가 없는 agent 다(Law 2).
- 설계문서 `## Acceptance Criteria` 원문 · 승인 표 원문 · 이 계획의 `## AC 가르기` · `## 계획의 판단` 표.
- 요청: 이 PR 몫 AC(`AC1,AC2,AC4,AC7,AC9,AC10,AC11,AC12,AC13,AC14`)마다 한 줄 `AC<n>: <구현됨|미룸|빠짐> — <근거(파일:줄 · 테스트 이름 · 명령 결과)>`. AC13 은 「미룸 — 지휘자 대조」. AC3 · AC5 · AC6 · AC15 · AC16 · AC17 은 「미룸 — 다른 PR(PR 1 · 3 · 정리 PR · 로드맵 끝)」. AC8 은 「해당 없음 — 사라진 확인 없음」 이 맞는지(지운 단언이 없는지) 확인한다. AC1 · AC2 의 PR 본문 몫은 「PR 본문 재료 · 과제 9 Step 9」 를 근거로.
- 요청: 설계문서 `## 있는 것 검토` 가 고른 것을 실제로 썼는지, 같은 것을 다시 만들지 않았는지 — 준비물은 있는 도우미 `conductor_branch_fixture.py` 옆에 얹었는가(새 도우미 파일 없음 · `StateRepo` 그대로) · 시간은 `tools/suite/` 의 시간 기록(`run_unittest_dir.py` · `SUITE_TIMING_FILE`)으로 공유 잠금 아래 대상 파일만 쟀는가 · 기준은 `docs/testing.md` 그대로인가 · 점검에 `test_guards_coverage_bidirectional.sh` · `test_charter_citations.sh` 를 썼는가 · 평가 장치를 쓰지 않았는가.
- 끝에서 끝을 따로 물어라: 견본을 클래스마다 한 번만 짓는가(케이스마다가 아니다) · 견본을 짓는 동안 GIT_ENV 가 걸려 있는가 · 사본마다 클론의 원격이 그 사본의 bare 인가(`file://` 와 경로 꼴 둘 다) · 복사 뒤 index 를 새로 하는가 · 깊은 복사한 값 밖에 케이스끼리 나누는 객체가 없는가 · 표지 수정 시각에 기대는 케이스가 스스로 utime 을 거는가 · LiveAgent · Lock 의 정리가 chmod 되돌리기 뒤에 도는가 · 고친 뒤 케이스 id 목록이 고치기 전과 같은가(새 케이스 하나 밖) · 변이 표에서 옛 · 새 ✗ id 가 같은가.
- 계획이 쓴 테스트 코드(과제 2 Step 1)와 계획이 정한 판정(K1–K11)은 계획이 정한 것이라고 밝혀 같은 눈으로 보게 한다. 고친 기존 시험에서 단언 줄이 지워지거나 느슨해지지 않았는지 `git diff "$B0" -- 'plugins/*/tests/*'` 로 보게 한다 — 이력 주석 덜기(과제 7)는 주석 · 독스트링만이어야 한다.

## 테스트할 자리와의 대응

| 설계 「테스트할 자리」 | 이 계획 |
|---|---|
| 한 번 지어 복사하는 준비물 도우미(지휘 상태 레포) — 복사본끼리 상태를 나누지 않고 원본 절대 경로가 남지 않는다 | 과제 2 Step 1 의 케이스(`test_conductor_branch.py` Fixture 안 · 두 원격 꼴) · Step 5 의 이빨 셋 · 과제 8 Step 3 |
| 옮기거나 합친 확인 — 전에 잡던 것을 옮긴 뒤에도 잡는다(보안은 변이 넷 · 양성 대조) | 옮긴 확인은 없다 — 준비를 바꾼 보안 범위는 과제 8 Step 2(옛 · 새 ✗ id 가 같다) · 순서 섞기 과제 8 Step 4 |
