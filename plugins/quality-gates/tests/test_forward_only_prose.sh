#!/usr/bin/env bash
# Regression guard for the v1.5.0 forward-only state machine prose contract.
# Failing this test means the SKILL.md / references prose has drifted back
# toward the pre-v1.5.0 "auto-restart from Gate 1" vocabulary, OR the
# deprecated total_iterations / max_total_iterations fields have re-entered
# the codebase.
#
# Style mirrors the plugin's other tests/test_*.sh (PASS/FAIL counter + summary).
#
# AC8 expectation timing: this script is created as a failing-test anchor for
# Task 1 of the v1.10.0 cleanup. AC8 LEAK includes the fixture lines in
# tests/test_stop_hook_state_machine.py (lines 25-162) and tests/test_kill_switches.py:49,
# tests/test_session_start_advisor.py:26 until Task 4 (D1.c) removes them; the
# allowlist below only excludes the named gate test (line 15) because the
# rest of the file legitimately fails AC8 today by carrying the deprecated keys.
#
# Locked by spec docs/superpowers/specs/2026-05-13-qg-forward-only-cleanup-and-stop-hook-trim-design.md AC1-3, AC4-6, AC8, NG7.
set -u

REPO_PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_PLUGIN_ROOT"

PASS=0
FAIL=0
fail()  { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $*"; }
ok()    { PASS=$((PASS+1)); echo "  ✓ ok:   $*"; }

# --- AC1-3: forbidden phrases in skill prose -----------------------------------

if grep -rnE 'restart(ing)? from Gate 1' skills 2>/dev/null; then
    fail "AC1: 'restart(ing)? from Gate 1' phrase still present"
else
    ok "AC1: no 'restart(ing)? from Gate 1' in skill prose"
fi

if grep -rn 'loop-back' skills 2>/dev/null; then
    fail "AC2: 'loop-back' phrase still present in SKILL prose"
else
    ok "AC2: no 'loop-back' in skill prose"
fi

if grep -rnE 'Restart(ing)? from Gate 1' skills 2>/dev/null; then
    fail "AC3: example log line 'Restart(ing)? from Gate 1' still present"
else
    ok "AC3: no 'Restart(ing)? from Gate 1' in skill or references"
fi

# --- AC4-6: required phrases ---------------------------------------------------

if grep -q 'forward-only' skills/quality-pipeline/SKILL.md; then
    ok "AC4: SKILL.md mentions 'forward-only'"
else
    fail "AC4: SKILL.md missing 'forward-only' (verdict definition?)"
fi

count_fix_rerun=$(grep -c 'Fix and re-run /qg' skills/quality-pipeline/SKILL.md || true)
if [ "$count_fix_rerun" -ge 1 ]; then
    ok "AC5: SKILL.md contains 'Fix and re-run /qg' (count=$count_fix_rerun)"
else
    fail "AC5: SKILL.md missing 'Fix and re-run /qg'"
fi

count_no_auto=$(grep -cE 'does (not|NOT) auto-restart' skills/quality-pipeline/SKILL.md || true)
if [ "$count_no_auto" -ge 2 ]; then
    ok "AC6: SKILL.md contains 'does not auto-restart' >=2 (count=$count_no_auto)"
else
    fail "AC6: SKILL.md needs 'does not auto-restart' in >=2 sections (got $count_no_auto)"
fi

# --- AC8: deprecated state field residues --------------------------------------
# Allowed (always): CHANGELOG history; the named gate test
# (test_stop_hook_state_machine.py line 15 — test_no_max_total_iterations_constant);
# this script itself (it must reference the forbidden tokens to grep for them).
# Transient (FAIL today, will go green when their owning task lands):
#   - hooks/stop-hook.py:89,92,403,405,433       — Tasks 2-3 (D1.a/b)
#   - tests/test_stop_hook_state_machine.py:25-162 fixture lines  — Task 4 (D1.c)
#   - tests/test_kill_switches.py:49             — Task 4 (D1.c)
#   - tests/test_session_start_advisor.py:26     — Task 4 (D1.c)
#   - skills/quality-pipeline/references/state-file-format.md:37  — Task 5 (D1.d)

LEAK=$(grep -rn 'total_iterations\|max_total_iterations' . 2>/dev/null \
  | grep -v 'CHANGELOG.md' \
  | grep -v 'test_stop_hook_state_machine.py.*test_no_max_total_iterations_constant' \
  | grep -v 'tests/test_forward_only_prose.sh' \
  || true)

if [ -z "$LEAK" ]; then
    ok "AC8: no deprecated-field residue (CHANGELOG + named gate test excluded)"
else
    fail "AC8: deprecated-field residue:"
    echo "$LEAK"
fi

# --- NG7: setup-qg.sh has no deprecated-field writing --------------------------

if grep -n 'total_iterations\|max_total_iterations' scripts/setup-qg.sh 2>/dev/null; then
    fail "NG7: setup-qg.sh contains deprecated field reference (regression)"
else
    ok "NG7: setup-qg.sh free of deprecated field references"
fi

# --- Summary -------------------------------------------------------------------

echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
