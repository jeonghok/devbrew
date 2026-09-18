#!/usr/bin/env python3
"""seed_provenance.py — seed 문장의 출처와 확인을 audit 기록과 대조한다.

  marks    <seed> <audit> [--fix]    «(사용자 확인)» 이 붙은 문장이 audit `## 2. 질문 전체` 의
                                     「…」 — 고름 풀이 안에 있는가. 없으면 보고하고 rc 1 —
                                     --fix 면 그 표시만 떼고 seed 를 다시 쓴다(rc 0).
  classify <seed> [--audit <audit>]  seed 본문 문장마다 출처(user|author)와 확인(true|false).

비교 단위 — 공백(줄바꿈 포함)을 한 칸으로 접고 종결부호 앞 공백을 지운 뒤 **글자 그대로** 본다.
마크업(백틱 · 별표)은 지우지 않는다. seed 문장이 확인된 풀이의 부분 문자열이면 확인이다. 압축이
그 문장을 한 글자라도 고치면 확인이 아니다 — 확인은 저자가 다시 쓸 수 없는 고정점이다.
audit 을 못 읽으면 확인된 풀이는 0 이다: 표시는 전부 근거 없음, 문장은 전부 저자 · 미확인.
rc: 0 정상 · 1 marks 위반 · 2 입력 오류.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

from seed_review_log import section_body

MARK = "(사용자 확인)"
REVERIFY_PREFIX = "다시 검증할 것 —"
FRONTMATTER_RE = re.compile(r"\A---\n.*?\n---\n", re.S)
READING_RE = re.compile(r"^\s*- 내가 읽은 것: 「(?P<t>.*)」 — 고름\s*$")
SENT_SPLIT_RE = re.compile(r"(?<=[.!?。])\s+")
MARK_OCC_RE = re.compile(r"[ \t]*" + re.escape(MARK))


def norm(s: str) -> str:
    s = re.sub(r"\s+", " ", s).strip()
    return re.sub(r"\s+([.!?。,])", r"\1", s)


def split_front(text: str) -> tuple[str, str]:
    m = FRONTMATTER_RE.match(text)
    head = m.group(0) if m else ""
    return head, text[len(head):]


def segments(body: str) -> list[dict]:
    """문단 → 문장. 문장 뒤에 붙은 표시는 그 문장에 속한다."""
    out = []
    for para in re.split(r"\n\s*\n", body.strip()):
        flat = norm(para)
        if not flat:
            continue
        reverify = flat.startswith(REVERIFY_PREFIX)
        sents: list[str] = []
        for piece in SENT_SPLIT_RE.split(flat):
            if piece.startswith(MARK) and sents:
                sents[-1] += " " + MARK
                rest = piece[len(MARK):].strip()
                if rest:
                    sents.append(rest)
            else:
                sents.append(piece)
        for s in sents:
            out.append({"text": norm(s.replace(MARK, "")), "marked": MARK in s, "reverify": reverify})
    return out


def confirmed_readings(audit_text: str | None) -> list[str]:
    body = section_body(audit_text, "## 2. 질문 전체") if audit_text else None
    return [norm(m["t"]) for m in map(READING_RE.match, (body or "").splitlines()) if m]


def with_mark_status(segs: list[dict], readings: list[str]) -> list[dict]:
    for s in segs:
        if s["marked"]:
            s["mark_valid"] = bool(s["text"]) and any(s["text"] in r for r in readings)
    return segs


def strip_invalid(text: str, segs: list[dict]) -> str:
    head, body = split_front(text)
    marked = [s for s in segs if s["marked"]]
    occ = list(MARK_OCC_RE.finditer(body))
    if len(occ) != len(marked):
        raise ValueError("mark_count_mismatch: 표시 %d개 · 표시 붙은 문장 %d개" % (len(occ), len(marked)))
    out, last = [], 0
    for m, s in zip(occ, marked):
        out.append(body[last:m.end()] if s["mark_valid"] else body[last:m.start()])
        last = m.end()
    out.append(body[last:])
    return head + "".join(out)


def _read_audit(path: str | None) -> tuple[str | None, str]:
    if not path:
        return None, "unavailable: --audit 없음"
    try:
        return pathlib.Path(path).read_text(encoding="utf-8"), "ok"
    except OSError as e:
        return None, "unavailable: %s" % e


def classify(segs: list[dict], audit_text: str | None) -> list[dict]:
    raw = norm(section_body(audit_text, "## 1. 원문") or "") if audit_text else ""
    out = []
    for s in segs:
        if s["reverify"]:
            r = ("author", False, "reverify_paragraph")
        elif s["marked"] and s.get("mark_valid"):
            r = ("user", True, "confirmed_reading")
        elif s["text"] and raw and s["text"] in raw:
            r = ("user", False, "verbatim")
        elif s["marked"]:
            r = ("author", False, "mark_invalid")
        else:
            r = ("author", False, "none")
        out.append({"text": s["text"], "provenance": r[0], "confirmed": r[1], "basis": r[2]})
    return out


def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="seed_provenance.py")
    sp = p.add_subparsers(dest="cmd", required=True)
    x = sp.add_parser("marks"); x.add_argument("seed"); x.add_argument("audit")
    x.add_argument("--fix", action="store_true")
    x = sp.add_parser("classify"); x.add_argument("seed"); x.add_argument("--audit", default=None)
    try:
        a = p.parse_args(argv)
    except SystemExit:
        return 2
    seed = pathlib.Path(a.seed)
    try:
        text = seed.read_text(encoding="utf-8")
    except OSError as e:
        print("seed 를 읽지 못했다: %s" % e, file=sys.stderr)
        return 2
    audit_text, audit_state = _read_audit(a.audit)
    segs = with_mark_status(segments(split_front(text)[1]), confirmed_readings(audit_text))
    if a.cmd == "marks":
        invalid = [s["text"] for s in segs if s["marked"] and not s["mark_valid"]]
        res = {"marked": sum(1 for s in segs if s["marked"]), "invalid": invalid,
               "audit": audit_state, "fixed": False}
        if invalid and a.fix:
            try:
                seed.write_text(strip_invalid(text, segs), encoding="utf-8")
            except ValueError as e:
                print(str(e), file=sys.stderr)
                return 2
            res["fixed"] = True
        print(json.dumps(res, ensure_ascii=False))
        return 1 if (invalid and not a.fix) else 0
    rows = classify(segs, audit_text)
    counts = {"user_confirmed": sum(1 for r in rows if r["provenance"] == "user" and r["confirmed"]),
              "user_unconfirmed": sum(1 for r in rows if r["provenance"] == "user" and not r["confirmed"]),
              "author": sum(1 for r in rows if r["provenance"] == "author")}
    print(json.dumps({"audit": audit_state, "sentences": rows, "counts": counts}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
