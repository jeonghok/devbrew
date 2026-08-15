#!/usr/bin/env python3
"""AC29 게이트 2 의 신뢰 드라이버 — 피검체 코드를 돌리되 **통과의 증거는 피검체가
만들지 않는다.**

게이트 2 는 피검체가 고친 코드를 실행해서 판정한다. 그런데 그 코드는 검증
프로세스 **안에서** 돈다 — import 시점에 `os._exit(0)` 을 하면 프로세스가 종료
코드 0 으로 죽고, 종료 코드만 보는 판정은 그것을 *"테스트가 전부 통과했다"* 로
읽는다. 앞선 판은 두 다리(가시 테스트 · 숨김 오라클) 모두 종료 코드만 봤고,
오라클 쪽에 붙어 있던 완주 센티널은 그 경로를 **환경변수로 피검체에게 알려주고
있었다** — 피검체가 자기가 써 놓고 `_exit(0)` 하면 과업을 0% 해도 게이트 2 가
`visible=0 oracle=0 hash=ok` 로 통과했다(2026-08-15 리뷰가 재현).

그래서 이 모듈이 다음 셋을 소유한다.

1. **완주 증거.** `result.testsRun` 이 기대치와 같고 `wasSuccessful()` 일 때만
   센티널을 쓴다. 중간에 죽으면 파일이 없고, 러너는 종료 코드 **와** 그 파일을
   둘 다 본다.
2. **경로의 비공개.** 센티널 경로는 **stdin 한 줄로만** 들어온다. `os.environ`
   에도 넣지 않고, 피검체 코드를 import 하기 전에 `sys.argv` 를 지운다 — 둘 다
   피검체 코드가 한 줄로 읽는 표면이다.
3. **기대 테스트 수.** `count` 모드가 픽스처 **원본**을 AST 로 센다. import 로
   세면 피검체가 고쳐 놓은 파일을 세게 되어 기대값이 피검체를 따라간다.

**이것이 막지 못하는 것.** 피검체 코드는 이 프로세스 안에서 사용자 권한으로
돈다 — 파일시스템을 훑어 센티널 디렉토리를 찾아내는 것까지 막지는 못한다.
막는 것은 *"한 줄로 읽어서"* 되는 경로이고, 그 너머는 `ab_seal.py` 의 봉인이
사후에 **탐지**한다. 완전한 차단은 OS 수준 격리가 필요하며 이 하니스의 범위가
아니다 — 통과를 그 이상으로 읽지 않도록 그 사실을 여기 적어 둔다.

Run (러너가 부르는 실제 형태 — 1회용 사본 `$VER` 안에서):

    printf '%s\\n' "$sentinel" | ( cd "$VER" && python3 -I -S ./ab_driver.py run \\
        --subject "$FX" --expect 5 tests.test_calc tests.test_calc_negative )
"""
from __future__ import annotations

import ast
import os
import sys
import unittest


def count_tests(paths):
    """`test` 로 시작하는 메서드 수를 **import 없이** 센다.

    `unittest` 기본 `testMethodPrefix` 와 같은 접두를 쓴다. AST 로 세는 이유는
    두 가지다 — 피검체 코드를 실행하지 않고, 러너가 첫 반복 **전에** 원본
    픽스처에서 기대값을 못박을 수 있다.
    """
    total = 0
    for path in paths:
        with open(path, "r", encoding="utf-8") as fh:
            tree = ast.parse(fh.read(), filename=path)
        for node in ast.walk(tree):
            if not isinstance(node, ast.ClassDef):
                continue
            for stmt in node.body:
                if isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef)) \
                        and stmt.name.startswith("test"):
                    total += 1
    return total


