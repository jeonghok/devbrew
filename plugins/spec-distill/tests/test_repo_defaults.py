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
            self.assertEqual(s["parallel_default"], 3, bad)  # 권장 수는 게이트가 아니다 — 기본값으로 세고
            self.assertEqual(s["errors"], [], bad)  # 상태 계산 · 스위트 대조를 멈추지 않는다
            self.assertTrue(any("parallel_default" in w and "기본 3" in w for w in s["warnings"]), bad)  # 크게 알린다
            self.assertEqual(s["sources"]["parallel_default"], "기본값(머리말 값이 깨졌다)", bad)

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


LABEL = "레포 설정@0123abcd"


class StrictFrontmatter(unittest.TestCase):
    def kind(self, text, where="repo"):
        with self.assertRaises(rd.SettingsError) as c:
            rd.strict_frontmatter(text, where)
        self.assertEqual(c.exception.where, where)
        return c.exception.kind

    def test_bom_is_unreadable(self):
        self.assertEqual(self.kind("﻿---\na: b\n---\n"), "unreadable")

    def test_unclosed_and_trailing_space_fence_are_unreadable(self):
        self.assertEqual(self.kind("---\na: b\n"), "unreadable")
        self.assertEqual(self.kind("--- \na: b\n---\n"), "unreadable")

    def test_no_frontmatter_repo_is_unreadable_other_layers_empty(self):
        self.assertEqual(self.kind("본문만\n"), "unreadable")
        self.assertEqual(rd.strict_frontmatter("본문만\n", "roadmap"), {})

    def test_duplicate_key(self):
        self.assertEqual(self.kind("---\nspecs_dir: a/\nspecs_dir: b/\n---\n"), "duplicate_key")

    def test_unquoted_hash_is_error(self):
        self.assertEqual(self.kind("---\ntest_command: pytest # 빠른 것\n---\n"), "unquoted_hash")

    def test_quoted_hash_is_value(self):
        self.assertEqual(rd.strict_frontmatter('---\ntest_command: "pytest -k \'a#b\' # x"\n---\n', "repo")["test_command"],
                         "pytest -k 'a#b' # x")

    def test_quoted_value_with_trailing_text_is_error(self):
        self.assertEqual(self.kind('---\ntest_command: "pytest" # x\n---\n'), "unquoted_hash")
        self.assertEqual(self.kind("---\ntest_command: 'pytest'\t# x\n---\n"), "unquoted_hash")
        self.assertEqual(self.kind('---\ntest_command: "pytest" -k a\n---\n'), "unreadable")
        self.assertEqual(self.kind('---\ntest_command: "pytest"#x\n---\n'), "unreadable")
        self.assertEqual(self.kind('---\ntest_command: "pytest\n---\n'), "unreadable")

    def test_hash_after_any_whitespace_is_error(self):
        self.assertEqual(self.kind("---\ntest_command: pytest\t# 빠른 것\n---\n"), "unquoted_hash")
        self.assertEqual(rd.strict_frontmatter("---\ntest_command: a#b\n---\n", "repo")["test_command"], "a#b")

    def test_line_rules_skip_indented_list_and_comment_lines(self):
        m = rd.strict_frontmatter("---\n# c\nspecs_dir: s/\n  x: y\n- item\n---\n본문 a: b\n", "repo")
        self.assertEqual(m, {"specs_dir": "s/"})


class Layers(unittest.TestCase):
    def test_typo_key_is_unknown(self):
        with self.assertRaises(rd.SettingsError) as c:
            rd.check_layer({"spec_dir": "x/"}, "repo")
        self.assertEqual(c.exception.kind, "unknown_key")

    def test_roadmap_layer_rejects_pre_roadmap_keys(self):   # AC23b
        for k in ("roadmaps_dir", "interview_dir", "branch_prefix"):
            with self.assertRaises(rd.SettingsError) as c:
                rd.check_layer({k: "x/"}, "roadmap")
            self.assertEqual(c.exception.kind, "layer_key", k)

    def test_roadmap_layer_accepts_meta_and_its_settings(self):
        rd.check_layer({"type": "roadmap", "source_brief": "b.md", "specs_dir": "s/", "plans_dir": "p/", "test_command": "t",
                        "test_failure_pattern": "f", "review_model": "m", "parallel_default": "2"}, "roadmap")

    def test_repo_layer_accepts_all_nine_keys_and_not_meta(self):
        self.assertEqual(len(rd.KEYS), 9)
        rd.check_layer({k: "x" for k in rd.KEYS}, "repo")
        with self.assertRaises(rd.SettingsError):
            rd.check_layer({"type": "roadmap"}, "repo")

    def test_machine_layer_accepts_two_keys_only(self):
        with self.assertRaises(rd.SettingsError) as c:
            rd.check_layer({"review_model": "x"}, "machine")
        self.assertEqual(c.exception.kind, "layer_key")
        rd.check_layer({"test_command": "x", "test_failure_pattern": "y"}, "machine")


