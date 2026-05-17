#!/usr/bin/env python3
"""PostToolUse hook for project-init plugin — agent-readable docs convention validator.

Validates root context files (CLAUDE.md, AGENTS.md, .claude/CLAUDE.md, .claude/AGENTS.md)
against 5 deterministic rules: R1 size, R2 TOC, R5 fenced code language,
R6 internal links resolve, R-pointer CLAUDE/AGENTS drift.

Non-blocking advisory pattern: outputs systemMessage on violation, {} on pass.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path
from typing import Optional


# --- Filter constants ---

TARGET_BASENAMES = {"CLAUDE.md", "AGENTS.md"}
TARGET_RELPATHS = {"CLAUDE.md", "AGENTS.md", ".claude/CLAUDE.md", ".claude/AGENTS.md"}
TARGET_TOOLS = {"Write", "Edit", "MultiEdit"}
WORKTREE_MARKER = os.sep + ".git" + os.sep + "worktrees" + os.sep


# --- Helpers ---


def kill_switch_active() -> bool:
    """Return True if devbrew kill switch env vars opt this hook out.

    Mirrors plugins/project-init/hooks/post-tool-use.py:149-154 pattern,
    differing only in the hook token string.
    """
    if os.environ.get("DEVBREW_DISABLE_PROJECT_INIT") == "1":
        return True
    skip_list = [s.strip() for s in os.environ.get("DEVBREW_SKIP_HOOKS", "").split(",")]
    return "project-init:docs-lint" in skip_list


def resolve_target_path(file_path: str, project_dir: str) -> Optional[Path]:
    """Return absolute Path if file_path is one of the 4 target root context files
    relative to project_dir, else None. Skips worktree internal metadata paths."""
    if not file_path:
        return None
    abs_path = Path(file_path).resolve()
    if WORKTREE_MARKER in str(abs_path):
        return None
    try:
        rel = abs_path.relative_to(Path(project_dir).resolve())
    except ValueError:
        # File is outside CLAUDE_PROJECT_DIR
        return None
    if rel.as_posix() not in TARGET_RELPATHS:
        return None
    return abs_path


def emit(systemMessage: Optional[str] = None) -> None:
    """Print hook JSON output and exit 0.

    ``ensure_ascii=False`` so Unicode glyphs (≤, →, etc.) reach the user
    verbatim instead of as escape sequences — JSON spec permits raw UTF-8.
    """
    if systemMessage:
        print(json.dumps({"systemMessage": systemMessage}, ensure_ascii=False), flush=True)
    else:
        print(json.dumps({}), flush=True)


# --- Rules ---


def check_r1_size(target: Path, rel_display: str) -> Optional[str]:
    """AC7/AC8: size warning if >200 lines, STRONG suffix if >300."""
    try:
        content = target.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None
    lines = content.count("\n") + (0 if content.endswith("\n") or not content else 1)
    if lines <= 200:
        return None
    base = (
        f"project-init: {rel_display} is {lines} lines. "
        f"Anthropic recommends ≤200. Move detailed content to docs/** and link from here."
    )
    if lines > 300:
        return base + " (STRONG: >300 lines means agent will likely truncate)"
    return base


def main() -> int:
    if kill_switch_active():
        emit()
        return 0
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        print("[project-init:docs-lint] invalid JSON on stdin — skipping", file=sys.stderr)
        emit()
        return 0
    tool_name = payload.get("tool_name", "")
    if tool_name not in TARGET_TOOLS:
        emit()
        return 0
    file_path = payload.get("tool_input", {}).get("file_path", "")
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
    target = resolve_target_path(file_path, project_dir)
    if target is None:
        emit()
        return 0
    # Compute display path (relative to project_dir for readability)
    try:
        rel_display = target.relative_to(Path(project_dir).resolve()).as_posix()
    except ValueError:
        rel_display = str(target)
    messages: list[str] = []
    msg_r1 = check_r1_size(target, rel_display)
    if msg_r1:
        messages.append(msg_r1)
    # More rules will be added in subsequent tasks.
    if messages:
        emit("\n\n".join(messages))
    else:
        emit()
    return 0


if __name__ == "__main__":
    sys.exit(main())
