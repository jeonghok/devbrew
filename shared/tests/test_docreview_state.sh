#!/usr/bin/env bash
# guards: shared/docreview/scripts/docreview_state.py shared/tests/fixtures/docreview/**
#
# docreview 원장의 **행동**을 고정한다 — D13 전이표의 상태·라운드·게이트 셀.
# 케이스 본문은 fixtures/docreview/cases.sh 에 있다(mutation 락과 공유).
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/scripts/docreview_state.py"; bash "$(dirname "$0")/docreview_fixture_corpus.sh"; exit 0
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
case_T39_gate_derivation
case_cap_zero_open_two_stage
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
finish
