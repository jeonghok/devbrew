#!/usr/bin/env python3
# -*- coding: utf-8 -*-
r"""brief_body.py — brief 를 읽는 허용 문법 하나: 줄 나눔 · 정규형 · 절 경계 · §6 앵커 줄 · 결정 줄 · 원문 번호 참조 · §4 항목.

`check_brief` · `check_verbatim_coverage` · `roadmap_model` · `roadmap_render` 가 함께 쓴다 — 판독기마다 같은 줄을 다르게
읽는 틈을 없앤다(`seed_body.py` 방식). 줄은 `split_lines` 로만 자르고, 분류는 정규형(`canon` · `fold`) 위에서 한다.
정규형으로는 구조(앵커 · 결정 줄 · 목록 머리)처럼 보이는데 날 글자로는 문법 밖인 줄은 사유 이름과 함께 거부한다.
표준 라이브러리와 같은 폴더의 `section6` 만 쓰고 파일을 읽지 않는다.
"""
from __future__ import annotations

import functools
import html
import re
import unicodedata

import section6  # 같은 scripts 폴더 — 표준 라이브러리만 쓰는 §6 경계 모듈

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
# 키릴 · 체로키 · 리수 · 리키아 · 데저렛 문자. 숫자 닮은꼴은 표로 쫓지 않는다 — `S` 바로 뒤의 비ASCII 숫자 · 글자는
# `ref_confusables` 가 거부하고, §6 의 강조 머리는 `anchor_lines` 가 거부한다(Ruling S13-a).
S_CONFUSABLES = (0x0405, 0x054F, 0x10BD, 0x10FD, 0x13D5, 0x13DA, 0x1CBD, 0xA4E2, 0xA576, 0x10296, 0x10420, 0x16AD6,
                 0x16F3A, 0x1CCE8)
# 결정 번호 머리 `OQ<n>` 의 `O` · `Q` 를 흉내 내는 글자 — 같은 confusables.txt 에서 대상이 `O`(U+004F) · `Q`(U+0051)이고 NFKC 가
# 접지 않는 글자. `S` 표와 별개로 둔다 — 쓰는 곳이 다르다. 세 표(S · O · Q)는 UTS #39 confusables.txt(Version 18.0.0,
# Date 2026-08-06)에서 파서로 뽑았다: 원천이 ASCII 가 아니고, NFKC 가 이미 대상으로 접거나 이미 표에 있는 글자로 접는 글자와
# 숫자(Nd)는 뺐다(숫자는 접지 않는다). 숫자 여부는 실행하는 파이썬의 유니코드 자료로 판정하므로, 더 새 자료에서는 표를 같은 규칙으로
# 다시 뽑아야 한다.
O_CONFUSABLES = (0x039F, 0x041E, 0x0555, 0x0B20, 0x12D0, 0x1CBF, 0x2C9E, 0x2D54, 0x3007, 0xA4F3, 0x10292, 0x102AB,
                 0x1030F, 0x10404, 0x104C2, 0x10516, 0x10C17, 0x118B5, 0x16AE9, 0x1CCE4)
Q_CONFUSABLES = (0x051A, 0x2D55, 0x1CCE6)
# 마크다운 구조 글자(`*` 강조 · 불릿, `-` 불릿)를 흉내 내는 글자 — NFKC 가 접지 않는 별표 · 빼기 · 하이픈 · 대시.
STRUCT_LOOKALIKES = {
    0x2217: "*", 0x2731: "*", 0x204E: "*", 0x066D: "*", 0x2732: "*",
    0x2212: "-", 0x2010: "-", 0x2011: "-", 0x2012: "-", 0x2013: "-", 0x2014: "-", 0x2015: "-",
    0xFE63: "-", 0xFE58: "-", 0x2043: "-",
}
# brief 절 번호와 제목 — 게이트 · 로드맵이 같은 표로 절을 찾는다(제목 붙은 경계).
SECTIONS = (("0", "한눈에"), ("1", "Goal · Non-goal"), ("2", "제약"), ("3", "Open Questions"),
            ("4", "External Landscape"), ("5", "기각 · Blind Spots"), ("6", "사용자 원문"), ("7", "Next Action"))
SECTION_TITLES = dict(SECTIONS)


def _ignorable(c):
    o = ord(c)
    if o < 0xAD:
        return False
    return unicodedata.category(c) == "Cf" or any(a <= o <= b for a, b in DEFAULT_IGNORABLE_RANGES)


def _drop_ignorable(text):
    return "".join(c for c in text if not _ignorable(c))


def has_ignorable(text):
    """보이지 않는 글자(Default_Ignorable · Cf)가 하나라도 있는가."""
    return any(_ignorable(c) for c in text)


@functools.lru_cache(maxsize=65536)   # 같은 brief 를 여러 판독기가 줄마다 다시 읽는다
def canon(text):
    """판독용 정규형 — 보이지 않는 글자(Default_Ignorable · Cf)를 지우고 NFKC 로 접는다. 분류는 이 모양 위에서 한다."""
    return _drop_ignorable(unicodedata.normalize("NFKC", _drop_ignorable(text)))


def _fold_char(c):
    o = ord(c)
    if o in S_CONFUSABLES:
        return "S"
    if o in O_CONFUSABLES:
        return "O"
    if o in Q_CONFUSABLES:
        return "Q"
    return STRUCT_LOOKALIKES.get(o, c)


