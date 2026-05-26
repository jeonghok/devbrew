#!/usr/bin/env bash
# AC3 — handoff_incomplete fires when TL;DR / Implicit / Deferred 중 하나라도 비어있음.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/spec-reviewer.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# AC3: 3 sub-section labels referenced in agent
for label in "TL;DR" "Implicit context" "Deferred to plan"; do
  grep -qF "$label" "$AGENT" \
    && note PASS "AC3: sub-section '$label' referenced in agent" \
    || note FAIL "AC3 sub-section '$label' not in agent"
done

# AC3: empty-subsection 검출 로직 명시
grep -qE '비어.*있|empty|미작성' "$AGENT" \
  && note PASS "AC3: empty-subsection detection language present" \
  || note FAIL "AC3 empty-subsection detection missing"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
