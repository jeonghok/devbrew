"""Unit tests for plugins/project-init/hooks/post-tool-use.py."""
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Optional, Tuple

HOOK = Path(__file__).resolve().parent.parent / "hooks" / "post-tool-use.py"

# The hook filename has a hyphen, so it is not importable by name. Load it via
# importlib (side-effect-free: post-tool-use.py guards execution behind
# `if __name__ == "__main__":`) so tests couple to the REAL functions/constants
# rather than parallel literal copies. Mirrors test_docs_lint.py.
_spec = importlib.util.spec_from_file_location("post_tool_use_hook", HOOK)
assert _spec is not None and _spec.loader is not None, f"could not load hook module from {HOOK}"
_hook = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_hook)


def write_strategy(project_dir: str, regex_block: Optional[str]) -> None:
    """Write docs/git-workflow/branch-strategy.md under project_dir.

    regex_block is None  -> file with NO ```regex fence (regex-less).
    regex_block == ""    -> file with an EMPTY ```regex fence (degenerate).
    otherwise            -> file with a ```regex fence containing regex_block.
    """
    dst = Path(project_dir) / "docs" / "git-workflow"
    dst.mkdir(parents=True, exist_ok=True)
    f = dst / "branch-strategy.md"
    if regex_block is None:
        f.write_text("# Branch Strategy\n\nNo regex fence here.\n")
    else:
        f.write_text(f"# Branch Strategy\n\n```regex\n{regex_block}\n```\n")


def run_hook(payload: dict, env_override: Optional[dict] = None,
             cwd: Optional[str] = None) -> Tuple[str, int]:
    """Invoke the hook script as a subprocess; return (stdout, returncode)."""
    env = os.environ.copy()
    # Strip inherited devbrew env vars so tests are deterministic.
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


class _ProjectDirTestCase(unittest.TestCase):
    """Base: isolates CLAUDE_PROJECT_DIR to a fresh tempdir per test."""

    def setUp(self) -> None:
        self._prev = os.environ.get("CLAUDE_PROJECT_DIR")
        self.tmp = tempfile.mkdtemp()
        os.environ["CLAUDE_PROJECT_DIR"] = self.tmp

    def tearDown(self) -> None:
        if self._prev is None:
            os.environ.pop("CLAUDE_PROJECT_DIR", None)
        else:
            os.environ["CLAUDE_PROJECT_DIR"] = self._prev
        shutil.rmtree(self.tmp, ignore_errors=True)


