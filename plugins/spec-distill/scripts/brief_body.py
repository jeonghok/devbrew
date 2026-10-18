#!/usr/bin/env python3
# -*- coding: utf-8 -*-
r"""brief_body.py — brief 를 읽는 허용 문법 하나: 줄 나눔 · 정규형 · 절 경계 · §6 앵커 줄 · 결정 줄 · 원문 번호 참조 · §4 항목.

`check_brief` · `check_verbatim_coverage` · `roadmap_model` · `roadmap_render` 가 함께 쓴다 — 판독기마다 같은 줄을 다르게
읽는 틈을 없앤다(`seed_body.py` 방식). 줄은 `split_lines` 로만 자르고, 분류는 정규형(`canon` · `fold`) 위에서 한다.
정규형으로는 구조(앵커 · 결정 줄 · 목록 머리)처럼 보이는데 날 글자로는 문법 밖인 줄은 사유 이름과 함께 거부한다.
표준 라이브러리만 쓰고 파일을 읽지 않는다.
"""
from __future__ import annotations

import re
import unicodedata

# ── 정규형 ────────────────────────────────────────────────────────────────────
# Default_Ignorable_Code_Point — Unicode DerivedCoreProperties.txt 의 그 속성 범위(예약 자리 포함). 화면에 안 보이므로
# 판독 전에 지운다. 서식 글자(Cf)는 이 목록 밖의 것도 함께 지운다.
DEFAULT_IGNORABLE_RANGES = (
    (0x00AD, 0x00AD), (0x034F, 0x034F), (0x061C, 0x061C), (0x115F, 0x1160), (0x17B4, 0x17B5),
    (0x180B, 0x180F), (0x200B, 0x200F), (0x202A, 0x202E), (0x2060, 0x206F), (0x3164, 0x3164),
    (0xFE00, 0xFE0F), (0xFEFF, 0xFEFF), (0xFFA0, 0xFFA0), (0xFFF0, 0xFFF8), (0x1BCA0, 0x1BCA3),
    (0x1D173, 0x1D17A), (0xE0000, 0xE0FFF),
)
# UTS #39 confusables.txt 에서 대상(prototype)이 구조 글자 `S`(U+0053)이고 NFKC 가 접지 않는 글자 — 아르메니아 ·
# 키릴 · 체로키 · 리수 · 리키아 · 데저렛 문자. 숫자는 표 대신 유니코드 십진 숫자 값으로 접는다(`fold`).
S_CONFUSABLES = (0x0405, 0x054F, 0x13D5, 0x13DA, 0xA4E2, 0x10296, 0x10420)


def _ignorable(c):
    o = ord(c)
    if o < 0xAD:
        return False
    return unicodedata.category(c) == "Cf" or any(a <= o <= b for a, b in DEFAULT_IGNORABLE_RANGES)


def _drop_ignorable(text):
    return "".join(c for c in text if not _ignorable(c))


def canon(text):
    """판독용 정규형 — 보이지 않는 글자(Default_Ignorable · Cf)를 지우고 NFKC 로 접는다. 분류는 이 모양 위에서 한다."""
    return _drop_ignorable(unicodedata.normalize("NFKC", _drop_ignorable(text)))


def _fold_char(c):
    if ord(c) in S_CONFUSABLES:
        return "S"
    if ord(c) > 0x7F:
        d = unicodedata.decimal(c, None)
        if d is not None:
            return str(d)
    return c


def fold(text):
    """`canon` 위에 구조 글자를 한 번 더 접는다 — `S` 를 흉내 내는 다른 문자 체계의 글자는 `S` 로, 다른 문자 체계의
    십진 숫자는 ASCII 숫자로. 앵커 꼴 · 원문 번호 참조를 찾을 때만 쓴다."""
    return "".join(_fold_char(c) for c in canon(text))


# ── 줄 나눔 · 절 ──────────────────────────────────────────────────────────────

def split_lines(text, keepends=False):
    r"""줄 나눔은 `\n` 하나다 — brief 를 읽는 판독기는 전부(§0~§5 항목 · 결정 줄 · §4 항목 · §6 앵커 줄) 이 함수로
    자른다. `str.splitlines()` 가 자르는 다른 글자(`\r` · `\v` · `\f` · `\x1c`~`\x1e` · `\x85` · U+2028 · U+2029)는 줄 안에
    남는다 — 그 조각 하나라도 목록 머리 · 결정 줄 · 앵커 줄처럼 보이면 그 줄은 `*_line_separator` 로 거부된다
    (`entry_lines` · `decision_line_problem` · `anchor_lines`)."""
    parts = text.split("\n")
    if not keepends:
        return parts
    return [p + "\n" for p in parts[:-1]] + ([parts[-1]] if parts[-1] else [])


FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)
# 펜스 정규식은 여기가 소유한다(`check_brief.FENCE_RE` 가 이것을 쓴다).
FENCE_RE = re.compile(r"^[ \t]*```.*?^[ \t]*```[^\n]*$", re.DOTALL | re.MULTILINE)


def body_text(text):
    """frontmatter 와 펜스를 벗긴 본문 — 게이트의 존재 검사 코퍼스(`check_brief._body`)."""
    m = FRONTMATTER_RE.match(text)
    body = text[m.end():] if m else text
    return FENCE_RE.sub("", body)


def section_text(text, num, title=None):
    """게이트의 절 경계 — `## <num>. <title>` 다음부터 다음 `## <숫자>.` 앞까지(펜스는 벗긴 본문 위). 제목을 주지 않으면
    번호만 본다. 절 안의 다른 `## ` 소제목은 절을 끊지 않는다. 없으면 빈 문자열."""
    body = body_text(text)
    head = (rf"^##\s+{re.escape(num)}\.\s+{re.escape(title)}\b" if title else rf"^##\s+{re.escape(num)}\.")
    start = re.search(head, body, re.MULTILINE | re.IGNORECASE)
    if not start:
        return ""
    rest = body[start.end():]
    nxt = re.search(r"^##\s+\d+\.", rest, re.MULTILINE)
    return rest[: nxt.start()] if nxt else rest


# ── §6 앵커 줄 ────────────────────────────────────────────────────────────────
# 허용 문법 — 열 0 의 `- ` 하나 + `**S<n>**`(번호는 ASCII 숫자 · 앞자리 0 없음) + (공백 하나 + 본문). 그 밖은 앵커가 아니다.
ANCHOR_LINE_RE = re.compile(r"^- \*\*(S[1-9][0-9]*)\*\*(?: (.*))?$")
# 접은 모양(`fold`)에서 줄 머리가 기호 · 공백 · 번호뿐이고 곧바로 `**S<n>**` 가 오는 줄 — 앵커 꼴.
_ANCHOR_SHAPED = re.compile(r"^(?:[^\w\n]|\d+[.)])*\*\*S\d+\*\*")
# 앵커가 아닌 줄(이음 줄 · 앵커 앞 줄 · 앵커 줄의 본문)에 있으면 안 되는 것 — 앵커 꼴 토큰 · S 번호를 단 목록 머리.
_IN_BODY_TOKEN = re.compile(r"\*\*S\d+\*\*|__S\d+__")
_IN_BODY_BULLET = re.compile(r"^(?:[^\w\n]|\d+[.)])*?(?:[-*+]|\d+[.)])\s+[*_`]*S\d+(?![0-9])")
# 거부 사유 이름 → 사람이 읽는 말. 메시지는 이 말을 앞세우고 사유 이름은 괄호에 둔다.
ANCHOR_REASON_TEXT = {
    "anchor_indented": "들여 쓴 앵커 줄",
    "anchor_unicode_space": "공백 · 탭이 아닌 공백 글자(NBSP · 전각 공백 등)로 시작하는 앵커 줄",
    "anchor_star_bullet": "`*` 불릿 앵커 줄",
    "anchor_shape": "모양이 다른 앵커 줄",
    "anchor_confusable": "보이지 않는 글자나 닮은 글자로 앵커처럼 꾸민 줄",
    "anchor_line_separator": "한 줄 안에 줄 나눔 글자가 있어 읽는 쪽마다 앵커 줄 수가 달라지는 줄",
    "anchor_in_body": "앵커가 아닌 줄에 앵커처럼 보이는 글(`**S<n>**` 또는 S 번호를 단 목록 머리)이 있는 줄",
}


def _lead_ws_reason(line):
    i = 0
    while i < len(line) and line[i].isspace():
        i += 1
    if i == 0:
        return None
    return "anchor_indented" if set(line[:i]) <= {" ", "\t"} else "anchor_unicode_space"


def _in_body(f):
    return bool(_IN_BODY_TOKEN.search(f) or _IN_BODY_BULLET.match(f))


