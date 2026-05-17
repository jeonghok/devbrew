#!/usr/bin/env python3
"""spec-distill state path helper.

Resolves state root to <main_repo>/.claude/spec-distill regardless of cwd
(worktree-aware via `git rev-parse --git-common-dir`). Fallback: cwd-relative
with loud stderr log.

CLI:
  python3 state_path.py state-root [<cwd>]    → prints absolute path to stdout
  python3 state_path.py cleanup <state-root>  → purges stale state files
"""
from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path


PENDING_TTL_HOURS = 24
FILE_TTL_DAYS = 7


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


def cleanup_stale_states(root: Path) -> None:
    """Stub for Task 3."""
    return None


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: state_path.py {state-root|cleanup} [<arg>]", file=sys.stderr)
        return 2
    sub = argv[1]
    if sub == "state-root":
        cwd = argv[2] if len(argv) >= 3 else None
        print(str(state_root(cwd)))
        return 0
    if sub == "cleanup":
        if len(argv) < 3:
            print("usage: state_path.py cleanup <state-root>", file=sys.stderr)
            return 2
        cleanup_stale_states(Path(argv[2]))
        return 0
    print(f"unknown subcommand: {sub}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
