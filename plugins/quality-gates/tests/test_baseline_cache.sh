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

# /qg iter-1 (codex + silent-failure-hunter 가 각각 독립 실측): `error` 도 캐시하면
# 안 된다. `unrun` 을 뺀 근거("환경 상태에 달렸고 merge_base 의 함수가 아니다")가
# error 에 문자 그대로 적용된다 — OOM(137)·timeout(124)·권한(126)이 전부 error 버킷에
# 떨어지는데, 캐시 키에 TTL 도 환경 지문도 없어 한 번 얼면 그 unit 들의 진짜 HEAD
# 회귀를 브랜치 수명 내내 PRE_EXISTING 으로 가린다.
#
# 양의 짝(pass 는 여전히 캐시)이 함께 있어야 한다. 없으면 "아무것도 캐시하지 않는"
# mutation 이 GREEN 이 된다 — 이 리포가 이미 값을 치른 실패 모양.
#
# **관측을 get 이 아니라 캐시 파일로 하는 이유(실측):** get 도 error 행을 거르므로,
# get 출력으로 재면 put 이 error 를 쓰도록 되돌린 mutation 이 GREEN 이 된다 — 두 필터가
# 서로를 가린다. 이 케이스가 재려는 것은 **put 의 이빨**이므로 put 의 산출물을 직접 본다.
# (get 쪽 이빨은 아래 case_get_skips_legacy_error_row 가 따로 잰다.)
case_error_not_cached_pass_still_cached() {
  mkroot
  printf 'e.py\terror\t126\np.py\tpass\t0\n' | bash "$BC" put "$ROOT" "$SHA_A" pytest
  local f="$ROOT/${SHA_A:0:12}.md" body
  body=$(sed -n '4,$p' "$f")
  local has_err has_pass
  has_err=$(printf '%s\n' "$body" | grep -c "${TAB}error${TAB}" || true)
  has_pass=$(printf '%s\n' "$body" | grep -c "^pytest${TAB}p\.py${TAB}pass${TAB}0$" || true)
  if [[ "$has_err" == "0" && "$has_pass" == "1" ]]; then
    pass "put: error 행 미기록 · pass 행 기록(양의 짝) — 캐시 파일 직접 검사"
  else fail "put error 미캐시 (error행=$has_err pass행=$has_pass body='$body')"; fi
  rmroot
}

# 이 수정 **이전** 버전이 남긴 캐시에는 error 행이 이미 얼어 있고, 그것이 이 결함의
# 실제 피해다. put 만 고치면 기존 오염은 그대로 서빙되므로 get 도 미적중으로 떨어뜨려
# 스스로 낫게 한다. 단 read_valid_body 는 error 를 여전히 **유효 토큰**으로 봐야 한다 —
# 옛 캐시는 손상이 아니므로 파일 전체가 exit 4 로 버려지면 안 된다. 그래서 같은 파일의
# pass 행은 정상 적중해야 하고 종료코드는 0 이어야 한다.
case_get_skips_legacy_error_row() {
  mkroot
  printf '%s\nmerge_base: %s\n---\npytest\te.py\terror\t126\npytest\tp.py\tpass\t0\n' \
    '<!-- qg-baseline-cache:v1 -->' "$SHA_A" > "$ROOT/${SHA_A:0:12}.md"
  local out rc
  out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest e.py p.py | tr '\n' ';'); rc=$?
  if [[ "$rc" == "0" && "$out" == "p.py${TAB}pass${TAB}0;" ]]; then
    pass "레거시 error 행 미적중(재계산) · 같은 파일 pass 행 적중 · exit 0(손상 아님)"
  else fail "레거시 error 행 (rc=$rc out='$out')"; fi
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

