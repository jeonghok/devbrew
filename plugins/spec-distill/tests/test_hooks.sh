#!/usr/bin/env bash
# spec-distill — minimal hook regression tests.
# Run: bash plugins/spec-distill/tests/test_hooks.sh
# Exits 0 on all pass, 1 on any failure.

set -u
set -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PLUGIN_ROOT="$REPO_ROOT/plugins/spec-distill"
ANCHOR="$PLUGIN_ROOT/hooks/session-anchor.sh"

pass=0
fail=0

note() {
  if [[ "$1" == "PASS" ]]; then
    pass=$((pass+1))
    echo "  ✓ $2"
  else
    fail=$((fail+1))
    echo "  ✗ $2"
  fi
}

echo "=== session-anchor.sh ==="

TMPSTATE=$(mktemp -d)
trap 'rm -rf "$TMPSTATE"' EXIT

# 9. No state dir → silent
out=$(CLAUDE_PROJECT_DIR="$TMPSTATE" bash "$ANCHOR" < /dev/null 2>/dev/null || true)
[[ -z "$out" ]] && note PASS "No state dir → silent" \
                || note FAIL "No state dir should be silent (got: $out)"

# 10. State file present → SessionStart dual-target emit
mkdir -p "$TMPSTATE/.claude/spec-distill/test-session-id"
echo "---" > "$TMPSTATE/.claude/spec-distill/test-session-id/state.local.md"
out=$(CLAUDE_PROJECT_DIR="$TMPSTATE" bash "$ANCHOR" < /dev/null 2>/dev/null)
echo "$out" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' >/dev/null \
  && echo "$out" | jq -e '.hookSpecificOutput.additionalContext | length > 0' >/dev/null \
  && echo "$out" | jq -e '.systemMessage | startswith("[spec-distill]")' >/dev/null \
  && note PASS "State file present → emits dual-target (additionalContext + systemMessage)" \
  || note FAIL "State file should emit dual-target schema (got: $out)"

# 11. Mutation regression: session-anchor.sh does NOT modify any file
before=$(find "$TMPSTATE/.claude" -type f 2>/dev/null | sort | xargs md5sum 2>/dev/null | md5sum | awk '{print $1}')
CLAUDE_PROJECT_DIR="$TMPSTATE" bash "$ANCHOR" < /dev/null > /dev/null 2>&1 || true
after=$(find "$TMPSTATE/.claude" -type f 2>/dev/null | sort | xargs md5sum 2>/dev/null | md5sum | awk '{print $1}')
[[ "$before" == "$after" ]] && note PASS "session-anchor.sh does not mutate files (md5 unchanged)" \
                            || note FAIL "session-anchor.sh mutated files (P14 violation)"

# 12. Kill switch isolation for SessionStart: trigger hook unaffected
out=$(DEVBREW_SKIP_HOOKS="spec-distill:SessionStart" \
      CLAUDE_PROJECT_DIR="$TMPSTATE" \
      bash "$ANCHOR" < /dev/null 2>/dev/null || true)
[[ -z "$out" ]] && note PASS "DEVBREW_SKIP_HOOKS=spec-distill:SessionStart suppresses anchor" \
                || note FAIL "SessionStart kill switch did not suppress (got: $out)"

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
