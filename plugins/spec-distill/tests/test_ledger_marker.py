"""R7 §2-2 · §2-4 — ledger_marker.py (AC7 · AC8 의 모듈 쪽)."""
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "ledger_marker.py"
A, B = "sess-aaaa1111", "sess-bbbb2222"


def run(*args):
    cp = subprocess.run([sys.executable, str(SCRIPT), *args], capture_output=True, text=True, timeout=20)
    return cp.returncode, cp.stdout.strip(), cp.stderr.strip()


def ledger(d: Path, rnd: int):
    d.mkdir(parents=True, exist_ok=True)
    (d / "docreview-state.md").write_text(
        "---\ndocreview:\n  doc: /x/y.md\n  profile: design-doc\n  round: %d\n---\n# docreview 원장\n" % rnd,
        encoding="utf-8")


class MarkerTest(unittest.TestCase):
    def setUp(self):
        self.d = Path(tempfile.mkdtemp()) / "k"
        self.d.mkdir()

    def m(self, sub, sid):
        return run(sub, "--dir", str(self.d), "--session", sid)

    def test_acquire_then_held(self):
        self.assertEqual(self.m("acquire", A)[:2], (0, "acquired"))
        self.assertEqual(self.m("acquire", A)[:2], (0, "held"))
        self.assertEqual((self.d / "reviewing-by").read_text(encoding="utf-8"), A + "\n")

    def test_foreign_is_rc3_with_owner(self):
        self.m("acquire", A)
        self.assertEqual(self.m("acquire", B)[:2], (3, A))

    def test_concurrent_acquire_exactly_one_wins(self):
        for trial in range(10):
            d = self.d.parent / ("c%d" % trial)
            d.mkdir()
            procs = [subprocess.Popen([sys.executable, str(SCRIPT), "acquire", "--dir", str(d), "--session", s],
                                      stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                     for s in ("sess-p%07d" % i for i in range(6))]
            rcs = [p.wait(timeout=20) for p in procs]
            self.assertEqual(rcs.count(0), 1, "trial %d rcs=%r" % (trial, rcs))
            self.assertEqual(rcs.count(3), 5)

    def test_check(self):
        self.assertEqual(self.m("check", A)[0], 3)            # 표지 없음
        self.assertIn("표지 없음", self.m("check", A)[1])
        self.m("acquire", A)
        self.assertEqual(self.m("check", A)[0], 0)
        rc, out, _ = self.m("check", B)
        self.assertEqual(rc, 3)
        self.assertIn(A, out)

    def test_release_only_own(self):
        self.m("acquire", A)
        rc, out, _ = self.m("release", B)
        self.assertEqual(rc, 0)
        self.assertTrue((self.d / "reviewing-by").exists(), "남의 표지를 지웠다")
        self.assertEqual(self.m("release", A)[:2], (0, "released"))
        self.assertFalse((self.d / "reviewing-by").exists())
        self.assertEqual((self.d / "last-session").read_text(encoding="utf-8").strip(), A)
        self.assertEqual(self.m("release", A)[0], 0)          # 표지 없음 — rc 0

    def test_takeover_replaces_and_old_owner_stops(self):
        self.m("acquire", A)
        rc, out, _ = self.m("takeover", B)
        self.assertEqual(rc, 0)
        self.assertIn("이전: " + A, out)
        self.assertEqual(self.m("check", B)[0], 0)
        self.assertEqual(self.m("check", A)[0], 3)            # 넘겨준 세션은 다음 쓰기 앞에서 멈춘다
        self.assertEqual(self.m("acquire", A)[0], 3)
        self.m("release", A)
        self.assertTrue((self.d / "reviewing-by").exists())

    def test_empty_marker_is_foreign(self):
        (self.d / "reviewing-by").write_text("", encoding="utf-8")
        self.assertEqual(self.m("acquire", A)[:2], (3, "(빈 표지)"))
        self.assertEqual(self.m("check", A)[0], 3)
        self.assertEqual(self.m("takeover", A)[0], 0)
        self.assertEqual(self.m("check", A)[0], 0)

    def test_symlink_marker_is_error_not_followed(self):
        outside = self.d.parent / "outside.txt"
        outside.write_text(A + "\n", encoding="utf-8")
        os.symlink(outside, self.d / "reviewing-by")
        self.assertEqual(self.m("check", A)[0], 2)
        self.assertEqual(outside.read_text(encoding="utf-8"), A + "\n")

    def _planted(self):
        outside = self.d.parent / "outside.txt"
        outside.write_text("KEEP\n", encoding="utf-8")
        os.symlink(outside, self.d / "reviewing-by")
        return outside

    def test_planted_marker_link_never_written_through(self):
        outside = self._planted()
        for sub in ("acquire", "check", "release"):
            self.assertEqual(self.m(sub, A)[0], 2, sub)
            self.assertEqual(outside.read_text(encoding="utf-8"), "KEEP\n", sub)
        self.assertEqual(self.m("takeover", A)[0], 0)          # 링크 자체를 바꾼다
        self.assertEqual(outside.read_text(encoding="utf-8"), "KEEP\n")
        self.assertFalse((self.d / "reviewing-by").is_symlink())
        self.assertEqual(self.m("check", A)[0], 0)

    def test_planted_last_session_link_not_followed(self):
        outside = self.d.parent / "outside2.txt"
        outside.write_text("KEEP\n", encoding="utf-8")
        os.symlink(outside, self.d / "last-session")
        self.m("acquire", A)
        self.assertEqual(self.m("release", A)[:2], (0, "released"))
        self.assertEqual(outside.read_text(encoding="utf-8"), "KEEP\n")
        self.assertFalse((self.d / "last-session").is_symlink())

    def test_planted_tmp_link_refused_in_process(self):
        sys.path.insert(0, str(SCRIPT.parent))
        try:
            import ledger_marker
        finally:
            sys.path.pop(0)
        outside = self.d.parent / "outside3.txt"
        outside.write_text("KEEP\n", encoding="utf-8")
        os.symlink(outside, self.d / (".reviewing-by.%d.tmp" % os.getpid()))
        with self.assertRaises(OSError):
            ledger_marker._atomic_write(self.d, "reviewing-by", A + "\n")
        self.assertEqual(outside.read_text(encoding="utf-8"), "KEEP\n")
        self.assertFalse((self.d / "reviewing-by").exists())

    def test_dir_or_parent_link_rc2(self):
        real = self.d.parent / "real"
        real.mkdir()
        (real / "k").mkdir()
        os.symlink(real, self.d.parent / "plink")
        self.assertEqual(run("acquire", "--dir", str(self.d.parent / "plink" / "k"), "--session", A)[0], 2)
        self.assertFalse((real / "k" / "reviewing-by").exists())
        os.symlink(real / "k", self.d.parent / "dlink")
        self.assertEqual(run("acquire", "--dir", str(self.d.parent / "dlink"), "--session", A)[0], 2)
        self.assertFalse((real / "k" / "reviewing-by").exists())

    def test_bad_inputs_rc2(self):
        self.assertEqual(run("acquire", "--dir", str(self.d / "nope"), "--session", A)[0], 2)
        self.assertEqual(self.m("acquire", "a b")[0], 2)
        self.assertEqual(self.m("acquire", A + "\n")[0], 2)


class ResumeNoteTest(unittest.TestCase):
    def setUp(self):
        self.d = Path(tempfile.mkdtemp()) / "k"

    def note(self, sid):
        return run("resume-note", "--dir", str(self.d), "--session", sid)

    def test_round0_silent(self):
        ledger(self.d, 0)
        self.assertEqual(self.note(A)[:2], (0, ""))

    def test_no_last_session_prints(self):
        ledger(self.d, 2)
        self.assertEqual(self.note(A)[1], "[spec-distill] 이전 리뷰 라운드 2 에서 이어 간다 — %s" % self.d)

    def test_other_last_session_prints(self):
        ledger(self.d, 1)
        (self.d / "last-session").write_text(B + "\n", encoding="utf-8")
        self.assertIn("이전 리뷰 라운드 1 에서 이어 간다", self.note(A)[1])

    def test_same_last_session_silent(self):
        ledger(self.d, 3)
        (self.d / "last-session").write_text(A + "\n", encoding="utf-8")
        self.assertEqual(self.note(A)[1], "")

    def test_own_marker_silent(self):            # R-d — 같은 세션의 다음 라운드
        ledger(self.d, 3)
        (self.d / "reviewing-by").write_text(A + "\n", encoding="utf-8")
        self.assertEqual(self.note(A)[1], "")

    def test_no_ledger_silent(self):
        self.d.mkdir(parents=True)
        self.assertEqual(self.note(A)[:2], (0, ""))

    def test_unreadable_ledger_stderr(self):
        self.d.mkdir(parents=True)
        (self.d / "docreview-state.md").write_text("garbage", encoding="utf-8")
        rc, out, err = self.note(A)
        self.assertEqual((rc, out), (0, ""))
        self.assertIn("이전 리뷰 원장을 읽지 못했다", err)


if __name__ == "__main__":
    unittest.main()
