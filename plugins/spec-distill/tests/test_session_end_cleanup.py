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


class SymlinkedStateRootTest(unittest.TestCase):
    """AC17 — 저장소가 커밋한 링크로 state root 가 저장소 밖으로 풀리면 GC·정리가 지우지 않는다.

    양성 짝은 위 `test_9_gc_collects_stale_other_session`(진짜 루트에서는 같은 훅이 지운다)이다.
    심는 링크와 피해 디렉토리는 전부 이 테스트가 만든 임시 디렉토리 `P` 안이고, 훅을 띄우기 전에
    링크가 `P` 안으로 풀리는지 확인한다 — 저장소나 $HOME 을 가리키는 것은 없다.
    """

    def setUp(self):
        tmp_root = os.path.realpath(tempfile.gettempdir())
        base = os.path.realpath(tempfile.mkdtemp(prefix="sd-gc-symlink-"))
        # mktemp 가 빈 값·엉뚱한 곳을 내면 아래 링크가 그 기준으로 풀린다 — 여기서 멈춘다.
        if not (base and os.path.isabs(base) and os.path.isdir(base)
                and base.startswith(tmp_root + os.sep)):
            raise RuntimeError(f"임시 디렉토리가 이상하다: {base!r} (tmp={tmp_root!r})")
        self.P = Path(base)
        self.clone = self.P / "clone"
        self.clone.mkdir()
        subprocess.run(["git", "init", "-q"], cwd=self.clone, check=True)

    def tearDown(self):
        shutil.rmtree(self.P, ignore_errors=True)

    def _victim(self, d: Path, age_s: float = 2 * 86400) -> Path:
        d.mkdir(parents=True)
        f = d / "notes.txt"
        f.write_text("precious\n")
        t = time.time() - age_s
        os.utime(f, (t, t))
        os.utime(d, (t, t))
        return f

    def _commit_link(self, link: Path, target: str, resolves_to: Path):
        os.symlink(target, link)
        real = os.path.realpath(self.clone / ".claude" / "spec-distill")
        # 계측기 바닥 — 링크가 기대한 곳(이 테스트의 P 안)으로 풀리지 않으면 훅을 띄우지 않는다.
        if real != os.path.realpath(resolves_to) or not (
                real == str(self.P) or real.startswith(str(self.P) + os.sep)):
            raise RuntimeError(f"링크가 {real!r} 로 풀린다 — P={self.P} 밖이다")
        git = ["git", "-c", "user.email=t@t", "-c", "user.name=t"]
        subprocess.run(git + ["add", "-A"], cwd=self.clone, check=True)
        subprocess.run(git + ["commit", "-qm", "plant link"], cwd=self.clone, check=True)

    def test_symlinked_root_gc_refused(self):
        """`.claude/spec-distill -> ../..` — GC 의 루트가 P 로 풀린다."""
        victim = self._victim(self.P / "victim-dir-01")
        (self.clone / ".claude").mkdir()
        self._commit_link(self.clone / ".claude" / "spec-distill", "../..", self.P)
        rc, _, stderr = run_hook(None, cwd=str(self.clone), raw_stdin=b"")
        self.assertEqual(rc, 0)
        self.assertTrue(victim.exists(), "저장소 밖 디렉토리를 GC 가 지웠다")
        self.assertFalse((self.P / ".gc.lock").exists(), "저장소 밖에 GC 락 파일을 만들었다")
        self.assertIn("GC 거부", stderr)

    def test_symlinked_claude_dir_gc_refused(self):
        """`.claude -> ../outside` — 루트 자신이 아니라 그 부모가 링크다."""
        victim = self._victim(self.P / "outside" / "spec-distill" / "victim-dir-02")
        self._commit_link(self.clone / ".claude", "../outside",
                          self.P / "outside" / "spec-distill")
        rc, _, stderr = run_hook(None, cwd=str(self.clone), raw_stdin=b"")
        self.assertEqual(rc, 0)
        self.assertTrue(victim.exists(), "링크된 .claude 너머의 디렉토리를 GC 가 지웠다")
        self.assertFalse((self.P / "outside" / "spec-distill" / ".gc.lock").exists())
        self.assertIn("GC 거부", stderr)

    def test_symlinked_root_session_cleanup_refused(self):
        """payload sid 가 링크 너머의 디렉토리 이름과 같으면 ② 정리가 그것을 지우던 자리 — 나이와 무관하다."""
        victim = self._victim(self.P / "victim-dir-03", age_s=0)
        (self.clone / ".claude").mkdir()
        self._commit_link(self.clone / ".claude" / "spec-distill", "../..", self.P)
        rc, _, stderr = run_hook({"session_id": "victim-dir-03", "cwd": str(self.clone)},
                                 cwd=str(self.clone))
        self.assertEqual(rc, 0)
        self.assertTrue(victim.exists(), "세션 정리가 링크 너머의 디렉토리를 지웠다")
        self.assertIn("세션 정리 거부", stderr)


if __name__ == "__main__":
    unittest.main()
