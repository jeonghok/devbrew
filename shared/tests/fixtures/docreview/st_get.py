#!/usr/bin/env python3
"""st_get.py <docreview-state.md> <python-expr>  — 원장 frontmatter 의 `docreview` 트리를 `st` 로 놓고 식을 평가해 찍는다.
케이스 파일이 heredoc-in-$() 안에 python 을 두지 않기 위한 픽스처 헬퍼다."""
import sys
import yaml
t = open(sys.argv[1], encoding="utf-8").read()
st = yaml.safe_load(t[4:t.find("\n---\n", 4)])["docreview"]
print(eval(sys.argv[2]))
