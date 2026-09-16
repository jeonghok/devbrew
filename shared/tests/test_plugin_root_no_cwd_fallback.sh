#!/usr/bin/env bash
# guards: plugins/*/skills/*.md plugins/*/commands/*.md plugins/*/references/*.md
#
# skill · command · reference 마크다운이 모델에게 건네는 플러그인 루트는 cwd 로 풀리지 않는다.
#
# 치환은 SKILL.md 본문을 로드할 때 글자 그대로의 `${CLAUDE_PLUGIN_ROOT}` 토큰에만 온다. Bash 도구
# 환경에는 그 변수가 없고, `Read` 로 연 reference 파일은 글자 그대로 온다(2.1.270 실측 — 설계
# docs/superpowers/specs/2026-09-14-plugin-root-cwd-fallback-design.md 「실측」). 그래서 잰다:
#
#  축 1  — 본문 어디에도 bare 가 아닌 루트 전개(`${CLAUDE_PLUGIN_ROOT` 뒤에 `}` 가 아닌 무엇이든 — `:-` · `-` · `:=` · `:?` 등)가 없다. SKILL.md 에서도 치환되지 않아 끝자락으로 떨어진다(C1).
#  축 1b — 본문 어디에도 cwd 상대 플러그인 루트가 없다: `./plugins/` 리터럴(대입 끝자락 · 산문 모두),
#          그리고 자기 플러그인 스크립트를 실행하는 코드 스팬 · bash 줄이 넘기는 cwd 상대
#          `plugins/<자기 플러그인>/…` 인자. 처분 앵커 · 문서 포인터처럼 명령이 아닌 자리와 감사 대상
#          `plugins/<target>` 은 명령의 첫 낱말이 자기 스크립트가 아니거나 자기 플러그인 이름이 아니라서
#          걸리지 않는다.
#  축 2  — reference 파일의 bash 펜스(들여쓴 펜스 포함) 중 루트를 쓰는 것은, 같은 펜스에서 그 사용보다
#          앞에 `X="${CLAUDE_PLUGIN_ROOT}"; [ -n "$X" ] || { echo "…" >&2; exit N; }` 한 줄이 있다.
#          「루트를 쓴다」는 코퍼스 전체에서 모은 가드 변수 이름으로 판정한다 — reference 펜스는 SKILL.md
#          펜스 뒤에 이어 붙여 한 호출로 도는 것이 호출 관습이라, 그 파일 안에 대입이 없어도 루트를 쓴다.
#  축 2b — 가드가 잡은 루트 변수를 같은 펜스에서 다시 대입하지 않는다(모든 마크다운의 bash 펜스). 가드는
#          빈 값에서 멈출 뿐이고, 그 뒤에서 `pwd` 나 상대 경로로 루트를 되살리면 결함이 그대로 돌아온다.
#  축 3  — 루트 토큰을 담은 reference 마다 그것을 `Read` 하는 SKILL.md 줄이 있고, 그 줄은 전부
#          `${CLAUDE_PLUGIN_ROOT}/…` 절대 형태이며, 같은 절에 치환 안내 문장이 **줄 전체 그대로** 있다.
#          부분 문자열로 재면 문장 뒤에 부정을 붙여도 통과한다.
#  C3/C4 — 가드 줄의 메시지에 `${CLAUDE_PLUGIN_ROOT}` 가 없고(SKILL.md 에서는 그것까지 치환된다), 가드를
#          담은 펜스에서 가드 앞에 `set -u` 가 없다(unbound 오류가 복구 메시지를 가린다).
#  C5    — 가드 메시지가 원인과 복구 지시를 함께 싣는다. 치환이 없는 하니스에서 cwd 실행을 실제로 막는
#          것은 비0 종료가 아니라 이 문장이고, 대표 펜스의 stderr 만 재면 나머지 자리는 무방비다.
#  행동  — 대표 펜스 둘(SKILL.md 하나 · reference 하나)을 잘라, 무치환 · 변수 없음 · cwd 에
#          `./plugins/quality-gates/scripts/` 미끼가 있는 조건에서 미끼가 돌지 않고 비0 으로 끝나며
#          복구 지시가 나오는지, 토큰을 픽스처 루트로 바꾼 조건에서 픽스처 스크립트가 도는지 실행한다.
#          축 1b 의 자기 하니스 인자 탐지에는 합성 단위를 태우는 양성 대조가 따로 있다(N_PROBE).
#
# 재지 못하는 것: 이름만 적힌 스크립트 호출과 「리포 root에서」 같은 산문 루트 진술(실행 지시인지
# 설명인지 가려야 한다), 치환이 없는 하니스에서 모델이 `Read` 경로를 어떻게 푸는지, `Read` 로 연 파일이
# 다시 가리키는 2차 포인터, 그리고 태그가 `bash` 가 아닌 펜스(태그 없음 · `sh`) — 축 1b 의 자기 하니스
# 인자 · 축 2 · 축 2b · C3 · C4 · C5 는 bash 태그 펜스만 본다.
#
# 파싱은 python 으로 한다 — 셸 본문 추출기는 조용히 깨진다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1

