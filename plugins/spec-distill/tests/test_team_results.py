#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""team_files.py — 결과 파일 · 막힘 파일 · 결정 기록 줄의 글(R1 AC10 · AC27 · AC29 의 읽는 규칙).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_team_results.py
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SCRIPTS = REPO / "plugins" / "spec-distill" / "scripts"
sys.path.insert(0, str(SCRIPTS))
import team_files as F  # noqa: E402

H = "a" * 40
B = "b" * 40
J = "c" * 64


def result(body="", **over):
    keys = dict(type="job-result", stage="implement", plan="1", attempt="2", role="worker", head=H, bundle_at=B, job_at=J)
    keys.update(over)
    head = "".join("%s: %s\n" % (k, v) for k, v in keys.items() if v is not None)
    return "---\n" + head + "---\n\n" + body


class Parse(unittest.TestCase):
    def test_reads_head_and_machine_lines(self):
        r = F.parse_result(result("Task 1/3: 끝 — abc1234\nRuling: R-A — 하나 — 둘 — 셋\n메모 한 줄\nTask 2/3: 끝 — 없음\n"
                                  "AC9: 구현됨 — a.py\n규칙 반증: [테스트] 고친 곳엔 — 테스트가 없는 파일이었다\n산출물: docs/x.md\n끝 — " + H + "\n"))
        self.assertEqual(r.problems, [])
        self.assertEqual((r.stage, r.plan, r.attempt, r.role, r.head, r.bundle_at, r.job_at), ("implement", 1, 2, "worker", H, B, J))
        self.assertEqual(r.tasks, [(1, 3, "끝", "abc1234"), (2, 3, "끝", "없음")])
        self.assertEqual(r.rulings, ["Ruling: R-A — 하나 — 둘 — 셋"])
        self.assertEqual((r.outputs, r.end, len(r.refutes)), (["docs/x.md"], H, 1))
        self.assertIn("AC9: 구현됨 — a.py", r.machine_text)

    def test_fenced_lookalikes_are_body(self):   # Review Focus 1
        r = F.parse_result(result("Task 1/2: 끝 — abc1234\n```\n끝 — " + H + "\nAC3: 구현됨 — 인용\nTask 9/2: 끝 — x\n산출물: no.md\n```\n"))
        self.assertEqual((r.problems, r.end, r.outputs, r.tasks), ([], None, [], [(1, 2, "끝", "abc1234")]))
        self.assertNotIn("AC3:", r.machine_text)
        indented = F.parse_result(result("  ```\n끝 — " + H + "\n  ```\n"))   # 줄 머리 공백 뒤 펜스도 펜스다
        self.assertEqual((indented.problems, indented.end), ([], None))
        lead = F.parse_result(result("  끝 — " + H + "\n"))   # 줄 머리가 아니면 기계 줄이 아니다
        self.assertEqual((lead.problems, lead.end), ([], None))

    def test_line_endings(self):   # Review Focus 1
        text = result("Task 1/1: 끝 — abc1234\n끝 — " + H)
        for variant in (text, text.replace("\n", "\r\n"), text + "\n\n"):
            r = F.parse_result(variant)
            self.assertEqual((r.problems, r.end, r.head), ([], H, H), repr(variant[-12:]))
        self.assertTrue(F.parse_result("﻿" + text).problems)

    def test_problems_name_what_is_wrong(self):
        for text, word in ((result(), None), ("본문뿐\n", "머리"), ("---\ntype: job-result\n", "닫히지"), (result(type="job-blocked"), "type"),
                           (result(stage="deploy"), "stage"), (result(attempt="0"), "attempt"), (result(attempt="02"), "attempt"),
                           (result(plan="0"), "plan"), (result(role="reviewer"), "role"), (result(head="abc1234"), "head"),
                           (result(bundle_at=None), "bundle_at"), (result(job_at="x" * 40), "job_at"),
                           (result("Task 2: 끝 — a\n"), "Task"), (result("Task 1/2: 진행 — a\n"), "Task"),
                           (result("끝 — " + H + "\n끝 — " + H + "\n"), "끝"), (result("끝 — " + H + "\nRuling: 뒤\n"), "끝"),
                           (result("산출물: \n"), "산출물")):
            problems = F.parse_result(text).problems
            if word is None:
                self.assertEqual(problems, [])
            else:
                self.assertTrue(any(word in p for p in problems), (word, problems))
        self.assertIsNone(F.parse_result(result(plan=None)).plan)   # 계획 번호가 없는 결과 파일

    def test_machine_lines_after_end(self):   # 「끝」 뒤의 기계 줄은 종류마다 사유다
        for tail in ("Task 1/1: 끝 — a", "AC1: 구현됨 — x", "규칙 반증: [가] 나 — 다", "산출물: x.md"):
            problems = F.parse_result(result("끝 — " + H + "\n" + tail + "\n")).problems
            self.assertTrue(any("끝" in p for p in problems), (tail, problems))
        self.assertEqual(F.parse_result(result("끝 — " + H + "\n메모\n")).problems, [])   # 기계 줄이 아닌 글은 괜찮다


