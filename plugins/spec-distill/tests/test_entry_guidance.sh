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
  assert_contains "$C" 'spec-distill 전체(리뷰 · 상태 계산 포함)가 꺼진다' "Ruling R35: ${f##*/} 끄는 스위치가 플러그인 전체를 끈다고 말한다"
  assert_contains "$C" '끄지 말고 지휘자를 부르지 않은 채' "Ruling R35: ${f##*/} 손 절차는 끄지 않고 지휘자 없이 따른다"
  assert_not_contains "$C" '지휘자를 껐으면' "Ruling R35: ${f##*/} 「지휘자를 끄면 손 절차」 옛 문장이 없다"
done
TPL_LINE="$(cond "$TPL" | grep -F '이 로드맵은 지휘자가 이끈다')"
RM_LINE="$(cond "$RMAP" | grep -F '이 로드맵은 지휘자가 이끈다')"
RM_REL="${RMAP#"$ROOT"/}"
TOK='{{ROADMAP}}'
[ -n "$TPL_LINE" ] && [ "$RM_REL" != "$RMAP" ] && ok "안내 줄과 로드맵 상대경로를 읽었다" || no "안내 줄이나 로드맵 상대경로를 못 읽었다 — 아래 비교가 공허하다"
assert_eq "${RM_LINE//"$RM_REL"/$TOK}" "$TPL_LINE" "템플릿과 이 로드맵의 지휘자 안내 줄은 경로만 다르다"
assert_eq "$(grep -cF -- "$SHARED" "$CD")" "1" "AC37: conducting.md 에 같은 문장이 한 번"
assert_contains "$(sed -n '1,5p' "$EH")" '지휘자를 껐거나' "AC31: 넘김 줄은 지휘자를 끈 경우(또는 사용자가 따로 진행할 때)에만"
assert_contains "$(sed -n '1,5p' "$EH")" '자기 brainstorming 입력으로 쓴다' "AC31: 지휘자는 넘김 줄을 사용자에게 주지 않는다"
assert_eq "$(grep -cF '지휘 세션이 붙여 넣는 줄' "$EH" || true)" "0" "넘김 줄 머리말: 재결정 전 표현이 없다"
assert_eq "$(grep -cF '새 세션(`/new`)의 첫 줄로' "$EH" || true)" "0" "넘김 줄 끝 문장: 새 세션을 전제하지 않는다"
RB="$(awk '/^\*\*로드맵 에픽이면 — 둘째 줄은 지휘자 호출\.\*\*/{f=1} f&&/^- \*\*①\/② 의 정지 요건\*\*/{exit} f' "$SR")"
[ -n "$RB" ] && ok "AC42: spec-review 의 로드맵 갈래 문단이 있다" || no "AC42: 로드맵 갈래 문단이 없다"
for lit in '`roadmap:` 줄이 있으면' '`/spec-distill:epic-conductor <roadmap 절대경로>`' '계획 agent 의 입력(지휘자가 넘긴다 — 지휘자 없이 이 세션에서 이어 갈 때만 친다)' '`roadmap:` 줄이 없으면 위 줄 그대로다' '이 갈래는 지휘 세션 없이 이 리뷰를 부른 경우다' \
           '「승인 — 계획 담당자에게 (권장)」 · 「수정 필요」 · 「멈춤」' '「수정 필요」 는 ③ 의 후속 갈래 그대로이고, 「멈춤」 은 ④ 다' \
           '같은 턴에 지휘 세션이 계획 agent 를 보낸다' '이 갈래는 명령 두 줄을 노출하지 않고 여기서 턴을 끝내지도 않는다'; do
  assert_contains "$RB" "$lit" "AC42 · 지휘자 수리 1: $lit"
done
# 지휘자 수리 1 — 지휘 세션이 돌린 리뷰의 승인: 미커밋 확인 → 승인 줄과 커밋 → 기계 상태 저장 → 같은 턴에 계획 agent
gate_order() {  # gate_order <글> — 넷이 이 순서면 yes
  PYTHONIOENCODING=utf-8 python3 -I -c 'import sys
t = sys.argv[1]
s = t.find("**지휘 세션이 돌린 리뷰면 — 승인 질문 하나.**")
ks = ["`### 미커밋 확인`", "승인 줄 기록", "기계 상태 저장", "같은 턴에 지휘 세션이 계획 agent 를 보낸다"]
ix = [t.find(k, s) for k in ks]
print("yes" if s >= 0 and min(ix) >= 0 and ix == sorted(ix) else "no")' "$1"
}
assert_eq "$(gate_order "$RB")" "yes" "지휘자 수리 1: 승인 갈래는 미커밋 확인 → 승인 줄 · 커밋 → 저장 → 같은 턴 계획 agent 차례"
assert_eq "$(gate_order '**지휘 세션이 돌린 리뷰면 — 승인 질문 하나.** 같은 턴에 지휘 세션이 계획 agent 를 보낸다. `### 미커밋 확인` 승인 줄 기록 기계 상태 저장')" "no" "양성 대조: 계획 agent 를 먼저 보내면 no"
for old in '①/② 를 골라도 정리만 한다' '계획 agent 는 이 턴에 띄우지 않는다'; do
  assert_not_contains "$RB" "$old" "지휘자 수리 1: 옛 문장 「${old}」 이 없다(양성 짝: 위 승인 질문 하나 문장)"
done
assert_contains "$(awk '/^## 5\. 적용/{f=1;next} f&&/^## /{exit} f' "$RED")" '고른 라벨을 글자 그대로' "재분해 5: 라벨만 고른 답의 --approval"
assert_contains "$(awk '/^## 5\. 적용/{f=1;next} f&&/^## /{exit} f' "$RED")" '「순서만」' "재분해 5: 순서만 바뀐 경우"
finish
