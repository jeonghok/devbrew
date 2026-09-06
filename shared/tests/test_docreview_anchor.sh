#!/usr/bin/env bash
# guards: shared/docreview/scripts/docreview_anchor.py shared/tests/fixtures/docreview/**
#
# 헤딩 단위 앵커 도구의 행동 — 스냅샷 모양 · slug 규칙 · diff 와 얼림 예외 · 보호 부류 캐스케이드 · 인용 수.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/scripts/docreview_anchor.py"; git ls-files -- 'shared/tests/fixtures/docreview/*'; exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPTS="${SCRIPTS:-$REPO_ROOT/plugins/spec-distill/scripts}"
. "$HERE/fixtures/docreview/cases.sh"
case_anchor_snapshot_shape
case_anchor_slug_rules
case_T44_headingless
case_anchor_diff_and_exempt
case_anchor_insert_after
case_anchor_protected_cascade
case_anchor_refs
finish
