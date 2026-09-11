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
# 라운드 2 의 재상승 항목 — F_DEC 의 계보를 이어받아 만료 항목을 supersedes 한다(라우터가 붙이는 최종 모양).
F_DEC_R2='{"id":"aaaa0001#r2.1","lineage":"aaaa0001#r1.1","bucket":"aaaa0001","supersedes":"aaaa0001#r1.1","origin":"auto","layer":2,"category":"ambiguity","anchor":"#12-files-to-modify","edit_scope":"#12-files-to-modify","disposition":"decide","summary":"채택 후 미적용(expired): 파일 목록이 두 가지로 읽힌다","evidence":"라운드 2 에 채택 변경 관측 없음","blocks":[],"kind":"pre"}'
# AC20 ① — 만료를 가리키지만 «의무를 지지 않는» 후속 넷. 처분만 다르다.
F_SUCC_ASK='{"id":"aaaa0001#r2.1","lineage":"aaaa0001#r1.1","bucket":"aaaa0001","supersedes":"aaaa0001#r1.1","origin":"auto","layer":2,"category":"ambiguity","anchor":"#12-files-to-modify","edit_scope":"#12-files-to-modify","disposition":"ask","summary":"후속: 물어보기","evidence":null,"blocks":[]}'
F_SUCC_DEFER='{"id":"aaaa0001#r2.1","lineage":"aaaa0001#r1.1","bucket":"aaaa0001","supersedes":"aaaa0001#r1.1","origin":"auto","layer":2,"category":"ambiguity","anchor":"#12-files-to-modify","edit_scope":"#12-files-to-modify","disposition":"defer","summary":"후속: plan 으로","evidence":null,"blocks":[]}'
F_SUCC_DROP='{"id":"aaaa0001#r2.1","lineage":"aaaa0001#r1.1","bucket":"aaaa0001","supersedes":"aaaa0001#r1.1","origin":"auto","layer":2,"category":"ambiguity","anchor":"#12-files-to-modify","edit_scope":"#12-files-to-modify","disposition":"drop","summary":"후속: 버림","evidence":null,"blocks":[]}'
F_SUCC_REJ='{"id":"aaaa0001#r2.1","lineage":"aaaa0001#r1.1","bucket":"aaaa0001","supersedes":"aaaa0001#r1.1","origin":"auto","layer":2,"category":"ambiguity","anchor":"#12-files-to-modify","edit_scope":"#12-files-to-modify","disposition":"decide","state":"rejected","summary":"후속: 재비판이 기각","evidence":"오탐","blocks":[],"kind":"pre"}'
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
  # [Task 3 fix round 1 — I2a] AC20 로 "adopted"·"blocked_expired" 가 갈라진 뒤에도 정상
  # 종결(적용) 경로가 승인 게이트를 실제로 여는지 재는 자리가 남아 있어야 한다 — 이
  # 락이 없어지면 「의무 이행이 승인을 다시 연다」는 통째로 case_T22b 의 삭제된 꼬리와
  # 함께 사라진다(그 사실 자체는 case_AC20_reexpiry_blocks_again 이 재지 않는다, 아래
  # ⑫ 은퇴 노트 정정 참조).
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["adopted"], d["blocked_expired"], d["approval_ready"]')" "([], [], True)" "T21: 정상 적용 뒤엔 adopted·blocked_expired 둘 다 비고 승인 게이트가 열린다"
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
# [Task 3 실행 노트 — AC20] 전방 포인터 계약 아래서는 `record-findings` 경로(라우터를
# 거치지 않고 손으로 후속을 심는 것)로 `superseded_by` 를 쓸 수 없다 — 그 필드를 쓰는 곳은
# `docreview_route.py` 의 재상승 루프 하나뿐이다(§`PUBLIC_FIELDS` 는 finding 의 공개 필드이지
# decides 레코드가 아니다). 그래서 이 케이스의 둘째 단언은 브리프 원안(「후속이 생기면
# 만료 항목은 안 막는다」)을 그대로 두면 새 계약에서 거짓이 된다 — 뒤집어 그 사실 자체를
# 락으로 만든다. 「후속을 채택·적용하면 승인이 다시 열린다」 쪽은 `finalize` 의 실제
# 재상승 경로로만 잴 수 있으므로 `case_AC20_reexpiry_blocks_again` 으로 옮겼다(커버리지
# 손실 아님).
case_T22b_expired_superseded_unblocks() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null       # 라운드 2 — 변경 없음 → expired
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["blocked_expired"], d["approval_ready"]')" "(['aaaa0001#r1.1'], False)" "T22b: 후속이 아직 없는 expired 는 계속 막는다(의무를 아무도 안 짐)"
  seed_findings "$d" "[$F_DEC_R2]"                        # record-findings 경로 — 포인터를 쓰지 않는다
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["blocked_expired"], d["approval_ready"]')" "(['aaaa0001#r1.1'], False)" "T22b: 후속 finding 이 «있어도» 포인터가 없으면 계속 막는다(역방향 스캔 금지)"
  rm -rf "$d"
}
# AC20 ① — 만료를 가리키지만 «의무를 지지 않는» 후속 넷(비차단 ask · defer · drop · 재비판
# reject) 이 각각 와도 차단은 유지돼야 한다. 넷 다 record-findings 경로라 supersedes 는
# 라우터가 아니라 픽스처가 직접 붙인다 — superseded_by 는 어차피 아무도 안 쓴다.
case_AC20_nonobligation_successors_still_block() {
  local succ
  for succ in "$F_SUCC_ASK" "$F_SUCC_DEFER" "$F_SUCC_DROP" "$F_SUCC_REJ"; do
    local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
    py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' >/dev/null
    next_round "$d" "$FX/design-sample.md" >/dev/null      # 변경 없음 → expired
    seed_findings "$d" "[$succ]"
    local disp; disp="$(printf '%s' "$succ" | jgets 'd["disposition"] + ("/" + d["state"] if d.get("state") else "")')"
    assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["blocked_expired"], d["approval_ready"]')" \
      "(['aaaa0001#r1.1'], False)" "AC20①: 의무를 안 지는 후속($disp)은 차단을 풀지 않는다"
    rm -rf "$d"
  done
}
# AC20 ②③ — 실제 finalize 경로의 재상승이 전방 포인터를 쓰고(②), 후속이 다시 만료하면
# 낡은 포인터가 아니라 빈 포인터로 다시 막는다(③, 한 만료 인스턴스당 한 번만 유효).
case_AC20_reexpiry_blocks_again() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  local gid; gid="$(fsum "$d" 'Non-goals' '["id"]')"
  py docreview_state.py decide --state-dir "$d" --id "$gid" --choice adopt --quote '채택' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null        # 라운드 2 — 변경 없음 → expired
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-nolayer2.txt" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/diff2.json" --doc "$FX/design-sample.md" > "$d/fin2.json"
  local succ; succ="$(jget "$d/fin2.json" '[x["id"] for x in d["findings"] if "expired" in x["summary"]][0]')"
  assert_eq "$(st_yaml "$d" 'st["decides"]["'"$gid"'"].get("superseded_by")')" "$succ" "AC20②: 재상승 루프가 후속 id 를 전방 포인터로 남긴다"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["blocked_expired"]')" "[]" "AC20②: 포인터가 찍힌 만료는 더 막지 않는다"
  # 후속을 채택했는데 또 미적중 → 재만료. 낡은 포인터가 아니라 빈 포인터로 다시 막아야 한다.
  py docreview_state.py decide --state-dir "$d" --id "$succ" --choice adopt --quote '이번엔 적용' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null        # 라운드 3 — 또 변경 없음
  # [Task 3 fix round 1 주석] 이 단언은 자연 경로에서 공허하게 참이다 — succ 는 애초에
  # superseded_by 를 받은 적이 없어서(자기 자신이 후속이지 원본이 아니다) None 은 그저
  # 「한 번도 안 찍힘」이다. 「만료 인스턴스당 포인터 한 번」이 여기서 실제로 지키는
  # 힘은 `pop()` 이 아니라 **id 신선도**다 — 재만료는 항상 새 permit·같은 finding_id 라
  # 새 포인터를 쓸 대상 자체가 없다. `pop()` 이 실제로 막는 「낡은 포인터가 새 만료를
  # 남몰래 푸는」 상태는 이 케이스가 아니라 case_AC20_stale_pointer_cleared_on_reobserve
  # (픽스처로 그 조합을 강제) 가 잰다 — 둘의 분업은 그렇게 갈린다.
  assert_eq "$(st_yaml "$d" 'st["decides"]["'"$succ"'"]["state"], st["decides"]["'"$succ"'"].get("superseded_by")')" "('expired', None)" "AC20③: 재만료한 항목의 포인터는 비어 있다"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets '"'"$succ"'" in d["blocked_expired"]')" "True" "AC20③: 재만료는 다시 막는다(낡은 포인터가 안 푼다)"
  rm -rf "$d"
}
# [Task 4 실행 노트 — 수명 갱신] Task 3 시점엔 이 픽스처가 강제하는 조합(포인터가
# 찍힌 decides 레코드가 같은 id 로 새 permit 을 다시 받는 것)이 CLI 로 도달 불가였다.
# Task 4 의 만료 재결정 탈출구(`cmd_decide` 가 `state in ("open", "expired")` 를 받게
# 넓어짐)가 그 창을 실경로로 열었다 — `case_AC22_stale_pointer_cleared_via_redecide`
# (아래, Task 4 절)가 픽스처 없이 그 경로(만료 → finalize 가 포인터를 씀 → 탈출구로
# 재결정 → 재만료)를 그대로 걷는다. 이 픽스처 케이스는 그래도 남긴다 — `cmd_decide`
# 가 재결정에서 포인터를 지우는 것(Task 4 의 별도 정정)과 무관하게, `cmd_observe_diff`
# 의 `d.pop("superseded_by", None)` **하나만** 격리해서 잴 수 있는 유일한 자리이기
# 때문이다(탈출구 코드가 재결정 시점에 먼저 지워버리면 이 관측-시점 가드 자체를 그
# CLI 경로에서는 따로 못 잰다).
case_AC20_stale_pointer_cleared_on_reobserve() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null        # 라운드 2 — 변경 없음 → expired
  python3 "$FX/st_set_stale_pointer.py" "$d/docreview-state.md" 'aaaa0001#r1.1' 'STALE#r9.9' '#12-files-to-modify'
  next_round "$d" "$FX/design-sample.md" >/dev/null        # 라운드 3 — 픽스처가 연 permit 을 observe-diff 가 처리
  assert_eq "$(st_yaml "$d" 'st["decides"]["aaaa0001#r1.1"].get("superseded_by")')" "None" "AC20: 재평가된 만료는 낡은 포인터를 지운다(다음 만료가 그걸로 안 풀림)"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets '"aaaa0001#r1.1" in d["blocked_expired"]')" "True" "AC20: 낡은 포인터를 지운 뒤엔 다시 막는다"
  rm -rf "$d"
}
# ── 만료 재결정 탈출구 (Task 4, AC22) ───────────────────────────────────────
case_AC22_expired_escape_hatch() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null        # expired + 예약
  # ① 렌더 본문에 차단 항목의 id 가 나온다.
  assert_eq "$(py docreview_state.py gate --state-dir "$d" --render | grep -c 'aaaa0001#r1.1')" "1" "AC22①: 차단 중인 만료 항목이 게이트 본문에 렌더된다"
  # ② 「보류」는 거부한다 — held 는 열린 decide 에도 차단 만료에도 안 들어 승인을 열어 버린다.
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice hold --quote '나중에' >/dev/null 2>&1
  assert_eq "$?" "1" "AC22②: 만료의 「보류」는 거부된다"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["approval_ready"]')" "False" "AC22②: 거부됐으므로 여전히 막힌다"
  # ③ 「기각」이 예약을 함께 폐기한다.
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice reject --quote '이건 안 한다' >/dev/null
  assert_eq "$(st_yaml "$d" 'st["decides"]["aaaa0001#r1.1"]["state"], st["reraise"]')" "('rejected', [])" "AC22③: 만료 기각 → rejected + 미소비 예약 폐기"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["approval_ready"]')" "True" "AC22③: 사용자가 치웠으므로 승인이 열린다"
  rm -rf "$d"
}
case_AC22_nonexpired_states_still_refused() {
  local d st
  for st in reject hold; do
    d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
    py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice "$st" --quote '첫 결정' >/dev/null
    py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '다시' >/dev/null 2>&1
    assert_eq "$?" "1" "AC22③: 첫 결정이 $st 였던 항목의 재결정은 거부된다"
    rm -rf "$d"
  done
  # [리뷰 M5] adopted 도 네 번째 거부 상태다 — 그 라운드에 이미 연 permit 이 아직
  # 관측을 기다리는 중이라, 재결정할 대상이 아니라 다음 라운드 observe-diff 의 결과
  # (applied 나 expired)를 기다리는 중인 것뿐이다(설계 §6.4).
  d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' >/dev/null
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '다시' >/dev/null 2>&1
  assert_eq "$?" "1" "AC22③: adopted(관측 대기 중)의 재결정도 거부된다"
  rm -rf "$d"
  d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' >/dev/null
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null     # 변경 관측 → applied
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice reject --quote '되돌려' >/dev/null 2>&1
  assert_eq "$?" "1" "AC22③: applied 의 재결정도 거부된다"
  rm -rf "$d"
}
# [리뷰 I1] `case_AC22_expired_escape_hatch` 가 렌더를 재는 항목은 F_DEC(kind="pre") 뿐이라
# post 만료의 원복-경고 꼬리(§6.4 탈출구 문단 마지막 문장)를 렌더 문자열에서 지워도
# 아무 락도 못 잡았다(리뷰 실측: 68/68 GREEN 유지). `_post_with_real_hash`(case_T25·T26 가
# 쓰는 헬퍼)로 사후 decide 를 기각 → 원복 permit → 그 라운드 관측 안 됨 → post 만료까지
# 실제로 걷고, 선결조건(state·kind)을 먼저 단언한 뒤에만 렌더를 잰다.
case_AC22_post_expiry_render_tail() {
  local d; d="$(_post_with_real_hash)"; next_round "$d" "$FX/design-sample-r2.md" >/dev/null   # 원복 관측 안 됨
  assert_eq "$(st_yaml "$d" 'st["decides"]["dddd0001#r2.1"]["state"], st["decides"]["dddd0001#r2.1"]["kind"]')" "('expired', 'post')" "AC22: 사후 결정의 원복 미관측 → post 만료(렌더 단언의 선결조건)"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" --render | grep -c '원복 의무를 관측 없이 종결한다')" "1" "AC22: post 만료 렌더에 원복 경고 꼬리가 실린다(§6.4 탈출구 마지막 문장)"
  rm -rf "$d"
}
# [Task 4 실행 노트] Task 3 의 픽스처(`st_set_stale_pointer.py`)가 강제하던 조합 — 포인터가
# 찍힌 만료 항목이 같은 id 로 새 permit 을 다시 받는 것 — 을 이제 픽스처 없이 CLI 로 그대로
# 걷는다: 만료 → finalize(재상승 루프가 전방 포인터를 씀) → 탈출구로 재결정(채택) → 다음
# 라운드 무변경(재만료). 중간 단언(재결정 직후)은 `cmd_decide` 자신의 pop(위 Task 4 정정 —
# 재결정이 expired 를 벗어날 때 포인터를 비운다)을 겨눈다 — `cmd_observe_diff` 의 독립
# pop(위 `case_AC20_stale_pointer_cleared_on_reobserve` 가 격리해 재는 그 코드)은 다음
# 라운드 관측까지 기다려야 걸리므로 이 창을 못 잰다.
case_AC22_stale_pointer_cleared_via_redecide() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  local gid; gid="$(fsum "$d" 'Non-goals' '["id"]')"
  py docreview_state.py decide --state-dir "$d" --id "$gid" --choice adopt --quote '채택' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null        # 라운드 2 — 변경 없음 → expired
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-nolayer2.txt" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/diff2.json" --doc "$FX/design-sample.md" > "$d/fin2.json"
  local succ; succ="$(jget "$d/fin2.json" '[x["id"] for x in d["findings"] if "expired" in x["summary"]][0]')"
  assert_eq "$(st_yaml "$d" 'st["decides"]["'"$gid"'"].get("superseded_by")')" "$succ" "AC22: finalize 가 gid 에 전방 포인터를 남긴다(재상승, Task 3)"
  py docreview_state.py decide --state-dir "$d" --id "$gid" --choice adopt --quote '재결정: 다시 채택' >/dev/null
  assert_eq "$(st_yaml "$d" 'st["decides"]["'"$gid"'"].get("superseded_by")')" "None" "AC22: 탈출구 재결정이 그 자리에서 낡은 포인터를 지운다"
  next_round "$d" "$FX/design-sample.md" >/dev/null        # 라운드 3 — 또 변경 없음 → 재만료
  assert_eq "$(st_yaml "$d" 'st["decides"]["'"$gid"'"].get("superseded_by")')" "None" "AC22: 재만료 뒤에도 포인터는 비어 있다(옛 succ 를 안 물려받음)"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets '"'"$gid"'" in d["blocked_expired"]')" "True" "AC22: 재만료는 다시 막는다(픽스처 없이 CLI 로)"
  rm -rf "$d"
}
# ── 재상승 후속의 「보류」 거부 (Task 4 of 2026-09-08-docreview-design-doc-site,
#    설계 §6.4 알려진 한계 (a)) ───────────────────────────────────────────────
# 전방 포인터는 의무를 후속으로 «옮긴다» — 원본은 `superseded_by` 로 blocked_expired
# 를 벗어나고 후속은 평범한 open decide 다. 그 후속에 「보류」가 통과하면 원본의
# 차단을 한 홉 건너에서 푼다(AC20 의 전방 포인터 + AC21 의 예약 누적이 재상승을 항상
# 성공시키면서 이 재설계 자신이 만든 결함). `case_AC22_stale_pointer_cleared_via_redecide`
# 와 같은 경로로 픽스처 없이 실제 재상승 후속을 CLI 로 얻는다.
case_AC22b_reraise_successor_hold_refused() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null        # 라운드 2 — 변경 없음 → expired + 예약
  # [Task 4 fix round 1 — 리뷰 I5 정정] route_r1 의 기본 critic(critic-r1.txt) 은 이
  # decide 말고도 fix·ask 여러 건을 함께 만든다 — 그 클러터가 approval_ready 를 이
  # 성공/재상승과 무관하게 늘 False 로 묶어, 아래 마지막 단언을 공허하게 만들었다
  # (리뷰 실측: `_is_reraise_successor` 를 `return False` 로 눌러도 approval_ready
  # 는 여전히 False — 4개의 다른 open decide·3개의 미적용 fix·1개의 차단 ask 가
  # 계속 막았다). layer1·layer2 둘 다 «형식은 맞지만 빈» 블록으로 다른 finding 을
  # 하나도 안 만든다 — finalize 뒤 원장에 남는 decide 는 재상승 후속 하나뿐이라,
  # 이 항목의 상태 전이가 approval_ready 를 «직접» 정한다(아래 클러터-없음 선결조건
  # 이 그 사실 자체를 잰다). 별도 mktemp 없이 `$d` 안에 둔다 — 케이스 끝의
  # `rm -rf "$d"` 가 함께 지운다.
  local empty_critic="$d/critic-empty.txt"
  printf '리뷰 없음.\n\n```docreview-layer1\n[]\n```\n\n```docreview-layer2\n[]\n```\n' > "$empty_critic"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$empty_critic" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/diff2.json" --doc "$FX/design-sample.md" > "$d/fin2.json"
  local succ; succ="$(jget "$d/fin2.json" '[x["id"] for x in d["findings"] if x["disposition"]=="decide" and "expired" in x["summary"]][0]')"
  assert_eq "$(st_yaml "$d" 'st["decides"]["aaaa0001#r1.1"].get("superseded_by")')" "$succ" "AC22b: finalize 가 원본에 전방 포인터를 남긴다(선결조건, 재상승)"
  assert_eq "$(st_yaml "$d" 'st["decides"]["'"$succ"'"]["state"]')" "open" "AC22b: 후속은 평범한 open decide 다(선결조건 — 열려 있지 않으면 「보류」시도 자체가 무의미)"
  # I1(리뷰) — fin.json 채널 자체를 잠근다. `gate_summary` 는 선택지 목록을 전혀
  # 안 내므로(버킷만) JSON 을 읽는 소비자에게는 이 필드가 유일한 선택지 채널이다 —
  # render 만 맞고 fin.json 의 decision_view.alternatives 는 여전히 셋을 내던 것이
  # 리뷰가 실측으로 잡은 결함(fin.json·state.md·골든 셋 다 새는 채널).
  assert_eq "$(jget "$d/fin2.json" '[x["decision_view"]["alternatives"] for x in d["findings"] if x["id"]=="'"$succ"'"][0]')" \
    "['채택(적용)', '기각(원복)']" "AC22b: fin.json 의 decision_view.alternatives 에도 「보류」가 없다(I1 — JSON 채널)"
  # I5(리뷰) — 선결조건: 이 항목이 유일한 열린 항목이다(클러터 없음). 이게 없으면
  # 아래 마지막 단언은 이 성공/실패와 무관하게 항상 False 라 아무것도 못 잰다.
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["open_decide"], d["unapplied_fix"], d["blocking_ask_open"]')" \
    "(['$succ'], [], [])" "AC22b: 선결조건 — 재상승 후속이 유일한 열린 항목이다(클러터 없음, I5)"
  local out rc
  # `fail()`(§docreview_state.py) 은 실패 JSON 을 stderr 로 낸다 — `2>&1` 로 합쳐야
  # $out 이 실제로 그 JSON 을 받는다(성공 경로의 `_emit` 은 stdout, 실패는 stderr).
  out="$(py docreview_state.py decide --state-dir "$d" --id "$succ" --choice hold --quote '보류' 2>&1)"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd.get("reason")')" "1 decide_hold_not_allowed_for_reraise_successor" \
    "AC22b: 재상승 후속의 「보류」는 거부된다(원본의 차단을 한 홉 건너에서 풀지 못한다) — 사유까지 검증(I3)"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["approval_ready"]')" "False" \
    "AC22b: 보류 시도 뒤에도 승인은 열리지 않는다(I5 — 이 항목이 유일한 블로커였으므로 공허하지 않다)"
  rm -rf "$d"
}
# ── 재상승 후속의 kind·prev_hash 승계 (Task 5, 설계 §6.4 알려진 한계 (b)) ────────
# 원본이 post(얼림 diff 가 만든 사후 결정)였고 「기각」으로 원복 permit(expect_hash =
# 기각 시점 스냅샷 해시)이 열렸는데 그 원복이 관측되지 않아 만료하면, 후속은 원본의
# kind·prev_hash 를 물려받아야 한다 — 하드코딩된 "pre" 는 「채택」이 해시 대조 없는
# apply permit 을 열게 만들어 원복 의무를 「앵커가 닿기만 하면 통과」로 강등시킨다
# (되돌리지 않은 얼림 위반이 그대로 승인된다). `_post_with_real_hash`(T25·T26 이
# 쓰는 헬퍼, 실제 r1 해시를 prev_hash 로 갖는 post finding 을 심고 기각까지 걷는다)
# 로 원복 permit 을 연 뒤, 그 라운드 관측 안 됨(post 만료)까지 실제로 걷고
# finalize 로 후속을 낸다.
#
# [fix round 1 — 리뷰 I1 정정] 브리프 Step1 의 넷째 단언(사후 고지 꼬리)을 원판에서
# finalize «전» 원본(`case_AC22_post_expiry_render_tail` 과 같은 대상·같은 리터럴,
# cases.sh 구판 411-412)으로 옮겨 달았었다 — 이미 있는 락의 verbatim 중복이라 새로
# 재는 게 없었고(M2), 「선결조건」이라는 라벨이 그 단언이 충족된 것처럼 읽히게
# 만들었다. 리뷰가 이것을 브리프 내부 불일치(Step2 스니펫만으로는 Step1 을 못 채움)
# 로 판정해 escalate 했고, 처분은 `_rg_decide` 에 같은 꼬리를 잇는 것으로 났다
# (docreview_state.py, `_post_kind_notice` 공유 헬퍼 — 리터럴은 여전히 한 곳). 이제
# 이 케이스는 후속 «자신의» 렌더(finalize 뒤, open_decide → `_rg_decide`)에서 직접
# 꼬리를 잰다 — 예전 선결조건 중복은 필요 없어졌으므로 지웠다.
case_AC22c_reraise_inherits_post_kind() {
  local d; d="$(_post_with_real_hash)"; next_round "$d" "$FX/design-sample-r2.md" >/dev/null   # 원복 관측 안 됨 → expired + 재상승 예약
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-nolayer2.txt" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep3.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/diff3.json" --doc "$FX/design-sample-r2.md" > "$d/fin3.json"
  # M4(fix round 1) — 부분문자열("expired" in summary) 대신 계보 포인터로 구조적으로
  # 고른다. 원본 id 는 `_post_with_real_hash`/F_POST 가 고정한 "dddd0001#r2.1" 이고,
  # 재상승 후속만 `supersedes` 에 이 값을 싣는다(escalated 후속도 `supersedes` 를
  # 쓰지만 이 라운드엔 없다) — summary 어휘가 critic 픽스처를 따라 바뀌어도 안 흔들린다.
  local succ; succ="$(jget "$d/fin3.json" '[x["id"] for x in d["findings"] if x["supersedes"]=="dddd0001#r2.1"][0]')"
  assert_eq "$(st_yaml "$d" 'st["decides"]["'"$succ"'"]["kind"]')" "post" "AC22c: 후속이 원본의 kind(post)를 물려받는다(하드코딩 pre 가 아니다)"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" --render | grep -c '원복 의무를 관측 없이 종결한다')" "1" \
    "AC22c: 후속(open decide) 자신의 렌더에 원복 경고 꼬리가 실린다(§6.4 한계 (b) 후속 경로 — fix round 1 I1)"
  local out; out="$(py docreview_state.py decide --state-dir "$d" --id "$succ" --choice adopt --quote '재확인: 이번엔 채택')"
  assert_eq "$(printf '%s' "$out" | jgets 'd["state"], d["permit"]')" "('applied', None)" "AC22c: post 후속의 「채택」은 즉시 applied 다(사후 채택의 계약 — pre 였다면 adopted + apply permit)"
  rm -rf "$d"
}
# 위 케이스와 같은 셋업이지만 kind 승계와 «독립»된 축(prev_hash)만 잰다 — 변이
# ①(kind 하드코딩 복원)과 변이 ②(prev_hash 승계 삭제)가 한 케이스 안에서 서로를
# 가리지 않도록 쪼갠다(브리프 Step 3 — 하나를 되돌려도 다른 단언이 여전히 RED 면
# 매트릭스에서 어느 변이가 어느 단언을 잡았는지 구별이 안 된다). `prev_hash` 는
# `record_findings` 가 `PUBLIC_FIELDS` 를 거치지 않고 항목에서 직접 읽으므로
# (`st["decides"][fid] = {..., "prev_hash": it.get("prev_hash"), ...}`, `kind`
# 처럼 `PUBLIC_FIELDS` 목록에 없어도 decides 레코드에 실린다) 이 단언은 그 경로가
# 실제로 값을 나른다는 것까지 함께 잰다.
case_AC22c_reraise_inherits_prev_hash() {
  local d; d="$(_post_with_real_hash)"; next_round "$d" "$FX/design-sample-r2.md" >/dev/null   # 원복 관측 안 됨 → expired + 재상승 예약
  local orig_hash; orig_hash="$(st_yaml "$d" 'st["decides"]["dddd0001#r2.1"]["prev_hash"]')"
  # M1(fix round 1) — 공허성 바닥. 양변이 같은 원장에서 나오므로 `record_findings`
  # 가 `prev_hash` 를 아예 안 싣게 되면 둘 다 `None` 이 되어 아래 등식이 «공허하게»
  # GREEN 이 된다(리뷰의 V1 프로브가 실측으로 확인). 원본이 실제 12자리 hex 해시임을
  # 먼저 박아, 등식이 None==None 으로 새지 않게 한다.
  assert_grep "$orig_hash" '^[0-9a-f]{12}$' "AC22c: 선결조건(공허성 바닥) — 원본 prev_hash 가 실제 해시 모양이다(None==None 등식이 아니다)"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-nolayer2.txt" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep3.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/diff3.json" --doc "$FX/design-sample-r2.md" > "$d/fin3.json"
  local succ; succ="$(jget "$d/fin3.json" '[x["id"] for x in d["findings"] if x["supersedes"]=="dddd0001#r2.1"][0]')"
  assert_eq "$(st_yaml "$d" 'st["decides"]["'"$succ"'"]["prev_hash"]')" "$orig_hash" "AC22c: 후속의 prev_hash 가 원본의 prev_hash 와 같다"
  rm -rf "$d"
}
# [Task 5 실행 노트 — fix round 1 I2 정정] 브리프의 두 변이(하드코딩 "pre" 복원 ·
# prev_hash 승계 삭제)는 «post» 원본만 겨눈다. `d0.get("kind")` 는 양방향 값을
# 다루는 식이라, 반대 방향 회귀(«pre» 원본인데 후속이 "post" 로 과잉 승계되는 것
# — kind 를 무조건 "post" 로 강제하는 변이)를 이 케이스가 새로 잰다. **이 케이스가
# 그 방향을 "처음 잡는" 락은 아니다** — 원판 코멘트가 「그때까지 그 방향을 잡는
# 락이 하나도 없었다」고 주장한 것은 리뷰가 측정으로 반증했다: 같은 변이로
# `test_docreview_golden.sh` 가 RED(가 T22 후속의 `"kind"` 가 pre→post 로 바뀌어
# `.fin.json`·`.state.md` 둘 다 어긋난다)이고 `case_AC20_reexpiry_blocks_again` 도
# RED(2) 다(post 후속은 채택 즉시 applied 라 그 케이스가 기대하는 재만료 자체가
# 안 일어난다). 이 케이스가 유일하게 갖는 값은 **귀속** 이다 — 골든 diff 도
# AC20③ 의 실패 메시지도 `kind` 를 한 글자도 언급하지 않는 반면, 이 케이스는
# `st["decides"][succ]["kind"]` 를 직접 단언해 무엇이 깨졌는지 이름을 붙인다.
# 위험한 이유는 여전히 옳다: "post" 로 잘못 태어나면 「채택」이 `cmd_decide` 의
# `if d.get("kind") == "post":` 분기를 타 permit 없이 즉시 applied 로 끝난다 —
# 「실제로 그 편집이 관측됐는가」를 permit 이 검증하는 pre 의 정상 계약을 건너뛴다.
# `case_AC22_stale_pointer_cleared_via_redecide` 의 앞부분(F_DEC 채택 → 무변경 →
# expired → finalize)과 같은 셋업을 재사용해 실제 라우팅으로 후속을 낸다.
case_AC22c_reraise_preserves_pre_kind() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null        # 라운드 2 — 변경 없음 → expired + 예약
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-nolayer2.txt" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/diff2.json" --doc "$FX/design-sample.md" > "$d/fin2.json"
  # M4(fix round 1) — 위와 같은 구조적 선택자. 원본 id 는 F_DEC 의 고정 id
  # "aaaa0001#r1.1".
  local succ; succ="$(jget "$d/fin2.json" '[x["id"] for x in d["findings"] if x["supersedes"]=="aaaa0001#r1.1"][0]')"
  assert_eq "$(st_yaml "$d" 'st["decides"]["'"$succ"'"]["kind"]')" "pre" "AC22c: pre 원본의 후속은 pre 로 남는다(post 로 과잉 승계되지 않는다)"
  rm -rf "$d"
}
# `decide_choices` 를 실제로 import 해 낸다(문자열로 옮겨 적지 않는다) — heredoc-in-$()
# 파싱 함정을 피해 st_yaml 처럼 python -c 한 줄로 둔다.
dc_choices() {   # dc_choices <state-dir> <fid> → decide_choices(st, fid) 의 python 리스트 repr
  python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); from docreview_state import load_state, decide_choices; st = load_state(sys.argv[2]); print(decide_choices(st, sys.argv[3]))' "$SCRIPTS" "$1" "$2"
}
# render 의 그 id 블록에서 「대안:」 줄을 뽑아 decide_choices 가 내는 집합과 «라벨로
# 바꾼 뒤» 비교한다(라벨 문자열이 아니라 집합 — 순서 무관). fid 는 hash 파생이라
# "] <fid> —" 조합이 그 id 의 [decide…] 헤더 줄에서만 나온다.
choices_match() {   # choices_match <render-text> <fid> <state-dir> → True/False
  local alt; alt="$(printf '%s\n' "$1" | grep -F -A4 -- "] $2 —" | grep '대안: ' | head -1)"
  python3 -c '
