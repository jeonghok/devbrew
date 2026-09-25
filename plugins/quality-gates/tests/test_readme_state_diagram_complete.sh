#!/usr/bin/env bash
# README state-diagram drift detection (I12, v1.32.1).
#
# v1.32.0 redesign replaced the Mermaid stateDiagram-v2 (turn-by-turn
# Stop-hook state machine, 13 transitions) with a single ASCII diagram
# representing the in-turn AskUserQuestion-driven pipeline. This test
# now asserts that ONE canonical pipeline diagram exists in the README
# and contains the v1.32.0 protocol-shape markers expected by the design.

set -euo pipefail
README="plugins/quality-gates/README.md"

[[ -f "$README" ]] || { echo "FAIL: README missing at $README"; exit 1; }

# 1. No Mermaid stateDiagram-v2 block (was removed in v1.32.0).
if grep -q 'stateDiagram-v2' "$README"; then
  echo "FAIL: stateDiagram-v2 still present (v1.32.0 removed it)"
  exit 1
fi

# 2. Exactly one v1.32.0 ASCII pipeline diagram (delimited by
#    "single assistant turn" header line inside a fenced block).
turn_diagrams=$(grep -c 'single assistant turn' "$README" || true)
[[ "$turn_diagrams" -eq 1 ]] || {
  echo "FAIL: expected exactly 1 'single assistant turn' diagram header, got $turn_diagrams"
  exit 1
}

# 3. Protocol-shape markers inside the diagram (each must appear at least once).
EXPECTED_MARKERS=(
  "setup-qg.sh"
  "SKILL preflight"
  "trivia escape"
  "qg iter loop"
  "② differential test"
  "⑤ synthesize → verdict"
  "AskUserQuestion"
  "findings remain"
  "Final summary"
)
missing=()
for marker in "${EXPECTED_MARKERS[@]}"; do
  if ! grep -qF "$marker" "$README"; then
    missing+=("$marker")
  fi
done

if [[ "${#missing[@]}" -gt 0 ]]; then
  echo "FAIL: README v1.32.0 pipeline diagram missing markers:"
  printf '  - %s\n' "${missing[@]}"
  exit 1
fi

# Negative lock — two-gate diagram markers must not survive the one-pipeline
# merge (positive markers above are the paired mutation target).
for gone in "Runtime gate dispatch" "Review gate iter loop" "gate scope?" "NEEDS_RESOLUTION"; do
  if grep -qF "$gone" "$README"; then
    echo "FAIL: README still carries the two-gate diagram marker: $gone"
    exit 1
  fi
done

echo "PASS: README v1.32.0 pipeline diagram complete (${#EXPECTED_MARKERS[@]} markers + no stateDiagram-v2)"
