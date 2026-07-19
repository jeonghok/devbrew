#!/usr/bin/env bash
# AC2 (v2.13.0) — codex is a Tier B availability-floor: dispatched whenever
# detect_codex is true, regardless of diff scope. SKILL.md prose invariant
# (proxy — real LLM dispatch is manual self-dogfood). Rewritten from the
# pre-2.13.0 `codex_manifest.codex_available == true/false` phase1_agents
# fallback structure, which the scope-driven rewrite removed.
set -u
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "OK: $1"; }

REPO_ROOT="$(git rev-parse --show-toplevel)"
SKILL="$REPO_ROOT/plugins/quality-gates/skills/quality-pipeline/SKILL.md"

# 1. Tier B codex availability-floor prose present (body-unique anchor).
grep -qF 'Tier B — codex (availability-floor' "$SKILL" \
  || fail "1: SKILL missing Tier B codex availability-floor anchor"
ok "1: Tier B codex availability-floor anchor present"

# 2. codex is scope-independent (dispatched regardless of scope when available).
#    Anchor the '스코프 무관' claim within the Tier B window (Tier B anchor → next
#    '**Tier C' or '## ' heading) so it can't be satisfied by the Tier A floor line.
tb_start=$(awk '/Tier B — codex \(availability-floor/{print NR; exit}' "$SKILL")
tb_end=$(awk -v s="$tb_start" 'NR>s && (/\*\*Tier C/ || /^## /){print NR; exit}' "$SKILL")
if [[ -n "$tb_start" && -n "$tb_end" ]] && awk -v s="$tb_start" -v e="$tb_end" 'NR>=s && NR<e' "$SKILL" | grep -qF '스코프'; then
  ok "2: codex dispatch is scope-independent (in Tier B window $tb_start..$tb_end)"
else
  fail "2: Tier B window lacks a scope-independence claim (s=$tb_start e=$tb_end)"
fi

# 3. codex dispatched via run_codex_reviewer.sh (script-based, T3-3 unchanged).
grep -qF 'run_codex_reviewer.sh' "$SKILL" \
  || fail "3: SKILL missing run_codex_reviewer.sh invocation"
ok "3: run_codex_reviewer.sh invocation present"

# 4. Floor dispatch blocks still thread project_dir (contract preserved through rewrite).
for name in security-reviewer adversarial; do
  awk -v name="quality-gates:$name" '
    $0 ~ name { found=NR }
    found && NR <= found+12 && /project_dir:/ { ok=1; exit }
    END { exit !ok }
  ' "$SKILL" || fail "4: floor dispatch block for $name lacks project_dir within 12 lines"
done
ok "4: floor dispatch blocks (security-reviewer + adversarial) thread project_dir"

# 5. Negative: the removed pre-2.13.0 fallback structure must be GONE.
for stale in 'codex_manifest.codex_available == false' 'codex_manifest.codex_available == true'; do
  if grep -qF "$stale" "$SKILL"; then
    fail "5: stale pre-2.13.0 codex_manifest prose still present — '$stale'"
  fi
done
ok "5: stale codex_manifest fallback prose absent (scope-driven rewrite)"

echo "PASS: test_codex_dispatch_invariant.sh (Tier B availability-floor, 5 checks)"
