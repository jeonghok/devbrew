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
`## 2` 의 풀이 문장 하나가 통째로 seed 에 남으면 확인이고, `## 1` 의 원문 문장(문단마다 — 그
문단을 이어 붙인 것과, 감싼 문장의 뒷토막이 아닌 그 문단의 줄 각각을 단위로 본다) 하나가 통째로
남으면 사용자 원문이다. «(사용자 확인)» 은 문장 경계다 — 종결부호 없는 풀이 뒤에 붙어도 그 뒤
글자는 다음 문장이다. 압축이 그 문장을 한 글자라도 고치면 확인 · 원문 어느 쪽도 아니다 — 확인은
저자가 다시 쓸 수 없는 고정점이다.
확인 표시는 문장을 따라간다 — 근거 있는 «(사용자 확인)» 이 붙은 문장은 «다시 검증할 것 —» 문단 안에서도
사용자 확인이다. 그 문단의 표시 없는 문장은 저자 · 미확인이다.
audit 을 못 읽으면 확인된 풀이와 원문 문장은 0 이다: marks 는 판단을 거부하고(rc 2), classify 는
전부 저자 · 미확인으로 떨어지며 그 사실을 밝힌다. audit 에 템플릿 제목이 중복되거나(예: `## 2`
줄이 `## 1` 본문 안에도 심겨 있음) `## 1`/`## 2` 절이 없으면 같은 «못 믿는» 상태로 다룬다.
표시가 있는데 `## 2` 에 풀이 줄(`- 내가 읽은 것: 「…」 — 고름|고르지 않음`, 끝에 ` — 사용자가 적은 말: 「…」` 가 붙을 수 있다)이 하나도 없거나, `- 내가 읽은
것:` 으로 시작하는데 그 모양이 아닌 줄이 하나라도 있으면 marks 는 판단을 거부한다(rc 2) — 줄 모양이
어긋난 것과 확인이 없었던 것을 이 코드가 가를 수 없고, 그 판정은 줄마다 성립한다.
풀이 줄은 `parse_reading_line` 하나가 읽는다 — 판정은 줄에서 **왼쪽에서 처음 나오는** 판정 구분자
(`」 — 고름` · `」 — 고르지 않음`) 하나로 정하고, 그 뒤 나머지는 비었거나 정확히 ` — 사용자가 적은 말: 「…」`
여야 한다. 꼬리(사용자 자유 입력)는 판정 뒤에만 오므로 그 안에 `」 — 고름` 을 심어도 판정이 바뀌지 않는다 —
사람과 모델도 왼쪽 첫 판정으로 읽는다. 그 밖의 나머지는 모양 어긋남이다.
«(사용자 확인)» 의 근거는 `— 고름` 풀이 줄의 풀이 글자뿐이다 — 적은 말 꼬리 · `## seed 에서 덜어 낸 것`
표(되살림 칸 포함)는 근거가 아니다. 되살린 문장은 `## 1` 원문과 글자가 같을 때만 사용자 원문(미확인)이다.
seed 본문은 `seed_body.parse_seed` 하나로 읽는다 — 게이트(`check_seed.py`)와 같은 문법이다. 그 문법이
거부하는 줄(산문이 아닌 구조 · 보이지 않는 글자 · 정본이 아닌 확인 표시 · URL 등)이 하나라도 있으면 marks 와
classify 는 판단하지 않는다(rc 2) — 게이트가 막는 seed 의 출처를 이 코드가 따로 매기지 않는다. 확인 표시는
정본 글자 «(사용자 확인)» 하나뿐이다. 줄바꿈에 걸쳐 감싼 표시처럼 문법을 지난 뒤 정본 글자와 다른 표시는
근거 없는 표시다(marks 위반 · `--fix` 가 뗀다 · classify 는 mark_invalid). 글자 하나씩 접은 자리와
문자열 전체를 접은 수가 다르면 표시의 자리를 정할 수 없어 marks 는 판단을 거부한다(rc 2).
rc: 0 정상 · 1 marks 위반 · 2 입력 오류(seed 못 읽음 · seed 를 못 씀 · seed 문법 거부 · audit 을 못 믿음 ·
풀이 줄 0 · 표시 자리를 정할 수 없음 · 그 밖의 예외). rc 1 은 위반에만 쓴다.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

