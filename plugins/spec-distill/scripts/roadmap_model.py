#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_model.py — 번호 문법 · 로드맵 해석 · 블록별 배정 번호 · brief 번호 집합.

`check_bundle_coverage.py` 와 `roadmap_status.py` 가 함께 쓴다. 이 모듈은 둘 중 어느 것도 import 하지
않는다(순환 없음). 읽기만 한다 — 파일을 쓰지 않고 git · 네트워크를 부르지 않는다.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import section6  # noqa: E402

# 번호 한 개 — 확정 C/D · 열린 질문 OQ · 레포 근거 RC · 위험 K · steelman ST · 발화 S, 또는 «key».
TOKEN_RE = re.compile(r"(?:C|D|OQ|RC|K|ST|S)\d+|«[^«»,·\s]+»")
# 번호 여럿의 구분 — 쉼표 또는 ` · `. 범위 표기(`K1~K7`)는 토큰 문법에 맞지 않아 깨짐으로 친다.
SEP_RE = re.compile(r"\s*,\s*|\s+·\s+")
SEP_CELL_RE = re.compile(r":?-{3,}:?")
PREFIX_ORDER = ("C", "D", "OQ", "RC", "K", "ST", "S")


IMPL_PREFIX = "## 구현 대조 — "


class FormatError(ValueError):
    """검사할 수 없는 입력 — 종료 코드 3."""


def parse_ids(cell: str) -> list:
    """번호 칸 하나를 토큰 목록으로. 문법에 맞지 않는 토큰이 하나라도 있으면 FormatError."""
    cell = cell.strip()
    if not cell:
        raise FormatError("빈 번호 칸")
    out = []
    for piece in SEP_RE.split(cell):
        if not TOKEN_RE.fullmatch(piece):
            raise FormatError("번호 문법에 맞지 않는 토큰: %r" % piece)
        out.append(piece)
    return out


def id_sort_key(token: str):
    if token.startswith("«"):
        return (len(PREFIX_ORDER), 0, token)
    for i, p in enumerate(PREFIX_ORDER):
        rest = token[len(p):]
        if token.startswith(p) and rest.isdigit():
            return (i, int(rest), token)
    return (len(PREFIX_ORDER) + 1, 0, token)


def frontmatter(text: str) -> dict:
    """맨 앞 `---` 블록의 최상위 `키: 값` 줄. 들여쓴 줄 · 목록 줄은 건너뛴다. 없거나 안 닫혔으면 {}."""
    lines = text.split("\n")
    if not lines or lines[0].rstrip("\r") != "---":
        return {}
    out = {}
    for line in lines[1:]:
        line = line.rstrip("\r")
        if line == "---":
            return out
        if not line or line[0] in " \t-#" or ":" not in line:
            continue
        key, value = line.split(":", 1)
        out.setdefault(key.strip(), value.strip())
    return {}


def unquote(value: str) -> str:
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def _heading_indexes(lines):
    """펜스 밖의 `## ` 줄 번호들. `### ` 는 `## ` 로 시작하지 않으므로 들지 않는다."""
    in_fence = False
    for i, line in enumerate(lines):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if not in_fence and line.startswith("## "):
            yield i


def section_body(text: str, heading: str):
    """`heading` 과 같거나 `heading + " "` 로 시작하는 `## ` 줄 다음부터 다음 `## ` 줄 앞까지.

    없으면 None, 둘 이상이면 FormatError. §6 은 이 함수로 읽지 않는다 — `section6.body` 한 곳이다.
    """
    if heading.startswith("## 6."):
        raise ValueError("§6 은 section6.body 로만 읽는다")
    lines = text.splitlines(keepends=True)
    heads = list(_heading_indexes(lines))
    hits = [i for i in heads
            if lines[i].rstrip("\r\n") == heading or lines[i].startswith(heading + " ")]
    if not hits:
        return None
    if len(hits) > 1:
        raise FormatError("%s 절이 %d개다" % (heading, len(hits)))
    start = hits[0]
    later = [j for j in heads if j > start]
    end = later[0] if later else len(lines)
    return "".join(lines[start + 1:end])


def bundle_ids(text: str) -> list:
    raw = frontmatter(text).get("ids")
    if raw is None:
        raise FormatError("묶음 frontmatter 에 ids 가 없다")
    if not (raw.startswith("[") and raw.endswith("]")):
        raise FormatError("ids 는 한 줄 목록([…])이어야 한다")
    if not raw[1:-1].strip():
        raise FormatError("ids 가 비었다")
    return parse_ids(raw[1:-1])

