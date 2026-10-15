#!/usr/bin/env python3
"""spec-distill — 리뷰 진입 때 한 번 도는 원장 정리(설계 §3-2).

  ① `<state-root>/.docreview/<키>/` 중 기록된 문서가 없는 원장을 지운다 — `gc_one` 의 TTL 검사를 그대로 받는다.
     원장을 읽지 못하면 지우지 않고 알린다.
  ② 옛 세션 폴더 `<state-root>/<sid>/`(세션 이름 정규식) 중 `state.local.md` 가 없고 TTL 을 넘은 것을 지운다.
     지우기 전에 기록된 문서가 있는 옛 원장 `docreview/<x>/` 를 `.docreview/<새 키>/` 로 옮긴다.
  ③ `state.local.md` 가 있는 옛 세션 폴더는 시간과 무관하게 지우지 않고 알린다.
  안전: (a) 루트 디렉토리 잠금 (b) `.docreview` 링크 · 탈출 거부 (c) `.gc-pending-*` 줍기(두 자리).
  링크: 저장소가 심은 링크는 따라가지 않는다 — 옛 원장 경로가 `inside_root` 를 통과하지 못하거나, 옮길 대상
  이름이 링크이거나, 상태 파일이 링크면 그 원장은 「읽지 못한 원장」 으로 세고 옮기지도 지우지도 않는다.

Kill switches: DEVBREW_SPEC_DISTILL_DISABLE=1 · DEVBREW_SKIP_HOOKS 의 spec-distill:SessionEnd ·
spec-distill:session-end-cleanup · spec-distill:spec-distill-gc — 셋 다 이 정리를 끈다.
TTL: DEVBREW_SPEC_DISTILL_TTL_HOURS(기본 24) — ① 의 삭제 유예와 ② 의 판정 두 자리에 쓴다.
"""
from __future__ import annotations

import argparse
import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from state_path import SESSION_PATTERN, inside_root, state_root  # noqa: E402
from gc_common import (  # noqa: E402
    GC_PENDING_PREFIX, folder_mtime_ns, gc_one, locked_root, root_escapes, safe_rmtree, ttl_ns,
)
from kill_switch_active import kill_switch_active  # noqa: E402
import docreview_state  # noqa: E402
from docreview_state import STATE_SUBDIR, load_state, state_dir_for  # noqa: E402

MARKER = "reviewing-by"
STATE_FILE = "docreview-state.md"
OLD_SUBDIR = "docreview"
LEGACY_INTERVIEW = "state.local.md"
PENDING_SWEEP_AGE_S = 60


class Report:
    def __init__(self) -> None:
        self.docless = 0
        self.old_removed = 0
        self.moved = 0
        self.conflicts: list[str] = []
        self.preserved: list[str] = []
        self.unread: list[str] = []
        self.uncountable: list[str] = []


def disabled() -> bool:
    return (kill_switch_active("spec-distill", "session-end-cleanup", "SessionEnd")
            or kill_switch_active("spec-distill", "spec-distill-gc"))


def recorded_doc(ledger_dir: Path) -> str | None:
    if (ledger_dir / STATE_FILE).is_symlink():
        return None
    try:
        st = load_state(ledger_dir)
    except Exception:
        return None
    doc = st.get("doc")
    # 상대 경로면 있고 없음이 cwd 에 달린다 — 문서 경로를 얻지 못한 것으로 친다(엔진도 절대 경로만 받는다).
    return doc if isinstance(doc, str) and os.path.isabs(doc) else None


def ledger_root_bad(root: Path) -> bool:
    lr = root / STATE_SUBDIR
    return lr.is_symlink() or (os.path.lexists(lr) and os.path.realpath(lr) != os.path.join(
        os.path.realpath(root), STATE_SUBDIR))


def ledger_root_ok(root: Path, rep: Report) -> bool:
    if ledger_root_bad(root):
        rep.uncountable.append("{0} 가 링크이거나 루트 밖으로 풀린다".format(root / STATE_SUBDIR))
        return False
    return True


