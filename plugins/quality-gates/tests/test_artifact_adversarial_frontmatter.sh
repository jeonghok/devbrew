#!/usr/bin/env bash
# T9/AC4/AC13a-b — artifact-adversarial: inherit-tier + read-only + verdict schema.
set -u
A="plugins/quality-gates/agents/artifact-adversarial.md"
PASS=0; FAIL=0
ag() { grep -qE "$1" "$A" && { PASS=$((PASS+1)); echo "  PASS: $2"; } || { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $2"; }; }
ng() { if [ ! -f "$A" ]; then FAIL=$((FAIL+1)); echo "  ✗ FAIL: $2 (file missing)"; return; fi
       grep -qE "$1" "$A" && { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $2 (unexpected '$1')"; } || { PASS=$((PASS+1)); echo "  PASS: $2"; }; }

ag '^name: artifact-adversarial$' "name is artifact-adversarial"
ag '^model: inherit$' "model is inherit"
ng '^model: (opus|sonnet|haiku)' "model is NOT a pinned tier"
ag '^color: (cyan|green|yellow|blue|red|purple|orange|pink)$' "color in 8-color enum"
ag '^tools: Read, Grep, Glob[[:space:]]*$' "tools: allowlist (fail-closed, read-only)"
ng '^disallowedTools:' "denylist 제거됨 (allowlist 가 컨트롤)"
ng '^tools:.*(Write|Edit|MultiEdit|NotebookEdit|Bash|Agent|Monitor|mcp__)' "tools: 에 write/exec/delegation/MCP 없음"
ag 'finding_key' "verdict schema uses finding_key (echoed dedup_key)"
ag 'new_severity' "downgrade carries new_severity"
ag 'new_findings' "adversarial can add missed findings"
# NOTE: pattern is 'load-bearing' only (not 'load-bearing|amplif') — the
# frontmatter `description:` line also contains "amplified into real edits",
# so an 'amplif' alternative is header-satisfiable (passes even if the
# persona body's load-bearing framing is gutted). 'load-bearing' alone does
# not appear in frontmatter — body-unique, has teeth. See task-9-report.md.
ag 'load-bearing' "persona states FP gate is load-bearing (edits amplify)"

echo ""; echo "Total: $((PASS+FAIL)), PASS=$PASS, FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
