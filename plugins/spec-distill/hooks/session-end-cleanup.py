#!/usr/bin/env python3
"""SessionEnd hook: deterministic per-session state cleanup.

Removes `.claude/spec-distill/<self-session>/` if it exists.
Path resolution uses spec-distill's git-aware state_root (worktree compat —
diverges from qg's simple cwd-relative pattern; see spec §C9).
Best-effort: idempotent (no-op if missing), tolerant of permission errors.

Kill switches (CLAUDE.md "kill switch는 보안 컨트롤"):
  DEVBREW_DISABLE_SPEC_DISTILL=1                       - disables entirely
  DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd           - skip just this one
  DEVBREW_SKIP_HOOKS=spec-distill:session-end-cleanup  - 같은 훅을 훅명으로 지목 (이관 후 추가)
"""
from __future__ import annotations

import json
import os
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "scripts"))
from state_path import state_root, SESSION_PATTERN  # noqa: E402 # pyright: ignore[reportMissingImports]
from kill_switch_active import kill_switch_active  # noqa: E402


def main() -> int:
    if kill_switch_active("spec-distill", "session-end-cleanup", "SessionEnd"):
        return 0
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0
    except OSError as exc:
        print(f"[spec-distill] session-end-cleanup: stdin read error: {exc}", file=sys.stderr)
        return 0
    # SessionEnd targets the ending session (from payload), NOT the current
    # session (from CLAUDE_CODE_SESSION_ID env). Use payload directly — do not
    # use resolve_session_id which has env precedence.
    session_id = payload.get("session_id", "")
    if not session_id or not SESSION_PATTERN.match(session_id):
        return 0
    cwd = payload.get("cwd")
    if not cwd:
        print(
            "[spec-distill] session-end-cleanup: payload missing 'cwd', "
            "falling back to process cwd",
            file=sys.stderr,
        )
        cwd = os.getcwd()
    folder = state_root(cwd) / session_id
    shutil.rmtree(folder, ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
