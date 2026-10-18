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
import section6  # noqa: E402


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


# ── fix round 3 (Ruling T10-d · S13-a) — 남은 판독기 불일치 · 구조 글자 닮은꼴 ───────────────────────────────
import check_brief as CB  # noqa: E402
import roadmap_render  # noqa: E402

FX3 = Path(__file__).resolve().parent / "fixtures"


def _pair():
    return ((FX3 / "interview-brief-valid.md").read_text(encoding="utf-8"),
            (FX3 / "interview-brief-valid.audit.md").read_text(encoding="utf-8"))


class Round3Sections(unittest.TestCase):
    """로드맵도 게이트와 같은 절 경계(제목 붙은 `## <n>. <제목>`)로 읽고, 같은 번호 머리가 둘이면 거부한다."""

    def test_one_title_table(self):
        self.assertEqual(B.SECTION_TITLES["0"], "한눈에")
        self.assertEqual(list(CB.SECTIONS), list(B.SECTIONS))

    def test_duplicate_heading_refused(self):
        doc = "# t\n\n## 0. 메모\n\n- OQ9 [열림] — 미끼\n\n## 0. 한눈에\n\n- OQ1 [열림] — x\n\n## 1. Goal · Non-goal\n"
        self.assertEqual(B.section_problem(doc, "0"), "section_heading_duplicate")
        fenced = ("# t\n\n```\n## 0. 메모\n```\n\n## 0. 한눈에\n\n- OQ1 [열림] — x\n\n"
                  "## 4. External Landscape\n\n## 4.1 하위\n\n## 1. Goal · Non-goal\n")
        self.assertIsNone(B.section_problem(fenced, "0"))   # 펜스 안 머리는 세지 않는다
        self.assertIsNone(B.section_problem(fenced, "4"))   # `## 4.1` 은 다른 번호다
        self.assertEqual(B.section_problem("# t\n\n## 0. 다른 제목\n", "0"), "section_missing")

    def test_universe_refuses_decoy_heading(self):
        brief, audit = _pair()
        decoy = brief.replace("## 0. 한눈에", "##  0. 메모\n\n- OQ9 [열림] — 미끼\n\n## 0. 한눈에", 1)
        with self.assertRaises(roadmap_model.FormatError):
            roadmap_model.brief_universe(decoy, audit)

    def test_subheading_and_separator_do_not_cut_section5(self):
        brief, audit = _pair()
        base_non_s, _s, base_k = roadmap_model.brief_universe(brief, audit)
        self.assertIn("ST1", base_non_s)
        self.assertEqual(len(base_k), 1)
        base_idx = roadmap_render.index_brief(brief, audit)
        head = "## 5. 기각 · Blind Spots\n\n"
        self.assertIn(head, brief)
        for extra in ("## 메모\n\n", "산문" + chr(0x2028) + "## 9. x\n\n"):
            b2 = brief.replace(head, head + extra, 1)
            non_s, _s, k = roadmap_model.brief_universe(b2, audit)
            self.assertIn("ST1", non_s, repr(extra))
            self.assertEqual(k, base_k, repr(extra))
            idx = roadmap_render.index_brief(b2, audit)
            self.assertEqual(idx.lines, base_idx.lines, repr(extra))
            self.assertEqual(idx.k_lines, base_idx.k_lines, repr(extra))


