#!/usr/bin/env bash
# AC16 — README/plugin.json/CHANGELOG synced with v0.14.0 (cancel-review + suppression).
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
README="$REPO_ROOT/plugins/spec-distill/README.md"
PLUGIN_JSON="$REPO_ROOT/plugins/spec-distill/.claude-plugin/plugin.json"
CHANGELOG="$REPO_ROOT/plugins/spec-distill/CHANGELOG.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

grep -q '"version": "0.14.0"' "$PLUGIN_JSON" \
  && note PASS "AC16: plugin.json version 0.14.0" || note FAIL "AC16: plugin.json not 0.14.0"
grep -qE '^## \[0\.14\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \
  && note PASS "AC16: CHANGELOG [0.14.0] entry with ISO date" || note FAIL "AC16: CHANGELOG [0.14.0] missing/!ISO"
grep -qE '^## \[0\.14\.0\].*XX' "$CHANGELOG" \
  && note FAIL "AC16: CHANGELOG date has XX placeholder" || note PASS "AC16: no XX placeholder in date"

for kw in 'DEVBREW_SPEC_DISTILL_DISABLE_WEB' 'interview-brief' 'steelman-builder' 'cancel-review'; do
  grep -q "$kw" "$README" \
    && note PASS "AC16: README mentions $kw" || note FAIL "AC16: README missing $kw"
done

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
