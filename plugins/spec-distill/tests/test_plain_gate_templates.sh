#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/*/SKILL.md plugins/spec-distill/skills/spec-interview/references/finishing.md plugins/spec-distill/references/proceed-gate.md
#
# 쉬운 말 출력 설계 §4 · AC7 — 모든 게이트 질문은 결정 하나와 상태 한 줄만 담고, 경고 목록은 앞 글에 쓴다.
# 「채널을 읽은 뒤에만 없음을 쓴다」 계약은 그대로 남는다.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  git -C "$REPO_ROOT" ls-files -- 'plugins/spec-distill/skills/*/SKILL.md' \
    plugins/spec-distill/skills/spec-interview/references/finishing.md plugins/spec-distill/references/proceed-gate.md
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
finish
