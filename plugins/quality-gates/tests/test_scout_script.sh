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

# --- AC5 (v2.13.0): docs_touched → comment-analyzer phase2 hint ---
# 경계 = filter-docs.sh doc-path 집합(오케스트레이터가 boolean 계산); scout는 라우팅만.
phase2_has() {  # phase2_has <json> <token> <PRESENT|ABSENT>
  local out; out=$(echo "$1" | python3 "$SCRIPT")
  local p2; p2=$(echo "$out" | grep '^phase2_agents:')
  if echo "$p2" | grep -q "$2"; then local got=PRESENT; else local got=ABSENT; fi
  if [[ "$got" == "$3" ]]; then
    echo "PASS: docs_touched case — '$2' $3 ($p2)"; PASS=$((PASS+1))
  else
    echo "FAIL: docs_touched case — '$2' want $3 got $got ($p2)"; FAIL=$((FAIL+1))
  fi
}

# quick-depth pure-docs diff still surfaces comment-analyzer (gap closure).
phase2_has '{"changed_lines": 10, "docs_touched": true}' 'comment-analyzer' PRESENT
# standard-depth docs change → comment-analyzer present.
phase2_has '{"changed_lines": 80, "docs_touched": true}' 'comment-analyzer' PRESENT
# no docs → comment-analyzer absent (no false hint).
phase2_has '{"changed_lines": 80, "docs_touched": false}' 'comment-analyzer' ABSENT
# docs_touched omitted entirely → absent (default false, backward-compat).
phase2_has '{"changed_lines": 80}' 'comment-analyzer' ABSENT
# deep + docs + type_design → both hints coexist.
phase2_has '{"changed_lines": 300, "type_design": true, "docs_touched": true}' 'comment-analyzer' PRESENT
phase2_has '{"changed_lines": 300, "type_design": true, "docs_touched": true}' 'type-design-analyzer' PRESENT

echo ""
echo "Total: $((PASS+FAIL)), PASS=$PASS, FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