def anchor_lines(section_text):
    """§6 본문의 바이트 전부를 센다 -> (문법 안 앵커 [(줄 번호, sid, 본문)], 거부 줄 [(줄 번호, 사유)]). 줄 번호는 1부터.

    앵커 꼴(접은 모양의 줄 머리가 `**S<n>**`)인데 날 글자가 문법 밖이면 그 모양의 사유로 거부한다. 앵커가 아닌 줄과
    앵커 줄의 본문에 앵커 꼴 토큰이나 S 번호를 단 목록 머리가 있으면 `anchor_in_body` 다 — 하류가 그것을 사용자
    발화의 앵커로 읽는다(Ruling S13 대체 규칙: 실제 brief 의 §6 은 출처 표기 · 앵커 앞 설명 · 따옴표 같은 원문 밖 글을
    싣고 있어 본문을 원장 글자와 같게 강제하지 않는다)."""
    ok, bad = [], []
    for n, line in enumerate(split_lines(section_text), 1):
        parts = line.splitlines()
        if len(parts) > 1 and any(_ANCHOR_SHAPED.match(fold(p)) or _in_body(fold(p)) for p in parts):
            bad.append((n, "anchor_line_separator"))
            continue
        f = fold(line)
        if not _ANCHOR_SHAPED.match(f):
            if _in_body(f):
                bad.append((n, "anchor_in_body"))
            continue
        m = ANCHOR_LINE_RE.match(line)
        if m:
            ok.append((n, m.group(1), m.group(2) or ""))
            if _IN_BODY_TOKEN.search(fold(m.group(2) or "")):
                bad.append((n, "anchor_in_body"))
            continue
        why = _lead_ws_reason(line)
        if why is None:
            if line.startswith("* **S"):
                why = "anchor_star_bullet"
            elif f != line:
                why = "anchor_confusable"
            else:
                why = "anchor_shape"
        bad.append((n, why))
    return ok, bad


def anchor_items(section_text):
    """-> (항목 [(sid, 머리 본문, [뒤따르는 줄])], 거부 줄). 항목은 문법 안 앵커 줄에서 열려 다음 앵커 줄 앞에서 닫힌다."""
    ok, bad = anchor_lines(section_text)
    starts = {n: (sid, rest) for n, sid, rest in ok}
    items, cur = [], None
    for n, line in enumerate(split_lines(section_text), 1):
        if n in starts:
            cur = (starts[n][0], starts[n][1], [])
            items.append(cur)
        elif cur is not None:
            cur[2].append(line)
    return items, bad


# ── 항목 줄 · 결정 줄 ─────────────────────────────────────────────────────────
ENTRY_BULLET_RE = re.compile(r"^\s*[-*]\s")
_COL0_BULLET_RE = re.compile(r"^[-*][ \t]")
_LIST_HEAD_RE = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s")
_NUMBERED_RE = re.compile(r"^\s*\d+[.)]\s")
_QUOTED_RE = re.compile(r"^\s*>")
# 결정 꼴 (가) — 줄 머리(공백 · 번호 · 인용 · 기호 같은 불릿 아닌 앞붙이 뒤)가 `OQ<n>` 이고 그 뒤(강조 표시 건너)에 `:` 또는 `[`.
_DECISION_HEAD_RE = re.compile(r"^(?:[\W\d_]|\w{1,3}[.)])*?[*_`]*OQ\d+[*_`]*\s*[:\[]")
# 결정 꼴 (나) — 코드 칸(백틱) 밖에 해결 · 열림 표시가 있다.
_DECISION_MARK_RE = re.compile(r"\[해결|\[열림")
_CODE_SPAN_RE = re.compile(r"(`+).*?\1")
# 선두 결정 번호 — 불릿을 뗀 본문이 (강조 표시를 사이에 두고도) `OQ<n>` 로 시작할 때 그 번호(`check_brief.LEADING_OQ_RE`).
LEADING_OQ_RE = re.compile(r"^[*_`]*\s*(OQ\d+)(?!_*[0-9A-Za-z])")
_BULLET_PREFIX_RE = re.compile(r"^\s*[-*]\s+")
DECISION_REASON_TEXT = {
    "decision_numbered": "번호 목록으로 쓴 결정 줄",
    "decision_quoted": "인용(`>`)으로 쓴 결정 줄",
    "decision_shape": "열 0 의 `- ` 불릿이 아닌 결정 줄",
    "decision_confusable": "보이지 않는 글자나 닮은 글자로 머리를 꾸민 결정 줄",
    "decision_line_separator": "한 줄 안에 줄 나눔 글자가 있어 읽는 쪽마다 항목 수가 달라지는 줄",
    "entry_line_separator": "한 줄 안에 줄 나눔 글자가 있어 읽는 쪽마다 항목 수가 달라지는 줄",
}


def _decision_head_end(c):
    m = _DECISION_HEAD_RE.match(c)
    if m:
        return m.end()
    mk = _DECISION_MARK_RE.search(_CODE_SPAN_RE.sub(lambda s: " " * len(s.group(0)), c))
    return mk.end() if mk else None


def _structural(part):
    f = fold(part)
    return bool(_LIST_HEAD_RE.match(f) or _decision_head_end(f) is not None or _ANCHOR_SHAPED.match(f))


