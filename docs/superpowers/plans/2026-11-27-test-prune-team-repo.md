# 있는 테스트 정리 PR 1 — 팀 레포 준비물 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 승인된 PR 1 판정 표(2026-11-27)대로 팀 레포를 테스트마다 · 묶음마다 새로 짓던 셸 테스트 다섯을 「한 번 지어 복사」 로 바꾸고, 같은 동작을 되풀이하던 확인(`test_human_gate.sh` 15 · 16 · `test_human_gate_e2e.sh` 의 위조 줄 열두 갈래)을 대표만 남기고 사유 글 확인은 `test_human_judge.py` 로 옮기고, `test_team_status.sh` · `test_roadmap_status.sh` 의 보고 읽기와 정적 검사 변이를 프로세스 하나로 묶어 시간을 줄인다.

**Architecture:** 있는 팀 레포 도우미 `plugins/spec-distill/tests/fixtures/team_repo.sh` 에 진입점 하나(`repo_copy`)만 더한다 — 기존 함수는 그대로다. 견본은 테스트 프로세스마다 한 번 짓고 묶음마다 `cp -R` 한 뒤 원격 주소만 사본 쪽으로 돌린다. 줄인 확인은 남는 확인이 같은 변이를 잡는지 지우기 전 사본과 견줘 보인다(`git archive` 로 뜬 사본 둘 — 작업 트리를 건드리지 않는다).

**Tech Stack:** bash(`shared/tests/assert.sh` — `/usr/bin/env bash` 가 3.2 일 수 있다) · python3(이 기계의 스위트 `python3` 는 3.9 — 3.9 문법만) · unittest · git · 시간 기록은 `tools/suite/run-all.sh` 의 `SUITE_TIMING_FILE` · `SUITE_ONLY_FAILED_FILE`.

**Spec:** `docs/superpowers/specs/2026-11-26-test-prune-design.md` §1 의 PR 1 몫. 범위는 사용자가 승인한 판정 표가 정한다 — `/Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-20-test-method-rework-brief/files/relay/E4/table-pr1-final.md`(근거 실측: 같은 폴더 `table-pr1-a.md` · `table-pr1-b.md`). 설계문서 끝 「Deferred to plan」 표는 모두 본문에 반영됐다(지휘 기록) — 이 계획이 따로 받는 행은 없다. 승인 줄의 「값 읽기 묶기(④)는 하지 않는다」 는 PR 3 표의 답이다(`table-pr3-final.md` 머리) — PR 1 표의 `test_roadmap_status.sh` ④(정적 검사 변이를 한 프로세스로)는 승인된 그대로 한다.

## Global Constraints

