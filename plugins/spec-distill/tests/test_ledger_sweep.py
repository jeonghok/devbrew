"""R7 §3-2 · §3-3 — ledger_sweep.py (AC9) + 옛 GC 가 .docreview 를 지우지 않음(AC6 픽스처, R-g)."""
import fcntl
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
SWEEP = SCRIPTS / "ledger_sweep.py"
sys.path.insert(0, str(SCRIPTS))
import docreview_state  # noqa: E402
REPO = Path(__file__).resolve().parents[3]
OLD_GC_COMMIT = "9b7a5e07"
OLD = time.time() - 30 * 3600          # TTL(24h) 너머


def run(args=(), env_extra=None, cwd=None):
    env = {k: v for k, v in os.environ.items()
           if k not in ("DEVBREW_SPEC_DISTILL_DISABLE", "DEVBREW_SKIP_HOOKS", "DEVBREW_SPEC_DISTILL_TTL_HOURS")}
    env.update(env_extra or {})
    cp = subprocess.run([sys.executable, str(SWEEP), *args], env=env, cwd=cwd,
                        capture_output=True, text=True, timeout=30)
    return cp.returncode, cp.stdout, cp.stderr


def age(path: Path, when=OLD):
    for dp, dns, fns in os.walk(path):
        for n in dns + fns:
            os.utime(os.path.join(dp, n), (when, when), follow_symlinks=False)
    os.utime(path, (when, when))


def write_ledger(d: Path, doc: str):
    d.mkdir(parents=True, exist_ok=True)
    st = docreview_state._empty(doc, "design-doc")   # 엔진이 쓴 모양 그대로 — 손으로 만든 원장이 아니다
    st["round"] = 2
    st["_body"] = "# docreview 원장\n"
    docreview_state.save_state(d, st)


def append_ledger_line(d: Path, line: str):
    st = docreview_state.load_state(d)
    st["_body"] = st["_body"] + line + "\n"
    docreview_state.save_state(d, st)


def key_for(root: Path, doc: str) -> Path:
    out = subprocess.run([sys.executable, str(SCRIPTS / "docreview_state.py"), "state-dir-for",
                          "--root", str(root), "--doc", doc], capture_output=True, text=True, check=True)
    return Path(out.stdout.strip())


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp()).resolve()
        subprocess.run(["git", "init", "-q"], cwd=self.tmp, check=True)
        self.root = self.tmp / ".claude" / "spec-distill"
        self.root.mkdir(parents=True)
        self.docs = self.tmp / "docs"
        self.docs.mkdir()

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def doc(self, name="d.md"):
        p = self.docs / name
        p.write_text("x\n", encoding="utf-8")
        return str(p)

    def sweep(self, env=None):
        return run(["--root", str(self.root)], env_extra=env)

    def old_session(self, sid, ledgers=(), state_local=False):
        s = self.root / sid
        s.mkdir()
        (s / "interview-basename").write_text("x\n", encoding="utf-8")   # 직속 파일 — grace 창을 비켜 간다
        for name, doc in ledgers:
            write_ledger(s / "docreview" / name, doc)
        if state_local:
            (s / "state.local.md").write_text("---\n---\n", encoding="utf-8")
        age(s)
        return s


