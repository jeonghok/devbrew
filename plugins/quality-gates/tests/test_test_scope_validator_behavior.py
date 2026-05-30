"""T3-4 behavioral test for test-scope-validator.

Validates that test-scope-validator's frozen YAML output meets schema +
classification enum contract. Uses tests/harness/agent_stub.py to
short-circuit dispatch (deterministic, hermetic — no LLM call).

AC45 verdict enum match | AC46 schema completeness | AC47 no-silent-skip.
"""
import sys
from pathlib import Path
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent / "harness"))
from agent_stub import run_agent_stub, assert_yaml_schema  # noqa: E402

TEST_SCOPE_FROZEN = """
test_scope_verdicts:
  - file: tests/test_foo.py
    classification: aligned
    evidence: matches plan item P3
  - file: tests/test_old.py
    classification: outdated-suspicion
    evidence: references removed function
summary: 1 aligned, 1 outdated-suspicion, 0 cherry-pick-suspicion, 0 unclear
"""


def test_AC45_test_scope_validator_classification_enum():
    parsed = run_agent_stub("test-scope-validator", "p", TEST_SCOPE_FROZEN)
    assert_yaml_schema(
        parsed,
        required_keys=["test_scope_verdicts", "summary"],
    )
    for v in parsed["test_scope_verdicts"]:
        assert_yaml_schema(
            v,
            required_keys=["file", "classification"],
            enum={"classification": [
                "aligned", "outdated-suspicion",
                "cherry-pick-suspicion", "unclear",
            ]},
        )


def test_AC46_test_scope_validator_missing_key_raises():
    bad = "summary: ok\n"
    parsed = run_agent_stub("test-scope-validator", "p", bad)
    with pytest.raises(AssertionError):
        assert_yaml_schema(parsed, ["test_scope_verdicts", "summary"])


def test_AC47_test_scope_validator_invalid_yaml_raises():
    with pytest.raises(AssertionError):
        run_agent_stub("test-scope-validator", "p", ": : invalid")


# --- v2.1.0: ac_coverage advisory block (spec present) + no-spec fallback ---

TEST_SCOPE_WITH_AC = """
test_scope_verdicts:
  - file: tests/test_foo.py
    classification: aligned
    evidence: matches AC3 behavior
ac_coverage:
  note: "advisory only — does not block the Runtime gate"
  items:
    - id: AC1
      status: covered
      covered_by: ["tests/test_foo.py::test_ac1"]
    - id: AC2
      status: uncovered
      covered_by: []
summary: 1 aligned, 0 outdated-suspicion, 0 cherry-pick-suspicion, 0 unclear
"""

TEST_SCOPE_NO_SPEC = """
test_scope_verdicts:
  - file: tests/test_foo.py
    classification: aligned
    evidence: matches plan item P3
summary: 1 aligned, 0 outdated-suspicion, 0 cherry-pick-suspicion, 0 unclear
"""


def test_ac_coverage_schema_when_spec_present():
    """When a spec is found, ac_coverage carries per-AC verdicts + advisory note."""
    parsed = run_agent_stub("test-scope-validator", "p", TEST_SCOPE_WITH_AC)
    assert_yaml_schema(
        parsed,
        required_keys=["test_scope_verdicts", "ac_coverage", "summary"],
    )
    ac = parsed["ac_coverage"]
    assert_yaml_schema(ac, required_keys=["note", "items"])
    # AC5: note declares advisory posture (two stable tokens — robust to dash glyph).
    assert "advisory only" in ac["note"]
    assert "does not block" in ac["note"]
    for item in ac["items"]:
        assert_yaml_schema(
            item,
            required_keys=["id", "status", "covered_by"],
            enum={"status": ["covered", "uncovered"]},
        )


def test_fallback_omits_ac_coverage_when_no_spec():
    """No spec -> ac_coverage omitted; plan-based per-file verdicts still emitted."""
    parsed = run_agent_stub("test-scope-validator", "p", TEST_SCOPE_NO_SPEC)
    assert_yaml_schema(parsed, required_keys=["test_scope_verdicts", "summary"])
    assert "ac_coverage" not in parsed
