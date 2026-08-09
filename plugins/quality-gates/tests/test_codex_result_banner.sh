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
pass=0; fail=0
ok() { pass=$((pass+1)); echo "  ✓ $1"; }
no() { fail=$((fail+1)); echo "  ✗ $1"; }

[ -f "$SKILL" ] || { echo "FAIL: SKILL 부재"; exit 1; }

# 섹션 윈도우 추출: start_pattern이 매칭된 헤딩 "다음" 줄부터, 레벨 1~4의 다음
# 헤딩 "직전" 줄까지. 못 찾으면(RESULT 서브섹션이 아직 없으면) 빈 문자열 + 실패
# 상태를 돌려준다 — 호출부는 그걸 "본문 없음"으로 취급한다.
section_window() {
  local start_pattern="$1" start_line end_line total
  start_line="$(grep -n "$start_pattern" "$SKILL" | head -1 | cut -d: -f1)"
  [ -n "$start_line" ] || return 1
  total="$(wc -l < "$SKILL")"
  end_line="$(awk -v s="$start_line" 'NR>s && /^#+ /{print NR; exit}' "$SKILL")"
  [ -n "$end_line" ] || end_line=$((total + 1))
  sed -n "$((start_line + 1)),$((end_line - 1))p" "$SKILL"
}

# "Codex skip 안내" 섹션 전체(그 아래 새 서브섹션 헤딩 직전까지) — Task 12가 넣은
# 배너 문구용 윈도우.
SKIP_WINDOW="$(section_window '^#### Codex skip 안내')" \
  || { echo "FAIL: 'Codex skip 안내' 섹션을 찾지 못했다"; exit 1; }

# "codex 결과 판정" 서브섹션 — 이번 태스크(Step 3)가 추가하는 절차 전용 윈도우.
# 아직 추가되지 않았으면 section_window가 실패해 빈 문자열을 남긴다(의도된 RED).
RESULT_WINDOW="$(section_window '^#### codex 결과 판정')"

# 규칙 2: 산출물 파일의 부재·0바이트 — 새 서브섹션 안에서 판정돼야 한다.
if [ -n "$RESULT_WINDOW" ] && echo "$RESULT_WINDOW" | grep -qE '0바이트|비어 있으면|파일이 없거나'; then
  ok "규칙 2: 산출물 부재/0바이트 판정이 명시됨"
else
  no "규칙 2: 산출물 부재/0바이트를 어떻게 읽는지 새 서브섹션에 없다"
fi

# 규칙 3: 양성 성공 표식 — 같은 새 서브섹션 안에서 codex_failed를 읽는다고 말해야
# 한다. ('## Review gate' 안 rc==3 의무가 쓰는 codex_failed는 이 윈도우 밖이다.)
if [ -n "$RESULT_WINDOW" ] && echo "$RESULT_WINDOW" | grep -q 'codex_failed'; then
  ok "규칙 3: 양성 표식(codex_failed)을 읽는다고 명시됨"
else
  no "규칙 3: 양성 표식을 읽는 절차가 새 서브섹션에 없다"
fi

# indeterminate ≠ clean: findings 0건을 clean으로 읽지 않는다는 명시 (같은 서브섹션)
if [ -n "$RESULT_WINDOW" ] && echo "$RESULT_WINDOW" | grep -qE 'findings: \[\][^\n]*clean|clean 으?로 읽지 않는다|발견 0건.*아니다'; then
  ok "indeterminate ≠ clean 이 명시됨"
else
  no "findings 0건을 clean으로 읽지 말라는 명시가 없다"
fi

# 배너 문구가 P11 결손을 말하는가 ('codex 없음'이 아니라) — Codex skip 안내 섹션
# 전체 스코프(Task 12 산출물).
if echo "$SKIP_WINDOW" | grep -q '모델 다양성'; then
  ok "배너가 '모델 다양성 없음'을 말한다 (P11 미집행)"
else
  no "배너가 'codex 없음'에 머문다 — P11이 집행되지 않았다는 사실이 안 보인다"
fi

# 산문 게이트는 이 사이클 범위 밖이며, 그 사실이 문서에 적혀 있어야 한다.
if echo "$SKIP_WINDOW" | grep -qE '산문 게이트|범위 밖'; then
  ok "산문 게이트의 미해결 상태가 문서에 남아 있다 (조용한 갭 아님)"
else
  no "산문 게이트가 미해결이라는 사실이 문서에서 사라졌다"
fi

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[ "$fail" -eq 0 ]
