#!/usr/bin/env bash
# guards: shared/entry/entry_preflight.py plugins/**
# 끄기 변수 표(switches.md) 넷과 README 「끄는 길」 의 대조.
#   A 표를 읽는다 · B 수를 센다 · B2 이름 → 상태 · 별칭 지도를 글자로 묶는다 · C README 표가 switches.md 와 바이트로 같다 · D 남음 이름에 읽는 곳이 있다
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
retired = sum(1 for s in state.values() if s == "은퇴")
for label, got, want in (("행 첫 이름 합계", total, 27), ("남음", kept, 7), ("은퇴 예정", retiring, 0), ("은퇴", retired, 20)):
    if got == want: ok("%s %d" % (label, got))
    else: no("%s: 기대 %d, 실제 %d" % (label, want, got))
if not bad: ok("두 표에 실린 이름은 두 표의 상태가 같다")
'

note "B2. names_pinned"
# 플러그인 · 행 첫 이름 → 상태 · 별칭. 설계 1 「끄는 길」 의 표에서 옮긴 기대값이다 — 은퇴 20 행은 상태가 「은퇴」 다.
run_section B2 '
EXPECT = {
    ("plugin-audit", "DEVBREW_PLUGIN_AUDIT_DISABLE_CODEX"): ("남음", ()),
    ("plugin-audit", "DEVBREW_PLUGIN_AUDIT_DISABLE_RUNTIME_SANDBOX"): ("남음", ("DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX",)),
    ("plugin-audit", "DEVBREW_PLUGIN_AUDIT_DISABLE"): ("은퇴", ()),
    ("plugin-audit", "DEVBREW_PLUGIN_AUDIT_DISABLE_WEB"): ("은퇴", ()),
    ("project-init", "DEVBREW_PROJECT_INIT_DISABLE"): ("은퇴", ()),
    ("project-init", "DEVBREW_SKIP_HOOKS=project-init:post-tool-use"): ("은퇴", ("DEVBREW_SKIP_HOOKS=project-init:PostToolUse",)),
    ("quality-gates", "DEVBREW_QUALITY_GATES_DISABLE_CODEX"): ("남음", ()),
    ("quality-gates", "DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST"): ("남음", ()),
    ("quality-gates", "DEVBREW_QUALITY_GATES_DISABLE_PUBLISH"): ("남음", ()),
    ("quality-gates", "DEVBREW_QUALITY_GATES_DISABLE"): ("은퇴", ()),
    ("quality-gates", "DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER"): ("은퇴", ()),
    ("quality-gates", "DEVBREW_QUALITY_GATES_DISABLE_CRITIQUE"): ("은퇴", ()),
    ("quality-gates", "DEVBREW_QUALITY_GATES_DISABLE_E2E"): ("은퇴", ()),
    ("quality-gates", "DEVBREW_QUALITY_GATES_DISABLE_INTENT_CRITIC"): ("은퇴", ()),
    ("quality-gates", "DEVBREW_SKIP_HOOKS=quality-gates:qg-gc"): ("은퇴", ()),
    ("spec-distill", "DEVBREW_SPEC_DISTILL_DISABLE_CODEX"): ("남음", ()),
    ("spec-distill", "DEVBREW_SPEC_DISTILL_DISABLE_WEB"): ("남음", ()),
    ("spec-distill", "DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST"): ("남음", ()),
    ("spec-distill", "DEVBREW_SPEC_DISTILL_DISABLE"): ("은퇴", ()),
    ("spec-distill", "DEVBREW_SPEC_DISTILL_DISABLE_RECRITIC"): ("은퇴", ()),
    ("spec-distill", "DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW"): ("은퇴", ()),
    ("spec-distill", "DEVBREW_SPEC_DISTILL_DISABLE_WORKTREE"): ("은퇴", ()),
    ("spec-distill", "DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE"): ("은퇴", ()),
    ("spec-distill", "DEVBREW_SKIP_HOOKS=spec-distill:review-entry"): ("은퇴", ()),
    ("spec-distill", "DEVBREW_QUALITY_GATES_DISABLE_WEB"): ("은퇴", ()),
    ("spec-distill", "DEVBREW_SKIP_HOOKS=spec-distill:statusline"): ("은퇴", ()),
    ("spec-distill", "DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd"): ("은퇴", ("DEVBREW_SKIP_HOOKS=spec-distill:session-end-cleanup",)),
    ("spec-distill", "DEVBREW_SKIP_HOOKS=spec-distill:spec-distill-gc"): ("은퇴", ()),
}
got = {}
for p in plugins:
    try: rows = rd(p)
    except m.TableError: continue
    for r in rows:
        got[(p, r["names"][0])] = (r["state"], tuple(r["names"][1:]))
