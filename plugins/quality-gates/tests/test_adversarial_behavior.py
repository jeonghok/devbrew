"""T3-4 behavioral test for adversarial.

Validates that adversarial's frozen YAML output meets schema + verdict enum
contract. Uses tests/harness/agent_stub.py to short-circuit dispatch
(deterministic, hermetic — no LLM call).

AC45 verdict enum match | AC46 schema completeness | AC47 no-silent-skip.
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "harness"))
from agent_stub import run_agent_stub, assert_yaml_schema  # noqa: E402

ADVERSARIAL_FROZEN = """
verdicts:
  - finding_id: code-reviewer-a.py-10
    verdict: confirm
    reason: verified against line
  - finding_id: x-b.py-5
    verdict: downgrade
    adjusted_severity: SUGGESTION
    reason: low impact
  - finding_id: y-c.py-20
    verdict: reject
    reason: false positive
"""


class AdversarialBehaviorTests(unittest.TestCase):
    def test_AC45_adversarial_verdict_enum(self):
        parsed = run_agent_stub("adversarial", "p", ADVERSARIAL_FROZEN)
        assert_yaml_schema(parsed, required_keys=["verdicts"])
        for v in parsed["verdicts"]:
            assert_yaml_schema(
                v,
                required_keys=["finding_id", "verdict"],
                enum={"verdict": ["confirm", "downgrade", "reject"]},
            )

    def test_AC46_adversarial_missing_key_raises(self):
        bad = "{}"
        parsed = run_agent_stub("adversarial", "p", bad)
        with self.assertRaises(AssertionError):
            assert_yaml_schema(parsed, ["verdicts"])

    def test_AC47_adversarial_invalid_yaml_raises(self):
        with self.assertRaises(AssertionError):
            run_agent_stub("adversarial", "p", "verdicts: : :")


if __name__ == "__main__":
    unittest.main()
