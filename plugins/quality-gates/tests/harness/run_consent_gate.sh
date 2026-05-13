#!/usr/bin/env bash
# Minimal harness simulating the SKILL.md consent gate in isolation.

set -u
MARKER="${HOME}/.claude/quality-gates/codex-cost-consent.md"

if [[ -f "$MARKER" ]]; then
  exit 0
fi

if [[ -n "${QG_MOCK_ASKUSER_PATH:-}" ]]; then
  cat > "$QG_MOCK_ASKUSER_PATH" <<'EOF'
question: Codex CLI detected. Enable codex-reviewer for this project?
options:
  - Approve once
  - Approve always (recommended)
  - Decline
EOF
  mkdir -p "${HOME}/.claude/quality-gates"
  printf 'consented: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$MARKER"
  exit 0
fi

echo "Real AskUserQuestion not invoked in harness" >&2
exit 0
