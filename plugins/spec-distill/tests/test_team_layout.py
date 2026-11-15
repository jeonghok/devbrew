#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""team_layout.py — team 형식의 이름 · 경로 한 곳(R1 AC1 · AC8).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_team_layout.py
"""
from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SCRIPTS = REPO / "plugins" / "spec-distill" / "scripts"
sys.path.insert(0, str(SCRIPTS))
import team_layout as L  # noqa: E402

D = "docs/x/roadmaps/"


class Paths(unittest.TestCase):
    def test_team_paths(self):
        t = L.Team(D, "2026-a")
        self.assertEqual(t.dir, D + "2026-a")
        self.assertEqual(t.roadmap, D + "2026-a/roadmap.md")
        self.assertEqual(t.rules, D + "2026-a/RULES.md")
        self.assertEqual(t.original, D + "2026-a/intent/original.md")
        self.assertEqual((t.status, t.inbox), (D + "2026-a/STATUS.md", D + "2026-a/inbox"))
        self.assertEqual(t.intent("R3"), D + "2026-a/jobs/R3/INTENT.md")
        self.assertEqual(t.sources("R3"), D + "2026-a/jobs/R3/sources.md")
        self.assertEqual(t.keep("R3"), D + "2026-a/jobs/R3/results/.gitkeep")
        self.assertEqual(t.design("R3"), D + "2026-a/jobs/R3/design.md")
        self.assertEqual(t.plan("R3", 2), D + "2026-a/jobs/R3/plan-2.md")
        self.assertRaises(ValueError, t.plan, "R3", 0)

    def test_common_and_team_relative(self):
        self.assertEqual(L.handbook(D), D + "HANDBOOK.md")
        self.assertEqual(L.role_doc(D, "writer"), D + "writer/CLAUDE.md")
        self.assertRaises(ValueError, L.role_doc, D, "reviewer")
        self.assertEqual((L.sources_rel("R3"), L.intent_rel("R3"), L.original_rel()),
                         ("jobs/R3/sources.md", "jobs/R3/INTENT.md", "intent/original.md"))

    def test_team_from_roadmap(self):
        self.assertEqual(L.team_from_roadmap(D, D + "2026-a/roadmap.md"), L.Team(D, "2026-a"))
        for bad in (D + "2026-a/other.md", D + "a/b/roadmap.md", "elsewhere/2026-a/roadmap.md", D + "worker/roadmap.md"):
            self.assertRaises(ValueError, L.team_from_roadmap, D, bad)


class Names(unittest.TestCase):
    def test_roles_and_names(self):
        self.assertEqual(L.ROLES, ("leader", "designer", "writer", "worker"))
        for r in L.ROLES:
            self.assertTrue(L.team_name_problem(r)); self.assertTrue(L.job_name_problem(r))
        self.assertIsNone(L.team_name_problem("2026-11-14-x")); self.assertIsNone(L.job_name_problem("fix-typo_2"))
        for bad in ("", ".", "..", "a/b", ".hidden", "한글", "a b", "R1\n"):
            self.assertTrue(L.job_name_problem(bad), bad)

    def test_layout_of(self):
        self.assertIsNone(L.layout_of({"type": "roadmap"}))
        self.assertEqual(L.layout_of({"layout": '"team"'}), "team")
        for bad in ("", "Team", "teams", "old"):
            with self.assertRaises(L.UnknownLayout) as c:
                L.layout_of({"layout": bad})
            self.assertEqual(c.exception.value, bad)


class LiteralsLiveInOnePlace(unittest.TestCase):   # AC1
    def fragments(self):
        return [L.JOBS_DIR + "/", L.INTENT_DIR + "/", L.RESULTS_DIR + "/", L.RULES_FILE, L.HANDBOOK_FILE]

    def hits(self, text):
        return [f for f in self.fragments() if re.search(r"(?<![\w-])" + re.escape(f), text)]

    def test_no_other_script_spells_the_fragments(self):
        bad = {p.name: self.hits(p.read_text(encoding="utf-8")) for p in sorted(SCRIPTS.glob("*.py")) if p.name != "team_layout.py"}
        self.assertEqual({k: v for k, v in bad.items() if v}, {})
        self.assertGreater(len(list(SCRIPTS.glob("*.py"))), 40)   # 스캔이 비지 않았다

    def test_scan_has_teeth(self):   # 양성 · 음성 대조
        self.assertEqual(self.hits('p = "jobs/" + x'), ["jobs/"])
        self.assertEqual(self.hits("see RULES.md"), ["RULES.md"])
        self.assertEqual(self.hits("tool-results/x · reintent/"), [])
        self.assertEqual(len(self.fragments()), 5)


if __name__ == "__main__":
    unittest.main()
