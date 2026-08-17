#!/usr/bin/env bash
# Cross-file invariant: re-review hard cap value must be consistent across
# SKILL.md body (source of truth), frontmatter description, routing table,
# README.md ASCII flow, README.md AP16 line, and design-routing test assertions.
#
# Catches the v0.3.0-style drift where the cap was bumped in body + CHANGELOG
# only, leaving the routing table / frontmatter / README / test stale —
# which silently made cap=5 dead code (the >=3 routing row fired first).
#
# devbrew Law 3 (Compounding) instantiation: when a future PR bumps the cap
# again, this test fails until every derived location is updated together.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL="$REPO_ROOT/plugins/spec-distill/skills/reviewing-spec/SKILL.md"
README="$REPO_ROOT/plugins/spec-distill/README.md"
ROUTING_TEST="$REPO_ROOT/plugins/spec-distill/tests/test_reviewing_spec_design_routing.sh"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# Source of truth: SKILL.md body "Hard cap**: `rereview_count >= N`" line.
CAP="$(grep -oE 'Hard cap\*\*:[[:space:]]*`rereview_count >= [0-9]+`' "$SKILL" | grep -oE '[0-9]+`$' | tr -d '`' | head -1)"
if [[ -z "${CAP:-}" ]]; then
  echo "✗ FATAL: source-of-truth pattern not found in $SKILL"
  echo "  expected line: '**Hard cap**: \`rereview_count >= N\`'"
  exit 1
fi
echo "Source-of-truth cap = $CAP (from SKILL.md body)"
echo

grep -qE "review cap \(max $CAP," "$SKILL" \
  && ok "SKILL.md frontmatter: 'review cap (max $CAP, ...)'" \
  || no "SKILL.md frontmatter drift (expected 'max $CAP')"

# v0.12.0: spec-mode rows removed — only design rows carry the cap now.
grep -qE "\*\*design\*\*.*\| < $CAP \|" "$SKILL" \
  && ok "SKILL.md routing: design '< $CAP' row" \
  || no "SKILL.md routing: design '< $CAP' row missing"

grep -qE "\*\*design\*\*.*\| >= $CAP \|" "$SKILL" \
  && ok "SKILL.md routing: design '>= $CAP' row" \
  || no "SKILL.md routing: design '>= $CAP' row missing"

grep -qE "auto re-review, max $CAP" "$README" \
  && ok "README.md ASCII flow: 'auto re-review, max $CAP'" \
  || no "README.md ASCII flow drift (expected 'auto re-review, max $CAP')"

grep -qE "re-review max $CAP" "$README" \
  && ok "README.md AP16: 're-review max $CAP'" \
  || no "README.md AP16 drift (expected 're-review max $CAP')"

# Strip comment lines before matching — a stale comment with the old cap value
# would otherwise mask a wrong assertion on the next line (codex-1 finding).
# Only the executable code path counts. Use -F (fixed string) so the literal
# regex-string "count >?= ?N" in the peer assertion matches without the `?`s
# being re-interpreted as regex meta-characters.
if grep -vE '^[[:space:]]*#' "$ROUTING_TEST" | grep -qF "count >?= ?$CAP"; then
  ok "test_reviewing_spec_design_routing.sh asserts cap $CAP (in non-comment line)"
else
  ACTUAL="$(grep -vE '^[[:space:]]*#' "$ROUTING_TEST" | grep -oE 'count >?= ?[0-9]+' | grep -oE '[0-9]+' | head -1)"
  no "test_reviewing_spec_design_routing.sh asserts different cap (found: ${ACTUAL:-unknown}, expected: $CAP)"
fi
finish
