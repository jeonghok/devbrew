#!/usr/bin/env bash
# AC7 — handoff_incomplete is wired into the design-mode checklist (7th category).
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/spec-reviewer.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# Locate design mode section
design_start=$(grep -n "^### Design Mode Branch" "$AGENT" | head -1 | cut -d: -f1)
[[ -n "$design_start" ]] && note PASS "AC7: design mode section located (line $design_start)" \
  || { note FAIL "design mode section header missing"; exit 1; }

# Within the design mode block, all 6 existing categories + handoff_incomplete must appear.
design_block=$(sed -n "${design_start},/^## /p" "$AGENT")

for cat in "placeholder" "ambiguity" "scope_creep" "approaches_comparison" "isolation" "testing" "handoff_incomplete"; do
  echo "$design_block" | grep -q "$cat" \
    && note PASS "AC7: design category '$cat' present" \
    || note FAIL "AC7 design category '$cat' missing"
done

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
