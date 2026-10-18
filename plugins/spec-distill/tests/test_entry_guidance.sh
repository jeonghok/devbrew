#!/usr/bin/env bash
# R5 계획 3 — 지휘자를 가리키는 진입 안내: 나눈 일의 다음 세션 줄(AC36) · 템플릿과 이 로드맵의 지휘 절차(AC37) ·
# 에픽 넘김 줄은 지휘자를 끈 경우에만(AC31) · spec-review 승인 게이트의 로드맵 갈래(AC42 · 결정 K) · 재분해 이력 문면.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_entry_guidance.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SD="$ROOT/plugins/spec-distill"
FIN="$SD/skills/spec-interview/references/finishing.md"
TPL="$SD/templates/roadmap-template.md"
RMAP="$ROOT/docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md"
EH="$SD/references/epic-handoff.md"
SR="$SD/skills/spec-review/SKILL.md"
RED="$SD/references/redecompose.md"
CD="$SD/references/conducting.md"
SHARED='실행 방식은 writing-plans 가 권하는 방식이고, 계획 검토는 계획에 설계에 없던 결정이 있을 때만 기다린다.'
MARK='**다음 세션 줄 — 분해된 일 ①/② 공통**'
DLINE="$(awk -v m="$MARK" '$0==m{f=1;next} f&&NF{print;exit}' "$FIN")"
assert_eq "$DLINE" '`/spec-distill:epic-conductor <roadmap-path>`' "AC36: 나눈 일의 다음 세션 줄이 지휘자 호출 한 줄"
assert_eq "$(grep -cF '이 로드맵의 지휘 절차대로 진행하라' "$FIN" || true)" "0" "AC36: 옛 지휘 절차 줄이 없다"
cond() { awk '$0=="## 지휘 절차"{f=1;next} f&&/^## /{exit} f' "$1"; }
for f in "$TPL" "$RMAP"; do
  C="$(cond "$f")"
  assert_contains "$C" '/spec-distill:epic-conductor' "AC37: ${f##*/} 지휘 절차가 지휘자 호출을 안내한다"
  assert_contains "$C" "$SHARED" "AC37: ${f##*/} 지휘 절차 4 의 뜻이 공유 문장과 같다"
  assert_contains "$C" '손으로 따르는 절차' "AC37: ${f##*/} 지휘자를 끈 경우의 손 절차를 가리킨다"
  assert_eq "$(printf '%s\n' "$C" | grep -cE '^[0-9]+\. ' || true)" "0" "AC37: ${f##*/} 지휘 절차에 옛 번호 걸음이 없다"
done
assert_eq "$(grep -cF -- "$SHARED" "$CD")" "1" "AC37: conducting.md 에 같은 문장이 한 번"
assert_contains "$(sed -n '1,5p' "$EH")" '지휘자를 껐거나' "AC31: 넘김 줄은 지휘자를 끈 경우(또는 사용자가 따로 진행할 때)에만"
assert_contains "$(sed -n '1,5p' "$EH")" '자기 brainstorming 입력으로 쓴다' "AC31: 지휘자는 넘김 줄을 사용자에게 주지 않는다"
assert_eq "$(grep -cF '지휘 세션이 붙여 넣는 줄' "$EH" || true)" "0" "넘김 줄 머리말: 재결정 전 표현이 없다"
assert_eq "$(grep -cF '새 세션(`/new`)의 첫 줄로' "$EH" || true)" "0" "넘김 줄 끝 문장: 새 세션을 전제하지 않는다"
RB="$(awk '/^\*\*로드맵 에픽이면 — 둘째 줄은 지휘자 호출\.\*\*/{f=1} f&&/^- \*\*①\/② 의 정지 요건\*\*/{exit} f' "$SR")"
[ -n "$RB" ] && ok "AC42: spec-review 의 로드맵 갈래 문단이 있다" || no "AC42: 로드맵 갈래 문단이 없다"
for lit in '`roadmap:` 줄이 있으면' '`/spec-distill:epic-conductor <roadmap 절대경로>`' '계획 agent 의 입력(치지 않는다)' '`roadmap:` 줄이 없으면 위 줄 그대로다'; do
  assert_contains "$RB" "$lit" "AC42: $lit"
done
assert_contains "$(awk '/^## 5\. 적용/{f=1;next} f&&/^## /{exit} f' "$RED")" '고른 라벨을 글자 그대로' "재분해 5: 라벨만 고른 답의 --approval"
assert_contains "$(awk '/^## 5\. 적용/{f=1;next} f&&/^## /{exit} f' "$RED")" '「순서만」' "재분해 5: 순서만 바뀐 경우"
finish
