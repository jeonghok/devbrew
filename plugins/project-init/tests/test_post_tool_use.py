"""Unit tests for plugins/project-init/hooks/post-tool-use.py."""
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from typing import Optional, Tuple, Union

HOOK = Path(__file__).resolve().parent.parent / "hooks" / "post-tool-use.py"

# The hook filename has a hyphen, so it is not importable by name. Load it via
# importlib (side-effect-free: post-tool-use.py guards execution behind
# `if __name__ == "__main__":`) so tests couple to the REAL functions/constants
# rather than parallel literal copies.
_spec = importlib.util.spec_from_file_location("post_tool_use_hook", HOOK)
assert _spec is not None and _spec.loader is not None, f"could not load hook module from {HOOK}"
_hook = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_hook)

GIT_ENV = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")


def git(*args: str, cwd: Optional[str] = None) -> None:
    subprocess.run(
        ["git", "-c", "user.name=t", "-c", "user.email=t@example.com",
         "-c", "init.defaultBranch=main", *args],
        cwd=cwd, env=GIT_ENV, check=True, capture_output=True,
    )


def strategy(regex_block: Optional[str]) -> str:
    """branch-strategy.md text.

    regex_block is None  -> file with NO ```regex fence (regex-less).
    regex_block == ""    -> file with an EMPTY ```regex fence (degenerate).
    otherwise            -> file with a ```regex fence containing regex_block.
    """
    if regex_block is None:
        return "# Branch Strategy\n\nNo regex fence here.\n"
    return f"# Branch Strategy\n\n```regex\n{regex_block}\n```\n"


def make_repo(root: str, content: Union[str, bytes, None], origin_head: bool = True) -> str:
    """Commit the strategy file on the origin's default branch, clone it, return the clone.

    content None -> no strategy file on the default branch.
    """
    src, work = os.path.join(root, "src"), os.path.join(root, "work")
    git("init", "-q", src)
    if content is not None:
        d = Path(src, "docs", "git-workflow")
        d.mkdir(parents=True)
        data = content if isinstance(content, bytes) else content.encode("utf-8")
        (d / "branch-strategy.md").write_bytes(data)
    Path(src, "README").write_text("x\n", encoding="utf-8")
    git("add", "-A", cwd=src)
    git("commit", "-q", "-m", "init", cwd=src)
    git("clone", "-q", src, work)
    if not origin_head:
        git("remote", "set-head", "origin", "-d", cwd=work)
    return work


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


class _RepoTestCase(unittest.TestCase):
    """Base: a fresh temp root per test for repo fixtures."""

    def setUp(self) -> None:
        self.tmp = tempfile.mkdtemp()

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def repo(self, content: Union[str, bytes, None], origin_head: bool = True) -> str:
        return make_repo(self.tmp, content, origin_head)

    def observe_after_branch(self, work: str, name: str) -> list:
        git("branch", name, cwd=work)
        return _hook.observe_branches(work, time.time())

    def assert_one_fail_open(self, results: list) -> str:
        self.assertEqual(len(results), 1, results)
        msg, model = results[0]
        self.assertIn("fail-open", msg)
        self.assertIn("브랜치 이름 검사를 건너뛴다", msg)
        self.assertIsNone(model)
        return msg


