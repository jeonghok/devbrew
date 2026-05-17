# spec-distill Design-Mode Trigger Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-distill 플러그인 v0.4.0 — 4-layer trigger chain redundancy(L1/L4a/L4b/L5) + worktree-aware state path 단일화로, brainstorming flow가 산출한 `-design.md`를 spec-reviewer agent가 silent-miss 없이 review하도록 한다.

**Architecture:** State path 해석을 `hooks/state_path.py` 단일 helper로 중앙화 (git rev-parse --git-common-dir 기반 main repo root 해석). PostToolUse 훅이 design.md를 감지해 `pending_review:` block을 main repo의 `.claude/spec-distill/<session-id>/state.local.md`에 기록(worktree_path 포함). Stop 훅이 turn boundary에서 mandate systemMessage emit(terminal handoff 보류 + worktree_path 포함). 신규 UserPromptSubmit reminder 훅이 매 next-turn에 TTL(30s) 가드 후 mandate 재emit으로 redundancy. reviewing-spec skill의 routing table에 design rows 3개 추가, spec-reviewer agent에 design checklist 분기 섹션 추가. 모든 hook은 graceful degradation + kill switch 존중.

**Tech Stack:** Python 3 (standard library only — `pathlib`, `subprocess`, `json`, `re`, `os`, `sys`, `datetime`). Bash test 러너 (.sh, mktemp 격리). 외부 PyPI 의존성 없음.

**Spec:** [`docs/superpowers/specs/2026-05-17-spec-distill-design-mode-trigger-design.md`](../specs/2026-05-17-spec-distill-design-mode-trigger-design.md) (v1.0.0, approved by spec-reviewer round 2).

---

## File Structure

신규 (4 코드 + 2 fixture + 8 test = 14):
- `plugins/spec-distill/hooks/state_path.py` — state root 해석 helper (`state_root(cwd)` + `cleanup_stale_states(state_root_path)`). git rev-parse --git-common-dir → main repo root. cwd fallback + loud stderr log.
- `plugins/spec-distill/hooks/pending-review-reminder.py` — UserPromptSubmit hook entry. TTL(30s) 가드. pending_review가 살아있고 last_dispatched_at > TTL이면 mandate 재emit.
- `plugins/spec-distill/tests/fixtures/2026-05-17-test-design.md` — valid design.md fixture (placeholder/ambiguity 없음).
- `plugins/spec-distill/tests/fixtures/2026-05-17-test-design-bad.md` — placeholder + ambiguity hit fixture.
- `plugins/spec-distill/tests/test_state_path.sh` — state_path helper unit test (worktree → main repo + git fallback + cleanup).
- `plugins/spec-distill/tests/test_design_mode_validator.sh` — PostToolUse hook design mode + worktree state path + worktree_path 필드.
- `plugins/spec-distill/tests/test_review_dispatch_design_mandate.sh` — Stop hook mandate 본문 검증.
- `plugins/spec-distill/tests/test_reminder_hook.sh` — UserPromptSubmit reminder TTL skip / re-emit / kill switch.
- `plugins/spec-distill/tests/test_reviewing_spec_design_routing.sh` — reviewing-spec SKILL.md design rows + mode 분기 텍스트 검증.
- `plugins/spec-distill/tests/test_spec_reviewer_design_checklist.sh` — agents/spec-reviewer.md design checklist 섹션 + 카테고리 출현 fixture-기반 dry-run.
- `plugins/spec-distill/tests/test_state_cleanup.sh` — 24h pending purge + 7일 파일 auto-delete.

수정 (8):
- `plugins/spec-distill/hooks/spec-write-validator.py` — state_path helper 도입, pending_review block에 `worktree_path:` 필드 추가. C5 본문 변경 최소화 원칙.
- `plugins/spec-distill/hooks/review-dispatch.py` — state_path helper 도입, mandate systemMessage 본문에 "타 terminal handoff(writing-plans 등) 보류" + worktree_path 포함, stale state cleanup 호출.
- `plugins/spec-distill/hooks/hooks.json` — UserPromptSubmit 이벤트에 reminder 등록 (기존 interview-trigger.sh 옆 hooks 배열).
- `plugins/spec-distill/skills/reviewing-spec/SKILL.md` — Step 1에 `mode` 분기 명시, Routing Table에 design rows 3개 추가, "drafting-spec 미호출" 명시.
- `plugins/spec-distill/agents/spec-reviewer.md` — design mode checklist 분기 섹션 추가 (placeholder / ambiguity / scope-creep / approaches-comparison / isolation / testing 6 카테고리). spec mode 본문 무손상.
- `plugins/spec-distill/.claude-plugin/plugin.json` — version `0.3.0` → `0.4.0`.
- `plugins/spec-distill/CHANGELOG.md` — `## [0.4.0] — 2026-05-17` 섹션 (Added / Changed / Security).
- `plugins/spec-distill/README.md` — "Hooks Installed"에 UserPromptSubmit reminder 행 추가 + 한 줄 justification. "Principles Instantiated"에 G6 (worktree-aware state path, §4.8 instantiation) 한 줄.

---

## Task 1: Test fixtures 작성

**Files:**
- Create: `plugins/spec-distill/tests/fixtures/2026-05-17-test-design.md`
- Create: `plugins/spec-distill/tests/fixtures/2026-05-17-test-design-bad.md`

설명: 후속 모든 hook 테스트가 이 두 fixture를 입력으로 사용. Valid fixture는 hook이 pass해야 하고, bad fixture는 placeholder + ambiguity 둘 다 hit.

- [ ] **Step 1: Write valid design fixture**

Create `plugins/spec-distill/tests/fixtures/2026-05-17-test-design.md`:

```markdown
# Test Design Fixture

This is a deliberate fixture for spec-distill v0.4.0 hook tests. The file ends with `-design.md` to exercise design-mode validation.

## Goal

Exercise design-mode placeholder and ambiguity scan paths.

## Components

- A: clear purpose, well-bounded interface.
- B: clear purpose, well-bounded interface.

## Testing

Manual fixture used by `test_design_mode_validator.sh` and `test_review_dispatch_design_mandate.sh`.
```

- [ ] **Step 2: Write bad design fixture (placeholder + ambiguity)**

Create `plugins/spec-distill/tests/fixtures/2026-05-17-test-design-bad.md`:

```markdown
# Bad Design Fixture

## Goal

TODO: fill in goal.

## Components

The system must be robust and works correctly under load.
```

Line 5 has `TODO:` (placeholder hit), line 9 has `robust` + `works correctly` (two ambiguity hits).

- [ ] **Step 3: Commit fixtures**

```bash
git add plugins/spec-distill/tests/fixtures/2026-05-17-test-design.md \
        plugins/spec-distill/tests/fixtures/2026-05-17-test-design-bad.md
git commit -m "test(spec-distill): add v0.4.0 design.md fixtures (valid + bad)"
```

---

## Task 2: state_path.py — state_root() helper (TDD)

**Files:**
- Create: `plugins/spec-distill/hooks/state_path.py`
- Create: `plugins/spec-distill/tests/test_state_path.sh`

설명: 모든 hook이 state 파일 위치를 일관되게 해석하도록 하는 단일 helper. `git rev-parse --git-common-dir`로 main repo의 `.git` 경로를 얻어 `dirname`으로 root 도출 → `<main_repo>/.claude/spec-distill/`. git 부재/실패 시 cwd-relative fallback + stderr loud log (AC11 / AC13).

- [ ] **Step 1: Write failing test**

Create `plugins/spec-distill/tests/test_state_path.sh`:

