#!/usr/bin/env bash
# 링크를 따라가지 않는 공용 writer(nofollow_write.py)의 동작과 두 플러그인 링크를 잰다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

W="$ROOT/shared/docreview/scripts/nofollow_write.py"
T="$(mktemp -d)"
cleanup() { chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT

fresh() {   # fresh — 폴더와 레포 밖 대상을 새로 만든다
  chmod -R u+rwx "$T" 2>/dev/null
  rm -rf "$T/out" "$T/outside.txt" "$T/other"
  mkdir "$T/out"
  printf 'KEEP' > "$T/outside.txt"
  P="$T/out/b"
}
nw() { python3 "$W" "$@"; }
content() { cat "$1" 2>/dev/null; }
is_regular() { [ -f "$1" ] && [ ! -L "$1" ]; }
nlink() { python3 -c 'import os,sys; print(os.stat(sys.argv[1]).st_nlink)' "$1"; }

note "== run_symlink_replaced"
fresh; ln -s "$T/outside.txt" "$P"
nw run --out "$P" -- printf 'NEW' 2>/dev/null; rc=$?
assert_eq "$rc" "0" "run 링크: rc 0"
assert_eq "$(content "$T/outside.txt")" "KEEP" "run 링크: 레포 밖 대상 그대로"
is_regular "$P" && ok "run 링크: P 는 일반 파일" || no "run 링크: P 는 일반 파일"
assert_eq "$(content "$P")" "NEW" "run 링크: P 내용 NEW"

note "== run_hardlink_replaced"
fresh; ln "$T/outside.txt" "$P"
assert_eq "$(nlink "$P")" "2" "하드 링크 픽스처: 링크 수 2"
nw run --out "$P" -- printf 'NEW' 2>/dev/null; rc=$?
assert_eq "$rc" "0" "run 하드 링크: rc 0"
assert_eq "$(content "$T/outside.txt")" "KEEP" "run 하드 링크: 대상 그대로"
is_regular "$P" && ok "run 하드 링크: P 는 일반 파일" || no "run 하드 링크: P 는 일반 파일"
assert_eq "$(content "$P")" "NEW" "run 하드 링크: P 내용 NEW"
assert_eq "$(nlink "$P")" "1" "run 하드 링크: P 링크 수 1"

note "== run_passes_rc_and_keeps_stdout"
fresh
nw run --out "$P" -- sh -c 'printf X; exit 3' 2>/dev/null; rc=$?
assert_eq "$rc" "3" "run rc 3 그대로"
assert_eq "$(content "$P")" "X" "run rc 3: stdout 은 놓는다"
fresh
nw run --out "$P" -- sh -c 'printf X; exit 5' 2>/dev/null; rc=$?
assert_eq "$rc" "5" "run rc 5 그대로"
assert_eq "$(content "$P")" "X" "run rc 5: stdout 은 놓는다"

note "== run_missing_command_127"
fresh
nw run --out "$P" -- /nonexistent/cmd-zzz 2>/dev/null; rc=$?
assert_eq "$rc" "127" "없는 명령: rc 127"
is_regular "$P" && ok "없는 명령: P 는 일반 파일" || no "없는 명령: P 는 일반 파일"
assert_eq "$(wc -c < "$P" | tr -d ' ')" "0" "없는 명령: P 는 비어 있다"

note "== run_stdin_inherited"
fresh
printf 'in' | nw run --out "$P" -- cat 2>/dev/null; rc=$?
assert_eq "$rc" "0" "stdin 물려받기: rc 0"
assert_eq "$(content "$P")" "in" "stdin 물려받기: P 내용 in"

note "== run_self_failure_73"
fresh
nw run --out "$T/nodir/b" -- printf 'x' 2>"$T/err"; rc=$?
assert_eq "$rc" "73" "폴더 없음: rc 73"
assert_grep "$(head -n 1 "$T/err")" '^\[nofollow_write\] ' "폴더 없음: stderr 첫 줄 접두"
[ ! -e "$T/nodir/b" ] && ok "폴더 없음: P 없음" || no "폴더 없음: P 없음"
fresh; printf 'OLD' > "$P"; chmod 555 "$T/out"
nw run --out "$P" -- printf 'NEW' 2>"$T/err"; rc=$?
assert_eq "$rc" "73" "폴더 쓰기 불가: rc 73"
assert_eq "$(content "$P")" "OLD" "폴더 쓰기 불가: P 그대로"
assert_grep "$(head -n 1 "$T/err")" '^\[nofollow_write\] ' "폴더 쓰기 불가: stderr 접두"
chmod 755 "$T/out"

note "== bad_args_73"
fresh
nw 2>/dev/null; assert_eq "$?" "73" "모드 없음: rc 73"
nw run -- printf x 2>/dev/null; assert_eq "$?" "73" "--out 없음: rc 73"
nw run --out "$P" printf x 2>/dev/null; assert_eq "$?" "73" "run 에 -- 없음: rc 73"
nw empty 2>/dev/null; assert_eq "$?" "73" "empty --out 없음: rc 73"
nw bogus --out "$P" 2>/dev/null; assert_eq "$?" "73" "모르는 모드: rc 73"

note "== empty_symlink_and_hardlink"
fresh; ln -s "$T/outside.txt" "$P"
nw empty --out "$P" 2>/dev/null; rc=$?
assert_eq "$rc" "0" "empty 링크: rc 0"
is_regular "$P" && ok "empty 링크: P 일반 파일" || no "empty 링크: P 일반 파일"
assert_eq "$(wc -c < "$P" | tr -d ' ')" "0" "empty 링크: P 비어 있다"
assert_eq "$(content "$T/outside.txt")" "KEEP" "empty 링크: 대상 그대로"
fresh; ln "$T/outside.txt" "$P"
nw empty --out "$P" 2>/dev/null; rc=$?
assert_eq "$rc" "0" "empty 하드 링크: rc 0"
is_regular "$P" && ok "empty 하드 링크: P 일반 파일" || no "empty 하드 링크: P 일반 파일"
assert_eq "$(wc -c < "$P" | tr -d ' ')" "0" "empty 하드 링크: P 비어 있다"
assert_eq "$(content "$T/outside.txt")" "KEEP" "empty 하드 링크: 대상 그대로"

note "== empty_truncate_branch"
fresh; printf 'OLD' > "$P"; chmod 555 "$T/out"
nw empty --out "$P" 2>/dev/null; rc=$?
assert_eq "$rc" "0" "자르기 갈래: rc 0"
assert_eq "$(wc -c < "$P" | tr -d ' ')" "0" "자르기 갈래: P 크기 0"
chmod 755 "$T/out"
fresh; ln -s "$T/outside.txt" "$P"; chmod 555 "$T/out"
nw empty --out "$P" 2>/dev/null; rc=$?
assert_eq "$rc" "73" "자르기 갈래 링크: rc 73"
assert_eq "$(content "$T/outside.txt")" "KEEP" "자르기 갈래 링크: 대상 그대로"
chmod 755 "$T/out"
fresh; printf 'OLD' > "$T/outside.txt"; ln "$T/outside.txt" "$P"; chmod 555 "$T/out"
nw empty --out "$P" 2>/dev/null; rc=$?
assert_eq "$rc" "73" "자르기 갈래 하드 링크: rc 73"
assert_eq "$(content "$T/outside.txt")" "OLD" "자르기 갈래 하드 링크: 한 이름 OLD"
assert_eq "$(content "$P")" "OLD" "자르기 갈래 하드 링크: 다른 이름 OLD"
chmod 755 "$T/out"

note "== append_creates_and_appends"
fresh
printf 'a' | nw append --out "$P" 2>/dev/null; rc=$?
assert_eq "$rc" "0" "append 만들기: rc 0"
printf 'b' | nw append --out "$P" 2>/dev/null; rc=$?
assert_eq "$rc" "0" "append 덧붙이기: rc 0"
assert_eq "$(content "$P")" "ab" "append 내용 ab"
fresh
nw append --out "$P" </dev/null 2>/dev/null; rc=$?
assert_eq "$rc" "0" "빈 stdin: rc 0"
is_regular "$P" && ok "빈 stdin: 파일 생성" || no "빈 stdin: 파일 생성"
assert_eq "$(wc -c < "$P" | tr -d ' ')" "0" "빈 stdin: 빈 파일"

note "== append_refuses_links"
fresh; ln -s "$T/outside.txt" "$P"
printf 'z' | nw append --out "$P" 2>/dev/null; rc=$?
assert_eq "$rc" "73" "append 링크: rc 73"
assert_eq "$(content "$T/outside.txt")" "KEEP" "append 링크: 대상 그대로"
fresh; ln "$T/outside.txt" "$P"
printf 'z' | nw append --out "$P" 2>/dev/null; rc=$?
assert_eq "$rc" "73" "append 하드 링크: rc 73"
assert_eq "$(content "$T/outside.txt")" "KEEP" "append 하드 링크: 대상 그대로"

note "== run_signal_rc"
fresh
nw run --out "$P" -- sh -c 'kill -TERM $$' 2>/dev/null; rc=$?
assert_eq "$rc" "143" "명령이 TERM 으로 죽음: rc 143"

note "== no_temp_left"
tmp_left() { find "$T/out" -maxdepth 1 -name '.b.*.tmp' | grep -c .; }
fresh; mkdir "$P"
nw run --out "$P" -- printf 'x' 2>/dev/null; rc=$?
assert_eq "$rc" "73" "P 가 폴더: rc 73"
assert_eq "$(tmp_left)" "0" "P 가 폴더: run 실패 뒤 임시 파일 없음"
fresh; mkdir "$P"
nw empty --out "$P" 2>/dev/null; rc=$?
assert_eq "$rc" "73" "P 가 폴더: empty rc 73"
assert_eq "$(tmp_left)" "0" "P 가 폴더: empty 실패 뒤 임시 파일 없음"
fresh
nw run --out "$P" -- printf 'x' 2>/dev/null
assert_eq "$(tmp_left)" "0" "정상 run 뒤 임시 파일 없음"
nw run --out "$P" -- sh -c 'printf y; exit 4' 2>/dev/null
assert_eq "$(tmp_left)" "0" "명령 rc 4 run 뒤 임시 파일 없음"

note "== mode_matches_shell"
fresh
( umask 027
  nw run --out "$T/out/viaw" -- printf 'm' 2>/dev/null
  printf 'm' > "$T/out/viash" )
mw="$(python3 -c 'import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$T/out/viaw")"
ms="$(python3 -c 'import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$T/out/viash")"
assert_eq "$mw" "$ms" "run 이 만든 권한 = 셸 > 가 만든 권한"

