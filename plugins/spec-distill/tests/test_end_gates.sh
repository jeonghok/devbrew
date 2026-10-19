#!/usr/bin/env bash
# guards: plugins/spec-distill/references/proceed-gate.md plugins/spec-distill/skills/spec-interview/references/finishing.md
#
# R10 계획 2 — 끝 게이트: 정본의 둘째 질문(선택) · 인터뷰 끝 ①② 이름 표 · 다른 다음 단계의 줄.
# 정적 락이다 — 모델이 이 문면을 실제로 따르는지는 재지 못한다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT/plugins/spec-distill"
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/references/proceed-gate.md"
  echo "plugins/spec-distill/skills/spec-interview/references/finishing.md"
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
for lit in '**이름이 바뀌어도 절차는 같다.**' '**다른 다음 단계의 줄 — 둘째 질문에서 제안을 골랐을 때.**' \
           '`@<brief-path>` 를 원소로' 'confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지.' \
           '§3 열린 질문 · §4 조사 · §5 위험을 번호째 입력으로 읽는다' \
           'brief 의 확정 항목은 다시 묻지 않고 되비춤으로 확인한다.' \
           '사람에게 쓰는 글의 낱말 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에)을 지킨다.' \
           '`next_phase:` 를 고른 skill 의 완전명으로 바꾼다' '인용 줄로 두지 않는다'; do
  assert_contains "$B3" "$lit" "AC23: B-3 «${lit}»"
done
finish
