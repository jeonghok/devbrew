# 지휘자 상태 브랜치 · 편지함 — 계획 2(리더가 쓰는 자리 · 작은 수리 다섯) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** team 형식 로드맵에서 리더가 쓰는 것 — 규칙 고침(`RULES.md` 사본)과 대기 줄(`pending.md`) — 이 상태 브랜치에 살고, 시작 묶음 · 「묶음 낡음」 · `flush` 가 그 자리를 읽되 남이 올린 고침은 사용자가 확인하기 전에 쓰지 않으며, R1 이 넘긴 작은 수리 다섯과 계획 1 이 남긴 것을 마친다.

**Architecture:** 쓰는 쪽은 새 스크립트 하나(`leader_seat.py` — 규칙 사본 고침 · 규칙 브랜치 · 남의 고침 확인 · 대기 줄)가 맡고 명령줄은 `conductor_branch.py` 의 하위 명령으로 연다. 읽는 쪽(규칙을 읽을 끝 · 남의 고침 세기)은 상태 계산의 닫힘 안에 있는 `team_status.py` 에 두어 상태 계산 · 시작 묶음 · `sync` · `show` 가 같은 함수를 부른다. 「이 기계가 만든 커밋」 은 상태 브랜치 쓰기의 바닥(`conductor_branch._write_floor` · `_publish`)이 기계 상태의 새 절에 적는다 — 어느 쓰기도 그 기록을 빠뜨릴 수 없고, 남이 만든 커밋은 그 기록에 들어가지 않는다.

**Tech Stack:** Python 3(레포의 `python3` 는 3.9.6 — 3.9 문법만) · git(2.54) · bash(macOS 3.2 호환) · unittest · `shared/tests/assert.sh`.

**Spec:** `docs/superpowers/specs/2026-11-19-conductor-state-branch-design.md` — 이 계획은 그 문서가 나눈 둘 가운데 **계획 2**(§5 · §9 · `## Files to Modify` 의 계획 칸이 2 · 「1 · 2」 · 「PR 마다」 인 행)와 `## 미룸` 표에서 받는 곳이 R3 인 행 다섯 — 지휘자 skill 이 절차 문서를 읽게 하는 줄(과제 18) · AC20 의 team 절반(과제 19) · 같은 (에픽, 종류)를 다시 물을 때(과제 13) · 계획 1 구현 리뷰의 잔여(과제 2 · 13 · 「고치지 않고 둔 것」) · 대기 줄의 사람 줄 종류와 `flush`(과제 9) — 를 받는다. 브랜치 `feature/conductor-leader-seat`. 이 브랜치는 R3 계획 1 브랜치의 끝(`dc112961` — 종류 이름 여덟 · AC3 · AC22 · AC23 · 변경 기록 락)을 합쳤다. 경로는 따로 적지 않으면 `plugins/spec-distill/` 아래다.

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
| AC22 · AC23 | 계획 1(사용자 2026-11-20 에 새로 적었고 계획 1 의 구현 대조가 「구현됨」 으로 셌다) | 없음 — 과제 15 가 있는 테스트에 번호 주석만 단다. 대조 목록에 넣지 않는다 |

대조 스크립트에 주는 목록: `AC12 · AC14~AC21`.

## Global Constraints

- **범위.** 설계문서는 고치지 않는다. 설계의 글자 · 수용 기준 · 사용자에게 보이는 동작을 더하거나 바꾸는 자리는 아래 `## 계획의 판단` 에 ★ 로 표시했고, 구현 중 새로 생기면 멈추고 지휘자에게 돌려보낸다. 「사용자 확인 대기」 로 표시한 판단은 지휘자 권장으로 썼고, 계획 확인에서 다른 답이 오면 그 줄이 적은 과제만 고친다. 설계문서 `## 미룸` 표에 올릴 것은 보고에 적고 지휘자가 올린다.
- **E1 보다 먼저 · R2 계획 2 뒤에.** `start_bundle.py` · `team_write.py` · `conductor_ledger.py` · `team-files.md` 는 E1 도 예약했다(이 계획이 먼저 머지된다). R2 계획 2(`origin/feature/conductor-walk-table` · 계획 파일 `2026-11-20-conductor-walk-gates-plan2.md`)가 먼저 머지될 예정이고 같은 파일을 여럿 고친다(`## 머지 전 다시 셀 것`). 편집의 닻은 양쪽에 다 있는 글(함수 이름 · 절 제목 · 지금 있는 문장)에 둔다.
- **상태 계산의 닫힘.** `tests/test_roadmap_status.sh` 의 정적 검사 목록(열여섯)과 `control_plane.CODE_STAMP_FILES` 에 **새 모듈을 넣지 않는다**. 읽기 함수는 이미 닫힘 안인 `team_status.py` · `team_layout.py` 에 둔다 — 거기 더하는 코드는 그 검사가 받는 호출만 쓴다(git 은 `roadmap_status.Git` 의 `log` · `cat-file` · `rev-parse` · `diff` — `rev-list` · `diff-tree` 는 받지 않는다, `open` · `getattr` 금지, 쓰기 금지). `team_layout.py` 는 표준 라이브러리만 가져온다. `leader_seat.py` 는 닫힘 밖이고 상태 계산 · 현황 화면이 그것을 가져오지 않는다(과제 19 가 닫힘 락의 새 모듈 목록에 `leader_seat.py` 를 더한다). 닫힘의 이름 허용 목록(`READERS` 의 `conductor_state` 줄)에 새 이름 `TRUST` 하나만 더한다(과제 3 — 허용을 넓히는 고침이라 리뷰어가 본다).
- **`conductor_state.py` 의 읽기 함수.** `parse_machine` · `_check_row` 에 더하는 코드는 `in` · `==` · 미리 컴파일한 정규식의 `.fullmatch(` 만 쓴다.
- **명령줄 진입(B2).** `conductor_branch.py` 를 스크립트로 돌리면 모듈 이름이 `__main__` 이라, 함수 안에서 가져온 `leader_seat` 가 `conductor_branch` 를 둘째 모듈 객체로 다시 읽고 그쪽의 `BranchError` 는 `main` 의 `except BranchError` 에 걸리지 않는다(종료 코드가 늘 3 · 보고가 첫 줄에서 잘린다 — 계획을 고치며 임시 폴더의 두 파일로 재현했다). 파일 끝을 세 줄 `if __name__ == "__main__":` · `    import conductor_branch as _self` · `    sys.exit(_self.main())` 로 바꿔 `main` 이 늘 가져온 모듈 객체에서 돌게 한다. 새 하위 명령은 **명령줄로 부르는 테스트**(종료 코드 · 마지막 줄)를 함께 둔다.
- **「씀」 의 뜻(B3).** 기계 상태 `확인한 끝` 절의 `씀` 줄과 `Result.made` 는 **이 부름 안에서 `_build_commit` 이 `None` 아닌 값으로 만든 커밋만** 담는다(뿌리 · 이번 쓰기 · 새 커밋을 낸 다시 얹기 · 다시 만든 쓰기). 받아 온 원격 끝 · 다시 얹기가 바뀐 것 없이 돌려준 `onto` · `made` 없이 ref 를 옮긴 끝은 담지 않는다.
- **닫는 판정은 정확히.** 커밋 대조 · 경로 대조 · 줄 대조 · 브랜치 이름은 `==` · `in <닫힌 목록>` · `re.fullmatch` 로만 본다. 확인 표시는 40자 전체만 받는다(I4 — 앞 8자는 받지 않는다). 남이 쓴 글(상태 브랜치의 규칙 사본 · `pending.md` · `rules-base.md` · 커밋)을 화면에 낼 때는 `conductor_branch.visible` 을 거친다. 남의 글 때문에 명령이 예외로 죽지 않는다 — 읽지 못하면 「재지 못했다」 로 닫는 쪽(규칙은 기본 브랜치 · 대기 줄은 옮기지 않음)으로 간다.
- **「재지 못함」 은 한 뜻이다(I11).** 기계 상태를 읽지 못함 · 확인 끝 커밋이 이 레포에 없음 · git 실패 · 남의 머지 커밋 — 넷 모두 남의 고침 판정이 `None` 이고, 읽는 쪽(`rules_tip` · 시작 묶음 · `sync` · `show` · `flush` · `rules-add`)은 모두 「남의 고침을 재지 못했다」 로 닫는다. 빠져나가는 길은 `confirm`(받아들임 — 아래 M6) · `rules-reset`(규칙만 — M36) · `delete`(절을 비운다 — M35)다.
- **종료 코드.** 새 하위 명령(`rules-add` · `rules-drop` · `rules-reset` · `rules-branch` · `confirm`)은 계획 1 의 규칙 그대로다 — 0(썼다 · 쓸 수 없어 알리고 넘어감) · 1(없음/아님 · 확인 없이 부른 `confirm` · 갈라져서 만들지 않은 `rules-branch`) · 2(사용법 · 받지 않는 값) · 3(읽기 불가 · git 실패) · 5(표지 아님). 예상 밖 예외도 3. `conductor_ledger.py` 가 `leader_seat` 를 부를 때 그 `BranchError` 는 같은 종료 코드의 `Fail` 로 바꾼다(I7).
- **고정 글자.** 「확인되지 않은 남의 고침 %d」 · 「남의 고침을 재지 못했다」 · 「규칙 사본이 기본 브랜치와 갈라졌다」 · 「올릴 규칙 고침이 없다」 · 「확인할 끝: %s」 · 「상태 브랜치가 없어 기계 상태에 쌓았다 — ensure 뒤의 줄부터 상태 브랜치에 쌓는다」 · 「사람 줄이라 옮기지 않은 대기 줄 %d — record --human 으로 적고 drop 으로 지운다」 · 「확인되지 않은 남의 고침이 더한 대기 줄 %d — 옮기지 않았다」 · 「과제 폴더 없음」 · 「묶음 낡음을 재지 못했다」(있는 상수). 스크립트의 상수로 한 번만 두고 테스트는 **글자**를 견준다.
- **종류 이름.** 「지금 묻는 질문」 의 종류는 계획 1 PR 에서 바뀐 여덟이다 — `설계 대화` · `spec 승인` · `계획 검토` · `흐름 승인` · `걸음 건너뜀` · `옮긴 질문` · `머지` · `그 밖`(별칭 없음). 이 계획의 테스트 · 문서는 이 이름만 쓴다.
- **레포 락.** `"python3"` 따옴표 리터럴 금지 · `open(` · `.read_text(` 에 `encoding` · `re.compile` 리터럴이 `## ` 로 시작하는 글과 3글자 이상 맞으면 RED · `team_layout.py` 밖 스크립트가 `RULES.md` · `jobs/` · `results/` 를 글자로 쓰면 RED(`Team.rules` 를 쓴다) · 같은 20줄(200자 이상) 블록이 두 파일에 있으면 RED · 새 셸 테스트는 100755(`git ls-files -s` 로 확인) · CHANGELOG 새 머리는 바로 다음 판만 · 레포 전용 글자(기본 브랜치 이름 · `feature/` · `fix/` 접두 · `docs/superpowers` · 모델 이름)를 락 대상 파일에 쓰지 않는다(과제 18 이 `leader_seat.py` 를 대상에 더한다) · `references/*.md` 는 `${CLAUDE_PLUGIN_ROOT}/references/<파일>` 꼴의 가리킴이 있어야 한다 · 문서에 `AskUserQuestion` 을 쓰지 않는다(질문은 문장으로).
- **bash 3.2.** `set -u` 아래 빈 배열은 `${arr[@]+"${arr[@]}"}` · `$var` 바로 뒤 한글은 `${var}`. 테스트 셸에서 `${A}:path` 처럼 변수 뒤에 `:` 를 붙일 때는 중괄호로 감싼다(zsh 의 `:r` 수식어가 글을 깎는 것을 계획을 쓰며 겪었다 — 셸 테스트는 bash 로 돈다).
- **계획이 쓴 테스트 코드.** 아래 테스트 코드는 계획이 정한 것이다 — 구현자는 그대로 옮기되, mock 으로 거절을 흉내 내지 않고(실제 임시 레포의 실제 거절) 단언이 공허하지 않은지(빈 목록 위의 `all` · 늘 참인 비교) 옮기면서 본다. 락마다 「붉어지는 변이」 를 적었고, 통과가 정답인 락은 과제 19 의 변이 표가 이빨을 잰다.
- **테스트의 git.** 임시 레포만 쓴다(`tempfile.mkdtemp` · `tests/fixtures/team_repo.sh` 의 `$T`). **이 레포에 `conductor/` 브랜치를 만들지 않는다.** 이 레포의 원격 · 상태 폴더를 건드리는 테스트를 쓰지 않는다.
- **판.** spec-distill **minor**. 번호는 머지 직전 `origin/main` 위의 다음 minor(지금 예상 8.28.0 — R3 계획 1 이 8.26.0 · R2 계획 2 가 8.27.0). **판 번호 리터럴을 테스트에 쓰지 않는다** — CHANGELOG 절은 `.claude-plugin/plugin.json` 의 판으로 고른다(`"\n## [%s]" % version`).
- **커밋.** 한국어 Conventional Commits(type · scope 는 영어) · pathspec 커밋 · `git stash` · HEAD 뒤로 옮기기 · push · 다른 worktree 의 git 금지.
- **전체 스위트**는 이 줄로만 돈다(지휘자 대조와 같은 공유 잠금 — 못 잡으면 주인 · 잡은 시각을 보고한다. `--owner` 는 도는 agent 의 이름). 과제 안에서는 그 과제가 이름 댄 테스트만 돈다. 구현 담당이 하위 agent 를 띄우면 그 글에도 이 줄과 경로를 그대로 싣는다:
  `python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.19.2"/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-conductor-context-economy-brief/files/suite-lock --owner r3-impl-2 --wait 10800 -- bash -c 'bash tools/suite/run-all.sh'`

## Review Focus

설계가 뜻하지만 어느 수용 기준도 이름 대지 않는 입력이다. 줄마다 그 코드를 가진 과제에 테스트가 있다.

1. **남의 끝 위로 옮겨 간 쓰기** — 올리기가 거절돼 원격 끝(남이 `RULES.md` 사본을 고친 커밋) 위에 다시 만들 때, 다시 만든 고침이 「바뀐 것 없음」 이어서 ref 가 그 남의 끝으로 옮겨 가도, 또 내 커밋을 그 위에 새로 만들어도, 남의 고침은 「씀」 이 되지 않고 다음 쓰기 한 번에 「확인됨」 으로 넘어가지 않는다(과제 2 · 8 — B3 · 설계 Deferred df3f1a6d).
2. **사본이 있는데 기본 브랜치의 규칙이 그 사이 다른 PR 로 바뀜** — 시작 묶음은 사본을 싣고, `sync` 는 「규칙 사본이 기본 브랜치와 갈라졌다」 를 알리며 `rules-branch` 는 만들지 않는다(과제 7).
3. **`rules_at` 커밋이 이 클론에 없음** — 다른 클론에서 쓴 결과 파일의 `rules_at` 이 아직 받아 오지 않은 상태 브랜치 커밋이면 「묶음 낡음을 재지 못했다」 로 알리고 지어내지 않는다(과제 4).
4. **`pending.md` 에 같은 줄이 둘** — 일부러 두 번 쌓은 같은 결정 줄은 `flush` 가 하나씩 옮기고 하나씩 뺀다(다중집합 — 계획 1 J52 와 같은 규칙, 과제 9).
5. **남의 머지 커밋** — 남이 상태 브랜치에 부모 둘인 커밋을 올려 규칙 사본을 예전 글로 되돌리면, 경로를 한정한 `git log` 의 기본 이력 단순화는 그 머지를 숨긴다(계획을 고치며 임시 레포로 재현했다). 남의 고침 판정은 「재지 못했다」 로 닫는다(과제 3 — I2).

---

## 계획의 판단

설계가 계획에 넘긴 것과 설계가 정하지 않아 이 계획이 정한 것이다. **★ 는 설계에 없던 결정**(설계의 글자 · 보이는 동작에 닿는다), **⏸ 는 사용자 확인 대기**(지휘자 권장으로 썼다 — 고를 길 전부는 아래 「사용자 확인 대기」 표).

