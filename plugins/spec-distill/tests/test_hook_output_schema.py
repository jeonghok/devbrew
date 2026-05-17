#!/usr/bin/env python3
"""AC12 — Hook output schema 통합 회귀 방지 test (v0.5.0).

Covers AC1–AC5 (5 hook output schemas), AC1a (encoding round-trip),
AC7.1/7.2/7.3 (Stop hook ordering + rewrite-fail behavior + ordering
verification 3-prong), AC10/AC11 (kill switches), NG9 (cross-resolver
advisory).

Run:
    python3 -m unittest plugins/spec-distill/tests/test_hook_output_schema.py
"""
from __future__ import annotations

import ast
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path
from unittest import mock

REPO_ROOT = Path(__file__).resolve().parents[3]
HOOKS_DIR = REPO_ROOT / "plugins" / "spec-distill" / "hooks"


def _make_temp_repo() -> Path:
    """Create a temp dir initialised as a git repo (state_path needs git)."""
    tmp = Path(tempfile.mkdtemp(prefix="specdistill-schema-"))
    subprocess.run(["git", "init", "-q"], cwd=tmp, check=True)
    subprocess.run(["git", "config", "user.email", "t@t.t"], cwd=tmp, check=True)
    subprocess.run(["git", "config", "user.name", "t"], cwd=tmp, check=True)
    subprocess.run(
        ["git", "commit", "-q", "--allow-empty", "-m", "seed"],
        cwd=tmp, check=True,
    )
    return tmp


def _write_pending_review_state(
    repo: Path, session_id: str, *, spec_path: str = "/tmp/x-spec.md",
    mode: str = "spec", worktree_path: str | None = None,
    triggered_at: str = "2026-05-17T00:00:00Z",
    last_dispatched_at: str | None = None,
) -> Path:
    """Write a state.local.md with a pending_review block."""
    state_dir = repo / ".claude" / "spec-distill" / session_id
    state_dir.mkdir(parents=True, exist_ok=True)
    state_file = state_dir / "state.local.md"
    block = (
        f"pending_review:\n"
        f"  path: {spec_path}\n"
        f"  mode: {mode}\n"
    )
    if worktree_path:
        block += f"  worktree_path: {worktree_path}\n"
    block += f"  triggered_at: {triggered_at}\n"
    tail = ""
    if last_dispatched_at:
        tail = f"\nlast_dispatched_at: {last_dispatched_at}\n"
    state_file.write_text(
        f"---\nsession_id: {session_id}\n---\n\n{block}{tail}",
        encoding="utf-8",
    )
    return state_file


def _run_hook(
    hook_relpath: str, *,
    cwd: Path, env_extra: dict[str, str] | None = None,
    stdin_payload: dict | None = None,
    binary: str = "python3",
) -> subprocess.CompletedProcess:
    """Run a hook with isolated env. cwd=temp repo redirects state_root()."""
    env = {"HOME": os.environ.get("HOME", "/tmp"), "PATH": os.environ["PATH"]}
    if env_extra:
        env.update(env_extra)
    hook_path = HOOKS_DIR / hook_relpath
    stdin_str = json.dumps(stdin_payload or {})
    return subprocess.run(
        [binary, str(hook_path)],
        cwd=cwd, env=env, input=stdin_str, text=True,
        capture_output=True, timeout=15,
    )


class HookOutputSchemaTestBase(unittest.TestCase):
    """Base class with shared fixture lifecycle."""

    def setUp(self):
        self.repo = _make_temp_repo()

    def tearDown(self):
        shutil.rmtree(self.repo, ignore_errors=True)