from seed_body import (MARK, fold_flat, mark_spans, marks_in_flat, parse_seed,  # noqa: F401
                       rejected_lines_message, split_front, split_paragraphs)
from seed_review_log import heading_structure, read_audit_text, section_body, separator_lines, separator_message

REVERIFY_PREFIX = "다시 검증할 것 —"
# 풀이 줄 — `parse_reading_line` 이 읽는다. 끝의 선택 꼬리는 사용자가 «기타» 로 적은 말 · 「아니다」 뒤에
# 덧붙인 말(N19)이다. 꼬리 안의 글자는 비신뢰 요청문이라 판정에 쓰지 않는다 — 줄 모양만 받는다.
READING_HEAD = "- 내가 읽은 것: 「"
VERDICT_SEPS = ("」 — 고름", "」 — 고르지 않음")
SAID_HEAD = " — 사용자가 적은 말: 「"
READING_PREFIX_RE = re.compile(r"^\s*- 내가 읽은 것:")
# 템플릿이 예시로 담은 자리표 줄 — 아무것도 채우지 않은 것, 즉 **두 자리가 모두** 꺾쇠이고 줄
# 전체가 그 모양이다. 이것은 모양이 어긋난 풀이가 아니라 저자가 아직 손대지 않은 예시다(템플릿을
# 그대로 복사한 audit 이 막히지 않는다). **반쯤 채운 줄은 자리표가 아니다** — 따옴표만 채우고 처분
# 자리표를 남긴 줄은 흔한 저자 실수이고, 그 줄을 건너뛰면 `--fix` 가 진짜 «(사용자 확인)» 을 뗀다
# (이 가드가 막으려던 바로 그 손실이다). 넓은 술어가 사는 것은 없고 잃는 것은 진짜 확인이다.
PLACEHOLDER_READING_RE = re.compile(
    r"^\s*- 내가 읽은 것:\s*「\s*<[^<>」]*>\s*」\s*—\s*<[^<>]*>"
    r"(?:\s*\[\s*—\s*사용자가 적은 말:\s*「\s*<[^<>」]*>\s*」\s*\])?\s*$")
SENT_SPLIT_RE = re.compile(r"(?<=[.!?。])\s+|(?<=" + re.escape(MARK) + r")\s+")


def parse_reading_line(line: str) -> tuple[str, str, str | None] | None:
    """풀이 줄 하나 → `(풀이 글자, 고름|고르지 않음, 적은 말 또는 None)`. 모양이 아니면 None.
    판정은 왼쪽에서 처음 나오는 판정 구분자 하나다(풀이 글자는 그 앞까지 — 비탐욕)."""
    s = line.strip()
    if not s.startswith(READING_HEAD):
        return None
    rest = s[len(READING_HEAD):]
    hits = [(rest.find(v), v) for v in VERDICT_SEPS if v in rest]
    if not hits:
        return None
    at, sep = min(hits)
    after = rest[at + len(sep):]
    if after == "":
        said = None
    elif after.startswith(SAID_HEAD) and after.endswith("」") and len(after) > len(SAID_HEAD):
        said = after[len(SAID_HEAD):-1]
    else:
        return None
    return rest[:at], sep[len("」 — "):], said


def mark_positions_ok(body: str, segs: list[dict]) -> bool:
    """표시 자리를 하나로 정할 수 있는가 — 본문 전체에서 글자마다 접어 찾은 수 · 문자열 전체를 접어 센 수 ·
    문장마다 센 수의 합이 모두 같아야 한다."""
    n = len(mark_spans(body))
    return n == len(marks_in_flat(fold_flat(body))) == sum(s["n_marks"] for s in segs)


def norm(s: str) -> str:
    s = re.sub(r"\s+", " ", s).strip()
    return re.sub(r"\s+([.!?。,])", r"\1", s)


