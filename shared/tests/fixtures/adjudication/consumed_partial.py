def emit(report):
    # `held` 만 읽는다 — 오늘의 프로덕션과 같은 모양
    return "held=%d" % report["counts"]["held"]
