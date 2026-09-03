#!/usr/bin/env bash
# guards: plugins/*/scripts/*.py plugins/*/hooks/*.py
#
# 원장이 «낸» 카운트를 소비자가 «읽는지» 검사한다.
#
# 요구 키는 Ledger 자신에게서 도출한다 — 여기 열거하면 어휘가 늘어도 락이
# 조용하고, 그 침묵이 이 락이 막으려는 바로 그것이다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

TMPD="$(mktemp -d -t adjcons-XXXXXX)" || exit 1
trap 'rm -rf "$TMPD"' EXIT

PYTHONDONTWRITEBYTECODE=1 python3 "$HERE/fixtures/adjudication/run_consumed.py" \
  "$REPO_ROOT" > "$TMPD/out.txt" 2>&1
OUT="$(cat "$TMPD/out.txt")"
note "$OUT"

note "── 판정기 자체 (fixture)"
assert_contains "$OUT" "fx_partial_missing=7" "held 만 읽는 소비자에서 나머지 일곱을 찾아낸다"
assert_contains "$OUT" "fx_full_missing=0"    "전부 읽는 소비자는 통과한다"

note "── 요구 키가 Ledger 에서 도출된다"
nkeys="$(printf '%s\n' "$OUT" | sed -n 's/^keys=//p')"
if [ "${nkeys:-0}" -ge 8 ] 2>/dev/null; then
  ok "요구 키 $nkeys 개 (카운트 7 + unknown_counts)"
else
  no "요구 키가 $nkeys 개다 — Ledger 도출이 깨졌으면 이 락 전체가 vacuous 하다"
fi

note "── 프로덕션 소비자"
nfiles="$(printf '%s\n' "$OUT" | sed -n 's/^consumers=//p')"
if [ "${nfiles:-0}" -gt 0 ] 2>/dev/null; then
  ok "소비자 $nfiles 개"
else
  no "소비자 도출이 0 이다 — 락이 vacuous 하다"
fi
unconsumed="$(printf '%s\n' "$OUT" | sed -n 's/^unconsumed_total=//p')"
assert_eq "$unconsumed" "0" "모든 소비자가 모든 카운트를 읽는다"

finish
