#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""에픽 병렬 권장 — 공유 파일 설정 키 (뒤 과제가 클래스를 더한다).

Run (리포 루트에서): PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_parallel_recommend.py -v
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS))
import repo_defaults as rd  # noqa: E402
import roadmap_status as rs  # noqa: E402
import control_plane as cp  # noqa: E402
import spec_review_bundle as sb  # noqa: E402

FIXTURE = Path(__file__).resolve().parent / "fixtures" / "conductor-e2e"

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


def _blocks(a_res, b_res):
    return [{"id": "A", "deps": [], "reserved": a_res}, {"id": "B", "deps": [], "reserved": b_res}]


class Overlaps(unittest.TestCase):
    def test_folder_and_shared_file_either_order(self):
        for a, b in ((["plugins/x/"], ["plugins/x/README.md"]), (["plugins/x/README.md"], ["plugins/x/"])):
            self.assertEqual(rs.overlaps(_blocks(a, b)), [], (a, b))

    def test_two_folders_still_overlap(self):
        self.assertEqual([o["blocks"] for o in rs.overlaps(_blocks(["plugins/x/"], ["plugins/x/sub/"]))], [["A", "B"]])

    def test_names_argument(self):
        self.assertEqual(rs.overlaps(_blocks(["p/NOTICE"], ["p/NOTICE"]), names=("NOTICE",)), [])
        self.assertEqual(len(rs.overlaps(_blocks(["p/README.md"], ["p/README.md"]), names=("NOTICE",))), 1)


