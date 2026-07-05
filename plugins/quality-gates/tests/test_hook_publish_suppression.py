"""test_hook_publish_suppression.py — AC11: post-tool-use.py suppresses the /qg
re-suggestion when the publish sentinel is present. Run: python3 -m unittest."""
from __future__ import annotations
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
HOOK = PLUGIN_ROOT / "hooks" / "post-tool-use.py"
SID = "pubsuppress123"


def run_hook(cwd: str):
    payload = {
        "tool_name": "Bash",
        "session_id": SID,
        "cwd": cwd,
        "tool_input": {"command": "gh pr create --fill"},
        "tool_response": {"stdout": "https://github.com/o/r/pull/42"},
    }
    r = subprocess.run([sys.executable, str(HOOK)], input=json.dumps(payload),
                       capture_output=True, text=True)
    return json.loads(r.stdout or "{}")


class PublishSuppression(unittest.TestCase):
    def test_sentinel_suppresses_suggestion(self):
        with tempfile.TemporaryDirectory() as d:
            sent = Path(d) / ".claude" / "quality-gates" / SID
            sent.mkdir(parents=True)
            (sent / "publish-active.md").write_text("publishing", encoding="utf-8")
            self.assertEqual(run_hook(d), {}, "sentinel must suppress /qg suggestion")

    def test_no_sentinel_still_suggests(self):
        with tempfile.TemporaryDirectory() as d:
            out = run_hook(d)
            self.assertIn("systemMessage", out, "without sentinel the /qg suggestion should fire")


if __name__ == "__main__":
    unittest.main()
