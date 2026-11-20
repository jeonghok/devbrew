# 지휘자 상태 브랜치 · 편지함 — 계획 2(리더가 쓰는 자리 · 작은 수리 다섯) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** team 형식 로드맵에서 리더가 쓰는 것 — 규칙 고침(`RULES.md` 사본)과 대기 줄(`pending.md`) — 이 상태 브랜치에 살고, 시작 묶음 · 「묶음 낡음」 · `flush` 가 그 자리를 읽되 남이 올린 고침은 사용자가 확인하기 전에 쓰지 않으며, R1 이 넘긴 작은 수리 다섯과 계획 1 이 남긴 것을 마친다.

**Architecture:** 쓰는 쪽은 새 스크립트 하나(`leader_seat.py` — 규칙 사본 고침 · 규칙 브랜치 · 남의 고침 확인 · 대기 줄)가 맡고 명령줄은 `conductor_branch.py` 의 하위 명령으로 연다. 읽는 쪽(규칙을 읽을 끝 · 남의 고침 세기)은 상태 계산의 닫힘 안에 있는 `team_status.py` 에 두어 상태 계산과 시작 묶음이 같은 함수를 부른다. 「이 기계가 쓴 커밋」 은 상태 브랜치 쓰기의 바닥(`conductor_branch._write_floor`)이 기계 상태의 새 절에 적는다 — 어느 쓰기도 그 기록을 빠뜨릴 수 없다.

**Tech Stack:** Python 3(레포의 `python3` 는 3.9.6 — 3.9 문법만) · git(2.54) · bash(macOS 3.2 호환) · unittest · `shared/tests/assert.sh`.

**Spec:** `docs/superpowers/specs/2026-11-19-conductor-state-branch-design.md` — 이 계획은 그 문서가 나눈 둘 가운데 **계획 2**(§5 · §9 · `## Files to Modify` 의 계획 칸이 2 · 「1 · 2」 · 「PR 마다」 인 행 · `## 미룸` 표의 받는 곳 R3 행)다. 브랜치 `feature/conductor-leader-seat`. 경로는 따로 적지 않으면 `plugins/spec-distill/` 아래다.

## AC 가르기

계획 1 의 `## AC 가르기` 표에서 「계획 2 에 남는 부분」 과 계획 2 몫을 모았다.

| AC | 몫 | 이 계획이 하는 부분 |
|---|---|---|
| AC12 | 걸침(계획 1 이 새 절차 파일의 문장 · 걸음 1 · 2 · 7 을 했다) | 지휘 절차서 걸음 5 의 줄(안 올린 규칙 고침 · 판 번호 줄) — 과제 18 |
| AC14 | 걸침(계획 1 이 쓰는 명령 · `show` 를 했다) | `leader_ref` 가 상태 브랜치를 읽게 된 뒤에도 꺼진 설정에서 기본 브랜치를 낸다 — 과제 3 · 19 |
| AC15 | 계획 2 | 전부 — 과제 3 · 4 |
| AC16 | 계획 2 | 전부 — 과제 9 |
| AC17 | 걸침(계획 1 이 STATUS 의 절과 `rules_gap` 을 했다) | 사본을 만들고 지우는 것 · `rules-branch` · 갈라졌을 때의 알림 — 과제 6 · 7 |
| AC18 | 계획 2 | 전부 — 과제 5 · 10 · 11 · 12 |
| AC19 | 걸침(계획 1 이 STATUS · 편지 · `state_branch` 를 적었다) | `team-files.md` §15 「지금의 값」 의 나머지(읽는 ref · 규칙 고침의 길 · 대기 줄) · `rules_at` — 과제 18 |
| AC20 | 걸침(계획 1 이 고친 것에 대해 했다) | 이 계획이 고친 것에 대해 같은 것 — 옛 형식 출력 그대로 · 꺼진 team 형식에서 R1 동작 그대로 — 과제 19 |
| AC21 | 계획 2 | 전부 — 과제 2 · 3 · 8 · 9 |

대조 스크립트에 주는 목록: `AC12 · AC14~AC21`. 지휘자가 센 목록과 같다.

## Global Constraints

- **범위.** 설계문서는 고치지 않는다. 설계의 글자 · 수용 기준 · 사용자에게 보이는 동작을 더하거나 바꾸는 자리는 아래 `## 계획의 판단` 에 ★ 로 표시했고, 구현 중 새로 생기면 멈추고 지휘자에게 돌려보낸다. 설계문서 `## 미룸` 표에 올릴 것은 보고에 적고 지휘자가 올린다.
- **E1 보다 먼저 · R2 계획 2 뒤에.** `start_bundle.py` · `team_write.py` · `conductor_ledger.py` · `team-files.md` 는 E1 도 예약했다(이 계획이 먼저 머지된다). R2 계획 2(`origin/feature/conductor-walk-table` · 계획 파일 `2026-11-20-conductor-walk-gates-plan2.md`)가 먼저 머지될 예정이고 `conducting.md` · `team-files.md` · `start_bundle.py` · `conductor_ledger.py` · `skills/epic-conductor/SKILL.md` · README · CHANGELOG · `test_start_bundle.sh` · `test_team_status.sh` 를 함께 고친다. 편집의 닻은 양쪽에 다 있는 글(함수 이름 · 절 제목 · 지금 있는 문장)에 두고, 그 머지 뒤 `## 머지 전 다시 셀 것` 을 하나씩 다시 센다.
- **상태 계산의 닫힘.** `tests/test_roadmap_status.sh` 의 정적 검사 목록(열여섯)과 `control_plane.CODE_STAMP_FILES` 에 **새 모듈을 넣지 않는다**. 읽기 함수는 이미 닫힘 안인 `team_status.py` · `team_layout.py` 에 둔다 — 거기 더하는 코드는 그 검사가 받는 호출만 쓴다(git 은 `roadmap_status.Git` 의 `log` · `cat-file` · `rev-parse` · `diff`, `open` · `getattr` 금지, 쓰기 금지). `team_layout.py` 는 표준 라이브러리만 가져온다. `leader_seat.py` 는 닫힘 밖이고 상태 계산이 그것을 가져오지 않는다. 닫힘의 이름 허용 목록(`READERS` 의 `conductor_state` 줄)에 새 이름 `TRUST` 하나만 더한다(과제 3 — 허용을 넓히는 고침이라 리뷰어가 본다).
- **`conductor_state.py` 의 읽기 함수.** `parse_machine` · `_check_row` 에 더하는 코드는 `in` · `==` · 미리 컴파일한 정규식의 `.fullmatch(` 만 쓴다(계획 1 과 같다).
- **닫는 판정은 정확히.** 커밋 대조 · 경로 대조 · 줄 대조 · 브랜치 이름은 `==` · `in <닫힌 목록>` · `re.fullmatch` 로만 본다. 남이 쓴 글(상태 브랜치의 규칙 사본 · `pending.md` · 커밋)을 화면에 낼 때는 `conductor_branch.visible` 을 거친다. 남의 글 때문에 명령이 예외로 죽지 않는다 — 읽지 못하면 「재지 못했다」 로 닫는 쪽(규칙은 기본 브랜치 · 대기 줄은 옮기지 않음)으로 간다.
- **종료 코드.** 새 하위 명령(`rules-add` · `rules-drop` · `rules-reset` · `rules-branch` · `confirm`)은 계획 1 의 규칙 그대로다 — 0(썼다 · 쓸 수 없어 알리고 넘어감) · 1(없음/아님 · 확인 없이 부른 `confirm` · 갈라져서 만들지 않은 `rules-branch`) · 2(사용법 · 받지 않는 값) · 3(읽기 불가 · git 실패) · 5(표지 아님). 예상 밖 예외도 3.
- **고정 글자.** 「확인되지 않은 남의 고침 %d」 · 「규칙 사본이 기본 브랜치와 갈라졌다」 · 「올릴 규칙 고침이 없다」 · 「확인할 끝: %s」 · 「남의 고침을 재지 못했다」 · 「상태 브랜치가 없어 기계 상태에 쌓았다 — ensure 뒤의 줄부터 상태 브랜치에 쌓는다」 · 「사람 줄이라 옮기지 않은 대기 줄 %d — record --human 으로 적는다」 · 「확인되지 않은 남의 고침이 더한 대기 줄 %d — 옮기지 않았다」 · 「과제 폴더 없음」 · 「묶음 낡음을 재지 못했다」(있는 상수). 스크립트의 상수로 한 번만 두고 테스트는 **글자**를 견준다.
- **레포 락(계획 1 Global Constraints 의 「레포 락」 줄 그대로).** `"python3"` 따옴표 리터럴 금지 · `open(` · `.read_text(` 에 `encoding` · `re.compile` 리터럴이 `## ` 로 시작하는 글과 3글자 이상 맞으면 RED · `team_layout.py` 밖 스크립트가 `RULES.md` · `jobs/` · `results/` 를 글자로 쓰면 RED(`Team.rules` 를 쓴다) · 같은 20줄(200자 이상) 블록이 두 파일에 있으면 RED · 새 셸 테스트는 100755(`git ls-files -s` 로 확인) · CHANGELOG 새 머리는 바로 다음 판만 · 레포 전용 글자(기본 브랜치 이름 · `feature/` · `fix/` 접두 · `docs/superpowers` · 모델 이름)를 락 대상 파일에 쓰지 않는다(과제 18 이 `leader_seat.py` 를 대상에 더한다) · `references/*.md` 는 `${CLAUDE_PLUGIN_ROOT}/references/<파일>` 꼴의 가리킴이 있어야 한다 · 문서에 `AskUserQuestion` 을 쓰지 않는다(질문은 문장으로).
- **bash 3.2.** `set -u` 아래 빈 배열은 `${arr[@]+"${arr[@]}"}` · `$var` 바로 뒤 한글은 `${var}`.
- **계획이 쓴 테스트 코드.** 아래 테스트 코드는 계획이 정한 것이다 — 구현자는 그대로 옮기되, mock 으로 거절을 흉내 내지 않고(실제 임시 레포의 실제 거절) 단언이 공허하지 않은지(빈 목록 위의 `all` · 늘 참인 비교) 옮기면서 본다. 락마다 「붉어지는 변이」 와 양성 대조를 적었다. 변이는 커밋한 뒤 `PYTHONDONTWRITEBYTECODE=1` 로 돌리고 `git checkout HEAD -- <파일>` 뒤 `git diff HEAD --stat` 이 비었는지로 되돌림을 확인한다.
- **테스트의 git.** 임시 레포만 쓴다(`tempfile.mkdtemp` · `tests/fixtures/team_repo.sh` 의 `$T`). **이 레포에 `conductor/` 브랜치를 만들지 않는다.** 이 레포의 원격 · 상태 폴더를 건드리는 테스트를 쓰지 않는다.
- **판.** spec-distill **minor**. 번호는 머지 직전 `origin/main` 위의 다음 minor(지금 예상 8.28.0 — R3 계획 1 이 8.26.0 · R2 계획 2 가 8.27.0). **판 번호 리터럴을 테스트에 쓰지 않는다** — CHANGELOG 절은 `.claude-plugin/plugin.json` 의 판으로 고른다(`"\n## [%s]" % version`).
- **커밋.** 한국어 Conventional Commits(type · scope 는 영어) · pathspec 커밋 · `git stash` · HEAD 뒤로 옮기기 · push · 다른 worktree 의 git 금지.
- **전체 스위트**는 이 줄로만 돈다(지휘자 대조와 같은 공유 잠금 — 못 잡으면 주인 · 잡은 시각을 보고한다. `--owner` 는 도는 agent 의 이름). 과제 안에서는 그 과제가 이름 댄 테스트만 돈다. 구현 담당이 하위 agent 를 띄우면 그 글에도 이 줄과 경로를 그대로 싣는다:
  `python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.19.2"/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-conductor-context-economy-brief/files/suite-lock --owner r3-impl-2 --wait 10800 -- bash -c 'bash tools/suite/run-all.sh'`

## Review Focus

설계가 뜻하지만 어느 수용 기준도 이름 대지 않는 입력이다. 줄마다 그 코드를 가진 과제에 테스트가 있다.

1. **남의 커밋 위에 이 기계가 다시 만든 커밋** — 올리기가 거절돼 원격 끝(남이 `RULES.md` 사본을 고친 커밋) 위에 `STATUS` 쓰기를 다시 만들어도, 그 남의 고침은 다음 쓰기 한 번에 「확인됨」 으로 넘어가지 않는다(과제 2 · 8 — 설계 Deferred df3f1a6d).
2. **사본이 있는데 기본 브랜치의 규칙이 그 사이 다른 PR 로 바뀜** — 시작 묶음은 사본을 싣고, `sync` 는 「규칙 사본이 기본 브랜치와 갈라졌다」 를 알리며 `rules-branch` 는 만들지 않는다(과제 7).
3. **`rules_at` 커밋이 이 클론에 없음** — 다른 클론에서 쓴 결과 파일의 `rules_at` 이 아직 받아 오지 않은 상태 브랜치 커밋이면 「묶음 낡음을 재지 못했다」 로 알리고 지어내지 않는다(과제 4).
4. **`pending.md` 에 같은 줄이 둘** — 일부러 두 번 쌓은 같은 결정 줄은 `flush` 가 하나씩 옮기고 하나씩 뺀다(다중집합 — 계획 1 J52 와 같은 규칙, 과제 9).
5. **상태 브랜치가 아직 없는 team 로드맵에서 `add`** — 기계 상태에 쌓고 알리며, 상태 브랜치가 생긴 뒤의 `pending` · `flush` 는 두 자리의 줄을 모두 보인다 · 옮긴다(과제 9).

---

## 계획의 판단

설계가 계획에 넘긴 것과 설계가 정하지 않아 이 계획이 정한 것이다. **★ 는 설계에 없던 결정**(설계의 글자 · 보이는 동작에 닿는다)이고 지휘자 보고의 같은 목록에 옮겼다.

