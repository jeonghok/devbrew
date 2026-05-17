"""Self-tests for the agent_stub harness (T3-4 prerequisite).

Verifies the harness itself does what it claims before any behavioral test
relies on it.
"""
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent / "harness"))
from agent_stub import run_agent_stub, assert_yaml_schema  # noqa: E402


def test_run_agent_stub_parses_valid_yaml():
    parsed = run_agent_stub("test", "p", "verdict: PASS\nmatched: []\n")
    assert parsed == {"verdict": "PASS", "matched": []}


def test_run_agent_stub_raises_on_invalid_yaml():
    with pytest.raises(AssertionError):
        run_agent_stub("test", "p", "verdict: : : invalid")


def test_assert_yaml_schema_missing_key():
    with pytest.raises(AssertionError) as ei:
        assert_yaml_schema({"a": 1}, ["a", "b"])
    assert "b" in str(ei.value)


def test_assert_yaml_schema_enum_violation_scalar():
    with pytest.raises(AssertionError) as ei:
        assert_yaml_schema(
            {"verdict": "MAYBE"},
            required_keys=["verdict"],
            enum={"verdict": ["PASS", "FAIL"]},
        )
    assert "MAYBE" in str(ei.value)


def test_assert_yaml_schema_enum_violation_list():
    with pytest.raises(AssertionError):
        assert_yaml_schema(
            {"tags": ["good", "bad"]},
            required_keys=["tags"],
            enum={"tags": ["good", "fine"]},
        )


def test_assert_yaml_schema_happy_path_scalar():
    # No exception expected
    assert_yaml_schema(
        {"verdict": "PASS"},
        required_keys=["verdict"],
        enum={"verdict": ["PASS", "FAIL", "SKIP"]},
    )


def test_assert_yaml_schema_non_dict_raises():
    with pytest.raises(AssertionError):
        assert_yaml_schema(["not", "a", "dict"], ["verdict"])
