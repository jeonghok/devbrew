#!/usr/bin/env bash
# AC5 — compact-detect.py: /compact prefix or Skill writing-plans → marker delete.
# Payload key per Task 4 research: actual Claude Code field is `user_prompt`.
# Tests include all three (`user_prompt`, `user_message`, `prompt`) for resilience.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$PLUGIN_DIR/hooks/compact-detect.py"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

make_marker() {
    local wd=$1 sid=$2
    mkdir -p "$wd/.claude/spec-distill/.markers"
    cat > "$wd/.claude/spec-distill/.markers/${sid}.emitted" <<MARKER
STATUS=already_handed_off
TIMESTAMP=2026-05-27T00:00:00Z
FIRE_COUNT=2
SPEC_PATH=/dummy/spec.md
MARKER
}

invoke() {
    local wd=$1 payload=$2 sid=$3
    cd "$wd"
    git init -q 2>/dev/null || true
    git config user.email t@x.invalid 2>/dev/null
    git config user.name t 2>/dev/null
    # DEVBREW_SPEC_DISTILL_SESSION_ID pins the session so resolve_session_id uses
    # our test SID rather than CLAUDE_CODE_SESSION_ID from the outer shell.
    export DEVBREW_SPEC_DISTILL_SESSION_ID="$sid"
    echo "$payload" | python3 "$HOOK" 2>&1
}

# Helper — payload with all three plausible keys set to same text.
pld() {
    local sid=$1 text=$2
    # JSON-escape backslashes and double quotes minimally.
    local esc=${text//\\/\\\\}
    esc=${esc//\"/\\\"}
    echo "{\"session_id\":\"$sid\",\"user_prompt\":\"$esc\",\"user_message\":\"$esc\",\"prompt\":\"$esc\"}"
}

# ───────── Case 1 (AC5.i): /compact prefix → marker deleted ─────────
WORK=$(mktemp -d)
SID="sess1234abc"
make_marker "$WORK" "$SID"
invoke "$WORK" "$(pld "$SID" "/compact preserve spec")" "$SID" >/dev/null
if [[ ! -f "$WORK/.claude/spec-distill/.markers/${SID}.emitted" ]]; then
    note PASS "case 1: /compact prefix → marker deleted"
else
    note FAIL "case 1: marker still exists"
fi
rm -rf "$WORK"

# ───────── Case 2 (AC5.ii): Skill superpowers:writing-plans → marker deleted ─────────
WORK=$(mktemp -d)
make_marker "$WORK" "$SID"
invoke "$WORK" "$(pld "$SID" "Skill superpowers:writing-plans foo.md")" "$SID" >/dev/null
if [[ ! -f "$WORK/.claude/spec-distill/.markers/${SID}.emitted" ]]; then
    note PASS "case 2: Skill writing-plans → marker deleted"
else
    note FAIL "case 2: marker still exists"
fi
rm -rf "$WORK"

# ───────── Case 3: leading whitespace handled (lstrip semantics) ─────────
WORK=$(mktemp -d)
make_marker "$WORK" "$SID"
invoke "$WORK" "$(pld "$SID" "   /compact")" "$SID" >/dev/null
if [[ ! -f "$WORK/.claude/spec-distill/.markers/${SID}.emitted" ]]; then
    note PASS "case 3: leading whitespace then /compact → marker deleted"
else
    note FAIL "case 3: marker still exists"
fi
rm -rf "$WORK"

# ───────── Case 4: substring (mid-message) → marker preserved ─────────
WORK=$(mktemp -d)
make_marker "$WORK" "$SID"
invoke "$WORK" "$(pld "$SID" "please run /compact later")" "$SID" >/dev/null
if [[ -f "$WORK/.claude/spec-distill/.markers/${SID}.emitted" ]]; then
    note PASS "case 4: substring /compact → marker preserved"
else
    note FAIL "case 4: marker deleted on substring match (false positive)"
fi
rm -rf "$WORK"

# ───────── Case 5: case-sensitive (/Compact rejected) ─────────
WORK=$(mktemp -d)
make_marker "$WORK" "$SID"
invoke "$WORK" "$(pld "$SID" "/Compact preserve")" "$SID" >/dev/null
if [[ -f "$WORK/.claude/spec-distill/.markers/${SID}.emitted" ]]; then
    note PASS "case 5: /Compact (uppercase C) → marker preserved (case-sensitive)"
else
    note FAIL "case 5: case-insensitive match leaked"
fi
rm -rf "$WORK"

# ───────── Case 6: unrelated prompt → marker preserved ─────────
WORK=$(mktemp -d)
make_marker "$WORK" "$SID"
invoke "$WORK" "$(pld "$SID" "do something else")" "$SID" >/dev/null
if [[ -f "$WORK/.claude/spec-distill/.markers/${SID}.emitted" ]]; then
    note PASS "case 6: unrelated prompt → marker preserved"
else
    note FAIL "case 6: marker deleted on unrelated prompt"
fi
rm -rf "$WORK"

# ───────── Case 7 (AC7): kill switch DEVBREW_DISABLE_SPEC_DISTILL=1 → no-op ─────────
WORK=$(mktemp -d)
make_marker "$WORK" "$SID"
cd "$WORK"
git init -q 2>/dev/null
git config user.email t@x.invalid 2>/dev/null
git config user.name t 2>/dev/null
DEVBREW_DISABLE_SPEC_DISTILL=1 bash -c "echo '$(pld "$SID" "/compact")' | python3 \"$HOOK\"" >/dev/null 2>&1
if [[ -f "$WORK/.claude/spec-distill/.markers/${SID}.emitted" ]]; then
    note PASS "case 7 (AC7): kill switch → marker preserved (hook no-op)"
else
    note FAIL "case 7: kill switch did not no-op"
fi
rm -rf "$WORK"

if [[ "$fail" -gt 0 ]]; then
    echo "FAILED: $fail case(s)"
    exit 1
fi
echo "PASSED: 7 cases"
