#!/usr/bin/env bash
# guards: CLAUDE.md docs/philosophy/*.md .claude-plugin/marketplace.json plugins/quality-gates/.claude-plugin/plugin.json
# test_charter_citations.sh — 헌장 인용 락 (설계 §6.5.4 · AC19 · AC20).
#
# 헌장(CLAUDE.md + docs/philosophy/*.md)이 이름으로 박는 것은 실재해야 한다. 조항이 가리키던 대상이
# 사라져도 조항 자체에 락이 없으면 제거가 GREEN 으로 통과하고 조항이 대상 없이 남는다(§6.5.4).
# 이름은 두 갈래로 도출한다 — 모양 하나로는 진짜 인용과 예시 이름(명명 규칙 · 금지 예시)을 못 가른다.
#  1. 모양으로 인식되는 인용은 실재한다 — 백틱 토큰 · 마크다운 링크 대상 중 `/` 를 품은 경로,
#     이 리포 plugins/ 의 플러그인을 가리키는 `<플러그인>:<이름>`. 템플릿 · 글롭 · 맨 파일명 ·
#     리포 밖 플러그인 · 경로 아닌 모양은 건너뛰고 수를 공시한다(조용히 재해석하지 않는다).
#  2. 이력에서 사라진 이름은 헌장에 없다 — HEAD 이력에서 agent · 스크립트 · 플러그인으로 존재했으나
#     지금 어떤 추적 파일 이름으로도 없는 식별자 모양(`-` `_` `.` 를 품은) 이름. 백틱 밖 산문도 잰다.
#     한 단어 이름(예: adversarial)은 산문 낱말과 부딪쳐 건너뛴다 — 이 락이 못 보는 자리다.
# AC20 — marketplace.json · qg plugin.json · CLAUDE.md 에 runtime-verifier · 2-gate 가 없다.
# git 트리 · 이력을 못 읽으면 조용히 통과하지 않는다(git archive 사본 · 얕은 클론은 RED).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  cd "$ROOT" || exit 1
  printf '%s\n' CLAUDE.md .claude-plugin/marketplace.json plugins/quality-gates/.claude-plugin/plugin.json
  git ls-files -- 'docs/philosophy/*.md'
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
OUT="$(mktemp)" || exit 1
trap 'rm -f "$OUT"' EXIT
PYTHONDONTWRITEBYTECODE=1 python3 - "$ROOT" > "$OUT" <<'PY'
import fnmatch, json, os, re, subprocess, sys

sys.stdout.reconfigure(encoding="utf-8")
QG_DESC = ("Quality verification pipeline — one pipeline, one verdict (review + mandatory differential test) "
           "with multi-plugin review delegation, plus a separate consent-gated PR-understanding generate/publish "
           "surface (not a gate). Invoke manually via /qg or /qg-publish.")
os.chdir(sys.argv[1])


def out(kind, msg):
    print(kind + "\t" + msg)


def git(*args):
    try:
        r = subprocess.run(["git", *args], capture_output=True, text=True)
    except OSError:
        return 127, ""
    return r.returncode, r.stdout


