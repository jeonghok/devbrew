"""T3-4 behavioral test for plan-verifier.

Validates that plan-verifier's frozen YAML output meets schema + verdict enum
contract. Uses tests/harness/agent_stub.py to short-circuit dispatch
(deterministic, hermetic — no LLM call).

AC45 verdict enum match | AC46 schema completeness | AC47 no-silent-skip.
"""
import sys
from pathlib import Path
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent / "harness"))
from agent_stub import run_agent_stub, assert_yaml_schema  # noqa: E402

PLAN_VERIFIER_FROZEN = """
verdict: PASS
plan_path: docs/superpowers/plans/2026-05-01-feature.md
matched_items:
  - implement X
  - test Y
unmatched_items: []
unexpected_files: []
"""


def test_AC45_plan_verifier_verdict_enum():
    """verdict must be PASS/FAIL/SKIP/NEEDS_CLARIFICATION."""
    parsed = run_agent_stub("plan-verifier", "p", PLAN_VERIFIER_FROZEN)
    assert_yaml_schema(
        parsed,
        required_keys=["verdict", "matched_items", "unmatched_items"],
        enum={"verdict": ["PASS", "FAIL", "SKIP", "NEEDS_CLARIFICATION"]},
    )


def test_AC46_plan_verifier_missing_key_raises():
    bad = "verdict: PASS\n"
    parsed = run_agent_stub("plan-verifier", "p", bad)
    with pytest.raises(AssertionError):
        assert_yaml_schema(parsed, ["verdict", "matched_items"])


def test_AC47_plan_verifier_invalid_yaml_raises():
    """No silent skip on bad input — must raise AssertionError."""
    with pytest.raises(AssertionError):
        run_agent_stub("plan-verifier", "p", "not: : : valid yaml")
