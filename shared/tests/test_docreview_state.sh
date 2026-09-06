#!/usr/bin/env bash
# guards: shared/docreview/scripts/docreview_state.py shared/tests/fixtures/docreview/**
#
# docreview 원장의 **행동**을 고정한다 — D13 전이표의 상태·라운드·게이트 셀.
# 케이스 본문은 fixtures/docreview/cases.sh 에 있다(mutation 락과 공유).
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/scripts/docreview_state.py"
  git ls-files -- 'shared/tests/fixtures/docreview/*'
  exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPTS="${SCRIPTS:-$REPO_ROOT/plugins/spec-distill/scripts}"
. "$HERE/fixtures/docreview/cases.sh"
case_T37_cap_and_extra
finish
