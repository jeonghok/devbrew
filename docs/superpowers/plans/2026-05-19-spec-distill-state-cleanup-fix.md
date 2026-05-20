# spec-distill State Cleanup Residue Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `plugins/spec-distill/`에서 (a) session_id가 `"default"` literal로 collapse하는 singleton 버그 제거 + (b) SessionEnd hook으로 deterministic per-session cleanup + (c) TTL-GC + approve_handoff script 추출 + (d) write_state defensive truncate 마지막 보루. v0.5.1 → v0.6.0 minor bump.

**Architecture:** `CLAUDE_CODE_SESSION_ID`를 single source of truth로 채택 (qg pattern adaptation). 3개 기존 hook은 `state_path.resolve_session_id(payload)` helper 호출로 통일. 신규 SessionEnd hook + TTL-GC script + approve_handoff.sh가 4-layer cleanup defense 구성. Path resolution은 spec-distill의 git-aware `state_path.state_root(cwd)` 사용 (qg의 단순 cwd-relative와 divergence — worktree 사용자에서 main repo `.claude/spec-distill/` 일관성 유지).

**Tech Stack:** Python 3 stdlib (`unittest`, `subprocess`, `tempfile`, `shutil`, `fcntl`, `re`, `os`, `json`, `pathlib`, `datetime`), bash (`set -euo pipefail`, `rm -rf -- ... || true`), git CLI. 외부 의존성 추가 없음. Cross-plugin reference: `plugins/quality-gates/scripts/qg-gc.py`, `plugins/quality-gates/hooks/session-end-cleanup.py`, `plugins/quality-gates/scripts/setup-qg.sh:108-128`.

**Spec:** `docs/superpowers/specs/2026-05-19-spec-distill-state-cleanup-fix-design.md` (3 rounds reviewed, approved).

**Branch:** `feature/spec-distill-state-cleanup-fix` from `main`. Conventional Commits: `feat(spec-distill): session-id resolution + 4-layer cleanup defense (v0.6.0)`.

---

## File Structure

**Modified (hook + helper, 4 files):**
- `plugins/spec-distill/hooks/state_path.py` — add `SESSION_PATTERN` + `resolve_session_id(payload)`, deprecate `cleanup_stale_states`
- `plugins/spec-distill/hooks/spec-write-validator.py` — session_id 소스 교체 + `write_state` defensive truncate + AC14 legacy advisory
- `plugins/spec-distill/hooks/review-dispatch.py` — session_id 소스 교체 + GC subprocess
- `plugins/spec-distill/hooks/pending-review-reminder.py` — session_id 소스 교체 + GC subprocess

**Modified (hooks config + SKILL.md, 2 files):**
- `plugins/spec-distill/hooks/hooks.json` — SessionEnd event 등록
- `plugins/spec-distill/skills/reviewing-spec/SKILL.md` — AC11 prose → 1-line script call

**Modified (metadata, 3 files):**
- `plugins/spec-distill/.claude-plugin/plugin.json` — version bump 0.5.1 → 0.6.0
- `plugins/spec-distill/CHANGELOG.md` — [0.6.0] entry
- `plugins/spec-distill/README.md` — Hooks Installed + Principles Instantiated 갱신

**Created (new source, 3 files):**
- `plugins/spec-distill/hooks/session-end-cleanup.py` — SessionEnd hook
- `plugins/spec-distill/scripts/spec-distill-gc.py` — TTL-GC
- `plugins/spec-distill/scripts/approve_handoff.sh` — AC11 atomic script (chmod 755)

**Created (tests, 7 files):**
- `plugins/spec-distill/tests/test_session_id_resolution.sh` (AC1, 11 cases)
- `plugins/spec-distill/tests/test_session_end_cleanup.py` (AC4, 8 cases)
- `plugins/spec-distill/tests/test_gc.py` (AC5, 12 cases including `.gc-pending-*` sweep)
- `plugins/spec-distill/tests/test_approve_handoff.sh` (AC6, 8 cases)
- `plugins/spec-distill/tests/test_stale_state_truncate.sh` (AC8, 4 cases)
- `plugins/spec-distill/tests/test_brainstorming_entry.sh` (AC9, 3 cases sequential)
- `plugins/spec-distill/tests/test_kill_switches_v060.sh` (AC10, 6+ cases)

**Unchanged (explicit):** `agents/`, `skills/conducting-interview/SKILL.md`, `skills/drafting-spec/SKILL.md`, `hooks/interview-trigger.sh`, `hooks/session-anchor.sh`, `commands/interview.md`, `scripts/ambiguity-blacklist.txt`, `scripts/parse_spec_structure.py`.

---

## Task 1: Branch setup + verify clean baseline

**Files:** check only, no edits.

- [ ] **Step 1: Verify on main and clean**

```bash
git status
git branch --show-current
```

Expected: branch=`main`, working tree clean. If dirty, stash or abort.

- [ ] **Step 2: Create feature branch**

```bash
git checkout -b feature/spec-distill-state-cleanup-fix
```

- [ ] **Step 3: Verify baseline tests pass (regression safety net)**

```bash
cd plugins/spec-distill/
bash tests/test_state_path.sh
bash tests/test_spec_write_validator.sh
bash tests/test_review_dispatch.sh
bash tests/test_reminder_hook.sh
bash tests/test_design_mode_validator.sh
bash tests/test_review_dispatch_design_mandate.sh
python3 -m unittest tests.test_hook_output_schema
cd ../..
```

Expected: all 7 existing tests PASS. If any fail at baseline, abort and report.

---

## Task 2: AC1 — `resolve_session_id` TDD (Phase 1, deliverable a)

**Files:**
- Create: `plugins/spec-distill/tests/test_session_id_resolution.sh`
- Modify: `plugins/spec-distill/hooks/state_path.py` (add `SESSION_PATTERN` + `resolve_session_id`)

- [ ] **Step 1: Write failing test (11 cases)**

Create `plugins/spec-distill/tests/test_session_id_resolution.sh`:

```bash
#!/usr/bin/env bash
# AC1 verification — resolve_session_id() precedence + charset/length validation.
set -uo pipefail

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hooks"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)); }

# Helper: call resolve_session_id with env + payload, return string or "<none>" if None
call() {
    local env_assigns=("${!1}") payload="$2"
    env "${env_assigns[@]}" python3 -c "
import sys, json, os
sys.path.insert(0, '$HOOKS_DIR')
from state_path import resolve_session_id
p = json.loads('''$payload''') if '$payload' else None
r = resolve_session_id(p)
print(r if r is not None else '<none>')
" 2>/dev/null
}

# Case 1: test override + CLAUDE_CODE_SESSION_ID both set → test override wins
envs=(DEVBREW_SPEC_DISTILL_SESSION_ID=override-12345678 CLAUDE_CODE_SESSION_ID=ccsid-87654321)
[[ "$(call envs[@] '')" == "override-12345678" ]] \
    && note PASS "case 1: test override precedence" \
    || note FAIL "case 1: test override precedence"

# Case 2: only CLAUDE_CODE_SESSION_ID set
envs=(CLAUDE_CODE_SESSION_ID=ccsid-87654321)
[[ "$(call envs[@] '')" == "ccsid-87654321" ]] \
    && note PASS "case 2: CLAUDE_CODE_SESSION_ID fallback" \
    || note FAIL "case 2: CLAUDE_CODE_SESSION_ID fallback"

# Case 3: env unset, payload has session_id
envs=()
[[ "$(call envs[@] '{"session_id":"payload-12345678"}')" == "payload-12345678" ]] \
    && note PASS "case 3: payload fallback" \
    || note FAIL "case 3: payload fallback"

# Case 4: all sources empty → None
envs=()
[[ "$(call envs[@] '')" == "<none>" ]] \
    && note PASS "case 4: None on unresolved" \
    || note FAIL "case 4: None on unresolved"

# Case 5: test override empty string + CLAUDE_CODE_SESSION_ID set → fallback (empty=falsy)
envs=(DEVBREW_SPEC_DISTILL_SESSION_ID= CLAUDE_CODE_SESSION_ID=ccsid-87654321)
[[ "$(call envs[@] '')" == "ccsid-87654321" ]] \
    && note PASS "case 5: empty string falls through" \
    || note FAIL "case 5: empty string falls through"

# Case 6: session_id with spaces → charset reject
envs=(CLAUDE_CODE_SESSION_ID="with spaces")
[[ "$(call envs[@] '')" == "<none>" ]] \
    && note PASS "case 6: charset reject (spaces)" \
    || note FAIL "case 6: charset reject (spaces)"

# Case 7: traversal/slash/dot → charset reject
for bad in "../traversal" "with/slash" "with.dot"; do
    envs=(CLAUDE_CODE_SESSION_ID="$bad")
    [[ "$(call envs[@] '')" == "<none>" ]] \
        && note PASS "case 7: charset reject ($bad)" \
        || note FAIL "case 7: charset reject ($bad)"
done

# Case 8: length < 8 reject
envs=(CLAUDE_CODE_SESSION_ID=abc)
[[ "$(call envs[@] '')" == "<none>" ]] \
    && note PASS "case 8: length reject (< 8)" \
    || note FAIL "case 8: length reject (< 8)"

# Case 9: exactly 8 chars accept
envs=(CLAUDE_CODE_SESSION_ID=a1b2c3d4)
[[ "$(call envs[@] '')" == "a1b2c3d4" ]] \
    && note PASS "case 9: exactly 8 chars" \
    || note FAIL "case 9: exactly 8 chars"

# Case 10: UUID format accept
envs=(CLAUDE_CODE_SESSION_ID=a3f8b1c2-4d5e-6f7a-8b9c-0d1e2f3a4b5c)
[[ "$(call envs[@] '')" == "a3f8b1c2-4d5e-6f7a-8b9c-0d1e2f3a4b5c" ]] \
    && note PASS "case 10: UUID format" \
    || note FAIL "case 10: UUID format"

# Case 11: 256 chars accept (charset valid)
long_sid=$(printf '%.0sa' {1..256})
envs=(CLAUDE_CODE_SESSION_ID="$long_sid")
[[ "$(call envs[@] '')" == "$long_sid" ]] \
    && note PASS "case 11: 256-char accept" \
    || note FAIL "case 11: 256-char accept"

if [[ "$fail" -gt 0 ]]; then
    echo "FAILED: $fail case(s)"
    exit 1
fi
echo "PASSED: 11 cases"
```

