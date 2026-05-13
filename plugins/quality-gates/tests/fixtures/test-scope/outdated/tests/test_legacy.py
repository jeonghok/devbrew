from src.legacy import parse_v1  # <- references removed symbol

def test_parse_v1_basic():
    assert parse_v1({"data": "x"}) == {"version": 1, "data": "x"}
