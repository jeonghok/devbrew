# R9 계획 2 — 지출 승인을 규모 공시로 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 모든 `cost_class: high` skill 이 크게 쓰기 전에 규모를 한 줄로 알리고 진행하게 한다 — epic-conductor 시작 승인 · plugin-audit 지출 동의 · artifact-critique E3 의 지출 문장을 걷고, 범위 고르기 질문은 남기며, 규칙(CLAUDE.md:51 · 철학 P22)과 락을 같은 PR 에서 바꾼다.

**Architecture:** 장치 쪽을 먼저 걷고(기계 상태가 옛 `## 시작 승인` 을 읽되 버림 → 원장의 승인 하위 명령 제거 → 세 skill 문면), 마지막에 규칙 문장과 새 공유 락 `shared/tests/test_cost_disclosure.sh` 를 한 커밋으로 세운다. 옛 기계 상태 · 옛 감사 데이터는 계속 읽힌다.

**Tech Stack:** Python 3.9 표준 라이브러리(argparse · unittest), macOS bash 3.2 셸 테스트, Markdown.

**Spec:** `docs/superpowers/specs/2026-10-23-rules-docs-cleanup-design.md` (§2 · §3 · §4 · §8 · AC11~AC21 · `### Deferred to plan`)

**구현 브랜치:** `feature/cost-scale-disclosure` — 계획 1(`feature/rules-docs-cleanup`)의 PR 이 머지된 뒤 기본 브랜치에서 새로 만든다(쌓은 PR 없음). 그때는 R14 도 머지돼 있다.

## Global Constraints

- **확정 문안(U8):** CLAUDE.md:51 과 P22 본문 두 줄은 설계 §2 의 펜스를 글자 그대로 옮긴다. 낱말 하나라도 바꿔야 하면 멈추고, 바꾼 문안을 사용자에게 다시 보여 승인받는다 — 승인 전에는 바꾼 문안을 커밋하지 않는다(그 질문은 지휘자에게 두 부분으로 돌려보낸다).
- **판 번호(AC20):** 머지 시점 기본 브랜치의 판에서 — spec-distill · plugin-audit minor(동작 변경 · 하위 명령 제거), quality-gates patch. CHANGELOG `Removed` 에 `approval` · `approve` · 이름 붙인 예외 · 지출 동의 질문을 적는다(사용자가 명시 결정한 재건 — deprecation 창 없음).
- git: merge 만 · HEAD 를 뒤로 옮기지 않는다 · 커밋은 pathspec · `git stash` 금지 · 공유 임시 폴더 glob 삭제 금지 · 다른 worktree 의 git 금지.
- 커밋 메시지: `type(scope)` 영어 · 설명 한국어. 끝에 `Spec: docs/superpowers/specs/2026-10-23-rules-docs-cleanup-design.md` 와 세션이 주는 `Co-Authored-By:` · `Claude-Session:` 줄.
- 셸: `/bin/bash`(3.2) · `$var` 뒤 한글은 `${var}` · 새 셸 테스트는 `chmod +x` 뒤 `git ls-files -s` 로 `100755`.
- 파이썬: 3.9 · `encoding="utf-8"` 명시 · `plugins/**/*.py` 에 `"python3"` 리터럴 금지 · 테스트는 `PYTHONDONTWRITEBYTECODE=1`.
- **변이(AC19):** 테스트 먼저 · RED 확인 · 커밋 뒤 변이(삭제 · 추가 · 반전 · 형태 변경) · 양성 대조 · 복원은 `git checkout HEAD -- <파일>` 뒤 `git diff HEAD --quiet`. 음의 락에는 양의 짝.
- **전체 스위트:** 계획 1 과 같은 공유 잠금 줄 — `LOCK="$(python3 plugins/spec-distill/scripts/conductor_ledger.py suite-lock --roadmap docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md | head -1)"`, `python3 plugins/spec-distill/scripts/suite_lock.py run --lock "$LOCK" --owner <이름> --wait 1800 -- bash -c 'bash tools/suite/run-all.sh > <출력> 2>&1'`. 하위 agent 에게도 이 줄을 싣는다. 기록 폴더 `$HOME/.claude/sdd-mirror/r9/`.
- **공통 공시 문장:** 세 skill 의 공시 자리는 모두 `지출 승인을 묻지 않는다` 를 쓴다 — CLAUDE.md · P22 의 「어느 클래스의 skill(스킬)도 지출 승인을 묻지 않는다」 와 같은 낱말이다. 새 락의 (나) 갈래가 이 문장을 절 안에서 잰다(머리로 만족되지 않게).
- 예약 밖 편집 둘(설계 Files to Modify): `plugins/spec-distill/tests/test_reviewing_brief_skill.sh`(:73 메시지) · `plugins/spec-distill/references/conducting.md`(:14 괄호). 경로 예약 정보 줄을 받아들인다.
- persona · 리뷰어 프로필은 고치지 않는다.

## 설계와 다른 점 · 설계에 없던 결정

- claim(새로 잡을 때) · takeover 는 바꾸지 않는 `update` 를 돈다(설계 §3 의 계획 판단 — 첫 claim 이 기계 상태 파일을 만든다고 `test_upgrade_path_claim_then_reset_then_claim` 이 기대한다). release 는 표지만 푼다 — 기계 상태를 읽지 않는다.
- 공통 공시 문장은 설계 §3 의 「지출을 이유로 묻지 않는다」 대신 `지출 승인을 묻지 않는다` 다(`### Deferred to plan` — 규칙과 세 skill 이 같은 낱말).
- `RETIRED_SECTIONS` 는 `parse_machine` 의 `skip` 기본값에 얹지 않고 따로 갈래를 둔다 — `skip` 은 부르는 쪽이 고르는 인자라 기본값에 얹으면 부르는 쪽이 넘긴 `skip` 이 그것을 덮는다.
- `_normalized` 도 `RETIRED_SECTIONS` 를 빈 목록으로 둔다 — `save` 의 다시 읽기 대조가 render 의 생략과 같은 모양을 본다.
- plugin-audit 의 `## phase 0 — consent` 머리는 `## phase 0 — 범위 고르기` 로 바꾼다(파일 · 키 이름 `consent` 는 그대로).
- 새 락의 금지 문구는 `지출 동의` · `지출 전 명시` · `지출-전 명시` · `지출 승인 게이트` · `승인 전에는 agent 를 보내지 않는다` · `이름 붙인 예외` 여섯이다. 「지출 승인」 낱말 자체는 공시 문장(`지출 승인을 묻지 않는다`)이 쓰므로 금지하지 않는다.

## Review Focus

1. **이 판보다 옛 플러그인이 쓴 `machine.md`(`## 시작 승인` 절과 행이 있다).** 지휘 재개가 「모르는 절」로 막히면 안 되고, 다음 저장에서 그 절이 사라져야 한다. Task 1 `test_old_machine_with_start_approval_is_read_and_dropped` 와 Task 2 `test_claim_rewrites_old_machine_without_start_approval` 가 잠근다.
2. **옛 감사 데이터의 `approved` 가 `true` 가 아닌 값(`false` · 문자열 `"true"`).** 거절이나 잘못 적힌 기록이 지나가면 안 된다. Task 4 `test_consent_approved_string_is_red` 가 잠근다.
3. **옛 4칸 PR 줄이 있는 기계 상태에서 claim · takeover.** rc 3 과 다시 채우기 안내를 내고 파일 바이트는 그대로여야 한다(쓰지 않음). Task 2 `test_old_pr_row_stops_claim_and_takeover_without_writing` 이 잠근다.
4. **plugin-audit 첫 질문에서 「중단」.** 실행 디렉토리 · agent 가 없어야 한다 — 문면 순서로만 잴 수 있다. Task 4 `test_scope_question_has_stop_before_run_dir` 가 잠근다.
5. **설치 캐시에 남은 옛 SKILL 이 `conductor_ledger.py approval` 을 부른다.** argparse 의 모르는 하위 명령 rc 2 와 사유가 나와야 한다(조용히 0 이 아니다). Task 2 `test_retired_subcommands_are_unknown` 이 잠근다.

---

### Task 0: 자리 · 기준선 · 가벼운 다시 확인

**Files:** 없음

