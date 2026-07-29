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

# --- /qg iter-1 IMPORTANT : 식별자가 아니라 **개념 별칭**으로 스윕 -----------
# 결함: 위 assert들은 $GATE·$REVIEWER 두 경로를 하드코딩해, 같은 주장을 **다른 문구로**
# 하는 세 번째 인스턴스를 구조적으로 볼 수 없었다 — 실제로 reviewing-spec/SKILL.md가
# 현재시제로 "interview는 brief까지 단독 완결, design doc만 Law 2 분리 reviewer 대상"을
# 단언한 채 출하됐고 이 브랜치가 그것을 반증한다. 리터럴이 아니라 개념으로 쓸어야 한다.
#
# 스코프는 **production 파일만**이다(리포 기록: forbidden-string 락이 CHANGELOG·테스트
# 자신을 잡아 2회 재발). CHANGELOG는 과거를 기록하는 것이 정당하고, 이 테스트 파일은
# 검사 문자열을 담아야 하므로 둘 다 제외한다.
# 별칭은 **주장 형태**로 좁힌다. '단독 완결' 단독은 NG7(handoff는 강제가 아니라 사용자
# 선택)의 정당한 어휘와 충돌하고, 'design doc만' 단독은 spec-reviewer가 자기 스코프를
# 옳게 서술한 문장까지 잡는다(둘 다 실측 FP). 잡아야 하는 것은 '**brief에는 분리
# 리뷰어가 없다**'는 주장 하나다.
CONCEPT_ALIASES=('brief까지 단독 완결' 'design doc만 Law 2' 'brief는 검토 대상이 아' 'brief만 단독으로 완결')
sweep_hits=""
while IFS= read -r prod; do
  for alias in "${CONCEPT_ALIASES[@]}"; do
    if grep -qF -- "$alias" "$prod"; then
      sweep_hits="${sweep_hits}
  - ${prod#$REPO_ROOT/} :: '$alias'"
    fi
  done
done < <(find "$SD/skills" "$SD/agents" "$SD/scripts" "$SD/templates" -type f \( -name '*.md' -o -name '*.py' -o -name '*.sh' \) 2>/dev/null)

n_prod="$(find "$SD/skills" "$SD/agents" "$SD/scripts" "$SD/templates" -type f \( -name '*.md' -o -name '*.py' -o -name '*.sh' \) 2>/dev/null | grep -c . || true)"
[[ "$n_prod" -ge 10 ]] \
  && note PASS "NG3-sweep: production 파일 ${n_prod}개를 스캔 (코퍼스 비어 있지 않음)" \
  || note FAIL "NG3-sweep: 스캔 대상이 ${n_prod}개뿐 — 이 스윕이 vacuous하다"
[[ -z "$sweep_hits" ]] \
  && note PASS "NG3-sweep: 별칭 ${#CONCEPT_ALIASES[@]}종이 production에 잔존하지 않음" \
  || note FAIL "NG3-sweep: brief가 분리 리뷰 대상이 아니라는 주장이 아직 살아 있다:$sweep_hits"

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
# `state` 단독 grep은 쓰지 않는다 — check_brief.py에서 모든 매칭이 `statement`이거나
# 이 파일이 그 개념을 설명하는 문맥이다(실측, task-9 이후 bare `state` 1건 존재). 정확 토큰만
# 실제 의존을 가리키므로, 락은 토큰 단위로 건다.
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
