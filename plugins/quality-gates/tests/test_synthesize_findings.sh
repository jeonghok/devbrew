#!/usr/bin/env bash
# AC34-AC39 — synthesize_findings.py deterministic post-processing.
set -euo pipefail
SCRIPT="plugins/quality-gates/scripts/synthesize_findings.py"
PASS=0; FAIL=0

run_case() {
  local name="$1" adv_yaml="$2" findings_yaml="$3" expected_grep="$4" expected_neg="$5"
  local tmp; tmp="$(mktemp -d)"
  echo "$adv_yaml" > "$tmp/adv.yaml"
  echo "$findings_yaml" > "$tmp/findings.yaml"
  local out; out=$(python3 "$SCRIPT" --adversarial "$tmp/adv.yaml" --findings "$tmp/findings.yaml")
  # Collapse newlines for multi-line pattern matching
  local out_flat; out_flat=$(echo "$out" | tr '\n' ' ')
  local ok=1
  if [[ -n "$expected_grep" ]] && ! echo "$out_flat" | grep -qE "$expected_grep"; then ok=0; fi
  if [[ -n "$expected_neg" ]] && echo "$out_flat" | grep -qE "$expected_neg"; then ok=0; fi
  if [[ "$ok" -eq 1 ]]; then
    echo "PASS: $name"; PASS=$((PASS+1))
  else
    echo "FAIL: $name"
    echo "    expected_grep='$expected_grep' expected_neg='$expected_neg'"
    echo "    got:"; echo "$out" | sed 's/^/      /'
    FAIL=$((FAIL+1))
  fi
  rm -rf "$tmp"
}

# AC34 dedup
run_case "AC34 dedup" \
  'verdicts: []' \
  '- {agent: code-reviewer, file: a.py, line: 10, severity: IMPORTANT, confidence: 8, summary: x, proposed_fix: y}
- {agent: silent-failure-hunter, file: a.py, line: 10, severity: IMPORTANT, confidence: 6, summary: x, proposed_fix: y}' \
  'a.py:10' ''

# AC35 reject
run_case "AC35 reject" \
  '- {finding_id: code-reviewer-a.py-10, verdict: reject, reason: x}' \
  '- {agent: code-reviewer, file: a.py, line: 10, severity: CRITICAL, confidence: 9, summary: bug, proposed_fix: fix}' \
  'No high-confidence' 'a.py:10'

# AC36 suppress<7 except CRITICAL
run_case "AC36 suppress" \
  'verdicts: []' \
  '- {agent: code-reviewer, file: a.py, line: 1, severity: IMPORTANT, confidence: 5, summary: low, proposed_fix: x}
- {agent: code-reviewer, file: b.py, line: 1, severity: CRITICAL, confidence: 4, summary: crit-low, proposed_fix: y}' \
  'b.py:1' 'a.py:1'

# AC37 sort order
run_case "AC37 sort" \
  'verdicts: []' \
  '- {agent: r, file: a.py, line: 1, severity: SUGGESTION, confidence: 9, summary: s, proposed_fix: f}
- {agent: r, file: b.py, line: 1, severity: CRITICAL, confidence: 9, summary: c, proposed_fix: f}' \
  '### CRITICAL' ''

# AC38 schema headers
run_case "AC38 headers" \
  'verdicts: []' \
  '- {agent: r, file: a.py, line: 1, severity: CRITICAL, confidence: 9, summary: s, proposed_fix: f}' \
  '## Review Findings.*### CRITICAL' ''

# AC39 empty
run_case "AC39 empty" \
  'verdicts: []' \
  '' \
  'No high-confidence findings' ''

echo ""
echo "Total: $((PASS+FAIL)), PASS=$PASS, FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
