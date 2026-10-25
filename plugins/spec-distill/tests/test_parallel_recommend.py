#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""에픽 병렬 권장 — 공유 파일 설정 키 (뒤 과제가 클래스를 더한다).

Run (리포 루트에서): PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_parallel_recommend.py -v
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS))
import repo_defaults as rd  # noqa: E402

DEFAULT = ("plugin.json", "CHANGELOG.md", "README.md")


def merged(roadmap=None, repo=None, machine=None):
    return rd.merge_layers(roadmap, repo, "레포 설정@0123abcd" if repo is not None else None, machine, [])


class SharedFilesSetting(unittest.TestCase):
    def test_absent_is_default(self):
        m = merged(repo={})
        self.assertEqual(m["values"]["shared_files"], DEFAULT)
        self.assertEqual(m["errors"], [])

    def test_value_is_parsed(self):
        m = merged(repo={"shared_files": "plugin.json, CHANGELOG.md, NOTICE"})
        self.assertEqual(m["values"]["shared_files"], ("plugin.json", "CHANGELOG.md", "NOTICE"))
        self.assertEqual(m["warnings"], [])

    def test_broken_values_fall_back_with_warning(self):
        for bad in ("", "a, , b", "a,", "docs/README.md, b"):
            m = merged(repo={"shared_files": bad})
            self.assertEqual(m["values"]["shared_files"], DEFAULT, bad)
            self.assertEqual(m["errors"], [], bad)
            self.assertTrue(any("shared_files" in w for w in m["warnings"]), bad)

    def test_roadmap_and_machine_layer_are_ignored_with_warning(self):
        for layer in ("roadmap", "machine"):
            kw = {layer: {"shared_files": "X.md"}, "repo": {"shared_files": "Y.md"}}
            m = merged(**kw)
            self.assertEqual(m["errors"], [], layer)
            self.assertEqual(m["values"]["shared_files"], ("Y.md",), layer)
            self.assertTrue(any("shared_files" in w for w in m["warnings"]), layer)

    def test_quoted_whole_value_with_hash(self):
        meta = rd.strict_frontmatter('---\nshared_files: "note #1.md, README.md"\n---\n', "repo")
        m = merged(repo=meta)
        self.assertEqual(m["values"]["shared_files"], ("note #1.md", "README.md"))

    def test_get_prints_comma_list(self):
        env = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@e", GIT_COMMITTER_NAME="t",
                   GIT_COMMITTER_EMAIL="t@e", GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_SYSTEM=os.devnull)

        def git(cwd, *args):
            subprocess.run(["git", *args], cwd=cwd, env=env, check=True, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL)

        with tempfile.TemporaryDirectory() as tmp:
            bare, repo = os.path.join(tmp, "origin.git"), os.path.join(tmp, "repo")
            git(tmp, "init", "--bare", "-b", "trunk", bare)
            git(tmp, "init", "-b", "trunk", repo)
            Path(repo, ".devbrew.md").write_text("---\nshared_files: a.md, b.md\n---\n", encoding="utf-8")
            git(repo, "add", ".devbrew.md")
            git(repo, "commit", "-m", "init")
            git(repo, "remote", "add", "origin", bare)
            git(repo, "push", "-u", "origin", "trunk")
            git(repo, "remote", "set-head", "origin", "--auto")
            proc = subprocess.run([sys.executable, str(SCRIPTS / "repo_defaults.py"), "get", "shared_files",
                                   "--root", repo], env=dict(env, PYTHONDONTWRITEBYTECODE="1"),
                                  capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout, "a.md, b.md\n")


if __name__ == "__main__":
    unittest.main()
