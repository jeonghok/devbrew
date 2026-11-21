#!/usr/bin/env python3
"""디렉토리 하나의 unittest 를 찾아 돌린다 — 실패마다 unittest 의 `FAIL:` · `ERROR:` 줄, 하나라도 있으면 rc 1.

사용: python3 tools/suite/run_unittest_dir.py <디렉토리> [패턴]   (패턴 기본 test_*.py)
스크립트 파일 호출이라 sys.path 맨 앞은 이 폴더이고, 사용자 site-packages 는 그대로 남는다.
환경 변수 SUITE_TIMING_FILE(절대 경로)이 있으면 끝에 `<초>\tpymod\t<폴더>/<모듈 파일>` 줄을 덧붙인다 —
테스트에는 물려주지 않는다. 빈 값은 없는 것과 같다.
"""
import os
import sys
import time
import unittest


def module_key(test, start, base):
    """모듈 파일의 시작 폴더(base) 기준 상대 경로. 임포트에서 죽은 모듈은 `<폴더>/<이름>.py`. 죽지 않는다."""
    try:
        if isinstance(test, unittest.loader._FailedTest):
            return os.path.join(start, test._testMethodName + ".py")
        mod = sys.modules.get(type(test).__module__)
        path = getattr(mod, "__file__", None)
        if not path:
            return type(test).__module__
        return os.path.relpath(path, base)
    except Exception:
        return type(test).__module__


class _TimedResult(unittest.TextTestResult):
    start_dir = "."
    base_dir = ""

    def startTestRun(self):
        super().startTestRun()
        self.module_secs = {}
        self._last = time.monotonic()

    def stopTest(self, test):
        now = time.monotonic()
        key = module_key(test, self.start_dir, self.base_dir)
        self.module_secs[key] = self.module_secs.get(key, 0.0) + (now - self._last)
        self._last = now
        super().stopTest(test)


def write_timing(path, module_secs):
    try:
        with open(path, "a", encoding="utf-8") as fh:
            for key in sorted(module_secs):
                fh.write("%.3f\tpymod\t%s\n" % (module_secs[key], key))
    except (OSError, UnicodeError):
        print("run_unittest_dir: 시간 기록 파일에 쓸 수 없다 — 기록하지 않는다: %s" % path, file=sys.stderr)


def main(argv):
    timing = os.environ.pop("SUITE_TIMING_FILE", "")
    if timing and not os.path.isabs(timing):
        print("run_unittest_dir: SUITE_TIMING_FILE 은 절대 경로여야 한다 — 기록하지 않는다: %s" % timing,
              file=sys.stderr)
        timing = ""
    if len(argv) < 2:
        print("사용: run_unittest_dir.py <디렉토리> [패턴]", file=sys.stderr)
        return 2
    start = argv[1]
    pattern = argv[2] if len(argv) > 2 else "test_*.py"
    suite = unittest.defaultTestLoader.discover(start, pattern=pattern)
    if not timing:
        result = unittest.TextTestRunner(stream=sys.stdout, verbosity=1).run(suite)
        return 0 if result.wasSuccessful() else 1
    _TimedResult.start_dir = start
    try:
        _TimedResult.base_dir = os.getcwd()
    except OSError:
        _TimedResult.base_dir = ""
    result = unittest.TextTestRunner(stream=sys.stdout, verbosity=1, resultclass=_TimedResult).run(suite)
    write_timing(timing, result.module_secs)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
