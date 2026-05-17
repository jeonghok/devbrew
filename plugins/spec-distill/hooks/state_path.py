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


def _parse_iso(s: str):
    s = s.strip()
    try:
        return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def cleanup_stale_states(root: Path) -> None:
    """Purge stale pending_review blocks (>24h) and old state files (>7d).

    - pending_review with triggered_at > 24h ago → strip block, keep file.
    - state file with no pending_review and last_dispatched_at > 7d → delete file.
    """
    if not root.exists():
        return
    now = datetime.now(timezone.utc)
    pending_cutoff = now - timedelta(hours=PENDING_TTL_HOURS)
    file_cutoff = now - timedelta(days=FILE_TTL_DAYS)
    for session_dir in root.iterdir():
        if not session_dir.is_dir():
            continue
        state_file = session_dir / "state.local.md"
        if not state_file.exists():
            continue
        try:
            body = state_file.read_text(encoding="utf-8")
        except OSError:
            continue
        # Purge stale pending_review
        import re
        m = re.search(
            r"^pending_review:\n  path:[^\n]+\n  mode:[^\n]+\n  triggered_at:\s*([^\n]+)\n(?:  [^\n]*\n)*",
            body, flags=re.MULTILINE,
        )
        if m:
            ts = _parse_iso(m.group(1))
            if ts and ts < pending_cutoff:
                body = re.sub(
                    r"^pending_review:\n(?:  [^\n]*\n)*", "", body, flags=re.MULTILINE,
                )
                try:
                    state_file.write_text(body, encoding="utf-8")
                    print(
                        f"[spec-distill] state cleanup: purged stale pending_review in {state_file}",
                        file=sys.stderr,
                    )
                except OSError:
                    pass
        # File-level delete if only last_dispatched_at remains and is old
        if "pending_review:" not in body:
            ld = re.search(r"^last_dispatched_at:\s*(.+)$", body, flags=re.MULTILINE)
            if ld:
                ts = _parse_iso(ld.group(1))
                if ts and ts < file_cutoff:
                    try:
                        state_file.unlink()
                        try:
                            session_dir.rmdir()
                        except OSError:
                            pass
                        print(
                            f"[spec-distill] state cleanup: deleted stale state file {state_file}",
                            file=sys.stderr,
                        )
                    except OSError:
                        pass


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
