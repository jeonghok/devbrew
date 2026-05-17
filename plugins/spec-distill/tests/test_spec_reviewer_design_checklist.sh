#!/usr/bin/env bash
# AC7 — agents/spec-reviewer.md design mode checklist + 6 카테고리.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/spec-reviewer.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# AC7a: design mode section header exists
grep -qE '^##.*[Dd]esign.*[Mm]ode' "$AGENT" \
  && note PASS "AC7: design mode section header exists" \
  || note FAIL "AC7 design mode section header missing"

# AC7b: 6 카테고리 모두 등장
for cat in "placeholder" "ambiguity" "scope.creep" "approaches.compar" "isolation" "testing"; do
  grep -qiE "$cat" "$AGENT" \
    && note PASS "AC7: category '$cat' present" \
    || note FAIL "AC7 category '$cat' missing"
done

# AC7c: spec mode regression — 기존 "11 필수 섹션" 표현 보존
grep -qE '11.*필수.*섹션|missing_section' "$AGENT" \
  && note PASS "AC7: spec mode 11-section table preserved (regression)" \
  || note FAIL "spec mode 11-section text accidentally removed"

# AC7d: Output 형식 (round N + Status + Issues + Stagnation_signal) 보존
grep -q 'Spec Review (round N)' "$AGENT" \
  && grep -q 'Stagnation_signal' "$AGENT" \
  && note PASS "AC7: Output 형식 (round N + Stagnation_signal) preserved" \
  || note FAIL "Output format regression"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
