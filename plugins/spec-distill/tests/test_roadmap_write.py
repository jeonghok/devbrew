#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_write.py 의 판정 · 되돌리기 · 생성 기록(R4 AC5 · AC10).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_roadmap_write.py
"""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "plugins" / "spec-distill" / "scripts"))
import roadmap_write as W  # noqa: E402


def report(**over):
    base = {"format_errors": [], "unassigned": [], "orphans": [], "unknown_ids": [], "unknown_reasons": []}
    base.update(over)
    return json.dumps(base, ensure_ascii=False)


class Judge(unittest.TestCase):
    def test_pass(self):
        self.assertEqual(W.judge(report(), 3), [])  # rc 는 보지 않는다(origin/main 없음 3 · 경고 1)

    def test_each_list(self):
        for key in W.LISTS:
            with self.subTest(key):
                reasons = W.judge(report(**{key: ["X1"]}), 0)
                self.assertEqual(len(reasons), 1)
                self.assertIn(key, reasons[0])
                self.assertIn("X1", reasons[0])

    def test_uncountable(self):
        reasons = W.judge(report(unassigned=None, unknown_reasons=["번호 전체 집합을 셀 수 없다"]), 3)
        self.assertTrue(any("셀 수 없음" in r and "unassigned" in r for r in reasons))
        missing = json.loads(report())
        del missing["orphans"]
        self.assertTrue(any("orphans" in r for r in W.judge(json.dumps(missing), 0)))

    def test_unreadable(self):
        for out in ("", "not json", "[]", "null"):
            with self.subTest(out):
                self.assertTrue(any("읽지 못했다" in r for r in W.judge(out, 3)))


class Transaction(unittest.TestCase):
    def test_rollback_restores_bytes(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            kept, gone, new = d / "kept.md", d / "gone.md", d / "sub" / "new.md"
            kept.write_bytes("원래\n".encode("utf-8"))
            gone.write_bytes(b"gone\n")
            txn = W.Txn()
            txn.write(kept, "바뀜\n")
            txn.write(kept, "두 번 바뀜\n")
            txn.remove(gone)
            txn.ensure_dir(new.parent)
            txn.write(new, "새 파일\n")
            self.assertEqual(kept.read_text(encoding="utf-8"), "두 번 바뀜\n")
            self.assertEqual(txn.rollback(), [])
            self.assertEqual(kept.read_bytes(), "원래\n".encode("utf-8"))
            self.assertEqual(gone.read_bytes(), b"gone\n")
            self.assertFalse(new.exists())
            self.assertFalse(new.parent.exists())
            self.assertEqual(sorted(p.name for p in d.iterdir()), ["gone.md", "kept.md"])


class Record(unittest.TestCase):
    def test_round_trip(self):
        text = "# state\n\n## 분해안\n\n| 표 |\n"
        once = W.with_record(text, {"docs/rm/roadmap.md", "docs/rm/A1.md"})
        self.assertEqual(W.read_record(once), {"docs/rm/roadmap.md", "docs/rm/A1.md"})
        self.assertTrue(once.startswith(text.rstrip("\n")))
        twice = W.with_record(once + "\n## 뒤 절\n\n뒤\n", {"docs/rm/roadmap.md"})
        self.assertEqual(W.read_record(twice), {"docs/rm/roadmap.md"})
        self.assertIn("## 뒤 절\n\n뒤\n", twice)
        self.assertEqual(twice.count("## 생성 기록"), 1)

    def test_empty(self):
        self.assertEqual(W.read_record("# state\n"), set())


if __name__ == "__main__":
    unittest.main()
