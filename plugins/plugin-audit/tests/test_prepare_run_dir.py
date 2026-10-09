"""prepare-run-dir.py — 실행 디렉토리 생성기 (설계 2026-09-28-audit-folder-removal §2 · AC4).

스크립트 이름에 하이픈이 있어 import 하지 않고 subprocess 로 돈다.
"""
import hashlib
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "prepare-run-dir.py"
DATE = "2026-09-28"


def run(root, target, *extra, env=None):
    r = subprocess.run(
        [sys.executable, str(SCRIPT), target, "--repo-root", str(root), "--date", DATE, *extra],
        capture_output=True, env=env)
    return (r.returncode, r.stdout.decode("utf-8").splitlines(),
            r.stderr.decode("utf-8", "replace"))


def sha8(key):
    return hashlib.sha256(key.encode("utf-8")).hexdigest()[:8]


class TestPrepareRunDir(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name).resolve()
        self.parent = self.root / ".claude" / "plugin-audit"

    def tearDown(self):
        self._td.cleanup()

    def test_1_first_call_creates_keyed_dir_and_prints_abs_path(self):
        # 사용자 리포에는 .claude/ 가 아예 없을 수 있다 — 부모까지 만든다.
        self.assertFalse((self.root / ".claude").exists())
        rc, out, err = run(self.root, "quality-gates")
        self.assertEqual(rc, 0, err)
        want = self.parent / f"{DATE}-quality-gates"
        self.assertTrue(want.is_dir())
        self.assertEqual(len(out), 2, out)
        self.assertTrue(Path(out[0]).is_absolute(), out[0])
        self.assertEqual(Path(out[0]), want)

    def test_2_second_call_makes_dash_2_and_leaves_first_untouched(self):
        rc, out1, err = run(self.root, "quality-gates")
        self.assertEqual(rc, 0, err)
        first = Path(out1[0])
        (first / "audit.md").write_text("first run\n", encoding="utf-8")
        before = sorted(p.name for p in first.iterdir())
        rc, out2, err = run(self.root, "quality-gates")
        self.assertEqual(rc, 0, err)
        self.assertEqual(Path(out2[0]), self.parent / f"{DATE}-quality-gates-2")
        self.assertEqual(sorted(p.name for p in first.iterdir()), before)
        self.assertEqual((first / "audit.md").read_text(encoding="utf-8"), "first run\n")

    def test_3_gitignore_is_single_star_line(self):
        rc, out, err = run(self.root, "quality-gates")
        self.assertEqual(rc, 0, err)
        gi = Path(out[0]) / ".gitignore"
        self.assertEqual(gi.read_text(encoding="utf-8").splitlines(), ["*"])

    def test_4_bad_targets_are_rc2_and_create_nothing(self):
        for bad in ("../x", "a/b", ".x", "a..b", ""):
            with self.subTest(target=bad):
                rc, out, err = run(self.root, bad)
                self.assertEqual(rc, 2, err)
                self.assertIn("target 형식 불허", err)
                self.assertEqual(out, [])
        self.assertFalse(self.parent.exists() and any(self.parent.iterdir()))

    def test_5_sandbox_id_is_hash_of_run_key(self):
        seen = []
        for target in ("quality-gates", "spec-distill", "quality-gates"):  # 셋째는 -2
            rc, out, err = run(self.root, target)
            self.assertEqual(rc, 0, err)
            key = Path(out[0]).name
            self.assertRegex(out[1], r"\A[0-9a-f]{8}\Z")
            # 같은 실행 키 → 같은 id: 디렉토리 이름에서 언제든 다시 계산된다.
            self.assertEqual(out[1], sha8(key))
            seen.append((key, out[1]))
        # 같은 달의 서로 다른 실행 키 → 앞 8글자가 서로 다르다.
        self.assertEqual(len({sid for _, sid in seen}), 3, seen)
        # 키 자체의 앞 8글자는 전부 같다 — audit-sandbox.sh create-sandbox 가 id 앞 8글자만 쓰므로 해시가 필요하다.
        self.assertEqual(len({key[:8] for key, _ in seen}), 1, seen)

    def test_6_bad_date_is_rc2(self):
        rc, out, err = run(self.root, "quality-gates", "--date", "20260928")
        self.assertEqual(rc, 2, err)
        self.assertIn("date 형식 불허", err)
        self.assertEqual(out, [])

    def test_7_root_with_space_and_hangul_under_ascii_stdout(self):
        root = self.root / "내 리포"
        root.mkdir()
        env = dict(os.environ, PYTHONIOENCODING="ascii")
        rc, out, err = run(root, "quality-gates", env=env)
        self.assertEqual(rc, 0, err)
        self.assertEqual(Path(out[0]), root.resolve() / ".claude" / "plugin-audit" / f"{DATE}-quality-gates")
        self.assertTrue(Path(out[0]).is_dir())

    def test_8_existing_file_at_key_is_skipped_not_overwritten(self):
        self.parent.mkdir(parents=True)
        squatter = self.parent / f"{DATE}-quality-gates"
        squatter.write_text("not a dir\n", encoding="utf-8")
        rc, out, err = run(self.root, "quality-gates")
        self.assertEqual(rc, 0, err)
        self.assertEqual(Path(out[0]).name, f"{DATE}-quality-gates-2")
        self.assertEqual(squatter.read_text(encoding="utf-8"), "not a dir\n")


if __name__ == "__main__":
    unittest.main()
