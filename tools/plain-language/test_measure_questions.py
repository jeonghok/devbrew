# -*- coding: utf-8 -*-
import json
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import measure_questions as mq  # noqa: E402

_n = [0]


def _uid():
    _n[0] += 1
    return "q%04d" % _n[0]


def skill(name, uuid=None):
    return {"type": "assistant", "uuid": uuid or _uid(), "message": {"content": [
        {"type": "tool_use", "name": "Skill", "input": {"skill": name}}]}}


def ask(*questions, uuid=None, unparsed=False):
    qs = [{"question": t, "options": [{"label": lb, "description": d} for lb, d in opts]}
          for t, opts in questions]
    inp = {"questions": qs}
    if unparsed:
        inp = {"__unparsedToolInput": {"raw": json.dumps(inp, ensure_ascii=False)}}
    return {"type": "assistant", "uuid": uuid or _uid(), "message": {"content": [
        {"type": "tool_use", "name": "AskUserQuestion", "input": inp}]}}


def result(text, as_list=False):
    content = [{"type": "text", "text": text}] if as_list else text
    return {"type": "user", "uuid": _uid(), "message": {"content": [
        {"type": "tool_result", "content": content}]}}


def write(path, rows):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")


class MeasureQuestions(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    def f(self, name="a.jsonl"):
        return os.path.join(self.dir, name)

    def test_skill_is_the_one_called_just_before(self):
        write(self.f(), [
            skill("spec-distill:pm-interview"), ask(("질문 A", [("가", "x"), ("나", "y")])),
            skill("spec-distill:spec-review"), ask(("질문 B", [("가", "x"), ("나", "y")])),
        ])
        qs = mq.scan([self.dir])
        self.assertEqual([q.skill for q in qs], ["spec-distill:pm-interview", "spec-distill:spec-review"])

    def test_no_skill_before(self):
        write(self.f(), [ask(("질문", [("가", "x"), ("나", "y")]))])
        self.assertEqual(mq.scan([self.dir])[0].skill, "(없음)")

    def test_counts(self):
        both = "얻음: 가 · 내줌: 나"
        write(self.f(), [
            skill("spec-distill:spec-review"),
            ask(
                ("위에 적었다 그러니 고르라", [("가", "x"), ("나", "y")]),
                ("추천이 있다", [("가 (권장)", both), ("나", both)]),
                ("추천이 있으나 대가 없음", [("가 (Recommended)", both), ("나", "얻음: 만 있다")]),
                ("본문\n전문: 길고 긴 글", [("고친다(채택) — 요약", "z"), ("그대로 둔다", "w")]),
            ),
        ])
        s = mq.summarize(mq.scan([self.dir]), ["위에 적었다"])
        self.assertEqual(s["questions"], 4)
        self.assertEqual(s["out_of_window"], 1)
        self.assertEqual(s["recommended"], 2)
        self.assertEqual(s["recommended_all_tradeoff"], 1)
        self.assertEqual(s["review_decision"], 1)
        self.assertEqual(s["review_decision_with_fulltext"], 1)

    def test_review_decision_without_fulltext(self):
        write(self.f(), [
            skill("spec-distill:spec-review"),
            ask(("본문 전문: 은 줄 머리가 아니다", [("기각", "x"), ("보류", "y")])),
        ])
        s = mq.summarize(mq.scan([self.dir]), [])
        self.assertEqual((s["review_decision"], s["review_decision_with_fulltext"]), (1, 0))

    def test_phrase_in_option_description(self):
        write(self.f(), [
            skill("quality-gates:quality-pipeline"),
            ask(("질문", [("가", "이유는 질문 위 글에 있다"), ("나", "y")])),
        ])
        self.assertEqual(mq.summarize(mq.scan([self.dir]), ["이유는 질문 위 글에"])["out_of_window"], 1)

    def test_duplicate_uuid_counted_once(self):
        row = ask(("질문", [("가", "x"), ("나", "y")]), uuid="dup1")
        write(self.f("a.jsonl"), [skill("spec-distill:spec-review"), row])
        write(self.f("sub/b.jsonl"), [skill("spec-distill:spec-review"), row])
        self.assertEqual(mq.summarize(mq.scan([self.dir]), [])["questions"], 1)

    def test_pair_by_finding_id_not_nearest_gate(self):
        write(self.f(), [
            skill("spec-distill:spec-review"),
            result("라운드 1\n- 요약 가 (aaaaaaaa#r1.1)\n  그대로 두면: 나쁨\n  고치면: 좋음\n"
                   "- 요약 나 (bbbbbbbb#r1.2)\n  그대로 두면: 몰라\n"),
            result("- 다른 요약 (cccccccc#r2.1)\n  그대로 두면: 다름\n", as_list=True),
            ask(("질문", [("고친다", "지적 (aaaaaaaa#r1.1)"), ("그대로 둔다", "y")])),
        ])
        q = mq.scan([self.dir])[0]
        self.assertIn("요약 가", q.gate_blocks["aaaaaaaa#r1.1"])
        self.assertIn("고치면: 좋음", q.gate_blocks["aaaaaaaa#r1.1"])
        self.assertNotIn("요약 나", q.gate_blocks["aaaaaaaa#r1.1"])
        self.assertIn("다름", q.gate_blocks["cccccccc#r2.1"])

    def test_non_devbrew_skill_excluded_from_summary(self):
        write(self.f(), [
            skill("superpowers:brainstorming"),
            ask(("질문", [("가 (권장)", "x"), ("나", "y")])),
        ])
        qs = mq.scan([self.dir])
        self.assertEqual(len(qs), 1)
        self.assertEqual(mq.summarize(qs, [])["questions"], 0)

    def test_unparsed_tool_input(self):
        write(self.f(), [
            skill("spec-distill:spec-review"),
            ask(("질문", [("가", "x"), ("나", "y")]), unparsed=True),
        ])
        qs = mq.scan([self.dir])
        self.assertEqual([(q.text, q.options) for q in qs], [("질문", [("가", "x"), ("나", "y")])])

    def test_load_phrases_skips_comments_and_blanks(self):
        p = self.f("p.txt")
        with open(p, "w", encoding="utf-8") as fh:
            fh.write("# 주석\n\n문구 하나\n  \n문구 둘\n")
        self.assertEqual(mq.load_phrases(p), ["문구 하나", "문구 둘"])

    def test_shipped_phrase_file_loads(self):
        phrases = mq.load_phrases(str(Path(__file__).resolve().parent / "window_phrases.txt"))
        self.assertIn("위에 적었다", phrases)

    def test_bad_json_line_is_skipped(self):
        with open(self.f(), "w", encoding="utf-8") as fh:
            fh.write("not json\n")
            fh.write(json.dumps(skill("spec-distill:spec-review")) + "\n")
            fh.write(json.dumps(ask(("질문", [("가", "x"), ("나", "y")]))) + "\n")
        self.assertEqual(len(mq.scan([self.dir])), 1)

    def test_writes_nothing(self):
        write(self.f(), [skill("spec-distill:spec-review"), ask(("질문", [("가", "x"), ("나", "y")]))])
        before = sorted(os.listdir(self.dir))
        mq.main([self.dir])
        self.assertEqual(sorted(os.listdir(self.dir)), before)


if __name__ == "__main__":
    unittest.main()
