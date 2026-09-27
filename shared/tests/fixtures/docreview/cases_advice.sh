# docreview 참고(advisory) 라우팅 케이스 — 설계 2026-09-27-review-stopping-criterion. 행동 락
# (test_docreview_advice.sh)과 변이 매트릭스(test_docreview_mutations.sh)가 공유한다.
# 계약: cases.sh 를 먼저 source 한다(헬퍼 r1 · route_r1 · next_round · critic_now · codex_now · st_yaml · gsum · jget · fsum ·
#       $PROF_QG). cases.sh 의 케이스는 must_catch 를 뺀 사본($PROF_SD)으로 돌고, 여기 케이스는 실제 프로필($PROF_MC)로 돈다.
PROF_MC="$REPO_ROOT/plugins/spec-distill/references/docreview-profiles"

adv_py() {   # adv_py <프로필> <식> — docreview_advice 를 a, 적재한 프로필을 p 로 놓고 식을 평가해 찍는다
  python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import docreview_advice as a, docreview_state as s
p = s.load_profile(sys.argv[2]); print(eval(sys.argv[3]))' "$SCRIPTS" "$1" "$2"
}

# ── §A advisory 축 = (layer1 ∪ layer2) − must_catch ────────────────────────
case_advice_axes_per_profile() {
  assert_eq "$(adv_py "$PROF_MC/brief.md" 'sorted(a.advisory_axes(p))')" "['direction', 'overdesign']" \
    "§A: brief 의 advisory 축은 direction · overdesign"
  assert_eq "$(adv_py "$PROF_MC/design-doc.md" 'sorted(a.advisory_axes(p))')" \
    "['ambiguity', 'approaches_comparison', 'component_relations', 'data_flow', 'feasibility', 'handoff_incomplete', 'isolation', 'overdesign', 'placeholder', 'scope_creep', 'testing', 'tradeoffs']" \
    "§A: design-doc 의 advisory 축은 층 1 나머지 다섯 + 층 2 일곱"
  assert_eq "$(adv_py "$PROF_MC/seed.md" 'sorted(a.advisory_axes(p)), a.has_must_catch(p)')" "([], True)" \
    "§A: seed 는 advisory 축이 없고 지목은 있다(참고 줄 · 계수 키는 선다)"
  assert_eq "$(adv_py "$PROF_QG/generic.md" 'sorted(a.advisory_axes(p)), a.has_must_catch(p)')" "([], False)" \
    "§A: 필드 없는 프로필(qg generic)은 advisory 축이 공집합 — 라우팅 현행"
}
case_advice_engine_items_mustcatch() {
  assert_eq "$(adv_py "$PROF_MC/design-doc.md" '[a.is_advisory({"category": "ambiguity", "_source": s}, a.advisory_axes(p)) for s in ("critic", "codex", "recritic", "diff", "reraise", "escalated")]')" \
    "[True, True, True, False, False, False]" \
    "§A: 엔진 자동 생성 항목(diff · reraise · escalated)은 category 와 무관하게 must-catch — 호출 순서에 기대지 않는다"
  assert_eq "$(adv_py "$PROF_MC/design-doc.md" '[a.is_advisory(it, a.advisory_axes(p)) for it in ({"category": "other"}, {"category": "frozen_change"}, {"category": "made_up_axis"}, {"category": "goal_fit"}, {"category": "ambiguity", "_member_categories": ["ambiguity", "architecture"]}, {"category": "ambiguity", "_member_categories": ["ambiguity", "testing"]})]')" \
    "[False, False, False, False, False, True]" \
    "§A·§B: rubric 밖 · other · frozen_change · must-catch 축 · must-catch 구성원이 낀 병합 생존자는 must-catch, 전부 advisory 인 병합은 advisory"
}
