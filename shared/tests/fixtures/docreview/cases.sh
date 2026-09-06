# docreview 행동 케이스 — 행동 락(test_docreview_*.sh)과 mutation 락(test_docreview_mutations.sh)이 공유한다.
# 계약: 이 파일을 source 하기 전에 REPO_ROOT · SCRIPTS 가 정의돼 있어야 하고 assert.sh 가 로드돼 있어야 한다.
#       각 case_* 는 자기 임시 디렉토리를 만들고 끝에 지운다. 관측은 assert_* 로만 낸다.
FX="$REPO_ROOT/shared/tests/fixtures/docreview"
PROF_SD="$REPO_ROOT/plugins/spec-distill/references/docreview-profiles"
PROF_QG="$REPO_ROOT/plugins/quality-gates/references/docreview-profiles"
export PYTHONDONTWRITEBYTECODE=1

py()   { python3 "$SCRIPTS/$1" "${@:2}"; }                      # py <script> <args…>
jget() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$1" "$2"; }
jgets(){ python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); print(eval(sys.argv[1]))' "$1"; }
mk_state() {   # mk_state <doc> <profile>  → prints state dir (init 까지)
  local d; d="$(mktemp -d -t docreview-XXXXXX)" || return 1
  py docreview_state.py init --state-dir "$d" --doc "$1" --profile "$2" >/dev/null || { echo "$d"; return 1; }
  echo "$d"
}
snap() { py docreview_anchor.py snapshot "$1" > "$2"; }         # snap <doc> <out.json>

# ── T37 — 상한 2 와 추가 라운드 ───────────────────────────────────────────
case_T37_cap_and_extra() {
  local d s; d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "T37: init 실패"; return; }
  s="$d/snap.json"; snap "$FX/design-sample.md" "$s"
  local r1 r2 r3 r4 r4b
  r1="$(py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" | jgets 'd["rereview_count"]')"
  r2="$(py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" | jgets 'd["rereview_count"]')"
  r3="$(py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" | jgets 'd["rereview_count"]')"
  assert_eq "$r1 $r2 $r3" "0 1 2" "T37: rereview_count 는 라운드 1·2·3 에서 0·1·2"
  py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" >/dev/null 2>&1; r4=$?
  assert_eq "$r4" "3" "T37: 라운드 4 는 승인 없이 rc 3 (cap_reached)"
  r4b="$(py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" --extra-approval '사용자: 한 라운드 더' | jgets 'd["round"]')"
  assert_eq "$r4b" "4" "T37: --extra-approval 이 있으면 라운드 4 가 열린다"
  local nx; nx="$(python3 "$FX/st_get.py" "$d/docreview-state.md" 'len(st["extra_rounds"]), st["extra_rounds"][0]["round"], st["rereview_count"]')"
  assert_eq "$nx" "(1, 4, 2)" "T37: extra_rounds 에 개별 기록 1건(round 4), 카운터는 2 에 머문다"
  rm -rf "$d"
}

# ── 앵커 (Task 4) ─────────────────────────────────────────────────────────
case_anchor_snapshot_shape() {
  local out; out="$(py docreview_anchor.py snapshot "$FX/design-sample.md")"
  assert_eq "$(printf '%s' "$out" | jgets '",".join(s["anchor"] for s in d["sections"])')" \
    "#__preamble__,#1-context,#2-goals,#3-non-goals,#5-architecture,#51-parts,#11-acceptance-criteria,#12-files-to-modify,#handoff-context,#deferred-to-plan" \
    "snapshot: 앵커 목록이 문서 순서·slug 규칙과 같다(머리말 포함)"
  assert_eq "$(printf '%s' "$out" | jgets '[s for s in d["sections"] if s["anchor"]=="#51-parts"][0]["parents"]')" "['#5-architecture']" "snapshot: ### 의 parents 는 직전 ##"
  assert_eq "$(printf '%s' "$out" | jgets 'all(len(s["hash"])==12 for s in d["sections"]) and d["headingless"]==False')" "True" "snapshot: 해시 12자 · headingless false"
}
case_anchor_slug_rules() {
  local out; out="$(py docreview_anchor.py snapshot "$FX/slug-sample.md")"
  assert_eq "$(printf '%s' "$out" | jgets '",".join(s["anchor"] for s in d["sections"])')" \
    "#제목,#51-물리-배치--shareddocreview-정본--심볼릭-링크,#notes,#notes-1" \
    "slug: GitHub 규칙(구두점 제거·연속 하이픈 유지) · 펜스 안 # 무시 · 중복 -1"
}
case_T44_headingless() {
  local s; s="$(mktemp -t hl-XXXXXX)"; py docreview_anchor.py snapshot "$FX/headingless.md" > "$s"
  assert_eq "$(jget "$s" 'd["headingless"], [x["anchor"] for x in d["sections"]]')" "(True, ['#__doc__'])" "T44: 헤딩 0 → headingless + 문서 전체 앵커 하나"
  local dd; dd="$(py docreview_anchor.py diff "$s" "$s" | jgets 'd["headingless"], d["changed"]')"
  assert_eq "$dd" "(True, [])" "T44: headingless diff 는 changed 를 내지 않는다(얼림 비활성)"
  rm -f "$s"
}
# [Task 2+4 실행 노트 — ruling R8] 위 케이스의 둘째 단언은 같은 스냅샷을 자기 자신과
# diff 한다(`diff "$s" "$s"`). `old == new` 라 `changed=[]` 는 문서 종류와 무관하게
# 항상 보장되므로, 이 단언은 「얼림 비활성」을 실제로 재지 않는다 — `diff_snapshots` 의
# `if headingless:` 분기를 통째로 지워도 여전히 통과한다(자기-자신 diff 는 애초에 해시가
# 같아 `rec()` 이 한 번도 안 불린다). brief 원문을 그대로 두고(재발견 금지), 실제로 얼림
# 경로를 지나는 케이스를 아래에 더한다 — **서로 다른** 두 headingless 픽스처를 diff 해
# 변경이 `changed` 가 아니라 `exempt_applied` 로 가고 `scope` 가 `"#__doc__"` 인지 본다.
case_T44b_headingless_freeze_inactive() {
  local a b; a="$(mktemp -t hla-XXXXXX)"; b="$(mktemp -t hlb-XXXXXX)"
  snap "$FX/headingless.md" "$a"; snap "$FX/headingless-r2.md" "$b"
  local dd; dd="$(py docreview_anchor.py diff "$a" "$b" | jgets 'd["headingless"], d["changed"], [e["scope"] for e in d["exempt_applied"]]')"
  assert_eq "$dd" "(True, [], ['#__doc__'])" "T44b: 서로 다른 headingless 문서 간 변경은 changed 가 아니라 exempt_applied(scope #__doc__) 로 간다(얼림 실제 경로)"
  rm -f "$a" "$b"
}
case_anchor_diff_and_exempt() {
  local a b; a="$(mktemp -t s1-XXXXXX)"; b="$(mktemp -t s2-XXXXXX)"
  snap "$FX/design-sample.md" "$a"; snap "$FX/design-sample-r2.md" "$b"
  local out; out="$(py docreview_anchor.py diff "$a" "$b")"
  assert_eq "$(printf '%s' "$out" | jgets 'sorted(c["anchor"] for c in d["changed"])')" "['#12-files-to-modify', '#2-goals']" "diff: 바뀐 두 섹션만 (kind modified)"
  assert_grep "$(printf '%s' "$out" | jgets 'd["changed"][0]["evidence"]')" 'hash [0-9a-f]{12}→[0-9a-f]{12}' "diff: evidence 에 해시 전후가 실린다"
  local ex; ex="$(mktemp -t ex-XXXXXX)"; echo '["#12-files-to-modify"]' > "$ex"
  out="$(py docreview_anchor.py diff "$a" "$b" --exempt "$ex")"
  assert_eq "$(printf '%s' "$out" | jgets '[c["anchor"] for c in d["changed"]], [e["scope"] for e in d["exempt_applied"]]')" "(['#2-goals'], ['#12-files-to-modify'])" "diff: exempt 는 changed 에서 빠지고 exempt_applied 로 간다"
  rm -f "$a" "$b" "$ex"
}
case_anchor_insert_after() {
  local a b ex t; t="$(mktemp -t ia-XXXXXX.md)"
  awk '{print} /^- 범위 밖 C$/{print ""; print "## 4. 새 절"; print ""; print "삽입된 절."}' "$FX/design-sample.md" > "$t"
  a="$(mktemp -t s1-XXXXXX)"; b="$(mktemp -t s2-XXXXXX)"; snap "$FX/design-sample.md" "$a"; snap "$t" "$b"
  ex="$(mktemp -t ex-XXXXXX)"; echo '["insert-after:#3-non-goals"]' > "$ex"
  local out; out="$(py docreview_anchor.py diff "$a" "$b" --exempt "$ex")"
  assert_eq "$(printf '%s' "$out" | jgets '[c["anchor"] for c in d["changed"]], [(e["anchor"],e["scope"]) for e in d["exempt_applied"]]')" \
    "([], [('#4-새-절', 'insert-after:#3-non-goals')])" "diff: insert-after 는 #x 바로 뒤 새 앵커 하나만 면제"
  rm -f "$a" "$b" "$ex" "$t"
}
case_anchor_protected_cascade() {
  local s; s="$(mktemp -t sp-XXXXXX)"; snap "$FX/design-sample.md" "$s"
  local p; p="$PROF_SD/design-doc.md"
  assert_eq "$(py docreview_anchor.py protected '#2-goals' --profile "$p" --snapshot "$s" | jgets 'd["protected"], d["immutable"], d["fix_allowed"]')" "(True, False, True)" "protected: Goals 는 보호 부류"
  assert_eq "$(py docreview_anchor.py protected '#51-parts' --profile "$p" --snapshot "$s" | jgets 'd["protected"]')" "True" "protected: Architecture 의 하위 절도 보호(캐스케이드, P5)"
  assert_eq "$(py docreview_anchor.py protected '#12-files-to-modify' --profile "$p" --snapshot "$s" | jgets 'd["protected"]')" "False" "protected: Files 는 보호 아님"
  rm -f "$s"; s="$(mktemp -t sp-XXXXXX)"; snap "$FX/brief-sample.md" "$s"; p="$PROF_SD/brief.md"
  assert_eq "$(py docreview_anchor.py protected '#6-사용자-원문' --profile "$p" --snapshot "$s" | jgets 'd["immutable"], d["fix_allowed"]')" "(True, False)" "protected: brief §6 은 immutable 이고 fix 불가"
  assert_eq "$(py docreview_anchor.py protected '#2-제약' --profile "$p" --snapshot "$s" | jgets 'd["immutable"], d["fix_allowed"], d["protected"]')" "(False, True, False)" "protected: brief §2 는 fix 가능"
  assert_eq "$(py docreview_anchor.py protected '#1-goal' --profile "$p" --snapshot "$s" | jgets 'd["protected"], d["fix_allowed"]')" "(True, False)" "protected: brief §1 Goal 은 보호 부류"
  rm -f "$s"
}
case_anchor_refs() {
  assert_eq "$(py docreview_anchor.py refs '#12-files-to-modify' "$FX/design-sample.md" | jgets 'd["refs"], d["sections"]')" "(1, ['#5-architecture'])" "refs: Architecture 가 #12 를 링크로 인용한다 → 1"
}

