#!/usr/bin/env bash
# T8/AC4/AC13a-b — artifact-critic: inherit-tier (model: inherit, not cheap) + read-only.
set -u
A="plugins/quality-gates/agents/artifact-critic.md"
PASS=0; FAIL=0
ag() { grep -qE "$1" "$A" && { PASS=$((PASS+1)); echo "  PASS: $2"; } || { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $2"; }; }
ng() { if [ ! -f "$A" ]; then FAIL=$((FAIL+1)); echo "  ✗ FAIL: $2 (file missing)"; return; fi
       grep -qE "$1" "$A" && { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $2 (unexpected '$1')"; } || { PASS=$((PASS+1)); echo "  PASS: $2"; }; }

ag '^name: artifact-critic$' "name is artifact-critic"
ag '^model: inherit$' "model is inherit (session-tier, no downgrade)"
ng '^model: (opus|sonnet|haiku)' "model is NOT a pinned cheap/fixed tier"
ag '^color: (cyan|green|yellow|blue|red|purple|orange|pink)$' "color in 8-color enum"
ag '^tools: Read, Grep, Glob[[:space:]]*$' "tools: allowlist (fail-closed, read-only)"
ng '^disallowedTools:' "denylist 제거됨 (allowlist 가 컨트롤)"
ng '^tools:.*(Write|Edit|MultiEdit|NotebookEdit|Bash|Agent|Monitor|mcp__)' "tools: 에 write/exec/delegation/MCP 없음"
ag 'You are \*\*Artifact Critic\*\*' "persona body frames the critic role (body-unique, not header-satisfiable)"
ag 'NOT responsible' "persona has explicit non-responsibility (Law 2 role framing)"
ag 'findings:' "output schema documented"

echo ""; echo "Total: $((PASS+FAIL)), PASS=$PASS, FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
