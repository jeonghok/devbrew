#!/usr/bin/env bash
# Static check: scout.py is the deterministic replacement for agents/scout.md.
# Architecture: scout was migrated to scripts/scout.py in v1.29.0 (T3-1).
# These checks guard:
#   1. agents/scout.md is absent (deleted in T3-1).
#   2. scripts/scout.py exists and is executable.
#   3. SKILL.md Phase 0 references scout.py invocation (not Agent() dispatch).
#   4. SKILL.md codex dispatch remains owned by SKILL.md (LD4 guard — unchanged by T3-1).

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCOUT_MD="$PLUGIN_ROOT/agents/scout.md"
SCOUT_PY="$PLUGIN_ROOT/scripts/scout.py"
SKILL_MD="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"

pass=0; fail=0
check_true() {
  local name="$1" result="$2"
  if [[ "$result" == "0" ]]; then
    echo "  PASS: $name"; pass=$((pass + 1))
  else
    echo "  FAIL: $name"; fail=$((fail + 1))
  fi
}
check_false() {
  local name="$1" result="$2"
  if [[ "$result" != "0" ]]; then
    echo "  PASS: $name"; pass=$((pass + 1))
  else
    echo "  FAIL: $name (should be absent/false)"; fail=$((fail + 1))
  fi
}

# 1. agents/scout.md must be absent (deleted in T3-1)
check_false "agents/scout.md absent post-T3-1" "$(test -f "$SCOUT_MD"; echo $?)"

# 2. scripts/scout.py must exist
check_true "scripts/scout.py exists" "$(test -f "$SCOUT_PY"; echo $?)"

# 3. scripts/scout.py must be executable
check_true "scripts/scout.py is executable" "$(test -x "$SCOUT_PY"; echo $?)"

# 4. SKILL.md Phase 0 references scout.py invocation (script-based dispatch)
if grep -q 'scripts/scout.py' "$SKILL_MD"; then
  echo "  PASS: SKILL.md references scripts/scout.py"; pass=$((pass + 1))
else
  echo "  FAIL: SKILL.md does not reference scripts/scout.py"; fail=$((fail + 1))
fi

# 5. SKILL.md must NOT contain old Agent(subagent_type="quality-gates:scout") dispatch
if grep -q 'subagent_type="quality-gates:scout"' "$SKILL_MD"; then
  echo "  FAIL: SKILL.md still has old Agent(subagent_type=\"quality-gates:scout\") dispatch (T3-1 regression)"
  fail=$((fail + 1))
else
  echo "  PASS: old Agent() scout dispatch absent from SKILL.md"; pass=$((pass + 1))
fi

# Scenario 5 (T2-2 / AC7-AC8) — unified dispatch heading + fan-out gate
# applies to both primary and fallback paths.
test_scenario_5_unified_dispatch() {
  echo "=== Scenario 5: Phase 1 unified dispatch + fan-out gate ==="
  local skill="$SKILL_MD"

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
