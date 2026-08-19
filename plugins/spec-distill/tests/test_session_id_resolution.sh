#!/usr/bin/env bash
# AC1 verification — resolve_session_id() precedence + charset/length validation.
set -uo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# call_resolve <payload-json-or-empty> [KEY=VALUE ...]
# Runs resolve_session_id in a clean environment (only PATH inherited).
# Extra KEY=VALUE pairs are passed as additional env vars.
call_resolve() {
    local payload="$1"; shift
    local extra_vars=("$@")
    env -i "PATH=$PATH" "${extra_vars[@]+"${extra_vars[@]}"}" python3 -c "
import sys, json, os
sys.path.insert(0, '$SCRIPTS_DIR')
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
    && ok "case 1: test override precedence" \
    || no "case 1: test override precedence"

# Case 2: only CLAUDE_CODE_SESSION_ID set
result="$(call_resolve '' CLAUDE_CODE_SESSION_ID=ccsid-87654321)"
[[ "$result" == "ccsid-87654321" ]] \
    && ok "case 2: CLAUDE_CODE_SESSION_ID fallback" \
    || no "case 2: CLAUDE_CODE_SESSION_ID fallback"

# Case 3: env unset, payload has session_id
result="$(call_resolve '{"session_id":"payload-12345678"}')"
[[ "$result" == "payload-12345678" ]] \
    && ok "case 3: payload fallback" \
    || no "case 3: payload fallback"

# Case 4: all sources empty → None
result="$(call_resolve '')"
[[ "$result" == "<none>" ]] \
    && ok "case 4: None on unresolved" \
    || no "case 4: None on unresolved"

# Case 5: test override empty string + CLAUDE_CODE_SESSION_ID set → fallback (empty=falsy)
result="$(call_resolve '' DEVBREW_SPEC_DISTILL_SESSION_ID= CLAUDE_CODE_SESSION_ID=ccsid-87654321)"
[[ "$result" == "ccsid-87654321" ]] \
    && ok "case 5: empty string falls through" \
    || no "case 5: empty string falls through"

# Case 6: session_id with spaces → charset reject
result="$(call_resolve '' 'CLAUDE_CODE_SESSION_ID=with spaces')"
[[ "$result" == "<none>" ]] \
    && ok "case 6: charset reject (spaces)" \
    || no "case 6: charset reject (spaces)"

# Case 7: traversal/slash/dot → charset reject
for bad in "../traversal" "with/slash" "with.dot"; do
    result="$(call_resolve '' "CLAUDE_CODE_SESSION_ID=$bad")"
    [[ "$result" == "<none>" ]] \
        && ok "case 7: charset reject ($bad)" \
        || no "case 7: charset reject ($bad)"
done

# Case 8: length < 8 reject
result="$(call_resolve '' CLAUDE_CODE_SESSION_ID=abc)"
[[ "$result" == "<none>" ]] \
    && ok "case 8: length reject (< 8)" \
    || no "case 8: length reject (< 8)"

# Case 9: exactly 8 chars accept
result="$(call_resolve '' CLAUDE_CODE_SESSION_ID=a1b2c3d4)"
[[ "$result" == "a1b2c3d4" ]] \
    && ok "case 9: exactly 8 chars" \
    || no "case 9: exactly 8 chars"

# Case 10: UUID format accept
result="$(call_resolve '' CLAUDE_CODE_SESSION_ID=a3f8b1c2-4d5e-6f7a-8b9c-0d1e2f3a4b5c)"
[[ "$result" == "a3f8b1c2-4d5e-6f7a-8b9c-0d1e2f3a4b5c" ]] \
    && ok "case 10: UUID format" \
    || no "case 10: UUID format"

# Case 11: 256 chars accept (charset valid)
long_sid=$(printf '%.0sa' {1..256})
result="$(call_resolve '' "CLAUDE_CODE_SESSION_ID=$long_sid")"
[[ "$result" == "$long_sid" ]] \
    && ok "case 11: 256-char accept" \
    || no "case 11: 256-char accept"

# ── session-id 서브커맨드 (AC9 / T3) ──────────────────────────────────────
STATE_PATH="$SCRIPTS_DIR/state_path.py"

# call_session_id [KEY=VALUE ...] — runs `state_path.py session-id` in clean env,
# echoes "<stdout>|<exit_code>".
call_session_id() {
    local out rc
    out="$(env -i "PATH=$PATH" "$@" python3 "$STATE_PATH" session-id 2>/dev/null)"; rc=$?
    printf '%s|%s' "$out" "$rc"
}

# Case 12: env set (CLAUDE_CODE_SESSION_ID) → prints value, exit 0
res="$(call_session_id CLAUDE_CODE_SESSION_ID=ccsid-87654321)"
[[ "$res" == "ccsid-87654321|0" ]] \
    && ok "case 12: session-id prints resolved sid, exit 0" \
    || no "case 12: session-id set (got '$res')"

# Case 13: DEVBREW override precedence honored by CLI
res="$(call_session_id DEVBREW_SPEC_DISTILL_SESSION_ID=override-12345678 CLAUDE_CODE_SESSION_ID=ccsid-87654321)"
[[ "$res" == "override-12345678|0" ]] \
    && ok "case 13: session-id honors DEVBREW override" \
    || no "case 13: session-id override (got '$res')"

# Case 14: env unset → NO stdout ("<none>" 미출력) + exit 1
res="$(call_session_id)"
[[ "$res" == "|1" ]] \
    && ok "case 14: session-id unset → empty stdout + exit 1" \
    || no "case 14: session-id unset (got '$res')"

# Case 15: charset reject (spaces) → empty stdout + exit 1
res="$(call_session_id 'CLAUDE_CODE_SESSION_ID=with spaces')"
[[ "$res" == "|1" ]] \
    && ok "case 15: session-id charset reject → empty + exit 1" \
    || no "case 15: session-id charset reject (got '$res')"

finish
