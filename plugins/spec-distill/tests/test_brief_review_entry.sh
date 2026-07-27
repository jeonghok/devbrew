#!/usr/bin/env bash
# Spec B AC1 지원 (V1 보완) — conducting-interview → reviewing-brief 진입 + Step B 실기.
# 기존 종료 조건·Step A 게이트·B-2 4옵션 구조가 **불변**임을 함께 잠근다(회귀 방지).
# Run: bash plugins/spec-distill/tests/test_brief_review_entry.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
CI="$REPO_ROOT/plugins/spec-distill/skills/conducting-interview/SKILL.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }
window() { awk -v pat="$1" '$0 ~ pat {inw=1; next} inw && /^#{3,4} / {exit} inw' "$CI"; }

test -f "$CI" || { note FAIL "SKILL 부재"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }

# --- 진입 블록 -------------------------------------------------------------
grep -qE '^### Step A\.5' "$CI" && note PASS "Step A.5 헤더 존재" || note FAIL "Step A.5 헤더 부재"
WA5="$(window '^### Step A\.5')"
grep -qF 'reviewing-brief' <<<"$WA5" && note PASS "A.5가 reviewing-brief를 지목 (느슨한 substring, defense-in-depth)" || note FAIL "A.5에 reviewing-brief 부재"
# 위 substring 체크는 프로즈 한 줄만으로도 satisfiable하다(실측: invocation 라인 전체를 지워도
# 프로즈의 "`reviewing-brief` skill로 넘깁니다"가 남아 계속 PASS로 읽힌다). load-bearing lock은
# 아래 anchor 체크 — 실제 invocation directive 라인(줄 맨 앞 "Skill spec-distill:reviewing-brief")
# 존재를 직접 확인한다.
grep -qE '^Skill spec-distill:reviewing-brief\b' <<<"$WA5" \
  && note PASS "A.5가 invocation directive 라인을 실제로 포함 (anchor, load-bearing)" \
  || note FAIL "A.5에 invocation directive 라인 부재 (prose mention만으로는 이 assert가 만족되지 않는다)"
grep -qF 'DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW' <<<"$WA5" \
  && note PASS "A.5에 kill switch 경로" || note FAIL "A.5에 kill switch 경로 부재"
# 한 블록만 추가 — A.5가 파이프라인 절차를 복제하면 두 곳 drift가 생긴다
n5="$(wc -l <<<"$WA5" | tr -d ' ')"
[[ "$n5" -le 30 ]] && note PASS "A.5가 한 블록 규모 (${n5} 줄 ≤ 30)" || note FAIL "A.5가 ${n5} 줄 — 파이프라인을 복제했다"
for tok in 'brief-critic' 'merge_brief_review' 'check_verbatim_coverage' 'G1'; do
  grep -qF "$tok" <<<"$WA5" && note FAIL "A.5가 파이프라인 내부('$tok')를 복제" || note PASS "A.5에 '$tok' 없음 (복제 아님)"
done

# --- 핸드오프 변수 3종 (Task 7 cross-task obligation) -----------------------
# reviewing-brief SKILL.md 상태 섹션은 $PAYLOAD·$CODEX_DIR_YAML·$CODEX_FID_YAML을
# "호출자가 진입 시점에 이미 쥐고 넘기는 값"이라 주장한다 — conducting-interview가
# 실제로 이 세 값을 세우지 않으면 그 주장은 overclaim이 된다(V1 cross-task 요건).
for var in 'PAYLOAD=' 'CODEX_DIR_YAML=' 'CODEX_FID_YAML='; do
  grep -qF "$var" <<<"$WA5" && note PASS "A.5가 ${var%=} 값을 확립" || note FAIL "A.5에 ${var%=} 확립 부재"
done
grep -qE 'state_path\.py.*state-root' <<<"$WA5" \
  && note PASS "A.5가 파이프라인과 같은 state-root 리졸버 사용" || note FAIL "A.5의 ROOT 도출이 리졸버와 불일치"
