#!/usr/bin/env bash
# v1.32.1 SKILL.md orchestration verification (static grep approach).
#
# Wraps spec verification steps:
#   V2b: context anchors + option labels
#
# V2a (Review gate → Runtime gate first-mention line order) was REMOVED in
# PR4b: 한 파이프라인에는 별도 dispatch 지점으로서의 "Runtime gate" 가 없다 —
# 순서 비교 자체가 무의미해졌다(대상 소멸). Protocol-shape coverage for the
# surviving skeleton lives in tests/harness/test_skill_orchestration_behavior.sh
# and tests/test_one_pipeline_surface.sh.
#
# V7 was REMOVED in v1.32.1 (C6 atomicity, spec §5.1/§5.6.9): the
# `grep -c '\bPASS\b'` token never appeared in SKILL.md, so V7's
# negative-assertion path was unreachable (tautological PASS). Replaced
# by tests/harness/test_skill_orchestration_behavior.sh, which asserts
# the orchestration protocol-shape (dispatch ordering, proximity, and
# fan-out membership) without any unreachable code paths.
#
# Exit 0 if all pass; non-zero with diagnostic on first failure.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
S="$ROOT/quality-gates/skills/quality-pipeline/SKILL.md"

if [[ ! -f "$S" ]]; then
  echo "FAIL: SKILL.md not found at $S"
  exit 1
fi

# ============== V2b: Context anchors + option labels (AC6/7) ==============
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
# Fix-loop iter context
assert_file_grep "$S" 'findings remain' "Fix-loop iter anchor"
# AC6 anchor uniqueness (Medium): `findings remain` must appear in EXACTLY
# ONE AskUserQuestion question template, so the routing is unambiguous.
# Prose mentions and meta-comments outside `question:` lines are allowed.
question_findings=$(awk '/^[[:space:]]*question:/ && /findings remain/ { c++ } END { print c+0 }' "$S")
if [[ "$question_findings" -ne 1 ]]; then
  echo "FAIL V2b uniqueness: 'findings remain' appears in $question_findings question: lines (expected 1)"
  exit 1
fi
echo "PASS V2b (anchor uniqueness: 1 question line)"
assert_file_grep "$S" 'Retry' "Fix-loop iter option"
assert_file_grep "$S" 'Accept and finish' "Fix-loop iter option"

# V7 removed in v1.32.1 (see header). Runtime NEEDS_RESOLUTION decision
# context (P21 / 'Runtime verifier needs') was removed in PR4b along with
# the decision tool it anchored (대상 소멸). Protocol-shape coverage moved to
# tests/harness/test_skill_orchestration_behavior.sh.

finish
