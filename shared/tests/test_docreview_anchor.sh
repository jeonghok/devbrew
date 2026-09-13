#!/usr/bin/env bash
# guards: shared/docreview/scripts/docreview_anchor.py shared/docreview/scripts/docreview_state.py shared/tests/fixtures/docreview/**
#
# 헤딩 단위 앵커 도구의 행동 — 스냅샷 모양 · slug 규칙 · diff 와 얼림 예외 · 보호 부류 캐스케이드 · 인용 수.
# diff 계산(`diff_snapshots` · `resolve_scope`)과 보호 부류 판정(`anchors_matching`)은 `docreview_state.py` 에 산다 —
# 엔진이 원장의 스냅숏으로 같은 diff 를 계산한다(PR 3 qg iter 3). 그래서 이 락은 그 파일도 지킨다.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/scripts/docreview_anchor.py"; echo "shared/docreview/scripts/docreview_state.py"
  bash "$(dirname "$0")/docreview_fixture_corpus.sh"; exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPTS="${SCRIPTS:-$REPO_ROOT/plugins/spec-distill/scripts}"
. "$HERE/fixtures/docreview/cases.sh"
case_anchor_snapshot_shape
case_anchor_slug_rules
case_T44_headingless
case_T44b_headingless_freeze_inactive
case_anchor_diff_and_exempt
case_anchor_insert_after
case_anchor_protected_cascade
case_anchor_refs
finish
