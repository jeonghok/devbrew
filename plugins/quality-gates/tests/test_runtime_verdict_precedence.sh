#!/usr/bin/env bash
# test_runtime_verdict_precedence.sh — verdict 규칙과 갭 게이트의 오케스트레이션 락.
# AC10 AC12 AC19 AC20 AC44 AC49 AC53 AC57 · T8 T21 T31 T40 T46 T51 T55
# · M5 M6 M11 M19 M24
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
RTS="$PLUGIN_ROOT/scripts/run-test-selection.sh"
TAB=$'\t'

PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ FAIL: $1"; }

# section_window <start-anchor> <end-anchor> → 두 앵커 사이의 본문
# 락 문구를 섹션 윈도우 안에서 찾는 이유: 문서 아무 데나 있는 같은 단어가
# 락을 만족시키면 그 락엔 이빨이 없다.
section_window() {
  awk -v s="$1" -v e="$2" '
    index($0, s) { inw = 1 }
    inw && index($0, e) && !index($0, s) { exit }
    inw { print }
  ' "$SKILL"
}

# body_unique_in <window-cmd-output> <needle> → 윈도우 안에 정확히 1회
count_in() { printf '%s\n' "$1" | grep -cF "$2"; }

# ── (i) 결정론 산출물 ────────────────────────────────────────────────────────

# T51 + M24 + AC53: unclaimed unit이 실제로 산출된다 (verdict 라우팅의 입력)
case_unclaimed_row_is_produced() {
  local w; w=$(mktemp -d)
  mkdir -p "$w/tests"; : > "$w/tests/test_a.py"
  local out; out=$(printf 'spec/a_spec.rb\n' | bash "$RTS" assign "$w")
  [[ "$out" == "spec/a_spec.rb${TAB}unclaimed${TAB}file" ]] \
    && pass "미지원 레포 → unclaimed 행 산출" || fail "unclaimed 미산출 ($out)"
  rm -rf "$w"
}

# T40 + M19 + AC44: 영향분 러너 부재는 exit 3으로 **구별 가능하게** 나온다
case_runner_absent_is_distinguishable() {
  local w; w=$(mktemp -d); mkdir -p "$w/tests"; : > "$w/tests/test_a.py"
  local rc; bash "$RTS" run "$w" cargo bulk BULK >/dev/null 2>&1; rc=$?
  [[ $rc -eq 3 ]] && pass "영향분 러너 부재 → exit 3 (gap과 구별 가능)" || fail "exit 3 아님 ($rc)"
  rm -rf "$w"
}

# ── (ii) SKILL.md 산문 락 (섹션 윈도우 + body-unique) ─────────────────────────

# T51 + AC53: unclaimed → verification degraded → PASS 불가가 verdict 절에 있다.
# needle 은 SKILL.md 본문의 **연속 부분문자열**이어야 한다 — 백틱 하나 어긋나면
# grep -F 가 못 찾고 락은 조용히 통과한다(이 plan 작성 중 실제로 한 번 어긋났다).
case_skill_unclaimed_blocks_pass() {
  local w; w=$(section_window '**Step R8' '## Blocked-path routing')
  if [[ $(count_in "$w" '가 하나라도 있으면 `verification: degraded` 이고 verdict 를 PASS 로 올리지 않는다') -ge 1 ]] \
     && [[ $(count_in "$w" '열거가 인증을 대신하지 않는다') -ge 1 ]]; then
    pass "R8 절이 unclaimed → verification degraded → PASS 불가를 명시"
  else fail "R8 절에 unclaimed 라우팅 규칙 부재"; fi
}

