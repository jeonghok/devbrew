#!/usr/bin/env bash
# Drift guard — adversarial reviewer model must be consistently `opus` across
# all three declaration sites. adversarial is the Opus-critic over Sonnet
# Phase 1 workers (cf. Anthropic multi-agent patterns): it is the single
# model-based judgment bottleneck in Gate 2 (synthesizer is a deterministic
# script). Distinguishing "reviewer verified vs. pattern-matched" against the
# diff is reasoning-heavy, so capability is spent at this consolidation point.
#
# This is a deliberate quality choice, NOT a cost leak. A prior cost pass
# (T2-8) drifted frontmatter/README toward sonnet while the SKILL dispatch
# still pinned opus, leaving the three sites contradicting each other. This
# test locks them consistent so any future single-site edit fails CI.
#
# Single source of truth: agents/adversarial.md frontmatter (`model: opus`).
# The SKILL dispatch must NOT pin a model override — it relies on frontmatter,
# matching the convention of the other frontmatter-pinned qg agents
# (plan-verifier, runtime-verifier, test-scope-validator).

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AGENT="$ROOT/agents/adversarial.md"
SKILL="$ROOT/skills/quality-pipeline/SKILL.md"
README="$ROOT/README.md"

PASS=0
FAIL=0

assert_grep() {
  local file="$1" pattern="$2" msg="$3"
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    PASS=$((PASS + 1)); echo "  PASS: $msg"
  else
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (pattern '$pattern' not in ${file##*/})"
  fi
}

assert_not_grep() {
  local file="$1" pattern="$2" msg="$3"
  # A missing file must FAIL, not vacuously PASS (Gate 2 adversarial confirmed this gap):
  # grep on a nonexistent file exits non-zero, which would otherwise route to the PASS branch.
  if [ ! -f "$file" ]; then
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (file not found: ${file##*/})"
    return
  fi
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $msg (unexpected '$pattern' in ${file##*/})"
  else
    PASS=$((PASS + 1)); echo "  PASS: $msg"
  fi
}

# 1. Frontmatter is the single source of truth — must be opus.
assert_grep "$AGENT" '^model: opus$' "adversarial.md frontmatter is model: opus"
assert_not_grep "$AGENT" '^model: sonnet$' "adversarial.md frontmatter is not sonnet"

# 2. SKILL dispatch must rely on frontmatter (no model= override in the block).
adv_block="$(grep -A3 'subagent_type="quality-gates:adversarial"' "$SKILL" 2>/dev/null || true)"
if [ -z "$adv_block" ]; then
  # Empty block = dispatch removed/renamed = the check cannot verify its invariant.
  # Treat as FAIL, not PASS — a vacuous pass here would defeat the guard's purpose
  # (Gate 2 adversarial caught this false-PASS blind spot).
  FAIL=$((FAIL + 1)); echo "  ✗ FAIL: SKILL has no adversarial dispatch block (pattern not found in ${SKILL##*/})"
elif printf '%s' "$adv_block" | grep -q 'model='; then
  FAIL=$((FAIL + 1)); echo "  ✗ FAIL: SKILL adversarial dispatch pins a model override (must rely on frontmatter)"
else
  PASS=$((PASS + 1)); echo "  PASS: SKILL adversarial dispatch has no model override (relies on frontmatter)"
fi

# 3. README must describe adversarial as opus, consistently in both the model
#    note and the Gate 2 phase diagram.
assert_grep "$README" 'Adversarial \(Standard/Deep, opus\)' "README phase diagram tags Adversarial as opus"
assert_grep "$README" '`adversarial` agent uses `model: opus`' "README model note states opus"
assert_not_grep "$README" '`adversarial` agent uses `model: sonnet`' "README model note does not state sonnet"

echo ""
echo "Tests passed: $PASS, failed: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
