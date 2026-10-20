"""흡수 분기의 배선 — 라우터의 두 흡수 분기가 처분 호출을 갖는지, 그 호출을 지우면 락이 잡는지 잰다.

사용법: run_wiring_absorb.py <repo-root> <scratch-dir>
"""
import ast
import sys
from pathlib import Path

root = Path(sys.argv[1])
scratch = Path(sys.argv[2])
sys.path.insert(0, str(root / "tools" / "adjudication"))
from check_wiring import scan  # noqa: E402

SRC = root / "shared" / "docreview" / "scripts" / "docreview_route.py"

rows = scan([str(SRC)])
merge_cont = []
for r in rows:
    if r["func"] == "merge_list_blocks" and r["kind"] == "continue":
        merge_cont.append(r)
prep_first = []
for r in rows:
    if r["func"] == "cmd_prepare" and "first" in r["guard"]:
        prep_first.append(r)
print("merge_continue_rows=%d" % len(merge_cont))
print("merge_continue_unguarded=%d" % len([r for r in merge_cont if not r["guarded"]]))
print("prepare_first_rows=%d" % len(prep_first))
print("prepare_first_guarded=%d" % len([r for r in prep_first if r["guarded"]]))


def mutant(func, test_has, name):
    """`func` 안에서 `test_has` 를 포함한 조건의 분기 본문에 있는 `ev("absorbed", …)` 줄을 `pass` 로 바꾼 사본을 쓴다."""
    text = SRC.read_text(encoding="utf-8")
    tree = ast.parse(text)
    lines = text.split("\n")
    hit = 0
    for fn in ast.walk(tree):
        if not (isinstance(fn, ast.FunctionDef) and fn.name == func):
            continue
        for node in ast.walk(fn):
            if not (isinstance(node, ast.If) and test_has in ast.unparse(node.test)):
                continue
            for stmt in node.body:
                call = stmt.value if isinstance(stmt, ast.Expr) else None
                if (isinstance(call, ast.Call) and isinstance(call.func, ast.Name) and call.func.id == "ev"
                        and call.args and isinstance(call.args[0], ast.Constant) and call.args[0].value == "absorbed"):
                    indent = " " * stmt.col_offset
                    lines[stmt.lineno - 1] = indent + "pass"
                    for k in range(stmt.lineno, stmt.end_lineno):
                        lines[k] = ""
                    hit += 1
    out = scratch / name
    out.write_text("\n".join(lines), encoding="utf-8")
    return out, hit


for func, test_has, name, tag in (
        ("merge_list_blocks", "key in seen_items", "mutant_merge.py", "merge"),
        ("cmd_prepare", "detector", "mutant_prepare.py", "prepare")):
    path, hit = mutant(func, test_has, name)
    mrows = scan([str(path)])
    bad = [r for r in mrows if r["func"] == func and not r["guarded"]]
    print("mutant_%s_removed=%d" % (tag, hit))
    print("mutant_%s_unwired=%d" % (tag, len(bad)))
