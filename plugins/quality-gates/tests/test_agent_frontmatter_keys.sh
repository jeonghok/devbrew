#!/usr/bin/env bash
# AC15: repo-wide agent frontmatter convention guard.
# Cross-PR dependency: PR ① (AC1)이 이미 머지돼야 본 test PASS.
set -u
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

BAD=$(grep -rln -E "^(allowed-tools|disallowed-tools):" plugins/*/agents/*.md 2>/dev/null || true)
if [ -n "$BAD" ]; then
  echo "FAIL: agent frontmatter convention violations (kebab-case found):" >&2
  echo "$BAD" >&2
  echo "Expected: allowedTools / disallowedTools (camelCase)." >&2
  exit 1
fi

echo "PASS: agent frontmatter keys all conform to camelCase convention"
exit 0
