#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""repo_defaults.py — 레포 설정 해결자(엄격한 머리말 · 층 · 합치기)와 기본값(R5 AC14 · R8 AC1 · AC2 · AC5).

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

    def test_colonless_line_unreadable_repo(self):
        with self.assertRaises(rd.SettingsError) as c:
            rd.strict_frontmatter("---\nspecs_dir: s/\nplans_dir s/\n---\n", "repo")
        self.assertEqual((c.exception.kind, c.exception.where), ("unreadable", "repo"))
        self.assertIn("plans_dir s/", str(c.exception))

    def test_colonless_line_unreadable_roadmap(self):
        with self.assertRaises(rd.SettingsError) as c:
            rd.strict_frontmatter("---\ntype: roadmap\nspecs_dir s/\n---\n", "roadmap", "r/roadmap.md")
        self.assertEqual((c.exception.kind, c.exception.where), ("unreadable", "roadmap"))
        self.assertIn("specs_dir s/", str(c.exception))

    def test_skipped_lines_still_skipped(self):
        m = rd.strict_frontmatter("---\n\n  indented no colon\n\ttab no colon\n- x\n# x\nspecs_dir: s/\n---\n", "repo")
        self.assertEqual(m, {"specs_dir": "s/"})

    def test_real_roadmaps_pass(self):
        root = Path(__file__).resolve().parents[3]
        files = sorted(root.glob("docs/superpowers/roadmaps/*/roadmap.md"))
        self.assertTrue(files)
        for f in files:
            rd.strict_frontmatter(f.read_text(encoding="utf-8"), "roadmap", str(f))
        settings = root / rd.SETTINGS_FILE
        if settings.is_file():
            rd.strict_frontmatter(settings.read_text(encoding="utf-8"), "repo")


class FolderSpecialChars(unittest.TestCase):
    def merged(self, key, value):
        return rd.merge_layers(None, {key: value}, LABEL, None, [])

    def test_folder_special_chars(self):
        for key in ("specs_dir", "plans_dir", "roadmaps_dir", "interview_dir"):
            for ch in ("*", "?", "[", "]", "\\"):
                m = self.merged(key, "docs/a%sb/" % ch)
                self.assertIsNone(m["values"][key], (key, ch))
                self.assertEqual(len(m["errors"]), 1, (key, ch))
                self.assertIn(key, m["errors"][0])
                self.assertIn(ch, m["errors"][0])
            m = self.merged(key, ":(glob)docs/")
            self.assertIsNone(m["values"][key], key)
            self.assertIn(":", m["errors"][0])

    def test_colon_inside_folder_ok(self):
        m = self.merged("specs_dir", "docs/a:b/")
        self.assertEqual((m["values"]["specs_dir"], m["errors"]), ("docs/a:b/", []))

    def test_pattern_keeps_bracket(self):
        m = self.merged("test_failure_pattern", "^\\[x\\]")
        self.assertEqual((m["values"]["test_failure_pattern"], m["errors"]), ("^\\[x\\]", []))

    def test_ordinary_folder_and_defaults_pass(self):
        m = self.merged("plans_dir", "docs/my-plans/")
        self.assertEqual((m["values"]["plans_dir"], m["errors"]), ("docs/my-plans/", []))
        self.assertEqual(rd.merge_layers(None, {}, LABEL, None, [])["errors"], [])


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

    def test_repo_layer_accepts_all_ten_keys_and_not_meta(self):
        self.assertEqual(len(rd.KEYS), 10)
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
        for bad in (".git/x/", "a/.git/b/", ".GIT/x/", "a/.Git/b/", ".", "./", "/abs/", "a/../b/"):
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


class InternalErrors(unittest.TestCase):
    """값 없음(rc 1)과 깨짐(rc 3)을 가른다 — 예상 밖 예외도 rc 3 이다. 임시 레포(원격 없음)에서만 돈다."""

    def setUp(self):
        import os, subprocess, tempfile
        self.tmp = os.path.realpath(tempfile.mkdtemp())
        self.addCleanup(__import__("shutil").rmtree, self.tmp, True)
        env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
        subprocess.run(["git", "init", "-q", self.tmp], check=True, env=env)

    def test_machine_reader_non_value_error_is_settings_error(self):
        def boom(_roadmap):
            raise RuntimeError("깨진 기계 상태")
        with self.assertRaises(rd.SettingsError) as c:
            rd.resolve(self.tmp, roadmap="r/roadmap.md", roadmap_text="---\ntype: roadmap\n---\n", machine_reader=boom)
        self.assertEqual((c.exception.kind, c.exception.where), ("unreadable", "machine"))
        self.assertIn("기계 상태(임시)", str(c.exception))

    def test_git_calls_never_lazy_fetch(self):
        captured = []
        real = rd.subprocess.run

        def spy(cmd, **kw):
            captured.append(kw.get("env") or {})
            return real(cmd, **kw)
        rd.subprocess.run = spy
        self.addCleanup(setattr, rd.subprocess, "run", real)
        rd._git(self.tmp, "cat-file", "-e", "HEAD:x")
        self.assertEqual([env.get("GIT_NO_LAZY_FETCH") for env in captured], ["1"])

    def test_main_turns_unexpected_exception_into_rc3(self):
        import contextlib, io

        def boom(*_a, **_k):
            raise RuntimeError("예상 밖")
        real = rd.resolve
        rd.resolve = boom
        self.addCleanup(setattr, rd, "resolve", real)
        err, out = io.StringIO(), io.StringIO()
        with contextlib.redirect_stderr(err), contextlib.redirect_stdout(out):
            rc = rd.main(["get", "interview_dir", "--root", self.tmp])
        self.assertEqual((rc, out.getvalue()), (3, ""))
        self.assertIn("내부 오류", err.getvalue())


if __name__ == "__main__":
    unittest.main()
