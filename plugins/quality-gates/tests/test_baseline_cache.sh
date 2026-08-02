#!/usr/bin/env bash
# test_baseline_cache.sh — scripts/baseline-cache.sh (design §5.4).
# AC8 AC32 AC33 AC40(cache) AC42 · T6 T23 T24 T36b T38 · M7 M13 M18
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
BC="$PLUGIN_ROOT/scripts/baseline-cache.sh"
TAB=$'\t'
SHA_A=1111111111111111111111111111111111111111
SHA_B=2222222222222222222222222222222222222222

PASS=0; FAIL=0; ROOT=""
pass() { PASS=$((PASS + 1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }
mkroot() { ROOT=$(mktemp -d) || exit 1; }
rmroot() { cd / && rm -rf "$ROOT"; }
seed() {   # seed <sha> <runner> — a=pass, b=fail
  printf 'a.py\tpass\t0\nb.py\tfail\t1\n' | bash "$BC" put "$ROOT" "$1" "$2"
}

# T6 + M7 + AC8: merge_base가 바뀌면 미적중
case_key_includes_merge_base() {
  mkroot; seed "$SHA_A" pytest
  local hit miss
  hit=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py b.py | wc -l | tr -d ' ')
  miss=$(bash "$BC" get "$ROOT" "$SHA_B" pytest a.py b.py 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$hit" == "2" && "$miss" == "0" ]]; then
    pass "같은 merge_base 적중 2 / 다른 merge_base 적중 0"
  else fail "merge_base 키 (hit=$hit miss=$miss)"; fi
  rmroot
}

# 같은 merge_base라도 runner가 다르면 미적중 (캐시 키 3요소)
case_key_includes_runner() {
  mkroot; seed "$SHA_A" pytest
  local n; n=$(bash "$BC" get "$ROOT" "$SHA_A" shell a.py | wc -l | tr -d ' ')
  [[ "$n" == "0" ]] && pass "runner가 다르면 미적중" || fail "runner 키 ($n)"
  rmroot
}

# T23-a: 전량 적중 — 값까지 정확히
case_get_full_hit() {
  mkroot; seed "$SHA_A" pytest
  local out; out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py b.py | tr '\n' ';')
  [[ "$out" == "a.py${TAB}pass${TAB}0;b.py${TAB}fail${TAB}1;" ]] \
    && pass "전량 적중 → 값 보존" || fail "전량 적중 (got: $out)"
  rmroot
}

# T23-b: 부분 적중 — **적중분만** emit (미적중 unit은 무출력)
case_get_partial_hit() {
  mkroot; seed "$SHA_A" pytest
  local out; out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py zzz.py | tr '\n' ';')
  [[ "$out" == "a.py${TAB}pass${TAB}0;" ]] \
    && pass "부분 적중 → 적중분만 출력" || fail "부분 적중 (got: $out)"
  rmroot
}

