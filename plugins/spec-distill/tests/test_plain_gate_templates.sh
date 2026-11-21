#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/*/SKILL.md plugins/spec-distill/skills/pm-interview/references/finishing.md plugins/spec-distill/references/proceed-gate.md shared/docreview/references/reviewing-document.md plugins/spec-distill/references/conducting.md
#
# 쉬운 말 출력 설계 §4 · AC7 — 모든 게이트 질문은 결정 하나와 상태 한 줄만 담고, 경고 목록은 앞 글에 쓴다.
# 「채널을 읽은 뒤에만 없음을 쓴다」 계약은 그대로 남는다.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  git -C "$REPO_ROOT" ls-files -- 'plugins/spec-distill/skills/*/SKILL.md' \
    plugins/spec-distill/skills/pm-interview/references/finishing.md plugins/spec-distill/references/proceed-gate.md \
    shared/docreview/references/reviewing-document.md plugins/spec-distill/references/conducting.md
  exit 0
fi
. "$REPO_ROOT/shared/tests/assert.sh"
SD="$REPO_ROOT/plugins/spec-distill"
FIN="$SD/skills/pm-interview/references/finishing.md"
RS="$SD/skills/spec-review/SKILL.md"
RB="$SD/skills/reviewing-brief/SKILL.md"
FR="$SD/skills/request-framing/SKILL.md"
PG="$SD/references/proceed-gate.md"

# ① 머리글 「Proceed」가 없다(spec-distill 어디에도).
n="$(grep -rF -- 'header: "Proceed"' "$SD/skills" "$SD/references" | grep -c . || true)"
assert_eq "$n" "0" "AC7: 게이트 머리글이 「Proceed」가 아니다"
assert_file_grep "$FIN" 'header: "다음 단계"' "AC7 양의 짝: B-2 머리글이 「다음 단계」다"

# ② B-2 질문 한 줄이 경고 목록 대신 경고 줄 하나와 「전문」 줄만 싣는다.
QLINE="$(awk '/^#### B-2/{f=1} f && /^[[:space:]]*question:/{print; exit}' "$FIN")"
[ -n "$QLINE" ] && ok "B-2 question 줄을 찾았다" || no "B-2 question 줄이 없다 — 아래 단언이 공허하다"
assert_contains "$QLINE" '경고 줄 — 채널마다의 짧은 줄' "AC7: B-2 질문이 경고를 채널마다의 짧은 줄을 이은 한 줄로 싣는다"
assert_contains "$QLINE" '전문: <경로>' "AC7: B-2 질문이 「전문」 줄 자리를 싣는다"
assert_not_contains "$QLINE" 'degrade:' "AC7: B-2 질문이 degrade 줄 목록 자리를 싣지 않는다"
assert_not_contains "$QLINE" '게이트 advisory:' "AC7: B-2 질문이 advisory 목록 자리를 싣지 않는다"

# ③ 경고는 앞 글로 — 채택 skill 의 degrade 자리가 「게이트 앞 글」을 이름으로 댄다.
for f in "$FIN" "$RS" "$RB" "$FR" "$PG"; do
  assert_file_grep "$f" '게이트 앞 글' "AC7: $(basename "$(dirname "$f")")/$(basename "$f") 가 경고를 게이트 앞 글에 쓰라고 지시한다"
done

# ④ 「채널을 읽은 뒤에만 없음」 문장이 넷 모두에 남는다.
for f in "$FIN" "$RS" "$RB" "$FR"; do
  assert_file_grep "$f" '실제로 읽었다는 주장' "AC7: $(basename "$(dirname "$f")") 에 「채널을 실제로 읽었다는 주장」 문장이 있다"
done

# ⑤ 「이상 없음」·「경고 없음」 구분(설계 표 7874b3bb#r2.1).
assert_file_grep "$PG" '남은 항목도 없으면 「이상 없음」' "Q1: 정본이 「이상 없음」을 남은 항목도 없을 때로 한정한다"
assert_file_grep "$PG" '「경고 없음」' "Q1: 정본이 「경고 없음」을 말한다"

