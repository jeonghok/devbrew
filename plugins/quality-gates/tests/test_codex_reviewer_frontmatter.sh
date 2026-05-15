#!/usr/bin/env bash
# Validates codex-reviewer.md frontmatter compliance with AC9 (3-layer
# isolation) and AC11 (narrow Bash allowlist). Section-aware checks via
# inline Python YAML parsing.

set -u

FILE="$(cd "$(dirname "$0")/.." && pwd)/agents/codex-reviewer.md"

python3 - "$FILE" <<'PYEOF'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
md = path.read_text(encoding="utf-8")

m = re.match(r"^---\n(.*?)\n---", md, re.DOTALL)
if not m:
    print("FAIL: no YAML frontmatter found", file=sys.stderr)
    sys.exit(2)

try:
    import yaml
    data = yaml.safe_load(m.group(1))
except ImportError:
    # Tiny ad-hoc YAML parser fallback when pyyaml is absent.
    data = {}
    current_key = None
    for line in m.group(1).splitlines():
        if not line.strip():
            continue
        if not line.startswith(" "):
            key, _, val = line.partition(":")
            current_key = key.strip()
            val = val.strip()
            data[current_key] = val if val else []
        elif line.lstrip().startswith("- "):
            item = line.lstrip()[2:].strip()
            if isinstance(data.get(current_key), list):
                data[current_key].append(item)

passes = 0
fails = 0

def assert_eq(condition, msg):
    global passes, fails
    if condition:
        passes += 1
        print(f"  PASS: {msg}")
    else:
        fails += 1
        print(f"  FAIL: {msg}")

# AC9 Layer 1 — disallowedTools must include all 5
disallowed = set(data.get("disallowedTools") or [])
for tool in ("Write", "Edit", "MultiEdit", "NotebookEdit", "Glob"):
    assert_eq(tool in disallowed, f"{tool} in disallowedTools")

# AC9 Layer 2 / AC11 — allowedTools is the narrow whitelist
allowed = data.get("allowedTools") or []
# Required entries
required_allowed = ["Bash(codex exec*)", "Bash(python3 *)"]
for tool in required_allowed:
    assert_eq(tool in allowed, f"{tool} present in allowedTools")

# Banned entries — must NOT be in allowedTools
banned_in_allowed = ["Bash(cat *)", "Bash(echo *)", "Bash", "Write", "Edit", "MultiEdit"]
for tool in banned_in_allowed:
    assert_eq(tool not in allowed, f"{tool} NOT in allowedTools (would weaken isolation)")

# Standard plugin shape — cost_class declared
assert_eq("cost_class" in data, "cost_class declared")

# Standard plugin shape — name + description
assert_eq("name" in data and data["name"] == "codex-reviewer", "name == codex-reviewer")
assert_eq("description" in data and bool(data["description"]), "description present")

print()
print(f"Total: {passes + fails}, PASS: {passes}, FAIL: {fails}")
sys.exit(0 if fails == 0 else 1)
PYEOF
