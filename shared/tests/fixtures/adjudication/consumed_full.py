def emit(report):
    c = report["counts"]
    return "a=%d r=%d h=%d ab=%d co=%d sf=%d su=%d u=%s" % (
        c["accepted"], c["rejected"], c["held"], c["absorbed"],
        c["coerced"], c["sources_failed"], c["suppressed"],
        report["unknown_counts"])
