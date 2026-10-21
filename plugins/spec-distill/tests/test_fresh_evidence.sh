#!/usr/bin/env bash
# guards: plugins/spec-distill/references/fresh-evidence.md plugins/spec-distill/references/research-claims.md plugins/spec-distill/skills/pm-interview/references/finishing.md plugins/spec-distill/templates/interview-audit-template.md
#
# 신선한 근거 원칙 여덟이 원문 그대로 · 행동 한 줄과 함께 실려 있는가, 낡은 지식 바로잡기와
# 사용자 판단 · 외부 사실 구분 문장이 있는가, 주문 요약 표지가 한 쌍인가, 웹 근거 선택 칸이
# 별도 절에 있고 어느 게이트도 읽지 않는가, 「대체됨」 줄이 state 라운드 기록에서 audit 프로세스 로그로
# 옮겨 가는 길(finishing Step A · audit 템플릿)이 있는가. 실제 agent 는 부르지 않는다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT/plugins/spec-distill"
SKILL="$SD/skills/pm-interview/SKILL.md"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/references/fresh-evidence.md"
  echo "plugins/spec-distill/references/research-claims.md"
  echo "plugins/spec-distill/skills/pm-interview/references/finishing.md"
  echo "plugins/spec-distill/templates/interview-audit-template.md"
  exit 0
fi

. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

SCRATCH="$(mktemp -d -t sd-fresh-XXXXXX)" || { echo "scratch 생성 실패" >&2; exit 1; }
[ -n "$SCRATCH" ] && [ -d "$SCRATCH" ] || { echo "scratch 가 유효한 디렉토리가 아니다" >&2; exit 1; }
trap 'rm -rf "$SCRATCH"' EXIT

FE="$SD/references/fresh-evidence.md"; RC="$SD/references/research-claims.md"
[ -f "$FE" ] || no "fresh-evidence.md 부재"
FE_FLAT="$(tr '\n' ' ' < "$FE" 2>/dev/null | tr -s ' ')"
# AC8 — 원칙 여덟 원문(설계 §3 표 첫 칸 글자 그대로)
P=('모델이 자신의 지식이 오래되었는지 정확히 안다고 가정하지 말고, 시간에 따라 변할 수 있으며 현재 결정에 영향을 주는 사실을 검증 대상으로 삼는다.'
   '조사 에이전트가 잘못된 지식을 가져왔을 수 있으니 항상비판적으로 봐야한다. 향후에도 항상 검증을 통해 뒤집힐 수 있는 컨텍스트이며 조사해온 내용으로 인해 잘못된 방향으로 빠지면 안된다'
   '기술 정보는 현재 프로젝트가 실제로 사용하는 버전과 최신 upstream 버전을 혼동하지 않는다.'
   '최신과 신뢰성 간 스윗포인트를 생각해야하며 사용자에게 선택지를 줄 수 있어야 한다 모델이 혼자 결정하지 않음'
   '가능한 경우 공식 문서와 1차 자료를 우선한다.'
   '확인하지 못한 내용은 현재 사실처럼 단정하지 말고 불확실성을 드러낸다.'
   '조사 능력을 제한하는 임의의 검색 횟수·출처 수 상한이나, 형식만 채우는 무거운 게이트를 추가하지 않는다.'
   '사용자 판단과 외부 사실의 교정을 구분하고 기존 사용자 결정권을 유지한다.')
i=0; for p in "${P[@]}"; do i=$((i+1)); assert_contains "$FE_FLAT" "$p" "AC8: 원칙 ${i} 원문"; done
# 원칙마다 행동 한 줄 — 본문 고유 문구(제목만으로 맞출 수 없게). 표의 원칙 행에서만 잰다 — 아래 주문 요약에도
# 같은 말(「2차 자료는 2차로 표시한다」 등)이 있어 파일 전체로 재면 표 행을 지워도 요약이 단언을 대신 만족시킨다.
FE_ROWS="$(grep -E '^\| [1-8] 「' "$FE" 2>/dev/null | tr '\n' ' ' | tr -s ' ')"
assert_eq "$(grep -cE '^\| [1-8] 「' "$FE" 2>/dev/null)" "8" "AC8(양성대조): 원칙 표 행이 여덟이다"
for lit in '모델의 확신과 무관하게 그 사실을 조사 주문에 넣는다' '1차 자료로 한 번 더 확인하거나 불확실로 둔다' \
           '레포 버전은 추측하지 않고 읽는다' '차이를 보이고 선택지로 묻는다' '2차 자료는 2차로 표시한다' \
           '「확인 못 함」으로 적는다' '검색 · 출처 수 상한을 두지 않는다'; do
  assert_contains "$FE_ROWS" "$lit" "AC8: 표 행의 행동 «${lit}»"