| # | 자리 | 정한 것 | 이유 | 다른 길 |
|---|---|---|---|---|
| M1 ★ | `leader_ref` 의 자리 | `team_layout.leader_ref(default_ref, state_tip=None) -> str` 은 고르기만 한다(`state_tip` 이 있으면 그것, 없으면 `default_ref`). 끝을 계산하는 것은 `team_status.rules_tip(...)` 이고 상태 계산 · 시작 묶음이 그것을 불러 넘긴다 | 설계는 `team_layout.leader_ref()` 가 상태 브랜치를 보고 고른다고 적었다. 그 모듈은 표준 라이브러리만 가져오고(다른 모듈이 가져오므로 거꾸로 가져오면 돈다) 상태 계산의 정적 검사 대상이라 상태 브랜치 · 기계 상태를 읽는 코드를 둘 수 없다. 이름과 「여기서 고른다」 는 그대로 두고 계산을 닫힘 안의 읽기 모듈로 옮긴다 | `team_layout` 안에서 늦게 가져온다(정적 검사가 잠긴 파일 밖 로컬 import 로 잡는다) |
| M2 | 접두 글자 | `conductor/` 를 `team_layout.STATE_BRANCH_PREFIX` 한 곳으로 옮기고 `conductor_branch.STATE_BRANCH_PREFIX` 는 그 이름을 다시 내보낸다. `conductor_status.FETCH_HINT` 도 그 상수로 짓는다(계획 1 리뷰 잔여) | 닫힘 안의 `team_status` 가 상태 브랜치 이름을 알아야 한다 — `conductor_branch` 는 닫힘 밖이다 | `team_status` 에 글자를 하나 더 둔다 |
| M3 | 「이 기계가 쓴 끝」 의 기록(설계 「적는 자리」) | 기계 상태의 새 절 `확인한 끝`(칸 `끝 · 까닭 · 때 · 세션`, 까닭은 `확인` · `씀`). 상태 브랜치 쓰기의 바닥이 ref 를 옮기는 데 성공한 커밋마다 `씀` 줄을 하나 더한다(만들기 · 쓰기 · 다시 얹기 · 다시 만들기 모두 — 예외로 끝나도 그때까지 옮긴 것은 적는다). `확인` 줄은 많아야 하나이고 「여기까지는 사용자가 확인했거나 남의 고침이 없었다」 는 기준 끝이다 | 커밋을 누가 만들었는지는 원격에서 가를 수 없다(지은이 · 커밋 글은 누구나 흉내 낸다). 쓰기의 바닥에서 적으면 어느 쓰기도 빠뜨리지 않고, 남의 커밋 위에 다시 만든 커밋도 「내 커밋」 만 내 것으로 남는다(Deferred df3f1a6d) | 쓴 끝 하나만 적는다(다시 만들기가 남의 커밋을 끼고 넘어간다) · 커밋 글의 세션 칸으로 가른다 |
| M4 | 남의 고침을 세는 법 | `git log --format=%H --name-only <확인 끝>..<읽을 끝> -- <규칙 사본> <pending.md>` 가 낸 커밋 가운데 `씀` 줄에 없는 것. `확인` 줄이 없으면 `<읽을 끝>` 의 이력 전부. git 이 실패하면 `None`(재지 못함 — 쓰는 쪽은 남의 고침이 있는 것처럼 닫는다). 기계 상태를 읽지 못해도 `None` | 설계 §5 「원격에서 받아 온 커밋 가운데 이 기계의 지휘 세션이 만들지 않은 것이 규칙 사본이나 `pending.md` 를 바꿨으면」. 두 파일 밖(STATUS · 편지 · 받음 줄)을 바꾼 남의 커밋은 세지 않는다 | 모든 남의 커밋 |
| M5 | 기준 끝을 앞으로 옮기는 때 | `sync` 가 쓴 뒤 읽을 끝에서 남의 고침이 0 이면 `확인한 끝` 절을 `확인 · <그 끝>` 한 줄로 줄인다(`씀` 줄을 지운다). 남의 고침이 있으면 그대로 둔다 | 절이 끝없이 자라지 않는다. 남의 고침이 있는 동안만 `씀` 줄이 쌓인다 | 쓸 때마다 줄인다 |
| M6 ★ | 확인을 기록하는 명령(Deferred 82ffe046) | `conductor_branch.py confirm --roadmap R --session S [--confirmed <끝>]` — 표지를 쥔 세션만. `--confirmed` 가 없으면 남의 고침 커밋마다 `<8자> · <때> · <바꾼 파일>` 과 그 커밋의 차이(줄마다 `│ `, `visible` 을 거침)를 내고 마지막 줄 `확인할 끝: <40자>` 와 함께 1. 있으면(40자 또는 앞 8자) 그것이 지금 읽을 끝과 전체 일치할 때만 `확인한 끝` 을 그 끝으로 두고 0, 다르면 다시 내고 1 | `delete` 의 「수를 센 끝」 과 같은 꼴이라 지휘자가 한 가지 걸음으로 다룬다. 끝을 받지 않으면 보인 뒤에 들어온 남의 고침까지 확인된다 | 표시 없이 지금 끝을 확인한다 |
| M7 ★ | 규칙 고침 명령 | `conductor_branch.py rules-add --line "<규칙 줄>"` · `rules-drop --line "<규칙 줄>"` · `rules-reset`. 줄은 `team_rules.parse_rules` 로 한 줄짜리 규칙 꼴인지 보고(문제가 있으면 그 사유와 2) 이미 있는 줄을 또 더하거나 없는 줄을 빼면 2. 사본이 없으면 기본 브랜치의 글로 만든 뒤 고치고, 출발한 기본 브랜치 커밋을 `<로드맵 폴더>/rules-base.md`(한 줄 `기본 브랜치 커밋: <40자>`)에 함께 쓴다. `rules-reset` 은 사본과 그 파일을 지운다(설계 「되돌아오는 길」 — 규칙 PR 을 닫았을 때). 남의 고침이 있으면 셋 다 고치지 않고 1(먼저 `confirm`). team 형식이 아니면 2 | 설계 §5 「`conductor_branch.py` 의 쓰기 · 출발한 기본 브랜치 커밋을 함께 적어 둔다 · 적는 자리는 계획이 정한다」. 줄 단위 고침이라 거절 뒤 다시 만들기(줄 파일 규칙)가 그대로 맞는다. 사본 안에 적으면 사본이 기본 브랜치 글과 같아지는 때를 가를 수 없다 | 사본 맨 위의 주석 줄 · 커밋 글에 적는다 · 파일 통째로 바꾸는 명령 |
| M8 | 같아짐 · 갈라짐 | 기본 브랜치의 지금 글 == 사본 → `sync` 가 사본과 `rules-base.md` 를 지운다. 지금 글 ≠ `rules-base.md` 가 적은 커밋의 글 이고 지금 글 ≠ 사본 → 갈라짐(「규칙 사본이 기본 브랜치와 갈라졌다」). `rules-base.md` 가 없거나 읽지 못하면 갈라짐으로 본다(닫는 쪽) | 설계 §5 · AC17 | — |
| M9 | `rules-branch` | `--branch <이름>` 필수. 이름은 `conductor/` 로 시작하지 않고(`team_layout.STATE_BRANCH_PREFIX`), 레포 규칙 문서가 있으면 그 정규식이 받아야 한다(아니면 2). 기본 브랜치 끝 위에 규칙 파일만 사본 글로 바꾼 커밋 하나를 만들어 `update-ref refs/heads/<이름> <커밋> 0…0` 로 둔다(이미 있으면 3). **올리지 않는다** — PR 을 여는 것은 지금 절차대로 지휘자가 한다. 사본이 없거나 기본 브랜치와 같으면 「올릴 규칙 고침이 없다」 1 · 갈라졌으면 둘의 차이를 내고 1 · 남의 고침이 있으면 1 | 설계 §5 · AC17 「기본 브랜치에서 딴 브랜치에 그 파일만 바꾼 커밋 하나」. 브랜치 접두는 레포마다 다르다(레포 전용 값 금지) | 이름을 스크립트가 짓는다 · 올리기까지 한다 |
| M10 | `rules_at` 의 꼴 | 시작 묶음은 「맞추는 명령」 줄에 늘 `--rules-at <규칙을 읽은 커밋>` 을 싣는다(기본 브랜치와 같아도). `job sync` 의 `--rules-at` 은 `--bundle-at` · `--job-at` 과 함께만 받는다(아니면 2). 새 머리에는 `bundle_at` 바로 뒤에 `rules_at` 줄. 「끝」 줄이 없는 결과 파일에 셋을 함께 주면 `rules_at` 줄을 고치거나(없으면 `bundle_at` 줄 뒤에) 넣는다. `--rules-at` 없이 만든 머리는 지금과 바이트까지 같다 | 설계 §5 「「맞추는 명령」 줄이 그 값을 싣고 `job sync` 가 적는다」. 늘 실으면 읽는 쪽 규칙이 하나다 | 기본 브랜치와 다를 때만 싣는다 |
| M11 | `rules_at` 을 읽는 곳 | `team_files.parse_result` 가 `rules_at` 을 고를 수 있는 키로 읽는다 — 있으면 커밋 꼴이어야 하고(아니면 problem) `Result.rules_at`. 결과 대조(`job_results.py check`)는 고치지 않는다 — 꼴이 틀린 `rules_at` 은 머리 문제로 이미 거절된다. 커밋이 이 레포에 있는지는 대조하지 않는다(상태 브랜치 커밋은 받아 오기 전에는 없다) | `job_results.py` 는 R2 계획 2 가 고치는 파일이다 — 닿는 면을 줄인다 | 결과 대조에 「`rules_at` 커밋이 없다」 를 더한다 |
| M12 | 「묶음 낡음」 의 규칙 대조 | 규칙 파일은 `rules_at`(없으면 `bundle_at`) 커밋의 글과 지금 규칙을 읽을 끝(`leader_ref(main, rules_tip)`)의 글을 견준다. `rules_at` 커밋이 이 레포에 없으면 「묶음 낡음을 재지 못했다: <이름> — 규칙을 읽은 커밋 <8자> 가 이 레포에 없다」 | AC15 · 설계 §5. 리더가 고친 뒤 받은 묶음의 `rules_at` 은 그 고침을 담은 끝이라 낡지 않는다 | — |
| M13 | 「묶음 낡음」 의 빈 곳(§9) | implement 가 아닌 단계(검수는 지금처럼 뺀다)의 가장 새 시도 결과 파일이 끝 줄 없이 읽히지 않으면(글을 못 읽음 · 머리 문제 · 빠뜨린 기계 줄) 「묶음 낡음을 재지 못했다: <이름> — <첫 사유>」. implement 단계는 받음 쪽 알림이 내므로 지금처럼 건너뛴다 | 설계 §9 「결과 받음 쪽 알림과 같은 파일을 두 번 알리지 않는다」. 받음 쪽 알림(`job_results.receipt`)은 implement 단계만 본다 | 모든 단계 |
| M14 ★ | 대기 줄의 자리 | 「상태 브랜치 자리」 = 로드맵 머리말이 `layout: team` 이고 `conductor_branch.availability` 가 `None` 이고 상태 브랜치 로컬 끝이 있을 때. 그때 `add --section "쌓인 기록"` 은 `pending.md` 에 `- <에픽> · <절> · <글>` 한 줄을 더한다. 상태 브랜치가 아직 없으면 기계 상태에 쌓고 「상태 브랜치가 없어 기계 상태에 쌓았다 — …」 한 줄을 알린다. 상태 브랜치 자리에서 `pending` · `flush` 는 **두 자리를 함께** 읽는다(기계 상태 줄 먼저, 그 뒤 `pending.md`) | 설계 §5 는 상태 브랜치가 없을 때를 정하지 않았다. 기계 상태에 이미 쌓인 줄(이 판으로 올리기 전 · 브랜치 만들기 전)을 버리지 않으려면 두 자리를 함께 읽어야 한다 | 브랜치가 없으면 쓰지 않고 1 |
| M15 ★ | 대기 줄의 사람 줄 종류(R2 미룸 행) | 상태 브랜치 자리에서 `add` 는 `human_lines.is_human` 인 줄을 human_gate 가 켜졌을 때 받지 않는다(지금 `flush` 의 글 `HUMAN_BY_ARGS` 와 2). `flush` 는 사람 줄을 건너뛰고 「사람 줄이라 옮기지 않은 대기 줄 n — record --human 으로 적는다」 를 알린 뒤 나머지를 옮긴다(멈추지 않는다). 기계 상태 자리(옛 형식 · 꺼짐 · 브랜치 없음)는 지금 동작 그대로 — AC20 | R2 설계 미룸 행 「건너뛰고 세거나 넣을 때 거르기」 의 둘 다. 원격에 올라간 `pending.md` 에는 남이 사람 줄을 넣을 수 있다 — 한 줄 때문에 다른 줄이 옮겨지지 않으면 결정이 쌓인다 | 넣을 때만 거른다 · 지금처럼 멈춘다 |
| M16 | `flush` 와 남의 고침 | 옮길 줄 = 그 에픽 · 「지휘 기록」 절의 `pending.md` 줄(다중집합) − 남의 고침 커밋들이 더한 줄(다중집합). 빠진 줄 수는 「확인되지 않은 남의 고침이 더한 대기 줄 n — 옮기지 않았다」. 차례 — INTENT.md 에 먼저 쓰고(`_append_decisions`) 그 뒤 상태 브랜치에서 옮긴 줄을 뺀다(다중집합 빼기). 둘째가 실패해도 다음 `flush` 는 같은 줄을 INTENT.md 에 다시 쓰지 않는다(이미 있는 줄은 더하지 않는다) | AC21 「`flush` 가 그 커밋이 더한 줄을 옮기지 않으며」. 남이 지운 줄은 화면의 「확인되지 않은 남의 고침 n」 으로 드러난다 | 확인 끝의 글에 내 고침만 다시 얹어 옮길 줄을 계산한다 |
| M17 | 판정 줄 규칙 하나(§9) — **계획 확인 Q1** | `workflow_superpowers.RULING_MARK = "Ruling:"` 와 `ruling_said(line) -> Optional[str]`(판정 줄이면 `Ruling:` 뒤 글, 아니면 `None`). 원장을 읽는 둘(`conductor_state.ledger_rulings` · `workflow_superpowers.ledger_lines`)이 그 함수로 줄을 고른다 — `ledger_rulings` 의 출력(줄 전체)은 그대로. 결과 파일의 기계 줄 문법(줄 머리 — `team_files._is_machine`)은 형식 정본의 계약이라 바꾸지 않고 상수와 함수만 같은 것을 쓴다. 함수의 규칙은 Q1 의 답이다 — 이 계획은 **(가) 부분 문자열** 로 썼다 | 아래 「판정 줄 실측」 | (나) 줄 머리 |
| M18 | 「예약 밖 변경」 줄임(§9) — **계획 확인 Q2** | 파일이 여섯 이상이면 이름 순 앞 다섯과 「 외 n개」(`예약 밖 변경: a · b · c · d · e 외 3개`). 다섯 이하면 지금 그대로 | 설계 §9 「몇 줄인지는 계획이 제안하고 계획 확인에서 정한다」. 지금 테스트의 줄은 둘 · 하나라 그대로 선다 | 셋 · 열 |
| M19 | 판정이 없을 때의 문구(§9) | 보고의 `layout` 이 `team` 이면 네 자리(`control_plane.py` 의 두 화면 각 둘)의 「설계문서 `## 판정`」 을 「결과 파일의 `Ruling:` 줄」 로 바꾼다. 옛 형식은 그대로 | 설계 §9 · R1 계획 2 잔여 7 | — |
| M20 | `BUCKETS` · `TASK_STATUS` 락(§9) | `set(BUCKETS 의 단계 전부) ∪ set(control_plane.UNCOUNTED) == set(roadmap_status.TASK_STATUS) ∪ {"알 수 없음"}` 를 단언한다(지금 같다 — 통과가 정답인 락이라 변이와 양성 대조를 둔다) | 설계 §9 | — |
| M21 | 글 출력의 로드맵 밖 과제(§9) | `roadmap_status.render` 가 보고에 `jobs` 칸이 있을 때만(team 형식) 경로 예약 겹침 줄 앞에 `로드맵 밖 과제: <n>개` 와 과제마다 `    <id> <title> — <단계> · <사유>` · 그 알림 `        정보: …` · `job_notes` 의 `    정보: …` 를 낸다. 옛 형식의 글 출력은 바이트까지 그대로 | 설계 §9 · AC20 | — |
| M22 ★ | 과제 폴더 없는 작업(§9) | `control_plane.works_lines` 가 team 보고일 때, 끝나지 않은 작업 줄마다 과제를 찾는다 — 에픽 칸이 보고의 블록 번호(결정 블록 빼고)면 있다, 「로드맵 밖」 이면 이름 칸이 보고 `jobs` 의 과제 이름과 글자 그대로 같을 때만 있다. 없으면 그 줄 끝에 ` · 과제 폴더 없음`. 지휘 절차서에 「team 형식에서 로드맵 밖 일의 작업 줄 이름 칸은 과제 이름이다」 한 문장(과제 18) | 설계 §9 는 「과제 폴더가 없으면」 만 적었다. 기계 상태의 작업 줄에는 과제 칸이 없다 — 이름 칸이 과제 이름이라는 약속을 새로 둔다 | 근거 칸의 경로로 가른다 |
| M23 | 단순 작업의 PR 캐시(§9) | `pr-refresh` 가 `--epic` 없이 불리면 보고 `jobs` 가운데 단계가 머지됨이 아닌 과제(`--reset` 이면 전부)의 `branch` 도 채운다. 그 줄의 에픽 자리는 과제 이름 | 설계 §9 · R1 B25 | — |
| M24 ★ | 같은 (에픽, 종류)를 다시 물을 때(미룸 R3) | `waiting add` 가 같은 (에픽, 종류) 줄을 찾았을 때 그 줄이 「질문 창」 이고 세션이 이 세션이면 언제부터를 지금으로 바꾼다(앞 질문은 이 세션이 다시 돌고 있으니 답을 받았다). 「턴 끝」 이거나 다른 세션의 줄이면 지금처럼 처음 값을 둔다 | 설계 §2 「그 세션이 다시 돌고 있다는 것이 답을 받았다는 뜻」 과 같은 뜻으로 맞춘다 | 늘 지금으로 바꾼다 |
| M25 | 드문 경우 넷(계획 1 리뷰 잔여) | ① `ensure` 는 그 로드맵이 끝났으면(블록이 모두 머지됨 · 끝남) 만들지 않고 「끝난 로드맵이라 상태 브랜치를 만들지 않는다」 · 0 ② 설정 오류면 쓰는 명령(`ensure` · `sync` · `waiting` · `send` · `ack` · 새 하위 명령)이 3 이 아니라 0 으로 끝나고 「레포 설정을 읽지 못해 …」 를 낸다 — `team_of` 보다 `availability` 를 먼저 본다 ③ `send` 는 표지(5) → `availability` → 값 차례로 본다 ④ ★ 원격 브랜치를 지우는 push 를 `--force-with-lease=refs/heads/conductor/<이름>:<센 끝>` 으로 건다(원격이 그 끝이 아니면 지우지 않고 3). 다시 얹을 커밋 가운데 부모가 둘 이상인 것이 있으면 다시 얹지 않고 3(「손으로 만든 머지 커밋이 있다 — 상태 브랜치는 스크립트만 쓴다」). 이름 꼴이 틀린 `conductor/` 브랜치는 `show` 에 「이름 꼴이 틀린 상태 브랜치 n」 으로 센다 | 계획 1 구현 대조 「리뷰 잔여」. ④ 의 lease 는 지우기를 좁히기만 한다 — 브랜치 규칙의 「force-push 금지」(이력을 덮는 올리기)와는 다른 꼴이지만 글자에 `force` 가 들어 리뷰어에게 따로 보인다 | ④ 를 공시만 한다 |
| M26 | 가리기의 경로 꼴(계획 1 리뷰 잔여) | 절대경로로 보는 낱말 = 줄 머리 · 공백 · 여는 괄호 · 따옴표 · 백틱 바로 뒤의 `/` 로 시작하고 `/` 로 이은 ASCII 경로 성분(`[A-Za-z0-9._~-]+`)이 둘 이상인 것. `scrub` · `redact` · 편지 `about` 판정이 같은 함수(`conductor_branch.looks_absolute`)를 쓴다 | 「리더/담당자/일꾼」 · 「설계/계획/구현」 · `./a/b` 가 절대경로로 깎이거나 거절됐다 — 닫히는 쪽이었지만 쓸 수 있는 글을 막았다 | 그대로 둔다 |
| M27 | `DONE_STAGES` 락(계획 1 리뷰 잔여) | `conductor_branch.DONE_STAGES == roadmap_status.DONE` 를 단언한다 | 글자로 복제한 목록이 갈라지면 끝난 로드맵을 끝나지 않은 것으로 센다 | 가져다 쓴다(상태 계산을 가져오게 된다) |
| M28 | AC20 의 team 절반을 재는 법 | 커밋되는 테스트는 같은 코드 안에서 「끔」 과 「켬 · 브랜치 없음」 의 출력이 R1 의 고정 출력 테스트대로인지 본다. 기준 코드와의 차이는 과제 19 가 한 번 돌리는 대조(`git archive <merge-base>` 의 스크립트와 이 브랜치의 스크립트로 같은 team 픽스처의 명령 출력을 견준다)로 재고 그 결과를 보고에 싣는다 | 계획 1 리뷰 잔여 「AC20 의 증거에 한계가 있다」. 레포의 git 상태에 기대는 테스트는 머지 뒤 공허해진다 | 커밋되는 테스트에 기준 코드 대조를 넣는다 |

### 판정 줄 실측(설계 §9 「계획의 첫 과제가 재고」)

계획을 쓰면서 쟀다(2026-11-20 · 읽기만). 대상은 이 기계의 실제 구현 원장(`progress.md`) — 레포 `.superpowers/sdd` · 지휘 자원 폴더 · `~/.claude/sdd-mirror` · `.git/sdd` · worktree 들 — 이고 내용이 같은 사본은 한 번만 셌다. 59개 파일에서 `Ruling:` 이 든 줄은 1096줄이다.

| 꼴(불릿 `- ` · `* ` 을 뗀 뒤) | 줄 | 부분 문자열(지금 원장 읽기 둘) | 줄 머리(결과 파일 읽기의 규칙을 원장에 쓰면) |
|---|---|---|---|
| `Ruling: …` 로 시작 | 897 | 판정 | 판정 |
| `Task <n>: Ruling: …` | 92 | 판정 | **빠짐** — `Task <n>:` 을 떼야 잡힌다 |
| `**Ruling: …**` | 3 | 판정 | **빠짐** — `**` 를 떼야 잡힌다 |
| 글 속 언급(`` `Ruling:` 줄을 읽는다 ``) | 10 | **판정으로 잘못 셈** | 빠짐(맞다) |
| 줄 중간의 판정 — `parked — … — Ruling: <판정>` 64 · 표 칸 `\| … \| Ruling: <판정> \|` 등 28 · 그 밖 2 | 94 | 판정 | **빠짐**(실제 판정이다) |

**셋이 다르게 가르는 줄이 있다** — 결과 파일 읽기(`team_files`)는 변환기가 줄 머리로 쓴 줄만 읽으므로 지금은 갈리지 않지만, 규칙 하나로 모으면 원장에서는 위 표의 셋째 · 넷째 열처럼 갈린다. 계획 확인에서 묻는다(Q1).

### 계획 확인에서 정할 것

- **Q1 판정 줄 규칙(M17 · 과제 10).** (가) 부분 문자열 — 줄 어디든 `Ruling:` 이 있으면 판정이고 그 뒤 글을 쓴다. 지금 원장을 읽는 둘과 같아 바뀌는 출력이 없다. 글 속 언급 10줄이 판정으로 남는다. (나) 줄 머리 — 불릿 · `Task <n>:` · `**` 를 뗀 뒤 `Ruling:` 으로 시작할 때만 판정. 글 속 언급 10줄이 빠지고, `parked` 줄 · 표 칸의 실제 판정 94줄도 판정에서 빠진다(설계문서 `## 판정` 에 옮겨지지 않는다). **추천 (가)** — 실제 판정을 조용히 빠뜨리는 쪽이 잘못 든 언급(눈에 보인다)보다 비싸다. (나)면 과제 10 의 `ruling_said` 본문과 테스트 표의 기대값 셋만 바꾼다.
- **Q2 「예약 밖 변경」 을 몇 개에서 줄일지(M18 · 과제 11).** 추천 다섯(여섯 이상이면 앞 다섯 + 「외 n개」). 다른 값이면 상수 `RESERVE_OUTSIDE_MAX` 하나와 테스트의 기대 글자를 바꾼다.

### 사용자 결정 대기 넷(설계문서 `## 미룸` 의 R3 행 — 이 계획이 정하지 않는다)

지휘자가 PR #306 의 머지 전 확인 때 사용자에게 여쭌다. 계획에는 「사용자 결정 대기 — 답에 따라 이 과제를 하거나 건너뛴다」 로 과제 14 – 17 을 갈라 두었다.

| # | 물음 | 길과 바뀌는 것 | 과제 |
|---|---|---|---|
| U1 | AC3 의 글자 · 세 번 거절이면 종료 코드 1 | (가) 코드 그대로(1 · 「세 번 다시 만들어도 올리지 못했다 — 로컬 커밋은 남겼다」) 두고 지휘자가 AC3 의 글자에 「다시 만들어도 세 번 거절되면 로컬 커밋을 남기고 1」 을 더한다 — 코드 변경 없음, 과제 14 건너뜀. (나) AC3 의 글자대로 0 으로 끝내고 알림만 — `_publish` 의 끝 갈래 · 절차 문서의 종료 코드 표 1 행 · 테스트 둘을 바꾼다(과제 14) | 14 |
| U2 | 두 세션 알림 · 지우기에 수용 기준 줄이 없다 | (가) 지휘자가 설계문서에 AC 두 줄을 더한다 — 이 계획은 그 번호를 대조 목록과 마지막 리뷰의 AC 목록에 더하고 있는 테스트에 번호 주석만 단다(과제 15). (나) 더하지 않는다 — 과제 15 건너뜀 | 15 |
| U3 | 지우기 확인 표시의 꼴 | (가) 구현 그대로(`--confirmed <수를 센 끝>`) 두고 지휘자가 §1 의 글자를 맞춘다 — 과제 16 건너뜀. (나) §1 글자대로 맨 표시(`--confirmed`)로 — 수를 센 뒤 브랜치가 움직였을 때 지우지 않는 보호가 사라진다. `delete` 의 인자 · 절차 문서 걸음 7 · 테스트를 바꾼다(과제 16). 추천 (가) | 16 |
| U4 | 「지금 묻는 질문」 종류 이름과 R2 사람 줄 종류 | (가) 이름을 맞춘다 — `계획 확인` → `계획 검토`, `흐름 승인` · `걸음 건너뜀` 을 더한다(`ASK_KINDS` · 기계 상태 줄 검사 · 절차 문서 · 테스트. 옛 이름의 줄이 든 기계 상태는 읽을 때 새 이름으로 바꿔 읽는다). (나) 이름은 두고 절차 문서에 대응표(어느 사람 줄 질문을 걸 때 어느 종류로 올리는지)를 둔다 — 문서 한 절과 락 하나 | 17 |

---

## 머지 전 다시 셀 것

R2 계획 2 가 먼저 머지되면 `git merge origin/main` 뒤 아래를 하나씩 연다 — 충돌 목록에 없어도 `git diff origin/main -- <경로>` 로 본다(같은 판으로 올린 `plugin.json` 은 조용히 합쳐진다). 기본 브랜치를 합칠 때마다 다시 한다.

