#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""human_lines.py — 사람 줄(spec 승인 · 계획 검토 · 흐름 승인 · 걸음 건너뜀)의 꼴 · 통과 라벨 표 · 관문 이름 · 본문 · 판 ·
꼴 판정 · 대조 판정 · 관문 표가 사는 한 곳.

읽기만 한다 — 파일을 쓰지 않는다. 세션 기록은 대조 판정(`match`)만 `session_record` 로 읽고, 꼴 판정(`shape`)은 읽지 않는다.
git 은 부르는 쪽이 넘긴 객체(`roadmap_status.Git`)로만 읽는다. 관문 표는 이 파일의 상수다 — 설정 · 걸음표 · 환경에서 읽지 않는다.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import NamedTuple, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
import roadmap_model  # noqa: E402
import section6  # noqa: E402
import session_record  # noqa: E402
import team_files  # noqa: E402
import team_layout  # noqa: E402

KIND_SPEC, KIND_PLAN, KIND_FLOW, KIND_SKIP = "spec 승인", "계획 검토", "흐름 승인", "걸음 건너뜀"
KINDS = (KIND_SPEC, KIND_PLAN, KIND_FLOW, KIND_SKIP)
SKIP_LABEL, RETRY_LABEL = "건너뛴다", "다시 시도한다"
PASS_LABELS = {KIND_SPEC: ("승인 — 계획 담당자에게",), KIND_PLAN: ("계획대로 구현한다",),
               KIND_FLOW: ("설계 없이 진행",), KIND_SKIP: (SKIP_LABEL, RETRY_LABEL)}
RECOMMENDED = "(권장)"

PASS, NO_EVIDENCE, MISMATCH, UNCHECKED, STALE = "지남", "근거 없음", "어긋남", "확인 못 함", "낡음"

GATES = {"design": (), "plan": (KIND_SPEC,), "implement": (KIND_SPEC, KIND_PLAN), "review": (KIND_SPEC, KIND_PLAN)}
PLAIN_GATES = (KIND_FLOW,)
RETRY_STOP = 2
GATE_OFF = "사람 줄 대조가 꺼져 있다"
NO_LINE = "줄이 없다"
_HAD, _GOT = "%s 가 있다", "%s 의 받음 줄이 있다"
_AGAIN = "질문 창으로 다시 승인받는다"
_OPEN = "기록의 꼴이 바뀐 것이면 레포 설정 human_gate: 끔 으로 연다"

RECORD_HEADS = ("## 결정 기록", "## 지휘 기록", "## 미룸", "## 판정", "## 구현 대조")
DEFERRED_HEAD = "### Deferred to plan"

_NUM = r"[1-9][0-9]*"
_LINE_RE = re.compile(
    r"- (?P<kind>%s) · (?P<date>[0-9]{4}-[0-9]{2}-[0-9]{2}) · 「(?P<label>[^」]+)」(?: · (?P<gate>[^·]+?))?"
    r" · (?P<file>[^ ·@]+)@(?P<rev>[0-9a-f]{8})"
    r" · 근거 (?P<session>[A-Za-z0-9_-]{8,}):(?P<entry>[0-9a-f-]{36})#(?P<index>%s)"
    % ("|".join(re.escape(k) for k in KINDS), _NUM))
_SKIP_GATES = (re.compile(r"spec 승인"), re.compile(r"계획 검토 plan %s" % _NUM))
_RETRY_GATES = (re.compile(r"다시 시도 plan %s 시도 %s" % (_NUM, _NUM)), re.compile(r"다시 시도 구현 시도 %s" % _NUM))
_GATE_PLAN_RE = re.compile(r".* plan ([1-9][0-9]*)(?: .*)?")
_GATE_NAME_RE = re.compile(r"spec 승인|계획 검토 plan %s|다시 시도 plan %s 시도 %s|다시 시도 구현 시도 %s" % (_NUM, _NUM, _NUM, _NUM))


