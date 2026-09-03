import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools" / "adjudication"))
from check_wiring import scan  # noqa: E402

FX = root / "shared" / "tests" / "fixtures" / "adjudication"
for name in ("bad", "good", "farguard", "nested_if", "except_guard"):
    rows = scan([str(FX / ("wiring_%s.py" % name))])
    print("%s=%d" % (name, len([r for r in rows if not r["guarded"]])))

# 이중 계상은 「미배선 수」가 아니라 «행 수»로 잰다 — 두 번 세어도 둘 다
# 미배선이면 앞의 지표로는 안 보인다.
print("nested_loop_rows=%d"
      % len(scan([str(FX / "wiring_nested_loop.py")])))

# while 경계도 «행 수»로 잰다 — while 안의 버리는 분기는 바깥 for 의 인구가
# 아니므로 귀속 자체가 없어야 한다(guarded 여부가 아니라 행이 아예 안 나옴).
print("while_boundary_rows=%d"
      % len(scan([str(FX / "wiring_while_boundary.py")])))
