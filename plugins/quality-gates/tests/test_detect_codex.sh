#!/usr/bin/env bash
# AC1 — 6-case probe verification.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROBE="$PLUGIN_ROOT/scripts/detect_codex.sh"
MOCKS="$SCRIPT_DIR/mocks"
TMP="$(mktemp -d -t qg-detect-codex-test-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

echo "=== Case 1: not installed ==="
out="$(PATH=/usr/bin:/bin bash "$PROBE")"
assert_grep "$out" 'skip_reason: not_installed' "not installed"

echo "=== Case 2: installed + auth + safe version ==="
out="$(PATH="$MOCKS/safe-v1:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY=test bash "$PROBE")"
assert_grep "$out" 'codex_available: true' "ok"

echo "=== Case 3: kill switch ==="
out="$(DEVBREW_DISABLE_QG_CODEX=1 bash "$PROBE")"
assert_grep "$out" 'skip_reason: kill_switch' "kill switch"

echo "=== Case 4a: inside codex (CODEX_SANDBOX) ==="
out="$(CODEX_SANDBOX=1 bash "$PROBE")"
assert_grep "$out" 'skip_reason: inside_codex_sandbox' "inside codex via CODEX_SANDBOX"

echo "=== Case 4b: inside codex (CODEX_SESSION_ID) ==="
out="$(CODEX_SESSION_ID=abc bash "$PROBE")"
assert_grep "$out" 'skip_reason: inside_codex_sandbox' "inside codex via CODEX_SESSION_ID"

echo "=== Case 5: auth missing ==="
mkdir -p "$TMP/no-codex-home"
out="$(PATH="$MOCKS/safe-v1:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY= OPENAI_API_KEY= HOME="$TMP/no-codex-home" bash "$PROBE")"
assert_grep "$out" 'skip_reason: auth_missing' "auth missing"

echo "=== Case 6: known bad version ==="
out="$(PATH="$MOCKS/bad-version:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY=test bash "$PROBE")"
assert_grep "$out" 'skip_reason: known_bad_version' "known bad version"

echo "=== Case 7: version below floor (0.117.0 < 0.118.0) ==="
out="$(PATH="$MOCKS/below-floor:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY=test bash "$PROBE")"
assert_grep "$out" 'skip_reason: version_below_floor' "version below floor"

echo "=== Case 8: version unreadable (semver 파싱 실패) ==="
# `|| echo unknown`은 도달하지 않는다 — `head -1`이 빈 입력에도 exit 0이라 `||`가
# 절대 발화하지 않기 때문이다. 판독 실패의 실제 관측값은 빈 문자열이고, 그 상태로
# `codex_available: true`가 나가면 `indeterminate ≠ clean` 위반이다. 그래서 판정을
# 문자열 `unknown`이 아니라 **semver 파싱 성공 여부**에 건다.
out="$(PATH="$MOCKS/unreadable-version:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY=test bash "$PROBE")"
assert_grep "$out" 'skip_reason: version_unreadable' "version unreadable"

echo "=== Case 9: 바닥 이상은 통과한다 (0.118.0 경계 포함) ==="
out="$(PATH="$MOCKS/safe-v1:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY=test bash "$PROBE")"
assert_grep "$out" 'codex_available: true' "floor 이상은 available"

# AC7 — codex --version timeout 5s wrap
# Accept either literal timeout/gtimeout or via TIMEOUT_BIN variable with arg 5
echo "=== AC7: codex --version uses timeout 5 ==="
if grep -qE '(timeout|gtimeout)[[:space:]]+5[[:space:]]+codex[[:space:]]+--version' \
    "$PLUGIN_ROOT/scripts/detect_codex.sh" || \
   grep -qE '\$TIMEOUT_BIN"?[[:space:]]+5[[:space:]]+codex[[:space:]]+--version' \
    "$PLUGIN_ROOT/scripts/detect_codex.sh"; then
  ok "AC7: codex --version wrapped with timeout 5"
else
  no "AC7: codex --version not wrapped with 'timeout 5'"
fi

# AC7 — timeout_binary_missing 7th case
echo "=== AC7: timeout_binary_missing 7th case ==="
if grep -q "timeout_binary_missing" \
    "$PLUGIN_ROOT/scripts/detect_codex.sh"; then
  ok "AC7: timeout_binary_missing skip_reason present"
else
  no "AC7: timeout_binary_missing skip_reason not emitted"
fi

# 합집합(AC25): sd 사본에만 있던 케이스를 가져온다. 두 사본이 **어느 쪽도 합집합이
# 아닌** 상태였고, 그래서 한쪽에만 있는 케이스는 반대쪽 사본의 회귀를 못 잡았다.
echo "=== Case 10: 이웃 플러그인 kill switch 변수는 무효해야 한다 ==="
out="$(PATH="$MOCKS/safe-v1:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY=test DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1 bash "$PROBE")"
assert_grep "$out" 'codex_available: true' "foreign kill switch inert"

echo "=== Case 11: kill switch 변수명 (body grep) ==="
if grep -q 'DEVBREW_DISABLE_QG_CODEX' "$PROBE"; then
  ok "kill-switch var name"
else
  no "kill-switch var name (expect DEVBREW_DISABLE_QG_CODEX)"
fi

echo "=== Case 12: 이웃 플러그인 변수 잔존 없음 ==="
if grep -q 'DEVBREW_DISABLE_SPEC_DISTILL_CODEX\|DEVBREW_DISABLE_PLUGIN_AUDIT_CODEX' "$PROBE"; then
  no "이웃 플러그인 kill switch 변수 잔존"
else
  ok "이웃 변수 잔존 없음"
fi

finish
