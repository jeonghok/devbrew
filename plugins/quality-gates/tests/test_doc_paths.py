"""scripts/doc_paths.py — 리뷰 diff 에서 뺄 문서 경로 규칙(AC23).

포함 규칙이 먼저다: 문서 파일만 뺄 수 있고, 모델이 읽는 파일 · 코드는 패턴에 걸려도 남긴다.
"""
import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "doc_paths.py"
spec = importlib.util.spec_from_file_location("doc_paths", SCRIPT)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


def run_cli(args, env_extra=None, drop_env=True):
    env = os.environ.copy()
    if drop_env:
        env.pop(m.ENV_KEY, None)
    if env_extra:
        env.update(env_extra)
    return subprocess.run([sys.executable, str(SCRIPT)] + args,
                          capture_output=True, text=True, encoding="utf-8", env=env)


class TestSelect(unittest.TestCase):

    def test_default_excludes_readme_changelog_anywhere(self):
        ex, kept = m.select(["README.md", "plugins/x/README.md", "plugins/x/CHANGELOG.md",
                             "docs/a.md", "src/a.py"], list(m.DEFAULT_DOC_PATHS))
        self.assertEqual(ex, ["README.md", "plugins/x/README.md", "plugins/x/CHANGELOG.md"])
        self.assertEqual(kept, [])

    def test_docs_reviewed_by_default(self):
        ex, _ = m.select(["docs/git-workflow/branch-strategy.md"], list(m.DEFAULT_DOC_PATHS))
        self.assertEqual(ex, [])

    def test_model_read_kept_even_if_matched(self):
        paths = ["plugins/x/skills/y/SKILL.md", "plugins/x/agents/a.md", "CLAUDE.md",
                 "plugins/x/references/r.md", "docs/guide.md"]
        ex, kept = m.select(paths, ["**/*.md"])
        self.assertEqual(ex, ["docs/guide.md"])
        self.assertEqual(kept, paths[:4])

    def test_code_never_excluded(self):
        ex, kept = m.select(["src/a.py", "src/notes.md"], ["src/**"])
        self.assertEqual(ex, ["src/notes.md"])
        self.assertEqual(kept, ["src/a.py"])

    def test_unmatched_not_in_kept(self):
        ex, kept = m.select(["src/a.py", "lib/b.py"], ["README*"])
        self.assertEqual((ex, kept), ([], []))

    def test_extensionless_readme_is_doc(self):
        self.assertTrue(m.is_doc_file("README"))
        self.assertTrue(m.is_doc_file("a/CHANGELOG"))
        self.assertFalse(m.is_doc_file("Makefile"))
        self.assertTrue(m.is_doc_file("docs/a.rst"))

    def test_model_read_segments(self):
        for p in ["x/.claude/notes.md", "p/.claude-plugin/x.md", "p/hooks/readme.md",
                  "p/templates/t.md", "p/commands/c.md", "AGENTS.md", "a/b/SKILL.md"]:
            self.assertTrue(m.is_model_read(p), p)
        self.assertFalse(m.is_model_read("docs/agents-guide.md"))


