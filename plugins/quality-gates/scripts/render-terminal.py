#!/usr/bin/env python3
"""render-terminal.py — scannable terminal STATUS table for the qg Final verdict.

Subcommand:
  table --title T : read `key<TAB>value` lines from stdin → aligned STATUS table.

Deterministic, no network, no gh. ≤~100 columns.
"""
from __future__ import annotations
import argparse
import sys

RULE = "─" * 56


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


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    t = sub.add_parser("table"); t.add_argument("--title", required=True); t.set_defaults(fn=cmd_table)
    args = ap.parse_args()
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
