#!/usr/bin/env bash
# 판정 헬퍼 정본 — 리포의 모든 셸 테스트가 이것을 source 한다.
#
# **사본이 없다.** 테스트는 리포에서만 돌고 `${CLAUDE_PLUGIN_ROOT}` 에서 도달할 필요가
# 없으므로, 배포되는 것과 달리 정본 하나를 직접 source 한다(설계 §2.2 경계선).
#
# `plugins/quality-gates/tests/lib/` 를 쓰지 않는 이유는 소유 관계다 — 판정 헬퍼는
# 어느 한 플러그인의 것이 아니다. 지금 spec-distill 테스트 하나가 quality-gates 의
# lib 를 source 하는 것이 그 왜곡의 실증이다. 리포 루트 `.gitignore:17` 의 `lib/`
# 규칙이 `tests/lib/` 하위를 조용히 untracked 로 만들며 quality-gates 만 `:20-21`
# negation 으로 구제돼 있는데, `shared/tests/` 는 그 규칙에 걸리지 않는다.
#
# ── 계약 ──────────────────────────────────────────────────────────────────
#  · 판정 헬퍼는 **실패를 세고 계속 진행**한다. 종료는 `finish` 가 한다.
#  · `field <key> <text>` — 인자 순서는 **키가 먼저**, 반환은 **값만**.
#    (이관 전 리포에는 `field <text> <key>` 형태가 섞여 있었다. 순서를 뒤집는
#     이관이므로 호출부를 하나도 빠뜨리면 안 된다 — 빠뜨리면 빈 문자열끼리
#     비교해 **조용히 통과**한다. `shared/tests/test_assert_behavior.sh` 가 순서를 못박는다.)
#  · 이 계약을 바꾸면 `test_assert_behavior.sh` 가 RED 로 알린다.

_ASSERT_PASS=0
_ASSERT_FAIL=0

note() { printf '%s\n' "$*"; }
ok()   { _ASSERT_PASS=$((_ASSERT_PASS+1)); printf '  ✓ %s\n' "$*"; }
no()   { _ASSERT_FAIL=$((_ASSERT_FAIL+1)); printf '  ✗ %s\n' "$*"; }

assert_eq() {        # assert_eq <actual> <expected> <msg>
  if [ "$1" = "$2" ]; then ok "$3"
  else no "$3"; printf '      expected: %s\n      actual:   %s\n' "$2" "$1"; fi
}

assert_contains() {  # assert_contains <haystack> <needle> <msg>
  case "$1" in
    *"$2"*) ok "$3" ;;
    *) no "$3"; printf '      needle:   %s\n      haystack: %s\n' "$2" "$(printf '%s' "$1" | head -c 400)" ;;
  esac
}

assert_not_contains() {  # assert_not_contains <haystack> <needle> <msg>
  case "$1" in
    *"$2"*) no "$3"; printf '      금지 문자열이 있다: %s\n' "$2" ;;
    *) ok "$3" ;;
  esac
}

assert_grep() {      # assert_grep <text> <ERE> <msg>
  if printf '%s\n' "$1" | grep -qE -- "$2"; then ok "$3"
  else no "$3"; printf '      pattern:  %s\n      text:     %s\n' "$2" "$(printf '%s' "$1" | head -c 400)"; fi
}

assert_not_grep() {  # assert_not_grep <text> <ERE> <msg>   — assert_grep 의 짝
  if printf '%s\n' "$1" | grep -qE -- "$2"; then
    no "$3"; printf '      금지 패턴: %s\n' "$2"
  else ok "$3"; fi
}

# ── 파일 대상 변형 ─────────────────────────────────────────────────────────
# **파일 부재는 fail-closed 다 — no() 로 센다.**
# 이관 전 `assert_not_grep`(quality-gates/tests/test_adversarial_model_consistency.sh:39)
# 의 주석이 실측으로 남긴 결함이다: *"A missing file must FAIL, not vacuously PASS
# (Gate 2 adversarial confirmed this gap): grep on a nonexistent file exits non-zero,
# which would otherwise route to the PASS branch."* 이 이빨을 이관하면서 잃으면 C10 위반이다.
# `"$(cat <file>)"` 로 텍스트 변형에 넘기는 우회는 쓰지 않는다 — 그 형태가 정확히 위 결함이다.
assert_file_grep() {    # assert_file_grep <file> <ERE> <msg>
  if [ ! -f "$1" ]; then no "$3 (파일 없음: $1)"; return; fi
  if grep -qE -- "$2" "$1"; then ok "$3"
  else no "$3"; printf '      pattern:  %s\n      file:     %s\n' "$2" "$1"; fi
}

assert_file_absent() {  # assert_file_absent <file> <ERE> <msg>
  if [ ! -f "$1" ]; then no "$3 (파일 없음: $1)"; return; fi
  if grep -qE -- "$2" "$1"; then no "$3 (금지 패턴이 있다: $2)"
  else ok "$3"; fi
}

# 개수 판정 — 이관 전 `check <name> <cmd> <expected>` 계열(qg 6파일, persona 쌍 포함)의 정본.
# **인자 순서가 뒤집힌다**: 이관 전은 msg 가 **첫** 인자였고 여기서는 **마지막**이다
# (assert_eq·assert_contains·assert_grep 와 같은 자리). `field` 와 같은 종류의 조용한
# 실패원이므로 이관 시 호출부를 하나도 빠뜨리면 안 된다 — Task 14 Step 4 가 기계적으로 찾는다.
# 개수가 아닌 출력(빈 문자열·에러 텍스트)은 통과가 아니라 실패다: 이관 전 `check` 는
# `[ "$actual" -ge "$expected" ]` 에서 bash 산술 에러를 내고 `set +e` 아래서 실패로 떨어졌는데,
# 그 경로는 메시지가 없어 원인이 안 보였다.
assert_count_ge() {     # assert_count_ge <cmd> <expected> <msg>
  local actual
  actual="$(eval "$1" 2>/dev/null || true)"
  case "$actual" in ''|*[!0-9]*) no "$3 (개수가 아니다: '$actual')"; return ;; esac
  if [ "$actual" -ge "$2" ]; then ok "$3 (got $actual, expected >= $2)"
  else no "$3 (got $actual, expected >= $2)"; fi
}

# field <key> <text> → 그 키의 **값만**. `key: value` 형식 YAML-ish 출력 파싱용.
# awk 로 첫 콜론까지를 키로 보고 나머지를 값으로 낸다. 값에 공백이 있어도 보존한다
# (기존 `awk '{print $2}'` 변형들은 첫 토큰만 냈다 — 값에 공백이 있으면 잘렸다).
field() {
  printf '%s\n' "$2" | awk -v k="$1" '
    { i = index($0, ":") }
    i > 0 && substr($0, 1, i-1) == k {
      v = substr($0, i+1); sub(/^[[:space:]]+/, "", v); print v; exit
    }'
}

# field_line <key> <text> → 그 키의 **줄 전체**. test_qg_mutation_guard.sh:23 이
# 쓰던 형태 — 값만 내는 field 와 이름을 나눠 두 뜻이 한 이름에 겹치지 않게 한다.
field_line() {
  printf '%s\n' "$2" | awk -v k="$1" '
    { i = index($0, ":") }
    i > 0 && substr($0, 1, i-1) == k { print; exit }'
}

finish() {
  printf '\nTotal: %d | Pass: %d | Fail: %d\n' "$((_ASSERT_PASS+_ASSERT_FAIL))" "$_ASSERT_PASS" "$_ASSERT_FAIL"
  [ "$_ASSERT_FAIL" -eq 0 ]
}
