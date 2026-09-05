def f(items, ledger):
    out = []
    for it in items:
        try:
            out.append(process(it))
        except ValueError:
            ledger.reject(it, "파싱 실패")
            continue          # 같은 except 본문에 처분 호출 — 통과해야 한다
    return out
