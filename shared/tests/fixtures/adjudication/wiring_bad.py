def f(items, ledger):
    out = []
    for it in items:
        if not isinstance(it, dict):
            continue          # 처분 호출 없음 — 잡혀야 한다
        out.append(it)
    return out