@functools.lru_cache(maxsize=65536)
def fold(text):
    """`canon` 위에 구조 글자를 한 번 더 접는다 — `S` 를 흉내 내는 다른 문자 체계의 글자는 `S` 로, 별표 · 하이픈을
    흉내 내는 글자는 `*` · `-` 로. 숫자는 접지 않는다(닮은 숫자를 다른 번호로 풀지 않는다). 앵커 꼴 · 원문 번호 참조를
    찾을 때만 쓴다. 결정 번호 머리의 `O` · `Q` 를 흉내 내는 글자도 접는다(`O_CONFUSABLES` · `Q_CONFUSABLES`)."""
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


FRONTMATTER_RE = section6.FRONTMATTER_RE
# 펜스 판독기는 `section6` 이 소유한다(`check_brief.FENCE_RE` 도 같은 객체).
FENCE_RE = section6.FENCE_RE


def body_text(text):
    """frontmatter 와 펜스를 벗긴 본문 — 게이트의 존재 검사 코퍼스(`check_brief._body`)."""
    m = FRONTMATTER_RE.match(text)
    body = text[m.end():] if m else text
    return FENCE_RE.sub("", body)


def _titled_head(num, title):
    # 한 줄만 읽는다 — `[ \t]` (`\s` 는 `##` 다음 줄의 `0. 한눈에` 를 같은 머리로 읽는다).
    return re.compile(rf"^##[ \t]+{re.escape(num)}\.[ \t]+{re.escape(title)}\b", re.MULTILINE | re.IGNORECASE)


# 절 머리 판독 하나 — 정규형 위에서, ASCII 숫자만, `## <n>.` 뒤가 숫자가 아니다(`## 0.1` 은 절 머리가 아니다). 절의 끝 ·
# 같은 번호 머리 수 · 절 밖 결정 판독이 모두 이 규칙을 쓴다.
# 머리 정규식은 `section6.py` 가 소유한다(§6 경계와 한 곳 — `test_check_brief.sh` §6단일화 락).
SECTION_HEAD_RE = section6.BRIEF_SECTION_HEAD_RE
# 절 번호처럼 보이는 머리 — `##` 뒤(공백 없어도) 숫자(다른 문자 체계의 숫자 포함)가 오면 모두 후보다.
_HEADLIKE_RE = section6.BRIEF_HEADLIKE_RE


def is_section_head(line):
    """이 줄이 절 머리인가(정규형 · ASCII 숫자) -> 그 번호 또는 None."""
    m = SECTION_HEAD_RE.match(canon(line))
    return m.group(1) if m else None


def section_text(text, num, title=None):
    """게이트의 절 경계 — `## <num>. <title>` 머리 줄 다음부터 다음 절 머리(`is_section_head`) 앞까지(펜스는 벗긴 본문 위).
    제목을 주지 않으면 brief 절 표(`SECTION_TITLES`)의 제목을 쓴다. `## 0.1` · `## 메모` 같은 소제목은 절을 끊지 않는다 —
    그 아래 글도 그 절로 읽혀 검사를 받는다. 없으면 빈 문자열. 같은 번호 머리 수는 `section_problem`, 표에 없는 머리는
    `head_problems` 가 판정한다."""
    body = body_text(text)
    start = _titled_head(num, title or SECTION_TITLES[num]).search(body)
    if not start:
        return ""
    eol = body.find("\n", start.end())
    rest = "" if eol < 0 else body[eol + 1:]   # 머리 줄의 나머지는 절 본문이 아니다
    out = []
    for ln in split_lines(rest, keepends=True):
        if is_section_head(ln) is not None:
            break
        out.append(ln)
    return "".join(out)


_SETEXT_UNDER_RE = re.compile(r"^( {0,3})(?:=+|-+)[ \t]*$")
_THEMATIC_RE = re.compile(r"^ {0,3}(?:(?:\*[ \t]*){3,}|(?:-[ \t]*){3,}|(?:_[ \t]*){3,})$")
_ATX_RE = section6.ATX_HEADING_RE   # 제목 머리 정규식은 section6 이 소유한다
_ITEM_RE = re.compile(r"^( {0,3})([-*+]|\d{1,9}[.)])([ \t]+|$)")
_QUOTE_RE = re.compile(r"^ {0,3}> ?")
_HTML_BLOCK_RE = re.compile(r"^ {0,3}<[A-Za-z/!?]")


def _cannot_interrupt(ln):
    """열린 문단을 끊지 못하는 목록 줄 — 내용이 없는 항목, 1 이 아닌 번호로 시작하는 번호 목록(CommonMark)."""
    m = _ITEM_RE.match(ln)
    num = m.group(2)
    if not ln[m.end():].strip():
        return True   # 내용이 없는 항목은 어떤 표지든 문단을 끊지 못한다
    return num[-1] in ".)" and num[:-1].lstrip("0") != "1"


