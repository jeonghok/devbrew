#!/usr/bin/env bash
# Spec B T12·T13 — NG3 서술 교정 + check_brief.py "brief 파일만 읽는다" 불변식.
# AC16(state 의존 추가 없음) · AC17(NG3 서술 2곳 교정)
# Run: bash plugins/spec-distill/tests/test_brief_review_ng3.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
GATE="$SD/scripts/check_brief.py"
REVIEWER="$SD/agents/spec-reviewer.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# --- T13 / AC17 : 옛 문구 부재 AND 새 문구 존재, 2파일 각각 -----------------
OLD_EN='the brief gets no separated review'
OLD_KO='brief는 검토 대상이 아닙니다'
OLD_KO2='brief는 분리 review 대상이 아니다'

grep -qiF "$OLD_EN" "$GATE" && note FAIL "T13: check_brief.py에 옛 NG3 문구 잔존" \
                            || note PASS "T13: check_brief.py 옛 문구 부재"
grep -qE 'Law 2 (분리 리뷰|separated review).*(얹|on top|added)' "$GATE" \
  && note PASS "T13: check_brief.py 새 문구 존재" || note FAIL "T13: check_brief.py 새 문구 부재"
grep -qF 'reviewing-brief' "$GATE" \
  && note PASS "T13: check_brief.py가 후속 리뷰 위치를 가리킴" || note FAIL "T13: reviewing-brief 언급 부재"

grep -qiF "$OLD_EN" "$REVIEWER" && note FAIL "T13: spec-reviewer.md에 옛 NG3 문구 잔존" \
                                || note PASS "T13: spec-reviewer.md 옛 문구 부재"
grep -qF "$OLD_KO" "$REVIEWER" && note FAIL "T13: spec-reviewer.md 한국어 옛 문구 잔존" \
                               || note PASS "T13: spec-reviewer.md 한국어 옛 문구 부재"
grep -qF "$OLD_KO2" "$REVIEWER" && note FAIL "T13: spec-reviewer.md '분리 review 대상 아님' 잔존" \
                                || note PASS "T13: spec-reviewer.md 부정 서술 부재"
grep -qF 'brief-critic' "$REVIEWER" \
  && note PASS "T13: spec-reviewer.md가 brief 리뷰어를 가리킴" || note FAIL "T13: brief-critic 언급 부재"
# 역할 경계는 유지되어야 한다 — spec-reviewer는 여전히 design doc만 본다
grep -qE 'design doc (only|만)' "$REVIEWER" \
  && note PASS "T13: spec-reviewer 역할 경계 유지 (design doc only)" || note FAIL "T13: 역할 경계 서술 손실"

# --- T12 / AC16 : state 의존 부재 (정확 토큰) --------------------------------
# `state` 단독 grep은 항상 red다 — check_brief.py의 모든 `state` 매칭이 `statement`다(실측).
for tok in 'state.local.md' 'state_path' 'state-root'; do
  grep -qF -- "$tok" "$GATE" && note FAIL "T12: check_brief.py가 '${tok}'를 참조 (불변식 위반)" \
                            || note PASS "T12: check_brief.py에 '${tok}' 부재"
done
grep -qF 'user_statements' "$GATE" && note FAIL "T12: check_brief.py가 state 원장 필드를 읽는다" \
                                  || note PASS "T12: state 원장 필드 부재"
# 불변식이 문서로도 남아야 한다 (다음 세션이 깨뜨리지 않도록)
grep -qE 'brief 파일만|payload.*만 읽' "$GATE" \
  && note PASS "T12: '브리프 파일만 읽는다' 불변식 서술" || note FAIL "T12: 불변식 서술 부재"

# --- audit 템플릿 텔레메트리 -------------------------------------------------
TPL="$SD/templates/interview-audit-template.md"
grep -qE '리뷰 라운드|brief 리뷰' "$TPL" && note PASS "audit 템플릿에 리뷰 텔레메트리" || note FAIL "audit 템플릿 텔레메트리 부재"
grep -qF 'reviewing-brief' "$TPL" && note PASS "audit 템플릿이 파이프라인을 지목" || note FAIL "audit 템플릿에 파이프라인 언급 부재"
# 텔레메트리는 게이트 통과 조건이 아니다 (이빨 없는 체크 도입 금지 — AC22c)
grep -qE '게이트 (통과 )?조건이 아니|기록이며' "$TPL" \
  && note PASS "텔레메트리가 게이트 조건이 아님을 명시" || note FAIL "텔레메트리를 게이트 조건으로 오독 가능"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ "$fail" -eq 0 ]]
