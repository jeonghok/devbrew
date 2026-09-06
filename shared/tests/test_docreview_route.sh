#!/usr/bin/env bash
# guards: shared/docreview/scripts/docreview_route.py shared/tests/fixtures/docreview/**
#
# 라우팅 규칙(설계 §6.3 표)과 finding 정체성(§6.2)의 행동 — D13 T01~T17 · T22 · T28 · T35 · T40~T43.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/scripts/docreview_route.py"; git ls-files -- 'shared/tests/fixtures/docreview/*'; exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPTS="${SCRIPTS:-$REPO_ROOT/plugins/spec-distill/scripts}"
. "$HERE/fixtures/docreview/cases.sh"
case_T01_prepare_anonymizes
case_T02_same_as_max
case_T03_T04_raise
case_T05_T06_reject
case_T07_codex_no_disposition
case_T08_defer_disallowed
case_T09_disallowed_up
case_T10_protected_decide
case_T10_invalidated_reject_still_promotes
case_T10_invalidated_raise_still_promotes
case_T11_permit_keeps_disposition
case_T12_immutable_fix_to_decide
case_T12_invalidated_reject_still_promotes
case_T12_invalidated_raise_still_promotes
case_T13_ids_distinct
case_T14_T15_lineage
case_T15_auto_lineage
case_T16_lineage_mismatch
case_T17_revival_notice
case_T35_frozen_change_auto_decide
case_T28_escalated_fix_becomes_decide
case_T22_reraise_appears_in_next_round
case_T40_codex_absent_first_line
case_T41_critic_dead_blocks
case_T42_layer2_missing
case_T43_recritic_dead
case_route_adjudication_keys
finish
