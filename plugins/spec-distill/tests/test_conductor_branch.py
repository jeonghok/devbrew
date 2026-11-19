#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_branch.py — 상태 브랜치의 이름 · 쓸 수 있는지 · 읽기 · 쓰기 · 올리기.

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_conductor_branch.py
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from conductor_branch_fixture import ALPHA, BETA, ENV, OTHER, SCRIPTS, SID, StateRepo, rm  # noqa: E402


class Fixture(StateRepo):
    def test_two_roadmaps_are_found_and_staged(self):
        out = subprocess.run([sys.executable, str(SCRIPTS / "roadmap_status.py"), "--json", rm(ALPHA)], cwd=str(self.w),
                             env=ENV, capture_output=True, encoding="utf-8").stdout
        blocks = json.loads(out)["blocks"]
        self.assertEqual([(b["id"], b["title"], b["stage"]) for b in blocks], [("A1", "가 · 나", "준비"), ("A2", "다", "준비")])
        self.assertEqual(self.g("rev-parse", "--abbrev-ref", "origin/HEAD"), "origin/trunk")
        self.assertEqual(self.snap(), self.snap())

    def test_second_clone_shares_the_remote(self):
        other = self.clone("m2")
        self.assertEqual(self.g("rev-parse", "origin/trunk", repo=other), self.g("rev-parse", "origin/trunk"))

    def test_shallow_clone_is_really_shallow(self):   # 로컬 경로 클론은 --depth 를 무시한다 — file:// 로만 얕아진다
        d = self.clone("sh", "--depth", "1", "--no-local")
        self.assertEqual(self.g("rev-parse", "--is-shallow-repository", repo=d), "true")

    def test_state_folder_is_never_committed_and_git_runs_without_the_users_config(self):
        self.claim()
        self.put({"x.txt": "x\n"})                                   # git add -A 를 거친다
        self.epic_branch("feature/a1", {"src/a.py": "a\n"})
        for ref in ("trunk", "feature/a1"):
            self.assertEqual([p for p in self.g("ls-tree", "-r", "--name-only", ref).split("\n") if p.startswith(".claude")], [], ref)
        other = self.clone("m2")
        self.claim(repo=other)                                       # 다른 클론에서 새로 잡힌다 — 표지가 실려 오지 않았다
        self.assertEqual(os.environ["GIT_CONFIG_GLOBAL"], "/dev/null")
        self.assertEqual(self.rc("merge-base", "--is-ancestor", "trunk", "feature/a1"), 0)
        self.assertEqual(self.rc("merge-base", "--is-ancestor", "feature/a1", "trunk"), 1)   # 양성 대조 — rc 가 실제로 갈린다