def read(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read()
    except OSError as e:
        out("NO", f"{path} 를 읽을 수 없다: {e}")
        return None


rc, ls = git("ls-files")   # 추적 파일만 — 워킹트리의 untracked 파일이 판정을 바꾸지 않는다
if rc != 0 or not ls.strip():
    out("NO", f"git 트리를 읽을 수 없다(rc={rc}) — 트리 없이 인용을 판정하지 않는다")
    sys.exit(0)
tracked = [p for p in ls.splitlines() if p]
tracked_set = set(tracked)
tracked_dirs = set()
for p in tracked:
    parts = p.split("/")
    for i in range(1, len(parts)):
        tracked_dirs.add("/".join(parts[:i]))

charter = ["CLAUDE.md"] + sorted(p for p in tracked if re.fullmatch(r"docs/philosophy/[^/]+\.md", p))
texts = {}
for p in charter:
    t = read(p)
    if t is not None:
        texts[p] = t
if "CLAUDE.md" in texts and len(texts) >= 2:
    out("OK", f"헌장 코퍼스 {len(texts)}개를 읽었다(CLAUDE.md + docs/philosophy/*.md — 하한 2)")
else:
    out("NO", f"헌장 코퍼스가 {len(texts)}개다 — CLAUDE.md 와 철학 문서가 함께 있어야 한다")

# ── 갈래 1: 모양으로 인식되는 인용은 실재한다 ────────────────────────────────
plugins = {p.split("/")[1] for p in tracked
           if re.fullmatch(r"plugins/[^/]+/\.claude-plugin/plugin\.json", p)}


def members(pl):
    s = set()
    for p in tracked:
        m = re.fullmatch(r"plugins/" + re.escape(pl) + r"/(?:agents|commands)/([^/]+)\.md", p)
        if m:
            s.add(m.group(1))
        m = re.fullmatch(r"plugins/" + re.escape(pl) + r"/skills/([^/]+)/SKILL\.md", p)
        if m:
            s.add(m.group(1))
    return s


PLUGREF = re.compile(r"[a-z0-9][a-z0-9-]*:[a-z0-9][a-z0-9-]*")
skipped = {"템플릿": 0, "글롭": 0, "맨 파일명": 0, "리포 밖 플러그인·자리표시": 0, "경로 아닌 모양": 0}
checked = []
for doc, text in texts.items():
    toks = re.findall(r"`([^`\n]+)`", text) + re.findall(r"\]\(([^)\s]+)\)", text)
    for raw in toks:
        tok = raw.strip()
        if "<" in tok or ">" in tok:
            skipped["템플릿"] += 1
            continue
        if "*" in tok:
            # 리포 최상위 항목으로 시작하는 글롭은 추적 파일 1건 이상에 맞아야 한다(글롭 오타를 숨기지 않는다).
            # 그 밖의 글롭(규약 모양 — `*-journal.jsonl` 등)은 건너뛰고 수를 공시한다.
            head = tok.split("/", 1)[0]
            if "/" in tok and head in tracked_dirs:
                checked.append((doc, tok))
                if not any(fnmatch.fnmatchcase(p, tok) for p in tracked):
                    out("NO", f"{doc}: `{tok}` — 그 글롭에 맞는 추적 파일이 없다")
            else:
                skipped["글롭"] += 1
            continue
        if PLUGREF.fullmatch(tok):
            pl, name = tok.split(":", 1)
            if pl not in plugins:
                skipped["리포 밖 플러그인·자리표시"] += 1
                continue
            checked.append((doc, tok))
            if name not in members(pl):
                out("NO", f"{doc}: `{tok}` — 플러그인 {pl} 에 그 agent · skill · command 가 없다")
            continue
        if "/" not in tok:
            if re.fullmatch(r"[^\s/]+\.(?:md|sh|py|json)", tok):
                skipped["맨 파일명"] += 1
            continue
        if (re.match(r"[a-z][a-z0-9+.-]*://", tok) or tok.startswith("/")
                or tok.startswith("#") or re.search(r"\s", tok)):
            skipped["경로 아닌 모양"] += 1
            continue
        path = re.sub(r":\d+(?:-\d+)?$", "", tok.split("#", 1)[0])   # `경로:줄` · `경로:줄-줄` 인용
        if path.startswith("./") or path.startswith("../"):
            path = os.path.normpath(os.path.join(os.path.dirname(doc), path))
        path = path.rstrip("/")
        checked.append((doc, tok))
        if path not in tracked_set and path not in tracked_dirs:
            out("NO", f"{doc}: `{tok}` — 그 경로가 리포에 없다")
n_claude = sum(1 for d, _ in checked if d == "CLAUDE.md")
if len(checked) >= 10 and n_claude >= 3:
    out("OK", f"모양 인용 {len(checked)}건을 실재와 대조했다(CLAUDE.md {n_claude}건 — 하한 전체 10 · CLAUDE.md 3)")
else:
    out("NO", f"모양 인용이 {len(checked)}건(CLAUDE.md {n_claude}건)뿐이다 — 도출이 무너졌다(하한 10 · 3)")
out("NOTE", "건너뛴 모양 — " + " · ".join(f"{k} {v}" for k, v in skipped.items()))

# ── 갈래 2: 이력에서 사라진 이름은 헌장에 없다 ──────────────────────────────
rc, hist = git("log", "HEAD", "--no-renames", "--format=", "--name-only", "--diff-filter=A", "--",
               ":(glob)plugins/*/agents/*.md", ":(glob)plugins/*/scripts/*",
               ":(glob)plugins/*/.claude-plugin/plugin.json")
if rc != 0 or not hist.strip():
    out("NO", f"git 이력을 읽을 수 없다(rc={rc}) — 사라진 이름을 도출하지 못하면 판정하지 않는다")
else:
    ever = set()
    for p in hist.split():
        parts = p.split("/")
        if p.endswith("/.claude-plugin/plugin.json"):
            ever.add(parts[1])
        elif len(parts) >= 4 and parts[2] == "agents":
            ever.add(parts[-1][:-3])
        else:
            ever.add(parts[-1])
    # 「지금 있는 이름」은 플러그인 · 공유 모듈 트리에서만 도출한다 — docs/ 의 무관한 문서 이름이
    # 사라진 agent 이름과 우연히 같아 고아를 가리는 것을 막는다.
    now = set()
    for p in tracked:
        if not (p.startswith("plugins/") or p.startswith("shared/")):
            continue
        for comp in p.split("/"):
            now.add(comp)
            now.add(os.path.splitext(comp)[0])
    gone = sorted(n for n in ever if n not in now)
    ident = [n for n in gone if re.search(r"[-_.]", n)]
    words = [n for n in gone if not re.search(r"[-_.]", n)]
    # 양의 짝 — 세 축(agent · 스크립트 · 플러그인)마다 알려진 제거 하나가 도출에 보여야 한다.
    # 한 축의 pathspec 이 깨지면 그 축의 고아가 조용히 사라지므로 축마다 잰다.
    for known, axis in (("runtime-verifier", "agent · PR4b"), ("detect-runtime.sh", "스크립트 · PR4b"),
                        ("agent-transparency", "플러그인 · #159")):
        if known in ident:
            out("OK", f"이력 도출이 알려진 제거 {known}({axis})를 본다(양의 짝)")
        else:
            out("NO", f"이력 도출이 알려진 제거 {known}({axis})를 못 본다 — 그 축의 도출이 무너졌거나 얕은 클론이다")
    out("NOTE", f"사라진 이름 {len(gone)}개 — 식별자 모양 {len(ident)}개 검사 · 한 단어 {len(words)}개 건너뜀({', '.join(words) or '-'})")
    def occurrences(name, text):
        return len(re.findall(r"(?<![A-Za-z0-9_.-])" + re.escape(name) + r"(?![A-Za-z0-9_-])", text))
    # 매처 자체의 대조 — 정규식이 부러지면 hits==0 으로 조용히 GREEN 이 되는 것을 막는다.
    if occurrences("runtime-verifier", "x runtime-verifier y") == 1 and occurrences("runtime-verifier", "x runtime-verifier-x y") == 0:
        out("OK", "헌장 매처가 합성 문자열에서 이름 하나를 잡고 더 긴 식별자는 잡지 않는다(매처 대조)")
    else:
        out("NO", "헌장 매처가 합성 대조를 통과하지 못했다 — 정규식이 부러졌다")
    hits = 0
    for doc, text in texts.items():
        for n in ident:
            k = occurrences(n, text)
            if k:
                hits += 1
                out("NO", f"{doc}: 이력에서 사라진 이름 `{n}` 이 {k}곳에 있다 — 그 대상이 지금 트리에 없다")
    if hits == 0:
        out("OK", "헌장에 이력에서 사라진 식별자 모양 이름이 없다")

# ── AC20: 공개 계약 · 헌장에 옛 표면이 없다 ───────────────────────────────
# 한국어형(「두 게이트」 · 「2-게이트」 · 「2게이트」)도 잡는다 — 헌장은 Korean-primary 다.
FORBID = re.compile(r"runtime-verifier|(?i:\b(?:2|two)[- ]gates?\b)|(?:두|2)[ -]?게이트")
for p in (".claude-plugin/marketplace.json", "plugins/quality-gates/.claude-plugin/plugin.json", "CLAUDE.md"):
    t = read(p)
    if t is None:
        continue
    m = FORBID.search(t)
    if m:
        out("NO", f"{p}: 옛 표면 `{m.group(0)}` 이 남았다(AC20)")
    else:
        out("OK", f"{p}: runtime-verifier · 2-gate 가 없다(AC20)")
mk_desc = pj_desc = None
try:
    mk = json.loads(read(".claude-plugin/marketplace.json") or "null")
    ents = [e for e in (mk or {}).get("plugins", []) if isinstance(e, dict) and e.get("name") == "quality-gates"]
    if len(ents) == 1:
        mk_desc = ents[0].get("description")
    else:
        out("NO", f"marketplace.json 의 quality-gates 항목이 {len(ents)}개다")
    pj = json.loads(read("plugins/quality-gates/.claude-plugin/plugin.json") or "null")
    pj_desc = (pj or {}).get("description")
except (ValueError, AttributeError) as e:
    out("NO", f"공개 계약 JSON 을 해석할 수 없다: {e}")
if isinstance(mk_desc, str) and isinstance(pj_desc, str):
    # 공개 계약은 문자열 전체로 잰다 — 부분 문자열(「differential test」)은 부정문
    # (「no differential test」)도 통과시킨다(모의 실행 실측).
    if pj_desc == QG_DESC:
        out("OK", "plugin.json 의 qg 설명이 한 파이프라인의 공개 계약 문자열과 같다(양의 짝)")
    else:
        out("NO", "plugin.json 의 qg 설명이 공개 계약 문자열과 다르다 — 설명을 바꾸려면 이 락의 QG_DESC 도 함께 바꾼다")
    if mk_desc == pj_desc:
        out("OK", "marketplace.json 과 plugin.json 의 qg 설명이 같다")
    else:
        out("NO", "marketplace.json 과 plugin.json 의 qg 설명이 다르다")
else:
    out("NO", "qg 설명을 두 JSON 에서 찾지 못했다")
PY
rc=$?
[ "$rc" -eq 0 ] || no "판정 코어가 죽었다(rc=$rc) — 판정 없이 통과하지 않는다"
TAB="$(printf '\t')"
n=0
while IFS="$TAB" read -r kind msg; do
  n=$((n+1))
  case "$kind" in
    OK) ok "$msg" ;;
    NO) no "$msg" ;;
    NOTE) note "  · $msg" ;;
    *) no "판정 코어가 모르는 줄을 냈다: $kind $msg" ;;
  esac
done < "$OUT"
[ "$n" -gt 0 ] || no "판정 코어가 아무 줄도 내지 않았다"
finish
