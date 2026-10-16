"""R7 §1-4 · §1-7 · §2-5 — interview_state.py (AC3 · AC4 · AC11 · AC12 의 스크립트 쪽)."""
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "interview_state.py"
SID = "sess-aaaa1111"


def run(*args, cwd=None, env_extra=None):
    env = {k: v for k, v in os.environ.items()
           if k not in ("DEVBREW_SPEC_DISTILL_SESSION_ID", "CLAUDE_CODE_SESSION_ID")}
    env.update(env_extra or {})
    cp = subprocess.run([sys.executable, str(SCRIPT), *args], cwd=cwd, env=env,
                        capture_output=True, text=True, timeout=20)
    return cp.returncode, cp.stdout, cp.stderr


def last(out):
    lines = [l for l in out.splitlines() if l.strip()]
    return lines[-1] if lines else ""


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp()).resolve()
        subprocess.run(["git", "init", "-q"], cwd=self.tmp, check=True)
        self.iv = self.tmp / "docs" / "superpowers" / "interview"
        self.iv.mkdir(parents=True)

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp, ignore_errors=True)

    def put(self, name, typ, extra=""):
        p = self.iv / name
        p.write_text("---\ntype: %s\n%s---\nbody\n" % (typ, extra), encoding="utf-8")
        return p


