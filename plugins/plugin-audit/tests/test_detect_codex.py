"""plugin-audit detect_codex.sh — 14-케이스. 형제 두 사본과 같은 커버리지를 갖는다.

왜 python인가: plugin-audit의 테스트 층은 unittest다(`tests/test_*.py`).
검사 대상은 bash 스크립트지만 하니스는 이 플러그인의 기성 규약을 따른다.
"""
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]          # plugins/plugin-audit
PROBE = ROOT / "scripts" / "detect_codex.sh"
CONF = ROOT / "scripts" / "codex-killswitch.conf"
QG_MOCKS = ROOT.parent / "quality-gates" / "tests" / "mocks"


def run(env_extra=None, path_dirs=None):
    import os
    env = dict(os.environ)
    env.pop("CODEX_SANDBOX", None)
    env.pop("CODEX_SESSION_ID", None)
    env.pop("DEVBREW_PLUGIN_AUDIT_DISABLE_CODEX", None)
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
        out = run({"DEVBREW_PLUGIN_AUDIT_DISABLE_CODEX": "1"})
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
        out = run({"CODEX_API_KEY": "t", "DEVBREW_QUALITY_GATES_DISABLE_CODEX": "1"},
                  self._mocks("safe-v1"))
        self.assertIn("codex_available: true", out)

    def test_9_version_below_floor(self):
        out = run({"CODEX_API_KEY": "t"}, self._mocks("below-floor"))
        self.assertIn("skip_reason: version_below_floor", out)

    def test_10_version_unreadable(self):
        out = run({"CODEX_API_KEY": "t"}, self._mocks("unreadable-version"))
        self.assertIn("skip_reason: version_unreadable", out)

    def test_11_kill_switch_var_name(self):
        # 재조준(F1/C1, 2026-08-17): PROBE 는 정본을 가리키는 심볼릭 링크라 본문에
        # 변수명 리터럴이 없다(형제 conf 로 이동). 형제 conf 로 재조준한다 — 부재는
        # assertTrue 로 fail-closed(테스트 실패)한다.
        self.assertTrue(CONF.is_file(), f"conf 없음: {CONF}")
        body = CONF.read_text(encoding="utf-8")
        self.assertIn("CODEX_KILL_SWITCH_VAR=DEVBREW_PLUGIN_AUDIT_DISABLE_CODEX", body)

    def test_12_no_stale_foreign_var(self):
        self.assertTrue(CONF.is_file(), f"conf 없음: {CONF}")
        body = CONF.read_text(encoding="utf-8")
        self.assertNotIn("DEVBREW_QUALITY_GATES_DISABLE_CODEX", body)
        self.assertNotIn("DEVBREW_SPEC_DISTILL_DISABLE_CODEX", body)

    def _with_conf_bytes(self, raw_bytes):
        """conf 를 raw_bytes 로 덮어쓰고 detect_codex.sh 출력을 반환한 뒤 바이트 그대로 원복한다.

        N5 잔여 위험(round 2): SIGKILL은 `finally`를 못 받는다 — 그때는 추적 중인
        codex-killswitch.conf가 malformed 값(CRLF/공백만)으로 덮인 채 남는다. 테스트
        실패로는 안 깨진다. `git checkout --`로 복구 가능하고 데이터 손실은 없다 —
        다음 사람이 워킹트리가 왜 더러운지 알도록 남긴다.
        """
        backup = CONF.read_bytes()
        try:
            CONF.write_bytes(raw_bytes)
            return run({"CODEX_API_KEY": "t"}, self._mocks("safe-v1"))
        finally:
            CONF.write_bytes(backup)

    def test_15_malformed_conf_crlf_fails_closed(self):
        # F2 compounding: 리뷰를 빠져나간 버그를 그것을 잡았어야 할 검사에 넣어 닫는다.
        out = self._with_conf_bytes(
            b"CODEX_KILL_SWITCH_VAR=DEVBREW_PLUGIN_AUDIT_DISABLE_CODEX\r\n"
        )
        self.assertIn("skip_reason: killswitch_config_invalid", out)

    def test_16_malformed_conf_whitespace_only_fails_closed(self):
        out = self._with_conf_bytes(b'CODEX_KILL_SWITCH_VAR="   "\n')
        self.assertIn("skip_reason: killswitch_config_invalid", out)

    def test_13_version_probe_wrapped_in_timeout(self):
        body = PROBE.read_text(encoding="utf-8")
        self.assertRegex(body, r'\$TIMEOUT_BIN"?\s+5\s+codex\s+--version')

    def test_14_floor_value_is_declared(self):
        # 바닥 값이 리터럴로 선언돼 있어야 한다 — 값을 지우면 아래 비교가 통째로 무의미해진다.
        self.assertIn("CODEX_VERSION_FLOOR='0.118.0'", PROBE.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
