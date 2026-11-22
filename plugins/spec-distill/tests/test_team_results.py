#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""team_files.py — 결과 파일 · 막힘 파일 · 결정 기록 줄의 글(R1 AC10 · AC27 · AC29 의 읽는 규칙).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_team_results.py
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[3]
SCRIPTS = REPO / "plugins" / "spec-distill" / "scripts"
sys.path.insert(0, str(SCRIPTS))
import job_results  # noqa: E402
import team_files as F  # noqa: E402
import team_layout  # noqa: E402

H = "a" * 40
B = "b" * 40
J = "c" * 64
BOM = chr(0xFEFF)   # 보이지 않는 글자는 chr 로 적어 diff 에 보이게 한다
# str.splitlines() 가 줄을 나누는 글자 열하나(`\r\n` 포함)
LINE_BREAKS = [chr(c) for c in (0x0A, 0x0B, 0x0C, 0x0D, 0x1C, 0x1D, 0x1E, 0x85, 0x2028, 0x2029)] + ["\r\n"]


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

    def test_review_result_qg_block_is_not_machine_lines(self):   # R4 Review Focus 5 — 검수 결과 파일의 qg 기록 펜스
        qg = ("```text\n- 호출 · premerge-E1 · 1111111..2222222\n- 판정: 막는 지적 1\n"
              "AC1: 빠짐 — qg 지적 글이 이 꼴로 시작한다\n끝 — " + H + "\nTask 1/2: 끝 — abc1234\n"
              "Ruling: 인용된 판정\n산출물: quoted.md\n- 재리뷰 0 · 멈출 조건: 두 번 뒤 묻는다\n```\n")
        body = "반려 — a.py 의 입력 검사가 REVIEW.md 의 「테스트가 실패하면 반려」 에 걸렸다\n- qg 막는 지적: a.py:3 입력 검사 없음\n" + qg
        r = F.parse_result(result(body, stage="review", role="leader"))
        self.assertEqual((r.problems, r.end, r.tasks, r.rulings, r.outputs), ([], None, [], [], []))
        for quoted in ("AC1:", "끝 — ", "Task 1/2", "Ruling:", "산출물:"):
            self.assertNotIn(quoted, r.machine_text, quoted)
        bare = F.parse_result(result(body.replace("```text\n", "").replace("```\n", ""), stage="review", role="leader"))   # 양성 대조: 펜스를 벗기면 기계 줄로 읽힌다
        self.assertEqual(bare.end, H)
        self.assertTrue(any("줄 뒤에 기계 줄이 있다" in p for p in bare.problems), bare.problems)
        self.assertIn("AC1:", bare.machine_text)

    QUOTED = "끝 — " + H + "\nAC3: 구현됨 — 인용\nTask 9/2: 끝 — x\n산출물: no.md\n"
    REAL = "산출물: real.md\n"

    def fence_case(self, before, after, unclosed=False):
        """펜스 밖 진짜 줄은 읽고(산출물 real.md · 앞의 Task) 인용된 기계 줄 꼴은 읽지 않는다."""
        r = F.parse_result(result("Task 1/2: 끝 — abc1234\n" + before + self.QUOTED + after + self.REAL))
        label = repr(before + after)
        self.assertEqual((r.end, r.tasks, "AC3:" in r.machine_text), (None, [(1, 2, "끝", "abc1234")], False), label)
        if unclosed:
            self.assertEqual((r.outputs, [p for p in r.problems if "닫히지 않았다" in p]), ([], [F._UNCLOSED_FENCE]), label)
            self.assertEqual(r.problems, [F._UNCLOSED_FENCE], label)
        else:
            self.assertEqual((r.problems, r.outputs), ([], ["real.md"]), label)

    def test_fence_shapes(self):   # CommonMark 꼴 — 인용된 줄은 읽지 않고 펜스 밖의 진짜 줄은 읽는다
        self.fence_case("````\n```\n", "```\n````\n")                  # 긴 펜스가 짧은 펜스를 인용한다
        self.fence_case("~~~\n", "~~~\n")                              # 물결 펜스
        self.fence_case("```python\n", "```\n")                        # 정보 문자열
        self.fence_case("```\n~~~\n", "~~~\n```\n")                    # 다른 글자의 펜스는 닫지 않는다
        self.fence_case("  ```\n", "  ```\n")                          # 들여쓴 펜스(세 칸까지)
        self.fence_case("```\n", "", unclosed=True)                    # 닫히지 않은 펜스는 끝까지 펜스다
        self.fence_case("````\n", "```\n", unclosed=True)              # 더 짧은 줄은 닫지 못한다

    def test_short_closer_at_end_does_not_close(self):   # 파일 끝의 더 짧은 줄은 긴 펜스를 닫지 못한다
        for body in ("````\n" + self.QUOTED + "```\n", "```\n" + self.QUOTED + "~~~\n", "```\n" + self.QUOTED + "``` 글\n",
                     "````\n" + self.QUOTED + "```", "```\n" + self.QUOTED + "~~~"):   # 끝 줄바꿈이 없으면 짧은 줄이 마지막 줄이다
            r = F.parse_result(result(body))
            self.assertEqual((r.problems, r.end, r.outputs), ([F._UNCLOSED_FENCE], None, []), repr(body[-12:]))
        for body in ("````\n" + self.QUOTED + "````\n", "````\n" + self.QUOTED + "`````", "~~~\n" + self.QUOTED + "~~~"):   # 같거나 긴 줄은 닫는다(양성 대조)
            closed = F.parse_result(result(body))
            self.assertEqual((closed.problems, closed.end), ([], None), repr(body[-8:]))

    def test_non_fences_are_read(self):   # 펜스가 아닌 줄은 뒤의 진짜 줄을 가리지 않는다
        for opener in ("```x```\n", "    ```\n", "\t```\n"):
            r = F.parse_result(result(opener + self.REAL))
            self.assertEqual((r.problems, r.outputs), ([], ["real.md"]), repr(opener))

    def test_real_fence_after_non_fence_shape(self):   # 펜스 아닌 꼴(네 칸 들여쓴 백틱) 뒤의 진짜 펜스는 펜스다
        body = "    ```\n\n```\n끝 — abc1234\n```\n끝 — def5678\n"
        r = F.parse_result(result(body))
        self.assertEqual((r.end, r.problems), ("def5678", []))

    def test_line_endings(self):   # Review Focus 1
        text = result("Task 1/1: 끝 — abc1234\n끝 — " + H)
        for variant in (text, text.replace("\n", "\r\n"), text + "\n\n"):
            r = F.parse_result(variant)
            self.assertEqual((r.problems, r.end, r.head), ([], H, H), repr(variant[-12:]))
        bom = F.parse_result(BOM + text)   # 첫 글자가 BOM 이면 머리가 없다
        self.assertEqual(len(bom.problems), 1)
        self.assertTrue(bom.problems[0].startswith("머리(첫 줄"), bom.problems)

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
        for tail in ("Task 1/1: 끝 — a", "AC1: 구현됨 — x", "규칙 반증: [가] 나 — 다", "산출물: x.md", "Ruling: 뒤"):
            problems = F.parse_result(result("끝 — " + H + "\n" + tail + "\n")).problems
            self.assertTrue(any("줄 뒤에 기계 줄이 있다" in p for p in problems), (tail, problems))
        self.assertEqual(F.parse_result(result("끝 — " + H + "\n메모\n")).problems, [])   # 기계 줄이 아닌 글은 괜찮다

    def test_duplicate_head_key(self):
        text = result().replace("attempt: 2\n", "attempt: 2\nattempt: 3\n")
        r = F.parse_result(text)
        self.assertEqual((r.problems, r.attempt), (["머리 키 attempt 가 두 번 나온다"], 2))
        b = F.parse_blocked(BlockedFile.TEXT.replace("attempt: 2\n", "attempt: 2\nattempt: 3\n") % H)
        self.assertEqual(b.problems, ["머리 키 attempt 가 두 번 나온다"])

    def test_rules_at_is_optional_but_closed(self):   # R3 AC15
        R = "c" * 40
        self.assertIsNone(F.parse_result(result()).rules_at)
        r = F.parse_result(result().replace("job_at:", "rules_at: %s\njob_at:" % R, 1))
        self.assertEqual((r.rules_at, r.problems), (R, []))
        bad = F.parse_result(result().replace("job_at:", "rules_at: zz\njob_at:", 1))
        self.assertIsNone(bad.rules_at)
        self.assertIn("머리 rules_at 가 커밋 번호 꼴이 아니다: 'zz'", bad.problems)

    def test_task_numbers_with_leading_zero_are_not_task_lines(self):
        for line in ("Task 01/3: 끝 — a", "Task 1/03: 끝 — a", "Task 00/3: 끝 — a"):
            r = F.parse_result(result(line + "\n"))
            self.assertEqual(r.tasks, [], line)
            self.assertEqual(len(r.problems), 1, line)
            self.assertTrue(r.problems[0].startswith("Task 줄 꼴이 아니다"), r.problems)
            self.assertTrue(r.problems[0].endswith(": " + line), r.problems)   # 사유는 줄을 적힌 대로 싣는다


