#!/usr/bin/env python3
"""Smoke test for post-tool-use-session-tracker payload cwd handling."""
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

PLUGIN_DIR = Path(__file__).resolve().parent.parent
HOOK = PLUGIN_DIR / "hooks" / "post-tool-use-session-tracker.py"


def run_hook(payload: dict, process_cwd: str) -> int:
    proc = subprocess.run(
        ["python3", str(HOOK)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        cwd=process_cwd,
        timeout=10,
    )
    return proc.returncode


def test_state_file_under_payload_cwd():
    """State write goes under payload cwd, not process cwd."""
    with tempfile.TemporaryDirectory() as wt_dir, tempfile.TemporaryDirectory() as proc_dir:
        sid = "tracker-test-01"
        payload = {
            "cwd": wt_dir,
            "session_id": sid,
            "tool_name": "Edit",
            "tool_input": {"file_path": "/some/absolute/foo.py"},
        }
        rc = run_hook(payload, proc_dir)
        assert rc == 0
        state_file = Path(wt_dir) / ".claude" / "quality-gates" / sid / "files.md"
        assert state_file.exists(), f"State not written under payload cwd: {state_file}"
        proc_state = Path(proc_dir) / ".claude" / "quality-gates" / sid / "files.md"
        assert not proc_state.exists(), f"Process-cwd leakage: {proc_state}"


def test_relative_file_path_resolves_against_payload_cwd():
    """Relative file_path resolves against payload cwd, not process cwd."""
    with tempfile.TemporaryDirectory() as wt_dir, tempfile.TemporaryDirectory() as proc_dir:
        sid = "tracker-test-02"
        # Write a file inside wt_dir so resolve doesn't go to /
        (Path(wt_dir) / "subdir").mkdir()
        (Path(wt_dir) / "subdir" / "rel.py").write_text("x = 1")
        payload = {
            "cwd": wt_dir,
            "session_id": sid,
            "tool_name": "Edit",
            "tool_input": {"file_path": "subdir/rel.py"},
        }
        rc = run_hook(payload, proc_dir)
        assert rc == 0
        state_file = Path(wt_dir) / ".claude" / "quality-gates" / sid / "files.md"
        content = state_file.read_text()
        expected_abs = str(Path(wt_dir) / "subdir" / "rel.py")
        # On macOS, /var ↔ /private/var symlink may differ; use resolve to compare
        assert str(Path(expected_abs).resolve()) in content, \
            f"Expected resolved {expected_abs} in state; got:\n{content}"


ADVISOR_HOOK = PLUGIN_DIR / "hooks" / "session-start-advisor.py"


def test_session_start_advisor_uses_payload_cwd(tmp_path):
    """advisor scans plugins/*/agents/*.md relative to payload cwd."""
    # Create a fake plugin layout under tmp_path with a bad-key agent file
    agent_path = tmp_path / "plugins" / "fake-plugin" / "agents" / "test.md"
    agent_path.parent.mkdir(parents=True)
    agent_path.write_text(
        "---\nname: test\nallowed-tools: [Read]\n---\nbody\n"
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
    assert "fake-plugin/agents/test.md" in proc.stderr, \
        f"Advisor didn't scan payload cwd; stderr: {proc.stderr}"


# Note: test_session_start_advisor_uses_payload_cwd uses pytest's tmp_path fixture
# and is intentionally NOT included in the __main__ block below.
# Run via: python3 -m pytest plugins/quality-gates/tests/test_hook_cwd_contract.py
if __name__ == "__main__":
    test_state_file_under_payload_cwd()
    test_relative_file_path_resolves_against_payload_cwd()
    print("PASS: 2 tests")
