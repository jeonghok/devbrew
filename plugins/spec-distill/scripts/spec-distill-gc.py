#!/usr/bin/env python3
"""TTL-based GC for spec-distill per-session state folders.

qg-gc.py pattern adaptation:
  - race guard: fcntl lock + double-stat ns + rename-then-rmtree (3-layer)
    락은 state root 디렉토리 자신의 fd(`O_DIRECTORY | O_NOFOLLOW`)에 건다 — 락 파일은 없다.
    루트 아래 고정 이름 파일은 저장소가 링크로 커밋할 수 있어서 열지 않는다.
  - 24h TTL (DEVBREW_SPEC_DISTILL_TTL_HOURS override)
  - self-session protection via CLAUDE_CODE_SESSION_ID or --session-id
  - grace window (60s) for newly-created empty folders
  - ROOT resolved dynamically via state_path.state_root() (worktree compat)
  - 루트가 심볼릭 링크를 거쳐 제자리 밖으로 풀리면(`state_root_escapes`) 락을 잡기 전에
    거부한다. 루트 안의 링크 자식은 세션 폴더로 보지 않는다.
  - .gc-pending-* orphan sweep (>60s) at iteration start

Kill switches:
  DEVBREW_SPEC_DISTILL_DISABLE=1              - no-op
  DEVBREW_SKIP_HOOKS=spec-distill:spec-distill-gc - no-op (이 스크립트 하나만)

훅이 아니지만 `DEVBREW_SKIP_HOOKS` 토큰으로 지목할 이름을 갖는다 — 이관 전에는
이 파일이 `DEVBREW_SKIP_HOOKS` 를 **아예 읽지 않아서**, 사용자가 그 변수로 껐다고
믿어도 이 GC 는 무반응이었다. kill switch 는 opt-out 컨트롤이므로 **더 잘 꺼지는**
방향이고, 회귀는 반대 방향(덜 꺼짐)뿐이다.
"""
from __future__ import annotations

import fcntl
import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from state_path import state_root, state_root_escapes, SESSION_PATTERN  # noqa: E402 # pyright: ignore[reportMissingImports]
from gc_common import (  # noqa: E402 # pyright: ignore[reportMissingImports]
    GC_PENDING_PREFIX, gc_one, safe_rmtree, ttl_ns,
)
from kill_switch_active import kill_switch_active  # noqa: E402

GC_PENDING_SWEEP_AGE_S = 60

# TTL 계산 · 나이 판정 · 안전 삭제 · 폴더 수집은 `shared/gc/gc_common.py` 정본(형제
# 사본 `scripts/gc_common.py`)이 갖는다. 여기 남는 것은 spec-distill 고유 본문이다 —
# git-aware state root(`state_path.state_root`)와 `.gc-pending-*` 고아 스윕.
# `GC_PENDING_PREFIX` 는 정본에서 가져온다: 그 접두를 **쓰는** 쪽(`gc_one`)과
# **줍는** 쪽(아래 스윕)이 갈라지면 고아가 영원히 안 지워진다.


def _verbose() -> bool:
    return os.environ.get("DEVBREW_SPEC_DISTILL_GC_VERBOSE") == "1"


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
        if child.is_symlink() or not child.is_dir():
            continue
        if not child.name.startswith(GC_PENDING_PREFIX):
            continue
        try:
            age = now - child.stat().st_mtime
        except OSError:
            continue
        if age < GC_PENDING_SWEEP_AGE_S:
            continue
        if safe_rmtree(child, root):
            removed += 1
    return removed


def gc(self_session_id: str | None = None) -> int:
    if kill_switch_active("spec-distill", "spec-distill-gc"):
        return 0
    root = state_root()
    if not root.exists():
        return 0
    if state_root_escapes(root):
        print(
            f"[spec-distill] GC 거부 — state root '{root}' 가 심볼릭 링크를 거쳐 "
            f"'{os.path.realpath(root)}' 로 풀린다. 저장소 밖을 지울 수 있어 건너뛴다.",
            file=sys.stderr,
        )
        return 0
    ttl = ttl_ns("DEVBREW_SPEC_DISTILL_TTL_HOURS")
    removed = 0
    # 락은 루트 디렉토리 자신이다. 루트 아래의 고정 이름 파일은 저장소가 링크로 커밋할 수
    # 있어, 그것을 만들거나 열면 링크를 따라 저장소 밖 파일을 만들거나 자른다.
    try:
        dfd = os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    except OSError as exc:
        print(
            f"[spec-distill] GC 거부 — state root '{root}' 를 디렉토리로 열 수 없다(링크 · 디렉토리 아님 · 권한): {exc}",
            file=sys.stderr,
        )
        return 0
    try:
        try:
            fcntl.flock(dfd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return 0
        except OSError as exc:
            print(f"[spec-distill] GC 건너뜀 — state root 락 실패: {exc}", file=sys.stderr)
            return 0
        try:
            removed += _sweep_gc_pending(root)
            for child in root.iterdir():
                if child.is_symlink() or not child.is_dir():
                    continue
                if not SESSION_PATTERN.match(child.name):
                    continue
                if self_session_id and child.name == self_session_id:
                    continue
                try:
                    if gc_one(child, ttl, root):
                        removed += 1
                except OSError as exc:
                    print(
                        f"[spec-distill] GC failed on {child.name}: {exc}",
                        file=sys.stderr,
                    )
        finally:
            try:
                fcntl.flock(dfd, fcntl.LOCK_UN)
            except OSError:
                pass
    finally:
        os.close(dfd)
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
