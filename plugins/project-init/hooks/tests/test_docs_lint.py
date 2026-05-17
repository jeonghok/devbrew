"""Unit tests for plugins/project-init/hooks/docs-lint.py."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Optional, Tuple

HOOK = Path(__file__).resolve().parent.parent / "docs-lint.py"


def run_hook(payload: dict, env_override: Optional[dict] = None, cwd: Optional[str] = None) -> Tuple[str, int]:
    """Invoke the hook with given JSON payload; return (stdout, returncode)."""
    env = os.environ.copy()
    # Strip any inherited devbrew env vars first to make tests deterministic
    for k in list(env):
        if k.startswith("DEVBREW_"):
            del env[k]
    if env_override:
        env.update(env_override)
    if cwd:
        env["CLAUDE_PROJECT_DIR"] = cwd
    cp = subprocess.run(
        [sys.executable, str(HOOK)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        env=env,
        timeout=10,
    )
    return cp.stdout, cp.returncode


class TestSkeleton(unittest.TestCase):
    """AC1, AC2, AC4, AC5, AC6 — skeleton behavior."""

    def test_kill_switch_full_disable(self):
        """AC4: DEVBREW_DISABLE_PROJECT_INIT=1 → {} exit 0."""
        out, rc = run_hook(
            {"tool_name": "Write", "tool_input": {"file_path": "/anything/CLAUDE.md"}},
            env_override={"DEVBREW_DISABLE_PROJECT_INIT": "1"},
        )
        self.assertEqual(out.strip(), "{}")
        self.assertEqual(rc, 0)

    def test_kill_switch_hook_opt_out(self):
        """AC4: DEVBREW_SKIP_HOOKS containing project-init:docs-lint → {}."""
        out, rc = run_hook(
            {"tool_name": "Write", "tool_input": {"file_path": "/anything/CLAUDE.md"}},
            env_override={"DEVBREW_SKIP_HOOKS": "other:foo,project-init:docs-lint,bar:baz"},
        )
        self.assertEqual(out.strip(), "{}")
        self.assertEqual(rc, 0)

    def test_non_target_tool_no_op(self):
        """AC2: Bash tool input → {} (only Write/Edit/MultiEdit checked)."""
        with tempfile.TemporaryDirectory() as td:
            out, rc = run_hook(
                {"tool_name": "Bash", "tool_input": {"command": "ls"}},
                cwd=td,
            )
            self.assertEqual(out.strip(), "{}")
            self.assertEqual(rc, 0)

    def test_non_target_file_no_op(self):
        """AC2: file_path that isn't one of the 4 names → {}."""
        with tempfile.TemporaryDirectory() as td:
            other = Path(td) / "README.md"
            other.write_text("# readme\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(other)}},
                cwd=td,
            )
            self.assertEqual(out.strip(), "{}")
            self.assertEqual(rc, 0)

    def test_invalid_json_graceful(self):
        """AC6: invalid stdin JSON → {} exit 0 (graceful)."""
        # send raw garbage instead of structured payload
        env = {k: v for k, v in os.environ.items() if not k.startswith("DEVBREW_")}
        cp = subprocess.run(
            [sys.executable, str(HOOK)],
            input="this is not json",
            capture_output=True,
            text=True,
            env=env,
            timeout=10,
        )
        self.assertEqual(cp.stdout.strip(), "{}")
        self.assertEqual(cp.returncode, 0)

    def test_worktree_path_skip(self):
        """AC5: file_path inside .git/worktrees/** → skip ({})."""
        with tempfile.TemporaryDirectory() as td:
            wt_dir = Path(td) / ".git" / "worktrees" / "wt1"
            wt_dir.mkdir(parents=True)
            wt_file = wt_dir / "CLAUDE.md"
            wt_file.write_text("# stub\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(wt_file)}},
                cwd=td,
            )
            self.assertEqual(out.strip(), "{}")
            self.assertEqual(rc, 0)

    def test_path_traversal_outside_project_dir(self):
        """C4: file_path escaping CLAUDE_PROJECT_DIR → skip."""
        with tempfile.TemporaryDirectory() as td_outer:
            with tempfile.TemporaryDirectory() as td_project:
                outside = Path(td_outer) / "CLAUDE.md"
                outside.write_text("# stub\n")
                out, rc = run_hook(
                    {"tool_name": "Write", "tool_input": {"file_path": str(outside)}},
                    cwd=td_project,
                )
                self.assertEqual(out.strip(), "{}")
                self.assertEqual(rc, 0)

    def test_target_file_passes_through_to_rules(self):
        """AC1: target file passes filter and reaches rule layer; valid 3-line content stays below all rule thresholds so output is {}."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "CLAUDE.md"
            target.write_text("# Title\n\nShort content.\n")  # passes all 5 rules
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertEqual(out.strip(), "{}")
            self.assertEqual(rc, 0)


class TestR1Size(unittest.TestCase):
    """R1 — file size threshold (warn at >200, strong warn at >300)."""

    def _write_lines(self, td: str, basename: str, n: int) -> Path:
        p = Path(td) / basename
        p.write_text("\n".join(f"line {i}" for i in range(n)) + "\n")
        return p

    def test_exactly_200_lines_passes(self):
        """AC7: 200 lines exact → no R1 warning."""
        with tempfile.TemporaryDirectory() as td:
            target = self._write_lines(td, "CLAUDE.md", 200)
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("Anthropic recommends", out)
            self.assertEqual(rc, 0)

    def test_201_lines_warns(self):
        """AC7: 201 lines → R1 base warning (no STRONG suffix yet)."""
        with tempfile.TemporaryDirectory() as td:
            target = self._write_lines(td, "AGENTS.md", 201)
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("Anthropic recommends ≤200", out)
            self.assertIn("201 lines", out)
            self.assertNotIn("STRONG", out)
            self.assertEqual(rc, 0)

    def test_300_lines_passes_strong_threshold(self):
        """AC8: 300 lines exact → only base warning (not STRONG yet, threshold is >300)."""
        with tempfile.TemporaryDirectory() as td:
            target = self._write_lines(td, "AGENTS.md", 300)
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("Anthropic recommends ≤200", out)
            self.assertNotIn("STRONG", out)
            self.assertEqual(rc, 0)

    def test_301_lines_strong_warns(self):
        """AC8: 301 lines → R1 base + STRONG suffix in single message."""
        with tempfile.TemporaryDirectory() as td:
            target = self._write_lines(td, "AGENTS.md", 301)
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("Anthropic recommends ≤200", out)
            self.assertIn("STRONG", out)
            self.assertIn("301 lines", out)
            # AC8: single combined string, not duplicate emit
            self.assertEqual(out.count("Anthropic recommends ≤200"), 1)


class TestR2Toc(unittest.TestCase):
    """R2 — TOC required if >300 lines."""

    def test_350_lines_no_toc_warns(self):
        """AC9: 350 lines + no TOC → R2 warning (and R1 STRONG)."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text("# Title\n\n" + "\n".join(f"line {i}" for i in range(350)) + "\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("exceeds 300 lines without a TOC", out)
            # AC19: both R1 STRONG and R2 fire, joined with \n\n
            # (which is JSON-encoded as \\n\\n in the systemMessage payload)
            self.assertIn("STRONG", out)
            self.assertIn("\\n\\n", out)
            # R1 message must come before R2 message (insertion order)
            self.assertLess(
                out.index("Anthropic recommends"),
                out.index("exceeds 300 lines without a TOC"),
            )
            self.assertEqual(rc, 0)

    def test_350_lines_with_korean_toc_passes(self):
        """AC9: 350 lines + ## 목차 → R2 passes (R1 STRONG still fires)."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# Title\n\n## 목차\n\n- intro\n\n"
                + "\n".join(f"line {i}" for i in range(350)) + "\n"
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("without a TOC", out)
            self.assertIn("STRONG", out)  # R1 still fires
            self.assertEqual(rc, 0)

    def test_350_lines_with_english_toc_passes(self):
        """AC9: 350 lines + ## Table of Contents → R2 passes."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# Title\n\n## Table of Contents\n\n- intro\n\n"
                + "\n".join(f"line {i}" for i in range(350)) + "\n"
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("without a TOC", out)
            self.assertEqual(rc, 0)

    def test_300_lines_or_less_no_r2(self):
        """AC9: ≤300 lines → R2 never fires regardless of TOC presence."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text("\n".join(f"line {i}" for i in range(250)) + "\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("without a TOC", out)
            self.assertEqual(rc, 0)

    def test_toc_at_end_of_file_still_passes(self):
        """AC10: TOC location is free — bottom of file also OK."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# Title\n\n"
                + "\n".join(f"line {i}" for i in range(340)) + "\n"
                + "\n## 목차\n\n- intro\n"
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("without a TOC", out)
            self.assertEqual(rc, 0)


