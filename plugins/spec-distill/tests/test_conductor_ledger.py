#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_ledger.py — 기계 상태 쓰기 · 표지 · 로드맵 찾기(R5 계획 3 Task 4). 뒤 Task 가 클래스를 더한다.

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

# 시작 승인 절을 쓰던 판이 실제로 쓴 기계 상태 글(그 판의 render_machine 출력 그대로).
OLD_MACHINE = (
    "---\ntype: conductor-machine\nroadmap: docs/superpowers/roadmaps/rm/roadmap.md\nwriter: spec-distill 8.9.1\n---\n\n"
    "## PR\n\n\n## 실행 원장\n\n\n## 자원\n\n\n## 살아 있는 agent\n\n\n## 기다리는 질문\n\n\n"
    "## 쌓인 기록\n\n\n## 레포 설정\n\n\n## 시작 승인\n\n"
    "- session-aaaa1111 · 2026-10-18 10:00 · 남은 에픽 2 · agent 약 6\n"
)


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

    def gh_origin(self):
        """가짜 gh 를 부르는 사례 — 픽스처의 origin 은 로컬 경로라 gh_repo 가 슬러그를 뽑지 못한다. 슬러그만 바꾼다."""
        from unittest import mock
        patch = mock.patch.object(L.gh_repo, "origin_slug", return_value=("github.com", "me", "r"))
        patch.start()
        self.addCleanup(patch.stop)


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


class RetiredApproval(Repo):
    def test_retired_subcommands_are_unknown(self):
        script = str(Path(L.__file__).resolve())
        for cmd in ("approval", "approve"):
            p = subprocess.run([sys.executable, script, "--root", str(self.w), cmd, "--roadmap", RM,
                                "--session", SID, "--scale", "x"], capture_output=True, encoding="utf-8")
            self.assertEqual(p.returncode, 2, p.stderr)
            self.assertIn("invalid choice", p.stderr)
            self.assertIn("'%s'" % cmd, p.stderr)

    def test_claim_takeover_release_still_work(self):
        self.assertEqual(self.cli("claim", "--roadmap", RM, "--session", SID), (0, "acquired\n"))
        self.assertTrue(L.mpath(self.w, RM).is_file())
        self.assertEqual(self.cli("takeover", "--roadmap", RM, "--session", OTHER)[0], 0)
        rc, out = self.cli("release", "--roadmap", RM, "--session", OTHER)
        self.assertEqual(rc, 0)
        self.assertIn("표지를 풀었다", out)