class Progress(unittest.TestCase):
    def p(self, body):
        return F.progress_of(F.parse_result(result(body)))

    def test_numbers(self):
        self.assertEqual(self.p(""), (None, None, "진행 줄 없음"))
        self.assertEqual(self.p("Task 1/7: 끝 — a\nTask 3/7: 끝 — b\n"), (3, 7, None))
        self.assertEqual(self.p("Task 1/7: 끝 — a\nTask 2/7: 막힘 — b\n"), (1, 7, None))   # Q7
        for body in ("Task 9/7: 끝 — a\n", "Task 0/7: 끝 — a\n", "Task 1/0: 끝 — a\n"):
            done, total, why = self.p(body)
            self.assertEqual((done, total), (None, None), body)
            self.assertTrue(why.startswith("진행 줄 깨짐 — "), why)

    def test_reason_carries_the_line_as_written(self):
        for line in ("Task 9/7: 끝 — a  b", "Task 0/7: 막힘 — 한  글 "):
            self.assertEqual(self.p(line + "\n"), (None, None, "진행 줄 깨짐 — " + line), line)

    def test_total_follows_the_last_line(self):   # 구현 중에 계획의 task 절이 늘거나 줄었다(U13)
        grew = "Task 1/5: 끝 — aaa1111\nTask 2/5: 끝 — bbb2222\nTask 3/6: 끝 — ccc3333\n"
        self.assertEqual(self.p(grew), (3, 6, None))
        shrank = "Task 1/5: 끝 — aaa1111\nTask 2/4: 막힘 — bbb2222\n"
        self.assertEqual(self.p(shrank), (1, 4, None))

    def test_a_number_above_its_own_total_is_still_broken(self):
        why = self.p("Task 6/5: 끝 — aaa1111\nTask 2/6: 끝 — bbb2222\n")[2]
        self.assertTrue(why.startswith("진행 줄 깨짐 — Task 6/5"), why)

    def test_reason_heads_are_constants(self):   # 계획 2 Task 7 수정 1 — 사유 머리는 한 곳(team_status 가 가져다 쓴다)
        self.assertEqual((F.PROGRESS_NONE, F.PROGRESS_BROKEN), ("진행 줄 없음", "진행 줄 깨짐"))
        self.assertEqual(self.p("")[2], F.PROGRESS_NONE)
        self.assertTrue(self.p("Task 9/7: 끝 — a\n")[2].startswith(F.PROGRESS_BROKEN + " — "))

    def test_lost_lines(self):   # 기계 줄을 빠뜨린 문제만 — 머리 없음 · 머리 안 닫힘 · 닫히지 않은 펜스 · 꼴이 아닌 Task 줄
        lost = lambda text: F.lost_lines(F.parse_result(text))   # noqa: E731
        good = result("Task 1/3: 끝 — a\n")
        self.assertEqual(lost(good), [])
        self.assertEqual(lost(good.replace("role: worker", "role: boss")), [])   # 머리 값 문제는 기계 줄을 빠뜨리지 않는다
        for text, head in ((BOM + good, "머리(첫 줄 `---`)가 없다"), ("---\ntype: job-result\n", "머리가 닫히지 않았다"),
                           (result("Task 1/3: 끝 — a\n```text\nTask 2/3: 끝 — b\n"), "본문의 코드 펜스가 닫히지 않았다"),
                           (result("Task 1/3: 끝 — a\nTask 03/3: 끝 — b\n"), "Task 줄 꼴이 아니다")):
            got = lost(text)
            self.assertEqual(len(got), 1, text)
            self.assertTrue(got[0].startswith(head), got)


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
        longer = (self.TEXT % H) + "\n````\n```\n## 덧붙임\n```\n````\n"
        self.assertEqual(F.parse_blocked(longer).problems, [])
        b = F.parse_blocked((self.TEXT % H).replace("plan: 1\n", ""))
        self.assertEqual((b.problems, b.plan), ([], None))
        self.assertTrue(F.parse_blocked("본문뿐\n").problems)

    def test_unclosed_fence_is_a_problem(self):
        b = F.parse_blocked((self.TEXT % H) + "\n```\n## 덧붙임\n")
        self.assertEqual(b.problems, [F._UNCLOSED_FENCE])


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

    def test_dash_is_prepended_and_same_line_counts_once(self):
        with_dash = F.append_decision(INTENT, "- 결정 · 2026-11-20 · 글")
        for first, second in (("- 결정 · 2026-11-20 · 글", "결정 · 2026-11-20 · 글"), ("결정 · 2026-11-20 · 글", "- 결정 · 2026-11-20 · 글")):
            out = F.append_decision(F.append_decision(INTENT, first), second)
            self.assertEqual(out, with_dash, (first, second))
            self.assertEqual(F.decision_lines(out), ["- 결정 · 2026-11-20 · 글"])

    def test_new_kinds_are_accepted(self):
        for line in ("- 흐름 승인 · 2026-11-18 · 「설계 없이 진행」 · INTENT.md@0123abcd · 근거 00000000-0000-4000-8000-00000000aaaa:00000000-0000-4000-8000-000000000001#1",
                     "- 걸음 건너뜀 · 2026-11-18 · 「건너뛴다」 · 계획 검토 plan 2 · INTENT.md@0123abcd · 근거 00000000-0000-4000-8000-00000000aaaa:00000000-0000-4000-8000-000000000001#1"):
            self.assertIsNone(F.decision_problem(line), line)
        self.assertEqual(F.DECISION_KINDS[:7], ("spec 승인", "병렬 답", "계획 검토", "결과 받음", "예약 밖 변경", "넘김 확인", "결정"))
        self.assertIsNotNone(F.decision_problem("- 흐름승인 · 2026-11-18 · 「설계 없이 진행」"))

    def test_kinds_and_shapes(self):
        self.assertEqual(F.DECISION_KINDS, ("spec 승인", "병렬 답", "계획 검토", "결과 받음", "예약 밖 변경", "넘김 확인", "결정", "흐름 승인", "걸음 건너뜀"))
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

    def test_every_line_separator_is_refused(self):   # str.splitlines() 가 나누는 글자 모두
        for sep in LINE_BREAKS:
            self.assertEqual(len(("a" + sep + "b").splitlines()), 2, repr(sep))   # 목록이 정말 줄 나눔 글자다
            for line in ("- 결정 · 2026-11-20 · 가" + sep + "나", "- 결정 · 2026-11-20 · 가" + sep):
                self.assertTrue(F.decision_problem(line), repr(line))
                self.assertRaises(F.FormatError, F.append_decision, INTENT, line)
        self.assertEqual(len(LINE_BREAKS), 11)

    def test_empty_line_has_its_own_reason(self):
        self.assertEqual(F.decision_problem(""), "빈 줄이다")
        self.assertRaises(F.FormatError, F.append_decision, INTENT, "")

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


