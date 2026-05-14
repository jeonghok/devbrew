#!/usr/bin/env python3
"""Extract logical codex invocation lines from a markdown agent file.

Normalizes backslash-line-continuations so multi-line shell invocations
can be grep-checked for required flags.

Usage: python3 extract_codex_invocations.py path/to/agent.md
Stdout: one logical invocation per line.
"""

from __future__ import annotations

import re
import sys


def normalize_continuations(text: str) -> str:
    return re.sub(r"\\\n\s*", " ", text)


def extract_shell_blocks(md: str) -> list[str]:
    return re.findall(r"```(?:bash|sh|shell)?\s*\n(.*?)\n```", md, re.DOTALL)


def find_codex_lines(block: str) -> list[str]:
    block = normalize_continuations(block)
    return [line.strip() for line in block.split("\n") if "codex exec" in line]


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <path>", file=sys.stderr)
        return 2
    with open(sys.argv[1], "r", encoding="utf-8") as fh:
        md = fh.read()
    for block in extract_shell_blocks(md):
        for line in find_codex_lines(block):
            print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
