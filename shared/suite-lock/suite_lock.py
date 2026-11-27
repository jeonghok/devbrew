#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""suite_lock.py — 공유 스위트 잠금. 지휘자의 스위트 대조(`merge_check.py`) · 하위 agent 의 전체 스위트 · qg(차등 테스트의
테스트 명령마다)가 같은 잠금 하나를 쓴다. 정본은 `shared/suite-lock/` 이고 spec-distill · quality-gates 가 링크로 싣는다.

잠금은 폴더 하나(`mkdir`)이고 안의 `owner` 파일 첫 낱말이 주인 프로세스 번호다. 경로는 지휘자 기계 상태 폴더에서
도출한다(`lock_path`) — 지휘자가 `conductor_ledger.py suite-lock` 으로 얻어 하위에게 보내는 글에 싣는다.

판정(`state`):
  - 주인 기록 없음: 잡은 지 LOCK_YOUNG 초 안이면 바쁨, 그 뒤면 주인 없는 잠금
  - 첫 낱말이 숫자: 그 프로세스가 살아 있으면 바쁨, 아니면 주인 없는 잠금
  - 첫 낱말이 숫자가 아님(사람이 쓴 잠금 등): 살았는지 알 수 없어 바쁨으로 본다 — 주인 · 잡은 시각을 보이고 사람이 정한다

잠금 꼴(`lock_shaped`): 링크가 아닌 폴더이고, 안에 든 것이 없거나 일반 파일 `owner` 하나뿐이다. 잠금 자리가 폴더가 아니면
(일반 파일 · 링크 등), 폴더가 잠금 꼴이 아니면 나이 · 주인과 무관하게 치우지도 옮기지도 않고 기다리지 않은 채 못
잡는다(stuck) — 잘못 가리킨 잠금 인자가 남의 폴더를 지우지 않는다.

명령줄:
  suite_lock.py show --lock <잠금 폴더>
  suite_lock.py run  --lock <잠금 폴더> --owner <이름> [--wait <초>] -- <명령> [인자 …]

