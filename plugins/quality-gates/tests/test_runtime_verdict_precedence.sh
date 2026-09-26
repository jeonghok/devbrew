#!/usr/bin/env bash
# test_runtime_verdict_precedence.sh — verdict 규칙과 갭 게이트의 오케스트레이션 락.
# AC10 AC12 AC19 AC20 AC44 AC49 AC53 AC57 · T8 T21 T31 T40 T46 T51 T55
# · M5 M6 M11 M19 M24
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SKILL_REAL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
RTS="$PLUGIN_ROOT/scripts/run-test-selection.sh"
TAB=$'\t'

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# Task 31(무게 감축): 차등 테스트 절차 전문이 references/differential-test.md 로
# 분리됐다. 아래 section_window() 는 R-init..R8 앵커로 SKILL.md 를 창-스캔하도록
# 설계됐으므로, 분할 전과 동일한 논리적 문서를 재구성해 그 위에서 돈다. 재구성
# 실패를 원본 SKILL.md 로 조용히 폴백하면 앵커가 전부 소실돼 아래 창들이 비고,
# 음의 락들이 vacuous 하게 통과한다 — 그래서 폴백하지 않고 즉시 FAIL 한다.
. "$SCRIPT_DIR/lib/reconstruct-skill.sh"
if ! SKILL="$(reconstruct_skill_md "$SKILL_REAL")"; then
  echo "FAIL: SKILL.md ↔ references/differential-test.md 재구성 실패 ($SKILL_REAL)"
  exit 1
fi
trap 'rm -f "$SKILL"' EXIT

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
    && ok "미지원 레포 → unclaimed 행 산출" || no "unclaimed 미산출 ($out)"
  rm -rf "$w"
}

# T40 + M19 + AC44: 영향분 러너 부재는 exit 3으로 **구별 가능하게** 나온다
case_runner_absent_is_distinguishable() {
  local w; w=$(mktemp -d); mkdir -p "$w/tests"; : > "$w/tests/test_a.py"
  local rc; bash "$RTS" run "$w" cargo bulk BULK >/dev/null 2>&1; rc=$?
  [[ $rc -eq 3 ]] && ok "영향분 러너 부재 → exit 3 (gap과 구별 가능)" || no "exit 3 아님 ($rc)"
  rm -rf "$w"
}

# T66 — R-init 판별자 표에 락 (/qg iter-5, TA4).
#
# 배경: iter-4(8432aec)가 R-init 도입 문장의 포괄 형태(`same_as_head` **단독**으로 PASS
# 차단)를 표에 맞춰 좁혔는데 **락을 안 붙였다.** 그래서 되돌려도 스위트 전체가 GREEN
# 이었고, 실제로 같은 문서 안에 안 좁혀진 인용이 두 개(`:1018`·CHANGELOG) 살아남은 채
# 스위트는 full-green 이었다. 그것이 이 락의 존재 이유다.
#
# 잠그는 대상은 **도입 문장이 아니라 표의 행**이다 — 도입 문장은 산문이라 다시 넓어져도
# 표만 보면 안 보이지만, 행은 판별의 실체다. needle 은 **body-unique** 로 고른다:
# 표 안에서만 나오는 `| yes | dirty |` 형태를 쓰지 않으면(예: '워킹 트리' 같은 산문어)
# 본문을 지우고 산문만 남겨도 GREEN 이 된다(헤딩-satisfiable 함정, 이 리포 기학습).
case_rinit_discriminator_table() {
  local w; w=$(section_window '**Step R-init' '**Step R1a')
  local ok=1

  # 양① — clean 행: 차등 불가 → 스킵 + PASS 불가
  printf '%s\n' "$w" | grep -qE '^\|[[:space:]]*yes[[:space:]]*\|[[:space:]]*clean[[:space:]]*\|.*clean 불가' \
    || { ok=0; echo "    (miss) yes|clean 행 + 'clean 불가'"; }
  # 양② — dirty 행: 차등 성립 → 정상 진행
  printf '%s\n' "$w" | grep -qE '^\|[[:space:]]*yes[[:space:]]*\|[[:space:]]*dirty[[:space:]]*\|.*정상 진행' \
    || { ok=0; echo "    (miss) yes|dirty 행 + '정상 진행'"; }
  # 음 — 포괄 형태의 재도입 봉쇄. 이 문자열이 다시 나타나면 규칙이 재광역화된 것이다.
  if printf '%s\n' "$w" | grep -qF '또는 `same_as_head: yes` 면'; then
    ok=0; echo "    (regress) 포괄 형태가 R-init 창에 재등장"
  fi

  [[ $ok -eq 1 ]] && ok "R-init 판별자 표: clean→clean불가 · dirty→정상진행 · 포괄형태 0회" \
    || no "R-init 판별자 표 락"
}