class LedgerRootTest(Base):
    def test_docless_ledger_removed_after_ttl(self):
        d = key_for(self.root, str(self.docs / "gone.md")); write_ledger(d, str(self.docs / "gone.md")); age(d)
        rc, out, _ = self.sweep()
        self.assertFalse(d.exists())
        self.assertIn("문서 없는 원장 1개", out)

    def test_docless_ledger_within_ttl_kept(self):
        d = key_for(self.root, str(self.docs / "gone.md")); write_ledger(d, str(self.docs / "gone.md"))
        self.sweep()
        self.assertTrue(d.exists())

    def test_ledger_with_doc_kept(self):
        doc = self.doc(); d = key_for(self.root, doc); write_ledger(d, doc); age(d)
        self.sweep()
        self.assertTrue(d.exists())

    def test_unreadable_ledger_kept_and_announced(self):
        d = self.root / ".docreview" / "x-0000000000000000"; d.mkdir(parents=True)
        (d / "critic.txt").write_text("y", encoding="utf-8"); age(d)
        rc, out, _ = self.sweep()
        self.assertTrue(d.exists())
        self.assertIn("읽지 못한 원장 1개 남김 — %s" % d, out)

    def test_relative_doc_path_is_unreadable(self):
        d = self.root / ".docreview" / "rel-0000000000000000"
        write_ledger(d, "docs/gone.md"); age(d)
        rc, out, _ = self.sweep()
        self.assertTrue(d.exists())
        self.assertIn("읽지 못한 원장 1개 남김 — %s" % d, out)

    def test_docreview_symlink_uncountable(self):
        outside = self.tmp / "outside"; outside.mkdir()
        os.symlink(outside, self.root / ".docreview")
        s = self.old_session("oldsess01", ledgers=[("k1", self.doc())])   # ② 의 이월도 링크 너머로 가지 않는다
        rc, out, _ = self.sweep()
        self.assertIn("원장 정리 — 셀 수 없음(", out)
        self.assertTrue(outside.exists())
        self.assertEqual(os.listdir(outside), [])
        self.assertTrue((s / "docreview" / "k1" / "docreview-state.md").exists())

    def test_korean_doc_path_kept_and_migrated(self):
        doc = self.doc("설계 문서.md")
        s = self.old_session("oldsess01", ledgers=[("k1", doc)])
        rc, out, _ = self.sweep()
        self.assertTrue((key_for(self.root, doc) / "docreview-state.md").exists())
        self.assertFalse(s.exists())


class OldSessionTest(Base):
    def test_docreview_root_not_old_folder(self):
        doc = self.doc(); d = key_for(self.root, doc); write_ledger(d, doc); age(self.root / ".docreview")
        self.sweep()
        self.assertTrue(d.exists())

    def test_old_folder_without_state_local_removed(self):
        s = self.old_session("oldsess01")
        rc, out, _ = self.sweep()
        self.assertFalse(s.exists())
        self.assertIn("옛 세션 폴더 1개 지움", out)

    def test_old_folder_within_ttl_untouched(self):
        s = self.root / "newsess01"; s.mkdir(); (s / "f").write_text("x", encoding="utf-8")
        write_ledger(s / "docreview" / "k", self.doc())
        self.sweep()
        self.assertTrue((s / "docreview" / "k" / "docreview-state.md").exists())

    def test_state_local_folder_preserved_and_announced(self):
        s = self.old_session("oldsess01", state_local=True)
        rc, out, _ = self.sweep()
        self.assertTrue(s.exists())
        self.assertIn("옮기지 않은 옛 인터뷰 기록 1개 — %s" % (s / "state.local.md"), out)

    def test_old_ledger_with_doc_migrated_to_state_dir_for_key(self):
        doc = self.doc()
        s = self.old_session("oldsess01", ledgers=[("k1", doc)])
        rc, out, _ = self.sweep()
        self.assertTrue((key_for(self.root, doc) / "docreview-state.md").exists())
        self.assertFalse(s.exists())
        self.assertIn("옛 원장 1개 옮김", out)

    def test_old_ledger_without_doc_removed_with_folder(self):
        s = self.old_session("oldsess01", ledgers=[("k1", str(self.docs / "gone.md"))])
        self.sweep()
        self.assertFalse(s.exists())
        self.assertFalse(key_for(self.root, str(self.docs / "gone.md")).exists())

    def test_old_unreadable_ledger_keeps_folder(self):
        doc = self.doc()
        s = self.old_session("oldsess01", ledgers=[("k1", doc)])
        bad = s / "docreview" / "k2"; bad.mkdir(); (bad / "x").write_text("y", encoding="utf-8"); age(s)
        rc, out, _ = self.sweep()
        self.assertTrue(s.exists())
        self.assertTrue((key_for(self.root, doc) / "docreview-state.md").exists())  # 옮길 수 있는 것은 옮긴다
        self.assertIn("읽지 못한 원장", out)

    def _conflict(self, old_newer: bool, marker=False, target_unreadable=False):
        doc = self.doc()
        tgt = key_for(self.root, doc)
        if target_unreadable:
            tgt.mkdir(parents=True); (tgt / "x").write_text("y", encoding="utf-8")
        else:
            write_ledger(tgt, doc)
        if marker:
            (tgt / "reviewing-by").write_text("sess-live0001\n", encoding="utf-8")
        s = self.old_session("oldsess01", ledgers=[("k1", doc)])
        old_state = s / "docreview" / "k1" / "docreview-state.md"
        append_ledger_line(old_state.parent, "- old")
        age(s)                                   # 옛 폴더 전체를 다시 TTL 너머로 — 아래 한 파일만 조금 젊힌다
        # 옛 폴더는 TTL 너머여야 ② 가 본다 — 옛 원장의 시각은 OLD 근처에서만 움직인다.
        t_old, t_new = (OLD + 100, OLD) if old_newer else (OLD, time.time() - 100)
        os.utime(old_state, (t_old, t_old))
        if (tgt / "docreview-state.md").exists():
            os.utime(tgt / "docreview-state.md", (t_new, t_new))
        return doc, tgt, s

    def test_conflict_old_newer_wins(self):
        doc, tgt, s = self._conflict(old_newer=True)
        rc, out, _ = self.sweep()
        self.assertIn("- old", (tgt / "docreview-state.md").read_text(encoding="utf-8"))
        self.assertIn("옛 원장 충돌 — %s: 옛 쪽을 남겼다" % tgt.name, out)

    def test_conflict_new_newer_wins(self):
        doc, tgt, s = self._conflict(old_newer=False)
        rc, out, _ = self.sweep()
        self.assertNotIn("- old", (tgt / "docreview-state.md").read_text(encoding="utf-8"))
        self.assertIn("옛 원장 충돌 — %s: 새 쪽을 남겼다" % tgt.name, out)

    def test_conflict_marker_keeps_target(self):
        doc, tgt, s = self._conflict(old_newer=True, marker=True)
        rc, out, _ = self.sweep()
        self.assertNotIn("- old", (tgt / "docreview-state.md").read_text(encoding="utf-8"))
        self.assertIn("새 쪽을 남겼다", out)

    def test_conflict_marker_only_target_keeps_old_ledger(self):
        doc = self.doc()
        tgt = key_for(self.root, doc); tgt.mkdir(parents=True)
        (tgt / "reviewing-by").write_text("sess-live0001\n", encoding="utf-8")
        s = self.old_session("oldsess01", ledgers=[("k1", doc)])
        rc, out, _ = self.sweep()
        self.assertTrue((s / "docreview" / "k1" / "docreview-state.md").exists())
        self.assertFalse((tgt / "docreview-state.md").exists())
        self.assertIn("읽지 못한 원장 1개 남김 — %s\n" % tgt, out)
        self.assertNotIn("새 쪽을 남겼다", out)

    def test_conflict_unreadable_target_keeps_both(self):
        doc, tgt, s = self._conflict(old_newer=True, target_unreadable=True)
        rc, out, _ = self.sweep()
        self.assertTrue((tgt / "x").exists())
        self.assertTrue(s.exists())
        self.assertIn("읽지 못한 원장 1개 남김 — %s\n" % tgt, out)   # ① 과 ② 가 함께 봐도 한 번


