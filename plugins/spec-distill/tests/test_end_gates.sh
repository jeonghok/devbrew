#!/usr/bin/env bash
# guards: plugins/spec-distill/references/proceed-gate.md plugins/spec-distill/skills/spec-interview/references/finishing.md plugins/spec-distill/templates/interview-brief-template.md plugins/spec-distill/skills/spec-interview/SKILL.md plugins/spec-distill/references/epic-handoff.md
#
# R10 계획 2 — 끝 게이트: 정본의 둘째 질문(선택) · 인터뷰 끝 ①② 이름 표 · 다른 다음 단계의 줄.
# 정적 락이다 — 모델이 이 문면을 실제로 따르는지는 재지 못한다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT/plugins/spec-distill"
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/references/proceed-gate.md"
  echo "plugins/spec-distill/skills/spec-interview/references/finishing.md"
  echo "plugins/spec-distill/templates/interview-brief-template.md"
  echo "plugins/spec-distill/skills/spec-interview/SKILL.md"
  echo "plugins/spec-distill/references/epic-handoff.md"
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }
win() { awk -v a="$2" -v b="$3" '$0 ~ a {f=1; print; next} f && $0 ~ b {f=0} f' "$1" | tr '\n' ' ' | tr -s ' '; }
PG="$SD/references/proceed-gate.md"; FIN="$SD/skills/spec-interview/references/finishing.md"
# AC17(정본) — Step B 안에 있다(다음 세션 명령 절 앞)
STEPB="$(win "$PG" '^## Step B' '^## ')"
[ -n "$STEPB" ] && ok "AC17(양성 대조): 정본 Step B 를 떴다" || no "AC17: 정본 Step B 부재"
for lit in '**둘째 질문(선택) — 다음 단계 갈래.**' '머리글은 「다음 단계 갈래」' \
           '첫 질문의 네 선택지 · 순서 · `(권장)` 은 그대로다' '①/② 의 이름과 설명은 특정 단계를 가리키지 않는다' \
           '제안이 없으면 둘째 질문도 없다' '`## 다음 세션 명령` 규칙 3 대로'; do
  assert_contains "$STEPB" "$lit" "AC17(정본): «${lit}»"
done
B2="$(win "$FIN" '^#### B-2' '^#### ')"; B3="$(win "$FIN" '^#### B-3' '^#### ')"
[ -n "$B2" ] && [ -n "$B3" ] && ok "양성 대조: B-2 · B-3 를 떴다" || no "B-2 · B-3 부재"
# AC21 — 분해된 일의 이름 · 하나짜리 이름 그대로 · /compact 가 ①(권장)
assert_contains "$B2" '| 하나짜리 brief · 둘째 질문 없음 | 확정하고 /compact 후 brainstorming (권장) | 확정하고 /new 후 brainstorming |' "AC21: 하나짜리 brief 이름 그대로"
assert_contains "$B2" '| 분해된 일 | 확정하고 /compact 후 지휘자로 (권장) | 확정하고 /new 후 지휘자로 |' "AC21: 분해된 일은 지휘자로"
assert_contains "$B2" '이 세션에서 로드맵의 에픽들을 끝까지 이끈다' "AC21: 분해된 일의 설명이 지휘자를 말한다"
# AC23 — 둘째 질문이 있으면 단계 안 가리키는 이름 · 정본을 가리킴 · 제안 없으면 없음 · 분해된 일엔 없음
assert_contains "$B2" '| 하나짜리 brief · 둘째 질문 있음 | 확정하고 /compact 후 다음 단계로 (권장) | 확정하고 /new 후 다음 단계로 |' "AC23: 둘째 질문이 있으면 단계를 가리키지 않는 이름"
for lit in '선택지 넷의 개수 · 순서 · `(권장)` 은 어느 경우든 그대로' \
           '`${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md` 의 「둘째 질문(선택)」 대로' \
           '「brainstorming (권장)」 · 「<모델의 제안>」' '제안 이유는 게이트 앞 글' \
           '제안이 없으면 둘째 질문도 없다' '분해된 일에는 둘째 질문을 두지 않는다'; do
  assert_contains "$B2" "$lit" "AC23: B-2 «${lit}»"