# ── 상태 전이 (Task 5) ─────────────────────────────────────────────────────
# finding 을 손으로 심는다 — 라우터가 붙이는 필드까지 채운 최종 모양이다.
seed_findings() {   # seed_findings <state-dir> <json-text>
  local f; f="$(mktemp -t seed-XXXXXX.json)"; printf '%s' "$2" > "$f"
  py docreview_state.py record-findings --state-dir "$1" --json "$f" >/dev/null; local rc=$?; rm -f "$f"; return $rc
}
F_DEC='{"id":"aaaa0001#r1.1","lineage":"aaaa0001#r1.1","bucket":"aaaa0001","origin":"reviewer","layer":2,"category":"ambiguity","anchor":"#12-files-to-modify","edit_scope":"#12-files-to-modify","disposition":"decide","summary":"파일 목록이 두 가지로 읽힌다","evidence":"12행","blocks":[],"kind":"pre"}'
F_FIX='{"id":"bbbb0001#r1.1","lineage":"bbbb0001#r1.1","bucket":"bbbb0001","origin":"reviewer","layer":2,"category":"placeholder","anchor":"#12-files-to-modify","edit_scope":"#12-files-to-modify","disposition":"fix","summary":"c.py 가 빠졌다","evidence":null,"blocks":[]}'
F_ASK='{"id":"cccc0001#r1.1","lineage":"cccc0001#r1.1","bucket":"cccc0001","origin":"reviewer","layer":2,"category":"ambiguity","anchor":"#12-files-to-modify","edit_scope":"#12-files-to-modify","disposition":"ask","summary":"b.py 를 유지하나?","evidence":null,"blocks":["bbbb0001#r1.1"]}'
F_POST='{"id":"dddd0001#r2.1","lineage":"dddd0001#r2.1","bucket":"dddd0001","origin":"auto","layer":2,"category":"frozen_change","anchor":"#12-files-to-modify","edit_scope":"#12-files-to-modify","disposition":"decide","summary":"finding 없이 바뀜","evidence":"hash a→b","blocks":[],"kind":"post","prev_hash":"PREV"}'
st_yaml() {   # st_yaml <state-dir> <python-expr over st>   — heredoc-in-$() 파싱 함정을 피해 파일로 둔다
  python3 "$FX/st_get.py" "$1/docreview-state.md" "$2"
}
r1() {   # r1 <profile> <doc> → state dir with round 1 begun
  local d s; d="$(mk_state "$2" "$1")" || return 1; s="$d/s1.json"; snap "$2" "$s"
  py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" >/dev/null; echo "$d"
}
next_round() {   # next_round <state-dir> <doc-for-this-round> [extra-quote]  → prints diff json path
  local d="$1" n; n="$(st_yaml "$d" 'st["round"]+1')"; snap "$2" "$d/s$n.json"
  if [ -n "${3:-}" ]; then py docreview_state.py begin-round --state-dir "$d" --snapshot "$d/s$n.json" --extra-approval "$3" >/dev/null
  else py docreview_state.py begin-round --state-dir "$d" --snapshot "$d/s$n.json" >/dev/null; fi
  py docreview_state.py exempt-anchors --state-dir "$d" > "$d/ex$n.json"
  py docreview_anchor.py diff "$d/s$((n-1)).json" "$d/s$n.json" --exempt "$d/ex$n.json" > "$d/diff$n.json"
  py docreview_state.py observe-diff --state-dir "$d" --diff "$d/diff$n.json" > "$d/obs$n.json"
  echo "$d/diff$n.json"
}
case_T18_adopt_issues_permit() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  local out; out="$(py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택')"
  assert_eq "$(printf '%s' "$out" | jgets 'd["state"], d["permit"]["apply_anchors"], d["permit"]["round"], d["permit"]["kind"]')" "('adopted', ['#12-files-to-modify'], 2, 'apply')" "T18: 채택 → adopted + apply permit(round n+1)"
  assert_eq "$(st_yaml "$d" 'len(st["decision_log"]), st["decision_log"][0]["choice"], st["decision_log"][0]["quote"]')" "(1, 'adopt', '채택')" "T18: 결정 기록 1건 verbatim"
  rm -rf "$d"
}
case_T19_reject_closes() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice reject --quote '기각한다' >/dev/null
  assert_eq "$(st_yaml "$d" 'st["decides"]["aaaa0001#r1.1"]["state"], st["rejected_lineages"]["aaaa0001#r1.1"]["by"]')" "('rejected', 'user')" "T19: 기각 → rejected + 계보 기각 기록(by user)"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["open_decide"], d["approval_ready"]')" "([], True)" "T19: 기각된 decide 는 열린 것이 아니다"
  rm -rf "$d"
}
case_T20_hold_becomes_ask() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice hold --quote '나중에' >/dev/null
  assert_eq "$(st_yaml "$d" 'st["decides"]["aaaa0001#r1.1"]["state"], st["findings"]["aaaa0001#r1.1"]["disposition"], "aaaa0001#r1.1" in st["asks"]')" "('held', 'ask', True)" "T20: 보류 → held, finding 은 ask 로 내려가 승인 게이트로"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["approval_ready"], d["asks_open"]')" "(True, ['aaaa0001#r1.1'])" "T20: 보류된 것은 승인을 막지 않고 asks_open 에 보인다"
  rm -rf "$d"
}
case_T21_permit_applied() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' >/dev/null
  local df; df="$(next_round "$d" "$FX/design-sample-r2.md")"
  assert_eq "$(jget "$d/ex2.json" '"#12-files-to-modify" in d')" "True" "T21·AC6b: 채택된 permit 앵커가 라운드 2 얼림 예외에 든다(permit 없는 같은 앵커 변경은 T35 가 auto decide 로 잰다)"
  assert_eq "$(jget "$df" '[c["anchor"] for c in d["changed"]], [e["anchor"] for e in d["exempt_applied"]]')" "(['#2-goals'], ['#12-files-to-modify'])" "T21: permit 앵커의 변경은 changed 가 아니다(예외 ②)"
  assert_eq "$(jget "$d/obs2.json" 'd["applied"], d["progress"]')" "(['aaaa0001#r1.1'], 1)" "T21: 변경 관측 → applied, progress 1"
  assert_eq "$(st_yaml "$d" 'st["decides"]["aaaa0001#r1.1"]["state"], list(st["permits"].values())[0]["consumed"]')" "('applied', True)" "T21: 상태 applied · permit 소모"
  rm -rf "$d"
}
case_T22_permit_expired_reraise() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null       # 변경 없음
  assert_eq "$(jget "$d/obs2.json" 'd["expired"], [r["finding_id"] for r in d["reraise"]]')" "(['aaaa0001#r1.1'], ['aaaa0001#r1.1'])" "T22: 변경 없음 → expired + 같은 계보 재상승 예약"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["approval_ready"]')" "False" "T22: expired 는 승인을 막는다(열린 계보)"
  rm -rf "$d"
}
case_T23_post_adopt_applied() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; next_round "$d" "$FX/design-sample-r2.md" >/dev/null
  seed_findings "$d" "[$F_POST]"
  py docreview_state.py decide --state-dir "$d" --id 'dddd0001#r2.1' --choice adopt --quote '이 변경 승인' >/dev/null
  assert_eq "$(st_yaml "$d" 'st["decides"]["dddd0001#r2.1"]["state"], st["rounds"]["2"]["progress"], len(st["permits"])')" "('applied', 0, 0)" "T23: 사후 decide 채택 → 즉시 applied, permit 없음, progress 불변(P13)"
  rm -rf "$d"
}
case_T24_post_reject_revert_permit() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; next_round "$d" "$FX/design-sample-r2.md" >/dev/null
  seed_findings "$d" "[$F_POST]"
  local out; out="$(py docreview_state.py decide --state-dir "$d" --id 'dddd0001#r2.1' --choice reject --quote '원복하라')"
  assert_eq "$(printf '%s' "$out" | jgets 'd["state"], d["permit"]["kind"], d["permit"]["expect_hash"], d["permit"]["round"]')" "('adopted', 'revert', 'PREV', 3)" "T24: 사후 decide 기각 → 원복 permit(expect_hash = 변경 전)"
  rm -rf "$d"
}
_post_with_real_hash() {   # 실제 r1 해시를 prev_hash 로 갖는 post finding 을 심는다 → echo state dir
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; next_round "$d" "$FX/design-sample-r2.md" >/dev/null
  local h; h="$(jget "$d/s1.json" '[s["hash"] for s in d["sections"] if s["anchor"]=="#12-files-to-modify"][0]')"
  seed_findings "$d" "[${F_POST/PREV/$h}]"
  py docreview_state.py decide --state-dir "$d" --id 'dddd0001#r2.1' --choice reject --quote '원복하라' >/dev/null
  echo "$d"
}
case_T25_revert_observed() {
  local d; d="$(_post_with_real_hash)"; next_round "$d" "$FX/design-sample-r3.md" >/dev/null   # r3 = #12 를 r1 로 되돌림
  assert_eq "$(jget "$d/obs3.json" 'd["applied"], d["progress"]')" "(['dddd0001#r2.1'], 1)" "T25: 해시 복원 관측 → applied(원복 완료)"
  rm -rf "$d"
}
case_T26_revert_missed_reraise() {
  local d; d="$(_post_with_real_hash)"; next_round "$d" "$FX/design-sample-r2.md" >/dev/null   # 그대로
  assert_eq "$(jget "$d/obs3.json" 'd["expired"], len(d["reraise"])')" "(['dddd0001#r2.1'], 1)" "T26: 원복 안 됨 → expired + 재상승"
  rm -rf "$d"
}
case_T27_intent_pass_records_scope() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
  py docreview_state.py fix --state-dir "$d" --id 'bbbb0001#r1.1' --event intent-pass --scope '#12-files-to-modify' >/dev/null
  assert_eq "$(st_yaml "$d" 'st["fixes"]["bbbb0001#r1.1"]["state"], st["applied_scopes"][0]["scope"], st["applied_scopes"][0]["round"]')" "('intent_passed', '#12-files-to-modify', 1)" "T27: intent-pass → intent_passed + applied_scopes(round 1)"
  rm -rf "$d"
}
case_T29_fix_applied() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
  py docreview_state.py fix --state-dir "$d" --id 'bbbb0001#r1.1' --event intent-pass --scope '#12-files-to-modify' >/dev/null
  local df; df="$(next_round "$d" "$FX/design-sample-r2.md")"
  assert_eq "$(jget "$df" '[c["anchor"] for c in d["changed"]]')" "['#2-goals']" "T29: applied_scopes 의 앵커는 얼림 예외 ①"
  assert_eq "$(jget "$d/obs2.json" 'd["applied"], d["progress"]')" "(['bbbb0001#r1.1'], 1)" "T29: scope 변경 관측 → fix applied"
  rm -rf "$d"
}
case_T30_fix_unapplied_counts() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
  py docreview_state.py fix --state-dir "$d" --id 'bbbb0001#r1.1' --event intent-pass --scope '#12-files-to-modify' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["unapplied_fix"], d["approval_ready"]')" "(['bbbb0001#r1.1'], False)" "T30: 통과했으나 미적용 fix 는 승인을 막는다"
  rm -rf "$d"
}
case_T31_T34_blocked_fix_held_gate_opens() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX,$F_ASK]"
  local g; g="$(py docreview_state.py gate --state-dir "$d")"
  assert_eq "$(printf '%s' "$g" | jgets 'd["held_fix"], d["unapplied_fix"], d["blocking_ask_open"], d["round_gate_needed"], d["open_decide"]')" \
    "(['bbbb0001#r1.1'], [], ['cccc0001#r1.1'], True, [])" "T31·T34: 전제 ask 미응답 → fix held(미적용 아님) · decide 0 이어도 라운드 게이트"
  assert_eq "$(printf '%s' "$g" | jgets 'd["approval_ready"]')" "True" "T31: held fix 는 승인 집계에서 빠진다(승인 게이트에 보이기만)"
  rm -rf "$d"
}
case_T32_ask_answered_unholds() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX,$F_ASK]"
  py docreview_state.py ask --state-dir "$d" --id 'cccc0001#r1.1' --answered >/dev/null
  assert_eq "$(st_yaml "$d" 'st["fixes"]["bbbb0001#r1.1"]["state"]')" "pending" "T32: ask 응답 → 막혔던 fix pending"
  rm -rf "$d"
}
case_T33_user_drops_fix() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
  py docreview_state.py fix --state-dir "$d" --id 'bbbb0001#r1.1' --event drop --reason '오탐' >/dev/null
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["unapplied_fix"], d["dropped"], d["approval_ready"]')" "([], ['bbbb0001#r1.1'], True)" "T33: 사용자 drop → 미적용에서 빠진다"
  rm -rf "$d"
}
case_T36_freeze_exceptions_log_targets() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_eq "$(py docreview_state.py exempt-anchors --state-dir "$d" | jgets 'sorted(d)')" "['#deferred-to-plan', '#결정-기록']" "T36: decision_log·defer_target 절은 항상 얼림 예외 ③"
  rm -rf "$d"
}
case_T38_stagnation() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
  next_round "$d" "$FX/design-sample.md" >/dev/null
  seed_findings "$d" "[${F_FIX/bbbb0001#r1.1\"/bbbb0001#r2.1\"}]"     # 같은 계보(lineage 필드 그대로) 의 r2 id
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["stagnation"], d["approval_gate_open"], d["two_stage"], d["next_round_mode"]')" "(True, True, True, 'budget')" "T38: 열린 계보 동일 + 진행 0 → stagnation, 두 단계 게이트, 예산 남음"
  rm -rf "$d"
}
case_T39_gate_derivation() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["approval_ready"], d["round_gate_needed"], d["approval_gate_open"], d["two_stage"], d["next_round_mode"]')" "(True, False, True, False, None)" "T39: finding 0 → 승인 준비"
  seed_findings "$d" "[$F_DEC]"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["approval_ready"], d["round_gate_needed"], d["approval_gate_open"]')" "(False, True, False)" "T39: 열린 decide → 라운드 게이트, 승인 게이트 아님"
  next_round "$d" "$FX/design-sample.md" >/dev/null; next_round "$d" "$FX/design-sample.md" >/dev/null
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["cap_reached"], d["approval_gate_open"], d["two_stage"], d["next_round_mode"]')" "(True, True, True, 'extra_approval')" "T39: 상한 도달 + 열린 것 → 두 단계, 다음 라운드는 개별 승인"
  rm -rf "$d"
}
case_T45_decision_log_append_only() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  local log; log="$(mktemp -t log-XXXXXX.md)"; cp "$FX/design-sample.md" "$log"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '첫 결정' --log-file "$log" >/dev/null
  local first; first="$(st_yaml "$d" 'st["decision_log"][0]')"
  # 리뷰 R1: 문서 파일의 바이트(메모리 dict 와는 다른 산출물)를 둘째 append 전에 잡아 둔다.
  # `$()` 는 후행 개행을 전부 지우므로 sentinel 로 보존한다 — 안 그러면 "이미 쓰인 앞 줄에
  # CORRUPTED 를 덧붙이는" 변이(개행 앞에 삽입)가 단순 substring 비교를 통과해 버린다.
  local file_before; file_before="$(cat "$log"; printf 'X')"; file_before="${file_before%X}"
  next_round "$d" "$FX/design-sample.md" >/dev/null
  seed_findings "$d" "[${F_DEC/aaaa0001#r1.1\",\"lineage/aaaa0001#r2.1\",\"lineage}]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r2.1' --choice reject --quote '둘째 결정' --log-file "$log" >/dev/null
  assert_eq "$(st_yaml "$d" 'st["decision_log"][0]')" "$first" "T45: 기존 항목 불변"
  assert_eq "$(st_yaml "$d" 'st["decision_log"][1]["supersedes"] == st["decision_log"][0]["decision_id"]')" "True" "T45: 같은 계보의 둘째 결정은 supersedes 를 단다"
  assert_eq "$(grep -c '^## 결정 기록$' "$log")" "1" "T45: 문서에 결정 기록 절이 한 번 만들어진다"
  assert_eq "$(grep -cE '^- D[0-9]+\.[0-9]+ ' "$log")" "2" "T45: 문서 절에 두 줄 append"
  local file_after msg; file_after="$(cat "$log"; printf 'X')"; file_after="${file_after%X}"
  msg="T45·AC12: 둘째 append 뒤에도 첫 항목까지의 문서 바이트가 그 접두(줄바꿈 포함)로 정확히 보존된다"
  case "$file_after" in
    "$file_before"*) ok "$msg" ;;
    *) no "$msg"
       printf '      before 끝: …%s\n      after  같은 길이: …%s\n' \
         "$(printf '%s' "$file_before" | tail -c 30)" \
         "$(printf '%s' "$file_after" | head -c "${#file_before}" | tail -c 30)" ;;
  esac
  rm -rf "$d" "$log"
}
case_T12_immutable_permit_targets_summary() {
  local d; d="$(r1 "$PROF_SD/brief.md" "$FX/brief-sample.md")"
  seed_findings "$d" '[{"id":"eeee0001#r1.1","lineage":"eeee0001#r1.1","bucket":"eeee0001","origin":"auto","promotion":"immutable","immutable":true,"layer":2,"category":"omission","anchor":"#6-사용자-원문","edit_scope":"#6-사용자-원문","disposition":"decide","summary":"원문이 두 가지로 읽힌다","evidence":"S1","blocks":[],"kind":"pre"}]'
  local out; out="$(py docreview_state.py decide --state-dir "$d" --id 'eeee0001#r1.1' --choice adopt --quote '해석 A 로' )"
  assert_eq "$(printf '%s' "$out" | jgets 'sorted(d["permit"]["apply_anchors"])')" "['#0-한-줄', '#2-제약']" "T12·AC11: 불변 앵커의 decide 채택 → permit 은 §0·§2 (원문 아님)"
  rm -rf "$d"
}