| # | 자리 | 견줄 것 |
|---|---|---|
| 1 | `.claude-plugin/plugin.json` · `CHANGELOG.md` 맨 위 머리 | 기본 브랜치의 판 바로 다음 minor 이고 머리가 하나만 더해졌다(테스트는 판 리터럴이 없다) |
| 2 | `references/team-files.md` §9 의 「맞추는 명령」 예시 줄 | R2 계획 2 과제 10 이 같은 줄의 경로 따옴표를 뗀다. 합친 뒤 그 줄이 따옴표 없이 `--rules-at <커밋>` 까지 있는지 |
| 3 | `references/team-files.md` §5 머리 예시 · §10 「묶음 낡음」 문단 · §2 · §15 · `## 목차` | R2 계획 2 가 §2 · §5 · §6 · §9 · §10 과 새 `### 걸음표` 를 고친다. `rules_at` 줄 · 「규칙을 읽은 커밋」 문장 · §15 의 새 「지금의 값」 이 남아 있는지, 목차가 절과 맞는지 |
| 4 | `references/conducting.md` 걸음 5 | R2 계획 2 가 걸음 2 – 5 의 「- 판단:」 뒤에 한 줄씩과 끝에 `## team 형식 로드맵` 절을 더한다. 이 계획의 걸음 5 「기본값」 끝 문장이 그대로이고 `test_conductor_state_branch_docs.py` 의 걸음 가르기(`step(5)`)가 새 줄 때문에 다른 글을 잡지 않는지 |
| 5 | `skills/epic-conductor/SKILL.md` | 「5. 지휘 순환」 의 `Read` 펜스에 셋째 줄이 있고 R2 계획 2 의 문장(208행 근처)과 겹치지 않는지 · `test_epic_conductor_skill.sh` |
| 6 | `scripts/start_bundle.py` | R2 계획 2 가 `_job_bundle` 의 힌트 조건을 고친다 — `SYNC_LINE` · `sync_line` · `open_base` 의 이 계획 고침이 그대로인지 · `bash tests/test_start_bundle.sh` |
| 7 | `scripts/conductor_ledger.py` | R2 계획 2 는 `human-check` 를 고친다 — `c_add` · `c_pending` · `c_flush` · `c_pr_refresh` 의 이 계획 고침이 그대로인지 · `python3 -m unittest tests/test_conductor_ledger.py` |
| 8 | `scripts/job_results.py` | 이 계획은 고치지 않는다 — `git diff origin/main -- plugins/spec-distill/scripts/job_results.py` 가 R2 의 것뿐인지 |
| 9 | `tests/fixtures/team_repo.sh` | 바뀌었으면 `bash tests/test_leader_seat_e2e.sh` 를 다시 돌린다 |
| 10 | `tests/test_start_bundle.sh` · `tests/test_team_stale.sh` 의 `team_layout.leader_ref = lambda …` 줄 | 두 인자를 받는 꼴(`lambda ref, tip=None: …`)인지 — R2 가 같은 줄을 더 썼으면 그 줄도 |
| 11 | README 「Principles Instantiated」 · 「지휘자 상태 브랜치」 절 | 줄이 겹쳐 지워지지 않았는지 |
| 12 | `tests/test_roadmap_status.sh` 의 `READERS` · `CHECKED 16` · `control_plane.CODE_STAMP_FILES` | `READERS` 에 `TRUST` 가 있고 수와 목록은 기본 브랜치와 같다(이 계획은 닫힘에 모듈을 넣지 않는다) |
| 13 | `repo_defaults.KEYS` 와 키 수 글자 | 이 계획은 키를 더하지 않는다 — 기본 브랜치와 같은지만 본다 |

---

## 파일 표

| 파일 | 과제 | 무엇 |
|---|---|---|
| `scripts/team_layout.py` · `scripts/conductor_branch.py` · `scripts/conductor_status.py` · `scripts/conductor_state.py` · `tests/test_conductor_state.py` · `tests/test_conductor_branch.py` | 2 | 접두 상수 · 기계 상태 `확인한 끝` · 쓴 커밋 기록 |
| `scripts/team_status.py` · `scripts/team_layout.py` · `scripts/roadmap_status.py` · `scripts/start_bundle.py` · `tests/test_leader_seat.py`(새로) · `tests/test_roadmap_status.sh` · `tests/test_start_bundle.sh` · `tests/test_team_stale.sh` · `tests/test_team_layout.py` · `tests/test_conductor_state_branch_docs.py` | 3 | 남의 고침 · 규칙을 읽을 끝 |
| `scripts/start_bundle.py` · `scripts/team_write.py` · `scripts/roadmap_write.py` · `scripts/team_files.py` · `scripts/team_status.py` · `tests/test_team_sync.sh` · `tests/test_team_results.py` · `tests/test_leader_seat_e2e.sh`(새로 · 100755) | 4 | `rules_at` |
| `scripts/team_status.py` · `tests/test_team_stale.sh` | 5 | 「묶음 낡음」 빈 곳 |
| `scripts/leader_seat.py`(새로) · `scripts/conductor_branch.py` · `tests/test_leader_seat.py` | 6 · 7 · 8 | 규칙 사본 고침 · `rules-branch` · `confirm` |
| `scripts/conductor_status.py` · `tests/test_conductor_status.py` · `tests/test_conductor_cross.py` | 7 · 8 | `sync` 의 사본 지우기 · 갈라짐 · 남의 고침 n · `show` |
| `scripts/conductor_ledger.py` · `scripts/leader_seat.py` · `tests/test_conductor_ledger.py` · `tests/test_leader_seat_e2e.sh` | 9 | 대기 줄 |
| `scripts/workflow_superpowers.py` · `scripts/conductor_state.py` · `scripts/team_files.py` · `tests/test_workflow_superpowers.py` | 10 | 판정 줄 규칙 하나 |
| `scripts/roadmap_status.py` · `scripts/control_plane.py` · `tests/test_control_plane.py` · `tests/test_team_status.sh` · `tests/test_team_tasks.sh` | 11 | 현황 수리 |
| `scripts/conductor_ledger.py` · `tests/test_team_tasks.sh` | 12 | 단순 작업 PR 캐시 |
| `scripts/conductor_status.py` · `scripts/conductor_branch.py` · `scripts/conductor_mail.py` · `tests/test_conductor_status.py` · `tests/test_conductor_branch.py` · `tests/test_conductor_mail.py` · `tests/test_conductor_cross.py` | 13 | 계획 1 잔여 |
| 과제 14 – 17 의 파일은 각 과제에 | 14 – 17 | 사용자 결정 대기 |
| `references/conducting.md` · `skills/epic-conductor/SKILL.md` · `references/conductor-state-branch.md` · `references/team-files.md` · `references/roadmap-ontology.md` · `README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json` · `tests/test_conductor_state_branch_docs.py` · `tests/test_team_docs.py` · `tests/test_repo_literals.sh` | 18 | 문서와 판 |
| `tests/test_leader_seat_e2e.sh` · `tests/test_leader_seat.py` | 19 | 끝에서 끝 · 옛 동작 · 변이 · 전체 스위트 |

고치지 않는 것: `scripts/job_results.py`(M11) · `scripts/repo_defaults.py` · `scripts/check_deps.py` · `dependencies.md`(아래 「고치지 않고 둔 것」) · `tests/test_roadmap_status.sh` 의 정적 검사 목록과 `CHECKED` 수 · `control_plane.CODE_STAMP_FILES` · `plugins/project-init/` · 설계문서 · 지나간 계획.

---

### Task 1: 다시 확인

**AC:** 없음(준비).

**Files:** 없음(읽기만).

- [ ] **Step 1: 설계가 근거로 든 자리가 지금도 그런지 본다**

worktree 뿌리에서 아래를 돌린다. 줄 끝 주석의 기대값과 **하나라도 다르면 멈추고 지휘자에게 보고한다**(무엇이 다른지 · 설계의 어느 문장이 그 자리에 기대는지). 계획을 쓸 때(2026-11-20 · 이 브랜치의 끝 a0290234) 모두 기대값이었다. 19 의 판은 R2 계획 2 가 먼저 머지됐으면 `origin/main` 이 8.27.0 이다 — 그때는 이 브랜치가 기본 브랜치를 합쳤는지(21)도 함께 본다.

```bash
P=plugins/spec-distill
grep -c '^def leader_ref(default_ref: str) -> str:' $P/scripts/team_layout.py                                          # 1
grep -c '^SYNC_LINE = "맞추는 명령: python3 %s job sync --result %s --role %s --bundle-at %s --job-at %s"' $P/scripts/start_bundle.py   # 1
grep -c 'lead = self.git.commit(team_layout.leader_ref(self.main)) or ""' $P/scripts/team_status.py                     # 1
grep -c '^SYNC_HEAD_KEYS = ("type", "stage", "plan", "attempt", "role", "head", "bundle_at", "job_at")' $P/scripts/team_write.py   # 1
grep -c 'r.head, r.bundle_at, r.job_at = _commit(meta, "head"), _commit(meta, "bundle_at"), _commit(meta, "job_at")' $P/scripts/team_files.py   # 1
grep -c 'rows = \[r for r in load(root, a.roadmap)\["쌓인 기록"\] if r\["에픽"\] == a.epic and r\["절"\] == "지휘 기록"\]' $P/scripts/conductor_ledger.py   # 1
grep -c 'raise Fail(2, HUMAN_BY_ARGS' $P/scripts/conductor_ledger.py                                                    # 1 — 사람 줄이 섞이면 flush 가 멈춘다
echo "$(grep -c '^BUCKETS = ' $P/scripts/control_plane.py) $(grep -c '^TASK_STATUS = ' $P/scripts/roadmap_status.py)"  # 1 1
grep -c '설계문서 `## 판정` 도 없다' $P/scripts/control_plane.py                                                        # 4
sed -n '/^def render(report: dict) -> str:/,/^def main/p' $P/scripts/roadmap_status.py | grep -c 'jobs'                # 0
grep -c 'for br in _branches_of(b):' $P/scripts/conductor_ledger.py                                                     # 2
echo "$(grep -c 'if "Ruling:" in l\]' $P/scripts/conductor_state.py) $(grep -c 'elif "Ruling:" in line:' $P/scripts/workflow_superpowers.py) $(grep -c 'elif line.startswith("Ruling:"):' $P/scripts/team_files.py)"   # 1 1 1
sed -n '/    def stale(self, tip: str, block: dict) -> list:/,/    def _fill_progress/p' $P/scripts/team_status.py | grep -c '^            if result is None:'   # 1 — 읽지 못한 결과 파일을 말없이 건너뛴다
echo "$(grep -c '^def rules_gap(root, roadmap_rel: str, tip: Optional\[str\]) -> int:' $P/scripts/conductor_status.py) $(grep -c '"pending": sum(1 for line in pending.splitlines() if line.startswith("- "))' $P/scripts/conductor_status.py)"   # 1 1
echo "$(grep -c '^    onto: Optional\[str\]' $P/scripts/conductor_branch.py) $(grep -c '^PENDING_FILE = "pending.md"' $P/scripts/conductor_branch.py)"   # 1 1
echo "$(grep -c 'conductor-state-branch.md' $P/references/conducting.md) $(sed -n '/^### 5\. 머지 전 확인/,/^### 6\./p' $P/references/conducting.md | grep -c 'conductor-state-branch\|규칙 고침')"   # 3 0
echo "$(grep -c '^Read \${CLAUDE_PLUGIN_ROOT}/references/' $P/skills/epic-conductor/SKILL.md) $(grep -c 'conductor-state-branch' $P/skills/epic-conductor/SKILL.md)"   # 2 0
grep -c 'RULES.md 의 고침과 대기 줄은 아직 옮기지 않았다' $P/references/team-files.md                                  # 1
echo "$(grep -o '"version": "[0-9.]*"' $P/.claude-plugin/plugin.json) · main $(git show origin/main:$P/.claude-plugin/plugin.json | grep -o '"version": "[0-9.]*"')"   # 8.26.0 · main 8.25.0(R2 계획 2 머지 뒤면 이 브랜치가 합친 판 · main 8.27.0)
echo "$(grep -o 'len(rd.KEYS), [0-9]*' $P/tests/test_repo_defaults.py) $(grep -o '"CHECKED 16"' $P/tests/test_roadmap_status.sh | sort -u)"   # len(rd.KEYS), 14 "CHECKED 16"(R2 계획 2 뒤면 15)
git merge-base --is-ancestor origin/main HEAD; echo $?                                                                    # 0
grep -c 'team = team_of(root, roadmap_rel)' $P/scripts/conductor_branch.py                                              # 3 — availability 보다 먼저 설정을 읽는 자리(M25 ②)
```

- [ ] **Step 2: 판정 줄 실측이 계획의 표와 같은 꼴인지 본다**

`## 계획의 판단` 의 「판정 줄 실측」 표가 지금 기계의 원장에서도 같은 꼴(다섯 갈래 모두 0 이 아니다)인지 아래로 본다. 수가 조금 다른 것은 새 원장이 생긴 것이라 멈추지 않는다 — 다섯 갈래 가운데 하나가 0 이면 지휘자에게 알린다(Q1 의 근거가 달라진다).

```bash
python3 -I - "$HOME/.claude/sdd-mirror" .superpowers/sdd <<'PY'
import os, re, sys, hashlib, collections
seen, c = set(), collections.Counter()
for r in sys.argv[1:]:
    for d, _s, fs in os.walk(r):
        if "progress.md" not in fs: continue
        b = open(os.path.join(d, "progress.md"), "rb").read()
        if hashlib.sha1(b).hexdigest() in seen: continue
        seen.add(hashlib.sha1(b).hexdigest())
        for raw in b.decode("utf-8", "replace").splitlines():
            if "Ruling:" not in raw: continue
            u = raw.strip()
            u = u[2:].strip() if u[:2] in ("- ", "* ") else u
            k = ("머리" if u.startswith("Ruling:") else "Task" if re.match(r"Task [0-9]+[a-z]?: Ruling:", u)
                 else "굵게" if u.startswith("**Ruling:") else "언급" if "`Ruling:`" in u else "중간")
            c[k] += 1
print(len(seen), dict(c))
PY
```

Expected: 파일 수와 다섯 갈래(`머리` · `Task` · `굵게` · `언급` · `중간`)의 수. 보고에 그대로 옮긴다.

---

### Task 2: 접두 상수 · 기계 상태 `확인한 끝` · 이 기계가 쓴 커밋

**AC:** AC21(기반 — 「확인한 끝은 기계 상태에 남고」).

**Files:**
- Modify: `scripts/team_layout.py`(상수 `STATE_BRANCH_PREFIX`) · `scripts/conductor_branch.py`(`STATE_BRANCH_PREFIX` 를 그 상수로 · `Result.made` · `_write_floor` · `_publish` · `_replay` 가 옮긴 커밋을 적는다) · `scripts/conductor_status.py`(`FETCH_HINT` 를 상수로 짓는다) · `scripts/conductor_state.py`(절 `확인한 끝`)
- Test: `tests/test_conductor_state.py` · `tests/test_conductor_branch.py`

**Interfaces:**
- Produces: `team_layout.STATE_BRANCH_PREFIX = "conductor/"` · `conductor_state.TRUST = "확인한 끝"` · `conductor_state.TRUST_WHY = ("확인", "씀")` · `conductor_state.COLUMNS[TRUST] == ("끝", "까닭", "때", "세션")`(선택 절 — 비면 머리를 쓰지 않는다) · `conductor_branch.Result` 의 넷째 뒤 칸 `made: tuple = ()`(이 쓰기에서 ref 를 옮긴 커밋들 · 차례대로) · `conductor_branch.record_own(root, roadmap_rel: str, session: str, commits: list) -> None`(기계 상태에 `씀` 줄을 더한다 · 표지 확인은 부르는 쪽이 이미 했다).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_conductor_state.py` 에 — 새 절의 줄 검사(R3 AC21):

```python
class TrustSection(unittest.TestCase):   # R3 AC21 — 확인한 끝
    ROW = {"끝": "a" * 40, "까닭": "확인", "때": "2026-11-20 10:00 +0900", "세션": "aaaa1111-session"}

    def text(self, row):
        data = cs.empty()
        data[cs.TRUST].append(row)
        return cs.render_machine("docs/r/x/roadmap.md", data)

    def test_round_trip(self):
        data = cs.parse_machine(self.text(self.ROW), "docs/r/x/roadmap.md")
        self.assertEqual(data[cs.TRUST], [self.ROW])

    def test_closed_cells(self):   # 붉어지는 변이: 끝의 fullmatch 를 match 로 · 까닭 목록에 다른 글 · 때 검사 지움
        for key, bad in (("끝", "a" * 39), ("끝", "a" * 40 + "x"), ("끝", "A" * 40), ("까닭", "확인함"), ("때", "2026-11-20 10:00")):
            with self.assertRaises(cs.MachineError, msg=(key, bad)):
                cs.parse_machine(self.text(dict(self.ROW, **{key: bad})), "docs/r/x/roadmap.md")

    def test_empty_section_writes_no_head(self):   # 옛 기계 상태 글을 바이트로 견주는 테스트를 그대로 둔다
        self.assertNotIn("## " + cs.TRUST, cs.render_machine("docs/r/x/roadmap.md", cs.empty()))
```

`tests/test_conductor_branch.py` 에 — 쓴 커밋이 적힌다(실제 임시 레포 · 실제 거절):

```python
class OwnCommits(StateRepo):   # R3 AC21 · Review Focus 1
    def own(self):
        return [r["끝"] for r in cs.load(cs.machine_path(state_root(str(self.w)), rm(ALPHA)), rm(ALPHA))[cs.TRUST]
                if r["까닭"] == "씀"]

    def test_every_moved_commit_is_recorded(self):
        self.claim()
        made = CB.ensure(str(self.w), rm(ALPHA), SID)
        res = CB.write(str(self.w), rm(ALPHA), SID, lambda b: {CB.team_of(str(self.w), rm(ALPHA)).status: "x\n"}, "STATUS")
        self.assertEqual(self.own(), [made.commit, res.commit])
        self.assertEqual(res.made, (res.commit,))

    def test_remade_on_foreign_tip_records_only_mine(self):   # 남의 커밋은 「씀」 이 아니다
        self.claim()
        CB.ensure(str(self.w), rm(ALPHA), SID)
        other = self.clone("other")
        self.claim(repo=other, session=OTHER)
        team = CB.team_of(str(other), rm(ALPHA))
        CB._fetch(str(other), team.name)
        self.g("update-ref", CB.ref_of(team.name), "refs/remotes/origin/" + CB.branch_of(team.name), repo=other)
        theirs = CB.write(str(other), rm(ALPHA), OTHER, lambda b: {team.rules: "- [남] 남의 줄\n"}, "남")
        mine = CB.write(str(self.w), rm(ALPHA), SID, lambda b: {team.status: "y\n"}, "STATUS")   # 거절 → 받아 와 다시 만든다
        self.assertEqual(mine.onto, theirs.commit)
        self.assertNotIn(theirs.commit, self.own())
        self.assertIn(mine.commit, self.own())
```

붉어지는 변이: `_publish` 의 다시 만들기 갈래에서 기록을 지운다(둘째 단언 셋째) · 기록에 `remote` 를 넣는다(둘째의 `NotIn`) · `ensure` 의 만들기를 기록하지 않는다(첫째). 양성 대조: 첫째가 쓴 커밋 둘을 글자 그대로 견준다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_state.py plugins/spec-distill/tests/test_conductor_branch.py 2>&1 | tail -3`
Expected: `TrustSection` · `OwnCommits` FAIL(`TRUST` 가 없다)

- [ ] **Step 3: 구현한다**

- `team_layout.STATE_BRANCH_PREFIX = "conductor/"`. `conductor_branch.STATE_BRANCH_PREFIX = team_layout.STATE_BRANCH_PREFIX`(이름은 남긴다 — 계획 1 의 테스트 · 객체 지도가 그 이름을 짚는다). `conductor_status.FETCH_HINT` 를 `"git fetch origin 'refs/heads/%s*:refs/remotes/origin/%s*' 로 받아 온다" % (P, P)` 꼴로 그 상수에서 짓는다(글은 지금과 바이트까지 같다).
- `conductor_state` — `SECTIONS` 끝(옛 절 둘 앞)에 `(TRUST, ("끝", "까닭", "때", "세션"))`, `OPTIONAL_SECTIONS` 에 `TRUST`. `_check_row` 에 갈래: `OID_RE.fullmatch(끝)` · `까닭 in TRUST_WHY` · `STAMP_RE.fullmatch(때)` · `SESSION_PATTERN.fullmatch(세션)`.
- `conductor_branch` — `Result` 를 `made: tuple = ()` 칸을 가진 NamedTuple 로(기존 네 칸 위치 그대로). `_write_floor` · `_publish` 는 `update-ref` 가 성공한 커밋마다(만들기 · 이번 쓰기 · `_replay` 가 낸 새 끝들 · 다시 만든 쓰기) 목록에 더하고 `try/finally` 로 `record_own` 을 한 번 부른다 — 예외로 끝나도 옮긴 것은 적는다. `record_own` 은 `cs.load` → `TRUST` 에 `{"끝": c, "까닭": "씀", "때": stamp(), "세션": session}` 를 더해 → `cs.save`. `ensure` 의 받아 오기(`_adopt`)는 남의 끝이라 적지 않는다.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_state.py plugins/spec-distill/tests/test_conductor_branch.py plugins/spec-distill/tests/test_conductor_status.py plugins/spec-distill/tests/test_conductor_mail.py plugins/spec-distill/tests/test_conductor_cross.py 2>&1 | tail -1; bash plugins/spec-distill/tests/test_roadmap_status.sh | tail -1; bash plugins/spec-distill/tests/test_conductor_state_branch_e2e.sh | tail -1`
Expected: `OK` · 실패 0 · 실패 0(기계 상태를 바이트로 견주는 테스트가 붉으면 빈 절의 머리를 쓴 것이다)

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/team_layout.py plugins/spec-distill/scripts/conductor_branch.py plugins/spec-distill/scripts/conductor_status.py plugins/spec-distill/scripts/conductor_state.py plugins/spec-distill/tests/test_conductor_state.py plugins/spec-distill/tests/test_conductor_branch.py
git commit -m "feat(spec-distill): 상태 브랜치 쓰기가 옮긴 커밋을 기계 상태의 확인한 끝 절에 적는다"
```

---

### Task 3: 남의 고침 · 규칙을 읽을 끝

**AC:** AC15(「상태 브랜치가 켜져 있고 사본이 있으면 `leader_ref` 가 그 끝을, 없으면 기본 브랜치를」) · AC21(「사용자가 확인하기 전에는 `leader_ref` 가 기본 브랜치를」) · AC14(꺼짐 → 기본 브랜치).

