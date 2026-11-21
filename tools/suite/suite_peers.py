"""다른 스위트 러너(run-all.sh)가 지금 몇 개 도는지 센다.

명령줄: python3 suite_peers.py [--pid N] [--list | --stamp | --wait S [--interval I]]
세는 것: 셸이 run-all.sh 를 직접 실행하는 다른 프로세스 — 같은 바퀴의 하위 셸 · 안쪽 러너는 바깥 하나로 센다.
세지 않는 것: 이 실행 자신 · 조상 · 자손, 그리고 러너를 감싼 잠금 스크립트 · `bash -c '…'`.
"""
import argparse
import os
import subprocess
import sys
import time

SHELLS = ("bash", "sh", "zsh", "dash", "ksh")
PS_ENV = "SUITE_PEERS_PS_FILE"
PS_CMD = ["ps", "-axww", "-o", "pid=,ppid=,command="]


def parse_ps(text):
    rows = []
    for line in text.splitlines():
        parts = line.split(None, 2)
        if len(parts) != 3:
            continue
        try:
            rows.append((int(parts[0]), int(parts[1]), parts[2].strip()))
        except ValueError:
            continue
    return rows


def is_runner(command):
    tokens = command.split()
    if not tokens or tokens[0].lstrip("-").rsplit("/", 1)[-1] not in SHELLS:
        return False
    i = 1
    while i < len(tokens) and tokens[i].startswith("-"):
        flag = tokens[i]
        if not flag.startswith("--") and "c" in flag[1:]:
            return False
        i += 1
    rest = " ".join(tokens[i:])
    return rest.rsplit("/", 1)[-1] == "run-all.sh"


def peer_pids(rows, self_pid):
    by_pid = {pid: (ppid, cmd) for pid, ppid, cmd in rows}

    def ancestors(p):
        seen = set()
        cur = by_pid.get(p, (0, ""))[0]
        while cur and cur in by_pid and cur not in seen:
            seen.add(cur)
            cur = by_pid[cur][0]
        return seen

    desc = set()
    frontier = {self_pid}
    while frontier:
        nxt = {pid for pid, ppid, _ in rows if ppid in frontier and pid not in desc and pid != self_pid}
        desc |= nxt
        frontier = nxt
    excluded = {self_pid} | ancestors(self_pid) | desc
    runners = {pid for pid, (_, cmd) in by_pid.items() if is_runner(cmd)}
    return sorted(p for p in runners - excluded if not (ancestors(p) & runners))


def read_rows():
    path = os.environ.get(PS_ENV)
    try:
        if path:
            with open(path, encoding="utf-8", errors="replace") as fh:
                return parse_ps(fh.read())
        proc = subprocess.run(PS_CMD, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=30)
        if proc.returncode != 0:
            return None
        return parse_ps(proc.stdout.decode("utf-8", errors="replace"))
    except (OSError, subprocess.SubprocessError):
        return None


def count_peers(self_pid):
    rows = read_rows()
    return None if rows is None else len(peer_pids(rows, self_pid))


def main(argv=None):
    ap = argparse.ArgumentParser(description="다른 스위트 러너 수")
    ap.add_argument("--pid", type=int, default=os.getppid())
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument("--list", action="store_true")
    mode.add_argument("--stamp", action="store_true")
    mode.add_argument("--wait", type=float, metavar="S")
    ap.add_argument("--interval", type=float, default=15.0)
    a = ap.parse_args(argv)

    if a.stamp:
        n = count_peers(a.pid)
        print("%.3f %s" % (time.time(), "?" if n is None else n))
        return 0
    if a.list:
        rows = read_rows()
        if rows is None:
            return 3
        for p in peer_pids(rows, a.pid):
            print(p)
        return 0
    if a.wait is not None:
        start = time.monotonic()
        while True:
            n = count_peers(a.pid)
            waited = time.monotonic() - start
            if n == 0:
                print("waited=%d\tpeers=0" % int(waited))
                return 0
            if waited >= a.wait:
                print("waited=%d\tpeers=%s" % (int(waited), "?" if n is None else n))
                return 1
            time.sleep(max(0.0, min(a.interval, a.wait - waited)))
    n = count_peers(a.pid)
    if n is None:
        print("?")
        return 3
    print(n)
    return 0


if __name__ == "__main__":
    sys.exit(main())
