#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""repo_defaults.py — 로드맵 frontmatter 의 레포 설정과 기본값(R5 AC14).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_repo_defaults.py
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
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


if __name__ == "__main__":
    unittest.main()
