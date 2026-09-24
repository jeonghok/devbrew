#!/usr/bin/env bash
# guards: plugins/*/agents/*.md plugins/*/skills/** plugins/*/commands/** plugins/*/hooks/** plugins/*/scripts/*.js shared/docreview/agents/*.md
#
# AC22 (설계 §6.3.4 · §11) — docreview agent 의 **사본 집합과 디스패치 집합이 정확히
# 일치한다.** 디스패치하는데 사본이 없어도, 사본이 있는데 디스패치하지 않아도 RED.
# 두 집합 모두 코퍼스에서 도출한다(∀).
#
# **기존 락에 기대지 않는다.** `shared/tests/test_dispatch_disposition.sh` 는 agent 를
# frontmatter `name:` 으로만 키잡고 디스패치 이름의 플러그인 접두를 검사하지 않는다 —
# 같은 이름의 사본이 두 플러그인에 있으면 한 키로 접히고, 한 플러그인의 디스패치가 다른
# 플러그인 사본의 「dispatch ≥ 1」을 대신 만족시킨다(PR3 계획 R-D 의 측정). 이 락은
# 원소를 `(플러그인, 이름)` 쌍으로 잡는다: 디스패치의 접두가 있으면 접두의 플러그인,
# 없으면 그 파일이 사는 플러그인이다.
#
# 도출만으로는 「사본도 디스패치도 함께 사라짐」이 GREEN 이다(양쪽이 같이 빈다). 그래서
# 파일 밖 기대값(EXPECTED)과 등호를 함께 둔다. 새 사본을 더하면 이 핀도 고친다 — 의도다.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  # 선언을 되뇌지 않는다 — 검출기(`copyset.py`)가 실제로 여는 파일 선택 규칙과 같은
  # 경로를 낸다(가드 커버리지 락의 방향 A 가 자기 반복으로 GREEN 이 되지 않게).
  _R="$(cd "$(dirname "$0")/../.." && pwd)"
  git -C "$_R" ls-files --cached --others --exclude-standard -- \
    'plugins/*/agents/*.md' 'plugins/*/skills/**' 'plugins/*/commands/**' \
    'plugins/*/hooks/**' 'plugins/*/scripts/*.js' 'shared/docreview/agents/*.md'
  exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
export PYTHONDONTWRITEBYTECODE=1
TMPD="$(mktemp -d -t copyset-XXXXXX)" || exit 1
trap 'rm -rf "$TMPD"' EXIT

# 검출기 — 리포 루트 하나를 받아 두 집합을 낸다. 픽스처 리포에도 같은 검출기를 건다
# (검출기 자신의 이빨을 잰다).
cat > "$TMPD/copyset.py" <<'PY'
import os, re, subprocess, sys
root = sys.argv[1]
files = subprocess.run(
    ["git", "-C", root, "ls-files", "--cached", "--others", "--exclude-standard",
     "--", "plugins", "shared"],
    capture_output=True, text=True, check=True).stdout.split("\n")
NAME = re.compile(r'^name:\s*["\']?([^"\'\s#]+)["\']?\s*(?:#.*)?$', re.M)
MARK = re.compile(r"^[ \t]*(?:#|//|<!--)[ \t]*copy-of:[ \t]*(\S+)")
def read(p):
    # 인덱스에는 있는데 워킹트리에서 지워진 파일(`git ls-files --cached`)은 빈 문자열로 —
    # 죽으면 stdout 이 비어 모든 값이 「비었다」로 오보된다(모의 실행 A3).
    try:
        with open(os.path.join(root, p), encoding="utf-8") as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError):
        return ""
canon = {}
for f in files:
    if re.fullmatch(r"shared/docreview/agents/[^/]+\.md", f):
        m = NAME.search(read(f))
        if m:
            canon[m.group(1)] = f
copies = set()
for f in files:
    m = re.fullmatch(r"plugins/([^/]+)/agents/([^/]+)\.md", f)
    if not m:
        continue
    text = read(f)
    nm = NAME.search(text)
    name = nm.group(1) if nm else m.group(2)
    head = text.splitlines()[:20]
    marker = None
    for line in head:
        mm = MARK.match(line)
        if mm:
            marker = mm.group(1)
    if name in canon or (marker or "").startswith("shared/docreview/agents/"):
        copies.add((m.group(1), name))