| # | 자리 | 정한 것 | 이유 | 다른 길 |
|---|---|---|---|---|
| M1 ★ | `leader_ref` 의 자리 | `team_layout.leader_ref(default_ref, state_tip=None) -> str` 은 고르기만 한다(`state_tip` 이 있으면 그것, 없으면 `default_ref`). 끝을 계산하는 것은 `team_status.rules_tip(...)` 이고 상태 계산 · 시작 묶음이 그것을 불러 넘긴다 | 설계는 `team_layout.leader_ref()` 가 상태 브랜치를 보고 고른다고 적었다. 그 모듈은 표준 라이브러리만 가져오고 상태 계산의 정적 검사 대상이라 상태 브랜치 · 기계 상태를 읽는 코드를 둘 수 없다. 이름과 「여기서 고른다」 는 그대로 두고 계산을 닫힘 안의 읽기 모듈로 옮긴다 | `team_layout` 안에서 늦게 가져온다(정적 검사가 잠긴 파일 밖 로컬 import 로 잡는다) |
| M2 | 접두 글자 | `conductor/` 를 `team_layout.STATE_BRANCH_PREFIX` 한 곳으로 옮기고 `conductor_branch.STATE_BRANCH_PREFIX` 는 그 이름을 다시 내보낸다. `conductor_status.FETCH_HINT` 도 그 상수로 짓는다(계획 1 리뷰 잔여) | 닫힘 안의 `team_status` 가 상태 브랜치 이름을 알아야 한다 | `team_status` 에 글자를 하나 더 둔다 |
| M3 | 「이 기계가 쓴 끝」 의 기록(설계 「적는 자리」) | 기계 상태의 새 절 `확인한 끝`(칸 `끝 · 까닭 · 때 · 세션`, 까닭은 `확인` · `씀`). 상태 브랜치 쓰기의 바닥이 Global Constraints 「씀」 의 뜻대로 이 부름이 만든 커밋마다 `씀` 줄을 하나 더한다 — 예외로 끝나도 그때까지 만든 것은 적는다(`try/finally`). `확인` 줄은 많아야 하나이고 「여기까지는 사용자가 확인했거나 남의 고침이 없었다」 는 기준 끝이다 | 커밋을 누가 만들었는지는 원격에서 가를 수 없다(지은이 · 커밋 글은 누구나 흉내 낸다). 쓰기의 바닥에서 「만든 것」 만 적으면 어느 쓰기도 빠뜨리지 않고, 남의 끝을 받아 와 ref 를 옮겨도 그 끝은 내 것이 되지 않는다(B3) | ref 를 옮긴 끝을 모두 적는다(B3 의 구멍) · 커밋 글의 세션 칸으로 가른다 |
| M4 | 남의 고침을 세는 법(I2 · S11) | 두 걸음이다. ① `git log --format=%H %P <확인 끝>..<읽을 끝>`(경로 한정 없음)으로 범위의 커밋을 모두 보고, `씀` 에 없는 커밋 가운데 부모가 둘 이상인 것이 있으면 `None`(재지 못함). ② 그 밖이면 `git log --no-renames --format=%H --name-only <범위> -- <경로…>` 로 경로를 바꾼 커밋을 고르고 `씀` 에 없는 것을 남의 고침으로 낸다 — 출력은 「해시 줄, 빈 줄, 경로 줄들」 차례라 40자 해시와 `fullmatch` 되는 줄이 새 묶음을 연다. `확인` 줄이 없으면 `<읽을 끝>` 의 이력 전부. 확인 끝 커밋이 이 레포에 없거나 git 이 실패하면 `None`. 경로는 규칙 쪽이 `[규칙 사본, rules-base.md]`, 대기 줄 쪽이 `[pending.md]` | 설계 §5 「원격에서 받아 온 커밋 가운데 이 기계의 지휘 세션이 만들지 않은 것이 규칙 사본이나 `pending.md` 를 바꿨으면」. 경로 한정 `log` 는 그 경로에서 한 부모와 같은 머지를 그 부모 쪽으로만 따라가 숨긴다(재현함) — 머지는 스크립트가 만들지 않으므로 남의 머지는 닫는다. `rules-base.md` 를 규칙 쪽에 넣어야 남이 갈라짐 판정을 뒤집지 못한다(S6) | `--full-history` 로 머지까지 경로를 따진다(머지의 차이를 부모마다 따져야 한다 — 닫는 쪽이 단순하다) |
| M5 | 기준 끝을 앞으로 옮기는 때 | `sync` 가 쓴 뒤 읽을 끝에서 두 쪽(규칙 · 대기 줄) 모두 남의 고침이 0 이면 `확인한 끝` 절을 `확인 · <그 끝>` 한 줄로 줄인다. 남의 고침이 있으면 `씀` 줄 가운데 범위(`<확인 끝>..<읽을 끝>`)에 없는 것(다시 만들기로 버려진 커밋)만 지운다. `씀` 줄이 500 을 넘으면 `sync` 가 「확인되지 않은 남의 고침이 오래 남아 있다 — confirm 하거나 지운다」 를 낸다(S13 — 기계 상태 크기 한도 1 MiB 앞에서 알린다) | 절이 끝없이 자라지 않는다 | 쓸 때마다 줄인다 |
| M6 ★ | 확인을 기록하는 명령(Deferred 82ffe046) | `conductor_branch.py confirm --roadmap R --session S [--confirmed <끝 40자>]` — 표지를 쥔 세션만. `--confirmed` 가 없으면 남의 고침 커밋마다 `<8자> · <때> · <바꾼 파일>` 과 그 커밋의 차이(첫째 부모와 · 머지면 첫째 부모와의 차이에 「머지 커밋」 표시 · 줄마다 `│ ` · `visible`)를 내고 마지막 줄 `확인할 끝: <40자>` 와 함께 1. 판정이 `None` 이면 확인 끝 없이(이력 전부) 다시 세어 보고하고, 그래도 `None`(남의 머지)이면 범위의 남의 커밋 전부를 같은 꼴로 보인다. 기계 상태를 읽지 못하면 3. `--confirmed` 는 40자 전체만 받고(아니면 2) 지금 읽을 끝과 같을 때만 `확인한 끝` 을 `확인 · <그 끝>` 한 줄로 두고 0, 다르면 다시 보고하고 1 | `delete` 의 「수를 센 끝」 과 같은 꼴이라 지휘자가 한 가지 걸음으로 다룬다. 앞 8자는 같은 앞머리의 커밋을 만들어 올리면 확인하지 않은 끝이 확인된다(I4) | 표시 없이 지금 끝을 확인한다 |
| M7 ★ | 규칙 고침 명령 | `conductor_branch.py rules-add --line "<규칙 줄>"` · `rules-drop --line "<규칙 줄>"` · `rules-reset`. 줄은 `team_rules.parse_rules` 로 한 줄짜리 규칙 꼴인지 보고(문제가 있으면 그 사유와 2) 이미 있는 줄을 또 더하거나 없는 줄을 빼면 2. 사본이 없으면 기본 브랜치의 글로 만든 뒤 고치고, 출발한 기본 브랜치 커밋을 `<로드맵 폴더>/rules-base.md`(한 줄 `기본 브랜치 커밋: <40자>`)에 함께 쓴다. `rules-add` · `rules-drop` 은 규칙 쪽 남의 고침이 있거나 재지 못하면 고치지 않고 1(먼저 `confirm` 또는 `rules-reset`). team 형식이 아니면 2 | 설계 §5 「`conductor_branch.py` 의 쓰기 · 출발한 기본 브랜치 커밋을 함께 적어 둔다 · 적는 자리는 계획이 정한다」. 줄 단위 고침이라 거절 뒤 다시 만들기(줄 파일 규칙)가 그대로 맞는다 | 사본 맨 위의 주석 줄 · 커밋 글에 적는다 · 파일 통째로 바꾸는 명령 |
| M8 | 같아짐 · 갈라짐 | 기본 브랜치의 지금 글 == 사본 → `sync` 가 사본과 `rules-base.md` 를 지운다 — 단 규칙 쪽 남의 고침이 0 일 때만(S6). 지울 사본이 있으면 STATUS 가 같아도 「바뀐 것」 으로 센다(S5 — `sync` 의 「달라진 것이 없다」 조기 반환을 타지 않는다). 지금 글 ≠ `rules-base.md` 가 적은 커밋의 글이고 지금 글 ≠ 사본 → 갈라짐(「규칙 사본이 기본 브랜치와 갈라졌다」). `rules-base.md` 가 없거나 읽지 못하면 갈라짐으로 본다(닫는 쪽) | 설계 §5 · AC17 | — |
| M9 | `rules-branch` | `--branch <이름>` 필수. 이름은 `conductor/` 로 시작하지 않고(`team_layout.STATE_BRANCH_PREFIX`), 레포 규칙 문서가 있으면 그 정규식이 받아야 한다(아니면 2). 기본 브랜치 끝 위에 규칙 파일만 사본 글로 바꾼 커밋 하나를 만들어 `update-ref refs/heads/<이름> <커밋> 0…0` 로 둔다(이미 있으면 3). **올리지 않는다** — PR 을 여는 것은 지금 절차대로 지휘자가 한다. 사본이 없거나 기본 브랜치와 같으면 「올릴 규칙 고침이 없다」 1 · 갈라졌으면 둘의 차이를 내고 1 · 규칙 쪽 남의 고침이 있거나 재지 못하면 1 | 설계 §5 · AC17 「기본 브랜치에서 딴 브랜치에 그 파일만 바꾼 커밋 하나」. 브랜치 접두는 레포마다 다르다 | 이름을 스크립트가 짓는다 · 올리기까지 한다 |
| M10 ★ ⏸ | `rules_at` 을 싣는 때(H1 · I3) | 시작 묶음은 **규칙을 상태 브랜치에서 읽었을 때만**(`base.rules_commit != base.commit`) 「맞추는 명령」 줄 끝에 `--rules-at <규칙을 읽은 커밋>` 을 싣는다. 꺼진 설정 · 사본 없음 · 확인되지 않은 남의 고침이면 싣지 않아 줄이 지금과 바이트까지 같다. `job sync` 의 `--rules-at` 은 `--bundle-at` · `--job-at` 과 함께만 받는다(아니면 2). 새 머리에는 `bundle_at` 바로 뒤에 `rules_at` 줄. 「끝」 줄이 없는 결과 파일에 셋을 함께 주면 `rules_at` 줄을 고치거나(없으면 `bundle_at` 줄 뒤에) 넣는다 | AC15 「상태 브랜치가 켜져 있고 거기에 사본이 있으면 … 「맞추는 명령」 줄에 `rules_at` 을 싣는다」 · AC20 「꺼진 team 형식에서 R1 의 동작이 바뀌지 않는다」. `rules_at` 이 없는 결과 파일은 `bundle_at` 으로 견주는데, 사본이 없을 때는 둘이 같은 기본 브랜치 커밋이라 읽는 쪽 규칙이 하나로 남는다. `sync_line` 의 인자가 넷인 부름이 그대로 서므로 기존 테스트 넷(B1)의 기대 줄도 바뀌지 않는다 | 켜져 있으면 늘 싣는다 · 늘 싣는다(AC20 에 예외를 더해야 한다) |
| M11 | `rules_at` 을 읽는 곳 | `team_files.parse_result` 가 `rules_at` 을 고를 수 있는 키로 읽는다 — 있으면 커밋 꼴이어야 하고(아니면 problem) `Result.rules_at`. 결과 대조(`job_results.py check`)는 고치지 않는다 — 꼴이 틀린 `rules_at` 은 머리 문제로 이미 거절된다. 커밋이 이 레포에 있는지는 대조하지 않는다(상태 브랜치 커밋은 받아 오기 전에는 없다) | `job_results.py` 는 R2 계획 2 가 고치는 파일이다 | 결과 대조에 「`rules_at` 커밋이 없다」 를 더한다 |
| M12 | 「묶음 낡음」 의 규칙 대조 | 규칙 파일은 `rules_at`(없으면 `bundle_at`) 커밋의 글과 지금 규칙을 읽을 끝(`leader_ref(main, rules_tip)`)의 글을 견준다. `rules_at` 커밋이 이 레포에 없으면 「묶음 낡음을 재지 못했다: <이름> — 규칙을 읽은 커밋 <8자> 가 이 레포에 없다」 | AC15 · 설계 §5 | — |
| M13 | 「묶음 낡음」 의 빈 곳(§9) | implement 가 아닌 단계(검수는 지금처럼 뺀다)의 가장 새 시도 결과 파일이 끝 줄 없이 읽히지 않으면(글을 못 읽음 · 머리 문제 · 빠뜨린 기계 줄) 「묶음 낡음을 재지 못했다: <이름> — <첫 사유>」. implement 단계는 받음 쪽 알림이 내므로 지금처럼 건너뛴다 | 설계 §9 「결과 받음 쪽 알림과 같은 파일을 두 번 알리지 않는다」 | 모든 단계 |
| M14 ★ | 대기 줄의 자리 | 「상태 브랜치 자리」 = 로드맵 머리말이 `layout: team` 이고 `conductor_branch.availability` 가 `None` 이고 상태 브랜치 로컬 끝이 있을 때. 그때 `add --section "쌓인 기록"` 은 `pending.md` 에 `- <에픽> · <절> · <글>` 한 줄을 더한다. 상태 브랜치가 아직 없으면 기계 상태에 쌓고 알린다. 상태 브랜치 자리에서 `pending` · `flush` · `drop --section "쌓인 기록"` 은 **두 자리를 함께** 다룬다(기계 상태 줄 먼저, 그 뒤 `pending.md`) | 설계 §5 는 상태 브랜치가 없을 때를 정하지 않았다. 기계 상태에 이미 쌓인 줄을 버리지 않으려면 두 자리를 함께 읽어야 한다 | 브랜치가 없으면 쓰지 않고 1 |
| M15 ★ | 대기 줄의 사람 줄 종류(설계 `## 미룸` 의 R3 행 「대기 줄에 사람 줄 종류가 하나라도 있으면 `flush` 가 …」) | 상태 브랜치 자리에서 `add` 는 `human_lines.is_human` 인 줄을 human_gate 가 켜졌을 때 받지 않는다(지금 `flush` 의 글 `HUMAN_BY_ARGS` 와 2). `flush` 는 사람 줄을 건너뛰어 그 자리(기계 상태 · `pending.md`)에 남기고 「사람 줄이라 옮기지 않은 대기 줄 n — …」 를 알린 뒤 나머지를 옮긴다(멈추지 않는다). 남은 사람 줄은 `drop --section "쌓인 기록" --where 글=<글>` 로 지운다(S8). 기계 상태 자리(옛 형식 · 꺼짐 · 브랜치 없음)는 지금 동작 그대로 — AC20 | 그 미룸 행의 「건너뛰고 세거나 넣을 때 거른다」 둘 다. 원격에 올라간 `pending.md` 에는 남이 사람 줄을 넣을 수 있다 — 한 줄 때문에 다른 줄이 옮겨지지 않으면 결정이 쌓인다 | 넣을 때만 거른다 · 지금처럼 멈춘다 |
| M16 | `flush` 와 남의 고침 · 옮긴 줄 빼기(I6) | 옮길 줄 = 그 에픽 · 「지휘 기록」 절의 줄 가운데 — 기계 상태 줄 전부와, `pending.md` 줄(다중집합) − 남의 고침 커밋들이 더한 줄(다중집합). 대기 줄 쪽 판정이 `None` 이면 `pending.md` 줄은 하나도 옮기지 않는다. 사람 줄은 뺀다(M15). 차례 — INTENT.md 에 먼저 쓰고(`_append_decisions`) 그 뒤 **옮긴 줄만** 기계 상태에서(다중집합 빼기) · 상태 브랜치에서(다중집합 빼기) 뺀다. 건너뛴 줄(사람 줄 · 남의 줄)은 두 자리 모두에 그대로 남는다. 둘째 걸음이 실패해도 다음 `flush` 는 같은 줄을 INTENT.md 에 다시 쓰지 않는다 | AC21 「`flush` 가 그 커밋이 더한 줄을 옮기지 않으며」. 설계 「확인한 끝까지의 줄」 과는 남이 지운 줄에서 조금 어긋난다 — 남이 지운 내 줄은 확인 전에 옮겨지지 않고 「확인되지 않은 남의 고침 n」 으로 드러난다 | 확인 끝의 글에 내 고침만 다시 얹어 옮길 줄을 계산한다 |
| M17 ⏸ | 판정 줄 규칙 하나(§9 — Q1) | `workflow_superpowers.RULING_MARK = "Ruling:"` 와 `ruling_said(line) -> Optional[str]`(판정 줄이면 `Ruling:` 뒤 글, 아니면 `None`). 원장을 읽는 둘(`conductor_state.ledger_rulings` · `workflow_superpowers.ledger_lines`)이 그 함수로 줄을 고른다 — `ledger_rulings` 의 출력(줄 전체)은 그대로. 결과 파일의 기계 줄 문법(줄 머리 — `team_files._is_machine` 과 `parse_result` 의 `startswith`)은 형식 정본의 계약이라 판정을 바꾸지 않고 상수만 같은 것을 쓴다. `team_write.py` 의 `"Ruling:"` 글자도 상수로. 함수의 규칙은 Q1 의 답이다 — **(가) 줄 어디든** 으로 썼다 | 아래 「판정 줄 실측」 | (나) 줄 머리 |
| M18 ⏸ | 「예약 밖 변경」 줄임(§9 — Q2) | 파일이 여섯 이상이면 이름 순 앞 다섯과 「 외 n개」(`예약 밖 변경: a · b · c · d · e 외 3개`). 다섯 이하면 지금 그대로 | 설계 §9 「몇 줄인지는 계획이 제안하고 계획 확인에서 정한다」 | 셋 · 열 |
| M19 | 판정이 없을 때의 문구(§9) | 보고의 `layout` 이 `team` 이면 네 자리(`control_plane.py` 의 `show_text` 둘 · `epic_view` 둘)의 「설계문서 `## 판정`」 을 「결과 파일의 `Ruling:` 줄」 로 바꾼다. 옛 형식은 그대로 | 설계 §9 · R1 계획 2 잔여 7 | — |
| M20 | `BUCKETS` · `TASK_STATUS` 락(§9) | `set(BUCKETS 의 단계 전부) ∪ set(control_plane.UNCOUNTED) == set(roadmap_status.TASK_STATUS) ∪ {"알 수 없음"}` 와 `BUCKETS 의 단계 ∩ UNCOUNTED == ∅` 를 단언한다(지금 참 — 이빨은 과제 19 의 변이 표) | 설계 §9 | — |
| M21 | 글 출력의 로드맵 밖 과제(§9) | `roadmap_status.render` 가 보고에 `jobs` 칸이 있을 때만(team 형식) 경로 예약 겹침 줄 앞에 `로드맵 밖 과제: <n>개` 와 과제마다 `    <id> <title> — <단계> · <사유>` · 그 알림 `        정보: …` · `job_notes` 의 `    정보: …` 를 낸다. 옛 형식의 글 출력은 바이트까지 그대로 | 설계 §9 · AC20 | — |
| M22 ★ ⏸ | 과제 폴더 없는 작업(§9) | **(라) 새 약속 · 새 칸 없이 보고로 찾는다.** 상태 계산이 team 블록마다 `job_folder`(기본 브랜치에 그 과제의 `INTENT.md` 가 있으면 `true`, 없다고 확인되면 `false`, 확인하지 못하면 `null` — 지금 쓰는 `src.absent` 읽기로)를 싣는다. `control_plane.works_lines` 가 team 보고일 때, 끝나지 않은 작업 줄마다 — 에픽 칸이 보고의 블록 번호(결정 블록 빼고)면 그 블록의 `job_folder` 로 가르고(`null` 이면 알리지 않는다), 보고에 없는 에픽 번호면 없다고 보고, 「로드맵 밖」 이면 보고 `jobs` 의 과제 이름이 이름 칸의 낱말(공백으로 가른 것)과 글자 그대로 같거나 근거 칸의 경로가 그 과제 폴더 아래이면 있다고 본다. 어느 것도 아니면 줄 끝에 ` · 과제 폴더 없음` | 검수 지적 — 이름 칸 약속(가)은 지휘 절차에 새 약속을 만들고 그 약속 전에 쓴 옛 줄에 거짓 알림을 낸다. 근거 칸만으로(나)도 같은 문제가 있고, 과제 칸(다)은 기계 상태 꼴을 바꾼다. (라)는 이름이나 근거 어느 한쪽에 과제가 드러나면 받아들여 옛 줄의 거짓 알림을 줄이고, 블록 줄은 폴더가 정말 있는지 보아 「블록이 보고에 있으면 폴더가 있다」 는 근사(S10)를 걷는다 | (가) 이름 칸 = 과제 이름 약속 · (나) 근거 칸 경로 · (다) 작업 절에 과제 칸 |
| M23 | 단순 작업의 PR 캐시(§9) | `pr-refresh` 가 `--epic` 없이 불리면 보고 `jobs` 가운데 단계가 머지됨이 아닌 과제(`--reset` 이면 전부)의 `branch` 도 채운다. 그 줄의 에픽 자리는 과제 이름 | 설계 §9 · R1 B25 | — |
| M24 ★ | 같은 (에픽, 종류)를 다시 물을 때(미룸 R3 · S9) | `waiting add` 가 같은 (에픽, 종류) 줄을 찾으면 — 그 줄이 「질문 창」 이고 세션이 이 세션이면 앞 질문은 답을 받은 것이라 새 줄로 바꾼다(언제부터 지금 · 건 길 새 값). 그 밖(「턴 끝」 이거나 다른 세션의 줄)은 아직 기다리는 질문이라 언제부터를 두고 건 길 · 세션만 새 값으로 바꾼다 — 「턴 끝」 줄을 질문 창으로 다시 물으면 다음 `sync` 가 내린다 | 설계 §2 「그 세션이 다시 돌고 있다는 것이 답을 받았다는 뜻」. 계획 1 원장 P2(「턴 끝」 · 다른 세션 줄 위에 질문 창으로 다시 물으면 `sync` 가 내리지 않는다)를 함께 고친다 | 늘 지금으로 바꾼다 |
| M25 | 드문 경우(계획 1 리뷰 잔여) | ② 설정 오류면 쓰는 명령(`ensure` · `sync` · `waiting` · `send` · `ack` · 새 하위 명령)이 3 이 아니라 0 으로 끝나고 「레포 설정을 읽지 못해 …」 를 낸다 — `team_of` 보다 `availability` 를 먼저 본다 ③ `send` · `ack` 는 표지(5) → `availability` → 값 차례로 본다 ④ ★ ⏸ 원격 브랜치를 지우는 push 를 `--force-with-lease=refs/heads/conductor/<이름>:<센 끝>` 으로 건다(원격이 그 끝이 아니면 지우지 않고 3). 다시 얹을 커밋 가운데 부모가 둘 이상인 것이 있으면 다시 얹지 않고 3. 이름 꼴이 틀린 `conductor/` 브랜치는 `show` 에 「이름 꼴이 틀린 상태 브랜치 n」 으로 센다. **① 끝난 로드맵에서 `ensure` 가 지운 브랜치를 다시 만드는 것은 고치지 않는다 ⏸** — 「끝나지 않은 로드맵」 술어를 하나로 모으는 일은 E2 가 받았고 넷째 사본을 만들지 않는다(「고치지 않고 둔 것」) | 설계 `## 구현 대조` 의 「리뷰 잔여」. ④ 의 lease 는 지우기를 좁히기만 하지만 설계 §1 · 브랜치 규칙 문서의 「force-push 하지 않는다」 글자와 겉으로 부딪히고 계획 1 원장이 「가드는 `--force-with-lease` 를 막는다」 고 적은 결정을 바꾼다 — 사용자에게 보인다 | ④ 를 공시만 한다 · ① 을 블록만 세는 술어로 고친다 |
| M26 | 가리기의 경로 꼴(계획 1 리뷰 잔여 · S4) | 절대경로로 보는 낱말 = 줄 머리 · 공백 · 여는 괄호 · `「` · 따옴표 · 백틱 · `:` · `=` 바로 뒤에서 `/` 또는 `~/` 로 시작하고, `/` 로 이은 성분(`/` · 공백이 아닌 글자 하나 이상 — 비ASCII 도 받는다)이 `/` 시작이면 둘 이상 · `~/` 시작이면 하나 이상인 것. 이 기계의 뿌리 · 홈 · 상태 루트는 지금처럼 글자로도 가린다. `scrub` · `redact` · 편지 `about` 판정이 같은 함수(`conductor_branch.looks_absolute`)를 쓴다 | 「리더/담당자/일꾼」 · 「설계/계획/구현」 · `./a/b` 는 `/` 앞이 경계가 아니라 지나가고, 좁히면서 새던 비ASCII 성분 · `~/` · `key=/a/b` 는 그대로 잡는다 | 그대로 둔다 |
| M27 | `DONE_STAGES` 락(계획 1 리뷰 잔여) | `conductor_branch.DONE_STAGES == roadmap_status.DONE` 를 단언한다(이빨은 변이 표) | 글자로 복제한 목록이 갈라지면 끝난 로드맵을 끝나지 않은 것으로 센다 | 가져다 쓴다(상태 계산을 가져오게 된다) |
| M28 | AC20 의 team 절반을 재는 법 | 커밋되는 테스트는 같은 코드 안에서 「끔」 과 「켬 · 브랜치 없음」 의 출력이 R1 의 고정 출력 테스트대로인지 본다. 기준 코드와의 차이는 과제 19 가 한 번 돌리는 대조로 재고 결과를 보고에 싣는다 | 레포의 git 상태에 기대는 테스트는 머지 뒤 공허해진다 | 커밋되는 테스트에 기준 코드 대조를 넣는다 |
| M29 | 현황 캐시의 열쇠(I1) | `control_plane.pr_cache_prints` 가 대상마다 PR 캐시 지문 뒤에 `확인한 끝` 절의 지문(줄을 차례대로 이은 글의 sha256 앞 16자)을 붙인다. `cache_key` 의 문서 문자열 「PR 밖 기계 상태는 키에 없다」 를 「PR 캐시와 확인한 끝 밖의 기계 상태는 키에 없다」 로 | 과제 3 뒤로 상태 계산의 「묶음 낡음」 이 `확인한 끝` 에 기댄다. `confirm` 은 기계 상태만 바꾸고 ref 는 그대로라 옛 결과가 나온다 | 캐시를 team 로드맵에서 끈다 |
| M30 | `team_status` 의 칸 글자(I12) | `team_status` 는 `conductor_state` 를 가져오지 못하므로 `TRUST_WHY = ("확인", "씀")` · `TRUST_COLUMNS = ("끝", "까닭", "때", "세션")` 를 두고, 과제 3 의 테스트가 `conductor_state` 의 것과 같은지 단언한다 | 복제한 글자가 갈라지면 「확인」 을 못 알아본다 | `READERS` 에 이름을 더 연다 |
| M31 | `conductor_ledger` 의 오류 받기(I7) | `leader_seat` 를 부르는 자리마다 `except CB.BranchError as e: raise Fail(e.rc, str(e))`. 쓰기 결과의 알림은 줄마다 `[spec-distill] <알림>` 으로 지금 출력 뒤에 낸다 | 일반 예외로 빠져 3 이 되면 표지 아님(5) · 「상태 브랜치가 없다」(1)를 가를 수 없다 | — |
| M35 | 지우기와 `확인한 끝`(I11) | `delete` 가 브랜치를 지운 뒤 기계 상태의 `확인한 끝` 절을 비운다 | 다시 만든 브랜치에서 옛 확인 끝 커밋이 없으면 판정이 영영 `None` 이 된다 | — |
| M36 ★ ⏸ | 남의 고침을 거절하는 길(H2 · I5) | **(가) 의 가장 작은 꼴.** `rules-reset` 은 규칙 쪽 남의 고침이 있거나 재지 못해도 돈다 — 사본과 `rules-base.md` 를 지우는 커밋(이 기계가 만든 것 — `씀`)을 쓰면 규칙은 사람이 머지한 기본 브랜치의 글로 돌아간다. 그 뒤 대기 줄 쪽 남의 고침이 0 이면 `확인한 끝` 을 새 끝으로 옮겨 `rules-add` 가 다시 열린다(규칙 사본이 없는 끝이라 남의 규칙 고침이 남지 않는다). 대기 줄 쪽 남의 고침이 있으면 확인 끝을 옮기지 않고 「대기 줄의 남의 고침은 남아 있다 — confirm 하거나 지운다」 를 낸다. 명령을 늘리지 않는다 | 「남의 고침 앞의 확인된 글」 로 되돌리는 길은 확인 끝의 사본이 기본 브랜치보다 낡았을 수 있고, 한 명령이 경우에 따라 두 뜻(지움 · 되돌림)이 된다. 기본 브랜치의 글은 늘 정해져 있고 사람이 머지한 것이다. 내 안 올린 고침도 함께 지워진다(이력에 남아 다시 더할 수 있다) | (가) `confirm --reject` 를 두고 확인 끝의 글로 되돌린다 · (나) 거절은 브랜치를 지우는 것뿐이라고 절차서에 적는다 |

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

### 사용자 확인 대기(계획 확인 때 지휘자가 여쭌다 — 권장으로 썼다)

