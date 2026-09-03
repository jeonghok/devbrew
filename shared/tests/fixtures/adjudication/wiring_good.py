def f(items, ledger):
    out = []
    for it in items:
        if not isinstance(it, dict):
            ledger.hold(repr(it), "항목 파손: not a mapping")
            continue          # 같은 분기에 처분 호출 — 통과해야 한다
        out.append(it)
    return out
