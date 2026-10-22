#!/usr/bin/env bash
# skill 이 부르는 스크립트의 상태 폴더 쓰기가 마지막 성분의 링크를 따라가지 않는지 실행으로 잰다.
#   · seed_edit_diff.py — 기준 사본 · .shown · .reverted
#   · docreview_state.py — 원장(링크면 거절 · 제자리 덮어쓰기는 유지) · 시대 표지
# 세 skill(request-framing · reviewing-brief · spec-review)의 bash 펜스 쓰기는 도출 락(scan_writes)과
# 펜스를 잘라 실제로 돌리는 끝에서 끝 칸으로 잰다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
SED="$ROOT/plugins/spec-distill/scripts/seed_edit_diff.py"
DS="$ROOT/shared/docreview/scripts/docreview_state.py"
PROFILE="$ROOT/plugins/spec-distill/references/docreview-profiles/design-doc.md"
DOC="$ROOT/shared/tests/fixtures/docreview/design-sample.md"
T="$(mktemp -d -t sd-state-writes-XXXXXX)" || exit 1
trap 'chmod -R u+w "$T" 2>/dev/null; rm -rf "$T"' EXIT

mk_case() {   # mk_case <이름> → $T/<이름>/{work,out,state}, work/seed.md
  mkdir -p "$T/$1/work" "$T/$1/out" "$T/$1/state"
  printf 'alpha\nbeta\ngamma\n' > "$T/$1/work/seed.md"
}
sha_of() { python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"; }
plain() { [ -f "$1" ] && [ ! -L "$1" ]; }
ds_init() { python3 "$DS" init --state-dir "$1" --doc "$DOC" --profile "$PROFILE"; }

# ── seed_edit_diff ───────────────────────────────────────────────────────
mk_case sed_init_dangling_base; c="$T/sed_init_dangling_base"
ln -s "$c/out/new-target" "$c/work/base.md"
python3 "$SED" init "$c/work/base.md" "$c/work/seed.md" >/dev/null 2>&1
if [ -e "$c/out/new-target" ] || [ -L "$c/out/new-target" ]; then no "sed_init_dangling_base: 바깥 경로가 생겼다"; else ok "sed_init_dangling_base: 바깥 경로가 생기지 않았다"; fi
if plain "$c/work/base.md" && cmp -s "$c/work/base.md" "$c/work/seed.md"; then ok "sed_init_dangling_base: 기준 사본은 seed 와 같은 일반 파일"; else no "sed_init_dangling_base: 기준 사본이 일반 파일이 아니거나 seed 와 다르다"; fi

mk_case sed_accept_base_link; c="$T/sed_accept_base_link"
printf 'outside\n' > "$c/out/o.txt"
printf 'old\n' > "$c/work/old.md"
python3 "$SED" init "$c/work/base.md" "$c/work/old.md" >/dev/null 2>&1
python3 "$SED" hunks "$c/work/base.md" "$c/work/seed.md" >/dev/null 2>&1
rm -f "$c/work/base.md"; ln -s "$c/out/o.txt" "$c/work/base.md"
python3 "$SED" accept "$c/work/base.md" "$c/work/seed.md" >/dev/null 2>&1
assert_eq "$(cat "$c/out/o.txt")" "outside" "sed_accept_base_link: 바깥 파일 그대로"
if plain "$c/work/base.md" && cmp -s "$c/work/base.md" "$c/work/seed.md"; then ok "sed_accept_base_link: 기준 사본은 일반 파일"; else no "sed_accept_base_link: 기준 사본이 일반 파일이 아니다"; fi

mk_case sed_hunks_shown_link; c="$T/sed_hunks_shown_link"
printf 'outside\n' > "$c/out/o.txt"
printf 'alpha\n' > "$c/work/b0.md"
python3 "$SED" init "$c/work/base.md" "$c/work/b0.md" >/dev/null 2>&1
ln -s "$c/out/o.txt" "$c/work/base.md.shown"
python3 "$SED" hunks "$c/work/base.md" "$c/work/seed.md" >/dev/null 2>&1
assert_eq "$(cat "$c/out/o.txt")" "outside" "sed_hunks_shown_link: 바깥 파일 그대로"
if plain "$c/work/base.md.shown"; then assert_eq "$(cat "$c/work/base.md.shown")" "$(sha_of "$c/work/seed.md")" "sed_hunks_shown_link: .shown 은 해시를 담은 일반 파일"; else no "sed_hunks_shown_link: .shown 이 일반 파일이 아니다"; fi

mk_case sed_revert_markers_link; c="$T/sed_revert_markers_link"
printf 'alpha\nbeta\n' > "$c/work/b0.md"
python3 "$SED" init "$c/work/base.md" "$c/work/b0.md" >/dev/null 2>&1
printf '%s' "$(sha_of "$c/work/seed.md")" > "$c/out/o1.txt"   # .shown 이 읽힐 때 맞는 해시를 담은 바깥 파일
cp "$c/out/o1.txt" "$c/out/o1.keep"
ln -s "$c/out/o1.txt" "$c/work/base.md.shown"
ln -s "$c/out/o2.txt" "$c/work/base.md.reverted"
python3 "$SED" revert "$c/work/base.md" "$c/work/seed.md" --ids 1 >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "sed_revert_markers_link: revert 성공"
if cmp -s "$c/out/o1.txt" "$c/out/o1.keep"; then ok "sed_revert_markers_link: .shown 바깥 파일 그대로"; else no "sed_revert_markers_link: .shown 바깥 파일이 바뀌었다"; fi
if [ -e "$c/out/o2.txt" ] || [ -L "$c/out/o2.txt" ]; then no "sed_revert_markers_link: .reverted 바깥 경로가 생겼다"; else ok "sed_revert_markers_link: .reverted 바깥 경로가 생기지 않았다"; fi

# ── docreview_state ──────────────────────────────────────────────────────
mk_case ds_save_symlink_refused; c="$T/ds_save_symlink_refused"
printf 'outside\n' > "$c/out/o.txt"
ln -s "$c/out/nope" "$c/state/docreview-state.md"
err="$(ds_init "$c/state" 2>&1 >/dev/null)"; rc=$?
assert_eq "$rc" "1" "ds_save_symlink_refused: 끊어진 링크 원장은 rc 1"
assert_contains "$err" "ledger_not_plain_file" "ds_save_symlink_refused: 사유"
if [ -e "$c/out/nope" ] || [ -L "$c/out/nope" ]; then no "ds_save_symlink_refused: 바깥 경로가 생겼다"; else ok "ds_save_symlink_refused: 바깥 경로가 생기지 않았다"; fi
# 살아 있는 링크 — 저장하는 명령(begin-round)
mkdir -p "$c/state2" "$c/state0"
ds_init "$c/state0" >/dev/null 2>&1
cp "$c/state0/docreview-state.md" "$c/out/o.txt"
ln -s "$c/out/o.txt" "$c/state2/docreview-state.md"
before="$(cat "$c/out/o.txt")"
err="$(python3 "$DS" begin-round --state-dir "$c/state2" 2>&1 >/dev/null)"; rc=$?
assert_eq "$rc" "1" "ds_save_symlink_refused: 살아 있는 링크 원장도 rc 1"
assert_contains "$err" "ledger_not_plain_file" "ds_save_symlink_refused: 살아 있는 링크 사유"
assert_eq "$(cat "$c/out/o.txt")" "$before" "ds_save_symlink_refused: 바깥 파일 그대로"

mk_case ds_save_hardlink_refused; c="$T/ds_save_hardlink_refused"
mkdir -p "$c/state0"
ds_init "$c/state0" >/dev/null 2>&1
cp "$c/state0/docreview-state.md" "$c/out/o.txt"
ln "$c/out/o.txt" "$c/state/docreview-state.md"
before="$(cat "$c/out/o.txt")"
err="$(python3 "$DS" begin-round --state-dir "$c/state" 2>&1 >/dev/null)"; rc=$?
assert_eq "$rc" "1" "ds_save_hardlink_refused: 하드 링크 원장은 rc 1"
assert_contains "$err" "ledger_not_plain_file" "ds_save_hardlink_refused: 사유"
assert_eq "$(cat "$c/out/o.txt")" "$before" "ds_save_hardlink_refused: 다른 이름의 파일 그대로"

mk_case ds_era_link_not_followed; c="$T/ds_era_link_not_followed"
ln -s "$c/out/new-target" "$c/state/docreview-digest-era"
ds_init "$c/state" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "ds_era_link_not_followed: 원장은 저장된다"
if [ -e "$c/out/new-target" ] || [ -L "$c/out/new-target" ]; then no "ds_era_link_not_followed: 바깥 경로가 생겼다"; else ok "ds_era_link_not_followed: 바깥 경로가 생기지 않았다"; fi

mk_case ds_inplace_ro_dir_kept; c="$T/ds_inplace_ro_dir_kept"
ds_init "$c/state" >/dev/null 2>&1
chmod 555 "$c/state"
python3 "$DS" begin-round --state-dir "$c/state" >/dev/null 2>&1; rc=$?
chmod 755 "$c/state"
assert_eq "$rc" "0" "ds_inplace_ro_dir_kept: 쓰기 불가 폴더 안 원장도 갱신된다"
assert_contains "$(cat "$c/state/docreview-state.md")" "round: 1" "ds_inplace_ro_dir_kept: 라운드가 올랐다"

# ── 세 skill 펜스의 쓰기 — 도출 락 ─────────────────────────────────────────
# scan_writes <md> → rc 0 깨끗 · 1 위반. stderr 줄마다 `<줄 번호>: <사유>: <글>`, stdout 은 `fences=N writes=M`.
# ```bash 펜스는 글자 단위로 읽어 넘기기 · tee · touch 대상을 모은다. 허용 대상은 /dev/null 과
# 같은 펜스에서 $(mktemp …) 나 빈 값으로만 대입된 변수 하나다. 그 밖의 펜스는 줄 정규식으로 본다.
# ```bash 펜스마다 실제 셸과 맞춰 본다 — bash -n 통과, declare -f 로 편 본문의 대상 다중집합이 같다.
scan_writes() {
  python3 -I - "$1" <<'PY'
import collections
import os
import re
import subprocess
import sys
import tempfile

OPEN_RE = re.compile(r"^[ \t]*(`{3,}|~{3,})")
OP_RE = re.compile(r"&>>|&>|>>|>\||>&|<<<|<<-|<<|<>|<&|>|<|\|\||\|&|\||&&|;;&|;;|;&|;|&|\(|\)")
WRITE_OPS = {">", ">>", ">|", "&>", "&>>", "<>"}
READ_OPS = {"<", "<&", "<<", "<<-", "<<<"}
SEP_OPS = {";", ";;", ";;&", ";&", "&&", "||", "|", "|&", "&", "(", ")"}
KEYWORDS = {"then", "do", "else", "elif", "if", "while", "until", "!", "{", "}", "time",
            "command", "builtin", "exec", "nohup", "env", "esac", "fi", "done"}
DECL = {"export", "local", "readonly", "declare", "typeset"}
NAME = r"[A-Za-z_][A-Za-z0-9_]*"
VAR_TARGET = re.compile(r'"\$(%s)"|"\$\{(%s)\}"|\$(%s)|\$\{(%s)\}' % (NAME, NAME, NAME, NAME))
MKTEMP_VAL = re.compile(
    r'"?\$\(\s*mktemp(?:\s+(?:(?!\$\(|`)[^()|;&])*)?'
    r"(?:\|\|\s*printf\s+(?:'/dev/null'|\"/dev/null\"|/dev/null)\s*)?\)\"?")
PLACEHOLDER = re.compile(r"<[^<>\s][^<>\n]*?>")
OTHER_WRITE = [re.compile(r"(?:^|[\s;&|({])(?:\d*>>?|&>>?|>\|)(?!&)\s*\S"),
               re.compile(r"(?:^|[\s;&|({])(?:tee|touch)\s"),
               re.compile(r"exec\s*\d*>")]


class Reader:
    """```bash 펜스 본문 하나를 글자 단위로 읽는다."""

    def __init__(self, text):
        self.s = text
        self.writes = []      # (offset, 연산, 대상 원문)
        self.bad = []         # (offset, 사유)
        self.assign = collections.defaultdict(list)
        self.pending = []     # (구분자, <<- 여부, 따옴표 여부, offset)
        self.streams = []
        self.dbl = False

    def heredoc_bodies(self, i):
        s = self.s
        while self.pending:
            delim, strip, quoted, off = self.pending.pop(0)
            body_start, body = i, None
            while i < len(s):
                j = s.find("\n", i)
                end = len(s) if j < 0 else j
                line = s[i:end]
                i = len(s) if j < 0 else j + 1
                if (line.lstrip("\t") if strip else line) == delim:
                    body = s[body_start:end - len(line)]
                    break
            if body is None:
                body = s[body_start:]
            if not quoted and ("$(" in body or "`" in body):
                self.bad.append((off, "읽을 수 없는 heredoc 본문"))
        return i

    def single(self, i):
        j = self.s.find("'", i + 1)
        return len(self.s) if j < 0 else j + 1

    def ansi(self, i):
        s, j = self.s, i + 2
        while j < len(s):
            if s[j] == "\\":
                j += 2
            elif s[j] == "'":
                return j + 1
            else:
                j += 1
        return len(s)

    def nested(self, j):
        """j 자리의 $(( · $( · ${ · 역따옴표를 읽고 다음 자리를 낸다. 해당 없으면 None."""
        s = self.s
        if s.startswith("$((", j):
            return self.arith(j + 1)
        if s.startswith("$(", j):
            return self.lex(j + 2, ")")
        if s.startswith("${", j):
            return self.brace(j + 2)
        if s[j] == "`":
            return self.lex(j + 1, "`")
        return None

    def double(self, i):
        s, j = self.s, i + 1
        while j < len(s):
            if s[j] == "\\":
                j += 2
                continue
            if s[j] == '"':
                return j + 1
            k = self.nested(j)
            j = j + 1 if k is None else k
        return len(s)

    def brace(self, j):
        s = self.s
        m = re.match(r"(%s):?=" % NAME, s[j:])
        if m:
            self.assign[m.group(1)].append(None)
        while j < len(s):
            c = s[j]
            if c == "\\":
                j += 2
                continue
            if c == "}":
                return j + 1
            if c == "'":
                j = self.single(j)
                continue
            if c == '"':
                j = self.double(j)
                continue
            k = self.nested(j)
            j = j + 1 if k is None else k
        return len(s)

    def arith(self, i):
        s, j, depth = self.s, i, 0
        while j < len(s):
            if s[j] == "(":
                depth += 1
            elif s[j] == ")":
                depth -= 1
                if depth == 0:
                    return j + 1
            j += 1
        return len(s)

    def lex(self, i, stop):
        """보통 상태로 읽어 낱말 · 연산 · 줄바꿈 토큰을 모은다. stop 을 만나면 그 다음 자리를 낸다."""
        s, n = self.s, len(self.s)
        toks = []
        self.streams.append(toks)
        word = {"raw": "", "start": None}
        st = {"depth": 0, "case": 0, "delim": None}

        def at_cmd():
            if not toks:
                return True
            t = toks[-1]
            return t[0] == "nl" or (t[0] == "op" and t[1] in SEP_OPS) or (t[0] == "w" and t[1] in KEYWORDS)

        def flush():
            raw, start = word["raw"], word["start"]
            if start is None:
                return
            cmd = at_cmd()
            toks.append(("w", raw, start))
            if st["delim"] is not None:
                quoted = any(q in raw for q in "'\"\\")
                self.pending.append((re.sub(r"[\"'\\]", "", raw), st["delim"] == "<<-", quoted, start))
                st["delim"] = None
            elif cmd and raw == "[[":
                self.dbl = True
            elif raw == "]]":
                self.dbl = False
            elif cmd and raw == "case":
                st["case"] += 1
            elif cmd and raw == "esac":
                st["case"] -= 1
            word["raw"], word["start"] = "", None

        while i < n:
            c = s[i]
            if c == "\\" and s.startswith("\\\n", i):
                i += 2
                continue
            if stop == "`" and c == "`":
                flush()
                return i + 1
            if c in " \t":
                flush()
                i += 1
                continue
            if c == "\n":
                flush()
                toks.append(("nl", "\n", i))
                i = self.heredoc_bodies(i + 1)
                continue
            if c == "#" and word["start"] is None:
                j = s.find("\n", i)
                i = n if j < 0 else j
                continue
            j = None
            if c == "\\":
                j = i + 2
            elif c == "'":
                j = self.single(i)
            elif s.startswith("$'", i):
                j = self.ansi(i)
            elif c == '"':
                j = self.double(i)
            elif s.startswith("((", i) and word["start"] is None and at_cmd():
                j = self.arith(i)
            elif s.startswith(">(", i) or s.startswith("<(", i):
                if c == ">":
                    self.bad.append((i, "프로세스 치환"))
                j = self.lex(i + 2, ")")
            elif self.dbl and c in "<>()":
                j = i + 1
            else:
                j = self.nested(i)
            if j is not None:
                if word["start"] is None:
                    word["start"] = i
                word["raw"] += s[i:j]
                i = j
                continue
            m = OP_RE.match(s, i)
            if m:
                op, off = m.group(0), i
                if op[0] in "<>" and word["start"] is not None and word["raw"].isdigit():
                    op, off = word["raw"] + op, word["start"]
                    word["raw"], word["start"] = "", None
                else:
                    flush()
                if op == ")" and stop == ")" and st["depth"] == 0 and st["case"] == 0:
                    return i + 1
                if op == "(":
                    st["depth"] += 1
                elif op == ")" and st["depth"] > 0:
                    st["depth"] -= 1
                if op.lstrip("0123456789") in ("<<", "<<-"):
                    st["delim"] = op.lstrip("0123456789")
                toks.append(("op", op, off))
                i = m.end()
                continue
            if word["start"] is None:
                word["start"] = i
            word["raw"] += c
            i += 1
        flush()
        return n

    def interpret(self, toks):
        cmdpos, decl, tool = True, False, None
        k = 0
        while k < len(toks):
            t = toks[k]
            nxt = toks[k + 1] if k + 1 < len(toks) else None
            k += 1
            if t[0] == "nl":
                cmdpos, decl, tool = True, False, None
                continue
            if t[0] == "op":
                base = t[1].lstrip("0123456789")
                tgt = nxt[1] if nxt and nxt[0] == "w" else ""
                if base in WRITE_OPS or (base == ">&" and not re.fullmatch(r"\d+-?|-", tgt)):
                    self.writes.append((t[2], t[1], tgt))
                if base in WRITE_OPS or base in READ_OPS or base == ">&":
                    k += 1 if tgt else 0
                elif t[1] in SEP_OPS:
                    cmdpos, decl, tool = True, False, None
                continue
            w = t[1]
            if tool:
                if not w.startswith("-"):
                    self.writes.append((t[2], tool, w))
                continue
            m = re.match(r"(%s)\+?=" % NAME, w)
            if m and (cmdpos or decl):
                self.assign[m.group(1)].append(w[m.end():])
                continue
            if decl:
                if re.fullmatch(NAME, w):
                    self.assign[w].append("")
                continue
            if not cmdpos or w in KEYWORDS:
                continue
            if w in DECL:
                decl, cmdpos = True, False
                continue
            bare = os.path.basename(re.sub(r"[\"'\\]", "", w))
            if bare in ("tee", "touch"):
                tool, cmdpos = bare, False
                continue
            if bare == "for" and nxt and nxt[0] == "w":
                self.assign[nxt[1]].append(None)
            if bare in ("read", "mapfile", "readarray", "getopts"):
                for u in toks[k:]:
                    if u[0] != "w":
                        break
                    if re.fullmatch(NAME, u[1]):
                        self.assign[u[1]].append(None)
            if bare == "printf" and nxt and nxt[1] == "-v" and k + 1 < len(toks):
                self.assign[toks[k + 1][1]].append(None)
            cmdpos = False

    def run(self):
        self.lex(0, None)
        for toks in self.streams:
            self.interpret(toks)
        return self


def mktemp_vars(assign):
    out = set()
    for name, vals in assign.items():
        made = [v for v in vals if v is not None and MKTEMP_VAL.fullmatch(v)]
        if made and all(v is not None and (v in ("", '""', "''") or MKTEMP_VAL.fullmatch(v)) for v in vals):
            out.add(name)
    return out


def allowed(tgt, mk):
    if tgt in ("/dev/null", '"/dev/null"', "'/dev/null'"):
        return True
    m = VAR_TARGET.fullmatch(tgt)
    return bool(m) and next(g for g in m.groups() if g) in mk


def read(text):
    r = Reader(text).run()
    return r, collections.Counter(t for _o, _op, t in r.writes)


def bash_fence(body, first, bad):
    def where(off):
        return first + body.count("\n", 0, off)

    r, mine = read(body)
    mk = mktemp_vars(r.assign)
    for off, why in r.bad:
        bad.append((where(off), why))
    for off, op, tgt in r.writes:
        if not allowed(tgt, mk):
            bad.append((where(off), "허용 밖 쓰기(%s %s)" % (op, tgt)))
    with tempfile.TemporaryDirectory() as d:
        alone, wrapped = os.path.join(d, "fence.sh"), os.path.join(d, "wrap.sh")
        with open(alone, "w", encoding="utf-8") as fh:
            fh.write(body + "\n")
        if subprocess.run(["/bin/bash", "-n", alone], stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL).returncode != 0:
            bad.append((first, "셸이 읽지 못하는 펜스"))
            return len(r.writes)
        with open(wrapped, "w", encoding="utf-8") as fh:
            fh.write("f__() {\n" + body + "\n:\n}\ndeclare -f f__\n")
        shown = subprocess.run(["/bin/bash", wrapped], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                               stdin=subprocess.DEVNULL).stdout.decode("utf-8", "replace")
        if not shown.strip() or read(shown)[1] != mine:
            bad.append((first, "실제 셸과 다르게 읽음"))
    return len(r.writes)


def scan(path):
    with open(path, encoding="utf-8", newline="") as fh:
        lines = fh.read().split("\n")
    bad, fences, writes, i = [], 0, 0, 0
    while i < len(lines):
        m = OPEN_RE.match(lines[i])
        if not m:
            i += 1
            continue
        mark = m.group(1)
        close = re.compile(r"[ \t]*%s{%d,}[ \t]*\r?" % (re.escape(mark[0]), len(mark)))
        j = i + 1
        while j < len(lines) and not close.fullmatch(lines[j]):
            j += 1
        body = lines[i + 1:j]
        if lines[i] == "```bash":
            fences += 1
            writes += bash_fence("\n".join(body), i + 2, bad)
        else:
            for k, ln in enumerate(body):
                cut = PLACEHOLDER.sub("", ln)
                if any(p.search(cut) for p in OTHER_WRITE):
                    bad.append((i + 2 + k, "검사 밖 펜스의 쓰기"))
        i = j + 1
    for ln, why in sorted(bad):
        sys.stderr.write("%d: %s: %s\n" % (ln, why, lines[ln - 1].strip() if 0 < ln <= len(lines) else ""))
    print("fences=%d writes=%d" % (fences, writes))
    return 1 if bad else 0


sys.exit(scan(sys.argv[1]))
PY
}

note "== 펜스 쓰기 락 — 세 skill 폴더"
SKILL_MDS="$(cd "$ROOT" && git ls-files -- 'plugins/spec-distill/skills/request-framing/*' \
  'plugins/spec-distill/skills/reviewing-brief/*' 'plugins/spec-distill/skills/spec-review/*' | grep '\.md$')"
n_md="$(printf '%s\n' "$SKILL_MDS" | grep -c .)"
[ "$n_md" -ge 3 ] && ok "대상: 세 skill 폴더의 .md ${n_md}개" || no "대상: 세 skill 폴더의 .md 가 ${n_md}개 — 도출이 비었다"
for f in $SKILL_MDS; do
  out="$(scan_writes "$ROOT/$f" 2>"$T/scan.err")"; rc=$?
  if [ "$rc" = 0 ]; then ok "$f: 허용 밖 쓰기 없음 (${out})"
  else no "$f: 허용 밖 쓰기"; sed 's/^/      /' "$T/scan.err"; fi
  fw="$(printf '%s' "$out" | sed -n 's/^fences=\([0-9]*\) writes=\([0-9]*\)$/\1 \2/p')"
  case "$fw" in "0 "*|"") no "$f: bash 펜스를 하나도 못 읽었다(${out})" ;; *" 0") no "$f: 쓰기 자리를 하나도 못 봤다(${out})" ;; *) ok "$f: 펜스 · 쓰기를 읽었다(공허하지 않다)" ;; esac
  # writer 를 부르는 루트 변수는 그 펜스가 다른 스크립트를 부르는 루트 변수와 같다(아니면 빈 경로를 부른다)
  rv="$(python3 -I -c '
