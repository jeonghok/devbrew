#!/usr/bin/env bash
# AC1 + AC2 + AC15(codex-only) — 6-case probe + kill-switch var mutation teeth.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROBE="$PLUGIN_ROOT/scripts/detect_codex.sh"
CONF="$PLUGIN_ROOT/scripts/codex-killswitch.conf"
MOCKS="$SCRIPT_DIR/mocks"
TMP="$(mktemp -d -t sd-detect-codex-test-XXXXXX)"
CONF_BACKUP="$TMP/codex-killswitch.conf.orig"
[ -f "$CONF" ] && cp -p "$CONF" "$CONF_BACKUP"
restore_conf() { [ -f "$CONF_BACKUP" ] && cp -p "$CONF_BACKUP" "$CONF"; }
# N5 잔여 위험(round 2): SIGKILL은 EXIT trap을 못 받는다 — 그때는 추적 중인
# codex-killswitch.conf가 malformed 값(CRLF/공백만)으로 덮인 채 남는다. 테스트
# 실패로는 안 깨진다(복원이 판정보다 먼저, no()는 exit하지 않는다). git checkout --
# 로 복구 가능하고 데이터 손실은 없다 — 다음 사람이 워킹트리가 왜 더러운지 알도록 남긴다.
trap 'restore_conf; rm -rf "$TMP"' EXIT
chmod +x "$MOCKS"/bin-stubs/* "$MOCKS"/safe-v1/* "$MOCKS"/bad-version/* \
         "$MOCKS"/below-floor/* "$MOCKS"/unreadable-version/* 2>/dev/null || true

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# Case 1: not installed
assert_grep "$(PATH=/usr/bin:/bin bash "$PROBE")" 'skip_reason: not_installed' "not_installed"
# Case 2: ok
assert_grep "$(PATH="$MOCKS/safe-v1:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY=t bash "$PROBE")" 'codex_available: true' "available"
# Case 3: codex-only kill switch (AC1 + AC15 codex-only)
assert_grep "$(DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1 bash "$PROBE")" 'skip_reason: kill_switch' "kill_switch"
# Case 4a/4b: recursion guard
assert_grep "$(CODEX_SANDBOX=1 bash "$PROBE")" 'skip_reason: inside_codex_sandbox' "inside CODEX_SANDBOX"
assert_grep "$(CODEX_SESSION_ID=abc bash "$PROBE")" 'skip_reason: inside_codex_sandbox' "inside CODEX_SESSION_ID"
# Case 5: auth missing
mkdir -p "$TMP/nohome"
assert_grep "$(PATH="$MOCKS/safe-v1:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY= OPENAI_API_KEY= HOME="$TMP/nohome" bash "$PROBE")" 'skip_reason: auth_missing' "auth_missing"
# Case 6: known bad version
assert_grep "$(PATH="$MOCKS/bad-version:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY=t bash "$PROBE")" 'skip_reason: known_bad_version' "known_bad_version"
# Case 7: timeout bin missing
assert_grep "$(PATH="$MOCKS/safe-v1:/usr/bin:/bin" CODEX_API_KEY=t bash "$PROBE")" 'skip_reason: timeout_binary_missing' "timeout_binary_missing"

# Case 8/9: 버전 바닥·판독 불가 (합집합 — AC25)
assert_grep "$(PATH="$MOCKS/below-floor:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY=t bash "$PROBE")" 'skip_reason: version_below_floor' "version_below_floor"
assert_grep "$(PATH="$MOCKS/unreadable-version:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY=t bash "$PROBE")" 'skip_reason: version_unreadable' "version_unreadable"
# Case 10: AC7 timeout 5 wrap (qg 사본에만 있던 검사 — 합집합)
assert_file_grep "$PROBE" '\$TIMEOUT_BIN"?[[:space:]]+5[[:space:]]+codex[[:space:]]+--version' "codex --version이 timeout 5로 감싸져 있다"

# AC1 regression: qg var DEVBREW_DISABLE_QG_CODEX must NOT affect this script.
assert_grep "$(PATH="$MOCKS/safe-v1:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY=t DEVBREW_DISABLE_QG_CODEX=1 bash "$PROBE")" 'codex_available: true' "qg var inert"

# 재조준(F1/C1 수정, 2026-08-17): $PROBE는 정본을 가리키는 심볼릭 링크라 본문에
# 어느 변수명도 리터럴로 없다(형제 conf 로 이동). 형제 conf 로 재조준한다 — 부재는
# assert_file_grep/assert_file_absent 계약대로 fail-closed.
assert_file_grep "$CONF" 'CODEX_KILL_SWITCH_VAR=DEVBREW_DISABLE_SPEC_DISTILL_CODEX' "kill-switch var name (expect DEVBREW_DISABLE_SPEC_DISTILL_CODEX)"
# N6(round 2): qg·pa 두 형제 파일은 자기 이웃 변수를 전부 확인한다(qg는
# SPEC_DISTILL|PLUGIN_AUDIT, pa는 QG·SPEC_DISTILL 각각). 이 파일은 QG만 봤다 —
# baseline에서 그대로 옮겨와 회귀는 아니지만, 형제 conf로 재조준하는 김에 열거를
# 맞춘다(C10: 추가는 허용, 감소만 금지).
assert_file_absent "$CONF" 'DEVBREW_DISABLE_QG_CODEX|DEVBREW_DISABLE_PLUGIN_AUDIT_CODEX' "no stale foreign var"

# F2 compounding: malformed conf 는 fail-closed 다.
printf 'CODEX_KILL_SWITCH_VAR=DEVBREW_DISABLE_SPEC_DISTILL_CODEX\r\n' > "$CONF"
out="$(bash "$PROBE" 2>&1)"
restore_conf
assert_grep "$out" 'skip_reason: killswitch_config_invalid' "malformed conf(CRLF) fail-closed"

printf 'CODEX_KILL_SWITCH_VAR="   "\n' > "$CONF"
out="$(bash "$PROBE" 2>&1)"
restore_conf
assert_grep "$out" 'skip_reason: killswitch_config_invalid' "malformed conf(공백만) fail-closed"

finish
