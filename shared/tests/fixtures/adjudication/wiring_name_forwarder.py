def f(items, ev):
    out = []
    for it in items:
        if not isinstance(it, dict):
            ev("hold", repr(it), "항목 파손: not a mapping")
            continue          # 원장으로 넘기는 이름(ev)의 처분 호출 — 통과해야 한다
        out.append(it)
    return out
