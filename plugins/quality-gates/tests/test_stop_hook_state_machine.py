"""Tests for stop-hook state machine after cross-gate loop removal."""
import importlib.util
import sys
import unittest
from pathlib import Path

HOOK_PATH = Path(__file__).resolve().parent.parent / "hooks" / "stop-hook.py"
spec = importlib.util.spec_from_file_location("stop_hook", HOOK_PATH)
stop_hook = importlib.util.module_from_spec(spec)
sys.modules["stop_hook"] = stop_hook
spec.loader.exec_module(stop_hook)


class TestForwardOnlyStateMachine(unittest.TestCase):
    def test_no_max_total_iterations_constant(self):
        # The constant must be removed (it was stored in state, not as a module constant;
        # confirm no module-level MAX_TOTAL_ITERATIONS attribute exists)
        self.assertFalse(hasattr(stop_hook, "MAX_TOTAL_ITERATIONS"))

    def test_gate2_needs_restart_does_not_loop_to_gate1(self):
        state = {
            "current_gate": 2,
            "gate2_iteration": 1,
            "max_gate2_iterations": 5,
            "total_iterations": 1,
            "max_total_iterations": 5,
            "skip_runtime": False,
            "single_gate": None,
        }
        signal = {"gate": "2", "verdict": "NEEDS_RESTART", "summary": "fix needed"}
        transition = stop_hook.compute_transition(state, signal)
        # Forward-only contract: NEEDS_RESTART must NOT trigger fix-loop or restart;
        # it always escalates to user-choice with the canonical prompt key.
        self.assertEqual(transition["type"], "gate2_user_choice")
        self.assertEqual(transition["prompt_key"], "gate2_needs_restart")

    def test_gate3_needs_restart_terminates_with_user_choice(self):
        state = {
            "current_gate": 3,
            "total_iterations": 1,
            "max_total_iterations": 5,
            "gate2_iteration": 0,
            "max_gate2_iterations": 5,
            "skip_runtime": False,
            "single_gate": None,
        }
        signal = {"gate": "3", "verdict": "NEEDS_RESTART", "summary": "runtime fail"}
        transition = stop_hook.compute_transition(state, signal)
        self.assertEqual(transition["type"], "gate3_fail")
        # Forward-only: never returns "restart"
        self.assertNotEqual(transition["type"], "restart")

    def test_trivia_skipped_verdict_completes_pipeline(self):
        state = {
            "current_gate": 1,
            "total_iterations": 1,
            "max_total_iterations": 5,
            "gate2_iteration": 0,
            "max_gate2_iterations": 5,
            "skip_runtime": False,
            "single_gate": None,
        }
        signal = {"verdict": "trivia-skipped", "reason": "whitespace"}
        transition = stop_hook.compute_transition(state, signal)
        self.assertEqual(transition["type"], "complete")

    def test_scout_fallback_verdict_does_not_break(self):
        state = {
            "current_gate": 2,
            "gate2_iteration": 1,
            "max_gate2_iterations": 5,
            "total_iterations": 1,
            "max_total_iterations": 5,
            "skip_runtime": False,
            "single_gate": None,
        }
        signal = {"verdict": "scout-fallback", "reason": "json parse error"}
        transition = stop_hook.compute_transition(state, signal)
        # Pipeline continues; scout fallback is informational, not terminal
        self.assertIn(transition["type"], {"continue", "retry_gate", "next_gate"})

    def test_repeat_detected_triggers_user_choice(self):
        state = {
            "current_gate": 2,
            "gate2_iteration": 3,
            "max_gate2_iterations": 5,
            "total_iterations": 1,
            "max_total_iterations": 5,
            "skip_runtime": False,
            "single_gate": None,
        }
        signal = {"verdict": "repeat-detected"}
        transition = stop_hook.compute_transition(state, signal)
        self.assertEqual(transition["type"], "gate2_user_choice")