# T67 (invert — Task 7, 계획 Step 3(c)) — R4 는 이제 판별자를 **자기 스텝에서 직접
# 구하지 않는다.** 한 파이프라인에는 `/qg runtime` 같은 Dispatch-Loop 우회 경로가
# 없다 — 모든 iteration 이 Review Step 1b 를 R4 보다 먼저 돈다(Pipeline ①→②). 그래서
# R4 는 Step 1b 가 iteration 1 에서 캐시한 `worktree_dirty`/`degraded` 를 그대로
# 쓰고, iteration 2 이상은 캐시가 낡았다고 보아 dirty 로 취급한다(fail-closed: 모름
# → 실행). `check-review-scope.sh` 를 R4 창 안에서 다시 부르는 문구가 있으면 그것이
# 오히려 회귀다(원인이던 우회 경로가 이제 존재하지 않는다).
case_r4_resolves_discriminator_itself() {
  local w; w=$(section_window '**Step R4' '**Step R5b')
  local ok=1
  count_in "$w" 'Review Step 1b 가 iteration 1 에서 캐시한' | grep -qE '^[1-9]' \
    || { ok=0; echo "    (miss) R4 창 안에 Step 1b 캐시 판별자 문장"; }
  count_in "$w" 'iteration 2 이상은 Retry 가 파일을 고친 뒤' | grep -qE '^[1-9]' \
    || { ok=0; echo "    (miss) iteration 2 이상 캐시-낡음 → dirty 취급 문장"; }
  # degraded 를 dirty 로 접는 fail-closed 규칙 (모름 → 실행)
  printf '%s\n' "$w" | grep -qE '^\|[[:space:]]*yes[[:space:]]*\|.*degraded: yes.*\|.*R4 실행' \
    || { ok=0; echo "    (miss) degraded: yes → R4 실행 행"; }
  [[ $ok -eq 1 ]] && ok "R4 가 판별자를 Step 1b 캐시에서 구하고 degraded 를 dirty 로 접는다 (Task 7 invert)" \
    || no "R4 판별자 캐시-소비 락"
}

# T68 — 좁힌 규칙의 **원래 형태가 문서 어디에도 인용 가능한 채로 남지 않는다** (∀).
#
# ∃-검사("어딘가에 좁힌 형태가 있다")로는 이 결함이 반복 통과한다 — 실제로 3회 반복됐다
# (design.md §6.6 → SKILL.md:656 → SKILL.md:1018). 그래서 ∀ 로 뒤집는다:
# `same_as_head` 를 R4 스킵/PASS 차단 사유로 **언급하는 모든 줄**은 같은 줄 안에
# 한정어(clean/깨끗/worktree_dirty/단독은 아니)를 동반해야 한다.
case_same_as_head_never_unqualified() {
  local bad=0 line
  while IFS= read -r line; do
    case "$line" in
      *same_as_head*) : ;;
      *) continue ;;
    esac
    # 스킵/PASS-차단 문맥이 아닌 줄(키 정의·계약 설명 등)은 대상 아님
    case "$line" in
      *건너뛴*|*건너뛰지*|*스킵*|*PASS*|*차등*) : ;;
      *) continue ;;
    esac
    # 한정어는 **개념**이지 특정 토큰이 아니다 — "이 줄은 same_as_head 를 *충분조건*으로
    # 주장하지 않는다" 를 만족시키는 형태를 전부 센다. 워킹 트리를 둘째 축으로 선언하는
    # 표 헤더도, 충분성을 부정하는 정정문("만으로는 … 않는다")도 한정된 진술이다.
    # (개념이 아니라 토큰만 열거하면 같은 것을 다른 이름으로 부른 줄이 위양성으로 잡힌다.)
    case "$line" in
      *clean*|*깨끗*|*worktree_dirty*|*dirty*|*단독*|*"워킹 트리"*|*만으로*) : ;;
      *) bad=$((bad+1)); echo "    (unqualified) ${line:0:96}" ;;
    esac
  done < "$SKILL"
  [[ $bad -eq 0 ]] && ok "same_as_head 를 스킵/PASS 사유로 쓰는 모든 줄이 한정어 동반 (∀)" \
    || no "한정어 없는 same_as_head 진술 ${bad}줄"
}

