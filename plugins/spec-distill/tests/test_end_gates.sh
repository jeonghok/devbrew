#!/usr/bin/env bash
# guards: plugins/spec-distill/references/proceed-gate.md plugins/spec-distill/skills/context-build/references/finishing.md plugins/spec-distill/skills/roadmap-draft/SKILL.md plugins/spec-distill/templates/interview-brief-template.md plugins/spec-distill/skills/context-build/SKILL.md plugins/spec-distill/references/epic-handoff.md plugins/spec-distill/references/brief-handoff.md plugins/spec-distill/references/trivia-escape.md plugins/spec-distill/agents/steelman-builder.md plugins/spec-distill/skills/context-build/references/steelman.md plugins/spec-distill/skills/intent-sync/SKILL.md plugins/spec-distill/scripts/roadmap_render.py plugins/spec-distill/scripts/roadmap_model.py plugins/spec-distill/CHANGELOG.md plugins/spec-distill/README.md
#
# R10 계획 2 — 끝 게이트: 정본의 둘째 질문(선택) · 인터뷰 끝 ①② 이름 표 · 다른 다음 단계의 줄.
# 정적 락이다 — 모델이 이 문면을 실제로 따르는지는 재지 못한다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT/plugins/spec-distill"
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/references/proceed-gate.md"
  echo "plugins/spec-distill/skills/context-build/references/finishing.md"
  echo "plugins/spec-distill/skills/roadmap-draft/SKILL.md"
  echo "plugins/spec-distill/templates/interview-brief-template.md"
  echo "plugins/spec-distill/skills/context-build/SKILL.md"
  echo "plugins/spec-distill/references/epic-handoff.md"
  echo "plugins/spec-distill/references/brief-handoff.md"
  echo "plugins/spec-distill/references/trivia-escape.md"
  echo "plugins/spec-distill/agents/steelman-builder.md"
  echo "plugins/spec-distill/skills/context-build/references/steelman.md"
  echo "plugins/spec-distill/skills/intent-sync/SKILL.md"
  echo "plugins/spec-distill/scripts/roadmap_render.py"
  echo "plugins/spec-distill/scripts/roadmap_model.py"
  echo "plugins/spec-distill/CHANGELOG.md"
  echo "plugins/spec-distill/README.md"
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }
win() { awk -v a="$2" -v b="$3" '$0 ~ a {f=1; print; next} f && $0 ~ b {f=0} f' "$1" | tr '\n' ' ' | tr -s ' '; }
PG="$SD/references/proceed-gate.md"; FIN="$SD/skills/context-build/references/finishing.md"; RDS="$SD/skills/roadmap-draft/SKILL.md"
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
           '「<모델의 제안> (권장)」 · 「brainstorming」' '제안 선택지의 설명은 「얻음: <제안 이유> · 내줌: <그 제안이 틀렸을 때 원인이 될 것 하나>」로 쓴다' \
           '제안이 없으면 둘째 질문도 없다' '분해된 일에는 둘째 질문을 두지 않는다'; do
  assert_contains "$B2" "$lit" "AC23: B-2 «${lit}»"
done
para() { awk -v m="$2" 'index($0,m)==1{print}' "$1"; }
NEWP="$(para "$FIN" '**다른 다음 단계의 줄 — 둘째 질문에서 제안을 골랐을 때.**')"
SAMEP="$(para "$FIN" '**이름이 바뀌어도 절차는 같다.**')"
[ -n "$NEWP" ] && [ -n "$SAMEP" ] && ok "양성 대조: B-3 의 「다른 다음 단계의 줄」 · 「이름이 바뀌어도 절차는 같다」 문단을 떴다" || no "B-3 새 문단 부재"
assert_contains "$B3" '**다른 다음 단계의 줄 — 둘째 질문에서 제안을 골랐을 때.**' "AC23: B-3 안에 있다"
assert_contains "$B3" '**이름이 바뀌어도 절차는 같다.**' "AC23: B-3 안에 있다(절차 문단)"
for lit in '`@<brief-path>` 를 원소로' '줄에는 공통 지시를 글자로 싣지 않고' \
           '/references/brief-handoff.md 의 ## 공통 지시 절을 읽고 그 지시를 따른다' \
           '`next_phase:` 를 고른 skill 의 완전명으로 바꾼다' '인용 줄로 두지 않는다'; do
  assert_contains "$NEWP" "$lit" "AC23: 「다른 다음 단계의 줄」 문단 «${lit}»"
