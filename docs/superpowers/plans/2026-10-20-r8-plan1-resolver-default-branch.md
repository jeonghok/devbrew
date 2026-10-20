# R8 계획 1 — 값 해결자 · 폴더 · 기본 브랜치 · 상태 폴더 · 작업공간 불변 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **시작 조건 — 구현은 R10 · R12 · R13 이 모두 기본 브랜치에 머지된 뒤 시작한다(사용자 결정 U10).** 구현 담당은 먼저 `origin/<기본 브랜치>` 를 이 브랜치에 merge 하고, 이 계획이 인용한 파일 · 함수 · 절을 하나도 빠짐없이 새로 읽어 확인한다(Task 0). 이 계획은 60e21baa(설계 승인) 시점의 트리로 썼다 — 그 뒤 R10 계획 3 이 `skills/spec-interview` 를 `skills/pm-interview` 로 옮기고, R12 가 `shared/docreview` · request-framing · spec-review · 재분해 · 지휘 절차 · project-init 을, R13 이 pm-interview · request-framing · spec-review · `check_brief` 를 고친다. 그래서 그 파일들은 줄 번호가 아니라 절 · 함수 이름으로 가리킨다.

**Goal:** 레포마다 다른 값(폴더 · 테스트 명령 · 브랜치 접두 등)을 `repo_defaults.py` 하나가 출처와 함께 내고, 기본 브랜치는 `origin/HEAD` 하나에서 전체 참조 이름으로 얻으며, 정확성이 걸린 자리(커밋 범위 · 기본 브랜치)는 값이 오류 없이 틀어질 때 멈추고, 상태 폴더가 devbrew 밖 레포에서도 추적되지 않게 한다.

**Architecture:** `repo_defaults.py` 에 엄격한 frontmatter 판독 · 닫힌 키 집합 · 층 넷(로드맵 · `.devbrew.md`@기본 ref · 기계 상태(임시) · 상수) 합치기 · CLI(`get` · `check-path` · `roadmap-check` · `default-branch`)를 더한다. 로드맵 찾기는 `roadmap_model.py` 의 판정 함수 하나를 상태줄 · 로드맵 목록 · 끝내기 펜스가 함께 쓴다. 셸 펜스는 값을 조립하지 않고 판정 명령의 rc 를 받는다. 상태 루트는 처음 만들 때 자기 `.gitignore` 를 두고, bare 레포면 공용 git 디렉토리 안으로 간다.

**Tech Stack:** Python 3(표준 라이브러리), bash 3.2 호환 셸 펜스, 레포 셸 테스트 하네스(`shared/tests/assert.sh`), `python3 -m unittest`.

**Spec:** `docs/superpowers/specs/2026-10-20-dependency-portability-design.md` (§1 · §2 · §3 의 RC82 를 뺀 불릿 · §6 · §9 · AC1~AC12 · AC23b · AC24 · AC27 · AC28 · AC29 의 계획 1 몫)

## Global Constraints

- **시작 시점.** R10 · R12 · R13 머지 뒤(U10). 브랜치 `feature/dependency-portability`. 시작 때 기본 브랜치를 merge 한다(rebase 금지). 커밋은 pathspec(`git commit -- <경로…>`), `git stash` 금지. HEAD 를 뒤로 옮기지 않는다.
- 커밋 메시지: `type(scope)` 영어 · 설명 한국어. 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` 와 세션이 주는 `Claude-Session` 줄.
- **버전.** 판 번호는 머지 직전 지휘자가 정한다. 계획 안에서는 다음 minor 를 임시로 쓴다 — spec-distill · quality-gates 각각 minor bump. CHANGELOG 머리는 plugin.json 과 같게(`shared/tests/test_changelog_integrity.sh`).
- 호환 코드 · 옛 판 대체 길을 만들지 않는다(U2). gh 를 이 계획에서 새로 부르지 않는다(gh 는 계획 2).
- 지원 흐름은 내 레포 안 흐름이다 — PR · 기본 브랜치는 언제나 `origin`(U8). 원격 이름 설정 키를 두지 않는다.
- 설정 키는 닫힌 집합이다: `specs_dir` · `plans_dir` · `roadmaps_dir` · `interview_dir` · `test_command` · `test_failure_pattern` · `review_model` · `parallel_default` · `branch_prefix`. 로드맵 층이 받는 키: `type` · `source_brief` · `specs_dir` · `plans_dir` · `test_command` · `test_failure_pattern` · `review_model` · `parallel_default`. 기계 상태 층이 받는 키: `test_command` · `test_failure_pattern`.
- 출처 표기는 글자 그대로 `로드맵` · `레포 설정@<커밋 8자>` · `기계 상태(임시)` · `기본값` · `기본값(기본 브랜치 없음 — 설정 파일 못 읽음)`.
- 레포 전용 값(경로 · 브랜치 이름 · 접두 · 모델)은 `repo_defaults.py` 의 상수에만 글자로 둔다. 다른 파일은 해결자를 부른다. 상수가 아닌 이름(`roadmap_model` 등)을 `repo_defaults` 이름공간에 대문자로 끌어오지 않는다(`test_repo_literals.sh` 의 허용 목록이 `vars(R)` 의 대문자 문자열에서 도출된다 — `import roadmap_model as _rm` 꼴로).
- 셸 펜스는 macOS bash 3.2 · zsh 에서 돈다: `$var` 바로 뒤 한글은 `${var}`, `$( )` 안 heredoc 금지, 배열 첨자 대입 · 맞는 파일 없는 글롭 금지. 펜스는 값이 아니라 판정 rc 를 받고, 값을 받으면 rc 와 빈 값을 확인한다.
- 스크립트 파일 읽기는 `encoding="utf-8"`. 플러그인 `.py` 에 `"python3"` 리터럴 금지(`sys.executable`). 인라인 python 은 `python3 -I`. 새 셸 테스트는 `chmod +x` 후 `git ls-files -s` 로 `100755`.
- 사람에게 보이는 새 문면(안내 · 실패 메시지 · README · CHANGELOG)은 `shared/style/plain-language.md` — 첫 줄에 상태, 번호 · 해시는 내용 뒤 괄호, 끝에 할 일 하나. 모델이 읽는 새 문면(skill · reference)에는 출처 · 배경 · 정당화를 쓰지 않는다.
- 락은 변이로 이빨을 확인한다(표기 · 값 · 위치 · 부정문 네 축 + 추가 · 반전). 음의 락에는 양의 짝. 변이 전에 커밋하고 복원은 `git checkout HEAD -- <파일>` 뒤 `git diff HEAD` 로 확인. `PYTHONDONTWRITEBYTECODE=1`.
- 임시 레포 픽스처는 `mktemp -d` 결과가 비었거나 폴더가 아니면 바로 끝낸다(`cd ""` 사고). macOS `/tmp` → `/private/tmp` 를 경로 비교 전에 `pwd -P` 로 맞춘다.

## 설계와 다른 점 · 설계에 없던 결정

1. **레포 설정 파일 이름은 설계의 잠정 이름 `.devbrew.md` 그대로다** — 레포 루트, frontmatter 만 읽는다.
2. **CLI 종료 코드.** `get <키>`: 0 값 있음(stdout 한 줄) · 1 값 없음(기본값이 없는 키 — `test_command` 등, stdout 빈 줄 없음) · 2 사용법 · 3 설정이 깨짐(모르는 키 · 같은 키 둘 · 못 읽는 머리말 · 층 위반 · 일반 파일 아님 · LFS). `check-path` · `roadmap-check`: 0 통과 · 3 거부(사유 한 줄). `default-branch`: 0 짧은 이름 · 3 기본 브랜치 없음(고치는 법 안내) · 5 원격과 다름. 출처 · 알림은 stderr 한 줄씩 `[spec-distill] …`.
3. **`check-path <키> <경로>` 의 뜻은 「경로의 부모 폴더가 그 키의 폴더와 글자까지 같다」 하나다.** 대소문자만 다르거나, 디스크에 있는 경로 성분의 실제 이름이 대소문자만 다르면 rc 3 「대소문자만 다른 경로」. 로드맵 폴더(부모 = `roadmaps_dir`) · 인터뷰 파일(부모 = `interview_dir`)이 같은 명령을 쓴다.
4. **기본 브랜치 도출 · 대조는 `repo_defaults.py` 의 `default_branch()` · `check_remote_head()` 와 CLI `default-branch [--check-remote]` 가 맡는다.** `DEFAULT_REF` · `NO_DEFAULT` 정의는 `roadmap_model.py` 하나로 남고(`test_roadmap_approval.py` `OneDefaultRef` 에 `repo_defaults` 를 더한다), 원격이 없을 때의 안내 `NO_ORIGIN` 을 그 옆에 더한다.
5. **원격 대조의 시간 상한은 10초**(`git ls-remote --symref origin HEAD`, `GIT_TERMINAL_PROMPT=0`). 네트워크 진입 셋은 지휘자 진입 단계(표지 잡기 뒤) · `merge_check run`(fetch 뒤) · 인터뷰 끝 커밋 펜스(커밋 직전)다.
6. **로드맵의 모양은 `<roadmaps_dir><폴더>/<파일>.md` (한 단계 아래) ∧ frontmatter `type: roadmap`.** 파일 이름 `roadmap.md` 는 더 요구하지 않는다(지금 `control_plane.ROADMAP_RE` 만 요구했다). 기계 상태 폴더가 로드맵의 부모 폴더 이름을 쓰므로 한 단계가 필요하다.
7. **bare 판정은 git 을 부르지 않는 규칙이다**: 공용 git 디렉토리의 이름이 `.git` 이면 지금처럼 그 부모, 아니면 그 안(`<공용 git 디렉토리>/.claude/spec-distill`). `state_root_for_common` 은 순수 함수로 남는다. devbrew 처럼 평범한 레포는 경로가 바뀌지 않는다.
8. **상태 루트 쓰기 보장은 `state_path.ensure_state_root(root)` 하나**를 상태 루트 아래에 폴더를 만드는 모든 자리가 부르고, CLI `state-root --ensure` 를 원장을 처음 만드는 skill 펜스가 쓴다. 읽기만 하는 자리(상태줄 · 상태 보기)는 만들지 않는다.
9. **project-init README 의 「`branch_prefix` 와 브랜치 규칙을 맞춘다」 한 줄은 계획 2 에 둔다** — project-init 은 계획 2(RC82)가 고치고 판을 올린다. 이 계획은 spec-distill README 쪽 한 줄만 쓴다.

## Review Focus

1. **설정 파일이 없는 새 레포에서 인터뷰를 처음 연다(오프라인, `origin/HEAD` 없음).** 사람은 인터뷰가 막히지 않고 기본 폴더로 가며, 한 줄로 「기본 브랜치 없음 — 설정 파일을 읽지 못해 기본값을 썼다」를 보길 기대한다. 커밋 직전에야 기본 브랜치가 필요해 멈춘다. Task 2 의 `test_no_default_ref_uses_constants_with_source` 와 Task 7 의 무원격 픽스처가 잠근다.
2. **작업 브랜치에서 `.devbrew.md` 를 처음 더하고(아직 기본 브랜치에 없음) 같은 브랜치에서 인터뷰 끝 커밋을 한다.** 사람은 새 값이 아니라 기본값으로 가고 「아직 기본 브랜치에 없다 — 기본값을 쓴다」를 보길 기대한다(작업 브랜치가 자기 검사 범위를 바꾸지 못한다). Task 2 의 `test_worktree_only_file_notice` 가 잠근다.
3. **값에 `#` 이 든 테스트 명령(`test_command: pytest -k "not slow" # 빠른 것만`).** 사람은 주석이 값에 섞여 다른 명령이 도는 대신 멈추고 「따옴표로 감싸라」를 보길 기대한다. Task 1 의 `test_unquoted_hash_is_error` 가 잠근다.
4. **대소문자를 무시하는 파일시스템에서 brief §7 이 `Docs/Superpowers/roadmaps/…` 로 적혔다.** 사람은 다른 폴더를 커밋하는 대신 멈추길 기대한다. Task 7 의 대소문자 사례가 잠근다(macOS 기본 APFS 에서 실제로 돈다).
5. **GitHub 에서 기본 브랜치를 `main` → `trunk` 로 바꾼 뒤 `git fetch` 만 했다(옛 `origin/HEAD` 남음).** 사람은 지휘자 · merge_check · 인터뷰 끝 커밋이 옛 기본 브랜치 위에서 「기본 브랜치에 직접 커밋하지 않는다」 검사를 통과하지 않고 멈춰 `git remote set-head origin --auto` 를 안내하길 기대한다. 오프라인이면 멈추지 않고 「원격과 대조하지 못했다」. Task 3 의 개명 픽스처가 잠근다.

