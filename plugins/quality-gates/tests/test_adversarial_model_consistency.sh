#!/usr/bin/env bash
# Drift guard — adversarial 리뷰어의 모델 선언이 세 곳에서 일관되게 `inherit`인지
# 확인한다. adversarial은 Gate 2의 단일 model-based 판정 병목이다(synthesizer는
# 결정론 스크립트). 그래서 **세션이 쓰는 것과 같은 티어**로 돌아야 한다 — 하니스가
# 여기서 티어를 리터럴로 박으면, 세션이 더 강한 모델을 쓰고 있을 때 판정 병목만
# 조용히 약해진다. 반대로 세션보다 강한 티어를 박으면 비용이 사용자 동의 없이 는다.
# 어느 방향이든 하니스가 사용자의 모델 선택을 덮어쓰는 것이므로 `inherit`이 정답이다.
#
# 이전 버전은 이 자리에서 `opus` 핀을 옹호했다. 그 논증은 "Phase 1 워커가 sonnet"
# 이라는 전제에 기대는데, 워커들도 이 sweep에서 `inherit`이 되어 전제가 사라졌다.
#
# 양방향 락이다 — positive(`inherit` 실재) + negative(고정 티어 부재). 하나만 두면
# 반대 방향 mutation(`model:` 줄 통째 삭제 / 핀 재도입)이 조용히 통과한다.
#
# Single source of truth: agents/adversarial.md frontmatter (`model: inherit`).
# SKILL dispatch는 model override를 pin하지 않는다 — frontmatter에 의존한다.

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

# 1. Frontmatter is the single source of truth — must be inherit (양방향).
assert_grep "$AGENT" '^model: inherit$' "adversarial.md frontmatter is model: inherit"
assert_not_grep "$AGENT" '^model: (opus|sonnet|haiku)$' "adversarial.md frontmatter pins no fixed tier"

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

# 3. README must describe adversarial as inherit, consistently in both the model
#    note and the Gate 2 phase diagram.
assert_grep "$README" 'quality-gates:adversarial[[:space:]]+\(Phase 1\.5, inherit\)' "README phase diagram tags Adversarial as inherit"
assert_grep "$README" '`adversarial` agent uses `model: inherit`' "README model note states inherit"
assert_not_grep "$README" '`adversarial` agent uses `model: (opus|sonnet|haiku)`' "README model note pins no fixed tier"

echo ""
echo "Tests passed: $PASS, failed: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
