"""AC5 — TTL-GC contract (qg-gc.py pattern adaptation + .gc-pending-* orphan sweep)."""
import fcntl
import os
import shutil
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

GC = (Path(__file__).resolve().parent.parent / "scripts" / "spec-distill-gc.py").resolve()


def run_gc(env_extra=None, cwd=None, cmd=None):
    env = {**os.environ}
    for k in ("DEVBREW_SPEC_DISTILL_DISABLE", "DEVBREW_SKIP_HOOKS",
              "DEVBREW_SPEC_DISTILL_TTL_HOURS", "DEVBREW_SPEC_DISTILL_GC_VERBOSE",
              "CLAUDE_CODE_SESSION_ID"):
        env.pop(k, None)
    if env_extra:
        env.update(env_extra)
    cp = subprocess.run(
        cmd or ["python3", str(GC)],
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


class GcLockLeafTest(unittest.TestCase):
    """저장소가 `.claude/spec-distill/.gc.lock` 을 링크나 디렉토리로 커밋해도 GC 는 그 이름을 열지 않는다.

    락은 루트 디렉토리 자신이다. 심는 링크 · 센티널 · 유령 경로는 전부 이 테스트가 만든 임시
    디렉토리 `P` 안이고(클론은 `P/clone`, 센티널은 클론 밖 `P/`), GC 를 띄우기 전에 링크가
    `P` 안으로 풀리는지 확인한다 — 저장소나 $HOME 을 가리키는 것은 없다.
    """

    def setUp(self):
        tmp_root = os.path.realpath(tempfile.gettempdir())
        base = os.path.realpath(tempfile.mkdtemp(prefix="sd-gc-lockleaf-"))
        if not (base and os.path.isabs(base) and os.path.isdir(base)
                and base.startswith(tmp_root + os.sep)):
            raise RuntimeError(f"임시 디렉토리가 이상하다: {base!r} (tmp={tmp_root!r})")
        self.P = Path(base)
        self.clone = self.P / "clone"
        self.clone.mkdir()
        subprocess.run(["git", "init", "-q"], cwd=self.clone, check=True)
        self.root = self.clone / ".claude" / "spec-distill"
        self.root.mkdir(parents=True)
        self.lock = self.root / ".gc.lock"

    def tearDown(self):
        shutil.rmtree(self.P, ignore_errors=True)

    def _stale(self, sid="stale-lockleaf-01"):
        d = self.root / sid
        d.mkdir()
        f = d / "state.local.md"
        f.write_text("x")
        past = time.time() - 25 * 3600
        os.utime(f, (past, past))
        return d

    def _plant_link(self, name):
        """`.gc.lock -> ../../../<name>` — 계측기 바닥: `P/<name>` 으로 풀리지 않으면 GC 를 띄우지 않는다."""
        os.symlink(os.path.join("..", "..", "..", name), self.lock)
        real = os.path.realpath(self.lock)
        want = str(self.P / name)
        if real != want or not real.startswith(str(self.P) + os.sep):
            raise RuntimeError(f"링크가 {real!r} 로 풀린다 — 기대 {want!r} (P={self.P})")
        return Path(want)

    def test_a_lock_link_to_outside_file_untouched(self):
        sentinel = self.P / "sentinel.txt"
        sentinel.write_bytes(b"precious line 1\nprecious line 2\n")
        past = time.time() - 3600
        os.utime(sentinel, (past, past))
        before = (sentinel.read_bytes(), os.stat(sentinel).st_mtime_ns)
        self.assertEqual(self._plant_link("sentinel.txt"), sentinel)
        stale = self._stale()
        p_before = sorted(os.listdir(self.P))
        rc, _, _ = run_gc(cwd=str(self.clone))
        self.assertEqual(rc, 0)
        self.assertEqual(sentinel.read_bytes(), before[0],
                         "심은 .gc.lock 링크를 따라 저장소 밖 파일을 잘랐다")
        self.assertEqual(os.stat(sentinel).st_mtime_ns, before[1],
                         "심은 .gc.lock 링크를 따라 저장소 밖 파일을 건드렸다(touch)")
        self.assertTrue(self.lock.is_symlink(), "심은 링크를 바꿨다")
        self.assertFalse(stale.exists(), "GC 가 돌지 않았다 — 위 단언들이 공허하다")
        self.assertEqual(sorted(os.listdir(self.root)), [".gc.lock"],
                         "GC 가 루트에 심은 링크 말고 다른 이름을 남겼다")
        self.assertEqual(sorted(os.listdir(self.P)), p_before, "GC 가 저장소 밖 목록을 바꿨다")

    def test_b_dangling_lock_link_target_not_created(self):
        ghost = self._plant_link("ghost.txt")
        self.assertFalse(os.path.lexists(ghost))
        stale = self._stale()
        p_before = sorted(os.listdir(self.P))
        rc, _, _ = run_gc(cwd=str(self.clone))
        self.assertEqual(rc, 0)
        self.assertEqual(sorted(os.listdir(self.P)), p_before,
                         "매달린 .gc.lock 링크를 따라 저장소 밖에 파일을 만들었다")
        self.assertFalse(stale.exists(), "GC 가 돌지 않았다 — 위 단언이 공허하다")
        self.assertEqual(sorted(os.listdir(self.root)), [".gc.lock"],
                         "GC 가 루트에 심은 링크 말고 다른 이름을 남겼다")

    def test_c_lock_name_as_directory_gc_still_runs(self):
        self.lock.mkdir()
        stale = self._stale()
        rc, _, stderr = run_gc(cwd=str(self.clone))
        self.assertEqual(rc, 0)
        self.assertFalse(stale.exists(),
                         f"디렉토리로 심은 .gc.lock 이 GC 를 멈췄다 — stderr: {stderr.strip()}")
        self.assertTrue(self.lock.is_dir())
        self.assertEqual(sorted(os.listdir(self.root)), [".gc.lock"],
                         "GC 가 루트에 심은 디렉토리 말고 다른 이름을 남겼다")

    def test_d_real_root_no_lock_file_and_collects(self):
        stale = self._stale()
        rc, _, _ = run_gc(cwd=str(self.clone))
        self.assertEqual(rc, 0)
        self.assertFalse(stale.exists())
        self.assertEqual(sorted(os.listdir(self.root)), [],
                         "GC 가 루트에 파일을 남겼다 — 고정 이름 파일을 만드는 경로가 살아 있다")

    def test_e_root_dir_lock_held_elsewhere_gc_yields(self):
        # 락이 실제로 루트 디렉토리에 걸리는가 — 다른 프로세스가 쥐고 있으면 GC 는 비켜선다.
        stale = self._stale()
        dfd = os.open(self.root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            fcntl.flock(dfd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            rc, _, stderr = run_gc(cwd=str(self.clone))
            self.assertEqual(rc, 0)
            self.assertTrue(stale.exists(), "루트 디렉토리 락을 쥔 동안 GC 가 지웠다 — 락이 걸리지 않는다")
            self.assertEqual(stderr, "", "경합으로 비켜서는 GC 가 줄을 냈다 — 경합은 조용해야 한다")
        finally:
            os.close(dfd)
        run_gc(cwd=str(self.clone))
        self.assertFalse(stale.exists(), "락을 놓은 뒤에도 GC 가 돌지 않았다")

    def test_f_flock_failure_announced(self):
        # 경합이 아닌 flock 실패(OSError)는 조용히 넘기지 않는다 — GC 를 건너뛴 사실을 stderr 에 낸다.
        stale = self._stale()
        code = (
            "import errno, fcntl, runpy, sys\n"
            "def _boom(*a, **k):\n"
            "    raise OSError(errno.EBADF, 'Bad file descriptor')\n"
            "fcntl.flock = _boom\n"
            "sys.argv = sys.argv[1:]\n"
            "runpy.run_path(sys.argv[0], run_name='__main__')\n"
        )
        rc, _, stderr = run_gc(cwd=str(self.clone), cmd=["python3", "-c", code, str(GC)])
        self.assertEqual(rc, 0, stderr)
        self.assertIn("GC 건너뜀 — state root 락 실패", stderr)
        self.assertTrue(stale.exists(), "락을 못 잡았는데 GC 가 돌았다")

    def test_g_root_regular_file_refused(self):
        # 저장소가 `.claude/spec-distill` 을 일반 파일로 커밋하면 GC 는 추적 없이 거부 줄로 끝난다.
        self.root.rmdir()
        self.root.write_text("not a directory\n")
        git = ["git", "-c", "user.email=t@t", "-c", "user.name=t"]
        subprocess.run(git + ["add", "-A"], cwd=self.clone, check=True)
        subprocess.run(git + ["commit", "-qm", "root as file"], cwd=self.clone, check=True)
        rc, _, stderr = run_gc(cwd=str(self.clone))
        self.assertEqual(rc, 0, stderr)
        self.assertIn("GC 거부", stderr)
        self.assertNotIn("Traceback", stderr)
        self.assertEqual(self.root.read_text(), "not a directory\n")


if __name__ == "__main__":
    unittest.main()