- 고치는 파일은 아래 열뿐이다(표에 없는 테스트는 고치지 않는다 — 설계 §2 걸음 3): `plugins/spec-distill/tests/fixtures/team_repo.sh` · `test_human_gate.sh` · `test_human_gate_e2e.sh` · `test_human_judge.py` · `test_team_status.sh` · `test_leader_seat_e2e.sh` · `test_human_record.sh` · `test_walk_next.sh` · `test_roadmap_status.sh`(모두 `plugins/spec-distill/tests/` 아래) · `docs/removed-tests.md`. 마지막 과제에서 설계문서 `## 미룸` 표에 줄을 더할 수 있다.
- 표의 「둠」 행 파일(`test_start_bundle.sh` · `test_team_tasks.sh` · `test_job_results.sh` · `test_team_stale.sh` · `test_conductor_state_branch_e2e.sh` · `test_team_coverage.sh` · `test_team_sync.sh` · `test_team_review_entry.sh` · `test_team_rules.sh`)과 `fixtures/session_fixture.py` 는 고치지 않는다. `test_human_gate.sh` 9 · 10 · 11 · `test_human_gate_e2e.sh` 1–16 · S0 · P0 · S+ · P+ · P4 · 옛 형식 · `test_human_record.sh` 8 · 9 는 그대로 둔다.
- 새 파일을 만들지 않는다(도우미 확인은 그 준비물을 쓰는 테스트 파일 안 — 설계 「테스트할 자리」). 실행 비트를 바꾸지 않는다(테스트 일곱은 100755, `team_repo.sh` 는 100644 그대로).
- 어느 플러그인의 `plugin.json` 판도 바꾸지 않고 CHANGELOG 를 고치지 않는다(AC12). `plugins/spec-distill/tests/test_stage_prose_trim.sh` 는 건드리지 않는다(AC14). `docs/testing.md` 는 바꾸지 않는다.
- 보안 확인(표의 「보안 확인이 섞였는가」 칸의 줄 범위)은 첫째 줄 · 넷째 줄로 지우거나 줄이지 않는다. 옮기거나 줄인 보안 확인은 변이 넷(삭제 · 추가 · 반전 · 형태 바꾸기)과 양성 대조로 보인다(`docs/testing.md` 「망가뜨려 보기」). `test_roadmap_status.sh` 의 :419–893 · :1787–1857 은 보안처럼 다룬다(표).
- 지운 확인의 기록 줄 꼴은 `docs/removed-tests.md` 머리 그대로다: `- <지운 날> · <테스트 파일[ · 케이스]> · 지키던 것: <한 문장> · 판정: <「값 대비 비용」 의 어느 줄> · 지금 지키는 것: <테스트 경로> · PR #<번호>`.
- 셸은 bash 3.2 에서 돈다 — 연관 배열을 쓰지 않는다. 변수 바로 뒤에 한글 · 낫표가 오면 `${v}` 로 감싼다. 셸 안 python 은 파일 읽기 · 쓰기에 `encoding="utf-8"` 을 쓴다.
- 변이를 걸 때는 작업 트리를 고치지 않는다 — `git archive <커밋> | tar -x -C "$TMPDIR/<이름>"` 으로 뜬 사본에 건다. 사본 실행은 `PYTHONDONTWRITEBYTECODE=1` 로 한다(낡은 `.pyc` 가 변이를 가린다). 사본의 변이 자리 하나가 0개 · 둘 이상이면 그 변이는 무효로 보고 자리를 고친다.
- 문서는 한국어가 기본이다. 사람에게 보이는 보고는 첫 줄에 상태, 번호 · 해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 끝에 할 일.
- 커밋: Conventional Commits(`type(scope):` 영어 · 설명 한국어), pathspec 으로만(`git add -- <경로>` · `git commit -m … -- <경로>`). 본문 끝: `Spec: docs/superpowers/specs/2026-11-26-test-prune-design.md` 와 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`(그 agent 의 모델 이름으로). push 는 지휘자의 지시를 따른다.
- 금지: 공유 임시 폴더 glob 삭제 · `git stash` · 다른 worktree 의 git · HEAD 뒤로 옮기기(reset · rebase · force). 지우는 것은 자기가 만든 경로를 이름으로만.
- `TMPDIR` 은 지휘자가 정한 폴더(`/Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-20-test-method-rework-brief/files/tmp/<agent 이름>`)다. 격리된 자리의 셸은 복합 명령을 막는다 — `$TMPDIR` 의 스크립트 파일로 써서 `bash <파일>` 로 돈다.
- 전체 스위트와 시간 재기는 공유 잠금 아래에서만 돈다: `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.25.0/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-20-test-method-rework-brief/files/suite-lock --owner <이 agent 이름> --wait 3600 -- bash -c '<명령>'`. 못 잡으면 잠금 없이 돌리지 않고 주인 · 잡은 시각을 보고한다. 하위 구현 agent 에게 전체 스위트를 맡기지 않는다 — 과제 안에서는 그 과제의 파일만 돈다.
- 하위 agent 를 띄울 때마다 superpowers subagent-driven-development 의 「Model Selection」 으로 모델을 골라 이름으로 지정하고 이유를 한 줄 적는다. 과제 리뷰어에게는 「계획이 쓴 테스트 코드」 를 그렇다고 밝혀 넘긴다(덜 검사받는 자리다).
- 설계문서의 글자 · 수용 기준 · 승인 표의 판정을 바꿔야 할 것 같으면 스스로 정하지 말고 멈춰 지휘자에게 보고한다.

## Review Focus

1. 견본 짓기가 실패하면(`team_repo` 가 rc 1) — 예전엔 그 묶음에서 실패했고, 이제는 `repo_copy` 가 1 을 내고 부르는 쪽의 `|| { no …; exit 1; }` 가 그대로 받아야 한다. 없는 견본 폴더도 1(Task 2 단언).
2. 레포가 이미 선 폴더에 다시 뜨면 — 두 레포를 섞지 않고 1 을 낸다(Task 2 단언).
3. 같은 경로의 보고 JSON 을 같은 초 안에 다른 글로 다시 쓰면 — 보고 캐시가 옛 값을 내지 않고 다시 읽는다(Task 5 · Task 8 단언).
4. 보고에 블록이 없거나 블록에 그 칸이 없으면 — 캐시 도우미는 지금 `js` 와 같은 표준 출력을 낸다(블록 없음 → 빈 출력, 칸 없음 → `칸 없음`). 있는 단언(`test_team_status.sh` :109 의 `칸 없음`)과 Task 5 의 한 번 대조로 본다.
5. 정적 검사 묶음 실행에서 앞 묶음의 `LOCAL_DIR` · 모듈 캐시가 뒤 묶음으로 새면 — 사본 폴더의 변이가 안 보여 양성 대조가 거짓으로 지난다. Task 8 의 한 번 대조(묶음마다 따로 띄운 출력과 바이트 비교)와 형태 바꾸기 변이(캐시를 비우지 않게 바꾼 사본에서 RED)로 본다.

---

### Task 1: 다시 확인과 고치기 전 시간

코드를 바꾸지 않는다. 설계 · 승인 표가 근거로 든 자리가 지금 코드에서도 그런지 보고, 하나라도 다르면 **멈추고** 다른 자리 · 지금 값을 지휘자에게 보고한다.

**Files:** 없음(기록은 `$TMPDIR/recheck.md` · `$TMPDIR/times-before.tsv` — git 밖)

**Interfaces:**
- Produces: `$TMPDIR/times-before.tsv`(Task 9 가 견준다) · `$TMPDIR/only-targets.txt`(Task 9 가 같은 목록으로 다시 잰다)

- [ ] **Step 1: 자리 대조** — 아래가 모두 맞는지 본다(줄 번호는 이 브랜치의 머리 `3e83f142` 기준).
  - 레포를 짓는 횟수: `test_human_gate.sh` 의 `new_repo` 15(묶음 A · B · C · D · F · G · H · J · K · I · L · M · N · O · P) · `e1_state` 를 부르는 묶음 7(H · K · I · L · N · O · P) · `test_team_status.sh` 3(:11 `team_repo` · :736 `team_repo` · :804 `new_repo`) · `test_leader_seat_e2e.sh` `new_repo` 5 · `test_human_record.sh` 3(:14 `team_repo && claim` · :356 · :378 `new_repo`) · `test_walk_next.sh` `new_repo` 3.
  - `test_human_gate.sh` 15 · 16 이 :102–106 이고 묶음 A 의 마지막 확인이다(:107 `g checkout -q main`).
  - `test_human_gate_e2e.sh` 의 `trio` 부름이 16번이다 — S1 :179 · S2–S7 :182–219 · S8 :221–225 · S9 두 갈래 :227–237 · S10 세 갈래 :239–251 · P1 :264–267 · P2 :269–273 · P3 :275–284.
  - `test_human_judge.py` 의 `Match.test_forged_lines_do_not_pass` 가 :183–211, `test_other_question_of_the_same_call` :213, `test_old_answer_with_a_rewritten_version` :221, `test_one_answer_two_lines` :229, `test_plan_head_carries_the_plan_number` :242 이다.
  - 사유 글의 출처: `human_lines.py` 의 `match` · `shape` · `_no_answer` 가 낸 `why` 가 human-check 의 `    사유: ` 줄(`conductor_ledger.py` 의 `out.append("    사유: %s" % got.why)`)과 묶음 · 결과 대조 사유(`human_lines.py` 의 `` "`%s` 줄이 지나지 못했다%s: %s" ``)로 그대로 간다.
  - `test_roadmap_status.sh`: `static_check` 정의 :420, 부름 :716(열일곱 파일) · :721–816 · :874–876, `ctl_reader` :750 · `ctl_own` :784, 읽기 전용 행동 `ro_probe` · `ro_variant` :1802–1857.
  - `team_repo.sh` 를 source 하는 테스트가 열다섯이고(위 다섯 + 둠 열), 그 열다섯 어디에도 `TEAM_TPL` · `repo_copy` 라는 이름이 없다.
  - `git diff --name-only origin/main...origin/feature/switch-retirement` 에 고칠 파일 아홉이 없다(`docs/removed-tests.md` 만 겹친다 — 설계 §8 대로 머지 때 둘 다 남긴다). 양성 대조로 같은 grep 이 `docs/removed-tests.md` 를 찾는지 본다.
- [ ] **Step 2: 복사 안전 실측** — `$TMPDIR` 의 스크립트로 `team_repo.sh` 를 source 해 `new_repo "$X/a"` 를 짓고 `cp -R "$X/a" "$X/b"` 한 뒤 `grep -rlF --exclude-dir=objects -- "$X/a" "$X/b"` 를 본다. 기대: `repo/.git/config`(원격 주소)와 `repo/.git/FETCH_HEAD` 둘뿐(표 A 의 실측). 다른 파일이 나오면 그 파일 · 내용을 보고하고 멈춘다.
- [ ] **Step 3: 고치기 전 시간** — `$TMPDIR/only-targets.txt` 에 일곱 줄을 쓴다(`<대상>: 시간` 꼴): `plugins/spec-distill/tests/test_human_gate.sh` · `test_human_gate_e2e.sh` · `test_team_status.sh` · `test_leader_seat_e2e.sh` · `test_human_record.sh` · `test_walk_next.sh` · `test_roadmap_status.sh`(모두 그 폴더 경로로). 공유 잠금 아래에서 돈다:

```bash
python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.25.0/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-20-test-method-rework-brief/files/suite-lock --owner <이 agent 이름> --wait 3600 -- bash -c 'SUITE_ONLY_FAILED_FILE="$TMPDIR/only-targets.txt" SUITE_TIMING_FILE="$TMPDIR/times-before.tsv" bash tools/suite/run-all.sh; { /usr/bin/time -p python3 -m unittest plugins/spec-distill/tests/test_human_judge.py; } 2> "$TMPDIR/judge-before.txt"'
```

  기대: `times-before.tsv` 에 대상 일곱의 `<초>\tsh\t<대상>\t<다른 스위트 수>` 줄, `judge-before.txt` 끝에 `real <초>`(`test_human_judge.py` — python 폴더 러너는 파일 하나를 따로 재지 못해 직접 잰다). 다른 스위트 수가 0 이 아닌 줄이 있으면 그렇다고 기록한다. `FAILED` 줄이 있으면 기존 실패로 기록한다(이 PR 이 만든 것이 아니다).
- [ ] **Step 4: 고치기 전 통과 수** — 잠금 없이 일곱 셸 파일을 하나씩 `bash <파일>` 로 돌려 끝 줄(`finish` 의 요약)을 `$TMPDIR/counts-before.txt` 에 적는다. 뒤 과제의 「통과 수가 고치기 전과 같다 · ±n」 은 이 값과 견준다.
- [ ] **Step 5: 기록** — `$TMPDIR/recheck.md` 에 Step 1–4 의 결과를 한 줄씩 적는다. 커밋하지 않는다.

### Task 2: 팀 레포 견본 복사 진입점과 `test_human_gate.sh` 의 묶음 복사

**Files:**
- Modify: `plugins/spec-distill/tests/fixtures/team_repo.sh`(끝에 함수 하나 · 머리 주석의 도우미 목록에 이름 하나)
- Modify: `plugins/spec-distill/tests/test_human_gate.sh`(묶음 A 앞에 도우미 확인 0 · `new_repo` 열다섯 · e1_state 견본)

**Interfaces:**
- Produces: `repo_copy <새 폴더> <견본>` — 견본은 `team`(`team_repo` 를 막 부른 레포) · `new`(`new_repo` 를 막 부른 레포 — 공통 문서 커밋 · 지휘 표지까지) · 팀 레포가 선 폴더 경로(`origin.git` · `repo` 가 있는 폴더) 가운데 하나. `team` · `new` 견본은 그 테스트 프로세스에서 처음 부를 때 `$TEAM_TPL/team` · `$TEAM_TPL/new` 에 한 번 짓는다 — `new` 는 `team` 견본의 사본에 `new_repo` 의 나머지(공통 문서 커밋 · push · fetch · `claim`)를 더해 짓는다. `TEAM_TPL` 은 source 때의 `$T` 아래 `.team-tpl` 이다. 새 폴더가 없으면 만들고, 있으면 그 안에 `repo` · `origin.git` 이 없어야 한다. 견본 폴더의 내용을 새 폴더로 `cp -R` 하고 `use_repo <새 폴더>` · `git remote set-url origin <새 폴더>/origin.git` · `git fetch -q origin` 을 한다. rc 0 = 섰다, 1 = 견본을 짓지 못함 · 없는 견본 · 새 폴더에 레포가 이미 있음(까닭은 표준 오류 한 줄 · 이때는 `T` · `W` · `CLAUDE_CONFIG_DIR` 를 옮기지 않는다). 기존 함수(`team_repo` · `new_repo` · `use_repo` …)는 바꾸지 않는다.

- [ ] **Step 1: 실패하는 도우미 확인을 쓴다** — `test_human_gate.sh` 의 `SPECL=…` 줄 뒤, 묶음 A 머리 앞에 넣는다(계획이 쓴 테스트 코드):

```bash
# ── 0 — 한 번 지어 복사하는 팀 레포(repo_copy): 사본은 원격을 따로 갖고 견본 경로를 품지 않는다 ──
repo_copy "$T0/c0a" new && repo_copy "$T0/c0b" new && ok "0: 견본에서 사본 둘을 떴다" || { no "0: 사본을 뜨지 못했다 — $(cat "$T/out.txt" "$T/led.txt" 2>/dev/null)"; finish; exit 1; }
assert_eq "$(git -C "$T0/c0a/repo" remote get-url origin)" "$T0/c0a/origin.git" "0: 사본의 원격은 그 사본의 bare 레포다"
assert_eq "$(grep -rlF --exclude-dir=objects -- "$TEAM_TPL" "$T0/c0a/repo" "$T0/c0a/origin.git" "$T0/c0a/claude" 2>/dev/null)" "" "0: 사본의 레포 · 원격 · 세션 기록에 견본 경로가 남지 않는다"
use_repo "$T0/c0a" && g checkout -q -b c0/only-a main && g push -q origin c0/only-a
assert_eq "$(git -C "$T0/c0a/origin.git" for-each-ref --format='%(refname)' refs/heads/c0/only-a)" "refs/heads/c0/only-a" "0: 양성 대조 — 그 사본의 원격에는 올라갔다"
assert_eq "$(git -C "$T0/c0b/origin.git" for-each-ref --format='%(refname)' refs/heads/c0/only-a)" "" "0: 한 사본의 push 가 다른 사본의 원격에 보이지 않는다"
assert_eq "$(git -C "$TEAM_TPL/new/origin.git" for-each-ref --format='%(refname)' refs/heads/c0/only-a)" "" "0: 견본의 원격에도 보이지 않는다"
repo_copy "$T0/c0a" new 2>/dev/null; assert_eq "$?" "1" "0: 레포가 이미 선 폴더에는 뜨지 않는다"
repo_copy "$T0/c0c" "$T0/no-such-template" 2>/dev/null; assert_eq "$?" "1" "0: 없는 견본은 1"
```

- [ ] **Step 2: 실패를 본다** — `bash plugins/spec-distill/tests/test_human_gate.sh 2>&1 | head -5`. 기대: `repo_copy` 가 없어(`command not found`) 「0: 사본을 뜨지 못했다」 로 멈춘다.
- [ ] **Step 3: `team_repo.sh` 에 `repo_copy` 를 쓴다** — 위 Interfaces 그대로. 머리 주석 3–4줄의 도우미 목록에 `repo_copy` 를 더한다. 함수 주석은 무엇을 하는지만 적는다(이력 · 배경을 적지 않는다).
- [ ] **Step 4: 도우미 확인이 지나는지 본다** — 같은 명령. 기대: 「0:」 단언 여덟이 모두 ✓ 이고, 그 뒤는 지금처럼 돈다.
- [ ] **Step 5: 부정 대조(구현 보고에 싣는다)** — `$TMPDIR` 의 `git archive HEAD` 사본(작업 트리의 고친 두 파일을 덮어 둔 것)에서 `repo_copy` 의 `remote set-url` 줄을 지우고 돈다. 기대: 「0: 사본의 원격은…」 과 「0: 한 사본의 push 가…」 가 ✗. 결과(✗ 줄)를 보고에 싣는다.
- [ ] **Step 6: 묶음을 복사로 바꾼다** — `test_human_gate.sh` 에서
  - 묶음 A · B · C · D · F · G · J · M 의 `new_repo "$T0/<x>"` 를 `repo_copy "$T0/<x>" new` 로 바꾼다(뒤의 `&& ok … || { no …; exit 1; }` 는 그대로).
  - `e1_state` · `line_of` · `edit_intent` 정의 뒤, 묶음 H 앞에 견본 셋을 짓는다: T1 = `repo_copy "$T0/t1" new && e1_state` · T2 = `repo_copy "$T0/t2" "$T0/t1" && approved "spec 승인" E1 - - 2026-11-20 && push_br feature/tm-e1` · T3 = `repo_copy "$T0/t3" "$T0/t2" && approved "계획 검토" E1 1 - 2026-11-21 && push_br feature/tm-e1`. 실패하면 `no "견본 T1–T3 을 짓지 못했다 — …"; finish; exit 1`. `PLAN_R1` 은 T1 을 지을 때 `e1_state` 가 정한 값을 그대로 쓴다(묶음 I :384 가 읽는다).
  - 묶음 K · O 는 `repo_copy "$T0/<x>" "$T0/t1"`, H · L · P 는 `"$T0/t2"`, I · N 은 `"$T0/t3"` 로 뜨고, 견본이 이미 한 일만 담은 줄(H :292 · K :356 · I :369 · L :398 · N :427 · O :440 · P :468 — `e1_state` 와 그 뒤의 `approved` · `push_br`)을 지운다.
  - 사본 단위는 묶음 하나다 — 한 묶음 안에서 다시 뜨지 않는다(A 1→16 · D 20→30 은 앞 상태에 기댄다).
- [ ] **Step 7: 돈다** — `bash plugins/spec-distill/tests/test_human_gate.sh`. 기대: 실패 0, 통과 수 = 고치기 전(Task 1 Step 4) + 8(확인 0 의 ok · 단언 여덟 — 견본 T1–T3 에 ok 줄을 두었으면 그만큼 더한다). 15 · 16 은 아직 있다.
- [ ] **Step 8: 전에 잡던 것 하나를 아직 잡는지 본다(구현 보고에 싣는다)** — `git archive HEAD` 사본에 고친 두 파일을 덮고, `plugins/spec-distill/scripts/human_lines.py` 의 `if ans.who != session_record.HUMAN:` 를 `if ans.who == session_record.HUMAN:` 으로 바꿔 `test_human_gate.sh` 를 돈다. 기대: ✗ 가 하나 이상(사람 줄 관문이 사본에서도 산다). 변이 없는 같은 사본은 실패 0(양성 대조).
- [ ] **Step 9: 커밋** — `git add -- plugins/spec-distill/tests/fixtures/team_repo.sh plugins/spec-distill/tests/test_human_gate.sh` · `git commit -m "test(spec-distill): 팀 레포를 한 번 지어 묶음마다 복사한다" -- <같은 두 경로>`.

### Task 3: `test_human_gate.sh` 15 · 16 을 지운다

**Files:**
- Modify: `plugins/spec-distill/tests/test_human_gate.sh:102-106`(Task 2 뒤 줄 번호는 옮겨졌다 — `15: 설계 없는 흐름은` 로 찾는다)
- Modify: `docs/removed-tests.md`(`## 항목` 아래 한 줄)