import sys
sys.path.insert(0, sys.argv[1])
from docreview_state import load_state, decide_choices
LABEL = {"adopt": "채택(적용)", "reject": "기각(원복)", "hold": "보류"}
st = load_state(sys.argv[2])
choices = decide_choices(st, sys.argv[3])
expected = {LABEL[c] for c in choices}
alt_line = sys.argv[4]
offered = set()
if "대안: " in alt_line:
    offered = {x.strip() for x in alt_line.split("대안: ", 1)[1].split("/")}
print(bool(choices) and expected == offered)
' "$SCRIPTS" "$3" "$2" "$alt"
}
# [Task 4 fix round 1 — 리뷰 I4] `_rg_expired` 도 괄호 안에 선택지를 나열한다 —
# `_rg_decide` 의 「대안:」 줄과는 다른 형식(별도 줄이 아니라 한 줄에 인라인)이라
# `choices_match` 를 그대로 못 쓴다. 정규식으로 다시 파싱하지 않는다 — 라벨
# 자체가 괄호를 품는다(`채택(적용)`). 대신 실제로 찍히는 접두사·형식을 그대로
# 재구성해 벗겨낸다(프로그램의 포맷 문자열과 같은 모양).
choices_match_expired() {   # choices_match_expired <render-text> <fid> <state-dir> → True/False
  local line; line="$(printf '%s\n' "$1" | grep -F -- "[만료·차단] $2 —" | head -1)"
  python3 -c '
import sys
sys.path.insert(0, sys.argv[1])
from docreview_state import load_state, decide_choices
LABEL = {"adopt": "채택(적용)", "reject": "기각(원복)", "hold": "보류"}
st = load_state(sys.argv[2])
fid = sys.argv[3]
choices = decide_choices(st, fid)
expected = {LABEL[c] for c in choices}
line = sys.argv[4]
summary = st["findings"][fid].get("summary") or ""
prefix = "[만료·차단] %s — %s (" % (fid, summary)
offered = set()
if line.startswith(prefix) and line.endswith(")"):
    body = line[len(prefix):-1].split(" — ", 1)[0]   # post 만료 원복-경고 꼬리 제거
    offered = {x.strip() for x in body.split("/")}
print(bool(choices) and expected == offered)
' "$SCRIPTS" "$3" "$2" "$line"
}
# 「제안 = 수용」 등식 — 한 state 안에 세 부류(평범한 open · expired(비후속) · 재상승
# 후속)를 모두 만들고 각각을 잰다. 셋 다 이제 렌더 텍스트로 비교한다(open 둘은
# `_rg_decide` 의 「대안:」 줄, expired 는 `_rg_expired` 의 인라인 괄호 — [Task 4
# fix round 1, 리뷰 I4] 전에는 expired 쪽을 `decide_choices` 하나로만 쟀는데,
# `_rg_expired` 가 «따로» 하드코딩한 열거가 그 함수와 갈려도 이 락은 구조적으로
# 못 봤다 — 이제 렌더 텍스트 자체를 검사해 그 축도 잡는다). `dc_choices` 로도
# 한 번 더 재는 것은 렌더 파싱과 무관하게 함수 자체가 맞는지 보는 이중 확인이다.
case_choices_offered_equal_accepted() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null        # 라운드 2 — 변경 없음 → expired + 예약
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-nolayer2.txt" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/diff2.json" --doc "$FX/design-sample.md" > "$d/fin2.json"
  local succ normal
  succ="$(jget "$d/fin2.json" '[x["id"] for x in d["findings"] if x["disposition"]=="decide" and "expired" in x["summary"]][0]')"
  # critic-nolayer2 가 같은 라운드에 만드는 무관 lineage(Non-goals, aaaa 와 다른 bucket)
  # — 이것이 「평범한 open」. [리뷰 I2] 이 항목은 재상승 사슬(aaaa→succ)과 «같은
  # state 안에 공존»한다 — 아래 마지막 단언(양성 짝)이 정확히 이 공존을 이용한다.
  normal="$(jget "$d/fin2.json" '[x["id"] for x in d["findings"] if x["disposition"]=="decide" and "expired" not in x["summary"]][0]')"
  # 「expired(비후속)」 — 새 decide 를 이번 라운드(2)에 심어 채택 → 다음 라운드
  # 무변경 → expired, 후속은 만들지 않는다(finalize 를 다시 안 부른다).
  seed_findings "$d" '[{"id":"ffff0001#r2.1","lineage":"ffff0001#r2.1","bucket":"ffff0001","origin":"reviewer","layer":2,"category":"ambiguity","anchor":"#2-goals","edit_scope":"#2-goals","disposition":"decide","summary":"막힌 만료 테스트용","evidence":null,"blocks":[],"kind":"pre"}]'
  py docreview_state.py decide --state-dir "$d" --id 'ffff0001#r2.1' --choice adopt --quote '채택' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null        # 라운드 3 — 변경 없음 → ffff expired(후속 없음)
  local blocked="ffff0001#r2.1"

  assert_eq "$(st_yaml "$d" 'st["decides"]["'"$succ"'"]["state"]')" "open" "선결: 재상승 후속은 open 이다"
  assert_eq "$(st_yaml "$d" 'st["decides"]["'"$normal"'"]["state"]')" "open" "선결: 평범한 항목도 open 이다"
  assert_eq "$(st_yaml "$d" 'st["decides"]["'"$blocked"'"]["state"], st["decides"]["'"$blocked"'"].get("superseded_by")')" "('expired', None)" "선결: 막힌 항목은 후속 없이 expired 다"

  local render; render="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_eq "$(choices_match "$render" "$normal" "$d")" "True" "제안=수용: 평범한 open — 「대안:」 줄과 decide_choices 가 같은 집합"
  assert_eq "$(choices_match "$render" "$succ" "$d")" "True" "제안=수용: 재상승 후속 — 「대안:」 줄과 decide_choices 가 같은 집합(둘 다 보류 없이 둘)"
  assert_eq "$(dc_choices "$d" "$blocked")" "['adopt', 'reject']" "제안=수용: expired(비후속) — decide_choices 도 보류 없이 둘"
  assert_eq "$(choices_match_expired "$render" "$blocked" "$d")" "True" \
    "제안=수용: expired(비후속) — 렌더의 괄호 열거와 decide_choices 가 같은 집합(I4 — 렌더 텍스트로도 잰다)"

  # [리뷰 I2] 양성 짝 — `_is_reraise_successor` 가 `== fid`(대상 특정) 대신
  # `is not None`(존재만) 으로 넓어지면, 이 state 안에 재상승 사슬이 살아 있다는
  # 사실 «자체»가 무관한 $normal 의 「보류」까지 잘못 거부한다. 위 두 choices_match
  # 단언은 양쪽이 같은 decide_choices 에서 나오므로 이 축을 구조적으로 못 본다
  # (순환) — 실제 CLI 성공 여부로 따로 잰다. 다른 단언이 읽는 상태를 바꾸므로
  # 이 케이스의 맨 끝에 둔다.
  local out_hold rc_hold
  # `fail()` 은 stderr 로 낸다(`2>&1` 로 합친다) — 실패하면 "state" 키 자체가 없는
  # JSON(`{"ok": false, "reason": ..., "id": ...}`) 이라 `.get()` 으로 받는다
  # (`d["state"]` 는 그 갈래에서 KeyError 로 죽어 판정을 「못 잼」으로 가린다 —
  # 매트릭스 헤더의 "값이 아예 사라질 수 있는 변이" 함정, R19/R20).
  out_hold="$(py docreview_state.py decide --state-dir "$d" --id "$normal" --choice hold --quote '보류 — 재상승과 무관' 2>&1)"; rc_hold=$?
  assert_eq "$rc_hold $(printf '%s' "$out_hold" | jgets 'd.get("state")')" "0 held" \
    "I2 양성 짝: 재상승 사슬과 공존하는 평범한 open 의 「보류」는 여전히 성공한다"
  rm -rf "$d"
}
# [Task 4 fix round 1 — 리뷰 I3/Ruling 32] 사유 리터럴 셋 중 나머지 둘 — 「재상승
# 후속」쪽은 case_AC22b_reraise_successor_hold_refused 가 이미 JSON 으로 잰다(위).
# 브리프가 「기존 케이스가 그 문자열을 재고 있다」고 전제했던 것은 실은 거짓이었다
# (git grep 은 이 셋을 어떤 테스트도 원장 JSON 으로 재지 않았음을 보였다) — 그
# 전제를 참으로 만든다. `cases.sh:1008`(`case_AC6_reject_reasons_extra`)의 관용구
# (`assert_eq "$rc $(... reason)" "1 <literal>"`)를 그대로 쓴다.
case_decide_reason_literals_not_open_and_expired() {
  local d out rc
  # `fail()` 은 실패 JSON 을 stderr 로 낸다 — 둘 다 `2>&1` 로 합친다.
  d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice reject --quote '기각' >/dev/null
  out="$(py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '다시' 2>&1)"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd.get("reason")')" "1 decide_not_open" \
    "사유 리터럴: rejected 상태의 재결정 → decide_not_open"
  rm -rf "$d"
  d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null        # 변경 없음 → expired(비후속)
  out="$(py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice hold --quote '보류' 2>&1)"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd.get("reason")')" "1 decide_hold_not_allowed_for_expired" \
    "사유 리터럴: 평범한 expired 의 보류 → decide_hold_not_allowed_for_expired"
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
  local gr; gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_contains "$gr" "추가 라운드 1회 열기" "T39: 열린 것이 있어도 렌더 1단계가 사용자 말로 「추가 라운드 1회 열기」를 싣는다(Park P3)"
  assert_not_contains "$gr" "= extra_approval" "T39: 렌더에 날 모드 토큰 'extra_approval' 이 없다"
  rm -rf "$d"
}
# ── 상한 도달 + 열린 것 0 — 승인 게이트는 항상 두 단계다 (Park P3·D-U3) ────
# 기존(2026-09-06 설계 §8.2 원문)엔 「열린 것이 남아 있으면」만 두 단계였다 — 상한
# 도달 + 열린 것 0 은 approval_ready 하나로 즉시 진행 옵션이 열렸다(추가 라운드를
# 고를 자리가 없었다). 사용자가 이 동작을 뒤집었다: 상한 도달이면 항상 두 단계이고
# 1단계에 「추가 라운드 1회 열기」가 선다. 아래가 그 음 셀이고, 바로 다음이 그 양의
# 짝(상한 전 + 열린 것 0 은 예전대로 즉시 진행)이다.
case_cap_zero_open_two_stage() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  next_round "$d" "$FX/design-sample.md" >/dev/null; next_round "$d" "$FX/design-sample.md" >/dev/null
  local g; g="$(py docreview_state.py gate --state-dir "$d")"
  assert_eq "$(printf '%s' "$g" | jgets 'd["cap_reached"], d["approval_ready"], d["two_stage"], d["next_round_mode"]')" \
    "(True, True, True, 'extra_approval')" \
    "상한 도달 + 열린 것 0: approval_ready 와 무관하게 two_stage 참, next_round_mode 는 개별 승인(Park P3·D-U3)"
  local gr; gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_contains "$gr" "추가 라운드 1회 열기" "상한 도달 + 열린 것 0: 렌더 1단계가 사용자 말로 「추가 라운드 1회 열기」를 싣는다"
  assert_contains "$gr" "진행 옵션으로" "상한 도달 + 열린 것 0: 1단계 둘째 선택지 「진행 옵션으로」도 함께 실린다"
  assert_not_contains "$gr" "= extra_approval" "상한 도달 + 열린 것 0: 렌더에 날 모드 토큰 'extra_approval' 이 없다"
  rm -rf "$d"
}
case_precap_zero_open_not_two_stage() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  local g; g="$(py docreview_state.py gate --state-dir "$d")"
  assert_eq "$(printf '%s' "$g" | jgets 'd["cap_reached"], d["approval_ready"], d["two_stage"], d["next_round_mode"]')" \
    "(False, True, False, None)" \
    "양의 짝 — 상한 전 + 열린 것 0: two_stage 거짓, next_round_mode 없음(동작 불변)"
  local gr; gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_not_contains "$gr" "추가 라운드 1회 열기" "양의 짝: 상한 전 렌더엔 「추가 라운드 1회 열기」문구가 없다"
  assert_contains "$gr" "다음: 승인 게이트 — 진행 옵션 활성" "양의 짝: 상한 전 + 열린 것 0 은 예전처럼 즉시 진행 옵션이다"
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
# ── codex 산출물의 시점 판별 (prepare-recritic) ────────────────────────────
# 산출물 경로는 세션과 문서의 순수 함수라 같은 문서의 라운드마다 같은 파일이고, 직전 라운드의 산출물과 이번
# 라운드의 것은 내용으로 못 가른다. `prepare-recritic` 은 `begin-round` 가 기록한 라운드
# 시작보다 먼저 쓰인 codex 파일을 부재로 읽는다. 그래서 픽스처는 러너가 4단계에서 쓰듯
# 라운드 시작 «뒤» 에 상태 디렉토리로 복사해 넘긴다 — 커밋된 픽스처의 mtime 은 체크아웃
# 시각이라 언제나 라운드보다 앞선다.
codex_now() {   # codex_now <state-dir> <fixture> → 방금 쓴 사본 경로 (없는 경로는 그대로)
  if [ -f "$2" ]; then cp "$2" "$1/codex.yaml" && echo "$1/codex.yaml"; else echo "$2"; fi
}
backdate() { python3 -c 'import os, sys, time; t = time.time() - 60; os.utime(sys.argv[1], (t, t))' "$1"; }
case_codex_predates_round_absent() {
  local d; d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "시점 판별: init 실패"; return; }
  # 직전 라운드가 남긴 산출물 — 이번 라운드 시작보다 앞선다(거친 타임스탬프 FS 에서도 그 순서가 보이게 뒤로 민다)
  cp "$FX/codex-r1.yaml" "$d/codex.yaml"; backdate "$d/codex.yaml"
  snap "$FX/design-sample.md" "$d/s1.json"; py docreview_state.py begin-round --state-dir "$d" --snapshot "$d/s1.json" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-r1.txt" --codex "$d/codex.yaml" > "$d/prep.json"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-r1.txt" --codex "$d/never-written.yaml" > "$d/ctl.json"
  assert_eq "$(jget "$d/prep.json" 'd["degrade"]["codex_absent"], d["degrade"]["codex_reason"]')" "(True, 'codex_predates_round')" \
    "시점 판별: 라운드 시작보다 먼저 쓰인 codex 파일은 codex_failed: false 여도 부재다 (사유 codex_predates_round)"
  assert_eq "$(jget "$d/prep.json" 'd["items"]')" "$(jget "$d/ctl.json" 'd["items"]')" \
    "시점 판별: 그 라운드의 항목이 codex 파일이 없던 라운드와 같다 (직전 라운드 finding 섭취 0)"
  rm -rf "$d"
}
case_codex_after_round_start_read() {   # 위 부재 단언의 양의 짝
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  # 라운드 시작 «뒤» 에 쓰인 산출물 — 뒤로 밀지 않는다. 판별의 경계(시작 직후)를 그대로 잰다
  cp "$FX/codex-r1.yaml" "$d/codex.yaml"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-r1.txt" --codex "$d/codex.yaml" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" 'd["degrade"]["codex_absent"], d["degrade"]["codex_reason"], len(d["items"])')" "(False, None, 10)" \
    "시점 판별(양의 짝): 라운드 시작 뒤에 쓰인 codex 파일은 이번 라운드의 판정으로 읽힌다 (critic+codex 10건)"
  rm -rf "$d"
}
case_codex_round_start_unrecorded_absent() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import docreview_state as s
st = s.load_state(sys.argv[2]); st["rounds"][str(st["round"])].pop("started_mtime_ns", None); s.save_state(sys.argv[2], st)' "$SCRIPTS" "$d"
  cp "$FX/codex-r1.yaml" "$d/codex.yaml"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-r1.txt" --codex "$d/codex.yaml" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" 'd["degrade"]["codex_absent"], d["degrade"]["codex_reason"]')" "(True, 'round_start_unrecorded')" \
    "시점 판별: 라운드 시작 기록이 없으면 판별할 수 없으므로 부재로 닫는다 (사유 round_start_unrecorded)"
  rm -rf "$d"
}
st_mark() {   # st_mark <state-dir> <op> [<file>] — 라운드 시작 표식을 다루는 픽스처 조작(엔진 사본을 쓴다)
  python3 -c 'import os, sys
sys.path.insert(0, sys.argv[1]); import docreview_state as s
d, op = sys.argv[2], sys.argv[3]; st = s.load_state(d); cur = st["rounds"][str(st["round"])]
if op == "shift-r1-back":   # 라운드 1 시작을 120초 앞으로 되돌리고 파일을 그 +60초(ns 명시)에 둔다
    r = st["rounds"]["1"]; r["started_mtime_ns"] = int(r["started_mtime_ns"]) - 120 * 10**9; s.save_state(d, st)
    t = r["started_mtime_ns"] + 60 * 10**9; os.utime(sys.argv[4], ns=(t, t))
elif op == "tie":           # 파일 mtime 을 이번 라운드 표식과 정확히 같게
    t = int(cur["started_mtime_ns"]); os.utime(sys.argv[4], ns=(t, t))
elif op == "garble":        # 표식을 정수가 아닌 값으로
    cur["started_mtime_ns"] = "not-a-number"; s.save_state(d, st)
elif op == "window":        # 파일이 라운드 1 시작과 이번 라운드 시작 «사이» 에 있는가
    m = os.stat(sys.argv[4]).st_mtime_ns; c = cur.get("started_mtime_ns")
    print(st["round"], c is not None and int(st["rounds"]["1"]["started_mtime_ns"]) < m < int(c))
else:
    sys.exit("st_mark: unknown op %s" % op)' "$SCRIPTS" "$@"
}
# 직전 라운드의 산출물은 «직전 라운드 시작 뒤 · 이번 라운드 시작 앞» 에 쓰인다 — 위협의 실제 자리다.
# 위의 부재 단언은 파일을 모든 라운드 시작보다 앞에 두므로 «어느 라운드의 표식과 비교하는가»를
# 가르지 못한다. 라운드 1 시작을 120초 되돌리고 파일을 그 +60초에 두면, 어떤 타임스탬프
# 해상도에서도 파일은 두 시작 사이에 있다.
case_codex_prev_round_output_absent() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  cp "$FX/codex-r1.yaml" "$d/codex.yaml"; st_mark "$d" shift-r1-back "$d/codex.yaml"
  next_round "$d" "$FX/design-sample.md" >/dev/null
  assert_eq "$(st_mark "$d" window "$d/codex.yaml")" "2 True" \
    "시점 판별 전제: 직전 라운드 산출물이 라운드 1 시작과 라운드 2 시작 «사이» 에 있다"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-r1.txt" --codex "$d/codex.yaml" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" 'd["degrade"]["codex_absent"], d["degrade"]["codex_reason"]')" "(True, 'codex_predates_round')" \
    "시점 판별: 라운드 2 에서 직전 라운드 산출물(라운드 1 시작 뒤·라운드 2 시작 앞)은 부재다 — 비교 대상은 이번 라운드의 표식이다"
  rm -rf "$d"
}
case_codex_tie_absent() {   # 표식과 같은 시각 — 앞뒤를 가를 수 없으면 부재 쪽으로 닫는다
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  cp "$FX/codex-r1.yaml" "$d/codex.yaml"; st_mark "$d" tie "$d/codex.yaml"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-r1.txt" --codex "$d/codex.yaml" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" 'd["degrade"]["codex_absent"], d["degrade"]["codex_reason"]')" "(True, 'codex_predates_round')" \
    "시점 판별: mtime 이 라운드 시작 표식과 같으면 부재다 (동률은 부재 쪽)"
  rm -rf "$d"
}
case_codex_round_start_unreadable_absent() {
  local d rc; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  st_mark "$d" garble
  cp "$FX/codex-r1.yaml" "$d/codex.yaml"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-r1.txt" --codex "$d/codex.yaml" > "$d/prep.json" 2>/dev/null; rc=$?
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-r1.txt" --codex "$d/never-written.yaml" > "$d/ctl.json" 2>/dev/null
  assert_eq "$rc|$(jget "$d/prep.json" 'd["degrade"]["codex_absent"], d["degrade"]["codex_reason"]' 2>/dev/null)" "0|(True, 'round_start_unreadable')" \
    "시점 판별: 정수가 아닌 라운드 시작 표식은 죽지 않고 codex 부재로 닫는다 (rc 0, 사유 round_start_unreadable)"
  assert_eq "$(jget "$d/prep.json" 'd["items"]' 2>/dev/null)" "$(jget "$d/ctl.json" 'd["items"]' 2>/dev/null)" \
    "시점 판별: 표식이 깨져도 critic 항목은 그대로다 (codex 파일이 없던 라운드와 같다)"
  rm -rf "$d"
}
route_r1() {   # route_r1 <profile> <doc> [critic] [codex] [recritic-tmpl|--skip] → state dir; $R1 = finalize json path
  local prof="$1" doc="$2" critic="${3:-$FX/critic-r1.txt}" codex="${4:-$FX/codex-r1.yaml}" rtmpl="${5:-$FX/recritic-r1.txt.tmpl}"
  local d; d="$(r1 "$prof" "$doc")" || return 1
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$critic" --codex "$(codex_now "$d" "$codex")" > "$d/prep.json"; echo "$?" > "$d/prep.rc"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-r1.txt" --codex "$(codex_now "$d" "$FX/codex-r1.yaml")" > "$d/prep.json"
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
# 재비판 verdict 는 reject·raise·confirm 셋뿐이다. `vd = str(v.get("verdict") or "confirm")`
# 뒤의 분기는 이 셋 아닌 값을 전부 else 로 흘려 조용히 confirm 취급하고 원장에 아무것도
# 안 남긴다 — 형제 처분 정규화(normalize())는 같은 상황(disp not in RANK)에 ledger.coerced 를
# 남긴다. 대칭이 깨진 자리(Task 7, AC27).
case_AC27_unknown_verdict_coerced() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-r1.txt" "$FX/codex-failed.yaml" "--skip")"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-r1.txt" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep.json"
  local rt; rt="$(mktemp -t rt-XXXXXX.txt)"
  printf '```docreview-recritic\nverdicts:\n  - f: "f1"\n    verdict: maybe\nadded: []\n```\n' > "$rt"
  py docreview_route.py finalize --state-dir "$d" --recritic "$rt" --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_coerced"] >= 1')" "True" "AC27(1b): 어휘 밖 verdict 는 조용히 confirm 이 되지 않고 coerced 로 계수된다"
  rm -rf "$d" "$rt"
}
# AC27 의 쌍둥이 공백(Task 7b) — 재비판이 `same_as` 로 존재하지 않는 대상(전 라운드
# id·오타 등)을 지목하면, union-find 의 `if x in parent and y in parent:` 가드가
# 병합만 조용히 스킵하고 원장 어디에도 안 남았다(재상승 불변식 케이스
# `case_reraise_successor_immune_to_recritic` 의 주석에서 실측 확인됨). f1 은 known
# item 이라 unknown-f hold 를 안 타므로 union-find 단계까지 실제로 도달한다 — 그
# 사실을 먼저 단언(hold==0)한 뒤에 coerced 를 본다.
case_AC7b_unknown_same_as_target_coerced() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-r1.txt" "$FX/codex-failed.yaml" "--skip")"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-r1.txt" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep.json"
  local rt; rt="$(mktemp -t rt-XXXXXX.txt)"
  printf '```docreview-recritic\nverdicts:\n  - f: "f1"\n    verdict: confirm\n    same_as: ["zzzz9999#r1.1"]\nadded: []\n```\n' > "$rt"
  py docreview_route.py finalize --state-dir "$d" --recritic "$rt" --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_held"]')" "0" "AC7b: f1 은 known item — hold 를 안 타고 union-find 단계에 실제로 도달한다(중간 사실)"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_coerced"]')" "1" "AC7b: 존재하지 않는 same_as 타겟은 조용히 스킵되지 않고 coerced 로 계수된다(union-find y-not-in-parent, AC27 의 쌍둥이)"
  rm -rf "$d" "$rt"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$t" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep.json"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$t" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep.json"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$t" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep.json"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$t" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep.json"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$t" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/diff2.json" --doc "$FX/design-sample-r2.md" > "$d/fin.json"
  assert_eq "$(fsum "$d" '후속 손질' '["disposition"]')" "fix" "T11: 유효 permit 이 있는 보호 앵커는 리뷰어 처분 그대로"
  assert_eq "$(jget "$d/fin.json" 'all(x["id"].split("#")[1].startswith("r2.") for x in d["findings"])')" "True" "T11: 라운드 2 에서 생성된 id 는 전부 r2. 로 시작 — 라운드 «번호» 가 실제로 박힌다(r 존재가 아니라 값)"
  rm -rf "$d" "$t"
}
# `_permit_covers` 는 permit 의 「이번 라운드」것인지를 본다(`int(p["round"]) == n`). permit 은
# 소모(`consumed`)돼도 삭제되지 않으므로, 그 permit 의 라운드가 지나면(다음 라운드가 또
# 지나도록 재결정이 없으면) 낡은 permit 이 남는다 — 그 라운드 검사가 없으면 낡은 permit 이
# 영원히 보호 승격을 막는 구멍이 된다(Task 6, AC24). 코드는 그대로다 — 이미 라운드를
# 본다; 이 케이스는 그 사실에 이빨을 준다.
case_AC24_stale_permit_does_not_cover() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  local gid; gid="$(fsum "$d" 'Non-goals' '["id"]')"
  py docreview_state.py decide --state-dir "$d" --id "$gid" --choice adopt --quote '채택' >/dev/null
  local anc; anc="$(st_yaml "$d" 'list(st["permits"].values())[0]["apply_anchors"][0]')"
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null     # 라운드 2 — permit 소모
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null     # 라운드 3 — permit 은 라운드 2 의 것, 이제 낡았다
  assert_eq "$(st_yaml "$d" 'st["round"], [p["round"] for p in st["permits"].values()]')" "(3, [2])" "AC24: 라운드 3 인데 permit 은 라운드 2 의 것(permits 는 삭제되지 않는다)"
  local t; t="$(mktemp -t cr-XXXXXX.txt)"
  printf '```docreview-layer1\n[]\n```\n```docreview-layer2\n- ref: c1\n  category: ambiguity\n  anchor: "%s"\n  disposition: fix\n  summary: "낡은 permit 앵커의 새 fix"\n```\n' "$anc" > "$t"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$t" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep3.json"
  # fsum 은 "$1/fin.json" 을 고정으로 읽는다(다른 접미사를 안 받는다) — round1 산출물을
  # 그대로 덮어써야 이 assert 가 실제 round3 결과를 본다(브리프 원안의 fin3.json 은 fsum
  # 이 절대 안 읽는 죽은 파일이라 아래 두 assert 가 IndexError 로 죽는다, 실측 확인).
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/diff3.json" --doc "$FX/design-sample-r2.md" > "$d/fin.json"
  assert_eq "$(fsum "$d" '낡은 permit' '["disposition"]')" "decide" "AC24: 라운드가 지난 permit 은 보호 승격을 막지 못한다"
  # .get(...) — 라운드 경계가 없으면 승격 자체가 안 먹어 "promotion" 키가 통째로 없다.
  # ["promotion"] 이면 그 변이 사본에서 KeyError → traceback → run_case 가 caught 대신
  # unmeasurable 로 오판정한다(Task 5 의 같은 함정, cases.sh AC23 참조).
  assert_eq "$(fsum "$d" '낡은 permit' '.get("promotion")')" "protected" "AC24: 승격 사유는 protected"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$t" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$t" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$t" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/diff2.json" --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" 'len(d["revived"]), d["revived"][0]["by"], "그대로" in d["revived"][0]["why"]')" "(1, 'user', True)" "T17: 기각 계보의 부활을 라우터가 원장으로 대조해 사유와 함께 공시"
  assert_eq "$(fsum "$d" '또 두 가지' '["disposition"]')" "decide" "T17: 새 finding 은 지우지 않는다(보호라 decide)"
  rm -rf "$d" "$t"
}
case_T35_frozen_change_auto_decide() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-nolayer2.txt" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-nolayer2.txt" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/diff2.json" --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" '[(x["disposition"], x["kind"], x["supersedes"]==sys.argv[0] if False else x["supersedes"]) for x in d["findings"] if "AC 가 하나뿐" in x["summary"]]')" "[('decide', 'pre', '$fid')]" "T28: check-intent 거부된 fix 는 다음 라운드에 같은 계보의 decide(pre)"
  rm -rf "$d"
}
case_T22_reraise_appears_in_next_round() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  local gid; gid="$(fsum "$d" 'Non-goals' '["id"]')"
  py docreview_state.py decide --state-dir "$d" --id "$gid" --choice adopt --quote '채택' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null        # 변경 없음 → expired
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-nolayer2.txt" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-nolayer1.txt" --codex "$(codex_now "$d" "$FX/codex-r1.yaml")" > "$d/prep.json" 2>/dev/null; local rc=$?
  assert_eq "$rc $(jget "$d/prep.json" 'd["degrade"]["critic_dead"]')" "4 True" "T41: 층 1 블록 없음 → rc 4 + critic_dead"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-broken.txt" --codex "$(codex_now "$d" "$FX/codex-r1.yaml")" > "$d/prep.json" 2>/dev/null; rc=$?
  assert_eq "$rc" "4" "T41: 층 1 블록 YAML 파손 → rc 4"
  # critic 사망 라운드를 finalize 까지 태운다 — `reviewing-spec/SKILL.md` 의 mark-reviewed 배제가
  # 읽는 신호는 `fin.json` 의 `blocks` 다. rc 4 · `critic_dead` 만 재면 그 다리(주 판정자로 기록 →
  # `blocks`)가 끊겨도 통과한다(doc-critic 을 보조로 기록하는 변이가 락 15개 전부에서 GREEN 이었다).
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin.json" 2>/dev/null
  assert_eq "$(jget "$d/fin.json" 'd["blocks"], any(a.startswith("입력 실패(주): doc-critic") for a in d["advisory"])')" "(True, True)" \
    "T41: critic 사망 라운드의 finalize → fin.json blocks 참 + 주 판정자 사유(doc-critic)"
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

