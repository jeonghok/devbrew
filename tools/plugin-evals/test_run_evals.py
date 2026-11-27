"""run_evals.py 의 명령줄 · 종료 코드 · 요약 줄 · 평가 명령에 넘기는 환경을 잰다.

바깥 경계가 명령줄 · 종료 코드라 케이스마다 스크립트를 띄운다.
가짜 claude 는 설정을 환경이 아니라 옆의 fake.conf 에서 읽는다 — 스크립트가 넘기는 환경을 재야 해서다.
POSIX(macOS · Linux) 전용이다 — 가짜 claude 가 /bin/sh 스크립트다.
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
sys.path.insert(0, HERE)
import run_evals  # noqa: E402 — 허용 목록 이름을 NEEDED 와 대조한다

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

# 가짜 claude(sh) 와 OS 가 스스로 두는 이름 — 스크립트가 넘긴 것이 아니다.
SHELL_SET = frozenset(("PWD", "OLDPWD", "SHLVL", "_", "__CF_USER_TEXT_ENCODING",
                       "LC_CTYPE"))

# 넘어가야 하는 이름과 값 — 공식 env-vars 문서에서 고른 것. HOME · CLAUDE_CONFIG_DIR 는 테스트가 채운다.
NEEDED = {
    "USER": "someone", "LOGNAME": "someone", "SHELL": "/bin/zsh",
    "LANG": "ko_KR.UTF-8", "LC_ALL": "ko_KR.UTF-8", "TERM": "xterm-256color",
    "ANTHROPIC_API_KEY": "<REDACTED>",
    "ANTHROPIC_BASE_URL": "https://gateway.example.invalid",
    "CLAUDE_CODE_USE_POWERSHELL_TOOL": "0",
    "CLAUDE_CODE_SKIP_BEDROCK_AUTH": "1",
    "CLAUDE_CODE_SKIP_ANTHROPIC_GOOGLE_CLOUD_AUTH": "1",
    "CLAUDE_CODE_OAUTH_TOKEN": "<REDACTED>",
    "CLAUDE_CODE_OAUTH_REFRESH_TOKEN": "<REDACTED>",
    "CLAUDE_CODE_OAUTH_SCOPES": "user:inference",
    "CLAUDE_CODE_API_KEY_HELPER_TTL_MS": "60000",
    "CLAUDE_CODE_AWS_CHAIN_RESOLVE_TIMEOUT_MS": "60000",
    "CLAUDE_CODE_PROVIDER_MANAGED_BY_HOST": "1",
    "CLAUDE_CODE_CERT_STORE": "bundled,system",
    "CLAUDE_CODE_CLIENT_CERT": "/etc/ssl/client.pem",
    "CLAUDE_CODE_CLIENT_KEY": "/etc/ssl/client.key",
    "CLAUDE_CODE_CLIENT_KEY_PASSPHRASE": "<REDACTED>",
    "CLAUDE_CODE_PROXY_RESOLVES_HOSTS": "1",
    "CLAUDE_CODE_GZIP_REQUEST_BODIES": "0",
    "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY": "1",
    "CLAUDE_CODE_GATEWAY_MODEL_DISCOVERY_TIMEOUT_MS": "3000",
    "CLAUDE_CODE_GATEWAY_HINT_HEADERS": "1",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "CLAUDE_CODE_DISABLE_AUTH_REFRESH_LOCK": "1",
    "DISABLE_TELEMETRY": "1", "DISABLE_ERROR_REPORTING": "1",
    "DISABLE_AUTOUPDATER": "1",
    "DO_NOT_TRACK": "1", "CLAUDE_CODE_SEND_FEEDBACK": "0",
    "ENABLE_CLAUDEAI_MCP_SERVERS": "false",
    "DEVBREW_SKIP_HOOKS": "spec-distill:review-entry",
    "HTTPS_PROXY": "http://proxy.example.invalid:3128",
    "https_proxy": "http://proxy.example.invalid:3128",
    "HTTP_PROXY": "http://proxy.example.invalid:3128",
    "http_proxy": "http://proxy.example.invalid:3128",
    "ALL_PROXY": "socks5://proxy.example.invalid:1080",
    "all_proxy": "socks5://proxy.example.invalid:1080",
    "NO_PROXY": "localhost", "no_proxy": "localhost",
    "NODE_EXTRA_CA_CERTS": "/etc/ssl/corp.pem",
    "SSL_CERT_FILE": "/etc/ssl/cert.pem", "SSL_CERT_DIR": "/etc/ssl/certs",
}


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
        if os.path.exists(self.env_file):
            os.remove(self.env_file)
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

    def env_run(self, extra_env):
        """평가 명령이 받은 환경. 실행이 통과로 끝났는지도 본다."""
        p = self.run_script([], result="ok", extra_env=extra_env)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        return self.child_env()

    def assert_names_within(self, got, allowed):
        """받은 이름 전체가 기대 집합 안에 든다 — 셸과 OS 가 스스로 두는 이름은 뺀다."""
        extra = set(got) - set(allowed) - {"PATH", "TMPDIR"} - SHELL_SET
        self.assertEqual(extra, set())

    def test_env_drops_unlisted(self):
        unlisted = {
            "DEVBREW_FAKE_SECRET": "<REDACTED>",
            "GITHUB_TOKEN": "<REDACTED>",
            "CLAUDE_CODE_MESSAGING_TOKEN": "<REDACTED>",
            "CLAUDE_CODE_SESSION_ID": "some-session",
            "AWS_SECRET_ACCESS_KEY": "<REDACTED>",
            "GOOGLE_APPLICATION_CREDENTIALS": "/nowhere/creds.json",
            "AZURE_CLIENT_SECRET": "<REDACTED>",
            "PYTHONPATH": "/nowhere",
            "DEVBREW_PYTHON": "/nowhere/python3",
            "DEVBREW_SPEC_DISTILL_SKIP_VC_ONCE": "1",
        }
        got = self.env_run(unlisted)
        for name in unlisted:
            with self.subTest(name=name):
                self.assertNotIn(name, got)
        self.assert_names_within(got, ())

    def needed_env(self):
        env = dict(NEEDED)
        env["HOME"] = os.path.join(self.root, "home")
        env["CLAUDE_CONFIG_DIR"] = os.path.join(self.root, "claude-work")
        return env

    def test_env_passes_needed(self):
        needed = self.needed_env()
        p = self.run_script([], result="ok", extra_env=needed)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        got = self.child_env()
        for name, value in needed.items():
            with self.subTest(name=name):
                self.assertEqual(got.get(name), value)
        self.assertEqual(got.get("TMPDIR"), self.root)
        self.assert_names_within(got, needed)
        self.assertEqual(p.stderr.count("\n"), 1, p.stderr)

    def test_needed_covers_every_listed_name(self):
        """허용 목록의 이름 · 접두마다 넘어가는지 보는 값이 NEEDED 에 있다."""
        needed = self.needed_env()
        for name in run_evals.PASS_NAMES:
            with self.subTest(name=name):
                self.assertIn(name, set(needed) | {"PATH", "TMPDIR"})
        for prefix in run_evals.PASS_PREFIXES:
            with self.subTest(prefix=prefix):
                self.assertTrue(any(k.startswith(prefix) for k in needed))

    def test_dropped_provider_vars_are_named_without_values(self):
        creds = {
            "AWS_SECRET_ACCESS_KEY": "aws-value-not-shown",
            "GOOGLE_APPLICATION_CREDENTIALS": "/nowhere/google-value-not-shown",
            "AZURE_CLIENT_SECRET": "azure-value-not-shown",
        }
        p = self.run_script([], result="ok", extra_env=creds)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        notice = [line for line in p.stderr.splitlines()
                  if "AWS_SECRET_ACCESS_KEY" in line]
        self.assertEqual(len(notice), 1, p.stderr)
        for name, value in creds.items():
            with self.subTest(name=name):
                self.assertIn(name, notice[0])
                self.assertNotIn(value, p.stderr + p.stdout)
        self.assertIn("CLAUDE_CODE_USE_", notice[0])
        p = self.run_script([], result="ok", extra_env=dict(
            creds, CLAUDE_CODE_USE_BEDROCK="1", CLAUDE_CODE_USE_VERTEX="1",
            CLAUDE_CODE_USE_FOUNDRY="1"))
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertNotIn("AWS_SECRET_ACCESS_KEY", p.stderr)

    def test_env_passes_kill_switches(self):
        switches = {
            "DEVBREW_QUALITY_GATES_DISABLE": "1",
            "DEVBREW_SPEC_DISTILL_DISABLE_CODEX": "1",
            "DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE": "1",
            "DEVBREW_DISABLE_QUALITY_GATES": "1",
            "DEVBREW_SKIP_HOOKS": "spec-distill:review-entry",
        }
        got = self.env_run(switches)
        for name, value in switches.items():
            with self.subTest(name=name):
                self.assertEqual(got.get(name), value)
        self.assert_names_within(got, switches)

    def test_env_provider_vars_only_when_selected(self):
        aws = {"AWS_PROFILE": "some-profile"}
        google = {
            "GOOGLE_APPLICATION_CREDENTIALS": "/nowhere/creds.json",
            "GOOGLE_CLOUD_PROJECT": "some-project",
            "CLOUD_ML_REGION": "global",
            "VERTEX_REGION_CLAUDE_HAIKU_4_5": "us-east5",
        }
        azure = {"AZURE_TENANT_ID": "some-tenant"}
        creds = dict(aws, **google)
        creds.update(azure)
        for selector, chosen, opened in (
            ("CLAUDE_CODE_USE_BEDROCK", "1", aws),
            ("CLAUDE_CODE_USE_MANTLE", "true", aws),
            ("CLAUDE_CODE_USE_ANTHROPIC_AWS", "Yes", aws),
            ("CLAUDE_CODE_USE_VERTEX", "on", google),
            ("CLAUDE_CODE_USE_ANTHROPIC_GOOGLE_CLOUD", "TRUE", google),
            ("CLAUDE_CODE_USE_FOUNDRY", "1", azure),
        ):
            env = dict(creds)
            env[selector] = chosen
            got = self.env_run(env)
            with self.subTest(selector=selector):
                self.assertEqual(got.get(selector), chosen)
                self.assertEqual({k: got.get(k) for k in creds if k in got},
                                 opened)
                self.assert_names_within(got, dict(opened, **{selector: 1}))
        selectors = ("CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_MANTLE",
                     "CLAUDE_CODE_USE_ANTHROPIC_AWS", "CLAUDE_CODE_USE_VERTEX",
                     "CLAUDE_CODE_USE_ANTHROPIC_GOOGLE_CLOUD",
                     "CLAUDE_CODE_USE_FOUNDRY")
        for off in ("0", "false", "OFF", ""):
            env = dict(creds)
            env.update({s: off for s in selectors})
            got = self.env_run(env)
            with self.subTest(off=off):
                for name in creds:
                    self.assertNotIn(name, got)
                for s in selectors:
                    self.assertEqual(got.get(s), off)

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
