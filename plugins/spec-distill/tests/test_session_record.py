#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""session_record.py — 세션 기록에서 질문 창의 답을 읽는다(AC5 · AC6).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_session_record.py
"""
from __future__ import annotations

import json
import os
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[3]
SCRIPTS = REPO / "plugins" / "spec-distill" / "scripts"
sys.path.insert(0, str(SCRIPTS))
sys.path.insert(0, str(REPO / "plugins" / "spec-distill" / "tests" / "fixtures"))
import session_fixture as SF  # noqa: E402
import session_record as R  # noqa: E402

SID = "00000000-0000-4000-8000-00000000aaaa"


class Base(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.d = tmp.name
        self.env = {"CLAUDE_CONFIG_DIR": self.d}


class Locate(Base):
    def test_finds_the_one_file(self):
        d, env = self.d, self.env
        SF.add_answer(d, SID, [("q", "a")])
        self.assertEqual(R.locate(SID, env), SF.record_path(d, SID))

    def test_missing_two_and_bad_names_are_unreadable(self):
        d, env = self.d, self.env
        for sid in (SID, "../" + SID, "short", ""):
            self.assertRaises(R.Unreadable, R.locate, sid, env)            # 없음 · 꼴 아님
        SF.add_answer(d, SID, [("q", "a")])
        SF.add_answer(d, SID, [("q", "a")], project="other")
        self.assertRaises(R.Unreadable, R.locate, SID, env)                 # 둘

    def test_a_trailing_newline_is_not_a_session_name(self):
        d, env = self.d, self.env
        SF.add_answer(d, SID, [("q", "a")])
        self.assertEqual(R.locate(SID, env), SF.record_path(d, SID))       # 양성 대조
        self.assertRaises(R.Unreadable, R.locate, SID + "\n", env)

    def test_subagent_files_are_not_session_files(self):
        d, env = self.d, self.env
        SF.add_answer(d, SID, [("q", "a")], subagent=True)
        self.assertRaises(R.Unreadable, R.locate, SID, env)
        self.assertRaises(R.Unreadable, R.locate, "agent-fixture", env)

    def test_config_dir_follows_the_environment(self):
        self.assertEqual(R.config_dir({"CLAUDE_CONFIG_DIR": "/x/y"}), Path("/x/y"))
        self.assertEqual(R.config_dir({"CLAUDE_CONFIG_DIR": ""}), Path.home() / ".claude")
        self.assertEqual(R.config_dir({}), Path.home() / ".claude")


class Answers(Base):
    def test_one_answer(self):
        d = self.d
        uid = SF.add_answer(d, SID, [("R2 @0123abcd — 질문", "승인 — 계획 담당자에게 (권장)")])
        got = R.answers(SF.record_path(d, SID))
        self.assertEqual(got, [R.Answer(SID, uid, 1, "R2 @0123abcd — 질문", "승인 — 계획 담당자에게 (권장)", R.HUMAN, "", "2026-01-01T12:00:00.000Z")])
        self.assertEqual(got[0].key, uid + "#1")
        self.assertEqual(R.find(SF.record_path(d, SID), uid + "#1"), got[0])
        for key in (uid + "#2", uid, "x#1", uid + "#0", uid + "#1\n"):
            self.assertIsNone(R.find(SF.record_path(d, SID), key), key)

    def test_each_question_of_one_call_has_its_own_label(self):
        d = self.d
        SF.add_answer(d, SID, [("첫 질문", "가"), ("둘째 질문", "나")])
        self.assertEqual([(a.index, a.question, a.label) for a in R.answers(SF.record_path(d, SID))],
                         [(1, "첫 질문", "가"), (2, "둘째 질문", "나")])

    def test_who(self):
        d = self.d
        for who in ("unknown", "other", "denied", "hook", "human"):
            SF.add_answer(d, SID, [("q " + who, "a")], who=who)
        got = R.answers(SF.record_path(d, SID))
        self.assertEqual([a.who for a in got], [R.UNKNOWN, R.UNKNOWN, R.NOT_HUMAN, R.NOT_HUMAN, R.HUMAN])
        self.assertEqual([bool(a.why) for a in got], [True, True, True, True, False])
        self.assertIn("permissionDecision", got[0].why)
        self.assertIn("fixture_other", got[1].why)
        self.assertIn("hook", got[3].why)

    def test_entrypoint(self):   # 사용자 2026-11-19 「cli 만 받는다」
        d = self.d
        SF.add_answer(d, SID, [("q sdk", "a")], entrypoint="sdk-cli")           # 프로그램이 대신 답한 세션 — permissionDecision 은 사람과 같다
        SF.add_answer(d, SID, [("q other", "a")], entrypoint="fixture_other")  # 잰 적 없는 값
        SF.add_answer(d, SID, [("q none", "a")], drop=("entrypoint",))          # 칸이 없다
        SF.add_answer(d, SID, [("q both", "a")], who="other", entrypoint="sdk-cli")   # 사람 아님이 먼저다
        SF.add_answer(d, SID, [("q cli", "a")])
        got = R.answers(SF.record_path(d, SID))
        self.assertEqual([a.who for a in got], [R.NOT_HUMAN, R.UNKNOWN, R.UNKNOWN, R.NOT_HUMAN, R.HUMAN])
        self.assertIn("sdk-cli", got[0].why)
        self.assertIn("entrypoint", got[1].why)
        self.assertIn("entrypoint", got[2].why)

    def test_not_human_comes_before_missing_columns(self):   # J2 「사람 아님이 먼저다」(F6)
        d = self.d
        SF.add_answer(d, SID, [("q a", "a")], who="unknown", entrypoint="sdk-cli")       # permissionDecision 없음 + sdk-cli
        SF.add_answer(d, SID, [("q b", "a")], who="hook", drop=("timestamp",))           # hook + timestamp 없음
        SF.add_answer(d, SID, [("q c", "a")], who="denied", drop=("timestamp",))         # 수락 아님 + timestamp 없음
        SF.add_answer(d, SID, [("q d", "a")], who="unknown")                             # 양성 대조 — 사람 아님 단서가 없으면 알 수 없음
        SF.add_answer(d, SID, [("q e", "a")], drop=("timestamp",))                       # 양성 대조 — timestamp 없음
        got = R.answers(SF.record_path(d, SID))
        self.assertEqual([a.who for a in got], [R.NOT_HUMAN, R.NOT_HUMAN, R.NOT_HUMAN, R.UNKNOWN, R.UNKNOWN])
        self.assertIn("timestamp", got[4].why)

    def test_the_four_lists_and_the_measured_fixtures(self):   # J26 — 잰 값이 목록과 자료에 있다
        d = self.d
        self.assertEqual((R.HUMAN_SOURCES, R.NOT_HUMAN_SOURCES, R.HUMAN_ENTRYPOINTS, R.NOT_HUMAN_ENTRYPOINTS),
                         (("user_temporary",), ("hook",), ("cli",), ("sdk-cli",)))
        for name, want in (("answer", [R.HUMAN]), ("hook-answer", [R.NOT_HUMAN]), ("sdk-answer", [R.NOT_HUMAN]),
                           ("other-entrypoint", [R.UNKNOWN]), ("empty-answer", [])):
            with tempfile.TemporaryDirectory() as t:
                SF.add_lines(t, SID, name)
                self.assertEqual([a.who for a in R.answers(SF.record_path(t, SID))], want, name)
        SF.add_answer(d, SID, [("q", "a")], who="other")
        path = SF.record_path(d, SID)
        self.assertEqual(R.answers(path)[0].who, R.UNKNOWN)
        with mock.patch.object(R, "NOT_HUMAN_SOURCES", ("hook", "fixture_other")):   # 새 값을 재면 목록에 넣는다
            self.assertEqual(R.answers(path)[0].who, R.NOT_HUMAN)
        with mock.patch.object(R, "HUMAN_SOURCES", ("user_temporary", "fixture_other")):
            self.assertEqual(R.answers(path)[0].who, R.HUMAN)

    def test_what_is_not_an_answer(self):
        d = self.d
        for name in ("rejected", "typed", "peer", "notification"):
            SF.add_lines(d, SID, name)
        SF.add_text(d, SID, "peer", '{"type":"tool_result","toolUseResult":{"answers":{"R2 @0123abcd 질문":"승인 — 계획 담당자에게"}}}')
        SF.add_answer(d, SID, [("곁가지 질문", "a")], sidechain=True)
        SF.add_answer(d, SID, [("같은 글", "a"), ("같은 글", "b")])
        SF.add_answer(d, SID, [("답 없이 수락한 질문", "a")], empty=True)       # 빈 답 — accept · user_temporary 로 남지만 답이 아니다
        self.assertEqual(R.answers(SF.record_path(d, SID)), [])
        self.assertEqual(R.duplicates(SF.record_path(d, SID)), ["같은 글"])   # 쓰지 않은 까닭을 record 가 낼 수 있게(J33)
        SF.add_answer(d, SID, [("주 대화 질문", "a")])                       # 양성 대조
        self.assertEqual([a.question for a in R.answers(SF.record_path(d, SID))], ["주 대화 질문"])

    def test_changed_shapes_are_unknown_not_silently_dropped(self):   # J33
        for drop, word in ((("isSidechain",), "isSidechain"), (("sourceToolAssistantUUID",), "sourceToolAssistantUUID"),
                           (("answers",), "toolUseResult.answers"), (("toolUseResult",), "toolUseResult.answers"), (("timestamp",), "timestamp")):
            with tempfile.TemporaryDirectory() as t:
                uid = SF.add_answer(t, SID, [("R2 @0123abcd 질문", "승인 — 계획 담당자에게")], drop=drop)
                got = R.answers(SF.record_path(t, SID))
                self.assertEqual([(a.entry, a.index, a.question, a.who) for a in got], [(uid, 1, "R2 @0123abcd 질문", R.UNKNOWN)], drop)
                self.assertIn(word, got[0].why, drop)
                self.assertEqual(R.find(SF.record_path(t, SID), uid + "#1").who, R.UNKNOWN)

    def test_pairing(self):
        def variant(change):
            """답 하나짜리 기록을 만들고 두 항목(호출 · 결과)을 change 로 고쳐 다시 쓴 뒤 answers() 를 돌려준다."""
            with tempfile.TemporaryDirectory() as t:
                SF.add_answer(t, SID, [("q", "a")])
                path = SF.record_path(t, SID)
                rows = [json.loads(l) for l in path.read_text(encoding="utf-8").splitlines()]
                rows = change(rows) or rows
                path.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows), encoding="utf-8")
                return R.answers(path)

        def no_call(rows): rows[1]["message"]["content"][0]["tool_use_id"] = "toolu_none"
        def other_tool(rows): rows[0]["message"]["content"][0]["name"] = "Bash"
        def result_first(rows): return [rows[1], rows[0]]
        def other_source(rows): rows[1]["sourceToolAssistantUUID"] = "00000000-0000-4000-8000-00000000dead"
        def no_key(rows): rows[1]["toolUseResult"]["answers"] = {"다른 질문": "a"}
        self.assertEqual([a.who for a in variant(lambda rows: None)], [R.HUMAN])       # 양성 대조
        for change in (no_call, other_tool, result_first):                             # 짝이 되는 호출이 없다 — 답이 아니다
            self.assertEqual(variant(change), [], change.__name__)
        for change in (other_source, no_key):                                          # 짝은 맞는데 칸이 다르다 — 알 수 없음
            self.assertEqual([a.who for a in variant(change)], [R.UNKNOWN], change.__name__)

    def test_day(self):
        self.assertEqual(R.day("2026-11-20T23:30:00.000Z", local=False), "2026-11-20")
        for bad in ("", "어제", "2026-13-40T00:00:00.000Z", "2026-11-20"):
            self.assertIsNone(R.day(bad, local=False), bad)
            self.assertIsNone(R.day(bad, local=True), bad)
        old = os.environ.get("TZ")
        try:
            os.environ["TZ"] = "Asia/Seoul"; time.tzset()
            self.assertEqual(R.day("2026-11-20T23:30:00.000Z", local=True), "2026-11-21")
            os.environ["TZ"] = "UTC"; time.tzset()
            self.assertEqual(R.day("2026-11-20T23:30:00.000Z", local=True), "2026-11-20")
        finally:
            if old is None:
                os.environ.pop("TZ", None)
            else:
                os.environ["TZ"] = old
            time.tzset()

    def test_broken_lines_and_empty_files(self):
        d = self.d
        uid = SF.add_answer(d, SID, [("q", "a")])
        with open(SF.record_path(d, SID), "a", encoding="utf-8") as f:
            f.write('{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"toolu_x"')   # 반만 쓰인 마지막 줄
        self.assertEqual([a.entry for a in R.answers(SF.record_path(d, SID))], [uid])
        empty = SF.record_path(d, "00000000-0000-4000-8000-00000000bbbb"); empty.parent.mkdir(parents=True, exist_ok=True)
        empty.write_text("not json\n", encoding="utf-8")
        self.assertRaises(R.Unreadable, R.answers, empty)
        self.assertRaises(R.Unreadable, R.answers, Path(d) / "no-such.jsonl")

    def test_large_record(self):
        d = self.d
        path = SF.record_path(d, SID); path.parent.mkdir(parents=True, exist_ok=True)
        filler = json.dumps({"type": "assistant", "isSidechain": False, "uuid": "x", "message": {"content": [{"type": "text", "text": "자리표시 " * 40}]}})
        path.write_text((filler + "\n") * 50000, encoding="utf-8")
        uid = SF.add_answer(d, SID, [("끝 질문", "끝 답")])
        t0 = time.monotonic()
        self.assertEqual([a.entry for a in R.answers(path)], [uid])
        self.assertLess(time.monotonic() - t0, 10)


class MeasuredShapes(Base):
    """Claude Code 2.1.327 기록에서 잰 꼴 — 읽다가 죽지 않고 J33 대로 가른다."""

    def rows(self):
        SF.add_answer(self.d, SID, [("q", "a")])
        path = SF.record_path(self.d, SID)
        return path, [json.loads(l) for l in path.read_text(encoding="utf-8").splitlines()]

    def write(self, path, rows):
        path.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows), encoding="utf-8")

    def test_questions_as_json_text_is_read(self):   # I2(a)
        path, rows = self.rows()
        inp = rows[0]["message"]["content"][0]["input"]
        inp["questions"] = json.dumps(inp["questions"], ensure_ascii=False)
        self.write(path, rows)
        self.assertEqual([(a.label, a.who) for a in R.answers(path)], [("a", R.HUMAN)])
        self.assertEqual(R.unreadable(path), [])

    def test_unreadable_call_with_a_paired_result_is_listed_not_answered(self):   # I2(b)
        for name, change in (("글자", lambda q: "R2 @0123abcd 질문\n둘째 줄"), ("질문 글 없음", lambda q: [{"header": "h"}]),
                             ("빈 목록", lambda q: []), ("목록 아님", lambda q: 7)):
            path, rows = self.rows()
            rows[0]["message"]["content"][0]["input"]["questions"] = change(None)
            self.write(path, rows)
            self.assertEqual(R.answers(path), [], name)
            got = R.unreadable(path)
            self.assertEqual([(u.entry, u.session) for u in got], [(rows[1]["uuid"], SID)], name)
            self.assertEqual(got[0].text, "R2 @0123abcd 질문 둘째 줄" if name == "글자" else "", name)
            os.remove(str(path))
        path, rows = self.rows()   # 양성 대조 — 읽을 수 있는 호출은 목록에 없다
        self.assertEqual(R.unreadable(path), [])

    def test_unreadable_call_listed_only_for_a_plain_result(self):
        for name, change in (("오류", lambda rows: rows[1]["message"]["content"][0].update(is_error=True)),
                             ("곁가지 결과", lambda rows: rows[1].update(isSidechain=True)),
                             ("곁가지 호출", lambda rows: rows[0].update(isSidechain=True)),
                             ("짝 없음", lambda rows: rows.pop())):
            path, rows = self.rows()
            rows[0]["message"]["content"][0]["input"]["questions"] = "자리표시 글자"
            change(rows)
            self.write(path, rows)
            self.assertEqual(R.unreadable(path), [], name)
            self.assertEqual(R.answers(path), [], name)
            os.remove(str(path))

    def test_known_not_human_wins_over_a_broken_shape(self):   # J2 · M1
        for entrypoint, who in (("sdk-cli", "human"), ("cli", "hook"), ("cli", "denied")):
            for drop in (("isSidechain",), ("sourceToolAssistantUUID",), ("answers",), ("toolUseResult",), ("timestamp",)):
                with tempfile.TemporaryDirectory() as t:
                    SF.add_answer(t, SID, [("q", "a")], who=who, entrypoint=entrypoint, drop=drop)
                    self.assertEqual([a.who for a in R.answers(SF.record_path(t, SID))], [R.NOT_HUMAN], (entrypoint, who, drop))
        with tempfile.TemporaryDirectory() as t:   # 양성 대조 — 사람 아님 단서가 없으면 같은 모양이 알 수 없음
            SF.add_answer(t, SID, [("q", "a")], drop=("isSidechain",))
            self.assertEqual([a.who for a in R.answers(SF.record_path(t, SID))], [R.UNKNOWN])

    def test_missing_or_odd_decision_is_unknown(self):   # I1 — 출처 · 방식이 사람 값이어도 결정이 없으면 사람이 아니다
        for name, change in (("칸 없음", lambda perm: perm.pop("decision")), ("null", lambda perm: perm.update(decision=None)),
                             ("숫자", lambda perm: perm.update(decision=5)), ("목록", lambda perm: perm.update(decision=["accept"]))):
            path, rows = self.rows()
            change(rows[1]["permissionDecision"])
            self.write(path, rows)
            got = R.answers(path)
            self.assertEqual([a.who for a in got], [R.UNKNOWN], name)
            self.assertIn("permissionDecision", got[0].why, name)
            os.remove(str(path))
        path, rows = self.rows()   # 양성 대조
        self.assertEqual([a.who for a in R.answers(path)], [R.HUMAN])

    def test_unknown_values_in_why_are_short_one_liners(self):   # M3
        path, rows = self.rows()
        rows[1]["permissionDecision"]["source"] = "첫 줄\n" + "x" * 200
        self.write(path, rows)
        got = R.answers(path)[0]
        self.assertEqual(got.who, R.UNKNOWN)
        self.assertNotIn("\n", got.why)
        self.assertNotIn("x" * 50, got.why)
        self.assertLess(len(got.why), 100)

    def test_call_carrying_answers_is_still_read(self):
        path, rows = self.rows()
        rows[0]["message"]["content"][0]["input"]["answers"] = {"q": "스스로 채운 글"}
        self.write(path, rows)
        got = R.answers(path)
        self.assertEqual([(a.label, a.who) for a in got], [("a", R.HUMAN)])   # 답은 결과 항목의 것만 읽는다

    def test_unparsed_input_raw_is_read(self):   # measure_questions 의 입력 풀기와 같다
        path, rows = self.rows()
        inp = rows[0]["message"]["content"][0]["input"]
        rows[0]["message"]["content"][0]["input"] = {"__unparsedToolInput": {"raw": json.dumps({"questions": inp["questions"]})}}
        self.write(path, rows)
        self.assertEqual([a.who for a in R.answers(path)], [R.HUMAN])

    def test_multiple_blocks_and_other_tools(self):
        path, rows = self.rows()
        use, res = rows
        use["message"]["content"] = [{"type": "text", "text": "자리표시"},
                                     {"type": "tool_use", "id": "toolu_other", "name": "Bash", "input": {"command": "자리표시"}},
                                     use["message"]["content"][0]]
        res["message"]["content"] = [{"type": "tool_result", "tool_use_id": "toolu_other", "content": "자리표시"},
                                     {"type": "text", "text": "자리표시"}, res["message"]["content"][0]]
        self.write(path, rows)
        self.assertEqual([(a.label, a.who) for a in R.answers(path)], [("a", R.HUMAN)])

    def test_odd_entries_do_not_crash(self):
        path, rows = self.rows()
        extra = [[], "글자", {"type": "assistant", "message": "글자 AskUserQuestion"}, {"type": "user", "message": {"content": None}},
                 {"type": "assistant", "message": {"content": [3, None, {"type": "tool_use", "name": "AskUserQuestion", "id": 5, "input": []}]}}]
        with open(str(path), "a", encoding="utf-8") as f:
            for e in extra:
                f.write(json.dumps(e, ensure_ascii=False) + "\n")
        self.assertEqual([a.who for a in R.answers(path)], [R.HUMAN])

    def test_copied_entries_count_once(self):   # J3 — 이어받은 세션이 복사한 같은 uuid
        path, rows = self.rows()
        self.write(path, rows + rows)
        self.assertEqual(len(R.answers(path)), 1)


if __name__ == "__main__":
    unittest.main()
