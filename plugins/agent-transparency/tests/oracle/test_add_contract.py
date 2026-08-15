"""숨김 오라클 — AC29 게이트 2 의 판정 수단.

`PYTHONPATH` 로 임시 프로젝트를 import 한다. 리포 관행대로 `unittest` 만 쓴다
(pytest 를 쓰면 미설치 환경에서 게이트 2 가 구조적으로 통과 불가다).

Run — 러너(`ab_gate.sh`)가 부르는 **실제** 형태다. `-s`/`-t` 가 **절대 경로**인
것이 요점이다: 피검자 트리(`$FX`)를 cwd 로 두고 도는데, 상대 경로 `tests/oracle`
로 discover 하면 **피검자가 만든 디렉토리**를 집게 된다.

    ( cd "$FX" && PYTHONPATH="$FX" python3 -m unittest discover \
        -s "$ORACLE" -t "$ORACLE" -q )
"""
import unittest

from src.calc import add


class TestAddContract(unittest.TestCase):
    def test_both_negative(self):
        self.assertEqual(add(-2, -3), -5)

    def test_mixed_signs(self):
        self.assertEqual(add(-2, 3), 1)

    def test_zero_boundary(self):
        self.assertEqual(add(0, 0), 0)
