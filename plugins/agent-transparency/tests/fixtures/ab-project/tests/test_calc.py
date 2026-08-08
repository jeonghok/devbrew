import unittest

from src.calc import add


class TestAdd(unittest.TestCase):
    def test_two_positives(self):
        self.assertEqual(add(2, 3), 5)

    def test_zero_and_positive(self):
        self.assertEqual(add(0, 7), 7)
