import unittest

from src.calc import add


class TestAddNegative(unittest.TestCase):
    def test_both_negative(self):
        self.assertEqual(add(-2, -3), -5)

    def test_mixed_signs(self):
        self.assertEqual(add(-2, 3), 1)

    def test_zero_boundary(self):
        self.assertEqual(add(0, 0), 0)
