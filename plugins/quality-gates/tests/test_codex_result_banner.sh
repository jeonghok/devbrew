#!/usr/bin/env bash
# AC24 — 코드리뷰 경로에서 §4.1 규칙 2·3이 배너로 사용자에게 닿는가.
#
# synthesize_findings.py에 meta·codex 언급이 0건이라 결정론 소비자가 없다. 그 경로는
# 러너가 쓴 YAML을 SKILL 오케스트레이터가 직접 읽으므로 배너를 걸 수 있는 유일한
# 지점이 SKILL이다. 여기서는 그 절차가 SKILL에 **명시**돼 있는지를 잰다.
#
# 이것은 문서 검사다 — 모델이 그것을 실제로 따르는지는 잴 수 없다(설계 §10 미해결 1과
# 같은 층의 한계). 그래도 절차가 적혀 있지 않으면 따를 수조차 없다.
#
# 앵커는 섹션 윈도우로 스코프된다: 전체-파일 grep은 다른 태스크가 다른 하위섹션에
# 넣은 동일 문구(예: '## Review gate' 안 rc==3 소비자 의무가 쓰는 'codex_failed')를
# 이 절차의 것으로 오인해 통과시키는 함정이 있다.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL="$ROOT/plugins/quality-gates/skills/quality-pipeline/SKILL.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

[ -f "$SKILL" ] || { echo "FAIL: SKILL 부재"; exit 1; }

# 섹션 윈도우 추출: start_pattern이 매칭된 헤딩 "다음" 줄부터, 아래 세 종료 후보 중
# 가장 먼저 오는 줄 "직전"까지. 못 찾으면(RESULT 서브섹션이 아직 없으면) 빈 문자열
# + 실패 상태를 돌려준다 — 호출부는 그걸 "본문 없음"으로 취급한다.
#
# 종료 후보 (min 을 취한다 — 하나라도 먼저 오면 거기서 끊는다):
#   1. 레벨 무관 다음 헤딩(`^#+ `). 파일 전체에 5단계 이상 헤딩이 없어 이 하나로
#      대부분의 진짜 섹션 경계를 잡지만, 이 두 서브섹션('Codex skip 안내' /
#      'codex 결과 판정')은 헤딩이 아니라 '## Review gate' 번호목록 항목(3번) 안에
#      들여쓰기 없이 끼워 넣은 곁가지라는 게 R9 CRITICAL의 근원 — 헤딩 하나만 보면
#      다음 곁가지 헤딩까지, 또는(그마저 없으면) 그다음 진짜 헤딩까지 143줄을
#      집어삼킨다(실측: RESULT_WINDOW가 391→536, 다른 소단원 4개를 통째로 삼킴).
#   2. 감싸는 번호목록 본문으로 복귀하는 줄(`^   \*\*`, 3칸 들여쓰기 + 볼드 마커로
#      시작 — 예: '   **Tier C', '   **Step 4.5'). 두 곁가지 모두 본문이 들여쓰기
#      0에서 시작하고, 자기 안의 번호목록(1./2./3.) 연속행은 3칸 들여쓰기 뒤에
#      한글/백틱/괄호로 이어지지 '**'로 바로 시작하지 않는다(전수 확인) — 그래서
#      이 패턴은 자기 본문을 안 물고 진짜 복귀 지점만 문다.
#   3. 시작줄 + 50. 위 두 구조 탐지가 모두 깨지는 미래 개편에 대한 로드베어링
#      아닌 안전망일 뿐이다 — 오늘 두 서브섹션의 실측 길이(21·32줄)에 여유를 둔
#      값이며, 144줄 유출 같은 재발은 이 상한이 있는 한 구조 탐지 없이도 막힌다.
section_window() {
  local start_pattern="$1" start_line total
  local heading_end indent_end cap_end end_line
  start_line="$(grep -n "$start_pattern" "$SKILL" | head -1 | cut -d: -f1)"
  [ -n "$start_line" ] || return 1
  total="$(wc -l < "$SKILL")"

  heading_end="$(awk -v s="$start_line" 'NR>s && /^#+ /{print NR; exit}' "$SKILL")"
  [ -n "$heading_end" ] || heading_end=$((total + 1))

  indent_end="$(awk -v s="$start_line" 'NR>s && /^   \*\*/{print NR; exit}' "$SKILL")"
  [ -n "$indent_end" ] || indent_end=$((total + 1))

  cap_end=$((start_line + 50))

  end_line=$heading_end
  [ "$indent_end" -lt "$end_line" ] && end_line=$indent_end
  [ "$cap_end" -lt "$end_line" ] && end_line=$cap_end

  # 빈 윈도우(종료 후보가 시작 헤딩 바로 다음 줄이라 본문이 아예 없는 경우) 방어.
  # BSD sed의 "높은,낮은p" 역방향 범위는 빈 결과가 아니라 그 첫 줄 1개를 찍는다
  # (macOS 실측 — GNU sed와 다르다) — 여기서 검증 없이 sed에 넘기면 창 밖의 줄이
  # 1개 새어 들어온다. start_line+1 > end_line-1 이면 sed를 부르지 않고 그냥
  # 아무것도 출력하지 않는다(성공, "빈 본문"이 유효한 상태).
  if [ "$((start_line + 1))" -gt "$((end_line - 1))" ]; then
    return 0
  fi
  sed -n "$((start_line + 1)),$((end_line - 1))p" "$SKILL"
}

# "Codex skip 안내" 섹션 전체(그 아래 새 서브섹션 헤딩 직전까지) — Task 12가 넣은
# 배너 문구용 윈도우.
SKIP_WINDOW="$(section_window '^#### Codex skip 안내')" \
  || { echo "FAIL: 'Codex skip 안내' 섹션을 찾지 못했다"; exit 1; }

