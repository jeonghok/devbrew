#!/usr/bin/env bash
# AC6 — compact-induction stagnation: 5 fires without /compact → self-cleanup.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$PLUGIN_DIR/hooks/compact-induction.py"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

WORK=$(mktemp -d)
SID="sess1234abc"
mkdir -p "$WORK/.claude/spec-distill/.markers"
cat > "$WORK/.claude/spec-distill/.markers/${SID}.emitted" <<MARKER
STATUS=already_handed_off
TIMESTAMP=2026-05-27T00:00:00Z
FIRE_COUNT=0
SPEC_PATH=/dummy/spec.md
MARKER

cd "$WORK"
git init -q
git config user.email t@x.invalid
git config user.name t

# Per-run tmpdir to avoid /tmp/induct_err_* collisions between parallel CI jobs.
TMPDIR_TESTRUN=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TESTRUN"' EXIT

# Fire 5 times with session id pinning
for i in 1 2 3 4 5; do
    DEVBREW_SPEC_DISTILL_SESSION_ID="$SID" bash -c "echo '{\"session_id\":\"$SID\"}' | python3 \"$HOOK\"" >/dev/null 2>"$TMPDIR_TESTRUN/induct_err_$i" || true
done

# Check FIRE_COUNT progression and final self-cleanup behavior.
# At FIRE_COUNT == 5 the hook should delete the marker AND advisory mentions "stagnation".
marker_file="$WORK/.claude/spec-distill/.markers/${SID}.emitted"
if [[ ! -f "$marker_file" ]]; then
    note PASS "case 1: marker auto-deleted after 5 fires"
else
    note FAIL "case 1: marker still exists ($(cat $marker_file 2>/dev/null | tr '\n' ' '))"
fi

# Advisory check on the 5th fire's stderr
if grep -q "stagnation" "$TMPDIR_TESTRUN/induct_err_5" 2>/dev/null; then
    note PASS "case 2: stagnation advisory emitted on 5th fire"
else
    note FAIL "case 2: stagnation keyword missing in stderr: $(cat "$TMPDIR_TESTRUN/induct_err_5" 2>/dev/null)"
fi

# 6th fire should be a no-op (marker absent) — emit {}
out6=$(DEVBREW_SPEC_DISTILL_SESSION_ID="$SID" bash -c "echo '{\"session_id\":\"$SID\"}' | python3 \"$HOOK\"" 2>/dev/null | tr -d '[:space:]')
if [[ "$out6" == "{}" ]]; then
    note PASS "case 3: 6th fire (post-cleanup) → stdout '{}'"
else
    note FAIL "case 3: 6th fire stdout '$out6' (expected '{}')"
fi

rm -rf "$WORK"  # TMPDIR_TESTRUN cleaned by EXIT trap

if [[ "$fail" -gt 0 ]]; then
    echo "FAILED: $fail case(s)"
    exit 1
fi
echo "PASSED: 3 cases"