EXTRA_FIELDS = ("크기", "병렬", "순서 이유", "근거", "흐름", "산출물")
FIELDS = ("의도", "범위", "의존", "브랜치", "묶음", "경로 예약", "spec", "발화", "항목", "완료") + EXTRA_FIELDS
ONE_LINE = ("묶음", "spec", "완료", "발화", "항목")   # 하위 항목을 두지 않는 칸
SUB_ITEM = "  - "
HISTORY_HEADING = "## 재분해 이력"
HISTORY_HEAD_RE = re.compile(r"### (\d{4}-\d{2}-\d{2}) · (\S.*)")
OLD_HISTORY_RE = re.compile(r"- (\d{4}-\d{2}-\d{2}) · (\S.*)")
REQUIRED = {
    "bundle": ("의도", "범위", "의존", "브랜치", "묶음", "경로 예약"),
    "branch": ("의도", "범위", "의존", "브랜치", "묶음", "경로 예약", "spec", "발화", "항목"),
    "decision": ("의도", "범위", "의존", "완료", "묶음", "경로 예약", "발화", "항목"),
}
FORBIDDEN = {"bundle": ("spec", "발화", "항목", "완료"), "branch": ("완료",),
             "decision": ("브랜치", "spec")}
RISK_PREFIXES = ("- 위험 — 숨은 가정", "- 위험 — 실패 양식", "- 위험 — 리뷰 참고")
BLOCK_HEAD_RE = re.compile(r"### ([A-Z][0-9]+[a-z]?) — (\S.*)")
BLOCK_ID_RE = re.compile(r"[A-Z][0-9]+[a-z]?")
BUNDLE_NAME_RE = re.compile(r"[A-Za-z0-9_-]+\.md")
RISK_ROW_RE = re.compile(r"- (K\d+) — (\S.*)")
DATE_RE = re.compile(r"\d{4}-\d{2}-\d{2}")
ID_ITEM_RE = re.compile(r"\s+- id: ([CD]\d+)\s*")
OQ_LINE_RE = re.compile(r"- (OQ\d+) ")
RC_RE = re.compile(r"\bRC\d+\b")
ST_RE = re.compile(r"\bST\d+\b")
KEY_RE = re.compile(r"«[^«»]+»")
S_ANCHOR_RE = re.compile(r"\*\*(S\d+)\*\*")
LIST_SEP_RE = re.compile(r"\s*,\s*|\s+·\s+")


def split_list(value: str) -> list:
    value = value.strip()
    if value == "없음":
        return []
    return [p.strip().strip("`") for p in LIST_SEP_RE.split(value) if p.strip()]


def field_list(value) -> list:
    """칸 값을 목록으로 — 하위 항목이면 항목마다(백틱 뗌), 한 줄이면 쉼표 · ` · ` 로 나눈다. 「없음」은 빈 목록."""
    if isinstance(value, list):
        items = [v.strip().strip("`") for v in value]
        return [] if items == ["없음"] else [v for v in items if v]
    return split_list(value)


def field_text(value) -> str:
    """칸 값을 한 줄 글로 — 하위 항목은 ` · ` 로 잇는다."""
    return " · ".join(value) if isinstance(value, list) else value


def quotes(text: str) -> list:
    """「…」 인용들. 안에 「…」 가 겹쳐 있으면 바깥 인용 하나로 센다. 닫히지 않은 「 는 세지 않는다."""
    out, depth, start = [], 0, 0
    for i, ch in enumerate(text):
        if ch == "「":
            if depth == 0:
                start = i
            depth += 1
        elif ch == "」" and depth:
            depth -= 1
            if depth == 0:
                out.append(text[start:i + 1])
    return out


def is_quote(text: str) -> bool:
    return quotes(text) == [text]


def strip_quotes(text: str) -> str:
    for q in quotes(text):
        head, _sep, tail = text.partition(q)   # 첫 하나만 바꾼다 — 쓰기 호출 이름(replace)을 피한다
        text = head + " " + tail
    return text


def _field_line(text: str):
    """`<칸>: <값>` → (칸, 값 글). `<칸>:` → (칸, []) — 하위 항목을 받는다. 모르는 칸이면 (None, None)."""
    if text.endswith(":") and text[:-1] in FIELDS:
        return text[:-1], []
    key, sep, value = text.partition(": ")
    if not sep or key not in FIELDS:
        return None, None
    return key, value.strip()


