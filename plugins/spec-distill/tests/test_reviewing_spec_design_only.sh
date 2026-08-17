#!/usr/bin/env bash
# PN2/V8/AC10 — reviewing-spec is design-mode only; spec-mode/re-consensus/Mode B removed;
# drafting-spec absent from skills/hooks/commands.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PLUGIN="$REPO_ROOT/plugins/spec-distill"
SKILL="$PLUGIN/skills/reviewing-spec/SKILL.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

grep -qE 'design\b.*approved.*Human Gate' "$SKILL" \
  && ok "design approved → Human Gate row present" || no "design approved row missing"
grep -qE 'design\b.*needs_revise.*author' "$SKILL" \
  && ok "design needs_revise → author 회귀 row present" || no "design needs_revise row missing"

grep -qiE 'reconsensus|re-consensus|\[3\.5\]' "$SKILL" \
  && no "re-consensus gate still present (should be removed)" \
  || ok "re-consensus [3.5] removed"
grep -qE 'mode_b_violation' "$SKILL" \
  && no "mode_b_violation still present" || ok "mode_b_violation removed"
grep -qE '^\|[[:space:]]*\**[[:space:]]*spec\b' "$SKILL" \
  && no "spec-mode routing rows still present" || ok "spec-mode routing rows removed"
grep -q 'drafting-spec' "$SKILL" \
  && no "drafting-spec still referenced in reviewing-spec" || ok "drafting-spec ref removed from reviewing-spec"

# F9-D: scan agents/ + templates/ too — the exact dirs this PR cleaned of
# drafting-spec/Mode-B refs (spec-reviewer persona, spec-template comment).
COUNT=$(grep -rl 'drafting-spec' "$PLUGIN/skills" "$PLUGIN/hooks" "$PLUGIN/commands" \
  "$PLUGIN/agents" "$PLUGIN/templates" 2>/dev/null | wc -l | tr -d ' ')
[[ "$COUNT" == "0" ]] && ok "AC10/F9-D: 0 drafting-spec refs in skills/hooks/commands/agents/templates" \
  || no "AC10/F9-D: $COUNT drafting-spec refs remain"
[[ ! -d "$PLUGIN/skills/drafting-spec" ]] && ok "drafting-spec/ directory removed" \
  || no "drafting-spec/ directory still exists"
finish
