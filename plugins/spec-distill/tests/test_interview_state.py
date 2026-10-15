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

    def test_migrate_refuses_existing_target(self):
        old = self.legacy()
        tgt = self.put("2026-10-15-t-interview.state.md", "interview-state")
        before = tgt.read_bytes()
        rc, _, err = run("migrate-legacy", "--session", SID, "--topic", "t", "--date", "2026-10-15", cwd=self.tmp)
        self.assertEqual(rc, 2)
        self.assertTrue(old.exists())
        self.assertEqual(tgt.read_bytes(), before)

    def test_migrate_without_legacy_is_rc1(self):
        rc, _, _ = run("migrate-legacy", "--session", SID, "--topic", "t", cwd=self.tmp)
        self.assertEqual(rc, 1)


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
