"""v10 (AC10 · spec §6): the output schema has no `confidence` key — severity is set by
the criteria block. The persona's own `## Output format` block and the integration
fixture are checked for the same key set.
"""
import re
import unittest
from pathlib import Path

import yaml

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
PERSONA = PLUGIN_ROOT / "agents" / "security-reviewer.md"
FIXTURE = PLUGIN_ROOT / "tests" / "fixtures" / "security-reviewer" / "expected" / "sql-concat.schema.yaml"
FINDING_KEYS = {"agent", "file", "line", "severity", "summary", "proposed_fix"}
# 쉬운 말 출력 §5 — 사람에게 보일 한 문장(선택 칸). 형식에는 있고, 출력에는 있어도 없어도 된다.
OPTIONAL_KEYS = {"plain"}


class SecurityReviewerBehaviorTests(unittest.TestCase):
    def test_v10_persona_output_schema_has_no_confidence(self):
        text = PERSONA.read_text(encoding="utf-8")
        body = text[text.index("\n---\n", 4) + 5:]
        section = body[body.index("\n## Output format\n"):]
        block = re.search(r"```yaml\n(.*?)```", section, re.S)
        self.assertIsNotNone(block, "## Output format has no ```yaml block")
        keys = set(re.findall(r"^\s*-?\s*([a-z_]+):", block.group(1), re.M))
        self.assertEqual(keys, FINDING_KEYS | OPTIONAL_KEYS)

    def test_v10_fixture_schema_has_no_confidence(self):
        entries = yaml.safe_load(FIXTURE.read_text(encoding="utf-8"))
        self.assertTrue(entries)
        for e in entries:
            self.assertEqual(set(e) - OPTIONAL_KEYS, FINDING_KEYS)


if __name__ == "__main__":
    unittest.main()
