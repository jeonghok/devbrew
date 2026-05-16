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

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[[ $fail -eq 0 ]] || exit 1
