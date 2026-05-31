#!/usr/bin/env python3
"""spec-distill — web research budget enforcer (AC7, AC8, PN3).

Enforces two bounds on interview web research, reading counters from a
state.local.md frontmatter (PN3: state-file counter, not in-memory):

  - per-sweep:   web_sweep_count  <= SWEEP_CAP (4)   — AP9 fan-out guard
  - per-session: web_search_count <= SESSION_CAP (8) — AP16 unbounded guard

conducting-interview increments these via Bash before each web call (worktree
sessions cannot Edit/Write the main-repo state — PN1) and runs `check`; a
non-zero exit means the next call would breach budget → caller emits advisory +
forces a (b) user question.

Kill switch DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 → always exit 0 (web disabled;
caller skips landscape and logs loudly — AC8 graceful degradation).

CLI:
  web_budget.py check <state.local.md>   → exit 0 within budget, 1 if over.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

SWEEP_CAP = 4
SESSION_CAP = 8


def _read_counter(text: str, key: str) -> int:
    m = re.search(rf"^{re.escape(key)}\s*:\s*([0-9]+)\s*$", text, re.MULTILINE)
    return int(m.group(1)) if m else 0


def check(state_path: Path) -> int:
    if os.environ.get("DEVBREW_SPEC_DISTILL_DISABLE_WEB") == "1":
        print(json.dumps({"ok": True, "reason": "web disabled (kill switch)"}))
        return 0
    try:
        text = state_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(json.dumps({"ok": False, "reason": f"state unreadable: {exc}"}))
        return 1
    sweep = _read_counter(text, "web_sweep_count")
    session = _read_counter(text, "web_search_count")
    over = []
    if sweep > SWEEP_CAP:
        over.append(f"sweep {sweep} > {SWEEP_CAP}")
    if session > SESSION_CAP:
        over.append(f"session {session} > {SESSION_CAP}")
    if over:
        print(json.dumps({"ok": False, "sweep": sweep, "session": session,
                          "reason": "; ".join(over)}))
        return 1
    print(json.dumps({"ok": True, "sweep": sweep, "session": session}))
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 3 or argv[1] != "check":
        print("usage: web_budget.py check <state.local.md>", file=sys.stderr)
        return 64
    return check(Path(argv[2]))


if __name__ == "__main__":
    sys.exit(main(sys.argv))
