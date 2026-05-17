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
        print(f"[project-init:docs-lint] could not read {rel_display} — skipping R1", file=sys.stderr)
        return None
    lines = len(content.splitlines())
    if lines <= 200:
        return None
    base = (
        f"project-init: {rel_display} is {lines} lines. "
        f"Anthropic recommends ≤200. Move detailed content to docs/** and link from here."
    )
    if lines > 300:
        return base + " (STRONG: >300 lines means agent will likely truncate)"
    return base


TOC_RE = re.compile(r"^##\s+(목차|Table of Contents|Contents)\s*$", re.MULTILINE)


def check_r2_toc(target: Path, rel_display: str) -> Optional[str]:
    """AC9: TOC required if >300 lines."""
    try:
        content = target.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        print(f"[project-init:docs-lint] could not read {rel_display} — skipping R2", file=sys.stderr)
        return None
    lines = len(content.splitlines())
    if lines <= 300:
        return None
    if TOC_RE.search(content):
        return None
    return (
        f"project-init: {rel_display} exceeds 300 lines without a TOC section. "
        f'Add "## 목차" or "## Table of Contents" near the top.'
    )


FENCE_RE = re.compile(r"^ {0,3}`{3}(\S*)\s*$")


def check_r5_fences(target: Path, rel_display: str) -> Optional[str]:
    """AC11/AC12: bare 3-backtick opening fence without language tag.

    Scope-outs (v1.4.0 false-negative허용): 4+ backtick fences, tilde fences,
    space-separated info string (`​```​ bash` with leading space).
    """
    try:
        content = target.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        print(f"[project-init:docs-lint] could not read {rel_display} — skipping R5", file=sys.stderr)
        return None
    violations: list[int] = []
    in_fence = False
    for lineno, line in enumerate(content.splitlines(), start=1):
        m = FENCE_RE.match(line)
        if not m:
            continue
        if not in_fence:
            # Opening fence
            lang = m.group(1)
            if not lang:
                violations.append(lineno)
        # Toggle either way (closing fence is always bare and intentional)
        in_fence = not in_fence
    if not violations:
        return None
    if len(violations) == 1:
        return (
            f"project-init: {rel_display} has 1 fenced code block without a language tag "
            f"at line L{violations[0]}. Add the language (e.g. \"```bash\")."
        )
    shown = violations[:5]
    suffix = ""
    if len(violations) > 5:
        suffix = f" ... and {len(violations) - 5} more"
    line_list = ", ".join(f"L{n}" for n in shown) + suffix
    return (
        f"project-init: {rel_display} has {len(violations)} fenced code blocks "
        f"without language tags at lines [{line_list}]. "
        f"Add the language (e.g. \"```bash\")."
    )


LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
URL_SCHEME_RE = re.compile(r"^[a-zA-Z][a-zA-Z0-9+.-]*:")


def check_r6_links(target: Path, rel_display: str, project_dir: Path) -> Optional[str]:
    """AC13/AC14/AC15: internal markdown links must resolve.

    Scope-outs (v1.4.0 false-positive허용): links inside fenced code blocks /
    inline backtick spans are not excluded — known false-positive surface,
    parallel to R5's fence scope-outs.
    """
    try:
        content = target.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        print(f"[project-init:docs-lint] could not read {rel_display} — skipping R6", file=sys.stderr)
        return None
    unresolved: list[str] = []
    base_dir = target.parent
    for m in LINK_RE.finditer(content):
        raw_target = m.group(2).strip()
        if not raw_target:
            continue
        if URL_SCHEME_RE.match(raw_target):
            continue
        if raw_target.startswith("#"):
            continue
        # Strip fragment
        path_part = raw_target.split("#", 1)[0]
        if not path_part:
            continue
        resolved = (base_dir / path_part).resolve()
        # AC15: escape outside project_dir → treat as external
        try:
            resolved.relative_to(project_dir)
        except ValueError:
            continue
        if not resolved.exists():
            unresolved.append(raw_target)
    if not unresolved:
        return None
    shown = unresolved[:5]
    suffix = ""
    if len(unresolved) > 5:
        suffix = f" ... and {len(unresolved) - 5} more"
    list_str = ", ".join(shown) + suffix
    return (
        f"project-init: {rel_display} has {len(unresolved)} unresolved internal link(s): "
        f"[{list_str}]"
    )