```bash
#!/usr/bin/env bash
# Tests for hooks/state_path.py — state_root() helper.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HELPER="$REPO_ROOT/plugins/spec-distill/hooks/state_path.py"
WORK=$(mktemp -d -t specdistill-statepath-XXXXXX)
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
note() {
  if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"
  else fail=$((fail+1)); echo "  ✗ $2"; fi
}

# Setup: a git repo with a worktree
cd "$WORK"
git init -q main-repo
cd main-repo
git config user.email t@t.t; git config user.name t
echo "x" > a.txt; git add a.txt; git commit -qm "init"
git worktree add -q ../wt-foo 2>/dev/null || git worktree add -q ../wt-foo HEAD

# Case 1: AC11 — called from worktree returns main repo root
got=$(cd "$WORK/wt-foo" && python3 "$HELPER" state-root)
want="$WORK/main-repo/.claude/spec-distill"
[[ "$got" == "$want" ]] \
  && note PASS "state-root from worktree → main repo .claude/spec-distill" \
  || note FAIL "got='$got' want='$want'"

# Case 2: AC11 — called from main repo returns main repo root
got=$(cd "$WORK/main-repo" && python3 "$HELPER" state-root)
want="$WORK/main-repo/.claude/spec-distill"
[[ "$got" == "$want" ]] \
  && note PASS "state-root from main repo → main repo .claude/spec-distill" \
  || note FAIL "got='$got' want='$want'"

# Case 3: AC13 — non-git directory → cwd fallback + loud stderr
mkdir -p "$WORK/non-git"
out=$(cd "$WORK/non-git" && python3 "$HELPER" state-root 2>&1 >/dev/null)
got=$(cd "$WORK/non-git" && python3 "$HELPER" state-root 2>/dev/null)
[[ "$got" == "$WORK/non-git/.claude/spec-distill" ]] \
  && echo "$out" | grep -q "state root fallback: cwd" \
  && note PASS "non-git → cwd fallback + loud stderr" \
  || note FAIL "got='$got' stderr='$out'"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

```bash
chmod +x plugins/spec-distill/tests/test_state_path.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash plugins/spec-distill/tests/test_state_path.sh`
Expected: FAIL with "No such file or directory" (state_path.py 미생성).

- [ ] **Step 3: Implement state_path.py minimal**

Create `plugins/spec-distill/hooks/state_path.py`:

```python
#!/usr/bin/env python3
"""spec-distill state path helper.

Resolves state root to <main_repo>/.claude/spec-distill regardless of cwd
(worktree-aware via `git rev-parse --git-common-dir`). Fallback: cwd-relative
with loud stderr log.

CLI:
  python3 state_path.py state-root [<cwd>]    → prints absolute path to stdout
  python3 state_path.py cleanup <state-root>  → purges stale state files
"""
from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path


PENDING_TTL_HOURS = 24
FILE_TTL_DAYS = 7


def state_root(cwd: str | None = None) -> Path:
    """Return <main_repo>/.claude/spec-distill. cwd fallback on git failure."""
    if cwd is None:
        cwd = os.getcwd()
    try:
        cp = subprocess.run(
            ["git", "rev-parse", "--git-common-dir"],
            cwd=cwd, capture_output=True, text=True, timeout=5, check=False,
        )
        if cp.returncode == 0:
            git_dir = Path(cp.stdout.strip())
            if not git_dir.is_absolute():
                git_dir = (Path(cwd) / git_dir).resolve()
            main_repo = git_dir.parent
            return main_repo / ".claude" / "spec-distill"
    except (subprocess.TimeoutExpired, OSError, FileNotFoundError):
        pass
    fallback = Path(cwd) / ".claude" / "spec-distill"
    print(
        f"[spec-distill] state root fallback: cwd ({cwd}) — main repo 미해석",
        file=sys.stderr,
    )
    return fallback


