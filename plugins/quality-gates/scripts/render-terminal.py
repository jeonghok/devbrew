#!/usr/bin/env python3
"""render-terminal.py — shared scannable terminal renderer (design §9).

Subcommands:
  table --title T   : read `key<TAB>value` lines from stdin → aligned STATUS table.
  diagram           : read a diagram-facts.sh block from stdin → ASCII (same facts
                      as the artifact's mermaid → single source of truth, no drift).
  accuracy-warnings : (added in Task 5) compare artifact claims vs facts/changed-set.

Deterministic, no network, no gh. ≤~100 columns.
"""
from __future__ import annotations
import argparse
import re
import sys

RULE = "─" * 56


def _read_facts(text: str):
    nodes, edges, section = [], [], None
    for line in text.splitlines():
        s = line.strip()
        if s == "nodes:":
            section = "n"; continue
        if s == "edges:":
            section = "e"; continue
        if s.startswith("degraded:"):
            section = None; continue
        if not s:
            continue
        if section == "n":
            nodes.append(s)
        elif section == "e":
            edges.append(s)
    return nodes, edges


def cmd_table(args) -> int:
    rows = []
    for line in sys.stdin.read().splitlines():
        if "\t" in line:
            k, v = line.split("\t", 1)
            rows.append((k.strip(), v.strip()))
    width = max((len(k) for k, _ in rows), default=0)
    print(f"── {args.title} " + "─" * max(0, 52 - len(args.title)))
    for k, v in rows:
        print(f"{k.ljust(width)}   {v}")
    print(RULE)
    return 0


def cmd_diagram(_args) -> int:
    nodes, edges = _read_facts(sys.stdin.read())
    print("nodes:")
    for n in nodes:
        print(f"  [{n}]")
    print("edges:")
    for e in edges:
        print(f"  {e}")
    return 0


def cmd_accuracy_warnings(args) -> int:
    artifact = open(args.artifact, encoding="utf-8", errors="replace").read()
    facts_nodes, _ = _read_facts(open(args.facts, encoding="utf-8", errors="replace").read())
    changed = {l.strip() for l in open(args.changed, encoding="utf-8", errors="replace")
               if l.strip()}
    node_paths = set(facts_nodes)
    warnings = []

    # 1) mermaid node referencing a repo path not in diagram-facts
    in_mermaid = False
    for line in artifact.splitlines():
        if line.strip().startswith("```mermaid"):
            in_mermaid = True; continue
        if in_mermaid and line.strip().startswith("```"):
            in_mermaid = False; continue
        if in_mermaid:
            for m in re.findall(r"[\w./-]+\.\w+", line):
                if ("/" in m or m.endswith((".py", ".ts", ".js", ".sh", ".go", ".rb"))) \
                   and m not in node_paths:
                    warnings.append(f"warning: possible hallucinated node: {m}")

    # 2) structure-table row marked NEW/changed but file not in changed-set
    for line in artifact.splitlines():
        if "|" in line and re.search(r"(?i)\b(NEW|changed|added|추가|신규)\b", line):
            for m in re.findall(r"[\w./-]+\.\w+", line):
                if ("/" in m or "." in m) and m not in changed and m not in node_paths:
                    warnings.append(f"warning: possible hallucinated file: {m}")

    # 3) Testing section claims tests but no changed test file exists
    has_test_change = any(re.search(r"(^|/)test_|_test\.|\.test\.|/tests?/", c) for c in changed)
    m = re.search(r"(?is)\*\*Testing\*\*.*?(?=\n\*\*|\Z)", artifact)
    if m and not has_test_change:
        body = m.group(0)
        if re.search(r"(?i)\btest", body) and not re.search(r"No tests in this PR", body):
            warnings.append("warning: unverified testing claim (no changed test file)")

    seen = set()
    for w in warnings:
        if w not in seen:
            seen.add(w); print(w)
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    t = sub.add_parser("table"); t.add_argument("--title", required=True); t.set_defaults(fn=cmd_table)
    d = sub.add_parser("diagram"); d.set_defaults(fn=cmd_diagram)
    w = sub.add_parser("accuracy-warnings")
    w.add_argument("--artifact", required=True)
    w.add_argument("--facts", required=True)
    w.add_argument("--changed", required=True)
    w.set_defaults(fn=cmd_accuracy_warnings)
    args = ap.parse_args()
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