class Merge(unittest.TestCase):
    def test_missing_key_is_default_not_error(self):
        m = rd.merge_layers(None, {}, LABEL, None, [])
        self.assertEqual((m["values"]["interview_dir"], m["sources"]["interview_dir"]), (rd.INTERVIEW_DIR, "기본값"))
        self.assertEqual((m["values"]["branch_prefix"], m["values"]["roadmaps_dir"]), ("feature/", rd.ROADMAPS_DIR))
        self.assertEqual(m["errors"], [])
        self.assertEqual(list(m["values"]), list(rd.KEYS))

    def test_priority_roadmap_repo_machine_constant(self):
        m = rd.merge_layers({"test_command": "a"}, {"test_command": "b"}, LABEL, {"test_command": "c"}, [])
        self.assertEqual((m["values"]["test_command"], m["sources"]["test_command"]), ("a", "로드맵"))
        m = rd.merge_layers({}, {"test_command": "b"}, LABEL, {"test_command": "c"}, [])
        self.assertEqual((m["values"]["test_command"], m["sources"]["test_command"]), ("b", LABEL))
        m = rd.merge_layers({}, {}, LABEL, {"test_command": "c"}, [])
        self.assertEqual((m["values"]["test_command"], m["sources"]["test_command"]), ("c", "기계 상태(임시)"))
        m = rd.merge_layers({}, {}, LABEL, {}, [])
        self.assertEqual((m["values"]["test_command"], m["sources"]["test_command"]), (None, "기본값"))

    def test_folder_under_git_or_root_is_error(self):
        for bad in (".git/x/", "a/.git/b/", ".", "./", "/abs/", "a/../b/"):
            m = rd.merge_layers(None, {"specs_dir": bad}, LABEL, None, [])
            self.assertIsNone(m["values"]["specs_dir"], bad)
            self.assertEqual(len(m["errors"]), 1, bad)

    def test_old_repo_settings_meaning_is_kept(self):
        m = rd.merge_layers({"specs_dir": "design", "plans_dir": '"work/plans/"', "review_model": "opus", "test_command": "'make test'"},
                            None, None, None, [])
        self.assertEqual((m["values"]["specs_dir"], m["values"]["plans_dir"]), ("design/", "work/plans/"))
        self.assertEqual((m["values"]["review_model"], m["values"]["test_command"]), ("opus", "make test"))
        m = rd.merge_layers({"review_model": ""}, None, None, None, [])
        self.assertIsNone(m["values"]["review_model"])
        self.assertTrue(any("review_model" in e for e in m["errors"]))
        for bad in ("0", "-1", "abc", "", "3.5", "３"):
            m = rd.merge_layers({"parallel_default": bad}, None, None, None, [])
            self.assertEqual(m["values"]["parallel_default"], 3, bad)
            self.assertEqual(m["errors"], [], bad)
            self.assertTrue(any("parallel_default" in w and "기본 3" in w for w in m["warnings"]), bad)
            self.assertEqual(m["sources"]["parallel_default"], "기본값(머리말 값이 깨졌다)", bad)
        m = rd.merge_layers({"parallel_default": "5"}, None, None, None, [])
        self.assertEqual((m["values"]["parallel_default"], m["sources"]["parallel_default"]), (5, "로드맵"))

    def test_layer_violation_is_an_error_and_notices_pass_through(self):
        m = rd.merge_layers({"branch_prefix": "x/"}, {}, LABEL, None, ["알림"])
        self.assertEqual(m["values"]["branch_prefix"], "feature/")
        self.assertTrue(m["errors"])
        self.assertEqual(m["notices"], ["알림"])


if __name__ == "__main__":
    unittest.main()