def setext_problems(text):
    """setext 제목(글줄 아래 `===` · `---` 밑줄) -> [(글줄, `setext_heading`)]. 펜스 밖 어디서든 — 절 머리가 ATX(`## n. 제목`) 한
    꼴로만 있게 한다. CommonMark 를 따른다: 밑줄은 들여쓰기 0–3칸, 글줄은 문단 줄이다(빈 줄 · 목록 · 제목 · 인용 · HTML 블록이 아니다).
    목록 항목이나 인용 안의 문단은 그 컨테이너 안의 제목이거나(절 머리가 아니라 세지 않는다) 게으른 이음 줄 아래의 가로줄이다."""
    out = []
    lines = split_lines(body_text(text))
    para = None   # 문단이 열려 있으면 (컨테이너 종류, 컨테이너 들여쓰기 너비, 마지막 글줄)
    for ln in lines:
        if not ln.strip():
            para = None
            continue
        if para is not None:
            kind, width, last = para
            if kind == "quote":
                q = _QUOTE_RE.match(ln)
                inner = ln[q.end():] if q else None
            elif kind == "item" and ln[:width].strip() == "" and len(ln) - len(ln.lstrip(" ")) >= width:
                inner = ln[width:]
            elif kind == "top":
                inner = ln
            else:
                inner = None   # 컨테이너 밖에 놓인 줄 — 게으른 이음이거나 새 블록
            if inner is not None and _SETEXT_UNDER_RE.match(inner):
                if kind == "top":   # 인용 · 목록 안의 제목은 절 머리가 아니다 — 실제 brief 가 frontmatter 예시를 인용으로 싣는다
                    out.append((last, "setext_heading"))
                para = None
                continue
        if _THEMATIC_RE.match(ln) or _ATX_RE.match(ln) or _HTML_BLOCK_RE.match(ln):
            para = None
        elif _QUOTE_RE.match(ln):
            q = _QUOTE_RE.match(ln)
            rest = ln[q.end():]
            para = ("quote", 0, rest) if rest.strip() and not _ITEM_RE.match(rest) and not _ATX_RE.match(rest) else None
        elif _ITEM_RE.match(ln) and not (para is not None and _cannot_interrupt(ln)):
            m = _ITEM_RE.match(ln)
            rest = ln[m.end():]
            width = m.end() if rest.strip() else len(m.group(1)) + len(m.group(2)) + 1
            para = ("item", width, rest) if rest.strip() and not _ATX_RE.match(rest) else None
        elif para is not None:
            para = (para[0], para[1], ln)   # 이음 줄(게으른 이음 포함) — 컨테이너는 그대로
        elif len(ln) - len(ln.lstrip(" ")) <= 3:
            para = ("top", 0, ln)
        # 들여쓰기 4칸 이상이고 열린 문단이 없으면 코드 블록이다
    return out


_CHAR_REF_RE = re.compile(r"&[A-Za-z][A-Za-z0-9]*;|&#[0-9]+;|&#[xX][0-9A-Fa-f]+;")


def subset_problems(text):
    """부분집합 밖 구조 -> [(줄, 사유)] — brief 는 기계가 쓰는 마크다운의 부분집합이라 읽는 쪽이 모델하지 않는 것은 해석하지 않고
    거부한다: HTML 블록 시작 줄(`html_block_not_allowed`), HTML 문자 참조(`char_ref_not_allowed`, 코드 칸 안도 거부),
    들여 쓴 펜스 여는 줄(`fence_indented`)."""
    out = []
    for ln in split_lines(body_text(text)):
        c = canon(ln)
        if _HTML_BLOCK_RE.match(c):
            out.append((ln, "html_block_not_allowed"))
        if _CHAR_REF_RE.search(c):
            out.append((ln, "char_ref_not_allowed"))
    for ln in section6.indented_fence_openers(text):
        out.append((ln, "fence_indented"))
    return out


def audit_subset_problems(audit_text):
    """audit 전체(frontmatter 뒤)에 payload 와 같은 부분집합 규칙 -> [(줄, 사유)]. audit 본문도 같은 렌더러가 읽으므로 §6 앞 절의 열린
    HTML 블록 · 들여 쓴 펜스가 §6 머리의 상태를 바꿔 가짜 앵커를 그리지 못하게 한다."""
    return subset_problems(audit_text)


SUBSET_REASONS = ("html_block_not_allowed", "char_ref_not_allowed", "fence_indented")   # 절 머리가 아닌 부분집합 밖 구조


SECTION_REASON_TEXT = {
    "html_block_not_allowed": "HTML 블록으로 시작하는 줄이라 읽는 쪽마다 다른 구조로 읽힌다",
    "char_ref_not_allowed": "HTML 문자 참조(`&#83;` 같은 것)가 있어 렌더러만 다른 글자로 읽는다(코드 칸 안도 마찬가지다)",
    "fence_indented": "들여 쓴 코드 펜스라 목록 항목 안의 펜스로 읽는 쪽과 아닌 쪽이 갈린다",
    "setext_heading": "글줄 아래에 `===` 나 `---` 밑줄을 둔 제목(setext)이라 절 머리가 ATX 한 꼴로만 있다는 읽기가 깨진다",
    "section_missing": "제목 붙은 절 머리가 없다",
    "section_heading_duplicate": "같은 번호의 절 머리가 둘 이상이라 읽는 쪽마다 다른 절을 고를 수 있다",
    "section_head_unknown": "절 표에 없는 번호 머리(소번호 · 부록 · 전각 · 다른 문자 체계 숫자 등)라 어느 절로 읽을지 정해지지 않는다",
}


