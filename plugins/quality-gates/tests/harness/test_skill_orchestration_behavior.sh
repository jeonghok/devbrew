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
#   - Review gate → Runtime gate dispatch line order monotonic
#   - All 4 reviewer agents present in Review/Runtime gate fan-out (consistency w/ C1)
#   - Review gate iter cap within proximity of AskUserQuestion section
#   - DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS within 100 lines of Runtime gate dispatch
#   - Retry-path AskUserQuestion block lies between Review gate and Runtime gate

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
review_line=$(first_line 'subagent_type.*quality-gates:adversarial')
runtime_line=$(first_line 'subagent_type.*runtime-verifier')

assert_line "Review gate adversarial dispatch"   "$review_line"
assert_line "Runtime gate runtime-verifier dispatch" "$runtime_line"

# Ordering: Review gate < Runtime gate.
assert_order "Review precedes Runtime" "$review_line" "$runtime_line"

# Four reviewer agents in Review / Runtime gate fan-out (consistency with C1 / AC1).
for agent in adversarial test-scope-validator security-reviewer runtime-verifier; do
  if grep -qE "subagent_type[^\"]*\"quality-gates:$agent" "$SKILL_MD"; then
    echo "PASS: $agent dispatch present"
  else
    echo "FAIL: $agent dispatch missing"
    fail=$((fail + 1))
  fi
done

# Review gate iter cap proximity to Review gate section / AskUserQuestion.
# Use FIRST AskUserQuestion at or after the adversarial dispatch (the
# description's top-of-file AskUserQuestion mention is irrelevant; we want the
# Review-gate decision-tool call).
askuser_review_line=$(first_line_after 'AskUserQuestion' "$review_line")
itercap_line=$(first_line 'max_review_iterations')
assert_proximity "iter cap near Review gate AskUserQuestion" "$askuser_review_line" "$itercap_line" 80

# DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS near Runtime gate dispatch — use first mention
# AT OR AFTER the Runtime gate dispatch line (the top-of-file "up to ..." preview
# mention is irrelevant; we want the Runtime NEEDS_RESOLUTION section reference).
runtime_max_line=$(first_line_after 'DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS' "$runtime_line")
assert_proximity "RUNTIME_MAX_RESOLUTIONS near Runtime dispatch" "$runtime_line" "$runtime_max_line" 100

# Retry-path AskUserQuestion (I6) between Review gate dispatch and Runtime gate dispatch.
retry_line=$(first_line 'Retry: error handling|Retry failed')
if [[ "$retry_line" -gt 0 && "$retry_line" -gt "$review_line" && "$retry_line" -lt "$runtime_line" ]]; then
  echo "PASS: Retry block between Review gate ($review_line) and Runtime gate ($runtime_line) at $retry_line"
else
  echo "FAIL: Retry block not between Review gate ($review_line) and Runtime gate ($runtime_line); found at $retry_line"
  fail=$((fail + 1))
fi

if [[ "$fail" -eq 0 ]]; then
  echo "test_skill_orchestration_behavior: all protocol-shape assertions PASS"
  exit 0
else
  echo "test_skill_orchestration_behavior: $fail assertion(s) FAILED"
  exit 1
fi