class Round3OneOQReader(unittest.TestCase):
    REFUSED = {
        "- OQ1: x [해" + chr(0xFE00) + "결 " + LA + "S2" + RA + "]": "decision_confusable",
        "- OQ" + chr(0x034F) + "1 — 제목": "decision_confusable",
        "- " + FW("OQ") + "1 — 제목": "decision_confusable",
        "OQ1 — 제목만 적은 맨 줄": "decision_shape",
        "**OQ1 — 제목**": "decision_shape",
        "메모 `[해결 " + LA + "S2" + RA + "]` 를 코드 칸에 숨겼다": "decision_shape",
    }

    def test_refused(self):
        for line, why in self.REFUSED.items():
            self.assertEqual(B.decision_line_problem(line), why, repr(line))

    def test_passes(self):
        for line in ("- **OQ1 — cache 전략** [열림] — x", "- OQ1 — " + chr(0x2460) + " x [해결 " + LA + "S2" + RA + "]",
                     "(OQ1~OQ7 은 S10 에서 사용자가 「일곱 개」로 박제한 것이다.",
                     "**결정 목록** — 상태는 `[열림]` 또는 `[해결 " + LA + "S<n>" + RA + "]` 로 적는다.", "- OQ1 — 제목"):
            self.assertIsNone(B.decision_line_problem(line), repr(line))

    def test_gate_and_roadmap_read_the_same_oq(self):
        for line in ("- " + FW("OQ") + "3 [열림] — x", "- OQ" + chr(0x034F) + "3 [열림] — x", "* **OQ3** [열림] — x"):
            want = B.decision_entries(line)[0][0][0]
            self.assertEqual(CB._leading_oq(line), want, repr(line))
            self.assertEqual(CB._decision_line("0", line)[0], want, repr(line))


class Round3Lookalikes(unittest.TestCase):
    """Ruling S13-a — 숫자 닮은꼴 표를 쫓지 않는다. §6 의 강조 머리가 S 로 시작하면 앵커이거나 거부, §6 밖의 S 바로 뒤
    비ASCII 숫자 · 한글/한자가 아닌 글자는 `ref_confusable`."""

    def test_section6_emphasis_head(self):
        for line in ("- **S" + chr(0x0417) + "** 「t」", "- **S" + chr(0x0A67) + "** 「t」", chr(0x2212) + " **S5** 「t」",
                     "- " + chr(0x2217) * 2 + "S5" + chr(0x2217) * 2 + " 「t」", "- __S5__ 「t」", "- **S" + chr(0x0431) + "** 「t」"):
            ok, bad = B.anchor_lines("- **S1** a\n" + line)
            self.assertEqual([s for _n, s, _r in ok], ["S1"], repr(line))
            self.assertEqual([r for _n, r in bad], ["anchor_confusable"], repr(line))

    def test_ref_confusable(self):
        for tail in (chr(0x0417), chr(0x0661), chr(0x0431), chr(0x0A67)):
            text = "근거 S" + tail + " 끝"
            self.assertEqual(B.ref_confusables(text), ["S" + tail], hex(ord(tail)))
            self.assertEqual(B.open_line_s_refs(text), [], hex(ord(tail)))   # 다른 번호로 풀지 않는다
        for ok_text in ("S3에 따라", "S가 아니다", "S" + chr(0x4E00) + " 한자", "S<n>"):
            self.assertEqual(B.ref_confusables(ok_text), [], repr(ok_text))


# ── fix round 4 (Ruling S14 · S13-b) — 머리 판독 하나 · 읽히지 않는 결정 글 없음 · OQ 숫자는 ASCII ───────────────────
DOC4 = ("---\nname: t\n---\n\n# t\n\n## 0. 한눈에\n\n- OQ1 [열림] — x\n\n## 0.1 추가 결정\n\n- OQ8 [해결 " + LA + "S2" + RA
        + "] — 확정\n\n## 1. Goal · Non-goal\n\n- Goal: g " + LA + "S1" + RA + "\n")


