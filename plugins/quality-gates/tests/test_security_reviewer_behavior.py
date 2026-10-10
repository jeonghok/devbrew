"""T3-4 behavioral test for security-reviewer.

Validates that security-reviewer's frozen YAML output meets schema + severity
enum contract. Uses tests/harness/agent_stub.py to short-circuit dispatch
(deterministic, hermetic — no LLM call).

AC45 verdict enum match | AC46 schema completeness | AC47 no-silent-skip.
v10 (AC10 · spec §6): the output schema has no `confidence` key — severity is set by
the criteria block. The persona's own `## Output format` block and the integration
fixture are checked for the same key set, so the stub cannot drift from them.
"""
import re
import sys
import unittest
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent / "harness"))
from agent_stub import run_agent_stub, assert_yaml_schema  # noqa: E402

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
PERSONA = PLUGIN_ROOT / "agents" / "security-reviewer.md"
FIXTURE = PLUGIN_ROOT / "tests" / "fixtures" / "security-reviewer" / "expected" / "sql-concat.schema.yaml"
FINDING_KEYS = {"agent", "file", "line", "severity", "summary", "proposed_fix"}

SEC_REVIEWER_FROZEN = """
agent: security-reviewer
findings:
  - severity: CRITICAL
    file: src/auth.py
    line: 42
    summary: SQL injection in raw query
    proposed_fix: use parameterized queries
  - severity: IMPORTANT
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
                required_keys=["severity", "file", "line"],
                enum={"severity": ["CRITICAL", "IMPORTANT", "SUGGESTION"]},
            )
            self.assertNotIn("confidence", f)

    def test_v10_persona_output_schema_has_no_confidence(self):
        text = PERSONA.read_text(encoding="utf-8")
        body = text[text.index("\n---\n", 4) + 5:]
        section = body[body.index("\n## Output format\n"):]
        block = re.search(r"```yaml\n(.*?)```", section, re.S)
        self.assertIsNotNone(block, "## Output format has no ```yaml block")
        keys = set(re.findall(r"^\s*-?\s*([a-z_]+):", block.group(1), re.M))
        self.assertEqual(keys, FINDING_KEYS)

    def test_v10_fixture_schema_has_no_confidence(self):
        entries = yaml.safe_load(FIXTURE.read_text(encoding="utf-8"))
        self.assertTrue(entries)
        for e in entries:
            self.assertEqual(set(e), FINDING_KEYS)

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
