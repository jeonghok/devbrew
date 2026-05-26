#!/usr/bin/env bash
# AC2 — agents/spec-reviewer.md must define `handoff_incomplete` category that
# fires when `## Handoff Context` section is absent.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/spec-reviewer.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# AC2a: `handoff_incomplete` 카테고리 ID 존재
grep -q 'handoff_incomplete' "$AGENT" \
  && note PASS "AC2: handoff_incomplete category defined" \
  || note FAIL "AC2 handoff_incomplete category missing"

# AC2b: `## Handoff Context` section 검사 명시
grep -qE '## Handoff Context|Handoff Context.*섹션' "$AGENT" \
  && note PASS "AC2: '## Handoff Context' section check referenced" \
  || note FAIL "AC2 section check missing from agent"

# AC2c: severity block-level
grep -qE 'handoff_incomplete.*block|block.*handoff_incomplete' "$AGENT" \
  && note PASS "AC2: handoff_incomplete is block-severity" \
  || note FAIL "AC2 handoff_incomplete severity not block"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
