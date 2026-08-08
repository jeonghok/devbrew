"""숨김 오라클 — 게이트 2 의 판정 수단.

`PYTHONPATH` 로 임시 프로젝트를 import 한다. 리포 관행대로 `unittest` 만 쓴다
(pytest 를 쓰면 미설치 환경에서 게이트 2 가 구조적으로 통과 불가다).

Run (러너가 이렇게 부른다):
    PYTHONPATH="$FX" python3 -m unittest discover -s tests/oracle -t tests/oracle -q
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
