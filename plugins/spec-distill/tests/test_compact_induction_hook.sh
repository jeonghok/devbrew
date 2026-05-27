#!/usr/bin/env bash
# AC4 — compact-induction.py Stop hook contract.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$PLUGIN_DIR/hooks/compact-induction.py"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

make_marker() {
    local wd=$1 sid=$2
    mkdir -p "$wd/.claude/spec-distill/.markers"
    cat > "$wd/.claude/spec-distill/.markers/${sid}.emitted" <<MARKER
STATUS=already_handed_off
TIMESTAMP=2026-05-27T00:00:00Z
FIRE_COUNT=0
SPEC_PATH=/dummy/spec.md
MARKER
}

invoke() {
    local wd=$1 sid=$2
    cd "$wd"
    git init -q 2>/dev/null || true
    git config user.email t@x.invalid 2>/dev/null
    git config user.name t 2>/dev/null
    DEVBREW_SPEC_DISTILL_SESSION_ID="$sid" \
        bash -c "echo '{\"session_id\":\"$sid\"}' | python3 \"$HOOK\""
}

# ───────── Case 1 (AC4 hit): marker present → JSON with /compact + writing-plans ─────────
WORK=$(mktemp -d)
SID="sess1234abc"
make_marker "$WORK" "$SID"
out=$(invoke "$WORK" "$SID" 2>/dev/null || true)
echo "$out" | python3 -c "
import json, sys
d = json.load(sys.stdin)
ac = d['hookSpecificOutput']['additionalContext']
assert '/compact' in ac, f'/compact missing in: {ac}'
assert 'Skill superpowers:writing-plans' in ac, f'writing-plans missing in: {ac}'
assert d['hookSpecificOutput']['hookEventName'] == 'Stop'
print('OK')
" >/dev/null 2>&1 \
    && note PASS "case 1 (AC4): marker → JSON has /compact + writing-plans" \
    || note FAIL "case 1: stdout malformed: $out"
rm -rf "$WORK"

# ───────── Case 2 (AC4 miss): marker absent → stdout exactly {} ─────────
WORK=$(mktemp -d)
out=$(invoke "$WORK" "sess1234abc" 2>/dev/null || true)
trimmed=$(echo "$out" | tr -d '[:space:]')
if [[ "$trimmed" == "{}" ]]; then
    note PASS "case 2 (AC4): marker absent → stdout '{}'"
else
    note FAIL "case 2: stdout '$trimmed' (expected '{}')"
fi
rm -rf "$WORK"

# ───────── Case 3 (AC6): FIRE_COUNT increments on each fire ─────────
WORK=$(mktemp -d)
SID="sess1234abc"
make_marker "$WORK" "$SID"
invoke "$WORK" "$SID" >/dev/null 2>&1
fc1=$(grep "^FIRE_COUNT=" "$WORK/.claude/spec-distill/.markers/${SID}.emitted" | cut -d= -f2)
invoke "$WORK" "$SID" >/dev/null 2>&1
fc2=$(grep "^FIRE_COUNT=" "$WORK/.claude/spec-distill/.markers/${SID}.emitted" | cut -d= -f2)
if [[ "$fc1" == "1" && "$fc2" == "2" ]]; then
    note PASS "case 3 (AC6): FIRE_COUNT 0→1→2"
else
    note FAIL "case 3: fc1=$fc1, fc2=$fc2 (expected 1,2)"
fi
rm -rf "$WORK"

# ───────── Case 4 (AC8): kill switch DEVBREW_SKIP_HOOKS=spec-distill:compact-induction → exit 0 no-op ─────────
WORK=$(mktemp -d)
SID="sess1234abc"
make_marker "$WORK" "$SID"
cd "$WORK"
git init -q 2>/dev/null
git config user.email t@x.invalid 2>/dev/null
git config user.name t 2>/dev/null
out=$(DEVBREW_SKIP_HOOKS="spec-distill:compact-induction" DEVBREW_SPEC_DISTILL_SESSION_ID="$SID" \
    bash -c "echo '{\"session_id\":\"$SID\"}' | python3 \"$HOOK\"" 2>/dev/null)
fc=$(grep "^FIRE_COUNT=" "$WORK/.claude/spec-distill/.markers/${SID}.emitted" | cut -d= -f2)
if [[ -z "$out" || "$out" == "" ]] && [[ "$fc" == "0" ]]; then
    note PASS "case 4 (AC8): hook-specific kill switch → no JSON, no FIRE_COUNT bump"
else
    note FAIL "case 4: out='$out', fc=$fc"
fi
rm -rf "$WORK"

# ───────── Case 5 (AC7): DEVBREW_DISABLE_SPEC_DISTILL=1 → no-op ─────────
WORK=$(mktemp -d)
SID="sess1234abc"
make_marker "$WORK" "$SID"
cd "$WORK"
git init -q 2>/dev/null
git config user.email t@x.invalid 2>/dev/null
git config user.name t 2>/dev/null
out=$(DEVBREW_DISABLE_SPEC_DISTILL=1 DEVBREW_SPEC_DISTILL_SESSION_ID="$SID" \
    bash -c "echo '{\"session_id\":\"$SID\"}' | python3 \"$HOOK\"" 2>/dev/null)
fc=$(grep "^FIRE_COUNT=" "$WORK/.claude/spec-distill/.markers/${SID}.emitted" | cut -d= -f2)
[[ -z "$out" && "$fc" == "0" ]] \
    && note PASS "case 5 (AC7): plugin disable → no-op" \
    || note FAIL "case 5: out='$out', fc=$fc"
rm -rf "$WORK"

if [[ "$fail" -gt 0 ]]; then
    echo "FAILED: $fail case(s)"
    exit 1
fi
echo "PASSED: 5 cases"
