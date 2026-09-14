#!/usr/bin/env bash
# Spec B T12·T13 — NG3 서술 교정 + check_brief.py "brief 파일만 읽는다" 불변식.
# AC16(state 의존 추가 없음) · AC17(NG3 서술 2곳 교정)
# Run: bash plugins/spec-distill/tests/test_brief_review_ng3.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
GATE="$SD/scripts/check_brief.py"
# 역할 경계의 새 소유자 — 옛 design-doc 리뷰어 agent 가 자기 산문으로 지던 경계를,
# 엔진 전환(T7) 이후에는 자리별 프로필의 `ground_truth`·`layer_rubric` 이 진다.
PROF_DESIGN="$SD/references/docreview-profiles/design-doc.md"
PROF_BRIEF="$SD/references/docreview-profiles/brief.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# --- T13 / AC17 : 옛 문구 부재 AND 새 문구 존재 ------------------------------
# 옛 한국어 문구 둘(`brief는 검토 대상이 아닙니다` · `brief는 분리 review 대상이
# 아니다`)은 별도 상수로 두지 않는다 — 그 둘을 쥐던 design-doc 리뷰어 agent 가
# T7 에서 삭제됐고, 같은 **주장**은 아래 개념-별칭 스윕이 production 전량에서 잡는다.
OLD_EN='the brief gets no separated review'

# --- /qg iter-1 IMPORTANT : 식별자가 아니라 **개념 별칭**으로 스윕 -----------
# 결함: 위 assert들은 $GATE 와 리뷰어 파일 두 경로를 하드코딩해, 같은 주장을 **다른 문구로**
# 하는 세 번째 인스턴스를 구조적으로 볼 수 없었다 — 실제로 reviewing-spec/SKILL.md가
# 현재시제로 "interview는 brief까지 단독 완결, design doc만 Law 2 분리 reviewer 대상"을
# 단언한 채 출하됐고 이 브랜치가 그것을 반증한다. 리터럴이 아니라 개념으로 쓸어야 한다.
#
# 스코프는 **production 파일만**이다(리포 기록: forbidden-string 락이 CHANGELOG·테스트
# 자신을 잡아 2회 재발). CHANGELOG는 과거를 기록하는 것이 정당하고, 이 테스트 파일은
# 검사 문자열을 담아야 하므로 둘 다 제외한다.
# 별칭은 **주장 형태**로 좁힌다. '단독 완결' 단독은 NG7(handoff는 강제가 아니라 사용자
# 선택)의 정당한 어휘와 충돌하고, 'design doc만' 단독은 design 자리 리뷰어가 자기
# 스코프를 옳게 서술한 문장까지 잡는다(둘 다 실측 FP). 잡아야 하는 것은 '**brief에는 분리
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
  && ok "NG3-sweep: production 파일 ${n_prod}개를 스캔 (코퍼스 비어 있지 않음)" \
  || no "NG3-sweep: 스캔 대상이 ${n_prod}개뿐 — 이 스윕이 vacuous하다"
[[ -z "$sweep_hits" ]] \
  && ok "NG3-sweep: 별칭 ${#CONCEPT_ALIASES[@]}종이 production에 잔존하지 않음" \
  || no "NG3-sweep: brief가 분리 리뷰 대상이 아니라는 주장이 아직 살아 있다:$sweep_hits"

grep -qiF "$OLD_EN" "$GATE" && no "T13: check_brief.py에 옛 NG3 문구 잔존" \
                            || ok "T13: check_brief.py 옛 문구 부재"
grep -qE 'Law 2 (분리 리뷰|separated review).*(얹|on top|added)' "$GATE" \
  && ok "T13: check_brief.py 새 문구 존재" || no "T13: check_brief.py 새 문구 부재"
grep -qF 'reviewing-brief' "$GATE" \
  && ok "T13: check_brief.py가 후속 리뷰 위치를 가리킴" || no "T13: reviewing-brief 언급 부재"

# --- T13 / AC17 (재조준, T7) : 역할 경계를 **새 소유자**에서 다시 잰다 ---------
#
# 옛 판정은 삭제된 design-doc 리뷰어 agent 안의 옛 문구 셋의 **부재** + 새 문구 둘의
# 존재였다. 그 agent 는 문서 리뷰 엔진 전환으로 사라졌다. 부재 단언은 대상이 사라지면 조용히
# 통과하므로(파일이 없으면 grep 이 실패 → `no` 분기가 아니라 `ok` 분기), 그대로 두면
# 이 절이 통째로 vacuous 해진다.
#
# 경계 자체는 사라지지 않았다 — 자리가 둘(design doc · brief)이고 각 자리의 **정답의
# 출처**와 **검토 항목**이 다르다는 사실이 그것이다. 그것을 소유하는 파일이
# `references/docreview-profiles/{design-doc,brief}.md` 의 `ground_truth`·`layer_rubric`
# 이므로 대상을 그리로 옮긴다. 판정은 존재가 아니라 **분리**다: 두 자리가 같은 정답
# 출처나 같은 검토 항목을 갖게 되면 한 리뷰어가 다른 자리를 대신 보게 된다.
for _p in "$PROF_DESIGN" "$PROF_BRIEF"; do
  [[ -f "$_p" ]] && ok "T13: 프로필 실재 — ${_p#$REPO_ROOT/}" \
                 || { no "T13: 프로필 부재 — ${_p#$REPO_ROOT/} (아래 경계 판정은 잴 대상이 없다)"; finish; exit; }