**Interfaces:**
- Consumes: Task 2 의 `test_human_gate.sh`

- [ ] **Step 1: 변이 견주기(지우기 전에 — 보안 :102–106 · AC7)** — 사본 둘을 뜬다: 옛 = `git archive HEAD`(15 · 16 이 있는 지금), 새 = 같은 사본에서 15 · 16 다섯 줄을 지운 것. 「흐름 승인」 관문(설계 없는 흐름은 흐름 승인 줄이 없으면 멈추고 있으면 나간다)에 변이 넷을 사본마다 따로 건다. 기본 자리(자리가 없거나 옛 15 · 16 이 잡지 못하면 같은 갈래의 다른 자리를 고르고 까닭을 적는다):
  - 삭제 — `human_lines.py` 의 관문 표(독스트링 「관문 표 — … 설계 없는 흐름이면 어느 단계든 흐름 승인 하나」 인 함수)가 설계 없는 흐름에서 내는 흐름 승인 항목을 빈 목록으로.
  - 추가 — 같은 자리에 설계 없는 흐름도 `spec 승인` 을 함께 요구하게.
  - 반전 — 흐름 승인 줄이 지났는지 보는 판정의 참 · 거짓을 뒤집기.
  - 형태 바꾸기 — `PASS_LABELS` 의 `KIND_FLOW` 통과 라벨 `"설계 없이 진행"` 을 `"설계 없이 진행한다"` 로.
  옛 사본에서는 `test_human_gate.sh` 를, 새 사본에서는 `test_human_gate_e2e.sh` 를 돈다. 기대: 변이마다 옛 15 · 16 가운데 ✗ 가 있으면 새 쪽 e2e 15 · 16 에도 ✗ 가 있다. 변이 없는 사본은 둘 다 실패 0(양성 대조). 옛 쪽이 잡고 새 쪽이 못 잡는 변이가 하나라도 있으면 **멈추고** 보고한다(겹침이 아니다 — 표를 다시 승인받아야 한다).