| # | 물음 | 고를 길과 각 길이 바꾸는 것 | 권장 · 이유 | 과제 |
|---|---|---|---|---|
| Q1 | 판정 줄 규칙(M17) | (가) 줄 어디든 — `Ruling:` 이 줄 어디에 있든 판정이고 그 뒤 글을 쓴다. 지금 원장을 읽는 둘과 같은 규칙이라 원장에서 고르는 줄은 그대로다. 달라지는 것은 둘 — `ledger_rulings` 가 `Ruling:` 뒤가 빈 줄을 더는 판정으로 내지 않고(지금은 낸다), 판정 줄 꼴을 아는 곳이 변환기 하나가 된다. 글 속 언급 10줄은 판정으로 남는다. (나) 줄 머리 — 불릿 · `Task <n>:` · `**` 를 뗀 뒤 `Ruling:` 으로 시작할 때만 판정. 글 속 언급 10줄이 빠지고, `parked` 줄 · 표 칸의 실제 판정 94줄도 판정에서 빠진다(설계문서 `## 판정` 에 옮겨지지 않는다) | (가) — 실제 판정을 조용히 빠뜨리는 쪽이 눈에 보이는 잘못 든 언급보다 비싸다 | 10 |
| Q2 | 「예약 밖 변경」 을 몇 개에서 줄일지(M18) | 다섯 · 셋 · 열 — 그 수보다 많으면 앞 그 수만큼과 「외 n개」 | 다섯 — 지금 테스트의 줄(둘 · 하나)이 그대로 서고 한 줄에 경로 다섯이면 읽힌다 | 11 |
| H1 | 꺼진 · 사본 없는 team 로드맵에서도 `--rules-at` 을 싣나(M10) | (가) 상태 브랜치에서 규칙을 읽었을 때만 싣는다 — 꺼졌거나 사본이 없으면 묶음 줄과 결과 파일 머리가 지금 그대로(AC20 을 지킨다). (나) 켜져 있으면 늘 싣는다 — 사본이 없어도 결과 파일에 `rules_at` 이 생긴다. (다) 늘 싣는다 — 꺼진 설정에서도 바뀌므로 AC20 에 「`rules_at` 칸은 예외」 를 더해야 한다 | (가) — AC20 을 그대로 지키고, 사본이 없을 때 `rules_at` 은 `bundle_at` 과 같은 커밋이라 실어도 얻는 것이 없다 | 4 |
| H2 | 남이 올린 규칙 고침을 받아들이지 않고 물리는 길(M36) | (가) 가장 작은 꼴 — `rules-reset` 이 남의 고침이 있어도 사본을 지워 기본 브랜치의 규칙으로 돌아간다(명령을 늘리지 않는다 · 내 안 올린 고침도 지워진다). (가′) `confirm --reject` 를 두고 확인 끝의 사본 글로 되돌린다(명령 하나 · 낡은 사본이 돌아올 수 있다). (나) 물리는 길은 상태 브랜치를 지우는 것뿐이라고 절차서에 적는다(코드 없음 · 편지 · 받음 줄도 함께 지워진다) | (가) — 기본 브랜치의 글은 늘 정해져 있고 사람이 머지한 것이라 「확인된 글」 을 고르는 판단이 없다 | 6 · 8 |
| M22 | 과제 폴더 없는 작업을 가르는 법 | (가) 「team 형식에서 로드맵 밖 일의 작업 줄 이름 칸은 과제 이름이다」 약속을 새로 둔다 — 그 약속 전에 쓴 옛 줄에 거짓 알림이 뜬다. (나) 근거 칸이 과제 폴더 아래 경로일 때만 있다고 본다 — 같은 문제. (다) 기계 상태 「작업」 절에 과제 칸을 더한다 — 기계 상태 꼴이 바뀌고 옛 판이 읽지 못한다. (라) 새 약속 · 새 칸 없이 블록 줄은 기본 브랜치에 폴더가 있는지, 로드맵 밖 줄은 이름 칸의 낱말이나 근거 칸 경로에 과제가 드러나는지로 가른다 — 둘 다 드러나지 않는 옛 줄에는 알림이 뜬다 | (라) — 새 약속도 기계 상태 꼴 변경도 없고, 블록 줄은 근사가 아니라 실제 폴더를 본다 | 11 |
| M25① | 끝난 로드맵에서 `ensure` 가 지운 상태 브랜치를 다시 만드는 것 | (가) 블록 · 로드맵 밖 과제를 함께 세는 술어로 막는다 — 넷째 술어 사본이 생긴다. (나) 고치지 않고 리뷰 잔여로 둔다 — 「끝나지 않은 로드맵」 술어를 하나로 모으는 E2 가 받는다. (다) 블록만 센다 — 로드맵 밖 과제만 남은 로드맵에서 상태 브랜치가 서지 않는다 | (나) — E2 가 술어를 하나로 모은 뒤에 고치면 사본이 생기지 않는다 | (없음) |
| 제안 5 | AC16 에 더할 글(M15) | 더한다 — 「(team 형식 · 상태 브랜치 자리) 사람 줄 종류는 `add` 가 받지 않고 `flush` 가 건너뛰어 센다」 · 더하지 않는다 — 계획은 그대로이고 미룸 행이 근거다 | 더한다 — 보이는 동작이다 | 9 |
| lease | 원격 지우기에 `--force-with-lease`(M25④) | 쓴다 — 센 끝과 원격이 다르면 지우지 않는다(지우기를 좁힌다). 글자에 `force` 가 들어 설계 §1 · 브랜치 규칙 문서의 「force-push 하지 않는다」 와 겉으로 부딪힌다. 쓰지 않는다 — 견줌과 지우기 사이의 짧은 창을 공시만 한다 | 쓴다 — 이력을 덮는 올리기가 아니라 조건을 건 지우기다 | 13 |

### 사용자가 정한 것(2026-11-20 — 계획 1 PR #306 에 반영됐다)

| # | 물음 | 답 | 이 계획에서 |
|---|---|---|---|
| U1 | AC3 의 글자 · 세 번 거절이면 종료 코드 1 | (가) 코드 그대로 · AC3 에 「세 번 이어서 거절되면 … 종료 코드 1 로 멈춘다」 를 더했다(사용자 「셋 모두 구현에 맞춘다」) | 과제 14 건너뜀 |
| U2 | 두 세션 알림 · 지우기의 수용 기준 줄 | (가) AC22 · AC23 을 새로 적었고 계획 1 의 구현 대조가 「구현됨」 으로 셌다 | 과제 15 — 번호 주석만 · 대조 목록 그대로 |
| U3 | 지우기 확인 표시의 꼴 | (가) `--confirmed <수를 센 끝>` 을 두고 §1 글자를 맞췄다 | 과제 16 건너뜀 |
| U4 | 「지금 묻는 질문」 종류 이름 | (가) 사람 줄 종류 이름에 맞췄다 — 여덟 · 별칭 없음(사용자 「R2 이름에 맞춘다」) | 과제 17 건너뜀 · 이 계획의 테스트 · 문서는 새 이름만 쓴다 |

---

## 머지 전 다시 셀 것

R2 계획 2 가 먼저 머지되면, 또 R3 계획 1 브랜치에 커밋이 더 쌓이면 `git merge origin/main`(또는 `origin/feature/conductor-state-branch`) 뒤 아래를 하나씩 연다 — 충돌 목록에 없어도 `git diff origin/main -- <경로>` 로 본다(같은 판으로 올린 `plugin.json` 은 조용히 합쳐진다). 기본 브랜치를 합칠 때마다 다시 한다.

| # | 자리 | 견줄 것 |
|---|---|---|
| 1 | `.claude-plugin/plugin.json` · `CHANGELOG.md` 맨 위 머리 | 기본 브랜치의 판 바로 다음 minor 이고 머리가 하나만 더해졌다(테스트는 판 리터럴이 없다). 계획 1 의 8.26.0 절(종류 여덟의 글)이 그대로 있다 |
| 2 | `references/team-files.md` §9 의 「맞추는 명령」 예시 줄 | R2 계획 2 과제 10 이 같은 줄의 경로 따옴표를 뗀다. 합친 뒤 그 줄이 따옴표 없이 있고 `--rules-at` 의 설명(상태 브랜치에서 읽었을 때만)이 붙어 있는지 |
| 3 | `references/team-files.md` §5 머리 예시 · §10 「묶음 낡음」 문단 · §2 · §15 · `## 목차` | R2 계획 2 가 §2 · §5 · §6 · §9 · §10 과 새 `### 걸음표` 를 고친다. `rules_at` 줄 · 「규칙을 읽은 커밋」 문장 · §15 의 새 「지금의 값」 이 남아 있는지, 목차가 절과 맞는지 |
| 4 | `references/conducting.md` 걸음 5 | R2 계획 2 가 걸음 2 – 5 의 「- 판단:」 뒤에 한 줄씩과 끝에 `## team 형식 로드맵` 절을 더한다. 이 계획의 걸음 5 「기본값」 끝 문장이 그대로이고 `test_conductor_state_branch_docs.py` 의 걸음 가르기(`step(5)`)가 새 줄 때문에 다른 글을 잡지 않는지 |
| 5 | `skills/epic-conductor/SKILL.md` | 「5. 지휘 순환」 의 `Read` 펜스에 셋째 줄이 있고 R2 계획 2 의 문장(208행 근처)과 겹치지 않는지 · `test_epic_conductor_skill.sh` |
| 6 | `scripts/start_bundle.py` | R2 계획 2 가 `_job_bundle` 의 힌트 조건을 고친다 — `sync_line` · `open_base` · `_job_bundle` 의 `--rules-at` 갈래가 그대로인지 · `bash tests/test_start_bundle.sh` |
| 7 | `tests/test_team_docs.py` 356 – 358행 · `tests/test_start_bundle.sh` 의 「맞추는 명령」 단언(155 · 172 · 193 · 400행)과 이 계획이 더한 단언 | R2 계획 2 과제 10 이 바로 옆 줄을 고친다. 넷인 부름의 기대 줄은 바뀌지 않았고 이 계획이 더한 다섯인 부름의 단언이 있는지(B1) |
| 8 | `scripts/conductor_ledger.py` | R2 계획 2 는 `human-check` 를 고친다 — `c_add` · `c_drop` · `c_pending` · `c_flush` · `c_pr_refresh` 의 이 계획 고침이 그대로인지 · `python3 -m unittest tests/test_conductor_ledger.py` |
| 9 | `scripts/human_lines.py` | R2 계획 2 과제 5 · 6 이 고친다. 이 계획은 `is_human` 에 기댄다 — 합친 뒤 `is_human` 의 꼴(받는 것 · 내는 것)이 같은지 · 과제 9 의 사람 줄 테스트 |
| 10 | `scripts/job_results.py` | 이 계획은 고치지 않는다 — `git diff origin/main -- plugins/spec-distill/scripts/job_results.py` 가 R2 의 것뿐인지 |
| 11 | `tests/fixtures/team_repo.sh` | 바뀌었으면 `bash tests/test_leader_seat_e2e.sh` 를 다시 돌린다 |
| 12 | `tests/test_start_bundle.sh` · `tests/test_team_stale.sh` 의 `team_layout.leader_ref = lambda …` 줄 | 두 인자를 받는 꼴(`lambda ref, tip=None: …`)인지 — R2 가 같은 줄을 더 썼으면 그 줄도 |
| 13 | `tests/test_team_status.sh` · `tests/test_team_tasks.sh` | 두 계획이 모두 행을 더한다 — 합친 뒤 두 쪽 행이 다 있는지 · 실패 0 |
| 14 | `tests/test_repo_literals.sh` 의 `TARGETS` | R2 는 `walk_table.py` 를, 이 계획은 `leader_seat.py` 를 더한다 — 둘 다 있는지 |
| 15 | `references/roadmap-ontology.md` | R2 는 설정 키 줄을, 이 계획은 기계 상태 · 상태 브랜치 줄의 속성 칸을 고친다 — 둘 다 있는지 · `test_roadmap_ontology.py` |
| 16 | README 「Principles Instantiated」 · 「지휘자 상태 브랜치」 절 | 줄이 겹쳐 지워지지 않았는지 |
| 17 | `tests/test_roadmap_status.sh` 의 `READERS` · `CHECKED 16` · `control_plane.CODE_STAMP_FILES` | `READERS` 에 `TRUST` 가 있고 수와 목록은 기본 브랜치와 같다 |
| 18 | `repo_defaults.KEYS` 와 키 수 글자 | 이 계획은 키를 더하지 않는다 — 기본 브랜치와 같은지만 본다 |
| 19 | `tests/test_conductor_state_branch_docs.py` | 계획 1 의 뒤 커밋이 고친 것(종류 여덟 · 변경 기록을 8.26.0 으로 고르는 락)과 이 계획의 고침(`LeaderSeatDocs` · 지운 한 줄 · `NEW_MODULES`)이 함께 있는지 |

---

## 파일 표

| 파일 | 과제 | 무엇 |
|---|---|---|
| `scripts/team_layout.py` · `scripts/conductor_branch.py` · `scripts/conductor_status.py` · `scripts/conductor_state.py` · `tests/test_conductor_state.py` · `tests/test_conductor_branch.py` | 2 | 접두 상수 · 기계 상태 `확인한 끝` · 만든 커밋 기록 · 명령줄 진입 |
| `scripts/team_status.py` · `scripts/team_layout.py` · `scripts/roadmap_status.py` · `scripts/start_bundle.py` · `scripts/control_plane.py` · `tests/test_leader_seat.py`(새로) · `tests/test_control_plane.py` · `tests/test_roadmap_status.sh` · `tests/test_start_bundle.sh` · `tests/test_team_stale.sh` · `tests/test_team_layout.py` · `tests/test_conductor_state_branch_docs.py` | 3 | 남의 고침 · 규칙을 읽을 끝 · 캐시 열쇠 |
| `scripts/start_bundle.py` · `scripts/team_write.py` · `scripts/roadmap_write.py` · `scripts/team_files.py` · `scripts/team_status.py` · `tests/test_team_sync.sh` · `tests/test_team_results.py` · `tests/test_team_docs.py` · `tests/test_start_bundle.sh` · `tests/test_leader_seat_e2e.sh`(새로 · 100755) | 4 | `rules_at` |
| `scripts/team_status.py` · `tests/test_team_stale.sh` | 5 | 「묶음 낡음」 빈 곳 |
| `scripts/leader_seat.py`(새로) · `scripts/conductor_branch.py` · `tests/test_leader_seat.py` · `tests/test_leader_seat_e2e.sh` | 6 · 7 · 8 | 규칙 사본 고침 · `rules-branch` · `confirm` |
| `scripts/conductor_status.py` · `tests/test_conductor_cross.py` · `tests/test_leader_seat_e2e.sh` | 7 · 8 | `sync` 의 사본 지우기 · 갈라짐 · 남의 고침 n · `show` |
| `scripts/conductor_ledger.py` · `scripts/leader_seat.py` · `tests/test_conductor_ledger.py` · `tests/test_leader_seat_e2e.sh` | 9 | 대기 줄 |
| `scripts/workflow_superpowers.py` · `scripts/conductor_state.py` · `scripts/team_files.py` · `scripts/team_write.py` · `tests/test_workflow_superpowers.py` | 10 | 판정 줄 규칙 하나 |
| `scripts/roadmap_status.py` · `scripts/control_plane.py` · `tests/test_control_plane.py` · `tests/test_team_status.sh` · `tests/test_team_tasks.sh` · `tests/test_roadmap_status.sh` | 11 | 현황 수리 |
| `scripts/conductor_ledger.py` · `tests/test_team_tasks.sh` | 12 | 단순 작업 PR 캐시 |
| `scripts/conductor_status.py` · `scripts/conductor_branch.py` · `scripts/conductor_mail.py` · `tests/test_conductor_status.py` · `tests/test_conductor_branch.py` · `tests/test_conductor_mail.py` · `tests/test_conductor_cross.py` | 13 | 계획 1 잔여 |
| `tests/test_conductor_status.py` · `tests/test_conductor_branch.py` | 15 | AC22 · AC23 번호 주석 |
| `references/conducting.md` · `skills/epic-conductor/SKILL.md` · `references/conductor-state-branch.md` · `references/team-files.md` · `references/roadmap-ontology.md` · `README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json` · `tests/test_conductor_state_branch_docs.py` · `tests/test_team_docs.py` · `tests/test_repo_literals.sh` | 18 | 문서와 판 |
| `tests/test_leader_seat_e2e.sh` · `tests/test_leader_seat.py` · `tests/test_conductor_state_branch_docs.py` | 19 | 끝에서 끝 · 옛 동작 · 변이 · 닫힘 락 · 전체 스위트 |

고치지 않는 것: `scripts/job_results.py`(M11) · `scripts/repo_defaults.py` · `scripts/check_deps.py` · `dependencies.md`(「고치지 않고 둔 것」) · `tests/test_roadmap_status.sh` 의 정적 검사 목록과 `CHECKED` 수 · `control_plane.CODE_STAMP_FILES` · `plugins/project-init/` · 설계문서 · 지나간 계획. 과제 14 · 16 · 17 은 건너뛴다(사용자 2026-11-20).

---

### Task 1: 다시 확인

**AC:** 없음(준비).

**Files:** 없음(읽기만).

- [ ] **Step 1: 기준 브랜치를 본다**

이 브랜치가 R3 계획 1 브랜치(머지됐으면 기본 브랜치)를 품었는지 본다 — `git merge-base --is-ancestor origin/feature/conductor-state-branch HEAD; echo $?` 가 0(그 브랜치가 지워졌으면 `origin/main` 으로). 0 이 아니면 지휘자에게 알리고 `git merge` 한 뒤 Step 2 로 간다(충돌하면 풀지 말고 멈춘다).

- [ ] **Step 2: 설계가 근거로 든 자리가 지금도 그런지 본다**

worktree 뿌리에서 아래를 돌린다. 줄 끝 주석의 기대값과 **하나라도 다르면 멈추고 지휘자에게 보고한다**(무엇이 다른지 · 설계의 어느 문장이 그 자리에 기대는지). 계획을 고칠 때(2026-11-20 · 계획 1 브랜치 끝 `dc112961` 을 합친 뒤) 모두 기대값이었다. 판 줄은 R2 계획 2 가 먼저 머지됐으면 `origin/main` 이 8.27.0 이다.

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
sed -n '/    def stale(self, tip: str, block: dict) -> list:/,/    def _fill_progress/p' $P/scripts/team_status.py | grep -c '^            if result is None:'   # 1
echo "$(grep -c '^def rules_gap(root, roadmap_rel: str, tip: Optional\[str\]) -> int:' $P/scripts/conductor_status.py) $(grep -c '"pending": sum(1 for line in pending.splitlines() if line.startswith("- "))' $P/scripts/conductor_status.py)"   # 1 1
echo "$(grep -c '^    onto: Optional\[str\]' $P/scripts/conductor_branch.py) $(grep -c '^PENDING_FILE = "pending.md"' $P/scripts/conductor_branch.py)"   # 1 1
grep -c 'target = made or new' $P/scripts/conductor_branch.py                                                            # 1 — B3 의 자리
grep -c "^def pr_cache_prints(targets, machine_lookup) -> str:" $P/scripts/control_plane.py                             # 1 — M29 의 자리
echo "$(grep -c 'conductor-state-branch.md' $P/references/conducting.md) $(sed -n '/^### 5\. 머지 전 확인/,/^### 6\./p' $P/references/conducting.md | grep -c 'conductor-state-branch\|규칙 고침')"   # 3 0
echo "$(grep -c '^Read \${CLAUDE_PLUGIN_ROOT}/references/' $P/skills/epic-conductor/SKILL.md) $(grep -c 'conductor-state-branch' $P/skills/epic-conductor/SKILL.md)"   # 2 0
grep -c 'RULES.md 의 고침과 대기 줄은 아직 옮기지 않았다' $P/references/team-files.md                                  # 1
grep -c '^ASK_KINDS = ("설계 대화", "spec 승인", "계획 검토", "흐름 승인", "걸음 건너뜀", "옮긴 질문", "머지", "그 밖")' $P/scripts/conductor_state.py   # 1 — 종류 여덟(U4)
grep -c 'body.startswith("8.26.0\] — ")' $P/tests/test_conductor_state_branch_docs.py                                   # 1 — 계획 1 의 변경 기록 락은 판 번호로 절을 고른다
echo "$(grep -c '^- AC22: \|^- AC23: ' docs/superpowers/specs/2026-11-19-conductor-state-branch-design.md) $(grep -c '세 번 이어서 거절되면' docs/superpowers/specs/2026-11-19-conductor-state-branch-design.md)"   # 2 1 — U2 · U1
grep -c '대기 줄에 사람 줄 종류(`spec 승인` · `계획 검토`' docs/superpowers/specs/2026-11-19-conductor-state-branch-design.md   # 1 — M15 가 받는 미룸 행
echo "$(grep -o '"version": "[0-9.]*"' $P/.claude-plugin/plugin.json) · main $(git show origin/main:$P/.claude-plugin/plugin.json | grep -o '"version": "[0-9.]*"')"   # 8.26.0 · main 8.25.0
echo "$(grep -o 'len(rd.KEYS), [0-9]*' $P/tests/test_repo_defaults.py) $(grep -o '"CHECKED 16"' $P/tests/test_roadmap_status.sh | sort -u)"   # len(rd.KEYS), 14 "CHECKED 16"(R2 계획 2 뒤면 15)
grep -c 'team = team_of(root, roadmap_rel)' $P/scripts/conductor_branch.py                                              # 3 — availability 보다 먼저 설정을 읽는 자리(M25 ②)
```

- [ ] **Step 3: 판정 줄 실측이 계획의 표와 같은 꼴인지 본다**

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

### Task 2: 접두 상수 · 기계 상태 `확인한 끝` · 이 기계가 만든 커밋 · 명령줄 진입

**AC:** AC21(기반 — 「확인한 끝은 기계 상태에 남고」).

**Files:**
- Modify: `scripts/team_layout.py`(상수 `STATE_BRANCH_PREFIX`) · `scripts/conductor_branch.py`(`STATE_BRANCH_PREFIX` 를 그 상수로 · `Result.made` · `_write_floor` · `_publish` · `_replay` 가 만든 커밋을 적는다 · 파일 끝의 진입) · `scripts/conductor_status.py`(`FETCH_HINT` 를 상수로 짓는다) · `scripts/conductor_state.py`(절 `확인한 끝`)
- Test: `tests/test_conductor_state.py` · `tests/test_conductor_branch.py`

**Interfaces:**
- Produces: `team_layout.STATE_BRANCH_PREFIX = "conductor/"` · `conductor_state.TRUST = "확인한 끝"` · `conductor_state.TRUST_WHY = ("확인", "씀")` · `conductor_state.COLUMNS[TRUST] == ("끝", "까닭", "때", "세션")`(선택 절 — 비면 머리를 쓰지 않는다) · `conductor_branch.Result` 의 다섯째 칸 `made: tuple = ()`(Global Constraints 「씀」 의 뜻 · 차례대로) · `conductor_branch.record_own(root, roadmap_rel: str, session: str, commits: list) -> None`(기계 상태에 `씀` 줄을 더한다 · 표지 확인은 부르는 쪽이 이미 했다 · 빈 목록이면 아무것도 하지 않는다).

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

`tests/test_conductor_branch.py` 에 — 만든 커밋만 적힌다(실제 임시 레포 · 실제 거절):

```python
class OwnCommits(StateRepo):   # R3 AC21 · Review Focus 1 · B3
    def own(self):
        return [r["끝"] for r in cs.load(cs.machine_path(state_root(str(self.w)), rm(ALPHA)), rm(ALPHA))[cs.TRUST]
                if r["까닭"] == "씀"]

    def other_writes(self, files):
        """둘째 클론이 같은 상태 브랜치에 써 올린다 — 그 커밋을 돌려준다."""
        other = self.clone("other%d" % len(list(self.t.iterdir())))
        self.claim(repo=other, session=OTHER)
        team = CB.team_of(str(other), rm(ALPHA))
        CB._fetch(str(other), team.name)
        self.g("update-ref", CB.ref_of(team.name), "refs/remotes/origin/" + CB.branch_of(team.name), repo=other)
        return CB.write(str(other), rm(ALPHA), OTHER, lambda b: files, "남").commit

    def test_every_made_commit_is_recorded(self):
        self.claim()
        made = CB.ensure(str(self.w), rm(ALPHA), SID)
        team = CB.team_of(str(self.w), rm(ALPHA))
        res = CB.write(str(self.w), rm(ALPHA), SID, lambda b: {team.status: "x\n"}, "STATUS")
        self.assertEqual(self.own(), [made.commit, res.commit])
        self.assertEqual(res.made, (res.commit,))

    def test_remade_on_foreign_tip_records_only_mine(self):   # 남의 커밋은 「씀」 이 아니다
        self.claim()
        CB.ensure(str(self.w), rm(ALPHA), SID)
        team = CB.team_of(str(self.w), rm(ALPHA))
        theirs = self.other_writes({team.rules: "- [남] 남의 줄\n"})
        mine = CB.write(str(self.w), rm(ALPHA), SID, lambda b: {team.status: "y\n"}, "STATUS")   # 거절 → 받아 와 다시 만든다
        self.assertEqual(mine.onto, theirs)
        self.assertNotIn(theirs, self.own())
        self.assertIn(mine.commit, self.own())

    def test_unchanged_remake_moves_ref_to_foreign_tip_without_recording_it(self):   # B3 — made 가 None 인 갈래
        self.claim()
        CB.ensure(str(self.w), rm(ALPHA), SID)
        team = CB.team_of(str(self.w), rm(ALPHA))
        theirs = self.other_writes({team.status: "같은 글\n"})
        res = CB.write(str(self.w), rm(ALPHA), SID, lambda b: {team.status: "같은 글\n"}, "STATUS")   # 원격 끝에서는 바뀐 것이 없다
        self.assertEqual(CB.local_tip(str(self.w), team.name), theirs)   # ref 는 남의 끝으로 옮겨 갔다
        self.assertNotIn(theirs, self.own())                             # 그래도 「씀」 이 아니다
        self.assertNotIn(theirs, res.made)

    def test_creating_race_does_not_record_the_adopted_root(self):   # B3 — ensure 가 만드는 사이 남이 먼저 올렸다
        other = self.clone("first")
        self.claim(repo=other, session=OTHER)
        their_root = CB.ensure(str(other), rm(ALPHA), OTHER).commit
        self.claim()
        real = CB.git   # 바꿔 끼우기 전에 잡는다 — 안에서 잡으면 자기 자신을 부른다

        def fake(root, *a, **k):   # ls-remote 가 「없다」(2)고 답한 것처럼 — 만드는 쪽으로 보낸다
            return (2, "", "") if a[:1] == ("ls-remote",) else real(root, *a, **k)
        with mock.patch.object(CB, "git", side_effect=fake):
            CB.ensure(str(self.w), rm(ALPHA), SID)
        self.assertNotIn(their_root, self.own())
