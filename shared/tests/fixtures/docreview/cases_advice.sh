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

# ── 라우팅 헬퍼 ───────────────────────────────────────────────────────────
adv_has()  { st_yaml "$1" "'$2' in [v['id'] for v in (st.get('advice') or {}).values()]"; }   # adv_has <dir> <id>
adv_cats() { st_yaml "$1" 'sorted(v["category"] for v in (st.get("advice") or {}).values())'; }
id_of()    { jget "$1" "[x['id'] for x in d['findings'] if '$2' in x['summary']][0]"; }       # id_of <fin.json> <요약 조각>
mc_r1() {   # design-doc(must_catch) 라운드 1 — critic-mc-r1 · codex 부재 · recritic-mc-r1 → 상태 디렉토리($d/fin.json)
  route_r1 "$PROF_MC/design-doc.md" "$FX/design-sample.md" "$FX/critic-mc-r1.txt" "$FX/codex-failed.yaml" "$FX/recritic-mc-r1.txt.tmpl"
}
mc_round() {   # mc_round <dir> <doc> <critic> <out-fin> — 다음 라운드를 codex 부재 · 빈 재비판으로 finalize
  next_round "$1" "$2" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$1" --critic "$(critic_now "$1" "$3")" \
    --codex "$(codex_now "$1" "$FX/codex-failed.yaml")" > "$1/prep-next.json"
  py docreview_route.py finalize --state-dir "$1" --recritic "$FX/recritic-empty.txt" --doc "$2" > "$4"
}

# ── AC1 — brief 프로필 fixture 둘 ──────────────────────────────────────────
case_AC1_brief_direction_only() {
  local d; d="$(route_r1 "$PROF_MC/brief.md" "$FX/brief-sample.md" "$FX/critic-brief-direction.txt" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt")"
  assert_eq "$(gsum "$d" 'd["approval_ready"], d["round_gate_needed"]')" "(True, False)" \
    "AC1(i): direction decide 만 나온 라운드 1 — 승인 가능 · 라운드 게이트 없음"
  assert_eq "$(adv_cats "$d")" "['direction']" "AC1(i): direction 은 advice 원장에 있다"
  assert_eq "$(st_yaml "$d" 'len(st["decides"]), len(st["fixes"]), len(st["asks"])')" "(0, 0, 0)" "AC1(i): 차단 원장 셋이 비었다"
  rm -rf "$d"
}
case_AC1_brief_direction_distortion() {
  local d; d="$(route_r1 "$PROF_MC/brief.md" "$FX/brief-sample.md" "$FX/critic-brief-direction-distortion.txt" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt")"
  assert_eq "$(st_yaml "$d" 'sorted(st["findings"][i]["category"] for i in list(st["decides"]) + list(st["fixes"]))')" "['distortion']" \
    "AC1(ii): distortion 은 차단 원장(fixes)에 있다"
  assert_eq "$(gsum "$d" 'd["approval_ready"]')" "False" "AC1(ii): 승인이 막힌다"
  assert_eq "$(adv_cats "$d")" "['direction']" "AC1(ii): direction 은 advice 원장에 있다"
  rm -rf "$d"
}

# ── AC3 양의 짝 — 지목하면 참고 키 · 참고 줄이 선다(음은 골든 12파일이 잰다) ─────
case_AC3_reference_line_positive() {
  local d e; d="$(route_r1 "$PROF_MC/design-doc.md" "$FX/design-sample.md")"; e="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_eq "$(jget "$d/fin.json" '"advice" in d and "advice_new" in d and "mc_preexisting_new" in d')" "True" \
    "AC3(양의 짝): must_catch 를 지목한 프로필의 보고서에 참고 키가 선다"
  assert_grep "$(py docreview_state.py gate --state-dir "$d" --render)" \
    '^참고 [0-9]+건\(이번 라운드 새 [0-9]+ · 반복 [0-9]+\) — 끝에서 한 목록으로' "AC3(양의 짝): 게이트 렌더에 참고 줄이 선다"
  assert_eq "$(jget "$e/fin.json" '"advice" in d or "advice_new" in d')" "False" "AC3(음): 필드 없는 사본 프로필의 보고서에는 참고 키가 없다"
  assert_not_contains "$(py docreview_state.py gate --state-dir "$e" --render)" "끝에서 한 목록으로" "AC3(음): 필드 없는 사본 프로필의 렌더에는 참고 줄이 없다"
  assert_eq "$(st_yaml "$e" '"advice" in st')" "False" "AC3(음): 필드 없는 사본 프로필의 원장에는 advice 키가 없다"
  rm -rf "$d" "$e"
}

