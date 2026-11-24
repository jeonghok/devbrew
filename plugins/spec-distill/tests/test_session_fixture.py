#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""세션 기록 자료 — 개인 정보가 없고, 도우미가 자료와 같은 꼴의 항목을 짓는다.

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_session_fixture.py
"""
from __future__ import annotations

import json
import re
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "fixtures"))
import session_fixture as SF  # noqa: E402

DATA = HERE / "fixtures" / "session-record"
NAMES = ("answer", "answer-multi", "rejected", "typed", "peer", "notification", "hook-answer", "sdk-answer", "empty-answer", "other-entrypoint")
FIXED = frozenset({   # 기록의 고정 낱말(type · name · role · decision · source · entrypoint · kind …) — 사용자 글이 아니다
    "AskUserQuestion", "accept", "assistant", "cli", "external", "fixture_other", "high", "hook", "human", "interactive",
    "peer", "queued", "reject", "sdk-cli", "system", "task-notification", "task_notification", "tool_result", "tool_use",
    "typed", "user", "user_reject", "user_temporary"})
SAFE = [re.compile(p) for p in (
    r"자리표시(?: (?:질문|라벨|설명|결과|머리|글|다른 선택지))?(?: [0-9]+)?",   # 닫힌 꼬리 낱말 + 번호만
    r"0{8}-0{4}-4000-8000-0{9}[0-9a-f]{3}",                   # 가짜 uuid
    r"toolu_fixture_[0-9]+", r"2\.1\.[0-9]{3}", r"2026-01-01T00:00:[0-9]{2}\.000Z")]


def is_safe(s):
    return s in FIXED or any(r.fullmatch(s) for r in SAFE)


IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def is_safe_key(k):
    return is_safe(k) or bool(IDENT.fullmatch(k))


def unsafe(value):
    """값 안의 안전하지 않은 글 값과 열쇠. 모든 깊이의 사전 · 목록을 돈다."""
    if isinstance(value, str):
        if not is_safe(value):
            yield value
    elif isinstance(value, list):
        for v in value:
            yield from unsafe(v)
    elif isinstance(value, dict):
        for k, v in value.items():
            if not is_safe_key(k):
                yield k
            yield from unsafe(v)


def entries(name):
    return [json.loads(line) for line in (DATA / (name + ".jsonl")).read_text(encoding="utf-8").splitlines() if line]


class Privacy(unittest.TestCase):
    def test_files_exist_and_parse(self):
        self.assertEqual(sorted(p.stem for p in DATA.glob("*.jsonl")), sorted(NAMES))
        for name in NAMES:
            self.assertTrue(entries(name), name)

    def test_every_string_is_a_placeholder_or_a_fixed_word(self):
        for path in sorted(DATA.glob("*.jsonl")):
            for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                self.assertEqual([s[:12] for s in unsafe(json.loads(line))], [], "%s:%d" % (path.name, n))

    def test_keys_outside_answers_are_checked(self):   # AC4 — PR #305 리뷰
        _use, res = entries("answer")
        for bad in ("설계를 승인할까요?", "/Users/someone/x", "a@b.example"):
            planted = json.loads(json.dumps(res))
            planted["toolUseResult"]["annotations"] = {bad: {"notes": "자리표시"}}
            self.assertIn(bad, list(unsafe(planted)), bad)
            nested = json.loads(json.dumps(res))
            nested["message"]["content"][0][bad] = "자리표시"            # 목록 안 사전의 열쇠
            self.assertIn(bad, list(unsafe(nested)), bad)

    def test_identifier_keys_pass_and_the_fixtures_are_clean(self):   # AC4 뒷부분 — 양성 대조는 위 심은 열쇠
        self.assertEqual(list(unsafe({"advisorModel": "자리표시", "is_error": True})), [])
        for path in sorted(DATA.glob("*.jsonl")):
            for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                self.assertEqual([s[:12] for s in unsafe(json.loads(line))], [], "%s:%d" % (path.name, n))

    def test_the_lock_bites(self):   # 양성 대조 — 경로 · 이메일 · 한글 문장은 걸린다
        for bad in ("/Users/someone/x", "a@b.example", "설계를 승인할까요?", "0123abcd-0000-4000-8000-000000000001",
                    "main", "feature-conductor-stage", "jeongho-kim", "secret", "sk-ant-abc", "자리표시 설계를 승인할까요"):
            self.assertFalse(is_safe(bad), bad)


class Shape(unittest.TestCase):
    def test_answer_fixture_has_the_measured_columns(self):
        use, res = entries("answer")
        block = use["message"]["content"][0]
        self.assertEqual((use["type"], block["type"], block["name"], use["isSidechain"]), ("assistant", "tool_use", "AskUserQuestion", False))
        self.assertEqual(sorted(block["input"]["questions"][0]), ["header", "multiSelect", "options", "question"])
        out = res["message"]["content"][0]
        self.assertEqual((res["type"], out["type"], out["tool_use_id"], res["isSidechain"]), ("user", "tool_result", block["id"], False))
        self.assertEqual(res["sourceToolAssistantUUID"], use["uuid"])
        self.assertEqual(sorted(res["toolUseResult"]), ["answers", "questions"])
        self.assertEqual(res["permissionDecision"]["decision"], "accept")
        self.assertEqual(res["permissionDecision"]["source"], "user_temporary")
        self.assertEqual(list(res["toolUseResult"]["answers"]), [block["input"]["questions"][0]["question"]])
        for col in ("origin", "turnOrigin", "promptSource"):
            self.assertNotIn(col, res)

    def test_measured_shapes(self):   # J26 — 2.1.327 에서 잰 네 꼴. answer.jsonl 과 다른 칸만 본다
        base_use, base_res = entries("answer")
        self.assertEqual((base_use["entrypoint"], base_res["entrypoint"]), ("cli", "cli"))
        hook = entries("hook-answer")[1]
        self.assertEqual(hook["permissionDecision"], {"decision": "accept", "source": "hook", "reasonType": "hook"})
        sdk_use, sdk = entries("sdk-answer")
        self.assertEqual((sdk_use["entrypoint"], sdk["entrypoint"]), ("sdk-cli", "sdk-cli"))
        self.assertEqual(sdk["permissionDecision"], base_res["permissionDecision"])            # 사람 답과 같은 값으로 남는다
        empty = entries("empty-answer")[1]
        self.assertEqual((empty["toolUseResult"]["answers"], empty["permissionDecision"]), ({}, base_res["permissionDecision"]))
        self.assertNotIn("is_error", empty["message"]["content"][0])
        other = entries("other-entrypoint")[1]
        self.assertEqual((other["entrypoint"], other["permissionDecision"]), ("fixture_other", base_res["permissionDecision"]))
        for name in ("hook-answer", "empty-answer", "other-entrypoint"):
            self.assertEqual(len(entries(name)), 2, name)

    def test_other_fixtures(self):
        self.assertEqual(len(entries("answer-multi")[0]["message"]["content"][0]["input"]["questions"]), 2)
        self.assertEqual(len(entries("answer-multi")[1]["toolUseResult"]["answers"]), 2)
        rejected = entries("rejected")[1]
        self.assertIs(rejected["message"]["content"][0]["is_error"], True)
        self.assertIsInstance(rejected["toolUseResult"], str)
        kinds = [set(k for k in ("origin", "turnOrigin", "promptSource") if k in e) for e in entries("typed")]
        self.assertEqual(kinds, [{"origin", "turnOrigin", "promptSource"}, {"turnOrigin", "promptSource"}, set()])
        for name in ("typed", "peer", "notification"):
            for e in entries(name):
                self.assertEqual(e["type"], "user")
                self.assertIsInstance(e["message"]["content"], str, name)   # 도구 결과가 아니다


class Builder(unittest.TestCase):
    def test_add_answer_matches_the_fixture_shape(self):
        with tempfile.TemporaryDirectory() as d:
            sid = "00000000-0000-4000-8000-000000000a01"
            uid = SF.add_answer(d, sid, [("R2 @0123abcd — 자리표시 질문", "자리표시 라벨")])
            use, res = [json.loads(l) for l in SF.record_path(d, sid).read_text(encoding="utf-8").splitlines()]
            base_use, base_res = entries("answer")
            self.assertEqual(sorted(use), sorted(base_use))
            self.assertEqual(sorted(res), sorted(base_res))
            self.assertEqual(res["uuid"], uid)
            self.assertEqual(res["sourceToolAssistantUUID"], use["uuid"])
            self.assertEqual(res["toolUseResult"]["answers"], {"R2 @0123abcd — 자리표시 질문": "자리표시 라벨"})
            self.assertEqual(use["message"]["content"][0]["input"]["questions"][0]["question"], "R2 @0123abcd — 자리표시 질문")

    def test_who_and_place(self):
        with tempfile.TemporaryDirectory() as d:
            sid = "00000000-0000-4000-8000-000000000a02"
            SF.add_answer(d, sid, [("q", "a")], who="unknown")
            SF.add_answer(d, sid, [("q2", "a")], who="other")
            SF.add_answer(d, sid, [("q3", "a")], sidechain=True)
            rows = [json.loads(l) for l in SF.record_path(d, sid).read_text(encoding="utf-8").splitlines()]
            self.assertNotIn("permissionDecision", rows[1])
            self.assertEqual(rows[3]["permissionDecision"]["source"], "fixture_other")
            self.assertEqual((rows[4]["isSidechain"], rows[5]["isSidechain"]), (True, True))
            SF.add_answer(d, sid, [("q4", "a")], subagent=True)
            self.assertTrue((Path(d) / "projects" / "fixture" / sid / "subagents" / "agent-fixture.jsonl").is_file())
            self.assertEqual(len(SF.record_path(d, sid).read_text(encoding="utf-8").splitlines()), 6)
            self.assertEqual(SF.add_answer(d, sid, [("q5", "a")], entry="00000000-0000-4000-8000-000000000fff"),
                             "00000000-0000-4000-8000-000000000fff")
            SF.add_answer(d, sid, [("q6", "a")], who="denied", when="2026-11-20T12:00:00.000Z", drop=("sourceToolAssistantUUID", "answers"))
            last = json.loads(SF.record_path(d, sid).read_text(encoding="utf-8").splitlines()[-1])
            self.assertEqual((last["permissionDecision"]["decision"], last["permissionDecision"]["source"], last["timestamp"]),
                             ("reject", "user_reject", "2026-11-20T12:00:00.000Z"))
            self.assertNotIn("sourceToolAssistantUUID", last)
            self.assertNotIn("answers", last["toolUseResult"])
            SF.add_answer(d, sid, [("q7", "a")], drop=("isSidechain", "timestamp", "toolUseResult"))
            use, res = [json.loads(l) for l in SF.record_path(d, sid).read_text(encoding="utf-8").splitlines()[-2:]]
            self.assertEqual(("isSidechain" in use, "isSidechain" in res, "timestamp" in res, res["toolUseResult"]), (False, False, False, "자리표시"))
            SF.add_answer(d, sid, [("q8", "a")], who="hook", entrypoint="sdk-cli", empty=True)
            use, res = [json.loads(l) for l in SF.record_path(d, sid).read_text(encoding="utf-8").splitlines()[-2:]]
            self.assertEqual((use["entrypoint"], res["entrypoint"], res["permissionDecision"]["source"], res["toolUseResult"]["answers"]),
                             ("sdk-cli", "sdk-cli", "hook", {}))
            SF.add_answer(d, sid, [("q9", "a")], drop=("entrypoint",))
            self.assertNotIn("entrypoint", json.loads(SF.record_path(d, sid).read_text(encoding="utf-8").splitlines()[-1]))
            SF.add_text(d, sid, "peer", "R2 @0123abcd — 자리표시 질문")
            self.assertEqual(json.loads(SF.record_path(d, sid).read_text(encoding="utf-8").splitlines()[-1])["message"]["content"],
                             "R2 @0123abcd — 자리표시 질문")


class Main(unittest.TestCase):
    SID = "00000000-0000-4000-8000-000000000a03"

    def test_main_answer_prints_the_uuid(self):
        import contextlib
        import io
        with tempfile.TemporaryDirectory() as d:
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                rc = SF.main(["answer", "--config", d, "--session", self.SID, "--question", "q", "--label", "a"])
            self.assertEqual(rc, 0)
            rows = [json.loads(l) for l in SF.record_path(d, self.SID).read_text(encoding="utf-8").splitlines()]
            self.assertEqual(out.getvalue().splitlines(), [rows[1]["uuid"]])

    def test_main_rejects_mismatched_counts(self):
        import contextlib
        import io
        with tempfile.TemporaryDirectory() as d:
            with contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as cm:
                    SF.main(["answer", "--config", d, "--session", self.SID, "--question", "q1", "--question", "q2", "--label", "a"])
            self.assertEqual(cm.exception.code, 2)
            self.assertFalse(SF.record_path(d, self.SID).exists())

    def test_unknown_who_and_drop_raise(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertRaises(ValueError, SF.add_answer, d, self.SID, [("q", "a")], who="x")
            self.assertRaises(ValueError, SF.add_answer, d, self.SID, [("q", "a")], drop=("x",))

    def test_main_lines_and_text(self):
        with tempfile.TemporaryDirectory() as d:
            path = SF.record_path(d, self.SID)
            n = len((DATA / "typed.jsonl").read_text(encoding="utf-8").splitlines())
            SF.main(["lines", "--config", d, "--session", self.SID, "--name", "typed"])
            self.assertEqual(len(path.read_text(encoding="utf-8").splitlines()), n)
            SF.main(["text", "--config", d, "--session", self.SID, "--name", "typed", "--text", "글"])
            self.assertEqual(len(path.read_text(encoding="utf-8").splitlines()), n + 1)


if __name__ == "__main__":
    unittest.main()
