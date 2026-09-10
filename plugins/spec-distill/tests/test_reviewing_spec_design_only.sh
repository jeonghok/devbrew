#!/usr/bin/env bash
# PN2/V8/AC10 — reviewing-spec is design-mode only; spec-mode/re-consensus/Mode B removed;
# drafting-spec absent from skills/hooks/commands.
#
# ── 앵커 (2.0.0) ─────────────────────────────────────────────────────────────
# 이 파일의 주제 — *"이 skill 은 design 자리 전용인가"* — 를 오늘 지탱하는 것은 **프로필
# 고정**이다: 이 skill 은 `design-doc.md` 하나만 고르고, 호출 인자에는 모드가 없다. 그래서
# 양의 단언은 `## 프로필` 절의 고정 문장을, 음의 단언은 옛 모드 슬롯의 부재를 잰다.
#
# 아래 **부재** 단언 넷(re-consensus · mode_b_violation · spec-mode 표 행 · drafting-spec)
# 은 그대로다 — 그것들이 잠그는 개념은 되살아나면 안 된다.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PLUGIN="$REPO_ROOT/plugins/spec-distill"
SKILL="$PLUGIN/skills/reviewing-spec/SKILL.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# (1) 이 skill 이 고르는 프로필은 design-doc 하나다.
grep -qF 'references/docreview-profiles/design-doc.md' "$SKILL" \
  && ok "design-doc 프로필을 이름으로 고른다" \
  || no "design-doc 프로필 선택이 사라졌다 — 이 skill 이 어느 자리인지 문서가 말하지 않는다"

# (2) 프로필이 design-doc 하나로 **고정**이라는 주장이 `## 프로필` 절 **안에** 있는가.
#     파일 어딘가가 아니라 그 절 — 헤더나 다른 절의 문장으로는 만족되지 않는다.
PROF_WIN="$(awk '/^## 프로필$/{f=1; next} f && /^## /{f=0} f' "$SKILL")"
if [[ -z "$PROF_WIN" ]]; then
  no "(2) '## 프로필' 창이 비었다 — 구조 앵커 파손 (통과 아님)"
elif grep -qE 'design-doc\.md.*고정' <<<"$PROF_WIN"; then
  ok "(2) '## 프로필' 절이 design-doc.md 고정을 주장한다"
else
  no "(2) '## 프로필' 절에 design-doc.md 고정 문장이 없다 — 이 skill 이 어느 자리인지 말하지 않는다"
fi

# (2a) 옛 모드 슬롯이 없다 — 모드 값으로 프로필이 갈라질 입력 자체가 없어야 한다.
grep -qE '\$mode|mode: (design|spec)' "$SKILL" \
  && no "(2a) 모드 슬롯(\$mode / mode: design|spec)이 남았다" \
  || ok "(2a) 모드 슬롯이 없다"

# (2b) 위 (2)는 «주장»을 재고, 이 축은 «사실»을 잰다: 실재하는 프로필 파일 중 이 skill 이
#      이름 대는 것이 design-doc 하나뿐인가. 대상은 열거가 아니라 프로필 디렉터리에서
#      도출한다 — 넷째 프로필이 생기면 자동으로 이 축에 들어온다.
PROF_DIR="$PLUGIN/references/docreview-profiles"
prof_n=0
named_other=""
for _pf in "$PROF_DIR"/*.md; do
  [[ -f "$_pf" ]] || continue
  prof_n=$((prof_n + 1))
  _b="$(basename -- "$_pf")"
  [[ "$_b" == "design-doc.md" ]] && continue
  grep -qF -- "$_b" "$SKILL" && named_other="$named_other $_b"
done
if [[ "$prof_n" -lt 2 ]]; then
  no "(2b) 프로필 디렉터리에서 ${prof_n}개만 도출 — 「design-doc 말고 다른 것을 안 부른다」가 이 상태에서 공허하다"
elif [[ -z "$named_other" ]]; then
  ok "(2b) 실재 프로필 ${prof_n}개 중 이 skill 이 이름 대는 것은 design-doc 하나뿐이다"
else
  no "(2b) 이 skill 이 design-doc 아닌 프로필을 이름 댄다:$named_other — design 전용이 아니게 된다"
fi

grep -qiE 'reconsensus|re-consensus|\[3\.5\]' "$SKILL" \
  && no "re-consensus gate still present (should be removed)" \
  || ok "re-consensus [3.5] removed"
grep -qE 'mode_b_violation' "$SKILL" \
  && no "mode_b_violation still present" || ok "mode_b_violation removed"
grep -qE '^\|[[:space:]]*\**[[:space:]]*spec\b' "$SKILL" \
  && no "spec-mode routing rows still present" || ok "spec-mode routing rows removed"
grep -q 'drafting-spec' "$SKILL" \
  && no "drafting-spec still referenced in reviewing-spec" || ok "drafting-spec ref removed from reviewing-spec"

# F9-D: scan agents/ + templates/ too — the exact dirs an earlier PR cleaned of
# drafting-spec/Mode-B refs (design 자리 리뷰어 persona · 템플릿 주석).
# 그 persona 파일은 문서 리뷰 엔진 전환(T7)으로 사라졌지만 두 디렉토리는 여전히
# 스캔 루트다 — 코퍼스를 좁히면 이 부재 단언이 조용히 약해진다.
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
