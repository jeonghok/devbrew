#!/usr/bin/env bash
# guards: shared/docreview/scripts/docreview_anchor.py shared/tests/fixtures/docreview/**
#
# check-intent 의 두 계약(AC6) — 일반 fix(edit_scope·fix_anchors·보호·불변) / decision permit(라운드·apply_anchors·불변만).
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/scripts/docreview_anchor.py"; git ls-files -- 'shared/tests/fixtures/docreview/*'; exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPTS="${SCRIPTS:-$REPO_ROOT/plugins/spec-distill/scripts}"
. "$HERE/fixtures/docreview/cases.sh"
case_AC6_fix_contract
case_AC6_insert_after
case_AC6_permit_contract
case_AC6_reject_reasons_extra
finish