- [ ] **Step 2: 지운다** — 다섯 줄(`g checkout -q -b feature/tm-e2 main && push_br feature/tm-e2` 부터 `check 0 "16: …"` 까지)을 지우고, 묶음 A 머리 주석의 「설계 흐름(E1)과 설계 없는 흐름(E2)」 을 「설계 흐름(E1)」 으로 고친다.
- [ ] **Step 3: 돈다** — `bash plugins/spec-distill/tests/test_human_gate.sh`. 기대: 실패 0, 통과 수가 Task 2 보다 넷(15 의 `check 1` 이 내는 단언 둘 · 사유 하나 · 16 의 `check 0` 하나) 적다.
- [ ] **Step 4: 기록 한 줄** — `docs/removed-tests.md` 의 `## 항목` 아래:
  `- <오늘 날짜> · plugins/spec-distill/tests/test_human_gate.sh · 15 · 16 · 지키던 것: 설계 없는 흐름의 시작 묶음은 흐름 승인 줄이 없으면 멈추고 있으면 나간다 · 판정: 둘째 줄(같은 것을 다른 테스트가 지킨다) · 지금 지키는 것: plugins/spec-distill/tests/test_human_gate_e2e.sh(15 · 16) · PR #<번호>`
  (`<번호>` 는 PR 을 연 뒤 Task 9 가 채운다.)
- [ ] **Step 5: 커밋** — `git commit -m "test(spec-distill): human_gate 15 · 16 을 e2e 15 · 16 에 합친다" -- plugins/spec-distill/tests/test_human_gate.sh docs/removed-tests.md`. 구현 보고에 Step 1 의 표(변이 · 옛 ✗ 줄 · 새 ✗ 줄)를 싣는다.

### Task 4: 견본 복사 — `test_leader_seat_e2e.sh` · `test_human_record.sh` · `test_walk_next.sh`

**Files:**
- Modify: `plugins/spec-distill/tests/test_leader_seat_e2e.sh`(:15 · :168 · :248 · :276 · :328)
- Modify: `plugins/spec-distill/tests/test_human_record.sh`(:14 · :356 · :378)
- Modify: `plugins/spec-distill/tests/test_walk_next.sh`(:25 · :149 · :226)

**Interfaces:**
- Consumes: Task 2 의 `repo_copy <새 폴더> team|new|<폴더>`

- [ ] **Step 1: 바꾼다** — `new_repo "$T0/<x>"` 는 `repo_copy "$T0/<x>" new` 로. `test_human_record.sh` :14 의 `team_repo && claim` 은 `repo_copy "$T" team && claim` 으로(새 폴더가 이미 있는 `$T` 다 — 그 안에 레포가 없으니 뜬다). 뒤의 `&& ok … || { no …; }` 는 그대로다. `test_leader_seat_e2e.sh` 의 견본은 `new_repo` 단계까지다 — 뒤의 `git config` · `info/exclude` 줄(:17–18)은 사본에서 그대로 돈다.
- [ ] **Step 2: 돈다** — 셋을 하나씩 `bash <파일>`. 기대: 셋 다 실패 0, 통과 수가 고치기 전(Task 1 Step 4)과 같다.
- [ ] **Step 3: 커밋** — `git commit -m "test(spec-distill): 리더 자리 · 사람 줄 · 걸음 보기 테스트가 팀 레포 견본을 복사한다" -- <세 경로>`.

