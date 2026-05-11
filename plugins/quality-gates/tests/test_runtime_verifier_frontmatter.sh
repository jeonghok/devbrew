#!/usr/bin/env bash
# Validates runtime-verifier.md frontmatter compliance with CLAUDE.md
# "Plugin Shape" requirements (no default-everything; Write/Edit must be
# disallowed for the reviewer agent).

set -u

FILE="$(cd "$(dirname "$0")/.." && pwd)/agents/runtime-verifier.md"
PASS=0
FAIL=0

assert_grep() {
  local pattern="$1" msg="$2"
  if grep -qE "$pattern" "$FILE"; then
    PASS=$((PASS + 1)); echo "  PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (pattern '$pattern' not in file)"
  fi
}

assert_grep "^cost_class: variable" "cost_class is variable (was low)"
assert_grep "^allowedTools:" "allowedTools declared"
assert_grep "^disallowedTools:" "disallowedTools declared"
assert_grep "^[[:space:]]+- Write([[:space:]]|$)" "Write in disallowedTools"
assert_grep "^[[:space:]]+- Edit([[:space:]]|$)" "Edit in disallowedTools"
assert_grep "^[[:space:]]+- MultiEdit([[:space:]]|$)" "MultiEdit in disallowedTools"
assert_grep "^[[:space:]]+- NotebookEdit([[:space:]]|$)" "NotebookEdit in disallowedTools"
# Verify body declares verdict taxonomy
assert_grep "SKIP_WITH_EVIDENCE" "SKIP_WITH_EVIDENCE verdict documented"
assert_grep "NEEDS_RESOLUTION" "NEEDS_RESOLUTION verdict documented"

echo ""
echo "Tests passed: $PASS, failed: $FAIL"
[[ $FAIL -eq 0 ]] || exit 1
