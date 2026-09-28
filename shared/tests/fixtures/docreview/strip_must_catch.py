#!/usr/bin/env python3
"""strip_must_catch.py <src> <dst> — 프로필 frontmatter 의 `must_catch:` 줄만 빼고 나머지를 바이트 그대로 옮긴다.
본문(frontmatter 밖)의 같은 모양 줄은 건드리지 않는다."""
from __future__ import annotations

import io
import sys

lines = io.open(sys.argv[1], encoding="utf-8").read().split("\n")
out, fences = [], 0
for i, ln in enumerate(lines):
    if ln == "---":
        fences += 1
    if not (fences == 1 and i > 0 and ln.startswith("must_catch:")):
        out.append(ln)
io.open(sys.argv[2], "w", encoding="utf-8").write("\n".join(out))