done
# F4 AC3 — 공통 지시 네 문장은 문단이 아니라 지시 파일의 `## 공통 지시` 절에 산다(양성 짝: 문단에는 없다)
BHF="$SD/references/brief-handoff.md"
bhsec() { awk -v h="## $1" '$0==h{f=1;next} f&&/^## /{exit} f' "$BHF" | tr '\n' ' ' | tr -s ' '; }
CMS="$(bhsec '공통 지시')"; BSS="$(bhsec 'brainstorming 지시')"
[ -n "$CMS" ] && [ -n "$BSS" ] && ok "F4(양성 대조): 지시 파일의 두 절을 떴다" || no "F4: 지시 파일의 절 부재"
for lit in 'confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지.' \
           '§3 열린 질문 · §4 조사 · §5 위험을 번호째 입력으로 읽는다' \
           'brief 의 확정 항목은 다시 묻지 않고 되비춤으로 확인한다.' \
           '사람에게 쓰는 글의 낱말 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에)을 지킨다.'; do
  assert_contains "$CMS" "$lit" "F4 AC3: 공통 지시 절 «${lit}»"
  assert_not_contains "$NEWP" "$lit" "F4 AC3: 「다른 다음 단계의 줄」 문단에는 글자로 없다 «${lit}»"
done
assert_contains "$SAMEP" '「같은 턴에서 호출하지 말 것」은 그 줄이 부르는 skill(지휘자 · 고른 skill) 모두에 선다.' "AC23: 같은 턴 금지가 지휘자 · 고른 skill 모두에 선다"
EH="$SD/references/epic-handoff.md"; TPL="$SD/templates/interview-brief-template.md"; SKI="$SD/skills/context-build/SKILL.md"
nsl() { awk -v m="$2" '$0==m{f=1;next} f&&NF{print;exit}' "$1"; }
BL="$(nsl "$FIN" '**다음 세션 줄 — ①/② 공통**')"; EL="$(nsl "$EH" '**에픽 넘김 줄**')"
SHARED='설계문서에 ## 있는 것 검토 절(맞는 있는 것이 있으면 그 위에서 만드는 것이 기본이다 — 찾아본 후보를 이름으로 먼저 적고, 직접 만들려면 그 후보에 대한 구체 이유를 적어 사용자 승인을 받는다. 레포 밖 것은 후보와 차이를 보여 사용자가 승인한 뒤에만 쓴다. 적는 법은 ${CLAUDE_PLUGIN_ROOT}/references/existing-first.md 를 읽어 따른다)과 ## 상류 · 하류 연계 절(이 일이 받는 곳 · 넘기는 곳 · 되돌아오는 길 · 같은 상태를 읽는 다른 표면)을 두고, 경로 · 테스트 명령 · 기본 브랜치 · 브랜치 이름 · 모델 같은 레포 전용 값은 박지 말고 도출하거나 레포 설정에서 읽게 설계한다.'
assert_contains "$EL" "$SHARED" "AC22(양성 대조): 에픽 넘김 줄에 원칙 문장"
assert_contains "$BSS" "$SHARED" "AC22: brief 지시 파일의 원칙 문장이 에픽 넘김 줄과 글자가 같다"
assert_not_contains "$BL" "$SHARED" "F4 AC1: 그 원칙 문장은 brief 줄에 글자로 없다(양성 짝: 위 단언)"
# 있는 것 먼저 — brief 지시 파일과 에픽 넘김 줄의 마지막 전체 리뷰가 고른 것을 썼는지도 묻는다(같은 글자: test_review_handoff_order.sh · test_conductor_dispatch_reference.sh)
USED='설계문서 ## 있는 것 검토 절이 고른 것을 실제로 썼는지(같은 것을 다시 만들지 않았는지)도 묻게 한다.'
assert_contains "$BSS" "$USED" "있는 것 먼저: brief 지시 파일의 마지막 전체 리뷰가 고른 것을 썼는지 묻는다"
assert_not_contains "$BL" "$USED" "있는 것 먼저: 그 묻는 구절은 brief 줄에 글자로 없다(양성 짝: 위 단언)"
assert_contains "$EL" "$USED" "있는 것 먼저: 에픽 넘김 줄의 마지막 전체 리뷰가 고른 것을 썼는지 묻는다"
# AC18
grep -qxF 'next_phase: superpowers:brainstorming   # 기본 다음 단계 — 끝 게이트의 둘째 질문에서 다른 단계를 고르면 그 skill 의 완전명' "$TPL" \
  && ok "AC18: 템플릿 next_phase 가 기본 다음 단계라고 말한다" || no "AC18: 템플릿 next_phase 주석 부재"
