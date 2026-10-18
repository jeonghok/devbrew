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

    def test_prose_mention_in_section6_is_refused(self):
        # §6 은 바이트 전부를 센다(Ruling S13 대체 규칙) — 본문 가운데 적힌 `**S<n>**` 도 앵커 꼴 토큰이다.
        ok, bad = B.anchor_lines("본문 가운데 **S3** 를 언급한다")
        self.assertEqual((ok, [r for _n, r in bad]), ([], ["anchor_in_body"]))

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

    def test_reference_scan_is_canonical(self):
        for text in ["(S2)", "[S2]", "\u27e8S2\u27e9", "\u27e8\uff33\uff12\u27e9", "\u27e8S\u200b2\u27e9",
                     "<S2>", "\u2039S2\u203a", "\u3008S2\u3009", "\uff08S2\uff09", "\u300cS2\u300d"]:
            self.assertEqual(B.open_line_s_refs("- OQ1: " + text + " 끝"), ["S2"], repr(text))
        # 괄호가 없어도 토큰이다(`ANCHOR_RE` 관례 — Ruling F4).
        self.assertEqual(B.open_line_s_refs("- OQ1: S2 만 적었다"), ["S2"])

    def test_decision_shape(self):
        self.assertEqual(B.decision_line_problem("+ OQ1 [해결 \u27e8S99\u27e9] — 정함"), "decision_shape")
        self.assertEqual(B.decision_line_problem("OQ1 [해결 \u27e8S2\u27e9] — 정함"), "decision_shape")
        self.assertEqual(B.decision_line_problem("\uff2fQ1 [해결 \u27e8S2\u27e9] — 정함"), "decision_shape")
        self.assertIsNone(B.decision_line_problem("- OQ1: 열림"))
        self.assertIsNone(B.decision_line_problem("* OQ1: 열림"))
        self.assertIsNone(B.decision_line_problem("산문 줄이다"))
        self.assertIsNone(B.decision_line_problem("(OQ1~OQ7 은 사용자가 「일곱 개」로 박제한 것이다."))
        self.assertIsNone(B.decision_line_problem("**결정 목록** — 상태는 `[열림]` 또는 `[해결 \u27e8S<n>\u27e9]` 로 적는다."))


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


# ── fix round 2 (Ruling S12-c · S13 · F1~F5) — 보이지 않는 · 닮은 글자는 전부 chr(코드포인트) 로 적는다 ──────
LA, RA = chr(0x27E8), chr(0x27E9)           # 수학 꺾쇠 ⟨ ⟩
FW = lambda s: "".join(chr(ord(c) + 0xFEE0) for c in s)   # noqa: E731 — ASCII → 전각