# 대상은 열거가 아니라 도출이다. pathspec 의 `*` 는 `/` 를 넘으므로 세 글롭이 모든 깊이를 덮고,
# 심볼릭 링크로 배포된 파일(mode 120000)도 경로로 나온다 — 읽기는 링크를 따라간다.
# 추적 전인 새 파일도 대상이다(`--others --exclude-standard`).
CORPUS="$(git ls-files --cached --others --exclude-standard -- \
  'plugins/*/skills/*.md' 'plugins/*/commands/*.md' 'plugins/*/references/*.md' | LC_ALL=C sort -u)"
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' "$CORPUS"
  exit 0
fi

. "$ROOT/shared/tests/assert.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/plugin-root-lock.XXXXXX")" || { echo "mktemp 실패" >&2; exit 1; }
trap 'rm -rf "$TMP"' EXIT
printf '%s\n' "$CORPUS" > "$TMP/corpus.txt"

python3 - "$TMP" "$TMP/corpus.txt" > "$TMP/report.tsv" <<'PY'
import os
import re
import sys

out_dir, corpus_file = sys.argv[1], sys.argv[2]
files = [l for l in open(corpus_file, encoding="utf-8").read().split("\n") if l]
TOKEN = "${CLAUDE_PLUGIN_ROOT}"
SENT = ("그 파일의 플러그인 루트 변수(`CLAUDE_PLUGIN_ROOT`)는 치환되지 않은 채로 온다 — 읽거나 실행할 때 "
        "`${CLAUDE_PLUGIN_ROOT}` 로 바꿔 넣는다. 위 `Read` 줄의 경로가 절대 경로로 보이지 않으면 reference 를 "
        "cwd 에서 찾지 말고 멈춰 보고한다.")
FM = re.compile(r"\A---\n.*?\n---\n", re.S)
FOPEN = re.compile(r"^(\s*)```(\S*)\s*$")
GUARD = re.compile(r'^\s*([A-Za-z_]\w*)="\$\{CLAUDE_PLUGIN_ROOT\}"; \[ -n "\$\1" \] \|\| '
                   r'\{ echo "([^"]*)" >&2; exit [1-9][0-9]*; \}(\s+#.*)?\s*$')
HEADING = re.compile(r"^#{1,6} ")
READ = re.compile(r"^\s*Read\s+(\S+\.md)\s*$")
SET_U = re.compile(r"^\s*set\s+(-[A-Za-z]*u|-o\s+nounset)")
INTERP = {"python3", "python", "bash", "sh", "node", "exec", "env"}
REP = {"skill": ("plugins/quality-gates/skills/quality-pipeline/SKILL.md", "/scripts/check-review-scope.sh"),
       "ref": ("plugins/quality-gates/skills/quality-pipeline/references/runtime-gate.md", "/scripts/resolve-baseline.sh")}


def emit(tag, path, line, text):
    print(f"{tag}\t{path}:{line}\t{' '.join(text.split())[:170]}")


def load(path):
    txt = open(path, encoding="utf-8").read()
    m = FM.match(txt)
    return txt.split("\n"), (txt[:m.end()].count("\n") if m else 0)


def fences(lines, start):
    """(여는 idx, 닫는 idx, 언어, 들여쓰기). 닫는 줄은 같은 들여쓰기의 ``` 이다 — 목록 안 펜스 포함."""
    out, i = [], start
    while i < len(lines):
        m = FOPEN.match(lines[i])
        if m:
            ind, lang = m.group(1), m.group(2)
            close = re.compile("^" + re.escape(ind) + r"```\s*$")
            j = i + 1
            while j < len(lines) and not close.match(lines[j]):
                j += 1
            out.append((i, j, lang, ind))
            i = j + 1
            continue
        i += 1
    return out