note "== bash32_fence"
fresh; ln -s "$T/outside.txt" "$P"
out="$(/bin/bash -c 'python3 "$1" empty --out "$2" 2>/dev/null || echo fail' _ "$W" "$P")"
assert_eq "$out" "" "bash 3.2 펜스 empty 링크: fail 아님"
is_regular "$P" && ok "bash 3.2 펜스 empty: P 일반 파일" || no "bash 3.2 펜스 empty: P 일반 파일"
assert_eq "$(content "$T/outside.txt")" "KEEP" "bash 3.2 펜스 empty: 대상 그대로"
fresh; ln "$T/outside.txt" "$P"
out="$(printf 'q' | /bin/bash -c 'python3 "$1" append --out "$2" 2>/dev/null || echo fail' _ "$W" "$P")"
assert_eq "$out" "fail" "bash 3.2 펜스 append 하드 링크: 거부"
assert_eq "$(content "$T/outside.txt")" "KEEP" "bash 3.2 펜스 append: 대상 그대로"
fresh
/bin/bash -c 'python3 "$1" run --out "$2" -- printf R 2>/dev/null || echo fail' _ "$W" "$P" >/dev/null
assert_eq "$(content "$P")" "R" "bash 3.2 펜스 run: P 내용 R"

note "== links_derived"
carriers="$(git ls-files -s -- 'plugins/*/scripts/run_docreview_codex_reviewer.sh' | awk '{ sub(/^[^\t]*\t/, ""); print }' | awk -F/ '{ print $2 }')"
n=0
for p in $carriers; do
  n=$((n+1))
  L="plugins/$p/scripts/nofollow_write.py"
  mode="$(git ls-files -s -- "$L" | awk '{ print $1 }')"
  assert_eq "$mode" "120000" "$p: nofollow_write.py 는 인덱스에서 링크(120000)"
  if [ -L "$L" ]; then
    got="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$L")"
    want="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$W")"
    assert_eq "$got" "$want" "$p: 링크가 공용 writer 로 풀린다"
  else
    no "$p: 작업 트리에서 링크가 아니다"
  fi
