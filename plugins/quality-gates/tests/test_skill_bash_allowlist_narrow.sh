#!/usr/bin/env bash
# T3-3 / AC44: SKILL.md frontmatter Bash allowlist is narrow (specific
# script entries only, no wildcard `Bash(*)`).
set -euo pipefail
SKILL="plugins/quality-gates/skills/quality-pipeline/SKILL.md"

# Smell check: Bash(*) wildcard absent
if grep -E '^\s*-\s*Bash\(\*\)\s*$|allowed-tools:.*Bash\(\*\)' "$SKILL"; then
  echo "FAIL AC44: Bash(*) wildcard found in SKILL.md frontmatter"
  exit 1
fi

# Positive: run_codex_reviewer.sh entry exists (T3-3)
if ! grep -q 'run_codex_reviewer.sh' "$SKILL"; then
  echo "FAIL AC44: SKILL.md missing run_codex_reviewer.sh reference"
  exit 1
fi

echo "PASS AC44: Bash allowlist narrow"
