#!/usr/bin/env bash
# guards: plugins/*/scripts/*.py plugins/*/hooks/*.py shared/adjudication/*.py tools/adjudication/check_consumed.py tools/adjudication/check_wiring.py shared/tests/fixtures/adjudication/run_consumed.py
#
# 수정 라운드 1 (F6) — 판정기 자신을 declare 한다. `fixtures/adjudication/
# run_consumed.py` 가 `from check_consumed import ...` 와 `from check_wiring
# import derive_consumers` 둘 다 쓰므로(소비자 모집단을 배선 판정기에서
# 빌린다) 이 락의 코퍼스는 둘이다 — import 로 도출했지 손으로 고르지 않았다.
#
# 수정 라운드 2 (I1) — `run_consumed.py` 자신(그 두 판정기를 «부르는» 러너)
# 은 F6 이후에도 빠져 있었다. F4 의 실제 결함 자리(러너의 print 루프)와
# 같은 종류 — 이 락이 유일한 소비자이므로 여기 편입한다.
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
#
# 폐포는 «파일 단위»다 — 호출 그래프를 안 본다. 공유 모듈의 어떤 함수가 키를
# 읽으면, 그 파일에서 «무엇이든» import 하는 소비자 전부가 그 키를 소비한
# 것으로 세어진다. 그 소비자가 실제로 부르는 함수가 그 키를 안 만져도 그렇다.
# 좁히려면 함수 단위 도달성 분석이 필요하고 그것은 또 하나의 오라클이다 —
# 이 락은 그것을 갖지 않는다고 밝힌다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

# `--emit-scanned` — test_guards_coverage_bidirectional.sh 가 읽는다. 코퍼스
# 도출은 run_consumed.py 안에 산다(판정기가 파이썬) — 셸에서 다시 구현하지
# 않고 같은 러너를 `--emit-scanned` 모드로 부른다.
if [ "${1:-}" = "--emit-scanned" ]; then
  PYTHONDONTWRITEBYTECODE=1 python3 "$HERE/fixtures/adjudication/run_consumed.py" \
    "$REPO_ROOT" --emit-scanned
  printf '%s\n' "tools/adjudication/check_consumed.py"
  printf '%s\n' "tools/adjudication/check_wiring.py"
  printf '%s\n' "shared/tests/fixtures/adjudication/run_consumed.py"
  exit 0
fi

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
