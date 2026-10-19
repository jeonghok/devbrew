#!/usr/bin/env python3
"""ac15_adv_seed.py <scripts-dir> <state-dir> <값> — 상태의 참고 항목 요약 · 대체안을 <값> 으로 바꿔 저장하고, 다시 읽어
전부 그 값인지 확인해 «바뀐 항목 수» 를 찍는다. 못 바꾸면 rc 1 (PyYAML 이 필요해서 `-I` 없이 부른다)."""
import sys

sys.path.insert(0, sys.argv[1])
from docreview_state import load_state, save_state  # noqa: E402

d, val = sys.argv[2], sys.argv[3]
st = load_state(d)
items = list(st["advice"].values())
for v in items:
    v.update(summary=val, replacement=val)
save_state(d, st, "fixture")
back = list(load_state(d)["advice"].values())
n = sum(1 for v in back if v.get("summary") == val and v.get("replacement") == val)
print(n)
sys.exit(0 if n == len(items) and n > 0 else 1)
