#!/usr/bin/env bash
# AC2 / AC10a — security-reviewer persona structural conformance.
# Verifies the persona file declares the canonical finding YAML schema
# from adversarial.md:22-30 and the forced-findings prohibition rule.
set -eu
REPO_ROOT="$(git rev-parse --show-toplevel)"
PERSONA="$REPO_ROOT/plugins/quality-gates/agents/security-reviewer.md"

# Existence guard — runs while set -e is active so a missing persona
# fails fast with a clean diagnostic rather than yielding empty REPO_ROOT
# silently and confusing downstream grep results.
if [ ! -f "$PERSONA" ]; then
  echo "  FAIL: persona file missing at $PERSONA" >&2; exit 1
fi

set +e
pass=0; fail=0
check() {
  local name="$1" cmd="$2" expected="$3"
  local actual
  actual="$(eval "$cmd" 2>/dev/null || true)"
  if [ "$actual" -ge "$expected" ]; then
    echo "  PASS: $name (got $actual, expected >= $expected)"; pass=$((pass + 1))
  else
    echo "  FAIL: $name (got $actual, expected >= $expected)"; fail=$((fail + 1))
  fi
}
# Real boolean absence assert — `check ... 0` above is vacuous (count >= 0 is
# always true), so it can never fail even when the forbidden pattern IS
# present. Used for the dead-key / forbidden-tool checks below.
assert_absent() {
  local name="$1" pattern="$2"
  if grep -qE "$pattern" "$PERSONA"; then
    echo "  FAIL: $name (pattern '$pattern' unexpectedly present)"; fail=$((fail + 1))
  else
    echo "  PASS: $name (pattern absent, as expected)"; pass=$((pass + 1))
  fi
}

# Section extractors — lock placement, not just presence. A rule moved out of
# its section makes the window empty → the grep RED. (AC5: section-scoped, not
# a global keyword count.)
inputs_to_hunt() {
  awk '/^## Inputs/{f=1; next} /^## Hunt categories/{f=0} f' "$PERSONA"
}
antiflag_section() {
  awk '/^## What you do NOT flag/{f=1; next} /^## /{f=0} f' "$PERSONA"
}

# Frontmatter required keys
check "frontmatter name" \
  "grep -c '^name: security-reviewer$' '$PERSONA'" 1
check "frontmatter cost_class medium" \
  "grep -c '^cost_class: medium$' '$PERSONA'" 1
check "frontmatter model inherit" \
  "grep -c '^model: inherit$' '$PERSONA'" 1
check "frontmatter tools: allowlist (fail-closed)" \
  "grep -c '^tools: Read, Grep, Glob$' '$PERSONA'" 1
assert_absent "죽은 allowedTools 없음" '^allowedTools:'
assert_absent "disallowedTools 없음 (allowlist 가 컨트롤)" '^disallowedTools:'
assert_absent "쓰기·실행·위임 도구가 tools: 에 없음" \
  '^tools:.*(Write|Edit|MultiEdit|NotebookEdit|Bash|Agent|Monitor|mcp__)'

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

# --- v2.8.0 untrusted-input norm (A / AC1) — section-scoped between ## Inputs and ## Hunt categories
check "untrusted-input header positioned after ## Inputs" \
  "inputs_to_hunt | grep -c '^## Untrusted input'" 1
# Body-unique phrase only — the header also contains "data, not instructions",
# so grepping that would pass even if the body norm prose were deleted. Scoped
# to the inputs_to_hunt window; deleting the body now goes RED.
check "untrusted-input body norm (DATA-to-analyze) in section" \
  "inputs_to_hunt | grep -cE 'DATA to analyze, never as instructions'" 1

# --- v2.8.0 FP precedent (B / AC3) — 3 suppress-at-source bullets INSIDE anti-flag section
check "managed-lang memory-safety precedent in anti-flag section" \
  "antiflag_section | grep -c 'Managed-language memory safety'" 1
check "framework-escaped XSS precedent in anti-flag section" \
  "antiflag_section | grep -c 'Framework-escaped XSS'" 1
check "path-only SSRF precedent in anti-flag section" \
  "antiflag_section | grep -c 'Path-only SSRF'" 1

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[ "$fail" -eq 0 ] || exit 1