### Task 5: `test_team_status.sh` — 견본 복사와 보고를 한 번 읽기

**Files:**
- Modify: `plugins/spec-distill/tests/test_team_status.sh`(:11 · :735–736 · :804 · 도우미 :72–77)

**Interfaces:**
- Consumes: Task 2 의 `repo_copy`
- Produces(이 파일 안): `jget <json 파일> <블록 번호> <칸>` — 표준 출력이 지금의 `js "$json" "[b for b in r['blocks'] if b['id']=='<번호>'][0].get('<칸>', '칸 없음')"` 와 바이트로 같다. `<칸>` 이 `notes|` 면 `' | '.join(… ['notes'])` 와, `job.<k>` 면 `[…][0]['job']['<k>']` 와 같다. 블록이 없으면 빈 출력. 보고 파일 하나를 글(내용의 `cksum`)이 같은 동안 python 한 번으로만 읽는다 — 블록마다 칸 값을 `shlex.quote` 한 셸 변수 대입으로 `$T` 아래 캐시 파일에 쓰고 source 한다(블록 번호의 영숫자 밖 글자는 `_<16진 두 자리>` 로). 수정 시각으로 가리지 않는다.

- [ ] **Step 1: 실패하는 신선함 확인을 쓴다** — 도우미 정의 뒤(:94 근처)에 넣는다(계획이 쓴 테스트 코드):

```bash
printf '{"blocks": [{"id": "Z1", "stage": "가"}]}\n' > "$T/fresh.json"
assert_eq "$(jget "$T/fresh.json" Z1 stage)" "가" "보고 캐시: 처음 읽은 값"
printf '{"blocks": [{"id": "Z1", "stage": "나"}]}\n' > "$T/fresh.json"
assert_eq "$(jget "$T/fresh.json" Z1 stage)" "나" "보고 캐시: 같은 경로를 같은 초에 다시 쓰면 새 글을 읽는다"
assert_eq "$(jget "$T/fresh.json" Z1 reason)" "칸 없음" "보고 캐시: 블록은 있고 칸이 없으면 칸 없음"
assert_eq "$(jget "$T/fresh.json" Z9 stage)" "" "보고 캐시: 블록이 없으면 빈 출력"
```

- [ ] **Step 2: 실패를 본다** — `bash plugins/spec-distill/tests/test_team_status.sh 2>&1 | grep '보고 캐시'`. 기대: 넷 다 ✗(`jget` 이 없다).
- [ ] **Step 3: `jget` 을 쓰고 한 번 대조한다** — Interfaces 그대로 쓴 뒤, 임시로 `blk` · `notes` · `jobf` 가 옛 `js` 식과 `jget` 을 둘 다 불러 다르면 `no "캐시 대조: <번호> <칸>"` 을 내게 하고 파일 전체를 한 번 돈다. 기대: 「캐시 대조」 ✗ 0. 그 임시 대조를 지우고 `blk` · `st` · `why` · `prog` · `notes` · `jobf` 를 `jget "$T/s.json" …` 위에 다시 쓴다. 다른 `js` 직접 부름(:107 · :108 · :161–162 · :263 등)은 그대로 둔다.
- [ ] **Step 4: 견본 복사** — :11 `team_repo` → `repo_copy "$T" team`(뒤의 `&& ok … || { no …; finish; }` 그대로). :735–736 의 `T0="$T"; T="$T0/gate"; mkdir -p "$T"; W="$T/repo"; export CLAUDE_CONFIG_DIR="$T/claude"` + `team_repo` → `T0="$T"` + `repo_copy "$T0/gate" team`(뒤의 ok/no 그대로). :804 `new_repo "$T0/rcpt"` → `repo_copy "$T0/rcpt" new`. :801 `T="$T0"` 와 끝의 `use_repo "$T0"` 는 그대로다.
- [ ] **Step 5: 돈다** — `bash plugins/spec-distill/tests/test_team_status.sh`. 기대: 실패 0, 통과 수 = 고치기 전 + 4(보고 캐시 단언).
- [ ] **Step 6: 신선함 단언의 이빨 · 전에 잡던 것 하나(구현 보고)** — `git archive HEAD` 사본에 고친 파일을 덮고 (가) 캐시 열쇠를 글의 `cksum` 대신 경로만 쓰게 바꿔 돈다 → 「같은 경로를 같은 초에 다시 쓰면 새 글을 읽는다」 ✗. (나) 같은 사본을 되돌리고 `plugins/spec-distill/scripts/team_status.py` 의 단계 이름 하나(`st` 단언이 견주는 것 — 예: 「설계 중」)를 다른 글로 바꿔 돈다. 기대: 그 단계를 견주는 ✗ 가 같은 변이를 건 고치기 전 커밋 사본에서와 같은 수만큼 나온다. 변이 없는 사본은 실패 0(양성 대조).
- [ ] **Step 7: 커밋** — `git commit -m "test(spec-distill): team_status 테스트가 견본을 복사하고 보고를 한 번 읽는다" -- plugins/spec-distill/tests/test_team_status.sh`.

### Task 6: `test_human_judge.py` — 위조 줄 갈래마다 사유 글을 잰다(옮겨 받는 쪽)

Task 7 이 e2e 의 열두 갈래를 지우기 **전에** 그 갈래들이 human-check 에서 재던 사유 글을 여기로 옮긴다.

**Files:**
- Modify: `plugins/spec-distill/tests/test_human_judge.py:183-250`

**Interfaces:**
- Produces: `Match` 의 갈래 표가 `(줄, 판정, 사유 조각 튜플)` 이 되고, 조각마다 `H.match(...).why` 에 들었는지 잰다.

- [ ] **Step 1: 사유 조각을 더한다** — `test_forged_lines_do_not_pass` 의 `cases` 값을 3-튜플로 바꾸고 루프에서 조각마다 `assertIn(frag, verdict.why, name)` 을 더한다. 조각은 지울 e2e 갈래가 human-check 에서 재던 글 그대로다(다른 갈래는 빈 튜플):

| `cases` 이름 | 사유 조각 | 옮겨 오는 e2e 갈래 |
|---|---|---|
| 손으로 쓴 줄 | `"근거 칸이 없거나 줄 꼴이 아니다"` | P1 |
| 없는 항목 | `"세션 기록에 없다"` | S2 |
| 다른 과제의 답 | `"시작하지 않는다"` | S3 |
| 라벨만 바꾼 줄 | `"사람이 고른 라벨은 「수정 필요」"` | S4 |
| 훅이 채운 답 | `"사람이"`, `"hook"` | S9(`--who hook`) |
| 빈 답 | `"세션 기록에 없다"` | S9(`--empty`) |
| 모르는 출처 | `"질문 창으로 다시 승인받는다"`, `"fixture_other"` | S10(`--who other`) |
| 모르는 entrypoint | `"질문 창으로 다시 승인받는다"`, `"fixture_other"` | S10(`--entrypoint fixture_other`) |

  그리고 따로 선 세 메서드에 한 줄씩: `test_other_question_of_the_same_call` 의 `n == 2` 에서 `assertIn("시작하지 않는다", H.match(...).why)`(S5) · `test_one_answer_two_lines` 의 `real, [real, twin]` 에서 `assertIn("같은 답을 근거로 쓴 줄이 또 있다", …)`(S6) · `test_old_answer_with_a_rewritten_version` 의 `rewritten, tip=c5` 에서 `assertIn("시작하지 않는다", …)`(S7) · `test_plan_head_carries_the_plan_number` 의 `as_two, tip=both` 에서 `assertIn("시작하지 않는다", …)`(P3). 판정을 재는 기존 단언은 그대로 둔다.
