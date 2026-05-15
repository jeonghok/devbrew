#!/usr/bin/env bash
# AC5 / AC11 — kill switch presence + disable log message structural test.
# This is a structural test (grep on SKILL.md): SKILL.md is consumed by an
# LLM, not executable, so we verify the kill switch is documented in the
# dispatch sequence. Behavioral assertion of LLM compliance requires
# integration smoke (AC10b, opt-in).
set -u
REPO_ROOT="$(git rev-parse --show-toplevel)"
SKILL="$REPO_ROOT/plugins/quality-gates/skills/quality-pipeline/SKILL.md"

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

check "kill switch env var present" \
  "grep -c 'DEVBREW_DISABLE_QG_SECURITY_REVIEWER' '$SKILL'" 1

check "disable log message present" \
  "grep -cE 'security-reviewer disabled|security-reviewer.*DEVBREW_DISABLE' '$SKILL'" 1

check "security-reviewer dispatch reference count" \
  "grep -c 'security-reviewer' '$SKILL'" 3

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[ "$fail" -eq 0 ] || exit 1
