import sys
from collections import Counter
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools" / "adjudication"))
import check_slots  # noqa: E402

FX = root / "shared" / "tests" / "fixtures" / "adjudication"
for name in ("match", "undeclared", "undelivered", "forbidden", "suspectvar"):
    probs = check_slots.check(str(FX / ("slots_%s" % name)))
    print("fx_%s=%d" % (name, len(probs)))

defs = check_slots.agents(str(root))
print("agents=%d" % len(defs))
probs = check_slots.check(str(root))
kinds = Counter(p[0] for p in probs)
print("no_declaration=%d" % kinds.get("no_declaration", 0))
print("problems_other=%d" % (len(probs) - kinds.get("no_declaration", 0)))
for p in probs:
    if p[0] != "no_declaration":
        print("  PROBLEM %s %s @ %s %s" % p)
print("exempt_total=%d" % len(check_slots.EXEMPT_SLOTS))
print("exempt_uncited=%d" % len(check_slots.uncited_exemptions()))
