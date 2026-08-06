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

# 2. SKILL dispatch must rely on frontmatter (no model= override pinned anywhere
#    near the adversarial reference). v1.32.0 SKILL groups Gate 2 reviewers as
#    a bullet list of subagent_type identifiers (`- quality-gates:adversarial`)
#    rather than per-reviewer Agent() dispatch blocks, so the drift guard
#    asserts on the line + a windowed model= scan around it.
adv_line_no="$(grep -nE '^[[:space:]]*-?[[:space:]]*[`\"]?quality-gates:adversarial[`\"]?' "$SKILL" 2>/dev/null | head -1 | cut -d: -f1)"
if [ -z "$adv_line_no" ]; then
  # Missing reference = dispatch removed/renamed = the check cannot verify its
  # invariant. Treat as FAIL, not PASS — a vacuous pass here would defeat the
  # guard's purpose (Gate 2 adversarial caught this false-PASS blind spot).
  FAIL=$((FAIL + 1)); echo "  ✗ FAIL: SKILL has no adversarial reviewer reference (pattern not found in ${SKILL##*/})"
else
  win_start=$((adv_line_no > 5 ? adv_line_no - 5 : 1))
  win_end=$((adv_line_no + 5))
  adv_window="$(sed -n "${win_start},${win_end}p" "$SKILL" 2>/dev/null || true)"
  if printf '%s' "$adv_window" | grep -qE 'model[[:space:]]*=[[:space:]]*["'\'']?(opus|sonnet|haiku)'; then
    FAIL=$((FAIL + 1)); echo "  ✗ FAIL: SKILL adversarial reference has a model override nearby (must rely on frontmatter)"
  else
    PASS=$((PASS + 1)); echo "  PASS: SKILL adversarial reference has no nearby model override (relies on frontmatter)"
  fi
fi

# 3. README must describe adversarial as opus, consistently in both the model
#    note and the Gate 2 phase diagram.
assert_grep "$README" 'quality-gates:adversarial[[:space:]]+\(Phase 1\.5, opus\)' "README phase diagram tags Adversarial as opus"
assert_grep "$README" '`adversarial` agent uses `model: opus`' "README model note states opus"
assert_not_grep "$README" '`adversarial` agent uses `model: sonnet`' "README model note does not state sonnet"

echo ""
echo "Tests passed: $PASS, failed: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
