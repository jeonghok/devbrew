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
  next_round "$d" "$FX/design-sample.md" >/dev/null
  seed_findings "$d" "[${F_DEC/aaaa0001#r1.1\",\"lineage/aaaa0001#r2.1\",\"lineage}]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r2.1' --choice reject --quote '둘째 결정' --log-file "$log" >/dev/null
  assert_eq "$(st_yaml "$d" 'st["decision_log"][0]')" "$first" "T45: 기존 항목 불변"
  assert_eq "$(st_yaml "$d" 'st["decision_log"][1]["supersedes"] == st["decision_log"][0]["decision_id"]')" "True" "T45: 같은 계보의 둘째 결정은 supersedes 를 단다"
  assert_eq "$(grep -c '^## 결정 기록$' "$log")" "1" "T45: 문서에 결정 기록 절이 한 번 만들어진다"
  assert_eq "$(grep -cE '^- D[0-9]+\.[0-9]+ ' "$log")" "2" "T45: 문서 절에 두 줄 append"
  rm -rf "$d" "$log"
}
case_T12_immutable_permit_targets_summary() {
  local d; d="$(r1 "$PROF_SD/brief.md" "$FX/brief-sample.md")"
  seed_findings "$d" '[{"id":"eeee0001#r1.1","lineage":"eeee0001#r1.1","bucket":"eeee0001","origin":"auto","promotion":"immutable","immutable":true,"layer":2,"category":"omission","anchor":"#6-사용자-원문","edit_scope":"#6-사용자-원문","disposition":"decide","summary":"원문이 두 가지로 읽힌다","evidence":"S1","blocks":[],"kind":"pre"}]'
  local out; out="$(py docreview_state.py decide --state-dir "$d" --id 'eeee0001#r1.1' --choice adopt --quote '해석 A 로' )"
  assert_eq "$(printf '%s' "$out" | jgets 'sorted(d["permit"]["apply_anchors"])')" "['#0-한-줄', '#2-제약']" "T12·AC11: 불변 앵커의 decide 채택 → permit 은 §0·§2 (원문 아님)"
  rm -rf "$d"
}
