#!/usr/bin/env bash
# T3-3 refactor: codex-reviewer is now a script, not an agent.
# This test asserts (a) the agent file is absent, (b) the script exists +
# preserves -s read-only sandbox invocation.
set -euo pipefail
AGENT_FILE="plugins/quality-gates/agents/codex-reviewer.md"
SCRIPT_FILE="plugins/quality-gates/scripts/run_codex_reviewer.sh"

[[ ! -f "$AGENT_FILE" ]] || { echo "FAIL: agent file should be absent post-T3-3"; exit 1; }
[[ -x "$SCRIPT_FILE" ]] || { echo "FAIL: script missing/non-executable"; exit 1; }
grep -q 'codex exec.*-s read-only' "$SCRIPT_FILE" || { echo "FAIL AC41: -s read-only sandbox missing"; exit 1; }
grep -q 'DEVBREW_DISABLE_QG_CODEX\|codex_available' plugins/quality-gates/skills/quality-pipeline/SKILL.md \
  || { echo "FAIL AC42: kill switch reference missing in SKILL"; exit 1; }
echo "PASS T3-3: codex-reviewer migrated from agent to script; sandbox + kill switch preserved"