# ── (ii) SKILL.md 산문 락 (섹션 윈도우 + body-unique) ─────────────────────────

# T51 + AC53: unclaimed → verification degraded → PASS 불가가 verdict 절에 있다.
# needle 은 SKILL.md 본문의 **연속 부분문자열**이어야 한다 — 백틱 하나 어긋나면
# grep -F 가 못 찾고 락은 조용히 통과한다(이 plan 작성 중 실제로 한 번 어긋났다).
case_skill_unclaimed_blocks_pass() {
  local w; w=$(section_window '**Step R8' '## Final Summary')
  if [[ $(count_in "$w" '가 하나라도 있으면 `verification: degraded` 이고 clean 불가') -ge 1 ]] \
     && [[ $(count_in "$w" '열거가 인증을 대신하지 않는다') -ge 1 ]]; then
    ok "R8 절이 unclaimed → verification degraded → clean 불가를 명시"
  else no "R8 절에 unclaimed 라우팅 규칙 부재"; fi
}

# M19 + T40 + AC44: 영향분 러너 부재(exit 3)는 **PASS 불가 행**에 있어야 한다.
# 두 조건을 따로 세면 토큰이 `gap: closed` 행으로 옮겨가도 GREEN 이다 — 그 이동이
# 정확히 M19("영향분 러너 부재를 gap: closed 로 처리해 PASS 허용")이므로 **같은 줄**을
# 잰다. 실측: 행만 옮기는 mutation 에 다른 12 케이스는 전부 GREEN 이었다.
case_skill_runner_absent_blocks_pass() {
  local w; w=$(section_window '**Step R8' '## Final Summary')
  if printf '%s\n' "$w" | grep -F '러너 부재 exit 3' | grep -qF '**불가**'; then
    ok "영향분 러너 부재(exit 3)가 clean 불가 행에 있다"
  else
    no "러너 부재 exit 3 이 clean 불가 행에 없음 (gap: closed 행으로 새면 M19)"
  fi
}

# T31 + M11 + AC15(빈 스코프, 대상 소멸 — Task 7): 영향분 0개 → SKIP_WITH_EVIDENCE
# 였던 R8 verdict 결정 표 자체가 지워졌다(판정 어휘는 scripts/verdict.py 밖에 두지
# 않는다 — global constraints). 사유 매핑(scope-empty)은 R-Y 를 거쳐 Task 8 이
# verdict.py 로 옮긴다 — 이 레퍼런스 문서에는 대응물이 없다.

# T26 + M5 + M15 + AC35 (대상 소멸 — Task 7): 확증 제품결함 총 순서 표(FAIL >
# NEEDS_RESOLUTION > SKIP_WITH_EVIDENCE > PASS)도 같은 표와 함께 지워졌다 — 우선순위
# 규칙은 verdict.py 의 decide()/CAUSE_TO_REASON 이 코드로 소유한다.

# T21 + M6 + AC12: 재실행은 정확히 1회 (무한 재실행이 false green 경로)
case_skill_rerun_exactly_once() {
  local w; w=$(section_window '**Step R6' '**Step R8')
  if [[ $(count_in "$w" '재실행은 정확히 1회다 — green 이 나올 때까지가 아니다') -eq 1 ]]; then
    ok "재실행 1회 잠금 문장 존재 (body-unique)"
  else no "재실행 1회 문장 부재/중복"; fi
}

