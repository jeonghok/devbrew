#!/usr/bin/env python3
"""v1.32.3 I-C: CHANGELOG [1.32.0] body Korean-primary verifier.

Usage: check-changelog-korean-primary.py <CHANGELOG.md>
Exit: 0 if [1.32.0] body satisfies Korean-primary 단락 단위 rule, 1 otherwise.

Rule: 각 non-empty 단락(blank-line 분리)이 다음 중 하나:
- (a) Hangul 문자 (U+AC00..U+D7A3) 1개 이상 포함
- (b) Verbatim 인용 (전체가 백틱/따옴표로 둘러싸인 영어)
- (c) 100% identifier-like (영문자/숫자/`_/-./` + 백틱만)

영구 보존 스크립트 — 향후 CHANGELOG 항목 추가 시에도 동일 컨벤션 재검증 가능.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

HANGUL_RE = re.compile(r"[가-힣]")
# Identifier-only (no whitespace): paragraph가 100% 식별자 토큰 한 덩어리
# (e.g., `hooks/stop-hook.py` 단독). 공백 포함 영어 prose는 fail시킴.
IDENTIFIER_ONLY_RE = re.compile(r"^[A-Za-z0-9_\-./`'\"\\(\)\[\],:;*+=<>!?]+$")


def extract_section(text: str, header: str) -> str:
    """Extract body of `## [header]` until next `## [` or EOF."""
    lines = text.splitlines()
    start = -1
    for i, line in enumerate(lines):
        if line.startswith(f"## [{header}]"):
            start = i + 1
            break
    if start == -1:
        return ""
    body: list[str] = []
    for line in lines[start:]:
        if line.startswith("## ["):
            break
        body.append(line)
    return "\n".join(body)


def check_paragraph(p: str) -> bool:
    """Return True if paragraph satisfies Korean-primary rule."""
    p = p.strip()
    if not p:
        return True
    # 헤더 라인 (### Breaking 등)은 면제
    if p.startswith("### "):
        return True
    # (a) Hangul 포함
    if HANGUL_RE.search(p):
        return True
    # (c) 100% identifier-like
    if IDENTIFIER_ONLY_RE.match(p):
        return True
    # (b) Verbatim 인용 — 간단 휴리스틱
    if p.startswith("`") and p.endswith("`"):
        return True
    if p.startswith('"') and p.endswith('"'):
        return True
    return False


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check-changelog-korean-primary.py <CHANGELOG.md>", file=sys.stderr)
        return 1

    path = Path(sys.argv[1])
    if not path.exists():
        print(f"check-changelog-korean-primary: {path} not found", file=sys.stderr)
        return 1

    text = path.read_text(encoding="utf-8")
    section = extract_section(text, "1.32.0")
    if not section:
        print("check-changelog-korean-primary: [1.32.0] section not found", file=sys.stderr)
        return 1

    # Split by blank lines (단락 단위)
    paragraphs = re.split(r"\n\s*\n", section)
    failed: list[str] = []
    for p in paragraphs:
        if not check_paragraph(p):
            failed.append(p.strip()[:80])
    if failed:
        print(
            f"check-changelog-korean-primary: {len(failed)} paragraph(s) fail Korean-primary rule:",
            file=sys.stderr,
        )
        for f in failed:
            print(f"  - {f}", file=sys.stderr)
        return 1
    print(f"check-changelog-korean-primary: OK ({len(paragraphs)} paragraphs)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