bad = False
for k in sorted(set(EXPECT) | set(got)):
    if k not in got: no("표에 없다: %s %s" % k); bad = True
    elif k not in EXPECT: no("기대값에 없는 행이다: %s %s" % k); bad = True
    elif got[k] != EXPECT[k]: no("%s %s: 기대 %r, 실제 %r" % (k + (EXPECT[k], got[k]))); bad = True
if not bad: ok("표 %d 행의 이름 · 상태 · 별칭이 기대값과 같다" % len(got))
# 통째 끄기 세 행의 「끄는 것」 은 정확히 「<플러그인> 전체」 다 — 진입 skill 이 줄 머리로 알아보는 글자의 원천이다
for p in ("spec-distill", "quality-gates", "plugin-audit"):
    n = "DEVBREW_" + p.upper().replace("-", "_") + "_DISABLE"
    try: rows = rd(p)
    except m.TableError: no(p + " 표를 못 읽어 통째 끄기 행을 보지 못한다"); continue
    hit = [r for r in rows if r["names"][0] == n]
    if len(hit) != 1: no("%s 통째 끄기 행이 %d 개다" % (p, len(hit))); continue
    if hit[0]["state"] == "은퇴" and hit[0]["what"] == p + " 전체": ok(p + " 통째 끄기 행: 은퇴 · 끄는 것 「" + p + " 전체」")
    else: no("%s 통째 끄기 행: 상태 %r · 끄는 것 %r" % (p, hit[0]["state"], hit[0]["what"]))
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
if len(entries) == 10: ok("사전 검사 줄이 있는 진입 skill 이 열이다")
else: no("사전 검사 줄이 있는 진입 skill 이 %d 개다(기대 10)" % len(entries))
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
    if hits[0].startswith(ANCHOR) and (hits[0].endswith(SENT) or (SENT + " 감시줄 아래에 `[devbrew-switch] 더 듣지 않는다 — ") in hits[0]): ok(name + " 문장이 앵커 줄에 있다(뒤 문장은 절 E2 가 문다)")
    else: no(name + " 문장이 든 줄이 앵커로 시작하지 않거나 문장 뒤가 다른 글이다")
'

note "E2. entry_skills_retired_question"
run_section E2 '
PRE_LINE = "!`python3 \"${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py\" "
SENT = " 감시줄 아래에 `[devbrew-switch]` 로 시작하는 줄이 있으면 감시줄이 무엇이든 그 줄들을 고치지 않고 사용자에게 보인다."
HEAD = "`[devbrew-switch] 더 듣지 않는다 — "
def g1(p):
    return ("감시줄 아래에 `[devbrew-switch] 더 듣지 않는다 — " + p + " 전체(` 로 시작하는 줄이나 `[devbrew-switch] 끄기 변수 표를 읽지 못했다` 로 시작하는 줄이 있으면 "
            "그 줄을 보인 뒤 `AskUserQuestion` 으로 계속할지 한 번 묻고, 「계속한다」 를 고를 때만 간다 — 물을 수 없거나 답이 없으면 멈춘다.")
Q = "끄던 변수가 켜져 있지만 더 듣지 않는다 — 계속하면 이 skill 이 그대로 돈다(codex · 웹 조사로 내용을 보내거나, 남의 코드를 돌리거나, PR 에 글을 올릴 수 있다). 계속할까?"
OPT1 = "`계속한다`(얻음: 이 skill 을 지금 쓴다 · 내줌: 꺼 두었다고 믿던 일이 돈다)"
OPT2 = "`멈춘다`(얻음: 아무것도 돌지 않는다 · 내줌: 변수를 풀거나 플러그인 끄기를 쓴 뒤 다시 불러야 한다)"
G8 = "(추천을 달지 않는다 — 꺼 두었다고 믿던 일을 다시 돌릴지는 사용자가 고른다)"
entries = []
for f in sorted(glob.glob(os.path.join(root, "plugins", "*", "skills", "*", "SKILL.md"))):
    with open(f, "rb") as fh: txt = fh.read().decode("utf-8")
    if any(ln.startswith(PRE_LINE) for ln in txt.split("\n")): entries.append((f, txt))
