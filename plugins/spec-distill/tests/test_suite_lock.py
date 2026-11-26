#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""suite_lock.py — 지휘자의 스위트 대조와 하위 agent 의 전체 스위트가 같이 쓰는 공유 잠금(지휘자 수리 2).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_suite_lock.py
"""
from __future__ import annotations

import io
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from contextlib import redirect_stdout
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS))
import suite_lock as sl  # noqa: E402


def dead_pid() -> int:
    p = subprocess.Popen([sys.executable, "-c", "pass"])
    p.wait()
    return p.pid


class Lock(unittest.TestCase):
    def setUp(self):
        self.t = Path(tempfile.mkdtemp())
        self.d = sl.lock_path(self.t / "machine")

    def tearDown(self):
        shutil.rmtree(str(self.t), ignore_errors=True)

    def own(self, text):
        self.d.mkdir(parents=True, exist_ok=True)
        (self.d / "owner").write_text(text, encoding="utf-8")

    def test_path_is_under_machine_resource_folder(self):
        self.assertEqual(self.d, self.t / "machine" / "files" / "suite-lock")

    def test_take_and_drop(self):
        sl.take(self.d, "conductor-fix2", say=lambda m: None)
        s = sl.state(self.d)
        self.assertTrue(s["busy"])
        self.assertEqual(s["pid"], os.getpid())
        self.assertIn("conductor-fix2", s["owner"])
        sl.drop(self.d)
        self.assertFalse(self.d.exists())

    def test_drop_keeps_someone_elses_lock(self):
        self.own("%d other t\n" % dead_pid())
        sl.drop(self.d)
        self.assertTrue(self.d.exists())

    def test_live_owner_is_busy_and_described(self):
        self.own("%d impl-agent 2026-10-19 08:07:00\n" % os.getppid())
        with self.assertRaises(sl.Busy) as cm:
            sl.take(self.d, "me", say=lambda m: None)
        self.assertIn("impl-agent", str(cm.exception))
        self.assertIn("잡은 시각", str(cm.exception))

    def test_dead_owner_is_freed_loudly(self):
        self.own("%d gone t\n" % dead_pid())
        said = []
        sl.take(self.d, "me", say=said.append)
        self.assertTrue(any("주인 없는 잠금을 풀었다" in m for m in said), said)
        self.assertEqual(sl.state(self.d)["pid"], os.getpid())

    def test_owner_without_pid_is_never_stolen(self):
        self.own("conductor merge_check feature/x\n2026-10-19 11:48:05\n")
        old = time.time() - 3600
        os.utime(str(self.d), (old, old))
        with self.assertRaises(sl.Busy):
            sl.take(self.d, "me", say=lambda m: None)
        self.assertIn("conductor merge_check", (self.d / "owner").read_text(encoding="utf-8"))

    def test_young_lock_without_owner_is_busy_old_one_is_freed(self):
        self.d.mkdir(parents=True)
        with self.assertRaises(sl.Busy):
            sl.take(self.d, "me", say=lambda m: None)
        old = time.time() - sl.LOCK_YOUNG - 5
        os.utime(str(self.d), (old, old))
        sl.take(self.d, "me", say=lambda m: None)
        self.assertEqual(sl.state(self.d)["pid"], os.getpid())

    def test_wait_queues_until_released(self):
        self.own("%d holder t\n" % os.getppid())
        sl_poll = sl.POLL
        sl.POLL = 0.2
        said = []

        def release():
            time.sleep(0.6)
            shutil.rmtree(str(self.d))
        th = threading.Thread(target=release)
        th.start()
        try:
            sl.take(self.d, "me", wait=10, say=said.append)
        finally:
            sl.POLL = sl_poll
            th.join()
        self.assertTrue(any("기다린다(줄)" in m for m in said), said)
        self.assertEqual(sl.state(self.d)["pid"], os.getpid())

    def test_stale_judgement_raced_by_a_new_holder_is_restored(self):
        """주인 없음을 판정한 뒤 다른 쪽이 새로 잡은 잠금을 옮겼으면 되돌린다 — 살아 있는 잠금을 훔치지 않는다."""
        self.own("%d gone t\n" % dead_pid())
        real_rename = os.rename
        swapped = []

        def racing_rename(src, dst):
            if not swapped and str(src) == str(self.d):
                swapped.append(1)  # 판정과 옮기기 사이에 다른 쪽이 풀고 새로 잡는다
                shutil.rmtree(str(self.d))
                self.d.mkdir()
                (self.d / "owner").write_text("%d racer t\n" % os.getppid(), encoding="utf-8")
            return real_rename(src, dst)
        sl.os.rename = racing_rename
        try:
            with self.assertRaises(sl.Busy):
                sl.take(self.d, "me", say=lambda m: None)
        finally:
            sl.os.rename = real_rename
        self.assertIn("racer", (self.d / "owner").read_text(encoding="utf-8"))

    def test_restore_loop_is_bounded(self):
        """되돌린 잠금이 계속 「다른 것」 으로 보이는 파일시스템에서도 끝없이 돌지 않는다."""
        self.own("%d gone t\n" % dead_pid())
        real_state = sl.state

        def drifting(d):
            s = real_state(d)
            if s["held"]:
                s = dict(s, ident=("drift", time.time()))  # 옮긴 뒤 비교가 늘 어긋난다
            return s
        real_rename = os.rename
        calls = []

        def counting(src, dst):
            calls.append(1)
            return real_rename(src, dst)
        sl.state = drifting
        sl.os.rename = counting
        try:
            with self.assertRaises(sl.Busy) as cm:
                sl.take(self.d, "me", say=lambda m: None)
        finally:
            sl.state = real_state
            sl.os.rename = real_rename
        self.assertIn("경합했다", str(cm.exception))
        self.assertLessEqual(len(calls), 2 * (sl.RESTORE_MAX + 1), "되돌리기가 상한을 넘어 돌았다")
        self.assertTrue(self.d.exists())

    def _bounded(self, fn, seconds=10):
        import signal

        def boom(*_a):
            raise AssertionError("take() 이 %d초 안에 끝나지 않았다(쉬지 않고 같은 자리를 돈다)" % seconds)
        old = signal.signal(signal.SIGALRM, boom)
        signal.alarm(seconds)
        try:
            return fn()
        finally:
            signal.alarm(0)
            signal.signal(signal.SIGALRM, old)

    def _unmovable_stale(self):
        """주인 프로세스가 끝난 잠금 — 부모 폴더에 쓰기 권한이 없어 옮기지(rename) 못한다."""
        self.own("%d gone t\n" % dead_pid())
        os.chmod(str(self.d.parent), 0o555)
        self.addCleanup(os.chmod, str(self.d.parent), 0o755)

    def test_unmovable_stale_lock_stops_with_reason(self):
        self._unmovable_stale()
        with self.assertRaises(sl.Busy) as cm:
            self._bounded(lambda: sl.take(self.d, "me", wait=0, say=lambda m: None))
        self.assertIn("주인 없는 잠금을 옮기지 못했다", str(cm.exception))
        self.assertIn("PermissionError", str(cm.exception))
        self.assertTrue(cm.exception.stuck, "기다려도 풀리지 않는 갈래로 표시한다")
        self.assertTrue((self.d / "owner").is_file(), "옮기지 못한 잠금은 그대로다")

    def _rival_moves_first(self):
        """주인 없는 잠금을 옮기려는 순간 다른 쪽이 먼저 옮기고 새로 잡았다 — 이쪽 rename 은 FileNotFoundError."""
        self.own("%d gone t\n" % dead_pid())
        real = sl.os.rename

        def rival(src, dst):
            sl.os.rename = real
            real(src, src + ".rival-stale")
            Path(src).mkdir()
            (Path(src) / "owner").write_text("%d rival t\n" % os.getppid(), encoding="utf-8")
            raise FileNotFoundError(src)
        sl.os.rename = rival
        self.addCleanup(setattr, sl.os, "rename", real)

    def test_rival_moving_stale_lock_first_is_plain_busy(self):
        self._rival_moves_first()
        with self.assertRaises(sl.Busy) as cm:
            self._bounded(lambda: sl.take(self.d, "me", wait=0, say=lambda m: None))
        self.assertNotIn("옮기지 못했다", str(cm.exception))
        self.assertIn("rival", str(cm.exception), "새 주인을 보인다")
        self.assertFalse(cm.exception.stuck)

    def test_rival_moving_stale_lock_first_waits_without_rename_notice(self):
        self._rival_moves_first()
        said = []
        with self.assertRaises(sl.Busy):
            self._bounded(lambda: sl.take(self.d, "me", wait=0.6, say=said.append))
        self.assertFalse(any("옮기지 못했다" in m for m in said), said)
        self.assertTrue(any("rival" in m for m in said), "바쁜 잠금으로 줄을 선다: %r" % said)

    def test_unmovable_stale_lock_honours_wait_and_sleeps(self):
        self._unmovable_stale()
        poll, sleeps, real_sleep = sl.POLL, [], sl.time.sleep
        sl.POLL = 0.2
        self.addCleanup(setattr, sl, "POLL", poll)
        sl.time.sleep = lambda x: (sleeps.append(x), real_sleep(x))
        self.addCleanup(setattr, sl.time, "sleep", real_sleep)
        said, start = [], time.time()
        with self.assertRaises(sl.Busy):
            self._bounded(lambda: sl.take(self.d, "me", wait=1, say=said.append))
        self.assertGreaterEqual(time.time() - start, 0.9, "기다림 시간을 지킨다")
        self.assertTrue(sleeps and all(x > 0 for x in sleeps), "다시 보기 전에 쉰다")
        self.assertLessEqual(len(sleeps), 20, "쉬는 간격으로 돈다 — 바쁘게 돌지 않는다")
        self.assertEqual(sum("옮기지 못했다" in m for m in said), 1, "기다리는 이유를 한 번 알린다: %r" % said)

    def test_describe_empty(self):
        self.assertEqual(sl.describe(self.d), "스위트 잠금: 비어 있음")


class Cli(unittest.TestCase):
    def setUp(self):
        self.t = Path(tempfile.mkdtemp())
        self.d = self.t / "lock"

    def tearDown(self):
        shutil.rmtree(str(self.t), ignore_errors=True)

    def cli(self, *args):
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = sl.main(list(args))
        return rc, buf.getvalue()

    def test_run_returns_command_rc_and_releases(self):
        rc, out = self.cli("run", "--lock", str(self.d), "--owner", "a", "--", sys.executable, "-c",
                           "import sys, os; sys.exit(3 if os.path.isdir(sys.argv[1]) else 9)", str(self.d))
        self.assertEqual(rc, 3, out)  # 명령이 도는 동안 잠금이 있었다
        self.assertFalse(self.d.exists())
        self.assertIn("풀었다", out)

    def test_run_busy_returns_busy_rc_with_owner(self):
        self.d.mkdir()
        (self.d / "owner").write_text("%d holder t\n" % os.getppid(), encoding="utf-8")
        rc, out = self.cli("run", "--lock", str(self.d), "--owner", "a", "--", sys.executable, "-c", "pass")
        self.assertEqual(rc, sl.BUSY_RC, out)
        self.assertIn("holder", out)
        self.assertTrue(self.d.exists())

    def test_run_unwritable_lock_folder_is_its_own_exit_code(self):
        ro = self.t / "ro"
        ro.mkdir()
        os.chmod(str(ro), 0o500)
        try:
            rc, out = self.cli("run", "--lock", str(ro / "sub" / "lock"), "--owner", "a", "--", sys.executable, "-c", "pass")
        finally:
            os.chmod(str(ro), 0o755)
        self.assertEqual(rc, sl.NO_LOCK_RC, out)
        self.assertIn("잠금 폴더에 쓰지 못했다", out)

    def test_run_unmovable_stale_lock_is_no_lock_rc_not_busy(self):
        self.d.mkdir()
        (self.d / "owner").write_text("%d gone t\n" % dead_pid(), encoding="utf-8")
        os.chmod(str(self.t), 0o555)
        try:
            rc, out = self.cli("run", "--lock", str(self.d), "--owner", "a", "--", sys.executable, "-c", "pass")
        finally:
            os.chmod(str(self.t), 0o755)
        self.assertEqual(rc, sl.NO_LOCK_RC, out)
        self.assertIn("옮기지 못했다", out)

    def test_run_without_command_is_usage(self):
        rc, _out = self.cli("run", "--lock", str(self.d), "--owner", "a")
        self.assertEqual(rc, 2)

    def test_sigterm_stops_suite_and_releases(self):
        mark = self.t / "child-alive"
        pidf = self.t / "grandchild.pid"
        child = ("import os, time, pathlib, sys\np = pathlib.Path(sys.argv[1])\n"
                 "pathlib.Path(sys.argv[2]).write_text(str(os.getpid()))\np.write_text('x')\ntime.sleep(30)\n")
        script = self.t / "g.py"
        script.write_text(child, encoding="utf-8")
        # bash -c 의 복합 명령 — 손자(파이썬)까지 멈춰야 한다
        inner = "'%s' '%s' '%s' '%s'; true" % (sys.executable, script, mark, pidf)
        p = subprocess.Popen([sys.executable, str(SCRIPTS / "suite_lock.py"), "run", "--lock", str(self.d), "--owner", "a",
                              "--", "bash", "-c", inner], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        for _ in range(100):
            if mark.exists():
                break
            time.sleep(0.1)
        self.assertTrue(self.d.exists())
        p.terminate()
        p.wait(timeout=20)
        self.assertFalse(self.d.exists(), "SIGTERM 뒤 잠금이 남았다")
        self.assertEqual(p.returncode, 143)
        gpid = int(pidf.read_text(encoding="utf-8"))
        for _ in range(50):
            try:
                os.kill(gpid, 0)
            except ProcessLookupError:
                break
            time.sleep(0.1)
        else:
            os.kill(gpid, 9)
            self.fail("손자 프로세스(스위트)가 잠금 밖에 남았다")

    def test_show(self):
        rc, out = self.cli("show", "--lock", str(self.d))
        self.assertEqual((rc, out.strip()), (0, "스위트 잠금: 비어 있음"))

    # ── 잠금 꼴이 아닌 것은 치우지 않는다(AC26) ──────────────────────────────

    def _age(self, p):
        old = time.time() - sl.LOCK_YOUNG - 5
        os.utime(str(p), (old, old), follow_symlinks=False)

    def _run_marking(self, *extra):
        """잠금을 잡으면 표시 파일을 쓰는 명령으로 run 을 부른다 — (rc, 출력, 표시 파일)."""
        mark = self.t / "ran"
        rc, out = self.cli("run", "--lock", str(self.d), "--owner", "a", *extra, "--", sys.executable, "-c",
                           "import pathlib, sys; pathlib.Path(sys.argv[1]).write_text('x')", str(mark))
        return rc, out, mark

    def _refused(self, rc, out, mark):
        self.assertEqual(rc, sl.NO_LOCK_RC, out)
        self.assertIn("[suite-lock] 잠금을 잡지 못했다 — 잠금 자리에 잠금이 아닌 것이 있다(%s) — 치우지 않는다"
                      % self.d, out)
        self.assertFalse(mark.exists(), "잠금 꼴이 아닌 자리에서 명령이 돌았다")
        self.assertEqual(sorted(p.name for p in self.t.iterdir() if ".stale-" in p.name), [], "옮겨진 것이 있다")

    def test_old_dir_with_other_file_not_removed(self):
        self.d.mkdir()
        (self.d / "report.md").write_text("keep\n", encoding="utf-8")
        self._age(self.d)
        rc, out, mark = self._run_marking()
        self._refused(rc, out, mark)
        self.assertEqual((self.d / "report.md").read_text(encoding="utf-8"), "keep\n")
        self.assertEqual(sorted(os.listdir(str(self.d))), ["report.md"])

    def test_dead_owner_dir_with_other_file_not_removed(self):
        self.d.mkdir()
        (self.d / "owner").write_text("%d gone t\n" % dead_pid(), encoding="utf-8")
        (self.d / "notes.txt").write_text("keep\n", encoding="utf-8")
        rc, out, mark = self._run_marking()
        self._refused(rc, out, mark)
        self.assertEqual(sorted(os.listdir(str(self.d))), ["notes.txt", "owner"])
        self.assertEqual((self.d / "notes.txt").read_text(encoding="utf-8"), "keep\n")

    def test_plain_file_at_lock_path_not_moved(self):
        self.d.write_text("not a lock\n", encoding="utf-8")
        for aged in (False, True):   # 나이와 무관하다 — 갓 생긴 파일도 바쁜 잠금으로 보지 않는다
            if aged:
                self._age(self.d)
            rc, out, mark = self._run_marking()
            self._refused(rc, out, mark)
            self.assertTrue(self.d.is_file())
            self.assertEqual(self.d.read_text(encoding="utf-8"), "not a lock\n")

    def test_owner_named_folder_is_not_lock_shaped(self):
        """`owner` 이름 하나뿐이어도 폴더면 잠금 꼴이 아니다 — 그 안의 것이 지워지지 않는다."""
        (self.d / "owner").mkdir(parents=True)
        (self.d / "owner" / "data.txt").write_text("keep\n", encoding="utf-8")
        self._age(self.d)
        rc, out, mark = self._run_marking()
        self._refused(rc, out, mark)
        self.assertEqual((self.d / "owner" / "data.txt").read_text(encoding="utf-8"), "keep\n")

    def test_symlink_at_lock_path_is_not_lock_shaped(self):
        """잠금 자리가 폴더를 가리키는 링크면(빈 폴더라도 · 나이와 무관하게) 링크도 대상도 건드리지 않는다."""
        target = self.t / "elsewhere"
        target.mkdir()
        os.symlink(str(target), str(self.d))
        for aged in (False, True):
            if aged:
                self._age(target)
                self._age(self.d)
            rc, out, mark = self._run_marking()
            self._refused(rc, out, mark)
            self.assertTrue(self.d.is_symlink())
            self.assertTrue(target.is_dir())

    def test_dangling_symlink_at_lock_path_is_refused(self):
        """대상이 없는 링크도 잠금 꼴이 아니다 — 같은 자리를 끝없이 돌지 않고 3 으로 끝나며 링크는 그대로다."""
        os.symlink(str(self.t / "nowhere"), str(self.d))
        mark = self.t / "ran"
        try:
            p = subprocess.run([sys.executable, str(SCRIPTS / "suite_lock.py"), "run", "--lock", str(self.d), "--owner", "a",
                                "--", sys.executable, "-c", "import pathlib, sys; pathlib.Path(sys.argv[1]).write_text('x')",
                                str(mark)], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=10)
        except subprocess.TimeoutExpired:
            self.fail("대상 없는 링크 자리에서 10초 안에 끝나지 않았다")
        self._refused(p.returncode, p.stdout.decode("utf-8"), mark)
        self.assertTrue(self.d.is_symlink())
        self.assertFalse((self.t / "nowhere").exists())

    def test_unreadable_old_dir_is_not_cleared(self):
        """안을 읽지 못하는 폴더는 잠금 꼴인지 알 수 없어 치우지 않는다."""
        self.d.mkdir()
        (self.d / "report.md").write_text("keep\n", encoding="utf-8")
        self._age(self.d)
        os.chmod(str(self.d), 0o000)
        try:
            rc, out, mark = self._run_marking()
        finally:
            for p in [self.d] + [p for p in self.t.iterdir() if ".stale-" in p.name]:
                if os.path.lexists(str(p)):
                    os.chmod(str(p), 0o755)
        self._refused(rc, out, mark)
        self.assertEqual((self.d / "report.md").read_text(encoding="utf-8"), "keep\n")

    def test_empty_or_owner_only_stale_still_cleared(self):
        self.d.mkdir()
        self._age(self.d)
        rc, out, mark = self._run_marking()
        self.assertEqual(rc, 0, out)
        self.assertTrue(mark.exists(), "빈 주인 없는 잠금을 치우고 명령이 돈다")
        self.assertIn("주인 없는 잠금을 풀었다", out)
        self.assertFalse(self.d.exists())
        mark.unlink()
        self.d.mkdir()
        (self.d / "owner").write_text("%d gone t\n" % dead_pid(), encoding="utf-8")
        rc, out, mark = self._run_marking()
        self.assertEqual(rc, 0, out)
        self.assertTrue(mark.exists(), "owner 하나만 든 주인 없는 잠금을 치우고 명령이 돈다")
        self.assertIn("주인 없는 잠금을 풀었다", out)
        self.assertEqual(sorted(p.name for p in self.t.iterdir() if ".stale-" in p.name), [])

    def test_fresh_dir_with_other_file_refused_without_wait(self):
        """갓 생긴(60초 안) 폴더라도 owner 말고 다른 것이 들었으면 바쁜 잠금으로 기다리지 않고 3 으로 끝난다."""
        self.d.mkdir()
        (self.d / "report.md").write_text("keep\n", encoding="utf-8")
        start = time.time()
        rc, out, mark = self._run_marking("--wait", "30")
        self.assertLess(time.time() - start, 5, "잠금 꼴이 아닌 폴더에서 기다렸다")
        self._refused(rc, out, mark)
        self.assertEqual((self.d / "report.md").read_text(encoding="utf-8"), "keep\n")

    def test_no_wait_on_non_lock(self):
        for make in ("dir", "file"):
            if make == "dir":
                self.d.mkdir()
                (self.d / "report.md").write_text("keep\n", encoding="utf-8")
            else:
                self.d.write_text("x\n", encoding="utf-8")
            self._age(self.d)
            start = time.time()
            rc, out, _mark = self._run_marking("--wait", "30")
            self.assertLess(time.time() - start, 5, "%s: 잠금 꼴이 아닌 자리에서 기다렸다" % make)
            self.assertEqual(rc, sl.NO_LOCK_RC, out)
            if make == "dir":
                shutil.rmtree(str(self.d))
            else:
                self.d.unlink()


if __name__ == "__main__":
    unittest.main()
