#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_status.py — 로드맵 사이 계산과 show.

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_conductor_cross.py
"""
from __future__ import annotations

import datetime
import os
import shutil
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from conductor_branch_fixture import ALPHA, BETA, SID, StateRepo, block, rm, roadmap_text  # noqa: E402
import conductor_branch as CB  # noqa: E402
import conductor_state as cs  # noqa: E402
import conductor_status as CS  # noqa: E402
import suite_lock  # noqa: E402
from state_path import state_root  # noqa: E402

KST = datetime.timezone(datetime.timedelta(hours=9))
T0 = datetime.datetime(2026, 11, 19, 2, 30, tzinfo=KST)
PLUGIN = "plugins/x/.claude-plugin/plugin.json"


def manifest(version):
    return '{"name": "x", "version": "%s"}\n' % version


class CrossRepo(StateRepo):
    """ALPHA(나)의 A1 과 BETA 의 B1 이 src/shared.py · plugin.json 을 함께 예약했다. 두 에픽 브랜치가 같은 파일을 바꾸고 같은 판을 잡는다."""
    def setUp(self):
        super().setUp()
        self.put({PLUGIN: manifest("1.0.0"), "src/shared.py": "base\n", "README.md": "r\n"})
        self.a1 = self.epic_branch("feature/a1", {"src/shared.py": "a\n", "src/a.py": "a\n", PLUGIN: manifest("1.1.0"), "README.md": "a\n"})
        self.b1 = self.epic_branch("feature/b1", {"src/shared.py": "b\n", "src/b.py": "b\n", PLUGIN: manifest("1.1.0"), "README.md": "b\n"})

    def view(self):
        return CS.cross_view(self.w, rm(ALPHA), now=T0)


class Computed(CrossRepo):
    def test_reserve_overlap_names_blocks_and_stages_and_skips_shared_files(self):
        """뒤집으면 붉다 — 공유 파일 빼기를 지우면 plugin.json 줄이 생긴다."""
        self.assertEqual(self.view()["reserve"], [{"path": "src/shared.py", "theirs": ("B1", "설계 중"), "mine": ("A1", "설계 중"), "unchecked": True,
                                                   "roadmap": BETA}])

    def test_changed_overlap_names_branches_and_skips_shared_files(self):
        self.assertEqual(self.view()["changed"], [{"path": "src/shared.py", "theirs": "feature/b1", "mine": "feature/a1", "unchecked": True,
                                                   "roadmap": BETA}])

    def test_same_version_claimed_twice(self):
        v = self.view()
        self.assertEqual(v["versions"], [{"name": "x", "base": "1.0.0", "version": "1.1.0", "holders": [(ALPHA, "feature/a1"), (BETA, "feature/b1")]}])
        self.assertEqual(v["version_unreadable"], 0)
        self.g("checkout", "-q", "feature/b1")
        (self.w / PLUGIN).write_text(manifest("1.2.0"), encoding="utf-8")
        self.g("commit", "-qam", "chore: bump")
        self.g("push", "-q", "origin", "feature/b1")
        self.g("checkout", "-q", "trunk")
        self.assertEqual(self.view()["versions"], [])                      # 판이 다르면 짚지 않는다
        self.epic_branch("feature/a2", {PLUGIN: manifest("1.1.0")})        # 같은 로드맵의 두 브랜치(J30)
        self.assertEqual(self.view()["versions"][0]["holders"], [(ALPHA, "feature/a1"), (ALPHA, "feature/a2")])

    def test_default_branch_moves_counted_on_the_first_parent_line(self):
        self.put({"src/a.py": "moved\n"}, message="예약 경로를 바꾼 커밋")
        self.put({"docs/x.md": "x\n"}, message="무관한 커밋")
        self.put({PLUGIN: manifest("1.0.1")}, message="공유 파일만 바꾼 커밋")
        self.assertEqual(self.view()["moves"], [{"branch": "feature/a1", "ahead": 3, "touching": 1, "paths": ["src/a.py"]}])

    def test_finished_roadmaps_and_merged_branches_are_left_out(self):
        self.merge_epic("feature/b1")                                      # BETA 가 끝났다
        v = self.view()
        self.assertEqual((v["reserve"], v["changed"], v["versions"]), ([], [], []))

    def test_three_roadmaps(self):
        gamma = "2026-01-03-gamma"
        self.put({rm(gamma): roadmap_text("감마", block("G1", "마", "feature/g1", "src/a.py"))})
        self.assertEqual([(r["roadmap"], r["path"]) for r in self.view()["reserve"]], [(BETA, "src/shared.py"), (gamma, "src/a.py")])

    def test_blocks_with_the_same_number_in_two_roadmaps_do_not_collide(self):   # Handoff — 번호가 로드맵마다 겹친다
        twin = "2026-01-04-twin"
        self.put({rm(twin): roadmap_text("쌍둥이", block("A1", "바", "feature/t1", "src/a.py") + block("A2", "사", "feature/t2", deps="A1"))})
        hit = [r for r in self.view()["reserve"] if r["roadmap"] == twin]
        self.assertEqual([(r["path"], r["theirs"][0], r["mine"][0]) for r in hit], [("src/a.py", "A1", "A1")])

    def test_unchecked_mark_follows_the_pr_cache_not_a_status_file(self):   # J35 · AC7 — 다른 지휘자의 STATUS 를 읽지 않는다
        plain = self.view()
        self.claim(BETA)
        CB.ensure(self.w, rm(BETA), SID)
        team = CB.team_of(self.w, rm(BETA))
        CB.write(self.w, rm(BETA), SID, lambda base: {team.status: "# STATUS — 거짓말\n\n아무 에픽도 없다\n"}, "심기")
        self.assertEqual(self.view()["reserve"], plain["reserve"])         # 그 로드맵의 STATUS 가 무엇이든 계산은 같다
        path = cs.machine_path(state_root(str(self.w)), rm(BETA))
        data = cs.empty()
        data["PR"].append(cs.no_pr_row("feature/b1", "2026-11-19 02:00", SID))
        cs.save(path, rm(BETA), data, SID)                                 # 그 브랜치의 PR 을 확인한 기록이 이 기계에 있다
        self.assertEqual([r["unchecked"] for r in self.view()["reserve"]], [False])

    def test_running_suite_of_another_roadmap(self):
        lock = suite_lock.lock_path(cs.machine_dir(state_root(str(self.w)), rm(BETA)))
        lock.mkdir(parents=True)
        (lock / "owner").write_text("%d beta-suite\n" % os.getpid(), encoding="utf-8")
        got = self.view()["suites"]
        self.assertEqual([s["roadmap"] for s in got], [BETA])
        (lock / "owner").write_text("999999 gone\n", encoding="utf-8")     # 주인 프로세스가 없다 — 도는 스위트가 아니다
        self.assertEqual(self.view()["suites"], [])
        shutil.rmtree(str(lock))
        mine = suite_lock.lock_path(cs.machine_dir(state_root(str(self.w)), rm(ALPHA)))
        mine.mkdir(parents=True)
        (mine / "owner").write_text("%d alpha-suite\n" % os.getpid(), encoding="utf-8")
        self.assertEqual(self.view()["suites"], [])                        # 내 로드맵의 스위트는 「다른 로드맵」 이 아니다

    def test_uncountable_roadmap_is_named_not_dropped(self):
        self.put({"docs/superpowers/roadmaps/2026-01-05-broken/roadmap.md": "---\ntype: roadmap\nsource_brief: b.md\n---\n\n# 깨진 로드맵\n"})
        self.assertEqual([n for n, _why in self.view()["unchecked_roadmaps"]], ["2026-01-05-broken"])


if __name__ == "__main__":
    unittest.main()
