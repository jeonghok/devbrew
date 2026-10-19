#!/usr/bin/env python3
"""ac15_roots.py <상태 디렉토리> <루트1> <루트2> <이름1> <이름2> — 상태 디렉토리를 `<루트>/<이름>/.docreview/<같은 이름>` 두 곳에
복사한다(루트 이름만 다른 두 상태). 셸이 한글 경로를 만들다 locale 에 걸리지 않게 파이썬이 만든다."""
import shutil
import sys
from pathlib import Path

src = Path(sys.argv[1])
for root, name in ((sys.argv[2], sys.argv[4]), (sys.argv[3], sys.argv[5])):
    dst = Path(root) / name / ".docreview" / src.name
    dst.parent.mkdir(parents=True)
    shutil.copytree(str(src), str(dst))
print("ok")
