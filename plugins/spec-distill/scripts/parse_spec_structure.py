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


LD_FIELDS = ("id", "section", "summary", "source")


def validate_locked_decisions(text: str) -> list[str]:
    """Each LD entry must have id/section/summary/source. Returns error list."""
    errors: list[str] = []
    m = FRONTMATTER_RE.match(text)
    if not m:
        return errors  # no frontmatter → design mode → no LD constraint
    body = m.group(1)
    # Locate `locked_decisions:` block and its entries (lines starting with "  - id:")
    in_block = False
    entries: list[dict] = []
    current: dict = {}
    for line in body.split("\n"):
        if re.match(r"^locked_decisions\s*:\s*\[\s*\]\s*$", line):
            return errors  # explicitly empty
        if re.match(r"^locked_decisions\s*:\s*$", line):
            in_block = True
            continue
        if in_block:
            if re.match(r"^[a-zA-Z_]", line):  # next top-level key → block end
                if current:
                    entries.append(current)
                break
            m_id = re.match(r"^\s*-\s*id\s*:\s*(.+)$", line)
            m_field = re.match(r"^\s+([a-z_]+)\s*:\s*(.+)$", line)
            if m_id:
                if current:
                    entries.append(current)
                current = {"id": m_id.group(1).strip()}
            elif m_field:
                key = m_field.group(1).strip()
                val = m_field.group(2).strip()
                current[key] = val
    if current:
        entries.append(current)
    for idx, entry in enumerate(entries):
        for f in LD_FIELDS:
            if f not in entry or not entry[f]:
                errors.append(f"LD[{idx}] missing required field '{f}'")
    return errors


def cmd_locked_decisions(path: Path) -> int:
    text = path.read_text(encoding="utf-8")
    print(json.dumps({"errors": validate_locked_decisions(text)}))
    return 0


def load_blacklist(blacklist_path: Path) -> list[str]:
    patterns: list[str] = []
    for raw in blacklist_path.read_text(encoding="utf-8").split("\n"):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        patterns.append(line)
    return patterns


def scan_ambiguity(text: str, patterns: list[str]) -> list[dict]:
    """Find lines containing any blacklisted phrase. `~phrase` opt-out applies
    to that specific occurrence (match must NOT be preceded by `~`).
    """
    hits: list[dict] = []
    for lineno, line in enumerate(text.split("\n"), start=1):
        for phrase in patterns:
            # Search for phrase, ensure the character immediately before is not `~`
            for m in re.finditer(re.escape(phrase), line, flags=re.IGNORECASE):
                start = m.start()
                if start > 0 and line[start - 1] == "~":
                    continue
                hits.append({"line": lineno, "phrase": phrase, "text": line})
                break  # one hit per phrase per line is enough
    return hits


def cmd_ambiguity(path: Path, blacklist_path: Path) -> int:
    text = path.read_text(encoding="utf-8")
    patterns = load_blacklist(blacklist_path)
    print(json.dumps({"hits": scan_ambiguity(text, patterns)}))
    return 0


PLACEHOLDER_TOKENS = ("TBD", "TODO", "FIXME", "<placeholder>")


def scan_placeholders(text: str) -> list[dict]:
    """Find lines containing placeholder tokens. Frontmatter and `~`-escaped
    occurrences are excluded."""
    hits: list[dict] = []
    # Skip frontmatter
    m = FRONTMATTER_RE.match(text)
    body_start = m.end() if m else 0
    offset_line = text[:body_start].count("\n")
    body = text[body_start:]
    for idx, line in enumerate(body.split("\n"), start=offset_line + 1):
        for token in PLACEHOLDER_TOKENS:
            for m2 in re.finditer(re.escape(token), line):
                start = m2.start()
                if start > 0 and line[start - 1] == "~":
                    continue
                hits.append({"line": idx, "token": token, "text": line})
                break
    return hits


def cmd_placeholders(path: Path) -> int:
    text = path.read_text(encoding="utf-8")
    print(json.dumps({"hits": scan_placeholders(text)}))
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
    if sub == "locked-decisions":
        return cmd_locked_decisions(Path(argv[2]))
    if sub == "ambiguity":
        return cmd_ambiguity(Path(argv[2]), Path(argv[3]))
    if sub == "placeholders":
        return cmd_placeholders(Path(argv[2]))
    print(f"unknown subcommand: {sub}", file=sys.stderr)
    return 64


if __name__ == "__main__":
    sys.exit(main(sys.argv))