class Progress(unittest.TestCase):
    def p(self, body):
        return F.progress_of(F.parse_result(result(body)))

    def test_numbers(self):
        self.assertEqual(self.p(""), (None, None, "진행 줄 없음"))
        self.assertEqual(self.p("Task 1/7: 끝 — a\nTask 3/7: 끝 — b\n"), (3, 7, None))
        self.assertEqual(self.p("Task 1/7: 끝 — a\nTask 2/7: 막힘 — b\n"), (1, 7, None))   # Q7
        for body in ("Task 9/7: 끝 — a\n", "Task 0/7: 끝 — a\n", "Task 1/0: 끝 — a\n", "Task 1/7: 끝 — a\nTask 2/8: 끝 — b\n"):
            done, total, why = self.p(body)
            self.assertEqual((done, total), (None, None), body)
            self.assertTrue(why.startswith("진행 줄 깨짐 — "), why)


class BlockedFile(unittest.TestCase):
    TEXT = "---\ntype: job-blocked\nstage: implement\nplan: 1\nattempt: 2\nhead: %s\n---\n\n## 무엇에 막혔나\n\n가\n\n## 풀려면 무엇이 필요한가\n\n나\n"

    def test_shape(self):
        b = F.parse_blocked(self.TEXT % H)
        self.assertEqual((b.problems, b.stage, b.plan, b.attempt, b.head), ([], "implement", 1, 2, H))
        for bad in (self.TEXT.replace("job-blocked", "job-result") % H, self.TEXT.replace("## 풀려면 무엇이 필요한가", "## 다음") % H,
                    (self.TEXT % H) + "\n## 덧붙임\n", self.TEXT % "zz", (self.TEXT % H).replace("## 무엇에 막혔나\n\n가\n\n", "")):
            self.assertTrue(F.parse_blocked(bad).problems, bad[-40:])

    def test_fenced_heading_is_body_and_no_plan(self):
        fenced = (self.TEXT % H) + "\n```\n## 덧붙임\n```\n"
        self.assertEqual(F.parse_blocked(fenced).problems, [])
        b = F.parse_blocked((self.TEXT % H).replace("plan: 1\n", ""))
        self.assertEqual((b.problems, b.plan), ([], None))
        self.assertTrue(F.parse_blocked("본문뿐\n").problems)


INTENT = ("---\ntype: job\njob: R3\nkind: epic\nroadmap: r/t/roadmap.md\nbranch:\npaths: []\n---\n\n## 목표\n\n가\n\n## 지시 원문\n\n"
          "- 범위: intent/original.md 2–3행\n\n## 하지 않을 것\n\n- 없음\n\n## 결정 기록\n")


