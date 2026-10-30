#!/usr/bin/env bash
# guards: shared/docreview/scripts/docreview_advice.py shared/docreview/scripts/docreview_route.py shared/docreview/scripts/docreview_state.py shared/docreview/scripts/docreview_config.py plugins/*/references/docreview-profiles/*.md shared/tests/fixtures/docreview/**
#
# must-catch 축 / 참고(advisory) 축 라우팅의 행동 — 설계 2026-09-27-review-stopping-criterion.
# 케이스 본문은 fixtures/docreview/cases_advice.sh 에 있다(변이 매트릭스와 공유). 실제 프로필(must_catch 지목)로 돈다.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/scripts/docreview_advice.py"; echo "shared/docreview/scripts/docreview_route.py"
  echo "shared/docreview/scripts/docreview_state.py"; echo "shared/docreview/scripts/docreview_config.py"
  git ls-files -- 'plugins/*/references/docreview-profiles/*.md'
  bash "$(dirname "$0")/docreview_fixture_corpus.sh"; exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPTS="${SCRIPTS:-$REPO_ROOT/plugins/spec-distill/scripts}"
. "$HERE/fixtures/docreview/cases.sh"
. "$HERE/fixtures/docreview/cases_advice.sh"
case_advice_axes_per_profile
case_advice_engine_items_mustcatch
case_AC1_brief_overdesign_only
case_AC1_brief_overdesign_distortion
case_AC3_reference_line_positive
case_AC13_advisory_decide_ask_to_advice
case_AC19_promoted_advisory_fix
case_AC5_AC9_round2
case_AC9_child_section_changed
case_advice_same_round_refinalize_idempotent
case_advice_same_round_duplicate_bucket
case_AC2_mustcatch_fail_closed
case_AC13_blocking_ask_stays
case_AC15_blocks_by_application_path
case_AC14_merge_survivor
case_AC18_round2_new_advisory_fix
case_advice_supersedes_open_lineage_only
case_AC8_staged_equation
case_advice_dangling_blocks
case_advice_blocks_coercion_flips_gate
case_advice_step2_order_independent
case_AC6_render_cap
case_AC16_advice_list_read_only
case_AC7_sink_idempotent
case_AC17_count_line_carrier
case_AC17_count_key_line_start
case_advice_render_once
case_advice_pre_upgrade_ledger
case_advice_odd_text_one_line
case_advice_write_failure_loud
case_advice_module_missing
case_advice_sink_bullet_section
case_advice_sink_persists_before_later_steps
case_advice_surrogate_sink_atomic
case_AC39_contradicts_routes_fix
case_AC39_contradicts_unbound_decisions_stay_advice
case_AC39_contradicts_malformed_id
case_AC39_contradicts_accounted
case_AC39_contradicts_never_lowers
case_AC39_contradicts_fence_and_immutable
case_AC39_contradicts_protected_still_asks
case_AC39_precondition_protected_fix_escalates
case_advice_surrogate_entry
case_advice_text_encoding_exit
case_advice_seed_gate_no_reference_line
case_advice_plain_render_nothing_left_mc
case_advice_plain_render_zero_with_mc_preexisting
case_advice_seed_gate_profile_yaml_broken
case_advice_cli_text_surrogate_rejected
case_advice_atomic_write_keeps_link_and_mode
case_advice_sink_after_headerless_defer_row
case_advice_count_line_nested_log
case_advice_render_where_label
# AC11 — 리뷰가 닫힌 뒤 결정 기록 끝의 손 줄.
case_closed_log_after_close_vs_after_begin
case_count_line_fresh_ledger_same_doc
case_count_line_old_ledger_idempotent
case_closed_log_inserted_above_count_asks
case_closed_log_other_section_asks
case_closed_log_old_ledger_asks
case_closed_log_two_counts_uses_last
case_closed_log_label_reserved
case_closed_log_engine_line_deleted_asks
# AC15 — 박제 행도 한 줄 문법.
case_AC15_sink_row_one_line_escaped
case_AC15_sink_row_function_one_line
case_AC15_count_line_identity_one_token
case_AC15_identity_one_to_one_across_roots
finish
