#!/usr/bin/env python3
"""interview-seed 게이트 — 다섯.

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

audit 쪽 존재 검사는 **원문 보존 하나뿐**이다. 그것은 payload 가 아니라 확산물의 보관소라
같은 논리가 적용되지 않는다.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

# 답-슬롯 헤딩 — 이 넷은 «공간을 닫는» 산출물의 표지다. seed 는 질문을 닫지 않는다.
ANSWER_SLOT_RE = re.compile(
    r'^##+\s*(미해결\s*질문|Open\s*Questions|대안|Alternatives|인수\s*조건|'
    r'Acceptance\s*Criteria|기각|Rejected)', re.M | re.I)
TAG_RE = re.compile(r'\[(open|추론|외부)\s*:')
URL_RE = re.compile(r'https?://')
FRONTMATTER_RE = re.compile(r'\A---\n.*?\n---\n', re.S)


def body_of(text: str) -> str:
    """frontmatter 를 제외한 본문. frontmatter 세 줄은 하니스용이고 첫 턴에 붙여넣는
    것은 본문이다 — 검사 대상도 본문이어야 한다."""
    return FRONTMATTER_RE.sub("", text, count=1)


def gate(seed_path: pathlib.Path, audit_path: pathlib.Path | None) -> list:
    problems = []
    try:
        text = seed_path.read_text(encoding="utf-8")
    except OSError as e:
        return [f"seed 를 읽을 수 없다: {e}"]

    body = body_of(text)

    # 0. 본문이 비어 있지 않다 — 유일한 seed 본문 «존재» 검사이고, 슬롯이 아니라
    #    파일 전체에 대한 것이다. 빈 파일을 통과시키면 나머지 셋이 전부 vacuous 하다.
    if not body.strip():
        problems.append("seed 본문이 비어 있다")

    # 1. 답-슬롯 헤딩 부재
    for m in ANSWER_SLOT_RE.finditer(body):
        problems.append(f"답-슬롯 헤딩: {m.group(0).strip()!r} — seed 는 공간을 닫지 않는다")

    # 2. 태그 0개
    for m in TAG_RE.finditer(body):
        problems.append(f"태그: {m.group(0)!r} — 라벨 없이 말로 쓴다")

    # 3. URL 0개
    #    web kill switch 와 **무관**하다. 웹이 꺼져 있어도 금지는 유지된다 — 완화할
    #    대상이 애초에 없다. 링크가 권위로 읽혀 하류를 끌고 가는 것이 이 조항의 이유다.
    for m in URL_RE.finditer(body):
        problems.append(f"URL: {m.group(0)!r} — 링크로 나르지 말고 말로 옮겨 적는다")

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
            m = re.search(r'^##\s*1\.\s*원문\s*$(.*?)(?=^##\s|\Z)', atext, re.M | re.S)
            if m is None:
                problems.append("audit 에 `## 1. 원문` 절이 없다")
            elif not m.group(1).strip():
                problems.append("audit 의 `## 1. 원문` 절이 비어 있다")
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
