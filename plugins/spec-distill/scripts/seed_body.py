"""seed_body.py — interview-seed 본문의 문법. seed 본문을 읽는 곳(`check_seed.py` 게이트 ·
`seed_provenance.py` marks/classify)은 모두 이 파일의 `parse_seed` 하나로 읽는다 — 게이트와 출처
판정이 seed 에 무엇이 들었는지를 두고 어긋날 수 없게.

**받는 문법(허용 목록)을 적고, 그 밖은 전부 거부한다** — 막을 표기를 하나씩 열거하지 않는다.
seed 는 다음 세션에 보내는 메시지이지 문서가 아니다: frontmatter 다음은 빈 줄로 나뉜 문단이고, 문단의 줄은
전부 산문 줄이다. 산문 줄은 이렇다.

- 글자: 서식 문자(Cf — 제로폭 · BOM · 방향 제어 · 소프트 하이픈) · 사용자 정의(Co) · 서로게이트(Cs) ·
  미할당(Cn) · 줄 · 문단 구분자(Zl · Zp) · `\\n` 밖의 제어 문자(Cc — 탭 포함)가 하나도 없다. 지우지 않고
  거부한다 — 보이지 않는 글자는 읽는 쪽마다 다르게 읽힌다.
- 줄 머리: NFKC 로 접은 뒤 들여쓰기 0–3칸, 첫 글자가 문자(L) · 숫자(N) · 여는 괄호류(Ps, `[` 제외) · 여는
  인용 부호(Pi) · `"` · `'` · `` ` `` · `*` · `_` · `/`(skill 이름) · `@`(경로) · `—`(앞 문장에 잇는 말) 다 —
  끝의 셋은 레포의 실제 seed 가 산문 줄 머리로 쓴 글자다(마크다운 구조가 아니다). 그 밖(`#` · `>` · `-` · `+` · `=` · `|` · `<` ·
  `[` · `~` · 그 밖의 기호)으로 시작하는 줄은 산문이 아니다 — 제목 · 인용 · 목록 · 표 · setext 밑줄 ·
  HTML · 링크 문법이 모두 여기서 걸린다. 숫자 머리라도 `1.` · `1)` 다음 공백이면 번호 목록이고, `*` · `_`
  머리라도 다음이 공백이거나 줄 전체가 그 글자뿐이면 목록 · 가로줄이며, `` ``` `` 는 펜스다.
  **목록을 받지 않는 이유**: seed 템플릿 예시에 목록이 없고, 목록은 문단을 항목 양식으로 바꾼다.
- 줄 안: URL 스킴(`<영문자>…://`)과 `www.` 이 없다(인라인 코드 안도 — URL 비권위화는 고정점이다).
  인라인 코드 밖에 `[` · `]`(링크 · 참조 · 태그 · 체크박스 문법)와 `<` 바로 뒤 공백 아닌 글자(HTML ·
  자동 링크)가 없다. 확인 표시는 정본 «(사용자 확인)» 글자 그대로만 — 괄호류로 감싼 `사용자확인` 의 다른
  모양은 산문이 아니다.

이 검사는 seed 본문의 **모양** 검사(부재 검사)다 — 무엇이 «있어야» 한다고 요구하지 않는다(슬롯 존재
검사가 아니다). 거부 사유는 줄 번호와 고정된 이름으로만 낸다 — 줄 글자는 싣지 않는다(비신뢰 요청문이다).
"""
from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field

from seed_review_log import fold_for_match

MARK = "(사용자 확인)"
FRONTMATTER_RE = re.compile(r"\A---\n.*?\n---\n", re.S)
# 접은 열에서 표시의 낱말 — 앞뒤 한 글자가 괄호류여야 표시다(`marks_in_flat`).
MARK_CORE_RE = re.compile(r"사용자가?확인(?:함|됨)?")
URL_RE = re.compile(r"[a-z][a-z0-9+.-]*://|www\.\S")
CODE_SPAN_RE = re.compile(r"(`+)(?:(?!\1).)+?\1")
ORDERED_ITEM_RE = re.compile(r"\d{1,9}[.)](?:\s|$)")
REJECT_CATEGORIES = frozenset({"Cf", "Co", "Cs", "Cn", "Zl", "Zp"})
PROSE_START_EXTRA = frozenset('"\'`*_/@' + chr(0x2014))


def split_front(text: str) -> tuple[str, str]:
    m = FRONTMATTER_RE.match(text)
    head = m.group(0) if m else ""
    return head, text[len(head):]