def segments(paragraphs: list[str]) -> list[dict]:
    """문단 → 문장. 문장 뒤에 붙은 표시는 그 문장에 속한다. 표시 변형도 정본과 같은 자리에서 문장을
    끊고 붙는다 — 변형 자리를 정본 글자로 바꾼 사본으로 쪼개고, 문장마다 그 안의 표시가 변형이었는지를
    순서대로 되찾는다."""
    out = []
    for para in paragraphs:  # `seed_body.parse_seed` 가 나눈 문단 그대로 — 두 번째 문단 나누기가 없다
        flat = norm(para)
        if not flat:
            continue
        reverify = flat.startswith(REVERIFY_PREFIX)
        spans = mark_spans(flat)
        variants = [flat[a:b] != MARK for a, b in spans]
        canon, last = [], 0
        for a, b in spans:
            canon += [flat[last:a], MARK]
            last = b
        canon.append(flat[last:])
        flat = "".join(canon)
        if flat.count(MARK) != len(spans):
            raise ValueError("mark_count_mismatch: 표시 자리 %d개 · 정본으로 바꾼 뒤 %d개"
                             % (len(spans), flat.count(MARK)))
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
            n = s.count(MARK)
            flags, variants = variants[:n], variants[n:]
            out.append({"text": norm(s.replace(MARK, "")), "marked": n > 0, "n_marks": n,
                        "variant": any(flags), "reverify": reverify})
    return out


def _sentence_units(flat: str) -> list[str]:
    """정규화된 한 문자열을 `SENT_SPLIT_RE` 로 쪼갠 뒤 다시 정규화한 비어 있지 않은 조각들."""
    return [p for p in (norm(piece) for piece in SENT_SPLIT_RE.split(flat)) if p]


def confirmed_reading_sentences(audit_text: str | None) -> set[str]:
    """`## 2` 의 「…」 — 고름 풀이마다 문장 단위로 쪼갠 집합. seed 문장은 이 집합의 원소와
    **정확히 같아야**(부분 문자열이 아니다) 확인이다 — 풀이 문장 하나가 통째로 살아남으면
    확인, 압축이 그 문장 경계를 넘나들며 고치면 확인이 아니다."""
    body = section_body(audit_text, "## 2. 질문 전체") if audit_text else None
    readings = [norm(r[0]) for r in map(parse_reading_line, (body or "").split("\n"))
                if r is not None and r[1] == "고름"]
    out: set[str] = set()
    for r in readings:
        out.update(_sentence_units(r))
    return out


def verbatim_units(audit_text: str | None) -> set[str]:
    """`## 1` 원문의 문장 단위 집합 — 문단(빈 줄로 나뉜 덩어리)마다, 그 문단을 이어 붙여 쪼갠
    것과 그 문단의 줄 하나하나를 각각 쪼갠 것의 합집합이다. 줄 단위가 있어야 종결부호 없는 대화체
    줄(예: 「로그인이 가끔 실패한다」)도 그 줄 하나만으로 사용자 원문 단위가 된다 — 문단을 이어
    붙이면 다음 줄과 합쳐져 버린다. 단, 줄 단위가 **같은 문단**의 이어 붙인 단위의 진부분 꼬리이면
    뺀다 — 한 문장을 줄바꿈으로 감싼 뒷토막이라 그것만 남은 seed 문장은 원문 문장이 아니다.
    문단을 넘어 이어 붙이지 않는다 — 문장부호 없는 앞 문단(인사말 · 라벨)이 다음 문단의 온전한
    문장을 꼬리로 만들어 버린다."""
    body = section_body(audit_text, "## 1. 원문") if audit_text else None
    if not body:
        return set()
    out: set[str] = set()
    for para in split_paragraphs(body.strip()):   # seed 본문과 같은 문단 나눔 — 공백만 있는 줄은 경계가 아니다
        whole = set(_sentence_units(norm(para)))
        out |= whole
        for line in para.split("\n"):
            line_n = norm(line)
            if not line_n:
                continue
            for u in _sentence_units(line_n):
                if not any(len(w) > len(u) and w.endswith(u) for w in whole):
                    out.add(u)
    return out


