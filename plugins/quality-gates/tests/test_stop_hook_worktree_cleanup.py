#!/usr/bin/env python3
"""Unit tests for stop-hook.py worktree cleanup on terminal status."""
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

PLUGIN_DIR = Path(__file__).resolve().parent.parent
HOOK = PLUGIN_DIR / "hooks" / "stop-hook.py"


def make_repo_with_worktree(tmp: Path) -> tuple[Path, Path, str]:
    repo = tmp / "repo"
    repo.mkdir()
    subprocess.run(["git", "init", "-q", "-b", "main"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.email", "t@t"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.name", "t"], cwd=repo, check=True)
    subprocess.run(["git", "commit", "-q", "--allow-empty", "-m", "init"],
                   cwd=repo, check=True)
    subprocess.run(["git", "branch", "feat-x"], cwd=repo, check=True)
    wtdir = repo / ".claude" / "quality-gates" / "worktrees" / "feat-x-abc12345"
    subprocess.run(
        ["git", "worktree", "add", "--detach", str(wtdir), "feat-x"],
        cwd=repo, check=True, capture_output=True,
    )
    return repo, wtdir, "feat-x"


def write_state(repo: Path, sid: str, worktree_abs: str, status: str = "completed",
                include_worktree_fields: bool = True):
    sdir = repo / ".claude" / "quality-gates" / sid
    sdir.mkdir(parents=True, exist_ok=True)
    worktree_lines = ""
    if include_worktree_fields:
        worktree_lines = (
            f'worktree_path: "{worktree_abs}"\n'
            f'target_branch: "feat-x"\n'
        )
    (sdir / "pipeline.md").write_text(
        f"""---
status: {status}
current_gate: 3
gate2_iteration: 1
max_gate2_iterations: 5
gate3_resolution_iter: 0
last_gate3_needed_hash: ""
max_gate3_resolutions: 3
skip_runtime: false
single_gate: null
plan_file: "auto"
pr_url: ""
available_plugins: ""
project_dir: "{worktree_abs}"
session_id: "{sid}"
started_at: "2026-05-17T00:00:00Z"
{worktree_lines}---

# Quality Gates Pipeline State

## Gate Results

## Pipeline History
- init
"""
    )
    return sdir / "pipeline.md"


def run_hook(repo: Path, sid: str, signal_text: str, env_overrides=None):
    payload = {
        "session_id": sid,
        "cwd": str(repo),
        "last_assistant_message": signal_text,
        "transcript_path": "",
    }
    env = os.environ.copy()
    if env_overrides:
        env.update(env_overrides)
    return subprocess.run(
        [sys.executable, str(HOOK)],
        input=json.dumps(payload),
        capture_output=True, text=True, env=env,
    )


def test_complete_removes_worktree():
    with tempfile.TemporaryDirectory() as tmp:
        repo, wt, _ = make_repo_with_worktree(Path(tmp))
        sid = "completesess12"
        write_state(repo, sid, str(wt))
        signal = '<qg-signal gate="3" verdict="PASS" summary="ok" />'
        result = run_hook(repo, sid, signal)
        assert not wt.exists(), (
            f"worktree {wt} should be removed on complete. "
            f"stdout={result.stdout!r} stderr={result.stderr!r}"
        )


def test_abort_removes_worktree():
    with tempfile.TemporaryDirectory() as tmp:
        repo, wt, _ = make_repo_with_worktree(Path(tmp))
        sid = "abortsess123456"
        write_state(repo, sid, str(wt))
        signal = '<qg-signal action="abort" reason="user" />'
        result = run_hook(repo, sid, signal)
        assert not wt.exists(), (
            f"worktree should be removed on abort. "
            f"stdout={result.stdout!r} stderr={result.stderr!r}"
        )


def test_keep_env_preserves_worktree():
    with tempfile.TemporaryDirectory() as tmp:
        repo, wt, _ = make_repo_with_worktree(Path(tmp))
        sid = "keepsess1234567"
        write_state(repo, sid, str(wt))
        signal = '<qg-signal gate="3" verdict="PASS" summary="ok" />'
        run_hook(repo, sid, signal,
                 env_overrides={"DEVBREW_QG_KEEP_WORKTREE": "1"})
        assert wt.exists(), "worktree should be preserved with KEEP=1"


def test_no_worktree_path_no_op():
    """Legacy state (no worktree_path) → hook must not error."""
    with tempfile.TemporaryDirectory() as tmp:
        repo, wt, _ = make_repo_with_worktree(Path(tmp))
        sid = "legacysess12345"
        # State without worktree_path field
        write_state(repo, sid, str(wt), include_worktree_fields=False)
        result = run_hook(repo, sid, '<qg-signal gate="3" verdict="PASS" summary="" />')
        assert result.returncode == 0, f"legacy state errored: stdout={result.stdout!r} stderr={result.stderr!r}"


def test_gate3_fail_preserves_worktree():
    with tempfile.TemporaryDirectory() as tmp:
        repo, wt, _ = make_repo_with_worktree(Path(tmp))
        sid = "gate3failsess12"
        # status must be gate3_running so hook routes through Gate 3 logic
        write_state(repo, sid, str(wt), status="gate3_running")
        signal = '<qg-signal gate="3" verdict="FAIL" summary="" />'
        result = run_hook(repo, sid, signal)
        assert wt.exists(), (
            f"worktree must persist on gate3_fail. "
            f"stdout={result.stdout!r} stderr={result.stderr!r}"
        )


def test_gate2_user_choice_preserves_worktree():
    with tempfile.TemporaryDirectory() as tmp:
        repo, wt, _ = make_repo_with_worktree(Path(tmp))
        sid = "gate2userses12X"
        write_state(repo, sid, str(wt), status="gate2_running")
        signal = '<qg-signal gate="2" verdict="NEEDS_RESTART" summary="" />'
        result = run_hook(repo, sid, signal)
        assert wt.exists(), (
            f"worktree must persist on gate2_user_choice. "
            f"stdout={result.stdout!r} stderr={result.stderr!r}"
        )


if __name__ == "__main__":
    test_complete_removes_worktree()
    print("test_complete_removes_worktree passed")
    test_abort_removes_worktree()
    print("test_abort_removes_worktree passed")
    test_keep_env_preserves_worktree()
    print("test_keep_env_preserves_worktree passed")
    test_no_worktree_path_no_op()
    print("test_no_worktree_path_no_op passed")
    test_gate3_fail_preserves_worktree()
    print("test_gate3_fail_preserves_worktree passed")
    test_gate2_user_choice_preserves_worktree()
    print("test_gate2_user_choice_preserves_worktree passed")
    print("All stop-hook worktree cleanup tests passed.")
