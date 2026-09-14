#!/usr/bin/env bash
# guards: plugins/*/skills/*/SKILL.md plugins/*/commands/*.md
#
# skill · command 본문에 위치 인자 토큰이 없는가 — 저장소 전체에서 도출한 코퍼스 전부를 잰다.
#
# Claude Code 는 로드된 SKILL.md · 커맨드 본문의 `$N`(= `$ARGUMENTS[N]`, 0부터)을 호출 인자로
# 치환하고, 인자가 없는 자리의 토큰은 그대로 둔다. 셸 쪽 의미로 쓴 토큰(함수 인자 · awk 필드)도
# 가리지 않는다. 그래서 인자가 둘 이상인 호출에서만 셸 펜스의 토큰이 인자 값으로 바뀐다 — 실측:
# `reviewing-brief`(인자 payload · audit)의 잔존물 중화 함수가 로드된 본문에서 audit 을 지우는
# `rm -f` 가 됐다. 인자 하나로 불린 `reviewing-spec` 에서는 같은 토큰이 그대로 남았다.
#
# 코퍼스 — Skill · 커맨드 로드 때 본문으로 들어가는 파일: `plugins/*/skills/*/SKILL.md` ·
#   `plugins/*/commands/*.md`. skill 디렉토리의 다른 파일(references 등)은 모델이 Read 로 읽으므로
#   코퍼스에 넣지 않았다 — 그 파일들이 치환되지 않는다는 것은 로드 경로에서 도출한 것이고 문서가
#   명시하지 않는다. 파일 전체를 본다 — frontmatter · 펜스 안팎 · 주석 · 인라인 코드.
# 금지 — `$0`…`$9`(뒤 숫자 이어짐 · 역슬래시 이스케이프 형 포함) · `${0`…`${9` · `$@` · `$*` · `$#`
#   (앞 셋은 문서에 치환 여부가 없어 보수적으로) · frontmatter 의 `arguments:` 선언(선언된 이름의
#   `$name` 이 치환된다).
# 허용 — `$ARGUMENTS` · `$ARGUMENTS[N]`(의도된 사용) · `${CLAUDE_*}` · 이름 있는 셸 변수 · `$?` · `$$`.
#
# 양의 짝 — (a) 두 도출(git · find)이 같은 집합이고 0 이 아니며 스캐너가 그 전부를 읽었다.
#   (b) `$ARGUMENTS` 를 쓰는 파일이 코퍼스에 있고 그 파일들의 적발이 0 이다 · 허용 토큰 표본의 적발이 0 이다.
#   (c) 금지 토큰을 본문 어디에 두어도 같은 스캐너가 그 줄·그 토큰으로 잡는다(스캐너 자신의 양성 대조).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

derive_git() {
  git -C "$ROOT" ls-files --cached --others --exclude-standard -- \
      'plugins/*/skills/*/SKILL.md' 'plugins/*/commands/*.md' | LC_ALL=C sort -u
}

if [ "${1:-}" = "--emit-scanned" ]; then
  derive_git
  exit 0
fi

. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

SCRATCH="$(mktemp -d -t sh-posargs-XXXXXX)" || { echo "scratch 생성 실패" >&2; exit 1; }
[ -n "$SCRATCH" ] && [ -d "$SCRATCH" ] || { echo "scratch 경로가 비었다" >&2; exit 1; }
trap 'rm -rf "$SCRATCH"' EXIT

# ── 스캐너 — 코퍼스와 표본이 같은 코드를 지난다 ─────────────────────────────────
# 출력 줄: HIT <경로> <줄> <토큰> · DECL <경로> <줄> arguments: · ARGS <경로> · UNREADABLE <경로> <사유> · SCANNED <n>
cat > "$SCRATCH/scan.py" <<'PY'
import re, sys
FORBID = re.compile(r'\$(?:\{[0-9]|[0-9@*#])')
FRONT = re.compile(r'\A---[ \t]*\r?\n(.*?)(?:\r?\n)---[ \t]*(?:\r?\n|\Z)', re.S)
DECL = re.compile(r'^[ \t]*["\']?arguments["\']?[ \t]*:', re.M)
root, listing = sys.argv[1], sys.argv[2]
scanned = 0
for rel in open(listing, encoding="utf-8").read().split("\n"):
    if not rel:
        continue
    path = rel if rel.startswith("/") else root + "/" + rel
    try:
        text = open(path, encoding="utf-8").read()
    except Exception as e:
        print("UNREADABLE\t%s\t%s" % (rel, type(e).__name__))
        continue
    scanned += 1
    for m in FORBID.finditer(text):
        print("HIT\t%s\t%d\t%s" % (rel, text.count("\n", 0, m.start()) + 1, m.group(0)))
    fm = FRONT.match(text)
    if fm:
        for m in DECL.finditer(fm.group(1)):
            print("DECL\t%s\t%d\targuments:" % (rel, text.count("\n", 0, fm.start(1) + m.start()) + 1))
    if "$ARGUMENTS" in text:
        print("ARGS\t%s" % rel)
