#!/usr/bin/env bash
# Tests for agents/test-scope-validator.md frontmatter — verifies Plugin Shape
# compliance: allowedTools / disallowedTools / model / cost_class declarations.
# Mirrors style of test_runtime_verifier_frontmatter.sh.

set -u

AGENT="$(cd "$(dirname "$0")/.." && pwd)/agents/test-scope-validator.md"
PASS=0
FAIL=0

note() { echo "  → $1"; }

assert_grep() {
  local pattern="$1" msg="$2"
  if grep -qE "$pattern" "$AGENT"; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (pattern '$pattern' not found)"
  fi
}

assert_not_grep() {
  local pattern="$1" msg="$2"
  if ! grep -qE "$pattern" "$AGENT"; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (unexpected '$pattern')"
  fi
}

assert_body_grep() {
  local pattern="$1" msg="$2"
  if echo "$BODY" | grep -qE "$pattern"; then
    PASS=$((PASS + 1)); note "PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (pattern '$pattern' not found in body)"
  fi
}

if [ ! -f "$AGENT" ]; then
  echo "  ✗ FAIL: agent file missing: $AGENT"
  exit 1
fi

# Extract markdown body (everything after the SECOND '---' line).
BODY=$(awk '/^---$/{c++; next} c>=2' "$AGENT")

# Extract frontmatter block (between first two '---' lines).
FM=$(awk '/^---$/{c++; next} c==1' "$AGENT")

echo "== Frontmatter declarations =="
echo "$FM" | grep -qE '^name:[[:space:]]*test-scope-validator$' \
  && { PASS=$((PASS + 1)); note "PASS: name=test-scope-validator"; } \
  || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: name field"; }
echo "$FM" | grep -qE '^model:[[:space:]]*sonnet$' \
  && { PASS=$((PASS + 1)); note "PASS: model=sonnet"; } \
  || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: model field"; }
echo "$FM" | grep -qE '^cost_class:[[:space:]]*low$' \
  && { PASS=$((PASS + 1)); note "PASS: cost_class=low"; } \
  || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: cost_class field"; }

# Extract sublist for a top-level YAML key in the frontmatter.
# Emits all `  - <value>` lines until the next non-indented, non-list line.
extract_sublist() {
  local key="$1"
  echo "$FM" | awk -v key="$key" '
    $0 ~ "^"key":[[:space:]]*$" { in_list=1; next }
    in_list && /^[[:space:]]*-[[:space:]]/ { print; next }
    in_list { in_list=0 }
  '
}

ALLOWED_LIST=$(extract_sublist allowedTools)
DISALLOWED_LIST=$(extract_sublist disallowedTools)

echo "== allowedTools (positive list, scoped to allowedTools: sublist) =="
for t in Read Grep Glob Bash; do
  echo "$ALLOWED_LIST" | grep -qE "^[[:space:]]*-[[:space:]]*${t}$" \
    && { PASS=$((PASS + 1)); note "PASS: allowedTools includes $t"; } \
    || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: allowedTools missing $t"; }
done

echo "== disallowedTools (Law 2 enforcement, scoped to disallowedTools: sublist) =="
for t in Write Edit MultiEdit NotebookEdit; do
  echo "$DISALLOWED_LIST" | grep -qE "^[[:space:]]*-[[:space:]]*${t}$" \
    && { PASS=$((PASS + 1)); note "PASS: disallowedTools includes $t"; } \
    || { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: disallowedTools missing $t"; }
done

echo "== body claims (scoped to markdown body) =="
assert_body_grep 'aligned' "body mentions aligned classification"
assert_body_grep 'outdated-suspicion' "body mentions outdated-suspicion"
assert_body_grep 'cherry-pick-suspicion' "body mentions cherry-pick-suspicion"
assert_body_grep 'unclear' "body mentions unclear"
assert_body_grep 'test_scope_verdicts' "body mentions output key"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