scripts_cache = {}


def own_scripts(p):
    if p not in scripts_cache:
        d = os.path.join("plugins", p, "scripts")
        names = os.listdir(d) if os.path.isdir(d) else []
        scripts_cache[p] = {n for n in names if re.search(r"\.(py|sh|js)$", n)}
    return scripts_cache[p]


def command_violations(unit, p, is_bash):
    """자기 스크립트를 실행하는 명령 단위라면 그 안의 cwd 상대 `plugins/<p>/…` 낱말들.

    산문 코드 스팬은 인자가 있을 때만 명령으로 본다 — 경로 하나만 담긴 스팬은 문서 포인터다."""
    toks = [t.strip("\"'`(") for t in unit.split()]
    i = 0
    while i < len(toks) and (re.match(r"^[A-Za-z_]\w*=", toks[i]) or toks[i] in INTERP):
        m = re.match(r'^[A-Za-z_]\w*="?\$\((.*)$', toks[i])
        if m and m.group(1):
            toks[i] = m.group(1).strip("\"'")
            break
        i += 1
    if i >= len(toks) or os.path.basename(toks[i]) not in own_scripts(p):
        return []
    if not is_bash and len(toks) - i == 1:
        return []
    bad = []
    for t in toks[i:]:
        if t.startswith("--") and "=" in t:
            t = t.split("=", 1)[1]
        if t.startswith(f"plugins/{p}/") or t == f"plugins/{p}":
            bad.append(t)
    return bad


# 가드가 잡는 루트 변수 이름은 코퍼스 전체에서 모은다. reference 펜스를 SKILL.md 펜스 뒤에 이어 붙여
# 한 호출로 도는 것이 이 리포의 호출 관습이라, 그 파일 안에 대입이 없어도 루트를 쓰는 펜스일 수 있다 —
# 파일 안 대입만 보면 그런 펜스는 축 2 대상에서 통째로 빠지고 하한도 그것을 세지 않는다.
GLOBAL_ROOTVARS = set()
for _p in files:
    _lines, _s = load(_p)
    for _l in _lines[_s:]:
        _g = GUARD.match(_l)
        if _g:
            GLOBAL_ROOTVARS.add(_g.group(1))
        _m = re.match(r'^\s*([A-Za-z_]\w*)="\$\{CLAUDE_PLUGIN_ROOT\}"', _l)
        if _m:
            GLOBAL_ROOTVARS.add(_m.group(1))

