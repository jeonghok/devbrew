"""T3-4 behavioral test for test-scope-validator.

Validates that test-scope-validator's frozen YAML output meets schema +
classification enum contract. Uses tests/harness/agent_stub.py to
short-circuit dispatch (deterministic, hermetic — no LLM call).

AC45 verdict enum match | AC46 schema completeness | AC47 no-silent-skip.
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "harness"))
from agent_stub import run_agent_stub, assert_yaml_schema  # noqa: E402

PERSONA = Path(__file__).resolve().parents[1] / "agents" / "test-scope-validator.md"

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


class TestScopeValidatorBehaviorTests(unittest.TestCase):
    def test_AC45_test_scope_validator_classification_enum(self):
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

    def test_AC46_test_scope_validator_missing_key_raises(self):
        bad = "summary: ok\n"
        parsed = run_agent_stub("test-scope-validator", "p", bad)
        with self.assertRaises(AssertionError):
            assert_yaml_schema(parsed, ["test_scope_verdicts", "summary"])

    def test_AC47_test_scope_validator_invalid_yaml_raises(self):
        with self.assertRaises(AssertionError):
            run_agent_stub("test-scope-validator", "p", ": : invalid")

    # --- v2.1.0: ac_coverage no longer exists (spec or no spec) ---

    def test_persona_no_longer_emits_ac_coverage(self):
        """§6.5.1 7행 — spec AC 런타임 검증이 사라지며 ac_coverage 출력도 사라진다.
        분류 축(spec AC 1차)은 그대로다."""
        text = PERSONA.read_text(encoding="utf-8")
        self.assertNotIn("ac_coverage", text)
        self.assertIn("spec_path", text, "spec 은 여전히 1차 분류 축이다(양의 짝)")


if __name__ == "__main__":
    unittest.main()
