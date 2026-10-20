#!/usr/bin/env bash
# guards: shared/docreview/scripts/docreview_state.py shared/docreview/scripts/docreview_config.py shared/tests/fixtures/docreview/**
#
# docreview 원장의 **행동**을 고정한다 — D13 전이표의 상태·라운드·게이트 셀.
# 케이스 본문은 fixtures/docreview/cases.sh 에 있다(mutation 락과 공유).
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/scripts/docreview_state.py"; echo "shared/docreview/scripts/docreview_config.py"; bash "$(dirname "$0")/docreview_fixture_corpus.sh"; exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPTS="${SCRIPTS:-$REPO_ROOT/plugins/spec-distill/scripts}"
. "$HERE/fixtures/docreview/cases.sh"
case_T37_cap_and_extra
case_config_defaults_disclosed
case_config_env_wins
case_config_entry_beats_profile
case_config_invalid_refused
case_config_maximum_refused
case_config_changes_between_rounds
case_config_profile_fields
case_config_profile_string_refused
case_config_rereview_count_never_decreases
case_T18_adopt_issues_permit
case_T19_reject_closes
case_T20_hold_becomes_ask
case_T21_permit_applied
case_AC38_related_declared_exempt_and_shown
case_AC38_related_undeclared_still_frozen
case_AC38_related_refusals
case_AC38_related_declared_but_unchanged_disclosed
case_AC38_related_immutable_refused_and_frozen
case_AC38_related_insert_after
case_AC38_related_scoped_to_permit_round
case_AC38_related_uncountable_disclosed
case_AC38_audit_row1_forged_related_scope
case_AC38_audit_row2_edit_scope_immutable
case_AC38_audit_row3_insert_after_immutable
case_AC38_audit_row4_fix_intent_pass_validated
case_AC38_audit_row5_labels_never_apply
case_AC38_audit_row6_decision_log_append_only
case_AC38_audit_row9_declare_stale_permit
case_AC38_audit_row10_11_entry_flags
case_AC38_r3_f1_intent_pass_removed
case_AC38_r3_f2_revert_immutable_restored
case_AC38_r3_f3_log_section_fenced
case_AC38_r3_f3_positive_controls
case_AC38_r3_f4_headingless_transition
case_AC38_r3_f5_gate_adopt_unavailable
case_AC38_r3_f6_legacy_ledger_disclosed
case_AC38_r3_f7_invisible_blank_quote
case_AC38_r4_A_log_revert_keeps_engine_lines
case_AC38_r4_B_fake_log_lines
case_AC38_r4_C_log_recreated
case_AC38_r4_m3_invisible_letters
case_AC38_r4_m4_route_alternatives_filtered
case_AC38_r4_m1_revert_target_flagged
case_AC38_r4_snapshot_fields_cannot_switch_guards_off
case_AC38_r5_1_revert_to_absence_keeps_engine_lines
case_AC38_r5_2_window_upper_bound
case_AC38_r5_3_since_corrupt_and_legacy_once
case_AC38_r5_4_duplicate_engine_line
case_AC38_r5_5_combining_only_blank
case_T22_permit_expired_reraise
case_T22b_expired_superseded_unblocks
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
case_AC13_stagnation_first_line
case_T39_gate_derivation
case_cap_zero_open_two_stage
case_AC40_extra_source_required
case_AC40_below_cap_approval_logged
case_AC13_open_count_and_label
case_precap_zero_open_not_two_stage
case_T45_decision_log_append_only
case_T12_immutable_permit_targets_summary
case_AC21_reraise_accumulates
case_AC21_reraise_dedup
case_AC20_nonobligation_successors_still_block
case_AC20_reexpiry_blocks_again
case_AC20_stale_pointer_cleared_on_reobserve
case_AC22_expired_escape_hatch
case_AC22_nonexpired_states_still_refused
case_AC22_post_expiry_render_tail
case_AC22_stale_pointer_cleared_via_redecide
# Task 4 (2026-09-08-docreview-design-doc-site) — 같은 이유(F-8/Ruling 23)로 여기도
# 등록한다: 매트릭스(test_docreview_mutations.sh)에서만 불리면 규칙이 실제로 깨져도
# 「양성대조 실패(계측기 고장)」로만 보고돼 행동 락으로는 안 잡힌다. 브리프의 파일
# 목록엔 없었지만(브리프는 이 파일을 몰랐다) 형제 case_AC22_* 들과 같은 종류다.
case_AC22b_reraise_successor_hold_refused
# Task 5 (2026-09-08-docreview-design-doc-site) — 같은 이유(F-8/Ruling 23)로 여기도
# 등록한다. 브리프의 파일 목록에도 없었다(브리프는 이 파일을 몰랐다) — AC22b 위
# 코멘트가 이미 기록한 바로 그 사정 그대로다.
case_AC22c_reraise_inherits_post_kind
case_AC22c_reraise_inherits_prev_hash
case_AC22c_reraise_preserves_pre_kind
case_choices_offered_equal_accepted
case_decide_reason_literals_not_open_and_expired
# Task 2 재리뷰(F-8/Ruling 23) — escalated 케이스 넷은 지금까지 매트릭스
# (test_docreview_mutations.sh)에서만 불렸다. 그 규칙이 진짜로 깨지면 매트릭스는
# 「양성대조 실패(계측기 고장)」로만 보고해, 다음 독자를 규칙이 아니라 계측기로
# 보낸다. 형제 case_AC21_reraise_accumulates·case_AC21_reraise_dedup 처럼 여기
# 등록해 행동 락으로도 재게 한다.
case_escalated_accumulates
case_escalated_dedup
case_escalated_unconsumed_counted
case_escalated_dropped_fix_not_resurrected
# Task 3 — 위와 같은 이유(F-8/Ruling 23)로 여기 등록한다: 매트릭스에서만 불리면
# 규칙이 깨져도 「양성대조 실패(계측기 고장)」로만 보고된다.
case_GR_held_decide_cross_ledger
case_GR_escalated_fix_blocks_approval
case_GR_escalated_fix_drop_clears_block
case_GR_escalated_fix_reason_persists
# 상태 디렉토리의 문서 정체 — init 거부 둘 · 그 양의 짝 · 빈 state-dir · 문서별 자리 도출.
case_init_other_doc_refused
case_init_other_profile_refused
case_init_same_doc_idempotent
case_init_empty_state_dir_refused
case_init_relative_doc_refused
case_state_dir_for_per_doc
# PR 3 qg iter 3 — 관측은 원장의 함수: 건너뛴 라운드의 permit(적용 · 원복)을 뒤 라운드가 그 라운드의 스냅숏으로 따라잡는다.
case_E1_skipped_round_permit_caught_up
case_E5_revert_caught_up_by_its_round_snapshot
case_state_gloss_covers_gate_rows
# AC14 — 줄인 플래그 거부 · brief 원문 절 덧붙이기만 허용.
case_AC14_no_abbrev_flags
case_AC14_append_only_passes
case_AC14_append_only_plus_edit
case_AC14_line_hashes_only_immutable
# AC2 — 불변 절은 0열 새 목록 항목만 추가로 본다.
case_AC2_append_new_item_only
# AC15 — 엔진이 쓰는 줄의 모든 칸은 한 줄 문법.
case_AC15_log_line_one_line_every_field
case_AC15_forged_lines_gain_no_provenance
case_AC15_drop_reason_one_line
case_AC15_decide_quote_one_line
case_AC15_defer_row_one_line_escaped
# AC17 — 원장 요약값.
case_AC17_digest_mismatch_stops
case_AC17_digest_covers_engine_lines_and_body
case_AC17_digest_backfill_disclosed_once
case_AC17_digest_line_strip_stops
case_AC17_era_marker_failure_disclosed
case_AC17_legacy_disclosed_on_every_load
case_AC17_misplaced_or_malformed_digest_stops
# AC38 · AC15 — 사람이 내린 결정 줄은 엔진 명령(log-decision)으로 쓰고, 울타리는 그대로다.
case_AC38_human_decision_via_engine
case_AC38_human_decision_by_hand_still_frozen
case_AC38_human_decision_creates_section
case_AC38_human_decision_quote_one_line
case_AC38_human_decision_refusals
case_AC38_human_decision_no_ledger_baseline
case_AC38_human_decision_before_first_round_baseline
case_AC38_human_decision_count_prefix
finish
