#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""team_files.py — team 형식의 틀 위치와 과제 파일(INTENT · sources)의 글을 만들고 읽는다.

글만 다룬다 — 파일을 쓰지 않고 git 을 부르지 않는다. 경로 조각은 team_layout 에서 가져온다.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import team_layout  # noqa: E402
from roadmap_model import FormatError, section_body  # noqa: E402,F401

TEMPLATES = Path(__file__).resolve().parent.parent / "templates" / "team"
SECTIONS = ("목표", "지시 원문", "하지 않을 것", "결정 기록")
KIND_EPIC = "epic"
KIND_TASK = "task"

_RANGE_RE = re.compile(r"([0-9]+)[–-]([0-9]+)")
_SLOT_RE = re.compile(r"\{\{(\w*)\}\}")
_SCOPE_MID = " / 안 한다 "
_SCOPE_HEAD = "한다 "
SOURCE_PARTS = ("제약", "열린 질문", "웹 근거", "기각 · 위험")   # 번호 파일의 칸 — roadmap_render.bundle_parts 도 이 이름을 쓴다


def role_template(role: str) -> Path:
    if role not in team_layout.ROLES:
        raise ValueError("역할 이름이 아니다: %r" % role)
    return TEMPLATES / ("role-%s.md" % role)


def parse_ranges(cell: str) -> list:
    out = []
    for piece in cell.split(" · "):
        m = _RANGE_RE.fullmatch(piece)
        if not m:
            raise ValueError("줄 범위 꼴이 아니다: %r" % piece)
        a, b = int(m.group(1)), int(m.group(2))
        if a < 1 or a > b:
            raise ValueError("줄 범위가 0 으로 시작하거나 뒤집혔다: %r" % piece)
        out.append((a, b))
    return out


def format_ranges(ranges) -> str:
    return " · ".join("%d–%d" % (a, b) for a, b in ranges)


def _split_scope(scope: str):
    """`한다 <가> / 안 한다 <나>` 꼴이면 (가, 나), 아니면 None."""
    if "\n" in scope or not scope.startswith(_SCOPE_HEAD) or scope.count(_SCOPE_MID) != 1:
        return None
    head, tail = scope.split(_SCOPE_MID)
    do = head[len(_SCOPE_HEAD):]
    if not do or do[0].isspace() or not tail or tail[0].isspace():
        return None
    return do, tail


def goal_text(intent: str, scope: str) -> str:
    halves = _split_scope(scope)
    return "%s\n\n- 범위: %s" % (intent, halves[0] if halves else scope)


def not_text(scope: str) -> str:
    halves = _split_scope(scope)
    return "- %s" % (halves[1] if halves else "없음")


def original_pointer(ranges, roadmap_rel: str) -> str:
    return ("전체 그림에서 이 과제의 자리 — 원자료 가운데 아래 줄 범위가 이 과제 몫이다. "
            "나머지가 어느 과제로 갔는지는 로드맵(%s)의 에픽 지도와 각 과제의 이 칸에 있다.\n\n"
            "%s%s" % (roadmap_rel, _pointer_prefix(), " · ".join("%d–%d행" % (a, b) for a, b in ranges)))


def _pointer_prefix() -> str:
    return "- 범위: " + team_layout.original_rel() + " "


def render_intent(template: str, job: str, kind: str, roadmap_rel: str, goal: str, original: str,
                  not_do: str, branch: str = "", paths=()) -> str:
    values = {"JOB": job, "KIND": kind, "ROADMAP": roadmap_rel, "BRANCH": branch, "PATHS": ", ".join(paths),
              "GOAL": goal, "ORIGINAL": original, "NOT": not_do}

    def fill(m):
        if m.group(1) not in values:
            raise FormatError("틀의 알 수 없는 자리표: {{%s}}" % m.group(1))
        return values[m.group(1)]

    text = _SLOT_RE.sub(fill, template)
    lines = text.split("\n")
    if lines[0] == "---":
        for i in range(1, len(lines)):
            lines[i] = lines[i].rstrip(" \t")
            if lines[i] == "---":
                break
    return "\n".join(lines)


