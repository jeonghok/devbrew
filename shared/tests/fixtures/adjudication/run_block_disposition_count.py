"""decision:"block" dict 리터럴 수와 처분 메서드 호출 수를 ast 로 센다.

Task 15 수정 라운드 1 (F1) — grep -c 기반 카운트(`\\.(hold|reject|...)\\(`)가
review-dispatch.py 의 `_block_with_ledger()` docstring 안 `` `L.reject(...)` ``
텍스트를 실제
호출로 오인해, 진짜 처분 호출 하나가 지워져도 ndisp 가 줄지 않았다(Task 15
변이 μ11 이 실측). ast 는 실제 `ast.Call`/`ast.Dict` 노드만 보므로 주석·
문자열 리터럴은 원리적으로 셀 수 없다.

`DISPOSITION` 은 `tools/adjudication/check_wiring.py` 의 정의를 그대로
쓴다 — 처분 메서드 어휘를 두 곳에 따로 적으면 한쪽만 늘 때 나머지가
조용해진다(이 리포가 반복해서 잡은 결함 모양).
"""
import ast
import sys
from pathlib import Path

REPO_ROOT = Path(sys.argv[1])
sys.path.insert(0, str(REPO_ROOT / "tools" / "adjudication"))
from check_wiring import DISPOSITION  # noqa: E402

FX = Path(__file__).parent


def count(path):
    tree = ast.parse(Path(path).read_text(encoding="utf-8"))
    nblock = 0
    for n in ast.walk(tree):
        if isinstance(n, ast.Dict):
            for k, v in zip(n.keys, n.values):
                if (isinstance(k, ast.Constant) and k.value == "decision"
                        and isinstance(v, ast.Constant) and v.value == "block"):
                    nblock += 1
    ndisp = sum(
        1 for n in ast.walk(tree)
        if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute)
        and n.func.attr in DISPOSITION
    )
    return nblock, ndisp


if len(sys.argv) > 2 and sys.argv[2] == "--emit-scanned":
    # 이 판정기 자신이 코퍼스로 갖는 것 — F6: check_wiring.py 를 import 하므로
    # 그 파일도 낸다.
    print("tools/adjudication/check_wiring.py")
    sys.exit(0)

gb, gd = count(FX / "block_disposition_good.py")
print("fx_good_nblock=%d" % gb)
print("fx_good_ndisp=%d" % gd)

db, dd = count(FX / "block_disposition_decoy.py")
print("fx_decoy_nblock=%d" % db)
print("fx_decoy_ndisp=%d" % dd)

if len(sys.argv) > 2:
    tb, td = count(sys.argv[2])
    print("target_nblock=%d" % tb)
    print("target_ndisp=%d" % td)
