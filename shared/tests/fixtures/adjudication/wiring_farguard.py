def f(items, ledger):
    out = []
    for it in items:
        if it.get("late"):
            ledger.absorbed(it, "elsewhere")
        if not isinstance(it, dict):
            continue          # 처분 호출은 «다른» 분기에 있다 — 잡혀야 한다
        out.append(it)
    return out
