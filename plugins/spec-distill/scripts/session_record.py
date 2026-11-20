#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""session_record.py — 세션 기록에서 질문 창(AskUserQuestion)의 답을 읽는다. 읽기만 하고 표준 라이브러리만 쓴다.

- answers(path): 읽은 답. find(path, key): 그 중 `<uuid>#<n>` 인 것.
- duplicates(path): 한 호출 안에 글이 같은 질문이 둘이라 쓰지 않은 호출의 질문 글.
- unreadable(path): 질문을 읽지 못해 쓰지 않았지만 짝이 되는 결과(오류 아님 · 곁가지 아님)가 있는 호출.
  답으로 싣지 않는다. 쓸 답을 찾지 못했을 때 「읽지 못한 질문 창 호출이 있다」 를 알리는 데 쓴다.
"""
from __future__ import annotations

import calendar
import json
import os
import re
import time
from pathlib import Path
from typing import NamedTuple, Optional

TOOL = "AskUserQuestion"
HUMAN_SOURCES = ("user_temporary",)
NOT_HUMAN_SOURCES = ("hook",)
HUMAN_ENTRYPOINTS = ("cli",)
NOT_HUMAN_ENTRYPOINTS = ("sdk-cli",)
HUMAN, NOT_HUMAN, UNKNOWN = "사람", "사람 아님", "알 수 없음"

SESSION_PATTERN = r"[A-Za-z0-9_-]{8,}"
_TIME = r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}"
_ABSENT = "칸 없음"
_SHORT = 40


class Unreadable(Exception):
    """확인 못 함의 사유 — str(exc) 가 한 줄 한국어다."""


class UnreadableCall(NamedTuple):
    session: str
    entry: str   # 짝이 되는 결과 항목의 uuid
    text: str    # 읽을 수 있는 앞 글(질문 글 또는 글자 입력의 앞 80자 · 한 줄). 읽을 수 없으면 ""


class Answer(NamedTuple):
    session: str
    entry: str
    index: int
    question: str
    label: str
    who: str
    why: str
    when: str

    @property
    def key(self):
        return "%s#%d" % (self.entry, self.index)


def config_dir(environ=None):
    env = os.environ if environ is None else environ
    value = env.get("CLAUDE_CONFIG_DIR", "")
    return Path(value) if value else Path.home() / ".claude"


def locate(session, environ=None):
    if not isinstance(session, str) or re.fullmatch(SESSION_PATTERN, session) is None:
        raise Unreadable("세션 번호의 꼴이 아니다")
    projects = config_dir(environ) / "projects"
    found = []
    try:
        for proj in sorted(projects.iterdir()):
            cand = proj / (session + ".jsonl")
            if cand.is_file():
                found.append(cand)
    except OSError:
        raise Unreadable("세션 기록 폴더를 읽지 못했다: %s" % projects)
    if not found:
        raise Unreadable("세션 기록 파일을 찾지 못했다: %s.jsonl" % session)
    if len(found) > 1:
        raise Unreadable("세션 기록 파일이 둘 이상이다: %s.jsonl" % session)
    return found[0]


def day(when, local):
    """시각 글자의 앞 19자를 UTC 로 읽어 날짜(YYYY-MM-DD). local 이 참이면 이 기계의 지역 날짜. 읽지 못하면 None."""
    if not isinstance(when, str) or re.fullmatch(_TIME, when[:19]) is None:
        return None
    try:
        stamp = calendar.timegm(time.strptime(when[:19], "%Y-%m-%dT%H:%M:%S"))
        return time.strftime("%Y-%m-%d", time.localtime(stamp) if local else time.gmtime(stamp))
    except (ValueError, OverflowError, OSError):
        return None


def _questions_of(inp):
    """호출 입력의 질문 글 목록. 읽지 못하면 None.

    `__unparsedToolInput.raw` 로만 남은 입력은 그 글을 JSON 으로 풀어 읽는다.
    """
    if not isinstance(inp, dict):
        return None
    if "questions" not in inp and isinstance(inp.get("__unparsedToolInput"), dict):
        try:
            inp = json.loads(inp["__unparsedToolInput"].get("raw"))
        except (TypeError, ValueError):
            return None
        if not isinstance(inp, dict):
            return None
    qs = inp.get("questions")
    if isinstance(qs, str):   # 목록이 글자로 담긴 호출 — JSON 으로 풀린 목록만 쓴다
        try:
            qs = json.loads(qs)
        except ValueError:
            return None
    if not isinstance(qs, list) or not qs:
        return None
    texts = []
    for q in qs:
        if not isinstance(q, dict) or not isinstance(q.get("question"), str):
            return None
        texts.append(q["question"])
    return texts


def _hint(inp):
    """읽지 못한 호출의 앞 글 — 읽을 수 있을 때만(한 줄 · 80자)."""
    qs = inp.get("questions") if isinstance(inp, dict) else None
    if isinstance(qs, list) and qs and isinstance(qs[0], dict):
        qs = qs[0].get("question")
    return " ".join(qs.split())[:80] if isinstance(qs, str) else ""


def _blocks(row):
    msg = row.get("message")
    content = msg.get("content") if isinstance(msg, dict) else None
    if not isinstance(content, list):
        return []
    return [b for b in content if isinstance(b, dict)]


def _text(value):
    """기록의 값을 사유 글에 넣을 때 — 한 줄 · 40자 이내."""
    if value is None:
        return _ABSENT
    shown = repr(value)
    return shown if len(shown) <= _SHORT else shown[:_SHORT - 1] + "…"


def _not_human(res, perm):
    """사람 아님이 먼저다(J2) — 모양을 보기 전에 가른다. 아니면 None."""
    entry = res.get("entrypoint")
    decision = perm.get("decision") if isinstance(perm, dict) else None
    source = perm.get("source") if isinstance(perm, dict) else None
    if (isinstance(decision, str) and decision != "accept") or source in NOT_HUMAN_SOURCES \
            or entry in NOT_HUMAN_ENTRYPOINTS:
        return "사람이 질문 창에서 고른 답이 아니다(%s · %s · %s)" % (_text(decision), _text(source), _text(entry))
    return None


def _judge(res, perm, label_ok):
    """(who, why) — 사람 아님은 이미 가려졌다. 꼴 → 칸 없음 → 아는 값."""
    if not label_ok:
        return UNKNOWN, "고른 답을 읽을 칸(toolUseResult.answers)이 없거나 꼴이 다르다"
    entry = res.get("entrypoint")
    decision = perm.get("decision") if isinstance(perm, dict) else None
    source = perm.get("source") if isinstance(perm, dict) else None
    if day(res.get("timestamp"), False) is None:
        return UNKNOWN, "답한 시각(timestamp)을 읽지 못했다"
    if not isinstance(perm, dict) or not isinstance(decision, str):
        return UNKNOWN, "사람이 답했는지 가를 칸(permissionDecision)이 없다"
    if source not in HUMAN_SOURCES:
        return UNKNOWN, "수락의 출처(%s)가 아는 값이 아니다" % _text(source)
    if entry not in HUMAN_ENTRYPOINTS:
        return UNKNOWN, "세션을 띄운 방식(entrypoint: %s)이 아는 값이 아니다" % _text(entry)
    return HUMAN, ""


def _scan(path):
    """(답 목록, 쓰지 않은 호출의 질문 글 목록, 읽지 못한 호출 목록). 파일을 열지 못하거나 읽은 JSON 줄이 없으면 Unreadable."""
    session = Path(path).name
    if session.endswith(".jsonl"):
        session = session[:-6]
    calls, bad, out, dups, lost, seen = {}, {}, [], [], [], set()
    parsed = 0
    try:
        with open(str(path), encoding="utf-8", errors="replace") as f:
            for line in f:
                if TOOL not in line and "tool_result" not in line:
                    s = line.strip()
                    if s.startswith("{") and s.endswith("}"):
                        # JSON 으로 풀지 않고 센다 — 반쯤 쓰인 줄로 「읽은 줄 없음」 이 되지 않게(지금 동작)
                        parsed += 1   # 큰 기록은 풀지 않고 JSON 줄로만 센다
                    continue
                try:
                    row = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(row, dict):
                    continue
                parsed += 1
                uid = row.get("uuid")
                if isinstance(uid, str):
                    if uid in seen:   # 이어받은 세션이 복사한 같은 uuid 의 항목은 처음 것만 읽는다
                        continue
                    seen.add(uid)
                kind = row.get("type")
                if kind == "assistant":
                    for b in _blocks(row):
                        if b.get("type") != "tool_use" or b.get("name") != TOOL or not isinstance(b.get("id"), str):
                            continue
                        qs = _questions_of(b.get("input"))
                        if row.get("isSidechain") is True:
                            continue
                        if qs is None:
                            bad.setdefault(b["id"], _hint(b.get("input")))
                            continue
                        if len(set(qs)) != len(qs):
                            for q in qs:
                                if qs.count(q) > 1 and q not in dups:
                                    dups.append(q)
                            continue
                        calls.setdefault(b["id"], (row, qs))
                elif kind == "user":
                    for b in _blocks(row):
                        if b.get("type") != "tool_result":
                            continue
                        if b.get("tool_use_id") in calls:
                            _result(session, calls[b["tool_use_id"]], row, b, out)
                        elif b.get("tool_use_id") in bad and row.get("isSidechain") is not True and not b.get("is_error"):
                            lost.append(UnreadableCall(session, _entry(row), bad[b["tool_use_id"]]))
    except OSError as exc:
        raise Unreadable("세션 기록을 읽지 못했다: %s — %s" % (Path(path).name, exc.__class__.__name__))
    if not parsed:
        raise Unreadable("세션 기록에서 읽은 JSON 줄이 없다: %s" % Path(path).name)
    return out, dups, lost


def _entry(res):
    return res.get("uuid") if isinstance(res.get("uuid"), str) else ""


def _result(session, call, res, block, out):
    use, qs = call
    if res.get("isSidechain") is True or block.get("is_error"):
        return
    tur = res.get("toolUseResult")
    ans = tur.get("answers") if isinstance(tur, dict) else None
    if isinstance(ans, dict) and not ans:
        return   # 답 없이 수락 — 고른 답이 없다
    when = res.get("timestamp") if isinstance(res.get("timestamp"), str) else ""
    entry = _entry(res)
    perm = res.get("permissionDecision")
    refused = _not_human(res, perm)
    if refused:   # 사람 아님이 먼저다 — 모양이 달라도 어긋남이다
        for i, q in enumerate(qs, 1):
            ok = isinstance(ans, dict) and isinstance(ans.get(q), str)
            out.append(Answer(session, entry, i, q, ans[q] if ok else "", NOT_HUMAN, refused, when))
        return
    shape = None
    if not isinstance(use.get("isSidechain"), bool) or not isinstance(res.get("isSidechain"), bool):
        shape = "주 대화인지 가를 칸(isSidechain)이 없다"
    elif not isinstance(use.get("uuid"), str) or res.get("sourceToolAssistantUUID") != use.get("uuid"):
        shape = "호출과 결과를 잇는 칸(sourceToolAssistantUUID)이 없거나 다르다"
    for i, q in enumerate(qs, 1):
        if shape:
            out.append(Answer(session, entry, i, q, "", UNKNOWN, shape, when))
            continue
        ok = isinstance(ans, dict) and isinstance(ans.get(q), str)
        label = ans[q] if ok else ""
        who, why = _judge(res, perm, ok)
        out.append(Answer(session, entry, i, q, label, who, why, when))


def answers(path):
    return _scan(path)[0]


def find(path, key):
    for a in answers(path):
        if a.key == key:
            return a
    return None


def duplicates(path):
    return _scan(path)[1]


def unreadable(path):
    return _scan(path)[2]
