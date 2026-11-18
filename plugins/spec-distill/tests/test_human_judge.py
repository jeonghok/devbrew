#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""human_lines.py — 판 찾기와 꼴 판정(임시 git 레포, AC4 · AC8).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_human_judge.py
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[3]
SCRIPTS = REPO / "plugins" / "spec-distill" / "scripts"
sys.path.insert(0, str(SCRIPTS))
import human_lines as H  # noqa: E402
import roadmap_status as RS  # noqa: E402
import team_layout  # noqa: E402

S, E = "00000000-0000-4000-8000-00000000aaaa", "00000000-0000-4000-8000-000000000001"
TEAM = team_layout.Team("docs/r/", "tm")
JOB = "E1"
DESIGN = "# 설계\n\n## Goals\n\n본문 하나\n\n```\n## 결정 기록\n펜스 안 글\n```\n\n## Handoff\n\n넘김\n\n### Deferred to plan\n\n| 항목 |\n\n## 미룸\n\n| 항목 |\n\n## 결정 기록\n\n- D1\n\n## 지휘 기록\n\n- 기록\n"


class Repo(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = os.path.realpath(tmp.name)
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_SYSTEM="/dev/null", GIT_TERMINAL_PROMPT="0")
        self.git_run("init", "-q", "-b", "main")
        self.git = RS.Git(self.dir)

    def git_run(self, *args):
        proc = subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@example.com", "-c", "commit.gpgsign=false", *args],
                              cwd=self.dir, env=self.env, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(proc.returncode, 0, proc.stderr.decode("utf-8", "replace"))
        return proc.stdout.decode("utf-8").strip()

    def commit(self, path, text, msg):
        full = Path(self.dir) / path
        full.parent.mkdir(parents=True, exist_ok=True)
        full.write_text(text, encoding="utf-8")
        self.git_run("add", "--", path)
        self.git_run("commit", "-q", "-m", msg, "--", path)
        return self.git_run("rev-parse", "HEAD")

    def scope(self, tip, lines=(), gate_on=True):
        return H.Scope(self.git, TEAM, JOB, tip, tuple(lines), gate_on)


class Version(Repo):
    def test_version_is_the_last_commit_that_changed_the_body(self):
        path = TEAM.design(JOB)
        c1 = self.commit(path, DESIGN, "설계")
        self.assertEqual(H.version(self.git, c1, path), c1[:8])
        c2 = self.commit(path, DESIGN.replace("- 기록", "- 기록\n- 둘째"), "기록 절만")
        self.assertEqual(H.version(self.git, c2, path), c1[:8])
        c3 = self.commit(path, DESIGN.replace("본문 하나", "본문 둘"), "본문")
        c4 = self.commit("other.txt", "x", "다른 파일")
        self.assertEqual(H.version(self.git, c4, path), c3[:8])
        c5 = self.commit(path, DESIGN, "본문을 처음 글로 되돌림")
        self.assertEqual(H.version(self.git, c5, path), c5[:8])            # c1 과 본문이 같아도 이어진 구간이 아니다
        self.assertEqual(H.version(self.git, c1, path), c1[:8])            # 끝마다 따로 센다
        self.assertIsNone(H.version(self.git, c5, TEAM.plan(JOB, 1)))


class ShapeVerdict(Repo):
    def line(self, rev, file="design.md", kind="spec 승인", label="승인 — 계획 담당자에게"):
        return H.render(kind, "2026-11-18", label, file, rev, S, E + "#1")

    def test_verdicts(self):
        path = TEAM.design(JOB)
        c1 = self.commit(path, DESIGN, "설계")
        c2 = self.commit(path, DESIGN.replace("| 항목 |", "| 항목 |\n| 새 미룸 |").replace("- 기록", "- 기록\n- 승인 직전 기록"), "미룸 · 기록 절만")
        c3 = self.commit(path, DESIGN.replace("본문 하나", "본문 둘"), "본문")
        with mock.patch.dict(os.environ, {"CLAUDE_CONFIG_DIR": "/nonexistent/claude"}):   # 꼴 판정은 세션 기록을 읽지 않는다
            self.assertEqual(H.shape(self.scope(c1), self.line(c1[:8])).verdict, H.PASS)
            self.assertEqual(H.shape(self.scope(c2), self.line(c1[:8])).verdict, H.PASS)      # AC8 — 기록 절 · 미룸 절
            stale = H.shape(self.scope(c3), self.line(c1[:8]))
            self.assertEqual((stale.verdict, "다시 승인받는다" in stale.why, stale.line.rev), (H.STALE, True, c1[:8]))
            self.assertEqual(H.shape(self.scope(c3), self.line(c3[:8])).verdict, H.PASS)
            self.assertEqual(H.shape(self.scope(c3), self.line("deadbeef")).verdict, H.UNCHECKED)
            self.assertEqual(H.shape(self.scope(c3), self.line(c3[:8], "plan-1.md", "계획 검토", "계획대로 구현한다")).verdict, H.UNCHECKED)
            none = H.shape(self.scope(c3), "- spec 승인 · 2026-11-18 · 「승인 — 계획 담당자에게」")
            self.assertEqual((none.verdict, none.line), (H.NO_EVIDENCE, None))


if __name__ == "__main__":
    unittest.main()