# ⑥ 다음 세션 줄이 규칙 유지 문장을 싣는다 — 표지 블록의 한 줄에서 재고, 그 구절은 파일에 한 곳뿐이다.
nsl() { awk -v m='**다음 세션 줄 — ①/② 공통**' '$0==m{f=1;next} f&&NF{print;exit}' "$1"; }
# brainstorming 으로 넘기는 줄(finishing.md)은 지시 파일을 가리키고, 낱말 규칙 문장은 그 파일의 두 절에 한 줄씩 산다(F4 AC1 · AC2).
BHF="$(dirname "$PG")/brief-handoff.md"
phrase='사람에게 쓰는 글의 낱말 규칙'
l="$(nsl "$FIN")"
[ -n "$l" ] && ok "AC7(양성): finishing.md 의 다음 세션 줄을 읽었다" || no "AC7(양성): finishing.md 에 다음 세션 줄 표지 블록이 없다 — 아래 단언이 공허하다"
assert_contains "$l" '/references/brief-handoff.md 의 ## brainstorming 지시 절을 읽고 그 지시를 따른다' "F4 AC1: finishing.md 의 다음 세션 줄이 지시 파일의 절을 가리킨다"
assert_eq "$(grep -c "${phrase}(번호·해시는" "$FIN" || true)" "0" "F4 AC1: finishing.md 는 낱말 규칙 문장을 글자로 싣지 않는다(양성 짝: 아래 지시 파일 단언)"
assert_eq "$(grep -c "^- ${phrase}(번호·해시는" "$BHF" || true)" "2" "F4 AC2: 지시 파일에서 그 구절이 든 줄은 정확히 2개다(두 절에 하나씩)"
for sec in 'brainstorming 지시' '공통 지시'; do
  n="$(awk -v h="## ${sec}" '$0==h{f=1;next} f&&/^## /{exit} f' "$BHF" | grep -c "^- ${phrase}(번호·해시는" || true)"
  assert_eq "$n" "1" "F4 AC2: 지시 파일의 「${sec}」 절이 규칙 유지 문장을 한 줄 싣는다"
done
f="$RS"; rphrase='사람에게 쓰는 글 규칙'
l="$(nsl "$f")"; who="${f#"$REPO_ROOT"/}"
[ -n "$l" ] && ok "AC7(양성): ${who} 의 다음 세션 줄을 읽었다" || no "AC7(양성): ${who} 에 다음 세션 줄 표지 블록이 없다 — 아래 단언이 공허하다"
assert_eq "$(printf '%s' "$l" | grep -oF "$rphrase" | wc -l | tr -d ' ')" "1" "AC7: ${who} 의 다음 세션 줄이 규칙 유지 문장을 싣는다"
assert_eq "$(grep -E '^> `' "$f" | grep -c "${rphrase}(번호·해시는" || true)" "1" "AC7: ${who} 에서 그 구절은 인용 줄(다음 세션 줄) 한 곳뿐이다"
assert_eq "$(grep -c "${rphrase}(번호·해시는" "$f" || true)" "1" "AC7: ${who} 에서 그 구절이 든 줄은 정확히 1개다"
OTHER="$(awk -v m='**다른 다음 단계의 줄 — 둘째 질문에서 제안을 골랐을 때.**' 'index($0,m)==1{print}' "$FIN")"
[ -n "$OTHER" ] && ok "AC7(양성): finishing.md 의 「다른 다음 단계의 줄」 문단을 읽었다" || no "AC7(양성): 「다른 다음 단계의 줄」 문단 부재"
assert_contains "$OTHER" '/references/brief-handoff.md 의 ## 공통 지시 절을 읽고 그 지시를 따른다' "F4 AC3: 「다른 다음 단계의 줄」 문단이 공통 지시 절을 가리킨다"
assert_not_contains "$(nsl "$FIN")" '첫 줄에 상태, 끝에 할 일 하나' "지휘자 수리 2: brainstorming 으로 넘기는 줄은 메시지 순서 규칙을 싣지 않는다(양성 짝: 지시 파일 단언)"
# 꺾쇠 자리표는 줄 앞 `@<…>` 토큰에만 있다 — 목록 원소가 늘어도 통과한다(설계 G3).
RSC="$(nsl "$RS" | sed -e 's/^> `//' -e 's/`$//')"
assert_eq "$(LINE="$RSC" python3 -c '
import os, re
l = os.environ["LINE"]
m = re.match(r"((?:@<[^<>]+> )+)", l)
names = set(re.findall(r"@<([^<>]+)>", m.group(1))) if m else set()
rest = re.findall(r"<([^<>]+)>", l[m.end():]) if m else ["x"]
print("ok" if m and all(x in names for x in rest) else "no")')" "ok" "Review Focus 4: spec-review 다음 세션 줄의 꺾쇠 자리표는 줄 앞 @<…> 토큰의 이름만 쓴다"

# ⑦ request-framing 의 옛 채널 이름이 남지 않는다(처분 앵커 포함).
FR_FLAT="$(tr '\n' ' ' < "$FR" | tr -s ' ')"
assert_eq "$(printf '%s' "$FR_FLAT" | grep -oE '게이트 질문 텍스트|게이트 텍스트' | wc -l | tr -d ' ')" "0" "Q3: request-framing 에 옛 채널 이름(「게이트 질문 텍스트」·「게이트 텍스트」)이 줄바꿈을 접어도 없다"
assert_file_grep "$FR" 'disclosure=proceed 게이트 앞 글' "Q3 양의 짝: 처분 앵커가 새 이름을 댄다"

# ⑧ 질문에 그대로 남는 예외가 명시돼 있다(Q4).
assert_file_absent "$FR" '규칙 블록의 「따로 정한 자리」' "Q4: 저자 편집 덩어리를 질문에 그대로 싣는 예외가 없다"
assert_file_grep "$FR" '공시 펜스가 낸 화면 글은 게이트 앞 글에 그대로 한 번 싣는다' "Q4 양의 짝: 저자 편집 화면은 게이트 앞 글에 싣고 질문 본문에는 결정 한 줄만 둔다"

# ⑨ 게이트 질문의 경고 줄은 엔진의 상태 줄을 잇는다 — 렌더 첫 줄은 같은 사실의 원문들을 한 줄로 합쳐 사실을 세므로
#    앞 글에 `advisory[]` 원문을 다시 늘어놓으면 질문의 경고 줄과 앞 글의 줄 수가 갈린다(계획 Q9). 줄바꿈을 접어 잰다.
for f in "$RS" "$RB" "$FR" "$FIN"; do
  flat="$(tr '\n' ' ' < "$f" | tr -s ' ')"
  assert_eq "$(printf '%s' "$flat" | grep -oF '질문의 경고 줄은 엔진의 상태 줄과 다른 채널의 짧은 줄을 이은 것이다 — 개수를 더하지 않는다.' | wc -l | tr -d ' ')" "1" \
    "Q9: $(basename "$(dirname "$f")") 가 질문의 경고 줄을 엔진의 상태 줄과 다른 채널의 짧은 줄을 이은 것으로 정한다"
  assert_eq "$(printf '%s' "$flat" | grep -oF '`advisory[]` 원문을 다시 늘어놓지 않' | wc -l | tr -d ' ')" "1" \
    "Q9: $(basename "$(dirname "$f")") 가 앞 글에 advisory 원문을 다시 늘어놓지 않는다고 적는다"
done

# ⑩~⑮ 는 줄바꿈·들여쓰기를 접은 본문에서 잰다. 자리마다 문장 앞뒤 글자를 함께 잡아 「정확히 한 번 · 그 자리」를 잰다.
RD="$REPO_ROOT/shared/docreview/references/reviewing-document.md"
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }
cnt() { printf '%s' "$1" | grep -oF -- "$2" | wc -l | tr -d ' '; }
F_RS="$(flat "$RS")"; F_RB="$(flat "$RB")"; F_FR="$(flat "$FR")"; F_FIN="$(flat "$FIN")"; F_PG="$(flat "$PG")"; F_RD="$(flat "$RD")"

# ⑩ 게이트 질문의 본문 규칙(최종 리뷰 I1) — 라운드 게이트(8단계)와 승인(다음 단계) 게이트는 규칙이 다르다.
# 라운드 게이트의 질문 본문은 엔진의 질문 재료가 정한다 — 진입 skill 셋은 S1, 절차서는 STEP8.
# 승인 게이트의 본문 규칙은 정본(`proceed-gate.md`)이 정하고(PGBODY) 나머지 자리는 그 정본을 가리킨다(PGREF).
S1='질문 본문은 엔진의 질문 재료가 낸 「본문」 · 「상태」 · 「덧줄」 · 「전문」 줄을 그대로 싣고, 선택지 설명 · 줄일 때의 규칙 넷 · 기타 칸의 「전문」은 절차서 8단계대로 한다 — 질문을 띄우기 직전마다 아래 질문 재료 펜스를 돈다.'
STEP8='질문마다 엔진의 질문 재료(`docreview_state.py ask-material`) 한 묶음을 쓴다.'
for v in F_RS F_RB F_FR; do
  t="${!v}"
  assert_eq "$(cnt "$t" "$S1")" "1" "I1: ${v} 에 라운드 게이트(8단계) 질문 본문 문장이 한 번 있다"
  assert_eq "$(cnt "$t" "첫 호출 **앞 글**에 한 번 쓴다. ${S1}")" "1" "I1: ${v} 의 8단계 렌더 첫 줄 문장 바로 뒤에 그 문장이 있다"
done
assert_eq "$(cnt "$F_RD" "첫 호출 **앞 글**에 한 번 쓴다. 질문은 질문 창만 보고 고를 수 있게 싣는다 — ${STEP8}")" "1" "I1: F_RD 의 8단계 렌더 첫 줄 문장 바로 뒤에 질문 재료 문장이 있다"
PGBODY='질문 본문에는 결정 하나, 경고 줄 하나, 「전문: <경로>」 한 줄을 둔다.'
PGREF='정본(`proceed-gate.md`)의 본문 규칙대로'
assert_eq "$(cnt "$F_PG" "$PGBODY")" "1" "I1: 정본(proceed-gate.md)에 승인 게이트의 질문 본문 규칙이 한 번 있다"
assert_eq "$(cnt "$F_PG" "선택지 넷의 설명은 위 표의 얻음 · 내줌 꼴이다. 머리글은")" "1" "I1: 정본의 본문 규칙이 선택지 설명을 표로 가리키고 머리글 문장으로 이어진다"
assert_eq "$(cnt "$F_RS" "읽지 않은 채 쓰지 않는다. ${S1}")" "0" "I1: spec-review 승인 게이트 문단에 라운드 게이트 문장이 들어가지 않는다"
assert_eq "$(cnt "$F_RS" "승인 게이트 질문의 본문은 ${PGREF} 싣는다.")" "1" "I1: spec-review 승인 게이트 문단이 정본의 본문 규칙을 가리킨다"
assert_eq "$(cnt "$F_RB" "$PGREF")" "1" "I1: reviewing-brief Step B 문단이 정본의 본문 규칙을 가리킨다"
assert_eq "$(cnt "$F_FR" "$PGREF")" "1" "I1: request-framing 확정 게이트 문단이 정본의 본문 규칙을 가리킨다"
assert_eq "$(cnt "$F_FIN" "$PGREF")" "1" "I1: finishing B-2 가 정본의 본문 규칙을 가리킨다"

# ⑪ 질문의 경고 줄은 엔진의 상태 줄과 다른 채널의 짧은 줄을 이은 것이다 — 개수를 더하지 않는다(최종 리뷰 I2).
S2='렌더 첫 줄의 끝 문구(이상 없음 · 경고 없음 · 경고 K개)는 문서 리뷰 엔진 몫의 결론이다.'
S3='질문의 경고 줄은 엔진의 상태 줄과 다른 채널의 짧은 줄을 이은 것이다 — 개수를 더하지 않는다.'
assert_eq "$(cnt "$F_FIN" "$S3 ${S2} 다른 채널에 경고가 있으면")" "1" "I2: finishing 이 이은 줄 문장 바로 뒤에 엔진 몫 문장을 둔다"
assert_eq "$(cnt "$F_RB" "$S3 ${S2} 다른 채널에 경고가 있으면")" "1" "I2: reviewing-brief 가 이은 줄 문장 바로 뒤에 엔진 몫 문장을 둔다"
assert_eq "$(cnt "$F_FR" "$S3 ${S2} 다른 채널에 경고가 있으면")" "1" "I2: request-framing 이 이은 줄 문장 바로 뒤에 엔진 몫 문장을 둔다"
assert_eq "$(cnt "$F_RS" "$S3")" "1" "I2: spec-review 가 이은 줄 문장을 한 번 둔다"
for v in F_FIN F_RB F_FR F_RS; do
  t="${!v}"
  assert_eq "$(cnt "$t" "$S2")" "$([ "$v" = F_RS ] && echo 0 || echo 1)" "I2: ${v} 의 엔진 몫 문장 수"
  assert_eq "$(printf '%s' "$t" | grep -oE '그 위에 더|엔진 K \+ 그 밖의 M|경고 N개 — 위에 적었다|「경고 N개」에 (더|넣)' | wc -l | tr -d ' ')" "0" "I2: ${v} 에 개수를 더하라는 옛 문장이 없다"
done
# 같은 옛 이름을 인용하는 지휘 절차도 본다(마지막 전체 리뷰 M3) — 양의 짝은 그 자리의 새 문장.
CD="$SD/references/conducting.md"
assert_eq "$(grep -oE '그 위에 더|엔진 K \+ 그 밖의 M|경고 N개 — 위에 적었다|「경고 N개」에 (더|넣)' "$CD" | wc -l | tr -d ' ')" "0" "M3: conducting.md 에 「경고 N개」에 더하라는 옛 문장이 없다"
assert_eq "$(grep -cF '검사 불가는 막지 않고 승인 질문의 경고 줄에 번호 대조의 짧은 줄로 이어진다' "$CD")" "1" "M3 양의 짝: conducting.md 의 번호 대조 경고가 승인 질문의 경고 줄로 간다"

# ⑫ 「이상 없음」·「경고 없음」 구분과 그 조건(「…때만」) — 파일마다 실제 글자. reviewing-document.md 에는 이 구분 문장이 없다.
assert_eq "$(cnt "$F_RS" '셋 다 비었을 때만, 남은 항목도 없으면 「이상 없음」, 있으면 「경고 없음」이다 — 그 문구는')" "1" "구분: spec-review 승인 게이트의 「셋 다 비었을 때만」 구분"
assert_eq "$(cnt "$F_RS" '남은 것은 있고 경고가 없으면 「경고 없음」, 남은 것도 경고도 없으면 「이상 없음」이 온다.')" "1" "구분: spec-review 가 첫 줄의 두 문구를 가른다"
assert_eq "$(cnt "$F_RB" '전부 비었을 때만, 남은 항목도 없으면 「이상 없음」, 있으면 「경고 없음」이다 — 그 문구는')" "1" "구분: reviewing-brief 의 「전부 비었을 때만」 구분"
assert_eq "$(cnt "$F_FIN" '남은 항목(위 3)도 없을 때만 「이상 없음」, 남은 항목이 있으면 「경고 없음」 한 줄이다.')" "1" "구분: finishing 목록 4 의 「없을 때만」 구분"
assert_eq "$(cnt "$F_PG" '채널을 다 읽었는데 경고가 없으면, 남은 항목도 없으면 「이상 없음」, 남은 항목이 있으면 「경고 없음」 한 줄이다 — 침묵과')" "1" "구분: 정본의 이상 없음/경고 없음 구분"
assert_eq "$(cnt "$F_FR" '경고가 없을 때의 두 문구는 **채널을 실제로 읽었다는 주장**이라 읽지 않은 채 쓰지 않습니다.')" "1" "구분: request-framing 이 경고 없을 때의 두 문구를 읽은 뒤에만 쓴다"

# ⑬ 질문 본문의 규칙 — 라운드 게이트는 STEP8, 승인 게이트는 정본 한 곳과 그것을 가리키는 자리들(M5 · M7).
assert_eq "$(cnt "$F_RD" "$STEP8")" "1" "질문 본문: F_RD 의 라운드 게이트 질문 규칙"
assert_eq "$(cnt "$F_RS" "$PGREF")" "1" "질문 본문: spec-review 는 degrade 채널 끝 문단에서만 정본을 가리킨다"
assert_eq "$(cnt "$F_FIN" '질문 본문에는 결정 하나와 경고 줄 · 「전문」 줄을 정본(`proceed-gate.md`)의 본문 규칙대로 싣습니다.')" "1" "질문 본문: finishing B-2"
for v in F_RS F_RB F_FR F_FIN F_PG F_RD; do
  t="${!v}"
  assert_eq "$(printf '%s' "$t" | grep -oE '질문[^.]*한 줄씩|한 줄씩[^.]*질문' | wc -l | tr -d ' ')" "0" \
    "질문 본문: ${v} 에 경고를 질문에 한 줄씩 싣는 문장이 없다(위 양의 짝과 함께)"
done

# ⑭ finishing — degrade record 는 앞 글에 한 줄씩, 질문 본문은 정본의 규칙대로(M11).
assert_eq "$(cnt "$F_FIN" '모든 degrade record 는 **게이트 앞 글**(위 목록 4)에 한 줄씩 씁니다. 질문 본문에는')" "1" \
  "finishing: degrade record 는 앞 글에 쓰고 질문 본문은 정본의 규칙을 따른다"
assert_eq "$(cnt "$F_FIN" '옵션 description 에 싣지 않습니다')" "0" "finishing: 옵션 description 에 경고를 싣지 않는다는 옛 문장이 없다(설명은 얻음 · 내줌 꼴)"

# ⑭b finishing — 인터뷰 끝 게이트의 짧은 줄 출처(brief 원장 · 구조 검사 참고).
for ph in '`brief_review_state.py short "$STATE" --fallback-file "$DEGRADE_FALLBACK_FILE"`' '「구조 검사 참고 N개」'; do
  assert_eq "$(cnt "$F_FIN" "$ph")" "1" "finishing: 짧은 줄 출처 ${ph}"
done

# ⑮ 읽지 못한 채널은 「알 수 없음 — <사유>」 한 줄(M3 · M4).
assert_eq "$(cnt "$F_FIN" '읽지 못한 채널은 「알 수 없음 — <사유>」 로 따로 한 줄 쓴다.')" "1" "알 수 없음: finishing 목록 4"
assert_eq "$(cnt "$F_PG" '읽지 못한 채널은 「알 수 없음 — <사유>」로 따로 쓴다.')" "1" "알 수 없음: 정본"
finish
