# Quality-Gates Per-Session State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `quality-gates` 플러그인의 state를 평면 5파일(`.claude/quality-gates*.local.md` + cache files)에서 per-session 디렉토리(`.claude/quality-gates/<session-id>/`)로 이전. 동시 세션 corruption + stale advisor + 누적 잔재를 한꺼번에 해결. SemVer 1.5.0 → 1.6.0.

**Architecture:** 세션 ID는 경로가 source of truth. `setup-qg.sh`가 `${CLAUDE_CODE_SESSION_ID}` 또는 `--session-id` 인자로 자기 폴더 생성. SessionStart는 read-only로 자기 폴더만 advise. GC는 `setup-qg.sh` 시작부 + `/cancel-qg --gc` + `/qg --gc`에서만 fire (SessionStart never mutates). 신규 SessionEnd 훅이 graceful close 시 자기 폴더 cleanup. fcntl lock + double-stat ns + rename-then-rmtree 3-layer race guard.

**Tech Stack:** Python 3 (hooks + qg-gc.py), bash (setup-qg.sh, pre-pipeline-check.sh), markdown (slash commands), `unittest`(Python 테스트), bash subprocess for shell tests.

**Spec:** [`docs/superpowers/specs/2026-05-08-qg-per-session-state-design.md`](../specs/2026-05-08-qg-per-session-state-design.md)

**Working dir:** `/Users/jeonghokim/Downloads/devbrew`
**Branch:** `feature/qg-per-session-state` (already checked out at commit `dde8b56`)

---

## File Structure

### 신규 파일
- `plugins/quality-gates/scripts/qg-gc.py` — TTL GC helper (단일 진입점, lock + race guard).
- `plugins/quality-gates/hooks/session-end-cleanup.py` — graceful close cleanup.
- `plugins/quality-gates/tests/test_qg_gc.py`
- `plugins/quality-gates/tests/test_session_end_cleanup.py`
- `plugins/quality-gates/tests/test_setup_qg.sh`

### 수정 파일
- `plugins/quality-gates/.claude-plugin/plugin.json` — version bump.
- `plugins/quality-gates/scripts/setup-qg.sh` — `--session-id` 인자, hard fail, GC 호출, per-session paths.
- `plugins/quality-gates/scripts/pre-pipeline-check.sh` — per-session paths.
- `plugins/quality-gates/hooks/post-tool-use.py` — self-session scope.
- `plugins/quality-gates/hooks/post-tool-use-session-tracker.py` — per-session path.
- `plugins/quality-gates/hooks/session-start-advisor.py` — self-only advise.
- `plugins/quality-gates/hooks/stop-hook.py` — per-session path + folder rmtree on terminal.
- `plugins/quality-gates/hooks/hooks.json` — `SessionEnd` 등록.
- `plugins/quality-gates/commands/qg.md` — `--reset`/`--gc` 동작.
- `plugins/quality-gates/commands/cancel-qg.md` — `allowed-tools`, `--gc`/`--all` flags.
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — pre-pipeline-check 결과 사용처 갱신.
- `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md` — 경로 예시.
- `plugins/quality-gates/tests/test_session_tracker.py` — 새 path + per-session 격리.
- `plugins/quality-gates/tests/test_session_start_advisor.py` — sibling silent.
- `plugins/quality-gates/tests/e2e-scenarios.md` — 신규 시나리오.
- `plugins/quality-gates/README.md` — Pipeline state 섹션 + P21 → P5/P14/§4.8 cite 수정.
- `plugins/quality-gates/CHANGELOG.md` — 1.6.0 entry.
- `docs/philosophy/devbrew-harness-philosophy.md` §4.8 — per-session subdir 한 줄 보강.
- `CLAUDE.md` — Plugin Shape의 markdown-state bullet 보강.

---

## Phase 1: GC Helper (Foundation)

### Task 1: `qg-gc.py` test scaffolding (failing tests)

**Files:**
- Create: `plugins/quality-gates/tests/test_qg_gc.py`

- [ ] **Step 1: Write failing tests for qg-gc.py**

```python
"""Tests for scripts/qg-gc.py — TTL-based session-folder GC."""
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

GC = Path(__file__).resolve().parent.parent / "scripts" / "qg-gc.py"


def run_gc(cwd, env_extra=None, args=None):
    env = os.environ.copy()
    env.pop("DEVBREW_QG_GC_VERBOSE", None)
    env.pop("DEVBREW_QG_TTL_HOURS", None)
    env.pop("DEVBREW_DISABLE_QUALITY_GATES", None)
    if env_extra:
        env.update(env_extra)
    cmd = [sys.executable, str(GC)]
    if args:
        cmd.extend(args)
    return subprocess.run(cmd, capture_output=True, text=True, cwd=cwd, env=env)


def make_session_dir(root, sid, mtime_offset_seconds=0, ctime_offset_seconds=0):
    """Create .claude/quality-gates/<sid>/pipeline.md with mtime backdated."""
    folder = root / ".claude" / "quality-gates" / sid
    folder.mkdir(parents=True, exist_ok=True)
    f = folder / "pipeline.md"
    f.write_text("---\nstatus: gate2_running\n---\n")
    if mtime_offset_seconds:
        new_time = time.time() + mtime_offset_seconds
        os.utime(f, (new_time, new_time))
        os.utime(folder, (new_time, new_time))
    return folder


class TestQgGc(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def test_old_folder_removed(self):
        old = make_session_dir(self.tmp, "abcd1234efgh", mtime_offset_seconds=-25 * 3600)
        proc = run_gc(self.tmp, env_extra={"DEVBREW_QG_GC_VERBOSE": "1"})
        self.assertEqual(proc.returncode, 0, msg=proc.stderr)
        self.assertFalse(old.exists(), msg=f"stale folder should be removed; stderr={proc.stderr}")
        self.assertIn("removed 1", proc.stdout)

    def test_fresh_folder_kept(self):
        fresh = make_session_dir(self.tmp, "freshsess99", mtime_offset_seconds=-60)
        proc = run_gc(self.tmp)
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(fresh.exists())

    def test_self_session_excluded(self):
        sid = "selfsess1234"
        own = make_session_dir(self.tmp, sid, mtime_offset_seconds=-25 * 3600)
        proc = run_gc(self.tmp, env_extra={"CLAUDE_CODE_SESSION_ID": sid})
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(own.exists(), msg="self session must never be GC'd")

    def test_pattern_guard_skips_short_names(self):
        bad = self.tmp / ".claude" / "quality-gates" / "short"
        bad.mkdir(parents=True)
        (bad / "pipeline.md").write_text("x")
        old = time.time() - 25 * 3600
        os.utime(bad / "pipeline.md", (old, old))
        os.utime(bad, (old, old))
        run_gc(self.tmp)
        self.assertTrue(bad.exists(), msg="non-pattern folders must not be GC'd")

    def test_grace_period_protects_empty_new_folder(self):
        new = self.tmp / ".claude" / "quality-gates" / "newsess12345"
        new.mkdir(parents=True)
        # Empty + just created: ctime within 60s
        proc = run_gc(self.tmp)
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(new.exists(), msg="folders within ctime grace must not be GC'd")

    def test_kill_switch(self):
        old = make_session_dir(self.tmp, "killsess1234", mtime_offset_seconds=-25 * 3600)
        proc = run_gc(self.tmp, env_extra={"DEVBREW_DISABLE_QUALITY_GATES": "1"})
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(old.exists(), msg="kill switch must skip GC")

    def test_lock_contention_silent_exit(self):
        # Hold the lock from outside, GC should silently noop.
        import fcntl
        root = self.tmp / ".claude" / "quality-gates"
        root.mkdir(parents=True)
        lockpath = root / ".gc.lock"
        lockpath.touch()
        old = make_session_dir(self.tmp, "lockedsess12", mtime_offset_seconds=-25 * 3600)
        with open(lockpath, "w") as lf:
            fcntl.flock(lf.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            proc = run_gc(self.tmp)
            self.assertEqual(proc.returncode, 0)
            self.assertTrue(old.exists(), msg="contended lock must skip GC")

    def test_session_id_arg_overrides_env(self):
        sid = "argsession12"
        own = make_session_dir(self.tmp, sid, mtime_offset_seconds=-25 * 3600)
        proc = run_gc(self.tmp, args=["--session-id", sid])
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(own.exists())

    def test_invalid_ttl_falls_back_to_default(self):
        old = make_session_dir(self.tmp, "ttlsess12345", mtime_offset_seconds=-25 * 3600)
        proc = run_gc(self.tmp, env_extra={"DEVBREW_QG_TTL_HOURS": "not-a-number"})
        self.assertEqual(proc.returncode, 0)
        self.assertFalse(old.exists(), msg="invalid TTL should fall back to 24h")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd /Users/jeonghokim/Downloads/devbrew && python3 -m unittest plugins.quality-gates.tests.test_qg_gc -v
```

Expected: ImportError or "no such file" — `qg-gc.py` doesn't exist yet.

### Task 2: Implement `qg-gc.py`

**Files:**
- Create: `plugins/quality-gates/scripts/qg-gc.py`

- [ ] **Step 1: Implement qg-gc.py**

