import ast
import io
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools" / "adjudication"))
from check_consumed import (  # noqa: E402
    _closure, _consumed_names, missing, required_keys)
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
self_sufficient = 0
for rel in union:
    miss = missing(str(root / rel), keys, str(root))
    total += len(miss)
    if miss:
        print("  UNCONSUMED %s: %s" % (rel, ", ".join(miss)))
    # 최종 리뷰 K4a — 폐포가 «자기 파일 + import 한 공유 모듈»이므로
    # `unconsumed_total=0` 은 소비자 다섯에 대한 다섯 개의 독립 단언이 아니다.
    # 자기 파일만으로 몇 키를 읽는지 따로 낸다 — 그 수가 낮을수록 그 소비자의
    # 통과는 «공유 모듈 하나»에 대한 단언의 사본이다.
    own = _consumed_names(ast.parse(io.open(root / rel, encoding="utf-8").read()))
    own_hit = [k for k in keys if k in own]
    if len(own_hit) == len(keys):
        self_sufficient += 1
    print("  OWNFILE %s own=%d/%d" % (rel, len(own_hit), len(keys)))
print("unconsumed_total=%d" % total)
print("self_sufficient=%d" % self_sufficient)

# 폐포가 어느 공유 모듈로 만족되는지 이름을 댄다 — 「그 한 파일」이 무엇인지
# 감추면 다음 독자는 다섯 개의 독립 증거를 읽었다고 믿는다.
for _m in sorted((root / "shared" / "adjudication").glob("*.py")):
    _got = _consumed_names(ast.parse(io.open(_m, encoding="utf-8").read()))
    print("  SHARED %s covers=%d/%d"
          % (_m.relative_to(root), len([k for k in keys if k in _got]), len(keys)))