class FakeGit:
    """결과 폴더의 이름 목록과 글을 돌려주는 작은 git — 이어짐을 세는 규칙만 잰다."""

    def __init__(self, files):
        self.files = files

    def names(self, tip, folder):
        prefix = folder.rstrip("/") + "/"
        return sorted(p[len(prefix):] for p in self.files if p.startswith(prefix))

    def blob(self, tip, path):
        return self.files.get(path)


class FailedStreak(unittest.TestCase):
    """job_results.failed_streak — 「끝」 줄이 있고 산 받음 줄이 없는 implement 시도가 이어지는 수(J12)."""

    TEAM = team_layout.team_from_roadmap("r/", "r/tm/roadmap.md")

    def build(self, attempts, received=(), blocked=False, other=(), bodies=None):
        """attempts: [(계획, 시도, 끝 줄 있음)]. received: 받음 줄을 적을 (계획, 시도). other: 다른 단계의 (단계, 계획, 시도) 끝난 결과."""
        files = {}
        for plan, attempt, ended in attempts:
            name = team_layout.result_name("implement", attempt, plan)
            body = (bodies or {}).get((plan, attempt))
            files[self.TEAM.job("E1", "results", name)] = result("산출물: a.md\n" + ("끝 — " + H + "\n" if ended else "") if body is None else body,
                                                                  plan=str(plan) if plan else None, attempt=str(attempt))
        for stage, plan, attempt in other:
            name = team_layout.result_name(stage, attempt, plan)
            files[self.TEAM.job("E1", "results", name)] = result("끝 — " + H + "\n", stage=stage, plan=str(plan), attempt=str(attempt))
        if blocked:
            files[self.TEAM.blocked("E1")] = "막힘"
        text = INTENT
        for plan, attempt in received:
            text = F.append_decision(text, F.received_line("2026-11-20", team_layout.result_name("implement", attempt, plan), H, "결과 대조: 통과 — x"))
        return FakeGit(files), text

    def streak(self, attempts, before, plan=1, received=(), passes=(), commit_differs=(), **kw):
        """passes: 대조를 통과하는 (계획, 시도). 그 밖의 시도는 대조 거절이다."""
        git, text = self.build(attempts, received=received, **kw)
        calls = []

        def fake_check(g, tip, team, job, name, newer_ok=False):
            calls.append((name, newer_ok))
            ok = any(team_layout.result_name("implement", a, p) == name for p, a in passes)
            return job_results.Check(ok, "", [] if ok else ["거절"], [], None)

        if commit_differs:   # 받음 줄의 커밋이 그 파일의 head 와 다르다
            for plan_, attempt in commit_differs:
                name = team_layout.result_name("implement", attempt, plan_)
                text = F.append_decision(text, F.received_line("2026-11-20", name, B, "결과 대조: 통과 — x"))
        with mock.patch.object(job_results, "check_result", fake_check):
            got = job_results.failed_streak(git, "tip", self.TEAM, "E1", text, plan, before)
        for _name, newer_ok in calls:
            self.assertTrue(newer_ok, "산 받음 줄을 다시 잴 때는 newer_ok=True 로 부른다")
        return got

    def test_table(self):
        self.assertEqual(self.streak([], 1), 0)
        self.assertEqual(self.streak([(1, 1, True)], 2), 1)
        self.assertEqual(self.streak([(1, 1, True), (1, 2, True)], 3), 2)
        # 1 은 받음(대조 통과) · 2 는 받음 줄 없음 — 1 에서 멈춘다
        self.assertEqual(self.streak([(1, 1, True), (1, 2, True)], 3, received=[(1, 1)], passes=[(1, 1)]), 1)
        # 손으로 쓴 받음 줄(꼴은 맞고 대조는 거절) — 산 받음 줄이 아니다
        self.assertEqual(self.streak([(1, 1, True), (1, 2, True)], 3, received=[(1, 1)]), 2)
        # 받음 줄의 커밋이 head 와 다르다(대조는 통과)
        self.assertEqual(self.streak([(1, 1, True)], 2, commit_differs=[(1, 1)], passes=[(1, 1)]), 1)
        # 도는 중인 시도(끝 줄 없음)는 이어짐을 끊는다
        self.assertEqual(self.streak([(1, 1, True), (1, 2, False)], 3), 0)
        self.assertEqual(self.streak([(1, 1, True), (1, 2, True), (1, 3, False)], 3), 2)
        # 계획 1 의 시도 하나 · 계획 2 의 시도 둘 — 계획 1 만 본다
        att = [(1, 1, True), (2, 1, True), (2, 2, True)]
        self.assertEqual(self.streak(att, 2, plan=1), 1)
        self.assertEqual(self.streak(att, 3, plan=2), 2)
        # 구현 시도만 센다 — design · plan 결과는 시도가 아니다
        self.assertEqual(self.streak([(1, 1, True)], 2, other=[("plan", 1, 1), ("plan", 1, 2)]), 1)
        # 막힘 파일은 시도가 아니다
        self.assertEqual(self.streak([(1, 1, True)], 2, blocked=True), 1)
        self.assertEqual(self.streak([(1, 1, True), (1, 2, True)], 3, blocked=True), 2)

    def test_ended_attempt_with_format_problems_counts(self):   # 끝났으나 꼴 문제가 있는 시도는 산 받음 줄을 가질 수 없는 실패다
        end = "끝 — " + H + "\n"
        for label, body in (("끝 줄 둘", "산출물: a.md\n" + end + end), ("끝 줄 뒤의 기계 줄", "산출물: a.md\n" + end + "산출물: b.md\n"),
                            ("끝 줄이 비었다", "산출물: a.md\n끝 —  \n")):
            git, text = self.build([(1, 1, True), (1, 2, True)], bodies={(1, 2): body})
            self.assertTrue(F.parse_result(result(body)).problems, label)
            with mock.patch.object(job_results, "check_result", lambda *a, **k: job_results.Check(True, "", [], [], None)):
                self.assertEqual(job_results.failed_streak(git, "tip", self.TEAM, "E1", text, 1, 3), 2, label)

    def test_blob_read_failure_is_unchecked(self):
        git, text = self.build([(1, 1, True)])
        del git.files[self.TEAM.result("E1", "implement", 1, 1)]
        git.names = lambda tip, folder: [team_layout.result_name("implement", 1, 1)]
        self.assertRaises(job_results.Unchecked, job_results.failed_streak, git, "tip", self.TEAM, "E1", text, 1, 2)

    def test_unreadable_attempt_breaks(self):
        git, text = self.build([(1, 1, True), (1, 2, True)])
        path = self.TEAM.result("E1", "implement", 2, 1)
        git.files[path] = "머리가 없는 글"
        self.assertEqual(job_results.failed_streak(git, "tip", self.TEAM, "E1", text, 1, 3), 0)


if __name__ == "__main__":
    unittest.main()
