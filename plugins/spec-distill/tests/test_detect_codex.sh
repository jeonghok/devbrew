#!/usr/bin/env bash
# AC1 + AC2 + AC15(codex-only) — 6-case probe + kill-switch var mutation teeth.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROBE="$PLUGIN_ROOT/scripts/detect_codex.sh"
MOCKS="$SCRIPT_DIR/mocks"
TMP="$(mktemp -d -t sd-detect-codex-test-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
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

# Teeth: the script must key the kill switch on the spec-distill var (body grep).
assert_file_grep "$PROBE" 'DEVBREW_DISABLE_SPEC_DISTILL_CODEX' "kill-switch var name (expect DEVBREW_DISABLE_SPEC_DISTILL_CODEX)"
assert_file_absent "$PROBE" 'DEVBREW_DISABLE_QG_CODEX' "no stale qg var"

finish
