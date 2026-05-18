"""T3-4 behavioral test for runtime-verifier.

Validates that runtime-verifier's frozen YAML output meets schema + verdict
enum contract. Uses tests/harness/agent_stub.py to short-circuit dispatch
(deterministic, hermetic — no LLM call).

AC45 verdict enum match | AC46 schema completeness | AC47 no-silent-skip.
"""
import sys
from pathlib import Path
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent / "harness"))
from agent_stub import run_agent_stub, assert_yaml_schema  # noqa: E402

RUNTIME_VERIFIER_FROZEN = """
verdict: PASS
evidence_log:
  - surface: docker-compose
    result: started; healthcheck PASS at /health
  - surface: pytest
    result: 47/47 PASS
"""


def test_AC45_runtime_verifier_verdict_enum():
    parsed = run_agent_stub("runtime-verifier", "p", RUNTIME_VERIFIER_FROZEN)
    assert_yaml_schema(
        parsed,
        required_keys=["verdict", "evidence_log"],
        enum={"verdict": [
            "PASS", "FAIL", "SKIP", "SKIP_WITH_EVIDENCE",
            "NEEDS_RESOLUTION", "NEEDS_RESTART", "PASS_WITH_WARNINGS",
        ]},
    )


def test_AC46_runtime_verifier_missing_key_raises():
    bad = "verdict: PASS\n"
    parsed = run_agent_stub("runtime-verifier", "p", bad)
    with pytest.raises(AssertionError):
        assert_yaml_schema(parsed, ["verdict", "evidence_log"])


def test_AC47_runtime_verifier_invalid_yaml_raises():
    with pytest.raises(AssertionError):
        run_agent_stub("runtime-verifier", "p", "verdict: : : :")
