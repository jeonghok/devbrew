#!/usr/bin/env bash
# e2e-state.sh — e2e 걷기의 결정론 부품.
#
#   fingerprint --out <file>        코드 상태 지문(HEAD · 추적 파일 변경 · 무시되지 않는 untracked)
#   compare <before> <after>        두 지문의 차이 — `changed: <path>` 줄들 + 마지막 줄 `same` | `changed: <N>`
#   boot --dir <dir> --cmd <command> (--ready-port <port> | --ready-log <ERE>) [--timeout <sec>]
#                                   승인된 명령을 새 프로세스 그룹으로 띄우고 준비 신호를 기다린다
#   stop --dir <dir>                boot 가 띄운 프로세스 그룹을 내린다(여러 번 불러도 같다)
#   propose <evidence.tsv>          증거표 → 판정안(`proposal: pass|fail|미확인`)
#
# exit: 0 성공(compare 는 same) · 1 compare changed · 2 잘못된 호출 · 3 kill switch ·
#       4 측정·판독 실패 또는 부팅 실패 · 5 정지 후에도 프로세스가 남음
#
# kill switch — DEVBREW_QUALITY_GATES_DISABLE · DEVBREW_QUALITY_GATES_DISABLE_E2E ·
# DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST 중 하나라도 정확히 1 이면 fingerprint ·
# compare · boot 가 측정·실행 전에 exit 3 으로 끝난다(X5). stop · propose 는 리뷰 대상 코드를
# 실행하지 않으므로 막지 않는다 — 꺼진 뒤에도 남은 앱은 내릴 수 있어야 한다.
set -u

die() { echo "e2e-state: $*" >&2; exit 2; }

# 프로세스 시작 시각 — 공백을 하나로 접고 앞뒤를 걷는다(기록과 대조가 같은 모양이어야 한다).
lstart_of() { LC_ALL=C ps -o lstart= -p "$1" 2>/dev/null | tr -s ' ' | sed 's/^ //; s/ $//'; }

port_open() {
  python3 -c 'import socket, sys
s = socket.socket(); s.settimeout(0.5)
sys.exit(0 if s.connect_ex(("127.0.0.1", int(sys.argv[1]))) == 0 else 1)' "$1"
}

killed_by_switch() {
  local v
  for v in DEVBREW_QUALITY_GATES_DISABLE DEVBREW_QUALITY_GATES_DISABLE_E2E DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST; do
    if [ "$(printenv "$v" 2>/dev/null)" = "1" ]; then
      echo "[quality-gates] e2e 가 ${v}=1 로 꺼져 있다 — 리뷰 대상 코드를 실행하지 않는다" >&2
      return 0
    fi
  done
  return 1
}

cmd_fingerprint() {
  local out=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --out) [ $# -ge 2 ] || die "--out 에 파일 경로가 없다"; out="$2"; shift 2 ;;
      *) die "fingerprint: 모르는 인자 '$1'" ;;
    esac
  done
  [ -n "$out" ] || die "usage: e2e-state.sh fingerprint --out <file>"
  killed_by_switch && exit 3
  GIT_OPTIONAL_LOCKS=0 PYTHONDONTWRITEBYTECODE=1 python3 - "$out" <<'PY'
import hashlib, json, os, stat, subprocess, sys

out = sys.argv[1]


def fail(msg):
    print(f"e2e-state: fingerprint — {msg}", file=sys.stderr)
    sys.exit(4)


def git(*args):
    try:
        r = subprocess.run(["git", "-c", "core.hooksPath=/dev/null", *args], capture_output=True)
    except OSError as exc:
        fail(f"git 을 실행하지 못했다: {exc}")
    if r.returncode != 0:
        fail(f"git {' '.join(args[:2])} 실패(rc={r.returncode}): {r.stderr.decode('utf-8', 'replace').strip()}")
    return r.stdout


top = git("rev-parse", "--show-toplevel").decode("utf-8", "surrogateescape").strip()
os.chdir(top)
head = git("rev-parse", "--verify", "HEAD").decode().strip()
EXCLUDE = ":(exclude).claude/quality-gates"
tracked = [p for p in git("diff", "HEAD", "--name-only", "-z", "--no-renames", "--", ".", EXCLUDE).split(b"\0") if p]
untracked = [p for p in git("ls-files", "--others", "--exclude-standard", "-z", "--", ".", EXCLUDE).split(b"\0") if p]