def reading_line_count(audit_text: str | None) -> int:
    """`## 2` 의 풀이 줄(고름 · 고르지 않음 어느 쪽이든) 수 — 0 이면 표시를 매길 근거 자체가 없다."""
    body = section_body(audit_text, "## 2. 질문 전체") if audit_text else None
    return sum(1 for line in (body or "").split("\n") if parse_reading_line(line) is not None)


def malformed_reading_lines(audit_text: str | None) -> list[int]:
    """`## 2` 에서 `- 내가 읽은 것:` 으로 시작하는데 풀이 줄 모양이 아닌 줄의 번호(그 절 안에서 1 부터).
    그 줄의 고름은 읽히지 않는다. 템플릿 자리표 줄은 세지 않는다(`PLACEHOLDER_READING_RE`).

    줄 «내용» 은 돌려주지 않는다 — 그 글자는 비신뢰 요청문에서 왔고, 부르는 쪽은 이 결과를
    stderr 로 내보내며 그 stderr 는 엔진의 `--reason "<…>"` 처럼 큰따옴표 안으로 옮겨 적힌다.
    거기 실린 `$( )` 는 셸이 실행한다. 자리는 번호로 가리킨다."""
    body = section_body(audit_text, "## 2. 질문 전체") if audit_text else None
    return [n for n, line in enumerate((body or "").split("\n"), 1)
            if READING_PREFIX_RE.match(line) and parse_reading_line(line) is None
            and not PLACEHOLDER_READING_RE.match(line)]


def with_mark_status(segs: list[dict], reading_sentences: set[str]) -> list[dict]:
    for s in segs:
        if s["marked"]:
            s["mark_valid"] = not s["variant"] and bool(s["text"]) and s["text"] in reading_sentences
    return segs


def strip_invalid(text: str, segs: list[dict]) -> str:
    head, body = split_front(text)
    occ = mark_spans(body)
    if not mark_positions_ok(body, segs):
        raise ValueError("mark_count_mismatch: 표시 자리 %d개 · 문장마다 센 표시 %d개"
                         % (len(occ), sum(s["n_marks"] for s in segs)))
    out, last, k = [], 0, 0
    for s in segs:
        for _ in range(s["n_marks"]):
            a, b = occ[k]
            k += 1
            if s["mark_valid"]:
                out.append(body[last:b])
            else:
                while a > last and body[a - 1] in " \t":  # 표시 앞 공백까지 뗀다
                    a -= 1
                out.append(body[last:a])
            last = b
    out.append(body[last:])
    return head + "".join(out)


def _read_audit(path: str | None) -> tuple[str | None, str]:
    """audit 을 읽고 신뢰할 수 있는지 확인한다. 셋 중 하나라도 걸리면 못 믿는 것으로 친다 —
    `audit_text` 를 None 으로 돌려 하류가 «없음»과 똑같이 다루게 한다: (1) 못 읽음,
    (2) `AUDIT_HEADINGS` 제목이 겹치거나 템플릿 순서가 어긋남(`heading_structure` — `## 1` 본문 안에
    심긴 `## 2` 줄은 펜스 안이든 밖이든 둘 중 하나가 된다),
    (3) `## 1`/`## 2` 절 자체가 없음."""
    if not path:
        return None, "unavailable: --audit 없음"
    try:
        text = read_audit_text(path)
    except (OSError, UnicodeError) as e:
        return None, "unavailable: %s" % e
    sep = separator_lines(text)
    if sep:
        return None, "unavailable: line_separator " + ",".join(map(str, sep))
    problems = heading_structure(text)
    if problems:
        return None, "unavailable: %s" % "; ".join(problems)
    missing = [h for h in ("## 1. 원문", "## 2. 질문 전체") if section_body(text, h) is None]
    if missing:
        return None, "unavailable: section_missing %s" % ", ".join(missing)
    return text, "ok"