```python
#!/usr/bin/env python3
"""TTL-based GC for quality-gates per-session state folders.

Triggers (must be explicit, never SessionStart):
  - setup-qg.sh start (auto, fire-and-forget)
  - /qg --gc, /cancel-qg --gc, /cancel-qg --all (user)

Race guard: 3-layer (fcntl lock + double-stat ns + rename-then-rmtree).

Kill switch: DEVBREW_DISABLE_QUALITY_GATES=1 → no-op.
TTL override: DEVBREW_QG_TTL_HOURS (positive int, default 24).
Verbose: DEVBREW_QG_GC_VERBOSE=1 → print summary line on stdout.
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

ROOT = Path(".claude/quality-gates")
LOCK_NAME = ".gc.lock"
SESSION_PATTERN = re.compile(r"^[A-Za-z0-9_-]{8,}$")
GRACE_NS = 60 * 1_000_000_000
DOUBLE_STAT_DELAY_S = 0.05


def _disabled() -> bool:
    return os.environ.get("DEVBREW_DISABLE_QUALITY_GATES") == "1"


def _ttl_ns() -> int:
    raw = os.environ.get("DEVBREW_QG_TTL_HOURS", "24")
    try:
        n = int(raw)
        if n <= 0:
            n = 24
    except ValueError:
        n = 24
    return n * 3600 * 1_000_000_000


def _verbose() -> bool:
    return os.environ.get("DEVBREW_QG_GC_VERBOSE") == "1"


def _folder_mtime_ns(folder: Path) -> int:
    files = [p for p in folder.iterdir() if p.is_file()]
    if not files:
        return folder.stat().st_mtime_ns
    return max(p.stat().st_mtime_ns for p in files)


def _within_grace(folder: Path) -> bool:
    age_ns = time.time_ns() - folder.stat().st_ctime_ns
    return age_ns < GRACE_NS


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
    pending = folder.parent / f".gc-pending-{uuid.uuid4().hex}"
    try:
        folder.rename(pending)
    except OSError:
        return False
    shutil.rmtree(pending, ignore_errors=True)
    return True


def gc(self_session_id: str | None = None) -> int:
    if _disabled() or not ROOT.exists():
        return 0
    lock_path = ROOT / LOCK_NAME
    lock_path.touch(exist_ok=True)
    ttl_ns = _ttl_ns()
    removed = 0
    with open(lock_path, "w") as lockfile:
        try:
            fcntl.flock(lockfile.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except (BlockingIOError, OSError):
            return 0
        try:
            for child in ROOT.iterdir():
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
                        f"[quality-gates] GC failed on {child.name}: {exc}",
                        file=sys.stderr,
                    )
        finally:
            try:
                fcntl.flock(lockfile.fileno(), fcntl.LOCK_UN)
            except OSError:
                pass
    if _verbose() and removed > 0:
        print(f"[quality-gates] GC: removed {removed} stale session folder(s)")
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

- [ ] **Step 2: Make it executable**

```bash
chmod +x /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates/scripts/qg-gc.py
```

- [ ] **Step 3: Run tests to verify pass**

```bash
cd /Users/jeonghokim/Downloads/devbrew && python3 -m unittest plugins.quality-gates.tests.test_qg_gc -v
```

Expected: 9 passing.

- [ ] **Step 4: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew && git add plugins/quality-gates/scripts/qg-gc.py plugins/quality-gates/tests/test_qg_gc.py && git commit -m "feat(quality-gates): qg-gc.py TTL GC helper with lock + race guard"
```

---

## Phase 2: Hook Updates (per-session paths)

### Task 3: Update `test_session_tracker.py` for per-session paths

**Files:**
- Modify: `plugins/quality-gates/tests/test_session_tracker.py`

- [ ] **Step 1: Replace path-related test logic**

기존 `state_path`는 `.claude/quality-gates-session.local.md` flat path. 새 path는 `.claude/quality-gates/<session-id>/files.md`. 모든 test에 `session_id` payload 필드 추가, `state_path` 계산 helper 통일.

```python
"""Tests for the post-tool-use session-tracker hook."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parent.parent / "hooks" / "post-tool-use-session-tracker.py"
SID_A = "sessionidaaaa"
SID_B = "sessionidbbbb"


def state_path(cwd, sid):
    return Path(cwd) / ".claude" / "quality-gates" / sid / "files.md"


def run_hook(payload, cwd, env_extra=None):
    env = os.environ.copy()
    if env_extra:
        env.update(env_extra)
    proc = subprocess.run(
        [sys.executable, str(HOOK)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        cwd=cwd,
        env=env,
    )
    return proc


class TestSessionTracker(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def test_appends_edit_path(self):
        payload = {
            "session_id": SID_A,
            "tool_name": "Edit",
            "tool_input": {"file_path": "/abs/path/foo.py"},
        }
        proc = run_hook(payload, self.tmp)
        self.assertEqual(proc.returncode, 0, msg=proc.stderr)
        state = state_path(self.tmp, SID_A)
        self.assertTrue(state.exists())
        self.assertIn("- /abs/path/foo.py", state.read_text())

    def test_dedup_within_run(self):
        for _ in range(2):
            run_hook(
                {
                    "session_id": SID_A,
                    "tool_name": "Write",
                    "tool_input": {"file_path": "/abs/path/bar.py"},
                },
                self.tmp,
            )
        state = state_path(self.tmp, SID_A)
        self.assertEqual(state.read_text().count("/abs/path/bar.py"), 1)

    def test_two_sessions_isolated(self):
        run_hook(
            {
                "session_id": SID_A,
                "tool_name": "Edit",
                "tool_input": {"file_path": "/abs/a.py"},
            },
            self.tmp,
        )
        run_hook(
            {
                "session_id": SID_B,
                "tool_name": "Edit",
                "tool_input": {"file_path": "/abs/b.py"},
            },
            self.tmp,
        )
        a_state = state_path(self.tmp, SID_A)
        b_state = state_path(self.tmp, SID_B)
        self.assertIn("/abs/a.py", a_state.read_text())
        self.assertNotIn("/abs/b.py", a_state.read_text())
        self.assertIn("/abs/b.py", b_state.read_text())
        self.assertNotIn("/abs/a.py", b_state.read_text())

    def test_multiedit(self):
        proc = run_hook(
            {
                "session_id": SID_A,
                "tool_name": "MultiEdit",
                "tool_input": {"file_path": "/abs/x.py", "edits": [{}]},
            },
            self.tmp,
        )
        self.assertEqual(proc.returncode, 0)
        self.assertIn("- /abs/x.py", state_path(self.tmp, SID_A).read_text())

    def test_ignores_non_edit_tools(self):
        run_hook(
            {
                "session_id": SID_A,
                "tool_name": "Read",
                "tool_input": {"file_path": "/abs/q.py"},
            },
            self.tmp,
        )
        self.assertFalse(state_path(self.tmp, SID_A).exists())

    def test_kill_switch_env(self):
        env = {"DEVBREW_DISABLE_QUALITY_GATES": "1"}
        proc = run_hook(
            {
                "session_id": SID_A,
                "tool_name": "Edit",
                "tool_input": {"file_path": "/abs/k.py"},
            },
            self.tmp,
            env_extra=env,
        )
        self.assertEqual(proc.returncode, 0)
        self.assertFalse(state_path(self.tmp, SID_A).exists())

    def test_relative_path_resolved_to_absolute(self):
        proc = run_hook(
            {
                "session_id": SID_A,
                "tool_name": "Edit",
                "tool_input": {"file_path": "rel/path.py"},
            },
            self.tmp,
        )
        self.assertEqual(proc.returncode, 0)
        self.assertIn(
            os.path.join(self.tmp, "rel/path.py"),
            state_path(self.tmp, SID_A).read_text(),
        )

    def test_kill_switch_skip_hooks(self):
        env = {"DEVBREW_SKIP_HOOKS": "quality-gates:session-tracker"}
        proc = run_hook(
            {
                "session_id": SID_A,
                "tool_name": "Edit",
                "tool_input": {"file_path": "/abs/s.py"},
            },
            self.tmp,
            env_extra=env,
        )
        self.assertEqual(proc.returncode, 0)
        self.assertFalse(state_path(self.tmp, SID_A).exists())

    def test_empty_session_id_silent_exit(self):
        proc = run_hook(
            {
                "session_id": "",
                "tool_name": "Edit",
                "tool_input": {"file_path": "/abs/e.py"},
            },
            self.tmp,
        )
        self.assertEqual(proc.returncode, 0)
        # Nothing should be written anywhere
        gates_root = Path(self.tmp) / ".claude" / "quality-gates"
        self.assertFalse(gates_root.exists() and any(gates_root.iterdir()))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run to confirm failure**

```bash
cd /Users/jeonghokim/Downloads/devbrew && python3 -m unittest plugins.quality-gates.tests.test_session_tracker -v
```

Expected: most fail — current hook writes to flat path, doesn't read session_id.

### Task 4: Update `post-tool-use-session-tracker.py`

**Files:**
- Modify: `plugins/quality-gates/hooks/post-tool-use-session-tracker.py`

- [ ] **Step 1: Replace hook body**

```python
#!/usr/bin/env python3
"""PostToolUse hook: track files edited in this session for /qg scope.

Per-session path: .claude/quality-gates/<session-id>/files.md.
Triggered by Edit, Write, MultiEdit. Idempotent (dedup). Atomic rename.

Kill switches:
  DEVBREW_DISABLE_QUALITY_GATES=1   - disables this hook entirely
  DEVBREW_SKIP_HOOKS=quality-gates:session-tracker  - skip just this one
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

TRACKED_TOOLS = {"Edit", "Write", "MultiEdit"}
HEADER = "# Quality-Gates Session Files\n\n"


def _disabled() -> bool:
    if os.environ.get("DEVBREW_DISABLE_QUALITY_GATES") == "1":
        return True
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    return "quality-gates:session-tracker" in skip


def _read_existing(path: Path) -> set[str]:
    if not path.exists():
        return set()
    seen: set[str] = set()
    for line in path.read_text().splitlines():
        if line.startswith("- "):
            seen.add(line[2:].strip())
    return seen


def _write_atomic(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + f".tmp.{os.getpid()}")
    tmp.write_text(content)
    tmp.replace(path)


def main() -> int:
    if _disabled():
        return 0
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0
    session_id = payload.get("session_id", "")
    if not session_id:
        return 0
    tool = payload.get("tool_name", "")
    if tool not in TRACKED_TOOLS:
        return 0
    file_path = payload.get("tool_input", {}).get("file_path")
    if not file_path:
        return 0
    abs_path = str(Path(file_path).resolve())
    state_file = Path(".claude/quality-gates") / session_id / "files.md"
    existing = _read_existing(state_file)
    if abs_path in existing:
        return 0
    sorted_paths = sorted(existing | {abs_path})
    body = HEADER + "".join(f"- {p}\n" for p in sorted_paths)
    _write_atomic(state_file, body)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run tests**

```bash
cd /Users/jeonghokim/Downloads/devbrew && python3 -m unittest plugins.quality-gates.tests.test_session_tracker -v
```

Expected: all 9 passing.

- [ ] **Step 3: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew && git add plugins/quality-gates/hooks/post-tool-use-session-tracker.py plugins/quality-gates/tests/test_session_tracker.py && git commit -m "feat(quality-gates): per-session paths in session-tracker hook"
```

### Task 5: Update `test_session_start_advisor.py` for self-only advise

**Files:**
- Modify: `plugins/quality-gates/tests/test_session_start_advisor.py`

- [ ] **Step 1: Replace test file**

```python
"""Tests for the SessionStart advisor (read-only, self-session scope).

