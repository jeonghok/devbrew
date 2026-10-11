#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_bundle_coverage.py — 조각 묶음의 번호 집합과 조각 spec 의 `## 번호 대조` 표를 맞춘다.

명령줄: check_bundle_coverage.py <묶음.md> <spec.md> [--json]
종료 코드: 0 빠진 번호 없음 · 1 빠진 번호 있음 · 2 사용법 오류 ·
3 검사 불가(`ids:` 없음 · 표 깨짐 · `## 번호 대조` 절 없음 · 파일을 못 읽음).

`roadmap_status.py` 는 `check(bundle_text, spec_text)` 를 import 해 `git show` 로 읽은 글을 넘긴다.
읽기만 한다 — 파일을 쓰지 않고 네트워크에 나가지 않는다.
"""
from __future__ import annotations

import argparse
import json
import re
import sys

# 번호 한 개 — 확정 C/D · 열린 질문 OQ · 레포 근거 RC · 위험 K · steelman ST · 발화 S, 또는 «key».
TOKEN_RE = re.compile(r"(?:C|D|OQ|RC|K|ST|S)\d+|«[^«»,·\s]+»")
# 번호 여럿의 구분 — 쉼표 또는 ` · `. 범위 표기(`K1~K7`)는 토큰 문법에 맞지 않아 깨짐으로 친다.
SEP_RE = re.compile(r"\s*,\s*|\s+·\s+")
SEP_CELL_RE = re.compile(r":?-{3,}:?")
PREFIX_ORDER = ("C", "D", "OQ", "RC", "K", "ST", "S")
TABLE_HEADING = "## 번호 대조"


class FormatError(ValueError):
    """검사할 수 없는 입력 — 종료 코드 3."""


def parse_ids(cell: str) -> list:
    """번호 칸 하나를 토큰 목록으로. 문법에 맞지 않는 조각이 하나라도 있으면 FormatError."""
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


def _cells(row: str) -> list:
    if not (row.startswith("|") and row.endswith("|")):
        raise FormatError("표 행이 | 로 시작하고 끝나지 않는다: %r" % row)
    return [c.strip() for c in row[1:-1].split("|")]


def table_ids(spec_text: str) -> set:
    """`## 번호 대조` 표의 첫 칸 번호 전부. 절이 없거나 표가 깨졌으면 FormatError."""
    body = section_body(spec_text, TABLE_HEADING)
    if body is None:
        raise FormatError("spec 에 `## 번호 대조` 절이 없다")
    rows = [l.strip() for l in body.splitlines() if l.strip().startswith("|")]
    if len(rows) < 3:
        raise FormatError("번호 대조 표가 없거나 데이터 행이 없다")
    if len(_cells(rows[0])) != 3:
        raise FormatError("번호 대조 표 머리 행이 칸 셋이 아니다")
    sep = _cells(rows[1])
    if len(sep) != 3 or not all(SEP_CELL_RE.fullmatch(c) for c in sep):
        raise FormatError("번호 대조 표 구분 행이 칸 셋이 아니다")
    out = set()
    for row in rows[2:]:
        cells = _cells(row)
        if len(cells) != 3:
            raise FormatError("번호 대조 표 행이 칸 셋이 아니다: %r" % row)
        if not (cells[1].startswith("반영") or cells[1].startswith("기각")):
            raise FormatError("둘째 칸이 반영/기각이 아니다: %r" % row)
        if not cells[2]:
            raise FormatError("셋째 칸(자리 또는 이유)이 비었다: %r" % row)
        out.update(parse_ids(cells[0]))
    return out


def check(bundle_text: str, spec_text: str) -> dict:
    """묶음 ids 중 표에 없는 번호(missing)와 표에만 있는 번호(extra)."""
    try:
        want = bundle_ids(bundle_text)
        have = table_ids(spec_text)
    except FormatError as exc:
        return {"status": 3, "missing": [], "extra": [], "bundle_count": None,
                "table_count": None, "reason": str(exc)}
    seen = set()
    missing = []
    for token in want:
        if token not in have and token not in seen:
            missing.append(token)
        seen.add(token)
    extra = sorted(have - seen, key=id_sort_key)
    return {"status": 1 if missing else 0, "missing": missing, "extra": extra,
            "bundle_count": len(seen), "table_count": len(have), "reason": None}


def render(result: dict) -> str:
    if result["status"] == 3:
        return "번호 대조 검사 불가 — %s" % result["reason"]
    lines = []
    if result["missing"]:
        lines.append("번호 대조: 빠진 번호 %d개 — %s"
                     % (len(result["missing"]), " · ".join(result["missing"])))
    else:
        lines.append("번호 대조: 빠진 번호 없음 (묶음 번호 %d개 · 표 번호 %d개)"
                     % (result["bundle_count"], result["table_count"]))
    if result["extra"]:
        lines.append("정보: 묶음에 없는 번호 %d개가 표에 있다 — %s"
                     % (len(result["extra"]), " · ".join(result["extra"])))
    return "\n".join(lines)


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(prog="check_bundle_coverage.py",
                                 description="조각 묶음의 번호와 spec 의 번호 대조 표를 맞춘다.")
    ap.add_argument("bundle")
    ap.add_argument("spec")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    texts = []
    for path in (args.bundle, args.spec):
        try:
            with open(path, encoding="utf-8") as fh:
                texts.append(fh.read())
        except (OSError, UnicodeDecodeError) as exc:
            result = {"status": 3, "missing": [], "extra": [], "bundle_count": None,
                      "table_count": None, "reason": "파일을 못 읽었다: %s (%s)" % (path, exc)}
            print(json.dumps(result, ensure_ascii=False) if args.json else render(result))
            return 3
    try:
        result = check(texts[0], texts[1])
    except Exception as exc:  # 검사 자체가 죽어도 이상 없음(0)으로 내지 않는다
        result = {"status": 3, "missing": [], "extra": [], "bundle_count": None,
                  "table_count": None, "reason": "내부 오류 — %s: %s" % (type(exc).__name__, exc)}
    print(json.dumps(result, ensure_ascii=False) if args.json else render(result))
    return result["status"]


if __name__ == "__main__":
    sys.exit(main())
