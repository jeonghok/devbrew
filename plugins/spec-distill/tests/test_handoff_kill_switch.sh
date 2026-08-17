#!/usr/bin/env bash
# AC6 — DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK=1 must bypass handoff_incomplete only.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/spec-reviewer.md"
README="$REPO_ROOT/plugins/spec-distill/README.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# AC6a: kill switch env var 이름 in agent
grep -q 'DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK' "$AGENT" \
  && ok "AC6: kill switch env var referenced in agent" \
  || no "AC6 kill switch env var missing from agent"

# AC6b: README Kill switches 표에 행 추가
grep -q 'DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK' "$README" \
  && ok "AC6: kill switch documented in README" \
  || no "AC6 kill switch not in README"

# AC6c: loud warning 텍스트 명시
grep -qE 'handoff readiness 검증 비활성화|handoff.*disabled' "$AGENT" \
  && ok "AC6: loud warning text present" \
  || no "AC6 loud warning text missing"
finish