class Line(NamedTuple):
    kind: str
    date: str
    label: str
    gate: Optional[str]
    file: str
    rev: str
    session: str
    entry: str
    index: int
    raw: str

    @property
    def key(self):
        return "%s#%d" % (self.entry, self.index)

    @property
    def plan(self):
        n = team_layout.plan_number(self.file)
        if n is not None:
            return n
        m = _GATE_PLAN_RE.fullmatch(self.gate) if self.gate else None
        return int(m.group(1)) if m else None


class Verdict(NamedTuple):
    verdict: str
    why: str
    line: Optional[Line]
    raw: str


class Scope(NamedTuple):
    git: object
    team: object
    job: str
    tip: str
    lines: tuple = ()
    gate_on: bool = True


def is_human(raw: str) -> Optional[str]:
    if not isinstance(raw, str):
        return None
    for kind in KINDS:
        if raw.startswith("- " + kind + " · "):
            return kind
    return None


def _file_ok(kind: str, file: str) -> bool:
    if kind == KIND_SPEC:
        return file == team_layout.DESIGN_FILE
    if kind == KIND_PLAN:
        return team_layout.plan_number(file) is not None
    return file == team_layout.INTENT_FILE


def _gate_ok(kind: str, label: str, gate: Optional[str]) -> bool:
    if kind != KIND_SKIP:
        return gate is None
    if gate is None:
        return False
    pool = _SKIP_GATES if label == SKIP_LABEL else _RETRY_GATES
    return any(p.fullmatch(gate) for p in pool)


def parse(raw: str) -> Optional[Line]:
    if not isinstance(raw, str) or team_files.decision_problem(raw) is not None:
        return None
    m = _LINE_RE.fullmatch(raw)
    if m is None:
        return None
    kind, label, gate, file = m.group("kind"), m.group("label"), m.group("gate"), m.group("file")
    if label not in PASS_LABELS[kind] or not _file_ok(kind, file) or not _gate_ok(kind, label, gate):
        return None
    return Line(kind, m.group("date"), label, gate, file, m.group("rev"), m.group("session"), m.group("entry"),
                int(m.group("index")), raw)


def render(kind, date, label, file, rev, session, key, gate=None) -> str:
    mid = "" if gate is None else " · " + gate
    return "- %s · %s · 「%s」%s · %s@%s · 근거 %s:%s" % (kind, date, label, mid, file, rev, session, key)


def clean_label(text: str) -> str:
    out = text.strip()
    if out.endswith(RECOMMENDED):
        out = out[:-len(RECOMMENDED)].rstrip()
    return out


def head(job: str, rev: str, plan: Optional[int] = None) -> str:
    if plan is None:
        return "%s @%s" % (job, rev)
    return "%s plan %d @%s" % (job, plan, rev)


def starts_with_head(question: str, job: str, rev: str, plan: Optional[int] = None) -> bool:
    want = head(job, rev, plan)
    if not isinstance(question, str) or not question.startswith(want):
        return False
    rest = question[len(want):len(want) + 1]
    return rest == "" or rest not in "0123456789abcdef"


def bound_name(kind: str, plan: Optional[int] = None) -> str:
    if kind == KIND_SPEC:
        return team_layout.DESIGN_FILE
    if kind == KIND_PLAN:
        return team_layout.plan_name(plan)
    if kind in (KIND_FLOW, KIND_SKIP):
        return team_layout.INTENT_FILE
    raise ValueError("사람 줄 종류가 아니다: %r" % (kind,))


def gate_name(kind: str, plan: Optional[int] = None) -> str:
    if kind == KIND_SPEC:
        return KIND_SPEC
    if kind == KIND_PLAN:
        return "%s plan %d" % (KIND_PLAN, plan)
    raise ValueError("관문 이름이 있는 종류가 아니다: %r" % (kind,))


def retry_name(plan: Optional[int], attempt: int) -> str:
    if plan is None:
        return "다시 시도 구현 시도 %d" % attempt
    return "다시 시도 plan %d 시도 %d" % (plan, attempt)


def names_gate(text: str, name: str) -> bool:
    if not text or not name:
        return False
    at = text.find(name)
    while at >= 0:
        end = at + len(name)
        if end >= len(text) or not "0" <= text[end] <= "9":
            return True
        at = text.find(name, at + 1)
    return False


