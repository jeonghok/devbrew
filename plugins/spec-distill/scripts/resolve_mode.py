from __future__ import annotations

import os
import re
import sys
from pathlib import Path
from typing import Optional

PATH_PREFIX = "docs/superpowers/specs/"


def _frontmatter_has_locked_decisions(file_path: str) -> bool:
    """첫 ---...--- frontmatter 블록 안에 locked_decisions 키가 있으면 True.

    body의 locked_decisions 언급은 무시. 닫는 ---가 없는 unclosed frontmatter는
    유효 블록이 아니므로 False. 읽기/디코드 실패는 False + loud stderr (caller가
    design으로 매핑)."""
    try:
        text = Path(file_path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(
            f"[spec-distill] resolve_mode content-peek failed for {file_path}: {exc}",
            file=sys.stderr,
        )
        return False
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return False  # frontmatter 블록 없음
    block: list[str] = []
    closed = False
    for line in lines[1:]:
        if line.strip() == "---":
            closed = True
            break
        block.append(line)
    if not closed:
        return False  # unclosed frontmatter → spec marker로 인정 안 함
    return any(re.match(r"\s*locked_decisions\s*:", b) for b in block)


def resolve_mode(file_path: str) -> Optional[str]:
    """Return 'spec', 'design', or None (not in scope)."""
    if PATH_PREFIX not in file_path:
        return None
    if not file_path.endswith(".md"):
        return None
    if file_path.endswith("-spec.md"):
        return "spec"
    design_disabled = (
        os.environ.get("DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE") == "1"
    )
    if file_path.endswith("-design.md"):
        return None if design_disabled else "design"
    # suffix 없는 임의 .md — content-aware
    if _frontmatter_has_locked_decisions(file_path):
        return "spec"
    return None if design_disabled else "design"