def digest(raw):
    path = raw.decode("utf-8", "surrogateescape")
    try:
        st = os.lstat(path)
    except FileNotFoundError:
        return "deleted"
    except OSError as exc:
        fail(f"{path!r} 를 읽지 못했다: {exc}")
    if stat.S_ISLNK(st.st_mode):
        return "link:" + hashlib.sha256(os.fsencode(os.readlink(path))).hexdigest()
    if stat.S_ISDIR(st.st_mode):
        return "dir"
    h = hashlib.sha256()
    try:
        with open(path, "rb") as fh:
            for chunk in iter(lambda: fh.read(1 << 20), b""):
                h.update(chunk)
    except OSError as exc:
        fail(f"{path!r} 를 읽지 못했다: {exc}")
    return ("x:" if st.st_mode & 0o111 else "f:") + h.hexdigest()


def name(raw):
    return json.dumps(raw.decode("utf-8", "backslashreplace"), ensure_ascii=False)


lines = ["e2e-fingerprint v1", f"head {head}"]
lines += [f"tracked {digest(p)} {name(p)}" for p in sorted(tracked)]
lines += [f"untracked {digest(p)} {name(p)}" for p in sorted(untracked)]
tmp = out + ".tmp"
try:
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    os.replace(tmp, out)
except OSError as exc:
    fail(f"지문을 쓰지 못했다: {out} ({exc})")
print(f"fingerprint: {out} (head {head[:7]} · tracked {len(tracked)} · untracked {len(untracked)})")
PY
}