# ── T46 — 「미검증」 라운드를 엔진이 스스로 안다 (Task 7b, R51) ───────────────────
# 이번 라운드의 판정이 원장에 없는 세 모양 — critic 사망 두 번(5단계가 6~7단계를 건너뛴다) ·
# critic 이 죽은 채 finalize · finalize 실패. 게이트 요약이 사유(`unverified`) · 승인 게이트 라벨
# (`approval_label`) · 완료 기록 신호(`round_reviewed`)를 내고, 렌더 첫 줄이 공시로 시작한다. 진입
# skill 은 이 셋을 읽는다(reviewing-spec 의 mark-reviewed 배제 · reviewing-brief 의 Step B 라벨).
gsum()   { py docreview_state.py gate --state-dir "$1" | jgets "$2"; }            # gsum <dir> <expr over d>
gfirst() { py docreview_state.py gate --state-dir "$1" --render | head -1; }      # 렌더 첫 줄(degrade 공시)
UNV='d["unverified"], d["approval_label"], d["round_reviewed"], d["approval_gate_open"]'
UNV3='d["unverified"], d["approval_label"], d["round_reviewed"]'
critic_dead_twice() {   # critic_dead_twice <state-dir> — 5단계 rc 4 두 번(재dispatch 도 죽었다)
  py docreview_route.py prepare-recritic --state-dir "$1" --critic "$FX/critic-nolayer1.txt" --codex "$(codex_now "$1" "$FX/codex-r1.yaml")" > "$1/prep.json" 2>/dev/null
  py docreview_route.py prepare-recritic --state-dir "$1" --critic "$FX/critic-broken.txt" --codex "$(codex_now "$1" "$FX/codex-r1.yaml")" > "$1/prep.json" 2>/dev/null
}
case_T46_critic_dead_twice_unverified() {
  local d f; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  critic_dead_twice "$d"
  assert_eq "$(gsum "$d" "$UNV")" "('critic_dead', '미검증', False, True)" \
    "T46: critic 사망 두 번(finalize 없음) → unverified critic_dead · 라벨 「미검증」 · 완료 기록 불가 · 승인 게이트 열림"
  f="$(gfirst "$d")"
  assert_not_contains "$f" "degrade 없음" "T46: critic 사망 두 번 라운드의 렌더 첫 줄에 「degrade 없음」이 없다"
  assert_contains "$f" "「미검증」 주 판정자(doc-critic) 사망" "T46: 렌더 첫 줄이 주 판정자 사망 · 「미검증」을 공시한다 (부재 단언의 양의 짝)"
  assert_contains "$(py docreview_state.py gate --state-dir "$d" --render)" "다음: 승인 게이트(「미검증」)" \
    "T46: 렌더의 다음 줄이 승인 게이트를 「미검증」 라벨로 연다"
  rm -rf "$d"
}
case_T46_critic_dead_finalized_unverified() {   # mark-reviewed 배제 둘째 갈래 — 죽은 채 finalize 한 라운드
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-nolayer1.txt" --codex "$(codex_now "$d" "$FX/codex-r1.yaml")" > "$d/prep.json" 2>/dev/null
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin.json" 2>/dev/null
  assert_eq "$(jget "$d/fin.json" 'd["blocks"]')" "True" "T46 전제: critic 이 죽은 채 finalize 한 라운드 — fin.json blocks 참"
  assert_eq "$(gsum "$d" "$UNV")" "('critic_dead', '미검증', False, True)" \
    "T46: critic 이 죽은 채 finalize 한 라운드도 엔진이 「미검증」으로 안다 (unverified critic_dead · 완료 기록 불가)"
  assert_contains "$(gfirst "$d")" "「미검증」 주 판정자(doc-critic) 사망" "T46: 그 라운드의 렌더 첫 줄도 주 판정자 사망을 맨 앞에 싣는다"
  rm -rf "$d"
}
case_T46_finalize_failed_unverified() {   # critic 생존 · finalize rc≠0 — 준비는 남고 fin.json 은 비었다
  local d rc f; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-r1.txt" --codex "$(codex_now "$d" "$FX/codex-r1.yaml")" > "$d/prep.json"
  printf '{' > "$d/broken-diff.json"   # 파손 diff — finalize 가 원장을 쓰기 전에 죽는다
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/broken-diff.json" --doc "$FX/design-sample.md" > "$d/fin.json" 2>/dev/null; rc=$?
  assert_eq "$rc $(wc -c < "$d/fin.json" | tr -d ' ')" "1 0" "T46 전제: finalize 가 rc 1 로 죽고 fin.json 은 비었다"
  assert_eq "$(gsum "$d" "$UNV")" "('finalize_incomplete', '미검증', False, True)" \
    "T46: finalize 실패 → 정상 게이트가 아니다 (unverified finalize_incomplete · 라벨 「미검증」 · 완료 기록 불가)"
  f="$(gfirst "$d")"
  assert_not_contains "$f" "degrade 없음" "T46: finalize 실패 라운드의 렌더 첫 줄에 「degrade 없음」이 없다"
  assert_contains "$f" "「미검증」 라우팅(finalize) 미완" "T46: 렌더 첫 줄이 라우팅 미완 · 「미검증」을 공시한다 (부재 단언의 양의 짝)"
  rm -rf "$d"
}
case_T46_finalize_without_prepare_marks_round() {   # 준비 없는 finalize — 거부를 원장에 남기고, 성공이 치운다
  local d rc; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin.json" 2>"$d/fin.err"; rc=$?
  assert_eq "$rc $(jget "$d/fin.err" 'd["reason"]')" "1 no_pending_recritic" "T46 전제: 준비 없는 finalize 는 rc 1 no_pending_recritic"
  assert_eq "$(st_yaml "$d" 'st["rounds"]["1"].get("finalize_failed")')" "no_pending_recritic" "T46: 그 거부가 이 라운드 자리에 실패 표지로 남는다"
  assert_eq "$(gsum "$d" "$UNV")" "('finalize_incomplete', '미검증', False, True)" "T46: 준비 없이 finalize 가 거부된 라운드의 게이트는 「미검증」이다"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-r1.txt" --codex "$(codex_now "$d" "$FX/codex-r1.yaml")" > "$d/prep.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin.json"; rc=$?
  assert_eq "$rc $(st_yaml "$d" 'st["rounds"]["1"].get("finalize_failed")')" "0 None" "T46: 같은 라운드의 finalize 성공이 실패 표지를 치운다"
  assert_eq "$(gsum "$d" "$UNV3")" "(None, None, True)" "T46: 그 뒤 게이트는 정상이다 (라벨 없음 · 완료 기록 가능)"
  rm -rf "$d"
}
case_T46_stale_pending_refused() {   # 다른 라운드의 준비는 소비하지 않는다 · 번호 없는 준비도
  local d rc; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  critic_dead_twice "$d"                                   # 라운드 1 의 준비(critic 사망)가 남는다
  next_round "$d" "$FX/design-sample.md" >/dev/null        # 라운드 2 — 아직 준비 없음
  assert_eq "$(gsum "$d" 'd["unverified"], d["round_reviewed"]')" "(None, False)" \
    "T46 라운드 스코프: 직전 라운드의 critic 사망 준비는 이번 라운드를 「미검증」으로 만들지 않는다 — 다만 라우팅 전이라 완료 기록 신호도 서지 않는다"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin.json" 2>"$d/fin.err"; rc=$?
  assert_eq "$rc $(jget "$d/fin.err" 'd["reason"]') $(wc -c < "$d/fin.json" | tr -d ' ')" "1 pending_recritic_stale 0" \
    "T46: 라운드 2 의 finalize 는 라운드 1 의 준비를 소비하지 않는다 (rc 1 pending_recritic_stale · fin.json 없음)"
  assert_eq "$(st_yaml "$d" 'st["pending_recritic"]["round"], st["rounds"]["2"].get("route_report"), st["rounds"]["2"].get("finalize_failed")')" \
    "(1, None, 'pending_recritic_stale')" "T46: 거부는 준비를 건드리지 않고 이번 라운드 자리에 표지만 남긴다"
  assert_eq "$(gsum "$d" "$UNV3")" "('finalize_incomplete', '미검증', False)" "T46: 그 라운드의 게이트는 「미검증」이다"
  rm -rf "$d"
  d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-r1.txt" --codex "$(codex_now "$d" "$FX/codex-r1.yaml")" > "$d/prep.json"
  python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import docreview_state as s
st = s.load_state(sys.argv[2]); st["pending_recritic"].pop("round"); s.save_state(sys.argv[2], st)' "$SCRIPTS" "$d"
  assert_eq "$(gsum "$d" "$UNV3")" "('finalize_incomplete', '미검증', False)" "T46: 라운드 번호가 없는 준비는 이번 라운드의 미완 준비로 친다 (닫힌 쪽)"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin.json" 2>"$d/fin.err"; rc=$?
  assert_eq "$rc $(jget "$d/fin.err" 'd["reason"]')" "1 pending_round_unrecorded" "T46: finalize 는 어느 라운드 것인지 모르는 준비를 소비하지 않는다"
  rm -rf "$d"
}
case_T46_unverified_released_next_round() {   # 라운드 스코프 — 다음 라운드가 정상으로 끝나면 표지가 풀린다
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  critic_dead_twice "$d"
  assert_eq "$(gsum "$d" 'd["unverified"]')" "critic_dead" "T46 전제: 라운드 1 은 「미검증」(critic 사망)"
  next_round "$d" "$FX/design-sample.md" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-r1.txt" --codex "$(codex_now "$d" "$FX/codex-r1.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/diff2.json" --doc "$FX/design-sample.md" > "$d/fin2.json"
  assert_eq "$(gsum "$d" "$UNV3")" "(None, None, True)" "T46: 라운드 2 가 정상으로 끝나면 「미검증」이 풀린다 (라벨 없음 · 완료 기록 가능)"
  assert_not_contains "$(gfirst "$d")" "미검증" "T46: 풀린 라운드의 렌더 첫 줄에 「미검증」이 없다"
  # finalize 실패 표지도 같은 스코프다 — 라운드 3 에서 준비 없이 거부된 뒤 라운드 4(추가 승인) 가 정상이면 풀린다.
  next_round "$d" "$FX/design-sample.md" >/dev/null
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > /dev/null 2>&1
  assert_eq "$(gsum "$d" 'd["unverified"]')" "finalize_incomplete" "T46 전제: 라운드 3 은 「미검증」(finalize 거부)"
  next_round "$d" "$FX/design-sample.md" '사용자: 한 라운드 더' >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-r1.txt" --codex "$(codex_now "$d" "$FX/codex-r1.yaml")" > "$d/prep4.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/diff4.json" --doc "$FX/design-sample.md" > "$d/fin4.json"
  assert_eq "$(gsum "$d" "$UNV3")" "(None, None, True)" "T46: 라운드 4 가 정상으로 끝나면 finalize 실패 표지도 풀린다"
  rm -rf "$d"
}
case_T46_normal_and_unrouted_rounds() {   # 양의 짝 둘 — 정상 라운드는 참, 라우팅 없는 라운드는 사유 없이 거짓
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_eq "$(gsum "$d" "$UNV3")" "(None, None, True)" "T46 양의 짝: 정상 라운드(critic 생존 · finalize 성공) → 사유 없음 · 라벨 없음 · 완료 기록 가능"
  assert_not_contains "$(py docreview_state.py gate --state-dir "$d" --render)" "미검증" "T46 양의 짝: 정상 라운드의 렌더에 「미검증」이 없다"
  rm -rf "$d"
  d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_eq "$(gsum "$d" "$UNV3")" "(None, None, False)" \
    "T46: finalize 를 거치지 않은 라운드 — 「미검증」 사유는 없지만 완료 기록 신호는 서지 않는다 (참은 이번 라운드의 finalize 보고서를 요구한다)"
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

# ── check-intent 일반 fix 경로의 앵커 실재 검사 (Task 5, AC23) ─────────────
# classify_anchor 는 앵커를 못 찾으면 `"fix_allowed": "*" in prof["fix_anchors"]` 를 낸다 —
# fix_anchors:["*"] 프로필(generic)에서는 «없는 앵커»가 fix_allowed 로 분류된다. 슬러그
# 오타가 보호 부류 검사를 통째로 건너뛰는 구멍이라 일반 경로에도 found 검사가 필요하다.
case_AC23_general_fix_anchor_unresolved() {
  local d; d="$(r1 "$PROF_QG/generic.md" "$FX/design-sample.md")"
  local f='{"id":"eeee0001#r1.1","lineage":"eeee0001#r1.1","bucket":"eeee0001","origin":"reviewer","layer":2,"category":"placeholder","anchor":"#12-files-to-modifyy","edit_scope":"#12-files-to-modifyy","disposition":"fix","summary":"슬러그 오타","evidence":null,"blocks":[]}'
  seed_findings "$d" "[$f]"
  local out; out="$(_ci 'eeee0001#r1.1' --intent '#12-files-to-modifyy' --state-dir "$d")"; local rc=$?
  assert_eq "$rc" "1" "AC23: 스냅샷에 없는 앵커의 일반 fix 는 거부된다"
  # d.get(...) — 이 검사가 빠지면 이 프로필(와일드카드)에서 나머지 검사가 전부 통과해
  # "reason" 키 자체가 없는 accept json 이 나온다. d["reason"] 이면 mutation 사본에서
  # KeyError → traceback → run_case 가 unmeasurable 로 오판정한다(caught 를 기대하는 셀).
  assert_eq "$(printf '%s' "$out" | jgets 'd.get("reason")')" "anchor_unresolved" "AC23: 사유는 anchor_unresolved — insert_after_unresolved 와 다른 문자열"
  assert_eq "$(st_yaml "$d" 'st["fixes"]["eeee0001#r1.1"]["state"], [e["finding_id"] for e in st["escalated"]]')" "('escalated', ['eeee0001#r1.1'])" "AC23: 거부는 escalate 경로 — 다음 라운드 decide 로 올라간다(단순 거부면 pending 으로 남아 영구히 승인을 막는다)"
  rm -rf "$d"
}

# ── 재상승 예약 누적·dedup·미소비 계수 (Task 2, AC21) ─────────────────────
case_AC21_reraise_accumulates() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null        # 라운드 2 — 변경 없음 → expired + 예약
  assert_eq "$(st_yaml "$d" '[r["finding_id"] for r in st["reraise"]]')" "['aaaa0001#r1.1']" "AC21: 라운드 2 의 만료가 예약을 남긴다"
  # finalize 가 재상승 루프 «전에» 빠져나간다 — prepare-recritic 이 없으므로 no_pending_recritic.
  py docreview_route.py finalize --state-dir "$d" --doc "$FX/design-sample.md" --recritic-skipped >/dev/null 2>&1
  assert_eq "$(st_yaml "$d" '[r["finding_id"] for r in st["reraise"]]')" "['aaaa0001#r1.1']" "AC21: 조기 반환한 finalize 는 예약을 소비하지 않는다"
  next_round "$d" "$FX/design-sample.md" >/dev/null        # 라운드 3 — observe-diff 가 다시 돈다
  assert_eq "$(st_yaml "$d" '[r["finding_id"] for r in st["reraise"]]')" "['aaaa0001#r1.1']" "AC21: 다음 라운드 observe-diff 가 그 예약을 지우지 않는다(누적)"
  rm -rf "$d"
}
# [Task 2 실행 노트] 브리프 원안(next_round 를 세 번 반복)은 dedup 을 실제로 재지 않는다
# (`no_teeth` 실측) — permit 은 decision_id 로 유일하고 한 번 소비되면(`consumed=True`)
# 다시는 처리되지 않으므로, 같은 finding_id 가 «자연 경로»로 reraise 에 두 번 들어올 방법이
# 없다(라운드를 더 돌려도 매번 로컬 reraise 는 비어 있어 dedup 분기 자체가 안 밟힌다).
# dedup 이 실제로 막아야 하는 상황을 만들려면 같은 finding_id 에 대한 permit 이 «두 번»
# 생겨야 한다.
# [Task 4 fix round 1 — 정정] R1 이 여기 뒀던 원안(`seed_findings` 로 같은 id 를
# disposition=decide 로 다시 심어 `record_findings` 가 그 decides 레코드를 "open" 으로
# 되돌리는 것을 이용해 두 번째로 `cmd_decide` 채택)은 Task 4 에서 실측 `no_teeth` 로
# 무너졌다 — 재심기 자체는 `cmd_decide` 를 안 거치지만, 바로 다음 줄의 실제 `cmd_decide`
# 채택이 Task 4 의 재결정 탈출구를 그대로 탄다: 그 탈출구는 **모든** `cmd_decide` 호출에서
# 새 permit 을 여는 것과 대상 id 의 미소비 예약을 폐기하는 것을 **같은 호출 안에서 함께**
# 한다(§6.4 상호배제의 절반) — 원안은 스스로 첫 예약을 지워버려 dedup 이 막아야 할
# 「같은 id 의 예약 둘」 조합을 만들지
# 못했다(실측: 변이 있든 없든 결과가 똑같이 `(1, 1)`). `cmd_decide` 를 완전히 우회해
# 두 번째 permit 을 여는 픽스처(`st_open_permit.py`)로 바꾼다 — 첫 예약을 그대로 둔 채로.
case_AC21_reraise_dedup() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null        # 라운드 2 — 변경 없음 → expired + 예약 1건
  python3 "$FX/st_open_permit.py" "$d/docreview-state.md" 'aaaa0001#r1.1' '#12-files-to-modify'   # cmd_decide 우회 — 예약을 안 건드리고 permit 하나 더
  next_round "$d" "$FX/design-sample.md" >/dev/null        # 라운드 3 — 같은 finding_id 가 다시 만료
  assert_eq "$(st_yaml "$d" 'len(st["reraise"]), len({r["finding_id"] for r in st["reraise"]})')" "(1, 1)" "AC21: 같은 finding_id 의 예약이 두 번째 만료에도 하나로 유지된다(dedup)"
  rm -rf "$d"
}
case_AC21_unconsumed_counted() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  python3 "$FX/st_set_reraise.py" "$d/docreview-state.md" 'zzzz9999#r1.1'
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-nolayer2.txt" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" 'd["reraise_unconsumed"]')" "1" "AC21: 대상 finding 이 없는 예약은 버려지지 않고 계수된다"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["counts"]["reraise_unconsumed"]')" "1" "AC21: 그 계수가 게이트에 실린다"
  rm -rf "$d"
}

