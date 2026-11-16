#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""team_files.py — team 형식의 틀 위치와 과제 파일(INTENT · sources)과 원자료 사본(original.md)과 결과 파일 · 막힘 파일의 글을 만들고 읽는다.

글만 다룬다 — 파일을 쓰지 않고 git 을 부르지 않는다. 경로 조각은 team_layout 에서 가져온다.
"""
from __future__ import annotations

import datetime
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
import team_layout  # noqa: E402
import section6  # noqa: E402
from roadmap_model import CONFIRM_RE, FormatError, field_text, frontmatter, section_body, unquote  # noqa: E402,F401

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


def roadmap_rel(meta: dict) -> str:
    """INTENT.md 머리 `roadmap` 의 값 — 레포 상대 경로가 아니면(빈 값 · `/` 로 시작 · 역슬래시 · `..` 조각) FormatError."""
    value = meta.get("roadmap") or ""
    if not value or value.startswith("/") or "\\" in value or ".." in value.split("/"):
        raise FormatError("머리 roadmap 이 레포 상대 경로가 아니다: %s" % value)
    return value


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


# ── 결과 파일 · 막힘 파일 ────────────────────────────────────────────────────
# 머리(첫 줄 `---` 부터 다음 `---` 까지)와 기계 줄(펜스 밖 · 줄 머리)을 읽는다. 줄 끝의 `\r` 은 뗀다.

RESULT_TYPE = "job-result"
BLOCKED_TYPE = "job-blocked"
BLOCKED_HEADS = ("## 무엇에 막혔나", "## 풀려면 무엇이 필요한가")

_COMMIT_RE = re.compile(r"[0-9a-f]{40}(?:[0-9a-f]{24})?")
_NUMBER_RE = re.compile(r"[1-9][0-9]*")
_TASK_RE = re.compile(r"Task (0|[1-9][0-9]*)/(0|[1-9][0-9]*): (끝|막힘) — (\S.*)")   # 0 은 읽고(진행 줄 깨짐이 된다) 앞의 0 은 꼴이 아니다
_AC_RE = re.compile(r"AC[0-9]+:")
_END_PREFIX = "끝 — "
END_EMPTY = "「끝」 줄에 커밋 글이 없다"   # 이 사유가 있으면 「끝」 줄은 있되 읽을 커밋이 없다(job_results 가 「끝 줄이 없다」 를 덧내지 않는다)
END_PREFIX = _END_PREFIX
_TASK_BLOCKED = "막힘"
_MACHINE_PREFIXES = ("Ruling:", "규칙 반증:", "산출물:")
NO_HEAD = "머리(첫 줄 `---`)가 없다"
OPEN_HEAD = "머리가 닫히지 않았다(`---` 줄이 하나뿐이다)"
TASK_SHAPE = "Task 줄 꼴이 아니다(Task <n>/<전체>: 끝|막힘 — <커밋>)"
PROGRESS_NONE, PROGRESS_BROKEN = "진행 줄 없음", "진행 줄 깨짐"   # progress_of 의 사유 머리


@dataclass
class Result:
    stage: Optional[str] = None
    plan: Optional[int] = None
    attempt: Optional[int] = None
    role: Optional[str] = None
    head: Optional[str] = None
    bundle_at: Optional[str] = None
    job_at: Optional[str] = None
    tasks: list = field(default_factory=list)
    rulings: list = field(default_factory=list)
    refutes: list = field(default_factory=list)
    outputs: list = field(default_factory=list)
    end: Optional[str] = None
    machine_text: str = ""
    problems: list = field(default_factory=list)


@dataclass
class Blocked:
    stage: Optional[str] = None
    plan: Optional[int] = None
    attempt: Optional[int] = None
    head: Optional[str] = None
    problems: list = field(default_factory=list)


def _split_head(text: str) -> tuple:
    """(머리의 키 → 값, 머리 뒤 줄들, 사유 | None, 두 번 나온 키의 사유들). 첫 글자가 BOM 이면 머리가 없는 것이다."""
    lines = [line.rstrip("\r") for line in text.split("\n")]
    if lines[0] != "---":
        return {}, lines, NO_HEAD, []
    meta, dups = {}, []
    for i in range(1, len(lines)):
        if lines[i] == "---":
            return meta, lines[i + 1:], None, dups
        if ":" in lines[i] and lines[i][0] not in " \t-#":
            key, value = lines[i].split(":", 1)
            key = key.strip()
            if key in meta:
                dups.append("머리 키 %s 가 두 번 나온다" % key)
            meta.setdefault(key, value.strip())
    return {}, [], OPEN_HEAD, []


def _head_problems(meta: dict, type_value: str, keys: tuple) -> list:
    """keys 는 커밋 번호 꼴로 읽을 키들. type · stage · attempt · plan(있으면)은 늘 본다."""
    out = []
    if meta.get("type") != type_value:
        out.append("머리 type 이 %s 가 아니다: %r" % (type_value, meta.get("type")))
    if meta.get("stage") not in team_layout.STAGES:
        out.append("머리 stage 가 단계 이름이 아니다: %r" % meta.get("stage"))
    if not _NUMBER_RE.fullmatch(meta.get("attempt", "")):
        out.append("머리 attempt 가 1 이상의 수가 아니다: %r" % meta.get("attempt"))
    if "plan" in meta and not _NUMBER_RE.fullmatch(meta["plan"]):
        out.append("머리 plan 이 1 이상의 수가 아니다: %r" % meta["plan"])
    for key in keys:
        if not _COMMIT_RE.fullmatch(meta.get(key, "")):
            out.append("머리 %s 가 커밋 번호 꼴이 아니다: %r" % (key, meta.get(key)))
    return out


_FENCE_END_RE = re.compile(r" {0,3}(`{3,}|~{3,})[ \t]*")


def _outside_fences(lines: list) -> tuple:
    """(펜스 밖의 줄들, 닫히지 않은 펜스가 있나). 펜스를 세는 규칙은 section6 한 곳이다."""
    text = "\n".join(lines)
    spans = section6.fence_spans_in(text)
    out, pos = [], 0
    for line in lines:
        if not any(a <= pos < b for a, b in spans):
            out.append(line)
        pos += len(line) + 1
    unclosed = False
    if spans:
        shown = text[spans[-1][0]:spans[-1][1]].split("\n")   # 마지막 펜스가 닫는 줄로 끝나는지 본다
        opener = _FENCE_END_RE.match(shown[0]).group(1)
        closer = _FENCE_END_RE.fullmatch(shown[-1])
        unclosed = len(shown) < 2 or not (closer and closer.group(1)[0] == opener[0] and len(closer.group(1)) >= len(opener))
    return out, unclosed


_UNCLOSED_FENCE = "본문의 코드 펜스가 닫히지 않았다 — 끝까지 펜스 안으로 읽어 기계 줄을 읽지 않았다"


def _is_machine(line: str) -> bool:
    return (line.startswith("Task ") and line[5:6].isdigit()) or line.startswith(_END_PREFIX) \
        or _AC_RE.match(line) is not None or line.startswith(_MACHINE_PREFIXES)


def _number(meta: dict, key: str) -> Optional[int]:
    return int(meta[key]) if _NUMBER_RE.fullmatch(meta.get(key, "")) else None


def _commit(meta: dict, key: str) -> Optional[str]:
    return meta[key] if _COMMIT_RE.fullmatch(meta.get(key, "")) else None


def parse_result(text: str) -> Result:
    """결과 파일 글 → Result. 던지지 않는다 — 읽지 못한 것은 problems 에 한 줄씩 적는다."""
    r = Result()
    meta, rest, why, dups = _split_head(text)
    if why:
        r.problems.append(why)
        return r
    r.problems += dups + _head_problems(meta, RESULT_TYPE, ("head", "bundle_at", "job_at"))
    if meta.get("role") not in team_layout.ROLES:
        r.problems.append("머리 role 이 역할 이름이 아니다: %r" % meta.get("role"))
    r.stage, r.role = meta.get("stage"), meta.get("role")
    r.head, r.bundle_at, r.job_at = _commit(meta, "head"), _commit(meta, "bundle_at"), _commit(meta, "job_at")
    r.attempt, r.plan = _number(meta, "attempt"), _number(meta, "plan")
    body, unclosed = _outside_fences(rest)
    if unclosed:
        r.problems.append(_UNCLOSED_FENCE)
    r.machine_text = "\n".join(body)
    ended = False
    for line in body:
        if not _is_machine(line):
            continue
        if line.startswith(_END_PREFIX):
            if ended:
                r.problems.append("「끝」 줄이 둘이다: %s" % line)
            elif not line[len(_END_PREFIX):].strip():
                r.problems.append("%s: %s" % (END_EMPTY, line))
            else:
                r.end = line[len(_END_PREFIX):].strip()
            ended = True
            continue
        if ended:
            r.problems.append("「끝」 줄 뒤에 기계 줄이 있다: %s" % line)
        if line.startswith("Task "):
            m = _TASK_RE.fullmatch(line)
            if m:
                r.tasks.append((int(m.group(1)), int(m.group(2)), m.group(3), m.group(4)))
            else:
                r.problems.append("%s: %s" % (TASK_SHAPE, line))
        elif line.startswith("Ruling:"):
            r.rulings.append(line)
        elif line.startswith("규칙 반증:"):
            r.refutes.append(line)
        elif line.startswith("산출물:"):
            value = line[len("산출물:"):].strip()
            if value:
                r.outputs.append(value)
            else:
                r.problems.append("산출물 줄의 경로가 비었다")
    return r


def progress_of(result: Result) -> tuple:
    """`(끝난 수, 전체, None)` 또는 `(None, None, 사유)`. 전체는 마지막 Task 줄의 것이다 — 계획의 task 절 수는 구현 중에 바뀐다."""
    if not result.tasks:
        return None, None, PROGRESS_NONE
    for n, whole, state, commit in result.tasks:
        if n < 1 or whole < 1 or n > whole:
            return None, None, "%s — Task %d/%d: %s — %s" % (PROGRESS_BROKEN, n, whole, state, commit)
    n, total, state, _ = result.tasks[-1]
    return (n - 1 if state == _TASK_BLOCKED else n), total, None


def lost_lines(result: Result) -> list:
    """result.problems 가운데 기계 줄을 빠뜨리게 한 것 — 머리를 못 읽어 본문을 읽지 않음 · 닫히지 않은 펜스 · 꼴이 아닌 Task 줄.
    하나라도 있으면 진행 숫자 · 「끝」 줄의 있고 없음을 그 파일에서 셀 수 없다."""
    return [p for p in result.problems
            if p in (NO_HEAD, OPEN_HEAD, _UNCLOSED_FENCE) or p.startswith(TASK_SHAPE + ": ")]


def parse_blocked(text: str) -> Blocked:
    """막힘 파일 글 → Blocked. 던지지 않는다."""
    b = Blocked()
    meta, rest, why, dups = _split_head(text)
    if why:
        b.problems.append(why)
        return b
    b.problems += dups + _head_problems(meta, BLOCKED_TYPE, ("head",))
    b.stage, b.head = meta.get("stage"), _commit(meta, "head")
    b.attempt, b.plan = _number(meta, "attempt"), _number(meta, "plan")
    body, unclosed = _outside_fences(rest)
    if unclosed:
        b.problems.append(_UNCLOSED_FENCE)
    heads = tuple(line for line in body if line.startswith("## "))
    if heads != BLOCKED_HEADS:
        b.problems.append("본문의 `## ` 제목이 %s 뿐이어야 한다: %s" % (" · ".join(BLOCKED_HEADS), list(heads)))
    return b


# ── 결정 기록 ────────────────────────────────────────────────────────────────

DECISION_KINDS = ("spec 승인", "병렬 답", "계획 검토", "결과 받음", "예약 밖 변경", "넘김 확인", "결정")
_KIND_RECEIVED, _KIND_CONFIRM = DECISION_KINDS[3], DECISION_KINDS[5]
_DATE_RE = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}")
_RECEIVED_RE = re.compile(r"- 결과 받음 · (?P<date>[0-9]{4}-[0-9]{2}-[0-9]{2}) · 「(?P<name>[^ ·」]+) · "
                          r"(?P<commit>[0-9a-f]{40}(?:[0-9a-f]{24})?) · (?P<first>\S.*)」")
_DECISION_HEAD = "## 결정 기록"


def _real_date(value: str) -> bool:
    if not _DATE_RE.fullmatch(value):
        return False
    try:
        datetime.date.fromisoformat(value)
    except ValueError:
        return False
    return True


def decision_lines(intent_text: str) -> list:
    """결정 기록 칸의 `- ` 줄들. 칸을 못 찾으면 FormatError."""
    return [l for l in intent_sections(intent_text)["결정 기록"].split("\n") if l.startswith("- ")]


def decision_problem(line: str) -> Optional[str]:
    """결정 기록에 쓸 수 없는 줄이면 사유, 받을 수 있으면 None."""
    if line == "":
        return "빈 줄이다"
    if line.splitlines() != [line]:
        return "줄 나눔 글자가 든 줄이다: %r" % line
    if not line.startswith("- "):
        return "`- ` 로 시작하지 않는다: %r" % line
    parts = line[2:].split(" · ", 2)
    if parts[0] not in DECISION_KINDS:
        return "종류가 %s 가운데 하나가 아니다: %r" % (" · ".join(DECISION_KINDS), parts[0])
    if parts[0] == _KIND_CONFIRM:
        return None if CONFIRM_RE.fullmatch(line) else "넘김 확인 줄 꼴이 아니다(- 넘김 확인 · <에픽> · <8자> · <근거>): %r" % line
    if len(parts) < 3 or not _real_date(parts[1]) or not parts[2].strip():
        return "`- <종류> · <YYYY-MM-DD> · <글>` 꼴이 아니다: %r" % line
    if parts[0] == _KIND_RECEIVED:
        m = _RECEIVED_RE.fullmatch(line)
        if not m or team_layout.parse_result_name(m.group("name")) is None:
            return "결과 받음 줄 꼴이 아니다(「<결과 파일 이름> · <커밋> · <첫 줄>」): %r" % line
    return None


def append_decision(intent_text: str, line: str) -> str:
    """결정 기록 칸 맨 아래에 줄을 덧붙인 글. 같은 줄이 있으면 글 그대로, 못 받는 줄이면 FormatError.

    맨 앞 `- ` 가 없는 줄은 `- ` 를 앞에 붙여 받는다(있는 줄과 같은지도 붙인 꼴로 본다).
    """
    if not line.startswith("- "):
        line = "- " + line
    why = decision_problem(line)
    if why:
        raise FormatError(why)
    if line in decision_lines(intent_text):
        return intent_text
    lines = intent_text.split("\n")
    h = max(i for i, l in enumerate(lines) if l == _DECISION_HEAD)
    tail = lines[h + 1:]
    while tail and tail[-1] == "":
        tail.pop()
    head = "\n".join(lines[:h + 1])
    if not tail:
        return head + "\n\n" + line + "\n"
    return head + "\n" + "\n".join(tail) + "\n" + line + "\n"


@dataclass
class Received:
    date: str
    name: str
    commit: str
    first: str
    raw: str


def received_line(date: str, name: str, commit: str, first: str) -> str:
    line = "- %s · %s · 「%s · %s · %s」" % (_KIND_RECEIVED, date, name, commit, first)
    why = decision_problem(line)
    if why:
        raise FormatError(why)
    return line


def received(intent_text: str) -> tuple:
    """`(받음 줄 목록, 꼴이 깨진 받음 줄 목록)`. 받음 줄은 적힌 순서대로다."""
    good, broken = [], []
    for line in decision_lines(intent_text):
        if not line.startswith("- %s" % _KIND_RECEIVED):
            continue
        m = _RECEIVED_RE.fullmatch(line) if decision_problem(line) is None else None
        if m:
            good.append(Received(m.group("date"), m.group("name"), m.group("commit"), m.group("first"), line))
        else:
            broken.append(line)
    return good, broken


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
