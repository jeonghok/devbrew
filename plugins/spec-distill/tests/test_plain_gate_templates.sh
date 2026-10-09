#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/*/SKILL.md plugins/spec-distill/skills/spec-interview/references/finishing.md plugins/spec-distill/references/proceed-gate.md shared/docreview/references/reviewing-document.md
#
# 쉬운 말 출력 설계 §4 · AC7 — 모든 게이트 질문은 결정 하나와 상태 한 줄만 담고, 경고 목록은 앞 글에 쓴다.
# 「채널을 읽은 뒤에만 없음을 쓴다」 계약은 그대로 남는다.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  git -C "$REPO_ROOT" ls-files -- 'plugins/spec-distill/skills/*/SKILL.md' \
    plugins/spec-distill/skills/spec-interview/references/finishing.md plugins/spec-distill/references/proceed-gate.md \
    shared/docreview/references/reviewing-document.md
  exit 0
fi
. "$REPO_ROOT/shared/tests/assert.sh"
SD="$REPO_ROOT/plugins/spec-distill"
FIN="$SD/skills/spec-interview/references/finishing.md"
RS="$SD/skills/spec-review/SKILL.md"
RB="$SD/skills/reviewing-brief/SKILL.md"
FR="$SD/skills/request-framing/SKILL.md"
PG="$SD/references/proceed-gate.md"

# ① 머리글 「Proceed」가 없다(spec-distill 어디에도).
n="$(grep -rF -- 'header: "Proceed"' "$SD/skills" "$SD/references" | grep -c . || true)"
assert_eq "$n" "0" "AC7: 게이트 머리글이 「Proceed」가 아니다"
assert_file_grep "$FIN" 'header: "다음 단계"' "AC7 양의 짝: B-2 머리글이 「다음 단계」다"

# ② B-2 질문 한 줄이 경고 목록 대신 개수 한 줄만 싣는다.
QLINE="$(awk '/^#### B-2/{f=1} f && /^[[:space:]]*question:/{print; exit}' "$FIN")"
[ -n "$QLINE" ] && ok "B-2 question 줄을 찾았다" || no "B-2 question 줄이 없다 — 아래 단언이 공허하다"
assert_contains "$QLINE" '위에 적었다' "AC7: B-2 질문이 경고를 「경고 N개 — 위에 적었다」 한 줄로 가리킨다"
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

# ⑥ 핸드오프 /compact 틀 둘이 규칙 유지 문장을 싣는다.
for f in "$FIN" "$RS"; do
  assert_eq "$(grep -c '/compact .*사람에게 쓰는 글 규칙' "$f" || true)" "1" "AC7: $(basename "$(dirname "$f")") 의 /compact 틀이 규칙 유지 문장을 싣는다"
done
RSC="$(grep '/compact 설계문서' "$RS" || true)"
assert_eq "$(printf '%s' "$RSC" | grep -oE '<[^>]+>' | sort -u | tr '\n' ' ')" "<spec_path> " "Review Focus 4: spec-review /compact 틀의 꺾쇠 자리표가 <spec_path> 하나다"

# ⑦ request-framing 의 옛 채널 이름이 남지 않는다(처분 앵커 포함).
FR_FLAT="$(tr '\n' ' ' < "$FR" | tr -s ' ')"
assert_eq "$(printf '%s' "$FR_FLAT" | grep -oE '게이트 질문 텍스트|게이트 텍스트' | wc -l | tr -d ' ')" "0" "Q3: request-framing 에 옛 채널 이름(「게이트 질문 텍스트」·「게이트 텍스트」)이 줄바꿈을 접어도 없다"
assert_file_grep "$FR" 'disclosure=proceed 게이트 앞 글' "Q3 양의 짝: 처분 앵커가 새 이름을 댄다"

# ⑧ 질문에 그대로 남는 예외가 명시돼 있다(Q4).
assert_file_grep "$FR" '규칙 블록의 「따로 정한 자리」' "Q4: 저자 편집 덩어리를 질문에 그대로 싣는 것이 예외라고 적혀 있다"

# ⑨ 게이트 질문의 「경고 N개」는 렌더 첫 줄의 N 이다 — 첫 줄은 같은 사실의 원문들을 한 줄로 합쳐 사실을 세므로
#    앞 글에 `advisory[]` 원문을 다시 늘어놓으면 질문의 N 과 앞 글의 줄 수가 갈린다(계획 Q9). 줄바꿈을 접어 잰다.
for f in "$RS" "$RB" "$FR" "$FIN"; do
  flat="$(tr '\n' ' ' < "$f" | tr -s ' ')"
  assert_eq "$(printf '%s' "$flat" | grep -oF '렌더 첫 줄의 N 이' | wc -l | tr -d ' ')" "1" \
    "Q9: $(basename "$(dirname "$f")") 가 질문의 경고 수를 렌더 첫 줄의 N 으로 정한다"
  assert_eq "$(printf '%s' "$flat" | grep -oF '`advisory[]` 원문을 다시 늘어놓지 않' | wc -l | tr -d ' ')" "1" \
    "Q9: $(basename "$(dirname "$f")") 가 앞 글에 advisory 원문을 다시 늘어놓지 않는다고 적는다"
