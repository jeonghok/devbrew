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


def cmd_diagram(args) -> int:
    nodes, edges = _read_facts(sys.stdin.read())
    print("nodes:")
    for n in nodes:
        print(f"  [{n}]")
    print("edges:")
    for e in edges:
        print(f"  {e}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    t = sub.add_parser("table"); t.add_argument("--title", required=True); t.set_defaults(fn=cmd_table)
    d = sub.add_parser("diagram"); d.set_defaults(fn=cmd_diagram)
    args = ap.parse_args()
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
