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
import suite_lock  # noqa: E402

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
        self.assertIn("칸 9개", out)

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
    """설정 폴더가 plan/roadmaps/ 인 레포(R8 AC6 · AC29) — 로드맵 = 그 폴더 바로 아래 폴더의 .md ∧ type: roadmap."""
    IN = "plan/roadmaps/rm/roadmap.md"

    def setUp(self):
        super().setUp()
        self.put({".devbrew.md": "---\nroadmaps_dir: plan/roadmaps/\n---\n",
                  self.IN: roadmap(BLOCK),
                  "plan/roadmaps/rm/A1.md": "---\ntype: epic-bundle\n---\n",
                  "plan/roadmaps/rm/notes.md": "# 메모\n",
                  "plan/roadmaps/rm/deep/roadmap.md": roadmap(BLOCK),
                  "docs/superpowers/roadmaps/z/roadmap.md": roadmap(BLOCK),
                  "templates/roadmap-template.md": roadmap(BLOCK)})

    def put(self, files):
        for rel, text in files.items():
            (self.w / rel).parent.mkdir(parents=True, exist_ok=True)
            (self.w / rel).write_bytes(text if isinstance(text, bytes) else text.encode("utf-8"))
        sh(self.w, "add", "-A")
        sh(self.w, "commit", "-qm", "files")
        sh(self.w, "push", "-q", "origin", "trunk")

    def rows(self):
        rc, out = self.cli("roadmaps")
        self.assertEqual(rc, 0, out)
        return dict(l.split("\t") for l in out.strip().splitlines())

    def test_unreadable_roadmap_is_listed_unchecked(self):
        self.put({"plan/roadmaps/rm/bad.md": "---\ntype: roadmap\n---\n\n# x\n",
                  "plan/roadmaps/q/quoted.md": b'---\r\ntype: "roadmap"\r\n---\r\n\r\n# x\r\n',
                  "plan/roadmaps/rm/broken.md": "---\ntype: roadmap\n# 머리말이 닫히지 않았다\n"})
        rows = self.rows()
        self.assertEqual(rows.get("plan/roadmaps/rm/bad.md"), "검사 불가")
        self.assertEqual(rows.get("plan/roadmaps/q/quoted.md"), "검사 불가")
        self.assertEqual(rows.get("plan/roadmaps/rm/broken.md"), "검사 불가")

    def test_finds_in_configured_folder_only(self):
        self.assertEqual(list(self.rows()), [self.IN])

    def test_two_entries_same_list(self):
        import control_plane as cp
        (self.w / "plan/roadmaps/ln").mkdir(parents=True)
        os.symlink("../rm/roadmap.md", str(self.w / "plan/roadmaps/ln/roadmap.md"))
        exe = self.w / "plan/roadmaps/ex/roadmap.md"
        exe.parent.mkdir(parents=True)
        exe.write_text(roadmap(BLOCK), encoding="utf-8")
        exe.chmod(0o755)
        self.put({"plan/roadmaps/rm/broken.md": "---\ntype: roadmap\n# 머리말이 닫히지 않았다\n",
                  "plan/roadmaps/r2/plan.md": roadmap(BLOCK),
                  "plan/roadmaps/lfs/roadmap.md": "version https://git-lfs.github.com/spec/v1\noid sha256:00\nsize 1\n"})
        self.assertIn("100755", sh(self.w, "ls-tree", "HEAD", "--", "plan/roadmaps/ex/roadmap.md"))
        self.assertIn("120000", sh(self.w, "ls-tree", "HEAD", "--", "plan/roadmaps/ln/roadmap.md"))
        repo = cp.Repo(str(self.w), cp.Deadline(60))
        tree, folder, why = cp.listing(repo, cp.default_ref(repo)[0])
        self.assertIsNone(why)
        paths, unchecked, failed = cp.candidates(repo, tree, folder)
        self.assertEqual(sorted(unchecked), ["plan/roadmaps/lfs/roadmap.md", "plan/roadmaps/ln/roadmap.md",
                                             "plan/roadmaps/rm/broken.md"])
        self.assertEqual(failed, set())
        shas = sorted(set(e[2] for e in tree.values() if e[1] == "blob")) + ["0" * 40]
        got = cp.cat_batch(repo, shas)
        self.assertNotIn("0" * 40, got)   # 없는 blob 은 빠진다(읽는 쪽이 읽기 실패로 센다)
        for sha in shas[:-1]:
            want = subprocess.run(["git", "cat-file", "blob", sha], cwd=str(self.w), env=ENV, capture_output=True).stdout
            self.assertEqual(got.get(sha), want, sha)
        self.assertNotIn("plan/roadmaps/ex/roadmap.md", unchecked)   # 실행 비트(100755)도 일반 파일
        rows = self.rows()
        listed = sorted(rows)
        self.assertEqual(listed, ["plan/roadmaps/ex/roadmap.md", "plan/roadmaps/lfs/roadmap.md", "plan/roadmaps/ln/roadmap.md",
                                  "plan/roadmaps/r2/plan.md", "plan/roadmaps/rm/broken.md", self.IN])
        self.assertEqual(paths, listed)
        for p in ("plan/roadmaps/lfs/roadmap.md", "plan/roadmaps/ln/roadmap.md", "plan/roadmaps/rm/broken.md"):
            self.assertEqual(rows[p], "검사 불가", p)

    def test_broken_settings_stop(self):
        self.put({".devbrew.md": "---\nroadmaps_dir: plan/roadmaps/\ntypo_key: x\n---\n"})
        rc, out = self.cli("roadmaps")
        self.assertEqual(rc, 3, out)
        self.assertIn("typo_key", out)

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
        lock = suite_lock.lock_path(self._mdir())  # 담당자 스위트와 같은 공유 잠금(지휘자 수리 2)
        lock.mkdir(parents=True)
        mc.mkdir(parents=True)
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

    def test_resource_dir_creates_and_cleanup_removes(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        made = {}
        for kind in ("tmp", "relay", "report"):
            rc, out = self.cli("resource-dir", "--roadmap", RM, "--kind", kind, "--name", "A1-plan")
            self.assertEqual(rc, 0, out)
            p = Path(out.strip())
            self.assertEqual(p, self._mdir() / "files" / kind / "A1-plan")
            self.assertTrue(p.is_dir())
            self.assertEqual(L.disposable_kind(self.w, RM, p), "file")
            (p / "sub").mkdir()
            (p / "sub" / "x.md").write_text("x", encoding="utf-8")
            self._row(p)
            made[kind] = p
        loose = self._mdir() / "files" / "relay" / "relay-A1-1.md"
        loose.write_text("x", encoding="utf-8")
        self._row(loose)
        self.assertEqual(self.cli("cleanup-check", "--roadmap", RM, "--path", str(made["tmp"]))[0], 0)
        for p in list(made.values()) + [loose]:
            rc, out = self.cli("cleanup", "--roadmap", RM, "--session", SID, "--path", str(p))
            self.assertEqual(rc, 0, out)
            self.assertFalse(p.exists())
        self.assertEqual(self._rows(), [])

    def test_resource_dir_refuses_bad_name_kind_and_symlink(self):
        for name in ("", ".", "..", "a/b", "a b", "가"):
            rc, out = self.cli("resource-dir", "--roadmap", RM, "--kind", "tmp", "--name", name)
            self.assertEqual(rc, 2, (name, out))
        with self.assertRaises(SystemExit):
            self.cli("resource-dir", "--roadmap", RM, "--kind", "other", "--name", "x")
        (self._mdir() / "files").mkdir(parents=True)
        elsewhere = self.t / "elsewhere"
        elsewhere.mkdir()
        (self._mdir() / "files" / "tmp").symlink_to(elsewhere)
        rc, out = self.cli("resource-dir", "--roadmap", RM, "--kind", "tmp", "--name", "x")
        self.assertEqual(rc, 3, out)
        self.assertEqual(list(elsewhere.iterdir()), [])

    def test_resource_kind_only_direct_children(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        files = self._mdir() / "files"
        (files / "tmp" / "a" / "deep").mkdir(parents=True)
        (files / "other" / "b").mkdir(parents=True)
        self.assertIsNone(L.disposable_kind(self.w, RM, files / "tmp" / "a" / "deep"))
        self.assertIsNone(L.disposable_kind(self.w, RM, files / "other" / "b"))
        self.assertIsNone(L.disposable_kind(self.w, RM, files / "tmp"))
        rc, out = self.cli("cleanup", "--roadmap", RM, "--session", SID, "--path", str(files / "tmp" / "a" / "deep"))
        self.assertEqual(rc, 2, out)
        self.assertTrue((files / "tmp" / "a" / "deep").exists())
        target = self.t / "keep"
        target.mkdir()
        link = files / "tmp" / "link"
        link.symlink_to(target)
        rc, out = self.cli("cleanup", "--roadmap", RM, "--session", SID, "--path", str(link))
        self.assertEqual(rc, 3, out)
        self.assertTrue(target.exists())

    def test_cleanup_failed_resource_delete_keeps_row(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        rc, out = self.cli("resource-dir", "--roadmap", RM, "--kind", "report", "--name", "stuck")
        p = Path(out.strip())
        (p / "sub").mkdir()
        (p / "sub" / "f.md").write_text("x", encoding="utf-8")
        self._row(p)
        os.chmod(str(p / "sub"), 0o500)
        try:
            rc, out = self.cli("cleanup", "--roadmap", RM, "--session", SID, "--path", str(p))
        finally:
            os.chmod(str(p / "sub"), 0o755)
        self.assertEqual(rc, 3, out)
        self.assertTrue(p.exists())
        self.assertEqual(len(self._rows()), 1)

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
        suite_lock.lock_path(self._mdir()).mkdir(parents=True)
        (mc / "run-y").mkdir(parents=True)
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


class LiveAgent(Repo):
    def _add(self, cells):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.assertEqual(self.cli("add", "--roadmap", RM, "--session", SID, "--section", "살아 있는 agent",
                                  "--cells", cells)[0], 0)

    def _ask(self, epic, work):
        return self.cli("live-agent", "--roadmap", RM, "--epic", epic, "--work", work)

    def test_no_row_is_rc1(self):
        self.assertEqual(self._ask("A1", "계획")[0], 1)

    def test_matching_row_is_rc0_and_printed(self):
        self._add("plan-a1 · A1 · 계획 · /w/a1 · 2026-10-18")
        rc, out = self._ask("A1", "계획")
        self.assertEqual(rc, 0)
        self.assertIn("plan-a1 · A1 · 계획 · /w/a1", out)

    def test_other_epic_or_other_work_is_rc1(self):
        self._add("plan-a1 · A1 · 계획 · /w/a1 · 2026-10-18")
        self.assertEqual(self._ask("A2", "계획")[0], 1)
        self.assertEqual(self._ask("A1", "구현")[0], 1)

    def test_broken_machine_state_is_rc3_not_none(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        path = L.mpath(self.w, RM)
        path.write_text("깨진 글\n", encoding="utf-8")
        rc, out = self._ask("A1", "계획")
        self.assertEqual(rc, 3)
        self.assertNotIn("agent 없음", out)
        self.assertEqual(path.read_text(encoding="utf-8"), "깨진 글\n")


class Audit(unittest.TestCase):
    def test_handoff_section_and_after_review(self):
        body = ("## 요약\n\n가\n\n## 통합 리뷰 인계\n\n- 이 PR 이 고침: x\n- R3 이 고침: y\n\n## 기타\n\n"
                "- 리뷰 뒤 반영(리뷰 라운드를 거치지 않았다): 오타\n")
        self.assertEqual(L.handoff_section(body), ["- 이 PR 이 고침: x", "- R3 이 고침: y"])
        self.assertEqual(L.after_review_lines(body), ["- 리뷰 뒤 반영(리뷰 라운드를 거치지 않았다): 오타"])
        self.assertEqual(L.handoff_section("본문만"), [])

    def test_carried(self):
        recv = ("# r\n\n## 번호 대조\n\n| 번호 | 반영/기각 | 자리 |\n|---|---|---|\n| C1 | 반영 | §1 |\n\n"
                "## Acceptance Criteria\n\n- AC1 qg 범위 입력(로드맵 시작 커밋부터)을 받는다\n\n## 미룸\n\n없음\n")
        self.assertTrue(L.carried("qg 범위 입력(로드맵 시작 커밋부터) · 「문서 경로」 정의", recv))
        self.assertFalse(L.carried("전혀 다른 넘김 항목이 여기 있다 길게", recv))

    def test_version_gap(self):
        d = Path(tempfile.mkdtemp())
        try:
            (d / "p").mkdir()
            subprocess.run(["git", "init", "-q", str(d)], env=ENV, check=True)
            (d / "p" / "plugin.json").write_text('{"name": "spec-distill", "version": "7.3.0"}', encoding="utf-8")
            sh(d, "add", "-A")
            sh(d, "commit", "-qm", "x")
            inst = d / "installed.json"
            inst.write_text('{"name": "spec-distill", "version": "5.3.0"}', encoding="utf-8")
            self.assertIn("옛 판", L.version_gap(d, inst))
            inst.write_text('{"name": "spec-distill", "version": "7.3.0"}', encoding="utf-8")
            self.assertIsNone(L.version_gap(d, inst))
        finally:
            shutil.rmtree(str(d))


class PrHandoffs(Repo):
    def test_no_gh_degrades(self):
        old = os.environ.get("PATH", "")
        os.environ["PATH"] = str(self.t)  # gh 없는 PATH — git 은 절대경로로 부른다
        try:
            rc, out = self.cli("pr-handoffs", "--roadmap", RM, "--epic", "A1")
        finally:
            os.environ["PATH"] = old
        self.assertEqual(rc, 4)
        self.assertIn("설계문서 `## 미룸` 표와 `## 지휘 기록` 을 쓴다", out)

    def test_gh_stub(self):
        stub = self.t / "bin"
        stub.mkdir()
        (stub / "pr.json").write_text(json.dumps([{"number": 5, "state": "OPEN",
                                                   "body": "## 통합 리뷰 인계\n\n- R2 가 고침: z\n"}]), encoding="utf-8")
        (stub / "gh").write_text("#!/bin/sh\ncat '%s'\n" % (stub / "pr.json"), encoding="utf-8")
        (stub / "gh").chmod(0o755)
        old = os.environ.get("PATH", "")
        os.environ["PATH"] = str(stub) + os.pathsep + old
        try:
            rc, out = self.cli("pr-handoffs", "--roadmap", RM, "--epic", "A1")
        finally:
            os.environ["PATH"] = old
        self.assertEqual(rc, 0, out)
        self.assertIn("#5", out)
        self.assertIn("- R2 가 고침: z", out)

    def _audit_with_gh(self, prs):
        stub = self.t / "bin"
        stub.mkdir()
        (stub / "pr.json").write_text(json.dumps(prs), encoding="utf-8")
        (stub / "gh").write_text("#!/bin/sh\ncat '%s'\n" % (stub / "pr.json"), encoding="utf-8")
        (stub / "gh").chmod(0o755)
        old = os.environ.get("PATH", "")
        os.environ["PATH"] = str(stub) + os.pathsep + old
        try:
            return self.cli("audit", "--roadmap", RM, "--epic", "A1")
        finally:
            os.environ["PATH"] = old

    def test_audit_with_unreadable_status_is_not_all_clear(self):
        rc, out = self._audit_with_gh([])  # 이 fixture 는 brief 가 없어 상태 계산에 셀 수 없는 것이 있다
        self.assertEqual(rc, 0, out)
        self.assertIn("셀 수 없음", out)
        self.assertNotIn("감사 후보 없음", out)

    def test_audit_lists_after_review_lines(self):
        rc, out = self._audit_with_gh([{"number": 7, "state": "OPEN", "body": "- 리뷰 뒤 반영(리뷰 라운드를 거치지 않았다): 오타\n"}])
        self.assertEqual(rc, 0, out)
        self.assertIn("리뷰 뒤 반영 1개", out)


TABLE = "## 번호 대조\n\n| 번호 | 반영/기각 | 자리 |\n|---|---|---|\n%s\n"


class AuditReadFailures(unittest.TestCase):
    """읽지 못한 것은 「없음」이 아니라 「셀 수 없음」이다."""
    def run_audit(self, docs, report=None, prs=None):
        from unittest import mock
        block = {"id": "A1", "stage": "설계 중", "tip": "abc", "specs": list(docs), "branches": ["b1"]}
        rep = report or {"blocks": [block], "handoffs": []}
        buf = io.StringIO()
        with mock.patch.object(L, "_status", return_value=rep), \
                mock.patch.object(L, "_doc", side_effect=lambda r, b, p: docs.get(p)), \
                mock.patch.object(L, "_prs", return_value=prs if prs is not None else []), \
                redirect_stdout(buf):
            rc = L.main(["--root", ".", "audit", "--roadmap", "r.md", "--epic", "A1"])
        return rc, buf.getvalue()

    def test_unreadable_spec_is_not_none(self):
        rc, out = self.run_audit({"s.md": None})
        self.assertEqual(rc, 0)
        self.assertIn("셀 수 없음", out)
        self.assertNotIn("감사 후보 없음", out)

    def test_nothing_found_when_all_read(self):
        rc, out = self.run_audit({"s.md": "# 설계\n"})
        self.assertIn("감사 후보 없음", out)

    def test_unknown_stage_is_unreadable(self):
        rep = {"blocks": [{"id": "A1", "stage": "알 수 없음", "reason": "기본 브랜치를 못 읽었다", "specs": []}],
               "handoffs": []}
        rc, out = self.run_audit({}, report=rep)
        self.assertIn("셀 수 없음", out)
        self.assertNotIn("감사 후보 없음", out)

    def test_rejected_count_is_exact(self):
        two = TABLE % "| C1 | 기각 | 이유 가 |\n| C2 | 기각 | 이유 나 |"
        _rc, out = self.run_audit({"s.md": two})
        self.assertIn("기각한 번호(s.md) 2개", out)
        self.assertNotIn("받지 않기로 한", out)
        multi = TABLE % "| C1 · C2 | 기각 | 이유 |"
        _rc, out = self.run_audit({"s.md": multi})
        self.assertIn("기각한 번호(s.md) 2개", out)
        zero = TABLE % "| C1 | 반영 | §1 |"
        _rc, out = self.run_audit({"s.md": zero})
        self.assertNotIn("기각한 번호", out)
        self.assertIn("감사 후보 없음", out)

    def test_unreadable_handoff_state_and_unreadable_receiver_doc_are_reported(self):
        hs = [{"giver": "A2", "spec": "g.md", "item": "넘긴 항목입니다 길게 길게", "receiver": "A1",
               "state": "셀 수 없음", "basis": "A1 지휘 기록 읽기 불가"}]
        block = {"id": "A1", "stage": "설계 중", "tip": "abc", "specs": ["s.md"], "branches": []}
        _rc, out = self.run_audit({"s.md": "# 설계\n"}, report={"blocks": [block], "handoffs": hs})
        self.assertIn("줄어든 넘김 의심(셀 수 없음)", out)
        hs[0]["state"] = "열림"
        _rc, out = self.run_audit({"s.md": None}, report={"blocks": [block], "handoffs": hs})
        self.assertIn("받는 쪽 설계문서를 읽지 못했다", out)

    def test_unreadable_handoff_shown_even_without_receiver_specs(self):
        hs = [{"giver": "A2", "spec": "g.md", "item": "항목", "receiver": "A1", "state": "셀 수 없음", "basis": "읽기 불가"}]
        block = {"id": "A1", "stage": "준비", "specs": [], "branches": []}
        _rc, out = self.run_audit({}, report={"blocks": [block], "handoffs": hs})
        self.assertIn("줄어든 넘김 의심(셀 수 없음)", out)
        self.assertNotIn("감사 후보 없음", out)

    def test_unknown_reasons_block_the_all_clear(self):
        block = {"id": "A1", "stage": "설계 중", "tip": "abc", "specs": ["s.md"], "branches": []}
        _rc, out = self.run_audit({"s.md": "# 설계\n"}, report={"blocks": [block], "handoffs": [],
                                                                "unknown_reasons": ["A2 미룸 표 셀 수 없음"]})
        self.assertIn("A2 미룸 표 셀 수 없음", out)
        self.assertNotIn("감사 후보 없음", out)

    def test_shrunk_handoff_is_listed(self):
        hs = [{"giver": "A2", "spec": "g.md", "item": "전혀 다른 넘김 항목이 여기 있다 길게", "receiver": "A1",
               "state": "열림", "basis": ""}]
        block = {"id": "A1", "stage": "설계 중", "tip": "abc", "specs": ["s.md"], "branches": []}
        _rc, out = self.run_audit({"s.md": "# 설계\n"}, report={"blocks": [block], "handoffs": hs})
        self.assertIn("줄어든 넘김 의심 1개", out)

    def test_status_failure_is_rc3_not_missing_epic(self):
        from unittest import mock
        buf = io.StringIO()
        rep = {"blocks": [], "exit": 3, "unknown_reasons": ["기본 브랜치를 못 읽었다"], "format_errors": []}
        with mock.patch.object(L.subprocess, "run") as run, redirect_stdout(buf):
            run.return_value = mock.Mock(stdout=json.dumps(rep), stderr="", returncode=3)
            rc = L.main(["--root", ".", "audit", "--roadmap", "r.md", "--epic", "A1"])
        self.assertEqual(rc, 3)
        self.assertIn("기본 브랜치를 못 읽었다", buf.getvalue())
        self.assertNotIn("로드맵에 없다", buf.getvalue())


class VersionReport(unittest.TestCase):
    def check(self, inst, repo):
        d = Path(tempfile.mkdtemp())
        try:
            subprocess.run(["git", "init", "-q", str(d)], env=ENV, check=True)
            if repo is not None:
                (d / "plugin.json").write_text(repo, encoding="utf-8")
            sh(d, "add", "-A")
            (d / "installed.json").write_text(inst, encoding="utf-8")
            return L.version_report(d, d / "installed.json")
        finally:
            shutil.rmtree(str(d))

    def test_forms(self):
        def mk(v):
            return json.dumps({"name": "p", "version": v})
        self.assertEqual(self.check(mk("7.3.1-rc1"), mk("7.3.1"))[0], 0)
        self.assertEqual(self.check(mk("v7.3.0"), mk("7.3.0"))[0], 0)
        self.assertEqual(self.check(mk("7.3"), mk("7.3.0"))[0], 0)
        rc, msg = self.check(mk("7.3"), mk("7.3.1"))
        self.assertEqual(rc, 1)
        self.assertIn("옛 판", msg)
        rc, msg = self.check(mk("8.0.0"), mk("7.3.1"))
        self.assertEqual(rc, 0)
        self.assertIn("새 판", msg)

    def test_uncomparable_is_never_ok(self):
        ok = json.dumps({"name": "p", "version": "1.0.0"})
        for inst, repo in [(json.dumps({"version": "1.0.0"}), ok), ("[]", ok),
                           (json.dumps({"name": "p", "version": "dev"}), ok),
                           (ok, json.dumps({"name": "p", "version": "x"})), (ok, "{깨짐")]:
            rc, msg = self.check(inst, repo)
            self.assertEqual(rc, 1, (inst, repo, msg))
            self.assertIn("판을 비교하지 못했다", msg)

    def test_no_tracked_source_is_ok_line(self):
        rc, msg = self.check(json.dumps({"name": "p", "version": "1.0.0"}), None)
        self.assertEqual(rc, 0)
        self.assertIn("플러그인 소스가 없다", msg)


OID1, OID2, OID3, MOID = "1" * 40, "2" * 40, "3" * 40, "abcdef0123456789abcdef0123456789abcdef01"


def gh_pr(number, state, oid, cross, merge=None, head="feature/a1", base="trunk"):
    return {"number": number, "state": state, "headRefName": head, "headRefOid": oid, "isCrossRepository": cross,
            "baseRefName": base, "mergeCommit": {"oid": merge} if merge else None}


class PrRefresh(Repo):
    """ledger pr-refresh — head 이름의 PR 을 모두 받아 그 브랜치의 PR 캐시 줄을 통째로 바꾼다(R8 계획 2 Task 2 · AC17 · §4)."""
    THREE = [gh_pr(7, "MERGED", OID1, False, MOID), gh_pr(8, "MERGED", OID2, True, MOID.replace("a", "b"), base="dev"),
             gh_pr(9, "OPEN", OID3, False)]

    def setUp(self):
        super().setUp()
        self.calls = []
        self.answers = {}
        self.stop = None

    def fake_pr_list(self, cwd, branch, limit=100):
        self.calls.append((cwd, branch, limit))
        if self.stop:
            raise L.gh_repo.GhStop(self.stop)
        items = list(self.answers.get(branch, []))[:limit]
        return items, len(items) >= limit

    def refresh(self, *extra, session=SID):
        from unittest import mock
        with mock.patch.object(L.gh_repo, "pr_list", self.fake_pr_list):
            return self.cli("pr-refresh", "--roadmap", RM, "--session", session, *extra)

    def rows(self):
        return cs.load(L.mpath(self.w, RM), RM)["PR"]

    def test_all_prs_with_same_head_name_become_rows(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.answers["feature/a1"] = self.THREE
        rc, out = self.refresh("--epic", "A1")
        self.assertEqual(rc, 0, out)
        self.assertEqual(self.calls, [(str(self.w), "feature/a1", L.PR_REFRESH_LIMIT)])
        self.assertEqual(L.PR_REFRESH_LIMIT, 100)
        rows = self.rows()
        # 같은 head 이름의 내 레포 PR · 남의 fork PR(다른 base) 이 둘 다 줄이 되고, 판정이 거를 칸을 그대로 적는다
        self.assertEqual([(r["번호"], r["상태"], r["headRefOid"], r["교차 레포"], r["baseRefName"], r["mergeCommit"])
                          for r in rows], [
            ("#7", "머지됨", OID1, "아니오", "trunk", MOID), ("#8", "머지됨", OID2, "예", "dev", MOID.replace("a", "b")),
            ("#9", "열림", OID3, "아니오", "trunk", "-")])
        for r in rows:
            self.assertEqual((r["브랜치"], r["쓴 세션"]), ("feature/a1", SID))
            self.assertRegex(r["확인한 때"], r"^\d{4}-\d\d-\d\d \d\d:\d\d$")
        last = out.strip().splitlines()[-1]
        self.assertRegex(last, r"^PR 캐시: 브랜치 1개 · PR 3개를 \d{4}-\d\d-\d\d \d\d:\d\d 에 채웠다$")

    def test_without_epic_takes_every_unfinished_block(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.answers["feature/a2"] = [gh_pr(4, "CLOSED", OID1, False, head="feature/a2")]
        rc, out = self.refresh()
        self.assertEqual(rc, 0, out)
        self.assertEqual(sorted(c[1] for c in self.calls), ["feature/a1", "feature/a2"])
        self.assertEqual([(r["브랜치"], r["번호"], r["상태"]) for r in self.rows()], [("feature/a2", "#4", "닫힘")])
        self.assertIn("PR 캐시: 브랜치 2개 · PR 1개를", out)

    def test_branch_rows_are_replaced_whole_and_other_branches_kept(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.answers["feature/a1"] = self.THREE
        self.refresh("--epic", "A1")
        L.update(self.w, RM, SID, lambda d: d["PR"].append(dict(d["PR"][0], 브랜치="feature/other", 번호="#1")))
        self.answers["feature/a1"] = [gh_pr(9, "MERGED", OID3, False, MOID)]
        rc, out = self.refresh("--epic", "A1")
        self.assertEqual(rc, 0, out)
        self.assertEqual([(r["브랜치"], r["번호"], r["상태"]) for r in self.rows()],
                         [("feature/other", "#1", "머지됨"), ("feature/a1", "#9", "머지됨")])

    def test_session_without_marker_cannot_write(self):
        self.cli("claim", "--roadmap", RM, "--session", OTHER)
        self.answers["feature/a1"] = self.THREE
        rc, out = self.refresh("--epic", "A1")
        self.assertEqual(rc, 5, out)
        self.assertIn("읽기 전용", out)
        self.assertEqual(self.calls, [])
        self.assertEqual(self.rows(), [])

    def test_reset_clears_old_four_column_rows_and_refills(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        path = L.mpath(self.w, RM)
        text = path.read_text(encoding="utf-8")
        old = "- feature/a1 · #3 · 열림 · 2026-10-17 10:00"
        path.write_text(text.replace("## PR\n\n", "## PR\n\n" + old + "\n", 1), encoding="utf-8")
        self.answers["feature/a1"] = self.THREE
        rc, out = self.refresh("--epic", "A1")
        self.assertEqual(rc, 3, out)
        self.assertIn("옛 판이 쓴 PR 캐시 줄이다(칸 4개)", out)
        self.assertIn("--reset", out)
        self.assertEqual(self.calls, [])
        self.assertIn(old, path.read_text(encoding="utf-8"))
        rc, out = self.refresh("--reset")
        self.assertEqual(rc, 0, out)
        self.assertNotIn(old, path.read_text(encoding="utf-8"))
        self.assertEqual([r["번호"] for r in self.rows()], ["#7", "#8", "#9"])

    def test_reset_with_epic_is_refused(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.answers["feature/a1"] = self.THREE
        rc, out = self.refresh("--epic", "A1", "--reset")
        self.assertEqual(rc, 2, out)
        self.assertEqual(out.strip(), "[spec-distill] `--reset` 은 PR 절 전체를 다시 채운다 — `--epic` 을 빼고 다시 돌려라")
        self.assertEqual(self.calls, [])
        self.assertEqual(self.rows(), [])

    def write_old_row(self):
        path = L.mpath(self.w, RM)
        text = path.read_text(encoding="utf-8")
        path.write_text(text.replace("## PR\n\n", "## PR\n\n- feature/a1 · #3 · 열림 · 2026-10-17 10:00\n", 1),
                        encoding="utf-8")

    def test_upgrade_path_claim_then_reset_then_claim(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.cli("release", "--roadmap", RM, "--session", SID)
        self.write_old_row()
        rc, out = self.cli("claim", "--roadmap", RM, "--session", SID)
        self.assertEqual(rc, 3, out)
        self.assertRegex(out.strip(), r"^\[spec-distill\] \d+줄: 옛 판이 쓴 PR 캐시 줄이다\(칸 4개\) — ledger pr-refresh "
                                      r"--roadmap <로드맵> --session <세션> --reset 으로 다시 채운다$")
        self.assertEqual(cs.holder(L.mpath(self.w, RM).parent), SID)
        rc, out = self.cli("takeover", "--roadmap", RM, "--session", OTHER)
        self.assertEqual(rc, 3, out)
        self.assertIn("--reset 으로 다시 채운다", out)
        self.cli("takeover", "--roadmap", RM, "--session", SID)
        self.answers["feature/a1"] = self.THREE
        rc, out = self.refresh("--reset")
        self.assertEqual(rc, 0, out)
        rc, out = self.cli("claim", "--roadmap", RM, "--session", SID)
        self.assertEqual((rc, out.strip()), (0, "held"))
        self.assertEqual([r["번호"] for r in self.rows()], ["#7", "#8", "#9"])

    def test_pr_of_another_head_name_fails_closed(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.answers["feature/a1"] = [gh_pr(7, "MERGED", OID1, False, MOID), gh_pr(5, "MERGED", OID2, False, MOID,
                                                                                 head="feature/a1-old")]
        rc, out = self.refresh("--epic", "A1")
        self.assertEqual(rc, 4, out)
        self.assertIn("gh 가 다른 브랜치의 PR 을 냈다(브랜치 feature/a1 · PR #5 의 head feature/a1-old)", out)
        self.assertEqual(self.rows(), [])

    def test_finished_blocks_are_not_refreshed(self):
        from unittest import mock
        self.cli("claim", "--roadmap", RM, "--session", SID)
        rep = {"blocks": [{"id": "A1", "kind": "bundle", "stage": "머지됨", "branches": ["feature/a1"]},
                          {"id": "A2", "kind": "bundle", "stage": "끝남", "branches": ["feature/a2"]},
                          {"id": "A3", "kind": "bundle", "stage": "구현 끝", "branches": ["feature/a3"]},
                          {"id": "A4", "kind": "bundle", "stage": "일부 머지(1/2)",
                           "branches": ["feature/a4", "feature/a4b"]}]}
        with mock.patch.object(L, "_status", return_value=rep):
            rc, out = self.refresh()
        self.assertEqual(rc, 0, out)
        self.assertEqual([c[1] for c in self.calls], ["feature/a3", "feature/a4", "feature/a4b"])

    def test_branch_added_only_by_unmerged_roadmap_copy(self):
        sh(self.w, "checkout", "-q", "-b", "feature/a1-2")
        (self.w / RM).write_text(roadmap(BLOCK.replace("- 브랜치: feature/a1\n", "- 브랜치: feature/a1 · feature/a1-2\n")),
                                 encoding="utf-8")
        sh(self.w, "commit", "-qam", "계획 2 브랜치")
        sh(self.w, "push", "-q", "origin", "feature/a1-2")
        sh(self.w, "checkout", "-q", "trunk")
        sh(self.w, "fetch", "-q", "origin")
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.answers["feature/a1-2"] = [gh_pr(11, "OPEN", OID1, False, head="feature/a1-2")]
        rc, out = self.refresh("--epic", "A1")
        self.assertEqual(rc, 0, out)
        self.assertEqual([c[1] for c in self.calls], ["feature/a1", "feature/a1-2"])
        self.assertEqual([(r["브랜치"], r["번호"]) for r in self.rows()], [("feature/a1-2", "#11")])

    def test_limit_reached_is_stated(self):
        from unittest import mock
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.answers["feature/a1"] = self.THREE
        with mock.patch.object(L, "PR_REFRESH_LIMIT", 3):
            rc, out = self.refresh("--epic", "A1")
        self.assertEqual(rc, 0, out)
        self.assertIn("feature/a1 의 PR 목록이 3개 한도에 닿았다 — 더 있을 수 있다", out)
        rc, out = self.refresh("--epic", "A1")
        self.assertNotIn("한도에 닿았다", out)

    def test_gh_stop_stops_without_writing(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.stop = "gh 인증이 안 됐다 — gh auth login --hostname github.com 를 돈다"
        rc, out = self.refresh("--epic", "A1")
        self.assertEqual(rc, 4, out)
        self.assertIn(self.stop, out)
        self.assertEqual(self.rows(), [])

    def test_unknown_state_or_cross_value_stops(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        for bad in (dict(gh_pr(7, "DRAFT", OID1, False)), dict(gh_pr(7, "OPEN", OID1, None))):
            self.answers["feature/a1"] = [bad]
            rc, out = self.refresh("--epic", "A1")
            self.assertEqual(rc, 4, out)
            self.assertIn("gh pr list 출력 모양이 다르다", out)
        self.assertEqual(self.rows(), [])

    def test_env_notices_are_shown(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        old = os.environ.get("GH_REPO")
        os.environ["GH_REPO"] = "up/r"
        try:
            rc, out = self.refresh("--epic", "A1")
        finally:
            if old is None:
                os.environ.pop("GH_REPO", None)
            else:
                os.environ["GH_REPO"] = old
        self.assertEqual(rc, 0, out)
        self.assertIn("GH_REPO 이 설정돼 있다(up/r) — devbrew 는 -R 로 origin 을 명시해 쓴다", out)


class NoPrBranch(Repo):
    def test_no_pr_line(self):
        stub = self.t / "bin"
        stub.mkdir()
        (stub / "gh").write_text("#!/bin/sh\necho '[]'\n", encoding="utf-8")
        (stub / "gh").chmod(0o755)
        old = os.environ.get("PATH", "")
        os.environ["PATH"] = str(stub) + os.pathsep + old
        try:
            rc, out = self.cli("pr-handoffs", "--roadmap", RM, "--epic", "A1")
        finally:
            os.environ["PATH"] = old
        self.assertEqual(rc, 0, out)
        self.assertIn("feature/a1 PR 없음", out)


class AuditEndToEnd(Repo):
    """실제 roadmap_status — 주는 쪽의 깨진 미룸 표는 「셀 수 없음」으로 올라와야 한다."""
    def test_broken_giver_table_reaches_audit(self):
        block = BLOCK.replace("- 묶음: A2.md\n", "- 묶음: A2.md\n- 산출물: docs/a2.md\n")
        (self.w / RM).write_text(roadmap(block), encoding="utf-8")
        sh(self.w, "commit", "-qam", "산출물")
        sh(self.w, "push", "-q", "origin", "trunk")
        sh(self.w, "checkout", "-q", "-b", "feature/a2")
        (self.w / "docs").mkdir()
        (self.w / "docs/a2.md").write_text("# 설계\n\n## 미룸\n\n| 항목 | 받는 곳 |\n|---|---|\n| AC2 | A1 |\n",
                                           encoding="utf-8")
        sh(self.w, "add", "-A")
        sh(self.w, "commit", "-qm", "a2 spec")
        sh(self.w, "push", "-q", "origin", "feature/a2")
        sh(self.w, "checkout", "-q", "trunk")
        sh(self.w, "fetch", "-q", "origin")
        from unittest import mock
        with mock.patch.object(L, "_prs", return_value=[]):
            rc, out = self.cli("audit", "--roadmap", RM, "--epic", "A1")
        self.assertEqual(rc, 0, out)
        self.assertIn("상태 계산 — 셀 수 없음", out)
        self.assertIn("A2 미룸 표", out)
        self.assertNotIn("감사 후보 없음", out)


class DocRead(Repo):
    def test_doc_missing_is_none_and_empty_is_empty(self):
        (self.w / "empty.md").write_text("", encoding="utf-8")
        sh(self.w, "add", "-A")
        sh(self.w, "commit", "-qm", "empty")
        b = {"tip": "HEAD"}
        self.assertEqual(L._doc(self.w, b, "empty.md"), "")
        self.assertIsNone(L._doc(self.w, b, "nope.md"))


class PrHandoffEdges(Repo):
    def stub(self, text):
        stub = self.t / "bin"
        stub.mkdir()
        (stub / "pr.json").write_text(text, encoding="utf-8")
        (stub / "gh").write_text("#!/bin/sh\ncat '%s'\n" % (stub / "pr.json"), encoding="utf-8")
        (stub / "gh").chmod(0o755)
        old = os.environ.get("PATH", "")
        os.environ["PATH"] = str(stub) + os.pathsep + old
        return old

    def test_limit_reached_is_stated(self):
        old = self.stub(json.dumps([{"number": n, "state": "OPEN", "body": ""} for n in range(L.PR_LIMIT)]))
        try:
            rc, out = self.cli("pr-handoffs", "--roadmap", RM, "--epic", "A1")
        finally:
            os.environ["PATH"] = old
        self.assertEqual(rc, 0, out)
        self.assertIn("한도에 닿았다", out)

    def test_block_without_branch(self):
        block = BLOCK.replace("- 브랜치: feature/a1\n", "- 브랜치: 없음\n")
        (self.w / RM).write_text(roadmap(block), encoding="utf-8")
        sh(self.w, "commit", "-qam", "no branch")
        sh(self.w, "push", "-q", "origin", "trunk")
        old = self.stub("[]")
        try:
            rc, out = self.cli("pr-handoffs", "--roadmap", RM, "--epic", "A1")
        finally:
            os.environ["PATH"] = old
        self.assertEqual(rc, 0, out)
        self.assertIn("브랜치 없음", out)




class ReviewPack(Repo):
    def branch(self, name, path, text):
        sh(self.w, "checkout", "-q", "-b", name, "trunk")
        (self.w / path).write_text(text, encoding="utf-8")
        sh(self.w, "add", "-A")
        sh(self.w, "commit", "-qm", name)
        sh(self.w, "checkout", "-q", "trunk")

    def test_pack(self):
        self.branch("feature/a1", "x.txt", "a1\n")
        self.branch("feature/a2", "x.txt", "a2\n")
        out_dir = self.t / "pack"
        old = os.environ.get("PATH", "")
        os.environ["PATH"] = str(self.t)  # gh 없음 — handoffs.md 가 사유를 적는다
        try:
            rc, out = self.cli("review-pack", "--roadmap", RM, "--epic", "A1", "--branch", "feature/a1",
                               "--merged", "/somewhere/merged", "--out", str(out_dir))
        finally:
            os.environ["PATH"] = old
        self.assertEqual(rc, 0, out)
        self.assertIn("review 폴더 밖", out)
        self.assertIn("+a1", (out_dir / "pr.diff").read_text(encoding="utf-8"))
        self.assertIn("+a2", (out_dir / "open-A2-feature_a2.diff").read_text(encoding="utf-8"))
        self.assertIn("A2(feature/a2): x.txt", (out_dir / "conflicts.txt").read_text(encoding="utf-8"))
        self.assertIn("gh 가 없다", (out_dir / "handoffs.md").read_text(encoding="utf-8"))
        self.assertIn("/somewhere/merged", (out_dir / "README.txt").read_text(encoding="utf-8"))

    def test_stale_local_uses_origin_tip(self):
        # 스위트 대조(merge_check)와 같은 끝 고르기(branch_tip.py) — 낡은 로컬이면 origin 끝 · 갈라지면 3
        self.branch("feature/a1", "x.txt", "old\n")
        stale = sh(self.w, "rev-parse", "feature/a1").strip()
        sh(self.w, "checkout", "-q", "feature/a1")
        (self.w / "x.txt").write_text("new\n", encoding="utf-8")
        sh(self.w, "commit", "-qam", "new")
        sh(self.w, "push", "-q", "origin", "feature/a1")
        sh(self.w, "checkout", "-q", "trunk")
        new = sh(self.w, "rev-parse", "feature/a1").strip()
        sh(self.w, "update-ref", "refs/heads/feature/a1", stale)
        out_dir = self.t / "pack-stale"
        rc, out = self.cli("review-pack", "--roadmap", RM, "--epic", "A1", "--branch", "feature/a1", "--out", str(out_dir))
        self.assertEqual(rc, 0, out)
        self.assertIn("로컬 브랜치 feature/a1 가 origin 보다 뒤라 origin/feature/a1(%s) 를 썼다" % new[:8], out)
        self.assertIn("(로컬 끝 %s · 원격 끝 %s)" % (stale[:8], new[:8]), out)   # 두 끝이 다르면 둘 다 보인다(§9)
        self.assertIn("+new", (out_dir / "pr.diff").read_text(encoding="utf-8"))
        rc, out = self.cli("review-pack", "--roadmap", RM, "--epic", "A1", "--branch", "origin/feature/a1",
                           "--out", str(self.t / "pack-origin"))
        self.assertEqual(rc, 0, out)
        self.assertFalse((self.t / "pack-origin" / "open-A1-feature_a1.diff").exists(), "자기 브랜치를 다른 에픽으로 미리 보지 않는다")
        sh(self.w, "checkout", "-q", "feature/a1")
        (self.w / "y.txt").write_text("side\n", encoding="utf-8")
        sh(self.w, "add", "-A")
        sh(self.w, "commit", "-qm", "side")
        sh(self.w, "checkout", "-q", "trunk")
        rc, out = self.cli("review-pack", "--roadmap", RM, "--epic", "A1", "--branch", "feature/a1",
                           "--out", str(self.t / "pack-div"))
        self.assertEqual(rc, 3, out)
        self.assertIn("가 갈라졌다", out)

    def test_merged_branch_is_not_open(self):
        self.branch("feature/a2", "y.txt", "y\n")
        sh(self.w, "merge", "-q", "--no-ff", "feature/a2", "-m", "merge a2")
        sh(self.w, "push", "-q", "origin", "trunk")
        sh(self.w, "fetch", "-q", "origin")
        self.branch("feature/a1", "x.txt", "a1\n")
        out_dir = self.t / "pack2"
        rc, out = self.cli("review-pack", "--roadmap", RM, "--epic", "A1", "--branch", "feature/a1", "--out", str(out_dir))
        self.assertEqual(rc, 0, out)
        self.assertFalse((out_dir / "open-A2-feature_a2.diff").exists())
        self.assertEqual((out_dir / "conflicts.txt").read_text(encoding="utf-8").strip(), "충돌 없음")

    def test_default_folder_has_no_outside_note(self):
        self.branch("feature/a1", "x.txt", "a1\n")
        rc, out = self.cli("review-pack", "--roadmap", RM, "--epic", "A1", "--branch", "feature/a1")
        self.assertEqual(rc, 0, out)
        first = out.splitlines()[0]
        self.assertEqual(Path(first).parent.name, L.REVIEW_PACK_DIR)
        self.assertNotIn("review 폴더 밖", out)
        shutil.rmtree(first, ignore_errors=True)

    def test_diff_failure_is_written_not_empty(self):
        self.branch("feature/a1", "x.txt", "a1\n")
        out_dir = self.t / "pack3"
        real = L.git

        def broken(cwd, *args):
            if "diff" in args:
                return 128, "", "boom"
            return real(cwd, *args)
        L.git = broken
        try:
            rc, out = self.cli("review-pack", "--roadmap", RM, "--epic", "A1", "--branch", "feature/a1",
                               "--out", str(out_dir))
        finally:
            L.git = real
        self.assertEqual(rc, 0, out)
        self.assertIn("diff 를 만들지 못했다 — boom", (out_dir / "pr.diff").read_text(encoding="utf-8"))
        self.assertIn("경고", out)

    def test_existing_out_is_refused(self):
        self.branch("feature/a1", "x.txt", "a1\n")
        (self.t / "pack4").mkdir()
        rc, out = self.cli("review-pack", "--roadmap", RM, "--epic", "A1", "--branch", "feature/a1",
                           "--out", str(self.t / "pack4"))
        self.assertEqual(rc, 2, out)

    def test_pr_limit_and_skipped_branch(self):
        self.branch("feature/a1", "x.txt", "a1\n")  # feature/a2 는 만들지 않는다
        fake = self.t / "bin"
        fake.mkdir()
        gh = fake / "gh"
        items = ",".join('{"number":%d,"state":"MERGED","body":""}' % i for i in range(20))
        gh.write_text("#!/bin/sh\necho '[%s]'\n" % items, encoding="utf-8")
        gh.chmod(0o755)
        out_dir = self.t / "pack5"
        old = os.environ.get("PATH", "")
        os.environ["PATH"] = str(fake) + os.pathsep + old
        try:
            rc, out = self.cli("review-pack", "--roadmap", RM, "--epic", "A1", "--branch", "feature/a1",
                               "--out", str(out_dir))
        finally:
            os.environ["PATH"] = old
        self.assertEqual(rc, 0, out)
        self.assertIn("한도에 닿았다", (out_dir / "handoffs.md").read_text(encoding="utf-8"))
        self.assertIn("경고: feature/a1 PR 목록이 20개 한도에 닿았다", out)
        c = (out_dir / "conflicts.txt").read_text(encoding="utf-8")
        self.assertIn("A2(feature/a2): 브랜치를 찾지 못했다", c)
        self.assertNotEqual(c.splitlines()[0], "충돌 없음")
        self.assertIn("A2(feature/a2): 브랜치를 찾지 못했다", (out_dir / "README.txt").read_text(encoding="utf-8"))

    def test_gh_missing_reason_is_warned_and_bad_epic(self):
        self.branch("feature/a1", "x.txt", "a1\n")
        old = os.environ.get("PATH", "")
        os.environ["PATH"] = str(self.t)
        try:
            rc, out = self.cli("review-pack", "--roadmap", RM, "--epic", "A1", "--branch", "feature/a1",
                               "--out", str(self.t / "pack6"))
            self.assertIn("경고: PR 인계를 읽지 못했다", out)
            self.assertEqual(self.cli("review-pack", "--roadmap", RM, "--epic", "../x", "--branch", "feature/a1")[0], 2)
        finally:
            os.environ["PATH"] = old

    def copy_branch(self, name, block_text, path, text):
        """그 브랜치의 로드맵 사본이 블록을 block_text 로 바꾼다(계획 2 · 3 의 브랜치가 자기 사본에서 블록에 자신을 더하듯)."""
        sh(self.w, "checkout", "-q", "-b", name, "trunk")
        (self.w / RM).write_text(roadmap(block_text), encoding="utf-8")
        (self.w / path).write_text(text, encoding="utf-8")
        sh(self.w, "add", "-A")
        sh(self.w, "commit", "-qm", name)
        sh(self.w, "checkout", "-q", "trunk")

    def test_open_branch_added_only_on_a_copy_is_found(self):
        """지휘자 수리 2 — 열린 에픽 찾기도 상태 계산과 같은 규칙(블록을 잇는 사본 읽기)."""
        self.branch("feature/a1", "x.txt", "a1\n")
        self.branch("feature/a2", "y.txt", "a2\n")
        self.copy_branch("feature/a2-next", BLOCK.replace("- 브랜치: feature/a2\n", "- 브랜치: feature/a2 · feature/a2-next\n"),
                         "z.txt", "next\n")
        self.copy_branch("feature/stale", BLOCK.replace("- 브랜치: feature/a2\n", "- 브랜치: feature/stale\n"),
                         "s.txt", "stale\n")
        out_dir = self.t / "pack-copy"
        old = os.environ.get("PATH", "")
        os.environ["PATH"] = str(self.t)  # gh 없음
        try:
            rc, out = self.cli("review-pack", "--roadmap", RM, "--epic", "A1", "--branch", "feature/a1", "--out", str(out_dir))
        finally:
            os.environ["PATH"] = old
        self.assertEqual(rc, 0, out)
        self.assertTrue((out_dir / "open-A2-feature_a2.diff").exists())
        self.assertIn("+next", (out_dir / "open-A2-feature_a2-next.diff").read_text(encoding="utf-8"))
        self.assertIn("feature/a2-next 도 열린 브랜치로 셌다", out)
        self.assertFalse((out_dir / "open-A2-feature_stale.diff").exists(), "블록의 브랜치를 다 품지 않은 낡은 사본은 세지 않는다")

    def test_copy_reading_failure_is_warned_not_silent(self):
        self.branch("feature/a1", "x.txt", "a1\n")
        import roadmap_status as rs
        real = rs.extra_branches

        def boom(*_a, **_k):
            raise RuntimeError("git 을 실행하지 못했다: x")
        rs.extra_branches = boom
        try:
            rc, out = self.cli("review-pack", "--roadmap", RM, "--epic", "A1", "--branch", "feature/a1",
                               "--out", str(self.t / "pack-boom"))
        finally:
            rs.extra_branches = real
        self.assertEqual(rc, 0, out)
        self.assertIn("경고: 로드맵 사본을 읽지 못했다", out)

    def test_worktree_path(self):
        rc, out = self.cli("worktree-path", "--name", "a1")
        self.assertEqual(rc, 0)
        self.assertTrue(out.strip().endswith("/a1"), out)
        self.assertTrue(out.strip().startswith(str(self.w.resolve())), out)
        self.assertEqual(self.cli("worktree-path", "--name", "../x")[0], 2)
        self.assertEqual(self.cli("worktree-path", "--name", "..")[0], 2)


class ParallelTruth(Repo):
    """지휘자 수리 2 — 공유 스위트 잠금 경로 · 원장 진행 · 「작업」 표(로드맵 밖 일 포함)."""
    def test_suite_lock_path_and_state(self):
        rc, out = self.cli("suite-lock", "--roadmap", RM)
        self.assertEqual(rc, 0, out)
        path, line = out.splitlines()[:2]
        self.assertEqual(Path(path), suite_lock.lock_path(L.mpath(self.w, RM).parent))
        self.assertEqual(line, "스위트 잠금: 비어 있음")
        Path(path).mkdir(parents=True)
        (Path(path) / "owner").write_text("%d impl t\n" % os.getppid(), encoding="utf-8")
        _rc, out = self.cli("suite-lock", "--roadmap", RM)
        self.assertIn("주인 %d impl t" % os.getppid(), out)
        self.assertIn("잡은 시각", out)

    def test_progress_shows_last_line_and_age(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        led = self.t / "progress.md"
        led.write_text("# 진행\n\n- Task 1 끝\n- Task 2 스위트 잠금 대기\n", encoding="utf-8")
        self.cli("add", "--roadmap", RM, "--session", SID, "--section", "실행 원장",
                 "--cells", "A1 · plan.md · %s · 0" % led)
        self.cli("add", "--roadmap", RM, "--session", SID, "--section", "실행 원장",
                 "--cells", "A2 · plan2.md · %s · 0" % (self.t / "none.md"))
        rc, out = self.cli("progress", "--roadmap", RM)
        self.assertEqual(rc, 0, out)
        self.assertTrue(out.startswith("기준 "), out)
        self.assertIn("A1 · plan.md · 마지막 고침", out)
        self.assertIn("분 전) · - Task 2 스위트 잠금 대기", out)
        self.assertIn("A2 · plan2.md · 원장을 읽지 못했다", out)

    def test_progress_empty(self):
        rc, out = self.cli("progress", "--roadmap", RM)
        self.assertEqual(rc, 0)
        self.assertIn("실행 원장 없음", out)

    def test_works_table_holds_outside_roadmap_rows(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        rc, out = self.cli("add", "--roadmap", RM, "--session", SID, "--section", "작업",
                           "--cells", "수리 PR · fix/conductor-parallel-truth · 로드맵 밖 · 구현 · conductor-fix2 · ~/x/design.md")
        self.assertEqual(rc, 0, out)
        rows = cs.load(L.mpath(self.w, RM), RM)["작업"]
        self.assertEqual(rows, [{"종류": "수리 PR", "이름": "fix/conductor-parallel-truth", "에픽": "로드맵 밖",
                                 "단계": "구현", "담당": "conductor-fix2", "근거": "~/x/design.md"}])
        rc, _out = self.cli("add", "--roadmap", RM, "--session", SID, "--section", "작업", "--cells", "a · b · c")
        self.assertEqual(rc, 2)


if __name__ == "__main__":
    unittest.main()