assert_contains "$(flat "$TPL")" '§7 대로 기본 다음 단계(brainstorming 해답공간)로' "AC18: 템플릿 정의 문장"
assert_contains "$(win "$TPL" '^## 7[.]' '^## ')" '(기본 다음 단계 — superpowers 있으면:' "AC18: §7 이 기본 다음 단계를 말한다"
assert_contains "$(flat "$FIN")" '`next_phase: superpowers:brainstorming`(기본 다음 단계 — 끝 게이트의 둘째 질문에서 다른 단계를 고르면 B-3 이 그 skill 의 완전명으로 바꾼다)' "AC18: Step A 의 next_phase"
assert_contains "$(flat "$SKI")" 'interview brief**(기본 다음 단계가 brainstorming 인 meta-prompt)' "AC18: SKILL 정의 문장"
grep -qF 'brainstorming용 meta-prompt' "$SKI" && no "AC18: 옛 「brainstorming용」 정의 잔존" || ok "AC18: 옛 정의 없음(양성 짝: 위 단언)"
# AC19 · AC20
TE="$SD/references/trivia-escape.md"; SB="$SD/agents/steelman-builder.md"; SM="$SD/skills/context-build/references/steelman.md"
TEF="$(flat "$TE")"
grep -qxF '# Trivia Escape — 한 문장 기준' "$TE" && ok "AC19: 머리가 한 문장 기준" || no "AC19: 머리가 다르다"
for lit in '한 문장으로 설명 가능한 사소한 변경이면' '아래 다섯은 그 기준에 드는 흔한 예시다' \
           '목록에 없어도 한 문장으로 설명되는 변경이면 trivia 로 보고' '목록에 들어도 의미가 바뀌는 변경이면 trivia 가 아니다' \
           '**짧은 요청 + 명백히 안전한 syntactic action 동사**' '(보기: 10 토큰 안팎)' '판정 근거: <판정 근거>'; do
  assert_contains "$TEF" "$lit" "AC19: «${lit}»"
done
for old in '<10 토큰' '다섯 중 하나에 해당하면' '맞은 패턴'; do
  grep -qF "$old" "$TE" && no "AC19: 옛 문구 «${old}» 잔존" || ok "AC19: 옛 문구 «${old}» 없음(양성 짝: 위 단언)"
done
for f in "$SD/skills/context-build/SKILL.md" "$SD/skills/intent-sync/SKILL.md"; do
  assert_contains "$(flat "$f")" '그 파일의 기준과 예시로 판정한다' "AC19: ${f##*/skills/} 진입이 기준으로 판정"
  grep -qF '다섯 패턴' "$f" && no "AC19: ${f##*/skills/} 에 「다섯 패턴」 잔존" || ok "AC19: ${f##*/skills/} 「다섯 패턴」 없음"
done
SBF="$(flat "$SB")"
for lit in '보기: landscape 모순 · 알려진 anti-pattern · 기존 사용자 제약과의 충돌. 이 셋에 한정하지 않는다.' \
           '<goal 기준으로 대안이 이기는 케이스 — 길이는 근거가 정한다(보기: 2-4줄)>' \
           '<같은 기준으로 원안이 이기는 케이스 — 길이는 근거가 정한다(보기: 2-4줄)>'; do
  assert_contains "$SBF" "$lit" "AC20: steelman-builder «${lit}»"
done
for old in '충돌 중 하나.' ', 2-4줄>'; do
  grep -qF "$old" "$SB" && no "AC20: steelman-builder 옛 «${old}» 잔존" || ok "AC20: 옛 «${old}» 없음(양성 짝: 위 단언)"
