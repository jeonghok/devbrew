#!/usr/bin/env bash
# Regression guard for the v1.5.0 forward-only state machine prose contract.
# Failing this test means the SKILL.md / references prose has drifted back
# toward the pre-v1.5.0 "auto-restart from Gate 1" vocabulary, OR the
# deprecated total_iterations / max_total_iterations fields have re-entered
# the codebase.
#
# Locked by spec docs/superpowers/specs/2026-05-13-qg-forward-only-cleanup-and-stop-hook-trim-design.md AC1-3, AC4-6, AC8, NG7.
set -u

REPO_PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_PLUGIN_ROOT"

FAILED=0
fail()  { echo "FAIL: $*"; FAILED=1; }
ok()    { echo "ok:   $*"; }

# --- AC1-3: forbidden phrases in skill prose -----------------------------------

if grep -rn 'restart from Gate 1' skills 2>/dev/null; then
    fail "AC1: 'restart from Gate 1' phrase still present"
else
    ok "AC1: no 'restart from Gate 1' in skill prose"
fi

if grep -rn 'loop-back' skills 2>/dev/null; then
    fail "AC2: 'loop-back' phrase still present in SKILL prose"
else
    ok "AC2: no 'loop-back' in skill prose"
fi

if grep -rn 'Restarting from Gate 1' skills 2>/dev/null; then
    fail "AC3: example log line 'Restarting from Gate 1' still present"
else
    ok "AC3: no 'Restarting from Gate 1' in skill or references"
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
# Allowed: CHANGELOG history; test_no_max_total_iterations_constant gate test;
# this script itself (which has to reference the forbidden tokens to grep for them).

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

# -------------------------------------------------------------------------------

if [ "$FAILED" -ne 0 ]; then
    echo "test_forward_only_prose.sh: FAIL"
    exit 1
fi
echo "test_forward_only_prose.sh: PASS"