# M19 + T40 + AC44: 영향분 러너 부재(exit 3)는 **PASS 불가 행**에 있어야 한다.
# 두 조건을 따로 세면 토큰이 `gap: closed` 행으로 옮겨가도 GREEN 이다 — 그 이동이
# 정확히 M19("영향분 러너 부재를 gap: closed 로 처리해 PASS 허용")이므로 **같은 줄**을
# 잰다. 실측: 행만 옮기는 mutation 에 다른 12 케이스는 전부 GREEN 이었다.
case_skill_runner_absent_blocks_pass() {
  local w; w=$(section_window '**Step R8' '## Blocked-path routing')
  if printf '%s\n' "$w" | grep -F '러너 부재 exit 3' | grep -qF '**불가**'; then
    pass "영향분 러너 부재(exit 3)가 PASS 불가 행에 있다"
  else
    fail "러너 부재 exit 3 이 PASS 불가 행에 없음 (gap: closed 행으로 새면 M19)"
  fi
}

# T31 + M11 + AC15(빈 스코프): 영향분 0개 → SKIP_WITH_EVIDENCE (PASS도 FAIL도 아님)
case_skill_zero_impact_is_skip() {
  local w; w=$(section_window '**Step R8' '## Blocked-path routing')
  [[ $(count_in "$w" '영향분 0개 → `SKIP_WITH_EVIDENCE`') -ge 1 ]] \
    && pass "영향분 0개 → SKIP_WITH_EVIDENCE (정확 토큰)" \
    || fail "영향분 0개 규칙 부재/토큰 불일치"
}

# T26 + M5 + M15 + AC35: 확증 제품결함이 terminal이고 degrade가 함께 기록된다
case_skill_precedence_total_order() {
  local w; w=$(section_window '**Step R8' '## Blocked-path routing')
  if [[ $(count_in "$w" '확증 제품결함(FAIL, terminal)  >  NEEDS_RESOLUTION  >  SKIP_WITH_EVIDENCE  >  PASS') -eq 1 ]] \
     && [[ $(count_in "$w" 'degrade 사실은 원장과 보고서에 함께 기록된다') -ge 1 ]]; then
    pass "verdict 총 순서 1회 + degrade 동시 기록 명시"
  else fail "verdict 총 순서 / degrade 동시 기록 락 실패"; fi
}

# T21 + M6 + AC12: 재실행은 정확히 1회 (무한 재실행이 false green 경로)
case_skill_rerun_exactly_once() {
  local w; w=$(section_window '**Step R6' '**Step R7')
  if [[ $(count_in "$w" '재실행은 정확히 1회다 — green 이 나올 때까지가 아니다') -eq 1 ]]; then
    pass "재실행 1회 잠금 문장 존재 (body-unique)"
  else fail "재실행 1회 문장 부재/중복"; fi
}

# T8 + AC10: bulk green이면 per-unit 재실행을 하지 않는다 (2단 구조)
case_skill_two_stage() {
  local w; w=$(section_window '**Step R5b' '**Step R6')
  [[ $(count_in "$w" 'bulk 가 green 이면 per-unit 재실행을 하지 않는다') -ge 1 ]] \
    && pass "2단 구조(bulk green → per-unit 0회) 명시" || fail "2단 구조 문장 부재"
}

# T28 + AC19: 계획 산문 6필드가 R2 절에 열거된다
case_skill_plan_prose_six_fields() {
  local w; w=$(section_window '**Step R2' '**Step R3')
  local missing=0 f
  for f in '무엇이 바뀌었나' '어떤 행동에 닿나' '무엇을 돌리나' \
           '비용 신호' '무엇을 안 돌리나' 'CI 와 다르면'; do
    [[ $(count_in "$w" "$f") -ge 1 ]] || { echo "    누락 필드: $f"; missing=1; }
  done
  [[ $missing -eq 0 ]] && pass "계획 산문 6필드 전부 R2에 존재" || fail "계획 산문 필드 누락"
  [[ $(count_in "$w" '개 선택 (전체 ') -ge 1 ]] \
    && pass "선택 비율 포맷 \`N개 선택 (전체 M개 중)\`" || fail "선택 비율 포맷 부재"
}

