"""Regression test for AC12 (P21 Secret 미노출).

Scans SKILL.md and other persona/agent files for AskUserQuestion-like prompts
that could solicit secret values. The contract: every user-facing option label
must be a *decision* (yes/no, retry/skip/abort) or *path*, never a free-form
input for a secret.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Files where AskUserQuestion options are defined or instructed.
TARGETS = [
    ROOT / "skills/quality-pipeline/SKILL.md",
    ROOT / "agents/runtime-verifier.md",
]

# Patterns that suggest secret-value extraction.
# These are heuristics: a free-text "input X" near a secret-like keyword is
# the smell we're guarding against. We accept these in option DESCRIPTIONS
# (e.g., "user has set DB_URL in .env") but flag any imperative
# "ask the user for <SECRET>" or "input the API_KEY" pattern.
SECRET_KEYWORDS = r"(API[_-]?KEY|TOKEN|PASSWORD|SECRET|CREDENTIAL|PRIVATE[_-]?KEY|DB[_-]?URL|DATABASE[_-]?URL|CONNECTION[_-]?STRING)"
LEAK_PATTERN = re.compile(
    rf"(ask|prompt|input|enter|provide|paste|type)\b[^\.\n]{{0,80}}\b{SECRET_KEYWORDS}\b",
    re.IGNORECASE,
)
# Whitelist: explicit text saying we DO NOT ask for secrets is fine.
NEGATION_HINT = re.compile(
    r"(never|don't|do not|cannot|must not)\b[^\.\n]{0,30}\b(ask|prompt|input)",
    re.IGNORECASE,
)


class TestNoSecretPrompts(unittest.TestCase):
    def test_no_imperative_secret_extraction(self):
        offenders = []
        for path in TARGETS:
            if not path.exists():
                continue
            text = path.read_text()
            for match in LEAK_PATTERN.finditer(text):
                start = max(0, match.start() - 100)
                ctx = text[start:match.end() + 50]
                if NEGATION_HINT.search(ctx):
                    continue  # Negated mention is fine
                offenders.append(f"{path.name}:{text[:match.start()].count(chr(10)) + 1}: "
                                 f"...{ctx[-150:]}...")
        self.assertEqual(offenders, [],
                         "Found prompts that may solicit secret values:\n"
                         + "\n".join(offenders))

    def test_runtime_verifier_disallows_secret_request(self):
        """runtime-verifier.md must explicitly state it does not request secret values."""
        path = ROOT / "agents/runtime-verifier.md"
        text = path.read_text()
        # Must contain explicit guard text.
        self.assertRegex(
            text,
            r"(do not request secret|never request secret|cannot request secret|"
            r"never ask.*secret|do not ask.*secret)",
            "runtime-verifier.md must explicitly forbid secret-value requests",
        )

if __name__ == "__main__":
    unittest.main()
