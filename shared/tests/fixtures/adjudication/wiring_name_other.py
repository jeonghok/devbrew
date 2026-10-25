def f(items, ledger):
    out = []
    for it in items:
        if not isinstance(it, dict):
            print("hold", it)
            continue          # 처분 이름 글자를 넘겼을 뿐 원장과 무관한 함수 — 잡혀야 한다
        out.append(it)
    return out