def fold_flat(s: str) -> str:
    return "".join(ch for ch in fold_for_match(s) if not ch.isspace())


def _is_open(ch: str) -> bool:
    return unicodedata.category(ch) in ("Ps", "Pi") or ch == "<"


def _is_close(ch: str) -> bool:
    return unicodedata.category(ch) in ("Pe", "Pf") or ch == ">"


def marks_in_flat(flat: str) -> list[tuple[int, int]]:
    """접고 공백을 뺀 열에서 표시 자리 `[여는 괄호, 닫는 괄호 다음)`."""
    out = []
    for m in MARK_CORE_RE.finditer(flat):
        a, b = m.start() - 1, m.end()
        if a >= 0 and b < len(flat) and _is_open(flat[a]) and _is_close(flat[b]):
            out.append((a, b + 1))
    return out


def mark_spans(s: str) -> list[tuple[int, int]]:
    """s 안의 확인 표시 자리(정본 · 변형 모두) — 글자마다 접고 공백을 뺀 열에서 표시를 찾아 원래
    자리 `[시작, 끝)` 로 되돌린다."""
    flat, where = [], []
    for i, ch in enumerate(s):
        for f in fold_for_match(ch):
            if not f.isspace():
                flat.append(f)
                where.append(i)
    return [(where[a], where[b - 1] + 1) for a, b in marks_in_flat("".join(flat))]


def _starts_as_prose(g: str) -> bool:
    c = g[0]
    cat = unicodedata.category(c)
    if cat.startswith("N"):
        return ORDERED_ITEM_RE.match(g) is None
    if cat.startswith("L") or cat == "Pi" or (cat == "Ps" and c != "["):
        return True
    if c not in PROSE_START_EXTRA:
        return False
    if c == "`":
        return not g.startswith("```")
    if c in "*_":
        return g[1:2] not in ("", " ") and set(g.replace(" ", "")) != {c}
    return True


def line_problem(line: str) -> str | None:
    """산문 줄이 아니면 그 사유의 고정된 이름, 산문 줄이면 None. 빈 줄은 부르지 않는다."""
    for ch in line:
        cat = unicodedata.category(ch)
        if cat in REJECT_CATEGORIES or (cat == "Cc" and ch != "\n"):
            return "보이지 않거나 제어하는 글자"
    f = fold_for_match(line).casefold()
    g = f.lstrip(" ")
    if len(f) - len(g) >= 4:
        return "들여 쓴 코드 블록"
    if not g:
        return None
    if not _starts_as_prose(g):
        return "줄 머리가 산문이 아니다"
    if URL_RE.search(f):
        return "URL"
    outside = CODE_SPAN_RE.sub("", f)
    if "[" in outside or "]" in outside or re.search(r"<\S", outside):
        return "링크 · 태그 · HTML 문법"
    spans = mark_spans(line)
    if len(spans) != len(marks_in_flat(fold_flat(line))):
        return "확인 표시 자리를 정할 수 없다"
    if any(line[a:b] != MARK for a, b in spans):
        return "정본이 아닌 확인 표시"
    return None


@dataclass
class SeedParse:
    head: str
    body: str
    paragraphs: list = field(default_factory=list)
    rejected: list = field(default_factory=list)  # [(파일 줄 번호 1-based, 사유 이름)]


def parse_seed(text: str) -> SeedParse:
    """seed 파일 글 전체 → frontmatter · 본문 · 문단 · 거부된 줄. 줄은 `str.splitlines` 로 나눈다 —
    `\\n` 밖의 줄 구분자는 위 글자 규칙이 이미 거부한다."""
    head, body = split_front(text)
    offset = head.count("\n")
    out = SeedParse(head=head, body=body)
    para: list[str] = []
    for i, line in enumerate(body.split("\n")):
        if line.strip(" ") == "" and not any(unicodedata.category(c) in REJECT_CATEGORIES for c in line):
            if para:
                out.paragraphs.append("\n".join(para))
                para = []
            continue
        reason = line_problem(line)
        if reason:
            out.rejected.append((offset + i + 1, reason))
        para.append(line)
    if para:
        out.paragraphs.append("\n".join(para))
    return out


def rejected_lines_message(rejected: list) -> list[str]:
    """거부된 줄마다 쉬운 한 줄 — 줄 번호와 사유 이름만(줄 글자는 싣지 않는다). 부르는 쪽이 `[스크립트]` 를 붙인다."""
    return ["seed 에 산문이 아닌 구조가 있다 — %d째 줄(%s)" % (n, why) for n, why in rejected]
