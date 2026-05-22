#!/usr/bin/env bash
# resolve_mode() scope 확대 단위 테스트 (AC2 회귀 + AC3–AC7).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
python3 - <<'PY'
import sys, tempfile, os, io, contextlib
from pathlib import Path
import importlib.util
spec = importlib.util.spec_from_file_location(
    "v", "plugins/spec-distill/hooks/spec-write-validator.py")
v = importlib.util.module_from_spec(spec); spec.loader.exec_module(v)

base = Path(tempfile.mkdtemp()) / "docs" / "superpowers" / "specs"
base.mkdir(parents=True)
def mk(name, body=""):
    p = base / name; p.write_text(body, encoding="utf-8"); return str(p)

# AC1/AC2
assert v.resolve_mode(mk("x-spec.md")) == "spec"
assert v.resolve_mode(mk("x-design.md")) == "design"
# AC3 — frontmatter에 locked_decisions → spec
assert v.resolve_mode(mk("foo.md", "---\nname: t\nlocked_decisions: []\n---\n")) == "spec"
# AC4 — frontmatter에 locked_decisions 없음 → design
assert v.resolve_mode(mk("bar.md", "---\nname: t\n---\n")) == "design"
# AC4 (body-only) — body에만 → design
assert v.resolve_mode(mk("bodyonly.md", "---\nname: t\n---\n\n## s\nlocked_decisions: []\n")) == "design"
# AC4 (unclosed) — 닫는 --- 없음 → design (locked_decisions 있어도)
assert v.resolve_mode(mk("unclosed.md", "---\nname: t\nlocked_decisions: []\n")) == "design"
# AC5 — prefix 아래 .md 아님 → None ; prefix 밖 → None
assert v.resolve_mode(mk("baz.txt")) is None
assert v.resolve_mode(mk("q.markdown")) is None
assert v.resolve_mode("/elsewhere/foo.md") is None
# AC6 — 디코드 실패(바이너리) → design + stderr loud
binp = base / "bin.md"; binp.write_bytes(b"\xff\xfe\x00\x01 not utf8")
err = io.StringIO()
with contextlib.redirect_stderr(err):
    assert v.resolve_mode(str(binp)) == "design"
assert "[spec-distill]" in err.getvalue() and "bin.md" in err.getvalue()
# AC7 + AC2 회귀 — DESIGN_MODE_DISABLE
os.environ["DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE"] = "1"
assert v.resolve_mode(mk("z-design.md")) is None
assert v.resolve_mode(mk("nolocked.md", "---\nname: t\n---\n")) is None
assert v.resolve_mode(mk("locked.md", "---\nlocked_decisions: []\n---\n")) == "spec"
del os.environ["DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE"]
print("test_resolve_mode_scope: ALL PASS")
PY