done

gt_of()  { sed -n 's/^[[:space:]]*ground_truth:[[:space:]]*//p' "$1" | head -1; }
lay_of() { sed -n "s/^[[:space:]]*$2:[[:space:]]*//p" "$1" | head -1; }

GT_D="$(gt_of "$PROF_DESIGN")"; GT_B="$(gt_of "$PROF_BRIEF")"
if [[ -n "$GT_D" && -n "$GT_B" ]]; then
  ok "T13: 두 프로필에서 ground_truth 추출 성공 (양의 짝 — 파일을 실제로 읽었다)"
else
  no "T13: ground_truth 추출 실패 (design='$GT_D' brief='$GT_B') — 프로필 문법이 바뀌었다"
fi
if [[ -n "$GT_D" && "$GT_D" != "$GT_B" ]]; then
  ok "T13: 두 자리의 정답 출처가 다르다 (design=인터뷰 브리프 확정 · brief=사용자 원문)"
else
  no "T13: 두 자리가 같은 ground_truth 를 쓴다 — 자리 경계가 무너졌다"
fi

# 층 2 항목의 분리: 충실도 축(brief 프로필의 층 2 전부)은 brief 자리 소유이고
# design 자리 rubric 에 나타나면 안 된다. 반대 방향도 함께 잰다.
L2_D="$(lay_of "$PROF_DESIGN" layer2)"; L2_B="$(lay_of "$PROF_BRIEF" layer2)"
L1_D="$(lay_of "$PROF_DESIGN" layer1)"; L1_B="$(lay_of "$PROF_BRIEF" layer1)"
if [[ -n "$L2_D" && -n "$L2_B" && -n "$L1_D" && -n "$L1_B" ]]; then
  ok "T13: 네 layer_rubric 목록 추출 성공 (양의 짝)"
else
  no "T13: layer_rubric 추출 실패 — 아래 경계 판정이 공허하다"
fi
leak=""
n_fid=0
for _fid in $(printf '%s' "$L2_B" | tr -d '[]' | tr ',' ' '); do
  n_fid=$((n_fid+1))
  printf '%s' "$L2_D" | grep -qF "$_fid" && leak="$leak $_fid"
done
[[ "$n_fid" -ge 3 ]] \
  && ok "T13: brief 층 2 에서 충실도 축 ${n_fid}개를 읽었다 (아래 부재 판정의 양의 짝)" \
  || no "T13: brief 층 2 에서 충실도 축을 ${n_fid}개만 읽었다 — 아래 부재 판정이 공허하다"
[[ -z "$leak" ]] \
  && ok "T13: 충실도 축(brief 층 2 전부)이 design 자리 rubric 에 없다" \
  || no "T13: design 자리 rubric 이 brief 자리의 충실도 축을 흡수했다:$leak"
leak2=""
for _did in goal_fit architecture tradeoffs; do
  printf '%s' "$L1_B" | grep -qF "$_did" && leak2="$leak2 $_did"
done
[[ -z "$leak2" ]] \
  && ok "T13: 설계 축(goal_fit·architecture·tradeoffs)이 brief 자리 rubric 에 없다" \
  || no "T13: brief 자리 rubric 이 design 자리의 설계 축을 흡수했다:$leak2"

# --- T12 / AC16 : state 의존 부재 (정확 토큰) --------------------------------
# `state` 단독 grep은 쓰지 않는다 — check_brief.py에서 모든 매칭이 `statement`이거나
# 이 파일이 그 개념을 설명하는 문맥이다(실측, task-9 이후 bare `state` 1건 존재). 정확 토큰만
# 실제 의존을 가리키므로, 락은 토큰 단위로 건다.
for tok in 'state.local.md' 'state_path' 'state-root'; do
  grep -qF -- "$tok" "$GATE" && no "T12: check_brief.py가 '${tok}'를 참조 (불변식 위반)" \
                            || ok "T12: check_brief.py에 '${tok}' 부재"
done
grep -qF 'user_statements' "$GATE" && no "T12: check_brief.py가 state 원장 필드를 읽는다" \
                                  || ok "T12: state 원장 필드 부재"
# 불변식이 문서로도 남아야 한다 (다음 세션이 깨뜨리지 않도록)
grep -qE 'brief 파일만|payload.*만 읽' "$GATE" \
  && ok "T12: '브리프 파일만 읽는다' 불변식 서술" || no "T12: 불변식 서술 부재"

# --- audit 템플릿 텔레메트리 -------------------------------------------------
TPL="$SD/templates/interview-audit-template.md"
grep -qE '리뷰 라운드|brief 리뷰' "$TPL" && ok "audit 템플릿에 리뷰 텔레메트리" || no "audit 템플릿 텔레메트리 부재"
grep -qF 'reviewing-brief' "$TPL" && ok "audit 템플릿이 파이프라인을 지목" || no "audit 템플릿에 파이프라인 언급 부재"
# 텔레메트리는 게이트 통과 조건이 아니다 (이빨 없는 체크 도입 금지 — AC22c)
grep -qE '게이트 (통과 )?조건이 아니|기록이며' "$TPL" \
  && ok "텔레메트리가 게이트 조건이 아님을 명시" || no "텔레메트리를 게이트 조건으로 오독 가능"
finish