def parse_history(text: str):
    """`## 재분해 이력` → (항목들, 오류들). 항목 {"date","reason","changes","quotes","form"}.

    새 꼴: `### <날짜> · <사유>` 아래 `- 바뀜: …`(또는 `- 바뀜:` + 하위 항목)과 `- 원문:` + 하위 항목(줄마다 「…」 하나).
    옛 꼴 `- <날짜> · …` 한 줄도 읽는다(인용은 줄 안의 「…」 전부). 새 항목 밖의 다른 줄은 전처럼 읽지 않는다.
    """
    try:
        body = section_body(text, HISTORY_HEADING)
    except FormatError as exc:
        return [], [str(exc)]
    entries, errors, cur, key = [], [], None, None
    for line in (body or "").splitlines():
        if not line.strip():
            continue
        old = OLD_HISTORY_RE.fullmatch(line.rstrip())
        if line.startswith("### "):
            m = HISTORY_HEAD_RE.fullmatch(line.rstrip())
            cur, key = None, None
            if not m:
                errors.append("재분해 이력 머리가 `### <YYYY-MM-DD> · <사유>` 가 아니다: %r" % line)
                continue
            cur = {"date": m.group(1), "reason": m.group(2), "changes": [], "quotes": [], "form": "new"}
            entries.append(cur)
        elif old:
            entries.append({"date": old.group(1), "reason": old.group(2), "changes": [],
                            "quotes": quotes(line), "form": "old"})
            cur, key = None, None
        elif cur is None:
            continue
        elif line.startswith("- 바뀜:") or line.startswith("- 원문:"):
            key, _sep, value = line[2:].partition(":")
            value = value.strip()
            if key == "원문" and value:
                errors.append("%s 재분해 이력: 원문은 하위 항목으로 줄마다 하나씩 적는다: %r" % (cur["date"], line))
            elif value:
                cur["changes"].append(value)
        elif line.startswith(SUB_ITEM) and key in ("바뀜", "원문"):
            item = line[len(SUB_ITEM):].strip()
            if key == "원문" and not is_quote(item):
                errors.append("%s 재분해 이력: 원문 줄은 「…」 하나다: %r" % (cur["date"], line))
            elif key == "원문":
                cur["quotes"].append(item)
            elif item:
                cur["changes"].append(item)
        else:
            errors.append("%s 재분해 이력에서 읽지 못한 줄: %r" % (cur["date"], line))
    for e in entries:
        if e["form"] == "new" and not e["quotes"]:
            errors.append("%s 재분해 이력(%s)에 원문이 없다" % (e["date"], e["reason"]))
    return entries, errors


