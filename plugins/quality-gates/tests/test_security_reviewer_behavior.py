"""T3-4 behavioral test for security-reviewer.

Validates that security-reviewer's frozen YAML output meets schema + severity
enum contract. Uses tests/harness/agent_stub.py to short-circuit dispatch
(deterministic, hermetic — no LLM call).

AC45 verdict enum match | AC46 schema completeness | AC47 no-silent-skip.
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "harness"))
from agent_stub import run_agent_stub, assert_yaml_schema  # noqa: E402

SEC_REVIEWER_FROZEN = """
agent: security-reviewer
findings:
  - severity: CRITICAL
    confidence: 9
    file: src/auth.py
    line: 42
    summary: SQL injection in raw query
    proposed_fix: use parameterized queries
  - severity: IMPORTANT
    confidence: 8
    file: src/api.py
    line: 100
    summary: missing authz check
    proposed_fix: add middleware
"""


class SecurityReviewerBehaviorTests(unittest.TestCase):
    def test_AC45_security_reviewer_findings_schema(self):
        parsed = run_agent_stub("security-reviewer", "p", SEC_REVIEWER_FROZEN)
        assert_yaml_schema(parsed, required_keys=["agent", "findings"])
        for f in parsed["findings"]:
            assert_yaml_schema(
                f,
                required_keys=["severity", "confidence", "file", "line"],
                enum={"severity": ["CRITICAL", "IMPORTANT", "SUGGESTION"]},
            )
            self.assertTrue(1 <= int(f["confidence"]) <= 10)

    def test_AC46_security_reviewer_missing_key_raises(self):
        bad = "agent: security-reviewer\n"
        parsed = run_agent_stub("security-reviewer", "p", bad)
        with self.assertRaises(AssertionError):
            assert_yaml_schema(parsed, ["agent", "findings"])

    def test_AC47_security_reviewer_invalid_yaml_raises(self):
        with self.assertRaises(AssertionError):
            run_agent_stub("security-reviewer", "p", "agent: : : invalid")


if __name__ == "__main__":
    unittest.main()
