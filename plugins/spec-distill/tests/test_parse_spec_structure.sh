#!/usr/bin/env bash
# Unit tests for parse_spec_structure.py library (CLI subcommand interface).
# Run: bash plugins/spec-distill/tests/test_parse_spec_structure.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/spec-distill/scripts/parse_spec_structure.py"
FIX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"

pass=0
fail=0
note() {
  if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"
  else fail=$((fail+1)); echo "  ✗ $2"; fi
}

echo "=== frontmatter subcommand ==="

# T3-1: valid frontmatter → exit 0 + JSON에 expected keys
out=$(python3 "$SCRIPT" frontmatter "$FIX/spec-valid.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"name": "fixture-valid"' \
  && note PASS "valid frontmatter parsed (name)" \
  || note FAIL "valid frontmatter parse failed (rc=$rc out=$out)"

# T3-2: missing frontmatter (design mode case) → exit 0 + empty object
out=$(python3 "$SCRIPT" frontmatter "$FIX/design-no-frontmatter.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '{}' \
  && note PASS "no frontmatter returns empty object" \
  || note FAIL "no-frontmatter case failed (rc=$rc out=$out)"

echo ""
echo "summary: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
