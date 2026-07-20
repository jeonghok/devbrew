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

# Scenario 5 (v2.13.0) — scope-driven 3-tier dispatch replaced the old
# `#### Phase 1 (unified dispatch)` heading structure. Guard the new prose so
# scout stays a HINT provider under the 3-tier model (not the authority).
test_scenario_5_scope_driven() {
  echo "=== Scenario 5: scope-driven 3-tier dispatch (v2.13.0) ==="
  local skill="$SKILL_MD"

  # 5a: old unified-dispatch heading must be GONE.
  if grep -qF '#### Phase 1 (unified dispatch)' "$skill"; then
    echo "  FAIL 5a: stale '#### Phase 1 (unified dispatch)' heading still present"
    fail=$((fail + 1))
  else
    echo "  PASS: 5a: stale unified-dispatch heading absent"
    pass=$((pass + 1))
  fi

  # 5b: Tier A floor anchor present (scope-independent floor).
  if grep -qF 'Tier A — Floor (스코프 무관, 항상 디스패치' "$skill"; then
    echo "  PASS: 5b: Tier A floor anchor present"; pass=$((pass + 1))
  else
    echo "  FAIL 5b: Tier A floor anchor missing"; fail=$((fail + 1))
  fi

  # 5c: scope-driven composition section present (rubric owner).
  if grep -qF '## Reviewer composition (scope-driven)' "$skill"; then
    echo "  PASS: 5c: Reviewer composition section present"; pass=$((pass + 1))
  else
    echo "  FAIL 5c: Reviewer composition section missing"; fail=$((fail + 1))
  fi

  # 5d: scout is referenced as a HINT, not the authority (phase2 hint phrasing).
  if grep -qE 'scout.*힌트|힌트.*scout' "$skill"; then
    echo "  PASS: 5d: scout framed as a hint"; pass=$((pass + 1))
  else
    echo "  FAIL 5d: scout hint framing missing"; fail=$((fail + 1))
  fi

  echo "=== Scenario 5 done ==="
}
test_scenario_5_scope_driven

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[[ $fail -eq 0 ]] || exit 1
