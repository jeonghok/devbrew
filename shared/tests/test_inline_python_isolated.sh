#!/usr/bin/env bash
# 인라인 python 호출은 `-I` 로 격리한다 — 리포 전체 락.
#
# `python3 -c` · `-m` · `-` · heredoc · 파이프로 부르면 현재 디렉토리가 sys.path 맨 앞이라, 플러그인이
# 리뷰 · 감사 대상 리포 안에서 돌 때 그 리포의 json.py · uuid.py 가 표준 모듈 대신 실행된다.
# 두 겹으로 잰다.
#   정적 — 추적되는 플러그인 · shared · tools 파일의 인라인 호출 전부에 -I 가 있다(예외는 사유와 함께).
#   행동 — 표준 모듈 이름의 파일을 심은 리포에서 진입 스크립트를 돌려도 그 파일이 실행되지 않는다.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=assert.sh
. "$ROOT/shared/tests/assert.sh"
# 스캐너는 이 테스트 안에 산다 — tests/ 아래에 테스트 아닌 파일을 두면 qg 차등 테스트가 그것을 맡을
# 러너가 없는 후보로 세어 판정을 막는다(silent-drop).
SCAN_DIR="$(mktemp -d)"; SCAN="$SCAN_DIR/inline_python_scan.py"
trap 'rm -rf "$SCAN_DIR"' EXIT
cat > "$SCAN" <<'QG_SCAN_PY'
#!/usr/bin/env python3
"""인라인 python 호출 스캐너 — test_inline_python_isolated.sh 가 쓴다.

python 을 `-c` · `-m` · `-`(stdin) 로 부르거나 스크립트 인자 없이(heredoc · 파이프) 부르면
현재 디렉토리가 sys.path 맨 앞에 온다. 플러그인 스크립트와 skill 펜스는 리뷰 · 감사 대상 리포를
현재 디렉토리로 두고 도는 일이 많아서, 그 리포의 json.py · uuid.py 가 표준 모듈 대신 실행된다.
`-I` 가 그것을 막는다. 스크립트 파일 경로로 부르는 호출은 그 파일의 디렉토리가 맨 앞이라 대상이 아니다.

  scan <path>...      줄마다 `<path>:<line>\t<isolated|bare>\t<줄>` — 인라인 호출만 낸다
  classify            stdin 의 줄마다 `inline-isolated` · `inline-bare` · `script` · `none` 하나
"""
import re
import sys

# 명령 자리의 python 토큰. 경로 접두(/usr/bin/python3 · .venv/bin/python)도 잡는다.
# 앞 글자가 단어 · `$` · `-` 면 다른 단어의 일부다(PYTHONPATH · run_python3 · $python3).
# 뒤에는 공백만이 아니라 셸 연산자 · 따옴표가 붙어 올 수 있다(`python3<<'PY'` · `| python3)` · `"… | python3"`).
# 앞 글자가 `/` 면 변수로 시작하는 경로의 끝이다(`"$_dir/python3"`) — 그 꼴은 스캐너가 보지 못한다.
TOKEN = re.compile(r"(?<![\w$/-])((?:[\w.~-]*/)*python3?(?:\.\d+)?)(?=[\s<>|;&)`\"']|$)")
# 앞에 이것이 오면 호출이 아니라 존재 확인 · 값이다: `command -v python3` · 배열 대입 `X=(… python)` ·
# `$(python3` · ` (python3` · `then(python3` 는 호출이다 — 배열 안이어도 `$(` · 백틱 뒤면 명령 치환이라
# 호출로 본다(`arr=( $(python3 -c …) )`). 문장 속 글자(`name(python)`)는 예외 목록이 사유와 함께 다룬다.
PROBE = re.compile(r"(command\s+-v|which|type|hash)\s+$|=\([^)$`]*$")
# 셸 연산자 · 리다이렉트로 시작하는 토큰 — 여기까지 위치 인자가 없었으면 스크립트를 stdin 으로 받는다.
STOP = re.compile(r"^(\||&&|\|\||;|\)|<|>|\d>|&>|`|$)")