Status fixtures use the canonical vocabulary documented in
skills/quality-pipeline/references/state-file-format.md:
  gate1_running | gate2_running | gate3_running | completed | aborted
"""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parent.parent / "hooks" / "session-start-advisor.py"
SID = "advisorses12"
SID_OTHER = "othersess999"


def make_state(status: str, gate: int = 2, started_at: str = "2026-04-29T08:14:00Z") -> str:
    return (
        "---\n"
        f"status: {status}\n"
        f"current_gate: {gate}\n"
        "total_iterations: 1\n"
        f'started_at: "{started_at}"\n'
        "---\n"
        "# Quality Gates Pipeline State\n"
    )


def run_advisor(cwd, payload=None, env_extra=None):
    env = os.environ.copy()
    if env_extra:
        env.update(env_extra)
    proc = subprocess.run(
        [sys.executable, str(HOOK)],
        input=json.dumps(payload or {"session_id": SID}),
        capture_output=True,
        text=True,
        cwd=cwd,
        env=env,
    )
    return proc


def write_state(cwd, sid, status):
    folder = Path(cwd) / ".claude" / "quality-gates" / sid
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "pipeline.md").write_text(make_state(status))


class TestAdvisor(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def test_no_state_silent(self):
        proc = run_advisor(self.tmp)
        self.assertEqual(proc.returncode, 0)
        self.assertEqual(proc.stdout, "")

    def test_self_active_state_prints_one_liner(self):
        write_state(self.tmp, SID, "gate2_running")
        proc = run_advisor(self.tmp)
        self.assertEqual(proc.returncode, 0)
        self.assertIn("/qg", proc.stdout)
        self.assertIn("--reset", proc.stdout)

    def test_other_session_active_silent_by_default(self):
        write_state(self.tmp, SID_OTHER, "gate2_running")
        proc = run_advisor(self.tmp)
        self.assertEqual(proc.returncode, 0)
        self.assertEqual(proc.stdout, "", msg="must not advise about other sessions")

    def test_verbose_shows_sibling_count(self):
        write_state(self.tmp, SID_OTHER, "gate2_running")
        proc = run_advisor(self.tmp, env_extra={"DEVBREW_QG_GC_VERBOSE": "1"})
        self.assertEqual(proc.returncode, 0)
        self.assertIn("sibling", proc.stdout.lower())

    def test_self_terminal_state_silent(self):
        for status in ("completed", "aborted"):
            with self.subTest(status=status):
                write_state(self.tmp, SID, status)
                proc = run_advisor(self.tmp)
                self.assertEqual(proc.returncode, 0)
                self.assertEqual(proc.stdout, "", msg=f"output on terminal {status}")

    def test_does_not_mutate_files(self):
        write_state(self.tmp, SID, "gate2_running")
        write_state(self.tmp, SID_OTHER, "gate2_running")
        before = {
            p: p.read_text()
            for p in (Path(self.tmp) / ".claude/quality-gates").rglob("*.md")
        }
        run_advisor(self.tmp)
        after = {
            p: p.read_text()
            for p in (Path(self.tmp) / ".claude/quality-gates").rglob("*.md")
        }
        self.assertEqual(before, after, msg="advisor must NEVER mutate files")

    def test_kill_switch(self):
        write_state(self.tmp, SID, "gate2_running")
        proc = run_advisor(self.tmp, env_extra={"DEVBREW_DISABLE_QUALITY_GATES": "1"})
        self.assertEqual(proc.returncode, 0)
        self.assertEqual(proc.stdout, "")

    def test_legacy_flat_state_warns_via_systemmessage(self):
        legacy = Path(self.tmp) / ".claude" / "quality-gates.local.md"
        legacy.parent.mkdir(parents=True, exist_ok=True)
        legacy.write_text(make_state("gate2_running"))
        proc = run_advisor(self.tmp)
        self.assertEqual(proc.returncode, 0)
        self.assertIn("Legacy", proc.stdout)
        # MUST NOT delete (read-only)
        self.assertTrue(legacy.exists())

    def test_advisory_includes_gate_and_timestamp(self):
        write_state(self.tmp, SID, "gate2_running")
        proc = run_advisor(self.tmp)
        self.assertIn("Gate 2", proc.stdout)
        self.assertIn("2026-04-29T08:14:00Z", proc.stdout)

    def test_quoted_status_value_handled(self):
        folder = Path(self.tmp) / ".claude" / "quality-gates" / SID
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "pipeline.md").write_text(
            "---\nstatus: \"gate2_running\"\ncurrent_gate: 2\n---\n"
        )
        proc = run_advisor(self.tmp)
        self.assertIn("--reset", proc.stdout)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run to confirm failure**

```bash
cd /Users/jeonghokim/Downloads/devbrew && python3 -m unittest plugins.quality-gates.tests.test_session_start_advisor -v
```

Expected: most fail — current advisor reads flat path, ignores session_id.

### Task 6: Update `session-start-advisor.py`

**Files:**
- Modify: `plugins/quality-gates/hooks/session-start-advisor.py`

- [ ] **Step 1: Rewrite advisor body**

```python
#!/usr/bin/env python3
"""SessionStart hook: advisory only — never mutates state.

Reads only `.claude/quality-gates/<self-session>/pipeline.md`.
Other sessions' folders are NEVER read or mutated (per CLAUDE.md
"SessionStart never mutates" rule).

Behaviors:
- self in-flight (gate{1,2,3}_running)         → one-line advisory on stdout
- self terminal (completed | aborted)          → silent
- other-session in-flight                      → silent (verbose: sibling count)
- legacy flat state file (v1.5.0) detected     → systemMessage about migration
                                                  (read-only check; setup-qg removes)

Working-directory contract: invoked with cwd = workspace root.

Kill switch: DEVBREW_DISABLE_QUALITY_GATES=1.
Verbose: DEVBREW_QG_GC_VERBOSE=1 prints sibling-folder count.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(".claude/quality-gates")
LEGACY_FILES = (
    Path(".claude/quality-gates.local.md"),
    Path(".claude/quality-gates-session.local.md"),
    Path(".claude/quality-gates-branch.local.md"),
    Path(".claude/qg-diff-cache.txt"),
    Path(".claude/qg-code-paths.tmp"),
)
ACTIVE_STATUSES = {"gate1_running", "gate2_running", "gate3_running"}
GATE_RX = re.compile(r"^current_gate:\s*(\S+)", re.MULTILINE)
STARTED_AT_RX = re.compile(r"^started_at:\s*\"?([^\"\n]+)\"?", re.MULTILINE)
STATUS_RX = re.compile(r"^status:\s*\"?(\S+?)\"?\s*$", re.MULTILINE)
SESSION_PATTERN = re.compile(r"^[A-Za-z0-9_-]{8,}$")


def _strip_quotes(value: str) -> str:
    return value.strip().strip('"').strip("'")


def _disabled() -> bool:
    return os.environ.get("DEVBREW_DISABLE_QUALITY_GATES") == "1"


def _verbose() -> bool:
    return os.environ.get("DEVBREW_QG_GC_VERBOSE") == "1"


def _self_session_id() -> str:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        return ""
    return payload.get("session_id", "") or ""


def _legacy_present() -> bool:
    return any(p.exists() for p in LEGACY_FILES)