class SafetyTest(Base):
    def test_kill_switches_spare_everything(self):
        envs = [{"DEVBREW_SPEC_DISTILL_DISABLE": "1"},
                {"DEVBREW_SKIP_HOOKS": "spec-distill:SessionEnd"},
                {"DEVBREW_SKIP_HOOKS": "spec-distill:session-end-cleanup"},
                {"DEVBREW_SKIP_HOOKS": "spec-distill:spec-distill-gc"}]
        for env in envs:
            s = self.old_session("oldsess%02d" % envs.index(env))
            d = key_for(self.root, str(self.docs / "gone.md")); write_ledger(d, str(self.docs / "gone.md")); age(d)
            self.sweep(env)
            self.assertTrue(s.exists(), env)
            self.assertTrue(d.exists(), env)
        self.sweep()                                   # 양성 대조 — 스위치 없으면 지운다
        self.assertFalse(d.exists())

    def test_root_escape_refused(self):
        real = self.tmp / "elsewhere"; real.mkdir()
        shutil.rmtree(self.root); os.symlink(real, self.root)
        s = real / "oldsess01"; s.mkdir(); (s / "f").write_text("x", encoding="utf-8"); age(s)
        rc, out, _ = self.sweep()
        self.assertTrue(s.exists())
        self.assertIn("셀 수 없음(", out)

    def test_lock_held_elsewhere_skips_loudly(self):
        s = self.old_session("oldsess01")
        fd = os.open(str(self.root), os.O_RDONLY)
        fcntl.flock(fd, fcntl.LOCK_EX)
        try:
            rc, out, _ = self.sweep()
        finally:
            os.close(fd)
        self.assertTrue(s.exists())
        self.assertIn("건너뜀(다른 세션이 정리 중)", out)

    def test_pyyaml_missing_touches_nothing(self):
        shadow = self.tmp / "noyaml" / "yaml"; shadow.mkdir(parents=True)
        (shadow / "__init__.py").write_text("raise ImportError('no yaml')\n", encoding="utf-8")
        d = key_for(self.root, str(self.docs / "gone.md")); write_ledger(d, str(self.docs / "gone.md")); age(d)
        s = self.old_session("oldsess01")
        a = self.root / ".gc-pending-aaa"; a.mkdir(); age(a)
        rc, out, _ = self.sweep({"PYTHONPATH": str(self.tmp / "noyaml")})
        self.assertEqual(rc, 0)
        self.assertEqual(out.count("원장 정리 — 셀 수 없음(pyyaml 없음)"), 1)
        self.assertNotIn("읽지 못한 원장", out)
        self.assertTrue(d.exists()); self.assertTrue(s.exists()); self.assertTrue(a.exists())
        rc, out, _ = self.sweep()                      # 양성 대조 — yaml 이 있으면 지운다
        self.assertFalse(d.exists()); self.assertFalse(s.exists()); self.assertFalse(a.exists())

    def test_gc_pending_swept_in_both_places(self):
        a = self.root / ".gc-pending-aaa"; a.mkdir(); age(a)
        (self.root / ".docreview").mkdir()
        b = self.root / ".docreview" / ".gc-pending-bbb"; b.mkdir(); age(b)
        self.sweep()
        self.assertFalse(a.exists()); self.assertFalse(b.exists())


