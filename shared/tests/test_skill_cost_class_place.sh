#!/usr/bin/env bash
# guards: plugins/*/skills/*/SKILL.md shared/entry/check_invocation_surface.py
# skill 의 cost_class 는 frontmatter `metadata` 아래에 둔다(CLAUDE.md 컴포넌트 격리).
#  (가) 모든 SKILL.md — metadata 아래 값이 있고 맨 위 cost_class 줄이 없다. 이름 붙인 skill 은 값이 옮기기 전과 같다.
#  (나) 호출 표면 검사 — 맨 위 cost_class 는 모르는 키, metadata 는 받는다.
#  (다) frontmatter 에 disallowed-tools 를 쓰는 skill 은 0 이다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOCK="$ROOT/shared/entry/check_invocation_surface.py"
if [ "${1:-}" = "--emit-scanned" ]; then
  git -C "$ROOT" ls-files -- 'plugins/*/skills/*/SKILL.md'
  printf '%s\n' shared/entry/check_invocation_surface.py
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
TMP="$(mktemp -d "${TMPDIR:-/tmp}/cc-place.XXXXXX")" || { no "mktemp 실패"; finish; exit 1; }
[ -n "$TMP" ] && [ -d "$TMP" ] || { no "임시 디렉토리가 없다"; finish; exit 1; }
trap 'rm -rf "$TMP"' EXIT

# place <파일> — 「top=<0|1> meta=<값|-> dis=<0|1>」. frontmatter 는 첫 줄 --- 부터 다음 --- 앞까지.
place() {
  python3 -I - "$1" <<'PY'
import re, sys
lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
fm = []
if lines and lines[0] == "---":
    for ln in lines[1:]:
        if ln == "---":
            break
        fm.append(ln)
top = any(re.match(r"cost_class:", ln) for ln in fm)
dis = any(re.match(r"disallowed-tools:", ln) for ln in fm)
meta, inside, width = "-", False, None
for ln in fm:
    if re.match(r"metadata:[ \t]*$", ln):
        inside, width = True, None
        continue
    if not inside or not ln.strip():
        continue
    if not ln[0].isspace():
        inside = False
        continue
    indent = len(ln) - len(ln.lstrip(" \t"))
    if width is None:
        width = indent
    m = re.match(r"cost_class:[ \t]*(\S+)[ \t]*$", ln.lstrip(" \t"))
    if indent == width and m:
        meta = m.group(1)
print("top=%d meta=%s dis=%d" % (top, meta, dis))
PY
}

# ── 계측기 양성 대조 ──
printf -- '---\nname: x\ncost_class: high\n---\n' > "$TMP/s_top.md"
printf -- '---\nname: x\nmetadata:\n  cost_class: high\n---\n' > "$TMP/s_meta.md"
printf -- '---\nname: x\nhooks:\n  cost_class: high\n---\n' > "$TMP/s_other.md"
printf -- '---\nname: x\n---\nmetadata:\n  cost_class: high\n' > "$TMP/s_body.md"
printf -- '---\nname: x\nmetadata:\n  a: 1\nhooks:\n  cost_class: high\n---\n' > "$TMP/s_after.md"
assert_eq "$(place "$TMP/s_top.md")"   "top=1 meta=- dis=0"    "대조: 맨 위 cost_class 를 맨 위로 읽는다"
assert_eq "$(place "$TMP/s_meta.md")"  "top=0 meta=high dis=0" "대조: metadata 아래 값을 읽는다"
assert_eq "$(place "$TMP/s_other.md")" "top=0 meta=- dis=0"    "대조: 다른 키 아래 들여쓴 cost_class 는 선언이 아니다"
assert_eq "$(place "$TMP/s_body.md")"  "top=0 meta=- dis=0"    "대조: 본문의 같은 글자는 frontmatter 가 아니다"
assert_eq "$(place "$TMP/s_after.md")" "top=0 meta=- dis=0"    "대조: metadata 블록은 들여쓰지 않은 다음 키에서 닫힌다"
printf -- '---\nname: x\nmetadata:\n  inner:\n    cost_class: high\n---\n' > "$TMP/s_deep.md"
printf -- '---\nname: x\ndisallowed-tools: Bash\n---\n' > "$TMP/s_dis.md"
assert_eq "$(place "$TMP/s_deep.md")"  "top=0 meta=- dis=0"    "대조: metadata 아래 더 깊이 들여쓴 cost_class 는 직속 자식이 아니다"
assert_eq "$(place "$TMP/s_dis.md")"   "top=0 meta=- dis=1"    "대조: disallowed-tools 줄을 읽는다"

