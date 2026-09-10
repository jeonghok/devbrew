"""AC4 · AC3 — SessionEnd 훅: 끝나는 세션의 폴더 정리 + TTL-GC 기동."""
import json
import os
import shutil
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

HOOK = (Path(__file__).resolve().parent.parent / "hooks" / "session-end-cleanup.py").resolve()

#: TTL 기본값(24h)보다 늙은 나이.
STALE_AGE_S = 90_000


def run_hook(payload, env_extra=None, cwd=None, raw_stdin=None):
    """훅을 실행한다. **`cwd` 는 필수다.**

    훅은 TTL-GC 를 돌리고, GC 의 루트는 프로세스 cwd 의 state_root 다. cwd 를 비우면 러너
    cwd — 워크트리에서 돌리면 main 체크아웃의 `.claude/spec-distill/` — 의 실제 세션 폴더를
    지운다.
    """
    if cwd is None:
        raise ValueError("run_hook: cwd 필수 — GC 가 러너 cwd 의 실제 상태 루트를 돌지 않게")
    env = {**os.environ}
    for k in ("DEVBREW_SPEC_DISTILL_DISABLE", "DEVBREW_SKIP_HOOKS",
              "DEVBREW_SPEC_DISTILL_TTL_HOURS", "CLAUDE_CODE_SESSION_ID"):
        env.pop(k, None)
    if env_extra:
        env.update(env_extra)
    if raw_stdin is not None:
        stdin = raw_stdin
    else:
        stdin = (json.dumps(payload) if payload is not None else "not-json").encode("utf-8")
    cp = subprocess.run(
        ["python3", str(HOOK)], input=stdin, env=env, cwd=cwd,
        capture_output=True, timeout=15,
    )
    return (cp.returncode, cp.stdout.decode("utf-8", "replace"),
            cp.stderr.decode("utf-8", "replace"))


class SessionEndCleanupTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        subprocess.run(["git", "init", "-q"], cwd=self.tmp, check=True)
        self.root = Path(self.tmp) / ".claude" / "spec-distill"
        self.sid = "abc12345"
        self.folder = self.root / self.sid
        self.folder.mkdir(parents=True)
        (self.folder / "state.local.md").write_text(f"---\nsession_id: {self.sid}\n---\n")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _plant(self, name, age_s):
        """다른 세션의 폴더. 폴더 나이 = 직속 파일의 최신 mtime(gc_common)."""
        d = self.root / name
        d.mkdir(parents=True)
        f = d / "state.local.md"
        f.write_text("x")
        t = time.time() - age_s
        os.utime(f, (t, t))
        return d

    def test_1_happy_path(self):
        rc, _, _ = run_hook({"session_id": self.sid, "cwd": self.tmp}, cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertFalse(self.folder.exists())

    def test_2_folder_absent(self):
        shutil.rmtree(self.folder)
        rc, _, _ = run_hook({"session_id": self.sid, "cwd": self.tmp}, cwd=self.tmp)
        self.assertEqual(rc, 0)

    def test_3_json_decode_fail(self):
        rc, _, _ = run_hook(None, cwd=self.tmp)  # sends "not-json"
        self.assertEqual(rc, 0)
        self.assertTrue(self.folder.exists())

    def test_4_session_id_missing(self):
        rc, _, _ = run_hook({"cwd": self.tmp}, cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertTrue(self.folder.exists())

    def test_5_charset_reject(self):
        rc, _, _ = run_hook({"session_id": "../evil", "cwd": self.tmp}, cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertTrue(self.folder.exists())

    def test_6_cwd_missing(self):
        rc, _, stderr = run_hook({"session_id": self.sid}, cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertFalse(self.folder.exists())
        self.assertIn("missing 'cwd'", stderr)

    def test_7_global_killswitch(self):
        rc, _, _ = run_hook(
            {"session_id": self.sid, "cwd": self.tmp}, cwd=self.tmp,
            env_extra={"DEVBREW_SPEC_DISTILL_DISABLE": "1"},
        )
        self.assertEqual(rc, 0)
        self.assertTrue(self.folder.exists())

    def test_8_granular_killswitch(self):
        rc, _, _ = run_hook(
            {"session_id": self.sid, "cwd": self.tmp}, cwd=self.tmp,
            env_extra={"DEVBREW_SKIP_HOOKS": "spec-distill:SessionEnd"},
        )
        self.assertEqual(rc, 0)
        self.assertTrue(self.folder.exists())

    # --- AC3: TTL-GC 는 SessionEnd 의 `finally` 에서 돈다 ---

    def test_9_gc_collects_stale_other_session(self):
        stale = self._plant("stale-session-01", STALE_AGE_S)
        fresh = self._plant("fresh-session-01", 0)
        rc, _, _ = run_hook({"session_id": self.sid, "cwd": self.tmp}, cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertFalse(self.folder.exists())
        self.assertFalse(stale.exists(), "TTL 이 지난 다른 세션 폴더가 남았다 — GC 가 안 돌았다")
        self.assertTrue(fresh.exists(), "살아 있는 세션 폴더까지 지웠다")

    def test_10_gc_runs_when_stdin_not_json(self):
        stale = self._plant("stale-session-02", STALE_AGE_S)
        rc, _, _ = run_hook(None, cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertTrue(self.folder.exists())
        self.assertFalse(stale.exists())

    def test_11_gc_runs_when_session_id_missing(self):
        stale = self._plant("stale-session-03", STALE_AGE_S)
        rc, _, _ = run_hook({"cwd": self.tmp}, cwd=self.tmp)
        self.assertEqual(rc, 0)
        self.assertTrue(self.folder.exists())
        self.assertFalse(stale.exists())

    def test_12_gc_runs_when_stdin_undecodable(self):
        """stdin 디코딩 예외로 정리가 죽어도 GC 는 돈다(`finally`).

        훅의 rc 는 재지 않는다 — 예외는 GC 뒤에 그대로 전파된다(옛 동작과 같다).
        `PYTHONIOENCODING=utf-8:strict` 는 C 로케일의 surrogateescape 를 꺼서 디코딩 예외를
        확실히 낸다.
        """
        stale = self._plant("stale-session-04", STALE_AGE_S)
        run_hook(None, cwd=self.tmp, raw_stdin=b"\xff\xfe{",
                 env_extra={"PYTHONIOENCODING": "utf-8:strict"})
        self.assertFalse(stale.exists())

    def test_13_gc_switch_spares_stale_only(self):
        stale = self._plant("stale-session-05", STALE_AGE_S)
        rc, _, _ = run_hook(
            {"session_id": self.sid, "cwd": self.tmp}, cwd=self.tmp,
            env_extra={"DEVBREW_SKIP_HOOKS": "spec-distill:spec-distill-gc"},
        )
        self.assertEqual(rc, 0)
        self.assertFalse(self.folder.exists(), "GC 스위치는 세션 정리를 끄지 않는다")
        self.assertTrue(stale.exists())

    def test_14_global_disable_spares_both(self):
        stale = self._plant("stale-session-06", STALE_AGE_S)
        run_hook({"session_id": self.sid, "cwd": self.tmp}, cwd=self.tmp,
                 env_extra={"DEVBREW_SPEC_DISTILL_DISABLE": "1"})
        self.assertTrue(self.folder.exists())
        self.assertTrue(stale.exists())

    def test_15_sessionend_switch_spares_both(self):
        for tok in ("spec-distill:SessionEnd", "spec-distill:session-end-cleanup"):
            with self.subTest(tok=tok):
                stale = self._plant("stale-" + tok.split(":")[1].lower(), STALE_AGE_S)
                run_hook({"session_id": self.sid, "cwd": self.tmp}, cwd=self.tmp,
                         env_extra={"DEVBREW_SKIP_HOOKS": tok})
                self.assertTrue(self.folder.exists(), "훅은 자기 kill switch 를 거부할 수 없다")
                self.assertTrue(stale.exists(), "꺼진 훅이 다른 세션 폴더를 지웠다")

    def test_16_run_hook_refuses_missing_cwd(self):
        with self.assertRaises(ValueError):
            run_hook({"session_id": self.sid, "cwd": self.tmp})


if __name__ == "__main__":
    unittest.main()