import re, sys
lines, out, i = open(sys.argv[1], encoding="utf-8").read().split("\n"), [], 0
while i < len(lines):
    if lines[i] != "```bash":
        i += 1
        continue
    j = i + 1
    while j < len(lines) and lines[j] != "```":
        j += 1
    body = "\n".join(lines[i + 1:j])
    w = set(re.findall(r"\"\$(\w+)/scripts/nofollow_write\.py\"", body))
    o = set(re.findall(r"\"\$(\w+)/scripts/(?!nofollow_write\.py)", body))
    if w and w != o:
        out.append("%d: writer %s · 다른 스크립트 %s" % (i + 1, sorted(w), sorted(o)))
    i = j + 1
print("\n".join(out))' "$ROOT/$f")"
  assert_eq "$rv" "" "$f: writer 를 그 펜스의 루트 변수로 부른다"
done

probe_md() {   # probe_md <라벨> <기대 rc> <stderr 에 있어야 할 말|-> <md 내용>
  printf '%s' "$4" > "$T/probe.md"
  scan_writes "$T/probe.md" >/dev/null 2>"$T/probe.err"; local rc=$?
  if [ "$rc" = "$2" ] && { [ "$3" = - ] || grep -qF -- "$3" "$T/probe.err"; }; then ok "프로브 ${1}: rc $rc"
  else no "프로브 ${1}: rc $rc (기대 $2 · ${3})"; sed 's/^/      /' "$T/probe.err"; fi
}
probe_bash() { probe_md "$1" "$2" "$3" "$(printf '```bash\n%s\n```\n' "$4")"; }
W='허용 밖 쓰기'
probe_bash '>' 1 "$W" 'cmd > "$STATE_DIR/x"'
probe_bash '>>' 1 "$W" 'cmd >> "$STATE_DIR/x"'
probe_bash '>|' 1 "$W" 'cmd >| "$STATE_DIR/x"'
probe_bash '&>' 1 "$W" 'cmd &> "$STATE_DIR/x"'
probe_bash '2>' 1 "$W" 'cmd 2> "$STATE_DIR/x"'
probe_bash '{ } >' 1 "$W" '{ a; b; } > "$STATE_DIR/x"'
probe_bash 'exec >' 1 "$W" 'exec > "$STATE_DIR/x"'
probe_bash '| tee' 1 "$W" 'cmd | tee "$STATE_DIR/x"'
probe_bash 'touch' 1 "$W" 'touch "$STATE_DIR/x"'
probe_bash '$( > )' 1 "$W" 'x="$(cmd > "$STATE_DIR/y")"'
probe_bash 'mktemp 뒤 다시 대입' 1 "$W" 'x="$(mktemp)"; x="$STATE_DIR/y"; echo > "$x"'
probe_bash 'tee >(…)' 1 '프로세스 치환' 'tee >(cat)'
probe_bash '따옴표 없는 heredoc' 1 '읽을 수 없는 heredoc 본문' "$(printf 'cat <<EOF\n$(touch y)\nEOF')"
probe_bash '줄 잇기' 1 "$W" "$(printf 'cmd \\\n> "$STATE_DIR/x"')"
O='검사 밖 펜스의 쓰기'
probe_md '```sh' 1 "$O" "$(printf '```sh\ncmd > "$STATE_DIR/x"\n```\n')"
probe_md '```shell' 1 "$O" "$(printf '```shell\ncmd > "$STATE_DIR/x"\n```\n')"
probe_md '들여쓴 ```bash' 1 "$O" "$(printf '  ```bash\ncmd > "$STATE_DIR/x"\n  ```\n')"
probe_md '```bash + 공백' 1 "$O" "$(printf '```bash \ncmd > "$STATE_DIR/x"\n```\n')"
probe_md '~~~bash' 1 "$O" "$(printf '~~~bash\ncmd > "$STATE_DIR/x"\n~~~\n')"
probe_md '```BASH' 1 "$O" "$(printf '```BASH\ncmd > "$STATE_DIR/x"\n```\n')"
probe_md 'CRLF 펜스' 1 "$O" "$(printf '```bash\r\ncmd > "$STATE_DIR/x"\r\n```\r\n')"
probe_bash 'mktemp heredoc(양성)' 0 - "$(printf 'T="$(mktemp)"; cat > "$T" <<'"'"'EOF'"'"'\n> "$STATE_DIR/y"\nEOF')"
probe_bash 'mktemp || /dev/null(양성)' 0 - "$(printf 'e="$(mktemp 2>/dev/null || printf '"'"'/dev/null'"'"')"; cmd 2>"$e"')"
probe_bash '>&2(양성)' 0 - 'echo x >&2'
probe_bash '2>&1(양성)' 0 - 'cmd 2>&1'
probe_bash '2>/dev/null(양성)' 0 - 'cmd 2>/dev/null'
probe_bash '따옴표 안 >(양성)' 0 - 'echo "a > b"'
probe_bash '주석(양성)' 0 - '# x > y'
probe_bash 'rm(양성)' 0 - 'rm -f "$STATE_DIR/x"'
probe_md '자리표 펜스(양성)' 0 - "$(printf '```text\n<document>${DOCUMENT}</document>\n<합격 > 기준>\n```\n')"

