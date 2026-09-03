def f(groups, ledger):
    out = []
    for g in groups:
        for it in g:
            if not isinstance(it, dict):
                continue          # 이 «한» 문장이 한 번만 세어져야 한다
            out.append(it)
    return out