# ── AC13(1 걸음 몫) — 라운드 1 advisory fix 는 fixes, 같은 축 decide · (blocks 없는) ask 는 advice ────
case_AC13_advisory_decide_ask_to_advice() {
  local d f6 f20 f21; d="$(mc_r1)"
  f6="$(fsum "$d" 'AD6:' '["id"]')"; f20="$(fsum "$d" 'AD20:' '["id"]')"; f21="$(fsum "$d" 'AD21:' '["id"]')"
  assert_eq "$(st_yaml "$d" "'$f6' in st['fixes']") $(adv_has "$d" "$f6")" "True False" \
    "AC13: 보호 헤딩 밖 ambiguity fix 는 fixes 원장에 있고 advice 에 없다"
  assert_eq "$(adv_has "$d" "$f20") $(adv_has "$d" "$f21")" "True True" "AC13: 같은 축의 decide · ask 는 advice 에 있다"
  assert_eq "$(st_yaml "$d" "st['findings']['$f20']['route'], '$f20' in st['decides'], '$f21' in st['asks']")" "('advice', False, False)" \
    "AC13: advice 항목은 decides · asks 에 없고 finding 에 route: advice 표지가 있다"
  rm -rf "$d"
}

# ── AC19 — 보호 헤딩 승격분 ──────────────────────────────────────────────────
case_AC19_promoted_advisory_fix() {
  local d f8 f9; d="$(route_r1 "$PROF_MC/design-doc.md" "$FX/design-sample.md" "$FX/critic-mc-promoted.txt" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt")"
  f8="$(fsum "$d" 'AD8:' '["id"]')"
  assert_eq "$(fsum "$d" 'AD8:' '["promoted_from"]') $(adv_has "$d" "$f8")" "fix True" \
    "AC19: 보호 헤딩(Goals) 안 advisory fix 는 decide 로 승격된 뒤 advice 에 있다"
  assert_eq "$(gsum "$d" 'd["round_gate_needed"], d["approval_ready"]')" "(False, True)" "AC19: 승격분은 라운드 게이트를 켜지 않는다"
  rm -rf "$d"; d="$(mc_r1)"; f9="$(fsum "$d" 'MC9:' '["id"]')"
  assert_eq "$(st_yaml "$d" "'$f9' in st['decides'], st['findings']['$f9']['promoted_from']")" "(True, 'fix')" \
    "AC19: 같은 자리의 must-catch fix 는 현행대로 decides 로 승격된다"
  rm -rf "$d"
}

# ── AC5 · AC9 — 라운드 2 의 1회 규칙 · 선재 절의 새 must-catch ─────────────────────
case_AC5_AC9_round2() {
  local d rc_ rg rd; d="$(mc_r1)"
  mc_round "$d" "$FX/design-sample-r2.md" "$FX/critic-mc-r2.txt" "$d/fin2.json"
  rc_="$(id_of "$d/fin2.json" 'R2C:')"; rg="$(id_of "$d/fin2.json" 'R2G:')"; rd="$(id_of "$d/fin2.json" 'R2D:')"
  assert_eq "$(jget "$d/fin2.json" 'd["advice_new"], d["advice_repeat"]')" "(1, 1)" \
    "AC5: 라운드 2 — 새 버킷 1(listed) · 라운드 1 에 오른 버킷 1(repeat)"
  assert_eq "$(adv_has "$d" "$rg") $(adv_has "$d" "$rc_") $(st_yaml "$d" "st['findings']['$rc_']['route']")" "True False advice" \
    "AC5: 새 버킷(R2G)은 목록에 오르고, 반복 버킷(R2C)은 목록에 없고 advice 표지만 단다"
  assert_eq "$(jget "$d/fin2.json" 'd["mc_preexisting_new"]')" "1" \
    "AC9: 해시 불변 절(#1-context)의 새 계보 must-catch(R2D)만 센다 — 바뀐 절(R2E) · 계보 후속(R2F)은 세지 않는다"
  assert_eq "$(st_yaml "$d" "'$rd' in st['decides']")" "True" "AC9: 관측은 동작을 바꾸지 않는다 — R2D 는 decides 에 있다"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" --render | grep '^참고 ')" \
    "참고 7건(이번 라운드 새 1 · 반복 1) — 끝에서 한 목록으로 · 선재 절의 새 must-catch 1" \
    "AC5·AC9: 게이트 참고 줄의 값 — 총계 7(라운드 1 의 6 + 새 1) · 새 1 · 반복 1 · 선재 1"
  assert_eq "$(gsum "$d" 'd["advice"] == {"total": 7, "new": 1, "repeat": 1, "mc_preexisting_new": 1}')" "True" \
    "AC5·AC9: gate JSON 의 advice 객체가 보고서 계수 · 원장 크기와 같다"
  rm -rf "$d"
}
case_AC9_child_section_changed() {
  local d; d="$(route_r1 "$PROF_MC/design-doc.md" "$FX/design-sample.md" "$FX/critic-mc-empty.txt" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt")"
  mc_round "$d" "$FX/design-sample-child.md" "$FX/critic-mc-child.txt" "$d/fin2.json"
  assert_eq "$(jget "$d/fin2.json" 'd["mc_preexisting_new"]')" "1" \
    "AC9: 하위 절(5.1)이 바뀐 상위 앵커(#5-architecture)의 새 must-catch 는 선재로 세지 않는다 — 안 바뀐 #1-context 것만 센다"
  rm -rf "$d"
}

