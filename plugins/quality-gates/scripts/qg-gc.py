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
GRACE_NS = 60 * 1_000_000_000
DOUBLE_STAT_DELAY_S = 0.05


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
    lock_path.touch(exist_ok=True)
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
