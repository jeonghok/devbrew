#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""brief_body.py — brief 판독 허용 문법 하나(AC18). 판독기 셋이 같은 객체를 쓰는지도 고정한다.

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_brief_body.py
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import brief_body as B  # noqa: E402
import check_brief  # noqa: E402
import check_verbatim_coverage as CVC  # noqa: E402
import roadmap_model  # noqa: E402


class AnchorGrammar(unittest.TestCase):
    def test_accepts_column0(self):
        ok, bad = B.anchor_lines("- **S1** 「첫 말」\n- **S2** 「둘째」")
        self.assertEqual([s for _n, s, _r in ok], ["S1", "S2"])
        self.assertEqual(bad, [])

    def test_prose_mention_is_not_an_anchor_shape(self):
        ok, bad = B.anchor_lines("본문 가운데 **S3** 를 언급한다")
        self.assertEqual((ok, bad), ([], []))

    def test_rejects_each_shape(self):
        cases = {
            "  - **S3** 「들임」": "anchor_indented",
            "\t- **S3** 「탭」": "anchor_indented",
            "\u00a0- **S3** 「NBSP」": "anchor_unicode_space",
            "\u3000- **S3** 「전각」": "anchor_unicode_space",
            "* **S3** 「별표」": "anchor_star_bullet",
            "-  **S3** 「공백 둘」": "anchor_shape",
            "1. **S3** 「번호」": "anchor_shape",
            "> - **S3** 「인용」": "anchor_shape",
        }
        for line, why in cases.items():
            ok, bad = B.anchor_lines(line)
            self.assertEqual(ok, [], line)
            self.assertEqual([r for _n, r in bad], [why], line)


class DecisionLines(unittest.TestCase):
    def test_numbered_and_quoted(self):
        self.assertEqual(B.decision_line_problem("1. [해결 ⟨S2⟩] — 정함"), "decision_numbered")
        self.assertEqual(B.decision_line_problem("> [해결 ⟨S2⟩] — 정함"), "decision_quoted")
        self.assertIsNone(B.decision_line_problem("- OQ1: 열림"))


class OpenLineRefs(unittest.TestCase):
    def test_all_refs_anywhere(self):
        self.assertEqual(B.open_line_s_refs("- OQ1: 가 ⟨S2⟩ 나\n  이어서 ⟨S5⟩ 끝 ⟨S2⟩"), ["S2", "S5", "S2"])


class Section4(unittest.TestCase):
    def test_fence_and_prose_not_items(self):
        txt = "- «a» 항목\n  이음\n산문 «b»\n```\n- «c»\n```\n- «d» 둘째"
        heads = [h for h, _c in B.section4_items(txt)]
        self.assertEqual(heads, ["- «a» 항목", "- «d» 둘째"])

    def test_blank_line_keeps_item_open(self):
        items = B.section4_items("- «a» 머리\n\n  이음 줄\n")
        self.assertEqual(items, [("- «a» 머리", ["이음 줄"])])

    def test_unicode_space_continuation(self):
        items = B.section4_items("- «a» 머리\n\u3000이음 «k»\n")
        self.assertEqual(items, [("- «a» 머리", ["이음 «k»"])])


class SharedGrammar(unittest.TestCase):
    def test_readers_share_one_object(self):
        self.assertIs(check_brief.ANCHOR_LINE_RE, B.ANCHOR_LINE_RE)
        self.assertIs(CVC.ANCHOR_LINE_RE, B.ANCHOR_LINE_RE)
        self.assertIs(roadmap_model.ANCHOR_LINE_RE, B.ANCHOR_LINE_RE)
        self.assertIs(roadmap_model.section4_items, B.section4_items)


if __name__ == "__main__":
    unittest.main()