def may_enter(dest: Path, root: Path) -> bool:
    """`os.rename` 으로 `dest` 에 들어가기 직전 — 부모가 검증된 `.docreview` 디렉토리이고 `dest` 이름이 비었다."""
    lr = root / STATE_SUBDIR
    return (dest.parent == lr and lr.is_dir() and not ledger_root_bad(root)
            and not os.path.lexists(dest))


def sweep_pending(parent: Path, root: Path) -> None:
    if parent.is_symlink() or not parent.is_dir():
        return
    now = time.time()
    for child in parent.iterdir():
        if child.is_symlink() or not child.is_dir() or not child.name.startswith(GC_PENDING_PREFIX):
            continue
        try:
            if now - child.stat().st_mtime < PENDING_SWEEP_AGE_S:
                continue
        except OSError:
            continue
        safe_rmtree(child, root)


def sweep_ledgers(root: Path, ttl: int, rep: Report) -> None:
    lr = root / STATE_SUBDIR
    if not lr.is_dir():
        return
    for child in sorted(lr.iterdir()):
        if child.name.startswith(".") or not (child.is_symlink() or child.is_dir()):
            continue
        doc = None if child.is_symlink() else recorded_doc(child)
        if doc is None:
            rep.unread.append(str(child))
            continue
        if os.path.exists(doc):
            continue
        try:
            if gc_one(child, ttl, lr):
                rep.docless += 1
        except OSError as exc:
            print("[spec-distill] 원장 정리 실패 — {0}: {1}".format(child, exc), file=sys.stderr)


def migrate_old_ledger(old: Path, root: Path, rep: Report) -> str:
    """'moved' · 'docless' · 'unread' · 'kept-target' 중 하나."""
    doc = recorded_doc(old)
    if doc is None:
        rep.unread.append(str(old))
        return "unread"
    if not os.path.exists(doc):
        return "docless"
    target = state_dir_for(str(root), doc)
    if target.is_symlink():
        rep.unread.append(str(target))
        return "unread"
    if not ledger_root_bad(root):
        target.parent.mkdir(exist_ok=True)
    if not os.path.lexists(target):
        if not may_enter(target, root):
            rep.unread.append(str(old))
            return "unread"
        os.rename(str(old), str(target))
        rep.moved += 1
        return "moved"
    key = target.name
    # 읽지 못한 대상이 표지보다 먼저다 — 표지만 있는 대상에 밀려 읽히는 옛 원장이 폴더째 지워지면 안 된다.
    if recorded_doc(target) is None:
        rep.unread.append(str(target))
        return "unread"
    if os.path.lexists(target / MARKER):
        rep.conflicts.append("옛 원장 충돌 — {0}: 새 쪽을 남겼다".format(key))
        return "kept-target"
    if os.lstat(old / STATE_FILE).st_mtime_ns > os.lstat(target / STATE_FILE).st_mtime_ns:
        aside = target.parent / "{0}{1}-{2}".format(GC_PENDING_PREFIX, key, time.time_ns())
        if not may_enter(aside, root):
            rep.unread.append(str(old))
            return "unread"
        os.rename(str(target), str(aside))
        try:
            os.rename(str(old), str(target))
        except OSError:
            os.rename(str(aside), str(target))   # 비켜 놓은 대상은 줍기가 지운다 — 옮기지 못했으면 되돌린다
            raise
        rep.moved += 1
        rep.conflicts.append("옛 원장 충돌 — {0}: 옛 쪽을 남겼다".format(key))
        return "moved"
    rep.conflicts.append("옛 원장 충돌 — {0}: 새 쪽을 남겼다".format(key))
    return "kept-target"


