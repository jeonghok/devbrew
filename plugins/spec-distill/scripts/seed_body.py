"""seed_body.py — interview-seed 본문의 문법. seed 본문을 읽는 곳(`check_seed.py` 게이트 ·
`seed_provenance.py` marks/classify)은 모두 이 파일의 `parse_seed` 하나로 읽는다 — 게이트와 출처
판정이 seed 에 무엇이 들었는지를 두고 어긋날 수 없게.

**받는 문법(허용 목록)을 적고, 그 밖은 전부 거부한다** — 막을 표기를 하나씩 열거하지 않는다.
seed 는 다음 세션에 보내는 메시지이지 문서가 아니다: frontmatter 다음은 빈 줄로 나뉜 문단이고, 문단의 줄은
전부 산문 줄이다. 산문 줄은 이렇다.

- 글자: 서식 문자(Cf — 제로폭 · BOM · 방향 제어 · 소프트 하이픈) · 사용자 정의(Co) · 서로게이트(Cs) ·
  미할당(Cn) · 줄 · 문단 구분자(Zl · Zp) · `\\n` 밖의 제어 문자(Cc — 탭 포함)가 하나도 없다. 지우지 않고
  거부한다 — 보이지 않는 글자는 읽는 쪽마다 다르게 읽힌다. 줄 구분은 `\n` 하나다 — U+2028 · U+2029 ·
  NEL · FF · VT 같은 다른 줄 나눔 글자는 위 범주(Zl · Zp · Cc)로 거부된다.
- 빈 줄: 글자가 하나도 없는 줄만 빈 줄(문단 경계)이다. 공백 글자(스페이스 · NBSP · 전각 공백 등)만 있는
  줄은 거부한다 — 그 줄을 문단 경계로 볼지 문단의 한 줄로 볼지가 읽는 쪽마다 달라 확인 문장의 경계가
  흔들린다. 문단은 `parse_seed` 가 나눈 것을 모든 소비자가 그대로 쓴다(두 번째 문단 나누기가 없다).
- 줄 머리: NFKC 로 접은 뒤 들여쓰기 0–3칸, 첫 글자가 문자(L) · 숫자(N) · 여는 괄호류(Ps, `[` 제외) · 여는
  인용 부호(Pi) · `"` · `'` · `` ` `` · `*` · `_` · `/`(skill 이름) · `@`(경로) · `—`(앞 문장에 잇는 말) 다 —
  끝의 셋은 레포의 실제 seed 가 산문 줄 머리로 쓴 글자다(마크다운 구조가 아니다). 그 밖(`#` · `>` · `-` · `+` · `=` · `|` · `<` ·
  `[` · `~` · 그 밖의 기호)으로 시작하는 줄은 산문이 아니다 — 제목 · 인용 · 목록 · 표 · setext 밑줄 ·
  HTML · 링크 문법이 모두 여기서 걸린다. 숫자 머리라도 `1.` · `1)` 다음 공백이면 번호 목록이고, `*` · `_`
  머리라도 다음이 공백이거나 줄 전체가 그 글자뿐이면 목록 · 가로줄이며, `` ``` `` 는 펜스다.
  **목록을 받지 않는 이유**: seed 템플릿 예시에 목록이 없고, 목록은 문단을 항목 양식으로 바꾼다.
- 줄 안: URL 스킴(`<영문자>…://` · `mailto:`)과 `www.` · 도메인으로 시작하는 주소(`example.com/…` — `bare_domain`) · HTML 문자 참조
  (`&#91;` · `&amp;` — `char_ref`) · `[` · `]`(링크 · 참조 · 태그 · 체크박스 문법) · `<` 바로 뒤
  공백 아닌 글자(HTML · 자동 링크)가 없다. **인라인 코드도 면제하지 않는다** — 코드 구간의 경계(백틱 길이 ·
  이웃 백틱 · 백슬래시 이스케이프)를 이 파일이 따로 계산하면 렌더러와 어긋나는 흉내 파서가 된다(``` ``<h2>`
  ``` 가 날 HTML 로, `` \`[x](y)` `` 가 진짜 링크로 렌더된다). 백틱 자체는 받는다 — 경로 · 명령을 적는 데
  쓰이고(템플릿 예시의 `` `src/auth/` ``), 금지 글자가 없는 한 어떻게 갈라 읽어도 구조가 생기지 않는다. 확인 표시는 정본 «(사용자 확인)» 글자 그대로만 — 괄호류로 감싼 `사용자확인` 의 다른
  모양과, `사용자` 와 `확인` 을 함께 담은 괄호가 정본이 아닌 모양(`mark_variant`)은 산문이 아니다. frontmatter 는 `키: 값` 줄만
  받는다(`frontmatter_line` · `frontmatter_value`).

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
URL_RE = re.compile(r"[a-z0-9+.-]://|www\.\S|mailto:")   # 스킴 글자 바로 뒤 `://` — 길이를 재지 않아 선형이고 긴 스킴도 거부한다
CHAR_REF_RE = re.compile(r"&(?:#[0-9]+|#[xX][0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);")
BARE_DOMAIN_RE = re.compile(r"(?<![a-z0-9.-])[a-z0-9-]{1,63}(?:\.[a-z0-9-]{1,63})+/")   # 낱말 머리에서만 시작 — 선형
FRONTMATTER_LINE_RE = re.compile(r"^([a-z_]+):(?: (.*))?$")
BARE_PLACEHOLDER_RE = re.compile(r"<[A-Za-z][A-Za-z0-9_-]*>")   # 속성 없는 여는 태그 하나 — 템플릿의 자리 표시(`<basename>`)
ANGLE_RE = re.compile(r"<\S")
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


def _flat_groups(s: str):
    """-> (접고 공백을 뺀 열, 짝이 맞는 괄호 묶음 [(여는 자리, 닫는 자리)] — 그 열 위의 자리). 줄 전체를 한 번에 접는다(NFKC 는 글자
    하나씩 접으면 놓치는 조합 — 풀어 쓴 한글 자모 — 을 합친다). 여는 괄호류는 짝을 깊이로 센다(바깥 묶음과 안쪽 묶음 모두 낸다).
    짝 없는 괄호는 묶음이 아니다."""
    flat = fold_flat(s)
    stack, out = [], []
    for k, ch in enumerate(flat):
        if _is_open(ch):
            stack.append(k)
        elif _is_close(ch) and stack:
            out.append((stack.pop(), k))
    return flat, out


_MAX_MARK_GROUPS = 200


def mark_variant(line: str) -> bool:
    """확인 표시를 닮은 괄호(`사용자` 다음에 `확인` 을 담은 묶음)가 정본 «(사용자 확인)» 글자 그대로가 아닌가. 정본 표시를 한 번
    뺀 묶음에 아직 두 낱말이 남으면 변형이다 — 정본 표시를 따옴표 안에 인용한 줄은 변형이 아니다. 괄호 묶음이 지나치게 많은 줄은
    판정하지 않고 변형으로 본다. 접기는 줄당 한 번, 낱말 찾기는 `find` 라 줄 길이에 선형이다."""
    flat, groups = _flat_groups(line)
    if len(groups) > _MAX_MARK_GROUPS:
        return True
    flat_mark = fold_flat(MARK)
    for a, b in groups:
        t = flat[a:b + 1].replace(flat_mark, "")
        i = t.find("사용자")
        if i >= 0 and t.find("확인", i + 3) >= 0:
            return True
    return False


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
    if line.strip() == "":
        return "공백 글자만 있는 줄"
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
    if CHAR_REF_RE.search(f):
        return "char_ref"
    if BARE_DOMAIN_RE.search(f):
        return "bare_domain"
    if "[" in f or "]" in f or ANGLE_RE.search(f):
        return "링크 · 태그 · HTML 문법"
    spans = mark_spans(line)
    if len(spans) != len(marks_in_flat(fold_flat(line))):
        return "확인 표시 자리를 정할 수 없다"
    if any(line[a:b] != MARK for a, b in spans):
        return "정본이 아닌 확인 표시"
    if mark_variant(line):
        return "mark_variant"
    return None


@dataclass
class SeedParse:
    head: str
    body: str
    paragraphs: list = field(default_factory=list)
    rejected: list = field(default_factory=list)  # [(파일 줄 번호 1-based, 사유 이름)]


def split_paragraphs(text: str) -> list[str]:
    """글을 문단으로 나눈다 — 줄은 `\n` 으로만 자르고 문단 경계는 글자가 하나도 없는 줄뿐이다. seed 본문(`parse_seed`)과 audit `## 1`
    원문(`seed_provenance.verbatim_units`)이 같은 이 함수로 나눈다 — 문단을 가르는 규칙이 둘이면 같은 글이 읽는 쪽마다 다른
    문장 단위가 된다."""
    out, para = [], []
    for line in text.split("\n"):
        if line == "":
            if para:
                out.append("\n".join(para))
                para = []
            continue
        para.append(line)
    if para:
        out.append("\n".join(para))
    return out


def _mask_placeholders(value: str) -> str:
    """속성 없는 꺾쇠 낱말 중 HTML 요소 이름이 아닌 것(`<basename>`)만 글자로 바꾼다 — `<template>` 같은 진짜 요소는 남겨 거부된다."""
    from section6 import HTML_ELEMENT_NAMES
    return BARE_PLACEHOLDER_RE.sub(lambda m: m.group(0) if m.group(0)[1:-1].lower() in HTML_ELEMENT_NAMES else "x", value)


def frontmatter_problems(head: str) -> list[tuple[int, str]]:
    """frontmatter 는 `키: 값` 줄만 받는다 — 키는 `[a-z_]+`, 값은 비었거나 산문 줄 규칙(`line_problem`)을 지나는 한 줄(속성 없는 꺾쇠 낱말 `<basename>` 은 템플릿의 자리 표시라 글자로 본다). 그 밖은
    -> [(파일 줄 번호 1-based, `frontmatter_line` | `frontmatter_value`)]. `head` 는 `split_front` 의 앞부분이다."""
    if not head:
        return []
    out = []
    for i, ln in enumerate(head.split("\n")[1:-2], 2):
        m = FRONTMATTER_LINE_RE.match(ln)
        if not m:
            out.append((i, "frontmatter_line"))
        elif m.group(2) is not None and m.group(2) != "" and line_problem(_mask_placeholders(m.group(2))):
            out.append((i, "frontmatter_value"))
    return out


def parse_seed(text: str) -> SeedParse:
    """seed 파일 글 전체 → frontmatter · 본문 · 문단 · 거부된 줄. 줄은 `\\n` 으로만 나눈다 — 다른 줄 나눔
    글자는 위 글자 규칙이 거부한다. 문단 경계는 글자가 하나도 없는 줄뿐이다(`split_paragraphs`)."""
    head, body = split_front(text)
    offset = head.count("\n")
    out = SeedParse(head=head, body=body)
    out.rejected.extend(frontmatter_problems(head))
    for i, line in enumerate(body.split("\n")):
        if line == "":
            continue
        reason = line_problem(line)
        if reason:
            out.rejected.append((offset + i + 1, reason))
    out.paragraphs = split_paragraphs(body)
    return out


REASON_GLOSS = {
    "frontmatter_line": "frontmatter 줄이 `키: 값` 한 줄이 아니다",
    "frontmatter_value": "frontmatter 값이 산문 한 줄이 아니다",
    "char_ref": "HTML 문자 참조(`&#91;` 같은 것)가 있다 — 그 글자를 그대로 적는다",
    "bare_domain": "도메인으로 시작하는 주소(`example.com/…`)가 있다 — 주소 대신 이름이나 설명으로 적는다",
    "mark_variant": "확인 표시를 닮은 괄호가 정본 «(사용자 확인)» 이 아니다 — 정확히 «(사용자 확인)» 으로 적거나 «사용자» · «확인» 을 괄호 밖으로 뺀다",
}


def rejected_lines_message(rejected: list) -> list[str]:
    """거부된 줄마다 쉬운 한 줄 — 줄 번호와 사유 이름만(줄 글자는 싣지 않는다). 부르는 쪽이 `[스크립트]` 를 붙인다."""
    return ["seed 에 산문이 아닌 구조가 있다 — %d째 줄(%s)" % (n, ("%s: %s" % (why, REASON_GLOSS[why])) if why in REASON_GLOSS else why)
            for n, why in rejected]