```

다섯째의 mock 은 원격의 「있다/없다」 답만 바꾼다 — 뿌리를 만들고 실제로 올리다 거절되는 길은 실제 git 이 탄다. 붉어지는 변이: `_publish` 의 다시 만들기 갈래에서 기록을 지운다(둘째의 셋째 단언) · 기록에 `target` 을 넣는다(셋째 · 다섯째) · 기록에 `remote` 를 넣는다(둘째) · `ensure` 의 만들기를 기록하지 않는다(첫째).

`tests/test_conductor_branch.py` 에 — 명령줄 진입(B2):

```python
class CommandLineIdentity(StateRepo):   # B2 — 함수 안에서 가져온 모듈이 던진 BranchError 도 그 종료 코드로 끝난다
    def test_branch_error_raised_from_a_late_import_keeps_its_code(self):
        p = subprocess.run([sys.executable, str(SCRIPTS / "conductor_branch.py"), "--root", str(self.w),
                            "ensure", "--roadmap", rm(ALPHA), "--session", SID], capture_output=True, encoding="utf-8")
        self.assertEqual(p.returncode, 5)   # 표지 없음 — 지금도 5(양성 대조: 같은 모듈 안의 오류)
        src = (SCRIPTS / "conductor_branch.py").read_text(encoding="utf-8")
        self.assertIn('if __name__ == "__main__":\n    import conductor_branch as _self\n    sys.exit(_self.main())', src)
```

(이빨은 과제 6 · 8 의 명령줄 테스트가 진다 — `rules-add` 의 2 · `confirm` 의 1 과 마지막 줄.)

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_state.py plugins/spec-distill/tests/test_conductor_branch.py 2>&1 | tail -3`
Expected: `TrustSection` · `OwnCommits` · `CommandLineIdentity` FAIL

- [ ] **Step 3: 구현한다**

- `team_layout.STATE_BRANCH_PREFIX = "conductor/"`. `conductor_branch.STATE_BRANCH_PREFIX = team_layout.STATE_BRANCH_PREFIX`. `conductor_status.FETCH_HINT` 를 그 상수에서 짓는다(글은 지금과 바이트까지 같다).
- `conductor_state` — `SECTIONS` 끝(옛 절 둘 앞)에 `(TRUST, ("끝", "까닭", "때", "세션"))`, `OPTIONAL_SECTIONS` 에 `TRUST`. `_check_row` 에 갈래: `OID_RE.fullmatch(끝)` · `까닭 in TRUST_WHY` · `STAMP_RE.fullmatch(때)` · `SESSION_PATTERN.fullmatch(세션)`.
- `conductor_branch` — `Result` 에 `made: tuple = ()`. `_write_floor` 와 `_publish` 가 목록 하나를 함께 들고, `_build_commit` 이 `None` 아닌 커밋을 낼 때마다(뿌리 · 이번 쓰기 · `_replay` 가 새 커밋을 낸 때 — `_replay` 는 만든 커밋을 그 목록에 더한다 · 다시 만든 쓰기) 더한다. `target = made or new` 의 `new` 가 원격 끝이거나 `_replay` 가 돌려준 `onto` 이면 더하지 않는다. `try/finally` 로 `record_own` 을 한 번 부른다. `ensure` 의 받아 오기(`_adopt`)는 남의 끝이라 적지 않는다. 파일 끝은 Global Constraints 「명령줄 진입」 의 세 줄.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_state.py plugins/spec-distill/tests/test_conductor_branch.py plugins/spec-distill/tests/test_conductor_status.py plugins/spec-distill/tests/test_conductor_mail.py plugins/spec-distill/tests/test_conductor_cross.py 2>&1 | tail -1; bash plugins/spec-distill/tests/test_roadmap_status.sh | tail -1; bash plugins/spec-distill/tests/test_conductor_state_branch_e2e.sh | tail -1`
Expected: `OK` · 실패 0 · 실패 0(기계 상태를 바이트로 견주는 테스트가 붉으면 빈 절의 머리를 쓴 것이다)

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/team_layout.py plugins/spec-distill/scripts/conductor_branch.py plugins/spec-distill/scripts/conductor_status.py plugins/spec-distill/scripts/conductor_state.py plugins/spec-distill/tests/test_conductor_state.py plugins/spec-distill/tests/test_conductor_branch.py
git commit -m "feat(spec-distill): 상태 브랜치 쓰기가 만든 커밋만 기계 상태의 확인한 끝 절에 적는다"
```

---

### Task 3: 남의 고침 · 규칙을 읽을 끝 · 캐시 열쇠

**AC:** AC15(「상태 브랜치가 켜져 있고 사본이 있으면 `leader_ref` 가 그 끝을, 없으면 기본 브랜치를」) · AC21(「사용자가 확인하기 전에는 `leader_ref` 가 기본 브랜치를」) · AC14(꺼짐 → 기본 브랜치).

**Files:**
- Modify: `scripts/team_layout.py`(`leader_ref`) · `scripts/team_status.py`(상수 둘 · 새 함수 셋 · `Reader` 가 `lead_tip` 을 받는다) · `scripts/roadmap_status.py`(`read_machine` 을 가르고 team 로드맵이면 `rules_tip` 을 `Reader` 에 넘긴다) · `scripts/start_bundle.py`(`open_base`) · `scripts/control_plane.py`(`pr_cache_prints` · `cache_key` 문서 문자열)
- Test: `tests/test_leader_seat.py`(새로) · `tests/test_control_plane.py` · `tests/test_team_layout.py` · `tests/test_start_bundle.sh` · `tests/test_team_stale.sh` · `tests/test_roadmap_status.sh`(`READERS` 에 `TRUST`) · `tests/test_conductor_state_branch_docs.py`

**Interfaces:**
- Consumes: 과제 2 의 `TRUST` · `TRUST_WHY` · `STATE_BRANCH_PREFIX`.
- Produces:
  - `team_layout.leader_ref(default_ref: str, state_tip: Optional[str] = None) -> str`
  - `team_status.TRUST_WHY` · `team_status.TRUST_COLUMNS`(M30)
  - `team_status.trust_of(rows: Optional[list]) -> Optional[tuple]` — `(확인 끝 | None, 씀 커밋들의 frozenset)`. `rows` 가 `None`(기계 상태를 읽지 못함)이면 `None`. `확인` 줄이 둘 이상이면 `None`.
  - `team_status.foreign_commits(git, tip: str, trust: Optional[tuple], paths: list) -> Optional[list]` — M4. `[(커밋 40자, (바꾼 경로…)), …]`(오래된 차례). `trust` 가 `None` · 확인 끝이 이 레포에 없음 · git 실패 · 남의 머지면 `None`.
  - `team_status.rules_paths(team) -> list` — `[team.rules, team.path("rules-base.md")]`(이 파일 이름 상수 `team_status.RULES_BASE_FILE` 를 `leader_seat` 가 다시 내보낸다) · `team_status.pending_paths(team) -> list` — `[team.path("pending.md")]`(`conductor_branch.PENDING_FILE` 과 같은지 과제 3 의 테스트가 본다)
  - `team_status.rules_tip(git, team, on: bool, rows: Optional[list]) -> tuple` — `(상태 브랜치 끝 | None, 알림들)`. `on` 이 거짓 · 상태 브랜치 없음 · 사본 없음이면 `(None, [])`. 갈라짐이면 알림 한 줄. 남의 고침이 있으면 `(None, ["확인되지 않은 남의 고침 %d — 규칙은 기본 브랜치의 글을 읽는다"])`, 재지 못하면 `(None, ["남의 고침을 재지 못했다 — 규칙은 기본 브랜치의 글을 읽는다"])`.
  - `team_status.Reader(..., lead_tip: Optional[str] = None)` — `stale` 이 `team_layout.leader_ref(self.main, self.lead_tip)` 를 쓴다.
  - `roadmap_status.read_machine(git, roadmap_rel) -> tuple` — `(data | None, 못 읽은 사유 | None)`. `read_pr_cache` 는 이것 위에 선다(출력 그대로).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_leader_seat.py` — 머리에서 `from conductor_branch_fixture import ALPHA, OTHER, ROADMAPS, SCRIPTS, SID, StateRepo, rm, roadmap_text` · `import conductor_branch as CB` · `import conductor_state as cs` · `import roadmap_status as RS` · `import team_layout as TL` · `import team_status as TS` · `from state_path import state_root` · `from unittest import mock` · `import subprocess, sys` 를 가져오고(과제 6 부터 `import leader_seat as LS`), team 형식 로드맵을 세우는 픽스처를 둔다. 이 픽스처의 로드맵은 상태 계산을 깨끗이 지나지 않는다(블록의 `묶음:` 이 team 형식의 번호 파일이 아니다 — 계획을 고치며 돌려 봤다: 보고는 서지만 단계가 「알 수 없음」 이고 형식 오류가 남는다. 번호 파일 꼴로 바꾸면 보고가 아예 서지 않는다). 그래서 **상태 계산을 거치는 걸음(`sync` · 시작 묶음 · 상태 보기)은 이 파일에서 재지 않고** `tests/test_leader_seat_e2e.sh`(`team_repo.sh` 의 온전한 team 레포)가 잰다.

```python
TEAM_RULE = "- [하나] 고친 곳엔 테스트 먼저 · 조건: 역할=worker · 출처: a · 확인: b"
SPEC = "refs/heads/conductor/%s:refs/remotes/origin/conductor/%s" % (ALPHA, ALPHA)


class TeamRepo(StateRepo):
    """ALPHA 를 team 형식(머리말 layout: team)으로 다시 쓰고 기본 브랜치에 규칙 파일 한 줄을 둔다.
    상태 계산을 거치지 않는 함수(leader_seat · team_status 의 남의 고침 판정)만 이 픽스처로 잰다."""
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

    def foreign_edit(self, label="other", files=None):
        """둘째 클론이 상태 브랜치에 남의 고침을 올리고 첫 클론이 받아 온다. 부를 때마다 다른 클론 이름 · 다른 글을 준다."""
        other = self.clone(label)
        self.g("fetch", "-q", "origin", SPEC, repo=other)
        self.g("update-ref", "refs/heads/conductor/" + ALPHA, "refs/remotes/origin/conductor/" + ALPHA, repo=other)
        self.claim(repo=other, session=OTHER)
        files = files or {self.team.rules: TEAM_RULE + "\n- [남] %s · 조건: 역할=worker · 출처: a · 확인: b\n" % label}
        commit = self.write(files, repo=other, session=OTHER).commit
        self.g("fetch", "-q", "origin", SPEC)
        return commit

    def ls(self, *args):
        """명령줄로 conductor_branch.py 를 부른다 — (종료 코드, 표준 출력 + 표준 오류)."""
        p = subprocess.run([sys.executable, str(SCRIPTS / "conductor_branch.py"), "--root", str(self.w), *args],
                           capture_output=True, encoding="utf-8")
        return p.returncode, p.stdout + p.stderr
```

```python
class RulesTip(TeamRepo):   # R3 AC15 · AC21 · AC14
    def tip_of(self, on=True, rows="load"):
        return TS.rules_tip(RS.Git(str(self.w)), self.team, on, self.rows() if rows == "load" else rows)

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
        self.foreign_edit()
        tip, notes = self.tip_of()
        self.assertIsNone(tip)
        self.assertEqual(notes, ["확인되지 않은 남의 고침 1 — 규칙은 기본 브랜치의 글을 읽는다"])

    def test_unreadable_machine_state_closes(self):   # I11 — 한 뜻: 재지 못함
        self.write({self.team.rules: "- 사본\n"})
        tip, notes = self.tip_of(rows=None)
        self.assertIsNone(tip)
        self.assertEqual(notes, ["남의 고침을 재지 못했다 — 규칙은 기본 브랜치의 글을 읽는다"])


class Foreign(TeamRepo):
    def trust(self):
        return TS.trust_of(self.rows())

    def test_only_the_named_paths_count(self):   # 남이 STATUS 만 바꾼 커밋은 세지 않는다
        git = RS.Git(str(self.w))
        fake = self.foreign_edit("o1", {self.team.status: "x\n"})
        self.assertEqual(TS.foreign_commits(git, self.tip(), self.trust(), TS.rules_paths(self.team)), [])
        moved = self.foreign_edit("o2")
        got = TS.foreign_commits(git, self.tip(), self.trust(), TS.rules_paths(self.team))
        self.assertEqual(got, [(moved, (self.team.rules,))])
        self.assertNotIn(fake, [c for c, _p in got])

    def test_own_commits_are_not_foreign(self):
        mine = self.write({self.team.rules: "- 내 줄\n"}).commit
        self.assertEqual(TS.foreign_commits(RS.Git(str(self.w)), mine, self.trust(), TS.rules_paths(self.team)), [])

    def test_git_failure_or_missing_base_is_none_not_empty(self):
        git = RS.Git(str(self.w))
        self.assertIsNone(TS.foreign_commits(git, "f" * 40, self.trust(), TS.rules_paths(self.team)))
        self.assertIsNone(TS.foreign_commits(git, self.tip(), ("e" * 40, frozenset()), TS.rules_paths(self.team)))

    def test_foreign_merge_back_to_an_old_copy_is_not_hidden(self):   # I2 — 경로 한정 log 의 이력 단순화가 숨기는 머지
        old = self.write({self.team.rules: "- 옛 줄\n"}).commit
        self.write({self.team.rules: "- 새 줄\n"})
        mine = self.write({self.team.status: "s\n"}).commit
        other = self.clone("merger")   # 남의 기계 흉내: old 위에 규칙을 건드리지 않는 커밋 B, 그리고 머지 M(mine, B) 의 규칙 = 옛 줄
        self.g("fetch", "-q", "origin", SPEC, repo=other)
        b_tree = self.g("rev-parse", old + "^{tree}", repo=other)
        b = self.g("commit-tree", b_tree, "-p", old, "-m", "B", repo=other)
        m_tree = self.g("rev-parse", old + "^{tree}", repo=other)   # 규칙 = 옛 줄 · STATUS 는 없어도 된다 — 숨김은 규칙 경로에서 일어난다
        m = self.g("commit-tree", m_tree, "-p", mine, "-p", b, "-m", "M", repo=other)
        self.g("push", "-q", "origin", "%s:refs/heads/conductor/%s" % (m, ALPHA), repo=other)
        self.g("fetch", "-q", "origin", SPEC)
        git = RS.Git(str(self.w))
        hidden = git.run("log", "--format=%H", "%s..%s" % (mine, m), "--", self.team.rules)[1].split()
        self.assertEqual(hidden, [])   # 양성 대조 — 기본 이력 단순화는 정말 숨긴다(고치기 전의 꼴은 0 으로 읽힌다)
        self.assertIsNone(TS.foreign_commits(git, m, self.trust(), TS.rules_paths(self.team)))   # 닫는 쪽
        self.assertIsNone(TS.rules_tip(git, self.team, True, self.rows())[0])

    def test_columns_match_the_machine_state(self):   # M30 — 붉어지는 변이: 한쪽 글자를 바꾼다
        self.assertEqual((TS.TRUST_WHY, TS.TRUST_COLUMNS), (cs.TRUST_WHY, cs.COLUMNS[cs.TRUST]))
        self.assertEqual(TS.pending_paths(self.team), [self.team.path(CB.PENDING_FILE)])
```

붉어지는 변이: `rules_tip` 에서 `on` 검사를 지운다(셋째) · 남의 고침 판정을 지운다(넷째) · `trust_of(None)` 을 「모두 내 것」 으로(다섯째) · `foreign_commits` 가 경로 거르기를 뺀다(여섯째) · 실패를 `[]` 로(여덟째) · 머지 검사(M4 ①)를 지운다(아홉째의 둘째 단언 — **고치기 전 꼴에서 붉고 고친 코드에서 초록인 재현 테스트**).

`tests/test_control_plane.py` 에 — 열쇠에 `확인한 끝` 이 든다(M29):

```python
class TrustInCacheKey(unittest.TestCase):   # I1
    def test_confirm_changes_the_key(self):
        before = {"PR": [], cs.TRUST: [{"끝": "a" * 40, "까닭": "씀", "때": "2026-11-20 10:00 +0900", "세션": "s"}]}
        after = {"PR": [], cs.TRUST: [{"끝": "a" * 40, "까닭": "확인", "때": "2026-11-20 10:05 +0900", "세션": "s"}]}
        targets = [("r.md", "b")]
        self.assertNotEqual(CP.pr_cache_prints(targets, lambda p: (before, None)),
                            CP.pr_cache_prints(targets, lambda p: (after, None)))
        self.assertEqual(CP.pr_cache_prints(targets, lambda p: (before, None)),
                         CP.pr_cache_prints(targets, lambda p: (dict(before), None)))   # 같은 재료면 같다
```

(기계 상태 사전의 꼴은 그 파일의 `pr_cache_fingerprint` 테스트가 쓰는 꼴에 맞춘다.) `tests/test_team_layout.py` 의 `test_leader_ref_is_the_default_branch_in_this_epic` 옆에 `self.assertEqual(L.leader_ref("refs/remotes/origin/HEAD", "b" * 40), "b" * 40)` 한 줄. `tests/test_conductor_state_branch_docs.py` 의 `test_leader_ref_still_answers_with_what_it_was_given` 에 같은 한 줄. `tests/test_start_bundle.sh` · `tests/test_team_stale.sh` 의 `team_layout.leader_ref = lambda ref: "refs/heads/leader-state"` 를 `lambda ref, tip=None: "refs/heads/leader-state"` 로(단언은 그대로). `tests/test_roadmap_status.sh` 의 `READERS["conductor_state"]` 집합에 `"TRUST"` 하나를 더한다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_control_plane.py 2>&1 | tail -3`
Expected: `RulesTip` · `Foreign` · `TrustInCacheKey` FAIL

- [ ] **Step 3: 구현한다**

- `team_layout.leader_ref` — `return state_tip or default_ref`. 문서 문자열에 「상태 브랜치의 끝은 `team_status.rules_tip` 이 계산해 넘긴다」.
- `team_status.foreign_commits` — M4 의 두 걸음. 확인 끝이 있으면 먼저 `git.commit(base)` 로 이 레포에 있는지 보고 없으면 `None`. ① `git.run_err("log", "--format=%H %P", rng)` — 줄마다 첫 칸이 커밋, 나머지가 부모. `씀` 에 없고 부모가 둘 이상인 커밋이 있으면 `None`. ② `git.run_err("log", "--no-renames", "--format=%H", "--name-only", rng, "--", *paths)` — 40자 해시와 `fullmatch` 되는 줄이 새 묶음을 열고, 빈 줄은 건너뛰며, 그 밖의 줄은 그 묶음의 경로다. `씀` 에 든 커밋을 빼고 출력을 뒤집어 오래된 차례로. rc ≠ 0 이면 `None`. `rng` 는 확인 끝이 있으면 `"%s..%s" % (base, tip)`, 없으면 `tip`.
- `team_status.rules_tip` — `branch_tip.tip(git.cwd, team_layout.STATE_BRANCH_PREFIX + team.name)`(`TipError` 면 `(None, ["상태 브랜치가 갈라져 규칙은 기본 브랜치의 글을 읽는다 — <사유>"])`) → 끝이 없으면 `(None, [])` → `git.blob(tip, team.rules)` 가 `None` 이면 `(None, [])` → `foreign_commits(git, tip, trust_of(rows), rules_paths(team))`.
- `roadmap_status` — `read_pr_cache` 의 앞부분(경로를 풀고 읽어 `parse_machine` 까지)을 `read_machine` 으로 가르고 `read_pr_cache` 는 그 위에서 같은 셋을 낸다. team 로드맵이면 `Reader` 를 만들 때 `lead_tip=team_status.rules_tip(git, team, state_branch_on(settings) and not resolved["errors"], data[TRUST] if data is not None else None)[0]` — `settings` · `resolved` 는 그 함수가 1257행 근처에서 이미 만든 값이고, `state_branch_on` 은 `from repo_defaults import …` 에, `TRUST` 는 `from conductor_state import …` 에 이름으로 더한다. 알림은 상태 계산에 싣지 않는다(`sync` · `show` · 시작 묶음이 낸다).
- `start_bundle.open_base` — `team_rules.open_team` 은 설정 오류가 있으면 이미 멈추므로(검사 불가 3 — `team_rules.py:275`) `on = repo_defaults.state_branch_on(opened.values)`. 기계 상태를 `conductor_state.load(machine_path(state_root(...), roadmap))` 로 읽고(읽지 못하면 `rows=None`) `tip, notes = team_status.rules_tip(git, opened.team, on, rows)` → `rules_commit = git.commit(team_layout.leader_ref(DEFAULT_REF, tip))`. `notes` 는 묶음의 `알림:` 줄로 낸다(`Base` 에 `notices` 칸을 더해 `_leader_bundle` · `_job_bundle` 의 `emit` 에 넘긴다).
- `control_plane` — M29.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_control_plane.py plugins/spec-distill/tests/test_team_layout.py plugins/spec-distill/tests/test_conductor_state_branch_docs.py 2>&1 | tail -1; for t in test_start_bundle test_team_stale test_roadmap_status test_team_status test_team_tasks test_control_plane; do bash plugins/spec-distill/tests/$t.sh | tail -1; done`
Expected: `OK` · 실패 0 여섯

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/team_layout.py plugins/spec-distill/scripts/team_status.py plugins/spec-distill/scripts/roadmap_status.py plugins/spec-distill/scripts/start_bundle.py plugins/spec-distill/scripts/control_plane.py plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_control_plane.py plugins/spec-distill/tests/test_team_layout.py plugins/spec-distill/tests/test_start_bundle.sh plugins/spec-distill/tests/test_team_stale.sh plugins/spec-distill/tests/test_roadmap_status.sh plugins/spec-distill/tests/test_conductor_state_branch_docs.py
git commit -m "feat(spec-distill): 확인된 상태 브랜치에 규칙 사본이 있으면 그 끝에서 규칙을 읽는다"
```

---

### Task 4: `rules_at`

