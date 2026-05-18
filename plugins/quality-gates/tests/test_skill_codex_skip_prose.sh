#!/usr/bin/env bash
# T2-5 / AC19-AC21: SKILL.md prose must surface the codex skip_reason
# 6-enum with correct visibility policy (4 visible + 2 silent).

set -euo pipefail
SKILL="plugins/quality-gates/skills/quality-pipeline/SKILL.md"
fail=0

# AC19 — 4 visible reasons each appear at least once
visible_patterns=(
  "Codex CLI not installed"
  "auth missing"
  "no .*timeout"
  "version known-bad"
)
for p in "${visible_patterns[@]}"; do
  if grep -Eq "$p" "$SKILL"; then
    echo "PASS visible: $p"
  else
    echo "FAIL AC19 visible message missing: $p"
    fail=1
  fi
done

# AC20 — 2 silent reasons MUST NOT appear as a stderr-emit pattern
# (i.e., they appear in the policy table as structural references, but no
# "[quality-gates] ... <reason>" or "Codex skipped: ... <reason>" actionable message)
silent_reasons=(kill_switch inside_codex_sandbox)
for r in "${silent_reasons[@]}"; do
  if grep -Eq "\[quality-gates\][^\n]*${r}|Codex skipped[^\n]*${r}" "$SKILL"; then
    echo "FAIL AC20 silent reason has visible message: $r"
    fail=1
  else
    echo "PASS silent: $r"
  fi
done

# AC21 — the visibility policy section header exists (compounding anchor)
if grep -q "Codex skip 안내" "$SKILL"; then
  echo "PASS AC21: visibility-policy section header present"
else
  echo "FAIL AC21: visibility-policy section header missing"
  fail=1
fi

[[ "$fail" -eq 0 ]] || exit 1
echo ""
echo "AC19/AC20/AC21: PASS"