종료 코드: show 0 · run 은 명령의 종료 코드, 잠금을 잡지 못하면 75(BUSY_RC) · 잠금 폴더에 쓰지 못하거나 주인 없는 잠금을
옮기지 못하거나 잠금 자리에 잠금 꼴이 아닌 것이 있으면 3(NO_LOCK_RC) · 2 사용법.
"""
from __future__ import annotations

import argparse
import datetime
import os
import shutil
import signal
import stat
import subprocess
import sys
import time
from pathlib import Path

LOCK_NAME = "suite-lock"   # 기계 상태 자원 폴더(files/) 아래 이름
FILES_DIR = "files"
LOCK_YOUNG = 60            # 주인 기록 전 잠금은 이 초 동안 바쁜 것으로 본다
POLL = 15                  # 기다릴 때 다시 보는 간격(초)
RESTORE_MAX = 3            # 주인 없는 잠금을 풀다 경합으로 되돌린 횟수가 이것을 넘으면 바쁜 것으로 본다
BUSY_RC = 75               # 명령의 종료 코드와 섞이지 않게 고른 값(EX_TEMPFAIL)
NO_LOCK_RC = 3             # 잠금 폴더에 쓰지 못했다 — 잠금 없이 돌리지 않는다


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
        return {"held": False, "busy": False, "owner": "", "pid": None, "taken_at": "", "why": "비어 있음", "ident": None}
    taken_at = datetime.datetime.fromtimestamp(st.st_mtime).strftime("%Y-%m-%d %H:%M:%S")
    ident = (st.st_ino, st.st_mtime_ns)
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
    return {"held": True, "busy": busy, "owner": owner, "pid": pid, "taken_at": taken_at, "why": why, "ident": ident}


def describe(d: Path) -> str:
    s = state(d)
    if not s["held"]:
        return "스위트 잠금: 비어 있음"
    return "스위트 잠금: %s — 주인 %s · 잡은 시각 %s" % (s["why"], s["owner"] or "(기록 없음)", s["taken_at"])


def lock_shaped(d: Path) -> bool:
    """링크가 아닌 폴더이고 안에 든 것이 없거나 일반 파일 `owner` 하나뿐인가. 읽지 못하면 잠금 꼴로 보지 않는다."""
    try:
        if not stat.S_ISDIR(os.lstat(str(d)).st_mode):
            return False
        names = os.listdir(str(d))
        if not names:
            return True
        return names == ["owner"] and stat.S_ISREG(os.lstat(str(Path(d) / "owner")).st_mode)
    except OSError:
        return False


def not_lock(d: Path) -> str:
    return "잠금 자리에 잠금이 아닌 것이 있다(%s) — 치우지 않는다" % d


class Busy(Exception):
    """잠금을 잡지 못했다. stuck 이면 바빠서가 아니라 주인 없는 잠금을 옮기지 못했거나 잠금 자리에 잠금 꼴이 아닌 것이
    있어서다 — 기다려도 풀리지 않는다."""

    def __init__(self, msg, stuck=False):
        super().__init__(msg)
        self.stuck = stuck


def take(d: Path, owner: str, wait: float = 0, say=print) -> None:
    """잠금을 잡는다. 주인 없는 잠금은 알리고 푼다. wait 초 안에 못 잡으면 Busy(주인 · 잡은 시각)."""
    d = Path(d)
    d.parent.mkdir(parents=True, exist_ok=True)
    label = " ".join(owner.split())
    deadline = time.time() + max(0.0, wait)
    announced = stuck = False
    restored = 0
    while True:
        try:
            d.mkdir()
        except FileExistsError:
            try:
                here = os.lstat(str(d))
            except FileNotFoundError:
                continue
            if not stat.S_ISDIR(here.st_mode):   # 일반 파일 · 링크 — 나이와 무관하게 옮기지 않는다
                raise Busy(not_lock(d), stuck=True)
            s = state(d)
            if not s["held"]:
                continue
            # owner 말고 다른 것이 든 폴더는 바쁘든 아니든 남의 폴더다 — 기다리지도 치우지도 않는다. state 뒤에 보므로
            # 그 뒤에 더해진 것은 옮긴 뒤의 ident 비교가 잡는다
            if not lock_shaped(d):
                if not os.path.lexists(str(d)):
                    continue
                raise Busy(not_lock(d), stuck=True)
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
            except FileNotFoundError:
                continue   # 다른 쪽이 먼저 옮겼다 — 다시 본다(그쪽이 새로 잡았으면 바쁨으로 판정된다)
            except OSError as exc:   # 옮기지 못하면 바쁜 잠금처럼 기다림 상한 · 쉼을 지키고 이유를 알린다
                why = "주인 없는 잠금을 옮기지 못했다(%s) — 잠금 폴더의 부모 권한을 확인하거나 사람이 지운다: %s" % (
                    type(exc).__name__, describe(d))
                if time.time() >= deadline:
                    raise Busy(why, stuck=True)
                if not stuck:
                    say("[suite-lock] 기다린다(줄) — " + why)
                    stuck = True
                time.sleep(min(POLL, max(0.5, deadline - time.time())))
                continue
            try:
                moved = gone.stat()
                moved_owner = (gone / "owner").read_text(encoding="utf-8").strip() if (gone / "owner").is_file() else ""
            except (OSError, UnicodeDecodeError):
                moved, moved_owner = None, None
            if moved is None or (moved.st_ino, moved.st_mtime_ns) != s["ident"] or moved_owner != s["owner"]:
                # 판정한 뒤 다른 쪽이 새로 잡은 잠금을 옮겼다 — 되돌리고 다시 본다(횟수 상한)
                try:
                    os.rename(str(gone), str(d))
                except OSError:
                    raise Busy("경합 — 옮긴 잠금이 %s 에 남았다, 사람이 확인한다" % gone)
                restored += 1
                if restored > RESTORE_MAX:
                    raise Busy("주인 없는 잠금을 풀다 %d번 경합했다 — %s" % (restored, describe(d)))
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


def _kill_group(child, sig) -> None:
    try:
        os.killpg(child.pid, sig)
    except (ProcessLookupError, PermissionError):
        pass


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
        return NO_LOCK_RC if exc.stuck else BUSY_RC
    except OSError as exc:
        print("[suite-lock] 잠금 폴더에 쓰지 못했다: %s (%s) — 잠금 없이 돌리지 않는다" % (lock, type(exc).__name__))
        return NO_LOCK_RC
    print("[suite-lock] 잡았다 — %s" % lock)
    sys.stdout.flush()

    def _term(signum, _frame):
        raise SystemExit(128 + signum)
    signal.signal(signal.SIGTERM, _term)
    child = None
    try:
        child = subprocess.Popen(cmd, start_new_session=True)  # 끊기면 명령의 프로세스 묶음 전체를 멈춘다
        return child.wait()
    except OSError as exc:
        print("[suite-lock] 명령을 실행하지 못했다: %s" % exc)
        return 127
    finally:
        if child is not None and child.poll() is None:  # 끊겼으면 잠금을 풀기 전에 스위트(손자 포함)를 멈춘다
            _kill_group(child, signal.SIGTERM)
            try:
                child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                _kill_group(child, signal.SIGKILL)
                child.wait()
        drop(lock)
        print("[suite-lock] 풀었다 — %s" % lock)


if __name__ == "__main__":
    sys.exit(main())