# ── Task 8a — 분해 전 커버리지 공백을 메운다 ────────────────────────────────
# 매트릭스 열둘 중 어느 것도 escalated 이월(round != n-1 인 예약은 이번 라운드에
# 소비되지 않고 다음으로 넘어간다, cmd_finalize 의 `keep_esc` 절)을 겨누지 않았다.
# 자연 경로로 그 분기를 실제로 밟으려면 finalize 를 «건너뛴» 라운드가 있어야 한다
# (reraise 의 AC21_reraise_accumulates 와 같은 종류의 조기-반환 상황) — cases.sh 에
# 그런 케이스가 없어 여기서 만든다. 같은 finalize 호출 안에서 이월(불일치, round=1)과
# 소비(일치, round=2)를 동시에 겨눠 둘을 한 번에 가른다.
# [Task 2 — 락 뒤집기] 이 케이스는 원래 `case_escalated_round_mismatch_carries_over`
# 였고, `_auto_decides` 의 escalated 갈래가 `!= n - 1`(정확히 직전 라운드의 예약만
# 소비)이던 시절에 둘째 단언으로 *"소비되지 않은 라운드 1 예약은 버려지지 않고
# 다음으로 이월된다"* 를 **의도된 동작**으로 못 박았다. Task 2 가 그 규칙을
# `>= n`(이번 라운드보다 앞선 예약 전부를 소비)으로 뒤집는다 — `finalize` 가 이
# 루프 전에 조기 반환한 라운드가 하나라도 끼면 라운드 번호가 영원히 어긋나 그
# 예약이 소비도 계수도 안 되는 결함이 있었기 때문이다(형제 reraise, AC21 이 같은
# 결함을 먼저 닫았다). 그래서 둘째 단언의 뜻도 뒤집힌다 — 라운드 1 예약은 이제
# «이월»이 아니라 «이번 라운드에 소비»된다. 케이스 이름도 `case_escalated_accumulates`
# 로 바꾼다. **[F-4 재리뷰 정정]** 원 시나리오의 핵심 골격(라운드 1 escalate → 라운드
# 2 finalize 건너뜀 → 라운드 2 escalate → 라운드 3 finalize)은 그대로 두지만, 아래
# 실행 노트(§ 실측)가 밝히듯 그 골격만으로는 뒤집을 대상(「아직 자기 차례가 아닌
# 예약은 보존된다」)이 한 번도 안 밟혀 — 시나리오에 예약 하나를 **더했다**(라운드
# 3 에 다시 escalate). 바뀐 것은 기대값만이 아니다 — 시나리오도 최소한으로 늘었다.
#
# BEFORE(뒤집기 전 — GREEN 이었던 사실, report 에 그대로 인용):
#   assert_eq ... "['$fid2']" "escalated 이월: round 불일치(라운드 1 예약)는 이번
#     라운드(n-1=2)에 소비되지 않고, 일치하는 것(라운드 2 예약)만 decide 로 올라온다"
#   assert_eq "$(st_yaml "$d" 'sorted(e["finding_id"] for e in st["escalated"])')"
#     "['$fid1']" "escalated 이월: 소비되지 않은 라운드 1 예약은 버려지지 않고 다음으로
#     이월된다(round 필드 그대로)"
# AFTER(뒤집은 뒤 — 아래 본문): fid1·fid2 둘 다 소비되어 decide 로 올라온다.
# [Task 2 실행 노트 — 회귀 실측] `>= n` 아래에서는 원 시나리오(라운드 1·2 에 escalate,
# 라운드 3 에 finalize)만으로는 "아직 자기 차례가 아닌" 예약을 하나도 안 만든다 —
# n=3 에 도달한 시점엔 round=1·round=2 예약 «둘 다» 이미 과거라 즉시 소비되고,
# `keep_esc.append(e)` 가 한 번도 안 불린다(실측: ㉙ `escalated_mismatch_dropped`
# 셀이 no_teeth 로 떨어짐 — `keep_esc.append(e)` 를 지워도 이 케이스가 안 흔들렸다).
# 그래서 **같은 라운드에 escalate 한 예약**(round == n, 아직 자기 차례가 아님)을
# 셋째로 더한다 — fid1 을 라운드 3(이번 finalize 와 같은 라운드)에 다시 escalate
# 하면 그 예약은 이번 라운드 판정에서 `round(3) >= n(3)` 이라 보류된다(dedup 과는
# 안 섞인다 — 라운드 검사가 dedup 검사보다 앞서 걸러낸다, `_auto_decides` 참조).
case_escalated_accumulates() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  local fid1 fid2
  fid1="$(fsum "$d" 'AC 가 하나뿐' '["id"]')"        # #1-context, category ambiguity, disposition fix
  fid2="$(fsum "$d" '부품 경계' '["id"]')"            # #handoff-context, category isolation, disposition fix
  py docreview_state.py fix --state-dir "$d" --id "$fid1" --event escalate --reason 'check-intent 거부(라운드 1)' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null   # 라운드 2 — finalize 를 부르지 않고 건너뛴다
  py docreview_state.py fix --state-dir "$d" --id "$fid2" --event escalate --reason 'check-intent 거부(라운드 2)' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null   # 라운드 3
  py docreview_state.py fix --state-dir "$d" --id "$fid1" --event escalate --reason 'check-intent 거부(라운드 3, 아직 자기 차례가 아님)' >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-nolayer2.txt" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep3.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/diff3.json" --doc "$FX/design-sample.md" > "$d/fin.json"
  # n=3. 새 계약: 「직전 라운드」가 아니라 「이번 라운드보다 앞선」 예약을 전부 소비한다
  # — fid1(round=1)·fid2(round=2) 둘 다 이번 finalize 에서 decide 로 올라온다.
  # `supersedes in (fid1,fid2)` 로 걸러 다른 자동 항목(같은 라운드 critic 이 우연히
  # 만드는 자동 연결 등)과 섞이지 않게 한다. 정렬은 id 문자열 순 — fid1·fid2 의 실제
  # 정렬 순서는 실행 시점 값에 달렸으므로 기대값도 같은 sorted() 규칙으로 낸다.
  local expected; expected="$(python3 -c 'import sys; print(sorted(sys.argv[1:]))' "$fid1" "$fid2")"
  assert_eq "$(jget "$d/fin.json" 'sorted(x["supersedes"] for x in d["findings"] if x.get("supersedes") in ("'"$fid1"'", "'"$fid2"'"))')" \
    "$expected" "escalated 누적: 라운드가 어긋난 예약(라운드 1)도 버려지지 않고 이번 라운드에 소비된다"
  assert_eq "$(st_yaml "$d" '[(e["finding_id"], e["round"]) for e in st["escalated"]]')" "[('$fid1', 3)]" \
    "escalated 누적: 이번 라운드(3)에 새로 생긴 예약(아직 자기 차례가 아님)은 소비되지 않고 그대로 남는다"
  rm -rf "$d"
}

