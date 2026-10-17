#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_bundle_coverage.py — 자리 표기 · 에픽 이름 · AC 고르기 · 받는 곳 규칙(R5 AC11 · AC13 · AC14 · AC40).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_coverage_scope.py
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS))
import check_bundle_coverage as cbc  # noqa: E402
from roadmap_model import FormatError  # noqa: E402

SPEC = ("---\nroadmap: rm/roadmap.md\n---\n\n# 설계\n\n## 2. 이름 붙은 절\n\n1. 첫째\n\n"
        "## Acceptance Criteria\n\n- AC1 가\n- AC2 나\n- AC3 다\n- AC4 라\n\n"
        "## 미룸\n\n| 항목 | 이유 | 받는 곳 |\n|---|---|---|\n| AC3 넘김 | 이유 | R9 |\n| 다른 일 | 이유 | #4 |\n")
PLAN = "# 계획\n\n### Task 1: 하나\n\nAC1 · AC2\n"
REPORT = "AC1: 구현됨 — a\nAC2: 구현됨 — b\nAC3: 미룸 — c\nAC4: 구현됨 — d\n"
ROADMAP = ("---\ntype: roadmap\nsource_brief: b.md\n---\n\n## 에픽\n\n### R5 — 가\n- 의도: i\n- 범위: s\n- 의존: 없음\n"
           "- 브랜치: feature/a\n- 묶음: R5.md\n- 경로 예약: 없음\n\n## 결정 기록\n\n## 재분해 이력\n\n- 없음\n")


class Locations(unittest.TestCase):
    def test_numbered_h2_resolves_section(self):
        sections = cbc.design_sections(SPEC)
        self.assertIn(2, sections)
        self.assertIsNone(cbc.location_problem("§2 · §2-1", sections, ["AC1"], cbc.heading_parts(SPEC)))
        self.assertIsNotNone(cbc.location_problem("§3", sections, ["AC1"], cbc.heading_parts(SPEC)))


class EpicNames(unittest.TestCase):
    def test_capital_digits_optional_lowercase(self):
        self.assertEqual(cbc.epic_refs("P3 결정은 R2a · X9 범위, S36 은 발화", {"P3", "R2a"}), ["P3", "R2a", "X9"])
        self.assertEqual(cbc.epic_refs("AC12 와 RC85 는 에픽이 아니다", {"R5"}), [])
        self.assertEqual(cbc.epic_refs("S36 이 에픽이면", {"S36"}), ["S36"])


class Acs(unittest.TestCase):
    def test_parse(self):
        self.assertEqual(cbc.parse_acs("AC1~AC3 · AC7, AC39 AC7"), ["AC1", "AC2", "AC3", "AC7", "AC39"])
        for bad in ("", "AC3~AC1", "X1", "AC1~"):
            with self.assertRaises(FormatError):
                cbc.parse_acs(bad)

    def test_plan_only_checks_chosen_acs(self):
        self.assertEqual(cbc.check_plan(SPEC, PLAN)["missing"], ["AC3", "AC4"])
        r = cbc.check_plan(SPEC, PLAN, only=["AC1", "AC2"])
        self.assertEqual((r["status"], r["missing"], r["scoped"]), (0, [], True))
        self.assertEqual(cbc.check_plan(SPEC, PLAN, only=["AC9"])["status"], 3)

    def test_impl_only_and_receiver_rule(self):
        r = cbc.check_impl(SPEC, REPORT, only=["AC3"], epic_ids={"R5"})
        self.assertEqual(r["unreported"], [])
        self.assertEqual(r["no_receiver"], ["AC3 넘김"])
        r = cbc.check_impl(SPEC, REPORT, epic_ids={"R9"})
        self.assertEqual(r["no_receiver"], [])
        r = cbc.check_impl(SPEC, REPORT)
        self.assertEqual(r["no_receiver"], [])
        self.assertIn("로드맵 없음", r["receiver_rule"])
        r = cbc.check_impl(SPEC, REPORT, receiver_problem="로드맵을 못 읽었다: rm/roadmap.md")
        self.assertEqual(r["receiver_unknown"], ["로드맵을 못 읽었다: rm/roadmap.md"])


