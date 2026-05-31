#!/usr/bin/env bash
# V5 / AC7 / AC8 — web_budget.py enforces sweep<=4, session<=8; kill switch = ok.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/spec-distill/scripts/web_budget.py"
FX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# within budget → exit 0
python3 "$SCRIPT" check "$FX/state-web-within.md" >/dev/null 2>&1 \
  && note PASS "AC7: sweep=4/session=8 within budget (exit 0)" \
  || note FAIL "AC7: within-budget should pass"

# sweep over cap → exit 1
python3 "$SCRIPT" check "$FX/state-web-over-sweep.md" >/dev/null 2>&1 \
  && note FAIL "AC7: sweep=5 should be rejected" \
  || note PASS "AC7: sweep=5 > 4 rejected (exit 1)"

# session over cap → exit 1
python3 "$SCRIPT" check "$FX/state-web-over-session.md" >/dev/null 2>&1 \
  && note FAIL "AC7: session=9 should be rejected" \
  || note PASS "AC7: session=9 > 8 rejected (exit 1)"

# AC8: kill switch forces ok even when over budget (graceful degradation)
DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 python3 "$SCRIPT" check "$FX/state-web-over-sweep.md" >/dev/null 2>&1 \
  && note PASS "AC8: DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 → exit 0 (web disabled)" \
  || note FAIL "AC8: kill switch should short-circuit to ok"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
