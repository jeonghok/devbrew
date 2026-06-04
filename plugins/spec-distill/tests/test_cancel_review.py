"""spec-distill cancel-review + suppress_state contract (v0.14.0).

TestSuppressState: 단일 소스 헬퍼 직접 import 단위 (AC4/AC11/AC14/AC17).
TestCancelReview: cancel_review.py subprocess 통합 (AC1–AC8, AC19).

실행 (repo root):
  python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_cancel_review.py'
"""
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
import suppress_state  # noqa: E402

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