def gate_names_in(text: str) -> list:
    """글에 든 건너뜀 · 다시 시도 관문 이름들(처음 나온 차례 · 겹침 없이). 이름 바로 뒤에 숫자가 이어지면 그 이름이 아니다."""
    out = []
    for m in _GATE_NAME_RE.finditer(text if isinstance(text, str) else ""):
        if m.end() < len(text) and "0" <= text[m.end()] <= "9":
            continue
        if m.group(0) not in out:
            out.append(m.group(0))
    return out


def _heading_level(line: str) -> int:
    if line.startswith("### "):
        return 3
    if line.startswith("## "):
        return 2
    if line.startswith("# "):
        return 1
    return 0


def _is_head(line: str, title: str) -> bool:
    """제목이 정확히 title 이다. `## 구현 대조` 만 `## 구현 대조 — <계획 파일 경로>` 꼴도 받는다(설계 §2 「본문」)."""
    if line == title:
        return True
    if not line.startswith(roadmap_model.IMPL_PREFIX) or title != roadmap_model.IMPL_PREFIX[:-3]:
        return False
    path = line[len(roadmap_model.IMPL_PREFIX):]
    return path.endswith(".md") and len(path) > 3 and path.split() == [path]


def _trim_blank_tail(lines: list) -> str:
    end = len(lines)
    while end > 0 and lines[end - 1] == "":
        end -= 1
    return "\n".join(lines[:end])


def _design_body(text: str) -> str:
    spans = section6.fence_spans_in(text)
    out, pos, cut = [], 0, None   # cut: "record"(다음 2단계 제목까지) · "deferred"(다음 1–3단계 제목까지) · None
    for line in text.split("\n"):
        here, pos = pos, pos + len(line) + 1
        fenced = any(a <= here < b for a, b in spans)
        level = 0 if fenced else _heading_level(line)
        if cut == "record" and level == 2:
            cut = None
        elif cut == "deferred" and 1 <= level <= 3:
            cut = None
        if cut is None and level == 2 and any(_is_head(line, h) for h in RECORD_HEADS):
            cut = "record"
        elif cut is None and level == 3 and _is_head(line, DEFERRED_HEAD):
            cut = "deferred"
        if cut is None:
            out.append(line)
    return _trim_blank_tail(out)


def _intent_body(text: str) -> str:
    lines = text.split("\n")
    last = None
    for i, line in enumerate(lines):
        if line == RECORD_HEADS[0]:
            last = i
    return _trim_blank_tail(lines if last is None else lines[:last])


def body_of(name: str, text: str) -> str:
    if name == team_layout.DESIGN_FILE:
        return _design_body(text)
    if name == team_layout.INTENT_FILE:
        return _intent_body(text)
    return _trim_blank_tail(text.split("\n"))


def version(git, tip: str, path: str) -> Optional[str]:
    name = path.rsplit("/", 1)[-1]
    now = git.blob(tip, path)
    if now is None:
        return None
    rc, out, err = git.run_err("log", "--format=%H", tip, "--", ":(top,literal)" + path)
    if rc != 0:
        git.fail("log", rc, err)
        return None
    commits = [c for c in out.split("\n") if c]
    if not commits:
        return None
    want, found = body_of(name, now), commits[0]
    for commit in commits[1:]:
        text = git.blob(commit, path)
        if text is None or body_of(name, text) != want:
            break
        found = commit
    return found[:8]


def _path_of(scope: Scope, line: Line) -> str:
    if line.kind == KIND_SPEC:
        return scope.team.design(scope.job)
    if line.kind == KIND_PLAN:
        return scope.team.plan(scope.job, line.plan)
    return scope.team.intent(scope.job)