class TestReviewDispatchSchema(HookOutputSchemaTestBase):
    """AC1 — review-dispatch.py (Stop hook) output schema."""

    def test_pending_review_emits_decision_block_with_reason(self):
        session_id = "test-stop-happy"
        _write_pending_review_state(
            self.repo, session_id,
            spec_path="/tmp/some-spec.md", mode="spec",
            worktree_path="/Users/foo/wt",
        )
        result = _run_hook(
            "review-dispatch.py",
            cwd=self.repo,
            env_extra={"DEVBREW_SPEC_DISTILL_SESSION_ID": session_id},
        )
        self.assertEqual(result.returncode, 0, msg=f"stderr: {result.stderr}")
        self.assertTrue(result.stdout.strip(), msg="stdout empty")
        payload = json.loads(result.stdout)
        self.assertEqual(payload.get("decision"), "block")
        reason = payload.get("reason", "")
        self.assertIn("MANDATORY", reason)
        self.assertIn("spec path:", reason)
        self.assertIn("mode:", reason)
        self.assertIn("worktree_path:", reason)
        sysmsg = payload.get("systemMessage", "")
        self.assertTrue(sysmsg, msg="systemMessage missing")
        self.assertLessEqual(len(sysmsg), 120, msg=f"systemMessage too long: {len(sysmsg)}")
        self.assertTrue(sysmsg.startswith("[spec-distill]"))

    def test_reason_encoding_safe_with_special_chars(self):
        """AC1a — special chars in spec path must round-trip via json.loads."""
        session_id = "test-stop-encoding"
        special_path = "/tmp/spec dir/with $special `chars`.md"
        _write_pending_review_state(
            self.repo, session_id,
            spec_path=special_path, mode="design",
            worktree_path="/tmp/wt with space",
        )
        result = _run_hook(
            "review-dispatch.py",
            cwd=self.repo,
            env_extra={"DEVBREW_SPEC_DISTILL_SESSION_ID": session_id},
        )
        self.assertEqual(result.returncode, 0)
        payload = json.loads(result.stdout)  # ← round-trip via stdlib json
        self.assertIn(special_path, payload["reason"])
        self.assertIn("/tmp/wt with space", payload["reason"])

    def test_rewrite_failure_suppresses_emit(self):
        """AC7.2 — if rewrite_state raises OSError, hook must NOT emit decision:block."""
        session_id = "test-stop-rewrite-fail"
        state_file = _write_pending_review_state(
            self.repo, session_id, spec_path="/tmp/x-spec.md", mode="spec",
        )
        # Make state file read-only to force rewrite_state OSError on open(w).
        # File-level chmod is required: parent-dir chmod doesn't block writes
        # to existing owned files. Also chmod the parent so any fallback
        # create/rename also fails.
        parent = state_file.parent
        original_file_mode = state_file.stat().st_mode
        original_parent_mode = parent.stat().st_mode
        try:
            os.chmod(state_file, 0o444)  # r--r--r--
            os.chmod(parent, 0o555)  # r-xr-xr-x
            result = _run_hook(
                "review-dispatch.py",
                cwd=self.repo,
                env_extra={"DEVBREW_SPEC_DISTILL_SESSION_ID": session_id},
            )
        finally:
            os.chmod(parent, original_parent_mode)
            os.chmod(state_file, original_file_mode)
        self.assertEqual(result.returncode, 0)
        # stdout must be empty or {} — NOT decision:block
        stripped = result.stdout.strip()
        if stripped:
            payload = json.loads(stripped)
            self.assertNotEqual(
                payload.get("decision"), "block",
                msg=f"AC7.2 violated: emitted decision:block despite rewrite failure: {stripped}",
            )
        # stderr should contain the loud log
        self.assertIn("state rewrite failed", result.stderr)
        self.assertIn("dispatch suppressed", result.stderr)


