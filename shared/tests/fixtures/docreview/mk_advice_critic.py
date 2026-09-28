#!/usr/bin/env python3
"""mk_advice_critic.py <n> <out> — design-doc advisory 축 decide n 개(서로 다른 버킷, 전부 #1-context)를 담은 critic
출력을 쓴다(1 ≤ n ≤ 12). 요약은 「참고 항목 k — <축>」, 대체안은 「고칠 방법 k」."""
from __future__ import annotations

import io
import sys

AXES = ["component_relations", "data_flow", "tradeoffs", "feasibility", "overdesign", "placeholder",
        "ambiguity", "scope_creep", "approaches_comparison", "isolation", "testing", "handoff_incomplete"]
n = int(sys.argv[1])
if not 0 < n <= len(AXES):
    sys.exit("n 은 1..%d" % len(AXES))
rows = ["```docreview-layer1"]
for k, cat in enumerate(AXES[:n], 1):
    rows += ["- ref: p%d" % k, "  category: %s" % cat, '  anchor: "#1-context"', "  disposition: decide",
             '  summary: "참고 항목 %d — %s"' % (k, cat), '  replacement: "고칠 방법 %d"' % k]
rows += ["```", "", "```docreview-layer2", "[]", "```", ""]
io.open(sys.argv[2], "w", encoding="utf-8").write("\n".join(rows))