class Decisions(unittest.TestCase):
    def test_append_into_empty_then_below(self):
        one = F.append_decision(INTENT, "spec 승인 · 2026-11-20 · 「이대로 승인 (권장)」")
        self.assertEqual(one, INTENT + "\n- spec 승인 · 2026-11-20 · 「이대로 승인 (권장)」\n")
        two = F.append_decision(one, "- 결정 · 2026-11-21 · 막힘을 풀었다")
        self.assertEqual(two, one + "- 결정 · 2026-11-21 · 막힘을 풀었다\n")
        self.assertEqual(F.append_decision(two, "- 결정 · 2026-11-21 · 막힘을 풀었다"), two)   # 같은 줄은 한 번
        self.assertEqual(F.decision_lines(two), ["- spec 승인 · 2026-11-20 · 「이대로 승인 (권장)」", "- 결정 · 2026-11-21 · 막힘을 풀었다"])
        self.assertTrue(two.startswith(INTENT))   # 앞 바이트 그대로

    def test_kinds_and_shapes(self):
        self.assertEqual(F.DECISION_KINDS, ("spec 승인", "병렬 답", "계획 검토", "결과 받음", "예약 밖 변경", "넘김 확인", "결정"))
        ok = ["- 넘김 확인 · R1 · 0a1b2c3d · 계획에 넣었다", "- 예약 밖 변경 · 2026-11-20 · README 한 줄",
              "- 결과 받음 · 2026-11-20 · 「implement-plan-1-2.md · %s · 결과 대조: 통과 — …」" % H]
        for line in ok:
            self.assertIsNone(F.decision_problem(line), line)
        bad = ["- 메모 · 2026-11-20 · 글", "- 결정 · 11/20 · 글", "- 결정 · 2026-02-30 · 글", "- 결정 · 2026-11-20 · ", "- 결정",
               "- 넘김 확인 · 2026-11-20 · 글", "- 결과 받음 · 2026-11-20 · implement-1.md · %s · 글" % H,
               "- 결과 받음 · 2026-11-20 · 「BLOCKED.md · %s · 글」" % H, "- 결과 받음 · 2026-11-20 · 「implement-1.md · abc1234 · 글」"]
        self.assertTrue(F.decision_problem("결정 · 2026-11-20 · 대시 없음"))   # 줄 그대로는 대시가 있어야 한다(덧붙일 때만 대시를 붙여 준다)
        for line in bad:
            self.assertTrue(F.decision_problem(line), line)
            self.assertRaises(F.FormatError, F.append_decision, INTENT, line)
        for line in ("- 결정 · 2026-11-20 · 한 줄\n둘째 줄", "- 결정 · 2026-11-20 · 가 나", "- 결정 · 2026-11-20 · 가\r나"):
            self.assertTrue(F.decision_problem(line), repr(line))
            self.assertRaises(F.FormatError, F.append_decision, INTENT, line)

    def test_heading_lookalike_in_received_words(self):   # 받은 말 안의 `## 결정 기록` 꼴 줄
        task = INTENT.replace("kind: epic", "kind: task").replace("- 범위: intent/original.md 2–3행", "받은 말\n## 결정 기록\n- 결정 · 흉내")
        out = F.append_decision(task, "- 결정 · 2026-11-20 · 진짜")
        self.assertEqual(F.decision_lines(out), ["- 결정 · 2026-11-20 · 진짜"])
        self.assertIn("받은 말\n## 결정 기록\n- 결정 · 흉내", F.intent_sections(out)["지시 원문"])


class ReceivedLines(unittest.TestCase):
    def test_roundtrip_and_broken(self):
        line = F.received_line("2026-11-20", "implement-plan-1-2.md", H, "결과 대조: 통과 — 글")
        self.assertEqual(line, "- 결과 받음 · 2026-11-20 · 「implement-plan-1-2.md · %s · 결과 대조: 통과 — 글」" % H)
        text = F.append_decision(F.append_decision(INTENT, line), F.received_line("2026-11-22", "implement-plan-1-3.md", J, "둘째"))
        got, broken = F.received(text)
        self.assertEqual([(r.date, r.name, r.commit, r.first) for r in got],
                         [("2026-11-20", "implement-plan-1-2.md", H, "결과 대조: 통과 — 글"), ("2026-11-22", "implement-plan-1-3.md", J, "둘째")])
        self.assertEqual(broken, [])
        hand = INTENT + "\n- 결과 받음 · 2026-11-20 · implement-1.md 받았다\n"   # 손으로 쓴 꼴이 깨진 줄은 세지 않고 따로 낸다
        self.assertEqual(F.received(hand), ([], ["- 결과 받음 · 2026-11-20 · implement-1.md 받았다"]))
        self.assertRaises(F.FormatError, F.received_line, "2026-11-20", "BLOCKED.md", H, "글")

    def test_bad_commit_and_same_name_twice(self):
        short = "- 결과 받음 · 2026-11-20 · 「implement-1.md · abc1234 · 글」"
        self.assertEqual(F.received(INTENT + "\n" + short + "\n"), ([], [short]))
        text = INTENT
        for day, commit in (("2026-11-20", H), ("2026-11-21", B)):   # 같은 결과 파일을 두 번 받으면 둘 다 순서대로 나온다 — 뒤의 것이 이긴다
            text = F.append_decision(text, F.received_line(day, "implement-1.md", commit, "글"))
        got, broken = F.received(text)
        self.assertEqual(([r.commit for r in got], broken), ([H, B], []))
        self.assertEqual(got[-1].raw, "- 결과 받음 · 2026-11-21 · 「implement-1.md · %s · 글」" % B)
        self.assertEqual(F.received(INTENT), ([], []))


if __name__ == "__main__":
    unittest.main()
