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
    "참고 6건(이번 라운드 새 1 · 반복 1) — 끝에서 한 목록으로 · 선재 절의 새 must-catch 1" \
    "AC5·AC9: 게이트 참고 줄의 값 — 총계 6(라운드 1 의 5 + 새 1) · 새 1 · 반복 1 · 선재 1"
  assert_eq "$(gsum "$d" 'd["advice"] == {"total": 6, "new": 1, "repeat": 1, "mc_preexisting_new": 1}')" "True" \
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
  assert_eq "$(jget "$d/fin.json" 'd["advice_new"], d["advice_repeat"]')" "(5, 0)" "1회 규칙 전제: 라운드 1 finalize 는 새 5 · 반복 0"
  adv_mark "$d"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-mc-r1.txt")" \
    --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep-again.json"
  render_recritic "$d/prep-again.json" "$FX/recritic-mc-r1.txt.tmpl" "$d/recritic-again.txt"
  py docreview_route.py finalize --state-dir "$d" --recritic "$d/recritic-again.txt" --doc "$FX/design-sample.md" > "$d/fin-again.json"
  assert_eq "$(jget "$d/fin-again.json" 'd["advice_new"], d["advice_repeat"]')" "(5, 0)" \
    "1회 규칙: 같은 라운드를 다시 finalize 해도 그 라운드가 올린 버킷은 새로 센다(반복 0)"
  assert_eq "$(st_yaml "$d" 'len(st["advice"]), sorted({(v["shown"], v["sunk"]) for v in st["advice"].values()})')" "(5, [(True, True)])" \
    "1회 규칙: 같은 라운드 재기록은 원장을 늘리지 않고 shown · sunk 를 지우지 않는다"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" --render | grep '^참고 ')" \
    "참고 5건(이번 라운드 새 5 · 반복 0) — 끝에서 한 목록으로 · 선재 절의 새 must-catch 0" \
    "1회 규칙: 재finalize 뒤 게이트 참고 줄도 새 5 · 반복 0"
  rm -rf "$d"
}
case_advice_same_round_duplicate_bucket() {   # 한 라운드 안에서 같은 버킷의 advisory 둘 — 뒤 항목은 반복이다
  local d; d="$(route_r1 "$PROF_MC/design-doc.md" "$FX/design-sample.md" "$FX/critic-mc-dup-bucket.txt" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt")"
  assert_eq "$(jget "$d/fin.json" 'd["advice_new"], d["advice_repeat"], len(d["advice"])')" "(1, 1, 2)" \
    "1회 규칙: 같은 라운드의 같은 버킷 둘 — 둘 다 표지를 달지만 목록에는 하나(새 1 · 반복 1)"
  assert_eq "$(st_yaml "$d" 'len(st["advice"])')" "1" "1회 규칙: 같은 버킷은 원장에 한 줄"
  rm -rf "$d"
}

