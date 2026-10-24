"""Branch-prefix templates derive from the chosen strategy (AC33)."""
import importlib.util
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

PLUGIN = Path(__file__).resolve().parents[1]
HOOK = PLUGIN / "hooks" / "post-tool-use.py"
SKILL = PLUGIN / "skills" / "project-init" / "SKILL.md"
TEMPLATES = PLUGIN / "templates"
STRATEGIES = ["github-flow", "git-flow", "trunk-based"]

_spec = importlib.util.spec_from_file_location("post_tool_use_hook", HOOK)
assert _spec is not None and _spec.loader is not None
_hook = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_hook)


def read(path):
    return Path(path).read_text(encoding="utf-8")


def strategy_doc(s):
    return read(TEMPLATES / s / "branch-strategy.md")


def agents_section(s):
    return read(TEMPLATES / s / "agents-md-section.md")


def defaults_from_skill():
    lines = [
        ln for ln in read(SKILL).splitlines() if ln.startswith("**전략별 기본 접두**")
    ]
    assert len(lines) == 1, lines
    out = {}
    for s in STRATEGIES:
        m = re.search(re.escape(s) + r": `([^`]+)`", lines[0])
        assert m, s
        out[s] = m.group(1).split(", ")
    return out


def render(strategy, extras):
    names = []
    for n in defaults_from_skill()[strategy] + list(extras):
        if n not in names:
            names.append(n)
    text = strategy_doc(strategy)
    text = text.replace("{{BRANCH_PREFIXES}}", "|".join(names))
    text = text.replace("{{BRANCH_PREFIX_LIST}}", " · ".join("`%s/*`" % n for n in names))
    extra_names = [n for n in extras if n not in defaults_from_skill()[strategy]]
    text = text.replace(
        "{{EXTRA_PREFIX_LIST}}",
        " · ".join("`%s/*`" % n for n in extra_names) if extra_names else "없음",
    )
    return text


class HookEnv(object):
    """A temp clone whose default branch (origin/HEAD) holds the rendered doc."""

    def __init__(self, strategy, extras):
        self.strategy = strategy
        self.extras = extras

    def _git(self, *args, cwd=None):
        env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
        subprocess.run(
            ["git", "-c", "user.name=t", "-c", "user.email=t@example.com", *args],
            cwd=cwd, env=env, check=True, capture_output=True,
        )

    def __enter__(self):
        self.tmp = tempfile.TemporaryDirectory()
        src = Path(self.tmp.name) / "src"
        d = src / "docs" / "git-workflow"
        d.mkdir(parents=True)
        (d / "branch-strategy.md").write_text(
            render(self.strategy, self.extras), encoding="utf-8"
        )
        self._git("init", "-q", str(src))
        self._git("add", "-A", cwd=str(src))
        self._git("commit", "-q", "-m", "init", cwd=str(src))
        self.work = str(Path(self.tmp.name) / "work")
        self._git("clone", "-q", str(src), self.work)
        return self

    def pattern(self):
        return _hook.get_branch_pattern(self.work)

    def __exit__(self, *exc):
        self.tmp.cleanup()


class BranchPrefixTemplateTests(unittest.TestCase):
    def test_regex_fence_is_the_placeholder(self):
        for s in STRATEGIES:
            doc = strategy_doc(s)
            fences = re.findall(r"```regex\n(.*?)\n```", doc, re.S)
            self.assertEqual(
                fences, ["^({{BRANCH_PREFIXES}})/[a-z0-9][a-z0-9.-]*$"], s
            )
            self.assertNotIn("^(feature|fix", doc, s)

    def test_hook_derives_defaults(self):
        for s in STRATEGIES:
            with HookEnv(s, []) as env:
                self.assertEqual(
                    _hook.derive_prefixes(env.pattern()),
                    defaults_from_skill()[s],
                    s,
                )

    def test_hook_derives_added_prefixes(self):
        for s in STRATEGIES:
            with HookEnv(s, ["docs", "chore"]) as env:
                self.assertEqual(
                    _hook.derive_prefixes(env.pattern()),
                    defaults_from_skill()[s] + ["docs", "chore"],
                    s,
                )
                self.assertIsNone(_hook.check_branch_name("docs/readme-fix", env.pattern()), s)
            with HookEnv(s, []) as env:
                self.assertIsNotNone(_hook.check_branch_name("docs/readme-fix", env.pattern()), s)

    def test_skill_prefix_rule_matches_hook(self):
        text = read(SKILL)
        step3 = text.split("### Step 3: ", 1)[1].split("### Step 3.5", 1)[0]
        rules = [r for r in re.findall(r"`([^`]+)`", step3) if r.startswith("[a-z]")]
        self.assertEqual(len(set(rules)), 1, rules)
        rule = rules[0]
        samples = ["docs", "chore-x", "a1", "Docs", "docs/x", "1fix", "do_cs", ""]
        for t in samples:
            derived = _hook.derive_prefixes(re.compile("^(feature|" + t + ")/x$"))
            self.assertEqual(bool(re.fullmatch(rule, t)), t in derived, repr(t))

    def test_prose_uses_derived_list(self):
        for s in STRATEGIES:
            self.assertIn("{{BRANCH_PREFIX_LIST}}", agents_section(s), s)
            self.assertIn("{{EXTRA_PREFIX_LIST}}", strategy_doc(s), s)
            rules = strategy_doc(s).split("## Rules for Claude", 1)[1]
            self.assertNotIn("`feature/*` 또는 `fix/*` 브랜치 명명 사용", rules, s)

    def test_branch_check_only_for_change_work(self):
        for s in STRATEGIES:
            doc = strategy_doc(s)
            self.assertNotIn("**ALWAYS** 작업 시작 전 현재 브랜치 확인", doc, s)
            hits = [
                ln
                for ln in doc.splitlines()
                if "변경 작업" in ln and "git branch --show-current" in ln
            ]
            self.assertEqual(len(hits), 1, s)

    def test_worktree_path_same_rule(self):
        for s in STRATEGIES:
            doc = strategy_doc(s)
            self.assertIn("### Working in a worktree", doc, s)
            sec = doc.split("### Working in a worktree", 1)[1]
            sec = re.split(r"\n#{2,3} ", sec, 1)[0]
            for needle in [
                "git worktree add",
                "Branch Naming Pattern",
                "git worktree add -b",
                "git push -u origin",
            ]:
                self.assertIn(needle, sec, (s, needle))
            self.assertIn("reflog", sec, s)
            self.assertIn("`git worktree add -b` 로 만든 이름을 모두 확인한다", sec, s)
            self.assertNotIn("확인하지 않는다", sec, s)
            self.assertNotIn("만 확인한다", sec, s)

    def test_defaults_match_prefix_table(self):
        for s in STRATEGIES:
            table = strategy_doc(s).split("## Branch Prefixes", 1)[1].split("\n\n- ", 1)[0]
            rows = re.findall(r"^\| `([a-z][a-z0-9-]*)/<", table, re.M)
            self.assertEqual(rows, defaults_from_skill()[s], s)

    def test_4d_branch_strategy_item_substitutes_placeholders(self):
        sec = read(SKILL).split("#### 4d:", 1)[1].split("#### 4e:", 1)[0]
        items = [ln for ln in sec.splitlines() if ln.startswith("1. ")]
        self.assertEqual(len(items), 1)
        self.assertIn("placeholder 치환", items[0])


if __name__ == "__main__":
    unittest.main()
