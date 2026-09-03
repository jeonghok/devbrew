#!/usr/bin/env bash
# guards: plugins/*/scripts/*.py plugins/*/hooks/*.py
#
# 원장이 «낸» 카운트를 소비자가 «읽는지» 검사한다.
#
# 요구 키는 Ledger 자신에게서 도출한다 — 여기 열거하면 어휘가 늘어도 락이
# 조용하고, 그 침묵이 이 락이 막으려는 바로 그것이다.
#
# 코퍼스는 소비자 파일 «하나»가 아니라 그 파일 + 그것이 import 하는
# `shared/adjudication/` 모듈들이다. 네 소비자가 같은 두 줄을 내려고 공유 렌더
# 모듈을 두는 것이 설계라, 파일 하나만 보면 설계를 따르는 것이 곧 위반이 된다.
#
# **이 락이 못 보는 것**: 키 이름이 렌더 코드에 «적혀 있다»는 것이지 그 값이
# 사용자 화면까지 «간다»는 것이 아니다. 후자는 결정론 fixture 의 처분 행렬과
# 라이브 렌더 1회가 잰다(설계 M11·M12).
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
assert_contains "$OUT" "fx_dictkey_missing=8" \
  "딕셔너리 리터럴 «키»는 소비가 아니다 — 같은 이름의 무관한 지역 변수가 락을 만족시키지 않는다"

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
