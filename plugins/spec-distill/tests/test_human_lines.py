#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""human_lines.py — 사람 줄의 꼴 · 통과 라벨 표 · 본문(git 없이, AC7 · AC8).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_human_lines.py
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SCRIPTS = REPO / "plugins" / "spec-distill" / "scripts"
sys.path.insert(0, str(SCRIPTS))
import human_lines as H  # noqa: E402
import team_files as F  # noqa: E402

S, E = "00000000-0000-4000-8000-00000000aaaa", "00000000-0000-4000-8000-000000000001"
SPEC = "- spec 승인 · 2026-11-18 · 「승인 — 계획 담당자에게」 · design.md@51f1b64d · 근거 %s:%s#1" % (S, E)
SKIP = "- 걸음 건너뜀 · 2026-11-18 · 「건너뛴다」 · 계획 검토 plan 2 · INTENT.md@51f1b64d · 근거 %s:%s#1" % (S, E)


class LineShape(unittest.TestCase):
    def test_tables(self):
        self.assertEqual(H.KINDS, ("spec 승인", "계획 검토", "흐름 승인", "걸음 건너뜀"))
        self.assertEqual(H.PASS_LABELS, {"spec 승인": ("승인 — 계획 담당자에게",), "계획 검토": ("계획대로 구현한다",),
                                         "흐름 승인": ("설계 없이 진행",), "걸음 건너뜀": ("건너뛴다", "다시 시도한다")})
        self.assertEqual((H.PASS, H.NO_EVIDENCE, H.MISMATCH, H.UNCHECKED, H.STALE), ("지남", "근거 없음", "어긋남", "확인 못 함", "낡음"))
        self.assertEqual(len(set(l for v in H.PASS_LABELS.values() for l in v)), 5)   # 종류마다 라벨이 다르다
        for kind in H.KINDS:
            self.assertIn(kind, F.DECISION_KINDS)

    def test_spec_label_is_the_one_the_approval_question_offers(self):   # J20 — 계획 2 가 나머지 라벨을 더한다
        text = (REPO / "plugins/spec-distill/references/conducting.md").read_text(encoding="utf-8")
        self.assertIn("「%s %s」" % (H.PASS_LABELS[H.KIND_SPEC][0], H.RECOMMENDED), text)

    def test_both_recommend_tails_come_off_once(self):   # test_human_lines.py LineShape — K11 (가)
        self.assertEqual(H.clean_label("승인 — 계획 담당자에게 (Recommended)"), "승인 — 계획 담당자에게")
        self.assertEqual(H.clean_label("승인 — 계획 담당자에게 (권장)"), "승인 — 계획 담당자에게")
        self.assertEqual(H.clean_label("승인 — 계획 담당자에게 (권장) (Recommended)"), "승인 — 계획 담당자에게 (권장)")   # 한 번만
        self.assertEqual(H.clean_label("(Recommended) 승인"), "(Recommended) 승인")                                           # 끝만

    def test_parse_and_render_round_trip(self):
        l = H.parse(SPEC)
        self.assertEqual((l.kind, l.date, l.label, l.gate, l.file, l.rev, l.session, l.entry, l.index, l.raw, l.key, l.plan),
                         ("spec 승인", "2026-11-18", "승인 — 계획 담당자에게", None, "design.md", "51f1b64d", S, E, 1, SPEC, E + "#1", None))
        self.assertEqual(H.render("spec 승인", "2026-11-18", "승인 — 계획 담당자에게", "design.md", "51f1b64d", S, E + "#1"), SPEC)
        k = H.parse(SKIP)
        self.assertEqual((k.kind, k.label, k.gate, k.file, k.plan), ("걸음 건너뜀", "건너뛴다", "계획 검토 plan 2", "INTENT.md", 2))
        self.assertEqual(H.render("걸음 건너뜀", "2026-11-18", "건너뛴다", "INTENT.md", "51f1b64d", S, E + "#1", gate="계획 검토 plan 2"), SKIP)
        p = H.parse(SPEC.replace("spec 승인", "계획 검토").replace("승인 — 계획 담당자에게", "계획대로 구현한다").replace("design.md", "plan-12.md"))
        self.assertEqual((p.file, p.plan), ("plan-12.md", 12))
        for raw in (SPEC, SKIP):
            self.assertIsNone(F.decision_problem(raw))
            self.assertEqual(H.is_human(raw), H.parse(raw).kind)

    def test_lines_that_are_human_kind_but_do_not_parse(self):
        retry = SKIP.replace("건너뛴다", "다시 시도한다").replace("계획 검토 plan 2", "다시 시도 plan 1 시도 3")
        self.assertEqual(H.parse(retry).gate, "다시 시도 plan 1 시도 3")                     # 양성 대조
        self.assertEqual(H.parse(retry.replace("다시 시도 plan 1 시도 3", "다시 시도 구현 시도 3")).plan, None)
        self.assertIsNone(H.parse(retry.replace("다시 시도 plan 1 시도 3", "다시 시도 시도 3")))   # 설계 없는 흐름의 이름은 「구현 시도」 다
        bad = [
            "- spec 승인 · 2026-11-18 · 「승인 — 계획 담당자에게」",                           # 옛 줄
            SPEC.replace("승인 — 계획 담당자에게", "이대로 승인"),                              # 통과 라벨이 아니다
            SPEC.replace("담당자에게」", "담당자에게 (권장)」"),                               # 꼬리가 남았다
            SPEC.replace("design.md", "plan-1.md"), SPEC.replace("design.md", "INTENT.md"),  # 파일이 종류와 다르다
            SPEC.replace("@51f1b64d", "@51f1b64"), SPEC.replace("@51f1b64d", "@51f1b64d0"), SPEC.replace("@51f1b64d", "@51F1B64D"),
            SPEC.replace("2026-11-18", "2026-02-30"), SPEC.replace("#1", "#0"), SPEC.replace("#1", "#01"),
            SPEC + " x", SPEC + "\n", SPEC.replace(" · 근거 ", " · 근거: "), SPEC.replace(S + ":", "short:"),
            SPEC.replace("」 · design", "」 · spec 승인 · design"),                            # 건너뜀이 아닌데 관문 이름
            SKIP.replace(" · 계획 검토 plan 2", ""), SKIP.replace("계획 검토 plan 2", "아무 관문"),
            SKIP.replace("계획 검토 plan 2", "계획 검토 plan 0"), SKIP.replace("계획 검토 plan 2", "다시 시도 plan 1 시도 3"),
            retry.replace("다시 시도 plan 1 시도 3", "spec 승인"), SKIP.replace("INTENT.md", "design.md"),
        ]
        for raw in bad:
            self.assertIsNone(H.parse(raw), raw)
            self.assertIn(H.is_human(raw), H.KINDS, raw)
        for raw in ("- 결정 · 2026-11-18 · 「글」", "- spec 승인됨 · 2026-11-18 · 「글」", "spec 승인 · 2026-11-18 · 「글」", ""):
            self.assertIsNone(H.is_human(raw), raw)

    def test_labels_heads_and_names(self):
        for text, want in (("승인 — 계획 담당자에게 (권장)", "승인 — 계획 담당자에게"), ("승인 — 계획 담당자에게(권장)", "승인 — 계획 담당자에게"),
                           ("  건너뛴다 ", "건너뛴다"), ("(권장) 승인", "(권장) 승인"), ("승인 (권장) (권장)", "승인 (권장)")):
            self.assertEqual(H.clean_label(text), want)
        self.assertEqual((H.head("R2", "51f1b64d"), H.head("R2", "51f1b64d", 1)), ("R2 @51f1b64d", "R2 plan 1 @51f1b64d"))
        self.assertTrue(H.starts_with_head("R2 plan 1 @51f1b64d — 계획대로 갈까요?", "R2", "51f1b64d", 1))
        for q in ("R2 plan 12 @51f1b64d 질문", "R2 plan 2 @51f1b64d 질문", "R2 @51f1b64d 질문", "R2 plan 1@51f1b64d 질문"):
            self.assertFalse(H.starts_with_head(q, "R2", "51f1b64d", 1), q)
        self.assertFalse(H.starts_with_head("R2 plan 1 @51f1b64d 질문", "R2", "51f1b64d"))      # 계획 번호 없는 머리와도 갈린다
        self.assertTrue(H.names_gate("다시 시도 plan 1 시도 3 을 풀까요", "다시 시도 plan 1 시도 3"))
        self.assertTrue(H.names_gate("spec 승인을 건너뛸까요 · 계획 검토 plan 1", "계획 검토 plan 1"))
        for text, name in (("다시 시도 plan 1 시도 31 을 풀까요", "다시 시도 plan 1 시도 3"), ("계획 검토 plan 12 를 건너뛸까요", "계획 검토 plan 1"), ("", "spec 승인")):
            self.assertFalse(H.names_gate(text, name), text)
        for q in ("R2 @51f1b64d — 설계를 승인할까요?", "R2 @51f1b64d", "R2 @51f1b64d\n둘째 줄"):
            self.assertTrue(H.starts_with_head(q, "R2", "51f1b64d"), q)
        for q in (" R2 @51f1b64d — 질문", "**R2 @51f1b64d** 질문", "\nR2 @51f1b64d", "R21 @51f1b64d 질문", "R2 @51f1b64d0 질문",
                  "R2 @51F1B64D 질문", "R2  @51f1b64d 질문", "r2 @51f1b64d 질문", "질문 R2 @51f1b64d", ""):
            self.assertFalse(H.starts_with_head(q, "R2", "51f1b64d"), q)
        self.assertEqual([H.bound_name(H.KIND_SPEC), H.bound_name(H.KIND_PLAN, 2), H.bound_name(H.KIND_FLOW), H.bound_name(H.KIND_SKIP)],
                         ["design.md", "plan-2.md", "INTENT.md", "INTENT.md"])
        self.assertEqual([H.gate_name(H.KIND_SPEC), H.gate_name(H.KIND_PLAN, 2), H.retry_name(2, 3), H.retry_name(None, 3)],
                         ["spec 승인", "계획 검토 plan 2", "다시 시도 plan 2 시도 3", "다시 시도 구현 시도 3"])


