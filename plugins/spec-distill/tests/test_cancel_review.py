"""spec-distill cancel-review + suppress_state contract (v0.14.0).

TestSuppressState: 단일 소스 헬퍼 직접 import 단위 (AC4/AC11/AC14/AC17).
TestCancelReview: cancel_review.py subprocess 통합 (AC1–AC8, AC19).

실행 (repo root):
  python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_cancel_review.py'
"""
from __future__ import annotations  # str | None 시그니처가 py3.9에서도 동작

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = (Path(__file__).resolve().parent.parent / "scripts").resolve()
HOOKS = (Path(__file__).resolve().parent.parent / "hooks").resolve()
CANCEL = SCRIPTS / "cancel_review.py"
sys.path.insert(0, str(SCRIPTS))
sys.path.insert(0, str(HOOKS))
import suppress_state  # noqa: E402 # pyright: ignore[reportMissingImports]

PREFIX = "docs/superpowers/specs/"
DOC_A = PREFIX + "2026-01-01-doc-a-design.md"
DOC_B = PREFIX + "2026-01-01-doc-b-design.md"


class TestSuppressState(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.sf = self.tmp / "sid12345" / "state.local.md"

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_canonical_key_strips_prefix(self):
        self.assertEqual(suppress_state.canonical_key("/abs/wt/" + DOC_A), DOC_A)
        self.assertEqual(suppress_state.canonical_key(DOC_A), DOC_A)

    def test_canonical_key_out_of_scope_none(self):
        self.assertIsNone(suppress_state.canonical_key("/x/README.md"))
        self.assertIsNone(suppress_state.canonical_key(""))

    def test_add_idempotent_single_entry(self):  # AC4
        suppress_state.add(self.sf, "/wt/" + DOC_A)
        suppress_state.add(self.sf, DOC_A)
        self.assertEqual(
            suppress_state.suppressed_keys(self.sf.read_text()), [DOC_A]
        )

    def test_remove(self):
        suppress_state.add(self.sf, DOC_A)
        suppress_state.remove(self.sf, DOC_A)
        self.assertEqual(suppress_state.suppressed_keys(self.sf.read_text()), [])

    def test_is_suppressed(self):
        self.assertFalse(suppress_state.is_suppressed(self.sf, DOC_A))
        suppress_state.add(self.sf, DOC_A)
        self.assertTrue(suppress_state.is_suppressed(self.sf, "/wt/" + DOC_A))

    def test_strip_pending_preserves_suppressed(self):  # AC14 / C3
        body = (
            "---\nsession_id: s\n---\n\n"
            "pending_review:\n  path: " + DOC_A + "\n  mode: design\n"
            "  worktree_path: /x\n  triggered_at: t\n\n"
            "suppressed_paths:\n  - " + DOC_B + "\n"
        )
        self.assertEqual(suppress_state.pending_path(body), DOC_A)
        self.assertIn(DOC_B, suppress_state.suppressed_keys(body))
        stripped = suppress_state.strip_pending(body)
        self.assertNotIn("pending_review:", stripped)
        self.assertIn("suppressed_paths:", stripped)
        self.assertIn(DOC_B, stripped)

    def test_suppress_path_same_key_strips_pending(self):  # AC1 core
        self.sf.parent.mkdir(parents=True)
        self.sf.write_text(
            "---\nsession_id: sid12345\n---\n\n"
            "pending_review:\n  path: /wt/" + DOC_A + "\n  mode: design\n"
            "  worktree_path: /wt\n  triggered_at: t\n"
        )
        suppress_state.suppress_path(self.sf, "/wt/" + DOC_A)
        body = self.sf.read_text()
        self.assertNotIn("pending_review:", body)
        self.assertEqual(suppress_state.suppressed_keys(body), [DOC_A])

    def test_suppress_path_different_key_preserves_pending(self):  # AC19 unit
        self.sf.parent.mkdir(parents=True)
        self.sf.write_text(
            "---\nsession_id: sid12345\n---\n\n"
            "pending_review:\n  path: /wt/" + DOC_A + "\n  mode: design\n"
            "  worktree_path: /wt\n  triggered_at: t\n"
        )
        suppress_state.suppress_path(self.sf, "/wt/" + DOC_B)
        body = self.sf.read_text()
        self.assertIn("pending_review:", body)
        self.assertEqual(suppress_state.pending_path(body), "/wt/" + DOC_A)
        self.assertEqual(suppress_state.suppressed_keys(body), [DOC_B])

    def test_no_prefix_slice_outside_suppress_state(self):  # AC17
        root = Path(__file__).resolve().parent.parent
        for rel in ("scripts/cancel_review.py", "scripts/approve_handoff.sh"):
            txt = (root / rel).read_text()
            self.assertNotIn(
                "docs/superpowers/specs/", txt,
                f"{rel} must delegate normalization to suppress_state (AC17)",
            )


def run_cancel(args, env_extra=None, cwd=None, sid: str | None = "tsid1234"):
    env = {**os.environ}
    for k in ("DEVBREW_DISABLE_SPEC_DISTILL", "CLAUDE_CODE_SESSION_ID",
              "DEVBREW_SPEC_DISTILL_SESSION_ID"):
        env.pop(k, None)
    if sid is not None:
        env["DEVBREW_SPEC_DISTILL_SESSION_ID"] = sid
    if env_extra:
        env.update(env_extra)
    return subprocess.run(
        ["python3", str(CANCEL)] + args,
        env=env, cwd=cwd, capture_output=True, text=True, timeout=10,
    )


class TestCancelReview(unittest.TestCase):
    SID = "tsid1234"

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        subprocess.run(["git", "init", "-q"], cwd=self.tmp, check=True)
        self.sf = self.tmp / ".claude" / "spec-distill" / self.SID / "state.local.md"

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _seed_pending(self, doc_raw):
        self.sf.parent.mkdir(parents=True, exist_ok=True)
        self.sf.write_text(
            f"---\nsession_id: {self.SID}\n---\n\n"
            f"pending_review:\n  path: {doc_raw}\n  mode: design\n"
            f"  worktree_path: {self.tmp}\n  triggered_at: t\n"
        )

    def test_ac1_cancel_current_pending(self):
        doc = str(self.tmp / DOC_A)
        self._seed_pending(doc)
        cp = run_cancel([], cwd=self.tmp)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        body = self.sf.read_text()
        self.assertNotIn("pending_review:", body)
        self.assertEqual(suppress_state.suppressed_keys(body), [DOC_A])

    def test_ac2_explicit_path_no_pending_creates(self):
        self.assertFalse(self.sf.exists())
        cp = run_cancel([str(self.tmp / DOC_A)], cwd=self.tmp)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        body = self.sf.read_text()
        self.assertEqual(suppress_state.suppressed_keys(body), [DOC_A])
        self.assertNotIn("pending_review:", body)

    def test_ac3_no_pending_no_args_advisory(self):
        cp = run_cancel([], cwd=self.tmp)
        self.assertEqual(cp.returncode, 0)
        self.assertIn("nothing to do", cp.stderr)
        self.assertFalse(self.sf.exists())

    def test_ac4_idempotent(self):
        doc = str(self.tmp / DOC_A)
        run_cancel([doc], cwd=self.tmp)
        run_cancel([doc], cwd=self.tmp)
        self.assertEqual(
            suppress_state.suppressed_keys(self.sf.read_text()), [DOC_A]
        )

    def test_ac5_reset_removes(self):
        doc = str(self.tmp / DOC_A)
        run_cancel([doc], cwd=self.tmp)
        cp = run_cancel(["--reset", doc], cwd=self.tmp)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        self.assertEqual(suppress_state.suppressed_keys(self.sf.read_text()), [])
        cp2 = run_cancel(["--reset", str(self.tmp / DOC_B)], cwd=self.tmp)
        self.assertEqual(cp2.returncode, 0)  # absent-key reset → no-op

    def test_ac6_killswitch(self):
        doc = str(self.tmp / DOC_A)
        self._seed_pending(doc)
        cp = run_cancel(
            [], env_extra={"DEVBREW_DISABLE_SPEC_DISTILL": "1"}, cwd=self.tmp
        )
        self.assertEqual(cp.returncode, 0)
        self.assertIn("no-op", cp.stderr)
        self.assertIn("pending_review:", self.sf.read_text())

    def test_ac7_sid_unresolved(self):
        cp = run_cancel([], cwd=self.tmp, sid=None)
        self.assertEqual(cp.returncode, 1)
        self.assertIn("session_id", cp.stderr)
        self.assertFalse(self.sf.exists())

    def test_ac8_out_of_scope(self):
        cp = run_cancel([str(self.tmp / "README.md")], cwd=self.tmp)
        self.assertEqual(cp.returncode, 1)
        self.assertIn("스코프 밖", cp.stderr)
        self.assertFalse(self.sf.exists())

    def test_ac19_different_doc_pending_preserved(self):
        doc_a = str(self.tmp / DOC_A)
        doc_b = str(self.tmp / DOC_B)
        self._seed_pending(doc_a)
        cp = run_cancel([doc_b], cwd=self.tmp)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        body = self.sf.read_text()
        self.assertIn("pending_review:", body)
        self.assertEqual(suppress_state.pending_path(body), doc_a)
        self.assertEqual(suppress_state.suppressed_keys(body), [DOC_B])

    def _seed_lock(self, key_a, key_b):
        from datetime import datetime, timezone
        now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        self.sf.parent.mkdir(parents=True, exist_ok=True)
        self.sf.write_text(
            f"---\nsession_id: {self.SID}\n---\n\n"
            f"review_in_progress:\n"
            f"  - path: {key_a}\n    since: {now}\n"
            f"  - path: {key_b}\n    since: {now}\n"
        )

    def test_ac11_cancel_clears_lock_entry_preserves_other(self):
        self._seed_lock(DOC_A, DOC_B)
        cp = run_cancel([str(self.tmp / DOC_A)], cwd=self.tmp)
        self.assertEqual(cp.returncode, 0, cp.stderr)
        import review_lock  # noqa: E402 # pyright: ignore[reportMissingImports]
        body = self.sf.read_text()
        entries = dict(review_lock._parse_entries(body))
        self.assertNotIn(DOC_A, entries)   # 취소 문서 락 제거
        self.assertIn(DOC_B, entries)      # 다른 문서 락 불변(AC11)


if __name__ == "__main__":
    unittest.main()
