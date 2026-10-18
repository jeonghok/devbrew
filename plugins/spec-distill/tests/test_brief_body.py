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


SEPARATORS = ["\r", "\v", "\f", "\x1c", "\x1d", "\x1e", "\x85", "\u2028", "\u2029"]


class Round1Anchors(unittest.TestCase):
    def test_separator_inside_anchor_line_refused(self):
        for sep in SEPARATORS:
            ok, bad = B.anchor_lines("- **S4** 「t4」" + sep + "- **S5** 「t5」")
            self.assertEqual(ok, [], repr(sep))
            self.assertEqual([r for _n, r in bad], ["anchor_line_separator"], repr(sep))

    def test_separator_in_plain_text_line_allowed(self):
        self.assertEqual(B.anchor_lines("- **S4** 「t4」\r"), ([(1, "S4", "「t4」\r")], []))
        self.assertEqual(B.anchor_lines("일반 줄" + "\u2028" + "이어서"), ([], []))

    def test_separator_in_payload_section6_refused_by_coverage_reader(self):
        for sep in SEPARATORS:
            doc = "## 6. 사용자 원문\n- **S1** a\n- **S4** 「t4」" + sep + "- **S5** 「t5」\n## 7. Next Action\n"
            with self.assertRaises(CVC.StructuralViolation, msg=repr(sep)):
                CVC.parse_section6(doc, "payload")

    def test_confusable_anchor_lines_refused(self):
        cases = ["- **\uff335** 「x」", "- **\u200bS5** 「x」", "- **S\u200b5** 「x」", "- **S\uff15** 「x」"]
        for line in cases:
            ok, bad = B.anchor_lines(line)
            self.assertEqual(ok, [], repr(line))
            self.assertEqual([r for _n, r in bad], ["anchor_confusable"], repr(line))

    def test_id_spelling(self):
        for line in ["- **S01** x", "- **S\u0662** x", "- **S0** x"]:
            ok, bad = B.anchor_lines(line)
            self.assertEqual(ok, [], repr(line))
            self.assertEqual(len(bad), 1, repr(line))

    def test_reference_scan_is_canonical_and_bracket_derived(self):
        for text in ["(S2)", "[S2]", "\u27e8S2\u27e9", "\u27e8\uff33\uff12\u27e9", "\u27e8S\u200b2\u27e9",
                     "<S2>", "\u2039S2\u203a", "\u3008S2\u3009", "\uff08S2\uff09", "\u300cS2\u300d"]:
            self.assertEqual(B.open_line_s_refs("- OQ1: " + text + " 끝"), ["S2"], repr(text))
        self.assertEqual(B.open_line_s_refs("- OQ1: S2 만 적었다"), [])

    def test_decision_shape(self):
        self.assertEqual(B.decision_line_problem("+ OQ1 [해결 \u27e8S99\u27e9] — 정함"), "decision_shape")
        self.assertEqual(B.decision_line_problem("OQ1 [해결 \u27e8S2\u27e9] — 정함"), "decision_shape")
        self.assertEqual(B.decision_line_problem("\uff2fQ1 [해결 \u27e8S2\u27e9] — 정함"), "decision_shape")
        self.assertIsNone(B.decision_line_problem("- OQ1: 열림"))
        self.assertIsNone(B.decision_line_problem("* OQ1: 열림"))
        self.assertIsNone(B.decision_line_problem("산문 줄이다"))


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
