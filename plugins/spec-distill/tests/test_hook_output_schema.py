#!/usr/bin/env python3
"""NG9 — Python `state_path.state_root()` 와 bash `CLAUDE_PROJECT_DIR` resolver 의 일치.

Run:
    cd plugins/spec-distill/tests && python3 -m unittest -v test_hook_output_schema
"""
from __future__ import annotations

import os
import subprocess
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS_DIR = REPO_ROOT / "plugins" / "spec-distill" / "scripts"


def _in_worktree() -> bool:
    """Detect git worktree (vs main repo) via .git file (not dir)."""
    try:
        cp = subprocess.run(
            ["git", "rev-parse", "--is-inside-work-tree"],
            cwd=REPO_ROOT, capture_output=True, text=True, timeout=3, check=False,
        )
        if cp.returncode != 0 or cp.stdout.strip() != "true":
            return False
        # main repo has .git/ dir; worktree has .git file pointing to gitdir.
        dot_git = REPO_ROOT / ".git"
        return dot_git.is_file()
    except (OSError, subprocess.TimeoutExpired):
        return False


class TestCrossResolverAdvisory(unittest.TestCase):
    """NG9 — Python state_path vs bash CLAUDE_PROJECT_DIR resolver consistency.

    Skips if not running inside a worktree (the cross-resolver mismatch only
    manifests there). PASS = both resolvers point to the same dir; FAIL = the
    follow-up unification PR is needed.
    """

    @unittest.skipUnless(_in_worktree(), "cross-resolver test runs only inside a git worktree")
    def test_python_and_bash_resolvers_agree(self):
        # Python resolver: state_path.state_root()
        sys.path.insert(0, str(SCRIPTS_DIR))
        try:
            import state_path  # type: ignore
            py_root = state_path.state_root()
        finally:
            sys.path.pop(0)
        # Bash resolver: ${CLAUDE_PROJECT_DIR:-$PWD}/.claude/spec-distill
        bash_root = Path(os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())) \
            / ".claude" / "spec-distill"
        self.assertEqual(
            py_root.resolve(), bash_root.resolve(),
            msg=(
                "Python state_path and bash CLAUDE_PROJECT_DIR resolvers disagree. "
                "Follow-up PR per spec NG9 needed."
            ),
        )


if __name__ == "__main__":
    unittest.main()