# T8 + AC10: bulk green이면 per-unit 재실행을 하지 않는다 (2단 구조)
case_skill_two_stage() {
  local w; w=$(section_window '**Step R5b' '**Step R6')
  local missing=""
  # green 방향(재실행 안 함) — 비용 절약 규칙.
  [[ $(count_in "$w" 'bulk 가 green 이면 per-unit 재실행을 하지 않는다') -ge 1 ]] \
    || missing="$missing green방향"
  # /qg iter-6 (adversarial N2): **red 방향이 무잠금이었다.** green 절반만 잠그면
  # "실패한 unit 을 per-unit 으로 재실행한다" 를 지워도 스위트가 못 본다. 그런데 그
  # 문장이 사라지면 기준선 green + HEAD bulk red 인 shell/unittest 실행에서 **무고한
  # unit 전부가 (P,F)=NEW_REGRESSION → confirmed_product_defect: true → terminal FAIL**
  # 이 되고, terminal FAIL 은 어떤 degrade 로도 내려가지 않는다. 즉 거짓 *terminal*
  # FAIL 이 산문 한 단계 누락 거리에 있었다. 두 방향을 함께 요구한다.
  # red 방향은 **HEAD 측(R5b)** 창에서 잰다 — 거짓 terminal FAIL 이 나는 쪽이 여기다.
  # (R4 도 같은 규칙을 자기 문구로 갖고 있지만, 기준선 축이 red 인 경우는 degrade 로
  # 흡수되므로 그쪽이 빠져도 인증이 늘지 않는다.)
  [[ $(count_in "$w" 'red 일 때만 실패한 unit 에 대해 `per-unit` 으로 재실행한다') -ge 1 ]] \
    || missing="$missing red방향"
  [[ -z "$missing" ]] && ok "2단 구조 **양방향** 명시 (green→재실행 0회 / red→실패분만 per-unit)" \
                      || no "2단 구조 문장 부재:$missing"
}

# T28 + AC19: 계획 산문 6필드가 R2 절에 열거된다
case_skill_plan_prose_six_fields() {
  local w; w=$(section_window '**Step R2' '**Step R3')
  local missing=0 f
  for f in '무엇이 바뀌었나' '어떤 행동에 닿나' '무엇을 돌리나' \
           '비용 신호' '무엇을 안 돌리나' 'CI 와 다르면'; do
    [[ $(count_in "$w" "$f") -ge 1 ]] || { echo "    누락 필드: $f"; missing=1; }
  done
  [[ $missing -eq 0 ]] && ok "계획 산문 6필드 전부 R2에 존재" || no "계획 산문 필드 누락"
  [[ $(count_in "$w" '개 선택 (전체 ') -ge 1 ]] \
    && ok "선택 비율 포맷 \`N개 선택 (전체 M개 중)\`" || no "선택 비율 포맷 부재"
}

# T55 + AC57: 비용 신호는 3단계 범주값이고 숫자 시간 추정을 쓰지 않는다
case_skill_cost_signal_categorical() {
  local w; w=$(section_window '**Step R2' '**Step R3')
  local ok=1 c
  for c in '즉시' '수 분' '설치 포함'; do
    [[ $(count_in "$w" "$c") -ge 1 ]] || { echo "    누락 등급: $c"; ok=0; }
  done
  [[ $ok -eq 1 ]] && ok "비용 등급 3단계 존재" || no "비용 등급 누락"
  # 숫자 시간 추정(예: "약 3분", "5 min")이 R2 절에 없어야 한다.
  # 단위 토큰에 bare `s` 를 넣지 않는다 — "R5b" 같은 식별자를 오탐한다.
  # 빈 윈도우 가드: 앵커가 어긋나 윈도우가 비면 이 **음의** 락은 공허하게 통과한다
  # (양의 락들과 달리 부재를 재는 락이라 스스로 못 알아챈다).
  if [[ -z "$w" ]]; then
    no "R2 윈도우가 비어 있음 — 음의 락이 공허하게 통과할 뻔했다"
  elif printf '%s\n' "$w" | grep -qE '(약[[:space:]]+)?[0-9]+[[:space:]]*(초|분|시간|sec|min|hour)'; then
    no "R2 절에 숫자 시간 추정이 있음"
  else
    ok "숫자 시간 추정 0회 (추정기가 없으므로 지어낸 숫자가 된다)"
  fi
}

