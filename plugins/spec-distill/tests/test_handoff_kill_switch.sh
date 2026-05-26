#!/usr/bin/env bash
# AC6 — DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK=1 must bypass handoff_incomplete only.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/spec-reviewer.md"
README="$REPO_ROOT/plugins/spec-distill/README.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# AC6a: kill switch env var 이름 in agent
grep -q 'DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK' "$AGENT" \
  && note PASS "AC6: kill switch env var referenced in agent" \
  || note FAIL "AC6 kill switch env var missing from agent"

# AC6b: README Kill switches 표에 행 추가
grep -q 'DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK' "$README" \
  && note PASS "AC6: kill switch documented in README" \
  || note FAIL "AC6 kill switch not in README"

# AC6c: loud warning 텍스트 명시
grep -qE 'handoff readiness 검증 비활성화|handoff.*disabled' "$AGENT" \
  && note PASS "AC6: loud warning text present" \
  || note FAIL "AC6 loud warning text missing"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
