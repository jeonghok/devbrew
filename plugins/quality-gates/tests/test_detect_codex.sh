#!/usr/bin/env bash
# AC1 — detect_codex.sh probe verification: 판정(available · skip_reason)마다 한 케이스 · kill switch conf.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROBE="$PLUGIN_ROOT/scripts/detect_codex.sh"
CONF="$PLUGIN_ROOT/scripts/codex-killswitch.conf"
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
out="$(DEVBREW_QUALITY_GATES_DISABLE_CODEX=1 bash "$PROBE")"
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

# AC25 — 이웃 플러그인의 kill switch 변수는 이 감지기를 끄지 않는다.
echo "=== Case 10: 이웃 플러그인 kill switch 변수는 무효해야 한다 ==="
out="$(PATH="$MOCKS/safe-v1:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY=test DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1 bash "$PROBE")"
assert_grep "$out" 'codex_available: true' "foreign kill switch inert"

# `$PROBE`는 정본 shared/codex/detect_codex.sh 를 가리키는 심볼릭 링크다 — 본문에는
# 어느 kill switch 변수명도 리터럴로 없다(형제 conf 에 있다). `$PROBE` 본문을 grep 하면
# 자기 변수도 못 찾아 양(positive)이 조용히 RED 되고, 이웃 변수도 못 찾아 음(negative)이
# 조용히 vacuous 통과가 된다 — 두 축 다 형제 conf `$CONF` 를 잰다. conf 부재는
# assert_file_grep/assert_file_absent 계약대로 fail-closed(no()) 다.
echo "=== Case 11: kill switch 변수명 (conf grep) ==="
assert_file_grep "$CONF" 'CODEX_KILL_SWITCH_VAR=DEVBREW_QUALITY_GATES_DISABLE_CODEX' "kill-switch var name"

echo "=== Case 12: 이웃 플러그인 변수 잔존 없음 ==="
assert_file_absent "$CONF" 'DEVBREW_SPEC_DISTILL_DISABLE_CODEX|DEVBREW_PLUGIN_AUDIT_DISABLE_CODEX' "이웃 변수 잔존 없음"

# F2 — malformed conf 가 fail-closed 하는지. 추적 conf 는 덮지 않는다 —
# 링크를 푼 감지기 사본을 $TMP/probe 에 두고, 감지기가 dirname "${BASH_SOURCE[0]}"
# 로 찾는 형제 conf 자리에 망가진 값을 쓴다.
mkdir -p "$TMP/probe"
cp -L "$PROBE" "$TMP/probe/detect_codex.sh"

echo "=== Case 13: malformed conf(CRLF) 는 fail-closed 다 ==="
printf 'CODEX_KILL_SWITCH_VAR=DEVBREW_QUALITY_GATES_DISABLE_CODEX\r\n' > "$TMP/probe/codex-killswitch.conf"
out="$(bash "$TMP/probe/detect_codex.sh" 2>&1)"
assert_grep "$out" 'skip_reason: killswitch_config_invalid' "malformed conf(CRLF) fail-closed"

echo "=== Case 14: malformed conf(공백만) 는 fail-closed 다 ==="
printf 'CODEX_KILL_SWITCH_VAR="   "\n' > "$TMP/probe/codex-killswitch.conf"
out="$(bash "$TMP/probe/detect_codex.sh" 2>&1)"
assert_grep "$out" 'skip_reason: killswitch_config_invalid' "malformed conf(공백만) fail-closed"

# 13 · 14 의 양의 짝 — 같은 사본 옆에 정상 conf 를 두면 invalid 가 아니다. 사본이 형제
# conf 를 읽지 못하면 killswitch_config_missing 이 나므로 available 로 판정한다.
echo "=== Case 15: 정상 conf 를 둔 사본은 killswitch_config_invalid 가 아니다 ==="
cp "$CONF" "$TMP/probe/"
out="$(PATH="$MOCKS/safe-v1:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY=test bash "$TMP/probe/detect_codex.sh" 2>&1)"
assert_grep "$out" 'codex_available: true' "정상 conf 사본은 형제 conf 를 읽고 invalid 가 아니다"

finish
