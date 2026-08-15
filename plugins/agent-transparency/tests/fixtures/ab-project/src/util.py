import csv

from src.calc import add


def double(n):
    return n * 2


def describe(n):
    return "positive" if n > 0 else "non-positive"


def _cell(value):
    value = value.strip()
    return int(value) if value else None


def total(path):
    """data.csv 의 각 행에 든 두 값을 add 로 누적한다."""
    running = 0
    with open(path, newline="", encoding="utf-8") as fh:
        for row in csv.reader(fh):
            running = add(running, add(_cell(row[0]), _cell(row[1])))
    return running
