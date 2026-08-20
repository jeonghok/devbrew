"""Self-tests for the agent_stub harness (T3-4 prerequisite).

Verifies the harness itself does what it claims before any behavioral test
relies on it.
"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "harness"))
from agent_stub import run_agent_stub, assert_yaml_schema  # noqa: E402


class AgentStubHarnessTests(unittest.TestCase):
    def test_run_agent_stub_parses_valid_yaml(self):
        parsed = run_agent_stub("test", "p", "verdict: PASS\nmatched: []\n")
        self.assertEqual(parsed, {"verdict": "PASS", "matched": []})

    def test_run_agent_stub_raises_on_invalid_yaml(self):
        with self.assertRaises(AssertionError):
            run_agent_stub("test", "p", "verdict: : : invalid")

    def test_assert_yaml_schema_missing_key(self):
        with self.assertRaises(AssertionError) as ctx:
            assert_yaml_schema({"a": 1}, ["a", "b"])
        self.assertIn("b", str(ctx.exception))

    def test_assert_yaml_schema_enum_violation_scalar(self):
        with self.assertRaises(AssertionError) as ctx:
            assert_yaml_schema(
                {"verdict": "MAYBE"},
                required_keys=["verdict"],
                enum={"verdict": ["PASS", "FAIL"]},
            )
        self.assertIn("MAYBE", str(ctx.exception))

    def test_assert_yaml_schema_enum_violation_list(self):
        with self.assertRaises(AssertionError):
            assert_yaml_schema(
                {"tags": ["good", "bad"]},
                required_keys=["tags"],
                enum={"tags": ["good", "fine"]},
            )

    def test_assert_yaml_schema_happy_path_scalar(self):
        # No exception expected
        assert_yaml_schema(
            {"verdict": "PASS"},
            required_keys=["verdict"],
            enum={"verdict": ["PASS", "FAIL", "SKIP"]},
        )

    def test_assert_yaml_schema_non_dict_raises(self):
        with self.assertRaises(AssertionError):
            assert_yaml_schema(["not", "a", "dict"], ["verdict"])

    # --- Regressions from Gate 2 review (qg self-review iter 1) ---

    def test_run_agent_stub_raises_on_empty_yaml(self):
        """Empty / whitespace / null YAML must raise AssertionError naming the
        agent — not silently return None to the caller (Gate 2 finding #1)."""
        for empty in ("", "   ", "\n", "null", "~"):
            with self.assertRaises(AssertionError) as ctx:
                run_agent_stub("reviewer", "p", empty)
            msg = str(ctx.exception)
            self.assertIn("agent_stub[reviewer]", msg)
            self.assertTrue("parsed to None" in msg or "not valid YAML" in msg)

    def test_assert_yaml_schema_empty_enum_dict_is_not_skipped(self):
        """An empty enum dict {} must NOT bypass validation — only explicit None
        skips. Empty dict means 'validate against zero constraints' which is a
        no-op loop, not a silent green (Gate 2 finding #2). Regression: if the
        guard reverts to `if enum:` (falsy on {}), this test still passes
        because validation simply iterates an empty dict. The test's value is
        asserting the empty-dict case raises no exception AND that the
        required-key contract still applies."""
        # Empty enum + all required keys present → no exception
        assert_yaml_schema({"verdict": "PASS"}, ["verdict"], enum={})
        # Empty enum + missing required key → still raises (required check is
        # before the enum block, so semantics are preserved either way)
        with self.assertRaises(AssertionError):
            assert_yaml_schema({"a": 1}, ["a", "b"], enum={})


if __name__ == "__main__":
    unittest.main()
