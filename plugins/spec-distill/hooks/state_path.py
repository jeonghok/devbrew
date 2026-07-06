#!/usr/bin/env python3
"""spec-distill state path helper.

Resolves state root to <main_repo>/.claude/spec-distill regardless of cwd
(worktree-aware via `git rev-parse --git-common-dir`). Fallback: cwd-relative
with loud stderr log.

CLI:
  python3 state_path.py state-root [<cwd>]    → prints absolute path to stdout
  python3 state_path.py session-id            → prints env-resolved session id (exit 1 if unresolved)
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path


SESSION_PATTERN = re.compile(r"^[A-Za-z0-9_-]{8,}$")


def resolve_session_id(payload: dict | None = None) -> str | None:
    """Resolve session_id with precedence: test override → CLAUDE_CODE_SESSION_ID → payload.

    Returns None + loud stderr on unresolved or charset/length validation failure.
    Caller must skip state write but may still emit advisory output.
    """
    sid = (
        os.environ.get("DEVBREW_SPEC_DISTILL_SESSION_ID")
        or os.environ.get("CLAUDE_CODE_SESSION_ID")
        or (payload or {}).get("session_id")
    )
    if not sid:
        print(
            "[spec-distill] session_id unresolved (env+payload empty) — "
            "state write skipped, hook output retained",
            file=sys.stderr,
        )
        return None
    if not SESSION_PATTERN.match(sid):
        truncated = sid[:32] + ("..." if len(sid) > 32 else "")
        print(
            f"[spec-distill] session_id rejected by charset/length: '{truncated}'",
            file=sys.stderr,
        )
        return None
    return sid


def state_root(cwd: str | None = None) -> Path:
    """Return <main_repo>/.claude/spec-distill. cwd fallback on git failure."""
    if cwd is None:
        cwd = os.getcwd()
    try:
        cp = subprocess.run(
            ["git", "rev-parse", "--git-common-dir"],
            cwd=cwd, capture_output=True, text=True, timeout=5, check=False,
        )
        if cp.returncode == 0:
            git_dir = Path(cp.stdout.strip())
            if not git_dir.is_absolute():
                git_dir = (Path(cwd) / git_dir).resolve()
            main_repo = git_dir.parent
            return main_repo / ".claude" / "spec-distill"
    except (subprocess.TimeoutExpired, OSError, FileNotFoundError):
        pass
    fallback = Path(cwd) / ".claude" / "spec-distill"
    print(
        f"[spec-distill] state root fallback: cwd ({cwd}) — main repo 미해석",
        file=sys.stderr,
    )
    return fallback


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: state_path.py {state-root|session-id} [<cwd>]", file=sys.stderr)
        return 2
    sub = argv[1]
    if sub == "state-root":
        cwd = argv[2] if len(argv) >= 3 else None
        print(str(state_root(cwd)))
        return 0
    if sub == "session-id":
        # env-only resolve (no hook payload on the CLI path); mirrors what the
        # Stop/UserPromptSubmit/PostToolUse hooks resolve so the skill keys the
        # review lock to the SAME state file the hooks read. Unresolved → exit 1
        # with NO stdout (caller treats empty as "skip lock, keep enforcement").
        sid = resolve_session_id(None)
        if sid is None:
            return 1
        print(sid)
        return 0
    print(f"unknown subcommand: {sub}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