def shape(scope: Scope, raw: str) -> Verdict:
    line = parse(raw)
    if line is None:
        return Verdict(NO_EVIDENCE, "근거 칸이 없거나 줄 꼴이 아니다(옛 줄 · 손으로 쓴 줄)", None, raw)
    path = _path_of(scope, line)
    now = scope.git.blob(scope.tip, path)
    if now is None:
        return Verdict(UNCHECKED, "%s 을 %s 에서 읽지 못했다" % (line.file, scope.tip[:8]), line, raw)
    commit = scope.git.commit(line.rev)
    then = scope.git.blob(commit, path) if commit else None
    if then is None:
        return Verdict(UNCHECKED, "줄의 판 %s 을 이 레포에서 읽지 못한다 — 질문 창으로 다시 승인받는다" % line.rev, line, raw)
    if body_of(line.file, then) != body_of(line.file, now):
        return Verdict(STALE, "%s 의 본문이 승인한 판 %s 뒤에 바뀌었다 — 달라진 곳을 보이고 다시 승인받는다" % (line.file, line.rev),
                       line, raw)
    return Verdict(PASS, "승인한 판 %s 의 본문과 같다" % line.rev, line, raw)


class Passed(NamedTuple):
    date: str
    skipped: bool   # 건너뜀 줄로 지났다


def _unchecked(line: Line, raw: str, why: str, shape_changed: bool = False) -> Verdict:
    tail = "%s. %s" % (_AGAIN, _OPEN) if shape_changed else _AGAIN
    return Verdict(UNCHECKED, "%s — %s" % (why, tail), line, raw)


def _no_answer(path, line: Line, raw: str) -> Verdict:
    """근거의 `uuid#n` 답이 없을 때 — 그 항목에 질문을 읽지 못한 호출의 결과가 있으면 가를 수 없다(확인 못 함)."""
    try:
        lost = [c for c in session_record.unreadable(path) if c.entry == line.entry]
    except session_record.Unreadable as exc:
        return _unchecked(line, raw, str(exc))
    if lost:
        return _unchecked(line, raw, "근거가 가리키는 질문 창 호출의 질문을 읽지 못했다", True)
    return Verdict(MISMATCH, "근거가 가리키는 질문 창 답이 세션 기록에 없다", line, raw)


def match(scope: Scope, raw: str) -> Verdict:
    """대조 판정 — 꼴 판정을 지난 줄을 근거 칸이 가리키는 질문 창 답과 견준다. 날짜는 견주지 않는다(J28)."""
    first = shape(scope, raw)
    if first.verdict != PASS:
        return first
    line = first.line
    try:
        path = session_record.locate(line.session)
        ans = session_record.find(path, line.key)
    except session_record.Unreadable as exc:
        return _unchecked(line, raw, str(exc))
    if ans is None:
        return _no_answer(path, line, raw)
    if ans.who == session_record.UNKNOWN:
        return _unchecked(line, raw, ans.why, True)
    if ans.who != session_record.HUMAN:
        return Verdict(MISMATCH, ans.why or "사람이 질문 창에서 고른 답이 아니다", line, raw)
    plan = line.plan if line.kind == KIND_PLAN else None
    if not starts_with_head(ans.question, scope.job, line.rev, plan):
        return Verdict(MISMATCH, "그 질문은 머리 %s 로 시작하지 않는다" % head(scope.job, line.rev, plan), line, raw)
    picked = clean_label(ans.label)
    if picked != line.label:
        return Verdict(MISMATCH, "사람이 고른 라벨은 「%s」 이다" % picked, line, raw)
    if line.kind == KIND_SKIP and not names_gate(ans.question, line.gate):
        return Verdict(MISMATCH, "그 질문에 관문 이름 %s 이 없다" % line.gate, line, raw)
    named = gate_names_in(ans.question) if line.kind == KIND_SKIP else []
    if len(named) > 1:   # 질문 하나가 관문 하나만 가리킨다 — 한 번의 답으로 묻지 않은 관문의 줄을 지어내지 못하게
        return Verdict(MISMATCH, "그 질문에 관문 이름이 둘 이상 있다(%s) — 관문마다 따로 묻는다" % " · ".join(named), line, raw)
    for other in scope.lines:
        twin = parse(other) if other != raw else None
        if twin is not None and twin.key == line.key:   # 세션이 달라도 같은 답이다(J3)
            return Verdict(MISMATCH, "같은 답을 근거로 쓴 줄이 또 있다", line, raw)
    return Verdict(PASS, "질문 창 답 %s:%s 과 맞는다" % (line.session, line.key), line, raw)