# escalated dedup — 같은 finding_id 가 두 번 예약돼도 후속은 라운드당 하나(재상승
# dedup, AC21 과 같은 규칙), 그러나 **같은 라운드의 다른 finding 은 삼키지 않는다**
# (F-1 재리뷰 — dedup 키는 `finding_id` 다, `round` 가 아니다). **도달성 확인(Task 2
# 브리프 요구, `case_AC21_reraise_dedup` 이 한 번 no_teeth 로 판정됐던 자리와 같은
# 종류)** — 유일한 실제 진입점 `docreview_anchor.py cmd_check_intent` 의 `escalate()`
# 클로저는 그 앞의 가드(`if not fx or fx["state"] not in ("pending", "intent_passed"):
# return _reject(...)`)를 반드시 지나야 한다. **[F-5 재리뷰 정정]** "escalate 가 한
# 번 일어나면 다시는 그 가드를 못 지난다"는 예전 서술은 **틀렸다** — `cmd_fix` 의
# `intent-pass` 분기(`docreview_state.py` 의 `cmd_fix` 안, "intent-pass" 갈래)는 현재 상태를 검사하지 않고
# `fx["state"] = "intent_passed"` 로 무조건 대입하고, `intent_passed` 는 그 가드의
# 허용 집합 안이다. 즉 `escalate → intent-pass → escalate` 로 **check-intent 경유의
# 자연 재예약도 가능하다** — 도달성은 원래 서술보다 더 높다. 그와 별개로 이 파일의
# 다른 모든 escalated 케이스가 이미 쓰는 저수준 CLI(`docreview_state.py fix --event
# escalate`)는 애초에 그 가드를 갖지 않는다(현재 상태를 검사하지 않고 매번 그대로
# append 한다) — 재상승 쪽 dedup(`case_AC21_reraise_dedup`)이 `cmd_decide` 를 완전히
# 우회하는 전용 픽스처(`st_open_permit.py`)로 도달성을 만든 것과 같은 등급이고,
# 이쪽은 전용 픽스처조차 필요 없다. 결론은 그대로다(케이스를 쓴다) — 근거만 고쳤다.
case_escalated_dedup() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  local fid fid_other
  fid="$(fsum "$d" 'AC 가 하나뿐' '["id"]')"
  fid_other="$(fsum "$d" '부품 경계' '["id"]')"        # F-1 — 같은 라운드의 다른 finding
  py docreview_state.py fix --state-dir "$d" --id "$fid" --event escalate --reason 'check-intent 거부(1차)' >/dev/null
  py docreview_state.py fix --state-dir "$d" --id "$fid" --event escalate --reason 'check-intent 거부(2차, 같은 finding_id 재예약)' >/dev/null
  py docreview_state.py fix --state-dir "$d" --id "$fid_other" --event escalate --reason 'check-intent 거부(같은 라운드, 다른 finding)' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null   # 라운드 2 — 세 예약(round=1) 모두 이번 finalize 대상
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-nolayer2.txt" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin.json"
  # F-1 — dedup 은 finding_id 로 키잉한다. round 로 키잉하면(리뷰의 M8 변이:
  # `esc_seen.add(e["finding_id"])` → `esc_seen.add(e["round"])`) 세 예약이 모두
  # round=1 이라 fid_other 가 fid 에 "같은 라운드"라는 이유만으로 삼켜져 이 단언이
  # 후속 하나(fid_other 없음)만 보고 RED 가 된다.
  local expected; expected="$(python3 -c 'import sys; print(sorted(sys.argv[1:]))' "$fid" "$fid_other")"
  assert_eq "$(jget "$d/fin.json" 'sorted(x["supersedes"] for x in d["findings"] if x.get("supersedes") in ("'"$fid"'", "'"$fid_other"'"))')" \
    "$expected" "escalated dedup: 같은 라운드의 다른 finding 은 삼켜지지 않고 각자 후속을 낸다(키는 finding_id — round 가 아니다)"
  assert_eq "$(jget "$d/fin.json" 'len([x for x in d["findings"] if x.get("supersedes")=="'"$fid"'"])')" "1" "escalated dedup: 같은 finding_id 가 두 번 예약돼도 후속은 라운드당 하나"
  # Ruling 22 — 사유 승자를 못 박는다. `st["escalated"]` 는 append-only 라 리스트
  # 순서 = escalate 된 순서다. 코드가 esc_seen 을 그 순서대로 채우므로 «먼저» 온
  # 사유(1차)가 남는다 — 최신(2차)이 아니다. 행동은 안 바꾼다, 드러내기만 한다.
  assert_eq "$(jget "$d/fin.json" 'next(x["evidence"] for x in d["findings"] if x.get("supersedes")=="'"$fid"'")')" \
    "check-intent 거부(1차)" "escalated dedup: 중복 예약 중 먼저 온 사유가 남는다(최신이 아니다, Ruling 22)"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_absorbed"]')" "1" "escalated dedup: 흡수된 중복 하나가 원장에 계수된다(면제가 아니다, F-2/Ruling 21)"
  assert_eq "$(st_yaml "$d" 'st["escalated"]')" "[]" "escalated dedup: 예약 모두 소비되고(중복은 흡수) 목록이 빈다"
  rm -rf "$d"
}