# ── AC2 — 정의가 fail-closed ─────────────────────────────────────────────────
case_AC2_mustcatch_fail_closed() {
  local d d2 f6 esc; d="$(mc_r1)"
  assert_eq "$(st_yaml "$d" '[st["findings"][i]["category"] for i in st["decides"] if st["findings"][i]["category"] == "made_up_axis"]')" \
    "['made_up_axis']" "AC2: rubric 밖 category 는 must_catch 가 있는 프로필에서도 decides 에 있다"
  assert_eq "$(st_yaml "$d" '[st["findings"][i]["category"] for i in st["fixes"] if st["findings"][i]["category"] == "other"]')" \
    "['other']" "AC2: other 는 fixes 에 있다"
  assert_eq "$(adv_has "$d" "$(fsum "$d" 'AD4:' '["id"]')")" "True" "AC2 대조: advisory 축(overdesign) decide 는 advice 에 있다(여집합이 뒤집히면 RED)"
  mc_round "$d" "$FX/design-sample-r2.md" "$FX/critic-mc-empty.txt" "$d/fin2.json"
  assert_eq "$(st_yaml "$d" 'sorted({st["findings"][i]["category"] for i in st["decides"] if st["findings"][i]["category"] == "frozen_change"}), [v for v in (st.get("advice") or {}).values() if v["category"] == "frozen_change"]')" \
    "(['frozen_change'], [])" "AC2: frozen_change 는 decides 에 있고 advice 에 없다"
  rm -rf "$d"
  d2="$(mc_r1)"; f6="$(fsum "$d2" 'AD6:' '["id"]')"
  py docreview_state.py fix --state-dir "$d2" --id "$f6" --event escalate --reason 'anchor_protected' >/dev/null
  mc_round "$d2" "$FX/design-sample.md" "$FX/critic-mc-empty.txt" "$d2/fin2.json"
  esc="$(id_of "$d2/fin2.json" '상향: AD6')"
  assert_eq "$(st_yaml "$d2" "'$esc' in st['decides'], st['findings']['$esc']['category']") $(adv_has "$d2" "$esc")" "(True, 'ambiguity') False" \
    "AC2: advisory 축 fix 의 check-intent 거부 상향 후속(_source: escalated)은 decides 에 있고 advice 에 없다"
  rm -rf "$d2"
}

# ── AC13 예외 · AC15 — blocks 판정은 대상의 적용 경로로 ─────────────────────────────
case_AC13_blocking_ask_stays() {
  local d f6 f7; d="$(mc_r1)"; f6="$(fsum "$d" 'AD6:' '["id"]')"; f7="$(fsum "$d" 'AD7:' '["id"]')"
  assert_eq "$(st_yaml "$d" "'$f7' in st['asks'], st['asks'].get('$f7', {}).get('blocks')") $(adv_has "$d" "$f7")" "(True, ['$f6']) False" \
    "AC13: fixes 원장 항목을 blocks 로 가리키는 advisory ask 는 asks 에 있다"
  rm -rf "$d"
}
case_AC15_blocks_by_application_path() {
  local d f6 f7 f13 f14 f15; d="$(mc_r1)"
  f6="$(fsum "$d" 'AD6:' '["id"]')"; f7="$(fsum "$d" 'AD7:' '["id"]')"; f13="$(fsum "$d" 'AD13:' '["id"]')"
  f14="$(fsum "$d" 'MC14:' '["id"]')"; f15="$(fsum "$d" 'MC15:' '["id"]')"
  assert_eq "$(gsum "$d" "sorted(d['blocking_ask_open']) == sorted(['$f7', '$f13'])")" "True" \
    "AC15: advisory ask 가 fixes 에 남는 fix 를 막으면 — must-catch fix(①)든 advisory fix(②)든 — 차단 ask 다"
  assert_eq "$(st_yaml "$d" "st['fixes']['$f14']['state'], st['fixes']['$f6']['state']")" "('held', 'held')" \
    "AC15: 그 fix 둘은 held 다 — 질문이 막는 fix 가 답 없이 적용되지 않는다"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_coerced"]') $(st_yaml "$d" "st['asks']['$f15']['blocks']")" "1 []" \
    "AC15: 차단 ask 의 blocks 중 advice 로 간 ref 는 조용히 버려지지 않고 coerced 로 1 세어진다"
  rm -rf "$d"
}

