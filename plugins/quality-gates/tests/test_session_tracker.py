"""Tests for the post-tool-use session-tracker hook."""
import json
import os
import shutil
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
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

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
        env = {"DEVBREW_QUALITY_GATES_DISABLE": "1"}
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
        gates_root = Path(self.tmp) / ".claude" / "quality-gates"
        self.assertFalse(gates_root.exists() and any(gates_root.iterdir()))


if __name__ == "__main__":
    unittest.main()