def read_flags(tok):
    """`-` 로 시작하는 옵션 묶음을 python 처럼 한 글자씩 읽는다 → (isolated, inline, eats_next).

    `I` 는 격리. `c` · `m` 을 만나면 인라인이고 남은 글자는 그 인자다(`-c'…'` · `-mjson.tool` · `-cI`).
    `W` · `X` 는 남은 글자가 인자이고, 남은 글자가 없으면 다음 토큰이 인자다."""
    isolated = False
    for k, ch in enumerate(tok[1:], start=1):
        if ch == "I":
            isolated = True
        elif ch in "cm":
            return isolated, True, False
        elif ch in "WXQ":
            return isolated, False, k == len(tok) - 1
    return isolated, False, False


def classify_one(line, m):
    """TOKEN 일치 하나 → (kind, isolated). kind: inline · script."""
    before = line[m.start() - 1] if m.start() > 0 else ""
    after = line[m.end()] if m.end() < len(line) else ""
    rest_start = m.end()
    if after in "\"'":
        if before == after:
            rest_start += 1   # `"python3" -c …` — 따옴표로 감싼 인터프리터 이름. 닫는 따옴표 뒤를 읽는다
        else:
            return ("inline", False)   # `bash -c "… | python3"` — 인용된 명령 문자열이 여기서 끝난다
    rest = line[rest_start:].split()
    isolated = False
    i = 0
    while i < len(rest):
        tok = rest[i]
        if STOP.match(tok) or tok == "-":
            return ("inline", isolated)
        if tok.startswith("--"):
            i += 1
            continue
        if tok.startswith("-") and len(tok) > 1:
            iso, inline, eats_next = read_flags(tok)
            isolated = isolated or iso
            if inline:
                return ("inline", isolated)
            i += 2 if eats_next else 1
            continue
        return ("script", False)
    return ("inline", isolated)   # 줄 끝까지 위치 인자가 없다 — 다음 줄(heredoc)이나 stdin 에서 받는다


def classify(line):
    """한 줄 → (kind, isolated). kind: inline · script · none. 인라인 호출이 여럿이면 하나라도 격리되지 않았으면 bare."""
    best = ("none", False)
    inline_seen, all_isolated = False, True
    for m in TOKEN.finditer(line):
        if PROBE.search(line[: m.start()]):
            continue
        kind, isolated = classify_one(line, m)
        if kind == "inline":
            inline_seen = True
            all_isolated = all_isolated and isolated
        elif best[0] == "none":
            best = ("script", False)
    if inline_seen:
        return ("inline", all_isolated)
    return best


def is_comment(line, markdown=False):
    """건너뛸 줄. 마크다운은 `#` 줄도 본다 — skill 펜스 안 주석은 모델이 지시로 읽는다."""
    s = line.lstrip()
    if s.startswith("```"):   # 마크다운 펜스 머리줄(```python)
        return True
    return s.startswith("#") and not markdown


def strip_trailing_comment(line):
    """따옴표 밖에서 공백 뒤에 오는 `#` 부터 줄 끝까지를 뗀다(`set +B  # … python3 -c …`)."""
    quote = None
    for i, ch in enumerate(line):
        if quote:
            if ch == quote:
                quote = None
        elif ch in "'\"":
            quote = ch
        elif ch == "#" and i > 0 and line[i - 1] in " \t":
            return line[:i]
    return line


def joined(rows):
    """`\` 로 끝나는 줄을 다음 줄과 이어 붙인다 — (시작 줄 번호, 이은 줄)."""
    out, buf, start = [], "", None
    for n, row in enumerate(rows, start=1):
        if start is None:
            start = n
        if row.endswith("\\"):
            buf += row[:-1] + " "
            continue
        out.append((start, buf + row))
        buf, start = "", None
    if start is not None:
        out.append((start, buf))
    return out


def scan(paths):
    for path in paths:
        try:
            with open(path, encoding="utf-8") as fh:
                rows = fh.read().split("\n")
        except (OSError, UnicodeDecodeError) as exc:
            print(f"{path}:0\tunreadable\t{exc}")   # 읽지 못한 파일은 건너뛰지 않고 알린다
            continue
        markdown = path.endswith(".md")
        for n, row in joined(rows):
            if is_comment(row, markdown):
                continue
            kind, isolated = classify(row if markdown else strip_trailing_comment(row))
            if kind == "inline":
                state = "isolated" if isolated else "bare"
                print(f"{path}:{n}\t{state}\t{row.strip()}")


