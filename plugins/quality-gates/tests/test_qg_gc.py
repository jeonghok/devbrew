"""Tests for scripts/qg-gc.py — TTL-based session-folder GC."""
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

GC = Path(__file__).resolve().parent.parent / "scripts" / "qg-gc.py"


def run_gc(cwd, env_extra=None, args=None):
    env = os.environ.copy()
    env.pop("DEVBREW_QUALITY_GATES_GC_VERBOSE", None)
    env.pop("DEVBREW_QUALITY_GATES_TTL_HOURS", None)
    env.pop("DEVBREW_QUALITY_GATES_DISABLE", None)
    if env_extra:
        env.update(env_extra)
    cmd = [sys.executable, str(GC)]
    if args:
        cmd.extend(args)
    return subprocess.run(cmd, capture_output=True, text=True, cwd=cwd, env=env)


def make_session_dir(root, sid, mtime_offset_seconds=0, ctime_offset_seconds=0):
    folder = root / ".claude" / "quality-gates" / sid
    folder.mkdir(parents=True, exist_ok=True)
    f = folder / "pipeline.md"
    f.write_text("---\nstatus: gate2_running\n---\n")
    if mtime_offset_seconds:
        new_time = time.time() + mtime_offset_seconds
        os.utime(f, (new_time, new_time))
        os.utime(folder, (new_time, new_time))
    return folder


