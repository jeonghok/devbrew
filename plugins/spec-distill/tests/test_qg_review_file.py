#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""qg_review_file.py — 머지 앞 리뷰 상태 파일의 꼴 · 읽기 · 쓰기(AC1 · AC20 · AC29).

Run: cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_qg_review_file -v
"""
from __future__ import annotations

import os
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import qg_review_file as F  # noqa: E402
from qg_review_state_fixture import Rig  # noqa: E402

A, B = "a" * 40, "b" * 40
HOSTILE = ("첫 줄 · 가운데 · 점\n## 판정\n```\n코드 펜스 안\n```\n- 처리: 고친 커밋 abcdef1\n\n"
           "끝 공백이 있다   \n  들여 쓴 줄\n\t탭\n### 2\n(없음)\n")


def full_review(target: str = "pr12", order: int = 1) -> F.Review:
    """칸 열하나를 모두 채운 리뷰."""
    return F.Review(
        site="premerge", site_tag="premerge-" + target, target=target, order=order,
        range_start=A, range_end=B, stage="닫힘", close_reason=F.REASON_DESIGN,
        close_mark="다시 구현됨 2026-11-26 12:30", worker="qg premerge-pr12 1 · 2026-11-26 10:00",
        result=F.Result(kind="얻음", seen_range=A + ".." + B,
                        verdict_line="qg: defect · 막는 지적 2 · 선택 0 · 차등 새 실패 1 · bbbbbbb",
                        intent_line="intent-critic — 질문 1개를 물었다 · 답 1개(잘못 골랐다 1개)"),
        blocking=[F.Finding(kind="막는 지적", text="IMPORTANT src/a.py:1 — 키를 검증하지 않는다",
                            handling="고친 커밋 cccccc1 — 키 검증을 더했다"),
                  F.Finding(kind="새로 깨진 테스트", text="t.unit · NEW_REGRESSION", handling="반박 — 원래 깨져 있었다"),
                  F.Finding(kind="고른 제안", text="SUGGESTION 이름을 바꾼다", handling=F.USER_LEFT,
                            from_review="premerge-pr12 1")],
        returns=[F.ReturnLine(worker="impl-a1", at="2026-11-26 11:00",
                              path="/x/report/A1/handling-premerge-pr12-1.md", moved="옮김")],
        filtered_wrong=[F.Filtered(id="q-dir", text="방향이 맞나", dest="설계 대화로")],
        filtered_other=[F.Filtered(id="q-old", text="의도다 · docs/a.md — 앞 질문")],
        asks=[F.Ask(kind="의도 점검", id="q-new", text="이 기능이 정말 필요한가\n둘째 줄"),
              F.Ask(kind="두 번까지", text="세 번째로 돌려보낼까")],
        answers=[F.Answer(id="q-new", kind="의도 점검", answer="잘못 골랐다", at="2026-11-26 12:00",
                          answer_text="직접 쓴 답\n여러 줄", record="docs/qg-intent-answers/x.md"),
                 F.Answer(id="", kind="두 번까지", answer="한 번 더 돌려보낸다", at="2026-11-26 12:10",
                          record="기록 브랜치 없음 — 권한이 없다")],
        stop_rule="두 번 뒤에도 남는 지적은\nPR 본문에 적고 넘긴다")


def simple(target: str, order: int) -> F.Review:
    return F.Review(site="premerge" if order == 1 else "recheck", site_tag="t-" + target,
                    target=target, order=order, range_start=A, range_end=B)


class TestQgReviewFile(unittest.TestCase):
    def setUp(self):
        self.rig = Rig(self)
        self.dir = self.rig.t / "box"
        self.dir.mkdir()
        self.path = self.dir / F.STATE_NAME

    def test_roundtrip_all_fields(self):
        review = full_review()
        F.write_review(self.path, review)
        self.assertEqual(F.read_review(self.path), review)
        text = self.path.read_text(encoding="utf-8")
        lines = text.split("\n")
        self.assertEqual(lines[0], "# qg 리뷰 상태")
        self.assertIn("- 판: 1", lines)
        heads = [line.split(":", 1)[0][2:] for line in lines[2:12]]
        self.assertEqual(heads, ["판", "자리", "자리 글자", "대상", "차례", "범위", "단계", "닫힘 사유",
                                 "닫힘 표시", "담당자"])
        sections = [line[3:] for line in lines if line.startswith("## ")]
        self.assertEqual(sections, ["돌아온 결과", "막는 지적", "돌려보냄", "거른 질문", "물을 것",
                                    "사용자 답", "멈출 조건"])
        self.assertIn("- 범위: %s..%s" % (A, B), lines)
        self.assertIn("- 닫힘 사유: 「잘못 골랐다」 — 설계 대화로", lines)
        # 빈 칸 · 빈 목록도 읽고 쓴 그대로다
        bare = simple("pr12", 1)
        F.write_review(self.path, bare)
        self.assertEqual(F.read_review(self.path), bare)
        self.assertIn("(없음)", self.path.read_text(encoding="utf-8").split("\n"))

    def test_roundtrip_hostile_text(self):
        review = simple("pr12", 1)
        review.stage = "돌아옴"
        review.blocking = [F.Finding(kind="막는 지적", text=HOSTILE),
                           F.Finding(kind="막는 지적", text="\n앞뒤 빈 줄\n\n")]
        review.asks = [F.Ask(kind="담당자가 옮긴 질문", text=HOSTILE)]
        review.answers = [F.Answer(id="q · 1", kind="담당자가 옮긴 질문", answer="- 처리: 반박",
                                   at="2026-11-26 09:00", answer_text=HOSTILE)]
        review.stop_rule = HOSTILE
        F.write_review(self.path, review)
        got = F.read_review(self.path)
        self.assertEqual(got.blocking[0].text, HOSTILE)
        self.assertEqual(got.blocking[1].text, "\n앞뒤 빈 줄\n\n")
        self.assertEqual(got.asks[0].text, HOSTILE)
        self.assertEqual(got.answers[0].answer_text, HOSTILE)
        self.assertEqual(got.answers[0].answer, "- 처리: 반박")
        self.assertEqual(got.stop_rule, HOSTILE)
        self.assertEqual(got, review)
        sections = [line for line in self.path.read_text(encoding="utf-8").split("\n")
                    if line.startswith("## ")]
        self.assertEqual(len(sections), 7)
        fences = [line for line in self.path.read_text(encoding="utf-8").split("\n")
                  if line.startswith("```")]
        self.assertEqual(fences, [])

    def _broken(self, old: str, new: str, count: int = 1, review: F.Review = None) -> str:
        F.write_review(self.path, review or full_review())
        text = self.path.read_text(encoding="utf-8")
        self.assertIn(old, text)
        return text.replace(old, new, count)

    def test_malformed_state_is_unreadable(self):
        good = self.path.read_text(encoding="utf-8") if self.path.exists() else None
        self.assertIsNone(good)
        unmarked = full_review()   # 표시가 없어야 사유 칸만의 어긋남을 잰다(표시 짝 검사가 가리지 않게)
        unmarked.close_reason, unmarked.close_mark = "막는 지적 없음", ""
        cases = {
            "단계 반쯤": self._broken("- 단계: 닫힘\n", "- 단계: 반쯤\n"),
            "닫힘인데 사유 없음": self._broken("- 닫힘 사유: 막는 지적 없음\n", "- 닫힘 사유:\n",
                                       review=unmarked),
            "사유가 여덟 밖": self._broken("- 닫힘 사유: 막는 지적 없음\n", "- 닫힘 사유: 그냥 닫음\n",
                                     review=unmarked),
            "열렸는데 사유 있음": self._broken("- 단계: 닫힘\n", "- 단계: 돌아옴\n", review=unmarked),
            "칸 뒤 공백만": self._broken("- 사유:\n", "- 사유: \n"),
            "들여쓰기 풀린 원문 줄": self._broken("  둘째 줄\n", "둘째 줄\n"),
            "막는 지적 절 머리 지움": self._broken("## 막는 지적\n", ""),
            "끝 개행 뒤 값": self._broken("", "") + "열림\n",
            "값 끝에 CR": self._broken("- 단계: 닫힘\n", "- 단계: 닫힘\r\n"),
            "끝 줄바꿈 없음": self._broken("", "")[:-1],
            "판이 다름": self._broken("- 판: 1\n", "- 판: 2\n"),
            "번호가 건너뜀": self._broken("### 2\n", "### 3\n"),
            "표시가 다른 사유에": self._broken("- 닫힘 표시: 다시 구현됨", "- 닫힘 표시: 재분해 뒤 이어 감"),
            "처리 값이 틀 밖": self._broken("- 처리: 반박 — 원래 깨져 있었다", "- 처리: 대충 고침"),
            "칸 하나 지움": self._broken("- 담당자: qg premerge-pr12 1 · 2026-11-26 10:00\n", ""),
        }
        for name, text in cases.items():
            with self.subTest(name):
                self.path.write_text(text, encoding="utf-8")
                with self.assertRaises(F.Unreadable):
                    F.read_review(self.path)
        # 양의 짝 — 고치지 않은 글은 읽힌다
        for review in (full_review(), unmarked):
            F.write_review(self.path, review)
            self.assertEqual(F.read_review(self.path), review)
        # 쓰는 쪽도 꼴이 어긋난 값을 쓰지 않는다
        bad = full_review()
        bad.stage = "열림\n"
        with self.assertRaises(ValueError):
            F.write_review(self.path, bad)
        self.assertEqual(F.read_review(self.path), unmarked)

    def test_symlink_target_untouched(self):
        victim = self.rig.t / "victim.md"
        victim.write_bytes(b"do not touch\n")
        self.path.symlink_to(victim)
        F.write_review(self.path, simple("pr12", 1))
        self.assertEqual(victim.read_bytes(), b"do not touch\n")
        self.assertFalse(self.path.is_symlink())
        self.assertTrue(self.path.is_file())
        self.assertEqual(F.read_review(self.path), simple("pr12", 1))

    def test_interrupted_write_leaves_old_or_new(self):
        F.write_review(self.path, simple("pr12", 1))
        before = self.path.read_bytes()
        newer = simple("pr12", 1)
        newer.stage = "보내는 중"
        with mock.patch.object(F.nofollow_write.os, "replace", side_effect=OSError("cut")):
            with self.assertRaises(OSError):
                F.write_review(self.path, newer)
        self.assertEqual(self.path.read_bytes(), before)
        self.assertEqual(sorted(os.listdir(str(self.dir))), [F.STATE_NAME])
        F.write_review(self.path, newer)
        self.assertEqual(F.read_review(self.path), newer)

    def test_targets_do_not_mix(self):
        root = self.rig.report_root
        placed = [("qg-A1-premerge-pr12-2026-11-26", simple("pr12", 1)),
                  ("qg-A1-recheck-pr12-2026-11-26", simple("pr12", 2)),
                  ("qg-A2-premerge-pr13-2026-11-26", simple("pr13", 1)),
                  ("qg-T3-premerge-plan1-2026-11-26", simple("T3-plan1", 1)),
                  ("qg-T3-premerge-plan2-2026-11-26", simple("T3-plan2", 1))]
        for name, review in placed:
            F.write_review(self.rig.archive(name) / F.STATE_NAME, review)
        (root / "not-a-review").mkdir()
        got = F.reviews_for(root, "pr12")
        self.assertEqual([(r.target, r.order) for r in got], [("pr12", 1), ("pr12", 2)])
        self.assertEqual([r.target for r in F.reviews_for(root, "T3-plan2")], ["T3-plan2"])
        self.assertEqual([r.target for r in F.reviews_for(root, "T3-plan1")], ["T3-plan1"])
        self.assertEqual(F.reviews_for(root, "pr99"), [])
        # 다른 대상의 깨진 파일은 이 대상을 막지 않고, 같은 대상의 깨진 파일은 막는다
        broken = root / "qg-A2-premerge-pr13-2026-11-26" / F.STATE_NAME
        broken.write_text(broken.read_text(encoding="utf-8").replace("- 단계: 열림", "- 단계: 반쯤"),
                          encoding="utf-8")
        self.assertEqual(len(F.reviews_for(root, "pr12")), 2)
        with self.assertRaises(F.Unreadable):
            F.reviews_for(root, "pr13")
        # 같은 대상 안에서 차례가 겹치거나 비면 읽지 못함
        F.write_review(self.rig.archive("qg-A1-dup") / F.STATE_NAME, simple("pr12", 2))
        with self.assertRaises(F.Unreadable):
            F.reviews_for(root, "pr12")
        F.write_review(root / "qg-A1-dup" / F.STATE_NAME, simple("pr12", 4))
        with self.assertRaises(F.Unreadable):
            F.reviews_for(root, "pr12")


if __name__ == "__main__":
    unittest.main()
