"""test_publish_kill_switch.py — AC10: DEVBREW_QG_DISABLE_PUBLISH suppresses the
network mutation at the innermost sink while still computing the decision.
Run: python3 -m unittest (from repo root)."""
from __future__ import annotations
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
SCRIPT = PLUGIN_ROOT / "scripts" / "comment-upsert.py"
MARKER = "<!-- pr-understanding:v1 -->"


class KillSwitch(unittest.TestCase):
    def test_disabled_suppresses_network_but_decides(self):
        with tempfile.TemporaryDirectory() as d:
            gh = Path(d) / "gh"
            gh.write_text("#!/usr/bin/env bash\necho called >> "
                          + str(Path(d) / "log") + "\n", encoding="utf-8")
            gh.chmod(0o755)
            body = Path(d) / "body"; body.write_text(MARKER + "\nx", encoding="utf-8")
            cj = Path(d) / "c.json"; cj.write_text(json.dumps([]), encoding="utf-8")
            env = dict(os.environ, PATH=f"{d}:{os.environ['PATH']}",
                       DEVBREW_QG_DISABLE_PUBLISH="1")
            r = subprocess.run(
                [sys.executable, str(SCRIPT), "--pr", "1", "--marker", MARKER,
                 "--body-file", str(body), "--my-id", "5", "--repo", "o/r",
                 "--comments-json", str(cj)],
                capture_output=True, text=True, env=env)
            self.assertIn("action: post", r.stdout)               # decision computed
            self.assertIn("network suppressed", r.stdout)         # but no mutation
            self.assertFalse((Path(d) / "log").exists(), "gh was called despite kill switch")


if __name__ == "__main__":
    unittest.main()
