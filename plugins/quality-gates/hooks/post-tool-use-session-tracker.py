#!/usr/bin/env python3
"""PostToolUse hook: track files edited in this session for /qg scope.

Per-session path: .claude/quality-gates/<session-id>/files.md.
Triggered by Edit, Write, MultiEdit. Idempotent (dedup). Atomic rename.

Kill switches:
  DEVBREW_QUALITY_GATES_DISABLE=1   - disables this hook entirely
  DEVBREW_SKIP_HOOKS=quality-gates:session-tracker  - skip just this one
  DEVBREW_SKIP_HOOKS=quality-gates:PostToolUse      - skip every PostToolUse hook here
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from kill_switch_active import kill_switch_active  # noqa: E402

TRACKED_TOOLS = {"Edit", "Write", "MultiEdit"}
HEADER = "# Quality-Gates Session Files\n\n"


def _read_existing(path: Path) -> set[str]:
    if not path.exists():
        return set()
    seen: set[str] = set()
    for line in path.read_text().splitlines():
        if line.startswith("- "):
            seen.add(line[2:].strip())
    return seen


def _write_atomic(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + f".tmp.{os.getpid()}")
    tmp.write_text(content)
    tmp.replace(path)


def main() -> int:
    if kill_switch_active("quality-gates", "session-tracker", "PostToolUse"):
        return 0
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0
    session_id = payload.get("session_id", "")
    if not session_id:
        return 0
    tool = payload.get("tool_name", "")
    if tool not in TRACKED_TOOLS:
        return 0
    file_path = payload.get("tool_input", {}).get("file_path")
    if not file_path:
        return 0
    # AC4: derive worktree-relative base from payload cwd (B2 fix).
    # Loud fallback per CLAUDE.md "Loud logging을 동반한 graceful degradation"
    # — a Review gate review found this hook's earlier silent fallback was the only
    # surface that violated G3; harmonize with stop-hook/session-end-cleanup/
    # session-start-advisor which all warn on missing 'cwd'.
    cwd_val = payload.get("cwd")
    if not cwd_val:
        print("[quality-gates] post-tool-use-session-tracker payload missing 'cwd'; "
              "falling back to process cwd",
              file=sys.stderr)
        cwd_val = os.getcwd()
    cwd_base = Path(cwd_val)
    # If file_path is absolute, resolve() ignores cwd_base; if relative,
    # join against payload cwd so worktree paths resolve correctly.
    file_path_obj = Path(file_path)
    if file_path_obj.is_absolute():
        abs_path = str(file_path_obj.resolve())
    else:
        abs_path = str((cwd_base / file_path_obj).resolve())
    state_file = cwd_base / ".claude" / "quality-gates" / session_id / "files.md"
    existing = _read_existing(state_file)
    if abs_path in existing:
        return 0
    sorted_paths = sorted(existing | {abs_path})
    body = HEADER + "".join(f"- {p}\n" for p in sorted_paths)
    _write_atomic(state_file, body)
    return 0


if __name__ == "__main__":
    sys.exit(main())