class Round4Heads(unittest.TestCase):
    def test_subheading_stays_inside_section(self):
        self.assertIn("- OQ8", B.section_text(DOC4, "0"))
        self.assertNotIn("Goal:", B.section_text(DOC4, "0"))

    def test_duplicate_count_on_canonical_text(self):
        real = "# t\n\n## 0. 한눈에\n\n- OQ1 [열림] — x\n\n## 1. Goal · Non-goal\n"
        for decoy in ("## " + FW("0") + ". 한눈에\n\n", "## 0" + chr(0x200B) + ". 한눈에\n\n"):
            doc = real.replace("## 0. 한눈에", decoy + "## 0. 한눈에", 1)
            self.assertEqual(B.section_problem(doc, "0"), "section_heading_duplicate", repr(decoy))

    def test_unknown_heads(self):
        for head in ("## 0.1 추가 결정", "## 8. 부록", "## 00. 영영", "## " + chr(0x0660) + ". 아라비아 숫자",
                     "## " + FW("0") + ". 한눈에", "##0. 한눈에", "## 2) 괄호"):
            doc = "# t\n\n## 0. 한눈에\n\n" + head + "\n\n## 1. Goal · Non-goal\n"
            self.assertEqual([r for _n, r in B.head_problems(doc)], ["section_head_unknown"], repr(head))
        clean = "# t\n\n## 0. 한눈에\n\n```\n## 8. 펜스 안\n```\n\n### 0.5 소소제목\n\n## 메모\n\n## 1. Goal · Non-goal\n"
        self.assertEqual(B.head_problems(clean), [])

    def test_decision_outside_sections(self):
        brief, _audit = _pair()
        for where, add in (("# Sample Topic — Interview Brief\n", "\n- OQ6 [열림] — 머리말\n"),
                           ("## 2. 제약\n", "\n- OQ5 [해결 " + LA + "S2" + RA + "] — 숨긴 결정\n"),
                           ("## 7. Next Action\n", "\n```\n- OQ7 [열림] — 펜스 안\n```\n")):
            doc = brief.replace(where, where + add, 1)
            self.assertTrue(any("decision_outside_sections" in x for x in CB.decision_outside_failures(doc)), repr(add))
        self.assertEqual(CB.decision_outside_failures(brief), [])
        legend = brief.replace("## 2. 제약\n", "## 2. 제약\n\n상태는 `[열림]` 또는 `[해결 " + LA + "S<n>" + RA + "]` 로 적는다.\n", 1)
        self.assertEqual(CB.decision_outside_failures(legend), [])

    def test_oq_digits_are_ascii(self):
        self.assertEqual(B.decision_line_problem("- OQ" + chr(0x0661) + " [해결 " + LA + "S2" + RA + "] — 정함"), "oq_confusable")
        self.assertIsNone(B.leading_oq("- OQ" + chr(0x0661) + " [열림] — x"))
        self.assertIsNone(CB.DECISION_HEAD_RE.match("OQ" + chr(0x0661)))

    def test_no_literal_payload_titles(self):
        # 절 제목은 brief_body.SECTIONS 하나에만 있다 — 판독기 소스에 payload 절 제목 리터럴이 남지 않는다.
        scripts = Path(__file__).resolve().parent.parent / "scripts"
        for name in ("check_brief.py", "roadmap_model.py", "roadmap_render.py"):
            src = (scripts / name).read_text(encoding="utf-8")
            for _num, title in B.SECTIONS:
                n = src.count('"%s"' % title)
                allowed = 1 if (name == "check_brief.py" and title == "사용자 원문") else 0   # AUDIT_SECTIONS 의 audit 제목
                self.assertEqual(n, allowed, "%s: %s" % (name, title))


# ── fix round 5 (Ruling S14-a · S14-b) — 머리 정규식은 한 줄만 읽는다 · audit §6 출처 표기는 싣는 바이트에서 ─────────────
import section6  # noqa: E402


class Round5OneLineHeads(unittest.TestCase):
    DECOY = ("# t\n\n##\n0. 한눈에\n\n## 0. 한눈에\n\n- OQ8 [해결 " + LA + "S2" + RA + "] — 숨긴 결정\n\n"
             "## 1. Goal · Non-goal\n")

    def test_heading_does_not_span_lines(self):
        self.assertIn("- OQ8", B.section_text(self.DECOY, "0"))
        self.assertIsNone(B._titled_head("0", "한눈에").match("##\n0. 한눈에"))
        self.assertEqual([r for _l, r in B.head_problems(self.DECOY)], ["section_head_unknown"])   # 빈 `##` 머리

    def test_roadmap_refuses_split_heading(self):
        brief, audit = _pair()
        b2 = brief.replace("\n## 0. 한눈에\n", "\n##\n0. 한눈에\n\n## 0. 한눈에\n", 1)
        with self.assertRaises(roadmap_model.FormatError):
            roadmap_model.brief_universe(b2, audit)

    def test_section6_heads_read_one_line(self):
        doc = "# t\n\n## 5. 기각 · Blind Spots\n\n- x\n\n##\n6. 사용자 원문\n\n## 6. 사용자 원문\n- **S1** a\n## 7. Next Action\n"
        self.assertEqual(len(section6.start_candidates(doc)), 1)
        self.assertEqual(section6.body(doc), B.section_text(doc, "6"))
        for rx in (section6.START_RE, section6.END_LOOSE_RE, section6.END_STRICT_RE, section6.BRIEF_SECTION_HEAD_RE,
                   section6.BRIEF_HEADLIKE_RE):
            self.assertIsNone(rx.search("##\n6. x"), rx.pattern)


