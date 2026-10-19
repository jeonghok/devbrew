#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""repo_defaults.py — 로드맵 frontmatter 의 레포 설정과 기본값(R5 AC14).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_repo_defaults.py
"""
from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS))
import repo_defaults as rd  # noqa: E402


class Settings(unittest.TestCase):
    def test_defaults_when_absent(self):
        s = rd.repo_settings({})
        self.assertEqual(s["specs_dir"], rd.SPECS_DIR)
        self.assertEqual(s["plans_dir"], rd.PLANS_DIR)
        self.assertIsNone(s["test_command"])
        self.assertIsNone(s["review_model"])
        self.assertEqual(s["sources"]["specs_dir"], "기본값")
        self.assertEqual(s["errors"], [])

    def test_parallel_default_is_a_recommendation_with_default_three(self):
        s = rd.repo_settings({})
        self.assertEqual((s["parallel_default"], s["sources"]["parallel_default"]), (3, "기본값"))
        s = rd.repo_settings({"parallel_default": "5"})
        self.assertEqual((s["parallel_default"], s["sources"]["parallel_default"], s["errors"]), (5, "frontmatter", []))
        for bad in ("0", "-1", "abc", "", "3.5", "\uff13"):
            s = rd.repo_settings({"parallel_default": bad})
            self.assertIsNone(s["parallel_default"], bad)
            self.assertTrue(any("parallel_default" in e for e in s["errors"]), bad)

    def test_frontmatter_wins_and_gets_trailing_slash(self):
        s = rd.repo_settings({"specs_dir": "design", "plans_dir": "\"work/plans/\""})
        self.assertEqual(s["specs_dir"], "design/")
        self.assertEqual(s["plans_dir"], "work/plans/")
        self.assertEqual(s["sources"]["plans_dir"], "frontmatter")

    def test_bad_folder_is_an_error_not_a_silent_default(self):
        for bad in ("../x", "/abs", "~/x", "a/./b", "", "\"\""):
            s = rd.repo_settings({"specs_dir": bad})
            self.assertIsNone(s["specs_dir"], bad)
            self.assertTrue(s["errors"], bad)

    def test_text_keys(self):
        s = rd.repo_settings({"review_model": "opus", "test_command": "'make test'"})
        self.assertEqual(s["review_model"], "opus")
        self.assertEqual(s["test_command"], "make test")
        self.assertEqual(s["sources"]["review_model"], "frontmatter")

    def test_empty_text_key_is_an_error(self):
        s = rd.repo_settings({"review_model": ""})
        self.assertIsNone(s["review_model"])
        self.assertTrue(any("review_model" in e for e in s["errors"]))


class NoHardcodedFolders(unittest.TestCase):
    """AC14 — 설계문서 · 계획 · SDD 폴더 기본값은 repo_defaults.py 에만 글자로 있다(이어 붙인 꼴 포함)."""
    FILES = ("roadmap_status.py", "check_bundle_coverage.py", "conductor_state.py", "control_plane.py",
             "spec_review_bundle.py", "roadmap_model.py")
    LITERALS = (rd.SPECS_DIR.rstrip("/"), rd.PLANS_DIR.rstrip("/"), rd.SDD_WORKSPACE.rstrip("/"))

    @classmethod
    def hits(cls, text):
        """text 안에서 폴더 기본값이 글자로 있는 꼴 — 슬래시로 이은 꼴, 또는 조각이 따옴표 글자로 이어진 꼴."""
        found = []
        for lit in cls.LITERALS:
            parts = lit.split("/")
            split_form = re.compile(r"\s*[,+]?\s*".join("[\"']" + re.escape(p) + "/?[\"']" for p in parts))
            if lit in text or split_form.search(text):
                found.append(lit)
        return found

    def test_default_folders_only_in_repo_defaults(self):
        for name in self.FILES:
            text = (SCRIPTS / name).read_text(encoding="utf-8")
            self.assertEqual(self.hits(text), [], "%s 에 폴더 기본값이 박혀 있다 — repo_defaults 를 써라" % name)

    def test_lock_sees_planted_literals(self):   # 양성 대조 — 이 락이 두 꼴을 실제로 본다
        for planted in ("x = %r\n" % rd.SPECS_DIR,
                        'p = os.path.join(root, "docs", "superpowers", "specs")\n',
                        'p = "docs/" "superpowers/" "plans"\n'.replace('" "', '", "'),
                        "q = ('.superpowers', 'sdd')\n"):
            self.assertTrue(self.hits(planted), planted)
        self.assertEqual(self.hits('os.path.join(root, "docs", "other")\n'), [])


if __name__ == "__main__":
    unittest.main()