done
[ "$n" -ge 2 ] && ok "공유 러너를 싣는 플러그인 $n 개(2 이상)" || no "공유 러너를 싣는 플러그인 수 $n (2 이상이어야 한다)"

# 공유 러너의 셸 쓰기를 모아 판정한다. 허용 대상은 /dev/null · fd 복제 · 러너 안에서
# "$SCRATCH/…" 로만 대입된 변수(SCRATCH 는 mktemp -d 로만 대입)뿐이다. 그 밖의 대상은 위반이다.
# write_failclosed · _degrade_if_empty 는 runner_common.sh(qg 러너와 나누는 사본 쌍)의 함수라
# 고치지 않고 이름으로 뺀다 — 러너의 writer empty 줄이 심어 둔 링크를 이미 일반 파일로 바꾼 뒤에만
# 불려야 하므로, 그 순서를 잰다.
#   python3 -I runner_lock.py check <러너>                → 위반 줄들 · rc 1, 없으면 rc 0
#   python3 -I runner_lock.py mutate <원본> <사본> <종류> [줄]  → 사본에 변이 하나(안 바뀌면 rc 2)
LOCK="$T/runner_lock.py"
cat > "$LOCK" <<'PY'
import os
import re
import sys

OP_RE = re.compile(r"&>>|&>|>>|>\||>&|<<<|<<-|<<|<>|<&|>|<|\|\||\|&|\||&&|;;|;|&|\(|\)")
WRITE_OPS = {">", ">>", ">|", "&>", "&>>", "<>"}
SEP_OPS = {";", ";;", "&&", "||", "|", "|&", "&", "(", ")"}
KEYWORDS = {"then", "do", "else", "elif", "if", "while", "until", "!", "{", "time"}
DECL = {"export", "local", "readonly", "declare", "typeset"}
EMPTY_NEEDLE = 'nofollow_write.py" empty --out "$OUTPUT_PATH"'
WRITER_CALL = 'python3 -I "$_RUNNER_DIR/nofollow_write.py"'
EXEMPT_FUNCS = re.compile(r"\b(write_failclosed|_degrade_if_empty)\b")