**Files:**
- Modify: `scripts/team_layout.py`(`leader_ref`) · `scripts/team_status.py`(새 함수 셋 · `Reader` 가 `lead_tip` 을 받는다) · `scripts/roadmap_status.py`(`read_machine` 을 가르고 team 로드맵이면 `rules_tip` 을 `Reader` 에 넘긴다) · `scripts/start_bundle.py`(`open_base`)
- Test: `tests/test_leader_seat.py`(새로) · `tests/test_team_layout.py` · `tests/test_start_bundle.sh` · `tests/test_team_stale.sh` · `tests/test_roadmap_status.sh`(`READERS` 에 `TRUST`) · `tests/test_conductor_state_branch_docs.py`

**Interfaces:**
- Consumes: 과제 2 의 `TRUST` · `TRUST_WHY` · `STATE_BRANCH_PREFIX`.
- Produces:
  - `team_layout.leader_ref(default_ref: str, state_tip: Optional[str] = None) -> str`
  - `team_status.trust_of(rows: Optional[list]) -> tuple` — `(확인 끝 | None, 씀 커밋들의 frozenset)`. `rows` 가 `None`(기계 상태를 읽지 못함)이면 `(None, frozenset())`. `확인` 줄이 둘 이상이면 `(None, 씀 집합)`(닫는 쪽).
  - `team_status.foreign_commits(git, tip: str, base: Optional[str], own: frozenset, paths: list) -> Optional[list]` — `[(커밋 40자, (바꾼 경로…)), …]`(오래된 차례). git 실패면 `None`.
  - `team_status.rules_tip(git, team, on: bool, rows: Optional[list]) -> tuple` — `(상태 브랜치 끝 | None, 알림들)`. `on` 이 거짓 · 상태 브랜치 없음 · 갈라짐 · 사본 없음이면 `(None, [])`(갈라짐은 알림 한 줄). 남의 고침이 있으면 `(None, ["확인되지 않은 남의 고침 %d — 규칙은 기본 브랜치의 글을 읽는다"])`, 재지 못하면 `(None, ["남의 고침을 재지 못했다 — 규칙은 기본 브랜치의 글을 읽는다"])`.
  - `team_status.Reader(..., lead_tip: Optional[str] = None)` — `stale` 이 `team_layout.leader_ref(self.main, self.lead_tip)` 를 쓴다.
  - `roadmap_status.read_machine(git, roadmap_rel) -> tuple` — `(data | None, 못 읽은 사유 | None)`. `read_pr_cache` 는 이것 위에 선다(출력 그대로).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_leader_seat.py` — 머리에서 `from conductor_branch_fixture import ALPHA, OTHER, ROADMAPS, SID, StateRepo, rm, roadmap_text` · `import conductor_branch as CB` · `import conductor_state as cs` · `import roadmap_status as RS` · `import team_layout as TL` · `import team_status as TS` · `from state_path import state_root` · `from unittest import mock` 를 가져오고(과제 6 부터 `import leader_seat as LS`), team 형식 로드맵을 세우는 픽스처를 둔다:

```python
TEAM_RULE = "- [하나] 고친 곳엔 테스트 먼저 · 조건: 역할=worker · 출처: a · 확인: b"


class TeamRepo(StateRepo):
    """ALPHA 를 team 형식(머리말 layout: team)으로 다시 쓰고 기본 브랜치에 규칙 파일 한 줄을 둔다."""
    def setUp(self):
        super().setUp()
        self.team = TL.Team(ROADMAPS, ALPHA)
        head = roadmap_text("알파 — 로드맵", self.ALPHA_BLOCKS).replace("type: roadmap\n", "type: roadmap\nlayout: team\n", 1)
        self.put({rm(ALPHA): head, self.team.rules: TEAM_RULE + "\n"})
        self.claim()
        CB.ensure(str(self.w), rm(ALPHA), SID)

    def rows(self, repo=None):
        return cs.load(cs.machine_path(state_root(str(repo or self.w)), rm(ALPHA)), rm(ALPHA))[cs.TRUST]

    def write(self, files, repo=None, session=SID):
        return CB.write(str(repo or self.w), rm(ALPHA), session, lambda b: files, "시험")

    def tip(self, repo=None):
        return CB.seen_tip(str(repo or self.w), ALPHA)[0]
```

```python
class RulesTip(TeamRepo):   # R3 AC15 · AC21 · AC14
    def tip_of(self, on=True, rows="load"):
        git = RS.Git(str(self.w))
        return TS.rules_tip(git, self.team, on, self.rows() if rows == "load" else rows)

    def test_no_copy_means_default(self):
        self.assertEqual(self.tip_of(), (None, []))

    def test_own_copy_is_read(self):
        res = self.write({self.team.rules: TEAM_RULE + "\n- [둘] 새 줄 · 조건: 역할=worker · 출처: a · 확인: b\n"})
        self.assertEqual(self.tip_of(), (res.commit, []))
        self.assertEqual(TL.leader_ref("refs/remotes/origin/HEAD", res.commit), res.commit)

    def test_off_means_default_even_with_a_copy(self):   # AC14
        self.write({self.team.rules: "- 사본\n"})
        self.assertEqual(self.tip_of(on=False), (None, []))

    def test_foreign_copy_is_not_read_until_confirmed(self):   # AC21 — 남의 고침
        other = self.clone("other")
        self.g("fetch", "-q", "origin", "refs/heads/conductor/%s:refs/remotes/origin/conductor/%s" % (ALPHA, ALPHA), repo=other)
        self.g("update-ref", "refs/heads/conductor/" + ALPHA, "refs/remotes/origin/conductor/" + ALPHA, repo=other)
        self.claim(repo=other, session=OTHER)
        self.write({self.team.rules: "- [남] 남의 줄\n"}, repo=other, session=OTHER)
        self.g("fetch", "-q", "origin", "refs/heads/conductor/%s:refs/remotes/origin/conductor/%s" % (ALPHA, ALPHA))
        tip, notes = self.tip_of()
        self.assertIsNone(tip)
        self.assertEqual(notes, ["확인되지 않은 남의 고침 1 — 규칙은 기본 브랜치의 글을 읽는다"])

    def test_unreadable_machine_state_closes(self):   # 기계 상태를 못 읽으면 내 사본도 남의 것처럼 닫는다
        self.write({self.team.rules: "- 사본\n"})
        tip, notes = self.tip_of(rows=None)
        self.assertIsNone(tip)
        self.assertEqual(notes, ["확인되지 않은 남의 고침 1 — 규칙은 기본 브랜치의 글을 읽는다"])


class Foreign(TeamRepo):
    def test_only_the_two_files_count(self):   # 남이 STATUS 만 바꾼 커밋은 세지 않는다(양성 대조 — 같은 손이 규칙 사본 고침은 센다)
        git = RS.Git(str(self.w))
        base, own = TS.trust_of(self.rows())
        fake = self.write({self.team.status: "x\n"}).commit
        self.assertEqual(TS.foreign_commits(git, fake, base, frozenset(), [self.team.rules]), [])
        moved = self.write({self.team.rules: "- y\n"}).commit
        got = TS.foreign_commits(git, moved, base, frozenset(), [self.team.rules])
        self.assertEqual(got, [(moved, (self.team.rules,))])
        self.assertEqual(TS.foreign_commits(git, moved, base, frozenset({moved}), [self.team.rules]), [])

    def test_git_failure_is_none_not_empty(self):
        self.assertIsNone(TS.foreign_commits(RS.Git(str(self.w)), "f" * 40, None, frozenset(), [self.team.rules]))
```

붉어지는 변이: `rules_tip` 에서 `on` 검사를 지운다(셋째) · 남의 고침 판정을 지운다(넷째) · `rows is None` 일 때 빈 씀 집합 대신 「모두 내 것」 으로 본다(다섯째) · `foreign_commits` 가 경로 거르기를 뺀다(여섯째의 첫 단언) · 실패를 `[]` 로 낸다(일곱째). 양성 대조: 둘째가 내 사본을 읽는다.

`tests/test_team_layout.py` 의 `test_leader_ref_is_the_default_branch_in_this_epic` 옆에 `self.assertEqual(L.leader_ref("refs/remotes/origin/HEAD", "b" * 40), "b" * 40)` 한 줄. `tests/test_conductor_state_branch_docs.py` 의 `test_leader_ref_still_answers_with_what_it_was_given` 에 같은 한 줄. `tests/test_start_bundle.sh` · `tests/test_team_stale.sh` 의 `team_layout.leader_ref = lambda ref: "refs/heads/leader-state"` 를 `lambda ref, tip=None: "refs/heads/leader-state"` 로(단언은 그대로 — 고친 것은 바꿔 끼우는 함수의 꼴뿐이다). `tests/test_roadmap_status.sh` 의 `READERS["conductor_state"]` 집합에 `"TRUST"` 하나를 더한다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_leader_seat.py 2>&1 | tail -3`
Expected: `RulesTip` · `Foreign` FAIL(`rules_tip` 가 없다)

- [ ] **Step 3: 구현한다**

- `team_layout.leader_ref` — `return state_tip or default_ref`. 문서 문자열에 「상태 브랜치의 끝은 `team_status.rules_tip` 이 계산해 넘긴다」.
- `team_status.foreign_commits` — `git.run_err("log", "--no-renames", "--format=%H", "--name-only", "%s..%s" % (base, tip) if base else tip, "--", *paths)`. 빈 줄로 가른 묶음마다 첫 줄이 40자 커밋(`fullmatch`)이고 나머지가 경로다. `own` 에 든 커밋을 빼고 오래된 차례로(출력을 뒤집는다). rc ≠ 0 이면 `None`.
- `team_status.rules_tip` — `branch_tip.tip(git.cwd, team_layout.STATE_BRANCH_PREFIX + team.name)`(`TipError` 면 `(None, ["상태 브랜치가 갈라져 규칙은 기본 브랜치의 글을 읽는다 — <사유>"])`) → 끝이 없으면 `(None, [])` → `git.blob(tip, team.rules)` 가 `None` 이면 `(None, [])` → `trust_of(rows)` → `foreign_commits(..., [team.rules])`.
- `roadmap_status` — `read_pr_cache` 의 앞부분(경로를 풀고 읽어 `parse_machine` 까지)을 `read_machine` 으로 가르고 `read_pr_cache` 는 그 위에서 같은 셋을 낸다. team 로드맵이면 `Reader` 를 만들 때 `lead_tip=team_status.rules_tip(git, team, repo_defaults.state_branch_on(settings) and not resolved["errors"], data[TRUST] if data is not None else None)[0]` — `settings` · `resolved` 는 그 함수가 1257행 근처에서 이미 만든 값이고(설정 오류가 하나라도 있으면 켬으로 읽지 않는다 — 계획 1 J10 과 같은 뜻), `TRUST` 는 `from conductor_state import …` 에 이름으로 더한다. 알림은 상태 계산에 싣지 않는다(`sync` · `show` · 시작 묶음이 낸다 — 과제 8).
- `start_bundle.open_base` — `team_rules.open_team` 은 설정 오류가 있으면 이미 멈추므로(검사 불가 3) `on = repo_defaults.state_branch_on(opened.values)`. 기계 상태를 `conductor_state.load(machine_path(state_root(...), roadmap))` 로 읽고(읽지 못하면 `rows=None`) `tip, notes = team_status.rules_tip(git, opened.team, on, rows)` → `rules_commit = git.commit(team_layout.leader_ref(DEFAULT_REF, tip))`. `notes` 는 묶음의 `알림:` 줄로 낸다(`Base` 에 `notices` 칸을 더해 `_leader_bundle` · `_job_bundle` 의 `emit` 에 넘긴다).

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_team_layout.py plugins/spec-distill/tests/test_conductor_state_branch_docs.py 2>&1 | tail -1; for t in test_start_bundle test_team_stale test_roadmap_status test_team_status test_team_tasks; do bash plugins/spec-distill/tests/$t.sh | tail -1; done`
Expected: `OK` · 실패 0 다섯

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/team_layout.py plugins/spec-distill/scripts/team_status.py plugins/spec-distill/scripts/roadmap_status.py plugins/spec-distill/scripts/start_bundle.py plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_team_layout.py plugins/spec-distill/tests/test_start_bundle.sh plugins/spec-distill/tests/test_team_stale.sh plugins/spec-distill/tests/test_roadmap_status.sh plugins/spec-distill/tests/test_conductor_state_branch_docs.py
git commit -m "feat(spec-distill): 확인된 상태 브랜치에 규칙 사본이 있으면 그 끝에서 규칙을 읽는다"
```

---

### Task 4: `rules_at`

**AC:** AC15(「시작 묶음은 규칙 글을 그 커밋에서 싣고 「맞추는 명령」 줄에 `rules_at` 을 싣는다 · `job sync` 가 적는다 · 「묶음 낡음」 은 규칙을 `rules_at` 에서 · 없으면 `bundle_at` · 리더가 규칙을 고친 것만으로는 그 뒤에 받은 묶음의 결과에 「묶음 낡음」 이 뜨지 않는다」).

**Files:**
- Modify: `scripts/start_bundle.py`(`SYNC_LINE` · `sync_line`) · `scripts/team_write.py`(`SYNC_HEAD_KEYS` · `_new_head` · `cmd_job_sync`) · `scripts/roadmap_write.py`(`job sync` 의 `--rules-at` 인자 · 사용법 글) · `scripts/team_files.py`(`Result.rules_at`) · `scripts/team_status.py`(`stale`)
- Test: `tests/test_team_sync.sh` · `tests/test_team_results.py` · `tests/test_leader_seat_e2e.sh`(새로 · 100755)

**Interfaces:**
- Consumes: 과제 3 의 `rules_tip` · `leader_ref`.
- Produces: `start_bundle.sync_line(write: str, role: str, bundle_at: str, job_at: str, rules_at: str) -> str` · `SYNC_LINE = "맞추는 명령: python3 %s job sync --result %s --role %s --bundle-at %s --job-at %s --rules-at %s"` · `team_files.Result.rules_at: Optional[str]` · `job sync --rules-at <커밋>`.

R2 의 사람 줄 관문과 만나는 자리: 시작 묶음의 관문(`human_lines.missing` → 멈춤 1)은 「맞추는 명령」 줄을 짓기 전에 서므로 이 고침이 닿지 않는다. 결과 대조(`job_results.py check`)는 고치지 않는다(M11) — 꼴이 틀린 `rules_at` 은 `parse_result` 의 머리 문제로 이미 거절된다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_team_results.py` 에 — `rules_at` 은 고를 수 있는 칸이다:

```python
    def test_rules_at_is_optional_but_closed(self):   # R3 AC15
        R = "c" * 40
        self.assertIsNone(F.parse_result(result()).rules_at)
        r = F.parse_result(result().replace("job_at:", "rules_at: %s\njob_at:" % R, 1))
        self.assertEqual((r.rules_at, r.problems), (R, []))
        bad = F.parse_result(result().replace("job_at:", "rules_at: zz\njob_at:", 1))
        self.assertIsNone(bad.rules_at)
        self.assertIn("머리 rules_at 가 커밋 번호 꼴이 아니다: 'zz'", bad.problems)
```

`tests/test_team_sync.sh` 에 행 넷(그 파일의 `sync` 도우미 · `$J` · `$B` 를 쓴다):

| 이름 | 하는 것 | 단언 | 붉어지는 변이 |
|---|---|---|---|
| 새 머리의 `rules_at` | 결과 파일이 없을 때 `--role worker --bundle-at $B --job-at $J --rules-at $RA` | 머리가 `type … head … bundle_at: $B\nrules_at: $RA\njob_at: $J` 차례 | `SYNC_HEAD_KEYS` 에서 빼거나 자리를 옮긴다 |
| 없이 만든 머리 | 지금 48행의 단언 | 바이트 그대로(옛 꼴) | `rules_at` 을 늘 쓴다 |
| 이어 쓰는 파일 | 끝 줄 없는 파일(`rules_at` 없음)에 셋 함께 | `rules_at` 줄이 `bundle_at` 줄 바로 뒤에 하나 · 다른 줄은 바이트 그대로 | 끝에 붙인다 · 둘째 줄을 만든다 |
| 홀로 준 `--rules-at` | `--rules-at $RA` 만 | rc 2 · 파일 바이트 그대로 | 함께 주기 검사를 지운다 |

`tests/test_leader_seat_e2e.sh`(새로) — `tests/fixtures/team_repo.sh` 를 source 하고 `new_repo "$T/a"` 로 세운다. 걸음:

1. `python3 "$S/conductor_branch.py" --root "$W" ensure --roadmap "$RM" --session "$SID"` → 0.
2. 상태 브랜치에 규칙 사본을 쓴다(과제 6 전에는 이 테스트 안의 작은 파이썬 한 줄로 `conductor_branch.write(...)` 를 부른다 — 과제 6 이 `rules-add` 로 바꾼다).
3. `bundle --roadmap "$RM" --job E1 --stage implement --plan 1` → 0. 묶음의 규칙 머리가 `규칙 (<기준> · 팀 규칙은 <상태 끝>):` · 사본의 새 줄이 실린다 · 「맞추는 명령」 줄 끝이 `--rules-at <상태 끝>`.
4. 그 줄 그대로 `job sync` → 결과 파일 머리에 `rules_at: <상태 끝>`. 커밋 · push.
5. 사본에 줄을 하나 더 쓴다 → 상태 계산(`status`)의 E1 알림에 「묶음 낡음: implement-plan-1-1.md — 묶은 커밋 … 뒤에 바뀜: <규칙 경로>」.
6. 새 시도 묶음 → 「맞추는 명령」 의 `--rules-at` 이 새 끝 → 그 줄로 새 결과 파일 → 상태 계산에 그 파일의 「묶음 낡음」 이 **없다**(AC15 끝 문장 — 양성 대조는 5).
7. `rules_at` 없는 옛 결과 파일(`hand_result` 로 쓴 것)은 `bundle_at` 으로 견준다 — 사본이 있는 동안 「묶음 낡음」 이 뜬다(옛 동작과 같다).
8. 다른 클론이 쓴 `rules_at`(받아 오지 않은 커밋 `0123…`)은 「묶음 낡음을 재지 못했다: … — 규칙을 읽은 커밋 01234567 가 이 레포에 없다」.

`git add` 전에 `chmod +x` 하고 커밋 뒤 `git ls-files -s plugins/spec-distill/tests/test_leader_seat_e2e.sh` 가 `100755` 인지 본다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_results.py 2>&1 | tail -1; bash plugins/spec-distill/tests/test_team_sync.sh | tail -1; bash plugins/spec-distill/tests/test_leader_seat_e2e.sh | tail -1`
Expected: 새 테스트 FAIL

- [ ] **Step 3: 구현한다**

- `start_bundle` — `SYNC_LINE` 끝에 ` --rules-at %s`, `sync_line` 에 `rules_at` 인자(감싸기 그대로). `_job_bundle` 의 `sync_line(write, role, base.commit, commit, base.rules_commit)`.
- `team_write` — `SYNC_HEAD_KEYS` 를 `(…, "bundle_at", "rules_at", "job_at")`, `_new_head(parsed, role, bundle_at, job_at, rules_at=None)`(값이 `None` 인 키는 지금처럼 쓰지 않는다). `cmd_job_sync` — `--rules-at` 도 `_commit_flag` 를 거치고, `--bundle-at` · `--job-at` 없이 오면 `W.Usage`. 이어 쓰는 파일에 셋을 함께 주면 `_swap_head(…, "rules_at")` — 그 키 줄이 없으면 `bundle_at` 줄 바로 뒤에 넣는 갈래를 `_swap_head` 에 더한다(`insert_after` 인자). 「묶은 커밋 고침」 글은 그대로.
- `roadmap_write` — `job sync` 하위 파서의 인자 목록에 `--rules-at`, 사용법 줄에 ` [--rules-at <커밋>]`.
- `team_files.parse_result` — `rules_at` 이 머리에 있으면 커밋 꼴(아니면 `"머리 rules_at 가 커밋 번호 꼴이 아니다: %r"` problem), `r.rules_at = _commit(meta, "rules_at")`.
- `team_status.stale` — `at` 다음에 `rules_from = self.git.commit(result.rules_at) if result.rules_at else at` (없는 커밋이면 그 줄의 「재지 못했다」 를 내고 다음 파일), `checks[0] = (team.rules, lead)` 를 견줄 때 그때 글은 `self.git.blob(rules_from, team.rules)` 에서, 나머지 둘은 지금처럼 `at` 에서 읽는다.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_results.py plugins/spec-distill/tests/test_team_docs.py 2>&1 | tail -1; for t in test_team_sync test_start_bundle test_team_stale test_job_results test_leader_seat_e2e test_team_status; do bash plugins/spec-distill/tests/$t.sh | tail -1; done`
Expected: `OK` · 실패 0 여섯(`test_team_docs.py` 가 형식 정본의 머리 키 목록을 짚어 붉으면 과제 18 의 문서 고침을 이 과제로 당겨 온다 — 락을 느슨하게 하지 않는다)

- [ ] **Step 5: 커밋**

```bash
chmod +x plugins/spec-distill/tests/test_leader_seat_e2e.sh
git add plugins/spec-distill/scripts/start_bundle.py plugins/spec-distill/scripts/team_write.py plugins/spec-distill/scripts/roadmap_write.py plugins/spec-distill/scripts/team_files.py plugins/spec-distill/scripts/team_status.py plugins/spec-distill/tests/test_team_sync.sh plugins/spec-distill/tests/test_team_results.py plugins/spec-distill/tests/test_leader_seat_e2e.sh
git commit -m "feat(spec-distill): 결과 파일 머리에 rules_at 을 적고 묶음 낡음은 규칙을 그 커밋에서 견준다"
```

---

### Task 5: 「묶음 낡음」 의 빈 곳

**AC:** AC18(「묶음 낡음을 재지 못했다」 알림).

**Files:**
- Modify: `scripts/team_status.py`(`stale`)
- Test: `tests/test_team_stale.sh`

**Interfaces:** 없음(알림 줄만 는다 — `STALE_UNMEASURED` 상수 그대로).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_team_stale.sh` 에 행 넷(그 파일의 픽스처 E3 — plan 단계 결과 파일을 쓴다):

