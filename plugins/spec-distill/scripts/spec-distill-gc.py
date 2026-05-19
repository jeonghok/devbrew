#!/usr/bin/env python3
"""TTL-based GC for spec-distill per-session state folders.

qg-gc.py pattern adaptation:
  - race guard: fcntl lock + double-stat ns + rename-then-rmtree (3-layer)
  - 24h TTL (DEVBREW_SPEC_DISTILL_TTL_HOURS override)
  - self-session protection via CLAUDE_CODE_SESSION_ID or --session-id
  - grace window (60s) for newly-created empty folders
  - ROOT resolved dynamically via state_path.state_root() (worktree compat)
  - .gc-pending-* orphan sweep (>60s) at iteration start

Kill switches:
  DEVBREW_DISABLE_SPEC_DISTILL=1     - no-op
"""
from __future__ import annotations

import fcntl
import os
import shutil
import sys
import time
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent / "hooks"
sys.path.insert(0, str(HERE))
from state_path import state_root, SESSION_PATTERN  # noqa: E402 # pyright: ignore[reportMissingImports]

LOCK_NAME = ".gc.lock"
GRACE_NS = 60 * 1_000_000_000
DOUBLE_STAT_DELAY_S = 0.05
GC_PENDING_PREFIX = ".gc-pending-"
GC_PENDING_SWEEP_AGE_S = 60


def _disabled() -> bool:
    return os.environ.get("DEVBREW_DISABLE_SPEC_DISTILL") == "1"


def _ttl_ns() -> int:
    raw = os.environ.get("DEVBREW_SPEC_DISTILL_TTL_HOURS", "24")
    try:
        n = int(raw)
        if n <= 0:
            n = 24
    except ValueError:
        n = 24
    return n * 3600 * 1_000_000_000


def _verbose() -> bool:
    return os.environ.get("DEVBREW_SPEC_DISTILL_GC_VERBOSE") == "1"


def _folder_mtime_ns(folder: Path) -> int:
    files = [p for p in folder.iterdir() if p.is_file()]
    if not files:
        return folder.stat().st_mtime_ns
    return max(p.stat().st_mtime_ns for p in files)


def _within_grace(folder: Path) -> bool:
    try:
        has_files = any(p.is_file() for p in folder.iterdir())
    except OSError:
        return False
    if has_files:
        return False
    age_ns = time.time_ns() - folder.stat().st_ctime_ns
    return age_ns < GRACE_NS


def _sweep_gc_pending(root: Path) -> int:
    """Remove leftover .gc-pending-<uuid> folders older than 60s.

    Defends against qg-gc.py's known edge: timeout-aborted rename mid-rmtree
    leaves .gc-pending-* orphans because SESSION_PATTERN rejects the name.

    Uses st_mtime (settable via os.utime) rather than st_ctime for age check
    — on macOS st_ctime is always updated by os.utime (reflects metadata change),
    making ctime-based tests unreliable. mtime reflects last-content-modification
    and is directly controllable in tests.
    """
    removed = 0
    now = time.time()
    for child in root.iterdir():
        if not child.is_dir():
            continue
        if not child.name.startswith(GC_PENDING_PREFIX):
            continue
        try:
            age = now - child.stat().st_mtime
        except OSError:
            continue
        if age < GC_PENDING_SWEEP_AGE_S:
            continue
        shutil.rmtree(child, ignore_errors=True)
        removed += 1
    return removed


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
    pending = folder.parent / f"{GC_PENDING_PREFIX}{uuid.uuid4().hex}"
    try:
        folder.rename(pending)
    except OSError:
        return False
    shutil.rmtree(pending, ignore_errors=True)
    return True


def gc(self_session_id: str | None = None) -> int:
    if _disabled():
        return 0
    root = state_root()
    if not root.exists():
        return 0
    lock_path = root / LOCK_NAME
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
            removed += _sweep_gc_pending(root)
            for child in root.iterdir():
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
                        f"[spec-distill] GC failed on {child.name}: {exc}",
                        file=sys.stderr,
                    )
        finally:
            try:
                fcntl.flock(lockfile.fileno(), fcntl.LOCK_UN)
            except OSError:
                pass
    if _verbose() and removed > 0:
        print(f"[spec-distill] GC: removed {removed} stale folder(s)")
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
