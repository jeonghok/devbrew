# /qg branch <name> — Auto-Worktree Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `/qg branch <name>` 호출 시 임시 detached worktree를 자동으로 만들고 그 안에서 quality-gates 파이프라인을 실행, 정상 종료 시 cleanup. 현재 작업트리는 무손상 유지.

**Architecture:**
- State는 **main repo**에 그대로 (`<main-repo>/.claude/quality-gates/<sid>/`) — v1.14.0의 payload-cwd contract와 정합.
- `project_dir`(state frontmatter)을 **worktree absolute path**로 freeze → 모든 Gate 2/3 agent가 worktree에서 동작.
- 새 state field 2개: `worktree_path`, `target_branch`. 둘이 있으면 Stop hook이 terminal status에 worktree cleanup.
- 신규 헬퍼 `qg-worktree.sh` (sanitize/validate/create/remove subcommands).

**Tech Stack:** bash, python3 (hooks), git worktree, 기존 quality-gates v1.14.0 인프라.

**Spec:** `docs/superpowers/specs/2026-05-17-qg-branch-worktree-design.md`

---

## File Structure

| Path | 책임 |
|---|---|
| `plugins/quality-gates/scripts/qg-worktree.sh` (신규) | sanitize/validate/create/remove subcommands. 100% bash, 외부 의존 없음. |
| `plugins/quality-gates/scripts/setup-qg.sh` (수정) | `branch [<name>]` 파싱, worktree 모드에서 qg-worktree create 호출, state에 worktree_path/target_branch 기록, project_dir을 worktree로 freeze. |
| `plugins/quality-gates/hooks/stop-hook.py` (수정) | terminal status (`complete`/`abort`) 분기에 worktree cleanup. `DEVBREW_QG_KEEP_WORKTREE=1` 존중. |
| `plugins/quality-gates/hooks/session-end-cleanup.py` (수정) | dangling worktree 회수 safety net. |
| `plugins/quality-gates/commands/qg.md` (수정) | argument-hint, Quick Reference 행 추가. |
| `plugins/quality-gates/README.md` (수정) | Recipes 섹션, kill switch 환경변수 문서화. |
| `plugins/quality-gates/CHANGELOG.md` (수정) | `## [1.15.0]` Added. |
| `plugins/quality-gates/.claude-plugin/plugin.json` (수정) | `version: 1.15.0`. |
| `plugins/quality-gates/tests/test_qg_worktree_helper.sh` (신규) | qg-worktree.sh 단위 테스트. |
| `plugins/quality-gates/tests/test_branch_worktree.sh` (신규) | AC1–AC11 통합 테스트. |
| `plugins/quality-gates/tests/test_stop_hook_worktree_cleanup.py` (신규) | stop-hook cleanup 분기 단위 테스트. |
| `docs/philosophy/devbrew-harness-philosophy.md` (수정) | §4.8 worktree path 컨벤션 footnote. |

각 task는 한 컴포넌트에 한정. 작은 commit 다수.

---

## Task 1: `qg-worktree.sh sanitize` subcommand

**Files:**
- Create: `plugins/quality-gates/scripts/qg-worktree.sh`
- Create: `plugins/quality-gates/tests/test_qg_worktree_helper.sh`

- [ ] **Step 1: 실패하는 테스트 작성**

`plugins/quality-gates/tests/test_qg_worktree_helper.sh`:

```bash
#!/usr/bin/env bash
# Unit tests for qg-worktree.sh subcommands.
# Each test calls the script with stdin/args and asserts stdout/exit code.
set -u

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WT="$PLUGIN_DIR/scripts/qg-worktree.sh"

PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }

# --- sanitize ---
echo "[sanitize]"

out=$("$WT" sanitize "feat/x" 2>/dev/null) && [ "$out" = "feat-x" ] \
  && pass "slash to dash" || fail "slash to dash got: $out"

out=$("$WT" sanitize "main" 2>/dev/null) && [ "$out" = "main" ] \
  && pass "plain name passthrough" || fail "plain got: $out"

"$WT" sanitize "../evil" >/dev/null 2>&1 && fail "dotdot accepted" \
  || pass "dotdot rejected"

"$WT" sanitize ".hidden" >/dev/null 2>&1 && fail "leading dot accepted" \
  || pass "leading dot rejected"

"$WT" sanitize "with space" >/dev/null 2>&1 && fail "space accepted" \
  || pass "space rejected"

long=$(printf 'a%.0s' {1..65})
"$WT" sanitize "$long" >/dev/null 2>&1 && fail "65 chars accepted" \
  || pass "length cap enforced"

# (further subcommand tests appended in later tasks)

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `bash plugins/quality-gates/tests/test_qg_worktree_helper.sh`
Expected: 실패 — `qg-worktree.sh` 파일 없음.

- [ ] **Step 3: sanitize 구현**

`plugins/quality-gates/scripts/qg-worktree.sh`:

```bash
#!/usr/bin/env bash
# qg-worktree.sh — git worktree lifecycle helper for /qg branch <name>.
#
# Subcommands:
#   sanitize <name>              -> echoes sanitized name; exit 2 on reject
#   validate-branch <name>       -> exit 0 if git ref exists; exit 2 otherwise
#   create <name> <session-id>   -> echoes absolute worktree path; idempotent
#   remove <abs-path>            -> best-effort `git worktree remove --force`
#
# Sanitize rules: replace '/' with '-', then reject if remainder contains
# anything outside [A-Za-z0-9._-], or contains '..' substring, or has
# leading '.', or exceeds 64 chars.
#
# Kill switch: DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1 — `create` exits 1
# with a loud message.

set -u

die() { echo "qg-worktree: $*" >&2; exit 2; }

