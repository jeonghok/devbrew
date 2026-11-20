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


class ResultNames(unittest.TestCase):   # 계획 2 — 단계와 결과 파일 이름
    def test_stages_and_names(self):
        self.assertEqual(L.STAGES, ("design", "plan", "implement", "review"))
        self.assertEqual(L.PLANNED_STAGES, ("plan", "implement", "review"))
        self.assertEqual(L.BLOCKED_FILE, "BLOCKED.md")
        self.assertEqual(L.result_name("implement", 2, plan=1), "implement-plan-1-2.md")
        self.assertEqual(L.result_name("design", 1), "design-1.md")
        self.assertEqual(L.result_name("plan", 3, plan=2), "plan-plan-2-3.md")
        for bad in (("deploy", 1, None), ("implement", 0, None), ("implement", 1, 0), ("design", 1, 1)):
            self.assertRaises(ValueError, L.result_name, *bad)

    def test_parse_result_name(self):
        for name, want in (("implement-plan-1-2.md", ("implement", 1, 2)), ("review-4.md", ("review", None, 4)),
                           ("plan-plan-2-3.md", ("plan", 2, 3)), ("plan-3.md", ("plan", None, 3)), ("design-10.md", ("design", None, 10))):
            self.assertEqual(L.parse_result_name(name), want, name)
            self.assertEqual(L.result_name(want[0], want[2], want[1]), name)   # 왕복
        for bad in ("BLOCKED.md", ".gitkeep", "implement-plan-01-2.md", "implement-0.md", "design-plan-1-1.md", "implement-1.md\n",
                    "implement-plan-1.2.md", "Implement-1.md", "implement-1.txt", "implement--1.md", ""):
            self.assertIsNone(L.parse_result_name(bad), bad)

    def test_plan_names(self):
        self.assertEqual((L.plan_name(2), L.plan_number("plan-2.md")), ("plan-2.md", 2))
        self.assertEqual(L.Team(D, "2026-a").plan("R3", 2), D + "2026-a/jobs/R3/" + L.plan_name(2))
        for bad in ("plan-02.md", "plan-0.md", "plan-2.md.bak", "plan-.md", "plan-2.MD", "plan-2.md\n"):
            self.assertIsNone(L.plan_number(bad), bad)
        self.assertRaises(ValueError, L.plan_name, 0)
        self.assertEqual((L.plan_shape_digits("plan-0.md"), L.plan_shape_digits("plan-02.md"), L.plan_shape_digits("plan-x.md")), ("0", "02", None))

    def test_job_paths(self):
        t = L.Team(D, "2026-a")
        self.assertEqual(t.jobs, D + "2026-a/jobs")
        self.assertEqual(t.result("R3", "implement", 1, plan=2), D + "2026-a/jobs/R3/results/implement-plan-2-1.md")
        self.assertEqual(t.blocked("R3"), D + "2026-a/jobs/R3/results/BLOCKED.md")
        self.assertEqual(L.job_of_path(D, t.result("R3", "implement", 1)), (t, "R3", "results/implement-1.md"))
        self.assertEqual(L.job_of_path(D, t.intent("fix-typo"))[1:], ("fix-typo", "INTENT.md"))
        for bad in (t.roadmap, t.rules, t.job("R3"), t.job("R3") + "/", "elsewhere/2026-a/jobs/R3/INTENT.md",
                    D + "worker/jobs/R3/INTENT.md", D + "2026-a/jobs/leader/INTENT.md", D + "2026-a/jobs/a b/INTENT.md", D + "jobs/R3/INTENT.md"):
            self.assertIsNone(L.job_of_path(D, bad), bad)


class RolesAndRefs(unittest.TestCase):   # 계획 3 — 기본 역할(§9) · 리더가 쓰는 파일을 읽을 ref(§15 · AC31)
    def test_default_roles(self):
        self.assertEqual([L.default_role(s) for s in L.STAGES], ["leader", "worker", "worker", None])
        self.assertRaises(ValueError, L.default_role, "deploy")
        self.assertEqual(L.LEADER_ROLE, "leader")

    def test_leader_ref_is_the_state_tip_or_the_given_ref(self):
        self.assertEqual(L.leader_ref("refs/remotes/origin/HEAD"), "refs/remotes/origin/HEAD")
        self.assertEqual(L.leader_ref("0" * 40), "0" * 40)   # 커밋을 줘도 그대로
        self.assertEqual(L.leader_ref("refs/remotes/origin/HEAD", "b" * 40), "b" * 40)


if __name__ == "__main__":
    unittest.main()
