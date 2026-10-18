#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_ledger.py — 기계 상태 쓰기 · 표지 · 시작 승인 · 로드맵 찾기(R5 계획 3 Task 4). 뒤 Task 가 클래스를 더한다.

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py
"""
from __future__ import annotations

import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS))
import conductor_ledger as L  # noqa: E402
import conductor_state as cs  # noqa: E402

SID, OTHER = "session-aaaa1111", "session-bbbb2222"
RM = "plan/rm/roadmap.md"
ENV = dict(os.environ, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1")


def sh(cwd, *args):
    return subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@x", "-c", "commit.gpgsign=false", *args],
                          cwd=str(cwd), env=ENV, capture_output=True, encoding="utf-8", check=True).stdout


def roadmap(blocks):
    head = "---\ntype: roadmap\nsource_brief: b.md\n---\n\n# r\n\n## 에픽\n\n"
    tail = "## 결정 기록\n\n## 재분해 이력\n\n- 없음\n\n## 위험 번호표\n"
    return head + blocks + tail


BLOCK = ("### A1 — 가\n- 의도: 가\n- 범위:\n  - 한다: x\n  - 안 한다: y\n- 의존: 없음\n- 브랜치: feature/a1\n"
         "- 묶음: A1.md\n- 경로 예약: 없음\n\n"
         "### A2 — 나\n- 의도: 나\n- 범위:\n  - 한다: z\n  - 안 한다: w\n- 의존: 없음\n- 브랜치: feature/a2\n"
         "- 묶음: A2.md\n- 경로 예약: 없음\n\n")


class Repo(unittest.TestCase):
    """원격(bare, 기본 브랜치 trunk)과 클론 하나. self.w 가 작업 레포."""
    def setUp(self):
        self.t = Path(tempfile.mkdtemp())
        self.o, self.w = self.t / "o.git", self.t / "w"
        subprocess.run(["git", "init", "-q", "--bare", "-b", "trunk", str(self.o)], env=ENV, check=True)
        subprocess.run(["git", "clone", "-q", str(self.o), str(self.w)], env=ENV, capture_output=True, check=True)
        sh(self.w, "checkout", "-q", "-B", "trunk")
        (self.w / "plan/rm").mkdir(parents=True)
        (self.w / RM).write_text(roadmap(BLOCK), encoding="utf-8")
        (self.w / "notes.md").write_text("---\ntype: note\n---\n", encoding="utf-8")
        sh(self.w, "add", "-A")
        sh(self.w, "commit", "-qm", "base")
        sh(self.w, "push", "-q", "origin", "trunk")
        sh(self.w, "remote", "set-head", "origin", "--auto")

    def tearDown(self):
        shutil.rmtree(str(self.t), ignore_errors=True)

    def cli(self, *args):
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = L.main(["--root", str(self.w), *args])
        return rc, buf.getvalue()


class Fixture(unittest.TestCase):
    def test_roadmap_fixture_parses(self):
        import roadmap_model as M
        _m, blocks, _r, _k, errors = M.parse_roadmap(roadmap(BLOCK))
        self.assertEqual(errors, [])
        self.assertEqual([b["id"] for b in blocks], ["A1", "A2"])


class Marker(Repo):
    def test_claim_held_other(self):
        self.assertEqual(self.cli("claim", "--roadmap", RM, "--session", SID)[0], 0)
        rc, out = self.cli("claim", "--roadmap", RM, "--session", SID)
        self.assertEqual((rc, out.strip()), (0, "held"))
        rc, out = self.cli("claim", "--roadmap", RM, "--session", OTHER)
        self.assertEqual(rc, 5)
        self.assertIn(SID, out)
        self.assertIn("읽기 전용", out)

    def test_write_needs_marker(self):
        rc, out = self.cli("add", "--roadmap", RM, "--session", SID, "--section", "자원",
                           "--cells", "worktree · /x · A1 · 설계 · 2026-10-18")
        self.assertEqual(rc, 5)
        self.assertIn("읽기 전용", out)

    def test_add_drop_round_trip(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        rc, _o = self.cli("add", "--roadmap", RM, "--session", SID, "--section", "자원",
                          "--cells", "worktree · /x · A1 · 설계 · 가 · 나")
        self.assertEqual(rc, 0)
        data = cs.load(L.mpath(self.w, RM), RM)
        self.assertEqual(data["자원"][0]["만든 때"], "가 · 나")
        self.assertEqual(self.cli("drop", "--roadmap", RM, "--session", SID, "--section", "자원",
                                  "--where", "경로=/x")[0], 0)
        self.assertEqual(cs.load(L.mpath(self.w, RM), RM)["자원"], [])
        self.assertEqual(self.cli("drop", "--roadmap", RM, "--session", SID, "--section", "자원",
                                  "--where", "경로=/x")[0], 1)

    def test_wrong_cell_count(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        rc, out = self.cli("add", "--roadmap", RM, "--session", SID, "--section", "PR", "--cells", "feature/a1 · #3")
        self.assertEqual(rc, 2)
        self.assertIn("칸 4개", out)

    def test_broken_machine_state_is_not_overwritten(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        path = L.mpath(self.w, RM)
        path.write_text("깨진 글\n", encoding="utf-8")
        rc, out = self.cli("add", "--roadmap", RM, "--session", SID, "--section", "자원",
                           "--cells", "worktree · /x · A1 · 설계 · t")
        self.assertEqual(rc, 3)
        self.assertEqual(path.read_text(encoding="utf-8"), "깨진 글\n")


class StartApproval(Repo):
    def test_same_session_same_scale_is_disclosure(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        rc, out = self.cli("approval", "--roadmap", RM, "--session", SID, "--scale", "남은 에픽 2 · agent 약 6")
        self.assertEqual(rc, 1)
        self.assertIn("승인 필요", out)
        self.assertEqual(self.cli("approve", "--roadmap", RM, "--session", SID,
                                  "--scale", "남은 에픽 2 · agent 약 6")[0], 0)
        rc, out = self.cli("approval", "--roadmap", RM, "--session", SID, "--scale", "남은 에픽 2 · agent 약 6")
        self.assertEqual(rc, 0)
        self.assertTrue(out.startswith("공시만"), out)
        rc, out = self.cli("approval", "--roadmap", RM, "--session", SID, "--scale", "남은 에픽 3 · agent 약 9")
        self.assertEqual(rc, 1)
        self.assertIn("규모가 바뀌었다", out)

    def test_other_session_must_ask(self):
        ok, why = L.scale_check([{"세션": SID, "때": "t", "규모": "s"}], OTHER, "s")
        self.assertFalse(ok)
        self.assertIn("이 세션의 승인이 없다", why)

    def test_approve_replaces_own_row(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.cli("approve", "--roadmap", RM, "--session", SID, "--scale", "a")
        self.cli("approve", "--roadmap", RM, "--session", SID, "--scale", "b")
        rows = cs.load(L.mpath(self.w, RM), RM)["시작 승인"]
        self.assertEqual([r["규모"] for r in rows], ["b"])


class ApprovalMarker(Repo):
    SCALE = "남은 에픽 2"

    def approved(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.cli("approve", "--roadmap", RM, "--session", SID, "--scale", self.SCALE)

    def ask(self, session=SID):
        return self.cli("approval", "--roadmap", RM, "--session", session, "--scale", self.SCALE)

    def test_no_marker_needs_approval(self):
        rc, out = self.ask()
        self.assertEqual(rc, 1)
        self.assertIn("표지를 쥐고 있지 않다", out)

    def test_held_stays_disclosure(self):
        self.approved()
        self.cli("claim", "--roadmap", RM, "--session", SID)
        rc, out = self.ask()
        self.assertEqual(rc, 0)
        self.assertTrue(out.startswith("공시만"), out)

    def test_release_then_claim_needs_approval(self):
        self.approved()
        self.cli("release", "--roadmap", RM, "--session", SID)
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.assertEqual(self.ask()[0], 1)

    def test_takeover_by_other_invalidates(self):
        self.approved()
        self.cli("takeover", "--roadmap", RM, "--session", OTHER)
        self.assertEqual(self.ask()[0], 1)
        self.cli("takeover", "--roadmap", RM, "--session", SID)
        self.assertEqual(self.ask()[0], 1)

    def test_other_cannot_add(self):
        self.approved()
        rc, out = self.cli("add", "--roadmap", RM, "--session", OTHER, "--section", "자원",
                           "--cells", "worktree · /x · A1 · 설계 · t")
        self.assertEqual(rc, 5)
        self.assertIn(SID, out)

    def test_drop_where_needs_equals(self):
        self.approved()
        rc, _o = self.cli("drop", "--roadmap", RM, "--session", SID, "--section", "자원", "--where", "경로")
        self.assertEqual(rc, 2)


class Roadmaps(Repo):
    def test_unreadable_roadmap_is_listed_unchecked(self):
        (self.w / "plan/rm/bad.md").write_text("---\ntype: roadmap\n---\n\n# x\n", encoding="utf-8")
        (self.w / "plan/rm/quoted.md").write_bytes(b'---\r\ntype: "roadmap"\r\n---\r\n\r\n# x\r\n')
        sh(self.w, "add", "-A")
        sh(self.w, "commit", "-qm", "bad")
        sh(self.w, "push", "-q", "origin", "trunk")
        rc, out = self.cli("roadmaps")
        self.assertEqual(rc, 0, out)
        rows = dict(l.split("\t") for l in out.strip().splitlines())
        self.assertEqual(rows.get("plan/rm/bad.md"), "검사 불가")
        self.assertEqual(rows.get("plan/rm/quoted.md"), "검사 불가")


    def test_finds_by_frontmatter_not_folder(self):
        rc, out = self.cli("roadmaps")
        self.assertEqual(rc, 0, out)
        self.assertEqual(out.strip().split("\t")[0], RM)

    def test_no_default_branch(self):
        sh(self.w, "remote", "set-head", "origin", "-d")
        rc, out = self.cli("roadmaps")
        self.assertEqual(rc, 3)
        self.assertIn("origin/HEAD", out)


if __name__ == "__main__":
    unittest.main()