class Round5AuditLegend(unittest.TestCase):
    def test_legend_read_from_shipped_section6(self):
        _brief, audit = _pair()
        self.assertFalse(CB.attribution_block_missing(audit))
        for cut in ("## 7.1 끼운 소제목\n\n", "## " + chr(0x0667) + ". 끼운 머리\n\n"):
            a2 = audit.replace("## 6. 사용자 원문\n\n", "## 6. 사용자 원문\n\n" + cut, 1)
            self.assertTrue(CB.attribution_block_missing(a2), repr(cut))


class RenderedShapeRules(unittest.TestCase):
    """Task 11 — markdown-it 교차 확인이 드러낸 부류: CommonMark 펜스 · 마크업으로 꾸민 앵커 · O/Q 닮은꼴 · CR 머리 · setext."""

    def spans(self, doc):
        return [m.span() for m in B.FENCE_RE.finditer(doc)]

    def test_fence_follows_commonmark(self):
        self.assertEqual(self.spans("```a``` x\n- **S9** y\n"), [])                  # 정보 문자열에 백틱 — 펜스가 아니다
        self.assertEqual(self.spans("~~~\n- **S9** y\n~~~\n"), [(0, 18)])              # 물결 펜스
        self.assertEqual(self.spans("```\nx\n~~~\n"), [(0, 10)])                      # 닫히지 않은 펜스는 글 끝까지
        self.assertEqual(self.spans("````\nx\n```\ny\n````\n"), [(0, 17)])           # 닫는 줄은 여는 줄 이상의 길이
        self.assertEqual(self.spans("    ```\nx\n    ```\n"), [])                    # 들여쓰기 4칸은 펜스가 아니다

    def test_markup_dressed_anchor_is_refused(self):
        for line in ("- <b>S9</b> x", "- *\\*S5*\\*", "- **S<i></i>9**"):
            ok, bad = B.anchor_lines(line)
            self.assertEqual(ok, [], line)
            self.assertTrue(bad, line)
        self.assertEqual(B.anchor_lines("- **S9** 「x」")[0], [(1, "S9", "「x」")])
        self.assertEqual(B.anchor_lines("- **S<N>** 자리 표시")[1], [])    # 템플릿 자리 표시는 태그로 읽지 않는다
        ok, bad = B.anchor_lines("  - **S" + chr(0x0417) + "**")
        self.assertEqual((ok, [r for _n, r in bad]), ([], ["anchor_confusable"]))     # 들인 닮은 글자 머리

    def test_o_q_lookalikes_fold(self):
        self.assertEqual(B.fold(chr(0x041E) + chr(0x051A) + "1"), "OQ1")
        line = "- " + chr(0x041E) + "Q1 결정 내용"
        self.assertEqual(B.decision_line_problem(line), "decision_confusable")
        self.assertTrue(B.decision_shaped(line))
        self.assertIsNone(B.decision_line_problem("- OQ1 결정 내용"))

    def test_empty_head_with_cr_is_a_candidate(self):
        for head in ("##", "##\r", "## ", "  ##\t\r"):
            doc = "본문\n\n" + head + "\n\n## 0. 한눈에\n"
            self.assertEqual([r for _l, r in B.head_problems(doc)], ["section_head_unknown"], repr(head))

    def test_placeholder_does_not_exempt_the_whole_line(self):
        for line in ("- <b>S9</b> x S<N>", "- *\\*S5*\\* S\\<N\\>", "- **&#83;9** x", "- <b>S&#57;</b> x"):
            ok, bad = B.anchor_lines(line)
            self.assertEqual((ok, [r for _n, r in bad]), ([], ["anchor_markup"]), line)
        self.assertEqual(B.anchor_lines("- **S<N>** 자리 표시 S<N>")[1], [])   # 자리 표시만 있는 줄은 그대로 받는다

    def test_html_and_char_refs_are_outside_the_subset(self):
        why = lambda doc: [w for _l, w in B.subset_problems(doc)]
        self.assertEqual(why("<div>\n- a\n</div>\n"), ["html_block_not_allowed", "html_block_not_allowed"])
        self.assertEqual(why("<!-- c -->\n"), ["html_block_not_allowed"])
        self.assertEqual(why("- &#79;Q1 결정\n"), ["char_ref_not_allowed"])
        self.assertEqual(why("- &#x53;9 · &amp; · &copy;\n"), ["char_ref_not_allowed"])
        self.assertEqual(why("- 코드 칸 `&#83;` 안은 그대로\n"), [])
        self.assertEqual(why("```\n<div>&#83;\n```\n"), [])                 # 펜스 안은 읽지 않는다
        self.assertEqual(why("- 산문 a < b 와 R&D 는 괜찮다\n"), [])

    def test_indented_fence_is_refused(self):
        doc = "## 1. Goal · Non-goal\n- a\n  ```\n## 6. 사용자 원문\n  ```\n"
        self.assertIn("fence_indented", [w for _l, w in B.head_problems(doc)])
        self.assertEqual(section6.indented_fence_openers("```\nx\n```\n"), [])

    def test_fence_coordinate_is_the_body_for_every_reader(self):
        fm = "---\nname: x\nnote: |\n  ```\n---\n"
        head = fm + "## 5. 기각 · Blind Spots\n본문\n\n## 6. 사용자 원문\n\n"
        tail = "- **S1** 「뒤」\n\n## 7. Next Action\n끝\n"
        plain = head + tail
        self.assertEqual(section6.fence_spans(plain), [])           # frontmatter 의 펜스 꼴 줄은 세지 않는다
        self.assertIn("- **S1** 「뒤」", section6.body(plain))
        self.assertIn("- **S1** 「뒤」", B.section_text(plain, "6"))
        hidden = head + "```\n## 7. x\n```\n" + tail
        self.assertEqual(len(section6.fence_spans(hidden)), 1)
        self.assertTrue(section6.ambiguities(hidden))               # 펜스 안 머리 — 관대 · 엄격 읽기가 갈려 게이트가 막는다
        self.assertIsNone(section6.span(hidden))

    def test_ordered_item_not_one_cannot_interrupt_a_paragraph(self):
        self.assertEqual(B.setext_problems("x\n7. Next Action\n---\n"), [("7. Next Action", "setext_heading")])
        self.assertEqual(B.setext_problems("x\n1. 목록\n---\n"), [])

    def test_tables_cover_the_source_and_tag_scan_is_linear(self):
        for cp, want in ((0x1CCE6, "Q"), (0x1030F, "O"), (0x16F3A, "S")):
            self.assertEqual(B.fold(chr(cp)), want, hex(cp))
        import time
        t0 = time.time()
        B.anchor_lines("- " + "<" * 20000 + "x")
        self.assertLess(time.time() - t0, 2.0)

    def test_setext_heading_is_refused_at_top_level_only(self):
        self.assertEqual(B.setext_problems("제목\n---\n"), [("제목", "setext_heading")])
        self.assertEqual(B.setext_problems("제목\n===\n"), [("제목", "setext_heading")])
        for ok in ("제목\n\n---\n", "- 항목\n---\n", "> 인용\n> ---\n", "> 인용\n게으른 줄\n---\n", "# 제목\n---\n",
                   "```\n제목\n---\n```\n", "---\nname: x\n---\n본문\n"):
            self.assertEqual(B.setext_problems(ok), [], repr(ok))
        self.assertEqual([r for _l, r in B.head_problems("제목\n---\n")], ["setext_heading"])


class SharedGrammar(unittest.TestCase):
    def test_readers_share_one_object(self):
        self.assertIs(check_brief.ANCHOR_LINE_RE, B.ANCHOR_LINE_RE)
        self.assertIs(CVC.ANCHOR_LINE_RE, B.ANCHOR_LINE_RE)
        self.assertIs(roadmap_model.ANCHOR_LINE_RE, B.ANCHOR_LINE_RE)
        self.assertIs(roadmap_model.section4_items, B.section4_items)


if __name__ == "__main__":
    unittest.main()