- [ ] **Step 2: Run test, verify fails (function not defined)**

```bash
cd plugins/spec-distill/
bash tests/test_session_id_resolution.sh
```

Expected: FAIL with `ImportError: cannot import name 'resolve_session_id'` or similar.

- [ ] **Step 3: Add `SESSION_PATTERN` + `resolve_session_id` to `state_path.py`**

Modify `plugins/spec-distill/hooks/state_path.py` — add at top after existing imports + before `state_root()`:

```python
import re

SESSION_PATTERN = re.compile(r"^[A-Za-z0-9_-]{8,}$")


def resolve_session_id(payload: dict | None = None) -> str | None:
    """Resolve session_id with precedence: test override → CLAUDE_CODE_SESSION_ID → payload.

    Returns None + loud stderr on unresolved or charset/length validation failure.
    Caller must skip state write but may still emit advisory output.
    """
    sid = (
        os.environ.get("DEVBREW_SPEC_DISTILL_SESSION_ID")
        or os.environ.get("CLAUDE_CODE_SESSION_ID")
        or (payload or {}).get("session_id")
    )
    if not sid:
        print(
            "[spec-distill] session_id unresolved (env+payload empty) — "
            "state write skipped, hook output retained",
            file=sys.stderr,
        )
        return None
    if not SESSION_PATTERN.match(sid):
        truncated = sid[:32] + ("..." if len(sid) > 32 else "")
        print(
            f"[spec-distill] session_id rejected by charset/length: '{truncated}'",
            file=sys.stderr,
        )
        return None
    return sid
```

- [ ] **Step 4: Run test, verify all 11 cases pass**

```bash
bash tests/test_session_id_resolution.sh
```

Expected: `PASSED: 11 cases`.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/hooks/state_path.py plugins/spec-distill/tests/test_session_id_resolution.sh
git commit -m "feat(spec-distill): resolve_session_id() helper + SESSION_PATTERN (AC1)"
```

---

## Task 3: AC12 — `cleanup_stale_states` deprecation with marker

**Files:** Modify `plugins/spec-distill/hooks/state_path.py`.

- [ ] **Step 1: Replace `cleanup_stale_states` function body with no-op + marker advisory**

Modify `plugins/spec-distill/hooks/state_path.py` — replace the existing `cleanup_stale_states` function (and PENDING_TTL_HOURS/FILE_TTL_DAYS constants if no longer used) with:

```python
DEPRECATION_MARKER = ".deprecation-cleanup-stale-states-v060"


def cleanup_stale_states(root: Path) -> None:
    """DEPRECATED v0.6.0 — kept for backward import compatibility.

    Real cleanup now handled by scripts/spec-distill-gc.py (TTL-GC) +
    hooks/session-end-cleanup.py (per-session). This function is no-op.
    Removed in v0.7.0.
    """
    if not root.exists():
        return
    marker = root / DEPRECATION_MARKER
    if marker.exists():
        return  # advisory already emitted in this state-root lifetime
    try:
        marker.write_text("")  # atomic touch; empty content
        print(
            "[spec-distill] cleanup_stale_states() is deprecated since v0.6.0 "
            "(no-op). Cleanup now handled by spec-distill-gc.py + "
            "session-end-cleanup.py. Function removed in v0.7.0.",
            file=sys.stderr,
        )
    except OSError as exc:
        # marker write failed — emit advisory anyway, accept duplicate noise
        print(
            f"[spec-distill] cleanup_stale_states deprecated (marker write failed: {exc})",
            file=sys.stderr,
        )
```

- [ ] **Step 2: Run existing `test_state_path.sh` to confirm import compat**

```bash
bash plugins/spec-distill/tests/test_state_path.sh
```

Expected: existing 2 cases (worktree main-repo resolve) still PASS.

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/hooks/state_path.py
git commit -m "feat(spec-distill): deprecate cleanup_stale_states with marker (AC12)"
```

---

## Task 4: AC4 — SessionEnd hook TDD (Phase 2, deliverable b)

**Files:**
- Create: `plugins/spec-distill/tests/test_session_end_cleanup.py`
- Create: `plugins/spec-distill/hooks/session-end-cleanup.py`

- [ ] **Step 1: Write failing test (8 cases)**

Create `plugins/spec-distill/tests/test_session_end_cleanup.py`:

```python
"""AC4 — SessionEnd hook cleanup contract."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOK = (Path(__file__).resolve().parent.parent / "hooks" / "session-end-cleanup.py").resolve()


def run_hook(payload: dict, env_extra: dict | None = None, cwd: str | None = None):
    env = {**os.environ}
    # purge inherited kill-switch from outer shell to avoid cross-test contamination
    for k in ("DEVBREW_DISABLE_SPEC_DISTILL", "DEVBREW_SKIP_HOOKS"):
        env.pop(k, None)
    if env_extra:
        env.update(env_extra)
    cp = subprocess.run(
        ["python3", str(HOOK)],
        input=json.dumps(payload) if payload is not None else "not-json",
        env=env, cwd=cwd, capture_output=True, text=True, timeout=10,
    )
    return cp.returncode, cp.stdout, cp.stderr


class SessionEndCleanupTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        # mimic git repo so state_path.state_root() resolves via git-common-dir → tmp
        subprocess.run(["git", "init", "-q"], cwd=self.tmp, check=True)
        self.sid = "abc12345"
        self.folder = Path(self.tmp) / ".claude" / "spec-distill" / self.sid
        self.folder.mkdir(parents=True)
        (self.folder / "state.local.md").write_text(f"---\nsession_id: {self.sid}\n---\n")

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_1_happy_path(self):
        rc, _, _ = run_hook({"session_id": self.sid, "cwd": self.tmp})
        self.assertEqual(rc, 0)
        self.assertFalse(self.folder.exists())

    def test_2_folder_absent(self):
        import shutil
        shutil.rmtree(self.folder)
        rc, _, _ = run_hook({"session_id": self.sid, "cwd": self.tmp})
        self.assertEqual(rc, 0)  # no-op, no error

    def test_3_json_decode_fail(self):
        rc, _, _ = run_hook(None)  # sends "not-json"
        self.assertEqual(rc, 0)  # silent skip
        self.assertTrue(self.folder.exists())  # untouched

    def test_4_session_id_missing(self):
        rc, _, _ = run_hook({"cwd": self.tmp})
        self.assertEqual(rc, 0)
        self.assertTrue(self.folder.exists())

    def test_5_charset_reject(self):
        rc, _, _ = run_hook({"session_id": "../evil", "cwd": self.tmp})
        self.assertEqual(rc, 0)
        self.assertTrue(self.folder.exists())

    def test_6_cwd_missing(self):
        rc, _, stderr = run_hook({"session_id": self.sid}, cwd=self.tmp)
        self.assertEqual(rc, 0)
        # process cwd fallback used → folder removed
        self.assertFalse(self.folder.exists())
        self.assertIn("missing 'cwd'", stderr)

    def test_7_global_killswitch(self):
        rc, _, _ = run_hook(
            {"session_id": self.sid, "cwd": self.tmp},
            env_extra={"DEVBREW_DISABLE_SPEC_DISTILL": "1"},
        )
        self.assertEqual(rc, 0)
        self.assertTrue(self.folder.exists())  # cleanup blocked

    def test_8_granular_killswitch(self):
        rc, _, _ = run_hook(
            {"session_id": self.sid, "cwd": self.tmp},
            env_extra={"DEVBREW_SKIP_HOOKS": "spec-distill:SessionEnd"},
        )
        self.assertEqual(rc, 0)
        self.assertTrue(self.folder.exists())


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test, verify fails (hook file not found)**

```bash
cd plugins/spec-distill/
python3 -m unittest tests.test_session_end_cleanup
```

Expected: FAIL with `FileNotFoundError` or all 8 tests fail (hook missing).

- [ ] **Step 3: Implement `hooks/session-end-cleanup.py`**

Create `plugins/spec-distill/hooks/session-end-cleanup.py`:

```python
#!/usr/bin/env python3
"""SessionEnd hook: deterministic per-session state cleanup.

Removes `.claude/spec-distill/<self-session>/` if it exists.
Path resolution uses spec-distill's git-aware state_root (worktree compat).
Best-effort: idempotent (no-op if missing), tolerant of permission errors.

Kill switches (CLAUDE.md "kill switch는 보안 컨트롤"):
  DEVBREW_DISABLE_SPEC_DISTILL=1                       - disables entirely
  DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd           - skip just this one
"""
from __future__ import annotations

