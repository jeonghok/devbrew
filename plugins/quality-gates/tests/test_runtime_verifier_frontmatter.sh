#!/usr/bin/env bash
# Validates runtime-verifier.md frontmatter + body for the v2.2.0 sandbox-
# executor contract. The agent is now an executor: model inherit, Write/Edit
# in allowedTools, browser-interaction tools, NotebookEdit still denied, and
# the body declares the sandbox / no-commit / product-fix-forbidden contract.

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
assert_nogrep() {
  local pattern="$1" msg="$2"
  if grep -qE "$pattern" "$FILE"; then
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (pattern '$pattern' unexpectedly present)"
  else
    PASS=$((PASS + 1)); echo "  PASS: $msg"
  fi
}

# --- frontmatter ---
assert_grep "^model: inherit" "model is inherit (was sonnet)"
assert_grep "^cost_class: variable" "cost_class stays variable"
assert_grep "^allowedTools:" "allowedTools declared"
assert_grep "^disallowedTools:" "disallowedTools declared (not default-everything)"

# Write/Edit/MultiEdit now ALLOWED (sandbox executor)
assert_grep "^[[:space:]]+- Write([[:space:]]|$)" "Write present"
assert_grep "^[[:space:]]+- Edit([[:space:]]|$)" "Edit present"
assert_grep "^[[:space:]]+- MultiEdit([[:space:]]|$)" "MultiEdit present"

# NotebookEdit still DENIED (deny list non-empty, not default-everything)
assert_grep "^[[:space:]]+- NotebookEdit([[:space:]]|$)" "NotebookEdit still in disallowedTools"

# Write/Edit/MultiEdit must NOT appear in the disallowedTools section.
DISALLOWED_BLOCK=$(awk '
  /^disallowedTools:/ {indis=1; next}
  /^[a-zA-Z]/ {indis=0}
  indis {print}
' "$FILE")
if printf '%s' "$DISALLOWED_BLOCK" | grep -qE -- '- (Write|Edit|MultiEdit)\b'; then
  FAIL=$((FAIL + 1)); echo "  ✗ FAIL: Write/Edit/MultiEdit must NOT be in disallowedTools"
else
  PASS=$((PASS + 1)); echo "  PASS: Write/Edit/MultiEdit absent from disallowedTools"
fi

# Browser interaction tools present (subset; at least click + fill + type_text)
assert_grep "chrome-devtools__click" "chrome-devtools click tool"
assert_grep "chrome-devtools__fill" "chrome-devtools fill tool"
assert_grep "chrome-devtools__type_text" "chrome-devtools type_text tool"

# --- body contract ---
assert_grep "sandbox" "body references the sandbox"
assert_grep "functional_assertions" "evidence-log functional_assertions section"
assert_grep "ac_id" "functional assertions bind to ac_id"
assert_grep "mutation_guard" "body references orchestrator mutation_guard"
assert_grep "product" "body addresses product-source rule"
assert_grep "SKIP_WITH_EVIDENCE" "SKIP_WITH_EVIDENCE verdict documented"
assert_grep "NEEDS_RESOLUTION" "NEEDS_RESOLUTION verdict documented"

echo ""
echo "Tests passed: $PASS, failed: $FAIL"
[[ $FAIL -eq 0 ]] || exit 1