class MarkerWrites(Repo):
    def test_other_cannot_add(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        rc, out = self.cli("add", "--roadmap", RM, "--session", OTHER, "--section", "자원",
                           "--cells", "worktree · /x · A1 · 설계 · t")
        self.assertEqual(rc, 5)
        self.assertIn(SID, out)

    def test_drop_where_needs_equals(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
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

    def assertUnchecked(self, row, why=None):
        """검사 불가 줄의 둘째 칸 = 「검사 불가 — <사유>」, 사유는 비지 않는다(why 를 주면 그 사유 그대로)."""
        self.assertIsNotNone(row)
        self.assertTrue(row.startswith("검사 불가 — "), row)
        self.assertTrue(row[len("검사 불가 — "):].strip(), row)
        if why is not None:
            self.assertEqual(row, "검사 불가 — " + why)

    def test_unreadable_roadmap_is_listed_unchecked(self):
        self.put({"plan/roadmaps/rm/bad.md": "---\ntype: roadmap\n---\n\n# x\n",
                  "plan/roadmaps/q/quoted.md": b'---\r\ntype: "roadmap"\r\n---\r\n\r\n# x\r\n',
                  "plan/roadmaps/rm/broken.md": "---\ntype: roadmap\n# 머리말이 닫히지 않았다\n"})
        rows = self.rows()
        self.assertUnchecked(rows.get("plan/roadmaps/rm/bad.md"))
        self.assertUnchecked(rows.get("plan/roadmaps/q/quoted.md"))
        self.assertUnchecked(rows.get("plan/roadmaps/rm/broken.md"), "머리말이 닫히지 않았다")

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
        got, rc = cp.cat_batch(repo, shas)
        self.assertEqual(rc, 0)   # 없는 blob 은 `<blob> missing` 줄일 뿐 git 은 0 으로 끝난다
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
        for p, why in (("plan/roadmaps/lfs/roadmap.md", "LFS 포인터다"),
                       ("plan/roadmaps/ln/roadmap.md", "일반 파일이 아니다(링크 · 서브모듈 등)"),
                       ("plan/roadmaps/rm/broken.md", "머리말이 닫히지 않았다")):
            self.assertUnchecked(rows[p], why)

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
        (mc / "run-x" / "tmp-merged").mkdir()   # 옛 판이 남긴 실행 폴더의 찌꺼기 — 사본과 함께 지운다
        (mc / "run-x" / "units.assign").write_text("x", encoding="utf-8")
        (mc / "run-y").mkdir()                  # 다른 실행 폴더는 건드리지 않는다
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
        self.assertFalse((mc / "run-x").exists(), "합친 사본을 지우면 그 실행 폴더(임시 폴더 · 결과)도 지운다")
        self.assertTrue((mc / "run-y").is_dir(), "다른 실행 폴더는 그대로다")

    def test_cleanup_keeps_run_folder_with_another_copy(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        run = self._mdir() / "merge-check" / "run-x"
        run.mkdir(parents=True)
        copy, other = run / "merged", run / "base"
        for p in (copy, other):
            sh(self.w, "worktree", "add", "-q", "--detach", str(p), "trunk")
        self._row(copy)
        rc, out = self.cli("cleanup", "--roadmap", RM, "--session", SID, "--path", str(copy))
        self.assertEqual(rc, 0, out)
        self.assertFalse(copy.exists())
        self.assertTrue(other.is_dir(), "남은 사본(등록된 worktree)이 있으면 실행 폴더를 지우지 않는다")

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

    def test_unexpected_error_is_rc3_not_none(self):
        """예상 밖 예외(여기서는 기계 상태 폴더를 못 여는 PermissionError)는 파이썬 기본 rc 1(「없음」)이 아니라 rc 3 이다 —
        rc 1 이면 지휘자가 같은 계획 agent 를 한 번 더 보낸다."""
        self._add("plan-a1 · A1 · 계획 · /w/a1 · 2026-10-18")
        d = L.mpath(self.w, RM).parent
        os.chmod(str(d), 0)
        self.addCleanup(os.chmod, str(d), 0o755)
        p = subprocess.run([sys.executable, str(Path(L.__file__)), "--root", str(self.w), "live-agent", "--roadmap", RM,
                            "--epic", "A1", "--work", "계획"], capture_output=True, encoding="utf-8", env=ENV)
        self.assertEqual(p.returncode, 3, p.stdout + p.stderr)
        self.assertIn("내부 오류", p.stdout)
        self.assertNotIn("agent 없음", p.stdout)


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
    def test_no_gh_stops_without_fallback(self):
        old = os.environ.get("PATH", "")
        os.environ["PATH"] = str(self.t)  # gh 없는 PATH — git 은 절대경로로 부른다
        try:
            rc, out = self.cli("pr-handoffs", "--roadmap", RM, "--epic", "A1")
        finally:
            os.environ["PATH"] = old
        self.assertEqual(rc, 3, out)
        self.assertIn("PR 인계를 읽지 못했다 — " + L.gh_repo.STOP_NO_GH, out)
        self.assertNotIn("설계문서 `## 미룸`", out)

    def test_gh_stub(self):
        self.gh_origin()
        stub = self.t / "bin"
        stub.mkdir()
        (stub / "pr.json").write_text(json.dumps([{"number": 5, "state": "OPEN",
                                                   "body": "## 통합 리뷰 인계\n\n- R2 가 고침: z\n"}]), encoding="utf-8")
        (stub / "gh").write_text("#!/bin/sh\nprintf '%%s\\n' \"$@\" > '%s'\ncat '%s'\n" % (stub / "args", stub / "pr.json"),
                                 encoding="utf-8")
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
        args = (stub / "args").read_text(encoding="utf-8").splitlines()
        self.assertEqual(args[-2:], ["-R", "github.com/me/r"], args)
        self.assertEqual(args[:6], ["pr", "list", "--state", "all", "--head", "feature/a1"], args)

    def test_gh_stop_is_fail_3_with_its_sentence(self):
        from unittest import mock
        stop = "gh 인증이 안 됐다 — gh auth login --hostname github.com 를 돈다"
        with mock.patch.object(L.gh_repo, "gh_json", side_effect=L.gh_repo.GhStop(stop)), \
                mock.patch.object(L.gh_repo, "gh_exe", return_value="/x/gh"):
            rc, out = self.cli("pr-handoffs", "--roadmap", RM, "--epic", "A1")
        self.assertEqual(rc, 3, out)
        self.assertIn("PR 인계를 읽지 못했다 — " + stop, out)

    def _audit_with_gh(self, prs):
        self.gh_origin()
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
                mock.patch.object(L, "_epic_rows", return_value=[]), \
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
        for inst, repo in [("7.3", "7.3.0"), ("7.3.0", "7.3")]:  # 숫자 셋을 못 뽑으면 비교하지 않는다
            rc, msg = self.check(mk(inst), mk(repo))
            self.assertEqual(rc, 1, (inst, repo))
            self.assertIn("판을 비교하지 못했다", msg)
        rc, msg = self.check(mk("7.3.0"), mk("7.3.1"))
        self.assertEqual(rc, 1)
        self.assertIn("옛 판", msg)
        rc, msg = self.check(mk("7.9.0"), mk("7.10.0"))  # 정수로 비교한다
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
        self.views = {}
        self.viewed = []

    def fake_pr_list(self, cwd, branch, limit=100):
        self.calls.append((cwd, branch, limit))
        if self.stop:
            raise L.gh_repo.GhStop(self.stop)
        items = list(self.answers.get(branch, []))[:limit]
        return items, len(items) >= limit

    def fake_pr_view(self, cwd, number):
        self.viewed.append(number)
        return dict(self.views[number])

    def refresh(self, *extra, session=SID):
        from unittest import mock
        with mock.patch.object(L.gh_repo, "pr_list", self.fake_pr_list), \
                mock.patch.object(L.gh_repo, "pr_view", self.fake_pr_view):
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
        self.assertEqual(sorted((r["브랜치"], r["번호"], r["상태"]) for r in self.rows()),
                         [("feature/a1", "-", "PR 0개"), ("feature/a2", "#4", "닫힘")])
        self.assertIn("PR 캐시: 브랜치 2개 · PR 1개를", out)

    def test_branch_without_pr_gets_a_checked_marker(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        rc, out = self.refresh("--epic", "A1")
        self.assertEqual(rc, 0, out)
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0], cs.no_pr_row("feature/a1", rows[0]["확인한 때"], SID))
        self.assertRegex(rows[0]["확인한 때"], r"^\d{4}-\d\d-\d\d \d\d:\d\d$")
        self.assertIn("PR 캐시: 브랜치 1개 · PR 0개를", out)
        self.answers["feature/a1"] = [gh_pr(9, "OPEN", OID3, False)]
        rc, out = self.refresh("--epic", "A1")
        self.assertEqual([r["번호"] for r in self.rows()], ["#9"])

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
        self.assertEqual([(r["브랜치"], r["번호"]) for r in self.rows()],
                         [("feature/a1", "#7"), ("feature/a1", "#8"), ("feature/a1", "#9"), ("feature/a2", "-")])

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
        self.assertEqual([(r["브랜치"], r["번호"]) for r in self.rows()],
                         [("feature/a1", "#7"), ("feature/a1", "#8"), ("feature/a1", "#9"), ("feature/a2", "-")])

    def test_old_pr_row_stops_claim_and_takeover_without_writing(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.cli("release", "--roadmap", RM, "--session", SID)
        self.write_old_row()
        before = L.mpath(self.w, RM).read_bytes()
        rc, out = self.cli("claim", "--roadmap", RM, "--session", SID)
        self.assertEqual(rc, 3, out)
        self.assertIn("--reset 으로 다시 채운다", out)
        self.assertEqual(L.mpath(self.w, RM).read_bytes(), before)
        self.assertEqual(cs.holder(L.mpath(self.w, RM).parent), SID)
        rc, out = self.cli("takeover", "--roadmap", RM, "--session", OTHER)
        self.assertEqual(rc, 3, out)
        self.assertIn("--reset 으로 다시 채운다", out)
        self.assertEqual(L.mpath(self.w, RM).read_bytes(), before)

    def test_claim_rewrites_old_machine_without_start_approval(self):
        path = L.mpath(self.w, RM)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(OLD_MACHINE.replace("docs/superpowers/roadmaps/rm/roadmap.md", RM), encoding="utf-8")
        self.assertIn("## 시작 승인", path.read_text(encoding="utf-8"))
        rc, out = self.cli("claim", "--roadmap", RM, "--session", SID)
        self.assertEqual((rc, out.strip()), (0, "acquired"))
        self.assertNotIn("## 시작 승인", path.read_text(encoding="utf-8"))
        self.assertNotIn("예전 판이 적은 테스트 명령 줄", out, "옛 레포 설정 절이 비었으면 알리지 않는다")

    def test_claim_tells_old_repo_settings_rows_are_dropped(self):
        """8.11.0 까지 종료 코드 6 의 답을 적던 `## 레포 설정` 줄은 다시 쓸 때 지워진다 — 조용히 버리지 않고 한 번 알린다.
        값은 내보이지 않는다(검사받는 하위 agent 도 쓸 수 있는 파일이다)."""
        path = L.mpath(self.w, RM)
        path.parent.mkdir(parents=True, exist_ok=True)
        old = OLD_MACHINE.replace("docs/superpowers/roadmaps/rm/roadmap.md", RM)
        path.write_text(old.replace("## 레포 설정\n\n", "## 레포 설정\n\n- test_command · bash -c \"exit 0\"\n"),
                        encoding="utf-8")
        rc, out = self.cli("claim", "--roadmap", RM, "--session", SID)
        self.assertEqual(rc, 0, out)
        self.assertIn("예전 판이 적은 테스트 명령 줄", out)
        self.assertIn("사용자에게 다시 물어 --test-command 로 넘기거나", out)
        self.assertNotIn("exit 0", out, "옛 줄의 값을 알림에 싣지 않는다")
        self.assertEqual(out.strip().splitlines()[-1], "acquired")
        self.assertNotIn("레포 설정", path.read_text(encoding="utf-8"))
        rc, out = self.cli("add", "--roadmap", RM, "--session", SID, "--section", "쌓인 기록", "--cells", "R1 · 절 · 글")
        self.assertEqual(rc, 0, out)
        self.assertNotIn("예전 판이 적은 테스트 명령 줄", out, "지운 뒤에는 다시 알리지 않는다")

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

    def test_reset_refills_finished_blocks_too(self):
        from unittest import mock
        self.cli("claim", "--roadmap", RM, "--session", SID)
        rep = {"blocks": [{"id": "A1", "kind": "bundle", "stage": "머지됨", "branches": ["feature/a1"]},
                          {"id": "A2", "kind": "bundle", "stage": "끝남", "branches": ["feature/a2"]},
                          {"id": "A3", "kind": "bundle", "stage": "구현 끝", "branches": ["feature/a3"]}]}
        self.answers["feature/a1"] = [gh_pr(7, "MERGED", OID1, False, MOID)]
        with mock.patch.object(L, "_status", return_value=rep):
            rc, out = self.refresh()
            self.assertEqual([c[1] for c in self.calls], ["feature/a3"])
            self.calls.clear()
            rc, out = self.refresh("--reset")
        self.assertEqual(rc, 0, out)
        self.assertEqual([c[1] for c in self.calls], ["feature/a1", "feature/a2", "feature/a3"])
        self.assertEqual([(r["브랜치"], r["번호"], r["상태"]) for r in self.rows()],
                         [("feature/a1", "#7", "머지됨"), ("feature/a2", "-", "PR 0개"), ("feature/a3", "-", "PR 0개")])

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
        self.assertEqual([(r["브랜치"], r["번호"]) for r in self.rows()], [("feature/a1", "-"), ("feature/a1-2", "#11")])

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
        self.assertEqual(rc, 3, out)
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

    # ── 적은 번호(R14 AC3) ──
    def record_row(self, epic="A1", branch="feature/a1", number="#7"):
        L.update(self.w, RM, SID, lambda d: d[cs.EPIC_PR].append(
            {"에픽": epic, "브랜치": branch, "번호": number, "적은 때": "2026-10-01 10:00", "쓴 세션": SID}))

    def epic_rows(self):
        return cs.load(L.mpath(self.w, RM), RM)[cs.EPIC_PR]

    def numbers_of(self, branch):
        return [r["번호"] for r in self.rows() if r["브랜치"] == branch]

    def mismatch_line(self, out):
        return [l for l in out.splitlines() if "맞지 않는다" in l]

    def test_recorded_number_kept_when_missing_from_list(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.record_row()
        self.answers["feature/a1"] = [gh_pr(9, "OPEN", OID3, False)]
        self.views[7] = gh_pr(7, "MERGED", OID1, False, MOID)
        rc, out = self.refresh("--epic", "A1")
        self.assertEqual(rc, 0, out)
        self.assertEqual(self.viewed, [7])
        self.assertEqual(sorted((r["번호"], r["상태"], r["mergeCommit"]) for r in self.rows()),
                         [("#7", "머지됨", MOID), ("#9", "열림", "-")])
        self.assertIn("PR 캐시: 브랜치 1개 · PR 2개를", out)
        self.assertEqual(self.mismatch_line(out), [])
        # 양의 짝: 목록에 그 번호가 있으면 따로 묻지 않고 줄은 하나다
        self.viewed.clear()
        self.answers["feature/a1"] = [gh_pr(7, "MERGED", OID1, False, MOID), gh_pr(9, "OPEN", OID3, False)]
        rc, out = self.refresh("--epic", "A1")
        self.assertEqual(rc, 0, out)
        self.assertEqual(self.viewed, [])
        self.assertEqual(sorted(self.numbers_of("feature/a1")), ["#7", "#9"])

    def test_reset_keeps_epic_pr(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.record_row()
        before = self.epic_rows()
        self.assertEqual(len(before), 1)
        self.views[7] = gh_pr(7, "MERGED", OID1, False, MOID)
        rc, out = self.refresh("--reset")
        self.assertEqual(rc, 0, out)
        self.assertEqual(self.epic_rows(), before)
        self.assertEqual(self.numbers_of("feature/a1"), ["#7"])

    def test_mismatch_head_drops_only_that_row(self):
        from unittest import mock
        import control_plane
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.record_row()
        self.answers["feature/a1"] = [gh_pr(9, "OPEN", OID3, False)]
        self.answers["feature/a2"] = [gh_pr(4, "OPEN", OID2, False, head="feature/a2")]
        self.views[7] = gh_pr(7, "MERGED", OID1, False, MOID)
        with mock.patch.object(L, "now", return_value="2026-10-23 10:00"):
            rc, out = self.refresh()
            self.assertEqual(rc, 0, out)
            self.assertEqual(sorted(self.numbers_of("feature/a1")), ["#7", "#9"])  # 앞서 맞던 #7 줄
            epic_before = self.epic_rows()
            print_before = control_plane.pr_cache_fingerprint(cs.load(L.mpath(self.w, RM), RM))
            self.views[7] = gh_pr(7, "MERGED", OID1, False, MOID, head="feature/zz")
            self.calls.clear()
            rc, out = self.refresh()
        self.assertEqual(rc, 0, out)
        self.assertEqual(self.numbers_of("feature/a1"), ["#9"])
        self.assertEqual(self.epic_rows(), epic_before)
        self.assertEqual(sorted(c[1] for c in self.calls), ["feature/a1", "feature/a2"])  # 다른 블록 브랜치도 채운다
        self.assertEqual(self.numbers_of("feature/a2"), ["#4"])
        expected = ("[spec-distill] 적은 PR #7 이 feature/a1 와 맞지 않는다(headRefName: feature/a1 ≠ feature/zz) — "
                    "이 에픽의 PR 이면 `ledger pr-record --roadmap %s --session %s --epic A1 --pr <번호>` 로 다시 적고, "
                    "아니면 `ledger pr-record --roadmap %s --session %s --epic A1 --pr 7 --drop`" % (RM, SID, RM, SID))
        self.assertEqual(self.mismatch_line(out), [expected])
        self.assertIn("적은 PR #7 이 feature/a1 와 맞지 않는다(headRefName: feature/a1 ≠ feature/zz)", out)
        self.assertIn("--pr 7 --drop", out)
        self.assertIn("--pr <번호>", out)
        state = cs.load(L.mpath(self.w, RM), RM)
        self.assertEqual(cs.recorded_cache_row(state[cs.EPIC_PR], state["PR"], "A1", "feature/a1"), ("#7", None))
        self.assertNotEqual(control_plane.pr_cache_fingerprint(state), print_before)

    def test_mismatch_cross_repo(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.record_row()
        # head 목록에 그 번호가 교차 레포로 든 경우 — 따로 묻지 않고 목록에서 뺀다
        self.answers["feature/a1"] = [gh_pr(7, "OPEN", OID1, True), gh_pr(9, "OPEN", OID3, False)]
        rc, out = self.refresh("--epic", "A1")
        self.assertEqual(rc, 0, out)
        self.assertEqual(self.viewed, [])
        self.assertEqual(self.numbers_of("feature/a1"), ["#9"])
        self.assertEqual(len(self.epic_rows()), 1)
        [line] = self.mismatch_line(out)
        self.assertIn("적은 PR #7 이 feature/a1 와 맞지 않는다(isCrossRepository: false ≠ true)", line)
        self.assertIn("--pr 7 --drop", line)
        # 번호로 따로 받은 PR 이 교차 레포여도 같은 갈래
        self.answers["feature/a1"] = [gh_pr(9, "OPEN", OID3, False)]
        self.views[7] = gh_pr(7, "OPEN", OID1, True)
        rc, out = self.refresh("--epic", "A1")
        self.assertEqual(rc, 0, out)
        self.assertEqual(self.viewed, [7])
        self.assertEqual(self.numbers_of("feature/a1"), ["#9"])
        self.assertIn("(isCrossRepository: false ≠ true)", out)

    def test_no_record_suggestion_without_records(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.answers["feature/a1"] = [gh_pr(7, "OPEN", OID1, True), gh_pr(9, "OPEN", OID3, False)]
        rc, out = self.refresh()
        self.assertEqual(rc, 0, out)
        self.assertNotIn("pr-record", out)
        self.assertEqual(self.viewed, [])
        self.assertEqual(sorted(self.numbers_of("feature/a1")), ["#7", "#9"])  # 번호 없는 브랜치는 지금 그대로

    def test_warning_has_no_bare_hash(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.record_row()
        self.views[7] = gh_pr(7, "OPEN", OID1, False, head="feature/zz")
        rc, out = self.refresh("--epic", "A1")
        self.assertEqual(rc, 0, out)
        lines = self.mismatch_line(out)
        self.assertEqual(len(lines), 1, out)
        self.assertIn("--pr 7 --drop", lines[0])           # 양의 짝: 숫자 꼴은 있다
        self.assertNotIn("--pr #", lines[0])
        self.assertNotIn("--pr '#", lines[0])


class PrRecord(Repo):
    """ledger pr-record — 번호로 물은 PR 을 에픽의 브랜치 · 교차 · base 와 대조한 뒤에만 번호 줄과 PR 캐시 줄을 쓴다
    (R14 AC1 · AC20 · AC3 `--drop`)."""
    def setUp(self):
        super().setUp()
        self.gh_origin()
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.viewed = []
        self.answer = gh_pr(7, "OPEN", OID1, False)

    def fake_view(self, cwd, number):
        self.viewed.append(number)
        return dict(self.answer)

    def record(self, *extra, session=SID):
        from unittest import mock
        with mock.patch.object(L.gh_repo, "pr_view", self.fake_view):
            return self.cli("pr-record", "--roadmap", RM, "--session", session, "--epic", "A1", *extra)

    def state(self):
        return cs.load(L.mpath(self.w, RM), RM)

    def numbers(self):
        return [(r["에픽"], r["브랜치"], r["번호"]) for r in self.state()[cs.EPIC_PR]]

    def raw(self):
        return L.mpath(self.w, RM).read_bytes()

    def test_env_notices_are_shown(self):   # R14 미룸 — pr-refresh 와 같이 GH_REPO 를 무시한다고 알린다
        from unittest import mock
        with mock.patch.dict(os.environ, {"GH_REPO": "up/r"}):
            rc, out = self.record("--pr", "7")
        self.assertEqual(rc, 0, out)
        self.assertIn("GH_REPO 이 설정돼 있다(up/r) — devbrew 는 -R 로 origin 을 명시해 쓴다", out)
        with mock.patch.dict(os.environ, {"GH_REPO": ""}):
            rc, out = self.record("--pr", "7", "--drop")
        self.assertNotIn("GH_REPO", out, "양의 짝: 변수가 비었으면 알리지 않는다")

    def test_three_forms_record_one_row(self):
        for form in ("7", "#7", "https://github.com/me/r/pull/7"):
            rc, out = self.record("--pr", form)
            self.assertEqual(rc, 0, out)
            self.assertEqual(out.strip().splitlines()[-1], "번호를 적었다 — A1 · feature/a1 · #7(PR 캐시 줄도 썼다)")
            self.assertEqual(self.numbers(), [("A1", "feature/a1", "#7")])
            row = self.state()[cs.EPIC_PR][0]
            self.assertEqual(row["쓴 세션"], SID)
            self.assertRegex(row["적은 때"], r"^\d{4}-\d\d-\d\d \d\d:\d\d$")
        self.assertEqual(self.viewed, [7, 7, 7])

    def mismatch(self, answer, column):
        self.answer = answer
        before = self.raw()
        rc, out = self.record("--pr", "7")
        self.assertEqual(rc, 4, out)
        self.assertIn(column, out)
        self.assertIn("아무것도 적지 않았다", out)
        self.assertEqual(self.raw(), before)
        return out

    def test_head_mismatch_rc4_no_write(self):
        out = self.mismatch(gh_pr(7, "OPEN", OID1, False, head="feature/zz"), "headRefName")
        self.assertIn("feature/a1", out)
        self.assertIn("feature/zz", out)

    def test_cross_repo_rc4_no_write(self):
        self.mismatch(gh_pr(7, "OPEN", OID1, True), "isCrossRepository")

    def test_base_mismatch_rc4_no_write(self):
        out = self.mismatch(gh_pr(7, "OPEN", OID1, False, base="feature/a0"), "baseRefName")
        self.assertIn("trunk", out)
        self.assertIn("feature/a0", out)
        self.assertIn("쌓인 PR 이면 바탕을 기본 브랜치로 바꾼 직후 다시 적는다", out)

    def test_url_other_repo_rc4_without_gh(self):
        before = self.raw()
        rc, out = self.record("--pr", "https://github.com/other/r/pull/7")
        self.assertEqual(rc, 4, out)
        self.assertIn("PR URL 의 레포(github.com/other/r)가 origin(github.com/me/r)이 아니다 — 아무것도 적지 않았다", out)
        self.assertEqual(self.viewed, [])
        self.assertEqual(self.raw(), before)

    def test_url_same_repo_other_case_accepted(self):
        rc, out = self.record("--pr", "https://GitHub.com/ME/R/pull/7")
        self.assertEqual(rc, 0, out)
        self.assertEqual(self.numbers(), [("A1", "feature/a1", "#7")])

    def test_unreadable_pr_rc2(self):
        before = self.raw()
        rc, out = self.record("--pr", "abc")
        self.assertEqual(rc, 2, out)
        self.assertIn("PR 번호를 읽지 못했다: 'abc'", out)
        self.assertIn("--pr 123", out)
        self.assertEqual(self.viewed, [])
        self.assertEqual(self.raw(), before)

    def test_without_marker_rc5_without_gh(self):
        self.cli("takeover", "--roadmap", RM, "--session", OTHER)
        before = self.raw()
        rc, out = self.record("--pr", "7")
        self.assertEqual(rc, 5, out)
        self.assertIn("읽기 전용", out)
        self.assertEqual(self.viewed, [])
        self.assertEqual(self.raw(), before)

    def test_gh_stop_rc3_no_write(self):
        from unittest import mock

        def stop(cwd, number):
            raise L.gh_repo.GhStop("gh 인증이 안 됐다")
        before = self.raw()
        with mock.patch.object(L.gh_repo, "pr_view", stop):
            rc, out = self.cli("pr-record", "--roadmap", RM, "--session", SID, "--epic", "A1", "--pr", "7")
        self.assertEqual(rc, 3, out)
        self.assertIn("gh 인증이 안 됐다", out)
        self.assertEqual(self.raw(), before)

    def test_cache_row_written_and_replaced(self):
        old = L._cache_row("feature/a1", gh_pr(7, "OPEN", OID1, False), "2026-10-01 10:00", SID)
        keep = L._cache_row("feature/a1", gh_pr(5, "CLOSED", OID2, False), "2026-10-01 10:00", SID)
        other = L._cache_row("feature/a2", gh_pr(7, "OPEN", OID3, False, head="feature/a2"), "2026-10-01 10:00", SID)
        L.update(self.w, RM, SID, lambda d: d["PR"].extend(
            [old, cs.no_pr_row("feature/a1", "2026-10-01 10:00", SID), keep, other]))
        self.answer = gh_pr(7, "MERGED", OID1, False, MOID)
        rc, out = self.record("--pr", "7")
        self.assertEqual(rc, 0, out)
        rows = self.state()["PR"]
        self.assertEqual([(r["브랜치"], r["번호"], r["상태"]) for r in rows if r["브랜치"] == "feature/a1"],
                         [("feature/a1", "#5", "닫힘"), ("feature/a1", "#7", "머지됨")])
        self.assertIn(other, rows)
        mine = next(r for r in rows if r["브랜치"] == "feature/a1" and r["번호"] == "#7")
        self.assertEqual((mine["mergeCommit"], mine["쓴 세션"]), (MOID, SID))
        self.assertNotEqual(mine["확인한 때"], "2026-10-01 10:00")
        number, row = cs.recorded_cache_row(self.state()[cs.EPIC_PR], rows, "A1", "feature/a1")
        self.assertEqual((number, row), ("#7", mine))

    def test_copy_branch_head_accepted(self):
        from unittest import mock
        real = L._with_copy_branches

        def widen(root, roadmap, blocks, warns):
            blocks = real(root, roadmap, blocks, warns)
            for b in blocks:
                if b["id"] == "A1":
                    b["branches"] = list(b.get("branches") or []) + ["feature/a1-2"]
            return blocks
        self.answer = gh_pr(7, "OPEN", OID1, False, head="feature/a1-2")
        with mock.patch.object(L, "_with_copy_branches", widen):
            rc, out = self.record("--pr", "7")
        self.assertEqual(rc, 0, out)
        self.assertEqual(self.numbers(), [("A1", "feature/a1-2", "#7")])
        rc, out = self.record("--pr", "7")
        self.assertEqual(rc, 4, out)                       # 양의 짝: 사본이 더하지 않으면 같은 head 는 거부된다
        self.assertIn("headRefName", out)

    def test_other_epic_rows_kept(self):
        L.update(self.w, RM, SID, lambda d: d[cs.EPIC_PR].append(
            {"에픽": "A2", "브랜치": "feature/a2", "번호": "#3", "적은 때": "2026-10-01 10:00", "쓴 세션": SID}))
        rc, out = self.record("--pr", "7")
        self.assertEqual(rc, 0, out)
        self.assertEqual(self.numbers(), [("A2", "feature/a2", "#3"), ("A1", "feature/a1", "#7")])

    def test_drop_removes_without_gh(self):
        self.assertEqual(self.record("--pr", "7")[0], 0)
        self.viewed.clear()
        rc, out = self.record("--pr", "7", "--drop")
        self.assertEqual(rc, 0, out)
        self.assertEqual(self.numbers(), [])
        self.assertEqual(self.viewed, [])

    def test_drop_missing_rc1(self):
        self.assertEqual(self.record("--pr", "7")[0], 0)
        self.viewed.clear()
        rc, out = self.record("--pr", "8", "--drop")
        self.assertEqual(rc, 1, out)
        self.assertIn("지울 번호 줄이 없다 — A1 · #8", out)
        self.assertEqual(self.numbers(), [("A1", "feature/a1", "#7")])
        self.assertEqual(self.viewed, [])


class RecordThenStatus(Repo):
    """이미 머지된 PR 을 `pr-record` 로 적은 직후(`pr-refresh` 없이) 상태 계산이 그 번호로 머지됨이라 판정한다(R14 AC20).
    `pr-refresh --reset` 뒤에도 같다(AC19). `--drop` 뒤에는 이름 · 이력 길로 돌아간다(Review Focus 4)."""
    def setUp(self):
        super().setUp()
        self.gh_origin()
        sh(self.w, "checkout", "-q", "-b", "feature/a1")
        (self.w / "a1.txt").write_text("a1\n", encoding="utf-8")
        sh(self.w, "add", "a1.txt")
        sh(self.w, "commit", "-qm", "a1")
        tip = sh(self.w, "rev-parse", "HEAD").strip()
        sh(self.w, "checkout", "-q", "trunk")
        sh(self.w, "merge", "-q", "--no-ff", "feature/a1", "-m", "Merge branch 'feature/a1'")
        merge = sh(self.w, "rev-parse", "HEAD").strip()
        sh(self.w, "push", "-q", "origin", "trunk")
        self.pr = gh_pr(7, "MERGED", tip, False, merge)
        self.cli("claim", "--roadmap", RM, "--session", SID)

    def gh(self, *args):
        from unittest import mock
        with mock.patch.object(L.gh_repo, "pr_view", lambda cwd, number: dict(self.pr)), \
                mock.patch.object(L.gh_repo, "pr_list", lambda cwd, branch, limit=100:
                                  ([dict(self.pr)] if branch == "feature/a1" else [], False)):
            return self.cli(*args)

    def reason(self):
        return L._block(L._status(self.w, RM), "A1")

    def test_record_then_status_without_refresh(self):
        rc, out = self.gh("pr-record", "--roadmap", RM, "--session", SID, "--epic", "A1", "--pr", "7")
        self.assertEqual(rc, 0, out)
        b = self.reason()
        self.assertEqual(b["stage"], "머지됨", b)
        self.assertIn("PR #7 머지됨(적은 번호로 판정 · mergeCommit %s)" % self.pr["mergeCommit"]["oid"][:8], b["reason"])
        rc, out = self.gh("pr-refresh", "--roadmap", RM, "--session", SID, "--reset")
        self.assertEqual(rc, 0, out)
        b = self.reason()
        self.assertEqual(b["stage"], "머지됨", b)
        self.assertIn("적은 번호로 판정", b["reason"])

    def test_reset_lifts_hold_on_old_rows(self):
        """옛 판 4칸 줄이 남은 기계 상태 — 상태 계산은 머지 판정을 보류하고(R14 AC21) 사유에 `--reset` 을 싣는다.
        `pr-refresh --reset` 이 그 상태에서 돌고 보류를 푼다(Review Focus 1)."""
        path = L.mpath(self.w, RM)
        old = "- feature/a1 · #3 · 열림 · 2026-10-17 10:00"
        path.write_text(path.read_text(encoding="utf-8").replace("## PR\n\n", "## PR\n\n" + old + "\n", 1),
                        encoding="utf-8")
        b = self.reason()
        self.assertEqual(b["stage"], "알 수 없음", b)
        self.assertIn("feature/a1: 머지 판정 보류 — 기계 상태를 읽지 못해 PR 번호 기록이 있는지 모른다(", b["reason"])
        self.assertIn("--reset 으로 다시 채운다", b["reason"])
        rc, out = self.gh("pr-refresh", "--roadmap", RM, "--session", SID, "--reset")
        self.assertEqual(rc, 0, out)
        self.assertNotIn(old, path.read_text(encoding="utf-8"))
        b = self.reason()
        self.assertEqual(b["stage"], "머지됨", b)
        self.assertNotIn("머지 판정 보류", b["reason"])

    def test_drop_returns_to_name_path(self):
        self.assertEqual(self.gh("pr-record", "--roadmap", RM, "--session", SID, "--epic", "A1", "--pr", "7")[0], 0)
        self.assertIn("적은 번호로 판정", self.reason()["reason"])
        rc, out = self.gh("pr-record", "--roadmap", RM, "--session", SID, "--epic", "A1", "--pr", "7", "--drop")
        self.assertEqual(rc, 0, out)
        b = self.reason()
        self.assertEqual(b["stage"], "머지됨", b)
        self.assertNotIn("적은 번호", b["reason"])


class NoPrBranch(Repo):
    def test_no_pr_line(self):
        self.gh_origin()
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


class RecordedPrs(Repo):
    """적은 번호가 있는 브랜치는 pr-handoffs · audit · review-pack 이 그 번호의 PR 하나만 번호로 묻는다(R14 AC18).
    A1(feature/a1)에 #7 을 적었다. head 목록은 그 브랜치에 이름으로 먼저 잡히는 다른 PR #9(열림)를 낸다."""
    SEVEN = {"number": 7, "state": "MERGED",
             "body": "## 통합 리뷰 인계\n- seven\n- 리뷰 뒤 반영(리뷰 라운드를 거치지 않았다): seven-fix"}
    NINE = [{"number": 9, "state": "OPEN",
             "body": "## 통합 리뷰 인계\n- nine\n- 리뷰 뒤 반영(리뷰 라운드를 거치지 않았다): nine-fix"}]
    FOUR = [{"number": 4, "state": "OPEN", "body": "## 통합 리뷰 인계\n- four"}]

    def setUp(self):
        super().setUp()
        self.gh_origin()
        stub = self.t / "bin"
        stub.mkdir()
        self.args_file = stub / "args"
        for name, value in (("seven.json", self.SEVEN), ("nine.json", self.NINE), ("four.json", self.FOUR)):
            (stub / name).write_text(json.dumps(value), encoding="utf-8")
        script = ("#!/bin/sh\n"
                  "printf '%%s\\n' \"$*\" >> '{args}'\n"
                  "case \"$*\" in\n"
                  "  'pr view 7 '*) cat '{d}/seven.json' ;;\n"
                  "  *'--head feature/a1 '*) cat '{d}/nine.json' ;;\n"
                  "  *'--head feature/a2 '*) cat '{d}/four.json' ;;\n"
                  "  *) echo '[]' ;;\n"
                  "esac\n").replace("%%", "%").format(args=self.args_file, d=stub)
        (stub / "gh").write_text(script, encoding="utf-8")
        (stub / "gh").chmod(0o755)
        old = os.environ.get("PATH", "")
        os.environ["PATH"] = str(stub) + os.pathsep + old
        self.addCleanup(os.environ.__setitem__, "PATH", old)
        self.cli("claim", "--roadmap", RM, "--session", SID)
        L.update(self.w, RM, SID, lambda d: d[cs.EPIC_PR].append(
            {"에픽": "A1", "브랜치": "feature/a1", "번호": "#7", "적은 때": "2026-10-01 10:00", "쓴 세션": SID}))

    def args(self):
        return self.args_file.read_text(encoding="utf-8").splitlines() if self.args_file.exists() else []

    def test_handoffs_use_recorded_number(self):
        rc, out = self.cli("pr-handoffs", "--roadmap", RM, "--epic", "A1")
        self.assertEqual(rc, 0, out)
        self.assertIn("feature/a1 #7(MERGED)", out)
        self.assertIn("- seven", out)
        self.assertNotIn("#9", out)
        self.assertNotIn("nine", out)
        args = self.args()
        self.assertIn("pr view 7 --json number,state,body -R github.com/me/r", args)
        self.assertFalse([a for a in args if "list" in a and "--head feature/a1" in a], args)

    def test_audit_and_review_pack_use_recorded_number(self):
        rc, out = self.cli("audit", "--roadmap", RM, "--epic", "A1")
        self.assertEqual(rc, 0, out)
        self.assertIn("리뷰 뒤 반영 1개", out)
        self.assertIn("seven-fix", out)
        self.assertNotIn("#9", out)
        self.assertNotIn("nine", out)
        sh(self.w, "checkout", "-q", "-b", "feature/a1", "trunk")
        (self.w / "x.txt").write_text("a1\n", encoding="utf-8")
        sh(self.w, "add", "-A")
        sh(self.w, "commit", "-qm", "a1")
        sh(self.w, "checkout", "-q", "trunk")
        out_dir = self.t / "pack"
        rc, out = self.cli("review-pack", "--roadmap", RM, "--epic", "A1", "--branch", "feature/a1", "--out", str(out_dir))
        self.assertEqual(rc, 0, out)
        handoffs = (out_dir / "handoffs.md").read_text(encoding="utf-8")
        self.assertIn("### A1 feature/a1 #7(MERGED)", handoffs)
        self.assertIn("- seven", handoffs)
        self.assertIn("### A2 feature/a2 #4(OPEN)", handoffs)   # 양의 짝: 번호 없는 브랜치는 head 목록 그대로
        self.assertNotIn("#9", handoffs)
        self.assertNotIn("nine", handoffs)

    def test_unrecorded_branch_keeps_list(self):
        rc, out = self.cli("pr-handoffs", "--roadmap", RM, "--epic", "A2")
        self.assertEqual(rc, 0, out)
        self.assertIn("feature/a2 #4(OPEN)", out)
        self.assertIn("- four", out)
        args = self.args()
        self.assertTrue([a for a in args if a.startswith("pr list --state all --head feature/a2 ")], args)
        self.assertFalse([a for a in args if a.startswith("pr view")], args)


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
        self.gh_origin()
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
        self.gh_origin()
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


class RepoSettingsAdd(Repo):
    """기계 상태 `## 레포 설정` 은 옛 절이다 — 검사받는 하위 agent 도 쓸 수 있는 파일이라 스위트 대조가 읽지 않는다.
    `ledger add` 는 그 절(과 다른 옛 절)에 쓰지 않고, 사용자 답은 `merge_check.py run --test-command` 로 그 호출에만
    넘기라고 알린다(rc 2, 아무것도 쓰지 않는다)."""
    def setUp(self):
        super().setUp()
        self.cli("claim", "--roadmap", RM, "--session", SID)
        rc, out = self.cli("add", "--roadmap", RM, "--session", SID, "--section", "쌓인 기록", "--cells", "R1 · 절 · 글")
        self.assertEqual(rc, 0, out)
        self.before = L.mpath(self.w, RM).read_bytes()

    def refused(self, section, cells):
        rc, out = self.cli("add", "--roadmap", RM, "--session", SID, "--section", section, "--cells", cells)
        self.assertEqual(rc, 2, out)
        self.assertEqual(L.mpath(self.w, RM).read_bytes(), self.before, "거부면 기계 상태가 바이트까지 그대로다")
        return out

    def test_repo_settings_section_is_refused(self):
        for cells in ("test_command · make test", "test_failure_pattern · ^FAIL: (.+)$"):
            out = self.refused("레포 설정", cells)
            self.assertIn("merge_check.py run", out, cells)
            self.assertIn("--test-command", out, cells)
            self.assertIn(".devbrew.md", out, cells)

    def test_other_retired_section_is_refused(self):   # 옛 절은 쓰고 나서 버린다 — 「적었다」 고 말하지 않는다
        out = self.refused("시작 승인", "%s · 2026-10-18 10:00 · 남은 에픽 2" % SID)
        self.assertNotIn("적었다", out)

    def test_live_section_is_written(self):   # 양의 짝
        rc, out = self.cli("add", "--roadmap", RM, "--session", SID, "--section", "쌓인 기록", "--cells", "R2 · 절 · 글")
        self.assertEqual(rc, 0, out)
        self.assertNotEqual(L.mpath(self.w, RM).read_bytes(), self.before)


if __name__ == "__main__":
    unittest.main()
