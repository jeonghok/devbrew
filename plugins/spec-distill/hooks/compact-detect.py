#!/usr/bin/env python3
"""spec-distill UserPromptSubmit hook — compact detect (v0.10.0).

Watches for /compact or Skill superpowers:writing-plans at the *start* of
the user message (lstrip + startswith, case-sensitive). On match, deletes
the handoff marker file at .claude/spec-distill/.markers/<sid>.emitted
so the compact-induction Stop hook stops firing.

Payload key precedence: `user_prompt` (actual Claude Code field per Task 4
research) → `user_message` → `prompt` (defensive fallbacks). Read whichever
key is present; first non-empty string wins.

Kill switches:
- DEVBREW_DISABLE_SPEC_DISTILL=1
- DEVBREW_SKIP_HOOKS=spec-distill:compact-detect (or :UserPromptSubmit — shared with reminder)

Note: shares UserPromptSubmit with pending-review-reminder.py; both are
no-ops when their respective triggers are absent.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from state_path import state_root, resolve_session_id  # noqa: E402

COMPACT_PREFIXES = ("/compact", "Skill superpowers:writing-plans")
USER_TEXT_KEYS = ("user_prompt", "user_message", "prompt")


def kill_switch_active() -> bool:
    if os.environ.get("DEVBREW_DISABLE_SPEC_DISTILL") == "1":
        return True
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    tokens = {p.strip() for p in skip.split(",") if p.strip()}
    return bool(tokens & {
        "spec-distill:compact-detect",
        "spec-distill:UserPromptSubmit",
    })


def extract_user_text(payload: dict) -> str:
    """Read prompt text from payload; tolerant to schema drift.

    Claude Code's UserPromptSubmit payload field is `user_prompt` in this repo
    (Task 4 finding). We also accept `user_message` and `prompt` as defensive
    fallbacks so the documented field names in the spec continue to work.
    """
    for key in USER_TEXT_KEYS:
        value = payload.get(key)
        if isinstance(value, str) and value:
            return value
    return ""


def main() -> int:
    if kill_switch_active():
        return 0
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        payload = {}
    except OSError as exc:
        print(f"[spec-distill] compact-detect stdin error: {exc}", file=sys.stderr)
        payload = {}

    session_id = resolve_session_id(payload)
    if session_id is None:
        return 0

    text = extract_user_text(payload).lstrip()
    if not any(text.startswith(p) for p in COMPACT_PREFIXES):
        return 0

    marker = state_root() / ".markers" / f"{session_id}.emitted"
    if not marker.exists():
        return 0

    try:
        marker.unlink()
        print(
            f"[spec-distill] compact-detect: /compact|writing-plans observed — marker deleted ({marker.name})",
            file=sys.stderr,
        )
    except OSError as exc:
        print(
            f"[spec-distill] compact-detect: marker unlink failed (non-fatal): {exc}",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
