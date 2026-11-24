#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""workflow_superpowers.py — superpowers 계획 · 원장의 꼴을 읽는 변환기(R1 AC17 · AC27).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_workflow_superpowers.py
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[3]
SCRIPTS = REPO / "plugins" / "spec-distill" / "scripts"
sys.path.insert(0, str(SCRIPTS))
import check_bundle_coverage as cbc  # noqa: E402
import conductor_state as cs  # noqa: E402
import team_files as F  # noqa: E402
import workflow_superpowers as WS  # noqa: E402

H = "a" * 40

PLAN = ("# 계획\n\n## Global\n\nAC1 은 여기 있어도 세지 않는다\n\n### Task 1: 하나 (AC2)\n\n```\n### Task 9: 펜스 안\n```\n\n"
        "### Task 2: 둘\n\nAC3\n\n### 다른 절\n\nAC4\n\n### Task 3: 셋\n")
LEDGER = ("# SDD ledger — plan: docs/p.md\n\n- Task 1: complete (커밋 없음 — 읽기뿐)\n- Ruling: R-A — 하나 — 둘 — 셋\n"
          "- Task 2: 구현자 DONE_WITH_CONCERNS (abc1234)\n- Task 2: fix round 1/5 (1 addressed)\n"
          "- Task 2: complete (commits d391105..d91837e — 둘, review clean after round 1)\nRuling: R-A — 하나 — 둘 — 셋\n"
          "* Ruling: R-B — 넷\n- Task 2: complete (commits 1111111..2222222, review clean)\n- Task 5: 진행 중\n")


class Plan(unittest.TestCase):
    def test_task_sections(self):
        text = WS.task_text(PLAN)
        self.assertIn("### Task 1: 하나 (AC2)", text)
        self.assertIn("### Task 9: 펜스 안", text)      # 펜스 안 줄은 절 경계가 아니고 본문에 든다
        self.assertNotIn("AC1", text)
        self.assertNotIn("AC4", text)
        self.assertEqual(WS.task_total(PLAN), 3)          # 펜스 안의 제목 꼴은 세지 않는다


class Ledger(unittest.TestCase):
    def test_lines_in_ledger_order(self):
        self.assertEqual(WS.ledger_lines(LEDGER, 3), ["Task 1/3: 끝 — 없음", "Ruling: R-A — 하나 — 둘 — 셋",
                                                     "Task 2/3: 끝 — d91837e", "Ruling: R-B — 넷"])
        self.assertEqual(WS.ledger_lines("", 3), [])

    def test_lines_that_carry_nothing_are_skipped(self):   # 0 번 완료 · 글이 빈 Ruling · 꼴 밖의 줄은 내지 않는다
        text = "- Task 0: complete (commits aaaaaaa..bbbbbbb)\n- Ruling:\n- Task 7 complete\n끝 — 없음\n"
        self.assertEqual(WS.ledger_lines(text, 3), [])

    def test_lines_are_read_back_by_the_result_reader(self):   # 변환기가 낸 줄을 결과 파일 읽기가 그대로 읽는다
        body = "\n".join(WS.ledger_lines(LEDGER, 3)) + "\n"
        r = F.parse_result("---\ntype: job-result\nstage: implement\nattempt: 1\nrole: worker\nhead: %s\nbundle_at: %s\njob_at: %s\n---\n\n%s"
                           % (H, H, H, body))
        self.assertEqual((r.problems, F.progress_of(r)), ([], (2, 3, None)))
        self.assertEqual(len(r.rulings), 2)


class Place(unittest.TestCase):
    def test_sentences(self):
        self.assertEqual(WS.place_sentence("r/t/jobs/R3/design.md", "design"), "설계문서는 기본 자리 대신 r/t/jobs/R3/design.md 에 쓴다.")
        self.assertEqual(WS.place_sentence("r/t/jobs/R3/plan-2.md", "plan"), "계획은 기본 자리 대신 r/t/jobs/R3/plan-2.md 에 쓴다.")
        self.assertRaises(ValueError, WS.place_sentence, "x", "implement")


class OnePlaceForTheTaskShape(unittest.TestCase):   # AC17 — 변환기 밖에 그 꼴을 읽는 코드가 없다
    def test_only_the_adapter_spells_the_heading(self):
        hits = [p.name for p in sorted(SCRIPTS.glob("*.py"))
                if p.name != "workflow_superpowers.py" and WS.TASK_HEAD in p.read_text(encoding="utf-8")]
        self.assertEqual(hits, [])
        self.assertIn(WS.TASK_HEAD, (SCRIPTS / "workflow_superpowers.py").read_text(encoding="utf-8"))   # 양성 대조
        self.assertGreater(len(list(SCRIPTS.glob("*.py"))), 40)

    def test_plan_check_reads_through_the_adapter(self):
        self.assertIs(cbc.task_text, WS.task_text)
        self.assertFalse(hasattr(cbc, "plan_task_text"))
        spec = "## Acceptance Criteria\n\n- AC1: 가\n- AC2: 나\n- AC3: 다\n- AC4: 라\n"
        self.assertEqual(cbc.check_plan(spec, PLAN)["missing"], ["AC1", "AC4"])



class OneRulingRule(unittest.TestCase):   # R3 AC18 — 판정 줄 규칙 하나(Q1 = 가)
    CASES = (("- Ruling: 가", "가"), ("Ruling: 나", "나"), ("Task 3: Ruling: 다", "다"),
             ("- **Ruling: 라**", "라**"), ("- parked — x — Ruling: 마", "마"),
             ("원장의 `Ruling:` 줄을 읽는다", "` 줄을 읽는다"), ("판정 없음", None), ("Ruling:", None))

    def test_the_rule(self):
        for line, said in self.CASES:
            self.assertEqual(WS.ruling_said(line), said, line)

    def test_every_ledger_reader_uses_the_rule(self):   # 붉어지는 변이: 둘 가운데 하나가 자기 규칙으로 돌아간다
        text = "\n".join(line for line, _said in self.CASES)
        picked = [l for l, s in self.CASES if s is not None]
        self.assertEqual(cs.ledger_rulings(text), [l.strip() for l in picked])
        self.assertEqual(WS.ledger_lines(text, 3), ["Ruling: " + s for _l, s in self.CASES if s is not None])
        with mock.patch.object(WS, "ruling_said", return_value=None):   # 함수를 바꾸면 둘의 답이 함께 바뀐다
            self.assertEqual((cs.ledger_rulings(text), WS.ledger_lines(text, 3)), ([], []))

    def test_result_file_grammar_is_unchanged(self):   # 결과 파일 기계 줄은 줄 머리 — 형식 정본의 계약 · 빈 판정 줄도 지금처럼 판정
        r = F.parse_result("---\ntype: job-result\nstage: plan\nattempt: 1\nrole: worker\nhead: %s\nbundle_at: %s\njob_at: %s\n---\n\nRuling: 가\nRuling:\n메모 — Ruling: 나\n" % (("a" * 40,) * 3))
        self.assertEqual(r.rulings, ["Ruling: 가", "Ruling:"])

    def test_the_mark_lives_in_one_place(self):   # S1 — 「한 곳」 락. 붉어지는 변이: 다른 스크립트에 "Ruling:" 글자를 둔다
        hits = sorted(p.name for p in SCRIPTS.glob("*.py") if '"Ruling:"' in p.read_text(encoding="utf-8"))
        self.assertEqual(hits, ["workflow_superpowers.py"])


if __name__ == "__main__":
    unittest.main()