| 이름 | 하는 것 | 단언 | 붉어지는 변이 |
|---|---|---|---|
| 기계 줄이 깨진 plan 결과 | 끝 줄 없는 `plan-plan-1-1.md` 에 꼴이 틀린 `Task` 줄 | E3 알림에 `묶음 낡음을 재지 못했다: plan-plan-1-1.md — Task 줄 꼴이 아니다` 로 시작하는 줄이 하나 | `stale` 의 새 갈래를 지운다 |
| implement 는 두 번 내지 않는다 | 같은 깨짐을 `implement-plan-1-1.md` 에 | 「묶음 낡음을 재지 못했다: implement-plan-1-1.md」 줄이 **없고** 받음 쪽 알림(`받음 줄을 세지 않았다` 또는 `읽지 못함`)은 있다 | 단계 거르기를 지운다 |
| 끝난 파일은 재지 않는다 | 깨진 plan 결과에 끝 줄 | 「재지 못했다」 줄 없음 | 끝 줄 거르기를 지운다 |
| 검수 결과는 재지 않는다 | 깨진 `review-plan-1-1.md` | 「재지 못했다」 줄 없음 | `default_role(stage) is None` 거르기를 지운다 |

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_team_stale.sh | tail -3`
Expected: 첫 행 FAIL

- [ ] **Step 3: 구현한다**

`stale` 의 두 `continue`(`result is None` · `result.problems or lost_lines or end`) 가운데, 단계가 implement 가 아니고 끝 줄이 없는(`result is None` 이면 끝 줄을 모른다 — 알린다) 파일은 `"%s: %s — %s" % (STALE_UNMEASURED, name, <첫 사유>)` 를 내고 넘어간다. 첫 사유는 `result is None` 이면 「글을 읽지 못했다」, 아니면 `(result.problems + team_files.lost_lines(result))[0]`.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `for t in test_team_stale test_team_status test_team_tasks test_start_bundle; do bash plugins/spec-distill/tests/$t.sh | tail -1; done`
Expected: 실패 0 넷(R1 의 단언 셋 — 「알리면 결과 받음 쪽 알림과 겹쳐 있는 단언 셋이 깨진다」 — 이 붉으면 그 셋이 implement 단계인지 본다. implement 면 거르기가 틀린 것이다)

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/team_status.py plugins/spec-distill/tests/test_team_stale.sh
git commit -m "fix(spec-distill): 구현 밖 단계의 읽지 못한 결과 파일을 묶음 낡음을 재지 못했다로 알린다"
```

---

### Task 6: 규칙 사본 고침 — `rules-add` · `rules-drop` · `rules-reset`

**AC:** AC17(「규칙 사본은 리더가 규칙을 처음 고칠 때 생기고」) · AC21(남의 고침이 있으면 고치지 않는다).

**Files:**
- Create: `scripts/leader_seat.py`
- Modify: `scripts/conductor_branch.py`(`main` 에 하위 명령 — 함수 안에서 `leader_seat` 를 가져온다)
- Test: `tests/test_leader_seat.py` · `tests/test_leader_seat_e2e.sh`(걸음 2 를 `rules-add` 로)

**Interfaces:**
- Consumes: 과제 2 · 3.
- Produces:
  - `leader_seat.RULES_BASE_FILE = "rules-base.md"` · `leader_seat.BASE_HEAD = "기본 브랜치 커밋: "`
  - `leader_seat.foreign(root, roadmap_rel: str, tip: str, paths: list) -> Optional[list]` — 기계 상태를 읽어 `team_status.foreign_commits` 를 부른다(읽지 못하면 `None`).
  - `leader_seat.rules_edit(root, roadmap_rel: str, session: str, add: Optional[str] = None, drop: Optional[str] = None, reset: bool = False) -> conductor_branch.Result`
  - 명령줄: `conductor_branch.py rules-add --roadmap R --session S --line L` · `rules-drop … --line L` · `rules-reset --roadmap R --session S`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_leader_seat.py` 에:

```python
NEW = "- [둘] 새 줄 · 조건: 역할=worker · 출처: a · 확인: b"


class RulesEdit(TeamRepo):   # R3 AC17 · AC21
    def copy(self):
        return CB.read(str(self.w), self.tip(), self.team.rules)

    def base_line(self):
        return CB.read(str(self.w), self.tip(), self.team.path(LS.RULES_BASE_FILE))

    def test_first_edit_makes_the_copy_from_the_default_branch_and_records_the_base(self):
        main = self.g("rev-parse", "origin/trunk")
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        self.assertEqual(self.copy(), TEAM_RULE + "\n" + NEW + "\n")
        self.assertEqual(self.base_line(), LS.BASE_HEAD + main + "\n")

    def test_drop_then_reset(self):
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        LS.rules_edit(str(self.w), rm(ALPHA), SID, drop=TEAM_RULE)
        self.assertEqual(self.copy(), NEW + "\n")
        LS.rules_edit(str(self.w), rm(ALPHA), SID, reset=True)
        self.assertIsNone(self.copy())
        self.assertIsNone(self.base_line())

    def test_refuses_bad_or_pointless_lines(self):   # 2 — 아무것도 쓰지 않는다
        before = self.tip()
        for kw in ({"add": "- 태그 없는 줄"}, {"add": TEAM_RULE}, {"drop": NEW}):
            with self.assertRaises(CB.BranchError) as cm:
                LS.rules_edit(str(self.w), rm(ALPHA), SID, **kw)
            self.assertEqual(cm.exception.rc, 2, kw)
        self.assertEqual(self.tip(), before)

    def test_refuses_while_a_foreign_edit_is_unconfirmed(self):   # 남의 고침 위에 내 고침을 얹어 확인된 것으로 넘기지 않는다
        self.write({self.team.rules: "- [남] 남의 줄\n"})
        with mock.patch.object(LS, "foreign", return_value=[("e" * 40, (self.team.rules,))]):
            with self.assertRaises(CB.BranchError) as cm:
                LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        self.assertEqual(cm.exception.rc, 1)
        self.assertIn("확인되지 않은 남의 고침 1", str(cm.exception))
```

넷째 테스트의 `mock` 은 판정 함수의 **답**만 바꾼다 — 실제 남의 커밋으로 거절되는 끝에서 끝은 과제 8 의 `Confirm` 이 잰다. 붉어지는 변이: 사본을 빈 글에서 만든다(첫째) · `rules-base.md` 를 쓰지 않는다(첫째) · `reset` 이 하나만 지운다(둘째) · `parse_rules` 검사를 지운다(셋째의 첫 입력) · 남의 고침 검사를 지운다(넷째).

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_leader_seat.py 2>&1 | tail -3`
Expected: `RulesEdit` FAIL(`leader_seat` 가 없다)

- [ ] **Step 3: `leader_seat.py` 와 하위 명령을 쓴다**

- 머리 문서 문자열: 맡는 일(리더가 쓰는 자리 — 규칙 사본 · 규칙 브랜치 · 남의 고침 확인 · 대기 줄) · 가져오는 모듈(`conductor_branch` · `conductor_state` · `team_status` · `team_rules` · `roadmap_model` · `roadmap_status`(`Git` 만) · `human_lines` · `repo_defaults`) · 종료 코드.
- `rules_edit` — 차례: `CB._need_marker` → `CB.availability`(사유면 `Result(None, False, None, (사유,))`) → 로드맵 머리말이 team 형식인지(아니면 `BranchError(2, "team 형식 로드맵이 아니다 …")`) → 줄 검사(`team_rules.parse_rules(line + "\n")` 가 규칙 하나를 내고 그 `problems` 가 비어야 한다) → 읽을 끝(`CB.seen_tip`)에서 `foreign(…, [team.rules])` 가 비어 있지 않거나 `None` 이면 `BranchError(1, "확인되지 않은 남의 고침 %d — 먼저 confirm 으로 확인받는다")`(재지 못하면 같은 꼴에 「남의 고침을 재지 못했다」). 그 뒤 `CB.write(…, edit, "규칙 <더함|뺌|되돌림>")` — `edit(base)` 는 사본이 있으면 그 줄들, 없으면 기본 브랜치 끝(`repo_defaults.default_branch`)의 규칙 글 줄들에 고침을 적용하고, 사본이 없었으면 `rules-base.md` 도 함께 낸다. 줄 대조는 `==`. 더할 줄이 이미 있거나 뺄 줄이 없으면 `edit` 안에서 `BranchError(2)`.
- `conductor_branch.main` — 하위 파서 넷(`rules-add` · `rules-drop` · `rules-reset` · 과제 7 의 `rules-branch` · 과제 8 의 `confirm` 은 그 과제가 더한다). 함수 안에서 `import leader_seat as LS`(맨 위에서 가져오면 서로 가져온다 — `delete` 가 `conductor_status` 를 가져오는 꼴 그대로).
- `test_leader_seat_e2e.sh` 걸음 2 를 `python3 "$S/conductor_branch.py" --root "$W" rules-add --roadmap "$RM" --session "$SID" --line "<규칙 줄>"` 로 바꾼다.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_conductor_branch.py 2>&1 | tail -1; bash plugins/spec-distill/tests/test_leader_seat_e2e.sh | tail -1; python3 -m unittest plugins/spec-distill/tests/test_team_layout.py 2>&1 | tail -1`
Expected: `OK` · 실패 0 · `OK`(`test_team_layout.py` 가 `leader_seat.py` 에 `RULES.md` 글자가 없는지 본다 — `Team.rules` 를 쓴다)

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/leader_seat.py plugins/spec-distill/scripts/conductor_branch.py plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_leader_seat_e2e.sh
git commit -m "feat(spec-distill): 리더가 상태 브랜치의 규칙 사본을 줄 단위로 고치는 명령을 둔다"
```

---

### Task 7: `rules-branch` · 사본이 같아지면 지우기 · 갈라짐 알림

**AC:** AC17(「기본 브랜치의 글과 같아지면 `sync` 가 지운다 · 다르면 STATUS 가 달라진 줄 수 · `rules-branch` 는 기본 브랜치에서 딴 브랜치에 그 파일만 바꾼 커밋 하나 · 다른 손으로 바뀌어 있으면 `sync` 가 알리고 `rules-branch` 는 만들지 않고 차이를 낸다(1)」).

**Files:**
- Modify: `scripts/leader_seat.py`(`rules_state` · `rules_branch`) · `scripts/conductor_branch.py`(`main` 의 `rules-branch`) · `scripts/conductor_status.py`(`sync` 의 쓰기에 사본 지우기 · 갈라짐 알림)
- Test: `tests/test_leader_seat.py` · `tests/test_conductor_status.py`

**Interfaces:**
- Consumes: 과제 6.
- Produces:
  - `leader_seat.RulesState = NamedTuple("RulesState", [("copy", Optional[str]), ("base", Optional[str]), ("now", Optional[str]), ("verdict", str)])` — `verdict` 는 `"없음"`(사본 없음) · `"같음"`(지금 글 == 사본) · `"올릴 것"` · `"갈라짐"`.
  - `leader_seat.rules_state(root, roadmap_rel: str, tip: str) -> RulesState`
  - `leader_seat.rules_branch(root, roadmap_rel: str, session: str, branch: str) -> str`(만든 커밋 40자)
  - 고정 글자 `DIVERGED = "규칙 사본이 기본 브랜치와 갈라졌다"` · `NOTHING = "올릴 규칙 고침이 없다"`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_leader_seat.py` 에:

```python
class RulesBranch(TeamRepo):   # R3 AC17
    def test_one_commit_one_file_from_the_default_branch(self):
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        main = self.g("rev-parse", "origin/trunk")
        before = self.snap()
        commit = LS.rules_branch(str(self.w), rm(ALPHA), SID, "chore/alpha-rules")
        self.assertEqual(self.g("rev-parse", "refs/heads/chore/alpha-rules"), commit)
        self.assertEqual(self.g("rev-parse", commit + "^"), main)
        self.assertEqual(self.g("diff-tree", "--no-commit-id", "--name-only", "-r", commit), self.team.rules)
        self.assertEqual(self.g("show", "%s:%s" % (commit, self.team.rules)), (TEAM_RULE + "\n" + NEW))
        self.assertEqual(self.snap(), before)   # 작업 폴더를 건드리지 않는다

    def test_diverged_default_refuses_with_the_difference(self):   # 1 · 브랜치를 만들지 않는다
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        self.put({self.team.rules: "- [다른] 다른 손 · 조건: 역할=worker · 출처: a · 확인: b\n"})
        self.assertEqual(LS.rules_state(str(self.w), rm(ALPHA), self.tip()).verdict, "갈라짐")
        with self.assertRaises(CB.BranchError) as cm:
            LS.rules_branch(str(self.w), rm(ALPHA), SID, "chore/alpha-rules")
        self.assertEqual(cm.exception.rc, 1)
        self.assertIn(LS.DIVERGED, str(cm.exception))
        self.assertIn("다른 손", str(cm.exception))
        self.assertEqual(self.rc("rev-parse", "--verify", "-q", "refs/heads/chore/alpha-rules"), 1)

    def test_nothing_to_raise(self):
        with self.assertRaises(CB.BranchError) as cm:
            LS.rules_branch(str(self.w), rm(ALPHA), SID, "chore/alpha-rules")
        self.assertEqual((cm.exception.rc, LS.NOTHING in str(cm.exception)), (1, True))

    def test_refuses_state_prefix_and_existing_branch(self):
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        with self.assertRaises(CB.BranchError) as cm:
            LS.rules_branch(str(self.w), rm(ALPHA), SID, "conductor/x")
        self.assertEqual(cm.exception.rc, 2)
        self.g("branch", "chore/taken", "trunk")
        with self.assertRaises(CB.BranchError) as cm:
            LS.rules_branch(str(self.w), rm(ALPHA), SID, "chore/taken")
        self.assertEqual(cm.exception.rc, 3)
```

`tests/test_conductor_status.py` 에(그 파일의 `sync` 를 부르는 꼴을 따른다 — team 형식 픽스처는 `test_leader_seat.TeamRepo` 를 가져다 쓴다):

| 이름 | 하는 것 | 단언 | 붉어지는 변이 |
|---|---|---|---|
| 같아지면 지운다 | 사본을 만든 뒤 기본 브랜치에 그 글을 `put`(PR 머지 흉내) → `sync` | 읽을 끝에 사본 · `rules-base.md` 가 없다 · STATUS 「안 올린 규칙 고침」 이 `0줄` | `sync` 의 지우기 갈래를 지운다 |
| 올릴 것이면 남긴다 | 사본만 → `sync` | 사본이 있다 · STATUS 가 `1줄`(양성 대조) | 지우기 조건을 `!=` 로 |
| 갈라지면 알린다 | 사본 뒤 기본 브랜치를 다른 글로 → `sync` | `Synced.notes` 에 `규칙 사본이 기본 브랜치와 갈라졌다` 로 시작하는 줄 · 사본은 남는다 | 알림을 지운다 |

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_conductor_status.py 2>&1 | tail -3`
Expected: 새 테스트 FAIL

- [ ] **Step 3: 구현한다**

- `rules_state` — 사본(`CB.read(tip, team.rules)`) · `rules-base.md` 의 커밋(한 줄이 `BASE_HEAD + 40자` 와 `fullmatch` 될 때만) · 기본 브랜치 지금 글. M8 의 표대로 `verdict`.
- `rules_branch` — 표지 → availability → 이름 검사(`team_layout.STATE_BRANCH_PREFIX` 로 시작하면 2 · `CB.branch_rule(root)` 이 `"규칙"` 이면 그 정규식의 `match` 가 받아야 한다 · 읽지 못하면 3) → 남의 고침(1) → `rules_state` 가 `"없음"`/`"같음"` 이면 `NOTHING` 1 · `"갈라짐"` 이면 `difflib.unified_diff(지금 글, 사본)` 를 `visible` 을 거쳐 줄마다 `│ ` 를 붙여 `DIVERGED` 아래에 싣고 1 → `CB._build_commit(root, <기본 브랜치 끝>, {team.rules: 사본}, "chore(conductor): 규칙 고침을 올린다 · 세션 <8자>", False)` → `CB.git(root, "update-ref", "refs/heads/" + branch, commit, CB.ZERO_OID)` 가 실패하면 3(이미 있다 · 이름이 틀렸다).
- `conductor_status.sync` — 쓰는 `edit` 가 STATUS 와 함께, `rules_state` 가 `"같음"` 이면 `{team.rules: None, team.path(RULES_BASE_FILE): None}` 를 더 낸다. `"갈라짐"` 이면 `notes` 에 `DIVERGED + " — conductor_branch.py rules-branch 는 만들지 않는다"`. STATUS 의 줄 수는 지운 뒤의 끝에서 센다(`build_status` 가 `base.commit` 을 받으므로 지운 사본은 0).

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_conductor_status.py plugins/spec-distill/tests/test_conductor_branch.py 2>&1 | tail -1`
Expected: `OK`

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/leader_seat.py plugins/spec-distill/scripts/conductor_branch.py plugins/spec-distill/scripts/conductor_status.py plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_conductor_status.py
git commit -m "feat(spec-distill): 규칙 고침을 올리는 작은 브랜치를 만들고 머지된 사본은 sync 가 지운다"
```

---

### Task 8: 남의 고침 확인 — `confirm` · 기준 끝 옮기기 · `sync` 와 `show` 의 알림

**AC:** AC21(「`sync` 와 `show` 가 「확인되지 않은 남의 고침 n」 을 알린다 · 확인한 끝은 기계 상태에 남고 · 확인한 뒤에는 그 내용을 쓴다」).

**Files:**
- Modify: `scripts/leader_seat.py`(`confirm` · `settle`) · `scripts/conductor_branch.py`(`main` 의 `confirm`) · `scripts/conductor_status.py`(`sync` · `cross_view` · `render_view`)
- Test: `tests/test_leader_seat.py` · `tests/test_conductor_cross.py`

**Interfaces:**
- Produces:
  - `leader_seat.FOREIGN = "확인되지 않은 남의 고침 %d"` · `leader_seat.CONFIRM_TIP = "확인할 끝: %s"`
  - `leader_seat.confirm(root, roadmap_rel: str, session: str, confirmed: Optional[str] = None) -> tuple`(`(확인한 끝, 알림들)` — `confirmed` 가 없거나 끝이 다르면 `BranchError(1, <보고>)`)
  - `leader_seat.settle(root, roadmap_rel: str, session: str, tip: str) -> Optional[int]`(남의 고침 수 · 0 이면 `확인한 끝` 절을 `확인 · tip` 한 줄로 줄였다 · 재지 못하면 `None`)
  - `conductor_status.cross_view(...)["foreign"]`: `int | None`(내 로드맵)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_leader_seat.py` 에 — 실제 둘째 클론의 남의 커밋으로:

```python
class Confirm(TeamRepo):   # R3 AC21 · Review Focus 1
    def foreign_edit(self, label="other", line="남의 줄"):   # 부를 때마다 다른 클론 · 다른 줄(같은 글이면 커밋이 생기지 않는다)
        other = self.clone(label)
        spec = "refs/heads/conductor/%s:refs/remotes/origin/conductor/%s" % (ALPHA, ALPHA)
        self.g("fetch", "-q", "origin", spec, repo=other)
        self.g("update-ref", "refs/heads/conductor/" + ALPHA, "refs/remotes/origin/conductor/" + ALPHA, repo=other)
        self.claim(repo=other, session=OTHER)
        self.write({self.team.rules: TEAM_RULE + "\n- [남] %s · 조건: 역할=worker · 출처: a · 확인: b\n" % line},
                   repo=other, session=OTHER)
        self.g("fetch", "-q", "origin", spec)

    def test_report_then_confirm_with_the_shown_tip(self):
        self.foreign_edit()
        with self.assertRaises(CB.BranchError) as cm:
            LS.confirm(str(self.w), rm(ALPHA), SID)
        report = str(cm.exception)
        self.assertEqual(cm.exception.rc, 1)
        self.assertIn("남의 줄", report)
        tip = report.rsplit(LS.CONFIRM_TIP % "", 1)[1].strip()
        self.assertEqual(tip, self.tip())
        LS.confirm(str(self.w), rm(ALPHA), SID, tip)
        self.assertEqual([(r["끝"], r["까닭"]) for r in self.rows()], [(tip, "확인")])
        self.assertEqual(TS.rules_tip(RS.Git(str(self.w)), self.team, True, self.rows())[0], tip)   # 확인한 뒤에는 그 내용

    def test_a_tip_that_moved_after_the_report_is_not_confirmed(self):
        self.foreign_edit()
        stale = self.tip()
        self.foreign_edit("other2", "남의 둘째 줄")   # 보인 뒤에 또 들어온 남의 고침
        with self.assertRaises(CB.BranchError):
            LS.confirm(str(self.w), rm(ALPHA), SID, stale)
        self.assertNotIn("확인", [r["까닭"] for r in self.rows()])

    def test_remade_write_does_not_launder_a_foreign_edit(self):   # Review Focus 1 · Deferred df3f1a6d
        self.foreign_edit()
        self.write({self.team.status: "y\n"})   # 남의 끝 위에 다시 만든 내 STATUS
        self.assertEqual(LS.settle(str(self.w), rm(ALPHA), SID, self.tip()), 1)
        self.assertIsNone(TS.rules_tip(RS.Git(str(self.w)), self.team, True, self.rows())[0])

    def test_settle_compacts_when_clean(self):   # 양성 대조 — 남의 고침이 없으면 줄인다
        self.write({self.team.status: "y\n"})
        self.assertEqual(LS.settle(str(self.w), rm(ALPHA), SID, self.tip()), 0)
        self.assertEqual([r["까닭"] for r in self.rows()], ["확인"])