# ── AC14 — 병합 생존자 ───────────────────────────────────────────────────────
case_AC14_merge_survivor() {
  local d s s2; d="$(mc_r1)"; s="$(fsum "$d" 'AD3:' '["id"]')"
  assert_eq "$(st_yaml "$d" "'$s' in st['decides']") $(adv_has "$d" "$s") $(jget "$d/fin.json" 'any("MC2:" in x["summary"] for x in d["findings"])')" "True False False" \
    "AC14: architecture(must-catch · fix) + component_relations(advisory · decide) 병합 생존자는 처분 순위와 무관하게 must-catch 원장(decides)에 있다"
  s2="$(jget "$d/fin.json" '[x["id"] for x in d["findings"] if x["summary"].startswith(("AD18:", "AD19:"))][0]')"
  assert_eq "$(st_yaml "$d" "'$s2' in st['fixes']") $(adv_has "$d" "$s2")" "True False" \
    "AC14: 구성원이 전부 advisory 인 라운드 1 fix 끼리의 병합 생존자는 fixes 에 있다"
  assert_eq "$(adv_py "$PROF_MC/design-doc.md" 'a.member_categories({"f1": {"category": "testing"}, "f2": {"category": "architecture"}, "f3": {"category": "testing"}, "f4": {"category": "scope"}}, ["f1", "f2", "f3"])')" \
    "['architecture', 'testing']" "AC14: 구성원 category 는 live 구성원만 · 중복 없이 · 정렬해 남긴다(live 밖 f4 는 빠진다)"
  rm -rf "$d"
}

# ── AC18 — 라운드 2 의 새 계보 advisory fix ─────────────────────────────────────
case_AC18_round2_new_advisory_fix() {
  local d ra rb; d="$(mc_r1)"
  mc_round "$d" "$FX/design-sample-r2.md" "$FX/critic-mc-r2-fix.txt" "$d/fin2.json"
  ra="$(id_of "$d/fin2.json" 'R2A:')"; rb="$(id_of "$d/fin2.json" 'R2B:')"
  assert_eq "$(adv_has "$d" "$ra") $(st_yaml "$d" "'$ra' in st['fixes']") $(gsum "$d" "'$ra' in d['unapplied_fix']")" "True False False" \
    "AC18: 라운드 2 에서 새 계보의 advisory fix 는 advice 에 있고 승인을 막지 않는다"
  assert_eq "$(st_yaml "$d" "'$rb' in st['fixes'], st['findings']['$rb']['lineage'] != '$rb'") $(gsum "$d" "'$rb' in d['unapplied_fix']")" "(True, True) True" \
    "AC18: 라운드 1 에서 온 계보의 advisory fix(미적용)는 fixes 에 남아 막는다"
  rm -rf "$d"
}

# ── AC8 — 단계별 등식 ─────────────────────────────────────────────────────────
case_AC8_staged_equation() {
  local d out; d="$(mc_r1)"
  out="$(python3 "$FX/ac8_terms.py" "$d/prep.json" "$d/fin.json" 1)"
  assert_eq "$(printf '%s\n' "$out" | head -1)" "[21, 1, 2, 1, 1, 13, 5]" \
    "AC8: 입력 21 · added 1 · 흡수 2 · 기각 1 · drop 1 · 차단 원장 생존자 13 · advice 5 — 각 항이 0 이 아니다"
  assert_eq "$(printf '%s\n' "$out" | tail -1)" "True" "AC8: 입력 + added = 흡수 + 기각 + drop + 생존자 + advice (합계 하한이 아니라 등식)"
  assert_eq "$(jget "$d/fin.json" '[x["f"] for x in d["findings"] if x["summary"].startswith("AA1:")]')" "['a1']" "AC8 전제: 재비판 added 한 건이 finding 에 있다"
  assert_eq "$(jget "$d/fin.json" 'len(d["advice"]), sorted(set(d["advice"]) & set(sum(d["by_disposition"].values(), [])))')" "(5, [])" \
    "AC8: advice 항목 5 는 by_disposition 어느 칸(decide 포함)에도 없다 — 등식의 advice 항과 생존자 항이 겹치지 않는다"
  assert_eq "$(adv_py "$PROF_MC/design-doc.md" 'a.advice_ids([{"id": "x1", "route": "advice"}, {"id": "x2"}, {"id": "x3", "route": "advice"}])')" \
    "['x1', 'x3']" "AC8: advice_ids 는 route: advice 표지를 단 항목의 id 만 순서대로 낸다"
  rm -rf "$d"
}

