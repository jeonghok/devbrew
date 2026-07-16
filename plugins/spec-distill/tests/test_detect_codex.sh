#!/usr/bin/env bash
# AC1 + AC2 + AC15(codex-only) — 6-case probe + kill-switch var mutation teeth.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROBE="$PLUGIN_ROOT/scripts/detect_codex.sh"
MOCKS="$SCRIPT_DIR/mocks"
TMP="$(mktemp -d -t sd-detect-codex-test-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
chmod +x "$MOCKS"/bin-stubs/* "$MOCKS"/safe-v1/* "$MOCKS"/bad-version/* 2>/dev/null || true

pass=0; fail=0
ag() { local d="$1" o="$2" p="$3"; if echo "$o" | grep -q "$p"; then echo "  PASS: $d"; pass=$((pass+1)); else echo "  FAIL: $d (want: $p)"; echo "$o" | sed 's/^/    /'; fail=$((fail+1)); fi; }

# Case 1: not installed
ag "not_installed" "$(PATH=/usr/bin:/bin bash "$PROBE")" 'skip_reason: not_installed'
# Case 2: ok
ag "available" "$(PATH="$MOCKS/safe-v1:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY=t bash "$PROBE")" 'codex_available: true'
# Case 3: codex-only kill switch (AC1 + AC15 codex-only)
ag "kill_switch" "$(DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1 bash "$PROBE")" 'skip_reason: kill_switch'
# Case 4a/4b: recursion guard
ag "inside CODEX_SANDBOX" "$(CODEX_SANDBOX=1 bash "$PROBE")" 'skip_reason: inside_codex_sandbox'
ag "inside CODEX_SESSION_ID" "$(CODEX_SESSION_ID=abc bash "$PROBE")" 'skip_reason: inside_codex_sandbox'
# Case 5: auth missing
mkdir -p "$TMP/nohome"
ag "auth_missing" "$(PATH="$MOCKS/safe-v1:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY= OPENAI_API_KEY= HOME="$TMP/nohome" bash "$PROBE")" 'skip_reason: auth_missing'
# Case 6: known bad version
ag "known_bad_version" "$(PATH="$MOCKS/bad-version:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY=t bash "$PROBE")" 'skip_reason: known_bad_version'
# Case 7: timeout bin missing
ag "timeout_binary_missing" "$(PATH="$MOCKS/safe-v1:/usr/bin:/bin" CODEX_API_KEY=t bash "$PROBE")" 'skip_reason: timeout_binary_missing'

# AC1 regression: qg var DEVBREW_DISABLE_QG_CODEX must NOT affect this script.
ag "qg var inert" "$(PATH="$MOCKS/safe-v1:$MOCKS/bin-stubs:/usr/bin:/bin" CODEX_API_KEY=t DEVBREW_DISABLE_QG_CODEX=1 bash "$PROBE")" 'codex_available: true'

# Teeth: the script must key the kill switch on the spec-distill var (body grep).
grep -q 'DEVBREW_DISABLE_SPEC_DISTILL_CODEX' "$PROBE" \
  && { echo "  PASS: kill-switch var name"; pass=$((pass+1)); } \
  || { echo "  FAIL: kill-switch var name (expect DEVBREW_DISABLE_SPEC_DISTILL_CODEX)"; fail=$((fail+1)); }
grep -q 'DEVBREW_DISABLE_QG_CODEX' "$PROBE" \
  && { echo "  FAIL: stale qg var present"; fail=$((fail+1)); } \
  || { echo "  PASS: no stale qg var"; pass=$((pass+1)); }

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"; [[ $fail -eq 0 ]]