def head_problems(text):
    """펜스 밖 줄 중 절 번호처럼 보이는(정규형에서 `##` 뒤 숫자) 머리가 절 표의 제목 붙은 머리(날 글자) 하나가 아니면
    거부 -> [(그 줄, `section_head_unknown`)]. 부분집합 밖 구조(`subset_problems`)와 setext 제목도 같은 자리에서 낸다."""
    titled = [_titled_head(n, title) for n, title in SECTIONS]
    out = []
    for ln in split_lines(body_text(text)):
        if _HEADLIKE_RE.match(canon(ln)) and not any(rx.match(ln) for rx in titled):
            out.append((ln, "section_head_unknown"))
    return out + subset_problems(text) + setext_problems(text)


def section_problem(text, num, title=None):
    """절 경계가 하나로 정해지는가 -> None 또는 사유 이름. 펜스 밖 `## <num>.` 머리(제목 무관 · `## 4.1` 같은 다른 번호
    제외)가 둘 이상이면 `section_heading_duplicate`, 제목 붙은 머리가 없으면 `section_missing`."""
    body = body_text(text)
    if sum(1 for ln in split_lines(body) if is_section_head(ln) == num) > 1:
        return "section_heading_duplicate"
    if not _titled_head(num, title or SECTION_TITLES[num]).search(body):
        return "section_missing"
    return None


# ── §6 앵커 줄 ────────────────────────────────────────────────────────────────
# 허용 문법 — 열 0 의 `- ` 하나 + `**S<n>**`(번호는 ASCII 숫자 · 앞자리 0 없음) + (공백 하나 + 본문). 그 밖은 앵커가 아니다.
ANCHOR_LINE_RE = re.compile(r"^- \*\*(S[1-9][0-9]*)\*\*(?: (.*))?$")
# 접은 모양(`fold`)에서 줄 머리가 기호 · 공백 · 번호뿐이고 곧바로 `**S<n>**` 가 오는 줄 — 앵커 꼴.
_ANCHOR_SHAPED = re.compile(r"^(?:[^\w\n]|\d+[.)])*\*\*S\d+\*\*")
# 앵커가 아닌 줄(이음 줄 · 앵커 앞 줄 · 앵커 줄의 본문)에 있으면 안 되는 것 — 앵커 꼴 토큰 · S 번호를 단 목록 머리.
_IN_BODY_TOKEN = re.compile(r"\*\*S\d+\*\*|__S\d+__")
_IN_BODY_BULLET = re.compile(r"^(?:[^\w\n]|\d+[.)])*?(?:[-*+]|\d+[.)])\s+[*_`]*S\d+(?![0-9])")
# 열 0 의 줄 머리(불릿 하나는 건너)가 `S` 로 시작하는 강조(`**…**` · `__…__`) — 문법 안 앵커가 아니면 닮은 글자로 꾸민 앵커다.
_EMPH_S_HEAD = re.compile(r"^ {0,3}(?:[-*+]\s+)?(?:\*\*|__)S(?!\\?<|\ue000)")   # 자리 표시 `S<N>` · `S\<N\>`(템플릿)는 제외
# 모양 보기 — 앵커 꼴 판정에만 쓰는 접은 모양: 인라인 HTML 태그를 지우고 백슬래시 이스케이프를 푼다. 렌더러는 이 모양으로
# 앵커를 그리므로(`- <b>S9</b>` · `- *\\*S5*\\*`), 날 글자로는 문법 밖인데 이 모양으로 앵커처럼 읽히는 줄은 거부한다.
# CommonMark 의 인라인 원시 HTML 문법만 «태그»로 읽는다(여는 · 닫는 태그, 주석, 처리 명령, 선언, CDATA). 꺾쇠 안이 이 문법이
# 아니면(`<**S9**>`) 렌더러도 글자로 그리므로 지우지 않는다. 한 번에 훑어 선형이다.
_TAG_OPEN_RE = re.compile(r"</?[A-Za-z][A-Za-z0-9-]*(?:[ \t][^<>\n]*)?/?>|<![A-Za-z][^<>\n]*>")


_RAW_CLOSERS = (("<!--", "-->"), ("<?", "?>"), ("<![CDATA[", "]]>"))


def _strip_tags(text):
    out, i = [], 0
    gone = set()   # 닫는 표지가 더는 없는 종류 — 같은 종류의 뒤 여는 표지를 다시 찾지 않는다
    while True:
        j = text.find("<", i)
        if j < 0:
            break
        out.append(text[i:j])
        end = None
        for opener, closer in _RAW_CLOSERS:
            if text.startswith(opener, j):
                if opener not in gone:
                    k = text.find(closer, j + len(opener))
                    if k < 0:
                        gone.add(opener)
                    else:
                        end = k + len(closer)
                break
        else:
            m = _TAG_OPEN_RE.match(text, j)
            if m:
                end = m.end()
        if end is None:
            out.append("<")
            i = j + 1
        else:
            i = end
    out.append(text[i:])
    return "".join(out)


_ESCAPE_RE = re.compile(r"\\([!-/:-@\[-`{-~])")


