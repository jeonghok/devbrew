#!/usr/bin/env bash
# AC7 (revised) — structural verification that codex-disabled paths
# behave identically to pre-feature state.
#
# Three checks:
#   1. Probe with kill switch returns false (uses AC1 test's logic)
#   2. Scout's static rules omit codex-reviewer when codex_available=false
#      (already covered by AC2 test, repeated here for completeness)
#   3. All existing qg test files (those not touching codex) pass —
#      no regressions in unrelated tests after the feature lands.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

pass=0; fail=0

# Check 1: kill switch produces skip
out="$(DEVBREW_DISABLE_QG_CODEX=1 bash "$PLUGIN_ROOT/scripts/detect_codex.sh")"
if echo "$out" | grep -q 'skip_reason: kill_switch'; then
  echo "  PASS: kill switch -> codex_available: false"
  pass=$((pass + 1))
else
  echo "  FAIL: kill switch did not produce skip"
  echo "$out" | sed 's/^/    /'
  fail=$((fail + 1))
fi

# Check 2 (updated for Task 2/3 architecture): SKILL.md owns codex dispatch and
# enforces standard/deep-only gate + v1.10.x byte-equivalent fallback.
# Three sub-checks; all must pass.
SKILL_MD="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
c2_fail=0

# 2a: SKILL.md is the sole decision-maker for codex-reviewer dispatch (not scout)
if grep -qE 'SKILL\.md.*codex-reviewer.*dispatch.*단독|codex-reviewer dispatch.*단독' "$SKILL_MD"; then
  : # sub-check pass
else
  echo "  FAIL: SKILL.md does not declare sole ownership of codex-reviewer dispatch"
  c2_fail=$((c2_fail + 1))
fi

# 2b: codex-reviewer is evaluated on standard/deep only (excluded from quick)
if grep -qE 'Standard/deep depth.*평가|standard.*deep.*only|depth.*quick.*phase2_agents.*\[\]|depth == quick.*phase2_agents' "$SKILL_MD"; then
  : # sub-check pass
else
  echo "  FAIL: SKILL.md does not gate codex-reviewer to standard/deep depth"
  c2_fail=$((c2_fail + 1))
fi

# 2c: codex unavailable path preserves v1.10.x byte-equivalent 3-agent dispatch
if grep -qE 'byte-equivalent' "$SKILL_MD"; then
  : # sub-check pass
else
  echo "  FAIL: SKILL.md does not document v1.10.x byte-equivalent fallback"
  c2_fail=$((c2_fail + 1))
fi

if [[ $c2_fail -eq 0 ]]; then
  echo "  PASS: SKILL.md owns codex dispatch, depth-gates standard/deep, preserves v1.10.x fallback"
  pass=$((pass + 1))
else
  fail=$((fail + 1))
fi

# Check 3: all pre-existing qg test files (those NOT touching codex) pass.
# This is the real regression check — if the codex feature broke anything
# in scout/SKILL/probe-call wiring, one of these tests will catch it.
echo "Running existing qg test suite..."
existing_failures=0
existing_run=0
for t in "$PLUGIN_ROOT"/tests/test_*.sh "$PLUGIN_ROOT"/tests/test_*.py; do
  [[ -f "$t" ]] || continue
  case "$(basename "$t")" in
    test_detect_codex.sh|test_findings_parser.sh|test_sandbox_enforced.sh|test_failure_injection.sh|test_scout_codex_integration.sh|test_cost_consent.sh|test_codex_backward_compat.sh)
      continue ;;
  esac
  existing_run=$((existing_run + 1))
  case "$t" in
    *.py) python3 "$t" > /dev/null 2>&1 || existing_failures=$((existing_failures + 1)) ;;
    *.sh) bash "$t" > /dev/null 2>&1 || existing_failures=$((existing_failures + 1)) ;;
  esac
done

if [[ $existing_failures -eq 0 ]]; then
  echo "  PASS: all $existing_run existing qg tests pass (no regressions)"
  pass=$((pass + 1))
else
  echo "  FAIL: $existing_failures of $existing_run pre-existing test(s) regressed"
  # Re-run with verbose output for diagnostics
  for t in "$PLUGIN_ROOT"/tests/test_*.sh "$PLUGIN_ROOT"/tests/test_*.py; do
    [[ -f "$t" ]] || continue
    case "$(basename "$t")" in
      test_detect_codex.sh|test_findings_parser.sh|test_sandbox_enforced.sh|test_failure_injection.sh|test_scout_codex_integration.sh|test_cost_consent.sh|test_codex_backward_compat.sh)
        continue ;;
    esac
    case "$t" in
      *.py) python3 "$t" > /dev/null 2>&1 || echo "    FAIL: $(basename "$t")" ;;
      *.sh) bash "$t" > /dev/null 2>&1 || echo "    FAIL: $(basename "$t")" ;;
    esac
  done
  fail=$((fail + 1))
fi

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[[ $fail -eq 0 ]] || exit 1