n_a2 = 0
ref_with_var = []
skills = [f for f in files if f.endswith("/SKILL.md")]
for path in files:
    lines, start = load(path)
    p = path.split("/")[1]
    fz = fences(lines, start)
    infence = set()
    bash_units = []
    for (o, c, lang, ind) in fz:
        infence.update(range(o, c + 1))
        if lang != "bash":
            continue
        buf, first = "", None
        for k in range(o + 1, c):
            t = re.sub(r"(^|\s)#.*$", "", lines[k])
            first = k if first is None else first
            if t.rstrip().endswith("\\"):
                buf += t.rstrip()[:-1] + " "
                continue
            bash_units.append((first, buf + t))
            buf, first = "", None
    # 축 1 · 축 1b(리터럴)
    for k in range(start, len(lines)):
        if re.search(r"\$\{CLAUDE_PLUGIN_ROOT(?!\})", lines[k]):
            emit("A1", path, k + 1, lines[k])
        if "./plugins/" in lines[k]:
            emit("A1B", path, k + 1, lines[k])
    # 축 1b(자기 하니스 인자) — 산문의 코드 스팬(여러 줄 허용, 빈 줄 불허) + bash 논리 줄
    prose = "\n".join("" if (k < start or k in infence) else lines[k] for k in range(len(lines)))
    spans = [(prose[:m.start()].count("\n"), m.group(1)) for m in re.finditer(r"`([^`]+)`", prose)
             if "\n\n" not in m.group(1)]
    for (k, unit, is_bash) in [u + (True,) for u in bash_units] + [s + (False,) for s in spans]:
        for t in command_violations(unit, p, is_bash):
            emit("A1B", path, k + 1, f"{t} ← {unit}")
    # C3 · C4 — 가드 줄
    for (o, c, lang, ind) in fz:
        if lang != "bash":
            continue
        seen_set_u = None
        for k in range(o + 1, c):
            if SET_U.match(lines[k]):
                seen_set_u = k
            g = GUARD.match(lines[k])
            if g:
                if "CLAUDE_PLUGIN_ROOT" in g.group(2):
                    emit("C4", path, k + 1, lines[k])
                if seen_set_u is not None:
                    emit("C3", path, seen_set_u + 1, lines[seen_set_u])
                # C5 — 메시지가 원인과 복구 지시를 함께 싣는다. 치환이 없는 하니스에서 cwd 실행을
                # 실제로 막는 것은 비0 종료가 아니라 이 문장이다(설계 §2 의 고리 (2)). 대표 펜스 둘의
                # stderr 만 재면 나머지 자리에서 문구를 뒤집어도 통과한다.
                if not all(s in g.group(2) for s in
                           ("플러그인 루트 미해석", "추측하지 말고(cwd 포함) 멈춰 보고하라")):
                    emit("C5", path, k + 1, lines[k])
    # 축 2b — 가드가 잡은 루트 변수를 같은 펜스에서 cwd 쪽 값으로 다시 대입하지 않는다.
    # 가드는 빈 값에서 멈출 뿐 그 뒤를 보지 않는다. 이 릴리스가 「설치본 skill 은 워킹트리 스크립트를
    # 더는 돌리지 않는다」를 공시했으므로, `pwd` 로 루트를 되살리려는 유인이 새로 생겼다.
    # reference 뿐 아니라 SKILL.md 펜스도 본다 — 가드를 둔 자리라면 그 가드가 지켜져야 한다.
    for (o, c, lang, ind) in fz:
        if lang != "bash":
            continue
        guarded_here = set()
        for k in range(o + 1, c):
            g = GUARD.match(lines[k])
            if g:
                guarded_here.add(g.group(1))
                continue
            for v in guarded_here:
                m = re.match(r"^\s*(?:export\s+)?" + v + r"=(.*)$", lines[k])
                if (m and TOKEN not in m.group(1)) or re.search(r"\$\{" + v + r":?=", lines[k]):
                    emit("A2B", path, k + 1, lines[k])
                    break
    # 축 2 — reference 의 루트 사용 펜스
    if "/references/" in path:
        body = "\n".join(lines[start:])
        if "CLAUDE_PLUGIN_ROOT" in body:
            ref_with_var.append(path)
        rootvars = set(re.findall(r'([A-Za-z_]\w*)="\$\{CLAUDE_PLUGIN_ROOT\}"', body)) | GLOBAL_ROOTVARS
        for (o, c, lang, ind) in fz:
            if lang != "bash":
                continue
            blk = [(k, lines[k]) for k in range(o + 1, c)]
            def uses(t):
                return "CLAUDE_PLUGIN_ROOT" in t or any(re.search(r"\$\{?" + v + r"\b", t) for v in rootvars)
            if not any(uses(t) for (k, t) in blk):
                continue
            n_a2 += 1
            guarded, bad = set(), None
            for (k, t) in blk:
                g = GUARD.match(t)
                if g:
                    guarded.add(g.group(1))
                    continue
                if "CLAUDE_PLUGIN_ROOT" in t and not guarded:
                    bad = (k, "가드 앞에서 루트 토큰을 쓴다: " + t)
                    break
                late = [v for v in rootvars if re.search(r"\$\{?" + v + r"\b", t) and v not in guarded]
                if late:
                    bad = (k, f"가드 앞에서 ${late[0]} 를 쓴다: " + t)
                    break
            if not guarded:
                emit("A2", path, o + 1, "루트를 쓰는 펜스에 가드가 없다")
            elif bad:
                emit("A2", path, bad[0] + 1, bad[1])
    # 행동 테스트용 대표 펜스
    for role, (rp, needle) in REP.items():
        if path != rp:
            continue
        hits = [(o, c, ind) for (o, c, lang, ind) in fz if lang == "bash"
                and any(needle in lines[k] for k in range(o + 1, c))]
        if len(hits) != 1:
            print(f"REP_BAD\t{role}\t{path}\t{len(hits)}")
            continue
        o, c, ind = hits[0]
        with open(os.path.join(out_dir, f"{role}_fence.sh"), "w", encoding="utf-8") as fh:
            fh.write("\n".join(l[len(ind):] if l.startswith(ind) else l for l in lines[o + 1:c]) + "\n")
        print(f"REP\t{role}\t{path}:{o + 1}")
