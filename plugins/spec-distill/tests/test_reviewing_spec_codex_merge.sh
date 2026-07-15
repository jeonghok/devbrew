#!/usr/bin/env bash
# AC12 + AC15(global) + C8 + wiring invariants — structural grep on SKILL.md.
# Teeth: body-unique phrasing grepped inside section windows (header-satisfiable
# 함정 회피). Mutation proof described in the plan Step 5.
set -u -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL="$PLUGIN_ROOT/skills/reviewing-spec/SKILL.md"

pass=0; fail=0
note() { if [[ "$1" == PASS ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# (1) merge_review.py invoked.
grep -q 'merge_review.py' "$SKILL" && note PASS "merge_review.py invoked" || note FAIL "merge_review.py not wired"
# (2) detect + codex run wired.
grep -q 'detect_codex.sh' "$SKILL" && note PASS "detect_codex.sh wired" || note FAIL "detect_codex.sh missing"
grep -q 'run_spec_codex_reviewer.sh' "$SKILL" && note PASS "run_spec_codex_reviewer.sh wired" || note FAIL "run_spec_codex_reviewer.sh missing"
# (3) combined_verdict feeds routing.
grep -q 'combined_verdict' "$SKILL" && note PASS "combined_verdict → routing" || note FAIL "combined_verdict not fed to routing"

# (4) Stagnation detection section uses merge_review stagnation flag (not Claude self-report ALONE).
#     Body-unique phrase inside the Stagnation section window.
awk '/^### Stagnation detection/{f=1} f{print} /^## /{if(f && !/Stagnation/)exit}' "$SKILL" > /tmp/sd_stag_$$ || true
grep -q 'stagnation' /tmp/sd_stag_$$ && grep -qE 'merge_review|통합.?원장|unified' /tmp/sd_stag_$$ \
  && note PASS "Stagnation section wired to merge_review unified-ledger flag" \
  || note FAIL "Stagnation section still Claude-self-report only"
rm -f /tmp/sd_stag_$$

# (5) C8 verbatim: spec-reviewer raw output stored to --claude-output without summarizing.
grep -qE 'verbatim|그대로|요약.*(금지|말)' "$SKILL" && grep -q -- '--claude-output' "$SKILL" \
  && note PASS "C8: verbatim --claude-output store" || note FAIL "C8: verbatim store not specified"

# (6) AC12 blind-across-rounds: each reviewer gets same-origin history only.
grep -qE 'same-origin|same origin|동일 출처|codex 과거' "$SKILL" \
  && note PASS "AC12: same-origin history (blind)" || note FAIL "AC12: blind history not specified"

# (7) AC15 global kill switch: DEVBREW_DISABLE_SPEC_DISTILL skips the codex path;
#     and Claude review is NOT nested under codex-availability (codex kill != Claude block).
grep -q 'DEVBREW_DISABLE_SPEC_DISTILL_CODEX' "$SKILL" \
  && note PASS "AC15: codex-only kill switch documented" || note FAIL "AC15: codex-only kill switch missing"
grep -qE 'DEVBREW_DISABLE_SPEC_DISTILL\b' "$SKILL" \
  && note PASS "AC15: global kill switch referenced" || note FAIL "AC15: global kill switch missing"

# (8) degrade advisory present.
grep -qE 'degraded|degrade|model diversity 없음' "$SKILL" \
  && note PASS "degrade advisory present" || note FAIL "degrade advisory missing"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"; [[ $fail -eq 0 ]]
