"""AC4 — SessionEnd hook cleanup contract."""
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

HOOK = (Path(__file__).resolve().parent.parent / "hooks" / "session-end-cleanup.py").resolve()


def run_hook(payload, env_extra=None, cwd=None):
    env = {**os.environ}
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
        self.assertEqual(rc, 0)

    def test_3_json_decode_fail(self):
        rc, _, _ = run_hook(None)  # sends "not-json"
        self.assertEqual(rc, 0)
        self.assertTrue(self.folder.exists())

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
        self.assertFalse(self.folder.exists())
        self.assertIn("missing 'cwd'", stderr)

    def test_7_global_killswitch(self):
        rc, _, _ = run_hook(
            {"session_id": self.sid, "cwd": self.tmp},
            env_extra={"DEVBREW_DISABLE_SPEC_DISTILL": "1"},
        )
        self.assertEqual(rc, 0)
        self.assertTrue(self.folder.exists())

    def test_8_granular_killswitch(self):
        rc, _, _ = run_hook(
            {"session_id": self.sid, "cwd": self.tmp},
            env_extra={"DEVBREW_SKIP_HOOKS": "spec-distill:SessionEnd"},
        )
        self.assertEqual(rc, 0)
        self.assertTrue(self.folder.exists())


if __name__ == "__main__":
    unittest.main()