# 템플릿 자리 표시 `S<N>` — 줄 전체가 아니라 그 토큰만 비킨다. 뒤에 (굵게 닫는 `**` · `__` 하나를 건너) 숫자(유니코드 Nd 전부)
# · `<` · `*` · `_` 가 오지 않을 때만이다(`**S<N>9**` · `S<N><i>` · `**S<N>**9` 는 렌더러가 다른 글을 그린다).
_PLACEHOLDER = re.compile(r"S\\?<[Nn]\\?>(?=(?:\*\*|__)?(?![\d<*_]))")
_PH_MARK = "\ue000"


def _shape_view(text):
    f = _PLACEHOLDER.sub("S" + _PH_MARK, html.unescape(fold(text)).translate({ord(_PH_MARK): None}))   # 문자 참조를 먼저 푼다
    return _ESCAPE_RE.sub(r"\1", html.unescape(_strip_tags(f)))


# 거부 사유 이름 → 사람이 읽는 말. 메시지는 이 말을 앞세우고 사유 이름은 괄호에 둔다.
ANCHOR_REASON_TEXT = {
    "char_ref_not_allowed": "HTML 문자 참조(`&#57;` 같은 것)가 있어 렌더러만 다른 글자로 읽는 줄",
    "html_block_not_allowed": "HTML 블록으로 시작하는 줄이라 뒤따르는 앵커 줄을 삼킬 수 있는 줄",
    "fence_indented": "들여 쓴 코드 펜스를 여는 줄이라 목록 항목 안의 펜스로 읽는 쪽과 아닌 쪽이 갈리는 줄",
    "autolink_backtick": "백틱이 든 자동 링크 꼴(`<…>`)이라 코드 칸 짝짓기가 렌더러마다 갈리는 줄",
    "code_span_unclosed": "한 줄 안에서 짝을 찾지 못한 백틱이 있어 다음 줄의 코드 칸 짝짓기를 밀어 버리는 줄",
    "html_inline_not_allowed": "인라인 HTML(`<태그>` · 주석 등)이 있어 렌더러만 다른 글을 그리는 줄(코드 칸 안은 제외)",
    "anchor_markup": "HTML 태그나 백슬래시 이스케이프로 꾸며 앵커처럼 읽히는 줄",
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


_ASCII_PUNCT = frozenset("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~")


def code_spans(line):
    """CommonMark 인라인 코드 칸 -> [(시작, 끝, 여는 백틱 수)]. 날 글자 위에서 왼쪽부터: 백슬래시 + ASCII 기호는 둘 다 글자이고,
    백틱 덩어리(최대 연속)는 뒤에서 **길이가 같은** 덩어리를 만나면 그 사이가 코드 칸이다. 짝이 없으면 그 덩어리는 글자다."""
    return _scan_code_spans(line)[0]


def unpaired_backtick_runs(line):
    """한 줄 안에서 짝을 못 찾은 백틱 덩어리 수 — CommonMark 코드 칸은 줄 바꿈을 건너 짝을 짓지만 이 판독은 줄마다 짝을 지으므로,
    짝 없는 덩어리가 있는 줄은 부분집합 밖이다(그 덩어리가 다음 줄의 짝짓기를 밀어 진짜 HTML 을 코드로 가린다)."""
    return _scan_code_spans(line)[1]


def _scan_code_spans(line):
    out, i, n = [], 0, len(line)
    unpaired = 0
    dead = set()   # 뒤에 같은 길이의 닫는 덩어리가 없는 길이
    while i < n:
        c = line[i]
        if c == "\\" and i + 1 < n and line[i + 1] in _ASCII_PUNCT:
            i += 2
            continue
        if c != "`":
            i += 1
            continue
        j = i
        while j < n and line[j] == "`":
            j += 1
        run = j - i
        close = None
        if run not in dead:
            k = j
            while k < n:
                if line[k] != "`":
                    k += 1
                    continue
                m = k
                while m < n and line[m] == "`":
                    m += 1
                if m - k == run:
                    close = m
                    break
                k = m
            if close is None:
                dead.add(run)
        if close is None:
            unpaired += 1
            i = j
        else:
            out.append((i, close, run))
            i = close
    return out, unpaired


def _literal_view(line):
    """코드 칸과 백슬래시로 이스케이프한 글자를 공백으로 지운 줄 — 남은 글자만 마크업으로 읽힌다."""
    chars = list(line)
    for a, b, _run in code_spans(line):
        chars[a:b] = " " * (b - a)
    i = 0
    while i + 1 < len(chars):
        if chars[i] == "\\" and chars[i + 1] in _ASCII_PUNCT:
            chars[i] = chars[i + 1] = " "
            i += 2
        else:
            i += 1
    return "".join(chars)


_INLINE_HTML_RE = re.compile(r"<(?=[A-Za-z/!?])")
# P21 치환 토큰(`<REDACTED:라벨>` 등) — spec-interview 가 비밀 값을 바꿔 적는 정본 형태다. 이름 뒤 `:` 때문에 HTML 태그가 아니다(마크다운
# 파서는 이 꼴을 URI 자동 링크로 읽지만 보이는 글자는 그대로다). 그래서 `inline_html` 이 거부하지 않는다. `check_verbatim_coverage` 가 같은 정규식으로 원문 대조를 강등한다.
P21_PLACEHOLDER_RE = re.compile(
    r"<(?:REDACTED|SECRET|TOKEN|KEY|CREDENTIAL|PLACEHOLDER)"
    r"(?:[:_-][\w.-]{0,64})?>"
)
# HTML 요소 이름 — WHATWG 요소 색인 + 옛 요소 · 원문 텍스트 요소 + CommonMark HTML 블록 6종 이름. 속성 없는 여는 태그라도 이 이름이면
# 진짜 요소라 브라우저가 뒤 글을 가리거나 가짜 앵커를 그리므로 자리 표시 낱말로 두지 않는다(`<file>` · `<date>` 는 요소가 아니다).
HTML_ELEMENT_NAMES = section6.HTML_ELEMENT_NAMES   # 요소 이름 표는 section6 이 소유한다(seed_body 도 쓴다)
_BARE_OPEN_TAG_RE = re.compile(r"<([A-Za-z][A-Za-z0-9-]*)>")   # 속성 · 공백 · `/` 가 없는 여는 태그 — 자리 표시 낱말(`<file>`)로 둔다
_PLACEHOLDER_OK_RE = re.compile(r"S<[Nn]>(?=(?:\*\*|__)?(?![\d<*_]))")


def inline_html(line):
    """§6 줄에 인라인 HTML 시작(`<` + 글자 · `/` · `!` · `?`)이 있는가 — 코드 칸 밖에서, 느슨하게(문법을 흉내 내지 않는다). 속성 없는
    여는 태그 하나(`<file>` · `ST<N>`)는 자리 표시 낱말이라 두고, 모양 보기가 그것을 지운 글로 앵커 꼴을 다시 가린다(`**S<i>9**`).
    닫는 태그 · 주석 · 처리 명령 · 선언 · CDATA · 속성이 있는 태그는 거부한다. 이스케이프한 `\\<` 는 태그가 아니다."""
    masked = _PLACEHOLDER_OK_RE.sub(lambda m: "S" + " " * (len(m.group(0)) - 1), _literal_view(line))
    masked = P21_PLACEHOLDER_RE.sub(lambda m: " " * len(m.group(0)), masked)
    masked = _BARE_OPEN_TAG_RE.sub(
        lambda m: m.group(0) if m.group(1).lower() in HTML_ELEMENT_NAMES else " " * len(m.group(0)), masked)
    return bool(_INLINE_HTML_RE.search(masked))


_TOKEN_RE = re.compile(r"[^\s<]+")
_URI_AUTOLINK_RE = re.compile(r"<[A-Za-z][A-Za-z0-9+.-]{1,31}:[^<>\x00-\x20]*>")
_LABEL = r"[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?"
_EMAIL_AUTOLINK_RE = re.compile(r"<[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@" + _LABEL + r"(?:\." + _LABEL + r")*>")




def autolink_with_backtick(line):
    """CommonMark 자동 링크(URI · 이메일) 꼴 안에 백틱이 든 줄인가. 렌더러는 `<` 에서 시작하는 자동 링크를 먼저 읽어 그 안의
    백틱을 글자로 쓰지만, 이 판독의 코드 칸 짝짓기는 그 백틱을 짝으로 읽어 뒤의 HTML 을 코드로 가린다. 읽는 쪽이 갈리므로
    거부한다(백슬래시로 이스케이프한 `\\<` 는 자동 링크가 아니다)."""
    for tok in _TOKEN_RE.finditer(line):   # GFM 확장 자동 링크(`www.` · `스킴://`)도 백틱까지 한 링크로 읽는 렌더러가 있다 — 선형 낱말 훑기
        t = tok.group(0)
        marks = [i for i in (t.find("www."), t.find("://")) if i >= 0]
        if marks and t.rfind("`") > min(marks):
            return True
    for rx in (_URI_AUTOLINK_RE, _EMAIL_AUTOLINK_RE):
        for m in rx.finditer(line):
            if "`" not in m.group(0):
                continue
            back = 0
            while m.start() - back > 0 and line[m.start() - back - 1] == "\\":
                back += 1
            if back % 2 == 0:
                return True
    return False


def anchor_lines(section_text):
    """§6 본문의 바이트 전부를 센다 -> (문법 안 앵커 [(줄 번호, sid, 본문)], 거부 줄 [(줄 번호, 사유)]). 줄 번호는 1부터.

    앵커 꼴(접은 모양의 줄 머리가 `**S<n>**`)인데 날 글자가 문법 밖이면 그 모양의 사유로 거부한다. 앵커가 아닌 줄과
    앵커 줄의 본문에 앵커 꼴 토큰이나 S 번호를 단 목록 머리가 있으면 `anchor_in_body` 다 — 하류가 그것을 사용자
    발화의 앵커로 읽는다(Ruling S13 대체 규칙: 실제 brief 의 §6 은 출처 표기 · 앵커 앞 설명 · 따옴표 같은 원문 밖 글을
    싣고 있어 본문을 원장 글자와 같게 강제하지 않는다)."""
    ok, bad = [], []
    fenced = section6.col0_fence_spans_in(section_text)   # 열 0 에서 연 펜스 안 줄만 코드로 보고 인라인 판독을 하지 않는다
    indented = set(section6.indented_fence_opener_numbers_in(section_text))
    pos = 0
    for n, line in enumerate(split_lines(section_text), 1):
        here, pos = pos, pos + len(line) + 1
        in_fence = any(a <= here < b for a, b in fenced)
        parts = line.splitlines()
        if len(parts) > 1 and any(_ANCHOR_SHAPED.match(fold(p)) or _in_body(fold(p)) for p in parts):
            bad.append((n, "anchor_line_separator"))
            continue
        if n in indented:   # 들여 쓴 펜스 여는 줄 — 부분집합은 열 0 의 펜스만 받는다
            bad.append((n, "fence_indented"))
            continue
        if not in_fence and _HTML_BLOCK_RE.match(canon(line)):   # 줄 머리 `<` + 글자 — HTML 블록이 뒤 앵커 줄을 삼킬 수 있다
            bad.append((n, "html_block_not_allowed"))
            continue
        if not in_fence and _CHAR_REF_RE.search(canon(line)):   # 문자 참조는 §6 모든 줄에서 거부한다(코드 칸 안도)
            bad.append((n, "char_ref_not_allowed"))
            continue
        if not in_fence and autolink_with_backtick(line):
            bad.append((n, "autolink_backtick"))
            continue
        if not in_fence and unpaired_backtick_runs(line):
            bad.append((n, "code_span_unclosed"))
            continue
        if not in_fence and inline_html(line):
            bad.append((n, "html_inline_not_allowed"))
            continue
        f = fold(line)
        v = _shape_view(line)
        shaped = _ANCHOR_SHAPED.match(f)
        if not shaped:
            if _EMPH_S_HEAD.match(f):
                bad.append((n, "anchor_confusable"))
            elif _in_body(f):
                bad.append((n, "anchor_in_body"))
            elif v != f and (_ANCHOR_SHAPED.match(v) or _EMPH_S_HEAD.match(v) or _in_body(v)):
                bad.append((n, "anchor_markup"))
            continue
        m = ANCHOR_LINE_RE.match(line)
        if m:
            ok.append((n, m.group(1), m.group(2) or ""))
            body = m.group(2) or ""
            if _in_body(fold(body)) or _in_body(_shape_view(body)):
                bad.append((n, "anchor_in_body"))
            continue
        why = _lead_ws_reason(line)
        if why is None:
            if line.startswith("* **S"):
                why = "anchor_star_bullet"
            elif f != line or not shaped.group(0).isascii():
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
# 결정 꼴 (가) — 줄 머리(공백 · 번호 · 인용 · 기호 같은 불릿 아닌 앞붙이 뒤, 강조 표시 건너)가 `OQ<n>`. 앞붙이에 여는 괄호 ·
# 여는 따옴표가 있으면 머리가 아니다 — `(OQ1~OQ7 은 …` 같은 산문.
_DECISION_HEAD_RE = re.compile(r"^((?:[\W\d_]|\w{1,3}[.)])*?)[*_`]*(OQ[0-9]+)(?![0-9])")
# 결정 꼴 (나) — 해결 · 열림 표시. 코드 칸(백틱) 안의 표시는 그 칸에 실제 원문 번호(`S` + ASCII 숫자)가 없을 때만 면제한다
# — 자리 표시 `S<n>` 만 적은 설명은 결정 줄이 아니고, `[해결 ⟨S2⟩]` 를 코드 칸에 숨긴 줄은 결정 줄이다.
_DECISION_MARK_RE = re.compile(r"\[해결|\[열림")
_REAL_SID_RE = re.compile(r"S[0-9]")
# 선두 결정 번호 — 불릿을 뗀 본문이 (강조 표시를 사이에 두고도) `OQ<n>` 로 시작할 때 그 번호(`check_brief.LEADING_OQ_RE`).
LEADING_OQ_RE = re.compile(r"^[*_`]*\s*(OQ[0-9]+)(?!_*[0-9A-Za-z])")
# `OQ` 바로 뒤 비ASCII 숫자 — 다른 문자 체계의 숫자로 쓴 결정 번호(Ruling S13-b).
_OQ_LOOKALIKE_RE = re.compile(r"(?<![A-Za-z0-9])OQ(?=[^\x00-\x7f])")
_BULLET_PREFIX_RE = re.compile(r"^\s*[-*]\s+")
DECISION_REASON_TEXT = {
    "decision_numbered": "번호 목록으로 쓴 결정 줄",
    "decision_quoted": "인용(`>`)으로 쓴 결정 줄",
    "decision_shape": "열 0 의 `- ` 불릿이 아닌 결정 줄",
    "decision_confusable": "보이지 않는 글자나 닮은 글자로 머리를 꾸민 결정 줄",
    "decision_line_separator": "한 줄 안에 줄 나눔 글자가 있어 읽는 쪽마다 항목 수가 달라지는 줄",
    "oq_confusable": "결정 번호를 ASCII 가 아닌 숫자로 쓴 줄",
    "decision_outside_sections": "§0 · §3 밖(머리말 · 다른 절 · 펜스 · 표에 없는 머리 아래)에 있어 어느 결정 판독기도 읽지 않는 결정 줄",
    "entry_line_separator": "한 줄 안에 줄 나눔 글자가 있어 읽는 쪽마다 항목 수가 달라지는 줄",
}


def _decision_tokens(text):
    """한 줄의 결정 구조 토큰 -> (머리 `OQ<n>` 또는 None, 표시 목록). 둘 다 비면 결정 꼴이 아니다."""
    oq = None
    m = _DECISION_HEAD_RE.match(text)
    if m and not any(unicodedata.category(ch) in ("Ps", "Pi") for ch in m.group(1)):
        oq = m.group(2)
    chars = list(text)
    for a, b, _run in code_spans(text):   # 정확한 코드 칸 판독 — 정규식 흉내가 아니다
        if not _REAL_SID_RE.search(fold(text[a:b])):
            chars[a:b] = " " * (b - a)
    masked = "".join(chars)
    return oq, _DECISION_MARK_RE.findall(masked)


def _oq_lookalike(text):
    f = fold(text)
    return any(unicodedata.category(f[m.end()]) == "Nd" for m in _OQ_LOOKALIKE_RE.finditer(f))


def decision_shaped(line):
    """정규형이 결정 꼴인가 — `OQ<n>` 머리, 해결 · 열림 표시, 또는 ASCII 가 아닌 숫자를 단 `OQ`."""
    oq, marks = _decision_tokens(fold(line))
    return bool(oq or marks) or _oq_lookalike(line)


def _decision_head_end(c):
    oq, marks = _decision_tokens(c)
    return 0 if (oq or marks) else None


def _structural(part):
    f = fold(part)
    return bool(_LIST_HEAD_RE.match(f) or _decision_head_end(f) is not None or _ANCHOR_SHAPED.match(f))


def _separator_problem(line):
    parts = line.splitlines()
    return len(parts) > 1 and any(_structural(p) for p in parts)


def decision_line_problem(line):
    """§0 · §3 한 줄의 결정 줄 판독 -> 사유 이름 또는 None.

    정규형이 결정 꼴((가) 머리가 `OQ<n>` · (나) `[해결` · `[열림` 표시)인데, 날 글자가 열 0 의 `- ` · `* ` 불릿이 아니거나
    날 글자의 구조 토큰(`OQ<n>` · 표시)이 정규형과 다르면 거부한다 — 번호 목록 · 인용은 그 이름, 정규형으로만 불릿이면
    `decision_confusable`, 그 밖은 `decision_shape`. 줄 안에 다른 줄 나눔 글자가 있고 그 조각이 구조처럼 보이면
    `decision_line_separator`."""
    if _separator_problem(line):
        return "decision_line_separator"
    if _oq_lookalike(line):
        return "oq_confusable"
    c = canon(line)
    tokens = _decision_tokens(c)
    folded = _decision_tokens(fold(line))
    if folded != tokens:   # 닮은 글자(`O` · `Q`)로 쓴 결정 번호 — 정규형은 못 읽고 접은 모양만 결정 꼴이다
        return "decision_confusable"
    if not (tokens[0] or tokens[1]):
        return None
    # 날 글자의 구조 토큰(불릿 · `OQ<n>` · 표시)이 정규형과 같을 때만 받는다 — 앞붙이 · 본문의 정규형 차이(원 숫자 등)는 보지 않는다.
    if _COL0_BULLET_RE.match(line) and _decision_tokens(line) == tokens:
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
    return [(leading_oq(ln), ln) for _n, ln in acc], rej


def leading_oq(line):
    """항목 줄의 선두 `OQ<n>` — 불릿 하나를 뗀 본문의 정규형이 (강조 표시를 사이에 두고도) `OQ<n>` 로 시작할 때 그 번호.
    게이트(`check_brief._leading_oq` · `_decision_line`)와 로드맵이 이 하나로 읽는다."""
    m = LEADING_OQ_RE.match(canon(_BULLET_PREFIX_RE.sub("", line, count=1)).strip())
    return m.group(1) if m else None


# ── 원문 번호 참조 ─────────────────────────────────────────────────────────────
# `check_brief.ANCHOR_RE` 관례 — 앞이 ASCII 영숫자가 아닌 `S<숫자>`. 자리 표시 `S<n>` 은 숫자가 아니라 잡히지 않는다.
_REF_TOKEN_RE = re.compile(r"(?<![A-Za-z0-9])S([0-9]+)(?![0-9])")


# `S` 바로 뒤의 닮은 숫자 · 글자 — 비ASCII 숫자(N*)나 한글 · 한자(동아시아 전각 폭)가 아닌 글자(L*).
_REF_LOOKALIKE_RE = re.compile(r"(?<![A-Za-z0-9])S(?=[^\x00-\x7f])")


def ref_confusables(text):
    """원문 번호처럼 보이는데 번호로 풀지 않는 토큰 -> [`S` + 그 글자] (Ruling S13-a). 접은 모양에서 `S` 바로 뒤가 비ASCII
    숫자이거나 한글 · 한자가 아닌 글자면 닮은 글자로 쓴 번호다(키릴 글자 · 아라비아-인도 숫자 같은 것). 한국어 조사(`S가`)는 허용한다."""
    f = fold(text)
    out = []
    for m in _REF_LOOKALIKE_RE.finditer(f):
        ch = f[m.end()]
        cat = unicodedata.category(ch)
        if cat[0] == "N" or (cat[0] == "L" and unicodedata.east_asian_width(ch) not in ("W", "F")):
            out.append("S" + ch)
    return out


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
