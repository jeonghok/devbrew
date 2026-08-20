#!/usr/bin/env bash
# AC12 + AC15(global) + C8 + wiring invariants — structural grep on SKILL.md.
# Teeth: body-unique phrasing grepped inside section windows (header-satisfiable
# 함정 회피). Mutation proof described in the plan Step 5.
set -u -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL="$PLUGIN_ROOT/skills/reviewing-spec/SKILL.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# (1) merge_review.py invoked.
grep -q 'merge_review.py' "$SKILL" && ok "merge_review.py invoked" || no "merge_review.py not wired"
# (2) detect + codex run wired.
grep -q 'detect_codex.sh' "$SKILL" && ok "detect_codex.sh wired" || no "detect_codex.sh missing"
grep -q 'run_spec_codex_reviewer.sh' "$SKILL" && ok "run_spec_codex_reviewer.sh wired" || no "run_spec_codex_reviewer.sh missing"
# (3) combined_verdict feeds routing.
grep -q 'combined_verdict' "$SKILL" && ok "combined_verdict → routing" || no "combined_verdict not fed to routing"

# (4) Stagnation detection section uses merge_review stagnation flag (not Claude self-report ALONE).
#     Body-unique phrase inside the Stagnation section window.
awk '/^### Stagnation detection/{f=1} f{print} /^## /{if(f && !/Stagnation/)exit}' "$SKILL" > /tmp/sd_stag_$$ || true
grep -q 'stagnation' /tmp/sd_stag_$$ && grep -qE 'merge_review|통합.?원장|unified' /tmp/sd_stag_$$ \
  && ok "Stagnation section wired to merge_review unified-ledger flag" \
  || no "Stagnation section still Claude-self-report only"
rm -f /tmp/sd_stag_$$

# (5) C8 verbatim: spec-reviewer raw output stored to --claude-output without summarizing.
grep -qE 'verbatim|그대로|요약.*(금지|말)' "$SKILL" && grep -q -- '--claude-output' "$SKILL" \
  && ok "C8: verbatim --claude-output store" || no "C8: verbatim store not specified"

# (6) AC12 blind-across-rounds: each reviewer gets same-origin history only.
grep -qE 'same-origin|same origin|동일 출처|codex 과거' "$SKILL" \
  && ok "AC12: same-origin history (blind)" || no "AC12: blind history not specified"

# (7) AC15 global kill switch: DEVBREW_SPEC_DISTILL_DISABLE skips the codex path;
#     and Claude review is NOT nested under codex-availability (codex kill != Claude block).
grep -q 'DEVBREW_SPEC_DISTILL_DISABLE_CODEX' "$SKILL" \
  && ok "AC15: codex-only kill switch documented" || no "AC15: codex-only kill switch missing"
grep -qE 'DEVBREW_SPEC_DISTILL_DISABLE\b' "$SKILL" \
  && ok "AC15: global kill switch referenced" || no "AC15: global kill switch missing"

# (8) degrade advisory present.
grep -qE 'degraded|degrade|model diversity 없음' "$SKILL" \
  && ok "degrade advisory present" || no "degrade advisory missing"

# (9) N1: $LEDGER_JSON (merge_review's --history ledger) must live in the
#     continuity (interview-UUID) state dir, NOT the harness-sid dir — a
#     harness-sid ledger would reset re-review cap/stagnation continuity
#     across /compact. Section-scoped: window is the ⟦merge⟧ region only
#     (merge_review.py invocation through the $LEDGER_JSON placement
#     sentence), so this doesn't false-positive on unrelated harness-sid
#     mentions elsewhere in the file (e.g. Step 1's hook-facing trio).
awk '/⟦merge⟧/{f=1} /blind-across-rounds/{if(f) exit} f{print}' "$SKILL" > /tmp/sd_merge_$$
LEDGER_LINE="$(grep -E 'LEDGER_JSON.*둔다' /tmp/sd_merge_$$ | head -1)"
if [[ -z "$LEDGER_LINE" ]]; then
  no "N1: \$LEDGER_JSON placement sentence not found in ⟦merge⟧ window"
else
  # Cut at the placement verb "에 둔다(" — keeps only the affirmative
  # "$LEDGER_JSON is placed in X" clause, dropping the trailing parenthetical
  # (which legitimately mentions harness-sid only to say "collapse 금지").
  PREFIX="$(printf '%s' "$LEDGER_LINE" | sed 's/에 둔다(.*//')"
  if echo "$PREFIX" | grep -qE 'continuity|interview-UUID' \
     && ! echo "$PREFIX" | grep -qiE 'harness[-_]?sid'; then
    ok "N1: \$LEDGER_JSON documented under continuity(interview-UUID) dir, not harness-sid"
  else
    no "N1: \$LEDGER_JSON continuity-location invariant missing or harness-sid drift"
  fi
fi
rm -f /tmp/sd_merge_$$

# (10) FIX 3 (whole-branch review — codex content surfacing): the Step-3
#      consume/display prose must reference `codex_findings` AND
#      `codex_verdict` — without a content channel, codex issues would reach
#      the Human Gate as opaque 12-hex issue_history ids while Claude issues
#      reach the author via prose. Section-scoped to the "Parse merge_review
#      output" step through the Deterministic Routing Table header, so this
#      doesn't false-positive on unrelated mentions elsewhere.
awk '/^3\. \*\*Parse merge_review output\*\*/{f=1} f{print} /^## Deterministic Routing Table/{exit}' "$SKILL" > /tmp/sd_parse_$$
grep -q 'codex_findings' /tmp/sd_parse_$$ && grep -q 'codex_verdict' /tmp/sd_parse_$$ \
  && ok "FIX3: Step-3 consume/display references codex_findings + codex_verdict" \
  || no "FIX3: Step-3 consume/display missing codex_findings/codex_verdict"
rm -f /tmp/sd_parse_$$
finish