# T23-c + M13 + AC32: 헤더 손상 → exit 4 + **무출력** (부분 파싱해서 일부를 적중으로 내지 않는다)
case_get_corrupt_header() {
  mkroot; seed "$SHA_A" pytest
  local f; f=$(ls "$ROOT"/*.md | head -1)
  printf 'GARBAGE\nmerge_base: %s\n---\npytest\ta.py\tpass\t0\n' "$SHA_A" > "$f"
  local out rc; out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py 2>/dev/null); rc=$?
  if [[ $rc -eq 4 && -z "$out" ]]; then pass "헤더 손상 → exit 4 + 무출력"
  else fail "헤더 손상 (rc=$rc out='$out')"; fi
  rmroot
}

# T23-c(2): 본문 행 손상(필드 수 불일치)도 전량 미적중 — 반쯤 신뢰한 캐시가
# 조용히 틀린 귀속을 만든다.
case_get_corrupt_body() {
  mkroot; seed "$SHA_A" pytest
  local f; f=$(ls "$ROOT"/*.md | head -1)
  printf '<!-- qg-baseline-cache:v1 -->\nmerge_base: %s\n---\npytest\ta.py\tpass\n' "$SHA_A" > "$f"
  local out rc; out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py 2>/dev/null); rc=$?
  if [[ $rc -eq 4 && -z "$out" ]]; then pass "본문 행 손상 → exit 4 + 무출력"
  else fail "본문 손상 (rc=$rc out='$out')"; fi
  rmroot
}

# T23-d: 파일명은 맞는데 본문 merge_base가 다름 (short-sha 충돌) → 무출력
case_get_merge_base_mismatch() {
  mkroot; seed "$SHA_A" pytest
  local f; f=$(ls "$ROOT"/*.md | head -1)
  printf '<!-- qg-baseline-cache:v1 -->\nmerge_base: %s\n---\npytest\ta.py\tpass\t0\n' "$SHA_B" > "$f"
  local out rc; out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py 2>/dev/null); rc=$?
  if [[ $rc -eq 4 && -z "$out" ]]; then pass "본문 merge_base 불일치 → 무출력"
  else fail "sha 불일치 (rc=$rc out='$out')"; fi
  rmroot
}

# T24 + AC33: 원자적 쓰기 — 임시파일 + rename, 중단 시 부분 파일 부재
case_put_atomic() {
  mkroot; seed "$SHA_A" pytest
  if grep -qE 'mv[[:space:]]' "$BC" && grep -qE '\.tmp' "$BC"; then
    pass "put이 tmp + mv rename 사용"
  else fail "원자적 쓰기 코드 부재"; fi
  local strays; strays=$(find "$ROOT" -name '*.tmp*' | wc -l | tr -d ' ')
  [[ "$strays" == "0" ]] && pass "put 후 임시파일 잔존 0" || fail "임시파일 $strays개 잔존"
  rmroot
}

# T36b + AC40: `unrun`은 캐시에 안 들어가고 `absent`는 들어간다
case_unrun_not_cached_absent_cached() {
  mkroot
  printf 'x.py\tunrun\t-\ny.py\tabsent\t-\n' | bash "$BC" put "$ROOT" "$SHA_A" pytest
  local out; out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest x.py y.py | tr '\n' ';')
  [[ "$out" == "y.py${TAB}absent${TAB}-;" ]] \
    && pass "unrun 미캐시 · absent 캐시" || fail "unrun/absent (got: $out)"
  rmroot
}

# T38 + M18 + AC42: `BULK` 키는 granularity=bulk에서만 생긴다.
# file-granularity의 bulk-green은 호출자가 unit별 pass 행으로 분해해 put하므로
# 캐시에 BULK 키가 남으면 안 된다. 캐시는 받은 것을 그대로 저장하되,
# **BULK 키와 unit 키가 같은 (merge_base, runner)에 공존하면 loud advisory**를 낸다.
case_bulk_key_isolation() {
  mkroot
  printf 'BULK\tpass\t0\n' | bash "$BC" put "$ROOT" "$SHA_A" cargo
  local out; out=$(bash "$BC" get "$ROOT" "$SHA_A" cargo BULK | tr '\n' ';')
  [[ "$out" == "BULK${TAB}pass${TAB}0;" ]] && pass "bulk 어댑터 → BULK 키 정상" || fail "BULK 키 ($out)"
  local err
  printf 'BULK\tpass\t0\na.py\tpass\t0\n' | bash "$BC" put "$ROOT" "$SHA_A" pytest 2>"$ROOT/e.txt"
  err=$(cat "$ROOT/e.txt")
  printf '%s' "$err" | grep -q 'BULK' \
    && pass "file-granularity 러너에 BULK 혼입 → loud advisory" \
    || fail "BULK 혼입 무경고"
  rmroot
}

# 부분 적중 병합: 같은 키에 새 값이 오면 새 값이 이기고, 다른 runner의 행은 보존
case_put_merge_preserves_other_runner() {
  mkroot; seed "$SHA_A" pytest
  printf 'z.sh\tpass\t0\n' | bash "$BC" put "$ROOT" "$SHA_A" shell
  local n1 n2
  n1=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py b.py | wc -l | tr -d ' ')
  n2=$(bash "$BC" get "$ROOT" "$SHA_A" shell z.sh | wc -l | tr -d ' ')
  [[ "$n1" == "2" && "$n2" == "1" ]] \
    && pass "다른 runner put이 기존 행을 보존" || fail "병합 (pytest=$n1 shell=$n2)"
  printf 'a.py\tfail\t1\n' | bash "$BC" put "$ROOT" "$SHA_A" pytest
  local out; out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py)
  [[ "$out" == "a.py${TAB}fail${TAB}1" ]] \
    && pass "같은 키 재기록 → 새 값이 이김" || fail "키 충돌 (got: $out)"
  rmroot
}

# Not in the brief — added during self-review. task-11-brief.md §R4③ shows the
# orchestrator's real put payload is only the miss-set (units re-run in the baseline
# worktree), never the runner's full unit set: a later /qg run at the SAME merge_base
# can select a different impacted-unit subset (new commits, no rebase) and only the
# newly-missed units get put. A same-runner "wipe section, write payload" merge would
# silently evict previously-cached, still-valid units that just weren't touched by
# this call — breaking the "amortize to once per merge_base" guarantee the whole
# component exists to provide. This is a correctness-of-purpose bug, not just an
# untested edge case: revert the (runner,unit)-keyed merge back to a runner-only wipe
# and this goes RED.
case_put_partial_preserves_uninvolved_units_same_runner() {
  mkroot; seed "$SHA_A" pytest   # caches a.py=pass, b.py=fail for pytest
  # A later run at the same merge_base only re-runs (and puts) c.py for pytest —
  # a.py/b.py are untouched cache hits, not part of this put's payload.
  printf 'c.py\tpass\t0\n' | bash "$BC" put "$ROOT" "$SHA_A" pytest
  local out; out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py b.py c.py | tr '\n' ';')
  [[ "$out" == "a.py${TAB}pass${TAB}0;b.py${TAB}fail${TAB}1;c.py${TAB}pass${TAB}0;" ]] \
    && pass "부분 payload put이 같은 runner의 미포함 unit을 보존" \
    || fail "부분 payload put이 미포함 unit을 지움 (got: $out)"
  rmroot
}

# Not in the brief — added during self-review (coordinator round 2). The
# (runner,unit)-keyed preservation fix above must not regress the pre-existing
# "same key, new value wins" contract (case_put_merge_preserves_other_runner) into
# "never overwrite on collision." This exercises BOTH properties in a single put
# call: a.py is already cached and is ALSO present in this call's payload with a
# different status (must overwrite), while b.py is cached and NOT in this call's
# payload (must be preserved unchanged).
case_put_partial_overwrites_matching_unit_preserves_others() {
  mkroot; seed "$SHA_A" pytest   # a.py=pass/0, b.py=fail/1
  printf 'a.py\tfail\t9\n' | bash "$BC" put "$ROOT" "$SHA_A" pytest
  local out; out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py b.py | tr '\n' ';')
  [[ "$out" == "a.py${TAB}fail${TAB}9;b.py${TAB}fail${TAB}1;" ]] \
    && pass "충돌 키는 새 값이 이기고 미포함 키는 보존 (동시 성립)" \
    || fail "충돌+보존 동시성 (got: $out)"
  rmroot
}

for c in case_key_includes_merge_base case_key_includes_runner case_get_full_hit \
         case_get_partial_hit case_get_corrupt_header case_get_corrupt_body \
         case_get_merge_base_mismatch case_put_atomic \
         case_unrun_not_cached_absent_cached case_bulk_key_isolation \
         case_put_merge_preserves_other_runner \
         case_put_partial_preserves_uninvolved_units_same_runner \
         case_put_partial_overwrites_matching_unit_preserves_others; do
  echo "== $c"; $c
done
echo "── baseline-cache: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