- [ ] **Step 2: 돈다** — `python3 -m unittest plugins/spec-distill/tests/test_human_judge.py`. 기대: OK. 조각 하나라도 `why` 에 없으면 조각을 고쳐 맞추지 말고 **멈추고** 보고한다(그 갈래의 e2e 사유가 다른 길에서 온다는 뜻 — 옮기면 잃는다).
- [ ] **Step 3: 옮긴 확인이 무는지 본다(보안 — 믿지 않는 입력 · AC7. 구현 보고)** — `git archive HEAD` 사본(고친 파일을 덮은 것)에 변이 넷을 따로 걸어 `test_human_judge.py` 를 돈다:
  - 삭제 — `human_lines.py` `match` 의 `if picked != line.label:` 두 줄을 지움 → 「라벨만 바꾼 줄」 ✗.
  - 추가 — `session_record.py` 의 `HUMAN_ENTRYPOINTS = ("cli",)` 에 `"fixture_other"` 를 더함 → 「모르는 entrypoint」 ✗.
  - 반전 — `match` 의 `if ans.who != session_record.HUMAN:` 를 `==` 로 → ✗ 여럿.
  - 형태 바꾸기 — `"사람이 고른 라벨은 「%s」 이다"` 를 `"고른 라벨이 「%s」 이다"` 로, `"그 질문은 머리 %s 로 시작하지 않는다"` 를 `"그 질문의 머리가 %s 가 아니다"` 로(판정은 그대로 · 글만) → 새로 더한 사유 조각 단언만 ✗.
  변이 없는 사본은 OK(양성 대조). 결과 표(변이 · ✗ 이름)를 보고에 싣는다.
- [ ] **Step 4: 커밋** — `git commit -m "test(spec-distill): human_judge 가 위조 줄 갈래마다 사유 글을 잰다" -- plugins/spec-distill/tests/test_human_judge.py`.

### Task 7: `test_human_gate_e2e.sh` — 위조 줄 갈래를 대표 넷으로 줄인다

**Files:**
- Modify: `plugins/spec-distill/tests/test_human_gate_e2e.sh:182-284`
- Modify: `docs/removed-tests.md`(열두 줄)

**Interfaces:**
- Consumes: Task 6 의 사유 조각 단언

- [ ] **Step 1: 변이 견주기(지우기 전에 — 보안 :109–285 · AC7)** — 사본 둘: 옛 = 지금 `HEAD`(Task 6 반영 · e2e 열여섯 갈래), 새 = 같은 사본에서 Step 2 대로 지운 것. Task 6 Step 3 의 변이 넷을 사본마다 건다. 옛 쪽은 `test_human_gate_e2e.sh`, 새 쪽은 `test_human_gate_e2e.sh` 와 `test_human_judge.py` 를 돈다. 기대: 변이마다 옛 e2e 가 ✗ 를 내면 새 쪽(e2e 대표 넷 또는 human_judge) 가운데 하나 이상이 ✗ 를 낸다. 변이 없는 사본은 모두 통과(양성 대조). 옛 쪽만 잡는 변이가 있으면 **멈추고** 보고한다.
- [ ] **Step 2: 지운다** — 남기는 것: S1(:176–180) · S8(:221–225) · S10 의 `--drop entrypoint` 한 갈래 · P2(:269–273) · 그 밖의 준비 · S0 · S+ · P0 · P4 · P+. 지우는 것: S2–S7 블록(:182–219) · S9 반복문(:227–237) · S10 의 `--who other` · `--entrypoint fixture_other` 두 갈래(반복문을 `--drop entrypoint` 한 블록으로 풀고 `cause="entrypoint"`) · P1(:264–267) · P3 블록(:275–284 — 계획 2 를 만드는 준비 포함). `hd` · `rend` · `rev_of` · `key_now` · `plant` · `unplant` · `trio` · `passes` 정의는 남는 갈래가 쓰니 그대로다.
- [ ] **Step 3: 돈다** — `bash plugins/spec-distill/tests/test_human_gate_e2e.sh`. 기대: 실패 0, `trio` 부름 넷.
- [ ] **Step 4: 기록 열두 줄** — `docs/removed-tests.md` 에 갈래마다 한 줄(승인 표대로 — 지금 지키는 것은 `test_human_judge.py`):
  `- <오늘 날짜> · plugins/spec-distill/tests/test_human_gate_e2e.sh · <갈래 이름 그대로 — 예: S2 없는 항목> · 지키던 것: <그 갈래의 위조 줄>을 시작 묶음 · 결과 대조 · human-check 가 모두 막고 사유가 그 줄 탓이다 · 판정: 둘째 줄(같은 것을 다른 테스트가 지킨다) · 지금 지키는 것: plugins/spec-distill/tests/test_human_judge.py(Match) · PR #<번호>`
  갈래 열둘: S2 없는 항목 · S3 다른 과제의 답 · S4 라벨만 바꾼 줄 · S5 같은 호출의 다른 질문에서 고른 라벨 · S6 같은 근거를 두 번 쓴 줄 · S7 진짜 옛 답 · 판만 새 커밋 · S9 훅이 채운 답(--who hook) · S9 고른 답이 빈 결과(--empty) · S10 모르는 출처(--who other) · S10 모르는 출처(--entrypoint fixture_other) · P1 손으로 쓴 줄 · P3 다른 계획의 답.
- [ ] **Step 5: 커밋** — `git commit -m "test(spec-distill): human_gate_e2e 의 위조 줄 갈래를 대표 넷으로 줄인다" -- plugins/spec-distill/tests/test_human_gate_e2e.sh docs/removed-tests.md`. 구현 보고에 Step 1 의 표를 싣는다.

### Task 8: `test_roadmap_status.sh` — 보고를 한 번 읽기(③)와 정적 검사 변이를 한 프로세스로(④)

**Files:**
- Modify: `plugins/spec-distill/tests/test_roadmap_status.sh`(도우미 :38–43 · :1573 · 정적 검사 :419–816 · :874–876)

**Interfaces:**
- Produces(이 파일 안):
  - `jcache` 계열 — `stage` · `warns` · `notes` · `reason` 이 같은 인자(`<json 파일> <블록 번호>`)로 지금 `js` 식과 바이트로 같은 표준 출력을 내되, 보고 파일 하나를 글(`cksum`)이 같은 동안 python 한 번으로만 읽는다(Task 5 의 `jget` 과 같은 계약 — 이 파일의 `next(…)` 식은 블록이 없으면 빈 출력). 다른 `js` 직접 부름은 그대로다. 함수는 Task 5 와 글자째 같은 20줄 덩어리가 되지 않게 쓴다(`shared/tests/test_no_new_duplication.sh`).
  - `static_check --batch <목록 파일> <출력 폴더>` — 목록 한 줄이 `<이름>\t<LOCAL_DIR 또는 ->\t<파일>[\t<파일>…]` 인 묶음이다. 묶음마다 python 한 프로세스 안에서 모듈 수준 가변 상태(`_MODS` · `_IMPORT_SCANNED` · `LOCAL` · `ARGS` · 세는 값, 그리고 heredoc 안의 다른 모듈 수준 가변 값 전부 — 고치기 전에 전수로 적어 보고한다)를 새로 하고 `os.environ["LOCAL_DIR"]` 를 그 묶음 값으로 두거나 지운 뒤, `<출력 폴더>/<이름>.out` 에 `LOCAL_DIR=<값> static_check <파일…>` 이 따로 냈을 출력과 바이트로 같은 글을 쓴다. `static_check <파일…>`(묶음 없이)는 지금 그대로 돈다 — 검사 몸은 heredoc 하나에 두고 두 꼴이 나눠 쓴다.
  - 묶는 부름: :721–749 · :816 · :874–876 의 `static_check` 와 `ctl_reader` · `ctl_own` 의 부름 전부. `ctl_reader` 는 사본 폴더를 만들고 변이를 걸어 목록에 한 줄을 더하는 일만 하고(이름은 지금 첫 인자), 단언은 묶음 실행 뒤 `<이름>.out` 을 읽는다. :716 의 열일곱 파일 부름 · `net_check` · `ro_probe` · `ro_variant` 는 그대로다(프로세스 경계가 확인 대상).