class Round2Decision(unittest.TestCase):
    REFUSED = {
        "1. OQ1: 인증 뷰의 캐시 전략": "decision_numbered",
        "> - OQ1: 인증 뷰의 캐시 전략": "decision_quoted",
        "+ OQ2: 열린 결정": "decision_shape",
        "OQ2: 열린 결정": "decision_shape",
        "결정: OQ1 [해결 " + LA + "S2" + RA + "] — 정함": "decision_shape",
        "가. OQ2: 열린 결정": "decision_shape",
        chr(0x2460) + " OQ2: 열린 결정": "decision_shape",
        chr(0x2192) + " 결론 OQ1 [해결 " + LA + "S2" + RA + "]": "decision_shape",
        "_OQ2_: 밑줄 강조 결정": "decision_shape",
        "  - OQ2: 들여 쓴 결정": "decision_shape",
        "**OQ2**: 불릿 없는 강조 결정": "decision_shape",
        "설명 [열림] 표지를 산문에 적었다": "decision_shape",
    }

    def test_refused_shapes(self):
        for line, why in self.REFUSED.items():
            self.assertEqual(B.decision_line_problem(line), why, line)

    def test_entry_and_prose_pass(self):
        for line in ("- OQ1: 열림", "* OQ1 [열림] — x", "- **OQ1**: x", "- OQ1 [해결 " + LA + "S2" + RA + "]: x",
                     "(OQ1~OQ7 은 S10 에서 사용자가 「일곱 개」로 박제한 것이다.",
                     "**결정 목록** — 상태는 `[열림]` 또는 `[해결 " + LA + "S<n>" + RA + "]` 로 적는다.",
                     "산문 줄이다", "- OQ2: 캐시 무효화 시점 (OQ1 이 정해진 뒤에 논의)", "- OQ1 — 제목만 적은 줄"):
            self.assertIsNone(B.decision_line_problem(line), line)

    def test_confusable_head_on_a_bullet(self):
        # 날 글자로는 열 0 불릿인데 정규형 머리가 날 머리와 다르다 — 판독기마다 다른 결정으로 읽힌다(F1).
        for line in ("- " + FW("OQ") + "3 [열림] — x", "- O" + chr(0x200B) + "Q1: x", "-" + chr(0xA0) + "OQ1: x",
                     "- OQ" + chr(0x034F) + "1: x", "- " + FW("[") + "열림] 표지만"):
            self.assertEqual(B.decision_line_problem(line), "decision_confusable", repr(line))

    def test_separator_inside_a_decision_line(self):
        for sep in SEPARATORS:
            line = "- OQ1: 열린 결정" + sep + "+ OQ2 [해결 " + LA + "S2" + RA + "]: 정함"
            self.assertEqual(B.decision_line_problem(line), "decision_line_separator", repr(sep))
        self.assertIsNone(B.decision_line_problem("산문" + chr(0x2028) + "이어서"))

    def test_entry_lines_share_the_splitter(self):
        acc, rej = B.entry_lines("- Goal: x " + LA + "S1" + RA + chr(0x2028) + "- Non-goal: y", sep_reason="decision_line_separator")
        self.assertEqual(len(acc), 1)
        self.assertEqual(rej, [(1, "decision_line_separator")])
        acc, rej = B.entry_lines("1. OQ1: x\n- OQ2: y", decisions=True)
        self.assertEqual((acc, rej), (["- OQ2: y"], [(1, "decision_numbered")]))
        self.assertEqual(B.entry_lines("1. OQ1: x\n- OQ2: y")[1], [])   # 결정 판독은 §0 · §3 에만

    def test_section4_items_use_the_splitter(self):
        self.assertEqual(len(B.section4_items("- «a» x" + chr(0x2028) + "- «b» y")), 1)


class Round2Canon(unittest.TestCase):
    def test_default_ignorables_removed(self):
        for cp in (0x00AD, 0x034F, 0x061C, 0x115F, 0x1160, 0x17B4, 0x180B, 0x180E, 0x200B, 0x200E, 0x202A, 0x2060,
                   0x2064, 0x206F, 0x3164, 0xFE00, 0xFE0F, 0xFEFF, 0xFFA0, 0xFFF0, 0x1BCA0, 0x1D173, 0xE0001, 0xE0100):
            self.assertEqual(B.canon("S" + chr(cp) + "5"), "S5", hex(cp))

    def test_ignorables_in_anchor_and_reference(self):
        for cp in (0x034F, 0xFE0F, 0x3164):
            ok, bad = B.anchor_lines("- **S" + chr(cp) + "5** x")
            self.assertEqual((ok, [r for _n, r in bad]), ([], ["anchor_confusable"]), hex(cp))
            self.assertEqual(B.open_line_s_refs("근거 " + LA + "S" + chr(cp) + "99" + RA + " 끝"), ["S99"], hex(cp))


