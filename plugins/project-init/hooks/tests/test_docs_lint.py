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
            self.assertEqual(rc, 0)

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
            self.assertEqual(rc, 0)

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
            self.assertEqual(rc, 0)

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
            self.assertIn("L3", out)
            self.assertEqual(rc, 0)

    def test_4_backtick_fence_without_lang_warns(self):
        """AC11 (v1.4.0 fix): 4+ backtick fence without language tag → warn (no more accidental skip)."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# Title\n\n"
                "````\n"  # 4 backticks, no language → should warn
                "code\n"
                "````\n"
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("fenced code block", out)
            self.assertEqual(rc, 0)

    def test_4_backtick_fence_with_lang_passes(self):
        """AC11 (v1.4.0 fix): 4+ backtick fence WITH language → pass."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# Title\n\n"
                "````python\n"
                "x = 1\n"
                "````\n"
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("fenced code block", out)
            self.assertEqual(rc, 0)

    def test_space_separated_info_string_passes(self):
        """F5 regression: ``` bash (CommonMark §4.5 space-separated info string) → pass.

        Previously the regex ``^ {0,3}` ``` `(\S*)\s*$`` missed this entirely, causing
        the closing fence to be reinterpreted as a bare opener (false-positive +
        state corruption). The relaxed regex handles whitespace between the fence
        and the info string.
        """
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# Title\n\n"
                "``` bash\n"  # space-separated info string
                "echo hi\n"
                "```\n"
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("fenced code block", out)
            self.assertEqual(rc, 0)


