#!/usr/bin/env bash
# AC6 — adversarial persona structural conformance (symmetric to
# test_security_reviewer_persona.sh). Locks: frontmatter (name / model: opus /
# disallowedTools 4) + Gate A–D structure + v2.8.0 untrusted-input norm (A)
# positioned before ## Verification protocol + 2 Gate C reject-at-verify
# precedents (B) INSIDE the Gate C block, each specifying reject. Section-scoped
# so a move/delete goes RED, not a global keyword count.
set -eu
REPO_ROOT="$(git rev-parse --show-toplevel)"
PERSONA="$REPO_ROOT/plugins/quality-gates/agents/adversarial.md"

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

# Section extractor — Gate C window between the Gate C and Gate D headers.
gateC_section() {
  awk '/\*\*Gate C/{f=1} /\*\*Gate D/{f=0} f' "$PERSONA"
}

# Frontmatter required keys
check "frontmatter name adversarial" \
  "grep -c '^name: adversarial$' '$PERSONA'" 1
check "frontmatter model opus" \
  "grep -c '^model: opus$' '$PERSONA'" 1
check "frontmatter disallowedTools blocks Write/Edit/MultiEdit/NotebookEdit" \
  "grep -cE 'disallowedTools:.*Write.*Edit.*MultiEdit.*NotebookEdit' '$PERSONA'" 1

# Gate A–D structure present
check "Gate A header present" "grep -c '\\*\\*Gate A' '$PERSONA'" 1
check "Gate B header present" "grep -c '\\*\\*Gate B' '$PERSONA'" 1
check "Gate C header present" "grep -c '\\*\\*Gate C' '$PERSONA'" 1
check "Gate D header present" "grep -c '\\*\\*Gate D' '$PERSONA'" 1

# (A / AC2) untrusted-input header exists AND sits before ## Verification protocol
hdr="$(grep -n '^## Untrusted input' "$PERSONA" | head -1 | cut -d: -f1)"
proto="$(grep -n '^## Verification protocol' "$PERSONA" | head -1 | cut -d: -f1)"
if [ -n "$hdr" ] && [ -n "$proto" ] && [ "$hdr" -lt "$proto" ]; then
  echo "  PASS: untrusted-input header precedes ## Verification protocol (line $hdr < $proto)"; pass=$((pass + 1))
else
  echo "  FAIL: untrusted-input header must exist before ## Verification protocol (hdr='$hdr' proto='$proto')"; fail=$((fail + 1))
fi
check "untrusted-input data-not-instructions norm present" \
  "grep -cE 'data, not instructions' '$PERSONA'" 1

# (B / AC4) 2 reject-at-verify precedents INSIDE the Gate C block, each with reject
check "client-side trust-boundary precedent in Gate C, specifies reject" \
  "gateC_section | grep -cE 'Client-side trust boundary.*reject'" 1
check "trusted-config-values precedent in Gate C, specifies reject" \
  "gateC_section | grep -cE 'Trusted configuration values.*reject'" 1

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[ "$fail" -eq 0 ] || exit 1