- [ ] **Step 1: 실패하는 신선함 확인을 쓴다** — Task 5 Step 1 의 네 단언과 같은 꼴을 이 파일의 `stage` · `reason` 으로 쓴다(블록 `Z1` · `Z9`, 메시지 머리 「보고 캐시: 」). 이 파일의 보고 꼴이 `next(...)` 라 「칸 없음」 단언은 쓰지 않고, 블록 없음은 빈 출력이다.
- [ ] **Step 2: 지금은 지나는 것을 본다** — 지금 `stage` · `reason` 은 매번 읽어 이 단언들이 ✓ 다(캐시가 없으면 낡을 수 없다). 이빨은 Step 5 뒤에 본다 — 캐시 열쇠를 경로만 쓰게 바꾼 사본에서 「같은 경로를 같은 초에 다시 쓰면…」 ✗(Step 6 의 보고에 함께 싣는다).
- [ ] **Step 3: ③ 을 쓰고 한 번 대조한다** — 캐시 도우미를 쓰고, 임시로 `stage` · `warns` · `notes` · `reason` 이 옛 `js` 와 둘 다 불러 다르면 `no "캐시 대조: …"` 를 내게 해 파일 전체를 돈다. 기대: 「캐시 대조」 ✗ 0. 임시 대조를 지운다.
- [ ] **Step 4: ④ 를 쓰고 한 번 대조한다** — Interfaces 그대로 쓴 뒤, 임시로 묶음 실행 뒤에 목록의 묶음마다 옛 꼴(`LOCAL_DIR=<값> static_check <파일…>`)을 따로 띄워 `<이름>.out` 과 `cmp` 하는 반복문을 더해 돈다. 기대: 모든 묶음이 같다(묶음 수를 보고에 적는다). 반복문을 지운다.
- [ ] **Step 5: 돈다** — `bash plugins/spec-distill/tests/test_roadmap_status.sh`. 기대: 실패 0, 통과 수 = 고치기 전 + 신선함 단언 수. 단언 메시지는 하나도 바뀌지 않았다(`git diff` 에서 지운 · 더한 `assert_` 줄의 메시지 집합이 같다 — 옮긴 줄만 있다).
- [ ] **Step 6: 변이 넷과 양성 대조(보안처럼 · AC7 — 구현 보고)** — 사본 둘: 옛 = 고치기 전 커밋, 새 = `HEAD`. 사본의 `test_roadmap_status.sh` 안 검사기에 변이를 건다(옛 · 새 heredoc 에 같은 글로 걸리는 자리):
  - 삭제 — `WRITE_ATTRS` 에서 `"write_text", ` 을 지움 → 「parse_machine 이 부르는 함수의 쓰기까지 따라가 잡는다」 등 ✗.
  - 추가 — `READ_GIT` 에 `"fetch", ` 를 더함 → 「fetch 를 허용 목록에 넣으면 정적 검사가 잡는다」 ✗.
  - 반전 — `if set(str(mode)) & set("wax+"):` 를 `if not (set(str(mode)) & set("wax+")):` 로 → 「내장 open 의 쓰기 모드를 잡는다」 ✗.
  - 형태 바꾸기(새 사본에만 — 묶음 경계의 카나리아) — 묶음마다 상태를 새로 하는 줄을 지워 첫 묶음의 `LOCAL` · `_MODS` 를 그대로 쓰게 → 사본 폴더 변이(`ctl_reader`)의 양성 대조 ✗.
  그리고 읽기 전용 행동 하나(③ 이 닿는 보고 읽기와 :1787–1857): 사본의 `plugins/spec-distill/scripts/roadmap_status.py` 의 `build()` 첫머리에 `Path(git.cwd, ".claude", "spec-distill", "probe.md").write_text("x", encoding="utf-8")` 를 넣음 → 「읽기 전용 행동: …」 ✗(옛 · 새 같음). 단계 이름 하나(`stage` 단언이 견주는 글)를 바꾼 사본에서 `stage` ✗ 수가 옛 · 새 같다(③ 이 전에 잡던 것). 변이 없는 사본은 둘 다 실패 0. 기대: 삭제 · 추가 · 반전 · 읽기 전용 · 단계 이름 변이에서 옛 · 새의 ✗ 메시지 집합이 같고, 형태 바꾸기는 새 쪽이 ✗.
- [ ] **Step 7: 커밋** — `git commit -m "test(spec-distill): roadmap_status 테스트가 보고를 한 번 읽고 정적 검사 변이를 한 프로세스로 돈다" -- plugins/spec-distill/tests/test_roadmap_status.sh`.

### Task 9: 마무리 — 점검 · 시간 · 스위트 · 리뷰 · PR

**Files:**
- Modify: `docs/removed-tests.md`(PR 번호 — PR 을 연 뒤)
- Modify: `docs/superpowers/specs/2026-11-26-test-prune-design.md`(`## 미룸` 표 — 미룬 것이 있을 때만)