done
assert_contains "$(flat "$SM")" '**trigger** — 기본은 셋이다: landscape 모순 / 알려진 anti-pattern / 기존 사용자 제약과의 충돌. 다른 이유로 방향이 의심되면 모델이 판단해 띄우고 그 이유를 trigger 로 적는다.' "AC20: 인터뷰 쪽 trigger 도 예시"
# 정본 둘째 질문 문단 — 지휘자 아래 승인 질문에는 둘째 질문이 없다(문단 한정: 「기타 칸」 문단의 비슷한 문장과 가른다)
PG2="$(awk 'index($0,"**둘째 질문(선택) — 다음 단계 갈래.**")==1{f=1} f&&!NF{exit} f{print}' "$PG" | tr '\n' ' ')"
[ -n "$PG2" ] && ok "AC17(양성 대조): 정본 둘째 질문 문단을 떴다" || no "AC17: 정본 둘째 질문 문단 부재"
assert_contains "$PG2" '지휘자 아래 승인 질문에는 다음 단계 갈래 질문이 없다(에픽의 흐름은 로드맵 `흐름:` 칸이 정한다) — 둘째 질문으로는 지휘 순환 걸음 3 의 병렬 질문만 붙을 수 있다(`conducting.md`).' "AC17: 둘째 질문 문단이 지휘자 아래엔 없다고 말한다"
assert_not_contains "$PG2" '지휘자 아래 승인 질문에는 둘째 질문이 없다(' "AC17: 옛 둘째 질문 문장은 사라졌다"
# AC25 — 위험 번호를 brief §5 줄에 박는다
DJ="$(win "$FIN" '^### 분해 판단' '^### ')"; SA="$(win "$FIN" '^### Step A ' '^### ')"
BA="$(win "$FIN" '^#### B-A' '^#### ')"; BR="$(win "$RDS" '^## 5[.] 생성' '^## ')"; RDJ="$(win "$RDS" '^## 3[.] 분해안 표' '^## 5[.]')"
[ -n "$DJ" ] && [ -n "$SA" ] && [ -n "$BA" ] && [ -n "$BR" ] && [ -n "$RDJ" ] && ok "AC25(양성 대조): 분해 판단 · Step A · B-A · 생성 · 분해안 표 를 떴다" || no "AC25: 분해 판단 · Step A · B-A · 생성 · 분해안 표 부재"
parab() { awk -v m="$2" 'index($0,m)==1{f=1} f&&!NF{exit} f{print}' "$1" | tr '\n' ' ' | tr -s ' '; }
RISKP="$(parab "$FIN" '   **위험 번호.**')"
assert_contains "$SA" ' **위험 번호.** payload §5 의 위험 줄마다' "AC25: 「위험 번호」 문단이 Step A 안에 있다"
for lit in '`- 위험 K<n> — <숨은 가정 | 실패 양식 | 리뷰 참고> …`' '숨은 가정 · 실패 양식 · 리뷰 참고 순으로 K1 부터 매긴다' \
           '다른 줄의 번호를 고치지 않는다.' \
           '지운 위험의 번호는 다시 쓰지 않는다 — 새로 더하는 위험 줄은 지금까지 나온 가장 큰 K(이 brief 의 §5, 로드맵이 있으면 그 `## 위험 번호표` 와 분해 표의 배정 번호까지)의 다음 수를 받는다.'; do
  assert_contains "$RISKP" "$lit" "AC25: Step A 「위험 번호」 «${lit}»"
done
assert_not_contains "$RISKP" '이 brief 의 가장 큰 K 다음 수' "AC25: Step A 「위험 번호」 에 옛 「이 brief 의 가장 큰 K」 없음(양성 짝: 위 단언)"
assert_contains "$RDJ" '위험 K 는 Step A 가 brief §5 위험 줄에 박을 번호다' "AC25: 분해 표 배정 번호 불릿"
RMT="$SD/templates/roadmap-template.md"
for f in "$FIN" "$RMT"; do
  grep -qF '번호 없는 위험 줄' "$f" && no "AC25: 옛 「번호 없는 위험 줄」 잔존(${f##*/})" || ok "AC25: 옛 「번호 없는 위험 줄」 없음(${f##*/}, 양성 짝: 위 · 아래 단언)"
done
RMTR="$(win "$RMT" '^## 위험 번호표' '^## ')"
for lit in '번호는 brief §5 위험 줄마다 박힌 번호(`- 위험 K<n> — …`)다.' '지운 위험의 번호는 다시 쓰지 않는다.' \
           '번호가 박히지 않은 옛 brief 만 숨은 가정 · 실패 양식 · 리뷰 참고 순으로 줄 순서대로 번호를 달고, 그렇게 매겼다고 알린다.'; do
  assert_contains "$RMTR" "$lit" "AC25: 로드맵 템플릿 「위험 번호표」 «${lit}»"
done
assert_contains "$BA" '`- 위험 K<n> — 리뷰 참고 | [<category>] <anchor> — <summary> (리뷰 <id>)`(`<n>` 은 Step A 「위험 번호」 의 다음 수 — 지운 위험의 번호는 다시 쓰지 않는다)' "AC25: B-A 의 §5 줄 꼴이 Step A 의 번호 규칙을 가리킨다"
assert_not_contains "$BA" '이 brief 의 가장 큰 K 다음 수' "AC25: B-A 에 옛 「이 brief 의 가장 큰 K」 없음(양성 짝: 위 단언)"
# 분해 판단 5 — 로드맵 폴더 이름은 brief 파일 이름에서 도출한다(<주제>-<HHMM> 줄기도)
DJ5="$(parab "$RDS" '5. **기록.**')"
assert_contains "$RDJ" '5. **기록.**' "분해 판단 5 가 roadmap-draft 의 고치기 · 승인 절 안에 있다"
assert_contains "$DJ5" '로드맵 폴더는 `<roadmaps_dir><YYYY-MM-DD>-<주제 또는 주제-HHMM>/` 다(`roadmaps_dir` 은 레포 설정의 로드맵 폴더) — 폴더 이름은 brief 파일 이름(`<줄기>.md`)에서 끝의 `-interview.md` 를 뗀 것, 곧 brief 파일 이름의 날짜 · 주제 부분 그대로다.' "분해 판단 5: 로드맵 폴더 이름을 brief 파일 이름에서 도출"
assert_not_contains "$DJ5" '(brief 와 같은 날짜 · 주제)' "분해 판단 5: 옛 「brief 와 같은 날짜 · 주제」 없음(양성 짝: 위 단언)"
for lit in '사유가 `unassigned` · `orphans` · `unknown_ids` 이거나 `brief 에서 줄을 찾지 못한 번호` 면' \
           '`unknown_ids` 는 표가 brief 에 없는 번호(지운 위험의 K 등)를 배정한 것이다 — 표에서 그 번호를 뺀다.' \
           '`brief 에서 줄을 찾지 못한 번호` 면 그 번호를 brief 에서 찾아 가른다 — brief 에 없으면 `unknown_ids` 와 같이 표에서 뺀다.' \
           'brief 에 있으면 생성기가 그 줄을 읽지 못한 것이다(생성기의 빈틈) — 표를 고치지 않고 그 번호와 사유를 그대로 보이고 아래 「표로 고칠 수 없는 사유」 처럼 멈춘다.' \
           '면 표가 아니라 brief 를 고친다 — 번호 없는 줄에는 메시지가 말한 번호부터 박고(로드맵 `## 위험 번호표` 에 더 큰 K 가 있으면 그다음 수부터), 겹친 번호는 한 줄을 Step A 「위험 번호」 의 다음 수로 바꾼다.' \
           '그다음 Step A 8 의 명령을 한 번만 다시 돌리고 위 갈래대로 가른다 — 또 같은 사유면 아래 「표로 고칠 수 없는 사유」 처럼 멈춘다.'; do
  assert_contains "$BR" "$lit" "AC25: B-R «${lit}»"