# AC20: 갭 게이트는 생략 목록이 **비어 있으면** 발화하지 않는다
case_skill_gap_gate_zero_click() {
  local w; w=$(section_window '**Step R3' '**Step R4')
  if [[ $(count_in "$w" '생략 목록이 비어 있으면 `AskUserQuestion` 을 발화하지 않는다') -ge 1 ]] \
     && [[ $(count_in "$w" 'zero-click') -ge 1 ]]; then
    ok "생략 0 → zero-click 조건 명시"
  else no "zero-click 조건 부재"; fi
}

# T46 + AC49: bulk 어댑터의 커버리지 미보장 공시가 R2와 R8 **양쪽**에 있다
case_skill_bulk_disclosure() {
  local w2 w8
  w2=$(section_window '**Step R2' '**Step R3')
  w8=$(section_window '**Step R8' '## Final Summary')
  if [[ $(count_in "$w2" '커버리지 미보장(러너가 선택을 무시함)') -ge 1 ]] \
     && [[ $(count_in "$w8" '커버리지 미보장(러너가 선택을 무시함)') -ge 1 ]]; then
    ok "bulk 커버리지 미보장 공시가 계획 산문과 보고서 양쪽에"
  else no "bulk 공시 누락 (R2=$(count_in "$w2" '커버리지 미보장(러너가 선택을 무시함)') R8=$(count_in "$w8" '커버리지 미보장(러너가 선택을 무시함)'))"; fi
}

# ── fix round 1 이 닫은 세 개의 fail-open 을 지키는 락 ────────────────────────
# 이 셋은 전부 **산문만** 고친 것이라 리뷰 시점에 회귀 커버리지가 0이었다. 셋 다
# "지워도 스위트가 초록"이면 다음 편집에서 조용히 사라진다 — C1 의 역사가 그 증거다.

# I1 회귀 락: 실패한 대조/집계는 degraded 로 가고 PASS 에 닿지 못한다.
# 오류 행의 두 결론(`degraded` 기록 · PASS 불가)을 **같은 줄에서** 잰다 — 따로 세면
# 표를 쪼개 한쪽만 남겨도 통과한다(값의 부재를 음성 결과로 읽는 바로 그 실패).
case_skill_r6_error_never_passes() {
  local w; w=$(section_window '**Step R6' '**Step R8')
  [[ -n "$w" ]] || { no "R6 윈도우가 비어 있음 (앵커 미스 — 아래 락이 공허해진다)"; return; }
  local bad=0
  [[ $(count_in "$w" '**R6 exit-code routing') -ge 1 ]] \
    || { echo "    누락: R6 exit-code 라우팅 절"; bad=1; }
  [[ $(count_in "$w" '어댑터별 호출과 `--aggregate` 호출 **양쪽**') -ge 1 ]] \
    || { echo "    누락: 두 호출(어댑터별·집계) 모두 커버한다는 명시"; bad=1; }
  printf '%s\n' "$w" | grep -F '그 외 non-zero' | grep -F '**`degraded`** 로 적는다' \
    | grep -qF '캡처 실패를 "결함 없음"으로 읽지 않는다' \
    || { echo "    누락 또는 극성 뒤집힘: 오류 행이 같은 줄에서 degraded + '캡처 실패를 \"결함 없음\"으로 읽지 않는다' 로 라우팅해야 함"; bad=1; }
  [[ $bad -eq 0 ]] && ok "R6: 실패한 대조/집계 → degraded (clean 불가)" \
                   || no "R6 exit-code 라우팅 락 실패"
}

# I2 회귀 락 (대상 소멸 — Task 7): NEEDS_RESOLUTION 해소 루프('Yes, retry'/'Skip
# with evidence' UI, R5a/R7/R9 의존)가 통째로 사라졌다 — 재시도는 이제 fix-loop
# Retry 옵션 하나이고, 대응물 없이 지운다.

# I3 회귀 락 (대상 소멸 — Task 7): fallback working-tree guard(R7 mutation-guard 의
# 읽기전용 폴백 신호)는 R-W 로 파이프라인이 create-sandbox 를 더 안 부르므로
# 이 폴백 시나리오 자체가 없어졌다 — 대응물 없이 지운다.