# "codex 결과 판정" 서브섹션 — 이번 태스크(Step 3)가 추가하는 절차 전용 윈도우.
# 아직 추가되지 않았으면 section_window가 실패해 빈 문자열을 남긴다(의도된 RED).
RESULT_WINDOW="$(section_window '^#### codex 결과 판정')"

# 진단용(assertion 아님) — 두 윈도우가 실제로 몇 줄을 물었는지 기록에 남긴다.
# R9 CRITICAL이 RESULT_WINDOW=144줄(Tier C·Transparency·Graceful degradation·
# Reviewer dispatch·honest-verdict floor까지 삼킴)이었던 것과 대조하는 값이다.
skip_lines=0; [ -n "$SKIP_WINDOW" ] && skip_lines="$(printf '%s\n' "$SKIP_WINDOW" | wc -l | tr -d ' ')"
result_lines=0; [ -n "$RESULT_WINDOW" ] && result_lines="$(printf '%s\n' "$RESULT_WINDOW" | wc -l | tr -d ' ')"
echo "  [diag] SKIP_WINDOW lines_captured=$skip_lines"
echo "  [diag] RESULT_WINDOW lines_captured=$result_lines"

# 규칙 2: 산출물 파일의 부재·0바이트 — 새 서브섹션 안에서 판정돼야 한다.
if [ -n "$RESULT_WINDOW" ] && echo "$RESULT_WINDOW" | grep -qE '0바이트|비어 있으면|파일이 없거나'; then
  ok "규칙 2: 산출물 부재/0바이트 판정이 명시됨"
else
  no "규칙 2: 산출물 부재/0바이트를 어떻게 읽는지 새 서브섹션에 없다"
fi

# 규칙 3: 양성 성공 표식 — 같은 새 서브섹션 안에서 `codex_failed: false`(양성
# 표식 그 자체)를 읽는다고 말해야 한다. 바닥 substring 'codex_failed'만 재면
# 바로 위 항목의 `codex_failed: true`(실패 판정, 별개 관심사) 한 줄에도 걸려서
# 양성-표식 문장을 통째로 지워도 그 줄이 남아 있으면 계속 통과한다 — 코디네이터가
# 잡은 결함(진단은 rule 3를 present라고 거짓 보고). `: false` 까지 물어야
# 이 문장에만 유일하다.
if [ -n "$RESULT_WINDOW" ] && echo "$RESULT_WINDOW" | grep -q 'codex_failed: false'; then
  ok "규칙 3: 양성 표식(codex_failed: false)을 읽는다고 명시됨"
else
  no "규칙 3: 양성 표식을 읽는 절차가 새 서브섹션에 없다"
fi

# indeterminate ≠ clean: findings 0건을 clean으로 읽지 않는다는 명시 (같은 서브섹션)
if [ -n "$RESULT_WINDOW" ] && echo "$RESULT_WINDOW" | grep -qE 'findings: \[\][^\n]*clean|clean 으?로 읽지 않는다|발견 0건.*아니다'; then
  ok "indeterminate ≠ clean 이 명시됨"
else
  no "findings 0건을 clean으로 읽지 말라는 명시가 없다"
fi

# 배너 문구가 P11 결손을 말하는가 ('codex 없음'이 아니라) — AC24의 실제 산출물은
# RESULT_WINDOW 안의 새 배너이므로 거기에 스코프한다. SKIP_WINDOW(Task 12가 넣은
# 기존 '미실행' 배너)로 스코프하면 이 태스크가 자기 배너 줄을 통째로 지워도
# SKIP_WINDOW 쪽 '모델 다양성' 문구(다른 배너) 때문에 계속 통과한다 — 리뷰에서
# 실측된 함정. AC24가 실제로 낸 배너 문구 안에서만 재야 이빨이 산다.
if [ -n "$RESULT_WINDOW" ] && echo "$RESULT_WINDOW" | grep -q '모델 다양성'; then
  ok "새 배너가 '모델 다양성 없음'을 말한다 (P11 미집행)"
else
  no "새 배너가 'codex 없음'에 머물거나 아예 없다 — P11이 집행되지 않았다는 사실이 안 보인다"
fi

# 산문 게이트는 이 사이클 범위 밖이며, 그 사실이 문서에 적혀 있어야 한다.
# 의도적으로 SKIP_WINDOW에만 스코프한다 — 파일 전체가 아니다. 이 문구
# ('산문 게이트' / '범위 밖')는 문서 전체를 통틀어 Codex skip 안내 섹션
# (Task 12 산출물, detect_codex.sh 자체가 아직 리터럴 bash 게이트가 아니라는
# 고지) 안에만 존재한다 — `grep -nE '산문 게이트|범위 밖' SKILL.md`가 정확히
# 1건을 낸다(재확인하려면 위 grep을 그대로 다시 돌려보라). RESULT_WINDOW(codex가
# 이미 돈 *뒤*의 결과 판정)는 이 주장과 무관한 다른 관심사라 반복할 이유가 없다.
# 이 문구가 나중에 RESULT_WINDOW 쪽으로 옮겨가면 이 grep도 같이 옮겨야 한다.
if echo "$SKIP_WINDOW" | grep -qE '산문 게이트|범위 밖'; then
  ok "산문 게이트의 미해결 상태가 문서에 남아 있다 (조용한 갭 아님)"
else
  no "산문 게이트가 미해결이라는 사실이 문서에서 사라졌다"
fi
finish
