import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools" / "adjudication"))
from check_consumed import _closure, missing, required_keys  # noqa: E402
from check_wiring import derive_consumers  # noqa: E402

# `--emit-scanned` — test_guards_coverage_bidirectional.sh 가 읽는다. 코퍼스는
# union(소비자 파일) + 그 파일들이 실제로 import 하는 shared/adjudication/
# 모듈들이다(§ check_consumed.py 의 `_closure()` 도크스트링) — 같은 함수를
# 그대로 다시 호출한다(재도출 아님).
if len(sys.argv) > 2 and sys.argv[2] == "--emit-scanned":
    _union, _, _ = derive_consumers(str(root))
    _corpus = set()
    for _rel in _union:
        for _f in _closure(str(root / _rel), str(root)):
            _corpus.add(str(Path(_f).relative_to(root)))
    for _p in sorted(_corpus):
        print(_p)
    sys.exit(0)

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