done
para() { awk -v m="$2" 'index($0,m)==1{print}' "$1"; }
NEWP="$(para "$FIN" '**다른 다음 단계의 줄 — 둘째 질문에서 제안을 골랐을 때.**')"
SAMEP="$(para "$FIN" '**이름이 바뀌어도 절차는 같다.**')"
[ -n "$NEWP" ] && [ -n "$SAMEP" ] && ok "양성 대조: B-3 의 「다른 다음 단계의 줄」 · 「이름이 바뀌어도 절차는 같다」 문단을 떴다" || no "B-3 새 문단 부재"
assert_contains "$B3" '**다른 다음 단계의 줄 — 둘째 질문에서 제안을 골랐을 때.**' "AC23: B-3 안에 있다"
assert_contains "$B3" '**이름이 바뀌어도 절차는 같다.**' "AC23: B-3 안에 있다(절차 문단)"
for lit in '`@<brief-path>` 를 원소로' 'confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지.' \
           '§3 열린 질문 · §4 조사 · §5 위험을 번호째 입력으로 읽는다' \
           'brief 의 확정 항목은 다시 묻지 않고 되비춤으로 확인한다.' \
           '사람에게 쓰는 글의 낱말 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에)을 지킨다.' \
           '`next_phase:` 를 고른 skill 의 완전명으로 바꾼다' '인용 줄로 두지 않는다'; do
  assert_contains "$NEWP" "$lit" "AC23: 「다른 다음 단계의 줄」 문단 «${lit}»"
done
assert_contains "$SAMEP" '「같은 턴에서 호출하지 말 것」은 그 줄이 부르는 skill(지휘자 · 고른 skill) 모두에 선다.' "AC23: 같은 턴 금지가 지휘자 · 고른 skill 모두에 선다"
EH="$SD/references/epic-handoff.md"; TPL="$SD/templates/interview-brief-template.md"; SKI="$SD/skills/spec-interview/SKILL.md"
nsl() { awk -v m="$2" '$0==m{f=1;next} f&&NF{print;exit}' "$1"; }
BL="$(nsl "$FIN" '**다음 세션 줄 — ①/② 공통**')"; EL="$(nsl "$EH" '**에픽 넘김 줄**')"
SHARED='설계문서에 ## 있는 것 검토 절(레포 안에 이미 있는 것을 먼저 찾아 쓰고, 레포 밖 패키지 · 프레임워크 · 서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다)과 ## 상류 · 하류 연계 절(이 일이 받는 곳 · 넘기는 곳 · 되돌아오는 길 · 같은 상태를 읽는 다른 표면)을 두고, 경로 · 테스트 명령 · 기본 브랜치 · 브랜치 이름 · 모델 같은 레포 전용 값은 박지 말고 도출하거나 레포 설정에서 읽게 설계한다.'
assert_contains "$EL" "$SHARED" "AC22(양성 대조): 에픽 넘김 줄에 원칙 문장"
assert_contains "$BL" "$SHARED" "AC22: brief 줄의 원칙 문장이 에픽 넘김 줄과 글자가 같다"
# AC18
grep -qxF 'next_phase: superpowers:brainstorming   # 기본 다음 단계 — 끝 게이트의 둘째 질문에서 다른 단계를 고르면 그 skill 의 완전명' "$TPL" \
  && ok "AC18: 템플릿 next_phase 가 기본 다음 단계라고 말한다" || no "AC18: 템플릿 next_phase 주석 부재"
assert_contains "$(flat "$TPL")" '§7 대로 기본 다음 단계(brainstorming 해답공간)로' "AC18: 템플릿 정의 문장"
assert_contains "$(win "$TPL" '^## 7[.]' '^## ')" '(기본 다음 단계 — superpowers 있으면:' "AC18: §7 이 기본 다음 단계를 말한다"
assert_contains "$(flat "$FIN")" '`next_phase: superpowers:brainstorming`(기본 다음 단계 — 끝 게이트의 둘째 질문에서 다른 단계를 고르면 B-3 이 그 skill 의 완전명으로 바꾼다)' "AC18: Step A 의 next_phase"
assert_contains "$(flat "$SKI")" 'interview brief**(기본 다음 단계가 brainstorming 인 meta-prompt)' "AC18: SKILL 정의 문장"
grep -qF 'brainstorming용 meta-prompt' "$SKI" && no "AC18: 옛 「brainstorming용」 정의 잔존" || ok "AC18: 옛 정의 없음(양성 짝: 위 단언)"
finish
