#!/usr/bin/env bash
# guards: plugins/*/.claude-plugin/plugin.json .claude-plugin/marketplace.json
#
# 쉬운 말 출력 설계 AC10 — 플러그인마다 plugin.json 과 마켓플레이스의 소개 문구가 글자까지 같다.
# 술어는 plugins/plugin-audit/scripts/check-staleness.py 의 scan_description_drift 와 같다
# (같은 name 의 description.strip() 등식). 대상은 열거하지 않고 디스크의 plugin.json 에서 도출한다.
# 읽을 수 없는 plugin.json · 중복 name · 검사기 자신의 실패는 통과가 아니라 RED 다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  git -C "$ROOT" ls-files -- 'plugins/*/.claude-plugin/plugin.json' .claude-plugin/marketplace.json
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
TMPD="$(mktemp -d -t desc-parity-XXXXXX)" || exit 1
[ -n "$TMPD" ] && [ -d "$TMPD" ] || exit 1
trap 'rm -rf "$TMPD"' EXIT

# scan_tree <루트> — 「ok <메시지>」/「no <메시지>」 줄을 낸다. 검사기가 실패하거나 줄 수가 안 맞으면 no 를 낸다.
scan_tree() {
  local root="$1" res="$TMPD/scan.$$" rc n total
  python3 - "$root" > "$res" 2> "$res.err" <<'PY'
import io, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
mp = json.load(io.open(str(root / ".claude-plugin/marketplace.json"), encoding="utf-8"))
by_name = {}
dups = set()
for p in mp.get("plugins", []):
    if p.get("name") in by_name:
        dups.add(p.get("name"))
    by_name[p.get("name")] = p
pjs = sorted(root.glob("plugins/*/.claude-plugin/plugin.json"))
print("count %d" % len(pjs))
for name in sorted(dups):
    print("no %s: 마켓플레이스에 같은 이름의 항목이 둘 이상이다" % name)
seen = set()
for pj in pjs:
    rel = pj.relative_to(root).as_posix()
    try:
        d = json.load(io.open(str(pj), encoding="utf-8"))
        name = d.get("name")
    except Exception as e:
        print("no %s: JSON 을 읽을 수 없다(%s)" % (rel, str(e).replace("\n", " ")))
        continue
    seen.add(name)
    m = by_name.get(name)
    if m is None:
        print("no %s: 마켓플레이스에 항목이 없다" % name)
    elif not (d.get("description") or "").strip():
        print("no %s: plugin.json 에 소개 문구가 없다" % name)
    elif (d.get("description") or "").strip() != (m.get("description") or "").strip():
        print("no %s: plugin.json 과 마켓플레이스 소개 문구가 다르다" % name)
    else:
        print("ok %s: 소개 문구가 글자까지 같다" % name)
for name in sorted(n for n in by_name if n not in seen):
    print("no %s: 마켓플레이스 항목에 맞는 plugin.json 이 없다" % name)
PY
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "no 검사기(python)가 실패했다 rc=${rc}: $(tail -n 1 "$res.err")"
    return 0
  fi
  n="$(sed -n 's/^count //p' "$res")"
  total="$(grep -c -E '^(ok|no) ' "$res")"
  [ "${n:-0}" -ge 1 ] || echo "no 대상 plugin.json 이 0개다 — 공허한 통과"
  grep -E '^(ok|no) ' "$res"
  [ "${total:-0}" -ge "${n:-0}" ] || echo "no 검사 결과 줄(${total})이 대상 수(${n})보다 적다 — 빠진 대상이 있다"
  return 0
}

out="$(scan_tree "$ROOT")"
n="$(grep -c -E '^(ok|no) ' <<<"$out")"
ok "디스크의 plugin.json 에서 대상을 도출해 ${n}줄을 잰다"
while IFS= read -r line; do
  case "$line" in
    "ok "*) ok "${line#ok }" ;;
    "no "*) no "${line#no }" ;;
  esac
done <<<"$out"

# 자체 점검 — 합성 트리에서 검사기가 RED 를 내는지 (통과만 보는 락은 이빨이 없다)
mk_tree() {  # mk_tree <이름> — 마켓플레이스에 a · b 가 있고 둘의 소개 문구가 같은 트리
  local d="$TMPD/$1"
  mkdir -p "$d/.claude-plugin" "$d/plugins/a/.claude-plugin" "$d/plugins/b/.claude-plugin"
  printf '{"plugins":[{"name":"a","description":"da"},{"name":"b","description":"db"}]}\n' > "$d/.claude-plugin/marketplace.json"
  printf '{"name":"a","description":"da"}\n' > "$d/plugins/a/.claude-plugin/plugin.json"
  printf '{"name":"b","description":"db"}\n' > "$d/plugins/b/.claude-plugin/plugin.json"
  printf '%s' "$d"
}
t="$(mk_tree good)"
assert_not_contains "$(scan_tree "$t")" "no " "자체 점검: 멀쩡한 합성 트리는 RED 가 없다"
t="$(mk_tree broken)"
printf '{"name":"b","descr' > "$t/plugins/b/.claude-plugin/plugin.json"
assert_contains "$(scan_tree "$t")" "JSON 을 읽을 수 없다" "자체 점검: 깨진 plugin.json 은 RED 다"
t="$(mk_tree dup)"
printf '{"plugins":[{"name":"a","description":"da"},{"name":"a","description":"da"},{"name":"b","description":"db"}]}\n' > "$t/.claude-plugin/marketplace.json"
assert_contains "$(scan_tree "$t")" "같은 이름의 항목이 둘 이상" "자체 점검: 마켓플레이스 중복 이름은 RED 다"
t="$(mk_tree crash)"
printf '{"plugins":[' > "$t/.claude-plugin/marketplace.json"
assert_contains "$(scan_tree "$t")" "검사기(python)가 실패했다" "자체 점검: 검사기가 죽으면 RED 다"
finish