class RoadmapRepo(unittest.TestCase):
    """기본 브랜치가 trunk 인 임시 원격 + 클론. 뒤 과제의 테스트가 이어받는다."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="parrec-")
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1",
                        PYTHONDONTWRITEBYTECODE="1")
        self.origin = os.path.join(self.tmp, "origin.git")
        self.w = os.path.join(self.tmp, "w")
        self.git(self.tmp, "init", "--bare", "-b", "trunk", self.origin)
        self.git(self.tmp, "init", "-b", "trunk", self.w)
        self.git(self.w, "remote", "add", "origin", self.origin)
        self.git(self.w, "checkout", "-B", "trunk")
        os.makedirs(os.path.join(self.w, "plan", "br"))
        for name in ("b.md", "b.audit.md"):
            shutil.copy(FIXTURE / name, os.path.join(self.w, "plan", "br", name))
        self.n = 0

    def git(self, cwd, *args):
        proc = subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@example.invalid",
                               "-c", "commit.gpgsign=false", *args], cwd=cwd, env=self.env,
                              capture_output=True, text=True, encoding="utf-8")
        if proc.returncode != 0:
            raise AssertionError("git %s: %s" % (" ".join(args), proc.stderr))
        return proc.stdout

    def write(self, root, rel, text):
        path = os.path.join(root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        Path(path).write_text(text, encoding="utf-8")

    def roadmap(self, blocks, settings=None, front_extra=""):
        """blocks: (id, deps, reserved 글, ids). 빈 reserved 글은 「없음」."""
        head = ("---\ntype: roadmap\nsource_brief: plan/br/b.md\nspecs_dir: plan/specs/\n"
                "plans_dir: plan/plans/\n%s---\n\n# 버릴 로드맵\n\n## 에픽\n\n" % (front_extra + "\n" if front_extra else ""))
        body = ""
        for eid, deps, reserved, ids in blocks:
            body += ("### %s — 에픽\n- 의도: 한 바퀴\n- 범위:\n  - 한다: 일\n  - 안 한다: 화면\n"
                     "- 의존: %s\n- 브랜치: work/%s\n- 묶음: %s.md\n- 경로 예약: %s\n\n"
                     % (eid, ", ".join(deps) or "없음", eid.lower(), eid, reserved or "없음"))
            self.write(self.w, "plan/rm/%s.md" % eid,
                       "---\ntype: epic-bundle\nepic: %s\nroadmap: plan/rm/roadmap.md\nsource_brief: plan/br/b.md\n"
                       "ids: [%s]\n---\n\n# %s\n" % (eid, ", ".join(ids), eid))
        tail = ("## 지휘 절차\n\n이 로드맵은 지휘자가 이끈다.\n\n## 결정 기록\n\n## 재분해 이력\n\n- 없음\n\n"
                "## 위험 번호표\n\n- K1 — 위험 — 숨은 가정: 버릴 가정 — 근거 없음\n")
        self.write(self.w, "plan/rm/roadmap.md", head + body + tail)
        if settings is not None:
            self.write(self.w, ".devbrew.md", settings)
        self.git(self.w, "add", "-A")
        self.git(self.w, "commit", "-m", "로드맵")
        self.git(self.w, "push", "-u", "origin", "trunk")
        self.git(self.w, "remote", "set-head", "origin", "--auto")

    def start_design(self, epic, extra="", base="origin/HEAD"):
        path = os.path.join(self.tmp, epic)
        self.git(self.w, "worktree", "add", path, "-b", "work/" + epic.lower(), base)
        self.write(path, "plan/specs/%s-design.md" % epic,
                   "---\nsource_interview: plan/rm/%s.md\nroadmap: plan/rm/roadmap.md\n---\n\n# %s 설계\n\n"
                   "## Goals\n\n- %s 목표\n\n## 결정 기록\n%s\n" % (epic, epic, epic, extra))
        self.git(path, "add", "-A")
        self.git(path, "commit", "-m", "설계 " + epic)
        self.git(path, "push", "-u", "origin", "work/" + epic.lower())
        return path

    def merge(self, epic):
        self.n += 1
        self.git(self.w, "checkout", "trunk")
        self.git(self.w, "merge", "--no-ff", "work/" + epic.lower(), "-m",
                 "Merge pull request #%d from o/work/%s" % (self.n, epic.lower()))
        self.git(self.w, "push", "origin", "trunk")
        self.git(self.w, "fetch", "origin")

    def status(self):
        proc = subprocess.run([sys.executable, str(SCRIPTS / "roadmap_status.py"), "--json", "plan/rm/roadmap.md"],
                              cwd=self.w, env=self.env, capture_output=True, text=True, encoding="utf-8")
        try:
            return json.loads(proc.stdout)
        except ValueError:
            raise AssertionError("roadmap_status.py 출력이 JSON 이 아니다: rc=%s stderr=%r stdout=%r"
                                 % (proc.returncode, proc.stderr, proc.stdout[:200]))


TWO = [("E1", [], "", ("C1", "S1", "OQ1")), ("E2", [], "", ("«e2e-k»", "K1"))]


class SharedOverlapInStatus(RoadmapRepo):
    def test_plain_fixture_is_clean(self):
        self.roadmap(TWO)
        r = self.status()
        self.assertEqual((r["format_errors"], r["unknown_reasons"], r["overlaps"]), ([], [], []))

    def test_shared_only_overlap_is_not_overlap(self):
        self.roadmap([("E1", [], "plugins/p/README.md, src/a.txt", ("C1", "S1", "OQ1")),
                      ("E2", [], "plugins/p/", ("«e2e-k»", "K1"))])
        self.assertEqual(self.status()["overlaps"], [])

    def test_real_overlap_still_reported(self):
        self.roadmap([("E1", [], "src/a.txt", ("C1", "S1", "OQ1")), ("E2", [], "src/", ("«e2e-k»", "K1"))])
        self.assertEqual([o["blocks"] for o in self.status()["overlaps"]], [["E1", "E2"]])

    def test_repo_setting_changes_shared_list(self):
        self.roadmap([("E1", [], "plugins/p/NOTICE", ("C1", "S1", "OQ1")),
                      ("E2", [], "plugins/p/NOTICE", ("«e2e-k»", "K1"))],
                     settings="---\nshared_files: NOTICE\n---\n")
        self.assertEqual(self.status()["overlaps"], [])

    def test_roadmap_layer_value_does_not_make_status_unknown(self):
        self.roadmap(TWO, front_extra="shared_files: X.md")
        r = self.status()
        self.assertEqual((r["format_errors"], r["unknown_reasons"]), ([], []))
        self.assertTrue(any("shared_files" in w for w in r["settings"]["warnings"]))


class ReservationNoteRespectsSharedList(RoadmapRepo):
    def _notes(self, settings):
        self.roadmap([("E1", [], "plugins/p/", ("C1", "S1", "OQ1")), ("E2", [], "src/b.txt", ("«e2e-k»", "K1"))],
                     settings=settings)
        path = self.start_design("E2")
        self.write(path, "plugins/p/NOTICE", "x\n")
        self.git(path, "add", "-A")
        self.git(path, "commit", "-m", "공지")
        self.git(path, "push", "origin", "work/e2")
        self.git(self.w, "fetch", "origin")
        return next(b for b in self.status()["blocks"] if b["id"] == "E2")["notes"]

    def test_listed_shared_file_gives_no_violation_note(self):
        notes = self._notes("---\nshared_files: NOTICE\n---\n")
        self.assertFalse(any("경로 예약 위반" in n for n in notes), notes)

    def test_without_setting_the_note_appears(self):
        notes = self._notes(None)
        self.assertTrue(any("경로 예약 위반" in n and "plugins/p/NOTICE" in n for n in notes), notes)


def _b(bid, stage, parallel=()):
    return {"id": bid, "stage": stage, "parallel": [{"id": p, "overlap": o} for p, o in parallel]}


class ParallelLineUnit(unittest.TestCase):
    def test_two_ready(self):
        self.assertEqual(cp.parallel_line([_b("R1", "준비", [("R2", [])]), _b("R2", "준비", [("R1", [])])]),
                         "동시에 갈 수 있는 준비 에픽: R1(함께: R2) · R2(함께: R1)")

    def test_filters(self):
        self.assertIsNone(cp.parallel_line([_b("R1", "준비", [("R2", ["x/"])]), _b("R2", "준비", [("R1", ["x/"])])]))
        self.assertIsNone(cp.parallel_line([_b("R1", "준비", [("R2", [])]), _b("R2", "대기", [("R1", [])])]))
        self.assertIsNone(cp.parallel_line([_b("R1", "준비", [("R2", [])]), _b("R2", "알 수 없음", [("R1", [])])]))
        self.assertIsNone(cp.parallel_line([_b("R1", "준비", [])]))
        self.assertIsNone(cp.parallel_line([_b("R1", "설계 중", [("R2", [])]), _b("R2", "설계 중", [("R1", [])])]))

    def test_in_progress_partner(self):
        self.assertEqual(cp.parallel_line([_b("R1", "구현 중", [("R2", [])]), _b("R2", "준비", [("R1", [])])]),
                         "동시에 갈 수 있는 준비 에픽: R2(함께: R1)")

    def test_tasks_output_appends_tabless_last_line(self):
        rep = {"exit": 0, "blocks": [dict(_b("R1", "준비", [("R2", [])]), title="가", task_status="pending"),
                                     dict(_b("R2", "준비", [("R1", [])]), title="나", task_status="pending")]}
        out, err, rc = cp.tasks_output([("rm.md", rep)])
        self.assertEqual(rc, 0)
        self.assertEqual(out[:2], ["R1 가 — 준비\tpending", "R2 나 — 준비\tpending"])
        self.assertEqual(out[2], "동시에 갈 수 있는 준비 에픽: R1(함께: R2) · R2(함께: R1)")
        self.assertNotIn("\t", out[2])


LINE = "동시에 갈 수 있는 준비 에픽: "


class ParallelLineInRepo(RoadmapRepo):
    def tasks(self):
        proc = subprocess.run([sys.executable, str(SCRIPTS / "control_plane.py"), "show", "--tasks",
                               "plan/rm/roadmap.md"], cwd=self.w, env=self.env, capture_output=True,
                              text=True, encoding="utf-8")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        return proc.stdout.splitlines()

    def assert_only_last_tabless(self, lines, has_line):
        tabless = [l for l in lines if "\t" not in l]
        self.assertEqual(tabless, lines[-1:] if has_line else [])

    def test_two_ready_no_overlap(self):
        self.roadmap(TWO)
        lines = self.tasks()
        self.assertEqual(lines[-1], LINE + "E1(함께: E2) · E2(함께: E1)")
        self.assert_only_last_tabless(lines, True)

    def test_dependent_has_no_line(self):
        self.roadmap([("E1", [], "", ("C1", "S1", "OQ1")), ("E2", ["E1"], "", ("«e2e-k»", "K1"))])
        lines = self.tasks()
        self.assertIn("\t", lines[-1])
        self.assert_only_last_tabless(lines, False)

    def test_real_overlap_has_no_line(self):
        self.roadmap([("E1", [], "src/a.txt", ("C1", "S1", "OQ1")), ("E2", [], "src/a.txt", ("«e2e-k»", "K1"))])
        self.assert_only_last_tabless(self.tasks(), False)

    def test_shared_file_only_overlap_has_line(self):
        self.roadmap([("E1", [], "plugins/p/README.md", ("C1", "S1", "OQ1")),
                      ("E2", [], "plugins/p/", ("«e2e-k»", "K1"))])
        self.assertEqual(self.tasks()[-1], LINE + "E1(함께: E2) · E2(함께: E1)")

    def test_in_progress_partner(self):
        self.roadmap(TWO)
        self.start_design("E1", extra="\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n"
                                      "| C1 | 반영 | AC1 |\n| S1 | 반영 | AC1 |\n| OQ1 | 반영 | AC1 |\n")
        lines = self.tasks()
        self.assertEqual(lines[-1], LINE + "E2(함께: E1)")
        self.assert_only_last_tabless(lines, True)


class DecisionLines(unittest.TestCase):
    def test_three_forms(self):
        for line in ("- B1 · 결정 · 2026-10-25 · 사용자 — 「가」", "- U3 · 결정 · 나", "- D2.6 · r2 · adopt · x"):
            self.assertTrue(sb.DECISION_LINE_RE.match(line), line)

    def test_not_decision_lines(self):
        for line in ("  - D1.1 · r1 · adopt", "- D2 · 결정 · 가", "- docreview 계수 — x", "- B1 결정"):
            self.assertFalse(sb.DECISION_LINE_RE.match(line), line)


def _table(*ids):
    return ("\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n"
            + "".join("| %s | 반영 | AC1 |\n" % i for i in ids))


class NeighborDecisions(RoadmapRepo):
    E2_DEC = "- U1 · 결정 · 유\n- D1.1 · r1 · adopt · 디\n"

    def neighbors(self):
        return sb.neighbors(os.path.join(self.w, "plan", "rm", "E1.md"), str(self.w))

    def test_parallel_epic_with_design_doc(self):
        self.roadmap(TWO)
        self.start_design("E2", extra=self.E2_DEC + _table("«e2e-k»", "K1"))
        self.start_design("E1", extra=_table("C1", "S1", "OQ1"))
        lines = self.neighbors()
        self.assertTrue(any(l.startswith("  함께 진행 중: E2 ") for l in lines), lines)
        self.assertIn("    - U1 · 결정 · 유", lines)
        self.assertIn("    - D1.1 · r1 · adopt · 디", lines)

    def test_dependent_is_not_parallel(self):
        self.roadmap([("E1", [], "", ("C1", "S1", "OQ1")), ("E2", ["E1"], "", ("«e2e-k»", "K1"))])
        self.start_design("E2", extra=self.E2_DEC + _table("«e2e-k»", "K1"))
        self.start_design("E1", extra=_table("C1", "S1", "OQ1"))
        lines = self.neighbors()
        self.assertTrue(any(l.startswith("  이 에픽에 의존: E2 ") for l in lines), lines)
        self.assertFalse(any("함께 진행 중" in l for l in lines), lines)

    def test_format_error_roadmap_degrades_with_notice(self):
        self.roadmap(TWO)
        path = os.path.join(self.w, "plan", "rm", "roadmap.md")
        text = Path(path).read_text(encoding="utf-8")
        Path(path).write_text(text.replace("- 의존: 없음\n", "- 의존: 없음\n- 의존: 없음\n", 1), encoding="utf-8")
        self.git(self.w, "commit", "-am", "형식 깨뜨림")
        self.git(self.w, "push", "origin", "trunk")
        self.assertTrue(self.status()["format_errors"])
        lines = self.neighbors()
        self.assertTrue(any("로드맵 상태 검사 불가" in l or "보일 수 없다" in l for l in lines), lines)


if __name__ == "__main__":
    unittest.main()