# T55 + AC57: 비용 신호는 3단계 범주값이고 숫자 시간 추정을 쓰지 않는다
case_skill_cost_signal_categorical() {
  local w; w=$(section_window '**Step R2' '**Step R3')
  local ok=1 c
  for c in '즉시' '수 분' '설치 포함'; do
    [[ $(count_in "$w" "$c") -ge 1 ]] || { echo "    누락 등급: $c"; ok=0; }
  done
  [[ $ok -eq 1 ]] && pass "비용 등급 3단계 존재" || fail "비용 등급 누락"
  # 숫자 시간 추정(예: "약 3분", "5 min")이 R2 절에 없어야 한다.
  # 단위 토큰에 bare `s` 를 넣지 않는다 — "R5b" 같은 식별자를 오탐한다.
  # 빈 윈도우 가드: 앵커가 어긋나 윈도우가 비면 이 **음의** 락은 공허하게 통과한다
  # (양의 락들과 달리 부재를 재는 락이라 스스로 못 알아챈다).
  if [[ -z "$w" ]]; then
    fail "R2 윈도우가 비어 있음 — 음의 락이 공허하게 통과할 뻔했다"
  elif printf '%s\n' "$w" | grep -qE '(약[[:space:]]+)?[0-9]+[[:space:]]*(초|분|시간|sec|min|hour)'; then
    fail "R2 절에 숫자 시간 추정이 있음"
  else
    pass "숫자 시간 추정 0회 (추정기가 없으므로 지어낸 숫자가 된다)"
  fi
}

# AC20: 갭 게이트는 생략 목록이 **비어 있으면** 발화하지 않는다
case_skill_gap_gate_zero_click() {
  local w; w=$(section_window '**Step R3' '**Step R4')
  if [[ $(count_in "$w" '생략 목록이 비어 있으면 `AskUserQuestion` 을 발화하지 않는다') -ge 1 ]] \
     && [[ $(count_in "$w" 'zero-click') -ge 1 ]]; then
    pass "생략 0 → zero-click 조건 명시"
  else fail "zero-click 조건 부재"; fi
}

# T46 + AC49: bulk 어댑터의 커버리지 미보장 공시가 R2와 R8 **양쪽**에 있다
case_skill_bulk_disclosure() {
  local w2 w8
  w2=$(section_window '**Step R2' '**Step R3')
  w8=$(section_window '**Step R8' '## Blocked-path routing')
  if [[ $(count_in "$w2" '커버리지 미보장(러너가 선택을 무시함)') -ge 1 ]] \
     && [[ $(count_in "$w8" '커버리지 미보장(러너가 선택을 무시함)') -ge 1 ]]; then
    pass "bulk 커버리지 미보장 공시가 계획 산문과 보고서 양쪽에"
  else fail "bulk 공시 누락 (R2=$(count_in "$w2" '커버리지 미보장(러너가 선택을 무시함)') R8=$(count_in "$w8" '커버리지 미보장(러너가 선택을 무시함)'))"; fi
}

# AC47: 기준선 트리에서 detect를 **재실행**한다 (HEAD 집합 재사용 금지)
case_skill_both_side_detect() {
  local w; w=$(section_window '**Step R4' '**Step R5a')
  [[ $(count_in "$w" 'HEAD 의 어댑터 집합을 재사용하지 않는다') -ge 1 ]] \
    && pass "기준선 트리 재감지 명시" || fail "양측 재감지 문장 부재"
}

for c in case_unclaimed_row_is_produced case_runner_absent_is_distinguishable \
         case_skill_unclaimed_blocks_pass case_skill_runner_absent_blocks_pass \
         case_skill_zero_impact_is_skip \
         case_skill_precedence_total_order case_skill_rerun_exactly_once \
         case_skill_two_stage case_skill_plan_prose_six_fields \
         case_skill_cost_signal_categorical case_skill_gap_gate_zero_click \
         case_skill_bulk_disclosure case_skill_both_side_detect; do
  echo "== $c"; $c
done
echo "── runtime verdict precedence: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
