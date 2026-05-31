#!/usr/bin/env bash
# V1/V2/V3/V6/PN4 — check_brief.py gate: valid brief passes, each ritual-unmet brief fails.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/spec-distill/scripts/check_brief.py"
FX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# Valid brief → gate exit 0 (AC2/AC4/AC5 all satisfied)
python3 "$SCRIPT" gate "$FX/interview-brief-valid.md" >/dev/null 2>&1 \
  && note PASS "valid brief passes gate" \
  || note FAIL "valid brief should pass gate"

# R2/AC4: uncited landscape → fail
python3 "$SCRIPT" gate "$FX/interview-brief-no-landscape.md" >/dev/null 2>&1 \
  && note FAIL "uncited landscape should fail (AC4)" \
  || note PASS "uncited landscape blocks termination (R2/AC4)"

# R3/AC5: malformed skepticism (no URL/verdict) → fail
python3 "$SCRIPT" gate "$FX/interview-brief-unchallenged.md" >/dev/null 2>&1 \
  && note FAIL "malformed skepticism should fail (AC5)" \
  || note PASS "malformed skepticism blocks termination (R3/AC5)"

# AC2: missing numbered section → fail
python3 "$SCRIPT" gate "$FX/interview-brief-missing-section.md" >/dev/null 2>&1 \
  && note FAIL "missing section should fail (AC2)" \
  || note PASS "missing section blocks termination (AC2)"

# R4/V2: empty Tried & Discarded with no N/A sentinel → fail
python3 "$SCRIPT" gate "$FX/interview-brief-empty-tried.md" >/dev/null 2>&1 \
  && note FAIL "empty Tried & Discarded should fail (R4)" \
  || note PASS "empty Tried & Discarded blocks termination (R4/V2)"

# PN4: containment, not exact match — substring check flags the missing URL
python3 "$SCRIPT" skepticism "$FX/interview-brief-unchallenged.md" 2>/dev/null | grep -q 'no-url' \
  && note PASS "PN4: skepticism check flags missing URL via substring containment" \
  || note FAIL "PN4: skepticism containment check did not flag missing URL"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