def _sibling_active_count(self_sid: str) -> int:
    if not ROOT.exists():
        return 0
    count = 0
    for child in ROOT.iterdir():
        if not child.is_dir():
            continue
        if not SESSION_PATTERN.match(child.name):
            continue
        if child.name == self_sid:
            continue
        pipeline = child / "pipeline.md"
        if not pipeline.exists():
            continue
        try:
            text = pipeline.read_text()
        except OSError:
            continue
        m = STATUS_RX.search(text)
        if not m:
            continue
        if _strip_quotes(m.group(1)).lower() in ACTIVE_STATUSES:
            count += 1
    return count


def _emit_self_advisory(state_text: str) -> None:
    status_match = STATUS_RX.search(state_text)
    if not status_match:
        return
    status = _strip_quotes(status_match.group(1)).lower()
    if status not in ACTIVE_STATUSES:
        return
    gate_match = GATE_RX.search(state_text)
    gate = _strip_quotes(gate_match.group(1)) if gate_match else "?"
    started_match = STARTED_AT_RX.search(state_text)
    started = _strip_quotes(started_match.group(1)) if started_match else None
    suffix = f" (started {started})" if started else ""
    sys.stdout.write(
        f"[quality-gates] In-flight pipeline at Gate {gate}{suffix}. "
        f"Run `/qg` to resume or `/qg --reset` to clear.\n"
    )


def main() -> int:
    if _disabled():
        return 0
    self_sid = _self_session_id()
    if _legacy_present():
        sys.stdout.write(
            "[quality-gates] Legacy v1.5.0 state files detected. "
            "They will be removed on your next /qg invocation. "
            "If you had an in-flight pipeline, re-run it.\n"
        )
    if self_sid:
        self_pipeline = ROOT / self_sid / "pipeline.md"
        if self_pipeline.exists():
            try:
                text = self_pipeline.read_text()
            except OSError:
                text = ""
            if text:
                _emit_self_advisory(text)
    if _verbose():
        n = _sibling_active_count(self_sid)
        if n > 0:
            sys.stdout.write(
                f"[quality-gates] verbose: {n} sibling session(s) appear active.\n"
            )
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run tests**

```bash
cd /Users/jeonghokim/Downloads/devbrew && python3 -m unittest plugins.quality-gates.tests.test_session_start_advisor -v
```

Expected: all 10 passing.

- [ ] **Step 3: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew && git add plugins/quality-gates/hooks/session-start-advisor.py plugins/quality-gates/tests/test_session_start_advisor.py && git commit -m "feat(quality-gates): self-only advisor (read-only) with legacy detection"
```

### Task 7: Update `stop-hook.py` for per-session paths and folder rmtree

**Files:**
- Modify: `plugins/quality-gates/hooks/stop-hook.py`

- [ ] **Step 1: Change STATE_FILE constant and resolve via session_id**

`stop-hook.py` 상단의 `STATE_FILE` 상수와 `main()` 진입부 변경. `session_id`를 stdin에서 가져와 path를 동적 구성.

Replace at top of file (around line 27):
```python
# OLD
STATE_FILE = ".claude/quality-gates.local.md"
```
with:
```python
ROOT = ".claude/quality-gates"


def state_file_for(session_id: str) -> str:
    return f"{ROOT}/{session_id}/pipeline.md"
```

- [ ] **Step 2: Update `main()` to compute STATE_FILE per call**

Replace `main()` (around line 564) section that reads `STATE_FILE`. Find these lines and update:

```python
def main():
    try:
        hook_input = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    session_id = hook_input.get("session_id", "")
    if not session_id:
        sys.exit(0)
    state_file = state_file_for(session_id)

    # 1. Check state file exists
    if not os.path.exists(state_file):
        sys.exit(0)

    # 2. Parse state file
    state, body = parse_state_file(state_file)
    if state is None:
        try:
            os.unlink(state_file)
        except OSError:
            pass
        sys.exit(0)

    # 3. Session isolation defense-in-depth (path already encodes session)
    state_session = state.get("session_id", "")
    if state_session and state_session != session_id:
        sys.exit(0)
```

- [ ] **Step 3: Replace all `STATE_FILE` usage in `main()` with `state_file`**

Search for remaining `STATE_FILE` references in `main()` body and replace with the local `state_file` variable. Also update the cleanup logic on terminal transitions:

```python
    # 9. Handle completion/abort — remove session folder entirely and allow exit
    if transition["type"] in ("complete", "abort"):
        import shutil
        folder = os.path.dirname(state_file)
        try:
            shutil.rmtree(folder, ignore_errors=True)
        except OSError:
            pass
        sys.exit(0)
```

- [ ] **Step 4: Update `update_state_file` and `parse_state_file` callers**

These functions accept `path` as their first argument — already parameterized. Pass `state_file` (the local) instead of the module-level `STATE_FILE`. Specifically these callsites in `main()`:
- `state, body = parse_state_file(state_file)`
- `update_state_file(state_file, state, signal, transition)`
- `updated_state, updated_body = parse_state_file(state_file)` (multiple places)

Also `update_state_file` internally uses `os.path.dirname(path)` for `tempfile.mkstemp(dir=...)` — that already works correctly with the new path.

- [ ] **Step 5: Verify hook still passes existing functional flow**

There's no automated test for stop-hook.py end-to-end (it's a complex integration). Run a smoke test by invoking it with a fixture:

```bash
cd /tmp && rm -rf qg-test && mkdir -p qg-test/.claude/quality-gates/smoketest12 && cd qg-test && \
cat > .claude/quality-gates/smoketest12/pipeline.md <<'EOF'
---
status: gate1_running
current_gate: 1
gate2_iteration: 0
max_gate2_iterations: 5
skip_runtime: false
single_gate: null
plan_file: "auto"
pr_url: ""
available_plugins: ""
session_id: "smoketest12"
started_at: "2026-05-08T00:00:00Z"
---

# Quality Gates Pipeline State

## Gate Results

## Pipeline History
- [2026-05-08T00:00:00Z] Pipeline started
EOF
echo '{"session_id":"smoketest12","last_assistant_message":"<qg-signal gate=\"1\" verdict=\"PASS\" summary=\"ok\" files_changed=\"\" />","transcript_path":""}' | \
  python3 /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates/hooks/stop-hook.py
```

Expected: JSON output with `decision: block` and Gate 2 prompt. State file moved to `gate2_running`.

```bash
cat /tmp/qg-test/.claude/quality-gates/smoketest12/pipeline.md | grep status:
```

Expected: `status: gate2_running`.

- [ ] **Step 6: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew && git add plugins/quality-gates/hooks/stop-hook.py && git commit -m "feat(quality-gates): stop-hook reads/writes per-session paths"
```

### Task 8: Update `post-tool-use.py` to scope to self-session

**Files:**
- Modify: `plugins/quality-gates/hooks/post-tool-use.py`

- [ ] **Step 1: Rewrite hook body**

```python
#!/usr/bin/env python3
"""PostToolUse hook for quality-gates plugin.

Detects when `gh pr create` succeeds and injects a system message
to trigger the quality pipeline. Self-session scope: checks only
`.claude/quality-gates/<session-id>/pipeline.md` for the active flag.
Passes --session-id explicitly to setup-qg.sh in case env var is unset.
"""

import json
import os
import re
import sys


def main():
    try:
        input_data = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        print(json.dumps({}))
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})
    tool_response = input_data.get("tool_response", {})
    session_id = input_data.get("session_id", "")

    if tool_name != "Bash" or not session_id:
        print(json.dumps({}))
        sys.exit(0)

    command = tool_input.get("command", "")
    if not re.search(r"gh\s+pr\s+create", command):
        print(json.dumps({}))
        sys.exit(0)

    project_dir = input_data.get("cwd", os.getcwd())
    state_file = os.path.join(
        project_dir, ".claude", "quality-gates", session_id, "pipeline.md"
    )
    if os.path.exists(state_file):
        print(json.dumps({}))
        sys.exit(0)

    if isinstance(tool_response, dict):
        stdout = tool_response.get("stdout", "")
    else:
        stdout = str(tool_response)
    pr_url_match = re.search(r"https://github\.com/[^\s]+/pull/\d+", stdout)
    pr_url = pr_url_match.group(0) if pr_url_match else ""

    if not pr_url:
        print(json.dumps({}))
        sys.exit(0)

    plugin_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    setup_script = os.path.join(plugin_root, "scripts", "setup-qg.sh")

    result = {
        "systemMessage": (
            f"Quality Gates: PR created at {pr_url}. "
            "You MUST now initialize the quality-gates pipeline. "
            f'Run: Bash("{setup_script} --session-id {session_id} --pr-url {pr_url}") '
            "Then invoke Skill(\"quality-gates:quality-pipeline\") with gate=1 "
            "to begin Gate 1."
        )
    }

    print(json.dumps(result))
    sys.exit(0)


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Smoke test**

```bash
echo '{"session_id":"sometest12","tool_name":"Bash","tool_input":{"command":"gh pr create --title x"},"tool_response":{"stdout":"https://github.com/x/y/pull/1"}}' | \
  python3 /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates/hooks/post-tool-use.py
```

Expected: JSON output containing `--session-id sometest12` in systemMessage.

- [ ] **Step 3: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew && git add plugins/quality-gates/hooks/post-tool-use.py && git commit -m "feat(quality-gates): post-tool-use scopes to self-session, passes --session-id"
```

### Task 9: Implement `session-end-cleanup.py` (TDD)

**Files:**
- Create: `plugins/quality-gates/tests/test_session_end_cleanup.py`
- Create: `plugins/quality-gates/hooks/session-end-cleanup.py`

- [ ] **Step 1: Write failing tests**

