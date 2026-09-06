#!/usr/bin/env bash
# T8/AC4/AC13a-b — artifact-critic: tier-unpinned (frontmatter 에 model 키 없음) + read-only.
set -u
A="plugins/quality-gates/agents/artifact-critic.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

assert_file_grep "$A" '^name: artifact-critic$' "name is artifact-critic"
MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"
assert_file_absent "$A" "$MODEL_KEY" "frontmatter 에 model 키 없음 (tier-unpinned — 사용자 설정 → 세션 모델)"
assert_file_grep "$A" '^color: (cyan|green|yellow|blue|red|purple|orange|pink)$' "color in 8-color enum"
assert_file_grep "$A" '^tools: Read, Grep, Glob[[:space:]]*$' "tools: allowlist (fail-closed, read-only)"
assert_file_absent "$A" '^disallowedTools:' "denylist 제거됨 (allowlist 가 컨트롤)"
assert_file_absent "$A" '^tools:.*(Write|Edit|MultiEdit|NotebookEdit|Bash|Agent|Monitor|mcp__)' "tools: 에 write/exec/delegation/MCP 없음"
assert_file_grep "$A" 'You are \*\*Artifact Critic\*\*' "persona body frames the critic role (body-unique, not header-satisfiable)"
assert_file_grep "$A" 'NOT responsible' "persona has explicit non-responsibility (Law 2 role framing)"
assert_file_grep "$A" 'findings:' "output schema documented"

finish
