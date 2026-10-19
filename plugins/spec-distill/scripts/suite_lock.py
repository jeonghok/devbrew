#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""suite_lock.py — 공유 스위트 잠금. 지휘자의 스위트 대조(`merge_check.py`)와 하위 agent 의 전체 스위트가 같은 잠금 하나를 쓴다.

잠금은 폴더 하나(`mkdir`)이고 안의 `owner` 파일 첫 낱말이 주인 프로세스 번호다. 경로는 지휘자 기계 상태 폴더에서
도출한다(`lock_path`) — 지휘자가 `conductor_ledger.py suite-lock` 으로 얻어 하위에게 보내는 글에 싣는다.

판정(`state`):
  - 주인 기록 없음: 잡은 지 LOCK_YOUNG 초 안이면 바쁨, 그 뒤면 주인 없는 잠금
  - 첫 낱말이 숫자: 그 프로세스가 살아 있으면 바쁨, 아니면 주인 없는 잠금
  - 첫 낱말이 숫자가 아님(사람이 쓴 잠금 등): 살았는지 알 수 없어 바쁨으로 본다 — 주인 · 잡은 시각을 보이고 사람이 정한다

명령줄:
  suite_lock.py show --lock <잠금 폴더>
  suite_lock.py run  --lock <잠금 폴더> --owner <이름> [--wait <초>] -- <명령> [인자 …]

종료 코드: show 0 · run 은 명령의 종료 코드, 잠금을 잡지 못하면 75(BUSY_RC) · 2 사용법.
"""
from __future__ import annotations

import argparse
import datetime
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

LOCK_NAME = "suite-lock"   # 기계 상태 자원 폴더(files/) 아래 이름
FILES_DIR = "files"
LOCK_YOUNG = 60            # 주인 기록 전 잠금은 이 초 동안 바쁜 것으로 본다
POLL = 15                  # 기다릴 때 다시 보는 간격(초)
BUSY_RC = 75               # 명령의 종료 코드와 섞이지 않게 고른 값(EX_TEMPFAIL)


def lock_path(machine_dir) -> Path:
    """<기계 상태 폴더>/files/suite-lock — 자원 폴더 아래지만 `cleanup` 이 치우는 종류(tmp · relay · report)가 아니다."""
    return Path(machine_dir) / FILES_DIR / LOCK_NAME


def stamp() -> str:
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def _alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def state(d: Path) -> dict:
    """{held, busy, owner, pid, taken_at, why}. 잠금이 없으면 held=False."""
    d = Path(d)
    try:
        st = d.stat()
    except FileNotFoundError:
        return {"held": False, "busy": False, "owner": "", "pid": None, "taken_at": "", "why": "비어 있음"}
    taken_at = datetime.datetime.fromtimestamp(st.st_mtime).strftime("%Y-%m-%d %H:%M:%S")
    try:
        owner = (d / "owner").read_text(encoding="utf-8").strip()
    except (OSError, UnicodeDecodeError):
        owner = ""
    head = owner.split(" ", 1)[0] if owner else ""
    pid = int(head) if head.isdigit() else None
    if not owner:
        busy = (time.time() - st.st_mtime) < LOCK_YOUNG
        why = "주인 기록 전" if busy else "주인 기록 없는 잠금"
    elif pid is not None:
        busy = _alive(pid)
        why = "주인 프로세스가 돌고 있다" if busy else "주인 프로세스가 끝났다(남은 잠금)"
    else:
        busy = True
        why = "주인이 살았는지 알 수 없다(프로세스 번호 없음) — 끝났으면 사람이 잠금 폴더를 지운다"
    return {"held": True, "busy": busy, "owner": owner, "pid": pid, "taken_at": taken_at, "why": why}


def describe(d: Path) -> str:
    s = state(d)
    if not s["held"]:
        return "스위트 잠금: 비어 있음"
    return "스위트 잠금: %s — 주인 %s · 잡은 시각 %s" % (s["why"], s["owner"] or "(기록 없음)", s["taken_at"])


class Busy(Exception):
    pass


def take(d: Path, owner: str, wait: float = 0, say=print) -> None:
    """잠금을 잡는다. 주인 없는 잠금은 알리고 푼다. wait 초 안에 못 잡으면 Busy(주인 · 잡은 시각)."""
    d = Path(d)
    d.parent.mkdir(parents=True, exist_ok=True)
    label = " ".join(owner.split())
    deadline = time.time() + max(0.0, wait)
    announced = False
    while True:
        try:
            d.mkdir()
        except FileExistsError:
            s = state(d)
            if not s["held"]:
                continue
            if s["busy"]:
                if time.time() >= deadline:
                    raise Busy(describe(d))
                if not announced:
                    say("[suite-lock] 기다린다(줄) — %s" % describe(d))
                    announced = True
                time.sleep(min(POLL, max(0.5, deadline - time.time())))
                continue
            gone = d.parent / ("%s.stale-%d-%d" % (d.name, os.getpid(), int(time.time() * 1000)))
            try:
                os.rename(str(d), str(gone))
            except OSError:
                continue
            say("[suite-lock] 주인 없는 잠금을 풀었다(%s · %s)" % (d, s["owner"] or s["why"]))
            shutil.rmtree(str(gone), ignore_errors=True)
            continue
        (d / "owner").write_text("%d %s %s\n" % (os.getpid(), label, stamp()), encoding="utf-8")
        return


def drop(d: Path) -> None:
    """이 프로세스가 주인일 때만 푼다."""
    d = Path(d)
    if state(d)["pid"] == os.getpid():
        shutil.rmtree(str(d), ignore_errors=True)


def main(argv=None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    argv = list(sys.argv[1:] if argv is None else argv)
    cmd = []
    if "--" in argv:
        at = argv.index("--")
        argv, cmd = argv[:at], argv[at + 1:]
    ap = argparse.ArgumentParser(prog="suite_lock.py", description="공유 스위트 잠금")
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("show")
    s.add_argument("--lock", required=True)
    r = sub.add_parser("run")
    r.add_argument("--lock", required=True)
    r.add_argument("--owner", required=True)
    r.add_argument("--wait", type=float, default=0)
    a = ap.parse_args(argv)
    lock = Path(a.lock)
    if a.cmd == "show":
        print(describe(lock))
        return 0
    if not cmd:
        print("[suite-lock] `--` 뒤에 돌릴 명령이 없다")
        return 2
    try:
        take(lock, a.owner, a.wait)
    except Busy as exc:
        print("[suite-lock] 잠금을 잡지 못했다 — %s" % exc)
        return BUSY_RC
    print("[suite-lock] 잡았다 — %s" % lock)
    sys.stdout.flush()
    try:
        return subprocess.call(cmd)
    except OSError as exc:
        print("[suite-lock] 명령을 실행하지 못했다: %s" % exc)
        return 127
    finally:
        drop(lock)
        print("[suite-lock] 풀었다 — %s" % lock)


if __name__ == "__main__":
    sys.exit(main())