print("SCANNED\t%d" % scanned)
PY

# ── (a) 코퍼스 — 두 도출이 같은 집합이고 0 이 아니다 ─────────────────────────────
derive_git > "$SCRATCH/git.lst"
( cd "$ROOT" && find plugins \( -path 'plugins/*/skills/*/SKILL.md' -o -path 'plugins/*/commands/*.md' \) \
    \( -type f -o -type l \) ) | LC_ALL=C sort -u > "$SCRATCH/find.all"
( cd "$ROOT" && git check-ignore --stdin < "$SCRATCH/find.all" ) | LC_ALL=C sort -u > "$SCRATCH/find.ign"
LC_ALL=C comm -23 "$SCRATCH/find.all" "$SCRATCH/find.ign" > "$SCRATCH/find.lst"
n_git="$(grep -c . "$SCRATCH/git.lst" || true)"
if [ "${n_git:-0}" -gt 0 ] && cmp -s "$SCRATCH/git.lst" "$SCRATCH/find.lst"; then
  ok "코퍼스: git 도출과 find 도출이 같은 ${n_git}개 파일이다 (빈 glob 이 통과를 만들지 않는다)"
else
  no "코퍼스: 도출이 비었거나 두 도출이 갈렸다 (git ${n_git:-0}개) — 아래 판정은 코퍼스 전부를 재지 않는다"
  diff "$SCRATCH/git.lst" "$SCRATCH/find.lst" | sed 's/^/      /'
fi

python3 "$SCRATCH/scan.py" "$ROOT" "$SCRATCH/git.lst" > "$SCRATCH/scan.out" 2> "$SCRATCH/scan.err"
scan_rc=$?
n_scanned="$(awk -F'\t' '$1=="SCANNED"{print $2}' "$SCRATCH/scan.out")"
n_unread="$(awk -F'\t' '$1=="UNREADABLE"' "$SCRATCH/scan.out" | grep -c . || true)"
if [ "$scan_rc" -eq 0 ] && [ "${n_scanned:-x}" = "${n_git:-y}" ] && [ "${n_unread:-1}" -eq 0 ]; then
  ok "코퍼스: 스캐너가 도출된 ${n_git}개를 전부 UTF-8 로 읽었다"
else
  no "코퍼스: 스캐너 rc=$scan_rc · 읽음 '${n_scanned:-}' / 도출 ${n_git:-0} · 판독 불가 ${n_unread:-?} — 셀 수 없는 파일이 있다"
  awk -F'\t' '$1=="UNREADABLE"{print "      " $2 " (" $3 ")"}' "$SCRATCH/scan.out"
  sed 's/^/      /' "$SCRATCH/scan.err" | head -5
fi

# ── 본 판정 — 코퍼스의 금지 토큰 0 ─────────────────────────────────────────────
awk -F'\t' '$1=="HIT"||$1=="DECL"' "$SCRATCH/scan.out" > "$SCRATCH/hits"
n_hits="$(grep -c . "$SCRATCH/hits" || true)"
if [ "${n_hits:-0}" -eq 0 ]; then
  ok "금지 토큰: 코퍼스 ${n_git}개 파일 어디에도 위치 인자 토큰 · arguments: 선언이 없다"
else
  no "금지 토큰: ${n_hits}건 — 로드된 본문에서 호출 인자로 치환된다. 셸 함수 인자는 이름 있는 변수로, awk 필드는 sed 로 바꿔라"
  awk -F'\t' '{print "      " $2 ":" $3 "  " $4}' "$SCRATCH/hits"
fi

# ── (b) 허용 토큰 음성 대조 ───────────────────────────────────────────────────
awk -F'\t' '$1=="ARGS"{print $2}' "$SCRATCH/scan.out" > "$SCRATCH/args.lst"
n_args="$(grep -c . "$SCRATCH/args.lst" || true)"
n_args_hits="$(awk -F'\t' 'NR==FNR{a[$1]=1; next} a[$2]' "$SCRATCH/args.lst" "$SCRATCH/hits" | grep -c . || true)"
if [ "${n_args:-0}" -gt 0 ] && [ "${n_args_hits:-1}" -eq 0 ]; then
  ok "허용: \$ARGUMENTS 를 쓰는 ${n_args}개 파일에서 적발 0 — 허용 토큰을 금지로 잡지 않는다"
else
  no "허용: \$ARGUMENTS 사용 파일 ${n_args:-0}개 · 그 파일들의 적발 ${n_args_hits:-?}건 — 대조가 공허하거나 허용 토큰 옆에 금지 토큰이 있다"
fi