**AC:** AC15(「시작 묶음은 규칙 글을 그 커밋에서 싣고 「맞추는 명령」 줄에 `rules_at` 을 싣는다 · `job sync` 가 적는다 · 「묶음 낡음」 은 규칙을 `rules_at` 에서 · 없으면 `bundle_at` · 리더가 규칙을 고친 것만으로는 그 뒤에 받은 묶음의 결과에 「묶음 낡음」 이 뜨지 않는다」). M10 의 H1 은 사용자 확인 대기 — (가) 로 썼다.

**Files:**
- Modify: `scripts/start_bundle.py`(`sync_line` · `_job_bundle`) · `scripts/team_write.py`(`SYNC_HEAD_KEYS` · `_new_head` · `_swap_head` · `cmd_job_sync`) · `scripts/roadmap_write.py`(`job sync` 의 `--rules-at` 인자 · 사용법 글) · `scripts/team_files.py`(`Result.rules_at`) · `scripts/team_status.py`(`stale`)
- Test: `tests/test_team_sync.sh` · `tests/test_team_results.py` · `tests/test_team_docs.py` · `tests/test_start_bundle.sh` · `tests/test_leader_seat_e2e.sh`(새로 · 100755)

**Interfaces:**
- Consumes: 과제 3 의 `rules_tip` · `leader_ref` · `Base.notices`.
- Produces: `start_bundle.sync_line(write: str, role: str, bundle_at: str, job_at: str, rules_at: Optional[str] = None) -> str` — `rules_at` 이 있으면 끝에 ` --rules-at <감싼 값>` · 없으면 지금 글 그대로 · 상수 `RULES_AT_TAIL = " --rules-at %s"` · `team_files.Result.rules_at: Optional[str]` · `job sync --rules-at <커밋>`.

R2 의 사람 줄 관문과 만나는 자리: 시작 묶음의 관문(`human_lines.missing` → 멈춤 1)은 「맞추는 명령」 줄을 짓기 전에 서므로 이 고침이 닿지 않는다. 결과 대조(`job_results.py check`)는 고치지 않는다(M11).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_team_results.py` 에:

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

`tests/test_team_docs.py` 의 356행 단언(인자 넷 — 그대로 선다) 바로 뒤에:

```python
        self.assertEqual(SB.sync_line("a b", "worker", "x", "y", "z"),
                         SB.sync_line("a b", "worker", "x", "y") + " --rules-at z")   # B1 — 넷인 부름은 그대로 · 다섯째는 끝에만
```

`tests/test_start_bundle.sh` 의 400행 근처(인자 넷 · 낱말 수 8 단언 — 그대로 선다) 뒤에 같은 꼴로 인자 다섯 부름(`"my dir/it's.md", "worker", "abc", "def", "ghi"`)의 낱말 수가 10 이고 끝 두 낱말이 `--rules-at ghi` 라는 단언 하나.

`tests/test_team_sync.sh` 에 행 넷:

| 이름 | 하는 것 | 단언 | 붉어지는 변이 |
|---|---|---|---|
| 새 머리의 `rules_at` | 결과 파일이 없을 때 `--role worker --bundle-at $B --job-at $J --rules-at $RA` | 머리가 `… bundle_at: $B\nrules_at: $RA\njob_at: $J` 차례 | `SYNC_HEAD_KEYS` 에서 빼거나 자리를 옮긴다 |
| 없이 만든 머리 | 지금 48행의 단언 | 바이트 그대로 | `rules_at` 을 늘 쓴다 |
| 이어 쓰는 파일 | 끝 줄 없는 파일(`rules_at` 없음)에 셋 함께 | `rules_at` 줄이 `bundle_at` 줄 바로 뒤에 하나 · 다른 줄은 바이트 그대로 | 끝에 붙인다 · 둘째 줄을 만든다 |
| 홀로 준 `--rules-at` | `--rules-at $RA` 만 | rc 2 · 파일 바이트 그대로 | 함께 주기 검사를 지운다 |

`tests/test_leader_seat_e2e.sh`(새로) — `ROOT` · `T` 를 정하고 `shared/tests/assert.sh` 와 `tests/fixtures/team_repo.sh` 를 source 한 뒤 `new_repo "$T/a"` 로 세운다. 도우미 `cb() { (cd "$W" && python3 "$S/conductor_branch.py" --root "$W" "$@") > "$T/cb.txt" 2>&1; echo $?; }`. 걸음:

1. `cb ensure --roadmap "$RM" --session "$SID"` → 0.
2. 사본이 없을 때 `bundle --roadmap "$RM" --job E1 --stage implement --plan 1` → 0 · 「맞추는 명령」 줄에 `--rules-at` 이 **없다**(H1 (가) · AC20 쪽 양성 대조).
3. 상태 브랜치에 규칙 사본을 쓴다(과제 6 전에는 이 테스트 안의 작은 파이썬 한 줄로 `conductor_branch.write(...)` — 과제 6 이 `cb rules-add` 로 바꾼다).
4. 다시 묶음 → 규칙 머리가 `규칙 (<기준> · 팀 규칙은 <상태 끝>):` · 사본의 새 줄이 실린다 · 「맞추는 명령」 줄 끝이 `--rules-at <상태 끝>`.
5. 그 줄 그대로 `job sync` → 결과 파일 머리에 `rules_at: <상태 끝>`. 커밋 · push.
6. 사본에 줄을 하나 더 쓴다 → 상태 계산(`status`)의 E1 알림에 「묶음 낡음: implement-plan-1-1.md — 묶은 커밋 … 뒤에 바뀜: <규칙 경로>」.
7. 새 시도 묶음 → 「맞추는 명령」 의 `--rules-at` 이 새 끝 → 그 줄로 새 결과 파일 → 상태 계산에 그 파일의 「묶음 낡음」 이 **없다**(AC15 끝 문장 — 양성 대조는 6).
8. `rules_at` 없는 옛 결과 파일(`hand_result`)은 `bundle_at` 으로 견준다 — 사본이 있는 동안 「묶음 낡음」 이 뜬다.
9. 다른 클론이 쓴 `rules_at`(`0123…` — 받아 오지 않은 커밋)은 「묶음 낡음을 재지 못했다: … — 규칙을 읽은 커밋 01234567 가 이 레포에 없다」.

`git add` 전에 `chmod +x` 하고 커밋 뒤 `git ls-files -s plugins/spec-distill/tests/test_leader_seat_e2e.sh` 가 `100755` 인지 본다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_results.py plugins/spec-distill/tests/test_team_docs.py 2>&1 | tail -1; for t in test_team_sync test_start_bundle test_leader_seat_e2e; do bash plugins/spec-distill/tests/$t.sh | tail -1; done`
Expected: 새 테스트 FAIL

- [ ] **Step 3: 구현한다**

- `start_bundle` — `sync_line` 에 `rules_at=None`(있으면 `RULES_AT_TAIL % _sh_word(rules_at)` 를 붙인다). `_job_bundle` 은 `sync_line(write, role, base.commit, commit, base.rules_commit if base.rules_commit != base.commit else None)`. `SYNC_LINE` 상수는 그대로.
- `team_write` — `SYNC_HEAD_KEYS` 를 `(…, "bundle_at", "rules_at", "job_at")`, `_new_head(parsed, role, bundle_at, job_at, rules_at=None)`(값이 `None` 인 키는 지금처럼 쓰지 않는다). `cmd_job_sync` — `--rules-at` 도 `_commit_flag` 를 거치고, `--bundle-at` · `--job-at` 없이 오면 `W.Usage`. 이어 쓰는 파일에 셋을 함께 주면 `_swap_head(…, "rules_at", insert_after="bundle_at")` — 키 줄이 없으면 `insert_after` 줄 바로 뒤에 넣는다.
- `roadmap_write` — `job sync` 하위 파서에 `--rules-at`, 사용법 줄에 ` [--rules-at <커밋>]`.
- `team_files.parse_result` — `rules_at` 이 머리에 있으면 커밋 꼴(아니면 `"머리 rules_at 가 커밋 번호 꼴이 아니다: %r"`), `r.rules_at = _commit(meta, "rules_at")`.
- `team_status.stale` — `rules_from = self.git.commit(result.rules_at) if result.rules_at else at`(없는 커밋이면 M12 의 「재지 못했다」 를 내고 다음 파일). 규칙 파일의 그때 글은 `rules_from` 에서, 나머지 둘은 지금처럼 `at` 에서.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_team_results.py plugins/spec-distill/tests/test_team_docs.py 2>&1 | tail -1; for t in test_team_sync test_start_bundle test_team_stale test_job_results test_leader_seat_e2e test_team_status; do bash plugins/spec-distill/tests/$t.sh | tail -1; done`
Expected: `OK` · 실패 0 여섯(형식 정본의 머리 키 목록을 짚는 문서 락이 붉으면 과제 18 의 문서 고침을 이 과제로 당겨 온다 — 락을 느슨하게 하지 않는다)

- [ ] **Step 5: 커밋**

```bash
chmod +x plugins/spec-distill/tests/test_leader_seat_e2e.sh
git add plugins/spec-distill/scripts/start_bundle.py plugins/spec-distill/scripts/team_write.py plugins/spec-distill/scripts/roadmap_write.py plugins/spec-distill/scripts/team_files.py plugins/spec-distill/scripts/team_status.py plugins/spec-distill/tests/test_team_sync.sh plugins/spec-distill/tests/test_team_results.py plugins/spec-distill/tests/test_team_docs.py plugins/spec-distill/tests/test_start_bundle.sh plugins/spec-distill/tests/test_leader_seat_e2e.sh
git commit -m "feat(spec-distill): 상태 브랜치에서 규칙을 읽은 묶음은 rules_at 을 싣고 묶음 낡음은 그 커밋에서 견준다"
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
Expected: 실패 0 넷(R1 의 「겹쳐 있는 단언 셋」 이 붉으면 그 셋이 implement 단계인지 본다 — implement 면 거르기가 틀린 것이다)

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/team_status.py plugins/spec-distill/tests/test_team_stale.sh
git commit -m "fix(spec-distill): 구현 밖 단계의 읽지 못한 결과 파일을 묶음 낡음을 재지 못했다로 알린다"
```

---

### Task 6: 규칙 사본 고침 — `rules-add` · `rules-drop` · `rules-reset`

**AC:** AC17(「규칙 사본은 리더가 규칙을 처음 고칠 때 생기고」) · AC21(남의 고침이 있으면 고치지 않는다). M36 의 H2 는 사용자 확인 대기 — (가) 로 썼다.

**Files:**
- Create: `scripts/leader_seat.py`
- Modify: `scripts/conductor_branch.py`(`main` 에 하위 명령 — 함수 안에서 `leader_seat` 를 가져온다 · 파일 끝 진입은 과제 2)
- Test: `tests/test_leader_seat.py` · `tests/test_leader_seat_e2e.sh`(걸음 3 을 `cb rules-add` 로)

**Interfaces:**
- Consumes: 과제 2 · 3.
- Produces:
  - `leader_seat.RULES_BASE_FILE`(= `team_status.RULES_BASE_FILE`) · `leader_seat.BASE_HEAD = "기본 브랜치 커밋: "`
  - `leader_seat.foreign(root, roadmap_rel: str, tip: str, paths: list) -> Optional[list]` — 기계 상태를 읽어(`cs.load` · 못 읽으면 `None`) `team_status.foreign_commits(RS.Git(root), tip, team_status.trust_of(rows), paths)`.
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

    def test_command_line_keeps_the_codes(self):   # B2 — 명령줄의 종료 코드와 마지막 줄
        rc, out = self.ls("rules-add", "--roadmap", rm(ALPHA), "--session", SID, "--line", "- 태그 없는 줄")
        self.assertEqual(rc, 2, out)
        rc, out = self.ls("rules-add", "--roadmap", rm(ALPHA), "--session", OTHER, "--line", NEW)
        self.assertEqual(rc, 5, out)
        rc, out = self.ls("rules-add", "--roadmap", rm(ALPHA), "--session", SID, "--line", NEW)
        self.assertEqual(rc, 0, out)
```

실제 남의 커밋으로 `rules_edit` 가 거절되는 것과 `rules-reset` 이 남의 고침을 물리는 것은 과제 8 의 `Confirm` 이 잰다(I10 · M36). 붉어지는 변이: 사본을 빈 글에서 만든다(첫째) · `rules-base.md` 를 쓰지 않는다(첫째) · `reset` 이 하나만 지운다(둘째) · `parse_rules` 검사를 지운다(셋째의 첫 입력) · 파일 끝 진입을 옛 꼴로 되돌린다(넷째 — 2 · 5 가 3 이 된다).

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_leader_seat.py 2>&1 | tail -3`
Expected: `RulesEdit` FAIL(`leader_seat` 가 없다)

- [ ] **Step 3: `leader_seat.py` 와 하위 명령을 쓴다**

- 머리 문서 문자열: 맡는 일(리더가 쓰는 자리 — 규칙 사본 · 규칙 브랜치 · 남의 고침 확인 · 대기 줄) · 가져오는 모듈(`conductor_branch` · `conductor_state` · `team_status` · `team_rules` · `roadmap_model` · `roadmap_status`(`Git` 만) · `human_lines` · `repo_defaults`) · 종료 코드.
- `rules_edit` — 차례: `CB._need_marker` → `CB.availability`(사유면 `Result(None, False, None, (사유,))`) → 로드맵 머리말이 team 형식인지(아니면 `BranchError(2, "team 형식 로드맵이 아니다 …")`) → 줄 검사(`team_rules.parse_rules(line + "\n")` 가 규칙 하나를 내고 그 `problems` 가 비어야 한다) → `add` · `drop` 이면 읽을 끝(`CB.seen_tip`)에서 `foreign(…, team_status.rules_paths(team))` 가 비어 있지 않으면 `BranchError(1, "확인되지 않은 남의 고침 %d — confirm 으로 확인받거나 rules-reset 으로 물린다")`, `None` 이면 같은 꼴에 「남의 고침을 재지 못했다」. 그 뒤 `CB.write(…, edit, "규칙 <더함|뺌|되돌림>")` — `edit(base)` 는 사본이 있으면 그 줄들, 없으면 기본 브랜치 끝(`repo_defaults.default_branch`)의 규칙 글 줄들에 고침을 적용하고, 사본이 없었으면 `rules-base.md` 도 함께 낸다. 줄 대조는 `==`. 더할 줄이 이미 있거나 뺄 줄이 없으면 `edit` 안에서 `BranchError(2)`.
- `rules_edit(reset=True)` — M36: 남의 고침 검사를 하지 않고 사본과 `rules-base.md` 를 지운다(`{team.rules: None, base: None}` — 둘 다 없으면 「되돌릴 사본이 없다」 0). 쓴 뒤 읽을 끝에서 규칙 쪽 판정이 비어 있지 않았던 경우, 대기 줄 쪽 판정(`foreign(…, team_status.pending_paths(team))`)이 `[]` 이면 `확인한 끝` 을 `확인 · <새 끝>` 한 줄로 두고 「남의 규칙 고침을 물렸다 — 규칙은 기본 브랜치의 글로 돌아갔다」 를, 아니면 「대기 줄의 남의 고침은 남아 있다 — confirm 하거나 지운다」 를 낸다.
- `conductor_branch.main` — 하위 파서 셋(`rules-branch` · `confirm` 은 과제 7 · 8 이 더한다). 함수 안에서 `import leader_seat as LS`. 과제 2 의 파일 끝 진입 덕에 `LS` 가 던진 `BranchError` 가 `main` 의 `except BranchError` 에 걸린다. `BranchError` 의 글은 줄을 자르지 않고 모두 낸다(계획 1 의 `delete` 보고와 같은 꼴).
- `test_leader_seat_e2e.sh` 걸음 3 을 `cb rules-add --roadmap "$RM" --session "$SID" --line "<규칙 줄>"` 로 바꾼다.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_conductor_branch.py plugins/spec-distill/tests/test_team_layout.py 2>&1 | tail -1; bash plugins/spec-distill/tests/test_leader_seat_e2e.sh | tail -1`
Expected: `OK` · 실패 0(`test_team_layout.py` 가 `leader_seat.py` 에 `RULES.md` 글자가 없는지 본다 — `Team.rules` 를 쓴다)

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
- Test: `tests/test_leader_seat.py` · `tests/test_leader_seat_e2e.sh`

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
        self.assertEqual(self.g("show", "%s:%s" % (commit, self.team.rules)), TEAM_RULE + "\n" + NEW)
        self.assertEqual(self.snap(), before)   # 작업 폴더를 건드리지 않는다

    def test_diverged_default_refuses_with_the_difference(self):   # 1 · 브랜치를 만들지 않는다
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)
        self.put({self.team.rules: "- [다른] 다른 손 · 조건: 역할=worker · 출처: a · 확인: b\n"})
        self.assertEqual(LS.rules_state(str(self.w), rm(ALPHA), self.tip()).verdict, "갈라짐")
        rc, out = self.ls("rules-branch", "--roadmap", rm(ALPHA), "--session", SID, "--branch", "chore/alpha-rules")
        self.assertEqual(rc, 1, out)
        self.assertIn(LS.DIVERGED, out)
        self.assertIn("다른 손", out)
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

`sync` 를 거치는 행은 `tests/test_leader_seat_e2e.sh` 에 둔다(과제 3 의 픽스처 설명):

| 이름 | 하는 것 | 단언 | 붉어지는 변이 |
|---|---|---|---|
| 같아지면 지운다 | `cb rules-add` 뒤 기본 브랜치에 그 글을 커밋 · push(PR 머지 흉내) → `conductor_status.py sync` | 읽을 끝에 사본 · `rules-base.md` 가 없다 · STATUS 「안 올린 규칙 고침」 이 `0줄` | `sync` 의 지우기 갈래를 지운다 |
| STATUS 가 같아도 지운다(S5) | 위와 같되 직전에 `sync` 를 한 번 더 돌려 STATUS 가 이미 `0줄` 아닌 같은 글인 상태에서 머지 흉내 → `sync` | 사본이 지워졌다 · 출력에 `달라진 것이 없다` 가 없다 | 조기 반환 조건에서 「지울 사본」 을 뺀다 |
| 남의 고침이면 지우지 않는다(S6) | 둘째 클론이 사본을 기본 브랜치 글과 같게 고쳐 올린다 → 받아 온 뒤 `sync` | 사본이 남아 있다 · 출력에 `확인되지 않은 남의 고침 1` | 지우기 조건에서 남의 고침 검사를 뺀다 |
| 올릴 것이면 남긴다 | 사본만 → `sync` | 사본이 있다 · STATUS 가 `1줄` | 지우기 조건을 `!=` 로 |
| 갈라지면 알린다 | 사본 뒤 기본 브랜치를 다른 글로 → `sync` | 출력에 `규칙 사본이 기본 브랜치와 갈라졌다` 로 시작하는 줄 · 사본은 남는다 | 알림을 지운다 |

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_leader_seat.py 2>&1 | tail -3; bash plugins/spec-distill/tests/test_leader_seat_e2e.sh | tail -3`
Expected: 새 테스트 FAIL

- [ ] **Step 3: 구현한다**

- `rules_state` — 사본(`CB.read(tip, team.rules)`) · `rules-base.md` 의 커밋(한 줄이 `BASE_HEAD + 40자` 와 `fullmatch` 될 때만) · 기본 브랜치 지금 글. M8 의 표대로 `verdict`.
- `rules_branch` — 표지 → availability → 이름 검사(`team_layout.STATE_BRANCH_PREFIX` 로 시작하면 2 · `CB.branch_rule(root)` 이 `"규칙"` 이면 그 정규식의 `match` 가 받아야 한다 · 읽지 못하면 3) → 규칙 쪽 남의 고침(1 · `None` 도 1) → `rules_state` 가 `"없음"`/`"같음"` 이면 `NOTHING` 1 · `"갈라짐"` 이면 `difflib.unified_diff(지금 글, 사본)` 를 `visible` 을 거쳐 줄마다 `│ ` 를 붙여 `DIVERGED` 아래에 싣고 1 → `CB._build_commit(root, <기본 브랜치 끝>, {team.rules: 사본}, "chore(conductor): 규칙 고침을 올린다 · 세션 <8자>", False)` → `CB.git(root, "update-ref", "refs/heads/" + branch, commit, CB.ZERO_OID)` 가 실패하면 3.
- `conductor_status.sync` — `rules_state` 가 `"같음"` 이고 규칙 쪽 판정이 `[]` 이면 쓰는 `edit` 가 STATUS 와 함께 `{team.rules: None, base: None}` 를 낸다. 그때는 「달라진 것이 없다」 조기 반환을 타지 않는다(S5). `"갈라짐"` 이면 `notes` 에 `DIVERGED + " — conductor_branch.py rules-branch 는 만들지 않는다"`. STATUS 의 줄 수는 지운 뒤의 끝에서 센다.
- `conductor_branch.main` — `rules-branch` 하위 명령.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_conductor_status.py plugins/spec-distill/tests/test_conductor_branch.py 2>&1 | tail -1; bash plugins/spec-distill/tests/test_leader_seat_e2e.sh | tail -1`
Expected: `OK` · 실패 0

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/leader_seat.py plugins/spec-distill/scripts/conductor_branch.py plugins/spec-distill/scripts/conductor_status.py plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_leader_seat_e2e.sh
git commit -m "feat(spec-distill): 규칙 고침을 올리는 작은 브랜치를 만들고 머지된 사본은 sync 가 지운다"
```

---

### Task 8: 남의 고침 확인 — `confirm` · 기준 끝 옮기기 · `sync` 와 `show` 의 알림

**AC:** AC21(「`sync` 와 `show` 가 「확인되지 않은 남의 고침 n」 을 알린다 · 확인한 끝은 기계 상태에 남고 · 확인한 뒤에는 그 내용을 쓴다」).

**Files:**
- Modify: `scripts/leader_seat.py`(`confirm` · `settle`) · `scripts/conductor_branch.py`(`main` 의 `confirm` · `delete` 가 `확인한 끝` 을 비운다 — M35) · `scripts/conductor_status.py`(`sync` · `cross_view` · `render_view`)
- Test: `tests/test_leader_seat.py` · `tests/test_conductor_cross.py` · `tests/test_conductor_branch.py` · `tests/test_leader_seat_e2e.sh`

**Interfaces:**
- Produces:
  - `leader_seat.FOREIGN = "확인되지 않은 남의 고침 %d"` · `leader_seat.CONFIRM_TIP = "확인할 끝: %s"`
  - `leader_seat.confirm(root, roadmap_rel: str, session: str, confirmed: Optional[str] = None) -> tuple`(`(확인한 끝, 알림들)` — M6)
  - `leader_seat.settle(root, roadmap_rel: str, session: str, tip: str) -> Optional[int]`(두 쪽 남의 고침 수의 합 · 0 이면 절을 줄였다 · 재지 못하면 `None` — M5)
  - `conductor_status.cross_view(...)["foreign"]`: `int | None`(내 로드맵) — `show` 는 닫힘 안의 `team_status.foreign_commits` · `trust_of` 로 계산하고 `leader_seat` 를 가져오지 않는다(쓰기 모듈과 엉키지 않게)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_leader_seat.py` 에 — 실제 둘째 클론의 남의 커밋으로:

