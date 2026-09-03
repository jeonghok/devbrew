# -*- coding: utf-8 -*-
"""L2 판정기 — 원장의 카운트가 소비자의 출력 경로에 실리는지.

요구 키를 «Ledger 자신에게서» 도출한다. 락에 열거하면 어휘가 늘어도 락이
조용하고, 그 침묵이 정확히 이 락이 막으려는 것이다.

문자열 «등장»이 아니라 AST 의 첨자/딕셔너리 키로만 센다. 주석 안의 키 이름이
소비로 읽히면 이 락은 검사가 아니라 장식이 된다.
"""
import ast
import io


def required_keys(repo_root):
    """`report()` 가 내는 카운트 키 전부 + `unknown_counts`."""
    import sys
    sys.path.insert(0, repo_root + "/shared/adjudication")
    from adjudication import Ledger
    rep = Ledger(items="open").report()
    return sorted(rep["counts"].keys()) + ["unknown_counts"]


def _string_keys(tree):
    """첨자(`x["k"]`)와 딕셔너리 리터럴 키로 «쓰인» 문자열만."""
    found = set()
    for n in ast.walk(tree):
        if isinstance(n, ast.Subscript):
            s = n.slice
            if isinstance(s, ast.Constant) and isinstance(s.value, str):
                found.add(s.value)
        elif isinstance(n, ast.Dict):
            for k in n.keys:
                if isinstance(k, ast.Constant) and isinstance(k.value, str):
                    found.add(k.value)
    return found


def missing(path, keys):
    tree = ast.parse(io.open(path, encoding="utf-8").read())
    found = _string_keys(tree)
    return [k for k in keys if k not in found]
