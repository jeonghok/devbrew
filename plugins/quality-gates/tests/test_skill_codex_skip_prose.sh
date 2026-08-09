#!/usr/bin/env bash
# T2-5 / AC19-AC21: SKILL.md prose must surface the codex skip_reason
# 6-enum with correct visibility policy (4 visible + 2 silent).

set -euo pipefail
SKILL="plugins/quality-gates/skills/quality-pipeline/SKILL.md"
fail=0

# AC19 — visible 사유는 각각 최소 1회 등장한다.
# 4종 → 6종: §4.2가 detect에 추가한 version_below_floor · version_unreadable은
# 사용자가 조치할 수 있는 사유이므로(설치 버전을 올리면 된다) visible이다 —
# `version known-bad`와 같은 부류다. silent 2종(kill_switch · inside_codex_sandbox)은
# 사용자 조치 대상이 아니라 아래 AC20이 별도로 다룬다.
visible_patterns=(
  "Codex CLI not installed"
  "auth missing"
  "no .*timeout"
  "version known-bad"
  "version_below_floor"
  "version_unreadable"
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
