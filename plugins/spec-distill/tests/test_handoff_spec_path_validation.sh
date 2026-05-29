#!/usr/bin/env bash
# AC4a/AC4b — approve_handoff.sh spec_path working-tree existence guard (v0.11.0).
# AC4b reproduces the dangling-worktree bug: file tracked in git HEAD but removed
# from the working tree. Without the `-f` guard the test FAILS (git rev-parse
# HEAD succeeds), so this test is the guard's regression detector.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$PLUGIN_DIR/scripts/approve_handoff.sh"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

setup_repo() {
    local wd=$1
    mkdir -p "$wd/docs/superpowers/specs"
    cd "$wd"
    git init -q && git config user.email t@x.invalid && git config user.name t
    echo "# test" > "$wd/docs/superpowers/specs/2026-01-01-test-spec.md"
    git add . && git commit -q -m init
    mkdir -p "$wd/.claude/spec-distill/test-sid12"
    echo state > "$wd/.claude/spec-distill/test-sid12/state.local.md"
}

# ── AC4a: spec_path never existed (absent in working tree AND git) ──
WORK=$(mktemp -d); setup_repo "$WORK"; ERR="$WORK/err"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/NONEXISTENT.md" >/dev/null 2>"$ERR"; rc=$?
sess_dir="$WORK/.claude/spec-distill/test-sid12"
if [[ $rc -eq 1 ]] && grep -q "\[spec-distill\]" "$ERR" && grep -qi "not found\|부재\|no handoff" "$ERR" && [[ -d "$sess_dir" ]]; then
    note PASS "AC4a: absent spec_path → exit 1 + advisory + session dir preserved"
else
    note FAIL "AC4a: rc=$rc, advisory=$(grep -qi 'not found\|부재\|no handoff' "$ERR" && echo y || echo n), sess_preserved=$([[ -d $sess_dir ]] && echo y || echo n)"
fi
rm -rf "$WORK"

# ── AC4b: dangling worktree — tracked in git HEAD, removed from working tree ──
WORK=$(mktemp -d); setup_repo "$WORK"; ERR="$WORK/err"
# spec is committed (in HEAD); now delete the working-tree copy → dangling.
rm -f "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>"$ERR"; rc=$?
sess_dir="$WORK/.claude/spec-distill/test-sid12"
if [[ $rc -eq 1 ]] && grep -q "\[spec-distill\]" "$ERR" && [[ -d "$sess_dir" ]]; then
    note PASS "AC4b: dangling (HEAD-tracked, worktree-absent) → exit 1 + session dir preserved"
else
    note FAIL "AC4b: rc=$rc (expected 1 — guard missing?), sess_preserved=$([[ -d $sess_dir ]] && echo y || echo n)"
fi
rm -rf "$WORK"

if [[ "$fail" -gt 0 ]]; then echo "FAILED: $fail case(s)"; exit 1; fi
echo "PASSED: 2 cases"
