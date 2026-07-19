import json, subprocess, sys, tempfile, unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "parse-seed.py"

SEED = """---
target: quality-gates
---
## 추가 scope
- docs/qg-notes.md
- .claude-plugin/marketplace.json

## Open Questions
- OQ1: 축3 — runtime gate가 PreToolUse로 승격돼야 하나?

## 후보 단서
- D1 (축1): README가 없는 기능을 광고 — plugins/quality-gates/README.md:12
"""


def run(path):
    r = subprocess.run([sys.executable, str(SCRIPT), str(path)],
                       capture_output=True, text=True)
    return r


class TestParseSeed(unittest.TestCase):
    def test_extracts_all_sections(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "seed.md"
            p.write_text(SEED, encoding="utf-8")
            r = run(p)
            self.assertEqual(r.returncode, 0)
            obj = json.loads(r.stdout)
            self.assertEqual(obj["target"], "quality-gates")
            self.assertIn("docs/qg-notes.md", obj["extra_scope"])
            self.assertEqual(obj["open_questions"][0]["id"], "OQ1")
            self.assertEqual(obj["open_questions"][0]["axis"], 3)
            c = obj["candidate_clues"][0]
            self.assertEqual((c["id"], c["axis"], c["file"], c["line"]),
                             ("D1", 1, "plugins/quality-gates/README.md", 12))

    def test_missing_file_is_empty_not_crash(self):
        r = run(Path("/nonexistent/seed.md"))
        self.assertEqual(r.returncode, 0)
        self.assertEqual(json.loads(r.stdout), {})
        self.assertIn("seed", r.stderr.lower())


if __name__ == "__main__":
    unittest.main()
