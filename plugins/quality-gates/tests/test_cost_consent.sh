#!/usr/bin/env bash
# AC10 — first-use consent gate fires; subsequent silent.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MARKER="${HOME}/.claude/quality-gates/codex-cost-consent.md"
CAPTURE_DIR="$(mktemp -d -t qg-consent-test-XXXXXX)"

restore() {
  rm -rf "$CAPTURE_DIR"
  test -f "$MARKER.test-bak" && mv "$MARKER.test-bak" "$MARKER"
  return 0
}
trap restore EXIT
test -f "$MARKER" && mv "$MARKER" "$MARKER.test-bak"

pass=0; fail=0

# Test 1: first run with no marker -> consent question captured
rm -f "$MARKER"
export QG_MOCK_ASKUSER_PATH="$CAPTURE_DIR/q1.json"
bash "$SCRIPT_DIR/harness/run_consent_gate.sh" 2>/dev/null || true
if [[ -f "$QG_MOCK_ASKUSER_PATH" ]] && grep -qi 'codex' "$QG_MOCK_ASKUSER_PATH"; then
  echo "  PASS: first run prompted for consent"; pass=$((pass + 1))
else
  echo "  FAIL: first run did not capture consent question"
  fail=$((fail + 1))
fi

# Test 2: marker exists -> second run silent
test -f "$MARKER" || touch "$MARKER"
export QG_MOCK_ASKUSER_PATH="$CAPTURE_DIR/q2.json"
bash "$SCRIPT_DIR/harness/run_consent_gate.sh" 2>/dev/null || true
if [[ ! -f "$QG_MOCK_ASKUSER_PATH" ]]; then
  echo "  PASS: second run silent (marker present)"; pass=$((pass + 1))
else
  echo "  FAIL: second run still prompted"
  fail=$((fail + 1))
fi

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[[ $fail -eq 0 ]] || exit 1
