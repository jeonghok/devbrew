#!/usr/bin/env bash
# guards: shared/docreview/scripts/docreview_advice.py shared/docreview/scripts/docreview_route.py shared/docreview/scripts/docreview_state.py plugins/*/references/docreview-profiles/*.md shared/tests/fixtures/docreview/**
#
# must-catch 축 / 참고(advisory) 축 라우팅의 행동 — 설계 2026-09-27-review-stopping-criterion.
# 케이스 본문은 fixtures/docreview/cases_advice.sh 에 있다(변이 매트릭스와 공유). 실제 프로필(must_catch 지목)로 돈다.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/scripts/docreview_advice.py"; echo "shared/docreview/scripts/docreview_route.py"
  echo "shared/docreview/scripts/docreview_state.py"
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
case_AC1_brief_direction_only
case_AC1_brief_direction_distortion
case_AC3_reference_line_positive
case_AC13_advisory_decide_ask_to_advice
case_AC19_promoted_advisory_fix
case_AC5_AC9_round2
case_AC9_child_section_changed
finish