done

# ⑩~⑮ 는 줄바꿈·들여쓰기를 접은 본문에서 잰다. 자리마다 문장 앞뒤 글자를 함께 잡아 「정확히 한 번 · 그 자리」를 잰다.
RD="$REPO_ROOT/shared/docreview/references/reviewing-document.md"
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }
cnt() { printf '%s' "$1" | grep -oF -- "$2" | wc -l | tr -d ' '; }
F_RS="$(flat "$RS")"; F_RB="$(flat "$RB")"; F_FR="$(flat "$FR")"; F_FIN="$(flat "$FIN")"; F_PG="$(flat "$PG")"; F_RD="$(flat "$RD")"

# ⑩ 「미검증」·라운드 미완이면 질문의 상태 줄이 그 공시다(최종 리뷰 I1) — 게이트 질문을 정하는 여덟 자리에 같은 글자로.
S1='「미검증」이거나 리뷰를 마치지 못한 라운드면 질문의 상태 줄은 렌더 첫 줄의 첫 문장(그 공시)이고, 「이상 없음」·「경고 없음」은 쓰지 않는다. 경고가 있으면 그 뒤에 「경고 N개 — 위에 적었다」를 붙인다.'
STEP8='질문 본문에는 그 질문의 결정 하나와, 경고가 있으면 「경고 N개 — 위에 적었다」 한 줄만 둔다.'
for v in F_RS:2 F_RB:2 F_FR:2 F_PG:1 F_RD:1; do
  n="${v%%:*}"; t="${!n}"
  assert_eq "$(cnt "$t" "$S1")" "${v##*:}" "I1: ${v%%:*} 에 미검증 라운드의 질문 상태 줄 문장이 ${v##*:}번 있다"
done
for v in F_RS F_RB F_FR F_RD; do
  t="${!v}"
  assert_eq "$(cnt "$t" "${STEP8} ${S1}")" "1" "I1: ${v} 의 라운드 게이트(8단계) 질문 규칙 바로 뒤에 그 문장이 있다"
done
assert_eq "$(cnt "$F_RS" "읽지 않은 채 쓰지 않는다. ${S1}")" "1" "I1: spec-review 승인 게이트 문단 끝에 그 문장이 있다"
assert_eq "$(cnt "$F_RB" "읽지 않은 채 쓰지 않는다. ${S1}")" "1" "I1: reviewing-brief Step B 문단에 그 문장이 있다"
assert_eq "$(cnt "$F_FR" "읽지 않은 채 쓰지 않습니다. ${S1}")" "1" "I1: request-framing 확정 게이트 문단에 그 문장이 있다"
assert_eq "$(cnt "$F_PG" "한 줄만 둔다. ${S1} 머리글은")" "1" "I1: 정본의 질문 본문 규칙 바로 뒤에 그 문장이 있다"

# ⑪ 렌더 첫 줄의 끝 문구는 엔진 몫의 결론이고 엔진 밖 채널의 경고는 「그 밖의 경고 M개:」 줄이다(최종 리뷰 I2).
S2='렌더 첫 줄의 끝 문구(이상 없음 · 경고 없음 · 경고 K개)는 문서 리뷰 엔진 몫의 결론이다. 다른 채널에 경고가 있으면 첫 줄 아래에 「그 밖의 경고 M개:」 줄로 쓰고, 전체 결론은 질문의 상태 줄이 정한다(엔진 K + 그 밖의 M).'
assert_eq "$(cnt "$F_FIN" "다른 채널의 경고 줄은 그 위에 더합니다. ${S2}")" "1" "I2: finishing 이 다른 채널 경고 줄을 더하고 바로 뒤에 엔진 몫 문장을 둔다"
assert_eq "$(cnt "$F_RB" "이 자리의 두 채널의 경고 줄은 그 위에 더한다. ${S2}")" "1" "I2: reviewing-brief 가 다른 채널 경고 줄을 더하고 바로 뒤에 엔진 몫 문장을 둔다"
assert_eq "$(cnt "$F_FR" "이 skill 의 두 채널의 경고 줄은 그 위에 더한다. ${S2}")" "1" "I2: request-framing 이 다른 채널 경고 줄을 더하고 바로 뒤에 엔진 몫 문장을 둔다"
for v in F_FIN F_RB F_FR; do
  t="${!v}"
  assert_eq "$(cnt "$t" "$S2")" "1" "I2: ${v} 에 엔진 몫 문장이 정확히 한 번 있다"
done

