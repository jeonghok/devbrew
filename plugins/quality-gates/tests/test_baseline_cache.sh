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

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
ROOT=""
mkroot() { ROOT=$(mktemp -d) || exit 1; }
rmroot() { cd / && rm -rf "$ROOT"; }
seed() {   # seed <sha> <runner> — a=pass, b=fail
  printf 'a.py\tpass\t0\nb.py\tfail\t1\n' | bash "$BC" put "$ROOT" "$1" "$2"
}

# v3.0.0 이후 `get` 은 **적중 집합에서 `fail` 을 뺀다**(재검증 — 심어지거나 낡은 fail 만
# 결함을 숨길 수 있고, pass/absent 의 오류 방향은 fail-closed 다). 그래서 put 이 무엇을
# **저장**했는지는 get 으로 관측할 수 없다 — 두 필터가 서로를 가린다(error 케이스에서
# 실측한 그 모양). 저장 의미론(병합·보존·덮어쓰기)을 재는 케이스는 파일을 직접 본다.
body_of() { sed -n '4,$p' "$ROOT/${1:0:12}.md"; }   # body_of <sha> → runner\tunit\tstatus\texit
row_of()  {   # row_of <sha> <runner> <unit> → "status/exit" (없으면 빈 문자열)
  body_of "$1" | awk -F'\t' -v r="$2" -v u="$3" '$1==r && $2==u { print $3"/"$4 }'
}
rows_of() {   # rows_of <sha> <runner> → "unit=status;..." (정렬)
  body_of "$1" | awk -F'\t' -v r="$2" '$1==r { print $2"="$3 }' | sort | tr '\n' ';'
}

# T6 + M7 + AC8: merge_base가 바뀌면 미적중.
# seed 는 a.py=pass, b.py=fail 을 넣지만 적중은 a.py 하나다 — v3.0.0 부터 `fail` 은
# 적중 집합에서 빠진다(재검증, case_get_full_hit 참조). 이 케이스가 재는 것은 **키**이고,
# 1 대 0 의 대비는 그대로다: get 이 아무것도 안 내주는 mutation 은 hit=0 으로,
# merge_base 를 무시하는 mutation 은 miss=1 로 각각 빨개진다.
case_key_includes_merge_base() {
  mkroot; seed "$SHA_A" pytest
  local hit miss
  hit=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py b.py | wc -l | tr -d ' ')
  miss=$(bash "$BC" get "$ROOT" "$SHA_B" pytest a.py b.py 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$hit" == "1" && "$miss" == "0" ]]; then
    ok "같은 merge_base 적중 1(pass 만) / 다른 merge_base 적중 0"
  else no "merge_base 키 (hit=$hit miss=$miss)"; fi
  rmroot
}

# 같은 merge_base라도 runner가 다르면 미적중 (캐시 키 3요소)
case_key_includes_runner() {
  mkroot; seed "$SHA_A" pytest
  local n; n=$(bash "$BC" get "$ROOT" "$SHA_A" shell a.py | wc -l | tr -d ' ')
  [[ "$n" == "0" ]] && ok "runner가 다르면 미적중" || no "runner 키 ($n)"
  rmroot
}

# T23-a: 적중은 값까지 보존 — 단 `fail` 은 적중 집합에서 빠진다(재검증).
# /qg iter-1 CRITICAL: 캐시는 verifier 가 쓸 수 있는 경로에 있고 봉인이 없다. 심어진
# `fail` 행은 (F,F)=PRE_EXISTING 으로 진짜 회귀를 숨기고, 전량 적중이면 기준선 워크트리
# 자체가 만들어지지 않아 기준선 테스트가 **하나도 돌지 않는다**. 봉인 대신 방향
# 비대칭을 쓴다 — pass/absent 는 틀려도 결함으로 뜨지만(fail-closed) fail 은 숨긴다.
case_get_full_hit() {
  mkroot; seed "$SHA_A" pytest
  local out; out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py b.py | tr '\n' ';')
  [[ "$out" == "a.py${TAB}pass${TAB}0;" ]] \
    && ok "pass 는 값까지 보존해 적중 · fail 은 미적중(재검증)" \
    || no "적중 집합 (got: $out)"
  # 양의 짝: 저장 자체는 되어야 한다. 이게 없으면 "put 이 fail 을 아예 안 쓰는"
  # mutation 과 구분되지 않는다.
  [[ "$(row_of "$SHA_A" pytest b.py)" == "fail/1" ]] \
    && ok "fail 은 파일에 저장은 됨(적중에서만 제외)" \
    || no "fail 저장 (row: '$(row_of "$SHA_A" pytest b.py)')"
  rmroot
}

