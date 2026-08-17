#!/usr/bin/env bash
# v1.32.1 SKILL.md orchestration verification (static grep approach).
#
# Wraps spec verification steps:
#   V2a: Review gate → Runtime gate first-mention line order monotonic
#   V2b: context anchors + 3-option labels + P21 token
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

# ============== V2a: gate label order ==============
awk '/Review gate/{if(!r)r=NR} /Runtime gate/{if(!rt)rt=NR} END{
  if (!(r && rt && r<rt)) {
    print "FAIL V2a: gate label order broken. review=" r " runtime=" rt
    exit 1
  }
}' "$S" || exit 1
echo "PASS V2a (gate-label order: review < runtime)"

# ============== V2b: Context anchors + options + P21 (AC6/7/8) ==============
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
# Review iter context
assert_file_grep "$S" 'findings remain' "Review iter anchor"
# AC6 anchor uniqueness (Medium): `findings remain` must appear in EXACTLY
# ONE AskUserQuestion question template, so the routing is unambiguous.
# Prose mentions and meta-comments outside `question:` lines are allowed.
question_findings=$(awk '/^[[:space:]]*question:/ && /findings remain/ { c++ } END { print c+0 }' "$S")
if [[ "$question_findings" -ne 1 ]]; then
  echo "FAIL V2b uniqueness: 'findings remain' appears in $question_findings question: lines (expected 1)"
  exit 1
fi
echo "PASS V2b (anchor uniqueness: 1 question line)"
assert_file_grep "$S" 'Retry' "Review iter option"
assert_file_grep "$S" 'Proceed to Runtime gate' "Review iter option"
# Runtime NEEDS_RESOLUTION context
assert_file_grep "$S" 'Runtime verifier needs' "Runtime anchor"
assert_file_grep "$S" 'Yes, retry' "Runtime option"
assert_file_grep "$S" 'Skip with evidence' "Runtime option"
assert_file_grep "$S" 'P21' "P21 secret-policy token"

# V7 removed in v1.32.1 (see header). Protocol-shape coverage moved to
# tests/harness/test_skill_orchestration_behavior.sh.

finish