cmd_compare() {
  [ $# -eq 2 ] || die "usage: e2e-state.sh compare <before> <after>"
  killed_by_switch && exit 3
  PYTHONDONTWRITEBYTECODE=1 python3 - "$1" "$2" <<'PY'
import json, sys


def fail(msg):
    print(f"e2e-state: compare — {msg}", file=sys.stderr)
    sys.exit(4)


def load(path):
    try:
        with open(path, encoding="utf-8") as fh:
            rows = fh.read().splitlines()
    except (OSError, UnicodeDecodeError) as exc:
        fail(f"지문을 읽지 못했다: {path} ({exc})")
    if not rows or rows[0] != "e2e-fingerprint v1":
        fail(f"지문 머리줄이 없다: {path}")
    head, entries = None, {}
    for n, row in enumerate(rows[1:], start=2):
        if row.startswith("head "):
            if head is not None:
                fail(f"head 줄이 둘 이상이다: {path}:{n}")
            head = row[5:]
            continue
        parts = row.split(" ", 2)
        if len(parts) != 3 or parts[0] not in ("tracked", "untracked"):
            fail(f"판독할 수 없는 줄: {path}:{n}")
        try:
            key = json.loads(parts[2])
        except ValueError:
            fail(f"경로를 판독할 수 없다: {path}:{n}")
        entries[key] = (parts[0], parts[1])
    if not head:
        fail(f"head 줄이 없다: {path}")
    return head, entries


bh, be = load(sys.argv[1])
ah, ae = load(sys.argv[2])
changed = []
if bh != ah:
    changed.append(f"HEAD ({bh[:7]} -> {ah[:7]})")
for key in sorted(set(be) | set(ae)):
    if be.get(key) != ae.get(key):
        changed.append(key)
for c in changed:
    print(f"changed: {c}")
print(f"changed: {len(changed)}" if changed else "same")
sys.exit(1 if changed else 0)
PY
}

cmd_boot() {
  local dir="" cmd="" port="" logre="" timeout="${DEVBREW_QUALITY_GATES_E2E_BOOT_TIMEOUT:-90}"
  local timeout_from="DEVBREW_QUALITY_GATES_E2E_BOOT_TIMEOUT"
  while [ $# -gt 0 ]; do
    case "$1" in
      --dir) [ $# -ge 2 ] || die "--dir 값이 없다"; dir="$2"; shift 2 ;;
      --cmd) [ $# -ge 2 ] || die "--cmd 값이 없다"; cmd="$2"; shift 2 ;;
      --ready-port) [ $# -ge 2 ] || die "--ready-port 값이 없다"; port="$2"; shift 2 ;;
      --ready-log) [ $# -ge 2 ] || die "--ready-log 값이 없다"; logre="$2"; shift 2 ;;
      --timeout) [ $# -ge 2 ] || die "--timeout 값이 없다"; timeout="$2"; timeout_from="--timeout"; shift 2 ;;
      *) die "boot: 모르는 인자 '$1'" ;;
    esac
  done
  [ -n "$dir" ] && [ -n "$cmd" ] || die "usage: e2e-state.sh boot --dir <dir> --cmd <command> (--ready-port <port> | --ready-log <ERE>) [--timeout <sec>]"
  if [ -n "$port" ] && [ -n "$logre" ]; then die "준비 신호는 --ready-port 와 --ready-log 중 하나만"; fi
  [ -n "$port" ] || [ -n "$logre" ] || die "준비 신호(--ready-port 또는 --ready-log)가 없다"
  [ -z "$port" ] || { [[ "$port" =~ ^[1-9][0-9]{0,4}$ ]] && [ "$port" -le 65535 ]; } || die "--ready-port 는 1~65535 의 숫자다: '$port'"
  [[ "$timeout" =~ ^[1-9][0-9]{0,3}$ ]] || die "${timeout_from}은 1~9999 의 초(앞에 0 없이)다: '$timeout'"
  [ -d "$dir" ] || die "--dir 이 없다: $dir"
  killed_by_switch && exit 3
  local top pgf log
  top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "e2e-state: boot — git 리포 밖이다" >&2; exit 4; }
  pgf="$dir/e2e-app.pgid"; log="$dir/e2e-app.log"
  if [ -s "$pgf" ]; then
    echo "e2e-state: boot — 이미 띄운 앱이 있다($pgf). stop 을 먼저 부른다" >&2
    exit 2
  fi
  cd "$top" || exit 4
  # 준비 포트가 부팅 전에 이미 열려 있으면 그 포트의 주인은 승인된 명령이 아니다 — 그대로 두면
  # 이전부터 떠 있던 다른 앱을 걷고 pass 를 낸다.
  if [ -n "$port" ] && port_open "$port"; then
    echo "boot-failed: port-in-use ($port 가 부팅 전에 이미 열려 있다)"
    exit 4
  fi
  # 새 세션(setsid)으로 띄워 그 프로세스 그룹 전체를 stop 이 한 번에 내린다. 표준 입출력을
  # 전부 떼어야 호출한 셸이 앱의 종료를 기다리지 않는다.
  : >"$log"
  trap 'cmd_stop --dir "$dir" >/dev/null 2>&1; echo "boot-failed: interrupted"; exit 4' INT TERM HUP
  python3 -c 'import os, sys
os.setsid()
fd = os.open(os.devnull, os.O_RDONLY)
os.dup2(fd, 0)
os.execvp("bash", ["bash", "-c", sys.argv[1]])' "$cmd" >"$log" 2>&1 &
  local pid=$!
  printf '%s %s\n' "$pid" "$(lstart_of "$pid")" >"$pgf"
  local waited=0 reason=""
  while :; do
    if ! kill -0 "$pid" 2>/dev/null; then
      local rc=0; wait "$pid" 2>/dev/null || rc=$?
      reason="exit-$rc"; break
    fi
    if [ -n "$port" ]; then
      if port_open "$port"; then
        echo "ready: pgid=$pid port=$port log=$log"; trap - INT TERM HUP; return 0
      fi
    elif grep -Eq -- "$logre" "$log" 2>/dev/null; then
      echo "ready: pgid=$pid log=$log"; trap - INT TERM HUP; return 0
    fi
    if [ "$waited" -ge $((timeout * 2)) ]; then reason="timeout-${timeout}s"; break; fi
    sleep 0.5; waited=$((waited + 1))
  done
  trap - INT TERM HUP
  echo "--- 부팅 출력 끝부분 ($log)"
  tail -n 40 "$log" 2>/dev/null
  cmd_stop --dir "$dir" >/dev/null 2>&1
  echo "boot-failed: $reason"
  exit 4
}

