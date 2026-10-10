#!/usr/bin/env bash
# guards: plugins/*/.claude-plugin/plugin.json .claude-plugin/marketplace.json
#
# 쉬운 말 출력 설계 AC10 — 플러그인마다 plugin.json 과 마켓플레이스의 소개 문구가 글자까지 같다.
# 술어는 plugins/plugin-audit/scripts/check-staleness.py 의 scan_description_drift 와 같다
# (같은 name 의 description.strip() 등식). 대상은 열거하지 않고 디스크의 plugin.json 에서 도출한다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  git -C "$ROOT" ls-files -- 'plugins/*/.claude-plugin/plugin.json' .claude-plugin/marketplace.json
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
RES="$(mktemp -t desc-parity-XXXXXX)" || exit 1
[ -n "$RES" ] && [ -f "$RES" ] || exit 1
trap 'rm -f "$RES"' EXIT
python3 - "$ROOT" > "$RES" <<'PY'
import io, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
mp = json.load(io.open(str(root / ".claude-plugin/marketplace.json"), encoding="utf-8"))
by_name = {}
for p in mp.get("plugins", []):
    by_name[p.get("name")] = p
pjs = sorted(root.glob("plugins/*/.claude-plugin/plugin.json"))
print("count %d" % len(pjs))
seen = set()
for pj in pjs:
    d = json.load(io.open(str(pj), encoding="utf-8"))
    name = d.get("name")
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
n="$(sed -n 's/^count //p' "$RES")"
[ "${n:-0}" -ge 1 ] && ok "대상 plugin.json ${n}개를 디스크에서 도출했다" || no "대상 plugin.json 이 0개다 — 공허한 통과"
while IFS= read -r line; do
  case "$line" in
    "ok "*) ok "${line#ok }" ;;
    "no "*) no "${line#no }" ;;
  esac
done < "$RES"
finish
