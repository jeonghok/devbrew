import json, stat, subprocess, tempfile, unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "run-own-tests.sh"


def _exe(p, body):
    p.write_text(body); p.chmod(p.stat().st_mode | stat.S_IEXEC)


def _stub_qg(path, guard="no", create_exit=0):
    # create-sandbox: 3줄 stdout / mutation-guard: forced_downgrade
    _exe(path, f"""#!/usr/bin/env bash
case "$1" in
  create-sandbox) [ {create_exit} -ne 0 ] && exit {create_exit}; printf '%s\\n%s\\n%s\\n' /tmp/sbx abc123 digestX; exit 0 ;;
  mutation-guard) echo 'tracked_diff: []'; echo 'forced_downgrade: {guard}'; exit 0 ;;
  remove) exit 0 ;;
  *) exit 2 ;;
esac
""")


def run(target, sid, qg):
    r = subprocess.run(["bash", str(SCRIPT), str(target), sid, "--qg-worktree", str(qg)],
                       capture_output=True, text=True)
    return r, (json.loads(r.stdout) if r.stdout.strip() else {})


class TestRunOwnTests(unittest.TestCase):
    def test_forced_downgrade_invalidates(self):   # AC-11 propagation
        with tempfile.TemporaryDirectory() as d:
            d = Path(d); qg = d / "qg.sh"; _stub_qg(qg, guard="yes")
            (d / "tests").mkdir()
            r, obj = run(d, "sid12345678", qg)
            self.assertTrue(obj["own_tests"]["forced_downgrade"])

    def test_clean_run_reports_ran(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d); qg = d / "qg.sh"; _stub_qg(qg, guard="no")
            (d / "tests").mkdir()
            r, obj = run(d, "sid12345678", qg)
            self.assertTrue(obj["own_tests"]["ran"])
            self.assertFalse(obj["own_tests"]["forced_downgrade"])

    def test_kill_switch_sandbox_is_not_ran(self):   # create-sandbox exit 3
        with tempfile.TemporaryDirectory() as d:
            d = Path(d); qg = d / "qg.sh"; _stub_qg(qg, create_exit=3)
            r, obj = run(d, "sid12345678", qg)
            self.assertFalse(obj["own_tests"]["ran"])
            self.assertIn("kill", (obj["own_tests"]["why"] or "").lower())

    def test_missing_qg_degrades(self):
        with tempfile.TemporaryDirectory() as d:
            r, obj = run(Path(d), "sid12345678", Path(d) / "nope.sh")
            self.assertFalse(obj["own_tests"]["ran"])
            self.assertIn("quality-gates", obj["own_tests"]["why"] or "")


if __name__ == "__main__":
    unittest.main()