def migrate_session(old_root: Path, root: Path, rep: Report, can_migrate: bool) -> bool:
    """옛 폴더의 `docreview/<x>/` 를 하나씩 옮긴다. 폴더를 지워도 되면 True.

    `docreview/` 가 링크여도 목록은 읽는다 — 그 아래 원장은 `inside_root` 에서 걸려 읽지 못한 원장이 되고
    폴더는 남는다(링크 너머를 옮기지도 지우지도 않는다).
    """
    if not can_migrate:
        return False
    try:
        before = os.lstat(old_root)
        entries = sorted(old_root.iterdir())
    except OSError:
        rep.unread.append(str(old_root))
        return False
    ok = True
    moved = False
    for led in entries:
        if not (led.is_symlink() or led.is_dir()):
            continue
        if inside_root(led, root) is not None:
            rep.unread.append(str(led))
            ok = False
            continue
        try:
            r = migrate_old_ledger(led, root, rep)
        except OSError as exc:
            print("[spec-distill] 옛 원장 옮기기 실패 — {0}: {1}".format(led, exc), file=sys.stderr)
            rep.unread.append(str(led))
            r = "unread"
        ok = ok and r != "unread"
        moved = moved or r == "moved"
    if moved and not old_root.is_symlink():
        # 옮기기가 바꾼 것은 `docreview/` 의 mtime 뿐이다 — 되돌려 gc_one 의 나이 판정이 옛 값을 보게 한다.
        os.utime(old_root, ns=(before.st_atime_ns, before.st_mtime_ns), follow_symlinks=False)
    return ok


def sweep_old_sessions(root: Path, ttl: int, rep: Report, can_migrate: bool) -> None:
    now = time.time_ns()
    for child in sorted(root.iterdir()):
        if child.is_symlink() or not child.is_dir() or not SESSION_PATTERN.fullmatch(child.name):
            continue
        if os.path.lexists(child / LEGACY_INTERVIEW):
            rep.preserved.append(str(child / LEGACY_INTERVIEW))
            continue
        try:
            if now - folder_mtime_ns(child) < ttl:
                continue
        except OSError:
            continue
        old_root = child / OLD_SUBDIR
        keep = old_root.is_dir() and not migrate_session(old_root, root, rep, can_migrate)
        if keep:
            continue
        try:
            if gc_one(child, ttl, root):
                rep.old_removed += 1
        except OSError as exc:
            print("[spec-distill] 옛 세션 폴더 정리 실패 — {0}: {1}".format(child, exc), file=sys.stderr)


def emit(rep: Report) -> None:
    if rep.docless or rep.old_removed or rep.moved:
        print("[spec-distill] 원장 정리 — 문서 없는 원장 {0}개 · 옛 세션 폴더 {1}개 지움 · 옛 원장 {2}개 옮김".format(
            rep.docless, rep.old_removed, rep.moved))
    for c in rep.conflicts:
        print("[spec-distill] " + c)
    if rep.preserved:
        print("[spec-distill] 옮기지 않은 옛 인터뷰 기록 {0}개 — {1}".format(len(rep.preserved), " · ".join(rep.preserved)))
    unread = list(dict.fromkeys(rep.unread))  # ① 과 ② 가 같은 대상을 둘 다 볼 수 있다 — 한 번만 센다
    if unread:
        print("[spec-distill] 원장 정리 — 읽지 못한 원장 {0}개 남김 — {1}".format(len(unread), " · ".join(unread)))
    for u in rep.uncountable:
        print("[spec-distill] 원장 정리 — 셀 수 없음({0})".format(u))


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="ledger_sweep.py")
    ap.add_argument("--root", default=None)
    a = ap.parse_args(argv)
    if disabled():
        return 0
    root = Path(a.root) if a.root else state_root()
    if root_escapes(root, "spec-distill"):
        print("[spec-distill] 원장 정리 — 셀 수 없음(state root '{0}' 가 링크를 거쳐 제자리 밖으로 풀린다)".format(root))
        return 0
    if not root.is_dir():
        return 0
    if docreview_state.yaml is None:
        # 원장을 하나도 읽지 못한다 — 문서 유무를 모르는 채로 지우거나 옮기지 않는다.
        print("[spec-distill] 원장 정리 — 셀 수 없음(pyyaml 없음)")
        return 0
    ttl = ttl_ns("DEVBREW_SPEC_DISTILL_TTL_HOURS")
    rep = Report()
    with locked_root(root, "spec-distill") as held:
        if not held:
            print("[spec-distill] 원장 정리 — 건너뜀(다른 세션이 정리 중)")
            return 0
        ok = ledger_root_ok(root, rep)
        sweep_pending(root, root)
        if ok:
            sweep_pending(root / STATE_SUBDIR, root)
            sweep_ledgers(root, ttl, rep)
        sweep_old_sessions(root, ttl, rep, can_migrate=ok)
    emit(rep)
    return 0


if __name__ == "__main__":
    sys.exit(main())