class TestR6Links(unittest.TestCase):
    """R6 — internal markdown links must resolve."""

    def test_resolved_link_passes(self):
        """AC13: link to existing sibling file → pass."""
        with tempfile.TemporaryDirectory() as td:
            sibling = Path(td) / "docs.md"
            sibling.write_text("ok")
            target = Path(td) / "AGENTS.md"
            target.write_text("# Title\n\nSee [docs](docs.md).\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("unresolved internal link", out)
            self.assertEqual(rc, 0)

    def test_unresolved_link_warns(self):
        """AC13/AC14: link to non-existent file → warn with path listed."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text("# Title\n\nSee [missing](nope.md).\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("1 unresolved internal link", out)
            self.assertIn("nope.md", out)
            self.assertEqual(rc, 0)

    def test_url_scheme_skipped(self):
        """AC13: URL schemes (http, https, mailto, custom) → skip."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# Title\n\n"
                "- [external](https://example.com)\n"
                "- [contact](mailto:x@y.z)\n"
                "- [phone](tel:1234)\n"
                "- [custom](weird+scheme:foo)\n"
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("unresolved internal link", out)
            self.assertEqual(rc, 0)

    def test_anchor_only_link_skipped(self):
        """AC13: #anchor-only link → skip (same-file anchor not checked)."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text("# Title\n\n[jump](#section)\n## section\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("unresolved internal link", out)
            self.assertEqual(rc, 0)

    def test_fragment_stripped_before_check(self):
        """AC13: link with #fragment — path checked, fragment stripped."""
        with tempfile.TemporaryDirectory() as td:
            sibling = Path(td) / "docs.md"
            sibling.write_text("ok")
            target = Path(td) / "AGENTS.md"
            target.write_text("[see](docs.md#header)\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("unresolved internal link", out)
            self.assertEqual(rc, 0)

    def test_escape_outside_project_dir_skipped(self):
        """AC15: link target escaping project_dir → treated as external, skipped."""
        with tempfile.TemporaryDirectory() as td_outer:
            with tempfile.TemporaryDirectory() as td_project:
                outside = Path(td_outer) / "other.md"
                outside.write_text("ok")
                target = Path(td_project) / "AGENTS.md"
                # relative path going up and out
                rel = os.path.relpath(outside, td_project)
                target.write_text(f"[outside]({rel})\n")
                out, rc = run_hook(
                    {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                    cwd=td_project,
                )
                self.assertNotIn("unresolved internal link", out)
                self.assertEqual(rc, 0)

    def test_multi_unresolved_truncates_at_5(self):
        """AC14: max 5 listed, '... and M more' suffix beyond."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text("\n".join(f"[bad{i}](no{i}.md)" for i in range(8)) + "\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("8 unresolved internal link", out)
            self.assertIn("and 3 more", out)
            self.assertEqual(rc, 0)

    def test_uppercase_url_scheme_skipped(self):
        """AC13: case-insensitive URL scheme detection (RFC 3986)."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text("[X](HTTPS://example.com)\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("unresolved internal link", out)
            self.assertEqual(rc, 0)

    def test_link_with_title_attribute_passes(self):
        """F6 regression: [text](docs.md "title") — title stripped before path resolution."""
        with tempfile.TemporaryDirectory() as td:
            sibling = Path(td) / "docs.md"
            sibling.write_text("ok")
            target = Path(td) / "AGENTS.md"
            target.write_text('[see](docs.md "Hover title here")\n')
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("unresolved internal link", out)
            self.assertEqual(rc, 0)

    def test_image_syntax_skipped(self):
        """F6 regression: ![alt](src) image syntax → skipped (images are not link rule scope)."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text("![logo](nonexistent-logo.png)\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("unresolved internal link", out)
            self.assertEqual(rc, 0)

    def test_angle_bracket_destination(self):
        """F6 regression: [x](<path with spaces.md>) — angle brackets stripped."""
        with tempfile.TemporaryDirectory() as td:
            sibling = Path(td) / "path with spaces.md"
            sibling.write_text("ok")
            target = Path(td) / "AGENTS.md"
            target.write_text("[see](<path with spaces.md>)\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("unresolved internal link", out)
            self.assertEqual(rc, 0)


class TestRPointer(unittest.TestCase):
    """R-pointer — CLAUDE.md ↔ AGENTS.md drift detection (bidirectional trigger)."""

    def _write_pair(self, td: str, agents_content: str, claude_content: str, sub: str = "") -> Tuple[Path, Path]:
        base = Path(td) / sub if sub else Path(td)
        base.mkdir(parents=True, exist_ok=True)
        a = base / "AGENTS.md"
        c = base / "CLAUDE.md"
        a.write_text(agents_content)
        c.write_text(claude_content)
        return a, c

    def test_only_one_file_no_check(self):
        """AC16: drift requires BOTH files; only AGENTS.md present → no R-pointer."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text("# title\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("drift risk", out)
            self.assertEqual(rc, 0)

    def test_thin_pointer_passes(self):
        """AC16 cond 2: CLAUDE.md is '@AGENTS.md' → pass."""
        with tempfile.TemporaryDirectory() as td:
            a, c = self._write_pair(td, "# canonical\n", "@AGENTS.md\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(c)}},
                cwd=td,
            )
            self.assertNotIn("drift risk", out)
            self.assertEqual(rc, 0)

    def test_thin_pointer_with_frontmatter_passes(self):
        """AC16 normalization: frontmatter stripped before @AGENTS.md check."""
        with tempfile.TemporaryDirectory() as td:
            a, c = self._write_pair(
                td,
                "# canonical\n",
                "---\ntitle: foo\n---\n@AGENTS.md\n",
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(c)}},
                cwd=td,
            )
            self.assertNotIn("drift risk", out)
            self.assertEqual(rc, 0)

    def test_frontmatter_no_trailing_newline_passes(self):
        """AC16 trailing newline regex: closing --- without \\n still strips."""
        with tempfile.TemporaryDirectory() as td:
            base = Path(td)
            (base / "AGENTS.md").write_text("# canonical\n")
            (base / "CLAUDE.md").write_text("---\nfoo: bar\n---\n@AGENTS.md")  # no trailing \n
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(base / "CLAUDE.md")}},
                cwd=td,
            )
            self.assertNotIn("drift risk", out)
            self.assertEqual(rc, 0)

    def test_html_comments_stripped(self):
        """AC16: HTML comments removed before comparison."""
        with tempfile.TemporaryDirectory() as td:
            a, c = self._write_pair(
                td,
                "# canonical\n",
                "<!-- maintainer note -->\n@AGENTS.md\n",
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(c)}},
                cwd=td,
            )
            self.assertNotIn("drift risk", out)
            self.assertEqual(rc, 0)

    def test_divergent_content_warns(self):
        """AC17: both exist + CLAUDE.md has divergent content → drift warning."""
        with tempfile.TemporaryDirectory() as td:
            a, c = self._write_pair(
                td,
                "# canonical AGENTS\n",
                "# completely different CLAUDE\n\nLots of content here.\n",
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(c)}},
                cwd=td,
            )
            self.assertIn("drift risk", out)
            self.assertIn("ln -sf AGENTS.md CLAUDE.md", out)
            self.assertEqual(rc, 0)

    def test_symlink_passes(self):
        """AC16 cond 1: CLAUDE.md is symlink to AGENTS.md → pass."""
        with tempfile.TemporaryDirectory() as td:
            a = Path(td) / "AGENTS.md"
            a.write_text("# canonical\n")
            c = Path(td) / "CLAUDE.md"
            os.symlink("AGENTS.md", c)
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(c)}},
                cwd=td,
            )
            self.assertNotIn("drift risk", out)
            self.assertEqual(rc, 0)

    def test_bidirectional_trigger_from_agents_edit(self):
        """AC18.5: editing AGENTS.md also triggers R-pointer if pair CLAUDE.md is divergent."""
        with tempfile.TemporaryDirectory() as td:
            a, c = self._write_pair(
                td,
                "# canonical AGENTS\n",
                "# divergent CLAUDE\n\nstuff\n",
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(a)}},  # AGENTS edited
                cwd=td,
            )
            self.assertIn("drift risk", out)
            self.assertEqual(rc, 0)

    def test_dot_claude_dir_independent(self):
        """AC18: .claude/CLAUDE.md ↔ .claude/AGENTS.md checked independently."""
        with tempfile.TemporaryDirectory() as td:
            dot = Path(td) / ".claude"
            a, c = self._write_pair(td, "# root agents\n", "@AGENTS.md\n")  # root pair OK
            dot.mkdir()
            (dot / "AGENTS.md").write_text("# inner\n")
            (dot / "CLAUDE.md").write_text("# divergent inner\n\ndifferent content\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(dot / "CLAUDE.md")}},
                cwd=td,
            )
            self.assertIn("drift risk", out)
            # Root pair is fine, not flagged
            self.assertNotIn("Make CLAUDE.md contain", out.split("drift risk")[0])
            self.assertEqual(rc, 0)


