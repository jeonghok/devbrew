#!/usr/bin/env bash
# test_render_terminal.sh — coverage for scripts/render-terminal.py (design §9, AC13).
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/render-terminal.py"
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }

case_table_aligned() {
  local out
  out=$(printf 'target\tPR #123\nidentity\toctocat (id 583231)\n' \
        | python3 "$SCRIPT" table --title "PR Understanding")
  # every value column must start at the same offset (aligned, not prose)
  local c1 c2
  c1=$(printf '%s\n' "$out" | grep -n 'PR #123' | head -1 | sed 's/.*://' | awk '{print index($0,"PR")}')
  c2=$(printf '%s\n' "$out" | grep -n 'octocat' | head -1 | sed 's/.*://' | awk '{print index($0,"octocat")}')
  if [[ -n "$c1" && "$c1" == "$c2" ]]; then pass "STATUS columns aligned (offset $c1)"; else fail "table not aligned ($c1 vs $c2)"; fi
}

case_diagram_parity() {
  local facts out
  facts=$'nodes:\nsrc/api.py\nsrc/db.py\nedges:\nsrc/api.py -> src/db.py\ndegraded: no'
  out=$(printf '%s' "$facts" | python3 "$SCRIPT" diagram)
  if printf '%s' "$out" | grep -qF "src/api.py" \
     && printf '%s' "$out" | grep -qF "src/db.py" \
     && printf '%s' "$out" | grep -qF "src/api.py -> src/db.py"; then
    pass "ASCII diagram carries every node + edge from facts"
  else
    fail "diagram parity (got: $out)"
  fi
}

case_table_aligned
case_diagram_parity
echo "render-terminal: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
