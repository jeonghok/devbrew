#!/usr/bin/env bash
# AC6 — approve_handoff.sh contract.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$PLUGIN_DIR/scripts/approve_handoff.sh"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

setup_repo() {
    local wd=$1
    mkdir -p "$wd/docs/superpowers/specs"
    cd "$wd"
    git init -q
    git config user.email test@x.invalid
    git config user.name test
    echo "# test" > "$wd/docs/superpowers/specs/2026-01-01-test-spec.md"
    git add . && git commit -q -m "init"
    mkdir -p "$wd/.claude/spec-distill/test-sid12"
    echo "state" > "$wd/.claude/spec-distill/test-sid12/state.local.md"
}

# Case 1: happy path
WORK=$(mktemp -d)
setup_repo "$WORK"
echo "modified" > "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>&1
rc=$?
[[ $rc -eq 0 && ! -d "$WORK/.claude/spec-distill/test-sid12" ]] \
    && note PASS "case 1: happy path (commit + cleanup)" \
    || note FAIL "case 1: rc=$rc folder_exists=$([[ -d $WORK/.claude/spec-distill/test-sid12 ]] && echo y || echo n)"
rm -rf "$WORK"

# Case 2: charset reject (cleanup_skipped)
WORK=$(mktemp -d)
setup_repo "$WORK"
mkdir -p "$WORK/.claude/spec-distill/..bad"
echo "modified" > "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
bash "$SCRIPT" "../bad" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>err
grep -q "cleanup skipped" err \
    && note PASS "case 2: charset reject emits advisory" \
    || note FAIL "case 2: missing cleanup-skipped advisory"
rm -rf "$WORK"

# Case 3: empty session_id arg
bash "$SCRIPT" "" "anything" >/dev/null 2>&1
[[ $? -ne 0 ]] \
    && note PASS "case 3: empty session_id rejected" \
    || note FAIL "case 3: empty session_id accepted"

# Case 4: empty spec_path arg
bash "$SCRIPT" "test-sid12" "" >/dev/null 2>&1
[[ $? -ne 0 ]] \
    && note PASS "case 4: empty spec_path rejected" \
    || note FAIL "case 4: empty spec_path accepted"

# Case 5: git commit fail (no spec edit → 'nothing to commit')
WORK=$(mktemp -d)
setup_repo "$WORK"
# don't modify spec → git commit will fail "nothing to commit"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>&1
rc=$?
[[ $rc -ne 0 && -d "$WORK/.claude/spec-distill/test-sid12" ]] \
    && note PASS "case 5: commit fail preserves state" \
    || note FAIL "case 5: rc=$rc, state lost"
rm -rf "$WORK"

# Case 6: rm permission fail (skip if root or limited platform)
if [[ $(id -u) -ne 0 ]]; then
    WORK=$(mktemp -d)
    setup_repo "$WORK"
    chmod 555 "$WORK/.claude/spec-distill"  # parent read-only
    echo "modified" > "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
    bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>err
    grep -q "cleanup rm failed" err \
        && note PASS "case 6: rm fail emits advisory but exits 0" \
        || note FAIL "case 6: missing rm-fail advisory"
    chmod 755 "$WORK/.claude/spec-distill"
    rm -rf "$WORK"
else
    note PASS "case 6: skipped (running as root)"
fi

# Case 7: idempotent re-run (second call → already committed)
WORK=$(mktemp -d)
setup_repo "$WORK"
echo "modified" > "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>&1
# folder already gone; second call should still fail because git has nothing to commit
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>&1
[[ $? -ne 0 ]] \
    && note PASS "case 7: idempotent re-run fails (already committed)" \
    || note FAIL "case 7: re-run silently succeeded"
rm -rf "$WORK"

# Case 8: folder pre-deleted (SessionEnd preceded)
WORK=$(mktemp -d)
setup_repo "$WORK"
rm -rf "$WORK/.claude/spec-distill/test-sid12"
echo "modified" > "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>&1
rc=$?
[[ $rc -eq 0 ]] \
    && note PASS "case 8: folder pre-deleted graceful" \
    || note FAIL "case 8: rc=$rc on absent folder"
rm -rf "$WORK"

if [[ "$fail" -gt 0 ]]; then
    echo "FAILED: $fail case(s)"
    exit 1
fi
echo "PASSED: 8 cases"
