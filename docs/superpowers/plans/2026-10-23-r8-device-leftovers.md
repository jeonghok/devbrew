# R14 — R8 남은 장치 결함 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 에픽 PR 번호를 기계 상태에 적고 그 번호로 머지를 판정하는 길 하나를 만들고, R8 리뷰가 남긴 나머지 장치 결함(공시 문장 · 해결자 · 원장 · 다음 세션 줄 · 작은 빈틈)을 있는 검사에 한 줄씩 더해 닫는다.

**Architecture:** 번호는 기계 상태의 선택 절 `## 에픽 PR` 에 산다. 쓰는 곳은 `ledger pr-record` 하나(gh 로 대조 뒤 쓰기 + `## PR` 캐시 줄), 운반은 `ledger pr-refresh`, 읽는 곳은 상태 계산 · 상태줄 · 원장의 PR 읽기 — 모두 `conductor_state` 의 두 함수(번호 찾기 · 번호의 캐시 줄)를 거친다. 기계 상태를 못 읽으면 상태 계산은 머지 판정을 보류한다. 나머지 항목은 있는 함수 · 테스트에 조건 한 줄씩이다.

**Tech Stack:** Python 3.9(`from __future__ import annotations`) · macOS bash 3.2 셸 테스트 · `shared/tests/assert.sh` · `unittest` · gh CLI(쓰는 쪽만).

**Spec:** `docs/superpowers/specs/2026-10-23-r8-device-leftovers-design.md` (계획과 함께 읽는다. 아래 `SD` = `plugins/spec-distill`)

## Global Constraints

- R8 AC17 — 상태 계산(`roadmap_status`) · 상태줄(`control_plane`)은 gh 를 부르지 않는다. 번호 판정도 캐시만 읽는다.
- 셸 펜스와 셸 테스트는 macOS bash 3.2 에서 돈다. 새 · 바뀐 셸 테스트는 100755 다. 테스트는 `bash <파일>` 로 돌린다(Bash 도구 셸은 zsh — `PIPESTATUS` 가 비어 rc 를 잘못 읽는다).
- bash 에서 변수 바로 뒤에 한글이 오면 `${v}` 로 감싼다(bash 3.2 가 `$v` 뒤 다중 바이트 글자를 먹는다).
- C25 · C35 · D26 — 외부 플러그인(superpowers)은 건드리지 않는다.
- 사람에게 보이는 명령의 PR 번호는 숫자만(`--pr 123`) — 맨 `#` 은 셸 주석이다.
- R9 병렬(지휘자 덧붙임): `conductor_ledger.py` · `test_epic_conductor_skill.sh` · `SD/README.md` · `SD/skills/spec-review/SKILL.md` · `SD/skills/request-framing/SKILL.md` 에서 R14 몫(PR 번호 기록 · §3 공시 · §5 · §7) 밖은 건드리지 않는다. `approval` · `approve` · epic-conductor `SKILL.md` · 쉬운 말 블록과 그 사본은 고치지 않는다. README 는 `## 한계` 와 상태 계산 줄(`scripts/roadmap_status.py <로드맵 경로>` 불릿)만.
- 경로 예약 — `shared/tests/fixtures/docreview/golden/` · `SD/tests/test_review_handoff_order.sh` 는 Task 11 이 예약에 더한 뒤에만 고친다. 그 밖의 예약 밖 파일은 고치지 않는다.
- 레포 락: `open(` · `.read_text(` 에 `encoding` 필수 · plugins 의 `.py` 에 `"python3"` 리터럴 금지 · 3.9 문법 · scripts 의 `re.compile` 리터럴이 `"## 6. 사용자 원문"` 앞 3글자 이상과 맞으면 RED · 두 파일에 20줄 같은 블록 금지 · CHANGELOG 새 머리는 바로 다음 판만.
- 변이로 이빨을 잴 때: 먼저 커밋하고, `PYTHONDONTWRITEBYTECODE=1`, 사본에 변이(원본은 그대로)하거나 원본을 바꿨으면 `git checkout HEAD -- <파일>` 뒤 `git diff HEAD` 로 되돌림을 확인한다. 변이가 실제로 적용됐는지(`cmp`) 먼저 본다. 음의 락에는 양의 짝을 둔다.
- 커밋: Conventional Commits, 설명은 한국어, pathspec 커밋, 트레일러 `Spec: docs/superpowers/specs/2026-10-23-r8-device-leftovers-design.md`.

## Review Focus

1. **이 레포 자신의 기계 상태는 옛 4칸 PR 줄이다** — Task 7 뒤 상태 계산은 모든 브랜치 판정을 보류한다. 보류 사유가 `--reset` 명령을 담고, `ledger pr-refresh --reset` 이 그 상태에서도 돌아 보류를 푼다(Task 7 테스트 `test_reset_lifts_hold_on_old_rows`).
2. **`gh pr create` 출력의 꼴** — 끝 개행 · 앞뒤 공백 · 끝 `/` 가 붙은 URL 은 받고, `issues/` URL · `#` 만 · `0` · `12abc` 는 rc 2 다(Task 3 `test_parse_pr_ref_forms`).
3. **로드맵 사본이 블록에 더한 브랜치의 PR** — `pr-record` 가 `_with_copy_branches` 를 거친 브랜치 목록으로 head 를 대조한다(Task 4 `test_copy_branch_head_accepted`).
4. **`--drop` 뒤에는 이름 · 이력 추정으로 돌아간다** — 번호 줄을 지운 브랜치는 다음 상태 계산에서 지금 길로 판정된다(Task 6 `test_drop_returns_to_name_path`).
5. **폴더 값의 `:` 가 가운데에 있으면 받는다** — `:` 로 시작할 때만 pathspec 매직이다(Task 14 `test_colon_inside_folder_ok`).

## 지휘자 덧붙임 · 참고 열하나의 처리

| # | 처리 | 과제 |
|---|---|---|
| 9fb13e91#r1.1 (지휘자 덧붙임 1) | 기계 상태 파일이 있는데 못 읽으면 머지 판정 보류 + 복구 사유. 설계문서에 AC21 을 더했다 | Task 7 |
| a6ecc055#r2.2 (지휘자 덧붙임 2) | 손 절차 8 에도 바탕 바꾼 직후 `pr-record` → `pr-refresh`. 설계문서 AC17 · Files to Modify 를 손 절차 8 까지 넓혔다 | Task 10 |
| 64366fc7#r4.1 (지휘자 덧붙임 3) | 설계문서 Context 2 의 한 문장을 바로잡았다(계획 커밋에 함께). 손 절차 5 에 `pr-record` → `pr-refresh` 를 **새로** 더한다 | Task 10 |
| f01c3775#r1.1 | U9 뒤 README 둘째 줄이 「지휘 세션에서 한 번 · 쓰기는 표지를 쥔 세션만」 으로 이미 맞다 — 그 글 그대로 싣는다 | Task 9 |
| cf7e2bc4#r1.1 | 다루지 않음 — U9 가 자동 채우기를 지워 「후보 여럿」 갈래가 없다 | — |
| fccf272b#r1.1 | 줄을 고르는 세 자리는 `recorded_cache_row`, `_prs` 는 `recorded_number`, 지문은 따로 | Task 5 · 6 · 8 |
| 9db1c4b0#r2.1 | README 공시 뒤 세 불릿을 같은 쉬운 말(리뷰 기록 · 리뷰 명령)로 | Task 12 |
| e5d7c790#r2.1 | `ledger add --section "레포 설정"` 이 읽는 쪽 값 검사(빈 값 · 정규식)를 쓰기 전에 돈다 | Task 15 |
| 1cdda836#r2.1 | 로드맵 · `R14.md` 갱신을 예약 Task 의 파일로 적었다 | Task 11 |
| f7b2ece8#r2.1 | 다루지 않음 — epic-conductor `SKILL.md` 를 고치지 않는다(설계문서 `## 상류 · 하류 연계`) | — |
| 8ce8e648#r3.1 | 다루지 않음 — U9 가 걸음 1 자동 채우기를 지웠다. 걸음 1 부재 락이 되살아남을 막는다 | Task 10 |

설계문서 `### Deferred to plan` 의 세 물음:

- **rc** — `pr-record` 의 대조 실패는 기존 rc 4 를 쓴다. 모듈 머리 설명을 「4 gh 가 낸 PR 이 기대와 다르다(pr-refresh: 다른 head · 모르는 값 / pr-record: head · 교차 · base · 레포가 그 에픽과 맞지 않음)」 로 넓힌다.
- **URL 펜스 꼴** — 지휘자는 `gh pr create` 표준 출력의 마지막 줄을 `--pr` 에 넘긴다. `parse_pr_ref` 가 앞뒤 공백을 벗긴다. `gh pr create` 가 실패하면(이미 있는 PR) 지휘자가 그 번호를 숫자로 넘긴다.
- **bare 판별** — `git --git-dir <공용 git 디렉토리> config --bool core.bare` 의 출력이 `true` 면 bare. 픽스처는 `git clone -q --bare <원본> <d>/.git` → `git --git-dir <d>/.git worktree add -q <d>/wt <브랜치>`.

---

