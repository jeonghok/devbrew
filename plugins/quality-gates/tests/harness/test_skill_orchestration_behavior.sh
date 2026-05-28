#!/usr/bin/env bash
# test_skill_orchestration_behavior.sh — protocol-shape test for SKILL.md.
#
# Asserts the prompt-defined orchestration protocol exists in SKILL.md with
# expected ordering, proximity, and section membership. Does NOT execute
# SKILL.md at runtime; this is a STATIC protocol-shape verifier that replaces
# V7's tautological substring grep (V7 looked for `PASS` token that never
# appeared, so its negative-assertion path was unreachable).
#
# Coverage (spec §5.6.9):
#   - Gate 1 → Gate 2 → Gate 3 dispatch line order monotonic
#   - All 4 reviewer agents present in Gate 2/3 fan-out (consistency w/ C1)
#   - Gate 2 iter cap within 50 lines of AskUserQuestion section
#   - DEVBREW_GATE3_MAX_RESOLUTIONS within 100 lines of Gate 3 dispatch
#   - Retry-path AskUserQuestion block lies between Gate 2 and Gate 3

set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILL_MD="$(cd -- "$SCRIPT_DIR/../.." && pwd)/skills/quality-pipeline/SKILL.md"

test -f "$SKILL_MD" || { echo "FAIL: SKILL.md not found at $SKILL_MD"; exit 1; }

fail=0

first_line() {
  # First line number where $1 (extended regex) matches, or "0" if absent.
  local pat="$1"
  awk -v p="$pat" '$0 ~ p { print NR; exit }' "$SKILL_MD" \
    | { read -r n || true; echo "${n:-0}"; }
}

first_line_after() {
  # First line number > $2 where $1 matches, or "0" if absent.
  local pat="$1" after="$2"
  awk -v p="$pat" -v a="$after" '
    NR > a && $0 ~ p { print NR; exit }
  ' "$SKILL_MD" | { read -r n || true; echo "${n:-0}"; }
}

assert_line() {
  local label="$1" line="$2"
  if [[ "$line" -gt 0 ]]; then
    echo "PASS: $label (line $line)"
  else
    echo "FAIL: $label (pattern not found)"
    fail=$((fail + 1))
  fi
}

assert_order() {
  local label="$1" earlier="$2" later="$3"
  if [[ "$earlier" -gt 0 && "$later" -gt 0 && "$earlier" -lt "$later" ]]; then
    echo "PASS: $label (line $earlier < line $later)"
  else
    echo "FAIL: $label (earlier=$earlier later=$later)"
    fail=$((fail + 1))
  fi
}

assert_proximity() {
  local label="$1" a="$2" b="$3" within="$4"
  if [[ "$a" -gt 0 && "$b" -gt 0 ]]; then
    local d
    if [[ "$a" -gt "$b" ]]; then d=$((a - b)); else d=$((b - a)); fi
    if [[ "$d" -le "$within" ]]; then
      echo "PASS: $label (lines $a, $b within $within)"
    else
      echo "FAIL: $label (lines $a, $b distance $d > $within)"
      fail=$((fail + 1))
    fi
  else
    echo "FAIL: $label (a=$a b=$b — missing markers)"
    fail=$((fail + 1))
  fi
}

# Gate dispatch lines.
gate1_line=$(first_line 'subagent_type.*plan-verifier')
gate2_line=$(first_line 'subagent_type.*quality-gates:adversarial')
gate3_line=$(first_line 'subagent_type.*runtime-verifier')

assert_line "Gate 1 plan-verifier dispatch" "$gate1_line"
assert_line "Gate 2 adversarial dispatch"   "$gate2_line"
assert_line "Gate 3 runtime-verifier dispatch" "$gate3_line"

# Ordering: Gate 1 < Gate 2 < Gate 3.
assert_order "Gate 1 precedes Gate 2" "$gate1_line" "$gate2_line"
assert_order "Gate 2 precedes Gate 3" "$gate2_line" "$gate3_line"

# Four reviewer agents in Gate 2 / Gate 3 fan-out (consistency with C1 / AC1).
for agent in adversarial test-scope-validator security-reviewer runtime-verifier; do
  if grep -qE "subagent_type[^\"]*\"quality-gates:$agent" "$SKILL_MD"; then
    echo "PASS: $agent dispatch present"
  else
    echo "FAIL: $agent dispatch missing"
    fail=$((fail + 1))
  fi
done

# Gate 2 iter cap proximity to Gate 2 section / AskUserQuestion.
# Use FIRST AskUserQuestion at or after the Gate 2 dispatch (the description's
# top-of-file AskUserQuestion mention is irrelevant; we want the Gate-2
# decision-tool call).
askuser_g2_line=$(first_line_after 'AskUserQuestion' "$gate2_line")
itercap_line=$(first_line 'max_gate2_iterations')
assert_proximity "iter cap near Gate 2 AskUserQuestion" "$askuser_g2_line" "$itercap_line" 80

# DEVBREW_GATE3_MAX_RESOLUTIONS near Gate 3 dispatch — use first mention
# AT OR AFTER the Gate 3 dispatch line (the top-of-file "up to ..." preview
# mention is irrelevant; we want the Gate 3 NEEDS_RESOLUTION section reference).
gate3_max_line=$(first_line_after 'DEVBREW_GATE3_MAX_RESOLUTIONS' "$gate3_line")
assert_proximity "GATE3_MAX_RESOLUTIONS near Gate 3 dispatch" "$gate3_line" "$gate3_max_line" 100

# Retry-path AskUserQuestion (I6) between Gate 2 dispatch and Gate 3 dispatch.
retry_line=$(first_line 'Retry: error handling|Retry failed')
if [[ "$retry_line" -gt 0 && "$retry_line" -gt "$gate2_line" && "$retry_line" -lt "$gate3_line" ]]; then
  echo "PASS: Retry block between Gate 2 ($gate2_line) and Gate 3 ($gate3_line) at $retry_line"
else
  echo "FAIL: Retry block not between Gate 2 ($gate2_line) and Gate 3 ($gate3_line); found at $retry_line"
  fail=$((fail + 1))
fi

if [[ "$fail" -eq 0 ]]; then
  echo "test_skill_orchestration_behavior: all protocol-shape assertions PASS"
  exit 0
else
  echo "test_skill_orchestration_behavior: $fail assertion(s) FAILED"
  exit 1
fi
