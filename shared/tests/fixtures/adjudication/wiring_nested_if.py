def f(items, ledger):
    out = []
    for it in items:
        if it.get("outer"):
            ledger.accept(it)     # 안쪽 if 의 형제가 아니라 «바깥» 분기에 있다
            if it.get("inner"):
                a = 1
                b = 2
                c = 3
                continue          # 안쪽 조건으로 한 번 더 걸렸다 — 잡혀야 한다
        out.append(it)
    return out
