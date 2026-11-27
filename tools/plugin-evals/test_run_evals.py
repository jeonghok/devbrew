"""run_evals.py 의 명령줄 · 종료 코드 · 요약 줄 · 평가 명령에 넘기는 환경을 잰다.

바깥 경계가 명령줄 · 종료 코드라 케이스마다 스크립트를 띄운다.
가짜 claude 는 설정을 환경이 아니라 옆의 fake.conf 에서 읽는다 — 스크립트가 넘기는 환경을 재야 해서다.
"""
import json
import os
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "run_evals.py")

FAKE_CLAUDE = """#!/bin/sh
. "$(dirname "$0")/fake.conf"
env > "$FAKE_ENV"
: > "$FAKE_ARGS"
for a in "$@"; do printf '%s\\n' "$a" >> "$FAKE_ARGS"; done
prev=""
for a in "$@"; do
  if [ "$prev" = "--json" ] && [ -n "$FAKE_RESULT" ]; then
    cp "$FAKE_RESULT" "$a"
  fi
  if [ "$prev" = "eval" ] && [ -n "$FAKE_LINKS" ]; then
    find "$a" -type l | wc -l > "$FAKE_LINKS"
    if [ -f "$a/linked.txt" ]; then cat "$a/linked.txt" > "$FAKE_LINKED"; fi
  fi
  prev="$a"
done
exit "${FAKE_RC:-0}"
"""

OUTSIDE_TEXT = "outside the plugin\n"


def _case(n_runs):
    return {"name": "c", "arms": {"with": [{"passed": True}] * n_runs}}


def _result(passed, cost, model, runs_per_case, partial=False):
    suite = {"modelOverride": model} if model else {}
    return {
        "partial": partial,
        "costUsd": cost,
        "suite": suite,
        "aggregates": {"casesPassed": passed, "casesTotal": 2},
        "cases": [_case(n) for n in runs_per_case],
    }


def _turns_result(passed, turns_per_case):
    data = _result(passed, 0.3, "sonnet", [0] * len(turns_per_case))
    for case, turns in zip(data["cases"], turns_per_case):
        case["arms"]["with"] = [
            {"passed": t > 0, "error": None, "turns": t} for t in turns]
    return data


class RunEvalsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = tempfile.mkdtemp(prefix="plugin evals.")
        cls.plugin = os.path.join(cls.root, "fake plugin")
        os.makedirs(os.path.join(cls.plugin, "tests", "evals"))
        outside = os.path.join(cls.root, "outside.txt")
        with open(outside, "w", encoding="utf-8") as f:
            f.write(OUTSIDE_TEXT)
        cls.link = os.path.join(cls.plugin, "linked.txt")
        os.symlink(outside, cls.link)
        cls.broken_plugin = os.path.join(cls.root, "broken plugin")
        os.makedirs(cls.broken_plugin)
        os.symlink(os.path.join(cls.root, "missing.txt"),
                   os.path.join(cls.broken_plugin, "dangling.txt"))
        cls.bin = os.path.join(cls.root, "bin")
        os.makedirs(cls.bin)
        fake = os.path.join(cls.bin, "claude")
        with open(fake, "w", encoding="utf-8") as f:
            f.write(FAKE_CLAUDE)
        os.chmod(fake, 0o755)
        cls.results = {}
        for name, data in (
            ("ok", _result(2, 0.5234, "sonnet", [3, 3])),
            ("fail", _result(1, 0.4, None, [3, 3])),
            ("partial", _result(0, 1.003, "sonnet", [1, 2], True)),
            ("zero_turns", _turns_result(0, [[0, 0], [0]])),
            ("one_zero_turn", _turns_result(1, [[0, 3], [3, 3]])),
        ):
            cls.results[name] = os.path.join(cls.root, name + ".json")
            with open(cls.results[name], "w", encoding="utf-8") as f:
                json.dump(data, f)
        no_cases = _result(0, 0.0, None, [])
        no_cases["aggregates"]["casesTotal"] = 0
        for name, data in (
            ("no_cases", no_cases),
            ("empty_runs", _result(0, 0.01, "sonnet", [0, 0], True)),
        ):
            cls.results[name] = os.path.join(cls.root, name + ".json")
            with open(cls.results[name], "w", encoding="utf-8") as f:
                json.dump(data, f)
        nokey = _result(2, 0.5, "sonnet", [3, 3])
        del nokey["aggregates"]
        cls.results["nokey"] = os.path.join(cls.root, "nokey.json")
        with open(cls.results["nokey"], "w", encoding="utf-8") as f:
            json.dump(nokey, f)
        cls.results["broken"] = os.path.join(cls.root, "broken.json")
        with open(cls.results["broken"], "w", encoding="utf-8") as f:
            f.write("{not json")
        cls.args_file = os.path.join(cls.root, "args.txt")
        cls.links_file = os.path.join(cls.root, "links.txt")
        cls.linked_file = os.path.join(cls.root, "linked-seen.txt")
        cls.env_file = os.path.join(cls.root, "env.txt")

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.root, ignore_errors=True)

    def setUp(self):
        for path in (self.args_file, self.links_file, self.linked_file,
                     self.env_file):
            if os.path.exists(path):
                os.remove(path)

    def run_script(self, extra, result=None, rc=0, with_bin=True,
                   plugin=None, cwd=None, inspect=False, extra_env=None):
        path = "/usr/bin:/bin"
        if with_bin:
            path = self.bin + ":" + path
        conf = {
            "FAKE_ARGS": self.args_file,
            "FAKE_ENV": self.env_file,
            "FAKE_RC": str(rc),
            "FAKE_RESULT": self.results[result] if result else "",
            "FAKE_LINKS": self.links_file if inspect else "",
            "FAKE_LINKED": self.linked_file if inspect else "",
        }
        with open(os.path.join(self.bin, "fake.conf"), "w",
                  encoding="utf-8") as f:
            for key, value in conf.items():
                f.write("%s=%s\n" % (key, shlex.quote(value)))
        env = {"PATH": path, "TMPDIR": self.root}
        env.update(extra_env or {})
        cmd = [sys.executable, SCRIPT, plugin or self.plugin] + extra
        return subprocess.run(
            cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            universal_newlines=True, cwd=cwd,
        )

    def fake_args(self):
        with open(self.args_file, encoding="utf-8") as f:
            return f.read().split("\n")[:-1]

    def last_line(self, p):
        return p.stdout.rstrip("\n").split("\n")[-1]

    def child_env(self):
        with open(self.env_file, encoding="utf-8") as f:
            return dict(line.split("=", 1) for line in f.read().splitlines()
                        if "=" in line)

    def test_env_drops_unlisted(self):
        unlisted = {
            "DEVBREW_FAKE_SECRET": "not-a-real-secret",
            "GITHUB_TOKEN": "not-a-real-token",
            "CLAUDE_CODE_MESSAGING_TOKEN": "not-a-real-token",
            "AWS_SECRET_ACCESS_KEY": "not-a-real-key",
            "GOOGLE_APPLICATION_CREDENTIALS": "/nowhere/creds.json",
            "AZURE_CLIENT_SECRET": "not-a-real-secret",
            "PYTHONPATH": "/nowhere",
        }
        p = self.run_script([], result="ok", extra_env=unlisted)
        self.assertEqual(p.returncode, 0)
        got = self.child_env()
        for name in unlisted:
            with self.subTest(name=name):
                self.assertNotIn(name, got)

    def test_env_passes_needed(self):
        needed = {
            "HOME": os.path.join(self.root, "home"),
            "USER": "someone",
            "LOGNAME": "someone",
            "SHELL": "/bin/zsh",
            "LANG": "ko_KR.UTF-8",
            "LC_ALL": "ko_KR.UTF-8",
            "TERM": "xterm-256color",
            "CLAUDE_CONFIG_DIR": os.path.join(self.root, "claude-work"),
            "ANTHROPIC_API_KEY": "<REDACTED>",
            "ANTHROPIC_BASE_URL": "https://gateway.example.invalid",
            "CLAUDE_CODE_OAUTH_TOKEN": "<REDACTED>",
            "HTTPS_PROXY": "http://proxy.example.invalid:3128",
            "NO_PROXY": "localhost",
            "NODE_EXTRA_CA_CERTS": "/etc/ssl/corp.pem",
        }
        p = self.run_script([], result="ok", extra_env=needed)
        self.assertEqual(p.returncode, 0)
        got = self.child_env()
        for name, value in needed.items():
            with self.subTest(name=name):
                self.assertEqual(got.get(name), value)
        self.assertEqual(got.get("TMPDIR"), self.root)

    def test_env_provider_vars_only_when_selected(self):
        provider = {
            "AWS_PROFILE": "some-profile",
            "GOOGLE_APPLICATION_CREDENTIALS": "/nowhere/creds.json",
            "CLOUD_ML_REGION": "global",
            "VERTEX_REGION_CLAUDE_HAIKU_4_5": "us-east5",
            "AZURE_TENANT_ID": "some-tenant",
        }
        selectors = ("CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX",
                     "CLAUDE_CODE_USE_FOUNDRY")
        for chosen in ("1", ""):
            env = dict(provider)
            env.update({s: chosen for s in selectors})
            self.run_script([], result="ok", extra_env=env)
            got = self.child_env()
            for name, value in provider.items():
                with self.subTest(chosen=chosen, name=name):
                    if chosen:
                        self.assertEqual(got.get(name), value)
                    else:
                        self.assertNotIn(name, got)
        self.run_script([], result="ok", extra_env={
            "CLAUDE_CODE_USE_MANTLE": "1", "AWS_REGION": "us-east-1"})
        self.assertEqual(self.child_env().get("AWS_REGION"), "us-east-1")

    @unittest.skipUnless(sys.platform == "darwin", "개발 도구 폴더는 macOS 만")
    def test_path_keeps_dev_tool_prefix(self):
        dev_root = os.path.join(self.root, "dev tools")
        os.makedirs(os.path.join(dev_root, "usr", "bin"), exist_ok=True)
        fake_select = os.path.join(self.bin, "xcode-select")
        with open(fake_select, "w", encoding="utf-8") as f:
            f.write("#!/bin/sh\nprintf '%s\\n' " + shlex.quote(dev_root) + "\n")
        os.chmod(fake_select, 0o755)
        try:
            p = self.run_script([], result="ok")
        finally:
            os.remove(fake_select)
        self.assertEqual(p.returncode, 0)
        self.assertEqual(
            self.child_env().get("PATH"),
            os.path.join(dev_root, "usr", "bin") + ":" + self.bin
            + ":/usr/bin:/bin")

    def test_always_flags_without_cap(self):
        self.run_script([], result="ok", plugin=os.path.basename(self.plugin),
                        cwd=self.root)
        a = self.fake_args()
        i = a.index("plugin")
        self.assertEqual(a[i + 1], "eval")
        got = a[i + 2]
        self.assertTrue(os.path.isabs(got))
        self.assertIn(" ", got)
        self.assertEqual(a[i + 3], "--eval-dir")
        self.assertNotEqual(got, self.plugin)
        self.assertNotEqual(got, os.path.realpath(self.plugin))
        self.assertEqual(os.path.basename(got), os.path.basename(self.plugin))
        self.assertEqual(a.count("--no-publish"), 1)
        self.assertEqual(a.count("--max-cost-usd"), 1)
        self.assertEqual(a[a.index("--max-cost-usd") + 1], "2")
        self.assertEqual(a[a.index("--eval-dir") + 1], "tests/evals")

    def test_always_flags_with_cap(self):
        self.run_script(["--max-cost-usd", "1", "--case", "roadmap-*",
                         "--runs", "3", "--model", "sonnet"], result="ok")
        a = self.fake_args()
        self.assertEqual(a.count("--max-cost-usd"), 1)
        self.assertEqual(a[a.index("--max-cost-usd") + 1], "1")
        self.assertIn("--no-publish", a)
        self.assertEqual(a[a.index("--eval-dir") + 1], "tests/evals")
        self.assertEqual(a[a.index("--case") + 1], "roadmap-*")
        self.assertEqual(a[a.index("--runs") + 1], "3")
        self.assertEqual(a[a.index("--model") + 1], "sonnet")

    def test_plugin_copy_resolves_links(self):
        self.assertTrue(os.path.islink(self.link))
        p = self.run_script([], result="ok", inspect=True)
        a = self.fake_args()
        got = a[a.index("eval") + 1]
        self.assertNotEqual(got, self.plugin)
        self.assertNotEqual(got, os.path.realpath(self.plugin))
        with open(self.links_file, encoding="utf-8") as f:
            self.assertEqual(f.read().strip(), "0")
        with open(self.linked_file, encoding="utf-8") as f:
            self.assertEqual(f.read(), OUTSIDE_TEXT)
        self.assertFalse(os.path.exists(got))
        self.assertEqual(p.returncode, 0)

    def test_copy_failure_does_not_call(self):
        p = self.run_script([], result="ok", plugin=self.broken_plugin)
        self.assertFalse(os.path.exists(self.args_file))
        self.assertTrue(
            self.last_line(p).startswith("plugin-evals: 돌지 못함 — "))
        self.assertEqual(p.returncode, 1)

    def test_bad_cap_does_not_call(self):
        for bad in ("abc", "0", "-1"):
            with self.subTest(cap=bad):
                if os.path.exists(self.args_file):
                    os.remove(self.args_file)
                p = self.run_script(["--max-cost-usd", bad], result="ok")
                self.assertFalse(os.path.exists(self.args_file))
                self.assertTrue(
                    self.last_line(p).startswith("plugin-evals: 돌지 못함 — "))
                self.assertEqual(p.returncode, 1)

    def test_pass_line(self):
        p = self.run_script([], result="ok", rc=0)
        self.assertEqual(
            self.last_line(p),
            "plugin-evals: 통과 · 케이스 2/2 · 실행 6회 · $0.52 · sonnet")
        self.assertEqual(p.returncode, 0)

    def test_fail_line_default_model(self):
        p = self.run_script([], result="fail", rc=1)
        self.assertEqual(
            self.last_line(p),
            "plugin-evals: 실패 · 케이스 1/2 · 실행 6회 · $0.40 · 기본")
        self.assertEqual(p.returncode, 1)

    def test_partial_line(self):
        p = self.run_script([], result="partial", rc=2)
        self.assertEqual(
            self.last_line(p),
            "plugin-evals: 부분 · 케이스 0/2 · 실행 3회 · $1.00 · sonnet")
        self.assertEqual(p.returncode, 2)

    def test_all_zero_turns_is_not_run(self):
        for rc in (1, 0):
            with self.subTest(rc=rc):
                p = self.run_script([], result="zero_turns", rc=rc)
                last = self.last_line(p)
                self.assertEqual(
                    last, "plugin-evals: 돌지 못함 — 세션이 시작되지 않았다"
                          "(실행 3회 모두 0턴)")
                self.assertNotIn("실패", last)
                self.assertNotIn("케이스", last)
                self.assertEqual(p.returncode, 1)

    def test_no_runs_is_not_run(self):
        for result, rc, want in (("no_cases", 1, 1), ("no_cases", 0, 1),
                                 ("empty_runs", 2, 2)):
            with self.subTest(result=result, rc=rc):
                p = self.run_script([], result=result, rc=rc)
                last = self.last_line(p)
                self.assertEqual(last, "plugin-evals: 돌지 못함 — 돈 실행이 없다")
                self.assertNotIn("케이스", last)
                self.assertEqual(p.returncode, want)

    def test_some_zero_turns_is_fail_line(self):
        p = self.run_script([], result="one_zero_turn", rc=1)
        self.assertEqual(
            self.last_line(p),
            "plugin-evals: 실패 · 케이스 1/2 · 실행 4회 · $0.30 · sonnet")
        self.assertEqual(p.returncode, 1)

    def test_no_result_rc0_is_not_run(self):
        p = self.run_script([], rc=0)
        self.assertEqual(self.last_line(p),
                         "plugin-evals: 돌지 못함 — 결과 파일이 없다")
        self.assertEqual(p.returncode, 1)

    def test_unreadable_result_is_not_run(self):
        p = self.run_script([], result="broken", rc=0)
        last = self.last_line(p)
        self.assertTrue(last.startswith(
            "plugin-evals: 돌지 못함 — 결과 파일을 읽지 못했다"))
        self.assertNotIn("케이스", last)
        self.assertEqual(p.returncode, 1)

    def test_result_missing_key_is_not_run(self):
        p = self.run_script([], result="nokey", rc=0)
        last = self.last_line(p)
        self.assertTrue(last.startswith(
            "plugin-evals: 돌지 못함 — 결과 파일을 읽지 못했다"))
        self.assertNotIn("케이스", last)
        self.assertEqual(p.returncode, 1)

    def test_no_result_rc2_keeps_rc(self):
        p = self.run_script([], rc=2)
        self.assertEqual(self.last_line(p),
                         "plugin-evals: 돌지 못함 — 결과 파일이 없다")
        self.assertEqual(p.returncode, 2)

    def test_unknown_rc_is_not_run(self):
        p = self.run_script([], result="ok", rc=130)
        last = self.last_line(p)
        self.assertTrue(last.startswith("plugin-evals: 돌지 못함 — "))
        self.assertNotIn("통과", last)
        self.assertEqual(p.returncode, 130)

    def test_command_missing_is_not_run(self):
        p = self.run_script([], with_bin=False)
        self.assertEqual(
            self.last_line(p),
            "plugin-evals: 돌지 못함 — 평가 명령(claude)을 찾지 못했다")
        self.assertEqual(p.returncode, 1)


if __name__ == "__main__":
    unittest.main()
