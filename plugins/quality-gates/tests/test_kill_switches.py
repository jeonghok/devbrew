"""Regression tests: every hook honors devbrew kill switches.

Per CLAUDE.md ("kill switch는 보안 컨트롤"), every hook must check both
DEVBREW_QUALITY_GATES_DISABLE=1 (global) and DEVBREW_SKIP_HOOKS=quality-gates:<key>
(per-hook). This test guards against the v1.6.1/v1.6.2 regression pattern
where new hooks shipped without the env var checks, contradicting the README's
"All hooks honor..." promise.

Strategy per hook:
  1. setup() pre-creates state that — without a kill switch — would cause the
     hook to produce a detectable side effect (state mutation, stdout, file
     creation, folder deletion).
  2. run hook with the relevant env var set.
  3. assert the side effect did NOT happen.

A hook that ignores the env var is detected by the side effect appearing
despite the kill switch — the test fails loudly.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
HOOKS = PLUGIN_ROOT / "hooks"

# Each hook contract: (script, per-hook skip key).
# The skip key is the suffix used in DEVBREW_SKIP_HOOKS=quality-gates:<key>.
HOOK_CONTRACTS = [
    ("post-tool-use.py", "post-tool-use"),
    ("session-start-advisor.py", "session-start-advisor"),
    ("session-end-cleanup.py", "session-end-cleanup"),
]

SID = "killswitch12345"

PIPELINE_RUNNING = (
    "---\n"
    "status: gate1_running\n"
    "current_gate: 1\n"
    'started_at: "2026-05-10T00:00:00Z"\n'
    "---\n"
    "# Quality Gates Pipeline State\n"
)


def _qg_dir(cwd: str) -> Path:
    return Path(cwd) / ".claude" / "quality-gates" / SID


def _payload_for(script: str) -> dict:
    """Payload that — without a kill switch — would cause the hook to act."""
    if script == "post-tool-use.py":
        return {
            "session_id": SID,
            "tool_name": "Bash",
            "tool_input": {"command": "gh pr create --title x --body y"},
            "tool_response": {"stdout": "https://github.com/owner/repo/pull/42\n"},
            "cwd": "",  # filled in per test
        }
    return {"session_id": SID}


def _setup_state(cwd: str, script: str) -> None:
    """Pre-create state so the hook would normally do work."""
    qg = _qg_dir(cwd)
    if script == "session-start-advisor.py":
        qg.mkdir(parents=True, exist_ok=True)
        (qg / "pipeline.md").write_text(PIPELINE_RUNNING)
    elif script == "session-end-cleanup.py":
        qg.mkdir(parents=True, exist_ok=True)
        (qg / "marker.txt").write_text("present-before-hook\n")


def _run_hook(script: str, payload: dict, env_extra: dict, cwd: str) -> subprocess.CompletedProcess:
    env = os.environ.copy()
    # Drop any kill switch the test runner inherited so we control the var precisely.
    env.pop("DEVBREW_QUALITY_GATES_DISABLE", None)
    env.pop("DEVBREW_SKIP_HOOKS", None)
    env.update(env_extra)
    if "cwd" in payload:
        payload = {**payload, "cwd": cwd}
    return subprocess.run(
        [sys.executable, str(HOOKS / script)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        cwd=cwd,
        env=env,
        timeout=15,
    )


def _assert_no_side_effect(test: unittest.TestCase, script: str, cwd: str,
                           proc: subprocess.CompletedProcess, label: str) -> None:
    """Hook-specific check that the kill switch actually suppressed work."""
    test.assertEqual(
        proc.returncode, 0,
        f"{label}: hook exited {proc.returncode}; stderr={proc.stderr!r}",
    )

    qg = _qg_dir(cwd)

    if script == "post-tool-use.py":
        # Must not emit a systemMessage trigger.
        out = proc.stdout.strip()
        if out:
            try:
                parsed = json.loads(out)
            except json.JSONDecodeError:
                test.fail(f"{label}: post-tool-use produced non-JSON stdout: {out!r}")
            test.assertNotIn(
                "systemMessage", parsed,
                f"{label}: post-tool-use injected systemMessage despite kill switch",
            )

    elif script == "session-start-advisor.py":
        # Advisor produces stdout when in-flight state is present.
        test.assertEqual(
            proc.stdout.strip(), "",
            f"{label}: advisor produced output despite kill switch: {proc.stdout!r}",
        )
        # And must not delete or rewrite the state.
        contents = (qg / "pipeline.md").read_text()
        test.assertEqual(contents, PIPELINE_RUNNING, f"{label}: advisor touched state")

    elif script == "session-end-cleanup.py":
        test.assertTrue(
            qg.exists() and (qg / "marker.txt").exists(),
            f"{label}: session-end-cleanup removed folder despite kill switch",
        )

    else:
        test.fail(f"{label}: no side-effect assertion defined for {script}")


class KillSwitchRegressionTest(unittest.TestCase):
    """Most tests below iterate HOOK_CONTRACTS via subTest; a few target one hook directly."""

    def setUp(self) -> None:
        self.tmp = tempfile.mkdtemp(prefix="qg-killswitch-")
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

    def test_global_disable_silences_every_hook(self) -> None:
        """DEVBREW_QUALITY_GATES_DISABLE=1 must suppress every hook."""
        for script, _ in HOOK_CONTRACTS:
            with self.subTest(hook=script):
                _setup_state(self.tmp, script)
                proc = _run_hook(
                    script, _payload_for(script),
                    {"DEVBREW_QUALITY_GATES_DISABLE": "1"}, self.tmp,
                )
                _assert_no_side_effect(self, script, self.tmp, proc, f"global / {script}")

    def test_per_hook_skip_silences_targeted_hook(self) -> None:
        """DEVBREW_SKIP_HOOKS=quality-gates:<key> must suppress that one hook."""
        for script, key in HOOK_CONTRACTS:
            with self.subTest(hook=script, key=key):
                _setup_state(self.tmp, script)
                proc = _run_hook(
                    script, _payload_for(script),
                    {"DEVBREW_SKIP_HOOKS": f"quality-gates:{key}"}, self.tmp,
                )
                _assert_no_side_effect(
                    self, script, self.tmp, proc, f"per-hook / {script}",
                )

    def test_per_hook_skip_in_csv_list(self) -> None:
        """SKIP_HOOKS whole-token match must work when the key is one of many."""
        for script, key in HOOK_CONTRACTS:
            with self.subTest(hook=script, key=key):
                _setup_state(self.tmp, script)
                csv = f"other-plugin:foo,quality-gates:{key},another:bar"
                proc = _run_hook(
                    script, _payload_for(script),
                    {"DEVBREW_SKIP_HOOKS": csv}, self.tmp,
                )
                _assert_no_side_effect(
                    self, script, self.tmp, proc, f"csv / {script}",
                )

    def test_per_hook_skip_does_not_cross_contaminate(self) -> None:
        """A longer key must NOT silence a hook whose key is its prefix.

        Previously: `'quality-gates:post-tool-use' in 'quality-gates:post-tool-use-session-tracker'`
        was True (substring match), so a user setting the longer key by mistake
        (e.g. typing the script filename) would silently disable post-tool-use.py.
        Whole-token match closes this hole.
        """
        # Setup post-tool-use state. Apply SKIP_HOOKS naming the LONGER key.
        # post-tool-use.py must still emit systemMessage (NOT silenced).
        _setup_state(self.tmp, "post-tool-use.py")
        proc = _run_hook(
            "post-tool-use.py",
            _payload_for("post-tool-use.py"),
            {"DEVBREW_SKIP_HOOKS": "quality-gates:post-tool-use-session-tracker"},
            self.tmp,
        )
        self.assertIn(
            "systemMessage", proc.stdout,
            "post-tool-use was accidentally silenced by a key whose prefix matches it",
        )

    def test_skill_setup_qg_honors_disable_kill_switch(self) -> None:
        """setup-qg.sh must short-circuit when DEVBREW_QUALITY_GATES_DISABLE=1.

        SKILL preflight P1 already checks this upstream, but defense in depth:
        the script itself must reject invocation so direct callers (tests,
        scripts, ad-hoc shell) cannot accidentally bypass the kill switch.
        """
        script = PLUGIN_ROOT / "scripts" / "setup-qg.sh"
        env = os.environ.copy()
        env["DEVBREW_QUALITY_GATES_DISABLE"] = "1"
        env["CLAUDE_CODE_SESSION_ID"] = "killswitch-skill-test1"
        result = subprocess.run(
            ["bash", str(script), "--ensure"],
            env=env,
            capture_output=True,
            text=True,
            timeout=10,
            cwd=self.tmp,
        )
        self.assertNotEqual(
            result.returncode, 0,
            "DEVBREW_QUALITY_GATES_DISABLE=1 must cause setup-qg to exit non-zero "
            f"(stdout={result.stdout!r}, stderr={result.stderr!r})",
        )
        self.assertRegex(
            result.stderr,
            r"DEVBREW_QUALITY_GATES_DISABLE|disabled",
            "kill-switch error message must reference DEVBREW_QUALITY_GATES_DISABLE or 'disabled'",
        )
        # And no state file should have been created.
        state = Path(self.tmp) / ".claude" / "quality-gates" / "killswitch-skill-test1" / "pipeline.md"
        self.assertFalse(
            state.exists(),
            f"setup-qg should not create state under kill switch; found {state}",
        )

    def test_all_hooks_declare_kill_switch_strings(self) -> None:
        """Every *.py file in hooks/ must mention both kill-switch env var names.

        Source-text static check that catches the v1.6.1/v1.6.2 regression
        pattern at merge time: a developer adding a new hook script without
        the env var checks fails this test even if they forget to update
        HOOK_CONTRACTS. This is the regression net the docstring promises.
        """
        for hook_file in sorted(HOOKS.glob("*.py")):
            with self.subTest(hook=hook_file.name):
                src = hook_file.read_text(encoding="utf-8")
                self.assertIn(
                    "DEVBREW_QUALITY_GATES_DISABLE", src,
                    f"{hook_file.name} missing global kill switch env var",
                )
                self.assertIn(
                    "DEVBREW_SKIP_HOOKS", src,
                    f"{hook_file.name} missing per-hook kill switch env var",
                )

    def test_setup_actually_triggers_work_without_kill_switch(self) -> None:
        """Sanity: confirm each hook's setup would produce a detectable side effect.

        This guards against the test passing trivially when the setup is wrong
        (e.g., hook would no-op even without a kill switch). If this test fails,
        the kill-switch tests above are unreliable.
        """
        for script, _ in HOOK_CONTRACTS:
            with self.subTest(hook=script):
                _setup_state(self.tmp, script)
                proc = _run_hook(script, _payload_for(script), {}, self.tmp)
                self.assertEqual(
                    proc.returncode, 0,
                    f"sanity / {script}: hook crashed with stderr={proc.stderr!r}",
                )
                self._assert_side_effect_happened(script, self.tmp, proc)
                # Reset state for next iteration.
                shutil.rmtree(_qg_dir(self.tmp).parent, ignore_errors=True)

    def _assert_side_effect_happened(self, script: str, cwd: str,
                                     proc: subprocess.CompletedProcess) -> None:
        qg = _qg_dir(cwd)
        if script == "post-tool-use.py":
            self.assertIn(
                "systemMessage", proc.stdout,
                "post-tool-use sanity: should emit systemMessage on `gh pr create`",
            )
        elif script == "session-start-advisor.py":
            self.assertNotEqual(
                proc.stderr.strip(), "",
                "advisor sanity: should produce stderr advisory for legacy state "
                "(v1.32.0 advisor writes to stderr, not stdout)",
            )
        elif script == "session-end-cleanup.py":
            self.assertFalse(
                qg.exists(),
                "session-end-cleanup sanity: should remove folder",
            )


if __name__ == "__main__":
    unittest.main()