# escalated 미소비 계수 — 대상 finding 이 없는 예약은 버리지 않고 센다(재상승,
# AC21③ 과 같은 규칙). `st_set_reraise.py` 와 같은 종류의 상태 강제 픽스처
# (`st_set_escalated.py`)로 대상 finding_id 가 st["findings"] 에 없는 예약을 직접
# 심는다 — round 는 심을 시점의 현재 라운드를 그대로 쓰므로, next_round 로 한
# 라운드 넘겨야 그 예약이 "이번 finalize 의 대상"(round < n)이 된다.
case_escalated_unconsumed_counted() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  python3 "$FX/st_set_escalated.py" "$d/docreview-state.md" 'zzzz9999#r1.1'
  next_round "$d" "$FX/design-sample.md" >/dev/null   # 라운드 2 — round=1 예약이 이번 finalize 대상
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-nolayer2.txt" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin.json"
  # F-7 재리뷰 — 매트릭스 헤더의 요구대로 `.get()` 을 쓴다(값이 사라질 수 있는 변이를
  # 겨눌 때 엄격 `d["key"]` 인덱싱은 unmeasurable 로 떨어진다). 기대값이 리터럴 "1"
  # 이라 이 완화는 단언을 약하게 하지 않는다 — 키가 없으면 `.get()` 은 None 을 내고
  # `None != "1"` 은 여전히 RED 다.
  assert_eq "$(jget "$d/fin.json" 'd.get("escalated_unconsumed")')" "1" "escalated: 대상 finding 이 없는 예약은 버려지지 않고 계수된다"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["counts"].get("escalated_unconsumed")')" "1" "escalated: 그 계수가 게이트에 실린다"
  # [Task 3 실행 노트 — Ruling 24] Task 2 가 render_gate 의 계수 줄에 「미소비 상향 예약
  # %d」를 더했는데(escalated_unconsumed), 그 줄을 게이트 **렌더 본문**에서 재는 락이
  # 없었다(위 두 단언은 JSON 의 escalated_unconsumed 만 본다). 이 카운터는 GATE_ROWS
  # 행이 아니다(어떤 상태 하나가 아니라 route 리포트의 집계값이라 행 모델에 안 맞는다)
  # — Task 3 의 새 가시성 락(test_docreview_gate_visibility.sh)이 행 기반이라 이 줄을
  # 자연스럽게 흡수하지 못한다. 대신 그 값을 이미 만들어 둔 이 케이스에 렌더 단언
  # 하나를 더해 갭을 닫는다.
  assert_grep "$(py docreview_state.py gate --state-dir "$d" --render)" '미소비 상향 예약 1' \
    "escalated: 그 계수가 게이트 렌더 본문에도 보인다(Ruling 24 — Task 2 가 늘린 줄의 유일한 렌더 커버리지)"
  rm -rf "$d"
}