def skip_sq(s, i):
    j = s.find("'", i + 1)
    return len(s) if j < 0 else j + 1


def skip_dq(s, i, subs):
    j = i + 1
    while j < len(s):
        c = s[j]
        if c == "\\":
            j += 2
            continue
        if c == '"':
            return j + 1
        if s.startswith("$(", j):
            k = close_paren(s, j + 1)
            subs.append(s[j + 2:k - 1])
            j = k
            continue
        if c == "`":
            k = close_bt(s, j)
            subs.append(s[j + 1:k - 1])
            j = k
            continue
        j += 1
    return len(s)


def close_paren(s, i):
    depth = 0
    j = i
    while j < len(s):
        c = s[j]
        if c == "\\":
            j += 2
            continue
        if c == "'":
            j = skip_sq(s, j)
            continue
        if c == '"':
            j = skip_dq(s, j, [])
            continue
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return j + 1
        j += 1
    return len(s)


def close_bt(s, i):
    j = i + 1
    while j < len(s):
        if s[j] == "\\":
            j += 2
            continue
        if s[j] == "`":
            return j + 1
        j += 1
    return len(s)


def tokenize(s):
    """한 논리 줄 → (낱말·연산자 목록, 명령 치환 본문 목록, 주석 앞 코드)."""
    toks, subs = [], []
    raw, val, inword = "", "", False
    i, n = 0, len(s)
    code_end = n

    def flush():
        if inword:
            toks.append(("w", raw, val))

    while i < n:
        c = s[i]
        if c in " \t":
            flush()
            raw, val, inword = "", "", False
            i += 1
            continue
        if c == "#" and not inword:
            code_end = i
            break
        if c == "\\":
            raw += s[i:i + 2]
            val += s[i + 1:i + 2]
            inword = True
            i += 2
            continue
        if c == "'":
            j = skip_sq(s, i)
            raw += s[i:j]
            val += s[i + 1:j - 1]
            inword = True
            i = j
            continue
        if c == '"':
            j = skip_dq(s, i, subs)
            raw += s[i:j]
            val += s[i + 1:j - 1]
            inword = True
            i = j
            continue
        if s.startswith("$(", i):
            j = close_paren(s, i + 1)
            subs.append(s[i + 2:j - 1])
            raw += s[i:j]
            val += s[i:j]
            inword = True
            i = j
            continue
        if c == "`":
            j = close_bt(s, i)
            subs.append(s[i + 1:j - 1])
            raw += s[i:j]
            val += s[i:j]
            inword = True
            i = j
            continue
        m = OP_RE.match(s, i)
        if m:
            op = m.group(0)
            if op[0] in "<>" and inword and raw.isdigit():
                op = raw + op
            else:
                flush()
            raw, val, inword = "", "", False
            toks.append(("op", op))
            i = m.end()
            continue
        raw += c
        val += c
        inword = True
        i += 1
    flush()
    return toks, subs, s[:code_end]


def logical_lines(text):
    """(줄 번호, 논리 줄) — 줄 끝 \\ 는 잇고, heredoc 본문은 건너뛴다(따옴표 없는 heredoc 은 표시)."""
    out, pending = [], []
    lines = text.split("\n")
    i = 0
    while i < len(lines):
        if pending:
            term, strip = pending[0]
            cand = lines[i].lstrip("\t") if strip else lines[i]
            if cand == term:
                pending.pop(0)
            i += 1
            continue
        start, buf = i + 1, lines[i]
        while buf.endswith("\\") and not buf.lstrip().startswith("#") and i + 1 < len(lines):
            i += 1
            buf = buf[:-1] + " " + lines[i]
        i += 1
        toks, _subs, _code = tokenize(buf)
        for k, t in enumerate(toks):
            if t[0] == "op" and t[1] in ("<<", "<<-"):
                nxt = toks[k + 1] if k + 1 < len(toks) else None
                if nxt and nxt[0] == "w":
                    quoted = any(q in nxt[1] for q in "'\"\\")
                    pending.append((nxt[2], t[1] == "<<-"))
                    if not quoted:
                        out.append((start, None))
        out.append((start, buf))
    return out