def needed(stage: str, plan: Optional[int], plain: bool) -> list:
    """관문 표 — [(종류, 계획 | None), …]. 설계 없는 흐름이면 어느 단계든 흐름 승인 하나."""
    if plain:
        return [(k, None) for k in PLAIN_GATES]
    return [(k, plan if k == KIND_PLAN else None) for k in GATES[stage]]


def _skip_gate(kind: str, plan: Optional[int]) -> Optional[str]:
    if kind == KIND_SPEC or (kind == KIND_PLAN and plan is not None):
        return gate_name(kind, plan)
    return None


def _dated(raw, kind: str) -> Optional[str]:
    """`- <종류> · <YYYY-MM-DD> · ` 로 시작하는 줄이면 그 날짜, 아니면 None."""
    prefix = "- %s · " % kind
    if not isinstance(raw, str) or not raw.startswith(prefix):
        return None
    rest = raw[len(prefix):]
    if re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", rest[:10]) is None or not rest[10:].startswith(" · "):
        return None
    return rest[:10]


def _names_skip(raw, name: str) -> bool:
    return isinstance(raw, str) and raw.startswith("- %s · " % KIND_SKIP) and names_gate(raw, name)


def _passed_off(scope: Scope, kind: str, plan: Optional[int]) -> tuple:
    """관문이 꺼졌을 때(J9) — 줄이 있는지만 본다. 세션 기록도 판도 보지 않는다."""
    why = NO_LINE
    if kind == KIND_SPEC:
        try:
            date = roadmap_model.approval_in(list(scope.lines))
        except roadmap_model.FormatError as exc:
            date, why = None, "%s — %s" % (MISMATCH, exc)
        if date:
            return Passed(date, False), None
    else:
        for raw in scope.lines:
            date = _dated(raw, kind)
            if date:
                return Passed(date, False), None
    name = _skip_gate(kind, plan)
    for raw in scope.lines if name is not None else ():
        if _names_skip(raw, name):
            return Passed(_dated(raw, KIND_SKIP) or "", True), None
    return None, why


def passed(scope: Scope, kind: str, plan: Optional[int], deep: bool) -> tuple:
    """관문 하나 — (Passed | None, 사유 | None). deep 이 참이면 대조 판정, 거짓이면 꼴 판정으로 본다."""
    if not scope.gate_on:
        return _passed_off(scope, kind, plan)
    judge = match if deep else shape
    last = None
    for raw in scope.lines:
        if is_human(raw) != kind:
            continue
        line = parse(raw)
        if kind == KIND_PLAN and line is not None and line.plan != plan:
            continue
        got = judge(scope, raw)
        if got.verdict == PASS:
            return Passed(got.line.date, False), None
        last = got
    name, last_skip = _skip_gate(kind, plan), None
    for raw in scope.lines if name is not None else ():
        skip = parse(raw) if is_human(raw) == KIND_SKIP else None
        if skip is None or skip.gate != name:
            continue
        got = judge(scope, raw)
        if got.verdict == PASS:
            return Passed(skip.date, True), None
        last_skip = got
    last = last or last_skip   # 그 관문의 건너뜀 줄만 있고 지나지 못했으면 그 판정을 낸다 — 「줄이 없다」 로 감추지 않는다
    if last is None:
        return None, NO_LINE
    return None, "%s — %s" % (last.verdict, last.why)


def missing(scope: Scope, stage: str, plan: Optional[int], plain: bool, deep: bool) -> list:
    """지나지 못한 관문마다 사유 한 줄 — 관문 표의 차례."""
    out = []
    for kind, n in needed(stage, plan, plain):
        got, why = passed(scope, kind, n, deep)
        if got is not None:
            continue
        where = "" if n is None else "(계획 %d)" % n
        if why == NO_LINE:
            out.append("`%s` 줄이 없다%s — %s" % (kind, where, _write_hint(scope, kind, False)))
            continue
        text = "`%s` 줄이 지나지 못했다%s: %s" % (kind, where, why)
        if why.startswith(NO_EVIDENCE + " — ") or why.startswith(MISMATCH + " — "):
            text += " — " + _write_hint(scope, kind, True)
        out.append(text)
    return out