```

`tests/test_conductor_cross.py` 에 — `show` 가 내 로드맵 줄 아래에 `확인되지 않은 남의 고침 1 — conductor_branch.py confirm` 을 내고, 0 이면 그 줄이 없다(양성 대조), 기계 상태를 못 읽으면 `남의 고침을 재지 못했다`. `sync` 의 `Synced.notes` 도 같은 글로 시작하는 줄 하나.

붉어지는 변이: `confirm` 의 끝 대조를 지운다(둘째) · `settle` 이 남의 고침이 있어도 줄인다(셋째) · `write` 가 `remote` 를 `씀` 으로 적는다(셋째 — 과제 2 의 변이와 같은 자리) · `show` 의 줄을 지운다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_conductor_cross.py 2>&1 | tail -3`
Expected: `Confirm` 과 새 cross 테스트 FAIL

- [ ] **Step 3: 구현한다**

- `confirm` — 표지 → 읽을 끝(`CB.seen_tip` · 갈라졌으면 3) → `foreign(…, [team.rules, team.path(CB.PENDING_FILE)])`. `confirmed` 가 없으면: 커밋마다 `<8자> · <CB._commit_stamp> · <경로들>` 과 경로마다 그 커밋과 첫째 부모 사이의 차이(`difflib.unified_diff` · `visible` · 줄마다 `│ `), 끝에 `CONFIRM_TIP % tip` — `BranchError(1, 보고)`. 남의 고침이 0 이면 `(tip, ("확인할 남의 고침이 없다",))` 로 0. `confirmed` 는 40자 또는 앞 8자(`CB._counted_tip_ok`) — 맞으면 `확인한 끝` 절을 `[{"끝": tip, "까닭": "확인", …}]` 로 두고 `(tip, ("확인했다 — <8자>",))`. 다르면 다시 센 보고로 1.
- `settle` — `foreign` 이 `[]` 면 절을 `확인 · tip` 한 줄로(`cs.load` · `cs.save`), 수를 돌려준다.
- `conductor_status.sync` — 쓴 뒤 `LS.settle(…, <쓴 뒤 읽을 끝>)` 의 값이 1 이상이면 `notes` 에 `FOREIGN % n + " — conductor_branch.py confirm 으로 차이를 보고 사용자 확인 뒤 기록한다"`, `None` 이면 「남의 고침을 재지 못했다」. 쓰지 않은 경우(달라진 것 없음 · 꺼짐)에도 상태 브랜치가 켜져 있고 있으면 같은 것을 센다.
- `cross_view` · `render_view` — 내 STATUS 아래에 위 한 줄(0 이면 없음). 다른 로드맵의 것은 세지 않는다(그 기계의 확인한 끝을 모른다).
- `conductor_branch.main` — `confirm` 하위 명령(`--confirmed` 는 `delete` 와 같은 꼴 검사).

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_conductor_cross.py plugins/spec-distill/tests/test_conductor_status.py 2>&1 | tail -1; bash plugins/spec-distill/tests/test_conductor_state_branch_e2e.sh | tail -1`
Expected: `OK` · 실패 0

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/leader_seat.py plugins/spec-distill/scripts/conductor_branch.py plugins/spec-distill/scripts/conductor_status.py plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_conductor_cross.py
git commit -m "feat(spec-distill): 남이 올린 규칙 · 대기 줄 고침을 보이고 확인받은 끝까지만 믿는다"
```

---

### Task 9: 대기 줄 — `pending.md`

**AC:** AC16 · AC21(「`flush` 가 그 커밋이 더한 줄을 옮기지 않으며」).

**Files:**
- Modify: `scripts/leader_seat.py`(대기 줄 함수) · `scripts/conductor_ledger.py`(`c_add` · `c_pending` · `c_flush`)
- Test: `tests/test_conductor_ledger.py` · `tests/test_leader_seat.py` · `tests/test_leader_seat_e2e.sh`

**Interfaces:**
- Consumes: 과제 2 · 6 · 8.
- Produces:
  - `leader_seat.pending_on_branch(root, roadmap_rel: str) -> bool`(M14 의 「상태 브랜치 자리」)
  - `leader_seat.pending_rows(root, roadmap_rel: str) -> tuple` — `(줄들, 확인 안 된 줄들)`. 줄은 `{"에픽", "절", "글"}`(기계 상태 줄과 같은 꼴). 확인 안 된 줄은 남의 고침이 더한 것(다중집합).
  - `leader_seat.pending_add(root, roadmap_rel: str, session: str, row: dict) -> CB.Result`
  - `leader_seat.pending_drop(root, roadmap_rel: str, session: str, rows: list) -> CB.Result`(다중집합 빼기)
  - `leader_seat.PENDING_NO_BRANCH` · `PENDING_HUMAN` · `PENDING_FOREIGN`(Global Constraints 의 고정 글자)

R2 의 사람 줄 관문과 만나는 자리: `record --human` 은 INTENT.md 에 바로 쓰고 대기 줄을 거치지 않는다(그대로). 상태 브랜치 자리에서는 `add` 가 사람 줄을 받지 않고 `flush` 가 건너뛴다(M15). `human-check` 는 과제 브랜치 끝의 결정 기록을 읽으므로 옮기기 전의 대기 줄을 보지 않는다(지금과 같다).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_conductor_ledger.py` 에(그 파일의 명령줄 도우미 꼴을 따르고, team 형식 · 상태 브랜치는 `test_leader_seat.TeamRepo` 를 가져다 쓴다 — 과제 폴더 · INTENT.md 가 필요한 `flush` 는 `test_leader_seat_e2e.sh` 가 잰다):

| 이름 | 하는 것 | 단언 | 붉어지는 변이 |
|---|---|---|---|
| 상태 브랜치에 쌓는다 | `add --section "쌓인 기록" --cells "A1 · 지휘 기록 · 가"` | 읽을 끝의 `pending.md` 가 `- A1 · 지휘 기록 · 가\n` · 기계 상태 「쌓인 기록」 은 빔 | `c_add` 의 갈래를 지운다 |
| 브랜치가 없으면 기계 상태 | 상태 브랜치를 만들기 전의 team 로드맵 | 기계 상태에 줄 · 출력에 `상태 브랜치가 없어 기계 상태에 쌓았다` · rc 0 | 알림을 지운다 |
| 꺼져 있으면 기계 상태 · 알림 없음 | `.devbrew.md` 에 `state_branch: 끔` | 기계 상태에 줄 · 출력이 R1 의 글 그대로(`적었다 — 쌓인 기록: …`) | `availability` 검사를 지운다 |
| 옛 형식은 기계 상태 | 옛 형식 ALPHA | 같은 | 형식 검사를 지운다 |
| 사람 줄은 받지 않는다 | 상태 브랜치 자리에서 글 `spec 승인 · …` | rc 2 · `pending.md` 바이트 그대로 | `is_human` 검사를 지운다 |
| 두 자리를 함께 보인다 | 기계 상태에 한 줄(브랜치 전) · 브랜치를 만든 뒤 한 줄 → `pending --roadmap` | 두 줄이 기계 상태 줄 먼저 차례로 | 한 자리만 읽는다 |
| 같은 줄 둘 | 같은 줄을 두 번 `add` | `pending.md` 에 둘(다중집합) | 이미 있는 줄을 거른다 |

`tests/test_leader_seat_e2e.sh` 에 걸음 — 상태 브랜치 자리에서 `add` 둘(같은 줄) → `flush --epic E1 --spec <E1 과제 폴더 안 경로>` → INTENT.md 결정 기록에 그 줄이 하나(결정 기록은 같은 줄을 두 번 쓰지 않는다 — 지금 규칙) · `pending.md` 의 E1 「지휘 기록」 줄 둘이 모두 빠졌다 · 사람 줄(남의 커밋으로 심은 것)은 남고 출력에 `사람 줄이라 옮기지 않은 대기 줄 1` · 남의 고침이 더한 보통 줄도 남고 `확인되지 않은 남의 고침이 더한 대기 줄 1` · `confirm` 뒤의 `flush` 는 그 보통 줄을 옮긴다. 꺼진 설정에서 같은 걸음은 R1 의 출력 그대로(사람 줄이 섞이면 2 로 멈춤).

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py 2>&1 | tail -3; bash plugins/spec-distill/tests/test_leader_seat_e2e.sh | tail -3`
Expected: 새 행 FAIL

- [ ] **Step 3: 구현한다**

- `leader_seat` — `pending_on_branch`: `team_files`/`roadmap_model.frontmatter` 로 작업 폴더의 로드맵 머리말이 team 형식 · `CB.availability` 가 `None` · `CB.local_tip` 이 있음. `pending_rows`: 읽을 끝의 `pending.md` 줄 가운데 `- ` 로 시작하는 것을 ` · ` 로 두 번 갈라(`split(" · ", 2)` — 글에 ` · ` 가 들어도 된다) 줄로. 꼴이 틀린 줄은 버리지 않고 「꼴이 맞지 않는 대기 줄 n」 으로 세어 확인 안 된 쪽에 둔다. 남의 고침 커밋마다 첫째 부모와의 차이에서 더한 줄(다중집합)을 확인 안 된 쪽으로. `pending_add` · `pending_drop` 은 `CB.write(…, edit, "대기 줄 <더함|옮김>")` — `edit` 는 지금 끝의 글에 줄을 붙이거나 앞에서부터 하나씩 뺀다(`_line_edit` 의 규칙과 같다).
- `conductor_ledger.c_add` — `a.section == "쌓인 기록"` 이고 `LS.pending_on_branch` 면 사람 줄 검사(`HL.is_human(_bullet(글))` 이고 `_gate_on(root)` 면 `Fail(2, HUMAN_BY_ARGS % 종류)`) 뒤 `LS.pending_add`. team 형식 · availability `None` 인데 브랜치만 없으면 지금처럼 기계 상태에 쓰고 `PENDING_NO_BRANCH` 를 출력한다. 그 밖은 지금 그대로.
- `c_pending` — 상태 브랜치 자리면 기계 상태 줄 + `pending_rows` 의 줄을 지금 꼴로 낸다. 확인 안 된 줄은 끝에 `   (확인되지 않은 남의 고침)`.
- `c_flush` — 상태 브랜치 자리이고 `team_intent(root, path)` 가 있으면: 옮길 줄 = 기계 상태 줄 + (`pending_rows` 의 줄 − 확인 안 된 줄) 가운데 그 에픽 · 「지휘 기록」. 그 가운데 사람 줄을 따로 세어 뺀다. `_append_decisions(root, intent, 글들)`(사람 줄이 빠졌으므로 멈추지 않는다) → `write_atomic` → 기계 상태에서 그 에픽 줄을 지운다 → `LS.pending_drop`. 출력은 지금 글에 `PENDING_HUMAN` · `PENDING_FOREIGN`(0 이 아닐 때) 줄을 더한다. 그 밖(옛 형식 · 꺼짐 · 브랜치 없음 · 옛 형식 설계문서 경로)은 지금 그대로.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py plugins/spec-distill/tests/test_leader_seat.py 2>&1 | tail -1; for t in test_leader_seat_e2e test_human_record test_human_gate test_conductor_e2e; do bash plugins/spec-distill/tests/$t.sh 2>/dev/null | tail -1; done`
Expected: `OK` · 실패 0(있는 셸 테스트마다)

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/leader_seat.py plugins/spec-distill/scripts/conductor_ledger.py plugins/spec-distill/tests/test_conductor_ledger.py plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_leader_seat_e2e.sh
git commit -m "feat(spec-distill): team 로드맵의 대기 줄을 상태 브랜치의 pending.md 에 쌓고 확인된 줄만 옮긴다"
```

---

### Task 10: 판정 줄 규칙 하나

**AC:** AC18(판정 줄 규칙 하나). **계획 확인 Q1 의 답에 따라 `ruling_said` 의 본문과 아래 표의 기대값 셋이 정해진다** — 이 과제는 (가) 로 썼다.

**Files:**
- Modify: `scripts/workflow_superpowers.py`(`RULING_MARK` · `ruling_said` · `ledger_lines`) · `scripts/conductor_state.py`(`ledger_rulings`) · `scripts/team_files.py`(`_MACHINE_PREFIXES` · `parse_result`)
- Test: `tests/test_workflow_superpowers.py`

**Interfaces:**
- Produces: `workflow_superpowers.RULING_MARK = "Ruling:"` · `workflow_superpowers.ruling_said(line: str) -> Optional[str]`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```python
class OneRulingRule(unittest.TestCase):   # R3 AC18 — 판정 줄 규칙 하나(Q1 = 가)
    CASES = (("- Ruling: 가", "가"), ("Ruling: 나", "나"), ("Task 3: Ruling: 다", "다"),
             ("- **Ruling: 라**", "라**"), ("- parked — x — Ruling: 마", "마"),
             ("원장의 `Ruling:` 줄을 읽는다", "` 줄을 읽는다"), ("판정 없음", None), ("Ruling:", None))
    # (나)면 넷째 · 다섯째 · 여섯째 기대값이 None 이고 셋째가 "다", 첫째 · 둘째는 그대로다.

    def test_the_rule(self):
        for line, said in self.CASES:
            self.assertEqual(W.ruling_said(line), said, line)

    def test_every_reader_uses_the_rule(self):   # 붉어지는 변이: 셋 가운데 하나가 자기 규칙으로 돌아간다
        text = "\n".join(line for line, _said in self.CASES)
        picked = [l for l, s in self.CASES if s is not None]
        self.assertEqual(cs.ledger_rulings(text), [l.strip() for l in picked])
        self.assertEqual(W.ledger_lines(text, 3), ["Ruling: " + s for _l, s in self.CASES if s is not None])
        with mock.patch.object(W, "ruling_said", return_value=None):   # 양성 대조 — 함수를 바꾸면 둘의 답이 함께 바뀐다
            self.assertEqual((cs.ledger_rulings(text), W.ledger_lines(text, 3)), ([], []))

    def test_result_file_grammar_is_unchanged(self):   # 결과 파일 기계 줄은 줄 머리 — 형식 정본의 계약
        r = F.parse_result("---\ntype: job-result\nstage: plan\nattempt: 1\nrole: worker\nhead: %s\nbundle_at: %s\njob_at: %s\n---\n\nRuling: 가\n메모 — Ruling: 나\n" % (("a" * 40,) * 3))
        self.assertEqual(r.rulings, ["Ruling: 가"])
```

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_workflow_superpowers.py 2>&1 | tail -3`
Expected: `OneRulingRule` FAIL(`ruling_said` 가 없다)

- [ ] **Step 3: 구현한다**

- `workflow_superpowers.ruling_said` — (가): `line` 에 `RULING_MARK` 가 있으면 그 뒤 글을 `strip` 해 비지 않으면 그것, 아니면 `None`. `ledger_lines` 는 `_unbullet(raw)` 에 그 함수를 쓴다(출력 그대로).
- `conductor_state.ledger_rulings` — `[l.strip() for l in text.splitlines() if workflow_superpowers.ruling_said(l) is not None]`(줄 전체를 그대로 낸다). 맨 위에서 `import workflow_superpowers` — 이 모듈이 `conductor_state` 를 가져오지 않는지 `python3 -c 'import sys; sys.path.insert(0, "plugins/spec-distill/scripts"); import conductor_state'` 로 본다.
- `team_files` — `_MACHINE_PREFIXES` 의 첫 글자를 `workflow_superpowers.RULING_MARK` 로, `parse_result` 의 `elif line.startswith("Ruling:")` 를 `elif line.startswith(RULING_MARK) and ruling_said(line) is not None` 로(기계 줄 문법은 줄 머리 그대로).

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_workflow_superpowers.py plugins/spec-distill/tests/test_conductor_state.py plugins/spec-distill/tests/test_team_results.py plugins/spec-distill/tests/test_control_plane.py 2>&1 | tail -1; for t in test_roadmap_status test_team_sync test_conductor_e2e; do bash plugins/spec-distill/tests/$t.sh 2>/dev/null | tail -1; done`
Expected: `OK` · 실패 0(정적 검사가 `team_files` 의 새 import 를 「잠긴 파일 밖 로컬 import」 로 잡지 않는다 — `workflow_superpowers` 는 닫힘 안이다)

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/workflow_superpowers.py plugins/spec-distill/scripts/conductor_state.py plugins/spec-distill/scripts/team_files.py plugins/spec-distill/tests/test_workflow_superpowers.py
git commit -m "refactor(spec-distill): 판정 줄을 가려내는 규칙을 변환기의 함수 하나에 둔다"
```

---

### Task 11: 현황 수리 — 「예약 밖 변경」 줄임 · 판정 없음 문구 · 단계 표 락 · 글 출력의 로드맵 밖 과제 · 과제 폴더 없는 작업

**AC:** AC18(과제 폴더 없는 작업 알림 · 리뷰 지적 넷). **계획 확인 Q2 의 답이 `RESERVE_OUTSIDE_MAX` 다** — 이 과제는 다섯으로 썼다.

**Files:**
- Modify: `scripts/roadmap_status.py`(`reserve_notes` · `render` · 상수 `RESERVE_OUTSIDE_MAX = 5`) · `scripts/control_plane.py`(판정 없음 문구 네 자리 · `works_lines`)
- Test: `tests/test_control_plane.py` · `tests/test_team_status.sh` · `tests/test_team_tasks.sh` · `tests/test_roadmap_status.sh`

**Interfaces:**
- Produces: `roadmap_status.outside_line(paths: list) -> str` · `control_plane.NO_JOB_FOLDER = "과제 폴더 없음"`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_control_plane.py` 에:

```python
class StageTableLock(unittest.TestCase):   # R3 AC18 — BUCKETS 와 TASK_STATUS
    def test_every_stage_has_a_bucket_or_is_uncounted(self):
        # 붉어지는 변이: TASK_STATUS 에 단계 하나를 더하고 BUCKETS 에는 안 더한다 · BUCKETS 에서 「결과 받음」 을 지운다
        bucketed = {s for _name, stages in CP.BUCKETS for s in stages}
        self.assertEqual(bucketed | set(CP.UNCOUNTED), set(RS.TASK_STATUS) | {"알 수 없음"})
        self.assertNotEqual(bucketed, set(RS.TASK_STATUS))   # 양성 대조 — 두 집합을 그대로 견주면 다르다(손이 실제로 가른다)


class TeamRulingWording(unittest.TestCase):   # R3 AC18 — team 은 결과 파일
    def test_team_says_result_file_old_says_design_doc(self):
        b = {"id": "E1", "stage": "구현 중", "rulings": None}
        team = {"layout": "team", "blocks": [b]}
        old = {"blocks": [b]}
        self.assertIn("결과 파일의 `Ruling:` 줄도 없다", "\n".join(CP.detail_lines(team, b)))   # 그 파일의 상세 화면 함수 이름으로
        self.assertIn("설계문서 `## 판정` 도 없다", "\n".join(CP.detail_lines(old, b)))
```

(`detail_lines` 는 1320 근처 상세 화면을 내는 함수의 실제 이름으로 바꾼다 — 목록 화면(405 · 409)도 같은 두 단언을 그 함수로 하나 더.)

```python
class NoJobFolder(unittest.TestCase):   # R3 AC18 — 과제 폴더 없는 작업
    def lines(self, report):
        return "\n".join(CP.works_lines(report))

    def report(self, layout):
        r = {"blocks": [{"id": "E1", "kind": "epic"}], "jobs": [{"id": "fix-x"}],
             "machine": {"살아 있는 agent": [], "작업": [
                 {"종류": "구현", "이름": "E1 계획 1", "에픽": "E1", "단계": "진행", "담당": "없음", "근거": "-"},
                 {"종류": "수리", "이름": "fix-x", "에픽": "로드맵 밖", "단계": "진행", "담당": "없음", "근거": "-"},
                 {"종류": "수리", "이름": "지휘자 수리", "에픽": "로드맵 밖", "단계": "진행", "담당": "없음", "근거": "-"},
                 {"종류": "구현", "이름": "E9 계획 1", "에픽": "E9", "단계": "진행", "담당": "없음", "근거": "-"},
                 {"종류": "수리", "이름": "끝난 일", "에픽": "로드맵 밖", "단계": "끝", "담당": "없음", "근거": "-"}]}}
        if layout:
            r["layout"] = layout
        return r

    def test_team_marks_only_rows_without_a_job(self):
        text = self.lines(self.report("team"))
        marked = [l for l in text.splitlines() if l.endswith(" · " + CP.NO_JOB_FOLDER)]
        self.assertEqual([l.split(" — ")[0].strip() for l in marked], ["수리 지휘자 수리", "구현 E9 계획 1"])

    def test_old_format_is_unchanged(self):   # AC20
        self.assertNotIn(CP.NO_JOB_FOLDER, self.lines(self.report(None)))
