#!/usr/bin/env bash
# guards: shared/entry/entry_preflight.py plugins/**
# 끄기 변수 표(switches.md) 넷과 README 「끄는 길」 의 대조.
#   A 표를 읽는다 · B 수를 센다 · C README 표가 switches.md 와 바이트로 같다 · D 남음 이름에 읽는 곳이 있다
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
PY="$(command -v python3)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/switchtables.XXXXXX")" || exit 1
[ -n "$TMP" ] && [ -d "$TMP" ] || exit 1
trap 'rm -rf "$TMP"' EXIT

# 공통 머리 — 사전 검사 모듈을 불러오고 대상 플러그인을 도출한다
PRE='import sys, os, glob, importlib.util, re
root = sys.argv[1]
spec = importlib.util.spec_from_file_location("e", os.path.join(root, "shared", "entry", "entry_preflight.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
scripts = sorted(glob.glob(os.path.join(root, "plugins", "*", "scripts", "entry_preflight.py")))
plugins = [os.path.basename(os.path.dirname(os.path.dirname(s))) for s in scripts]
out = []
def ok(t): out.append("OK " + t)
def no(t): out.append("NO " + t)
def rd(p): return m.read_table(m.table_path(os.path.join(root, "plugins", p, "scripts", "entry_preflight.py")), p)
import subprocess
SKIP_BASE = ("switches.md", "README.md", "CHANGELOG.md", "entry_preflight.py")
def skipped(ln):
    s = ln.lstrip()
    if s.startswith("#") or s.startswith("print("): return True
    return (s.split(None, 1) or [""])[0] in ("echo", "printf")
def scan_files(p):   # 절 D 가 읽는 플러그인 파일 — (상대 경로, 센 줄들). 링크는 대상 내용을 읽는다
    ls = subprocess.run(["git", "-C", root, "ls-files", "-z", "--", "plugins/" + p],
                        stdout=subprocess.PIPE, check=True).stdout.decode("utf-8").split("\0")
    files = []
    for f in ls:
        if not f or "/tests/" in f or os.path.basename(f) in SKIP_BASE: continue
        try:
            with open(os.path.join(root, f), "rb") as fh: txt = fh.read().decode("utf-8")
        except (OSError, UnicodeDecodeError): continue
        files.append((f, [ln for ln in txt.split("\n") if not skipped(ln)]))
    return files
'
if [ "${1:-}" = "--emit-scanned" ]; then   # 이 테스트가 실제로 읽는 경로 — 읽는 코드와 같은 도출로 낸다
  "$PY" -I -c "$PRE
seen = set()
for p in plugins:
    for n in ('switches.md', 'README.md'): seen.add('plugins/' + p + '/' + n)
    for f, _ in scan_files(p): seen.add(f)
seen.add('shared/entry/entry_preflight.py')
for f in glob.glob(os.path.join(root, 'plugins', '*', 'skills', '*', 'SKILL.md')): seen.add(os.path.relpath(f, root))
print(chr(10).join(sorted(seen)))" "$ROOT"
  exit 0
fi
run_section() {   # run_section <이름> <파이썬 본문> — 파이썬이 낸 OK/NO 줄을 판정으로 옮긴다
  local f="$TMP/$1.out"
  "$PY" -I -c "$PRE
$2
print(chr(10).join(out))" "$ROOT" > "$f" 2>"$TMP/$1.err" || { no "$1: 파이썬이 죽었다: $(head -c 300 "$TMP/$1.err")"; return; }
  local line
  while IFS= read -r line; do
    case "$line" in
      "OK "*) ok "$1: ${line#OK }" ;;
      "NO "*) no "$1: ${line#NO }" ;;
    esac
  done < "$f"
}

note "A. tables_readable"
run_section A '
if len(plugins) == 4: ok("entry_preflight.py 가 있는 플러그인이 넷이다 " + " ".join(plugins))
else: no("entry_preflight.py 가 있는 플러그인이 %d 개다: %s" % (len(plugins), " ".join(plugins)))
for p in plugins:
    try:
        rows = rd(p)
        if rows: ok(p + " 표를 읽었다(" + str(len(rows)) + " 행)")
        else: no(p + " 표에 행이 없다")
    except m.TableError as e:
        no(p + " 표를 못 읽는다: " + e.reason)
'

note "B. counts"
run_section B '
state = {}
bad = False
for p in plugins:
    try: rows = rd(p)
    except m.TableError: continue
    for r in rows:
        n = r["names"][0]
        if n in state and state[n] != r["state"]:
            no("한 이름이 두 표에 다른 상태로 실렸다: " + n); bad = True
        state[n] = r["state"]
total = len(state)
kept = sum(1 for s in state.values() if s == "남음")
retiring = sum(1 for s in state.values() if s == "은퇴 예정")
# 은퇴 0 — 둘째 판이 은퇴 20 으로 바꾼다
retired = sum(1 for s in state.values() if s == "은퇴")
for label, got, want in (("행 첫 이름 합계", total, 27), ("남음", kept, 7), ("은퇴 예정", retiring, 20), ("은퇴", retired, 0)):
    if got == want: ok("%s %d" % (label, got))
    else: no("%s: 기대 %d, 실제 %d" % (label, want, got))
if not bad: ok("두 표에 실린 이름은 두 표의 상태가 같다")
'

