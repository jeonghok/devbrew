#!/usr/bin/env python3
"""ac15_rows.py <문서> <행 머리말> — 머리말로 시작하는 표 행 수 · 그 행의 칸 수(이스케이프 안 된 `|` 로 센다) ·
앵커 줄 수 · 「## 6」 제목 줄 수를 찍는다."""
import re
import sys
from pathlib import Path

lines = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
head = sys.argv[2]
rows = [x for x in lines if x.startswith("| ") and head in x]
cells = sorted({len(re.split(r"(?<!\\)\|", x)) - 2 for x in rows})
anchors = sum(1 for x in lines if re.match(r"^\s*[-*]\s+\*\*S\d+\*\*", x))
heads = sum(1 for x in lines if x.startswith("## 6"))
print(len(rows), cells, anchors, heads)