# AC47: 기준선 트리에서 detect를 **재실행**한다 (HEAD 집합 재사용 금지)
case_skill_both_side_detect() {
  local w; w=$(section_window '**Step R4' '**Step R5b')
  [[ $(count_in "$w" 'HEAD 의 어댑터 집합을 재사용하지 않는다') -ge 1 ]] \
    && ok "기준선 트리 재감지 명시" || no "양측 재감지 문장 부재"
}

# T73 — R4②-a 의 `probe` 스텝에 락 (/qg iter-5 CRITICAL SR1).
#
# 배경: 캐시가 전량 적중이면 R4 의 `run` 이 호출되지 않아 실행-시점 관문이 한 번도
# 돌지 않는다. 그때 `baseline_detected` 의 근거는 `detect`(선언)뿐이고, 심어지거나
# 낡은 `pass` 가 원래 `unrun` → BASELINE_UNRUNNABLE → degraded → PASS 불가였을
# 실행을 STILL_GREEN → closed → **PASS** 로 바꾼다.
#
# 세 축을 각각 잰다 — **호출**(코드 블록) · **소비 규칙**(usable: yes 만 넣는다) ·
# **무조건성**. 셋 중 하나만 재면 나머지가 조용히 빠져도 GREEN 이다. 특히 무조건성:
# 이 파일의 기록상 `~일 때만` 조건이 SR1 의 직접 원인이었으므로(②의 "미적중분이
# 있을 때만"), 같은 최적화가 probe 에 붙는 것을 명시적으로 막는 문장을 잠근다.
case_r4_probe_step_is_locked() {
  local win; win=$(section_window '②-a **감지된 러너마다' '그다음 어댑터마다')
  if [[ -z "$win" ]]; then no "R4②-a 섹션 윈도우가 비었다 (앵커 소실)"; return; fi
  local bad=0
  # ① 실제 호출 — 산문이 아니라 실행 가능한 커맨드가 있어야 한다.
  [[ $(count_in "$win" 'run-test-selection.sh" probe "$baseline_wt" "$runner"') -ge 1 ]] \
    || { bad=1; echo "    (누락) probe 호출 코드 블록"; }
  # ② 소비 규칙 — `usable: yes` 를 **본** 러너만 들어가고, 부재는 통과가 아니다.
  #    needle 로 `usable: yes` 자체를 쓰면 안 된다: 그 토큰은 같은 윈도우의 출처
  #    진술에도 있어서 소비 규칙 문단을 통째로 지워도 GREEN 이었다(실측 — N2 mutation).
  #    body-unique 인 두 문구로 **소비 방향과 fail-closed 방향을 각각** 잰다.
  [[ $(count_in "$win" '를 **본** 러너만') -ge 1 ]] \
    || { bad=1; echo "    (누락) usable:yes 를 본 러너만 넣는다는 소비 규칙"; }
  [[ $(count_in "$win" '부재를 통과로 읽는 경로가 없다') -ge 1 ]] \
    || { bad=1; echo "    (누락) 부재≠통과 (fail-closed) 방향"; }
  # ③ 무조건성 — body-unique 문구. '캐시 적중 여부와 무관하게 항상'은 ② 헤더에도
  #    있으므로 그것으로 재면 ②-a 를 통째로 지워도 통과한다(헤더-satisfiable 함정).
  [[ $(count_in "$win" '조건을 붙이지 않는다') -ge 1 ]] \
    || { bad=1; echo "    (누락) probe 무조건성 선언"; }
  [[ $bad -eq 0 ]] && ok "R4②-a: probe 호출 · 소비 규칙 2방향 · 무조건성 (4축)" \
    || no "R4②-a probe 스텝 결손"
}