```

`tests/test_team_status.sh` · `tests/test_team_tasks.sh` 에 — 블록 하나가 예약 밖 파일 일곱을 바꾸면 그 알림이 `예약 밖 변경: <앞 다섯 · 이름 순> 외 2개` 이고(붉어지는 변이: 상한을 지운다), 다섯이면 다섯 그대로(양성 대조). `tests/test_team_tasks.sh` 에 — team 로드맵의 글 출력(`roadmap_status.py <로드맵>`, `--json` 없이)에 `로드맵 밖 과제: 1개` 와 그 과제 줄 · `정보:` 줄이 있다. `tests/test_roadmap_status.sh` 에 — 옛 형식 로드맵의 글 출력에 `로드맵 밖 과제` 가 없다(AC20).

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_control_plane.py 2>&1 | tail -3; for t in test_team_status test_team_tasks; do bash plugins/spec-distill/tests/$t.sh | tail -3; done`
Expected: 새 테스트 FAIL(`StageTableLock` 은 지금도 통과한다 — 통과가 정답인 락이라 Step 4 뒤 변이로 이빨을 본다)

- [ ] **Step 3: 구현한다**

- `roadmap_status.outside_line` — 다섯 이하면 `" · ".join(paths)`, 넘으면 앞 다섯 뒤에 `" 외 %d개" % (len - 5)`. `reserve_notes` 가 `RESERVE_OUTSIDE % outside_line(outside)`.
- `roadmap_status.render` — `report` 에 `jobs` 키가 있을 때만 경로 예약 겹침 줄 앞에 M21 의 줄들. 옛 형식 출력은 바이트 그대로.
- `control_plane` — 판정 없음 문구 네 자리: `report.get("layout") == "team"` 이면 「결과 파일의 `Ruling:` 줄도 없다」(「실행 원장을 읽지 못했고 결과 파일의 `Ruling:` 줄도 없다」 · 「실행 원장도 결과 파일의 `Ruling:` 줄도 없다」). `works_lines` — team 보고면 M22 의 판정으로 줄 끝에 ` · 과제 폴더 없음`.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_control_plane.py 2>&1 | tail -1; for t in test_team_status test_team_tasks test_roadmap_status test_control_plane; do bash plugins/spec-distill/tests/$t.sh | tail -1; done`
Expected: `OK` · 실패 0 넷. 그 뒤 `StageTableLock` 의 변이 둘(커밋 뒤)이 붉은지 본다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/roadmap_status.py plugins/spec-distill/scripts/control_plane.py plugins/spec-distill/tests/test_control_plane.py plugins/spec-distill/tests/test_team_status.sh plugins/spec-distill/tests/test_team_tasks.sh plugins/spec-distill/tests/test_roadmap_status.sh
git commit -m "fix(spec-distill): 현황의 예약 밖 변경 줄임 · team 판정 문구 · 단계 표 락 · 글 출력의 로드맵 밖 과제 · 과제 폴더 없는 작업"
```

---

### Task 12: 단순 작업 브랜치의 PR 캐시

**AC:** AC18(단순 작업 브랜치의 PR 캐시).

**Files:**
- Modify: `scripts/conductor_ledger.py`(`c_pr_refresh`)
- Test: `tests/test_team_tasks.sh`(가짜 `gh` 는 그 파일 · `test_conductor_ledger.py` 가 이미 쓰는 꼴을 따른다)

**Interfaces:** 없음.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

| 이름 | 하는 것 | 단언 | 붉어지는 변이 |
|---|---|---|---|
| 과제 브랜치도 채운다 | team 로드맵에 단순 작업 과제 `fix-x`(브랜치 `chore/fix-x`) · 가짜 `gh` 가 그 브랜치의 PR 하나를 낸다 → `pr-refresh` | 기계 상태 PR 캐시에 `chore/fix-x` 줄(번호 · 열림) · 출력의 브랜치 수에 든다 | `jobs` 를 돌지 않는다 |
| `--epic` 이면 블록만 | `pr-refresh --epic E1` | `chore/fix-x` 줄이 없다 | 갈래 조건을 지운다 |
| 머지된 과제는 `--reset` 에서만 | 기본 브랜치에 커밋된 단순 작업(머지됨) | `--reset` 없이는 줄이 없고 `--reset` 이면 있다 | 단계 거르기를 지운다 |
| 옛 형식은 그대로 | 옛 형식 로드맵 | 가짜 `gh` 가 받은 브랜치 목록이 블록 브랜치뿐 | 형식을 보지 않는다 |

- [ ] **Step 2: 돌려서 실패를 본다** — Run: `bash plugins/spec-distill/tests/test_team_tasks.sh | tail -3` · Expected: 첫 행 FAIL

- [ ] **Step 3: 구현한다** — `blocks` 를 고른 뒤 `a.epic` 이 없으면 `report.get("jobs") or []` 가운데(`--reset` 이 아니면 단계가 `DONE` 밖인) 과제의 `branch` 를 `branches` 에 더하고 `epic_of[br] = 과제 이름`.

- [ ] **Step 4: 돌려서 통과를 본다** — Run: `bash plugins/spec-distill/tests/test_team_tasks.sh | tail -1; python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py 2>&1 | tail -1` · Expected: 실패 0 · `OK`

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/conductor_ledger.py plugins/spec-distill/tests/test_team_tasks.sh
git commit -m "fix(spec-distill): PR 캐시 채우기가 단순 작업 과제의 브랜치도 채운다"
```

---

### Task 13: 계획 1 이 남긴 것 — 같은 질문 다시 · 드문 경우 넷 · 가리기 · 목록 락

**AC:** 없음(설계문서 `## 미룸` 의 R3 행 — 「같은 (에픽, 종류)」 · 「리뷰 잔여」).

**Files:**
- Modify: `scripts/conductor_status.py`(`waiting_add` · `scrub`) · `scripts/conductor_branch.py`(`ensure` · `_write_floor` · `delete` · `_check_delete_form` · `_publish` · `looks_absolute` · `redact` · `state_names`) · `scripts/conductor_mail.py`(`send` 의 차례 · `about` 판정)
- Test: `tests/test_conductor_status.py` · `tests/test_conductor_branch.py` · `tests/test_conductor_mail.py` · `tests/test_conductor_cross.py`

**Interfaces:**
- Produces: `conductor_branch.looks_absolute(token: str) -> bool` · `conductor_branch.state_names(root) -> list` 는 그대로, 새 `conductor_branch.bad_state_names(root) -> int`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

| 파일 · 이름 | 하는 것 | 단언 | 붉어지는 변이 |
|---|---|---|---|
| status · 다시 묻는 질문 창 | `waiting add`(질문 창) → 한 시간 뒤 같은 (에픽, 종류) `waiting add` | 줄 하나 · 언제부터가 둘째 시각 | 갈래를 지운다 |
| status · 턴 끝은 처음 값 | 같은 걸음을 「턴 끝」 으로 | 언제부터가 첫 시각(양성 대조) | 조건에서 건 길을 지운다 |
| status · 다른 세션의 줄 | 넘겨받은 세션이 같은 걸음 | 첫 시각 | 세션 대조를 지운다 |
| branch · 끝난 로드맵 | 블록을 모두 머지한 뒤 `ensure` | rc 0 · `끝난 로드맵이라 상태 브랜치를 만들지 않는다` · ref 없음 | 검사를 지운다 |
| branch · 설정 오류는 0 | `.devbrew.md` 에 모르는 키 → `ensure` · `sync` · `waiting add` · `send` · `ack` · `rules-add` 명령줄 | 모두 rc 0 · 출력에 `레포 설정을 읽지 못해 상태 브랜치를 쓰지 않는다` · ref · 기계 상태 그대로 | `team_of` 를 `availability` 앞으로 되돌린다 |
| mail · 표지 먼저 | 표지 없는 세션이 꼴 틀린 `--kind` 로 `send` | rc 5(2 가 아니다) | 차례를 되돌린다 |
| branch · 견준 끝에 건 지우기 | `delete --confirmed <끝>` 직전에 다른 클론이 같은 브랜치에 올린다(테스트는 `_fetch` 뒤 · push 앞을 `mock.patch.object(CB, "_git_delete", …)` 로 감싸 그 사이에 다른 클론의 실제 push 를 끼운다) | rc 3 · 원격 브랜치가 남아 있다 · 다른 클론의 커밋이 원격에 있다 | lease 를 뗀다 |
| branch · 손으로 만든 머지 커밋 | 로컬에 부모 둘인 커밋을 손으로 만든 뒤 거절되는 쓰기 | rc 3 · `손으로 만든 머지 커밋이 있다` · 원격 그대로 | 검사를 지운다 |
| cross · 이름 꼴이 틀린 상태 브랜치 | `refs/remotes/origin/conductor/Bad_Name` 을 둔다 → `show` | `이름 꼴이 틀린 상태 브랜치 1` | 세지 않는다 |
| status · 한글 사이 `/` | `scrub("리더/담당자/일꾼 · /Users/x/y")` | `리더/담당자/일꾼 · <경로>` | `looks_absolute` 를 `/` 하나로 |
| mail · `about` 의 꼴 | `--about "설계/계획/구현"` · `--about ./a/b` · `--about /tmp/a/b` | 앞 둘 rc 0 · 셋째 rc 2 | 같은 |
| branch · `DONE_STAGES` | `CB.DONE_STAGES == RS.DONE` | 같다 · 양성 대조 `CB.DONE_STAGES != ("머지됨",)` | 한쪽에 단계를 더한다 |

- [ ] **Step 2: 돌려서 실패를 본다** — Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_status.py plugins/spec-distill/tests/test_conductor_branch.py plugins/spec-distill/tests/test_conductor_mail.py plugins/spec-distill/tests/test_conductor_cross.py 2>&1 | tail -3` · Expected: 새 행 FAIL

- [ ] **Step 3: 구현한다**

- `waiting_add` — M24.
- `ensure` — 표지 · availability 뒤에 그 로드맵의 상태 계산(`roadmap_status.py --json <로드맵>` 하나만)이 블록을 모두 `DONE_STAGES` 로 내면 `Result(None, False, None, ("끝난 로드맵이라 상태 브랜치를 만들지 않는다",))`. 상태 계산을 읽지 못하면 지금처럼 간다(만드는 쪽 — 지휘가 막히지 않는다).
- 설정 오류 — `_write_floor` · `ensure` · `delete` 를 뺀 쓰기 명령 모두 `availability` 를 `team_of` 보다 먼저 부른다(`availability` 는 예외를 던지지 않는다). `conductor_mail.send` · `ack` 의 차례도 표지 → availability → 값.
- `delete` — 원격 지우기를 `push --porcelain --force-with-lease=refs/heads/conductor/<이름>:<끝> origin :refs/heads/conductor/<이름>` 로. `_check_delete_form` 이 받는 꼴을 그 넷째 인자가 든 꼴 하나로 바꾼다(`--force-with-lease=` 뒤가 `DELETE_REF_RE` 의 heads 갈래 + `:` + 40자 `fullmatch`) — 다른 push 꼴의 `force` 거절(`PUSH_FORMS`)은 그대로.
- `_publish` — `_commits_between` 의 커밋마다 `cat-file commit` 의 `parent ` 줄이 둘 이상이면 `BranchError(3, "손으로 만든 머지 커밋이 있다 — 상태 브랜치는 스크립트만 쓴다: <8자>")`.
- `looks_absolute` — M26. `redact` · `scrub` · `conductor_mail` 의 `about` 판정이 이것을 부른다.
- `bad_state_names` — `state_names` 가 버린 꼬리의 수. `cross_view` 가 0 이 아니면 「다른 로드맵과 닿는 것」 묶음에 `- 이름 꼴이 틀린 상태 브랜치 <n>` 한 줄.

- [ ] **Step 4: 돌려서 통과를 본다** — Run: Step 2 와 같은 명령 + `bash plugins/spec-distill/tests/test_conductor_state_branch_e2e.sh | tail -1` · Expected: `OK` · 실패 0

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/conductor_status.py plugins/spec-distill/scripts/conductor_branch.py plugins/spec-distill/scripts/conductor_mail.py plugins/spec-distill/tests/test_conductor_status.py plugins/spec-distill/tests/test_conductor_branch.py plugins/spec-distill/tests/test_conductor_mail.py plugins/spec-distill/tests/test_conductor_cross.py
git commit -m "fix(spec-distill): 계획 1 이 남긴 드문 경우 넷과 다시 묻는 질문의 시각 · 가리기 꼴을 바로잡는다"
```

---

### Task 14: (사용자 결정 대기 — U1) 세 번 거절이면 종료 코드

**사용자 결정 대기 — 답에 따라 이 과제를 하거나 건너뛴다.** U1 의 답이 (가)면 건너뛰고 보고에 「U1 (가) — 코드 그대로」 를 적는다. (나)면 아래를 한다.

**AC:** AC3(설계문서의 글자대로 — 「올리지 못하면 … 종료 코드는 0」).

**Files:** Modify `scripts/conductor_branch.py`(`_publish` 의 끝 갈래) · `references/conductor-state-branch.md`(종료 코드 표의 1 행에서 「세 번 다시 만들어도 못 올렸다는 줄이면 사용자에게 알린다」 를 빼고 0 행에 「세 번 다시 만들어도 못 올렸다」 를 더한다) · Test `tests/test_conductor_branch.py`(세 번 거절 테스트의 기대 rc 를 0 으로 · 로컬 커밋이 남았다는 단언은 그대로) · `tests/test_conductor_state_branch_docs.py`.

- [ ] **Step 1:** 테스트의 기대값을 바꾸고 붉은 것을 본다. **Step 2:** `_publish` 끝에서 `raise BranchError(1, REMAKE_GAVE_UP)` 를 `return Result(local_tip(root, name), False, None, (REMAKE_GAVE_UP,), made)` 로. **Step 3:** 문서. **Step 4:** `python3 -m unittest plugins/spec-distill/tests/test_conductor_branch.py plugins/spec-distill/tests/test_conductor_state_branch_docs.py` → `OK`. **Step 5:** 커밋 `fix(spec-distill): 세 번 다시 만들어도 올리지 못하면 로컬 커밋을 남기고 0 으로 알린다`.

---

### Task 15: (사용자 결정 대기 — U2) 두 세션 알림 · 지우기의 수용 기준 줄

**사용자 결정 대기 — 답에 따라 이 과제를 하거나 건너뛴다.** (나)면 건너뛴다. (가)면 지휘자가 설계문서에 더한 AC 번호(예: AC22 · AC23)를 받아:

- 이 계획의 `## AC 가르기` 표와 「대조 스크립트에 주는 목록」 에 그 번호를 더한다(몫 「계획 1 이 구현 · 계획 2 가 대조」).
- 있는 테스트에 번호 주석만 단다 — `tests/test_conductor_status.py` 의 두 세션 알림 테스트(뒤에 쓴 것 · 앞에 쓴 것 · 다른 기계) · `tests/test_conductor_branch.py` 의 `delete` 테스트. 단언은 바꾸지 않는다.
- 커밋 `test(spec-distill): 두 세션 알림과 지우기 테스트에 수용 기준 번호를 단다`.

---

### Task 16: (사용자 결정 대기 — U3) 지우기 확인 표시의 꼴

**사용자 결정 대기 — 답에 따라 이 과제를 하거나 건너뛴다.** (가)(추천 — 지금 꼴을 두고 설계 글자를 맞춘다)면 건너뛴다. (나)면:

- `scripts/conductor_branch.py` — `delete` 의 `--confirmed` 를 값 없는 표시로. 수를 센 끝 대조를 지우는 대신 「확인 표시가 있으면 지금 로컬 끝 · 원격 끝이 같을 때 지운다」 로 좁힌다(움직였으면 다시 세고 1 — 이것만은 남긴다).
- `references/conductor-state-branch.md` 걸음 7 의 1 · 3 · `references/conducting.md` 걸음 7 의 문장 · `tests/test_conductor_branch.py` · `tests/test_conductor_state_branch_docs.py`.
- 커밋 `fix(spec-distill): 지우기 확인 표시를 값 없는 표시로 바꾼다`.

---

### Task 17: (사용자 결정 대기 — U4) 「지금 묻는 질문」 종류와 사람 줄 종류

**사용자 결정 대기 — 답에 따라 이 과제의 갈래 하나를 한다.**

- **(가) 이름을 맞춘다.** `conductor_state.ASK_KINDS` 를 `("설계 대화", "spec 승인", "계획 검토", "흐름 승인", "걸음 건너뜀", "옮긴 질문", "머지", "그 밖")` 로. `_normalized`(읽기 뒤 고침 자리)에서 옛 이름 `계획 확인` 을 `계획 검토` 로 바꿔 읽는다 — 정적 검사가 따라가는 `parse_machine` · `_check_row` 에는 `==` · `in` 만. `references/conductor-state-branch.md` 의 「종류 여섯」 줄 · 테스트(`test_conductor_state.py` · `test_conductor_status.py` · `test_conductor_state_branch_docs.py`). 커밋 `feat(spec-distill): 지금 묻는 질문의 종류 이름을 사람 줄 종류와 맞춘다`.
- **(나) 대응을 적는다.** `references/conductor-state-branch.md` 의 「질문을 걸 때」 절에 표 하나 — `spec 승인` → `spec 승인` · `계획 검토` → `계획 확인` · `흐름 승인` · `걸음 건너뜀` → `그 밖`. `tests/test_conductor_state_branch_docs.py` 에 그 표의 넷째 칸이 모두 `cs.ASK_KINDS` 안이고 첫째 칸이 `human_lines` 의 종류 목록과 같다는 락(붉어지는 변이: 표에서 한 줄을 지운다 · 종류 하나를 바꾼다). 커밋 `docs(spec-distill): 사람 줄 질문을 걸 때 올리는 종류의 대응을 적는다`.

---

### Task 18: 문서와 판

**AC:** AC12(걸음 5) · AC19(계획 2 몫).

**Files:**
- Modify: `references/conducting.md`(걸음 5 의 「기본값」 끝 한 문장 · 걸음 1 「로드맵 밖 일도 한 곳에」 줄 끝에 M22 의 한 문장) · `skills/epic-conductor/SKILL.md`(「5. 지휘 순환」 의 `Read` 펜스 셋째 줄 · 「두 파일의」 → 「세 파일의」) · `references/conductor-state-branch.md`(새 절 셋) · `references/team-files.md`(§5 · §9 · §10 · §15) · `references/roadmap-ontology.md` · `README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json` · `tests/test_repo_literals.sh`(대상에 `scripts/leader_seat.py`)
- Test: `tests/test_conductor_state_branch_docs.py` · `tests/test_team_docs.py`

- [ ] **Step 1: 문서 락을 쓴다(실패하는 테스트)**

`tests/test_conductor_state_branch_docs.py` 에:

```python
class LeaderSeatDocs(unittest.TestCase):   # R3 AC12(걸음 5) · AC19(계획 2 몫)
    def test_step_five_and_the_skill(self):
        for word in (FILE_NAME, "안 올린 규칙 고침", "conductor_branch.py rules-branch", "판 번호"):
            self.assertIn(word, step(5), word)
        self.assertNotIn("rules-branch", step(4))   # 양성 대조 — 걸음 가르기가 이웃 걸음을 잡지 않는다
        skill = (PLUGIN / "skills" / "epic-conductor" / "SKILL.md").read_text(encoding="utf-8")
        self.assertIn("Read " + POINTER, skill)

    def test_procedure_file_has_the_three_new_sections(self):
        text = NEW.read_text(encoding="utf-8")
        for head in ("## 규칙을 고칠 때", "## 남이 올린 고침을 만났을 때", "## 대기 줄"):
            self.assertIn(head, text, head)
        for word in ("conductor_branch.py rules-add", "rules-drop", "rules-reset", "conductor_branch.py confirm",
                     "확인할 끝", "pending.md", "사람 줄이라 옮기지 않은 대기 줄", "확인되지 않은 남의 고침"):
            self.assertIn(word, text, word)
        self.assertNotIn("AskUserQuestion", text)

    def test_team_files_now_moved(self):
        text = (PLUGIN / "references" / "team-files.md").read_text(encoding="utf-8")
        self.assertNotIn("RULES.md 의 고침과 대기 줄은 아직 옮기지 않았다", text)
        for word in ("rules_at", "--rules-at", "pending.md", "rules-base.md", "team_status.rules_tip", "확인한 끝"):
            self.assertIn(word, text, word)

    def test_readme_and_changelog_section_of_this_version(self):
        readme = (PLUGIN / "README.md").read_text(encoding="utf-8")
        for word in ("rules-add", "rules-branch", "confirm", "pending.md", "rules_at"):
            self.assertIn(word, readme, word)
        version = json.loads((PLUGIN / ".claude-plugin" / "plugin.json").read_text(encoding="utf-8"))["version"]
        log = (PLUGIN / "CHANGELOG.md").read_text(encoding="utf-8")
        section = log.split("\n## [%s]" % version, 1)[1].split("\n## [", 1)[0]
        for word in ("leader_seat.py", "rules_at", "pending.md", "확인한 끝", "confirm"):
            self.assertIn(word, section, word)
```