def scan(lineno, s, acc):
    toks, subs, code = tokenize(s)
    acc["code"].append((lineno, code))
    cmdstart, decl = True, False
    for k, t in enumerate(toks):
        nxt = toks[k + 1] if k + 1 < len(toks) else None
        if t[0] == "op":
            op = t[1].lstrip("0123456789")
            if op in WRITE_OPS:
                acc["writes"].append((lineno, t[1], nxt[2] if nxt and nxt[0] == "w" else None))
            elif op == ">&":
                tgt = nxt[2] if nxt and nxt[0] == "w" else None
                if tgt is None or not re.fullmatch(r"\d+-?|-", tgt):
                    acc["writes"].append((lineno, t[1], tgt))
            if t[1] in SEP_OPS:
                cmdstart, decl = True, False
            continue
        word = t[2]
        prev = toks[k - 1] if k else None
        if prev and prev[0] == "op" and prev[1].lstrip("0123456789") in (WRITE_OPS | {">&", "<", "<&", "<<", "<<-", "<<<"}):
            continue
        if os.path.basename(word) in ("tee", "touch"):
            for u in toks[k + 1:]:
                if u[0] == "op":
                    break
                if not u[2].startswith("-"):
                    acc["writes"].append((lineno, os.path.basename(word), u[2]))
        m = re.match(r"([A-Za-z_][A-Za-z0-9_]*)\+?=", t[1])
        if m and (cmdstart or decl):
            acc["assign"].setdefault(m.group(1), []).append(t[1][m.end():])
            continue
        if decl and word.startswith("-"):
            continue
        if cmdstart and word in KEYWORDS:
            continue
        if cmdstart and word in DECL:
            decl, cmdstart = True, False
            continue
        if cmdstart and word == "for" and nxt and nxt[0] == "w":
            acc["assign"].setdefault(nxt[2], []).append(None)
        if cmdstart and word in ("read", "mapfile", "readarray"):
            for u in toks[k + 1:]:
                if u[0] == "op":
                    break
                if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", u[2]):
                    acc["assign"].setdefault(u[2], []).append(None)
        if cmdstart and word == "printf" and nxt and nxt[0] == "w" and nxt[2] == "-v":
            after = toks[k + 2] if k + 2 < len(toks) else None
            if after and after[0] == "w":
                acc["assign"].setdefault(after[2], []).append(None)
        cmdstart, decl = False, False
    for sub in subs:
        scan(lineno, sub, acc)


def check(path):
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    acc = {"writes": [], "assign": {}, "code": []}
    bad = []
    for lineno, s in logical_lines(text):
        if s is None:
            bad.append("L%d: 따옴표 없는 heredoc — 본문을 읽지 않는다" % lineno)
            continue
        scan(lineno, s, acc)
    sc = acc["assign"].get("SCRATCH", [])
    scratch_ok = bool(sc) and all(v is not None and re.match(r'"?\$\(mktemp -d\b', v) for v in sc)
    scratch_vars = set()
    if scratch_ok:
        for name, vals in acc["assign"].items():
            if name != "SCRATCH" and all(
                    v is not None and re.match(r'"?\$(SCRATCH|\{SCRATCH\})/', v) for v in vals):
                scratch_vars.add(name)
    for lineno, op, tgt in acc["writes"]:
        if tgt == "/dev/null":
            continue
        m = re.fullmatch(r"\$([A-Za-z_][A-Za-z0-9_]*)|\$\{([A-Za-z_][A-Za-z0-9_]*)\}", tgt or "")
        if m and (m.group(1) or m.group(2)) in scratch_vars:
            continue
        what = "$OUTPUT_PATH 맨 넘기기" if tgt and "OUTPUT_PATH" in tgt else "허용 밖 대상"
        bad.append("L%d: %s — %s %s" % (lineno, what, op, tgt))
    empties = [ln for ln, c in acc["code"] if EMPTY_NEEDLE in c]
    traps = [ln for ln, c in acc["code"] if re.match(r"\s*trap\s", c) and re.search(r"\bEXIT\s*$", c.rstrip())]
    if len(empties) != 1:
        bad.append("writer empty 줄이 %d 개(1 개여야 한다)" % len(empties))
    elif not traps:
        bad.append("종료 trap 줄이 없다")
    else:
        e = empties[0]
        if e >= min(traps):
            bad.append("L%d: writer empty 줄이 종료 trap(L%d) 뒤다" % (e, min(traps)))
        for ln, c in acc["code"]:
            if EXEMPT_FUNCS.search(c) and ln <= e:
                bad.append("L%d: write_failclosed · _degrade_if_empty 가 writer empty 줄(L%d) 앞에서 불린다" % (ln, e))
    for ln, c in acc["code"]:
        if "nofollow_write.py" in c and WRITER_CALL not in c:
            bad.append("L%d: writer 를 python3 -I \"$_RUNNER_DIR/…\" 꼴로 부르지 않는다" % ln)
    rd = acc["assign"].get("_RUNNER_DIR", [])
    if not rd or any(v is None or "pwd -P" not in v for v in rd):
        bad.append("_RUNNER_DIR 가 절대 경로(pwd -P)로만 대입되지 않는다")
    for b in bad:
        print(b)
    print("scratch=" + ",".join(sorted(scratch_vars)))
    print("writes=%d" % len(acc["writes"]))
    return 1 if bad else 0


