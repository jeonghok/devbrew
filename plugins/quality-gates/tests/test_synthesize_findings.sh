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

# AC34 dedup + source-merge (table row)
run_case "AC34 dedup+merge" \
  'verdicts: []' \
  '- {agent: code-reviewer, file: a.py, line: 10, severity: IMPORTANT, confidence: 8, summary: x, proposed_fix: y}
- {agent: silent-failure-hunter, file: a.py, line: 10, severity: IMPORTANT, confidence: 6, summary: x, proposed_fix: y}' \
  'a\.py:10 \| 8 \| x \| code-reviewer, silent-failure-hunter' ''

# AC35 reject (unchanged behavior)
run_case "AC35 reject" \
  '- {finding_id: code-reviewer-a.py-10, verdict: reject, reason: x}' \
  '- {agent: code-reviewer, file: a.py, line: 10, severity: CRITICAL, confidence: 9, summary: bug, proposed_fix: fix}' \
  'No high-confidence' 'a.py:10'

# AC36a + AC36b intentionally share one 3-finding fixture, each asserting a different facet.
# AC36a rubric: conf5 non-CRIT shown WITH caveat; conf4 non-CRIT suppressed
run_case "AC36a conf5 shown+caveat / conf4 suppressed" \
  'verdicts: []' \
  '- {agent: r, file: shown5.py, line: 1, severity: IMPORTANT, confidence: 5, summary: mid, proposed_fix: x}
- {agent: r, file: hidden4.py, line: 1, severity: IMPORTANT, confidence: 4, summary: low, proposed_fix: y}
- {agent: r, file: crit4.py, line: 1, severity: CRITICAL, confidence: 4, summary: critlow, proposed_fix: z}' \
  'shown5\.py:1 \| 5 \*' 'hidden4\.py:1'

# AC36b rubric: CRITICAL always shown (conf4) WITH caveat
run_case "AC36b CRITICAL conf4 shown+caveat" \
  'verdicts: []' \
  '- {agent: r, file: shown5.py, line: 1, severity: IMPORTANT, confidence: 5, summary: mid, proposed_fix: x}
- {agent: r, file: hidden4.py, line: 1, severity: IMPORTANT, confidence: 4, summary: low, proposed_fix: y}
- {agent: r, file: crit4.py, line: 1, severity: CRITICAL, confidence: 4, summary: critlow, proposed_fix: z}' \
  'crit4\.py:1 \| 4 \*' ''

# AC-R4 conf6/conf7 boundary: 6 -> caveat, 7 -> no marker
run_case "ACR4 conf6 boundary caveat" \
  'verdicts: []' \
  '- {agent: r, file: z.py, line: 1, severity: IMPORTANT, confidence: 6, summary: s, proposed_fix: f}' \
  'z\.py:1 \| 6 \*' ''
run_case "ACR4 conf7 boundary no-marker" \
  'verdicts: []' \
  '- {agent: r, file: y.py, line: 1, severity: IMPORTANT, confidence: 7, summary: s, proposed_fix: f}' \
  'y\.py:1 \| 7 \|' '7 \*'

# AC37 sort: CRITICAL row precedes SUGGESTION row (no ### headings anymore)
run_case "AC37 sort CRIT<SUG" \
  'verdicts: []' \
  '- {agent: r, file: a.py, line: 1, severity: SUGGESTION, confidence: 9, summary: s, proposed_fix: f}
- {agent: r, file: b.py, line: 1, severity: CRITICAL, confidence: 9, summary: c, proposed_fix: f}' \
  'CRITICAL \| b\.py:1.*SUGGESTION \| a\.py:1' ''

# AC38 table header schema
run_case "AC38 table header" \
  'verdicts: []' \
  '- {agent: r, file: a.py, line: 1, severity: CRITICAL, confidence: 9, summary: s, proposed_fix: f}' \
  '## Review Findings.*\| Sev \| Path:Line \| Conf \| Summary \| Source \|' ''

# AC-R4 counts line: always-3-severity (zero counts) + no marker at conf>=7
run_case "ACR4 counts zero-fill + no-marker" \
  'verdicts: []' \
  '- {agent: r, file: x.py, line: 1, severity: IMPORTANT, confidence: 8, summary: s, proposed_fix: f}' \
  '\*\*Findings:\*\* 0 CRITICAL / 1 IMPORTANT / 0 SUGGESTION' '8 \*'

# AC-R4 suggested-fixes block below table
run_case "ACR4 fixes block" \
  'verdicts: []' \
  '- {agent: r, file: x.py, line: 1, severity: IMPORTANT, confidence: 8, summary: s, proposed_fix: parameterize}' \
  '\*\*Suggested fixes:\*\*.*`x\.py:1` —' ''

# AC-R4 caveat legend present when a caveat row exists
run_case "ACR4 caveat legend present" \
  'verdicts: []' \
  '- {agent: r, file: w.py, line: 1, severity: IMPORTANT, confidence: 5, summary: s, proposed_fix: f}' \
  '`\*` = confidence <= 6 \(treat with caution\)\.' ''

# AC-R4 caveat legend ABSENT when all shown findings are conf>=7
run_case "ACR4 caveat legend absent" \
  'verdicts: []' \
  '- {agent: r, file: x.py, line: 1, severity: IMPORTANT, confidence: 8, summary: s, proposed_fix: f}' \
  '' 'confidence <= 6 \(treat'

# AC-R4 suppressed notice line + counts tail (1 shown, 1 suppressed)
run_case "ACR4 suppressed notice + counts tail" \
  'verdicts: []' \
  '- {agent: r, file: x.py, line: 1, severity: IMPORTANT, confidence: 8, summary: s, proposed_fix: f}
- {agent: r, file: q.py, line: 1, severity: SUGGESTION, confidence: 3, summary: low, proposed_fix: f}' \
  'finding\(s\) suppressed \(conf <= 4\); re-run with `/qg --show-low-confidence` to see all\.' 'q\.py:1 \|'
run_case "ACR4 counts suppressed tail" \
  'verdicts: []' \
  '- {agent: r, file: x.py, line: 1, severity: IMPORTANT, confidence: 8, summary: s, proposed_fix: f}
- {agent: r, file: q.py, line: 1, severity: SUGGESTION, confidence: 3, summary: low, proposed_fix: f}' \
  '1 suppressed \(conf <= 4\)' ''

# ACR4 all-suppressed: render([], N>0) — kept=0 but suppressed>0 (AC-R4-11 empty-state path)
run_case "ACR4 all-suppressed empty-state" \
  'verdicts: []' \
  '- {agent: r, file: x.py, line: 1, severity: IMPORTANT, confidence: 3, summary: s, proposed_fix: f}' \
  'No high-confidence findings\. 1 low-confidence findings suppressed' 'x\.py:1'

# ACR4 no-suppression: suppressed notice + counts tail both absent (locks suppressed_count>0 guard)
run_case "ACR4 no-suppression notice absent" \
  'verdicts: []' \
  '- {agent: r, file: x.py, line: 1, severity: IMPORTANT, confidence: 8, summary: s, proposed_fix: f}' \
  '' 'finding\(s\) suppressed|suppressed \(conf <= 4\)'

# AC39 empty
run_case "AC39 empty" \
  'verdicts: []' \
  '' \
  'No high-confidence findings' ''

echo ""
echo "Total: $((PASS+FAIL)), PASS=$PASS, FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