# T23-b: 부분 적중 — **적중분만** emit (미적중 unit은 무출력)
case_get_partial_hit() {
  mkroot; seed "$SHA_A" pytest
  local out; out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py zzz.py | tr '\n' ';')
  [[ "$out" == "a.py${TAB}pass${TAB}0;" ]] \
    && ok "부분 적중 → 적중분만 출력" || no "부분 적중 (got: $out)"
  rmroot
}

# T23-c + M13 + AC32: 헤더 손상 → exit 4 + **무출력** (부분 파싱해서 일부를 적중으로 내지 않는다)
case_get_corrupt_header() {
  mkroot; seed "$SHA_A" pytest
  local f; f=$(ls "$ROOT"/*.md | head -1)
  printf 'GARBAGE\nmerge_base: %s\n---\npytest\ta.py\tpass\t0\n' "$SHA_A" > "$f"
  local out rc; out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py 2>/dev/null); rc=$?
  if [[ $rc -eq 4 && -z "$out" ]]; then ok "헤더 손상 → exit 4 + 무출력"
  else no "헤더 손상 (rc=$rc out='$out')"; fi
  rmroot
}

# T23-c(2): 본문 행 손상(필드 수 불일치)도 전량 미적중 — 반쯤 신뢰한 캐시가
# 조용히 틀린 귀속을 만든다.
case_get_corrupt_body() {
  mkroot; seed "$SHA_A" pytest
  local f; f=$(ls "$ROOT"/*.md | head -1)
  printf '<!-- qg-baseline-cache:v1 -->\nmerge_base: %s\n---\npytest\ta.py\tpass\n' "$SHA_A" > "$f"
  local out rc; out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py 2>/dev/null); rc=$?
  if [[ $rc -eq 4 && -z "$out" ]]; then ok "본문 행 손상 → exit 4 + 무출력"
  else no "본문 손상 (rc=$rc out='$out')"; fi
  rmroot
}

# T23-d: 파일명은 맞는데 본문 merge_base가 다름 (short-sha 충돌) → 무출력
case_get_merge_base_mismatch() {
  mkroot; seed "$SHA_A" pytest
  local f; f=$(ls "$ROOT"/*.md | head -1)
  printf '<!-- qg-baseline-cache:v1 -->\nmerge_base: %s\n---\npytest\ta.py\tpass\t0\n' "$SHA_B" > "$f"
  local out rc; out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest a.py 2>/dev/null); rc=$?
  if [[ $rc -eq 4 && -z "$out" ]]; then ok "본문 merge_base 불일치 → 무출력"
  else no "sha 불일치 (rc=$rc out='$out')"; fi
  rmroot
}

# T24 + AC33: 원자적 쓰기 — 임시파일 + rename, 중단 시 부분 파일 부재
case_put_atomic() {
  mkroot; seed "$SHA_A" pytest
  if grep -qE 'mv[[:space:]]' "$BC" && grep -qE '\.tmp' "$BC"; then
    ok "put이 tmp + mv rename 사용"
  else no "원자적 쓰기 코드 부재"; fi
  local strays; strays=$(find "$ROOT" -name '*.tmp*' | wc -l | tr -d ' ')
  # `${strays}` 중괄호 필수 — `$strays개` 는 macOS bash 3.2 가 한글 `개` 의 선두 바이트를
  # 변수명에 포함시켜 이 분기가 실제로 발동하는 순간 unbound variable 로 죽는다.
  [[ "$strays" == "0" ]] && ok "put 후 임시파일 잔존 0" || no "임시파일 ${strays}개 잔존"
  rmroot
}

# T36b + AC40: `unrun`은 캐시에 안 들어가고 `absent`는 들어간다
case_unrun_not_cached_absent_cached() {
  mkroot
  printf 'x.py\tunrun\t-\ny.py\tabsent\t-\n' | bash "$BC" put "$ROOT" "$SHA_A" pytest
  local out; out=$(bash "$BC" get "$ROOT" "$SHA_A" pytest x.py y.py | tr '\n' ';')
  [[ "$out" == "y.py${TAB}absent${TAB}-;" ]] \
    && ok "unrun 미캐시 · absent 캐시" || no "unrun/absent (got: $out)"
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
    ok "put: error 행 미기록 · pass 행 기록(양의 짝) — 캐시 파일 직접 검사"
  else no "put error 미캐시 (error행=$has_err pass행=$has_pass body='$body')"; fi
  rmroot
}

# /qg iter-1 CRITICAL conf 8 (security-reviewer 제기, 실행 검증자가 손으로 행을 심어 재현).
#
# 캐시는 `.claude/quality-gates/baseline-cache/<mb[0:12]>.md` 에 살고, runtime-verifier 는
# 무제한 Bash 를 들고 **그 형제 디렉토리에 쓰라고 명시적으로 지시**받는다. 게다가 `run` 은
# 저장소가 통제하는 코드(`bash tests/*.sh` · npm lifecycle · `make` · build.rs)를 호스트
# 사용자 권한으로 돌리므로 **적대적 subagent 조차 필요 없다** — 리뷰 대상 저장소의 평범한
# 테스트 하나가 `git merge-base` 한 번으로 경로를 계산해 쓸 수 있다.
#
# 사슬: 심어진 fail → 전량 적중 → SKILL.md R4② 가 "미적중분이 있을 때만" 기준선
# 워크트리를 만들므로 **기준선 테스트가 하나도 안 돈다** → (F,F)=PRE_EXISTING → DEFECTS
# 밖 → confirmed_product_defect:false → PASS.
#
# 봉인(digest)이 아니라 재검증인 이유: 캐시는 실행 사이에 살아남는 것이 존재 이유라
# 세션 컨텍스트의 비밀로 봉인할 수 없고, 파일에 둔 비밀은 verifier 의 Bash 가 읽는다.
# 방향 비대칭은 비밀을 요구하지 않는다.
case_planted_fail_is_not_served_as_hit() {
  mkroot
  printf '%s\nmerge_base: %s\n---\npytest\tv.py\tfail\t1\npytest\tw.py\tpass\t0\n' \
    '<!-- qg-baseline-cache:v1 -->' "$SHA_A" > "$ROOT/${SHA_A:0:12}.md"
  # `rc` 를 **파이프 없이** 잡는다. `... | tr ...` 뒤의 `$?` 는 `tr` 의 상태(항상 0)라
  # 종료코드 검사가 죽은 assertion 이 된다 — /qg iter-2 G4 실측: get 의 성공 경로 `exit 0`
  # 을 `exit 4` 로 바꿔도 stdout 이 동일해 전 스위트가 GREEN 이었다.
  local raw out rc
  raw=$(bash "$BC" get "$ROOT" "$SHA_A" pytest v.py w.py); rc=$?
  out=$(printf '%s\n' "$raw" | tr '\n' ';')
  # 양의 짝(w.py=pass 적중)이 필수다 — 없으면 "get 이 아무것도 안 내주는" mutation 이
  # 이 케이스를 GREEN 으로 통과한다.
  if [[ "$rc" == "0" && "$out" == "w.py${TAB}pass${TAB}0;" ]]; then
    ok "심어진/낡은 fail 은 적중 아님(기준선 재실행 강제) · pass 는 적중(양의 짝)"
  else no "심어진 fail 재검증 (rc=$rc out='$out')"; fi
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
  # 파이프 없이 rc 를 잡는다 (위 케이스의 G4 주석 참조).
  local raw out rc
  raw=$(bash "$BC" get "$ROOT" "$SHA_A" pytest e.py p.py); rc=$?
  out=$(printf '%s\n' "$raw" | tr '\n' ';')
  if [[ "$rc" == "0" && "$out" == "p.py${TAB}pass${TAB}0;" ]]; then
    ok "레거시 error 행 미적중(재계산) · 같은 파일 pass 행 적중 · exit 0(손상 아님)"
  else no "레거시 error 행 (rc=$rc out='$out')"; fi
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
  [[ "$out" == "BULK${TAB}pass${TAB}0;" ]] && ok "bulk 어댑터 → BULK 키 정상" || no "BULK 키 ($out)"
  local err
  printf 'BULK\tpass\t0\na.py\tpass\t0\n' | bash "$BC" put "$ROOT" "$SHA_A" pytest 2>"$ROOT/e.txt"
  err=$(cat "$ROOT/e.txt")
  printf '%s' "$err" | grep -q 'BULK' \
    && ok "file-granularity 러너에 BULK 혼입 → loud advisory" \
    || no "BULK 혼입 무경고"
  rmroot
}

# 부분 적중 병합: 같은 키에 새 값이 오면 새 값이 이기고, 다른 runner의 행은 보존
case_put_merge_preserves_other_runner() {
  mkroot; seed "$SHA_A" pytest
  printf 'z.sh\tpass\t0\n' | bash "$BC" put "$ROOT" "$SHA_A" shell
  local n1 n2
  # 저장 의미론은 파일로 잰다 — get 은 fail 을 서빙하지 않으므로 보존 여부를 못 본다.
  n1=$(printf '%s' "$(rows_of "$SHA_A" pytest)" | tr ';' '\n' | grep -c . || true)
  n2=$(printf '%s' "$(rows_of "$SHA_A" shell)"  | tr ';' '\n' | grep -c . || true)
  [[ "$n1" == "2" && "$n2" == "1" ]] \
    && ok "다른 runner put이 기존 행을 보존" || no "병합 (pytest=$n1 shell=$n2)"
  printf 'a.py\tfail\t1\n' | bash "$BC" put "$ROOT" "$SHA_A" pytest
  [[ "$(row_of "$SHA_A" pytest a.py)" == "fail/1" ]] \
    && ok "같은 키 재기록 → 새 값이 이김" \
    || no "키 충돌 (row: '$(row_of "$SHA_A" pytest a.py)')"
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
  # 보존은 **저장** 속성이므로 파일로 잰다 (get 은 b.py=fail 을 서빙하지 않는다).
  local got; got=$(rows_of "$SHA_A" pytest)
  [[ "$got" == "a.py=pass;b.py=fail;c.py=pass;" ]] \
    && ok "부분 payload put이 같은 runner의 미포함 unit을 보존" \
    || no "부분 payload put이 미포함 unit을 지움 (rows: $got)"
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
  # 둘 다 fail 이라 get 으로는 아무것도 안 보인다 — 파일에서 status/exit 를 함께 잰다.
  local ra rb; ra=$(row_of "$SHA_A" pytest a.py); rb=$(row_of "$SHA_A" pytest b.py)
  [[ "$ra" == "fail/9" && "$rb" == "fail/1" ]] \
    && ok "충돌 키는 새 값이 이기고 미포함 키는 보존 (동시 성립)" \
    || no "충돌+보존 동시성 (a.py='$ra' b.py='$rb')"
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
  # 보존은 **저장** 속성이라 파일로 잰다 (get 은 b.py=fail 을 서빙하지 않는다).
  local rc rows expect="a.py=pass;b.py=fail;"

  printf '' | bash "$BC" put "$ROOT" "$SHA_A" pytest 2>/dev/null; rc=$?
  rows=$(rows_of "$SHA_A" pytest)
  if [[ $rc -eq 0 && "$rows" == "$expect" ]]; then
    ok "빈 stdin put → exit 0 + 기존 행 보존"
  else no "빈 stdin put (rc=$rc rows='$rows')"; fi

  printf 'c.py\tunrun\t-\n' | bash "$BC" put "$ROOT" "$SHA_A" pytest 2>/dev/null; rc=$?
  rows=$(rows_of "$SHA_A" pytest)
  if [[ $rc -eq 0 && "$rows" == "$expect" ]]; then
    ok "전량 unrun payload → exit 0 + 기존 행 보존"
  else no "전량 unrun payload (rc=$rc rows='$rows')"; fi

  printf 'z.py\tbogus\t0\nnotabs\n' | bash "$BC" put "$ROOT" "$SHA_A" pytest 2>/dev/null; rc=$?
  rows=$(rows_of "$SHA_A" pytest)
  if [[ $rc -eq 0 && "$rows" == "$expect" ]]; then
    ok "전량 malformed payload → exit 0 + 기존 행 보존"
  else no "전량 malformed payload (rc=$rc rows='$rows')"; fi

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
    ok "캐시 파일 부재 → exit 0 + 무출력 (손상의 exit 4와 구분)"
  else no "캐시 파일 부재 (rc=$rc out='$out')"; fi
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
    ok "존재하지 않는 cache-root → mkdir -p 후 정상 기록·조회"
  else no "cache-root 최초 생성 (rc=$rc out='$out')"; fi
  cd / && rm -rf "$parent"
  ROOT=""
}

for c in case_key_includes_merge_base case_key_includes_runner case_get_full_hit \
         case_get_partial_hit case_get_corrupt_header case_get_corrupt_body \
         case_get_merge_base_mismatch case_put_atomic \
         case_unrun_not_cached_absent_cached \
         case_error_not_cached_pass_still_cached case_get_skips_legacy_error_row \
         case_planted_fail_is_not_served_as_hit \
         case_bulk_key_isolation \
         case_put_merge_preserves_other_runner \
         case_put_partial_preserves_uninvolved_units_same_runner \
         case_put_partial_overwrites_matching_unit_preserves_others \
         case_put_empty_payload_normalizes_to_empty_exits_zero \
         case_get_missing_cache_file_exits_zero \
         case_put_creates_nonexistent_cache_root; do
  echo "== $c"; $c
done
finish