- [ ] **Step 1:** 계획 1 의 PR 이 머지됐는지 본다(`gh pr list --state merged --head feature/rules-docs-cleanup`). 머지 전이면 멈추고 보고한다. 머지됐으면 `git fetch origin && git switch -c feature/cost-scale-disclosure origin/main`(지휘자가 이미 만들었으면 그 브랜치에 서서 `git merge --ff-only origin/feature/cost-scale-disclosure`).
- [ ] **Step 2:** 공유 잠금 아래 전체 스위트 → `$HOME/.claude/sdd-mirror/r9/plan2-baseline.txt`.
- [ ] **Step 3: 다시 확인.** 설계가 적은 자리(§2~§4 의 줄 번호 — ad7efbb6 기준)가 계획 1 · R14 머지 뒤 바뀌었는지 `plan2-recheck.md` 에 표로 적는다. 함께: `git grep -n '시작 승인' -- plugins shared ':!*CHANGELOG*'` 로 기계 상태 `시작 승인` 절을 읽는 곳이 `conductor_ledger.py` · `conductor_state.py` 뿐인지(설계 `## 상류 · 하류 연계`), `git grep -n -e 'approval' -e 'approve' -- plugins/spec-distill/scripts plugins/spec-distill/references plugins/spec-distill/skills` 에서 원장 하위 명령을 부르는 다른 자리가 있는지. 설계와 다르면 보고한다.

---

### Task 1: `conductor_state` — 옛 `## 시작 승인` 을 읽되 버린다 (AC14 상태 부분)