done
assert_contains "$FE_ROWS" '`research-claims.md` 의 웹 근거 칸은 선택이고 게이트가 없다' "원칙 7: 표 행이 가리키는 칸을 이름으로 댄다"
assert_not_contains "$FE_FLAT" '아래 칸은 선택' "원칙 7: 이 파일에 없는 「아래 칸」을 가리키지 않는다"
# AC10 · AC11
assert_contains "$FE_FLAT" '다음 «지금 이해»에 바로잡은 사실을 명시하고 audit 에 앞 믿음을 「대체됨」으로 남긴다' "AC10: 낡은 지식 바로잡기"
REPLACED_LINE='`- 대체됨: <앞 믿음> → <바로잡은 사실> (조사 <n>)`'
assert_contains "$FE_FLAT" "인터뷰 중에는 audit 파일이 없으므로 그 라운드의 state 본문 \`## R<n>\` «지금 이해» 아래에 ${REPLACED_LINE} 한 줄로 적는다" "AC10: 인터뷰 중 「대체됨」 줄의 자리(state 라운드 기록)"
assert_contains "$FE_FLAT" '그 줄들을 audit `## 5. 프로세스 로그` 로 글자 그대로 옮긴다' "AC10: 종료 때 audit 프로세스 로그로 옮긴다"
FIN="$SD/skills/pm-interview/references/finishing.md"; AUD_T="$SD/templates/interview-audit-template.md"
[ -f "$FIN" ] && [ -f "$AUD_T" ] && ok "AC10(양성대조): finishing.md · audit 템플릿이 있다" || no "AC10: finishing.md 또는 audit 템플릿 부재"
STEPA="$(awk '/^### Step A — /{f=1;next} /^### /{f=0} f' "$FIN" 2>/dev/null | tr '\n' ' ' | tr -s ' ')"
assert_contains "$STEPA" "${REPLACED_LINE} 줄을 라운드 순서대로 audit \`## 5. 프로세스 로그\` 에 글자 그대로 옮겨 씁니다" "AC10: finishing Step A 가 「대체됨」 줄을 audit 프로세스 로그로 옮긴다"
assert_contains "$STEPA" '같은 걸음에 state 본문 각 `## R<n>` 의 `- 확인 RC<n> — …` 줄을 라운드 순서대로 audit `## 5. 프로세스 로그` 에 글자 그대로 옮겨 씁니다' "AC8: finishing Step A 가 확인 줄도 「대체됨」 옮기기와 같은 걸음에 옮긴다"
AUD5="$(awk '/^## 5\. 프로세스 로그/{f=1;next} /^## /{f=0} f' "$AUD_T" 2>/dev/null)"
assert_contains "$AUD5" "$REPLACED_LINE" "AC10: audit 템플릿의 프로세스 로그 절에 「대체됨」 줄 꼴이 있다"
assert_contains "$FE_FLAT" '사실 주장이면 출처와 함께 교정을 보이고 묻는다' "AC11: 사실 교정은 묻는다"
assert_contains "$FE_FLAT" '판단 · 선호면 덮지 않고 정보로 기록한다' "AC11: 판단 · 선호는 덮지 않는다"
assert_contains "$FE_FLAT" '확정 항목은 근거를 보이고 사용자 동의로만 재결정한다' "AC11: 확정 항목 재결정은 동의로만"
# 게이트가 아니다 — 양의 짝(문장) + 음의 짝(check_brief 가 이 파일 · 새 칸을 읽지 않는다)
assert_contains "$FE_FLAT" '게이트가 아니라 기본 행동이다' "원칙 7: 게이트 아님"
GATE_SRC=("$SD/scripts/check_brief.py" "$SD/scripts/brief_body.py")
for f in "${GATE_SRC[@]}"; do
  [ -f "$f" ] && ok "원칙 7(양의 짝): 게이트 소스 ${f##*/} 가 있다 (아래 부재가 공허하지 않다)" || no "원칙 7: 게이트 소스 ${f##*/} 부재 — 아래 부재 단언이 공허하다"
  for tok in fresh-evidence source_kind checked_at certainty; do
    if grep -qF "$tok" "$f"; then no "원칙 7: ${f##*/} 가 «${tok}» 를 읽는다"; else ok "원칙 7: ${f##*/} 에 «${tok}» 없음"; fi
  done
done
# 주문 요약 블록 — 표지 둘이 하나씩, 사이가 비지 않음
assert_eq "$(grep -cF '<!-- order-summary:begin -->' "$FE" 2>/dev/null)" "1" "AC8: 요약 시작 표지 하나"
assert_eq "$(grep -cF '<!-- order-summary:end -->' "$FE" 2>/dev/null)" "1" "AC8: 요약 끝 표지 하나"
SUM="$(awk '/<!-- order-summary:end -->/{f=0} f; /<!-- order-summary:begin -->/{f=1}' "$FE" 2>/dev/null)"
SUMN="$(grep -c . <<<"$SUM")"
if [ "$SUMN" -ge 6 ] && [ "$SUMN" -le 10 ]; then ok "AC8: 요약 블록 ${SUMN}줄 (6–10)"; else no "AC8: 요약 블록이 6–10줄 밖이다 (${SUMN}줄)"; fi
assert_not_contains "$SUM" '예시 목록' "AC8: 요약 블록은 주문에 홀로 실린다 — 블록 밖 「예시 목록」을 가리키지 않는다"
assert_contains "$SUM" '버전 · API · 공식 사용법 · 제품 정책 · 표준 · 제도 등, 이 예시에 한정하지 않는다' "AC8: 요약 블록이 예시를 안에 싣는다"
# AC9 — 선택 칸 넷(별도 절) · 없어도 실패하지 않는다는 문장
SEC="$(awk '/^## 웹 근거 칸\(선택\)/{f=1;next} /^## /{f=0} f' "$RC")"
for k in source_kind checked_at version certainty; do
  if grep -qE "^[[:space:]]*-?[[:space:]]*${k}:" <<<"$SEC"; then ok "AC9: 선택 칸 ${k}"; else no "AC9: 선택 칸 ${k} 부재"; fi
done
assert_contains "$(tr '\n' ' ' <<<"$SEC")" '없어도 실패하지 않는다' "AC9: 선택 칸은 선택"

finish
