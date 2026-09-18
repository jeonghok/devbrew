#!/usr/bin/env python3
"""seed_provenance.py — seed 문장의 출처와 확인을 audit 기록과 대조한다.

  marks    <seed> <audit> [--fix]    «(사용자 확인)» 이 붙은 문장이 audit `## 2. 질문 전체` 의
                                     「…」 — 고름 풀이를 문장 단위로 쪼갠 것과 정확히 같은가
                                     (부분 문자열이 아니다). 다르면 보고하고 rc 1 — --fix 면 그
                                     표시만 떼고 seed 를 다시 쓴다(rc 0). audit 을 못 읽거나
                                     못 믿으면(중복 제목 · 절 누락) 판단을 거부하고 rc 2.
  classify <seed> [--audit <audit>]  seed 본문 문장마다 출처(user|author)와 확인(true|false).

비교 단위 — 공백(줄바꿈 포함)을 한 칸으로 접고 종결부호 앞 공백을 지운 뒤 **문장 단위로 정확히
같아야**(부분 문자열이 아니다) 확인 · 원문으로 친다. 마크업(백틱 · 별표)은 지우지 않는다. audit
`## 2` 의 풀이 문장 하나가 통째로 seed 에 남으면 확인이고, `## 1` 의 원문 문장(문단 전체를 이어
붙인 것과, 감싼 문장의 뒷토막이 아닌 줄 단위 각각을 단위로 본다) 하나가 통째로 남으면 사용자
원문이다. 압축이 그 문장을 한 글자라도 고치면 확인 · 원문 어느 쪽도 아니다 — 확인은 저자가 다시
쓸 수 없는 고정점이다.
audit 을 못 읽으면 확인된 풀이와 원문 문장은 0 이다: marks 는 판단을 거부하고(rc 2), classify 는
전부 저자 · 미확인으로 떨어지며 그 사실을 밝힌다. audit 에 템플릿 제목이 중복되거나(예: `## 2`
줄이 `## 1` 본문 안에도 심겨 있음) `## 1`/`## 2` 절이 없으면 같은 «못 믿는» 상태로 다룬다.
rc: 0 정상 · 1 marks 위반 · 2 입력 오류(seed 못 읽음 · audit 을 못 믿음).
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

from seed_review_log import duplicate_headings, section_body

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


def _sentence_units(flat: str) -> list[str]:
    """정규화된 한 문자열을 `SENT_SPLIT_RE` 로 쪼갠 뒤 다시 정규화한 비어 있지 않은 조각들."""
    return [p for p in (norm(piece) for piece in SENT_SPLIT_RE.split(flat)) if p]


def confirmed_reading_sentences(audit_text: str | None) -> set[str]:
    """`## 2` 의 「…」 — 고름 풀이마다 문장 단위로 쪼갠 집합. seed 문장은 이 집합의 원소와
    **정확히 같아야**(부분 문자열이 아니다) 확인이다 — 풀이 문장 하나가 통째로 살아남으면
    확인, 압축이 그 문장 경계를 넘나들며 고치면 확인이 아니다."""
    body = section_body(audit_text, "## 2. 질문 전체") if audit_text else None
    readings = [norm(m["t"]) for m in map(READING_RE.match, (body or "").splitlines()) if m]
    out: set[str] = set()
    for r in readings:
        out.update(_sentence_units(r))
    return out


def verbatim_units(audit_text: str | None) -> set[str]:
    """`## 1` 원문의 문장 단위 집합 — 문단 전체를 이어 붙여 쪼갠 것과, 줄 하나하나를 각각
    쪼갠 것의 합집합이다. 후자가 있어야 종결부호 없는 대화체 줄(예: 「로그인이 가끔 실패한다」)
    도 그 줄 하나만으로 사용자 원문 단위가 된다 — 전체를 이어 붙이면 다음 줄과 합쳐져 버린다.
    단, 줄 단위가 전체 단위의 진부분 꼬리이면 뺀다 — 한 문장을 줄바꿈으로 감싼 뒷토막이라
    그것만 남은 seed 문장은 원문 문장이 아니다."""
    body = section_body(audit_text, "## 1. 원문") if audit_text else None
    if not body:
        return set()
    whole: set[str] = set(_sentence_units(norm(body)))
    out: set[str] = set(whole)
    for line in body.splitlines():
        line_n = norm(line)
        if not line_n:
            continue
        for u in _sentence_units(line_n):
            if not any(len(w) > len(u) and w.endswith(u) for w in whole):
                out.add(u)
    return out


def with_mark_status(segs: list[dict], reading_sentences: set[str]) -> list[dict]:
    for s in segs:
        if s["marked"]:
            s["mark_valid"] = bool(s["text"]) and s["text"] in reading_sentences
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
    """audit 을 읽고 신뢰할 수 있는지 확인한다. 셋 중 하나라도 걸리면 못 믿는 것으로 친다 —
    `audit_text` 를 None 으로 돌려 하류가 «없음»과 똑같이 다루게 한다: (1) 못 읽음,
    (2) `AUDIT_HEADINGS` 제목이 본문 어딘가에 심겨 중복됨(`section_body` 가 첫 occurrence 를
    고르므로 `## 1` 본문 안에 `## 2` 로 보이는 줄이 있으면 진짜 `## 2` 를 가릴 수 있다),
    (3) `## 1`/`## 2` 절 자체가 없음."""
    if not path:
        return None, "unavailable: --audit 없음"
    try:
        text = pathlib.Path(path).read_text(encoding="utf-8")
    except (OSError, UnicodeError) as e:
        return None, "unavailable: %s" % e
    dups = duplicate_headings(text)
    if dups:
        return None, "unavailable: duplicate_heading %s" % ", ".join(h for h, _ in dups)
    missing = [h for h in ("## 1. 원문", "## 2. 질문 전체") if section_body(text, h) is None]
    if missing:
        return None, "unavailable: section_missing %s" % ", ".join(missing)
    return text, "ok"


def classify(segs: list[dict], audit_text: str | None) -> list[dict]:
    verb_units = verbatim_units(audit_text)
    out = []
    for s in segs:
        if s["reverify"]:
            r = ("author", False, "reverify_paragraph")
        elif s["marked"] and s.get("mark_valid"):
            r = ("user", True, "confirmed_reading")
        elif s["text"] and s["text"] in verb_units:
            r = ("user", False, "verbatim")
        elif s["marked"]:
            r = ("author", False, "mark_invalid")
        else:
            r = ("author", False, "none")
        out.append({"text": s["text"], "provenance": r[0], "confirmed": r[1], "basis": r[2]})
    return out


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
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
    except (OSError, UnicodeError) as e:
        print("seed 를 읽지 못했다: %s" % e, file=sys.stderr)
        return 2
    audit_text, audit_state = _read_audit(a.audit)
    segs = with_mark_status(segments(split_front(text)[1]), confirmed_reading_sentences(audit_text))
    if a.cmd == "marks":
        if audit_state != "ok":
            print("[spec-distill] audit 을 판단할 수 없어 marks 를 매길 수 없다(위반이 아니다): %s"
                  % audit_state, file=sys.stderr)
            return 2
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