# ── 라우팅 (Task 6) ───────────────────────────────────────────────────────
render_recritic() {   # render_recritic <prepare.json> <tmpl> <out>  — {{F:부분문자열}} → fN
  python3 - "$1" "$2" "$3" <<'PY'
import json, re, sys
items = json.load(open(sys.argv[1], encoding="utf-8"))["items"]
def f_of(sub):
    hits = [i["f"] for i in items if sub in i["summary"]]
    if len(hits) != 1:
        sys.exit("템플릿 부분문자열이 %d개에 맞는다: %r" % (len(hits), sub))
    return hits[0]
t = open(sys.argv[2], encoding="utf-8").read()
open(sys.argv[3], "w", encoding="utf-8").write(re.sub(r"\{\{F:([^}]+)\}\}", lambda m: f_of(m.group(1)), t))
PY
}
route_r1() {   # route_r1 <profile> <doc> [critic] [codex] [recritic-tmpl|--skip] → state dir; $R1 = finalize json path
  local prof="$1" doc="$2" critic="${3:-$FX/critic-r1.txt}" codex="${4:-$FX/codex-r1.yaml}" rtmpl="${5:-$FX/recritic-r1.txt.tmpl}"
  local d; d="$(r1 "$prof" "$doc")" || return 1
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$critic" --codex "$codex" > "$d/prep.json"; echo "$?" > "$d/prep.rc"
  if [ "$rtmpl" = "--skip" ]; then
    py docreview_route.py finalize --state-dir "$d" --recritic-skipped --doc "$doc" > "$d/fin.json"
  elif [ -f "$rtmpl" ] && [ "${rtmpl%.tmpl}" != "$rtmpl" ]; then
    render_recritic "$d/prep.json" "$rtmpl" "$d/recritic.txt"
    py docreview_route.py finalize --state-dir "$d" --recritic "$d/recritic.txt" --doc "$doc" > "$d/fin.json"
  else
    py docreview_route.py finalize --state-dir "$d" --recritic "$rtmpl" --doc "$doc" > "$d/fin.json"
  fi
  echo "$d"
}
fsum() { jget "$1/fin.json" "[x for x in d[\"findings\"] if \"$2\" in x[\"summary\"]][0]$3"; }   # fsum <dir> <summary-sub> <suffix-expr>