# ── 1회 규칙의 멱등 — 같은 라운드를 다시 finalize 해도 그 라운드가 올린 버킷은 반복이 아니다 ──────────
adv_mark() {   # adv_mark <dir> — advice 원장 항목 전부에 shown · sunk 를 켠다(렌더 · 박제가 할 일을 픽스처가 대신한다)
  python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import docreview_state as s
st = s.load_state(sys.argv[2])
for v in st["advice"].values(): v["shown"] = True; v["sunk"] = True
s.save_state(sys.argv[2], st, "fixture: advice shown/sunk")' "$SCRIPTS" "$1"
}
case_advice_same_round_refinalize_idempotent() {
  local d; d="$(mc_r1)"
  assert_eq "$(jget "$d/fin.json" 'd["advice_new"], d["advice_repeat"]')" "(6, 0)" "1회 규칙 전제: 라운드 1 finalize 는 새 6 · 반복 0"
  adv_mark "$d"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-mc-r1.txt")" \
    --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep-again.json"
  render_recritic "$d/prep-again.json" "$FX/recritic-mc-r1.txt.tmpl" "$d/recritic-again.txt"
  py docreview_route.py finalize --state-dir "$d" --recritic "$d/recritic-again.txt" --doc "$FX/design-sample.md" > "$d/fin-again.json"
  assert_eq "$(jget "$d/fin-again.json" 'd["advice_new"], d["advice_repeat"]')" "(6, 0)" \
    "1회 규칙: 같은 라운드를 다시 finalize 해도 그 라운드가 올린 버킷은 새로 센다(반복 0)"
  assert_eq "$(st_yaml "$d" 'len(st["advice"]), sorted({(v["shown"], v["sunk"]) for v in st["advice"].values()})')" "(6, [(True, True)])" \
    "1회 규칙: 같은 라운드 재기록은 원장을 늘리지 않고 shown · sunk 를 지우지 않는다"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" --render | grep '^참고 ')" \
    "참고 6건(이번 라운드 새 6 · 반복 0) — 끝에서 한 목록으로 · 선재 절의 새 must-catch 0" \
    "1회 규칙: 재finalize 뒤 게이트 참고 줄도 새 6 · 반복 0"
  rm -rf "$d"
}
case_advice_same_round_duplicate_bucket() {   # 한 라운드 안에서 같은 버킷의 advisory 둘 — 뒤 항목은 반복이다
  local d; d="$(route_r1 "$PROF_MC/design-doc.md" "$FX/design-sample.md" "$FX/critic-mc-dup-bucket.txt" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt")"
  assert_eq "$(jget "$d/fin.json" 'd["advice_new"], d["advice_repeat"], len(d["advice"])')" "(1, 1, 2)" \
    "1회 규칙: 같은 라운드의 같은 버킷 둘 — 둘 다 표지를 달지만 목록에는 하나(새 1 · 반복 1)"
  assert_eq "$(st_yaml "$d" 'len(st["advice"])')" "1" "1회 규칙: 같은 버킷은 원장에 한 줄"
  rm -rf "$d"
}
