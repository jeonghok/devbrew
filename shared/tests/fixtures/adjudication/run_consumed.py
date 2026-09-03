import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools" / "adjudication"))
from check_consumed import missing, required_keys  # noqa: E402
from check_wiring import derive_consumers  # noqa: E402

FX = root / "shared" / "tests" / "fixtures" / "adjudication"
keys = required_keys(str(root))
print("keys=%d" % len(keys))
print("  KEYS %s" % ", ".join(keys))

print("fx_partial_missing=%d"
      % len(missing(str(FX / "consumed_partial.py"), keys, str(root))))
print("fx_full_missing=%d"
      % len(missing(str(FX / "consumed_full.py"), keys, str(root))))
# 오검출 회귀 — 딕셔너리 리터럴 «키»만으로는 만족되지 않는다.
print("fx_dictkey_missing=%d"
      % len(missing(str(FX / "consumed_dictkey.py"), keys, str(root))))

union, _, _ = derive_consumers(str(root))
print("consumers=%d" % len(union))
total = 0
for rel in union:
    miss = missing(str(root / rel), keys, str(root))
    total += len(miss)
    if miss:
        print("  UNCONSUMED %s: %s" % (rel, ", ".join(miss)))
print("unconsumed_total=%d" % total)
