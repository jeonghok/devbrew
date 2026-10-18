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


class Resources(Repo):
    def add_wt(self, name, branch=None):
        p = self.t / name
        if branch:
            sh(self.w, "worktree", "add", "-q", "-b", branch, str(p), "trunk")
        else:
            sh(self.w, "worktree", "add", "-q", "--detach", str(p), "trunk")
        return p

    def test_cleanup_check_lists_dirty_and_outside_records(self):
        p = self.add_wt("wt1", "feature/a1")
        self.assertEqual(self.cli("cleanup-check", "--path", str(p))[0], 0)
        (p / "new.txt").write_text("x", encoding="utf-8")
        (p / ".superpowers" / "sdd" / "plan").mkdir(parents=True)
        (p / ".superpowers" / "sdd" / "plan" / "progress.md").write_text("Ruling: a", encoding="utf-8")
        rc, out = self.cli("cleanup-check", "--path", str(p))
        self.assertEqual(rc, 1)
        self.assertIn("new.txt", out)
        self.assertIn("실행 방식 작업 폴더", out)
        self.assertEqual(self.cli("cleanup-check", "--path", str(self.t / "nope"))[0], 2)

    def test_cleanup_refuses_dirty_and_keeps_branch(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        p = self.add_wt("wt2", "feature/a1")
        self.cli("add", "--roadmap", RM, "--session", SID, "--section", "자원",
                 "--cells", "worktree · %s · A1 · 구현 · t" % p)
        (p / "x.txt").write_text("x", encoding="utf-8")
        rc, out = self.cli("cleanup", "--roadmap", RM, "--session", SID, "--path", str(p))
        self.assertEqual(rc, 1)
        self.assertTrue(p.exists())
        (p / "x.txt").unlink()
        rc, out = self.cli("cleanup", "--roadmap", RM, "--session", SID, "--path", str(p))
        self.assertEqual(rc, 0, out)
        self.assertFalse(p.exists())
        self.assertIn("feature/a1", sh(self.w, "branch", "--list", "feature/a1"))
        self.assertEqual(cs.load(L.mpath(self.w, RM), RM)["자원"], [])

    def _mdir(self):
        return L.mpath(self.w, RM).parent

    def _row(self, p):
        self.cli("add", "--roadmap", RM, "--session", SID, "--section", "자원",
                 "--cells", "worktree · %s · A1 · 구현 · t" % p)

    def _rows(self):
        return cs.load(L.mpath(self.w, RM), RM)["자원"]

    def test_cleanup_refuses_lock_and_live_lock_copy(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        mc = self._mdir() / "merge-check"
        lock = mc / "lock"
        lock.mkdir(parents=True)
        (lock / "owner").write_text("%d t\n" % os.getpid(), encoding="utf-8")
        rc, out = self.cli("cleanup", "--roadmap", RM, "--session", SID, "--path", str(lock))
        self.assertNotEqual(rc, 0)
        self.assertTrue((lock / "owner").exists())
        (mc / "run-x").mkdir()
        copy = mc / "run-x" / "merged"
        sh(self.w, "worktree", "add", "-q", "--detach", str(copy), "trunk")
        self._row(copy)
        rc, out = self.cli("cleanup", "--roadmap", RM, "--session", SID, "--path", str(copy))
        self.assertEqual(rc, 3, out)
        self.assertTrue(copy.exists())
        self.assertEqual(len(self._rows()), 1)

    def test_cleanup_removes_merge_copy_and_review_pack(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        mc = self._mdir() / "merge-check"
        (mc / "run-x").mkdir(parents=True)
        copy = mc / "run-x" / "merged"
        sh(self.w, "worktree", "add", "-q", "--detach", str(copy), "trunk")
        (copy / "dirty.txt").write_text("x", encoding="utf-8")
        pack = self._mdir() / "review" / "pack1"
        pack.mkdir(parents=True)
        (pack / "a.md").write_text("x", encoding="utf-8")
        self._row(copy)
        self._row(pack)
        for p in (copy, pack):
            rc, out = self.cli("cleanup", "--roadmap", RM, "--session", SID, "--path", str(p))
            self.assertEqual(rc, 0, out)
            self.assertFalse(p.exists())
        self.assertEqual(self._rows(), [])

    def test_cleanup_refuses_symlink_and_non_worktrees(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        real = self.add_wt("real", "feature/r")
        link = self.t / "link"
        link.symlink_to(real)
        self._row(link)
        rc, out = self.cli("cleanup", "--roadmap", RM, "--session", SID, "--path", str(link))
        self.assertNotEqual(rc, 0)
        self.assertTrue(real.exists())
        self.assertEqual(len(self._rows()), 1)
        self.assertEqual(self.cli("cleanup-check", "--path", str(link))[0], 2)
        for p in (self.w / "plan", self.w, self.t / "nope"):
            self.assertEqual(self.cli("cleanup-check", "--path", str(p))[0], 2, p)
            rc, out = self.cli("cleanup", "--roadmap", RM, "--session", SID, "--path", str(p))
            self.assertEqual(rc, 2, (p, out))
        self.assertTrue((self.w / "plan").exists())

    def test_orphans_unreadable_folder(self):
        bad = self.add_wt("bad", "feature/bad")
        os.chmod(str(bad), 0)
        try:
            rc, out = self.cli("orphans", "--roadmap", RM)
        finally:
            os.chmod(str(bad), 0o755)
        self.assertEqual(rc, 0)
        self.assertIn("feature/bad", out)

    def test_cleanup_gone_review_pack_drops_row(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        pack = self._mdir() / "review" / "gone"
        self._row(pack)
        rc, out = self.cli("cleanup", "--roadmap", RM, "--session", SID, "--path", str(pack))
        self.assertEqual(rc, 0, out)
        self.assertEqual(self._rows(), [])

    def test_cleanup_refuses_own_seat(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        seat = self.add_wt("seat", "feature/seat")
        inner = self.add_wt("inner", "feature/inner")
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = L.main(["--root", str(seat), "cleanup-check", "--path", str(seat)])
        self.assertEqual(rc, 2)
        with redirect_stdout(buf):
            rc = L.main(["--root", str(seat), "cleanup", "--roadmap", RM, "--session", SID, "--path", str(seat)])
        self.assertEqual(rc, 2)
        self.assertTrue(seat.exists())
        old = os.getcwd()
        os.chdir(str(inner))
        try:
            rc, out = self.cli("cleanup", "--roadmap", RM, "--session", SID, "--path", str(inner))
        finally:
            os.chdir(old)
        self.assertEqual(rc, 2)
        self.assertTrue(inner.exists())

    def test_cleanup_failed_delete_keeps_row_and_folder(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        pack = self._mdir() / "review" / "stuck"
        (pack / "sub").mkdir(parents=True)
        (pack / "sub" / "f.md").write_text("x", encoding="utf-8")
        self._row(pack)
        os.chmod(str(pack / "sub"), 0o500)
        try:
            rc, out = self.cli("cleanup", "--roadmap", RM, "--session", SID, "--path", str(pack))
        finally:
            os.chmod(str(pack / "sub"), 0o755)
        self.assertEqual(rc, 3, out)
        self.assertTrue(pack.exists())
        self.assertEqual(len(self._rows()), 1)

    def test_young_lock_without_owner_is_live(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        mc = self._mdir() / "merge-check"
        (mc / "lock").mkdir(parents=True)
        (mc / "run-y").mkdir()
        copy = mc / "run-y" / "base"
        sh(self.w, "worktree", "add", "-q", "--detach", str(copy), "trunk")
        rc, out = self.cli("cleanup", "--roadmap", RM, "--session", SID, "--path", str(copy))
        self.assertEqual(rc, 3, out)
        self.assertTrue(copy.exists())

    def test_orphans_missing_folder(self):
        gone = self.add_wt("gone", "feature/g")
        shutil.rmtree(str(gone))
        rc, out = self.cli("orphans", "--roadmap", RM)
        self.assertEqual(rc, 0)
        self.assertIn("폴더 없음(prunable)", out)
        self.assertNotIn("깨끗", out)

    def test_orphans(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        known = self.add_wt("known")
        stray = self.add_wt("stray", "feature/stray")
        self.cli("add", "--roadmap", RM, "--session", SID, "--section", "자원",
                 "--cells", "worktree · %s · A1 · 설계 · t" % known)
        rc, out = self.cli("orphans", "--roadmap", RM)
        self.assertEqual(rc, 0)
        self.assertIn(str(stray.resolve()), out)
        self.assertNotIn(str(known.resolve()), out)
        self.assertNotIn(str(self.w.resolve()) + "\t", out)
        self.assertIn("feature/stray", out)


SPEC_DOC = "---\nroadmap: plan/rm/roadmap.md\n---\n\n# 설계\n\n## Acceptance Criteria\n\n- AC1 가\n"


class Records(unittest.TestCase):
    def test_insert_record_creates_and_appends(self):
        t = L.insert_record(SPEC_DOC, "흐름: 설계 흐름(기본)")
        self.assertTrue(t.endswith("## 지휘 기록\n\n- 흐름: 설계 흐름(기본)\n"), t)
        t2 = L.insert_record(t + "\n## 판정\n\n- Ruling: x\n", "- 건너뜀: 통합 리뷰 — 테스트 없음")
        self.assertIn("- 흐름: 설계 흐름(기본)\n- 건너뜀: 통합 리뷰 — 테스트 없음\n\n## 판정", t2)

    def test_insert_record_refuses_duplicate_heading(self):
        with self.assertRaises(L.Fail) as cm:
            L.insert_record(SPEC_DOC + "\n## 지휘 기록\n\n- a\n\n## 지휘 기록\n\n- b\n", "c")
        self.assertEqual(cm.exception.rc, 3)

    def test_insert_record_refuses_newline_and_unreadable_approval(self):
        with self.assertRaises(L.Fail) as cm:
            L.insert_record(SPEC_DOC, "a\n## 판정")
        self.assertEqual(cm.exception.rc, 2)
        with self.assertRaises(L.Fail) as cm:
            L.insert_record(SPEC_DOC, "- spec 승인 · 날짜없음 · 「예」")
        self.assertEqual(cm.exception.rc, 2)

    def test_harvest_keeps_bold_marker(self):
        self.assertEqual(L.harvest("**Ruling:** a", [])["lines"], ["- **Ruling:** a"])

    def test_insert_sections_real_shape_and_duplicate_sub(self):
        doc = (SPEC_DOC + "\n## 판정\n\n### plans/p1.md\n\n- Ruling: a\n\n### plans/p2.md\n\n- Ruling: b\n"
               "\n## 구현 대조 — plans/p1.md\n\n- 구현 대조: x\n\n## 구현 대조 — plans/p2.md\n\n- 구현 대조: y\n")
        t = L.insert_sections(doc, "plans/p3.md", ["- Ruling: c"], "z", "w")
        self.assertLess(t.index("### plans/p3.md"), t.index("## 구현 대조 — plans/p1.md"))
        self.assertEqual(t.count("## 판정"), 1)
        with self.assertRaises(L.Fail) as cm:
            L.insert_sections(doc, "plans/p2.md", ["- Ruling: c"], "z", "w")
        self.assertEqual(cm.exception.rc, 2)
        only = SPEC_DOC + "\n## 판정\n\n### plans/p2.md\n\n- Ruling: b\n"
        with self.assertRaises(L.Fail) as cm:
            L.insert_sections(only, "plans/p2.md", ["- Ruling: c"], "z", "w")
        self.assertEqual(cm.exception.rc, 2)
        self.assertIn("판정 절 안", str(cm.exception))

    def test_line_break_chars_refused_everywhere(self):
        for bad in ("a\u2028b", "a\x0bb", "a\x85b", "a\rb"):
            with self.assertRaises(L.Fail, msg=repr(bad)):
                L.insert_record(SPEC_DOC, bad)
            for args in ((bad, ["- r"], "i", "c"), ("p", [bad], "i", "c"), ("p", ["- r"], bad, "c"), ("p", ["- r"], "i", bad)):
                with self.assertRaises(L.Fail, msg=repr(args)):
                    L.insert_sections(SPEC_DOC, *args)

    def test_approval_line_round_trips_with_status_reader(self):
        import roadmap_model as M
        t = L.insert_record(SPEC_DOC, L.approval_line("2026-10-18", "① /compact 후 다음 세션 줄 (권장)"))
        self.assertEqual(M.approval_date(t), "2026-10-18")
        self.assertIn("- spec 승인 · 2026-10-18 · 「① /compact 후 다음 세션 줄 (권장)」", t)

    def test_insert_sections_new_and_continue(self):
        t = L.insert_sections(SPEC_DOC, "plans/p1.md", ["- Ruling: a"], "경고 없음 (AC 1개)", "AC 1개 중 구현됨 1")
        self.assertIn("## 판정\n\n### plans/p1.md\n\n- Ruling: a\n", t)
        self.assertIn("## 구현 대조 — plans/p1.md\n\n- 구현 대조: 경고 없음 (AC 1개)\n- 보고: AC 1개 중 구현됨 1\n", t)
        t2 = L.insert_sections(t, "plans/p2.md", ["- Ruling: b"], "경고 없음", "AC 1개 중 구현됨 1")
        self.assertEqual(t2.count("## 판정"), 1)
        self.assertLess(t2.index("### plans/p2.md"), t2.index("## 구현 대조 — plans/p1.md"))
        with self.assertRaises(L.Fail) as cm:
            L.insert_sections(t2, "plans/p2.md", [], "x", "y")
        self.assertEqual(cm.exception.rc, 2)

    def test_insert_sections_refuses_headless_rulings(self):
        doc = SPEC_DOC + "\n## 판정\n\n- Ruling: 옛 줄\n"
        with self.assertRaises(L.Fail) as cm:
            L.insert_sections(doc, "plans/p2.md", ["- Ruling: b"], "x", "y")
        self.assertEqual(cm.exception.rc, 3)

    def test_harvest(self):
        got = L.harvest("끝\n- Ruling: b — 왜 — 값\nRuling: c — 왜 — 값\n", ["- Ruling: a — 왜 — 값\n- Ruling: b — 왜 — 값\n"])
        self.assertEqual(got["lines"], ["- Ruling: a — 왜 — 값", "- Ruling: b — 왜 — 값", "- Ruling: c — 왜 — 값"])
        self.assertEqual((len(got["only_report"]), len(got["only_ledger"])), (1, 1))
        self.assertEqual(L.harvest("없음", [])["lines"], [])

    def test_write_atomic_keeps_file_on_bad_text(self):
        d = Path(tempfile.mkdtemp())
        try:
            p = d / "x.md"
            p.write_text("원래", encoding="utf-8")
            with self.assertRaises(L.Fail):
                L.write_atomic(p, "깨진 \udc80 글")
            self.assertEqual(p.read_text(encoding="utf-8"), "원래")
            os.chmod(str(p), 0o644)
            L.write_atomic(p, "새로")
            self.assertEqual(p.stat().st_mode & 0o777, 0o644)
        finally:
            shutil.rmtree(str(d))


class Pending(Repo):
    def test_flush_moves_rows_into_spec(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.cli("add", "--roadmap", RM, "--session", SID, "--section", "쌓인 기록",
                 "--cells", "A1 · 지휘 기록 · 건너뜀: 통합 리뷰 — 이유 · 둘")
        spec = self.w / "s.md"
        spec.write_text(SPEC_DOC, encoding="utf-8")
        rc, out = self.cli("pending", "--roadmap", RM)
        self.assertIn("건너뜀: 통합 리뷰 — 이유 · 둘", out)
        rc, _o = self.cli("flush", "--roadmap", RM, "--session", SID, "--epic", "A1", "--spec", str(spec))
        self.assertEqual(rc, 0)
        self.assertIn("## 지휘 기록\n\n- 건너뜀: 통합 리뷰 — 이유 · 둘\n", spec.read_text(encoding="utf-8"))
        self.assertEqual(cs.load(L.mpath(self.w, RM), RM)["쌓인 기록"], [])

    def test_flush_non_holder_leaves_spec_and_twice_is_idempotent(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.cli("add", "--roadmap", RM, "--session", SID, "--section", "쌓인 기록",
                 "--cells", "A1 · 지휘 기록 · 건너뜀: 통합 리뷰")
        spec = self.w / "s.md"
        spec.write_text(SPEC_DOC, encoding="utf-8")
        rc, _o = self.cli("flush", "--roadmap", RM, "--session", OTHER, "--epic", "A1", "--spec", str(spec))
        self.assertEqual(rc, 5)
        self.assertEqual(spec.read_text(encoding="utf-8"), SPEC_DOC)
        self.cli("flush", "--roadmap", RM, "--session", SID, "--epic", "A1", "--spec", str(spec))
        self.cli("add", "--roadmap", RM, "--session", SID, "--section", "쌓인 기록",
                 "--cells", "A1 · 지휘 기록 · 건너뜀: 통합 리뷰")
        self.cli("flush", "--roadmap", RM, "--session", SID, "--epic", "A1", "--spec", str(spec))
        self.assertEqual(spec.read_text(encoding="utf-8").count("- 건너뜀: 통합 리뷰"), 1)

    def test_flush_double_heading_rc3_and_dash_text_not_doubled(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.cli("add", "--roadmap", RM, "--session", SID, "--section", "쌓인 기록",
                 "--cells", "A1 · 지휘 기록 · - 대시 시작")
        spec = self.w / "s.md"
        two = SPEC_DOC + "\n## 지휘 기록\n\n- a\n\n## 지휘 기록\n\n- b\n"
        spec.write_text(two, encoding="utf-8")
        rc, _o = self.cli("flush", "--roadmap", RM, "--session", SID, "--epic", "A1", "--spec", str(spec))
        self.assertEqual(rc, 3)
        self.assertEqual(spec.read_text(encoding="utf-8"), two)
        spec.write_text(SPEC_DOC, encoding="utf-8")
        self.cli("flush", "--roadmap", RM, "--session", SID, "--epic", "A1", "--spec", str(spec))
        self.cli("add", "--roadmap", RM, "--session", SID, "--section", "쌓인 기록",
                 "--cells", "A1 · 지휘 기록 · - 대시 시작")
        rc, out = self.cli("flush", "--roadmap", RM, "--session", SID, "--epic", "A1", "--spec", str(spec))
        self.assertEqual(spec.read_text(encoding="utf-8").count("- 대시 시작"), 1)
        self.assertIn("건너뛰었다", out)

    def test_write_sections_refuses_empty_or_stray_rulings(self):
        spec = self.w / "s.md"
        spec.write_text(SPEC_DOC, encoding="utf-8")
        r = self.w / "r.md"
        for body, want in (("", 3), ("\n\n", 3), ("- Ruling: a\n그냥 글\n", 2), ("그냥 글\n", 2), ("- \n", 3), ("-\n", 2)):
            r.write_text(body, encoding="utf-8")
            rc, _o = self.cli("write-sections", "--spec", str(spec), "--plan", "plans/p1.md", "--rulings", str(r),
                              "--impl-line", "x", "--counts", "y")
            self.assertEqual(rc, want, body)
            self.assertEqual(spec.read_text(encoding="utf-8"), SPEC_DOC)

    def test_record_rejects_bad_date_and_writes_good_one(self):
        spec = self.w / "s.md"
        spec.write_text(SPEC_DOC, encoding="utf-8")
        for bad in ("2026-1-8", "26-10-18", "2026-13-40x", "2026-10-18 "):
            rc, _o = self.cli("record", "--spec", str(spec), "--approval", "--date", bad, "--choice", "예")
            self.assertEqual(rc, 2, bad)
        self.assertEqual(spec.read_text(encoding="utf-8"), SPEC_DOC)
        rc, _o = self.cli("record", "--spec", str(spec), "--approval", "--date", "2026-10-18", "--choice", "예")
        self.assertEqual(rc, 0)
        self.assertIn("- spec 승인 · 2026-10-18 · 「예」", spec.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
