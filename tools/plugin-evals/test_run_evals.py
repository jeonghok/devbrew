"""run_evals.py 의 명령줄 · 종료 코드 · 요약 줄을 잰다.

바깥 경계가 명령줄 · 종료 코드라 케이스마다 스크립트를 띄운다.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "run_evals.py")

FAKE_CLAUDE = """#!/bin/sh
: > "$FAKE_ARGS"
for a in "$@"; do printf '%s\\n' "$a" >> "$FAKE_ARGS"; done
prev=""
for a in "$@"; do
  if [ "$prev" = "--json" ] && [ -n "$FAKE_RESULT" ]; then
    cp "$FAKE_RESULT" "$a"
  fi
  prev="$a"
done
exit "${FAKE_RC:-0}"
"""


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


class RunEvalsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = tempfile.mkdtemp(prefix="plugin evals.")
        cls.plugin = os.path.join(cls.root, "fake plugin")
        os.makedirs(os.path.join(cls.plugin, "tests", "evals"))
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

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.root, ignore_errors=True)

    def setUp(self):
        if os.path.exists(self.args_file):
            os.remove(self.args_file)

    def run_script(self, extra, result=None, rc=0, with_bin=True,
                   plugin=None, cwd=None):
        path = "/usr/bin:/bin"
        if with_bin:
            path = self.bin + ":" + path
        env = {
            "PATH": path,
            "TMPDIR": self.root,
            "FAKE_ARGS": self.args_file,
            "FAKE_RC": str(rc),
        }
        if result:
            env["FAKE_RESULT"] = self.results[result]
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

    def test_always_flags_without_cap(self):
        self.run_script([], result="ok", plugin=os.path.basename(self.plugin),
                        cwd=self.root)
        a = self.fake_args()
        i = a.index("plugin")
        self.assertEqual(a[i + 1], "eval")
        self.assertEqual(a[i + 2], os.path.realpath(self.plugin))
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