# ── (가) 실제 skill 전부 ──
n=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  n=$((n + 1))
  got="$(place "$ROOT/$f")"
  case "${got% dis=*}" in
    "top=0 meta=low"|"top=0 meta=medium"|"top=0 meta=high"|"top=0 meta=variable") ok "(가) $f: ${got% dis=*}" ;;
    *) no "(가) $f: metadata 아래 cost_class(low|medium|high|variable)가 없거나 맨 위 줄이 남았다 — $got" ;;
  esac
  case "$got" in
    *" dis=0") ok "(다) $f: disallowed-tools 없음" ;;
    *) no "(다) $f: frontmatter 에 disallowed-tools 가 있다 — $got. 이 단언은 에픽 시점(AC7)의 스냅샷이다(지금 이 키를 쓰는 skill 은 없다). 금지가 아니니, 쓰기 시작하는 PR 이 이 단언을 함께 고친다" ;;
  esac
done < <(git -C "$ROOT" ls-files -- 'plugins/*/skills/*/SKILL.md')
[ "$n" -ge 10 ] && ok "(가) 도출: SKILL.md ${n}개" || no "(가) 도출: SKILL.md 가 ${n}개뿐이다 — 도출이 무너졌다"
while read -r f v; do
  assert_eq "$(place "$ROOT/$f")" "top=0 meta=$v dis=0" "(가) 값 그대로: $f = $v"
done <<'EOF'
plugins/plugin-audit/skills/plugin-audit/SKILL.md high
plugins/project-init/skills/project-init/SKILL.md low
plugins/quality-gates/skills/artifact-critique/SKILL.md variable
plugins/quality-gates/skills/quality-pipeline/SKILL.md variable
plugins/spec-distill/skills/epic-conductor/SKILL.md high
plugins/spec-distill/skills/context-build/SKILL.md variable
plugins/spec-distill/skills/intent-sync/SKILL.md variable
plugins/spec-distill/skills/reviewing-brief/SKILL.md medium
plugins/spec-distill/skills/roadmap-status/SKILL.md low
plugins/spec-distill/skills/spec-review/SKILL.md medium
EOF

# ── (나) 호출 표면 검사 ──
mk() {   # mk <dir> <frontmatter 가운데 줄들>
  mkdir -p "$1/plugins/zz/skills/zz-yy"
  printf -- '---\nname: zz-yy\ndescription: x\n%s---\n\nbody\n' "$2" > "$1/plugins/zz/skills/zz-yy/SKILL.md"
  git init -q "$1"
}
e_lines() { python3 "$LOCK" --root "$1" 2>&1 | grep '^RED E plugins/zz/skills/zz-yy/SKILL.md' || true; }
mk "$TMP/r-top" 'cost_class: high
'
mk "$TMP/r-meta" 'metadata:
  cost_class: high
'
E_TOP="$(e_lines "$TMP/r-top")"; E_META="$(e_lines "$TMP/r-meta")"
assert_contains "$E_TOP" "'cost_class'" "(나) 맨 위 cost_class 를 모르는 키로 낸다"
assert_not_contains "$E_TOP" '∪' "(나) 메시지에 「∪ {cost_class}」 가 없다"
assert_eq "$E_META" "" "(나) metadata 아래 cost_class 는 축 E 에 걸리지 않는다"
assert_not_contains "$(cat "$LOCK")" '∪ {cost_class}' "(나) 검사 파일의 주석 · 메시지에 「∪ {cost_class}」 가 없다"

finish