DESIGN = "# 설계\n\n## Goals\n\n본문 하나\n\n```\n## 결정 기록\n펜스 안 글\n```\n\n## Handoff\n\n넘김\n\n### Deferred to plan\n\n| a | b |\n\n### 남는 소제목\n\n남는 글\n\n## 미룸\n\n| 항목 |\n\n## 결정 기록\n\n- D1\n\n## 지휘 기록\n\n- 기록\n"


class Body(unittest.TestCase):
    def test_design_body_leaves_out_record_sections(self):
        body = H.body_of("design.md", DESIGN)
        for kept in ("본문 하나", "펜스 안 글", "## Handoff", "넘김", "### 남는 소제목", "남는 글"):
            self.assertIn(kept, body)
        for gone in ("| a | b |", "| 항목 |", "- D1", "- 기록", "### Deferred to plan"):
            self.assertNotIn(gone, body)
        same = [DESIGN.replace("- D1", "- D1\n- D2"), DESIGN.replace("| 항목 |", "| 항목 |\n| 새 미룸 |"), DESIGN.replace("| a | b |", "| c |"),
                DESIGN + "\n## 판정\n\n- 판정\n\n## 구현 대조 — plan-1.md\n\n- 대조\n", DESIGN + "\n\n\n"]
        for text in same:
            self.assertEqual(H.body_of("design.md", text), body)
        for text in (DESIGN.replace("본문 하나", "본문 둘"), DESIGN.replace("펜스 안 글", "펜스 안 다른 글"), DESIGN.replace("남는 글", "바뀐 글"),
                     DESIGN + "\n## 미룸표 아닌 새 절\n\n글\n", DESIGN.replace("## Goals", "## Goals 2")):
            self.assertNotEqual(H.body_of("design.md", text), body)

    def test_plan_and_intent_bodies(self):
        self.assertEqual(H.body_of("plan-1.md", "# 계획\n\n## 결정 기록\n\n- x\n\n"), "# 계획\n\n## 결정 기록\n\n- x")
        intent = "---\njob: E1\n---\n\n## 목표\n\n목표 글\n\n## 지시 원문\n\n## 결정 기록\n받은 말 안의 제목 꼴\n\n## 하지 않을 것\n\n- 없음\n\n## 결정 기록\n"
        body = H.body_of("INTENT.md", intent)
        self.assertIn("받은 말 안의 제목 꼴", body)
        self.assertEqual(H.body_of("INTENT.md", intent + "\n- 결정 · 2026-11-18 · 「글」\n"), body)
        self.assertNotEqual(H.body_of("INTENT.md", intent.replace("목표 글", "다른 목표")), body)

    def test_body_comparison_is_exact_except_the_blank_tail(self):   # J4
        base = "# 계획\n\n본문 하나\n본문 둘"
        for name in ("plan-1.md", "design.md", "INTENT.md"):
            self.assertEqual(H.body_of(name, base + "\n\n\n"), H.body_of(name, base), name + " — 끝의 빈 줄만 떼어 낸다")
            self.assertNotEqual(H.body_of(name, base.replace("본문 하나", "본문 하나 ")), H.body_of(name, base), name + " — 줄 안의 줄 끝 공백은 다른 본문이다")
            self.assertNotEqual(H.body_of(name, "\n" + base), H.body_of(name, base), name + " — 앞 빈 줄은 다른 본문이다")
            self.assertNotEqual(H.body_of(name, base + "\n  "), H.body_of(name, base), name + " — 공백만 든 끝 줄은 빈 줄이 아니다")


    def test_all_blank_text_trims_to_empty(self):
        for name in ("design.md", "INTENT.md", "plan-1.md"):
            self.assertEqual(H.body_of(name, "\n\n"), "", name)

    def test_level1_heading_ends_deferred_but_not_record(self):   # K20 — 지금 동작
        deferred = "# 설계\n\n### Deferred to plan\n\n| a |\n\n# 새 최상위\n\n새 글\n"
        body = H.body_of("design.md", deferred)
        self.assertIn("# 새 최상위", body)
        self.assertIn("새 글", body)
        self.assertNotIn("| a |", body)
        record = "# 설계\n\n## 결정 기록\n\n- D1\n\n# 새 최상위\n\n새 글\n"
        body = H.body_of("design.md", record)
        self.assertNotIn("# 새 최상위", body)
        self.assertNotIn("새 글", body)
        self.assertNotIn("- D1", body)

    def test_record_title_with_space_or_cr_is_body(self):   # K20 — 지금 동작: 제목은 글자 그대로만 기록 절이다
        for title in ("## 결정 기록 ", "## 결정 기록\r"):
            self.assertIn("아래 줄", H.body_of("design.md", "# 설계\n\n%s\n아래 줄\n" % title), repr(title))
            self.assertIn("아래 줄", H.body_of("INTENT.md", "## 목표\n\n%s\n아래 줄\n" % title), repr(title))
        self.assertNotIn("아래 줄", H.body_of("design.md", "# 설계\n\n## 결정 기록\n아래 줄\n"))   # 양성 대조


if __name__ == "__main__":
    unittest.main()