def parse_roadmap(text: str):
    """(meta, blocks, records, risk_rows, errors). blocks 는 등장 순서의 dict 목록."""
    errors = []
    meta = frontmatter(text)
    if meta.get("type") != "roadmap":
        errors.append("frontmatter type 이 roadmap 이 아니다")
    if not meta.get("source_brief"):
        errors.append("frontmatter source_brief 가 없다")
    try:
        body = section_body(text, "## 에픽")
        rec_body = section_body(text, "## 결정 기록") or ""
        risk_body = section_body(text, "## 위험 번호표") or ""
    except FormatError as exc:
        return meta, [], [], [], errors + [str(exc)]
    if body is None:
        return meta, [], [], [], errors + ["`## 에픽` 절이 없다"]

    blocks, cur, last = [], None, None
    for line in body.splitlines():
        if line.startswith("### "):
            last = None
            m = BLOCK_HEAD_RE.fullmatch(line.rstrip())
            if not m:
                errors.append("블록 머리가 `### <번호> — <이름>` 이 아니다: %r" % line)
                cur = None
                continue
            cur = {"id": m.group(1), "title": m.group(2), "fields": {}}
            blocks.append(cur)
        elif cur is not None and line.startswith(SUB_ITEM):
            item = line[len(SUB_ITEM):].strip()
            if last is None or not isinstance(cur["fields"].get(last), list):
                errors.append("%s: 하위 항목이 값 없는 칸(`- <칸>:`) 아래에 있지 않다: %r" % (cur["id"], line))
            elif not item:
                errors.append("%s: %s 칸의 하위 항목이 비었다" % (cur["id"], last))
            else:
                cur["fields"][last].append(item)
        elif cur is not None and line.startswith("- "):
            key, value = _field_line(line[2:])
            last = None
            if key is None:
                errors.append("%s: 모르는 머리말 줄 %r" % (cur["id"], line))
            elif key in cur["fields"]:
                errors.append("%s: 머리말 %s 가 두 번 있다" % (cur["id"], key))
            else:
                cur["fields"][key] = value
                last = key
    for b in blocks:
        for key, value in b["fields"].items():
            if isinstance(value, list) and not value:
                errors.append("%s: %s 칸에 값도 하위 항목도 없다" % (b["id"], key))
            elif isinstance(value, list) and key in ONE_LINE:
                errors.append("%s: %s 칸은 한 줄 값이다 — 하위 항목을 두지 않는다" % (b["id"], key))

    ids = [b["id"] for b in blocks]
    for bid in sorted({i for i in ids if ids.count(i) > 1}):
        errors.append("블록 번호 %s 가 두 번 있다" % bid)
    known = set(ids)
    for b in blocks:
        errors.extend(_validate_block(b, known))
    errors.extend(_cycles(blocks))

    records = []
    for line in rec_body.splitlines():
        if not line.startswith("- "):
            continue
        parts = line[2:].split(" · ", 3)
        if (len(parts) != 4 or parts[0] not in known or parts[1] not in ("결정", "머지")
                or not DATE_RE.fullmatch(parts[2])
                or not (parts[3].startswith("「") and parts[3].rstrip().endswith("」"))):
            errors.append("결정 기록 줄이 `- <블록> · <결정|머지> · <날짜> · 「원문」` 이 아니다: %r"
                          % line)
            continue
        records.append({"block": parts[0], "kind": parts[1], "date": parts[2],
                        "quote": parts[3].rstrip()})
    kinds = {b["id"]: b.get("kind") for b in blocks}
    for r in records:
        if (r["kind"] == "결정") != (kinds.get(r["block"]) == "decision"):
            errors.append("결정 기록: %s 는 %s 블록이라 「%s」 기록을 받지 않는다"
                          % (r["block"], kinds.get(r["block"]), r["kind"]))

    risk_rows = []
    for line in risk_body.splitlines():
        if line.startswith("- K"):
            m = RISK_ROW_RE.fullmatch(line.rstrip())
            if not m:
                errors.append("위험 번호표 줄이 `- K<n> — <원문>` 이 아니다: %r" % line)
            else:
                risk_rows.append((m.group(1), m.group(2)))
    errors.extend(parse_history(text)[1])
    return meta, blocks, records, risk_rows, errors


def _validate_block(b: dict, known: set) -> list:
    f, bid, errs = b["fields"], b["id"], []

    def one(key):
        value = f.get(key)
        return value if isinstance(value, str) else None

    kind = "decision" if "완료" in f else ("branch" if one("묶음") == "없음" else "bundle")
    b["kind"] = kind
    for key in REQUIRED[kind]:
        if key not in f:
            errs.append("%s: 머리말 %s 가 없다" % (bid, key))
    for key in FORBIDDEN[kind]:
        if key in f:
            errs.append("%s: %s 블록에는 머리말 %s 를 두지 않는다" % (bid, kind, key))
    if kind == "decision":
        if one("완료") != "결정 기록":
            errs.append("%s: 완료 값은 「결정 기록」이어야 한다" % bid)
        if one("묶음") != "없음":
            errs.append("%s: 확인 · 결정 블록의 묶음은 「없음」이어야 한다" % bid)
    if kind == "bundle" and one("묶음") is not None and not BUNDLE_NAME_RE.fullmatch(one("묶음")):
        errs.append("%s: 묶음 값은 로드맵 옆 파일 이름(R<n>.md)이어야 한다" % bid)
    deps = field_list(f.get("의존", "없음"))
    b["deps"] = deps
    for d in deps:
        if not BLOCK_ID_RE.fullmatch(d) or d not in known or d == bid:
            errs.append("%s: 의존 %r 가 로드맵의 다른 블록이 아니다" % (bid, d))
    b["reserved"] = field_list(f.get("경로 예약", "없음"))
    b["branches"] = field_list(f["브랜치"]) if kind != "decision" and "브랜치" in f else []
    if kind != "decision" and "브랜치" in f and not b["branches"]:
        errs.append("%s: 브랜치 칸에 브랜치 이름이 없다" % bid)
    if len(set(b["branches"])) != len(b["branches"]):
        errs.append("%s: 브랜치가 두 번 있다" % bid)
    b["assigned"] = []
    for key, want_s in (("발화", True), ("항목", False)):
        if one(key) is not None:
            try:
                toks = parse_ids(one(key))
            except FormatError as exc:
                errs.append("%s: %s — %s" % (bid, key, exc))
                continue
            wrong = [t for t in toks if (t.startswith("S") and t[1:].isdigit()) != want_s]
            if wrong:
                errs.append("%s: %s 줄에 맞지 않는 번호 %s" % (bid, key, " · ".join(wrong)))
            b["assigned"].extend(toks)
    return errs