# 축 3
for r in ref_with_var:
    hits = []
    for s in skills:
        lines, start = load(s)
        heads = [k for k in range(start, len(lines)) if HEADING.match(lines[k])]
        fz = fences(lines, start)
        infence = set()
        for (o, c, lang, ind) in fz:
            infence.update(range(o, c + 1))
        heads = [k for k in heads if k not in infence]
        for k in range(start, len(lines)):
            m = READ.match(lines[k])
            if not m:
                continue
            ptr = m.group(1)
            if ptr.startswith(TOKEN + "/"):
                tgt, form = os.path.normpath(os.path.join("plugins", s.split("/")[1], ptr[len(TOKEN) + 1:])), "abs"
            elif ptr.startswith("$"):
                continue
            else:
                tgt, form = os.path.normpath(os.path.join(os.path.dirname(s), ptr)), "rel"
            if tgt != os.path.normpath(r):
                continue
            lo = max([h for h in heads if h < k], default=start)
            hi = min([h for h in heads if h > k], default=len(lines))
            hits.append((s, k, form, any(lines[j].strip() == SENT for j in range(lo, hi))))
    if not hits:
        emit("A3", r, 0, "이 reference 를 Read 하는 SKILL.md 줄이 없다")
    for (s, k, form, has_sent) in hits:
        if form != "abs":
            emit("A3", s, k + 1, "상대 형태 Read — 설치본에서 모델이 cwd 로 풀 수 있다")
        if not has_sent:
            emit("A3", s, k + 1, "같은 절에 치환 안내 문장(줄 전체)이 없다")
# 축 1b 자기 하니스 인자 탐지의 양성 대조. `own_scripts()` 가 빈 집합이 되면(디렉토리 이름 변경 ·
# 확장자 변경) 그 축은 위반 0 을 조용히 낸다 — 합성 단위 하나를 같은 코드 경로로 태워 잡히는지 본다.
probe = 0
for _p in sorted({f.split("/")[1] for f in files}):
    _sc = sorted(own_scripts(_p))
    if not _sc:
        continue
    if command_violations(f"{_sc[0]} --in plugins/{_p}/x", _p, True):
        probe = 1
    break
print(f"N_PROBE\t{probe}")
print(f"N_CORPUS\t{len(files)}")
print(f"N_A2\t{n_a2}")
print(f"N_A3\t{len(ref_with_var)}")
PY
py_rc=$?

count() { awk -F'\t' -v t="$1" '$1==t' "$TMP/report.tsv" | wc -l | tr -d ' '; }
val()   { awk -F'\t' -v t="$1" '$1==t {print $2}' "$TMP/report.tsv"; }
show()  { awk -F'\t' -v t="$1" '$1==t {print "      " $2 "  " $3}' "$TMP/report.tsv"; }

assert_eq "$py_rc" "0" "파서가 끝까지 돌았다 (rc $py_rc)"
n_corpus="$(val N_CORPUS)"; n_a2="$(val N_A2)"; n_a3="$(val N_A3)"
[ "${n_corpus:-0}" -ge 30 ] && ok "대상 마크다운 ${n_corpus}개 — vacuous 아님" \
  || no "대상 마크다운이 ${n_corpus:-0}개뿐 — 도출이 무너졌다(글롭 · 경로 변경?)"
for ax in A1 A1B A2 A2B A3 C3 C4 C5; do
  n="$(count "$ax")"
  case "$ax" in
    A1)  what="축 1: 본문의 bare 가 아닌 CLAUDE_PLUGIN_ROOT 전개" ;;
    A1B) what="축 1b: 본문의 cwd 상대 플러그인 루트(./plugins/ · 자기 하니스 cwd 인자)" ;;
    A2)  what="축 2: reference 펜스가 가드보다 먼저 루트를 쓴다 / 가드가 없다" ;;
    A2B) what="축 2b: 가드 뒤에 루트 변수를 다시 대입한다" ;;
    A3)  what="축 3: reference 를 여는 Read 줄이 절대 형태가 아니거나 안내 문장이 없다" ;;
    C3)  what="C3: 가드 앞의 set -u" ;;
    C4)  what="C4: 가드 메시지 안의 루트 토큰" ;;
    C5)  what="C5: 가드 메시지에 원인 · 복구 지시가 없다" ;;
  esac
  assert_eq "$n" "0" "$what — ${n}곳"
  [ "$n" -eq 0 ] || show "$ax"
