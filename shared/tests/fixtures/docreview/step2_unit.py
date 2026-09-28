#!/usr/bin/env python3
"""step2_unit.py <scripts-dir> <시나리오> <forward|reverse> — docreview_advice.route_step2 를 손으로 만든 항목으로 돌려
{f: [route, blocks]} 와 강제 기록(정렬)을 한 줄 JSON 으로 낸다. 같은 시나리오를 두 순서로 돌려 결과가 같은지 잰다.
축은 overdesign · data_flow 만 advisory 다(problem_definition · architecture 는 must-catch)."""
from __future__ import annotations

import json
import sys

sys.path.insert(0, sys.argv[1])
import docreview_advice as a  # noqa: E402

AXES = frozenset(("overdesign", "data_flow"))


def ask(f, cat, blocks):
    return {"f": f, "id": f, "lineage": f, "category": cat, "disposition": "ask", "blocks": list(blocks)}


def item(f, cat, disp, route=None):
    it = {"f": f, "id": f, "lineage": f, "category": cat, "disposition": disp}
    if route:
        it["route"] = route
    return it


SCENARIOS = {
    # advisory ask A → advisory ask B → advice decide C, 그리고 B 를 막는 must-catch ask M
    "chain": lambda: [ask("a", "data_flow", ["b"]), ask("b", "data_flow", ["c"]),
                      item("c", "overdesign", "decide", a.ROUTE_ADVICE), ask("m", "problem_definition", ["b"])],
    # must-catch ask X 가 advice 대상 하나 · must-catch fix 하나를 막는다 — 강제는 되지만 게이트는 안 바뀐다
    "mixed": lambda: [ask("x", "problem_definition", ["c", "d"]), item("c", "overdesign", "decide", a.ROUTE_ADVICE),
                      item("d", "architecture", "fix")],
    # advisory ask 둘이 서로를 막는다 — 어느 쪽도 advice 로 증명되지 않는다(차단 쪽으로 닫힌다)
    "cycle": lambda: [ask("p", "data_flow", ["q"]), ask("q", "data_flow", ["p"])],
}

final = SCENARIOS[sys.argv[2]]()
if sys.argv[3] == "reverse":
    final.reverse()
coerced = []


class L:
    @staticmethod
    def coerced(field, frm, to, gate=False):
        coerced.append([field, frm, to, bool(gate)])


a.route_step2(final, {}, AXES, 1, L, frozenset())
print(json.dumps({"items": {it["f"]: [it.get("route"), it.get("blocks")] for it in sorted(final, key=lambda x: x["f"])},
                  "coerced": sorted(coerced)}, ensure_ascii=False, sort_keys=True))
