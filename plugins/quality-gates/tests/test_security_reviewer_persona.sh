#!/usr/bin/env bash
# AC2 / AC10a — security-reviewer persona structural conformance.
# Verifies the persona file declares the canonical finding YAML schema
# from adversarial.md:22-30 and the forced-findings prohibition rule.
set -u
REPO_ROOT="$(git rev-parse --show-toplevel)"
PERSONA="$REPO_ROOT/plugins/quality-gates/agents/security-reviewer.md"

pass=0; fail=0
check() {
  local name="$1" cmd="$2" expected="$3"
  local actual
  actual="$(eval "$cmd" 2>/dev/null || echo "0")"
  if [ "$actual" -ge "$expected" ]; then
    echo "  PASS: $name (got $actual, expected >= $expected)"; pass=$((pass + 1))
  else
    echo "  FAIL: $name (got $actual, expected >= $expected)"; fail=$((fail + 1))
  fi
}

# Existence
if [ ! -f "$PERSONA" ]; then
  echo "  FAIL: persona file missing at $PERSONA"; exit 1
fi

# Frontmatter required keys
check "frontmatter name" \
  "grep -c '^name: security-reviewer$' '$PERSONA'" 1
check "frontmatter cost_class medium" \
  "grep -c '^cost_class: medium$' '$PERSONA'" 1
check "frontmatter model inherit" \
  "grep -c '^model: inherit$' '$PERSONA'" 1
check "frontmatter disallowedTools camelCase" \
  "grep -c '^disallowedTools:' '$PERSONA'" 1
check "disallowedTools blocks Write/Edit/MultiEdit/NotebookEdit" \
  "grep -cE '\\- Write$|\\- Edit$|\\- MultiEdit$|\\- NotebookEdit$' '$PERSONA'" 4

# Canonical schema keys present in persona body
check "schema key agent: security-reviewer" \
  "grep -c 'agent: security-reviewer' '$PERSONA'" 1
check "schema key severity:" \
  "grep -c '^[[:space:]]*severity:' '$PERSONA'" 1
check "schema key confidence:" \
  "grep -c '^[[:space:]]*confidence:' '$PERSONA'" 1
check "schema key file:" \
  "grep -c '^[[:space:]]*file:' '$PERSONA'" 1
check "schema key line:" \
  "grep -c '^[[:space:]]*line:' '$PERSONA'" 1
check "severity enum CRITICAL/IMPORTANT/SUGGESTION" \
  "grep -cE 'CRITICAL.*IMPORTANT.*SUGGESTION' '$PERSONA'" 1

# Forced findings prohibition (Korean or English)
check "forced findings prohibition present" \
  "grep -cE 'forced findings|Forced findings|빈 array|empty findings|empty list' '$PERSONA'" 1

# Role declaration shape (You are X / responsible / NOT responsible)
check "role declaration shape" \
  "grep -cE 'You are .*security-reviewer|responsible for|NOT responsible' '$PERSONA'" 3

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[ "$fail" -eq 0 ] || exit 1