class Round2Section6(unittest.TestCase):
    """§6 의 바이트 전부를 센다 — 앵커가 아닌 줄(이음 줄 · 앵커 앞 줄 · 앵커 줄 나머지)에 앵커 꼴 토큰이나 S 번호를 단
    목록 머리가 있으면 거부한다(Ruling S13 대체 규칙 · `anchor_in_body`)."""

    def test_anchor_in_body(self):
        cases = [
            "- **S1** a\n본문 가운데 **S3** 를 언급한다",
            "- **S1** 요청: - **S5** 「t」",
            "- **S1** a\n  > - S5 「t」",
            "- **S1** a\n  > - __S5__ 「t」",
            "앞 줄 - **S5** x\n- **S1** a",
            "- **S1** a\n  > 인용 가운데 **" + chr(0x0405) + "5** 를 심었다",
        ]
        for text in cases:
            ok, bad = B.anchor_lines(text)
            self.assertEqual(([s for _n, s, _r in ok], [r for _n, r in bad]), (["S1"], ["anchor_in_body"]), repr(text))

    def test_folded_heads_in_body_are_refused(self):
        # 닮은 글자(키릴 · 체로키 · 리수 S · 다른 문자 체계의 숫자)를 접으면 앵커 머리다 — 들여 쓴 줄이면 들임 사유로 거부된다.
        for text in ("- **S1** a\n  - **" + chr(0x0405) + "5** 「t」", "- **S1** a\n  > - **" + chr(0x13DA) + "5** 「t」",
                     "- **S1** a\n  > - **S" + chr(0x0662) + "** 「t」"):
            ok, bad = B.anchor_lines(text)
            self.assertEqual([s for _n, s, _r in ok], ["S1"], repr(text))
            self.assertEqual(len(bad), 1, repr(text))

    def test_cross_script_head_is_confusable(self):
        for s in (chr(0x0405), chr(0x13DA), chr(0xA4E2), chr(0x10296), chr(0x10420)):
            ok, bad = B.anchor_lines("- **" + s + "5** 「t」")
            self.assertEqual((ok, [r for _n, r in bad]), ([], ["anchor_confusable"]), hex(ord(s)))

    def test_ordinary_body_passes(self):
        text = ("> **출처 표기** — 사용자 발화 · 사용자 선택 · 모델 추론\n- **S1** 최초 요청:\n"
                "  > \"S2 를 다시 본다\"\n  >     - 하위 목록 줄\n- floor:root_problem — closed\n- **S2** 선택:\n  > \"네\"")
        ok, bad = B.anchor_lines(text)
        self.assertEqual(([s for _n, s, _r in ok], bad), (["S1", "S2"], []))


class Round2Refs(unittest.TestCase):
    def test_token_convention(self):
        cases = {
            "(S2, S99)": ["S2", "S99"],
            LA + " S99 " + RA: ["S99"],
            "«S99»": ["S99"],
            chr(0x201C) + "S99" + chr(0x201D): ["S99"],
            LA + "S" + chr(0x2490) + RA: ["S9"],
            "- Goal: X (S99) " + LA + "S1" + RA: ["S99", "S1"],
            "근거 " + chr(0x0405) + "99 끝": ["S99"],
            "S3에 따라": ["S3"],
            "S<n> 자리 · OQS3 · STS1": [],
        }
        for text, want in cases.items():
            self.assertEqual(B.open_line_s_refs(text), want, repr(text))


class Round2Universe(unittest.TestCase):
    """roadmap_model.brief_universe 가 §0 OQ 번호를 게이트와 같은 판독기 · 같은 절 경계(`## <n>.`)로 센다(F5)."""

    FX = Path(__file__).resolve().parent / "fixtures"

    def universe(self, s0_line):
        brief = (self.FX / "interview-brief-valid.md").read_text(encoding="utf-8")
        audit = (self.FX / "interview-brief-valid.audit.md").read_text(encoding="utf-8")
        marker = "- OQ1 [열림] — 인증 뷰의 캐시 전략 — 해답공간으로 이월.\n"
        self.assertIn(marker, brief)
        return roadmap_model.brief_universe(brief.replace(marker, marker + s0_line), audit)[0]

    def test_counts_like_the_gate(self):
        for line in ("* OQ3 [열림] — x\n", "- **OQ3** [열림] — x\n", "\n## 메모\n\n- OQ3 [열림] — x\n"):
            self.assertIn("OQ3", self.universe(line), repr(line))

    def test_confusable_head_is_uncountable(self):
        with self.assertRaises(roadmap_model.FormatError):
            self.universe("- " + FW("OQ") + "3 [열림] — x\n")

class SharedGrammar(unittest.TestCase):
    def test_readers_share_one_object(self):
        self.assertIs(check_brief.ANCHOR_LINE_RE, B.ANCHOR_LINE_RE)
        self.assertIs(CVC.ANCHOR_LINE_RE, B.ANCHOR_LINE_RE)
        self.assertIs(roadmap_model.ANCHOR_LINE_RE, B.ANCHOR_LINE_RE)
        self.assertIs(roadmap_model.section4_items, B.section4_items)


if __name__ == "__main__":
    unittest.main()
