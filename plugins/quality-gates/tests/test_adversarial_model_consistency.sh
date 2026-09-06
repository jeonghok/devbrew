#!/usr/bin/env bash
# Drift guard — adversarial 리뷰어의 모델 선언이 세 곳에서 일관되게 «키 부재»인지
# 확인한다. adversarial은 Gate 2의 단일 model-based 판정 병목이다(synthesizer는
# 결정론 스크립트). 하니스가 여기서 티어를 정하면 안 된다 — 리터럴 핀은 세션 선택을
# 덮어쓰고, `inherit` 는 사용자의 subagent 기본 티어 설정(`CLAUDE_CODE_SUBAGENT_MODEL`)을
# 덮어쓴다(CLI 2.1.261 실측, 2026-09-06). 키가 없어야 「사용자 설정 → 세션 모델」로 위임된다.
#
# 이전 버전들은 이 자리에서 `opus` 핀을, 그 다음엔 `inherit` 를 옹호했다. 둘 다
# 하니스가 티어를 정하는 값이었다.
#
# 세 곳: frontmatter(키 부재) · SKILL dispatch(model= override 부재) · README(같은 사실 서술).
#
# Single source of truth: agents/adversarial.md frontmatter (`model` 키 없음).
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

# 1. Frontmatter is the single source of truth — model 키 부재.
MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"
assert_file_absent "$AGENT" "$MODEL_KEY" "adversarial.md frontmatter 에 model 키 없음"

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

# 3. README must describe adversarial as tier-unpinned, consistently in both the
#    model note and the Gate 2 phase diagram.
assert_file_grep "$README" 'quality-gates:adversarial[[:space:]]+\(Phase 1\.5, tier-unpinned\)' "README phase diagram tags Adversarial as tier-unpinned"
assert_file_grep "$README" '`adversarial` agent declares no `model` key' "README model note states no model key"
assert_file_absent "$README" '`adversarial` agent uses `model: (inherit|opus|sonnet|haiku)`' "README model note names no tier"

finish
