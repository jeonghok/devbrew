#!/usr/bin/env bash
# guards: shared/docreview/scripts/docreview_route.py shared/docreview/scripts/docreview_state.py shared/tests/fixtures/docreview/**
#
# 라우팅 규칙(설계 §6.3 표)과 finding 정체성(§6.2)의 행동 — D13 T01~T17 · T22 · T28 · T35 · T40~T43.
# T46 — 「미검증」 라운드(critic 사망 · finalize 실패)를 엔진이 안다: 라우터가 남기는 준비의 라운드
# 번호 · finalize 거부 표지와, 그것을 읽는 `docreview_state.py` 게이트 요약·렌더를 함께 잰다
# (`docreview_route.py` 는 `docreview_state` 를 import 하고, 이 케이스들은 `gate` 도 부른다).
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/scripts/docreview_route.py"; echo "shared/docreview/scripts/docreview_state.py"
  bash "$(dirname "$0")/docreview_fixture_corpus.sh"; exit 0
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
case_AC27_unknown_verdict_coerced
case_AC7b_unknown_same_as_target_coerced
case_T07_codex_no_disposition
case_T08_defer_disallowed
case_T09_disallowed_up
case_T10_protected_decide
case_T10_invalidated_reject_still_promotes
case_T10_invalidated_raise_still_promotes
case_T11_permit_keeps_disposition
case_AC24_stale_permit_does_not_cover
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
case_codex_predates_round_absent
case_codex_after_round_start_read
case_codex_round_start_unrecorded_absent
case_codex_prev_round_output_absent
case_codex_tie_absent
case_codex_round_start_unreadable_absent
case_critic_predates_round_dead
case_T41_critic_dead_blocks
case_T42_layer2_missing
case_T43_recritic_dead
case_route_adjudication_keys
case_T46_critic_dead_twice_unverified
case_T46_critic_dead_finalized_unverified
case_T46_finalize_failed_unverified
case_T46_finalize_without_prepare_marks_round
case_T46_stale_pending_refused
case_T46_unverified_released_next_round
case_T46_normal_and_unrouted_rounds
case_T46_skipped_routing_unrouted_disclosed
case_T46_undecodable_critic_is_dead
case_T46_unrouted_round2_with_open_items
case_T46_unverified_two_stage_with_open_items
case_E1b_skipped_round_unedited_permit_expires
case_E2_finalize_observes_idempotent
case_E3_consumed_permit_exempt_from_freeze
case_E4_snapshot_missing_unverified
case_critic_freshness_unknown_disclosed
case_fields_roundtrip_decide
case_fields_survive_non_decide
case_decision_view_no_tautology
case_decision_view_absence_is_literal
finish