# ── Review Focus 4 — 없는 f 를 막는 ask ─────────────────────────────────────────
case_advice_dangling_blocks() {
  local d g1 g2; d="$(route_r1 "$PROF_MC/design-doc.md" "$FX/design-sample.md" "$FX/critic-mc-dangling.txt" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt")"
  g1="$(fsum "$d" 'DG1:' '["id"]')"; g2="$(fsum "$d" 'DG2:' '["id"]')"
  assert_eq "$(adv_has "$d" "$g1") $(st_yaml "$d" "'$g2' in st['asks'], st['asks']['$g2']['blocks']")" "True (True, [])" \
    "Review Focus: 대상을 찾을 수 없는 advisory ask 는 advice, must-catch ask 는 asks 에 남는다(없는 ref 는 현행대로 blocks 에서 빠진다)"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_coerced"]')" "0" "Review Focus: 없는 ref 는 advice 대상이 아니라 강제 계수가 늘지 않는다"
  rm -rf "$d"
}

# ── 2 걸음 fix round 1 — blocks 강제가 게이트를 바꾸면 degrade(gate=True) · 판정은 순서와 무관 ───────────
step2_unit() { python3 "$FX/step2_unit.py" "$SCRIPTS" "$1" "$2"; }   # step2_unit <시나리오> <forward|reverse>
case_advice_blocks_coercion_flips_gate() {
  local d k1; d="$(route_r1 "$PROF_MC/design-doc.md" "$FX/design-sample.md" "$FX/critic-mc-gate-coerce.txt" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt")"
  k1="$(fsum "$d" 'GC1:' '["id"]')"
  assert_eq "$(st_yaml "$d" "'$k1' in st['asks'], st['asks']['$k1']['blocks'], len(st['decides'])") $(adv_has "$d" "$(fsum "$d" 'GC2:' '["id"]')")" "(True, [], 0) True" \
    "게이트 강제 전제: must-catch ask 의 유일한 대상이 advice 로 가 blocks 가 비고, 열린 decide 는 없다"
  assert_eq "$(gsum "$d" 'd["round_gate_needed"], d["blocking_ask_open"]')" "(False, [])" \
    "게이트 강제: 강제가 없었다면 차단 ask 였을 질문이 차단에서 빠져 라운드 게이트가 꺼진다 — 이 강제가 게이트 판정을 바꿨다"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_coerced"], d["adjudication_degraded"], [x for x in d["advisory"] if x.startswith("강제(게이트 변경): blocks ")] != []')" "(1, True, True)" \
    "게이트 강제: 그 강제는 gate=True 로 세어져 degrade 로 공시된다(보고서 advisory 에 「강제(게이트 변경)」 줄)"
  assert_eq "$(gsum "$d" '[x for x in d["advisory"] if x.startswith("강제(게이트 변경): blocks ")] != []')" "True" \
    "게이트 강제: 게이트 JSON 의 advisory 에도 같은 공시가 실린다"
  rm -rf "$d"
}
case_advice_step2_order_independent() {
  local s f r
  for s in chain mixed cycle; do
    f="$(step2_unit "$s" forward)"; r="$(step2_unit "$s" reverse)"
    assert_eq "$f" "$r" "2 걸음 순서 무관: 시나리오 $s 는 final 순서를 뒤집어도 결과가 같다"
  done
  assert_eq "$(step2_unit chain forward)" \
    '{"coerced": [["blocks", "b", null, true]], "items": {"a": ["advice", ["b"]], "b": ["advice", ["c"]], "c": ["advice", null], "m": [null, []]}}' \
    "2 걸음 사슬: advisory A → advisory B → advice 는 A · B 둘 다 advice, B 를 막던 must-catch M 의 ref 는 gate=True 강제로 센다"
  assert_eq "$(step2_unit mixed forward)" \
    '{"coerced": [["blocks", "c", null, false]], "items": {"c": ["advice", null], "d": [null, null], "x": [null, ["d"]]}}' \
    "2 걸음 대조: advice 가 아닌 대상이 남으면 강제는 gate=False(차단은 그대로다)"
  assert_eq "$(step2_unit cycle forward)" \
    '{"coerced": [], "items": {"p": [null, ["q"]], "q": [null, ["p"]]}}' \
    "2 걸음 순환: 서로를 막는 advisory ask 는 advice 로 증명되지 않아 차단 쪽에 남는다"
}