class Cli(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        (self.tmp / "rm").mkdir()
        (self.tmp / "rm" / "roadmap.md").write_text(ROADMAP, encoding="utf-8")
        (self.tmp / "spec.md").write_text(SPEC, encoding="utf-8")
        (self.tmp / "report.md").write_text(REPORT, encoding="utf-8")
        (self.tmp / "plan.md").write_text(PLAN, encoding="utf-8")

    def tearDown(self):
        shutil.rmtree(str(self.tmp))

    def run_cbc(self, *args):
        proc = subprocess.run([sys.executable, str(SCRIPTS / "check_bundle_coverage.py")] + list(args),
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return proc.returncode, proc.stdout.decode("utf-8"), proc.stderr.decode("utf-8")

    def test_impl_reads_roadmap_from_spec(self):
        rc, out, _err = self.run_cbc("--impl", str(self.tmp / "spec.md"), str(self.tmp / "report.md"), "--json")
        r = json.loads(out)
        self.assertEqual(r["no_receiver"], ["AC3 넘김"])
        self.assertEqual(rc, 1)

    def test_plan_with_acs(self):
        rc, out, _err = self.run_cbc("--plan", str(self.tmp / "spec.md"), str(self.tmp / "plan.md"), "--acs", "AC1~AC2")
        self.assertEqual(rc, 0, out)
        self.assertIn("--acs", out)

    def test_acs_needs_plan_or_impl_and_valid_list(self):
        self.assertEqual(self.run_cbc(str(self.tmp / "spec.md"), str(self.tmp / "spec.md"), "--acs", "AC1")[0], 2)
        self.assertEqual(self.run_cbc("--plan", str(self.tmp / "spec.md"), str(self.tmp / "plan.md"),
                                      "--acs", "X1")[0], 2)


class SpecsDir(unittest.TestCase):
    def test_repo_specs_for_reads_given_folder(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            (tmp / "design").mkdir()
            (tmp / "design" / "a.md").write_text("---\nsource_interview: rm/R5.md\n---\n", encoding="utf-8")
            repo = cbc.Repo(str(tmp))
            self.assertEqual([p for p, _t in repo.specs_for("rm/R5.md", "design/")], ["design/a.md"])
            self.assertEqual(repo.specs_for("rm/R5.md"), [])
        finally:
            shutil.rmtree(str(tmp))

    def test_other_bundle_design_under_non_default_folder(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            (tmp / "rm").mkdir()
            (tmp / "design").mkdir()
            (tmp / "rm" / "roadmap.md").write_text(
                ROADMAP.replace("source_brief: b.md\n", "source_brief: b.md\nspecs_dir: design\n"), encoding="utf-8")
            other = "---\nsource_interview: rm/R5.md\n---\nOTHER"
            (tmp / "design" / "other.md").write_text(other, encoding="utf-8")
            repo = cbc.Repo(str(tmp))
            view, why = cbc._roadmap_view({"roadmap": "rm/roadmap.md"}, repo)
            self.assertIsNone(why)
            self.assertEqual(view["specs_dir"], "design/")
            block = {"kind": "bundle", "fields": {"묶음": "R5.md"}}
            self.assertEqual(cbc._block_specs(block, view, repo), [other])
            self.assertEqual(cbc._block_specs(block, dict(view, specs_dir=cbc.SPECS_DIR), repo), [])
        finally:
            shutil.rmtree(str(tmp))

    def test_tree_repo_constructor_folder_is_honoured(self):
        import roadmap_status as rs

        class FakeTree:
            def __init__(self):
                self.folders = []

            def grep_files(self, tree, fixed, pathspec):
                self.folders.append(pathspec)
                return []

        fake = FakeTree()
        repo = rs._GitTreeRepo(fake, "tree", "design/")
        repo.specs_for("rm/R5.md")
        repo.specs_for("rm/R5.md", "other/")
        repo.specs_for("rm/R5.md", "other/")   # 같은 폴더는 메모
        self.assertEqual(fake.folders, ["design/", "other/"])


if __name__ == "__main__":
    unittest.main()
