#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_bundle_coverage.py — 에픽 묶음의 번호 집합과 에픽 spec 의 `## 번호 대조` 표를 맞춘다.

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
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from roadmap_model import (  # noqa: E402,F401 — 이 이름들은 이 모듈의 공개 표면이기도 하다
    FormatError, PREFIX_ORDER, SEP_CELL_RE, SEP_RE, TOKEN_RE, bundle_ids, frontmatter,
    id_sort_key, parse_ids, section_body, unquote)

TABLE_HEADING = "## 번호 대조"


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
                                 description="에픽 묶음의 번호와 spec 의 번호 대조 표를 맞춘다.")
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
