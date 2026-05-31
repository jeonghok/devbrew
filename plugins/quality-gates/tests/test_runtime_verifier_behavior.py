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
  - surface: npm-script:dev
    result: started; /login flow asserted
writes:
  - path: .env
    class: non-product
    committed: never
functional_assertions:
  - ac_id: AC1
    flow: "navigate /login → submit → expect /dashboard"
    expected: "redirect to /dashboard"
    observed: "redirected to /dashboard"
    evidence_refs:
      - screenshots/login.png
    verdict: PASS
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


def test_v220_runtime_verifier_functional_assertions_schema():
    """v2.2.0: executor output carries functional_assertions bound to ac_id."""
    parsed = run_agent_stub("runtime-verifier", "p", RUNTIME_VERIFIER_FROZEN)
    assert_yaml_schema(
        parsed,
        required_keys=["verdict", "evidence_log", "functional_assertions"],
    )
    fa = parsed["functional_assertions"]
    assert isinstance(fa, list) and len(fa) >= 1, "functional_assertions must be a non-empty list"
    entry = fa[0]
    for k in ("ac_id", "flow", "expected", "observed", "evidence_refs", "verdict"):
        assert k in entry, f"functional_assertions entry missing '{k}'"
