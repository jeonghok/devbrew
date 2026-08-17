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

# NOTE: 이 파일의 자체 assert_file_grep/assert_file_absent 는 이름은 정본과 같지만
# 시그니처가 다르다(file 이 첫 인자) — 정본 assert_file_grep 은 text 가 첫 인자라
# 이름만 지우고 source 하면 파일 경로 문자열을 grep 대상으로 오인한다(조용한
# 실패). 그래서 이관은 이름 유지가 아니라 assert_file_grep/assert_file_absent
# 로 개명한다. 아래 fail-closed 부재-파일 처리는 정본 assert_file_absent 가
# 이미 이 파일의 실측을 반영해 흡수했다(shared/tests/assert.sh 헤더 주석 참고).
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# 1. Frontmatter is the single source of truth — must be inherit (양방향).
assert_file_grep "$AGENT" '^model: inherit$' "adversarial.md frontmatter is model: inherit"
assert_file_absent "$AGENT" '^model: (opus|sonnet|haiku)$' "adversarial.md frontmatter pins no fixed tier"

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
  no "SKILL has no adversarial reviewer reference (pattern not found in ${SKILL##*/})"
else
  win_start=$((adv_line_no > 5 ? adv_line_no - 5 : 1))
  win_end=$((adv_line_no + 5))
  adv_window="$(sed -n "${win_start},${win_end}p" "$SKILL" 2>/dev/null || true)"
  if printf '%s' "$adv_window" | grep -qE 'model[[:space:]]*=[[:space:]]*["'\'']?(opus|sonnet|haiku)'; then
    no "SKILL adversarial reference has a model override nearby (must rely on frontmatter)"
  else
    ok "SKILL adversarial reference has no nearby model override (relies on frontmatter)"
  fi
fi

# 3. README must describe adversarial as inherit, consistently in both the model
#    note and the Gate 2 phase diagram.
assert_file_grep "$README" 'quality-gates:adversarial[[:space:]]+\(Phase 1\.5, inherit\)' "README phase diagram tags Adversarial as inherit"
assert_file_grep "$README" '`adversarial` agent uses `model: inherit`' "README model note states inherit"
assert_file_absent "$README" '`adversarial` agent uses `model: (opus|sonnet|haiku)`' "README model note pins no fixed tier"

finish