case_T01_prepare_anonymizes() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-r1.txt" --codex "$FX/codex-r1.yaml" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" 'len(d["items"]), all(i["f"].startswith("f") for i in d["items"]), any("ref" in i for i in d["items"]), any("source" in i for i in d["items"])')" "(10, True, False, False)" "T01: 10건이 f-번호만 갖고 ref·source 라벨이 없다"
  assert_eq "$(jget "$d/prep.json" '[i["f"] for i in d["items"]] == ["f%d" % k for k in range(1, 11)]')" "True" "T01: 번호는 f1…fN 연속"
  assert_eq "$(jget "$d/prep.json" '[i["layer"] for i in d["items"]] == sorted(i["layer"] for i in d["items"])')" "True" "T01: 정렬 첫 키가 layer (P9) — 출처 순이 아니다"
  assert_eq "$(jget "$d/prep.json" '[i["blocks"] for i in d["items"] if "b.py" in i["summary"]][0][0].startswith("f")')" "True" "T01: blocks 도 f-번호로 바뀐다"
  rm -rf "$d"
}
case_T02_same_as_max() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_eq "$(jget "$d/fin.json" 'len([x for x in d["findings"] if x["anchor"]=="#12-files-to-modify" and x["category"]=="placeholder"])')" "1" "T02: same_as 로 묶인 둘 중 하나만 남는다"
  assert_eq "$(fsum "$d" 'c.py' '["disposition"]')" "decide" "T02: 남는 것은 높은 처분(decide)"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_absorbed"]')" "1" "T02: 흡수 1건 계수(소실 아님)"
  assert_eq "$(jget "$d/fin.json" '[x["blocks"] for x in d["findings"] if "b.py" in x["summary"]][0] == [ [x["id"] for x in d["findings"] if "c.py" in x["summary"]][0] ]')" "True" "T02: blocks 가 남은 쪽의 최종 id 를 따라간다"
  rm -rf "$d"
}
case_T03_T04_raise() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_eq "$(fsum "$d" 'Non-goals' '["disposition"]')" "decide" "T03: raise to=decide (이미 decide) — 유지"
  assert_eq "$(fsum "$d" '부품 경계' '["disposition"]')" "fix" "T04: raise to=drop 은 하향 요청 — 무시하고 fix 유지"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_coerced"] >= 1')" "True" "T04: 하향 요청은 coerced 로 계수"
  rm -rf "$d"
}
case_T05_T06_reject() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_eq "$(jget "$d/fin.json" 'len([x for x in d["findings"] if "관측 가능한" in x["summary"]]), d["adjudication_rejected"], "오탐" in d["rejected"][0]["evidence"]')" "(0, 1, True)" "T05: evidence 있는 reject → 제외 + 계수 + 인용"
  assert_eq "$(fsum "$d" 'AC 가 하나뿐' '["disposition"]')" "fix" "T06: evidence 없는 reject 는 무효 — confirm 취급"
  rm -rf "$d"
}
case_T07_codex_no_disposition() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_eq "$(fsum "$d" 'Deferred to plan 표' '["disposition"]')" "fix" "T07: recritic 이 to 로 붙인 값을 쓴다"
  local t; t="$(mktemp -t rt-XXXXXX.txt)"; printf '```docreview-recritic\nverdicts: []\nadded: []\n```\n' > "$t"
  rm -rf "$d"; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-r1.txt" "$FX/codex-r1.yaml" "$t")"
  assert_eq "$(fsum "$d" 'Deferred to plan 표' '["disposition"]')" "ask" "T07: 아무도 못 붙이면 ask (사람 쪽으로 기우는 유일한 자리)"
  rm -rf "$d" "$t"
}
case_T08_defer_disallowed() {
  local p; for p in "$PROF_SD/brief.md" "$PROF_SD/seed.md" "$PROF_QG/generic.md"; do
    local d; d="$(route_r1 "$p" "$FX/design-sample.md" "$FX/critic-r1.txt" "$FX/codex-failed.yaml" "$FX/recritic-missing.txt")"
    assert_eq "$(fsum "$d" '자동 검증 절차' '["disposition"]')" "ask" "T08·AC10: $(basename "$p" .md) 에서 defer → ask (fix 아님)"
    rm -rf "$d"
  done
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_eq "$(fsum "$d" '자동 검증 절차' '["disposition"]')" "defer" "T08: design-doc 에서만 defer 가 남는다"
  assert_eq "$(jget "$d/fin.json" 'len(d["defers"])')" "1" "T08: defers 목록 1"
  rm -rf "$d"
}
case_T09_disallowed_up() {
  local d t; t="$(mktemp -t cr-XXXXXX.txt)"
  printf '```docreview-layer1\n- ref: c0\n  category: direction\n  anchor: "#1-goal"\n  disposition: drop\n  summary: "방향 finding 을 drop 으로 냈다"\n```\n```docreview-layer2\n[]\n```\n' > "$t"
  d="$(route_r1 "$PROF_SD/brief.md" "$FX/brief-sample.md" "$t" "$FX/codex-failed.yaml" "$FX/recritic-missing.txt")"
  assert_eq "$(fsum "$d" '방향 finding' '["disposition"]')" "decide" "T09: 보호 앵커라 decide (drop 은 brief 허용값이지만 보호가 이긴다)"
  rm -rf "$d" "$t"
  # 허용값 밖 + 비보호: seed 프로필(허용 decide/ask/fix/drop)에 defer 아닌 값이 올 수 없으므로 T09 의 '상위 최소값' 분기는 generic 에 fix 를 금지한 임시 프로필로 잰다
  local pp; pp="$(mktemp -t prof-XXXXXX.md)"; sed 's/^allowed_dispositions: .*/allowed_dispositions: [decide, ask, drop]/' "$PROF_QG/generic.md" > "$pp"
  printf '```docreview-layer1\n[]\n```\n```docreview-layer2\n- ref: c1\n  category: completeness\n  anchor: "#12-files-to-modify"\n  disposition: fix\n  summary: "fix 가 불허인 프로필"\n```\n' > "$t"
  d="$(route_r1 "$pp" "$FX/design-sample.md" "$t" "$FX/codex-failed.yaml" "$FX/recritic-missing.txt")"
  assert_eq "$(fsum "$d" 'fix 가 불허' '["disposition"]')" "ask" "T09: 허용값 밖 fix → 그보다 높은 허용 최소값 ask + coerced"
  rm -rf "$d" "$t" "$pp"
}
case_T10_protected_decide() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_eq "$(fsum "$d" '목표 B' '["disposition"], [x for x in d["findings"] if "목표 B" in x["summary"]][0]["origin"], [x for x in d["findings"] if "목표 B" in x["summary"]][0]["promotion"]')" "('decide', 'auto', 'protected')" "T10·AC5: 보호 부류의 fix → decide(origin auto, promotion protected)"
  assert_eq "$(fsum "$d" '목표 B' '["decision_view"]["auto"]')" "True" "T10: 자동 채움 표시 [auto]"
  rm -rf "$d"
}
# 회귀 방지 — 리뷰 라운드가 되돌린 것: recritic 의 무효 검증(evidence 없는 reject · 하향
# raise)이 보호·불변 앵커의 fix 를 승격에서 면제해서는 안 된다. §6.3 의 보호 규칙은
# "처분 무관하게" 이고 예외는 유효 permit 하나뿐이며, immutable 행은 예외가 아예 없다
# ("어떤 처분도 그 본문을 바꾸지 않는다"). 옛 면제는 2×2(방아쇠 A=무효 reject/B=하향
# raise × 적용처 1=protected/2=immutable) 였다 — 네 칸을 각각 케이스로 잠근다.
case_T10_invalidated_reject_still_promotes() {   # A×1: 무효 reject × protected
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  local t; t="$(mktemp -t cr-XXXXXX.txt)"
  printf '```docreview-layer1\n[]\n```\n```docreview-layer2\n- ref: c1\n  category: ambiguity\n  anchor: "#11-acceptance-criteria"\n  disposition: fix\n  summary: "회귀 방지 A1: 무효 reject 뒤에도 보호 승격"\n```\n' > "$t"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$t" --codex "$FX/codex-failed.yaml" > "$d/prep.json"
  local rt; rt="$(mktemp -t rt-XXXXXX.txt)"
  printf '```docreview-recritic\nverdicts:\n  - f: "f1"\n    verdict: reject\nadded: []\n```\n' > "$rt"
  py docreview_route.py finalize --state-dir "$d" --recritic "$rt" --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(fsum "$d" '회귀 방지 A1' '["disposition"]')" "decide" "회귀 A×1: 보호 앵커의 fix 는 evidence 없는 reject(무효 → confirm 취급) 뒤에도 승격된다"
  assert_eq "$(fsum "$d" '회귀 방지 A1' '["promotion"]')" "protected" "회귀 A×1: 승격 사유는 protected — 검증 개입 여부와 무관하게 균일 적용"
  rm -rf "$d" "$t" "$rt"
}
case_T10_invalidated_raise_still_promotes() {   # B×1: 하향 raise × protected
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  local t; t="$(mktemp -t cr-XXXXXX.txt)"
  printf '```docreview-layer1\n[]\n```\n```docreview-layer2\n- ref: c1\n  category: ambiguity\n  anchor: "#11-acceptance-criteria"\n  disposition: fix\n  summary: "회귀 방지 B1: 하향 raise 뒤에도 보호 승격"\n```\n' > "$t"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$t" --codex "$FX/codex-failed.yaml" > "$d/prep.json"
  local rt; rt="$(mktemp -t rt-XXXXXX.txt)"
  printf '```docreview-recritic\nverdicts:\n  - f: "f1"\n    verdict: raise\n    to: drop\nadded: []\n```\n' > "$rt"
  py docreview_route.py finalize --state-dir "$d" --recritic "$rt" --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(fsum "$d" '회귀 방지 B1' '["disposition"]')" "decide" "회귀 B×1: 보호 앵커의 fix 는 하향 raise(무시 → coerced) 뒤에도 승격된다"
  assert_eq "$(fsum "$d" '회귀 방지 B1' '["promotion"]')" "protected" "회귀 B×1: 승격 사유는 protected"
  rm -rf "$d" "$t" "$rt"
}
case_T12_invalidated_reject_still_promotes() {   # A×2: 무효 reject × immutable
  local d; d="$(r1 "$PROF_SD/brief.md" "$FX/brief-sample.md")"
  local t; t="$(mktemp -t cr-XXXXXX.txt)"
  printf '```docreview-layer1\n[]\n```\n```docreview-layer2\n- ref: c1\n  category: omission\n  anchor: "#6-사용자-원문"\n  disposition: fix\n  summary: "회귀 방지 A2: 무효 reject 뒤에도 불변 승격"\n```\n' > "$t"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$t" --codex "$FX/codex-failed.yaml" > "$d/prep.json"
  local rt; rt="$(mktemp -t rt-XXXXXX.txt)"
  printf '```docreview-recritic\nverdicts:\n  - f: "f1"\n    verdict: reject\nadded: []\n```\n' > "$rt"
  py docreview_route.py finalize --state-dir "$d" --recritic "$rt" --doc "$FX/brief-sample.md" > "$d/fin.json"
  assert_eq "$(fsum "$d" '회귀 방지 A2' '["disposition"]')" "decide" "회귀 A×2: 불변 앵커의 fix 는 evidence 없는 reject(무효 → confirm 취급) 뒤에도 승격된다"
  assert_eq "$(fsum "$d" '회귀 방지 A2' '["promotion"]')" "immutable" "회귀 A×2: 승격 사유는 immutable — 예외가 아예 없다(설계 §6.3)"
  rm -rf "$d" "$t" "$rt"
}
case_T12_invalidated_raise_still_promotes() {   # B×2: 하향 raise × immutable
  local d; d="$(r1 "$PROF_SD/brief.md" "$FX/brief-sample.md")"
  local t; t="$(mktemp -t cr-XXXXXX.txt)"
  printf '```docreview-layer1\n[]\n```\n```docreview-layer2\n- ref: c1\n  category: omission\n  anchor: "#6-사용자-원문"\n  disposition: fix\n  summary: "회귀 방지 B2: 하향 raise 뒤에도 불변 승격"\n```\n' > "$t"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$t" --codex "$FX/codex-failed.yaml" > "$d/prep.json"
  local rt; rt="$(mktemp -t rt-XXXXXX.txt)"
  printf '```docreview-recritic\nverdicts:\n  - f: "f1"\n    verdict: raise\n    to: drop\nadded: []\n```\n' > "$rt"
  py docreview_route.py finalize --state-dir "$d" --recritic "$rt" --doc "$FX/brief-sample.md" > "$d/fin.json"
  assert_eq "$(fsum "$d" '회귀 방지 B2' '["disposition"]')" "decide" "회귀 B×2: 불변 앵커의 fix 는 하향 raise(무시 → coerced) 뒤에도 승격된다"
  assert_eq "$(fsum "$d" '회귀 방지 B2' '["promotion"]')" "immutable" "회귀 B×2: 승격 사유는 immutable — 예외가 아예 없다(설계 §6.3)"
  rm -rf "$d" "$t" "$rt"
}
case_T11_permit_keeps_disposition() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  local gid; gid="$(fsum "$d" '목표 B' '["id"]')"
  py docreview_state.py decide --state-dir "$d" --id "$gid" --choice adopt --quote '목표 B 문구 수정 승인' >/dev/null
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null
  local t; t="$(mktemp -t cr-XXXXXX.txt)"
  printf '```docreview-layer1\n[]\n```\n```docreview-layer2\n- ref: c1\n  category: ambiguity\n  anchor: "#2-goals"\n  disposition: fix\n  summary: "목표 B 문구 후속 손질"\n```\n' > "$t"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$t" --codex "$FX/codex-failed.yaml" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/diff2.json" --doc "$FX/design-sample-r2.md" > "$d/fin.json"
  assert_eq "$(fsum "$d" '후속 손질' '["disposition"]')" "fix" "T11: 유효 permit 이 있는 보호 앵커는 리뷰어 처분 그대로"
  assert_eq "$(jget "$d/fin.json" 'all(x["id"].split("#")[1].startswith("r2.") for x in d["findings"])')" "True" "T11: 라운드 2 에서 생성된 id 는 전부 r2. 로 시작 — 라운드 «번호» 가 실제로 박힌다(r 존재가 아니라 값)"
  rm -rf "$d" "$t"
}
case_T12_immutable_fix_to_decide() {
  local d t; t="$(mktemp -t cr-XXXXXX.txt)"
  printf '```docreview-layer1\n[]\n```\n```docreview-layer2\n- ref: c1\n  category: omission\n  anchor: "#6-사용자-원문"\n  disposition: fix\n  summary: "원문 문장을 고치자"\n```\n' > "$t"
  d="$(route_r1 "$PROF_SD/brief.md" "$FX/brief-sample.md" "$t" "$FX/codex-failed.yaml" "$FX/recritic-missing.txt")"
  assert_eq "$(fsum "$d" '원문 문장' '["disposition"], [x for x in d["findings"] if "원문 문장" in x["summary"]][0]["immutable"]')" "('decide', True)" "T12·AC11: §6 의 fix → decide(immutable)"
  local id; id="$(fsum "$d" '원문 문장' '["id"]')"
  assert_eq "$(py docreview_state.py decide --state-dir "$d" --id "$id" --choice adopt --quote '해석 확정' | jgets 'sorted(d["permit"]["apply_anchors"])')" "['#0-한-줄', '#2-제약']" "T12·AC11: 채택 permit 은 §0·§2 — §6 은 어떤 처분도 닿지 않는다"
  rm -rf "$d" "$t"
}
case_T13_ids_distinct() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  # c5 는 reject(evidence) 로 제외됐고 c6 는 남는다 — 같은 bucket 에 k 가 둘이며 reject 가 다른 k 를 지우지 않는다
  assert_eq "$(jget "$d/fin.json" 'sorted(x["id"].split("#r")[1] for x in d["findings"]+[{"id":r["id"]} for r in d["rejected"]] if x["id"].startswith(d["rejected"][0]["id"].split("#")[0]))')" "['1.1', '1.2']" "T13·AC19: 같은 bucket 의 둘은 r1.1 · r1.2 — reject 가 다른 순번을 지우지 않는다"
  assert_eq "$(jget "$d/fin.json" 'd["bucket_conflicts"]')" "1" "T13: bucket 충돌 1 공시"
  assert_eq "$(jget "$d/fin.json" 'all(x["id"].split("#")[1].startswith("r1.") for x in d["findings"])')" "True" "T13: 모든 id 에 라운드가 박힌다"
  rm -rf "$d"
}
case_T14_T15_lineage() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  local fid lin; fid="$(fsum "$d" 'AC 가 하나뿐' '["id"]')"; lin="$(fsum "$d" 'AC 가 하나뿐' '["lineage"]')"
  assert_eq "$fid" "$lin" "T14: 새 finding 의 계보 뿌리는 자기 id"
  next_round "$d" "$FX/design-sample.md" >/dev/null
  local t; t="$(mktemp -t cr-XXXXXX.txt)"
  printf '```docreview-layer1\n[]\n```\n```docreview-layer2\n- ref: c1\n  category: ambiguity\n  anchor: "#1-context"\n  disposition: fix\n  summary: "AC 가 여전히 하나뿐이다"\n- ref: c2\n  category: ambiguity\n  anchor: "#1-context"\n  disposition: fix\n  supersedes: "%s"\n  summary: "명시 지목"\n```\n' "$fid" > "$t"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$t" --codex "$FX/codex-failed.yaml" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/diff2.json" --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(fsum "$d" '명시 지목' '["lineage"]')" "$lin" "T14: supersedes 실재 → 그 계보"
  assert_eq "$(fsum "$d" '여전히 하나뿐' '["lineage"] != "'"$lin"'"')" "True" "T15: 지목된 조상은 자동 연결에서 빠지고 남는 것은 새 계보"
  rm -rf "$d" "$t"
}
case_T15_auto_lineage() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  local lin; lin="$(fsum "$d" 'AC 가 하나뿐' '["lineage"]')"
  next_round "$d" "$FX/design-sample.md" >/dev/null
  local t; t="$(mktemp -t cr-XXXXXX.txt)"
  printf '```docreview-layer1\n[]\n```\n```docreview-layer2\n- ref: c1\n  category: ambiguity\n  anchor: "#1-context"\n  disposition: fix\n  summary: "지목 없이 같은 자리"\n```\n' > "$t"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$t" --codex "$FX/codex-failed.yaml" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/diff2.json" --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(fsum "$d" '지목 없이' '["lineage"]')" "$lin" "T15: 지목이 없으면 같은 bucket 의 열린 이전 finding 에 자동 연결(순번 낮은 것부터)"
  rm -rf "$d" "$t"
}
case_T16_lineage_mismatch() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_eq "$(jget "$d/fin.json" 'd["lineage_mismatch"]')" "1" "T16: 실재하지 않는 supersedes → 계보 지목 불일치 1"
  assert_eq "$(fsum "$d" '부품 경계' '["supersedes"]')" "None" "T16: 그 finding 은 새 계보로 간다"
  rm -rf "$d"
}
case_T17_revival_notice() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  local gid; gid="$(fsum "$d" '목표 B' '["id"]')"
  py docreview_state.py decide --state-dir "$d" --id "$gid" --choice reject --quote '목표 B 는 그대로 둔다' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null
  local t; t="$(mktemp -t cr-XXXXXX.txt)"
  printf '```docreview-layer1\n[]\n```\n```docreview-layer2\n- ref: c1\n  category: ambiguity\n  anchor: "#2-goals"\n  disposition: fix\n  summary: "목표 B 가 또 두 가지로 읽힌다"\n```\n' > "$t"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$t" --codex "$FX/codex-failed.yaml" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/diff2.json" --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" 'len(d["revived"]), d["revived"][0]["by"], "그대로" in d["revived"][0]["why"]')" "(1, 'user', True)" "T17: 기각 계보의 부활을 라우터가 원장으로 대조해 사유와 함께 공시"
  assert_eq "$(fsum "$d" '또 두 가지' '["disposition"]')" "decide" "T17: 새 finding 은 지우지 않는다(보호라 decide)"
  rm -rf "$d" "$t"
}
case_T35_frozen_change_auto_decide() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-nolayer2.txt" --codex "$FX/codex-failed.yaml" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/diff2.json" --doc "$FX/design-sample-r2.md" > "$d/fin.json"
  local fr; fr="$(jget "$d/fin.json" 'sorted((x["anchor"], x["disposition"], x["origin"], x["kind"]) for x in d["findings"] if x["category"]=="frozen_change")')"
  assert_eq "$fr" "[('#12-files-to-modify', 'decide', 'auto', 'post'), ('#2-goals', 'decide', 'auto', 'post')]" "T35·AC4: 얼린 두 섹션의 변경 → 사후 auto decide 둘"
  assert_grep "$(jget "$d/fin.json" '[x["evidence"] for x in d["findings"] if x["anchor"]=="#12-files-to-modify" and x["category"]=="frozen_change"][0]')" 'hash [0-9a-f]{12}→[0-9a-f]{12}' "T35·AC4: evidence 에 헤딩 diff(해시 전후)"
  assert_grep "$(jget "$d/fin.json" '[x["decision_view"]["impact"] for x in d["findings"] if x["anchor"]=="#12-files-to-modify" and x["category"]=="frozen_change"][0]')" '인용 1 섹션' "T35: 영향 = refs (Architecture 가 #12 를 인용)"
  assert_eq "$(jget "$d/fin.json" '[x["decision_view"]["alternatives"] for x in d["findings"] if x["category"]=="frozen_change"][0]')" "['채택(적용)', '기각(원복)', '보류']" "T35: 대안은 고정 셋"
  rm -rf "$d"
}
case_T28_escalated_fix_becomes_decide() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  local fid; fid="$(fsum "$d" 'AC 가 하나뿐' '["id"]')"
  py docreview_state.py fix --state-dir "$d" --id "$fid" --event escalate --reason 'check-intent 거부: edit_scope 밖' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-nolayer2.txt" --codex "$FX/codex-failed.yaml" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/diff2.json" --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" '[(x["disposition"], x["kind"], x["supersedes"]==sys.argv[0] if False else x["supersedes"]) for x in d["findings"] if "AC 가 하나뿐" in x["summary"]]')" "[('decide', 'pre', '$fid')]" "T28: check-intent 거부된 fix 는 다음 라운드에 같은 계보의 decide(pre)"
  rm -rf "$d"
}
case_T22_reraise_appears_in_next_round() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  local gid; gid="$(fsum "$d" 'Non-goals' '["id"]')"
  py docreview_state.py decide --state-dir "$d" --id "$gid" --choice adopt --quote '채택' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null        # 변경 없음 → expired
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-nolayer2.txt" --codex "$FX/codex-failed.yaml" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/diff2.json" --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" '[(x["disposition"], x["supersedes"], x["lineage"]) for x in d["findings"] if "expired" in x["summary"]]')" "[('decide', '$gid', '$gid')]" "T22: expired 는 같은 계보의 decide 로 다음 라운드 목록에 재상승"
  rm -rf "$d"
}
case_T40_codex_absent_first_line() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-r1.txt" "$FX/codex-failed.yaml" "$FX/recritic-missing.txt")"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" --render | head -1)" "codex 없음 — 모델 다양성 0 (exit_nonzero)" "T40·AC8: 게이트 텍스트 첫 줄이 codex 부재 공시"
  assert_eq "$(jget "$d/fin.json" 'd["advisory"][0].startswith("codex 없음"), d["blocks"]')" "(True, False)" "T40: advisory 첫 항목도 codex, 차단은 아님"
  rm -rf "$d"
}
case_T41_critic_dead_blocks() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-nolayer1.txt" --codex "$FX/codex-r1.yaml" > "$d/prep.json" 2>/dev/null; local rc=$?
  assert_eq "$rc $(jget "$d/prep.json" 'd["degrade"]["critic_dead"]')" "4 True" "T41: 층 1 블록 없음 → rc 4 + critic_dead"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-broken.txt" --codex "$FX/codex-r1.yaml" > "$d/prep.json" 2>/dev/null; rc=$?
  assert_eq "$rc" "4" "T41: 층 1 블록 YAML 파손 → rc 4"
  rm -rf "$d"
}
case_T42_layer2_missing() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-nolayer2.txt" "$FX/codex-failed.yaml" "$FX/recritic-missing.txt")"
  assert_eq "$(jget "$d/fin.json" 'd["degrade"]["layer2_missing"], "layer2" in d["adjudication_unknown_counts"], any("상세 미검증" in a for a in d["advisory"])')" "(True, True, True)" "T42: 층 2 요구 프로필에서 부재 → uncountable + 공시"
  rm -rf "$d"
  d="$(route_r1 "$PROF_SD/seed.md" "$FX/design-sample.md" "$FX/critic-nolayer2.txt" "$FX/codex-failed.yaml" "$FX/recritic-missing.txt")"
  assert_eq "$(jget "$d/fin.json" 'd["degrade"]["layer2_missing"], d["adjudication_unknown_counts"]')" "(False, [])" "T42: seed(층 2 비움)에서는 부재가 정상 — 기록 없음"
  rm -rf "$d"
}
case_T43_recritic_dead() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-r1.txt" "$FX/codex-r1.yaml" "$FX/recritic-missing.txt")"
  assert_eq "$(jget "$d/fin.json" 'd["blocks"], any("기각 경로 0" in a for a in d["advisory"]), d["adjudication_rejected"]')" "(False, True, 0)" "T43: recritic 부재 → 차단 없음 + 「기각 경로 0」"
  assert_eq "$(fsum "$d" 'c.py 가 목록에 없다' '["disposition"]')" "fix" "T43: same_as 없이 critic 처분 그대로 간다"
  rm -rf "$d"
  d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-r1.txt" "$FX/codex-r1.yaml" --skip)"
  assert_eq "$(jget "$d/fin.json" 'd["degrade"]["recritic_dead"]')" "skipped" "T43: kill switch(--recritic-skipped) 도 같은 공시"
  rm -rf "$d"
}
case_route_adjudication_keys() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_eq "$(jget "$d/fin.json" 'sorted(k for k in d if k.startswith("adjudication_"))')" \
    "['adjudication_absorbed', 'adjudication_accepted', 'adjudication_coerced', 'adjudication_degraded', 'adjudication_held', 'adjudication_held_by_class', 'adjudication_rejected', 'adjudication_sources_failed', 'adjudication_suppressed', 'adjudication_unknown_counts']" \
    "route: adjudication_* 키 전부(P7)"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_accepted"] == len(d["findings"])')" "True" "route: 최종 목록 전부 accept 계수"
  rm -rf "$d"
}

