#!/usr/bin/env bash
# V9 — full hook chain: approve → marker → induction JSON → detect → marker gone.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPROVE="$PLUGIN_DIR/scripts/approve_handoff.sh"
INDUCT="$PLUGIN_DIR/hooks/compact-induction.py"
DETECT="$PLUGIN_DIR/hooks/compact-detect.py"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

WORK=$(mktemp -d)
SID="chainsid12abc"
SPEC_REL="docs/superpowers/specs/2026-01-01-test-spec.md"

mkdir -p "$WORK/docs/superpowers/specs"
cd "$WORK"
git init -q
git config user.email t@x.invalid
git config user.name t
echo "# spec" > "$SPEC_REL"
mkdir -p "$WORK/.claude/spec-distill/$SID"
echo "state" > "$WORK/.claude/spec-distill/$SID/state.local.md"
git add . && git commit -q -m "init spec"

# ───── Step 1: approve_handoff.sh → marker should exist ─────
bash "$APPROVE" "$SID" "$WORK/$SPEC_REL" >/tmp/chain_out_$$ 2>&1
m="$WORK/.claude/spec-distill/.markers/${SID}.emitted"
if [[ -f "$m" ]] && grep -q "STATUS=already_handed_off" "$m"; then
    note PASS "chain step 1: approve_handoff → marker created"
else
    note FAIL "chain step 1: marker missing (output: $(cat /tmp/chain_out_$$))"
fi

# ───── Step 2: compact-induction.py with marker → JSON has /compact + writing-plans ─────
induct_out=$(DEVBREW_SPEC_DISTILL_SESSION_ID="$SID" \
    bash -c "echo '{\"session_id\":\"$SID\"}' | python3 \"$INDUCT\"" 2>/dev/null)
echo "$induct_out" | python3 -c "
import json, sys
d = json.load(sys.stdin)
ac = d['hookSpecificOutput']['additionalContext']
assert '/compact' in ac and 'Skill superpowers:writing-plans' in ac
assert d['hookSpecificOutput']['hookEventName'] == 'Stop'
" 2>/dev/null \
    && note PASS "chain step 2: induction emits /compact + writing-plans" \
    || note FAIL "chain step 2: induction JSON malformed: $induct_out"

# ───── Step 3: compact-detect.py with /compact prompt → marker deleted ─────
DEVBREW_SPEC_DISTILL_SESSION_ID="$SID" \
    bash -c "echo '{\"session_id\":\"$SID\",\"user_prompt\":\"/compact preserve spec\",\"user_message\":\"/compact preserve spec\",\"prompt\":\"/compact preserve spec\"}' | python3 \"$DETECT\"" \
    >/dev/null 2>&1
if [[ ! -f "$m" ]]; then
    note PASS "chain step 3: detect deletes marker on /compact"
else
    note FAIL "chain step 3: marker still exists after /compact prompt"
fi

# ───── Step 4: induction post-delete → stdout {} ─────
post_out=$(DEVBREW_SPEC_DISTILL_SESSION_ID="$SID" \
    bash -c "echo '{\"session_id\":\"$SID\"}' | python3 \"$INDUCT\"" 2>/dev/null | tr -d '[:space:]')
[[ "$post_out" == "{}" ]] \
    && note PASS "chain step 4: induction post-delete → stdout '{}'" \
    || note FAIL "chain step 4: induction post-delete stdout='$post_out'"

# ───── Step 5 (V6 kill switch path): DEVBREW_DISABLE_SPEC_DISTILL=1 prevents marker ─────
rm -rf "$WORK/.claude/spec-distill/.markers"
DEVBREW_DISABLE_SPEC_DISTILL=1 bash "$APPROVE" "$SID" "$WORK/$SPEC_REL" >/dev/null 2>&1
if [[ ! -f "$m" ]]; then
    note PASS "chain step 5 (V6): kill switch prevents marker creation"
else
    note FAIL "chain step 5: kill switch leaked marker"
fi

rm -rf "$WORK" /tmp/chain_out_$$

if [[ "$fail" -gt 0 ]]; then
    echo "FAILED: $fail step(s)"
    exit 1
fi
echo "PASSED: 5 chain steps"