```python
"""Tests for the SessionEnd cleanup hook."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parent.parent / "hooks" / "session-end-cleanup.py"
SID = "endsession12"


def make_session_dir(cwd, sid):
    folder = Path(cwd) / ".claude" / "quality-gates" / sid
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "pipeline.md").write_text("---\nstatus: gate2_running\n---\n")
    (folder / "files.md").write_text("- /abs/x.py\n")
    return folder


def run_hook(cwd, payload, env_extra=None):
    env = os.environ.copy()
    if env_extra:
        env.update(env_extra)
    return subprocess.run(
        [sys.executable, str(HOOK)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        cwd=cwd,
        env=env,
    )


class TestSessionEndCleanup(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()

    def test_removes_self_folder(self):
        folder = make_session_dir(self.tmp, SID)
        proc = run_hook(self.tmp, {"session_id": SID})
        self.assertEqual(proc.returncode, 0, msg=proc.stderr)
        self.assertFalse(folder.exists())

    def test_idempotent_when_folder_missing(self):
        proc = run_hook(self.tmp, {"session_id": SID})
        self.assertEqual(proc.returncode, 0)

    def test_does_not_touch_other_sessions(self):
        own = make_session_dir(self.tmp, SID)
        other = make_session_dir(self.tmp, "siblingses99")
        run_hook(self.tmp, {"session_id": SID})
        self.assertFalse(own.exists())
        self.assertTrue(other.exists())

    def test_kill_switch(self):
        folder = make_session_dir(self.tmp, SID)
        proc = run_hook(
            self.tmp,
            {"session_id": SID},
            env_extra={"DEVBREW_DISABLE_QUALITY_GATES": "1"},
        )
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(folder.exists())

    def test_empty_session_id_silent_exit(self):
        proc = run_hook(self.tmp, {"session_id": ""})
        self.assertEqual(proc.returncode, 0)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run to verify failure**

```bash
cd /Users/jeonghokim/Downloads/devbrew && python3 -m unittest plugins.quality-gates.tests.test_session_end_cleanup -v
```

Expected: 5 errors — hook doesn't exist.

- [ ] **Step 3: Implement hook**

```python
#!/usr/bin/env python3
"""SessionEnd hook: graceful per-session state cleanup.

Removes `.claude/quality-gates/<self-session>/` if it exists.
Best-effort: idempotent (no-op if missing), tolerant of permission errors.

Kill switch: DEVBREW_DISABLE_QUALITY_GATES=1.
"""
from __future__ import annotations

import json
import os
import shutil
import sys
from pathlib import Path

ROOT = Path(".claude/quality-gates")