def main():
    if len(sys.argv) >= 2 and sys.argv[1] == "scan":
        scan(sys.argv[2:])
        return 0
    if len(sys.argv) == 2 and sys.argv[1] == "classify":
        for row in sys.stdin.read().split("\n"):
            if not row:
                continue
            if is_comment(row):
                print("none")
                continue
            kind, isolated = classify(strip_trailing_comment(row))
            if kind == "inline":
                print("inline-isolated" if isolated else "inline-bare")
            else:
                print(kind)
        return 0
    print("usage: inline_python_scan.py scan <path>... | classify", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
QG_SCAN_PY

# 일부러 리포 코드를 돌리는 자리 — 경로 · 줄에 들어 있는 글자 · 사유. 줄이 사라지면 그 예외도 지운다.
EXEMPT_PATHS=(
  "plugins/quality-gates/scripts/run-test-selection.sh"
  "plugins/plugin-audit/scripts/run-own-tests.sh"
  "plugins/plugin-audit/scripts/run-own-tests.sh"
)
EXEMPT_NEEDLES=(
  "python3 -m venv .venv"
  "python3 -m unittest discover"
  'add_why "$cand(python): 러너 비정상 종료'
)
EXEMPT_REASONS=(
  "차등 테스트의 venv setup 명령 — 리뷰 대상 리포의 setup 을 일부러 돌린다(R22 kill switch 가 막는다)"
  "감사 대상 플러그인의 자체 테스트를 샌드박스에서 일부러 돌린다(README 의 알려진 한계)"
  "호출이 아니라 실패 사유 문자열 안의 글자다"
)

note "[분류기 — 꼴마다 하나]"
check() {  # check <줄> <기대>
  local got
  got="$(printf '%s\n' "$1" | python3 -I -X utf8 "$SCAN" classify)"
  assert_eq "$got" "$2" "분류: $1"
}
check "x=\$(python3 -c 'import json')" inline-bare
check "python3 -I -c 'import json'" inline-isolated
check "python3 -Ic 'import json'" inline-isolated
check "python3 -B -c 'import json'" inline-bare
check "python3 -m unittest discover" inline-bare
check "python3 -I -m json.tool" inline-isolated
check "GIT_OPTIONAL_LOCKS=0 python3 - \"\$out\" <<'PY'" inline-bare
check "python3 -I - \"\$out\" <<'PY'" inline-isolated
check "printf x | python3 -c 'import sys'" inline-bare
check "cat f | python3" inline-bare
check "python3 <<'EOF'" inline-bare
check "python3 >out.txt" inline-bare
check "/usr/bin/python3 -c 'pass'" inline-bare
check ".venv/bin/python -m pip install -q" inline-bare
check "python -c 'pass'" inline-bare
check "python3.11 -c 'pass'" inline-bare
check "python3 -W ignore -c 'pass'" inline-bare
check "python3 \"\$QG/scripts/verdict.py\" --line" script
check "python3 -I \"\$QG/scripts/verdict.py\"" script
check "python3 -B foo.py -c" script
check "command -v python3 >/dev/null" none
check "echo \"python3 가 없어 건너뛴다\"" script
check "export PYTHONPATH=x" none
check "run_python3 -c x" none
check "a=\$(python3 -I -c 'x') b=\$(python3 -c 'y')" inline-bare
check "python3 \"\$X/a.py\" | python3 -c 'y'" inline-bare
check "python3 -I -c 'x' | python3 -I - <<'PY'" inline-isolated
# 붙여 쓴 꼴 — 연산자 · 따옴표가 토큰 바로 뒤에 오거나 옵션에 인자가 붙는다
check "python3<<'PY'" inline-bare
check "x=\$(cat f | python3)" inline-bare
check "cat f | python3; echo" inline-bare
check "bash -c \"cat f | python3\"" inline-bare
check "\$(python3<f)" inline-bare
check "python3 -c'import json'" inline-bare
check "python3 -c\"import json\"" inline-bare
check "python3 -mjson.tool f" inline-bare
check "python3 -Xutf8 -c x" inline-bare
check "python3 -Ic'x'" inline-isolated
check "python3 -cI 'x'" inline-bare
check "\"python3\" -c x" inline-bare
check "\"python3\" \"\$X/a.py\"" script
check "cmd = ['python3', 'x.py']" script
check "PY_ARGV=(uv run python)" none
check "arr=( \$(python3 -c 'x') )" inline-bare
check "x=(\"\$(python3 -c 'y')\")" inline-bare
check "local -a out=( \"\$(python3 -c 'print(1)')\" )" inline-bare
check "a=( \`python3 -c 'x'\` )" inline-bare
check "[ -x \"\$_dir/python3\" ]" none
check "echo \"\$cand(python): 실패\"" inline-bare
check "if true; then(python3 -c 'import json'); fi" inline-bare
check "for f in a; do(python3 -c 'x'); done" inline-bare
check "( python3 -c 'x' )" inline-bare
check "set +B  # nested \"\$(python3 -c \"...\")\"" none
check "\`\`\`python" none
check "echo 'a # b' | python3 -c 'pass'" inline-bare

note "[스캐너 — 파일 단위: 마크다운 주석 · 줄 이음 · 못 읽는 파일]"
SC="$(mktemp -d)"; SC="$(cd "$SC" && pwd -P)"
printf '```bash\n# state 는 python3 -c 로 고친다\n```\n' > "$SC/a.md"
printf '# python3 -c 는 설명일 뿐\nset +B  # nested python3 -c\n' > "$SC/b.sh"
printf 'x=$(python3 \\\n  -c "import json")\n' > "$SC/c.sh"
printf 'python3 -c x \xff\xfe\n' > "$SC/d.sh"
sc="$(python3 -I -X utf8 "$SCAN" scan "$SC/a.md" "$SC/b.sh" "$SC/c.sh" "$SC/d.sh")"
assert_contains "$sc" "$SC/a.md:2	bare" "마크다운 펜스 안 # 줄은 지시라서 본다"
assert_not_contains "$sc" "$SC/b.sh" "셸 스크립트의 # 주석은 보지 않는다"
assert_contains "$sc" "$SC/c.sh:1	bare" "\\ 로 이어진 다음 줄의 -c 를 본다"
assert_contains "$sc" "$SC/d.sh:0	unreadable" "UTF-8 이 아닌 파일은 건너뛰지 않고 알린다"
rm -rf "$SC"

note "[정적 — 추적되는 파일의 인라인 호출]"
corpus=()
while IFS= read -r -d '' p; do
  case "$p" in
    */tests/*|*/CHANGELOG.md|*/README.md) continue ;;
  esac
  corpus+=("$ROOT/$p")
