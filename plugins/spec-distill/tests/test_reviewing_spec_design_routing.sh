#!/usr/bin/env bash
# AC5 + AC6 — reviewing-spec SKILL.md design mode branch + routing rows.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL="$REPO_ROOT/plugins/spec-distill/skills/reviewing-spec/SKILL.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# AC5: Step 1 mode branch
grep -qE 'pending_review.*mode|mode.*분기.*design' "$SKILL" \
  && grep -qE '11.section|locked_decisions' "$SKILL" \
  && note PASS "AC5: Step 1 references mode branch + 11-section/locked_decisions skip" \
  || note FAIL "AC5 mode branch missing in Step 1"

# AC6: design rows in routing table
# (approved → Human Gate → writing-plans)
grep -qE 'design\b.*approved.*Human Gate' "$SKILL" \
  && note PASS "AC6: design approved → Human Gate row present" \
  || note FAIL "AC6 design approved row missing"

# (needs_revise & count<3 → brainstorming author 회귀)
grep -qE 'design\b.*needs_revise.*brainstorming author' "$SKILL" \
  && note PASS "AC6: design needs_revise → brainstorming author 회귀 row present" \
  || note FAIL "AC6 design needs_revise row missing"

# (drafting-spec 미호출 명시)
grep -qE 'drafting-spec.*미호출|drafting-spec.*호출하지 (않|않음)' "$SKILL" \
  && note PASS "AC6: 'drafting-spec 미호출' explicit text present" \
  || note FAIL "AC6 drafting-spec exclusion missing"

# (forced Human Gate at count >= 3)
grep -qE 'design\b.*count >?= ?3|design\b.*>=.*3.*Human Gate' "$SKILL" \
  && note PASS "AC6: design count>=3 forced Human Gate row present" \
  || note FAIL "AC6 design forced escalate row missing"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
