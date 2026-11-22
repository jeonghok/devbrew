import os
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from test_suite_timing import (  # noqa: E402
    RepoMixin, BASE, BASE_WITHOUT_FAIL, NODE, NODE_TEST, FAIL_OUT, PASS_PY, clean_env)

NODE_PATH = "plugins/p/tests/n.test.mjs"
ALL_TARGETS = 2 + 3   # BASE 의 셸 둘 · python 셋(node 없는 레포)
PARTIAL = "run-all: 일부만 돌았다 — 대상 %d개(SUITE_ONLY_FAILED_FILE)\n"
DROPPED = "run-all: 실패 목록을 읽지 못해 전부 돈다 — %s: %s\n"


class OnlyFailedTests(RepoMixin, unittest.TestCase):
    def setUp(self):
        self.tmp = os.path.realpath(tempfile.mkdtemp(prefix="suite-only-"))
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.count = 0
        self.ps = self.ps_file("")

    def list_file(self, text, name="only.txt"):
        path = os.path.join(self.tmp, name)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)
        return path

    def run_listed(self, repo, only):
        """목록 변수와 기록 변수를 함께 줘 돈다 — (rc, out, err, 돈 대상 경로 목록)."""
        timing = self.out_file("timing-%d.tsv" % len(os.listdir(self.tmp)))
        extra = {"SUITE_TIMING_FILE": timing, "SUITE_PEERS_PS_FILE": self.ps}
        if only is not None:
            extra["SUITE_ONLY_FAILED_FILE"] = only
        rc, out, err = self.run_all(repo, extra)
        ran = [l.split("\t")[2] for l in self.target_lines(self.lines(timing))]
        return rc, out, err, ran

    def check_runs_all(self, repo, only, reason, value):
        without = self.run_all(repo)
        rc, out, err, ran = self.run_listed(repo, only)
        self.assertEqual(len(ran), ALL_TARGETS, ran)
        self.assertEqual((rc, out), without[:2])
        self.assertEqual(err, DROPPED % (reason, value))

    def test_ac19_only_listed_targets_each_kind(self):
        repo = self.make_repo(BASE, node=True)
        text = "plugins/p/tests/test_fail.sh: broke\ntools/x: FAIL: test_1 (test_t.T)\n"
        if NODE:
            text += NODE_PATH + ": ok\n"
        rc, out, err, ran = self.run_listed(repo, self.list_file(text))
        self.assertEqual(sorted(ran),
                         sorted(["plugins/p/tests/test_fail.sh", "tools/x"] + [NODE_PATH] * NODE))
        self.assertEqual((rc, out), (1, FAIL_OUT))
        self.assertEqual(err, PARTIAL % (2 + NODE))

    def test_ac19_absent_runs_all(self):
        repo = self.make_repo(BASE, node=True)
        rc, out, err, ran = self.run_listed(repo, None)
        self.assertEqual(len(ran), ALL_TARGETS + NODE, ran)
        self.assertEqual((rc, out, err), (1, FAIL_OUT, ""))

    def test_empty_value_same_as_absent(self):
        repo = self.make_repo(BASE)
        without = self.run_all(repo)
        self.assertEqual(self.run_all(repo, {"SUITE_ONLY_FAILED_FILE": ""}), without)
        self.assertEqual(without, (1, FAIL_OUT, ""))

    def test_ac24_unreadable_line_runs_all(self):
        repo = self.make_repo(BASE)
        only = self.list_file("broke\nplugins/p/tests/test_fail.sh: broke\n")
        self.check_runs_all(repo, only, "대상 경로 꼴이 아닌 줄이 있다", "broke")

    def test_ac24_placeholder_target_unreadable(self):
        repo = self.make_repo(BASE)
        line = "<tree>/shared/tests/test_pass.sh: x"
        self.check_runs_all(repo, self.list_file(line + "\n"), "대상 경로 꼴이 아닌 줄이 있다", line)

    def test_shape_edges(self):
        # 꼴 밖: <p> · <d> 에 / · 이름이 test_*.sh 가 아님 · 접두가 다름 / 꼴 안: … 에 / 가 있는 셸 대상
        repo = self.make_repo(BASE)
        for line in ("plugins/a/b/tests: x", "tools/a/b: x", "shared/tests/foo.sh: x",
                     "plugins/p/tests/footest_x.sh: x", "plugins/p/test_x.sh: x",
                     "tools/: x", "plugins//tests: x", "plugins/p/tests/x.mjs: x"):
            rc, out, err, ran = self.run_listed(repo, self.list_file(line + "\n"))
            self.assertEqual(err, DROPPED % ("대상 경로 꼴이 아닌 줄이 있다", line), line)
            self.assertEqual(len(ran), ALL_TARGETS, line)
        only = self.list_file("shared/tests/sub/test_deep.sh: x\nshared/tests: FAIL: a (m.C)\n")
        rc, out, err, ran = self.run_listed(repo, only)
        self.assertEqual((rc, out, err, ran), (0, "", PARTIAL % 1, ["shared/tests"]))

    def test_unreadable_file_and_relative_path_run_all(self):
        repo = self.make_repo(BASE)
        missing = os.path.join(self.tmp, "no-such-list.txt")
        self.check_runs_all(repo, missing, "파일을 읽지 못했다", missing)
        self.check_runs_all(repo, self.tmp, "파일을 읽지 못했다", self.tmp)
        self.check_runs_all(repo, "rel.txt", "절대 경로가 아니다", "rel.txt")

    def test_blank_lines_skipped_and_empty_list_runs_all(self):
        repo = self.make_repo(BASE)
        only = self.list_file("\nplugins/p/tests/test_fail.sh: broke\n\n")
        rc, out, err, ran = self.run_listed(repo, only)
        self.assertEqual(ran, ["plugins/p/tests/test_fail.sh"])
        self.assertEqual((rc, out, err), (1, FAIL_OUT, PARTIAL % 1))
        empty = self.list_file("", "empty.txt")
        self.check_runs_all(repo, empty, "읽을 줄이 없다", empty)
        blank = self.list_file("\n\n", "blank.txt")
        self.check_runs_all(repo, blank, "읽을 줄이 없다", blank)

    def test_last_line_without_newline_read(self):
        repo = self.make_repo(BASE)
        rc, out, err, ran = self.run_listed(repo, self.list_file("plugins/p/tests/test_fail.sh: broke"))
        self.assertEqual((rc, out, err, ran), (1, FAIL_OUT, PARTIAL % 1, ["plugins/p/tests/test_fail.sh"]))

    def test_ac24_missing_target_line_skipped(self):
        repo = self.make_repo(BASE)
        only = self.list_file("plugins/p/tests/test_gone.sh: x\nplugins/p/tests/test_fail.sh: broke\n")
        rc, out, err, ran = self.run_listed(repo, only)
        self.assertEqual(ran, ["plugins/p/tests/test_fail.sh"])
        self.assertEqual((rc, out, err), (1, FAIL_OUT, PARTIAL % 1))

    def test_present_means_what_the_loops_run(self):
        # 있지만 반복문이 돌지 않는 대상(fixtures 아래 셸 · test_*.py 가 없는 tools 폴더 · 추적 안 된 node)은 세지 않는다
        files = dict(BASE)
        files["shared/tests/fixtures/test_fx.sh"] = "exit 1\n"
        files["tools/empty/readme.txt"] = "x\n"
        repo = self.make_repo(files)
        with open(os.path.join(repo, "plugins/p/tests/u.test.mjs"), "w", encoding="utf-8") as fh:
            fh.write(NODE_TEST)
        only = self.list_file("shared/tests/fixtures/test_fx.sh: x\ntools/empty: x\n"
                              "plugins/p/tests/u.test.mjs: x\n")
        rc, out, err, ran = self.run_listed(repo, only)
        self.assertEqual((rc, out, err, ran), (0, "", PARTIAL % 0, []))

    def test_duplicate_names_same_target_once(self):
        repo = self.make_repo(BASE)
        only = self.list_file("plugins/p/tests: FAIL: a (m.C)\nplugins/p/tests: FAIL: b (m.C)\n")
        rc, out, err, ran = self.run_listed(repo, only)
        self.assertEqual(ran, ["plugins/p/tests"])
        self.assertEqual((rc, out, err), (0, "", PARTIAL % 1))

    def test_ac30_partial_pass_stdout_rc_unchanged(self):
        repo = self.make_repo(BASE)
        rc, out, err = self.run_all(repo, {"SUITE_ONLY_FAILED_FILE":
                                           self.list_file("shared/tests/test_pass.sh: x\n")})
        self.assertEqual((rc, out), (0, ""))
        self.assertEqual(err, PARTIAL % 1)

    def test_ac28_nested_runner_gets_no_list(self):
        marks = os.path.join(self.tmp, "marks")
        os.makedirs(marks)
        inner = self.make_repo({
            "shared/tests/test_in1.sh": "touch '%s/in1'\n" % marks,
            "shared/tests/test_in2.sh": "touch '%s/in2'\n" % marks,
        })
        outer = self.make_repo({
            "plugins/p/tests/test_nested.sh": "(cd '%s' && bash tools/suite/run-all.sh)\n" % inner,
            "plugins/p/tests/test_unlisted.sh": "touch '%s/unlisted'\n" % marks,
            "shared/tests/test_pass.sh": BASE["shared/tests/test_pass.sh"],
        })
        only = self.list_file("plugins/p/tests/test_nested.sh: x\n")
        rc, out, err = self.run_all(outer, {"SUITE_ONLY_FAILED_FILE": only})
        self.assertEqual((rc, out, err), (0, "", PARTIAL % 1))
        self.assertTrue(os.path.exists(os.path.join(marks, "in1")))
        self.assertTrue(os.path.exists(os.path.join(marks, "in2")))
        self.assertFalse(os.path.exists(os.path.join(marks, "unlisted")))

    def test_sh_tests_do_not_inherit_list(self):
        repo = self.make_repo({
            "shared/tests/test_env.sh":
                '[ -z "${SUITE_ONLY_FAILED_FILE+x}" ] || { echo "  ✗ inherited"; exit 1; }\n',
            "plugins/p/tests/test_fail.sh": BASE["plugins/p/tests/test_fail.sh"],
        })
        only = self.list_file("shared/tests/test_env.sh: x\n")
        self.assertEqual(self.run_all(repo, {"SUITE_ONLY_FAILED_FILE": only}), (0, "", PARTIAL % 1))

    def test_python_tests_do_not_inherit_list(self):
        d = os.path.join(self.tmp, "pkg", "tests")
        os.makedirs(d)
        with open(os.path.join(d, "test_env.py"), "w", encoding="utf-8") as fh:
            fh.write("import os\nimport unittest\n\nclass E(unittest.TestCase):\n"
                     "    def test_env(self):\n"
                     "        self.assertNotIn('SUITE_ONLY_FAILED_FILE', os.environ)\n")
        env = clean_env(SUITE_ONLY_FAILED_FILE=self.list_file("pkg/tests: x\n"))

        def run(cmd):
            return subprocess.run(cmd, cwd=self.tmp, env=env, stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE, universal_newlines=True, timeout=120)
        proc = run([sys.executable, os.path.join(HERE, "run_unittest_dir.py"), "pkg/tests"])
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        # 양성 대조: 러너를 거치지 않으면 같은 시험이 변수를 보고 실패한다
        proc = run([sys.executable, "-m", "unittest", "discover", "-s", "pkg/tests"])
        self.assertNotEqual(proc.returncode, 0, proc.stdout + proc.stderr)

    def test_base_without_fail_partial_runs_nothing_failing(self):
        repo = self.make_repo(BASE_WITHOUT_FAIL)
        only = self.list_file("plugins/p/tests/test_fail.sh: broke\n")
        rc, out, err, ran = self.run_listed(repo, only)
        self.assertEqual((rc, out, err, ran), (0, "", PARTIAL % 0, []))


if __name__ == "__main__":
    unittest.main()