grep -qE 'state_path\.py.*session-id' <<<"$WA5" \
  && note PASS "A.5가 파이프라인과 같은 harness_sid 리졸버 사용" || note FAIL "A.5의 harness_sid 도출이 리졸버와 불일치"

# --- Step A 게이트·종료 조건 불변 (회귀 락) ---------------------------------
grep -qF 'check_brief.py' "$CI" && note PASS "Step A 게이트 보존" || note FAIL "check_brief.py 게이트가 사라졌다"
grep -qF 'floor 5차원' "$CI" && note PASS "종료 driver(floor 5) 보존" || note FAIL "종료 driver 서술 손실"
grep -qF '# confirmed 0건 — 사용자가 전부 잠정으로 판단' "$CI" \
  && note PASS "confirmed 0건 sentinel 보존" || note FAIL "sentinel 문구 손실"

# --- Step B 실기 (4 산출물 + degrade) ---------------------------------------
WB2="$(window '^#### B-2')"
[[ -n "$WB2" ]] && note PASS "B-2 윈도우 존재" || note FAIL "B-2 윈도우 부재"
grep -qF 'AskUserQuestion' <<<"$WB2" && note PASS "B-2 게이트 보존" || note FAIL "B-2 게이트 손실"
n_opt="$(grep -cE '^\s*\{label:' <<<"$WB2" || true)"
[[ "$n_opt" == "4" ]] && note PASS "B-2 4옵션 구조 불변 (${n_opt})" || note FAIL "B-2 옵션이 ${n_opt} 개 (구조 변경)"
for tok in '방향성' 'readback' 'gap' 'degrade'; do
  grep -qF "$tok" <<<"$WB2" && note PASS "B-2 question에 '$tok' 실림 (느슨한 substring, defense-in-depth)" || note FAIL "B-2에 '$tok' 부재"
done
grep -qE 'question 텍스트|question 본문' "$CI" \
  && note PASS "degrade가 question 텍스트에 렌더 (프로즈 서술, defense-in-depth)" || note FAIL "렌더 위치(question 텍스트) 명시 부재"
# 위 두 체크는 어휘(prose가 "degrade"·"question 텍스트"를 언급하는지)만 본다 — §5.6/AC15가
# 요구하는 실제 property는 *배치*(옵션 description이 아니라 question: 문자열 그 자체)다.
# 실측: degrade 렌더를 question:에서 빼 첫 옵션 description으로 옮기고 프로즈는 그대로 둬도
# 위 체크들은 계속 PASS로 읽힌다. load-bearing lock은 question: 라인 그 자체를 지목해 검사한다.
QLINE="$(grep -E '^\s*question:' <<<"$WB2" | head -1)"
[[ -n "$QLINE" ]] && note PASS "B-2 question: 라인 실재" || note FAIL "B-2 question: 라인을 찾지 못함"
grep -qF 'degrade' <<<"$QLINE" \
  && note PASS "B-2 question: 라인이 degrade record를 직접 실음 (placement, load-bearing)" \
  || note FAIL "B-2 question: 라인에 degrade 부재 — 렌더가 description 등 다른 곳으로 이동했을 수 있다"
grep -qE 'degrade 없음' "$CI" && note PASS "빈 배열도 명시" || note FAIL "빈 배열 명시 부재"

# --- P21 canonical 토큰 (checker와 producer가 같은 집합) --------------------
grep -qF '<REDACTED' "$CI" && note PASS "P21 canonical 토큰 명시" || note FAIL "P21 canonical 토큰 부재"

# --- cross-compact / polite stop 가드 불변 ----------------------------------
grep -qE '턴 종료|다음 턴' "$CI" && note PASS "cross-compact 가드 보존" || note FAIL "cross-compact 가드 손실"
grep -qF 'polite stop' "$CI" && note PASS "AP2 가드 보존" || note FAIL "AP2 가드 손실"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ "$fail" -eq 0 ]]
