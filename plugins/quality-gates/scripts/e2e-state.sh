#!/usr/bin/env bash
# e2e-state.sh — e2e 걷기의 결정론 부품.
#
#   fingerprint --out <file>        코드 상태 지문(HEAD · 추적 파일 변경 · 무시되지 않는 untracked)
#   compare <before> <after>        두 지문의 차이 — `changed: <path>` 줄들 + 마지막 줄 `same` | `changed: <N>`
#   propose <evidence.tsv>          증거표 → 판정안(`proposal: pass|fail|미확인`)
#
# exit: 0 성공(compare 는 same) · 1 compare changed · 2 잘못된 호출 · 3 kill switch ·
#       4 측정·판독 실패
#
# kill switch — DEVBREW_QUALITY_GATES_DISABLE · DEVBREW_QUALITY_GATES_DISABLE_E2E ·
# DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST 중 하나라도 정확히 1 이면 fingerprint ·
# compare 가 측정 전에 exit 3 으로 끝난다(X5). propose 는 리뷰 대상 코드를 실행하지 않으므로
# 막지 않는다.
set -u

die() { echo "e2e-state: $*" >&2; exit 2; }

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
[ -n "$sub" ] || die "usage: e2e-state.sh <fingerprint|compare|propose> ..."
shift
case "$sub" in
  fingerprint) cmd_fingerprint "$@" ;;
  compare) cmd_compare "$@" ;;
  propose) cmd_propose "$@" ;;
  *) die "모르는 하위명령 '$sub'" ;;
esac
