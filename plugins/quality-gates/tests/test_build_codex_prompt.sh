#!/usr/bin/env bash
# test_build_codex_prompt.sh — regression guard for the optional plan-summary
# contract (v2.0.0). run_codex_reviewer.sh defaults PLAN_SUMMARY_FILE to
# /dev/null ("omit for empty plan context"); since the Gate 1 verifier was
# removed, empty-plan-context is the canonical codex path. build_codex_prompt.py
# MUST treat a non-regular-file plan summary (/dev/null, missing) as empty
# context, not error — otherwise codex review fails with prompt_build_failed.

set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$SCRIPT_DIR/../scripts/build_codex_prompt.py"

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); echo "  PASS: $1"; }
bad()  { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }

DIFF="$(mktemp)"; printf 'diff --git a b\n+added line\n' > "$DIFF"
PLAN="$(mktemp)"; printf 'matched_items:\n  - feature X\n' > "$PLAN"
trap 'rm -f "$DIFF" "$PLAN"' EXIT

# Case 1: /dev/null plan summary → exit 0, empty <plan_context>.
out="$(python3 "$BUILD" "$DIFF" /dev/null 2>/dev/null)"; rc=$?
[ "$rc" -eq 0 ] && ok "/dev/null plan → exit 0" || bad "/dev/null plan → exit $rc (expected 0)"
echo "$out" | grep -q '+added line' && ok "/dev/null: diff content present" || bad "/dev/null: diff content missing"
# <plan_context> must exist but contain no plan text.
echo "$out" | grep -q '<plan_context>' && ok "/dev/null: plan_context block present" || bad "/dev/null: plan_context block missing"
echo "$out" | grep -q 'matched_items' && bad "/dev/null: leaked plan text" || ok "/dev/null: empty plan context"

# Case 2: real plan file → content included, exit 0.
out2="$(python3 "$BUILD" "$DIFF" "$PLAN" 2>/dev/null)"; rc2=$?
[ "$rc2" -eq 0 ] && ok "real plan → exit 0" || bad "real plan → exit $rc2 (expected 0)"
echo "$out2" | grep -q 'matched_items' && ok "real plan: content included" || bad "real plan: content missing"

# Case 3: missing diff file → exit 2 (diff is still required).
python3 "$BUILD" /nonexistent-qg-diff-xyz "$PLAN" >/dev/null 2>&1
[ "$?" -eq 2 ] && ok "missing diff → exit 2" || bad "missing diff → wrong exit"

echo ""
echo "Total: $((PASS + FAIL)), PASS=$PASS, FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