# ── advice 서브커맨드 ───────────────────────────────────────────────────────
adv_state() {   # adv_state <n> → 참고 항목 n 개를 가진 design-doc 라운드 1 상태 디렉토리
  local c; c="$(mktemp -t advcritic-XXXXXX)"; python3 "$FX/mk_advice_critic.py" "$1" "$c"
  route_r1 "$PROF_MC/design-doc.md" "$FX/design-sample.md" "$c" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt"
  rm -f "$c"
}
adv_ident() { python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import docreview_advice as a; print(a.review_identity(sys.argv[2]))' "$SCRIPTS" "$1"; }

case_AC6_render_cap() {
  local d out; d="$(adv_state 11)"
  out="$(py docreview_state.py advice --state-dir "$d" --render --cap 8)"
  assert_eq "$(printf '%s\n' "$out" | grep -c '^- \[') $(printf '%s\n' "$out" | grep -c '외 3건') $(printf '%s\n' "$out" | grep -c .)" "8 1 10" \
    "AC6: 11건 → 항목 8줄 + 「외 3건」 한 줄 · 머리 포함 10줄(≤10)"
  rm -rf "$d"; d="$(adv_state 8)"
  out="$(py docreview_state.py advice --state-dir "$d" --render --cap 8)"
  assert_eq "$(printf '%s\n' "$out" | grep -c '^- \[') $(printf '%s\n' "$out" | grep -c '외 ')" "8 0" "AC6: 8건이면 접는 줄이 없다"
  rm -rf "$d"; d="$(adv_state 11)"
  out="$(py docreview_state.py advice --state-dir "$d" --render)"
  assert_eq "$(printf '%s\n' "$out" | grep -c '^- \[') $(printf '%s\n' "$out" | grep -c '외 3건')" "8 1" "AC6: 기본 cap 이 8 이다"
  rm -rf "$d"
}
case_AC7_sink_idempotent() {
  local d b doc before rc; d="$(adv_state 3)"; doc="$(mktemp -t sinkdoc-XXXXXX)"; cp "$FX/design-sample.md" "$doc"
  py docreview_state.py advice --state-dir "$d" --sink "$doc" >/dev/null
  assert_eq "$(awk '/^### Deferred to plan$/{f=1;next} /^#/{f=0} f' "$doc" | grep -c '^| .* | 참고(')" "3" \
    "AC7: --sink 가 ### Deferred to plan 아래에 미박제 항목 3건을 표 행으로 적는다"
  before="$(cksum < "$doc")"; py docreview_state.py advice --state-dir "$d" --sink "$doc" >/dev/null
  assert_eq "$(cksum < "$doc")" "$before" "AC7: 두 번째 --sink 는 아무것도 더 적지 않는다(멱등)"
  b="$(route_r1 "$PROF_MC/brief.md" "$FX/brief-sample.md" "$FX/critic-brief-direction.txt" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt")"
  py docreview_state.py advice --state-dir "$b" --sink "$doc" >/dev/null 2>"$b/err"; rc=$?
  assert_eq "$rc $(grep -c profile_has_no_defer_target "$b/err")" "1 1" "AC7: brief 프로필(defer_target none)은 profile_has_no_defer_target rc 1"
  rm -rf "$d" "$b" "$doc"
}
case_AC17_count_line_carrier() {
  local d e doc id_d; d="$(adv_state 2)"; e="$(adv_state 2)"; doc="$(mktemp -t logdoc-XXXXXX)"; cp "$FX/design-sample.md" "$doc"
  id_d="$(adv_ident "$d")"
  assert_eq "$(adv_ident /r/sess-9/docreview/design-ab12)" "sess-9/design-ab12" \
    "AC17: 리뷰 정체는 <세션>/<문서 키> — 상태 디렉토리의 조부 이름과 자기 이름(문서 키만이면 세션이 빠진다)"
  py docreview_state.py advice --state-dir "$d" --log-file "$doc" >/dev/null
  py docreview_state.py advice --state-dir "$d" --log-file "$doc" >/dev/null
  assert_eq "$(grep -cF -- "- docreview 계수 — $id_d r1: advice_new=2 · advice_repeat=0 · mc_preexisting_new=0" "$doc")" "1" \
    "AC17: 계수 줄이 decision_log 절에 한 번 — 두 번째 호출은 같은 (리뷰 정체, 라운드) 줄을 다시 적지 않는다"
  py docreview_state.py advice --state-dir "$e" --log-file "$doc" >/dev/null
  assert_eq "$(grep -c '^- docreview 계수 — .* r1: ' "$doc")" "2" "AC17: 다른 리뷰 정체의 같은 라운드 줄은 적는다"
  rm -rf "$d" "$e"
  assert_eq "$(grep -cF "docreview 계수 — $id_d r1:" "$doc") $(grep -c '^## 결정 기록$' "$doc")" "1 1" \
    "AC17: 엔진 상태 디렉토리를 지워도 줄이 목적지 파일의 ## 결정 기록 절에 남는다"
  rm -f "$doc"
}
case_advice_render_once() {
  local d; d="$(adv_state 3)"
  py docreview_state.py advice --state-dir "$d" --render >/dev/null
  assert_eq "$(py docreview_state.py advice --state-dir "$d" --render | head -1 | grep -c '^참고(advisory) 0건')" "1" \
    "Review Focus: 두 번째 --render 는 이미 보인 항목을 다시 내지 않는다(shown 표지 — 멱등)"
  assert_eq "$(py docreview_state.py advice --state-dir "$d" | jgets '[it["shown"] for it in d["items"]]')" "[True, True, True]" \
    "Review Focus: 플래그 없는 호출은 읽기 전용 JSON 이고 shown 표지를 싣는다"
  rm -rf "$d"
}
case_advice_pre_upgrade_ledger() {
  local d n rc; d="$(route_r1 "$PROF_MC/design-doc.md" "$FX/design-sample.md" "$FX/critic-mc-empty.txt" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt")"
  python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import docreview_state as s