# ── (c) 스캐너 양성 대조 — 금지 토큰을 본문 어디에 두어도 잡는가 ──────────────────
PD="$SCRATCH/probes"; mkdir -p "$PD"
cat > "$SCRATCH/probes.py" <<'PY'
import os, sys
d = sys.argv[1]
N = "\n"
probes = [
    ("front",    "---" + N + "name: x" + N + "description: costs $1 each" + N + "---" + N + "body" + N, "HIT", 3, "$1"),
    ("comment",  "<!-- keep $2 -->" + N + "body" + N, "HIT", 1, "$2"),
    ("prose",    "# T" + N + N + "인자 $2 를 읽는다." + N, "HIT", 3, "$2"),
    ("inline",   "use `awk '$1==\"k:\"{print}'` here" + N, "HIT", 1, "$1"),
    ("fencecmt", "```bash" + N + "# 대상은 $3" + N + "true" + N + "```" + N, "HIT", 2, "$3"),
    ("fencecode","```bash" + N + "rm -f \"$1\" 2>/dev/null" + N + "```" + N, "HIT", 2, "$1"),
    ("zero",     "run $0 now" + N, "HIT", 1, "$0"),
    ("nine",     "x $9" + N, "HIT", 1, "$9"),
    ("multi",    "x $10" + N, "HIT", 1, "$1"),
    ("brace",    "x ${1:-d}" + N, "HIT", 1, "${1"),
    ("at",       "x \"$@\"" + N, "HIT", 1, "$@"),
    ("star",     "x $*" + N, "HIT", 1, "$*"),
    ("hash",     "x $#" + N, "HIT", 1, "$#"),
    ("escaped",  "x \\$2" + N, "HIT", 1, "$2"),
    ("decl",     "---" + N + "name: x" + N + "arguments: [issue]" + N + "---" + N + "b" + N, "DECL", 3, "arguments:"),
    ("declcrlf", "---\r\nname: x\r\narguments: [issue]\r\n---\r\nb\r\n", "DECL", 3, "arguments:"),
]
allowed = ("allowed", "---" + N + "argument-hint: \"[x]\"" + N + "---" + N +
           "Skill x $ARGUMENTS" + N + "$ARGUMENTS[0] $ARGUMENTS[1] ${CLAUDE_PLUGIN_ROOT} ${CLAUDE_SESSION_ID}" + N +
           "```bash" + N + "PAYLOAD=\"${PAYLOAD:-}\"; rm -f \"$NEUTRALISE_TARGET\"; echo \"${arr[@]}\" ${#arr[@]} $((i+1)) rc=$? $$" + N + "```" + N)
with open(os.path.join(d, "list"), "w", encoding="utf-8") as lf, open(os.path.join(d, "expect"), "w", encoding="utf-8") as ef:
    for name, body, kind, line, tok in probes:
        p = os.path.join(d, name + ".md")
        open(p, "w", encoding="utf-8", newline="").write(body)
        lf.write(p + N)
        ef.write("%s\t%s\t%d\t%s%s" % (kind, p, line, tok, N))
    p = os.path.join(d, allowed[0] + ".md")
    open(p, "w", encoding="utf-8").write(allowed[1])
    lf.write(p + N)
    open(os.path.join(d, "allowed"), "w", encoding="utf-8").write(p + N)
PY
python3 "$SCRATCH/probes.py" "$PD"
python3 "$SCRATCH/scan.py" "" "$PD/list" > "$SCRATCH/probe.out" 2>&1
n_probe="$(grep -c . "$PD/expect" || true)"
missed=""
while IFS= read -r want; do
  [ -n "$want" ] || continue
  grep -qxF -- "$want" "$SCRATCH/probe.out" || missed="$missed | $(printf '%s' "$want" | awk -F'\t' '{n=split($2,a,"/"); print a[n] ":" $3 " " $4}')"
done < "$PD/expect"
if [ "${n_probe:-0}" -ge 16 ] && [ -z "$missed" ]; then
  ok "양성 대조: 표본 ${n_probe}건(frontmatter · HTML 주석 · 산문 · 인라인 코드 · 펜스 주석 · 펜스 코드 · 토큰 변형 · arguments: 선언)을 그 줄·그 토큰으로 전부 잡는다"
else
  no "양성 대조: 표본 ${n_probe:-0}건 중 놓친 것 —${missed:- (표본이 모자란다)}"
fi
AP="$(cat "$PD/allowed")"
ap_hits="$(awk -F'\t' -v p="$AP" '($1=="HIT"||$1=="DECL") && $2==p' "$SCRATCH/probe.out" | grep -c . || true)"
if [ "${ap_hits:-1}" -eq 0 ] && grep -qxF -- "ARGS	$AP" "$SCRATCH/probe.out"; then
  ok "음성 대조: 허용 토큰 표본(\$ARGUMENTS · \$ARGUMENTS[N] · \${CLAUDE_*} · 이름 있는 셸 변수 · \$? · \$\$)은 읽히고 적발 0"
else
  no "음성 대조: 허용 토큰 표본의 적발 ${ap_hits:-?}건 또는 표본이 읽히지 않았다"
  awk -F'\t' -v p="$AP" '$2==p{print "      " $0}' "$SCRATCH/probe.out"
fi

finish
