#!/usr/bin/env python3
"""compute_issue_id.py — deterministic centralized issue-id helper.

spec-distill design §6 #5 / §8. Both reviewers' issues (Claude sentinel block,
codex findings) go through this single function so that identical
(category, target_section) pairs collide on the same id — the precondition for
cross-reviewer corroboration and cross-round stagnation matching. Replaces the
old LLM in-head sha256 (unreliable). stdlib only.

  issue_id = sha256(f"{category}:{target_section}")[:12 hex]

CLI:  compute_issue_id.py <category> <target_section>   → id + newline on stdout
"""

from __future__ import annotations

import hashlib
import sys

ID_LEN = 12


def compute(category: str, target_section: str) -> str:
    key = f"{category}:{target_section}"
    return hashlib.sha256(key.encode("utf-8")).hexdigest()[:ID_LEN]


def main() -> int:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <category> <target_section>", file=sys.stderr)
        return 2
    print(compute(sys.argv[1], sys.argv[2]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