done
assert_not_contains "$BR" '`unknown_ids` · `brief 에서 줄을 찾지 못한 번호` 는 표가' "AC25: B-R 이 두 사유를 한데 묶어 표에서 빼지 않는다(양성 짝: 위 단언)"
# B-R 이 brief 를 고치게 하는 위험 번호 사유는 생성기의 글과 같은 글이다
for msg in 'brief §5 위험 줄 가운데 K 번호가 없는 줄이 있다' 'brief §5 위험 줄의 K 번호가 겹친다'; do
  assert_contains "$BR" "\`${msg}\`" "AC25: B-R 이 위험 번호 사유 «${msg}» 를 이름으로 가른다"
  grep -F 'raise FormatError(' "$SD/scripts/roadmap_model.py" | grep -qF "$msg" \
    && ok "AC25: roadmap_model 의 FormatError 글에 «${msg}» 가 있다" || no "AC25: roadmap_model 의 FormatError 글이 B-R 과 다르다(«${msg}»)"
done
# B-R 이 부르는 묶음 그리기 사유는 생성기의 글과 같은 글이다(문서 · 코드가 따로 바뀌지 않게)
NOFIND='brief 에서 줄을 찾지 못한 번호'
assert_contains "$BR" "\`${NOFIND}\` 면" "AC25: B-R 이 묶음 그리기 사유를 이름으로 가른다"
grep -F 'raise TableError(' "$SD/scripts/roadmap_render.py" | grep -qF "$NOFIND" \
  && ok "AC25: roadmap_render 의 TableError 글에 «${NOFIND}» 가 있다" || no "AC25: roadmap_render 의 TableError 글이 B-R 과 다르다"
assert_contains "$BA" '로 적습니다. brief 의 위험 줄에 번호가 없으면(옛 brief) 이 줄도 번호 없이 `- 위험 — 리뷰 참고 | …` 로 쓴다.' "AC25: B-A 옛 brief 는 번호 없이"
TPL5="$(win "$TPL" '^## 5[.]' '^## ')"
for lit in '- 위험 K1 — <숨은 가정 | 실패 양식>: <내용> — <근거>' '- 위험 K2 — 숨은 가정 | <내용> — RC3 (plugins/x/y.py#sym) [RC3 → OQ1]'; do
  assert_contains "$TPL5" "$lit" "AC25: 템플릿 §5 «${lit}»"
done
# 인터뷰 중 §5 위험 줄은 번호 없이 적고 번호는 Step A 가 박는다(섞인 줄은 생성기가 FormatError 로 막는다)
assert_contains "$(flat "$SKI")" '라운드 중에는 번호 없이 적고, brief 를 쓸 때 Step A 가 줄마다 `위험` 바로 뒤에 번호를 박는다(`- 위험 K<n> — …`, `references/finishing.md` 「위험 번호」).' "AC25: 인터뷰 중 위험 줄의 번호는 Step A 가 박는다"
# AC24 — 분해 표의 선택 칸 여섯 · 조사 에픽
DT="$(win "$RDS" '^3[.] [*][*]분해안 표' '^4[.] [*][*]')"
[ -n "$DT" ] && ok "AC24(양성 대조): 분해 판단 3 창을 떴다" || no "AC24: 분해 판단 3 창 부재"
for lit in '칸은 기본 열하나다:' \
           '선택 칸 여섯(크기 · 병렬 · 순서 이유 · 근거 · 흐름 · 산출물)을 더한 열일곱 칸' \
           '쓰지 않는 칸은 「없음」이다' \
           '`${CLAUDE_PLUGIN_ROOT}/references/roadmap-ontology.md` 의 에픽 · 산출물 행' \
           '조사 에픽은 종류 「묶음」에 `흐름` 「조사 — <단계 한 줄>」, `산출물` 에 결과 파일의 레포 상대경로를 쓴다' \
           '「결정」은 산출물 없이 로드맵 결정 기록으로 끝나는 일이다'; do
  assert_contains "$DT" "$lit" "AC24: 분해 판단 3 «${lit}»"