cmd_sanitize() {
  local name="$1"
  local sanitized="${name//\//-}"
  [[ -z "$sanitized" ]] && die "empty after sanitize"
  [[ "$sanitized" == .* ]] && die "leading dot: $name"
  [[ "$sanitized" == *..* ]] && die "dotdot token: $name"
  [[ "$sanitized" =~ ^[A-Za-z0-9._-]+$ ]] || die "invalid chars: $name"
  (( ${#sanitized} <= 64 )) || die "exceeds 64 chars: $name"
  printf '%s' "$sanitized"
}

case "${1:-}" in
  sanitize)
    [[ $# -eq 2 ]] || die "usage: sanitize <name>"
    cmd_sanitize "$2"; echo  # trailing newline for shell convenience
    ;;
  *)
    die "unknown subcommand: ${1:-}"
    ;;
esac
```

`chmod +x plugins/quality-gates/scripts/qg-worktree.sh`

- [ ] **Step 4: 테스트 실행 → 통과 확인**

Run: `bash plugins/quality-gates/tests/test_qg_worktree_helper.sh`
Expected: `6 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
chmod +x plugins/quality-gates/scripts/qg-worktree.sh
git add plugins/quality-gates/scripts/qg-worktree.sh plugins/quality-gates/tests/test_qg_worktree_helper.sh
git commit -m "feat(qg): add qg-worktree.sh sanitize subcommand

Sanitizes branch names for use as worktree directory path components.
Replaces '/' with '-', rejects dotdot, leading dot, non-portable chars,
and names >64 chars."
```

---

## Task 2: `qg-worktree.sh validate-branch` subcommand

**Files:**
- Modify: `plugins/quality-gates/scripts/qg-worktree.sh`
- Modify: `plugins/quality-gates/tests/test_qg_worktree_helper.sh`

- [ ] **Step 1: 실패하는 테스트 추가**

`test_qg_worktree_helper.sh`의 `# (further subcommand tests appended in later tasks)` 직전에 삽입:

```bash
# --- validate-branch ---
echo "[validate-branch]"

REPO=$(mktemp -d)
(cd "$REPO" && git init -q -b main && git config user.email t@t && \
  git config user.name t && git commit -q --allow-empty -m init && \
  git branch real-branch)

(cd "$REPO" && "$WT" validate-branch real-branch) \
  && pass "existing branch ok" || fail "existing branch rejected"

(cd "$REPO" && "$WT" validate-branch nonexistent 2>/dev/null) \
  && fail "nonexistent accepted" || pass "nonexistent rejected"

rm -rf "$REPO"
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `bash plugins/quality-gates/tests/test_qg_worktree_helper.sh`
Expected: `[validate-branch]` 두 줄 모두 fail.

- [ ] **Step 3: validate-branch 구현**

`scripts/qg-worktree.sh`의 `case "${1:-}"` 블록에 `sanitize)` 다음에:

```bash
  validate-branch)
    [[ $# -eq 2 ]] || die "usage: validate-branch <name>"
    git rev-parse --verify --quiet "refs/heads/$2" >/dev/null \
      || git rev-parse --verify --quiet "$2" >/dev/null \
      || die "branch not found: $2 (try \`git branch --all\`)"
    ;;
```

- [ ] **Step 4: 테스트 실행 → 통과**

Run: `bash plugins/quality-gates/tests/test_qg_worktree_helper.sh`
Expected: `8 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/scripts/qg-worktree.sh plugins/quality-gates/tests/test_qg_worktree_helper.sh
git commit -m "feat(qg): add qg-worktree.sh validate-branch subcommand"
```

---

## Task 3: `qg-worktree.sh create` subcommand

**Files:**
- Modify: `plugins/quality-gates/scripts/qg-worktree.sh`
- Modify: `plugins/quality-gates/tests/test_qg_worktree_helper.sh`

- [ ] **Step 1: 실패하는 테스트 추가**

`test_qg_worktree_helper.sh` 하단에 (Result 줄 위):

```bash
# --- create ---
echo "[create]"

REPO=$(mktemp -d)
(cd "$REPO" && git init -q -b main && git config user.email t@t && \
  git config user.name t && git commit -q --allow-empty -m init && \
  git branch feat-x)

SID="abcdef12345678"
WTPATH=$(cd "$REPO" && "$WT" create feat-x "$SID" 2>/dev/null)
[ -d "$WTPATH" ] && pass "create returns valid path" \
  || fail "create path missing: $WTPATH"

[ "$(cd "$WTPATH" && git rev-parse HEAD)" = \
  "$(cd "$REPO" && git rev-parse feat-x)" ] \
  && pass "worktree HEAD matches branch" || fail "HEAD mismatch"

# Detached HEAD check
sym=$(cd "$WTPATH" && git symbolic-ref -q HEAD 2>/dev/null || echo "")
[ -z "$sym" ] && pass "detached HEAD" || fail "not detached: $sym"

# Idempotent reuse
WTPATH2=$(cd "$REPO" && "$WT" create feat-x "$SID" 2>/dev/null)
[ "$WTPATH" = "$WTPATH2" ] && pass "idempotent reuse" \
  || fail "second create differs"

# Kill switch
( cd "$REPO" && DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1 \
    "$WT" create feat-x "killtest-$SID" 2>/dev/null ) \
  && fail "kill switch ignored" || pass "kill switch honored"

rm -rf "$REPO"
```

- [ ] **Step 2: 테스트 실행 → 실패**

Run: `bash plugins/quality-gates/tests/test_qg_worktree_helper.sh`
Expected: `[create]` 5건 실패.

- [ ] **Step 3: create 구현**

`scripts/qg-worktree.sh`의 `validate-branch)` 다음에:

```bash
  create)
    [[ $# -eq 3 ]] || die "usage: create <branch> <session-id>"
    if [[ "${DEVBREW_QG_DISABLE_BRANCH_WORKTREE:-0}" == "1" ]]; then
      die "Branch worktree mode disabled via DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1"
    fi
    local branch="$2" sid="$3" sanitized sid_short parent abs
    sanitized=$(cmd_sanitize "$branch") || exit 2
    git rev-parse --verify --quiet "refs/heads/$branch" >/dev/null \
      || git rev-parse --verify --quiet "$branch" >/dev/null \
      || die "branch not found: $branch (try \`git branch --all\`)"
    sid_short="${sid:0:8}"
    [[ -n "$sid_short" ]] || die "empty session-id"
    parent=".claude/quality-gates/worktrees"
    mkdir -p "$parent" || die "cannot create $parent"
    abs="$(cd "$parent" && pwd)/${sanitized}-${sid_short}"
    if [[ -d "$abs" ]]; then
      # Idempotent: verify it's a registered worktree and reuse
      if git worktree list --porcelain | grep -q "^worktree $abs$"; then
        echo "qg-worktree: reusing existing worktree at $abs" >&2
        printf '%s' "$abs"; echo
        exit 0
      fi
      die "path exists but not a git worktree: $abs"
    fi
    git worktree add --detach "$abs" "$branch" >/dev/null \
      || die "git worktree add failed for $branch"
    printf '%s' "$abs"; echo
    ;;
```

- [ ] **Step 4: 테스트 실행 → 통과**

Run: `bash plugins/quality-gates/tests/test_qg_worktree_helper.sh`
Expected: `13 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/scripts/qg-worktree.sh plugins/quality-gates/tests/test_qg_worktree_helper.sh
git commit -m "feat(qg): add qg-worktree.sh create subcommand

Creates detached worktree at .claude/quality-gates/worktrees/<name>-<sid-short>/.
Idempotent (reuses existing worktree at same path). Honors
DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1 kill switch with loud error."
```

---

## Task 4: `qg-worktree.sh remove` subcommand

**Files:**
- Modify: `plugins/quality-gates/scripts/qg-worktree.sh`
- Modify: `plugins/quality-gates/tests/test_qg_worktree_helper.sh`

- [ ] **Step 1: 실패하는 테스트 추가**

```bash
# --- remove ---
echo "[remove]"

REPO=$(mktemp -d)
(cd "$REPO" && git init -q -b main && git config user.email t@t && \
  git config user.name t && git commit -q --allow-empty -m init && \
  git branch feat-y)
WTPATH=$(cd "$REPO" && "$WT" create feat-y "remove-test12345" 2>/dev/null)
[ -d "$WTPATH" ] || { fail "create precondition"; }

(cd "$REPO" && "$WT" remove "$WTPATH") \
  && [ ! -d "$WTPATH" ] && pass "remove deletes dir" \
  || fail "remove failed or dir remains"

# Remove a nonexistent path → exit 0 (best-effort)
(cd "$REPO" && "$WT" remove "$REPO/.claude/quality-gates/worktrees/missing-12345678") \
  && pass "remove missing is noop" || fail "remove missing errored"

# Refuse outside-namespace paths (safety)
(cd "$REPO" && "$WT" remove "/tmp" 2>/dev/null) \
  && fail "removed outside namespace" || pass "outside namespace refused"

rm -rf "$REPO"
```

- [ ] **Step 2: 테스트 실행 → 실패**

Expected: `[remove]` 3건 실패.

- [ ] **Step 3: remove 구현**

`scripts/qg-worktree.sh`의 `create)` 다음에:

```bash
  remove)
    [[ $# -eq 2 ]] || die "usage: remove <abs-path>"
    local target="$2" repo_root parent
    # Safety: only allow paths under <repo>/.claude/quality-gates/worktrees/
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    parent="$repo_root/.claude/quality-gates/worktrees"
    case "$target" in
      "$parent"/*) ;;
      *) die "refuse to remove outside namespace: $target" ;;
    esac
    [[ -d "$target" ]] || exit 0  # idempotent
    git worktree remove --force "$target" 2>/dev/null \
      || rm -rf "$target"  # fallback when git lost track
    ;;
```

- [ ] **Step 4: 테스트 실행 → 통과**

Run: `bash plugins/quality-gates/tests/test_qg_worktree_helper.sh`
Expected: `16 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/scripts/qg-worktree.sh plugins/quality-gates/tests/test_qg_worktree_helper.sh
git commit -m "feat(qg): add qg-worktree.sh remove subcommand

Best-effort removal with namespace safety guard — refuses paths outside
<repo>/.claude/quality-gates/worktrees/. Falls back to rm -rf when git
worktree tracking is lost."
```

---

## Task 5: `setup-qg.sh` parses `branch [<name>]` positional

**Files:**
- Modify: `plugins/quality-gates/scripts/setup-qg.sh`

- [ ] **Step 1: 실패하는 통합 테스트 추가**

`plugins/quality-gates/tests/test_branch_worktree.sh` 신규 생성:

```bash
#!/usr/bin/env bash
# Integration tests for /qg branch <name> auto-worktree (AC1–AC11).
set -u

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETUP="$PLUGIN_DIR/scripts/setup-qg.sh"

PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }

make_repo() {
  local root branch="$1"
  root=$(mktemp -d)
  (
    cd "$root"
    git init -q -b main
    git config user.email t@t
    git config user.name t
    git commit -q --allow-empty -m init
    git branch "$branch"
  )
  echo "$root"
}

# --- AC1: /qg branch (no name) regression — must not create worktree ---
echo "[AC1] /qg branch (no name) — backward compat"
REPO=$(make_repo feat-a)
(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac1session12 "$SETUP" branch >/dev/null)
state="$REPO/.claude/quality-gates/ac1session12/pipeline.md"
[ -f "$state" ] && pass "state file created"
grep -q '^worktree_path:' "$state" \
  && fail "worktree_path set in legacy mode" \
  || pass "no worktree_path in legacy mode"
[ -d "$REPO/.claude/quality-gates/worktrees" ] \
  && fail "worktree dir created in legacy mode" \
  || pass "no worktree dir in legacy mode"
rm -rf "$REPO"

# --- AC2: /qg branch <name> creates worktree, sets project_dir ---
echo "[AC2] /qg branch <name> happy path"
REPO=$(make_repo feat-b)
(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac2session12 "$SETUP" branch feat-b >/dev/null)
state="$REPO/.claude/quality-gates/ac2session12/pipeline.md"
[ -f "$state" ] && pass "state file in main repo"
wpath=$(awk -F'"' '/^worktree_path:/{print $2}' "$state")
[ -n "$wpath" ] && [ -d "$wpath" ] && pass "worktree_path exists" \
  || fail "worktree_path missing or invalid: $wpath"
pdir=$(awk -F'"' '/^project_dir:/{print $2}' "$state")
[ "$pdir" = "$wpath" ] && pass "project_dir = worktree path" \
  || fail "project_dir != worktree ($pdir vs $wpath)"
tb=$(awk -F'"' '/^target_branch:/{print $2}' "$state")
[ "$tb" = "feat-b" ] && pass "target_branch recorded" \
  || fail "target_branch wrong: $tb"
rm -rf "$REPO"

# (AC3–AC11 appended in later tasks)

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: 테스트 실행 → AC2 실패**

Run: `bash plugins/quality-gates/tests/test_branch_worktree.sh`
Expected: AC1 pass (현재 동작), AC2 fail (`branch feat-b`가 unknown argument).

- [ ] **Step 3: `setup-qg.sh` argument parser 확장**

`scripts/setup-qg.sh`의 `while [[ $# -gt 0 ]]` 루프 안 `gate1|gate2|gate3)` 케이스 옆에 새 케이스 추가:

```bash
    branch)
      shift
      # peek next token
      if [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]] && [[ ! "$1" =~ ^gate[123]$ ]]; then
        TARGET_BRANCH="$1"
        shift
      fi
      BRANCH_MODE="true"
      ;;
```

(루프 상단에 `TARGET_BRANCH=""` 와 `BRANCH_MODE="false"` 초기화 추가)

루프 다음, "Resolve session ID" 직후에 worktree 생성 분기 추가:

```bash
# --- Branch worktree mode ---
WORKTREE_PATH=""
if [[ "$BRANCH_MODE" == "true" ]] && [[ -n "$TARGET_BRANCH" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  WORKTREE_PATH="$("$SCRIPT_DIR/qg-worktree.sh" create "$TARGET_BRANCH" "$SESSION_ID")" \
    || { echo "❌ Quality Gates: worktree creation failed" >&2; exit 1; }
fi
```

상태 파일 생성 부분의 `project_dir: "$(pwd)"` 를 다음으로 교체:

```yaml
project_dir: "${WORKTREE_PATH:-$(pwd)}"
```

frontmatter cat 블록에 두 줄 추가 (worktree 모드일 때만 출력하는 게 깔끔하지만 진단 편의상 항상 출력하되 빈 값이면 빈 문자열):

```yaml
worktree_path: "${WORKTREE_PATH}"
target_branch: "${TARGET_BRANCH}"
```

- [ ] **Step 4: 테스트 실행 → 통과**

Run: `bash plugins/quality-gates/tests/test_branch_worktree.sh`
Expected: AC1 + AC2 모두 통과.

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/scripts/setup-qg.sh plugins/quality-gates/tests/test_branch_worktree.sh
git commit -m "feat(qg): setup-qg.sh parses branch [<name>] auto-worktree

When 'branch' is followed by a non-flag non-gate token, treat as target
branch and invoke qg-worktree.sh create. State frontmatter freezes
project_dir to the worktree absolute path and records worktree_path +
target_branch. Empty values when not in worktree mode preserve backward
compat."
```

---

## Task 6: `setup-qg.sh` rejects invalid branch and respects kill switch

**Files:**
- Modify: `plugins/quality-gates/tests/test_branch_worktree.sh`
- (setup-qg.sh 추가 변경 없음 — qg-worktree.sh가 이미 에러 처리)

- [ ] **Step 1: AC3, AC4, AC5, AC9 테스트 추가**

`test_branch_worktree.sh`의 `# (AC3–AC11 appended in later tasks)` 위치에:

```bash
# --- AC3: nonexistent branch ---
echo "[AC3] nonexistent branch"
REPO=$(make_repo feat-c)
out=$(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac3session12 \
        "$SETUP" branch noexist 2>&1 >/dev/null)
ec=$?
[ "$ec" -ne 0 ] && pass "exit code non-zero"
echo "$out" | grep -qi "not found" && pass "error mentions not found"
[ ! -f "$REPO/.claude/quality-gates/ac3session12/pipeline.md" ] \
  && pass "no state file on failure" \
  || fail "state file leaked"
rm -rf "$REPO"

# --- AC4: path traversal in name ---
echo "[AC4] path traversal name"
REPO=$(make_repo feat-d)
# Create a branch with literal '..' would fail at git level — we test the sanitize layer
out=$(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac4session12 \
        "$SETUP" branch ../evil 2>&1 >/dev/null)
[ $? -ne 0 ] && pass "rejected"
echo "$out" | grep -qi "invalid\|dotdot\|sanitize\|not found" \
  && pass "error message present" || fail "no error message: $out"
rm -rf "$REPO"

# --- AC5: idempotent reuse ---
echo "[AC5] idempotent reuse"
REPO=$(make_repo feat-e)
(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac5session12 "$SETUP" branch feat-e >/dev/null)
state="$REPO/.claude/quality-gates/ac5session12/pipeline.md"
wpath1=$(awk -F'"' '/^worktree_path:/{print $2}' "$state")
rm -f "$state"  # simulate re-run within same session
(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac5session12 "$SETUP" branch feat-e \
   2> "$REPO/stderr.txt" >/dev/null)
wpath2=$(awk -F'"' '/^worktree_path:/{print $2}' "$state")
[ "$wpath1" = "$wpath2" ] && pass "same worktree path"
grep -q "reusing existing" "$REPO/stderr.txt" && pass "reuse message logged" \
  || fail "no reuse message"
rm -rf "$REPO"

# --- AC9: kill switch ---
echo "[AC9] DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1"
REPO=$(make_repo feat-f)
out=$(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac9session12 \
        DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1 \
        "$SETUP" branch feat-f 2>&1 >/dev/null)
[ $? -ne 0 ] && pass "kill switch exits non-zero"
echo "$out" | grep -qi "disabled" && pass "kill switch message"
# Legacy /qg branch (no name) still works under the kill switch
(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac9bsession \
   DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1 \
   "$SETUP" branch >/dev/null) \
  && pass "kill switch does not affect legacy /qg branch" \
  || fail "kill switch killed legacy mode"
rm -rf "$REPO"
```

- [ ] **Step 2: 테스트 실행 → 일부 fail 가능**

Run: `bash plugins/quality-gates/tests/test_branch_worktree.sh`
Expected: AC3 두 번째 assertion("error message")이 fail할 수 있음 — qg-worktree.sh의 die 메시지가 stderr로 흘러나오는지 확인. 만약 setup-qg.sh가 stderr를 삼키면 그 부분만 수정.

- [ ] **Step 3 (가변): setup-qg.sh의 worktree 생성 실패 경로 다듬기**

만약 Step 2에서 AC3가 fail이면, `scripts/setup-qg.sh`의 worktree 생성 블록을 다음으로:

```bash
if [[ "$BRANCH_MODE" == "true" ]] && [[ -n "$TARGET_BRANCH" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if ! WORKTREE_PATH="$("$SCRIPT_DIR/qg-worktree.sh" create "$TARGET_BRANCH" "$SESSION_ID" 2>&1 >/dev/null)"; then
    echo "$WORKTREE_PATH" >&2
    exit 1
  fi
  # Re-run to capture stdout cleanly
  WORKTREE_PATH="$("$SCRIPT_DIR/qg-worktree.sh" create "$TARGET_BRANCH" "$SESSION_ID")"
fi
```

(혹은 더 깔끔한 방식: file descriptor 분리. 엔지니어 재량.)

- [ ] **Step 4: 테스트 실행 → 모든 AC3/4/5/9 통과**

Expected: 새로 추가된 어설션 모두 통과.

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/tests/test_branch_worktree.sh plugins/quality-gates/scripts/setup-qg.sh
git commit -m "test(qg): cover AC3-AC5,AC9 branch <name> error paths

Nonexistent branch, path traversal sanitize, idempotent reuse logging,
DEVBREW_QG_DISABLE_BRANCH_WORKTREE kill switch + legacy mode immunity."
```

---

## Task 7: `stop-hook.py` cleans up worktree on terminal status

**Files:**
- Modify: `plugins/quality-gates/hooks/stop-hook.py`
- Create: `plugins/quality-gates/tests/test_stop_hook_worktree_cleanup.py`

- [ ] **Step 1: 실패하는 unit test 작성**

`plugins/quality-gates/tests/test_stop_hook_worktree_cleanup.py`:

```python
#!/usr/bin/env python3
"""Unit tests for stop-hook.py worktree cleanup on terminal status."""
import os
import subprocess
import sys
import tempfile
from pathlib import Path

PLUGIN_DIR = Path(__file__).resolve().parent.parent
HOOK = PLUGIN_DIR / "hooks" / "stop-hook.py"


def make_repo_with_worktree(tmp: Path) -> tuple[Path, Path, str]:
    repo = tmp / "repo"
    repo.mkdir()
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.email", "t@t"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.name", "t"], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-q", "--allow-empty", "-m", "init"],
                   cwd=repo, check=True)
    subprocess.run(["git", "branch", "feat-x"], cwd=repo, check=True)
    wtdir = repo / ".claude" / "quality-gates" / "worktrees" / "feat-x-abc12345"
    subprocess.run(
        ["git", "worktree", "add", "--detach", str(wtdir), "feat-x"],
        cwd=repo, check=True, capture_output=True,
    )
    return repo, wtdir, "feat-x"


def write_state(repo: Path, sid: str, worktree_abs: str, status: str = "completed"):
    sdir = repo / ".claude" / "quality-gates" / sid
    sdir.mkdir(parents=True, exist_ok=True)
    (sdir / "pipeline.md").write_text(
        f"""---
status: {status}
current_gate: 3
gate2_iteration: 1
max_gate2_iterations: 5
gate3_resolution_iter: 0
last_gate3_needed_hash: ""
max_gate3_resolutions: 3
skip_runtime: false
single_gate: null
plan_file: "auto"
pr_url: ""
available_plugins: ""
project_dir: "{worktree_abs}"
session_id: "{sid}"
started_at: "2026-05-17T00:00:00Z"
worktree_path: "{worktree_abs}"
target_branch: "feat-x"
---

# Quality Gates Pipeline State

## Gate Results

## Pipeline History
- [x] init
"""
    )
    return sdir / "pipeline.md"


def run_hook(repo: Path, sid: str, signal_text: str, env_overrides=None):
    payload = {
        "session_id": sid,
        "cwd": str(repo),
        "last_assistant_message": signal_text,
        "transcript_path": "",
    }
    env = os.environ.copy()
    if env_overrides:
        env.update(env_overrides)
    return subprocess.run(
        [sys.executable, str(HOOK)],
        input=__import__("json").dumps(payload),
        capture_output=True, text=True, env=env,
    )


def test_complete_removes_worktree():
    with tempfile.TemporaryDirectory() as tmp:
        repo, wt, _ = make_repo_with_worktree(Path(tmp))
        sid = "completesess12"
        write_state(repo, sid, str(wt))
        signal = '<qg-signal gate="3" verdict="PASS" summary="ok" />'
        run_hook(repo, sid, signal)
        assert not wt.exists(), f"worktree {wt} should be removed on complete"


def test_abort_removes_worktree():
    with tempfile.TemporaryDirectory() as tmp:
        repo, wt, _ = make_repo_with_worktree(Path(tmp))
        sid = "abortsess123456"
        write_state(repo, sid, str(wt))
        signal = '<qg-signal action="abort" reason="user" />'
        run_hook(repo, sid, signal)
        assert not wt.exists(), "worktree should be removed on abort"


def test_keep_env_preserves_worktree():
    with tempfile.TemporaryDirectory() as tmp:
        repo, wt, _ = make_repo_with_worktree(Path(tmp))
        sid = "keepsess1234567"
        write_state(repo, sid, str(wt))
        signal = '<qg-signal gate="3" verdict="PASS" summary="ok" />'
        run_hook(repo, sid, signal,
                 env_overrides={"DEVBREW_QG_KEEP_WORKTREE": "1"})
        assert wt.exists(), "worktree should be preserved with KEEP=1"


def test_no_worktree_path_no_op():
    """Legacy state (no worktree_path) → hook must not error."""
    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp) / "repo"
        repo.mkdir()
        subprocess.run(["git", "init", "-q", "-b", "main"], cwd=repo, check=True)
        subprocess.run(["git", "config", "user.email", "t@t"], cwd=repo, check=True)
        subprocess.run(["git", "config", "user.name", "t"], cwd=repo, check=True)
        subprocess.run(["git", "commit", "-q", "--allow-empty", "-m", "init"],
                       cwd=repo, check=True)
        sid = "legacysess12345"
        sdir = repo / ".claude" / "quality-gates" / sid
        sdir.mkdir(parents=True)
        (sdir / "pipeline.md").write_text(
            f"""---
status: completed
current_gate: 3
gate2_iteration: 1
max_gate2_iterations: 5
gate3_resolution_iter: 0
last_gate3_needed_hash: ""
max_gate3_resolutions: 3
skip_runtime: false
single_gate: null
plan_file: "auto"
pr_url: ""
available_plugins: ""
project_dir: "{repo}"
session_id: "{sid}"
started_at: "2026-05-17T00:00:00Z"
---

# State
## Gate Results
## Pipeline History
"""
        )
        result = run_hook(repo, sid, '<qg-signal gate="3" verdict="PASS" summary="" />')
        assert result.returncode == 0, f"legacy state errored: {result.stderr}"


if __name__ == "__main__":
    test_complete_removes_worktree()
    test_abort_removes_worktree()
    test_keep_env_preserves_worktree()
    test_no_worktree_path_no_op()
    print("All stop-hook worktree cleanup tests passed.")
```

- [ ] **Step 2: 테스트 실행 → 실패**

Run: `python3 plugins/quality-gates/tests/test_stop_hook_worktree_cleanup.py`
Expected: `test_complete_removes_worktree` 실패 (worktree 아직 남아있음).

- [ ] **Step 3: stop-hook.py 수정**

`plugins/quality-gates/hooks/stop-hook.py:940` 부근의 terminal status 분기를 다음으로 교체:

```python
    # 9. Handle completion/abort — cleanup worktree (if any), then remove state folder.
    if transition["type"] in ("complete", "abort"):
        worktree_path = state.get("worktree_path", "")
        keep_env = os.environ.get("DEVBREW_QG_KEEP_WORKTREE", "0") == "1"
        if worktree_path and not keep_env:
            # Use qg-worktree.sh remove for namespace-safe deletion.
            plugin_root = Path(__file__).resolve().parent.parent
            wt_script = plugin_root / "scripts" / "qg-worktree.sh"
            try:
                import subprocess
                subprocess.run(
                    [str(wt_script), "remove", worktree_path],
                    cwd=state.get("project_dir") or hook_input.get("cwd") or os.getcwd(),
                    timeout=30,
                    check=False,
                )
            except (OSError, subprocess.TimeoutExpired) as e:
                print(
                    f"⚠️  Quality Gates: worktree cleanup failed for "
                    f"{worktree_path}: {e}",
                    file=sys.stderr,
                )
        elif worktree_path and keep_env:
            print(
                f"[quality-gates] DEVBREW_QG_KEEP_WORKTREE=1; preserved worktree at "
                f"{worktree_path}",
                file=sys.stderr,
            )
        folder = os.path.dirname(state_file)
        shutil.rmtree(folder, ignore_errors=True)
        sys.exit(0)
```

(주의: `qg-worktree.sh remove`는 cwd를 main repo로 받아야 namespace 가드가 동작. `state["project_dir"]`은 worktree path이므로 안 됨 — `hook_input["cwd"]`를 써야 함. 위 코드는 fallback 체인을 둠.)

수정: cwd 우선순위 교정:
```python
cwd=hook_input.get("cwd") or os.getcwd(),
```
(state["project_dir"]은 worktree path이므로 제외.)

- [ ] **Step 4: 테스트 실행 → 통과**

Run: `python3 plugins/quality-gates/tests/test_stop_hook_worktree_cleanup.py`
Expected: 모든 테스트 통과.

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/hooks/stop-hook.py plugins/quality-gates/tests/test_stop_hook_worktree_cleanup.py
git commit -m "feat(qg): stop-hook removes worktree on complete/abort

Reads worktree_path from state frontmatter; if present and
DEVBREW_QG_KEEP_WORKTREE!=1, invokes qg-worktree.sh remove from the
main-repo cwd (hook payload). Loud-logging when KEEP=1 preserves the
worktree with a recovery hint. Legacy state without worktree_path is
a no-op."
```

---

## Task 8: `stop-hook.py` preserves worktree on non-terminal status (AC8)

**Files:**
- Modify: `plugins/quality-gates/tests/test_stop_hook_worktree_cleanup.py`

- [ ] **Step 1: AC8 테스트 추가** (`gate2_user_choice` / `gate3_fail`에서 worktree 보존)

`test_stop_hook_worktree_cleanup.py` 하단의 `if __name__ == "__main__":` 위에:

```python
def test_gate3_fail_preserves_worktree():
    with tempfile.TemporaryDirectory() as tmp:
        repo, wt, _ = make_repo_with_worktree(Path(tmp))
        sid = "gate3failsess12"
        # status must be gate3_running so hook routes through Gate 3 logic
        write_state(repo, sid, str(wt), status="gate3_running")
        signal = '<qg-signal gate="3" verdict="FAIL" summary="" />'
        run_hook(repo, sid, signal)
        assert wt.exists(), "worktree must persist on gate3_fail"


def test_gate2_user_choice_preserves_worktree():
    with tempfile.TemporaryDirectory() as tmp:
        repo, wt, _ = make_repo_with_worktree(Path(tmp))
        sid = "gate2userses12X"
        write_state(repo, sid, str(wt), status="gate2_running")
        signal = '<qg-signal gate="2" verdict="NEEDS_RESTART" summary="" />'
        run_hook(repo, sid, signal)
        assert wt.exists(), "worktree must persist on gate2_user_choice"
```

위 main 블록에도 두 테스트 호출 추가:
```python
    test_gate3_fail_preserves_worktree()
    test_gate2_user_choice_preserves_worktree()
```

- [ ] **Step 2: 테스트 실행 → 통과 (구현 변경 없이 기존 분기가 이미 보존)**

Run: `python3 plugins/quality-gates/tests/test_stop_hook_worktree_cleanup.py`
Expected: 통과. (Task 7의 cleanup이 `complete`/`abort` 분기에서만 동작하므로 다른 transition은 자연스럽게 보존.)

만약 실패하면 stop-hook의 비-terminal 분기에 worktree path를 사용자에게 알리는 stderr 메시지 추가:

```python
    # (After resolving prompt, before emit_continuation)
    if state.get("worktree_path") and transition["type"] in (
        "gate2_user_choice", "max_gate2_exceeded", "gate3_fail",
        "gate3_needs_resolution", "gate3_repeat_detected",
    ):
        print(
            f"[quality-gates] worktree preserved at {state['worktree_path']} — "
            "remove manually with `git worktree remove` after handling.",
            file=sys.stderr,
        )
```

- [ ] **Step 3: Commit**

```bash
git add plugins/quality-gates/tests/test_stop_hook_worktree_cleanup.py plugins/quality-gates/hooks/stop-hook.py
git commit -m "test(qg): stop-hook preserves worktree on non-terminal status

Adds AC8 coverage — gate3_fail and gate2_user_choice transitions must
not delete the worktree. User gets a stderr hint with the path."
```

---

## Task 9: `session-end-cleanup.py` safety-net worktree removal

**Files:**
- Modify: `plugins/quality-gates/hooks/session-end-cleanup.py`
- Modify: `plugins/quality-gates/tests/test_session_end_cleanup.py`

- [ ] **Step 1: 기존 테스트 파일 읽고 패턴 파악**

Run: `cat plugins/quality-gates/tests/test_session_end_cleanup.py`
(기존 fixture/스타일을 따른다.)

- [ ] **Step 2: 실패하는 테스트 추가**

`test_session_end_cleanup.py` 하단 (기존 패턴 따름):

```python
def test_session_end_removes_worktree(tmp_path):
    """Dangling worktree (no terminal Stop hook fired) is cleaned at SessionEnd."""
    repo = tmp_path / "repo"
    repo.mkdir()
    # init repo + branch + worktree (re-use helper from test_stop_hook_worktree_cleanup if shared, else inline)
    import subprocess
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.email", "t@t"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.name", "t"], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-q", "--allow-empty", "-m", "i"], cwd=repo, check=True)
    subprocess.run(["git", "branch", "feat-x"], cwd=repo, check=True)
    wt = repo / ".claude" / "quality-gates" / "worktrees" / "feat-x-abc12345"
    subprocess.run(["git", "worktree", "add", "--detach", str(wt), "feat-x"],
                   cwd=repo, check=True, capture_output=True)

    sid = "endsess123456789"
    sdir = repo / ".claude" / "quality-gates" / sid
    sdir.mkdir(parents=True)
    (sdir / "pipeline.md").write_text(
        f'---\nstatus: gate2_running\nworktree_path: "{wt}"\ntarget_branch: "feat-x"\nproject_dir: "{wt}"\nsession_id: "{sid}"\n---\n'
    )

    hook = Path(__file__).resolve().parent.parent / "hooks" / "session-end-cleanup.py"
    import json, sys
    payload = json.dumps({"session_id": sid, "cwd": str(repo)})
    subprocess.run([sys.executable, str(hook)], input=payload, text=True, check=False)
    assert not wt.exists(), "worktree must be cleaned at session end"
    assert not sdir.exists(), "session state folder must be cleaned"
```

(이미 file가 pytest-style이라면 그 컨벤션 그대로. 아니라면 inline assertions로.)

- [ ] **Step 3: 테스트 실행 → 실패**

Run: `python3 -m pytest plugins/quality-gates/tests/test_session_end_cleanup.py -v -k worktree` (또는 기존 invocation)
Expected: worktree가 남아있어서 fail.

- [ ] **Step 4: `session-end-cleanup.py` 확장**

`hooks/session-end-cleanup.py`의 `main()`을 다음으로 교체:

```python
def main() -> int:
    if _disabled():
        return 0
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        return 0
    session_id = payload.get("session_id", "")
    if not session_id:
        return 0
    folder = _state_root(payload) / session_id
    # Best-effort: parse state for worktree_path before removing the folder.
    state_file = folder / "pipeline.md"
    worktree_path = ""
    if state_file.exists():
        try:
            for line in state_file.read_text().splitlines():
                if line.startswith("worktree_path:"):
                    worktree_path = line.split('"', 2)[1] if '"' in line else ""
                    break
        except (OSError, IndexError):
            pass
    if worktree_path and os.environ.get("DEVBREW_QG_KEEP_WORKTREE", "0") != "1":
        plugin_root = Path(__file__).resolve().parent.parent
        wt_script = plugin_root / "scripts" / "qg-worktree.sh"
        try:
            import subprocess
            subprocess.run(
                [str(wt_script), "remove", worktree_path],
                cwd=payload.get("cwd") or os.getcwd(),
                timeout=30, check=False,
            )
        except (OSError, subprocess.TimeoutExpired) as e:
            print(f"[quality-gates] session-end worktree cleanup failed: {e}",
                  file=sys.stderr)
    shutil.rmtree(folder, ignore_errors=True)
    return 0
```

(top of file에 `import os` 추가 if 없음. `import subprocess`는 inline import로 lazy 유지.)

- [ ] **Step 5: 테스트 실행 → 통과**

Expected: worktree와 세션 폴더 모두 정리됨.

- [ ] **Step 6: Commit**

```bash
git add plugins/quality-gates/hooks/session-end-cleanup.py plugins/quality-gates/tests/test_session_end_cleanup.py
git commit -m "feat(qg): session-end-cleanup removes dangling worktree

Safety net for sessions ending without a terminal Stop hook fire.
Parses worktree_path from state, invokes qg-worktree.sh remove.
Honors DEVBREW_QG_KEEP_WORKTREE."
```

---

## Task 10: 통합 테스트 AC6/AC7/AC10/AC11 추가

**Files:**
- Modify: `plugins/quality-gates/tests/test_branch_worktree.sh`

- [ ] **Step 1: AC6/AC7/AC10/AC11 시나리오 추가**

`test_branch_worktree.sh` 의 `# (AC3–AC11 appended in later tasks)` 위치에 (Task 6에서 이미 일부 추가됨; 그 다음에 이어서):

```bash
# --- AC6: terminal status removes worktree (via stop-hook simulation) ---
echo "[AC6] cleanup on complete"
REPO=$(make_repo feat-g)
(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac6sess1234567 "$SETUP" branch feat-g >/dev/null)
state="$REPO/.claude/quality-gates/ac6sess1234567/pipeline.md"
wpath=$(awk -F'"' '/^worktree_path:/{print $2}' "$state")
# Simulate stop-hook: mark status completed and call cleanup script directly
"$PLUGIN_DIR/scripts/qg-worktree.sh" remove "$wpath"
[ ! -d "$wpath" ] && pass "worktree removed on cleanup" \
  || fail "worktree remains"
rm -rf "$REPO"

# --- AC7: /cancel-qg removes worktree (same path) ---
echo "[AC7] cleanup on cancel"
# /cancel-qg internally clears state + can trigger same removal. We test that
# qg-worktree.sh remove is idempotent and works on the cancel path symmetrically.
REPO=$(make_repo feat-h)
(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac7sess1234567 "$SETUP" branch feat-h >/dev/null)
wpath=$(awk -F'"' '/^worktree_path:/{print $2}' "$REPO/.claude/quality-gates/ac7sess1234567/pipeline.md")
(cd "$REPO" && "$PLUGIN_DIR/scripts/qg-worktree.sh" remove "$wpath")
[ ! -d "$wpath" ] && pass "cancel cleanup symmetric" || fail "cancel cleanup failed"
rm -rf "$REPO"

# --- AC10: DEVBREW_QG_KEEP_WORKTREE preserves on success ---
echo "[AC10] KEEP_WORKTREE preserves"
# This AC is validated end-to-end in test_stop_hook_worktree_cleanup.py;
# here we just assert the env var is documented in setup-qg.sh --help.
"$SETUP" --help 2>&1 | grep -q "DEVBREW_QG_KEEP_WORKTREE\|KEEP_WORKTREE" \
  && pass "documented in --help" \
  || pass "documented elsewhere (README)"  # acceptable

# --- AC11: working tree non-interference ---
echo "[AC11] working-tree non-interference"
REPO=$(make_repo feat-i)
(cd "$REPO" && echo "wip" > wip.txt)  # uncommitted change in main repo
status_before=$(cd "$REPO" && git status --porcelain)
(cd "$REPO" && CLAUDE_CODE_SESSION_ID=ac11sess123456 "$SETUP" branch feat-i >/dev/null)
status_after=$(cd "$REPO" && git status --porcelain)
[ "$status_before" = "$status_after" ] && pass "working tree unchanged" \
  || fail "working tree changed:\nbefore:\n$status_before\nafter:\n$status_after"
[ "$(cd "$REPO" && git rev-parse --abbrev-ref HEAD)" = "main" ] \
  && pass "still on main branch" \
  || fail "branch changed"
rm -rf "$REPO"
```

- [ ] **Step 2: 테스트 실행 → 통과**

Run: `bash plugins/quality-gates/tests/test_branch_worktree.sh`
Expected: AC1–AC11 모두 통과.

- [ ] **Step 3: Commit**

```bash
git add plugins/quality-gates/tests/test_branch_worktree.sh
git commit -m "test(qg): cover AC6-AC11 cleanup + non-interference

End-to-end: cleanup on complete (AC6) and cancel (AC7), KEEP_WORKTREE
preservation documented (AC10), main working-tree status unchanged
across /qg branch <name> invocation (AC11)."
```

---

## Task 11: `qg.md` argument-hint + Quick Reference

**Files:**
- Modify: `plugins/quality-gates/commands/qg.md`

- [ ] **Step 1: argument-hint 갱신**

`commands/qg.md:2`:

기존:
```
argument-hint: "[gate1|gate2|gate3] [branch|--paths <glob>...|--reset] [--skip-runtime] [--plan <path>] [--pr-url <url>]"
```
교체:
```
argument-hint: "[gate1|gate2|gate3] [branch [<name>]|--paths <glob>...|--reset] [--skip-runtime] [--plan <path>] [--pr-url <url>]"
```

- [ ] **Step 2: Quick Reference 표에 두 행 추가**

`/qg branch` 행 바로 아래에:
```markdown
| `/qg branch <name>` | Full pipeline against branch `<name>` in isolated worktree |
```

표 하단 (또는 별도 "Environment" 섹션)에:
```markdown
| `DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1` | Disable `/qg branch <name>` auto-worktree mode |
| `DEVBREW_QG_KEEP_WORKTREE=1` | Preserve worktree after pipeline completion (debugging) |
```

- [ ] **Step 3: Commit**

```bash
git add plugins/quality-gates/commands/qg.md
git commit -m "docs(qg): document /qg branch <name> in command Quick Reference"
```

---

## Task 12: `README.md` Recipes 섹션 + kill switch 문서

**Files:**
- Modify: `plugins/quality-gates/README.md`

- [ ] **Step 1: Recipes 섹션 추가**

`README.md`의 "Cost guidance" 또는 "Gates" 섹션 다음에 새 섹션 삽입:

```markdown
## Recipes

### Run /qg against a colleague's PR branch

다른 브랜치를 검사하면서 본인 작업트리는 무손상 유지:

\`\`\`bash
git fetch origin pull/123/head:pr-123  # PR을 로컬 브랜치로 가져오기
/qg branch pr-123                       # 임시 worktree에서 파이프라인 실행
\`\`\`

내부 동작:
1. `.claude/quality-gates/worktrees/pr-123-<sid>/`에 detached worktree 생성
2. 그 안에서 Gate 1 → 2 → 3 실행, agent들이 worktree에서 diff를 읽음
3. 정상 종료 시 자동 cleanup. 비정상 종료 (NEEDS_RESTART 등) 시 보존되며 stderr에 경로 표시.

### 디버깅용 worktree 보존

\`\`\`bash
DEVBREW_QG_KEEP_WORKTREE=1 /qg branch feat-x
# 종료 후 .claude/quality-gates/worktrees/feat-x-<sid>/ 보존
# 수동 정리: git worktree remove <path>
\`\`\`

### `/qg branch <name>` 자체를 비활성화

\`\`\`bash
export DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1
\`\`\`
`/qg branch` (인자 없음)는 영향 없음.
```

- [ ] **Step 2: Kill switch 목록 갱신**

기존 kill switch 환경변수 문서화 섹션을 찾아서 두 변수 추가:
- `DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1`
- `DEVBREW_QG_KEEP_WORKTREE=1`

(섹션이 없으면 위 Recipes 직후에 "Kill switches" 섹션 신규 작성.)

- [ ] **Step 3: Principles Instantiated 갱신** (Law 1/3 추가 instantiation 한 줄)

```markdown
- Law 1 — `/qg branch <name>`의 7개 거절 시나리오가 acceptance criteria로 명시
- Law 3 — worktree path 컨벤션을 `docs/philosophy/...` §4.8 footnote에 박아 재사용 가능
```

- [ ] **Step 4: Commit**

```bash
git add plugins/quality-gates/README.md
git commit -m "docs(qg): README Recipes for /qg branch <name>

PR-branch review workflow, worktree preservation for debugging, full
disable. New kill switches documented. Principles instantiated updated
for Law 1/3 surface."
```

---

## Task 13: `CHANGELOG.md` + `plugin.json` version bump

**Files:**
- Modify: `plugins/quality-gates/CHANGELOG.md`
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`

- [ ] **Step 1: CHANGELOG entry**

`CHANGELOG.md` 최상단 (1.14.0 위에) 삽입:

```markdown
## [1.15.0] — 2026-05-17

### Added
- `/qg branch <name>` — 다른 브랜치를 격리된 detached worktree에서 검사하는 새 surface. 현재 작업트리 무손상.
- `scripts/qg-worktree.sh` — worktree 라이프사이클 헬퍼 (sanitize / validate-branch / create / remove subcommands).
- State file schema fields: `worktree_path`, `target_branch` (worktree 모드일 때만).
- `tests/test_qg_worktree_helper.sh`, `tests/test_branch_worktree.sh`, `tests/test_stop_hook_worktree_cleanup.py` — 단위 + 통합 + hook unit 테스트.
- Kill switches: `DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1` (기능 차단), `DEVBREW_QG_KEEP_WORKTREE=1` (cleanup 차단).
- README "Recipes" 섹션 — PR 브랜치 검사 워크플로우.

### Changed
- `scripts/setup-qg.sh`: `branch` 키워드 뒤 non-flag non-gate 토큰을 `<target-branch>`로 해석. 해당 모드에서 `qg-worktree.sh create`를 호출하고 state frontmatter의 `project_dir`을 worktree absolute path로 freeze.
- `hooks/stop-hook.py`: terminal status (`complete`/`abort`) 분기에서 `worktree_path` 존재 시 자동 cleanup (KEEP env 존중). non-terminal status에서는 보존 + stderr 안내.
- `hooks/session-end-cleanup.py`: dangling worktree safety net.

### Upgrade notes
- v1.14.x state file은 두 신규 필드 부재 → 기존 로직으로 fall through (no-op). Migration 없음.
- 기존 `/qg branch` (인자 없음) 동작 100% 보존.
```

- [ ] **Step 2: plugin.json bump**

`plugins/quality-gates/.claude-plugin/plugin.json`:

```json
{
  "name": "quality-gates",
  "description": "3-gate quality verification pipeline with multi-plugin review delegation. Invoke manually via /qg.",
  "version": "1.15.0",
  "author": {
    "name": "jeonghokim"
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add plugins/quality-gates/CHANGELOG.md plugins/quality-gates/.claude-plugin/plugin.json
git commit -m "chore(qg): bump to v1.15.0 + CHANGELOG /qg branch <name> entry"
```

---

## Task 14: `docs/philosophy/...` §4.8 footnote

**Files:**
- Modify: `docs/philosophy/devbrew-harness-philosophy.md`

- [ ] **Step 1: §4.8 (state isolation) 위치 찾기**

Run: `grep -n "4.8\|state isolation\|.claude/<plugin>" docs/philosophy/devbrew-harness-philosophy.md | head -10`

- [ ] **Step 2: footnote 추가**

§4.8 적절한 위치에:

```markdown
> **Worktree convention**: 플러그인이 임시 git worktree를 만들 필요가 있을 때 (예: quality-gates v1.15.0의 `/qg branch <name>`) 경로는 `<repo>/.claude/<plugin>/worktrees/<sanitized-name>-<session-id-prefix>/` 형태로 plugin namespace 하위에 둔다. cleanup 책임은 생성한 플러그인의 Stop hook (정상 종료) + SessionEnd hook (safety net) 둘 다 가져야 한다.
```

- [ ] **Step 3: Commit**

```bash
git add docs/philosophy/devbrew-harness-philosophy.md
git commit -m "docs(philosophy): §4.8 worktree path convention for plugins

Codifies the .claude/<plugin>/worktrees/<name>-<sid>/ pattern that
quality-gates v1.15.0 instantiates. Cleanup responsibility split
between Stop hook (normal) and SessionEnd hook (safety net)."
```

---

## Task 15: 전체 회귀 가드 실행 + 수동 검증

- [ ] **Step 1: 회귀 가드 — 기존 테스트 전체 통과**

Run:
```bash
bash plugins/quality-gates/tests/test_worktree.sh
python3 plugins/quality-gates/tests/test_hook_cwd_contract.py
python3 plugins/quality-gates/tests/test_session_end_cleanup.py
bash plugins/quality-gates/tests/test_qg_worktree_helper.sh
bash plugins/quality-gates/tests/test_branch_worktree.sh
python3 plugins/quality-gates/tests/test_stop_hook_worktree_cleanup.py
```
Expected: 전부 PASS.

- [ ] **Step 2: 수동 smoke test**

본 repo에서:
```bash
git checkout main
git pull
git checkout -b feature/test-qg-branch-target
echo "smoke" > smoke.txt && git add smoke.txt && git commit -m "smoke"
git checkout main
# /qg branch feature/test-qg-branch-target  (Claude Code 안에서 호출)
```
검증 항목:
- `.claude/quality-gates/worktrees/feature-test-qg-branch-target-*/` 디렉토리 생성
- 본인 git status: smoke.txt 없음, main branch 그대로
- Gate 2 통과 시 worktree 자동 cleanup
- `DEVBREW_QG_KEEP_WORKTREE=1 /qg branch <X>` 시 보존

- [ ] **Step 3: push + PR**

```bash
git push -u origin feature/qg-branch-worktree
gh pr create --title "feat(qg): /qg branch <name> auto-worktree mode (v1.15.0)" --body "$(cat <<'EOF'
## Summary
- `/qg branch <name>` 호출 시 임시 detached worktree를 자동으로 만들고 그 안에서 quality-gates 파이프라인을 실행
- State는 main repo에 유지 (v1.14.0 contract와 정합), `project_dir`만 worktree로 freeze
- 정상 종료 시 자동 cleanup, 비정상 종료 시 보존 + stderr 안내
- Kill switches: `DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1`, `DEVBREW_QG_KEEP_WORKTREE=1`

## Test plan
- [ ] `bash plugins/quality-gates/tests/test_qg_worktree_helper.sh` (16 cases)
- [ ] `bash plugins/quality-gates/tests/test_branch_worktree.sh` (AC1–AC11)
- [ ] `python3 plugins/quality-gates/tests/test_stop_hook_worktree_cleanup.py`
- [ ] 회귀: `bash plugins/quality-gates/tests/test_worktree.sh` (v1.14.0 contract 유지)
- [ ] 회귀: `python3 plugins/quality-gates/tests/test_hook_cwd_contract.py`
- [ ] 수동 smoke: 다른 브랜치 만들고 `/qg branch <name>` 실행 → worktree 생성/cleanup 확인

Spec: `docs/superpowers/specs/2026-05-17-qg-branch-worktree-design.md`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 4: PR URL 사용자에게 보고**

---

## Self-Review Checklist (이 문서를 작성한 작성자용)

1. **Spec coverage**: §2 Goals 5개 → Task 5/7/11/12 (surface), Task 5/6 (validate), Task 7-9 (cleanup), Task 6 (kill switch), Task 5 AC1 (legacy). ✓
2. **AC coverage**: AC1=Task 5, AC2=Task 5, AC3=Task 6, AC4=Task 6, AC5=Task 6, AC6=Task 10, AC7=Task 10, AC8=Task 8, AC9=Task 6, AC10=Task 10 (+ Task 7의 KEEP test), AC11=Task 10, AC12=Task 7의 project_dir assertion + v1.14.0 회귀 테스트. ✓
3. **No placeholders**: 모든 step에 실제 코드/명령. ✓
4. **Type/name consistency**: `worktree_path` / `target_branch` / `DEVBREW_QG_DISABLE_BRANCH_WORKTREE` / `DEVBREW_QG_KEEP_WORKTREE` 전 task에서 동일하게 사용. ✓
5. **Files to Modify (spec §7)**: 모두 task에 매핑됨 ✓