**Files:**
- Modify: `plugins/spec-distill/scripts/conductor_state.py`(docstring :6 · `SECTIONS` 뒤 · `parse_machine` · `render_machine` · `_normalized`)
- Test: `plugins/spec-distill/tests/test_conductor_state.py`
- R14(#254)가 이 파일에 `EPIC_PR` 절을 더했다 — `SECTIONS` · `OPTIONAL_SECTIONS` · `parse_machine` · `recorded_number` · `recorded_cache_row` 의 R14 줄은 남긴다. `RETIRED_SECTIONS` 는 그 옆에 더한다. `test_conductor_state.py` 의 R14 단언도 남긴다.

**Interfaces:**
- Produces: `RETIRED_SECTIONS: tuple = ("시작 승인",)` — `SECTIONS` 에 남은 채 읽기에서 줄 검사 없이 버리고, 쓰기에서 머리를 쓰지 않는 절.

- [ ] **Step 1: 옛 꼴 상수.** 고치기 전 지금 코드로 `render_machine(RM, data)`(`data = empty()` 에 `data["시작 승인"] = [{"세션": <테스트 세션>, "때": "2026-10-18 10:00", "규모": "남은 에픽 2 · agent 약 6"}]`)를 돌린 글을 테스트 파일 상수 `OLD_MACHINE` 에 그대로 붙인다 — 이 판이 쓴 진짜 옛 꼴이다.
- [ ] **Step 2: 실패하는 테스트.**
  - `test_old_machine_with_start_approval_is_read_and_dropped` — `parse_machine(OLD_MACHINE, RM)` 이 오류 없이 `data["시작 승인"] == []`. 같은 글을 파일로 두고 표지를 잡아 `load` → `save` 하면 파일에 `## 시작 승인` 이 없고 다른 절 머리는 그대로다.
  - `test_new_file_has_no_start_approval_heading` — `render_machine(RM, empty())` 에 `## 시작 승인` 이 없고, 그 글을 `parse_machine` 이 읽는다.
  - `test_retired_rows_are_not_checked` — `## 시작 승인` 아래 칸 수가 틀린 줄(`- 하나뿐`)도 오류가 아니다(검사 없이 버린다).
  - 머리말 `writer` 가 더 새 판이면 멈추는 것은 기존 `test_newer_writer_stops_older_reader` 가 잰다 — 고치지 않는다.
- [ ] **Step 3:** `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_conductor_state.py'` — 첫째 · 둘째 RED(지금은 절을 읽어 행을 담고, 빈 절 머리도 쓴다), 셋째 RED(칸 수 오류).
- [ ] **Step 4: 구현.** `RETIRED_SECTIONS = ("시작 승인",)` 를 `OPTIONAL_SECTIONS` 옆에 둔다. `parse_machine` 은 `if cur in skip: continue` 다음에 `if cur in RETIRED_SECTIONS: continue`. `render_machine` 의 절 고리 첫머리에 `if name in RETIRED_SECTIONS: continue`. `_normalized` 는 그 절을 채우지 않는다(빈 목록). docstring 의 `· 시작 승인(같은 세션 이어 부르기 공시)` 를 뺀다.
- [ ] **Step 5:** 상태 테스트 전체 GREEN · `bash plugins/spec-distill/tests/test_roadmap_status.sh` · `python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_control_plane*.py'`(있는 것) GREEN.
- [ ] **Step 6: 커밋** — `feat(spec-distill): 기계 상태가 옛 시작 승인 절을 읽되 버리고 쓰지 않는다`.
- [ ] **Step 7: 변이.** `parse_machine` 의 버림 갈래 삭제 → 첫째 RED(행이 담긴다). `render_machine` 의 생략 삭제 → 둘째 RED. `RETIRED_SECTIONS` 를 `SECTIONS` 에서도 지움(형태 변경) → 「모르는 절」로 첫째 RED.

---

### Task 2: `conductor_ledger` — 승인 하위 명령을 걷고 claim · takeover 검사는 남긴다 (AC14 원장 부분)

**Files:**
- Modify: `plugins/spec-distill/scripts/conductor_ledger.py`(docstring :13 · `scale_check` · `_drop_approval` · `c_claim` · `c_takeover` · `c_release` · `c_approval` · `c_approve` · 하위 명령 표)
- Test: `plugins/spec-distill/tests/test_conductor_ledger.py`
- R14(#254)가 이 파일에 넣은 줄(에픽 PR 번호 판정·기록 쪽)은 남긴다. `test_conductor_ledger.py` 의 R14 단언도 남긴다.

**Interfaces:**
- Consumes: Task 1 의 `RETIRED_SECTIONS` 동작(다시 쓸 때 그 절이 사라진다).
- Produces: `_check_state(root, a) -> None` — 표지를 쥔 세션으로 `update(root, a.roadmap, a.session, lambda d: None)`. 읽기에서 멈추면 `Fail(3, …)`(쓰지 않는다).

- [ ] **Step 1: 실패하는 테스트.** `StartApproval` 클래스와 `ApprovalMarker` 의 승인 단언 넷(`test_no_marker_needs_approval` · `test_held_stays_disclosure` · `test_release_then_claim_needs_approval` · `test_takeover_by_other_invalidates`), `PrRefresh` 의 `test_skill_reset_branch_drops_stale_approval_and_unblocks_approval` · `test_reset_then_claim_without_release_keeps_stale_approval` 를 지운다. `ApprovalMarker` 의 `test_other_cannot_add` · `test_drop_where_needs_equals` 는 승인과 무관한 성질이라 `MarkerWrites` 클래스로 옮기고 `approved()` 대신 `claim` 만 부른다. 새로 둔다:
  - `test_retired_subcommands_are_unknown` — 서브프로세스로 `[sys.executable, <conductor_ledger.py>, "--root", w, cmd, "--roadmap", RM, "--session", SID, "--scale", "x"]`(cmd ∈ approval · approve): rc 2, stderr 에 `invalid choice` 와 `'approval'`(또는 `'approve'`)이 함께 있다.
  - `test_claim_takeover_release_still_work` — claim `(0, "acquired")` 뒤 기계 상태 파일이 있다 · OTHER takeover rc 0 · OTHER release `표지를 풀었다`.
  - `PrRefresh.test_old_pr_row_stops_claim_and_takeover_without_writing` — claim · release · `write_old_row()` 뒤 바이트를 잡아 두고, claim rc 3 + `--reset 으로 다시 채운다` · 바이트 같음 · 표지 주인 SID, OTHER takeover rc 3 · 바이트 같음.
  - `PrRefresh.test_claim_rewrites_old_machine_without_start_approval` — 기계 상태 파일을 Task 1 의 `OLD_MACHINE` 꼴(옛 행 하나)로 쓰고 표지 없이 claim → `(0, "acquired")`, 파일에 `## 시작 승인` 이 없다.
  - `test_upgrade_path_claim_then_reset_then_claim` 은 고치지 않는다.
- [ ] **Step 2:** `python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_conductor_ledger.py'` — 새 테스트 중 rc 2 · 다시 쓰기 단언 RED.
- [ ] **Step 3: 구현.** `scale_check` · `c_approval` · `c_approve` · 표의 `"approval"` · `"approve"` 두 줄 · docstring 의 `approval | approve …` 줄을 지운다. `_drop_approval` 을 `_check_state` 로 바꾸고(docstring 한 줄: 「표지를 새로 쥐거나 넘겨받은 뒤 기계 상태를 읽어 검사하고 같은 내용을 다시 쓴다 — 깨졌거나 옛 판 줄이면 쓰지 않고 rc 3」), `c_claim` 의 `acquired` 갈래와 `c_takeover` 가 부른다. `c_release` 는 부르지 않는다(표지만 푼다).
- [ ] **Step 4:** 원장 테스트 전체 GREEN · `bash plugins/spec-distill/tests/test_conductor_e2e.sh` 는 Task 3 에서 고친다(여기서는 approval 줄 때문에 RED 일 수 있다 — 그 줄만이 RED 인지 본다).
- [ ] **Step 5: 커밋** — `feat(spec-distill)!: 원장의 시작 승인 하위 명령을 걷는다 — claim · takeover 는 기계 상태를 검사한다`.
- [ ] **Step 6: 변이.** `c_takeover` 의 `_check_state` 호출 삭제 → takeover rc 3 단언 RED. `_check_state` 를 `load` 만 하게(쓰지 않음) → `test_upgrade_path…` · 다시 쓰기 단언 RED(설계 §3 계획 판단의 근거를 실측). 하위 명령 표에 `"approval"` 을 되살림 → rc 2 단언 RED.

---

### Task 3: epic-conductor 4절 「규모 공시」 · 3절 표지 풀기 · e2e (AC13 · AC14 skill 부분)

**Files:**
- Modify: `plugins/spec-distill/skills/epic-conductor/SKILL.md`(:29 · 3절 · 4절)
- Modify: `plugins/spec-distill/references/conducting.md`(:14 괄호 하나 — 예약 밖)
- Test: `plugins/spec-distill/tests/test_epic_conductor_skill.sh`(:32-44 · :97 · :128 · 4절 옛 PR 캐시 갈래 락) · `plugins/spec-distill/tests/test_conductor_e2e.sh`(:42-47 · :114)

- [ ] **Step 1: 실패하는 단언.** `APP="$(sec '### 4. 규모 공시')"`. 리터럴(양): `'남은 에픽'` · `'agent 약'` · `'라운드마다 부르는 리뷰어 agent'` · `'spec 리뷰는 라운드마다 리뷰어 agent 둘 이상, 엔진의 재리뷰 상한까지(사용자가 더 열 수 있다)'` · `'구현 안 agent 수는 task 수에 따라 — 상한 없음'` · `'규모 줄을 보이고 5 로 간다 — 지출 승인을 묻지 않는다.'`. 부재(음): `'conductor_ledger.py" approval'` · `'conductor_ledger.py" approve'` · `` '`AskUserQuestion`' `` · `'conductor_ledger.py" release'` · `'승인 전에는 agent 를 보내지 않는다'` · `'이름 붙인 예외'`. 순서: `규모 줄 하나를 만든다` 가 `규모 줄을 보이고 5 로 간다` 앞. 세션 펜스 수 단언(:97)을 `-ge 4` 「(claim · takeover · 다시 채우기 · release)」로. :128 의 `assert_contains "$APP" 'conductor_ledger.py" release'` 를 3절 단언으로 옮긴다 — 3절 펜스 가운데 `pr-refresh` 가 없고 `python3 "$SD/scripts/conductor_ledger.py" release --roadmap "<로드맵>" --session "$sid"` 를 담는 펜스가 정확히 하나이고 `[ -n "$sid" ] ||` 멈춤을 가진다. `default_rc` 줄 리터럴(`'`claim_rc=0` 이면'` · `'`conductor_ledger.py" release`'` · `'돌린 뒤 멈춘다'`)은 그대로 두고 `'4 끝의'` 부재를 더한다. 4절의 `approval_branch_check` 블록과 그 변이 고리는 지운다(3절 `reset_branch_check` 는 그대로). `assert_not_contains "$(sec '### 3. 자리 · 세션 · 표지')" '옛 시작 승인'` 와 conducting.md 에 대한 `assert_not_contains "…conducting.md 내용…" '옛 시작 승인이 지워진다'` 를 더한다(conducting 의 「다시 채운 뒤 `ledger release` → `ledger claim`」 양성 단언은 그대로).
  e2e 의 2 단계는 `# 2 — 표지 · 규모 공시(원장에 승인 하위 명령이 없다)` 로: claim rc 0 · 기계 상태 파일이 생겼다 · `L approval …` 의 rc 가 2. :114 는 `L claim …` rc 0 으로 바꾸고 「시작 승인을 다시 묻는다」 단언을 지운다.
- [ ] **Step 2:** 두 테스트 RED.
- [ ] **Step 3: 4절 문면.** 머리를 `### 4. 규모 공시` 로. `control_plane.py show` 펜스는 그대로. 규모 줄 문장의 꼴을 `` `남은 에픽 <n>(<번호 목록>) · agent 약 <n> · 순서 <번호 → 번호 …> · spec 리뷰는 라운드마다 리뷰어 agent 둘 이상, 엔진의 재리뷰 상한까지(사용자가 더 열 수 있다) · 구현 안 agent 수는 task 수에 따라 — 상한 없음` `` 으로(설계 §3), 이어지는 agent 수 설명 · 「같은 상태에서는 같은 줄이 나오게 이 꼴 그대로 쓴다.」는 그대로. 그 뒤 `규모 줄을 보이고 아래 펜스로 승인 상태를 본다.` 부터 4절 끝(이름 붙인 예외 문단)까지를 `규모 줄을 보이고 5 로 간다 — 지출 승인을 묻지 않는다. 그 뒤의 dispatch 도 띄우기 전에 규모만 알리고 간다.` 한 문단으로 바꾼다.
- [ ] **Step 4: 3절 · :29 · conducting.md.** `default_rc` 줄의 `4 끝의 표지 풀기 펜스` 를 `아래 표지 풀기 펜스` 로. 3절 끝(다시 채우기 처리 줄 뒤, `### 4.` 앞)에 `표지 풀기 — 위에서 표지를 잡은 채 멈출 때 이 펜스로 푼다.` 한 줄과 옛 4절의 release 펜스(루트 가드 · 세션 id 멈춤 · `cd "<root>" && python3 "$SD/scripts/conductor_ledger.py" release --roadmap "<로드맵>" --session "$sid"`)를 옮긴다. 다시 채우기 줄 끝의 `(새로 잡아야 이 세션의 옛 시작 승인이 지워진다)` 를 지운다. :29 의 `진입 · 시작 승인 · 차례` 를 `진입 · 규모 공시 · 차례` 로. `conducting.md` :14 의 `(새로 잡아야 그 세션의 옛 시작 승인이 지워진다)` 괄호만 지운다(그 걸음은 남긴다).
- [ ] **Step 5:** 두 테스트 GREEN · `bash plugins/spec-distill/tests/test_conducting_reference.sh` · `bash plugins/spec-distill/tests/test_conducting_loop.sh` · 3~4절 펜스 공유 락(`test_epic_conductor_skill.sh` 가 부르는 `shared/tests/test_skill_*` 넷) GREEN.
- [ ] **Step 6: 커밋** — `feat(spec-distill)!: 지휘자 시작 승인을 규모 공시로 — 규모 줄에 리뷰 라운드 상한과 상한 없는 부분`.
- [ ] **Step 7: 변이.** 4절에 옛 approval 펜스를 되살림 → RED. 공시 문장 삭제 → RED. 3절 release 펜스 삭제(가리키는 펜스가 사라짐) → RED. 규모 줄 꼴에서 `상한 없음` 칸 삭제(형태 변경) → RED.

---

### Task 4: plugin-audit — 범위 고르기 · 규모 공시 · 동의 기록 (AC15)

**Files:**
- Modify: `plugins/plugin-audit/skills/plugin-audit/SKILL.md`(description :7 · `## phase 0` 머리 · step 2 끝 · step 3 · step 4 · Workflow 근거 :238)
- Modify: `plugins/plugin-audit/scripts/validate-audit-data.py`(docstring :6 · `validate_data` 의 consent 검사)
- Modify: `plugins/plugin-audit/scripts/prepare-run-dir.py`(docstring :2) · `plugins/plugin-audit/scripts/audit-workflow.js`(주석 :31 · :691)
- Modify: `plugins/plugin-audit/README.md`(:19 · :23-24 · :93 · :100) · `plugins/plugin-audit/tests/README.md`(:14)
- Test: `plugins/plugin-audit/tests/test_skill_orchestration.py` · `plugins/plugin-audit/tests/test_validate_audit_data.py`

- [ ] **Step 1: 실패하는 테스트 — 문면.** `test_skill_orchestration.py`:
  - `INVARIANTS` 의 `"AskUserQuestion"` 주석을 `# 축 고르기 질문(범위)` 으로.
  - `test_run_dir_made_after_consent` 를 `test_scope_question_has_stop_before_run_dir` 로: 앵커 `scope = "「여섯 축 전부 (권장)」 · 「축 골라서」 · 「중단」"` · `stop = "「중단」이면 종료한다 — 실행 디렉토리를 만들지 않는다"` · `disclose = "(b) **규모 공시** — 질문이 아니라 한 줄이다"` · `prep = 'scripts/prepare-run-dir.py" <target>'` 가 각 한 번이고 `scope < stop < disclose < prep`.
  - `test_consent_gate_announces_axes_and_scale` 를 `test_scope_and_disclosure_announce_axes_and_scale` 로: `start = body.index("3. **범위 고르기 · 규모 공시")`, 절은 `"4. **실행 디렉토리**"` 앞까지. 있음 — 「여섯 축 전부 (권장)」 · 「축 골라서」 · 「중단」 · `감사자 6 · 반박 최대 6` · `아무것도 띄우지 않고 실행 디렉토리도 만들지 않는다` · `상한 없음` · `심층검증` · 보안 축 경고 · 「검증 안 됨」 · `지출 승인을 묻지 않는다`. 없음 — `최대 8` · `약 30` · `6축` · `` AskUserQuestion`으로 명시 승인 `` · `「승인」 · 「중단」` · `지출 동의`. 본문에 `{at, fanout, axes}` 가 있고 `{approved, at, fanout, axes}` 가 없다.
  - `test_workflow_reason_is_user_invocation` — Workflow 절에 `사용자가 \`/plugin-audit:plugin-audit\` 를 부른 것이 이 Workflow 의 명시 요청이다. 모델은 이 skill 을 부르지 않는다(\`disable-model-invocation: true\`).` 가 있고 `cost_class 게이트 통과 후` 가 없다.
- [ ] **Step 2: 실패하는 테스트 — 검증기.** `test_validate_audit_data.py`: `test_consent_without_approved_passes`(VALID 에서 `approved` 키를 지움 → rc 0) · `test_consent_mismatch_is_red`(이미 있는 `approved: False` → rc 1, 오류 글에 `meta.consent.approved`) · `test_consent_approved_string_is_red`(`"true"` → rc 1) · 옛 픽스처(`approved: True`)는 기존 VALID 단언이 GREEN 으로 잰다.
- [ ] **Step 3:** 두 파일 RED(없는 앵커 · `approved` 없음이 지금은 오류).
- [ ] **Step 4: SKILL 문면.** description :7 의 `지출 동의 게이트·정적 게이트·…` 를 `범위 고르기 · 규모 공시·정적 게이트·Workflow·결정론 post-1 조립을 소유한다.` 로. `## phase 0 — consent (dispatch 전 필수)` 를 `## phase 0 — 범위 고르기 (dispatch 전 필수)` 로, step 2 끝 `consent 이전` 을 `범위 고르기 이전` 으로. step 3 을 아래로 바꾼다(「축 골라서」 의 다중 선택 문장 · 「다시 고르기」 문장 · `axes` 문장은 지금 글 그대로 (a) 안에 둔다):

```markdown
3. **범위 고르기 · 규모 공시 (cost_class: high)** — 감사할 축을 고르고, 고른 규모를 한 줄로 알리고 진행한다 — 지출 승인을 묻지 않는다.
   (a) **축 고르기** — `AskUserQuestion` 한 질문: 「여섯 축 전부 (권장)」 · 「축 골라서」 · 「중단」. 선택지 설명에 규모를 싣는다 —
   「여섯 축 전부」는 「감사자 6 · 반박 최대 6 · codex 감사 6회(설치돼 있으면)와 그 반박 1 · 심층검증은 반박을 통과한 심각·중요
   지적마다 2회 — 상한 없음」, 「축 골라서」는 「축마다 감사자 1 · 반박 최대 1 · codex 감사 1회(설치돼 있으면) — codex 반박 1 ·
   심층검증은 같은 꼴」, 「중단」은 「아무것도 띄우지 않고 실행 디렉토리도 만들지 않는다」.
   「중단」이면 종료한다 — 실행 디렉토리를 만들지 않는다. <「축 골라서」 다중 선택 · 「다시 고르기」 · `axes` 문장 — 지금 글 그대로>
   (b) **규모 공시** — 질문이 아니라 한 줄이다. 고른 축 수를 k 라 하고 「감사자 k · 반박 최대 k · codex 감사 k회(설치돼 있으면)와
   그 반박 1 · 심층검증은 반박을 통과한 심각·중요 지적마다 2회 — 상한 없음, 몇 건인지는 감사 뒤에 정해지고 시작 직전 실행 기록에
   찍힌다」를 보인다. 축을 골라 뺐으면 「고르지 않은 축의 seed 단서와 질문은 「검증 안 됨」으로 채워진다」 줄을 함께 싣는다. 보안
   축(6)을 뺐으면 맨 앞에 「보안 축을 뺐다 — 사용자 파일 파괴 경로를 아무도 보지 않는다」 줄을 싣는다. 공시 뒤에는 묻지 않고
   4 로 간다 — 도는 중인 감사를 멈추는 길은 끼어들기이고, kill switch(`DEVBREW_PLUGIN_AUDIT_DISABLE=1`)는 다음 진입에서 듣는다.
```

  테스트가 앵커로 쓰는 문구(선택지 줄 · 「중단」 종료 문장 · `(b) **규모 공시** — 질문이 아니라 한 줄이다` · 규모 문장 조각)는 한 줄 안에 둔다 — 단언은 원문 글자로 센다. step 4 의 `승인 직후` 를 `공시 직후` 로, `consent 아티팩트(\`{approved, at, fanout, axes}\`)` 를 `consent 아티팩트(\`{at, fanout, axes}\` — \`at\` 은 공시한 때)` 로. Workflow 절의 `command/skill이 Workflow opt-in 요건을 충족(cost_class 게이트 통과 후).` 를 Step 1 의 두 문장으로.
- [ ] **Step 5: 검증기.** `if not consent.get("approved") is True:` 갈래를 `if "approved" in consent and consent.get("approved") is not True: errs.append("meta.consent.approved 가 있는데 true 가 아니다 — 거절이나 잘못 적힌 기록이다")` 로. `at` 필수 · `fanout_declared == consent.fanout` · 축 일치 검사는 그대로. docstring 의 `consent 3필드` 를 `consent(\`at\` 필수 · \`approved\` 는 있으면 true)` 로.
- [ ] **Step 6: 함께 고치는 곳.** `prepare-run-dir.py` docstring `(지출 동의 승인 직후 한 번)` → `(규모 공시 직후 한 번)`. `audit-workflow.js` :31 `chosen at the consent gate` → `chosen at the scope question`, :691 `the consent gate announces the scale` → `the scope question and the disclosure line announce the scale`. README :19 → `` `cost_class: high` — dispatch 전에 축을 고르고(「중단」으로 멈출 수 있다) 규모를 한 줄로 본 뒤 진행한다 — 지출 승인을 묻지 않는다. ``, :23 `(지출 동의\n승인 직후, …)` → `(규모 공시 직후, …)`, :93 → `- **P22 (cost 인지)** — \`cost_class: high\` + 규모 공시 한 줄(fan-out 선언). 범위 고르기 질문은 남는다.`, :100 → `오케스트레이션(범위 고르기 · 규모 공시 → pre-0 → Workflow → post-1)`. `tests/README.md` :14 → `2. **phase 0** 범위 고르기 · 규모 공시(축 고르기 · 「중단」 · 공시 한 줄) → 공시 직후 \`prepare-run-dir.py\` 로 실행`. CHANGELOG :153 은 옛 판 기록이라 고치지 않는다(새 판 항목은 Task 7).
- [ ] **Step 7:** 두 테스트 GREEN · `python3 -m unittest discover -s plugins/plugin-audit/tests` 전체 · `node --test plugins/plugin-audit/tests/*.test.mjs` · `git grep -n -e '지출 동의' -e '지출게이트' -e '명시 승인' -- plugins/plugin-audit ':!*CHANGELOG*' ':!*/fixtures/*'` 가 빈다.
- [ ] **Step 8: 커밋** — `feat(plugin-audit)!: 지출 동의 질문을 걷고 첫 축 질문에 「중단」 · 규모를 싣는다`.
- [ ] **Step 9: 변이.** 첫 질문의 `· 「중단」` 삭제 → `test_scope_question_has_stop_before_run_dir` RED. (b) 에 「승인」 · 「중단」 질문 문장을 되살림 → RED. 검증기의 `"approved" in consent and` 를 지움(반전 — 없으면 오류) → `test_consent_without_approved_passes` RED. `is not True` 를 `is False` 로(형태 변경) → `test_consent_approved_string_is_red` RED.

---

### Task 5: artifact-critique E3 — 범위 고르기 · 규모 공시 (AC16)

**Files:**
- Modify: `plugins/quality-gates/skills/artifact-critique/SKILL.md`(E3 머리 · :174-175 · :191-192)
- Modify: `plugins/quality-gates/README.md`(:38)
- Test: `plugins/quality-gates/tests/test_critiquing_artifacts_skill.sh`(:43-67)

- [ ] **Step 1: 실패하는 단언.** `E3="$(awk '/^### E3 — /{f=1} f&&/^## /{exit} f' "$S")"`. 있음 — `'### E3 — 범위 고르기 · 규모 공시'` · `'disclosure-integrity'` · `'이 질문은 범위를 고르는 질문이다 — 라운드마다 띄울 수와 상한은 본문에 공시한다.'` · `'지출 승인을 묻지 않는다'` · 선택지 넷(`**실행**` · `**대상 변경**` · `**취소**` · `「1명 (권장)」`) · `effective_max_rounds`. 없음 — `'consent-integrity'` · `'지출-전 명시 승인'` · `'동의 범위 = 실행 범위'` · `'Upfront 동의 게이트'`. :67 의 `consent-integrity` 단언을 `disclosure-integrity`(E3 본문 고유)로 바꾼다. qg README 에 `'Law 1=E3 범위 고르기 · 규모 공시'` 있음 · `'Law 1=E3 upfront 동의 게이트'` 없음.
- [ ] **Step 2:** RED.
- [ ] **Step 3: 문면.** `### E3 — Upfront 동의 게이트` → `### E3 — 범위 고르기 · 규모 공시`. `**동의 문구와 루프 한도로 동일하게\n사용**한다(동의 범위 = 실행 범위; consent-integrity)` → `**고지 문구와 루프 한도로 동일하게\n사용**한다(고지 범위 = 실행 범위; disclosure-integrity)`. 끝 문단 `이 게이트는 N을 되묻지 않는다(값은 고지). cost_class=variable(worst-case high)이라 이\nupfront 게이트가 지출-전 명시 승인이다.` → `이 게이트는 N을 되묻지 않는다(값은 고지). 이 질문은 범위를 고르는 질문이다 — 라운드마다 띄울 수와 상한은 본문에 공시한다. 지출 승인을 묻지 않는다.`. 두 질문 · 선택지는 그대로. 같은 파일의 다른 자리에서 `E3` 를 「동의 게이트」로 부르는 곳(`git grep -n 'E3' plugins/quality-gates/skills/artifact-critique/SKILL.md`)을 같은 이름으로 맞춘다. qg README :38 의 `Law 1=E3 upfront 동의 게이트` → `Law 1=E3 범위 고르기 · 규모 공시`. :28-32 · :210-211 은 뜻이 이미 맞다 — 그대로 둔다.
- [ ] **Step 4:** 테스트 GREEN · `git grep -l 'artifact-critique' -- plugins/quality-gates/tests` 의 셸 테스트 GREEN.
- [ ] **Step 5: 커밋** — `fix(qg): artifact-critique E3 를 범위 고르기 · 규모 공시로 — 지출 승인 문장을 걷는다`.
- [ ] **Step 6: 변이.** `disclosure-integrity` 를 `consent-integrity` 로 되돌림 → RED. 「지출-전 명시 승인이다」 문장을 되살림 → RED.

---

### Task 6: 규칙 문장 · P22 · 새 공유 락 (AC11 · AC12 · AC17 · AC18)

**Files:**
- Create: `shared/tests/test_cost_disclosure.sh`(100755)
- Modify: `CLAUDE.md`(:51) · `docs/philosophy/devbrew-harness-philosophy.md`(P22 :63-64)
- Test: `plugins/quality-gates/tests/test_governance_no_capability_caps.sh`(AC8a cost 블록) · `plugins/spec-distill/tests/test_epic_conductor_skill.sh`(:213-223 예외 락) · `plugins/spec-distill/tests/test_reviewing_brief_skill.sh`(:73 메시지 — 예약 밖)

- [ ] **Step 1: 새 락 `shared/tests/test_cost_disclosure.sh`.** 머리 `# guards: plugins/*/skills/*/SKILL.md CLAUDE.md docs/philosophy/*.md`. 내용:
  - 도출: `derive_git` = `git -C "$ROOT" ls-files -- 'plugins/*/skills/*/SKILL.md'`(정렬), `derive_find <root>` = `find plugins -path '*/skills/*/SKILL.md'`(그 root 에서). 양성 대조 — 두 수가 같고 0 보다 크다.
  - `BANNED=('지출 동의' '지출 전 명시' '지출-전 명시' '지출 승인 게이트' '승인 전에는 agent 를 보내지 않는다' '이름 붙인 예외')`. `scan <root> <목록 파일>` 은 걸린 파일마다 `<파일>\t<문구>` 를 낸다.
  - (가) 실제 레포 scan 결과가 비었다. pm-interview SKILL 에 `닿으면 연장을 묻는다`, reviewing-brief SKILL 에 `「추가 라운드 1회 열기」` 가 있다(양성 — 상한을 여는 질문은 걸리지 않는다).
  - (가) 내장 양성 대조 — `mktemp -d` 사본에 도출한 SKILL.md 를 경로째 복사하고, (1) `plugins/quality-gates/skills/quality-pipeline/SKILL.md` 사본 끝에 `지출 동의 게이트` 를 붙이면 scan 이 그 파일 한 줄을 낸다, (2) `plugins/zz/skills/zz/SKILL.md` 를 `이름 붙인 예외` 한 줄로 더하면 `derive_find` 수가 하나 늘고 scan 이 그 파일을 낸다. 사본은 `trap` 으로 지운다.
  - (나) 절 안 양성 — epic-conductor `### 4. 규모 공시` 절 · plugin-audit `3. **범위 고르기 · 규모 공시` 부터 `4. **실행 디렉토리**` 앞까지 · artifact-critique `### E3 — 범위 고르기 · 규모 공시` 절에 각각 `지출 승인을 묻지 않는다`.
  - RC14 — epic-conductor 에 `DEVBREW_SPEC_DISTILL_DISABLE=1` · `엔진의 재리뷰 상한까지`, plugin-audit 에 `DEVBREW_PLUGIN_AUDIT_DISABLE=1` 과 step 3 안의 `상한 없음`, artifact-critique 에 `effective_max_rounds` · `artifact_stagnation.py` · `DEVBREW_QUALITY_GATES_DISABLE_CRITIQUE=1`.
  `chmod +x` 뒤 `bash shared/tests/test_cost_disclosure.sh` — Task 3~5 뒤라 GREEN 이어야 한다(GREEN 이 아니면 걸린 파일을 고친다 — 그 문구는 이 계획의 몫이다).
- [ ] **Step 2: 실패하는 단언 — 규칙.** governance 의 「cost_class: high 승인 게이트」 두 단언(:127-140)을 아래로 바꾼다(주석의 「P17 사용자 주권」 이유는 범위 질문 양성 단언에 붙인다):

```bash
COST_C="$(grep -F '**모든 skill에 `cost_class` 선언**' "$CLAUDE_MD")"
p22="$(awk '/^### P22/{f=1;next} /^(## |### )/{f=0} f' "$PHIL")"
assert_contains "$COST_C" '`high` 는 크게 쓰기 전에 규모(띄울 agent 수 · 라운드 · 상한이 없으면 없다는 사실)를 한 줄로 알리고 진행한다.' "AC11: CLAUDE.md 공시 문장(양)"
assert_contains "$COST_C" '어느 클래스의 skill 도 지출 승인을 묻지 않는다 — 상한 · 압축은 공시하고, 사용자가 상한을 여는 질문은 지출 승인이 아니다.' "AC11: 지출 승인 없음 · 상한을 여는 질문"
assert_contains "$COST_C" '대상 · 모드 · 취소처럼 일의 범위를 고르는 질문도 지출 승인이 아니라 그대로 묻는다.' "AC11: P17 — 사용자 결정권은 범위 고르기에 남는다(양)"
for gone in '지출 전 명시적 `AskUserQuestion` 승인 게이트를 invoke해야 함' '이름 붙인 예외' 'worst-case 가 high 인 `variable`'; do
  assert_not_contains "$(cat "$CLAUDE_MD")" "$gone" "AC11: CLAUDE.md 에 「$gone」 없음"
done
assert_contains "$p22" 'cost_class: high' "AC12: P22 리터럴"
assert_contains "$p22" '대상 · 모드 · 취소처럼 일의 범위를 고르는 질문은 사용자 결정이라 남는다(P17)' "AC12: P22 범위 질문"
assert_not_contains "$p22" '승인 게이트가 필수' "AC12: P22 옛 게이트 없음"
assert_not_contains "$p22" '<Use_When>' "AC12: P22 죽은 장치 없음"
```

  AC12 바이트 같음 — 설계 §2 의 세 줄(CLAUDE.md 한 줄 · P22 두 줄)을 테스트 안 리터럴로 두고 `grep -cxF -- "<줄>" <파일>` 이 각각 1(설계 파일에서 읽지 않는다). `test_epic_conductor_skill.sh` :213-223 은 `assert_contains "$COST" '어느 클래스의 skill 도 지출 승인을 묻지 않는다'`(양) · `assert_eq "$(grep -c '이름 붙인 예외' "$CM")" "0"` · `others="$(grep -l '이름 붙인 예외' "$ROOT"/plugins/*/skills/*/SKILL.md || true)"` 가 빈다(음)로. `test_reviewing_brief_skill.sh` :73 의 실패 메시지 `high 는 지출 승인 게이트를 요구한다(CLAUDE.md)` 를 `high 는 크게 쓰기 전에 규모 공시를 요구한다(CLAUDE.md)` 로(단언은 그대로).
- [ ] **Step 3:** governance · epic-conductor 테스트 RED.
- [ ] **Step 4: 규칙 문면.** CLAUDE.md :51 줄 전체를 설계 §2 「CLAUDE.md:51 확정 문안」 펜스의 한 줄로. 철학 P22 머리 `### P22 — Cost Awareness` 는 그대로, 본문 두 줄(:63-64)을 설계 §2 「철학 P22 확정 문안」 펜스의 두 줄로. 글자 그대로 — 바꿔야 하면 Global Constraints 의 확정 문안 규칙대로 멈춘다.
- [ ] **Step 5:** 아래가 모두 GREEN — governance(AC8a fan-out 임계 단언 포함 — 새 P22 줄은 `fan-out` 과 숫자를 함께 갖지만 비교 낱말이 없다) · `bash shared/tests/test_charter_citations.sh`(P22 코드 줄의 `test_cost_disclosure.sh` 가 추적 파일이다 — 같은 커밋에 넣는다) · `bash shared/tests/test_cost_disclosure.sh` · `bash plugins/spec-distill/tests/test_epic_conductor_skill.sh` · `bash plugins/spec-distill/tests/test_reviewing_brief_skill.sh` · `python3 -m unittest discover -s plugins/plugin-audit/tests -p 'test_check_shape_completeness.py'` · `git diff origin/main -- CLAUDE.md` 에 :91(Subagent spray) 줄이 없다.
- [ ] **Step 6: 커밋** — `git add shared/tests/test_cost_disclosure.sh CLAUDE.md docs/philosophy/devbrew-harness-philosophy.md plugins/quality-gates/tests/test_governance_no_capability_caps.sh plugins/spec-distill/tests/test_epic_conductor_skill.sh plugins/spec-distill/tests/test_reviewing_brief_skill.sh` · `docs(rules): high skill 은 규모를 한 줄로 알리고 진행한다 — 지출 승인을 묻지 않는다(P22)`. `git ls-files -s shared/tests/test_cost_disclosure.sh` 가 `100755`.
- [ ] **Step 7: 변이(AC17).** (1) 게이트가 없던 variable skill(`plugins/quality-gates/skills/quality-pipeline/SKILL.md`)에 「지출 동의 게이트」 한 줄 재삽입 → RED. (2) 세 skill 중 하나(artifact-critique)의 `지출 승인을 묻지 않는다` 삭제 → (나) RED. (3) 임시 사본 대신 실제 트리에 `plugins/zz/skills/zz/SKILL.md`(지출 승인 문구 한 줄)를 만들고 돌림 → RED(도출이 새 파일을 잡는다), 지운 뒤 `git status --porcelain` 이 빈다. (4) CLAUDE.md 에 옛 게이트 문장 되살림 → governance RED. (5) P22 의 범위 질문 문장 삭제 → RED.

---

### Task 7: spec-distill README · 판 · CHANGELOG (AC20)

**Files:**
- Modify: `plugins/spec-distill/README.md`(:17 · :120 · :144 · :159)
- Modify: `plugins/{spec-distill,plugin-audit,quality-gates}/.claude-plugin/plugin.json` · `CHANGELOG.md`

- [ ] **Step 1: README.** :17 의 괄호 `(cost_class high — 시작 승인, 같은 세션 · 표지가 살아 있고 · 규모가 글자 그대로 같으면 공시만)` → `(cost_class high — 시작할 때 규모를 한 줄로 알리고 진행합니다 · 지출 승인을 묻지 않습니다)`. :120 P22 줄의 `medium 인 reviewing-brief 에는 진입 지출 승인 게이트가 없고(epic-conductor 의 high 는 시작 승인 게이트를 갖는다)` → `어느 skill 도 지출 승인을 묻지 않고(epic-conductor 의 high 는 시작할 때 규모 줄을 공시한다)`(그 줄의 나머지는 그대로). :144 의 「cost_class high 의 이름 붙인 예외」 줄을 `- **P22 — 규모 공시** — epic-conductor 는 시작할 때 규모 줄(남은 에픽 · agent 약 · 순서 · 리뷰 라운드 상한 · 상한 없는 부분)을 보이고 진행한다. 멈추는 길은 끼어들기와 kill switch 다.` 로. :159 의 `기계 상태 · 시작 승인 · 자원 폴더` → `기계 상태 · 자원 폴더`. 그 뒤 `git grep -n -e '시작 승인' -e '이름 붙인 예외' -- plugins/spec-distill ':!*CHANGELOG*' ':!*/tests/*'` 가 빈다(state 의 `RETIRED_SECTIONS` 와 그 docstring 은 예외 — 남은 줄을 보고한다).
- [ ] **Step 2: 판 · CHANGELOG.** 머지 직전 기본 브랜치 판에서 spec-distill · plugin-audit minor, quality-gates patch. spec-distill `Removed` — `conductor_ledger.py approval` · `approve` · `cost_class: high` 의 이름 붙인 예외 · 기계 상태 `## 시작 승인` 쓰기. `Changed` — 지휘자 4절 「규모 공시」(규모 줄에 리뷰 라운드 상한 · 상한 없는 부분) · claim · takeover 가 기계 상태를 검사하고 다시 쓴다 · 옛 `## 시작 승인` 은 읽고 다음 저장에서 걷는다. plugin-audit `Removed` — 지출 동의 질문(「승인」 · 「중단」). `Changed` — 첫 축 질문에 「중단」 · 선택지 설명의 규모 · 공시 한 줄 · `consent.json` `{at, fanout, axes}` · 검증기가 `approved` 없음을 받고 있으면 true 만 받는다 · Workflow 근거는 사용자의 호출. quality-gates `Changed` — artifact-critique E3 이름 · 지출 승인 문장 제거.
- [ ] **Step 3:** `bash shared/tests/test_changelog_integrity.sh` · `bash shared/tests/test_plugin_description_parity.sh` · `bash plugins/spec-distill/tests/test_readme_sync.sh`(있으면) GREEN.
- [ ] **Step 4: 커밋** — `chore(release): R9 계획 2 판 · CHANGELOG · README`.

---

### Task 7b: 계획 1 에서 넘어온 작은 고침 셋 (설계 `## 미룸` 의 R9 받는 곳 행 셋을 닫는다)

**Files — 아래 중 `test_plain_language_block.sh` 만 로드맵 R9 경로 예약 안이다. 나머지는 예약 밖(`roadmap.md` R9 블록에 없음)이라 경로 예약 정보 줄을 받아들인다:**
- Modify: `plugins/quality-gates/dependencies.md` · `shared/tests/test_check_deps.sh`(둘 다 예약 밖 — R14 가 예약한 `shared/deps/check_deps.py` 는 건드리지 않는다)
- Modify: `plugins/project-init/templates/github-flow/branch-strategy.md`(:70) · `plugins/project-init/templates/git-flow/branch-strategy.md`(:103) · `plugins/project-init/templates/trunk-based/branch-strategy.md`(:74) · `plugins/project-init/tests/test_branch_prefix_templates.py` · `plugins/project-init/.claude-plugin/plugin.json` · `plugins/project-init/CHANGELOG.md`
- Modify: `plugins/spec-distill/references/redecompose.md`(:129) · `shared/tests/test_plain_language_block.sh`(R9 예약)
- 판: project-init patch(`plugin.json` · CHANGELOG `Fixed`). quality-gates 는 Task 7 의 patch 에 `Changed` 한 줄을 더한다(`dependencies.md` 에 외부 플러그인 행). spec-distill 은 Task 7 의 minor 에 `Changed` 한 줄(redecompose 끝 문장).
- 장치 변경 없음: `check_deps.py` 를 고치지 않는다 — 아래 (i) 는 그 스크립트가 이미 받는 꼴만 쓴다.

**(i) qg `dependencies.md` 에 `pr-review-toolkit` 행** — 설계 `## 미룸` 「qg `dependencies.md` 에 `pr-review-toolkit` 행」을 닫는다.

`check_deps.py` 가 이미 하는 일(읽고 확인했다): `read_table`/`_parse` 는 머리 다섯 칸·행마다 다섯 칸·이름 중복 없음·강도가 `멈춤` · `알림` · `기록` 중 하나일 때만 받고, 최소 판 · 잰 날짜 칸의 값은 보지 않는다. `measure` 는 `_measure_row` 가 모르는 이름이면 「이 이름을 재는 방법이 없다」로 그 행을 못 잰 행에 넣어 그대로 두고 알리며 rc 0 이다. `entry` 는 `--need` 로 부른 이름의 행만 읽는다 — `--need` 에 `pr-review-toolkit` 을 적으면 최소 판 칸이 판이 아니라 `DepsError` 로 멈추므로 어느 SKILL 도 그 이름을 `--need` 에 적지 않는다.

- [ ] **Step 1: 실패하는 단언.** `shared/tests/test_check_deps.sh` 의 `expected_names` 에서 `quality-gates)` 를 `echo "python git gh claude-code pr-review-toolkit"` 로. 같은 파일 §2 의 「모든 행의 최소 판 · 잰 날짜가 채워져 있다」 검사(파이썬 한 줄 — `all(version_triple(min_version) and len(measured_on) == 10 …)`)는 외부 플러그인 행에서 깨지므로, 판을 재지 못하는 행을 이름이 아니라 **강도 `기록` 이면서 `_measure_row` 가 재지 못하는 이름**(`check_deps._measure_row(name, ".", None)[0] is None`)으로 도출해 그 행만 건너뛴다 — 건너뛴 이름 목록을 한 줄 더 내고 `quality-gates` 에서 정확히 `pr-review-toolkit` 하나임을 `assert_eq` 한다(양성 대조: 목록이 비면 건너뛰기가 공허하다). 새 단언 둘: `qg: pr-review-toolkit 행은 강도 기록이고 없을 때 칸이 외부 플러그인이라 재지 못한다고 말한다`(`read_table` 로 그 행의 `strength == "기록"` · `when_missing` 에 `외부 플러그인` · `재지 못한다`), `qg: entry --need python,git,gh,claude-code 는 새 행과 상관없이 통과한다`(이 레포의 `scripts/check_deps.py entry --plugin-root plugins/quality-gates --need python,git,gh` rc 0 — 지금 환경 판이 최소 판 이상일 때).
- [ ] **Step 2:** `bash shared/tests/test_check_deps.sh` RED(행 이름 불일치).
- [ ] **Step 3: 행.** `plugins/quality-gates/dependencies.md` 표 끝(`claude-code` 행 뒤)에 정확히 이 줄을 더한다:

```
| pr-review-toolkit | — | — | 기록 | 외부 플러그인이라 판을 재지 못한다 — 없으면 이 리뷰어를 건너뛰고 나머지로 진행한다(README Prerequisites 의 optional 의존) |
```

  머리 안내문(「판 칸은 … measure 가 쓴다」 문단)은 그대로 둔다 — `measure` 가 이 행을 「못 쟀다」로 알리고 그대로 두는 것이 정상 동작이다.
- [ ] **Step 4:** `bash shared/tests/test_check_deps.sh` GREEN · `python3 plugins/quality-gates/scripts/check_deps.py entry --plugin-root plugins/quality-gates --need python,git,gh` rc 0 · `python3 plugins/quality-gates/scripts/check_deps.py measure --plugin-root plugins/quality-gates --today 2026-01-01` 은 **실제 파일을 고치므로** 복사본으로 돌린다(`cp -R plugins/quality-gates "$TMPDIR/qg-copy"` 뒤 `--plugin-root "$TMPDIR/qg-copy"`): 출력에 `pr-review-toolkit 못 쟀다` 가 있고 rc 0, 복사본에서 그 행이 바이트 그대로다.
- [ ] **Step 5: 커밋** — `fix(qg): 의존 표에 외부 플러그인 pr-review-toolkit 행을 기록으로 더한다`.
- [ ] **Step 6: 변이.** 행의 강도 `기록` → `멈춤`(형태 변경) → 새 강도 단언 RED. 행 삭제 → 이름 단언 RED. `외부 플러그인` 삭제 → 없을 때 단언 RED. 건너뛰기 도출을 이름 하드코딩 없이 `기록` 만 보게 바꿈(`claude-code` 도 건너뜀) → 건너뛴 목록 `assert_eq` RED(양성 대조).

**(ii) project-init 템플릿 셋의 낡은 훅 문장** — 설계 `## 미룸` 「project-init 템플릿 셋의 훅 문장」을 닫는다. 사실: 훅은 `Bash|EnterWorktree` 뒤 브랜치 reflog 의 만들기 · 이름 바꾸기 · 복사를 60초 안에 잡으므로 `git worktree add -b` 도 확인한다(`plugins/project-init/README.md` 「설치된 Hook」 `PostToolUse` 항목 · `plugins/project-init/hooks/post-tool-use.py` `_last_reflog_line`). 계획 시작 전에 이 사실을 `git grep -n 'reflog' plugins/project-init/hooks/post-tool-use.py plugins/project-init/README.md` 로 다시 확인하고 다르면 멈춘다.

- [ ] **Step 7: 실패하는 단언.** `plugins/project-init/tests/test_branch_prefix_templates.py::test_worktree_path_same_rule` 의 needle 목록에서 `"확인하지 않는다"` 를 빼고, 루프 뒤에 추가한다: `self.assertIn("reflog", sec, s)` · `self.assertIn("`git worktree add -b` 로 만든 이름을 모두 확인한다", sec, s)`(양) · `self.assertNotIn("확인하지 않는다", sec, s)` · `self.assertNotIn("만 확인한다", sec, s)`(음). 양성 짝: 위 두 양의 단언이 세 전략 모두에서 GREEN 인 것이 음의 단언이 공허하지 않다는 증거다.
- [ ] **Step 8:** `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/project-init/tests/test_branch_prefix_templates.py` RED.
- [ ] **Step 9: 문면.** 세 파일의 마지막 문장만 바꾼다(앞 문장은 그대로):
  - `github-flow` :70 — `project-init 훅은 `git checkout -b` · `git switch -c` 로 만든 이름만 확인한다 — `git worktree add -b` 로 만든 이름은 확인하지 않는다.` → `project-init 훅은 실행 뒤 브랜치 reflog 를 읽어 `git checkout -b` · `git switch -c` · `git worktree add -b` 로 만든 이름을 모두 확인한다.`
  - `git-flow` :103 — 같은 문장(앞머리 `project-init 훅은` 그대로).
  - `trunk-based` :74 — `훅(project-init)은 `git checkout -b` · `git switch -c` 로 만든 이름만 확인한다 — `git worktree add -b` 로 만든 이름은 확인하지 않는다.` → `훅(project-init)은 실행 뒤 브랜치 reflog 를 읽어 `git checkout -b` · `git switch -c` · `git worktree add -b` 로 만든 이름을 모두 확인한다.`
  `git grep -n '만 확인한다' -- plugins/project-init/templates` 가 빈다. 템플릿 문장은 사용자 레포로 복사되는 문서라 출처 · 날짜를 넣지 않는다.
- [ ] **Step 10:** 위 단위 테스트 GREEN · `git grep -l 'branch-strategy.md' -- plugins/project-init/tests` 의 테스트(`test_branch_strategy_rebase_clause.sh` 포함) GREEN. `plugin.json` patch · CHANGELOG `Fixed` — 템플릿 훅 문장을 지금 훅(reflog 로 `worktree add -b` 도 확인)에 맞췄다.
- [ ] **Step 11: 커밋** — `fix(project-init): 브랜치 전략 템플릿의 훅 문장을 worktree add -b 도 확인하는 지금 훅에 맞춘다`.
- [ ] **Step 12: 변이.** 한 템플릿(trunk-based)에 옛 문장 되살림 → `assertNotIn` RED. `reflog` 삭제 → 양 단언 RED. `모두` 삭제 → 양 단언 RED. 세 전략 중 하나의 절을 비움 → 그 전략 이름이 든 메시지로 RED(`s` 가 메시지에 있다).

**(iii) redecompose 끝 문장** — 설계 `## 미룸` 「`redecompose.md` 의 『다음 할 일 하나만 말하고』」를 닫는다.

- [ ] **Step 13: 실패하는 단언.** `shared/tests/test_plain_language_block.sh` 의 :45 아래에 추가: `assert_file_grep "$ROOT/plugins/spec-distill/references/redecompose.md" '다음 할 일을 말하고\(기본 하나 — 여럿이거나 병렬이면 밝힌다\) 턴을 끝낸다' "R9: redecompose 성공 줄이 새 꼬리를 쓴다(양)"`, 그리고 옛 문장 없음 — `RD_OLD="$(grep -cF -- '다음 할 일 하나만 말하고' "$ROOT/plugins/spec-distill/references/redecompose.md" || true)"; assert_eq "$RD_OLD" "0" "R9: redecompose 에 옛 꼬리가 없다(음)"`. 현재 문장 위치(`redecompose.md:129` — `git grep -n '다음 할 일 하나만 말하고' -- plugins shared tools` 로 이 줄뿐임을 확인했다).
- [ ] **Step 14:** `bash shared/tests/test_plain_language_block.sh` RED.
- [ ] **Step 15: 문면.** `plugins/spec-distill/references/redecompose.md:129` 끝의 `다음 할 일 하나만 말하고 턴을 끝낸다.` → `다음 할 일을 말하고(기본 하나 — 여럿이거나 병렬이면 밝힌다) 턴을 끝낸다.` 줄의 앞부분은 그대로. spec-distill README/CHANGELOG 는 Task 7 의 `Changed` 한 줄에 합친다.
- [ ] **Step 16:** `bash shared/tests/test_plain_language_block.sh` GREEN · `git grep -n -F '다음 할 일 하나만' -- plugins shared tools` 가 빈다.
- [ ] **Step 17: 커밋** — `docs(spec-distill): redecompose 성공 줄의 끝 할 일을 기본 하나로 맞춘다`.
- [ ] **Step 18: 변이.** 옛 문장 되살림 → 음 단언 RED. `(기본 하나 — …)` 괄호 삭제 → 양 단언 RED. `여럿이거나` → `여럿이면`(형태 변경) → 양 단언 RED.
- [ ] **Step 19:** 설계 `## 미룸` 표의 R9 받는 곳 행 셋(`pr-review-toolkit` 행 · 템플릿 훅 문장 행 · redecompose 행)에 `끝냄 — <커밋 해시>` 를 더한다(Task 8 Step 4 와 같은 표). 그 행들의 받는 곳은 `R9` 로 이미 올라 있다.

---

### Task 8: 합치기 · 전체 대조 · 마지막 리뷰 · 미룸 (AC19 · AC21 · AC11~AC18 확인)

- [ ] **Step 1:** `git fetch origin && git merge --no-edit origin/main`(앞서 있으면). 합친 사본에서 Task 1~6 의 테스트를 다시 돌린다. 겹친 파일(`conductor_ledger.py` · `test_epic_conductor_skill.sh` · spec-distill README)에서 R14 가 넣은 줄이 남았는지 `git diff origin/main -- <파일>` 로 확인해 PR 본문에 적는다(AC21).
- [ ] **Step 2:** 공유 잠금 아래 전체 스위트 → `plan2-after.txt`. 기준선에 없던 `FAILED` 줄은 이 계획의 몫이다.
- [ ] **Step 3: 마지막 전체 리뷰.** 고른 실행 방식의 마지막 리뷰(가장 강한 모델 · 쓰기 권한 없는 리뷰어)에 설계문서 `## Acceptance Criteria` 의 「계획 2」 AC11~AC18 과 「공통」 AC19~AC21 전문을 그대로 싣고, AC 마다 한 줄씩 `AC<n>: <구현됨 | 미룸 | 빠짐> — <근거>` 로 보고하게 한다. 함께 묻는다: 과제 사이 이음매(Task 1 의 버림과 Task 2 의 다시 쓰기가 옛 파일을 끝에서 끝으로 걷는지 · 3절 표지 풀기 펜스가 `default_rc` 줄과 이어지는지 · 공통 공시 문장이 규칙과 세 skill 에서 같은지), 계획이 쓴 테스트 코드(plan-mandated 라벨)의 이빨, `test_cost_disclosure.sh` 의 금지 문구가 상한을 여는 질문을 걸지 않는지. 보고를 git 이 추적하지 않는 `$HOME/.claude/sdd-mirror/r9/plan2-ac-report.md` 에 적는다. AC19 는 커밋 순서(테스트 → 구현 → 변이)와 과제 기록으로 본다.
- [ ] **Step 4: 미룸.** `미룸` · `빠짐` 판정과 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표에 한 행씩 올린다.
- [ ] **Step 5:** PR 을 만들기 전에 `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/7.3.0/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-10-23-rules-docs-cleanup-design.md $HOME/.claude/sdd-mirror/r9/plan2-ac-report.md --acs "AC11~AC21"` 를 돌려 경고를 사용자에게 쉬운 말로 보인다.

---

## `### Deferred to plan` 답 (이 계획 몫)

| 항목 | 답 |
|---|---|
| 공통 공시 문장의 정확한 글자 | `지출 승인을 묻지 않는다` — CLAUDE.md · P22 · 세 skill(Task 3~6) |
| `RETIRED_SECTIONS` 를 `skip` 기본값에 얹을지 | 따로 갈래(Task 1) — 부르는 쪽의 `skip` 이 덮지 않게 |
| ledger 승인 클래스 가운데 다른 성질을 함께 재던 단언 | `test_other_cannot_add` · `test_drop_where_needs_equals` — `MarkerWrites` 로 옮겨 남긴다(Task 2) |
| 3d9ac787 claim · takeover 검사 | 바꾸지 않는 `update`(Task 2 — 설계 §3 계획 판단) |
| 808c54ce plugin-audit README:100 | Task 4 Step 6 |
| 20b8dc7d 규모 줄의 라운드 · 상한 없음 | Task 3 Step 3 — §2 문안은 그대로 |