def run_modules(subject_dir, module_names, expect, sentinel, stream=None):
    """피검체 트리를 sys.path 에 얹고 모듈들을 돌린다. 성공일 때만 센티널을 쓴다.

    `sys.path` 를 여기서 명시적으로 조립하는 것이 load-bearing 이고, **순서가 그
    핵심이다.** 앞선 판은 `PYTHONPATH` 로 넘겼는데 그러면 피검체 트리가 **stdlib
    앞**에 놓여, `$FX/unittest/`·`$FX/encodings/` 를 심는 것만으로 검증 프로세스가
    피검체의 가짜 stdlib 을 쓴다(리뷰가 A3 로 적발). 러너가 `-I -S` 로 부르므로
    `PYTHONPATH` 도 `sitecustomize` 도 무시되고, 여기서:

        [신뢰 사본($VER)] + [stdlib …] + [피검체 트리($FX)]

    **피검체 트리는 append 다 — insert 가 아니다.** insert 로 앞에 놓으면
    `PYTHONPATH` 를 지운 의미가 사라진다(같은 구멍을 다른 문으로 연다).

    반환값은 (통과 여부, testsRun). 통과 = `wasSuccessful()` **그리고**
    `testsRun == expect`. 개수를 함께 보는 이유: import 실패는 unittest 가
    `_FailedTest` 한 개로 감싸므로 개수만으로도 갈리고, 반대로 모듈이 조용히
    비면 `wasSuccessful()` 만으로는 공허하게 참이 된다.
    """
    here = os.path.dirname(os.path.abspath(__file__))
    if here and here not in sys.path:
        sys.path.insert(0, here)          # 신뢰 사본이 맨 앞
    if subject_dir and subject_dir not in sys.path:
        sys.path.append(subject_dir)      # 피검체는 stdlib **뒤**
    # 오라클이 `data.csv` 를 찾는 좌표. **비밀이 아니다** — 피검체 자신의
    # 디렉토리이므로 환경변수로 두어도 새는 것이 없다. 센티널과 대비된다.
    os.environ["AT_SUBJECT_DIR"] = subject_dir

    # 피검체 코드가 읽을 수 있는 표면에서 러너의 인자를 지운다. 이 줄이 없으면
    # `--expect`/`--subject` 뿐 아니라 향후 누군가 센티널을 argv 로 옮겼을 때
    # 곧바로 재발한다 — 지우는 것을 기본값으로 둔다.
    sys.argv = sys.argv[:1]

    suite = unittest.TestLoader().loadTestsFromNames(list(module_names))
    runner = unittest.TextTestRunner(stream=stream or sys.stderr, verbosity=0)
    result = runner.run(suite)
    ok = bool(result.wasSuccessful()) and result.testsRun == expect
    if ok and sentinel:
        with open(sentinel, "w", encoding="utf-8") as fh:
            fh.write("ran=%d ok=True\n" % result.testsRun)
    return ok, result.testsRun


def _parse_run_args(argv):
    subject, expect, modules = None, None, []
    rest = list(argv)
    while rest:
        token = rest.pop(0)
        if token in ("--subject", "--expect"):
            if not rest:
                raise SystemExit("%s 에 값이 없다" % token)
            value = rest.pop(0)
            if token == "--subject":
                subject = value
            else:
                expect = value
        elif token.startswith("--"):
            raise SystemExit("알 수 없는 인자: %s" % token)
        else:
            modules.append(token)
    return subject, expect, modules


def main(argv):
    if len(argv) < 2:
        sys.stderr.write("usage: ab_driver.py count <file>... "
                         "| ab_driver.py run --subject DIR --expect N <module>...\n")
        return 2

    if argv[1] == "count":
        if len(argv) < 3:
            sys.stderr.write("count 에 파일이 없다\n")
            return 2
        sys.stdout.write("%d\n" % count_tests(argv[2:]))
        return 0

    if argv[1] != "run":
        sys.stderr.write("알 수 없는 모드: %s\n" % argv[1])
        return 2

    subject, expect, modules = _parse_run_args(argv[2:])
    if not subject or not os.path.isdir(subject):
        sys.stderr.write("--subject 가 디렉토리가 아니다: %r\n" % (subject,))
        return 2
    if not modules:
        sys.stderr.write("돌릴 모듈이 없다\n")
        return 2
    if expect is None:
        sys.stderr.write("--expect 가 없다\n")
        return 2
    try:
        expect = int(expect)
    except ValueError:
        sys.stderr.write("--expect 가 수가 아니다: %r\n" % (expect,))
        return 2
    if expect <= 0:
        # 0 을 허용하면 아무것도 안 돈 실행이 `testsRun == expect` 로 통과한다.
        sys.stderr.write("--expect 는 1 이상이어야 한다: %d\n" % expect)
        return 2

    # 센티널은 **stdin 으로만** 온다. tty 면 사람이 손으로 부른 것이므로 매달리는
    # 대신 크게 실패한다 — 조용한 hang 은 게이트를 영원히 막는다.
    if sys.stdin is None or sys.stdin.isatty():
        sys.stderr.write("센티널 경로를 stdin 으로 받아야 한다\n")
        return 2
    sentinel = sys.stdin.readline().strip()
    if not sentinel:
        sys.stderr.write("stdin 에 센티널 경로가 없다\n")
        return 2

    ok, ran = run_modules(subject, modules, expect, sentinel)
    sys.stderr.write("[ab_driver] ran=%d expect=%d ok=%s modules=%s\n"
                     % (ran, expect, ok, ",".join(modules)))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
