#!/usr/bin/env python3
"""spec-distill — 문서 리뷰 원장의 동시 리뷰 표지(`reviewing-by`, 세션 id 한 줄).

엔진(`docreview_state.py`)은 표지를 모른다. 리뷰를 부르는 진입 블록이 라운드를 시작할 때 `acquire`,
원장에 쓰기 전마다 같은 Bash 호출에서 `check`, 끝맺음 펜스 끝에서 `release` 를 부른다.

CLI: ledger_marker.py {acquire|check|release|takeover|resume-note} --dir <원장 폴더> --session <sid>
rc: 0 성공 · 3 남의 표지(acquire · check) 또는 표지 없음(check) · 2 입력 · 입출력 오류
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from state_path import SESSION_PATTERN, inside_root  # noqa: E402

MARKER = "reviewing-by"
LAST = "last-session"


def _read_line(d: Path, name: str) -> str | None:
    """링크를 따라가지 않고 읽는다. 없으면 None. 링크 · 권한은 OSError."""
    try:
        fd = os.open(str(d / name), os.O_RDONLY | os.O_NOFOLLOW)
    except FileNotFoundError:
        return None
    try:
        data = os.read(fd, 4096)
    finally:
        os.close(fd)
    return data.decode("utf-8", "replace").strip()


def _atomic_write(d: Path, name: str, text: str) -> None:
    tmp = d / (".%s.%d.tmp" % (name, os.getpid()))
    fd = os.open(str(tmp), os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
    try:
        os.write(fd, text.encode("utf-8"))
    finally:
        os.close(fd)
    os.replace(str(tmp), str(d / name))


def cmd_acquire(d: Path, sid: str) -> int:
    try:
        fd = os.open(str(d / MARKER), os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
    except FileExistsError:
        owner = _read_line(d, MARKER)
        if owner == sid:
            print("held")
            return 0
        print(owner if owner else "(빈 표지)")
        return 3
    try:
        os.write(fd, (sid + "\n").encode("utf-8"))
    finally:
        os.close(fd)
    print("acquired")
    return 0


def cmd_check(d: Path, sid: str) -> int:
    owner = _read_line(d, MARKER)
    if owner == sid:
        return 0
    if owner is None:
        print("[spec-distill] 표지 없음 — {0}".format(d))
    else:
        print("[spec-distill] 다른 세션 {0} 의 표지 — {1}".format(owner or "(빈 표지)", d))
    return 3


def cmd_release(d: Path, sid: str) -> int:
    owner = _read_line(d, MARKER)
    if owner != sid:
        if owner is None:
            print("[spec-distill] 표지 없음 — 지울 것이 없다: {0}".format(d))
        else:
            print("[spec-distill] 다른 세션 {0} 의 표지 — 지우지 않았다: {1}".format(owner or "(빈 표지)", d))
        return 0
    _atomic_write(d, LAST, sid + "\n")
    os.unlink(str(d / MARKER))
    print("released")
    return 0


def cmd_takeover(d: Path, sid: str) -> int:
    try:
        prev = _read_line(d, MARKER)
    except OSError:
        prev = "(읽지 못함)"
    _atomic_write(d, MARKER, sid + "\n")
    print("[spec-distill] 표지를 넘겨받았다 — 이전: {0}".format(prev or "없음"))
    return 0


def cmd_resume_note(d: Path, sid: str) -> int:
    from docreview_state import load_state  # 엔진의 원장 판독을 그대로 쓴다
    try:
        st = load_state(d)
    except FileNotFoundError:
        return 0
    except Exception as exc:  # 깨진 원장 · pyyaml 부재 — 줄을 내지 않되 조용하지 않다
        print("[spec-distill] 이전 리뷰 원장을 읽지 못했다 — {0} ({1})".format(d, exc), file=sys.stderr)
        return 0
    try:
        n = int(st.get("round") or 0)
    except (TypeError, ValueError):
        n = 0
    try:
        owner = _read_line(d, MARKER)
        last = _read_line(d, LAST)
    except OSError:
        owner = last = None
    if n >= 1 and owner != sid and last != sid:
        print("[spec-distill] 이전 리뷰 라운드 {0} 에서 이어 간다 — {1}".format(n, d))
    return 0


CMDS = {"acquire": cmd_acquire, "check": cmd_check, "release": cmd_release,
        "takeover": cmd_takeover, "resume-note": cmd_resume_note}


def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="ledger_marker.py")
    p.add_argument("cmd", choices=sorted(CMDS))
    p.add_argument("--dir", required=True)
    p.add_argument("--session", required=True)
    a = p.parse_args(argv)
    d = Path(a.dir)
    if not a.session or not SESSION_PATTERN.fullmatch(a.session):
        print("[spec-distill] 세션 id 형식이 아니다: {0!r}".format(a.session[:32]), file=sys.stderr)
        return 2
    if d.is_symlink() or not d.is_dir():
        print("[spec-distill] 원장 폴더가 없다(또는 링크다): {0}".format(d), file=sys.stderr)
        return 2
    parent = d.parent
    why = "상위 폴더가 링크다" if parent.is_symlink() else inside_root(d, parent)
    if why:
        print("[spec-distill] 원장 폴더를 믿을 수 없다 — {0}: {1}".format(why, d), file=sys.stderr)
        return 2
    try:
        return CMDS[a.cmd](d, a.session)
    except OSError as exc:
        print("[spec-distill] 표지 {0} 실패 — {1}".format(a.cmd, exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
