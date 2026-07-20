import json, stat, subprocess, tempfile, unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "run-own-tests.sh"

TRIVIAL_TEST = (
    "import unittest\n"
    "class T(unittest.TestCase):\n"
    "    def test_ok(self):\n"
    "        self.assertTrue(True)\n"
)


def _exe(p, body):
    p.write_text(body); p.chmod(p.stat().st_mode | stat.S_IEXEC)


def _stub_qg(path, sbx, guard="no", create_exit=0, guard_exit=0):
    # create-sandbox: 3줄 stdout, 1행 = 호출자가 미리 준비한 REAL 샌드박스 디렉토리(sbx)
    #   — 실제 경로여야 target-path-in-sandbox 매핑과 unittest discover가 그 안에서 동작한다.
    # mutation-guard: forced_downgrade 텍스트 + exit code(0=정상/4=indeterminate/2=die 흉내)
    _exe(path, f"""#!/usr/bin/env bash
case "$1" in
  create-sandbox) [ {create_exit} -ne 0 ] && exit {create_exit}; printf '%s\\n%s\\n%s\\n' {sbx} abc123 digestX; exit 0 ;;
  mutation-guard) echo 'tracked_diff: []'; echo 'forced_downgrade: {guard}'; exit {guard_exit} ;;
  remove) exit 0 ;;
  *) exit 2 ;;
esac
""")


def _sandbox_with_tests(root, rel_target="plugins/myplugin"):
    # root/rel_target/tests/ 를 실제 python 패키지(__init__.py 필요 — discover start-dir 요건)로 생성
    tests_dir = root / rel_target / "tests"
    tests_dir.mkdir(parents=True)
    (tests_dir / "__init__.py").write_text("")
    (tests_dir / "test_trivial.py").write_text(TRIVIAL_TEST)
    return tests_dir


def run(target, sid, qg):
    r = subprocess.run(["bash", str(SCRIPT), str(target), sid, "--qg-worktree", str(qg)],
                       capture_output=True, text=True)
    return r, (json.loads(r.stdout) if r.stdout.strip() else {})


class TestRunOwnTests(unittest.TestCase):
    def test_forced_downgrade_invalidates(self):   # AC-11 propagation
        with tempfile.TemporaryDirectory() as d:
            d = Path(d); qg = d / "qg.sh"; sbx = d / "sbx"
            _sandbox_with_tests(sbx)
            _stub_qg(qg, sbx, guard="yes")
            r, obj = run("plugins/myplugin", "sid12345678", qg)
            self.assertTrue(obj["own_tests"]["ran"])
            self.assertTrue(obj["own_tests"]["forced_downgrade"])

    def test_clean_run_reports_ran(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d); qg = d / "qg.sh"; sbx = d / "sbx"
            _sandbox_with_tests(sbx)
            _stub_qg(qg, sbx, guard="no")
            r, obj = run("plugins/myplugin", "sid12345678", qg)
            self.assertTrue(obj["own_tests"]["ran"])
            self.assertFalse(obj["own_tests"]["forced_downgrade"])

    def test_kill_switch_sandbox_is_not_ran(self):   # create-sandbox exit 3
        with tempfile.TemporaryDirectory() as d:
            d = Path(d); qg = d / "qg.sh"
            _stub_qg(qg, d / "unused-sbx", create_exit=3)
            r, obj = run(d, "sid12345678", qg)
            self.assertFalse(obj["own_tests"]["ran"])
            self.assertIn("kill", (obj["own_tests"]["why"] or "").lower())

    def test_missing_qg_degrades(self):
        with tempfile.TemporaryDirectory() as d:
            r, obj = run(Path(d), "sid12345678", Path(d) / "nope.sh")
            self.assertFalse(obj["own_tests"]["ran"])
            self.assertIn("quality-gates", obj["own_tests"]["why"] or "")

    def test_target_path_resolves_in_sandbox(self):
        # $sbx/plugins/myplugin/tests 는 만들지만 $sbx/tests(샌드박스 루트)는 만들지 않는다 —
        # 매핑이 $sbx/plugins/myplugin 으로 정확히 해석됨(샌드박스 루트로 새지 않음)을 증명.
        # MUTATION: tgt_in_sb를 "$SANDBOX/${TARGET#*/}" 로 되돌리면 $sbx/myplugin (존재하지
        # 않음)을 가리켜 ran:false 로 RED.
        with tempfile.TemporaryDirectory() as d:
            d = Path(d); qg = d / "qg.sh"; sbx = d / "sbx"
            _sandbox_with_tests(sbx, rel_target="plugins/myplugin")
            self.assertFalse((sbx / "tests").exists())
            _stub_qg(qg, sbx, guard="no")
            r, obj = run("plugins/myplugin", "sid12345678", qg)
            self.assertTrue(obj["own_tests"]["ran"])

    def test_mutation_guard_indeterminate_forces_downgrade(self):
        # mutation-guard 가 exit 4(indeterminate)로 죽으면 stdout 파싱과 무관하게 보수적으로
        # forced_downgrade=true 여야 한다(qg-worktree 자체 계약: indeterminate는 절대 PASS 아님).
        # MUTATION: exit-4 보수적 처리를 제거하면(exit code 무시하고 stdout만 파싱) forced가
        # 빈 문자열로 파싱되어 fd=false 로 새어 RED.
        with tempfile.TemporaryDirectory() as d:
            d = Path(d); qg = d / "qg.sh"; sbx = d / "sbx"
            _sandbox_with_tests(sbx)
            _stub_qg(qg, sbx, guard="no", guard_exit=4)
            r, obj = run("plugins/myplugin", "sid12345678", qg)
            self.assertTrue(obj["own_tests"]["forced_downgrade"])


if __name__ == "__main__":
    unittest.main()