def cleanup_stale_states(root: Path) -> None:
    """Stub for Task 3."""
    return None


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: state_path.py {state-root|cleanup} [<arg>]", file=sys.stderr)
        return 2
    sub = argv[1]
    if sub == "state-root":
        cwd = argv[2] if len(argv) >= 3 else None
        print(str(state_root(cwd)))
        return 0
    if sub == "cleanup":
        if len(argv) < 3:
            print("usage: state_path.py cleanup <state-root>", file=sys.stderr)
            return 2
        cleanup_stale_states(Path(argv[2]))
        return 0
    print(f"unknown subcommand: {sub}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

- [ ] **Step 4: Run test to verify pass**

Run: `bash plugins/spec-distill/tests/test_state_path.sh`
Expected: PASS — 3 cases.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/hooks/state_path.py plugins/spec-distill/tests/test_state_path.sh
git commit -m "feat(spec-distill): state_path helper for worktree-aware state root"
```

---

## Task 3: state_path.py — cleanup_stale_states() (TDD)

**Files:**
- Modify: `plugins/spec-distill/hooks/state_path.py` (replace `cleanup_stale_states` stub)
- Create: `plugins/spec-distill/tests/test_state_cleanup.sh`

설명: C8/LD14 cleanup 정책 구현. pending_review block의 `triggered_at` > 24h → block 제거 + stderr 통보. last_dispatched_at만 있고 pending_review 없는 state 파일 → 7일 후 파일 단위 auto-delete.

- [ ] **Step 1: Write failing test**

Create `plugins/spec-distill/tests/test_state_cleanup.sh`:

```bash
#!/usr/bin/env bash
# Tests for cleanup_stale_states() — V9 of design v1.0.0.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HELPER="$REPO_ROOT/plugins/spec-distill/hooks/state_path.py"
WORK=$(mktemp -d -t specdistill-cleanup-XXXXXX)
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
note() {
  if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"
  else fail=$((fail+1)); echo "  ✗ $2"; fi
}

ROOT="$WORK/state"
mkdir -p "$ROOT/fresh" "$ROOT/stale-pending" "$ROOT/stale-file"
NOW=$(python3 -c 'from datetime import datetime,timezone; print(datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))')
T_25H=$(python3 -c 'from datetime import datetime,timezone,timedelta; print((datetime.now(timezone.utc)-timedelta(hours=25)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
T_8D=$(python3 -c 'from datetime import datetime,timezone,timedelta; print((datetime.now(timezone.utc)-timedelta(days=8)).strftime("%Y-%m-%dT%H:%M:%SZ"))')

# fresh — should be untouched
cat > "$ROOT/fresh/state.local.md" <<EOF
---
session_id: fresh
---

pending_review:
  path: /tmp/x.md
  mode: design
  triggered_at: $NOW
EOF

# stale-pending — 25h old pending_review → block purged, file kept
cat > "$ROOT/stale-pending/state.local.md" <<EOF
---
session_id: stale-pending
---

pending_review:
  path: /tmp/y.md
  mode: design
  triggered_at: $T_25H
EOF

# stale-file — only last_dispatched_at, 8d old → file deleted
cat > "$ROOT/stale-file/state.local.md" <<EOF
---
session_id: stale-file
---
last_dispatched_at: $T_8D
EOF

python3 "$HELPER" cleanup "$ROOT" 2>/dev/null

# Case 1: fresh untouched
grep -q '^pending_review:' "$ROOT/fresh/state.local.md" \
  && note PASS "fresh pending_review preserved" \
  || note FAIL "fresh pending_review was purged"

# Case 2: stale-pending block purged but file kept
[[ -f "$ROOT/stale-pending/state.local.md" ]] \
  && ! grep -q '^pending_review:' "$ROOT/stale-pending/state.local.md" \
  && note PASS "stale pending_review purged, file kept" \
  || note FAIL "stale-pending not handled correctly"

# Case 3: stale-file deleted
[[ ! -f "$ROOT/stale-file/state.local.md" ]] \
  && note PASS "stale file (>7d, no pending_review) deleted" \
  || note FAIL "stale file not deleted"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

```bash
chmod +x plugins/spec-distill/tests/test_state_cleanup.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash plugins/spec-distill/tests/test_state_cleanup.sh`
Expected: FAIL — cleanup is a stub returning None.

- [ ] **Step 3: Implement cleanup_stale_states**

Replace the stub in `plugins/spec-distill/hooks/state_path.py`:

```python
def _parse_iso(s: str):
    s = s.strip()
    try:
        return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def cleanup_stale_states(root: Path) -> None:
    """Purge stale pending_review blocks (>24h) and old state files (>7d).

    - pending_review with triggered_at > 24h ago → strip block, keep file.
    - state file with no pending_review and last_dispatched_at > 7d → delete file.
    """
    if not root.exists():
        return
    now = datetime.now(timezone.utc)
    pending_cutoff = now - timedelta(hours=PENDING_TTL_HOURS)
    file_cutoff = now - timedelta(days=FILE_TTL_DAYS)
    for session_dir in root.iterdir():
        if not session_dir.is_dir():
            continue
        state_file = session_dir / "state.local.md"
        if not state_file.exists():
            continue
        try:
            body = state_file.read_text(encoding="utf-8")
        except OSError:
            continue
        # Purge stale pending_review
        import re
        m = re.search(
            r"^pending_review:\n  path:[^\n]+\n  mode:[^\n]+\n  triggered_at:\s*([^\n]+)\n(?:  [^\n]*\n)*",
            body, flags=re.MULTILINE,
        )
        if m:
            ts = _parse_iso(m.group(1))
            if ts and ts < pending_cutoff:
                body = re.sub(
                    r"^pending_review:\n(?:  [^\n]*\n)*", "", body, flags=re.MULTILINE,
                )
                try:
                    state_file.write_text(body, encoding="utf-8")
                    print(
                        f"[spec-distill] state cleanup: purged stale pending_review in {state_file}",
                        file=sys.stderr,
                    )
                except OSError:
                    pass
        # File-level delete if only last_dispatched_at remains and is old
        if "pending_review:" not in body:
            ld = re.search(r"^last_dispatched_at:\s*(.+)$", body, flags=re.MULTILINE)
            if ld:
                ts = _parse_iso(ld.group(1))
                if ts and ts < file_cutoff:
                    try:
                        state_file.unlink()
                        try:
                            session_dir.rmdir()
                        except OSError:
                            pass
                        print(
                            f"[spec-distill] state cleanup: deleted stale state file {state_file}",
                            file=sys.stderr,
                        )
                    except OSError:
                        pass
```

- [ ] **Step 4: Run test to verify pass**

Run: `bash plugins/spec-distill/tests/test_state_cleanup.sh`
Expected: PASS — 3 cases.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/hooks/state_path.py plugins/spec-distill/tests/test_state_cleanup.sh
git commit -m "feat(spec-distill): state cleanup policy — 24h pending purge / 7d file delete"
```

---

## Task 4: spec-write-validator.py — state_path adoption + worktree_path (TDD)

**Files:**
- Modify: `plugins/spec-distill/hooks/spec-write-validator.py:78-99` (write_state) + `159-163` (state_root resolution)
- Create: `plugins/spec-distill/tests/test_design_mode_validator.sh`

설명: PostToolUse hook이 state를 worktree's `.claude/`가 아니라 main repo의 `.claude/spec-distill/`에 기록하도록 변경 (AC11). pending_review block에 `worktree_path:` 필드 추가 (AC12). C5에 따라 본문 변경 최소화.

- [ ] **Step 1: Write failing test**

Create `plugins/spec-distill/tests/test_design_mode_validator.sh`:

```bash
#!/usr/bin/env bash
# AC1/AC11/AC12 for PostToolUse hook design-mode + worktree state path.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/spec-distill/hooks/spec-write-validator.py"
FIX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"
WORK=$(mktemp -d -t specdistill-design-XXXXXX)
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# Build a main repo + worktree to exercise AC11
cd "$WORK"
git init -q main-repo
cd main-repo
git config user.email t@t.t; git config user.name t
echo seed > seed.txt; git add seed.txt; git commit -qm seed
mkdir -p docs/superpowers/specs
git worktree add -q ../wt-foo HEAD

# Helper: emit a hook payload + run hook from a given cwd
run_hook() {
  local cwd="$1" path="$2" extra_env="${3:-}"
  local payload
  payload=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$path")
  cd "$cwd" && env -i HOME="$HOME" PATH="$PATH" $extra_env bash -c \
    "echo '$payload' | python3 '$HOOK'" 2>&1
}

# Case 1: AC1 + AC11 — valid design.md write from worktree → state in MAIN repo only
DEST="$WORK/main-repo/docs/superpowers/specs/2026-05-17-test-design.md"
cp "$FIX/2026-05-17-test-design.md" "$DEST"
out=$(run_hook "$WORK/wt-foo" "$DEST" "DEVBREW_SPEC_DISTILL_SESSION_ID=case1")
rc=$?
MAIN_STATE="$WORK/main-repo/.claude/spec-distill/case1/state.local.md"
WT_STATE="$WORK/wt-foo/.claude/spec-distill/case1/state.local.md"
[[ $rc -eq 0 ]] && [[ -f "$MAIN_STATE" ]] && [[ ! -f "$WT_STATE" ]] \
  && grep -q '^pending_review:' "$MAIN_STATE" \
  && grep -q 'mode: design' "$MAIN_STATE" \
  && note PASS "AC1+AC11: design.md write from worktree → state in main repo only" \
  || note FAIL "AC1+AC11 failed (rc=$rc, main_exists=$([[ -f $MAIN_STATE ]] && echo y || echo n), wt_exists=$([[ -f $WT_STATE ]] && echo y || echo n))"

# Case 2: AC12 — pending_review block contains worktree_path
grep -q "^  worktree_path:.*wt-foo" "$MAIN_STATE" \
  && note PASS "AC12: pending_review block contains worktree_path field" \
  || note FAIL "AC12: worktree_path field missing (state: $(cat $MAIN_STATE 2>/dev/null))"

# Case 3: regression — spec-mode (existing v0.3.0) still writes state in main repo too
DEST2="$WORK/main-repo/docs/superpowers/specs/2026-05-17-test-spec.md"
# Generate a minimal valid spec for the spec-mode regression (re-use ac1 fixture if exists)
if [[ -f "$FIX/spec-valid.md" ]]; then
  cp "$FIX/spec-valid.md" "$DEST2"
  out=$(run_hook "$WORK/wt-foo" "$DEST2" "DEVBREW_SPEC_DISTILL_SESSION_ID=case3")
  rc=$?
  MAIN_STATE2="$WORK/main-repo/.claude/spec-distill/case3/state.local.md"
  [[ $rc -eq 0 ]] && [[ -f "$MAIN_STATE2" ]] \
    && grep -q 'mode: spec' "$MAIN_STATE2" \
    && note PASS "regression: spec-mode write also routes to main repo .claude" \
    || note FAIL "spec-mode regression failed (rc=$rc)"
else
  note PASS "regression skipped (spec-valid.md fixture absent)"
fi

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

```bash
chmod +x plugins/spec-distill/tests/test_design_mode_validator.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash plugins/spec-distill/tests/test_design_mode_validator.sh`
Expected: FAIL — state lands in worktree, no worktree_path field.

- [ ] **Step 3: Modify spec-write-validator.py — state_root + worktree_path**

In `plugins/spec-distill/hooks/spec-write-validator.py`:

(a) Replace the import block (after existing imports) to add state_path helper:

```python
sys.path.insert(0, str(SCRIPT_DIR))
from state_path import state_root as _state_root  # noqa: E402
```

(insert immediately after the `from typing import Optional` line and the `SCRIPT_DIR = Path(__file__).resolve().parent` declaration).

(b) Update `write_state` signature and body (replace existing function body at lines 78-99):

```python
def write_state(session_id: str, path: str, mode: str, worktree_path: str) -> None:
    state_dir = _state_root() / session_id
    state_dir.mkdir(parents=True, exist_ok=True)
    state_file = state_dir / "state.local.md"
    block = (
        "pending_review:\n"
        f"  path: {path}\n"
        f"  mode: {mode}\n"
        f"  worktree_path: {worktree_path}\n"
        f"  triggered_at: {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}\n"
    )
    if state_file.exists():
        body = state_file.read_text(encoding="utf-8")
        body = re.sub(
            r"^pending_review:\n(?:  [^\n]*\n)*", "", body, flags=re.MULTILINE
        )
        state_file.write_text(body.rstrip() + "\n\n" + block, encoding="utf-8")
    else:
        state_file.write_text(
            f"---\nsession_id: {session_id}\n---\n\n{block}", encoding="utf-8"
        )
```

(c) Update the call site (currently around line 161 inside `main()`):

```python
        try:
            write_state(session_id, file_path, mode, os.getcwd())
        except (PermissionError, OSError) as exc:
            print(f"[spec-distill] state write failed (non-fatal): {exc}", file=sys.stderr)
```

- [ ] **Step 4: Run test to verify pass**

Run: `bash plugins/spec-distill/tests/test_design_mode_validator.sh`
Expected: PASS — 3 cases (Case 3 may be "regression skipped" if fixture missing — acceptable).

- [ ] **Step 5: Regression — existing v0.3.0 tests still pass**

Run: `bash plugins/spec-distill/tests/test_spec_write_validator.sh`
Expected: all existing AC1–AC10 cases still PASS (state may now live in main repo, but tests are mktemp-rooted; the `cd "$WORK"` + git-less env triggers cwd fallback path which preserves existing behavior).

If existing tests fail because they assume state at `$WORK/.claude/...` but state now lands elsewhere: the cwd-fallback path of state_path.py keeps them at `$WORK/.claude/spec-distill/`. Verify by running and reading output.

- [ ] **Step 6: Commit**

```bash
git add plugins/spec-distill/hooks/spec-write-validator.py \
        plugins/spec-distill/tests/test_design_mode_validator.sh
git commit -m "feat(spec-distill): PostToolUse uses state_path helper + worktree_path field"
```

---

## Task 5: review-dispatch.py — state_path + mandate strengthening + worktree_path emit (TDD)

**Files:**
- Modify: `plugins/spec-distill/hooks/review-dispatch.py` (state path resolution + mandate body)
- Create: `plugins/spec-distill/tests/test_review_dispatch_design_mandate.sh`

설명: Stop hook이 state_path helper를 사용하고, mandate systemMessage 본문에 "타 terminal handoff(writing-plans 등) 보류" 문구 + worktree_path를 포함하도록 한다 (AC2, AC12). Stale cleanup도 매 fire마다 호출.

- [ ] **Step 1: Write failing test**

Create `plugins/spec-distill/tests/test_review_dispatch_design_mandate.sh`:

```bash
#!/usr/bin/env bash
# AC2 + AC12 for Stop hook review-dispatch.py — design-mode mandate body.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/spec-distill/hooks/review-dispatch.py"
WORK=$(mktemp -d -t specdistill-mandate-XXXXXX)
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# Build a main repo so state_path helper resolves to it
cd "$WORK"
git init -q main-repo
cd main-repo
git config user.email t@t.t; git config user.name t
echo s > s.txt; git add s.txt; git commit -qm s
SID=case-mandate
SDIR="$WORK/main-repo/.claude/spec-distill/$SID"
mkdir -p "$SDIR"
cat > "$SDIR/state.local.md" <<EOF
---
session_id: $SID
---

pending_review:
  path: /Users/foo/docs/superpowers/specs/2026-05-17-x-design.md
  mode: design
  worktree_path: /Users/foo/.claude/worktrees/test-wt
  triggered_at: 2026-05-17T00:00:00Z
EOF

out=$(cd "$WORK/main-repo" && env DEVBREW_SPEC_DISTILL_SESSION_ID="$SID" python3 "$HOOK" </dev/null 2>&1)
rc=$?

# Extract systemMessage from JSON stdout (stderr filtered out via line filter)
msg=$(printf '%s' "$out" | python3 -c 'import sys,json
for line in sys.stdin:
    line=line.strip()
    if not line: continue
    try:
        o=json.loads(line)
    except Exception: continue
    if "systemMessage" in o:
        print(o["systemMessage"]); break
')

# AC2 — both phrases present
echo "$msg" | grep -q "reviewing-spec" \
  && echo "$msg" | grep -q "terminal handoff" \
  && note PASS "AC2: mandate contains 'reviewing-spec' + 'terminal handoff' phrases" \
  || note FAIL "AC2 failed. msg='$msg'"

# AC12 — worktree_path included
echo "$msg" | grep -q "worktree_path: /Users/foo/.claude/worktrees/test-wt" \
  && note PASS "AC12: mandate carries worktree_path forward" \
  || note FAIL "AC12 failed. msg='$msg'"

# pending_review cleared after fire
[[ -f "$SDIR/state.local.md" ]] \
  && ! grep -q '^pending_review:' "$SDIR/state.local.md" \
  && grep -q '^last_dispatched_at:' "$SDIR/state.local.md" \
  && note PASS "state rewritten: pending_review cleared, last_dispatched_at set" \
  || note FAIL "state not rewritten cleanly"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

```bash
chmod +x plugins/spec-distill/tests/test_review_dispatch_design_mandate.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash plugins/spec-distill/tests/test_review_dispatch_design_mandate.sh`
Expected: FAIL — mandate body missing "terminal handoff" phrase + worktree_path.

- [ ] **Step 3: Modify review-dispatch.py**

In `plugins/spec-distill/hooks/review-dispatch.py`:

(a) Add state_path import after existing imports:

```python
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from state_path import state_root as _state_root, cleanup_stale_states  # noqa: E402
```

(b) Replace `state_file_for`:

```python
def state_file_for(session_id: str) -> Path:
    return _state_root() / session_id / "state.local.md"
```

(c) Extend `PENDING_RE` to capture optional worktree_path field (keep backward compat — field optional):

```python
PENDING_RE = re.compile(
    r"^pending_review:\n  path:\s*(?P<path>[^\n]+)\n  mode:\s*(?P<mode>[^\n]+)\n"
    r"(?:  worktree_path:\s*(?P<wt>[^\n]+)\n)?"
    r"  triggered_at:\s*(?P<triggered>[^\n]+)\n",
    re.MULTILINE,
)
```

(d) Replace mandate construction in `main()` (currently around `msg = (...)` lines 100-104):

```python
    spec_path = m.group("path").strip()
    mode = m.group("mode").strip()
    wt = (m.group("wt") or "").strip()
    msg_lines = [
        "MANDATORY: 다음 turn 첫 액션으로 reviewing-spec skill 호출.",
        f"spec path: {spec_path}.",
        f"mode: {mode}.",
    ]
    if wt:
        msg_lines.append(f"worktree_path: {wt}.")
    msg_lines.append(
        "호출 skill의 terminal handoff(writing-plans 등)는 review pass 이후로 보류."
    )
    msg = " ".join(msg_lines)
    print(json.dumps({"systemMessage": msg}), flush=True)
```

(e) Add cleanup call right after kill_switch check (top of main):

```python
    try:
        cleanup_stale_states(_state_root())
    except (OSError, PermissionError):
        pass
```

- [ ] **Step 4: Run test to verify pass**

Run: `bash plugins/spec-distill/tests/test_review_dispatch_design_mandate.sh`
Expected: PASS — 3 cases.

- [ ] **Step 5: Regression — existing review_dispatch test**

Run: `bash plugins/spec-distill/tests/test_review_dispatch.sh`
Expected: all existing cases PASS.

- [ ] **Step 6: Commit**

```bash
git add plugins/spec-distill/hooks/review-dispatch.py \
        plugins/spec-distill/tests/test_review_dispatch_design_mandate.sh
git commit -m "feat(spec-distill): Stop mandate strengthened — terminal handoff defer + worktree_path"
```

---

## Task 6: pending-review-reminder.py — UserPromptSubmit redundancy hook (TDD)

**Files:**
- Create: `plugins/spec-distill/hooks/pending-review-reminder.py`
- Create: `plugins/spec-distill/tests/test_reminder_hook.sh`

설명: AC3/AC4/AC8 — UserPromptSubmit hook이 매 turn에 state.local.md의 pending_review를 확인. last_dispatched_at TTL(30s) 안이면 skip. TTL 초과 시 mandate 재emit. Kill switch 존중.

- [ ] **Step 1: Write failing test**

Create `plugins/spec-distill/tests/test_reminder_hook.sh`:

```bash
#!/usr/bin/env bash
# AC3 / AC4 / AC8 for pending-review-reminder.py.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/spec-distill/hooks/pending-review-reminder.py"
WORK=$(mktemp -d -t specdistill-reminder-XXXXXX)
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

cd "$WORK"
git init -q main-repo
cd main-repo
git config user.email t@t.t; git config user.name t
echo s > s.txt; git add s.txt; git commit -qm s
SID=case-reminder
SDIR="$WORK/main-repo/.claude/spec-distill/$SID"
mkdir -p "$SDIR"

write_state() {
  local last_dispatched="$1"
  cat > "$SDIR/state.local.md" <<EOF
---
session_id: $SID
---

pending_review:
  path: /docs/superpowers/specs/x-design.md
  mode: design
  worktree_path: /Users/foo/.claude/worktrees/wt
  triggered_at: 2026-05-17T00:00:00Z

last_dispatched_at: $last_dispatched
EOF
}

run_hook() {
  local extra_env="${1:-}"
  cd "$WORK/main-repo" && env -i HOME="$HOME" PATH="$PATH" \
    DEVBREW_SPEC_DISTILL_SESSION_ID="$SID" $extra_env \
    bash -c "echo '{\"user_prompt\":\"hi\"}' | python3 '$HOOK'" 2>&1
}

# AC3: last_dispatched_at within TTL (now-10s) → silent skip
RECENT=$(python3 -c 'from datetime import datetime,timezone,timedelta; print((datetime.now(timezone.utc)-timedelta(seconds=10)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
write_state "$RECENT"
out=$(run_hook)
[[ -z "$out" || "$out" == "" ]] \
  && note PASS "AC3: reminder silent within TTL" \
  || note FAIL "AC3 unexpected output: '$out'"

# AC4: last_dispatched_at older than TTL (now-60s) → re-emit
OLD=$(python3 -c 'from datetime import datetime,timezone,timedelta; print((datetime.now(timezone.utc)-timedelta(seconds=60)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
write_state "$OLD"
out=$(run_hook)
echo "$out" | grep -q "reviewing-spec" \
  && echo "$out" | grep -q "terminal handoff" \
  && note PASS "AC4: reminder re-emits past TTL with full mandate body" \
  || note FAIL "AC4 failed. out='$out'"

# AC8: kill switch via DEVBREW_SKIP_HOOKS
out=$(run_hook "DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit")
[[ -z "$out" ]] \
  && note PASS "AC8: kill switch (UserPromptSubmit) suppresses emit" \
  || note FAIL "AC8 (UserPromptSubmit) unexpected output: '$out'"

out=$(run_hook "DEVBREW_DISABLE_SPEC_DISTILL=1")
[[ -z "$out" ]] \
  && note PASS "AC8: kill switch (DISABLE_SPEC_DISTILL) suppresses emit" \
  || note FAIL "AC8 (DISABLE) unexpected output: '$out'"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

```bash
chmod +x plugins/spec-distill/tests/test_reminder_hook.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash plugins/spec-distill/tests/test_reminder_hook.sh`
Expected: FAIL — hook file not found.

- [ ] **Step 3: Implement reminder hook**

Create `plugins/spec-distill/hooks/pending-review-reminder.py`:

```python
#!/usr/bin/env python3
"""spec-distill UserPromptSubmit hook — pending review reminder.

If state.local.md still has a pending_review block AND last_dispatched_at is
older than TTL (default 30s), re-emit the Stop hook's mandate so the next-turn
agent doesn't silently drop the dispatch.

Kill switches:
- DEVBREW_DISABLE_SPEC_DISTILL=1
- DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit  (or :reminder)
- DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=<int>  (default 30; shared with Stop hook)
"""
from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from state_path import state_root as _state_root, cleanup_stale_states  # noqa: E402


PENDING_RE = re.compile(
    r"^pending_review:\n  path:\s*(?P<path>[^\n]+)\n  mode:\s*(?P<mode>[^\n]+)\n"
    r"(?:  worktree_path:\s*(?P<wt>[^\n]+)\n)?"
    r"  triggered_at:\s*(?P<triggered>[^\n]+)\n",
    re.MULTILINE,
)
LAST_DISPATCHED_RE = re.compile(r"^last_dispatched_at:\s*(.+)$", re.MULTILINE)


def kill_switch_active() -> bool:
    if os.environ.get("DEVBREW_DISABLE_SPEC_DISTILL") == "1":
        return True
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    tokens = {p.strip() for p in skip.split(",") if p.strip()}
    return bool(tokens & {
        "spec-distill:UserPromptSubmit",
        "spec-distill:reminder",
    })


def parse_iso(s: str):
    try:
        return datetime.strptime(s.strip(), "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except (ValueError, AttributeError):
        return None


def main() -> int:
    if kill_switch_active():
        return 0
    # Consume stdin (UserPromptSubmit payload), but we don't actually need it
    try:
        sys.stdin.read()
    except Exception:
        pass
    session_id = os.environ.get("DEVBREW_SPEC_DISTILL_SESSION_ID", "default")
    state_file = _state_root() / session_id / "state.local.md"
    if not state_file.exists():
        return 0
    try:
        body = state_file.read_text(encoding="utf-8")
    except OSError as e:
        print(f"[spec-distill] reminder state read failed (non-fatal): {e}", file=sys.stderr)
        return 0
    # Best-effort cleanup
    try:
        cleanup_stale_states(_state_root())
    except (OSError, PermissionError):
        pass
    # Re-read after cleanup (block may have been purged)
    try:
        body = state_file.read_text(encoding="utf-8")
    except OSError:
        return 0
    m = PENDING_RE.search(body)
    if not m:
        return 0
    try:
        ttl = int(os.environ.get("DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC", "30"))
    except ValueError:
        ttl = 30
    now = datetime.now(timezone.utc)
    ld = LAST_DISPATCHED_RE.search(body)
    if ld:
        last = parse_iso(ld.group(1))
        if last and (now - last) < timedelta(seconds=ttl):
            return 0
    spec_path = m.group("path").strip()
    mode = m.group("mode").strip()
    wt = (m.group("wt") or "").strip()
    parts = [
        "REMINDER (UserPromptSubmit): pending_review still active — reviewing-spec skill 호출 필요.",
        f"spec path: {spec_path}.",
        f"mode: {mode}.",
    ]
    if wt:
        parts.append(f"worktree_path: {wt}.")
    parts.append("호출 skill의 terminal handoff(writing-plans 등)는 review pass 이후로 보류.")
    print(json.dumps({"systemMessage": " ".join(parts)}), flush=True)
    # Update last_dispatched_at so we don't spam
    new_body = LAST_DISPATCHED_RE.sub(
        f"last_dispatched_at: {now.strftime('%Y-%m-%dT%H:%M:%SZ')}", body,
    )
    if new_body == body:
        new_body = body.rstrip() + f"\nlast_dispatched_at: {now.strftime('%Y-%m-%dT%H:%M:%SZ')}\n"
    try:
        state_file.write_text(new_body, encoding="utf-8")
    except OSError as e:
        print(f"[spec-distill] reminder state rewrite failed (non-fatal): {e}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

```bash
chmod +x plugins/spec-distill/hooks/pending-review-reminder.py
```

- [ ] **Step 4: Run test to verify pass**

Run: `bash plugins/spec-distill/tests/test_reminder_hook.sh`
Expected: PASS — 4 cases.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/hooks/pending-review-reminder.py \
        plugins/spec-distill/tests/test_reminder_hook.sh
git commit -m "feat(spec-distill): UserPromptSubmit reminder hook — L4b TTL-guarded redundancy"
```

---

## Task 7: hooks.json — register UserPromptSubmit reminder

**Files:**
- Modify: `plugins/spec-distill/hooks/hooks.json:4-14` (UserPromptSubmit array)

설명: 신규 reminder hook을 기존 interview-trigger.sh 옆에 배치. 두 hook이 같은 event 안에서 공존 — 순서 무관(둘 다 advisory).

- [ ] **Step 1: Modify hooks.json**

Edit `plugins/spec-distill/hooks/hooks.json` — replace the `UserPromptSubmit` array (currently single-item):

```json
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/interview-trigger.sh",
            "timeout": 10
          },
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/pending-review-reminder.py",
            "timeout": 5
          }
        ]
      }
    ],
```

- [ ] **Step 2: Validate JSON syntax**

Run: `python3 -c "import json; json.load(open('plugins/spec-distill/hooks/hooks.json'))"`
Expected: no output (valid JSON).

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/hooks/hooks.json
git commit -m "feat(spec-distill): register UserPromptSubmit reminder hook in hooks.json"
```

---

## Task 8: reviewing-spec/SKILL.md — design mode branch + routing rows (TDD via grep)

**Files:**
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md:18` (Step 1) + `:32-43` (Routing Table)
- Create: `plugins/spec-distill/tests/test_reviewing_spec_design_routing.sh`

설명: AC5 + AC6. Step 1에 `pending_review.mode` 분기 명시(design일 때 locked_decisions / 11-sections 점검 skip). Routing Table에 design rows 3개 추가, "drafting-spec 미호출" 명시.

- [ ] **Step 1: Write failing test**

Create `plugins/spec-distill/tests/test_reviewing_spec_design_routing.sh`:

```bash
#!/usr/bin/env bash
# AC5 + AC6 — reviewing-spec SKILL.md design mode branch + routing rows.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL="$REPO_ROOT/plugins/spec-distill/skills/reviewing-spec/SKILL.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# AC5: Step 1 mode branch
grep -qE 'pending_review.*mode|mode.*분기.*design' "$SKILL" \
  && grep -qE '11.section|locked_decisions' "$SKILL" \
  && note PASS "AC5: Step 1 references mode branch + 11-section/locked_decisions skip" \
  || note FAIL "AC5 mode branch missing in Step 1"

# AC6: design rows in routing table
# (approved → Human Gate → writing-plans)
grep -qE 'design\b.*approved.*Human Gate' "$SKILL" \
  && note PASS "AC6: design approved → Human Gate row present" \
  || note FAIL "AC6 design approved row missing"

# (needs_revise & count<3 → brainstorming author 회귀)
grep -qE 'design\b.*needs_revise.*brainstorming author' "$SKILL" \
  && note PASS "AC6: design needs_revise → brainstorming author 회귀 row present" \
  || note FAIL "AC6 design needs_revise row missing"

# (drafting-spec 미호출 명시)
grep -qE 'drafting-spec.*미호출|drafting-spec.*호출하지 (않|않음)' "$SKILL" \
  && note PASS "AC6: 'drafting-spec 미호출' explicit text present" \
  || note FAIL "AC6 drafting-spec exclusion missing"

# (forced Human Gate at count >= 3)
grep -qE 'design\b.*count >?= ?3|design\b.*>=.*3.*Human Gate' "$SKILL" \
  && note PASS "AC6: design count>=3 forced Human Gate row present" \
  || note FAIL "AC6 design forced escalate row missing"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

```bash
chmod +x plugins/spec-distill/tests/test_reviewing_spec_design_routing.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash plugins/spec-distill/tests/test_reviewing_spec_design_routing.sh`
Expected: FAIL — 5 assertions all missing.

- [ ] **Step 3: Edit Step 1 (mode branch)**

In `plugins/spec-distill/skills/reviewing-spec/SKILL.md` Step 1 (currently around line 18), append before the period of the last sentence:

```markdown
1. **Load state.local.md** — `session_id`, `rereview_count`, `wall_clock_started_at`, `issue_history` 읽기. 또한 `pending_review:` block 존재 여부 확인. *이 skill은 PostToolUse hook이 spec/design 파일 write를 감지해 file ledger에 `pending_review:` block을 기록한 직후, Stop hook이 다음 turn에 systemMessage로 dispatch를 강제했기 때문에* 호출됨 — `pending_review:` block이 *없는 채로* invoke되면 manual override로 간주 (loud advisory). **`pending_review.mode` 분기**: `mode: design`일 때 11-section 누락 / locked_decisions schema 검사는 *skip* (brainstorming의 design.md는 spec.md와 다른 양식). 본문의 placeholder / ambiguity / scope-creep / approaches-comparison / isolation / testing 검사만 spec-reviewer에게 요청. `session_id`가 unbound이거나 placeholder `<session-id>` 인 채로면 Step 3 cleanup이 charset 검증으로 자동 skip되지만, 사용자에게 명시적 통보 필요 (P14 + AP2).
```

- [ ] **Step 4: Edit Routing Table — add design rows**

Replace the routing table (around line 32-43) — keep existing spec rows + add design rows:

```markdown
## Deterministic Routing Table (AC15)

| Mode | Verdict | Stagnation_signal | rereview_count | affects_locked | → Next Phase |
|---|---|---|---|---|---|
| spec | `approved` | - | - | - | **[5] Human Gate** (auto) |
| spec | `needs_revise` | false | < 3 | **empty** | **[4] Revise** (auto, dispatch drafting-spec Mode B with `allowed_issue_ids = [all]`) |
| spec | `needs_revise` | false | < 3 | **non-empty** | **[3.5] Re-consensus gate** |
| spec | `needs_revise` | false | >= 3 | - | **[5] Human Gate** (forced escalate, full issue_history 첨부) |
| spec | `needs_revise` | true | - | - | **[5] Human Gate** (P18 stagnation, forced escalate — dismissed_by_user >= 1 issue는 stagnation count 제외) |
| spec | `needs_interview` | - | - | - | **user confirm gate** → [1] Interview 또는 [5] (취소) |
| **design** | `approved` | - | - | - | **[5] Human Gate** → `superpowers:writing-plans` |
| **design** | `needs_revise` | - | < 3 | - | **brainstorming author 회귀**: 메인 agent가 design.md 직접 수정 후 reviewing-spec 재dispatch. **drafting-spec Mode B 호출하지 않음** (spec mode 전용). |
| **design** | `needs_revise` | - | >= 3 | - | **[5] Human Gate** (forced escalate, full issue_history 첨부) |

매 dispatch 후 위 표를 *그대로* 적용. prose-based 결정 금지.
```

- [ ] **Step 5: Run test to verify pass**

Run: `bash plugins/spec-distill/tests/test_reviewing_spec_design_routing.sh`
Expected: PASS — 5 assertions.

- [ ] **Step 6: Commit**

```bash
git add plugins/spec-distill/skills/reviewing-spec/SKILL.md \
        plugins/spec-distill/tests/test_reviewing_spec_design_routing.sh
git commit -m "feat(spec-distill): reviewing-spec — design mode branch + 3 design routing rows"
```

---

## Task 9: agents/spec-reviewer.md — design checklist branch (TDD via grep + dry-run)

**Files:**
- Modify: `plugins/spec-distill/agents/spec-reviewer.md` (add design mode section after "What to check" table)
- Create: `plugins/spec-distill/tests/test_spec_reviewer_design_checklist.sh`

설명: AC7. spec mode 본문 무손상 + design mode 분기 섹션 추가. 카테고리: placeholder / ambiguity / scope-creep / approaches-comparison / isolation / testing.

- [ ] **Step 1: Write failing test**

Create `plugins/spec-distill/tests/test_spec_reviewer_design_checklist.sh`:

```bash
#!/usr/bin/env bash
# AC7 — agents/spec-reviewer.md design mode checklist + 6 카테고리.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/spec-reviewer.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# AC7a: design mode section header exists
grep -qE '^##.*[Dd]esign.*[Mm]ode' "$AGENT" \
  && note PASS "AC7: design mode section header exists" \
  || note FAIL "AC7 design mode section header missing"

# AC7b: 6 카테고리 모두 등장
for cat in "placeholder" "ambiguity" "scope.creep" "approaches.compar" "isolation" "testing"; do
  grep -qiE "$cat" "$AGENT" \
    && note PASS "AC7: category '$cat' present" \
    || note FAIL "AC7 category '$cat' missing"
done

# AC7c: spec mode regression — 기존 "11 필수 섹션" 표현 보존
grep -qE '11.*필수.*섹션|missing_section' "$AGENT" \
  && note PASS "AC7: spec mode 11-section table preserved (regression)" \
  || note FAIL "spec mode 11-section text accidentally removed"

# AC7d: Output 형식 (round N + Status + Issues + Stagnation_signal) 보존
grep -q 'Spec Review (round N)' "$AGENT" \
  && grep -q 'Stagnation_signal' "$AGENT" \
  && note PASS "AC7: Output 형식 (round N + Stagnation_signal) preserved" \
  || note FAIL "Output format regression"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

```bash
chmod +x plugins/spec-distill/tests/test_spec_reviewer_design_checklist.sh
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash plugins/spec-distill/tests/test_spec_reviewer_design_checklist.sh`
Expected: FAIL — design mode section header missing + categories.

- [ ] **Step 3: Add design mode section to spec-reviewer.md**

In `plugins/spec-distill/agents/spec-reviewer.md`, append the following section after the existing "What to check" table (right before "### Locked decisions 매핑" subsection):

```markdown
### Design Mode Branch (v0.4.0)

입력 spec 파일이 `*-design.md`로 끝나면 (또는 dispatcher가 `mode: design`을 prompt에 명시한 경우) 다음 분기 적용:

- **NOT applied (skip)**: `missing_section` (11 필수 섹션) + locked_decisions schema 검사. design.md는 brainstorming이 산출하는 자유 형식 — spec.md schema 강제하지 않음 (philosophy LD7 승계).
- **Applied (design checklist 6 카테고리)**:

| Category | What to flag | Severity |
|---|---|---|
| `placeholder` | "TBD", "TODO", "FIXME", "fill in later" 등 미완 표현 | high |
| `ambiguity` | "robust", "works correctly", "fast", "as needed" 등 측정 불가 키워드 (ambiguity-blacklist.txt 참고) | high |
| `scope_creep` | 한 design에 여러 독립 subsystem이 묶여 있어 single implementation plan으로 분해 곤란 | medium |
| `approaches_comparison` | 2-3개 대안 + tradeoff 제시 없이 단일 안만 기술됨 | medium |
| `isolation` | 컴포넌트 boundary / interface 정의가 모호해서 단위 테스트 / 변경 격리 불가능 | high |
| `testing` | Verification Plan 부재 또는 "manual check"만 — 자동 검증 절차 없음 | high |

design mode 결과에서도 위와 동일한 Output 형식 (Status / Issues / Recommendations / Stagnation_signal) 준수. spec mode와 동일한 `issue_id` 알고리즘 (`sha256_short(category + ":" + target_section)`). `affects_locked_decisions:` 필드는 design.md에 frontmatter `locked_decisions:`가 없으면 `[]` (빈 리스트, *반드시 emit*).
```

- [ ] **Step 4: Run test to verify pass**

Run: `bash plugins/spec-distill/tests/test_spec_reviewer_design_checklist.sh`
Expected: PASS — 9 assertions (1 section + 6 categories + spec regression + output format).

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/agents/spec-reviewer.md \
        plugins/spec-distill/tests/test_spec_reviewer_design_checklist.sh
git commit -m "feat(spec-distill): spec-reviewer — design mode checklist branch (6 카테고리)"
```

---

## Task 10: plugin.json + CHANGELOG.md + README.md

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json:5` (version)
- Modify: `plugins/spec-distill/CHANGELOG.md` (prepend [0.4.0] section)
- Modify: `plugins/spec-distill/README.md` (Hooks Installed + Principles Instantiated)

설명: AC9 — version bump 0.3.0 → 0.4.0, CHANGELOG에 변경사항 기재, README 갱신.

- [ ] **Step 1: Bump plugin.json version**

Edit `plugins/spec-distill/.claude-plugin/plugin.json` — change `"version": "0.3.0"` to `"version": "0.4.0"`.

Verify:

```bash
python3 -c "import json; v=json.load(open('plugins/spec-distill/.claude-plugin/plugin.json'))['version']; assert v=='0.4.0', v; print('ok', v)"
```

Expected: `ok 0.4.0`

- [ ] **Step 2: Prepend CHANGELOG.md entry**

Edit `plugins/spec-distill/CHANGELOG.md` — insert immediately after `# Changelog` line (before existing `## [0.3.0]`):

```markdown
## [0.4.0] — 2026-05-17

### Added
- `hooks/state_path.py` — main repo root 해석 helper (`git rev-parse --git-common-dir` 기반). state 파일을 항상 main repo `.claude/spec-distill/` 아래에 기록 (worktree 호출 시에도). cwd fallback + stderr loud log (philosophy §4.8 instantiation).
- `hooks/pending-review-reminder.py` — UserPromptSubmit hook. pending_review가 살아있고 last_dispatched_at > TTL(30s)이면 mandate 재emit (L4b redundancy). Kill switch `spec-distill:UserPromptSubmit` / `spec-distill:reminder`.
- State cleanup 정책: pending_review `triggered_at` > 24h → block auto-purge, last_dispatched_at만 있는 state file > 7일 → file auto-delete. 신규 env var 없이 하드코딩.
- reviewing-spec SKILL.md — Step 1 `pending_review.mode` 분기 + Routing Table에 design rows 3개 추가 (approved → writing-plans, needs_revise < 3 → brainstorming author 회귀, needs_revise ≥ 3 → forced Human Gate). drafting-spec Mode B는 design.md에 호출하지 *않음*.
- agents/spec-reviewer.md — design mode checklist 분기 섹션 6 카테고리 (placeholder / ambiguity / scope_creep / approaches_comparison / isolation / testing). spec mode 본문 무손상.
- 신규 test 6개: `test_state_path.sh`, `test_state_cleanup.sh`, `test_design_mode_validator.sh`, `test_review_dispatch_design_mandate.sh`, `test_reminder_hook.sh`, `test_reviewing_spec_design_routing.sh`, `test_spec_reviewer_design_checklist.sh`.
- 신규 fixture 2개: `tests/fixtures/2026-05-17-test-design.md` (valid), `tests/fixtures/2026-05-17-test-design-bad.md` (placeholder + ambiguity hits).

### Changed
- `hooks/spec-write-validator.py` — state path을 `state_path.state_root()`로 해석, pending_review block에 `worktree_path:` 필드 추가.
- `hooks/review-dispatch.py` — state path을 state_path helper로 해석, mandate systemMessage 본문에 "타 terminal handoff(writing-plans 등) 보류" 문구 + worktree_path 포함, fire마다 `cleanup_stale_states` 호출.
- `hooks/hooks.json` — UserPromptSubmit에 reminder hook 등록 (기존 interview-trigger.sh 옆).

### Security
- 모든 신규 hook은 기존 kill switch (`DEVBREW_DISABLE_SPEC_DISTILL=1`, `DEVBREW_SKIP_HOOKS=spec-distill:<event>`) 존중. 신규 env var 없음 (LD10 일관성).
- bare repo / submodule / nested worktree / `.git` symlink는 supported scope 밖 — state_path cwd fallback + loud log로 운영자 인지 (NG6).

```

- [ ] **Step 3: Update README.md "Hooks Installed"**

Edit `plugins/spec-distill/README.md` — find the existing "Hooks Installed" table and add a row for UserPromptSubmit reminder. Also confirm/add Principles Instantiated entry for G6.

Add table row (after existing rows for UserPromptSubmit interview-trigger / PostToolUse validator / Stop dispatch):

```markdown
| UserPromptSubmit | `hooks/pending-review-reminder.py` | Stop hook single-shot mandate가 next-turn에서 silent drop될 경우 매 user prompt에 mandate 재emit하는 redundancy layer — turn boundary 이벤트가 필요하므로 skill로 처리 불가. TTL(30s) 가드로 spam 방지. Kill switch: `DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit` / `:reminder`. |
```

Add one line to Principles Instantiated section (if list exists):

```markdown
- **§4.8 worktree path convention**: state 파일 위치를 `state_path.state_root()`로 단일화하여 worktree 호출 시에도 main repo `.claude/spec-distill/`에만 기록 — `ExitWorktree action: remove` 시 pending_review state silent loss 차단.
```

- [ ] **Step 4: Verify all docs consistent**

Run:

```bash
grep -c '0.4.0' plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md
```

Expected: both files contain "0.4.0" at least once.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json \
        plugins/spec-distill/CHANGELOG.md \
        plugins/spec-distill/README.md
git commit -m "chore(spec-distill): bump to v0.4.0 + CHANGELOG + README"
```

---

## Task 11: Full test suite regression + manual E2E

설명: V5/V5a/V6/V7 — 자동 회귀 + 수동 E2E.

- [ ] **Step 1: Run entire spec-distill test suite**

```bash
bash plugins/spec-distill/tests/test_hooks.sh && \
bash plugins/spec-distill/tests/test_spec_write_validator.sh && \
bash plugins/spec-distill/tests/test_review_dispatch.sh && \
bash plugins/spec-distill/tests/test_parse_spec_structure.sh && \
bash plugins/spec-distill/tests/test_state_path.sh && \
bash plugins/spec-distill/tests/test_state_cleanup.sh && \
bash plugins/spec-distill/tests/test_design_mode_validator.sh && \
bash plugins/spec-distill/tests/test_review_dispatch_design_mandate.sh && \
bash plugins/spec-distill/tests/test_reminder_hook.sh && \
bash plugins/spec-distill/tests/test_reviewing_spec_design_routing.sh && \
bash plugins/spec-distill/tests/test_spec_reviewer_design_checklist.sh
```

Expected: 모든 스크립트가 "Total: N | Pass: N | Fail: 0"으로 종료, 마지막 exit code 0.

- [ ] **Step 2: V5/V5a manual E2E — worktree write → state in main repo**

```bash
# In a fresh shell at devbrew main repo root
git worktree add -q .claude/worktrees/v0.4.0-e2e-test HEAD
cd .claude/worktrees/v0.4.0-e2e-test
# Simulate a brainstorming-style design.md write by invoking the hook directly
PAYLOAD='{"tool_name":"Write","tool_input":{"file_path":"'"$PWD/docs/superpowers/specs/2026-05-17-e2e-test-design.md"'"}}'
mkdir -p docs/superpowers/specs
cp ../../../plugins/spec-distill/tests/fixtures/2026-05-17-test-design.md \
   docs/superpowers/specs/2026-05-17-e2e-test-design.md
DEVBREW_SPEC_DISTILL_SESSION_ID=v0.4.0-e2e \
  echo "$PAYLOAD" | python3 ../../../plugins/spec-distill/hooks/spec-write-validator.py
# Verify state lands in MAIN repo, NOT worktree
ls -la ../../../.claude/spec-distill/v0.4.0-e2e/state.local.md
# Should not exist in worktree:
[ ! -d .claude/spec-distill ] && echo "PASS: worktree .claude/spec-distill not created" || echo "FAIL"
cd ../../..
# Now exit and remove the worktree
git worktree remove .claude/worktrees/v0.4.0-e2e-test --force
# State should survive
ls -la .claude/spec-distill/v0.4.0-e2e/state.local.md
echo "PASS: state preserved after worktree removal"
# Cleanup
rm -rf .claude/spec-distill/v0.4.0-e2e
```

Expected: state file lives only in `<repo>/.claude/spec-distill/v0.4.0-e2e/`, survives worktree removal.

- [ ] **Step 3: V6 kill switch verification**

```bash
PAYLOAD='{"user_prompt":"x"}'
echo "$PAYLOAD" | DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit \
  python3 plugins/spec-distill/hooks/pending-review-reminder.py
echo "exit: $?"
```

Expected: exit 0, no stdout output.

```bash
echo "$PAYLOAD" | DEVBREW_DISABLE_SPEC_DISTILL=1 \
  python3 plugins/spec-distill/hooks/pending-review-reminder.py
echo "exit: $?"
```

Expected: exit 0, no stdout output.

- [ ] **Step 4: Final commit + PR-ready summary**

Confirm `git log --oneline -15` shows all v0.4.0 commits in sequence. No further commit needed in this task — just verify.

```bash
git log --oneline -15
```

Expected sequence (approximate, count varies by exact commit grouping):
- chore(spec-distill): bump to v0.4.0 + CHANGELOG + README
- feat(spec-distill): spec-reviewer — design mode checklist branch
- feat(spec-distill): reviewing-spec — design mode branch + 3 design routing rows
- feat(spec-distill): register UserPromptSubmit reminder hook in hooks.json
- feat(spec-distill): UserPromptSubmit reminder hook — L4b TTL-guarded redundancy
- feat(spec-distill): Stop mandate strengthened — terminal handoff defer + worktree_path
- feat(spec-distill): PostToolUse uses state_path helper + worktree_path field
- feat(spec-distill): state cleanup policy — 24h pending purge / 7d file delete
- feat(spec-distill): state_path helper for worktree-aware state root
- test(spec-distill): add v0.4.0 design.md fixtures (valid + bad)
- (4 design doc commits before this branch's work)

---

## Self-Review Checklist (post-write)

**Spec coverage (per AC):**

- AC1 — Task 4 (`test_design_mode_validator.sh` Case 1)
- AC2 — Task 5 (`test_review_dispatch_design_mandate.sh` 'reviewing-spec' + 'terminal handoff' grep)
- AC3 — Task 6 (`test_reminder_hook.sh` AC3 case)
- AC4 — Task 6 (AC4 case)
- AC5 — Task 8 (`test_reviewing_spec_design_routing.sh` Step 1 mode branch grep)
- AC6 — Task 8 (3 design routing rows grep + drafting-spec 미호출)
- AC7 — Task 9 (`test_spec_reviewer_design_checklist.sh` 6 카테고리 + spec regression)
- AC8 — Task 6 (kill switch cases)
- AC9 — Task 10 (plugin.json version + CHANGELOG + README rows)
- AC10 — Task 11 (full suite run)
- AC11 — Task 4 (Case 1: state lands in main repo, not worktree)
- AC12 — Task 4 (Case 2: worktree_path field) + Task 5 (mandate carries worktree_path)
- AC13 — Task 2 (`test_state_path.sh` Case 3: non-git fallback + loud log)

**No placeholders:** scan complete — all "TODO/TBD/FIXME" mentions are inside Test fixtures (intentional, see Task 1 Step 2) or routing tables describing the design itself, not hidden plan gaps.

**Type/method consistency:**
- `state_root(cwd: str | None = None) -> Path` (Task 2) — referenced as `_state_root()` (no arg) in Tasks 4-6.
- `cleanup_stale_states(root: Path) -> None` (Task 3) — referenced verbatim in Tasks 5-6.
- `PENDING_RE` regex (Task 5) — same exact regex re-used in Task 6 reminder hook (worktree_path optional group with same name `wt`).
- `write_state(session_id, path, mode, worktree_path)` (Task 4) — only called in spec-write-validator.py; no consumer mismatch.

---

**Plan complete and saved to `docs/superpowers/plans/2026-05-17-spec-distill-design-mode-trigger.md`.**

Two execution options:

**1. Subagent-Driven (recommended)** — fresh subagent per task + two-stage review, fast iteration.

**2. Inline Execution** — execute tasks in this session using executing-plans, batch with checkpoints.

Which approach?