done < <(git -C "$ROOT" ls-files -z -- plugins shared tools)
assert_eq "$([ "${#corpus[@]}" -ge 200 ] && echo ok || echo "${#corpus[@]}")" ok "코퍼스가 비지 않았다(파일 ${#corpus[@]}개)"

# 스캐너도 -X utf8 이다 — 한국어 줄을 찍다 죽으면 보고가 잘린 채 「없음」이 통과한다. rc 를 따로 잰다.
scan_rc=0; report="$(python3 -I -X utf8 "$SCAN" scan "${corpus[@]}")" || scan_rc=$?
assert_eq "$scan_rc" 0 "스캐너가 코퍼스 끝까지 돌았다"
unread="$(printf '%s\n' "$report" | awk -F'\t' '$2 == "unreadable"')"
assert_eq "$unread" "" "코퍼스에 읽지 못한 파일이 없다"
bare="$(printf '%s\n' "$report" | awk -F'\t' '$2 == "bare"')"
left="$bare"
for i in "${!EXEMPT_PATHS[@]}"; do
  hit="$(printf '%s\n' "$bare" | grep -F "$ROOT/${EXEMPT_PATHS[$i]}:" | grep -F -- "${EXEMPT_NEEDLES[$i]}")"
  assert_eq "$(printf '%s' "$hit" | grep -c .)" 1 "예외가 아직 한 줄을 가리킨다: ${EXEMPT_PATHS[$i]} — ${EXEMPT_REASONS[$i]}"
  [ -n "$hit" ] && left="$(printf '%s\n' "$left" | grep -vF -- "$hit")"
done
left="$(printf '%s\n' "$left" | grep .)"
if [ -z "$left" ]; then
  ok "격리 없는 인라인 python 호출이 없다(예외 ${#EXEMPT_PATHS[@]}개 제외)"
else
  no "격리 없는 인라인 python 호출 — python3 -I 로 부른다"
  printf '%s\n' "$left" | sed "s#^$ROOT/#      #"
fi

note "[정적 — 양성 증인: 고친 자리를 스캐너가 인라인 · 격리로 본다]"
# spec-interview SKILL.md · finishing.md 는 증인에서 뺐다(R7 Task 9) — 그 자리(state 를 Bash 로만 고치던 계약의 인라인 python 줄)가
# 상태 파일 이월로 지워져 인라인 python 이 남지 않는다. 격리 없는 호출이 새로 생기면 위 부재 검사가 잡는다.
for f in \
  plugins/quality-gates/scripts/setup-qg.sh \
  plugins/quality-gates/scripts/discover-spec.sh \
  plugins/quality-gates/scripts/e2e-state.sh \
  plugins/quality-gates/scripts/publish-comment.sh \
  plugins/quality-gates/scripts/run-test-selection.sh \
  plugins/plugin-audit/scripts/check-plugin-structure.sh \
  plugins/plugin-audit/scripts/run-own-tests.sh \
  plugins/spec-distill/skills/request-framing/SKILL.md \
  plugins/spec-distill/skills/reviewing-brief/SKILL.md \
  plugins/spec-distill/skills/spec-review/SKILL.md \
  shared/docreview/scripts/run_docreview_codex_reviewer.sh; do
  n="$(printf '%s\n' "$report" | awk -F'\t' -v p="$ROOT/$f:" 'index($1, p) == 1 && $2 == "isolated"' | grep -c .)"
  assert_eq "$([ "$n" -ge 1 ] && echo ok || echo 0)" ok "$f — 격리된 인라인 호출 ${n}개"
done

note "[행동 — 표준 모듈 이름을 심은 리포]"
TMP="$(mktemp -d)"; TMP="$(cd "$TMP" && pwd -P)"
trap 'rm -rf "$TMP" "$SCAN_DIR"' EXIT
REPO="$TMP/repo"; MARK="$TMP/planted-ran"
mkdir -p "$REPO/docs" "$REPO/plug/.claude-plugin"
git -C "$REPO" init -q
git -C "$REPO" config user.email t@example.com; git -C "$REPO" config user.name t
printf '# 캐너리 스펙\n' > "$REPO/docs/spec.md"
printf '{"name":"plug","version":"0.0.1","description":"x"}\n' > "$REPO/plug/.claude-plugin/plugin.json"
git -C "$REPO" commit -q --allow-empty -m "chore: base"
git -C "$REPO" branch -M main
git -C "$REPO" checkout -q -b feature/canary
git -C "$REPO" add -A
git -C "$REPO" commit -q -m "feat: canary" -m "Spec: docs/spec.md"
for m in json socket hashlib subprocess pathlib uuid shutil contextlib importlib re tempfile stat; do
  printf 'import os as _o\nopen(_o.environ["QG_CANARY"], "a").write("%s\\n")\nraise SystemExit(97)\n' "$m" > "$REPO/$m.py"
done
export QG_CANARY="$MARK"
planted() { [ -s "$MARK" ] && tr '\n' ' ' < "$MARK" || echo "(없음)"; }

(cd "$REPO" && python3 -c 'import json' >/dev/null 2>&1)
assert_eq "$(planted)" "json " "양성 대조 — 격리 없는 python3 -c 는 심은 json.py 를 실행한다"
rm -f "$MARK"

QG="$ROOT/plugins/quality-gates/scripts"
out="$(cd "$REPO" && bash "$QG/discover-spec.sh" --intent-out "$TMP/intent.md" 2>&1)"
assert_contains "$out" '"intent_source": "spec-trailer"' "discover-spec.sh 가 spec 트레일러까지 돌았다"
assert_eq "$(planted)" "(없음)" "discover-spec.sh — 심은 모듈이 실행되지 않았다"
rm -f "$MARK"

out="$(cd "$REPO" && CLAUDE_CODE_SESSION_ID=canary-0001 bash "$QG/setup-qg.sh" --session-id canary-0001 2>&1)"; rc=$?
assert_eq "$rc" 0 "setup-qg.sh 가 끝까지 돌았다: $(printf '%s' "$out" | tail -n 1)"
assert_eq "$(planted)" "(없음)" "setup-qg.sh — 심은 모듈이 실행되지 않았다"
rm -f "$MARK"

out="$(cd "$REPO" && bash "$QG/e2e-state.sh" fingerprint --out "$TMP/before.txt" 2>&1)"
assert_contains "$out" "fingerprint: $TMP/before.txt" "e2e-state.sh fingerprint 가 지문을 냈다"
out="$(cd "$REPO" && bash "$QG/e2e-state.sh" compare "$TMP/before.txt" "$TMP/before.txt" 2>&1)"
assert_eq "$out" "same" "e2e-state.sh compare 가 같은 지문을 same 으로 냈다"
printf '기대 상태\t판정\t증거\n화면이 뜬다\t충족\t"ok"\n' > "$TMP/ev.tsv"
out="$(cd "$REPO" && bash "$QG/e2e-state.sh" propose "$TMP/ev.tsv" 2>&1)"
assert_contains "$out" "proposal: " "e2e-state.sh propose 가 판정안을 냈다"
# propose 는 내장 sys 만 import 해서 이 겹으로는 못 잰다 — 아래 단언은 fingerprint · compare 의 것이다.
assert_eq "$(planted)" "(없음)" "e2e-state.sh fingerprint · compare — 심은 모듈이 실행되지 않았다"
rm -f "$MARK"

PA="$ROOT/plugins/plugin-audit/scripts"
mkdir -p "$TMP/no-plugin-dev"
out="$(cd "$REPO" && bash "$PA/check-plugin-structure.sh" plug --plugin-dev-root "$TMP/no-plugin-dev" 2>&1)"
assert_contains "$out" '"degraded"' "check-plugin-structure.sh 가 결과 JSON 을 냈다"
out="$(cd "$REPO" && bash "$PA/run-own-tests.sh" plug canary-0001 --sandbox-helper "$TMP/absent.sh" 2>&1)"
assert_contains "$out" '"own_tests"' "run-own-tests.sh 가 결과 JSON 을 냈다"
assert_eq "$(planted)" "(없음)" "plugin-audit 두 스크립트 — 심은 모듈이 실행되지 않았다"

note "[행동 — UTF-8 아닌 로케일: -I 가 PYTHONIOENCODING 을 무시하므로 -X utf8 이 있어야 한국어를 찍는다]"
NONUTF8=""
for l in en_US.ISO8859-15 en_US.ISO8859-1 en_US.iso885915 en_US.iso88591 de_DE.ISO8859-15; do
  locale -a 2>/dev/null | grep -qx "$l" && { NONUTF8="$l"; break; }
done
if [ -n "$NONUTF8" ]; then
  out="$(cd "$REPO" && LC_ALL="$NONUTF8" LANG="$NONUTF8" PYTHONIOENCODING=utf-8 bash "$PA/check-plugin-structure.sh" plug --plugin-dev-root "$TMP/no-plugin-dev" 2>/dev/null)"
  assert_contains "$out" '"degraded"' "$NONUTF8 — check-plugin-structure.sh 가 한국어 결과 JSON 을 낸다"
  # discover-spec 이 한국어를 찍는 길은 거부 사유다 — 리포 밖을 가리키는 Spec 트레일러로 그 길을 탄다
  REJ="$TMP/reject-repo"; mkdir -p "$REJ"; git -C "$REJ" init -q
  git -C "$REJ" config user.email t@example.com; git -C "$REJ" config user.name t
  git -C "$REJ" commit -q --allow-empty -m "chore: base"; git -C "$REJ" branch -M main
  git -C "$REJ" checkout -q -b feature/reject
  git -C "$REJ" commit -q --allow-empty -m "feat: reject" -m "Spec: ../outside.md"
  out="$(cd "$REJ" && LC_ALL="$NONUTF8" LANG="$NONUTF8" PYTHONIOENCODING=utf-8 bash "$QG/discover-spec.sh" --intent-out "$TMP/intent2.md" 2>/dev/null)"
  assert_contains "$out" '"intent_note": "spec 경로 거부"' "$NONUTF8 — discover-spec.sh 가 한국어 거부 사유를 담은 JSON 을 낸다"
else
  no "UTF-8 아닌 로케일이 하나도 없어 이 겹을 재지 못했다(셀 수 없음)"
fi

finish