done
# 하한 — 코퍼스가 무너지면(태그 · 들여쓰기 인식 · 경로) 축 2 · 3 이 공허하게 통과한다.
[ "${n_a2:-0}" -ge 22 ] && ok "축 2 대상 reference 펜스 ${n_a2}곳 (하한 22)" \
  || no "축 2 대상 reference 펜스가 ${n_a2:-0}곳 — 하한 22 미달(들여쓴 펜스 인식이 무너졌나?)"
[ "${n_a3:-0}" -ge 2 ] && ok "축 3 대상 reference ${n_a3}개 (하한 2)" \
  || no "축 3 대상 reference 가 ${n_a3:-0}개 — 하한 2 미달"
# 양성 대조 — 자기 하니스 인자 탐지는 대상 스크립트 목록이 비면 조용히 0 을 낸다(부재 락에는 양의 짝).
[ "$(val N_PROBE)" = "1" ] && ok "축 1b 자기 하니스 탐지 양성 대조 — 합성 단위를 잡는다" \
  || no "축 1b 자기 하니스 탐지가 합성 단위를 잡지 못했다 — 이 축은 이 실행에서 아무것도 재지 않았다"

# ── 행동 — 대표 펜스 둘 ──────────────────────────────────────────────────────
USER_REPO="$TMP/user"; FX="$TMP/fx/quality-gates"
mkdir -p "$USER_REPO/plugins/quality-gates/scripts" "$FX/scripts"
for n in check-review-scope.sh resolve-baseline.sh; do
  printf '#!/bin/sh\ntouch "%s/BAIT.%s"\n' "$TMP" "$n" > "$USER_REPO/plugins/quality-gates/scripts/$n"
  printf '#!/bin/sh\ntouch "%s/FIX.%s"\n' "$TMP" "$n" > "$FX/scripts/$n"
  chmod +x "$USER_REPO/plugins/quality-gates/scripts/$n" "$FX/scripts/$n"
done
for role in skill ref; do
  case "$role" in skill) n=check-review-scope.sh ;; ref) n=resolve-baseline.sh ;; esac
  fence="$TMP/${role}_fence.sh"
  if ! grep -q "^REP	$role	" "$TMP/report.tsv" || [ ! -s "$fence" ]; then
    no "행동($role): 대표 펜스($n)를 정확히 하나 찾지 못했다 — 아래 판정은 무의미하다"
    continue
  fi
  rm -f "$TMP/BAIT.$n" "$TMP/FIX.$n"
  ( cd "$USER_REPO" && env -i PATH="/usr/bin:/bin" HOME="$TMP" bash "$fence" ) >"$fence.out" 2>"$fence.err"; rc=$?
  [ "$rc" -ne 0 ] && ok "행동($role) 무치환: 비0 종료 (rc $rc)" || no "행동($role) 무치환: rc 0 으로 끝났다"
  [ ! -e "$TMP/BAIT.$n" ] && ok "행동($role) 무치환: cwd 의 미끼 $n 가 돌지 않았다" \
    || no "행동($role) 무치환: cwd 의 미끼 $n 가 돌았다 — 사용자 저장소의 스크립트를 실행한다"
  err="$(cat "$fence.err")"
  assert_contains "$err" "플러그인 루트 미해석" "행동($role) 무치환: stderr 에 원인이 나온다"
  assert_contains "$err" "추측하지 말고(cwd 포함) 멈춰 보고하라" "행동($role) 무치환: stderr 에 복구 지시가 나온다"
  python3 -c '
import sys
src, dst, root = sys.argv[1:4]
t = open(src, encoding="utf-8").read()
open(dst, "w", encoding="utf-8").write(t.replace("${CLAUDE_PLUGIN_ROOT}", root))
' "$fence" "$fence.subst" "$FX"
  rm -f "$TMP/BAIT.$n" "$TMP/FIX.$n"
  ( cd "$USER_REPO" && env -i PATH="/usr/bin:/bin" HOME="$TMP" bash "$fence.subst" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] && [ -e "$TMP/FIX.$n" ] && ok "행동($role) 치환 흉내: 픽스처 플러그인의 $n 가 돌았다 (양성 짝)" \
    || no "행동($role) 치환 흉내: 픽스처 플러그인의 $n 가 돌지 않았다 (rc $rc)"
  [ ! -e "$TMP/BAIT.$n" ] && ok "행동($role) 치환 흉내: 미끼는 돌지 않았다" || no "행동($role) 치환 흉내: 미끼가 돌았다"
done

finish
