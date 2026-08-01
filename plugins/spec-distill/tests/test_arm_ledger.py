#!/usr/bin/env python3
"""arm_ledger 단위 테스트 (v0.25.0) — §5.1 판정 · §5.2 기록 시점 · G6 상한."""
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PLUGIN_ROOT / "hooks"))
sys.path.insert(0, str(PLUGIN_ROOT / "scripts"))
import arm_ledger  # noqa: E402

SPEC = "docs/superpowers/specs/2026-08-01-x-design.md"
OTHER = "docs/superpowers/specs/2026-08-01-y-design.md"
HEAD = "---\nsession_id: test-sid\n---\n\n"


def _make_repo() -> Path:
    repo = Path(tempfile.mkdtemp(prefix="armledger-")).resolve()
    subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.email", "t@t.t"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.name", "t"], cwd=repo, check=True)
    return repo


class TestCanonicalKey(unittest.TestCase):
    def test_absolute_worktree_and_relative_map_to_same_key(self):
        self.assertEqual(arm_ledger.canonical_key(f"/a/b/{SPEC}"), SPEC)
        self.assertEqual(arm_ledger.canonical_key(SPEC), SPEC)
        self.assertEqual(
            arm_ledger.canonical_key(f"/r/.claude/worktrees/wt/{SPEC}"), SPEC)

    def test_out_of_scope_is_none(self):
        self.assertIsNone(arm_ledger.canonical_key("/tmp/x-design.md"))
        self.assertIsNone(arm_ledger.canonical_key(""))


class TestLedgerBody(unittest.TestCase):
    def test_mark_armed_is_idempotent(self):
        body = arm_ledger.mark_armed(HEAD, f"/w/{SPEC}")
        body2 = arm_ledger.mark_armed(body, SPEC)
        self.assertEqual(arm_ledger.armed_keys(body2), [SPEC])

    def test_mark_armed_out_of_scope_is_noop(self):
        self.assertEqual(arm_ledger.mark_armed(HEAD, "/tmp/z.md"), HEAD)

    def test_attempts_roundtrip(self):
        body = arm_ledger.record_attempt(HEAD, SPEC, 2)
        self.assertEqual(arm_ledger.attempts(body), {SPEC: 2})

    def test_record_attempt_below_cap_does_not_arm(self):
        body = arm_ledger.record_attempt(HEAD, SPEC, 1)
        body = arm_ledger.record_attempt(body, SPEC, 2)
        self.assertEqual(arm_ledger.armed_keys(body), [])
        self.assertEqual(arm_ledger.attempts(body), {SPEC: 2})

    def test_record_attempt_at_cap_arms(self):
        body = arm_ledger.record_attempt(HEAD, SPEC, arm_ledger.DISPATCH_ATTEMPT_CAP)
        self.assertEqual(arm_ledger.armed_keys(body), [SPEC])
        self.assertEqual(arm_ledger.attempts(body)[SPEC],
                         arm_ledger.DISPATCH_ATTEMPT_CAP)

    def test_next_attempt_counts_from_zero_and_ignores_out_of_scope(self):
        self.assertEqual(arm_ledger.next_attempt(HEAD, SPEC), 1)
        body = arm_ledger.record_attempt(HEAD, SPEC, 2)
        self.assertEqual(arm_ledger.next_attempt(body, SPEC), 3)
        self.assertEqual(arm_ledger.next_attempt(body, "/tmp/z.md"), 0)

    def test_other_document_entries_survive(self):
        body = arm_ledger.record_attempt(HEAD, OTHER, 1)
        body = arm_ledger.mark_armed(body, SPEC)
        self.assertEqual(arm_ledger.armed_keys(body), [SPEC])
        self.assertEqual(arm_ledger.attempts(body), {OTHER: 1})

    def test_strip_pending_preserves_ledger_blocks(self):
        body = arm_ledger.mark_armed(HEAD, SPEC)
        body = body.rstrip() + (
            f"\n\npending_review:\n  path: {SPEC}\n  mode: design\n"
            "  triggered_at: 2026-08-01T00:00:00Z\n")
        stripped = arm_ledger.strip_pending(body)
        self.assertNotIn("pending_review:", stripped)
        self.assertEqual(arm_ledger.armed_keys(stripped), [SPEC])


class TestIsBorn(unittest.TestCase):
    def setUp(self):
        self.repo = _make_repo()
        self.cwd = os.getcwd()
        os.chdir(self.repo)
        (self.repo / "docs/superpowers/specs").mkdir(parents=True)

    def tearDown(self):
        os.chdir(self.cwd)
        shutil.rmtree(self.repo, ignore_errors=True)

    def test_tracked_document_is_born(self):
        (self.repo / SPEC).write_text("x\n", encoding="utf-8")
        subprocess.run(["git", "add", SPEC], cwd=self.repo, check=True)
        subprocess.run(["git", "commit", "-qm", "b"], cwd=self.repo, check=True)
        self.assertTrue(arm_ledger.is_born(SPEC))

    def test_staged_only_document_is_born(self):
        (self.repo / SPEC).write_text("x\n", encoding="utf-8")
        subprocess.run(["git", "add", SPEC], cwd=self.repo, check=True)
        self.assertTrue(arm_ledger.is_born(SPEC))

    def test_untracked_document_is_not_born(self):
        (self.repo / SPEC).write_text("x\n", encoding="utf-8")
        self.assertFalse(arm_ledger.is_born(SPEC))

    def test_dangling_path_is_not_born_and_does_not_raise(self):
        self.assertFalse(arm_ledger.is_born(SPEC))

    def test_outside_repo_falls_open_to_not_born(self):
        outside = Path(tempfile.mkdtemp(prefix="armledger-norepo-")).resolve()
        try:
            os.chdir(outside)
            self.assertFalse(arm_ledger.is_born(str(outside / SPEC)))
        finally:
            os.chdir(self.repo)
            shutil.rmtree(outside, ignore_errors=True)