class EntryTest(Base):
    def test_resume_on_state_file(self):
        p = self.put("2026-10-15-t-brief-interview.state.md", "interview-state", "seed: 없음\n")
        rc, out, _ = run("entry", "--arg", str(p), "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertEqual(last(out), "interview-state: RESUME %s" % p)

    def _outside(self):
        import shutil
        out = Path(tempfile.mkdtemp()).resolve()
        self.addCleanup(shutil.rmtree, str(out), True)
        return out

    def test_resume_refuses_linked_state_file(self):
        out = self._outside()
        real = out / "2026-10-15-x-interview.state.md"
        real.write_text("---\ntype: interview-state\nseed: 없음\n---\n밖\n", encoding="utf-8")
        link = self.iv / "2026-10-15-x-interview.state.md"
        os.symlink(str(real), str(link))
        rc, out_, _ = run("entry", "--arg", str(link), "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertTrue(last(out_).startswith("interview-state: REJECT %s (" % link), last(out_))

    def test_resume_refuses_linked_interview_dir(self):
        import shutil
        out = self._outside()
        (out / "2026-10-15-x-interview.state.md").write_text(
            "---\ntype: interview-state\nseed: 없음\n---\n밖\n", encoding="utf-8")
        shutil.rmtree(str(self.iv))
        os.symlink(str(out), str(self.iv))
        arg = self.iv / "2026-10-15-x-interview.state.md"
        rc, out_, _ = run("entry", "--arg", str(arg), "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertTrue(last(out_).startswith("interview-state: REJECT "), last(out_))

    def test_resume_refuses_state_file_outside_worktree(self):
        out = self._outside()
        p = out / "2026-10-15-x-interview.state.md"
        p.write_text("---\ntype: interview-state\nseed: 없음\n---\n밖\n", encoding="utf-8")
        rc, out_, _ = run("entry", "--arg", str(p), "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertTrue(last(out_).startswith("interview-state: REJECT "), last(out_))

    def test_resume_through_linked_cwd_is_allowed(self):
        """양성 대조 — cwd 를 링크로 들어왔을 때(논리 경로 인자) 이어 간다. 출력은 물리 cwd 접두의 절대경로."""
        p = self.put("2026-10-15-t-brief-interview.state.md", "interview-state", "seed: 없음\n")
        lk = self._outside() / "lk"
        os.symlink(str(self.tmp), str(lk))
        arg = lk / p.relative_to(self.tmp)
        rc, out_, _ = run("entry", "--arg", str(arg), "--session", SID, cwd=str(lk), env_extra={"PWD": str(lk)})
        self.assertEqual(rc, 0, out_)
        self.assertEqual(last(out_), "interview-state: RESUME %s" % p)

    # ── 짝 brief · audit 의 링크 — 끝낼 때 Write · 엔진 --log-file · degrade 원장 쓰기가 그 링크를 따라간다 ──
    def _sibling_fixture(self):
        st = self.put("2026-10-15-t-brief-interview.state.md", "interview-state", "seed: 없음\n")
        out = self._outside()
        victim = out / "authorized_keys"
        victim.write_text("원본\n", encoding="utf-8")
        return st, out, victim

    def test_resume_with_regular_audit_is_allowed(self):
        """양성 대조 — 짝 audit 가 보통 파일이고 brief 가 아직 없으면 이어 간다."""
        st = self.put("2026-10-15-t-brief-interview.state.md", "interview-state", "seed: 없음\n")
        self.put("2026-10-15-t-brief-interview.audit.md", "interview-audit")
        rc, out, _ = run("entry", "--arg", str(st), "--session", SID, cwd=self.tmp)
        self.assertEqual((rc, last(out)), (0, "interview-state: RESUME %s" % st))

    def test_resume_refuses_linked_audit(self):
        st, _, victim = self._sibling_fixture()
        os.symlink(str(victim), str(self.iv / "2026-10-15-t-brief-interview.audit.md"))
        rc, out, _ = run("entry", "--arg", str(st), "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertTrue(last(out).startswith("interview-state: REJECT %s (2026-10-15-t-brief-interview.audit.md: 링크를 거친다" % st),
                        last(out))
        self.assertEqual(victim.read_text(encoding="utf-8"), "원본\n")

    def test_resume_refuses_linked_brief(self):
        st, _, victim = self._sibling_fixture()
        os.symlink(str(victim), str(self.iv / "2026-10-15-t-brief-interview.md"))
        rc, out, _ = run("entry", "--arg", str(st), "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertTrue(last(out).startswith("interview-state: REJECT %s (2026-10-15-t-brief-interview.md: 링크를 거친다" % st),
                        last(out))

    def test_resume_refuses_dangling_brief_link(self):
        st, out_dir, _ = self._sibling_fixture()
        os.symlink(str(out_dir / "not-yet.md"), str(self.iv / "2026-10-15-t-brief-interview.md"))
        rc, out, _ = run("entry", "--arg", str(st), "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertTrue(last(out).startswith("interview-state: REJECT %s (2026-10-15-t-brief-interview.md: 링크를 거친다" % st),
                        last(out))
        self.assertFalse((out_dir / "not-yet.md").exists())

    def test_resume_refuses_finished_interview(self):
        st = self.put("2026-10-15-t-brief-interview.state.md", "interview-state", "seed: 없음\n")
        self.put("2026-10-15-t-brief-interview.md", "interview-brief")
        rc, out, _ = run("entry", "--arg", str(st), "--session", SID, cwd=self.tmp)
        self.assertEqual((rc, last(out)), (2, "interview-state: REJECT %s (이미 끝난 인터뷰다 — brief 가 있다)" % st))

    def _candidate_with_sibling_link(self, name, target):
        seed = self.put("2026-10-15-t-interview.md", "interview-seed")
        st = self.put("2026-10-15-t-brief-interview.state.md", "interview-state",
                      "seed: docs/superpowers/interview/2026-10-15-t-interview.md\n")
        os.symlink(str(target), str(self.iv / name))
        rc, out, err = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertNotIn("candidate: %s" % st, out)
        self.assertTrue(last(out).startswith("interview-state: NEW-SEED t-brief "), out)
        self.assertIn("이어 갈 후보에서 뺐다", err)

    def test_candidate_with_linked_audit_is_not_offered(self):
        victim = self._outside() / "authorized_keys"
        victim.write_text("원본\n", encoding="utf-8")
        self._candidate_with_sibling_link("2026-10-15-t-brief-interview.audit.md", victim)
        self.assertEqual(victim.read_text(encoding="utf-8"), "원본\n")

    def test_candidate_with_dangling_brief_link_is_not_offered(self):
        self._candidate_with_sibling_link("2026-10-15-t-brief-interview.md", self._outside() / "not-yet.md")

    def test_candidate_with_linked_brief_is_not_offered(self):
        victim = self._outside() / "b.md"
        victim.write_text("---\ntype: interview-brief\n---\n", encoding="utf-8")
        self._candidate_with_sibling_link("2026-10-15-t-brief-interview.md", victim)

    # ── seed: 값 — 링크 seed 는 `없음`(경로를 드러내지 않는다) ──
    def test_linked_seed_records_none(self):
        real = self._outside() / "2026-10-15-t-interview.md"
        real.write_text("---\ntype: interview-seed\n---\n밖\n", encoding="utf-8")
        seed = self.iv / "2026-10-15-t-interview.md"
        os.symlink(str(real), str(seed))
        rc, out, err = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
        self.assertEqual((rc, last(out)), (0, "interview-state: NEW-SEED t-brief seed=없음"))
        self.assertIn("seed 가 링크이거나 작업 트리 밖이다", err)
        self.assertNotIn("..", last(out))

    def test_reject_state_named_other_kind(self):
        p = self.put("2026-10-15-t-interview.state.md", "interview-seed")
        rc, out, _ = run("entry", "--arg", str(p), "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertTrue(last(out).startswith("interview-state: REJECT "))

    def test_new_seed_topic_gets_brief_tail(self):
        seed = self.put("2026-10-15-t-interview.md", "interview-seed")
        rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertEqual(last(out), "interview-state: NEW-SEED t-brief seed=docs/superpowers/interview/2026-10-15-t-interview.md")

    def test_ask_when_unfinished_state_points_at_seed(self):
        seed = self.put("2026-10-15-t-interview.md", "interview-seed")
        st = self.put("2026-10-15-t-brief-interview.state.md", "interview-state",
                      "seed: docs/superpowers/interview/2026-10-15-t-interview.md\n")
        rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
        self.assertEqual(last(out), "interview-state: ASK")
        self.assertIn("candidate: %s" % st, out)

    def test_linked_candidate_is_not_offered(self):
        seed = self.put("2026-10-15-t-interview.md", "interview-seed")
        out_dir = self._outside()
        real = out_dir / "2026-10-15-t-brief-interview.state.md"
        real.write_text("---\ntype: interview-state\nseed: docs/superpowers/interview/2026-10-15-t-interview.md\n---\n밖\n",
                        encoding="utf-8")
        link = self.iv / "2026-10-15-t-brief-interview.state.md"
        os.symlink(str(real), str(link))
        st = self.put("2026-10-15-t-brief-0930-interview.state.md", "interview-state",
                      "seed: docs/superpowers/interview/2026-10-15-t-interview.md\n")
        rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
        self.assertEqual(last(out), "interview-state: ASK")
        self.assertIn("candidate: %s" % st, out)            # 양성 대조 — 보통 파일은 그대로 후보
        self.assertNotIn("candidate: %s" % link, out)        # 링크는 후보로 내지 않는다
        self.assertEqual([l for l in out.splitlines() if l.startswith("candidate: ")], ["candidate: %s" % st])

    def test_only_linked_candidate_means_new_seed(self):
        seed = self.put("2026-10-15-t-interview.md", "interview-seed")
        out_dir = self._outside()
        real = out_dir / "x.state.md"
        real.write_text("---\ntype: interview-state\nseed: docs/superpowers/interview/2026-10-15-t-interview.md\n---\n밖\n",
                        encoding="utf-8")
        os.symlink(str(real), str(self.iv / "2026-10-15-t-brief-interview.state.md"))
        rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
        self.assertTrue(last(out).startswith("interview-state: NEW-SEED t-brief "), out)

    def test_finished_state_is_not_a_candidate(self):
        seed = self.put("2026-10-15-t-interview.md", "interview-seed")
        self.put("2026-10-15-t-brief-interview.state.md", "interview-state",
                 "seed: docs/superpowers/interview/2026-10-15-t-interview.md\n")
        self.put("2026-10-15-t-brief-interview.md", "interview-brief")
        rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
        self.assertTrue(last(out).startswith("interview-state: NEW-SEED "))

    def test_other_seed_state_is_not_a_candidate(self):
        seed = self.put("2026-10-15-t-interview.md", "interview-seed")
        self.put("2026-10-15-u-brief-interview.state.md", "interview-state",
                 "seed: docs/superpowers/interview/2026-10-14-u-interview.md\n")
        rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
        self.assertTrue(last(out).startswith("interview-state: NEW-SEED "))

    def test_rough_request_is_new(self):
        rc, out, _ = run("entry", "--arg", "", "--session", SID, cwd=self.tmp)
        self.assertEqual((rc, last(out)), (0, "interview-state: NEW"))

    def test_legacy_wins_over_seed(self):
        legacy = self.tmp / ".claude" / "spec-distill" / SID / "state.local.md"
        legacy.parent.mkdir(parents=True)
        legacy.write_text("---\nsession_id: x\n---\n## R1\n", encoding="utf-8")
        seed = self.put("2026-10-15-t-interview.md", "interview-seed")
        rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
        self.assertEqual(last(out), "interview-state: LEGACY %s" % legacy)


class MigrateTest(Base):
    def legacy(self):
        p = self.tmp / ".claude" / "spec-distill" / SID / "state.local.md"
        p.parent.mkdir(parents=True)
        p.write_text("---\nsession_id: x\nphase: 1\n---\n## R1\n기록\n", encoding="utf-8")
        return p

    def test_migrate_moves_and_prepends_keys(self):
        old = self.legacy()
        rc, out, _ = run("migrate-legacy", "--session", SID, "--topic", "t", "--date", "2026-10-15", cwd=self.tmp)
        new = self.iv / "2026-10-15-t-interview.state.md"
        self.assertEqual(rc, 0)
        self.assertIn("옛 위치의 진행 기록을 docs 로 옮겼다 — %s" % new, out)
        self.assertFalse(old.exists())
        text = new.read_text(encoding="utf-8")
        self.assertTrue(text.startswith("---\ntype: interview-state\nseed: 없음\nsession_id: x\n"))
        self.assertIn("## R1\n기록\n", text)

    def test_migrate_records_regular_seed(self):
        """양성 대조 — 작업 트리 안 보통 seed 는 상대경로로 적힌다."""
        self.legacy()
        seed = self.put("2026-10-15-t-interview.md", "interview-seed")
        rc, _, _ = run("migrate-legacy", "--session", SID, "--topic", "t-brief", "--date", "2026-10-15",
                       "--seed", str(seed), cwd=self.tmp)
        self.assertEqual(rc, 0)
        text = (self.iv / "2026-10-15-t-brief-interview.state.md").read_text(encoding="utf-8")
        self.assertTrue(text.startswith("---\ntype: interview-state\nseed: docs/superpowers/interview/2026-10-15-t-interview.md\n"), text)

    def test_migrate_linked_seed_records_none(self):
        import shutil
        self.legacy()
        out = Path(tempfile.mkdtemp()).resolve()
        self.addCleanup(shutil.rmtree, str(out), True)
        real = out / "s.md"
        real.write_text("---\ntype: interview-seed\n---\n밖\n", encoding="utf-8")
        seed = self.iv / "2026-10-15-t-interview.md"
        os.symlink(str(real), str(seed))
        rc, _, err = run("migrate-legacy", "--session", SID, "--topic", "t-brief", "--date", "2026-10-15",
                         "--seed", str(seed), cwd=self.tmp)
        self.assertEqual(rc, 0)
        text = (self.iv / "2026-10-15-t-brief-interview.state.md").read_text(encoding="utf-8")
        self.assertTrue(text.startswith("---\ntype: interview-state\nseed: 없음\n"), text)
        self.assertIn("seed 가 링크이거나 작업 트리 밖이다", err)

    def test_migrate_refuses_existing_target(self):
        old = self.legacy()
        tgt = self.put("2026-10-15-t-interview.state.md", "interview-state")
        before = tgt.read_bytes()
        rc, _, err = run("migrate-legacy", "--session", SID, "--topic", "t", "--date", "2026-10-15", cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertTrue(old.exists())
        self.assertEqual(tgt.read_bytes(), before)
        self.assertIn("이미 파일이 있다", err)

    def test_migrate_non_utf8_legacy_is_rc3(self):
        old = self.legacy()
        old.write_bytes(b"---\n\xff\xfe\n---\n")
        rc, _, err = run("migrate-legacy", "--session", SID, "--topic", "t", "--date", "2026-10-15", cwd=self.tmp)
        self.assertEqual(rc, 3)
        self.assertIn("옮기지 못했다", err)
        self.assertTrue(old.exists())
        self.assertFalse((self.iv / "2026-10-15-t-interview.state.md").exists())

    def test_migrate_readonly_dir_is_rc3(self):
        old = self.legacy()
        self.iv.chmod(0o500)
        try:
            if os.access(str(self.iv), os.W_OK):
                self.skipTest("권한이 막지 못한다(root)")
            rc, _, err = run("migrate-legacy", "--session", SID, "--topic", "t", "--date", "2026-10-15", cwd=self.tmp)
        finally:
            self.iv.chmod(0o700)
        self.assertEqual(rc, 3)
        self.assertTrue(old.exists())

    def test_migrate_without_legacy_is_rc1(self):
        rc, _, _ = run("migrate-legacy", "--session", SID, "--topic", "t", cwd=self.tmp)
        self.assertEqual(rc, 1)


class LinkTest(Base):
    def setUp(self):
        super().setUp()
        self.out = Path(tempfile.mkdtemp()).resolve()
        (self.out / "keep.txt").write_text("원본", encoding="utf-8")

    def tearDown(self):
        import shutil
        shutil.rmtree(self.out, ignore_errors=True)
        super().tearDown()

    def legacy(self):
        p = self.tmp / ".claude" / "spec-distill" / SID / "state.local.md"
        p.parent.mkdir(parents=True)
        p.write_text("---\nsession_id: x\n---\n기록\n", encoding="utf-8")
        return p

    def snapshot(self):
        return sorted(f.name for f in self.out.iterdir())

    def test_linked_interview_dir_refused(self):
        import shutil
        shutil.rmtree(self.iv)
        os.symlink(str(self.out), str(self.iv))
        before = self.snapshot()
        sp = Path(SCRIPT).with_name("state_path.py")
        cp = subprocess.run([sys.executable, str(sp), "interview-state", "--topic", "t",
                             "--date", "2026-10-15", "--cwd", str(self.tmp)],
                            capture_output=True, text=True, timeout=20)
        self.assertEqual(cp.returncode, 2)
        self.legacy()
        rc, _, _ = run("migrate-legacy", "--session", SID, "--topic", "t", "--date", "2026-10-15", cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertEqual(self.snapshot(), before)

    def test_planted_tmp_link_not_followed(self):
        old = self.legacy()
        os.symlink(str(self.out / "keep.txt"), str(self.iv / ".2026-10-15-t-interview.state.md.tmp"))
        rc, _, err = run("migrate-legacy", "--session", SID, "--topic", "t", "--date", "2026-10-15", cwd=self.tmp)
        self.assertEqual(rc, 3)
        self.assertEqual((self.out / "keep.txt").read_text(encoding="utf-8"), "원본")
        self.assertTrue(old.exists())

    def test_linked_sid_dir_refused(self):
        sd = self.tmp / ".claude" / "spec-distill"
        sd.mkdir(parents=True)
        (self.out / "state.local.md").write_text("---\nk: v\n---\n밖\n", encoding="utf-8")
        os.symlink(str(self.out), str(sd / SID))
        rc, _, _ = run("migrate-legacy", "--session", SID, "--topic", "t", "--date", "2026-10-15", cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertTrue((self.out / "state.local.md").exists())
        self.assertFalse((self.iv / "2026-10-15-t-interview.state.md").exists())

    def test_linked_legacy_refused(self):
        old = self.legacy()
        old.unlink()
        os.symlink(str(self.out / "keep.txt"), str(old))
        rc, _, _ = run("migrate-legacy", "--session", SID, "--topic", "t", "--date", "2026-10-15", cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertFalse((self.iv / "2026-10-15-t-interview.state.md").exists())


class SeedAuditTest(Base):
    def test_one_match(self):
        self.put("2026-10-15-t-interview.audit.md", "interview-seed-audit", "session_id: %s\n" % SID)
        rc, out, _ = run("seed-audit-for-session", "--session", SID, cwd=self.tmp)
        self.assertEqual((rc, out.strip()), (0, "2026-10-15-t-interview"))

    def test_interview_audit_of_same_session_is_ignored(self):
        self.put("2026-10-15-t-interview.audit.md", "interview-seed-audit", "session_id: %s\n" % SID)
        self.put("2026-10-15-t-brief-interview.audit.md", "interview-audit", "session_id: %s\n" % SID)
        rc, out, _ = run("seed-audit-for-session", "--session", SID, cwd=self.tmp)
        self.assertEqual((rc, out.strip()), (0, "2026-10-15-t-interview"))

    def test_none(self):
        rc, out, _ = run("seed-audit-for-session", "--session", SID, cwd=self.tmp)
        self.assertEqual((rc, out.strip()), (1, ""))

    def test_two_is_rc2(self):
        self.put("2026-10-15-a-interview.audit.md", "interview-seed-audit", "session_id: %s\n" % SID)
        self.put("2026-10-15-b-interview.audit.md", "interview-seed-audit", "session_id: %s\n" % SID)
        rc, _, err = run("seed-audit-for-session", "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertIn("2026-10-15-a-interview.audit.md", err)


if __name__ == "__main__":
    unittest.main()
