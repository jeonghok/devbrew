#!/usr/bin/env bash
# AC49-AC52 — README state-machine diagram drift detection.
#
# Asserts the README contains exactly one Mermaid stateDiagram-v2 block
# whose transition names match the 13-row authoritative set from the spec.

set -euo pipefail
README="plugins/quality-gates/README.md"

# AC50: exactly one stateDiagram-v2 block.
count_diag=$(grep -c 'stateDiagram-v2' "$README")
[[ "$count_diag" -eq 1 ]] || { echo "FAIL AC50: stateDiagram-v2 count=$count_diag (expected 1)"; exit 1; }

# AC51: at least 2 terminal/state markers ([*] or completed/aborted text).
count_term=$(grep -cE '\[\*\]|completed|aborted' "$README")
[[ "$count_term" -ge 2 ]] || { echo "FAIL AC51: terminal markers=$count_term (expected ≥2)"; exit 1; }

# AC49 + AC52: 13 transition names exactly equal expected set (no missing, no superset).
PATTERN='\b(next_gate|retry_gate|complete|abort|continue|gate2_user_choice|max_gate2_exceeded|gate3_fail|gate3_needs_resolution|gate3_repeat_detected|wall_clock_exceeded|no_signal_inc|no_signal_max)\b'
README_SET=$(awk '/^```mermaid$/,/^```$/' "$README" \
  | grep -oE "$PATTERN" | sort -u)
EXPECTED_SET=$(printf '%s\n' \
  next_gate retry_gate complete abort continue gate2_user_choice \
  max_gate2_exceeded gate3_fail gate3_needs_resolution gate3_repeat_detected \
  wall_clock_exceeded no_signal_inc no_signal_max | sort -u)

if ! diff <(echo "$README_SET") <(echo "$EXPECTED_SET") >/dev/null; then
  echo "FAIL AC49/AC52: README mermaid diagram transition set differs from expected."
  echo "--- README has ---"
  echo "$README_SET"
  echo "--- expected ---"
  echo "$EXPECTED_SET"
  exit 1
fi

echo "PASS AC49/AC50/AC51/AC52: README state-machine diagram complete (13 transitions)"
