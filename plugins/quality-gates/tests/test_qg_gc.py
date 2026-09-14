"""Tests for scripts/qg-gc.py — TTL-based session-folder GC."""
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

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
        # 락은 state root 디렉토리 자신이다 — 다른 프로세스가 그것을 쥐면 GC 는 조용히 비켜선다.
        import fcntl
        root = self.tmp / ".claude" / "quality-gates"
        root.mkdir(parents=True)
        old = make_session_dir(self.tmp, "lockedsess12", mtime_offset_seconds=-25 * 3600)
        dfd = os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            fcntl.flock(dfd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            proc = run_gc(self.tmp)
            self.assertEqual(proc.returncode, 0)
            self.assertTrue(old.exists(), msg="contended lock must skip GC")
            self.assertEqual(proc.stderr, "", msg="contention must be silent")
        finally:
            os.close(dfd)

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
        # 워크트리 쪽도 늙힌다(7.6.0 · 재리뷰 N-3) — 나이가 하위 전체를 보므로 신선한 `wt` 가 남아 있으면 마커
        # 식별과 무관하게 폴더가 살아, 이 셀이 식별(`_is_session_folder`)을 재지 못한다.
        os.utime(wt / "live.txt", (old, old))
        os.utime(wt, (old, old))
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

    # 7.6.0 · R79 — 폴더 나이는 폴더 자신과 그 아래 **모든 항목**(깊이 무관)의 최신 mtime 이다. 링크는 따라가지
    # 않는다(링크 자신의 mtime 만 센다). 정본 `shared/gc/gc_common.py` 는 spec-distill 과 같이 쓴다.
    def _nested(self, sid, deep_fresh):
        folder = make_session_dir(self.tmp, sid, mtime_offset_seconds=-48 * 3600)  # 마커 pipeline.md · 폴더 늙음
        sub = folder / "nested" / "deeper"
        sub.mkdir(parents=True)
        f = sub / "state.md"
        f.write_text("x")
        old = time.time() - 48 * 3600
        if not deep_fresh:
            os.utime(f, (old, old))
        for p in (sub, sub.parent, folder):   # 깊은 쪽부터
            os.utime(p, (old, old))
        return folder, f

    def test_nested_fresh_file_keeps_folder(self):
        folder, f = self._nested("nestfresh0qg", deep_fresh=True)
        run_gc(self.tmp)
        self.assertTrue(folder.exists(), "두 층 아래 방금 쓴 파일이 있는 세션 폴더를 수집했다 — 나이가 직속 파일만 본다")
        self.assertTrue(f.exists())

    def test_nested_all_old_collected(self):
        folder, _ = self._nested("nestold00qg", deep_fresh=False)
        run_gc(self.tmp)
        self.assertFalse(folder.exists(), "모든 깊이가 늙은 세션 폴더가 수집되지 않았다")

    def test_symlink_to_fresh_outside_file_does_not_keep_folder(self):
        if os.utime not in os.supports_follow_symlinks:
            self.skipTest("이 플랫폼은 링크 자신의 mtime 을 바꿀 수 없다")
        folder, _ = self._nested("nestlink0qg", deep_fresh=False)
        outside = self.tmp / "outside-fresh"
        outside.mkdir()
        target = outside / "fresh.txt"
        target.write_text("fresh")
        old = time.time() - 48 * 3600
        for link in (folder / "evil-link", folder / "nested" / "deeper" / "evil-link"):
            os.symlink(str(target), link)
            os.utime(link, (old, old), follow_symlinks=False)
            os.utime(link.parent, (old, old))
        run_gc(self.tmp)
        self.assertFalse(folder.exists(), "폴더 안 링크가 가리키는 밖의 신선한 파일이 폴더를 살렸다 — 링크를 따라갔다")
        self.assertTrue(target.exists(), "링크 너머 파일을 지웠다")


def _load_gc_common():
    """이 플러그인이 싣는 사본 `scripts/gc_common.py` 를 프로세스 안에서 읽는다 — 패치로 레이스를 재현하려고."""
    import importlib.util
    spec = importlib.util.spec_from_file_location("gc_common_qg_under_test", str(GC.parent / "gc_common.py"))
    gcm = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gcm)
    return gcm