if len(entries) == 10: ok("사전 검사 줄이 있는 진입 skill 이 열이다")
else: no("사전 검사 줄이 있는 진입 skill 이 %d 개다(기대 10)" % len(entries))
nine = 0
for f, txt in entries:
    name = os.path.relpath(f, root)
    plug = name.split(os.sep)[1]
    if "[devbrew-entry] disabled" in txt: no(name + " 에 `[devbrew-entry] disabled` 가 남았다")
    else: ok(name + " 에 disabled 행이 없다")
    if "이 표가 보는 kill switch" in txt: no(name + " 에 「이 표가 보는 kill switch」 가 남았다")
    else: ok(name + " 에 「이 표가 보는 kill switch」 가 없다")
    if any(ln.startswith("| `[devbrew-entry] ok") for ln in txt.split("\n")): ok(name + " 에 ok 행이 있다(양성 짝)")
    else: no(name + " 에 ok 행이 없다 — 위 부재 확인이 공허하다")
    lines = txt.split("\n")
    heads = [k for k, ln in enumerate(lines) if ln == "## 진입 단계"]
    if len(heads) != 1: no(name + " 의 `## 진입 단계` 절이 %d 개다" % len(heads)); continue
    e = heads[0] + 1
    while e < len(lines) and not lines[e].startswith("## "): e += 1
    sec = lines[heads[0] + 1:e]
    if plug == "project-init":
        if any(HEAD in ln for ln in lines): no(name + " 에 은퇴 변수 줄 앞머리가 있다(이 플러그인은 통째 끄기가 없다)")
        else: ok(name + " 에 은퇴 변수 줄 앞머리가 없다")
        continue
    nine += 1
    base = [ln for ln in sec if SENT.lstrip() in ln]
    if len(base) != 1: no(name + " 진입 단계 절에 첫 판 문장이 %d 번 있다(기대 1)" % len(base)); continue
    ln = base[0]
    after = ln.split(SENT, 1)[1] if SENT in ln else ""
    if sum(1 for x in sec if g1(plug) in x) == 1 and ln.count(g1(plug)) == 1 and after.startswith(" " + g1(plug)): ok(name + " G1 이 첫 판 문장 뒤 같은 줄에 한 번 있다")
    else: no(name + " G1 이 첫 판 문장 뒤 같은 줄에 정확히 한 번 있지 않다")
    g2 = after.split(g1(plug), 1)[1] if g1(plug) in after else ""
    if g2 == " 질문 `" + Q + "` · 선택지 " + OPT1 + " · " + OPT2 + ". " + G8: ok(name + " G1 뒤 같은 줄에 질문 · 선택지 두 개(계속한다 → 멈춘다) · 추천 없음 구절만 이어진다")
    else: no(name + " G1 뒤 같은 줄이 질문 · 선택지 두 개(계속한다 → 멈춘다) · 추천 없음 구절 그대로가 아니다")
    if ln.count(G8) == 1 and ln.endswith(G8) and "(권장)" not in ln: ok(name + " 같은 줄 끝에 추천 없음 구절이 한 번 있다")
    else: no(name + " 같은 줄 끝에 추천 없음 구절이 정확히 한 번 있지 않다")
    try: rows = rd(plug)
    except m.TableError: no(plug + " 표를 못 읽어 G1 의 이름을 견주지 못한다"); continue
    n = "DEVBREW_" + plug.upper().replace("-", "_") + "_DISABLE"
    hit = [r for r in rows if r["names"][0] == n]
    if len(hit) == 1 and hit[0]["what"] == plug + " 전체": ok(plug + " G1 의 이름이 표의 통째 끄기 행 「끄는 것」 과 같다")
    else: no(plug + " G1 의 이름과 표의 통째 끄기 행 「끄는 것」 이 다르다")
if nine == 9: ok("G1 을 달아야 하는 진입 skill 이 아홉이다")
else: no("G1 을 달아야 하는 진입 skill 이 %d 개다(기대 9)" % nine)
'

