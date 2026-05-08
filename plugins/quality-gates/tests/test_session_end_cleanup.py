"""Tests for the SessionEnd cleanup hook."""
import json
import os
import shutil
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
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

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
