#!/usr/bin/env bash
# PN2/V8/AC10 — reviewing-spec is design-mode only; spec-mode/re-consensus/Mode B removed;
# drafting-spec absent from skills/hooks/commands.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PLUGIN="$REPO_ROOT/plugins/spec-distill"
SKILL="$PLUGIN/skills/reviewing-spec/SKILL.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

grep -qE 'design\b.*approved.*Human Gate' "$SKILL" \
  && ok "design approved → Human Gate row present" || no "design approved row missing"
grep -qE 'design\b.*needs_revise.*author' "$SKILL" \
  && ok "design needs_revise → author 회귀 row present" || no "design needs_revise row missing"

grep -qiE 'reconsensus|re-consensus|\[3\.5\]' "$SKILL" \
  && no "re-consensus gate still present (should be removed)" \
  || ok "re-consensus [3.5] removed"
grep -qE 'mode_b_violation' "$SKILL" \
  && no "mode_b_violation still present" || ok "mode_b_violation removed"
grep -qE '^\|[[:space:]]*\**[[:space:]]*spec\b' "$SKILL" \
  && no "spec-mode routing rows still present" || ok "spec-mode routing rows removed"
grep -q 'drafting-spec' "$SKILL" \
  && no "drafting-spec still referenced in reviewing-spec" || ok "drafting-spec ref removed from reviewing-spec"

# F9-D: scan agents/ + templates/ too — the exact dirs this PR cleaned of
# drafting-spec/Mode-B refs (spec-reviewer persona, spec-template comment).
# Task 33: `$PLUGIN/references` (플러그인 레벨 공유 계약, skills/ 밖) 도 스캔 루트다.
#
# 〔fix round 1 / F4〕 루트를 덧붙이기만 하면 오타·개명 시 `grep -r` 의 *No such file* 이
# `2>/dev/null` 에 삼켜지고, 이 **부재** 단언은 좁아진 코퍼스 위에서 통과한다(조용한 축소).
# 열거한 루트가 전부 실재하는지 먼저 잰다.
F9D_ROOTS=("$PLUGIN/skills" "$PLUGIN/hooks" "$PLUGIN/commands" \
  "$PLUGIN/agents" "$PLUGIN/templates" "$PLUGIN/references")
for _r in "${F9D_ROOTS[@]}"; do
  [[ -d "$_r" ]] \
    && ok "AC10/F9-D: 스캔 루트 실재 — ${_r#"$PLUGIN/"}" \
    || no "AC10/F9-D: 스캔 루트 '${_r#"$PLUGIN/"}' 부재 — grep -r 이 그 코퍼스를 조용히 건너뛴다"
done
COUNT=$(grep -rl 'drafting-spec' "${F9D_ROOTS[@]}" 2>/dev/null | wc -l | tr -d ' ')
[[ "$COUNT" == "0" ]] && ok "AC10/F9-D: 0 drafting-spec refs in skills/hooks/commands/agents/templates" \
  || no "AC10/F9-D: $COUNT drafting-spec refs remain"
[[ ! -d "$PLUGIN/skills/drafting-spec" ]] && ok "drafting-spec/ directory removed" \
  || no "drafting-spec/ directory still exists"
finish
