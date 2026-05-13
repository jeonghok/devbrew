"""Unit tests for stop-hook.py build_special_prompt invariants.

These tests protect the Task 7 refactor (6-case → template + per-case dict).
They assert what every special prompt MUST contain so the refactor cannot
silently drop semantic content.

Locked by spec docs/superpowers/specs/2026-05-13-qg-forward-only-cleanup-and-stop-hook-trim-design.md AC14.
"""
import importlib.util
import sys
import unittest
from pathlib import Path

HOOK_PATH = Path(__file__).resolve().parent.parent / "hooks" / "stop-hook.py"
_spec = importlib.util.spec_from_file_location("stop_hook", HOOK_PATH)
stop_hook = importlib.util.module_from_spec(_spec)
sys.modules["stop_hook"] = stop_hook
_spec.loader.exec_module(stop_hook)


# Canonical (transition_type, prompt_key, expected_header_prefix) tuples.
# Header prefix is the exact case-tag the prompt MUST start with.
SPECIAL_CASES = [
    ("max_gate2_exceeded",        None,                       "GATE2_MAX_EXCEEDED\n\n"),
    ("gate3_needs_resolution",    None,                       "GATE3_NEEDS_RESOLUTION\n\n"),
    ("gate3_repeat_detected",     None,                       "GATE3_REPEAT_DETECTED\n\n"),
    ("gate3_fail",                None,                       "GATE3_FAIL\n\n"),
    ("gate2_user_choice",         "gate2_needs_restart",      "GATE2_NEEDS_RESTART\n\n"),
    ("gate2_user_choice",         "gate2_repeat_detected",    "GATE2_REPEAT_DETECTED\n\n"),
    ("gate2_user_choice",         None,                       "GATE2_USER_CHOICE\n\n"),  # generic fallback
]


def _state_stub():
    return {
        "max_gate2_iterations": 5,
        "gate3_resolution_iter": 0,
        "max_gate3_resolutions": 3,
        "current_gate": 2,
        "gate2_iteration": 1,
    }


class TestBuildSpecialPrompt(unittest.TestCase):
    def test_each_case_has_correct_header_prefix(self):
        state = _state_stub()
        for t_type, prompt_key, header in SPECIAL_CASES:
            with self.subTest(t_type=t_type, prompt_key=prompt_key):
                out = stop_hook.build_special_prompt(
                    t_type, state, "## Gate Results\nbaseline\n",
                    prompt_key=prompt_key,
                )
                self.assertTrue(
                    out.startswith(header),
                    msg=f"{t_type}/{prompt_key}: missing header {header!r}, got {out[:80]!r}",
                )

    def test_each_case_is_substantial(self):
        # All special prompts must be substantial (>200 chars) — they carry
        # option descriptions, signal mapping, and pipeline context.
        state = _state_stub()
        for t_type, prompt_key, _ in SPECIAL_CASES:
            with self.subTest(t_type=t_type, prompt_key=prompt_key):
                out = stop_hook.build_special_prompt(
                    t_type, state, "## Gate Results\nbaseline\n",
                    prompt_key=prompt_key,
                )
                self.assertGreater(len(out), 200, msg=f"{t_type}/{prompt_key}: too short")

    def test_each_case_contains_qg_signal_mapping_twice(self):
        # Every special prompt MUST tell the model how to emit signals — at
        # least two distinct <qg-signal directives (proceed/skip/abort).
        state = _state_stub()
        for t_type, prompt_key, _ in SPECIAL_CASES:
            with self.subTest(t_type=t_type, prompt_key=prompt_key):
                out = stop_hook.build_special_prompt(
                    t_type, state, "## Gate Results\nbaseline\n",
                    prompt_key=prompt_key,
                )
                self.assertGreaterEqual(
                    out.count("<qg-signal"), 2,
                    msg=f"{t_type}/{prompt_key}: needs >=2 <qg-signal lines",
                )

    def test_each_case_contains_abort_option(self):
        state = _state_stub()
        for t_type, prompt_key, _ in SPECIAL_CASES:
            with self.subTest(t_type=t_type, prompt_key=prompt_key):
                out = stop_hook.build_special_prompt(
                    t_type, state, "## Gate Results\nbaseline\n",
                    prompt_key=prompt_key,
                )
                self.assertIn("abort", out.lower(),
                              msg=f"{t_type}/{prompt_key}: needs abort option")

    def test_unknown_transition_returns_pipeline_error(self):
        # AC14: exact prefix, not just "non-empty" (a future refactor that
        # returns "" would otherwise pass).
        state = _state_stub()
        out = stop_hook.build_special_prompt(
            "no_such_transition", state, "", prompt_key=None,
        )
        self.assertTrue(out.startswith("PIPELINE_ERROR\n\n"),
                        msg=f"unknown transition: got {out[:80]!r}")


if __name__ == "__main__":
    unittest.main()