class TestPatterns(unittest.TestCase):

    def test_env_unset_is_default(self):
        self.assertEqual(m.parse_patterns(None), (["README*", "CHANGELOG*"], [], "default"))

    def test_env_set_empty_excludes_nothing(self):
        self.assertEqual(m.parse_patterns(""), ([], [], "env"))
        self.assertEqual(m.parse_patterns(" , "), ([], [], "env"))

    def test_env_replaces_defaults(self):
        pats, bad, src = m.parse_patterns("docs/drafts/**")
        self.assertEqual((pats, bad, src), (["docs/drafts/**"], [], "env"))
        ex, _ = m.select(["README.md", "docs/drafts/a.md"], pats)
        self.assertEqual(ex, ["docs/drafts/a.md"])

    def test_bad_pattern_disclosed(self):
        self.assertEqual(m.parse_patterns(":(exclude)x, !y, docs/*.md"),
                         (["docs/*.md"], [":(exclude)x", "!y"], "env"))
        pats, bad, _ = m.parse_patterns("a\tb, ok.md")
        self.assertEqual((pats, bad), (["ok.md"], ["a\tb"]))

    def test_uncompilable_pattern_disclosed(self):
        pats, bad, src = m.parse_patterns("[z-a]*.md, docs/*.md")
        self.assertEqual((pats, bad, src), (["docs/*.md"], ["[z-a]*.md"], "env"))

    def test_trailing_slash_is_whole_folder(self):
        self.assertTrue(m.matches("docs/", "docs/a.md"))
        self.assertTrue(m.matches("docs/", "docs/x/y.md"))
        self.assertFalse(m.matches("docs/", "docsx/a.md"))
        self.assertFalse(m.matches("docs/", "a/docs/b.md"))
        ex, _ = m.select(["docs/x/y.md", "src/a.md"], ["docs/"])
        self.assertEqual(ex, ["docs/x/y.md"])

    def test_select_agrees_with_matches(self):
        pats = ["README*", "/docs/*.md", "docs/", "**/*.rst", "a?.txt"]
        paths = ["README.md", "x/README.md", "docs/a.md", "docs/b/c.md", "x/docs/a.md",
                 "p/q.rst", "ab.txt", "x/ab.txt", "abc.txt"]
        for p in pats:
            ex, kept = m.select(paths, [p])
            self.assertEqual(sorted(ex + kept), sorted(x for x in paths if m.matches(p, x)), p)

    def test_glob_semantics(self):
        self.assertTrue(m.matches("docs/*.md", "docs/a.md"))
        self.assertFalse(m.matches("docs/*.md", "docs/x/a.md"))
        self.assertTrue(m.matches("docs/**/*.md", "docs/x/a.md"))
        self.assertTrue(m.matches("docs/**/*.md", "docs/a.md"))
        self.assertTrue(m.matches("README*", "a/b/README.md"))
        self.assertFalse(m.matches("README*", "a/READMEx/b.txt"))
        self.assertTrue(m.matches("docs/drafts/**", "docs/drafts/a/b.md"))
        self.assertFalse(m.matches("docs/drafts/**", "docs/draftsx/a.md"))
        self.assertTrue(m.matches("doc?.md", "x/docs.md"))
        self.assertFalse(m.matches("doc?.md", "x/doc.md"))
        self.assertTrue(m.matches("[!x]*.md", "a.md"))
        self.assertFalse(m.matches("[!x]*.md", "xa.md"))
        self.assertTrue(m.matches("a+b.md", "a+b.md"))
        self.assertFalse(m.matches("a+b.md", "aab.md"))

    def test_settings_changed(self):
        k = '{"env": {"DEVBREW_QUALITY_GATES_DOC_PATHS": "docs/**"}}'
        self.assertFalse(m.settings_key_changed(None, None))
        self.assertFalse(m.settings_key_changed(k, k))
        self.assertTrue(m.settings_key_changed(None, k))
        self.assertTrue(m.settings_key_changed('{"env": {}}', k))
        self.assertFalse(m.settings_key_changed('{"env": {"X": "1"}}', '{"env": {"X": "2"}}'))
        self.assertTrue(m.settings_key_changed("{not json", k))
        self.assertFalse(m.settings_key_changed(k, k.replace(" ", "")))


