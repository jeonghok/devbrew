"""Tests for the SessionStart advisor (read-only, self-session scope).

Status fixtures use the canonical vocabulary documented in
skills/quality-pipeline/references/state-file-format.md:
  gate1_running | gate2_running | gate3_running | completed | aborted
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parent.parent / "hooks" / "session-start-advisor.py"
SID = "advisorses12"
SID_OTHER = "othersess999"


def make_state(status: str, gate: int = 2, started_at: str = "2026-04-29T08:14:00Z") -> str:
    return (
        "---\n"
        f"status: {status}\n"
        f"current_gate: {gate}\n"
        "total_iterations: 1\n"
        f'started_at: "{started_at}"\n'
        "---\n"
        "# Quality Gates Pipeline State\n"
    )


def run_advisor(cwd, payload=None, env_extra=None):
    env = os.environ.copy()
    if env_extra:
        env.update(env_extra)
    proc = subprocess.run(
        [sys.executable, str(HOOK)],
        input=json.dumps(payload or {"session_id": SID}),
        capture_output=True,
        text=True,
        cwd=cwd,
        env=env,
    )
    return proc


def write_state(cwd, sid, status):
    folder = Path(cwd) / ".claude" / "quality-gates" / sid
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "pipeline.md").write_text(make_state(status))


class TestAdvisor(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

    def test_no_state_silent(self):
        proc = run_advisor(self.tmp)
        self.assertEqual(proc.returncode, 0)
        self.assertEqual(proc.stdout, "")

    def test_self_active_state_prints_one_liner(self):
        write_state(self.tmp, SID, "gate2_running")
        proc = run_advisor(self.tmp)
        self.assertEqual(proc.returncode, 0)
        self.assertIn("/qg", proc.stdout)
        self.assertIn("--reset", proc.stdout)

    def test_other_session_active_silent_by_default(self):
        write_state(self.tmp, SID_OTHER, "gate2_running")
        proc = run_advisor(self.tmp)
        self.assertEqual(proc.returncode, 0)
        self.assertEqual(proc.stdout, "", msg="must not advise about other sessions")

    def test_verbose_shows_sibling_count(self):
        write_state(self.tmp, SID_OTHER, "gate2_running")
        proc = run_advisor(self.tmp, env_extra={"DEVBREW_QG_GC_VERBOSE": "1"})
        self.assertEqual(proc.returncode, 0)
        self.assertIn("sibling", proc.stdout.lower())

    def test_self_terminal_state_silent(self):
        for status in ("completed", "aborted"):
            with self.subTest(status=status):
                write_state(self.tmp, SID, status)
                proc = run_advisor(self.tmp)
                self.assertEqual(proc.returncode, 0)
                self.assertEqual(proc.stdout, "", msg=f"output on terminal {status}")

    def test_does_not_mutate_files(self):
        write_state(self.tmp, SID, "gate2_running")
        write_state(self.tmp, SID_OTHER, "gate2_running")
        before = {
            p: p.read_text()
            for p in (Path(self.tmp) / ".claude/quality-gates").rglob("*.md")
        }
        run_advisor(self.tmp)
        after = {
            p: p.read_text()
            for p in (Path(self.tmp) / ".claude/quality-gates").rglob("*.md")
        }
        self.assertEqual(before, after, msg="advisor must NEVER mutate files")

    def test_kill_switch(self):
        write_state(self.tmp, SID, "gate2_running")
        proc = run_advisor(self.tmp, env_extra={"DEVBREW_DISABLE_QUALITY_GATES": "1"})
        self.assertEqual(proc.returncode, 0)
        self.assertEqual(proc.stdout, "")

    def test_legacy_flat_state_warns_via_systemmessage(self):
        legacy = Path(self.tmp) / ".claude" / "quality-gates.local.md"
        legacy.parent.mkdir(parents=True, exist_ok=True)
        legacy.write_text(make_state("gate2_running"))
        proc = run_advisor(self.tmp)
        self.assertEqual(proc.returncode, 0)
        self.assertIn("Legacy", proc.stdout)
        # MUST NOT delete (read-only)
        self.assertTrue(legacy.exists())

    def test_advisory_includes_gate_and_timestamp(self):
        write_state(self.tmp, SID, "gate2_running")
        proc = run_advisor(self.tmp)
        self.assertIn("Gate 2", proc.stdout)
        self.assertIn("2026-04-29T08:14:00Z", proc.stdout)

    def test_quoted_status_value_handled(self):
        folder = Path(self.tmp) / ".claude" / "quality-gates" / SID
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "pipeline.md").write_text(
            "---\nstatus: \"gate2_running\"\ncurrent_gate: 2\n---\n"
        )
        proc = run_advisor(self.tmp)
        self.assertIn("--reset", proc.stdout)


if __name__ == "__main__":
    unittest.main()