```python
class Confirm(TeamRepo):   # R3 AC21 · Review Focus 1 · I4 · I10 · M36
    def test_report_then_confirm_with_the_shown_tip(self):
        self.foreign_edit()
        rc, out = self.ls("confirm", "--roadmap", rm(ALPHA), "--session", SID)   # 명령줄 — 보고가 잘리지 않는다(B2)
        self.assertEqual(rc, 1, out)
        self.assertIn("[남] other", out)
        tip = out.strip().splitlines()[-1].rsplit(LS.CONFIRM_TIP % "", 1)[1].strip()
        self.assertEqual(tip, self.tip())
        self.assertEqual(self.ls("confirm", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", tip[:8])[0], 2)   # I4
        rc, out = self.ls("confirm", "--roadmap", rm(ALPHA), "--session", SID, "--confirmed", tip)
        self.assertEqual(rc, 0, out)
        self.assertEqual([(r["끝"], r["까닭"]) for r in self.rows()], [(tip, "확인")])
        self.assertEqual(TS.rules_tip(RS.Git(str(self.w)), self.team, True, self.rows())[0], tip)   # 확인한 뒤에는 그 내용

    def test_a_tip_that_moved_after_the_report_is_not_confirmed(self):
        self.foreign_edit("o1")
        stale = self.tip()
        self.foreign_edit("o2")   # 보인 뒤에 또 들어온 남의 고침
        with self.assertRaises(CB.BranchError):
            LS.confirm(str(self.w), rm(ALPHA), SID, stale)
        self.assertNotIn("확인", [r["까닭"] for r in self.rows()])

    def test_rules_edit_is_refused_by_a_real_foreign_commit(self):   # I10 — 판정 함수를 흉내 내지 않는다
        self.foreign_edit()
        before = self.tip()
        rc, out = self.ls("rules-add", "--roadmap", rm(ALPHA), "--session", SID, "--line", NEW)
        self.assertEqual(rc, 1, out)
        self.assertIn("확인되지 않은 남의 고침 1", out)
        self.assertEqual(self.tip(), before)

    def test_reset_withdraws_a_foreign_rule_edit(self):   # M36 — H2 (가)
        self.foreign_edit()
        LS.rules_edit(str(self.w), rm(ALPHA), SID, reset=True)
        self.assertIsNone(CB.read(str(self.w), self.tip(), self.team.rules))
        self.assertEqual([r["까닭"] for r in self.rows()], ["확인"])
        LS.rules_edit(str(self.w), rm(ALPHA), SID, add=NEW)   # 다시 열린다

    def test_reset_keeps_the_trust_base_when_pending_has_foreign_lines(self):
        self.foreign_edit("o1", {self.team.rules: "- [남] r\n", self.team.path(CB.PENDING_FILE): "- A1 · 지휘 기록 · 남\n"})
        LS.rules_edit(str(self.w), rm(ALPHA), SID, reset=True)
        self.assertNotIn("확인", [r["까닭"] for r in self.rows()])

    def test_remade_write_does_not_launder_a_foreign_edit(self):   # Review Focus 1 · Deferred df3f1a6d
        self.foreign_edit()
        self.write({self.team.status: "y\n"})   # 남의 끝 위에 다시 만든 내 STATUS
        self.assertEqual(LS.settle(str(self.w), rm(ALPHA), SID, self.tip()), 1)
        self.assertIsNone(TS.rules_tip(RS.Git(str(self.w)), self.team, True, self.rows())[0])

    def test_settle_compacts_when_clean(self):
        self.write({self.team.status: "y\n"})
        self.assertEqual(LS.settle(str(self.w), rm(ALPHA), SID, self.tip()), 0)
        self.assertEqual([r["까닭"] for r in self.rows()], ["확인"])

    def test_unreadable_machine_state_is_three(self):   # I11 — confirm 이 기계 상태를 읽지 못하면
        path = cs.machine_path(state_root(str(self.w)), rm(ALPHA))
        path.write_text(path.read_text(encoding="utf-8") + "\n## 확인한 끝\n\n| 끝 | 까닭 | 때 | 세션 |\n|---|---|---|---|\n| x | 씀 | - | - |\n", encoding="utf-8")
        self.assertEqual(self.ls("confirm", "--roadmap", rm(ALPHA), "--session", SID)[0], 3)
```

`tests/test_conductor_branch.py` 에 — `delete` 뒤 `확인한 끝` 절이 비었다(M35 · 붉어지는 변이: 비우기를 지운다).

`tests/test_conductor_cross.py` 에(옛 형식 `StateRepo` 로 — 남의 고침 판정은 형식을 가리지 않는다) — 둘째 클론이 `CB.team_of(…).rules` 경로를 써 올린 뒤 `show` 가 내 로드맵 줄 아래에 `확인되지 않은 남의 고침 1 — conductor_branch.py confirm` 을 내고, 0 이면 그 줄이 없다(양성 대조), 기계 상태를 못 읽으면 `남의 고침을 재지 못했다`. `tests/test_leader_seat_e2e.sh` 에 — `sync` 의 출력에 같은 글로 시작하는 줄 하나(team 레포).

붉어지는 변이: `confirm` 의 끝 대조를 지운다(둘째) · 앞 8자를 받는다(첫째의 2) · `rules_edit` 가 로컬 끝을 읽는다(셋째 — 남의 끝은 원격 추적 ref 에만 있다) · `settle` 이 남의 고침이 있어도 줄인다(여섯째) · `reset` 이 대기 줄 쪽을 보지 않고 확인 끝을 옮긴다(다섯째) · `show` 의 줄을 지운다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_conductor_cross.py plugins/spec-distill/tests/test_conductor_branch.py 2>&1 | tail -3`
Expected: 새 테스트 FAIL

- [ ] **Step 3: 구현한다**

- `confirm` — M6. 표지 → 기계 상태 읽기(실패면 3) → 읽을 끝(`CB.seen_tip` · 갈라졌으면 3) → 두 쪽 경로(`rules_paths + pending_paths`)로 `foreign`. 보고는 커밋마다 `<8자> · <CB._commit_stamp> · <경로들>` 과 경로마다 첫째 부모와의 차이(`difflib.unified_diff` · `visible` · 줄마다 `│ `), 맨 끝 줄 `CONFIRM_TIP % tip` — `BranchError(1, 보고)`. 판정 `None` 이면 확인 끝 없이 다시 세고, 그래도 `None` 이면 `git log --format=%H %P <범위>` 의 `씀` 밖 커밋 전부를 같은 꼴로(머지는 「머지 커밋 · 부모 n」 표시). 남의 고침이 0 이면 `(tip, ("확인할 남의 고침이 없다",))` 로 0. `confirmed` 는 `OID_RE.fullmatch` 40자만(아니면 2) — 지금 끝과 `==` 면 `확인한 끝` 을 `[{"끝": tip, "까닭": "확인", …}]` 로, 아니면 다시 센 보고로 1.
- `settle` — M5.
- `conductor_status.sync` — 쓴 뒤 `LS.settle(…, <쓴 뒤 읽을 끝>)` 의 값이 1 이상이면 `notes` 에 `FOREIGN % n + " — conductor_branch.py confirm 으로 차이를 보고 사용자 확인 뒤 기록한다"`, `None` 이면 「남의 고침을 재지 못했다」. 쓰지 않은 경우(달라진 것 없음)에도 센다. 꺼짐이면 세지 않는다.
- `cross_view` · `render_view` — 내 STATUS 아래에 위 한 줄(0 이면 없음). `team_status.foreign_commits(RS.Git(root), <읽을 끝>, team_status.trust_of(<기계 상태 TRUST 줄>), rules_paths + pending_paths)` 로 센다. 다른 로드맵의 것은 세지 않는다.
- `conductor_branch.main` — `confirm` 하위 명령. `delete` — 지운 뒤 `cs.load` · `TRUST` 를 비우고 `cs.save`(M35).

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_conductor_cross.py plugins/spec-distill/tests/test_conductor_status.py plugins/spec-distill/tests/test_conductor_branch.py 2>&1 | tail -1; for t in test_conductor_state_branch_e2e test_leader_seat_e2e; do bash plugins/spec-distill/tests/$t.sh | tail -1; done`
Expected: `OK` · 실패 0 둘

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/leader_seat.py plugins/spec-distill/scripts/conductor_branch.py plugins/spec-distill/scripts/conductor_status.py plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_conductor_cross.py plugins/spec-distill/tests/test_conductor_branch.py plugins/spec-distill/tests/test_leader_seat_e2e.sh
git commit -m "feat(spec-distill): 남이 올린 규칙 · 대기 줄 고침을 보이고 확인받은 끝까지만 믿는다"
```

---

### Task 9: 대기 줄 — `pending.md`

**AC:** AC16 · AC21(「`flush` 가 그 커밋이 더한 줄을 옮기지 않으며」). 설계 `## 미룸` 의 R3 행 「대기 줄에 사람 줄 종류가 하나라도 있으면 `flush` 가 …」 를 받는다(M15).

**Files:**
- Modify: `scripts/leader_seat.py`(대기 줄 함수) · `scripts/conductor_ledger.py`(`c_add` · `c_drop` · `c_pending` · `c_flush`)
- Test: `tests/test_conductor_ledger.py` · `tests/test_leader_seat.py` · `tests/test_leader_seat_e2e.sh`

**Interfaces:**
- Consumes: 과제 2 · 3 · 6 · 8.
- Produces:
  - `leader_seat.pending_on_branch(root, roadmap_rel: str) -> bool`(M14 의 「상태 브랜치 자리」)
  - `leader_seat.pending_rows(root, roadmap_rel: str) -> tuple` — `(줄들, 확인 안 된 줄들, 꼴이 틀린 줄 수)`. 줄은 `{"에픽", "절", "글"}`(기계 상태 줄과 같은 꼴). 확인 안 된 줄은 남의 고침이 더한 것(다중집합) — 대기 줄 쪽 판정이 `None` 이면 `pending.md` 의 줄 전부.
  - `leader_seat.pending_add(root, roadmap_rel: str, session: str, row: dict) -> CB.Result`
  - `leader_seat.pending_drop(root, roadmap_rel: str, session: str, rows: list) -> CB.Result`(다중집합 빼기)
  - `leader_seat.PENDING_NO_BRANCH` · `PENDING_HUMAN` · `PENDING_FOREIGN`(Global Constraints 의 고정 글자)

