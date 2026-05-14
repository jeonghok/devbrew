#!/usr/bin/env bash
# AC2 — static check: scout.md mentions codex_manifest in Inputs,
# codex-reviewer in Phase 1 table, and the selection rule.

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

check "Inputs lists codex_manifest" 'codex_manifest'
check "Phase1 table references codex-reviewer" 'codex-reviewer'
check "Selection rule for codex-reviewer depth gate" 'codex_available.*standard.*deep\|codex_available.*depth'
check "Selection rule mentions skip on quick" 'quick.*[Ss]kip\|[Ss]kip.*quick'

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[[ $fail -eq 0 ]] || exit 1