class TestR5Fences(unittest.TestCase):
    """R5 — fenced code blocks must declare a language (3-backtick only)."""

    def test_bare_fence_warns(self):
        """AC11: opening fence without language → warn with line number."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# Title\n\n"
                "```\n"
                "some code\n"
                "```\n"
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("fenced code block", out)
            self.assertIn("line L3", out)
            self.assertEqual(rc, 0)

    def test_languaged_fence_passes(self):
        """AC11: opening fence with bash → pass."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# Title\n\n"
                "```bash\n"
                "ls\n"
                "```\n"
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("fenced code block", out)

    def test_indented_code_block_ignored(self):
        """AC12: 4+ space indent → markdown indented code, R5 skips."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# Title\n\n"
                "    ```\n"  # 4 spaces — indented code, not fence
                "    code\n"
                "    ```\n"
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("fenced code block", out)

    def test_close_fence_not_flagged(self):
        """AC11 stateful: bare closing fence after opening fence is OK."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# Title\n\n"
                "```python\n"  # open with lang
                "x = 1\n"
                "```\n"        # bare close — must NOT trigger
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("fenced code block", out)

    def test_multi_violation_count_and_list(self):
        """AC11 message format: count + list pattern."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            # 3 bare opens (with proper closes)
            content = ""
            for _ in range(3):
                content += "```\nstuff\n```\n\n"
            target.write_text("# Title\n\n" + content)
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("3 fenced code blocks", out)
            self.assertIn("at lines [", out)

    def test_4_backtick_fence_ignored(self):
        """AC11 scope-out: 4+ backtick fences not checked."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# Title\n\n"
                "````\n"  # 4 backticks, no language
                "code\n"
                "````\n"
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("fenced code block", out)


if __name__ == "__main__":
    unittest.main()