# Not in the brief — added during self-review (coordinator round 3, Finding 1).
# `{ list; } > file` exits with the status of its LAST command, not whether the
# writes/redirect succeeded. The last statement inside put's write block is
# `[[ -n "$fresh" ]] && printf ...` — when $fresh is empty, that `&&` short-circuits
# to a false/1 exit status even though every printf before it succeeded and the file
# was written fine. The `||` error branch then fires, deletes the just-written tmp
# file, logs a FALSE "write failed", and exits 4 — on a normal, anticipated outcome
# (baseline setup failed for every requested unit is a first-class case the design
# names explicitly). Exercises all three ways a put's payload can normalize to
# empty: literally empty stdin, an all-`unrun` payload, and an all-malformed payload
# (no tabs / wrong field count). Revert the trailing `:` guard and this goes RED.
case_put_empty_payload_normalizes_to_empty_exits_zero() {
  mkroot; seed "$SHA_A" pytest   # a.py=pass/0, b.py=fail/1
  local rc out expect="a.py${TAB}pass${TAB}0;b.py${TAB}fail${TAB}1;"

  printf '' | bash "$BC" put "$ROOT" "$SHA_A" pytest 2>/dev/null; rc=$?
  out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py b.py | tr '\n' ';')
  if [[ $rc -eq 0 && "$out" == "$expect" ]]; then
    pass "빈 stdin put → exit 0 + 기존 행 보존"
  else fail "빈 stdin put (rc=$rc out='$out')"; fi

  printf 'c.py\tunrun\t-\n' | bash "$BC" put "$ROOT" "$SHA_A" pytest 2>/dev/null; rc=$?
  out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py b.py | tr '\n' ';')
  if [[ $rc -eq 0 && "$out" == "$expect" ]]; then
    pass "전량 unrun payload → exit 0 + 기존 행 보존"
  else fail "전량 unrun payload (rc=$rc out='$out')"; fi

  printf 'z.py\tbogus\t0\nnotabs\n' | bash "$BC" put "$ROOT" "$SHA_A" pytest 2>/dev/null; rc=$?
  out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py b.py | tr '\n' ';')
  if [[ $rc -eq 0 && "$out" == "$expect" ]]; then
    pass "전량 malformed payload → exit 0 + 기존 행 보존"
  else fail "전량 malformed payload (rc=$rc out='$out')"; fi

  rmroot
}

# Not in the brief — added during self-review (coordinator round 3, Finding 2). The
# 0-vs-4 distinction is get's whole contract (0 = normal including zero hits, 4 =
# corrupt/loud). No existing case pinned exit 0 for the "no cache file at all yet"
# path distinctly from the corrupt-file exit-4 cases — every fixture piped stderr
# away and only counted stdout lines, so a mutation that deletes the `[[ -f "$f" ]]`
# branch (making every read_valid_body failure exit 4, missing file included) leaves
# stdout empty in every existing case and slips through.
case_get_missing_cache_file_exits_zero() {
  mkroot   # cache ROOT exists (mktemp -d) but no .md was ever put for this merge_base
  local out rc
  out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py 2>/dev/null); rc=$?
  if [[ $rc -eq 0 && -z "$out" ]]; then
    pass "캐시 파일 부재 → exit 0 + 무출력 (손상의 exit 4와 구분)"
  else fail "캐시 파일 부재 (rc=$rc out='$out')"; fi
  rmroot
}

# Not in the brief — added during self-review (coordinator round 3, Minor 5). Every
# other fixture pre-creates the cache root via mkroot's `mktemp -d`, so put's
# `mkdir -p "$root"` on a genuinely non-existent root was never exercised.
case_put_creates_nonexistent_cache_root() {
  local parent; parent=$(mktemp -d) || exit 1
  ROOT="$parent/nested/cache-root"   # deliberately absent — put must mkdir -p it
  local rc out
  printf 'a.py\tpass\t0\n' | bash "$BC" put "$ROOT" "$SHA_A" pytest; rc=$?
  out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py)
  if [[ $rc -eq 0 && -d "$ROOT" && "$out" == "a.py${TAB}pass${TAB}0" ]]; then
    pass "존재하지 않는 cache-root → mkdir -p 후 정상 기록·조회"
  else fail "cache-root 최초 생성 (rc=$rc out='$out')"; fi
  cd / && rm -rf "$parent"
  ROOT=""
}

for c in case_key_includes_merge_base case_key_includes_runner case_get_full_hit \
         case_get_partial_hit case_get_corrupt_header case_get_corrupt_body \
         case_get_merge_base_mismatch case_put_atomic \
         case_unrun_not_cached_absent_cached \
         case_error_not_cached_pass_still_cached case_get_skips_legacy_error_row \
         case_bulk_key_isolation \
         case_put_merge_preserves_other_runner \
         case_put_partial_preserves_uninvolved_units_same_runner \
         case_put_partial_overwrites_matching_unit_preserves_others \
         case_put_empty_payload_normalizes_to_empty_exits_zero \
         case_get_missing_cache_file_exits_zero \
         case_put_creates_nonexistent_cache_root; do
  echo "== $c"; $c
done
echo "── baseline-cache: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