# F-3 재리뷰(Ruling 20) — 누적(`>= n`)이 escalated 예약의 소비 창을 1 라운드에서
# 무한대로 넓혔다. `_auto_decides` 의 옛 코드는 `prev.get(finding_id)`(finding 이
# 아직 존재하는가)만 보고 그 fix 의 «지금» 상태는 안 봤다 — 그래서 사용자가 escalate
# 된 fix 를 나중 라운드에 `drop`(cmd_fix event=drop, 상태 검사 없이 무조건 대입)해도
# 옛 예약이 여전히 소비 대상으로 남아 몇 라운드가 지나든 반드시 부활했다(리뷰 실측).
# 형제 재상승 갈래의 `if not d0 or d0.get("state") != "expired": continue` 와 같은
# 모양으로 「이 fix 가 지금도 escalated 상태인가」를 검사해 막는다.
case_escalated_dropped_fix_not_resurrected() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  local fid; fid="$(fsum "$d" 'AC 가 하나뿐' '["id"]')"
  py docreview_state.py fix --state-dir "$d" --id "$fid" --event escalate --reason 'check-intent 거부(라운드 1)' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null   # 라운드 2
  py docreview_state.py fix --state-dir "$d" --id "$fid" --event drop --reason '사용자가 라운드 2 에 drop' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null   # 라운드 3 — 옛 예약(round=1)이 이번 finalize 대상
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-nolayer2.txt" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep3.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" 'len([x for x in d["findings"] if x.get("supersedes")=="'"$fid"'"])')" "0" \
    "escalated: drop 된 fix 의 잔존 예약은 decide 로 부활하지 않는다(F-3)"
  assert_eq "$(st_yaml "$d" 'st["escalated"]')" "[]" "escalated: drop 된 fix 의 잔존 예약도 소비되고(부활 없이) 목록이 빈다"
  rm -rf "$d"
}

# 다섯째 불변식 — 재상승 후속은 `items` 에 안 들어가 same_as 흡수 · 재비판 reject ·
# 처분 강제를 지나지 않는다(설계 §6.4, cmd_finalize 의 「사후·이월 auto decide」 절이
# `items` 를 다 처리한 «뒤»에 `final` 에 직접 append 한다). 재비판이 그 계보(원본 id)를
# 직접 same_as/reject 로 겨눠도 — `items` 의 키는 항상 "f숫자"/"a숫자" 뿐이라 원본 id 는
# 애초에 존재하지 않는 키다 — 둘 다 안전하게 무시되지만 **경로는 다르다**(실측):
# `f: <원본id>` reject 시도는 `items.get(f)` 가 None 이라 `unknown f → L.hold()` 로
# 걸린다. `f: "f1"` + `same_as: [<원본id>]` 시도는 f1 자체는 실재 항목이라 hold 를
# 안 타고, union-find 의 `if x in parent and y in parent:` 가드에서 `y`(원본id)가
# `parent` 에 없어 병합만 스킵된다 — 이 갈래는 Task 7b 전까지 원장 어디에도 기록되지
# 않았다(CLAUDE.md 「판정기가 항목을 버리면 센다」에 대한 미해결 공백이었다, Task 7 이
# 고친 어휘 밖 verdict 와 같은 종류). Task 7b 가 이 갈래를 `L.coerced("same_as", …)`
# 로 계수하도록 고쳤다 — 전용 케이스는 `case_AC7b_unknown_same_as_target_coerced`.
# 이 케이스의 목적은 여전히 다른 불변식(재상승 후속이 `items` 를 안 지난다)이라
# 손대지 않았고, 셋째 단언(hold)은 reject 시도만으로 이미 참이다. 어느 경로든
# 후속은 여전히 open decide 로 남아야 한다.
case_reraise_successor_immune_to_recritic() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  local gid; gid="$(fsum "$d" 'Non-goals' '["id"]')"
  py docreview_state.py decide --state-dir "$d" --id "$gid" --choice adopt --quote '채택' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null        # 변경 없음 → expired + 재상승 예약
  local t; t="$(mktemp -t cr-XXXXXX.txt)"
  printf '```docreview-layer1\n[]\n```\n```docreview-layer2\n- ref: c1\n  category: ambiguity\n  anchor: "#2-goals"\n  disposition: fix\n  summary: "재상승과 무관한 동행 finding"\n```\n' > "$t"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$t" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  local rt; rt="$(mktemp -t rt-XXXXXX.txt)"
  printf '```docreview-recritic\nverdicts:\n  - f: "%s"\n    verdict: reject\n    evidence: "적대적: 재상승 계보(원본 id)를 직접 기각 시도"\n    same_as: ["%s"]\n  - f: "f1"\n    verdict: confirm\n    same_as: ["%s"]\nadded: []\n```\n' "$gid" "$gid" "$gid" > "$rt"
  py docreview_route.py finalize --state-dir "$d" --recritic "$rt" --diff "$d/diff2.json" --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" 'sorted(x["disposition"] for x in d["findings"] if x.get("supersedes")=="'"$gid"'")')" \
    "['decide']" "재상승 불변식: 원본 계보를 직접 겨눈 reject/same_as 뒤에도 후속은 decide 로 남는다(items 를 안 지나 안 닿는다)"
  local succid; succid="$(jget "$d/fin.json" 'next((x["id"] for x in d["findings"] if x.get("supersedes")=="'"$gid"'"), "")')"
  local succ_state; if [ -n "$succid" ]; then succ_state="$(st_yaml "$d" 'st["decides"].get("'"$succid"'", {}).get("state")')"; else succ_state="MISSING"; fi
  assert_eq "$succ_state" "open" "재상승 불변식: 후속의 decides 상태는 open 그대로 — 처분 강제·재비판 reject 어느 것도 안 지났다"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_held"] >= 1')" "True" "재상승 불변식: 원본 id 를 직접 겨눈 reject 시도(f: 원본id)는 unknown f 로 안전하게 hold 된다(무시되지, 크래시하지 않는다) — same_as 시도(f1→원본id)는 별도 경로(union-find y-not-in-parent 가드)로 가고 hold 가 아니라 coerced 로 잡힌다(Task 7b, 위 주석 참조) — 이 단언은 hold 쪽만 본다"
  rm -rf "$d" "$t" "$rt"
}

# ── 상태 축의 정본 표 (Task 3) ───────────────────────────────────────────────
# [Task 3 실행 노트 — 「facts I verified myself」①의 픽스처 증명] `cmd_decide` 의
# 「보류」는 한 finding id 로 두 원장에 동시에 쓴다 — `decides[fid].state = "held"`
# 그리고 `asks[fid] = {answered:False, blocks:[], from_decide:True}`(§`cmd_decide`
# hold 분기). 새 `is_open`/`gate_summary` 는 세 원장을 id 로 각각 훑으므로, 이 교차가
# `GATE_ROWS` 의 `held_decide` 행과 `ask_open` 행 둘 다에 동시에 걸릴 수 있는 유일한
# 자리다 — 걸리면 안 된다: `held_decide`(decides, state==held) 는 걸려야 하고
# `ask_open`(asks, blocks 없고 not from_decide) 은 `from_decide` 배제로 걸리지
# 않아야 한다(안 그러면 같은 항목이 두 번 렌더된다). 트레이스가 아니라 픽스처로 확인한다.
case_GR_held_decide_cross_ledger() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice hold --quote '나중에' >/dev/null
  local g; g="$(py docreview_state.py gate --state-dir "$d")"
  assert_eq "$(printf '%s' "$g" | jgets 'd["held_decide"], d["ask_open"], d["approval_ready"]')" \
    "(['aaaa0001#r1.1'], [], True)" "GR: hold 가 심은 ask(from_decide) 는 held_decide 행에만 걸리고 ask_open 행은 배제한다(교차 원장 id 충돌, 이중 렌더 방지)"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" --render | grep -c 'aaaa0001#r1.1')" "1" \
    "GR: held_decide 는 게이트 본문에 한 번만 보인다(설계 §8.2 — 승인 게이트가 남은 ask 로 보인다, 한계(a) 해소)"
  rm -rf "$d"
}

# [Task 3 실행 노트] 설계 §6.4 한계 (c) — escalated 된 fix 는 오늘 `unapplied_fix` 에도
# `render_gate` 가 그리는 어떤 목록에도 없어 비차단·비가시였다. `GATE_ROWS` 의
# `escalated_fix` 행(open=True, blocks=True)이 그 결함을 해소하는지 시나리오
# 단위로 직접 잰다(가시성 락의 코퍼스-도출 단언과는 별도로 — 그쪽은 모든 행에 대해
# 기계적으로 도는 일반 단언이고, 이 케이스는 한계(c) 라는 구체적 결함 하나를 사람이
# 읽는 문맥으로 남긴다).
case_GR_escalated_fix_blocks_approval() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
  py docreview_state.py fix --state-dir "$d" --id 'bbbb0001#r1.1' --event escalate --reason 'check-intent 거부' >/dev/null
  local g; g="$(py docreview_state.py gate --state-dir "$d")"
  assert_eq "$(printf '%s' "$g" | jgets 'd["escalated_fix"], d["approval_ready"]')" \
    "(['bbbb0001#r1.1'], False)" "GR: escalated fix 는 이제 승인을 막는다(설계 §6.4 한계(c) 해소)"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" --render | grep -c 'bbbb0001#r1.1')" "1" \
    "GR: escalated fix 는 게이트 본문에 보인다(한계(c) — 전에는 어떤 목록에도 없었다)"
  rm -rf "$d"
}

