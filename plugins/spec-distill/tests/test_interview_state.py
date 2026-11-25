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
        self.iv = self.tmp / "docs" / "superpowers" / "interview"      # 옛 의도 폴더 — 옛 꼴 파일의 증인
        self.iv.mkdir(parents=True)
        self.new = self.tmp / "docs" / "superpowers" / "intent"        # 새 의도 폴더
        self.new.mkdir(parents=True)

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp, ignore_errors=True)

    def put(self, name, typ, extra="", where=None):
        p = (where or self.iv) / name
        p.write_text("---\ntype: %s\n%s---\nbody\n" % (typ, extra), encoding="utf-8")
        return p


class EntryTest(Base):
    def test_resume_on_state_file(self):
        p = self.put("2026-10-15-t-brief-interview.state.md", "interview-state", "seed: 없음\n")
        rc, out, _ = run("entry", "--arg", str(p), "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertEqual(last(out), "context-state: RESUME %s" % p)

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
        self.assertTrue(last(out_).startswith("context-state: REJECT %s (" % link), last(out_))

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
        self.assertTrue(last(out_).startswith("context-state: REJECT "), last(out_))

    def test_resume_refuses_state_file_outside_worktree(self):
        out = self._outside()
        p = out / "2026-10-15-x-interview.state.md"
        p.write_text("---\ntype: interview-state\nseed: 없음\n---\n밖\n", encoding="utf-8")
        rc, out_, _ = run("entry", "--arg", str(p), "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertTrue(last(out_).startswith("context-state: REJECT "), last(out_))

    def test_resume_through_linked_cwd_is_allowed(self):
        """양성 대조 — cwd 를 링크로 들어왔을 때(논리 경로 인자) 이어 간다. 출력은 물리 cwd 접두의 절대경로."""
        p = self.put("2026-10-15-t-brief-interview.state.md", "interview-state", "seed: 없음\n")
        lk = self._outside() / "lk"
        os.symlink(str(self.tmp), str(lk))
        arg = lk / p.relative_to(self.tmp)
        rc, out_, _ = run("entry", "--arg", str(arg), "--session", SID, cwd=str(lk), env_extra={"PWD": str(lk)})
        self.assertEqual(rc, 0, out_)
        self.assertEqual(last(out_), "context-state: RESUME %s" % p)

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
        self.assertEqual((rc, last(out)), (0, "context-state: RESUME %s" % st))

    def test_resume_refuses_linked_audit(self):
        st, _, victim = self._sibling_fixture()
        os.symlink(str(victim), str(self.iv / "2026-10-15-t-brief-interview.audit.md"))
        rc, out, _ = run("entry", "--arg", str(st), "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertTrue(last(out).startswith("context-state: REJECT %s (2026-10-15-t-brief-interview.audit.md: 링크를 거친다" % st),
                        last(out))
        self.assertEqual(victim.read_text(encoding="utf-8"), "원본\n")

    def test_resume_refuses_linked_brief(self):
        st, _, victim = self._sibling_fixture()
        os.symlink(str(victim), str(self.iv / "2026-10-15-t-brief-interview.md"))
        rc, out, _ = run("entry", "--arg", str(st), "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertTrue(last(out).startswith("context-state: REJECT %s (2026-10-15-t-brief-interview.md: 링크를 거친다" % st),
                        last(out))

    def test_resume_refuses_dangling_brief_link(self):
        st, out_dir, _ = self._sibling_fixture()
        os.symlink(str(out_dir / "not-yet.md"), str(self.iv / "2026-10-15-t-brief-interview.md"))
        rc, out, _ = run("entry", "--arg", str(st), "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertTrue(last(out).startswith("context-state: REJECT %s (2026-10-15-t-brief-interview.md: 링크를 거친다" % st),
                        last(out))
        self.assertFalse((out_dir / "not-yet.md").exists())

    def test_resume_refuses_finished_interview(self):
        st = self.put("2026-10-15-t-brief-interview.state.md", "interview-state", "seed: 없음\n")
        self.put("2026-10-15-t-brief-interview.md", "interview-brief")
        rc, out, _ = run("entry", "--arg", str(st), "--session", SID, cwd=self.tmp)
        self.assertEqual((rc, last(out)), (2, "context-state: REJECT %s (이미 끝난 컨텍스트 쌓기다 — brief 가 있다)" % st))

    def _candidate_with_sibling_link(self, name, target):
        seed = self.put("2026-10-15-t-interview.md", "interview-seed")
        st = self.put("2026-10-15-t-brief-interview.state.md", "interview-state",
                      "seed: docs/superpowers/interview/2026-10-15-t-interview.md\n")
        os.symlink(str(target), str(self.iv / name))
        rc, out, err = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertNotIn("candidate: %s" % st, out)
        self.assertTrue(last(out).startswith("context-state: NEW-SEED t-brief "), out)
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
        self.assertEqual((rc, last(out)), (0, "context-state: NEW-SEED t-brief seed=없음"))
        self.assertIn("seed 가 링크이거나 작업 트리 밖이다", err)
        self.assertNotIn("..", last(out))

    def test_reject_state_named_other_kind(self):
        p = self.put("2026-10-15-t-interview.state.md", "interview-seed")
        rc, out, _ = run("entry", "--arg", str(p), "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertTrue(last(out).startswith("context-state: REJECT "))

    def test_new_seed_topic_gets_brief_tail(self):
        seed = self.put("2026-10-15-t-interview.md", "interview-seed")
        rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertEqual(last(out), "context-state: NEW-SEED t-brief seed=docs/superpowers/interview/2026-10-15-t-interview.md")

    def test_seed_with_old_next_phase_values_still_enters(self):
        for old in ("spec-distill:spec-" "interview", "spec-distill:" "interview"):
            with self.subTest(old=old):
                seed = self.put("2026-10-15-t-interview.md", "interview-seed", "next_phase: %s\n" % old)
                rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
                self.assertEqual((rc, last(out)), (0, "context-state: NEW-SEED t-brief seed=docs/superpowers/interview/2026-10-15-t-interview.md"))

    def test_ask_when_unfinished_state_points_at_seed(self):
        seed = self.put("2026-10-15-t-interview.md", "interview-seed")
        st = self.put("2026-10-15-t-brief-interview.state.md", "interview-state",
                      "seed: docs/superpowers/interview/2026-10-15-t-interview.md\n")
        rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
        self.assertEqual(last(out), "context-state: ASK")
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
        self.assertEqual(last(out), "context-state: ASK")
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
        self.assertTrue(last(out).startswith("context-state: NEW-SEED t-brief "), out)

    def test_finished_state_is_not_a_candidate(self):
        seed = self.put("2026-10-15-t-interview.md", "interview-seed")
        self.put("2026-10-15-t-brief-interview.state.md", "interview-state",
                 "seed: docs/superpowers/interview/2026-10-15-t-interview.md\n")
        self.put("2026-10-15-t-brief-interview.md", "interview-brief")
        rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
        self.assertTrue(last(out).startswith("context-state: NEW-SEED "))

    def test_other_seed_state_is_not_a_candidate(self):
        seed = self.put("2026-10-15-t-interview.md", "interview-seed")
        self.put("2026-10-15-u-brief-interview.state.md", "interview-state",
                 "seed: docs/superpowers/interview/2026-10-14-u-interview.md\n")
        rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
        self.assertTrue(last(out).startswith("context-state: NEW-SEED "))

    def test_rough_request_is_new(self):
        rc, out, _ = run("entry", "--arg", "", "--session", SID, cwd=self.tmp)
        self.assertEqual((rc, last(out)), (0, "context-state: NEW"))

    def test_entry_accepts_old_and_new_state_kind(self):
        for kind, name in (("interview-state", "2026-10-15-t-brief-interview.state.md"),
                           ("context-state", "2026-10-15-t-brief-context.state.md")):
            with self.subTest(kind=kind):
                p = self.put(name, kind, "seed: 없음\n")
                rc, out, _ = run("entry", "--arg", str(p), "--session", SID, cwd=self.tmp)
                self.assertEqual((rc, last(out)), (0, "context-state: RESUME %s" % p))

    def test_entry_new_seed_topic_both_forms(self):
        for kind, name in (("intent-seed", "2026-10-15-ab-intent.md"), ("interview-seed", "2026-10-15-ab-interview.md")):
            with self.subTest(kind=kind):
                seed = self.put(name, kind, where=self.new)
                rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
                self.assertEqual((rc, last(out)),
                                 (0, "context-state: NEW-SEED ab-brief seed=docs/superpowers/intent/%s" % name))

    def test_resume_candidate_in_old_folder(self):
        """새 폴더의 seed 로 시작해도 옛 폴더에 같은 seed 의 옛 꼴 상태 파일이 있으면 후보다."""
        seed = self.put("2026-10-15-t-intent.md", "intent-seed", where=self.new)
        st = self.put("2026-10-15-t-brief-interview.state.md", "interview-state",
                      "seed: docs/superpowers/intent/2026-10-15-t-intent.md\n")
        rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
        self.assertEqual(last(out), "context-state: ASK")
        self.assertEqual([l for l in out.splitlines() if l.startswith("candidate: ")], ["candidate: %s" % st])

    def test_resume_candidates_both_forms_new_folder(self):
        seed = self.put("2026-10-15-t-intent.md", "intent-seed", where=self.new)
        want = "seed: docs/superpowers/intent/2026-10-15-t-intent.md\n"
        a = self.put("2026-10-15-t-brief-context.state.md", "context-state", want, where=self.new)
        b = self.put("2026-10-16-t-brief-interview.state.md", "interview-state", want, where=self.new)
        rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
        self.assertEqual(sorted(l for l in out.splitlines() if l.startswith("candidate: ")),
                         sorted(["candidate: %s" % a, "candidate: %s" % b]))

    def test_legacy_wins_over_seed(self):
        legacy = self.tmp / ".claude" / "spec-distill" / SID / "state.local.md"
        legacy.parent.mkdir(parents=True)
        legacy.write_text("---\nsession_id: x\n---\n## R1\n", encoding="utf-8")
        seed = self.put("2026-10-15-t-interview.md", "interview-seed")
        rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
        self.assertEqual(last(out), "context-state: LEGACY %s" % legacy)


class MigrateTest(Base):
    def legacy(self):
        p = self.tmp / ".claude" / "spec-distill" / SID / "state.local.md"
        p.parent.mkdir(parents=True)
        p.write_text("---\nsession_id: x\nphase: 1\n---\n## R1\n기록\n", encoding="utf-8")
        return p

    def test_migrate_moves_and_prepends_keys(self):
        old = self.legacy()
        rc, out, _ = run("migrate-legacy", "--session", SID, "--topic", "t", "--date", "2026-10-15", cwd=self.tmp)
        new = self.new / "2026-10-15-t-context.state.md"
        self.assertEqual(rc, 0)
        self.assertIn("옛 위치의 진행 기록을 docs 로 옮겼다 — %s" % new, out)
        self.assertFalse(old.exists())
        text = new.read_text(encoding="utf-8")
        self.assertTrue(text.startswith("---\ntype: context-state\nseed: 없음\nsession_id: x\n"))
        self.assertIn("## R1\n기록\n", text)

    def test_migrate_records_regular_seed(self):
        """양성 대조 — 작업 트리 안 보통 seed 는 상대경로로 적힌다."""
        self.legacy()
        seed = self.put("2026-10-15-t-interview.md", "interview-seed")
        rc, _, _ = run("migrate-legacy", "--session", SID, "--topic", "t-brief", "--date", "2026-10-15",
                       "--seed", str(seed), cwd=self.tmp)
        self.assertEqual(rc, 0)
        text = (self.new / "2026-10-15-t-brief-context.state.md").read_text(encoding="utf-8")
        self.assertTrue(text.startswith("---\ntype: context-state\nseed: docs/superpowers/interview/2026-10-15-t-interview.md\n"), text)

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
        text = (self.new / "2026-10-15-t-brief-context.state.md").read_text(encoding="utf-8")
        self.assertTrue(text.startswith("---\ntype: context-state\nseed: 없음\n"), text)
        self.assertIn("seed 가 링크이거나 작업 트리 밖이다", err)

    def test_migrate_refuses_existing_target(self):
        old = self.legacy()
        tgt = self.put("2026-10-15-t-context.state.md", "context-state", where=self.new)
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
        self.assertFalse((self.new / "2026-10-15-t-context.state.md").exists())

    def test_migrate_readonly_dir_is_rc3(self):
        old = self.legacy()
        self.new.chmod(0o500)
        try:
            if os.access(str(self.new), os.W_OK):
                self.skipTest("권한이 막지 못한다(root)")
            rc, _, err = run("migrate-legacy", "--session", SID, "--topic", "t", "--date", "2026-10-15", cwd=self.tmp)
        finally:
            self.new.chmod(0o700)
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
        shutil.rmtree(self.new)
        os.symlink(str(self.out), str(self.new))
        before = self.snapshot()
        sp = Path(SCRIPT).with_name("state_path.py")
        cp = subprocess.run([sys.executable, str(sp), "context-state", "--topic", "t",
                             "--date", "2026-10-15", "--cwd", str(self.tmp)],
                            capture_output=True, text=True, timeout=20)
        self.assertEqual(cp.returncode, 2)
        self.legacy()
        rc, _, _ = run("migrate-legacy", "--session", SID, "--topic", "t", "--date", "2026-10-15", cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertEqual(self.snapshot(), before)

    def test_planted_tmp_link_not_followed(self):
        old = self.legacy()
        os.symlink(str(self.out / "keep.txt"), str(self.new / ".2026-10-15-t-context.state.md.tmp"))
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
        self.assertFalse((self.new / "2026-10-15-t-context.state.md").exists())

    def test_linked_legacy_refused(self):
        old = self.legacy()
        old.unlink()
        os.symlink(str(self.out / "keep.txt"), str(old))
        rc, _, _ = run("migrate-legacy", "--session", SID, "--topic", "t", "--date", "2026-10-15", cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertFalse((self.new / "2026-10-15-t-context.state.md").exists())


class SeedAuditTest(Base):
    def put_audit(self, name, where=None, kind="intent-seed-audit"):
        return self.put(name, kind, "session_id: %s\n" % SID, where=where or self.new)

    def test_one_match(self):
        self.put_audit("2026-10-15-t-intent.audit.md")
        rc, out, _ = run("seed-audit-for-session", "--session", SID, cwd=self.tmp)
        self.assertEqual((rc, out.strip()), (0, "2026-10-15-t-intent"))

    def test_both_forms_in_new_folder_and_old_folder_is_not_searched(self):
        """새 폴더의 두 꼴을 각각 찾고, 다른 폴더(옛 폴더)의 것은 찾지 않는다."""
        self.put_audit("2026-10-15-t-interview.audit.md", kind="interview-seed-audit")
        rc, out, _ = run("seed-audit-for-session", "--session", SID, cwd=self.tmp)
        self.assertEqual((rc, out.strip()), (0, "2026-10-15-t-interview"))
        (self.new / "2026-10-15-t-interview.audit.md").unlink()
        self.put_audit("2026-10-15-t-interview.audit.md", where=self.iv, kind="interview-seed-audit")
        rc, out, _ = run("seed-audit-for-session", "--session", SID, cwd=self.tmp)
        self.assertEqual((rc, out.strip()), (1, ""))

    def test_context_audit_of_same_session_is_ignored(self):
        self.put_audit("2026-10-15-t-intent.audit.md")
        self.put("2026-10-15-t-brief-context.audit.md", "context-audit", "session_id: %s\n" % SID, where=self.new)
        rc, out, _ = run("seed-audit-for-session", "--session", SID, cwd=self.tmp)
        self.assertEqual((rc, out.strip()), (0, "2026-10-15-t-intent"))

    def test_none(self):
        rc, out, _ = run("seed-audit-for-session", "--session", SID, cwd=self.tmp)
        self.assertEqual((rc, out.strip()), (1, ""))

    def test_two_is_rc2(self):
        self.put_audit("2026-10-15-a-intent.audit.md")
        self.put_audit("2026-10-15-b-intent.audit.md")
        rc, _, err = run("seed-audit-for-session", "--session", SID, cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertIn("2026-10-15-a-intent.audit.md", err)

    def test_topic_other_than_session_audit_is_none(self):
        # 같은 세션에서 다른 주제로 다시 열면 옛 주제의 audit 이름을 내지 않는다 — 알리고 rc 1
        self.put_audit("2026-10-15-a-intent.audit.md")
        rc, out, err = run("seed-audit-for-session", "--session", SID, "--topic", "b", cwd=self.tmp)
        self.assertEqual((rc, out.strip()), (1, ""))
        self.assertIn("2026-10-15-a-intent.audit.md", err)

    def test_topic_picks_its_own_audit(self):
        self.put_audit("2026-10-15-a-intent.audit.md")
        self.put_audit("2026-10-16-b-interview.audit.md", kind="interview-seed-audit")
        rc, out, _ = run("seed-audit-for-session", "--session", SID, "--topic", "b", cwd=self.tmp)
        self.assertEqual((rc, out.strip()), (0, "2026-10-16-b-interview"))

    def test_topic_unknown_name_is_kept(self):
        # 날짜-주제 꼴이 아닌 이름은 주제를 모른다 — 다른 주제로 단정해 버리지 않는다
        self.put_audit("probe-x-intent.audit.md")
        rc, out, _ = run("seed-audit-for-session", "--session", SID, "--topic", "b", cwd=self.tmp)
        self.assertEqual((rc, out.strip()), (0, "probe-x-intent"))

    def test_topic_is_whole_segment_not_suffix(self):
        # 「a」 는 「x-a」 의 audit 이 아니다
        self.put_audit("2026-10-15-x-a-intent.audit.md")
        rc, out, _ = run("seed-audit-for-session", "--session", SID, "--topic", "a", cwd=self.tmp)
        self.assertEqual((rc, out.strip()), (1, ""))


STATE_PATH = SCRIPT.parent / "state_path.py"


class RepoSettingsTest(unittest.TestCase):
    """R8 — 의도 폴더는 기본 브랜치의 레포 설정(`intent_dir`)이다. 두 갈래 상태 경로 · 이월 · seed audit 되찾기가 모두 그 폴더를 지난다."""

    def setUp(self):
        import shutil
        base = Path(tempfile.mkdtemp()).resolve()
        self.addCleanup(shutil.rmtree, str(base), True)
        self.repo = base / "work"
        remote = base / "remote.git"
        self.git = lambda *a, cwd=None: subprocess.run(
            ["git", "-c", "user.name=t", "-c", "user.email=t@example.invalid", "-c", "commit.gpgsign=false", *a],
            cwd=str(cwd or self.repo), check=True, capture_output=True)
        subprocess.run(["git", "init", "-q", "--bare", "-b", "trunk", str(remote)], check=True)
        subprocess.run(["git", "init", "-q", "-b", "trunk", str(self.repo)], check=True)
        self.git("remote", "add", "origin", str(remote))
        self.settle("---\nintent_dir: notes/\n---\n")
        self.iv = self.repo / "notes"
        self.iv.mkdir()
        self.default_iv = self.repo / "docs" / "superpowers" / "intent"
        self.default_iv.mkdir(parents=True)

    def settle(self, text):
        (self.repo / ".devbrew.md").write_text(text, encoding="utf-8")
        self.git("add", "--", ".devbrew.md")
        self.git("commit", "-qm", "settings")
        self.git("push", "-q", "origin", "trunk")
        self.git("remote", "set-head", "origin", "--auto")

    def state(self, *extra):
        cp = subprocess.run([sys.executable, str(STATE_PATH), "context-state", "--topic", "t", "--date", "2026-10-15",
                             "--cwd", str(self.repo), *extra], capture_output=True, text=True, timeout=20)
        return cp.returncode, cp.stdout.strip(), cp.stderr

    def test_state_path_uses_intent_dir(self):
        self.assertEqual(self.state()[:2], (0, str(self.iv / "2026-10-15-t-context.state.md")))

    def test_finished_branch_uses_intent_dir(self):
        (self.iv / "2026-10-15-t-context.md").write_text("---\ntype: context-brief\n---\n", encoding="utf-8")
        self.assertEqual(self.state("--time", "1230")[:2], (0, str(self.iv / "2026-10-15-t-1230-context.state.md")))

    def test_brief_in_default_folder_does_not_shift(self):
        """음의 짝 — 기본 폴더의 끝난 일은 이 레포의 컨텍스트 쌓기가 아니다."""
        (self.default_iv / "2026-10-15-t-context.md").write_text("---\ntype: context-brief\n---\n", encoding="utf-8")
        self.assertEqual(self.state("--time", "1230")[:2], (0, str(self.iv / "2026-10-15-t-context.state.md")))

    def test_migrate_writes_into_intent_dir(self):
        old = self.repo / ".claude" / "spec-distill" / SID / "state.local.md"
        old.parent.mkdir(parents=True)
        old.write_text("---\nsession_id: x\n---\n## R1\n", encoding="utf-8")
        rc, _, _ = run("migrate-legacy", "--session", SID, "--topic", "t", "--date", "2026-10-15", cwd=self.repo)
        self.assertEqual(rc, 0)
        self.assertTrue((self.iv / "2026-10-15-t-context.state.md").is_file())

    def test_seed_audit_found_in_intent_dir(self):
        for d, name in ((self.iv, "2026-10-15-t-intent.audit.md"), (self.default_iv, "2026-10-15-u-intent.audit.md")):
            (d / name).write_text("---\ntype: intent-seed-audit\nsession_id: %s\n---\n" % SID, encoding="utf-8")
        rc, out, _ = run("seed-audit-for-session", "--session", SID, cwd=self.repo)
        self.assertEqual((rc, out.strip()), (0, "2026-10-15-t-intent"))

    def test_resume_candidates_dedup_same_folder(self):
        """옛 키만 있어 두 폴더가 같다 — 같은 후보가 한 번만."""
        self.settle("---\ninterview_dir: notes/\n---\n")
        seed = self.iv / "2026-10-15-t-interview.md"
        seed.write_text("---\ntype: interview-seed\n---\n", encoding="utf-8")
        st = self.iv / "2026-10-15-t-brief-interview.state.md"
        st.write_text("---\ntype: interview-state\nseed: notes/2026-10-15-t-interview.md\n---\n", encoding="utf-8")
        rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.repo)
        self.assertEqual(last(out), "context-state: ASK")
        self.assertEqual([l for l in out.splitlines() if l.startswith("candidate: ")], ["candidate: %s" % st])

    def test_candidate_in_old_folder_when_keys_differ(self):
        self.settle("---\nintent_dir: notes/\ninterview_dir: oldnotes/\n---\n")
        old = self.repo / "oldnotes"
        old.mkdir()
        seed = self.iv / "2026-10-15-t-intent.md"
        seed.write_text("---\ntype: intent-seed\n---\n", encoding="utf-8")
        st = old / "2026-10-15-t-brief-interview.state.md"
        st.write_text("---\ntype: interview-state\nseed: notes/2026-10-15-t-intent.md\n---\n", encoding="utf-8")
        rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.repo)
        self.assertEqual(last(out), "context-state: ASK")
        self.assertIn("candidate: %s" % st, out)

    def test_broken_settings_refuse(self):
        self.settle("---\nintent_dir: /abs/\n---\n")
        rc, out, err = self.state()
        self.assertEqual((rc, out), (2, ""))
        self.assertIn("의도 폴더를 정하지 못했다", err)
        rc, out, err = run("seed-audit-for-session", "--session", SID, cwd=self.repo)
        self.assertEqual((rc, out.strip()), (3, ""))
        self.assertIn("의도 폴더를 정하지 못했다", err)


if __name__ == "__main__":
    unittest.main()
