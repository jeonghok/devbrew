#!/usr/bin/env bash
# PN2/V8/AC10 — reviewing-spec is design-mode only; spec-mode/re-consensus/Mode B removed;
# drafting-spec absent from skills/hooks/commands.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PLUGIN="$REPO_ROOT/plugins/spec-distill"
SKILL="$PLUGIN/skills/reviewing-spec/SKILL.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

grep -qE 'design\b.*approved.*Human Gate' "$SKILL" \
  && note PASS "design approved → Human Gate row present" || note FAIL "design approved row missing"
grep -qE 'design\b.*needs_revise.*author' "$SKILL" \
  && note PASS "design needs_revise → author 회귀 row present" || note FAIL "design needs_revise row missing"

grep -qiE 'reconsensus|re-consensus|\[3\.5\]' "$SKILL" \
  && note FAIL "re-consensus gate still present (should be removed)" \
  || note PASS "re-consensus [3.5] removed"
grep -qE 'mode_b_violation' "$SKILL" \
  && note FAIL "mode_b_violation still present" || note PASS "mode_b_violation removed"
grep -qE '^\|[[:space:]]*\**[[:space:]]*spec\b' "$SKILL" \
  && note FAIL "spec-mode routing rows still present" || note PASS "spec-mode routing rows removed"
grep -q 'drafting-spec' "$SKILL" \
  && note FAIL "drafting-spec still referenced in reviewing-spec" || note PASS "drafting-spec ref removed from reviewing-spec"

COUNT=$(grep -rl 'drafting-spec' "$PLUGIN/skills" "$PLUGIN/hooks" "$PLUGIN/commands" 2>/dev/null | wc -l | tr -d ' ')
[[ "$COUNT" == "0" ]] && note PASS "AC10: 0 drafting-spec refs in skills/hooks/commands" \
  || note FAIL "AC10: $COUNT drafting-spec refs remain"
[[ ! -d "$PLUGIN/skills/drafting-spec" ]] && note PASS "drafting-spec/ directory removed" \
  || note FAIL "drafting-spec/ directory still exists"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