R2 의 사람 줄 관문과 만나는 자리: `record --human` 은 INTENT.md 에 바로 쓰고 대기 줄을 거치지 않는다(그대로). 상태 브랜치 자리에서는 `add` 가 사람 줄을 받지 않고 `flush` 가 건너뛴다(M15). `human-check` 는 과제 브랜치 끝의 결정 기록을 읽으므로 옮기기 전의 대기 줄을 보지 않는다(지금과 같다).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_conductor_ledger.py` 에(그 파일의 명령줄 도우미 꼴을 따르고, team 형식 · 상태 브랜치는 `test_leader_seat.TeamRepo` 를 가져다 쓴다 — 과제 폴더 · INTENT.md 가 필요한 `flush` 는 `test_leader_seat_e2e.sh` 가 잰다):

| 이름 | 하는 것 | 단언 | 붉어지는 변이 |
|---|---|---|---|
| 상태 브랜치에 쌓는다 | `add --section "쌓인 기록" --cells "A1 · 지휘 기록 · 가"` | 읽을 끝의 `pending.md` 가 `- A1 · 지휘 기록 · 가\n` · 기계 상태 「쌓인 기록」 은 빔 · rc 0 | `c_add` 의 갈래를 지운다 |
| 브랜치가 없으면 기계 상태 | 상태 브랜치를 만들기 전의 team 로드맵 | 기계 상태에 줄 · 출력에 `상태 브랜치가 없어 기계 상태에 쌓았다` · rc 0 | 알림을 지운다 |
| 꺼져 있으면 기계 상태 · 알림 없음 | `.devbrew.md` 에 `state_branch: 끔` | 기계 상태에 줄 · 출력이 R1 의 글 그대로(`적었다 — 쌓인 기록: …`) | `availability` 검사를 지운다 |
| 옛 형식은 기계 상태 | 옛 형식 BETA | 같은 | 형식 검사를 지운다 |
| 사람 줄은 받지 않는다 | 상태 브랜치 자리에서 글 `spec 승인 · …` | rc 2 · `pending.md` 바이트 그대로 | `is_human` 검사를 지운다 |
| 표지 아님은 5 | 다른 세션으로 `add`(상태 브랜치 자리) | rc 5(3 이 아니다 — I7) | `BranchError` → `Fail` 바꾸기를 지운다 |
| 두 자리를 함께 보인다 | 기계 상태에 한 줄(브랜치 전) · 브랜치를 만든 뒤 한 줄 → `pending --roadmap` | 두 줄이 기계 상태 줄 먼저 차례로 | 한 자리만 읽는다 |
| 남의 줄은 보이는 글자로 | 남의 커밋이 `pending.md` 에 제어 글자(`\x1b[31m`)가 든 줄을 더한다 → `pending` | 출력에 `\x1b` 글자 그대로(제어 글자가 아니다) · 그 줄 끝에 `(확인되지 않은 남의 고침)` (S7) | `visible` 을 뗀다 |
| 같은 줄 둘 | 같은 줄을 두 번 `add` | `pending.md` 에 둘(다중집합) | 이미 있는 줄을 거른다 |
| 사람 줄 지우기 | 남이 넣은 사람 줄 → `drop --section "쌓인 기록" --where 글=<그 글>` | `pending.md` 에서 빠졌다 · rc 0 (S8) | `c_drop` 의 갈래를 지운다 |

`tests/test_leader_seat_e2e.sh` 에 걸음 — 상태 브랜치 자리에서 `add` 둘(같은 줄) → `flush --epic E1 --spec <E1 과제 폴더 안 경로>` → INTENT.md 결정 기록에 그 줄이 하나 · `pending.md` 의 E1 「지휘 기록」 줄 둘이 모두 빠졌다. 브랜치를 만들기 전 기계 상태에 쌓인 사람 줄 하나 · 보통 줄 하나와, 남의 커밋으로 심은 사람 줄 하나 · 보통 줄 하나가 있을 때 `flush` → 출력에 `사람 줄이라 옮기지 않은 대기 줄 2` · `확인되지 않은 남의 고침이 더한 대기 줄 1` · 기계 상태의 사람 줄은 **남아 있고**(I6) 보통 줄만 빠졌다 · `pending.md` 의 사람 줄 · 남의 보통 줄이 남았다 · `confirm` 뒤의 `flush` 는 그 보통 줄을 옮긴다. 꺼진 설정에서 같은 걸음은 R1 의 출력 그대로(사람 줄이 섞이면 2 로 멈춤).

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py 2>&1 | tail -3; bash plugins/spec-distill/tests/test_leader_seat_e2e.sh | tail -3`
Expected: 새 행 FAIL

- [ ] **Step 3: 구현한다**

- `leader_seat` — `pending_on_branch`: `roadmap_model.frontmatter` 로 작업 폴더의 로드맵 머리말이 team 형식 · `CB.availability` 가 `None` · `CB.local_tip` 이 있음. `pending_rows`: 읽을 끝의 `pending.md` 줄 가운데 `- ` 로 시작하는 것을 ` · ` 로 두 번 갈라(`split(" · ", 2)`) 줄로. 꼴이 틀린 줄은 세어 확인 안 된 쪽에 둔다. 남의 고침 커밋마다 첫째 부모와의 차이에서 더한 줄(다중집합)을 확인 안 된 쪽으로. `pending_add` · `pending_drop` 은 `CB.write(…, edit, "대기 줄 <더함|옮김|지움>")` — `edit` 는 지금 끝의 글에 줄을 붙이거나 앞에서부터 하나씩 뺀다(`_line_edit` 의 규칙과 같다).
- `conductor_ledger` — `leader_seat` 를 부르는 자리마다 M31. 쓰기 결과의 `notes` 는 줄마다 `[spec-distill] <알림>`.
- `c_add` — `a.section == "쌓인 기록"` 이고 `LS.pending_on_branch` 면 사람 줄 검사(`HL.is_human(_bullet(글))` 이고 `_gate_on(root)` 면 `Fail(2, HUMAN_BY_ARGS % 종류)`) 뒤 `LS.pending_add`. team 형식 · availability `None` 인데 브랜치만 없으면 지금처럼 기계 상태에 쓰고 `PENDING_NO_BRANCH` 를 출력한다. 그 밖은 지금 그대로.
- `c_drop` — `a.section == "쌓인 기록"` 이고 상태 브랜치 자리면 기계 상태에서 지금처럼 지우고 `pending.md` 에서도 `--where` 의 칸이 맞는 줄을 모두 뺀다. 지운 수는 둘을 더한 것.
- `c_pending` — 상태 브랜치 자리면 기계 상태 줄 + `pending_rows` 의 줄을 지금 꼴로 낸다. `pending.md` 줄의 글은 `CB.visible` 을 거치고, 확인 안 된 줄은 끝에 `   (확인되지 않은 남의 고침)`.
- `c_flush` — M16. 상태 브랜치 자리이고 `team_intent(root, path)` 가 있으면: 옮길 줄 = 기계 상태의 그 에픽 · 「지휘 기록」 줄 + (`pending_rows` 의 줄 − 확인 안 된 줄) 가운데 그 에픽 · 「지휘 기록」, 그 가운데 사람 줄을 뺀다. `_append_decisions(root, intent, 글들)` → `write_atomic` → 기계 상태에서 **옮긴 줄만** 다중집합으로 빼기(`update`) → `LS.pending_drop(옮긴 pending 줄)`. 출력은 지금 글에 `PENDING_HUMAN` · `PENDING_FOREIGN`(0 이 아닐 때) 줄을 더한다. 그 밖(옛 형식 · 꺼짐 · 브랜치 없음 · 옛 형식 설계문서 경로)은 지금 그대로.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py plugins/spec-distill/tests/test_leader_seat.py 2>&1 | tail -1; for t in test_leader_seat_e2e test_human_record test_human_gate test_conductor_e2e; do bash plugins/spec-distill/tests/$t.sh | tail -1; done`
Expected: `OK` · 실패 0 넷

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/leader_seat.py plugins/spec-distill/scripts/conductor_ledger.py plugins/spec-distill/tests/test_conductor_ledger.py plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_leader_seat_e2e.sh
git commit -m "feat(spec-distill): team 로드맵의 대기 줄을 상태 브랜치의 pending.md 에 쌓고 확인된 줄만 옮긴다"
```

---

### Task 10: 판정 줄 규칙 하나

**AC:** AC18(판정 줄 규칙 하나). **Q1 은 사용자 확인 대기** — (가) 로 썼다. (나)면 `ruling_said` 의 본문과 아래 표의 기대값(주석이 적은 넷)만 바꾼다.

**Files:**
- Modify: `scripts/workflow_superpowers.py`(`RULING_MARK` · `ruling_said` · `ledger_lines`) · `scripts/conductor_state.py`(`ledger_rulings`) · `scripts/team_files.py`(`_MACHINE_PREFIXES` · `parse_result` 의 상수) · `scripts/team_write.py`(723행의 글자)
- Test: `tests/test_workflow_superpowers.py`

**Interfaces:**
- Produces: `workflow_superpowers.RULING_MARK = "Ruling:"` · `workflow_superpowers.ruling_said(line: str) -> Optional[str]`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_workflow_superpowers.py` 는 그 모듈을 `WS` 로 가져온다. 머리에 `import conductor_state as cs` · `import team_files as F`(없으면) · `from unittest import mock` 를 더하고:

```python
class OneRulingRule(unittest.TestCase):   # R3 AC18 — 판정 줄 규칙 하나(Q1 = 가)
    CASES = (("- Ruling: 가", "가"), ("Ruling: 나", "나"), ("Task 3: Ruling: 다", "다"),
             ("- **Ruling: 라**", "라**"), ("- parked — x — Ruling: 마", "마"),
             ("원장의 `Ruling:` 줄을 읽는다", "` 줄을 읽는다"), ("판정 없음", None), ("Ruling:", None))
    # (나)면 넷째 · 다섯째 · 여섯째 기대값이 None 이고 넷째의 꼴(굵게)을 받기로 하면 "라" 다. 첫째 · 둘째 · 셋째 · 일곱째 · 여덟째는 그대로다.

    def test_the_rule(self):
        for line, said in self.CASES:
            self.assertEqual(WS.ruling_said(line), said, line)

    def test_every_ledger_reader_uses_the_rule(self):   # 붉어지는 변이: 둘 가운데 하나가 자기 규칙으로 돌아간다
        text = "\n".join(line for line, _said in self.CASES)
        picked = [l for l, s in self.CASES if s is not None]
        self.assertEqual(cs.ledger_rulings(text), [l.strip() for l in picked])
        self.assertEqual(WS.ledger_lines(text, 3), ["Ruling: " + s for _l, s in self.CASES if s is not None])
        with mock.patch.object(WS, "ruling_said", return_value=None):   # 함수를 바꾸면 둘의 답이 함께 바뀐다
            self.assertEqual((cs.ledger_rulings(text), WS.ledger_lines(text, 3)), ([], []))

    def test_result_file_grammar_is_unchanged(self):   # 결과 파일 기계 줄은 줄 머리 — 형식 정본의 계약 · 빈 판정 줄도 지금처럼 판정
        r = F.parse_result("---\ntype: job-result\nstage: plan\nattempt: 1\nrole: worker\nhead: %s\nbundle_at: %s\njob_at: %s\n---\n\nRuling: 가\nRuling:\n메모 — Ruling: 나\n" % (("a" * 40,) * 3))
        self.assertEqual(r.rulings, ["Ruling: 가", "Ruling:"])

    def test_the_mark_lives_in_one_place(self):   # S1 — 「한 곳」 락. 붉어지는 변이: 다른 스크립트에 "Ruling:" 글자를 둔다
        hits = sorted(p.name for p in SCRIPTS.glob("*.py") if '"Ruling:"' in p.read_text(encoding="utf-8"))
        self.assertEqual(hits, ["workflow_superpowers.py"])
```

(`SCRIPTS` 는 그 파일이 쓰는 스크립트 폴더 경로 이름 — 없으면 머리에 둔다.)

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_workflow_superpowers.py 2>&1 | tail -3`
Expected: `OneRulingRule` FAIL(`ruling_said` 가 없다)

- [ ] **Step 3: 구현한다**

- `workflow_superpowers.ruling_said` — (가): `line` 에 `RULING_MARK` 가 있으면 첫 그것 뒤의 글을 `strip` 해 비지 않으면 그것, 아니면 `None`. `ledger_lines` 는 `_unbullet(raw)` 에 그 함수를 쓴다.
- `conductor_state.ledger_rulings` — `[l.strip() for l in text.splitlines() if workflow_superpowers.ruling_said(l) is not None]`. 맨 위에서 `import workflow_superpowers`(그 모듈은 `conductor_state` 를 가져오지 않는다 — `python3 -c 'import sys; sys.path.insert(0, "plugins/spec-distill/scripts"); import conductor_state'` 로 본다). 바뀌는 출력은 하나 — `Ruling:` 뒤가 빈 줄을 더는 내지 않는다(Q1 표).
- `team_files` — `_MACHINE_PREFIXES` 와 `parse_result` 의 `startswith("Ruling:")` 를 `RULING_MARK` 로(판정은 그대로 줄 머리 · 빈 판정 줄도 지금처럼 판정).
- `team_write.py` 723행 — `("Ruling", "Ruling:")` 를 `("Ruling", workflow_superpowers.RULING_MARK)` 로.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_workflow_superpowers.py plugins/spec-distill/tests/test_conductor_state.py plugins/spec-distill/tests/test_team_results.py plugins/spec-distill/tests/test_control_plane.py 2>&1 | tail -1; for t in test_roadmap_status test_team_sync test_conductor_e2e; do bash plugins/spec-distill/tests/$t.sh | tail -1; done`
Expected: `OK` · 실패 0 셋

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/workflow_superpowers.py plugins/spec-distill/scripts/conductor_state.py plugins/spec-distill/scripts/team_files.py plugins/spec-distill/scripts/team_write.py plugins/spec-distill/tests/test_workflow_superpowers.py
git commit -m "refactor(spec-distill): 판정 줄을 가려내는 규칙을 변환기의 함수 하나에 둔다"
```

---

### Task 11: 현황 수리 — 「예약 밖 변경」 줄임 · 판정 없음 문구 · 단계 표 락 · 글 출력의 로드맵 밖 과제 · 과제 폴더 없는 작업

**AC:** AC18(과제 폴더 없는 작업 알림 · 리뷰 지적 넷). **Q2 · M22 는 사용자 확인 대기** — 다섯 · (라) 로 썼다.

**Files:**
- Modify: `scripts/roadmap_status.py`(`reserve_notes` · `render` · 상수 `RESERVE_OUTSIDE_MAX = 5`) · `scripts/control_plane.py`(판정 없음 문구 네 자리 · `works_lines`)
- Test: `tests/test_control_plane.py` · `tests/test_team_status.sh` · `tests/test_team_tasks.sh` · `tests/test_roadmap_status.sh`

**Interfaces:**
- Produces: `roadmap_status.outside_line(paths: list) -> str` · team 보고의 블록 칸 `job_folder: true | false | null` · `control_plane.NO_JOB_FOLDER = "과제 폴더 없음"`(`works_lines(report)` 의 꼴은 그대로).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`tests/test_control_plane.py` 에:

```python
class StageTableLock(unittest.TestCase):   # R3 AC18 — BUCKETS 와 TASK_STATUS(이빨은 과제 19 의 변이 13)
    def test_every_stage_has_one_place(self):
        bucketed = {s for _name, stages in CP.BUCKETS for s in stages}
        self.assertEqual(bucketed | set(CP.UNCOUNTED), set(RS.TASK_STATUS) | {"알 수 없음"})
        self.assertEqual(bucketed & set(CP.UNCOUNTED), set())   # 같은 단계가 묶음과 「세지 않음」 에 함께 있지 않다


class TeamRulingWording(unittest.TestCase):   # R3 AC18 — team 은 결과 파일
    def b(self):
        return {"id": "E1", "title": "가", "stage": "구현 중", "reason": "-", "rulings": None, "warnings": [], "notes": []}

    def test_epic_view(self):
        team = {"layout": "team", "blocks": [self.b()]}
        old = {"blocks": [self.b()]}
        self.assertIn("결과 파일의 `Ruling:` 줄도 없다", CP.epic_view("r.md", team, "E1"))
        self.assertIn("설계문서 `## 판정` 도 없다", CP.epic_view("r.md", old, "E1"))
```

(`epic_view(path, report, epic)` 가 글 하나를 내는지 목록을 내는지는 그 파일의 기존 `epic_view` 테스트 꼴에 맞추고, 보고 사전에 그 함수가 더 요구하는 칸이 있으면 기존 테스트의 보고 꼴을 빌린다. 목록 화면 `show_text(items, interview, notes, first_line_fn)` 의 두 자리도 같은 두 단언을 그 파일의 기존 `show_text` 테스트 꼴로 하나 더.)

```python
class NoJobFolder(unittest.TestCase):   # R3 AC18 — 과제 폴더 없는 작업(M22 = 라)
    def report(self, layout):
        row = lambda kind, name, epic, stage="진행", basis="-": {"종류": kind, "이름": name, "에픽": epic, "단계": stage, "담당": "없음", "근거": basis}
        r = {"blocks": [{"id": "E1", "kind": "epic", "job_folder": True}, {"id": "E2", "kind": "epic", "job_folder": False},
                        {"id": "E3", "kind": "epic", "job_folder": None}],
             "jobs": [{"id": "fix-x"}, {"id": "tidy"}],
             "machine": {"살아 있는 agent": [], "작업": [
                 row("구현", "E1 계획 1", "E1"), row("구현", "E2 계획 1", "E2"), row("구현", "E3 계획 1", "E3"),
                 row("구현", "E9 계획 1", "E9"),                                            # 로드맵에 없는 에픽
                 row("수리", "fix-x 마무리", "로드맵 밖"),                                 # 이름 칸의 낱말
                 row("정리", "정리 일", "로드맵 밖", basis="docs/r/a/jobs/tidy/INTENT.md"),   # 근거 칸의 경로
                 row("수리", "지휘자 수리", "로드맵 밖"),                                   # 어디에도 과제가 없다
                 row("수리", "끝난 일", "로드맵 밖", stage="끝")]}}
        if layout:
            r["layout"] = layout
            r["roadmap"] = "docs/r/a/roadmap.md"
        return r

    def test_team_marks_only_rows_without_a_job(self):
        text = "\n".join(CP.works_lines(self.report("team")))
        marked = [l for l in text.splitlines() if l.endswith(" · " + CP.NO_JOB_FOLDER)]
        self.assertEqual([l.split(" — ")[0].strip() for l in marked], ["구현 E2 계획 1", "구현 E9 계획 1", "수리 지휘자 수리"])

    def test_old_format_is_unchanged(self):   # AC20
        self.assertNotIn(CP.NO_JOB_FOLDER, "\n".join(CP.works_lines(self.report(None))))
```

`job_folder` 를 실제로 계산하는 것은 `tests/test_team_tasks.sh` 에 — 과제 폴더가 있는 블록은 `--json` 보고에 `"job_folder": true`, 기본 브랜치에서 그 과제 폴더를 지운 블록은 `false` 이고, 그 블록의 작업 줄이 상태 보기에 `과제 폴더 없음` 으로 뜬다(붉어지는 변이: `job_folder` 를 늘 `true` 로 — 「블록이 보고에 있으면 있다」 는 근사). 옛 형식 보고에는 `job_folder` 칸이 없다(AC20).

`tests/test_team_status.sh` · `tests/test_team_tasks.sh` 에 — 블록 하나가 예약 밖 파일 일곱을 바꾸면 그 알림이 `예약 밖 변경: <앞 다섯 · 이름 순> 외 2개` 이고, 다섯이면 다섯 그대로. `tests/test_team_tasks.sh` 에 — team 로드맵의 글 출력(`roadmap_status.py <로드맵>`, `--json` 없이)에 `로드맵 밖 과제: 1개` 와 그 과제 줄 · `정보:` 줄이 있다. `tests/test_roadmap_status.sh` 에 — 옛 형식 로드맵의 글 출력에 `로드맵 밖 과제` 가 없다(AC20).

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_control_plane.py 2>&1 | tail -3; for t in test_team_status test_team_tasks; do bash plugins/spec-distill/tests/$t.sh | tail -3; done`
Expected: 새 테스트 FAIL(`StageTableLock` 은 지금도 통과한다 — 이빨은 변이 표)

- [ ] **Step 3: 구현한다**

- `roadmap_status.outside_line` — `RESERVE_OUTSIDE_MAX` 이하면 `" · ".join(paths)`, 넘으면 앞 그 수 뒤에 `" 외 %d개" % (len - 5)`. `reserve_notes` 가 `RESERVE_OUTSIDE % outside_line(outside)`.
- `roadmap_status.render` — `report` 에 `jobs` 키가 있을 때만 경로 예약 겹침 줄 앞에 M21 의 줄들.
- `control_plane` — 판정 없음 문구 네 자리: `report.get("layout") == "team"` 이면 「실행 원장을 읽지 못했고 결과 파일의 `Ruling:` 줄도 없다」 · 「실행 원장도 결과 파일의 `Ruling:` 줄도 없다」. `works_lines` — M22 (라). `roadmap_status` 는 team 블록의 보고 칸을 채울 때(`report["blocks"][-1].update(progress=…, job=…)` 자리) `job_folder` 를 더한다 — `src.read(team.intent(id))` 가 글을 내면 `true`, `src.absent(…)` 가 참이면 `false`, 그 밖은 `null`.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_control_plane.py 2>&1 | tail -1; for t in test_team_status test_team_tasks test_roadmap_status test_control_plane; do bash plugins/spec-distill/tests/$t.sh | tail -1; done`
Expected: `OK` · 실패 0 넷

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

### Task 13: 계획 1 이 남긴 것 — 같은 질문 다시 · 드문 경우 · 가리기 · 목록 락

**AC:** 없음(설계문서 `## 미룸` 의 R3 행 — 「같은 (에픽, 종류)」 · 「리뷰 잔여」).

**Files:**
- Modify: `scripts/conductor_status.py`(`waiting_add` · `waiting_clear` · `scrub`) · `scripts/conductor_branch.py`(`_write_floor` · `ensure` · `delete` · `_check_delete_form` · `_publish` · `looks_absolute` · `redact` · `bad_state_names`) · `scripts/conductor_mail.py`(`send` · `ack` 의 차례 · `about` 판정)
- Test: `tests/test_conductor_status.py` · `tests/test_conductor_branch.py` · `tests/test_conductor_mail.py` · `tests/test_conductor_cross.py`

**Interfaces:**
- Produces: `conductor_branch.looks_absolute(token: str) -> bool` · `conductor_branch.bad_state_names(root) -> int`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

| 파일 · 이름 | 하는 것 | 단언 | 붉어지는 변이 |
|---|---|---|---|
| status · 다시 묻는 질문 창 | `waiting add --kind "계획 검토" --via "질문 창"` → 한 시간 뒤 같은 (에픽, 종류)를 같은 세션이 질문 창으로 | 줄 하나 · 언제부터가 둘째 시각 | 갈래를 지운다 |
| status · 턴 끝 위에 질문 창 | 「턴 끝」 으로 올린 줄 위에 같은 (에픽, 종류)를 「질문 창」 으로 → 같은 세션의 `sync` | 언제부터가 첫 시각 · 건 길이 질문 창 · `sync` 뒤 줄이 내려갔다(S9 · 원장 P2) | 건 길을 바꾸지 않는다 |
| status · 다른 세션의 질문 창 | 넘겨받은 세션이 같은 걸음 | 첫 시각 · 세션 칸이 새 세션 | 세션 대조를 지운다 |
| status · 모르는 종류로 내리기 | `waiting clear --kind "계획 확인"`(옛 이름) | rc 2 · 줄 그대로(I14 — 원장의 잔여) | 종류 검사를 지운다 |
| branch · 설정 오류는 0 | `.devbrew.md` 에 모르는 키 → `ensure` · `sync` · `waiting add` · `send` · `ack` · `rules-add` 명령줄 | 모두 rc 0 · 출력에 `레포 설정을 읽지 못해 상태 브랜치를 쓰지 않는다` · ref · 기계 상태 그대로 | `team_of` 를 `availability` 앞으로 되돌린다 |
| mail · 표지 먼저 | 표지 없는 세션이 꼴 틀린 `--kind` 로 `send` | rc 5(2 가 아니다) | 차례를 되돌린다 |
| branch · 지우는 꼴의 문 | `_check_delete_form` 에 lease 꼴 · lease 없는 옛 꼴 · lease 의 ref 와 지우는 ref 가 다른 꼴 | 첫째만 받는다(I8) | lease ref 대조를 지운다 |
| branch · 견준 끝에 건 지우기 | `delete --confirmed <끝>` 직전에 다른 클론이 같은 브랜치에 올린다(테스트는 `_fetch` 뒤 · push 앞을 `mock.patch.object(CB, "_git_delete", …)` 로 감싸 그 사이에 다른 클론의 **실제 push** 를 끼운다) | rc 3 · 원격 브랜치가 남아 있다 · 다른 클론의 커밋이 원격에 있다 | lease 를 뗀다 |
| branch · 손으로 만든 머지 커밋 | 로컬에 부모 둘인 커밋을 손으로 만든 뒤 거절되는 쓰기 | rc 3 · `손으로 만든 머지 커밋이 있다` · 원격 그대로 | 검사를 지운다 |
| cross · 이름 꼴이 틀린 상태 브랜치 | `refs/remotes/origin/conductor/Bad_Name` 을 둔다 → `show` | `이름 꼴이 틀린 상태 브랜치 1` | 세지 않는다 |
| status · 가리기 꼴 | `scrub("리더/담당자/일꾼 · ./a/b · /Users/x/y · ~/k/l · key=/p/q · /나의/폴더")` | `리더/담당자/일꾼 · ./a/b · <경로> · <경로> · key=<경로> · <경로>` (S4) | `looks_absolute` 의 경계 · 성분 규칙을 하나씩 좁힌다 |
| mail · `about` 의 꼴 | `--about "설계/계획/구현"` · `--about ./a/b` · `--about /tmp/a/b` | 앞 둘 rc 0 · 셋째 rc 2 | 같은 |
| branch · `DONE_STAGES` | `CB.DONE_STAGES == RS.DONE` | 같다(이빨은 변이 표) | 한쪽에 단계를 더한다 |

`tests/test_conductor_branch.py` 의 지우기 락 두 자리를 새 꼴로 고친다(I8) — 1225행 근처의 받는 꼴 목록에서 `("push", "--porcelain", "origin", ":" + ref)` 를 `("push", "--porcelain", "--force-with-lease=%s:%s" % (ref, oid), "origin", ":" + ref)` 로(옛 꼴은 거절 목록으로 옮긴다), 1257행의 닻 `body.index('"push", "--porcelain", "origin", ":"')` 를 lease 인자가 든 새 글로. 단언을 지우지 않는다.

- [ ] **Step 2: 돌려서 실패를 본다** — Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_status.py plugins/spec-distill/tests/test_conductor_branch.py plugins/spec-distill/tests/test_conductor_mail.py plugins/spec-distill/tests/test_conductor_cross.py 2>&1 | tail -3` · Expected: 새 행 FAIL

- [ ] **Step 3: 구현한다**

- `waiting_add` — M24. `waiting_clear` — `kind` 가 주어졌으면 `cs.ASK_KINDS` 안이어야 한다(아니면 `BranchError(2)`).
- 설정 오류 — `_write_floor` · `ensure` 와 `conductor_mail.send` · `ack` 가 `availability` 를 `team_of` 보다 먼저 부른다. `send` · `ack` 의 차례는 표지 → availability → 값.
- `delete` — 원격 지우기를 `push --porcelain --force-with-lease=refs/heads/conductor/<이름>:<끝> origin :refs/heads/conductor/<이름>` 로. `_check_delete_form` 이 받는 push 꼴을 그 하나로 바꾼다 — lease 의 ref 와 지우는 ref 가 같고(`==`) 끝이 40자 `fullmatch`. 다른 push 꼴의 `force` 거절(`PUSH_FORMS`)은 그대로.
- `_publish` — `_commits_between` 의 커밋마다 `cat-file commit` 의 `parent ` 줄이 둘 이상이면 `BranchError(3, "손으로 만든 머지 커밋이 있다 — 상태 브랜치는 스크립트만 쓴다: <8자>")`.
- `looks_absolute` — M26. `redact` · `scrub` · `conductor_mail` 의 `about` 판정이 이것을 부른다.
- `bad_state_names` — `state_names` 가 버린 꼬리의 수. `cross_view` 가 0 이 아니면 「다른 로드맵과 닿는 것」 묶음에 `- 이름 꼴이 틀린 상태 브랜치 <n>` 한 줄(닫힘 밖 쓰기 모듈을 더 가져오지 않는다 — `conductor_branch` 는 이미 가져온다).

- [ ] **Step 4: 돌려서 통과를 본다** — Run: Step 2 와 같은 명령 + `bash plugins/spec-distill/tests/test_conductor_state_branch_e2e.sh | tail -1` · Expected: `OK` · 실패 0

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/scripts/conductor_status.py plugins/spec-distill/scripts/conductor_branch.py plugins/spec-distill/scripts/conductor_mail.py plugins/spec-distill/tests/test_conductor_status.py plugins/spec-distill/tests/test_conductor_branch.py plugins/spec-distill/tests/test_conductor_mail.py plugins/spec-distill/tests/test_conductor_cross.py
git commit -m "fix(spec-distill): 계획 1 이 남긴 드문 경우와 다시 묻는 질문 · 가리기 꼴을 바로잡는다"
```

---

### Task 14: (건너뜀) 세 번 거절이면 종료 코드

**건너뜀 — 사용자 2026-11-20 「셋 모두 구현에 맞춘다」(U1 (가)).** 코드 그대로(1)이고 AC3 이 그 글자를 담았다. 보고에 「과제 14 건너뜀 — U1 (가)」 를 적는다.

---

### Task 15: AC22 · AC23 번호 주석

**AC:** 없음(계획 1 의 AC22 · AC23 — 계획 1 의 구현 대조가 「구현됨」 으로 셌다. 대조 목록에 넣지 않는다).

**Files:** Modify `tests/test_conductor_status.py`(두 세션 알림 테스트 셋 — 뒤에 쓴 것 · 앞에 쓴 것 · 다른 기계) · `tests/test_conductor_branch.py`(`delete` 테스트).

- [ ] **Step 1:** 그 테스트들의 `def` 줄 끝에 `# R3 AC22` · `# R3 AC23` 주석을 단다(이미 다른 AC 주석이 있으면 ` · AC22` 를 덧붙인다). 단언은 바꾸지 않는다.
- [ ] **Step 2:** Run `python3 -m unittest plugins/spec-distill/tests/test_conductor_status.py plugins/spec-distill/tests/test_conductor_branch.py 2>&1 | tail -1` → `OK`.
- [ ] **Step 3:** 커밋 `git add plugins/spec-distill/tests/test_conductor_status.py plugins/spec-distill/tests/test_conductor_branch.py && git commit -m "test(spec-distill): 두 세션 알림과 지우기 테스트에 수용 기준 번호를 단다"`.

---

### Task 16: (건너뜀) 지우기 확인 표시의 꼴

**건너뜀 — 사용자 2026-11-20(U3 (가)).** `--confirmed <수를 센 끝>` 꼴을 두고 설계 §1 의 글자를 맞췄다.

---

### Task 17: (건너뜀) 「지금 묻는 질문」 종류와 사람 줄 종류

**건너뜀 — 사용자 2026-11-20 「R2 이름에 맞춘다」(U4 (가)).** 계획 1 PR 에서 종류 이름을 여덟으로 바꿨고 별칭을 두지 않았다. 이 계획의 테스트 · 문서는 새 이름만 쓴다(Global Constraints 「종류 이름」).

---

### Task 18: 문서와 판

**AC:** AC12(걸음 5) · AC19(계획 2 몫).

**Files:**
- Modify: `references/conducting.md`(걸음 5 의 「기본값」 끝 한 문장) · `skills/epic-conductor/SKILL.md`(「5. 지휘 순환」 의 `Read` 펜스 셋째 줄 · 「두 파일의」 → 「세 파일의」) · `references/conductor-state-branch.md`(걸음 1 의 6 · 새 절 셋 · 종료 코드 표) · `references/team-files.md`(§5 · §9 · §10 · §15) · `references/roadmap-ontology.md` · `README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json` · `tests/test_repo_literals.sh`(대상에 `scripts/leader_seat.py`)
- Test: `tests/test_conductor_state_branch_docs.py` · `tests/test_team_docs.py`

- [ ] **Step 1: 문서 락을 쓴다(실패하는 테스트)**

`tests/test_conductor_state_branch_docs.py` 에:

```python
class LeaderSeatDocs(unittest.TestCase):   # R3 AC12(걸음 5) · AC19(계획 2 몫)
    def test_step_five_and_the_skill(self):
        for word in (FILE_NAME, "안 올린 규칙 고침", "conductor_branch.py rules-branch", "판 번호"):
            self.assertIn(word, step(5), word)
        self.assertNotIn("rules-branch", step(4))   # 걸음 가르기가 이웃 걸음을 잡지 않는다
        skill = (PLUGIN / "skills" / "epic-conductor" / "SKILL.md").read_text(encoding="utf-8")
        self.assertIn("Read " + POINTER, skill)

    def test_procedure_file_has_the_three_new_sections(self):
        text = NEW.read_text(encoding="utf-8")
        for head in ("## 규칙을 고칠 때", "## 남이 올린 고침을 만났을 때", "## 대기 줄"):
            self.assertIn(head, text, head)
        for word in ("conductor_branch.py rules-add", "rules-drop", "rules-reset", "conductor_branch.py confirm",
                     "확인할 끝", "40자", "pending.md", "사람 줄이라 옮기지 않은 대기 줄", "확인되지 않은 남의 고침",
                     "남의 고침을 재지 못했다"):
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

계획 1 의 `test_team_files_no_longer_says_undecided` 끝 줄(`assertIn("RULES.md 의 고침과 대기 줄은 아직 옮기지 않았다", …)` — 「계획 2 가 옮기면서 이 단언을 뒤집는다」)을 지운다(위 셋째가 뒤집은 단언을 맡는다). 계획 1 의 8.26.0 절 락은 그대로 둔다. 붉어지는 변이: 걸음 5 문장을 지운다 · SKILL 의 `Read` 줄을 지운다 · 새 절 하나를 지운다 · §15 의 옛 문장을 되살린다 · CHANGELOG 의 이 판 절에서 낱말 하나를 지운다.

- [ ] **Step 2: 돌려서 실패를 본다** — Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_state_branch_docs.py 2>&1 | tail -3` · Expected: `LeaderSeatDocs` FAIL

- [ ] **Step 3: 문서를 쓴다**

- `conducting.md` 걸음 5 「기본값」 끝: 「상태 브랜치의 「안 올린 규칙 고침」 이 있으면 PR 마다 함께 알리고 `conductor_branch.py rules-branch` 로 작은 브랜치를 만들어 지금 절차대로 PR 을 연다 — 판 번호는 `conductor_status.py show` 의 판 번호 줄을 보고 정한다(`conductor-state-branch.md`).」 루트 토큰을 쓰지 않는다.
- `conductor-state-branch.md` — 「## 맞출 때(걸음 1)」 에 6 번: 「`sync` 가 「확인되지 않은 남의 고침 n」 이나 「남의 고침을 재지 못했다」 를 내면 `confirm` 을 `--confirmed` 없이 돌려 낸 차이를 사용자에게 그대로 보이고 문장으로 묻는다 — 받아들이면 같은 명령을 `--confirmed <확인할 끝 40자>` 로, 남의 규칙 고침을 물리려면 `rules-reset`(사본을 지워 기본 브랜치의 규칙으로 돌아간다 — 내 안 올린 고침도 지워진다), 대기 줄의 남의 줄은 `drop` 으로 지운다. 확인 전에는 규칙은 기본 브랜치의 글이 실리고 그 커밋이 더한 대기 줄은 옮기지 않는다.」 새 절 셋 — `## 규칙을 고칠 때`(명령 셋 · 사본과 `rules-base.md` · 다음 시작 묶음부터 실린다 · 「배운 것」 편지는 규칙 절차를 거친 뒤에만) · `## 남이 올린 고침을 만났을 때`(위 6 의 자세한 꼴 · 「확인할 끝」 은 40자 전체 · 끝이 바뀌면 다시 · 남의 머지 커밋이면 「재지 못했다」 로 닫힌다) · `## 대기 줄`(team 형식이면 `pending.md` · 브랜치가 없으면 기계 상태 · 사람 줄은 넣지 않는다 · `flush` 의 두 알림 · 남은 사람 줄은 `drop`). 종료 코드 표의 1 행에 「확인 없는 `confirm` 이면 낸 차이를 사용자에게 보이고 묻는다 · 갈라진 `rules-branch` 면 차이를 보인다」.
- `team-files.md` — §5 머리 예시에 `rules_at: <시작 묶음이 상태 브랜치에서 팀 규칙을 읽은 커밋 — 없으면 bundle_at 으로 견준다>` · 키 설명 줄 · 「이어 쓰기」 에 `--rules-at` 은 둘과 함께만. §9 「맞추는 명령」 설명에 「규칙을 상태 브랜치에서 읽었을 때만 끝에 `--rules-at <커밋>` 이 붙는다」 · 규칙 머리 줄 설명(두 커밋). §10 「묶음 낡음」 — 규칙은 `rules_at`(없으면 `bundle_at`)에서 · 구현 밖 단계의 읽지 못한 결과 파일은 「재지 못했다」. §15 표의 「INTENT.md 결정 기록」 행 · 「리더가 쓰는 자리」 · 「지금의 값」 을 새 사실로 — 규칙은 `team_status.rules_tip` 이 계산한 상태 브랜치 끝(확인된 사본이 있을 때)에서 · 규칙 고침은 `rules-add` · `rules-drop` 과 `rules-branch` PR · 대기 줄은 `pending.md`(꺼져 있거나 브랜치가 없으면 기계 상태) · 남의 고침은 `confirm` 전까지 쓰지 않는다 · 「확인한 끝」 은 기계 상태에. `## 목차` 가 있으면 맞춘다.
- `roadmap-ontology.md` — 기계 상태 줄의 속성 칸에 「 · 확인한 끝」, 상태 브랜치 줄의 속성 칸에 「 · 규칙 사본 · 대기 줄」(객체를 더하지 않는다).
- `README.md` — 「지휘자 상태 브랜치」 절에 「리더가 쓰는 자리(team 형식)」 문단 · 「Principles Instantiated」 에 한 줄(남이 올린 고침은 사람이 확인한 끝까지만 믿는다 — Law 2 쪽).
- `CHANGELOG.md` — 새 머리 `## [<다음 minor>] — <날짜>`. Added: `leader_seat.py` · `rules-add` · `rules-drop` · `rules-reset` · `rules-branch` · `confirm` · 결과 파일 머리 `rules_at` 과 `job sync --rules-at` · 기계 상태 「확인한 끝」 절 · team 형식 대기 줄 `pending.md`. Changed: `leader_ref` 의 꼴 · 「묶음 낡음」 의 규칙 대조 · 판정 줄 규칙 하나 · 현황 수리 · 단순 작업 PR 캐시 · 현황 캐시 열쇠 · 원격 지우기의 lease. Fixed: 「묶음 낡음」 빈 곳 · 계획 1 잔여 · 명령줄 종료 코드. 「이 판 앞의 설치본은 이 판이 쓴 기계 상태를 「더 새 판이 썼다」 로 멈춘다」 한 줄.
- `plugin.json` — 판.
- `tests/test_repo_literals.sh` — `TARGETS` 에 `scripts/leader_seat.py`.

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_state_branch_docs.py plugins/spec-distill/tests/test_team_docs.py plugins/spec-distill/tests/test_roadmap_ontology.py 2>&1 | tail -1; for t in plugins/spec-distill/tests/test_repo_literals.sh plugins/spec-distill/tests/test_epic_conductor_skill.sh plugins/spec-distill/tests/test_conducting_reference.sh plugins/spec-distill/tests/test_readme_sync.sh shared/tests/test_changelog_integrity.sh shared/tests/test_no_new_duplication.sh shared/tests/test_skill_reference_pointers.sh shared/tests/test_ask_recommendation.sh shared/tests/test_shell_tests_executable.sh; do printf '%s: ' "$t"; bash "$t" | tail -1; done`
Expected: `OK` · 실패 0 아홉

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/references/conducting.md plugins/spec-distill/skills/epic-conductor/SKILL.md plugins/spec-distill/references/conductor-state-branch.md plugins/spec-distill/references/team-files.md plugins/spec-distill/references/roadmap-ontology.md plugins/spec-distill/README.md plugins/spec-distill/CHANGELOG.md plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/tests/test_repo_literals.sh plugins/spec-distill/tests/test_conductor_state_branch_docs.py plugins/spec-distill/tests/test_team_docs.py
git commit -m "docs(spec-distill): 리더가 쓰는 자리 · rules_at · 대기 줄 · 남의 고침 확인을 문서에 적고 판을 올린다"
```

---

### Task 19: 끝에서 끝 · 옛 동작 · 변이 · 닫힘 락 · 전체 스위트

**AC:** AC20(계획 2 몫) · AC14(`leader_ref` 꺼짐) · AC15 · AC16 · AC17 · AC21 의 끝에서 끝.

**Files:** Modify `tests/test_leader_seat_e2e.sh` · `tests/test_leader_seat.py` · `tests/test_conductor_state_branch_docs.py`(닫힘 락의 `NEW_MODULES` 에 `leader_seat.py` — S13).

- [ ] **Step 1: 끝에서 끝 걸음을 채운다**

`tests/test_leader_seat_e2e.sh` 에 아직 없는 걸음을 더한다 — ① `rules-add` → 묶음 → `job sync` → `rules-add` → 「묶음 낡음」 은 앞 결과에만 ② 둘째 클론(`git clone file://…`)이 상태 브랜치의 규칙 사본과 `pending.md` 를 고쳐 올린다 → 첫 클론이 받아 온 뒤 `sync` 의 「확인되지 않은 남의 고침 2」 · 묶음의 `알림: 확인되지 않은 남의 고침 1 — 규칙은 기본 브랜치의 글을 읽는다` 와 규칙 머리가 기본 브랜치 커밋 · 「맞추는 명령」 에 `--rules-at` 이 없음 · `flush` 가 그 줄을 옮기지 않음 → `confirm` 보고 → `--confirmed <끝>` → 묶음이 사본을 싣고 `flush` 가 옮긴다 ③ `rules-branch chore/<로드맵>-rules` → 그 브랜치를 기본 브랜치에 머지(테스트 안의 `git merge`) → `sync` 가 사본을 지우고 STATUS 가 `0줄` ④ `state_branch: 끔` 으로 바꾼 뒤 같은 레포에서 — 묶음의 규칙 머리가 기본 브랜치 · 「맞추는 명령」 이 R1 글 그대로(AC14 · AC20) · `add` · `pending` · `flush` 가 기계 상태 · R1 출력 그대로(AC20). `tests/test_conductor_state_branch_docs.py` 의 `NEW_MODULES` 에 `"leader_seat.py"` 를 더한다.

- [ ] **Step 2: 변이 표를 돌린다**

커밋한 뒤 아래 변이를 하나씩 넣고 `PYTHONDONTWRITEBYTECODE=1` 로 그 줄의 테스트를 돌려 붉은지 본다. 되돌림은 `git checkout HEAD -- <파일>` 뒤 `git diff HEAD --stat` 가 빈지로. 결과(변이 · 붉어진 테스트 이름 · 되돌림 확인)를 과제 보고에 표로 싣는다. 하나라도 초록이면 그 락에 이빨을 더한 뒤 다시 돈다. 1 – 3 은 **남의 글이 들어오는 길의 세 구멍**(B3 · I2 · I4)이다 — 고치기 전 꼴로 되돌린 변이가 붉어야 재현 테스트다.

| # | 변이 | 붉어야 할 테스트 |
|---|---|---|
| 1 | `_publish` 가 `target`(made 없이 옮긴 끝)을 「씀」 에 적는다 — B3 의 고치기 전 꼴 | `OwnCommits.test_unchanged_remake_moves_ref_to_foreign_tip_without_recording_it` · `test_creating_race_does_not_record_the_adopted_root` |
| 2 | `foreign_commits` 의 머지 검사(M4 ①)를 지운다 — I2 의 고치기 전 꼴 | `Foreign.test_foreign_merge_back_to_an_old_copy_is_not_hidden` |
| 3 | `confirm` 이 앞 8자도 받는다 — I4 의 고치기 전 꼴 | `Confirm.test_report_then_confirm_with_the_shown_tip` |
| 4 | 파일 끝 진입을 `sys.exit(main())` 로 되돌린다 — B2 | `RulesEdit.test_command_line_keeps_the_codes` · `Confirm.test_report_then_confirm_with_the_shown_tip` |
| 5 | `team_status.rules_tip` 의 `if not on` 갈래를 지운다 | `RulesTip.test_off_means_default_even_with_a_copy` · e2e ④ |
| 6 | `rules_tip` 이 남의 고침을 보지 않는다 | `RulesTip.test_foreign_copy_is_not_read_until_confirmed` · e2e ② |
| 7 | `_publish` 가 다시 만든 쓰기를 「씀」 에 적지 않는다 | `OwnCommits.test_remade_on_foreign_tip_records_only_mine` |
| 8 | `leader_seat.confirm` 의 끝 대조를 지운다 | `Confirm.test_a_tip_that_moved_after_the_report_is_not_confirmed` |
| 9 | `rules_edit` 가 읽을 끝 대신 로컬 끝을 읽는다 | `Confirm.test_rules_edit_is_refused_by_a_real_foreign_commit` |
| 10 | `start_bundle` 이 사본이 없어도 `--rules-at` 을 싣는다 | e2e 과제 4 걸음 2 · e2e ④ |
| 11 | `team_status.stale` 이 `rules_at` 대신 `bundle_at` 으로 견준다 | e2e 과제 4 걸음 7 |
| 12 | `c_flush` 가 확인 안 된 줄을 빼지 않는다 | e2e ② 의 `flush` |
| 13 | `c_flush` 가 기계 상태에서 그 에픽 줄을 모두 지운다(I6 의 고치기 전 꼴) | e2e 과제 9 의 사람 줄 걸음 |
| 14 | `c_add` 가 꺼진 설정에서도 `pending.md` 에 쓴다 | `test_conductor_ledger.py` 「꺼져 있으면 기계 상태」 |
| 15 | `rules_branch` 가 갈라짐을 보지 않는다 | `RulesBranch.test_diverged_default_refuses_with_the_difference` |
| 16 | `sync` 가 같아진 사본을 지우지 않는다 · 남의 고침이 있어도 지운다 | e2e 「같아지면 지운다」 · 「남의 고침이면 지우지 않는다」 |
| 17 | `roadmap_status.outside_line` 의 상한을 지운다 | `test_team_status.sh` 의 줄임 행 |
| 18 | `CP.BUCKETS` 에서 「결과 받음」 을 지운다 · `UNCOUNTED` 에 「준비」 를 더한다 | `StageTableLock` |
| 19 | `CB.DONE_STAGES` 에 단계를 하나 더한다 | 「`DONE_STAGES`」 행 |
| 20 | `team_files.parse_result` 가 `rules_at` 꼴을 보지 않는다 | `test_rules_at_is_optional_but_closed` |
| 21 | `_check_delete_form` 이 lease 의 ref 대조를 하지 않는다 | 「지우는 꼴의 문」 |
| 22 | `pr_cache_prints` 가 `확인한 끝` 을 빼먹는다 | `TrustInCacheKey` |
| 23 | `team_status.TRUST_WHY` 의 글자 하나를 바꾼다 | `Foreign.test_columns_match_the_machine_state` |

- [ ] **Step 3: AC20 의 기준 코드 대조를 한 번 돈다(커밋하지 않는다)**

`$TMPDIR` 에 스크립트를 두고 bash 로 돈다: `base=$(git merge-base HEAD origin/main)` · `git archive "$base" plugins/spec-distill/scripts | tar -x -C "$TMPDIR/base"` · 같은 team 픽스처(`team_repo.sh` 의 `new_repo` — 상태 브랜치를 만들지 않음 · 다음 판에 `state_branch: 끔`)에서 기준 스크립트와 이 브랜치 스크립트로 `control_plane.py show --tasks <로드맵>` · `roadmap_status.py <로드맵>` · `roadmap_status.py --json <로드맵>` · `conductor_ledger.py pending --roadmap <로드맵>` · `start_bundle.py --roadmap <로드맵> --role leader` · `start_bundle.py --roadmap <로드맵> --job E1 --stage implement --plan 1`(과제 묶음 — S12) 을 돌려 출력을 `diff` 한다. 기대 — 다른 줄은 이 계획이 일부러 바꾼 것뿐(team 글 출력의 `로드맵 밖 과제` · 판정 없음 문구 · `예약 밖 변경` 줄임 · 과제 폴더 없는 작업 알림). 과제 묶음의 「맞추는 명령」 줄은 **두 경우 모두 같다**(H1 (가) — 사본이 없다). 같은 대조를 옛 형식 로드맵으로도 하고 그때는 **차이가 0** 이다. 결과를 과제 보고에 싣는다.

- [ ] **Step 4: 전체 스위트**

Global Constraints 의 잠금 줄 그대로 돈다. 못 잡으면 주인 · 잡은 시각을 보고한다. `FAILED` 줄마다 이 브랜치의 변경과 닿는지 적는다 — worktree 에서만 나는 기존 실패(`TestCrossResolverAdvisory` 등)는 그렇다고 적는다. 이 브랜치에만 있는 실패가 0 이 될 때까지 그 과제의 뜻 안에서 고친다(pathspec 커밋).

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/tests/test_leader_seat_e2e.sh plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_conductor_state_branch_docs.py
git commit -m "test(spec-distill): 리더가 쓰는 자리의 끝에서 끝과 꺼진 설정의 옛 동작을 잰다"
```

---

## 실행 방식의 마지막 전체 리뷰

고른 실행 방식의 마지막 전체 리뷰(subagent-driven 의 브랜치 전체 리뷰 · native 의 마지막 리뷰)의 리뷰어에게 아래를 그대로 싣는다.

- 설계문서 `## Acceptance Criteria` 의 AC 목록 원문과 이 계획의 `## AC 가르기` 표.
- 요청: 계획 2 몫 AC(`AC12 · AC14~AC21`)마다 한 줄씩 `AC<n>: <구현됨|미룸|빠짐> — <근거(파일:줄 · 테스트 이름 · 명령 결과)>` 꼴로 보고하라. 걸친 AC(AC12 · AC14 · AC17 · AC19 · AC20)는 계획 1 이 한 부분과 이 계획이 한 부분을 함께 보고 둘이 다 됐으면 `구현됨` 이다. 설계 `## 미룸` 의 R3 행 다섯(Spec 줄)이 각각 어느 과제에서 받혔는지도 한 줄씩.
- 요청: 설계문서 `## 있는 것 검토` 가 고른 것을 실제로 썼는지, 같은 것을 다시 만들지 않았는지 줄마다 답하라 — `team_layout` 의 자리(`Team.rules` · `Team.path`)와 `leader_ref` 이름 · 대기 줄은 `conductor_ledger.py add · pending · flush` 의 줄 꼴과 옮기는 길(`_append_decisions`) · 상태 브랜치 쓰기는 `conductor_branch.write` 하나(다른 커밋 만들기 코드를 새로 쓰지 않았는가) · 브랜치 끝 고르기는 `branch_tip.tip` · 규칙 줄의 꼴은 `team_rules.parse_rules` · 브랜치 규칙 판정은 `conductor_branch.branch_rule`.
- 끝에서 끝 흐름 넷을 따로 물어라 — 각 이음매의 종료 코드 소비와 상태 가정: ① `rules-add` → 시작 묶음(규칙 머리 두 커밋 · `--rules-at`) → `job sync` → `rules-add` → 상태 계산의 「묶음 낡음」(앞 결과에만) ② 다른 클론의 규칙 사본 · `pending.md` 고침 → 받아 오기 → `sync` · `show` 의 「확인되지 않은 남의 고침」 · 묶음 알림 · `flush` 가 옮기지 않음 → `confirm`(또는 `rules-reset`) → 확인 뒤 사용 ③ `rules-branch` → 머지 → `sync` 가 사본을 지움 → 다음 묶음이 기본 브랜치 규칙 ④ 올리기 거절 → 다시 만들기(내 `pending.md` 줄 · 내 규칙 고침이 있을 때 · 원격 끝에서 바뀐 것이 없을 때) → `확인한 끝` 의 `씀` 줄에 남의 커밋이 섞이지 않는가.
- 요청: **남의 글이 들어오는 자리**가 닫히는 쪽으로 실패하는지 따로 답하라 — 계획을 고치며 막은 세 구멍(B3 원격 끝의 「씀」 · I2 남의 머지 커밋 · I4 앞 8자)이 정말 닫혔는지, 원격에서 온 커밋 · 규칙 사본 · `pending.md` · `rules-base.md` 의 글자가 경로 · git 인자 · 출력 틀로 들어가는 곳마다(`rules_state` 의 커밋 줄 · `confirm` 의 차이 · `pending_rows` 의 줄 가르기 · `c_pending` 의 출력 · `rules-branch` 의 이름). 남이 심은 글 하나(꼴이 틀린 `rules-base.md` · 아주 긴 줄 · 제어 글자 · 같은 줄 여럿 · 부모 둘인 커밋)로 `sync` · `show` · `flush` · 시작 묶음이 예외로 죽거나, 확인 전의 남의 줄이 시작 묶음 · 결정 기록에 들어가는 길이 남아 있는지.
- 요청: 「이 기계가 만든 커밋」 기록이 빠지는 길(예외로 끝난 쓰기 · 다시 얹기)과, 남의 커밋을 `씀` 으로 적는 길이 없는지. 「재지 못함」 이 영원히 막히는 길(확인 끝 커밋이 사라짐)이 `delete` · `confirm` 으로 풀리는지.
- 요청: 꺼 둔 설정 · 옛 형식 · 상태 브랜치 없음에서 R1 의 동작(묶음 · 「맞추는 명령」 · 「묶음 낡음」 · `add` · `pending` · `flush` 의 출력과 종료 코드)이 바뀌는 길이 없는지(AC20) — 과제 19 Step 3 의 대조 결과를 함께 본다.
- 요청: 상태 계산의 닫힘 — `team_status.py` · `team_layout.py` · `roadmap_status.py` 에 더한 코드가 정적 검사가 받는 호출만 쓰는지(`rev-list` · `diff-tree` 를 쓰지 않는지), `READERS` 에 더한 이름이 `TRUST` 하나뿐인지, 상태 계산 · 현황 화면이 `leader_seat` · `conductor_branch` 를 가져오지 않는지, 현황 캐시 열쇠가 `확인한 끝` 을 담는지.
- 요청: R2 의 사람 줄 관문(시작 묶음 · 결과 대조 · `record --human` · `human-check`)과 이 계획의 `rules_at` · `pending.md` · `flush` 가 만나는 자리에서 관문이 약해진 곳이 없는지.
- 이 계획이 쓴 테스트 코드(과제 2 – 13 · 18 의 파이썬 테스트와 표)는 계획이 정한 것이라는 표시를 붙여, 덜 보지 말고 같은 눈으로 보라고 적는다 — mock 된 거절(과제 2 다섯째의 `ls-remote` 답 · 과제 13 의 지우기 사이 끼우기는 답이나 때만 바꾸고 거절은 실제 git 이 낸다)과 공허한 단언을 찾으라고. 기존 테스트를 고친 곳(`test_start_bundle.sh` · `test_team_stale.sh` 의 lambda · `test_roadmap_status.sh` 의 `READERS` · `test_conductor_branch.py` 의 지우기 락 두 자리 · `test_conductor_state_branch_docs.py` 의 지운 한 줄)에서 단언이 지워지거나 느슨해지지 않았는지 `git diff origin/main -- plugins/spec-distill/tests` 로 보라고 적는다.

리뷰 보고는 git 이 추적하지 않는 파일에 적는다 — 지휘자가 준 임시 폴더의 `r3-plan2-ac-report.md`(없으면 상태 루트 `python3 plugins/spec-distill/scripts/state_path.py state-root` 가 내는 폴더 아래 같은 이름). 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올린다 — 올릴 행을 보고에 적고 지휘자가 올린다. PR 을 만들기 전에

`python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.19.2"/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-19-conductor-state-branch-design.md <보고 파일 경로> --acs "AC12 · AC14~AC21"`

을 돌려 경고를 사용자에게 보인다. PR 본문에는 「사용자 확인 대기」 의 답(Q1 · Q2 · H1 · H2 · M22 · M25① · 제안 5 · lease)과 그 답으로 고친 과제 · 사용자가 정한 넷(U1 – U4)과 건너뛴 과제 · ★ 표시 결정 · 과제 19 의 변이 표와 기준 코드 대조 · 아래 「재지 못함」 · 「고치지 않고 둔 것」 을 적는다.

## 재지 못함

- **GitHub 원격에서의 `--force-with-lease` 지우기.** 임시 레포의 원격은 로컬 bare 다. 브랜치 보호가 있는 레포에서 lease 를 건 지우기가 어떻게 거절되는지는 실제 원격에서 처음 돈다 — 거절되면 3 이고 로컬은 둔다.
- **다른 기계 둘.** 두 기계는 한 기계의 클론 둘로 흉내 냈다. `확인한 끝` 은 기계마다 따로라, 한 로드맵을 두 기계가 번갈아 지휘하면 서로의 커밋을 남의 고침으로 센다(닫히는 쪽 — 확인을 한 번 더 받는다).
- **설치본.** 지휘 세션은 설치된 판의 스크립트를 쓴다. 이 계획의 명령은 플러그인을 갱신한 새 세션부터 돈다.

## 고치지 않고 둔 것

- **끝난 로드맵에서 `ensure` 가 지운 상태 브랜치를 다시 만드는 것(M25① ⏸).** 「끝나지 않은 로드맵」 술어는 지금 셋(설계 `## 미룸` 의 E2 행)이고 블록만 세면 로드맵 밖 과제만 남은 team 로드맵에서 상태 브랜치가 서지 않는다. E2 가 술어를 하나로 모은 뒤에 고친다.
- **`dependencies.md` 의 project-init 행(계획 1 리뷰 잔여).** 행을 더하면 판 칸을 `check_deps.py measure` 가 재야 하는데, 그 스크립트는 공용 `shared/deps/check_deps.py` 의 사본이라 플러그인 모두의 사본과 그 락을 함께 고쳐야 한다(계획 1 J8). README 「Prerequisites」 가 이미 공시한다. 설계문서 `## 미룸` 에 올릴 후보로 보고한다.
- **`job_results.py` 의 `rules_at` 대조(M11).** 꼴이 틀린 값은 머리 문제로 거절되고, 없는 커밋은 「묶음 낡음을 재지 못했다」 로 드러난다.
- **다른 로드맵의 남의 고침 수.** `show` 는 내 로드맵의 것만 센다 — 다른 기계의 확인한 끝을 모른다.
- **계획 1 원장의 과제별 작은 지적(I14).** 원장(`.superpowers/sdd/2026-11-19-conductor-state-branch-plan1/progress.md`)의 `minor (deferred)` 줄을 셋으로 갈랐다. ① 이 계획이 받은 것 — `waiting_clear` 의 `--kind` 검사(과제 13) · 「턴 끝」 · 다른 세션 줄 위의 질문 창(P2 — 과제 13) · `./a/b` 과잉 거절 · 맨 `/tmp`(과제 13 의 가리기 꼴) · 원격 지우기의 비원자성(과제 13) · 다시 얹기의 둘째 부모(과제 13) · `KEYS[-1]` 핀(계획 1 이 이미 다시 셌다). ② 동작이 닫히는 쪽이라 두는 것 — 네트워크 실패 갈래의 테스트 부족 · 같은 기계 두 프로세스의 경쟁 · 바깥 catch-all 의 사유 글 · 하위 프로세스 시간 제한 없음 · `suites()` 의 OSError · `_age` 의 「0분」 대체 · 갈라진 로드맵의 편지 미독 사유 · 규칙 정규식이 `a..b` 를 받는 것(`name_ok` 가 먼저 막는다). ③ 테스트 · 문서 다듬기라 두는 것 — 픽스처의 공허한 지문 비교 · 환경 격리의 남은 변수 · 얕은 클론 픽스처 · 꼴 틀린 값의 음성 사례 부족 · 문서 락의 부분 문자열 단언 · README 의 빈 줄. ② · ③ 은 설계문서 `## 미룸` 의 「리뷰 잔여」 행 그대로 두고, 그 행의 받는 곳은 지휘자가 다시 정한다.
