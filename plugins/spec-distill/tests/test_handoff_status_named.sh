#!/usr/bin/env bash
# AC1/AC3 — named-status invariant: approve_handoff.sh exports 3 named status constants.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$PLUGIN_DIR/scripts/approve_handoff.sh"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

# Invariant 1: 3 named status constants declared as readonly.
for name in HANDOFF_STATUS_ALREADY_DONE HANDOFF_STATUS_DIRTY_BLOCKED HANDOFF_STATUS_EMITTED; do
    if grep -Eq "^readonly[[:space:]]+${name}=" "$SCRIPT"; then
        note PASS "constant $name declared readonly"
    else
        note FAIL "constant $name missing or not readonly"
    fi
done

# Invariant 2: Status values are named strings (not numeric, not empty).
# Pull the RHS value of each readonly declaration and ensure it's a non-empty quoted string.
for name in HANDOFF_STATUS_ALREADY_DONE HANDOFF_STATUS_DIRTY_BLOCKED HANDOFF_STATUS_EMITTED; do
    value=$(grep -E "^readonly[[:space:]]+${name}=" "$SCRIPT" | sed -E "s/^readonly[[:space:]]+${name}=//; s/^['\"]//; s/['\"]$//")
    if [[ -n "$value" && ! "$value" =~ ^[0-9]+$ ]]; then
        note PASS "constant $name has named value '$value'"
    else
        note FAIL "constant $name value '$value' is empty or numeric"
    fi
done

# Invariant 3: STATUS= line in .handoff-status uses one of the named constants.
# Search for the literal HANDOFF_STATUS_* variable expansion in marker write logic.
if grep -Eq 'STATUS=\$\{?HANDOFF_STATUS_' "$SCRIPT"; then
    note PASS "marker write uses named status variable expansion"
else
    note FAIL "marker write does not use named status constant"
fi

if [[ "$fail" -gt 0 ]]; then
    echo "FAILED: $fail invariant(s)"
    exit 1
fi
echo "PASSED: 7 invariants"
