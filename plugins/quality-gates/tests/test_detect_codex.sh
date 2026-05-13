#!/usr/bin/env bash
# AC1 — 6-case probe verification.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROBE="$PLUGIN_ROOT/scripts/detect_codex.sh"
MOCKS="$SCRIPT_DIR/mocks"
TMP="$(mktemp -d -t qg-detect-codex-test-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
assert_grep() {
  local desc="$1"; local output="$2"; local pattern="$3"
  if echo "$output" | grep -q "$pattern"; then
    echo "  PASS: $desc"
    pass=$((pass + 1))
  else
    echo "  FAIL: $desc"
    echo "    expected: $pattern"
    echo "    actual:"
    echo "$output" | sed 's/^/      /'
    fail=$((fail + 1))
  fi
}

echo "=== Case 1: not installed ==="
out="$(PATH=/usr/bin:/bin bash "$PROBE")"
assert_grep "not installed" "$out" 'skip_reason: not_installed'

echo "=== Case 2: installed + auth + safe version ==="
out="$(PATH="$MOCKS/safe-v1:/usr/bin:/bin" CODEX_API_KEY=test bash "$PROBE")"
assert_grep "ok" "$out" 'codex_available: true'

echo "=== Case 3: kill switch ==="
out="$(DEVBREW_DISABLE_QG_CODEX=1 bash "$PROBE")"
assert_grep "kill switch" "$out" 'skip_reason: kill_switch'

echo "=== Case 4a: inside codex (CODEX_SANDBOX) ==="
out="$(CODEX_SANDBOX=1 bash "$PROBE")"
assert_grep "inside codex via CODEX_SANDBOX" "$out" 'skip_reason: inside_codex_sandbox'

echo "=== Case 4b: inside codex (CODEX_SESSION_ID) ==="
out="$(CODEX_SESSION_ID=abc bash "$PROBE")"
assert_grep "inside codex via CODEX_SESSION_ID" "$out" 'skip_reason: inside_codex_sandbox'

echo "=== Case 5: auth missing ==="
mkdir -p "$TMP/no-codex-home"
out="$(PATH="$MOCKS/safe-v1:/usr/bin:/bin" CODEX_API_KEY= OPENAI_API_KEY= HOME="$TMP/no-codex-home" bash "$PROBE")"
assert_grep "auth missing" "$out" 'skip_reason: auth_missing'

echo "=== Case 6: known bad version ==="
out="$(PATH="$MOCKS/bad-version:/usr/bin:/bin" CODEX_API_KEY=test bash "$PROBE")"
assert_grep "known bad version" "$out" 'skip_reason: known_bad_version'

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[[ $fail -eq 0 ]] || exit 1
