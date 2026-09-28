#!/usr/bin/env python3
"""ac8_terms.py <prep.json> <fin.json> <added> — AC8 단계별 등식의 항을 JSON 목록으로 낸다.
[입력(critic+codex 정규화), 재비판 added, same_as 흡수, 재비판 기각, drop, 차단 원장 생존자(decide+fix+ask+defer, 축 무관), advice(listed+repeat)]
그리고 둘째 줄에 좌변 == 우변 여부. 엔진 자동 생성분은 별도 유입이다 — 호출자는 라운드 1(유입 0)에서 부른다."""
from __future__ import annotations

import io
import json
import sys

prep = json.load(io.open(sys.argv[1], encoding="utf-8"))
fin = json.load(io.open(sys.argv[2], encoding="utf-8"))
added = int(sys.argv[3])
bd = fin["by_disposition"]
terms = [len(prep["items"]), added, fin["adjudication_absorbed"], len(fin["rejected"]), len(bd["drop"]),
         sum(len(bd[k]) for k in ("decide", "fix", "ask", "defer")), fin["advice_new"] + fin["advice_repeat"]]
print(json.dumps(terms))
print(terms[0] + terms[1] == sum(terms[2:]))
