import sys
sys.path.insert(0, sys.argv[1] + "/shared/adjudication")
from adjudication import Ledger

L = Ledger(items="open")
L.suppressed("f1", "conf<=4")
r = L.report()
print("suppressed=%d" % r["counts"]["suppressed"])
print("rejected=%d" % r["counts"]["rejected"])
print("blocks=%s" % L.blocks())
print("degraded=%s" % r["degraded"])
