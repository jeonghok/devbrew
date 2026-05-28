#!/usr/bin/env python3
"""Read a single frontmatter value from a YAML-frontmatter markdown file.

Usage: read-frontmatter.py <file> <key>
Stdout: value (without surrounding quotes; \\" / \\\\ escape 해제), 또는
        key 부재 시 빈 줄.
Exit: 0 on success (key 부재도 success), 1 on file/parse error.

v1.32.3 MED-3: 3 call site (pre-pipeline-check.sh × 2, cancel-qg-core.sh × 1)
의 `awk -F'"'` 패턴을 대체. escape-aware regex로 embedded quote 처리.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: read-frontmatter.py <file> <key>", file=sys.stderr)
        return 1

    path, key = Path(sys.argv[1]), sys.argv[2]
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as e:
        print(f"read-frontmatter: {e}", file=sys.stderr)
        return 1

    # Frontmatter는 `---` 마커로 감싸짐. 없으면 전체 텍스트 대상.
    m = re.search(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    fm = m.group(1) if m else text

    # Match key: "...escaped..." (escape-aware) OR key: bare-value
    # Escape-aware quoted: `[^"\\]` (일반 char) 또는 `\\.` (escape sequence) 반복.
    m2 = re.search(
        rf'^{re.escape(key)}:\s*(?:"((?:[^"\\]|\\.)*)"|(.*))$',
        fm,
        re.MULTILINE,
    )
    if m2:
        if m2.group(1) is not None:  # quoted form
            # Unescape minimal YAML double-quoted escape sequences:
            # \" → ", \\ → \. (현재 schema 범위: 한 줄 값만)
            val = (
                m2.group(1)
                .replace("\\\\", "\x00")
                .replace('\\"', '"')
                .replace("\x00", "\\")
            )
            print(val)
        else:  # bare form
            print(m2.group(2).strip())
    else:
        print("")  # key 부재 — 명시적 빈 줄
    return 0


if __name__ == "__main__":
    sys.exit(main())