def _disabled() -> bool:
    return os.environ.get("DEVBREW_DISABLE_QUALITY_GATES") == "1"


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
    folder = ROOT / session_id
    shutil.rmtree(folder, ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/jeonghokim/Downloads/devbrew && python3 -m unittest plugins.quality-gates.tests.test_session_end_cleanup -v
```

Expected: 5 passing.

- [ ] **Step 5: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew && git add plugins/quality-gates/hooks/session-end-cleanup.py plugins/quality-gates/tests/test_session_end_cleanup.py && git commit -m "feat(quality-gates): SessionEnd hook for graceful cleanup"
```

### Task 10: Register `SessionEnd` in `hooks.json`

**Files:**
- Modify: `plugins/quality-gates/hooks/hooks.json`

- [ ] **Step 1: Add SessionEnd entry**

Replace the file contents:

```json
{
  "description": "Quality Gates - Stop hook for pipeline progression + PostToolUse session-tracker for /qg scope + SessionStart advisor + SessionEnd cleanup",
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/stop-hook.py",
            "timeout": 30
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/post-tool-use-session-tracker.py"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/post-tool-use.py"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/session-start-advisor.py"
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/session-end-cleanup.py"
          }
        ]
      }
    ]
  }
}
```

Note: `post-tool-use.py` was missing a registered matcher in the original `hooks.json` — the diff verified the original file only registered the session-tracker, not the gh-pr-create detection. Add it as a proper Bash matcher entry alongside.

- [ ] **Step 2: Validate JSON**

```bash
cd /Users/jeonghokim/Downloads/devbrew && python3 -c "import json; json.load(open('plugins/quality-gates/hooks/hooks.json'))" && echo OK
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew && git add plugins/quality-gates/hooks/hooks.json && git commit -m "chore(quality-gates): register SessionEnd + Bash PostToolUse hooks"
```

---

## Phase 3: Scripts (setup-qg, pre-pipeline-check)

### Task 11: Write `test_setup_qg.sh` (failing)

**Files:**
- Create: `plugins/quality-gates/tests/test_setup_qg.sh`

- [ ] **Step 1: Write bash test**

```bash
#!/usr/bin/env bash
# Tests for scripts/setup-qg.sh per-session paths and --session-id arg.
# Uses bash assertions; no external test framework.
set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/setup-qg.sh"
PASS=0
FAIL=0

note() { echo "  → $1"; }

assert_eq() {
  local actual="$1" expected="$2" msg="$3"
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (got '$actual', expected '$expected')"
  fi
}

assert_file_exists() {
  local path="$1" msg="$2"
  if [[ -f "$path" ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (file missing: $path)"
  fi
}

assert_file_not_exists() {
  local path="$1" msg="$2"
  if [[ ! -e "$path" ]]; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (file exists: $path)"
  fi
}

# --- Test 1: --session-id arg creates per-session folder ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="testsession01"
unset CLAUDE_CODE_SESSION_ID
"$SCRIPT" --session-id "$SID" >/dev/null 2>&1
RC=$?
assert_eq "$RC" "0" "exits 0 with --session-id"
assert_file_exists ".claude/quality-gates/$SID/pipeline.md" "creates pipeline.md in per-session folder"
cd / && rm -rf "$TMPDIR"

# --- Test 2: env var works without --session-id ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="envsess0001"
CLAUDE_CODE_SESSION_ID="$SID" "$SCRIPT" >/dev/null 2>&1
RC=$?
assert_eq "$RC" "0" "exits 0 with env var"
assert_file_exists ".claude/quality-gates/$SID/pipeline.md" "creates pipeline.md from env"
cd / && rm -rf "$TMPDIR"

# --- Test 3: missing both env and arg → hard fail ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
unset CLAUDE_CODE_SESSION_ID
"$SCRIPT" >/dev/null 2>err
RC=$?
ERR_MSG=$(cat err)
[[ "$RC" -ne 0 ]] && PASS=$((PASS + 1)) || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: hard fail expected, got rc=$RC"; }
echo "$ERR_MSG" | grep -q "session" && PASS=$((PASS + 1)) || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: error mentions session"; }
cd / && rm -rf "$TMPDIR"

# --- Test 4: legacy flat files removed on fresh setup ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="legacysess1"
mkdir -p .claude
touch .claude/quality-gates.local.md \
      .claude/quality-gates-session.local.md \
      .claude/quality-gates-branch.local.md \
      .claude/qg-diff-cache.txt \
      .claude/qg-code-paths.tmp
"$SCRIPT" --session-id "$SID" >/dev/null 2>&1
assert_file_not_exists ".claude/quality-gates.local.md" "legacy quality-gates.local.md removed"
assert_file_not_exists ".claude/quality-gates-session.local.md" "legacy session file removed"
assert_file_not_exists ".claude/quality-gates-branch.local.md" "legacy branch file removed"
assert_file_not_exists ".claude/qg-diff-cache.txt" "legacy diff cache removed"
assert_file_not_exists ".claude/qg-code-paths.tmp" "legacy code paths removed"
cd / && rm -rf "$TMPDIR"

# --- Test 5: same-session re-invocation blocked, different-session overwrites ---
TMPDIR=$(mktemp -d); cd "$TMPDIR"
SID="sameses0001"
"$SCRIPT" --session-id "$SID" >/dev/null 2>&1
"$SCRIPT" --session-id "$SID" >/dev/null 2>err
RC=$?
[[ "$RC" -ne 0 ]] && PASS=$((PASS + 1)) || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: 2nd invocation same session should error"; }
cd / && rm -rf "$TMPDIR"

echo
echo "Pass: $PASS, Fail: $FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
```

- [ ] **Step 2: Make executable and run**

```bash
chmod +x /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates/tests/test_setup_qg.sh && \
/Users/jeonghokim/Downloads/devbrew/plugins/quality-gates/tests/test_setup_qg.sh
```

Expected: most assertions FAIL — current setup-qg.sh writes to flat path.

### Task 12: Update `setup-qg.sh`

**Files:**
- Modify: `plugins/quality-gates/scripts/setup-qg.sh`

- [ ] **Step 1: Replace argument parsing and STATE_FILE logic**

Update the script to add `--session-id` arg, hard-fail on empty session, write to per-session path, remove legacy flat files, call qg-gc.py.

Key changes to `setup-qg.sh`:

1. Add `SESSION_ID=""` variable + `--session-id` arg parsing in the while loop:

```bash
    --session-id)
      if [[ -z "${2:-}" ]]; then
        echo "❌ Error: --session-id requires an argument" >&2
        exit 1
      fi
      SESSION_ID="$2"
      shift 2
      ;;
```

2. After the arg parsing loop, resolve session ID and hard-fail if absent:

```bash
# Resolve session ID: --session-id arg takes precedence, then env var.
if [[ -z "$SESSION_ID" ]]; then
  SESSION_ID="${CLAUDE_CODE_SESSION_ID:-}"
fi
if [[ -z "$SESSION_ID" ]]; then
  cat >&2 <<EOF
❌ Quality Gates: cannot create pipeline state — session ID is empty.
   Neither --session-id <id> argument nor CLAUDE_CODE_SESSION_ID env var was provided.
   This usually means /qg was invoked outside of Claude Code or in a sub-shell
   that did not inherit the env. Re-run /qg from Claude Code, or pass
   --session-id explicitly.
EOF
  exit 1
fi

# Validate pattern (defense in depth; matches qg-gc.py SESSION_PATTERN).
if [[ ! "$SESSION_ID" =~ ^[A-Za-z0-9_-]{8,}$ ]]; then
  echo "❌ Quality Gates: session ID '$SESSION_ID' fails pattern guard ([A-Za-z0-9_-]{8,})." >&2
  exit 1
fi
```

3. Replace `STATE_FILE` constant and active-pipeline check:

```bash
STATE_DIR=".claude/quality-gates/$SESSION_ID"
STATE_FILE="$STATE_DIR/pipeline.md"

# --- Active pipeline check (self-session only) ---
if [[ -f "$STATE_FILE" ]]; then
  if [[ "$ENSURE_MODE" == "true" ]]; then
    exit 0
  fi
  echo "❌ Error: A quality gates pipeline is already active in this session" >&2
  echo "   State file: $STATE_FILE" >&2
  echo "" >&2
  echo "   To cancel: /cancel-qg" >&2
  exit 1
fi

# --- Legacy v1.5.0 cleanup (one-time, advisory) ---
LEGACY_FILES=(
  ".claude/quality-gates.local.md"
  ".claude/quality-gates-session.local.md"
  ".claude/quality-gates-branch.local.md"
  ".claude/qg-diff-cache.txt"
  ".claude/qg-code-paths.tmp"
)
LEGACY_REMOVED=0
for f in "${LEGACY_FILES[@]}"; do
  if [[ -f "$f" ]]; then
    rm -f "$f"
    LEGACY_REMOVED=$((LEGACY_REMOVED + 1))
  fi
done
if [[ "$LEGACY_REMOVED" -gt 0 ]]; then
  cat >&2 <<EOF
[quality-gates] Removed $LEGACY_REMOVED legacy flat state file(s) from v1.5.0.
v1.6.0 uses per-session storage at .claude/quality-gates/<session>/.
EOF
fi

# --- TTL GC (best-effort; never aborts setup) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$SCRIPT_DIR/qg-gc.py" --session-id "$SESSION_ID" 2>/dev/null || true

mkdir -p "$STATE_DIR"
```

4. The `cat > "$TEMP_FILE" << EOF` for the state body — keep `session_id: "$SESSION_ID"` line (use `$SESSION_ID` not `$CLAUDE_CODE_SESSION_ID`).

5. `TEMP_FILE` and `mv` — change directory:
```bash
TEMP_FILE="${STATE_FILE}.tmp.$$"
```
The directory is `$STATE_DIR` which is now created via `mkdir -p`.

- [ ] **Step 2: Apply edits**

Open `setup-qg.sh` and apply the patches. The full updated diff is large; the agent should read the file, make the edits, and verify the result by running the bash test.

- [ ] **Step 3: Run bash tests**

```bash
/Users/jeonghokim/Downloads/devbrew/plugins/quality-gates/tests/test_setup_qg.sh
```

Expected: 0 failures.

- [ ] **Step 4: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew && git add plugins/quality-gates/scripts/setup-qg.sh plugins/quality-gates/tests/test_setup_qg.sh && git commit -m "feat(quality-gates): setup-qg per-session paths, --session-id arg, GC trigger, legacy cleanup"
```

### Task 13: Update `pre-pipeline-check.sh` for per-session paths

**Files:**
- Modify: `plugins/quality-gates/scripts/pre-pipeline-check.sh`

- [ ] **Step 1: Adapt path constants and behavior**

Read the file first to understand all paths used. Replace the three top constants:

```bash
# OLD
STATE_FILE=".claude/quality-gates.local.md"
SESSION_FILE=".claude/quality-gates-session.local.md"
BRANCH_FILE=".claude/quality-gates-branch.local.md"

# NEW (resolve session_id from env)
SESSION_ID="${CLAUDE_CODE_SESSION_ID:-}"
if [[ -z "$SESSION_ID" ]]; then
  echo "result: no_session_id"
  exit 0
fi
STATE_DIR=".claude/quality-gates/$SESSION_ID"
STATE_FILE="$STATE_DIR/pipeline.md"
SESSION_FILE="$STATE_DIR/files.md"
BRANCH_FILE="$STATE_DIR/branch.md"
```

The branch-mismatch wipe (`rm -f "$SESSION_FILE" "$STATE_FILE"`) and the branch marker write should now operate within `$STATE_DIR`. Existing logic structure remains.

- [ ] **Step 2: Smoke test**

```bash
TMPDIR=$(mktemp -d); cd "$TMPDIR"
git init -q && git checkout -q -b main
mkdir -p .claude/quality-gates/preses0001
touch .claude/quality-gates/preses0001/branch.md
CLAUDE_CODE_SESSION_ID=preses0001 \
  /Users/jeonghokim/Downloads/devbrew/plugins/quality-gates/scripts/pre-pipeline-check.sh
cd / && rm -rf "$TMPDIR"
```

Expected: structured stdout (key: value lines). No errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew && git add plugins/quality-gates/scripts/pre-pipeline-check.sh && git commit -m "feat(quality-gates): pre-pipeline-check per-session paths"
```

---

## Phase 4: Commands (qg.md, cancel-qg.md)

### Task 14: Update `commands/cancel-qg.md`

**Files:**
- Modify: `plugins/quality-gates/commands/cancel-qg.md`

- [ ] **Step 1: Rewrite command file**

```markdown
---
description: "Cancel active quality gates pipeline"
argument-hint: "[--gc | --all]"
allowed-tools: ["Bash(test:*)", "Bash(rm:*)", "Bash(rm -rf:*)", "Read", "Bash(python3 ${CLAUDE_PLUGIN_ROOT}/scripts/qg-gc.py:*)"]
hide-from-slash-command-tool: "true"
---

# Cancel Quality Gates

`$ARGUMENTS` 처리:

## Default (no flags) — cancel current session's pipeline

1. session ID 결정:
   - 환경변수 `CLAUDE_CODE_SESSION_ID` 사용. 비어있으면 "Cannot determine session ID — no active pipeline."로 종료.
2. 자기 세션 폴더 검사:
   ```!
   test -d ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID" && echo EXISTS || echo NOT_FOUND
   ```
3. **NOT_FOUND**: "No active quality gates pipeline found for this session." 종료.
4. **EXISTS**:
   - `Read(.claude/quality-gates/$CLAUDE_CODE_SESSION_ID/pipeline.md)`로 frontmatter (`status`, `current_gate`, `gate2_iteration`) 읽기.
   - 폴더 통째 삭제: `Bash("rm -rf .claude/quality-gates/$CLAUDE_CODE_SESSION_ID")`.
   - 보고: "Cancelled quality gates pipeline (was at Gate N, iteration M)".

## `--gc` — cancel + immediate TTL sweep

1. Default 액션 수행 (자기 세션 폴더 삭제).
2. `Bash("python3 ${CLAUDE_PLUGIN_ROOT}/scripts/qg-gc.py")` 실행 → stale sibling 폴더 정리.

## `--all` — wipe all session folders (REQUIRES CONFIRM)

1. 살아있는 sibling 카운트 (mtime < 1h):
   ```!
   find .claude/quality-gates -mindepth 1 -maxdepth 1 -type d -mmin -60 2>/dev/null | wc -l
   ```
2. `AskUserQuestion`을 사용해 사용자에게 확인:
   - 질문: "Delete ALL quality-gates session folders? N appear active (mtime < 1h)."
   - 옵션: "Yes, delete all" / "No, abort"
3. **Yes**: `Bash("rm -rf .claude/quality-gates")` + 보고 "Removed all session folders."
4. **No**: 보고 "Aborted." 종료.
```

- [ ] **Step 2: Manual smoke test**

이 명령은 마크다운 + Claude 해석이 필요해 자동 테스트 어려움. 다음 시나리오를 수동으로 검증:
1. `/cancel-qg` → 자기 세션 폴더만 삭제.
2. `/cancel-qg --gc` → 자기 + stale sibling 삭제.
3. `/cancel-qg --all` → confirm prompt 후 전체 삭제.

- [ ] **Step 3: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew && git add plugins/quality-gates/commands/cancel-qg.md && git commit -m "feat(quality-gates): cancel-qg supports --gc and --all flags"
```

### Task 15: Update `commands/qg.md`

**Files:**
- Modify: `plugins/quality-gates/commands/qg.md`

- [ ] **Step 1: Update --reset block and add --gc**

`commands/qg.md`에서 다음 두 섹션 변경:

A. `## Special argument: --reset` 섹션의 rm 블록 교체:

```markdown
## Special argument: `--reset`

`$ARGUMENTS` 가 `--reset` 포함 시 setup 안 돌리고 자기 세션 폴더 + legacy 파일 정리:

```!
SID="${CLAUDE_CODE_SESSION_ID:-}"
if [ -n "$SID" ]; then
  rm -rf ".claude/quality-gates/$SID"
fi
rm -f .claude/quality-gates.local.md \
      .claude/quality-gates-session.local.md \
      .claude/quality-gates-branch.local.md \
      .claude/qg-diff-cache.txt \
      .claude/qg-code-paths.tmp
```

종료 후 "Quality-gates state cleared." 보고.
```

B. `--gc` 신설 (Quick Reference 표 위에 새 섹션):

```markdown
## Special argument: `--gc`

`$ARGUMENTS` 가 `--gc` 포함 시 (단독 또는 다른 인자와 함께) TTL GC를 명시 실행:

```!
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/qg-gc.py"
```

`--gc` 단독: 종료. 다른 인자와 함께: GC 후 setup 진행.
```

C. Quick Reference 표에 행 추가:

```markdown
| `/qg --gc` | Run TTL GC on stale session folders |
```

D. `### Scope (default: session)` 단락의 path를 갱신:

```markdown
A PostToolUse hook (`post-tool-use-session-tracker.py`) accumulates touched
files into `.claude/quality-gates/<session-id>/files.md`. The pre-pipeline check
(`pre-pipeline-check.sh`) clears this file when the branch changes mid-session
or when 24+ hours pass without activity.
```

E. Pipeline Rules 마지막 bullet:
```markdown
- State tracked in `.claude/quality-gates/<session-id>/{pipeline,files,branch}.md` (managed by hook scripts; see plugin README)
```

- [ ] **Step 2: Manual smoke test**

수동: `/qg --reset`로 자기 폴더 + legacy 정리, `/qg --gc`로 TTL sweep.

- [ ] **Step 3: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew && git add plugins/quality-gates/commands/qg.md && git commit -m "feat(quality-gates): /qg --reset clears per-session folder, add --gc flag"
```

---

## Phase 5: Skill References

### Task 16: Update `state-file-format.md`

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md`

- [ ] **Step 1: Update path examples**

Read file first; in path-related lines, replace `.claude/quality-gates.local.md` with `.claude/quality-gates/<session-id>/pipeline.md` and update header to mention per-session layout.

- [ ] **Step 2: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew && git add plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md && git commit -m "docs(quality-gates): state-file-format references per-session paths"
```

### Task 17: Update `SKILL.md`

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`

- [ ] **Step 1: Find pre-pipeline-check call sites**

Search for `pre-pipeline-check.sh` and `quality-gates-session.local.md` references. Update any hardcoded path mention to per-session.

```bash
cd /Users/jeonghokim/Downloads/devbrew && grep -n "quality-gates.*local.md\|pre-pipeline-check" plugins/quality-gates/skills/quality-pipeline/SKILL.md
```

- [ ] **Step 2: Replace hardcoded paths**

For each hit, replace flat path with per-session path. The skill file uses paths in narrative — update narrative to reference `.claude/quality-gates/<session-id>/files.md` instead of `.claude/quality-gates-session.local.md`.

- [ ] **Step 3: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew && git add plugins/quality-gates/skills/quality-pipeline/SKILL.md && git commit -m "docs(quality-gates): SKILL.md references per-session paths"
```

---

## Phase 6: Docs + Version Bump + Citation Fixes

### Task 18: Bump `plugin.json` to 1.6.0

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`

- [ ] **Step 1: Edit version**

Replace `"version": "1.5.0"` (or whatever current is) with `"version": "1.6.0"`.

```bash
cd /Users/jeonghokim/Downloads/devbrew && python3 -c "
import json
p = 'plugins/quality-gates/.claude-plugin/plugin.json'
d = json.load(open(p))
print('current:', d.get('version'))
d['version'] = '1.6.0'
json.dump(d, open(p, 'w'), indent=2)
print('updated to 1.6.0')
"
```

- [ ] **Step 2: Verify**

```bash
cd /Users/jeonghokim/Downloads/devbrew && python3 -c "import json; print(json.load(open('plugins/quality-gates/.claude-plugin/plugin.json'))['version'])"
```

Expected: `1.6.0`.

### Task 19: Add CHANGELOG entry

**Files:**
- Modify: `plugins/quality-gates/CHANGELOG.md`

- [ ] **Step 1: Insert entry at top of changelog (under header)**

Read existing CHANGELOG to understand structure. Add new entry at the top of the version list:

```markdown
## [1.6.0] — 2026-05-08

### Added
- SessionEnd hook (`session-end-cleanup.py`) for graceful per-session state cleanup.
- `scripts/qg-gc.py`: TTL-based GC helper with `fcntl` lock, double-stat ns race guard, and rename-then-rmtree.
- Env: `DEVBREW_QG_TTL_HOURS` (default 24), `DEVBREW_QG_GC_VERBOSE` (default off).
- `/cancel-qg --gc` (TTL sweep) and `/cancel-qg --all` (full wipe with confirm + active-sibling listing).
- `/qg --gc` flag for explicit GC invocation.
- `setup-qg.sh --session-id <id>` argument as fallback when `CLAUDE_CODE_SESSION_ID` env var is unset.
- `post-tool-use.py` registered as PostToolUse(Bash) hook in `hooks.json` (was previously orphaned).

### Changed
- State moved from flat `.claude/quality-gates*.local.md` (5 files) to per-session `.claude/quality-gates/<session-id>/{pipeline,files,branch}.md` + `{diff-cache,code-paths}` files.
- `session-start-advisor.py` now scopes advice to current session only and is read-only (per CLAUDE.md "SessionStart never mutates" rule).
- `setup-qg.sh` hard-fails if neither `CLAUDE_CODE_SESSION_ID` nor `--session-id` is provided.
- `setup-qg.sh` now invokes `qg-gc.py` at start (best-effort; never aborts setup).
- `/qg --reset` now wipes the current session folder + legacy v1.5.0 files (was: only flat files).
- README "Principles Instantiated": fixed mis-citation of P21 → corrected to P5 (Filesystem as Memory) + P14 (State Survives Compaction) + §4.8 (State File). The state-file rule never lived in P21 (Security & Supply Chain).

### Fixed
- Concurrent sessions in the same project no longer corrupt each other's state (was: 5 shared `.claude/` files).
- Stale state from a crashed/closed session no longer triggers misleading "in-flight pipeline" advice in unrelated new sessions.
- `post-tool-use.py` now scopes its "active pipeline" check to the calling session only (was: any session blocked auto-trigger).

### Removed
- Flat per-project state file model. The 5 legacy files (`quality-gates.local.md`, `quality-gates-session.local.md`, `quality-gates-branch.local.md`, `qg-diff-cache.txt`, `qg-code-paths.tmp`) are unlinked on first `/qg` post-upgrade with a stderr warning.

### Migration
- `session-start-advisor` surfaces a one-time stdout message when legacy files are found (read-only — never deletes).
- In-flight v1.5.0 pipelines are not automatically migrated; the previous session_id is meaningful only to that prior session. Re-run `/qg`.
```

- [ ] **Step 2: Verify markdown**

```bash
cd /Users/jeonghokim/Downloads/devbrew && head -50 plugins/quality-gates/CHANGELOG.md
```

### Task 20: Fix README citation + update Pipeline state section

**Files:**
- Modify: `plugins/quality-gates/README.md`

- [ ] **Step 1: Find and fix P21 mis-citation**

```bash
cd /Users/jeonghokim/Downloads/devbrew && grep -n "P21" plugins/quality-gates/README.md
```

Replace any "P21 (Markdown state, not JSON)" or similar with: "P5 (Filesystem as Memory) + P14 (State Survives Compaction) + §4.8 (State File)".

- [ ] **Step 2: Update Pipeline state section**

Find the "Pipeline state is tracked in `.claude/`" paragraph and replace path references:

```markdown
### Pipeline state

State is tracked per Claude Code session in `.claude/quality-gates/<session-id>/`:
- `pipeline.md` — pipeline frontmatter (status, current_gate, iteration counters) + body (Gate Results, History).
- `files.md` — files edited in this session (used for `/qg` scope narrowing).
- `branch.md` — last seen git branch (for branch-mismatch detection).
- `diff-cache.txt`, `code-paths.tmp` — transient caches.

Stale sibling folders (mtime older than `DEVBREW_QG_TTL_HOURS`, default 24h) are
garbage-collected when `/qg` or `/cancel-qg --gc` runs. The `SessionStart` hook
is strictly read-only (per CLAUDE.md rule); the `SessionEnd` hook removes the
current session's folder on graceful close. Crashes fall back to the TTL sweep.
```

- [ ] **Step 3: Update Hooks Installed section**

Add SessionEnd entry, update SessionStart description to reflect read-only + sibling-aware behavior.

- [ ] **Step 4: Commit (combined doc updates)**

```bash
cd /Users/jeonghokim/Downloads/devbrew && git add plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md plugins/quality-gates/README.md && git commit -m "docs(quality-gates): v1.6.0 changelog, README per-session, fix P21→P5/P14/§4.8 cite"
```

### Task 21: Update philosophy doc §4.8

**Files:**
- Modify: `docs/philosophy/devbrew-harness-philosophy.md`

- [ ] **Step 1: Find §4.8 State File section**

```bash
cd /Users/jeonghokim/Downloads/devbrew && grep -n "^### 4.8" docs/philosophy/devbrew-harness-philosophy.md
```

- [ ] **Step 2: Add per-session subdir variant note**

In §4.8 body (after the existing "State는 `.claude/<plugin>.local.md`..." sentence), append:

```markdown
- per-session 격리가 필요하면 `.claude/<plugin>/<session-id>/...` 하위 디렉토리도 P5/P14 정합 유지하며 허용. 단 plugin namespace(`.claude/<plugin>/`) 하위에 머물러야 함. 사례: `quality-gates` (v1.6.0+) — 동시 세션 격리 + TTL GC + SessionEnd cleanup.
```

- [ ] **Step 3: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew && git add docs/philosophy/devbrew-harness-philosophy.md && git commit -m "docs(philosophy): §4.8 allow per-session subdir for state files"
```

### Task 22: Update CLAUDE.md Plugin Shape bullet

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Find the JSON-vs-markdown bullet**

```bash
cd /Users/jeonghokim/Downloads/devbrew && grep -n "JSON이 아니라 마크다운" CLAUDE.md
```

- [ ] **Step 2: Append per-session sub-clause to that bullet**

기존 문장 뒤에 한 줄 추가:

```markdown
**JSON이 아니라 마크다운 state.** State는 `.claude/<plugin>.local.md`에 살음 (git-ignored, 성공 시 auto-delete, 실패 시 디버깅을 위해 보존). per-session 격리가 필요하면 `.claude/<plugin>/<session-id>/...` 하위 디렉토리도 허용 — plugin namespace(`.claude/<plugin>/`) 하위에 머물 것 (§4.8 참조). **Secret 기록 금지** — placeholder 참조 사용 (철학 P21).
```

- [ ] **Step 3: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew && git add CLAUDE.md && git commit -m "docs(claude-md): plugin shape allows per-session subdir for state"
```

---

## Phase 7: E2E + Final Verification

### Task 23: Update `tests/e2e-scenarios.md`

**Files:**
- Modify: `plugins/quality-gates/tests/e2e-scenarios.md`

- [ ] **Step 1: Append v1.6.0 scenarios**

Add new scenarios at end of file:

```markdown
### Scenario: Concurrent sessions stay isolated (v1.6.0)

**Setup**: Two terminal sessions A and B in the same project. Both have valid `CLAUDE_CODE_SESSION_ID` env vars.

1. In A: `Edit` `/abs/a.py`. Verify `.claude/quality-gates/$SID_A/files.md` contains `/abs/a.py` only.
2. In B: `Edit` `/abs/b.py`. Verify `.claude/quality-gates/$SID_B/files.md` contains `/abs/b.py` only.
3. In A: Run `/qg`. Verify scope = files from A's tracker only.

### Scenario: Dormant session GC

**Setup**: Backdate a sibling session's `pipeline.md` mtime by 25 hours.

```bash
old=$(($(date +%s) - 25 * 3600))
touch -t "$(date -r $old +%Y%m%d%H%M)" .claude/quality-gates/oldsess0001/pipeline.md
touch -t "$(date -r $old +%Y%m%d%H%M)" .claude/quality-gates/oldsess0001
```

1. Run `/qg` (any flavor). Verify `.claude/quality-gates/oldsess0001/` no longer exists.
2. Set `DEVBREW_QG_GC_VERBOSE=1` and observe stdout: `[quality-gates] GC: removed 1 stale session folder(s)`.

### Scenario: Graceful SessionEnd

1. Start `/qg` in a session.
2. Close Claude Code gracefully (not kill -9).
3. Verify `.claude/quality-gates/$SID/` is gone.

### Scenario: Legacy migration on upgrade

**Setup**: Pre-existing v1.5.0 flat files (5 files) in `.claude/`.

1. Open Claude Code. Observe `session-start-advisor` stdout: `[quality-gates] Legacy v1.5.0 state files detected.`
2. Run `/qg`. Observe `setup-qg.sh` stderr: `Removed 5 legacy flat state file(s) from v1.5.0.`
3. Verify the 5 files are gone, new `.claude/quality-gates/$SID/pipeline.md` exists.

### Scenario: GC lock contention

1. Hold the lock from a shell:
```bash
exec 9>".claude/quality-gates/.gc.lock"; flock -n 9 || echo "fail"
# (keep shell open with lock held)
```
2. In another terminal, run `/qg --gc`. Should silently exit (GC skipped).

### Scenario: Kill switch globally disables

```bash
DEVBREW_DISABLE_QUALITY_GATES=1 /qg
```

1. Verify no `.claude/quality-gates/` folder created.
2. Verify SessionEnd hook noop.
3. Verify `qg-gc.py` exits 0 without action.
```

- [ ] **Step 2: Commit**

```bash
cd /Users/jeonghokim/Downloads/devbrew && git add plugins/quality-gates/tests/e2e-scenarios.md && git commit -m "test(quality-gates): e2e scenarios for v1.6.0 per-session state"
```

### Task 24: Run all tests

- [ ] **Step 1: Python tests**

```bash
cd /Users/jeonghokim/Downloads/devbrew && python3 -m unittest discover plugins/quality-gates/tests -v
```

Expected: all green. Specifically:
- test_qg_gc.py — 9 passing
- test_session_tracker.py — 9 passing
- test_session_start_advisor.py — 10 passing
- test_session_end_cleanup.py — 5 passing

- [ ] **Step 2: Bash tests**

```bash
/Users/jeonghokim/Downloads/devbrew/plugins/quality-gates/tests/test_setup_qg.sh
```

Expected: 0 failures.

- [ ] **Step 3: Lint check**

```bash
cd /Users/jeonghokim/Downloads/devbrew && python3 -m py_compile $(find plugins/quality-gates -name '*.py') && echo OK
```

Expected: `OK`.

- [ ] **Step 4: Validate JSON**

```bash
cd /Users/jeonghokim/Downloads/devbrew && python3 -c "import json; json.load(open('plugins/quality-gates/hooks/hooks.json'))" && \
python3 -c "import json; json.load(open('plugins/quality-gates/.claude-plugin/plugin.json'))" && echo OK
```

Expected: `OK`.

### Task 25: Manual verification of golden path

- [ ] **Step 1: Two-terminal isolation**

Open two terminal Claude Code sessions in this repo. In each:
1. Edit a different file (different paths).
2. Verify `.claude/quality-gates/<sid>/files.md` exists per session, paths isolated.
3. In one session run `/qg`. Verify scope only includes own session's edits.

- [ ] **Step 2: Stale advisor regression**

Simulate a crash:
1. In session A, run `/qg` to start a pipeline.
2. Force-quit Claude Code (or simulate by deleting only the live session, leaving folder).
3. Open new session B in same repo.
4. Verify B's SessionStart advisor does NOT show "in-flight pipeline" message.

- [ ] **Step 3: Legacy migration**

```bash
cd /Users/jeonghokim/Downloads/devbrew && touch .claude/quality-gates.local.md \
  .claude/quality-gates-session.local.md \
  .claude/quality-gates-branch.local.md \
  .claude/qg-diff-cache.txt \
  .claude/qg-code-paths.tmp
```

Open Claude Code. Verify advisor stdout mentions legacy. Run `/qg`. Verify all 5 files removed and new per-session folder created.

### Task 26: Final review and PR push

- [ ] **Step 1: Verify spec acceptance criteria**

Read `docs/superpowers/specs/2026-05-08-qg-per-session-state-design.md` Acceptance Criteria. Walk through each (1–10) and confirm coverage:

| AC | Covered by |
|----|------------|
| 1. concurrent isolation | test_session_tracker.test_two_sessions_isolated, e2e #1 |
| 2. stale advisor silent | test_session_start_advisor.test_other_session_active_silent_by_default |
| 3. TTL GC + double-stat + grace | test_qg_gc.test_old_folder_removed/test_grace_period |
| 4. setup-qg hard-fail | test_setup_qg.sh test 3 |
| 5. terminal rmtree | stop-hook smoke (Task 7 step 5); e2e covers |
| 6. SessionEnd graceful | test_session_end_cleanup |
| 7. legacy migration | test_setup_qg.sh test 4 + test_session_start_advisor.test_legacy_flat_state_warns |
| 8. kill switch in new entry points | test_qg_gc.test_kill_switch + test_session_end_cleanup.test_kill_switch |
| 9. --all confirm + listing | manual verification (cancel-qg.md spec) |
| 10. version bump + README cite fix | plugin.json + README.md committed |

- [ ] **Step 2: Self-review diff**

```bash
cd /Users/jeonghokim/Downloads/devbrew && git log --oneline main..HEAD
git diff main..HEAD --stat
```

Expected: ~25 commits, ~20 files changed.

- [ ] **Step 3: Push branch**

```bash
cd /Users/jeonghokim/Downloads/devbrew && git push -u origin feature/qg-per-session-state
```

- [ ] **Step 4: Open PR**

```bash
gh pr create --title "feat(quality-gates): per-session state (v1.6.0)" --body "$(cat <<'EOF'
## Summary
- Move quality-gates state from flat `.claude/quality-gates*.local.md` (5 files) to per-session `.claude/quality-gates/<session-id>/`.
- Fix concurrent-session corruption, stale advisor, legacy accumulation.
- Honor CLAUDE.md SessionStart-never-mutates rule: GC trigger moves to setup-qg.sh + explicit user commands.
- Fix P21 mis-citation (state-file rule lives in P5/P14/§4.8) in spec, plan, and README.

## Test plan
- [ ] `python3 -m unittest discover plugins/quality-gates/tests`
- [ ] `plugins/quality-gates/tests/test_setup_qg.sh`
- [ ] Two-terminal manual isolation test
- [ ] Stale advisor regression
- [ ] Legacy migration
- [ ] Kill switch
- [ ] /cancel-qg --all confirm gate

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 5: Mark plan task complete**

PR URL이 출력되면 사용자에게 보고. Plan 종료.