# [Fix round 1 — I2/Ruling 27] escalated 된 fix 를 벗어나는 프로덕션 전이는 `cmd_fix`
# 의 `drop`/`intent-pass`/`hold` 뿐이고, 의도된 흐름(escalate → 후속 auto-decide →
# 채택)은 원본 fix 의 `state` 를 안 건드린다 — 리뷰 실측대로 그대로 두면 한 번 escalate
# 된 fix 는 `approval_ready` 를 영구히 False 로 묶는다. `drop` 은 상태 가드가 없어
# (AC23 이 이미 연 탈출구, 이 태스크가 새로 만든 것이 아니다) escalated 에서도 그대로
# 먹힌다 — 렌더가 그 사실을 실제로 알려주는지와, drop 이 실제로 차단을 푸는지를 함께 잰다.
case_GR_escalated_fix_drop_clears_block() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
  py docreview_state.py fix --state-dir "$d" --id 'bbbb0001#r1.1' --event escalate --reason 'check-intent 거부' >/dev/null
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["approval_ready"]')" "False" \
    "GR: escalate 직후엔 승인이 막혀 있다(선결조건)"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" --render | grep -c 'drop 하면 이 차단이 풀린다')" "1" \
    "GR: 렌더가 drop 이 탈출구임을 실제로 알려준다(I2 — unapplied_fix 와 같은 모양으로)"
  py docreview_state.py fix --state-dir "$d" --id 'bbbb0001#r1.1' --event drop --reason '오탐' >/dev/null
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["escalated_fix"], d["approval_ready"]')" "([], True)" \
    "GR: drop 은 escalated 상태에서도 상태 가드 없이 동작해 실제로 차단을 푼다(AC23 탈출구, 새 전이 아니다)"
  rm -rf "$d"
}

# [Fix round 1 — M7/Ruling 30] `st["escalated"]` 는 소비되면 빈다(Task 2, round>=n
# 수명) — `_rg_escalated_fix` 가 그 리스트만 스캔해 사유를 얻던 옛 코드는 소비 뒤
# 하드코딩 기본값("check-intent 거부")으로 조용히 대체돼, 라운드 1 의 진짜 사유
# (예: anchor_protected)가 라운드 2 부터 거짓 일반화됐다(리뷰 실측). `escalate_reason`
# 을 fx 레코드 자신에 남기면(cmd_fix·docreview_anchor.escalate 둘 다) 원장 소비와
# 무관하게 살아남는지를 실제 finalize 경로로 확인한다.
case_GR_escalated_fix_reason_persists() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  local fid; fid="$(fsum "$d" 'AC 가 하나뿐' '["id"]')"
  py docreview_state.py fix --state-dir "$d" --id "$fid" --event escalate --reason 'anchor_protected' >/dev/null
  assert_eq "$(py docreview_state.py gate --state-dir "$d" --render | grep -c '사유: anchor_protected')" "1" \
    "GR: 라운드 1 렌더에 진짜 사유가 실린다(선결조건)"
  next_round "$d" "$FX/design-sample.md" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$FX/critic-nolayer2.txt" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --diff "$d/diff2.json" --doc "$FX/design-sample.md" > "$d/fin2.json"
  assert_eq "$(st_yaml "$d" 'st["escalated"]')" "[]" "GR: finalize 뒤 예약은 소비돼 빈다(원장 쪽 선결조건, M7 이 겨눈 자리)"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" --render | grep -c '사유: anchor_protected')" "1" \
    "GR: 라운드 2 렌더에도 같은 진짜 사유가 남는다(M7 — fx 레코드의 escalate_reason 이 원장 소비와 무관)"
  rm -rf "$d"
}

# ── 상태 디렉토리의 문서 정체 — init 거부 · state-dir-for ──────────────────────
# 한 디렉토리의 원장은 한 문서의 것이다. 다른 문서로 init 하면 그 문서가 첫 문서의
# 라운드·재리뷰 상한·finding·permit·스냅샷을 물려받는다. 판정은 stdout·stderr 파일을
# grep 으로 읽는다 — 거부가 사라지는 변이에서 빈 stderr 를 json 으로 읽으면 traceback 이
# 나고, 그러면 매트릭스가 규칙 위반을 「측정 불가」로 판정한다.
case_init_other_doc_refused() {
  local d rc; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  cp "$d/docreview-state.md" "$d/before.md"
  py docreview_state.py init --state-dir "$d" --doc "$FX/brief-sample.md" --profile "$PROF_SD/design-doc.md" >"$d/out" 2>"$d/err"; rc=$?
  assert_eq "$rc" "1" "문서 정체: 다른 문서의 원장이 있는 디렉토리에 init 하면 rc 1"
  assert_file_grep "$d/err" '"reason": "state_doc_mismatch"' "문서 정체: 사유는 state_doc_mismatch"
  assert_file_grep "$d/err" '"state_doc": "[^"]*/design-sample\.md"' "문서 정체: 상세에 기존 원장의 문서가 실린다"
  assert_file_grep "$d/err" '"requested_doc": "[^"]*/brief-sample\.md"' "문서 정체: 상세에 요청한 문서가 실린다"
  assert_eq "$(cat "$d/out")" "" "문서 정체: 거부는 성공 JSON 을 내지 않는다"
  if cmp -s "$d/before.md" "$d/docreview-state.md"; then
    ok "문서 정체: 거부가 원장을 건드리지 않는다 (바이트 동일, 라운드 1 그대로)"
  else
    no "문서 정체: 거부했는데 원장이 바뀌었다"
  fi
  rm -rf "$d"
}
case_init_other_profile_refused() {
  local d rc; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  cp "$d/docreview-state.md" "$d/before.md"
  py docreview_state.py init --state-dir "$d" --doc "$FX/design-sample.md" --profile "$PROF_SD/brief.md" >"$d/out" 2>"$d/err"; rc=$?
  assert_eq "$rc" "1" "프로필 정체: 다른 프로필로 같은 문서를 init 하면 rc 1"
  assert_file_grep "$d/err" '"reason": "state_profile_mismatch"' "프로필 정체: 사유는 state_profile_mismatch"
  assert_file_grep "$d/err" '"state_profile": "[^"]*/design-doc\.md"' "프로필 정체: 상세에 기존 프로필이 실린다"
  assert_file_grep "$d/err" '"requested_profile": "[^"]*/brief\.md"' "프로필 정체: 상세에 요청한 프로필이 실린다"
  if cmp -s "$d/before.md" "$d/docreview-state.md"; then
    ok "프로필 정체: 거부가 원장을 건드리지 않는다"
  else
    no "프로필 정체: 거부했는데 원장이 바뀌었다"
  fi
  rm -rf "$d"
}
# 위 두 거부의 양의 짝 — 같은 문서·같은 프로필은 표기가 달라도 멱등이다.
case_init_same_doc_idempotent() {
  local d rc; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  cp "$d/docreview-state.md" "$d/before.md"
  ln -s "$FX/design-sample.md" "$d/link.md"
  py docreview_state.py init --state-dir "$d" --doc "$FX/design-sample.md" --profile "$PROF_SD/design-doc.md" >"$d/o1" 2>&1; rc=$?
  assert_eq "$rc" "0" "멱등: 같은 문서로 다시 init 하면 rc 0"
  assert_file_grep "$d/o1" '"created": false, "round": 1' "멱등: created false · 원장의 라운드 1 이 그대로 보인다"
  py docreview_state.py init --state-dir "$d" --doc "$d/link.md" --profile "$PROF_SD/design-doc.md" >"$d/o2" 2>&1; rc=$?
  assert_eq "$rc" "0" "멱등(정규화): 같은 문서를 가리키는 심볼릭 링크로 init 해도 rc 0"
  assert_file_grep "$d/o2" '"created": false' "멱등(정규화): 심볼릭 링크 표기도 같은 문서로 읽는다"
  py docreview_state.py init --state-dir "$d" --doc "$FX/./design-sample.md" --profile "$PROF_SD/../docreview-profiles/design-doc.md" >"$d/o3" 2>&1; rc=$?
  assert_eq "$rc" "0" "멱등(정규화): '/./' 문서 표기와 '..' 프로필 표기로 init 해도 rc 0"
  if cmp -s "$d/before.md" "$d/docreview-state.md"; then
    ok "멱등: 재 init 셋이 원장을 건드리지 않는다"
  else
    no "멱등: 재 init 이 원장을 바꿨다"
  fi
  rm -rf "$d"
}
# 빈 --state-dir 는 `Path("")` = cwd 다 — cwd 에 원장이 생기면 안 된다.
case_init_empty_state_dir_refused() {
  local w o rc; w="$(mktemp -d -t docreview-XXXXXX)"; o="$(mktemp -d -t docreview-XXXXXX)"
  ( cd "$w" && py docreview_state.py init --state-dir "" --doc "$FX/design-sample.md" --profile "$PROF_SD/design-doc.md" ) >"$o/out" 2>"$o/err"; rc=$?
  assert_eq "$rc" "1" "빈 state-dir: init 이 rc 1 로 거부한다"
  assert_file_grep "$o/err" '"reason": "state_dir_missing"' "빈 state-dir: 사유는 state_dir_missing"
  if [ -e "$w/docreview-state.md" ]; then
    no "빈 state-dir: cwd 에 원장이 생겼다"
  else
    ok "빈 state-dir: cwd 에 원장이 생기지 않는다"
  fi
  rm -rf "$w" "$o"
}
# 문서별 디렉토리 — 같은 문서는 같은 자리, 다른 문서는 다른 자리. 두 번째 문서는 첫 문서와
# **파일 이름이 같게** 둔다: 이름표(stem)만으로 갈리면 도출에서 문서 경로가 빠져도 이 셀이
# 통과한다. 유일성은 경로의 정체가 져야 한다.
case_state_dir_for_per_doc() {
  local w a1 a2 a3 b rc; w="$(mktemp -d -t docreview-XXXXXX)"
  mkdir -p "$w/other"; cp "$FX/design-sample.md" "$w/other/design-sample.md"
  ln -s "$FX/design-sample.md" "$w/link.md"
  a1="$(py docreview_state.py state-dir-for --root "$w/root" --session sess0001 --doc "$FX/design-sample.md")"
  a2="$(py docreview_state.py state-dir-for --root "$w/root" --session sess0001 --doc "$FX/design-sample.md")"
  a3="$(py docreview_state.py state-dir-for --root "$w/root" --session sess0001 --doc "$w/link.md")"
  b="$(py docreview_state.py state-dir-for --root "$w/root" --session sess0001 --doc "$w/other/design-sample.md")"
  assert_eq "${a1%/*}" "$w/root/sess0001/docreview" "문서별 자리: <root>/<session>/docreview/ 아래다"
  assert_grep "${a1##*/}" '^design-sample-[0-9a-f]{16}$' "문서별 자리: 키는 <stem>-<해시 16자>"
  assert_eq "$a2" "$a1" "문서별 자리: 같은 문서를 두 번 도출하면 같은 자리"
  assert_eq "$a3" "$a1" "문서별 자리: 같은 문서를 가리키는 심볼릭 링크도 같은 자리 (init 의 정규화와 같다)"
  if [ -n "$b" ] && [ "$b" != "$a1" ] && [ "${b%/*}" = "$w/root/sess0001/docreview" ]; then
    ok "문서별 자리: 이름이 같은 다른 문서는 다른 자리"
  else
    no "문서별 자리: 다른 문서가 같은 자리로 간다 ($b = $a1)"
  fi
  py docreview_state.py state-dir-for --root "root" --session sess0001 --doc "$FX/design-sample.md" >"$w/o1" 2>"$w/e1"; rc=$?
  assert_eq "$rc:$(cat "$w/o1")" "1:" "문서별 자리: 상대 루트는 rc 1 · 출력 없음"
  assert_file_grep "$w/e1" '"reason": "root_not_absolute"' "문서별 자리: 상대 루트의 사유는 root_not_absolute"
  py docreview_state.py state-dir-for --root "$w/root" --session "" --doc "$FX/design-sample.md" >"$w/o2" 2>"$w/e2"; rc=$?
  assert_eq "$rc:$(cat "$w/o2")" "1:" "문서별 자리: 빈 세션은 rc 1 · 출력 없음 (루트 바로 아래를 여러 세션이 나눠 쓰지 않는다)"
  assert_file_grep "$w/e2" '"reason": "session_invalid"' "문서별 자리: 빈 세션의 사유는 session_invalid"
  py docreview_state.py state-dir-for --root "$w/root" --session sess0001 --doc "" >"$w/o3" 2>"$w/e3"; rc=$?
  assert_eq "$rc:$(cat "$w/o3")" "1:" "문서별 자리: 빈 문서는 rc 1 · 출력 없음"
  assert_file_grep "$w/e3" '"reason": "doc_empty"' "문서별 자리: 빈 문서의 사유는 doc_empty"
  ( cd "$FX" && py docreview_state.py state-dir-for --root "$w/root" --session sess0001 --doc design-sample.md ) >"$w/o4" 2>"$w/e4"; rc=$?
  assert_eq "$rc:$(cat "$w/o4")" "1:" "문서별 자리: 상대 문서 경로는 rc 1 · 출력 없음 (키가 cwd 의 함수가 되지 않는다)"
  assert_file_grep "$w/e4" '"reason": "doc_not_absolute"' "문서별 자리: 상대 문서의 사유는 doc_not_absolute"
  py docreview_state.py state-dir-for --root "$w/root" --session "$(printf 'ab\ncd')" --doc "$FX/design-sample.md" >"$w/o5" 2>"$w/e5"; rc=$?
  assert_eq "$rc:$(cat "$w/o5")" "1:" "문서별 자리: 개행이 든 세션은 rc 1 · 출력 없음 (두 줄 경로를 내지 않는다)"
  assert_file_grep "$w/e5" '"reason": "session_invalid"' "문서별 자리: 제어 문자 세션의 사유는 session_invalid"
  py docreview_state.py state-dir-for --root "$w/root" --session ".." --doc "$FX/design-sample.md" >"$w/o6" 2>"$w/e6"; rc=$?
  assert_eq "$rc:$(cat "$w/o6")" "1:" "문서별 자리: '..' 세션은 rc 1 · 출력 없음"
  a1="$(py docreview_state.py state-dir-for --root "$w/root" --session "a_B-9" --doc "$FX/design-sample.md")"
  assert_eq "${a1%/docreview/*}" "$w/root/a_B-9" "문서별 자리: [A-Za-z0-9_-] 세션은 받는다 (세션 검사 좁힘의 양의 짝)"
  rm -rf "$w"
}
case_init_relative_doc_refused() {
  local d rc; d="$(mktemp -d -t docreview-XXXXXX)"
  ( cd "$FX" && py docreview_state.py init --state-dir "$d" --doc design-sample.md --profile "$PROF_SD/design-doc.md" ) >"$d/out" 2>"$d/err"; rc=$?
  assert_eq "$rc" "1" "상대 문서: init 이 상대 --doc 을 rc 1 로 거부한다 (문서 정체가 cwd 의 함수가 되지 않는다)"
  assert_file_grep "$d/err" '"reason": "doc_not_absolute"' "상대 문서: 사유는 doc_not_absolute"
  if [ -e "$d/docreview-state.md" ]; then
    no "상대 문서: 거부했는데 원장이 생겼다"
  else
    ok "상대 문서: 원장이 생기지 않는다"
  fi
  rm -rf "$d"
}
