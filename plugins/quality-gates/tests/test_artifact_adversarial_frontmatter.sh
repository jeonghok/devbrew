#!/usr/bin/env bash
# T9/AC4/AC13a-b — artifact-adversarial: tier-unpinned + read-only + verdict schema.
set -u
A="plugins/quality-gates/agents/artifact-adversarial.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

assert_file_grep "$A" '^name: artifact-adversarial$' "name is artifact-adversarial"
MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"
assert_file_absent "$A" "$MODEL_KEY" "frontmatter 에 model 키 없음 (tier-unpinned — 사용자 설정 → 세션 모델)"
assert_file_grep "$A" '^color: (cyan|green|yellow|blue|red|purple|orange|pink)$' "color in 8-color enum"
assert_file_grep "$A" '^tools: Read, Grep, Glob[[:space:]]*$' "tools: allowlist (fail-closed, read-only)"
assert_file_absent "$A" '^disallowedTools:' "denylist 제거됨 (allowlist 가 컨트롤)"
assert_file_absent "$A" '^tools:.*(Write|Edit|MultiEdit|NotebookEdit|Bash|Agent|Monitor|mcp__)' "tools: 에 write/exec/delegation/MCP 없음"
assert_file_grep "$A" 'finding_key' "verdict schema uses finding_key (echoed dedup_key)"
assert_file_grep "$A" 'new_severity' "downgrade carries new_severity"
assert_file_grep "$A" 'new_findings' "adversarial can add missed findings"
# NOTE: pattern is 'load-bearing' only (not 'load-bearing|amplif') — the
# frontmatter `description:` line also contains "amplified into real edits",
# so an 'amplif' alternative is header-satisfiable (passes even if the
# persona body's load-bearing framing is gutted). 'load-bearing' alone does
# not appear in frontmatter — body-unique, has teeth. See task-9-report.md.
assert_file_grep "$A" 'load-bearing' "persona states FP gate is load-bearing (edits amplify)"

finish
