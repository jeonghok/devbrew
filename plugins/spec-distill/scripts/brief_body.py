#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""brief_body.py — brief 의 §6 앵커 줄 · 결정 줄 머리 · §3 열린 줄 참조 · §4 항목을 읽는 허용 문법 하나.

`check_brief` · `check_verbatim_coverage` · `roadmap_model` 이 함께 쓴다 — 판독기 셋이 같은 줄을 다르게 읽는
틈을 없앤다(`seed_body.py` 방식). 문법 밖 줄은 사유 이름과 함께 거부한다. 표준 라이브러리만 쓰고 파일을
읽지 않는다.
"""
from __future__ import annotations

import re
import unicodedata

# §6 앵커 줄의 허용 문법 — 열 0 의 `- ` 하나 + `**S<n>**`(번호는 ASCII 숫자 · 앞자리 0 없음) + (공백 하나 + 본문).
# 그 밖은 앵커가 아니다.
ANCHOR_LINE_RE = re.compile(r"^- \*\*(S[1-9][0-9]*)\*\*(?: (.*))?$")
# 정규형(NFKC · Cf 제거)에서 줄 머리가 기호 · 공백 · 번호뿐이고 곧바로 `**S<n>**` 가 오는 줄 — 본문 한가운데
# 적힌 `**S<n>**` 는 앵커 꼴이 아니다. 번호는 유니코드 숫자도 꼴로 본다(문법 안인지는 위 정규식이 가른다).
_ANCHOR_SHAPED = re.compile(r"^(?:[^\w\n]|\d+[.)])*\*\*S\d+\*\*")
# 거부 사유 이름 → 사람이 읽는 말. 메시지는 이 말을 앞세우고 사유 이름은 괄호에 둔다.
ANCHOR_REASON_TEXT = {
    "anchor_indented": "들여 쓴 앵커 줄",
    "anchor_unicode_space": "공백 · 탭이 아닌 공백 글자(NBSP · 전각 공백 등)로 시작하는 앵커 줄",
    "anchor_star_bullet": "`*` 불릿 앵커 줄",
    "anchor_shape": "모양이 다른 앵커 줄",
    "anchor_confusable": "보이지 않는 글자나 전각 글자로 앵커처럼 꾸민 줄",
    "anchor_line_separator": "한 줄 안에 줄 나눔 글자가 있어 읽는 쪽마다 앵커 줄 수가 달라지는 줄",
}
_OPEN_BRACKETS = set("<\u2039\u27e8\u3008")
_CLOSE_BRACKETS = set(">\u203a\u27e9\u3009")
_REF_RE = re.compile(r"(.)S(\d+)(.)")
# 펜스 정규식은 여기가 소유한다(`check_brief.FENCE_RE` 가 이것을 쓴다).
FENCE_RE = re.compile(r"^[ \t]*```.*?^[ \t]*```[^\n]*$", re.DOTALL | re.MULTILINE)
_BULLET_HEAD_RE = re.compile(r"^[-*]\s")
ENTRY_BULLET_RE = re.compile(r"^\s*[-*]\s")
_NUMBERED_RE = re.compile(r"^\s*\d+[.)]\s")
_QUOTED_RE = re.compile(r"^\s*>")
# 결정 표지는 해결 · 열림 표시(`[해결` · `[열림`)다 — 줄 머리에 있거나, 줄 머리의 `OQ<n>` 뒤에 따라온다. OQ 번호만 부르는
# 산문(`(OQ1~OQ7 은 …`)이나 설명 줄 가운데 적힌 표지 글자는 결정 줄이 아니다.
_DECISION_HEAD_RE = re.compile(r"^[^\w\[\n]*(?:\d+[.)]\s*)?[^\w\[\n]*(OQ\d|\[해결|\[열림\])")
_RESOLUTION_MARK_RE = re.compile(r"\[해결|\[열림")


def _is_decision_line(c):
    m = _DECISION_HEAD_RE.match(c)
    return bool(m) and (not m.group(1).startswith("OQ") or bool(_RESOLUTION_MARK_RE.search(c)))


def canon(text):
    """판독용 정규형 — NFKC 로 접고 서식 글자(Cf)를 지운다. 분류는 이 모양 위에서 한다."""
    return "".join(c for c in unicodedata.normalize("NFKC", text) if unicodedata.category(c) != "Cf")


def split_lines(text, keepends=False):
    """줄 나눔은 `\n` 하나다 — 모든 판독기가 이 함수로 자른다(`str.splitlines()` 는 다른 글자에서도 자른다)."""
    parts = text.split("\n")
    if not keepends:
        return parts
    return [p + "\n" for p in parts[:-1]] + ([parts[-1]] if parts[-1] else [])


def _lead_ws_reason(line):
    i = 0
    while i < len(line) and line[i].isspace():
        i += 1
    if i == 0:
        return None
    return "anchor_indented" if set(line[:i]) <= {" ", "\t"} else "anchor_unicode_space"


def anchor_lines(section_text):
    """-> (문법 안 앵커 [(줄 번호, sid, 본문)], 거부 줄 [(줄 번호, 사유)]). 줄 번호는 1부터."""
    ok, bad = [], []
    for n, line in enumerate(split_lines(section_text), 1):
        parts = line.splitlines()
        if len(parts) > 1 and any(_ANCHOR_SHAPED.match(canon(p)) for p in parts):
            bad.append((n, "anchor_line_separator"))
            continue
        if not _ANCHOR_SHAPED.match(canon(line)):
            continue
        m = ANCHOR_LINE_RE.match(line)
        if m:
            ok.append((n, m.group(1), m.group(2) or ""))
            continue
        why = _lead_ws_reason(line)
        if why is None:
            if line.startswith("* **S"):
                why = "anchor_star_bullet"
            elif canon(line) != line:
                why = "anchor_confusable"
            else:
                why = "anchor_shape"
        bad.append((n, why))
    return ok, bad


def anchor_items(section_text):
    """-> (항목 [(sid, 머리 본문, [뒤따르는 줄])], 거부 줄). 항목은 문법 안 앵커 줄에서 열려 다음 앵커 줄 앞에서 닫힌다."""
    ok, bad = anchor_lines(section_text)
    lines = split_lines(section_text)
    starts = {n: (sid, rest) for n, sid, rest in ok}
    items, cur = [], None
    for n, line in enumerate(lines, 1):
        if n in starts:
            cur = (starts[n][0], starts[n][1], [])
            items.append(cur)
        elif cur is not None:
            cur[2].append(line)
    return items, bad


def decision_line_problem(line):
    """§0 · §3 한 줄의 결정 줄 판독 — 정규형이 결정 표지(선두 `OQ<n>` · `[해결` · `[열림]`)를 담았는데 열 0 불릿
    항목 줄(`_entry_lines` 가 받는 줄)이 아니면 사유 이름을 낸다. 번호 목록 · 인용은 이름을 유지하고 그 밖은
    `decision_shape`. 문제가 없으면 None."""
    c = canon(line)
    if not _is_decision_line(c):
        return None
    if ENTRY_BULLET_RE.match(c) and c.strip() not in ("-", "*"):
        return None
    if _NUMBERED_RE.match(c):
        return "decision_numbered"
    if _QUOTED_RE.match(c):
        return "decision_quoted"
    return "decision_shape"


def open_line_s_refs(section_text):
    """§0 · §3 원문(펜스 포함)의 정규형에서 괄호 쌍(유니코드 Ps/Pe · `< >` · `‹ ›` · `⟨ ⟩` · `〈 〉`) 바로 안의
    `S<번호>` 를 위치와 무관하게 전부 뽑는다. 번호 철자는 그대로 낸다(풀리는지는 부르는 쪽이 앵커 집합과 대조한다)."""
    out = []
    for m in _REF_RE.finditer(canon(section_text)):
        o, ident, c = m.group(1), m.group(2), m.group(3)
        opens = unicodedata.category(o) == "Ps" or o in _OPEN_BRACKETS
        closes = unicodedata.category(c) == "Pe" or c in _CLOSE_BRACKETS
        if opens and closes:
            out.append("S" + ident)
    return out


def section4_items(section_text):
    """§4 항목 — (첫 줄, 본문 줄들). 펜스 안은 항목이 아니다. 열 0 의 불릿 줄이 항목이고, 그 뒤 들여 쓴 줄
    (첫 글자가 공백류 — 공백 · 탭 · NBSP · 전각 공백)은 그 항목의 본문이다. 빈 줄은 항목을 닫지 않는다. 열 0 의
    불릿이 아닌 줄은 항목을 닫는다. 항목이 열리기 전에 나온 들여 쓴 불릿은 그 자체로 항목이다."""
    out = []
    cur = None
    for ln in FENCE_RE.sub("", section_text).splitlines():
        if not ln.strip():
            continue
        if _BULLET_HEAD_RE.match(ln) and ln.strip() not in ("-", "*"):
            cur = (ln.strip(), [])
            out.append(cur)
        elif ln[:1].isspace():
            if cur is None:
                if ENTRY_BULLET_RE.match(ln) and ln.strip() not in ("-", "*"):
                    cur = (ln.strip(), [])
                    out.append(cur)
            else:
                cur[1].append(ln.strip())
        else:
            cur = None
    return out
