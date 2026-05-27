#!/usr/bin/env bash
# v1.32.1 SKILL.md orchestration verification (static grep approach).
#
# Wraps spec verification steps:
#   V2a — AC5: Gate 1 → Gate 2 → Gate 3 first-mention line order monotonic
#   V2b — AC6/AC7/AC8: context anchors + 3-option labels + P21 token
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

# ============== V2a: Gate label order (AC5) ==============
awk '/Gate 1/{if(!g1)g1=NR} /Gate 2/{if(!g2)g2=NR} /Gate 3/{if(!g3)g3=NR} END{
  if (!(g1 && g2 && g3 && g1<g2 && g2<g3)) {
    print "FAIL V2a: Gate label order broken. g1=" g1 " g2=" g2 " g3=" g3
    exit 1
  }
}' "$S" || exit 1
echo "PASS V2a (gate-label order)"

# ============== V2b: Context anchors + options + P21 (AC6/7/8) ==============
check() {
  local needle="$1"
  local label="$2"
  if ! grep -q -- "$needle" "$S"; then
    echo "FAIL V2b: missing $label — needle: $needle"
    exit 1
  fi
}
# Gate 1 FAIL context
check "Plan verification failed" "Gate 1 FAIL anchor"
check "Continue anyway"          "Gate 1 FAIL option"
check "View detail"              "Gate 1 FAIL option"
# Gate 2 iter context
check "findings remain"          "Gate 2 iter anchor"
check "Retry"                    "Gate 2 iter option"
check "Proceed to Gate 3"        "Gate 2 iter option"
# Gate 3 NEEDS_RESOLUTION context
check "Runtime verifier needs"   "Gate 3 anchor"
check "Yes, retry"               "Gate 3 option"
check "Skip with evidence"       "Gate 3 option"
check "P21"                      "P21 secret-policy token"
echo "PASS V2b (context anchors + options + P21)"

# V7 removed in v1.32.1 (see header). Protocol-shape coverage moved to
# tests/harness/test_skill_orchestration_behavior.sh.

echo "All SKILL orchestration checks pass."
