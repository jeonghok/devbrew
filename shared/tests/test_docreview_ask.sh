#!/usr/bin/env bash
# guards: shared/docreview/scripts/docreview_ask.py shared/docreview/scripts/docreview_advice.py shared/docreview/scripts/docreview_route.py shared/docreview/scripts/docreview_state.py shared/docreview/scripts/docreview_config.py shared/docreview/scripts/nofollow_write.py plugins/*/references/docreview-profiles/*.md shared/tests/fixtures/docreview/**
#
# 질문에 싣는 짧은 경고 줄 · 상태 줄 · 질문 재료 · 전문 파일의 행동 — 설계 2026-11-15-present-tradeoffs AC4–AC6.
# 케이스 본문은 fixtures/docreview/cases_ask.sh 에 있다.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/scripts/docreview_ask.py"
  echo "shared/docreview/scripts/docreview_advice.py"; echo "shared/docreview/scripts/docreview_route.py"
  echo "shared/docreview/scripts/docreview_state.py"; echo "shared/docreview/scripts/docreview_config.py"
  echo "shared/docreview/scripts/nofollow_write.py"
  git ls-files -- 'plugins/*/references/docreview-profiles/*.md'
  bash "$(dirname "$0")/docreview_fixture_corpus.sh"; exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPTS="${SCRIPTS:-$REPO_ROOT/plugins/spec-distill/scripts}"
. "$HERE/fixtures/docreview/cases.sh"
. "$HERE/fixtures/docreview/cases_advice.sh"
. "$HERE/fixtures/docreview/cases_ask.sh"
case_ask_short_warn_line_unit
case_ask_status_count_equals_first_line
case_ask_status_no_warns
case_ask_status_nothing_left
case_ask_status_unverified
case_ask_unknown_warn_counted
case_ask_warn_gloss_short_names_total
case_ask_plain_warns_unchanged
case_ask_material_decide_bundle
case_ask_material_no_bundles
case_ask_material_length_mark_uses_width
case_ask_material_absent_fields
case_ask_material_post_decision
case_ask_material_adopt_unavailable
case_ask_material_fix_rows_flag
case_ask_material_blocking_ask_short
case_ask_material_ask_rows_flag
case_ask_material_extra_round
case_ask_material_approve_with_open_tail
case_ask_material_gate_file_failed
case_ask_material_module_missing
case_gate_file_two_zones_match_render
case_gate_file_originals_preserved
case_gate_file_channel_zone_not_duplicated
case_gate_file_advice_included
case_gate_file_round_and_rejected
case_gate_file_symlink_refused
case_gate_file_ledger_untouched
case_gate_file_success_feeds_material
case_gate_file_module_missing
case_gate_file_is_write_command
case_ask_display_path
case_ask_originals_block_unit
finish