class TestQgGc(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

    def test_old_folder_removed(self):
        old = make_session_dir(self.tmp, "abcd1234efgh", mtime_offset_seconds=-25 * 3600)
        proc = run_gc(self.tmp, env_extra={"DEVBREW_QUALITY_GATES_GC_VERBOSE": "1"})
        self.assertEqual(proc.returncode, 0, msg=proc.stderr)
        self.assertFalse(old.exists(), msg=f"stale folder should be removed; stderr={proc.stderr}")
        self.assertIn("removed 1", proc.stdout)

    def test_fresh_folder_kept(self):
        fresh = make_session_dir(self.tmp, "freshsess99", mtime_offset_seconds=-60)
        proc = run_gc(self.tmp)
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(fresh.exists())

    def test_self_session_excluded(self):
        sid = "selfsess1234"
        own = make_session_dir(self.tmp, sid, mtime_offset_seconds=-25 * 3600)
        proc = run_gc(self.tmp, env_extra={"CLAUDE_CODE_SESSION_ID": sid})
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(own.exists(), msg="self session must never be GC'd")

    def test_pattern_guard_skips_short_names(self):
        bad = self.tmp / ".claude" / "quality-gates" / "short"
        bad.mkdir(parents=True)
        (bad / "pipeline.md").write_text("x")
        old = time.time() - 25 * 3600
        os.utime(bad / "pipeline.md", (old, old))
        os.utime(bad, (old, old))
        run_gc(self.tmp)
        self.assertTrue(bad.exists(), msg="non-pattern folders must not be GC'd")

    def test_grace_period_protects_empty_new_folder(self):
        new = self.tmp / ".claude" / "quality-gates" / "newsess12345"
        new.mkdir(parents=True)
        proc = run_gc(self.tmp)
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(new.exists(), msg="folders within ctime grace must not be GC'd")

    def test_kill_switch(self):
        old = make_session_dir(self.tmp, "killsess1234", mtime_offset_seconds=-25 * 3600)
        proc = run_gc(self.tmp, env_extra={"DEVBREW_QUALITY_GATES_DISABLE": "1"})
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(old.exists(), msg="kill switch must skip GC")

    def test_lock_contention_silent_exit(self):
        import fcntl
        root = self.tmp / ".claude" / "quality-gates"
        root.mkdir(parents=True)
        lockpath = root / ".gc.lock"
        lockpath.touch()
        old = make_session_dir(self.tmp, "lockedsess12", mtime_offset_seconds=-25 * 3600)
        with open(lockpath, "w") as lf:
            fcntl.flock(lf.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            proc = run_gc(self.tmp)
            self.assertEqual(proc.returncode, 0)
            self.assertTrue(old.exists(), msg="contended lock must skip GC")

    def test_session_id_arg_overrides_env(self):
        sid = "argsession12"
        own = make_session_dir(self.tmp, sid, mtime_offset_seconds=-25 * 3600)
        proc = run_gc(self.tmp, args=["--session-id", sid])
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(own.exists())

    def test_invalid_ttl_falls_back_to_default(self):
        old = make_session_dir(self.tmp, "ttlsess12345", mtime_offset_seconds=-25 * 3600)
        proc = run_gc(self.tmp, env_extra={"DEVBREW_QUALITY_GATES_TTL_HOURS": "not-a-number"})
        self.assertEqual(proc.returncode, 0)
        self.assertFalse(old.exists(), msg="invalid TTL should fall back to 24h")

    # T49 — **실패 재현**. 이 테스트는 수정 *전에* 빨개져야 한다:
    # TTL 초과 + 직접 파일 없는 `worktrees` 디렉토리가 현재 코드에서 삭제된다.
    #
    # 브리프 원안은 `worktrees/`에 직접 파일을 두지 않고 os.utime()으로 그
    # 디렉토리 자신의 mtime만 backdating했다. 그러나 os.utime()은 atime/mtime만
    # 되돌릴 뿐 ctime은 항상 "지금"으로 갱신된다 — `_within_grace`는 직접 파일이
    # 없는 폴더에서 ctime 신선도로 "방금 생성됨"을 판정하므로, 원안 그대로는
    # grace-period 가드가 60초 이내의 신선한 ctime을 보고 **결함과 무관하게**
    # 폴더를 보호해 버린다(수정 전/후 모두 GREEN — 실측: 수정 전 코드로 실행해도
    # `wt.exists()`가 True). 이빨 없는 락이 되므로, `worktrees/`에 직접 마커
    # 파일을 하나 두어 `_within_grace`의 has_files 체크를 정상적으로 지나가게
    # 하고 `_folder_mtime_ns`가 그 파일의 (backdate 가능한) mtime을 쓰도록
    # 바꿨다. "직접 파일이 없는 폴더" 자체보다 "패턴만으로 세션 폴더가 아닌 형제
    # 디렉토리가 지워진다"는 결함의 본질은 그대로 보존한다.
    def test_worktrees_dir_survives_gc(self):
        root = Path(self.tmp)
        wt_parent = root / ".claude" / "quality-gates" / "worktrees"
        wt = wt_parent / "rt-abc12345"
        wt.mkdir(parents=True)
        (wt / "live.txt").write_text("살아있는 워크트리", encoding="utf-8")
        marker = wt_parent / ".worktrees-index"
        marker.write_text("rt-abc12345\n", encoding="utf-8")
        old = time.time() - 48 * 3600
        os.utime(marker, (old, old))
        os.utime(wt_parent, (old, old))
        run_gc(self.tmp)
        self.assertTrue(
            wt.exists(),
            "TTL 초과 worktrees/ 가 GC됨 — 안에 살아있는 워크트리가 있는데도",
        )

    # AC27(2) — baseline-cache/ 도 세션 폴더가 아니다
    def test_baseline_cache_dir_survives_gc(self):
        root = Path(self.tmp)
        cache = root / ".claude" / "quality-gates" / "baseline-cache"
        cache.mkdir(parents=True)
        f = cache / "abc123def456.md"
        f.write_text("<!-- qg-baseline-cache:v1 -->\n", encoding="utf-8")
        old = time.time() - 48 * 3600
        os.utime(f, (old, old))
        os.utime(cache, (old, old))
        run_gc(self.tmp)
        self.assertTrue(f.exists(), "TTL 초과 baseline-cache/ 가 GC됨")

    # T19 후반 + M2 — 반대 방향: 진짜 세션 폴더는 **여전히** 삭제된다.
    # 이 assert가 없으면 "아무것도 안 지우게" 만든 mutation이 GREEN이 된다.
    def test_real_session_folder_still_collected(self):
        folder = make_session_dir(Path(self.tmp), "sess" + "a" * 8,
                                  mtime_offset_seconds=-48 * 3600)
        run_gc(self.tmp)
        self.assertFalse(folder.exists(), "TTL 초과 세션 폴더가 수집되지 않음")

    # AC28 — 마커 파일이 `publish-eligible.md` 하나뿐인 세션 폴더도 수집된다.
    def test_session_identified_by_publish_eligible_md(self):
        root = Path(self.tmp)
        folder = root / ".claude" / "quality-gates" / ("sess" + "b" * 8)
        folder.mkdir(parents=True)
        f = folder / "publish-eligible.md"
        f.write_text("- a.py\n", encoding="utf-8")
        old = time.time() - 48 * 3600
        os.utime(f, (old, old))
        os.utime(folder, (old, old))
        run_gc(self.tmp)
        self.assertFalse(folder.exists(), "publish-eligible.md 만 있는 세션 폴더가 수집되지 않음")

    # M2 — 업그레이드 누수. 4.x 가 남긴 폴더는 유일한 파일이 `files.md` 인 경우가
    # 있다(세션 tracker 가 파일을 적었지만 /qg 를 한 번도 안 돌린 세션). 5.0.0 이
    # 그 생산자를 지워도 **이미 디스크에 있는 폴더는 남는다** — 어느 마커도 안 맞아
    # 영원히 회수되지 않는다. 기존 사용자 전원에게 실재하는 누수다.
    def test_legacy_4x_files_md_folder_collected(self):
        root = Path(self.tmp)
        folder = root / ".claude" / "quality-gates" / ("sess" + "c" * 8)
        folder.mkdir(parents=True)
        f = folder / "files.md"
        f.write_text("- a.py\n", encoding="utf-8")
        old = time.time() - 48 * 3600
        os.utime(f, (old, old))
        os.utime(folder, (old, old))
        run_gc(self.tmp)
        self.assertFalse(
            folder.exists(),
            "4.x 잔여 폴더(files.md 단독)가 회수되지 않는다 — 업그레이드 누수",
        )

    # 위 회수가 형제 디렉토리까지 넓히지 않았다는 음의 짝: 이름이 세션 패턴을
    # 만족하고 TTL 도 넘겼지만 마커가 하나도 없는 폴더는 여전히 건드리지 않는다.
    # (`test_baseline_cache_dir_survives_gc` 는 특정 이름을 재는 반면 이것은
    # "마커 없음" 이라는 성질 자체를 잰다 — legacy 마커 추가가 식별을
    # 「아무 폴더나」로 무너뜨리면 여기서 RED 다.)
    def test_unmarked_sibling_dir_still_survives(self):
        root = Path(self.tmp)
        sib = root / ".claude" / "quality-gates" / "someothersibling"
        sib.mkdir(parents=True)
        f = sib / "not-a-marker.md"
        f.write_text("x\n", encoding="utf-8")
        old = time.time() - 48 * 3600
        os.utime(f, (old, old))
        os.utime(sib, (old, old))
        run_gc(self.tmp)
        self.assertTrue(f.exists(), "마커 없는 형제 디렉토리가 GC됐다")


if __name__ == "__main__":
    unittest.main()
