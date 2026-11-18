#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""가짜 세션 기록 도우미 — `session-record/answer.jsonl` 의 두 항목을 틀로 질문 창 호출 · 답 항목을 덧붙인다.

테스트가 `<config_dir>/projects/<project>/<session>.jsonl` 에 세션 기록을 짓는 데 쓴다.
"""
from __future__ import annotations

import argparse
import copy
import json
import sys
import uuid
from pathlib import Path

DATA = Path(__file__).resolve().parent / "session-record"
PLACEHOLDER = "자리표시"


def record_path(config_dir, session, project="fixture"):
    return Path(config_dir) / "projects" / project / (session + ".jsonl")


def _load(name):
    return [json.loads(line) for line in (DATA / (name + ".jsonl")).read_text(encoding="utf-8").splitlines() if line]


def _append(path, rows):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(str(path), "a", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")


def add_answer(config_dir, session, questions, who="human", sidechain=False, subagent=False, entry=None,
               when="2026-01-01T12:00:00.000Z", drop=(), entrypoint="cli", empty=False, project="fixture"):
    use, res = copy.deepcopy(_load("answer"))
    template_q = use["message"]["content"][0]["input"]["questions"][0]
    qs = []
    for question, label in questions:
        q = copy.deepcopy(template_q)
        q["question"] = question
        q["options"][0]["label"] = label
        qs.append(q)
    tool = "toolu_fixture_%d" % (uuid.uuid4().int % 10 ** 9)
    use["uuid"] = str(uuid.uuid4())
    use["message"]["content"][0]["id"] = tool
    use["message"]["content"][0]["input"]["questions"] = qs
    res["uuid"] = entry if entry is not None else str(uuid.uuid4())
    res["parentUuid"] = use["uuid"]
    res["sourceToolAssistantUUID"] = use["uuid"]
    res["timestamp"] = when
    res["message"]["content"][0]["tool_use_id"] = tool
    res["toolUseResult"] = {"questions": copy.deepcopy(qs), "answers": {} if empty else {q: l for q, l in questions}}
    for e in (use, res):
        e["entrypoint"] = entrypoint
        e["isSidechain"] = bool(sidechain)
    if who == "unknown":
        del res["permissionDecision"]
    elif who == "other":
        res["permissionDecision"]["source"] = "fixture_other"
    elif who == "denied":
        res["permissionDecision"] = {"decision": "reject", "source": "user_reject"}
    elif who == "hook":
        res["permissionDecision"] = {"decision": "accept", "source": "hook", "reasonType": "hook"}
    elif who != "human":
        raise ValueError("who: %r" % (who,))
    for col in drop:
        if col in ("isSidechain", "entrypoint"):
            use.pop(col, None)
            res.pop(col, None)
        elif col in ("sourceToolAssistantUUID", "timestamp"):
            res.pop(col, None)
        elif col == "answers":
            res["toolUseResult"].pop("answers", None)
        elif col == "toolUseResult":
            res["toolUseResult"] = PLACEHOLDER
        else:
            raise ValueError("drop: %r" % (col,))
    if subagent:
        path = Path(config_dir) / "projects" / project / session / "subagents" / "agent-fixture.jsonl"
    else:
        path = record_path(config_dir, session, project)
    _append(path, [use, res])
    return res["uuid"]


def add_lines(config_dir, session, name, project="fixture"):
    _append(record_path(config_dir, session, project), _load(name))


def add_text(config_dir, session, name, text, project="fixture"):
    row = _load(name)[0]
    row["uuid"] = str(uuid.uuid4())
    row["message"]["content"] = text
    _append(record_path(config_dir, session, project), [row])


def main(argv=None):
    ap = argparse.ArgumentParser(description="가짜 세션 기록을 덧붙인다")
    sub = ap.add_subparsers(dest="cmd", required=True)
    for cmd in ("answer", "lines", "text"):
        p = sub.add_parser(cmd)
        p.add_argument("--config", required=True)
        p.add_argument("--session", required=True)
        p.add_argument("--project", default="fixture")
        if cmd == "answer":
            p.add_argument("--question", action="append", required=True)
            p.add_argument("--label", action="append", required=True)
            p.add_argument("--who", default="human", choices=("human", "unknown", "other", "denied", "hook"))
            p.add_argument("--entrypoint", default="cli")
            p.add_argument("--empty", action="store_true")
            p.add_argument("--entry")
            p.add_argument("--when", default="2026-01-01T12:00:00.000Z")
            p.add_argument("--drop", action="append", default=[])
            p.add_argument("--sidechain", action="store_true")
            p.add_argument("--subagent", action="store_true")
        else:
            p.add_argument("--name", required=True)
            if cmd == "text":
                p.add_argument("--text", required=True)
    a = ap.parse_args(argv)
    if a.cmd == "answer":
        if len(a.question) != len(a.label):
            ap.error("--question 과 --label 의 수가 다르다")
        print(add_answer(a.config, a.session, list(zip(a.question, a.label)), who=a.who, sidechain=a.sidechain,
                         subagent=a.subagent, entry=a.entry, when=a.when, drop=tuple(a.drop),
                         entrypoint=a.entrypoint, empty=a.empty, project=a.project))
    elif a.cmd == "lines":
        add_lines(a.config, a.session, a.name, project=a.project)
    else:
        add_text(a.config, a.session, a.name, a.text, project=a.project)
    return 0


if __name__ == "__main__":
    sys.exit(main())