dispatch = set()
if canon:
    names = sorted(canon, key=len, reverse=True)
    # 표기 필터가 이름 매칭보다 먼저 걸린다(형제 test_dispatch_disposition.sh:93 와
    # 같은 규율). `subagent_type`/`agentType` 뒤에 `:`·`=` 구분자(사이에 닫는
    # 따옴표 하나는 허용)를 요구한다 — 구분자 없이 키워드만 요구하면(라운드 1의
    # 실수) 산문 속 "subagent_type 필드에 ... doc-recritic ..." 같은 문장이
    # 디스패치로 오판된다(리뷰 실측). 구분자를 다시 앵커로 걸되, `subagent_type="..."`
    # (= 표기)와 `"agentType": "..."`(JSON 키, 이름과 콜론 사이에 닫는 따옴표가
    # 낀다) 는 여전히 잡는다 — 둘 다 구분자 앞에 선택적 닫는 따옴표 하나만 있다.
    NOTATION = re.compile(r'subagent_type["\']?\s*[:=]|agentType["\']?\s*[:=]|Agent\(|^\s*agent:\s')
    # 경계도 형제와 다르다: `=`·`(`·backtick 을 이름 앞에 허용해
    # `subagent_type="..."`·백틱 인용을 잡는다. `-` 는 경계가 아니다(형제와 동일 —
    # `adversarial` 이 `artifact-adversarial` 을 먹지 않게).
    PRE, POST = r'(?:^|[\s"\'=:(`])', r'(?=["\'\s,)`]|$)'
    def name_re(n):
        return re.compile(PRE + r'(?:([A-Za-z0-9_-]+):)?' + re.escape(n) + POST)
    for f in files:
        m = re.fullmatch(r"plugins/([^/]+)/(?:skills|commands|hooks)/.+", f) or \
            re.fullmatch(r"plugins/([^/]+)/scripts/[^/]+\.js", f)
        if not m:
            continue
        text = read(f)
        for line in text.splitlines():
            if not NOTATION.search(line):
                continue
            for n in names:
                dm = name_re(n).search(line)
                if dm:
                    dispatch.add((dm.group(1) or m.group(1), n))
def show(s):
    return " ".join(sorted("%s:%s" % p for p in s))
print("CANON=" + " ".join(sorted(canon)))
print("COPIES=" + show(copies))
print("DISPATCH=" + show(dispatch))
print("COPY_NOT_DISPATCHED=" + show(copies - dispatch))
print("DISPATCHED_NOT_COPIED=" + show(dispatch - copies))
PY

scan() { python3 "$TMPD/copyset.py" "$1"; }
# kv <KEY> <text> — `KEY=value` 줄의 값. assert.sh 의 `field` 는 첫 «콜론»으로 가르는데
# 이 출력의 값에는 `플러그인:이름` 콜론이 있고 구분자는 `=` 다 — `field` 를 쓰면 전부 빈 값이다.
kv() { printf '%s\n' "$2" | sed -n "s/^$1=//p"; }

note "── 실제 리포"
OUT="$(scan "$REPO_ROOT")"; SRC=$?
# 검출기가 죽으면 아래 빈 값 단언이 전부 거짓으로 GREEN/RED 한다 — rc 를 먼저 단언한다.
assert_eq "$SRC" "0" "검출기가 정상 종료한다"
printf '%s\n' "$OUT" | sed 's/^/      /'
CANON="$(kv CANON "$OUT")"; COPIES="$(kv COPIES "$OUT")"; DISPATCH="$(kv DISPATCH "$OUT")"
[ -n "$CANON" ]    && ok "docreview 정본이 도출된다"      || no "docreview 정본을 도출하지 못했다 — 아래는 빈 코퍼스다"
[ -n "$COPIES" ]   && ok "사본 집합이 비지 않는다"        || no "사본 집합이 비었다"
[ -n "$DISPATCH" ] && ok "디스패치 집합이 비지 않는다"    || no "디스패치 집합이 비었다"
assert_eq "$(kv COPY_NOT_DISPATCHED "$OUT")"   "" "사본이 있는데 디스패치하지 않는 것이 없다"
assert_eq "$(kv DISPATCHED_NOT_COPIED "$OUT")" "" "디스패치하는데 사본이 없는 것이 없다"
EXPECTED="spec-distill:doc-critic spec-distill:doc-critic-web spec-distill:doc-recritic"
assert_eq "$COPIES"   "$EXPECTED" "사본 집합 == 파일 밖 기대값"
assert_eq "$DISPATCH" "$EXPECTED" "디스패치 집합 == 파일 밖 기대값"

note "── 검출기 자기검사 (픽스처 리포)"
# mkfix <디렉토리> — 정본 하나(doc-recritic)와 spec-distill 사본 + 그 디스패치를 가진 최소 리포
mkfix() {
  local d="$1"
  mkdir -p "$d/shared/docreview/agents" "$d/plugins/spec-distill/agents" "$d/plugins/spec-distill/skills/s"
  printf -- '---\nname: doc-recritic\n---\n본문\n' > "$d/shared/docreview/agents/doc-recritic.md"
  { printf '%s\n' '---' '# copy-of: shared/docreview/agents/doc-recritic.md' 'name: doc-recritic' '---' '본문'; } \
    > "$d/plugins/spec-distill/agents/doc-recritic.md"
  printf 'Agent({\n  subagent_type: "spec-distill:doc-recritic",\n})\n' > "$d/plugins/spec-distill/skills/s/SKILL.md"
  git -C "$d" init -q
}
F="$TMPD/fx-ok"; mkfix "$F"
O="$(scan "$F")"
assert_eq "$(kv COPY_NOT_DISPATCHED "$O")$(kv DISPATCHED_NOT_COPIED "$O")" "" "픽스처 기준선은 일치한다 (양성 대조의 짝)"

