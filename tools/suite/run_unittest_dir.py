#!/usr/bin/env python3
"""디렉토리 하나의 unittest 를 찾아 돌린다 — 실패마다 unittest 의 `FAIL:` · `ERROR:` 줄, 하나라도 있으면 rc 1.

사용: python3 tools/suite/run_unittest_dir.py <디렉토리> [패턴]   (패턴 기본 test_*.py)
스크립트 파일 호출이라 sys.path 맨 앞은 이 폴더이고, 사용자 site-packages 는 그대로 남는다.
"""
import sys
import unittest


def main(argv):
    if len(argv) < 2:
        print("사용: run_unittest_dir.py <디렉토리> [패턴]", file=sys.stderr)
        return 2
    start = argv[1]
    pattern = argv[2] if len(argv) > 2 else "test_*.py"
    suite = unittest.defaultTestLoader.discover(start, pattern=pattern)
    result = unittest.TextTestRunner(stream=sys.stdout, verbosity=1).run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
