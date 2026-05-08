"""Tests for scripts/qg-gc.py — TTL-based session-folder GC."""
import os
import shutil
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
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

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
        proc = run_gc(self.tmp)
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(new.exists(), msg="folders within ctime grace must not be GC'd")

    def test_kill_switch(self):
        old = make_session_dir(self.tmp, "killsess1234", mtime_offset_seconds=-25 * 3600)
        proc = run_gc(self.tmp, env_extra={"DEVBREW_DISABLE_QUALITY_GATES": "1"})
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(old.exists(), msg="kill switch must skip GC")

    def test_lock_contention_silent_exit(self):
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
