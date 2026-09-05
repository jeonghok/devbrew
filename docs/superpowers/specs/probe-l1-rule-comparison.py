# -*- coding: utf-8 -*-
"""L1 후보 규칙 둘을 같은 코퍼스에 돌려 무엇을 잡고 무엇을 놓치는지 실측한다.

규칙 A (설계 round 2 판본) — 함수가 ledger 를 **인자로 받거나** 모듈 수준에서 접근.
규칙 B (리뷰어 대안)       — 함수 안에서 ledger 처분 메서드가 **한 번이라도** 불림.

둘 다에 대해: 그 함수 안의 for 루프에서 `continue` 로 끝나는 경로 중
같은 분기에 처분 호출이 없는 것을 센다.
"""
import ast
import io
import sys

DISPOSITION = {"accept", "reject", "hold", "absorbed", "coerced",
               "source_failed", "uncountable", "suppressed"}

FILES = [
    "plugins/quality-gates/scripts/synthesize_findings.py",
    "plugins/quality-gates/scripts/synthesize_artifact_findings.py",
    "plugins/spec-distill/scripts/merge_review.py",
    "plugins/spec-distill/scripts/merge_brief_review.py",
]


def disposition_calls(node):
    """이 서브트리 안의 ledger 처분 호출 (obj.method(...) 형태)."""
    out = []
    for n in ast.walk(node):
        if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute):
            if n.func.attr in DISPOSITION:
                out.append(n)
    return out


def builds_ledger(node):
    for n in ast.walk(node):
        if isinstance(n, ast.Call) and isinstance(n.func, ast.Name) \
                and n.func.id == "Ledger":
            return True
    return False


def ledger_param_names(fn):
    names = set()
    for a in list(fn.args.args) + list(fn.args.kwonlyargs):
        if a.arg.lower() in ("ledger", "l", "led"):
            names.add(a.arg)
    return names


def analyse(path):
    src = io.open(path, encoding="utf-8").read()
    tree = ast.parse(src)
    fns = [n for n in ast.walk(tree)
           if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))]

    sel_a, sel_b = [], []
    for fn in fns:
        if ledger_param_names(fn):
            sel_a.append(fn)
        if disposition_calls(fn):
            sel_b.append(fn)

    def bare_continues(fnlist):
        """선택된 함수들의 for 루프 안에서, 같은 분기에 처분 호출이 없는 continue."""
        hits = []
        for fn in fnlist:
            for loop in [n for n in ast.walk(fn) if isinstance(n, ast.For)]:
                for n in ast.walk(loop):
                    if not isinstance(n, ast.Continue):
                        continue
                    # 이 continue 를 감싸는 가장 가까운 If 본문(=같은 분기)을 찾는다
                    branch = None
                    for anc in ast.walk(loop):
                        if isinstance(anc, ast.If):
                            for body in (anc.body, anc.orelse):
                                if any(x is n for stmt in body
                                       for x in ast.walk(stmt)):
                                    branch = body
                    scope = branch if branch is not None else loop.body
                    guarded = any(disposition_calls(s) for s in scope)
                    if not guarded:
                        hits.append(n.lineno)
        return sorted(set(hits))

    return {
        "file": path,
        "builds_local_ledger": builds_ledger(tree),
        "rule_A_functions": sorted({f.name for f in sel_a}),
        "rule_B_functions": sorted({f.name for f in sel_b}),
        "rule_A_bare_continue_lines": bare_continues(sel_a),
        "rule_B_bare_continue_lines": bare_continues(sel_b),
    }


for f in FILES:
    r = analyse(f)
    print("=" * 70)
    print(r["file"])
    print("  Ledger 를 로컬로 만드나:", r["builds_local_ledger"])
    print("  규칙 A 가 고른 함수:", r["rule_A_functions"] or "— 없음")
    print("  규칙 B 가 고른 함수:", r["rule_B_functions"] or "— 없음")
    print("  규칙 A 가 잡는 무방비 continue:", r["rule_A_bare_continue_lines"] or "— 없음")
    print("  규칙 B 가 잡는 무방비 continue:", r["rule_B_bare_continue_lines"] or "— 없음")
