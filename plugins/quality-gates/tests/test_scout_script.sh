#!/usr/bin/env bash
# AC29-AC33 — scout.py deterministic depth/agent selection.
set -euo pipefail
SCRIPT="plugins/quality-gates/scripts/scout.py"
PASS=0; FAIL=0

run_case() {
  local name="$1" step0_json="$2" expected_depth="$3"
  local out; out=$(echo "$step0_json" | python3 "$SCRIPT")
  local ok=1
  # AC30: depth matches expected
  echo "$out" | grep -q "^depth: $expected_depth" || ok=0
  # AC29: schema keys present
  for k in depth phase1_agents phase2_agents rationale fallback; do
    echo "$out" | grep -q "^$k:" || ok=0
  done
  # AC33: fallback is always false
  echo "$out" | grep -q '^fallback: false' || ok=0
  if [[ "$ok" -eq 1 ]]; then
    echo "PASS: $name (depth=$expected_depth)"; PASS=$((PASS+1))
  else
    echo "FAIL: $name"; echo "$out" | sed 's/^/    /'
    FAIL=$((FAIL+1))
  fi
}

run_case "small whitespace-only" \
  '{"changed_lines": 5, "new_files": 0, "config_touched": false, "type_design": false, "test_change": false}' \
  quick

run_case "medium new-files" \
  '{"changed_lines": 80, "new_files": 1, "config_touched": false, "type_design": false, "test_change": false}' \
  deep

run_case "large config-touched" \
  '{"changed_lines": 250, "new_files": 0, "config_touched": true, "type_design": false, "test_change": false}' \
  deep

run_case "large+type-design" \
  '{"changed_lines": 300, "new_files": 2, "config_touched": false, "type_design": true, "test_change": false}' \
  deep

run_case "large+test-only" \
  '{"changed_lines": 200, "new_files": 0, "config_touched": false, "type_design": false, "test_change": true}' \
  deep

echo ""
echo "Total: $((PASS+FAIL)), PASS=$PASS, FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
