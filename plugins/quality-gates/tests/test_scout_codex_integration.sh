#!/usr/bin/env bash
# Static check: scout.md declares codex_manifest as a pass-through Input
# and explicitly disclaims making codex-reviewer dispatch decisions.
# Architecture: codex-reviewer dispatch was moved from scout to SKILL.md in
# commit 4c9e7d2 (LD4). These checks guard against drift back.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCOUT_MD="$PLUGIN_ROOT/agents/scout.md"

pass=0; fail=0
check() {
  local name="$1" pattern="$2"
  if grep -q "$pattern" "$SCOUT_MD"; then
    echo "  PASS: $name"; pass=$((pass + 1))
  else
    echo "  FAIL: $name (pattern not found: $pattern)"
    fail=$((fail + 1))
  fi
}

# 1. codex_manifest must still appear in Inputs (pass-through field)
check "Inputs lists codex_manifest" 'codex_manifest'

# 2. scout.md must explicitly disclaim codex dispatch decisions (LD4 guard)
check "scout explicitly disclaims codex dispatch decisions" '사용하지 않는다\|does not use\|LD4'

# 3. scout.md must NOT contain codex depth-selection rule prose
#    (SKILL.md owns this; if it reappears here, that is a regression)
if grep -q 'codex_available.*\(standard\|deep\)\|codex_available.*depth' "$SCOUT_MD"; then
  echo "  FAIL: scout.md still has codex dispatch selection rule (SKILL.md owns this — LD4)"
  fail=$((fail + 1))
else
  echo "  PASS: scout.md does not select codex-reviewer depth (SKILL.md owns this now)"
  pass=$((pass + 1))
fi

# 4. scout.md must NOT reference codex-reviewer in any Phase 1 selection table
#    (the agent list in the table must only contain non-codex reviewers)
if grep -q 'codex-reviewer' "$SCOUT_MD"; then
  echo "  FAIL: scout.md references codex-reviewer (should be removed — SKILL.md owns dispatch)"
  fail=$((fail + 1))
else
  echo "  PASS: scout.md does not reference codex-reviewer in Phase 1 table"
  pass=$((pass + 1))
fi

# Scenario 5 (T2-2 / AC7-AC8) — unified dispatch heading + fan-out gate
# applies to both primary and fallback paths.
test_scenario_5_unified_dispatch() {
  echo "=== Scenario 5: Phase 1 unified dispatch + fan-out gate ==="
  local skill="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"

  # AC7-a: exactly one unified heading (4 hashes — preserves Gate 2 nesting).
  local count_unified
  count_unified=$(grep -c '^#### Phase 1 (unified dispatch)' "$skill" || true)
  if [[ "$count_unified" == "1" ]]; then
    echo "  PASS: AC7-a: unified heading count=$count_unified (expected 1)"
    pass=$((pass + 1))
  else
    echo "  FAIL AC7-a: unified heading count=$count_unified (expected 1)"
    fail=$((fail + 1))
  fi

  # AC7-b: legacy/fallback heading absent.
  local count_legacy
  count_legacy=$(grep -cE '^#### Phase 1 \(legacy/fallback\)' "$skill" || true)
  if [[ "$count_legacy" == "0" ]]; then
    echo "  PASS: AC7-b: legacy heading count=$count_legacy (expected 0)"
    pass=$((pass + 1))
  else
    echo "  FAIL AC7-b: legacy heading count=$count_legacy (expected 0)"
    fail=$((fail + 1))
  fi

  # Extract unified block (heading → next #### heading).
  local block
  block=$(awk '/^#### Phase 1 \(unified dispatch\)/{flag=1; print; next} flag && /^#### /{exit} flag{print}' "$skill")

  # AC7-c: unified block contains AskUserQuestion + Task invocation.
  if echo "$block" | grep -q 'AskUserQuestion('; then
    echo "  PASS: AC7-c: AskUserQuestion present in unified block"
    pass=$((pass + 1))
  else
    echo "  FAIL AC7-c: AskUserQuestion missing from unified block"
    fail=$((fail + 1))
  fi

  if echo "$block" | grep -qE 'Task\(|Task tool|parallel=true'; then
    echo "  PASS: AC7-c: parallel dispatch prose present in unified block"
    pass=$((pass + 1))
  else
    echo "  FAIL AC7-c: parallel dispatch prose missing from unified block"
    fail=$((fail + 1))
  fi

  # AC8: fallback branch is named within the unified block (so reader knows
  # the same gate applies to both paths).
  if echo "$block" | grep -qiE 'fallback|scout.failed|rule-based'; then
    echo "  PASS: AC8: fallback branch documented in unified block"
    pass=$((pass + 1))
  else
    echo "  FAIL AC8: fallback branch not documented in unified block"
    fail=$((fail + 1))
  fi

  echo "=== Scenario 5 done ==="
}
test_scenario_5_unified_dispatch

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[[ $fail -eq 0 ]] || exit 1