class F1FailOpenTest(_ProjectDirTestCase):
    """F1 / LD2 — no valid declared pattern => fail OPEN, loudly (AC1)."""

    def test_file_absent_fails_open(self):
        # No strategy file written under self.tmp.
        self.assertIsNone(_hook.get_branch_pattern())
        msg = _hook.validate_branch("git checkout -b release/x")
        self.assertIsNotNone(msg)
        self.assertIn("fail-open", msg)
        self.assertIn("skipping", msg)

    def test_regexless_file_fails_open(self):
        write_strategy(self.tmp, None)
        self.assertIsNone(_hook.get_branch_pattern())
        self.assertIn("fail-open", _hook.validate_branch("git checkout -b release/x"))

    def test_malformed_regex_fails_open(self):
        write_strategy(self.tmp, "^(feature|fix")  # unbalanced paren -> re.error
        self.assertIsNone(_hook.get_branch_pattern())
        self.assertIn("fail-open", _hook.validate_branch("git checkout -b whatever"))

    def test_empty_regex_fence_fails_open(self):
        write_strategy(self.tmp, "")  # ```regex\n\n``` -> search regex can't capture
        self.assertIsNone(_hook.get_branch_pattern())
        self.assertIn("fail-open", _hook.validate_branch("git checkout -b release/x"))

    def test_whitespace_only_regex_fence_fails_open(self):
        # ```regex\n   \n``` -> captures "   " -> .strip() empty -> guard -> None.
        # Must NOT become re.compile("") which would silently pass EVERY branch.
        write_strategy(self.tmp, "   ")
        self.assertIsNone(_hook.get_branch_pattern())
        msg = _hook.validate_branch("git checkout -b anything-goes")
        self.assertIsNotNone(msg)  # not silent pass-all
        self.assertIn("fail-open", msg)

    def test_declared_gitflow_pattern_respected(self):
        # AC3: a declared pattern is honored; release/* passes, no fail-open.
        write_strategy(self.tmp, r"^(feature|fix|release|hotfix)/[a-z0-9][a-z0-9.-]*$")
        pat = _hook.get_branch_pattern()
        self.assertIsNotNone(pat)
        self.assertIsNone(_hook.validate_branch("git checkout -b release/v1.2"))

    def test_non_utf8_strategy_file_fails_open(self):
        # 5th malformed case (qg-security + adversarial): a non-UTF-8/binary
        # branch-strategy.md must fail OPEN (loud advisory), never crash — this
        # preserves the always-exit-0 advisory contract AND must not let a
        # get_branch_pattern crash silently defeat commit validation in main()'s
        # left-to-right validator tuple.
        dst = Path(self.tmp) / "docs" / "git-workflow"
        dst.mkdir(parents=True, exist_ok=True)
        (dst / "branch-strategy.md").write_bytes(b"\xff\xfe\x00\x81\x82 not-utf8 \x9c")
        self.assertIsNone(_hook.get_branch_pattern())  # no UnicodeDecodeError crash
        msg = _hook.validate_branch("git checkout -b release/x")
        self.assertIsNotNone(msg)
        self.assertIn("fail-open", msg)
        # main() must still exit 0 AND still run commit validation (not aborted mid-tuple)
        out, rc = run_hook(
            {"tool_name": "Bash",
             "tool_input": {"command": 'git checkout -b release/x && git commit -m "add x"'}},
            cwd=self.tmp,
        )
        self.assertEqual(rc, 0)
        self.assertIn("fail-open", out)
        self.assertIn("Conventional Commits", out)  # commit validator still ran

    def test_utf8_strategy_read_under_non_utf8_locale(self):
        # codex (qg iter2): open() used the platform default encoding, so a VALID
        # UTF-8 strategy file with non-ASCII (Korean — devbrew is Korean-primary)
        # text fails to decode on a non-UTF-8 locale (e.g. LANG=C in CI/Docker),
        # quietly fail-opening a correctly-declared strategy. encoding="utf-8"
        # must read it regardless of locale.
        dst = Path(self.tmp) / "docs" / "git-workflow"
        dst.mkdir(parents=True, exist_ok=True)
        (dst / "branch-strategy.md").write_text(
            "# 브랜치 전략\n\n소문자만 허용합니다.\n\n"
            "```regex\n^(feature|fix)/[a-z0-9][a-z0-9.-]*$\n```\n",
            encoding="utf-8",
        )
        # Force an ASCII default encoding in the subprocess (defeat PEP 538/540
        # coercion so the locale default is genuinely non-UTF-8).
        out, rc = run_hook(
            {"tool_name": "Bash", "tool_input": {"command": "git checkout -b Bad_Name"}},
            env_override={"LC_ALL": "C", "LANG": "C",
                          "PYTHONUTF8": "0", "PYTHONCOERCECLOCALE": "0"},
            cwd=self.tmp,
        )
        self.assertEqual(rc, 0)
        # The Korean file decoded → its pattern applied → Bad_Name violates it.
        # Under the bug the file fails to decode → fail-open, so neither holds.
        self.assertIn("does not follow naming convention", out)
        self.assertNotIn("fail-open", out)


class F1RegressionLockTest(unittest.TestCase):
    """AC2 — DEFAULT_BRANCH_PATTERN must stay deleted (no silent GitHub-Flow default)."""

    def test_default_branch_pattern_symbol_removed(self):
        self.assertFalse(
            hasattr(_hook, "DEFAULT_BRANCH_PATTERN"),
            "DEFAULT_BRANCH_PATTERN reintroduced — GitHub-Flow default fallback is back",
        )


class PreservedBehaviorTest(_ProjectDirTestCase):
    """AC7 — commit / kill-switch / non-Bash / malformed-JSON paths unchanged."""

    def test_protected_branch_skipped(self):
        self.assertIsNone(_hook.validate_branch("git checkout -b main"))

    def test_conventional_commit_passes(self):
        self.assertIsNone(_hook.validate_commit('git commit -m "feat: add thing"'))

    def test_non_conventional_commit_flagged(self):
        msg = _hook.validate_commit('git commit -m "add thing"')
        self.assertIsNotNone(msg)
        self.assertIn("Conventional Commits", msg)

    def test_kill_switch_disable(self):
        out, rc = run_hook(
            {"tool_name": "Bash", "tool_input": {"command": "git checkout -b Bad_Name"}},
            env_override={"DEVBREW_PROJECT_INIT_DISABLE": "1"},
        )
        self.assertEqual(out.strip(), "{}")
        self.assertEqual(rc, 0)

    def test_non_bash_tool_skipped(self):
        out, rc = run_hook({"tool_name": "Write", "tool_input": {"file_path": "x"}})
        self.assertEqual(out.strip(), "{}")
        self.assertEqual(rc, 0)

    def test_malformed_json_stdin(self):
        env = os.environ.copy()
        for k in list(env):
            if k.startswith("DEVBREW_"):
                del env[k]
        cp = subprocess.run(
            [sys.executable, str(HOOK)], input="not json",
            capture_output=True, text=True, env=env, timeout=10,
        )
        self.assertEqual(cp.stdout.strip(), "{}")
        self.assertEqual(cp.returncode, 0)