cmd_stop() {
  local dir=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --dir) [ $# -ge 2 ] || die "--dir 값이 없다"; dir="$2"; shift 2 ;;
      *) die "stop: 모르는 인자 '$1'" ;;
    esac
  done
  [ -n "$dir" ] || die "usage: e2e-state.sh stop --dir <dir>"
  local pgf="$dir/e2e-app.pgid" pg started now
  if [ ! -s "$pgf" ]; then echo "stopped: none"; return 0; fi
  read -r pg started <"$pgf"
  # pgid 1 · 0 · 음수 · 숫자 아닌 값으로 `kill -- -<pg>` 를 부르면 무관한 프로세스 전체가 맞는다.
  if ! [[ "$pg" =~ ^[1-9][0-9]{0,9}$ ]] || [ "$pg" -le 1 ]; then
    echo "e2e-state: stop — pgid 파일이 판독 불가다: $pgf" >&2; exit 5
  fi
  # 우리 그룹이 아직 있으면 그 pid 는 재사용될 수 없다. 리더가 살아 있는데 시작 시각이 다르면
  # 우리 그룹은 이미 사라졌고 그 pid 는 남의 것이다 — 그때는 아무것도 죽이지 않는다.
  now=$(lstart_of "$pg")
  if kill -0 "$pg" 2>/dev/null; then
    if [ -z "$now" ] || [ -z "$started" ]; then
      echo "stop-failed: pgid=$pg (시작 시각을 확인할 수 없어 죽이지 않는다)"; exit 5
    fi
    if [ "$now" != "$started" ]; then
      rm -f "$pgf"; echo "stopped: none (pid $pg 는 다른 프로세스로 재사용됐다)"; return 0
    fi
  fi
  kill -TERM -- "-$pg" 2>/dev/null
  local i=0
  while pgrep -g "$pg" >/dev/null 2>&1 && [ "$i" -lt 10 ]; do sleep 0.5; i=$((i + 1)); done
  if pgrep -g "$pg" >/dev/null 2>&1; then kill -KILL -- "-$pg" 2>/dev/null; sleep 0.5; fi
  if pgrep -g "$pg" >/dev/null 2>&1; then
    echo "stop-failed: pgid=$pg 에 프로세스가 남았다"; exit 5
  fi
  rm -f "$pgf"
  echo "stopped: pgid=$pg"
}

cmd_propose() {
  [ $# -eq 1 ] || die "usage: e2e-state.sh propose <evidence.tsv>"
  PYTHONDONTWRITEBYTECODE=1 python3 - "$1" <<'PY'
import sys

JUDGED = ("충족", "불충족", "미확인")
NO_EVIDENCE = ("", "-", "없음", "n/a", "N/A")


def fail(msg):
    print(f"e2e-state: propose — {msg}", file=sys.stderr)
    sys.exit(4)


try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        rows = [r for r in fh.read().splitlines() if r.strip()]
except (OSError, UnicodeDecodeError) as exc:
    fail(f"증거표를 읽지 못했다: {sys.argv[1]} ({exc})")
if rows and rows[0].split("\t")[0] == "기대 상태":
    rows = rows[1:]
final = []
for n, row in enumerate(rows, start=1):
    cols = row.split("\t")
    if len(cols) != 3:
        fail(f"{n}행의 칸이 {len(cols)}개다(기대 상태 · 판정 · 증거 셋이어야 한다)")
    state, judged, evidence = (c.strip() for c in cols)
    if not state:
        fail(f"{n}행의 기대 상태가 비었다")
    if judged not in JUDGED:
        fail(f"{n}행의 판정 '{judged}' 는 충족 · 불충족 · 미확인 밖이다")
    if judged == "충족" and evidence in NO_EVIDENCE:
        print(f"coerced: {n} 충족 → 미확인 (증거 인용 없음)")
        judged = "미확인"
    final.append(judged)
if not final:
    print("coerced: 0 기대 상태가 없다")
if "불충족" in final:
    proposal = "fail"
elif not final or "미확인" in final:
    proposal = "미확인"
else:
    proposal = "pass"
print(f"proposal: {proposal}")
PY
}

sub="${1:-}"
[ -n "$sub" ] || die "usage: e2e-state.sh <fingerprint|compare|boot|stop|propose> ..."
shift
case "$sub" in
  fingerprint) cmd_fingerprint "$@" ;;
  compare) cmd_compare "$@" ;;
  boot) cmd_boot "$@" ;;
  stop) cmd_stop "$@" ;;
  propose) cmd_propose "$@" ;;
  *) die "모르는 하위명령 '$sub'" ;;
esac