### Task 1: 설계 뒤 기본 브랜치 변경 재확인 (AC15)

**Files:** 없음(결과는 이 절에 적는다)

계획 작성 시점 결과(2026-10-23): `origin/main` = ad7efbb6 — 설계 기준과 같다. 바뀐 자리 없음, 새 받는 곳 R14 행 없음.

구현 시작 시점 결과(2026-10-23, 브랜치 7be20442): `git log --oneline ad7efbb6..origin/main` 빈 출력 — 바뀐 자리 없음, 새 받는 곳 R14 행 없음.

- [ ] **Step 1: 구현 시작 시점에 다시 본다**

Run: `git fetch -q origin && git log --oneline ad7efbb6..origin/main`
Expected: 빈 출력이면 끝. 커밋이 있으면 Step 2.

- [ ] **Step 2: (커밋이 있을 때만) 자리와 받는 곳을 본다**

Run: `git diff --stat ad7efbb6 origin/main` 로 설계문서 §10 표의 파일이 바뀌었는지 보고, `git grep -n "R14" origin/main -- 'docs/superpowers/specs/*-design.md'` 로 `## 미룸` 의 받는 곳 R14 새 행을 찾는다. 바뀐 자리는 이 절에 한 줄씩 더해 커밋하고, 설계에 없던 결정이 필요하면 멈추고 지휘 세션에 보고한다.

---

### Task 2: 기계 상태 `## 에픽 PR` 절 · 번호 찾기 두 함수 (AC6 읽기 · 꼴)

**Files:**
- Modify: `SD/scripts/conductor_state.py`
- Test: `SD/tests/test_conductor_state.py`

**Interfaces:**
- Produces:
  - `EPIC_PR = "에픽 PR"`; `SECTIONS` 의 `"PR"` 바로 뒤에 `("에픽 PR", ("에픽", "브랜치", "번호", "적은 때", "쓴 세션"))`; `OPTIONAL_SECTIONS = ("작업", "에픽 PR")`
  - `RECORDED_MISSING = "PR %s 이 PR 캐시에 없다 — 지휘자를 돌려 캐시를 채운다"`
  - `recorded_number(epic_rows: list, epic: str, branch: str) -> str | None` — `"#12"` 꼴 또는 None
  - `recorded_cache_row(epic_rows: list, pr_rows: list, epic: str, branch: str) -> tuple` — `(None, None)` 번호 없음 · `("#12", row)` · `("#12", None)` 캐시에 그 (브랜치, 번호) 줄 없음. 번호가 `-` 인 줄은 보지 않는다.

- [ ] **Step 1: 실패하는 테스트**

`class EpicPr(unittest.TestCase)` 에:
- `test_empty_section_has_no_header` — `render_machine(rel, empty())` 에 `"## 에픽 PR"` 이 없다.
- `test_roundtrip` — 줄 하나(`R14 · feature/x · #12 · 2026-10-23 10:00 · session-aaaa1111`)를 render → parse 하면 같다.
- `test_bad_number_rejected` — 번호 `12` · `#x` 에 `MachineError`, 메시지에 `#<숫자>`.
- `test_bad_epic_rejected` — 에픽 `r14` 에 `MachineError`.
- `test_duplicate_pair_rejected` — 같은 (에픽, 브랜치) 두 줄(번호만 다름)을 손으로 쓴 글을 `parse_machine` 하면 `MachineError`, 메시지에 `같은 (에픽, 브랜치)`. 다른 에픽의 같은 브랜치는 받는다(양의 짝).
- `test_recorded_cache_row_three_cases` — 번호 없음 `(None, None)`; 캐시에 `#12` 줄 `("#12", row)`; 같은 브랜치에 `#13` 만 있으면 `("#12", None)`; `-` 줄만 있어도 `("#12", None)`.

- [ ] **Step 2: RED 확인** — Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_conductor_state.py` → 새 테스트 FAIL(`AttributeError` 등)

- [ ] **Step 3: 구현** — `_check_row` 에 `에픽 PR` 갈래(번호는 `PR_NUMBER_RE`, 에픽은 `EPIC_RE` fullmatch). 같은 (에픽, 브랜치) 검사는 `parse_machine` 끝에서 한다(`save` 가 쓴 글을 다시 읽으므로 쓰기도 막힌다). 모듈 머리 설명의 담는 것 목록에 「에픽 PR 번호 기록」 을 더한다.

- [ ] **Step 4: GREEN** — 같은 명령, 전부 PASS. `bash plugins/spec-distill/tests/test_roadmap_status.sh` 도 GREEN(절이 비면 글이 그대로).

- [ ] **Step 5: 커밋** — `feat(spec-distill): 기계 상태에 에픽 PR 번호 절과 번호 찾기 함수`

---

### Task 3: gh 의 번호 묻기 · PR 참조 읽기 (AC1 바탕)

**Files:**
- Modify: `SD/scripts/gh_repo.py`
- Test: `SD/tests/test_gh_repo.py`

**Interfaces:**
- Produces:
  - `pr_view(cwd: str, number: int) -> dict` — `gh_json(cwd, ["pr", "view", str(number), "--json", ",".join(PR_FIELDS)])`. dict 가 아니거나 `PR_FIELDS` 칸이 빠지면 `GhStop("gh pr view 출력 모양이 다르다(PR #%d) — gh 판을 확인한다")`.
  - `parse_pr_ref(text: str) -> tuple | None` — `(번호:int, (host 소문자, owner, repo) | None)`. 앞뒤 공백을 벗긴 뒤 `re.fullmatch` 로: `\d+` · `#\d+` → `(n, None)`; `https?://<host>/<owner>/<repo>/pull/<n>` (끝 `/` 하나 허용) → `(n, (host, owner, repo))`. `n < 1` 이나 그 밖은 None.

- [ ] **Step 1: 실패하는 테스트**
- `test_pr_view_args` — `gh_json` 을 mock 해 받은 args 가 `["pr","view","12","--json","number,state,headRefName,headRefOid,isCrossRepository,baseRefName,mergeCommit"]`.
- `test_pr_view_shape_error` — `[]` · 칸 빠진 dict → `GhStop`, 메시지에 `PR #12`.
- `test_parse_pr_ref_forms` — `"12"` · `"#12"` · `" 12\n"` → `(12, None)`; `"https://github.com/Me/r/pull/12/\n"` → `(12, ("github.com", "Me", "r"))`; `"http://GHE.example/o/r/pull/3"` → host `ghe.example`; None: `"#"` · `"0"` · `"12abc"` · `"https://github.com/o/r/issues/3"` · `"https://github.com/o/r/pull/3/files"`.

- [ ] **Step 2: RED** — `python3 -m unittest plugins/spec-distill/tests/test_gh_repo.py` FAIL
- [ ] **Step 3: 구현** — 위 두 함수. 모듈 머리 설명에 한 줄.
- [ ] **Step 4: GREEN** — 같은 명령 PASS
- [ ] **Step 5: 커밋** — `feat(spec-distill): gh 번호로 PR 묻기와 PR 참조 읽기`

---

### Task 4: `ledger pr-record` (AC1 · AC20 쓰기 · AC3 `--drop`)

**Files:**
- Modify: `SD/scripts/conductor_ledger.py`
- Test: `SD/tests/test_conductor_ledger.py`

**Interfaces:**
- Consumes: `cs.EPIC_PR` · `gh_repo.pr_view` · `gh_repo.parse_pr_ref` · `gh_repo.origin_slug` · 기존 `need_holder` · `update` · `_status` · `_with_copy_branches` · `_block` · `_cache_row` · `now`
- Produces: 하위 명령 `pr-record --roadmap R --session S --epic E --pr <PR> [--drop]` → `c_pr_record(root, a) -> int`

