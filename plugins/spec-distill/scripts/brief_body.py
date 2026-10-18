#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""brief_body.py — brief 의 §6 앵커 줄 · 결정 줄 머리 · §3 열린 줄 참조 · §4 항목을 읽는 허용 문법 하나.

`check_brief` · `check_verbatim_coverage` · `roadmap_model` 이 함께 쓴다 — 판독기 셋이 같은 줄을 다르게 읽는
틈을 없앤다(`seed_body.py` 방식). 문법 밖 줄은 사유 이름과 함께 거부한다. 표준 라이브러리만 쓰고 파일을
읽지 않는다.
"""
from __future__ import annotations

import re

# §6 앵커 줄의 허용 문법 — 열 0 의 `- ` 하나 + `**S<n>**` + (공백 하나 + 본문). 그 밖은 앵커가 아니다.
ANCHOR_LINE_RE = re.compile(r"^- \*\*(S\d+)\*\*(?: (.*))?$")
# 줄 머리가 기호 · 공백 · 번호뿐이고 곧바로 `**S<n>**` 가 오는 줄 — 본문 한가운데 적힌 `**S<n>**` 는 앵커 꼴이 아니다.
_ANCHOR_SHAPED = re.compile(r"^(?:[^\w\n]|\d+[.)])*\*\*S\d+\*\*")
# 거부 사유 이름 → 사람이 읽는 말. 메시지는 이 말을 앞세우고 사유 이름은 괄호에 둔다.
ANCHOR_REASON_TEXT = {
    "anchor_indented": "들여 쓴 앵커 줄",
    "anchor_unicode_space": "공백 · 탭이 아닌 공백 글자(NBSP · 전각 공백 등)로 시작하는 앵커 줄",
    "anchor_star_bullet": "`*` 불릿 앵커 줄",
    "anchor_shape": "모양이 다른 앵커 줄",
}
_S_REF_RE = re.compile(r"⟨(S\d+)⟩")
_FENCE_BLOCK_RE = re.compile(r"^[ \t]*```.*?^[ \t]*```[^\n]*$", re.DOTALL | re.MULTILINE)
_BULLET_HEAD_RE = re.compile(r"^[-*]\s")
_ANY_BULLET_RE = re.compile(r"^\s*[-*]\s")
_NUMBERED_RE = re.compile(r"^\s*\d+[.)]\s")
_QUOTED_RE = re.compile(r"^\s*>")


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
    for n, line in enumerate(section_text.split("\n"), 1):
        if not _ANCHOR_SHAPED.match(line):
            continue
        m = ANCHOR_LINE_RE.match(line)
        if m:
            ok.append((n, m.group(1), m.group(2) or ""))
            continue
        why = _lead_ws_reason(line)
        if why is None:
            why = "anchor_star_bullet" if line.startswith("* **S") else "anchor_shape"
        bad.append((n, why))
    return ok, bad


def decision_line_problem(line):
    """결정 줄 머리 판독 — 번호 목록 · 인용 꼴이면 사유 이름, 아니면 None."""
    if _NUMBERED_RE.match(line):
        return "decision_numbered"
    if _QUOTED_RE.match(line):
        return "decision_quoted"
    return None


def open_line_s_refs(section3_text):
    """§3 산문 전체의 `⟨S<n>⟩` 를 위치와 무관하게 전부 뽑는다."""
    return _S_REF_RE.findall(section3_text)


def section4_items(section_text):
    """§4 항목 — (첫 줄, 본문 줄들). 펜스 안은 항목이 아니다. 열 0 의 불릿 줄이 항목이고, 그 뒤 들여 쓴 줄
    (첫 글자가 공백류 — 공백 · 탭 · NBSP · 전각 공백)은 그 항목의 본문이다. 빈 줄은 항목을 닫지 않는다. 열 0 의
    불릿이 아닌 줄은 항목을 닫는다. 항목이 열리기 전에 나온 들여 쓴 불릿은 그 자체로 항목이다."""
    out = []
    cur = None
    for ln in _FENCE_BLOCK_RE.sub("", section_text).splitlines():
        if not ln.strip():
            continue
        if _BULLET_HEAD_RE.match(ln) and ln.strip() not in ("-", "*"):
            cur = (ln.strip(), [])
            out.append(cur)
        elif ln[:1].isspace():
            if cur is None:
                if _ANY_BULLET_RE.match(ln) and ln.strip() not in ("-", "*"):
                    cur = (ln.strip(), [])
                    out.append(cur)
            else:
                cur[1].append(ln.strip())
        else:
            cur = None
    return out
