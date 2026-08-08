#!/usr/bin/env python3
"""TTL-based GC for quality-gates per-session state folders.

Triggers (must be explicit, never SessionStart):
  - setup-qg.sh start (auto, fire-and-forget)
  - /qg --gc, /cancel-qg --gc, /cancel-qg --all (user)

Race guard: 3-layer (fcntl lock + double-stat ns + rename-then-rmtree).

Kill switch: DEVBREW_DISABLE_QUALITY_GATES=1 → no-op.
TTL override: DEVBREW_QG_TTL_HOURS (positive int, default 24).
Verbose: DEVBREW_QG_GC_VERBOSE=1 → print summary line on stdout.
"""
from __future__ import annotations

import fcntl
import os
import re
import shutil
import sys
import time
import uuid
from pathlib import Path

ROOT = Path(".claude/quality-gates")
LOCK_NAME = ".gc.lock"
SESSION_PATTERN = re.compile(r"^[A-Za-z0-9_-]{8,}$")
# 이름의 charset만으로는 세션 폴더와 형제 디렉토리를 구분할 수 없다 —
# `worktrees`(9자)·`baseline-cache`(14자)가 위 패턴을 만족한다. 내용으로 식별한다.
#
# denylist({"worktrees", "baseline-cache"} 제외)를 쓰지 않는 이유: 공간에는 맞지만
# **시간에 fail-open**이다. 내일 추가될 형제 디렉토리를 오늘 열거할 수 없다.
# 마커 기반은 반대로 시간에 fail-closed다 — 새 형제 디렉토리는 자동으로 안전하다.
# 오판 방향도 옳다: 안 지우는 누수(빈 디렉토리 0바이트)가 살아있는 것을 지우는
# 것보다 안전하다.
# `pipeline.md`·`files.md`·`publish-eligible.md`는 SKILL.md가 실제로 쓰는 이름이다.
# `runtime-evidence.md`는 Runtime gate의 evidence-log 이름 —
# agents/runtime-verifier.md:98 및 scripts/detect-runtime.sh:286 이
# `.claude/quality-gates/<sid>/runtime-evidence.md`에 직접 쓴다(실재 확인됨).
# 목록에서 빠진 마커의 오판 방향은 "안 지움"(누수)이라 안전하다 — 반대 방향이 아니다.
SESSION_MARKERS = ("pipeline.md", "files.md", "publish-eligible.md", "runtime-evidence.md")
GRACE_NS = 60 * 1_000_000_000
DOUBLE_STAT_DELAY_S = 0.05


def _is_session_folder(folder: Path) -> bool:
    try:
        return any((folder / name).is_file() for name in SESSION_MARKERS)
    except OSError:
        return False


def _disabled() -> bool:
    return os.environ.get("DEVBREW_DISABLE_QUALITY_GATES") == "1"


def _ttl_ns() -> int:
    raw = os.environ.get("DEVBREW_QG_TTL_HOURS", "24")
    try:
        n = int(raw)
        if n <= 0:
            n = 24
    except ValueError:
        n = 24
    return n * 3600 * 1_000_000_000


def _verbose() -> bool:
    return os.environ.get("DEVBREW_QG_GC_VERBOSE") == "1"


def _folder_mtime_ns(folder: Path) -> int:
    files = [p for p in folder.iterdir() if p.is_file()]
    if not files:
        return folder.stat().st_mtime_ns
    return max(p.stat().st_mtime_ns for p in files)


def _within_grace(folder: Path) -> bool:
    """Protect newly-created empty folders from being GC'd before first write.

    Only applies when folder has no files — once content lands, mtime governs.
    """
    try:
        has_files = any(p.is_file() for p in folder.iterdir())
    except OSError:
        return False
    if has_files:
        return False
    age_ns = time.time_ns() - folder.stat().st_ctime_ns
    return age_ns < GRACE_NS


def _gc_one(folder: Path, ttl_ns: int) -> bool:
    if _within_grace(folder):
        return False
    try:
        snap1 = _folder_mtime_ns(folder)
    except OSError:
        return False
    if time.time_ns() - snap1 < ttl_ns:
        return False
    time.sleep(DOUBLE_STAT_DELAY_S)
    try:
        snap2 = _folder_mtime_ns(folder)
    except OSError:
        return False
    if snap1 != snap2:
        return False
    pending = folder.parent / f".gc-pending-{uuid.uuid4().hex}"
    try:
        folder.rename(pending)
    except OSError:
        return False
    shutil.rmtree(pending, ignore_errors=True)
    return True


def gc(self_session_id: str | None = None) -> int:
    if _disabled() or not ROOT.exists():
        return 0
    lock_path = ROOT / LOCK_NAME
    try:
        lock_path.touch(exist_ok=True)
    except OSError:
        return 0
    ttl_ns = _ttl_ns()
    removed = 0
    with open(lock_path, "w") as lockfile:
        try:
            fcntl.flock(lockfile.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except (BlockingIOError, OSError):
            return 0
        try:
            for child in ROOT.iterdir():
                if not child.is_dir():
                    continue
                if not SESSION_PATTERN.match(child.name):
                    continue
                # 이름 + 내용 **둘 다** 만족해야 sweep — 두 조건의 교집합이
                # 단독보다 좁다. 패턴을 지우지 않고 함께 유지하는 이유가 이것이다.
                if not _is_session_folder(child):
                    continue
                if self_session_id and child.name == self_session_id:
                    continue
                try:
                    if _gc_one(child, ttl_ns):
                        removed += 1
                except OSError as exc:
                    print(
                        f"[quality-gates] GC failed on {child.name}: {exc}",
                        file=sys.stderr,
                    )
        finally:
            try:
                fcntl.flock(lockfile.fileno(), fcntl.LOCK_UN)
            except OSError:
                pass
    if _verbose() and removed > 0:
        print(f"[quality-gates] GC: removed {removed} stale session folder(s)")
    return removed


def main() -> int:
    self_id = os.environ.get("CLAUDE_CODE_SESSION_ID") or None
    args = sys.argv[1:]
    if "--session-id" in args:
        i = args.index("--session-id")
        if i + 1 < len(args):
            self_id = args[i + 1]
    gc(self_id)
    return 0


if __name__ == "__main__":
    sys.exit(main())