class TestGate3ResolutionState(unittest.TestCase):
    def test_gate3_resolution_iter_parsed_as_int(self):
        # parse_state_file이 새 필드를 int로 변환하는지 확인.
        import tempfile, textwrap
        content = textwrap.dedent("""\
            ---
            status: gate3_running
            current_gate: 3
            gate2_iteration: 0
            max_gate2_iterations: 5
            gate3_resolution_iter: 1
            max_gate3_resolutions: 3
            skip_runtime: false
            single_gate: null
            session_id: "abc12345"
            started_at: "2026-05-10T00:00:00Z"
            ---

            # Pipeline State
            """)
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as f:
            f.write(content)
            path = f.name
        state, _ = stop_hook.parse_state_file(path)
        self.assertEqual(state["gate3_resolution_iter"], 1)
        self.assertEqual(state["max_gate3_resolutions"], 3)
        self.assertIsInstance(state["gate3_resolution_iter"], int)
        self.assertIsInstance(state["max_gate3_resolutions"], int)

    def test_legacy_v17_state_file_parses_with_defaults(self):
        # Simulates a v1.7.0 state file that doesn't have the new gate3 fields.
        # parse_state_file must NOT return None,None — it must default the new
        # fields and emit a warning, allowing the pipeline to continue.
        import tempfile, textwrap
        content = textwrap.dedent("""\
            ---
            status: gate3_running
            current_gate: 3
            gate2_iteration: 0
            max_gate2_iterations: 5
            skip_runtime: false
            single_gate: null
            session_id: "abc12345"
            started_at: "2026-05-10T00:00:00Z"
            ---

            # Pipeline State
            """)
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as f:
            f.write(content)
            path = f.name
        state, body = stop_hook.parse_state_file(path)
        self.assertIsNotNone(state, "Legacy v1.7.0 state file must parse, not return None")
        self.assertEqual(state["gate3_resolution_iter"], 0)
        self.assertEqual(state["max_gate3_resolutions"], 3)
        self.assertEqual(state["last_gate3_needed_hash"], "")

    def _gate3_state(self, resolution_iter=0, max_resolutions=3):
        return {
            "current_gate": 3,
            "gate2_iteration": 5,
            "max_gate2_iterations": 5,
            "gate3_resolution_iter": resolution_iter,
            "max_gate3_resolutions": max_resolutions,
            "total_iterations": 1,
            "max_total_iterations": 5,
            "skip_runtime": False,
            "single_gate": None,
        }

    def test_gate3_needs_resolution_under_cap_returns_resolution_transition(self):
        state = self._gate3_state(resolution_iter=0)
        signal = {"gate": "3", "verdict": "NEEDS_RESOLUTION", "summary": "docker daemon down"}
        transition = stop_hook.compute_transition(state, signal)
        self.assertEqual(transition["type"], "gate3_needs_resolution")

    def test_gate3_needs_resolution_at_cap_escalates_to_fail(self):
        state = self._gate3_state(resolution_iter=3, max_resolutions=3)
        signal = {"gate": "3", "verdict": "NEEDS_RESOLUTION", "summary": "still missing"}
        transition = stop_hook.compute_transition(state, signal)
        self.assertEqual(transition["type"], "gate3_fail")

    def test_gate3_needs_resolution_with_max_zero_escalates_immediately(self):
        # DEVBREW_GATE3_MAX_RESOLUTIONS=0 (Approach 2 mode)
        state = self._gate3_state(resolution_iter=0, max_resolutions=0)
        signal = {"gate": "3", "verdict": "NEEDS_RESOLUTION", "summary": "no resolution allowed"}
        transition = stop_hook.compute_transition(state, signal)
        self.assertEqual(transition["type"], "gate3_fail")

    def test_gate3_skip_with_evidence_completes(self):
        state = self._gate3_state()
        signal = {"gate": "3", "verdict": "SKIP_WITH_EVIDENCE",
                  "summary": "no runnable surfaces detected"}
        transition = stop_hook.compute_transition(state, signal)
        self.assertEqual(transition["type"], "complete")

    def test_gate3_legacy_skip_still_completes(self):
        # Backward compat: bare SKIP verdict from older agents still completes.
        state = self._gate3_state()
        signal = {"gate": "3", "verdict": "SKIP", "summary": "user opted out"}
        transition = stop_hook.compute_transition(state, signal)
        self.assertEqual(transition["type"], "complete")

    def test_gate3_resolution_iter_increments_on_transition(self):
        # Round-trip through the real update_state_file: write a state file with
        # gate3_resolution_iter=0, invoke update_state_file with a
        # gate3_needs_resolution transition (signal carries a needed_hash),
        # re-parse, and assert BOTH the counter advanced AND the hash persisted.
        # Regression-catches removal of the increment block in update_state_file
        # AND removal of the last_gate3_needed_hash assignment (TA-1).
        import tempfile, textwrap
        content = textwrap.dedent("""\
            ---
            status: gate3_running
            current_gate: 3
            gate2_iteration: 0
            max_gate2_iterations: 5
            gate3_resolution_iter: 0
            last_gate3_needed_hash: ""
            max_gate3_resolutions: 3
            skip_runtime: false
            single_gate: null
            session_id: "abc12345"
            started_at: "2026-05-10T00:00:00Z"
            ---

            # Pipeline State

            ## Pipeline History
            """)
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as f:
            f.write(content)
            path = f.name
        state, _ = stop_hook.parse_state_file(path)
        self.assertEqual(state["gate3_resolution_iter"], 0)
        self.assertEqual(state["last_gate3_needed_hash"], "")
        hash_value = "deadbeef" * 8  # 64 hex chars, valid sha256 shape
        signal = {"gate": "3", "verdict": "NEEDS_RESOLUTION",
                  "summary": "docker daemon down", "needed_hash": hash_value}
        transition = {"type": "gate3_needs_resolution"}
        stop_hook.update_state_file(path, state, signal, transition)
        new_state, _ = stop_hook.parse_state_file(path)
        self.assertEqual(new_state["gate3_resolution_iter"], 1)
        # TA-1: hash must round-trip so subsequent iteration can detect repeat.
        self.assertEqual(new_state["last_gate3_needed_hash"], hash_value)
        # Verify the persisted hash actually drives repeat detection.
        repeat_signal = {"gate": "3", "verdict": "NEEDS_RESOLUTION",
                         "summary": "same problem", "needed_hash": hash_value}
        repeat_transition = stop_hook.compute_transition(new_state, repeat_signal)
        self.assertEqual(repeat_transition["type"], "gate3_repeat_detected")

    def test_gate3_unknown_verdict_warns_and_aborts(self):
        # TD-1: verdict outside GATE3_VERDICTS frozenset must surface a warning
        # and abort safely rather than silently falling through.
        state = self._gate3_state()
        signal = {"gate": "3", "verdict": "MAYBE_PASS", "summary": "typo"}
        transition = stop_hook.compute_transition(state, signal)
        self.assertEqual(transition["type"], "abort")

    def test_parse_state_file_clamps_max_gate3_resolutions(self):
        # TD-4: a manually-edited state file with max_gate3_resolutions out of
        # range must be clamped to MAX_GATE3_RESOLUTIONS_CAP at read time, not
        # only at write time in setup-qg.sh.
        import tempfile, textwrap
        content = textwrap.dedent("""\
            ---
            status: gate3_running
            current_gate: 3
            gate2_iteration: 0
            max_gate2_iterations: 5
            gate3_resolution_iter: 0
            max_gate3_resolutions: 9999
            last_gate3_needed_hash: ""
            skip_runtime: false
            single_gate: null
            session_id: "abc12345"
            started_at: "2026-05-10T00:00:00Z"
            ---

            # Pipeline State
            """)
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as f:
            f.write(content)
            path = f.name
        state, _ = stop_hook.parse_state_file(path)
        self.assertEqual(state["max_gate3_resolutions"],
                         stop_hook.MAX_GATE3_RESOLUTIONS_CAP)

    def test_gate3_needs_resolution_prompt_contains_user_choices(self):
        # State here represents post-increment state (update_state_file runs
        # before build_special_prompt in main()). resolution_iter=2 means
        # "this is the user's 2nd resolution attempt out of max 3".
        state = self._gate3_state(resolution_iter=2, max_resolutions=3)
        gate_results = "### Gate 3 (iter 2)\n**Summary:** docker daemon down\n"
        prompt = stop_hook.build_special_prompt(
            "gate3_needs_resolution", state, gate_results
        )
        self.assertIn("GATE3_NEEDS_RESOLUTION", prompt)
        self.assertIn("retry", prompt.lower())
        self.assertIn("skip", prompt.lower())
        self.assertIn("abort", prompt.lower())
        # iteration counter visible (post-increment): "2/3"
        self.assertIn("2/3", prompt)
        # P21 guard: prompt mentions decision-only contract
        self.assertIn("decision", prompt.lower())

    def test_gate3_repeat_detected_when_same_needed_twice(self):
        # When two consecutive NEEDS_RESOLUTION emit the SAME `needed_hash`,
        # transition must escalate to gate3_repeat_detected, not just increment.
        state = self._gate3_state(resolution_iter=1, max_resolutions=3)
        state["last_gate3_needed_hash"] = "abc123"
        signal = {"gate": "3", "verdict": "NEEDS_RESOLUTION",
                  "summary": "still down", "needed_hash": "abc123"}
        transition = stop_hook.compute_transition(state, signal)
        self.assertEqual(transition["type"], "gate3_repeat_detected")

    def test_gate3_different_needed_hash_continues_resolution(self):
        # Different needed_hash → progress is being made, continue.
        state = self._gate3_state(resolution_iter=1, max_resolutions=3)
        state["last_gate3_needed_hash"] = "abc123"
        signal = {"gate": "3", "verdict": "NEEDS_RESOLUTION",
                  "summary": "different problem", "needed_hash": "xyz789"}
        transition = stop_hook.compute_transition(state, signal)
        self.assertEqual(transition["type"], "gate3_needs_resolution")

    def test_gate3_repeat_detected_prompt(self):
        state = self._gate3_state(resolution_iter=2, max_resolutions=3)
        prompt = stop_hook.build_special_prompt(
            "gate3_repeat_detected", state, "context"
        )
        self.assertIn("GATE3_REPEAT_DETECTED", prompt)
        self.assertIn("PASS_WITH_WARNINGS", prompt)
        self.assertIn("abort", prompt.lower())


if __name__ == "__main__":
    unittest.main()