def classify(segs: list[dict], audit_text: str | None) -> list[dict]:
    verb_units = verbatim_units(audit_text)
    out = []
    for s in segs:
        if s["marked"] and s.get("mark_valid"):
            r = ("user", True, "confirmed_reading")
        elif s["reverify"]:
            r = ("author", False, "reverify_paragraph")
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
    parsed = parse_seed(text)
    if parsed.rejected:
        for msg in rejected_lines_message(parsed.rejected):
            print("[seed_provenance] " + msg, file=sys.stderr)
        print("[spec-distill] seed 문법이 거부한 줄이 있어 %s 를 매기지 않는다(위반이 아니다 — check_seed 게이트가 "
              "같은 줄을 막는다)" % a.cmd, file=sys.stderr)
        return 2
    audit_text, audit_state = _read_audit(a.audit)
    segs = with_mark_status(segments(parsed.paragraphs), confirmed_reading_sentences(audit_text))
    if a.cmd == "marks":
        if not mark_positions_ok(split_front(text)[1], segs):
            print("[spec-distill] seed 의 확인 표시 자리를 하나로 정할 수 없다(접은 글자가 문장 경계를 넘거나 "
                  "글자마다 접은 것과 전체를 접은 것이 다르다) — 판단하지 않는다(mark_ambiguous, 위반이 아니다)",
                  file=sys.stderr)
            return 2
        if audit_state.startswith("unavailable: line_separator "):
            nums = [int(n) for n in audit_state.split(" ")[-1].split(",")]
            for ln in separator_message(nums).split("\n"):
                print("[seed_provenance] " + ln, file=sys.stderr)
        if audit_state != "ok":
            print("[spec-distill] audit 을 판단할 수 없어 marks 를 매길 수 없다(위반이 아니다): %s"
                  % audit_state, file=sys.stderr)
            return 2
        n_marked = sum(1 for s in segs if s["marked"])
        n_lines = reading_line_count(audit_text)
        bad = malformed_reading_lines(audit_text) if n_marked else []
        if bad:
            print("[spec-distill] audit `## 2. 질문 전체` 의 풀이 줄 %d개가 모양(`- 내가 읽은 것: 「…」 — 고름|고르지 "
                  "않음`, 끝에 ` — 사용자가 적은 말: 「…」` 가 붙을 수 있다)과 다르다 — 그 줄의 확인을 읽을 수 없어 판단하지 않는다(malformed_reading_lines, 위반이 "
                  "아니다). 그 절 안에서 %s 번째 줄이다(줄 내용은 싣지 않는다 — 요청문에서 온 글자다)."
                  % (len(bad), " · ".join(str(n) for n in bad)), file=sys.stderr)
            return 2
        if n_marked and not n_lines:
            print("[spec-distill] 표시가 %d개인데 audit `## 2. 질문 전체` 에 풀이 줄(`- 내가 읽은 것: "
                  "「…」 — 고름|고르지 않음`, 끝에 ` — 사용자가 적은 말: 「…」` 가 붙을 수 있다)이 하나도 없다 — 표시를 매길 근거가 없어 판단하지 않는다"
                  "(no_reading_lines, 위반이 아니다)" % n_marked, file=sys.stderr)
            return 2
        invalid = [s["text"] for s in segs if s["marked"] and not s["mark_valid"]]
        res = {"marked": n_marked, "invalid": invalid, "reading_lines": n_lines,
               "audit": audit_state, "fixed": False}
        if invalid and a.fix:
            try:
                seed.write_text(strip_invalid(text, segs), encoding="utf-8")
            except (ValueError, OSError) as e:
                print("[spec-distill] 표시를 떼지 못했다(seed 는 그대로일 수 있다): %s" % e, file=sys.stderr)
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
    try:
        sys.exit(main())
    except Exception as e:  # rc 1 은 위반 전용 — 예상 못 한 실패를 위반으로 읽히지 않게 2 로 낸다
        print("[spec-distill] seed_provenance.py 내부 오류(판단 불가): %s: %s" % (type(e).__name__, e),
              file=sys.stderr)
        sys.exit(2)
