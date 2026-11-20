#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""merged_pr_range.py — 머지 방식별(merge-commit · squash · rebase) 커밋 범위 확인.

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_merged_pr_range.py
"""
from __future__ import annotations

import contextlib
import io
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import conductor_state as cs  # noqa: E402
import merged_pr_range as mpr  # noqa: E402

RM = "docs/rm/roadmap.md"


def git(repo, *args):
    p = subprocess.run(["git", *args], cwd=repo, capture_output=True, encoding="utf-8", check=True)
    return p.stdout.strip()


class Repo:
    def __init__(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.path = str(Path(self._tmp.name).resolve())
        git(self.path, "init", "-q", "-b", "trunk-x")
        git(self.path, "config", "user.name", "t")
        git(self.path, "config", "user.email", "t@example.com")
        git(self.path, "config", "commit.gpgsign", "false")

    def close(self):
        self._tmp.cleanup()

    def write(self, name, text):
        (Path(self.path) / name).write_text(text, encoding="utf-8")

    def commit(self, name, text, msg="c"):
        self.write(name, text)
        git(self.path, "add", name)
        git(self.path, "commit", "-q", "-m", msg)
        return git(self.path, "rev-parse", "HEAD")


def lines(*xs):
    return "".join(x + "\n" for x in xs)


BASE_A = lines(*["line%d" % i for i in range(1, 31)])


class Cases(unittest.TestCase):
    def setUp(self):
        self.r = Repo()
        self.addCleanup(self.r.close)
        self.R = self.r.path

    def test_merge_commit(self):
        base = self.r.commit("a.txt", BASE_A)
        git(self.R, "checkout", "-q", "-b", "topic")
        self.r.commit("a.txt", "x = 1\n" + BASE_A)
        head = self.r.commit("b.txt", "b\n")
        git(self.R, "checkout", "-q", "trunk-x")
        first_parent = self.r.commit("c.txt", "c\n")
        git(self.R, "merge", "-q", "--no-ff", "-m", "m", "topic")
        merge = git(self.R, "rev-parse", "HEAD")
        self.assertNotEqual(base, first_parent)
        got, why = mpr.confirm(self.R, merge, head, "1")
        self.assertIsNone(why)
        self.assertEqual(got, (first_parent, merge, "merge-commit"))

    def _squash(self):
        self.r.commit("a.txt", BASE_A)
        git(self.R, "checkout", "-q", "-b", "topic")
        self.r.commit("a.txt", "top\n" + BASE_A)
        head = self.r.commit("b.txt", "b\n")
        git(self.R, "checkout", "-q", "trunk-x")
        return head

    def test_squash(self):
        head = self._squash()
        sq_parent = self.r.commit("c.txt", "c\n")
        git(self.R, "merge", "-q", "--squash", "topic")
        git(self.R, "commit", "-q", "-m", "sq")
        sq = git(self.R, "rev-parse", "HEAD")
        self.assertEqual(mpr.confirm(self.R, sq, head, "2")[0], (sq_parent, sq, "squash"))

    def test_rebase_three_commits_same_file(self):
        base_before = self.r.commit("a.txt", BASE_A)
        git(self.R, "checkout", "-q", "-b", "topic")
        c1 = self.r.commit("a.txt", "x = 1\n" + BASE_A)
        c2 = self.r.commit("a.txt", "x = 1\n" + BASE_A + "tail\n")
        c3 = self.r.commit("a.txt", "x = 2\n" + BASE_A + "tail\n")
        git(self.R, "checkout", "-q", "trunk-x")
        for c in (c1, c2, c3):
            git(self.R, "cherry-pick", c)
        merge = git(self.R, "rev-parse", "HEAD")
        parent_of_merge = git(self.R, "rev-parse", "HEAD~1")
        got, why = mpr.confirm(self.R, merge, c3, "3")
        self.assertIsNone(why)
        self.assertEqual(got, (base_before, merge, "rebase-3"))
        self.assertNotEqual(got[0], parent_of_merge)
        self.assertFalse(mpr.same_change(self.R, parent_of_merge, merge, base_before, c3))

    def test_unconfirmable(self):
        head = self._squash()
        unrelated = self.r.commit("z.txt", "z\n")
        got, why = mpr.confirm(self.R, unrelated, head, "4")
        self.assertIsNone(got)
        self.assertIn("같지 않다", why)

    def test_second_parent_not_head(self):
        self.r.commit("a.txt", BASE_A)
        git(self.R, "checkout", "-q", "-b", "topic")
        self.r.commit("b.txt", "b\n")
        other = self.r.commit("b.txt", "b2\n")
        git(self.R, "checkout", "-q", "trunk-x")
        self.r.commit("c.txt", "c\n")
        git(self.R, "merge", "-q", "--no-ff", "-m", "m", "topic")
        merge = git(self.R, "rev-parse", "HEAD")
        first_topic = git(self.R, "rev-parse", "topic~1")
        got, why = mpr.confirm(self.R, merge, first_topic, "5")
        self.assertIsNone(got)
        self.assertIn("둘째 부모", why)
        self.assertNotEqual(first_topic, other)

    def test_missing_head_says_fetch(self):
        c = self.r.commit("a.txt", BASE_A)
        got, why = mpr.confirm(self.R, c, "0" * 40, "6")
        self.assertIsNone(got)
        self.assertIn("git fetch origin pull/6/head", why)

    def test_whitespace_difference_is_not_same_change(self):
        base = self.r.commit("a.txt", lines("x = 1", "y"))
        c1 = self.r.commit("a.txt", lines("    x = 1", "y"))
        c2 = self.r.commit("a.txt", lines("    x = 2", "y"))
        self.assertFalse(mpr.same_change(self.R, c1, c2, base, c2))
        self.assertTrue(mpr.same_change(self.R, base, c2, base, c2))

    def test_squash_after_base_touched_same_file(self):
        self.r.commit("a.txt", BASE_A)
        git(self.R, "checkout", "-q", "-b", "topic")
        head = self.r.commit("a.txt", "top\n" + BASE_A)
        git(self.R, "checkout", "-q", "trunk-x")
        self.r.commit("a.txt", BASE_A + "far below\n")
        git(self.R, "merge", "-q", "--squash", "topic")
        git(self.R, "commit", "-q", "-m", "sq")
        sq = git(self.R, "rev-parse", "HEAD")
        self.assertEqual(mpr.confirm(self.R, sq, head, "7")[0][2], "squash")

    def _cli(self, argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            rc = mpr.main(argv)
        return rc, out.getvalue(), err.getvalue()

    def test_cli_rc(self):
        head = self._squash()
        self.r.commit("c.txt", "c\n")
        git(self.R, "merge", "-q", "--squash", "topic")
        git(self.R, "commit", "-q", "-m", "sq")
        sq = git(self.R, "rev-parse", "HEAD")
        unrelated = self.r.commit("z.txt", "z\n")
        cwd = Path.cwd()
        import os
        os.chdir(self.R)
        self.addCleanup(os.chdir, cwd)
        rc, out, err = self._cli(["--merge", sq, "--head", head, "--pr", "2"])
        self.assertEqual(rc, 0, err)
        rows = out.splitlines()
        self.assertEqual([x.split(":")[0] for x in rows], ["start", "end", "how"])
        self.assertEqual(rows[1], "end: " + sq)
        self.assertEqual(rows[2], "how: squash")
        rc, out, err = self._cli(["--merge", unrelated, "--head", head, "--pr", "4"])
        self.assertEqual((rc, out), (3, ""))
        self.assertTrue(err.startswith("[spec-distill] 범위를 확인하지 못했다 — "))
        self.assertEqual(self._cli(["--pr", "x"])[0], 2)
        self.assertEqual(self._cli(["--pr", "1"])[0], 2)

        # --roadmap 갈래: 캐시 줄 읽기
        data = cs.empty()
        row = {"브랜치": "feature/a", "번호": "#8", "상태": "머지됨", "확인한 때": "2026-11-20 10:00",
               "headRefOid": head, "교차 레포": "아니오", "baseRefName": "trunk-x", "mergeCommit": "-",
               "쓴 세션": "session-aaaa1111"}
        data["PR"].append(row)
        path = cs.machine_path(Path(self.R) / ".claude" / "spec-distill", RM)
        path.parent.mkdir(parents=True)
        with mock.patch("merged_pr_range.state_root", return_value=Path(self.R) / ".claude" / "spec-distill"):
            self.assertIn("머지됨", cs.PR_STATES)
            path.write_text(cs.render_machine(RM, data), encoding="utf-8")
            rc, out, err = self._cli(["--roadmap", RM, "--pr", "8"])
            self.assertEqual((rc, out), (4, ""))
            self.assertIn("PR #8 의 머지 커밋이 PR 캐시에 없다", err)
            self.assertEqual(self._cli(["--roadmap", RM, "--pr", "99"])[0], 4)
            data["PR"][0]["mergeCommit"] = sq
            path.write_text(cs.render_machine(RM, data), encoding="utf-8")
            rc, out, err = self._cli(["--roadmap", RM, "--pr", "8"])
            self.assertEqual(rc, 0, err)
            self.assertIn("how: squash", out)


if __name__ == "__main__":
    unittest.main()
