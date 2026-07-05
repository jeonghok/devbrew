"""test_accuracy_warnings.py — the 3 preview safety-net warnings (design §8, AC5).
These are the ONLY backstop for the removed hard-blocks, so each is named and
regression-locked. Run: python3 -m unittest (from repo root)."""
from __future__ import annotations
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
SCRIPT = PLUGIN_ROOT / "scripts" / "render-terminal.py"


def run(artifact: str, facts: str, changed: str) -> str:
    with tempfile.TemporaryDirectory() as d:
        a = Path(d) / "art"; f = Path(d) / "facts"; c = Path(d) / "changed"
        a.write_text(artifact, encoding="utf-8")
        f.write_text(facts, encoding="utf-8")
        c.write_text(changed, encoding="utf-8")
        r = subprocess.run([sys.executable, str(SCRIPT), "accuracy-warnings",
                            "--artifact", str(a), "--facts", str(f), "--changed", str(c)],
                           capture_output=True, text=True)
        return r.stdout


FACTS = "nodes:\nsrc/api.py\nsrc/db.py\nedges:\nsrc/api.py -> src/db.py\ndegraded: no"
CHANGED = "src/api.py\n"


class AccuracyWarnings(unittest.TestCase):
    def test_hallucinated_node(self):
        art = "```mermaid\ngraph TD\n  api --> cache\n  cache[src/cache.py]\n```"
        out = run(art, FACTS, CHANGED)
        self.assertIn("possible hallucinated node", out, out)
        self.assertIn("src/cache.py", out, out)

    def test_hallucinated_file(self):
        art = "| src/api.py | NEW |\n| src/ghost.py | NEW |"
        out = run(art, FACTS, CHANGED)
        self.assertIn("possible hallucinated file", out, out)
        self.assertIn("src/ghost.py", out, out)

    def test_unverified_testing_claim(self):
        art = "**Testing** — covered by test_api.py which asserts the handler path."
        out = run(art, FACTS, CHANGED)   # CHANGED has no test file
        self.assertIn("unverified testing claim", out, out)

    def test_clean_artifact_no_warnings(self):
        art = "```mermaid\ngraph TD\n  api[src/api.py] --> db[src/db.py]\n```"
        out = run(art, FACTS, CHANGED)
        self.assertNotIn("warning:", out, out)


if __name__ == "__main__":
    unittest.main()