- [ ] **Step 1: 이력 주석(AC11)** — 고친 아홉 파일에서 이력 주석(언제 · 어느 PR · 누가 고쳤는지만 말하는 주석)을 찾아 덜어 낸다. 무엇을 지키는지 · 왜 그 꼴인지 말하는 문장과 픽스처를 설명하는 주석(예: `test_roadmap_status.sh` :1877–1892 의 가짜 PR 번호)은 남긴다. 다시 확인에서 본 후보는 없었다 — 없으면 「없음」 으로 보고한다.
- [ ] **Step 2: §5 점검(AC9 · AC10)** — 구현 보고에 기대는 꼴마다 한 줄: 지움을 막는 문서(`CLAUDE.md` · `docs/philosophy/` · `docs/plugin-authoring.md` · `docs/testing.md` · `docs/git-workflow/` · 플러그인과 `shared/` 의 `README.md` · `plugins/*/skills/**` · `plugins/*/references/**` · `plugins/*/agents/**` · `plugins/*/templates/**`)가 지운 케이스 이름(「S2 없는 항목」 등 · `human_gate.sh` 15 · 16)을 부르는가(`git grep -F` — 0건이어야 한다) · 이 PR 이 지운 파일(없다 — AC9 는 「지운 파일 없음」) · 다른 테스트의 실행 · 목록 요구 · import · `# guards:` · 실패 원장 등재 · 부재 락 코퍼스. 그리고 아래를 하나씩 돌려 통과를 본다: `bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh` · `bash shared/tests/test_charter_citations.sh` · `bash plugins/spec-distill/tests/test_epic_conductor_skill.sh` · `bash plugins/spec-distill/tests/test_begin_round_snapshot.sh` · `bash shared/tests/test_presence_corpus_behavior.sh` · `bash shared/tests/test_no_new_duplication.sh`.
- [ ] **Step 3: 도우미를 쓰는 대상 밖 테스트** — `team_repo.sh` 에 진입점을 더했으니 그것을 source 하는 둠 아홉(`test_start_bundle.sh` · `test_team_tasks.sh` · `test_job_results.sh` · `test_team_stale.sh` · `test_conductor_state_branch_e2e.sh` · `test_team_coverage.sh` · `test_team_sync.sh` · `test_team_review_entry.sh` · `test_team_rules.sh`)을 돌려 실패 0 을 본다(그 테스트들은 고치지 않는다).
- [ ] **Step 4: 판 · 금지 파일(AC12 · AC14)** — `git diff --name-only origin/main...HEAD` 에 `plugin.json` · `CHANGELOG.md` · `test_stage_prose_trim.sh` 가 없고, 바뀐 파일이 Global Constraints 의 목록 안이다. `git ls-files -s` 로 고친 테스트 일곱이 100755 다.
- [ ] **Step 5: 고친 뒤 시간(AC3)** — Task 1 Step 3 과 같은 명령을 `times-after.tsv` 로 돈다. 대상 일곱마다 앞 · 뒤 초를 표로 만든다. 고친 파일마다 뒤가 앞보다 작아야 한다 — 작지 않은 파일이 있으면 까닭(부하 · 다른 스위트 수 · 그 파일의 줄어드는 몫)을 적고 지휘자에게 알린다(PR 본문에 싣고 사용자 승인을 받는다). `test_human_judge.py` 의 앞 · 뒤도 함께 싣는다(받는 쪽 — 표의 「≈0」).
- [ ] **Step 6: 전체 스위트(AC13)** — 공유 잠금 명령으로 `bash tools/suite/run-all.sh` 를 돈다(하위 구현 agent 가 아니라 이 흐름의 주인이 돈다). `FAILED` 줄마다 같은 대상이 `origin/main` 에서도 실패하는지 본다(worktree 에서만 나는 기존 실패가 있다 — 예: `TestCrossResolverAdvisory`). 이 브랜치만의 새 실패가 0 이어야 한다.
- [ ] **Step 7: 마지막 전체 리뷰** — 아래 「마지막 전체 리뷰에 싣는 것」 대로 띄우고, 리뷰의 AC 보고를 git 이 추적하지 않는 파일 `$TMPDIR/e4-pr1-ac-report.md` 에 쓴다.
- [ ] **Step 8: 미룸** — 리뷰가 「미룸」 · 「빠짐」 으로 낸 AC 와 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 한 줄씩 더하고 커밋한다(`docs(spec): …` · 같은 꼬리). 없으면 건너뛴다.
- [ ] **Step 9: 묶음 대조** — `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/9.3.0/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-26-test-prune-design.md "$TMPDIR/e4-pr1-ac-report.md"` 를 돌려 출력(경고 포함)을 그대로 지휘자에게 보인다.
- [ ] **Step 10: PR 본문 재료(AC1 · AC2)** — 지휘자에게 넘긴다: 승인받은 판정 표(`table-pr1-final.md` 그대로)와 승인 줄(「판정 표 승인 · 2026-11-27 · PR 1(팀 레포 준비물) 「승인 (권장)」」) · 읽은 담당자 A 와 다시 읽은 담당자 B(서로 다른 Opus 하위 agent)와 둘의 판정이 갈린 행(`table-pr1-b.md` 의 「A·B 갈림」 칸이 「예」 · 「부분」 · 「초」 · 「범위」 · 「csb 범위」 인 행을 A · B 원문 그대로) · Step 5 의 앞 · 뒤 초 표 · 변이 보고(Task 2 · 3 · 6 · 7 · 8) · §5 점검 · 기록한 열세 줄. PR 을 여는 일은 지휘자의 흐름이다.
- [ ] **Step 11: PR 번호(AC8)** — PR 이 열리면 `docs/removed-tests.md` 의 이 PR 줄 열셋의 `PR #<번호>` 를 실제 번호로 채워 같은 PR 의 다음 커밋으로 올린다(`docs(test): 지운 테스트 기록에 PR 번호를 채운다`).

## 마지막 전체 리뷰에 싣는 것

- 리뷰 범위: `origin/main...HEAD` 전체. 리뷰어는 쓰기 도구가 없는 agent 다(Law 2).
- 설계문서 `## Acceptance Criteria` 의 이 PR 몫 — AC1 · AC2 · AC3 · AC7 · AC8 · AC9 · AC10 · AC11 · AC12 · AC13 · AC14 — 를 원문 그대로 싣고, AC 마다 한 줄 `AC<n>: <구현됨 | 미룸 | 빠짐> — <근거>` 로 보고하게 한다(AC4 · AC5 · AC6 · AC15 · AC16 · AC17 은 다른 PR 몫이라 「미룸 — 다른 PR(PR 2 · 3 · 정리 PR · 로드맵 끝)」 으로 적게 한다). AC1 · AC2 · AC8 의 PR 본문 · PR 번호 부분은 PR 을 연 뒤에 서는 것이라 근거에 「PR 본문 재료 · Task 9 Step 10–11」 을 댄다.
- 설계문서 `## 있는 것 검토` 가 고른 것을 실제로 썼는지, 같은 것을 다시 만들지 않았는지 묻는다: 팀 레포 도우미 `fixtures/team_repo.sh` 위에 얹었는가(새 도우미 파일 없음) · 시간은 `tools/suite/` 의 시간 기록(`SUITE_TIMING_FILE`)으로 쟀는가 · 기록은 `docs/removed-tests.md` 의 줄 꼴인가 · 판정 기준은 `docs/testing.md` 그대로인가(바꾸지 않음) · 평가 장치는 쓰지 않았는가.
- 끝에서 끝을 묻는다: `repo_copy` 를 쓰는 다섯 파일이 견본을 프로세스마다 한 번만 짓는가 · 사본마다 `CLAUDE_CONFIG_DIR` 이 그 사본으로 가는가 · 줄인 확인마다 남는 확인이 같은 변이를 잡는다는 보고가 있는가 · 기록 열세 줄의 「지금 지키는 것」 이 실제로 그것을 재는가 · 캐시 도우미가 같은 경로의 다른 글을 다시 읽는가.
- 계획이 쓴 테스트 코드(Task 2 Step 1 · Task 5 Step 1 · Task 6 의 조각 표)는 그렇다고 밝혀 따로 보게 한다.

## 테스트할 자리와의 대응

| 설계 「테스트할 자리」 | 이 계획 |
|---|---|
| 한 번 지어 복사하는 준비물 도우미(팀 레포) — 복사본끼리 상태를 나누지 않고 원본 절대 경로가 남지 않는다 | Task 2 Step 1 의 확인 0(`test_human_gate.sh` 안) · Step 5 부정 대조 |
| 옮기거나 합친 확인 — 전에 잡던 것을 옮긴 뒤에도 잡는다(보안은 변이 넷 · 양성 대조) | Task 3 Step 1 · Task 6 Step 3 · Task 7 Step 1 · Task 8 Step 6 · 보안이 아닌 옮김은 Task 2 Step 8 · Task 5 Step 6 |
