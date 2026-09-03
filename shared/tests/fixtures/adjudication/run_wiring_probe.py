import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "shared" / "adjudication"))
from check_wiring import scan  # noqa: E402

FX = root / "shared" / "tests" / "fixtures" / "adjudication"
for name in ("bad", "good", "farguard", "nested_if"):
    rows = scan([str(FX / ("wiring_%s.py" % name))])
    print("%s=%d" % (name, len([r for r in rows if not r["guarded"]])))

# 이중 계상은 「미배선 수」가 아니라 «행 수»로 잰다 — 두 번 세어도 둘 다
# 미배선이면 앞의 지표로는 안 보인다.
print("nested_loop_rows=%d"
      % len(scan([str(FX / "wiring_nested_loop.py")])))
