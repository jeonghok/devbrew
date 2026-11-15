"""docreview_ask.py — 리뷰 뒤 질문에 싣는 재료를 만드는 순수 함수 (leaf 모듈).

표준 라이브러리만 쓴다. `docreview_state` 를 import 하지 않는다 — 원장은 호출자가 읽고, 여기는 그 값만 받는다.
"""
from __future__ import annotations

SHORT_WARN_HEAD = "리뷰 경고 %d개: %s"
SHORT_WARN_OTHER = "그 밖 %d개"


def short_warn_line(entries) -> str:
    """(짧은 이름, 쉬운 줄) 목록 → 질문의 상태 줄에 싣는 짧은 경고 줄. 비면 빈 글.

    개수는 목록의 길이 그대로다(게이트 첫 줄의 「경고 N개」와 같은 목록에서 센다). 짧은 이름은 처음 나온
    순서로 잇고, 같은 이름이 k(≥2)번이면 「<이름> ×k」로 접는다. 짧은 이름이 없는 것(표에 없는 원문)은
    버리지 않고 맨 끝에 「그 밖 N개」 하나로 센다."""
    entries = list(entries)
    if not entries:
        return ""
    order, count, other = [], {}, 0
    for short, _line in entries:
        if short is None:
            other += 1
            continue
        if short not in count:
            count[short] = 0
            order.append(short)
        count[short] += 1
    parts = [n if count[n] == 1 else "%s ×%d" % (n, count[n]) for n in order]
    if other:
        parts.append(SHORT_WARN_OTHER % other)
    return SHORT_WARN_HEAD % (len(entries), " · ".join(parts))