**동작(차례대로):**
1. `parse_pr_ref(a.pr)` 가 None → `Fail(2, "PR 번호를 읽지 못했다: %r — PR URL 이나 숫자(예: --pr 123)를 준다")`.
2. `--drop`: gh 를 부르지 않는다. `update` 로 `에픽 == E ∧ 번호 == #n` 줄을 지운다. 지운 줄이 없으면 rc 1(「지울 번호 줄이 없다 — E · #n」), 있으면 rc 0.
3. `need_holder` (gh 전에). URL 이면 `origin_slug(root)` 와 host 소문자 · owner · repo casefold 비교 — 다르면 `Fail(4, "PR URL 의 레포(%s)가 origin(%s)이 아니다 — 아무것도 적지 않았다")` (gh 를 부르지 않는다).
4. 블록 해석은 `pr-refresh --epic` 과 같다: `_with_copy_branches(root, a.roadmap, _status(...)["blocks"], warns)` → `_block` → `branches` (없으면 `branch_states` 의 이름).
5. `pr_view(root, n)` (GhStop → `Fail(3, …)`). 기본 브랜치 짧은 이름은 `repo_defaults.default_branch(str(root))[1]` (사유가 있으면 `Fail(3, 사유)`).
6. 대조 — 하나라도 어긋나면 `Fail(4, …)` 이고 아무것도 쓰지 않는다. 메시지는 어긋난 칸 이름 · 기대 값 · gh 값을 담는다: `headRefName`(그 에픽의 브랜치 목록에 없음) · `isCrossRepository`(참) · `baseRefName`(기본 브랜치 아님 — 「쌓인 PR 이면 바탕을 기본 브랜치로 바꾼 직후 다시 적는다」 를 덧붙임).
7. 한 번의 `update` 로: `## 에픽 PR` 에서 같은 (E, head) 줄을 새 줄로 바꾸고(`적은 때` = `now()`, `쓴 세션` = 세션), `## PR` 에서 그 브랜치의 `#n` 줄과 「PR 0개」 줄을 빼고 `_cache_row(head, it, now(), session)` 을 더한다.
8. 출력 `번호를 적었다 — E · <head> · #n(PR 캐시 줄도 썼다)`, rc 0. 모듈 머리 설명에 명령 줄과 rc 4 의 넓힌 뜻을 적는다.

- [ ] **Step 1: 실패하는 테스트** — `class PrRecord(Repo)`: `setUp` 에서 `self.gh_origin()` · `claim`. `pr_view` 는 `mock.patch.object(L.gh_repo, "pr_view", fake)` 로 바꾸고 부른 번호를 센다. 기계 상태 바이트는 `L.mpath(self.w, RM).read_bytes()` 로 전후 비교.
  - `test_three_forms_record_one_row` — `--pr 7` · `--pr '#7'` · `--pr https://github.com/me/r/pull/7` 각각 rc 0, `## 에픽 PR` 이 `[("A1","feature/a1","#7")]` 한 줄(두 번째부터는 바뀜).
  - `test_head_mismatch_rc4_no_write` · `test_cross_repo_rc4_no_write` · `test_base_mismatch_rc4_no_write` — rc 4, 출력에 `headRefName` / `isCrossRepository` / `baseRefName`, 바이트 그대로.
  - `test_url_other_repo_rc4_without_gh` — `https://github.com/other/r/pull/7` → rc 4, `pr_view` 0번.
  - `test_unreadable_pr_rc2` — `--pr abc` → rc 2.
  - `test_without_marker_rc5_without_gh` — 다른 세션으로 claim 뒤 → rc 5, `pr_view` 0번.
  - `test_cache_row_written_and_replaced` (AC20) — 미리 `#7` 열림 줄과 「PR 0개」 줄을 둔 뒤 머지된 `#7` 을 적으면 그 브랜치 `## PR` 이 `#7 · 머지됨` 한 줄.
  - `test_copy_branch_head_accepted` (Review Focus 3) — `L._with_copy_branches` 를 A1 에 `feature/a1-2` 를 더하는 함수로 바꾸고 head `feature/a1-2` 인 PR 을 적으면 rc 0, 줄의 브랜치가 `feature/a1-2`.
  - `test_drop_removes_without_gh` · `test_drop_missing_rc1`.
- [ ] **Step 2: RED** — `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py` 새 테스트 FAIL
- [ ] **Step 3: 구현** — 위 동작. `COMMANDS` 에 `"pr-record": (c_pr_record, lambda p: (_rs(p), p.add_argument("--epic", required=True), p.add_argument("--pr", required=True), p.add_argument("--drop", action="store_true")))`.
- [ ] **Step 4: GREEN** — 같은 명령 전부 PASS
- [ ] **Step 5: 커밋** — `feat(spec-distill): ledger pr-record — 대조한 에픽 PR 번호와 캐시 줄을 쓴다`

---

### Task 5: `pr-refresh` 의 번호 줄 · 원장의 PR 읽기를 번호로 (AC3 · AC18 원장 셋)

**Files:**
- Modify: `SD/scripts/conductor_ledger.py` (`c_pr_refresh` · `_prs` · `c_pr_handoffs` · `c_audit` · `c_review_pack`)
- Test: `SD/tests/test_conductor_ledger.py`

**Interfaces:**
- Consumes: `cs.recorded_number` · `gh_repo.pr_view`
- Produces: `_prs(root, b: dict, epic_rows: list)` — 번호가 적힌 브랜치는 `gh_json(["pr","view",<숫자>,"--json","number,state,body"])` 한 건을 `(br, [it], False)` 로, 나머지는 지금 그대로. `_epic_rows(root, roadmap) -> list` = `load(root, roadmap, skip=("PR",))[cs.EPIC_PR]`(옛 PR 줄에 걸리지 않는다). 세 명령이 `_epic_rows` 를 읽어 넘긴다 — `c_audit` · `c_review_pack` 은 이미 있는 `try … except Fail` 안에서.

**`pr-refresh` 에 더하는 것(그 밖은 그대로):** 브랜치마다 그 블록 번호와 함께 센다. `load` 가 돌려준 `에픽 PR` 줄로 `recorded_number(epic_rows, 블록, br)` 이 있으면, head 목록에서 그 번호를 찾고 없으면 `pr_view` 로 받는다. 그 PR 의 `headRefName != br` 또는 `isCrossRepository` 가 참이면 그 번호를 그 브랜치의 새 줄에서 빼고(옛 `#N` 줄은 브랜치 줄 통째 교체로 사라진다) 아래 경고 한 줄을 낸다. 맞으면 그 줄을 목록에 더한다. rc 0.

경고(숫자 · 이름은 채운다): `[spec-distill] 적은 PR #<N> 이 <브랜치> 와 맞지 않는다(<칸>: <기대 값> ≠ <gh 값>) — 이 에픽의 PR 이면 \`ledger pr-record --roadmap <로드맵 값> --session <세션 값> --epic <에픽> --pr <번호>\` 로 다시 적고, 아니면 \`ledger pr-record --roadmap <로드맵 값> --session <세션 값> --epic <에픽> --pr <N> --drop\``

- [ ] **Step 1: 실패하는 테스트**
  - `PrRefresh` 에 더한다(번호 줄은 `L.update` 로 직접 적는다):
    - `test_recorded_number_kept_when_missing_from_list` — 목록 stub 은 `#9` 만, `pr_view(7)` 은 `#7` 머지됨 → `## PR` 에 `#7` · `#9` 둘.
    - `test_reset_keeps_epic_pr` — `--reset` 뒤 `## 에픽 PR` 그대로.
    - `test_mismatch_head_drops_only_that_row` — 먼저 맞는 `#7` 로 채운 뒤 `pr_view(7)` head 를 `feature/zz` 로 바꿔 다시 → rc 0; 그 브랜치 `## PR` 에 `#7` 없음 · `#9` 남음; `## 에픽 PR` 그대로; 다른 블록 브랜치 채워짐; 출력에 `적은 PR #7 이 feature/a1 와 맞지 않는다(headRefName: feature/a1 ≠ feature/zz)` · `--pr 7 --drop` · `--pr <번호>`; `cs.recorded_cache_row(...)` 가 `("#7", None)`; `control_plane.pr_cache_fingerprint` 가 전과 다르다.
    - `test_mismatch_cross_repo` — `isCrossRepository` 참 → 같은 갈래, 칸 이름 `isCrossRepository`.
    - `test_no_record_suggestion_without_records` — 번호 줄이 없으면 출력에 `pr-record` 가 없다.
    - `test_warning_has_no_bare_hash` — 경고 줄에 `--pr #` · `--pr '#` 가 없다.
  - `class RecordedPrs(Repo)` — gh stub 스크립트가 인자를 파일에 남기고 `pr view 7` 에는 `{"number":7,"state":"MERGED","body":"## 통합 리뷰 인계\n- seven"}`, `pr list` 에는 `#9`(열림 · 본문 `- nine`) 목록을 낸다. A1 에 `#7` 을 적어 둔다.
    - `test_handoffs_use_recorded_number` — `pr-handoffs --epic A1` 출력에 `#7` · `seven`, `#9` 없음; 인자에 `view` 있고 A1 브랜치의 `list` 없음.
    - `test_audit_and_review_pack_use_recorded_number` — `audit` 의 리뷰 뒤 반영 · `review-pack` 의 `handoffs.md` 에 `#9` 가 없다.
    - `test_unrecorded_branch_keeps_list` — A2(번호 없음)는 `pr list --head feature/a2` 그대로(양의 짝).
- [ ] **Step 2: RED** — 같은 unittest 명령, 새 테스트 FAIL
- [ ] **Step 3: 구현** — 위 Interfaces · 동작
- [ ] **Step 4: GREEN** — 같은 명령 PASS
- [ ] **Step 5: 커밋** — `feat(spec-distill): pr-refresh 가 적은 번호를 따로 받고 원장의 PR 읽기가 그 번호를 쓴다`

---

### Task 6: 상태 계산의 번호 판정 (AC4 · AC18 judge · AC19 · AC20 · Review Focus 4)

**Files:**
- Modify: `SD/scripts/roadmap_status.py`
- Test: `SD/tests/test_merged_by_pr.py` · `SD/tests/test_roadmap_status.sh` · `SD/tests/test_conductor_ledger.py`

**Interfaces:**
- Consumes: `cs.recorded_cache_row` · `cs.RECORDED_MISSING`
- Produces:
  - `read_pr_cache(git, roadmap_rel) -> tuple` = `(pr_rows, epic_pr_rows, 사유 | None)` (실패면 `([], [], 사유)`). `build` 가 받아 `compute(..., epic_pr_rows=…)` 로 넘긴다.
  - `merged_by_number(number: str, row: dict | None, branch_rows: list, tip, default_short, reachable, epic: str, roadmap_rel) -> tuple` = `(근거 | None, 정보 줄들, 경고 줄들)` — 순수 함수:
    - `row` None → `(None, [RECORDED_MISSING % number], [])`
    - `row` 가 머지됨 ∧ 교차 `아니오` ∧ base == `default_short`: mergeCommit `-` → `(None, ["PR <N> 은 머지됐지만 캐시에 mergeCommit 이 없어 머지됨으로 세지 않았다 — 지휘자를 돌려 PR 캐시를 다시 채운다"], [])`; `reachable(mc)` → 근거 `"PR <N> 머지됨(적은 번호로 판정 · mergeCommit <8자>)"`, `tip` 이 있고 `tip != row["headRefOid"]` 면 정보 `"머지 뒤 브랜치에 커밋이 더 붙었다(<tip 8자> ≠ PR 의 head <8자> — 번호 판정은 그대로)"`; 닿지 않으면 경고 `"%s — %s(PR %s)" % (PR_NOT_FETCHED, FETCH_HINT, N)`
    - 그 밖: 같은 브랜치의 다른 줄 가운데 머지됨 ∧ `아니오` ∧ 기본 base 가 있으면 경고 `"적은 PR <N> 은 <상태>이고 같은 브랜치의 PR <M> 이 머지됐다 — 그 PR 이 이 에픽의 PR 이면 \`ledger pr-record --roadmap <roadmap_rel 또는 <로드맵>> --session <세션> --epic <E> --pr <M 의 숫자>\`"`, 아니면 빈 줄들.
- `compute` 의 `judge(br, block, extra)`: `(block["id"], br)` 에 번호가 있으면 이 길만 탄다(`merged_by_tips` · `age_ok` · `_judge_pr` · `merged_by_git` 을 부르지 않는다). `tip` 은 로컬이 원격의 조상이면 원격, 아니면 로컬 또는 원격. 줄은 `"<br>: "` 를 붙여 notes · warnings 에 싣고, 머지됨이면 지금과 같은 `reverts_of` 경고. 결정 기록 머지 줄의 「적용하지 않았다」 조건과 `unchecked_note` 는 번호 있는 브랜치를 캐시 줄이 있는 브랜치처럼 다룬다(「PR 상태 미확인」 을 달지 않는다).

- [ ] **Step 1: 실패하는 테스트**
  - `test_merged_by_pr.py` `class MergedByNumber`: 위 갈래마다 하나(없음 · `-` · 닿음 + 끝 같음(정보 없음) · 닿음 + 끝 다름(정보) · 닿지 않음(경고) · 열림/닫힘/다른 base/교차는 근거 None · 다른 줄 머지 경고에 `--pr 12` 가 있고 `--pr #` 가 없음).
  - `test_roadmap_status.sh` 새 절 「번호 판정(AC4)」 — 기존 `write_machine` 옆에 `write_machine_epic <machine.md> <rel> <PR 줄 파일> <에픽 PR 줄 파일(에픽|브랜치|#N)>` 도우미를 두고, 임시 레포에서 기존 S30 · B30 픽스처 꼴로 넷을 만든다:
    - (가) 같은 이름의 옛 브랜치 머지 커밋이 기본 브랜치 첫째 부모 줄에 있고 적은 PR 이 열림 → 단계가 머지됨이 아니다. 같은 픽스처에서 번호 줄만 지우면 머지됨(대조 — 틈 ① 이 번호로 닫힌 것). 대조가 머지됨이 되도록 견줄 커밋이 없게 만든다(블록 문서를 기본 브랜치에 두지 않고, 로컬 없이 원격 ref 가 옛 머지의 둘째 부모를 가리킨다).
    - (나) 로컬 브랜치 없이 문서가 첫 머지보다 뒤에 들어왔고 적은 PR 이 squash 머지됨(원격 끝 == 캐시 `headRefOid`, 끝은 기본 브랜치의 조상 아님) → 머지됨, 근거에 `적은 번호로 판정`, `커밋이 더 붙었다` 없음.
    - (다) 적은 PR 닫힘 · 같은 브랜치 다른 PR 머지됨 → 머지됨 아님 + 경고에 `ledger pr-record` 와 `--pr <M 숫자>`.
    - (라) 머지 뒤 커밋이 더 붙음 → 머지됨 + `머지 뒤 브랜치에 커밋이 더 붙었다`. 대조: rebase 머지 뒤 끝 == `headRefOid` 면 그 줄 없음.
    - 번호가 캐시에 없음 → 정보 줄 `PR #<N> 이 PR 캐시에 없다`, 「PR 상태 미확인」 없음.
    - AC18 판정 몫: 적은 `#N` 머지됨(squash, head H1) + 같은 브랜치 새 열림 `#M`(끝 H2) → 머지됨, 근거에 `#N`. 커밋한 뒤 변이: 사본 `roadmap_status.py` 에서 `recorded_cache_row(` 호출 결과를 `(None, None)` 으로 바꾸면 이 단언이 RED(변이 적용 `cmp` 확인).
    - 기존 stub 락(상태 계산이 gh 를 부르지 않는다)이 GREEN.
  - `test_conductor_ledger.py` `class RecordThenStatus(Repo)`: 기본 브랜치에 머지 커밋을 만들고 그 oid 를 mergeCommit 으로 낸 `pr_view` 로 `pr-record` → `pr-refresh` 없이 `L._status` 의 A1 단계가 머지됨, 근거에 `적은 번호로 판정`(AC20). `pr-refresh --reset`(목록 stub 이 같은 PR) 뒤에도 같다(AC19). `test_drop_returns_to_name_path` — `--drop` 뒤 근거에 `적은 번호` 가 없다(Review Focus 4).
- [ ] **Step 2: RED** — `python3 -m unittest plugins/spec-distill/tests/test_merged_by_pr.py plugins/spec-distill/tests/test_conductor_ledger.py` · `bash plugins/spec-distill/tests/test_roadmap_status.sh` 새 단언 FAIL
- [ ] **Step 3: 구현** — 위 Interfaces
- [ ] **Step 4: GREEN** — 같은 명령 PASS, 기존 PR · 머지 단언 전부 GREEN(AC5)
- [ ] **Step 5: 커밋 → 변이 확인 → (변이 단언 커밋)** — `feat(spec-distill): 적은 번호가 있는 브랜치는 그 PR 로만 머지를 판정한다`

---

### Task 7: 기계 상태를 못 읽으면 머지 판정 보류 (AC21 — 지휘자 덧붙임 1)

**Files:**
- Modify: `SD/scripts/roadmap_status.py` (`compute`)
- Test: `SD/tests/test_roadmap_status.sh` · `SD/tests/test_conductor_ledger.py`

**동작:** `pr_reason` 이 있으면 `judge` 는 모든 브랜치에 `st["uncountable"] = "<br>: 머지 판정 보류 — 기계 상태를 읽지 못해 PR 번호 기록이 있는지 모른다(<pr_reason>)"` 를 두고 돌아간다(이름 · 이력 추정을 부르지 않는다 — 블록은 「알 수 없음」, rc 3). 이때 `unchecked_note` 는 「PR 상태 미확인」 정보 줄을 달지 않고 지금의 캐시 경고(`PR 캐시를 읽지 못했다 — …`)만 단다. 파일이 없으면(`pr_reason` None) 지금 그대로.

- [ ] **Step 1: 테스트 — 바뀌는 기존 기대와 새 단언**
  - `test_roadmap_status.sh` 의 「깨진 기계 상태」 단언(지금 1566 · 1571 · 1572줄 근처): 「PR 상태 미확인」 → `assert_not_contains`, rc `1` → `3`, 단계 `준비` → `알 수 없음` + 사유에 `머지 판정 보류`. 「옛 판 4칸 줄」 의 rc `1` → `3` 과 사유에 `--reset`. 경고 단언(사유 · 경로 · 할 일)은 그대로.
  - 새 픽스처: 이 레포 소유자의 머지 문면과 머지 커밋이 있는 같은 이름 브랜치 + 깨진 기계 상태 → 단계가 머지됨이 아니고 `알 수 없음`. 양의 짝: 같은 레포에서 기계 상태 파일을 지우면 머지됨(옛 추정), 정상 파일인데 그 브랜치의 번호 줄이 없어도 지금 길.
  - `test_conductor_ledger.py` `test_reset_lifts_hold_on_old_rows` (Review Focus 1): 옛 4칸 줄을 쓴 기계 상태에서 `L._status` 의 브랜치 블록이 `알 수 없음` 이고 사유에 `--reset` → `pr-refresh --reset`(목록 stub) rc 0 → 보류가 풀린다.
- [ ] **Step 2: RED** — `bash plugins/spec-distill/tests/test_roadmap_status.sh` · ledger unittest 의 새 · 바뀐 단언 FAIL
- [ ] **Step 3: 구현** — 위 동작
- [ ] **Step 4: GREEN** — 같은 명령 PASS
- [ ] **Step 5: 커밋** — `fix(spec-distill): 기계 상태를 못 읽으면 이름 추정 대신 머지 판정을 보류한다`

---

### Task 8: 상태줄 · 상태 보기의 한 출처와 지문 (AC18 control_plane · AC6 지문)

**Files:**
- Modify: `SD/scripts/control_plane.py` (`pr_fact` · `merged_prs` · `overlay` · `pr_cache_fingerprint`)
- Test: `SD/tests/test_control_plane.py` · `SD/tests/test_control_plane.sh`

**Interfaces:**
- `pr_fact(rows, branch, default_short, missing, first="열림", epic=None, epic_rows=()) -> dict` — `cs.recorded_cache_row(epic_rows, rows, epic, branch)` 에 번호가 있으면 이름으로 고르지 않는다: 줄이 있으면 `{"number": 줄 번호, "state": 줄 상태, "source": "PR 캐시 — 적은 번호"}`, 없으면 `{"number": N, "state": "알 수 없음", "source": "PR %s 캐시에 없음 — 지휘자를 돌려 캐시를 채운다" % N}`. 번호 없으면 지금 그대로.
- `merged_prs(b, rows, default_short, epic_rows=())` — `pr_fact(..., epic=b.get("id"), epic_rows=epic_rows)`.
- `overlay` 가 `(machine or {}).get("에픽 PR", [])` 를 두 자리에 넘긴다.
- `pr_cache_fingerprint(machine)` — `## PR` 줄들 + `"에픽 PR" + SEP + 칸들` 줄들을 정렬해 sha256. 에픽 PR 줄이 없으면 지금과 같은 값.

- [ ] **Step 1: 실패하는 테스트**
  - `test_control_plane.py`: `test_fingerprint_includes_epic_pr` — `{"PR":[a]}` 와 `{"PR":[a],"에픽 PR":[]}` 같음, 번호 줄 하나 더하면 다름. `test_pr_fact_uses_recorded` — 같은 브랜치에 머지된 `#7`(적음)과 더 새 열림 `#9` → `#7`; 번호 없으면 `#9`(양의 짝); 캐시에 없으면 `알 수 없음` + `PR #7 캐시에 없음`. `test_merged_prs_uses_recorded` — 같은 픽스처에서 `#7`.
  - `test_control_plane.sh` 새 절 「AC18 한 출처」: 위 픽스처를 python 한 덩이로 돌려 `pr_fact` · `merged_prs` 가 `#7` 을 내는지 본 뒤, 커밋한 사본 두 변이 — (1) `pr_fact` 안의 `recorded_cache_row(` 호출을 `(None, None)` 으로 (2) `merged_prs` 가 `epic_rows` 를 넘기지 않게 — 마다 RED(변이 적용 `cmp` 확인).
- [ ] **Step 2: RED** — `python3 -m unittest plugins/spec-distill/tests/test_control_plane.py` · `bash plugins/spec-distill/tests/test_control_plane.sh` FAIL
- [ ] **Step 3: 구현** — 위 Interfaces
- [ ] **Step 4: GREEN** — 같은 명령 PASS, `test_roadmap_approval.py` 도 GREEN
- [ ] **Step 5: 커밋** — `feat(spec-distill): 상태줄 · 상태 보기가 적은 번호의 PR 줄을 쓰고 지문에 넣는다`

---

### Task 9: 번호 판정 공시 — NOTICE · README (AC5)

**Files:**
- Modify: `SD/scripts/roadmap_status.py` (`NOTICE`) · `SD/README.md` (상태 계산 줄 · `## 한계`)
- Test: `SD/tests/test_roadmap_status.sh`

**글(설계문서 §2 그대로):**
- `NOTICE` 의 첫 문장 뒤와 README 상태 계산 줄(`scripts/roadmap_status.py <로드맵 경로>` 불릿)의 「머지됨은 PR 상태로 판정합니다(…)」 뒤에: 「지휘자가 PR 을 열 때 번호를 적은 에픽은 그 PR 로만 머지를 판정한다. 번호가 없는 에픽(이 판 전에 연 PR · 지휘자 밖에서 연 PR · 번호 기록이 없는 다른 기계)은 브랜치 이름과 이력으로 알아보며, 같은 이름의 옛 브랜치가 머지됨으로 보이거나 머지된 에픽이 빠지는 틈이 남는다. 번호 기록은 기계 상태라 이 기계에만 있다.」 (README 는 합니다체로 같은 뜻.) README 의 「R14 로 미룬 틈이고 풀 장치는 정해지지 않았습니다」 괄호는 「번호를 적지 않은 에픽에 남는 틈입니다」 로 바꾼다.
- `## 한계` 첫 줄(공시) 다음 불릿 자리에 §2 의 U8 두 줄을 글 그대로(첫 줄 공시는 그대로 첫 줄).

- [ ] **Step 1: 실패하는 테스트** — `test_roadmap_status.sh`: `NOTICE` 에 `번호를 적은 에픽은 그 PR 로만 머지를 판정한다` · `이 기계에만`; README 상태 계산 줄에 같은 뜻의 두 구절; README `## 한계` 에 U8 두 줄이 줄 그대로(`grep -qxF`); `## 한계` 의 첫 비지 않은 줄은 그대로 `WRITER_TRUST_NOTICE`(Task 12 가 문장을 바꿔도 같은 상수로 비교).
- [ ] **Step 2: RED** · **Step 3: 구현** · **Step 4: GREEN** — `bash plugins/spec-distill/tests/test_roadmap_status.sh` · `bash shared/tests/test_writer_trust_notice.sh`
- [ ] **Step 5: 커밋** — `docs(spec-distill): 번호 판정과 번호 없는 에픽의 틈을 공시한다`

---

### Task 10: 지휘 절차의 번호 적기 (AC2 · AC17 · AC19 문장 — 지휘자 덧붙임 2 · 3)

**Files:**
- Modify: `SD/references/conducting.md`
- Test: `SD/tests/test_conducting_reference.sh`

**바꾸는 문장(`<…>` 는 문서의 자리표 그대로):**
- `## 지휘 순환` 머리 불릿 하나 더: 「에픽 PR 번호는 PR 을 열 때(걸음 4)와 쌓인 PR 의 바탕을 기본 브랜치로 바꾼 직후(걸음 5)에만 `ledger pr-record` 로 적는다 — 번호 없는 PR 을 찾아 적는 걸음은 없고, 그 밖의 PR(손으로 연 PR · 이 판 전에 연 PR)은 지휘 세션이 `ledger pr-record --roadmap <로드맵> --session <세션> --epic <에픽> --pr <번호>` 를 한 번 부른다(번호는 숫자만). `ledger pr-refresh` 가 「적은 PR #N 이 <브랜치> 와 맞지 않는다」 경고를 내면 그 줄의 두 명령 가운데 하나를 부른다 — 이 에픽의 PR 이면 다시 적고, 아니면 `--drop` 으로 번호 기록을 지운다.」
- 걸음 4: `gh pr create -R …` 로 PR 을 열고 → 「그 출력의 마지막 줄(PR URL)로 `ledger pr-record --roadmap <로드맵> --session <세션> --epic <에픽> --pr <그 URL>` 을 부른 뒤」 → 지금의 `pr-refresh … --epic <에픽>\` 으로 PR 캐시를 채운다` 문장(기존 락 글자 그대로 둔다). 이어서: 「PR 이 이미 있어 `gh pr create` 가 실패하면 그 PR 의 번호를 `--pr <번호>`(숫자만)로 적고 그 판단과 이유를 보인다. 앞 계획의 브랜치를 바탕으로 연 쌓인 PR 이면 `pr-record` 가 종료 코드 4 로 거부한다 — 예상된 결과이고 멈출 오류가 아니다. 적지 않고 넘어가고 걸음 5 가 바탕을 바꾼 직후에 적는다.」
- 걸음 5 「쌓인 PR」 불릿 끝에: 「바탕을 기본 브랜치로 바꾼 직후, 머지 명령을 준비하기 전에 `ledger pr-record --roadmap <로드맵> --session <세션> --epic <에픽> --pr <번호>` → `ledger pr-refresh --roadmap <로드맵> --session <세션> --epic <에픽>` 을 부른다.」(「바탕 브랜치를 지우면 위 PR 이 닫히고 다시 열 수 없다」 는 한 번 그대로 — `test_conducting_loop.sh` 락)
- 걸음 7 기계 상태: 「`## 에픽 PR` 은 남기고 나머지를 비운다(남은 자원 · agent · 쌓인 기록이 없을 때) — 에픽 PR 번호 기록은 다시 만들 수 없고, 정리 뒤에도 상태 계산이 같은 번호로 머지를 판정한다.」
- 손 절차 5(덧붙임 3 — **새로 더한다**): 「Push · PR 을 연다(`gh pr create -R …`)」 뒤에 「— 그 출력의 마지막 줄(PR URL)로 `python3 "<SD>"/scripts/conductor_ledger.py pr-record --roadmap <로드맵> --session <세션> --epic <에픽> --pr <그 URL>` 을 부른 뒤 `python3 "<SD>"/scripts/conductor_ledger.py pr-refresh --roadmap <로드맵> --session <세션> --epic <에픽>` 으로 PR 캐시를 채운다(표지는 `claim` 으로 먼저 잡는다). 쌓인 PR 이면 `pr-record` 가 종료 코드 4 로 거부한다 — 예상된 결과이고, 걸음 8 이 바탕을 바꾼 직후 적는다.」
- 손 절차 8(덧붙임 2): 쌓인 PR 문장 끝에 걸음 5 와 같은 꼴(긴 `python3 "<SD>"/scripts/conductor_ledger.py` 형)으로 「바탕을 기본 브랜치로 바꾼 직후, 머지 명령을 준비하기 전에 `… pr-record … --pr <번호>` → `… pr-refresh … --epic <에픽>` 을 부른다.」

- [ ] **Step 1: 실패하는 테스트** — `test_conducting_reference.sh` 에(기존 `before` · `cyc` · `step` · `pr_by_hand` 를 쓴다):
  - 순서(AC2): `cyc 4` 와 `step 5` 각각 `gh pr create` → `pr-record` → `pr-refresh` 가 `before` 로 yes, 뒤집은 합성 글로 no(양성 대조).
  - 순서(AC17): `cyc 5` 와 `step 8` 각각 `pr-record --roadmap` → `pr-refresh` → `머지 명령` 이 yes, 뒤집은 글로 no.
  - `cyc 4` · `step 5` 에 `종료 코드 4` 와 `예상된 결과` 가 있다.
  - 부재(AC17 · 8ce8e648): `cyc 1` 과 `step 1` 에 `pr-record` 가 없다 — 양성 대조: 그 글에 `ledger pr-record` 를 넣으면 잡는다.
  - 머리 불릿에 `--drop` 과 「맞지 않는다」 가 있다.
  - AC19: `cyc 7` 에 「`## 에픽 PR` 은 남기고」 가 있고, `에픽 PR[^.]*(지운|비운)` 꼴 문장이 없다(합성 「`## 에픽 PR` 도 비운다」 로 양성 대조).
  - AC2: `pr_by_hand` GREEN 그대로; `--section "에픽 PR"` · `--section '에픽 PR'` 손 적기 부재 + 양성 대조(합성 줄을 넣으면 잡는다).
  - 명령 예시에 `--pr #` 가 없다.
- [ ] **Step 2: RED** · **Step 3: 구현** · **Step 4: GREEN** — `bash plugins/spec-distill/tests/test_conducting_reference.sh` · `test_conducting_loop.sh` · `test_repo_literals.sh` · `test_epic_conductor_skill.sh` · `test_entry_guidance.sh` 모두 GREEN
- [ ] **Step 5: 커밋** — `docs(spec-distill): 지휘 절차가 PR 을 열 때와 바탕을 바꾼 직후 번호를 적는다`

---

### Task 11: 락 지도 단언과 골든 · 핸드오프 예약 (AC8)

**Files:**
- Modify: `SD/tests/test_roadmap_status.sh` (`lock_rows`) · `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md` · 같은 폴더 `R14.md`(`roadmap_write.py update` 가 쓴다)

**Interfaces:** `lock_rows(text, blocks)` 의 위반 조건에 `and cells[2] not in reach[b["id"]]`(`reach = rs._reachable(blocks)`) — 예약한 에픽이 줄의 에픽에 (건너서라도) 의존하면 위반이 아니다.

- [ ] **Step 1: 실패하는 테스트** — 실데이터 절에 양성 대조 넷(`copy.deepcopy(blocks)` 로 R14 예약에 `shared/tests/fixtures/docreview/golden/` 를 더한 `blocks2`):
  - `lock_rows("| shared/tests/fixtures/docreview/golden/case_T05_T06_reject.gate.txt:2 | x | R12 | y |", blocks2)[1] == []`
  - 기존 `LOCKCTL`(R2 줄 · R1 예약) 그대로 위반.
  - 반대 방향: `| shared/tests/fixtures/docreview/golden/x.txt:1 | x | R14 | y |` + 실제 blocks → R12 예약으로 위반.
  - 의존 없는 두 에픽: `| plugins/spec-distill/scripts/gh_repo.py:1 | x | R9 | y |` → R14 예약으로 위반.
- [ ] **Step 2: RED** — `bash plugins/spec-distill/tests/test_roadmap_status.sh` 첫 단언 FAIL
- [ ] **Step 3: 구현 · GREEN · 커밋** — 조건 한 줄. GREEN 확인 뒤 커밋(`test(spec-distill): 락 지도 단언이 의존 순서로 끝난 에픽의 줄을 위반으로 세지 않는다`). 사본에 조건을 지우는 변이를 걸어 첫 대조가 RED 인지 본다.
- [ ] **Step 4: 예약 더하기** — 커밋 0e803d5a 의 꼴(`roadmap_write.py extract` 로 표를 뽑아 R14 행 `경로 예약` 에 `shared/tests/fixtures/docreview/golden/` · `plugins/spec-distill/tests/test_review_handoff_order.sh` 를 더하고 `update --change "R14 경로 예약에 골든 폴더와 test_review_handoff_order.sh — 락 지도 단언을 고친 뒤" --approval "승인하고 계획으로 (권장)"`)을 따른다. 그 뒤 실데이터 `LOCKBAD` = `[]` · `OVERLAPS` 기존 단언 그대로 GREEN.
- [ ] **Step 5: 커밋** — `docs(roadmap): R14 경로 예약에 골든 폴더와 핸드오프 순서 테스트`

---

### Task 12: 쓰는 세션을 믿는 한계 공시를 쉬운 말로 (AC7)

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py` (`WRITER_TRUST_NOTICE`) · `shared/tests/fixtures/docreview/golden/*.gate.txt` · `*.gate.json`(각 다섯) · `SD/README.md` (`## 한계` 첫 줄 · 바로 뒤 세 불릿)
- Test: `shared/tests/test_writer_trust_notice.sh`

**글:** 새 상수(설계문서 §3 그대로): `리뷰 기록과 그 안의 사용자 말은 이 대화가 직접 쓴다 — 기록을 리뷰 명령 밖에서 고치면 확인값이 안 맞는 경우만 잡히고, 확인값까지 맞춰 그럴듯하게 고친 것은 잡히지 않는다`. README 세 불릿은 §3 의 세 줄 글 그대로. 골든 열 파일은 옛 문장을 새 문장으로 글자 그대로 바꾼다(다른 바이트는 그대로).

- [ ] **Step 1: 테스트 먼저 바꾼다** — `EXPECTED` 를 새 문장으로, 샌드박스 · `declare-related` 두 줄 기대를 §3 글로. 더한다: `NOTICE` 에 `원장` · `엔진` · `요약값` 이 없다; 진입 skill 셋(`request-framing` · `reviewing-brief` · `spec-review`) 폴더에 `NOTICE` 글이 없다(`grep -rlF`) — 양의 짝은 이미 있는 「렌더 셋째 줄이 공시」 단언.
- [ ] **Step 2: RED** — `bash shared/tests/test_writer_trust_notice.sh` FAIL
- [ ] **Step 3: 구현** — 상수 · README · 골든 열 파일(옛 → 새 치환 뒤 `git diff --stat` 이 열 파일 · 한 줄씩인지 본다)
- [ ] **Step 4: GREEN** — `bash shared/tests/test_writer_trust_notice.sh` · `test_docreview_gate_plain.sh` · `test_docreview_state.sh` · `test_docreview_gate_visibility.sh` PASS
- [ ] **Step 5: 커밋** — `fix(docreview): 쓰는 세션을 믿는 한계 공시를 쉬운 말로`

---

### Task 13: 인터뷰 다음 세션 줄의 superpowers 판 확인 (AC12)

**Files:**
- Modify: `SD/skills/pm-interview/references/finishing.md` (B-3 「다음 세션 줄 — ①/② 공통」 · 「다른 다음 단계의 줄」)
- Test: `SD/tests/test_review_handoff_order.sh`

**글:** brief 줄의 첫 문장(「…Skill superpowers:brainstorming 을 시작하라.」) 바로 뒤에 설계문서 §6 의 문장 그대로: `brainstorming 을 불러온 직후 첫 메시지 전에 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_deps.py superpowers --plugin-root ${CLAUDE_PLUGIN_ROOT} --base 에 그 skill 을 불러올 때 보인 기준 폴더 경로를 넘겨 한 번 돌리고, 첫 줄이 「검증한 판과 같다」 가 아니면 그 줄을 첫 메시지에 한 줄로 보인다 — 판 확인 결과로는 멈추지 않는다.` 「다른 다음 단계의 줄」 문단에: 「고른 skill 이 `superpowers:` 로 시작하면 위 brief 줄의 판 확인 문장도 `brainstorming` 을 그 skill 이름으로 바꿔 싣는다.」 (`check_deps.py superpowers` 의 같은 판 첫 줄은 `[spec-distill] superpowers <판> — 검증한 판과 같다` 로 끝난다 — 계획 때 확인함.)

- [ ] **Step 1: 실패하는 테스트** — `$ONE` 에 `check_deps.py superpowers --plugin-root` 와 `판 확인 결과로는 멈추지 않는다` 가 있고, `order` 로 「시작하라.」 → `check_deps.py` → `spec-distill:spec-review`. 「다른 다음 단계의 줄」 문단에 `superpowers:` · `판 확인 문장`. 기존 머리 · 순서 · `lead_only` 단언 GREEN. 커밋 뒤 변이: 사본 finishing.md 에서 그 문장을 지우면 RED.
- [ ] **Step 2: RED** · **Step 3: 구현** · **Step 4: GREEN** — `bash plugins/spec-distill/tests/test_review_handoff_order.sh` · `test_finishing_block_scope.py` · `test_superpowers_presence.sh` PASS
- [ ] **Step 5: 커밋** — `feat(spec-distill): 인터뷰 다음 세션 줄이 superpowers 판을 확인하게 한다`

---

### Task 14: 해결자의 거부 둘 — 콜론 없는 머리말 줄 · 폴더 값 특수 글자 (AC9 · AC10)

**Files:**
- Modify: `SD/scripts/repo_defaults.py` (`strict_frontmatter` · `_folder`)
- Test: `SD/tests/test_repo_defaults.py`

**Interfaces:**
- `strict_frontmatter`: 비지 않고 `line[0]` 이 공백 · 탭 · `-` · `#` 이 아닌 줄에 `:` 가 없으면 `SettingsError("unreadable", where, "%s 의 머리말에 \`키: 값\` 꼴이 아닌 줄이 있다(%s) — \`키: 값\` 으로 고치거나 지운다" % (at, line))`.
- `_folder`: 값에 `* ? [ ] \` 가 있거나 `:` 로 시작하면 `(None, "%s 에 글롭 · pathspec 특수 글자(%s)를 쓰지 않는다 — git 이 경로를 글자 그대로 읽지 않는다: %r")`(찾은 글자는 처음 본 차례로 ` · ` 로 잇는다).

- [ ] **Step 1: 실패하는 테스트** — `test_colonless_line_unreadable_repo` · `test_colonless_line_unreadable_roadmap`(kind `unreadable`, 메시지에 그 줄); `test_skipped_lines_still_skipped`(들여쓴 줄 · `- x` · `# x` · 빈 줄은 통과); `test_real_roadmaps_pass`(레포 `docs/superpowers/roadmaps/*/roadmap.md` 와 레포 설정 파일이 있으면 그것을 `strict_frontmatter` 로 읽어 오류 없음); `test_folder_special_chars` — `*` · `?` · `[` · `]` · `\` · 앞 `:` 마다 `merge_layers` 의 errors 에 키 이름과 그 글자, 값 None; `test_colon_inside_folder_ok`(`docs/a:b/` 받음 — Review Focus 5); `test_pattern_keeps_bracket`(`test_failure_pattern: "^\\[x\\]"` 받음); 기본값 · 보통 폴더 통과.
- [ ] **Step 2: RED** — `python3 -m unittest plugins/spec-distill/tests/test_repo_defaults.py` FAIL
- [ ] **Step 3: 구현** · **Step 4: GREEN** — 같은 명령 + `bash plugins/spec-distill/tests/test_repo_defaults_git.sh` · `test_roadmap_status.sh` PASS
- [ ] **Step 5: 커밋** — `fix(spec-distill): 해결자가 콜론 없는 머리말 줄과 폴더 값의 글롭 글자를 거부한다`

---

### Task 15: `ledger add --section "레포 설정"` 이 읽는 쪽이 거부할 값을 받지 않는다 (AC11 · §7 기계 층 오타 키)

**Files:**
- Modify: `SD/scripts/merge_check.py` · `SD/scripts/conductor_ledger.py` (`c_add`) · `SD/references/conducting.md`
- Test: `SD/tests/test_conductor_ledger.py` · `SD/tests/test_merge_check.sh` · `SD/tests/test_conducting_reference.sh`

**Interfaces:**
- `merge_check.pattern_error(pattern: str) -> str | None` — `re.compile(pattern, re.M)` 의 `re.error` 글, 아니면 None. `run` 이 이 함수를 부른다(문구 그대로).
- `c_add`: `a.section == "레포 설정"` 이면 쓰기 전에, 하나라도 걸리면 rc 2 이고 기계 상태는 바이트 그대로:
  1. 같은 키가 이미 있다 → `"레포 설정 절에 %s 가 이미 있다 — 바꾸려면 \`ledger drop --roadmap %s --session %s --section \"레포 설정\" --where 키=%s\` 로 지운 뒤 다시 적는다"`
  2. `repo_defaults.check_layer({키: 값}, "machine")` 의 `SettingsError` 글
  3. `repo_defaults.merge_layers(None, None, None, {키: 값}, [])` 의 `errors` 첫 줄(빈 값)
  4. 키가 `test_failure_pattern` 이면 합친 값에 `merge_check.pattern_error` (함수 안에서 import)
- conducting.md 걸음 5 rc 6 문장의 `ledger add … "test_command · <명령>"` 괄호 뒤에 「같은 키를 바꿀 때는 drop 뒤 add 한다」.

- [ ] **Step 1: 실패하는 테스트**
  - ledger `class RepoSettingsAdd(Repo)`: `test_duplicate_key_rc2` (출력에 `ledger drop` · `--where 키=test_command`) · `test_layer_key_rc2`(`specs_dir`) · `test_unknown_key_rc2`(`test_comand`) · `test_empty_value_rc2`(`""`) · `test_bad_pattern_rc2`(`[`) — 넷 모두 기계 상태 바이트 그대로; `test_reader_function_drives_writer` — `merge_check.pattern_error` 를 mock 해 늘 오류를 내면 맞는 정규식도 rc 2; `test_end_to_end_merge_check_accepts` — 이 명령으로 쓴 기계 상태를 `cs.repo_settings_rows` 와 `merge_layers` 가 오류 없이 읽는다.
  - `test_merge_check.sh`: 기계 상태 층에 오타 키(`test_comand`)를 손으로 둔 레포에서 `merge_check.py run` rc 3, 출력에 `모르는 키`.
  - `test_conducting_reference.sh`: `cyc 5` 에 「같은 키를 바꿀 때는 drop 뒤 add 한다」.
- [ ] **Step 2: RED** · **Step 3: 구현** · **Step 4: GREEN** — 세 테스트 파일 PASS
- [ ] **Step 5: 커밋** — `fix(spec-distill): ledger add 가 읽는 쪽이 거부할 레포 설정을 쓰지 않는다`

---

### Task 16: 작은 동작 빈틈 셋 (AC13 동작)

**Files:**
- Modify: `SD/scripts/check_bundle_coverage.py` (`Repo.specs_for`) · `SD/scripts/roadmap_status.py` (`_GitTreeRepo`) · `SD/scripts/state_path.py` (`_check_state_root`) · `SD/scripts/repo_defaults.py` (check-path 의 `choices`)
- Test: `SD/tests/test_bundle_coverage.sh` · `SD/tests/test_state_root.sh` · `SD/tests/test_repo_defaults_git.sh`

**Interfaces:**
- `Repo.specs_for(self, source: str, specs_dir: str) -> list` · `_GitTreeRepo.__init__(self, git, tree, specs_dir: str)` · `_GitTreeRepo.specs_for(self, source, specs_dir=None)` 는 `specs_dir or self.specs_dir` — `SPECS_DIR` 기본값 갈래를 지운다(쓰지 않게 된 import 도).
- `_check_state_root`: `common.name == ".git"` 다음에 `git --git-dir <common> config --bool core.bare` 출력이 `true` 면 `return`(추적 검사를 건너뛴다).
- check-path `choices=("roadmaps_dir", "interview_dir")`.

- [ ] **Step 1: 실패하는 테스트** — `test_bundle_coverage.sh`: python 한 줄로 `Repo(...).specs_for("x")` 와 `_GitTreeRepo(git, tree)` 가 `TypeError`. `test_state_root.sh`: 위 bare 픽스처의 worktree 에서 `python3 "$SP" state-root --ensure` rc 0 · 상태 폴더가 생긴다(지금은 할 일 없는 멈춤 문장). `test_repo_defaults_git.sh`: `check-path specs_dir x` rc 2(사용법 오류), `roadmaps_dir` · `interview_dir` 그대로.
- [ ] **Step 2: RED** · **Step 3: 구현** · **Step 4: GREEN** — 세 파일 + `test_roadmap_status.sh` · `test_ledger_root.sh` PASS
- [ ] **Step 5: 커밋** — `fix(spec-distill): specs_dir 필수 · .git 이름 bare 레포 · check-path 키 좁힘`

---

### Task 17: 작은 문구 · 락 빈틈 여섯 (AC13 나머지)

**Files:**
- Modify: `SD/scripts/roadmap_model.py` (`blob_reader`) · `SD/scripts/control_plane.py` (`cat_batch` · `candidates`) · `SD/scripts/conductor_ledger.py` (`c_roadmaps`) · `SD/tests/test_repo_literals.sh` · `SD/tests/test_ledger_root.sh` · `SD/tests/test_finish_commit_roadmap.sh`
- Test: 위 테스트 파일들 · `SD/tests/test_control_plane.py` · `SD/tests/test_control_plane.sh` · `SD/tests/test_repo_defaults_git.sh`

**각 항목:**
1. **`--root` 글자 접두** — `test_repo_defaults_git.sh`: 레포를 가리키는 링크 `L` 을 만들고 `check-path interview_dir "$L/<인터뷰 폴더>/x.md" --root "$L"` rc 0; 대조: `--root <실제 경로>` 에 같은 링크 경로면 rc 3(레포 밖).
2. **1b 이름표** — `test_finish_commit_roadmap.sh` 1b 머리를 「1b. cwd 가 다른 레포(다른 interview_dir · 기본 브랜치 모름)여도 brief 레포에 세 파일과 로드맵 폴더를 커밋하고 cwd 레포에는 커밋하지 않는다」 로.
3. **ReadFailed 사유** — `cat(sha)` 계약을 `(rc, 바이트 | None)` 으로: `rc != 0` → 「파일을 읽지 못했다(git cat-file rc %d)」, `rc == 0` 에 None → 「파일을 읽지 못했다(git cat-file --batch 출력에 이 blob 이 없다 — 짧게 읽음)」. `cat_batch` 는 `(got, rc)` 를 돌려주고 `candidates` 의 람다는 없는 blob 에 `(rc, None)`. 테스트(`test_control_plane.py`): rc 0 짧은 읽기 사유에 `짧게 읽음` · `rc 128` 없음, rc 128 이면 `rc 128`.
4. **검사 불가 사유** — `c_roadmaps` 는 `"%s\t검사 불가 — %s"` 로 사유를 단다(머리말을 못 읽은 후보는 `find_roadmaps` 의 사유, 상태 계산 실패는 `unknown_reasons` · `format_errors` 첫 줄 또는 「상태 계산 출력을 읽지 못했다(rc N)」). 테스트(`test_control_plane.sh` 의 기존 `ledger_list` 자리): 그 후보 줄에 `검사 불가 — ` 와 사유. 첫 칸(`cut -f1`) 비교는 그대로.
5. **재대입** — `test_repo_literals.sh` `covered_vars` 뒤: 판정받은 변수를 첫 판정 줄과 `git add` 사이에서 다시 대입하면 덮지 않은 것으로 보고 `"%s:%d: git add 경로 $%s 를 판정 뒤 다시 대입한다"` 를 낸다. 변이(`shape_mut`): request-framing 핸드오프 펜스의 `git add` 줄 앞에 `AUDIT="$SEED"` 를 넣으면 그 사유가 나온다.
6. **`|| :`** — `test_ledger_root.sh` 부재 단언을 `--ensure.*\|\|[[:space:]]*(true|:)([[:space:]]|$|;)` 로. 양성 대조: 합성 줄 `… --ensure)" || :` 를 잡고, `|| ROOT=""` 꼴(지금 문서)은 잡지 않는다.

- [ ] **Step 1: 실패하는 테스트** — 항목마다 위 단언
- [ ] **Step 2: RED** — 해당 테스트 파일들 FAIL
- [ ] **Step 3: 구현** — 항목 3 · 4 의 코드, 1 · 2 · 5 · 6 은 테스트 글
- [ ] **Step 4: GREEN** — `bash` 로 `test_repo_defaults_git.sh` · `test_finish_commit_roadmap.sh` · `test_control_plane.sh` · `test_repo_literals.sh` · `test_ledger_root.sh`, `python3 -m unittest plugins/spec-distill/tests/test_control_plane.py plugins/spec-distill/tests/test_roadmap_model.py` PASS
- [ ] **Step 5: 커밋** — `fix(spec-distill): 짧은 읽기 · 검사 불가 사유와 락 빈틈 넷`

---

### Task 18: `put_snap` 실패 수가 서브셸에서 사라지지 않게 (AC14)

**Files:**
- Modify: `shared/tests/fixtures/docreview/cases.sh` · `shared/tests/test_writer_trust_notice.sh`(이미 `cases.sh` 를 source 하고 `# guards:` 에 품는다)

**꼴:** `x="$(put_snap "$d" "$s" && py docreview_state.py begin-round … | jgets …)"` → `put_snap "$d" "$s" && x="$(py docreview_state.py begin-round … | jgets …)"`. `assert_eq "$(put_snap … && py …)" …` 도 `put_snap … && assert_eq "$(py …)" …`. 지금 18 자리 모두. 40줄 주석에 「`$(...)` 안에서 부르지 않는다 — 실패 수가 서브셸에서 사라진다」 를 더한다.

- [ ] **Step 1: 실패하는 테스트** — `cases.sh` 에 `case_put_snap_failure_counted`: 원장의 문서를 공유 픽스처(`$FX/design-sample.md`)로 `init` 한 상태 폴더에 다른 스냅숏으로 바뀐 꼴의 한 줄(`put_snap "$d" "$s" && r="$(py … begin-round …)"`)을 돌려 `_ASSERT_FAIL` 이 정확히 1 늘었는지 보고, 그 1 을 되돌린 뒤 `ok`/`no` 로 낸다. 같은 줄을 옛 꼴(`r="$(put_snap … && …)"`)로 돌리면 늘지 않음을 대조로 보인다. `test_writer_trust_notice.sh` 에서 이 케이스를 부르고, `cases.sh` 전체에 `$(put_snap` 이 0개(개수를 박지 않는다) + 합성 줄로 양성 대조.
- [ ] **Step 2: RED** — `bash shared/tests/test_writer_trust_notice.sh` FAIL(부재 단언)
- [ ] **Step 3: 구현** — 18 자리
- [ ] **Step 4: GREEN** — `test_writer_trust_notice.sh` 와 `cases.sh` 를 source 하는 나머지(`test_docreview_state.sh` · `_anchor` · `_gate_visibility` · `_intent` · `_route` · `_advice` · `_gate_plain` · `_mutations` · `test_adjudication_behavior.sh`) PASS
- [ ] **Step 5: 커밋** — `test(docreview): put_snap 을 서브셸 밖에서 불러 실패 수를 잃지 않는다`

---

### Task 19: 판 · CHANGELOG · 전체 대조 · 마지막 리뷰 (AC16)

**Files:**
- Modify: `SD/.claude-plugin/plugin.json` · `SD/CHANGELOG.md` · `plugins/quality-gates/.claude-plugin/plugin.json` · `plugins/quality-gates/CHANGELOG.md`

- [ ] **Step 1: 판** — 이 브랜치에 기본 브랜치를 merge 한 뒤 그 위의 판에서 spec-distill 다음 minor(지금 8.8.0 → 8.9.0), quality-gates 다음 patch(14.7.0 → 14.7.1). CHANGELOG 에 `## [<판>] — <날짜>` 로 Added(`ledger pr-record` · `## 에픽 PR` · 번호 판정) · Changed(깨진 기계 상태에서 판정 보류 — rc 3 · 공시 문장 · 해결자 거부 · `check-path` 키 좁힘 · `ledger add` 레포 설정 거부 · 다음 세션 줄) · Fixed(작은 빈틈). 옛 판이 `## 에픽 PR` 줄이 있는 기계 상태를 읽으면 「모르는 절」로 멈춘다는 사실을 Changed 에 적는다. qg CHANGELOG 는 공유 엔진 공시 문장 한 줄. 판 번호는 머지 직전에 지휘자가 다시 정할 수 있다.
- [ ] **Step 2: 전체 스위트** — `for f in plugins/*/tests/*.sh shared/tests/*.sh; do bash "$f" >/dev/null 2>&1 || echo "RED $f"; done` 와 `python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_*.py'` 를 이 브랜치와 기본 브랜치 사본에서 돌려 실패 이름을 대조한다. 이 브랜치에만 있는 실패는 0.
- [ ] **Step 3: 커밋** — `chore(spec-distill): 판과 CHANGELOG`
- [ ] **Step 4: 마지막 전체 리뷰** — 실행 방식의 마지막 리뷰에 설계문서 `## Acceptance Criteria` 의 AC 목록(AC1 · AC17 · AC2 · AC3 · AC4 · AC5 · AC19 · AC20 · AC18 · AC6 · AC21 · AC7 · AC8 · AC9 · AC10 · AC11 · AC12 · AC13 · AC14 · AC15 · AC16)을 싣고, AC 마다 한 줄 `AC1: 구현됨 — 근거` 꼴(판정은 구현됨 · 미룸 · 빠짐 중 하나)로 보고하게 한다. 리뷰에 끝에서 끝 흐름(`pr-record` → `pr-refresh` → 상태 계산 → 상태줄)과 rc 소비(pr-record rc 4 를 예상된 결과로 읽는 절차)를 따로 묻는다. 보고는 git 이 추적하지 않는 파일(`$TMPDIR` 아래)에 적는다.
- [ ] **Step 5: 미룸 · 대조** — 미룸 · 빠짐과 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올려 커밋하고, PR 을 만들기 전에 `python3 <spec-distill 플러그인 루트>/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-10-23-r8-device-leftovers-design.md <보고 파일>` 의 경고를 보고에 싣는다. 머지 메뉴는 「브랜치 그대로 두기」 — Push · PR 은 지휘 세션이 한다. 마지막 보고에 판정 목록 전체와 AC 보고 내용 전체를 싣는다.
