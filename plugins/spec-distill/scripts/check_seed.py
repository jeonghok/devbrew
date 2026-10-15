#!/usr/bin/env python3
"""interview-seed 게이트 — 여섯.

**seed 본문에 대한 슬롯 존재 검사는 없다.** 답-슬롯 헤딩·태그·URL 셋은 부재 검사다 — 슬롯
존재 검사를 추가하지 않는다: 그것이 payload 를 양식으로 만들고, 양식이 내용을 미리 판 구멍
모양으로 강제한다 — 이 단계가 막으라고 만들어진 실패가 그것이다. `tests/test_seed_one_sentence.sh`
가 이 금지를 산문이 아니라 동작으로 잡는다.

**예외가 하나 있다** — 본문이 비어 있지 않다는 검사(check 0)는 존재 검사이지만 **슬롯이
아니라 파일 전체에 대한 것**이라 같은 금지에 걸리지 않는다: 빈 파일을 통과시키면 나머지
세 부재 검사가 전부 vacuous 해진다(부재 검사는 대상이 없으면 항상 만족되므로). 이
구분(슬롯 vs 파일 전체)이 이 게이트의 경계다 — 슬롯 하나의 존재를 요구하는 검사(특정
헤딩·특정 필드·최소 길이·최소 절 개수·특정 리터럴 등)는 여전히 금지 위반이고
`test_seed_one_sentence.sh` 가 그런 추가에는 RED 를 낸다.

audit 쪽 존재 검사는 **원문 보존**과 **덜어 낸 것 표** 둘이다. 그것은 payload 가 아니라 확산물의
보관소라 같은 논리가 적용되지 않는다.

**판정은 접은 글자로 한다.** 부재 검사 셋은 본문을 `seed_review_log.fold_for_match`(서식 문자 제거 +
NFKC + 결합 기호 제거)로 접고 대소문자를 접은(casefold) 뒤 판정한다 — 전각 `＃` · `［open:` · `ｈｔｔｐｓ` ·
제로폭 문자가 낀 낱말을 사람과 모델은 같은 글자로 읽는다. 허용 표기를 열거하지 않는다.
- 답-슬롯 헤딩: 줄 머리의 들여쓰기 · 인용 `>` · 목록 표지(`-` `*` `+` `1.` `1)`)를 겹친 만큼 걷은 뒤,
  ATX 제목 모양(`section6.HEADING_SHAPED_RE` — `#` 줄 뒤 공백. 걷은 뒤라 4칸 들여쓰기도 잡는다)이거나
  `##` 로 시작하는 줄(`##대안` — 옛 게이트도 막았고 모델은 제목으로 읽는다), setext 제목(글 줄 바로 다음
  줄이 `=` 만 · `-` 만), HTML `<h1>`–`<h6>` 의 제목 글자에서 앞의 번호 · 기호를 걷고 금지 낱말로 시작하는지
  본다. `#` 하나에 공백 없는 `#대안` 은 제목이 아니다(해시태그 모양 문장). **펜스 안의 금지 헤딩도 금지다**
  — seed 는 다음 세션의 첫 메시지이지 코드 예시가 아니고, 소비자 모델은 펜스 안 `## 대안` 도 읽는다. 줄은
  `str.splitlines` 로 나눈다(U+2028 같은 구분자 뒤의 글도 줄로 본다 — 넓은 쪽).
- URL: 스킴(`<영문자>…://`) · 스킴 없는 `www.` · 마크다운 인라인 링크 목적지 `](…)` · 참조 정의(CommonMark
  모양 — `[라벨]:` 뒤 공백 없는 목적지 하나, 그 뒤는 줄 끝이나 따옴표 · 괄호 제목뿐. `[참고]: 이 부분은 …`
  같은 문장은 참조 정의가 아니다).
  `mailto:` 처럼 `//` 없는 스킴과 스킴 없는 맨 도메인(`example.com/x`)은 이 검사 밖이다.

**audit 절은 다른 소비자와 같은 파서로 찾는다** — `seed_review_log.section_body` · `heading_structure`
(`seed_provenance` · `build_seed_inline_blob` 이 쓰는 것). 템플릿 제목이 겹치거나 템플릿 순서가 어긋나면
판단하지 않는다(실패). 4칸 들여쓰기 · 한 줄 안에 숨은 제목 줄은 절을 열지 않는다. 펜스는 보지 않는다 —
`## 1` 원문의 닫히지 않은 펜스가 뒤 절을 삼켜 정직한 audit 을 막지 않게, 심긴 제목은 겹침 · 순서로 잡는다.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys
import unicodedata

_SCRIPTS_DIR = str(pathlib.Path(__file__).resolve().parent)
if _SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, _SCRIPTS_DIR)
from seed_review_log import fold_for_match, heading_structure, section_body  # noqa: E402
import section6  # noqa: E402 — 제목 모양 판정은 이 리포에서 한 곳이다(§6-단일화 락)

# 답-슬롯 헤딩 — 이 넷은 «공간을 닫는» 산출물의 표지다. seed 는 질문을 닫지 않는다. 접은(공백 제거 ·
# casefold) 제목 글자의 머리로 본다.
ANSWER_SLOT_WORDS = ("미해결질문", "openquestions", "대안", "alternatives", "인수조건",
                     "acceptancecriteria", "기각", "rejected")
TAG_RE = re.compile(r'\[\s*(open|추론|외부)\s*:')
URL_RE = re.compile(
    r'[a-z][a-z0-9+.-]*://|www\.\S|\]\(\s*[^)\s]'
    r'|^[ \t]*\[[^\]\n]+\]:[ \t]*(?:<[^>\n]*>|[^\s<]\S*)[ \t]*'
    r'(?:(?:"[^"\n]*"|' r"'[^'\n]*'" r'|\([^)\n]*\))[ \t]*)?$', re.M)
# 줄 머리의 컨테이너 표지 — 인용 `>` · 목록 표지(`-` `*` `+` · `1.` `1)`)와 들여쓰기, 겹친 만큼.
CONTAINER_RE = re.compile(r'^(?:[ \t]*(?:>|[-*+](?=[ \t])|\d{1,9}[.)](?=[ \t])))+[ \t]*')
HTML_HEADING_RE = re.compile(r'<h([1-6])\b[^>]*>(.*?)(?:</h\1\s*>|$)')
INNER_TAG_RE = re.compile(r'<[^>]*>')
RAW_HEADING = "## 1. 원문"
FRONTMATTER_RE = re.compile(r'\A---\n.*?\n---\n', re.S)

# check 0(파일 전체 비어있음)이 «비어있음»으로 볼 유니코드 카테고리. 셋을 넣었고 이유는
# 셋 다 같다 — **화면에 아무 것도 그리지 않는다**:
#   Cc(제어문자, 개행·탭 등)  Cf(서식문자, BOM U+FEFF·zero-width space U+200B 등 —
#   `str.isspace()` 가 공백으로 안 쳐서 `.strip()` 이 놓치는 정확한 틈새였다)
#   Zs/Zl/Zp(공백·줄·문단 분리자, `.strip()` 이 이미 잡던 부분집합 — 명시적으로 포함해
#   `.strip()` 의 동작에 암묵적으로 기대지 않는다)
# **뺀 것**: 구두점(P*)·기호(S*)·문자(L*)·숫자(N*)·결합기호(M*) — 대체로 화면에 뭔가를
# 그린다(구두점만 있는 seed, 예: "??")도 사람이 실제로 쓴 짧은 질문이다 — 존재로 인정해야
# 한다. **M* 는 헤지를 단다**: 결합 기호는 앞 글자에 붙어야 무언가를 그리고, 앞 글자 없이
# 단독으로 오면 렌더러에 따라 점선 원 같은 자리표만 나오거나 아무것도 안 나올 수 있다 —
# `Co` 에 단 것과 같은 종류의 불확실성이다. 그래도 «안 보인다»고 단정하지 않고 존재로
# 인정하는 쪽을 고른다: 단독 결합 기호만으로 이루어진 seed 는 실제 사용에서 나오지 않고,
# 틀린 방향으로 fail 하면 사람이 쓴 짧은 입력을 빈 것으로 거절하게 된다.
#   Co(사용자 정의)·Cs(서로게이트)·Cn(미할당)은 넣지 않았다 — Co 는 폰트에 따라 실제
# 아이콘 글리프로 렌더될 수 있어 "안 보인다"고 단정할 수 없고, Cs 는 올바른 UTF-8 텍스트에는
# 애초에 나타나지 않는다(단독 서로게이트는 인코딩이 안 됨 — `read_text(encoding="utf-8")`
# 단계에서 이미 걸러진다).
_INVISIBLE_CATEGORIES = frozenset({"Cc", "Cf", "Zs", "Zl", "Zp"})


def visible_content(text: str) -> str:
    """«내용 없음» 카테고리를 걷어낸 나머지. 남는 게 없으면 사람이 읽을 것이 없다는 뜻이고,
    그건 특정 문자 두 개(BOM·zero-width space)를 아는 것과 다른 얘기다 — 다음에 나올
    invisible 문자도 같은 카테고리면 자동으로 잡힌다."""
    return "".join(ch for ch in text if unicodedata.category(ch) not in _INVISIBLE_CATEGORIES)


def _seen(text: str) -> str:
    """판정용 — 접고(`fold_for_match`) 대소문자를 접은 글자. 원문은 바꾸지 않는다."""
    return fold_for_match(text).casefold()


def _slot_word(title: str) -> str | None:
    """제목 글자가 금지 낱말로 시작하면 그 낱말. 앞의 번호 · 기호 · 공백(`3.` · `**` · 닫는 `#`)을 걷는다."""
    flat = "".join(ch for ch in title if not ch.isspace())
    i = 0
    while i < len(flat) and not unicodedata.category(flat[i]).startswith("L"):
        i += 1
    return next((w for w in ANSWER_SLOT_WORDS if flat[i:].startswith(w)), None)


def _is_setext_underline(line: str) -> bool:
    u = line.strip()
    return bool(u) and (set(u) == {"="} or set(u) == {"-"})


def _uncontained(line: str) -> str:
    """줄 머리의 들여쓰기 · 인용 · 목록 표지를 걷은 글자."""
    return CONTAINER_RE.sub("", line, count=1).strip()


def _is_atx(s: str) -> bool:
    return section6.HEADING_SHAPED_RE.match(s) is not None or s.startswith("##")


def answer_slot_headings(body: str) -> list:
    """답-슬롯 헤딩으로 읽히는 줄(접은 글자). 컨테이너 표지를 걷은 뒤 ATX · setext(글 줄 + 밑줄) ·
    HTML `<h1>`–`<h6>` 을 본다(모듈 docstring)."""
    raw = _seen(body).splitlines()
    lines = [_uncontained(ln) for ln in raw]
    out = []
    for i, s in enumerate(lines):
        if _is_atx(s) and _slot_word(s.lstrip("#")):
            out.append(raw[i].strip())
        elif (s and i + 1 < len(lines) and _is_setext_underline(lines[i + 1])
              and not _is_setext_underline(s) and _slot_word(s)):
            out.append(raw[i].strip() + " / " + lines[i + 1])
        else:
            out += [m.group(0) for m in HTML_HEADING_RE.finditer(s)
                    if _slot_word(INNER_TAG_RE.sub("", m.group(2)))]
    return out


def tag_hits(body: str) -> list:
    return [m.group(0) for m in TAG_RE.finditer(_seen(body))]


def url_hits(body: str) -> list:
    return [m.group(0) for m in URL_RE.finditer(_seen(body))]


def body_of(text: str) -> str:
    """frontmatter 를 제외한 본문. frontmatter 세 줄은 하니스용 메타데이터이고 이
    게이트가 재는 것은 사람이 읽는 메시지다 — 검사 대상도 본문이어야 한다."""
    return FRONTMATTER_RE.sub("", text, count=1)


CUT_HEADING = "## seed 에서 덜어 낸 것"
CUT_HEADER_ROW = "| 항목 | 기준 | 원문 위치 | 되살림 |"
_CUT_SEP_RE = re.compile(r"^\|[\s:|-]+\|?\s*$")


def _squash(s: str) -> str:
    return "".join(ch for ch in fold_for_match(s) if not ch.isspace())


def structure_problem(atext: str) -> list:
    problems = heading_structure(atext)
    if not problems:
        return []
    return ["audit 의 템플릿 제목이 겹치거나 순서가 어긋난다(%s) — 어느 줄이 진짜 절인지 정해지지 않아 원문 "
            "보존 · 덜어 낸 것을 판단하지 않는다" % "; ".join(problems)]


def cut_table_problems(atext: str) -> list:
    """audit `## seed 에서 덜어 낸 것` — 표(머리 행 + 데이터 행 하나 이상) 또는 `없음` 한 줄(설계 §1-1 · §1-4).
    seed 본문이 아니라 audit 쪽 존재 검사다 — seed 를 양식으로 만들지 않는다(`test_seed_one_sentence.sh`).
    절은 `section_body` 로 찾는다(다른 소비자와 같은 파서). 머리 행 비교는 접고 공백을 뺀 뒤다."""
    bad = structure_problem(atext)
    if bad:
        return bad
    body = section_body(atext, CUT_HEADING)
    if body is None:
        return ["audit 에 `## seed 에서 덜어 낸 것` 절이 없다 — 덜어 낸 것이 없으면 `없음` 한 줄을 적는다"]
    lines = [ln.strip() for ln in body.splitlines() if ln.strip()]
    if any(ln == "없음" for ln in lines):
        return []
    rows = [ln for ln in lines if ln.startswith("|") and _squash(ln) != _squash(CUT_HEADER_ROW)
            and not _CUT_SEP_RE.match(ln)]
    if not rows:
        return ["audit 의 `## seed 에서 덜어 낸 것` 절에 표 행도 `없음` 줄도 없다 — 덜어 낸 항목을 한 줄씩 적거나 `없음` 을 적는다"]
    return []


def gate(seed_path: pathlib.Path, audit_path: pathlib.Path | None) -> list:
    problems = []
    try:
        text = seed_path.read_text(encoding="utf-8")
    except OSError as e:
        return [f"seed 를 읽을 수 없다: {e}"]

    body = body_of(text)

    # 0. 본문이 비어 있지 않다 — 유일한 seed 본문 «존재» 검사이고, 슬롯이 아니라
    #    파일 전체에 대한 것이다. 빈 파일을 통과시키면 나머지 셋이 전부 vacuous 하다.
    #    «비어있음» 판정은 문자 단위가 아니라 카테고리 단위다(`visible_content` 위 주석) —
    #    BOM(U+FEFF)·zero-width space(U+200B) 처럼 `.strip()` 이 공백으로 안 쳐서 놓치는
    #    Cf 문자, 그리고 그 사촌들까지 한 번에 잡는다. 구두점만 있는 seed 는 여전히 통과한다.
    if not visible_content(body):
        problems.append("seed 본문이 비어 있다 (또는 사람이 읽을 수 없는 문자뿐이다)")

    # 1~3 은 부재 검사다 — 슬롯 존재 검사가 아니다. 각 함수가 본문을 접은 뒤 판정한다(모듈 docstring).
    # 1. 답-슬롯 헤딩 부재
    for h in answer_slot_headings(body):
        problems.append(f"답-슬롯 헤딩: {h!r} — seed 는 공간을 닫지 않는다")

    # 2. 태그 0개
    for tag in tag_hits(body):
        problems.append(f"태그: {tag!r} — 라벨 없이 말로 쓴다")

    # 3. URL 0개
    #    web kill switch 와 **무관**하다. 웹이 꺼져 있어도 금지는 유지된다 — 완화할
    #    대상이 애초에 없다. 링크가 권위로 읽혀 하류를 끌고 가는 것이 이 조항의 이유다.
    for u in url_hits(body):
        problems.append(f"URL: {u!r} — 링크로 나르지 말고 말로 옮겨 적는다")

    # 4. 원문 보존 (audit 쪽 «존재» 검사) — 슬롯 존재 검사로는 유일하다
    #    (파일-전체 검사인 0번과는 범주가 다르다).
    if audit_path is None:
        problems.append("audit 경로가 주어지지 않았다 — 원문 보존을 확인할 수 없다")
    else:
        try:
            atext = audit_path.read_text(encoding="utf-8")
        except OSError as e:
            problems.append(f"audit 을 읽을 수 없다: {e}")
        else:
            if not structure_problem(atext):  # 어긋나면 아래 cut_table_problems 가 한 번 보고한다
                raw = section_body(atext, RAW_HEADING)
                if raw is None:
                    problems.append("audit 에 `## 1. 원문` 절이 없다")
                elif not raw.strip():
                    problems.append("audit 의 `## 1. 원문` 절이 비어 있다")
            # 5. 덜어 낸 것 표 (audit 쪽 존재 검사)
            problems.extend(cut_table_problems(atext))
    return problems


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("mode", choices=["gate"])
    p.add_argument("seed")
    p.add_argument("audit", nargs="?")
    a = p.parse_args()
    probs = gate(pathlib.Path(a.seed),
                 pathlib.Path(a.audit) if a.audit else None)
    for x in probs:
        print(f"[check_seed] {x}", file=sys.stderr)
    return 1 if probs else 0


if __name__ == "__main__":
    sys.exit(main())