def _cycles(blocks: list) -> list:
    deps = {b["id"]: b.get("deps", []) for b in blocks}
    state, errs = {}, []

    def visit(n, stack):
        if state.get(n) == 1:
            errs.append("의존이 돈다: %s" % " → ".join(stack + [n]))
            return
        if state.get(n) == 2 or n not in deps:
            return
        state[n] = 1
        for d in deps[n]:
            visit(d, stack + [n])
        state[n] = 2

    for n in deps:
        visit(n, [])
    return errs


def brief_universe(brief: str, audit: str):
    """(non_s, s_ids, k_expected). 셀 수 없으면 FormatError."""
    fm_lines = brief.split("\n---", 1)[0].splitlines()
    non_s = {m.group(1) for line in fm_lines for m in [ID_ITEM_RE.fullmatch(line)] if m}
    s0 = section_body(brief, "## 0.")
    s4 = section_body(brief, "## 4.")
    s5 = section_body(brief, "## 5.")
    if s0 is None or s4 is None or s5 is None:
        raise FormatError("brief 에 §0 · §4 · §5 중 없는 절이 있다")
    non_s |= {m.group(1) for line in s0.splitlines() for m in [OQ_LINE_RE.match(line)] if m}
    non_s |= set(RC_RE.findall(s5)) | set(ST_RE.findall(s5)) | set(KEY_RE.findall(s4))
    k_expected = []
    for prefix in RISK_PREFIXES:
        k_expected += [line[2:] for line in s5.splitlines() if line.startswith(prefix)]
    k_expected = [("K%d" % (i + 1), text) for i, text in enumerate(k_expected)]
    non_s |= {k for k, _ in k_expected}
    s_ids = set()
    for label, doc in (("brief", brief), ("audit", audit)):
        b6 = section6.body(doc)
        if b6 is None:
            raise FormatError("%s §6 을 하나로 읽을 수 없다" % label)
        s_ids |= set(S_ANCHOR_RE.findall(b6))
    if not non_s or not s_ids:
        raise FormatError("brief 번호 집합이 비었다")
    return non_s, s_ids, k_expected


def collect_assigned(blocks: list, meta: dict, roadmap_rel: str, read, exists):
    """묶음 블록의 `assigned` 를 그 묶음 `ids:` 로 채운다. 반환 (bundles, union, errors).

    bundles 는 블록 번호 → 묶음 글(못 읽으면 None), union 은 모든 블록의 배정 번호 합집합,
    errors 는 형식 깨짐 사유들. read(path) 는 글 또는 None, exists(path) 는 참/거짓 — 경로는 로드맵과
    같은 기준(레포 상대)이다.
    """
    roadmap_dir = roadmap_rel.rsplit("/", 1)[0] if "/" in roadmap_rel else "."
    bundles, union, errors = {}, set(), []
    for b in blocks:
        if b["kind"] != "bundle":
            union.update(b["assigned"])
            continue
        bpath = roadmap_dir + "/" + b["fields"]["묶음"]
        btext = read(bpath)
        bundles[b["id"]] = btext
        if btext is None:
            if exists(bpath):
                errors.append("%s 묶음을 읽지 못했다: %s" % (b["id"], bpath))
            continue
        fm = frontmatter(btext)
        bad = [k for k, want in (("type", "epic-bundle"), ("epic", b["id"]),
                                 ("roadmap", roadmap_rel), ("source_brief", meta.get("source_brief")))
               if unquote(fm.get(k, "")) != want]
        try:
            if bad:
                raise FormatError("frontmatter 가 맞지 않는다: %s" % " · ".join(bad))
            b["assigned"] = bundle_ids(btext)
        except FormatError as exc:
            errors.append("%s 묶음 — %s" % (b["id"], exc))
            continue
        union.update(b["assigned"])
    return bundles, union, errors


def _headings(doc_text: str):
    in_fence = False
    for line in doc_text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
        elif not in_fence and line.startswith("## "):
            yield line.rstrip()


def impl_done(doc_text: str, plan_rel: str) -> bool:
    """그 계획의 `## 구현 대조 — <계획 경로>` 절이 있는가 — 다른 계획의 절은 세지 않는다."""
    want = IMPL_PREFIX + plan_rel
    return any(h == want for h in _headings(doc_text))