done
assert_not_contains "$DT" '칸은 열하나다:' "AC24: 옛 «칸은 열하나다:» 없음(양성 짝: 위 단언)"
[ -f "$SD/references/roadmap-ontology.md" ] && ok "AC24: 인용한 roadmap-ontology.md 가 있다" || no "AC24: roadmap-ontology.md 부재"
# F4 AC8 · AC14 — 건너뛴 것 보이기(B-2) · 리뷰 뒤 다시 짓기(B-A) · 건너뛴 것을 나중에 돌리는 길(B-S)
BSW="$(win "$FIN" '^#### B-S' '^#### ')"
[ -n "$BSW" ] && ok "F4(양성 대조): B-S 를 떴다" || no "F4: B-S 부재 — 아래가 공허하다"
for lit in '5. **건너뛴 것 <N>개** — `check_brief.py gate` 의 `advisories` 가운데 `건너뜀 — ` 으로 시작하는 줄을 `- <자리>: <이유>` 로 한 줄씩 쓴다.' \
           '이 줄들은 경고(목록 4)에 다시 쓰지 않되 질문의 경고 줄에는 「건너뛴 것 <N>개」 짧은 줄로 잇는다 — 건너뛴 것이 있으면 「이상 없음」 · 「경고 없음」 을 쓰지 않는다.' \
           '「(경고에도 있다)」 를 붙인다. 질문의 경고 줄에서 엔진의 「상태」 줄과 이 짧은 줄이 같은 부품을 함께 말해도 개수를 더하지 않으므로 두 번 세지 않는다.' \
           '그 `건너뜀 — ` 줄은 「건너뛴 것 N개」(목록 5)' \
           '항목 끝에 「하게 하려면 기타 칸에 적는다」 한 줄을 싣는다.' \
           '0개면 이 항목을 쓰지 않는다.' \
           '그 줄 끝에 「— 끄기 스위치가 아니라 모델 판단으로 건너뛰었다」 를 덧붙인다(엔진의 글자는 고치지 않는다).' \
           '**기타 칸 — 건너뛴 것을 하라는 말.** 사용자가 기타 칸에 건너뛴 것을 하라고 적으면 B-S 로 간다.' \
           '그 말이 「여기서 계속」 인지 건너뛴 것을 하라는 것인지 불분명하면 다시 묻는다.'; do
  assert_contains "$B2" "$lit" "F4 AC8: B-2 «${lit}»"
done
assert_not_contains "$B2" '「경고 N개」 에는 센다' "F4 AC8: 건너뛴 것을 경고 개수에 더하라는 옛 문장이 없다(양성 짝: 위 「건너뛴 것 <N>개」 짧은 줄)"
for lit in '적은 뒤 — 적을 참고 항목이 없어도 — audit §2 의 사건 줄을 상태 파일의 `## audit §2 대기 줄` 블록에서 다시 짓고 구조 게이트를 다시 돕니다.' \
           '리뷰가 그 블록에 더한 건너뜀 줄은 여기서 검사에 닿고, B-2 의 게이트 앞 글이 읽는 `advisories` 는 이 실행의 것입니다.' \
           '사유가 「나눈 일은 건너뛸 수 없다」 면 끝 질문을 띄우지 않고 아래 B-S 로 갑니다:'; do
  assert_contains "$BA" "$lit" "F4 AC8: B-A «${lit}»"