def mutate(src, dst, kind, line=""):
    with open(src, encoding="utf-8") as fh:
        text = fh.read()
    lines = text.split("\n")
    new = list(lines)
    idx = [i for i, ln in enumerate(lines) if EMPTY_NEEDLE in ln]
    if kind == "revive_truncate" and len(idx) == 1:
        new[idx[0]] = new[idx[0]].replace(
            WRITER_CALL + ' empty --out "$OUTPUT_PATH"', ': > "$OUTPUT_PATH"')
    elif kind == "move_empty_after_trap" and len(idx) == 1:
        end = next((j for j in range(idx[0], len(lines)) if lines[j] == "}"), None)
        trap = next((j for j, ln in enumerate(lines) if ln.startswith("trap ")), None)
        if end is not None and trap is not None:
            block = lines[idx[0]:end + 1]
            rest = lines[:idx[0]] + lines[end + 1:]
            t = rest.index(lines[trap])
            new = rest[:t + 1] + block + rest[t + 1:]
    elif kind == "after_anchor":
        hits = [i for i, ln in enumerate(lines) if ln == 'OVERRIDE_REASON=""']
        if len(hits) == 1:
            new.insert(hits[0] + 1, line)
    elif kind == "before_empty" and len(idx) == 1:
        new.insert(idx[0], line)
    out = "\n".join(new)
    if kind == "sub_first" and "@@" in line:
        old, rep = line.split("@@", 1)
        out = text.replace(old, rep, 1)
    if out == text:
        sys.stderr.write("변이가 적용되지 않았다: %s\n" % kind)
        return 2
    with open(dst, "w", encoding="utf-8") as fh:
        fh.write(out)
    return 0


if __name__ == "__main__":
    if sys.argv[1] == "check":
        sys.exit(check(sys.argv[2]))
    sys.exit(mutate(*sys.argv[2:]))
PY

RUNNER="$ROOT/shared/docreview/scripts/run_docreview_codex_reviewer.sh"
lock() { python3 -I "$LOCK" check "$1"; }

note "== runner_targeted_lock"
out="$(lock "$RUNNER")"; rc=$?
assert_eq "$rc" "0" "공유 러너: 허용 밖 쓰기 없음 · writer empty 줄이 trap 과 두 함수보다 앞"
[ "$rc" = 0 ] || printf '%s\n' "$out" | sed 's/^/      /'
assert_grep "$out" '^scratch=(.*,)?PROMPT_FILE(,|$)' "도출: PROMPT_FILE 은 \$SCRATCH 변수"
assert_grep "$out" '^scratch=(.*,)?STDOUT_FILE(,|$)' "도출: STDOUT_FILE 은 \$SCRATCH 변수"
w="$(printf '%s\n' "$out" | sed -n 's/^writes=//p')"
[ "${w:-0}" -ge 3 ] && ok "도출: 쓰기 자리 ${w}개를 봤다(공허하지 않다)" || no "도출: 쓰기 자리 ${w:-0}개 — 러너를 못 읽었다"
assert_grep "$(grep -c 'nofollow_write.py" run --out "$OUTPUT_PATH"' "$RUNNER")" '^[1-9]' "공유 러너: writer run 으로 \$OUTPUT_PATH 를 쓴다"

# 사본 변이: <이름>~<종류>~<넣을 줄>~<기대 rc>~<위반 출력에 있어야 할 말>
M="$T/runner-mut.sh"
while IFS='~' read -r name kind line want needle; do
  [ -n "$name" ] || continue
  if python3 -I "$LOCK" mutate "$RUNNER" "$M" "$kind" "$line"; then
    mo="$(lock "$M")"; mrc=$?
    assert_eq "$mrc" "$want" "변이 $name: rc $want"
    [ -z "$needle" ] || assert_contains "$mo" "$needle" "변이 $name: 사유 「${needle}」"
  else
    no "변이 $name: 사본에 적용되지 않았다"
  fi
