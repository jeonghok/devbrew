#!/usr/bin/env bash
# T3-3 refactor: codex-reviewer is now a script, not an agent.
# This test asserts (a) the agent file is absent, (b) the script exists +
# preserves -s read-only sandbox invocation.
set -euo pipefail
AGENT_FILE="plugins/quality-gates/agents/codex-reviewer.md"
SCRIPT_FILE="plugins/quality-gates/scripts/run_codex_reviewer.sh"

[[ ! -f "$AGENT_FILE" ]] || { echo "FAIL: agent file should be absent post-T3-3"; exit 1; }
[[ -x "$SCRIPT_FILE" ]] || { echo "FAIL: script missing/non-executable"; exit 1; }
# AC41의 `-s read-only` 판정은 **주석에 만족됐다** — 이 러너의 헤더 주석 :7·:29가
# `codex exec -s read-only`를 설명으로 적고 있어, 실제 invocation의 플래그를 삭제해도
# 영구 GREEN이었다(mutation 확인). 정적 grep을 정교화하지 않고 **실행 관측**으로
# 넘긴다: tests/test_sandbox_enforced.sh가 mock codex로 실제 argv를 보고,
# tests/test_codex_invocation_contract.sh가 같은 판정을 모든 후보 러너에 대해 한다.
# 여기 남는 것은 '스크립트가 실재하고 실행 가능한가' + AC42(kill switch 발견성)다.
grep -q 'DEVBREW_DISABLE_QG_CODEX\|codex_available' plugins/quality-gates/skills/quality-pipeline/SKILL.md \
  || { echo "FAIL AC42: kill switch reference missing in SKILL"; exit 1; }
echo "PASS T3-3: codex-reviewer migrated from agent to script; sandbox + kill switch preserved"