def _header_end(lines: list) -> int:
    if not lines or lines[0] != "---":
        raise FormatError("INTENT 머리말이 없다")
    for i in range(1, len(lines)):
        if lines[i] == "---":
            return i
    raise FormatError("INTENT 머리말이 닫히지 않았다")


def intent_sections(text: str) -> dict:
    lines = text.split("\n")
    start = _header_end(lines) + 1
    marks = {name: "## " + name for name in SECTIONS}

    def first(name, lo):
        for i in range(lo, len(lines)):
            if lines[i] == marks[name]:
                return i
        raise FormatError("칸이 없다: %s" % marks[name])

    def last(name, lo, hi):
        for i in range(hi - 1, lo - 1, -1):
            if lines[i] == marks[name]:
                return i
        raise FormatError("칸이 없다: %s" % marks[name])

    h_goal = first("목표", start)
    h_orig = first("지시 원문", h_goal + 1)
    h_dec = last("결정 기록", h_orig + 1, len(lines))
    h_not = last("하지 않을 것", h_orig + 1, h_dec)
    heads = [h_goal, h_orig, h_not, h_dec]
    out = {}
    for name, h, nxt in zip(SECTIONS[:3], heads, heads[1:]):
        if lines[h + 1] != "" or nxt - 1 < h + 2 or lines[nxt - 1] != "":
            raise FormatError("칸 %s 의 앞뒤 빈 줄이 없다" % marks[name])
        out[name] = "\n".join(lines[h + 2:nxt - 1])
    tail = lines[h_dec + 1:]
    while tail and tail[0] == "":
        tail.pop(0)
    while tail and tail[-1] == "":
        tail.pop()
    out["결정 기록"] = "\n".join(tail)
    return out


def intent_ranges(text: str) -> list:
    lines = text.split("\n")
    header = lines[:_header_end(lines)]
    if "kind: " + KIND_TASK in header:
        return []   # 단순 작업의 지시 원문은 받은 말 그대로다 — 범위 줄로 읽지 않는다
    prefix = _pointer_prefix()
    for line in intent_sections(text)["지시 원문"].split("\n"):
        if line.startswith(prefix):
            pieces = line[len(prefix):].split(" · ")
            if not all(p.endswith("행") for p in pieces):
                raise FormatError("지시 원문 범위 줄 꼴이 아니다: %r" % line)
            try:
                return parse_ranges(" · ".join(p[:-1] for p in pieces))
            except ValueError as e:
                raise FormatError(str(e))
    return []


def intent_drift(text: str, intent: str, scope: str) -> list:
    s = intent_sections(text)
    out = []
    if s["목표"] != goal_text(intent, scope):
        out.append("목표 칸이 로드맵의 의도 · 범위와 다르다")
    if s["하지 않을 것"] != not_text(scope):
        out.append("하지 않을 것 칸이 로드맵의 범위(안 한다 쪽)와 다르다")
    return out


def render_sources(job: str, title: str, ids: list, parts: dict, receives: str, gives: str) -> str:
    out = ["---", "type: job-sources", "job: %s" % job, "ids: [%s]" % ", ".join(ids), "---", "",
           "# %s — %s · 번호 항목" % (job, title)]
    for name in SOURCE_PARTS:
        out += ["", "## " + name, ""] + (list(parts.get(name) or []) or ["- 없음"])
    out += ["", "## 인터페이스", "", "- 받는 것: %s" % receives, "- 넘기는 것: %s" % gives]
    return "\n".join(out) + "\n"


def sources_interface(text: str) -> tuple:
    body = section_body(text, "## 인터페이스")
    found = {}
    for key in ("받는 것", "넘기는 것"):
        prefix = "- %s: " % key
        for line in (body or "").splitlines():
            if line.startswith(prefix):
                found[key] = line[len(prefix):].rstrip("\r")
                break
    if not found:
        raise FormatError("sources 에 인터페이스 줄(받는 것 · 넘기는 것)이 없다")
    return found.get("받는 것", ""), found.get("넘기는 것", "")