class TestCli(unittest.TestCase):

    def _names(self, d, paths):
        p = Path(d) / "names"
        p.write_text("".join(x + "\n" for x in paths), encoding="utf-8")
        return str(p)

    def test_cli_output_shape(self):
        with tempfile.TemporaryDirectory() as d:
            names = self._names(d, ["README.md", "src/a.py", "plugins/x/skills/s/README.md"])
            r = run_cli(["select", "--names", names, "--settings-base", d + "/nope1",
                         "--settings-head", d + "/nope2"])
            self.assertEqual(r.returncode, 0, r.stderr)
            lines = r.stdout.splitlines()
            self.assertEqual([ln.split(":", 1)[0] for ln in lines[:5]],
                             ["doc_paths_source", "doc_paths", "bad_patterns", "excluded", "kept_model"])
            self.assertEqual(lines[0], "doc_paths_source: default")
            self.assertEqual(lines[1], "doc_paths: README*,CHANGELOG*")
            self.assertEqual(lines[2], "bad_patterns: -")
            self.assertEqual(lines[3], "excluded: 1")
            self.assertEqual(lines[4], "kept_model: 1")
            self.assertEqual(lines[5:], ["exclude\tREADME.md", "kept\tplugins/x/skills/s/README.md"])

    def test_cli_env_empty_and_bad(self):
        with tempfile.TemporaryDirectory() as d:
            names = self._names(d, ["README.md"])
            r = run_cli(["select", "--names", names, "--settings-base", d + "/n1",
                         "--settings-head", d + "/n2"], env_extra={m.ENV_KEY: " , !x"})
            self.assertEqual(r.returncode, 0, r.stderr)
            lines = r.stdout.splitlines()
            self.assertEqual(lines[:4], ["doc_paths_source: env", "doc_paths: (없음)",
                                         "bad_patterns: !x", "excluded: 0"])

    def test_cli_settings_changed_falls_back(self):
        with tempfile.TemporaryDirectory() as d:
            names = self._names(d, ["README.md", "docs/x.md"])
            head = Path(d) / "head.json"
            head.write_text('{"env": {"%s": "docs/**"}}' % m.ENV_KEY, encoding="utf-8")
            r = run_cli(["select", "--names", names, "--settings-base", d + "/none",
                         "--settings-head", str(head)], env_extra={m.ENV_KEY: "docs/**"})
            self.assertEqual(r.returncode, 0, r.stderr)
            lines = r.stdout.splitlines()
            self.assertEqual(lines[0], "doc_paths_source: default-settings-changed")
            self.assertEqual(lines[1], "doc_paths: README*,CHANGELOG*")
            self.assertEqual(lines[5:], ["exclude\tREADME.md"])

    def test_cli_settings_local_changed_falls_back(self):
        with tempfile.TemporaryDirectory() as d:
            names = self._names(d, ["README.md", "docs/x.md"])
            head = Path(d) / "local-head.json"
            head.write_text('{"env": {"%s": "docs/**"}}' % m.ENV_KEY, encoding="utf-8")
            base_args = ["select", "--names", names, "--settings-base", d + "/s0",
                         "--settings-head", d + "/s1"]
            r = run_cli(base_args + ["--settings-local-base", d + "/l0",
                                     "--settings-local-head", str(head)],
                        env_extra={m.ENV_KEY: "docs/**"})
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertEqual(r.stdout.splitlines()[0], "doc_paths_source: default-settings-changed")
            # 양성 짝 — local 이 양쪽 같으면 환경 변수가 쓰인다.
            r = run_cli(base_args + ["--settings-local-base", str(head),
                                     "--settings-local-head", str(head)],
                        env_extra={m.ENV_KEY: "docs/**"})
            self.assertEqual(r.stdout.splitlines()[:2], ["doc_paths_source: env", "doc_paths: docs/**"])
            # local 인자는 둘이 함께
            r = run_cli(base_args + ["--settings-local-base", str(head)])
            self.assertEqual(r.returncode, 2)

    def test_cli_rc(self):
        with tempfile.TemporaryDirectory() as d:
            r = run_cli(["select", "--names", d + "/missing", "--settings-base", d + "/a",
                         "--settings-head", d + "/b"])
            self.assertEqual(r.returncode, 4)
            self.assertEqual(r.stdout, "")
            r = run_cli(["select", "--names", d + "/missing"])
            self.assertEqual(r.returncode, 2)
            r = run_cli(["bogus"])
            self.assertEqual(r.returncode, 2)


if __name__ == "__main__":
    unittest.main()