st = s.load_state(sys.argv[2]); st.pop("advice", None)
for r in st["rounds"].values():
    for k in ("advice_new", "advice_repeat", "mc_preexisting_new"):
        (r.get("route_report") or {}).pop(k, None)
s.save_state(sys.argv[2], st)' "$SCRIPTS" "$d"
  assert_not_contains "$(py docreview_state.py gate --state-dir "$d" --render)" "끝에서 한 목록으로" "Review Focus: 업그레이드 전 원장 — 게이트 렌더에 참고 줄이 없고 죽지 않는다"
  assert_eq "$(py docreview_state.py advice --state-dir "$d" --render | head -1 | grep -c '^참고(advisory) 0건')" "1" "Review Focus: 업그레이드 전 원장 — --render 는 0건"
  n="$(mktemp -t pre-XXXXXX)"; cp "$FX/design-sample.md" "$n"
  py docreview_state.py advice --state-dir "$d" --log-file "$n" >/dev/null; rc=$?
  assert_eq "$rc $(grep -c 'docreview 계수' "$n")" "0 0" "Review Focus: 업그레이드 전 원장 — --log-file 은 계수 줄 0 · rc 0"
  rm -rf "$d" "$n"
  d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  py docreview_state.py advice --state-dir "$d" >/dev/null 2>"$d/err"; rc=$?
  assert_eq "$rc $(grep -c profile_has_no_must_catch "$d/err")" "1 1" "Review Focus: must_catch 없는 프로필의 advice 는 profile_has_no_must_catch rc 1"
  rm -rf "$d"
}
case_advice_odd_text_one_line() {
  local d doc out row; d="$(route_r1 "$PROF_MC/design-doc.md" "$FX/design-sample.md" "$FX/critic-mc-odd.txt" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt")"
  doc="$(mktemp -t odd-XXXXXX)"; cp "$FX/design-sample.md" "$doc"
  out="$(py docreview_state.py advice --state-dir "$d" --sink "$doc" --render)"
  assert_eq "$(printf '%s\n' "$out" | grep -c .) $(printf '%s\n' "$out" | grep -c '^- \[tradeoffs\] #1-context — 파이프 | 가 든 요약이고 둘째 줄로.*…$')" "2 1" \
    "Review Focus: 개행이 든 긴 요약도 렌더 항목은 한 줄이고 60자에서 「…」로 잘린다"
  row="$(awk '/^### Deferred to plan$/{f=1;next} /^#/{f=0} f' "$doc" | grep '참고(tradeoffs)')"
  assert_eq "$(printf '%s\n' "$row" | grep -c .) $(printf '%s\n' "$row" | grep -o '\\|' | wc -l | tr -d ' ')" "1 2" \
    "Review Focus: 박제 행은 한 줄이고 요약 · 대체안의 | 가 \\| 로 이스케이프된다"
  rm -rf "$d" "$doc"
}
case_advice_write_failure_loud() {   # 사용자 문서 쓰기 실패 — rc 1 · 사유를 내고, 적히지 않은 항목에 표지를 켜지 않는다
  local d doc gone rc; d="$(adv_state 2)"; gone="$d/없는-디렉토리/doc.md"
  py docreview_state.py advice --state-dir "$d" --sink "$gone" --render >"$d/out" 2>"$d/err"; rc=$?
  assert_eq "$rc $(grep -c sink_write_failed "$d/err") $(grep -c . "$d/out")" "1 1 0" \
    "쓰기 실패: 박제처에 못 쓰면 rc 1 · sink_write_failed 이고 표시로 넘어가지 않는다"
  assert_eq "$(st_yaml "$d" 'sorted((v["sunk"], v["shown"]) for v in st["advice"].values())')" "[(False, False), (False, False)]" \
    "쓰기 실패: 적히지 않은 항목은 sunk · shown 이 꺼진 채다"
  doc="$(mktemp -t wfail-XXXXXX)"; cp "$FX/design-sample.md" "$doc"
  py docreview_state.py advice --state-dir "$d" --sink "$doc" --log-file "$gone" --render >"$d/out" 2>"$d/err"; rc=$?
  assert_eq "$rc $(grep -c log_write_failed "$d/err") $(grep -c . "$d/out") $(grep -c '| 참고(' "$doc")" "1 1 0 2" \
    "쓰기 실패: 계수 줄을 못 쓰면 rc 1 · log_write_failed — 박제는 이미 적혔고 표시는 하지 않는다"
  assert_eq "$(st_yaml "$d" 'sorted((v["sunk"], v["shown"]) for v in st["advice"].values())')" "[(True, False), (True, False)]" \
    "쓰기 실패: 실제로 적힌 박제 행만 sunk 로 남고 shown 은 꺼진 채다"
  rm -rf "$d" "$doc"
}
case_advice_module_missing() {   # 원장 스크립트만 복사한 트리 — 다른 서브커맨드는 돌고 advice 만 사유를 내고 멈춘다
  local t rc; t="$(mktemp -d -t advlone-XXXXXX)"; cp -L "$SCRIPTS/docreview_state.py" "$t/"
  python3 "$t/docreview_state.py" state-dir-for --root "$t/root" --session s1 --doc "$FX/design-sample.md" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "0" "형제 부재: docreview_advice 가 없어도 원장 스크립트의 다른 서브커맨드는 돈다"
  python3 "$t/docreview_state.py" advice --state-dir "$t" >/dev/null 2>"$t/err"; rc=$?
  assert_eq "$rc $(grep -c advice_module_missing "$t/err")" "1 1" "형제 부재: advice 는 advice_module_missing rc 1 로 멈춘다(traceback 아님)"
  rm -rf "$t"
}
