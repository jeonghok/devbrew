"""shared/deps/check_deps.py — 판 문자열 판독 · 의존 표 판독."""
import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "deps"))

import check_deps  # noqa: E402

GOOD = (
    "---\n"
    "type: devbrew-dependencies\n"
    "plugin: demo\n"
    "---\n"
    "\n"
    "# demo 의존\n"
    "\n"
    "| 이름 | 최소 판 | 잰 날짜 | 강도 | 없을 때 |\n"
    "|---|---|---|---|---|\n"
    "| python | 3.9.6 | 2026-10-20 | 멈춤 | 진입에서 멈춘다 |\n"
    "| claude-code |  |  | 기록 | 기록만 한다 |\n"
)


class VersionTriple(unittest.TestCase):
    def test_cases(self):
        cases = [
            ("Python 3.9.6", (3, 9, 6)),
            ("git version 2.54.0 (Apple Git-157)", (2, 54, 0)),
            ("git version 2.47.1.windows.2", (2, 47, 1)),
            ("gh version 2.88.1 (2026-03-12)\nhttps://github.com/cli/cli/releases/tag/v2.88.1", (2, 88, 1)),
            ("2.45.0-rc1", (2, 45, 0)),
            ("2.1.303 (Claude Code)", (2, 1, 303)),
        ]
        for text, expected in cases:
            with self.subTest(text=text):
                self.assertEqual(check_deps.version_triple(text), expected)

    def test_unreadable(self):
        for text in ("git version unknown", "", None, "\n3.9.6", "Python 3.12", "gh version 2.88 (dev)"):
            with self.subTest(text=text):
                self.assertIsNone(check_deps.version_triple(text))

    def test_first_line_only(self):
        # 둘째 줄의 판을 집지 않는다 — gh 의 둘째 줄 URL 은 다른 판을 담을 수 있다.
        self.assertEqual(check_deps.version_triple("gh version 2.88.1\nv9.9.9"), (2, 88, 1))
        self.assertIsNone(check_deps.version_triple("gh version dev\nhttps://x/v2.88.1"))


class SuperpowersVersion(unittest.TestCase):
    def test_base_paths(self):
        self.assertEqual(
            check_deps.superpowers_version("/x/cache/claude-plugins-official/superpowers/7.0.0/skills/writing-plans"),
            (7, 0, 0))
        self.assertEqual(check_deps.superpowers_version("/x/superpowers/6.4.1/skills"), (6, 4, 1))
        for base in ("", None, "/x/superpowers/skills/writing-plans", "/x/superpowers/latest/skills/a",
                     "/x/other/7.0.0/skills/a"):
            with self.subTest(base=base):
                self.assertIsNone(check_deps.superpowers_version(base))


class ReadTable(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="check-deps-")
        self.path = os.path.join(self.tmp, "dependencies.md")

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def write(self, text):
        with open(self.path, "w", encoding="utf-8") as handle:
            handle.write(text)

    def test_good(self):
        self.write(GOOD)
        rows = check_deps.read_table(self.path)
        self.assertEqual([row["name"] for row in rows], ["python", "claude-code"])
        self.assertEqual(rows[0], {
            "name": "python", "min_version": "3.9.6", "measured_on": "2026-10-20",
            "strength": "멈춤", "when_missing": "진입에서 멈춘다"})
        self.assertEqual(rows[1]["min_version"], "")

    def test_bom_is_read(self):
        self.write("﻿" + GOOD)
        self.assertEqual(len(check_deps.read_table(self.path)), 2)

    def assert_broken(self, text, needle):
        self.write(text)
        with self.assertRaises(check_deps.DepsError) as caught:
            check_deps.read_table(self.path)
        self.assertIn(needle, str(caught.exception))

    def test_four_cells(self):
        self.assert_broken(GOOD + "| gh | 2.88.1 | 2026-10-20 | 멈춤 |\n", "4칸")

    def test_six_cells(self):
        self.assert_broken(GOOD + "| gh | 2.88.1 | 2026-10-20 | 멈춤 | 멈춘다 | 더 |\n", "6칸")

    def test_no_front_matter(self):
        self.assert_broken(GOOD.split("---\n", 2)[2], "머리말")

    def test_wrong_type(self):
        self.assert_broken(GOOD.replace("devbrew-dependencies", "devbrew-other"), "type")

    def test_no_plugin(self):
        self.assert_broken(GOOD.replace("plugin: demo\n", ""), "plugin")

    def test_unclosed_front_matter(self):
        self.assert_broken(GOOD.replace("plugin: demo\n---\n", "plugin: demo\n"), "닫히지")

    def test_wrong_header(self):
        self.assert_broken(GOOD.replace("| 잰 날짜 |", "| 날짜 |"), "표 머리")

    def test_no_separator(self):
        self.assert_broken(GOOD.replace("|---|---|---|---|---|\n", ""), "구분 줄")

    def test_bad_strength(self):
        self.assert_broken(GOOD.replace("| 기록 |", "| 무시 |"), "강도")

    def test_duplicate_name(self):
        self.assert_broken(GOOD + "| python | 3.9.6 | 2026-10-20 | 멈춤 | 멈춘다 |\n", "같은 이름")

    def test_second_table(self):
        self.assert_broken(GOOD + "\n뒷글\n\n| gh | 2.88.1 | 2026-10-20 | 멈춤 | 멈춘다 |\n", "끝난 뒤")

    def test_no_table(self):
        self.assert_broken(GOOD.split("| 이름")[0], "표가 없다")

    def test_no_rows(self):
        self.assert_broken(GOOD.split("| python")[0], "행이 없다")

    def test_missing_file(self):
        with self.assertRaises(check_deps.DepsError):
            check_deps.read_table(os.path.join(self.tmp, "none.md"))


if __name__ == "__main__":
    unittest.main()
