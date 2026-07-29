#!/usr/bin/env python3
"""spec-distill — web research budget enforcer (AC7, AC8, PN3).

Enforces two bounds on interview web research, reading counters from a
state.local.md frontmatter (PN3: state-file counter, not in-memory):

  - per-sweep:   web_sweep_count  <= SWEEP_CAP (4)   — AP9 fan-out guard
  - per-session: web_search_count <= SESSION_CAP (8) — AP16 unbounded guard

conducting-interview calls `increment` before each web call (worktree sessions
cannot Edit/Write the main-repo state, so the script does the PN1 Bash write);
`increment` advances both counters, persists them, and re-runs the budget check.
A non-zero exit means the just-attempted call breaches budget → caller emits
advisory + forces a (b) user question. At sweep end the caller runs `reset-sweep`
(zeroes web_sweep_count, keeps web_search_count).

The state schema (conducting-interview SKILL.md) writes the counters with a
trailing inline comment, e.g. `web_sweep_count: 0   # ...`. The parser tolerates
that (capture stops at the digits); a counter that is *present but non-numeric*
fails closed rather than silently reading as 0 (which would defeat the guard).

Kill switch DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 → always exit 0 (web disabled;
caller skips landscape and logs loudly — AC8 graceful degradation).

CLI (all print JSON):
  web_budget.py check <state.local.md>       → exit 0 within budget, 1 if over.
  web_budget.py check --prospective <state>  → same, but evaluated at count+1
      ("will the call I am about to make fit?"). A pre-dispatch gate MUST use
      this: the plain check rejects only `> CAP`, so at `count == CAP` it
      passes, the caller dispatches, and the follow-up increment lands on
      CAP+1 — one dispatch past the stated cap. Callers that increment
      *before* dispatching (conducting-interview) already avoid that and keep
      the default.
  web_budget.py increment <state.local.md>   → +1 both counters, persist, check.
  web_budget.py reset-sweep <state.local.md> → web_sweep_count := 0 (keep session).
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
    """Read a non-negative integer counter from state frontmatter.

    Tolerates a trailing inline comment (capture stops at the digit run, so the
    schema's `web_sweep_count: 0   # ...` parses). Returns 0 when the key is
    absent (fresh session — counters not yet written). Raises ValueError when the
    key is present but its value is not a non-negative integer: that is a
    fail-closed signal, never a silent 0 (a budget enforcer must not read
    malformed input as "within budget").
    """
    m = re.search(rf"^{re.escape(key)}\s*:\s*(\S+)", text, re.MULTILINE)
    if not m:
        return 0
    tok = m.group(1)
    if not tok.isdigit():
        raise ValueError(f"{key} is present but not a non-negative integer: {tok!r}")
    return int(tok)


def _evaluate(sweep: int, session: int) -> tuple[bool, str]:
    over = []
    if sweep > SWEEP_CAP:
        over.append(f"sweep {sweep} > {SWEEP_CAP}")
    if session > SESSION_CAP:
        over.append(f"session {session} > {SESSION_CAP}")
    return (not over), "; ".join(over)


def check(state_path: Path, prospective: bool = False) -> int:
    """Evaluate the budget against the counters on disk.

    Default (`prospective=False`) answers *"are the counters currently within
    budget?"* — the historical contract, used by `increment`'s bump-then-check.

    `prospective=True` answers the question a **pre-dispatch gate** actually
    asks: *"will the call I am about to make fit?"* It evaluates `count + 1`.
    Without it a pre-dispatch gate is off by one: at `session == SESSION_CAP`
    the plain check passes (it rejects only `> CAP`), the caller dispatches,
    and the follow-up `increment` lands on `CAP + 1` — one dispatch past the
    stated cap. Callers that increment *before* dispatching are already
    correct and must keep the default.
    """
    if os.environ.get("DEVBREW_SPEC_DISTILL_DISABLE_WEB") == "1":
        print(json.dumps({"ok": True, "reason": "web disabled (kill switch)"}))
        return 0
    try:
        text = state_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(json.dumps({"ok": False, "reason": f"state unreadable: {exc}"}))
        return 1
    try:
        sweep = _read_counter(text, "web_sweep_count")
        session = _read_counter(text, "web_search_count")
    except ValueError as exc:
        print(json.dumps({"ok": False, "reason": f"counter malformed: {exc}"}))
        return 1
    bump = 1 if prospective else 0
    ok, reason = _evaluate(sweep + bump, session + bump)
    payload = {"ok": ok, "sweep": sweep, "session": session}
    if prospective:
        payload["prospective"] = True
    if not ok:
        payload["reason"] = reason
        print(json.dumps(payload))
        return 1
    print(json.dumps(payload))
    return 0


def _bump_line(text: str, key: str, delta: int) -> str:
    """Return `text` with the integer counter `key` changed by `delta`,
    preserving everything after the number (e.g. an inline comment). Raises
    ValueError if the counter line is absent or non-numeric — increment never
    silently creates a missing counter (a GC-reset race must fail closed, not
    reset the session budget to 0)."""
    pat = re.compile(rf"^({re.escape(key)}\s*:\s*)([0-9]+)(.*)$", re.MULTILINE)
    m = pat.search(text)
    if not m:
        raise ValueError(f"{key} counter line absent or non-numeric")
    new_val = int(m.group(2)) + delta
    return text[:m.start()] + f"{m.group(1)}{new_val}{m.group(3)}" + text[m.end():]


def increment(state_path: Path) -> int:
    """+1 both counters, persist, then evaluate budget (increment-then-check)."""
    if os.environ.get("DEVBREW_SPEC_DISTILL_DISABLE_WEB") == "1":
        print(json.dumps({"ok": True, "reason": "web disabled (kill switch)"}))
        return 0
    try:
        text = state_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(json.dumps({"ok": False, "reason": f"state unreadable: {exc}"}))
        return 1
    try:
        text = _bump_line(text, "web_sweep_count", 1)
        text = _bump_line(text, "web_search_count", 1)
    except ValueError as exc:
        print(json.dumps({"ok": False, "reason": f"increment failed: {exc}"}))
        return 1
    try:
        state_path.write_text(text, encoding="utf-8")
    except OSError as exc:
        print(json.dumps({"ok": False, "reason": f"state unwritable: {exc}"}))
        return 1
    return check(state_path)


def reset_sweep(state_path: Path) -> int:
    """Zero web_sweep_count (sweep boundary), keep web_search_count."""
    try:
        text = state_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(json.dumps({"ok": False, "reason": f"state unreadable: {exc}"}))
        return 1
    pat = re.compile(r"^(web_sweep_count\s*:\s*)([0-9]+)(.*)$", re.MULTILINE)
    if not pat.search(text):
        print(json.dumps({"ok": False, "reason": "web_sweep_count line absent or non-numeric"}))
        return 1
    text = pat.sub(lambda m: f"{m.group(1)}0{m.group(3)}", text, count=1)
    try:
        state_path.write_text(text, encoding="utf-8")
    except OSError as exc:
        print(json.dumps({"ok": False, "reason": f"state unwritable: {exc}"}))
        return 1
    print(json.dumps({"ok": True, "reason": "web_sweep_count reset to 0"}))
    return 0


SUBCOMMANDS = {"check": check, "increment": increment, "reset-sweep": reset_sweep}

USAGE = ("usage: web_budget.py {check [--prospective]|increment|reset-sweep} "
         "<state.local.md>")


def main(argv: list[str]) -> int:
    args = argv[1:]
    prospective = False
    if "--prospective" in args:
        prospective = True
        args = [a for a in args if a != "--prospective"]
    if len(args) < 2 or args[0] not in SUBCOMMANDS:
        print(USAGE, file=sys.stderr)
        return 64
    if prospective and args[0] != "check":
        print(f"--prospective is only valid for `check` (got: {args[0]})", file=sys.stderr)
        return 64
    if args[0] == "check":
        return check(Path(args[1]), prospective=prospective)
    return SUBCOMMANDS[args[0]](Path(args[1]))


if __name__ == "__main__":
    sys.exit(main(sys.argv))
