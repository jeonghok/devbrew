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
echo "=== sections subcommand ==="

# T4-1: spec-valid → no missing sections
out=$(python3 "$SCRIPT" sections "$FIX/spec-valid.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"missing": \[\]' \
  && note PASS "valid spec has no missing sections" \
  || note FAIL "valid spec sections check failed (rc=$rc out=$out)"

# T4-2: spec-missing-goals → missing includes "#goals"
out=$(python3 "$SCRIPT" sections "$FIX/spec-missing-goals.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '#goals' \
  && note PASS "spec-missing-goals reports #goals as missing" \
  || note FAIL "missing-goals detection failed (rc=$rc out=$out)"

echo ""
echo "=== locked-decisions subcommand ==="

# T5-1: spec-valid → no errors (LD1만 있고 모든 sub-field 존재)
out=$(python3 "$SCRIPT" locked-decisions "$FIX/spec-valid.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"errors": \[\]' \
  && note PASS "valid spec locked_decisions has no errors" \
  || note FAIL "valid locked_decisions check failed (rc=$rc out=$out)"

# T5-2: design-no-frontmatter → no errors (locked_decisions 부재 = 미적용, design mode에서 정상)
out=$(python3 "$SCRIPT" locked-decisions "$FIX/design-no-frontmatter.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"errors": \[\]' \
  && note PASS "design-mode no-frontmatter has no errors" \
  || note FAIL "design no-frontmatter case failed (rc=$rc out=$out)"

echo ""
echo "summary: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
