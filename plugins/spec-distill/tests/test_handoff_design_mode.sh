#!/usr/bin/env bash
# AC7 — handoff_incomplete is wired into the design-mode checklist (7th category).
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/spec-reviewer.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# Locate design mode section
design_start=$(grep -n "^### Design Mode Branch" "$AGENT" | head -1 | cut -d: -f1)
[[ -n "$design_start" ]] && ok "AC7: design mode section located (line $design_start)" \
  || { no "design mode section header missing"; exit 1; }

# Within the design mode block, all 6 existing categories + handoff_incomplete must appear.
# Bounded extraction: from `### Design Mode Branch` line to (but not including) the next H3
# sub-section or the next H2 section. Prevents range bleed into later sub-sections
# (adversarial F3 — previously `sed -n "${design_start},/^## /p"` bled across H3 boundaries).
design_block=$(awk -v start="$design_start" '
  NR < start { next }
  NR == start { in_block = 1; print; next }
  in_block && /^### / { exit }
  in_block && /^## / { exit }
  in_block { print }
' "$AGENT")

if [[ -z "$design_block" ]]; then
  no "AC7: design mode block extracted empty — check agent file structure"
  echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
  exit 1
fi

for cat in "placeholder" "ambiguity" "scope_creep" "approaches_comparison" "isolation" "testing" "handoff_incomplete"; do
  echo "$design_block" | grep -q "$cat" \
    && ok "AC7: design category '$cat' present" \
    || no "AC7 design category '$cat' missing"
done
finish
