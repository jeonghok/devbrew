#!/usr/bin/env python3
"""interview-seed 게이트 — seed 본문 둘(비어 있지 않음 · 모양) · audit 셋(제목 구조 · 원문 보존 · 덜어 낸 것).

**seed 본문에 대한 슬롯 존재 검사는 없다.** seed 본문 검사는 모양 검사다 — `seed_body.parse_seed`
문법(산문 문단만)이 받지 않는 줄이 없는지를 본다(부재 검사). 무엇이 «있어야» 한다는 검사를 추가하지
않는다: 그것이 payload 를 양식으로 만들고, 양식이 내용을 미리 판 구멍 모양으로 강제한다 — 이 단계가
막으라고 만들어진 실패가 그것이다. `tests/test_seed_one_sentence.sh` 가 이 금지를 산문이 아니라 동작으로
잡는다.

**예외가 하나 있다** — 본문이 비어 있지 않다는 검사(check 0)는 존재 검사이지만 **슬롯이
아니라 파일 전체에 대한 것**이라 같은 금지에 걸리지 않는다: 빈 파일을 통과시키면 모양
검사가 vacuous 해진다(부재 검사는 대상이 없으면 항상 만족되므로). 이 구분(슬롯 vs 파일 전체)이
이 게이트의 경계다 — 슬롯 하나의 존재를 요구하는 검사(특정 헤딩·특정 필드·최소 길이·최소 절
개수·특정 리터럴 등)는 여전히 금지 위반이고 `test_seed_one_sentence.sh` 가 그런 추가에는 RED 를 낸다.

**seed 본문은 이 파일이 따로 해석하지 않는다** — 문법은 `seed_body.py` 한 곳이고 `seed_provenance.py`
marks/classify 도 같은 함수로 읽는다. 그 문법은 허용 목록이다: 산문이 아닌 구조(제목 · 인용 · 목록 · 표 ·
펜스 · HTML · 링크 · 참조 · 태그 문법), URL, 보이지 않는 글자, 정본이 아닌 확인 표시는 모두 «산문이 아닌
구조» 한 가지로 거부된다(줄 번호만 대고 줄 글자는 싣지 않는다). URL 금지는 web kill switch 와 무관하다 —
링크가 권위로 읽혀 하류를 끌고 가는 것이 이유다.

audit 쪽 존재 검사는 **원문 보존**과 **덜어 낸 것 표** 둘이다. 그것은 payload 가 아니라 확산물의
보관소라 같은 논리가 적용되지 않는다.

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
from seed_body import parse_seed, rejected_lines_message  # noqa: E402
from seed_review_log import fold_for_match, heading_structure, section_body  # noqa: E402

RAW_HEADING = "## 1. 원문"

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

    parsed = parse_seed(text)
    body = parsed.body

    # 0. 본문이 비어 있지 않다 — 유일한 seed 본문 «존재» 검사이고, 슬롯이 아니라
    #    파일 전체에 대한 것이다. 빈 파일을 통과시키면 모양 검사가 vacuous 하다.
    #    «비어있음» 판정은 문자 단위가 아니라 카테고리 단위다(`visible_content` 위 주석) —
    #    BOM(U+FEFF)·zero-width space(U+200B) 처럼 `.strip()` 이 공백으로 안 쳐서 놓치는
    #    Cf 문자, 그리고 그 사촌들까지 한 번에 잡는다. 구두점만 있는 seed 는 여전히 통과한다.
    if not visible_content(body):
        problems.append("seed 본문이 비어 있다 (또는 사람이 읽을 수 없는 문자뿐이다)")

    # 1. 본문 모양 — `seed_body` 문법이 받지 않는 줄이 없다(부재 검사 · 모듈 docstring). 답-슬롯 헤딩 ·
    #    태그 · URL 금지가 모두 이 하나에 들었다.
    problems.extend(rejected_lines_message(parsed.rejected))

    # 2. 원문 보존 (audit 쪽 «존재» 검사) — 슬롯 존재 검사로는 유일하다
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
            # 3. 덜어 낸 것 표 (audit 쪽 존재 검사)
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
