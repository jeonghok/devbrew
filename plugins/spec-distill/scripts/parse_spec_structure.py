#!/usr/bin/env python3
"""spec-distill — Spec/design structure parser library.

CLI subcommand interface so bash tests and hook scripts can invoke
specific checks deterministically:

  parse_spec_structure.py frontmatter <path>   # JSON
  parse_spec_structure.py sections <path>      # JSON (missing list)
  parse_spec_structure.py locked-decisions <path>  # JSON (errors list)
  parse_spec_structure.py ambiguity <path> <blacklist_path>  # JSON (hits)
  parse_spec_structure.py placeholders <path>  # JSON (hits)
"""
import json
import re
import sys
from pathlib import Path


FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n", re.DOTALL)

# 11 required sections (anchor form for output mapping)
REQUIRED_SECTIONS = [
    ("Goal", "#goal"),
    ("Context", "#context"),
    ("Goals", "#goals"),
    ("Non-goals", "#non-goals"),
    ("Constraints", "#constraints"),
    ("Acceptance Criteria", "#acceptance-criteria"),
    ("Files to Modify", "#files-to-modify"),
    ("Verification Plan", "#verification-plan"),
    ("Rejected Alternatives", "#rejected-alternatives"),
    ("Open Questions", "#open-questions"),
    ("Concrete Next Action", "#concrete-next-action"),
]


def find_missing_sections(text: str) -> list[str]:
    """Return anchor list for sections whose `## <title>` header is absent.

    'Context' matches both `## Context` and `## Context / Why`. Match is
    case-insensitive on the section title.
    """
    missing = []
    for title, anchor in REQUIRED_SECTIONS:
        pattern = re.compile(rf"^##\s+{re.escape(title)}\b", re.MULTILINE | re.IGNORECASE)
        if not pattern.search(text):
            missing.append(anchor)
    return missing


def cmd_sections(path: Path) -> int:
    text = path.read_text(encoding="utf-8")
    missing = find_missing_sections(text)
    print(json.dumps({"missing": missing}))
    return 0


def parse_frontmatter(text: str) -> dict:
    """Parse YAML-ish frontmatter into a flat dict. Returns {} if absent."""
    m = FRONTMATTER_RE.match(text)
    if not m:
        return {}
    body = m.group(1)
    out: dict = {}
    current_list_key = None
    for line in body.split("\n"):
        if not line.strip():
            continue
        if line.startswith("  - ") or line.startswith("    "):
            if current_list_key is not None:
                out.setdefault(current_list_key, []).append(line.rstrip())
            continue
        if ":" in line:
            key, _, value = line.partition(":")
            key = key.strip()
            value = value.strip()
            if value == "":
                current_list_key = key
                out[key] = []
            else:
                current_list_key = None
                if value.startswith(("'", '"')) and value.endswith(value[0]):
                    value = value[1:-1]
                out[key] = value
    return out


def cmd_frontmatter(path: Path) -> int:
    text = path.read_text(encoding="utf-8")
    print(json.dumps(parse_frontmatter(text)))
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: parse_spec_structure.py <subcommand> <args>", file=sys.stderr)
        return 64
    sub = argv[1]
    if sub == "frontmatter":
        return cmd_frontmatter(Path(argv[2]))
    if sub == "sections":
        return cmd_sections(Path(argv[2]))
    print(f"unknown subcommand: {sub}", file=sys.stderr)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv))