def _separator_problem(line):
    parts = line.splitlines()
    return len(parts) > 1 and any(_structural(p) for p in parts)


def decision_line_problem(line):
    """§0 · §3 한 줄의 결정 줄 판독 -> 사유 이름 또는 None.

    정규형이 결정 꼴((가) 머리가 `OQ<n>` + `:`/`[` · (나) 코드 칸 밖 `[해결` · `[열림`)인데, 날 글자가 열 0 의 `- ` · `* `
    불릿이 아니거나 정규형 머리가 날 머리와 다르면 거부한다 — 번호 목록 · 인용은 그 이름, 정규형으로만 불릿이면
    `decision_confusable`, 그 밖은 `decision_shape`. 줄 안에 다른 줄 나눔 글자가 있고 그 조각이 구조처럼 보이면
    `decision_line_separator`."""
    if _separator_problem(line):
        return "decision_line_separator"
    c = canon(line)
    end = _decision_head_end(c)
    if end is None:
        return None
    if _COL0_BULLET_RE.match(line) and line.startswith(c[:end]):
        return None
    if _COL0_BULLET_RE.match(c):
        return "decision_confusable"
    if _NUMBERED_RE.match(c):
        return "decision_numbered"
    if _QUOTED_RE.match(c):
        return "decision_quoted"
    return "decision_shape"


def _entries(section_text, decisions, sep_reason):
    acc, rej = [], []
    for n, ln in enumerate(split_lines(section_text), 1):
        if _separator_problem(ln):
            rej.append((n, "decision_line_separator" if decisions else sep_reason))
        elif decisions:
            why = decision_line_problem(ln)
            if why:
                rej.append((n, why))
        if ENTRY_BULLET_RE.match(ln) and ln.strip() not in ("-", "*"):
            acc.append((n, ln))
    return acc, rej


def entry_lines(section_text, decisions=False, sep_reason="entry_line_separator"):
    """절 본문의 항목 줄 -> (받은 항목 [줄.strip()], 거부 [(줄 번호, 사유)]). 항목은 불릿(`-` · `*`) 줄이다.
    `decisions=True`(§0 · §3)면 결정 줄 판독(`decision_line_problem`)의 거부를 함께 낸다."""
    acc, rej = _entries(section_text, decisions, sep_reason)
    return [ln.strip() for _n, ln in acc], rej


def decision_entries(section_text):
    """§0 · §3 본문 -> (결정 항목 [(선두 OQ 또는 None, 날 줄)], 거부 [(줄 번호, 사유)]). 선두 번호는 불릿을 뗀 정규형에서
    읽는다 — 게이트(`check_brief`)와 로드맵(`roadmap_model` · `roadmap_render`)이 같은 번호를 센다."""
    acc, rej = _entries(section_text, True, "decision_line_separator")
    out = []
    for _n, ln in acc:
        m = LEADING_OQ_RE.match(canon(_BULLET_PREFIX_RE.sub("", ln, count=1)).strip())
        out.append((m.group(1) if m else None, ln))
    return out, rej


# ── 원문 번호 참조 ─────────────────────────────────────────────────────────────
# `check_brief.ANCHOR_RE` 관례 — 앞이 ASCII 영숫자가 아닌 `S<숫자>`. 자리 표시 `S<n>` 은 숫자가 아니라 잡히지 않는다.
_REF_TOKEN_RE = re.compile(r"(?<![A-Za-z0-9])S([0-9]+)(?![0-9])")


def open_line_s_refs(text):
    """글 전체의 원문 번호 참조 — 접은 모양(`fold`)에서 `S<숫자>` 토큰을 위치 · 괄호와 무관하게 전부 뽑는다. 번호 철자는
    그대로 낸다(풀리는지는 부르는 쪽이 §6 앵커 집합과 대조한다)."""
    return ["S" + d for d in _REF_TOKEN_RE.findall(fold(text))]


# ── §4 항목 ──────────────────────────────────────────────────────────────────

def section4_items(section_text):
    """§4 항목 — (첫 줄, 본문 줄들). 펜스 안은 항목이 아니다. 열 0 의 불릿 줄이 항목이고, 그 뒤 들여 쓴 줄
    (첫 글자가 공백류 — 공백 · 탭 · NBSP · 전각 공백)은 그 항목의 본문이다. 빈 줄은 항목을 닫지 않는다. 열 0 의
    불릿이 아닌 줄은 항목을 닫는다. 항목이 열리기 전에 나온 들여 쓴 불릿은 그 자체로 항목이다."""
    out = []
    cur = None
    for ln in split_lines(FENCE_RE.sub("", section_text)):
        if not ln.strip():
            continue
        if re.match(r"^[-*]\s", ln) and ln.strip() not in ("-", "*"):
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
