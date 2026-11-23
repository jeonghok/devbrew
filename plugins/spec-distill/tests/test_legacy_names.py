"""legacy_names 의 새 글자 · 옛 글자 대응. Run: python3 test_legacy_names.py"""
from __future__ import annotations
import sys
import unittest
from pathlib import Path

_SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
if str(_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS))

import legacy_names as L  # noqa: E402


class LegacyNames(unittest.TestCase):
    def test_kind_pairs(self):
        pairs = {"intent-seed": "interview-seed", "intent-seed-audit": "interview-seed-audit",
                 "context-state": "interview-state", "context-brief": "interview-brief",
                 "context-audit": "interview-audit"}
        self.assertEqual(L.OLD_KIND, pairs)
        for new, old in pairs.items():
            self.assertTrue(L.kind_matches(new, new))
            self.assertTrue(L.kind_matches(old, new))
            self.assertEqual(L.kinds(new), (new, old))

    def test_kind_does_not_cross(self):
        self.assertFalse(L.kind_matches("interview-seed", "context-brief"))
        self.assertFalse(L.kind_matches("interview-seed", "intent-seed-audit"))
        self.assertFalse(L.kind_matches(None, "context-brief"))
        self.assertFalse(L.kind_matches("", "context-brief"))

    def test_source_of(self):
        self.assertEqual(L.source_of({"source_intent": "a.md"}), "a.md")
        self.assertEqual(L.source_of({"source_interview": "b.md"}), "b.md")
        self.assertEqual(L.source_of({"source_intent": "a.md", "source_interview": "b.md"}), "a.md")
        self.assertEqual(L.source_of({"source_intent": "", "source_interview": "b.md"}), "b.md")
        self.assertEqual(L.source_of({}), "")

    def test_names(self):
        self.assertTrue(L.is_old_name("2026-01-01-x-interview.md"))
        self.assertTrue(L.is_old_name("2026-01-01-x-interview.state.md"))
        self.assertTrue(L.is_old_name("2026-01-01-x-interview.audit.md"))
        self.assertFalse(L.is_old_name("2026-01-01-x-context.md"))
        self.assertFalse(L.is_old_name("notes.md"))
        self.assertEqual(L.seed_topic("2026-01-01-ab-cd-intent.md"), "ab-cd")
        self.assertEqual(L.seed_topic("2026-01-01-ab-cd-interview.md"), "ab-cd")
        self.assertIsNone(L.seed_topic("2026-01-01-ab-cd-context.md"))
        self.assertEqual(L.seed_audit_topic("2026-01-01-ab-intent.audit.md"), "ab")
        self.assertEqual(L.seed_audit_topic("2026-01-01-ab-interview.audit.md"), "ab")
        self.assertEqual(L.roadmap_folder_name("2026-01-01-ab-brief-context.md"), "2026-01-01-ab-brief")
        self.assertEqual(L.roadmap_folder_name("2026-01-01-ab-interview.md"), "2026-01-01-ab")
        self.assertIsNone(L.roadmap_folder_name("2026-01-01-ab.md"))
        self.assertEqual(L.state_suffixes(), ("-context.state.md", "-interview.state.md"))

    def test_siblings(self):
        self.assertEqual(L.siblings("/r/d/x-context.md"), ("/r/d/x-context.audit.md", "/r/d/x-context.state.md"))
        self.assertEqual(L.siblings("/r/d/x-interview.md"), ("/r/d/x-interview.audit.md", "/r/d/x-interview.state.md"))
        with self.assertRaises(ValueError):
            L.siblings("/r/d/x.txt")

    def test_constants(self):
        self.assertEqual((L.SETTING_KEY, L.OLD_SETTING_KEY), ("intent_dir", "interview_dir"))
        self.assertEqual((L.DEFAULT_DIR, L.OLD_DEFAULT_DIR), ("docs/superpowers/intent/", "docs/superpowers/interview/"))
        self.assertEqual(L.head_keys(), ("source_intent", "source_interview"))
        self.assertEqual((L.INTENT_SEED, L.INTENT_SEED_AUDIT), ("intent-seed", "intent-seed-audit"))
        self.assertEqual((L.CONTEXT_STATE, L.CONTEXT_BRIEF, L.CONTEXT_AUDIT),
                         ("context-state", "context-brief", "context-audit"))
        self.assertEqual((L.SEED_TAIL, L.CONTEXT_TAIL, L.OLD_TAIL), ("-intent", "-context", "-interview"))

    def test_setting_notice(self):
        self.assertIn("값(docs/x/)을 그대로 읽는다", L.setting_notice("docs/x/", None))
        both = L.setting_notice("docs/x/", "docs/y/")
        self.assertIn("intent_dir(docs/y/)에 새 기록을 쓰고", both)
        self.assertIn("interview_dir(docs/x/)는 옛 기록을 읽는 폴더로만", both)


if __name__ == "__main__":
    unittest.main()
