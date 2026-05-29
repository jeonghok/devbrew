#!/usr/bin/env bash
# V9 — handoff end-to-end (v0.11.0): approve → spec_path validated → session
# cleaned, with NO marker, NO induction hook, NO detect hook. Confirms the
# proceed-gate contract leaves no marker artifact behind.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPROVE="$PLUGIN_DIR/scripts/approve_handoff.sh"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

# ── Removed hooks must not exist ──
for h in compact-induction.py compact-detect.py; do
    [[ ! -e "$PLUGIN_DIR/hooks/$h" ]] \
        && note PASS "hook removed: $h" \
        || note FAIL "hook still present: $h"
done

WORK=$(mktemp -d)
SID="chainsid12abc"
SPEC_REL="docs/superpowers/specs/2026-01-01-test-spec.md"
mkdir -p "$WORK/docs/superpowers/specs"; cd "$WORK"
git init -q && git config user.email t@x.invalid && git config user.name t
echo "# spec" > "$SPEC_REL"
mkdir -p "$WORK/.claude/spec-distill/$SID"; echo state > "$WORK/.claude/spec-distill/$SID/state.local.md"
git add . && git commit -q -m "init spec"

# ── Step 1: approve_handoff → exit 0, NO marker dir created, session dir gone ──
bash "$APPROVE" "$SID" "$WORK/$SPEC_REL" >/tmp/chain_out_$$ 2>&1; rc=$?
md="$WORK/.claude/spec-distill/.markers"
sess="$WORK/.claude/spec-distill/$SID"
if [[ $rc -eq 0 && ! -d "$md" && ! -d "$sess" ]]; then
    note PASS "chain: approve → exit 0, no marker dir, session cleaned"
else
    note FAIL "chain: rc=$rc, no_marker=$([[ ! -d $md ]] && echo y || echo n), sess_gone=$([[ ! -d $sess ]] && echo y || echo n) (out: $(cat /tmp/chain_out_$$))"
fi

# ── Step 2: stdout carries NO legacy packet / marker tokens ──
if ! grep -qE "handoff packet|STATUS=|FIRE_COUNT=|HANDOFF_STATUS_|\.markers/" /tmp/chain_out_$$; then
    note PASS "chain: no legacy packet/marker tokens in output"
else
    note FAIL "chain: legacy tokens leaked: $(cat /tmp/chain_out_$$)"
fi

# ── Step 3 (kill switch): DEVBREW_DISABLE → exit 0, no marker, session preserved ──
mkdir -p "$sess"; echo state > "$sess/state.local.md"
DEVBREW_DISABLE_SPEC_DISTILL=1 bash "$APPROVE" "$SID" "$WORK/$SPEC_REL" >/dev/null 2>&1; rc=$?
if [[ $rc -eq 0 && ! -d "$md" && -d "$sess" ]]; then
    note PASS "chain: kill switch → exit 0, no marker, session preserved"
else
    note FAIL "chain: kill switch rc=$rc, sess_preserved=$([[ -d $sess ]] && echo y || echo n)"
fi

rm -rf "$WORK" /tmp/chain_out_$$

if [[ "$fail" -gt 0 ]]; then echo "FAILED: $fail step(s)"; exit 1; fi
echo "PASSED: chain"