# ⑫ 「이상 없음」·「경고 없음」 구분과 그 조건(「…때만」) — 파일마다 실제 글자. reviewing-document.md 에는 이 구분 문장이 없다.
assert_eq "$(cnt "$F_RS" '셋 다 비었을 때만, 남은 항목도 없으면 「이상 없음」, 있으면 「경고 없음」이다 — 그 문구는')" "1" "구분: spec-review 승인 게이트의 「셋 다 비었을 때만」 구분"
assert_eq "$(cnt "$F_RS" '남은 것은 있고 경고가 없으면 「경고 없음」, 남은 것도 경고도 없으면 「이상 없음」이 온다.')" "1" "구분: spec-review 가 첫 줄의 두 문구를 가른다"
assert_eq "$(cnt "$F_RB" '전부 비었을 때만, 남은 항목도 없으면 「이상 없음」, 있으면 「경고 없음」이다 — 그 문구는')" "1" "구분: reviewing-brief 의 「전부 비었을 때만」 구분"
assert_eq "$(cnt "$F_FIN" '남은 항목(위 3)도 없을 때만 「이상 없음」, 남은 항목이 있으면 「경고 없음」 한 줄이다.')" "1" "구분: finishing 목록 4 의 「없을 때만」 구분"
assert_eq "$(cnt "$F_PG" '채널을 다 읽었는데 경고가 없으면, 남은 항목도 없으면 「이상 없음」, 남은 항목이 있으면 「경고 없음」 한 줄이다 — 침묵과')" "1" "구분: 정본의 이상 없음/경고 없음 구분"
assert_eq "$(cnt "$F_FR" '경고가 없을 때의 두 문구는 **채널을 실제로 읽었다는 주장**이라 읽지 않은 채 쓰지 않습니다.')" "1" "구분: request-framing 이 경고 없을 때의 두 문구를 읽은 뒤에만 쓴다"

# ⑬ 질문 본문에는 결정과 상태 한 줄만 — 자리마다 그 문장(M5 · M7).
for v in F_RS F_RB F_FR F_RD; do
  t="${!v}"
  assert_eq "$(cnt "$t" "$STEP8")" "1" "질문 본문: ${v} 의 라운드 게이트 질문 규칙"
done
assert_eq "$(cnt "$F_RS" '승인 게이트 질문에는 「경고 N개 — 위에 적었다」(또는 「경고 없음」·「이상 없음」) 한 줄만 둔다. 셋 다')" "1" "질문 본문: spec-review 승인 게이트 질문은 상태 한 줄만"
assert_eq "$(cnt "$F_RB" '(질문 본문에는 「경고 N개 — 위에 적었다」(또는 「경고 없음」·「이상 없음」) 한 줄). 전부')" "1" "질문 본문: reviewing-brief Step B 질문은 상태 한 줄만"
assert_eq "$(cnt "$F_FR" '질문 본문에는 결정 하나와 「경고 N개 — 위에 적었다」(또는 「경고 없음」·「이상 없음」) 한 줄만 둡니다. 경고가')" "1" "질문 본문: request-framing 확정 게이트 질문은 결정과 상태 한 줄만"
assert_eq "$(cnt "$F_PG" '질문 본문에는 결정 하나와 「경고 N개 — 위에 적었다」 (또는 「경고 없음」·「이상 없음」) 한 줄만 둔다.')" "1" "질문 본문: 정본"
assert_eq "$(cnt "$F_FIN" '질문 본문에는 결정 하나와 그 개수 한 줄 (「경고 N개 — 위에 적었다」 또는 「경고 없음」·「이상 없음」)만 둡니다.')" "1" "질문 본문: finishing B-2"
for v in F_RS F_RB F_FR F_FIN F_PG F_RD; do
  t="${!v}"
  assert_eq "$(printf '%s' "$t" | grep -oE '질문[^.]*한 줄씩|한 줄씩[^.]*질문' | wc -l | tr -d ' ')" "0" \
    "질문 본문: ${v} 에 경고를 질문에 한 줄씩 싣는 문장이 없다(위 양의 짝과 함께)"
done

# ⑭ finishing — degrade record 는 앞 글에만, 옵션 description 에는 싣지 않는다(M11).
assert_eq "$(cnt "$F_FIN" '모든 degrade record 는 **게이트 앞 글**(위 목록 4)에 한 줄씩 씁니다 — 옵션 description 에 싣지 않습니다. 사용자가')" "1" \
  "finishing: degrade record 를 옵션 description 에 싣지 않는다"

# ⑮ 읽지 못한 채널은 「알 수 없음 — <사유>」 한 줄(M3 · M4).
assert_eq "$(cnt "$F_FIN" '읽지 못한 채널은 「알 수 없음 — <사유>」 로 따로 한 줄 쓴다.')" "1" "알 수 없음: finishing 목록 4"
assert_eq "$(cnt "$F_PG" '읽지 못한 채널은 「알 수 없음 — <사유>」로 따로 쓴다.')" "1" "알 수 없음: 정본"
finish