done <<'EOF_MUT'
truncate-revived~revive_truncate~~1~$OUTPUT_PATH 맨 넘기기
append-added~after_anchor~echo x >> "$OUTPUT_PATH"~1~$OUTPUT_PATH 맨 넘기기
tee-braced~after_anchor~printf x | tee "${OUTPUT_PATH}" >/dev/null~1~$OUTPUT_PATH 맨 넘기기
tmp-target~after_anchor~echo x > /tmp/x~1~허용 밖 대상
clobber~after_anchor~printf x >| "$OUTPUT_PATH"~1~$OUTPUT_PATH 맨 넘기기
amp-redirect~after_anchor~printf x &> "$OUTPUT_PATH"~1~$OUTPUT_PATH 맨 넘기기
fd-redirect~after_anchor~printf x 2>"$OUTPUT_PATH"~1~$OUTPUT_PATH 맨 넘기기
exec-redirect~after_anchor~exec > "$OUTPUT_PATH"~1~$OUTPUT_PATH 맨 넘기기
group-redirect~after_anchor~{ echo a; echo b; } > "$OUTPUT_PATH"~1~$OUTPUT_PATH 맨 넘기기
touch-out~after_anchor~touch "$OUTPUT_PATH"~1~$OUTPUT_PATH 맨 넘기기
cmdsub-in-quotes~after_anchor~x="$(echo y > "$OUTPUT_PATH")"~1~$OUTPUT_PATH 맨 넘기기
dup-to-file~after_anchor~printf x >&"$OUTPUT_PATH"~1~$OUTPUT_PATH 맨 넘기기
var-alias~after_anchor~O="$OUTPUT_PATH"; printf x > "$O"~1~허용 밖 대상
prompt-reassigned~after_anchor~PROMPT_FILE="$OUTPUT_PATH"~1~허용 밖 대상
scratch-reassigned~after_anchor~SCRATCH="$PWD"~1~허용 밖 대상
unquoted-heredoc~after_anchor~cat <<EOF2~1~따옴표 없는 heredoc
empty-after-trap~move_empty_after_trap~~1~종료 trap
failclosed-first~before_empty~write_failclosed "$OUTPUT_PATH" early~1~앞에서 불린다
writer-not-isolated~sub_first~python3 -I "$_RUNNER_DIR/nofollow_write.py" run@@python3 "$_RUNNER_DIR/nofollow_write.py" run~1~python3 -I
runner-dir-relative~sub_first~_RUNNER_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"@@_RUNNER_DIR="$(dirname -- "${BASH_SOURCE[0]}")"~1~pwd -P
prompt-write~after_anchor~echo x > "$PROMPT_FILE"~0~
devnull-and-dup~after_anchor~echo x >/dev/null 2>&1; echo y >&2~0~
EOF_MUT

note "== runner_e2e_symlink"
STUB="$T/stubbin"; mkdir -p "$STUB"
ln -s "$ROOT/shared/tests/fixtures/docreview/codex-stub.sh" "$STUB/codex"
PROF="$ROOT/plugins/spec-distill/references/docreview-profiles/design-doc.md"
DOCF="$ROOT/shared/tests/fixtures/docreview/design-sample.md"
plant() {   # plant <symlink|hardlink> — P 자리에 레포 밖 파일로 가는 링크를 심는다
  fresh
  if [ "$1" = symlink ]; then ln -s "$T/outside.txt" "$P"; else ln "$T/outside.txt" "$P"; fi
}
run_runner() {   # run_runner <러너> <플러그인 루트> <프로필>
  PATH="$STUB:$PATH" CLAUDE_PLUGIN_ROOT="$2" bash "$1" "$3" "$DOCF" "$ROOT" "$P" 2>/dev/null
}
after_run() {    # after_run <rc> <기대 rc> <P 에 있어야 할 줄> <라벨>
  assert_eq "$1" "$2" "$4: rc $2"
  assert_eq "$(content "$T/outside.txt")" "KEEP" "$4: 레포 밖 파일 그대로"
  is_regular "$P" && ok "$4: P 는 일반 파일" || no "$4: P 는 일반 파일"
  [ -f "$P" ] && assert_eq "$(nlink "$P")" "1" "$4: P 링크 수 1"
  assert_grep "$(content "$P")" "$3" "$4: P 는 YAML($3)"
}
for host in spec-distill quality-gates; do
  R="$ROOT/plugins/$host/scripts/run_docreview_codex_reviewer.sh"
  for kind in symlink hardlink; do
    plant "$kind"; run_runner "$R" "$ROOT/plugins/$host" "$PROF"; rc=$?
    after_run "$rc" 0 '^  codex_failed: false$' "$host $kind 정상"
    plant "$kind"; run_runner "$R" "$ROOT/plugins/$host" "$T/no-profile.md"; rc=$?
    after_run "$rc" 0 '^  reason: profile_missing$' "$host $kind profile_missing"
  done
done
for kind in symlink hardlink; do
  plant "$kind"; run_runner "$RUNNER" "$ROOT/plugins/spec-distill" "$PROF"; rc=$?
  after_run "$rc" 0 '^  reason: runner_common_unloadable$' "정본 자리 $kind runner_common_unloadable"