import json
import os
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from state_path import state_root, SESSION_PATTERN  # noqa: E402


def _disabled() -> bool:
    if os.environ.get("DEVBREW_DISABLE_SPEC_DISTILL") == "1":
        return True
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    tokens = {t.strip() for t in skip.split(",") if t.strip()}
    return "spec-distill:SessionEnd" in tokens


def main() -> int:
    if _disabled():
        return 0
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        return 0
    session_id = payload.get("session_id", "")
    if not session_id or not SESSION_PATTERN.match(session_id):
        return 0
    cwd = payload.get("cwd")
    if not cwd:
        print(
            "[spec-distill] session-end-cleanup: payload missing 'cwd', "
            "falling back to process cwd",
            file=sys.stderr,
        )
        cwd = os.getcwd()
    folder = state_root(cwd) / session_id
    shutil.rmtree(folder, ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

Then `chmod +x`:

```bash
chmod 755 plugins/spec-distill/hooks/session-end-cleanup.py
```

- [ ] **Step 4: Run test, verify 8 cases pass**

```bash
python3 -m unittest tests.test_session_end_cleanup -v
```

Expected: `Ran 8 tests in ... OK`.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/hooks/session-end-cleanup.py plugins/spec-distill/tests/test_session_end_cleanup.py
git commit -m "feat(spec-distill): SessionEnd hook for deterministic cleanup (AC4)"
```

---

## Task 5: AC5 — TTL-GC script TDD (Phase 2, deliverable c)

**Files:**
- Create: `plugins/spec-distill/tests/test_gc.py`
- Create: `plugins/spec-distill/scripts/spec-distill-gc.py`

- [ ] **Step 1: Write failing test (12 cases)**

Create `plugins/spec-distill/tests/test_gc.py`:

```python
"""AC5 — TTL-GC contract (qg-gc.py pattern adaptation + .gc-pending-* orphan sweep)."""
import os
import re
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

GC = (Path(__file__).resolve().parent.parent / "scripts" / "spec-distill-gc.py").resolve()


def run_gc(env_extra: dict | None = None, cwd: str | None = None):
    env = {**os.environ}
    for k in ("DEVBREW_DISABLE_SPEC_DISTILL", "DEVBREW_SKIP_HOOKS",
              "DEVBREW_SPEC_DISTILL_TTL_HOURS", "DEVBREW_SPEC_DISTILL_GC_VERBOSE",
              "CLAUDE_CODE_SESSION_ID"):
        env.pop(k, None)
    if env_extra:
        env.update(env_extra)
    cp = subprocess.run(
        ["python3", str(GC)],
        env=env, cwd=cwd, capture_output=True, text=True, timeout=10,
    )
    return cp.returncode, cp.stdout, cp.stderr


class GcTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        subprocess.run(["git", "init", "-q"], cwd=self.tmp, check=True)
        self.root = Path(self.tmp) / ".claude" / "spec-distill"
        self.root.mkdir(parents=True)

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _make_session(self, sid: str, age_seconds: int):
        d = self.root / sid
        d.mkdir()
        f = d / "state.local.md"
        f.write_text(f"---\nsession_id: {sid}\n---\n")
        past = time.time() - age_seconds
        os.utime(f, (past, past))
        return d

    def test_1_ttl_not_reached(self):
        d = self._make_session("abc12345", 3600)  # 1h, under 24h TTL
        run_gc(cwd=self.tmp)
        self.assertTrue(d.exists())

    def test_2_ttl_reached(self):
        d = self._make_session("abc12345", 25 * 3600)  # 25h
        run_gc(cwd=self.tmp)
        self.assertFalse(d.exists())

    def test_3_self_protection(self):
        d = self._make_session("self1234", 25 * 3600)
        run_gc(env_extra={"CLAUDE_CODE_SESSION_ID": "self1234"}, cwd=self.tmp)
        self.assertTrue(d.exists())

    def test_4_grace_window(self):
        d = self.root / "young123"
        d.mkdir()  # empty folder
        # ctime within 60s grace
        run_gc(cwd=self.tmp)
        self.assertTrue(d.exists())

    def test_5_charset_filter(self):
        # .gc-pending-* and bad-charset dirs are skipped from iteration
        bad = self.root / "with.dot"
        bad.mkdir()
        (bad / "state.local.md").write_text("x")
        past = time.time() - 25 * 3600
        os.utime(bad / "state.local.md", (past, past))
        run_gc(cwd=self.tmp)
        self.assertTrue(bad.exists())  # not GC'd (charset reject)

    def test_6_ttl_override(self):
        d = self._make_session("abc12345", 2 * 3600)  # 2h
        run_gc(env_extra={"DEVBREW_SPEC_DISTILL_TTL_HOURS": "1"}, cwd=self.tmp)
        self.assertFalse(d.exists())

    def test_7_global_killswitch(self):
        d = self._make_session("abc12345", 25 * 3600)
        run_gc(env_extra={"DEVBREW_DISABLE_SPEC_DISTILL": "1"}, cwd=self.tmp)
        self.assertTrue(d.exists())

    def test_8_verbose(self):
        self._make_session("abc12345", 25 * 3600)
        rc, stdout, _ = run_gc(
            env_extra={"DEVBREW_SPEC_DISTILL_GC_VERBOSE": "1"}, cwd=self.tmp,
        )
        self.assertEqual(rc, 0)
        self.assertIn("removed", stdout)

    def test_9_empty_root(self):
        # no sessions, just root
        rc, _, _ = run_gc(cwd=self.tmp)
        self.assertEqual(rc, 0)

    def test_10_root_absent(self):
        import shutil
        shutil.rmtree(self.root)
        rc, _, _ = run_gc(cwd=self.tmp)
        self.assertEqual(rc, 0)

    def test_11_gc_pending_orphan_sweep(self):
        # leftover .gc-pending-<uuid> from prior timeout-aborted GC
        orphan = self.root / ".gc-pending-deadbeefcafe"
        orphan.mkdir()
        (orphan / "state.local.md").write_text("x")
        past = time.time() - 120  # 2 min old (> 60s sweep threshold)
        os.utime(orphan, (past, past))
        run_gc(cwd=self.tmp)
        self.assertFalse(orphan.exists())  # swept

    def test_12_gc_pending_within_grace(self):
        # .gc-pending-* freshly created (< 60s) should NOT be swept
        recent = self.root / ".gc-pending-freshone"
        recent.mkdir()
        run_gc(cwd=self.tmp)
        self.assertTrue(recent.exists())  # within grace


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test, verify fails (script missing)**

```bash
python3 -m unittest tests.test_gc
```

Expected: 12 failures, file not found.

- [ ] **Step 3: Implement `scripts/spec-distill-gc.py`**

Create `plugins/spec-distill/scripts/spec-distill-gc.py`:

```python
#!/usr/bin/env python3
"""TTL-based GC for spec-distill per-session state folders.

qg-gc.py pattern adaptation:
  - race guard: fcntl lock + double-stat ns + rename-then-rmtree (3-layer)
  - 24h TTL (DEVBREW_SPEC_DISTILL_TTL_HOURS override)
  - self-session protection via CLAUDE_CODE_SESSION_ID or --session-id
  - grace window (60s) for newly-created empty folders
  - ROOT resolved dynamically via state_path.state_root() (worktree compat)
  - .gc-pending-* orphan sweep (>60s) at iteration start

Kill switches:
  DEVBREW_DISABLE_SPEC_DISTILL=1     - no-op
  DEVBREW_SKIP_HOOKS not honored here (script, not hook)
"""
from __future__ import annotations

import fcntl
import os
import re
import shutil
import sys
import time
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent / "hooks"
sys.path.insert(0, str(HERE))
from state_path import state_root, SESSION_PATTERN  # noqa: E402

LOCK_NAME = ".gc.lock"
GRACE_NS = 60 * 1_000_000_000
DOUBLE_STAT_DELAY_S = 0.05
GC_PENDING_PREFIX = ".gc-pending-"
GC_PENDING_SWEEP_AGE_S = 60


def _disabled() -> bool:
    return os.environ.get("DEVBREW_DISABLE_SPEC_DISTILL") == "1"


def _ttl_ns() -> int:
    raw = os.environ.get("DEVBREW_SPEC_DISTILL_TTL_HOURS", "24")
    try:
        n = int(raw)
        if n <= 0:
            n = 24
    except ValueError:
        n = 24
    return n * 3600 * 1_000_000_000


def _verbose() -> bool:
    return os.environ.get("DEVBREW_SPEC_DISTILL_GC_VERBOSE") == "1"


def _folder_mtime_ns(folder: Path) -> int:
    files = [p for p in folder.iterdir() if p.is_file()]
    if not files:
        return folder.stat().st_mtime_ns
    return max(p.stat().st_mtime_ns for p in files)


def _within_grace(folder: Path) -> bool:
    try:
        has_files = any(p.is_file() for p in folder.iterdir())
    except OSError:
        return False
    if has_files:
        return False
    age_ns = time.time_ns() - folder.stat().st_ctime_ns
    return age_ns < GRACE_NS


def _sweep_gc_pending(root: Path) -> int:
    """Remove leftover .gc-pending-<uuid> folders older than 60s.

    Defends against qg-gc.py's known edge: timeout-aborted rename mid-rmtree
    leaves .gc-pending-* orphans because SESSION_PATTERN rejects the name.
    """
    removed = 0
    now = time.time()
    for child in root.iterdir():
        if not child.is_dir():
            continue
        if not child.name.startswith(GC_PENDING_PREFIX):
            continue
        try:
            age = now - child.stat().st_ctime
        except OSError:
            continue
        if age < GC_PENDING_SWEEP_AGE_S:
            continue
        shutil.rmtree(child, ignore_errors=True)
        removed += 1
    return removed


def _gc_one(folder: Path, ttl_ns: int) -> bool:
    if _within_grace(folder):
        return False
    try:
        snap1 = _folder_mtime_ns(folder)
    except OSError:
        return False
    if time.time_ns() - snap1 < ttl_ns:
        return False
    time.sleep(DOUBLE_STAT_DELAY_S)
    try:
        snap2 = _folder_mtime_ns(folder)
    except OSError:
        return False
    if snap1 != snap2:
        return False
    pending = folder.parent / f"{GC_PENDING_PREFIX}{uuid.uuid4().hex}"
    try:
        folder.rename(pending)
    except OSError:
        return False
    shutil.rmtree(pending, ignore_errors=True)
    return True


def gc(self_session_id: str | None = None) -> int:
    if _disabled():
        return 0
    root = state_root()
    if not root.exists():
        return 0
    lock_path = root / LOCK_NAME
    try:
        lock_path.touch(exist_ok=True)
    except OSError:
        return 0
    ttl_ns = _ttl_ns()
    removed = 0
    with open(lock_path, "w") as lockfile:
        try:
            fcntl.flock(lockfile.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except (BlockingIOError, OSError):
            return 0
        try:
            removed += _sweep_gc_pending(root)
            for child in root.iterdir():
                if not child.is_dir():
                    continue
                if not SESSION_PATTERN.match(child.name):
                    continue
                if self_session_id and child.name == self_session_id:
                    continue
                try:
                    if _gc_one(child, ttl_ns):
                        removed += 1
                except OSError as exc:
                    print(
                        f"[spec-distill] GC failed on {child.name}: {exc}",
                        file=sys.stderr,
                    )
        finally:
            try:
                fcntl.flock(lockfile.fileno(), fcntl.LOCK_UN)
            except OSError:
                pass
    if _verbose() and removed > 0:
        print(f"[spec-distill] GC: removed {removed} stale folder(s)")
    return removed


def main() -> int:
    self_id = os.environ.get("CLAUDE_CODE_SESSION_ID") or None
    args = sys.argv[1:]
    if "--session-id" in args:
        i = args.index("--session-id")
        if i + 1 < len(args):
            self_id = args[i + 1]
    gc(self_id)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

Then chmod:

```bash
chmod 755 plugins/spec-distill/scripts/spec-distill-gc.py
```

- [ ] **Step 4: Run test, verify 12 cases pass**

```bash
python3 -m unittest tests.test_gc -v
```

Expected: `Ran 12 tests in ... OK`.

- [ ] **Step 5: Verify SESSION_PATTERN alignment with qg**

```bash
diff <(grep -E '^SESSION_PATTERN = ' plugins/spec-distill/hooks/state_path.py) \
     <(grep -E '^SESSION_PATTERN = ' plugins/quality-gates/scripts/qg-gc.py)
```

Expected: exit 0 (lines identical regex literal).

- [ ] **Step 6: Commit**

```bash
git add plugins/spec-distill/scripts/spec-distill-gc.py plugins/spec-distill/tests/test_gc.py
git commit -m "feat(spec-distill): TTL-GC script with .gc-pending-* sweep (AC5)"
```

---

## Task 6: AC6 — approve_handoff.sh TDD (Phase 2, deliverable c cont.)

**Files:**
- Create: `plugins/spec-distill/tests/test_approve_handoff.sh`
- Create: `plugins/spec-distill/scripts/approve_handoff.sh`

- [ ] **Step 1: Write failing test (8 cases)**

Create `plugins/spec-distill/tests/test_approve_handoff.sh`:

```bash
#!/usr/bin/env bash
# AC6 — approve_handoff.sh contract.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$PLUGIN_DIR/scripts/approve_handoff.sh"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)); }

setup_repo() {
    local wd=$1
    mkdir -p "$wd/docs/superpowers/specs"
    cd "$wd"
    git init -q
    git config user.email test@x.invalid
    git config user.name test
    echo "# test" > "$wd/docs/superpowers/specs/2026-01-01-test-spec.md"
    git add . && git commit -q -m "init"
    mkdir -p "$wd/.claude/spec-distill/test-sid12"
    echo "state" > "$wd/.claude/spec-distill/test-sid12/state.local.md"
}

# Case 1: happy path
WORK=$(mktemp -d)
setup_repo "$WORK"
echo "modified" > "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>&1
rc=$?
[[ $rc -eq 0 && ! -d "$WORK/.claude/spec-distill/test-sid12" ]] \
    && note PASS "case 1: happy path (commit + cleanup)" \
    || note FAIL "case 1: rc=$rc folder_exists=$([[ -d $WORK/.claude/spec-distill/test-sid12 ]] && echo y || echo n)"
rm -rf "$WORK"

# Case 2: charset reject (cleanup_skipped)
WORK=$(mktemp -d)
setup_repo "$WORK"
mkdir -p "$WORK/.claude/spec-distill/..bad"
echo "modified" > "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
bash "$SCRIPT" "../bad" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>err
grep -q "cleanup skipped" err \
    && note PASS "case 2: charset reject emits advisory" \
    || note FAIL "case 2: missing cleanup-skipped advisory"
rm -rf "$WORK"

# Case 3: empty session_id arg
bash "$SCRIPT" "" "anything" >/dev/null 2>&1
[[ $? -ne 0 ]] \
    && note PASS "case 3: empty session_id rejected" \
    || note FAIL "case 3: empty session_id accepted"

# Case 4: empty spec_path arg
bash "$SCRIPT" "test-sid12" "" >/dev/null 2>&1
[[ $? -ne 0 ]] \
    && note PASS "case 4: empty spec_path rejected" \
    || note FAIL "case 4: empty spec_path accepted"

# Case 5: git commit fail (no spec edit → 'nothing to commit')
WORK=$(mktemp -d)
setup_repo "$WORK"
# don't modify spec → git commit will fail "nothing to commit"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>&1
rc=$?
[[ $rc -ne 0 && -d "$WORK/.claude/spec-distill/test-sid12" ]] \
    && note PASS "case 5: commit fail preserves state" \
    || note FAIL "case 5: rc=$rc, state lost"
rm -rf "$WORK"

# Case 6: rm permission fail (skip if root or limited platform)
if [[ $(id -u) -ne 0 ]]; then
    WORK=$(mktemp -d)
    setup_repo "$WORK"
    chmod 555 "$WORK/.claude/spec-distill"  # parent read-only
    echo "modified" > "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
    bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>err
    grep -q "cleanup rm failed" err \
        && note PASS "case 6: rm fail emits advisory but exits 0" \
        || note FAIL "case 6: missing rm-fail advisory"
    chmod 755 "$WORK/.claude/spec-distill"
    rm -rf "$WORK"
else
    note PASS "case 6: skipped (running as root)"
fi

# Case 7: idempotent re-run (second call → already committed)
WORK=$(mktemp -d)
setup_repo "$WORK"
echo "modified" > "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>&1
# folder already gone; second call should still fail because git has nothing to commit
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>&1
[[ $? -ne 0 ]] \
    && note PASS "case 7: idempotent re-run fails (already committed)" \
    || note FAIL "case 7: re-run silently succeeded"
rm -rf "$WORK"

# Case 8: folder pre-deleted (SessionEnd preceded)
WORK=$(mktemp -d)
setup_repo "$WORK"
rm -rf "$WORK/.claude/spec-distill/test-sid12"
echo "modified" > "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>&1
rc=$?
[[ $rc -eq 0 ]] \
    && note PASS "case 8: folder pre-deleted graceful" \
    || note FAIL "case 8: rc=$rc on absent folder"
rm -rf "$WORK"

if [[ "$fail" -gt 0 ]]; then
    echo "FAILED: $fail case(s)"
    exit 1
fi
echo "PASSED: 8 cases"
```

- [ ] **Step 2: Run test, verify fails (script missing)**

```bash
bash tests/test_approve_handoff.sh
```

Expected: FAIL (8 cases or "command not found").

- [ ] **Step 3: Implement `scripts/approve_handoff.sh`**

Create `plugins/spec-distill/scripts/approve_handoff.sh`:

```bash
#!/usr/bin/env bash
# spec-distill v0.6.0 — AC11 atomic approve handoff (script-ified from prose).
# Usage: approve_handoff.sh <session_id> <spec_path>
set -euo pipefail

session_id="${1:?usage: approve_handoff.sh <session_id> <spec_path>}"
spec_path="${2:?usage: approve_handoff.sh <session_id> <spec_path>}"

# session_id charset guard (defense in depth — state_path.SESSION_PATTERN equivalent)
case "$session_id" in
    ''|*[!A-Za-z0-9_-]*)
        echo "[spec-distill] approve_handoff: cleanup skipped — invalid session_id '${session_id:-<empty>}'" >&2
        cleanup_skipped=1
        ;;
    *)
        # also enforce min length 8 to match SESSION_PATTERN
        if [[ ${#session_id} -lt 8 ]]; then
            echo "[spec-distill] approve_handoff: cleanup skipped — session_id length < 8" >&2
            cleanup_skipped=1
        else
            cleanup_skipped=0
        fi
        ;;
esac

# Step 1: commit
git add -- "$spec_path"
if ! git commit -m "spec: $(basename "${spec_path%-spec.md}" | sed 's/^[0-9-]*//') (v1.0.0, spec-distill v0.6.0)"; then
    echo "[spec-distill] commit failed — state preserved, 사용자 수동 개입 필요" >&2
    exit 1
fi

# Step 2: handoff pointer
echo "Spec lock 완료. 다음 단계:"
echo "  Skill superpowers:writing-plans $spec_path"

# Step 3: state cleanup (charset-guarded, race-tolerant)
if [[ "$cleanup_skipped" == "0" ]]; then
    if ! rm -rf -- ".claude/spec-distill/$session_id/" 2>/dev/null; then
        echo "[spec-distill] cleanup rm failed (non-fatal) — SessionEnd hook will retry" >&2
    fi
fi || true

# Step 4: termination notice
echo "spec-distill v0.6.0 종료."
```

```bash
chmod 755 plugins/spec-distill/scripts/approve_handoff.sh
```

- [ ] **Step 4: Run test, verify 8 cases pass**

```bash
bash tests/test_approve_handoff.sh
```

Expected: `PASSED: 8 cases`.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/scripts/approve_handoff.sh plugins/spec-distill/tests/test_approve_handoff.sh
git commit -m "feat(spec-distill): approve_handoff.sh atomic script (AC6, AC7 prereq)"
```

---

## Task 7: AC2, AC8, AC14 — modify spec-write-validator.py (Phase 3)

**Files:**
- Modify: `plugins/spec-distill/hooks/spec-write-validator.py`
- Create: `plugins/spec-distill/tests/test_stale_state_truncate.sh`

- [ ] **Step 1: Write failing test for defensive truncate (4 cases)**

Create `plugins/spec-distill/tests/test_stale_state_truncate.sh`:

```bash
#!/usr/bin/env bash
# AC8 — write_state defensive truncate when frontmatter session_id ≠ current.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$PLUGIN_DIR/hooks/spec-write-validator.py"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)); }

run_validator() {
    local wd=$1 sid=$2 file=$3
    cd "$wd"
    printf '{"tool_name":"Write","tool_input":{"file_path":"%s"},"session_id":"%s"}' "$file" "$sid" \
        | env -u DEVBREW_SPEC_DISTILL_SESSION_ID python3 "$HOOK" >/dev/null 2>&1
}

# Case 1: stale session_id → truncate
WORK=$(mktemp -d)
cd "$WORK" && git init -q
mkdir -p docs/superpowers/specs .claude/spec-distill/new-sid12345
cat > .claude/spec-distill/new-sid12345/state.local.md <<EOF
---
session_id: old-sid67890
phase: 3
---
stale body content
EOF
echo "spec body" > docs/superpowers/specs/2026-05-19-test-spec.md
run_validator "$WORK" "new-sid12345" "$WORK/docs/superpowers/specs/2026-05-19-test-spec.md"
grep -q "session_id: new-sid12345" "$WORK/.claude/spec-distill/new-sid12345/state.local.md" \
    && ! grep -q "stale body content" "$WORK/.claude/spec-distill/new-sid12345/state.local.md" \
    && note PASS "case 1: stale session_id → truncate" \
    || note FAIL "case 1: truncate did not occur"
rm -rf "$WORK"

# Case 2: matching session_id → append (no truncate)
WORK=$(mktemp -d)
cd "$WORK" && git init -q
mkdir -p docs/superpowers/specs .claude/spec-distill/same-sid12345
cat > .claude/spec-distill/same-sid12345/state.local.md <<EOF
---
session_id: same-sid12345
---
existing body
EOF
echo "spec body" > docs/superpowers/specs/2026-05-19-test-spec.md
run_validator "$WORK" "same-sid12345" "$WORK/docs/superpowers/specs/2026-05-19-test-spec.md"
grep -q "existing body" "$WORK/.claude/spec-distill/same-sid12345/state.local.md" \
    && note PASS "case 2: matching session_id → append preserves body" \
    || note FAIL "case 2: body lost"
rm -rf "$WORK"

# Case 3: no frontmatter (free-form body) → append path
WORK=$(mktemp -d)
cd "$WORK" && git init -q
mkdir -p docs/superpowers/specs .claude/spec-distill/no-fm12345
echo "free-form body only" > .claude/spec-distill/no-fm12345/state.local.md
echo "spec" > docs/superpowers/specs/2026-05-19-test-spec.md
run_validator "$WORK" "no-fm12345" "$WORK/docs/superpowers/specs/2026-05-19-test-spec.md"
grep -q "free-form body only" "$WORK/.claude/spec-distill/no-fm12345/state.local.md" \
    && note PASS "case 3: no frontmatter → backward compat" \
    || note FAIL "case 3: body lost"
rm -rf "$WORK"

# Case 4: unreadable state file → preserve (no overwrite)
WORK=$(mktemp -d)
cd "$WORK" && git init -q
mkdir -p docs/superpowers/specs .claude/spec-distill/unread12345
printf '\x00\x01\x02 binary garbage' > .claude/spec-distill/unread12345/state.local.md
chmod 000 .claude/spec-distill/unread12345/state.local.md
echo "spec" > docs/superpowers/specs/2026-05-19-test-spec.md
run_validator "$WORK" "unread12345" "$WORK/docs/superpowers/specs/2026-05-19-test-spec.md"
# verify file untouched (still 000, still ~26 bytes)
chmod 644 .claude/spec-distill/unread12345/state.local.md
[[ $(wc -c < .claude/spec-distill/unread12345/state.local.md) -lt 100 ]] \
    && note PASS "case 4: unreadable → preserved" \
    || note FAIL "case 4: overwrote unreadable"
rm -rf "$WORK"

if [[ "$fail" -gt 0 ]]; then
    echo "FAILED: $fail case(s)"
    exit 1
fi
echo "PASSED: 4 cases"
```

- [ ] **Step 2: Modify `hooks/spec-write-validator.py` — session_id source + defensive truncate + AC14 legacy advisory**

Locate `write_state` function (currently lines 80-100) and replace:

```python
LEGACY_ADVISORY_MARKER = ".legacy-advisory-emitted-v060"


def _legacy_advisory_check(state_root_path: Path) -> None:
    """AC14 — emit one-shot advisory if `.claude/spec-distill/default/` exists."""
    legacy = state_root_path / "default"
    marker = state_root_path / LEGACY_ADVISORY_MARKER
    if not legacy.exists() or marker.exists():
        return
    try:
        state_root_path.mkdir(parents=True, exist_ok=True)
        marker.write_text("")
        print(
            "[spec-distill] v0.6.0 detected: .claude/spec-distill/default/ "
            "legacy folder, manual cleanup recommended (no auto-delete to "
            "preserve in-flight work — see CHANGELOG [0.6.0]).",
            file=sys.stderr,
        )
    except OSError as exc:
        print(
            f"[spec-distill] legacy advisory marker write failed: {exc}",
            file=sys.stderr,
        )


def write_state(session_id: str, path: str, mode: str, worktree_path: str) -> None:
    from state_path import state_root  # local import to avoid top-level side effects in tests
    state_dir = state_root() / session_id
    state_dir.mkdir(parents=True, exist_ok=True)
    _legacy_advisory_check(state_root())
    state_file = state_dir / "state.local.md"
    block = (
        "pending_review:\n"
        f"  path: {path}\n"
        f"  mode: {mode}\n"
        f"  worktree_path: {worktree_path}\n"
        f"  triggered_at: {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}\n"
    )
    if not state_file.exists():
        state_file.write_text(
            f"---\nsession_id: {session_id}\n---\n\n{block}", encoding="utf-8"
        )
        return
    # File exists — detect stale session_id (AC8 defensive truncate)
    try:
        body = state_file.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError) as exc:
        print(
            f"[spec-distill] state.local.md unreadable — preserving for debug: {exc}",
            file=sys.stderr,
        )
        return
    fm_match = re.search(r"^session_id:\s*([^\n]+)$", body, flags=re.MULTILINE)
    if fm_match and fm_match.group(1).strip() != session_id:
        old = fm_match.group(1).strip()
        print(
            f"[spec-distill] stale state detected (old sid={old[:32]}, "
            f"current={session_id[:32]}) — truncating",
            file=sys.stderr,
        )
        state_file.write_text(
            f"---\nsession_id: {session_id}\n---\n\n{block}", encoding="utf-8"
        )
        return
    # Matching session_id — strip pending_review block and append fresh
    body = re.sub(
        r"^pending_review:\n(?:  [^\n]*\n)*", "", body, flags=re.MULTILINE
    )
    state_file.write_text(body.rstrip() + "\n\n" + block, encoding="utf-8")
```

In the `main()` function, locate line 160 (session_id resolution) and replace:

```python
    # Pass → write state (unless Layer 2 disabled)
    if os.environ.get("DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW") != "1":
        from state_path import resolve_session_id
        session_id = resolve_session_id(payload)
        if session_id is not None:
            try:
                write_state(session_id, file_path, mode, os.getcwd())
            except (PermissionError, OSError) as exc:
                print(f"[spec-distill] state write failed (non-fatal): {exc}", file=sys.stderr)
```

- [ ] **Step 3: Run new test, verify 4 cases pass**

```bash
bash tests/test_stale_state_truncate.sh
```

Expected: `PASSED: 4 cases`.

- [ ] **Step 4: Run existing test_spec_write_validator.sh, verify still passes**

```bash
bash tests/test_spec_write_validator.sh
```

Expected: all existing cases PASS (env override path unchanged).

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/hooks/spec-write-validator.py plugins/spec-distill/tests/test_stale_state_truncate.sh
git commit -m "feat(spec-distill): spec-write-validator session_id source + defensive truncate + legacy advisory (AC2, AC8, AC14)"
```

---

## Task 8: AC2 — modify review-dispatch.py + pending-review-reminder.py (Phase 3 cont.)

**Files:**
- Modify: `plugins/spec-distill/hooks/review-dispatch.py`
- Modify: `plugins/spec-distill/hooks/pending-review-reminder.py`

- [ ] **Step 1: Modify `review-dispatch.py`**

Locate line 94 (`session_id = os.environ.get("DEVBREW_SPEC_DISTILL_SESSION_ID", "default")`) and line 91 (`cleanup_stale_states(_state_root())`). Replace:

```python
    # Replace cleanup_stale_states call with GC subprocess (best-effort)
    GC_SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "spec-distill-gc.py"
    try:
        subprocess.run(
            ["python3", str(GC_SCRIPT)],
            timeout=5, check=False, capture_output=True,
        )
    except (subprocess.TimeoutExpired, OSError) as exc:
        print(
            f"[spec-distill] gc fire-and-forget failed (non-fatal): {exc}",
            file=sys.stderr,
        )

    # Replace session_id source
    from state_path import resolve_session_id
    session_id = resolve_session_id(payload)
    if session_id is None:
        return 0  # graceful skip, advisory output preserved by caller
```

Also remove top-level `from state_path import ..., cleanup_stale_states` import — replace with `from state_path import state_root as _state_root` and `import subprocess`.

- [ ] **Step 2: Modify `pending-review-reminder.py`**

Same pattern as Step 1. Locate line 62 (session_id source) and line 73 (`cleanup_stale_states` call). Replace both with the same GC subprocess + `resolve_session_id` block.

- [ ] **Step 3: Run existing tests**

```bash
bash tests/test_review_dispatch.sh
bash tests/test_review_dispatch_design_mandate.sh
bash tests/test_reminder_hook.sh
```

Expected: all existing cases PASS (env override `DEVBREW_SPEC_DISTILL_SESSION_ID=<id>` still works via `resolve_session_id` precedence).

- [ ] **Step 4: Verify no `"default"` literal remains in production hooks**

```bash
! grep -rn '"default"' plugins/spec-distill/hooks/ --include="*.py"
```

Expected: exit 0 (zero matches).

- [ ] **Step 5: Verify `resolve_session_id` is called in all 3 hooks**

```bash
grep -l 'resolve_session_id' plugins/spec-distill/hooks/spec-write-validator.py \
    plugins/spec-distill/hooks/review-dispatch.py \
    plugins/spec-distill/hooks/pending-review-reminder.py
```

Expected: 3 file paths printed.

- [ ] **Step 6: Commit**

```bash
git add plugins/spec-distill/hooks/review-dispatch.py plugins/spec-distill/hooks/pending-review-reminder.py
git commit -m "feat(spec-distill): review-dispatch + reminder session_id source + GC subprocess (AC2)"
```

---

## Task 9: AC9 — brainstorming entry regression test

**Files:** Create `plugins/spec-distill/tests/test_brainstorming_entry.sh`.

- [ ] **Step 1: Write test (3 cases, strict sequential)**

Create `plugins/spec-distill/tests/test_brainstorming_entry.sh`:

```bash
#!/usr/bin/env bash
# AC9 — brainstorming entry (no /interview): hook fires + cleanup works.
# strict sequential: (i) → (ii) → (iii).
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WRITE="$PLUGIN_DIR/hooks/spec-write-validator.py"
END="$PLUGIN_DIR/hooks/session-end-cleanup.py"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
mkdir -p docs/superpowers/specs

SID="brainstorm-12345678"
SPEC="$WORK/docs/superpowers/specs/2026-05-19-test-design.md"
echo "design body" > "$SPEC"

# (i) Setup — PostToolUse hook writes state.local.md
printf '{"tool_name":"Write","tool_input":{"file_path":"%s"},"session_id":"%s"}' "$SPEC" "$SID" \
    | env -u DEVBREW_SPEC_DISTILL_SESSION_ID python3 "$WRITE" >/dev/null 2>&1

STATE="$WORK/.claude/spec-distill/$SID/state.local.md"
[[ -f "$STATE" ]] || { echo "[FAIL] case i: state not created"; exit 1; }
grep -q "session_id: $SID" "$STATE" \
    && echo "[PASS] case i: state.local.md created with session_id=$SID" \
    || { echo "[FAIL] case i: session_id frontmatter wrong"; exit 1; }

# (ii) Assertion — no "default" literal anywhere in state
! grep -q 'default' "$STATE" \
    && echo "[PASS] case ii: 'default' literal absent from state" \
    || { echo "[FAIL] case ii: 'default' literal present"; exit 1; }

# (iii) Cleanup verification — SessionEnd hook removes folder
printf '{"session_id":"%s","cwd":"%s"}' "$SID" "$WORK" \
    | python3 "$END" >/dev/null 2>&1

[[ ! -d "$WORK/.claude/spec-distill/$SID" ]] \
    && echo "[PASS] case iii: SessionEnd cleanup removed folder" \
    || { echo "[FAIL] case iii: folder still exists"; exit 1; }

echo "PASSED: 3 cases sequential"
```

- [ ] **Step 2: Run test, verify all 3 cases pass**

```bash
bash tests/test_brainstorming_entry.sh
```

Expected: `PASSED: 3 cases sequential`.

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/tests/test_brainstorming_entry.sh
git commit -m "test(spec-distill): brainstorming entry regression guard (AC9)"
```

---

## Task 10: AC10 — kill switch matrix test

**Files:** Create `plugins/spec-distill/tests/test_kill_switches_v060.sh`.

- [ ] **Step 1: Write test (6 cases)**

Create `plugins/spec-distill/tests/test_kill_switches_v060.sh`:

```bash
#!/usr/bin/env bash
# AC10 — v0.6.0 kill switch matrix across new hooks/scripts.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)); }

# Setup tmp env
WORK=$(mktemp -d)
cd "$WORK" && git init -q
mkdir -p .claude/spec-distill/kill-test-12345
echo "x" > .claude/spec-distill/kill-test-12345/state.local.md

# Case 1: global DEVBREW_DISABLE_SPEC_DISTILL=1 blocks SessionEnd
printf '{"session_id":"kill-test-12345","cwd":"%s"}' "$WORK" \
    | env DEVBREW_DISABLE_SPEC_DISTILL=1 python3 "$PLUGIN_DIR/hooks/session-end-cleanup.py" >/dev/null
[[ -d .claude/spec-distill/kill-test-12345 ]] \
    && note PASS "case 1: global kill switch blocks SessionEnd" \
    || note FAIL "case 1: SessionEnd fired despite kill switch"

# Case 2: global kill switch blocks GC
mkdir -p .claude/spec-distill/old-12345678
echo "x" > .claude/spec-distill/old-12345678/state.local.md
past=$(($(date +%s) - 90000))
touch -d "@$past" .claude/spec-distill/old-12345678/state.local.md 2>/dev/null \
    || python3 -c "import os; os.utime('.claude/spec-distill/old-12345678/state.local.md', ($past, $past))"
env DEVBREW_DISABLE_SPEC_DISTILL=1 python3 "$PLUGIN_DIR/scripts/spec-distill-gc.py" >/dev/null
[[ -d .claude/spec-distill/old-12345678 ]] \
    && note PASS "case 2: global kill switch blocks GC" \
    || note FAIL "case 2: GC fired despite kill switch"

# Case 3: granular DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd
printf '{"session_id":"kill-test-12345","cwd":"%s"}' "$WORK" \
    | env DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd python3 "$PLUGIN_DIR/hooks/session-end-cleanup.py" >/dev/null
[[ -d .claude/spec-distill/kill-test-12345 ]] \
    && note PASS "case 3: granular kill switch blocks SessionEnd" \
    || note FAIL "case 3: SessionEnd fired despite granular"

# Case 4: CSV multi-kill DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd,other:event
printf '{"session_id":"kill-test-12345","cwd":"%s"}' "$WORK" \
    | env DEVBREW_SKIP_HOOKS="spec-distill:SessionEnd,quality-gates:Stop" \
        python3 "$PLUGIN_DIR/hooks/session-end-cleanup.py" >/dev/null
[[ -d .claude/spec-distill/kill-test-12345 ]] \
    && note PASS "case 4: CSV granular kill blocks correct hook" \
    || note FAIL "case 4: CSV granular failed"

# Case 5: DEVBREW_SKIP_HOOKS=quality-gates:SessionEnd does NOT affect spec-distill
printf '{"session_id":"kill-test-12345","cwd":"%s"}' "$WORK" \
    | env DEVBREW_SKIP_HOOKS="quality-gates:SessionEnd" \
        python3 "$PLUGIN_DIR/hooks/session-end-cleanup.py" >/dev/null
[[ ! -d .claude/spec-distill/kill-test-12345 ]] \
    && note PASS "case 5: cross-plugin kill switch ignored" \
    || note FAIL "case 5: cross-plugin kill switch leaked"

# Re-create folder for next case
mkdir -p .claude/spec-distill/kill-test-12345
echo "x" > .claude/spec-distill/kill-test-12345/state.local.md

# Case 6: TTL override DEVBREW_SPEC_DISTILL_TTL_HOURS
mkdir -p .claude/spec-distill/ttl-12345678
echo "x" > .claude/spec-distill/ttl-12345678/state.local.md
past=$(($(date +%s) - 7200))  # 2h old
python3 -c "import os; os.utime('.claude/spec-distill/ttl-12345678/state.local.md', ($past, $past))"
env DEVBREW_SPEC_DISTILL_TTL_HOURS=1 python3 "$PLUGIN_DIR/scripts/spec-distill-gc.py" >/dev/null
[[ ! -d .claude/spec-distill/ttl-12345678 ]] \
    && note PASS "case 6: TTL override removes 2h-old folder" \
    || note FAIL "case 6: TTL override failed"

rm -rf "$WORK"

if [[ "$fail" -gt 0 ]]; then
    echo "FAILED: $fail case(s)"
    exit 1
fi
echo "PASSED: 6 cases"
```

- [ ] **Step 2: Run test, verify 6 cases pass**

```bash
bash tests/test_kill_switches_v060.sh
```

Expected: `PASSED: 6 cases`.

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/tests/test_kill_switches_v060.sh
git commit -m "test(spec-distill): v0.6.0 kill switch matrix (AC10)"
```

---

## Task 11: AC7 — hooks.json + SKILL.md AC11 simplification (Phase 4)

**Files:**
- Modify: `plugins/spec-distill/hooks/hooks.json`
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md`

- [ ] **Step 1: Edit `hooks/hooks.json` to add SessionEnd event**

Modify `plugins/spec-distill/hooks/hooks.json` — add SessionEnd block before the closing `}` of `hooks`:

```json
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/session-end-cleanup.py",
            "timeout": 10
          }
        ]
      }
    ]
```

Make sure to add a comma after the preceding `"Stop": [ ... ]` block. Also update the top-level `"description"`:

```json
"description": "spec-distill — UserPromptSubmit interview + reminder, SessionStart anchor, PostToolUse spec/design validator, Stop reviewer dispatch, SessionEnd cleanup."
```

- [ ] **Step 2: Edit `skills/reviewing-spec/SKILL.md` AC11 section**

Locate `## Approve handoff sequence (AC11)` section. Replace the 4-step shell snippet block + "polite stop 금지" + "실패 시 state 보존" subsections with:

```markdown
## Approve handoff sequence (AC11)

사용자 "approve" 선택 시:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/approve_handoff.sh" \
  "$session_id" "$spec_path"
```

스크립트가 4-step (commit / handoff pointer / cleanup / termination) atomic 실행. session_id charset guard 내장 — invalid 시 cleanup skip + advisory. commit 실패 시 state.local.md 보존, exit 1.

**polite stop 금지** (AP2): "approved!"만 narrate하고 스크립트 호출 skip 금지. SessionEnd hook이 backup cleanup이지만 user-explicit "approve" 의도는 즉시 반영.

### 실패 시 state 보존 (P14)

approve_handoff.sh가 commit 실패 시 exit 1 + state.local.md 보존. cleanup rm 실패는 advisory only — SessionEnd hook이 재시도.
```

- [ ] **Step 3: Run AC7 three-grep verification**

```bash
# (i) 4-step cleanup line removed
test "$(grep -c 'rm -rf -- ".claude/spec-distill' plugins/spec-distill/skills/reviewing-spec/SKILL.md)" -eq 0
# (ii) approve_handoff.sh referenced
test "$(grep -c 'approve_handoff.sh' plugins/spec-distill/skills/reviewing-spec/SKILL.md)" -ge 1
# (iii) script called with both args
grep -E 'approve_handoff\.sh[^\n]+\$\{?session_id\}?[^\n]+\$\{?spec_path\}?' \
    plugins/spec-distill/skills/reviewing-spec/SKILL.md >/dev/null
```

Expected: all three exit 0.

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/hooks/hooks.json plugins/spec-distill/skills/reviewing-spec/SKILL.md
git commit -m "feat(spec-distill): register SessionEnd + AC11 prose → script call (AC7)"
```

---

## Task 12: AC11 — plugin.json + CHANGELOG + README sync (Phase 4 cont.)

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`
- Modify: `plugins/spec-distill/CHANGELOG.md`
- Modify: `plugins/spec-distill/README.md`

- [ ] **Step 1: Bump `plugin.json` version**

Modify `plugins/spec-distill/.claude-plugin/plugin.json`:

```json
{
  "name": "spec-distill",
  "description": "집요한 인터뷰로 모호함을 명확함으로 변환해 superpowers 호환 spec.md를 생성. devbrew Laws 1+2 instantiation (Writer/Reviewer 물리적 분리, 4-block Korean Socratic interview).",
  "version": "0.6.0",
  "author": {
    "name": "jeonghokim"
  }
}
```

- [ ] **Step 2: Add `CHANGELOG.md` entry**

Prepend the following section to `plugins/spec-distill/CHANGELOG.md` (after the top header line):

```markdown
## [0.6.0] — 2026-05-19

### Added
- `hooks/session-end-cleanup.py` — SessionEnd hook for deterministic per-session state cleanup (qg pattern adaptation, git-aware path).
- `scripts/spec-distill-gc.py` — TTL-based GC (24h) with fcntl lock + double-stat ns + rename-then-rmtree race guard. `.gc-pending-*` orphan sweep (>60s) on each invocation.
- `scripts/approve_handoff.sh` — atomic AC11 approve handoff (4-step: commit / handoff pointer / cleanup / termination). Extracted from `skills/reviewing-spec/SKILL.md` prose.
- `hooks/state_path.py`:`resolve_session_id(payload)` + `SESSION_PATTERN` — single source of truth for session_id, charset/length validation.
- 7 new tests: `test_session_id_resolution.sh`, `test_session_end_cleanup.py`, `test_gc.py`, `test_approve_handoff.sh`, `test_stale_state_truncate.sh`, `test_brainstorming_entry.sh`, `test_kill_switches_v060.sh`.

### Changed
- `hooks/spec-write-validator.py`, `hooks/review-dispatch.py`, `hooks/pending-review-reminder.py` — session_id source switched from `os.environ.get("DEVBREW_SPEC_DISTILL_SESSION_ID", "default")` literal fallback to `resolve_session_id(payload)`. Production now resolves from `CLAUDE_CODE_SESSION_ID`. `DEVBREW_SPEC_DISTILL_SESSION_ID` retained as test override.
- `hooks/spec-write-validator.py`:`write_state` — defensive truncate when existing state.local.md frontmatter `session_id` ≠ current (defense-in-depth).
- `hooks/spec-write-validator.py` — AC14 legacy advisory: detect `.claude/spec-distill/default/` and emit one-shot stderr advisory (marker `.legacy-advisory-emitted-v060`).
- `hooks/hooks.json` — SessionEnd event registered.
- `skills/reviewing-spec/SKILL.md` — AC11 4-step prose replaced with 1-line `approve_handoff.sh` script call.

### Deprecated
- `hooks/state_path.py`:`cleanup_stale_states` — no-op + marker-based one-shot deprecation stderr. Removed in v0.7.0.

### Fixed
- 잔여 frontmatter bug (사용자 보고 2026-05-19): `.claude/spec-distill/default/state.local.md`에 이전 세션의 frontmatter가 누적되어 새 세션이 stale data 위에 쓰는 증상. Root cause: `DEVBREW_SPEC_DISTILL_SESSION_ID` 부재 시 모든 hook이 `"default"` literal로 fallback → singleton file 공유. Fix: `CLAUDE_CODE_SESSION_ID` 단일 source + SessionEnd hook + TTL-GC + write_state defensive truncate (4-layer defense).

### Security
- session_id charset validation `^[A-Za-z0-9_-]{8,}$` 모든 cleanup path (SessionEnd hook, TTL-GC, approve_handoff.sh, write_state)에 적용 — `../traversal` 등 path injection 차단.
```

- [ ] **Step 3: Update `README.md` Hooks Installed + Principles Instantiated**

Locate the "Hooks Installed" section in `plugins/spec-distill/README.md`. Add SessionEnd line:

```markdown
- **SessionEnd** (`hooks/session-end-cleanup.py`): deterministic per-session `.claude/spec-distill/<sid>/` cleanup. 왜 skill이 아닌가: Claude lifecycle 이벤트는 hook이 catch해야 함. polite-stop이나 approve 누락 시에도 cleanup 보장 (4-layer defense의 layer 2).
```

Locate "Principles Instantiated" section. Add:

```markdown
- **Law 2 — load-bearing cleanup is code, not prose**: AC11 approve handoff을 SKILL.md prose에서 `scripts/approve_handoff.sh`로 추출. Reviewer가 prose를 narrate만 하고 cleanup skip하는 polite-stop 회피의 인프라적 강제.
- **P3 — graceful degradation with loud logging**: `resolve_session_id` 검증 실패 시 None 반환 + stderr advisory, advisory hook output은 유지. cleanup 실패 시 silent skip (SessionEnd) 또는 advisory (approve_handoff) — 사용자 attention 가용성에 따라 loud 정도 조정.
- **P14 — failure-time state preservation**: `write_state`가 stale-session 검출 시 *명시적* truncate (정상 케이스), 그러나 unreadable file은 보존 (failure preservation). TTL-GC도 self-session 보호 + grace window로 in-flight data 보호.
```

- [ ] **Step 4: Commit**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/spec-distill/README.md
git commit -m "chore(spec-distill): v0.5.1 → v0.6.0 bump + CHANGELOG + README sync (AC11)"
```

---

## Task 13: AC13 — Full test matrix verification

**Files:** none modified (verification only).

- [ ] **Step 1: Run all 7 new tests**

```bash
cd plugins/spec-distill/
bash tests/test_session_id_resolution.sh
python3 -m unittest tests.test_session_end_cleanup
python3 -m unittest tests.test_gc
bash tests/test_approve_handoff.sh
bash tests/test_stale_state_truncate.sh
bash tests/test_brainstorming_entry.sh
bash tests/test_kill_switches_v060.sh
```

Expected: all 7 PASS (totals: 11 + 8 + 12 + 8 + 4 + 3 + 6 = 52 cases).

- [ ] **Step 2: Run all 7 existing tests (AC13 ground truth list)**

```bash
bash tests/test_state_path.sh
bash tests/test_spec_write_validator.sh
bash tests/test_review_dispatch.sh
bash tests/test_reminder_hook.sh
bash tests/test_design_mode_validator.sh
bash tests/test_review_dispatch_design_mandate.sh
python3 -m unittest tests.test_hook_output_schema
```

Expected: all 7 PASS.

- [ ] **Step 3: Negative grep (AC3 — `"default"` literal absence)**

```bash
! grep -rn '"default"' plugins/spec-distill/hooks/ --include="*.py"
```

Expected: exit 0 (zero matches in production hooks; test fixtures excluded by `--include`).

- [ ] **Step 4: Cross-plugin SESSION_PATTERN alignment**

```bash
diff <(grep -E '^SESSION_PATTERN = ' plugins/spec-distill/hooks/state_path.py) \
     <(grep -E '^SESSION_PATTERN = ' plugins/quality-gates/scripts/qg-gc.py)
```

Expected: exit 0 (lines identical).

- [ ] **Step 5: Production env smoke test (G1 verification)**

```bash
cd /tmp && rm -rf smoke-test && mkdir smoke-test && cd smoke-test
git init -q
mkdir -p docs/superpowers/specs
env -u DEVBREW_SPEC_DISTILL_SESSION_ID -u CLAUDE_CODE_SESSION_ID \
    python3 /Users/jeonghokim/Downloads/devbrew/plugins/spec-distill/hooks/spec-write-validator.py \
    <<< '{"tool_name":"Write","tool_input":{"file_path":"docs/superpowers/specs/2026-05-19-smoke-design.md"},"session_id":"payload-12345678"}' \
    2>state.err >/dev/null
# Pass criteria: no "session_id unresolved" + state.local.md created
! grep -q 'session_id unresolved' state.err
test -f .claude/spec-distill/payload-12345678/state.local.md
echo "[PASS] smoke: payload session_id path verified"
cd / && rm -rf /tmp/smoke-test
```

Expected: `[PASS] smoke: payload session_id path verified`.

- [ ] **Step 6: No commit — verification only**

---

## Task 14: PR creation

**Files:** none modified.

- [ ] **Step 1: Push branch**

```bash
git push -u origin feature/spec-distill-state-cleanup-fix
```

- [ ] **Step 2: Create PR with `gh`**

```bash
gh pr create --title "feat(spec-distill): state cleanup residue fix (v0.6.0)" --body "$(cat <<'EOF'
## Summary
- session_id `"default"` literal singleton 제거 — `CLAUDE_CODE_SESSION_ID` single source of truth (qg pattern adaptation)
- 4-layer cleanup defense: SessionEnd hook + TTL-GC + approve_handoff script + write_state defensive truncate
- 7 신규 test (52 cases) + 기존 7 test 호환 유지

## Spec
`docs/superpowers/specs/2026-05-19-spec-distill-state-cleanup-fix-design.md` (3 rounds reviewed by spec-distill reviewer agent — design mode, approved)

## Test plan
- [ ] CI: 7 신규 test 통과 (test_session_id_resolution.sh, test_session_end_cleanup.py, test_gc.py, test_approve_handoff.sh, test_stale_state_truncate.sh, test_brainstorming_entry.sh, test_kill_switches_v060.sh)
- [ ] CI: 7 기존 test 무변경 통과 (test_state_path.sh, test_spec_write_validator.sh, test_review_dispatch.sh, test_reminder_hook.sh, test_design_mode_validator.sh, test_review_dispatch_design_mandate.sh, test_hook_output_schema.py)
- [ ] Negative: `grep -rn '"default"' plugins/spec-distill/hooks/ --include="*.py"` = 0 matches
- [ ] Cross-plugin: SESSION_PATTERN identical to plugins/quality-gates/scripts/qg-gc.py
- [ ] Smoke: production env payload session_id path (env -u DEVBREW_SPEC_DISTILL_SESSION_ID)
- [ ] /qg pipeline pass (Gate 1 plan-verifier, Gate 2 security+adversarial+test-scope, Gate 3 runtime if applicable)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 3: Report PR URL**

---

## Self-Review Checklist

**Spec coverage:**
- AC1 → Task 2 ✓
- AC2 → Tasks 7, 8 ✓
- AC3 → Task 8 step 4, Task 13 step 3 ✓
- AC4 → Task 4 ✓
- AC5 → Task 5 ✓
- AC6 → Task 6 ✓
- AC7 → Task 11 ✓
- AC8 → Task 7 ✓
- AC9 → Task 9 ✓
- AC10 → Task 10 ✓
- AC11 → Task 12 ✓
- AC12 → Task 3 ✓
- AC13 → Task 13 ✓
- AC14 → Task 7 step 2 (legacy advisory in write_state) ✓
- G1~G7 → all covered by AC mapping above
- N1~N7 → not implemented (intentional, per spec)
- C1~C10 → constraints satisfied throughout (kill switch in all hooks, SESSION_PATTERN consistent, worktree compat via state_root)

**Placeholder scan:** No TBD/TODO/"implement later" in any task. All code blocks complete.

**Type consistency:**
- `resolve_session_id(payload: dict | None = None) -> str | None` — defined Task 2, called Tasks 7, 8 (consistent signature)
- `SESSION_PATTERN` constant — defined Task 2, referenced Tasks 4, 5 (state_path import)
- `write_state(session_id, path, mode, worktree_path)` — modified Task 7, signature preserved from v0.5.1
- `approve_handoff.sh <session_id> <spec_path>` — defined Task 6, referenced Task 11 (SKILL.md)
- Marker file naming consistent: `.legacy-advisory-emitted-v060` (AC14), `.deprecation-cleanup-stale-states-v060` (AC12)

**Execution sequencing:** Phase order in spec §Metadata = (a)→(b)/(c)→(a)/(d)→sync→test. Plan task order: 1 setup → 2-3 (a) Phase 1 → 4-6 (b)+(c) Phase 2 → 7-8 (a)+(d) Phase 3 → 9-10 new tests → 11-12 Phase 4 sync → 13 Phase 5 verify → 14 PR. Consistent with spec.

No issues found. Plan ready for execution.