class SnapshotUnstableTest(unittest.TestCase):
    """순회 중 사라진 항목이 있으면 나이 스냅숏은 불안정하다 — 이번 실행은 그 폴더를 수집하지 않는다(7.6.0 · R80).

    원자적 교체(tmp 쓰기 → rename)가 `gc_one` 의 두 번째 스캔 중에 끝나면 tmp 가 lstat 전에 사라진다. 그 항목을
    건너뛰면 두 스냅숏이 같은 늙은 값이라 진행 중인 세션이 걷힌다. `gc_one` 을 직접 부르고 패치로 재현한다.
    """

    def setUp(self):
        self.gcm = _load_gc_common()
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.root = self.tmp / "root"
        self.old = time.time() - 48 * 3600
        self.ttl = 3600 * 1_000_000_000

    def _old_session(self, sid):
        d = self.root / sid
        sub = d / "nested" / "deeper"
        sub.mkdir(parents=True)
        for p in (d / "pipeline.md", sub / "state.md", sub / "state.tmp"):
            p.write_text("x")
            os.utime(p, (self.old, self.old))
        for p in (sub, sub.parent, d):
            os.utime(p, (self.old, self.old))
        return d

    def test_a_file_vanishing_during_second_scan_keeps_folder(self):
        d = self._old_session("unstablefile01")
        real_lstat = os.lstat
        seen = {"n": 0}

        def lstat(path, *args, **kw):
            if os.fspath(path).endswith("state.tmp"):
                seen["n"] += 1
                if seen["n"] >= 2:
                    raise FileNotFoundError(2, "replaced mid-walk", os.fspath(path))
            return real_lstat(path, *args, **kw)

        with mock.patch.object(self.gcm.os, "lstat", side_effect=lstat):
            got = self.gcm.gc_one(d, self.ttl, self.root)
        self.assertGreaterEqual(seen["n"], 2, "두 번째 스캔이 그 항목에 닿지 않았다 — 셀이 공허하다")
        self.assertFalse(got, "두 번째 스캔 중 사라진 항목이 있는데 수집했다")
        self.assertTrue(d.exists())

    def test_b_directory_vanishing_mid_walk_keeps_folder(self):
        d = self._old_session("unstabledir01")
        real_scandir = os.scandir
        target = str(d / "nested" / "deeper")

        def scandir(path=".", *args, **kw):
            if not isinstance(path, int) and os.fspath(path) == target:   # rmtree 는 fd(int)로도 부른다
                raise FileNotFoundError(2, "directory vanished mid-walk", target)
            return real_scandir(path, *args, **kw)

        with mock.patch.object(self.gcm.os, "scandir", side_effect=scandir):
            got = self.gcm.gc_one(d, self.ttl, self.root)
        self.assertFalse(got, "순회 중 사라진 하위 디렉토리가 있는데 수집했다(walk onerror 경로)")
        self.assertTrue(d.exists())

    def test_c_stable_old_folder_still_collected(self):
        d = self._old_session("stableold01")
        got = self.gcm.gc_one(d, self.ttl, self.root)
        self.assertTrue(got, "안정적으로 늙은 폴더를 수집하지 않았다")
        self.assertFalse(d.exists())

    def test_d_folder_mtime_raises_snapshot_unstable(self):
        d = self._old_session("unstablefn01")
        real_lstat = os.lstat

        def lstat(path, *args, **kw):
            if os.fspath(path).endswith("state.tmp"):
                raise FileNotFoundError(2, "vanished", os.fspath(path))
            return real_lstat(path, *args, **kw)

        with mock.patch.object(self.gcm.os, "lstat", side_effect=lstat):
            with self.assertRaises(self.gcm.SnapshotUnstable) as cm:
                self.gcm.folder_mtime_ns(d)
        self.assertIsInstance(cm.exception, OSError)


# ── 루트 안전 (7.5.3) ─────────────────────────────────────────────────────────
# 저장소가 `.claude/quality-gates` 나 그 아래 `.gc.lock` 을 링크 · 디렉토리 · 파일로 커밋해도
# GC 는 저장소 밖을 만들거나 자르거나 지우지 않는다. 락은 루트 디렉토리 자신이다.
# 심는 링크 · 센티널 · 유령 경로는 전부 이 테스트가 만든 임시 디렉토리 `P` 안이고(작업 트리는
# `P/clone`, 센티널은 그 밖 `P/`), GC 를 띄우기 전에 링크가 `P` 안으로 풀리는지 확인한다.


def run_gc_code(cwd, code):
    """GC 를 `python3 -c <code> <GC>` 로 띄운다 — 프로세스 안에서 모듈을 바꿔 치우고 싶을 때."""
    env = os.environ.copy()
    for k in ("DEVBREW_QUALITY_GATES_GC_VERBOSE", "DEVBREW_QUALITY_GATES_TTL_HOURS",
              "DEVBREW_QUALITY_GATES_DISABLE"):
        env.pop(k, None)
    return subprocess.run([sys.executable, "-c", code, str(GC)],
                          capture_output=True, text=True, cwd=cwd, env=env)


