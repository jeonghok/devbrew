"""AC5 — TTL-GC contract (qg-gc.py pattern adaptation + .gc-pending-* orphan sweep)."""
import os
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

GC = (Path(__file__).resolve().parent.parent / "scripts" / "spec-distill-gc.py").resolve()


def run_gc(env_extra=None, cwd=None):
    env = {**os.environ}
    for k in ("DEVBREW_SPEC_DISTILL_DISABLE", "DEVBREW_SKIP_HOOKS",
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

    def _make_session(self, sid, age_seconds):
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
        d.mkdir()  # empty folder, fresh ctime
        run_gc(cwd=self.tmp)
        self.assertTrue(d.exists())

    def test_5_charset_filter(self):
        # bad-charset dirs are skipped from iteration
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
        run_gc(env_extra={"DEVBREW_SPEC_DISTILL_DISABLE": "1"}, cwd=self.tmp)
        self.assertTrue(d.exists())

    def test_8_verbose(self):
        self._make_session("abc12345", 25 * 3600)
        rc, stdout, _ = run_gc(
            env_extra={"DEVBREW_SPEC_DISTILL_GC_VERBOSE": "1"}, cwd=self.tmp,
        )
        self.assertEqual(rc, 0)
        self.assertIn("removed", stdout)

    def test_9_empty_root(self):
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
        os.utime(orphan, (past, past))  # _sweep_gc_pending uses st_mtime (see docstring)
        run_gc(cwd=self.tmp)
        self.assertFalse(orphan.exists())  # swept

    def test_12_gc_pending_within_grace(self):
        # .gc-pending-* freshly created (< 60s) should NOT be swept
        recent = self.root / ".gc-pending-freshone"
        recent.mkdir()
        run_gc(cwd=self.tmp)
        self.assertTrue(recent.exists())

    def test_13_symlinked_child_untouched(self):
        # 루트 안의 링크 자식은 세션 폴더가 아니다 — 이름이 패턴에 맞고 링크 너머가 늙었어도
        # 건드리지 않는다(`.gc-pending-*` 로 개명하지도 않는다). 링크 너머도 이 임시 리포 안이다.
        outside = Path(self.tmp) / "outside-victim"
        outside.mkdir()
        f = outside / "notes.txt"
        f.write_text("x")
        past = time.time() - 25 * 3600
        os.utime(f, (past, past))
        link = self.root / "link-session-01"
        os.symlink(str(outside), link)
        self.assertEqual(os.path.realpath(link), os.path.realpath(outside))
        run_gc(cwd=self.tmp)
        self.assertTrue(link.is_symlink(), "링크 자식을 개명하거나 지웠다")
        self.assertTrue(f.exists())
        self.assertEqual([p.name for p in self.root.iterdir()
                          if p.name.startswith(".gc-pending-")], [])

    def test_14_symlinked_root_refused(self):
        # `.claude/spec-distill` 자신이 링크면 GC 는 락 파일도 만들지 않고 거부한다.
        import shutil
        shutil.rmtree(self.root)
        elsewhere = Path(self.tmp) / "elsewhere"
        stale = elsewhere / "abc12345"
        stale.mkdir(parents=True)
        f = stale / "state.local.md"
        f.write_text("x")
        past = time.time() - 25 * 3600
        os.utime(f, (past, past))
        os.symlink("../elsewhere", self.root)
        self.assertEqual(os.path.realpath(self.root), os.path.realpath(elsewhere))
        rc, _, stderr = run_gc(cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertTrue(stale.exists())
        self.assertFalse((elsewhere / ".gc.lock").exists())
        self.assertIn("GC 거부", stderr)


if __name__ == "__main__":
    unittest.main()