# ── 끝에서 끝 — 펜스를 잘라 임시 레포에서 돌리고 심어 둔 링크의 너머를 잰다 ──────────
note "== 펜스 끝에서 끝"
SDROOT="$ROOT/plugins/spec-distill"
RF_MD="$SDROOT/skills/request-framing/SKILL.md"; RB_MD="$SDROOT/skills/reviewing-brief/SKILL.md"
TR="$(cd "$T" && pwd -P)"; R="$TR/repo"; OUT="$TR/outside"
YAMLDIR="$(python3 -c 'import os, yaml; print(os.path.dirname(os.path.dirname(yaml.__file__)))' 2>/dev/null)"   # HOME 을 바꿔도 엔진이 pyyaml 을 찾게
mkdir -p "$R/docs" "$OUT" "$TR/home" "$TR/tmp" && git -C "$R" init -q
fence_with() {   # fence_with <md> <고정 문자열> → 그 문자열을 담은 첫 ```bash 펜스 본문
  P="$2" awk '/^```bash$/ {b=1; buf=""; has=0; next}
       b && /^```$/ {b=0; if (has && !done) {printf "%s", buf; done=1}; next}
       b {buf = buf $0 "\n"; if (index($0, ENVIRON["P"])) has=1}' "$1"
}
run_fence() {   # run_fence <스크립트> [VAR=값…] → rc · stderr 는 $TR/last.err
  local s="$1"; shift
  ( cd "$R" && env -i PATH=/usr/bin:/bin PYTHONPATH="$YAMLDIR" HOME="$TR/home" TMPDIR="$TR/tmp" PYTHONDONTWRITEBYTECODE=1 \
      CLAUDE_PLUGIN_ROOT="$SDROOT" DEVBREW_SPEC_DISTILL_SESSION_ID=sdwrites01 "$@" /bin/bash "$s" ) >/dev/null 2>"$TR/last.err"
}
state_dir_of() {   # state_dir_of <문서> → 머리와 같은 도출의 엔진 상태 폴더
  ( cd "$R" && python3 "$SDROOT/scripts/docreview_state.py" state-dir-for \
      --root "$(python3 "$SDROOT/scripts/state_path.py" state-root)" --doc "$1" )
}
outside() { printf 'outside %s\n' "$1" > "$OUT/$1"; }   # outside <이름> — 레포 밖 파일
kept() { assert_eq "$(cat "$OUT/$1")" "outside $1" "$2: 바깥 파일 $1 그대로"; }
plain_one() {   # plain_one <경로> <라벨> — 링크 수 하나인 일반 파일
  if plain "$1" && [ "$(python3 -c 'import os,sys;print(os.stat(sys.argv[1]).st_nlink)' "$1")" = 1 ]; then ok "$2: 그 자리는 링크 수 하나인 일반 파일"
  else no "$2: 그 자리가 일반 파일이 아니거나 링크가 둘 이상이다"; fi
}
for blk in "RB 번들:$RB_MD:build_brief_bundle.py" "RB kill switch:$RB_MD:--component \"<a>\"" \
           "RF 번들:$RF_MD:--for recritic" "RF hunks:$RF_MD:\"\$STATE_DIR/hunks.json\"" "RF drops:$RF_MD:gate-drops.json"; do
  label="${blk%%:*}"; rest="${blk#*:}"; md="${rest%%:*}"; pat="${rest#*:}"
  fence_with "$md" "$pat" > "$TR/blk.sh"
  if [ -s "$TR/blk.sh" ] && grep -q 'nofollow_write.py' "$TR/blk.sh" && bash -n "$TR/blk.sh" 2>/dev/null; then ok "추출: ${label} 펜스(writer 호출 · bash -n 통과)"
  else no "추출: ${label} 펜스가 비었거나 writer 를 부르지 않거나 문법이 깨졌다 — 아래 판정은 무의미하다"; fi
done

# RB 번들 펜스 — payload · audit 은 레포 안 docs
PAY="$R/docs/brief-sample.md"; AUD="$R/docs/brief-sample.audit.md"
cp "$ROOT/shared/tests/fixtures/docreview/brief-sample.md" "$PAY"
printf -- '---\nx: 1\n---\n\n## 6. 사용자 원문\n\n- id: S2\n  source: verbatim\n  round: 1\n  text: "둘째 발화"\n\n## 7. 확산 원자료\n\n없음\n' > "$AUD"
fence_with "$RB_MD" build_brief_bundle.py > "$TR/rb-bundle.sh"
SDIR="$(state_dir_of "$PAY")"; BND="$SDIR/brief-bundle.md"
mkdir -p "$SDIR"; outside rb1; ln -s "$OUT/rb1" "$BND"
run_fence "$TR/rb-bundle.sh" PAYLOAD="$PAY" AUDIT="$AUD"; rc=$?
assert_eq "$rc" "0" "rb_bundle_fence_link: 번들 펜스 rc 0"
kept rb1 rb_bundle_fence_link
plain_one "$BND" "rb_bundle_fence_link"
assert_contains "$(cat "$BND" 2>/dev/null)" "둘째 발화" "rb_bundle_fence_link: 번들에 audit 원문이 실렸다(양의 짝)"
rm -f "$BND"; outside rb2; ln "$OUT/rb2" "$BND"
run_fence "$TR/rb-bundle.sh" PAYLOAD="$PAY" AUDIT="$AUD"; rc=$?
assert_eq "$rc" "0" "rb_bundle_fence_link(하드 링크): 번들 펜스 rc 0"
kept rb2 "rb_bundle_fence_link(하드 링크)"
plain_one "$BND" "rb_bundle_fence_link(하드 링크)"

# 쓰기 불가 상태 폴더 + 쓰기 가능한 직전 번들 — writer 가 실패하면 실패 갈래가 번들을 비우고 멈춘다
# (다른 payload 의 자리에서 — 위 하드 링크 자리는 아래 링크 수 검사가 본다)
PAY2="$R/docs/brief-ro.md"; cp "$PAY" "$PAY2"
SDIR2="$(state_dir_of "$PAY2")"; BND2="$SDIR2/brief-bundle.md"
mkdir -p "$SDIR2"; printf 'OLD bundle\n' > "$BND2"; chmod 555 "$SDIR2"
run_fence "$TR/rb-bundle.sh" PAYLOAD="$PAY2" AUDIT="$AUD"; rc=$?
chmod 755 "$SDIR2"
[ "$rc" != 0 ] && ok "rb_bundle_ro_dir_clears_stale: 펜스가 멈춘다(rc $rc)" || no "rb_bundle_ro_dir_clears_stale: rc 0 으로 지나갔다"
if grep -q OLD "$BND2" 2>/dev/null; then no "rb_bundle_ro_dir_clears_stale: 직전 번들의 OLD 가 남았다"; else ok "rb_bundle_ro_dir_clears_stale: 직전 번들에 OLD 가 없다"; fi
assert_contains "$(cat "$TR/last.err")" "번들 조립 실패(rc 73)" "rb_bundle_ro_dir_clears_stale: writer 실패(rc 73)가 실패 갈래로 갔다"

# RF 번들 펜스 — 변수를 앞에 대입해 돈다
RFS="$R/.claude/spec-distill/.docreview/rf-seed"; mkdir -p "$RFS"
SEEDF="$R/docs/rf-seed.md"; AUDF="$R/docs/rf-seed.audit.md"
printf -- '---\ntype: interview-seed\nnext_phase: spec-distill:pm-interview\naudit_file: rf-seed.audit.md\n---\n\nRF_SEED_BODY 로그인이 가끔 실패한다.\n' > "$SEEDF"
printf -- '---\ntype: interview-seed-audit\npayload: rf-seed.md\n---\n\n# T\n\n## 1. 원문\n\n사용자가 한 말.\n\n## 2. 질문 전체\n\n없음\n\n## 6. 리뷰 결정\n\n없음\n' > "$AUDF"
printf '# CLAUDE.md\n규칙.\n' > "$R/CLAUDE.md"
rf_vars() { printf 'SD="%s"\nSTATE_DIR="%s"\nBUNDLE="%s"\nBUNDLE_RC="%s"\nSEED_ABS="%s"\nAUDIT_ABS="%s"\nSEED_BASE="%s"\n' \
  "$SDROOT" "$RFS" "$RFS/bundle.md" "$RFS/bundle-recritic.md" "$SEEDF" "$AUDF" "$RFS/seed-base.md"; }
{ rf_vars; fence_with "$RF_MD" '--for recritic'; } > "$TR/rf-bundle.sh"
outside rf1; outside rf2; ln -s "$OUT/rf1" "$RFS/bundle.md"; ln "$OUT/rf2" "$RFS/bundle-recritic.md"
run_fence "$TR/rf-bundle.sh"; rc=$?
assert_eq "$rc" "0" "rf_bundle_fence_link: 번들 펜스 rc 0"
kept rf1 rf_bundle_fence_link; kept rf2 rf_bundle_fence_link
plain_one "$RFS/bundle.md" "rf_bundle_fence_link(탐지 번들)"
plain_one "$RFS/bundle-recritic.md" "rf_bundle_fence_link(재비판 번들)"
assert_contains "$(cat "$RFS/bundle.md" 2>/dev/null)" "RF_SEED_BODY" "rf_bundle_fence_link: 번들에 seed 본문이 실렸다(양의 짝)"

# RF hunks · gate-drops 자리
python3 "$SDROOT/scripts/seed_edit_diff.py" init "$RFS/seed-base.md" "$SEEDF" >/dev/null 2>&1
python3 "$ROOT/shared/docreview/scripts/docreview_state.py" init --state-dir "$RFS" --doc "$SEEDF" \
  --profile "$SDROOT/references/docreview-profiles/seed.md" >/dev/null 2>&1 \
  && ok "rf_hunks_and_drops_link: 엔진 원장을 만들었다" || no "rf_hunks_and_drops_link: 엔진 원장 init 실패"
{ rf_vars; fence_with "$RF_MD" '"$STATE_DIR/hunks.json"'; } > "$TR/rf-hunks.sh"
{ rf_vars; fence_with "$RF_MD" 'gate-drops.json'; } > "$TR/rf-drops.sh"
outside rf3; outside rf4; ln -s "$OUT/rf3" "$RFS/hunks.json"; ln -s "$OUT/rf4" "$RFS/gate-drops.json"
run_fence "$TR/rf-hunks.sh"; rc=$?
assert_eq "$rc" "0" "rf_hunks_and_drops_link: hunks 펜스 rc 0"
kept rf3 rf_hunks_and_drops_link
plain_one "$RFS/hunks.json" "rf_hunks_and_drops_link(hunks.json)"
assert_contains "$(cat "$RFS/hunks.json" 2>/dev/null)" '"hunks"' "rf_hunks_and_drops_link: hunks.json 에 덩어리 목록(양의 짝)"
run_fence "$TR/rf-drops.sh"
kept rf4 rf_hunks_and_drops_link
plain_one "$RFS/gate-drops.json" "rf_hunks_and_drops_link(gate-drops.json)"
assert_contains "$(cat "$RFS/gate-drops.json" 2>/dev/null)" '"round"' "rf_hunks_and_drops_link: gate-drops.json 에 엔진 요약(양의 짝)"

# RF 확정 직전 drop 검사 — 엔진 원장이 없는 자리에서 audit 으로 만든 gate-final.json
RFF="$R/.claude/spec-distill/.docreview/rf-final"; mkdir -p "$RFF"
{ rf_vars; printf 'STATE_DIR="%s"\n' "$RFF"; fence_with "$RF_MD" 'gate-final.json'; } > "$TR/rf-final.sh"
for kind in symlink hardlink; do
  rm -f "$RFF/gate-final.json"; outside "rf-final-$kind"
  if [ "$kind" = symlink ]; then ln -s "$OUT/rf-final-$kind" "$RFF/gate-final.json"; else ln "$OUT/rf-final-$kind" "$RFF/gate-final.json"; fi
  run_fence "$TR/rf-final.sh"
  [ ! -e "$RFF/docreview-state.md" ] && ok "rf_gate_final_link($kind): 엔진 원장이 없는 갈래(전제)" || no "rf_gate_final_link($kind): 엔진 원장이 생겼다 — audit 갈래를 재지 않는다"
  kept "rf-final-$kind" "rf_gate_final_link($kind)"
  plain_one "$RFF/gate-final.json" "rf_gate_final_link($kind)"
  assert_contains "$(cat "$RFF/gate-final.json" 2>/dev/null)" '"dropped"' "rf_gate_final_link($kind): gate-final.json 에 audit 으로 만든 dropped(양의 짝)"
done

# RB degrade 대체 파일 — 그 자리의 링크는 거절되고 기록은 임시 폴더의 파일로 간다
KPAY="$R/docs/ks-interview.md"; KST="$R/docs/ks-interview.state.md"
cp "$PAY" "$KPAY"; printf 'not a state file\n' > "$KST"; chmod 444 "$KST"
KDIR="$(state_dir_of "$KPAY")"; mkdir -p "$KDIR"
outside rb3; ln -s "$OUT/rb3" "$KDIR/brief-degrade-fallback.txt"
fence_with "$RB_MD" '--component "<a>"' \
  | sed -e 's/<a>/pipeline/g' -e 's/<b>/all/g' -e 's/<c>/skipped/g' -e 's/<r>/probe-ks-e2e/g' > "$TR/rb-ks.sh"
run_fence "$TR/rb-ks.sh" PAYLOAD="$KPAY" AUDIT="$AUD"
chmod 644 "$KST"
kept rb3 rb_degrade_fallback_link
assert_contains "$(cat "$TR/tmp/brief-degrade-fallback.sdwrites01.txt" 2>/dev/null)" "probe-ks-e2e" \
  "rb_degrade_fallback_link: 기록은 임시 폴더의 대체 파일에 닿았다(양의 짝)"

# 위 실행 뒤 상태 폴더 안 일반 파일의 링크 수는 모두 1 이다
nreg="$(find "$R/.claude" -type f | grep -c .)"
multi="$(find "$R/.claude" -type f -links +1)"
[ "$nreg" -ge 6 ] && ok "nlink_one_after_rounds: 상태 폴더의 일반 파일 ${nreg}개를 봤다" || no "nlink_one_after_rounds: 일반 파일이 ${nreg}개뿐이다 — 실행이 상태 폴더에 닿지 않았다"
assert_eq "$multi" "" "nlink_one_after_rounds: 링크 수 2 이상인 파일이 없다"

# RF 산출물 기록 — 「산출물 없음」 메모를 쓰지 못하면 지난 라운드의 메모를 audit 에 옮기지 않는다
RFA="$R/.claude/spec-distill/.docreview/rf-absent"; mkdir -p "$RFA"
AUDA="$R/docs/rf-absent.audit.md"
{ rf_vars; printf 'STATE_DIR="%s"\nAUDIT_ABS="%s"\n' "$RFA" "$AUDA"; fence_with "$RF_MD" 'record_artifact()'; } > "$TR/rf-absent.sh"
if grep -q 'absent-note.txt' "$TR/rf-absent.sh" && bash -n "$TR/rf-absent.sh" 2>/dev/null; then ok "추출: RF 산출물 기록 펜스(bash -n 통과)"
else no "추출: RF 산출물 기록 펜스가 비었거나 문법이 깨졌다 — 아래 판정은 무의미하다"; fi
for kind in writable readonly; do
  cp "$ROOT/plugins/spec-distill/tests/fixtures/seed-one-sentence.audit.md" "$AUDA"
  printf '(STALE_ABSENT_NOTE)\n' > "$RFA/absent-note.txt"
  [ "$kind" = readonly ] && chmod 555 "$RFA"
  run_fence "$TR/rf-absent.sh"
  chmod 755 "$RFA"
  aud="$(cat "$AUDA")"
  case "$aud" in *STALE_ABSENT_NOTE*) no "rf_absent_note($kind): 지난 메모가 audit 에 옮겨졌다" ;; *) ok "rf_absent_note($kind): 지난 메모가 audit 에 없다" ;; esac
  if [ "$kind" = writable ]; then
    assert_contains "$aud" '(이 라운드에 산출물 없음 — recritic.txt)' "rf_absent_note(writable): 새 메모가 audit 에 옮겨졌다(양의 짝)"
  else
    assert_contains "$(cat "$TR/last.err")" '「산출물 없음」 메모를 쓰지 못해 audit ## 4 에 옮기지 않았다: 재비판 (doc-recritic)' "rf_absent_note(readonly): 쓰지 못한 사실을 알린다"
  fi
done

# README 한계 문장 — Write 도구 파일은 writer 로 감싸지 못한다
assert_contains "$(cat "$ROOT/plugins/spec-distill/README.md")" 'Write 도구로 쓰는 상태 폴더 파일(`said-*.txt` · `readback.txt` · `note-<id>.txt` · `critic*.txt` · `recritic.txt`)은 writer 로 감싸지 못하고' "README: §3 한계 문장"

finish