done
for lit in '줄은 그 블록에서 지우고 audit §2 를 그 블록에서 다시 짓는다' \
           '그 건너뜀 줄을 대기 줄 블록에서 지우고 Step A.5 의 「조사 계속」 갈래로 간다' \
           '맹점 조사를 건너뛴 차원은 다시 열려 지금 규칙대로 사용자 발화로 닫힌다.' \
           '`reviewing-brief` 를 한 라운드 더 돈다(탐지부터 — 재리뷰 상한에 든다).' \
           '줄만 지우고 audit 을 그대로 두면 그 skill 의 진입 게이트가 옛 audit 으로 구조 게이트를 돌려 나눈 일은 다시 막힌다.' \
           '`reviewing-brief` 의 `## 냉독` 만 돌린 뒤,' \
           '리뷰 라운드를 다시 돌지 않고 재리뷰 상한을 쓰지 않는다.' \
           '리뷰 부품의 줄(재비판 · codex · 읽어 보기)을 전부 지우고 audit §2 를 다시 지은 뒤 리뷰 한 라운드를 돌고, 읽어 보기도 건너뛰었으면 그 라운드 뒤에 돌린다.' \
           '줄 하나만 지우면 남은 줄 때문에 진입 게이트가 다시 막는다.' \
           '「추가 라운드 1회 열기」 질문의 답으로만 연다' \
           '사용자가 열지 않으면 지운 줄을 대기 줄 블록에 그대로 되돌리고 audit §2 를 다시 지은 뒤 끝 질문으로 돌아간다' \
           '`[spec-distill] 나눈 일은 건너뛴 리뷰 부품을 돌려야 끝낼 수 있다 — 추가 라운드를 열거나, 나누지 않기로 하면 그렇게 말해 달라.` 를 보이고 턴을 끝낸다.' \
           '어느 쪽이든 brief 가 바뀌면 리뷰를 다시 지난다 — 바뀐 brief 가 리뷰 없이 끝 질문에 닿지 않는다.' \
           'B-A 의 구조 게이트 펜스를 다시 돌려 그 `advisories` 로 끝 질문 앞 글을 다시 쓰고 끝 질문으로 돌아간다.' \
           '라운드가 끝나면 Step B 를 B-0 부터 다시 돈다(B-A 의 다시 짓기 · 게이트 포함).'; do
  assert_contains "$BSW" "$lit" "F4 AC14: B-S «${lit}»"