class TestReviewDispatchOrdering(unittest.TestCase):
    """AC7.3 — verify rewrite_state runs BEFORE print(json.dumps(...))."""

    def _walk_calls_in_order(self, body_nodes, target_names):
        """Yield (lineno, name) for Call nodes whose func.id is in target_names.

        Recurses into FunctionDef body if encountered (handles helper refactor
        per AC7.3.1 commentary)."""
        for node in body_nodes:
            if isinstance(node, ast.Expr) and isinstance(node.value, ast.Call):
                call = node.value
                name = None
                if isinstance(call.func, ast.Name):
                    name = call.func.id
                elif isinstance(call.func, ast.Attribute):
                    name = call.func.attr
                if name in target_names:
                    yield (node.lineno, name)
            if isinstance(node, ast.With):
                yield from self._walk_calls_in_order(node.body, target_names)
            if isinstance(node, ast.Try):
                yield from self._walk_calls_in_order(node.body, target_names)
                for handler in node.handlers:
                    yield from self._walk_calls_in_order(handler.body, target_names)
            if isinstance(node, ast.If):
                yield from self._walk_calls_in_order(node.body, target_names)
                yield from self._walk_calls_in_order(node.orelse, target_names)
            if isinstance(node, ast.FunctionDef):
                yield from self._walk_calls_in_order(node.body, target_names)

    def test_ast_rewrite_before_print(self):
        """AC7.3.1 — static AST scan: rewrite_state appears before print."""
        source = (HOOKS_DIR / "review-dispatch.py").read_text(encoding="utf-8")
        tree = ast.parse(source)
        main_fn = next(
            n for n in tree.body
            if isinstance(n, ast.FunctionDef) and n.name == "main"
        )
        calls = list(self._walk_calls_in_order(main_fn.body, {"rewrite_state", "print"}))
        rewrite_lines = [ln for ln, n in calls if n == "rewrite_state"]
        print_lines = [ln for ln, n in calls if n == "print"]
        self.assertTrue(rewrite_lines, "no rewrite_state call found in main()")
        self.assertTrue(print_lines, "no print call found in main()")
        # The final emit print must be after the rewrite_state call.
        self.assertLess(
            min(rewrite_lines), max(print_lines),
            msg=f"AC7.3.1 violated: rewrite={rewrite_lines}, print={print_lines}",
        )

    def test_mock_trace_rewrite_before_print(self):
        """AC7.3.3 — execute-time mock trace verifies rewrite runs first."""
        import importlib.util
        spec_module = importlib.util.spec_from_file_location(
            "review_dispatch_under_test", HOOKS_DIR / "review-dispatch.py",
        )
        mod = importlib.util.module_from_spec(spec_module)
        spec_module.loader.exec_module(mod)

        import builtins
        call_log: list[str] = []
        original_rewrite = mod.rewrite_state
        original_print = builtins.print

        def traced_rewrite(*args, **kwargs):
            call_log.append("rewrite_state")
            return original_rewrite(*args, **kwargs)

        def traced_print(*args, **kwargs):
            # Only count stdout prints (json emit), not stderr loud logs.
            if kwargs.get("file") is None:
                call_log.append("print_stdout")
            return original_print(*args, **kwargs)

        repo = _make_temp_repo()
        try:
            session_id = "test-mock-trace"
            _write_pending_review_state(
                repo, session_id, spec_path="/tmp/x-spec.md", mode="spec",
            )
            with mock.patch.object(mod, "rewrite_state", traced_rewrite), \
                 mock.patch.object(builtins, "print", traced_print), \
                 mock.patch.dict(os.environ, {
                     "DEVBREW_SPEC_DISTILL_SESSION_ID": session_id,
                 }), \
                 mock.patch("sys.stdin", new=__import__("io").StringIO("{}")):
                cwd_before = os.getcwd()
                try:
                    os.chdir(repo)
                    mod.main()
                finally:
                    os.chdir(cwd_before)
        finally:
            shutil.rmtree(repo, ignore_errors=True)
        try:
            r_idx = call_log.index("rewrite_state")
        except ValueError:
            self.fail(f"rewrite_state not called; trace: {call_log}")
        try:
            p_idx = call_log.index("print_stdout")
        except ValueError:
            self.fail(f"print_stdout not called; trace: {call_log}")
        self.assertLess(
            r_idx, p_idx,
            msg=f"AC7.3.3 violated: rewrite at {r_idx}, print at {p_idx}; trace: {call_log}",
        )


class TestSpecWriteValidatorSchema(HookOutputSchemaTestBase):
    """AC2 — spec-write-validator.py advisory branch output schema."""

    def test_design_mode_advisory_emits_additional_context(self):
        # Create a valid design.md fixture so the validator passes structural
        # checks and reaches the advisory branch.
        spec_rel = Path("docs") / "superpowers" / "specs" / "2026-05-17-test-design.md"
        spec_abs = self.repo / spec_rel
        spec_abs.parent.mkdir(parents=True, exist_ok=True)
        spec_abs.write_text(
            "# Test Design\n\nContext / Why\n\nGoals\n\nNon-goals\n\n"
            "Constraints\n\nAcceptance Criteria\n\nFiles\n\nVerification Plan\n\n"
            "Rejected Alternatives\n\nMetadata\n",
            encoding="utf-8",
        )
        stdin_payload = {
            "session_id": "test-pttu",
            "hook_event_name": "PostToolUse",
            "tool_name": "Write",
            "tool_input": {"file_path": str(spec_abs)},
            "tool_output": "ok",
            "cwd": str(self.repo),
        }
        result = _run_hook(
            "spec-write-validator.py",
            cwd=self.repo, stdin_payload=stdin_payload,
            env_extra={"DEVBREW_SPEC_DISTILL_SESSION_ID": "test-pttu"},
        )
        self.assertEqual(result.returncode, 0, msg=f"stderr: {result.stderr}")
        self.assertTrue(result.stdout.strip(), msg="advisory stdout empty")
        payload = json.loads(result.stdout)
        hso = payload.get("hookSpecificOutput", {})
        self.assertEqual(hso.get("hookEventName"), "PostToolUse")
        ac = hso.get("additionalContext", "")
        self.assertIn("structural OK", ac)
        self.assertIn("Reviewer will be dispatched", ac)
        sysmsg = payload.get("systemMessage", "")
        self.assertTrue(sysmsg)
        self.assertLessEqual(len(sysmsg), 120)
        self.assertTrue(sysmsg.startswith("[spec-distill]"))


