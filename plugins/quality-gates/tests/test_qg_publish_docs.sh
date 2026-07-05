#!/usr/bin/env bash
# test_qg_publish_docs.sh — AC15: version bump + honesty framing + kill-switch inventory.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }

grep -qE '"version":[[:space:]]*"2\.9\.0"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" \
  && pass "plugin.json version 2.9.0" || fail "version not bumped to 2.9.0"
grep -qE '^## \[2\.9\.0\]' "$PLUGIN_ROOT/CHANGELOG.md" \
  && pass "CHANGELOG has [2.9.0]" || fail "CHANGELOG missing [2.9.0]"
grep -qF 'DEVBREW_QG_DISABLE_PUBLISH' "$PLUGIN_ROOT/README.md" \
  && pass "README kill-switch inventory lists DEVBREW_QG_DISABLE_PUBLISH" || fail "kill switch not inventoried"
grep -qiE 'deterministic envelope|model-authored|모델 저술' "$PLUGIN_ROOT/README.md" \
  && pass "README honesty framing present" || fail "honesty framing missing"
grep -qF '/qg-publish' "$PLUGIN_ROOT/commands/qg.md" \
  && pass "qg.md cross-refs /qg-publish" || fail "no /qg-publish cross-ref"
echo "qg-publish-docs: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
