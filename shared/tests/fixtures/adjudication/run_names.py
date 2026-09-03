import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools" / "adjudication"))
import check_names  # noqa: E402

FX = root / "shared" / "tests" / "fixtures" / "adjudication"
known = check_names.defined(str(root))
print("defined=%d" % len(known))

# fixture 는 코퍼스 밖이므로 참조 추출만 직접 돌린다.
plugins = {p.name for p in (root / "plugins").glob("*") if p.is_dir()}
for name in ("stale", "ok", "prose"):
    text = (FX / ("names_%s.md" % name)).read_text(encoding="utf-8")
    hits = [m for m in check_names._REF_RE.finditer(text)
            if m.group(1) in plugins]
    bad = [m.group(0) for m in hits
           if "%s:%s" % (m.group(1), m.group(2)) not in known]
    print("fx_%s=%d" % (name, len(bad)))

refs = check_names.references(str(root))
print("refs=%d" % len(refs))
dang = check_names.dangling(str(root))
print("dangling=%d" % len(dang))
for (path, line, tok) in dang:
    print("  DANGLING %s:%d %s" % (path, line, tok))
