import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import suite_peers  # noqa: E402

PEERS = os.path.join(HERE, "suite_peers.py")


def clean_env(**extra):
    env = dict(os.environ)
    env.pop("SUITE_TIMING_FILE", None)
    env.pop("SUITE_PEERS_PS_FILE", None)
    env.update(extra)
    return env


def run_peers(args, ps_file=None):
    extra = {}
    if ps_file is not None:
        extra["SUITE_PEERS_PS_FILE"] = ps_file
    return subprocess.run([sys.executable, PEERS] + args, env=clean_env(**extra),
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          universal_newlines=True, timeout=60)


def wait_for_files(paths, limit=10.0):
    end = time.monotonic() + limit
    while time.monotonic() < end:
        if all(os.path.exists(p) and os.path.getsize(p) > 0 for p in paths):
            return True
        time.sleep(0.05)
    return False


def read_pid(path):
    with open(path, encoding="utf-8") as fh:
        return int(fh.read().strip())


def kill_quiet(pid):
    try:
        os.kill(pid, signal.SIGKILL)
    except (ProcessLookupError, PermissionError):
        pass


class PeerCountTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="suite-peers-test-")
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def ps_file(self, text):
        path = os.path.join(self.tmp, "ps.txt")
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)
        return path

    def test_is_runner_cases(self):
        yes = ["bash /r/tools/suite/run-all.sh", "/bin/bash ./tools/suite/run-all.sh",
               "-bash tools/suite/run-all.sh", "bash /Users/x/My Folder/tools/suite/run-all.sh",
               "sh -e tools/suite/run-all.sh"]
        no = ["bash -c bash tools/suite/run-all.sh",
              "python3 suite_lock.py run --lock L --owner o -- bash -c bash tools/suite/run-all.sh",
              "bash shared/tests/test_x.sh", "vim tools/suite/run-all.sh", "bash tools/suite/run-all.sh.bak", ""]
        for c in yes:
            self.assertTrue(suite_peers.is_runner(c), c)
        for c in no:
            self.assertFalse(suite_peers.is_runner(c), c)

    def test_peer_pids_fake_rows(self):
        R = "bash /w/tools/suite/run-all.sh"
        self.assertEqual(suite_peers.peer_pids([], 50), [])
        # 다른 러너 하나와 그 하위 셸(같은 명령줄) -> 하나
        rows = [(1, 0, "launchd"), (100, 1, R), (101, 100, R), (102, 101, "bash shared/tests/test_a.sh")]
        self.assertEqual(suite_peers.peer_pids(rows, 50), [100])
        # 자기 자신 · 자기 하위 셸 · 자기를 감싼 조상 러너만 -> 0
        rows = [(1, 0, "launchd"), (40, 1, R), (45, 40, "python3 x.py"), (50, 45, R), (51, 50, R)]
        self.assertEqual(suite_peers.peer_pids(rows, 50), [])
        # 다른 바퀴 안에서 테스트가 돌린 안쪽 러너 -> 바깥 하나만
        rows = [(1, 0, "launchd"), (200, 1, R), (210, 200, "python3 run_unittest_dir.py tools/suite"),
                (220, 210, "bash /tmp/t/tools/suite/run-all.sh")]
        self.assertEqual(suite_peers.peer_pids(rows, 50), [200])
        # 감싼 프로세스(잠금 스크립트)는 러너가 아니다
        rows = [(1, 0, "launchd"),
                (300, 1, "python3 suite_lock.py run -- bash -c bash tools/suite/run-all.sh"), (301, 300, R)]
        self.assertEqual(suite_peers.peer_pids(rows, 50), [301])

    def test_parse_ps_skips_bad_lines(self):
        rows = suite_peers.parse_ps("  10   1 bash /a/run-all.sh\nnot a row\n 11 x foo\n 12 1\n 13 1 cmd with  spaces\n")
        self.assertEqual(rows, [(10, 1, "bash /a/run-all.sh"), (13, 1, "cmd with  spaces")])

    def test_cli_fake_ps_file(self):
        R = "bash /w/tools/suite/run-all.sh"
        f = self.ps_file("  1     0 launchd\n 100     1 %s\n" % R)
        r = run_peers(["--pid", "50"], f)
        self.assertEqual((r.returncode, r.stdout.strip()), (0, "1"))
        r = run_peers(["--pid", "50", "--list"], f)
        self.assertEqual((r.returncode, r.stdout.split()), (0, ["100"]))
        f = self.ps_file("")
        r = run_peers(["--pid", "50"], f)
        self.assertEqual((r.returncode, r.stdout.strip()), (0, "0"))

    def test_cli_unknown_rows_print_question_mark(self):
        missing = os.path.join(self.tmp, "nope.txt")
        r = run_peers(["--pid", "50"], missing)
        self.assertEqual((r.returncode, r.stdout.strip()), (3, "?"))
        r = run_peers(["--pid", "50", "--list"], missing)
        self.assertEqual(r.returncode, 3)
        r = run_peers(["--pid", "50", "--stamp"], missing)
        self.assertEqual(r.returncode, 0)
        self.assertRegex(r.stdout.strip(), r"^\d+\.\d{3} \?$")

    def test_stamp_format(self):
        r = run_peers(["--pid", "50", "--stamp"], self.ps_file(""))
        self.assertEqual(r.returncode, 0)
        self.assertRegex(r.stdout.strip(), r"^\d+\.\d{3} 0$")

    def test_wait_returns_at_zero_and_times_out(self):
        r = run_peers(["--pid", "50", "--wait", "5"], self.ps_file(""))
        self.assertEqual((r.returncode, r.stdout.strip()), (0, "waited=0\tpeers=0"))
        f = self.ps_file(" 100     1 bash /w/tools/suite/run-all.sh\n")
        r = run_peers(["--pid", "50", "--wait", "1", "--interval", "0.2"], f)
        self.assertEqual(r.returncode, 1)
        self.assertTrue(r.stdout.strip().endswith("\tpeers=1"), r.stdout)
        self.assertRegex(r.stdout.strip(), r"^waited=\d+\tpeers=1$")

    @unittest.skipUnless(shutil.which("ps"), "ps 없음")
    def test_real_ps_detached_runner_counted_once(self):
        d = os.path.join(self.tmp, "f")
        os.makedirs(d)
        script = os.path.join(d, "run-all.sh")
        with open(script, "w", encoding="utf-8") as fh:
            fh.write("echo $$ > %s/pid\n( sleep 5; : ) & echo $! > %s/child\nwait\n" % (d, d))
        pidf, childf = os.path.join(d, "pid"), os.path.join(d, "child")
        pids = []
        try:
            subprocess.run(["bash", "-c", "bash %s >/dev/null 2>&1 &" % script],
                           env=clean_env(), timeout=30)
            self.assertTrue(wait_for_files([pidf, childf]), "가짜 러너가 뜨지 않았다")
            pids = [read_pid(pidf), read_pid(childf)]
            r = run_peers(["--pid", str(os.getpid()), "--list"])
            listed = [int(x) for x in r.stdout.split()]
            self.assertIn(pids[0], listed)
            self.assertNotIn(pids[1], listed)
        finally:
            for p in pids:
                kill_quiet(p)

    @unittest.skipUnless(shutil.which("ps"), "ps 없음")
    def test_real_ps_self_ancestor_child_excluded(self):
        for sub in ("a", "b"):
            os.makedirs(os.path.join(self.tmp, sub))
        out = os.path.join(self.tmp, "out")
        a = os.path.join(self.tmp, "a", "run-all.sh")
        b = os.path.join(self.tmp, "b", "run-all.sh")
        with open(a, "w", encoding="utf-8") as fh:
            fh.write("echo $$ > %s/a.pid\nbash %s\n" % (self.tmp, b))
        with open(b, "w", encoding="utf-8") as fh:
            fh.write("echo $$ > %s/b.pid\n( sleep 3; : ) & echo $! > %s/b.child\n"
                     "%s %s --pid $$ --list > %s\nwait\n"
                     % (self.tmp, self.tmp, sys.executable, PEERS, out))
        files = [os.path.join(self.tmp, n) for n in ("a.pid", "b.pid", "b.child")]
        proc = subprocess.Popen(["bash", a], env=clean_env(),
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            proc.wait(timeout=30)
            self.assertTrue(wait_for_files(files), "가짜 러너 파일이 없다")
            self.assertTrue(os.path.exists(out))
            with open(out, encoding="utf-8") as fh:
                listed = fh.read().split()
            for f in files:
                self.assertNotIn(str(read_pid(f)), listed, f)
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.wait()
            for f in files:
                if os.path.exists(f) and os.path.getsize(f) > 0:
                    kill_quiet(read_pid(f))


if __name__ == "__main__":
    unittest.main()
