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

# --- v0.20.0 co-reviewer contract: sentinel block + Status line + no issue_id self-report ---

# (A) sentinel fence info-string documented (exact token).
grep -q 'spec-review-issues' "$AGENT" \
  && note PASS "v0.20.0: sentinel fence 'spec-review-issues' documented" \
  || note FAIL "v0.20.0: sentinel fence token missing"

# (B) sentinel block JSON keys required (body-unique phrasing, not header-satisfiable).
for key in 'category' 'target_section' 'severity' 'message'; do
  grep -q "$key" "$AGENT" && note PASS "v0.20.0: sentinel key '$key'" || note FAIL "v0.20.0: sentinel key '$key' missing"
done

# (C) top-level **Status:** line still the verdict source of truth.
grep -qE '\*\*Status:\*\*' "$AGENT" \
  && note PASS "v0.20.0: **Status:** verdict line preserved" \
  || note FAIL "v0.20.0: **Status:** line removed"

# (D) issue_id self-report REMOVED — reviewer must no longer be told to emit
#     sha256_short itself (merge_review + compute_issue_id own it). Teeth: the
#     old self-report instruction phrase must be gone from the Output contract.
grep -q 'sha256_short(category' "$AGENT" \
  && note FAIL "v0.20.0: issue_id self-report (sha256_short) still instructed" \
  || note PASS "v0.20.0: issue_id self-report removed"

# (E) compute_issue_id referenced as the id authority.
grep -q 'compute_issue_id' "$AGENT" \
  && note PASS "v0.20.0: compute_issue_id referenced" \
  || note FAIL "v0.20.0: compute_issue_id reference missing"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
