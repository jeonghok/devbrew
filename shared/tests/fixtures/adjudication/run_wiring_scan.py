import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools" / "adjudication"))
from check_wiring import (  # noqa: E402
    EXEMPT, comprehension_count, derive_consumers, scan)

union, by_import, by_anchor = derive_consumers(str(root))
print("union=%d" % len(union))
print("import=%d" % len(by_import))
print("anchor=%d" % len(by_anchor))
for p in union:
    print("  CONSUMER %s" % p)

abs_paths = [str(root / p) for p in union]
rows = scan(abs_paths)
unwired = []
for r in rows:
    rel = str(Path(r["file"]).relative_to(root))
    if r["guarded"]:
        continue
    if (rel, r["line"]) in EXEMPT:
        continue
    unwired.append((rel, r["line"], r["kind"], r["func"]))
print("unwired=%d" % len(unwired))
for (rel, line, kind, func) in unwired:
    print("  UNWIRED %s:%d %s in %s" % (rel, line, kind, func))

print("exempt_total=%d" % len(EXEMPT))
print("exempt_uncited=%d" % len([v for v in EXEMPT.values()
                                 if "C6" not in str(v)]))
print("comprehensions=%d" % comprehension_count(abs_paths))
