#!/usr/bin/env python3
# guards: plugins/spec-distill/scripts/roadmap_status.py
"""roadmap_status — 갈라진 곳(merge-base)을 못 읽은 것은 「설계 중」 이 아니라 셀 수 없음이다.

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_roadmap_status_merge_base.py
"""
from __future__ import annotations

import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import roadmap_status as rs  # noqa: E402


class FakeGit(rs.Git):
    """merge-base 와 얕은 클론 질의만 흉내 낸다 — 그 밖의 호출은 테스트가 모르는 길이라 실패로 드러낸다."""

    def __init__(self, rc: int, shallow: bool = False, err: str = "fatal: Not a valid commit name deadbeef"):
        super().__init__(tempfile.gettempdir())
        self._rc, self._shallow, self._err = rc, shallow, err

    def run_err(self, *args):
        if args[0] == "merge-base":
            return (self._rc, "abc123\n" if self._rc == 0 else "", "" if self._rc in (0, 1) else self._err)
        if args[:2] == ("rev-parse", "--is-shallow-repository"):
            return (0, "true\n" if self._shallow else "false\n", "")
        raise AssertionError("예상 밖 git 호출: %r" % (args,))


class MergeBase(unittest.TestCase):
    def test_found(self):
        g = FakeGit(0)
        self.assertEqual(g.merge_base("main", "tip"), "abc123")
        self.assertEqual(g.failures, [])

    def test_git_error_is_counted(self):
        g = FakeGit(128)
        self.assertIsNone(g.merge_base("main", "tip"))
        self.assertEqual(len(g.failures), 1)
        self.assertIn("merge-base", g.failures[0])
        self.assertIn("rc 128", g.failures[0])

    def test_no_common_ancestor_is_not_a_failure(self):
        g = FakeGit(1)
        self.assertIsNone(g.merge_base("main", "tip"))
        self.assertEqual(g.failures, [])

    def test_no_common_ancestor_in_shallow_clone_is_counted(self):
        g = FakeGit(1, shallow=True)
        self.assertIsNone(g.merge_base("main", "tip"))
        self.assertEqual(len(g.failures), 1)
        self.assertIn("얕은 클론", g.failures[0])


class Progress(unittest.TestCase):
    def setUp(self):
        self._find = rs.find_specs
        rs.find_specs = lambda *_a, **_k: ["docs/s-design.md"]

    def tearDown(self):
        rs.find_specs = self._find

    def run_progress(self, g):
        return rs.progress(g, "main", "tip", {"id": "R1"}, None, {"specs_dir": "docs/", "plans_dir": "docs/p/"})

    def test_git_error_is_not_designing(self):
        stage, why, _specs, _plans = self.run_progress(FakeGit(128))
        self.assertEqual(stage, "알 수 없음", why)
        self.assertIn("갈라진 곳", why)

    def test_shallow_clone_is_not_designing(self):
        stage, _why, _specs, _plans = self.run_progress(FakeGit(1, shallow=True))
        self.assertEqual(stage, "알 수 없음")

    def test_no_common_ancestor_stays_designing(self):
        stage, _why, _specs, _plans = self.run_progress(FakeGit(1))
        self.assertEqual(stage, "설계 중")

    def test_exit_code_is_unknown_when_merge_base_failed(self):
        g = FakeGit(128)
        self.run_progress(g)
        report = {"format_errors": [], "unknown_reasons": ["git 읽기 실패 — %s" % f for f in g.failures],
                  "blocks": [], "unassigned": [], "orphans": [], "unknown_ids": []}
        self.assertEqual(rs.exit_code(report), 3)


if __name__ == "__main__":
    unittest.main()
