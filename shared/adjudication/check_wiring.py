# -*- coding: utf-8 -*-
"""L1 판정기 — 버리는 분기가 처분 호출을 갖는지.

대상은 파일의 «모든» `for` 문이다. 「처분 메서드가 불리는 함수」로 좁히면 전혀
배선되지 않은 버리기가 영원히 안 보이고, 모집단이 피검자 손에 들어간다.

컴프리헨션은 대상이 아니다 — 표현식 안에 문장을 넣을 수 없어 「처분을 부르라」는
요구가 문법상 성립하지 않는다. 대신 개수를 세어 호출자가 회귀로 잡게 한다.
"""
import ast
import io

DISPOSITION = frozenset((
    "accept", "reject", "hold", "absorbed", "coerced",
    "source_failed", "uncountable", "suppressed",
))

DISCARD_NODES = (ast.Continue, ast.Break, ast.Return)


def _disposition_calls(node):
    return [n for n in ast.walk(node)
            if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute)
            and n.func.attr in DISPOSITION]


def _enclosing_branch(loop, target):
    """`target` 을 직접 감싸는 가장 «안쪽» If 본문. 없으면 None.

    바깥 If 를 고르면 scope 가 넓어져 무관한 처분 호출이 이 분기를 guarded 로
    만든다 — fail-open 이다. 그래서 후보 중 가장 짧은 것을 고른다.
    """
    best = None
    for anc in ast.walk(loop):
        if not isinstance(anc, ast.If):
            continue
        for body in (anc.body, anc.orelse):
            if any(x is target for stmt in body for x in ast.walk(stmt)):
                if best is None or len(body) < len(best):
                    best = body
    return best


def _func_of(tree, node):
    for fn in ast.walk(tree):
        if isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef)):
            if any(x is node for x in ast.walk(fn)):
                return fn.name
    return "<module>"


def scan(paths):
    """버리는 분기 전수. 각 항목은 guarded 여부를 함께 낸다."""
    out = []
    for path in paths:
        tree = ast.parse(io.open(path, encoding="utf-8").read())
        loops = [n for n in ast.walk(tree)
                 if isinstance(n, (ast.For, ast.AsyncFor))]
        for loop in loops:
            for n in ast.walk(loop):
                if not isinstance(n, DISCARD_NODES):
                    continue
                branch = _enclosing_branch(loop, n)
                # 분기를 못 찾으면 루프 본문 전체로 넓히지 «않는다» — 그것이
                # 루프 최상위의 맨 continue 를 guarded 로 읽는 fail-open 이다.
                scope = branch if branch is not None else [n]
                out.append({
                    "file": path,
                    "line": n.lineno,
                    "kind": type(n).__name__.lower(),
                    "func": _func_of(tree, n),
                    "guarded": any(_disposition_calls(s) for s in scope),
                })
    return out


def comprehension_count(paths):
    """컴프리헨션 내포 수 — 요구가 아니라 회귀 축이다."""
    total = 0
    for path in paths:
        tree = ast.parse(io.open(path, encoding="utf-8").read())
        total += sum(
            len(n.generators) for n in ast.walk(tree)
            if isinstance(n, (ast.ListComp, ast.SetComp,
                              ast.DictComp, ast.GeneratorExp)))
    return total