class F1FailOpenTest(_RepoTestCase):
    """F1 / LD2 — no valid declared pattern on the default branch => fail OPEN, loudly (AC1)."""

    def test_file_absent_fails_open(self):
        work = self.repo(None)
        self.assertIsNone(_hook.get_branch_pattern(work))
        self.assert_one_fail_open(self.observe_after_branch(work, "release/x"))

    def test_regexless_file_fails_open(self):
        work = self.repo(strategy(None))
        self.assertIsNone(_hook.get_branch_pattern(work))
        self.assert_one_fail_open(self.observe_after_branch(work, "release/x"))

    def test_malformed_regex_fails_open(self):
        work = self.repo(strategy("^(feature|fix"))  # unbalanced paren -> re.error
        self.assertIsNone(_hook.get_branch_pattern(work))
        self.assert_one_fail_open(self.observe_after_branch(work, "whatever"))

    def test_empty_regex_fence_fails_open(self):
        work = self.repo(strategy(""))  # ```regex\n\n``` -> search regex can't capture
        self.assertIsNone(_hook.get_branch_pattern(work))
        self.assert_one_fail_open(self.observe_after_branch(work, "release/x"))

    def test_whitespace_only_regex_fence_fails_open(self):
        # ```regex\n   \n``` -> captures "   " -> .strip() empty -> guard -> None.
        # Must NOT become re.compile("") which would silently pass EVERY branch.
        work = self.repo(strategy("   "))
        self.assertIsNone(_hook.get_branch_pattern(work))
        self.assert_one_fail_open(self.observe_after_branch(work, "anything-goes"))

    def test_no_default_ref_fails_open(self):
        # 기본 ref(origin/HEAD) 없음 — 규칙 파일이 있어도 어느 판인지 몰라 건너뛰고, 따로 알린다.
        work = self.repo(strategy(r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$"), origin_head=False)
        self.assertIsNone(_hook.get_branch_pattern(work))
        msg = self.assert_one_fail_open(self.observe_after_branch(work, "Bad"))
        self.assertIn("기본 브랜치(origin/HEAD)를 찾지 못해", msg)
        self.assertIn("git remote set-head origin --auto", msg)

    def test_no_origin_remote_fails_open(self):
        # origin 원격 자체가 없으면 set-head 를 권하지 않고 그 사실을 알린다.
        work = self.repo(strategy(r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$"))
        git("remote", "remove", "origin", cwd=work)
        msg = self.assert_one_fail_open(self.observe_after_branch(work, "Bad"))
        self.assertIn("`origin` 원격이 없어", msg)
        self.assertNotIn("set-head", msg)

    def test_working_tree_rule_is_not_read(self):
        work = self.repo(None)
        d = Path(work, "docs", "git-workflow")
        d.mkdir(parents=True)
        (d / "branch-strategy.md").write_text(
            strategy(r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$"), encoding="utf-8")
        self.assertIsNone(_hook.get_branch_pattern(work))

    def test_declared_gitflow_pattern_respected(self):
        # AC3: a declared pattern is honored; release/* passes, no fail-open.
        work = self.repo(strategy(r"^(feature|fix|release|hotfix)/[a-z0-9][a-z0-9.-]*$"))
        pat = _hook.get_branch_pattern(work)
        self.assertIsNotNone(pat)
        self.assertIsNone(_hook.check_branch_name("release/v1.2", pat))
        self.assertEqual(self.observe_after_branch(work, "release/v1.2"), [])

    def test_non_utf8_strategy_file_fails_open(self):
        # 5th malformed case (qg-security + adversarial): a non-UTF-8/binary
        # branch-strategy.md must fail OPEN (loud advisory), never crash — this
        # preserves the always-exit-0 advisory contract AND must not let a
        # rule-read crash silently defeat commit validation in main().
        work = self.repo(b"\xff\xfe\x00\x81\x82 not-utf8 \x9c")
        self.assertIsNone(_hook.get_branch_pattern(work))  # no UnicodeDecodeError crash
        self.assert_one_fail_open(self.observe_after_branch(work, "release/x"))
        # main() must still exit 0 AND still run commit validation
        out, rc = run_hook(
            {"tool_name": "Bash",
             "tool_input": {"command": 'git checkout -b release/x && git commit -m "add x"'}},
            cwd=work,
        )
        self.assertEqual(rc, 0)
        self.assertIn("fail-open", out)
        self.assertIn("Conventional Commits", out)  # commit validator still ran

    def test_utf8_strategy_read_under_non_utf8_locale(self):
        # codex (qg iter2): a VALID UTF-8 strategy file with non-ASCII (Korean —
        # devbrew is Korean-primary) text must decode on a non-UTF-8 locale
        # (e.g. LANG=C in CI/Docker) instead of quietly fail-opening.
        work = self.repo(
            "# 브랜치 전략\n\n소문자만 허용합니다.\n\n"
            "```regex\n^(feature|fix)/[a-z0-9][a-z0-9.-]*$\n```\n")
        git("branch", "Bad_Name", cwd=work)
        # Force an ASCII default encoding in the subprocess (defeat PEP 538/540
        # coercion so the locale default is genuinely non-UTF-8).
        out, rc = run_hook(
            {"tool_name": "Bash", "tool_input": {"command": "git branch Bad_Name"}},
            env_override={"LC_ALL": "C", "LANG": "C",
                          "PYTHONUTF8": "0", "PYTHONCOERCECLOCALE": "0"},
            cwd=work,
        )
        self.assertEqual(rc, 0)
        self.assertIn("이름 규칙에 맞지 않는다", json.loads(out).get("systemMessage", ""))
        self.assertNotIn("fail-open", out)


class F1RegressionLockTest(unittest.TestCase):
    """AC2 — DEFAULT_BRANCH_PATTERN must stay deleted (no silent GitHub-Flow default)."""

    def test_default_branch_pattern_symbol_removed(self):
        self.assertFalse(
            hasattr(_hook, "DEFAULT_BRANCH_PATTERN"),
            "DEFAULT_BRANCH_PATTERN reintroduced — GitHub-Flow default fallback is back",
        )

    def test_command_regex_removed(self):
        # RC82 — 브랜치는 명령 문자열이 아니라 실행 뒤 reflog 로 본다.
        self.assertFalse(hasattr(_hook, "BRANCH_CREATE_RE"))
        self.assertFalse(hasattr(_hook, "validate_branch"))


class PreservedBehaviorTest(_RepoTestCase):
    """AC7 — commit / kill-switch / non-Bash / malformed-JSON paths unchanged."""

    def test_protected_branch_skipped(self):
        self.assertIsNone(_hook.check_branch_name("main", re.compile(r"^feature/.+$")))

    def test_conventional_commit_passes(self):
        self.assertIsNone(_hook.validate_commit('git commit -m "feat: add thing"'))

    def test_korean_description_passes(self):
        """커밋 설명이 한국어인 레포(devbrew CLAUDE.md 규칙) — 정규식은 type 만 본다."""
        self.assertIsNone(_hook.validate_commit('git commit -m "fix(qg): 범위 경고를 쉬운 말로"'))

    def test_non_conventional_commit_flagged(self):
        msg, _model = _hook.validate_commit('git commit -m "add thing"')
        self.assertIsNotNone(msg)
        self.assertIn("Conventional Commits", msg)

    def test_kill_switch_disable(self):
        work = self.repo(strategy(r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$"))
        git("branch", "Bad_Name", cwd=work)
        out, rc = run_hook(
            {"tool_name": "Bash", "tool_input": {"command": "git branch Bad_Name"}},
            env_override={"DEVBREW_PROJECT_INIT_DISABLE": "1"}, cwd=work,
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


class F2SuggestionTest(unittest.TestCase):
    """F2 / AC4 / AC5 — correction suggestion derived from active pattern."""

    def test_gitflow_violation_lists_derived_prefixes_no_feature_hardcode(self):
        pat = re.compile(r"^(feature|fix|release|hotfix)/[a-z0-9][a-z0-9.-]*$")
        msg, model = _hook.check_branch_name("hotfix-login", pat)
        self.assertIsNotNone(msg)
        self.assertIn("release", msg)
        self.assertIn("hotfix", msg)
        self.assertNotIn("feature/hotfix-login", msg)   # no hardcoded feature/ suggestion
        self.assertIn("허용 접두어: feature, fix, release, hotfix", msg)  # body-unique teeth (not header-satisfiable)
        # model half must be self-contained: a runnable command naming the observed
        # branch (it may not be the current one) and the derived prefix, plus the full
        # prefix list — never a dangling <prefix>/"above" pointer
        self.assertIn("git branch -m hotfix-login feature/hotfix-login", model)
        self.assertIn("Allowed prefixes: feature, fix, release, hotfix", model)
        self.assertNotIn("<prefix>", model)
        self.assertNotIn("above", model.lower())

    def test_shell_metacharacters_in_name_are_quoted(self):
        pat = re.compile(r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$")
        _msg, model = _hook.check_branch_name("a;touch_x", pat)
        self.assertIn("git branch -m 'a;touch_x' 'feature/a;touch_x'", model)

    def test_exotic_pattern_degrades_to_doc(self):
        msg, model = _hook.check_branch_name("bad", re.compile(r"^feature-.*$"))  # literal prefix -> exotic -> []
        self.assertIsNotNone(msg)
        self.assertNotIn("git branch -m", msg)  # cmd is None for exotic
        self.assertIsNone(model)
        self.assertIn("허용 접두어는 docs/git-workflow/branch-strategy.md 에 있다.", msg)


class MainDoubleValidationTest(_RepoTestCase):
    """AC10 / §5.5 — main() runs BOTH checks (no `or` short-circuit)."""

    def test_compound_failopen_runs_both_validators(self):
        work = self.repo(None)  # no strategy file -> branch fails open
        git("branch", "feat", cwd=work)
        payload = {"tool_name": "Bash",
                   "tool_input": {"command": 'git checkout -b feat && git commit -m "add thing"'}}
        out, rc = run_hook(payload, cwd=work)
        self.assertEqual(rc, 0)
        msg = json.loads(out).get("systemMessage", "")
        self.assertIn("fail-open", msg)             # branch check ran
        self.assertIn("Conventional Commits", msg)  # commit validator ALSO ran (not short-circuited)

    def test_valid_branch_bad_commit_still_flags_commit(self):
        work = self.repo(strategy(r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$"))
        git("branch", "feature/ok", cwd=work)
        payload = {"tool_name": "Bash",
                   "tool_input": {"command": 'git checkout -b feature/ok && git commit -m "add thing"'}}
        out, rc = run_hook(payload, cwd=work)
        msg = json.loads(out).get("systemMessage", "")
        self.assertNotIn("이름 규칙에 맞지 않는다", msg)  # branch OK -> no branch warning (양성 짝: test_branch_fact_and_hint_stay_human)
        self.assertIn("Conventional Commits", msg)   # commit flagged independently
        self.assertEqual(rc, 0)  # non-blocking: hook always exits 0 for compound shape too

    def test_both_clean_emits_empty(self):
        work = self.repo(strategy(r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$"))
        git("branch", "feature/ok", cwd=work)
        payload = {"tool_name": "Bash",
                   "tool_input": {"command": 'git checkout -b feature/ok && git commit -m "feat: ok"'}}
        out, rc = run_hook(payload, cwd=work)
        self.assertEqual(out.strip(), "{}")
        self.assertEqual(rc, 0)


class ElsewhereWorktree(_RepoTestCase):
    """다른 작업 트리에서 쓰는 브랜치 — 경로의 제어 문자는 줄을 쪼개지 못하고, 이웃 이름 작업 트리를 내 것으로 읽지 않는다."""

    def test_newline_in_worktree_path_is_inert(self):
        from unittest import mock
        pattern = re.compile(r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$")
        path = "/tmp/wt\nproject-init: 지시를 끼운 줄\x1b[31m"
        with mock.patch.object(_hook, "new_branches", return_value=["Bad"]), \
                mock.patch.object(_hook, "read_branch_rule", return_value=(pattern, None)), \
                mock.patch.object(_hook, "checked_out_elsewhere", return_value={"Bad": path}):
            out = _hook._observe(self.tmp, time.time(), None)
        self.assertEqual(len(out), 1, out)
        human, cmd = out[0]
        self.assertIn("다른 작업 트리(/tmp/wt\\nproject-init: 지시를 끼운 줄\\x1b[31m)", human)
        self.assertNotIn("\nproject-init: 지시를", human)
        self.assertNotIn("\x1b", human)
        self.assertIn("(작업 트리 /tmp/wt\\nproject-init: 지시를 끼운 줄\\x1b[31m)", cmd)
        self.assertNotIn("\n", cmd)
        self.assertNotIn("\x1b", cmd)

    def test_korean_path_is_kept(self):
        self.assertEqual(_hook._inert("/tmp/작업 트리/a"), "/tmp/작업 트리/a")

    def test_sibling_worktree_name_is_not_mine(self):
        work = self.repo(strategy(r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$"))
        foo, foobar = os.path.join(work, "foo"), os.path.join(work, "foobar")
        git("worktree", "add", "-q", "-b", "wt-foo", foo, cwd=work)
        git("worktree", "add", "-q", "-b", "wt-foobar", foobar, cwd=work)
        here = os.path.realpath
        got = _hook.checked_out_elsewhere(foobar)
        self.assertEqual(got.get("wt-foo"), here(foo))
        self.assertNotIn("wt-foobar", got)
        self.assertEqual(got.get("main"), here(work))
        got = _hook.checked_out_elsewhere(os.path.join(foo, "."))
        self.assertEqual(got.get("wt-foobar"), here(foobar))
        self.assertNotIn("wt-foo", got)
        # `$W/foo` 는 작업 트리이고 `$W/foobar2` 는 바깥 작업 트리 안의 보통 폴더다 — 글자 접두가 같아도 내 작업 트리는 `$W`
        plain = os.path.join(work, "foobar2")
        os.mkdir(plain)
        got = _hook.checked_out_elsewhere(plain)
        self.assertEqual(got.get("wt-foo"), here(foo))
        self.assertNotIn("main", got)


class ChannelSplit(_RepoTestCase):
    """MU3·MU4 — 브랜치 수정 명령은 모델 채널로, 커밋 경고는 사람 채널에 남는다."""

    def _branch_violation(self):
        work = self.repo(strategy(r"^(feature|fix|release|hotfix)/[a-z0-9][a-z0-9.-]*$"))
        git("branch", "BadName", cwd=work)
        payload = {"tool_name": "Bash", "tool_input": {"command": "git branch BadName"}}
        out, rc = run_hook(payload, cwd=work)
        self.assertEqual(rc, 0)
        return json.loads(out)

    def test_branch_fix_command_goes_to_model_channel(self):
        data = self._branch_violation()
        ac = data.get("hookSpecificOutput", {}).get("additionalContext", "")
        self.assertEqual(data.get("hookSpecificOutput", {}).get("hookEventName"), "PostToolUse")
        self.assertIn("git branch -m BadName ", ac, "수정 명령이 모델 채널에 없다")
        self.assertIn("Allowed prefixes: feature, fix, release, hotfix", ac,
                      "허용 prefix 목록이 모델 채널 자체에 없다 — 모델이 못 보는 사람 채널을 가리킨다")
        self.assertNotIn("<prefix>", ac, "모델 채널에 미치환 <prefix> placeholder가 남아 있다")
        self.assertNotIn("above", ac.lower(), "모델 채널이 자신은 못 보는 '위' 콘텐츠를 가리킨다")

    def test_branch_fact_and_hint_stay_human(self):
        """양성 증인 — 사람 채널이 여전히 사실과 기대 패턴을 싣는다."""
        sm = self._branch_violation().get("systemMessage", "")
        self.assertIn("이름 규칙에 맞지 않는다", sm)
        self.assertIn("기대하는 형식:", sm)
        self.assertIn("허용 접두어: feature, fix, release, hotfix", sm)
        self.assertNotIn("does not follow", sm, "옛 영어 경고가 사람 채널에 남았다")
        self.assertNotIn("git branch -m", sm, "수정 명령이 사람 채널에 남아 있다 — 채널이 갈리지 않았다")

    def test_commit_warning_stays_in_system_message(self):
        """MU4 — 커밋 경고는 자기 정규식에 재발동하므로 모델 채널로 보내지 않는다."""
        work = self.repo(strategy(r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$"))
        payload = {"tool_name": "Bash", "tool_input": {"command": 'git commit -m "add thing"'}}
        out, rc = run_hook(payload, cwd=work)
        self.assertEqual(rc, 0)
        data = json.loads(out)
        sm = data.get("systemMessage", "")
        self.assertIn("Conventional Commits", sm)
        self.assertIn("project-init: 커밋 메시지가 Conventional Commits 형식이 아니다.", sm)
        self.assertIn("형식: <type>(<scope>): <설명>", sm)
        self.assertIn("type: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert", sm)
        self.assertIn("제안: feat: add thing", sm)
        self.assertNotIn("Suggested:", sm, "옛 영어 제안 줄이 남았다")
        ac = data.get("hookSpecificOutput", {}).get("additionalContext", "")
        self.assertNotIn("Conventional Commits", ac, "커밋 경고가 모델 채널로 갔다 — 재진입 비대칭이 깨졌다")

    def test_clean_command_emits_neither_channel(self):
        work = self.repo(strategy(r"^(feature|fix)/[a-z0-9][a-z0-9.-]*$"))
        git("branch", "feature/ok", cwd=work)
        payload = {"tool_name": "Bash", "tool_input": {"command": "git branch feature/ok"}}
        out, rc = run_hook(payload, cwd=work)
        self.assertEqual(rc, 0)
        self.assertEqual(json.loads(out), {})


if __name__ == "__main__":
    unittest.main()