# T74 — **`baseline_detected` 의 출처를 `detect` 로 되돌리는 진술이 없다 (∀).**
#
# ∃-검사("어딘가에 probe 라고 적혀 있다")로는 부족하다는 것이 이 브랜치에서 세 번
# 실증됐다 — 좁힌 규칙의 원래 형태가 다른 문장에 인용 가능한 채로 남으면 좁히지
# 않은 것과 같다. 그래서 파일의 **모든** 줄을 본다.
#
# 한정어는 **개념**이지 특정 토큰이 아니다(T68 의 교훈: 토큰만 열거하면 같은 것을
# 다른 이름으로 부른 줄이 위양성이 된다). `detect` 를 언급하면서 출처를 잘못 지정하지
# **않는** 형태는 셋이다 — (a) 진짜 출처인 `probe` 를 함께 말한다, (b) 부정한다
# (`아니`), (c) 불충분하다고 말한다(`뿐`·`부족`·`못`).
case_baseline_detected_source_is_probe_forall() {
  local bad=0 line
  while IFS= read -r line; do
    # 대상: `baseline_detected` 를 다루면서 서브커맨드 `detect` 를 함께 말하는 줄.
    # 백틱을 포함해 매칭한다 — 백틱 없이 'detect' 를 찾으면 `baseline_detected` 의
    # 부분문자열이 스스로 매치해 모든 줄이 대상이 된다(계측기 고장).
    case "$line" in *baseline_detected*|*baseline-detected*) : ;; *) continue ;; esac
    case "$line" in *'`detect`'*) : ;; *) continue ;; esac
    case "$line" in
      *probe*|*아니*|*뿐*|*부족*|*못*) : ;;
      *) bad=$((bad+1)); echo "    (출처 오지정) ${line:0:96}" ;;
    esac
  done < "$SKILL"
  # 양의 짝 — 부정 락은 통째로 지워도 통과한다. 올바른 출처 진술이 실재하는지도 잰다.
  local positive=0
  grep -qF 'probe` 가 기준선 트리에서 **`usable: yes`**' "$SKILL" && positive=1
  if [[ $bad -eq 0 && $positive -eq 1 ]]; then
    ok "baseline_detected 출처 = probe (∀ 위반 0 + 양의 짝 실재)"
  else
    no "출처 진술: 위반 ${bad}줄 · 양의 짝 ${positive}"
  fi
}

# T76 (대상 소멸 — Task 7): R8 의 verdict 결정 표(PASS/SKIP_WITH_EVIDENCE 행) 자체가
# 지워졌다 — floor 5차원 + `verdict_input` 3플래그 + `forced_downgrade` 를 함께
# 요구하는 로직은 이제 `verdict.py` 의 `decide()`(Task 2/3 소유, Python 테스트로 잰다)
# 가 코드로 갖는다. 이 SKILL-문서 스캔 락은 대응물이 없어 지운다.

# T77 — `FLAKY` 는 **귀속 카테고리가 아니다** (/qg iter-5 SF2).
#
# 앞 문장은 재실행 후 green 인 unit 을 `FLAKY` 로 "기록한다"고 적었다. 그 토큰은
# `CATEGORIES` 8종에 없고 `diff-test-results.py` 가 어디서도 내지 않는다 — 그것을
# 찾는 소비자는 영원히 못 찾는다. 8종은 닫힌 집합(AC11)이라 9번째를 더할 수도 없다.
# 두 방향으로 잠근다: 산출물에 없음 + SKILL 이 기록 위치를 실제로 지정함.
case_flaky_is_a_note_not_a_category() {
  local py="$PLUGIN_ROOT/scripts/diff-test-results.py"
  # **코퍼스를 봤다는 positive 가 먼저다 (/qg iter-7, PT5).** 앞 버전은 곧장
  # `if grep -qF 'FLAKY' "$py"` 였는데, `$py` 가 없으면 grep 은 **exit 2**(파일 오류)를
  # 내고 `if` 는 그것을 "매치 없음"과 같은 non-zero 로 읽어 else 로 떨어져 PASS 를
  # 찍었다 — **파일을 통째로 지워도 GREEN**(실측). 이 케이스가 스스로 "두 방향으로
  # 잠근다"고 적은 둘째 방향은 `$SKILL` 을 읽으므로 이 음의 락의 코퍼스를 덮지 못한다.
  # 음의 락은 빈 코퍼스 위에서 언제나 참이다.
  local missing_cat="" c
  if [[ ! -f "$py" ]]; then
    no "diff-test-results.py 부재 ($py) — FLAKY 음의 락이 공허하게 통과할 뻔했다"
  else
    # 8종 닫힌 집합이 실제로 그 파일에 있는가. 이것이 "코퍼스를 읽었다"의 증거이자,
    # 카테고리를 전부 지우는 mutation 을 음의 락 단독이 놓치는 것을 막는 짝이다.
    for c in NEW_REGRESSION NEW_TEST_RED PRE_EXISTING STILL_GREEN \
             SILENT_DROP BASELINE_UNRUNNABLE; do
      grep -qF "$c" "$py" || missing_cat="$missing_cat $c"
    done
    if [[ -n "$missing_cat" ]]; then
      no "산출 스크립트에서 카테고리 누락:$missing_cat (코퍼스가 기대와 다르다)"
    elif grep -qF 'FLAKY' "$py"; then
      no "diff-test-results.py 가 FLAKY 를 언급 — 카테고리 계약(8종)과 충돌"
    else
      ok "산출 스크립트에 FLAKY 0회 + 카테고리 실재 (코퍼스 확인된 음의 락)"
    fi
  fi
  # 양의 짝 — 재실행 규칙이 **기록 위치를 지정**해야 한다. 지정 없이 토큰만 지우면
  # flaky 관측이 아무 데도 안 남는다.
  grep -qF 'derived: flaky' "$SKILL" \
    && ok "SKILL 이 flaky 를 원장 note(derived:)로 기록하도록 지시" \
    || no "flaky 기록 위치 미지정 — 관측이 사라진다"
}

