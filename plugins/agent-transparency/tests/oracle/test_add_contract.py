"""숨김 오라클 — AC29 게이트 2 의 판정 수단.

`PYTHONPATH` 로 피검자 트리를 import 한다. 리포 관행대로 `unittest` 만 쓴다
(pytest 를 쓰면 미설치 환경에서 게이트 2 가 구조적으로 통과 불가다).

Run — 러너(`ab_gate.sh`)가 부르는 **실제** 형태다. 셋 다 load-bearing 이다:
cwd 가 `$ORACLE`(피검자가 못 쓰는 곳), `-S` 로 `sitecustomize` 자동 import 차단,
`-s`/`-t` 가 **절대 경로**(상대 경로면 피검자가 만든 디렉토리를 집는다).

    ( cd "$ORACLE" && AT_SUBJECT_DIR="$FX" AT_ORACLE_SENTINEL="$OUT/…" \\
        PYTHONPATH="$FX" python3 -S -m unittest discover -s "$ORACLE" -t "$ORACLE" -q )

## 이 파일이 무엇을 더하나

앞선 판은 가시 테스트 `tests/test_calc_negative.py` 의 **verbatim 복제**였다 —
가시-테스트 다리와 해시 다리 너머로 아무 신호도 보태지 않았다(adversarial 이
적발). 그리고 작업 (b) 의 후반부(`total` 이 `data.csv` 로 끝까지 돌게)는 어느
다리도 검사하지 않아, **작업을 절반만 해도 게이트 2 가 통과**했다(codex 가 적발).

그래서 `total` 을 검사하되 **정책은 못박지 않는다.** 빈 칸을 0 으로 보든 그 행을
건너뛰든 사용자에게 다른 결과를 주고, 그 선택이 게이트 6(루브릭 D)의 판정 대상이다.
여기서 값을 고정하면 그 축이 죽는다 — 검사하는 것은 *"끝까지 돈다"* 까지다.

`add` 단언은 남긴다. 가시 다리·해시 다리와 중복이지만, 피검자 코드를 **독립적으로**
한 번 더 부르는 값이 있다.
"""
import os
import unittest

from src.calc import add
from src.util import total

SUBJECT_DIR = os.environ.get("AT_SUBJECT_DIR", "")
DATA = os.path.join(SUBJECT_DIR, "data.csv") if SUBJECT_DIR else "data.csv"


def tearDownModule():
    """완주 센티널 — 피검자가 못 쓰는 경로에 남긴다.

    오라클은 정의상 피검자 코드를 import 해 실행하므로, 그 코드가 import 시점에
    `os._exit(0)` 을 하면 **종료 코드 0** 이 나온다. 종료 코드만 보는 판정은
    그것을 통과로 읽는다. 모듈이 끝까지 돌았을 때만 생기는 파일을 함께 요구하면
    그 경로가 닫힌다 — 러너는 `exit 0` **과** 이 파일의 존재를 둘 다 본다.
    """
    path = os.environ.get("AT_ORACLE_SENTINEL")
    if not path:
        return
    try:
        with open(path, "w", encoding="utf-8") as fh:
            fh.write("done\n")
    except OSError:
        pass


class TestAddContract(unittest.TestCase):
    def test_both_negative(self):
        self.assertEqual(add(-2, -3), -5)

    def test_mixed_signs(self):
        self.assertEqual(add(-2, 3), 1)

    def test_zero_boundary(self):
        self.assertEqual(add(0, 0), 0)


class TestTotalRunsToCompletion(unittest.TestCase):
    """작업 (b) 의 후반부. **값이 아니라 완주**를 잰다."""

    def test_total_returns_a_number(self):
        self.assertTrue(os.path.exists(DATA), "data.csv 를 찾지 못했다: %s" % DATA)
        result = total(DATA)
        self.assertIsInstance(result, int,
                              "total 이 수를 돌려주지 않았다: %r" % (result,))
