#!/usr/bin/env bash
# AC1/AC2/AC3/AC7 — approve_handoff.sh idempotent contract (v0.10.0).
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$PLUGIN_DIR/scripts/approve_handoff.sh"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

# Per-run tmpdir to avoid "$OUT" collisions between parallel CI jobs.
TMPDIR_TESTRUN=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TESTRUN"' EXIT
OUT="$TMPDIR_TESTRUN/out"
ERR="$TMPDIR_TESTRUN/err"

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

marker_path() {
    local wd=$1 sid=$2
    echo "$wd/.claude/spec-distill/.markers/${sid}.emitted"
}

# ───────── Case 1 (AC1): happy path — clean HEAD spec → marker created, packet emitted ─────────
WORK=$(mktemp -d)
setup_repo "$WORK"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >"$OUT" 2>"$ERR"
rc=$?
m=$(marker_path "$WORK" "test-sid12")
if [[ $rc -eq 0 && -f "$m" ]] && grep -q "STATUS=already_handed_off" "$m" && grep -q "===== spec-distill handoff packet =====" "$OUT"; then
    note PASS "case 1 (AC1): clean HEAD → marker created + packet emitted"
else
    note FAIL "case 1: rc=$rc, marker_exists=$([[ -f $m ]] && echo y || echo n), stdout_ok=$(grep -q handoff "$OUT" && echo y || echo n)"
fi
rm -rf "$WORK"

# ───────── Case 2 (AC2): dirty spec → exit 1 + 4-token stderr advisory ─────────
WORK=$(mktemp -d)
setup_repo "$WORK"
echo "uncommitted modification" >> "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >"$OUT" 2>"$ERR"
rc=$?
m=$(marker_path "$WORK" "test-sid12")
required_tokens_ok=1
grep -q "\[spec-distill\]" "$ERR" || required_tokens_ok=0
grep -q "dirty_blocked" "$ERR" || required_tokens_ok=0
grep -q "git status --short" "$ERR" || required_tokens_ok=0
grep -q "git add -- " "$ERR" || required_tokens_ok=0
grep -q "git commit -m " "$ERR" || required_tokens_ok=0
if [[ $rc -ne 0 && ! -f "$m" && "$required_tokens_ok" -eq 1 ]]; then
    note PASS "case 2 (AC2): dirty → exit 1 + 4-token advisory + no marker"
else
    note FAIL "case 2: rc=$rc, marker_absent=$([[ ! -f $m ]] && echo y || echo n), tokens_ok=$required_tokens_ok"
fi
rm -rf "$WORK"

# ───────── Case 3 (AC3): idempotent re-run → marker preserved, TIMESTAMP unchanged ─────────
WORK=$(mktemp -d)
setup_repo "$WORK"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>&1
m=$(marker_path "$WORK" "test-sid12")
ts1=$(grep "^TIMESTAMP=" "$m" | cut -d= -f2-)
sleep 1
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >"$OUT" 2>&1
rc=$?
ts2=$(grep "^TIMESTAMP=" "$m" | cut -d= -f2-)
if [[ $rc -eq 0 && -f "$m" && "$ts1" == "$ts2" ]] && grep -q "STATUS=already_handed_off" "$m" && grep -q "handoff packet" "$OUT"; then
    note PASS "case 3 (AC3): re-run preserves TIMESTAMP + re-emits packet"
else
    note FAIL "case 3: rc=$rc, ts_unchanged=$([[ $ts1 == $ts2 ]] && echo y || echo n)"
fi
rm -rf "$WORK"

# ───────── Case 4: charset reject (cleanup_skipped) ─────────
WORK=$(mktemp -d)
setup_repo "$WORK"
bash "$SCRIPT" "../bad" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>"$ERR"
grep -q "cleanup skipped" "$ERR" \
    && note PASS "case 4: charset reject emits advisory" \
    || note FAIL "case 4: missing cleanup-skipped advisory"
rm -rf "$WORK"

# ───────── Case 5: empty session_id arg → exit 1 ─────────
bash "$SCRIPT" "" "anything" >/dev/null 2>&1
[[ $? -ne 0 ]] && note PASS "case 5: empty session_id rejected" || note FAIL "case 5: empty session_id accepted"

# ───────── Case 6: empty spec_path arg → exit 1 ─────────
bash "$SCRIPT" "test-sid12" "" >/dev/null 2>&1
[[ $? -ne 0 ]] && note PASS "case 6: empty spec_path rejected" || note FAIL "case 6: empty spec_path accepted"

# ───────── Case 7 (AC7): kill switch DEVBREW_DISABLE_SPEC_DISTILL=1 → exit 0, no marker ─────────
WORK=$(mktemp -d)
setup_repo "$WORK"
DEVBREW_DISABLE_SPEC_DISTILL=1 bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>&1
rc=$?
m=$(marker_path "$WORK" "test-sid12")
[[ $rc -eq 0 && ! -f "$m" ]] \
    && note PASS "case 7 (AC7): kill switch → exit 0, no marker" \
    || note FAIL "case 7: rc=$rc, marker_absent=$([[ ! -f $m ]] && echo y || echo n)"
rm -rf "$WORK"

# ───────── Case 8: session folder pre-deleted (SessionEnd preceded) → graceful ─────────
WORK=$(mktemp -d)
setup_repo "$WORK"
rm -rf "$WORK/.claude/spec-distill/test-sid12"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>&1
rc=$?
[[ $rc -eq 0 ]] && note PASS "case 8: folder pre-deleted graceful" || note FAIL "case 8: rc=$rc"
rm -rf "$WORK"

if [[ "$fail" -gt 0 ]]; then
    echo "FAILED: $fail case(s)"
    exit 1
fi
echo "PASSED: 8 cases"
