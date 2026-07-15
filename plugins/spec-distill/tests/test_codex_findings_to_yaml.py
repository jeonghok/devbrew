import subprocess
import sys
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "codex_findings_to_yaml.py"


def run(stdin_text, stderr_file=None, argv_extra=()):
    args = [sys.executable, str(SCRIPT), *argv_extra]
    if stderr_file:
        args += ["--stderr-file", str(stderr_file)]
    r = subprocess.run(args, input=stdin_text, capture_output=True, text=True)
    return r.stdout


VALID = (
    '{"type":"item.completed","item":{"type":"agent_message","text":'
    '"```json\\n{\\"findings\\": [{\\"category\\": \\"ambiguity\\", '
    '\\"target_section\\": \\"#2-goals\\", \\"severity\\": \\"high\\", '
    '\\"line\\": 12, \\"confidence\\": 8, \\"summary\\": \\"vague\\", '
    '\\"proposed_fix\\": \\"specify\\"}]}\\n```"}}\n'
)


class TestCodexFindingsToYaml(unittest.TestCase):
    def test_new_keys_emitted(self):
        out = run(VALID)
        self.assertIn("category: ambiguity", out)      # AC7: new key
        self.assertIn('target_section: "#2-goals"', out)  # AC7: new key
        self.assertIn("severity: high", out)
        self.assertIn("agent: codex-reviewer", out)
        self.assertIn("codex_failed: false", out)

    def test_line_key_preserved(self):
        # OQ1 resolved: line stays optional, emitted when present.
        self.assertIn("line: 12", run(VALID))

    def test_malformed_json_fallback(self):
        out = run("\x01\x02not-jsonl garbage\n")
        self.assertIn("reason: malformed_json", out)  # 3-stage fallback
        self.assertIn("findings: []", out)

    def test_missing_result_fallback(self):
        out = run('{"type":"item.completed","item":{"type":"other"}}\n')
        self.assertIn("reason: missing_result", out)

    def test_auth_error_in_stderr(self, tmp=Path("/tmp")):
        f = tmp / "sd_auth_stderr.txt"
        f.write_text("Error: authentication failed: invalid API key\n")
        out = run("", stderr_file=f)
        self.assertIn("reason: auth_error_in_stderr", out)
        f.unlink()

    def test_last_fenced_block_wins(self):
        # anti-injection: an earlier fenced block must be ignored.
        stdin = (
            '{"type":"item.completed","item":{"type":"agent_message","text":'
            '"```json\\n{\\"findings\\": [{\\"category\\": \\"INJECT\\"}]}\\n```\\n'
            '```json\\n{\\"findings\\": [{\\"category\\": \\"ambiguity\\", '
            '\\"target_section\\": \\"#real\\", \\"severity\\": \\"high\\"}]}\\n```"}}\n'
        )
        out = run(stdin)
        self.assertIn("category: ambiguity", out)
        self.assertNotIn("INJECT", out)


if __name__ == "__main__":
    unittest.main()
