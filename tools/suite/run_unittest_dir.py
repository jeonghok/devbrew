#!/usr/bin/env python3
"""디렉토리 하나의 unittest 를 찾아 돌린다 — 실패마다 unittest 의 `FAIL:` · `ERROR:` 줄, 하나라도 있으면 rc 1.

사용: python3 tools/suite/run_unittest_dir.py <디렉토리> [패턴]   (패턴 기본 test_*.py)
스크립트 파일 호출이라 sys.path 맨 앞은 이 폴더이고, 사용자 site-packages 는 그대로 남는다.
환경 변수 SUITE_TIMING_FILE(절대 경로)이 있으면 끝에 `<초>\tpymod\t<폴더>/<모듈 파일>` 줄을 덧붙인다 —
테스트에는 물려주지 않는다. 빈 값은 없는 것과 같다.
한 모듈의 초 = 그 모듈 테스트들의 몸통 + 그 모듈의 클래스 · 모듈 준비와 정리.
"""
import os
import sys
import time
import unittest


def _path_key(modname, start_abs, base):
    return os.path.relpath(os.path.join(start_abs, *modname.split(".")) + ".py", base)


def module_key(modname, start_abs, base):
    """모듈 파일의 base 기준 상대 경로. `__file__` 이 없으면 시작 폴더 아래 점 이름의 파일. 죽지 않는다."""
    try:
        path = getattr(sys.modules.get(modname), "__file__", None)
        if path:
            return os.path.relpath(path, base)
        return _path_key(modname, start_abs, base)
    except Exception:
        return modname


def test_module_key(test, start_abs, base):
    """테스트의 모듈 키. 로더가 만든 자리 테스트(임포트 실패 · 모듈 건너뜀)는 그 모듈의 점 이름으로 가른다."""
    if type(test).__module__ == "unittest.loader":
        name = getattr(test, "_testMethodName", "")
        try:
            return _path_key(name, start_abs, base)
        except Exception:
            return name
    return module_key(type(test).__module__, start_abs, base)


def timed_result_class(start_abs, base):
    """모듈별 초를 모으는 결과 클래스. `_TimedSuite` 가 준비 · 정리 몫을 `charge` 로 더한다."""

    class _TimedResult(unittest.TextTestResult):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            self.module_secs = {}
            self.timing_prev_key = None
            self.timing_teardown_total = 0.0
            self._timing_started = None

        def key_of(self, test):
            return test_module_key(test, start_abs, base)

        def charge(self, key, secs):
            self.module_secs[key] = self.module_secs.get(key, 0.0) + secs

        def startTest(self, test):
            self.timing_prev_key = self.key_of(test)
            self._timing_started = time.monotonic()
            super().startTest(test)

        def stopTest(self, test):
            if self._timing_started is not None:
                self.charge(self.key_of(test), time.monotonic() - self._timing_started)
                self._timing_started = None
            super().stopTest(test)

    return _TimedResult


class _TimedSuite(unittest.TestSuite):
    """정리는 앞 테스트의 모듈에, 준비(안에 든 정리를 뺀 몫)는 이번 테스트의 모듈에 더한다."""

    def _timed_teardown(self, result, call):
        if getattr(result, "charge", None) is None:
            return call()
        t0 = time.monotonic()
        out = call()
        secs = time.monotonic() - t0
        result.timing_teardown_total += secs
        if result.timing_prev_key is not None:
            result.charge(result.timing_prev_key, secs)
        return out

    def _timed_setup(self, test, result, call):
        if getattr(result, "charge", None) is None:
            return call()
        before = result.timing_teardown_total
        t0 = time.monotonic()
        out = call()
        secs = time.monotonic() - t0 - (result.timing_teardown_total - before)
        key = result.key_of(test)
        result.charge(key, max(secs, 0.0))
        result.timing_prev_key = key
        return out

    def _tearDownPreviousClass(self, test, result):
        return self._timed_teardown(result, lambda: super(_TimedSuite, self)._tearDownPreviousClass(test, result))

    def _handleModuleTearDown(self, result):
        return self._timed_teardown(result, lambda: super(_TimedSuite, self)._handleModuleTearDown(result))

    def _handleModuleFixture(self, test, result):
        return self._timed_setup(test, result, lambda: super(_TimedSuite, self)._handleModuleFixture(test, result))

    def _handleClassSetUp(self, test, result):
        return self._timed_setup(test, result, lambda: super(_TimedSuite, self)._handleClassSetUp(test, result))


def write_timing(path, module_secs):
    text = "".join("%.3f\tpymod\t%s\n" % (module_secs[key], key) for key in sorted(module_secs))
    try:
        text.encode("utf-8")
        with open(path, "a", encoding="utf-8") as fh:
            fh.write(text)
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
    if not timing:
        suite = unittest.defaultTestLoader.discover(start, pattern=pattern)
        result = unittest.TextTestRunner(stream=sys.stdout, verbosity=1).run(suite)
        return 0 if result.wasSuccessful() else 1
    try:
        base = os.getcwd()
        start_abs = os.path.abspath(start)
    except OSError:
        base = ""
        start_abs = start
    loader = unittest.TestLoader()
    loader.suiteClass = _TimedSuite
    suite = loader.discover(start, pattern=pattern)
    runner = unittest.TextTestRunner(stream=sys.stdout, verbosity=1,
                                     resultclass=timed_result_class(start_abs, base))
    result = runner.run(suite)
    write_timing(timing, result.module_secs)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
