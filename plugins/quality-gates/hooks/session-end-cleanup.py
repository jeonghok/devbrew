#!/usr/bin/env python3
"""SessionEnd hook: graceful per-session state cleanup.

Removes `.claude/quality-gates/<self-session>/` if it exists.
Best-effort: idempotent (no-op if missing), tolerant of permission errors.

Kill switches (CLAUDE.md "kill switch는 보안 컨트롤"):
  DEVBREW_DISABLE_QUALITY_GATES=1                       - disables this hook entirely
  DEVBREW_SKIP_HOOKS=quality-gates:session-end-cleanup  - skip just this one
"""
from __future__ import annotations

import json
import os
import shutil
import sys
from pathlib import Path


def _disabled() -> bool:
    if os.environ.get("DEVBREW_DISABLE_QUALITY_GATES") == "1":
        return True
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    tokens = {t.strip() for t in skip.split(",") if t.strip()}
    return "quality-gates:session-end-cleanup" in tokens


def _state_root(hook_input: dict) -> Path:
    """Resolve state root from hook stdin payload cwd; fall back loudly."""
    cwd = hook_input.get("cwd") if hook_input else None
    if not cwd:
        print("[quality-gates] session-end-cleanup payload missing 'cwd'; "
              "falling back to process cwd",
              file=sys.stderr)
        cwd = os.getcwd()
    return Path(cwd) / ".claude" / "quality-gates"


def main() -> int:
    if _disabled():
        return 0
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        return 0
    session_id = payload.get("session_id", "")
    if not session_id:
        return 0
    folder = _state_root(payload) / session_id
    shutil.rmtree(folder, ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
