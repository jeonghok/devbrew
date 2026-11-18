#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""human_lines.py — 사람 줄(spec 승인 · 계획 검토 · 흐름 승인 · 걸음 건너뜀)의 꼴 · 통과 라벨 표 · 관문 이름 · 본문 · 판과 꼴 판정이 사는 한 곳.

읽기만 한다 — 파일을 쓰지 않고 세션 기록을 읽지 않는다. git 은 부르는 쪽이 넘긴 객체(`roadmap_status.Git`)로만 읽는다.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import NamedTuple, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
import section6  # noqa: E402
import team_files  # noqa: E402
import team_layout  # noqa: E402

KIND_SPEC, KIND_PLAN, KIND_FLOW, KIND_SKIP = "spec 승인", "계획 검토", "흐름 승인", "걸음 건너뜀"
KINDS = (KIND_SPEC, KIND_PLAN, KIND_FLOW, KIND_SKIP)
SKIP_LABEL, RETRY_LABEL = "건너뛴다", "다시 시도한다"
PASS_LABELS = {KIND_SPEC: ("승인 — 계획 담당자에게",), KIND_PLAN: ("계획대로 구현한다",),
               KIND_FLOW: ("설계 없이 진행",), KIND_SKIP: (SKIP_LABEL, RETRY_LABEL)}
RECOMMENDED = "(권장)"

PASS, NO_EVIDENCE, MISMATCH, UNCHECKED, STALE = "지남", "근거 없음", "어긋남", "확인 못 함", "낡음"

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


def _heading_level(line: str) -> int:
    if line.startswith("### "):
        return 3
    if line.startswith("## "):
        return 2
    if line.startswith("# "):
        return 1
    return 0


def _is_head(line: str, title: str) -> bool:
    return line == title or line.startswith(title + " ")


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