class LinkSafetyTest(Base):
    """저장소가 심을 수 있는 링크 — 옛 원장 자리 · 새 키 자리 · 상태 파일. 밖은 옮겨지지도 지워지지도 않는다."""

    def _outside_ledger(self, name, doc):
        out = self.tmp / name
        write_ledger(out / "k1", doc)
        return out, (out / "k1" / "docreview-state.md").read_text(encoding="utf-8")

    def test_old_docreview_link_not_followed(self):
        doc = self.doc()
        outside, before = self._outside_ledger("outside", doc)
        s = self.old_session("oldsess01")
        os.symlink(outside, s / "docreview"); age(s)
        rc, out, _ = self.sweep()
        self.assertEqual((outside / "k1" / "docreview-state.md").read_text(encoding="utf-8"), before)
        self.assertFalse(key_for(self.root, doc).exists())
        self.assertTrue(s.exists())
        self.assertIn("읽지 못한 원장 1개 남김 — %s" % (s / "docreview" / "k1"), out)

    def test_old_ledger_link_not_followed(self):
        doc = self.doc()
        outside, before = self._outside_ledger("outside", doc)
        s = self.old_session("oldsess01")
        (s / "docreview").mkdir(); os.symlink(outside / "k1", s / "docreview" / "k1"); age(s)
        rc, out, _ = self.sweep()
        self.assertEqual((outside / "k1" / "docreview-state.md").read_text(encoding="utf-8"), before)
        self.assertFalse(key_for(self.root, doc).exists())
        self.assertIn("읽지 못한 원장 1개 남김 — %s" % (s / "docreview" / "k1"), out)

    def test_dangling_new_key_link_not_followed(self):
        doc = self.doc()
        tgt = key_for(self.root, doc); tgt.parent.mkdir(parents=True)
        nowhere = self.tmp / "nowhere"
        os.symlink(nowhere, tgt)
        s = self.old_session("oldsess01", ledgers=[("k1", doc)])
        rc, out, _ = self.sweep()
        self.assertFalse(os.path.lexists(nowhere))
        self.assertTrue(tgt.is_symlink())
        self.assertTrue((s / "docreview" / "k1" / "docreview-state.md").exists())
        self.assertIn("읽지 못한 원장 1개 남김 — %s" % tgt, out)

    def test_new_key_link_to_outside_not_followed(self):
        doc = self.doc()
        outside, before = self._outside_ledger("outside", doc)
        os.utime(outside / "k1" / "docreview-state.md", (OLD - 1000, OLD - 1000))  # 옛 쪽이 더 새다
        tgt = key_for(self.root, doc); tgt.parent.mkdir(parents=True)
        os.symlink(outside / "k1", tgt)
        s = self.old_session("oldsess01", ledgers=[("k1", doc)])
        rc, out, _ = self.sweep()
        self.assertTrue(tgt.is_symlink())
        self.assertEqual(os.readlink(tgt), str(outside / "k1"))
        self.assertEqual((outside / "k1" / "docreview-state.md").read_text(encoding="utf-8"), before)
        self.assertTrue((s / "docreview" / "k1" / "docreview-state.md").exists())
        self.assertNotIn("옛 쪽을 남겼다", out)
        self.assertIn("읽지 못한 원장 1개 남김 — %s" % tgt, out)

    def test_state_file_link_unreadable(self):
        outside_file = self.tmp / "outside-state.md"
        outside_file.write_text("---\ndocreview:\n  doc: %s\n---\n" % (self.docs / "gone.md"), encoding="utf-8")
        d = self.root / ".docreview" / "x-0000000000000000"; d.mkdir(parents=True)
        os.symlink(outside_file, d / "docreview-state.md"); age(d)
        rc, out, _ = self.sweep()
        self.assertTrue(d.exists())
        self.assertTrue(outside_file.exists())
        self.assertIn("읽지 못한 원장 1개 남김 — %s" % d, out)


