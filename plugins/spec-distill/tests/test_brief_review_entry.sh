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
grep -qF 'reviewing-brief' <<<"$WA5" && note PASS "A.5가 reviewing-brief를 지목" || note FAIL "A.5에 reviewing-brief 부재"
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
  grep -qF "$tok" <<<"$WB2" && note PASS "B-2 question에 '$tok' 실림" || note FAIL "B-2에 '$tok' 부재"
done
grep -qE 'question 텍스트|question 본문' "$CI" \
  && note PASS "degrade가 question 텍스트에 렌더" || note FAIL "렌더 위치(question 텍스트) 명시 부재"
grep -qE 'degrade 없음' "$CI" && note PASS "빈 배열도 명시" || note FAIL "빈 배열 명시 부재"

# --- P21 canonical 토큰 (checker와 producer가 같은 집합) --------------------
grep -qF '<REDACTED' "$CI" && note PASS "P21 canonical 토큰 명시" || note FAIL "P21 canonical 토큰 부재"

# --- cross-compact / polite stop 가드 불변 ----------------------------------
grep -qE '턴 종료|다음 턴' "$CI" && note PASS "cross-compact 가드 보존" || note FAIL "cross-compact 가드 손실"
grep -qF 'polite stop' "$CI" && note PASS "AP2 가드 보존" || note FAIL "AP2 가드 손실"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ "$fail" -eq 0 ]]