done
FAKE="$T/fakeroot"; mkdir -p "$FAKE/scripts"
ln -s "$ROOT/shared/codex/prompt-preamble.md" "$FAKE/scripts/prompt-preamble.md"
printf 'import sys\nsys.stdout.write("partial")\nsys.exit(1)\n' > "$FAKE/scripts/codex_findings_to_yaml.py"
for kind in symlink hardlink; do
  plant "$kind"; run_runner "$ROOT/plugins/spec-distill/scripts/run_docreview_codex_reviewer.sh" "$FAKE" "$PROF"; rc=$?
  after_run "$rc" 0 '^  reason: yaml_conversion_failed$' "변환 실패 $kind"
  assert_eq "$(content "$P")" "$(printf 'findings: []\nmeta:\n  codex_failed: true\n  reason: yaml_conversion_failed')" "변환 실패 $kind: 대체 YAML 전부"
done
fresh; chmod 555 "$T/out"
PATH="$STUB:$PATH" CLAUDE_PLUGIN_ROOT="$ROOT/plugins/spec-distill" \
  bash "$ROOT/plugins/spec-distill/scripts/run_docreview_codex_reviewer.sh" "$PROF" "$DOCF" "$ROOT" "$P" 2>"$T/err"; rc=$?
assert_eq "$rc" "3" "산출물 폴더 쓰기 불가 · P 없음: rc 3"
assert_contains "$(cat "$T/err")" "산출물 경로에 쓸 수 없다" "산출물 폴더 쓰기 불가: 사유 한 줄"
chmod 755 "$T/out"

note "== runner_relative_path_planted"
# 러너를 상대 경로로 부르고, 러너가 cd 하는 리뷰 대상 폴더의 같은 상대 자리에 nofollow_write.py 를 심는다.
PROJ="$T/proj"; MARK="$T/planted-ran"
plant_writer() {   # plant_writer <PROJ 안 상대 폴더>
  mkdir -p "$PROJ/$1"
  printf 'import os\nopen(os.environ["PLANT_MARK"], "a").write("ran\\n")\n' > "$PROJ/$1/nofollow_write.py"
}
rel_run() {        # rel_run <cwd> <상대 러너 경로>
  ( cd "$1" && PLANT_MARK="$MARK" PATH="$STUB:$PATH" CLAUDE_PLUGIN_ROOT="$ROOT/plugins/spec-distill" \
      bash "$2" "$PROF" "$DOCF" "$PROJ" "$P" 2>/dev/null )
}
rm -rf "$PROJ"; rm -f "$MARK"; fresh
plant_writer plugins/spec-distill/scripts
rel_run "$ROOT" plugins/spec-distill/scripts/run_docreview_codex_reviewer.sh; rc=$?
assert_eq "$rc" "0" "상대 경로 러너: rc 0"
[ ! -e "$MARK" ] && ok "상대 경로 러너: 리뷰 대상 폴더에 심은 nofollow_write.py 를 실행하지 않는다" \
  || no "상대 경로 러너: 리뷰 대상 폴더에 심은 nofollow_write.py 를 실행했다"
assert_grep "$(content "$P")" '^  codex_failed: false$' "상대 경로 러너: P 는 YAML"
# 양성 대조 — 러너 폴더를 굳히지 않은 사본은 심은 파일을 실행한다(이 단언이 공허하지 않다는 증거).
HOST="$T/host/scripts"; mkdir -p "$HOST"
ln -s "$ROOT/plugins/spec-distill/scripts/runner_common.sh" "$HOST/runner_common.sh"
ln -s "$W" "$HOST/nofollow_write.py"
python3 -I -c '
import sys
src, dst = sys.argv[1:3]
t = open(src, encoding="utf-8").read()
old = "_RUNNER_DIR=\"$(CDPATH= cd -- \"$(dirname -- \"${BASH_SOURCE[0]}\")\" && pwd -P)\""
new = "_RUNNER_DIR=\"$(dirname -- \"${BASH_SOURCE[0]}\")\""
if t.count(old) != 1:
    sys.exit(2)
open(dst, "w", encoding="utf-8").write(t.replace(old, new))
' "$RUNNER" "$HOST/run.sh"; mrc=$?
assert_eq "$mrc" "0" "양성 대조: 옛 _RUNNER_DIR 줄로 사본을 만들었다"
rm -rf "$PROJ"; rm -f "$MARK"; fresh
plant_writer host/scripts
rel_run "$T" host/scripts/run.sh
[ -e "$MARK" ] && ok "양성 대조: 옛 _RUNNER_DIR 사본은 심은 파일을 실행한다" \
  || no "양성 대조: 옛 _RUNNER_DIR 사본도 심은 파일을 실행하지 않았다 — 위 단언이 공허하다"

finish