계획 1 의 `test_team_files_no_longer_says_undecided` 끝 줄(`assertIn("RULES.md 의 고침과 대기 줄은 아직 옮기지 않았다", …)` — 「계획 2 가 옮기면서 이 단언을 뒤집는다」)을 지운다(위 셋째가 뒤집은 단언을 맡는다). 붉어지는 변이: 걸음 5 문장을 지운다 · SKILL 의 `Read` 줄을 지운다 · 새 절 하나를 지운다 · §15 의 옛 문장을 되살린다 · CHANGELOG 의 이 판 절에서 낱말 하나를 지운다(판으로 고른 절만 본다 — 맨 위 절을 가정하지 않는다).

- [ ] **Step 2: 돌려서 실패를 본다** — Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_state_branch_docs.py 2>&1 | tail -3` · Expected: `LeaderSeatDocs` FAIL

- [ ] **Step 3: 문서를 쓴다**

- `conducting.md` 걸음 5 「기본값」 끝: 「상태 브랜치의 「안 올린 규칙 고침」 이 있으면 PR 마다 함께 알리고 `conductor_branch.py rules-branch` 로 작은 브랜치를 만들어 지금 절차대로 PR 을 연다 — 판 번호는 `conductor_status.py show` 의 판 번호 줄을 보고 정한다(`conductor-state-branch.md`).」 루트 토큰을 쓰지 않는다(그 파일의 락).
- `conductor-state-branch.md` — 「## 맞출 때(걸음 1)」 에 6 번 「`sync` 가 「확인되지 않은 남의 고침 n」 을 내면 `confirm` 을 `--confirmed` 없이 돌려 낸 차이를 사용자에게 그대로 보이고 문장으로 묻는다 — 받아들이면 같은 명령을 `--confirmed <확인할 끝>` 으로. 확인 전에는 규칙은 기본 브랜치의 글이 실리고 그 커밋이 더한 대기 줄은 옮기지 않는다」. 새 절 셋 — `## 규칙을 고칠 때`(명령 셋과 꼴 · 사본과 `rules-base.md` · 다음 시작 묶음부터 실린다 · 「배운 것」 편지는 규칙 절차를 거친 뒤에만) · `## 남이 올린 고침을 만났을 때`(위 6 의 자세한 꼴 · 「확인할 끝」 · 끝이 바뀌면 다시) · `## 대기 줄`(team 형식이면 `pending.md` · 브랜치가 없으면 기계 상태 · 사람 줄은 넣지 않는다 · `flush` 의 두 알림). 종료 코드 표의 1 행에 「확인 없는 `confirm` 이면 낸 차이를 사용자에게 보이고 묻는다 · 갈라진 `rules-branch` 면 차이를 보인다」.
- `team-files.md` — §5 머리 예시에 `rules_at: <시작 묶음이 팀 규칙을 읽은 커밋 — 없으면 bundle_at 으로 견준다>` · 키 설명 줄에 `rules_at` · 「이어 쓰기」 에 `--rules-at` 은 둘과 함께만. §9 「맞추는 명령」 예시 줄 끝에 `--rules-at <커밋>`, 규칙 머리 줄 설명(두 커밋). §10 「묶음 낡음」 — 규칙은 `rules_at`(없으면 `bundle_at`)에서 · 구현 밖 단계의 읽지 못한 결과 파일은 「재지 못했다」. §15 표의 「INTENT.md 결정 기록」 행 · 「리더가 쓰는 자리」 · 「지금의 값」 을 새 사실로 — 규칙은 `team_status.rules_tip` 이 계산한 상태 브랜치 끝(확인된 사본이 있을 때)에서 · 규칙 고침은 `rules-add` · `rules-drop` 과 `rules-branch` PR · 대기 줄은 `pending.md`(꺼져 있거나 브랜치가 없으면 기계 상태) · 남의 고침은 `confirm` 전까지 쓰지 않는다 · 「확인한 끝」 은 기계 상태에. `## 목차` 가 있으면 맞춘다.
- `roadmap-ontology.md` — 기계 상태 줄의 속성 칸에 「 · 확인한 끝」, 상태 브랜치 줄의 속성 칸에 「 · 규칙 사본 · 대기 줄」(객체를 더하지 않는다 — 객체 목록 락을 고치지 않는다).
- `README.md` — 「지휘자 상태 브랜치」 절에 「리더가 쓰는 자리(team 형식)」 문단(규칙 고침 명령 · `rules-branch` · `confirm` · 대기 줄 · `rules_at`) · 「Principles Instantiated」 에 한 줄(Law 2 쪽 — 남이 올린 고침은 사람이 확인한 끝까지만 믿는다).
- `CHANGELOG.md` — 새 머리 `## [<다음 minor>] — <날짜>`. Added: `leader_seat.py` · `conductor_branch.py` 의 `rules-add` · `rules-drop` · `rules-reset` · `rules-branch` · `confirm` · 결과 파일 머리 `rules_at` 과 `job sync --rules-at` · 기계 상태 「확인한 끝」 절 · team 형식 대기 줄 `pending.md`. Changed: `leader_ref` 의 꼴 · 「묶음 낡음」 의 규칙 대조 · 판정 줄 규칙 하나 · 현황 수리 · 단순 작업 PR 캐시 · 계획 1 잔여(이름으로). Fixed: 「묶음 낡음」 빈 곳 · 드문 경우 넷. 「이 판 앞의 설치본은 이 판이 쓴 기계 상태를 「더 새 판이 썼다」 로 멈춘다」 한 줄.
- `plugin.json` — 판(Global Constraints 「판」).
- `tests/test_repo_literals.sh` — `TARGETS` 에 `scripts/leader_seat.py`.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_state_branch_docs.py plugins/spec-distill/tests/test_team_docs.py plugins/spec-distill/tests/test_roadmap_ontology.py 2>&1 | tail -1; for t in plugins/spec-distill/tests/test_repo_literals.sh plugins/spec-distill/tests/test_epic_conductor_skill.sh plugins/spec-distill/tests/test_conducting_reference.sh plugins/spec-distill/tests/test_readme_sync.sh shared/tests/test_changelog_integrity.sh shared/tests/test_no_new_duplication.sh shared/tests/test_skill_reference_pointers.sh shared/tests/test_ask_recommendation.sh shared/tests/test_shell_tests_executable.sh; do printf '%s: ' "$t"; bash "$t" 2>/dev/null | tail -1; done`
Expected: `OK` · 실패 0 아홉(없는 파일은 건너뛴다고 적는다)

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/references/conducting.md plugins/spec-distill/skills/epic-conductor/SKILL.md plugins/spec-distill/references/conductor-state-branch.md plugins/spec-distill/references/team-files.md plugins/spec-distill/references/roadmap-ontology.md plugins/spec-distill/README.md plugins/spec-distill/CHANGELOG.md plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/tests/test_repo_literals.sh plugins/spec-distill/tests/test_conductor_state_branch_docs.py plugins/spec-distill/tests/test_team_docs.py
git commit -m "docs(spec-distill): 리더가 쓰는 자리 · rules_at · 대기 줄 · 남의 고침 확인을 문서에 적고 판을 올린다"
```

---

### Task 19: 끝에서 끝 · 옛 동작 · 변이 · 전체 스위트

**AC:** AC20(계획 2 몫) · AC14(`leader_ref` 꺼짐) · AC15 · AC16 · AC17 · AC21 의 끝에서 끝.

**Files:** Modify `tests/test_leader_seat_e2e.sh` · `tests/test_leader_seat.py`.

- [ ] **Step 1: 끝에서 끝 걸음을 채운다**

`tests/test_leader_seat_e2e.sh` 에 아직 없는 걸음을 더한다 — ① `rules-add` → 묶음 → `job sync` → `rules-add` → 「묶음 낡음」 은 앞 결과에만(과제 4 의 걸음이 있으면 그것) ② 둘째 클론(`git clone file://…`)이 상태 브랜치의 규칙 사본과 `pending.md` 를 고쳐 올린다 → 첫 클론이 받아 온 뒤 `sync` 의 「확인되지 않은 남의 고침 2」 · 묶음의 `알림: 확인되지 않은 남의 고침 1 — 규칙은 기본 브랜치의 글을 읽는다` 와 규칙 머리가 기본 브랜치 커밋 · `flush` 가 그 줄을 옮기지 않음 → `confirm` 보고 → `--confirmed <끝>` → 묶음이 사본을 싣고 `flush` 가 옮긴다 ③ `rules-branch chore/<로드맵>-rules` → 그 브랜치를 기본 브랜치에 머지(테스트 안의 `git merge`) → `sync` 가 사본을 지우고 STATUS 가 `0줄` ④ `state_branch: 끔` 으로 바꾼 뒤 같은 레포에서 — 묶음의 규칙 머리가 기본 브랜치(AC14) · `add` · `pending` · `flush` 가 기계 상태 · R1 출력 그대로(AC20).

- [ ] **Step 2: 변이 표를 돌린다**

커밋한 뒤 아래 변이를 하나씩 넣고 `PYTHONDONTWRITEBYTECODE=1` 로 그 줄의 테스트를 돌려 붉은지 본다. 되돌림은 `git checkout HEAD -- <파일>` 뒤 `git diff HEAD --stat` 가 빈지로. 결과(변이 · 붉어진 테스트 이름 · 되돌림 확인)를 과제 보고에 표로 싣는다. 하나라도 초록이면 그 락에 이빨을 더한 뒤 다시 돈다.

| # | 변이 | 붉어야 할 테스트 |
|---|---|---|
| 1 | `team_status.rules_tip` 의 `if not on` 갈래를 지운다 | `RulesTip.test_off_means_default_even_with_a_copy` · e2e ④ |
| 2 | `rules_tip` 이 남의 고침을 보지 않는다 | `RulesTip.test_foreign_copy_is_not_read_until_confirmed` · e2e ② |
| 3 | `conductor_branch._publish` 가 다시 만든 쓰기를 `씀` 에 적지 않는다 | `OwnCommits.test_remade_on_foreign_tip_records_only_mine` |
| 4 | `_publish` 가 `remote` 를 `씀` 에 적는다 | `Confirm.test_remade_write_does_not_launder_a_foreign_edit` |
| 5 | `leader_seat.confirm` 의 끝 대조를 지운다 | `Confirm.test_a_tip_that_moved_after_the_report_is_not_confirmed` |
| 6 | `team_status.stale` 이 `rules_at` 대신 `bundle_at` 으로 견준다 | e2e 과제 4 걸음 6 |
| 7 | `c_flush` 가 확인 안 된 줄을 빼지 않는다 | e2e ② 의 `flush` |
| 8 | `c_flush` 가 사람 줄을 건너뛰지 않는다(상태 브랜치 자리) | e2e 과제 9 의 사람 줄 걸음 |
| 9 | `c_add` 가 꺼진 설정에서도 `pending.md` 에 쓴다 | `test_conductor_ledger.py` 「꺼져 있으면 기계 상태」 |
| 10 | `rules_branch` 가 갈라짐을 보지 않는다 | `RulesBranch.test_diverged_default_refuses_with_the_difference` |
| 11 | `conductor_status.sync` 가 같아진 사본을 지우지 않는다 | 「같아지면 지운다」 · e2e ③ |
| 12 | `roadmap_status.outside_line` 의 상한을 지운다 | `test_team_status.sh` 의 줄임 행 |
| 13 | `CP.BUCKETS` 에서 「결과 받음」 을 지운다 | `StageTableLock` |
| 14 | `team_files.parse_result` 가 `rules_at` 꼴을 보지 않는다 | `test_rules_at_is_optional_but_closed` |
| 15 | `_check_delete_form` 이 lease 없는 지우기도 받는다(코드는 lease 를 뗀다) | 「견준 끝에 건 지우기」 |

- [ ] **Step 3: AC20 의 기준 코드 대조를 한 번 돈다(커밋하지 않는다)**

`$TMPDIR` 에 스크립트를 두고 돈다: `base=$(git merge-base HEAD origin/main)` · `git archive "$base" plugins/spec-distill/scripts | tar -x -C "$TMPDIR/base"` · 같은 team 픽스처(`team_repo.sh` 의 `new_repo` — 상태 브랜치를 만들지 않음 · 다음 판에 `state_branch: 끔`)에서 기준 스크립트와 이 브랜치 스크립트로 `control_plane.py show --tasks <로드맵>` · `roadmap_status.py <로드맵>` · `roadmap_status.py --json <로드맵>` · `conductor_ledger.py pending --roadmap <로드맵>` · `start_bundle.py --roadmap <로드맵> --role leader` 를 돌려 출력을 `diff` 한다. 기대 — 다른 줄은 이 계획이 일부러 바꾼 것뿐(team 글 출력의 `로드맵 밖 과제` · 묶음 「맞추는 명령」 끝의 `--rules-at` · 판정 없음 문구 · `예약 밖 변경` 줄임). 같은 대조를 옛 형식 로드맵(`conductor_branch_fixture` 꼴)으로도 하고 그때는 **차이가 0** 이다. 결과를 과제 보고에 싣는다.

- [ ] **Step 4: 전체 스위트**

Global Constraints 의 잠금 줄 그대로 돈다. 못 잡으면 주인 · 잡은 시각을 보고한다. `FAILED` 줄마다 이 브랜치의 변경과 닿는지 적는다 — worktree 에서만 나는 기존 실패(`TestCrossResolverAdvisory` 등)는 그렇다고 적는다. 이 브랜치에만 있는 실패가 0 이 될 때까지 그 과제의 뜻 안에서 고친다(pathspec 커밋).

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/tests/test_leader_seat_e2e.sh plugins/spec-distill/tests/test_leader_seat.py
git commit -m "test(spec-distill): 리더가 쓰는 자리의 끝에서 끝과 꺼진 설정의 옛 동작을 잰다"
```

---

## 실행 방식의 마지막 전체 리뷰

고른 실행 방식의 마지막 전체 리뷰(subagent-driven 의 브랜치 전체 리뷰 · native 의 마지막 리뷰)의 리뷰어에게 아래를 그대로 싣는다.

- 설계문서 `## Acceptance Criteria` 의 AC 목록 원문과 이 계획의 `## AC 가르기` 표.
- 요청: 계획 2 몫 AC(`AC12 · AC14~AC21`)마다 한 줄씩 `AC<n>: <구현됨|미룸|빠짐> — <근거(파일:줄 · 테스트 이름 · 명령 결과)>` 꼴로 보고하라. 걸친 AC(AC12 · AC14 · AC17 · AC19 · AC20)는 계획 1 이 한 부분과 이 계획이 한 부분을 함께 보고 둘이 다 됐으면 `구현됨` 이다.
- 요청: 설계문서 `## 있는 것 검토` 가 고른 것을 실제로 썼는지, 같은 것을 다시 만들지 않았는지 줄마다 답하라 — `team_layout` 의 자리(`Team.rules` · `Team.path`)와 `leader_ref` 이름을 그대로 쓰는가 · 대기 줄은 `conductor_ledger.py add · pending · flush` 의 줄 꼴과 옮기는 길(`_append_decisions`)을 그대로 쓰는가 · 상태 브랜치 쓰기는 `conductor_branch.write` 하나를 거치는가(다른 커밋 만들기 코드를 새로 쓰지 않았는가) · 브랜치 끝 고르기는 `branch_tip.tip` 인가 · 규칙 줄의 꼴은 `team_rules.parse_rules` 인가 · 브랜치 규칙 판정은 `conductor_branch.branch_rule` 인가.
- 끝에서 끝 흐름 넷을 따로 물어라 — 각 이음매의 종료 코드 소비와 상태 가정: ① `rules-add` → 시작 묶음(규칙 머리 두 커밋 · `--rules-at`) → `job sync` → `rules-add` → 상태 계산의 「묶음 낡음」(앞 결과에만) ② 다른 클론의 규칙 사본 · `pending.md` 고침 → 받아 오기 → `sync` · `show` 의 「확인되지 않은 남의 고침」 · 묶음 알림 · `flush` 가 옮기지 않음 → `confirm` → 확인 뒤 사용 ③ `rules-branch` → 머지 → `sync` 가 사본을 지움 → 다음 묶음이 기본 브랜치 규칙 ④ 올리기 거절 → 다시 만들기(내 `pending.md` 줄 · 내 규칙 고침이 있을 때) → `확인한 끝` 의 `씀` 줄과 남의 커밋이 섞이지 않는가.
- 요청: **남의 글이 들어오는 자리**가 닫히는 쪽으로 실패하는지 따로 답하라 — 원격에서 온 커밋 · 규칙 사본 · `pending.md` · `rules-base.md` 의 글자가 경로 · git 인자 · 출력 틀로 들어가는 곳마다(`rules_state` 의 커밋 줄 · `confirm` 의 차이 · `pending_rows` 의 줄 가르기 · `rules-branch` 의 이름). 남이 심은 글 하나(꼴이 틀린 `rules-base.md` · 아주 긴 줄 · 제어 글자 · 같은 줄 여럿)로 `sync` · `show` · `flush` · 시작 묶음이 예외로 죽거나, 확인 전의 남의 줄이 시작 묶음 · 결정 기록에 들어가는 길이 남아 있는지.
- 요청: 「이 기계가 쓴 커밋」 기록이 빠지는 길(예외로 끝난 쓰기 · `ensure` 의 받아 오기 · `delete`)과, 남의 커밋을 `씀` 으로 적는 길이 없는지.
- 요청: 꺼 둔 설정 · 옛 형식 · 상태 브랜치 없음에서 R1 의 동작(묶음 · 「묶음 낡음」 · `add` · `pending` · `flush` 의 출력과 종료 코드)이 바뀌는 길이 없는지(AC20) — 과제 19 Step 3 의 대조 결과를 함께 본다.
- 요청: 상태 계산의 닫힘 — `team_status.py` · `team_layout.py` · `roadmap_status.py` 에 더한 코드가 정적 검사가 받는 호출만 쓰는지, `READERS` 에 더한 이름이 `TRUST` 하나뿐인지, 상태 계산 · 현황 화면이 `leader_seat` · `conductor_branch` 를 가져오지 않는지.
- 요청: R2 의 사람 줄 관문(시작 묶음 · 결과 대조 · `record --human` · `human-check`)과 이 계획의 `rules_at` · `pending.md` · `flush` 가 만나는 자리에서 관문이 약해진 곳이 없는지.
- 이 계획이 쓴 테스트 코드(과제 2 – 13 · 18 의 파이썬 테스트와 표)는 계획이 정한 것이라는 표시를 붙여, 덜 보지 말고 같은 눈으로 보라고 적는다 — mock 된 거절(과제 6 의 넷째는 판정 함수의 답만 바꾼다 — 실제 거절은 과제 8 이 잰다)과 공허한 단언을 찾으라고. 기존 테스트를 고친 곳(`test_start_bundle.sh` · `test_team_stale.sh` 의 lambda · `test_roadmap_status.sh` 의 `READERS` · `test_conductor_state_branch_docs.py` 의 지운 한 줄)에서 단언이 지워지거나 느슨해지지 않았는지 `git diff origin/main -- plugins/spec-distill/tests` 로 보라고 적는다.

리뷰 보고는 git 이 추적하지 않는 파일에 적는다 — 지휘자가 준 임시 폴더의 `r3-plan2-ac-report.md`(없으면 상태 루트 `python3 plugins/spec-distill/scripts/state_path.py state-root` 가 내는 폴더 아래 같은 이름). 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올린다 — 올릴 행을 보고에 적고 지휘자가 올린다. PR 을 만들기 전에

`python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.19.2"/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-19-conductor-state-branch-design.md <보고 파일 경로> --acs "AC12 · AC14~AC21"`

을 돌려 경고를 사용자에게 보인다. PR 본문에는 계획 확인의 답(Q1 · Q2)과 사용자 결정 대기 넷의 답 · 그 답으로 한 과제와 건너뛴 과제 · ★ 표시 결정 · 과제 19 의 변이 표와 기준 코드 대조 · 아래 「재지 못함」 · 「고치지 않고 둔 것」 을 적는다.

## 재지 못함

- **GitHub 원격에서의 `--force-with-lease` 지우기.** 임시 레포의 원격은 로컬 bare 다. 브랜치 보호가 있는 레포에서 lease 를 건 지우기가 어떻게 거절되는지는 실제 원격에서 처음 돈다 — 거절되면 3 이고 로컬은 둔다.
- **다른 기계 둘.** 두 기계는 한 기계의 클론 둘로 흉내 냈다. `확인한 끝` 은 기계마다 따로라, 한 로드맵을 두 기계가 번갈아 지휘하면 서로의 커밋을 남의 고침으로 센다(닫히는 쪽 — 확인을 한 번 더 받는다).
- **설치본.** 지휘 세션은 설치된 판의 스크립트를 쓴다. 이 계획의 명령은 플러그인을 갱신한 새 세션부터 돈다.

## 고치지 않고 둔 것

- **`dependencies.md` 의 project-init 행(계획 1 리뷰 잔여).** 행을 더하면 판 칸을 `check_deps.py measure` 가 재야 하는데, 그 스크립트는 공용 `shared/deps/check_deps.py` 의 사본이라 플러그인 모두의 사본과 그 락을 함께 고쳐야 한다(계획 1 J8). README 「Prerequisites」 가 이미 공시한다. 설계문서 `## 미룸` 에 올릴 후보로 보고한다(받는 곳 — 공용 의존 표를 고치는 일 · 지휘자가 정한다).
- **`job_results.py` 의 `rules_at` 대조(M11).** 꼴이 틀린 값은 머리 문제로 거절되고, 없는 커밋은 「묶음 낡음을 재지 못했다」 로 드러난다.
- **다른 로드맵의 남의 고침 수.** `show` 는 내 로드맵의 것만 센다 — 다른 기계의 확인한 끝을 모른다.
