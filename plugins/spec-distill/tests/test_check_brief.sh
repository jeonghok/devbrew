#!/usr/bin/env bash
# V1/V2/V3/V6/PN4 — check_brief.py gate: valid brief passes, each ritual-unmet brief fails.
# F3 — empty §3 External Landscape blocks (presence of header is not enough).
# F4 — section headers inside a fenced code block do not satisfy the gate.
# F5 — gate on an unreadable brief emits structured JSON + exit 1 (no traceback).
# F6 — a frontmatter steelman claim with no §4 entry blocks (cross-consistency).
# F9-A/B — frontmatter-validation path and N/A-sentinel branch covered.
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

# F3: §3 present but empty (no entries, no web-disabled sentinel) → fail
python3 "$SCRIPT" gate "$FX/interview-brief-empty-landscape.md" >/dev/null 2>&1 \
  && note FAIL "F3: empty External Landscape should fail (header presence != research)" \
  || note PASS "F3: empty External Landscape blocks termination"

# F4: all section headers inside a fenced code block → not authored content → fail
python3 "$SCRIPT" gate "$FX/interview-brief-fenced-sections.md" >/dev/null 2>&1 \
  && note FAIL "F4: fenced-only section headers should not satisfy the gate" \
  || note PASS "F4: fenced section headers do not satisfy the gate"

# F5: unreadable brief → structured JSON {"pass": false, ...} + exit 1, NOT a traceback
out="$(python3 "$SCRIPT" gate "$FX/__no_such_brief__.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q '"pass": false'; } \
  && note PASS "F5: unreadable brief → structured JSON + exit 1 (no traceback)" \
  || note FAIL "F5: unreadable brief should emit structured failure JSON, not crash"
printf '%s' "$out" | grep -qi 'Traceback' \
  && note FAIL "F5: gate dumped a Python traceback on unreadable brief" \
  || note PASS "F5: no traceback leaked to stdout"

# F6: frontmatter claims steelman: defended but §4 Skepticism Log is empty → fail
python3 "$SCRIPT" gate "$FX/interview-brief-steelman-unlogged.md" >/dev/null 2>&1 \
  && note FAIL "F6: steelman-claimed direction with no §4 entry should fail" \
  || note PASS "F6: unlogged steelman claim blocks termination (cross-consistency)"

# F9-A: frontmatter-validation failure class (wrong type/next_phase/missing locked_directions)
python3 "$SCRIPT" gate "$FX/interview-brief-bad-frontmatter.md" >/dev/null 2>&1 \
  && note FAIL "F9-A: bad frontmatter should fail the gate (AC1)" \
  || note PASS "F9-A: bad frontmatter blocks termination (AC1)"

# F9-B: §5 N/A sentinel is a legitimate pass (R4 edge — first-time defend+lock)
python3 "$SCRIPT" gate "$FX/interview-brief-na-tried.md" >/dev/null 2>&1 \
  && note PASS "F9-B: N/A Tried-&-Discarded sentinel passes (R4 edge)" \
  || note FAIL "F9-B: N/A sentinel should pass the gate"

# F8: a URL-less user-judgment §4 entry blocks when web is enabled...
python3 "$SCRIPT" gate "$FX/interview-brief-web-disabled.md" >/dev/null 2>&1 \
  && note FAIL "F8: URL-less skepticism should fail when web is enabled" \
  || note PASS "F8: URL-less skepticism blocks the gate when web is enabled"
# ...but the gate honors the kill switch (AC8 symmetry): web-disabled → URL relaxed,
# so the SKILL's documented web-absent degradation is mechanically backed.
DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 python3 "$SCRIPT" gate "$FX/interview-brief-web-disabled.md" >/dev/null 2>&1 \
  && note PASS "F8: web-disabled gate accepts URL-less user-judgment skepticism (AC8)" \
  || note FAIL "F8: web-disabled gate should accept URL-less skepticism per the SKILL clause"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