# Fix round 1 (Important #1) — R8 이 원장을 **새로 쓴다**(overwrite)고 지시해야 한다.
# R-AC(② 는 매 iteration 돈다)와 "이어 쓴다"(append)가 함께 있으면 두 번째 iteration
# 부터 5차원 전부가 파일에 두 번 나타나 `check_qa_ledger.py` 가 "두 번 선언됨"으로
# 전부 거부한다(behavioral 확인: test_qa_ledger.sh 의 case_appended_ledger_rejected) —
# Retry 가 있는 실행은 영원히 clean 에 도달하지 못한다. 양+음 쌍으로 잠근다: "이어 쓴다"
# 재도입은 금지(음), "새로 쓴다" 지시는 실재해야 한다(양).
case_ledger_overwrites_not_appends() {
  local w; w=$(section_window '**Step R8' '## Final Summary')
  local bad=0
  if printf '%s\n' "$w" | grep -qF '원장을 이어 쓴다'; then
    bad=1; echo "    (regress) R8 이 원장을 '이어 쓴다'고 지시 — Retry 가 doubled ledger 로 영원히 거부된다"
  fi
  [[ $(count_in "$w" '이어 쓰지 않는다') -ge 1 ]] \
    || { bad=1; echo "    (누락) '이어 쓰지 않는다' 명시 부재"; }
  [[ $bad -eq 0 ]] && ok "R8 원장은 새로 쓴다(overwrite) — 이어 쓰기 재도입 0회" \
                   || no "R8 원장 쓰기 지시 락 실패"
}

# T78 (대상 소멸 — Task 7): `DISABLE_RUNTIME_SANDBOX` 에서도 R4 를 건너뛰던 폴백
# 문단 자체가 differential-test.md 의 R4 에서 통째로 지워졌다(R-V 의 새 kill switch
# `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` 은 ② 전체를 건너뛰지 R4 한
# 스텝만 조건부로 건너뛰지 않는다) — 대응물 없이 지운다. 후계는 Task 8 의
# `test_pipeline_verdict_wiring.sh` 가 kill-switch 배선을 잰다.

for c in case_unclaimed_row_is_produced case_runner_absent_is_distinguishable \
         case_skill_unclaimed_blocks_pass case_skill_runner_absent_blocks_pass \
         case_skill_rerun_exactly_once \
         case_skill_two_stage case_skill_plan_prose_six_fields \
         case_skill_cost_signal_categorical case_skill_gap_gate_zero_click \
         case_skill_bulk_disclosure case_skill_both_side_detect \
         case_skill_r6_error_never_passes \
         case_rinit_discriminator_table case_r4_resolves_discriminator_itself \
         case_same_as_head_never_unqualified \
         case_r4_probe_step_is_locked case_baseline_detected_source_is_probe_forall \
         case_ledger_overwrites_not_appends \
         case_flaky_is_a_note_not_a_category; do
  echo "== $c"; $c
done
finish