---

### Task 0: 머지 뒤 다시 읽기 · 기준선 · 실측 하나

**Files:**
- Create: `$HOME/.claude/sdd-mirror/r8-plan1/baseline.sh` (레포 밖)
- Modify: 이 계획 파일(자리 고침이 있으면)

- [ ] **Step 1: 시작 조건을 확인한다.** 기본 브랜치 이름은 `git symbolic-ref refs/remotes/origin/HEAD` 로 도출한다. R10(브랜치 셋) · R12 · R13 의 PR 이 모두 MERGED 인지 `gh pr list --state merged --head <브랜치>` 로 본다. 하나라도 아니면 멈추고 지휘 세션에 「R8 시작 조건 미충족 — <에픽>」을 보고한다.
- [ ] **Step 2: `git merge --no-edit origin/<기본 브랜치>`.** 충돌이 나면 설계문서 · 계획은 이 브랜치 쪽을 둔다.
- [ ] **Step 3: 인용 자리를 다시 읽고 이 계획을 맞춘다.** 읽을 것: `repo_defaults.py` 전체 · `roadmap_model.py` 의 `frontmatter` · `DEFAULT_REF` · `NO_DEFAULT` · `state_path.py` 의 `state_root_for_common` · `state_root` · `INTERVIEW_DIR` · `interview_state_path` · `roadmap_status.py` 의 `Git.default_branch` · `build` · `control_plane.py` 의 `candidates` · `interview_files` · `read_interviews` · `default_ref` · `gather` · `statusline_text` · `conductor_ledger.py` 의 `c_roadmaps` · `_tip` · `_roadmap_blocks` · `merge_check.py` 의 `machine_settings` · `run` · `skills/pm-interview/SKILL.md` 의 `## State location` · `skills/pm-interview/references/finishing.md` 의 분해 판단(폴더 안내 · 분해안 표의 브랜치 칸) · Step A(`--out`) · 끝내기 커밋 펜스(`interview-commit`) · B-1 안내 · `skills/request-framing/SKILL.md` 의 base 도출 펜스 · 워크트리 승낙 절차 · 산출물 기록 펜스 · `skills/spec-review/SKILL.md` 의 `review-candidates` 펜스 · `references/redecompose.md` 의 작업 브랜치 문장 · `shared/test-selection/resolve-baseline.sh` · qg `check-review-scope.sh` · `review-diff.sh` · `discover-spec.sh` 의 기준선 소비 · `resolve-range.sh` 의 끝 도출. 이름이 바뀌었으면 이 계획의 이름을 고쳐 쓴다.
- [ ] **Step 4: 박힌 값 자리를 다시 센다.** `git grep -n -e 'docs/superpowers/interview' -e 'docs/superpowers/roadmaps' -e 'docs/superpowers/specs' -e "origin/main" -e "symbolic-ref --short" -e 'feature/' -- plugins/spec-distill/skills plugins/spec-distill/references plugins/spec-distill/scripts plugins/spec-distill/templates ':!*CHANGELOG*'` — 결과를 Task 6 · 7 의 고칠 목록으로 이 계획에 적는다(설계 Context 의 목록보다 많으면 많은 쪽).
- [ ] **Step 5: 기준 스위트.** R2a 계획 1(`docs/superpowers/plans/2026-10-18-r2a-plan1-defects-test-selection-qg-entry.md` Task 0 Step 1)의 `baseline.sh` 를 `$HOME/.claude/sdd-mirror/r8-plan1/baseline.sh` 로 쓰고, 버릴 clone(`git clone --no-local` 로 merge 한 HEAD)에서 `bash … "$HOME/.claude/sdd-mirror/r8-plan1/before"`. Expected: 실패 줄 «이름» 집합 파일 생성. 다른 스위트와 동시에 돌리지 않는다.
- [ ] **Step 6: 실측 — `.claude/worktrees/` 를 무시하지 않는 레포에서 qg(설계 §6 · PR #234 넘김).** 임시 레포(`.gitignore` 없음, 기본 브랜치 `trunk`, 원격은 로컬 bare)에 `git worktree add .claude/worktrees/wt -b feature/wt trunk` 를 두고 `bash plugins/quality-gates/scripts/review-diff.sh session <out>` 을 돈다. Expected: 출력의 `degraded:` 값과 stderr 의 「리뷰하지 못한 항목」 줄을 이 계획 Task 9 Step 6 에 그대로 적는다. 「추적 안 되는 중첩 레포」로 잡혀 인증이 막히면 그 사실을 README 의 devbrew 밖 레포 절(Task 11)에 「`.claude/worktrees/` 를 `.gitignore` 에 더하라」로 싣는다. 이 실측은 계획 작성 세션이 격리 가드 때문에 하지 못했다.

---

### Task 1: 해결자 — 엄격한 머리말 · 닫힌 키 · 층 넷 합치기 (AC1 의 합치기 · AC2 · AC5 의 층 · AC23b)

**Files:**
- Modify: `plugins/spec-distill/scripts/repo_defaults.py`
- Test: `plugins/spec-distill/tests/test_repo_defaults.py`

**Interfaces:**
- Produces:
  - 상수 `KEYS` (위 아홉, 순서 그대로) · `ROADMAP_LAYER_KEYS` · `ROADMAP_META_KEYS = ("type", "source_brief")` · `MACHINE_LAYER_KEYS = ("test_command", "test_failure_pattern")` · `ROADMAPS_DIR = "docs/superpowers/roadmaps/"` · `INTERVIEW_DIR = "docs/superpowers/interview/"` · `BRANCH_PREFIX = "feature/"` · `SETTINGS_FILE = ".devbrew.md"`
  - `class SettingsError(ValueError)` — 속성 `kind` ∈ `"unreadable"` · `"unknown_key"` · `"duplicate_key"` · `"unquoted_hash"` · `"layer_key"` · `"bad_value"` · `"not_regular_file"` · `"lfs_pointer"`, 속성 `where`(층 이름)
  - `strict_frontmatter(text: str, where: str) -> dict[str, str]` — 머리말이 없으면 `{}`(로드맵 층은 머리말이 늘 있다; 설정 파일은 `"unreadable"`). BOM · 안 닫힘 · `--- ` 뒤 공백 · 같은 키 둘 · 따옴표 없는 값의 ` #` → `SettingsError`. 값은 따옴표를 벗긴 글자.
  - `check_layer(meta: dict, layer: str) -> None` — `layer` ∈ `"roadmap"` · `"repo"` · `"machine"`; 허용 밖 키 → `SettingsError("layer_key" 또는 "unknown_key")`
  - `merge_layers(roadmap: dict | None, repo: dict | None, repo_label: str | None, machine: dict | None, notices: list[str]) -> dict` — 반환 `{"values": {키: 값|None}, "sources": {키: 출처}, "errors": [...], "warnings": [...], "notices": [...]}`. 폴더 키는 기존 `_folder` 규칙 + `.git` 아래 · 루트(`.`) 금지. `parallel_default` 의 「깨지면 기본값 + 경고」 규칙은 그대로.
- `repo_settings(meta)` 는 지운다 — 호출자(Task 4)가 `resolve` 로 옮긴다.

- [ ] **Step 1: 실패하는 테스트를 쓴다** (`test_repo_defaults.py` 에 클래스 `StrictFrontmatter` · `Layers` · `Merge`)

```python
def test_bom_is_unreadable(self):
    with self.assertRaises(rd.SettingsError) as c: rd.strict_frontmatter("﻿---\na: b\n---\n", "repo")
    self.assertEqual(c.exception.kind, "unreadable")
def test_unclosed_and_trailing_space_fence_are_unreadable(self): ...   # "---\na: b\n" · "--- \na: b\n---\n" → kind "unreadable"
def test_duplicate_key(self): ...                                       # "---\nspecs_dir: a/\nspecs_dir: b/\n---\n" → "duplicate_key"
def test_unquoted_hash_is_error(self): ...                              # 'test_command: pytest # 빠른 것' → "unquoted_hash"
def test_quoted_hash_is_value(self):
    self.assertEqual(rd.strict_frontmatter('---\ntest_command: "pytest -k \'a#b\' # x"\n---\n', "repo")["test_command"], "pytest -k 'a#b' # x")
def test_missing_key_is_default_not_error(self):
    m = rd.merge_layers(None, {}, "레포 설정@0123abcd", None, [])
    self.assertEqual((m["values"]["interview_dir"], m["sources"]["interview_dir"]), (rd.INTERVIEW_DIR, "기본값"))
def test_typo_key_is_unknown(self): ...                                 # repo 층 {"spec_dir": "x/"} → check_layer kind "unknown_key"
def test_roadmap_layer_rejects_pre_roadmap_keys(self):                  # AC23b
    for k in ("roadmaps_dir", "interview_dir", "branch_prefix"):
        with self.assertRaises(rd.SettingsError) as c: rd.check_layer({k: "x/"}, "roadmap")
        self.assertEqual(c.exception.kind, "layer_key")
def test_roadmap_layer_accepts_meta_and_its_settings(self): ...         # type · source_brief · specs_dir · … 통과
def test_machine_layer_accepts_two_keys_only(self): ...                 # review_model → "layer_key", test_command 통과
def test_priority_roadmap_repo_machine_constant(self):
    m = rd.merge_layers({"test_command": "a"}, {"test_command": "b"}, "레포 설정@0123abcd", {"test_command": "c"}, [])
    self.assertEqual((m["values"]["test_command"], m["sources"]["test_command"]), ("a", "로드맵"))
    m = rd.merge_layers({}, {"test_command": "b"}, "레포 설정@0123abcd", {"test_command": "c"}, [])
    self.assertEqual(m["sources"]["test_command"], "레포 설정@0123abcd")
    m = rd.merge_layers({}, {}, "레포 설정@0123abcd", {"test_command": "c"}, [])
    self.assertEqual(m["sources"]["test_command"], "기계 상태(임시)")
def test_folder_under_git_or_root_is_error(self): ...                   # ".git/x/" · "." · "./" · "/abs/" · "a/../b/" → errors 에 한 줄
```

- [ ] **Step 2: 돌려 실패를 본다.** Run: `python3 -m unittest plugins/spec-distill/tests/test_repo_defaults.py -v` — Expected: `AttributeError: module 'repo_defaults' has no attribute 'strict_frontmatter'` 류 FAIL.
- [ ] **Step 3: `strict_frontmatter` · `check_layer` · `merge_layers` 를 구현한다.** 판독은 `roadmap_model.frontmatter` 와 같은 줄 규칙(들여쓴 줄 · 목록 줄 · `#` 줄은 건너뜀)에 위 오류만 더한다. ` #` 판정은 따옴표를 벗기기 전 값에서 「따옴표로 시작하지 않고 ` #` 를 품음」.
- [ ] **Step 4: 통과를 본다.** 같은 명령 — Expected: OK. 옛 `repo_settings` 테스트는 같은 뜻의 `merge_layers` 테스트로 옮기고 지운다.
- [ ] **Step 5: 변이 하나씩**(복원은 `git checkout HEAD --`): ` #` 판정을 지움 · 층 표에서 `branch_prefix` 를 로드맵 층에 넣음 · 우선순위의 repo/machine 순서 반전 — 셋 다 RED 를 본다.
- [ ] **Step 6: 커밋** — `git commit -m "feat(spec-distill): 해결자의 엄격한 머리말 · 닫힌 키 · 층 넷 합치기" -- plugins/spec-distill/scripts/repo_defaults.py plugins/spec-distill/tests/test_repo_defaults.py`

---

### Task 2: 해결자 — 기본 브랜치 판의 설정 파일 · `resolve` · CLI `get` · `check-path` (AC1 · AC3 · AC4 의 명령)

**Files:**
- Modify: `plugins/spec-distill/scripts/repo_defaults.py`
- Test: `plugins/spec-distill/tests/test_repo_defaults_git.sh` (새, 임시 레포)

**Interfaces:**
- Consumes: Task 1 의 `strict_frontmatter` · `check_layer` · `merge_layers`
- Produces:
  - `read_repo_file(cwd: str) -> tuple[dict | None, str | None, list[str]]` — (레포 층, 출처 라벨 `레포 설정@<8자>`, 알림). 기본 ref 커밋에서 `git ls-tree <커밋> -- .devbrew.md` 의 mode 가 `100644` 가 아니면 `SettingsError("not_regular_file")`, 내용 첫 줄이 `version https://git-lfs` 로 시작하면 `"lfs_pointer"`. 기본 ref 에 파일이 없고 작업 트리에 있으면 알림 「레포 설정 파일(.devbrew.md)이 아직 기본 브랜치에 없다 — 기본값을 쓴다」. 기본 ref 가 없으면 (None, None, [알림]) — 이때 `merge_layers` 의 기본값 출처는 `기본값(기본 브랜치 없음 — 설정 파일 못 읽음)` 이고, 작업 트리에 파일이 있으면 알림을 「크게」(앞에 `[주의]`).
  - `resolve(cwd: str, roadmap: str | None = None, roadmap_text: str | None = None, machine_reader=None) -> dict` — `merge_layers` 의 반환. 로드맵을 받지 않으면 기계 상태 층을 건너뛰고 알림 「로드맵 없음 — 기계 상태 층 건너뜀」. `roadmap_text` 를 안 주면 기본 ref 의 로드맵을 읽는다. `machine_reader(roadmap) -> dict` 는 Task 4 가 넣는다(기본: 기계 상태 `## 레포 설정` 을 읽는 함수, 깨졌으면 `SettingsError("unreadable", where="machine")`).
  - CLI `repo_defaults.py get <키> [--roadmap <레포 상대 경로>]` · `check-path <키> <경로>` (종료 코드는 위 「설계에 없던 결정 2 · 3」)

- [ ] **Step 1: 실패하는 셸 테스트를 쓴다** — 임시 레포 셋(`trunk` 기본 · 원격은 로컬 bare · `git remote set-head origin --auto`). 사례:
  - `test_default_ref_file_wins_over_worktree`: 기본 브랜치에 `.devbrew.md`(`interview_dir: notes/iv/`), 작업 브랜치에서 `interview_dir: other/` 로 고침 → `get interview_dir` = `notes/iv/`, stderr 에 `레포 설정@<8자>`.
  - `test_worktree_only_file_notice`: 기본 브랜치에 없음 · 작업 트리에만 있음 → 값 = 기본값, stderr 에 「아직 기본 브랜치에 없다」.
  - `test_no_default_ref_uses_constants_with_source`: `origin/HEAD` 를 지움 → rc 0, 값 = 기본값, stderr 에 `기본값(기본 브랜치 없음 — 설정 파일 못 읽음)`. 작업 트리에 파일이 있으면 `[주의]`.
  - `test_symlink_and_lfs_refused`: 기본 브랜치의 `.devbrew.md` 가 링크(120000) → rc 3 「일반 파일이 아니다」; LFS 포인터 내용 → rc 3 「LFS」.
  - `test_get_no_value_rc1`: `get test_command`(어디에도 없음) → rc 1, stdout 비었음.
  - `test_get_broken_rc3`: 같은 키 둘 · BOM · 오타 키 → 셋 다 rc 3, stderr 사유가 서로 다르다(AC2 · AC29).
  - `test_check_path`: `check-path roadmaps_dir docs/superpowers/roadmaps/x` rc 0 · `…/Roadmaps/x` rc 3 「대소문자만 다른 경로」 · 디스크의 실제 폴더가 `Roadmaps` 인데 인자는 `roadmaps` → rc 3 (macOS APFS 기본에서만 돈다 — 대소문자 구별 파일시스템이면 이 사례는 건너뛰고 그 사실을 `ok` 줄로) · `docs/x` rc 3 「부모 폴더가 다르다」.
  - 양성 대조 하나: 설정이 다른 두 레포에서 `get interview_dir` 결과가 다르다.
- [ ] **Step 2: 돌려 실패를 본다.** Run: `bash plugins/spec-distill/tests/test_repo_defaults_git.sh` — Expected: `✗` 줄들(`get` 하위 명령 없음).
- [ ] **Step 3: `read_repo_file` · `resolve` · CLI 를 구현한다.** git 은 `subprocess.run([... "git", "-c", "core.quotePath=false", ...], timeout=5, env=GIT_TERMINAL_PROMPT=0 · GIT_OPTIONAL_LOCKS=0)`. 기본 ref 는 `roadmap_model.DEFAULT_REF` (`import roadmap_model as _rm`).
- [ ] **Step 4: 통과를 본다.** 같은 명령 — Expected: `✗` 0. `chmod +x` 후 `git ls-files -s` 로 100755 확인.
- [ ] **Step 5: 변이**: 기본 ref 대신 작업 트리를 읽게 바꿈 → `test_default_ref_file_wins_over_worktree` RED · mode 검사를 지움 → 링크 사례 RED · `get` 의 빈 값 rc 를 0 으로 → `test_get_no_value_rc1` RED.
- [ ] **Step 6: 커밋** — `feat(spec-distill): 해결자가 기본 브랜치의 레포 설정 파일을 읽고 get · check-path 를 낸다`

---

### Task 3: 기본 브랜치 — 전체 참조 이름 · 고치는 법 · 원격 대조 (AC9 의 spec-distill 몫 · AC10 · AC11)

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_model.py` (`NO_ORIGIN` 만 더함), `repo_defaults.py`, `roadmap_status.py` (`Git.default_branch`), `control_plane.py` (`default_ref` · `statusline_text` · `gather` 의 `no_default`), `conductor_ledger.py` (`NO_DEFAULT` 를 내는 자리 셋), `merge_check.py` (`run` 의 `--abbrev-ref` 자리 · fetch 뒤 대조), `skills/epic-conductor/SKILL.md` (진입 단계 3 뒤 대조 펜스 한 줄)
- Test: `plugins/spec-distill/tests/test_default_branch.sh` (새), `tests/test_roadmap_approval.py` (`OneDefaultRef`)

**Interfaces:**
- Produces:
  - `roadmap_model.NO_ORIGIN = "기본 브랜치를 알 수 없다 — origin 원격이 없다. git remote add origin <URL> 로 더한 뒤 git remote set-head origin --auto 를 돈다"`
  - `repo_defaults.default_branch(cwd) -> tuple[str | None, str | None, str | None]` — (커밋, 짧은 이름, 못 찾은 사유). 짧은 이름은 `git rev-parse --symbolic-full-name refs/remotes/origin/HEAD` 의 결과에서 접두 `refs/remotes/origin/` 을 벗긴 것; 접두가 아니면 사유. 사유는 `origin` 원격이 없으면 `NO_ORIGIN`, 있으면 `NO_DEFAULT`.
  - `repo_defaults.check_remote_head(cwd, local_short: str, timeout: float = 10.0) -> tuple[str, str]` — (`"same"` · `"differs"` · `"unchecked"`, 한 줄). `differs` 문장: 「원격 기본 브랜치(<원격>)가 로컬 기본 브랜치(<로컬>)와 다르다 — git remote set-head origin --auto 로 맞춘 뒤 다시 돈다」. `unchecked` 문장: 「원격과 대조하지 못했다 — 로컬 기본 브랜치 <이름> 을 썼다」.
  - CLI `default-branch [--check-remote]` — 종료 코드 0 · 3 · 5.

- [ ] **Step 1: 실패하는 테스트.** `test_default_branch.sh` 사례:
  - `trunk_repo`: 기본 `trunk` → `default-branch` 가 `trunk`.
  - `local_branch_named_origin_main`: 로컬 브랜치 `origin/main` 을 만든 레포 → 여전히 `main`(AC11 — `--short` 결과 벗기기의 회귀 증인).
  - `no_origin`: 원격 없음 → rc 3, stderr 에 `git remote add origin` (AC29 「origin 이 없는 레포」).
  - `no_head`: 원격은 있고 `origin/HEAD` 없음 → rc 3, stderr 에 `git remote set-head origin --auto`.
  - `renamed_default`: bare 원격의 HEAD 를 `trunk` 로 바꾸고 클론에서 `git fetch` 만 → `--check-remote` rc 5, 문장에 두 이름(AC10 · AC29 「기본 브랜치 개명 뒤」).
  - `offline`: 원격 URL 을 없는 경로로 바꿈 → `--check-remote` rc 0, stderr 에 「원격과 대조하지 못했다」.
  - `merge_check_stops_on_rename`: 같은 개명 레포에서 `merge_check.py run --roadmap … --branch …` rc 3, 출력에 `set-head`.
  - `statusline_names_default`: `control_plane.py statusline` 출력에 `기본 브랜치 trunk` 와 「(어느 원격 · 브랜치든)」.
  - `OneDefaultRef` 에 `self.assertIs(rd._rm.DEFAULT_REF, M.DEFAULT_REF)` 와 「`repo_defaults.py` 에 `DEFAULT_REF = "` 가 없다」를 더한다.
- [ ] **Step 2: 돌려 실패를 본다.** Run: `bash plugins/spec-distill/tests/test_default_branch.sh` — Expected: `✗` 줄들.
- [ ] **Step 3: 구현.** `roadmap_status.Git.default_branch` · `control_plane.default_ref` · `conductor_ledger` 의 세 자리 · `merge_check.run` 이 `repo_defaults.default_branch` 의 짧은 이름과 사유를 쓴다(사유 그대로 보인다). `merge_check.run` 은 fetch 뒤 `check_remote_head` 가 `differs` 면 `Stop(3, …)`. 지휘자 진입 단계 3 의 펜스 끝에 `python3 "$SD/scripts/repo_defaults.py" default-branch --check-remote` 를 더하고, 표에 「rc 3 · 5 면 그 줄을 보이고 멈춘다 · rc 0 의 「대조하지 못했다」 줄은 보이고 간다」 한 줄. 상태줄은 네트워크를 쓰지 않고 `기본 브랜치 <이름> · 받은 지 N분(어느 원격 · 브랜치든)`.
- [ ] **Step 4: 통과를 본다.** 같은 명령 + `python3 -m unittest plugins/spec-distill/tests/test_roadmap_approval.py plugins/spec-distill/tests/test_control_plane.py` — Expected: OK.
- [ ] **Step 5: 변이**: 접두 벗기기를 `rsplit("/",1)[-1]` 로(→ `feature/x` 꼴 기본 브랜치 사례를 하나 더해 RED) · `differs` 를 무시 → `renamed_default` RED · 오프라인을 멈춤으로 → `offline` RED.
- [ ] **Step 6: 커밋** — `fix(spec-distill): 기본 브랜치를 전체 참조 이름에서 얻고 원격과 대조한다`

---

### Task 4: 흡수 — 상태 계산 · 상태줄 · 스위트 대조가 해결자를 지난다 (AC1 의 소비자 · AC5)

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_status.py` (`build` 의 `repo_settings` 자리), `control_plane.py` (설정을 쓰는 자리), `merge_check.py` (`machine_settings` · `run` 의 설정 · 패턴 자리 · 출처가 `기계 상태(임시)` 면 「이 값을 레포 설정 파일(.devbrew.md)에 올린다」 한 줄), `conductor_state.py` (`## 레포 설정` 읽기 함수 하나), `references/conducting.md` (걸음 5 의 종료 코드 6 문장 — 「다음 로드맵 수정 PR 에서 frontmatter `test_command` 로 올리고」를 「레포 설정 파일에 올리자고 알리고」로)
- Test: `plugins/spec-distill/tests/test_merge_check.sh`, `tests/test_roadmap_status.sh`

**Interfaces:**
- Consumes: Task 2 의 `resolve(cwd, roadmap, roadmap_text, machine_reader)`
- Produces: `conductor_state.repo_settings_rows(path, roadmap_rel) -> dict[str, str]` — `## 레포 설정` 의 키 → 값. 같은 키 둘이면 `MachineError`(지금의 「마지막 줄이 이김」을 없앤다). `merge_check.machine_settings` 는 지우고 이것을 `machine_reader` 로 넘긴다.
- `roadmap_status` 의 보고 `settings` 에 `notices` 를 더한다. `report["settings"]["sources"]` 의 값은 위 출처 표기다.

- [ ] **Step 1: 실패하는 테스트.**
  - `test_merge_check.sh`: 기계 상태 `## 레포 설정` 에 `test_command` 가 둘 → rc 3 「같은 키」 · 로드맵에 `test_failure_pattern` 이 있으면 기계 상태 값은 안 쓴다(출처 `로드맵`) · 로드맵에 없고 `.devbrew.md` 에 있으면 출처 `레포 설정@<8자>` · 기계 상태에 `review_model` → rc 3 「기계 상태 층이 받지 않는 키」(AC23b).
  - `test_roadmap_status.sh`: `--json` 의 `settings.sources.specs_dir` 가 `.devbrew.md` 가 있으면 `레포 설정@` 로 시작한다 · 로드맵 머리말에 `roadmaps_dir` 가 있으면 `format_errors` 에 「로드맵 층이 받지 않는 키」.
- [ ] **Step 2: 실패를 본다.** Run: `bash plugins/spec-distill/tests/test_merge_check.sh; bash plugins/spec-distill/tests/test_roadmap_status.sh` — Expected: 새 사례 `✗`.
- [ ] **Step 3: 구현.** 세 스크립트가 `repo_settings(meta)` 대신 `resolve(...)` 를 부른다. `merge_check.run` 의 `pattern` 은 `resolve` 의 `test_failure_pattern` 값과 출처로(직접 `meta[...]` 를 읽지 않는다). `SettingsError` 는 각 스크립트의 「검사 불가」(rc 3 · `format_errors`)로.
- [ ] **Step 4: 통과를 본다.** 같은 명령 + `python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_*.py'` — Expected: 새 실패 없음.
- [ ] **Step 5: 커밋** — `refactor(spec-distill): 상태 계산 · 상태줄 · 스위트 대조의 레포 설정을 해결자 하나로`

---

### Task 5: 로드맵 찾기 하나 (AC6)

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_model.py`, `control_plane.py` (`candidates` · `ROADMAP_RE` 지움 · `GIT_OK` 에 `cat-file`), `conductor_ledger.py` (`c_roadmaps`), `repo_defaults.py` (CLI `roadmap-check`)
- Test: `plugins/spec-distill/tests/test_roadmap_model.py`, `tests/test_control_plane.sh`, `tests/test_conductor_ledger.py`

**Interfaces:**
- Produces:
  - `roadmap_model.roadmap_verdict(path: str, text: str | None, roadmaps_dir: str) -> tuple[str, str]` — (`"roadmap"` · `"not_roadmap"` · `"unreadable"`, 사유). 모양: `path` 가 `roadmaps_dir` 바로 아래 폴더 한 단계 안의 `.md` ∧ 머리말 `type: roadmap`. 머리말을 못 읽으면 `"unreadable"`(조용히 빼지 않는다).
  - `roadmap_model.find_roadmaps(paths: list[str], read: Callable[[str], str | None], roadmaps_dir: str) -> tuple[list[str], list[tuple[str, str]]]` — (로드맵, [(검사 불가 경로, 사유)]).
  - CLI `repo_defaults.py roadmap-check <경로>` — 작업 트리 파일로 `roadmap_verdict`; 0 · 3.
- `control_plane.candidates` 와 `c_roadmaps` 는 기본 ref 의 `ls-tree -r -z <main> -- <roadmaps_dir>` 목록과 blob 읽기로 `find_roadmaps` 를 부른다. 검사 불가는 지금처럼 「검사 불가」 행으로 센다.

- [ ] **Step 1: 실패하는 테스트.** `test_roadmap_model.py`: `test_template_and_fixture_are_not_roadmaps`(`plugins/spec-distill/templates/roadmap-template.md` · `plugins/spec-distill/tests/fixtures/conductor-e2e/roadmap.md` 경로 + `type: roadmap` 글 → `not_roadmap`, 사유 「로드맵 폴더 밖」) · `test_two_levels_deep_is_not_roadmap` · `test_unreadable_frontmatter_is_counted` · `test_other_type_in_folder`(`type: epic-bundle` → `not_roadmap`) · `test_any_md_name_in_folder_is_roadmap`(`<dir>x/plan.md` + `type: roadmap` → `roadmap`). `test_control_plane.sh` · `test_conductor_ledger.py`: 설정 폴더가 `plan/roadmaps/` 인 임시 레포에서 두 진입이 같은 목록을 낸다(AC29 「설정 폴더가 다른 레포」).
- [ ] **Step 2: 실패를 본다.** Run: `python3 -m unittest plugins/spec-distill/tests/test_roadmap_model.py -v` — Expected: `roadmap_verdict` 없음.
- [ ] **Step 3: 구현.** 두 진입과 CLI 가 `find_roadmaps` · `roadmap_verdict` 만 부른다(같은 판정의 복제가 없다 — Task 10 의 락이 잰다).
- [ ] **Step 4: 통과를 본다.** 같은 명령들 — Expected: OK.
- [ ] **Step 5: 변이**: `roadmap_verdict` 의 폴더 검사를 지움 → 템플릿 사례 RED · 표지 검사를 지움 → `epic-bundle` 사례 RED.
- [ ] **Step 6: 커밋** — `fix(spec-distill): 로드맵은 정해진 폴더 안 표지로 하나의 함수가 찾는다`

---

### Task 6: 박힌 값 — 인터뷰 · 설계문서 폴더 · 브랜치 접두 (AC8 · AC12 · §2 의 인터뷰 폴더 · spec-review 후보)

**Files:**
- Modify: `plugins/spec-distill/scripts/state_path.py` (`INTERVIEW_DIR` 를 `repo_defaults` 에서 · `interview_state_path` 가 `resolve` 의 `interview_dir`), `control_plane.py` (`interview_files` · `read_interviews` 의 글자 경로), `skills/request-framing/SKILL.md` (산출물 기록 펜스의 `AUDIT` · `SEED` · 워크트리 승낙 절차 2 의 `git branch -m`), `skills/pm-interview/SKILL.md` (`## State location`), `skills/pm-interview/references/finishing.md` (Task 0 Step 4 목록의 인터뷰 경로 · 분해 판단의 로드맵 폴더 안내 · 분해안 표의 브랜치 칸 안내 · Step A `--out` · B-1 안내), `skills/spec-review/SKILL.md` (`review-candidates` 펜스), `references/redecompose.md` (작업 브랜치 두 문장)
- Test: `plugins/spec-distill/tests/test_repo_literals.sh`, `tests/test_decompose_surface.sh`, `tests/test_interview_state.py`

**Interfaces:**
- Consumes: CLI `get interview_dir` · `get specs_dir` · `get roadmaps_dir` · `get branch_prefix` · `default-branch`
- 펜스 꼴(값이 필요한 자리 — rc 와 빈 값을 확인):

```bash
IDIR="$(python3 "$SD/scripts/repo_defaults.py" get interview_dir)" || IDIR=""
[ -n "$IDIR" ] || { echo "[spec-distill] 인터뷰 폴더를 정하지 못했다 — 위 줄의 사유를 고친 뒤 다시 돌린다" >&2; exit 1; }
```

- [ ] **Step 1: 락을 먼저 넓힌다(실패를 본다).** `test_repo_literals.sh` 의 `TARGETS` 에 `skills/request-framing/SKILL.md` · `skills/pm-interview/SKILL.md` · `skills/pm-interview/references/finishing.md` · `skills/spec-review/SKILL.md` · `references/redecompose.md` · `scripts/control_plane.py` · `scripts/state_path.py` · `scripts/roadmap_status.py` 를 더한다. 새 대상마다 「대상이 있다」 · 변이 사본 잡힘 사례가 자동으로 붙는다(기존 `mut` 루프). Run: `bash plugins/spec-distill/tests/test_repo_literals.sh` — Expected: 새 대상의 박힌 줄이 `✗`.
- [ ] **Step 1b: 펜스 꼴 락을 더한다(AC4).** 같은 테스트에 축 하나 — 대상 파일에서 `repo_defaults.py" get ` 을 품은 줄은 `<V>="$(… get …)" || <V>=""` 꼴이고 그 뒤 첫 비지 않은 줄에 `[ -n "$<V>" ]` 가 있다. 경로로 `git add` 범위를 정하는 펜스(`git add -- ` 를 품은 펜스)는 `check-path` 또는 `roadmap-check` 를 부른다. 펜스 판독은 기존 테스트의 펜스 추출기를 쓰고, 변이 둘(rc 확인 줄 지움 · 빈 값 확인 줄 지움)이 RED 인지 본다. 양의 짝: 위 꼴의 줄이 대상에 하나 이상 있다(공허 통과 방지).
- [ ] **Step 2: `test_decompose_surface.sh` 의 글자 락을 「도출하는가」 락으로 바꾼다(AC12).** 지금의 `'새로 fetch 한 \`origin/main\` 에서 \`feature/roadmap-<요지>\` …'` 글자 단언을 지우고, `redecompose.md` 가 `repo_defaults.py" default-branch` 와 `repo_defaults.py" get branch_prefix` 를 가리키고 `origin/main` · `feature/` 글자가 없음을 함께 단언한다(양 · 음 짝). 같은 일을 `test_conducting_reference.sh` 의 `origin/main` · `feature/roadmap-x` 금지 목록이 이미 하는지 확인하고 겹치면 한 곳에 둔다. Run — Expected: `✗`(아직 글자).
- [ ] **Step 3: 고친다.** 파이썬은 `resolve(...)["values"][...]`, 펜스는 위 꼴. `state_path.INTERVIEW_DIR` 은 `repo_defaults.INTERVIEW_DIR` 를 나눈 튜플로 남기되 `interview_state_path` 는 `resolve(root)` 의 값을 쓴다(설정이 깨졌으면 `(None, [사유])`). 인터뷰 상태 경로 두 갈래(`<주제>` · `<주제>-<HHMM>`)가 모두 그 폴더를 지난다. 분해안 표의 브랜치 칸 안내는 「`<branch_prefix><kebab>` — 접두는 `get branch_prefix`」. spec-review 후보 펜스는 `"${SPECS}*-design.md"` 로.
- [ ] **Step 4: 통과를 본다.** Run: `bash plugins/spec-distill/tests/test_repo_literals.sh && bash plugins/spec-distill/tests/test_decompose_surface.sh && python3 -m unittest plugins/spec-distill/tests/test_interview_state.py` — Expected: `✗` 0 · OK.
- [ ] **Step 5: 변이**: 새 대상 하나에 `docs/superpowers/interview/x` 를 되돌려 넣음 → RED · `redecompose.md` 에 `feature/roadmap-` 를 되돌림 → RED · `interview_state_path` 가 상수를 쓰게 → `interview_dir: notes/` 레포 사례 RED.
- [ ] **Step 6: 커밋** — `fix(spec-distill): 인터뷰 · 설계문서 폴더와 브랜치 접두를 해결자에서 얻는다`

---

### Task 7: 끝내기 커밋 펜스 · request-framing 의 기본 브랜치 (AC7 · AC9 · AC10 · AC11 의 펜스 몫)

**Files:**
- Modify: `skills/pm-interview/references/finishing.md` (끝내기 커밋 펜스 `interview-commit`), `skills/request-framing/SKILL.md` (base 도출 펜스와 그 아래 설명 문단)
- Test: `plugins/spec-distill/tests/test_finish_commit_roadmap.sh`, `tests/test_request_framing_entry.sh`

**Interfaces:**
- Consumes: `roadmap-check` · `check-path roadmaps_dir` · `default-branch --check-remote`
- 펜스가 가르는 다섯(그대로 메시지 · 동작):
  - 폴더 없음 → 「brief §7 의 로드맵 폴더가 없어 빼고 진행한다」(지금처럼).
  - 폴더는 있는데 인덱스에 커밋할 파일 없음(빈 폴더) → 「로드맵 폴더에 커밋할 파일이 없어 빼고 진행한다」(지금처럼).
  - 부모가 `roadmaps_dir` 아님 · 대소문자만 다름 · `roadmap-check` 거부 → 커밋하지 않는다(사유 한 줄).
  - 기본 브랜치 없음(rc 3) · 원격과 다름(rc 5) → 커밋하지 않는다, `default-branch` 의 stderr 그대로.
  - 원격 대조 못 함 → 「원격과 대조하지 못했다 …」를 보이고 커밋은 한다.

- [ ] **Step 1: 실패하는 테스트.** `test_finish_commit_roadmap.sh` 에 사례 — 설정 `roadmaps_dir: plan/roadmaps/` 레포에서 §7 이 `plan/roadmaps/x/roadmap.md` 면 커밋에 폴더가 든다 · §7 이 `docs/superpowers/roadmaps/x/roadmap.md`(기본값 자리, 설정과 다름)면 커밋하지 않는다 · 대소문자만 다른 경로 · 빈 폴더 · 폴더 없음 · 로컬 브랜치 `origin/main` 이 있는 레포에서 기본 브랜치(`main`) 위 커밋이 거부된다(AC11 — 지금은 통과해 버린다) · 기본 브랜치 개명 뒤 거부 · 오프라인이면 알림 뒤 커밋. `test_request_framing_entry.sh`: `origin/HEAD` 없음 + `origin/main` 있음 → 「확인 못함」(main/master 대체가 없다) · 로컬 브랜치 `origin/main` 이 있어도 base 가 `origin/<기본>` 전체 이름에서 온다.
- [ ] **Step 2: 실패를 본다.** Run: `bash plugins/spec-distill/tests/test_finish_commit_roadmap.sh; bash plugins/spec-distill/tests/test_request_framing_entry.sh` — Expected: 새 사례 `✗`.
- [ ] **Step 3: 펜스를 고친다.** 끝내기 펜스: `def` 를 `default-branch --check-remote` 의 stdout 으로(rc 3 · 5 면 커밋 갈래를 「기본 브랜치를 판정하지 못했다」로), §7 경로는 `roadmap-check` → `check-path roadmaps_dir "$(dirname -- "$r7")"`, 존재 · 대소문자는 작업 트리, 커밋할 파일은 `git ls-files -- "$RDIR"`(인덱스). request-framing base 펜스: `git symbolic-ref --quiet refs/remotes/origin/HEAD` 전체 이름을 쓰고 main/master 후보 루프를 지운다 — 못 찾으면 「확인 못함」 그대로. 그 아래 설명 문단의 「main/master 둘 다 부재」 문장을 맞춘다.
- [ ] **Step 4: 통과를 본다.** 같은 명령 + 펜스를 `bash -n` 과 `zsh -n` 으로(펜스 추출은 기존 테스트의 추출기) — Expected: `✗` 0.
- [ ] **Step 5: 변이**: `${def#origin/}` 꼴로 되돌림 → AC11 사례 RED · 인덱스 대신 작업 트리로 빈 폴더 판정 → 빈 폴더 사례 RED · 대조 rc 5 무시 → 개명 사례 RED.
- [ ] **Step 6: 커밋** — `fix(spec-distill): 인터뷰 끝 커밋 펜스의 로드맵 폴더 · 기본 브랜치 검사를 해결자로`

---

### Task 8: qg · 공유 기준선 — main/master 대체 지움 · 사유와 안내 (AC9 의 qg 몫)

**Files:**
- Modify: `shared/test-selection/resolve-baseline.sh`, `plugins/quality-gates/scripts/check-review-scope.sh` · `review-diff.sh` · `discover-spec.sh` (기준선 소비 자리), `plugins/quality-gates/skills/quality-pipeline/SKILL.md` (degraded 사유를 보이는 자리), `shared/test-selection/README.md`
- Test: `plugins/quality-gates/tests/test_resolve_baseline.sh`, `shared/tests/test_test_selection_bundle.sh`, `plugins/spec-distill/tests/test_merge_check.sh`

**Interfaces:**
- Produces: `resolve-baseline.sh` 출력에 키 하나 — `degraded_reason: <-|no-default-branch|not-a-repo|no-head|detached|shallow|merge-base>`(7줄, 소비자는 키로 읽는다). `no-default-branch` 면 stderr 에 한 줄: `[resolve-baseline] 기본 브랜치를 찾지 못했다 — origin/HEAD 가 없거나 가리키는 브랜치가 없다. git remote set-head origin --auto 로 고친다`. 기준은 `refs/remotes/origin/HEAD` 하나 — 대체 후보(`origin/main` · `origin/master` · 로컬 `main` · `master`) 없음. `base` 짧은 이름은 전체 이름에서 `refs/remotes/origin/` 을 벗겨 얻는다.
- qg 소비자 셋은 `degraded_reason` 을 자기 출력의 degraded 줄 옆에 그대로 싣고, quality-pipeline 이 그 사유와 안내를 크게 보인다(조용한 fail-open 금지). qg 보호 브랜치 가드(`artifact_branch_guard.sh`)의 고정 목록은 그대로다.

- [ ] **Step 1: 실패하는 테스트.** `test_resolve_baseline.sh`: `origin/HEAD` 없음 + `origin/main` 있음 → `degraded: yes` · `degraded_reason: no-default-branch` · stderr 안내(지금은 `origin/main` 으로 대체해 `no`) · 개명 뒤 dangling `origin/HEAD` → 같은 사유 · `trunk` 기본 → `base: trunk`. 기존 「6줄」 단언이 있으면 7줄로. `check-review-scope.sh` 출력에 `degraded_reason:` 이 실린다.
- [ ] **Step 2: 실패를 본다.** Run: `bash plugins/quality-gates/tests/test_resolve_baseline.sh` — Expected: `✗`.
- [ ] **Step 3: 구현.** 대체 `elif` 넷을 지우고 사유 키를 모든 `emit_degraded` 에 인자로. qg 소비자의 `2>/dev/null` 이 안내를 삼키지 않게 stderr 를 흘린다(또는 사유 키로 같은 문장을 재현).
- [ ] **Step 4: 통과를 본다.** 같은 명령 + `bash shared/tests/test_test_selection_bundle.sh && bash plugins/spec-distill/tests/test_merge_check.sh` — Expected: `✗` 0.
- [ ] **Step 5: 변이**: `origin/main` 대체 한 줄을 되돌림 → 첫 사례 RED · 사유를 `-` 로 → 사유 사례 RED.
- [ ] **Step 6: 커밋** — `fix(quality-gates): 기준선을 origin/HEAD 하나로 — 못 찾으면 사유와 고치는 법을 보인다`

---

### Task 9: 상태 루트 — 자기 무시 · 추적 파일이면 멈춤 · bare 레포 · 환경 변수 공시 (AC24 · §6)

**Files:**
- Modify: `plugins/spec-distill/scripts/state_path.py` (`state_root_for_common` · 새 `ensure_state_root` · CLI `state-root --ensure`), 상태 루트 아래 폴더를 만드는 모든 자리(Step 3 에서 센다 — 60e21baa 기준 `conductor_state.acquire` · `conductor_ledger` 의 `review-pack` · `resource-dir` · `merge_check.run` · `suite_lock` 의 잠금 만들기 · `control_plane.save_cache` 가 상태 루트 아래면), 원장을 처음 만드는 skill 펜스(`state-root` 를 부르는 자리 — `git grep -n 'state_path.py" state-root'`)
- Test: `plugins/spec-distill/tests/test_state_root.sh` (새)

**Interfaces:**
- Produces:
  - `state_root_for_common(common: Path) -> Path` — `common.name == ".git"` 이면 `common.parent / ".claude/spec-distill"`, 아니면 `common / ".claude/spec-distill"`.
  - `class StateRootError(RuntimeError)`; `ensure_state_root(root: Path, cwd: str | None = None) -> list[str]` (알림) — 폴더를 만들고, `.gitignore` 가 없으면 `*` 한 줄로 쓴다(링크면 거부). 그 뒤 `git check-ignore -q <root>/probe` 가 무시하지 않거나 `git ls-files -- <root>` 가 비지 않으면 `StateRootError`(「상태 폴더 아래 파일이 이미 추적된다 — git rm --cached -r <루트> 로 추적을 푼 뒤 다시 돈다」). `GIT_DIR` · `GIT_WORK_TREE` 가 설정돼 있으면 알림 한 줄.
- [ ] **Step 1: 실패하는 테스트**(`test_state_root.sh`): `.gitignore` 가 `.claude/` 를 무시하지 않는 레포에서 `state-root --ensure` 뒤 `git status --porcelain` 이 비었다 · 상태 루트 아래 파일을 `git add -f` 로 추적시킨 레포 → rc ≠ 0 · 안내 문장(AC29 「상태 루트 아래 추적 파일」) · 같은 부모 폴더의 bare 레포 둘(`a.git` · `b.git`)에 각각 worktree 를 두고 `state-root` 가 서로 다르고 각 bare 안이다 · 평범한 레포는 `<레포>/.claude/spec-distill` 그대로 · `GIT_DIR` 설정 시 알림 · 지휘자 표지 잡기(`conductor_ledger.py claim`)가 추적 파일 레포에서 멈춘다(쓰기 자리가 실제로 부른다는 증인).
- [ ] **Step 2: 실패를 본다.** Run: `bash plugins/spec-distill/tests/test_state_root.sh` — Expected: `✗`.
- [ ] **Step 3: 쓰기 자리를 센다.** `git grep -n -e 'mkdir' -e 'state_root(' -e 'state-root' -- plugins/spec-distill/scripts plugins/spec-distill/skills shared/docreview` 결과에서 상태 루트 아래를 만드는 자리를 이 계획에 목록으로 적고 각 자리가 `ensure_state_root` 를 부르게 한다. 읽기 자리(상태줄 · `conductor_state.py path/show` · `machine_for`)는 부르지 않는다.
- [ ] **Step 4: 구현 · 통과.** 같은 명령 — Expected: `✗` 0.
- [ ] **Step 5: 변이**: `.gitignore` 쓰기를 지움 → 첫 사례 RED · `ls-files` 검사를 지움 → 추적 사례 RED · bare 규칙을 지움 → bare 사례 RED. 양성 짝: 평범한 레포 경로 불변 사례가 셋 다에서 GREEN.
- [ ] **Step 6: Task 0 Step 6 의 실측 결과를 여기 적는다.** `.claude/worktrees/` 에 대한 결론(qg 가 잡는가 · 무엇을 안내하나)을 한 문단으로.
- [ ] **Step 7: 커밋** — `fix(spec-distill): 상태 폴더가 스스로를 무시하고 bare 레포마다 갈린다`

---

### Task 10: 작업공간 불변 락 · 읽은 트리 · 회귀 픽스처 (AC27 · AC29 의 계획 1 몫 · §9)

**Files:**
- Create: `plugins/spec-distill/tests/test_workspace_invariance.sh`
- Modify: `plugins/spec-distill/scripts/conductor_ledger.py` (`_tip` 과 충돌 미리 보기 — 로컬 · 원격 끝이 다르면 둘 다), `roadmap_status.py` (보고에 `read_tree`: `기본 브랜치` · `에픽 끝` · `이 작업공간`), `skills/pm-interview/references/finishing.md` (끝 펜스 출력에 「읽은 트리: 이 작업공간」 한 줄), `scripts/check_brief.py` (게이트 출력 머리에 같은 한 줄 — 출력 모양을 잠근 테스트가 있으면 그 기대도), `skills/spec-review/SKILL.md` (경로로 받은 설계문서를 읽는다고 알리는 진입 줄에 같은 꼴)
- Test: 위 새 파일 · `tests/test_check_brief.sh` 에 「읽은 트리」 줄 사례 하나

- [ ] **Step 1: 락을 쓴다.** 임시 레포 하나에 서로 다른 브랜치의 worktree 둘(한쪽은 로드맵과 `.devbrew.md` 를 고치고 커밋만, 기본 브랜치에는 안 넣음). 두 자리에서 `repo_defaults.py get <키>`(아홉 키 전부) · `conductor_ledger.py roadmaps` · `roadmap_status.py --json <로드맵>` 을 돌려 출력이 바이트까지 같다 — `read_tree` 가 `이 작업공간` 인 칸만 비교에서 뺀다. 양성 대조: 설정이 다른 두 레포는 `get interview_dir` 가 다르다(AC27). AC29 의 계획 1 몫을 이 파일에 모은다: `trunk` 레포 끝에서 끝(상태줄 · 로드맵 찾기 · 인터뷰 끝 커밋 · merge_check 가 맞는 값을 낸다) · 설정 폴더 `plan/…` 레포 · origin 없는 레포(안내와 함께 멈춤) · 기본 브랜치 개명(spec-distill `default-branch` rc 5 · qg `resolve-baseline` 사유) · 상태 루트 아래 추적 파일 · BOM · 같은 키 둘 · 오타 키.
- [ ] **Step 2: 돌린다.** Run: `bash plugins/spec-distill/tests/test_workspace_invariance.sh` — Expected: 앞 과제들이 끝났으면 GREEN. GREEN 이 정답인 락이라 변이로 이빨을 본다.
- [ ] **Step 3: 변이**: `resolve` 가 작업 트리 `.devbrew.md` 를 읽게 → 바이트 비교 RED · `roadmap_status` 가 작업 트리 로드맵을 읽게(`--roadmap-file` 기본) → RED · 비교에서 빼는 칸을 넓혀 전체를 뺌 → 양성 대조가 여전히 다름을 보이는지(공허 확인).
- [ ] **Step 4: 충돌 미리 보기 · 읽은 트리.** `conductor_ledger` 의 끝 읽기가 로컬과 원격 추적 ref 를 함께 읽어 다르면 「로컬 끝 <8자> · 원격 끝 <8자>」를 보인다. 테스트 한 줄을 `test_conductor_ledger.py` 에 더한다.
- [ ] **Step 5: 커밋** — `test(spec-distill): 작업공간 불변 락과 devbrew 밖 레포 회귀 픽스처`

---

### Task 11: 문서 · 버전 · 스위트 대조 (AC28 마감)

**Files:**
- Modify: `plugins/spec-distill/README.md` (레포 설정 파일 절 · 지원하는 흐름 · 설정 키 표 · 「`branch_prefix` 와 project-init 브랜치 규칙을 맞춘다」 한 줄 · Principles Instantiated 한 줄), `plugins/spec-distill/CHANGELOG.md`, `plugins/spec-distill/.claude-plugin/plugin.json`, `plugins/quality-gates/README.md` (기준선 문장), `plugins/quality-gates/CHANGELOG.md`, `plugins/quality-gates/.claude-plugin/plugin.json`

- [ ] **Step 1: README.** spec-distill 의 `## 설정` 에 `.devbrew.md` 예시(아홉 키 · 기본값 · 층마다 받는 키 · 「기본 브랜치에 머지된 판만 읽는다」 · 따옴표 규칙), 지원 흐름(「origin 의 기본 브랜치 · PR 만 본다 — fork 의 부모 레포로 PR 을 내는 흐름 · 원격 없는 로컬 레포는 지원하지 않는다」), devbrew 밖 레포 절(상태 폴더 자기 무시 · Task 9 Step 6 결론). Principles Instantiated 에 「CLAUDE.md 레포 전용 값 금지 — 레포 값은 `scripts/repo_defaults.py` 하나가 출처와 함께 낸다」.
- [ ] **Step 2: 버전.** spec-distill · quality-gates minor bump(번호는 머지 직전 지휘자가 정한다 — 그때 고쳐 쓴다). CHANGELOG `## [<판>] — <날짜>` 에 Added(설정 파일 · CLI · 상태 폴더 자기 무시) · Changed(기본 브랜치 대체 제거 — 「origin/HEAD 가 없으면 이제 멈춘다: `git remote set-head origin --auto`」) · Fixed(로드맵 후보에 템플릿 · 픽스처 · `--short` 접두 벗기기). Run: `bash shared/tests/test_changelog_integrity.sh` — Expected: GREEN.
- [ ] **Step 3: 전체 스위트 대조.** Task 0 의 `baseline.sh` 로 `after` 를 재고 이름 집합 차를 본다. Expected: 새 실패 0 — 있으면 고치거나 이유를 적는다.
- [ ] **Step 4: 커밋** — `docs(spec-distill): 레포 설정 파일 · 지원 흐름 · 판 올림`
- [ ] **Step 5: 마지막 전체 리뷰에 AC 를 싣는다.** 고른 실행 방식의 마지막 전체 리뷰에 설계문서 `## Acceptance Criteria` 의 이 계획 몫(AC1~AC12 · AC23b · AC24 · AC27 · AC28 · AC29) 목록을 싣고, AC 마다 `AC1: 구현됨 — <근거>` 꼴(판정은 구현됨 · 미룸 · 빠짐)로 보고하게 한다. 그 보고를 git 이 추적하지 않는 파일(`$HOME/.claude/sdd-mirror/r8-plan1/ac-report.md`)에 적고, 미룸 · 빠짐과 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올린 뒤 PR 전에 `python3 <spec-distill>/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-10-20-dependency-portability-design.md "$HOME/.claude/sdd-mirror/r8-plan1/ac-report.md" --acs "AC1~AC12 · AC23 · AC24 · AC27~AC29"` 를 돌려 경고를 사용자에게 보인다(`AC23b` 는 도구가 `AC23` 으로 센다 — AC23 의 나머지 몫은 계획 2).
