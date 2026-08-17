"""plugin-audit detect_codex.sh — 14-케이스. 형제 두 사본과 같은 커버리지를 갖는다.

왜 python인가: plugin-audit의 테스트 층은 unittest다(`tests/test_*.py`).
검사 대상은 bash 스크립트지만 하니스는 이 플러그인의 기성 규약을 따른다.
"""
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]          # plugins/plugin-audit
PROBE = ROOT / "scripts" / "detect_codex.sh"
QG_MOCKS = ROOT.parent / "quality-gates" / "tests" / "mocks"


def run(env_extra=None, path_dirs=None):
    import os
    env = dict(os.environ)
    env.pop("CODEX_SANDBOX", None)
    env.pop("CODEX_SESSION_ID", None)
    env.pop("DEVBREW_DISABLE_PLUGIN_AUDIT_CODEX", None)
    if path_dirs is not None:
        env["PATH"] = ":".join(str(p) for p in path_dirs) + ":/usr/bin:/bin"
    env.update(env_extra or {})
    p = subprocess.run(["bash", str(PROBE)], capture_output=True, text=True, env=env)
    return p.stdout


class TestDetectCodex(unittest.TestCase):
    def _mocks(self, name):
        return [QG_MOCKS / name, QG_MOCKS / "bin-stubs"]

    def test_1_not_installed(self):
        self.assertIn("skip_reason: not_installed", run(path_dirs=[]))

    def test_2_available(self):
        out = run({"CODEX_API_KEY": "t"}, self._mocks("safe-v1"))
        self.assertIn("codex_available: true", out)

    def test_3_kill_switch(self):
        out = run({"DEVBREW_DISABLE_PLUGIN_AUDIT_CODEX": "1"})
        self.assertIn("skip_reason: kill_switch", out)

    def test_4a_inside_sandbox(self):
        self.assertIn("skip_reason: inside_codex_sandbox", run({"CODEX_SANDBOX": "1"}))

    def test_4b_inside_session(self):
        self.assertIn("skip_reason: inside_codex_sandbox", run({"CODEX_SESSION_ID": "abc"}))

    def test_5_auth_missing(self):
        import tempfile
        with tempfile.TemporaryDirectory() as td:
            out = run({"CODEX_API_KEY": "", "OPENAI_API_KEY": "", "HOME": td},
                      self._mocks("safe-v1"))
        self.assertIn("skip_reason: auth_missing", out)

    def test_6_known_bad_version(self):
        out = run({"CODEX_API_KEY": "t"}, self._mocks("bad-version"))
        self.assertIn("skip_reason: known_bad_version", out)

    def test_7_timeout_binary_missing(self):
        out = run({"CODEX_API_KEY": "t"}, [QG_MOCKS / "safe-v1"])
        self.assertIn("skip_reason: timeout_binary_missing", out)

    def test_8_foreign_kill_switch_inert(self):
        # 이웃 플러그인의 변수는 이 사본에 무효해야 한다.
        out = run({"CODEX_API_KEY": "t", "DEVBREW_DISABLE_QG_CODEX": "1"},
                  self._mocks("safe-v1"))
        self.assertIn("codex_available: true", out)

    def test_9_version_below_floor(self):
        out = run({"CODEX_API_KEY": "t"}, self._mocks("below-floor"))
        self.assertIn("skip_reason: version_below_floor", out)

    def test_10_version_unreadable(self):
        out = run({"CODEX_API_KEY": "t"}, self._mocks("unreadable-version"))
        self.assertIn("skip_reason: version_unreadable", out)

    def test_11_kill_switch_var_name(self):
        body = PROBE.read_text(encoding="utf-8")
        self.assertIn("DEVBREW_DISABLE_PLUGIN_AUDIT_CODEX", body)

    def test_12_no_stale_foreign_var(self):
        body = PROBE.read_text(encoding="utf-8")
        self.assertNotIn("DEVBREW_DISABLE_QG_CODEX", body)
        self.assertNotIn("DEVBREW_DISABLE_SPEC_DISTILL_CODEX", body)

    def test_13_version_probe_wrapped_in_timeout(self):
        body = PROBE.read_text(encoding="utf-8")
        self.assertRegex(body, r'\$TIMEOUT_BIN"?\s+5\s+codex\s+--version')

    def test_14_floor_value_is_declared(self):
        # 바닥 값이 리터럴로 선언돼 있어야 한다 — 값을 지우면 아래 비교가 통째로 무의미해진다.
        self.assertIn("CODEX_VERSION_FLOOR='0.118.0'", PROBE.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
