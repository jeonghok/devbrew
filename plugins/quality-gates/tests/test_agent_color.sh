#!/usr/bin/env bash
# T2-9 / AC53-AC55: every extant agent file has color frontmatter from
# the Claude Code 8-color enum. Dynamic — survives T3-1/2/3 refactor
# that removes scout/synthesizer/codex-reviewer.md.

set -euo pipefail
ALLOWED='cyan|green|yellow|blue|red|purple|orange|pink'
fail=0

for f in plugins/quality-gates/agents/*.md; do
  if ! grep -q '^color:' "$f"; then
    echo "FAIL AC53: $f missing color frontmatter"
    fail=1
    continue
  fi
  val=$(grep '^color:' "$f" | awk '{print $2}')
  if ! echo "$val" | grep -qE "^($ALLOWED)$"; then
    echo "FAIL AC55: $f color='$val' not in 8-color enum"
    fail=1
  fi
done

[[ "$fail" -eq 0 ]] || exit 1
echo "PASS AC53/AC55: all extant agents have color in Claude Code 8-color enum"
