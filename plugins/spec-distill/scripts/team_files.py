#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""team_files.py — team 형식의 틀 위치와 과제 파일(INTENT · sources)과 원자료 사본(original.md)의 글을 만들고 읽는다.

글만 다룬다 — 파일을 쓰지 않고 git 을 부르지 않는다. 경로 조각은 team_layout 에서 가져온다.
"""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import team_layout  # noqa: E402
from roadmap_model import FormatError, field_text, frontmatter, section_body, unquote  # noqa: E402,F401

TEMPLATES = Path(__file__).resolve().parent.parent / "templates" / "team"
SECTIONS = ("목표", "지시 원문", "하지 않을 것", "결정 기록")
KIND_EPIC = "epic"
KIND_TASK = "task"

_RANGE_RE = re.compile(r"([0-9]+)[–-]([0-9]+)")
_SLOT_RE = re.compile(r"\{\{(\w*)\}\}")
_SCOPE_MID = " / 안 한다 "
SCOPE_RE = re.compile(r"한다 (\S.*?) / 안 한다 (\S.*)")
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
    m = SCOPE_RE.fullmatch(scope)
    if not m or scope.count(_SCOPE_MID) != 1:
        return None
    return m.group(1), m.group(2)


def scope_line(value) -> str:
    """로드맵 범위 칸(글 또는 하위 항목 목록) → `한다 … / 안 한다 …` 한 줄(INTENT.md 의 목표 · 하지 않을 것을 만든 꼴)."""
    if isinstance(value, str):
        return value
    do = [i[len("한다: "):] for i in value if i.startswith("한다: ")]
    dont = [i[len("안 한다: "):] for i in value if i.startswith("안 한다: ")]
    if do and dont and len(do) + len(dont) == len(value):
        return "한다 %s / 안 한다 %s" % (" · ".join(do), " · ".join(dont))
    return field_text(value)


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


def intent_meta(text: str) -> dict:
    """INTENT.md 머리의 키 → 따옴표를 벗긴 값. 머리가 없거나 닫히지 않았으면 FormatError."""
    _header_end(text.split("\n"))
    return {k: unquote(v) for k, v in frontmatter(text).items()}


def intent_ranges(text: str) -> list:
    lines = text.split("\n")
    _header_end(lines)
    if intent_meta(text).get("kind") == KIND_TASK:
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


# ── 원자료 사본(original.md) ─────────────────────────────────────────────────
# 구간마다 첫 줄이 출처 줄이고 그 아래 출처 줄이 적은 줄 수만큼이 본문이다. 파일 머리는 따로 없다.

LABELS = ("원문", "질문 전체", "사용자 원문")
REAPPENDED = "앞머리가 달라 통째로 다시 옮김"   # 이 표지가 붙은 구간부터가 그 출처의 지금 판이다
_MARKER_RE = re.compile(r"<!-- 출처: (?P<source>\S(?:.*\S)?)@(?P<commit>[0-9a-f]{40}(?:[0-9a-f]{24})?)"
                        r" · (?P<label>" + "|".join(re.escape(x) for x in LABELS) + r")"
                        r" · (?P<first>[0-9]+)–(?P<last>[0-9]+)행 · (?P<count>[0-9]+)줄"
                        r"(?: · (?P<note>\S(?:.*\S)?))? -->")


@dataclass
class Section:
    source: str
    commit: str
    label: str
    first: int
    last: int
    note: str
    start: int   # original.md 안에서 본문 첫 줄의 번호
    body: bytes


def byte_lines(data: bytes) -> list:
    """`\\n` 으로만 가른 줄들(줄바꿈을 붙인 채). `\\r` 은 줄 안의 글자로 남는다."""
    out = [line + b"\n" for line in data.split(b"\n")]
    out[-1] = out[-1][:-1]
    if not out[-1]:
        out.pop()
    return out


def line_count(data: bytes) -> int:
    return len(byte_lines(data))


def marker_line(source: str, commit: str, label: str, first: int, last: int, note: str = "") -> str:
    if label not in LABELS:
        raise FormatError("구간 절 이름이 아니다: %r" % label)
    if first < 1 or last < first:
        raise FormatError("구간 범위가 0 으로 시작하거나 뒤집혔다: %d–%d" % (first, last))
    for value in (source, note):
        if "\n" in value or "\r" in value:
            raise FormatError("출처 줄에 줄바꿈을 넣지 않는다: %r" % value)
    tail = " · %s" % note if note else ""
    return "<!-- 출처: %s@%s · %s · %d–%d행 · %d줄%s -->" % (source, commit, label, first, last, last - first + 1, tail)


def parse_original(data: bytes) -> list:
    """구간 목록. 출처 줄이 적은 줄 수로 본문을 읽는다 — 본문 안의 출처 줄 꼴 글은 본문이다."""
    if not data:
        raise FormatError("원자료 사본이 비었다")
    try:
        data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise FormatError("원자료 사본이 UTF-8 이 아니다(%s)" % exc)
    if not data.endswith(b"\n"):
        raise FormatError("원자료 사본의 끝에 줄바꿈이 없다")
    lines = byte_lines(data)
    out, i = [], 0
    while i < len(lines):
        m = _MARKER_RE.fullmatch(lines[i][:-1].decode("utf-8"))
        if not m:
            raise FormatError("%d행이 구간의 출처 줄이 아니다 — 구간 밖에 줄이 있다" % (i + 1))
        first, last, count = int(m.group("first")), int(m.group("last")), int(m.group("count"))
        if first < 1 or last < first or last - first + 1 != count:
            raise FormatError("%d행 출처 줄의 범위 %d–%d 와 줄 수 %d 가 어긋난다" % (i + 1, first, last, count))
        if i + 1 + count > len(lines):
            raise FormatError("%d행 구간의 줄이 모자란다 — %d줄 가운데 %d줄뿐이다" % (i + 1, count, len(lines) - i - 1))
        out.append(Section(m.group("source"), m.group("commit"), m.group("label"), first, last, m.group("note") or "",
                           i + 2, b"".join(lines[i + 1:i + 1 + count])))
        i += 1 + count
    return out


def extend_original(existing: bytes, wanted: list) -> tuple:
    """(새 바이트, 알림 줄들). wanted 는 (source, commit, label, first, lines, note) 들 — lines 는 줄바꿈을 붙인 바이트 줄.

    같은 출처(경로 + 절 이름)의 지금 판(마지막 다시 옮김부터)의 본문을 이은 것이 lines 의 앞머리면 남은 줄만,
    같으면 아무것도, 아니면 통째로 끝에 붙이고 알린다. 앞 바이트는 바꾸지 않는다."""
    sections = parse_original(existing) if existing else []
    out, notes = [existing], []
    for source, commit, label, first, lines, note in wanted:
        if not lines:
            continue
        for k, line in enumerate(lines):
            if not line.endswith(b"\n"):
                raise FormatError("%s · %s 구간의 %d행 끝에 줄바꿈이 없다 — 출처 파일 끝에 줄바꿈을 더해 커밋한 뒤 다시 돈다"
                                  % (source, label, first + k))
        group = [s for s in sections if (s.source, s.label) == (source, label)]
        since = max([i for i, s in enumerate(group) if REAPPENDED in s.note.split(" · ")] or [0])
        prev, cur = b"".join(s.body for s in group[since:]), b"".join(lines)
        if group and cur == prev:
            continue
        if group and cur.startswith(prev):
            skip, mark = prev.count(b"\n"), note
        else:
            skip, mark = 0, note
            if group:
                mark = " · ".join(x for x in (note, REAPPENDED) if x)
                notes.append("%s · %s: 앞 줄이 사본의 지금 판과 달라 그 절을 끝에 통째로 다시 옮겼다 — 앞 구간은 그대로 둔다"
                             % (source, label))
        tail = lines[skip:]
        head = marker_line(source, commit, label, first + skip, first + skip + len(tail) - 1, mark)
        block = head.encode("utf-8") + b"\n" + b"".join(tail)
        start = line_count(b"".join(out)) + 2
        sections.append(Section(source, commit, label, first + skip, first + skip + len(tail) - 1, mark, start, b"".join(tail)))
        out.append(block)
    return b"".join(out), notes