class TestShouldArmAndSkipReason(unittest.TestCase):
    def setUp(self):
        self.repo = _make_repo()
        self.cwd = os.getcwd()
        os.chdir(self.repo)
        (self.repo / "docs/superpowers/specs").mkdir(parents=True)
        (self.repo / SPEC).write_text("x\n", encoding="utf-8")
        self.state = self.repo / "state.local.md"
        self.state.write_text(HEAD, encoding="utf-8")

    def tearDown(self):
        os.chdir(self.cwd)
        shutil.rmtree(self.repo, ignore_errors=True)

    def _commit(self):
        subprocess.run(["git", "add", SPEC], cwd=self.repo, check=True)
        subprocess.run(["git", "commit", "-qm", "b"], cwd=self.repo, check=True)

    def test_fresh_untracked_document_arms(self):
        self.assertTrue(arm_ledger.should_arm(self.state, SPEC))

    def test_ledger_entry_blocks_arm(self):
        self.state.write_text(arm_ledger.mark_armed(HEAD, SPEC), encoding="utf-8")
        self.assertFalse(arm_ledger.should_arm(self.state, SPEC))
        self.assertEqual(arm_ledger.skip_reason(self.state, SPEC), "reviewed")

    def test_git_tracked_blocks_arm_even_with_empty_ledger(self):
        self._commit()
        self.assertEqual(arm_ledger.armed_keys(self.state.read_text()), [])
        self.assertFalse(arm_ledger.should_arm(self.state, SPEC))
        self.assertEqual(arm_ledger.skip_reason(self.state, SPEC), "born")

    def test_cap_reached_reports_capped_not_reviewed(self):
        body = arm_ledger.record_attempt(HEAD, SPEC, arm_ledger.DISPATCH_ATTEMPT_CAP)
        self.state.write_text(body, encoding="utf-8")
        self.assertFalse(arm_ledger.should_arm(self.state, SPEC))
        self.assertEqual(arm_ledger.skip_reason(self.state, SPEC), "capped")

    def test_missing_state_file_falls_open_to_arm(self):
        self.state.unlink()
        self.assertTrue(arm_ledger.should_arm(self.state, SPEC))


class TestFileLevelWrites(unittest.TestCase):
    def setUp(self):
        self.repo = _make_repo()
        self.cwd = os.getcwd()
        os.chdir(self.repo)
        self.state = self.repo / "state.local.md"

    def tearDown(self):
        os.chdir(self.cwd)
        shutil.rmtree(self.repo, ignore_errors=True)

    def test_mark_reviewed_arms_and_clears_attempts(self):
        self.state.write_text(
            arm_ledger.record_attempt(HEAD, SPEC, 2), encoding="utf-8")
        self.assertTrue(arm_ledger.mark_reviewed(self.state, SPEC))
        body = self.state.read_text(encoding="utf-8")
        self.assertEqual(arm_ledger.armed_keys(body), [SPEC])
        self.assertNotIn(SPEC, arm_ledger.attempts(body))

    def test_mark_reviewed_out_of_scope_returns_false(self):
        self.state.write_text(HEAD, encoding="utf-8")
        self.assertFalse(arm_ledger.mark_reviewed(self.state, "/tmp/z.md"))

    def test_strip_pending_file_only_touches_same_key(self):
        body = HEAD + (
            f"pending_review:\n  path: {OTHER}\n  mode: design\n"
            "  triggered_at: 2026-08-01T00:00:00Z\n")
        self.state.write_text(body, encoding="utf-8")
        self.assertFalse(arm_ledger.strip_pending_file(self.state, SPEC))
        self.assertIn("pending_review:", self.state.read_text(encoding="utf-8"))
        self.assertTrue(arm_ledger.strip_pending_file(self.state, OTHER))
        self.assertNotIn("pending_review:", self.state.read_text(encoding="utf-8"))

    def test_strip_pending_file_does_not_touch_ledger(self):
        body = arm_ledger.mark_armed(HEAD, OTHER).rstrip() + (
            f"\n\npending_review:\n  path: {SPEC}\n  mode: design\n"
            "  triggered_at: 2026-08-01T00:00:00Z\n")
        self.state.write_text(body, encoding="utf-8")
        arm_ledger.strip_pending_file(self.state, SPEC)
        self.assertEqual(
            arm_ledger.armed_keys(self.state.read_text(encoding="utf-8")), [OTHER])


if __name__ == "__main__":
    unittest.main()