note "F. retired_names_absent"
# 은퇴 이름은 표의 은퇴 행에서 도출한다(절 B2 가 표를 기대값에 묶는다). 코퍼스는 git ls-files 의 보통 파일(mode 120000 링크는 뺀다) 본문 전체.
run_section F '
ret, kept_names, tokens = set(), set(), {}
for p in plugins:
    try: rows = rd(p)
    except m.TableError: no(p + " 표를 못 읽어 은퇴 이름을 도출하지 못한다"); continue
    for r in rows:
        for n in r["names"]:
            if r["state"] == "남음": kept_names.add(n)
            elif r["state"] == "은퇴": ret.add(n)
ret -= kept_names
SKIPNAME = "DEVBREW_SKIP_HOOKS"
for n in sorted(ret):
    if n.startswith(SKIPNAME + "="): tokens[n] = n[len(SKIPNAME) + 1:]
def bound(x): return re.compile(r"(?<![A-Z0-9_])" + re.escape(x) + r"(?![A-Za-z0-9_])")   # 앞은 대문자 · 숫자 · _ 만 막는다 — 줄바꿈 · 탭 · %s 에 붙은 꼴도 잡는다
def tokbound(x): return re.compile(r"(?<![A-Za-z0-9_:-])" + re.escape(x) + r"(?![A-Za-z0-9_-])")   # 변수 이름 없이 토큰 글자만 있는 꼴(쉼표 목록 · dict 꼴)
def retired_pats():
    pats = []
    for n in sorted(ret):
        pats.append((n, bound(n)))
        if n in tokens: pats.append((n, tokbound(tokens[n])))
    return pats
def hits_in(text, pats):
    return sorted(set(n for n, rx in pats if rx.search(text)))
raw = subprocess.run(["git", "-C", root, "ls-files", "-s", "-z"], stdout=subprocess.PIPE, check=True).stdout.decode("utf-8").split("\0")
corpus = []
skipped_decode = 0
SIX = ("skills", "references", "templates", "scripts", "hooks", "agents")
have_six, have_other, branches = set(), set(), set()
for ent in raw:
    if not ent or "\t" not in ent: continue
    meta, f = ent.split("\t", 1)
    if meta.split()[0] not in ("100644", "100755"): continue   # 링크는 보통 파일이 아니다
    base = os.path.basename(f)
    plug = re.match(r"^plugins/[^/]+/(skills|references|templates|scripts|hooks|agents)/", f)
    sh = f.startswith("shared/") and "/tests/" not in f and base not in ("switches.md", "CHANGELOG.md") and not base.startswith("README")
    tl = f.startswith("tools/") and "/tests/" not in f and "/test_" not in f
    gw = f.startswith("docs/git-workflow/")
    mm6 = re.match(r"^plugins/[^/]+/([^/]+)/", f)
    if mm6 and mm6.group(1) in SIX: have_six.add(mm6.group(1))   # 기대 집합은 거르기와 따로 센다
    if f.startswith("shared/") and "/tests/" not in f and base not in ("switches.md", "CHANGELOG.md") and not base.startswith("README"): have_other.add("shared")
    if f.startswith("tools/") and "/tests/" not in f and "/test_" not in f: have_other.add("tools")
    if f.startswith("docs/git-workflow/"): have_other.add("docs/git-workflow")
    rd_ = re.match(r"^plugins/[^/]+/README\.md$", f)
    if rd_: have_other.add("README 산문")
    if not (plug or sh or tl or gw or rd_): continue
    try:
        with open(os.path.join(root, f), "rb") as fh: txt = fh.read().decode("utf-8")
    except (OSError, UnicodeDecodeError): skipped_decode += 1; continue
    if rd_: txt = re.sub(r"<!-- switches:begin -->.*?<!-- switches:end -->", "", txt, flags=re.S)   # 끄기 변수 표 표지 안은 표가 맡는다(절 C) — 밖 본문만 코퍼스다
    branches.add("plugins/" + plug.group(1) if plug else ("shared" if sh else ("tools" if tl else ("README 산문" if rd_ else "docs/git-workflow"))))
    corpus.append((f, txt))