class OldGcIgnoresDocreviewTest(unittest.TestCase):
    """AC6 — 옛 버전 spec-distill-gc.py 가 .docreview 를 지우지 않는다(TTL 1h · mtime 2h 전) + 양성 짝 둘."""

    def test_old_gc(self):
        tmp = Path(tempfile.mkdtemp()).resolve()
        try:
            src = subprocess.run(["git", "-C", str(REPO), "show",
                                  OLD_GC_COMMIT + ":plugins/spec-distill/scripts/spec-distill-gc.py"],
                                 capture_output=True, text=True)
            self.assertEqual(src.returncode, 0,
                             "옛 GC 를 git 에서 꺼내지 못했다(커밋 %s 도달 불가) — 도출 불가는 RED" % OLD_GC_COMMIT)
            tools = tmp / "oldgc"; tools.mkdir()
            (tools / "spec-distill-gc.py").write_text(src.stdout, encoding="utf-8")
            for n in ("state_path.py", "gc_common.py", "kill_switch_active.py"):
                shutil.copy(SCRIPTS / n, tools / n)
            repo = tmp / "repo"; repo.mkdir()
            subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
            root = repo / ".claude" / "spec-distill"; root.mkdir(parents=True)
            new_ledger = root / ".docreview" / "d-0123456789abcdef"; write_ledger(new_ledger, "/x/d.md")
            old_name = root / "docreview"; old_name.mkdir(); (old_name / "f").write_text("x", encoding="utf-8")
            stale = root / "stalesess01"; stale.mkdir(); (stale / "f").write_text("x", encoding="utf-8")
            fresh = root / "freshsess01"; fresh.mkdir(); (fresh / "f").write_text("x", encoding="utf-8")
            two_h = time.time() - 2 * 3600
            for p in (root / ".docreview", old_name, stale):
                age(p, two_h)
            env = {k: v for k, v in os.environ.items()
                   if k not in ("CLAUDE_CODE_SESSION_ID", "DEVBREW_SPEC_DISTILL_DISABLE", "DEVBREW_SKIP_HOOKS")}
            env["DEVBREW_SPEC_DISTILL_TTL_HOURS"] = "1"
            subprocess.run([sys.executable, str(tools / "spec-distill-gc.py")], cwd=repo, env=env,
                           capture_output=True, text=True, timeout=30)
            self.assertTrue((new_ledger / "docreview-state.md").exists(), "옛 GC 가 .docreview 원장을 지웠다")
            self.assertFalse(old_name.exists(), "양성 짝: 정규식에 맞는 늙은 폴더(옛 docreview 이름)는 지워져야 한다")
            self.assertFalse(stale.exists(), "양성 짝: 늙은 세션 폴더는 지워져야 한다")
            self.assertTrue(fresh.exists(), "양성 짝: mtime 이 지금인 폴더는 TTL 1h 로 남아야 한다")
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