F="$TMPD/fx-cross"; mkfix "$F"
mkdir -p "$F/plugins/quality-gates/agents" "$F/plugins/quality-gates/skills/q"
cp "$F/plugins/spec-distill/agents/doc-recritic.md" "$F/plugins/quality-gates/agents/doc-recritic.md"
printf 'Agent({\n  subagent_type: "spec-distill:doc-recritic",\n})\n' > "$F/plugins/quality-gates/skills/q/SKILL.md"
O="$(scan "$F")"
assert_eq "$(kv COPY_NOT_DISPATCHED "$O")" "quality-gates:doc-recritic" \
  "qg 사본이 있는데 qg 가 spec-distill: 접두로 디스패치하면 잡는다 (기존 락의 이름-키 사각지대)"

F="$TMPD/fx-nocopy"; mkfix "$F"
mkdir -p "$F/plugins/quality-gates/skills/q"
printf 'Agent({\n  subagent_type: "quality-gates:doc-recritic",\n})\n' > "$F/plugins/quality-gates/skills/q/SKILL.md"
O="$(scan "$F")"
assert_eq "$(kv DISPATCHED_NOT_COPIED "$O")" "quality-gates:doc-recritic" "사본 없이 디스패치하면 잡는다"

F="$TMPD/fx-bare"; mkfix "$F"
mkdir -p "$F/plugins/quality-gates/skills/q"
printf 'Agent({\n  subagent_type: "doc-recritic",\n})\n' > "$F/plugins/quality-gates/skills/q/SKILL.md"
O="$(scan "$F")"
assert_eq "$(kv DISPATCHED_NOT_COPIED "$O")" "quality-gates:doc-recritic" \
  "접두 없는 디스패치는 그 파일의 플러그인 것이다 — 접두를 빼서 빠져나가지 못한다"

F="$TMPD/fx-agent-call"; mkfix "$F"
mkdir -p "$F/plugins/quality-gates/skills/q"
printf 'Agent(subagent_type="quality-gates:doc-recritic", prompt=p)\n' > "$F/plugins/quality-gates/skills/q/SKILL.md"
O="$(scan "$F")"
assert_eq "$(kv DISPATCHED_NOT_COPIED "$O")" "quality-gates:doc-recritic" \
  "«=» 표기 Agent(subagent_type=\"...\") 도 잡는다 — 사본 없이 콜만 있으면 RED"

F="$TMPD/fx-json-key"; mkfix "$F"
mkdir -p "$F/plugins/quality-gates/scripts"
printf '{"agentType": "quality-gates:doc-recritic"}\n' > "$F/plugins/quality-gates/scripts/dispatch.js"
O="$(scan "$F")"
assert_eq "$(kv DISPATCHED_NOT_COPIED "$O")" "quality-gates:doc-recritic" \
  "JSON 키 표기 {\"agentType\": \"...\"} 도 잡는다 — 사본 없이 콜만 있으면 RED"

F="$TMPD/fx-unmarked"; mkfix "$F"
mkdir -p "$F/plugins/quality-gates/agents"
printf -- '---\nname: doc-recritic\n---\n갈라진 본문\n' > "$F/plugins/quality-gates/agents/doc-recritic.md"
O="$(scan "$F")"
assert_eq "$(kv COPY_NOT_DISPATCHED "$O")" "quality-gates:doc-recritic" \
  "마커를 뺀 같은 이름의 파일도 사본으로 센다 — 마커를 지워 빠져나가지 못한다"

F="$TMPD/fx-prose-bait"; mkfix "$F"
mkdir -p "$F/plugins/quality-gates/skills/q"
printf '%s\n' 'doc-recritic 를 부를 때는 subagent_type 필드에 플러그인 접두를 반드시 붙여야 한다.' \
  > "$F/plugins/quality-gates/skills/q/SKILL.md"
O="$(scan "$F")"
assert_eq "$(kv COPY_NOT_DISPATCHED "$O")$(kv DISPATCHED_NOT_COPIED "$O")" "" \
  "산문 속 «subagent_type ... doc-recritic» 동거는 디스패치가 아니다 — 사본 없는 qg 는 그대로 GREEN"

F="$TMPD/fx-unmarked-quoted"; mkfix "$F"
mkdir -p "$F/plugins/quality-gates/agents"
printf -- '---\nname: "doc-recritic"\n---\n갈라진 본문\n' > "$F/plugins/quality-gates/agents/doc-recritic.md"
O="$(scan "$F")"
assert_eq "$(kv COPY_NOT_DISPATCHED "$O")" "quality-gates:doc-recritic" \
  "따옴표로 감싼 name: 값도 마커 없이 사본으로 센다 — 따옴표로 빠져나가지 못한다"

finish