# ── check-intent (Task 7) ─────────────────────────────────────────────────
_ci() { py docreview_anchor.py check-intent "$@" 2>/dev/null; }   # rc 는 $?
case_AC6_fix_contract() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
  local out; out="$(_ci 'bbbb0001#r1.1' --intent '#12-files-to-modify' --state-dir "$d")"; local rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["contract"]')" "0 fix" "AC6: edit_scope 안 → 통과(fix 계약)"
  assert_eq "$(st_yaml "$d" 'st["fixes"]["bbbb0001#r1.1"]["state"], len(st["applied_scopes"])')" "('intent_passed', 1)" "AC6·T27: 통과가 applied_scopes 에 남는다"
  rm -rf "$d"; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
  out="$(_ci 'bbbb0001#r1.1' --intent '#11-acceptance-criteria' --state-dir "$d")"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["reason"]')" "1 scope_outside_edit_scope" "AC6: edit_scope 밖 → 거부"
  assert_eq "$(st_yaml "$d" 'st["fixes"]["bbbb0001#r1.1"]["state"], len(st["escalated"])')" "('escalated', 1)" "AC6·T28: 거부는 그 fix 를 escalated 로(다음 라운드 decide)"
  rm -rf "$d"
  # 보호 · 불변 · fix_anchors 밖
  d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  seed_findings "$d" "[${F_FIX//#12-files-to-modify/#2-goals}]"
  out="$(_ci 'bbbb0001#r1.1' --intent '#2-goals' --state-dir "$d")"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["reason"]')" "1 anchor_protected" "AC6: 보호 부류 앵커 → 거부(라우터가 못 잡은 경로의 최종 방어)"
  rm -rf "$d"; d="$(r1 "$PROF_SD/brief.md" "$FX/brief-sample.md")"
  seed_findings "$d" "[${F_FIX//#12-files-to-modify/#6-사용자-원문}]"
  out="$(_ci 'bbbb0001#r1.1' --intent '#6-사용자-원문' --state-dir "$d")"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["reason"]')" "1 anchor_immutable" "AC6: immutable → 거부"
  rm -rf "$d"; d="$(r1 "$PROF_SD/brief.md" "$FX/brief-sample.md")"
  seed_findings "$d" "[${F_FIX//#12-files-to-modify/#1-goal}]"
  out="$(_ci 'bbbb0001#r1.1' --intent '#1-goal' --state-dir "$d")"; rc=$?
  assert_eq "$rc" "1" "AC6: brief §1 은 fix_anchors 밖(+보호) → 거부"
  rm -rf "$d"
}
# [R13 실행 노트] 원래 여기서 삽입 대상으로 썼던 #3-non-goals 는 design-doc 프로필의
# 보호 부류다(classify_anchor 실측: protected=True) — R13 이 insert-after 대상의 protected 도
# 보게 되면서 그 자리를 "통과" 로 기대하던 첫 단언이 깨진다. 픽스처를 design-sample.md 의
# 비보호 헤딩 #1-context 로 옮긴다(같은 문서·같은 design-doc 프로필에서 classify_anchor 실측:
# protected=False·immutable=False — task-7-report.md R13 절의 표 참조). 보호·불변 자체를 겨누는
# 케이스는 아래 case_AC6_R13_insert_after_protection 이 맡는다.
case_AC6_insert_after() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  seed_findings "$d" "[${F_FIX//\"edit_scope\":\"#12-files-to-modify\"/\"edit_scope\":\"insert-after:#1-context\"}]"
  local out; out="$(_ci 'bbbb0001#r1.1' --intent 'insert-after:#1-context' --state-dir "$d")"; local rc=$?
  assert_eq "$rc" "0" "AC6: insert-after 의도는 finding 의 edit_scope 와 같고 대상이 비보호·비불변이면 통과"
  rm -rf "$d"; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  seed_findings "$d" "[${F_FIX//\"edit_scope\":\"#12-files-to-modify\"/\"edit_scope\":\"insert-after:#1-context\"}]"
  out="$(_ci 'bbbb0001#r1.1' --intent 'insert-after:#2-goals' --state-dir "$d")"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["reason"]')" "1 scope_outside_edit_scope" "AC6: 다른 자리의 insert-after 는 거부"
  rm -rf "$d"
}
# R13(사용자 결정) — 헤딩 파싱이 평면이라 #x 바로 뒤에 새 헤딩을 넣으면 #x 의 본문이 거기서
# 잘려 해시가 바뀐다("삽입"이 실제로 #x 를 변경한다). 라우터는 finding 의 anchor 만 분류하고
# check-intent 의 옛 insert-after 경로는 found 만 봐서, edit_scope 가 "insert-after:#<보호 헤딩>"
# 인 finding 은 두 방어를 다 통과했다 — 그 틈을 여기서 막는다. 사유는 일반 앵커 전용
# anchor_protected/anchor_immutable 과 구별되는 새 값(insert_after_protected/
# insert_after_immutable)을 쓴다.
case_AC6_R13_insert_after_protection() {
  # 대상이 protected(design-doc 의 #3-non-goals, classify_anchor 실측: protected=True·immutable=False)
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  seed_findings "$d" "[${F_FIX//\"edit_scope\":\"#12-files-to-modify\"/\"edit_scope\":\"insert-after:#3-non-goals\"}]"
  local out; out="$(_ci 'bbbb0001#r1.1' --intent 'insert-after:#3-non-goals' --state-dir "$d")"; local rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["reason"]')" "1 insert_after_protected" "R13: 보호 헤딩 뒤에 삽입 → insert_after_protected(anchor_protected 와 다른 문자열)"
  assert_eq "$(st_yaml "$d" 'st["fixes"]["bbbb0001#r1.1"]["state"]')" "escalated" "R13: 거부는 이 fix 도 escalated 로(T28 과 같은 다음-라운드 decide 경로)"
  rm -rf "$d"
  # 대상이 immutable(brief 의 #6-사용자-원문, classify_anchor 실측: protected=False·immutable=True)
  d="$(r1 "$PROF_SD/brief.md" "$FX/brief-sample.md")"
  seed_findings "$d" "[${F_FIX//\"edit_scope\":\"#12-files-to-modify\"/\"edit_scope\":\"insert-after:#6-사용자-원문\"}]"
  out="$(_ci 'bbbb0001#r1.1' --intent 'insert-after:#6-사용자-원문' --state-dir "$d")"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["reason"]')" "1 insert_after_immutable" "R13·AC11: 불변 헤딩 뒤에 삽입 → insert_after_immutable(immutable 은 삽입으로도 못 넘는다)"
  rm -rf "$d"
}
case_AC6_permit_contract() {
  # 보호 앵커(#2-goals)의 decide 를 채택 → permit 으로는 보호·fix_anchors 무관하게 통과, 라운드가 지나면 거부
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  seed_findings "$d" "[${F_DEC//#12-files-to-modify/#2-goals}]"
  local did; did="$(py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' | jgets 'd["decision_id"]')"
  local out rc
  out="$(_ci 'aaaa0001#r1.1' --intent '#2-goals' --state-dir "$d" --decision-id "$did")"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["reason"]')" "1 permit_round_mismatch" "AC6: permit 은 다음 라운드(n+1) 것 — 같은 라운드엔 아직 아니다"
  next_round "$d" "$FX/design-sample.md" >/dev/null   # 라운드 2 — 변경 없음이라 permit 은 아직 소모 안 됨? (observe-diff 가 expired 로 소모한다)
  rm -rf "$d"
  d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  seed_findings "$d" "[${F_DEC//#12-files-to-modify/#2-goals}]"
  did="$(py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' | jgets 'd["decision_id"]')"
  snap "$FX/design-sample.md" "$d/s2.json"; py docreview_state.py begin-round --state-dir "$d" --snapshot "$d/s2.json" >/dev/null   # 라운드 2 진입, observe 전
  out="$(_ci 'aaaa0001#r1.1' --intent '#2-goals' --state-dir "$d" --decision-id "$did")"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["contract"]')" "0 permit" "AC6: 라운드 n+1 의 유효 permit → 보호 앵커라도 통과(permit 계약)"
  out="$(_ci 'aaaa0001#r1.1' --intent '#12-files-to-modify' --state-dir "$d" --decision-id "$did")"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["reason"]')" "1 scope_outside_permit" "AC6: permit 의 apply_anchors 밖은 거부"
  rm -rf "$d"
  # immutable 은 permit 으로도 못 넘는다
  d="$(r1 "$PROF_SD/brief.md" "$FX/brief-sample.md")"
  seed_findings "$d" '[{"id":"eeee0001#r1.1","lineage":"eeee0001#r1.1","bucket":"eeee0001","origin":"reviewer","layer":2,"category":"omission","anchor":"#6-사용자-원문","edit_scope":"#6-사용자-원문","disposition":"decide","summary":"x","evidence":"S1","blocks":[],"kind":"pre"}]'
  did="$(py docreview_state.py decide --state-dir "$d" --id 'eeee0001#r1.1' --choice adopt --quote '채택' | jgets 'd["decision_id"]')"
  snap "$FX/brief-sample.md" "$d/s2.json"; py docreview_state.py begin-round --state-dir "$d" --snapshot "$d/s2.json" >/dev/null
  out="$(_ci 'eeee0001#r1.1' --intent '#6-사용자-원문' --state-dir "$d" --decision-id "$did")"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["reason"]')" "1 anchor_immutable" "AC6·AC11: immutable 은 permit 으로도 절대 못 넘는다(immutable 플래그 없는 decide 의 permit 이 §6 을 겨눈 경우)"
  rm -rf "$d"
}
# [Task 7 실행 노트] 위 세 케이스는 brief 축자다. brief Step 2 의 문면 코드는 이 케이스들과
# 스스로 어긋난다 — (a) fix_allowed 검사가 immutable 검사보다 먼저면 브리프 §6 케이스가
# `anchor_not_in_fix_anchors` 로 나와 위 기대(`anchor_immutable`)와 다르고, (b) protected·
# fix_allowed·immutable 검사를 insert-after 에도 그대로 적용하면 `#3-non-goals`(Non-goals 는
# 보호 부류, 직접 실측 확인)가 `anchor_protected` 로 막혀 위 insert-after 통과 기대와 어긋난다.
# 설계 §7 은 insert-after 에 「#x 바로 뒤에 새 섹션 하나」외의 제약을 두지 않는다(#x 본문은
# 안 바뀐다) — 그래서 구현은 insert-after 모드에서 found 검사만 하고, 일반 앵커 모드에서는
# immutable 을 fix_allowed·protected 보다 먼저 본다(면 브리프 문면과 다르지만 설계·이 브리프의
# 케이스 둘 다와 일치 — 권위는 설계 > 계획 > 브리프 코드). 아래는 그 재정렬이 없으면 못 잡는
# 나머지 사유들을 채운다(12개 중 이 파일이 reason 값까지 재는 것 전부).
case_AC6_reject_reasons_extra() {
  local d out rc
  d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  out="$(_ci 'zzzz9999#r1.1' --intent '#12-files-to-modify' --state-dir "$d")"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["reason"]')" "1 unknown_finding" "AC6: 존재하지 않는 finding-id → unknown_finding"
  seed_findings "$d" "[$F_DEC]"
  out="$(_ci 'aaaa0001#r1.1' --intent '#12-files-to-modify' --state-dir "$d")"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["reason"]')" "1 not_a_fix" "AC6: disposition=decide 인 finding 에 check-intent → not_a_fix"
  out="$(_ci 'aaaa0001#r1.1' --intent '#12-files-to-modify' --state-dir "$d" --decision-id 'D9.9')"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["reason"]')" "1 unknown_permit" "AC6: 존재하지 않는 decision-id → unknown_permit(finding 은 실재)"
  rm -rf "$d"
  d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
  py docreview_state.py fix --state-dir "$d" --id 'bbbb0001#r1.1' --event hold >/dev/null
  out="$(_ci 'bbbb0001#r1.1' --intent '#12-files-to-modify' --state-dir "$d")"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["reason"]')" "1 fix_not_pending" "AC6: held 상태의 fix → fix_not_pending"
  rm -rf "$d"
  d="$(r1 "$PROF_SD/brief.md" "$FX/brief-sample.md")"
  seed_findings "$d" "[${F_FIX//#12-files-to-modify/#1-goal}]"
  out="$(_ci 'bbbb0001#r1.1' --intent '#1-goal' --state-dir "$d")"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["reason"]')" "1 anchor_not_in_fix_anchors" "AC6: fix_anchors 밖(같은 앵커가 보호이기도 하나 이 판정이 먼저 온다)"
  rm -rf "$d"
  d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  seed_findings "$d" "[${F_FIX//\"edit_scope\":\"#12-files-to-modify\"/\"edit_scope\":\"insert-after:#zzz-missing\"}]"
  out="$(_ci 'bbbb0001#r1.1' --intent 'insert-after:#zzz-missing' --state-dir "$d")"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["reason"]')" "1 insert_after_unresolved" "AC6: insert-after 대상이 스냅샷에 없다 → insert_after_unresolved"
  rm -rf "$d"
  d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  local did; did="$(py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' | jgets 'd["decision_id"]')"
  next_round "$d" "$FX/design-sample.md" >/dev/null   # observe-diff 가 미적중으로 이 permit 을 이미 소모한다
  out="$(_ci 'aaaa0001#r1.1' --intent '#12-files-to-modify' --state-dir "$d" --decision-id "$did")"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["reason"]')" "1 permit_consumed" "AC6: 이미 소모된 permit → permit_consumed"
  rm -rf "$d"
}