class QgGcRootSafetyTest(unittest.TestCase):
    def setUp(self):
        tmp_root = os.path.realpath(tempfile.gettempdir())
        base = os.path.realpath(tempfile.mkdtemp(prefix="qg-gc-rootsafety-"))
        if not (base and os.path.isabs(base) and os.path.isdir(base)
                and base.startswith(tmp_root + os.sep)):
            raise RuntimeError(f"임시 디렉토리가 이상하다: {base!r} (tmp={tmp_root!r})")
        self.P = Path(base)
        self.addCleanup(shutil.rmtree, self.P, ignore_errors=True)
        self.clone = self.P / "clone"
        self.root = self.clone / ".claude" / "quality-gates"
        self.root.mkdir(parents=True)
        self.lock = self.root / ".gc.lock"

    def _stale(self, sid="stalerootsafe01", where=None):
        d = (where or self.root) / sid
        d.mkdir(parents=True)
        f = d / "pipeline.md"
        f.write_text("x\n", encoding="utf-8")
        past = time.time() - 48 * 3600
        os.utime(f, (past, past))
        os.utime(d, (past, past))
        return d

    def _inside_p(self, path):
        real = os.path.realpath(path)
        if not real.startswith(str(self.P) + os.sep):
            raise RuntimeError(f"링크가 P 밖으로 풀린다: {path} → {real} (P={self.P})")
        return real

    def _plant_lock_link(self, name):
        """`.gc.lock -> ../../../<name>` — `P/<name>` 으로 풀리지 않으면 GC 를 띄우지 않는다."""
        os.symlink(os.path.join("..", "..", "..", name), self.lock)
        want = str(self.P / name)
        if self._inside_p(self.lock) != want:
            raise RuntimeError(f"링크가 {os.path.realpath(self.lock)!r} 로 풀린다 — 기대 {want!r}")
        return Path(want)

    def test_a_lock_link_to_outside_file_untouched(self):
        sentinel = self.P / "sentinel.txt"
        sentinel.write_bytes(b"0123456789abcdef0123456789abcdef")
        past = time.time() - 3600
        os.utime(sentinel, (past, past))
        before = (sentinel.read_bytes(), os.stat(sentinel).st_mtime_ns)
        self.assertEqual(self._plant_lock_link("sentinel.txt"), sentinel)
        stale = self._stale()
        p_before = sorted(os.listdir(self.P))
        proc = run_gc(self.clone)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(sentinel.read_bytes(), before[0],
                         "심은 .gc.lock 링크를 따라 저장소 밖 파일을 잘랐다")
        self.assertEqual(os.stat(sentinel).st_mtime_ns, before[1],
                         "심은 .gc.lock 링크를 따라 저장소 밖 파일을 건드렸다(touch)")
        self.assertTrue(self.lock.is_symlink(), "심은 링크를 바꿨다")
        self.assertFalse(stale.exists(), "GC 가 돌지 않았다 — 위 단언들이 공허하다")
        self.assertEqual(sorted(os.listdir(self.root)), [".gc.lock"],
                         "GC 가 루트에 심은 링크 말고 다른 이름을 남겼다")
        self.assertEqual(sorted(os.listdir(self.P)), p_before, "GC 가 저장소 밖 목록을 바꿨다")

    def test_b_dangling_lock_link_target_not_created(self):
        ghost = self._plant_lock_link("ghost.txt")
        self.assertFalse(os.path.lexists(ghost))
        stale = self._stale()
        p_before = sorted(os.listdir(self.P))
        proc = run_gc(self.clone)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(sorted(os.listdir(self.P)), p_before,
                         "매달린 .gc.lock 링크를 따라 저장소 밖에 파일을 만들었다")
        self.assertFalse(stale.exists(), "GC 가 돌지 않았다 — 위 단언이 공허하다")
        self.assertEqual(sorted(os.listdir(self.root)), [".gc.lock"])

    def test_c_lock_name_as_directory_gc_still_runs(self):
        self.lock.mkdir()
        stale = self._stale()
        proc = run_gc(self.clone)
        self.assertEqual(proc.returncode, 0)
        self.assertFalse(stale.exists(),
                         f"디렉토리로 심은 .gc.lock 이 GC 를 멈췄다 — stderr: {proc.stderr.strip()}")
        self.assertEqual(sorted(os.listdir(self.root)), [".gc.lock"])

    def test_d_real_root_no_lock_file_and_collects(self):
        stale = self._stale()
        proc = run_gc(self.clone)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertFalse(stale.exists())
        self.assertEqual(sorted(os.listdir(self.root)), [],
                         "GC 가 루트에 파일을 남겼다 — 고정 이름 파일을 만드는 경로가 살아 있다")

    def test_e_root_dir_lock_held_elsewhere_gc_yields_silently(self):
        import fcntl
        stale = self._stale()
        dfd = os.open(self.root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            fcntl.flock(dfd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            proc = run_gc(self.clone)
            self.assertEqual(proc.returncode, 0)
            self.assertTrue(stale.exists(), "루트 디렉토리 락을 쥔 동안 GC 가 지웠다 — 락이 걸리지 않는다")
            self.assertEqual(proc.stderr, "", "경합으로 비켜서는 GC 가 줄을 냈다 — 경합은 조용해야 한다")
        finally:
            os.close(dfd)
        run_gc(self.clone)
        self.assertFalse(stale.exists(), "락을 놓은 뒤에도 GC 가 돌지 않았다")

    def test_f_flock_failure_announced(self):
        stale = self._stale()
        code = (
            "import errno, fcntl, runpy, sys\n"
            "def _boom(*a, **k):\n"
            "    raise OSError(errno.EBADF, 'Bad file descriptor')\n"
            "fcntl.flock = _boom\n"
            "sys.argv = sys.argv[1:]\n"
            "runpy.run_path(sys.argv[0], run_name='__main__')\n"
        )
        proc = run_gc_code(self.clone, code)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("[quality-gates] GC 건너뜀 — state root 락 실패", proc.stderr)
        self.assertTrue(stale.exists(), "락을 못 잡았는데 GC 가 돌았다")

    def test_g_root_regular_file_refused(self):
        self.root.rmdir()
        self.root.write_text("not a directory\n", encoding="utf-8")
        proc = run_gc(self.clone)
        self.assertEqual(proc.returncode, 0)
        self.assertIn("[quality-gates] GC 거부", proc.stderr)
        self.assertNotIn("Traceback", proc.stderr)
        self.assertEqual(self.root.read_text(encoding="utf-8"), "not a directory\n")

    def test_h_symlinked_root_refused(self):
        self.root.rmdir()
        elsewhere = self.P / "elsewhere"
        stale = self._stale(where=elsewhere)
        os.symlink(os.path.join("..", "..", "elsewhere"), self.root)
        self.assertEqual(self._inside_p(self.root), str(elsewhere))
        proc = run_gc(self.clone)
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(stale.exists(), "링크 루트 너머의 세션 모양 디렉토리를 지웠다")
        self.assertEqual(sorted(os.listdir(elsewhere)), [stale.name],
                         "링크 루트 너머에 무언가를 만들었다")
        self.assertIn("[quality-gates] GC 거부", proc.stderr)

    def test_i_symlinked_child_untouched(self):
        outside = self._stale(sid="outsidevictim01", where=self.P)
        link = self.root / "linksession0001"
        os.symlink(str(outside), link)
        # 링크 자신의 mtime 도 늙힌다(7.6.0 · 재리뷰 N-1) — 나이는 폴더 자신의 lstat 을 세므로, 방금 만든 링크의
        # 신선한 mtime 이 링크 자식 skip 없이도 링크를 살려 이 셀이 공허해진다.
        past = time.time() - 48 * 3600
        os.utime(link, (past, past), follow_symlinks=False)
        self.assertEqual(self._inside_p(link), str(outside))
        proc = run_gc(self.clone)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertTrue(link.is_symlink(), "링크 자식을 개명하거나 지웠다")
        self.assertTrue((outside / "pipeline.md").exists())
        self.assertEqual(sorted(os.listdir(self.root)), ["linksession0001"])

    def test_j_symlinked_claude_dir_refused(self):
        # `.claude` 자신이 링크면 루트의 마지막 성분은 진짜 디렉토리라 `O_NOFOLLOW` 가 못 막는다 —
        # 이 경우는 탈출 판정(`root_escapes`)만이 막는다.
        shutil.rmtree(self.clone / ".claude")
        elsewhere = self.P / "elsewhere-claude"
        stale = self._stale(where=elsewhere / "quality-gates")
        os.symlink(os.path.join("..", "elsewhere-claude"), self.clone / ".claude")
        self.assertEqual(self._inside_p(self.root), str(elsewhere / "quality-gates"))
        proc = run_gc(self.clone)
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(stale.exists(), "링크된 .claude 너머의 세션 모양 디렉토리를 지웠다")
        self.assertEqual(sorted(os.listdir(elsewhere / "quality-gates")), [stale.name],
                         "링크된 .claude 너머에 무언가를 만들었다")
        self.assertIn("[quality-gates] GC 거부", proc.stderr)

    def test_k_dangling_root_link_announced(self):
        # 매달린 루트 링크 — 지울 것은 없지만 조용히 끝나면 뒤이은 `setup-qg.sh` 의 `mkdir -p` 가
        # 링크 너머(저장소 밖)에 폴더를 만드는 동안 아무도 모른다. 존재 검사보다 탈출 판정이 먼저다.
        self.root.rmdir()
        os.symlink(os.path.join("..", "..", "ghost-root"), self.root)
        self.assertEqual(self._inside_p(self.root), str(self.P / "ghost-root"))
        self.assertFalse(os.path.exists(self.root))
        p_before = sorted(os.listdir(self.P))
        proc = run_gc(self.clone)
        self.assertEqual(proc.returncode, 0)
        self.assertIn("[quality-gates] GC 거부", proc.stderr)
        self.assertEqual(sorted(os.listdir(self.P)), p_before, "매달린 루트 링크 너머에 무언가를 만들었다")

    def test_l_symlinked_claude_without_root_announced(self):
        # `.claude -> <밖>` 인데 밖에 quality-gates 가 아직 없다 — 같은 이유로 알린다.
        shutil.rmtree(self.clone / ".claude")
        elsewhere = self.P / "elsewhere-claude-empty"
        elsewhere.mkdir()
        os.symlink(os.path.join("..", "elsewhere-claude-empty"), self.clone / ".claude")
        self.assertEqual(self._inside_p(self.clone / ".claude"), str(elsewhere))
        proc = run_gc(self.clone)
        self.assertEqual(proc.returncode, 0)
        self.assertIn("[quality-gates] GC 거부", proc.stderr)
        self.assertEqual(sorted(os.listdir(elsewhere)), [], "링크된 .claude 너머에 무언가를 만들었다")

    def test_m_no_claude_dir_stays_silent(self):
        # 음의 짝 — `.claude` 가 아예 없는 평범한 저장소에서는 여전히 아무 줄도 내지 않는다.
        shutil.rmtree(self.clone / ".claude")
        proc = run_gc(self.clone)
        self.assertEqual(proc.returncode, 0)
        self.assertEqual(proc.stderr, "", "루트가 없는 평범한 저장소에서 GC 가 줄을 냈다")

    def test_n_refusal_line_does_not_echo_link_target(self):
        # 거부 줄은 링크가 가리키는 곳을 옮겨 적지 않는다 — 그 이름은 저장소가 정한 문자열이고,
        # 이 stderr 는 `/qg` 시작 경로에서 모델에게 보인다.
        self.root.rmdir()
        target = self.P / "INJECTMARK-target"
        target.mkdir()
        os.symlink(os.path.join("..", "..", "INJECTMARK-target"), self.root)
        self.assertEqual(self._inside_p(self.root), str(target))
        proc = run_gc(self.clone)
        self.assertEqual(proc.returncode, 0)
        self.assertIn("[quality-gates] GC 거부", proc.stderr)
        self.assertNotIn("INJECTMARK", proc.stderr, "거부 줄이 링크 대상 이름을 옮겨 적었다")


class SetupForwardsGcStderr(unittest.TestCase):
    def test_setup_gc_call_does_not_discard_stderr(self):
        # GC 의 거부 · 락 실패 줄은 `/qg` 시작마다 도는 이 자동 경로에서 보여야 한다.
        setup = GC.parent / "setup-qg.sh"
        calls = [ln for ln in setup.read_text(encoding="utf-8").splitlines()
                 if "qg-gc.py" in ln and not ln.lstrip().startswith("#")]
        self.assertEqual(len(calls), 1, f"setup-qg.sh 의 GC 호출 줄이 하나가 아니다: {calls}")
        self.assertNotIn("2>", calls[0], f"GC 호출이 stderr 를 돌린다: {calls[0]}")
        # `&>/dev/null` · `>/dev/null 2>&1` 처럼 `2>` 없이 버리는 모양도 막는다.
        self.assertNotIn("/dev/null", calls[0], f"GC 호출이 출력을 버린다: {calls[0]}")


if __name__ == "__main__":
    unittest.main()
