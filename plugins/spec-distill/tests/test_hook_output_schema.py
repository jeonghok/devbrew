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