note "C. readme_matches_table"
run_section C '
PHRASES = ["claude plugin disable", "enabledPlugins", "/reload-plugins", "새 세션", "--settings", "settings.local.json", "`env` 칸", "[devbrew-switch]"]
for p in plugins:
    try: rd(p)
    except m.TableError: no(p + " 표를 못 읽어 대조하지 못한다"); continue
    with open(os.path.join(root, "plugins", p, "switches.md"), "rb") as fh:
        tl = fh.read().decode("utf-8").split("\n")
    i = tl.index(m.HEADER)
    j = i
    while j + 1 < len(tl) and tl[j + 1].startswith("|"): j += 1
    want = "\n".join(tl[i:j + 1])
    with open(os.path.join(root, "plugins", p, "README.md"), "rb") as fh:
        rl = fh.read().decode("utf-8").split("\n")
    heads = [k for k, ln in enumerate(rl) if ln == "## 끄는 길"]
    if len(heads) != 1: no(p + " README 의 `## 끄는 길` 절이 %d 개다" % len(heads)); continue
    s = heads[0] + 1
    e = s
    while e < len(rl) and not rl[e].startswith("## "): e += 1
    sec = rl[s:e]
    b = [k for k, ln in enumerate(sec) if ln == "<!-- switches:begin -->"]
    en = [k for k, ln in enumerate(sec) if ln == "<!-- switches:end -->"]
    if len(b) != 1 or len(en) != 1 or b[0] >= en[0]:
        no(p + " 절 안의 begin/end 표지가 하나씩이 아니다"); continue
    mid = sec[b[0] + 1:en[0]]
    while mid and mid[0] == "": mid = mid[1:]
    while mid and mid[-1] == "": mid = mid[:-1]
    got = "\n".join(mid)
    if got == want: ok(p + " README 표가 switches.md 와 바이트로 같다")
    else: no(p + " README 표가 switches.md 와 다르다")
    # 구절은 표 밖의 글에서만 센다 — 표의 칸이 구절을 채워 주면 산문을 지워도 통과한다
    text = "\n".join(sec[:b[0]] + sec[en[0] + 1:])
    for ph in PHRASES:
        if ph in text: ok(p + " 절에 " + ph + " 가 있다")
        else: no(p + " 절에 " + ph + " 가 없다")
'

note "D. kept_names_have_readers"
run_section D '
for p in plugins:
    try: rows = rd(p)
    except m.TableError: no(p + " 표를 못 읽는다"); continue
    files = scan_files(p)
    confs = {}
    for f, lines in files:
        if f.endswith(".conf"):
            for ln in lines:
                mm = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)=(\S+)\s*$", ln.strip())
                if mm: confs.setdefault(mm.group(2).strip("\"\x27"), []).append(mm.group(1))
    for r in rows:
        if r["state"] != "남음": continue
        for n in r["names"]:
            q = re.escape(n)
            pats = [r"\$\{?" + q + r"(?![A-Za-z0-9_])", r"environ\.get\(\s*[\"\x27]" + q + r"[\"\x27]",
                    r"environ\[\s*[\"\x27]" + q + r"[\"\x27]\s*\]", r"getenv\(\s*[\"\x27]" + q + r"[\"\x27]"]
            for key in confs.get(n, []): pats.append(r"\$\{!" + re.escape(key) + r"(?![A-Za-z0-9_])")
            hit = None
            for f, lines in files:
                if any(re.search(pt, ln) for ln in lines for pt in pats): hit = f; break
            if hit: ok("%s %s 를 읽는 곳이 있다(%s)" % (p, n, hit))
            else: no("%s %s 를 읽는 곳이 없다" % (p, n))
'

note "E. entry_skills_show_switch_lines"
run_section E '
PRE_LINE = "!`python3 \"${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py\" "
SENT = " 감시줄 아래에 `[devbrew-switch]` 로 시작하는 줄이 있으면 감시줄이 무엇이든 그 줄들을 고치지 않고 사용자에게 보인다."
ANCHOR = "이 절이 다른 모든 절보다 먼저 돈다."
entries = []
for f in sorted(glob.glob(os.path.join(root, "plugins", "*", "skills", "*", "SKILL.md"))):
    with open(f, "rb") as fh: txt = fh.read().decode("utf-8")
    if any(ln.startswith(PRE_LINE) for ln in txt.split("\n")): entries.append((f, txt))
if len(entries) == 9: ok("사전 검사 줄이 있는 진입 skill 이 아홉이다")
else: no("사전 검사 줄이 있는 진입 skill 이 %d 개다(기대 9)" % len(entries))
for f, txt in entries:
    name = os.path.relpath(f, root)
    lines = txt.split("\n")
    heads = [k for k, ln in enumerate(lines) if ln == "## 진입 단계"]
    if len(heads) != 1: no(name + " 의 `## 진입 단계` 절이 %d 개다" % len(heads)); continue
    e = heads[0] + 1
    while e < len(lines) and not lines[e].startswith("## "): e += 1
    sec = lines[heads[0] + 1:e]
    hits = [ln for ln in sec if SENT.lstrip() in ln]
    if len(hits) != 1: no(name + " 진입 단계 절에 문장이 %d 번 있다(기대 1)" % len(hits)); continue
    if hits[0].startswith(ANCHOR) and hits[0].endswith(SENT): ok(name + " 문장이 앵커 줄 끝에 있다")
    else: no(name + " 문장이 든 줄이 앵커로 시작하고 문장으로 끝나지 않는다")
'

finish
