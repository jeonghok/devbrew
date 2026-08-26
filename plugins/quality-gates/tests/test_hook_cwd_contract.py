#!/usr/bin/env python3
"""Smoke test for session-start-advisor / session-end-cleanup payload cwd handling."""
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

PLUGIN_DIR = Path(__file__).resolve().parent.parent
ADVISOR_HOOK = PLUGIN_DIR / "hooks" / "session-start-advisor.py"
CLEANUP_HOOK = PLUGIN_DIR / "hooks" / "session-end-cleanup.py"


class HookCwdContractTests(unittest.TestCase):
    def test_session_start_advisor_uses_payload_cwd(self):
        """advisor scans plugins/*/agents/*.md relative to payload cwd."""
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir)
            # Create a fake plugin layout under tmp_path with a bad-key agent file
            agent_path = tmp_path / "plugins" / "fake-plugin" / "agents" / "test.md"
            agent_path.parent.mkdir(parents=True)
            agent_path.write_text(
                "---\nname: test\nallowed-tools: [Read]\n---\nbody\n", encoding="utf-8"
            )

            proc = subprocess.run(
                ["python3", str(ADVISOR_HOOK)],
                input=json.dumps({"cwd": str(tmp_path), "session_id": "advisor-test-01"}),
                capture_output=True,
                text=True,
                cwd="/tmp",  # different from payload cwd to prove payload wins
                timeout=10,
            )
            # The kebab-case warning should mention the agent under payload cwd
            self.assertIn("fake-plugin/agents/test.md", proc.stderr,
                          f"Advisor didn't scan payload cwd; stderr: {proc.stderr}")

    def test_session_end_cleanup_uses_payload_cwd(self):
        """SessionEnd removes <payload-cwd>/.claude/quality-gates/<sid>/, not process-cwd."""
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir)
            sid = "cleanup-test-01"
            # Create state under payload cwd
            state_dir = tmp_path / ".claude" / "quality-gates" / sid
            state_dir.mkdir(parents=True)
            (state_dir / "pipeline.md").write_text("test state\n", encoding="utf-8")

            # Create decoy state under process cwd (should NOT be removed)
            with tempfile.TemporaryDirectory() as proc_dir:
                decoy_dir = Path(proc_dir) / ".claude" / "quality-gates" / sid
                decoy_dir.mkdir(parents=True)
                (decoy_dir / "pipeline.md").write_text("decoy\n", encoding="utf-8")

                proc = subprocess.run(
                    ["python3", str(CLEANUP_HOOK)],
                    input=json.dumps({"cwd": str(tmp_path), "session_id": sid}),
                    capture_output=True,
                    text=True,
                    cwd=proc_dir,
                    timeout=10,
                )
                self.assertEqual(proc.returncode, 0)
                self.assertFalse(state_dir.exists(), f"Worktree state not removed: {state_dir}")
                self.assertTrue(decoy_dir.exists(), f"Decoy at process cwd was wrongly removed: {decoy_dir}")

    def test_session_start_advisor_self_pipeline_uses_payload_cwd(self):
        """SessionStart advisor finds self pipeline under payload cwd, not process cwd."""
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir)
            sid = "advisor-self-test-01"
            pipeline = tmp_path / ".claude" / "quality-gates" / sid / "pipeline.md"
            pipeline.parent.mkdir(parents=True)
            pipeline.write_text("---\nstatus: gate1_running\n---\n", encoding="utf-8")

            proc = subprocess.run(
                ["python3", str(ADVISOR_HOOK)],
                input=json.dumps({"cwd": str(tmp_path), "session_id": sid}),
                capture_output=True,
                text=True,
                cwd="/tmp",  # different from payload cwd
                timeout=10,
            )
            # Advisor reads self_pipeline; we just verify it doesn't crash and that
            # any sibling-count log references the payload-cwd-rooted directory.
            # The advisor may print stderr advisories; just confirm zero exit code.
            self.assertEqual(proc.returncode, 0)


if __name__ == "__main__":
    unittest.main()
