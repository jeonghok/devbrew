#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_render.py — 분해안 표 · 로드맵 블록 · 에픽 묶음 · 로드맵의 글을 만든다. 파일을 쓰지 않는다.

`roadmap_write.py` 가 부른다. 형식의 정본은 R0 설계 §3(`docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md`)
이고, 로드맵 해석 · 번호 문법 · 절 읽기 · §6 경계는 `roadmap_status.py` · `check_bundle_coverage.py` · `section6.py` 의 것을 쓴다.
"""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import section6  # noqa: E402
from check_bundle_coverage import (  # noqa: E402
    FormatError, bundle_ids, id_sort_key, parse_ids, section_body)
from roadmap_status import (  # noqa: E402
    BLOCK_ID_RE, KEY_RE, OQ_LINE_RE, brief_universe, parse_roadmap)

TABLE_HEADING = "## 분해안"
COLUMNS = ("번호", "이름", "종류", "의도", "범위", "의존", "브랜치", "경로 예약", "배정 번호", "받는 것", "넘기는 것")
KIND_BUNDLE, KIND_BRANCH, KIND_DECISION = "bundle", "branch", "decision"
TEMPLATE = Path(__file__).resolve().parent.parent / "templates" / "roadmap-template.md"
C_LINE_RE = re.compile(r"- \S+ (?:confirmed|provisional) \*\*([CD]\d+)\*\* — ")
RC_LINE_RE = re.compile(r"(RC\d+) \(")
ST_LINE_RE = re.compile(r" — (ST\d+) — ")
PLACEHOLDER_RE = re.compile(r"\{\{([A-Z_]+)\}\}")


class TableError(ValueError):
    """분해안 표 · 묶음을 만들 수 없다 — 사유를 그대로 사용자에게 보인다."""


@dataclass
class Row:
    id: str
    title: str
    kind: str          # bundle · branch · decision
    spec: str          # branch 일 때 설계문서 경로, 아니면 ""
    intent: str
    scope: str
    deps: str          # 로드맵 `의존:` 값 그대로
    branch: str        # decision 이면 "없음"
    reserved: str      # 로드맵 `경로 예약:` 값 그대로
    ids: list = field(default_factory=list)   # 칸에 적힌 순서 그대로
    receives: str = "없음"
    gives: str = "없음"

    def kind_cell(self) -> str:
        if self.kind == KIND_BUNDLE:
            return "묶음"
        if self.kind == KIND_DECISION:
            return "결정"
        return "브랜치 " + self.spec


def _is_s(token: str) -> bool:
    return token.startswith("S") and token[1:].isdigit()


# ── 분해안 표 ────────────────────────────────────────────────────────────────

def _split_row(line: str) -> list:
    line = line.strip()
    if not (line.startswith("|") and line.endswith("|")):
        raise TableError("표 행이 | 로 시작하고 끝나지 않는다: %r" % line)
    body, cells, cur, i = line[1:-1], [], [], 0
    while i < len(body):
        if body[i] == "\\" and body[i + 1:i + 2] == "|":
            cur.append("|")
            i += 2
            continue
        if body[i] == "|":
            cells.append("".join(cur).strip())
            cur = []
        else:
            cur.append(body[i])
        i += 1
    cells.append("".join(cur).strip())
    return cells


def _row(c: list, line: str) -> Row:
    rid, title, kind_cell, intent, scope, deps, branch, reserved, ids_cell, recv, give = c
    if any(not v for v in c):
        raise TableError("빈 칸이 있다 — 없으면 「없음」이라 쓴다: %r" % line)
    if not BLOCK_ID_RE.fullmatch(rid):
        raise TableError("에픽 번호 %r 가 `<대문자><숫자>[소문자]` 가 아니다" % rid)
    if kind_cell == "묶음":
        kind, spec = KIND_BUNDLE, ""
    elif kind_cell == "결정":
        kind, spec = KIND_DECISION, ""
    elif kind_cell.startswith("브랜치 ") and kind_cell[len("브랜치 "):].strip():
        kind, spec = KIND_BRANCH, kind_cell[len("브랜치 "):].strip()
    else:
        raise TableError("%s: 종류는 「묶음」 · 「브랜치 <설계문서 경로>」 · 「결정」 중 하나다: %r" % (rid, kind_cell))
    if (kind == KIND_DECISION) != (branch == "없음"):
        raise TableError("%s: 브랜치 칸은 결정 블록만 「없음」이다" % rid)
    try:
        ids = parse_ids(ids_cell)
    except FormatError as exc:
        raise TableError("%s: 배정 번호 — %s" % (rid, exc))
    if kind != KIND_BUNDLE:
        n_s = sum(1 for t in ids if _is_s(t))
        if n_s == 0 or n_s == len(ids):
            raise TableError("%s: 묶음 없는 블록은 발화(S) 번호와 그 밖의 번호가 하나 이상씩 있어야 한다" % rid)
    return Row(rid, title, kind, spec, intent, scope, deps, branch, reserved, ids, recv, give)


def parse_table(text: str) -> list:
    try:
        body = section_body(text, TABLE_HEADING)
    except FormatError as exc:
        raise TableError(str(exc))
    if body is None:
        raise TableError("`%s` 절이 없다" % TABLE_HEADING)
    lines = [l for l in body.splitlines() if l.strip().startswith("|")]
    if len(lines) < 3:
        raise TableError("분해안 표가 없거나 에픽 행이 없다")
    if _split_row(lines[0]) != list(COLUMNS):
        raise TableError("분해안 표 머리가 칸 열하나(%s)가 아니다" % " · ".join(COLUMNS))
    sep = _split_row(lines[1])
    if len(sep) != len(COLUMNS) or not all(c.count("-") >= 3 and set(c) <= set("-:") for c in sep):
        raise TableError("분해안 표 구분 행이 칸 열하나가 아니다")
    rows, seen = [], set()
    for line in lines[2:]:
        cells = _split_row(line)
        if len(cells) != len(COLUMNS):
            raise TableError("분해안 표 행이 칸 열하나가 아니다: %r" % line)
        row = _row(cells, line)
        if row.id in seen:
            raise TableError("에픽 번호 %s 가 두 번 있다" % row.id)
        seen.add(row.id)
        rows.append(row)
    return rows


def format_table(rows: list) -> str:
    out = [TABLE_HEADING, "", "| " + " | ".join(COLUMNS) + " |", "|" + "---|" * len(COLUMNS)]
    for r in rows:
        cells = (r.id, r.title, r.kind_cell(), r.intent, r.scope, r.deps, r.branch, r.reserved,
                 " · ".join(r.ids), r.receives, r.gives)
        out.append("| " + " | ".join(c.replace("|", "\\|") for c in cells) + " |")
    return "\n".join(out) + "\n"


def extract_rows(roadmap_text: str, read_bundle) -> list:
    """로드맵 블록과 묶음(frontmatter ids · §7)에서 분해안 표를 거꾸로 뽑는다."""
    _meta, blocks, _records, _risks, errors = parse_roadmap(roadmap_text)
    if errors:
        raise TableError("로드맵 형식 깨짐 — " + " · ".join(errors))
    rows = []
    for b in blocks:
        f = b["fields"]
        if b["kind"] == "bundle":
            if f["묶음"] != b["id"] + ".md":
                raise TableError("%s: 묶음 이름이 `%s.md` 가 아니다" % (b["id"], b["id"]))
            text = read_bundle(f["묶음"])
            if text is None:
                raise TableError("%s 묶음을 읽지 못했다: %s" % (b["id"], f["묶음"]))
            try:
                ids = bundle_ids(text)
                s7 = section_body(text, "## 7.") or ""
            except FormatError as exc:
                raise TableError("%s 묶음 — %s" % (b["id"], exc))
            got = {}
            for line in s7.splitlines():
                for key in ("받는 것", "넘기는 것"):
                    if line.startswith("- %s: " % key):
                        got[key] = line[len("- %s: " % key):]
            if len(got) != 2:
                raise TableError("%s 묶음 §7 에 받는 것 · 넘기는 것 줄이 없다" % b["id"])
            rows.append(Row(b["id"], b["title"], KIND_BUNDLE, "", f["의도"], f["범위"], f["의존"],
                            f["브랜치"], f["경로 예약"], ids, got["받는 것"], got["넘기는 것"]))
            continue
        try:
            ids = parse_ids(f["발화"]) + parse_ids(f["항목"])
        except FormatError as exc:
            raise TableError("%s: %s" % (b["id"], exc))
        kind = KIND_BRANCH if b["kind"] == "branch" else KIND_DECISION
        rows.append(Row(b["id"], b["title"], kind, f.get("spec", ""), f["의도"], f["범위"], f["의존"],
                        f.get("브랜치", "없음"), f["경로 예약"], ids))
    return rows


# ── brief 색인 ───────────────────────────────────────────────────────────────

@dataclass
class BriefIndex:
    lines: dict      # 번호 → brief 줄(§2 C · D · §0 OQ · §4 «key» · §5 RC · ST)
    k_lines: dict    # K<n> → "- K<n> — <brief §5 위험 줄 원문>"
    goal: str        # brief §1 본문
    s6: str          # brief §6 본문 + 빈 줄 + audit §6 본문


def _body(text: str, heading: str) -> str:
    body = section_body(text, heading)
    if body is None:
        raise FormatError("brief 에 %s 절이 없다" % heading)
    return body


def index_brief(brief: str, audit: str) -> BriefIndex:
    _non_s, _s_ids, k_expected = brief_universe(brief, audit)
    lines = {}
    for line in _body(brief, "## 2.").splitlines():
        m = C_LINE_RE.match(line)
        if m:
            lines[m.group(1)] = line
    for line in _body(brief, "## 0.").splitlines():
        m = OQ_LINE_RE.match(line)
        if m:
            lines[m.group(1)] = line
    for line in _body(brief, "## 4.").splitlines():
        for key in KEY_RE.findall(line):
            lines[key] = line
    for line in _body(brief, "## 5.").splitlines():
        m = RC_LINE_RE.search(line)
        if m:
            lines[m.group(1)] = line
        m = ST_LINE_RE.search(line)
        if m:
            lines[m.group(1)] = line
    b6, a6 = section6.body(brief), section6.body(audit)
    if b6 is None or a6 is None:
        raise FormatError("brief 또는 audit 의 §6 을 하나로 읽을 수 없다")
    return BriefIndex(lines, {k: "- %s — %s" % (k, text) for k, text in k_expected},
                      _body(brief, "## 1."), b6.rstrip("\n") + "\n\n" + a6)


# ── 블록 · 묶음 · 로드맵 ─────────────────────────────────────────────────────

def render_block(r: Row) -> str:
    lines = ["### %s — %s" % (r.id, r.title), "- 의도: " + r.intent, "- 범위: " + r.scope,
             "- 의존: " + r.deps,
             "- 완료: 결정 기록" if r.kind == KIND_DECISION else "- 브랜치: " + r.branch,
             "- 묶음: " + (r.id + ".md" if r.kind == KIND_BUNDLE else "없음"),
             "- 경로 예약: " + r.reserved]
    if r.kind == KIND_BRANCH:
        lines.append("- spec: " + r.spec)
    if r.kind != KIND_BUNDLE:
        lines.append("- 발화: " + " · ".join(t for t in r.ids if _is_s(t)))
        lines.append("- 항목: " + " · ".join(t for t in r.ids if not _is_s(t)))
    return "\n".join(lines) + "\n"


BUNDLE_FORMAT = (
    "---\ntype: epic-bundle\nepic: %s\nroadmap: %s\nsource_brief: %s\nids: [%s]\n---\n\n"
    "# %s — %s · 에픽 묶음\n\n"
    "## 0. 역참조\n\n"
    "- 원본 brief: `%s` (audit `%s`)\n"
    "- 로드맵: `%s` 의 `### %s` 블록\n"
    "- 이 에픽의 설계문서는 frontmatter `source_interview:` 에 이 묶음 경로를, `roadmap:` 에 로드맵 경로를 적고, "
    "본문 `## 번호 대조` 표(칸: 번호 · 반영/기각 · 자리 또는 이유)에 위 `ids` 전부를 싣는다.\n\n"
    "## 1. Goal · Non-goal\n\n### 이 에픽의 Goal · Non-goal\n\n- 의도: %s\n- 범위: %s\n\n### 공통 목표\n%s"
    "## 2. 제약\n\n%s\n\n"
    "## 3. 열린 질문\n\n%s\n\n"
    "## 4. 웹 근거\n\n%s\n\n"
    "## 5. 기각 · 위험\n\n%s\n\n"
    "## 6. 사용자 원문\n%s"
    "## 7. 인터페이스\n\n- 받는 것: %s\n- 넘기는 것: %s\n")


def render_bundle(r: Row, idx: BriefIndex, roadmap_rel: str, brief_rel: str, audit_rel: str) -> str:
    ids = sorted(set(r.ids), key=id_sort_key)
    missing = [t for t in ids if not _is_s(t) and t not in idx.lines and t not in idx.k_lines]
    if missing:
        raise TableError("%s: brief 에서 줄을 찾지 못한 번호 — %s" % (r.id, " · ".join(missing)))

    def pick(prefix_ok):
        return [idx.lines[t] for t in ids if prefix_ok(t)]

    keys = []
    for t in ids:
        if t.startswith("«") and idx.lines[t] not in keys:
            keys.append(idx.lines[t])
    c_d = pick(lambda t: t[:1] in ("C", "D") and t[1:].isdigit())
    oq = pick(lambda t: t.startswith("OQ"))
    rest = (pick(lambda t: t.startswith("RC")) + pick(lambda t: t.startswith("ST"))
            + [idx.k_lines[t] for t in ids if t.startswith("K")])
    return BUNDLE_FORMAT % (
        r.id, roadmap_rel, brief_rel, ", ".join(ids), r.id, r.title, brief_rel, audit_rel, roadmap_rel, r.id,
        r.intent, r.scope, idx.goal,
        "\n".join(c_d) or "- 없음", "\n".join(oq) or "- 없음", "\n".join(keys) or "- 없음",
        "\n".join(rest) or "- 없음", idx.s6, r.receives, r.gives)


def render_roadmap(template: str, rows: list, idx: BriefIndex, title: str, brief_rel: str,
                   roadmap_rel: str, history: str) -> str:
    values = {"TITLE": title, "SOURCE_BRIEF": brief_rel, "ROADMAP": roadmap_rel,
              "EPICS": "\n".join(render_block(r) for r in rows), "HISTORY": history,
              "RISKS": "\n".join(idx.k_lines.values()) or "- 없음"}

    def sub(m):
        if m.group(1) not in values:
            raise TableError("로드맵 틀에 모르는 자리표 %s" % m.group(0))
        return values[m.group(1)]
    return PLACEHOLDER_RE.sub(sub, template)


# ── 로드맵 고쳐 쓰기(update) ─────────────────────────────────────────────────

def _span(lines: list, heading: str):
    start = next((i for i, l in enumerate(lines) if l.rstrip("\r\n") == heading), None)
    if start is None:
        raise TableError("로드맵에 `%s` 절이 없다" % heading)
    end = next((j for j in range(start + 1, len(lines)) if lines[j].startswith("## ")), len(lines))
    return start, end


def epic_block_texts(roadmap_text: str) -> dict:
    lines = roadmap_text.splitlines(keepends=True)
    start, end = _span(lines, "## 에픽")
    out, cur, buf = {}, None, []
    for line in lines[start + 1:end] + ["### \n"]:
        if line.startswith("### "):
            if cur is not None:
                out[cur] = "".join(buf).rstrip("\n") + "\n"
            cur, buf = line[4:].split(" — ", 1)[0].strip(), [line]
        elif cur is not None:
            buf.append(line)
    return out


def replace_epics(roadmap_text: str, blocks: list) -> str:
    lines = roadmap_text.splitlines(keepends=True)
    start, end = _span(lines, "## 에픽")
    return "".join(lines[:start + 1]) + "\n" + "\n".join(blocks) + "\n" + "".join(lines[end:])


def append_history(roadmap_text: str, line: str) -> str:
    lines = roadmap_text.splitlines(keepends=True)
    start, end = _span(lines, "## 재분해 이력")
    body = "".join(lines[start + 1:end]).rstrip("\n")
    tail = "".join(lines[end:])
    return "".join(lines[:start + 1]) + body + "\n" + line + "\n" + ("\n" + tail if tail else "")
