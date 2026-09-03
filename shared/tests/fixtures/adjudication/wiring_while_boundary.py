def f(items, ledger):
    out = []
    for it in items:
        j = 0
        while j < len(it):
            if not it[j]:
                break          # while 의 버리는 분기 — 바깥 for 의 인구가 아니다
            j += 1
        out.append(it)
    return out