class TestRobustness(unittest.TestCase):
    """F1 + F3 regression tests — graceful degradation against pathological inputs."""

    def test_circular_symlink_does_not_crash(self):
        """F1 regression: Path.resolve() on a circular symlink raises RuntimeError.

        The hook must not propagate the exception — it must catch (OSError, RuntimeError)
        in safe_resolve() and exit 0 with {} per the advisory contract.
        """
        with tempfile.TemporaryDirectory() as td:
            # Create CLAUDE.md as a symlink to itself (circular)
            loop = Path(td) / "CLAUDE.md"
            os.symlink("CLAUDE.md", loop)
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(loop)}},
                cwd=td,
            )
            self.assertEqual(rc, 0)
            # stdout is JSON `{}` (no traceback, no systemMessage)
            self.assertEqual(out.strip(), "{}")

    def test_r6_broken_symlink_target_does_not_crash(self):
        """F1 regression: R6 link pointing at a symlink loop must skip, not crash."""
        with tempfile.TemporaryDirectory() as td:
            # Symlink loop inside the project dir
            loop = Path(td) / "loop.md"
            os.symlink("loop.md", loop)
            target = Path(td) / "AGENTS.md"
            target.write_text("[broken](loop.md)\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertEqual(rc, 0)
            # Hook must produce valid JSON — either {} or a systemMessage, not a crash
            self.assertTrue(out.strip().startswith("{"))


class TestCharterTarget(unittest.TestCase):
    """C10/AC11: docs/project/*.md become additive lint targets; the existing
    4-path exact-set membership is untouched (regression-free)."""

    def test_charter_doc_is_linted(self):
        """AC11: an oversized docs/project/charter.md now reaches the rule layer
        (proves it is a recognized target) and R1 fires."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "docs" / "project" / "charter.md"
            target.parent.mkdir(parents=True)
            target.write_text("\n".join(f"line {i}" for i in range(250)) + "\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("Anthropic recommends", out)
            self.assertEqual(rc, 0)

    def test_charter_doc_clean_passes(self):
        """A clean docs/project/conventions.md → {}."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "docs" / "project" / "conventions.md"
            target.parent.mkdir(parents=True)
            target.write_text("# Conventions\n\n## Naming\n\nkebab-case.\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertEqual(out.strip(), "{}")
            self.assertEqual(rc, 0)

    def test_non_charter_docs_path_not_targeted(self):
        """C10 boundary: docs/other.md (not under docs/project/) stays a non-target
        even when oversized → {}."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "docs" / "other.md"
            target.parent.mkdir(parents=True)
            target.write_text("\n".join(f"line {i}" for i in range(250)) + "\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertEqual(out.strip(), "{}")
            self.assertEqual(rc, 0)

    def test_lookalike_prefix_not_targeted(self):
        """C10 boundary: docs/projectile/x.md must NOT match the docs/project/ prefix."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "docs" / "projectile" / "x.md"
            target.parent.mkdir(parents=True)
            target.write_text("\n".join(f"line {i}" for i in range(250)) + "\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertEqual(out.strip(), "{}")
            self.assertEqual(rc, 0)


class TestRCharter(unittest.TestCase):
    """AC11: AGENTS.md '## Project Charter' required-subsection integrity
    (heading-bounded; Vision / Non-goals / Tech Stack)."""

    def _agents_with_charter(self, vision: str, nongoals: str, tech: str) -> str:
        return (
            "# Project AGENTS\n\n"
            "## Project Charter\n\n"
            f"**Vision:** {vision}\n\n"
            f"**Non-goals:** {nongoals}\n\n"
            f"**Tech Stack:** {tech}\n\n"
            "상세: [charter](docs/project/charter.md)\n\n"
            "## Git Workflow\n\nGitHub Flow.\n"
        )

    def test_complete_charter_passes(self):
        """All three labels filled → no charter advisory."""
        with tempfile.TemporaryDirectory() as td:
            # Make the docs/project pointer resolve so R6 stays quiet.
            cdir = Path(td) / "docs" / "project"
            cdir.mkdir(parents=True)
            (cdir / "charter.md").write_text("# Charter\n")
            target = Path(td) / "AGENTS.md"
            target.write_text(self._agents_with_charter(
                "Ship a fast static-site generator.",
                "No CMS, no plugins runtime.",
                "Go 1.22, Hugo.",
            ))
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("Project Charter' section is incomplete", out)
            self.assertEqual(rc, 0)

    def test_missing_label_warns(self):
        """A required label absent → charter advisory naming it."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(
                "# A\n\n## Project Charter\n\n"
                "**Vision:** Ship it.\n\n"
                "**Tech Stack:** Go.\n\n"  # Non-goals label missing
                "## Git Workflow\n\nx\n"
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("section is incomplete", out)
            self.assertIn("Non-goals (label missing)", out)
            self.assertEqual(rc, 0)

    def test_empty_value_warns(self):
        """A label present but value empty → 'empty' advisory."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(self._agents_with_charter("Ship it.", "", "Go."))
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("section is incomplete", out)
            self.assertIn("Non-goals (empty)", out)
            self.assertEqual(rc, 0)

    def test_placeholder_residue_warns(self):
        """An unfilled {{...}} placeholder → 'placeholder' advisory (AC11 iii)."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(self._agents_with_charter("{{VISION}}", "No CMS.", "Go."))
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertIn("section is incomplete", out)
            self.assertIn("Vision", out)
            self.assertIn("placeholder", out)
            self.assertEqual(rc, 0)

    def test_no_charter_section_no_op(self):
        """AGENTS.md without a '## Project Charter' section → rule no-ops (a
        git-workflow-only AGENTS.md must not be falsely flagged)."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text("# A\n\n## Git Workflow\n\nGitHub Flow.\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertEqual(out.strip(), "{}")
            self.assertEqual(rc, 0)

    def test_charter_rule_only_on_agents(self):
        """The charter rule fires only for AGENTS.md basename — a CLAUDE.md that
        happens to contain a '## Project Charter' heading is not charter-linted."""
        with tempfile.TemporaryDirectory() as td:
            # AGENTS.md present (pair) so R-pointer doesn't dominate the assertion.
            (Path(td) / "AGENTS.md").write_text("# canonical\n")
            target = Path(td) / "CLAUDE.md"
            target.write_text(
                "# C\n\n## Project Charter\n\n**Vision:**\n\n"  # empty, but not AGENTS.md
            )
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("section is incomplete", out)
            self.assertEqual(rc, 0)

    def test_charter_doc_not_charter_linted(self):
        """docs/project/charter.md uses ## Vision etc. — it must NOT be subjected
        to the AGENTS.md '## Project Charter' subsection rule."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "docs" / "project" / "charter.md"
            target.parent.mkdir(parents=True)
            target.write_text("# Charter\n\n## Vision\n\nShip it.\n")
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
            )
            self.assertNotIn("section is incomplete", out)
            self.assertEqual(out.strip(), "{}")
            self.assertEqual(rc, 0)

    def test_kill_switch_silences_charter(self):
        """AC12: DEVBREW_SKIP_HOOKS=project-init:docs-lint silences the charter rule
        with no new kill-switch token."""
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "AGENTS.md"
            target.write_text(self._agents_with_charter("{{VISION}}", "", "Go."))
            out, rc = run_hook(
                {"tool_name": "Write", "tool_input": {"file_path": str(target)}},
                cwd=td,
                env_override={"DEVBREW_SKIP_HOOKS": "project-init:docs-lint"},
            )
            self.assertEqual(out.strip(), "{}")
            self.assertEqual(rc, 0)


if __name__ == "__main__":
    unittest.main()
