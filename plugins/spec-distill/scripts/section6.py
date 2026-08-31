#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""section6.py — brief 문서의 `## 6. 사용자 원문` 절 경계. **이 리포에서 한 곳.**

## 왜 별도 모듈인가

`## 6.` 이 어디서 시작해 어디서 끝나는지를 세 소비자가 각자 계산했고, 셋의 규칙이 달랐다:

| 소비자 | 시작 | 종결 |
|---|---|---|
| `check_brief.py` (게이트) | 펜스 **밖** `^##\\s+6\\.\\s+사용자 원문` | 펜스 **밖** `^##\\s+\\d+\\.` |
| `build_brief_bundle.py` | 원문 `^##\\s+6\\.\\s+사용자 원문` | 원문 `^##\\s+\\d+\\.` |
| `check_verbatim_coverage.py` | 원문 `^##\\s*6\\.` | 원문 `^##\\s` |

규칙이 다르면 **같은 문서가 소비자마다 다른 §6 을 갖는다**. 그 어긋남 하나하나가 통로였다 —
게이트가 보는 §6 과 번들이 싣는 §6 이 다르면, 게이트를 통과한 바이트가 아닌 것이 충실도
리뷰어에게 ground truth 로 나간다. 실측 두 형태(v0.47.0): audit §6 안에 **펜스로 감싼**
`## 7.` 을 두면 ① 번들의 `<<<AUDIT-VERBATIM>>>` 블록이 **비고**(원문 전량 소실) ② 그 자리에
위조 `S2` 를 심으면 **위조본이 실리고 진짜는 사라진다**. 게이트는 둘 다 rc 0 이었다.

그래서 규칙을 셋에서 **하나**로 줄인다. 소비자가 각자 계산하지 않으면 어긋남이 생길 자리가
없다 — 「지금은 안 어긋난다」가 아니라 **어긋날 수 없다**. 새 소비자가 자기 정규식을 들고
나타나는 것은 `test_check_brief.sh` 의 §6-경계 파생 락이 막는다(패턴을 손으로 열거하지 않고,
`## 6. 사용자 원문` 을 매치하는 모듈 수준 `re.compile` 리터럴을 `ast` 로 전수 수집해 이
파일 밖에 있으면 red).

## 판정 규칙 — 「유일하게 해석되는가」

경계를 **고르지 않는다.** 고르는 순간 그 선택이 저자가 옮길 수 있는 좌표가 된다(v0.46.0 이
시작 좌표에서 배운 것). 대신 **가장 관대한 읽기와 가장 엄격한 읽기가 일치하는지**를 묻고,
어긋나면 red 다. 두 극단은 위 표의 실제 소비자 규칙에서 뽑았다 — 손으로 고른 값이 아니다.

- **시작**: 후보는 `^##\\s*6\\.` 의 **전체**(펜스 안도 센다 — 소비자 셋 중 둘이 펜스를 무시한다).
  둘 이상이면 「어느 것이 §6 인가」가 정해지지 않는다.
- **종결**: 관대한 읽기는 `^##\\s`(원문, 펜스 무시), 엄격한 읽기는 `^##\\s+\\d+\\.`(펜스 밖).
  둘이 다른 자리를 가리키면 「어디까지가 §6 인가」가 정해지지 않는다.

두 축은 같은 술어의 두 좌표다. 한쪽만 못 박으면 다른 쪽으로 같은 공격이 그대로 들어온다.
"""
from __future__ import annotations

import re

# 펜스 인식은 `check_brief._body()` 와 같은 문법이어야 한다 — 다르면 「펜스 안」의 정의가
# 두 개가 되어 이 모듈이 없애려는 바로 그 어긋남이 재발한다.
FENCE_RE = re.compile(r"^[ \t]*```.*?^[ \t]*```[^\n]*$", re.DOTALL | re.MULTILINE)

# 시작 후보 — 제목을 요구하지 않는다. 제목을 요구하면 `## 6. 참고 자료` 같은 줄이 후보에서
# 빠지는데, 그 줄은 사람에게도 소비자에게도 「6번 절」로 읽힌다. 넓은 쪽으로 틀리면 red 가
# 하나 더 날 뿐이고, 좁은 쪽으로 틀리면 통로가 열린다.
START_RE = re.compile(r"(?m)^##\s*6\.")
# 종결 후보 — 관대(원문·펜스 무시) / 엄격(펜스 밖·번호 요구).
END_LOOSE_RE = re.compile(r"(?m)^##\s")
END_STRICT_RE = re.compile(r"(?m)^##\s+\d+\.")


def fence_spans(text: str) -> list:
    return [(m.start(), m.end()) for m in FENCE_RE.finditer(text)]


def _outside(m, spans) -> bool:
    return not any(s <= m.start() < e for s, e in spans)


def start_candidates(text: str) -> list:
    """§6 시작으로 읽힐 수 있는 매치 전부 (펜스 안 포함)."""
    return list(START_RE.finditer(text))


def line_of(text: str, pos: int) -> int:
    return text.count("\n", 0, pos) + 1


def ambiguities(text: str) -> list:
    """§6 이 **모든 소비자에게 같은 영역**으로 해석되지 않는 이유들. 없으면 빈 목록.

    절이 아예 없는 것은 여기서 다루지 않는다 — 그것은 모호가 아니라 부재이고,
    `find_missing_sections`(#1/#9)와 N1b 등식이 각자 자기 이름으로 red 를 낸다.
    """
    reasons = []
    starts = start_candidates(text)
    if len(starts) > 1:
        reasons.append(
            "§6 시작 헤딩이 %d개다 (줄 %s) — 어느 것이 §6 인지 정해지지 않는다"
            % (len(starts), [line_of(text, m.start()) for m in starts]))
        return reasons
    if not starts:
        return reasons
    pos = starts[0].end()
    spans = fence_spans(text)
    loose = END_LOOSE_RE.search(text, pos)
    strict = next((m for m in END_STRICT_RE.finditer(text, pos) if _outside(m, spans)), None)
    loose_at = loose.start() if loose else len(text)
    strict_at = strict.start() if strict else len(text)
    if loose_at != strict_at:
        reasons.append(
            "§6 종결 위치가 읽는 규칙마다 다르다 (관대: 줄 %s · 엄격: 줄 %s) — "
            "게이트가 보는 §6 과 번들·완전성 검사가 싣는 §6 이 갈린다"
            % (line_of(text, loose_at), line_of(text, strict_at)))
    return reasons


def span(text: str):
    """`(start, body_start, end)` — 유일하게 해석될 때만. 부재·모호면 None.

    `start`는 헤딩 줄 머리, `body_start`는 그 줄 다음, `end`는 다음 절 머리(없으면 EOF).
    None 을 **fail-closed 로 읽는 것은 호출자의 책임**이다 — 이 모듈은 「모르겠다」를
    「비었다」로 바꾸지 않는다.
    """
    if ambiguities(text):
        return None
    starts = start_candidates(text)
    if not starts:
        return None
    m = starts[0]
    nl = text.find("\n", m.end())
    body_start = len(text) if nl < 0 else nl + 1
    end = END_LOOSE_RE.search(text, m.end())
    return (m.start(), body_start, end.start() if end else len(text))


def body(text: str):
    """§6 의 **항목 본문**(헤딩 줄 제외). 부재·모호면 None."""
    sp = span(text)
    return None if sp is None else text[sp[1]:sp[2]]