class TestPendingReviewReminderSchema(HookOutputSchemaTestBase):
    """AC3 — pending-review-reminder.py output schema."""

    def test_pending_review_past_ttl_emits_reminder_in_additional_context(self):
        session_id = "test-reminder"
        # last_dispatched_at older than 30s default TTL.
        old_ts = "2026-05-16T00:00:00Z"
        _write_pending_review_state(
            self.repo, session_id,
            spec_path="/tmp/x-design.md", mode="design",
            worktree_path="/tmp/wt",
            last_dispatched_at=old_ts,
        )
        stdin_payload = {"user_prompt": "hi", "session_id": session_id}
        result = _run_hook(
            "pending-review-reminder.py",
            cwd=self.repo, stdin_payload=stdin_payload,
            env_extra={"DEVBREW_SPEC_DISTILL_SESSION_ID": session_id},
        )
        self.assertEqual(result.returncode, 0, msg=f"stderr: {result.stderr}")
        self.assertTrue(result.stdout.strip())
        payload = json.loads(result.stdout)
        hso = payload.get("hookSpecificOutput", {})
        self.assertEqual(hso.get("hookEventName"), "UserPromptSubmit")
        ac = hso.get("additionalContext", "")
        self.assertIn("REMINDER", ac)
        self.assertIn("pending_review", ac)
        self.assertIn("reviewing-spec", ac)
        sysmsg = payload.get("systemMessage", "")
        self.assertTrue(sysmsg)
        self.assertLessEqual(len(sysmsg), 120)


class TestInterviewTriggerSchema(HookOutputSchemaTestBase):
    """AC4 — interview-trigger.sh output schema (bash, jq + no-jq paths)."""

    def _run(self, env_extra=None):
        stdin_payload = {"user_prompt": "make a chat app"}
        return _run_hook(
            "interview-trigger.sh",
            cwd=self.repo, stdin_payload=stdin_payload,
            env_extra=env_extra, binary="bash",
        )

    @unittest.skipUnless(shutil.which("jq"), "jq required for AC4-a")
    def test_jq_path_emits_additional_context(self):
        result = self._run()
        self.assertEqual(result.returncode, 0, msg=f"stderr: {result.stderr}")
        self.assertTrue(result.stdout.strip())
        payload = json.loads(result.stdout)
        hso = payload.get("hookSpecificOutput", {})
        self.assertEqual(hso.get("hookEventName"), "UserPromptSubmit")
        ac = hso.get("additionalContext", "")
        self.assertIn("interview", ac)
        self.assertIn("advisory", ac)
        sysmsg = payload.get("systemMessage", "")
        self.assertTrue(sysmsg)
        self.assertLessEqual(len(sysmsg), 120)

    def test_no_jq_fallback_emits_additional_context(self):
        # Force no-jq by stripping PATH to a dir without jq.
        no_jq_bin = self.repo / "no-jq-bin"
        no_jq_bin.mkdir()
        # Symlink only bash + python3 + sed + tr + grep + printf + cat + wc.
        for tool in ("bash", "python3", "sed", "tr", "grep", "printf", "cat", "wc"):
            src = shutil.which(tool)
            if src:
                (no_jq_bin / tool).symlink_to(src)
        result = self._run(env_extra={"PATH": str(no_jq_bin)})
        self.assertEqual(result.returncode, 0, msg=f"stderr: {result.stderr}")
        self.assertTrue(result.stdout.strip())
        payload = json.loads(result.stdout)
        hso = payload.get("hookSpecificOutput", {})
        self.assertEqual(hso.get("hookEventName"), "UserPromptSubmit")
        self.assertIn("interview", hso.get("additionalContext", ""))
