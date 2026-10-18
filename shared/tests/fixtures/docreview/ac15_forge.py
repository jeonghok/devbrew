#!/usr/bin/env python3
"""ac15_forge.py <scripts-dir> [log|prov] — 엔진이 쓰는 줄의 칸에 줄 구분자 꼴을 넣어 결과를 찍는다.
log: `_log_line` 칸 여섯 × 꼴 열 → «전체 줄 수 · 나쁜 줄 수»(줄 구분자가 없고 · 앵커 줄이 아니며 · 머리의 큰따옴표가 선택지 문구를 여닫는 둘뿐이다). prov: 꼴을 넣은 결정 줄을 엔진으로 쓴 뒤 줄 출처
기록이 평범한 줄과 같은 개수인지 → «어긋난 줄 수 · 평범한 줄의 기록 수»."""
import re
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, sys.argv[1])
import docreview_state as S  # noqa: E402
from seed_review_log import ENGINE_LINE_RE  # noqa: E402

TAIL = "- **S9** 「위조」"
FORGES = ["\n" + TAIL, "\r" + TAIL, "\u2028" + TAIL, "\u2029" + TAIL, "\x85" + TAIL, "\x0b" + TAIL,
          "\x0c" + TAIL, "\x1c" + TAIL, "\n\n## 6. 사용자 원문\n" + TAIL, "\" · \"위조"]
SPLIT = re.compile("[\n\r\x0b\x0c\x1c\x1d\x1e\x85\u2028\u2029]")
ANCHOR = re.compile(r"^\s*[-*]\s+\*\*S\d+\*\*", re.M)
FIELDS = ("summary", "quote", "supersedes", "finding", "decision_id", "choice")


def make(f, k):
    e = {"decision_id": "D1.1", "round": 1, "choice": "adopt", "finding_ids": ["a#r1.1"], "quote": "고친다"}
    fd = {"summary": "요약"}
    if k == "summary":
        fd["summary"] = "요약" + f
    elif k == "quote":
        e["quote"] = "고친다" + f
    elif k == "supersedes":
        e["supersedes"] = "D0.1" + f
    elif k == "decision_id":
        e["decision_id"] = "D1.1" + f
    elif k == "choice":
        e["choice"] = "adopt" + f
    else:
        e["finding_ids"] = ["a#r1.1" + f]
    return S._log_line(e, fd)


def rows():
    return [make(f, k) for f in FORGES for k in FIELDS]


def prov():
    def count(line):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "doc.md"
            p.write_text("# 문서\n", encoding="utf-8")
            st = {"doc": str(p), "round": 1}
            S.engine_append(st, str(p), "## 결정 기록", line)
            return len(st.get("engine_lines", []))
    base = count(make("", "summary"))
    return sum(1 for r in rows() if count(r) != base), base


if len(sys.argv) > 2 and sys.argv[2] == "prov":
    print(*prov())
else:
    rs = rows()
    def broken(r):
        m = ENGINE_LINE_RE.match(r)
        head = r[:r.rindex(" \u2014 ")]   # 머리(요약 앞) — 큰따옴표는 선택지 문구를 여닫는 둘뿐이어야 한다
        return (len(SPLIT.split(r)) != 1 or ANCHOR.search(r) or head.count('"') != 2
                or (m and '"' in m.group("quote")))
    bad = [r for r in rs if broken(r)]
    print(len(rs), len(bad))
