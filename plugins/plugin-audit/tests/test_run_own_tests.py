import json, os, stat, subprocess, tempfile, unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "run-own-tests.sh"
NEW_SWITCH = "DEVBREW_PLUGIN_AUDIT_DISABLE_RUNTIME_SANDBOX"
LEGACY_SWITCH = "DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX"

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


def run(target, sid, qg, extra_path=None):
    env = None
    if extra_path is not None:
        env = dict(os.environ)
        env["PATH"] = f"{extra_path}:{env['PATH']}"
    r = subprocess.run(["bash", str(SCRIPT), str(target), sid, "--sandbox-helper", str(qg)],
                       capture_output=True, text=True, env=env)
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

    def _real_helper_run(self, switch_env):
        # 실제 audit-sandbox.sh(스텁 아님)로 돈다 — kill switch 를 읽는 것은 그 스크립트다.
        # 대상의 셸 테스트는 저장소 밖 절대경로 marker 를 만든다: marker 가 있으면 대상
        # 테스트가 실행된 것이다.
        d = Path(tempfile.mkdtemp())
        self.addCleanup(subprocess.run, ["rm", "-rf", str(d)])
        repo = d / "repo"; marker = d / "target-test-ran"
        tdir = repo / "plugins" / "tgt" / "tests"; tdir.mkdir(parents=True)
        _exe(tdir / "test_marker.sh", f"#!/usr/bin/env bash\ntouch '{marker}'\n")
        for c in (["git", "init", "-q", "-b", "main"], ["git", "config", "user.email", "t@t"],
                  ["git", "config", "user.name", "t"], ["git", "add", "-A"],
                  ["git", "commit", "-q", "-m", "init"]):
            subprocess.run(c, cwd=repo, check=True, capture_output=True)
        env = {k: v for k, v in os.environ.items()
               if k not in (NEW_SWITCH, LEGACY_SWITCH)}
        env.update(switch_env)
        r = subprocess.run(["bash", str(SCRIPT), "plugins/tgt", "sid12345678"],
                           capture_output=True, text=True, cwd=repo, env=env, timeout=120)
        obj = json.loads(r.stdout.strip().splitlines()[-1])["own_tests"]
        return obj, marker.exists(), (repo / ".claude" / "plugin-audit").exists()

    def test_real_helper_without_switch_runs_target_test(self):
        # 아래 두 skip 케이스의 양의 짝 — marker 장치가 실제로 실행을 관측한다.
        obj, ran_marker, _ = self._real_helper_run({})
        self.assertTrue(obj["ran"], obj)
        self.assertTrue(ran_marker, "스위치 없이도 대상 테스트가 안 돌았다 — marker 장치가 죽었다")

    def test_new_switch_name_skips_without_running(self):
        obj, ran_marker, ns = self._real_helper_run({NEW_SWITCH: "1"})
        self.assertFalse(obj["ran"])
        self.assertIn("kill-switch", obj["why"] or "")
        self.assertIn(NEW_SWITCH, obj["why"] or "")
        self.assertFalse(ran_marker, "kill switch 인데 대상 테스트가 실행됐다")
        self.assertFalse(ns, "kill switch 인데 샌드박스 네임스페이스가 생겼다")

    def test_legacy_switch_name_skips_without_running(self):
        # 0.11.0 이 옛 이름을 조용히 버려 대상 테스트가 다시 돌던 fail-open 의 락.
        obj, ran_marker, ns = self._real_helper_run({LEGACY_SWITCH: "1"})
        self.assertFalse(obj["ran"], "옛 이름 kill switch 가 무시됐다 (fail-open)")
        self.assertIn("kill-switch", obj["why"] or "")
        self.assertIn(LEGACY_SWITCH, obj["why"] or "", "skip 사유가 옛 이름을 밝히지 않는다")
        self.assertFalse(ran_marker, "옛 이름 kill switch 인데 대상 테스트가 실행됐다")
        self.assertFalse(ns, "옛 이름 kill switch 인데 샌드박스 네임스페이스가 생겼다")

    def test_missing_helper_degrades(self):
        with tempfile.TemporaryDirectory() as d:
            r, obj = run(Path(d), "sid12345678", Path(d) / "nope.sh")
            self.assertFalse(obj["own_tests"]["ran"])
            self.assertIn("audit-sandbox.sh 부재", obj["own_tests"]["why"] or "")

    def test_default_helper_is_the_sibling_script_not_cwd(self):
        # 옵션 없이 부르면 이 플러그인의 audit-sandbox.sh 를 쓴다 — cwd 에 무엇이 있든.
        # 비-git 임시 디렉토리라 create-sandbox 는 실패하지만, 그 실패 사유가 「부재」가 아니라는
        # 것이 도우미를 찾았다는 증거다.
        with tempfile.TemporaryDirectory() as d:
            r = subprocess.run(["bash", str(SCRIPT), "plugins/x", "sid12345678"],
                               capture_output=True, text=True, cwd=d, timeout=60)
            obj = json.loads(r.stdout.strip().splitlines()[-1])
            why = obj["own_tests"]["why"] or ""
            self.assertNotIn("부재", why)
            self.assertIn("sandbox 생성 실패", why)

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

    def test_timeout_reports_ran_false(self):   # E (AC-11, /qg 2026-07-20 round-2)
        # AC-11 (spec §14 L496): "120s 타임아웃 → own_tests:{ran:false}". 현재 line 46은 exit code를
        # 버리고 ran=true를 무조건 세워, 타임아웃(timeout/gtimeout kill = exit 124)·크래시-on-import가
        # 성공과 구별 불가하고 §14 배너 신호도 안 뜬다. fake `timeout`(exit 124)로 타임아웃 kill을 흉내.
        with tempfile.TemporaryDirectory() as d:
            d = Path(d); qg = d / "qg.sh"; sbx = d / "sbx"
            _sandbox_with_tests(sbx)
            _stub_qg(qg, sbx, guard="no")
            bindir = d / "bin"; bindir.mkdir()
            for name in ("timeout", "gtimeout"):   # 둘 다 심어 어느 유틸을 고르든 exit 124
                _exe(bindir / name, "#!/usr/bin/env bash\nexit 124\n")
            r, obj = run("plugins/myplugin", "sid12345678", qg, extra_path=str(bindir))
            self.assertFalse(obj["own_tests"]["ran"], "타임아웃(exit 124)인데 ran=true (AC-11 위반)")
            self.assertIn("타임아웃", (obj["own_tests"]["why"] or ""), "타임아웃 사유가 why에 없음")

    def test_mutation_guard_indeterminate_forces_downgrade(self):
        # mutation-guard 가 exit 4(indeterminate)로 죽으면 stdout 파싱과 무관하게 보수적으로
        # forced_downgrade=true 여야 한다(audit-sandbox.sh 자체 계약: indeterminate는 절대 PASS 아님).
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
