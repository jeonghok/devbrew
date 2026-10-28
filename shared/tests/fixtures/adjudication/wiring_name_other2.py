def f(items, note):
    out = []
    for it in items:
        if not isinstance(it, dict):
            note("absorbed", it)
            continue          # 원장 전달자가 아닌 이름이 처분 이름 글자를 넘겼다 — 잡혀야 한다
        out.append(it)
    return out
