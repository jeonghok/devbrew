#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""repo_defaults.py — 레포 설정 해결자(엄격한 머리말 · 층 · 합치기)와 기본값(R5 AC14 · R8 AC1 · AC2 · AC5).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_repo_defaults.py
"""
from __future__ import annotations

import ast
import re
import sys
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS))
import legacy_names  # noqa: E402
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
        return rd.merge_layers(None, {key: value}, LABEL, [])

    def test_folder_special_chars(self):
        for key in ("specs_dir", "plans_dir", "roadmaps_dir", "intent_dir"):
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
        self.assertEqual(rd.merge_layers(None, {}, LABEL, [])["errors"], [])


class Layers(unittest.TestCase):
    def test_typo_key_is_unknown(self):
        with self.assertRaises(rd.SettingsError) as c:
            rd.check_layer({"spec_dir": "x/"}, "repo")
        self.assertEqual(c.exception.kind, "unknown_key")

    def test_roadmap_layer_rejects_pre_roadmap_keys(self):   # AC23b
        for k in ("roadmaps_dir", "intent_dir", legacy_names.OLD_SETTING_KEY, "branch_prefix"):
            with self.assertRaises(rd.SettingsError) as c:
                rd.check_layer({k: "x/"}, "roadmap")
            self.assertEqual(c.exception.kind, "layer_key", k)

    def test_roadmap_layer_accepts_meta_and_its_settings(self):
        rd.check_layer({"type": "roadmap", "source_brief": "b.md", "specs_dir": "s/", "plans_dir": "p/", "test_command": "t",
                        "test_failure_pattern": "f", "review_model": "m", "parallel_default": "2"}, "roadmap")

    def test_repo_layer_accepts_all_keys_and_not_meta(self):
        self.assertEqual(len(rd.KEYS), 15)
        rd.check_layer({k: "x" for k in rd.KEYS}, "repo")
        with self.assertRaises(rd.SettingsError):
            rd.check_layer({"type": "roadmap"}, "repo")

    def test_machine_layer_is_gone(self):
        """기계 상태 파일은 검사받는 하위 agent 도 쓸 수 있다 — 해결자는 그 층을 갖지 않는다(테스트 명령 · 실패 꼴 포함)."""
        for meta in ({"test_command": "true"}, {"test_failure_pattern": "x"}, {}):
            with self.assertRaises(ValueError) as c:
                rd.check_layer(meta, "machine")
            self.assertNotIsInstance(c.exception, rd.SettingsError, meta)
        import inspect
        self.assertNotIn("machine", inspect.signature(rd.merge_layers).parameters)
        self.assertNotIn("machine_reader", inspect.signature(rd.resolve).parameters)


class Merge(unittest.TestCase):
    def test_missing_key_is_default_not_error(self):
        m = rd.merge_layers(None, {}, LABEL, [])
        self.assertEqual((m["values"]["intent_dir"], m["sources"]["intent_dir"]), (legacy_names.DEFAULT_DIR, "기본값"))
        self.assertEqual((m["values"]["branch_prefix"], m["values"]["roadmaps_dir"]), ("feature/", rd.ROADMAPS_DIR))
        self.assertEqual(m["errors"], [])
        self.assertEqual(list(m["values"]), list(rd.KEYS))

    def test_priority_roadmap_repo_constant(self):
        m = rd.merge_layers({"test_command": "a"}, {"test_command": "b"}, LABEL, [])
        self.assertEqual((m["values"]["test_command"], m["sources"]["test_command"]), ("a", "로드맵"))
        m = rd.merge_layers({}, {"test_command": "b"}, LABEL, [])
        self.assertEqual((m["values"]["test_command"], m["sources"]["test_command"]), ("b", LABEL))
        m = rd.merge_layers({}, {}, LABEL, [])
        self.assertEqual((m["values"]["test_command"], m["sources"]["test_command"]), (None, "기본값"))

    def test_folder_under_git_or_root_is_error(self):
        for bad in (".git/x/", "a/.git/b/", ".GIT/x/", "a/.Git/b/", ".", "./", "/abs/", "a/../b/"):
            m = rd.merge_layers(None, {"specs_dir": bad}, LABEL, [])
            self.assertIsNone(m["values"]["specs_dir"], bad)
            self.assertEqual(len(m["errors"]), 1, bad)

    def test_old_repo_settings_meaning_is_kept(self):
        m = rd.merge_layers({"specs_dir": "design", "plans_dir": '"work/plans/"', "review_model": "opus", "test_command": "'make test'"},
                            None, None, [])
        self.assertEqual((m["values"]["specs_dir"], m["values"]["plans_dir"]), ("design/", "work/plans/"))
        self.assertEqual((m["values"]["review_model"], m["values"]["test_command"]), ("opus", "make test"))
        m = rd.merge_layers({"review_model": ""}, None, None, [])
        self.assertIsNone(m["values"]["review_model"])
        self.assertTrue(any("review_model" in e for e in m["errors"]))
        for bad in ("0", "-1", "abc", "", "3.5", "３"):
            m = rd.merge_layers({"parallel_default": bad}, None, None, [])
            self.assertEqual(m["values"]["parallel_default"], 3, bad)
            self.assertEqual(m["errors"], [], bad)
            self.assertTrue(any("parallel_default" in w and "기본 3" in w for w in m["warnings"]), bad)
            self.assertEqual(m["sources"]["parallel_default"], "기본값(머리말 값이 깨졌다)", bad)
        m = rd.merge_layers({"parallel_default": "5"}, None, None, [])
        self.assertEqual((m["values"]["parallel_default"], m["sources"]["parallel_default"]), (5, "로드맵"))

    def test_layer_violation_is_an_error_and_notices_pass_through(self):
        m = rd.merge_layers({"branch_prefix": "x/"}, {}, LABEL, ["알림"])
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
            rc = rd.main(["get", "intent_dir", "--root", self.tmp])
        self.assertEqual((rc, out.getvalue()), (3, ""))
        self.assertIn("내부 오류", err.getvalue())



class IntentDirKey(unittest.TestCase):
    """설정 키 intent_dir — 옛 키 interview_dir 는 레포 층에서만 읽고 한 줄로 알린다."""
    NEW = legacy_names.DEFAULT_DIR
    OLD = legacy_names.OLD_DEFAULT_DIR

    def merged(self, repo):
        return rd.merge_layers(None, repo, LABEL, [])

    def test_no_setting_new_and_old_defaults(self):
        m = self.merged({})
        self.assertEqual(rd.intent_dirs(m), (self.NEW, self.OLD))
        self.assertEqual((m["notices"], m["errors"]), ([], []))

    def test_old_key_only(self):
        m = self.merged({"interview_dir": "docs/a/"})
        self.assertEqual(rd.intent_dirs(m), ("docs/a/", "docs/a/"))
        self.assertEqual(m["sources"]["intent_dir"], LABEL + "(옛 키 interview_dir)")
        self.assertEqual(len(m["notices"]), 1)
        self.assertIn("값(docs/a/)을 그대로 읽는다", m["notices"][0])

    def test_both_keys(self):
        m = self.merged({"intent_dir": "docs/b/", "interview_dir": "docs/a/"})
        self.assertEqual(rd.intent_dirs(m), ("docs/b/", "docs/a/"))
        self.assertEqual(m["sources"]["intent_dir"], LABEL)   # 새 키가 이긴다
        self.assertEqual(len(m["notices"]), 1)
        self.assertIn("함께 있다", m["notices"][0])
        self.assertEqual(m["errors"], [])

    def test_new_key_only(self):
        m = self.merged({"intent_dir": "docs/b/"})
        self.assertEqual(rd.intent_dirs(m), ("docs/b/", self.OLD))
        self.assertEqual((m["notices"], m["errors"]), ([], []))

    def test_old_key_in_roadmap_layer_is_layer_key(self):
        m = rd.merge_layers({"type": "roadmap", "interview_dir": "docs/a/"}, {}, LABEL, [], roadmap_path="r/roadmap.md")
        self.assertEqual(len(m["errors"]), 1)
        self.assertIn("interview_dir", m["errors"][0])
        self.assertIn("레포 설정 파일", m["errors"][0])   # layer_key 사유(unknown_key 가 아니다)
        self.assertNotIn("모르는 키", m["errors"][0])
        self.assertEqual(m["notices"], [])

    def test_broken_old_key_is_error(self):
        m = self.merged({"interview_dir": "/abs"})
        self.assertEqual(len(m["errors"]), 1)
        self.assertIn("interview_dir", m["errors"][0])
        self.assertEqual(rd.intent_dirs(m), (None, None))

    def test_broken_old_key_with_good_new_key(self):
        m = self.merged({"intent_dir": "docs/b/", "interview_dir": "/abs"})
        self.assertEqual(len(m["errors"]), 1)
        self.assertEqual(rd.intent_dirs(m), ("docs/b/", None))

    def test_keys_count_unchanged(self):
        self.assertEqual(len(rd.KEYS), 15)
        self.assertIn("intent_dir", rd.KEYS)
        self.assertNotIn("interview_dir", rd.KEYS)
        self.assertEqual(rd.KEYS.index("intent_dir"), 3)


class CheckPathIntentFolders(unittest.TestCase):
    """check-path intent_dir — 새 폴더는 지금처럼, 옛 폴더는 옛 꼴 이름만. 해결자는 설정 값으로 바꿔 끼운다."""
    OLD = legacy_names.OLD_DEFAULT_DIR
    NEW = legacy_names.DEFAULT_DIR

    def setUp(self):
        import os, subprocess, tempfile
        self.tmp = os.path.realpath(tempfile.mkdtemp())
        self.addCleanup(__import__("shutil").rmtree, self.tmp, True)
        env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
        subprocess.run(["git", "init", "-q", self.tmp], check=True, env=env)

    def check(self, repo, path, key="intent_dir", root=None):
        import contextlib, io
        real = rd.resolve
        rd.resolve = lambda *_a, **_k: rd.merge_layers(None, repo, LABEL, [])
        self.addCleanup(setattr, rd, "resolve", real)
        err, out = io.StringIO(), io.StringIO()
        try:
            with contextlib.redirect_stderr(err), contextlib.redirect_stdout(out):
                rc = rd.main(["check-path", key, path, "--root", root or self.tmp])
        except SystemExit as exc:   # argparse 오류
            rc = exc.code
        finally:
            rd.resolve = real
        return rc, err.getvalue()

    def test_check_path_new_folder_any_name(self):
        self.assertEqual(self.check({}, self.NEW + "notes.md")[0], 0)
        self.assertEqual(self.check({}, self.NEW + "x-context.md")[0], 0)

    def test_check_path_old_folder_old_name(self):
        for name in ("2026-01-01-x-interview.state.md", "2026-01-01-x-interview.md", "2026-01-01-x-interview.audit.md"):
            rc, err = self.check({}, self.OLD + name)
            self.assertEqual(rc, 0, name)
            lines = [l for l in err.splitlines() if l.strip()]
            self.assertEqual(len(lines), 1, err)   # 「값의 출처」 줄 밖은 비었다 — 받았다는 알림이 없다
            self.assertIn("값의 출처", lines[0])

    def test_old_folder_rejects_new_form_and_other(self):
        for name in ("x-context.md", "notes.md", "x-intent.md", "x-context.state.md"):
            rc, err = self.check({}, self.OLD + name)
            self.assertEqual(rc, 3, name)
            self.assertIn(self.OLD, err)
            self.assertIn(self.NEW, err)
            self.assertIn("옛 꼴 이름", err)

    def test_old_folder_name_must_end_old_form(self):
        rc, _ = self.check({}, self.OLD + "x-interview.md.bak")
        self.assertEqual(rc, 3)
        rc, _ = self.check({}, self.OLD + "x-interview-notes.md")
        self.assertEqual(rc, 3)

    def test_old_key_only_same_folder_accepts_both(self):
        repo = {"interview_dir": "docs/a/"}
        self.assertEqual(self.check(repo, "docs/a/x-context.md")[0], 0)
        self.assertEqual(self.check(repo, "docs/a/x-interview.md")[0], 0)

    def test_both_keys_old_folder_old_name_only(self):
        repo = {"intent_dir": "docs/b/", "interview_dir": "docs/a/"}
        self.assertEqual(self.check(repo, "docs/b/anything.md")[0], 0)
        self.assertEqual(self.check(repo, "docs/a/x-interview.state.md")[0], 0)
        self.assertEqual(self.check(repo, "docs/a/x-context.md")[0], 3)

    def test_other_parent_is_rejected_with_old_folder_note(self):
        rc, err = self.check({}, "docs/x/x-interview.md")
        self.assertEqual(rc, 3)
        self.assertIn("부모 폴더가 다르다", err)

    def test_roadmaps_dir_does_not_take_old_folder(self):
        rc, _ = self.check({}, self.OLD + "x-interview.md", key="roadmaps_dir")
        self.assertEqual(rc, 3)

    def test_check_path_rejects_old_key_argument(self):
        rc, _ = self.check({}, self.NEW + "x.md", key="interview_dir")
        self.assertEqual(rc, 2)

    def test_get_choices(self):
        import contextlib, io
        with contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as c:
                rd.main(["get", "interview_dir", "--root", self.tmp])
        self.assertEqual(c.exception.code, 2)

    def test_old_folder_link_rejected(self):
        import os
        link = self.tmp + "-link"
        os.symlink(self.tmp, link)
        self.addCleanup(os.unlink, link)
        rc, err = self.check({}, link + "/" + self.OLD + "x-interview.md")   # 링크로 시작하는 절대 경로 — 레포 밖으로 본다
        self.assertEqual(rc, 3)
        self.assertIn("레포 밖 경로", err)

    def test_old_folder_case_difference_rejected(self):
        rc, err = self.check({}, "docs/superpowers/Interview/x-interview.md")
        self.assertEqual(rc, 3)

    def test_old_key_broken_blocks_check(self):
        rc, _ = self.check({"interview_dir": "/abs"}, self.NEW + "x.md")
        self.assertEqual(rc, 3)


class Budgets(unittest.TestCase):   # R1 AC2
    def test_defaults_and_repo_layer(self):
        m = rd.merge_layers(None, {}, LABEL, [])
        self.assertEqual((m["values"]["rules_budget"], m["values"]["handbook_budget"]), (8192, 16384))
        m = rd.merge_layers(None, {"rules_budget": "4096", "handbook_budget": '"20000"'}, LABEL, [])
        self.assertEqual((m["values"]["rules_budget"], m["values"]["handbook_budget"]), (4096, 20000))
        self.assertEqual((m["sources"]["rules_budget"], m["errors"]), (LABEL, []))

    def test_broken_value_falls_back_with_warning(self):
        for bad in ("0", "-1", "8k", "", "８１９２"):
            m = rd.merge_layers(None, {"rules_budget": bad}, LABEL, [])
            self.assertEqual(m["values"]["rules_budget"], 8192, bad)
            self.assertTrue(any("rules_budget" in w for w in m["warnings"]), bad)

    def test_roadmap_layer_ignores_and_warns(self):
        m = rd.merge_layers({"type": "roadmap", "rules_budget": "1", "handbook_budget": "1"}, {"rules_budget": "4096"}, LABEL, [],
                            roadmap_path="r/roadmap.md")
        self.assertEqual((m["values"]["rules_budget"], m["values"]["handbook_budget"], m["errors"]), (4096, 16384, []))
        self.assertEqual(len([w for w in m["warnings"] if "레포 설정 파일" in w and "budget" in w]), 2)

    def test_layout_is_roadmap_meta_not_setting(self):
        rd.check_layer({"type": "roadmap", "source_brief": "b.md", "layout": "team"}, "roadmap")
        rd.check_layer({"layout": "no-such"}, "roadmap")   # 값은 해결자가 판정하지 않는다
        with self.assertRaises(rd.SettingsError) as c:
            rd.check_layer({"layout": "team"}, "repo")
        self.assertEqual(c.exception.kind, "unknown_key")
        self.assertNotIn("layout", rd.KEYS)


class ReadmeTable(unittest.TestCase):
    def test_every_key_has_a_row(self):
        text = (Path(__file__).resolve().parents[3] / "plugins/spec-distill/README.md").read_text(encoding="utf-8")
        for key in rd.KEYS:
            self.assertEqual(len([l for l in text.splitlines() if l.startswith("| `%s` |" % key)]), 1, key)
        for key in rd.BUDGET_KEYS:
            row = next(l for l in text.splitlines() if l.startswith("| `%s` |" % key))
            self.assertTrue(row.rstrip().endswith("| 무시하고 경고 |"), row)


class WalkTable(unittest.TestCase):   # R2 AC20 — 계획 2 몫
    def merged(self, repo=None, roadmap=None):
        return rd.merge_layers(roadmap, repo, "레포 설정", [])

    def test_default_is_none_and_place_is_before_human_gate(self):
        out = self.merged()
        self.assertEqual((out["values"]["walk_table"], out["sources"]["walk_table"]), (None, "기본값"))
        self.assertEqual(rd.KEYS[rd.KEYS.index("walk_table") + 1], "human_gate")

    def test_repo_relative_file_path(self):
        out = self.merged(repo={"walk_table": "docs/walk.md"})
        self.assertEqual((out["values"]["walk_table"], out["errors"]), ("docs/walk.md", []))
        self.assertEqual(self.merged(repo={"walk_table": '"docs/a #1.md"'})["values"]["walk_table"], "docs/a #1.md")

    def test_bad_paths_are_errors(self):
        for raw in ("/abs/walk.md", "~/walk.md", "docs/", "a/../walk.md", "./walk.md", ".git/walk.md", "docs/*.md", ":walk.md", ""):
            out = self.merged(repo={"walk_table": raw})
            self.assertIsNone(out["values"]["walk_table"], raw)
            self.assertTrue(out["errors"] and "walk_table" in out["errors"][0], raw)

    def test_roadmap_layer_does_not_take_it(self):
        out = self.merged(roadmap={"type": "roadmap", "walk_table": "docs/walk.md"})
        self.assertTrue(any("walk_table" in e for e in out["errors"]))
        self.assertIsNone(out["values"]["walk_table"])


class StateBranchKey(unittest.TestCase):   # R3 AC14
    def merged(self, repo=None, roadmap=None):
        return rd.merge_layers(roadmap, repo, LABEL, [])

    def test_default_is_on(self):
        out = self.merged()
        self.assertEqual((out["values"]["state_branch"], out["sources"]["state_branch"]), ("켬", "기본값"))
        self.assertTrue(rd.state_branch_on(out["values"]))

    def test_off_only_by_the_exact_word(self):
        out = self.merged(repo={"state_branch": "끔"})
        self.assertEqual((out["values"]["state_branch"], out["errors"]), ("끔", []))
        self.assertFalse(rd.state_branch_on(out["values"]))
        self.assertTrue(rd.state_branch_on(self.merged(repo={"state_branch": '"켬"'})["values"]))

    def test_other_words_are_errors_and_count_as_off(self):   # 닫는 쪽 — 깨진 값으로는 원격에 쓰지 않는다
        for word in ("off", "false", "0", "꺼짐", "켬켬", "끔끔", ""):
            out = self.merged(repo={"state_branch": '"%s"' % word})
            self.assertIsNone(out["values"]["state_branch"], word)
            self.assertEqual(len(out["errors"]), 1, word)
            self.assertIn("state_branch", out["errors"][0])
            self.assertFalse(rd.state_branch_on(out["values"]), word)

    def test_roadmap_layer_does_not_take_it(self):
        out = self.merged(roadmap={"type": "roadmap", "source_brief": "b.md", "state_branch": "끔"})
        self.assertTrue(any("state_branch" in e for e in out["errors"]))
        self.assertTrue(rd.state_branch_on(out["values"]))   # 로드맵 머리말의 값으로는 꺼지지 않는다

    def test_constants(self):
        self.assertEqual(rd.BRANCH_RULE_FILE, "docs/git-workflow/branch-strategy.md")
        self.assertEqual((rd.VERSION_FILE, rd.SHARED_FILES), ("plugin.json", ("plugin.json", "CHANGELOG.md", "README.md")))
        self.assertEqual(rd.KEYS[-1], "state_branch")


class HumanGate(unittest.TestCase):
    def merged(self, repo=None, roadmap=None):
        return rd.merge_layers(roadmap, repo, "레포 설정", [])

    def test_default_is_on(self):
        out = self.merged()
        self.assertEqual((out["values"]["human_gate"], out["sources"]["human_gate"]), ("켬", "기본값"))
        self.assertTrue(rd.gate_on(out["values"]))

    def test_off_only_by_the_exact_word(self):
        out = self.merged(repo={"human_gate": "끔"})
        self.assertEqual((out["values"]["human_gate"], out["errors"]), ("끔", []))
        self.assertFalse(rd.gate_on(out["values"]))
        self.assertTrue(rd.gate_on(self.merged(repo={"human_gate": '"켬"'})["values"]))

    def test_other_words_are_errors_and_stay_on(self):
        for word in ("off", "false", "0", "꺼짐", ""):
            out = self.merged(repo={"human_gate": word})
            self.assertIsNone(out["values"]["human_gate"], word)
            self.assertEqual(len(out["errors"]), 1, word)
            self.assertIn("human_gate", out["errors"][0])
            self.assertTrue(rd.gate_on(out["values"]), word)

    def test_roadmap_layer_does_not_take_it(self):
        out = self.merged(roadmap={"type": "roadmap", "human_gate": "끔"})
        self.assertTrue(any("human_gate" in e for e in out["errors"]))
        self.assertTrue(rd.gate_on(out["values"]))

    def test_gate_reading_code_does_not_look_at_the_environment(self):   # AC20 — 환경 변수로는 꺼지지 않는다
        def reads_environment(path, name):
            """그 파일에서 이름이 name 인 함수의 몸에 environ · getenv 가 나오는가."""
            tree = ast.parse(path.read_text(encoding="utf-8"))
            found = [n for n in ast.walk(tree) if isinstance(n, ast.FunctionDef) and n.name == name]
            self.assertTrue(found, name)
            return any(getattr(x, "attr", getattr(x, "id", "")) in ("environ", "getenv") for f in found for x in ast.walk(f))
        self.assertFalse(reads_environment(SCRIPTS / "repo_defaults.py", "gate_on"))
        self.assertFalse(reads_environment(SCRIPTS / "repo_defaults.py", "merge_layers"))
        self.assertTrue(reads_environment(SCRIPTS / "state_path.py", "resolve_session_id"))   # 양성 대조 — 탐침이 환경 읽기를 본다


if __name__ == "__main__":
    unittest.main()