if len(corpus) > 50 and len(ret) >= 20: ok("코퍼스 %d 파일(디코드 못 해 뺀 파일 %d 개) · 은퇴 이름 %d 개(별칭 포함)를 도출했다" % (len(corpus), skipped_decode, len(ret)))
else: no("코퍼스 %d 파일 · 은퇴 이름 %d 개 — 도출이 비었거나 너무 작다" % (len(corpus), len(ret)))
want_br = set("plugins/" + x for x in have_six) | have_other
if branches == want_br and len(have_six) >= 4: ok("코퍼스가 담은 갈래가 기대 집합과 같다: " + " ".join(sorted(branches)))
else: no("코퍼스 갈래가 기대와 다르다: 실제 %s · 기대 %s" % (sorted(branches), sorted(want_br)))
pats = retired_pats()
bad = [(f, hits_in(t, pats)) for f, t in corpus if hits_in(t, pats)]
if not bad: ok("어느 은퇴 이름도 코퍼스에 없다")
else:
    for f, h in bad: no("은퇴 이름이 남았다: %s %s" % (f, " ".join(h)))
bare = bound(SKIPNAME)
got = sorted(f for f, t in corpus if bare.search(t) and not re.match(r"^plugins/[^/]+/README\.md$", f))   # 맨이름 집합은 코드 코퍼스의 것이다 — README 산문은 은퇴 이름 검사에만 든다
want = ["plugins/spec-distill/scripts/review_entry.py", "shared/entry/entry_preflight.py"]
if got == want: ok("맨이름 " + SKIPNAME + " 가 나오는 파일이 정확히 둘이다")
else: no("맨이름 " + SKIPNAME + " 가 나오는 파일 집합이 다르다: " + repr(got))
alltext = "\n".join(t for _, t in corpus)
for n in sorted(kept_names):
    if bound(n).search(alltext): ok("남는 이름 " + n + " 가 코퍼스에 있다(양성 짝)")
    else: no("남는 이름 " + n + " 가 코퍼스에 없다")
if len(kept_names) == 7 + 1: ok("남는 이름이 일곱에 별칭 하나를 더한 여덟이다")
else: no("남는 이름이 %d 개다(기대 8: 일곱 + 별칭 하나)" % len(kept_names))
# 계측기 양성 대조 — 은퇴 이름 하나를 넣은 사본 코퍼스를 같은 검사가 잡는다(정확 경계도: 이름 뒤에 글자를 붙이면 안 잡힌다)
probe = sorted(ret)[0]
if hits_in("x " + probe + " y", pats) == [probe]: ok("계측기 양성 대조: 은퇴 이름을 넣으면 검사가 잡는다")
else: no("계측기 양성 대조 실패: 은퇴 이름을 넣어도 검사가 못 잡는다")
if not hits_in("x " + "DEVBREW_QUALITY_GATES_DISABLE_CODEX y", pats): ok("계측기 경계 대조: 남는 이름은 은퇴 이름으로 잡히지 않는다")
else: no("계측기 경계 대조 실패: 남는 이름이 은퇴 이름에 걸린다")
tk = sorted(tokens)
tokonly = [(n, rx) for n, rx in pats if n in tokens and rx.pattern.startswith("(?<![A-Za-z0-9_:-])")]
if tk and len(tokonly) == len(tk) and all(any(rx.search("x:y," + tokens[n] + " ") for m_, rx in tokonly if m_ == n) and not any(rx.search("DEVBREW_SKIP_HOOKS=x:y") for _, rx in tokonly) for n in tk): ok("계측기 양성 대조: 변수 이름 없이 쉼표 목록 둘째 자리의 토큰 글자만 있어도 토큰 패턴이 잡는다")
else: no("계측기 양성 대조 실패: 토큰 패턴이 토큰 글자만 있는 꼴을 못 잡는다")
if tk and all(n not in hits_in("x:y," + tokens[n] + "z", pats) for n in tk): ok("계측기 경계 대조: 토큰 글자에 글자가 붙으면 안 잡힌다")
else: no("계측기 경계 대조 실패: 토큰 뒤에 글자가 붙어도 잡힌다")
if probe in hits_in("a" + chr(92) + "n" + probe + "=1", pats) and probe in hits_in("-u" + probe, pats): ok("계측기 양성 대조: 이름이 다른 글자(줄바꿈 표기 n · u)에 붙은 꼴도 잡는다")
else: no("계측기 양성 대조 실패: 소문자에 붙은 이름을 못 잡는다")
if not hits_in("X" + probe, pats): ok("계측기 경계 대조: 대문자에 붙은 이름은 안 잡힌다")
else: no("계측기 경계 대조 실패: 대문자에 붙은 이름이 잡힌다")
'

finish
