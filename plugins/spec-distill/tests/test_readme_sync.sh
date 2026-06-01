#!/usr/bin/env bash
# AC12 — README synced with v0.12.0 interview flow.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
README="$REPO_ROOT/plugins/spec-distill/README.md"
PLUGIN_JSON="$REPO_ROOT/plugins/spec-distill/.claude-plugin/plugin.json"
CHANGELOG="$REPO_ROOT/plugins/spec-distill/CHANGELOG.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

grep -q '"version": "0.12.0"' "$PLUGIN_JSON" \
  && note PASS "AC11: plugin.json version 0.12.0" || note FAIL "AC11: plugin.json not 0.12.0"
grep -qE '^## \[0\.12\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \
  && note PASS "AC11: CHANGELOG [0.12.0] entry with ISO date" || note FAIL "AC11: CHANGELOG [0.12.0] missing/!ISO"
grep -qE '^## \[0\.12\.0\].*XX' "$CHANGELOG" \
  && note FAIL "AC11: CHANGELOG date has XX placeholder" || note PASS "AC11: no XX placeholder in date"

for kw in 'DEVBREW_SPEC_DISTILL_DISABLE_WEB' 'interview-brief' 'steelman-builder'; do
  grep -q "$kw" "$README" \
    && note PASS "AC12: README mentions $kw" || note FAIL "AC12: README missing $kw"
done

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
