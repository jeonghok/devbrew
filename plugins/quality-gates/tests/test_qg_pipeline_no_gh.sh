#!/usr/bin/env bash
# test_qg_pipeline_no_gh.sh — AC2: quality-pipeline SKILL.md allowed-tools carries
# NO gh/network tool, and render-terminal.py IS present. Teeth: adding a
# Bash(gh...) allow, or removing the render-terminal allow, turns this RED.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }

# allowed-tools window = from 'allowed-tools:' to the closing frontmatter '---'.
AT="$(awk '/^allowed-tools:/{f=1} f{print} f&&/^---[[:space:]]*$/{exit}' "$SKILL")"

if ! grep -qiE 'gh[[:space:]]|gh\(|gh pr|gh api|Bash\(gh' <<<"$AT"; then
  pass "no gh tool in quality-pipeline allowed-tools (AC2)"
else
  fail "gh tool leaked into quality-pipeline allowed-tools (AC2 violation)"
fi

grep -qF 'render-terminal.py' <<<"$AT" \
  && pass "render-terminal.py wired into allowed-tools" \
  || fail "render-terminal.py missing from allowed-tools"

# Final Summary section actually invokes render-terminal.py table.
if awk '/^## Final Summary/{f=1} f' "$SKILL" | grep -qF 'render-terminal.py table'; then
  pass "Final Summary uses render-terminal.py table"
else
  fail "Final Summary does not call render-terminal.py table"
fi

echo "qg-pipeline-no-gh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
