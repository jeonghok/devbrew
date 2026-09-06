#!/usr/bin/env bash
# guards: shared/docreview/scripts/docreview_state.py shared/tests/fixtures/docreview/**
#
# docreview 원장의 **행동**을 고정한다 — D13 전이표의 상태·라운드·게이트 셀.
# 케이스 본문은 fixtures/docreview/cases.sh 에 있다(mutation 락과 공유).
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/scripts/docreview_state.py"; git ls-files -- 'shared/tests/fixtures/docreview/*'; exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPTS="${SCRIPTS:-$REPO_ROOT/plugins/spec-distill/scripts}"
. "$HERE/fixtures/docreview/cases.sh"
case_T37_cap_and_extra
case_T18_adopt_issues_permit
case_T19_reject_closes
case_T20_hold_becomes_ask
case_T21_permit_applied
case_T22_permit_expired_reraise
case_T23_post_adopt_applied
case_T24_post_reject_revert_permit
case_T25_revert_observed
case_T26_revert_missed_reraise
case_T27_intent_pass_records_scope
case_T29_fix_applied
case_T30_fix_unapplied_counts
case_T31_T34_blocked_fix_held_gate_opens
case_T32_ask_answered_unholds
case_T33_user_drops_fix
case_T36_freeze_exceptions_log_targets
case_T38_stagnation
case_T39_gate_derivation
case_T45_decision_log_append_only
case_T12_immutable_permit_targets_summary
finish
