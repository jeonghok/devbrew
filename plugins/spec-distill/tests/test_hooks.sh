#!/usr/bin/env bash
# spec-distill — minimal hook regression tests.
# Run: bash plugins/spec-distill/tests/test_hooks.sh
# Exits 0 on all pass, 1 on any failure.

set -u
set -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PLUGIN_ROOT="$REPO_ROOT/plugins/spec-distill"
TRIGGER="$PLUGIN_ROOT/hooks/interview-trigger.sh"
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

echo "=== interview-trigger.sh ==="

# 1. Kill switch: DEVBREW_DISABLE_SPEC_DISTILL=1 → silent
out=$(DEVBREW_DISABLE_SPEC_DISTILL=1 bash "$TRIGGER" <<< '{"user_prompt":"build me a thing"}' 2>/dev/null || true)
[[ -z "$out" ]] && note PASS "DEVBREW_DISABLE_SPEC_DISTILL=1 suppresses output" \
                || note FAIL "DEVBREW_DISABLE_SPEC_DISTILL=1 suppresses output (got: $out)"

# 2. Kill switch: DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit → silent
out=$(DEVBREW_SKIP_HOOKS="spec-distill:UserPromptSubmit" bash "$TRIGGER" <<< '{"user_prompt":"build me a thing"}' 2>/dev/null || true)
[[ -z "$out" ]] && note PASS "DEVBREW_SKIP_HOOKS exact match suppresses output" \
                || note FAIL "DEVBREW_SKIP_HOOKS exact match suppresses output (got: $out)"

# 3. Kill switch isolation: a different hook in DEVBREW_SKIP_HOOKS does NOT suppress
out=$(DEVBREW_SKIP_HOOKS="spec-distill:SessionStart" bash "$TRIGGER" <<< '{"user_prompt":"build me a thing"}' 2>/dev/null || true)
echo "$out" | grep -q "systemMessage" \
  && note PASS "DEVBREW_SKIP_HOOKS for different hook does not affect this hook" \
  || note FAIL "DEVBREW_SKIP_HOOKS isolation broken (got: $out)"

# 4. Kill switch: prefix-injection guard (notspec-distill:... must NOT match)
out=$(DEVBREW_SKIP_HOOKS="notspec-distill:UserPromptSubmit" bash "$TRIGGER" <<< '{"user_prompt":"build me a thing"}' 2>/dev/null || true)
echo "$out" | grep -q "systemMessage" \
  && note PASS "Prefix-injection in DEVBREW_SKIP_HOOKS is rejected" \
  || note FAIL "Prefix-injection bypass succeeded (got: $out)"

# 5. Happy path: keyword + short prompt → systemMessage emitted
out=$(bash "$TRIGGER" <<< '{"user_prompt":"build me a todo app"}' 2>/dev/null)
echo "$out" | grep -q '"systemMessage"' \
  && note PASS "Keyword+short prompt emits systemMessage JSON" \
  || note FAIL "Keyword+short prompt did not emit systemMessage (got: $out)"

# 6. No keyword → silence
out=$(bash "$TRIGGER" <<< '{"user_prompt":"explain how this works"}' 2>/dev/null || true)
[[ -z "$out" ]] && note PASS "No keyword → silent" \
                || note FAIL "No keyword should be silent (got: $out)"

# 7. Long prompt (≥20 words) → silence (verify on natural-English long prompt)
LONG='{"user_prompt":"build a comprehensive authentication system with OAuth support and audit logging and rate limiting and session timeout and forgotten password recovery flows"}'
out=$(bash "$TRIGGER" <<< "$LONG" 2>/dev/null || true)
[[ -z "$out" ]] && note PASS "Long prompt (≥20 words) → silent" \
                || note FAIL "Long prompt should be silent (got: $out)"

# 8. Re-entrancy guard: /interview prefix → silence
out=$(bash "$TRIGGER" <<< '{"user_prompt":"/interview build me a thing"}' 2>/dev/null || true)
[[ -z "$out" ]] && note PASS "/interview prefix → silent (re-entrancy guard)" \
                || note FAIL "/interview prefix should be silent (got: $out)"

echo ""
echo "=== session-anchor.sh ==="

TMPSTATE=$(mktemp -d)
trap 'rm -rf "$TMPSTATE"' EXIT

# 9. No state dir → silent
out=$(CLAUDE_PROJECT_DIR="$TMPSTATE" bash "$ANCHOR" < /dev/null 2>/dev/null || true)
[[ -z "$out" ]] && note PASS "No state dir → silent" \
                || note FAIL "No state dir should be silent (got: $out)"

# 10. State file present → systemMessage emitted
mkdir -p "$TMPSTATE/.claude/spec-distill/test-session-id"
echo "---" > "$TMPSTATE/.claude/spec-distill/test-session-id/state.local.md"
out=$(CLAUDE_PROJECT_DIR="$TMPSTATE" bash "$ANCHOR" < /dev/null 2>/dev/null)
echo "$out" | grep -q '"systemMessage"' \
  && note PASS "State file present → emits systemMessage JSON" \
  || note FAIL "State file should emit systemMessage (got: $out)"

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