def _write_hint(scope: Scope, kind: str, again: bool) -> str:
    """줄을 (다시) 적는 길. 켜져 있으면 질문 창 답에서만(`record --human`), 꺼져 있으면 글로(§8 — 설계 승인은 옛 방식,
    나머지 종류는 `record --line`)."""
    verb = "다시 적는다" if again else "적는다"
    at = scope.team.intent(scope.job)   # 과제 폴더 안 경로면 record 가 그 과제의 INTENT.md 에 쓴다
    if scope.gate_on:
        return "질문 창으로 승인받고 `conductor_ledger.py record --human \"%s\"` 로 %s" % (kind, verb)
    if kind == KIND_SPEC:
        how = "`conductor_ledger.py record --spec %s --approval --date <YYYY-MM-DD> --choice \"<고른 글>\"`" % at
    else:
        how = "`conductor_ledger.py record --spec %s --line \"%s · <YYYY-MM-DD> · 「<고른 글>」\"`" % (at, kind)
    return "%s — 글로 %s: %s" % (GATE_OFF, verb, how)


def retry_open(scope: Scope, plan: Optional[int], attempt: int, deep: bool) -> bool:
    """그 시도를 푸는 산 `걸음 건너뜀` 줄(다시 시도)이 있는가."""
    name = retry_name(plan, attempt)
    if not scope.gate_on:
        return any(_names_skip(raw, name) for raw in scope.lines)
    judge = match if deep else shape
    for raw in scope.lines:
        skip = parse(raw) if is_human(raw) == KIND_SKIP else None
        if skip is not None and skip.gate == name and judge(scope, raw).verdict == PASS:
            return True
    return False


def collect(git, team, job: str, tips) -> tuple:
    """(겹침 없는 결정 기록 줄들 — 처음 나온 차례, 알림 줄들). 끝마다 그 과제 INTENT.md 의 결정 기록 줄을 한 번씩 읽는다."""
    path = team.intent(job)
    lines, seen, notes, done = [], set(), [], set()
    for tip in tips:
        if tip in done:
            continue
        done.add(tip)
        text = git.blob(tip, path)
        if text is None:
            if not git.absent(tip, path):
                notes.append("%s 의 결정 기록을 읽지 못했다 — git 이 %s 를 읽지 못했다" % (tip[:8], team_layout.INTENT_FILE))
            continue
        try:
            found = team_files.decision_lines(text)
        except roadmap_model.FormatError as exc:
            notes.append("%s 의 결정 기록을 읽지 못했다 — %s" % (tip[:8], exc))
            continue
        for one in found:
            if one not in seen:
                seen.add(one)
                lines.append(one)
    return tuple(lines), notes


def expected(plain: bool, plan_files: list, result_names: list, received_names: list) -> list:
    """자취로 볼 때 있어야 하는 사람 줄(J24) — [(종류, 계획 | None, 자취 글), …]. 차례는 spec 승인 · 계획 검토(계획 번호 차례).

    받음 줄은 그 결과 파일과 같이 단계로 가른다 — 관문 표(§3)로 볼 때 그 결과가 지나야 했던 관문만 있어야 한다.
    """
    named = [(_HAD % n, team_layout.parse_result_name(n)) for n in sorted(result_names)] \
        + [(_GOT % n, team_layout.parse_result_name(n)) for n in received_names]
    traces = [(text, r) for text, r in named if r is not None]
    if plain:
        return [(KIND_FLOW, None, traces[0][0])] if traces else []
    out = []
    spec = [_HAD % n for n in sorted(plan_files)] + [text for text, r in traces if r[0] in team_layout.PLANNED_STAGES]
    if spec:
        out.append((KIND_SPEC, None, spec[0]))
    built = team_layout.PLANNED_STAGES[1:]
    for n in sorted({r[1] for _, r in traces if r[0] in built and r[1] is not None}):
        out.append((KIND_PLAN, n, next(text for text, r in traces if r[0] in built and r[1] == n)))
    return out
