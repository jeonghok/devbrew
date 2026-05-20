#!/usr/bin/env bash
# AC1 verification — resolve_session_id() precedence + charset/length validation.
set -uo pipefail

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hooks"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

# call_resolve <payload-json-or-empty> [KEY=VALUE ...]
# Runs resolve_session_id in a clean environment (only PATH inherited).
# Extra KEY=VALUE pairs are passed as additional env vars.
call_resolve() {
    local payload="$1"; shift
    local extra_vars=("$@")
    env -i "PATH=$PATH" "${extra_vars[@]+"${extra_vars[@]}"}" python3 -c "
import sys, json, os
sys.path.insert(0, '$HOOKS_DIR')
from state_path import resolve_session_id
p = json.loads('''$payload''') if '$payload' else None
r = resolve_session_id(p)
print(r if r is not None else '<none>')
" 2>/dev/null
}

# Case 1: test override + CLAUDE_CODE_SESSION_ID both set → test override wins
result="$(call_resolve '' \
    DEVBREW_SPEC_DISTILL_SESSION_ID=override-12345678 \
    CLAUDE_CODE_SESSION_ID=ccsid-87654321)"
[[ "$result" == "override-12345678" ]] \
    && note PASS "case 1: test override precedence" \
    || note FAIL "case 1: test override precedence"

# Case 2: only CLAUDE_CODE_SESSION_ID set
result="$(call_resolve '' CLAUDE_CODE_SESSION_ID=ccsid-87654321)"
[[ "$result" == "ccsid-87654321" ]] \
    && note PASS "case 2: CLAUDE_CODE_SESSION_ID fallback" \
    || note FAIL "case 2: CLAUDE_CODE_SESSION_ID fallback"

# Case 3: env unset, payload has session_id
result="$(call_resolve '{"session_id":"payload-12345678"}')"
[[ "$result" == "payload-12345678" ]] \
    && note PASS "case 3: payload fallback" \
    || note FAIL "case 3: payload fallback"

# Case 4: all sources empty → None
result="$(call_resolve '')"
[[ "$result" == "<none>" ]] \
    && note PASS "case 4: None on unresolved" \
    || note FAIL "case 4: None on unresolved"

# Case 5: test override empty string + CLAUDE_CODE_SESSION_ID set → fallback (empty=falsy)
result="$(call_resolve '' DEVBREW_SPEC_DISTILL_SESSION_ID= CLAUDE_CODE_SESSION_ID=ccsid-87654321)"
[[ "$result" == "ccsid-87654321" ]] \
    && note PASS "case 5: empty string falls through" \
    || note FAIL "case 5: empty string falls through"

# Case 6: session_id with spaces → charset reject
result="$(call_resolve '' 'CLAUDE_CODE_SESSION_ID=with spaces')"
[[ "$result" == "<none>" ]] \
    && note PASS "case 6: charset reject (spaces)" \
    || note FAIL "case 6: charset reject (spaces)"

# Case 7: traversal/slash/dot → charset reject
for bad in "../traversal" "with/slash" "with.dot"; do
    result="$(call_resolve '' "CLAUDE_CODE_SESSION_ID=$bad")"
    [[ "$result" == "<none>" ]] \
        && note PASS "case 7: charset reject ($bad)" \
        || note FAIL "case 7: charset reject ($bad)"
done

# Case 8: length < 8 reject
result="$(call_resolve '' CLAUDE_CODE_SESSION_ID=abc)"
[[ "$result" == "<none>" ]] \
    && note PASS "case 8: length reject (< 8)" \
    || note FAIL "case 8: length reject (< 8)"

# Case 9: exactly 8 chars accept
result="$(call_resolve '' CLAUDE_CODE_SESSION_ID=a1b2c3d4)"
[[ "$result" == "a1b2c3d4" ]] \
    && note PASS "case 9: exactly 8 chars" \
    || note FAIL "case 9: exactly 8 chars"

# Case 10: UUID format accept
result="$(call_resolve '' CLAUDE_CODE_SESSION_ID=a3f8b1c2-4d5e-6f7a-8b9c-0d1e2f3a4b5c)"
[[ "$result" == "a3f8b1c2-4d5e-6f7a-8b9c-0d1e2f3a4b5c" ]] \
    && note PASS "case 10: UUID format" \
    || note FAIL "case 10: UUID format"

# Case 11: 256 chars accept (charset valid)
long_sid=$(printf '%.0sa' {1..256})
result="$(call_resolve '' "CLAUDE_CODE_SESSION_ID=$long_sid")"
[[ "$result" == "$long_sid" ]] \
    && note PASS "case 11: 256-char accept" \
    || note FAIL "case 11: 256-char accept"

if [[ "$fail" -gt 0 ]]; then
    echo "FAILED: $fail case(s)"
    exit 1
fi
echo "PASSED: 11 cases"
