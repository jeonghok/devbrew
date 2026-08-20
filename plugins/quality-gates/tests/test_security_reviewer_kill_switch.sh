#!/usr/bin/env bash
# AC5 / AC11 — kill switch presence + disable log message structural test.
# This is a structural test (grep on SKILL.md): SKILL.md is consumed by an
# LLM, not executable, so we verify the kill switch is documented in the
# dispatch sequence. Behavioral assertion of LLM compliance requires
# integration smoke (AC10b, opt-in).
set -eu
REPO_ROOT="$(git rev-parse --show-toplevel)"
SKILL="$REPO_ROOT/plugins/quality-gates/skills/quality-pipeline/SKILL.md"

if [ ! -f "$SKILL" ]; then
  echo "  FAIL: SKILL.md missing at $SKILL" >&2; exit 1
fi

set +e
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

assert_count_ge "grep -c 'DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER' '$SKILL'" 1 \
  "kill switch env var present"

assert_count_ge "grep -cE 'security-reviewer disabled|security-reviewer.*DEVBREW_QUALITY_GATES_DISABLE' '$SKILL'" 1 \
  "disable log message present"

assert_count_ge "grep -c 'security-reviewer' '$SKILL'" 3 \
  "security-reviewer dispatch reference count"

finish