class DerivePrefixesTest(unittest.TestCase):
    """F2 / AC4 / AC5 — extract prefixes from leading identifier-alternation only."""

    def test_github_flow(self):
        pat = re.compile(r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$")
        self.assertEqual(_hook.derive_prefixes(pat), ["feature", "fix"])

    def test_git_flow(self):
        pat = re.compile(r"^(feature|fix|release|hotfix)/[a-z0-9][a-z0-9.-]*$")
        self.assertEqual(_hook.derive_prefixes(pat), ["feature", "fix", "release", "hotfix"])

    def test_non_capturing_group(self):
        pat = re.compile(r"^(?:feature|fix)/[a-z0-9].*$")
        self.assertEqual(_hook.derive_prefixes(pat), ["feature", "fix"])

    def test_inline_flag_group_not_misparsed(self):
        # (?i) inline flag must NOT yield ["i"] — reviewer a909f052
        pat = re.compile(r"(?i)^(feature|fix)/[a-z0-9].*$")
        self.assertEqual(_hook.derive_prefixes(pat), [])

    def test_nested_group(self):
        pat = re.compile(r"^((?:a|b))/[a-z0-9].*$")
        self.assertEqual(_hook.derive_prefixes(pat), [])

    def test_literal_prefix(self):
        pat = re.compile(r"^feature-.*$")
        self.assertEqual(_hook.derive_prefixes(pat), [])


class F2SuggestionTest(_ProjectDirTestCase):
    """F2 / AC4 / AC5 — correction suggestion derived from active pattern."""

    def test_gitflow_violation_lists_derived_prefixes_no_feature_hardcode(self):
        write_strategy(self.tmp, r"^(feature|fix|release|hotfix)/[a-z0-9][a-z0-9.-]*$")
        msg = _hook.validate_branch("git checkout -b hotfix-login")
        self.assertIsNotNone(msg)
        self.assertIn("release", msg)
        self.assertIn("hotfix", msg)
        self.assertNotIn("feature/hotfix-login", msg)   # no hardcoded feature/ suggestion
        self.assertIn("<prefix>/hotfix-login", msg)      # placeholder, not a single prefix
        self.assertIn("Allowed prefixes: feature, fix, release, hotfix", msg)  # body-unique teeth (not header-satisfiable)

    def test_exotic_pattern_degrades_to_doc(self):
        write_strategy(self.tmp, r"^feature-.*$")  # literal prefix -> exotic -> []
        msg = _hook.validate_branch("git checkout -b bad")
        self.assertIsNotNone(msg)
        self.assertNotIn("git branch -m", msg)  # cmd is None for exotic
        self.assertIn("docs/git-workflow/branch-strategy.md", msg)


class MainDoubleValidationTest(unittest.TestCase):
    """AC10 / §5.5 — main() runs BOTH validators (no `or` short-circuit)."""

    def test_compound_failopen_runs_both_validators(self):
        tmp = tempfile.mkdtemp()  # no strategy file -> branch fails open
        try:
            payload = {
                "tool_name": "Bash",
                "tool_input": {
                    "command": 'git checkout -b feat && git commit -m "add thing"'
                },
            }
            out, rc = run_hook(payload, cwd=tmp)
            self.assertEqual(rc, 0)
            data = json.loads(out)
            msg = data.get("systemMessage", "")
            self.assertIn("fail-open", msg)             # branch validator ran
            self.assertIn("Conventional Commits", msg)  # commit validator ALSO ran (not short-circuited)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_valid_branch_bad_commit_still_flags_commit(self):
        tmp = tempfile.mkdtemp()
        write_strategy(tmp, r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$")
        try:
            payload = {
                "tool_name": "Bash",
                "tool_input": {
                    "command": 'git checkout -b feature/ok && git commit -m "add thing"'
                },
            }
            out, rc = run_hook(payload, cwd=tmp)
            data = json.loads(out)
            msg = data.get("systemMessage", "")
            self.assertNotIn("naming convention", msg)  # branch OK -> no branch warning
            self.assertIn("Conventional Commits", msg)   # commit flagged independently
            self.assertEqual(rc, 0)  # non-blocking: hook always exits 0 for compound shape too
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_both_clean_emits_empty(self):
        tmp = tempfile.mkdtemp()
        write_strategy(tmp, r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$")
        try:
            payload = {
                "tool_name": "Bash",
                "tool_input": {
                    "command": 'git checkout -b feature/ok && git commit -m "feat: ok"'
                },
            }
            out, rc = run_hook(payload, cwd=tmp)
            self.assertEqual(out.strip(), "{}")
            self.assertEqual(rc, 0)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