FRONTMATTER_RE = re.compile(r"^---\n.*?\n---(?:\n|$)", re.DOTALL)
HTML_COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)


def _normalize_pointer_content(content: str) -> str:
    """AC16 normalization: (1) strip frontmatter (2) strip HTML comments (3) str.strip().

    Order matters — frontmatter regex must run before HTML comment strip;
    do not reorder (frontmatter could contain `<!-- -->` boundaries that the
    comment strip would corrupt).
    """
    # 1. Strip frontmatter
    no_fm = FRONTMATTER_RE.sub("", content, count=1)
    # 2. Strip HTML comments
    no_comments = HTML_COMMENT_RE.sub("", no_fm)
    # 3. Whitespace
    return no_comments.strip()


def _is_proper_pointer(claude_path: Path, agents_basename: str = "AGENTS.md") -> bool:
    """Return True if claude_path satisfies AC16 pass conditions."""
    # Cond 1: symlink to AGENTS.md
    if claude_path.is_symlink():
        link = os.readlink(claude_path)
        return link in (agents_basename, f"./{agents_basename}")
    # Cond 2: normalized content == "@AGENTS.md"
    try:
        content = claude_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return False
    return _normalize_pointer_content(content) == f"@{agents_basename}"


def check_r_pointer(target: Path, project_dir: Path) -> Optional[str]:
    """AC16-AC18.5: bidirectional CLAUDE/AGENTS drift detection.

    Triggered when editing any of the 4 target files; checks the directory's pair.
    """
    target_dir = target.parent
    claude_path = target_dir / "CLAUDE.md"
    agents_path = target_dir / "AGENTS.md"
    # AC18.5: pair file worktree check + CLAUDE_PROJECT_DIR escape guard
    for p in (claude_path, agents_path):
        resolved = p.resolve() if p.exists() else p
        if WORKTREE_MARKER in str(resolved):
            return None
        try:
            if p.exists():
                p.resolve().relative_to(project_dir)
        except ValueError:
            return None
    if not (claude_path.exists() and agents_path.exists()):
        return None  # drift only meaningful when both exist
    if _is_proper_pointer(claude_path):
        return None
    try:
        rel_claude = claude_path.relative_to(project_dir).as_posix()
        rel_agents = agents_path.relative_to(project_dir).as_posix()
    except ValueError:
        rel_claude = str(claude_path)
        rel_agents = str(agents_path)
    return (
        f"project-init: Both {rel_claude} and {rel_agents} exist with divergent content "
        f"(drift risk). Make CLAUDE.md contain just \"@AGENTS.md\" or symlink it: "
        f"`ln -sf AGENTS.md CLAUDE.md`"
    )


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
    project_dir_path = Path(project_dir).resolve()
    try:
        rel_display = target.relative_to(project_dir_path).as_posix()
    except ValueError:
        rel_display = str(target)
    messages: list[str] = []
    msg_r1 = check_r1_size(target, rel_display)
    if msg_r1:
        messages.append(msg_r1)
    msg_r2 = check_r2_toc(target, rel_display)
    if msg_r2:
        messages.append(msg_r2)
    msg_r5 = check_r5_fences(target, rel_display)
    if msg_r5:
        messages.append(msg_r5)
    msg_r6 = check_r6_links(target, rel_display, project_dir_path)
    if msg_r6:
        messages.append(msg_r6)
    msg_rp = check_r_pointer(target, project_dir_path)
    if msg_rp:
        messages.append(msg_rp)
    if messages:
        emit("\n\n".join(messages))
    else:
        emit()
    return 0


if __name__ == "__main__":
    sys.exit(main())
