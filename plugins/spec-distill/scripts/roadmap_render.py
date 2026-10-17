#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_render.py — 분해안 표 · 로드맵 블록 · 에픽 묶음 · 로드맵의 글을 만든다. 파일을 쓰지 않는다.

`roadmap_write.py` 가 부른다. 형식의 정본은 R0 설계 §3(`docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md`)
이고, 로드맵 해석 · 번호 문법 · 절 읽기는 `roadmap_model.py`, §6 경계는 `section6.py` 의 것을 쓴다.
"""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import section6  # noqa: E402
from check_brief import section4_items  # noqa: E402
from check_verbatim_coverage import ITEM_RE as S6_ITEM_RE  # noqa: E402
from roadmap_model import (  # noqa: E402
    BLOCK_ID_RE, EXTRA_FIELDS, KEY_RE, OQ_LINE_RE, FormatError, brief_universe, bundle_ids, field_text,
    id_sort_key, is_quote, parse_ids, parse_roadmap, section_body)

TABLE_HEADING = "## 분해안"
COLUMNS = ("번호", "이름", "종류", "의도", "범위", "의존", "브랜치", "경로 예약", "배정 번호", "받는 것", "넘기는 것")
EXTRA_COLUMNS = EXTRA_FIELDS
SCOPE_RE = re.compile(r"한다 (\S.*?) / 안 한다 (\S.*)")
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
    extras: dict = field(default_factory=dict)   # 선택 칸 — 크기 · 병렬 · 순서 이유 · 근거 · 흐름 · 산출물

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
    rid, title, kind_cell, intent, scope, deps, branch, reserved, ids_cell, recv, give = c[:len(COLUMNS)]
    extras = dict((k, v) for k, v in zip(EXTRA_COLUMNS, c[len(COLUMNS):]) if v != "없음")
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
    return Row(rid, title, kind, spec, intent, scope, deps, branch, reserved, ids, recv, give, extras)


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
    head = _split_row(lines[0])
    if head == list(COLUMNS):
        width = len(COLUMNS)
    elif head == list(COLUMNS + EXTRA_COLUMNS):
        width = len(COLUMNS) + len(EXTRA_COLUMNS)
    else:
        raise TableError("분해안 표 머리가 칸 열하나(%s) 또는 그 뒤에 선택 칸 여섯(%s)을 더한 열일곱이 아니다"
                         % (" · ".join(COLUMNS), " · ".join(EXTRA_COLUMNS)))
    sep = _split_row(lines[1])
    if len(sep) != width or not all(c.count("-") >= 3 and set(c) <= set("-:") for c in sep):
        raise TableError("분해안 표 구분 행의 칸 수가 머리와 다르다")
    rows, seen = [], set()
    for line in lines[2:]:
        cells = _split_row(line)
        if len(cells) != width:
            raise TableError("분해안 표 행의 칸 수가 머리와 다르다: %r" % line)
        row = _row(cells, line)
        if row.id in seen:
            raise TableError("에픽 번호 %s 가 두 번 있다" % row.id)
        seen.add(row.id)
        rows.append(row)
    return rows


def format_table(rows: list) -> str:
    wide = any(r.extras for r in rows)
    cols = COLUMNS + (EXTRA_COLUMNS if wide else ())
    out = [TABLE_HEADING, "", "| " + " | ".join(cols) + " |", "|" + "---|" * len(cols)]
    for r in rows:
        cells = [r.id, r.title, r.kind_cell(), r.intent, r.scope, r.deps, r.branch, r.reserved,
                 " · ".join(r.ids), r.receives, r.gives]
        if wide:
            cells += [r.extras.get(k, "없음") for k in EXTRA_COLUMNS]
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

        def t(key, f=f):
            return field_text(f[key])
        extras = dict((k, v) for k in EXTRA_COLUMNS if k in f for v in [field_text(f[k])] if v != "없음")
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
            rows.append(Row(b["id"], b["title"], KIND_BUNDLE, "", t("의도"), scope_text(f["범위"]), t("의존"),
                            t("브랜치"), t("경로 예약"), ids, got["받는 것"], got["넘기는 것"], extras))
            continue
        try:
            ids = parse_ids(f["발화"]) + parse_ids(f["항목"])
        except FormatError as exc:
            raise TableError("%s: %s" % (b["id"], exc))
        kind = KIND_BRANCH if b["kind"] == "branch" else KIND_DECISION
        rows.append(Row(b["id"], b["title"], kind, f.get("spec", ""), t("의도"), scope_text(f["범위"]), t("의존"),
                        t("브랜치") if "브랜치" in f else "없음", t("경로 예약"), extras=extras, ids=ids))
    return rows


# ── brief 색인 ───────────────────────────────────────────────────────────────

@dataclass
class BriefIndex:
    lines: dict      # 번호 → brief 줄(§2 C · D · §0 OQ · §4 «key» · §5 RC · ST)
    k_lines: dict    # K<n> → "- K<n> — <brief §5 위험 줄 원문>"
    goal: str        # brief §1 본문
    s6: str          # brief §6 본문 + 빈 줄 + audit §6 중 brief §6 에 없는 S<n> 항목


def _body(text: str, heading: str) -> str:
    body = section_body(text, heading)
    if body is None:
        raise FormatError("brief 에 %s 절이 없다" % heading)
    return body


def _s6_ids(body: str) -> set:
    return {m.group(1) for m in map(S6_ITEM_RE.match, body.splitlines()) if m}


def _merge_s6(b6: str, a6: str) -> str:
    """payload §6 을 먼저 싣고, audit §6 항목(앵커 줄부터 다음 앵커 줄 앞까지)은 그 S<n> 이 payload §6 에 없는
    것만 더한다 — payload §6 이 S1~Sn 전량인 brief 에서 audit 의 같은 글 사본을 두 번 싣지 않는다. 겹치는
    앵커가 없으면(payload §6 = S1 인 brief) 두 본문을 그대로 잇는다."""
    have = _s6_ids(b6)
    head, entries, cur = [], [], None
    for line in a6.splitlines(keepends=True):
        m = S6_ITEM_RE.match(line.rstrip("\r\n"))
        if m:
            cur = (m.group(1), [line])
            entries.append(cur)
        elif cur is None:
            head.append(line)
        else:
            cur[1].append(line)
    kept = [e for e in entries if e[0] not in have]
    if len(kept) == len(entries):
        return b6.rstrip("\n") + "\n\n" + a6
    extra = "".join(head) + "".join("".join(lines) for _sid, lines in kept) if kept else ""
    return b6.rstrip("\n") + "\n\n" + extra


def _section4_index(brief: str) -> dict:
    """§4 «key» → 그 key 가 머리 줄에 있는 항목(머리 줄 + 들여쓴 본문 줄). 항목 규칙은 게이트의
    `check_brief.section4_items` 하나다. 본문 줄에만 있는 key 는 그 항목으로, 항목 밖 줄의 key 는 그 줄로 간다."""
    out = {}
    items = [(head, "\n".join([head] + ["  " + b for b in body]), body) for head, body in section4_items(brief)]
    for head, text, _body_lines in items:
        for key in KEY_RE.findall(head):
            out[key] = text
    for _head, text, body in items:
        for key in KEY_RE.findall("\n".join(body)):
            out.setdefault(key, text)
    for line in _body(brief, "## 4.").splitlines():
        for key in KEY_RE.findall(line):
            out.setdefault(key, line)
    return out


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
    lines.update(_section4_index(brief))
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
                      _body(brief, "## 1."), _merge_s6(b6, a6))


# ── 블록 · 묶음 · 로드맵 ─────────────────────────────────────────────────────

def scope_lines(scope: str) -> list:
    """표 칸 「한다 X / 안 한다 Y」 → `- 범위:` 와 하위 항목 둘. 그 꼴이 아니면 한 줄 그대로."""
    m = SCOPE_RE.fullmatch(scope)
    if not m:
        return ["- 범위: " + scope]
    return ["- 범위:", "  - 한다: " + m.group(1), "  - 안 한다: " + m.group(2)]


def scope_text(value) -> str:
    """로드맵 범위 칸 → 표 칸. 하위 항목은 「한다: …」 · 「안 한다: …」 만이고 둘 다 있어야 한다."""
    if isinstance(value, str):
        return value
    do = [i[len("한다: "):] for i in value if i.startswith("한다: ")]
    dont = [i[len("안 한다: "):] for i in value if i.startswith("안 한다: ")]
    if len(do) + len(dont) != len(value) or not do or not dont:
        raise TableError("범위 하위 항목은 「한다: …」 · 「안 한다: …」 뿐이고 둘 다 있어야 한다: %r" % value)
    return "한다 %s / 안 한다 %s" % (" · ".join(do), " · ".join(dont))


def render_block(r: Row) -> str:
    lines = ["### %s — %s" % (r.id, r.title), "- 의도: " + r.intent] + scope_lines(r.scope) + [
        "- 의존: " + r.deps,
        "- 완료: 결정 기록" if r.kind == KIND_DECISION else "- 브랜치: " + r.branch,
        "- 묶음: " + (r.id + ".md" if r.kind == KIND_BUNDLE else "없음"),
        "- 경로 예약: " + r.reserved]
    if r.kind == KIND_BRANCH:
        lines.append("- spec: " + r.spec)
    if r.kind != KIND_BUNDLE:
        lines.append("- 발화: " + " · ".join(t for t in r.ids if _is_s(t)))
        lines.append("- 항목: " + " · ".join(t for t in r.ids if not _is_s(t)))
    lines += ["- %s: %s" % (k, r.extras[k]) for k in EXTRA_COLUMNS if k in r.extras]
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


def history_entry(date: str, reason: str, changes: list, quotes: list) -> str:
    """새 재분해 이력 항목 하나 — `### <날짜> · <사유>` · `- 바뀜:` · `- 원문:` + 줄마다 「…」."""
    for q in quotes:
        if len(q.splitlines()) != 1 or not is_quote("「%s」" % q):
            raise TableError("원문은 한 줄이고 「 」 가 짝이 맞아야 한다: %r" % q)
    if not quotes:
        raise TableError("재분해 이력에 원문이 없다")
    if len(reason.splitlines()) != 1 or not reason.strip():
        raise TableError("재분해 이력 사유는 한 줄이다: %r" % reason)
    out = ["### %s · %s" % (date, reason.strip())]
    if changes:
        out.append("- 바뀜: " + " · ".join(changes))
    out.append("- 원문:")
    out += ["  - 「%s」" % q for q in quotes]
    return "\n".join(out) + "\n"


def append_history(roadmap_text: str, entry: str) -> str:
    lines = roadmap_text.splitlines(keepends=True)
    start, end = _span(lines, "## 재분해 이력")
    body = "".join(lines[start + 1:end]).rstrip("\n")
    tail = "".join(lines[end:])
    sep = "\n\n" if entry.startswith("### ") else "\n"
    return ("".join(lines[:start + 1]) + body + sep + entry.rstrip("\n") + "\n"
            + ("\n" + tail if tail else ""))