done
# 재리뷰 상한이 찬 길의 「추가 라운드 1회 열기」 질문은 B-A 가 표지를 푼 뒤라 질문 재료 펜스를 다시 돌리지 않는다
BS_NOFENCE='이 질문은 B-A 가 표지를 푼 뒤라 질문 재료 펜스를 돌리지 않고, 앞서 받은 「상태」 · 「전문」 줄과 게이트 글(`gate --render`)로 짠다.'
assert_contains "$BSW" "$BS_NOFENCE" "B-S: 재리뷰 상한이 찬 길의 추가 라운드 질문은 질문 재료 펜스를 다시 돌리지 않고 앞서 받은 두 줄과 게이트 글로 짠다"
assert_eq "$(grep -oF -- "$BS_NOFENCE" "$FIN" | wc -l | tr -d ' ')" "1" "B-S: 그 문장은 끝맺음 절차 파일에 한 번만 있다"
assert_contains "$SA" '사유가 「나눈 일은 건너뛸 수 없다」 면 건너뜀 줄만 지워 통과시키지 않는다 — B-S 대로 건너뛴 조사 · 리뷰를 돌린 뒤에 지운다.' "F4 AC14: Step A 의 게이트 걸음이 나눈 일 사유를 줄 지우기로 넘기지 않는다"
# F4 AC10 — superpowers 가 없을 때의 끝 질문: B-0 · B-3 · B-R · B-4 가 새 동작에 맞는다
B0="$(win "$FIN" '^#### B-0' '^#### ')"; B4="$(win "$FIN" '^#### B-4' '^#### ')"
[ -n "$B0" ] && [ -n "$B4" ] && ok "F4(양성 대조): B-0 · B-4 를 떴다" || no "F4: B-0 · B-4 부재 — 아래가 공허하다"
assert_contains "$B0" '얻음: 지금 확정 후보를 확정으로 바꾸고 왔던 끝 질문으로 돌아가 끝낼 길을 고른다' "F4: 재제시 상한 질문의 「지금 목록으로 확정」 설명이 왔던 끝 질문으로 돌아간다고 말한다"
assert_contains "$B3" '왔던 끝 질문(B-2 게이트 — superpowers 가 없어 B-1 의 끝 질문에서 왔으면 그 끝 질문)을 다시 띄우며' "F4: 「지금 목록으로 확정」 이 돌아갈 자리"
assert_not_contains "$B0$B3" 'B-2 게이트를 다시 띄운다 — 다음 단계는 그 게이트에서 고른다' "F4: 옛 「B-2 게이트를 다시 띄운다」 가 없다(양성 짝: 위 두 단언)"
assert_contains "$BR" 'B-1 끝 질문의 「확정하고 끝낸다」 · 「brief만 종료」 — 「지금 목록으로 확정」은 왔던 끝 질문으로 돌아가 그 질문의 갈래에서 한 번 돈다' "F4 AC10: B-R 의 갈래 목록에 끝 질문의 두 갈래"
assert_contains "$BR" '(B-1 끝 질문의 「확정하고 끝낸다」 · 「brief만 종료」 도 같은 펜스로 커밋한다)' "F4 AC10: 끝 질문의 두 갈래도 커밋한다"
assert_not_contains "$BR" 'B-1 은 커밋하지 않고' "F4 AC10: 옛 「B-1 은 커밋하지 않고」 가 없다(양성 짝: 위 단언)"
assert_contains "$B4" '(b) superpowers 가 없을 때의 B-1 끝 질문 (선택지 셋)을 거친다 — 질문 없는 **silent 종료 금지**.' "F4 AC10: Step B 를 끝내는 경로는 proceed 게이트와 B-1 끝 질문 둘이다"
assert_not_contains "$B4" '게이트를 거치지 않는 예외' "F4 AC10: 옛 「게이트를 거치지 않는 예외」 가 없다(양성 짝: 위 단언)"
assert_contains "$B2" '선택지 넷의 개수 · 순서 · `(권장)` 은 어느 경우든 그대로' "F4 AC10: B-2 게이트의 선택지 넷 문장은 그대로다"
# F4 AC10 — 옛 B-1(멈춤 · 미커밋)을 말하던 B-0 · B-3 의 문장이 새 끝 질문에 맞는다
[ -n "$B0" ] && [ -n "$B3" ] && ok "F4(양성 대조): B-0 · B-3 창이 비어 있지 않다" || no "F4: B-0 · B-3 창이 비었다 — 아래가 공허하다"
assert_contains "$B0" '또는 superpowers 가 없을 때 B-1 끝 질문의 「확정하고 끝낸다」 를 고를 때만 일어납니다.' "F4 AC10: B-0 의 확정 전이는 B-2 의 ①/② 와 B-1 끝 질문의 「확정하고 끝낸다」 둘로만 일어난다"
assert_not_contains "$B0" '확정-후-진행 옵션(①/②)을 고를 때만 일어납니다' "F4 AC10: B-0 에 B-1 구절 없는 옛 확정 전이 문장이 없다(양성 짝: 위 단언)"
assert_not_contains "$(cat "$FIN")" 'B-1 부재 advisory와 같은 톤' "F4 AC10: ④ 에 끊긴 「B-1 부재 advisory」 가리킴이 없다"
assert_contains "$B3" 'brief terminal advisory를 내고 종료. handoff 안 함.' "F4 AC10: ④ 의 남은 글은 그대로다(양성 짝: 위 부재 단언)"
assert_contains "$B3" '게이트(①/②)나 B-1 끝 질문의 「확정하고 끝낸다」 를 통해서만 바뀐다' "F4 AC10: ③ 의 status 변경 경로에 B-1 끝 질문이 든다"
assert_contains "$B3" '**끝내기 커밋 — ①/② 는 게이트 재실행 통과 · B-R 다시 생성 뒤 두 줄 노출 전, B-1 끝 질문의 「확정하고 끝낸다」 는 확정 반영 · 게이트 재실행 통과 · 나눈 일이면 B-R 다시 생성 뒤 끝 안내 전, ④ 와 B-1 의 「brief만 종료」 는 종료 안내 직전, 한 번.**' "F4 AC10: 끝내기 커밋 문장이 B-1 의 때를 말한다"
# CHANGELOG · README — 사람에게 보이는 글은 내부 단계 이름 대신 쉬운 말로
CL="$SD/CHANGELOG.md"; RD="$SD/README.md"
assert_contains "$(flat "$CL")" '- 같이 쓰는 진행 게이트의 정본(`references/proceed-gate.md`)의 둘째 질문 문단에, 지휘자 아래 승인 질문에는 둘째 질문이 없다는 문장을 더했다.' "CHANGELOG: 둘째 질문은 같이 쓰는 진행 게이트의 정본에"
assert_contains "$(flat "$CL")" '- 로드맵을 다시 만드는 단계가 「brief 에서 줄을 찾지 못한 번호」 로 멈추면, 그 번호가 brief 에 없을 때만 분해 표에서 뺀다.' "CHANGELOG: 다시 만드는 단계를 쉬운 말로"
for old in '인터뷰 끝 게이트의 정본에 선택 질문' 'B-R 이 묶음 에픽의'; do
  grep -qF "$old" "$CL" && no "CHANGELOG: 옛 «${old}» 잔존" || ok "CHANGELOG: 옛 «${old}» 없음(양성 짝: 위 단언)"
done
assert_contains "$(flat "$RD")" '인터뷰 끝 게이트는 하나짜리 brief 에서 둘째 질문으로 다른 다음 단계를 고를 수 있고' "README: 「하나짜리 brief 에서」"
grep -qF '하나짜리 brief 에서도' "$RD" && no "README: 옛 「에서도」 잔존" || ok "README: 옛 「에서도」 없음(양성 짝: 위 단언)"
finish
