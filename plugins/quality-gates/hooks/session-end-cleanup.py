#!/usr/bin/env python3
"""SessionEnd hook: graceful per-session state cleanup.

Removes `.claude/quality-gates/<self-session>/` if it exists.
Best-effort: idempotent (no-op if missing), tolerant of permission errors.

Kill switches (CLAUDE.md "kill switch는 보안 컨트롤"):
  DEVBREW_DISABLE_QUALITY_GATES=1                       - disables this hook entirely
  DEVBREW_SKIP_HOOKS=quality-gates:session-end-cleanup  - skip just this one
  DEVBREW_SKIP_HOOKS=quality-gates:SessionEnd           - skip every SessionEnd hook here
"""
from __future__ import annotations

import json
import os
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from kill_switch_active import kill_switch_active  # noqa: E402


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
    if kill_switch_active("quality-gates", "session-end-cleanup", "SessionEnd"):
        return 0
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        return 0
    session_id = payload.get("session_id", "")
    if not session_id:
        return 0
    folder = _state_root(payload) / session_id
    # Best-effort: parse state for worktree_path before removing the folder.
    state_file = folder / "pipeline.md"
    worktree_path = ""
    if state_file.exists():
        try:
            for line in state_file.read_text().splitlines():
                if line.startswith("worktree_path:"):
                    parts = line.split('"', 2)
                    if len(parts) >= 2:
                        worktree_path = parts[1]
                    break
        except OSError:
            pass
    if worktree_path and os.environ.get("DEVBREW_QG_KEEP_WORKTREE", "0") != "1":
        plugin_root = Path(__file__).resolve().parent.parent
        wt_script = plugin_root / "scripts" / "qg-worktree.sh"
        try:
            import subprocess
            subprocess.run(
                [str(wt_script), "remove", worktree_path],
                cwd=payload.get("cwd") or os.getcwd(),
                timeout=30, check=False,
            )
        except (OSError, subprocess.TimeoutExpired) as e:
            print(f"[quality-gates] session-end worktree cleanup failed: {e}",
                  file=sys.stderr)
    shutil.rmtree(folder, ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
