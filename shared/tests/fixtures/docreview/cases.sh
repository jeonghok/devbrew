# docreview 행동 케이스 — 행동 락(test_docreview_*.sh)과 mutation 락(test_docreview_mutations.sh)이 공유한다.
# 계약: 이 파일을 source 하기 전에 REPO_ROOT · SCRIPTS 가 정의돼 있어야 하고 assert.sh 가 로드돼 있어야 한다.
#       각 case_* 는 자기 임시 디렉토리를 만들고 끝에 지운다. 관측은 assert_* 로만 낸다.
FX="$REPO_ROOT/shared/tests/fixtures/docreview"
# 필드 없는 사본 — 이 파일의 케이스는 must_catch 를 지목하지 않은 프로필의 동작(라우팅 현행)을 잰다.
# must_catch 를 지목한 동작은 cases_advice.sh 가 실제 프로필($PROF_MC)로 잰다.
PROF_SD="${DOCREVIEW_PROF_SD:-$(bash "$FX/nofield_profiles.sh")}"
# 위 서브셸의 실패(빈 PROF_SD)를 그냥 넘기면 "$PROF_SD/design-doc.md" 가 "/design-doc.md" 로
# 풀려 아래 모든 케이스가 무관한 방식으로 조용히 깨진다 — 여기서 바로 죽는다. `exit` 를 쓰는
# 이유: 이 파일을 source 하는 모든 자리(anchor·gate_visibility·intent·route·state·
# capture_finalize_golden.sh)가 `set -e` 없이 최상위에서 source 하고 리턴값을 안 보므로
# `return` 은 조용히 넘어간다 — `test_docreview_mutations.sh` 의 `run_case` 만 서브셸
# 안에서 source 하므로 그 한 자리에서는 `exit` 가 서브셸만 끝낸다(전체 스위트는 안 죽는다).
[ -n "$PROF_SD" ] && [ -d "$PROF_SD" ] || { echo "[cases.sh] 사본 프로필 디렉토리 없음: '${PROF_SD}'" >&2; exit 1; }
PROF_QG="$REPO_ROOT/plugins/quality-gates/references/docreview-profiles"
export PYTHONDONTWRITEBYTECODE=1
# 개발자 환경의 엔진 값이 케이스에 새지 않게 한다 — 값을 따지는 케이스는 호출마다 직접 지정한다.
unset DEVBREW_DOCREVIEW_DETECTORS DEVBREW_DOCREVIEW_REREVIEW_CAP DEVBREW_DOCREVIEW_RENDER_CAP DEVBREW_DOCREVIEW_SUMMARY_WIDTH

py()   { python3 "$SCRIPTS/$1" "${@:2}"; }                      # py <script> <args…>
jget() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$1" "$2"; }
jgets(){ python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); print(eval(sys.argv[1]))' "$1"; }
own_doc() {   # own_doc <state-dir> <doc> → 그 문서의 사본 경로(<state-dir>/src/<이름>). 원장의 문서는 도우미가 가진 사본이다
  mkdir -p "$1/src" && cp "$2" "$1/src/${2##*/}" && echo "$1/src/${2##*/}"
}
mk_state() {   # mk_state <doc> <profile>  → prints state dir (init 까지). 원장의 문서는 <doc> 의 사본이다
  local d o; d="$(mktemp -d -t docreview-XXXXXX)" || return 1
  o="$(own_doc "$d" "$1")" || { echo "$d"; return 1; }
  py docreview_state.py init --state-dir "$d" --doc "$o" --profile "$2" >/dev/null || { echo "$d"; return 1; }
  echo "$d"
}
snap() { py docreview_anchor.py snapshot "$1" > "$2"; }         # snap <doc> <out.json>
ledger_doc() { python3 "$FX/st_get.py" "$1/docreview-state.md" 'st["doc"]'; }   # ledger_doc <state-dir> → 원장의 문서
# put_doc 의 거절은 서브셸 안에서도 세어져야 한다 — `d="$(도우미)"` · `$(ac2_diff …)` · `$(next_round …)` 처럼
# 도우미가 $(…) 안에서 불리면 그 안의 `no` 가 올린 실패 수는 부모 셸로 돌아오지 않는다. 서브셸이면 실패를
# 운반 파일에도 적고, 부모(이 파일을 source 한 셸)의 carry_fold 가 다시 센다. finish 가 끝에 한 번 더 접는다.
_CASES_SUB0=$BASH_SUBSHELL
_CASES_CARRY="$(mktemp -t cases-carry-XXXXXX)" || { echo "[cases.sh] 실패 운반 파일을 만들지 못했다" >&2; exit 1; }
put_fail() {   # put_fail <msg> — 실패를 센다. 서브셸이면 운반 파일에도 적는다
  no "$1"
  if [ "$BASH_SUBSHELL" -gt "$_CASES_SUB0" ]; then printf '%s\n' "$1" >> "$_CASES_CARRY"; fi
  return 0
}
carry_fold() {   # 부모 셸에서 — 서브셸이 운반 파일에 남긴 실패를 하나씩 세고 파일을 비운다
  [ "$BASH_SUBSHELL" -eq "$_CASES_SUB0" ] || return 0
  [ -s "$_CASES_CARRY" ] || return 0
  local l; while IFS= read -r l; do no "[서브셸 안에서 난 실패] $l"; done < "$_CASES_CARRY"
  : > "$_CASES_CARRY"
}
eval "_cases_finish_orig() $(declare -f finish | sed 1d)"
finish() {   # 운반 파일은 이 파일을 source 한 셸에서만 접고 지운다 — 서브셸의 finish 가 부모 몫을 지우지 않게
  if [ "$BASH_SUBSHELL" -eq "$_CASES_SUB0" ]; then carry_fold; rm -f "$_CASES_CARRY"; fi
  _cases_finish_orig
}
put_doc() {   # put_doc <state-dir> <doc> — 이번 라운드의 문서를 원장의 문서 자리에 옮긴다(같은 파일이면 그대로). 공유 픽스처는 덮지 않는다
  local L; L="$(ledger_doc "$1")" || { put_fail "[cases.sh] 원장의 문서를 읽지 못했다: $1" >&2; return 1; }
  [ "$2" -ef "$L" ] && return 0
  case "$L" in "$FX"/*) put_fail "[cases.sh] 원장의 문서가 공유 픽스처다 — 덮지 않는다: $L" >&2; return 1 ;; esac
  cp "$2" "$L" || { put_fail "[cases.sh] 문서 복사 실패: $2 → $L" >&2; return 1; }
}
put_snap() { put_doc "$1" "$(jget "$2" 'd["doc"]')"; }   # put_snap <state-dir> <snapshot.json> — 그 스냅숏을 뜬 문서를 원장의 문서 자리에. 부르는 줄은 `&&` 로 잇는다(거절이면 begin-round 를 돌리지 않는다)
# put_snap 의 거절은 `no` 로 실패를 센다 — `$(...)` 안에서 부르면 그 자리의 수는 서브셸에서 사라지고 운반 파일로만 부모에 닿는다(위 put_fail). 그래서 직접 부르는 줄은 `$(...)` 밖에서 부른다.
_put_in_helper() {   # _put_in_helper <state-dir> <snapshot> — 상태 폴더를 돌려주는 도우미 꼴: 안에서 put_snap 을 부르고 끝까지 간다
  put_snap "$1" "$2"; echo ran
}
case_put_snap_failure_counted() {   # 공유 픽스처가 원장의 문서인 상태에 다른 문서의 스냅숏을 넣는 줄이 실패를 정확히 1 센다
  local d s b a1 a2 a3 r pf
  d="$(mktemp -d -t docreview-XXXXXX)" || { no "put_snap 계수: 임시 폴더 실패"; return; }
  py docreview_state.py init --state-dir "$d" --doc "$FX/design-sample.md" --profile "$PROF_SD/design-doc.md" >/dev/null || { no "put_snap 계수: init 실패"; rm -rf "$d"; return; }
  { cat "$FX/design-sample.md"; echo "다른 문서"; } > "$d/other.md"; s="$d/s.json"; snap "$d/other.md" "$s"
  b=$_ASSERT_FAIL
  { r=""; put_snap "$d" "$s" && r="$(py docreview_state.py begin-round --state-dir "$d")"; } 2>/dev/null
  a1=$((_ASSERT_FAIL - b)); _ASSERT_FAIL=$b
  { pf=put_snap; r=""; r="$($pf "$d" "$s" && py docreview_state.py begin-round --state-dir "$d")"; } 2>/dev/null
  a2=$((_ASSERT_FAIL - b))
  carry_fold 2>/dev/null >/dev/null; a3=$((_ASSERT_FAIL - b)); _ASSERT_FAIL=$b
  assert_eq "$a1" "1" "put_snap 계수: 부름 줄을 서브셸 밖에서 돌리면 거절이 실패로 정확히 1 센다"
  assert_eq "$a2" "0" "put_snap 계수 대조: 옛 꼴(\$(…) 안)에서는 그 실패가 그 자리에서는 세어지지 않는다"
  assert_eq "$a3" "1" "put_snap 계수: 서브셸 안 거절은 운반 파일로 넘어와 부모가 정확히 1 센다(carry_fold)"
  assert_eq "$r" "" "put_snap 계수: 거절이면 begin-round 를 돌리지 않는다"
  # 도우미가 \$(…) 안에서 불려도(상태 폴더를 돌려주는 도우미 · ac2_diff · next_round) 그 안의 거절이 사라지지 않는다
  b=$_ASSERT_FAIL
  { r="$(_put_in_helper "$d" "$s")"; } 2>/dev/null
  carry_fold >/dev/null 2>&1; a3=$((_ASSERT_FAIL - b)); _ASSERT_FAIL=$b
  assert_eq "$a3 [$r]" "1 [ran]" "put_snap 계수: \$(도우미) 안의 거절도 부모가 정확히 1 센다"
  b=$_ASSERT_FAIL; carry_fold >/dev/null 2>&1
  assert_eq "$((_ASSERT_FAIL - b))" "0" "put_snap 계수: 운반 파일은 한 번 세면 비운다(두 번 세지 않는다)"
  rm -rf "$d"
  # 원장을 못 읽는 실패 · 복사 실패도 같은 줄에서 정확히 1 센다 — 세지 않으면 `put_snap … && assert_eq …` 의 단언이 조용히 빠진다
  d="$(mktemp -d -t docreview-XXXXXX)" || { no "put_snap 계수: 임시 폴더 실패"; return; }
  s="$d/s.json"; snap "$FX/design-sample.md" "$s"
  b=$_ASSERT_FAIL; { r=""; put_snap "$d" "$s" && r="$(py docreview_state.py begin-round --state-dir "$d")"; } >/dev/null 2>&1
  a1=$((_ASSERT_FAIL - b)); _ASSERT_FAIL=$b
  assert_eq "$a1 [$r]" "1 []" "put_snap 계수: 원장이 없어 원장의 문서를 못 읽으면 실패로 정확히 1 센다"
  rm -rf "$d"
  d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "put_snap 계수: init 실패"; rm -rf "$d"; return; }
  cp "$FX/design-sample.md" "$d/gone.md"; s="$d/s.json"; snap "$d/gone.md" "$s"; rm -f "$d/gone.md"
  b=$_ASSERT_FAIL; { r=""; put_snap "$d" "$s" && r="$(py docreview_state.py begin-round --state-dir "$d")"; } >/dev/null 2>&1
  a1=$((_ASSERT_FAIL - b)); _ASSERT_FAIL=$b
  assert_eq "$a1 [$r]" "1 []" "put_snap 계수: 문서 복사가 실패하면 실패로 정확히 1 센다"
  rm -rf "$d"
}

# ── T37 — 상한 2 와 추가 라운드 ───────────────────────────────────────────
case_T37_cap_and_extra() {
  local d s; d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "T37: init 실패"; return; }
  s="$d/snap.json"; snap "$FX/design-sample.md" "$s"
  local r1 r2 r3 r4 r4b
  r1=""; put_snap "$d" "$s" && r1="$(py docreview_state.py begin-round --state-dir "$d" | jgets 'd["rereview_count"]')"
  r2=""; put_snap "$d" "$s" && r2="$(py docreview_state.py begin-round --state-dir "$d" | jgets 'd["rereview_count"]')"
  r3=""; put_snap "$d" "$s" && r3="$(py docreview_state.py begin-round --state-dir "$d" | jgets 'd["rereview_count"]')"
  assert_eq "$r1 $r2 $r3" "0 1 2" "T37: rereview_count 는 라운드 1·2·3 에서 0·1·2"
  put_snap "$d" "$s" && py docreview_state.py begin-round --state-dir "$d" >/dev/null 2>&1; r4=$?
  assert_eq "$r4" "3" "T37: 라운드 4 는 승인 없이 rc 3 (cap_reached)"
  r4b=""; put_snap "$d" "$s" && r4b="$(py docreview_state.py begin-round --state-dir "$d" --extra-approval '추가 라운드 1회 열기' --extra-approval-source label | jgets 'd["round"]')"
  assert_eq "$r4b" "4" "T37: --extra-approval 이 있으면 라운드 4 가 열린다"
  local nx; nx="$(python3 "$FX/st_get.py" "$d/docreview-state.md" 'len(st["extra_rounds"]), st["extra_rounds"][0]["round"], st["rereview_count"], st["extra_rounds"][0]["source"]')"
  assert_eq "$nx" "(1, 4, 2, 'label')" "T37: extra_rounds 에 개별 기록 1건(round 4), 카운터는 2 에 머문다"
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
  py docreview_state.py begin-round --state-dir "$d" >/dev/null; echo "$d"
}
next_round() {   # next_round <state-dir> <doc-for-this-round> [extra-quote]  → prints diff json path
  local d="$1" n; n="$(st_yaml "$d" 'st["round"]+1')"; snap "$2" "$d/s$n.json"; put_doc "$d" "$2" || return 1
  if [ -n "${3:-}" ]; then py docreview_state.py begin-round --state-dir "$d" --extra-approval "$3" --extra-approval-source label >/dev/null
  else py docreview_state.py begin-round --state-dir "$d" >/dev/null; fi
  py docreview_state.py exempt-anchors --state-dir "$d" > "$d/ex$n.json"
  py docreview_anchor.py diff "$d/s$((n-1)).json" "$d/s$n.json" --exempt "$d/ex$n.json" > "$d/diff$n.json"
  py docreview_state.py observe-diff --state-dir "$d" > "$d/obs$n.json"
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
case_AC38_related_declared_exempt_and_shown() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  local did; did="$(py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '고친다' | jgets 'd["decision_id"]')"
  py docreview_state.py declare-related --state-dir "$d" --decision "$did" --anchors '#2-goals' > "$d/rel.json"
  assert_eq "$(jget "$d/rel.json" 'd["ok"], d["related"]')" "(True, ['#2-goals'])" "AC38: 고친다 결정에 절을 묶는다"
  local df; df="$(next_round "$d" "$FX/design-sample-r2.md")"
  assert_eq "$(jget "$df" '[c["anchor"] for c in d["changed"]]')" "[]" "AC38: 묶인 절의 변경은 frozen_change 로 오르지 않는다"
  assert_eq "$did" "D1.1" "AC38: 라운드 1 의 첫 결정 id"
  assert_eq "$(jget "$df" 'sorted(e["scope"] for e in d["exempt_applied"])')" "['#12-files-to-modify', 'related:D1.1']" "AC38: 면제 사유가 신고로 보인다"
  local r; r="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_contains "$r" "이 결정 때문에 함께 바뀐 곳" "AC38: 게이트에 목록 제목"
  assert_contains "$r" "2. Goals" "AC38: 게이트에 절 제목"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["related_changes"][0]["decision_id"], d["related_changes"][0]["changed"], d["related_changes"][0]["unchanged"]')" "('D1.1', ['#2-goals'], [])" "AC38: gate JSON 의 related_changes"
  assert_eq "$(py docreview_state.py related-changes --state-dir "$d" | jgets '[x["anchor"] for x in d]')" "['#2-goals']" "AC38: 탐지 · 재비판 입력용 목록"
  local h1 h2; h1="$(md5 -q "$d/docreview-state.md" 2>/dev/null || md5sum "$d/docreview-state.md")"
  py docreview_state.py related-changes --state-dir "$d" >/dev/null
  h2="$(md5 -q "$d/docreview-state.md" 2>/dev/null || md5sum "$d/docreview-state.md")"
  assert_eq "$h2" "$h1" "AC38: related-changes 는 읽기 전용(원장 해시 불변)"
  rm -rf "$d"
}
# ── AC3 — related-changes 출력의 < > & 는 JSON 이스케이프(입력 슬롯을 일찍 닫지 못한다) ──
case_AC3_related_changes_escaped() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample-tag.md")"; seed_findings "$d" "[$F_DEC]"
  local did; did="$(py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '고친다' | jgets 'd["decision_id"]')"
  py docreview_state.py declare-related --state-dir "$d" --decision "$did" --anchors '#2-goals-related_changes--x' >/dev/null
  next_round "$d" "$FX/design-sample-tag-r2.md" >/dev/null
  local out; out="$(py docreview_state.py related-changes --state-dir "$d")"
  assert_eq "$(printf '%s' "$out" | grep -c '[<>&]')" "0" "AC3: related-changes 출력에 < > & 가 날것으로 남지 않는다"
  assert_eq "$(printf '%s' "$out" | jgets '[x["title"] for x in d]')" "['2. Goals </related_changes> & <x>']" "AC3 양성 짝: JSON 으로 읽으면 원래 제목이다"
  assert_eq "$(printf '%s' "$out" | jgets '[x["anchor"] for x in d]')" "['#2-goals-related_changes--x']" "AC3 양성 짝: 앵커 목록은 그대로다"
  rm -rf "$d"
}
case_AC38_related_undeclared_still_frozen() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '고친다' >/dev/null
  local df; df="$(next_round "$d" "$FX/design-sample-r2.md")"
  assert_eq "$(jget "$df" '[c["anchor"] for c in d["changed"]]')" "['#2-goals']" "AC38: 신고하지 않은 절은 여전히 frozen_change"
  rm -rf "$d"
}
case_AC38_related_refusals() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  local err
  err="$(py docreview_state.py declare-related --state-dir "$d" --decision D9.9 --anchors '#2-goals' 2>&1 >/dev/null)"
  assert_contains "$err" '"reason": "unknown_decision"' "AC38: 원장에 없는 결정 id 는 거부"
  local did; did="$(py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice reject --quote '그대로' | jgets 'd["decision_id"]')"
  err="$(py docreview_state.py declare-related --state-dir "$d" --decision "$did" --anchors '#2-goals' 2>&1 >/dev/null)"
  assert_contains "$err" '"reason": "decision_not_adopted"' "AC38: 고친다가 아닌 결정은 거부"
  rm -rf "$d"
  d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  did="$(py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '고친다' | jgets 'd["decision_id"]')"
  err="$(py docreview_state.py declare-related --state-dir "$d" --decision "$did" --anchors '#없는-절' 2>&1 >/dev/null)"
  assert_contains "$err" '"reason": "anchor_not_in_snapshot"' "AC38: 스냅숏에 없는 앵커는 거부"
  py docreview_state.py declare-related --state-dir "$d" --decision "$did" --anchors 'insert-after:#2-goals' > "$d/rel.json"
  assert_eq "$(jget "$d/rel.json" 'd["ok"]')" "True" "AC38: insert-after 꼴은 받는다"
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null
  err="$(py docreview_state.py declare-related --state-dir "$d" --decision "$did" --anchors '#3-non-goals' 2>&1 >/dev/null)"
  assert_contains "$err" '"reason": "permit_consumed"' "AC38: 이미 소비된 permit 에는 묶지 못한다"
  rm -rf "$d"
}
case_AC38_related_declared_but_unchanged_disclosed() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  local did; did="$(py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '고친다' | jgets 'd["decision_id"]')"
  py docreview_state.py declare-related --state-dir "$d" --decision "$did" --anchors '#3-non-goals' >/dev/null
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null
  assert_contains "$(py docreview_state.py gate --state-dir "$d" --render)" "신고했지만 바뀌지 않은 곳" "AC38: 신고했는데 안 바뀐 절도 공시한다"
  rm -rf "$d"
}
F_BRIEF_DEC='{"id":"aaaa0001#r1.1","lineage":"aaaa0001#r1.1","bucket":"aaaa0001","origin":"reviewer","layer":2,"category":"ambiguity","anchor":"#2-확정","edit_scope":"#2-확정","disposition":"decide","summary":"확정 항목이 두 가지로 읽힌다","evidence":"3행","blocks":[],"kind":"pre"}'
case_AC38_related_immutable_refused_and_frozen() {
  local d s1 s2 err; d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC38: init 실패"; return; }
  s1="$d/s1.json"; snap "$FX/brief-append-r1.md" "$s1"
  put_snap "$d" "$s1" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  seed_findings "$d" "[$F_BRIEF_DEC]"
  local did; did="$(py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '고친다' | jgets 'd["decision_id"]')"
  err="$(py docreview_state.py declare-related --state-dir "$d" --decision "$did" --anchors '#6-사용자-원문' 2>&1 >/dev/null)"
  assert_contains "$err" '"reason": "anchor_immutable"' "AC38: 불변 절(사용자 원문)은 신고로 묶지 못한다"
  # 이중 방어 — 원장이 손으로 바뀌어 불변 절이 related_anchors 에 들어 있어도 면제하지 않는다
  PYTHONPATH="$SCRIPTS" python3 -c 'import sys; from docreview_state import load_state, save_state; d=sys.argv[1]; st=load_state(d); [p.update(related_anchors=["#6-사용자-원문"]) for p in st["permits"].values()]; save_state(d, st, "fixture")' "$d"
  s2="$d/s2.json"; snap "$FX/brief-append-r2-edit.md" "$s2"
  put_snap "$d" "$s2" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  assert_not_contains "$(py docreview_state.py exempt-anchors --state-dir "$d")" "related:" "AC38: 불변 절은 exempt 집합에 안 든다(이중 방어)"
  assert_eq "$(PYTHONPATH="$SCRIPTS" python3 "$FX/st_get.py" "$d/docreview-state.md" '[c["anchor"] for c in __import__("docreview_state").round_diff(st, __import__("docreview_state").load_profile(st["profile"]), 2)["changed"]]')" "['#6-사용자-원문']" "AC38: 불변 절의 비-추가 수정은 여전히 frozen_change"
  rm -rf "$d"
}
case_AC38_related_insert_after() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  local did; did="$(py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '고친다' | jgets 'd["decision_id"]')"
  local err; err="$(py docreview_state.py declare-related --state-dir "$d" --decision "$did" --anchors 'insert-after:#없는-절' 2>&1 >/dev/null)"
  assert_contains "$err" '"reason": "anchor_not_in_snapshot"' "AC38: insert-after 의 기준 앵커가 스냅숏에 없으면 거부"
  py docreview_state.py declare-related --state-dir "$d" --decision "$did" --anchors 'insert-after:#2-goals' >/dev/null
  python3 -I -c 'import sys; t=open(sys.argv[1],encoding="utf-8").read(); i=t.index("## 3."); open(sys.argv[2],"w",encoding="utf-8").write(t[:i]+"## 새 절\n\n본문 한 줄.\n\n"+t[i:])' "$FX/design-sample.md" "$d/ins.md"
  local df; df="$(next_round "$d" "$d/ins.md")"
  assert_eq "$(jget "$df" '[c["anchor"] for c in d["changed"]]')" "[]" "AC38: 신고한 insert-after 로 들어온 절은 frozen_change 가 아니다"
  assert_eq "$(jget "$df" '[(e["anchor"], e["scope"]) for e in d["exempt_applied"]]')" "[('#새-절', 'related:D1.1')]" "AC38: 면제 사유가 신고로 보인다"
  local r; r="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_contains "$r" "이 결정 때문에 함께 바뀐 곳 1개 (D1.1)" "AC38: 끼워 넣은 절이 바뀐 곳으로 보인다"
  assert_not_contains "$r" "신고했지만 바뀌지 않은 곳" "AC38: 끼워 넣은 절을 안 바뀐 곳으로 세지 않는다"
  assert_eq "$(py docreview_state.py related-changes --state-dir "$d" | jgets '[x["anchor"] for x in d]')" "['#새-절']" "AC38: related-changes 가 끼워 넣은 절을 낸다"
  rm -rf "$d"
}
case_AC38_related_scoped_to_permit_round() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  local did; did="$(py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '고친다' | jgets 'd["decision_id"]')"
  py docreview_state.py declare-related --state-dir "$d" --decision "$did" --anchors '#2-goals' >/dev/null
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null
  local df; df="$(next_round "$d" "$FX/design-sample.md")"
  assert_eq "$(jget "$df" 'sorted(c["anchor"] for c in d["changed"])')" "['#12-files-to-modify', '#2-goals']" "AC38: 신고는 permit 라운드 밖에서 면제하지 않는다(라운드 3 에서 둘 다 frozen_change)"
  rm -rf "$d"
}
case_AC38_related_uncountable_disclosed() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  local did; did="$(py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '고친다' | jgets 'd["decision_id"]')"
  py docreview_state.py declare-related --state-dir "$d" --decision "$did" --anchors '#2-goals' >/dev/null
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null
  PYTHONPATH="$SCRIPTS" python3 -c 'import sys; from docreview_state import load_state, save_state; d=sys.argv[1]; st=load_state(d); del st["snapshots"]["1"]; save_state(d, st, "fixture")' "$d"
  local r; r="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_contains "$r" "이 결정 때문에 함께 바뀐 곳을 셀 수 없다" "AC38: 못 읽으면 「셀 수 없음」 을 낸다"
  assert_not_contains "$r" "신고했지만 바뀌지 않은 곳" "AC38: 못 읽은 것을 «안 바뀜» 으로 내지 않는다"
  local err; err="$(py docreview_state.py related-changes --state-dir "$d" 2>&1 >/dev/null)"
  assert_contains "$err" '"reason": "related_uncountable"' "AC38: related-changes 는 빈 목록 대신 이름 있는 사유로 실패한다"
  rm -rf "$d"
}
r2_changed() {   # r2_changed <state-dir> → 라운드 2 얼림 diff 의 changed 앵커 목록과 면제 (anchor, scope) 쌍
  PYTHONPATH="$SCRIPTS" python3 "$FX/st_get.py" "$1/docreview-state.md" '(lambda D: ([c["anchor"] for c in D["changed"]], [(e["anchor"], e.get("scope")) for e in D["exempt_applied"]]))(__import__("docreview_state").round_diff(st, __import__("docreview_state").load_profile(st["profile"]), 2))'
}
plant_permit() {   # plant_permit <state-dir> <finding-id> <apply-anchor> [related-anchor] — 옛 원장 · 위조를 흉내 낸 permit 을 원장에 심는다
  PYTHONPATH="$SCRIPTS" python3 -c 'import sys; from docreview_state import load_state, save_state; d, fid, ap = sys.argv[1:4]; st=load_state(d); st["decides"][fid]["state"]="adopted"; p={"kind":"apply","apply_anchors":[ap],"round":2,"finding_id":fid,"consumed":False}; (p.update(related_anchors=[sys.argv[4]]) if len(sys.argv) > 4 else None); st["permits"]["D1.1"]=p; save_state(d, st, "fixture")' "$@"
}
F_BRIEF_NOIMM='{"id":"eeee0001#r1.1","lineage":"eeee0001#r1.1","bucket":"eeee0001","origin":"reviewer","layer":2,"category":"omission","anchor":"#2-확정","edit_scope":"EDIT_SCOPE","disposition":"decide","summary":"x","evidence":"S1","blocks":[],"kind":"pre"}'
case_AC38_audit_row1_forged_related_scope() {
  # 감사 1 — 리뷰어 edit_scope 로 쓴 「related:D9.9=#6」 이 불변 절을 얼림에서 빼는 우회
  local d err; d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC38: init 실패"; return; }
  snap "$FX/brief-append-r1.md" "$d/s1.json"; put_snap "$d" "$d/s1.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  seed_findings "$d" "[${F_BRIEF_NOIMM/EDIT_SCOPE/related:D9.9=#6-사용자-원문}]"
  err="$(py docreview_state.py decide --state-dir "$d" --id 'eeee0001#r1.1' --choice adopt --quote '고친다' 2>&1 >/dev/null)"
  assert_contains "$err" '"why": "scope_label_forged"' "AC38 감사1: 위조 related: edit_scope 는 decide 가 permit 을 열지 않는다"
  plant_permit "$d" 'eeee0001#r1.1' 'related:D9.9=#6-사용자-원문'
  snap "$FX/brief-append-r2-edit.md" "$d/s2.json"; put_snap "$d" "$d/s2.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  assert_eq "$(r2_changed "$d")" "(['#6-사용자-원문'], [])" "AC38 감사1: 심어 둔 위조 permit 도 §6 을 면제하지 못한다(exempt_scopes 이중 방어) — §6 은 frozen_change"
  assert_eq "$(py docreview_anchor.py check-intent 'eeee0001#r1.1' --intent 'related:D9.9=#6-사용자-원문' --state-dir "$d" | jgets 'd["reason"]')" "scope_label_forged" "AC38 감사1: check-intent 도 위조 라벨을 거부한다"
  rm -rf "$d"
}
case_AC38_audit_row2_edit_scope_immutable() {
  # 감사 2 — 불변이 아닌 앵커의 finding 이 edit_scope 로 §6 을 가리킨 채 채택되는 우회
  local d err; d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC38: init 실패"; return; }
  snap "$FX/brief-append-r1.md" "$d/s1.json"; put_snap "$d" "$d/s1.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  seed_findings "$d" "[${F_BRIEF_NOIMM/EDIT_SCOPE/#6-사용자-원문}]"
  err="$(py docreview_state.py decide --state-dir "$d" --id 'eeee0001#r1.1' --choice adopt --quote '고친다' 2>&1 >/dev/null)"
  assert_contains "$err" '"reason": "edit_scope_refused"' "AC38 감사2: 불변 절로 풀리는 edit_scope 의 채택은 permit 을 열지 않는다"
  assert_eq "$(st_yaml "$d" 'len(st["permits"]), st["decides"]["eeee0001#r1.1"]["state"]')" "(0, 'open')" "AC38 감사2: 거부된 채택은 원장을 바꾸지 않는다"
  plant_permit "$d" 'eeee0001#r1.1' '#6-사용자-원문'
  snap "$FX/brief-append-r2-edit.md" "$d/s2.json"; put_snap "$d" "$d/s2.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  assert_eq "$(r2_changed "$d")" "(['#6-사용자-원문'], [])" "AC38 감사2: 심어 둔 permit 의 §6 앵커도 면제하지 못한다(exempt_scopes 이중 방어)"
  rm -rf "$d"
  # 양성 짝 — 불변이 아닌 edit_scope 의 채택은 그대로 permit 을 연다
  d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC38: init 실패"; return; }
  snap "$FX/brief-append-r1.md" "$d/s1.json"; put_snap "$d" "$d/s1.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  seed_findings "$d" "[${F_BRIEF_NOIMM/EDIT_SCOPE/#2-확정}]"
  assert_eq "$(py docreview_state.py decide --state-dir "$d" --id 'eeee0001#r1.1' --choice adopt --quote '고친다' | jgets 'd["permit"]["apply_anchors"]')" "['#2-확정']" "AC38 감사2 양성 짝: 정상 edit_scope 는 permit 을 연다"
  rm -rf "$d"
}
case_AC38_audit_row3_insert_after_immutable() {
  # 감사 3 — insert-after:#(불변 절 또는 그 하위 절) 를 신고로 받아 §6 안에 끼운 절을 면제하는 우회
  local d err; d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC38: init 실패"; return; }
  python3 -I -c 'import sys; t=open(sys.argv[1],encoding="utf-8").read(); open(sys.argv[2],"w",encoding="utf-8").write(t.rstrip("\n")+"\n\n### 하위\n\n본문 한 줄.\n")' "$FX/brief-append-r1.md" "$d/r1.md"
  snap "$d/r1.md" "$d/s1.json"; put_snap "$d" "$d/s1.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  seed_findings "$d" "[${F_BRIEF_NOIMM/EDIT_SCOPE/#2-확정}]"
  py docreview_state.py decide --state-dir "$d" --id 'eeee0001#r1.1' --choice adopt --quote '고친다' >/dev/null
  err="$(py docreview_state.py declare-related --state-dir "$d" --decision D1.1 --anchors 'insert-after:#하위' 2>&1 >/dev/null)"
  assert_contains "$err" '"reason": "anchor_immutable"' "AC38 감사3: 불변 절의 하위 절 뒤에 끼우는 신고는 거부"
  err="$(py docreview_state.py declare-related --state-dir "$d" --decision D1.1 --anchors 'insert-after:#6-사용자-원문' 2>&1 >/dev/null)"
  assert_contains "$err" '"reason": "anchor_immutable"' "AC38 감사3: 불변 절 자신의 뒤에 끼우는 신고도 거부"
  # 이중 방어 — 원장에 손으로 심은 insert-after 신고는 풀린 앵커(새 절의 조상 제목이 불변)로 걸러진다
  plant_permit "$d" 'eeee0001#r1.1' '#2-확정' 'insert-after:#하위'
  python3 -I -c 'import sys; t=open(sys.argv[1],encoding="utf-8").read(); open(sys.argv[2],"w",encoding="utf-8").write(t.rstrip("\n")+"\n\n### 끼워 넣은 가짜 원문\n\n가짜.\n")' "$d/r1.md" "$d/r2.md"
  snap "$d/r2.md" "$d/s2.json"; put_snap "$d" "$d/s2.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  assert_not_contains "$(py docreview_state.py exempt-anchors --state-dir "$d")" "related:" "AC38 감사3: 불변 절 안에 끼운 절은 신고로 면제되지 않는다"
  rm -rf "$d"
}
case_AC38_audit_row4_fix_intent_pass_validated() {
  # 감사 4 — fix --event intent-pass --scope 로 아무 범위나 면제를 만드는 뒷문. 3차에서 이벤트 자체를 없앴다(이름 있는 거부).
  local d err; d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC38: init 실패"; return; }
  snap "$FX/brief-append-r1.md" "$d/s1.json"; put_snap "$d" "$d/s1.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  seed_findings "$d" '[{"id":"ffff0001#r1.1","lineage":"ffff0001#r1.1","bucket":"ffff0001","origin":"reviewer","layer":2,"category":"placeholder","anchor":"#2-확정","edit_scope":"#2-확정","disposition":"fix","summary":"x","evidence":null,"blocks":[]}]'
  err="$(py docreview_state.py fix --state-dir "$d" --id 'ffff0001#r1.1' --event intent-pass --scope 'related:D9.9=#6-사용자-원문' 2>&1 >/dev/null)"
  assert_contains "$err" '"reason": "intent_pass_removed"' "AC38 감사4: fix intent-pass 는 위조 라벨 범위도 이름 있는 거부"
  err="$(py docreview_state.py fix --state-dir "$d" --id 'ffff0001#r1.1' --event intent-pass --scope '#6-사용자-원문' 2>&1 >/dev/null)"
  assert_contains "$err" '"reason": "intent_pass_removed"' "AC38 감사4: fix intent-pass 는 불변 절 범위도 이름 있는 거부"
  assert_eq "$(st_yaml "$d" 'len(st["applied_scopes"]), st["fixes"]["ffff0001#r1.1"]["state"]')" "(0, 'pending')" "AC38 감사4: 거부된 intent-pass 는 원장을 바꾸지 않는다"
  assert_eq "$(_ci 'ffff0001#r1.1' --intent '#6-사용자-원문' --state-dir "$d" | jgets 'd["reason"]')" "scope_outside_edit_scope" "AC38 감사4: 남은 기록자(check-intent)는 edit_scope 밖 범위를 거부한다"
  rm -rf "$d"; d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC38: init 실패"; return; }
  snap "$FX/brief-append-r1.md" "$d/s1.json"; put_snap "$d" "$d/s1.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  seed_findings "$d" '[{"id":"ffff0001#r1.1","lineage":"ffff0001#r1.1","bucket":"ffff0001","origin":"reviewer","layer":2,"category":"placeholder","anchor":"#2-확정","edit_scope":"#2-확정","disposition":"fix","summary":"x","evidence":null,"blocks":[]}]'
  assert_eq "$(_ci 'ffff0001#r1.1' --intent '#2-확정' --state-dir "$d" | jgets 'd["contract"]')" "fix" "AC38 감사4 양성 짝: 정상 범위는 check-intent 로 통과"
  rm -rf "$d"
}
case_AC38_audit_row5_labels_never_apply() {
  # 감사 5 — 면제 라벨(append-only)과 같은 글자를 범위로 쓴 fix 가 «적용됨» 으로 읽히는 우회
  local d; d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC38: init 실패"; return; }
  snap "$FX/brief-append-r1.md" "$d/s1.json"; put_snap "$d" "$d/s1.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  seed_findings "$d" '[{"id":"ffff0001#r1.1","lineage":"ffff0001#r1.1","bucket":"ffff0001","origin":"reviewer","layer":2,"category":"placeholder","anchor":"#2-확정","edit_scope":"#2-확정","disposition":"fix","summary":"x","evidence":null,"blocks":[]}]'
  PYTHONPATH="$SCRIPTS" python3 -c 'import sys; from docreview_state import load_state, save_state; d=sys.argv[1]; st=load_state(d); fx=st["fixes"]["ffff0001#r1.1"]; fx.update(state="intent_passed", scope="append-only", round=1); save_state(d, st, "fixture")' "$d"
  snap "$FX/brief-append-r2.md" "$d/s2.json"; put_snap "$d" "$d/s2.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  assert_eq "$(py docreview_state.py observe-diff --state-dir "$d" | jgets 'd["applied"]')" "[]" "AC38 감사5: 라벨 글자의 fix 범위는 §6 에 줄이 덧붙었다는 사실만으로 적용됨이 되지 않는다"
  rm -rf "$d"
}
case_AC38_audit_row6_decision_log_append_only() {
  # 감사 6 — 결정 기록 절 전체를 면제해 과거 결정 줄을 고쳐 써도 안 잡히던 틈
  local d; d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38: init 실패"; return; }
  python3 -I -c 'import sys; t=open(sys.argv[1],encoding="utf-8").read(); open(sys.argv[2],"w",encoding="utf-8").write(t.rstrip("\n")+"\n\n## 결정 기록\n\n- D1.1 · r1 · reject · x · \"이 방향은 안 된다\" — 요약\n")' "$FX/design-sample.md" "$d/r1.md"
  python3 -I -c 'import sys; t=open(sys.argv[1],encoding="utf-8").read(); open(sys.argv[2],"w",encoding="utf-8").write(t.replace("reject","adopt").replace("이 방향은 안 된다","좋다"))' "$d/r1.md" "$d/r2.md"
  python3 -I -c 'import sys; t=open(sys.argv[1],encoding="utf-8").read(); open(sys.argv[2],"w",encoding="utf-8").write(t.rstrip("\n")+"\n- D2.1 · r2 · adopt · y — 엔진이 덧붙인 줄\n")' "$d/r1.md" "$d/r2a.md"
  snap "$d/r1.md" "$d/s1.json"; put_snap "$d" "$d/s1.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  snap "$d/r2.md" "$d/s2.json"; put_snap "$d" "$d/s2.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  assert_eq "$(r2_changed "$d")" "(['#결정-기록'], [])" "AC38 감사6: 과거 결정 줄을 고쳐 쓰면 frozen_change"
  rm -rf "$d"
  # [4차] 양성 짝은 엔진이 실제로 쓴 줄이어야 한다 — 작성자가 붙인 줄은 엔진 줄이 아니다(case_AC38_r4_B_fake_log_lines).
  d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38: init 실패"; return; }
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1"; br "$d" "$d/doc.md"
  eng_log "$d" bbbb0006; br "$d" "$d/doc.md"
  assert_eq "$(r2_changed "$d")" "([], [('#결정-기록', 'append-only')])" "AC38 감사6 양성 짝: 엔진이 덧붙인 줄은 append-only 로 지나간다"
  rm -rf "$d"
}
case_AC38_audit_row9_declare_stale_permit() {
  # 감사 9 — 지난 라운드의 permit 에 신고를 받아 게이트에 안 보이게 되는 틈
  local d err; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '고친다' >/dev/null
  snap "$FX/design-sample.md" "$d/s2.json"; put_snap "$d" "$d/s2.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  assert_eq "$(py docreview_state.py declare-related --state-dir "$d" --decision D1.1 --anchors '#2-goals' | jgets 'd["ok"]')" "True" "AC38 감사9 양성 짝: permit 라운드(현재 라운드)에는 신고를 받는다"
  snap "$FX/design-sample.md" "$d/s3.json"; put_snap "$d" "$d/s3.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  err="$(py docreview_state.py declare-related --state-dir "$d" --decision D1.1 --anchors '#3-non-goals' 2>&1 >/dev/null)"
  assert_contains "$err" '"reason": "permit_round_mismatch"' "AC38 감사9: 지난 라운드의 permit 에는 신고를 받지 않는다"
  rm -rf "$d"
}
case_AC38_audit_row10_11_entry_flags() {
  # 감사 10·11 — 진입 플래그 정수는 환경 값과 같은 ASCII 숫자만, 공백뿐인 추가 승인은 승인이 아니다
  local d rc; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  snap "$FX/design-sample.md" "$d/s2.json"
  local v
  for v in '1_0' '+2' '２' ' 3'; do
    put_snap "$d" "$d/s2.json" && py docreview_state.py begin-round --state-dir "$d" --detectors "$v" >/dev/null 2>&1; rc=$?
    assert_eq "$rc" "2" "AC38 감사10: --detectors «${v}» 는 인자 오류(rc 2)"
    py docreview_state.py advice --state-dir "$d" --render --cap "$v" >/dev/null 2>"$d/cap-err"; rc=$?
    assert_eq "$rc $(grep -c 'ASCII 숫자만 쓸 수 있다' "$d/cap-err") $(grep -c advice_needs_flag "$d/cap-err")" "2 1 0" \
      "AC38 감사10: --cap «${v}» 는 ASCII 정수 거부(rc 2 · 사유가 cap 이지 advice_needs_flag 가 아니다)"
  done
  local dmc; dmc="$(r1 "$REPO_ROOT/plugins/spec-distill/references/docreview-profiles/design-doc.md" "$FX/design-sample.md")"   # must_catch 를 지목한 프로필 — advice 가 도는 원장
  py docreview_state.py advice --state-dir "$dmc" --render --cap 3 >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "0" "AC38 감사10 양성 짝: --render 와 ASCII 정수 cap 은 받는다(rc 0)"
  put_snap "$d" "$d/s2.json" && assert_eq "$(py docreview_state.py begin-round --state-dir "$d" --detectors 1 | jgets 'd["ok"]')" "True" "AC38 감사10 양성 짝: ASCII 숫자는 받는다"
  snap "$FX/design-sample.md" "$d/s3.json"; snap "$FX/design-sample.md" "$d/s4.json"
  put_snap "$d" "$d/s3.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  local err; err=""; put_snap "$d" "$d/s4.json" && err="$(py docreview_state.py begin-round --state-dir "$d" --extra-approval '   ' --extra-approval-source typed 2>&1 >/dev/null)"; rc=$?
  assert_contains "$err" '"reason": "extra_approval_blank"' "AC38 감사11: 공백뿐인 추가 승인은 거부"
  rm -rf "$d"
}
# ── AC38 3차 — 쓰는 때의 울타리 하나(불변 절 ∪ 결정 기록 · 미룸 절)가 면제를 정한다 ─────────────
br() {   # br <state-dir> <doc> — 그 문서로 다음 라운드를 연다(스냅숏 s<n>.json)
  local n; n="$(st_yaml "$1" 'st["round"]+1')"; snap "$2" "$1/s$n.json"; put_doc "$1" "$2" || return 1
  py docreview_state.py begin-round --state-dir "$1" >/dev/null
}
rk_changed() {   # rk_changed <state-dir> <round> → 그 라운드 얼림 diff 의 (changed 앵커, 면제 (anchor, scope)) — 둘 다 정렬
  PYTHONPATH="$SCRIPTS" python3 "$FX/st_get.py" "$1/docreview-state.md" '(lambda D: (sorted(c["anchor"] for c in D["changed"]), sorted((e["anchor"], e.get("scope")) for e in D["exempt_applied"])))(__import__("docreview_state").round_diff(st, __import__("docreview_state").load_profile(st["profile"]), '"$2"'))'
}
with_log() {   # with_log <src> <out> <줄…> — src 끝에 「## 결정 기록」 절과 줄들을 붙인다(줄이 없으면 원문 그대로)
  python3 -I -c 'import sys; t=open(sys.argv[1],encoding="utf-8").read(); L=sys.argv[3:]; open(sys.argv[2],"w",encoding="utf-8").write(t.rstrip("\n")+"\n" + ("\n## 결정 기록\n\n"+"".join(x+"\n" for x in L) if L else ""))' "$@"
}
LOG_L1='- D1.1 · r1 · reject · x · "이 방향은 안 된다" — 요약'
LOG_L1_FORGED='- D1.1 · r1 · adopt · x · "좋다" — 요약'
LOG_L2='- D2.1 · r2 · adopt · y — 엔진이 덧붙인 줄'
LOG_L3='- D3.1 · r3 · reject · z — 엔진이 덧붙인 줄'
F_LOGSCOPE='{"id":"eeee0001#r1.1","lineage":"eeee0001#r1.1","bucket":"eeee0001","origin":"reviewer","layer":2,"category":"ambiguity","anchor":"#1-context","edit_scope":"EDIT_SCOPE","disposition":"DISP","summary":"맥락 문장이 두 가지로 읽힌다","evidence":"2행","blocks":[],"kind":"pre"}'
log_docs() {   # log_docs <dir> — r1.md(결정 줄 하나) · r2.md(과거 결정 줄을 고쳐 씀) · r2a.md(엔진처럼 줄을 덧붙임) · r3a.md(한 줄 더)
  with_log "$FX/design-sample.md" "$1/r1.md" "$LOG_L1"
  with_log "$FX/design-sample.md" "$1/r2.md" "$LOG_L1_FORGED"
  with_log "$FX/design-sample.md" "$1/r2a.md" "$LOG_L1" "$LOG_L2"
  with_log "$FX/design-sample.md" "$1/r3a.md" "$LOG_L1" "$LOG_L2" "$LOG_L3"
}
case_AC38_r3_f1_intent_pass_removed() {
  # 3차 지적 1 — fix --event intent-pass 는 check-intent 의 fix 계약(범위 = edit_scope · 실재 · 보호 · 상태)을 거치지 않고 면제를
  # 남기는 뒷문이었다. 호출자가 없으므로 원인을 없앤다 — 이름 있는 거부가 check-intent 를 가리킨다.
  local d err rc; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
  assert_eq "$(_ci 'bbbb0001#r1.1' --intent '#2-goals' --state-dir "$d" | jgets 'd["reason"]')" "scope_outside_edit_scope" "AC38 3차1 전제: check-intent 는 edit_scope 밖 범위를 거부한다"
  err="$(py docreview_state.py fix --state-dir "$d" --id 'bbbb0001#r1.1' --event intent-pass --scope '#2-goals' 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc" "1" "AC38 3차1: fix intent-pass 는 rc 1 로 거부된다"
  assert_contains "$err" '"reason": "intent_pass_removed"' "AC38 3차1: 사유는 intent_pass_removed"
  assert_contains "$err" 'check-intent' "AC38 3차1: 거부가 대신 쓸 명령(check-intent)을 가리킨다"
  assert_eq "$(st_yaml "$d" 'len(st["applied_scopes"])')" "0" "AC38 3차1: 거부는 면제 범위를 남기지 않는다"
  br "$d" "$FX/design-sample-r2.md"
  assert_eq "$(rk_changed "$d" 2)" "(['#12-files-to-modify', '#2-goals'], [])" "AC38 3차1: 다음 라운드의 Goals 고쳐 쓰기는 frozen_change 다"
  rm -rf "$d"
  # 양성 짝 — check-intent 를 통과한 fix 범위는 다음 라운드 면제다
  d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
  assert_eq "$(_ci 'bbbb0001#r1.1' --intent '#12-files-to-modify' --state-dir "$d" | jgets 'd["contract"]')" "fix" "AC38 3차1 양성 짝: 정상 범위는 check-intent 를 통과한다"
  br "$d" "$FX/design-sample-r2.md"
  assert_eq "$(rk_changed "$d" 2)" "(['#2-goals'], [('#12-files-to-modify', '#12-files-to-modify')])" "AC38 3차1 양성 짝: 통과한 범위만 면제다"
  rm -rf "$d"
}
case_AC38_r3_f2_revert_immutable_restored() {
  # 3차 지적 2 — 불변 절(§6)을 원래 글자로 정확히 되돌린 원복이 frozen_change 로 다시 올라오던 회귀. 원복 permit 은 새 해시가
  # 그 permit 의 expect_hash 와 같을 때만(진짜 복원) 울타리 안 절을 면제한다.
  local d h fp third
  for third in restore other; do
    d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC38 3차2: init 실패"; return; }
    br "$d" "$FX/brief-append-r1.md"; br "$d" "$FX/brief-append-r2-edit.md"
    h="$(jget "$d/s1.json" '[s["hash"] for s in d["sections"] if s["anchor"]=="#6-사용자-원문"][0]')"
    fp="${F_POST//#12-files-to-modify/#6-사용자-원문}"; fp="${fp/PREV/$h}"
    seed_findings "$d" "[$fp]"
    py docreview_state.py decide --state-dir "$d" --id 'dddd0001#r2.1' --choice reject --quote '원복하라' >/dev/null
    if [ "$third" = restore ]; then
      br "$d" "$FX/brief-append-r1.md"
      assert_eq "$(rk_changed "$d" 3)" "([], [('#6-사용자-원문', '#6-사용자-원문')])" "AC38 3차2: 원래 글자로 되돌린 §6 은 원복 permit 으로 면제된다(frozen_change 아님)"
      assert_eq "$(py docreview_state.py observe-diff --state-dir "$d" | jgets 'd["applied"]')" "['dddd0001#r2.1']" "AC38 3차2: 원복이 적용으로 관측된다"
    else
      br "$d" "$FX/brief-append-r2.md"
      assert_eq "$(rk_changed "$d" 3)" "(['#6-사용자-원문'], [])" "AC38 3차2 짝: 원래 글자가 아닌 §6 은 원복 permit 이 있어도 frozen_change 다"
    fi
    rm -rf "$d"
  done
}
case_AC38_r3_f3_log_section_fenced() {
  # 3차 지적 3 — 결정 기록 · 미룸 절은 범위(edit_scope · fix 범위 · 신고)로 면제되지 못한다. 기록할 때 이름 있는 거부, 쓸 때 울타리.
  local d err
  # ① decide — 사용자는 #1-context 를 보는데 edit_scope 가 결정 기록이다
  d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 3차3: init 실패"; return; }
  log_docs "$d"; br "$d" "$d/r1.md"
  local f="${F_LOGSCOPE/EDIT_SCOPE/#결정-기록}"; seed_findings "$d" "[${f/DISP/decide}]"
  err="$(py docreview_state.py decide --state-dir "$d" --id 'eeee0001#r1.1' --choice adopt --quote '고친다' 2>&1 >/dev/null)"
  assert_contains "$err" '"why": "anchor_log_section"' "AC38 3차3: 결정 기록을 고칠 범위로 쓴 채택은 permit 을 열지 않는다"
  assert_eq "$(st_yaml "$d" 'len(st["permits"])')" "0" "AC38 3차3: 거부된 채택은 원장을 바꾸지 않는다"
  plant_permit "$d" 'eeee0001#r1.1' '#결정-기록'
  br "$d" "$d/r2.md"
  assert_eq "$(rk_changed "$d" 2)" "(['#결정-기록'], [])" "AC38 3차3: 심어 둔 permit 도 결정 기록 고쳐 쓰기를 면제하지 못한다(쓰는 때의 울타리)"
  rm -rf "$d"
  # ② check-intent fix 계약 — edit_scope 가 결정 기록인 fix
  d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 3차3: init 실패"; return; }
  log_docs "$d"; br "$d" "$d/r1.md"
  seed_findings "$d" "[${f/DISP/fix}]"
  assert_eq "$(_ci 'eeee0001#r1.1' --intent '#결정-기록' --state-dir "$d" | jgets 'd["reason"]')" "anchor_log_section" "AC38 3차3: check-intent 는 결정 기록 범위를 거부한다"
  assert_eq "$(st_yaml "$d" 'len(st["applied_scopes"])')" "0" "AC38 3차3: 거부된 check-intent 는 면제 범위를 남기지 않는다"
  PYTHONPATH="$SCRIPTS" python3 -c 'import sys; from docreview_state import load_state, save_state; d=sys.argv[1]; st=load_state(d); st["applied_scopes"].append({"finding_id":"eeee0001#r1.1","scope":"#결정-기록","round":1}); save_state(d, st, "fixture")' "$d"
  br "$d" "$d/r2.md"
  assert_eq "$(rk_changed "$d" 2)" "(['#결정-기록'], [])" "AC38 3차3: 심어 둔 fix 범위도 결정 기록을 면제하지 못한다"
  rm -rf "$d"
  # ③ declare-related — 결정 기록을 함께 고친 곳으로 신고
  d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 3차3: init 실패"; return; }
  log_docs "$d"; br "$d" "$d/r1.md"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '고친다' >/dev/null
  err="$(py docreview_state.py declare-related --state-dir "$d" --decision D1.1 --anchors '#결정-기록' 2>&1 >/dev/null)"
  assert_contains "$err" '"reason": "anchor_log_section"' "AC38 3차3: 결정 기록은 신고로 묶지 못한다"
  err="$(py docreview_state.py declare-related --state-dir "$d" --decision D1.1 --anchors 'insert-after:#결정-기록' 2>&1 >/dev/null)"
  assert_contains "$err" '"reason": "anchor_log_section"' "AC38 3차3: 결정 기록 뒤에 끼우는 신고도 거부"
  assert_eq "$(py docreview_state.py declare-related --state-dir "$d" --decision D1.1 --anchors '#2-goals' | jgets 'd["ok"]')" "True" "AC38 3차3 양성 짝: 울타리 밖 절의 신고는 받는다"
  plant_permit "$d" 'aaaa0001#r1.1' '#12-files-to-modify' '#결정-기록'
  br "$d" "$d/r2.md"
  assert_eq "$(rk_changed "$d" 2)" "(['#결정-기록'], [])" "AC38 3차3: 심어 둔 신고도 결정 기록을 면제하지 못한다"
  rm -rf "$d"
  # ④ 꼬리 — 결정 기록에 심은 apply permit 은 엔진의 덧붙이기(append-only 면제)로 «적용됨» 이 되지 않는다
  d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 3차3: init 실패"; return; }
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1"; br "$d" "$d/doc.md"; seed_findings "$d" "[${f/DISP/decide}]"
  plant_permit "$d" 'eeee0001#r1.1' '#결정-기록'
  eng_log "$d" bbbb0007; br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 2)" "([], [('#결정-기록', 'append-only')])" "AC38 3차3 꼬리 전제: 엔진이 덧붙인 줄은 append-only 로 지나간다"
  assert_eq "$(py docreview_state.py observe-diff --state-dir "$d" | jgets 'd["applied"]')" "[]" "AC38 3차3 꼬리: 덧붙이기 면제는 permit 의 적용 증거가 아니다"
  rm -rf "$d"
}
case_AC38_r3_f3_positive_controls() {
  # 양성 짝 — 엔진이 결정 기록에 덧붙이는 정상 경로(절을 만드는 라운드 포함 1~3 라운드)와 울타리 밖 절의 permit 은 그대로 면제된다
  # [4차] 엔진이 실제로 쓴 줄로 잰다 — 작성자가 지어낸 줄은 4차부터 지나가지 못한다(case_AC38_r4_B_fake_log_lines)
  local d; d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 3차3 양성: init 실패"; return; }
  br "$d" "$d/doc.md"; eng_log "$d" bbbb0008; br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 2)" "([], [('#결정-기록', '#결정-기록')])" "AC38 3차3 양성 짝: 엔진이 결정 기록 절을 만드는 라운드는 면제"
  eng_log "$d" bbbb0009; br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 3)" "([], [('#결정-기록', 'append-only')])" "AC38 3차3 양성 짝: 다음 라운드에 엔진이 덧붙인 줄은 append-only"
  rm -rf "$d"
  d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 3차3 양성: init 실패"; return; }
  log_docs "$d"; br "$d" "$d/r1.md"
  local f="${F_LOGSCOPE/EDIT_SCOPE/#1-context}"; seed_findings "$d" "[${f/DISP/decide}]"
  assert_eq "$(py docreview_state.py decide --state-dir "$d" --id 'eeee0001#r1.1' --choice adopt --quote '고친다' | jgets 'd["permit"]["apply_anchors"]')" "['#1-context']" "AC38 3차3 양성 짝: 울타리 밖 edit_scope 의 채택은 permit 을 연다"
  python3 -I -c 'import sys; t=open(sys.argv[1],encoding="utf-8").read(); open(sys.argv[2],"w",encoding="utf-8").write(t.replace("배경 한 문단.", "배경을 고쳐 쓴 문단."))' "$d/r1.md" "$d/r2c.md"
  br "$d" "$d/r2c.md"
  assert_eq "$(rk_changed "$d" 2)" "([], [('#1-context', '#1-context')])" "AC38 3차3 양성 짝: 울타리 밖 permit 앵커의 변경은 면제"
  assert_eq "$(py docreview_state.py observe-diff --state-dir "$d" | jgets 'd["applied"]')" "['eeee0001#r1.1']" "AC38 3차3 양성 짝: 울타리 밖 절의 실제 변경은 적용으로 관측된다"
  rm -rf "$d"
}
case_AC38_r3_f4_headingless_transition() {
  # 3차 지적 4 — 문서를 코드 펜스로 감싸 머리 없는 라운드를 만들면 그 앞뒤 diff 가 통째로 #__doc__ 면제였다. 둘 다 머리 없을 때만
  # 통째 면제이고, 머리 있음 ↔ 없음 전이에서는 머리 있는 쪽의 울타리 절이 changed 에 든다.
  local d; d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC38 3차4: init 실패"; return; }
  python3 -I -c 'import sys; t=open(sys.argv[1],encoding="utf-8").read(); open(sys.argv[2],"w",encoding="utf-8").write("```\n"+t+"```\n")' "$FX/brief-append-r2-edit.md" "$d/fenced.md"
  br "$d" "$FX/brief-append-r1.md"; br "$d" "$d/fenced.md"
  assert_eq "$(st_yaml "$d" 'st["snapshots"]["2"]["headingless"]')" "True" "AC38 3차4 전제: 펜스로 감싼 라운드는 머리 없는 스냅숏이다"
  assert_eq "$(rk_changed "$d" 2 | jgets_py 'd[0]')" "['#6-사용자-원문']" "AC38 3차4: 머리 있음 → 없음 전이에서 사라진 §6 은 frozen_change"
  br "$d" "$FX/brief-append-r2-edit.md"
  assert_eq "$(rk_changed "$d" 3 | jgets_py 'd[0]')" "['#6-사용자-원문']" "AC38 3차4: 머리 없음 → 있음 전이에서 고쳐 쓴 채 돌아온 §6 도 frozen_change"
  rm -rf "$d"
  d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC38 3차4: init 실패"; return; }
  python3 -I -c 'import sys; t=open(sys.argv[1],encoding="utf-8").read(); open(sys.argv[2],"w",encoding="utf-8").write("```\n"+t)' "$FX/brief-append-r2-edit.md" "$d/unclosed.md"
  br "$d" "$FX/brief-append-r1.md"; br "$d" "$d/unclosed.md"
  assert_eq "$(rk_changed "$d" 2 | jgets_py 'd[0]')" "['#6-사용자-원문']" "AC38 3차4: 닫히지 않은 펜스 하나로 만든 머리 없는 라운드도 같다"
  rm -rf "$d"
  # 양성 짝 — 두 라운드 다 머리 없으면 그대로 통째 면제(#__doc__)
  d="$(mk_state "$FX/headingless.md" "$PROF_SD/brief.md")" || { no "AC38 3차4: init 실패"; return; }
  br "$d" "$FX/headingless.md"; br "$d" "$FX/headingless-r2.md"
  assert_eq "$(rk_changed "$d" 2)" "([], [('#__doc__', '#__doc__')])" "AC38 3차4 양성 짝: 둘 다 머리 없는 라운드는 #__doc__ 로 통째 면제"
  rm -rf "$d"
}
jgets_py() { python3 -I -c 'import ast,sys; d=ast.literal_eval(sys.stdin.read()); print(eval(sys.argv[1]))' "$1"; }
case_AC38_r3_f5_gate_adopt_unavailable() {
  # 3차 지적 5 — decide 가 거부할 채택을 게이트가 고를 수 있는 것처럼 내던 틈. 「고친다(채택)」를 빼고 이유를 한 줄로 보인다.
  local d r; d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC38 3차5: init 실패"; return; }
  br "$d" "$FX/brief-append-r1.md"; seed_findings "$d" "[${F_BRIEF_NOIMM/EDIT_SCOPE/#6-사용자-원문}]"
  r="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_contains "$r" "고친다(채택)는 고를 수 없다" "AC38 3차5: 게이트가 채택을 고를 수 없다고 말한다"
  assert_contains "$r" "사용자 원문" "AC38 3차5: 이유를 쉬운 말로 — 바꾸면 안 되는 사용자 원문 절"
  assert_eq "$(printf '%s\n' "$r" | grep '^  대안:' | grep -c '고친다(채택)')" "0" "AC38 3차5: 「대안:」 줄에 채택이 없다(제안 = 수용)"
  local err; err="$(py docreview_state.py decide --state-dir "$d" --id 'eeee0001#r1.1' --choice adopt --quote '고친다' 2>&1 >/dev/null)"
  assert_contains "$err" '"reason": "edit_scope_refused"' "AC38 3차5: 그래도 채택을 보내면 같은 사유로 거부"
  assert_eq "$(py docreview_state.py decide --state-dir "$d" --id 'eeee0001#r1.1' --choice reject --quote '그대로' | jgets 'd["state"]')" "rejected" "AC38 3차5: 남은 선택지(기각)는 그대로 받는다"
  rm -rf "$d"
  # 결정 기록을 고칠 범위로 쓴 decide — 이유가 결정 기록이라고 말한다
  d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 3차5: init 실패"; return; }
  log_docs "$d"; br "$d" "$d/r1.md"
  local f="${F_LOGSCOPE/EDIT_SCOPE/#결정-기록}"; seed_findings "$d" "[${f/DISP/decide}]"
  r="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_contains "$r" "고친다(채택)는 고를 수 없다 — 고칠 범위가 결정 기록" "AC38 3차5: 결정 기록 범위는 그 이유로 보인다"
  rm -rf "$d"
  # 양성 짝 — 정상 범위의 decide 는 채택을 그대로 고를 수 있다
  d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC38 3차5: init 실패"; return; }
  br "$d" "$FX/brief-append-r1.md"; seed_findings "$d" "[${F_BRIEF_NOIMM/EDIT_SCOPE/#2-확정}]"
  r="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_eq "$(printf '%s\n' "$r" | grep '^  대안:' | grep -c '고친다(채택)')" "1" "AC38 3차5 양성 짝: 정상 범위는 「대안:」 에 채택이 있다"
  assert_not_contains "$r" "고를 수 없다" "AC38 3차5 양성 짝: 정상 범위엔 그 줄이 없다"
  rm -rf "$d"
}
case_AC38_r3_f6_legacy_ledger_disclosed() {
  # 3차 지적 6 — 이 변경 전에 진행 중이던 원장은 결정 기록 절의 줄 해시가 없다. 그 첫 라운드는 옛 절 면제를 한 번 쓰고 게이트에 공시한다.
  local d r; d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 3차6: init 실패"; return; }
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1"; br "$d" "$d/doc.md"
  # 옛 원장 — 결정 기록 절의 줄 해시도, 엔진 줄 기록(4차)도 없다
  PYTHONPATH="$SCRIPTS" python3 -c 'import sys; from docreview_state import load_state, save_state; d=sys.argv[1]; st=load_state(d); [s.pop("line_hashes", None) for s in st["snapshots"]["1"]["sections"]]; st.pop("engine_lines", None); st.pop("engine_lines_since", None); save_state(d, st, "fixture: 옛 원장")' "$d"
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1" "$LOG_L2"; eng_log "$d" bbbb000a; br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 2)" "([], [('#결정-기록', '#결정-기록')])" "AC38 3차6: 옛 원장의 첫 라운드는 엔진의 덧붙이기를 frozen_change 로 올리지 않는다"
  r="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_contains "$r" "덧붙이기만 됐는지 이번 라운드는 확인하지 못했다" "AC38 3차6: 확인하지 못했다는 사실을 게이트에 공시한다"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["log_check_skipped"]')" "['#결정-기록']" "AC38 3차6: gate JSON 이 건너뛴 절을 싣는다"
  eng_log "$d" bbbb000b; br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 3)" "([], [('#결정-기록', 'append-only')])" "AC38 3차6: 다음 라운드부터는 줄 출처 규칙이 다시 선다(엔진 줄은 append-only)"
  assert_not_contains "$(py docreview_state.py gate --state-dir "$d" --render)" "확인하지 못했다" "AC38 3차6: 한 번뿐 — 다음 라운드엔 공시가 없다"
  rm -rf "$d"
}
case_AC38_r3_f7_invisible_blank_quote() {
  # 3차 지적 7 — 보이지 않는 글자(폭 없는 공백 등)뿐인 추가 승인은 승인이 아니다
  local d s err v rc; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; snap "$FX/design-sample.md" "$d/s2.json"
  for v in "$(python3 -I -c 'print("​", end="")')" "$(python3 -I -c 'print("﻿⁠", end="")')" "$(python3 -I -c 'print("​ 　‌", end="")')"; do
    err=""; put_snap "$d" "$d/s2.json" && err="$(py docreview_state.py begin-round --state-dir "$d" --extra-approval "$v" --extra-approval-source typed 2>&1 >/dev/null)"; rc=$?
    assert_eq "$rc" "2" "AC38 3차7: 보이지 않는 글자뿐인 추가 승인은 rc 2"
    assert_contains "$err" '"reason": "extra_approval_blank"' "AC38 3차7: 사유는 extra_approval_blank"
  done
  put_snap "$d" "$d/s2.json" && assert_eq "$(py docreview_state.py begin-round --state-dir "$d" --extra-approval '열기' --extra-approval-source typed | jgets 'd["ok"]')" "True" "AC38 3차7 양성 짝: 보이는 글자가 있는 승인은 받는다"
  rm -rf "$d"
}
# ── AC38 4차 — 결정 기록 · 미룸 절의 줄 출처: 엔진이 쓴 줄만 지나간다 ─────────────────────────
mk_doc_state() {   # mk_doc_state <src-doc> <profile> → state dir. 문서는 그 안의 doc.md 다(원장의 문서 = 엔진이 줄을 쓰는 문서)
  local d; d="$(mktemp -d -t docreview-XXXXXX)" || return 1
  cp "$1" "$d/doc.md"
  py docreview_state.py init --state-dir "$d" --doc "$d/doc.md" --profile "$2" >/dev/null || { echo "$d"; return 1; }
  echo "$d"
}
eng_log() {   # eng_log <state-dir> <id8> — 결정 하나를 심고 기각해 엔진이 doc.md 의 결정 기록에 줄을 쓴다
  seed_findings "$1" "[${F_DEC//aaaa0001/$2}]"
  py docreview_state.py decide --state-dir "$1" --id "$2#r1.1" --choice reject --quote '엔진 줄' --log-file "$1/doc.md" >/dev/null
}
doc_sub() {   # doc_sub <file> <old> <new> — 제자리 글자 바꾸기
  python3 -I -c 'import sys; p=sys.argv[1]; t=open(p,encoding="utf-8").read(); assert sys.argv[2] in t; open(p,"w",encoding="utf-8").write(t.replace(sys.argv[2], sys.argv[3]))' "$@"
}
doc_append() {   # doc_append <file> <line> — 파일 끝(마지막 절)에 작성자가 줄 하나를 붙인다
  python3 -I -c 'import sys; p=sys.argv[1]; t=open(p,encoding="utf-8").read(); open(p,"w",encoding="utf-8").write(t.rstrip("\n")+"\n"+sys.argv[2]+"\n")' "$@"
}
LOG_FAKE='- D3.1 · r3 · adopt · F2 · "사용자가 좋다고 했다" — 지어낸 줄'
case_AC38_r4_A_log_revert_keeps_engine_lines() {
  # 4차 A — 고쳐 쓴 결정 기록의 원복. 엔진이 그 사이 쓴 줄(기각 줄 등)을 지키는 원복만 원복이다 — 절을 통째로 옛 글자로
  # 되돌려 엔진 줄을 지우는 것은 원복이 아니라 다시 frozen_change 다.
  local d h fp mode
  for mode in honest destructive; do
    d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 4차A: init 실패"; return; }
    with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1"; cp "$d/doc.md" "$d/orig.md"
    br "$d" "$d/doc.md"
    doc_sub "$d/doc.md" "$LOG_L1" "$LOG_L1_FORGED"; br "$d" "$d/doc.md"
    assert_eq "$(rk_changed "$d" 2 | jgets_py 'd[0]')" "['#결정-기록']" "AC38 4차A 전제: 과거 결정 줄 고쳐 쓰기는 frozen_change"
    h="$(jget "$d/s1.json" '[s["hash"] for s in d["sections"] if s["anchor"]=="#결정-기록"][0]')"
    fp="${F_POST//#12-files-to-modify/#결정-기록}"; seed_findings "$d" "[${fp/PREV/$h}]"
    py docreview_state.py decide --state-dir "$d" --id 'dddd0001#r2.1' --choice reject --quote '원복하라' --log-file "$d/doc.md" >/dev/null
    if [ "$mode" = honest ]; then
      doc_sub "$d/doc.md" "$LOG_L1_FORGED" "$LOG_L1"; br "$d" "$d/doc.md"
      assert_eq "$(rk_changed "$d" 3)" "([], [('#결정-기록', '#결정-기록')])" "AC38 4차A: 고친 줄만 되돌리고 엔진 줄은 둔 원복은 면제"
      assert_eq "$(py docreview_state.py observe-diff --state-dir "$d" | jgets 'd["applied"]')" "['dddd0001#r2.1']" "AC38 4차A: 그 원복이 적용으로 관측된다(면제와 관측이 같은 판정)"
    else
      cp "$d/orig.md" "$d/doc.md"; br "$d" "$d/doc.md"
      assert_eq "$(rk_changed "$d" 3)" "(['#결정-기록'], [])" "AC38 4차A: 엔진이 쓴 기각 줄까지 지우는 통째 복원은 frozen_change"
      assert_eq "$(py docreview_state.py observe-diff --state-dir "$d" | jgets 'd["expired"]')" "['dddd0001#r2.1']" "AC38 4차A: 통째 복원은 원복 적용이 아니다"
    fi
    rm -rf "$d"
  done
}
case_AC38_r4_B_fake_log_lines() {
  # 4차 B — 엔진이 쓰지 않은 줄을 결정 기록 · 미룸 표에 덧붙이거나, 그런 줄로 절을 만들면 frozen_change
  local d
  d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 4차B: init 실패"; return; }
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1"; br "$d" "$d/doc.md"
  doc_append "$d/doc.md" "$LOG_FAKE"; br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 2)" "(['#결정-기록'], [])" "AC38 4차B: 작성자가 덧붙인 지어낸 결정 줄은 frozen_change"
  rm -rf "$d"
  d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 4차B: init 실패"; return; }
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1"; br "$d" "$d/doc.md"
  eng_log "$d" bbbb0002; br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 2)" "([], [('#결정-기록', 'append-only')])" "AC38 4차B 양성 짝: 엔진이 덧붙인 결정 줄은 append-only"
  rm -rf "$d"
  d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 4차B: init 실패"; return; }
  br "$d" "$d/doc.md"; doc_append "$d/doc.md" '| cccc0002#r1.1 | 지어낸 미룸 |'; br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 2)" "(['#deferred-to-plan'], [])" "AC38 4차B: 작성자가 덧붙인 미룸 행은 frozen_change"
  rm -rf "$d"
  d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 4차B: init 실패"; return; }
  br "$d" "$d/doc.md"
  local fd="${F_FIX//bbbb0001/cccc0002}"; seed_findings "$d" "[${fd/\"disposition\":\"fix\"/\"disposition\":\"defer\"}]"
  py docreview_state.py defer --state-dir "$d" --id 'cccc0002#r1.1' --log-file "$d/doc.md" >/dev/null
  br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 2)" "([], [('#deferred-to-plan', 'append-only')])" "AC38 4차B 양성 짝: 엔진이 덧붙인 미룸 행은 append-only"
  rm -rf "$d"
  d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 4차B: init 실패"; return; }
  br "$d" "$d/doc.md"; with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_FAKE"; br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 2)" "(['#결정-기록'], [])" "AC38 4차B: 지어낸 줄로 결정 기록 절을 처음 만들면 frozen_change"
  rm -rf "$d"
}
case_AC38_r4_C_log_recreated() {
  # 4차 C — 결정 기록 절이 이 원장의 앞 스냅숏 어디엔가 있었으면 «처음 만드는 라운드» 가 아니다(펜스 전이 · 지웠다 다시 만들기)
  local d
  d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 4차C: init 실패"; return; }
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1"; br "$d" "$d/doc.md"
  python3 -I -c 'import sys; p=sys.argv[1]; t=open(p,encoding="utf-8").read(); open(p,"w",encoding="utf-8").write("```\n"+t+"```\n")' "$d/doc.md"
  br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 2 | jgets_py '"#결정-기록" in d[0]')" "True" "AC38 4차C 전제: 펜스로 감싼 라운드에 결정 기록이 사라짐은 frozen_change"
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1_FORGED"; br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 3 | jgets_py '"#결정-기록" in d[0]')" "True" "AC38 4차C: 펜스를 풀며 과거 결정 줄을 고쳐 쓴 결정 기록은 frozen_change(만드는 라운드 아님)"
  rm -rf "$d"
  d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 4차C: init 실패"; return; }
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1"; br "$d" "$d/doc.md"
  cp "$FX/design-sample.md" "$d/doc.md"; br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 2)" "(['#결정-기록'], [])" "AC38 4차C 전제: 결정 기록 절을 지우면 frozen_change"
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1_FORGED"; br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 3)" "(['#결정-기록'], [])" "AC38 4차C: 지웠다 고쳐 쓴 줄로 다시 만든 결정 기록은 frozen_change"
  rm -rf "$d"
  d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 4차C: init 실패"; return; }
  br "$d" "$d/doc.md"; eng_log "$d" cccc0003; br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 2)" "([], [('#결정-기록', '#결정-기록')])" "AC38 4차C 양성 짝: 엔진이 결정 기록 절을 처음 만든 라운드는 면제"
  eng_log "$d" cccc0004; br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 3)" "([], [('#결정-기록', 'append-only')])" "AC38 4차C 양성 짝: 다음 라운드 엔진 줄은 append-only"
  rm -rf "$d"
}
case_AC38_r4_m3_invisible_letters() {
  # 4차 m3 — 글자 부류로는 문자지만 보이지 않는 것(한글 채움 문자 · 점자 빈칸 · 결합 자소 결합자)뿐인 추가 승인도 승인이 아니다
  local d err rc v; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; snap "$FX/design-sample.md" "$d/s2.json"
  for v in 3164 115F 1160 2800 034F FFA0; do
    err=""; put_snap "$d" "$d/s2.json" && err="$(py docreview_state.py begin-round --state-dir "$d" --extra-approval "$(python3 -I -c 'import sys; print(chr(int(sys.argv[1], 16)), end="")' "$v")" --extra-approval-source typed 2>&1 >/dev/null)"; rc=$?
    assert_eq "$rc" "2" "AC38 4차m3: U+${v} 뿐인 추가 승인은 rc 2"
  done
  put_snap "$d" "$d/s2.json" && assert_eq "$(py docreview_state.py begin-round --state-dir "$d" --extra-approval "$(python3 -I -c 'print(chr(0x3164) + "열기", end="")')" --extra-approval-source typed | jgets 'd["ok"]')" "True" "AC38 4차m3 양성 짝: 보이는 글자가 섞이면 받는다"
  rm -rf "$d"
}
revert_target_flagged_state() {   # → state dir: 라운드 2 와 3 에 #12 가 연달아 허가 없이 바뀌고 사후 결정 둘이 열려 있다
  local d h1 h2 p2; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null
  h1="$(jget "$d/s1.json" '[s["hash"] for s in d["sections"] if s["anchor"]=="#12-files-to-modify"][0]')"
  seed_findings "$d" "[${F_POST/PREV/$h1}]"
  python3 -I -c 'import sys; t=open(sys.argv[1],encoding="utf-8").read(); assert "## Handoff Context" in t; open(sys.argv[2],"w",encoding="utf-8").write(t.replace("## Handoff Context", "- `z.py`\n\n## Handoff Context"))' "$FX/design-sample-r2.md" "$d/r3.md"
  next_round "$d" "$d/r3.md" >/dev/null
  h2="$(jget "$d/s2.json" '[s["hash"] for s in d["sections"] if s["anchor"]=="#12-files-to-modify"][0]')"
  p2="${F_POST//dddd0001/dddd0002}"; seed_findings "$d" "[${p2/PREV/$h2}]"
  echo "$d"
}
case_AC38_r4_m1_revert_target_flagged() {
  # 4차 m1 — 사후 결정의 「이전 상태로 원복」이 돌아갈 글이 앞 라운드에 허가 없이 바뀐 글이면 게이트가 쉬운 말로 알린다
  local d r; d="$(revert_target_flagged_state)"
  r="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_contains "$r" "원복하면 원래 글이 아니라 라운드 2 에 허가 없이 바뀐 글로 돌아간다 — 그 변경은 아직 받아들여지지 않았다 (dddd0001#r2.1)" "AC38 4차m1: 둘째 사후 결정의 원복 대상이 앞 라운드의 허가 없는 변경임을 알린다"
  assert_eq "$(printf '%s\n' "$r" | grep -c '원복하면 원래 글이 아니라')" "1" "AC38 4차m1 양성 짝: 원래 글로 돌아가는 첫 사후 결정에는 그 줄이 없다"
  py docreview_state.py decide --state-dir "$d" --id 'dddd0001#r2.1' --choice adopt --quote '이 변경 승인' >/dev/null
  assert_not_contains "$(py docreview_state.py gate --state-dir "$d" --render)" "원복하면 원래 글이 아니라" "AC38 4차m1 양성 짝: 앞 변경을 사용자가 받아들였으면 알리지 않는다"
  rm -rf "$d"
}
snap_edit() {   # snap_edit <snapshot.json> <python-stmt over d> — 스냅숏을 고쳐 쓴다(위조 흉내)
  python3 -I -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p,encoding="utf-8")); exec(sys.argv[2]); json.dump(d, open(p,"w",encoding="utf-8"), ensure_ascii=False)' "$1" "$2"
}
snap_problem() {   # snap_problem <state-dir> <snapshot.json> → 그 원장의 다음 라운드에서 snapshot_problem 이 내는 답(repr)
  PYTHONPATH="$SCRIPTS" python3 "$FX/st_get.py" "$1/docreview-state.md" '(lambda S, P: S.snapshot_problem(__import__("json").load(open(sys.argv[3], encoding="utf-8")), P, immutable_lineage=S.lineage_anchors(st, P, "immutable", int(st["round"]))))(__import__("docreview_state"), __import__("docreview_state").load_profile(st["profile"]))' "$2"
}
case_AC38_r4_snapshot_fields_cannot_switch_guards_off() {
  # 4차 덧붙임 — 라운드 스냅숏이 울타리 절의 줄 해시를 잃거나 머리 없음 표지를 거짓으로 달아 가드를 끄는 모양이면
  # `snapshot_problem` 이 거절한다(begin-round 는 원장을 바꾸기 전에 그 판정으로 멈춘다). 옛 원장 판정은 스냅숏 하나가
  # 아니라 원장의 사실(엔진 줄 기록)로 한다.
  local d
  d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 4차+: init 실패"; return; }
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1"; br "$d" "$d/doc.md"
  snap "$d/doc.md" "$d/s2.json"
  snap_edit "$d/s2.json" '[s.pop("line_hashes", None) for s in d["sections"] if s["anchor"] == "#결정-기록"]'
  assert_eq "$(snap_problem "$d" "$d/s2.json")" "('fence_line_hashes_missing', ['#결정-기록'])" "AC38 4차+: 결정 기록 절의 줄 해시를 뗀 스냅숏은 snapshot_problem 이 거절한다"
  # 원장에 줄 해시 없는 스냅숏이 들어 있어도(손으로 심은 위조) 출처 기록이 있는 원장은 옛 원장 면제를 주지 않는다
  PYTHONPATH="$SCRIPTS" python3 -c 'import sys; from docreview_state import load_state, save_state; d=sys.argv[1]; st=load_state(d); [s.pop("line_hashes", None) for s in st["snapshots"]["1"]["sections"]]; save_state(d, st, "fixture: 위조")' "$d"
  doc_sub "$d/doc.md" "$LOG_L1" "$LOG_L1_FORGED"; br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 2)" "(['#결정-기록'], [])" "AC38 4차+: 줄 해시 없는 스냅숏 하나로는 옛 원장 면제가 열리지 않는다 — 고쳐 쓴 결정 기록은 frozen_change"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["log_check_skipped"]')" "[]" "AC38 4차+: 공시할 옛 원장 넘기기도 없다"
  rm -rf "$d"
  # 불변 절(§6)의 줄 해시를 뗀 스냅숏 · 머리가 있는데 머리 없음이라고 단 스냅숏도 받지 않는다
  d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC38 4차+: init 실패"; return; }
  snap "$FX/brief-append-r1.md" "$d/s1.json"
  snap_edit "$d/s1.json" '[s.pop("line_hashes", None) for s in d["sections"] if s["anchor"] == "#6-사용자-원문"]'
  assert_eq "$(snap_problem "$d" "$d/s1.json")" "('fence_line_hashes_missing', ['#6-사용자-원문'])" "AC38 4차+: 불변 절의 줄 해시를 뗀 스냅숏은 거절"
  snap "$FX/brief-append-r1.md" "$d/s1.json"; snap_edit "$d/s1.json" 'd["headingless"] = True'
  assert_contains "$(snap_problem "$d" "$d/s1.json")" "('headingless_mismatch', [" "AC38 4차+: 머리가 있는 절들에 머리 없음 표지를 단 스냅숏은 거절"
  snap "$FX/brief-append-r2-edit.md" "$d/s2.json"; snap_edit "$d/s2.json" 'd["headingless"] = True'
  assert_contains "$(snap_problem "$d" "$d/s2.json")" "('headingless_mismatch', [" "AC38 4차+: 거짓 머리 없음 표지 두 라운드로 §6 고쳐 쓰기를 통째 면제받는 길이 없다(둘째도 거절)"
  snap "$FX/brief-append-r1.md" "$d/s1.json"
  assert_eq "$(snap_problem "$d" "$d/s1.json")" "None" "AC38 4차+ 양성 짝: 도구가 낸 그대로의 스냅숏은 문제없다"
  rm -rf "$d"
  # 양성 짝 — 도구가 낸 그대로의 스냅숏(머리 없는 문서 포함)은 받는다
  d="$(mk_state "$FX/headingless.md" "$PROF_SD/brief.md")" || { no "AC38 4차+: init 실패"; return; }
  br "$d" "$FX/headingless.md"
  assert_eq "$(st_yaml "$d" 'st["round"]')" "1" "AC38 4차+ 양성 짝: 머리 없는 문서의 정상 스냅숏은 받는다"
  rm -rf "$d"
}
# ── AC38 5차 ─────────────────────────────────────────────────────────────────────────
log_added_then_rejected() {   # log_added_then_rejected <log-file-flag:yes|no> → state dir: 라운드 2 에 작성자가 지어낸 결정 기록 절을
  # 만들고(사후 결정, prev_hash 없음) 사용자가 기각했다. yes 면 그 기각 줄을 엔진이 그 절에 썼다.
  local d fp; d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || return 1
  br "$d" "$d/doc.md"; with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_FAKE"; br "$d" "$d/doc.md"
  fp="${F_POST//#12-files-to-modify/#결정-기록}"; fp="${fp/\"prev_hash\":\"PREV\"/\"prev_hash\":null}"; seed_findings "$d" "[$fp]"
  if [ "$1" = yes ]; then
    py docreview_state.py decide --state-dir "$d" --id 'dddd0001#r2.1' --choice reject --quote '원복하라' --log-file "$d/doc.md" >/dev/null
  else
    py docreview_state.py decide --state-dir "$d" --id 'dddd0001#r2.1' --choice reject --quote '원복하라' >/dev/null
  fi
  cp "$FX/design-sample.md" "$d/doc.md"; br "$d" "$d/doc.md"   # 라운드 3 — 절을 통째로 지운다
  echo "$d"
}
case_AC38_r5_1_revert_to_absence_keeps_engine_lines() {
  # 5차 1 — 없던 절로 되돌리는 원복도 엔진이 그 절에 쓴 줄(기각 줄)을 지우면 원복이 아니다
  local d; d="$(log_added_then_rejected yes)" || { no "AC38 5차1: 준비 실패"; return; }
  assert_eq "$(rk_changed "$d" 3)" "(['#결정-기록'], [])" "AC38 5차1: 엔진의 기각 줄째 절을 지운 «원복» 은 frozen_change"
  assert_eq "$(py docreview_state.py observe-diff --state-dir "$d" | jgets 'd["applied"], d["expired"]')" "([], ['dddd0001#r2.1'])" "AC38 5차1: 그 «원복» 은 적용으로 관측되지 않는다"
  rm -rf "$d"
  d="$(log_added_then_rejected no)" || { no "AC38 5차1: 준비 실패"; return; }
  assert_eq "$(rk_changed "$d" 3)" "([], [('#결정-기록', '#결정-기록')])" "AC38 5차1 양성 짝: 엔진 줄이 없는 절을 지운 원복은 면제"
  assert_eq "$(py docreview_state.py observe-diff --state-dir "$d" | jgets 'd["applied"]')" "['dddd0001#r2.1']" "AC38 5차1 양성 짝: 그 원복은 적용으로 관측된다"
  rm -rf "$d"
}
case_AC38_r5_2_window_upper_bound() {
  # 5차 2 — 판정하는 스냅숏 «뒤에» 엔진이 쓴 줄은 그 스냅숏에 있을 수 없다. 같은 라운드 다시 계산 · 늦은 관측이 거짓으로 뒤집히지 않는다.
  local d h fp
  d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 5차2: init 실패"; return; }
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1"; br "$d" "$d/doc.md"
  eng_log "$d" bbbb0010; br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 2)" "([], [('#결정-기록', 'append-only')])" "AC38 5차2 전제: 라운드 2 의 엔진 덧붙이기는 append-only"
  eng_log "$d" bbbb0011   # 라운드 2 게이트의 decide --log-file — 스냅숏 2 뒤에 쓴 줄
  assert_eq "$(rk_changed "$d" 2)" "([], [('#결정-기록', 'append-only')])" "AC38 5차2: 같은 라운드에 다시 계산해도(재-finalize) 스냅숏 뒤에 쓴 엔진 줄 때문에 frozen_change 가 되지 않는다"
  rm -rf "$d"
  # 늦은 관측 — 정직한 원복(라운드 3) 뒤 라운드 3 에 엔진이 줄을 더 쓰고 라운드 4 에야 관측한다
  d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 5차2: init 실패"; return; }
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1"; br "$d" "$d/doc.md"
  doc_sub "$d/doc.md" "$LOG_L1" "$LOG_L1_FORGED"; br "$d" "$d/doc.md"
  h="$(jget "$d/s1.json" '[s["hash"] for s in d["sections"] if s["anchor"]=="#결정-기록"][0]')"
  fp="${F_POST//#12-files-to-modify/#결정-기록}"; seed_findings "$d" "[${fp/PREV/$h}]"
  py docreview_state.py decide --state-dir "$d" --id 'dddd0001#r2.1' --choice reject --quote '원복하라' --log-file "$d/doc.md" >/dev/null
  doc_sub "$d/doc.md" "$LOG_L1_FORGED" "$LOG_L1"; br "$d" "$d/doc.md"
  eng_log "$d" bbbb0012; br "$d" "$d/doc.md"
  assert_eq "$(py docreview_state.py observe-diff --state-dir "$d" | jgets 'd["applied"]')" "['dddd0001#r2.1']" "AC38 5차2: 라운드 4 에 따라잡은 정직한 원복은 그 뒤 엔진 줄 때문에 만료로 뒤집히지 않는다"
  rm -rf "$d"
}
case_AC38_r5_3_since_corrupt_and_legacy_once() {
  # 5차 3 — 엔진 줄 기록 시작 라운드가 정수가 아니거나 현재 라운드보다 크면 원장 파손(이름 있는 실패), 옛 원장 넘기기는 그 라운드 한 번뿐
  local d v err
  for v in '"1"' 'True' '99'; do
    d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 5차3: init 실패"; return; }
    with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1"; br "$d" "$d/doc.md"; br "$d" "$d/doc.md"
    PYTHONPATH="$SCRIPTS" python3 -c 'import sys; from docreview_state import load_state, save_state; d=sys.argv[1]; st=load_state(d); st["engine_lines_since"]=eval(sys.argv[2]); save_state(d, st, "fixture")' "$d" "$v"
    err="$(py docreview_state.py exempt-anchors --state-dir "$d" 2>&1 >/dev/null)"
    assert_contains "$err" '"reason": "engine_lines_since_corrupt"' "AC38 5차3: engine_lines_since=${v} 는 원장 파손으로 멈춘다"
    rm -rf "$d"
  done
  # 기록 시작(라운드 3)보다 앞 라운드의 diff 는 옛 원장 넘기기를 받지 않는다(그 라운드 한 번만)
  d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 5차3: init 실패"; return; }
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1"; br "$d" "$d/doc.md"
  doc_append "$d/doc.md" "$LOG_FAKE"; br "$d" "$d/doc.md"; br "$d" "$d/doc.md"
  PYTHONPATH="$SCRIPTS" python3 -c 'import sys; from docreview_state import load_state, save_state; d=sys.argv[1]; st=load_state(d); st["engine_lines_since"]=3; save_state(d, st, "fixture")' "$d"
  assert_eq "$(rk_changed "$d" 2)" "(['#결정-기록'], [])" "AC38 5차3: 기록 시작 전 라운드의 지어낸 줄은 옛 원장 넘기기를 받지 않는다"
  rm -rf "$d"
}
case_AC38_r5_4_duplicate_engine_line() {
  # 5차 4 — 엔진이 한 번 쓴 줄을 작성자가 한 번 더 붙이면 엔진 줄이 아니다(개수로 잰다)
  local d; d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC38 5차4: init 실패"; return; }
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1"; br "$d" "$d/doc.md"
  eng_log "$d" bbbb0013; doc_append "$d/doc.md" "$(tail -1 "$d/doc.md")"; br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 2)" "(['#결정-기록'], [])" "AC38 5차4: 엔진 줄을 한 번 더 베껴 붙인 결정 기록은 frozen_change"
  rm -rf "$d"
}
case_AC38_r5_5_combining_only_blank() {
  # 5차 5 — 변형 선택자 · 결합 부호뿐인 추가 승인도 승인이 아니다
  local d rc v; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; snap "$FX/design-sample.md" "$d/s2.json"
  for v in FE0F E0100 0301 20DD; do
    put_snap "$d" "$d/s2.json" && py docreview_state.py begin-round --state-dir "$d" --extra-approval "$(python3 -I -c 'import sys; print(chr(int(sys.argv[1], 16)), end="")' "$v")" --extra-approval-source typed >/dev/null 2>&1; rc=$?
    assert_eq "$rc" "2" "AC38 5차5: U+${v} 뿐인 추가 승인은 rc 2"
  done
  put_snap "$d" "$d/s2.json" && assert_eq "$(py docreview_state.py begin-round --state-dir "$d" --extra-approval "$(python3 -I -c 'print("é", end="")')" --extra-approval-source typed | jgets 'd["ok"]')" "True" "AC38 5차5 양성 짝: 보이는 글자에 붙은 결합 부호는 받는다"
  rm -rf "$d"
}
case_AC38_r4_m4_route_alternatives_filtered() {
  # 4차 m4 — 라우팅이 fin.json 에 싣는 선택지(decision_view.alternatives)도 decide 가 받는 것과 같다
  local d; d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC38 4차m4: init 실패"; return; }
  br "$d" "$FX/brief-append-r1.md"
  local probe='import sys, docreview_state as S, docreview_route as R; st=S.load_state(sys.argv[1]); it={"id":"eeee0001#r1.1","anchor":"#2-확정","edit_scope":sys.argv[2],"category":"omission","kind":"pre","immutable":False,"origin":"reviewer","summary":"x"}; print("고친다(채택)" in R._decision_view(it, None, st)["alternatives"])'
  assert_eq "$(PYTHONPATH="$SCRIPTS" python3 -c "$probe" "$d" '#6-사용자-원문')" "False" "AC38 4차m4: 고칠 범위가 불변 절인 decide 의 fin.json 선택지에 채택이 없다"
  assert_eq "$(PYTHONPATH="$SCRIPTS" python3 -c "$probe" "$d" '#2-확정')" "True" "AC38 4차m4 양성 짝: 정상 범위는 채택이 있다"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin2.json"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin2.json"
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
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin2.json"
  local succ; succ="$(jget "$d/fin2.json" '[x["id"] for x in d["findings"] if x["disposition"]=="decide" and "expired" in x["summary"]][0]')"
  assert_eq "$(st_yaml "$d" 'st["decides"]["aaaa0001#r1.1"].get("superseded_by")')" "$succ" "AC22b: finalize 가 원본에 전방 포인터를 남긴다(선결조건, 재상승)"
  assert_eq "$(st_yaml "$d" 'st["decides"]["'"$succ"'"]["state"]')" "open" "AC22b: 후속은 평범한 open decide 다(선결조건 — 열려 있지 않으면 「보류」시도 자체가 무의미)"
  # I1(리뷰) — fin.json 채널 자체를 잠근다. `gate_summary` 는 선택지 목록을 전혀
  # 안 내므로(버킷만) JSON 을 읽는 소비자에게는 이 필드가 유일한 선택지 채널이다 —
  # render 만 맞고 fin.json 의 decision_view.alternatives 는 여전히 셋을 내던 것이
  # 리뷰가 실측으로 잡은 결함(fin.json·state.md·골든 셋 다 새는 채널).
  assert_eq "$(jget "$d/fin2.json" '[x["decision_view"]["alternatives"] for x in d["findings"] if x["id"]=="'"$succ"'"][0]')" \
    "['고친다(채택)', '그대로 둔다(기각)']" "AC22b: fin.json 의 decision_view.alternatives 에도 「보류」가 없다(I1 — JSON 채널)"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep3.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample-r2.md" > "$d/fin3.json"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep3.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample-r2.md" > "$d/fin3.json"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin2.json"
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
# 항목 머리 찾기 — 쉬운 말 렌더(쉬운 말 출력 PR 1)에서 항목 머리는 열 0 의 「- 」로 시작하고
# 「(<fid>)」 또는 「(<fid> · 자동)」으로 끝난다. 다른 항목이 이 fid 를 참조할 때(「이 답을 기다리는
# 수정: <fid>」 · 「이어받은 결정: <fid>」)는 괄호로 끝나지 않으므로 머리와 참조가 갈린다.
item_block() {   # item_block <render-text> <fid> <after> → 머리 줄 + 뒤 <after> 줄
  printf '%s\n' "$1" | python3 -c '
import sys
fid, after = sys.argv[1], int(sys.argv[2])
ls = sys.stdin.read().split("\n")
for i, l in enumerate(ls):
    if l.startswith("- ") and (l.endswith("(%s)" % fid) or l.endswith("(%s · 자동)" % fid)):
        print("\n".join(ls[i:i + 1 + after]))
        break
' "$2" "$3"
}
item_prev_line() {   # item_prev_line <render-text> <fid> → 그 항목 머리 바로 앞 줄
  printf '%s\n' "$1" | python3 -c '
import sys
fid = sys.argv[1]
ls = sys.stdin.read().split("\n")
for i, l in enumerate(ls):
    if l.startswith("- ") and (l.endswith("(%s)" % fid) or l.endswith("(%s · 자동)" % fid)):
        if i > 0:
            print(ls[i - 1])
        break
' "$2"
}
# render 의 그 id 블록에서 「대안:」 줄을 뽑아 decide_choices 가 내는 집합과 «라벨로
# 바꾼 뒤» 비교한다(라벨 문자열이 아니라 집합 — 순서 무관). fid 는 hash 파생이라
# item_block 이 그 id 의 항목 머리(끝 괄호)만 잡는다.
# [Task 8 재측정] `_rg_decide` 가 여섯 줄이 되며 「대안:」 이 헤더 뒤 3번째(옛 형식:
# 변경·근거·대안)가 아니라 5번째(그대로 두면·고치면·근거·자리·대안) 줄로 밀렸다.
# `-A4` 는 그 줄에 안 닿아 「대안: 」 이 빈 채로 돌아 이 함수가 늘 False 를 냈다
# (실측 — RED 로 걸렸다) — `-A5` 로 넓힌다. 대안 줄은 항상 이 오프셋에 있으므로
# (사람말 미사상 7번째 줄은 대안 «뒤») category 사상 여부와 무관하게 정확하다.
choices_match() {   # choices_match <render-text> <fid> <state-dir> → True/False
  local alt; alt="$(item_block "$1" "$2" 5 | grep '대안: ' | head -1)"
  python3 -c '
import sys
sys.path.insert(0, sys.argv[1])
from docreview_state import load_state, decide_choices, choice_label
st = load_state(sys.argv[2])
choices = decide_choices(st, sys.argv[3])
kind = (st["decides"].get(sys.argv[3]) or {}).get("kind")
expected = {choice_label(c, kind) for c in choices}
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
# 자체가 괄호를 품는다(`고친다(채택)`). 대신 실제로 찍히는 접두사·형식을 그대로
# 재구성해 벗겨낸다(프로그램의 포맷 문자열과 같은 모양).
choices_match_expired() {   # choices_match_expired <render-text> <fid> <state-dir> → True/False
  local line; line="$(item_block "$1" "$2" 0)"
  python3 -c '
import sys
sys.path.insert(0, sys.argv[1])
from docreview_state import load_state, decide_choices, choice_label
st = load_state(sys.argv[2])
fid = sys.argv[3]
choices = decide_choices(st, fid)
kind = (st["decides"].get(fid) or {}).get("kind")
expected = {choice_label(c, kind) for c in choices}
line = sys.argv[4]
summary = st["findings"][fid].get("summary") or ""
prefix = "- %s — 고를 수 있는 것: " % " ".join(summary.split())
suffix = " (%s)" % fid
offered = set()
if line.startswith(prefix) and line.endswith(suffix):
    body = line[len(prefix):-len(suffix)].split(" — ", 1)[0]   # post 만료 원복-경고 꼬리 제거
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin2.json"
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
  _ci 'bbbb0001#r1.1' --intent '#12-files-to-modify' --state-dir "$d" >/dev/null
  assert_eq "$(st_yaml "$d" 'st["fixes"]["bbbb0001#r1.1"]["state"], st["applied_scopes"][0]["scope"], st["applied_scopes"][0]["round"]')" "('intent_passed', '#12-files-to-modify', 1)" "T27: check-intent 통과 → intent_passed + applied_scopes(round 1)"
  rm -rf "$d"
}
case_T29_fix_applied() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
  _ci 'bbbb0001#r1.1' --intent '#12-files-to-modify' --state-dir "$d" >/dev/null
  local df; df="$(next_round "$d" "$FX/design-sample-r2.md")"
  assert_eq "$(jget "$df" '[c["anchor"] for c in d["changed"]]')" "['#2-goals']" "T29: applied_scopes 의 앵커는 얼림 예외 ①"
  assert_eq "$(jget "$d/obs2.json" 'd["applied"], d["progress"]')" "(['bbbb0001#r1.1'], 1)" "T29: scope 변경 관측 → fix applied"
  rm -rf "$d"
}
case_T30_fix_unapplied_counts() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
  _ci 'bbbb0001#r1.1' --intent '#12-files-to-modify' --state-dir "$d" >/dev/null
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
  # [R2a plan 2 Task 5 4차] 결정 기록 · 미룸 절은 범위로 면제되지 않고, 만드는 라운드도 엔진 줄만일 때만 지나간다 —
  # 라운드 1 의 이미 있는 미룸 절(작성자 표 머리)은 면제 집합에 없다. 그 규칙은 case_AC38_r4_* 가 잰다.
  assert_eq "$(py docreview_state.py exempt-anchors --state-dir "$d" | jgets 'sorted(d)')" "[]" "T36: 결정 기록 · 미룸 절은 범위 면제 집합에 그냥 들지 않는다(줄 출처 규칙만)"
  rm -rf "$d"
}
case_T38_stagnation() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
  next_round "$d" "$FX/design-sample.md" >/dev/null
  seed_findings "$d" "[${F_FIX/bbbb0001#r1.1\"/bbbb0001#r2.1\"}]"     # 같은 계보(lineage 필드 그대로) 의 r2 id
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["stagnation"], d["approval_gate_open"], d["two_stage"], d["next_round_mode"]')" "(True, True, True, 'budget')" "T38: 열린 계보 동일 + 진행 0 → stagnation, 두 단계 게이트, 예산 남음"
  rm -rf "$d"
}
case_AC13_stagnation_first_line() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
  next_round "$d" "$FX/design-sample.md" >/dev/null
  seed_findings "$d" "[${F_FIX/bbbb0001#r1.1\"/bbbb0001#r2.1\"}]"
  assert_eq "$(gsum "$d" 'd["stagnation"], d["cap_reached"]')" "(True, False)" "AC13 전제: 상한 전 정체다"
  assert_contains "$(gfirst "$d")" "열린 지적 2개 — 아직 안 고친 곳 2개가 남았다" "AC13: 정체 경로의 첫 줄도 열린 지적 수를 싣고 그 수가 같은 문장의 항목 합이다"
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
case_AC40_extra_source_required() {
  local d s; d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC40: init 실패"; return; }
  s="$d/s.json"; snap "$FX/design-sample.md" "$s"
  local i; for i in 1 2 3; do put_snap "$d" "$s" && py docreview_state.py begin-round --state-dir "$d" >/dev/null; done
  put_snap "$d" "$s" && py docreview_state.py begin-round --state-dir "$d" --extra-approval '한 번 더 봐 줘' >/dev/null 2>&1; local rc=$?
  assert_eq "$rc" "2" "AC40: 출처 없이 승인 값만 오면 rc 2"
  put_snap "$d" "$s" && py docreview_state.py begin-round --state-dir "$d" --extra-approval-source typed >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "AC40: 출처만 오면 rc 2"
  put_snap "$d" "$s" && py docreview_state.py begin-round --state-dir "$d" --extra-approval '한 번 더 봐 줘' --extra-approval-source typed >/dev/null
  assert_eq "$(st_yaml "$d" 'st["extra_rounds"][-1]["quote"], st["extra_rounds"][-1]["source"]')" "('한 번 더 봐 줘', 'typed')" "AC40: 기타 칸 원문은 typed 로 적힌다"
  rm -rf "$d"
}
case_AC40_below_cap_approval_logged() {
  local d s; d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC40: init 실패"; return; }
  s="$d/s.json"; snap "$FX/design-sample.md" "$s"
  put_snap "$d" "$s" && py docreview_state.py begin-round --state-dir "$d" --extra-approval '미리 승인' --extra-approval-source typed >/dev/null
  assert_eq "$(st_yaml "$d" 'len(st["extra_rounds"])')" "0" "AC40: 상한 아래서 온 승인 값은 extra_rounds 에 안 남는다"
  assert_contains "$(cat "$d/docreview-state.md")" "추가 승인 값이 왔지만 상한 아래라 쓰지 않았다" "AC40: 그 사실이 그 라운드 로그 줄(원장 본문)에 남는다"
  rm -rf "$d"
}
case_AC13_open_count_and_label() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC,$F_FIX]"
  local s="$d/s.json"; snap "$FX/design-sample.md" "$s"
  put_snap "$d" "$s" && py docreview_state.py begin-round --state-dir "$d" >/dev/null; put_snap "$d" "$s" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  local g; g="$(py docreview_state.py gate --state-dir "$d")"
  assert_eq "$(printf '%s' "$g" | jgets 'd["cap_reached"], d["open_total"]')" "(True, 2)" "AC13: 상한에서 열린 지적 수를 센다"
  local r; r="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_contains "$(printf '%s\n' "$r" | head -1)" "열린 지적 2개" "AC13: 게이트 첫 줄에 열린 지적 수"
  assert_contains "$r" "「열린 지적 2개를 두고 진행」" "AC13: 승인 선택지 이름에 열린 지적 수"
  assert_not_contains "$r" "사용자가 직접 쓴 말로" "AC40: 옛 문구가 없다"
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
  assert_contains "$gr" "다음: 승인 게이트 — 진행 옵션을 고를 수 있다" "양의 짝: 상한 전 + 열린 것 0 은 예전처럼 즉시 진행 옵션이다"
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
# 산출물 경로는 문서의 순수 함수라 같은 문서의 라운드마다 같은 파일이고, 직전 라운드의 산출물과 이번
# 라운드의 것은 내용으로 못 가른다. `prepare-recritic` 은 `begin-round` 가 기록한 라운드
# 시작보다 먼저 쓰인 codex 파일을 부재로 읽는다. 그래서 픽스처는 러너가 4단계에서 쓰듯
# 라운드 시작 «뒤» 에 상태 디렉토리로 복사해 넘긴다 — 커밋된 픽스처의 mtime 은 체크아웃
# 시각이라 언제나 라운드보다 앞선다.
codex_now() {   # codex_now <state-dir> <fixture> → 방금 쓴 사본 경로 (없는 경로는 그대로)
  if [ -f "$2" ]; then cp "$2" "$1/codex.yaml" && echo "$1/codex.yaml"; else echo "$2"; fi
}
# critic 출력도 같은 판별을 받는다(`critic_predates_round`) — 라운드 시작보다 먼저 쓰인 critic 파일은 직전
# 라운드의 탐지 출력이라 critic 사망이다. 커밋된 critic 픽스처를 라운드 시작 뒤에 그대로 넘기는 자리는
# 탐지 리뷰어가 3단계에서 쓰듯 라운드 시작 «뒤» 에 상태 디렉토리로 복사해 넘긴다.
critic_now() {   # critic_now <state-dir> <critic 파일> → 방금 쓴 사본 경로 (없는 경로는 그대로)
  if [ -f "$2" ]; then cp "$2" "$1/critic.txt" && echo "$1/critic.txt"; else echo "$2"; fi
}
backdate() { python3 -c 'import os, sys, time; t = time.time() - 60; os.utime(sys.argv[1], (t, t))' "$1"; }
case_codex_predates_round_absent() {
  local d; d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "시점 판별: init 실패"; return; }
  # 직전 라운드가 남긴 산출물 — 이번 라운드 시작보다 앞선다(거친 타임스탬프 FS 에서도 그 순서가 보이게 뒤로 민다)
  cp "$FX/codex-r1.yaml" "$d/codex.yaml"; backdate "$d/codex.yaml"
  snap "$FX/design-sample.md" "$d/s1.json"; put_snap "$d" "$d/s1.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-r1.txt")" --codex "$d/codex.yaml" > "$d/prep.json"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-r1.txt")" --codex "$d/never-written.yaml" > "$d/ctl.json"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-r1.txt")" --codex "$d/codex.yaml" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" 'd["degrade"]["codex_absent"], d["degrade"]["codex_reason"], len(d["items"])')" "(False, None, 10)" \
    "시점 판별(양의 짝): 라운드 시작 뒤에 쓰인 codex 파일은 이번 라운드의 판정으로 읽힌다 (critic+codex 10건)"
  rm -rf "$d"
}
case_codex_round_start_unrecorded_absent() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import docreview_state as s
st = s.load_state(sys.argv[2]); st["rounds"][str(st["round"])].pop("started_mtime_ns", None); s.save_state(sys.argv[2], st)' "$SCRIPTS" "$d"
  cp "$FX/codex-r1.yaml" "$d/codex.yaml"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-r1.txt")" --codex "$d/codex.yaml" > "$d/prep.json"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-r1.txt")" --codex "$d/codex.yaml" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" 'd["degrade"]["codex_absent"], d["degrade"]["codex_reason"]')" "(True, 'codex_predates_round')" \
    "시점 판별: 라운드 2 에서 직전 라운드 산출물(라운드 1 시작 뒤·라운드 2 시작 앞)은 부재다 — 비교 대상은 이번 라운드의 표식이다"
  rm -rf "$d"
}
case_codex_tie_absent() {   # 표식과 같은 시각 — 앞뒤를 가를 수 없으면 부재 쪽으로 닫는다
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  cp "$FX/codex-r1.yaml" "$d/codex.yaml"; st_mark "$d" tie "$d/codex.yaml"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-r1.txt")" --codex "$d/codex.yaml" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" 'd["degrade"]["codex_absent"], d["degrade"]["codex_reason"]')" "(True, 'codex_predates_round')" \
    "시점 판별: mtime 이 라운드 시작 표식과 같으면 부재다 (동률은 부재 쪽)"
  rm -rf "$d"
}
case_codex_round_start_unreadable_absent() {
  local d rc; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  st_mark "$d" garble
  cp "$FX/codex-r1.yaml" "$d/codex.yaml"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-r1.txt")" --codex "$d/codex.yaml" > "$d/prep.json" 2>/dev/null; rc=$?
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-r1.txt")" --codex "$d/never-written.yaml" > "$d/ctl.json" 2>/dev/null
  assert_eq "$rc|$(jget "$d/prep.json" 'd["degrade"]["codex_absent"], d["degrade"]["codex_reason"]' 2>/dev/null)" "0|(True, 'round_start_unreadable')" \
    "시점 판별: 정수가 아닌 라운드 시작 표식은 죽지 않고 codex 부재로 닫는다 (rc 0, 사유 round_start_unreadable)"
  assert_eq "$(jget "$d/prep.json" 'd["items"]' 2>/dev/null)" "$(jget "$d/ctl.json" 'd["items"]' 2>/dev/null)" \
    "시점 판별: 표식이 깨져도 critic 항목은 그대로다 (codex 파일이 없던 라운드와 같다)"
  rm -rf "$d"
}
# critic 출력도 같은 판별을 받는다. 탐지를 dispatch 하지 못한 라운드(프로필 판독 실패 등)에는 직전 라운드의
# critic 출력이 같은 자리에 남는다 — 내용이 유효해도 이번 라운드 시작보다 먼저 쓰였으면 이번 라운드의 탐지가
# 아니다(critic 사망, 사유 critic_predates_round). 파일은 라운드 1 시작 «뒤» · 라운드 2 시작 «앞» 에 쓰인다.
case_critic_predates_round_dead() {
  local d rc; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  cp "$FX/critic-r1.txt" "$d/critic.txt"                    # 라운드 1 의 탐지 출력
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$d/critic.txt" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep1.json" 2>/dev/null; rc=$?
  assert_eq "$rc $(jget "$d/prep1.json" 'd["degrade"]["critic_dead"], len(d["items"]) > 0' 2>/dev/null)" "0 (False, True)" \
    "critic 시점 판별 전제: 라운드 1 에서는 같은 파일이 유효한 탐지다 (rc 0 · 항목 있음)"
  next_round "$d" "$FX/design-sample.md" >/dev/null        # 라운드 2 시작 — critic.txt 는 그 자리에 남는다
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$d/critic.txt" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json" 2>/dev/null; rc=$?
  assert_eq "$rc $(jget "$d/prep2.json" 'd["ok"], d["degrade"]["critic_dead"], len(d["items"])' 2>/dev/null)" "4 (False, True, 0)" \
    "critic 시점 판별: 라운드 2 에 라운드 1 의 critic 출력을 그대로 넘기면 critic 사망이다 (rc 4 · 항목 섭취 0)"
  assert_eq "$(st_yaml "$d" '[(e[2], e[3]) for e in st["pending_recritic"]["events"] if e[0] == "source_failed" and e[1] == "doc-critic"]' 2>/dev/null)" \
    "[('layer1 block critic_predates_round', True)]" "critic 시점 판별: 주 판정자 실패로 기록되고 사유가 critic_predates_round 다"
  cp "$FX/critic-r1.txt" "$d/critic.txt"                    # 양의 짝 — 라운드 2 시작 뒤에 새로 쓴 탐지 출력
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$d/critic.txt" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep3.json" 2>/dev/null; rc=$?
  assert_eq "$rc $(jget "$d/prep3.json" 'd["degrade"]["critic_dead"], len(d["items"]) > 0' 2>/dev/null)" "0 (False, True)" \
    "critic 시점 판별(양의 짝): 라운드 2 시작 뒤에 새로 쓴 critic 출력은 이번 라운드의 탐지로 읽힌다 (rc 0 · 항목 있음)"
  rm -rf "$d"
}
route_r1() {   # route_r1 <profile> <doc> [critic] [codex] [recritic-tmpl|--skip] → state dir; $R1 = finalize json path
  local prof="$1" doc="$2" critic="${3:-$FX/critic-r1.txt}" codex="${4:-$FX/codex-r1.yaml}" rtmpl="${5:-$FX/recritic-r1.txt.tmpl}"
  local d; d="$(r1 "$prof" "$doc")" || return 1
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$critic")" --codex "$(codex_now "$d" "$codex")" > "$d/prep.json"; echo "$?" > "$d/prep.rc"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-r1.txt")" --codex "$(codex_now "$d" "$FX/codex-r1.yaml")" > "$d/prep.json"
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
# same_as 흡수는 판정자 하나만 남긴다 — 처분이 같으면 생존자는 f 번호 순으로 갈리고, f 번호는
# 요약의 sha1 순(익명화)이라 출처와 무관하다. 한쪽만 `replacement`·`if_unfixed` 를 적었는데 생존자가
# 빈 쪽이면 흡수된 쪽의 값이 함께 사라져 게이트가 「(대체안 미작성)」을 냈다(Task 20 e2e 실측).
# 값은 늘 크리틱 쪽에만 싣고 두 요약을 **맞바꿔 두 번** 돌린다 — 요약이 f 순서를 정하므로 한 번은
# 빈 쪽이 반드시 생존자다. 그 방향이 실제로 돌았는지를 «쌍마다» 따로 단언한다(한 방향만 재고
# 양방향이라 주장하는 공허 통과를 막는다 — 합계로 재면 한 쌍의 방향이 다른 쌍으로 옮겨가도 통과한다).
# 판정 헬퍼의 실패 계수(`_ASSERT_FAIL`)는 셸 변수라 `$( )` 서브셸 안에서 세면 사라진다 — 그래서
# 이 헬퍼는 직접 부르고 결과는 전역 `_SAF_EMPTY_SURVIVED` 로 돌려준다.
_same_as_fields_run() {   # _same_as_fields_run <크리틱 요약> <코덱스 요약> [replacement YAML 리터럴] [기대 replacement] [기대 coerced] [코덱스 evidence | -] [코덱스 replacement | -] — 생존자가 코덱스면 전역에 +1
  local repl_lit="${3:-인라인 한 줄. └ 천장: 둘째 형식이 요청될 때}" repl_want="${4:-인라인 한 줄. └ 천장: 둘째 형식이 요청될 때}" coerced_want="${5:-0}" cx_ev="${6:-코덱스 근거}" cx_repl="${7:--}"
  local cr cx d fc fx rt q cx_ev_line="" cx_repl_line="" ev_want
  [ "$cx_ev" = "-" ] || cx_ev_line="    evidence: \"${cx_ev}\""$'\n'
  [ "$cx_repl" = "-" ] || cx_repl_line="    replacement: \"${cx_repl}\""$'\n'
  cr="$(mktemp -t cr-XXXXXX.txt)"; cx="$(mktemp -t cx-XXXXXX.yaml)"; rt="$(mktemp -t rt-XXXXXX.txt)"
  printf '```docreview-layer1\n- ref: c1\n  category: overdesign\n  anchor: "#51-parts"\n  disposition: decide\n  summary: "%s"\n  evidence: "크리틱 근거"\n  replacement: "%s"\n  if_unfixed: "크리틱 결과"\n```\n```docreview-layer2\n[]\n```\n' "$1" "$repl_lit" > "$cr"
  printf 'findings:\n  - agent: codex-reviewer\n    ref: x1\n    layer: 1\n    category: overdesign\n    anchor: "#51-parts"\n    disposition: decide\n    summary: "%s"\n%s%smeta:\n  codex_failed: false\n' "$2" "$cx_ev_line" "$cx_repl_line" > "$cx"
  d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$cr")" --codex "$(codex_now "$d" "$cx")" > "$d/prep.json"
  fc="$(jget "$d/prep.json" "[i['f'] for i in d['items'] if i['summary']=='$1'][0]")"
  fx="$(jget "$d/prep.json" "[i['f'] for i in d['items'] if i['summary']=='$2'][0]")"
  printf '```docreview-recritic\nverdicts:\n  - f: "%s"\n    verdict: confirm\n    same_as: ["%s"]\nadded: []\n```\n' "$fx" "$fc" > "$rt"
  py docreview_route.py finalize --state-dir "$d" --recritic "$rt" --doc "$FX/design-sample.md" > "$d/fin.json"
  q='[x for x in d["findings"] if x["category"]=="overdesign"]'
  assert_eq "$(jget "$d/fin.json" "len($q), d[\"adjudication_absorbed\"]")" "(1, 1)" "same_as 필드[${_SAF_TAG:-단독}]($1): 둘이 하나로 흡수된다(전제)"
  assert_eq "$(jget "$d/fin.json" "$q[0][\"replacement\"]")" "$repl_want" "same_as 필드[${_SAF_TAG:-단독}]($1): 생존자에 replacement 가 남는다"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_coerced"]')" "$coerced_want" "same_as 필드[${_SAF_TAG:-단독}]($1): replacement 개행 접기는 값 하나에 정확히 $coerced_want 번 센다(흡수된 쪽은 렌더되지 않으므로 세지 않는다)"
  assert_eq "$(jget "$d/fin.json" "$q[0][\"if_unfixed\"]")" "크리틱 결과" "same_as 필드[${_SAF_TAG:-단독}]($1): 생존자에 if_unfixed 가 남는다"
  # 코덱스 쪽 evidence 가 없으면 생존자가 코덱스일 때 크리틱의 것을 물려받는다 — 있으면 덮지 않는다.
  # 코덱스 evidence 가 없거나 공백뿐이면 빈 칸이다 — 생존자가 코덱스일 때 크리틱의 것을 물려받는다.
  case "$cx_ev" in -|*[![:space:]]*) ;; *) cx_ev="-" ;; esac
  if [ "$cx_ev" = "-" ]; then ev_want="크리틱 근거"; else ev_want="$cx_ev"; fi
  assert_eq "$(jget "$d/fin.json" "$q[0][\"evidence\"] == ('$ev_want' if $q[0][\"summary\"] == '$2' else '크리틱 근거')")" "True" "same_as 필드[${_SAF_TAG:-단독}]($1): 생존자의 evidence 는 적혀 있으면 그대로, 비어 있으면 형제에게서 채운다"
  if [ "$(jget "$d/fin.json" "$q[0][\"summary\"]")" = "$2" ]; then _SAF_EMPTY_SURVIVED=$((_SAF_EMPTY_SURVIVED+1)); fi
  rm -rf "$d" "$cr" "$cx" "$rt"
}
# _saf_pair <태그> <인자…> — 두 요약을 맞바꿔 한 번씩 돌리고, 그 쌍에서 코덱스(빈 쪽)가 정확히 한 번 생존했는지
# 잰다. 태그는 안쪽 단언 라벨에도 붙어 어느 쌍이 떨어졌는지 보인다.
_saf_pair() {
  _SAF_TAG="$1"; shift
  _SAF_EMPTY_SURVIVED=0
  _same_as_fields_run "yagni: 첫째 요약" "yagni: 둘째 요약" "$@"
  _same_as_fields_run "yagni: 둘째 요약" "yagni: 첫째 요약" "$@"
  assert_eq "$_SAF_EMPTY_SURVIVED" "1" "same_as 필드 쌍[$_SAF_TAG]: 맞바꾼 둘 중 정확히 한 번 빈 쪽이 생존자였다(채움 방향이 실제로 돌았다)"
}
case_same_as_survivor_inherits_empty_fields() {
  _saf_pair 기본
  # 옛 두 줄 펜스를 베낀 값(YAML 이스케이프 `\n`) — 물려받은 값의 접기가 생존자 쪽에서 한 번만 세지는가
  _saf_pair 개행 '인라인 한 줄.\n  └ 천장: 둘째 형식이 요청될 때' "인라인 한 줄. └ 천장: 둘째 형식이 요청될 때" 1
  # 아래 쌍들의 `"" ""` 는 `${3:-…}`·`${4:-…}` 에서 기본값으로 떨어진다 — replacement 는 앞 쌍과 같은
  # 기본 한 줄이고, 이 쌍들이 바꾸는 것은 코덱스 쪽 칸뿐이다.
  # 코덱스가 evidence 를 안 적은 쌍 — 생존자가 코덱스인 쪽에서 evidence 가 크리틱의 것으로 채워지는가
  _saf_pair 코덱스-evidence-부재 "" "" 0 -
  # 코덱스가 공백뿐인 evidence·replacement 를 적은 쌍 — 공백은 빈 칸으로 친다. 안 그러면 코덱스가 생존할 때
  # 채움이 건너뛰어지고 replacement 는 뒤의 I4 접기가 None 으로 만들어 크리틱의 값이 흡수와 함께 사라진다.
  _saf_pair 코덱스-공백뿐 "" "" 0 "   " "   "
  _SAF_TAG=""
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-r1.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep.json"
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
# `normalize()` 는 `cmd_prepare` 에서 critic·codex 항목을 정규화하며 원장을 부른다 — 파손 항목은
# `hold`, 어휘 밖 처분은 `coerced`. prepare 의 원장은 `events` 로 기록된 호출만 finalize 로 넘기므로
# 그 호출이 기록되지 않으면 파손 항목이 계수 없이 사라져 `blocks` 가 거짓이 된다(실측 held=0 ·
# coerced=0 · blocks=False). 어휘 밖 처분에는 재비판이 처분을 «직접» 매긴다 — 그러면 `_apply_recritic`
# 의 `None → "ask"` 스윕이 돌지 않아 그 경로로 가려지지 않는다. `normalize()` 호출 자리는 셋(critic 층 1 ·
# critic 층 2 · codex)이라 파손 항목을 자리마다 하나씩 둔다 — 한 자리만 되돌려도 held 가 3 에서 떨어진다.
case_normalize_hold_and_coerced_reach_finalize() {
  local cr cx rt d f3
  cr="$(mktemp -t cr-XXXXXX.txt)"; cx="$(mktemp -t cx-XXXXXX.yaml)"; rt="$(mktemp -t rt-XXXXXX.txt)"
  printf '```docreview-layer1\n- ref: c1\n  category: scope\n  anchor: "#2-goals"\n  disposition: decide\n  summary: "정상 항목"\n- ref: c2\n  category: scope\n  summary: "앵커 없는 항목"\n- ref: c3\n  category: scope\n  anchor: "#3-non-goals"\n  disposition: bogus\n  summary: "어휘 밖 처분"\n```\n```docreview-layer2\n- ref: c4\n  category: placeholder\n  anchor: "#12-files-to-modify"\n```\n' > "$cr"
  printf 'findings:\n  - agent: codex-reviewer\n    ref: x1\n    layer: 1\n    category: scope\n    disposition: decide\n    summary: "codex 앵커 없는 항목"\nmeta:\n  codex_failed: false\n' > "$cx"
  d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$cr")" --codex "$(codex_now "$d" "$cx")" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" 'sorted(i["summary"] for i in d["items"])')" "['어휘 밖 처분', '정상 항목']" "normalize 원장: 세 자리의 파손 항목이 전부 prep 에서 빠진다(전제)"
  f3="$(jget "$d/prep.json" '[i["f"] for i in d["items"] if i["summary"]=="어휘 밖 처분"][0]')"
  printf '```docreview-recritic\nverdicts:\n  - f: "%s"\n    verdict: raise\n    to: decide\nadded: []\n```\n' "$f3" > "$rt"
  py docreview_route.py finalize --state-dir "$d" --recritic "$rt" --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_held"]')" "3" "normalize 원장: 세 자리(critic 층 1 · 층 2 · codex)의 파손 항목 hold 가 전부 finalize 원장에 닿는다"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_held_by_class"]["항목 파손"]')" "3" "normalize 원장: 그 hold 는 「항목 파손」 부류로 센다"
  assert_eq "$(jget "$d/fin.json" 'd["blocks"]')" "True" "normalize 원장: 항목이 소실됐으므로 라운드를 막는다"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_coerced"]')" "1" "normalize 원장: 어휘 밖 처분의 강제가 재비판이 처분을 직접 매긴 경로에서도 센다"
  rm -rf "$d" "$cr" "$cx" "$rt"
}
case_AC7b_unknown_same_as_target_coerced() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-r1.txt" "$FX/codex-failed.yaml" "--skip")"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-r1.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep.json"
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
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample-r2.md" > "$d/fin.json"
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
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample-r2.md" > "$d/fin.json"
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
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin.json"
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
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin.json"
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
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" 'len(d["revived"]), d["revived"][0]["by"], "그대로" in d["revived"][0]["why"]')" "(1, 'user', True)" "T17: 기각 계보의 부활을 라우터가 원장으로 대조해 사유와 함께 공시"
  assert_eq "$(fsum "$d" '또 두 가지' '["disposition"]')" "decide" "T17: 새 finding 은 지우지 않는다(보호라 decide)"
  rm -rf "$d" "$t"
}
case_T35_frozen_change_auto_decide() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample-r2.md" > "$d/fin.json"
  local fr; fr="$(jget "$d/fin.json" 'sorted((x["anchor"], x["disposition"], x["origin"], x["kind"]) for x in d["findings"] if x["category"]=="frozen_change")')"
  assert_eq "$fr" "[('#12-files-to-modify', 'decide', 'auto', 'post'), ('#2-goals', 'decide', 'auto', 'post')]" "T35·AC4: 얼린 두 섹션의 변경 → 사후 auto decide 둘"
  assert_grep "$(jget "$d/fin.json" '[x["evidence"] for x in d["findings"] if x["anchor"]=="#12-files-to-modify" and x["category"]=="frozen_change"][0]')" 'hash [0-9a-f]{12}→[0-9a-f]{12}' "T35·AC4: evidence 에 헤딩 diff(해시 전후)"
  assert_grep "$(jget "$d/fin.json" '[x["decision_view"]["impact"] for x in d["findings"] if x["anchor"]=="#12-files-to-modify" and x["category"]=="frozen_change"][0]')" '인용 1 섹션' "T35: 영향 = refs (Architecture 가 #12 를 인용)"
  # `frozen_change` 는 `kind=post` 다 — 이 자리의 기댓값은 **post 라벨 셋**이어야 한다
  # (pre 셋을 적으면 통과하는 스위트가 엉뚱한 것을 단언한다).
  assert_eq "$(jget "$d/fin.json" '[x["decision_view"]["alternatives"] for x in d["findings"] if x["category"]=="frozen_change"][0]')" "['현재 변경 유지(채택)', '이전 상태로 원복(기각)', '나중에 정한다(보류)']" "T35: 대안은 kind=post 의 셋"
  rm -rf "$d"
}
case_T28_escalated_fix_becomes_decide() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  local fid; fid="$(fsum "$d" 'AC 가 하나뿐' '["id"]')"
  py docreview_state.py fix --state-dir "$d" --id "$fid" --event escalate --reason 'check-intent 거부: edit_scope 밖' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" '[(x["disposition"], x["kind"], x["supersedes"]==sys.argv[0] if False else x["supersedes"]) for x in d["findings"] if "AC 가 하나뿐" in x["summary"]]')" "[('decide', 'pre', '$fid')]" "T28: check-intent 거부된 fix 는 다음 라운드에 같은 계보의 decide(pre)"
  rm -rf "$d"
}
case_T22_reraise_appears_in_next_round() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  local gid; gid="$(fsum "$d" 'Non-goals' '["id"]')"
  py docreview_state.py decide --state-dir "$d" --id "$gid" --choice adopt --quote '채택' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null        # 변경 없음 → expired
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" '[(x["disposition"], x["supersedes"], x["lineage"]) for x in d["findings"] if "expired" in x["summary"]]')" "[('decide', '$gid', '$gid')]" "T22: expired 는 같은 계보의 decide 로 다음 라운드 목록에 재상승"
  rm -rf "$d"
}
# ── I1 — 사후 후속(escalated·reraise)도 갈래 2 두 칸을 물려받는다 ──────────────
# `_auto_decides` 의 escalated·reraise 두 갈래는 `f0`(원본 finding)에서 layer·category·
# anchor·edit_scope 등을 물려받지만, PR 3 출시 시점엔 replacement·if_unfixed 를 빼먹었다
# — 리뷰어가 실제로 쓴 대체안이 한 줄 옆(`st["findings"]`)에 있는데도 렌더가
# 「(대체안 미작성)」(침묵 리터럴)을 낸다. T28·T22 와 같은 시퀀스지만 critic-fields.txt
# (갈래 2 두 칸이 채워진 픽스처)로 갈아 끼워, 후속 항목의 값이 원본과 일치하는지 잰다.
case_I1_escalated_carries_replacement_fields() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-fields.txt" "$FX/codex-failed.yaml" --skip)" \
    || { no "I1 escalated: route_r1 실패"; return; }
  local fid; fid="$(fsum "$d" 'TBD' '["id"]')"
  py docreview_state.py fix --state-dir "$d" --id "$fid" --event escalate --reason 'check-intent 거부: edit_scope 밖' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" '[(x["replacement"], x["if_unfixed"]) for x in d["findings"] if "check-intent 거부 후 상향" in x["summary"]]')" \
    "[('TBD 를 실제 컴포넌트 이름으로 채운다', 'plan 이 그 자리를 스스로 지어낸다')]" \
    "I1: check-intent 거부 후속(escalated)도 원본의 replacement·if_unfixed 를 물려받는다 — 부재가 아니라 원본 값이어야 한다"
  rm -rf "$d"
}
case_I1_reraise_carries_replacement_fields() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-fields.txt" "$FX/codex-failed.yaml" --skip)" \
    || { no "I1 reraise: route_r1 실패"; return; }
  local gid; gid="$(fsum "$d" '다른 것을 겨눈다' '["id"]')"
  py docreview_state.py decide --state-dir "$d" --id "$gid" --choice adopt --quote '채택' >/dev/null
  next_round "$d" "$FX/design-sample.md" >/dev/null        # 변경 없음 → expired
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" '[(x["replacement"], x["if_unfixed"]) for x in d["findings"] if "채택 후 미적용(expired)" in x["summary"]]')" \
    "[('§2 를 브리프 §1 의 goal 한 문장으로 되돌린다', '설계 전체가 다른 문제를 잘 푸는 쪽으로 굳는다')]" \
    "I1: 채택 후 미적용(expired) 후속(reraise)도 원본의 replacement·if_unfixed 를 물려받는다 — 부재가 아니라 원본 값이어야 한다"
  rm -rf "$d"
}
case_T40_codex_absent_first_line() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-r1.txt" "$FX/codex-failed.yaml" "$FX/recritic-missing.txt")"
  local f; f="$(py docreview_state.py gate --state-dir "$d" --render | head -1)"
  assert_grep "$f" '경고 [0-9]+개: ' "T40·AC8: 첫 줄이 경고를 싣는다"
  assert_contains "$f" "codex 리뷰가 없어 다른 모델의 시각이 빠졌다 (codex: exit_nonzero)" "T40·AC8: 첫 줄이 codex 부재와 사유를 공시한다"
  assert_not_contains "$f" "이상 없음" "T40: codex 없는 라운드는 이상 없음이 아니다"
  assert_not_contains "$f" "경고 없음" "T40: codex 없는 라운드는 경고 없음이 아니다"
  assert_eq "$(jget "$d/fin.json" 'd["advisory"][0].startswith("codex 없음"), d["blocks"]')" "(True, False)" "T40: advisory 첫 항목도 codex, 차단은 아님"
  rm -rf "$d"
}
# T40 의 「남은 것 없음」 갈래 — 남은 항목이 0 이어도 codex 없음은 경고로 첫 줄에 실린다(「이상 없음」이 아니다).
case_T40_codex_absent_nothing_left_first_line() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-empty.txt" "$FX/codex-failed.yaml" "$FX/recritic-empty.txt")" \
    || { no "T40 남은 것 없음: route_r1 실패"; return; }
  local f; f="$(py docreview_state.py gate --state-dir "$d" --render | head -1)"
  assert_contains "$f" "남은 것 없음" "T40 남은 것 없음 전제: 이 라운드는 남은 항목이 0 이다"
  assert_grep "$f" '경고 [0-9]+개: ' "T40 남은 것 없음: 첫 줄이 경고를 싣는다"
  assert_not_contains "$f" "이상 없음" "T40 남은 것 없음: codex 없는 라운드는 남은 것이 없어도 이상 없음이 아니다"
  rm -rf "$d"
}
case_T41_critic_dead_blocks() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer1.txt")" --codex "$(codex_now "$d" "$FX/codex-r1.yaml")" > "$d/prep.json" 2>/dev/null; local rc=$?
  assert_eq "$rc $(jget "$d/prep.json" 'd["degrade"]["critic_dead"]')" "4 True" "T41: 층 1 블록 없음 → rc 4 + critic_dead"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-broken.txt")" --codex "$(codex_now "$d" "$FX/codex-r1.yaml")" > "$d/prep.json" 2>/dev/null; rc=$?
  assert_eq "$rc" "4" "T41: 층 1 블록 YAML 파손 → rc 4"
  # critic 사망 라운드를 finalize 까지 태운다 — 게이트가 그 라운드를 「미검증」으로 여는 근거의 하나가
  # `fin.json` 의 `blocks` 다. rc 4 · `critic_dead` 만 재면 그 다리(주 판정자로 기록 →
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
# skill 은 이 셋을 읽는다(reviewing-spec 의 승인 게이트 라벨 · reviewing-brief 의 Step B 라벨).
gsum()   { py docreview_state.py gate --state-dir "$1" | jgets "$2"; }            # gsum <dir> <expr over d>
gfirst() { py docreview_state.py gate --state-dir "$1" --render | head -1; }      # 렌더 첫 줄(degrade 공시)
UNV='d["unverified"], d["approval_label"], d["round_reviewed"], d["approval_gate_open"]'
UNV3='d["unverified"], d["approval_label"], d["round_reviewed"]'
critic_dead_twice() {   # critic_dead_twice <state-dir> — 5단계 rc 4 두 번(재dispatch 도 죽었다)
  py docreview_route.py prepare-recritic --state-dir "$1" --critic "$(critic_now "$1" "$FX/critic-nolayer1.txt")" --codex "$(codex_now "$1" "$FX/codex-r1.yaml")" > "$1/prep.json" 2>/dev/null
  py docreview_route.py prepare-recritic --state-dir "$1" --critic "$(critic_now "$1" "$FX/critic-broken.txt")" --codex "$(codex_now "$1" "$FX/codex-r1.yaml")" > "$1/prep.json" 2>/dev/null
}
case_T46_critic_dead_twice_unverified() {
  local d f; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  critic_dead_twice "$d"
  assert_eq "$(gsum "$d" "$UNV")" "('critic_dead', '미검증', False, True)" \
    "T46: critic 사망 두 번(finalize 없음) → unverified critic_dead · 라벨 「미검증」 · 완료 기록 불가 · 승인 게이트 열림"
  f="$(gfirst "$d")"
  assert_not_contains "$f" "이상 없음" "T46: critic 사망 두 번 라운드의 렌더 첫 줄이 「이상 없음」·「경고 없음」을 쓰지 않는다"
  assert_not_contains "$f" "경고 없음" "T46: critic 사망 두 번 라운드의 렌더 첫 줄이 「이상 없음」·「경고 없음」을 쓰지 않는다"
  assert_contains "$f" "「미검증」 리뷰어(doc-critic)가 결과를 내지 못해" "T46: 렌더 첫 줄이 주 판정자 사망 · 「미검증」을 공시한다 (부재 단언의 양의 짝)"
  assert_contains "$(py docreview_state.py gate --state-dir "$d" --render)" "다음: 승인 게이트(「미검증」)" \
    "T46: 렌더의 다음 줄이 승인 게이트를 「미검증」 라벨로 연다"
  rm -rf "$d"
}
case_T46_critic_dead_finalized_unverified() {   # 「미검증」 둘째 갈래 — 죽은 채 finalize 한 라운드
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer1.txt")" --codex "$(codex_now "$d" "$FX/codex-r1.yaml")" > "$d/prep.json" 2>/dev/null
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin.json" 2>/dev/null
  assert_eq "$(jget "$d/fin.json" 'd["blocks"]')" "True" "T46 전제: critic 이 죽은 채 finalize 한 라운드 — fin.json blocks 참"
  assert_eq "$(gsum "$d" "$UNV")" "('critic_dead', '미검증', False, True)" \
    "T46: critic 이 죽은 채 finalize 한 라운드도 엔진이 「미검증」으로 안다 (unverified critic_dead · 완료 기록 불가)"
  assert_contains "$(gfirst "$d")" "「미검증」 리뷰어(doc-critic)가 결과를 내지 못해" "T46: 그 라운드의 렌더 첫 줄도 주 판정자 사망을 맨 앞에 싣는다"
  rm -rf "$d"
}
case_T46_finalize_failed_unverified() {   # critic 생존 · finalize rc≠0 — 준비는 남고 fin.json 은 비었다
  local d rc f; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-r1.txt")" --codex "$(codex_now "$d" "$FX/codex-r1.yaml")" > "$d/prep.json"
  # 탈것: 옛 판본은 파손 diff(`{`)로 finalize 를 죽였다. finalize 는 이제 diff 파일을 받지 않으므로(얼림 diff 는
  # 엔진이 원장의 스냅숏으로 계산한다 — PR 3 qg iter 3), 비-UTF-8 재비판 출력으로 죽인다 —
  # finalize 가 원장을 쓰기 전에 `unreadable` rc 1 로 끝난다.
  printf '\xff\xfe\x00bad' > "$d/broken-recritic.txt"
  py docreview_route.py finalize --state-dir "$d" --recritic "$d/broken-recritic.txt" --doc "$FX/design-sample.md" > "$d/fin.json" 2>/dev/null; rc=$?
  assert_eq "$rc $(wc -c < "$d/fin.json" | tr -d ' ')" "1 0" "T46 전제: finalize 가 rc 1 로 죽고 fin.json 은 비었다"
  assert_eq "$(gsum "$d" "$UNV")" "('finalize_incomplete', '미검증', False, True)" \
    "T46: finalize 실패 → 정상 게이트가 아니다 (unverified finalize_incomplete · 라벨 「미검증」 · 완료 기록 불가)"
  f="$(gfirst "$d")"
  assert_not_contains "$f" "이상 없음" "T46: finalize 실패 라운드의 렌더 첫 줄이 「이상 없음」·「경고 없음」을 쓰지 않는다"
  assert_not_contains "$f" "경고 없음" "T46: finalize 실패 라운드의 렌더 첫 줄이 「이상 없음」·「경고 없음」을 쓰지 않는다"
  assert_contains "$f" "「미검증」 판정 정리(finalize)를 마치지 못해" "T46: 렌더 첫 줄이 라우팅 미완 · 「미검증」을 공시한다 (부재 단언의 양의 짝)"
  rm -rf "$d"
}
case_T46_finalize_without_prepare_marks_round() {   # 준비 없는 finalize — 거부를 원장에 남기고, 성공이 치운다
  local d rc; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin.json" 2>"$d/fin.err"; rc=$?
  assert_eq "$rc $(jget "$d/fin.err" 'd["reason"]')" "1 no_pending_recritic" "T46 전제: 준비 없는 finalize 는 rc 1 no_pending_recritic"
  assert_eq "$(st_yaml "$d" 'st["rounds"]["1"].get("finalize_failed")')" "no_pending_recritic" "T46: 그 거부가 이 라운드 자리에 실패 표지로 남는다"
  assert_eq "$(gsum "$d" "$UNV")" "('finalize_incomplete', '미검증', False, True)" "T46: 준비 없이 finalize 가 거부된 라운드의 게이트는 「미검증」이다"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-r1.txt")" --codex "$(codex_now "$d" "$FX/codex-r1.yaml")" > "$d/prep.json"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-r1.txt")" --codex "$(codex_now "$d" "$FX/codex-r1.yaml")" > "$d/prep.json"
  python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import docreview_state as s
st = s.load_state(sys.argv[2]); st["pending_recritic"].pop("round"); s.save_state(sys.argv[2], st)' "$SCRIPTS" "$d"
  assert_eq "$(gsum "$d" "$UNV3")" "('finalize_incomplete', '미검증', False)" "T46: 라운드 번호가 없는 준비는 이번 라운드의 미완 준비로 친다 (닫힌 쪽)"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin.json" 2>"$d/fin.err"; rc=$?
  assert_eq "$rc $(jget "$d/fin.err" 'd["reason"]')" "1 pending_round_unrecorded" "T46: finalize 는 어느 라운드 것인지 모르는 준비를 소비하지 않는다"
  rm -rf "$d"
}
case_finalize_twice_same_report() {   # 한 라운드에 finalize 두 번 — 둘째는 같은 보고를 rc 0 으로, 게이트는 「미검증」이 아니다
  local d rc; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  py docreview_route.py finalize --state-dir "$d" --recritic "$d/recritic.txt" --doc "$FX/design-sample.md" > "$d/fin2.json" 2> "$d/fin2.err"; rc=$?
  assert_eq "$rc" "0" "finalize 두 번: 둘째 호출이 rc 0 이다"
  assert_eq "$(cmp -s "$d/fin.json" "$d/fin2.json" && echo same)" "same" "finalize 두 번: 둘째 보고가 첫 보고와 바이트 단위로 같다"
  assert_contains "$(cat "$d/fin2.err")" "이미 정리됐다" "finalize 두 번: 둘째 호출이 앞 보고를 다시 냈음을 stderr 에 밝힌다"
  assert_eq "$(st_yaml "$d" 'st["rounds"]["1"].get("finalize_failed")')" "None" "finalize 두 번: 둘째 호출이 실패 표지를 남기지 않는다"
  assert_eq "$(gsum "$d" "$UNV3")" "(None, None, True)" "finalize 두 번: 둘째 뒤에도 게이트가 정상이다 (「미검증」 아님)"
  rm -rf "$d"
}
case_finalize_twice_without_saved_report_refused() {   # 보고(finalize_out)가 없는 라운드 — 둘째 finalize 는 예전처럼 거부한다
  local d rc; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import docreview_state as s
st = s.load_state(sys.argv[2]); st["rounds"]["1"].pop("finalize_out"); s.save_state(sys.argv[2], st)' "$SCRIPTS" "$d"
  assert_eq "$(st_yaml "$d" 'bool(st["rounds"]["1"].get("route_report")), "finalize_out" in st["rounds"]["1"]')" "(True, False)" \
    "finalize 두 번 전제: route_report 는 있고 finalize_out 은 없는 라운드"
  py docreview_route.py finalize --state-dir "$d" --recritic "$d/recritic.txt" --doc "$FX/design-sample.md" > "$d/fin2.json" 2> "$d/fin2.err"; rc=$?
  assert_eq "$rc $(jget "$d/fin2.err" 'd["reason"]')" "1 no_pending_recritic" "finalize 두 번: 앞 보고가 없으면 둘째는 rc 1 로 거부한다"
  assert_eq "$(st_yaml "$d" 'st["rounds"]["1"].get("finalize_failed")')" "no_pending_recritic" "finalize 두 번: 그 거부를 라운드 자리에 남긴다"
  rm -rf "$d"
}
case_finalize_twice_does_not_resave() {   # 둘째 finalize 는 원장을 다시 쓰지 않는다 — 내용이 바이트 단위로 같다
  local d before rc; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  before="$(cksum < "$d/docreview-state.md")"
  chmod a-w "$d/docreview-state.md"   # 같은 바이트로 다시 써도 잡는다 — 쓰기를 시도하면 실패한다
  py docreview_route.py finalize --state-dir "$d" --recritic "$d/recritic.txt" --doc "$FX/design-sample.md" > "$d/fin2.json" 2>/dev/null; rc=$?
  chmod u+w "$d/docreview-state.md"
  assert_eq "$rc" "0" "finalize 두 번: 쓸 수 없는 원장에서도 둘째 호출이 rc 0 이다(원장을 쓰려 하지 않는다)"
  assert_eq "$(cksum < "$d/docreview-state.md")" "$before" "finalize 두 번: 둘째 호출 앞뒤의 원장 내용이 같다"
  assert_eq "$(cmp -s "$d/fin.json" "$d/fin2.json" && echo same)" "same" "finalize 두 번(양의 짝): 둘째 호출이 앞 보고를 냈다"
  rm -rf "$d"
}
case_T46_unverified_released_next_round() {   # 라운드 스코프 — 다음 라운드가 정상으로 끝나면 표지가 풀린다
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  critic_dead_twice "$d"
  assert_eq "$(gsum "$d" 'd["unverified"]')" "critic_dead" "T46 전제: 라운드 1 은 「미검증」(critic 사망)"
  next_round "$d" "$FX/design-sample.md" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-r1.txt")" --codex "$(codex_now "$d" "$FX/codex-r1.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin2.json"
  assert_eq "$(gsum "$d" "$UNV3")" "(None, None, True)" "T46: 라운드 2 가 정상으로 끝나면 「미검증」이 풀린다 (라벨 없음 · 완료 기록 가능)"
  assert_not_contains "$(gfirst "$d")" "미검증" "T46: 풀린 라운드의 렌더 첫 줄에 「미검증」이 없다"
  # finalize 실패 표지도 같은 스코프다 — 라운드 3 에서 준비 없이 거부된 뒤 라운드 4(추가 승인) 가 정상이면 풀린다.
  next_round "$d" "$FX/design-sample.md" >/dev/null
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > /dev/null 2>&1
  assert_eq "$(gsum "$d" 'd["unverified"]')" "finalize_incomplete" "T46 전제: 라운드 3 은 「미검증」(finalize 거부)"
  next_round "$d" "$FX/design-sample.md" '사용자: 한 라운드 더' >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-r1.txt")" --codex "$(codex_now "$d" "$FX/codex-r1.yaml")" > "$d/prep4.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin4.json"
  assert_eq "$(gsum "$d" "$UNV3")" "(None, None, True)" "T46: 라운드 4 가 정상으로 끝나면 finalize 실패 표지도 풀린다"
  rm -rf "$d"
}
case_T46_normal_and_unrouted_rounds() {   # 양의 짝 둘 — 정상 라운드는 참, 라우팅 없는 라운드는 사유 없이 거짓
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_eq "$(gsum "$d" "$UNV3")" "(None, None, True)" "T46 양의 짝: 정상 라운드(critic 생존 · finalize 성공) → 사유 없음 · 라벨 없음 · 완료 기록 가능"
  assert_not_contains "$(py docreview_state.py gate --state-dir "$d" --render)" "미검증" "T46 양의 짝: 정상 라운드의 렌더에 「미검증」이 없다"
  local gr; gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_eq "$(gsum "$d" 'd["unreviewed_reason"]')|$(printf '%s' "$gr" | grep -c '마치지 못했다')" "None|0" \
    "T46 양의 짝: 정상 라운드는 공시 사유가 없고 렌더에 리뷰 완료 아님 공시 · 꼬리가 없다"
  rm -rf "$d"
  d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_eq "$(gsum "$d" "$UNV3")" "(None, None, False)" \
    "T46: finalize 를 거치지 않은 라운드 — 「미검증」 사유는 없지만 완료 기록 신호는 서지 않는다 (참은 이번 라운드의 finalize 보고서를 요구한다)"
  rm -rf "$d"
}
case_T46_skipped_routing_unrouted_disclosed() {   # 리뷰 P1 — 5~7단계를 건너뛴 라운드(준비도 라우팅 보고서도 없다)
  # 탈것: 옛 판본은 비-UTF-8 critic 으로 5단계를 rc 1 로 죽였다. 그 입력은 이제 critic 사망(rc 4)이라
  # (최종 리뷰 F6 — 아래 case_T46_undecodable_critic_is_dead) 「미검증」 쪽으로 가므로, `unrouted` 는
  # 5~7단계를 건너뛴 라운드로 잰다 — 1단계 뒤 곧장 게이트다.
  local d f l; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_eq "$(st_yaml "$d" 'st["pending_recritic"], st["rounds"]["1"].get("route_report"), st["rounds"]["1"].get("finalize_failed")')" "(None, None, None)" \
    "T46 전제(리뷰 P1): 5~7단계를 건너뛴 라운드 — 준비 · 라우팅 보고서 · finalize 거부 표지가 모두 없다"
  assert_eq "$(gsum "$d" 'd["unreviewed_reason"], d["unverified"], d["approval_label"], d["round_reviewed"]')" "('unrouted', None, None, False)" \
    "T46: 7단계를 건너뛴 라운드 — 공시 사유 unrouted · 「미검증」 사유와 라벨은 아니다 · 완료 기록 불가"
  f="$(gfirst "$d")"
  assert_not_contains "$f" "이상 없음" "T46: 라우팅 보고서 없는 라운드의 렌더 첫 줄이 「이상 없음」·「경고 없음」을 쓰지 않는다"
  assert_not_contains "$f" "경고 없음" "T46: 라우팅 보고서 없는 라운드의 렌더 첫 줄이 「이상 없음」·「경고 없음」을 쓰지 않는다"
  assert_contains "$f" "리뷰를 마치지 못했다 — 이번 라운드의 판정 기록이 없다" "T46: 렌더 첫 줄이 라우팅 보고서 부재를 공시한다 (부재 단언의 양의 짝)"
  assert_not_contains "$f" "미검증" "T46: 그 공시는 「미검증」 라벨 문구가 아니다 (다른 사유)"
  l="$(py docreview_state.py gate --state-dir "$d" --render | tail -1)"
  assert_contains "$l" "리뷰를 마치지 못했다(round_reviewed=false · unrouted)" \
    "T46: 「다음:」 줄이 진행 옵션을 무조건 말하지 않는다 — 리뷰 완료 아님 꼬리 (리뷰 P1 의 「진행 옵션 활성」)"
  # 리뷰 P1b — 7단계를 건너뛰지 않으면 거부 표지가 서서 「미검증」(finalize_incomplete)이 된다.
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin.json" 2>/dev/null
  assert_eq "$(gsum "$d" 'd["unreviewed_reason"], d["approval_label"]')" "('finalize_incomplete', '미검증')" \
    "T46(리뷰 P1b): 그 뒤 finalize 를 부르면 거부 표지가 서서 「미검증」 이 된다"
  rm -rf "$d"
}
case_T46_undecodable_critic_is_dead() {   # 비-UTF-8 critic 출력 = sentinel 깨짐 — 설계 §9 주 판정자 실패 (최종 리뷰 F6)
  # 옛 판본은 디코드 예외가 `unreadable` rc 1 로 새어 재dispatch 없이 `unrouted` 로 갔다. 설계 §9 는 sentinel 이
  # 없거나 깨지면 critic 사망(재dispatch 1회, 또 실패면 「미검증」)이다.
  local d rc; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  printf '\xff\xfe\x00bad' > "$d/critic-bad.txt"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$d/critic-bad.txt" --codex "$(codex_now "$d" "$FX/codex-r1.yaml")" > "$d/prep.json" 2>"$d/prep.err"; rc=$?
  assert_eq "$rc $(jget "$d/prep.json" 'd["ok"], d["degrade"]["critic_dead"]' 2>/dev/null)" "4 (False, True)" \
    "T46(F6): 비-UTF-8 critic → prepare-recritic rc 4 · critic_dead (rc 1 unreadable 이 아니다)"
  assert_eq "$(st_yaml "$d" '[e[2] for e in st["pending_recritic"]["events"] if e[0] == "source_failed" and e[1] == "doc-critic"]' 2>/dev/null)" "['layer1 block undecodable']" \
    "T46(F6): source_failed 사유가 디코드 실패를 말한다"
  assert_eq "$(gsum "$d" "$UNV3")" "('critic_dead', '미검증', False)" \
    "T46(F6): 그 라운드의 게이트는 「미검증」(critic 사망) 쪽이다 — unrouted 가 아니다"
  rm -rf "$d"
}
case_T46_unrouted_round2_with_open_items() {   # 가장 흔한 재리뷰 모양 — 라운드 2 · 이전 라운드의 열린 항목 · 5~7단계 건너뜀 (최종 리뷰 F7)
  # 위 `unrouted` 셀들은 전부 라운드 1 · 열린 것 없음이라 공시가 `approval_ready` 갈래에서만 재졌다.
  local d f l; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  next_round "$d" "$FX/design-sample.md" >/dev/null
  assert_eq "$(gsum "$d" 'd["round"], d["approval_ready"], d["unreviewed_reason"], d["approval_label"]')" "(2, False, 'unrouted', None)" \
    "T46(F7) 전제: 라운드 2 · 이전 라운드의 열린 항목으로 승인 준비 아님 · 공시 사유 unrouted · 라벨 없음"
  f="$(gfirst "$d")"
  assert_not_contains "$f" "이상 없음" "T46(F7): 승인 준비가 아닌 라우팅 없는 라운드의 렌더 첫 줄도 「이상 없음」·「경고 없음」을 쓰지 않는다"
  assert_not_contains "$f" "경고 없음" "T46(F7): 승인 준비가 아닌 라우팅 없는 라운드의 렌더 첫 줄도 「이상 없음」·「경고 없음」을 쓰지 않는다"
  assert_contains "$f" "리뷰를 마치지 못했다 — 이번 라운드의 판정 기록이 없다" "T46(F7): 렌더 첫 줄이 라우팅 보고서 부재를 공시한다 (부재 단언의 양의 짝)"
  l="$(py docreview_state.py gate --state-dir "$d" --render | tail -1)"
  assert_contains "$l" "리뷰를 마치지 못했다(round_reviewed=false · unrouted)" \
    "T46(F7): 승인 준비가 아닐 때의 「다음:」 줄에도 리뷰 완료 아님 꼬리가 붙는다"
  rm -rf "$d"
}
case_T46_unverified_two_stage_with_open_items() {   # 「미검증」 + 이전 라운드의 열린 항목 → 두 단계 승인 게이트(설계 §8.2)
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_eq "$(gsum "$d" 'd["approval_ready"], d["approval_gate_open"]')" "(False, False)" "T46 전제: 라운드 1 이 열린 항목을 남긴다 (승인 준비 아님 · 승인 게이트 닫힘)"
  next_round "$d" "$FX/design-sample.md" >/dev/null
  critic_dead_twice "$d"
  assert_eq "$(gsum "$d" 'd["unverified"], d["approval_gate_open"], d["approval_ready"], d["two_stage"], d["next_round_mode"]')" \
    "('critic_dead', True, False, True, 'budget')" "T46: 「미검증」 + 열린 항목 → 승인 게이트를 열되 두 단계 · 다음 라운드는 예산"
  assert_contains "$(py docreview_state.py gate --state-dir "$d" --render)" "다음: 승인 게이트(「미검증」) 1단계 — 남은 항목을 처리하거나 「열린 지적 8개를 두고 진행」 (다음 라운드: 재리뷰 횟수 안에서)" \
    "T46: 렌더의 다음 줄이 「미검증」 라벨의 두 단계 승인 게이트다"
  rm -rf "$d"
}

# ── 관측과 얼림 diff 는 원장의 함수다 — 건너뛴 라운드를 따라잡는다 (PR 3 qg iter 3 층위 수정) ─────────────
# 엔진이 permit · fix 적용 관측과 얼림 diff 를 원장의 라운드별 스냅숏(`begin-round` 가 저장한다)으로 스스로 계산한다
# — 오케스트레이터가 쓰는 diff 파일이 없다. 관측 없이 끝난 라운드(critic 이 두 번 죽어 6~7단계를 건너뛴 라운드의
# 모양)의 permit 은 뒤 라운드의 관측이 그 permit 라운드의 스냅숏 쌍으로 따라잡는다. 옛 엔진은 `round == n` 인 permit
# 만 봐서 그런 permit 을 영영 다시 보지 않았고, 그 결정은 adopted 로 남아 재결정도 거부됐다(봉인).
PERMIT_SEL='[(p["round"], bool(p.get("consumed"))) for p in st["permits"].values()]'
begin_only() {   # begin_only <state-dir> <doc> — 1단계만(스냅숏 + begin-round). 관측도 finalize 도 없다
  local d="$1" n; n="$(st_yaml "$d" 'st["round"]+1')"; snap "$2" "$d/s$n.json"; put_doc "$d" "$2" || return 1
  py docreview_state.py begin-round --state-dir "$d" >/dev/null
}
empty_critic() {   # empty_critic <state-dir> → 형식은 맞고 finding 이 없는 critic 출력(라운드 시작 뒤에 쓴다)
  printf '리뷰 없음.\n\n```docreview-layer1\n[]\n```\n\n```docreview-layer2\n[]\n```\n' > "$1/critic.txt"; echo "$1/critic.txt"
}
case_E1_skipped_round_permit_caught_up() {
  local d rc; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' >/dev/null
  begin_only "$d" "$FX/design-sample-r2.md"      # 라운드 2 — permit 앵커(#12)를 고친 문서 · 관측 · finalize 없음
  assert_eq "$(st_yaml "$d" "$PERMIT_SEL")" "[(2, False)]" "E1 전제: 라운드 2 의 permit 이 관측 없이 남았다"
  begin_only "$d" "$FX/design-sample-r2.md"      # 라운드 3 — 문서 그대로
  py docreview_state.py observe-diff --state-dir "$d" > "$d/obs3.json" 2>"$d/obs3.err"; rc=$?
  assert_eq "$rc $(jget "$d/obs3.json" 'd["applied"], d["expired"]' 2>/dev/null)" "0 (['aaaa0001#r1.1'], [])" \
    "E1: 라운드 3 관측이 라운드 2 의 permit 을 그 라운드의 스냅숏 쌍(1→2)으로 따라잡아 applied 로 닫는다"
  assert_eq "$(st_yaml "$d" 'st["decides"]["aaaa0001#r1.1"]["state"]')" "applied" "E1: decide 상태가 applied 다"
  assert_eq "$(gsum "$d" 'd["adopted"]')" "[]" "E1: 라운드 3 게이트에 채택 대기 항목이 없다 (봉인이 없다)"
  rm -rf "$d"
}
case_E1b_skipped_round_unedited_permit_expires() {
  local d rc succ; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' >/dev/null
  begin_only "$d" "$FX/design-sample.md"          # 라운드 2 — 편집 없음 · 관측 · finalize 없음
  begin_only "$d" "$FX/design-sample.md"          # 라운드 3
  py docreview_state.py observe-diff --state-dir "$d" > "$d/obs3.json" 2>/dev/null
  assert_eq "$(jget "$d/obs3.json" 'd["expired"], [(r["finding_id"], r["reason"]) for r in d["reraise"]]' 2>/dev/null)" \
    "(['aaaa0001#r1.1'], [('aaaa0001#r1.1', '라운드 2 에 채택 변경 관측 없음 (D1.1)')])" \
    "E1′: 편집 없이 지나간 라운드의 permit 은 따라잡혀 만료되고 재상승 예약을 남긴다 (사유의 라운드는 permit 의 라운드)"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(empty_critic "$d")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep3.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin3.json" 2>/dev/null; rc=$?
  succ="$(jget "$d/fin3.json" '[x["id"] for x in d["findings"] if x.get("supersedes") == "aaaa0001#r1.1" and x["disposition"] == "decide"]' 2>/dev/null)"
  assert_eq "$rc $(jget "$d/fin3.json" 'len([x for x in d["findings"] if x.get("supersedes") == "aaaa0001#r1.1" and x["disposition"] == "decide"])' 2>/dev/null)" "0 1" \
    "E1′: 라운드 3 finalize 가 그 계보의 후속 decide 를 하나 만든다"
  assert_eq "$(st_yaml "$d" '[st["decides"]["aaaa0001#r1.1"].get("superseded_by")]')" "$succ" "E1′: 원본에 전방 포인터(superseded_by)가 그 후속을 가리킨다"
  rm -rf "$d"
}
e2_round2() {   # e2_round2 <yes|no> → 라운드 1 의 Non-goals decide 를 채택하고 라운드 2(편집된 문서)를 finalize 한 상태 디렉토리
  local d gid; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || return 1
  gid="$(fsum "$d" 'Non-goals' '["id"]')"
  py docreview_state.py decide --state-dir "$d" --id "$gid" --choice adopt --quote '채택' >/dev/null
  begin_only "$d" "$FX/design-sample-r2.md"
  [ "$1" = yes ] && py docreview_state.py observe-diff --state-dir "$d" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample-r2.md" > "$d/fin2.json" 2>/dev/null
  echo "$d"
}
case_E2_finalize_observes_idempotent() {
  local a b gid dec; a="$(e2_round2 no)"; b="$(e2_round2 yes)"; gid="$(fsum "$a" 'Non-goals' '["id"]')"
  dec='sorted((k, v["state"], v.get("superseded_by")) for k, v in st["decides"].items())'
  assert_eq "$(jget "$a/fin2.json" 'len([x for x in d["findings"] if x.get("supersedes") == "'"$gid"'"]), len([x for x in d["findings"] if x["category"] == "frozen_change"])' 2>/dev/null)" "(1, 2)" \
    "E2 전제: observe-diff 없이 finalize 한 라운드 2 — 채택 permit 이 관측돼 만료 후속 하나 · 얼림 검사가 편집 둘을 잡았다"
  assert_eq "$(st_yaml "$a" "$dec")" "$(st_yaml "$b" "$dec")" "E2: observe-diff 없이 finalize 한 decide 상태 == observe-diff 뒤 finalize 한 decide 상태"
  assert_eq "$(jget "$a/fin2.json" 'd["findings"]' 2>/dev/null)" "$(jget "$b/fin2.json" 'd["findings"]' 2>/dev/null)" "E2: 두 순서의 fin.json findings 가 같다"
  rm -rf "$a" "$b"
}
case_E3_consumed_permit_exempt_from_freeze() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' >/dev/null
  begin_only "$d" "$FX/design-sample-r2.md"      # 라운드 2 — permit 앵커(#12)와 permit 없는 #2-goals 를 고친 문서
  py docreview_state.py observe-diff --state-dir "$d" > "$d/obs2.json"
  assert_eq "$(jget "$d/obs2.json" 'd["applied"]') $(st_yaml "$d" "$PERMIT_SEL")" "['aaaa0001#r1.1'] [(2, True)]" \
    "E3 전제: 라운드 2 permit 이 관측돼 소비됐다"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(empty_critic "$d")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample-r2.md" > "$d/fin2.json"
  assert_eq "$(jget "$d/fin2.json" 'sorted(x["anchor"] for x in d["findings"] if x["category"] == "frozen_change")')" "['#2-goals']" \
    "E3: 소비된 permit 의 앵커(#12)는 그 라운드 얼림 검사에서 면제되고 permit 없는 편집(#2-goals)만 frozen_change 다"
  rm -rf "$d"
}
case_E4_snapshot_missing_unverified() {
  local d rc; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' >/dev/null
  begin_only "$d" "$FX/design-sample-r2.md"
  python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import docreview_state as s
st = s.load_state(sys.argv[2]); del st["snapshots"]["1"]; s.save_state(sys.argv[2], st)' "$SCRIPTS" "$d"
  py docreview_state.py observe-diff --state-dir "$d" > "$d/obs2.json" 2>"$d/obs2.err"; rc=$?
  assert_eq "$rc $(jget "$d/obs2.err" 'd["reason"], d["round"]' 2>/dev/null) $(wc -c < "$d/obs2.json" | tr -d ' ')" "1 ('snapshot_missing', 1) 0" \
    "E4: 원장에 라운드 1 스냅숏이 없으면 observe-diff 는 rc 1 snapshot_missing 이다 — 빈 diff 로 넘어가지 않는다"
  assert_eq "$(st_yaml "$d" "$PERMIT_SEL"', st["decides"]["aaaa0001#r1.1"]["state"], st["reraise"]')" "([(2, False)], 'adopted', [])" \
    "E4: 관측하지 못한 permit 은 소비 · 만료 · 재상승되지 않는다"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(empty_critic "$d")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample-r2.md" > "$d/fin2.json" 2>"$d/fin2.err"; rc=$?
  assert_eq "$rc $(jget "$d/fin2.err" 'd["reason"]' 2>/dev/null) $(wc -c < "$d/fin2.json" | tr -d ' ')" "1 snapshot_missing 0" \
    "E4: finalize 도 rc 1 snapshot_missing — 준비를 치우기 전에 멈춘다"
  assert_eq "$(gsum "$d" 'd["approval_label"], d["unverified"], d["round_reviewed"]')" "('미검증', 'finalize_incomplete', False)" \
    "E4: 그 라운드의 게이트는 「미검증」(finalize_incomplete) · 완료 기록 불가"
  rm -rf "$d"
}
case_E5_revert_caught_up_by_its_round_snapshot() {
  local d h; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample-r2.md")"   # 라운드 1 — #12 가 바뀐 채인 문서
  snap "$FX/design-sample.md" "$d/orig.json"
  h="$(jget "$d/orig.json" '[s["hash"] for s in d["sections"] if s["anchor"] == "#12-files-to-modify"][0]')"
  seed_findings "$d" '[{"id":"dddd0005#r1.1","lineage":"dddd0005#r1.1","bucket":"dddd0005","origin":"auto","layer":2,"category":"frozen_change","anchor":"#12-files-to-modify","edit_scope":"#12-files-to-modify","disposition":"decide","summary":"finding 없이 바뀜","evidence":"hash a→b","blocks":[],"kind":"post","prev_hash":"'"$h"'"}]'
  py docreview_state.py decide --state-dir "$d" --id 'dddd0005#r1.1' --choice reject --quote '원복하라' >/dev/null   # 원복 permit(라운드 2)
  begin_only "$d" "$FX/design-sample.md"          # 라운드 2 — #12 를 원복했다 · 관측 없이 지나간다
  begin_only "$d" "$FX/design-sample-r2.md"       # 라운드 3 — #12 를 다시 바꿨다
  assert_eq "$(jget "$d/s2.json" '[s["hash"] for s in d["sections"] if s["anchor"] == "#12-files-to-modify"][0] == "'"$h"'"') $(jget "$d/s3.json" '[s["hash"] for s in d["sections"] if s["anchor"] == "#12-files-to-modify"][0] == "'"$h"'"')" "True False" \
    "E5 전제: 라운드 2 의 #12 는 원복 해시와 같고 라운드 3 의 #12 는 다르다 (현재 라운드 스냅숏으로 판정하면 만료다)"
  py docreview_state.py observe-diff --state-dir "$d" > "$d/obs3.json" 2>/dev/null
  assert_eq "$(jget "$d/obs3.json" 'd["applied"], d["expired"]' 2>/dev/null)" "(['dddd0005#r1.1'], [])" \
    "E5: 원복 permit 은 그 permit 라운드(2)의 스냅숏으로 판정돼 applied 다"
  assert_eq "$(st_yaml "$d" 'st["decides"]["dddd0005#r1.1"]["state"]')" "applied" "E5: decide 상태가 applied 다 (원복 완료)"
  rm -rf "$d"
}
# ── critic 시점 판별 불가의 이름 (PR 3 qg iter 2 F-e) ─────────────────────────────────────────────
# 표식이 없거나 정수가 아니면 critic 을 죽이지 않지만(R69), 시점을 판별하지 못했다는 사실에 codex 경로와 독립으로
# 이름을 남긴다 — codex 파일을 넘기지 않는 라운드(kill switch · residue_unclearable)에서도. 공시이지 차단이 아니다.
case_critic_freshness_unknown_disclosed() {
  local d rc mode want
  for mode in unrecorded garble; do
    d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
    if [ "$mode" = unrecorded ]; then
      python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import docreview_state as s
st = s.load_state(sys.argv[2]); st["rounds"][str(st["round"])].pop("started_mtime_ns", None); s.save_state(sys.argv[2], st)' "$SCRIPTS" "$d"
      want=round_start_unrecorded
    else
      st_mark "$d" garble; want=round_start_unreadable
    fi
    cp "$FX/critic-r1.txt" "$d/critic.txt"
    py docreview_route.py prepare-recritic --state-dir "$d" --critic "$d/critic.txt" --codex "$d/never-written.yaml" > "$d/prep.json" 2>/dev/null; rc=$?
    assert_eq "$rc $(jget "$d/prep.json" 'd["degrade"]["critic_dead"], d["degrade"].get("critic_freshness_unknown"), len(d["items"]) > 0' 2>/dev/null)" "0 (False, '$want', True)" \
      "F-e($want): critic 은 죽지 않고(R69 · rc 0 · 항목 그대로) 시점 판별 불가가 이름으로 남는다 (codex 파일 없이도)"
    py docreview_route.py finalize --state-dir "$d" --recritic-skipped --doc "$FX/design-sample.md" > "$d/fin.json" 2>/dev/null
    assert_eq "$(jget "$d/fin.json" '"critic 시점 판별 불가 ('"$want"')" in d["advisory"], d["blocks"]' 2>/dev/null)" "(True, False)" \
      "F-e($want): finalize 가 그것을 advisory 로 공시한다 — 차단은 아니다"
    rm -rf "$d"
  done
  # 양의 짝 — 표식이 멀쩡한 라운드에는 그 이름도 공시도 없다.
  d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-r1.txt")" --codex "$d/never-written.yaml" > "$d/prep.json" 2>/dev/null
  py docreview_route.py finalize --state-dir "$d" --recritic-skipped --doc "$FX/design-sample.md" > "$d/fin.json" 2>/dev/null
  assert_eq "$(jget "$d/prep.json" '"critic_freshness_unknown" in d["degrade"]' 2>/dev/null) $(jget "$d/fin.json" 'len(d["advisory"]) > 0, any(a.startswith("critic 시점 판별 불가") for a in d["advisory"])' 2>/dev/null)" \
    "False (True, False)" "F-e 양의 짝: 표식이 멀쩡하면 시점 판별 불가의 이름 · 공시가 없다 (다른 advisory 는 있다)"
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
  snap "$FX/design-sample.md" "$d/s2.json"; put_snap "$d" "$d/s2.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null   # 라운드 2 진입, observe 전
  out="$(_ci 'aaaa0001#r1.1' --intent '#2-goals' --state-dir "$d" --decision-id "$did")"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["contract"]')" "0 permit" "AC6: 라운드 n+1 의 유효 permit → 보호 앵커라도 통과(permit 계약)"
  out="$(_ci 'aaaa0001#r1.1' --intent '#12-files-to-modify' --state-dir "$d" --decision-id "$did")"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["reason"]')" "1 scope_outside_permit" "AC6: permit 의 apply_anchors 밖은 거부"
  rm -rf "$d"
  # immutable 은 permit 으로도 못 넘는다
  d="$(r1 "$PROF_SD/brief.md" "$FX/brief-sample.md")"
  seed_findings "$d" '[{"id":"eeee0001#r1.1","lineage":"eeee0001#r1.1","bucket":"eeee0001","origin":"reviewer","layer":2,"category":"omission","anchor":"#6-사용자-원문","edit_scope":"#6-사용자-원문","disposition":"decide","summary":"x","evidence":"S1","blocks":[],"kind":"pre"}]'
  # [R2a plan 2 Task 5 fix round 2] 이제 decide 가 불변 절로 풀리는 edit_scope 의 permit 을 처음부터 열지 않는다 — 그 거부를 먼저 재고,
  # check-intent 의 두 번째 방어선은 원장에 permit 을 손으로 심어(옛 원장 · 위조) 따로 잰다.
  out="$(py docreview_state.py decide --state-dir "$d" --id 'eeee0001#r1.1' --choice adopt --quote '채택' 2>&1 >/dev/null)"
  assert_contains "$out" '"reason": "edit_scope_refused"' "AC6·AC11: 불변 절로 풀리는 edit_scope 는 decide 가 permit 을 열지 않는다"
  did="D1.1"
  PYTHONPATH="$SCRIPTS" python3 -c 'import sys; from docreview_state import load_state, save_state; d=sys.argv[1]; st=load_state(d); st["decides"]["eeee0001#r1.1"]["state"]="adopted"; st["permits"]["D1.1"]={"kind":"apply","apply_anchors":["#6-사용자-원문"],"round":2,"finding_id":"eeee0001#r1.1","consumed":False}; save_state(d, st, "fixture")' "$d"
  snap "$FX/brief-sample.md" "$d/s2.json"; put_snap "$d" "$d/s2.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
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
  # [PR 3 qg iter 3 탈것] 관측할 것이 없는 observe-diff 는 원장을 쓰지 않는다 — 라운드 3 이 무언가를 관측해 원장을 써야
  # 아래 단언이 누적(대입이 아니다)을 잰다. 라운드 2 에 #2-goals 의 decide 를 하나 더 채택해 라운드 3 permit 을 열고,
  # 라운드 3 문서가 그 앵커를 고친다(적용 관측 — 새 예약은 생기지 않으므로 기대값은 그대로다).
  local g="${F_DEC//aaaa0001/gggg0001}"; g="${g//#12-files-to-modify/#2-goals}"
  seed_findings "$d" "[$g]"
  py docreview_state.py decide --state-dir "$d" --id 'gggg0001#r1.1' --choice adopt --quote '채택' >/dev/null
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null     # 라운드 3 — observe-diff 가 다시 돌고 그 permit 의 적용을 관측한다
  assert_eq "$(jget "$d/obs3.json" 'd["applied"]')" "['gggg0001#r1.1']" "AC21 전제: 라운드 3 관측이 원장을 썼다 (다른 permit 의 적용)"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep3.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin.json"
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
# 자연 재예약도 가능하다** — 도달성은 원래 서술보다 더 높다([R2a plan 2 Task 5 3차] 그
# `intent-pass` 이벤트는 없어졌다 — 지금은 이 재예약 경로가 없다). 그와 별개로 이 파일의
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
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
  assert_grep "$(py docreview_state.py gate --state-dir "$d" --render)" '결정으로 올릴 대상이 없는 예약 1건' \
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
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep3.json"
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
  py docreview_route.py finalize --state-dir "$d" --recritic "$rt" --doc "$FX/design-sample.md" > "$d/fin.json"
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
# 의 `drop`/`hold` 뿐이고(`intent-pass` 는 R2a plan 2 Task 5 3차에서 없어졌다), 의도된 흐름(escalate → 후속 auto-decide →
# 채택)은 원본 fix 의 `state` 를 안 건드린다 — 리뷰 실측대로 그대로 두면 한 번 escalate
# 된 fix 는 `approval_ready` 를 영구히 False 로 묶는다. `drop` 은 상태 가드가 없어
# (AC23 이 이미 연 탈출구, 이 태스크가 새로 만든 것이 아니다) escalated 에서도 그대로
# 먹힌다 — 렌더가 그 사실을 실제로 알려주는지와, drop 이 실제로 차단을 푸는지를 함께 잰다.
case_GR_escalated_fix_drop_clears_block() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
  py docreview_state.py fix --state-dir "$d" --id 'bbbb0001#r1.1' --event escalate --reason 'check-intent 거부' >/dev/null
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["approval_ready"]')" "False" \
    "GR: escalate 직후엔 승인이 막혀 있다(선결조건)"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" --render | grep -c '버리면(drop) 이 차단이 풀린다')" "1" \
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
  assert_eq "$(py docreview_state.py gate --state-dir "$d" --render | grep -c '막힌 이유: anchor_protected')" "1" \
    "GR: 라운드 1 렌더에 진짜 사유가 실린다(선결조건)"
  next_round "$d" "$FX/design-sample.md" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample.md" > "$d/fin2.json"
  assert_eq "$(st_yaml "$d" 'st["escalated"]')" "[]" "GR: finalize 뒤 예약은 소비돼 빈다(원장 쪽 선결조건, M7 이 겨눈 자리)"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" --render | grep -c '막힌 이유: anchor_protected')" "1" \
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
  py docreview_state.py init --state-dir "$d" --doc "$(ledger_doc "$d")" --profile "$PROF_SD/brief.md" >"$d/out" 2>"$d/err"; rc=$?
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
  local L; L="$(ledger_doc "$d")"
  ln -s "$L" "$d/link.md"
  py docreview_state.py init --state-dir "$d" --doc "$L" --profile "$PROF_SD/design-doc.md" >"$d/o1" 2>&1; rc=$?
  assert_eq "$rc" "0" "멱등: 같은 문서로 다시 init 하면 rc 0"
  assert_file_grep "$d/o1" '"created": false, "round": 1' "멱등: created false · 원장의 라운드 1 이 그대로 보인다"
  py docreview_state.py init --state-dir "$d" --doc "$d/link.md" --profile "$PROF_SD/design-doc.md" >"$d/o2" 2>&1; rc=$?
  assert_eq "$rc" "0" "멱등(정규화): 같은 문서를 가리키는 심볼릭 링크로 init 해도 rc 0"
  assert_file_grep "$d/o2" '"created": false' "멱등(정규화): 심볼릭 링크 표기도 같은 문서로 읽는다"
  py docreview_state.py init --state-dir "$d" --doc "${L%/*}/./${L##*/}" --profile "$PROF_SD/../docreview-profiles/design-doc.md" >"$d/o3" 2>&1; rc=$?
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
  a1="$(py docreview_state.py state-dir-for --root "$w/root" --doc "$FX/design-sample.md")"
  a2="$(py docreview_state.py state-dir-for --root "$w/root" --doc "$FX/design-sample.md")"
  a3="$(py docreview_state.py state-dir-for --root "$w/root" --doc "$w/link.md")"
  b="$(py docreview_state.py state-dir-for --root "$w/root" --doc "$w/other/design-sample.md")"
  assert_eq "${a1%/*}" "$w/root/.docreview" "문서별 자리: <root>/.docreview/ 아래다 (세션 칸이 없다)"
  # 경로 꼴 — <root>/.docreview/<label>-<hash16>, 세션 칸이 없다
  case "$a1" in "$w/root/.docreview/design-sample-"????????????????) ok "문서별 자리: 꼴이 <root>/.docreview/<label>-<hash16> 이다" ;; *) no "state-dir-for 의 꼴이 <root>/.docreview/<label>-<hash16> 이 아니다: $a1" ;; esac
  assert_grep "${a1##*/}" '^design-sample-[0-9a-f]{16}$' "문서별 자리: 키는 <stem>-<해시 16자>"
  assert_eq "$a2" "$a1" "문서별 자리: 같은 문서를 두 번 도출하면 같은 자리"
  assert_eq "$a3" "$a1" "문서별 자리: 같은 문서를 가리키는 심볼릭 링크도 같은 자리 (init 의 정규화와 같다)"
  if [ -n "$b" ] && [ "$b" != "$a1" ] && [ "${b%/*}" = "$w/root/.docreview" ]; then
    ok "문서별 자리: 이름이 같은 다른 문서는 다른 자리"
  else
    no "문서별 자리: 다른 문서가 같은 자리로 간다 ($b = $a1)"
  fi
  py docreview_state.py state-dir-for --root "root" --doc "$FX/design-sample.md" >"$w/o1" 2>"$w/e1"; rc=$?
  assert_eq "$rc:$(cat "$w/o1")" "1:" "문서별 자리: 상대 루트는 rc 1 · 출력 없음"
  assert_file_grep "$w/e1" '"reason": "root_not_absolute"' "문서별 자리: 상대 루트의 사유는 root_not_absolute"
  # --session 은 더는 받지 않는다 — argparse 가 거부한다(exit 2)
  py docreview_state.py state-dir-for --root "$w/root" --session sess0001 --doc "$FX/design-sample.md" >"$w/o2" 2>"$w/e2"; rc=$?
  if [ "$rc" -eq 2 ] && [ ! -s "$w/o2" ]; then ok "문서별 자리: --session 을 주면 rc 2 · 출력 없음 (세션은 더는 경로의 성분이 아니다)"
  else no "state-dir-for 가 --session 을 받았다(rc=$rc)"; fi
  py docreview_state.py state-dir-for --root "$w/root" --doc "" >"$w/o3" 2>"$w/e3"; rc=$?
  assert_eq "$rc:$(cat "$w/o3")" "1:" "문서별 자리: 빈 문서는 rc 1 · 출력 없음"
  assert_file_grep "$w/e3" '"reason": "doc_empty"' "문서별 자리: 빈 문서의 사유는 doc_empty"
  ( cd "$FX" && py docreview_state.py state-dir-for --root "$w/root" --doc design-sample.md ) >"$w/o4" 2>"$w/e4"; rc=$?
  assert_eq "$rc:$(cat "$w/o4")" "1:" "문서별 자리: 상대 문서 경로는 rc 1 · 출력 없음 (키가 cwd 의 함수가 되지 않는다)"
  assert_file_grep "$w/e4" '"reason": "doc_not_absolute"' "문서별 자리: 상대 문서의 사유는 doc_not_absolute"
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

# ── 칸 둘(replacement·if_unfixed)의 왕복 — 리뷰어 → normalize → 원장 (Task 5) ──────
# 닫힌 열거가 셋이라(codex 변환의 DOCREVIEW_KEYS · normalize 반환 · PUBLIC_FIELDS) 앞의 둘만 고치면
# 렌더까지는 도달하고 «원장에는 안 남는다». 그러면 다음 라운드가 그 값을 못 본다.
case_fields_roundtrip_decide() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-fields.txt" "$FX/codex-failed.yaml" --skip)" || { no "칸 왕복: route_r1 실패"; return; }
  assert_eq "$(fsum "$d" '다른 것을 겨눈다' '["replacement"]')" \
    "§2 를 브리프 §1 의 goal 한 문장으로 되돌린다" "칸 왕복: normalize 가 replacement 를 실어 나른다"
  assert_eq "$(fsum "$d" '다른 것을 겨눈다' '["if_unfixed"]')" \
    "설계 전체가 다른 문제를 잘 푸는 쪽으로 굳는다" "칸 왕복: normalize 가 if_unfixed 를 실어 나른다"
  assert_eq "$(st_yaml "$d" 'bool([f for f in st["findings"].values() if f.get("replacement") == "§2 를 브리프 §1 의 goal 한 문장으로 되돌린다"])')" \
    "True" "칸 왕복: PUBLIC_FIELDS 를 지나 원장에 top-level 로 남는다"
  rm -rf "$d"
}
# AC21' — decide «가 아닌» 처분에서도 남는가. decision_view 통로는 decide 에만 열리므로
# 이 케이스가 없으면 fix 로 난 과설계 지적이 대체안 없이 저자에게 간다.
case_fields_survive_non_decide() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-fields.txt" "$FX/codex-failed.yaml" --skip)" || { no "칸 비-decide: route_r1 실패"; return; }
  local fid; fid="$(jget "$d/fin.json" '[x["id"] for x in d["findings"] if x["disposition"]=="fix" and "TBD" in x["summary"]][0]')"
  assert_eq "$(st_yaml "$d" 'st["findings"]["'"$fid"'"].get("decision_view")')" "None" \
    "칸 비-decide: 선결조건 — 이 항목에는 decision_view 통로가 «없다»(공허하지 않음의 증거)"
  assert_eq "$(st_yaml "$d" 'st["findings"]["'"$fid"'"].get("replacement")')" \
    "TBD 를 실제 컴포넌트 이름으로 채운다" "AC21': fix 처분의 replacement 도 원장에 남는다"
  assert_eq "$(st_yaml "$d" 'st["findings"]["'"$fid"'"].get("if_unfixed")')" \
    "plan 이 그 자리를 스스로 지어낸다" "AC21': fix 처분의 if_unfixed 도 원장에 남는다"
  rm -rf "$d"
}
# ── 동어반복 제거 + 침묵 공시 (AC15) ────────────────────────────────────────
# 「변경」이 헤더의 복사였다. 칸을 더해도 fallback 이 summary 를 되풀이하면 그 실패는
# «필드가 비어 있지 않아» 관측되지 않는다 — 그래서 부재는 리터럴로 말한다.
case_decision_view_no_tautology() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-fields.txt" "$FX/codex-failed.yaml" --skip)" || { no "동어반복: route_r1 실패"; return; }
  assert_eq "$(fsum "$d" '다른 것을 겨눈다' '["decision_view"].get("change", "<없음>")')" "<없음>" \
    "AC15: decision_view 에 change 키가 없다 (헤더 복사 제거)"
  assert_eq "$(fsum "$d" '다른 것을 겨눈다' '["decision_view"]["replacement"]')" \
    "§2 를 브리프 §1 의 goal 한 문장으로 되돌린다" "AC15 양의 짝: 채워진 replacement 는 그대로 난다"
  assert_eq "$(fsum "$d" '다른 것을 겨눈다' '["decision_view"]["if_unfixed"]')" \
    "설계 전체가 다른 문제를 잘 푸는 쪽으로 굳는다" "AC15 양의 짝: 채워진 if_unfixed 는 그대로 난다"
  rm -rf "$d"
}
# 부재가 summary 로 메워지지 않는다. frozen_change 는 애초에 두 칸이 없는 «실재하는»
# 경로라 리뷰어 실수를 지어내지 않고도 이 갈래를 태울 수 있다. T35 와 같은 시퀀스
# (route_r1 → next_round → prepare-recritic(critic-nolayer2, codex-failed) →
# finalize(recritic-missing)) — 이미 frozen_change 둘을 내는 것으로 검증된 경로다.
case_decision_view_absence_is_literal() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "침묵 공시: route_r1 실패"; return; }
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$FX/design-sample-r2.md" > "$d/fin.json"
  local dv; dv="$(jget "$d/fin.json" '[x["decision_view"] for x in d["findings"] if x["category"]=="frozen_change"][0]')"
  assert_grep "$dv" '리뷰어가 안 적음' "AC15: if_unfixed 부재는 「(리뷰어가 안 적음)」으로 난다"
  assert_grep "$dv" '대체안 미작성' "AC15: replacement 부재는 「(대체안 미작성)」으로 난다"
  case "$dv" in
    *'그냥 뺀다'*) no "AC15: 부재가 「대체안 없음 — 그냥 뺀다」로 났다 — 아무도 제안하지 않은 삭제를 만들어 낸다" ;;
    *) ok "AC15: 부재가 삭제 제안으로 승격되지 않았다" ;;
  esac
  rm -rf "$d"
}

# ── 라벨은 kind 의 함수다 (AC17 · AC17') ───────────────────────────────────
# cmd_decide 는 kind=post 에서 reject 에 revert permit 을 만든다 — 그 자리에서
# 「그대로 둔다」는 실제로 원복이다. 고정 라벨을 사람말로 바꾸면 동작을 반대로
# 설명하게 된다. 이 케이스는 얼림 diff 가 만드는 «실재하는» post 항목 위에서 돈다.
case_labels_are_kind_dependent() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "라벨 kind: r1 실패"; return; }
  next_round "$d" "$FX/design-sample-r2.md" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic-skipped --doc "$FX/design-sample-r2.md" > "$d/fin.json"
  local render; render="$(py docreview_state.py gate --state-dir "$d" --render)"
  local fid; fid="$(jget "$d/fin.json" '[x["id"] for x in d["findings"] if x["category"]=="frozen_change"][0]')"
  assert_eq "$(st_yaml "$d" 'st["decides"]["'"$fid"'"]["kind"]')" "post" \
    "라벨 kind: 선결조건 — 이 항목은 kind=post 다(공허하지 않음의 증거)"
  # [Task 8 재측정] 여섯 줄 렌더 이후 이 항목(frozen_change, 항상 사상됨)의 블록은
  # 헤더+5 = 6줄이다. -A6 은 다음 블록의 헤더 한 줄까지 삼켰다(실측) — 대안 줄까지는
  # 안 닿아 오늘은 안전하지만, «자기 블록만» 잡도록 -A5 로 좁힌다(그 판이 swallow
  # 여지를 아예 없앤다).
  local blk; blk="$(item_block "$render" "$fid" 5)"
  assert_grep "$blk" '현재 변경 유지\(채택\)' "AC17: post 의 adopt 라벨은 「현재 변경 유지(채택)」"
  assert_grep "$blk" '이전 상태로 원복\(기각\)' "AC17: post 의 reject 라벨은 「이전 상태로 원복(기각)」"
  case "$blk" in
    *'그대로 둔다'*) no "AC17': post 자리에 「그대로 둔다」로 읽히는 라벨이 있다 — reject 가 revert permit 을 만드는데 동작을 반대로 설명한다" ;;
    *) ok "AC17': post 자리에 「그대로 둔다」로 읽히는 라벨이 하나도 없다" ;;
  esac
  rm -rf "$d"
}
# pre 자리의 양의 짝 — 위 부재 단언이 「라벨이 통째로 사라져서」 통과하는 것을 막는다.
case_labels_pre_site() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-fields.txt" "$FX/codex-failed.yaml" --skip)" || { no "라벨 pre: route_r1 실패"; return; }
  local render; render="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_grep "$render" '고친다\(채택\)'       "AC17: pre 의 adopt 라벨은 「고친다(채택)」"
  assert_grep "$render" '그대로 둔다\(기각\)'  "AC17: pre 의 reject 라벨은 「그대로 둔다(기각)」"
  assert_grep "$render" '나중에 정한다\(보류\)' "AC17: hold 라벨은 양쪽에서 「나중에 정한다(보류)」"
  rm -rf "$d"
}

# ── 게이트 렌더 여섯 줄 (AC16 · AC19') ─────────────────────────────────────
case_gate_render_six_lines() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-fields.txt" "$FX/codex-failed.yaml" --skip)" || { no "렌더: route_r1 실패"; return; }
  local fid; fid="$(jget "$d/fin.json" '[x["id"] for x in d["findings"] if x["disposition"]=="decide" and "다른 것을 겨눈다" in x["summary"]][0]')"
  local render blk
  render="$(py docreview_state.py gate --state-dir "$d" --render)"
  blk="$(item_block "$render" "$fid" 5)"
  assert_grep "$blk" '^  그대로 두면: 설계 전체가' "AC16: 「그대로 두면」 줄이 if_unfixed 를 낸다"
  assert_grep "$blk" '^  고치면: §2 를 브리프'      "AC16: 「고치면」 줄이 replacement 를 낸다"
  assert_grep "$blk" '^  근거: '                     "AC16: 「근거」 줄이 있다"
  assert_grep "$blk" '^  자리: #2-goals \(목표가 다른 것을 겨눔\) · 인용 ' \
    "AC16·AC19': 「자리」 줄이 anchor · category 사람말 · 인용 수를 함께 낸다"
  assert_grep "$blk" '^  대안: '                     "AC16: 「대안」 줄은 항상 난다"
  case "$blk" in
    *'  변경: '*) no "AC16: 「변경」 줄이 아직 난다 — 헤더 복사(동어반복)" ;;
    *) ok "AC16: 「변경」 줄이 사라졌다" ;;
  esac
  case "$blk" in
    *'  영향: '*) no "AC16: 「영향」 줄이 아직 난다 — 위치를 영향이라 부른다" ;;
    *) ok "AC16: 「영향」이 「자리」로 바뀌었다" ;;
  esac
  rm -rf "$d"
}

# ── 묶음 제목의 순서 + 같은 anchor 묶음 (AC18 · AC18') ──────────────────────
# 순위를 새로 매기지 않는다(ⓓ · 설계 §5.7). GATE_ROWS 10행의 순서는 이미
# 결정론이지만 «상태 범주» 순이다 — 문제는 「순위가 없다」가 아니라 「있는
# 순서의 뜻이 안 보인다」였다. 오케스트레이터가 순위를 매기면 그 순위 자체가
# 판단이고 사용자가 그 위험을 받아들인다고 말한 적이 없다.
# 묶음은 표시일 뿐이다(D24) — AskUserQuestion 질문 수도 항목별 선택권도
# 그대로다. AC18' 은 「묶기 전후로 질문 수가 같다」를 함께 잰다 — gate 요약의
# 버킷 수(렌더와 독립인 채널)와 렌더가 낸 헤더 줄 수를 비교한다.
case_gate_head_and_grouping() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "게이트 머리: route_r1 실패"; return; }
  local render; render="$(py docreview_state.py gate --state-dir "$d" --render)"
  # 옛 렌더는 「순서:」 머리 줄 하나로 순서의 뜻을 말했다. 쉬운 말 출력 PR 1 이 그 줄을 묶음 제목으로
  # 흡수했으므로, 이제는 묶음 제목(「<STATE_GLOSS> N개」)이 렌더에 선 자리를 뽑아 GATE_ROWS 순서인지 잰다.
  # 묶음이 둘 이상이어야 순서 비교가 공허하지 않다.
  local order; order="$(printf '%s\n' "$render" | PYTHONPATH="$SCRIPTS" python3 -c '
import sys
from docreview_state import GATE_ROWS, STATE_GLOSS
ls = sys.stdin.read().split("\n")
pos = []
for r in GATE_ROWS:
    hit = [i for i, l in enumerate(ls) if l.startswith(STATE_GLOSS[r.name] + " ") and l.endswith("개") and not l.startswith("- ")]
    if hit:
        pos.append(hit[0])
print(len(pos) >= 2 and pos == sorted(pos), len(pos))
')"
  case "$order" in
    "True "*) ok "AC18: 묶음 제목이 GATE_ROWS 순서로 선다 ($order)" ;;
    *) no "AC18: 묶음 제목이 GATE_ROWS 순서가 아니거나 두 묶음 미만이다 ($order)" ;;
  esac
  assert_not_grep "$render" '^순서: ' "AC18: 「순서:」 설명 줄은 묶음 제목으로 흡수됐다"
  # AC18' — 묶음은 «표시»다. 묶기 전후로 게이트가 세는 항목 수(= AskUserQuestion
  # 질문 수)가 같다. gate_summary 의 버킷을 세면 그 수가 나온다 — 렌더와 독립인
  # 채널이라 순환이 아니다.
  local n_items; n_items="$(py docreview_state.py gate --state-dir "$d" | PYTHONPATH="$SCRIPTS" python3 -c 'import json, sys; from docreview_state import GATE_ROWS; d = json.load(sys.stdin); print(sum(len(d[r.name]) for r in GATE_ROWS))')"
  # 항목 머리는 열 0 의 「- 」로 시작하고 id 괄호(「(<id>)」 · 「(<id> · 자동)」)로 끝난다 — 그 모양만 센다.
  # 묶음 제목과 「  그대로 두면:」 같은 이어지는 줄은 열 0 의 「- 」가 아니라 안 걸린다. n_items 는 GATE_ROWS
  # 전 행의 합이므로 두 값이 같으면 렌더가 항목을 빼거나 더하지 않았다는 뜻이다.
  local n_headers; n_headers="$(printf '%s\n' "$render" | grep -cE '^- .* \([0-9a-f]+#r[0-9]+\.[0-9]+( · [^()]*)?\)$' || true)"
  [ "${n_items:-0}" -gt 0 ] \
    && ok "AC18' 양의 짝: 이 케이스에 열린 항목이 ${n_items}개 있다 (아래 등식이 0 == 0 으로 통과하지 않는다)" \
    || no "AC18': 열린 항목이 0개다 — 아래 등식이 공허하다. 항목을 만드는 픽스처로 바꿔라"
  assert_eq "$n_headers" "$n_items" "AC18': 묶음이 항목 수를 바꾸지 않는다(질문 수 불변)"
  rm -rf "$d"
}

# ── 같은 anchor 항목이 실제로 붙어서 보인다 (AC18' 의 나머지 절반) ──────────
# AC18' 는 두 절이다 — 「같은 anchor 의 열린 항목이 한 덩어리로 묶여 렌더된다」
# (묶음 자체) 와 「질문 수·선택권은 그대로다」(제약, 위 case_gate_head_and_
# grouping 이 이미 잰다). 위 케이스는 제약만 잰다 — 묶음 표시(`out.append("  ┆
# 같은 자리…")`) 를 통째로 지워도 안 흔들린다(리뷰 실측 — 178개 단언 전부
# 그린으로 남았다). 그 절반을 여기서 잰다. 세 단언:
#  ① 전제 — 이 상태의 한 묶음(GATE_ROWS 한 행) 안에 같은 anchor 를 가진 항목이 N≥2 이어진다.
#     표지는 묶음마다 새로 센다(계획 Q11) — 묶음 제목을 사이에 둔 두 항목은 인접 쌍이 아니다.
#     render_gate() 를 부르지 않는 채널로만 계산한다: `gate-rows` 의 행 순서
#     (GATE_ROWS 자체가 아니라 그 순서를 낸 CLI 출력) + `gate`(--render 없이)
#     의 버킷 + `load_state` 의 anchor. 렌더 문자열을 파싱하지 않으므로 이
#     전제는 렌더와 독립이다.
#  ② 그 인접 쌍의 둘째 항목 바로 앞줄이 마커다(묶음이 실제로 난다).
#  ③ anchor 가 다른 인접 쌍 앞에는 마커가 «없다»(무조건 출력이면 여기서 걸림).
case_gate_grouping_marker() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "묶음 마커: route_r1 실패"; return; }
  local render; render="$(py docreview_state.py gate --state-dir "$d" --render)"
  local rows bucket calc
  rows="$(py docreview_state.py gate-rows)"
  bucket="$(py docreview_state.py gate --state-dir "$d")"
  calc="$(python3 -c '
import json, sys
sys.path.insert(0, sys.argv[1])
from docreview_state import load_state
rows = json.loads(sys.argv[3])
g = json.loads(sys.argv[4])
st = load_state(sys.argv[2])
groups = [[(fid, (st["findings"].get(fid) or {}).get("anchor")) for fid in g[r["name"]]] for r in rows]
same_pairs = [(a[i - 1][0], a[i][0], a[i][1], gi)
              for gi, a in enumerate(groups) for i in range(1, len(a))
              if a[i][1] and a[i][1] == a[i - 1][1]]
diff_pairs = [(a[i - 1][0], a[i][0])
              for a in groups for i in range(1, len(a))
              if a[i][1] and a[i - 1][1] and a[i][1] != a[i - 1][1]]
group_size = 0
if same_pairs:
    target_anchor = same_pairs[0][2]
    group_size = sum(1 for _, x in groups[same_pairs[0][3]] if x == target_anchor)
print(json.dumps({"n_same_anchor_open_pairs": len(same_pairs), "group_size": group_size,
                   "same_pair": same_pairs[0] if same_pairs else None,
                   "diff_pair": diff_pairs[0] if diff_pairs else None}, ensure_ascii=False))
' "$SCRIPTS" "$d" "$rows" "$bucket")"
  local n_pairs group_size anchor_val fid_same1 fid_same2 fid_diff1 fid_diff2
  n_pairs="$(printf '%s' "$calc" | jgets 'd["n_same_anchor_open_pairs"]')"
  group_size="$(printf '%s' "$calc" | jgets 'd["group_size"]')"
  [ "${n_pairs:-0}" -gt 0 ] && [ "${group_size:-0}" -ge 2 ] \
    && ok "AC18' 전제: 이 상태에 같은 anchor 를 가진 열린 항목이 ${group_size}개(인접 쌍 ${n_pairs}) 있다 — 아래 마커 단언이 도달 불가능한 상태를 재지 않는다" \
    || { no "AC18' 전제: 같은 anchor 인접 쌍이 없다 — 마커 단언이 공허하다. 항목을 만드는 픽스처로 바꿔라"; rm -rf "$d"; return; }
  fid_same1="$(printf '%s' "$calc" | jgets 'd["same_pair"][0]')"
  fid_same2="$(printf '%s' "$calc" | jgets 'd["same_pair"][1]')"
  anchor_val="$(printf '%s' "$calc" | jgets 'd["same_pair"][2]')"
  fid_diff1="$(printf '%s' "$calc" | jgets 'd["diff_pair"][0] if d["diff_pair"] else ""')"
  fid_diff2="$(printf '%s' "$calc" | jgets 'd["diff_pair"][1] if d["diff_pair"] else ""')"
  # 인접 쌍의 둘째 항목이 렌더에서 «자기 항목 머리로» 나오는 줄 바로 앞줄을 뽑는다(`item_prev_line`).
  # bare fid 매치는 그 fid 가 다른 항목 안에 참조로 나오면(예: `_rg_blocking_ask` 의 「이 답을 기다리는
  # 수정: <fid>」) 그 줄을 머리로 오인한다. `item_prev_line` 은 열 0 의 「- 」로 시작하고 「(<fid>)」·
  # 「(<fid> · 자동)」으로 끝나는 줄만 머리로 본다 — 참조 줄은 그 끝 괄호 모양이 아니라 갈린다.
  local before_same before_diff
  before_same="$(item_prev_line "$render" "$fid_same2")"
  before_diff="$(item_prev_line "$render" "$fid_diff2")"
  assert_grep "$before_same" '^  ┆ 같은 자리\(' \
    "AC18': 같은 anchor(${anchor_val}) 인접 쌍(${fid_same1} → ${fid_same2}) 앞에 묶음 마커가 실제로 붙는다"
  case "$before_diff" in
    '  ┆ 같은 자리'*) no "AC18': anchor 가 다른 인접 쌍(${fid_diff1} → ${fid_diff2}) 앞에도 마커가 붙었다 — 무조건 출력이다" ;;
    *) ok "AC18': anchor 가 다른 인접 쌍(${fid_diff1} → ${fid_diff2}) 앞에는 마커가 없다" ;;
  esac
  rm -rf "$d"
}

# ── added finding 의 두 칸 왕복 (AC19″) ────────────────────────────────────
# added 는 critic 항목과 «같은» normalize() 를 지난다(docreview_route.py, _apply_recritic 의
# `normalize(ad, 2, "a", i, L)`) — 그래서 칸을 실을 수 «있다». 그것을 내라고 적는 자리는
# agent 본문뿐이고, 본문에 적는 것만으로는 배관이 실제로 사는지가 안 잡힌다. 이 케이스가
# 그 왕복을 잰다.
case_recritic_added_carries_fields() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-fields.txt" "$FX/codex-failed.yaml" "$FX/recritic-added-fields.txt.tmpl")" \
    || { no "added 왕복: route_r1 실패"; return; }
  local n_added; n_added="$(jget "$d/fin.json" 'len([x for x in d["findings"] if "재비판이 찾은" in (x["summary"] or "")])')"
  [ "${n_added:-0}" -ge 1 ] \
    && ok "AC19″ 양의 짝: added 항목이 ${n_added}개 살아남았다 (아래 판정이 공허하지 않다)" \
    || { no "AC19″: added 항목이 0개다 — 재비판 픽스처가 안 먹었다"; rm -rf "$d"; return; }
  assert_eq "$(fsum "$d" '재비판이 찾은' '["replacement"]')" \
    "그 절을 빼고 §5.1 한 줄로 대신한다" "AC19″: added 의 replacement 가 같은 normalize() 를 지나 산다"
  assert_eq "$(fsum "$d" '재비판이 찾은' '["if_unfixed"]')" \
    "plan 이 그 구조를 실재로 믿고 Task 를 짠다" "AC19″: added 의 if_unfixed 도 산다"
  rm -rf "$d"
}

# ── I4 — 개행 낀 replacement 는 _classify_items 가 한 줄로 강제하고 그 강제를 센다 ──
# 프로필 펜스(`### 판정 한 줄`)를 리뷰어가 «펜스가 예전에 두 줄이던 모양 그대로»
# 베끼면 `replacement` 에 개행이 낀 채 들어올 수 있다 — 렌더는 이 칸을 한 줄로
# 낸다(「고치면: %s」)이므로 개행이 섞이면 여섯 줄 블록의 줄 수가 늘고 `└ 천장`
# 조각이 다음 줄 첫 칸에 떨어져 최상위 게이트 줄과 구별이 안 된다. critic-
# replacement-newline.txt 는 그 실패 모양(펜스의 옛 두 줄 그대로)을 그대로 낸다.
# 강제는 normalize() 가 아니라 `_classify_items` 에서 한다 — 두 출처(critic/codex ·
# recritic added)가 합류하고 same_as 흡수가 끝난 뒤 한 번만 도는 자리라, 생존자가
# 물려받은 값을 한 번만 접고 한 번만 센다.
case_I4_replacement_newline_collapsed() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-replacement-newline.txt" "$FX/codex-failed.yaml" --skip)" \
    || { no "I4 개행 강제: route_r1 실패"; return; }
  local repl; repl="$(fsum "$d" '안 쓰는 옵션이 있다' '["replacement"]')"
  assert_eq "$repl" "옵션을 뺀다. └ 천장: 다시 요청되면" \
    "I4: 개행 낀 replacement 가 공백 하나로 뭉쳐 한 줄로 난다"
  case "$repl" in
    *$'\n'*) no "I4: 강제 후에도 replacement 에 실제 개행 문자가 남아 있다" ;;
    *) ok "I4: 강제 후 replacement 에 개행 문자가 없다" ;;
  esac
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_coerced"]')" "1" \
    "I4: 개행 강제가 adjudication_coerced 로 계수된다(소실이 아니라 강제)"
  # gate=False 확인은 집계 adjudication_degraded 로는 못 잰다 — 이 픽스처는 codex-failed.yaml
  # 로 codex 를 죽여 source_failed(모델 다양성, primary=False)만으로 이미 degraded=True 다
  # (adjudication.py:_degraded — `bool(sources_failed)` 가 gate 와 무관하게 참여한다). 대신
  # `reasons()` 가 `gate=True` 인 coerced 만 advisory 줄로 낸다는 사실(adjudication.py `reasons()` 의 `_coerced` 루프, `if gate:` 갈래)
  # 로 gate=False 를 정확히 겨눈다 — 이 강제가 advisory 에 "강제(게이트 변경): replacement" 줄을
  # «내지 않아야» gate=False 다.
  # 부재는 등호로 잰다 — 측정이 예외로 죽으면 빈 출력이 "True" 와 달라 RED 다. 접두의 양의 짝은
  # test_adjudication_behavior.sh §3 에 있다(접두가 바뀌면 거기서 먼저 RED).
  assert_eq "$(jget "$d/fin.json" 'isinstance(d["advisory"], list) and not any("강제(게이트 변경)" in a for a in d["advisory"])')" "True" \
    "I4 양의 짝: replacement 강제는 gate=False 라 advisory 의 게이트-변경 줄로 나지 않는다(카운트는 늘지만 차단은 아니다)"
  rm -rf "$d"
}

# ── I4 쌍둥이 — if_unfixed 도 같은 한 줄 슬롯(「그대로 두면: %s」)에 들어간다 ─────────────
# 개행 낀 값은 한 줄로 접고 센다. 공백뿐인 값은 부재로 친다 — 참으로 읽히면 AC15 의 부재
# 리터럴 대신 빈 줄이 선다. fixture 의 첫 항목은 개행 뒤에 게이트 줄 모양(`- … (<id>)`)을
# 싣는다: 접지 않으면 그 조각이 렌더의 열 0 에 떨어져 진짜 게이트 줄과 구별되지 않는다.
case_I4_if_unfixed_newline_collapsed() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-if-unfixed-newline.txt" "$FX/codex-failed.yaml" --skip)" \
    || { no "I4 if_unfixed: route_r1 실패"; return; }
  assert_eq "$(fsum "$d" '쓰이지 않는 훅' '["if_unfixed"]')" "훅이 죽은 채 남는다. - 가짜 항목 (zz#r1.9)" \
    "I4 if_unfixed: 개행 낀 if_unfixed 가 공백 하나로 뭉쳐 한 줄로 난다"
  assert_eq "$(fsum "$d" '두 가지로 읽힌다' '["if_unfixed"]')" "None" \
    "I4 if_unfixed: 공백뿐인 if_unfixed 는 부재(None)로 원장에 남는다"
  assert_eq "$(fsum "$d" '두 가지로 읽힌다' '["decision_view"]["if_unfixed"]')" "(리뷰어가 안 적음)" \
    "I4 if_unfixed: 공백뿐인 if_unfixed 는 AC15 부재 리터럴로 렌더된다"
  # 접기 범위는 `\s+` 다 — `\r`·탭도 접힌다(터미널에서 `\r` 은 줄 머리로 돌아가 가짜 줄을 그린다).
  assert_eq "$(fsum "$d" '두 번째 백엔드' '["if_unfixed"]')" "결과. - 가짜 (zz#r1.8)" \
    "I4 if_unfixed: \\r·\\n·탭이 섞인 값도 공백 하나로 뭉친다"
  assert_eq "$(jget "$d/fin.json" 'any(c in x.get("if_unfixed") for x in d["findings"] if x.get("if_unfixed") for c in "\r\t\n")')" "False" \
    "I4 if_unfixed: 어느 저장값에도 \\r·탭·개행이 남지 않는다"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_coerced"]')" "3" \
    "I4 if_unfixed: 세 접기(개행 · 공백뿐 · \\r 탭)가 각각 coerced 로 계수된다"
  assert_eq "$(jget "$d/fin.json" 'isinstance(d["advisory"], list) and not any("강제(게이트 변경)" in a for a in d["advisory"])')" "True" \
    "I4 if_unfixed: 칸 접기는 어느 칸이든 게이트 변경 강제가 아니다(advisory 에 게이트 변경 줄 없음 — 등호로 잰다)"
  local gr; gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_not_grep "$gr" '^- 가짜' "I4 if_unfixed: 값 속 게이트 줄 모양이 렌더의 열 0 에 서지 않는다"
  assert_grep "$gr" '^  그대로 두면: 훅이 죽은 채 남는다\. - 가짜 항목 \(zz#r1\.9\)' "I4 if_unfixed 양의 짝: 그 조각은 「그대로 두면」 줄 안에 산다"
  rm -rf "$d"
}

# ── 쉬운 말 렌더 (쉬운 말 출력 설계 §3 · AC3) ───────────────────────────────
# 대표 사례 둘 — ① 옛 렌더 「[미적용 fix] <id> — <요약> (적용 예정 / drop)」의 자리,
# ② 모델이 쓰던 정상 나열 「(codex 정상 · 재비판 정상 · …)」의 렌더 쪽 짝(옛 렌더: 「degrade 없음」 +
# 0 만 늘어선 집계 줄). 둘 다 golden 으로도 고정된다(capture_finalize_golden.sh).
case_plain_render_nothing_left() {
  local d gr; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-empty.txt" "$FX/codex-empty-ok.yaml" "$FX/recritic-empty.txt")" \
    || { no "쉬운 렌더 ②: route_r1 실패"; return; }
  gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_eq "$(printf '%s\n' "$gr" | head -1)" "리뷰 1라운드를 마쳤다 — 이상 없음." \
    "AC3①: 남은 것도 경고도 없는 라운드의 첫 줄은 「이상 없음」 한 문장이다"
  assert_not_grep "$gr" '^이번 라운드 집계' "AC3②: 전부 0 인 집계 줄이 나가지 않는다"
  assert_eq "$(printf '%s\n' "$gr" | grep -cE ' 0(건|개)( |$|·|\(|\))' || true)" "0" \
    "AC3②: 0 인 정상 집계 항목이 어디에도 없다"
  assert_not_grep "$gr" '^지금까지 집계' "AC3②: 전부 0 인 누계 줄이 나가지 않는다"
  assert_not_contains "$gr" "degrade 없음" "AC3: 옛 첫 줄 「degrade 없음」이 남지 않는다"
  rm -rf "$d"
}
case_plain_render_fix_and_decide() {
  local d gr heads; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-fields.txt" "$FX/codex-empty-ok.yaml" "$FX/recritic-empty.txt")" \
    || { no "쉬운 렌더 ①: route_r1 실패"; return; }
  gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_eq "$(printf '%s\n' "$gr" | head -1)" "리뷰 1라운드를 마쳤다 — 정할 것 1개 · 아직 안 고친 곳 1개가 남았다. 경고 없음." \
    "AC3①⑥: 남은 것이 있고 경고가 없으면 첫 줄은 「경고 없음」이다(「이상 없음」이 아니다)"
  heads="$(printf '%s\n' "$gr" | grep '^- ' || true)"
  assert_eq "$(printf '%s\n' "$heads" | grep -c . || true)" "2" "AC3③ 전제: 항목 머리가 둘(decide 1 · 미적용 fix 1)"
  assert_eq "$(printf '%s\n' "$heads" | grep -cvE ' \([0-9a-f]{8}#r[0-9]+\.[0-9]+( · 자동)?\)$' || true)" "0" \
    "AC3③: 모든 항목 머리가 쉬운 말로 시작하고 id 는 끝 괄호 안에 있다"
  assert_grep "$gr" '^아직 안 고친 곳 1개$' "AC3③: 미적용 fix 묶음 제목이 쉬운 말이다"
  assert_grep "$gr" '^- §5 에 TBD 가 남아 있다 — 고치거나 버린다\(drop\) \(9dea7cf3#r1\.1\)$' \
    "AC3 사례 ①: 옛 「[미적용 fix] 9dea7cf3#r1.1 — …」 이 쉬운 말 + 끝 괄호 id 로 바뀌었다"
  assert_not_grep "$gr" '^순서: ' "AC3: 「순서:」 설명 줄은 묶음 제목으로 흡수됐다"
  rm -rf "$d"
}
# Review Focus 1 — 요약(summary)은 정규화에서 개행을 접지 않는다. 새 머리가 열 0 의 「- 」 로 시작하므로
# 여러 줄 요약이 가짜 항목 줄을 만들 수 있다 — 렌더가 접는다(원장 값은 그대로).
case_I4_summary_newline_collapsed() {
  local d gr; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  seed_findings "$d" '[{"id":"aaaa0001#r1.1","lineage":"aaaa0001#r1.1","bucket":"aaaa0001","origin":"reviewer","layer":2,"category":"ambiguity","anchor":"#12-files-to-modify","edit_scope":"#12-files-to-modify","disposition":"decide","summary":"파일 목록이 두 가지로 읽힌다\n- 가짜 항목 (zz#r1.7)","evidence":"12행","blocks":[],"kind":"pre"}]'
  gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_not_grep "$gr" '^- 가짜 항목' "I4 summary: 요약 속 항목 머리 모양이 렌더의 열 0 에 서지 않는다"
  assert_grep "$gr" '^- 파일 목록이 두 가지로 읽힌다 - 가짜 항목 \(zz#r1\.7\) \(aaaa0001#r1\.1\)$' \
    "I4 summary 양의 짝: 그 조각은 진짜 머리 줄 안에 한 줄로 산다"
  assert_eq "$(st_yaml "$d" 'st["findings"]["aaaa0001#r1.1"]["summary"].count(chr(10))')" "1" \
    "I4 summary: 원장 값은 그대로다(접기는 렌더에서만)"
  rm -rf "$d"
}
# 같은 구멍의 근거(evidence) 칸 — 근거는 문서 인용이라 원장에 원문 그대로 남는다(계획 P11). 「  근거: 」 줄에
# 들어갈 때 개행이 살아 있으면 다음 줄 열 0 에 가짜 항목 머리가 선다 — 렌더가 접는다.
case_I4_evidence_newline_collapsed() {
  local d gr; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  seed_findings "$d" '[{"id":"aaaa0001#r1.1","lineage":"aaaa0001#r1.1","bucket":"aaaa0001","origin":"reviewer","layer":2,"category":"ambiguity","anchor":"#12-files-to-modify","edit_scope":"#12-files-to-modify","disposition":"decide","summary":"파일 목록이 두 가지로 읽힌다","evidence":"12행\n- 가짜 항목 (zz#r1.6)","blocks":[],"kind":"pre"}]'
  gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_not_grep "$gr" '^- 가짜' "I4 evidence: 근거 속 항목 머리 모양이 렌더의 열 0 에 서지 않는다"
  assert_grep "$gr" '^  근거: .*12행 - 가짜 항목 \(zz#r1\.6\)' \
    "I4 evidence 양의 짝: 그 조각은 「근거」 줄 안에 한 줄로 산다"
  assert_eq "$(st_yaml "$d" 'st["findings"]["aaaa0001#r1.1"]["evidence"].count(chr(10))')" "1" \
    "I4 evidence: 원장 값은 그대로다(접기는 렌더에서만 — 근거는 원문 인용)"
  rm -rf "$d"
}
# 같은 구멍의 category 칸 — 사람말 사상이 없는 category 는 「↳ 사람말 사상 없음」 줄에 원래 이름 그대로
# 실린다. 리뷰어가 쓴 이름에 개행이 있으면 다음 줄 열 0 에 가짜 항목 머리가 선다 — 렌더가 접는다.
case_I4_category_newline_collapsed() {
  local d gr; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-category-newline.txt" "$FX/codex-failed.yaml" --skip)" \
    || { no "I4 category: route_r1 실패"; return; }
  gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_not_grep "$gr" '^- 가짜' "I4 category: category 속 항목 머리 모양이 렌더의 열 0 에 서지 않는다"
  assert_grep "$gr" '^  ↳ 사람말 사상 없음: zzz - 가짜 항목 \(bbbb0002#r1\.1\) — 원래 이름 그대로 낸다$' \
    "I4 category 양의 짝: 그 이름은 「사람말 사상 없음」 줄 안에 한 줄로 산다"
  rm -rf "$d"
}
# 같은 구멍의 자리(anchor) 칸 — 같은 자리가 이어지면 「┆ 같은 자리(…)」 표지가 anchor 를 싣는다.
case_I4_anchor_newline_collapsed() {
  local d gr; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  seed_findings "$d" '[{"id":"aaaa0001#r1.1","lineage":"aaaa0001#r1.1","bucket":"aaaa0001","origin":"reviewer","layer":2,"category":"ambiguity","anchor":"#12\n- 가짜 항목 (zz#r1.7)","edit_scope":"#12-files-to-modify","disposition":"decide","summary":"파일 목록이 두 가지로 읽힌다","evidence":"12행","blocks":[],"kind":"pre"},{"id":"aaaa0002#r1.1","lineage":"aaaa0002#r1.1","bucket":"aaaa0002","origin":"reviewer","layer":2,"category":"ambiguity","anchor":"#12\n- 가짜 항목 (zz#r1.7)","edit_scope":"#12-files-to-modify","disposition":"decide","summary":"파일 순서가 정해지지 않았다","evidence":"12행","blocks":[],"kind":"pre"}]'
  gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_not_grep "$gr" '^- 가짜' "I4 anchor: anchor 속 항목 머리 모양이 렌더의 열 0 에 서지 않는다"
  assert_grep "$gr" '^  ┆ 같은 자리\(#12 - 가짜 항목 \(zz#r1\.7\)\)$' \
    "I4 anchor 양의 짝: 그 anchor 는 「같은 자리」 표지 안에 한 줄로 산다"
  rm -rf "$d"
}
# 렌더 첫 줄 경고의 쉬운 말(계획 Q9) — advisory 원문은 기계가 읽는 값이라 그대로 두고 렌더만 바꾼다. 같은 사실을
# 두 출처가 말한 원문(「codex 없음」 + 「입력 실패(보조): codex」 등)은 한 줄로 합치고, 사유 토큰은 그 줄 괄호에 모은다.
case_plain_warns_first_line() {
  local d f raw; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-nolayer2.txt" "$FX/codex-failed.yaml" --skip)" \
    || { no "경고 쉬운 말: route_r1 실패"; return; }
  f="$(gfirst "$d")"
  assert_eq "$(jget "$d/fin.json" 'len(d["advisory"])')" "6" "경고 쉬운 말 전제: 이 라운드의 advisory 원문은 여섯이다"
  assert_contains "$f" "경고 3개: " "경고 쉬운 말: 원문 여섯이 가리키는 사실 셋이 한 줄씩 실린다"
  assert_contains "$f" "codex 리뷰가 없어 다른 모델의 시각이 빠졌다 (codex: exit_nonzero)" \
    "경고 쉬운 말: codex 부재가 쉬운 문장 한 줄이고 사유 토큰은 괄호에 있다"
  assert_contains "$f" "재비판이 돌지 않아 잘못된 지적을 걸러 내지 못했다 (doc-recritic: kill switch, skipped)" \
    "경고 쉬운 말: 재비판 부재가 한 줄이고 두 출처의 사유를 모두 싣는다"
  assert_contains "$f" "세부 검토 결과(층 2)가 없어 세부 지적을 셀 수 없다 (layer2: block missing)" \
    "경고 쉬운 말: 층 2 부재가 한 줄이고 셀 수 없다고 말한다"
  assert_eq "$(printf '%s' "$f" | grep -o 'codex 리뷰가 없어' | grep -c .)" "1" "경고 쉬운 말: codex 부재가 첫 줄에 한 번만 나온다"
  for raw in '모델 다양성 0' '입력 실패(' '셀 수 없음:' '기각 경로 0' '상세 미검증'; do
    assert_not_contains "$f" "$raw" "경고 쉬운 말: 첫 줄에 엔진 원문 「${raw}」이 없다"
  done
  assert_eq "$(jget "$d/fin.json" 'd["advisory"][0], d["advisory"][1]')" \
    "('codex 없음 — 모델 다양성 0 (exit_nonzero)', '셀 수 없음: layer2 — block missing')" \
    "경고 쉬운 말 양의 짝: 기계가 읽는 advisory 원문은 그대로다"
  rm -rf "$d"
}
# 제목 없는 문서의 첫 줄 — 「앵커 불가」 원문의 두 사실(얼림·보호 검사가 꺼졌다 · 모든 수정이 문서 전체 범위다)이
# 쉬운 줄 하나에 함께 실린다. 원문은 기계가 읽는 값이라 그대로다(계획 Q9).
case_plain_warns_headingless_first_line() {
  local d f; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/headingless.md")" \
    || { no "제목 없는 문서 경고: route_r1 실패"; return; }
  f="$(gfirst "$d")"
  assert_contains "$f" "경고 1개: 문서에 제목이 없어 지적의 자리를 가리키지 못한다 — 얼림·보호 검사가 꺼졌고 모든 수정이 문서 전체 범위다 (앵커 불가)" \
    "제목 없는 문서 경고: 쉬운 줄이 꺼진 검사와 문서 전체 범위를 함께 말하고 괄호에 사유 토큰을 싣는다"
  assert_not_contains "$f" "얼림·보호 부류 비활성" "제목 없는 문서 경고: 첫 줄에 엔진 원문이 없다"
  assert_eq "$(jget "$d/fin.json" 'd["advisory"]')" "['앵커 불가 — 얼림·보호 부류 비활성, 모든 fix 가 문서 전체 범위']" \
    "제목 없는 문서 경고 양의 짝: 기계가 읽는 advisory 원문은 그대로다"
  rm -rf "$d"
}
# 쉬운 말 경고 표의 두 성질 — 표에 없는 원문은 버리지 않고 그대로 싣는다(계획 P6) · 원문 속 개행은 한 줄로 접는다.
case_plain_warns_unknown_kept() {
  local got; got="$(PYTHONPATH="$SCRIPTS" python3 -c '
from docreview_state import _plain_warns
print(_plain_warns(["표에 없는 경고 하나", "보류: recritic:f9 — 항목 파손:\nunknown f"]))')"
  assert_eq "$got" "['표에 없는 경고 하나', '판정하지 못하고 보류한 지적이 있다 (recritic:f9 — 항목 파손: unknown f)']" \
    "경고 쉬운 말: 표에 없는 원문은 그대로 싣고, 표에 있는 원문은 쉬운 문장 뒤 괄호에 나머지를 한 줄로 싣는다"
}
# 「앵커 불가」 행은 지금 원문과 같은 글자만 바꾼다 — 원문에 글자가 붙으면(앞으로 바뀐 원문) 그 원문을 그대로 낸다.
case_plain_warns_anchor_exact() {
  local got; got="$(PYTHONPATH="$SCRIPTS" python3 -c '
from docreview_state import _plain_warns
print(_plain_warns(["앵커 불가 — 얼림·보호 부류 비활성, 모든 fix 가 문서 전체 범위", "앵커 불가 — 얼림·보호 부류 비활성, 모든 fix 가 문서 전체 범위 · 새 사실"]))')"
  assert_eq "$got" "['문서에 제목이 없어 지적의 자리를 가리키지 못한다 — 얼림·보호 검사가 꺼졌고 모든 수정이 문서 전체 범위다 (앵커 불가)', '앵커 불가 — 얼림·보호 부류 비활성, 모든 fix 가 문서 전체 범위 · 새 사실']" \
    "앵커 불가 쉬운 말: 지금 원문만 쉬운 줄로 바꾸고, 글자가 붙은 원문은 그대로 싣는다"
}
# codex 사유가 없는 라운드(`codex_reason: None`) — 라우터 원문의 「(None)」이 첫 줄에 새지 않고 사유 자리는 「?」 하나다.
case_first_line_codex_reason_none() {
  local got; got="$(PYTHONPATH="$SCRIPTS" python3 -c '
from docreview_state import _first_line, GATE_ROWS
g = {r.name: [] for r in GATE_ROWS}
g.update(round=1, advisory=["codex 없음 — 모델 다양성 0 (None)"], degrade={"codex_absent": True, "codex_reason": None})
print(_first_line(g))')"
  assert_eq "$got" "리뷰 1라운드를 마쳤다 — 남은 것 없음. 경고 1개: codex 리뷰가 없어 다른 모델의 시각이 빠졌다 (codex: ?)" \
    "codex 사유 없음: 첫 줄의 사유 자리가 「?」 하나이고 None 이 없다"
}
# 집계 줄 — 사용자 기각 · 버린 지적은 원장 전체의 누계다. 「이번 라운드」로 세지 않고 「지금까지」로 낸다(합친 /qg #6).
case_count_line_scope() {
  local d gr; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]" \
    || { no "집계 줄 범위: seed 실패"; rm -rf "$d"; return; }
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice reject --quote '기각한다' >/dev/null
  gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_grep "$gr" '^지금까지 집계: 사용자가 기각한 지적 1건$' "집계 줄 범위: 사용자 기각은 「지금까지 집계」 줄에 선다"
  assert_not_grep "$gr" '^이번 라운드 집계: .*사용자가 기각' "집계 줄 범위: 사용자 기각을 「이번 라운드」로 세지 않는다"
  next_round "$d" "$FX/design-sample.md" >/dev/null
  gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_grep "$gr" '^지금까지 집계: 사용자가 기각한 지적 1건$' "집계 줄 범위: 2라운드에도 1라운드의 사용자 기각은 「지금까지」에 남는다"
  assert_not_grep "$gr" '^이번 라운드 집계: .*사용자가 기각' "집계 줄 범위: 2라운드 화면이 1라운드의 기각을 「이번 라운드」로 세지 않는다(Review Focus)"
  rm -rf "$d"
}
# 같은 글자의 경고 둘은 둘로 센다 — 같은 사실을 두 출처가 말한 행(괄호 이름이 있는 행)만 한 줄로 합친다(합친 /qg #7).
case_plain_warns_same_text_counted() {
  local got; got="$(PYTHONPATH="$SCRIPTS" python3 -c '
from docreview_state import _plain_warns
print(len(_plain_warns(["보류: recritic-verdict — 항목 파손: not a mapping", "보류: recritic-verdict — 항목 파손: not a mapping", "표에 없는 경고", "표에 없는 경고"])))')"
  assert_eq "$got" "4" "같은 글자 경고: 같은 모양의 사건 둘은 각각 한 줄이다(괄호 이름 없는 행 · 표에 없는 원문)"
  got="$(PYTHONPATH="$SCRIPTS" python3 -c '
from docreview_state import _first_line, GATE_ROWS
g = {r.name: [] for r in GATE_ROWS}
g.update(round=1, advisory=["보류: recritic-verdict — 항목 파손: not a mapping", "보류: recritic-verdict — 항목 파손: not a mapping"], degrade={})
print(_first_line(g))')"
  assert_grep "$got" ' 경고 2개: ' "같은 글자 경고: 첫 줄의 경고 개수가 사건 수와 같다"
  got="$(PYTHONPATH="$SCRIPTS" python3 -c '
from docreview_state import _plain_warns
print(len(_plain_warns(["codex 없음 — 모델 다양성 0 (not_installed)", "입력 실패(보조): codex — not_installed"])))')"
  assert_eq "$got" "1" "같은 글자 경고(양의 짝): 같은 사실을 두 출처가 말한 codex 행은 한 줄로 합친다"
}
# 「같은 자리」 표지는 한 묶음 안에서만 앞 항목을 가리킨다(계획 Q11) — 묶음 제목 너머의 항목을 가리키지 않는다.
case_gate_marker_stays_in_group() {
  local d gr; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  local F_DEC2='{"id":"aaaa0002#r1.1","lineage":"aaaa0002#r1.1","bucket":"aaaa0002","origin":"reviewer","layer":2,"category":"ambiguity","anchor":"#12-files-to-modify","edit_scope":"#12-files-to-modify","disposition":"decide","summary":"파일 순서가 정해지지 않았다","evidence":"12행","blocks":[],"kind":"pre"}'
  seed_findings "$d" "[$F_DEC,$F_DEC2,$F_FIX]" || { no "묶음 안 표지: seed 실패"; rm -rf "$d"; return; }
  gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_grep "$(item_prev_line "$gr" 'aaaa0002#r1.1')" '^  ┆ 같은 자리\(#12-files-to-modify\)$' \
    "묶음 안 표지 양의 짝: 같은 묶음에서 같은 자리가 이어지면 표지가 선다"
  assert_eq "$(item_prev_line "$gr" 'bbbb0001#r1.1')" "아직 안 고친 곳 1개" \
    "묶음 안 표지: 다른 묶음의 첫 항목 바로 앞은 묶음 제목이다(같은 자리 표지가 제목 너머를 가리키지 않는다)"
  assert_eq "$(printf '%s\n' "$gr" | grep -c '^  ┆ 같은 자리')" "1" "묶음 안 표지: 표지는 묶음 안의 한 번뿐이다"
  rm -rf "$d"
}
# 같은 구멍의 막힌 이유 칸 — escalate 사유(사용자·엔진이 쓴 값)에 개행이 있으면 다음 줄 열 0 에 가짜 항목
# 머리가 선다. 렌더가 접는다(원장 값은 그대로).
case_I4_escalate_reason_newline_collapsed() {
  local d gr; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
  py docreview_state.py fix --state-dir "$d" --id 'bbbb0001#r1.1' --event escalate --reason $'anchor_protected\n- 가짜 항목 (zz#r1.7)' >/dev/null
  gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_not_grep "$gr" '^- 가짜' "I4 막힌 이유: 사유 속 항목 머리 모양이 렌더의 열 0 에 서지 않는다"
  assert_grep "$gr" '^- c\.py 가 빠졌다 — 막힌 이유: anchor_protected - 가짜 항목 \(zz#r1\.7\)\. 버리면\(drop\) 이 차단이 풀린다 \(bbbb0001#r1\.1\)$' \
    "I4 막힌 이유 양의 짝: 그 사유는 항목 머리 안에 한 줄로 산다"
  assert_eq "$(st_yaml "$d" '"\n" in st["fixes"]["bbbb0001#r1.1"]["escalate_reason"]')" "True" \
    "I4 막힌 이유: 원장 값은 그대로다(접기는 렌더에서만)"
  rm -rf "$d"
}
# 「미검증」 라운드의 첫 줄은 「남은 것 없음」을 쓰지 않는다(계획 Q10) — 셀 것이 없는 것과 세지 못한 것은 다르다.
# 「미검증」이 아닌 라운드의 「남은 것 없음」은 case_T40_codex_absent_nothing_left_first_line 이 잰다(양의 짝).
case_T46_unverified_no_nothing_left() {
  local d f; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  critic_dead_twice "$d"
  assert_eq "$(gsum "$d" 'd["unverified"]')" "critic_dead" "T46 전제: 이 라운드는 「미검증」(critic 사망)"
  f="$(gfirst "$d")"
  assert_not_contains "$f" "남은 것 없음" "T46: 「미검증」 첫 줄이 「남은 것 없음」을 쓰지 않는다"
  assert_eq "$f" "「미검증」 리뷰어(doc-critic)가 결과를 내지 못해 이 라운드는 리뷰되지 않았다. 리뷰 1라운드." \
    "T46 양의 짝: 첫 줄은 「미검증」 공시와 라운드 번호다"
  rm -rf "$d"
}
# STATE_GLOSS 의 ∀ 커버리지 — 행 이름은 `gate-rows` 에서 도출한다(CATEGORY_GLOSS 락과 같은 모양).
case_state_gloss_covers_gate_rows() {
  local rows gl; rows="$(py docreview_state.py gate-rows | python3 -c 'import json, sys; print(" ".join(sorted(r["name"] for r in json.load(sys.stdin))))')"
  gl="$(PYTHONPATH="$SCRIPTS" python3 -c 'from docreview_state import STATE_GLOSS; print(" ".join(sorted(STATE_GLOSS)))')"
  [ -n "$rows" ] && ok "STATE_GLOSS 전제: gate-rows 가 행을 냈다" || no "STATE_GLOSS 전제: gate-rows 가 빈 목록이다 — 아래 등식이 공허하다"
  assert_eq "$gl" "$rows" "STATE_GLOSS: GATE_ROWS 의 행 전부에 사람말 짝이 있고 남는 짝도 없다"
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  assert_eq "$(PYTHONPATH="$SCRIPTS" python3 -c '
import sys
import docreview_state as m
st = m.load_state(sys.argv[1]); g = m.gate_summary(st)
row = next(r.name for r in m.GATE_ROWS if g[r.name])
del m.STATE_GLOSS[row]
out = m.render_gate(st, g).split("\n")
print(row in out[0], sum(1 for l in out if l == "  ↳ 상태 이름에 사람말이 없다: %s — 원래 이름 그대로 낸다" % row))
' "$d")" "True 1" "STATE_GLOSS: 짝이 없는 행은 원래 이름으로 나가고 그 사실을 한 줄로 공시한다"
  rm -rf "$d"
}

# ── AC19′ — 사람말 사상이 없는 category 는 원래 이름으로 나가고 그 사실을 공시한다 ─────────
# normalize() 는 임의 category 를 받는다 — rubric 밖 값을 내는 리뷰어가 실제로 이 갈래를 태운다.
# fixture 의 이름(`zz_unmapped_axis`)은 어느 축과도 겹치지 않게 골랐다 — 실제 축 이름을 쓰면 그 축이
# 생길 때 비회귀로 RED 가 된다. 그 전제를 먼저 잰다. 양의 짝(goal_fit)은 공시 줄이 없어야 한다 —
# 두 항목의 공시 줄 합계가 정확히 1 이다.
case_category_unglossed_disclosed() {
  assert_eq "$(PYTHONPATH="$SCRIPTS" python3 -c 'from docreview_state import category_gloss; print(category_gloss("zz_unmapped_axis"))')" "None" \
    "AC19′ 전제: fixture 의 category 가 정말 사상 밖이다(사상이 생기면 이 case 가 아니라 fixture 를 바꾼다)"
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-unglossed.txt" "$FX/codex-failed.yaml" --skip)" \
    || { no "AC19′ 공시: route_r1 실패"; return; }
  assert_eq "$(fsum "$d" '신뢰 경계를' '["decision_view"]["category_unglossed"]')" "zz_unmapped_axis" \
    "AC19′: 사상 없는 category 가 category_unglossed 로 공시된다"
  assert_contains "$(fsum "$d" '신뢰 경계를' '["decision_view"]["impact"]')" "#2-goals (zz_unmapped_axis) · 인용" \
    "AC19′: 사상 없는 category 는 「자리」에 원래 이름 그대로 실린다(빈칸이 아니다)"
  assert_eq "$(fsum "$d" '다른 것을 겨눈다' '["decision_view"]["category_unglossed"]')" "None" \
    "AC19′ 양의 짝: 사상 있는 category(goal_fit)는 공시하지 않는다"
  local gr; gr="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_grep "$gr" '^  ↳ 사람말 사상 없음: zz_unmapped_axis' "AC19′: 게이트 렌더에 사상 부재 공시 줄이 선다"
  assert_eq "$(printf '%s\n' "$gr" | grep -c '↳ 사람말 사상 없음')" "1" \
    "AC19′ 양의 짝: 공시 줄은 사상 없는 항목에만 — 렌더 전체에 정확히 하나"
  rm -rf "$d"
}

case_same_name_blocks_disclosed() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-dupblocks.txt" "$FX/codex-failed.yaml" "$FX/recritic-missing.txt")"
  # 층 1: 블록 둘의 c0 은 글자까지 같아 하나로 흡수 → c0 · c5 둘. 층 2: c1 · c1@b2 · c2 셋. codex 는 실패 픽스처라 0.
  assert_eq "$(jget "$d/prep.json" 'len(d["items"])')" "5" "같은 이름 블록: 겹친 항목 하나만 빠지고 5건이 남는다"
  assert_eq "$(jget "$d/fin.json" 'd["degrade"].get("blocks_merged")')" "{'docreview-layer1': 2, 'docreview-layer2': 2}" "같은 이름 블록: 합친 개수가 degrade 에 남는다"
  assert_eq "$(jget "$d/fin.json" 'any("같은 이름 블록을 합쳤다" in a for a in d["advisory"])')" "True" "같은 이름 블록: 공시 줄"
  assert_eq "$(jget "$d/fin.json" '[a for a in d["advisory"] if "같은 이름 블록을 합쳤다" in a][0]')" "같은 이름 블록을 합쳤다 — 층 1 블록 2개 · 층 2 블록 2개 (docreview-layer1 · docreview-layer2)" "같은 이름 블록: 공시 줄은 쉬운 말이 먼저고 내부 이름은 괄호 안이다"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_absorbed"] >= 3, d["blocks"]')" "(True, False)" "같은 이름 블록: 블록 둘 + 겹친 항목 하나가 흡수로 세지고 막지 않는다"
  rm -rf "$d"
}
case_same_name_blocks_ref_collision() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-dupblocks.txt" "$FX/codex-failed.yaml" "$FX/recritic-missing.txt")"
  # 둘째 층 2 블록의 ask(c2)는 같은 블록의 c1(「목표 B 가 두 가지로」)을 막는다 — 첫 블록의 c1(「c.py 가 목록에 없다」)이 아니다.
  assert_eq "$(jget "$d/prep.json" '[i["blocks"] for i in d["items"] if "둘로 나누나" in i["summary"]][0] == [[i["f"] for i in d["items"] if "두 가지로 읽힌다" in i["summary"]][0]]')" "True" "같은 이름 블록: 겹친 임시 번호는 자기 블록 안에서 풀린다"
  rm -rf "$d"
}
case_same_name_blocks_absorbed_ref_resolves() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-dupblocks.txt" "$FX/codex-failed.yaml" "$FX/recritic-missing.txt")"
  # 둘째 층 1 블록이 다시 보낸 c0(흡수)을 c5 가 막는다 — blocks 는 살아남은 c0 의 번호로 풀려야 한다(떨어지면 안 된다).
  assert_eq "$(jget "$d/prep.json" '[i["blocks"] for i in d["items"] if "다른 문제를 겨눈다" in i["summary"]][0] == [[i["f"] for i in d["items"] if "범위 항목 하나를 조용히 뺐다" in i["summary"]][0]]')" "True" "같은 이름 블록: 흡수된 항목을 가리킨 blocks 는 살아남은 항목으로 풀린다"
  rm -rf "$d"
}
case_same_name_layer2_broken_kills_critic() {
  local d f; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; f="$d/critic-in.txt"
  { cat "$FX/critic-r1.txt"; printf '\n```docreview-layer2\n- ref: c9\n  summary: [깨진\n```\n'; } > "$f"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$f")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep.json"; local rc=$?
  assert_eq "$rc" "4" "층 2 블록이 파손이면 층 1 이 멀쩡해도 탐지 사망(rc 4)"
  rm -rf "$d"
}
case_recritic_two_blocks_last_wins_disclosed() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-r1.txt" "$FX/codex-failed.yaml" "$FX/recritic-two-blocks.txt.tmpl")"
  assert_eq "$(fsum "$d" 'c.py 가 목록에 없다' '["disposition"]')" "fix" "재비판 블록 둘: 마지막(confirm)이 판정 — 인용 예시(reject)가 판정이 되지 않는다"
  assert_eq "$(jget "$d/fin.json" 'any("재비판 블록 2개" in a for a in d["advisory"])')" "True" "재비판 블록 둘: 마지막만 읽었다는 공시"
  rm -rf "$d"
}
case_same_name_block_broken_kills_critic() {
  local d f; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; f="$d/critic-in.txt"
  { printf '```docreview-layer1\n- ref: c9\n  summary: [깨진\n```\n\n'; cat "$FX/critic-r1.txt"; } > "$f"  # 깨진 블록이 먼저, 멀쩡한 블록이 뒤 — 마지막 블록만 읽으면 통과해 버린다
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$f")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep.json"; local rc=$?
  assert_eq "$rc" "4" "같은 이름 블록 하나라도 파손 → 출력 전체가 탐지 사망(rc 4)"
  rm -rf "$d"
}
case_same_name_blocks_both_read() {
  local d; d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md" "$FX/critic-two-blocks-distinct.txt" "$FX/codex-failed.yaml" "$FX/recritic-missing.txt")"
  # 층 1 블록 둘이 서로 다른 성한 항목(c0 · c5)을 하나씩 담는다 — 첫 블록만 또는 마지막 블록만 읽으면 한쪽이 빠진다.
  assert_eq "$(jget "$d/prep.json" 'sorted(i["summary"] for i in d["items"])')" "['Non-goals 가 브리프의 범위 항목 하나를 조용히 뺐다', '목표가 브리프와 다른 문제를 겨눈다']" "같은 이름 블록 둘: 두 블록의 항목이 모두 요약 목록에 있다"
  assert_eq "$(jget "$d/fin.json" 'd["degrade"].get("blocks_merged")')" "{'docreview-layer1': 2}" "같은 이름 블록 둘: 합친 개수가 degrade 에 남는다"
  rm -rf "$d"
}
# ── AC14 — 파서는 줄인 플래그를 거부한다 ─────────────────────────────────
case_AC14_no_abbrev_flags() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC14: r1 실패"; return; }
  py docreview_state.py advice --state-dir "$d" --rend >/dev/null 2>&1; local rc=$?
  assert_eq "$rc" "2" "AC14: advice --rend(줄인 --render)는 사용법 오류 rc 2"
  py docreview_state.py gate --state-dir "$d" --rend >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "AC14: gate --rend 도 rc 2"
  py docreview_route.py finalize --state-dir "$d" --recritic-s >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "AC14: 라우터 finalize --recritic-s(줄인 --recritic-skipped)도 rc 2"
  py docreview_state.py gate --state-dir "$d" --render >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "0" "AC14 양성 짝: 온전한 플래그는 그대로 rc 0"
  rm -rf "$d"
}
# ── AC14 — brief 「## 6」 은 끝에 덧붙인 줄만이면 통과 ─────────────────────
case_AC14_append_only_passes() {
  local d s1 s2; d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC14: init 실패"; return; }
  s1="$d/s1.json"; snap "$FX/brief-append-r1.md" "$s1"
  put_snap "$d" "$s1" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  s2="$d/s2.json"; snap "$FX/brief-append-r2.md" "$s2"
  put_snap "$d" "$s2" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  py docreview_state.py exempt-anchors --state-dir "$d" > "$d/ex2.json"
  # yaml 은 -I 로는 안 보이는 사용자 site 에 있을 수 있다 — st_get.py(비-I)에 식을 넘기고 엔진은 PYTHONPATH 로 건다.
  local out; out="$(PYTHONPATH="$SCRIPTS" python3 "$FX/st_get.py" "$d/docreview-state.md" '(lambda D: ([c["anchor"] for c in D["changed"]], [e.get("scope") for e in D["exempt_applied"]]))(__import__("docreview_state").round_diff(st, __import__("docreview_state").load_profile(st["profile"]), 2))')"
  assert_eq "$out" "([], ['append-only'])" "AC14: 「## 6」 끝에 덧붙인 줄만이면 changed 가 없고 append-only 면제로 보인다"
  rm -rf "$d"
}
# ── AC2 — 불변 절은 0열 새 목록 항목만 추가로 본다(이어 쓴 줄은 바뀜) ──────────────
ac2_diff() {   # ac2_diff <round-2 doc> → 그 라운드 얼림 diff 의 (changed 앵커, 면제 scope)
  local d s1 s2; d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { echo "init-fail"; return; }
  s1="$d/s1.json"; snap "$FX/brief-append-r1.md" "$s1"
  put_snap "$d" "$s1" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  s2="$d/s2.json"; snap "$1" "$s2"
  put_snap "$d" "$s2" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  PYTHONPATH="$SCRIPTS" python3 "$FX/st_get.py" "$d/docreview-state.md" '(lambda D: ([c["anchor"] for c in D["changed"]], [e.get("scope") for e in D["exempt_applied"]]))(__import__("docreview_state").round_diff(st, __import__("docreview_state").load_profile(st["profile"]), 2))'
  rm -rf "$d"
}
case_AC2_append_new_item_only() {
  assert_eq "$(ac2_diff "$FX/brief-append-r2.md")" "([], ['append-only'])" "AC2 양성: 0열 새 항목을 덧붙이면 append-only 면제다"
  assert_eq "$(ac2_diff "$FX/brief-append-r2-blank.md")" "([], ['append-only'])" "AC2 양성: 빈 줄 뒤 새 항목도 append-only 면제다"
  assert_eq "$(ac2_diff "$FX/brief-append-r2-cont.md")" "(['#6-사용자-원문'], [])" "AC2 음성: 들여쓴 이어 쓴 줄은 바뀜이다"
  local d s1 res
  s1="$(mktemp -d -t docreview-XXXXXX)/s.json"; snap "$FX/brief-append-r1.md" "$s1"
  res="$(python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1],encoding="utf-8")); print(all(isinstance(s.get("item_marks"),str) and len(s["item_marks"])==len(s["line_hashes"]) for s in d["sections"]))' "$s1")"
  assert_eq "$res" "True" "AC2: 스냅숏의 모든 절에 line_hashes 와 같은 길이의 item_marks 가 있다"
  rm -rf "$(dirname "$s1")"
  d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC2: init 실패"; return; }
  snap "$FX/brief-append-r1.md" "$d/s1.json"; put_snap "$d" "$d/s1.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  assert_eq "$(st_yaml "$d" '[("item_marks" in s) for s in st["snapshots"]["1"]["sections"] if s["anchor"]=="#6-사용자-원문"]')" "[True]" "AC2: 원장 스냅숏의 불변 절에는 item_marks 가 있다"
  assert_eq "$(st_yaml "$d" '[s["anchor"] for s in st["snapshots"]["1"]["sections"] if "item_marks" in s]')" "['#6-사용자-원문']" "AC2: 불변 절 밖에는 item_marks 가 없다"
  rm -rf "$d"
  d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "AC2: design init 실패"; return; }
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1"; snap "$d/doc.md" "$d/s1.json"
  put_snap "$d" "$d/s1.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  assert_eq "$(st_yaml "$d" '[("item_marks" in s, "line_hashes" in s) for s in st["snapshots"]["1"]["sections"] if s["anchor"]=="#결정-기록"]')" "[(False, True)]" "AC2: 결정 기록 절에는 줄 해시만 있고 item_marks 는 없다"
  rm -rf "$d"
  d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC2: init 실패"; return; }
  snap "$FX/brief-append-r1.md" "$d/s1.json"; put_snap "$d" "$d/s1.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  # 닫힌 쪽 — item_marks 를 지운 원장은 새 항목 추가도 바뀜이다
  PYTHONPATH="$SCRIPTS" python3 -c 'import sys; from docreview_state import load_state, save_state; d=sys.argv[1]; st=load_state(d); [s.pop("item_marks", None) for s in st["snapshots"]["1"]["sections"]]; save_state(d, st, "fixture")' "$d"
  snap "$FX/brief-append-r2.md" "$d/s2.json"; put_snap "$d" "$d/s2.json" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  assert_eq "$(PYTHONPATH="$SCRIPTS" python3 "$FX/st_get.py" "$d/docreview-state.md" '[c["anchor"] for c in __import__("docreview_state").round_diff(st, __import__("docreview_state").load_profile(st["profile"]), 2)["changed"]]')" "['#6-사용자-원문']" "AC2 닫힌 쪽: item_marks 없는 원장은 새 항목 추가도 바뀜이다"
  rm -rf "$d"
}
case_AC14_append_only_plus_edit() {
  local d s1 s2; d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC14: init 실패"; return; }
  s1="$d/s1.json"; snap "$FX/brief-append-r1.md" "$s1"
  put_snap "$d" "$s1" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  s2="$d/s2.json"; snap "$FX/brief-append-r2-edit.md" "$s2"
  put_snap "$d" "$s2" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  # yaml 은 -I 로는 안 보이는 사용자 site 에 있을 수 있다 — st_get.py(비-I)에 식을 넘기고 엔진은 PYTHONPATH 로 건다.
  local out; out="$(PYTHONPATH="$SCRIPTS" python3 "$FX/st_get.py" "$d/docreview-state.md" '(lambda D: [c["anchor"] for c in D["changed"]])(__import__("docreview_state").round_diff(st, __import__("docreview_state").load_profile(st["profile"]), 2))')"
  assert_eq "$out" "['#6-사용자-원문']" "AC14: 이미 있는 원문 줄이 바뀌면 덧붙인 줄이 함께 있어도 frozen_change 대상이다"
  rm -rf "$d"
}
case_AC14_line_hashes_only_immutable() {
  local d s1; d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")" || { no "AC14: init 실패"; return; }
  s1="$d/s1.json"; snap "$FX/brief-append-r1.md" "$s1"
  put_snap "$d" "$s1" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  assert_eq "$(st_yaml "$d" 'sorted(s["anchor"] for s in st["snapshots"]["1"]["sections"] if "line_hashes" in s)')" "['#6-사용자-원문']" "AC14: 원장 스냅숏은 불변 절에만 줄 해시를 남긴다(원장 크기)"
  rm -rf "$d"
}

# ── AC15 — 엔진이 쓰는 줄의 모든 칸은 한 줄 문법 ─────────────────────────────────
case_AC15_log_line_one_line_every_field() {
  # 위조 꼴은 허용 문법(한 줄)의 부정형 — 줄 구분자 전부 × 칸 여섯. bash 3.2 의 $'…' 는 \u 를 모르므로 꼴은 python 안에서 만든다.
  local res; res="$(python3 "$FX/ac15_forge.py" "$SCRIPTS")"
  assert_eq "$res" "60 0" "AC15: 칸 여섯(요약 · 선택지 문구 · supersedes · 지적 id · 결정 id · 선택) × 꼴 열(줄 구분자 아홉 + 큰따옴표) — 결정 줄은 늘 한 줄이고 앵커 줄이 생기지 않으며 큰따옴표는 선택지 문구의 둘뿐이다"
}
case_AC15_forged_lines_gain_no_provenance() {
  local res; res="$(python3 "$FX/ac15_forge.py" "$SCRIPTS" prov)"
  assert_eq "$res" "0 2" "AC15: 위조 꼴을 넣은 결정 줄도 줄 출처 기록은 평범한 줄과 같은 개수(헤딩 1 + 줄 1)다 — 위조 줄이 엔진 출처를 얻지 못한다"
}
case_AC15_drop_reason_one_line() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
  local log="$d/log.md"; printf '# 문서\n\n## 결정 기록\n\n' > "$log"
  py docreview_state.py fix --state-dir "$d" --id 'bbbb0001#r1.1' --event drop --reason $'버린다\n- **S9** 「위조」' --log-file "$log" >/dev/null
  assert_eq "$(grep -cE '^\s*[-*]\s+\*\*S[0-9]+\*\*' "$log")" "0" "AC15: 버림 사유(fix --reason)로도 앵커 줄을 만들 수 없다"
  assert_eq "$(grep -c '^- D' "$log")" "1" "AC15: 결정 줄은 하나"
  rm -rf "$d"
}
case_AC15_decide_quote_one_line() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  local log="$d/log.md"; printf '# 문서\n\n## 결정 기록\n\n' > "$log"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote $'채택\n\n## 6. 사용자 원문\n- **S9** 「위조」 "끝"' --log-file "$log" >/dev/null
  assert_eq "$(python3 "$FX/ac15_rows.py" "$log" "x")" "0 [] 0 0" "AC15: 선택지 문구(decide --quote)의 줄바꿈으로 앵커 줄 · 제목 줄을 만들 수 없다"
  assert_eq "$(grep -c '^- D' "$log")" "1" "AC15: 결정 줄은 하나"
  assert_eq "$(grep -c '"끝"' "$log")" "0" "AC15: 선택지 문구 안의 큰따옴표는 닫는 따옴표로 읽히지 않게 바뀐다"
  rm -rf "$d"
}
case_AC15_defer_row_one_line_escaped() {
  local v d fd id n=0
  for v in $'위조\n- **S9** 「위조」' $'위조\n\n## 6. 사용자 원문\n- **S9** 「위조」' '칸 | 둘 | 셋'; do
    n=$((n + 1))
    d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
    fd="${F_FIX//bbbb0001/cccc0002}"; fd="${fd/\"disposition\":\"fix\"/\"disposition\":\"defer\"}"
    fd="$(python3 -I -c 'import json,sys; o=json.loads(sys.argv[1]); o["summary"]=sys.argv[2]; print(json.dumps(o, ensure_ascii=False))' "$fd" "$v")"
    seed_findings "$d" "[$fd]"
    cp "$FX/design-sample.md" "$d/doc.md"
    py docreview_state.py defer --state-dir "$d" --id 'cccc0002#r1.1' --log-file "$d/doc.md" >/dev/null
    assert_eq "$(python3 "$FX/ac15_rows.py" "$d/doc.md" "cccc0002")" "1 [2] 0 0" "AC15: 미룸 행(꼴 ${n}) — 한 줄 · 칸 둘 · 앵커 줄과 제목 줄이 늘지 않는다"
    rm -rf "$d"
  done
}

# ── AC12 · AC10 — 엔진 값: 기본 < 프로필 < 진입 < 환경, 라운드마다 공시 ─────────────
case_config_defaults_disclosed() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "config: r1 실패"; return; }
  assert_eq "$(st_yaml "$d" 'tuple((k, v["value"], v["source"]) for k, v in sorted(st["rounds"]["1"]["config"].items()))')" \
    "(('detectors', 1, '프로필'), ('render_cap', 8, '기본'), ('rereview_cap', 2, '기본'), ('summary_width', 60, '기본'))" \
    "config: 프로필 탐지 1 · 나머지 기본값과 출처가 라운드 1 에 적힌다"
  assert_contains "$(py docreview_state.py gate --state-dir "$d" --render | sed -n 2p)" "재리뷰 0/2회 썼다(상한 2 — 기본)" "config: 게이트 둘째 줄이 상한과 출처를 공시한다"
  assert_contains "$(py docreview_state.py gate --state-dir "$d" --render | sed -n 2p)" "탐지 리뷰어 1명(프로필)" "config: 탐지 수와 출처도 같은 줄에"
  assert_contains "$(py docreview_state.py gate --state-dir "$d" --render | sed -n 2p)" "참고 목록 8줄(기본) · 요약 60자(기본)" "config: 참고 목록 줄 수와 요약 폭도 출처와 함께 같은 줄에"
  rm -rf "$d"
}
case_config_env_wins() {
  local d s; d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "config: init 실패"; return; }
  s="$d/s1.json"; snap "$FX/design-sample.md" "$s"
  local out; out=""; put_snap "$d" "$s" && out="$(DEVBREW_DOCREVIEW_DETECTORS=3 DEVBREW_DOCREVIEW_REREVIEW_CAP=0 py docreview_state.py begin-round --state-dir "$d" --detectors 2)"
  assert_eq "$(printf '%s' "$out" | jgets 'd["config"]["detectors"]["value"], d["config"]["detectors"]["source"], d["config"]["rereview_cap"]["value"]')" "(3, '환경', 0)" "config: 환경이 진입(--detectors 2)과 프로필을 이긴다"
  put_snap "$d" "$s" && DEVBREW_DOCREVIEW_REREVIEW_CAP=0 py docreview_state.py begin-round --state-dir "$d" >/dev/null 2>&1; local rc=$?
  assert_eq "$rc" "3" "config: 상한 0 이면 라운드 2 는 승인 없이 rc 3"
  rm -rf "$d"
}
case_config_entry_beats_profile() {
  local d s; d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "config: init 실패"; return; }
  s="$d/s1.json"; snap "$FX/design-sample.md" "$s"
  put_snap "$d" "$s" && assert_eq "$(env -u DEVBREW_DOCREVIEW_DETECTORS python3 "$SCRIPTS/docreview_state.py" begin-round --state-dir "$d" --detectors 2 | jgets 'd["config"]["detectors"]["value"], d["config"]["detectors"]["source"]')" "(2, '진입')" "config: 진입 선언이 프로필(1)을 이긴다"
  rm -rf "$d"
}
case_config_invalid_refused() {
  local d s; d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "config: init 실패"; return; }
  s="$d/s1.json"; snap "$FX/design-sample.md" "$s"
  local err rc; err=""; put_snap "$d" "$s" && err="$(DEVBREW_DOCREVIEW_DETECTORS=two py docreview_state.py begin-round --state-dir "$d" 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc" "2" "config: 정수가 아닌 환경 값은 라운드를 시작하지 않는다(rc 2)"
  assert_contains "$err" '"reason": "config_invalid"' "config: 사유 이름"
  assert_contains "$err" "DEVBREW_DOCREVIEW_DETECTORS" "config: 변수 이름을 낸다"
  assert_contains "$err" '"value": "two"' "config: 거부된 값도 낸다"
  # 값마다 int() 로는 상한(1~6) 안의 정수다 — 범위 검사가 아니라 ASCII 숫자 검사만 거절하게 한다
  for bad in 0_3 ' 2' '+2' '２'; do
    put_snap "$d" "$s" && DEVBREW_DOCREVIEW_DETECTORS="$bad" py docreview_state.py begin-round --state-dir "$d" >/dev/null 2>&1; rc=$?
    assert_eq "$rc" "2" "config: 환경 값 '${bad}' 은 엄격한 정수가 아니라 거부된다"
  done
  # 앞자리가 0 이 아닌 밑줄 값 — 조언 줄 수 상한(1~100) 안이라(int 로 10) 밑줄 검사만 거절한다
  put_snap "$d" "$s" && DEVBREW_DOCREVIEW_RENDER_CAP=1_0 py docreview_state.py begin-round --state-dir "$d" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "config: 환경 값 RENDER_CAP='1_0' 은 상한 안이지만 엄격한 정수가 아니라 거부된다"
  assert_eq "$(st_yaml "$d" 'st["round"]')" "0" "config: 거부는 원장을 바꾸지 않는다"
  put_snap "$d" "$s" && DEVBREW_DOCREVIEW_RENDER_CAP=0 py docreview_state.py begin-round --state-dir "$d" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "config: 조언 줄 수 0 은 범위 밖"
  rm -rf "$d"
}
case_config_maximum_refused() {
  local d s err rc; d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "max: init 실패"; return; }
  s="$d/s1.json"; snap "$FX/design-sample.md" "$s"
  err=""; put_snap "$d" "$s" && err="$(DEVBREW_DOCREVIEW_DETECTORS=500 py docreview_state.py begin-round --state-dir "$d" 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc" "2" "max: 최댓값을 넘는 환경 값은 라운드를 시작하지 않는다(rc 2)"
  assert_contains "$err" '"reason": "config_invalid"' "max: 사유 이름"
  assert_contains "$err" '"allowed": "1~6"' "max: 허용 범위를 낸다"
  assert_contains "$err" 'DEVBREW_DOCREVIEW_DETECTORS' "max: 출처(변수 이름)를 낸다"
  assert_eq "$(st_yaml "$d" 'st["round"]')" "0" "max: 거부는 원장을 바꾸지 않는다"
  for kv in DEVBREW_DOCREVIEW_REREVIEW_CAP=11 DEVBREW_DOCREVIEW_RENDER_CAP=101 DEVBREW_DOCREVIEW_SUMMARY_WIDTH=501; do
    put_snap "$d" "$s" && env "$kv" python3 "$SCRIPTS/docreview_state.py" begin-round --state-dir "$d" >/dev/null 2>&1; rc=$?
    assert_eq "$rc" "2" "max: ${kv} 는 최댓값+1 이라 거부된다"
  done
  for kv in DEVBREW_DOCREVIEW_DETECTORS=6 DEVBREW_DOCREVIEW_REREVIEW_CAP=10 DEVBREW_DOCREVIEW_RENDER_CAP=100 DEVBREW_DOCREVIEW_SUMMARY_WIDTH=500; do
    local d2; d2="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")"
    put_snap "$d2" "$s" && env "$kv" python3 "$SCRIPTS/docreview_state.py" begin-round --state-dir "$d2" >/dev/null 2>&1; rc=$?
    assert_eq "$rc" "0" "max 양성 짝: ${kv} 는 최댓값 그대로라 받는다"; rm -rf "$d2"
  done
  err=""; put_snap "$d" "$s" && err="$(env -u DEVBREW_DOCREVIEW_DETECTORS python3 "$SCRIPTS/docreview_state.py" begin-round --state-dir "$d" --detectors 7 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc" "2" "max: --detectors 7 은 거부된다"
  assert_contains "$err" '"where": "진입"' "max: 진입 출처를 낸다"
  local p; p="$(mktemp -d -t prof-XXXXXX)"
  python3 -I -c 'import sys; t=open(sys.argv[1],encoding="utf-8").read(); t=t.replace("detectors: 1\n","detectors: 1\nrereview_cap: 11\n",1); open(sys.argv[2],"w",encoding="utf-8").write(t)' "$PROF_SD/design-doc.md" "$p/design-doc.md"
  err="$(py docreview_state.py profile-check "$p/design-doc.md" 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc" "2" "max: 프로필 rereview_cap 11 은 거부된다"
  assert_contains "$err" "config_invalid" "max: 프로필 사유 이름"
  assert_contains "$err" "0~10" "max: 프로필 메시지에 0~10 (최솟값 0)"
  assert_not_contains "$err" "1~10" "max: 최솟값을 1 로 잘못 적지 않는다"
  rm -rf "$p"
  err="$(env -u DEVBREW_DOCREVIEW_RENDER_CAP python3 "$SCRIPTS/docreview_state.py" advice --state-dir "$d" --render --cap 101 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc" "2" "max: advice --cap 101 은 거부된다"
  assert_contains "$err" '"reason": "config_invalid"' "max: advice 사유 이름"
  err="$(env -u DEVBREW_DOCREVIEW_RENDER_CAP python3 "$SCRIPTS/docreview_state.py" advice --state-dir "$d" --render --cap 100 2>&1 >/dev/null)"
  assert_not_contains "$err" 'config_invalid' "max 양성 짝: advice --cap 100 은 이 사유로 거부되지 않는다"
  rm -rf "$d"
}
case_config_changes_between_rounds() {
  local d s; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "config: r1 실패"; return; }
  s="$d/s2.json"; snap "$FX/design-sample.md" "$s"
  put_snap "$d" "$s" && DEVBREW_DOCREVIEW_DETECTORS=2 py docreview_state.py begin-round --state-dir "$d" >/dev/null
  assert_eq "$(st_yaml "$d" 'st["rounds"]["1"]["config"]["detectors"]["value"], st["rounds"]["2"]["config"]["detectors"]["value"], st["rounds"]["2"]["config"]["detectors"]["source"]')" "(1, 2, '환경')" "config: 라운드마다 따로 적히고 앞 라운드 기록은 그대로다"
  rm -rf "$d"
}
case_config_profile_fields() {
  local p; p="$(mktemp -d -t prof-XXXXXX)"
  python3 -I -c 'import sys; t=open(sys.argv[1],encoding="utf-8").read(); t=t.replace("detectors: 1\n","detectors: 2\nrereview_cap: 4\nrender_cap: 12\nsummary_width: 80\n",1); open(sys.argv[2],"w",encoding="utf-8").write(t)' "$PROF_SD/design-doc.md" "$p/design-doc.md"
  local d s; d="$(mk_state "$FX/design-sample.md" "$p/design-doc.md")" || { no "config: init 실패"; rm -rf "$p"; return; }
  s="$d/s1.json"; snap "$FX/design-sample.md" "$s"
  put_snap "$d" "$s" && assert_eq "$(env -u DEVBREW_DOCREVIEW_DETECTORS -u DEVBREW_DOCREVIEW_REREVIEW_CAP -u DEVBREW_DOCREVIEW_RENDER_CAP -u DEVBREW_DOCREVIEW_SUMMARY_WIDTH python3 "$SCRIPTS/docreview_state.py" begin-round --state-dir "$d" | jgets 'tuple((k, v["value"], v["source"]) for k, v in sorted(d["config"].items()))')" \
    "(('detectors', 2, '프로필'), ('render_cap', 12, '프로필'), ('rereview_cap', 4, '프로필'), ('summary_width', 80, '프로필'))" "config: 프로필 필드 넷이 먹는다"
  rm -rf "$d" "$p"
}
case_config_profile_string_refused() {
  local p; p="$(mktemp -d -t prof-XXXXXX)"
  python3 -I -c 'import sys; t=open(sys.argv[1],encoding="utf-8").read(); t=t.replace("detectors: 1\n","detectors: 1\nrender_cap: \"8\"\n",1); open(sys.argv[2],"w",encoding="utf-8").write(t)' "$PROF_SD/design-doc.md" "$p/design-doc.md"
  py docreview_state.py profile-check "$p/design-doc.md" >/dev/null 2>&1; local rc=$?
  assert_eq "$rc" "2" "config: 프로필의 문자열 값(render_cap: \"8\")은 정수형이 아니라 거부된다"
  python3 -I -c 'import sys; t=open(sys.argv[1],encoding="utf-8").read(); t=t.replace("detectors: 1\n","detectors: 1\nrender_cap: true\n",1); open(sys.argv[2],"w",encoding="utf-8").write(t)' "$PROF_SD/design-doc.md" "$p/design-doc.md"
  py docreview_state.py profile-check "$p/design-doc.md" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "config: 프로필의 true 도 거부된다"
  rm -rf "$p"
}
case_config_rereview_count_never_decreases() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "config: r1 실패"; return; }
  next_round "$d" "$FX/design-sample.md" >/dev/null; next_round "$d" "$FX/design-sample.md" >/dev/null
  assert_eq "$(st_yaml "$d" 'st["round"], st["rereview_count"]')" "(3, 2)" "config: 라운드 3 까지 재리뷰 2회"
  local s="$d/s4.json"; snap "$FX/design-sample.md" "$s"
  put_snap "$d" "$s" && DEVBREW_DOCREVIEW_REREVIEW_CAP=1 py docreview_state.py begin-round --state-dir "$d" --extra-approval "승인 인용" --extra-approval-source typed >/dev/null
  assert_eq "$(st_yaml "$d" 'st["round"], st["rereview_count"]')" "(4, 2)" "config: 상한을 낮춘 뒤 추가 승인으로 돈 라운드 4 도 재리뷰 횟수는 줄지 않는다"
  rm -rf "$d"
}
# ── AC10 · AC11 — 탐지 리뷰어 여럿 ───────────────────────────────────────
r1_detectors() {   # r1_detectors <N> <profile> <doc> → round 1 begun with N detectors (환경으로)
  local d s; d="$(mk_state "$3" "$2")" || return 1; s="$d/s1.json"; snap "$3" "$s"
  DEVBREW_DOCREVIEW_DETECTORS="$1" py docreview_state.py begin-round --state-dir "$d" >/dev/null; echo "$d"
}
case_detectors_merge_and_source() {
  local d; d="$(r1_detectors 2 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC10: r1 실패"; return; }
  local c1 c2; c1="$(critic_now "$d" "$FX/critic-r1.txt")"; cp "$FX/critic-d2.txt" "$d/critic-2.txt"; c2="$d/critic-2.txt"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$c1" --critic "$c2" --codex "$(codex_now "$d" "$FX/codex-r1.yaml")" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" 'any("detector" in i for i in d["items"])')" "False" "AC10: 재비판 입력에는 출처 리뷰어가 없다(익명화)"
  assert_eq "$(st_yaml "$d" 'sorted({p["finding"].get("detector") for p in st["pending_recritic"]["items"] if p["source"]=="critic"})')" "['d1', 'd2']" "AC10: 원장 준비에는 리뷰어마다 출처가 있다"
  assert_eq "$(st_yaml "$d" '[p["finding"]["blocks"] for p in st["pending_recritic"]["items"] if p["finding"]["summary"].startswith("넘김 절의 경로")][0] == [[p["f"] for p in st["pending_recritic"]["items"] if p["finding"]["summary"].startswith("넘김 절에 이어")][0]]')" "True" "AC10: 둘째 리뷰어의 질문은 자기 c1 을 막는다(번호 충돌 없음)"
  rm -rf "$d"
}
case_detectors_partial_death() {
  local d; d="$(r1_detectors 3 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC11: r1 실패"; return; }
  local c1 c2; c1="$(critic_now "$d" "$FX/critic-r1.txt")"; cp "$FX/critic-d2.txt" "$d/critic-2.txt"; c2="$d/critic-2.txt"
  cp "$FX/critic-broken.txt" "$d/critic-3.txt"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$c1" --critic "$c2" --critic "$d/critic-3.txt" > "$d/prep.json"; local rc=$?
  assert_eq "$rc" "0" "AC11: 일부 사망은 라운드를 죽이지 않는다(rc 0)"
  assert_eq "$(jget "$d/prep.json" 'd["degrade"]["detectors"]["expected"], d["degrade"]["detectors"]["dead"], d["degrade"]["critic_dead"]')" "(3, [3], False)" "AC11: 탐지 3 중 셋째 사망 · 주 판정자 사망 아님"
  py docreview_route.py finalize --state-dir "$d" --recritic-skipped --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_contains "$(jget "$d/fin.json" '" | ".join(d["advisory"])')" "탐지 3 중 1 사망" "AC11: 라우팅 보고가 degrade 로 공시한다"
  assert_contains "$(py docreview_state.py gate --state-dir "$d" --render | head -1)" "탐지 리뷰어 3명 중 1명이 결과를 내지 못했다" "AC11: 게이트 첫 줄 경고가 쉬운 말로 말한다"
  rm -rf "$d"
}
case_detectors_all_dead() {
  local d; d="$(r1_detectors 2 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC11: r1 실패"; return; }
  cp "$FX/critic-broken.txt" "$d/critic-1.txt"; cp "$FX/critic-broken.txt" "$d/critic-2.txt"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$d/critic-1.txt" --critic "$d/critic-2.txt" > "$d/prep.json"; local rc=$?
  assert_eq "$rc" "4" "AC11: 전부 죽으면 지금처럼 critic 사망 rc 4"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | jgets 'd["unverified"]')" "critic_dead" "AC11: 게이트는 「미검증」"
  rm -rf "$d"
}
case_detectors_count_mismatch() {
  local d; d="$(r1_detectors 2 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC10: r1 실패"; return; }
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-r1.txt")" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" 'd["degrade"]["detectors"]["expected"], d["degrade"]["detectors"]["dead"]')" "(2, [2])" "AC10: 기대 2 인데 파일 1 이면 빠진 둘째를 사망으로 센다(조용히 1 로 줄이지 않는다)"
  rm -rf "$d"
}
case_detectors_dangling_block_no_tag_leak() {
  local d; d="$(r1_detectors 2 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC10: r1 실패"; return; }
  local c1; c1="$(critic_now "$d" "$FX/critic-r1.txt")"; cp "$FX/critic-d2-dangling.txt" "$d/critic-2.txt"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$c1" --critic "$d/critic-2.txt" > "$d/prep.json"
  assert_eq "$(grep -c '@d' "$d/prep.json")" "0" "AC10: 재비판 입력 전체에 리뷰어 꼬리표(@d)가 없다(없는 항목을 막는 참조 포함)"
  assert_eq "$(grep -c '@b' "$d/prep.json")" "0" "AC10: 블록 꼬리표(@b)도 없다"
  assert_eq "$(jget "$d/prep.json" '[i["blocks"] for i in d["items"] if "없는 항목 참조" in i["summary"]]')" "[['c9']]" "AC10: 풀리지 않는 참조는 꼬리표를 뗀 중립 형태로 남는다(최종 단계가 어차피 버린다)"
  rm -rf "$d"
}
case_detectors_overlap_absorbed() {
  local d1 d2 n1 n2
  d1="$(r1_detectors 1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC10: r1 실패"; return; }
  py docreview_route.py prepare-recritic --state-dir "$d1" --critic "$(critic_now "$d1" "$FX/critic-r1.txt")" > "$d1/prep.json"
  n1="$(jget "$d1/prep.json" 'len(d["items"])')"
  d2="$(r1_detectors 2 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC10: r1 실패"; return; }
  critic_now "$d2" "$FX/critic-r1.txt" >/dev/null; cp "$FX/critic-r1.txt" "$d2/critic-2.txt"
  py docreview_route.py prepare-recritic --state-dir "$d2" --critic "$d2/critic.txt" --critic "$d2/critic-2.txt" > "$d2/prep.json"
  assert_eq "$(jget "$d2/prep.json" 'len(d["items"])')" "$n1" "AC10: 같은 지적 둘은 하나로 센다(두 배가 되지 않는다)"
  assert_eq "$(st_yaml "$d2" 'len([e for e in st["pending_recritic"]["events"] if e[0]=="absorbed"])')" "$n1" "AC10: 버려진 중복 하나하나를 흡수로 센다"
  rm -rf "$d1" "$d2"
}
case_detectors_overlap_malformed_notice_follows_contradicts() {
  local d c1 c2 mk
  mk() {   # mk <파일> <contradicts 줄 또는 빈 값> — 같은 지적 하나
    printf '%s\n' '```docreview-layer1' '[]' '```' '```docreview-layer2' '- ref: c1' '  layer: 2' '  category: placeholder' '  anchor: "#handoff-context"' '  disposition: fix' '  summary: "넘김 절에 경로가 없다"' '  edit_scope: "#handoff-context"' ${2:+"$2"} '```' > "$1"
  }
  d="$(r1_detectors 2 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC10: r1 실패"; return; }
  c1="$d/critic-1.txt"; c2="$d/critic-2.txt"
  mk "$c1" '  contradicts: D1.1'; mk "$c2" '  contradicts: "형식 아님 !"'
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$c1" --critic "$c2" > "$d/prep.json"
  assert_eq "$(st_yaml "$d" 'len(st["pending_recritic"]["items"])')" "1" "AC10: 전제 — 같은 지적 둘은 하나로 합쳐진다"
  assert_eq "$(st_yaml "$d" 'bool(st["pending_recritic"]["items"][0]["finding"].get("_contradicts_malformed"))')" "False" "AC39: 유효한 번호를 단 남은 항목은 버려진 사본의 형식 위반 표시를 물려받지 않는다"
  assert_eq "$(jget "$d/prep.json" 'sorted(k for i in d["items"] for k in i if k.startswith("_"))')" "[]" "AC10: 재비판자에게 가는 항목에 엔진 내부 칸(_ 시작)이 없다"
  mk "$c1" ''; mk "$c2" '  contradicts: "형식 아님 !"'
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$c1" --critic "$c2" > "$d/prep.json"
  assert_eq "$(st_yaml "$d" 'bool(st["pending_recritic"]["items"][0]["finding"].get("_contradicts_malformed"))')" "True" "AC39 양성 짝: 남은 항목에 번호가 없으면 버려진 사본의 형식 위반 표시를 물려받는다"
  rm -rf "$d"
}
case_detectors_overlap_repoints_blocks() {
  local d; d="$(r1_detectors 2 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC10: r1 실패"; return; }
  cp "$FX/critic-d1-only.txt" "$d/critic-1.txt"; cp "$FX/critic-d2.txt" "$d/critic-2.txt"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$d/critic-1.txt" --critic "$d/critic-2.txt" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" 'len(d["items"])')" "2" "AC10: 겹치는 첫째 지적은 하나만 남는다"
  assert_eq "$(jget "$d/prep.json" '[i["blocks"] for i in d["items"] if i["summary"].startswith("넘김 절의 경로")][0] == [i["f"] for i in d["items"] if i["summary"].startswith("넘김 절에 이어")]')" "True" "AC10: 버려진 지적을 막던 질문은 남은 지적을 막는다"
  assert_eq "$(st_yaml "$d" 'sorted(p["finding"]["detector"] for p in st["pending_recritic"]["items"])')" "['d1', 'd2']" "AC10: 남은 것은 가장 앞 리뷰어의 지적이다"
  rm -rf "$d"
}
case_detectors_overlap_keeps_both_blocks() {
  local d; d="$(r1_detectors 2 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC10: r1 실패"; return; }
  cp "$FX/critic-d1-blocks.txt" "$d/critic-1.txt"; cp "$FX/critic-d2-blocks.txt" "$d/critic-2.txt"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$d/critic-1.txt" --critic "$d/critic-2.txt" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" 'len(d["items"])')" "3" "AC10: 같은 질문 하나와 서로 다른 고침 둘이 남는다"
  assert_eq "$(jget "$d/prep.json" '[len(i["blocks"]) for i in d["items"] if i["summary"].startswith("넘김 절의 경로")][0]')" "2" "AC10: 흡수된 사본이 막던 고침도 남은 질문이 계속 막는다(막는 항목 둘)"
  rm -rf "$d"
}
case_detectors_identical_pair_counts_blocks_once() {
  local d; d="$(r1_detectors 2 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC10: r1 실패"; return; }
  cp "$FX/critic-d2.txt" "$d/critic-1.txt"; cp "$FX/critic-d2.txt" "$d/critic-2.txt"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$d/critic-1.txt" --critic "$d/critic-2.txt" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" '[len(i["blocks"]) for i in d["items"] if i["summary"].startswith("넘김 절의 경로")][0]')" "1" "AC10: 두 리뷰어가 같은 질문과 고침을 내도 막는 항목은 하나로 센다"
  rm -rf "$d"
}
case_same_as_merge_counts_blocked_fix_once() {
  local d cr rt f1 f2; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC10: r1 실패"; return; }
  cr="$d/critic-src.txt"
  printf '%s\n' '```docreview-layer1' '[]' '```' '```docreview-layer2' '- ref: c1' '  layer: 2' '  category: placeholder' '  anchor: "#handoff-context"' '  disposition: fix' '  summary: "넘김 절에 경로가 없다"' '  edit_scope: "#handoff-context"' '- ref: c2' '  layer: 2' '  category: placeholder' '  anchor: "#handoff-context"' '  disposition: fix' '  summary: "넘김 절에 이어 갈 위치가 없다"' '  edit_scope: "#handoff-context"' '- ref: c3' '  layer: 2' '  category: ambiguity' '  anchor: "#handoff-context"' '  disposition: ask' '  summary: "넘김 절의 경로를 어디로 둘지 정해야 한다"' '  blocks: [c1, c2]' '```' > "$cr"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$cr")" > "$d/prep.json"
  f1="$(jget "$d/prep.json" "[i['f'] for i in d['items'] if i['summary']=='넘김 절에 경로가 없다'][0]")"
  f2="$(jget "$d/prep.json" "[i['f'] for i in d['items'] if i['summary']=='넘김 절에 이어 갈 위치가 없다'][0]")"
  rt="$d/rt.txt"
  printf '```docreview-recritic\nverdicts:\n  - f: "%s"\n    verdict: confirm\n    same_as: ["%s"]\nadded: []\n```\n' "$f2" "$f1" > "$rt"
  py docreview_route.py finalize --state-dir "$d" --recritic "$rt" --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" '[len(x["blocks"]) for x in d["findings"] if x["category"]=="ambiguity"][0]')" "1" "AC10: 재비판이 두 고침을 하나로 묶어도 질문이 막는 항목은 한 번만 센다"
  rm -rf "$d"
}
case_AC4_recritic_same_as_keeps_blocks() {
  local d cr rt f3 f4; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC4: r1 실패"; return; }
  cr="$d/critic-src.txt"
  printf '%s\n' '```docreview-layer1' '[]' '```' '```docreview-layer2' '- ref: c1' '  layer: 2' '  category: placeholder' '  anchor: "#handoff-context"' '  disposition: fix' '  summary: "넘김 절에 경로가 없다"' '  edit_scope: "#handoff-context"' '- ref: c2' '  layer: 2' '  category: placeholder' '  anchor: "#handoff-context"' '  disposition: fix' '  summary: "넘김 절에 이어 갈 위치가 없다"' '  edit_scope: "#handoff-context"' '- ref: c3' '  layer: 2' '  category: ambiguity' '  anchor: "#handoff-context"' '  disposition: ask' '  summary: "넘김 절의 경로를 어디로 둘지 정해야 한다"' '  blocks: [c1]' '- ref: c4' '  layer: 2' '  category: ambiguity' '  anchor: "#handoff-context"' '  disposition: ask' '  summary: "경로를 어느 쪽에 둘지 못 박아야 한다"' '  blocks: [c2]' '```' > "$cr"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$cr")" > "$d/prep.json"
  f3="$(jget "$d/prep.json" "[i['f'] for i in d['items'] if i['summary'].startswith('넘김 절의 경로를')][0]")"
  f4="$(jget "$d/prep.json" "[i['f'] for i in d['items'] if i['summary'].startswith('경로를 어느')][0]")"
  rt="$d/rt.txt"
  printf '```docreview-recritic\nverdicts:\n  - f: "%s"\n    verdict: confirm\n    same_as: ["%s"]\nadded: []\n```\n' "$f4" "$f3" > "$rt"
  py docreview_route.py finalize --state-dir "$d" --recritic "$rt" --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" 'len([x for x in d["findings"] if x["category"]=="ambiguity"])')" "1" "AC4: 같은 질문 둘이 하나로 묶인다"
  assert_eq "$(jget "$d/fin.json" '[len(x["blocks"]) for x in d["findings"] if x["category"]=="ambiguity"][0]')" "2" "AC4: 재비판이 묶은 질문은 두 쪽이 막던 고침을 둘 다 계속 막는다"
  assert_eq "$(jget "$d/fin.json" 'sorted([x["id"] for x in d["findings"] if x["category"]=="placeholder"]) == sorted([b for x in d["findings"] if x["category"]=="ambiguity" for b in x["blocks"]])')" "True" "AC4: 막는 항목은 두 고침의 id 다"
  rm -rf "$d"
}
case_AC5_multi_anchor_held() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC5: r1 실패"; return; }
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-multi-anchor.txt")" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" 'len(d["items"])')" "0" "AC5: 앵커 둘을 이은 범위 항목은 받지 않는다"
  py docreview_route.py finalize --state-dir "$d" --recritic-skipped --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_held"] >= 1, d["blocks"]')" "(True, True)" "AC5: 보류로 세고 막는다"
  assert_contains "$(jget "$d/fin.json" '"\n".join(d["advisory"])')" "edit_scope_multi_anchor" "AC5: 이유 이름이 경고에 든다"
  assert_contains "$(py docreview_state.py gate --state-dir "$d" --render)" "edit_scope_multi_anchor" "AC5: 게이트 출력에 보인다"
  rm -rf "$d"
  d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC5: r1 실패"; return; }
  sed 's/#2-goals, #3-non-goals/#2-goals #3-non-goals/' "$FX/critic-multi-anchor.txt" > "$d/critic-ws.txt"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$d/critic-ws.txt")" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" 'len(d["items"])')" "0" "AC5: 공백으로만 이은 꼴도 받지 않는다"
  rm -rf "$d"
  d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC5: r1 실패"; return; }
  sed 's/edit_scope: "#2-goals, #3-non-goals"/edit_scope: "insert-after:#2-goals"/' "$FX/critic-multi-anchor.txt" > "$d/critic-one.txt"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$d/critic-one.txt")" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" 'len(d["items"])')" "1" "AC5 양성 짝: 앵커 하나(insert-after)는 보류되지 않는다"
  rm -rf "$d"
}
# AC6 보조 — 2 라운드 흐름: 지적을 «결정»으로 채택하고 그 절 본문을 고친 다음 라운드를 열어 관측을 낸다.
# ac6_round2 <state-dir> <finding-id> <doc2> → "<적용으로 관측> | <만료로 관측> | <게이트의 blocked_expired 수>"
ac6_round2() {
  local sd="$1" id="$2" doc2="$3"
  py docreview_state.py decide --state-dir "$sd" --id "$id" --choice adopt --quote '채택' >/dev/null
  next_round "$sd" "$doc2" >/dev/null
  printf '%s | %s | %s' "$(jget "$sd/obs2.json" "d['applied'] == ['$id']")" \
    "$(jget "$sd/obs2.json" "d['expired'] == ['$id']")" \
    "$(py docreview_state.py gate --state-dir "$sd" | jgets 'len(d["blocked_expired"])')"
}
case_AC6_section_sign_anchor_normalized() {
  local d doc doc2 cr eng id sd; d="$(mktemp -d -t docreview-XXXXXX)" || { no "AC6: mktemp 실패"; return; }
  doc="$d/doc.md"; { cat "$FX/design-sample.md"; printf '\n### §B 부분\n\n본문.\n'; } > "$doc"
  doc2="$d/doc2.md"; { cat "$FX/design-sample.md"; printf '\n### §B 부분\n\n본문을 고쳤다.\n'; } > "$doc2"
  snap "$doc" "$d/probe.json"
  eng="$(jget "$d/probe.json" '[s["anchor"] for s in d["sections"] if "부분" in s["anchor"]][0]')"
  sd="$(r1 "$PROF_SD/design-doc.md" "$doc")" || { no "AC6: r1 실패"; return; }
  cr="$d/critic-sign.txt"
  printf '%s\n' '```docreview-layer1' '[]' '```' '```docreview-layer2' '- ref: c1' '  category: placeholder' '  anchor: "#§b-부분"' '  disposition: fix' '  summary: "부분 절에 내용이 없다"' '  edit_scope: "#§b-부분"' '```' > "$cr"
  py docreview_route.py prepare-recritic --state-dir "$sd" --critic "$(critic_now "$sd" "$cr")" > "$sd/prep.json"
  py docreview_route.py finalize --state-dir "$sd" --recritic-skipped --doc "$doc" > "$sd/fin.json"
  assert_eq "$(jget "$sd/fin.json" '[x["anchor"] for x in d["findings"] if "부분 절" in x["summary"]][0]')" "$eng" "AC6: 지적의 앵커가 엔진 앵커와 같다"
  assert_eq "$(jget "$sd/fin.json" 'd["adjudication_coerced"]')" "1" "AC6: 바꾼 값은 강제로 센다(앵커와 범위가 같은 글자면 한 번)"
  id="$(jget "$sd/fin.json" '[x["id"] for x in d["findings"] if "부분 절" in x["summary"]][0]')"
  assert_eq "$(py docreview_anchor.py check-intent "$id" --intent "$eng" --state-dir "$sd" | jgets 'd["ok"]')" "True" "AC6: 엔진 앵커로 고친 범위가 check-intent 를 통과한다"
  assert_eq "$(py docreview_anchor.py check-intent "$id" --intent '#§b-부분' --state-dir "$sd" 2>/dev/null | jgets 'd["ok"]')" "False" "AC6 양성 짝: 날 § 앵커로 신고한 범위는 check-intent 가 거부한다"
  rm -rf "$sd"
  # 2 라운드 — 지적을 결정으로 채택하고 그 절 본문을 고친 다음 라운드를 열어 관측을 본다.
  sd="$(r1 "$PROF_SD/design-doc.md" "$doc")" || { no "AC6: r1 실패"; return; }
  sed 's/disposition: fix/disposition: decide/; s/category: placeholder/category: ambiguity/' "$cr" > "$sd/critic-dec.txt"
  py docreview_route.py prepare-recritic --state-dir "$sd" --critic "$(critic_now "$sd" "$sd/critic-dec.txt")" > "$sd/prep.json"
  py docreview_route.py finalize --state-dir "$sd" --recritic-skipped --doc "$doc" > "$sd/fin.json"
  id="$(jget "$sd/fin.json" '[x["id"] for x in d["findings"] if "부분 절" in x["summary"]][0]')"
  assert_eq "$(ac6_round2 "$sd" "$id" "$doc2")" "True | False | 0" "AC6: 엔진 앵커로 채택하고 그 절을 고치면 다음 라운드에 적용으로 관측된다(만료 · 재상승 없음)"
  rm -rf "$sd"
  # 양성 짝 — 정규화를 건너뛴 날 앵커로 심은 결정은 채택 단계에서 거부된다(앵커가 문서에 없다).
  sd="$(r1 "$PROF_SD/design-doc.md" "$doc")" || { no "AC6: r1 실패"; return; }
  seed_findings "$sd" '[{"id":"eeee0001#r1.1","lineage":"eeee0001#r1.1","bucket":"eeee0001","origin":"reviewer","layer":2,"category":"ambiguity","anchor":"#§b-부분","edit_scope":"#§b-부분","disposition":"decide","summary":"부분 절에 내용이 없다","evidence":null,"blocks":[],"kind":"pre"}]'
  assert_contains "$(py docreview_state.py decide --state-dir "$sd" --id 'eeee0001#r1.1' --choice adopt --quote '채택' 2>&1 >/dev/null)" "anchor_unresolved" "AC6 양성 짝: 정규화를 건너뛴 날 앵커는 채택 단계에서 거부된다"
  rm -rf "$d" "$sd"
}
case_AC6_edit_scope_coerced_separately() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC6s: r1 실패"; return; }
  printf '%s\n' '```docreview-layer1' '[]' '```' '```docreview-layer2' '- ref: c1' '  category: placeholder' '  anchor: "#2-goals"' '  disposition: fix' '  summary: "목표 범위가 넓다"' '  edit_scope: "insert-after:#§2-goals"' '```' > "$d/critic-scope.txt"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$d/critic-scope.txt")" > "$d/prep.json"
  py docreview_route.py finalize --state-dir "$d" --recritic-skipped --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" '[x["edit_scope"] for x in d["findings"]][0]')" "insert-after:#2-goals" "AC6: 앵커와 다른 범위의 § 도 엔진 글자로 바뀐다(insert-after: 머리는 그대로)"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_coerced"]')" "1" "AC6: 앵커는 그대로이고 범위만 바뀌면 강제는 한 번"
  rm -rf "$d"
  d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC6s: r1 실패"; return; }
  printf '%s\n' '```docreview-layer1' '[]' '```' '```docreview-layer2' '- ref: c1' '  category: placeholder' '  anchor: "#§2-goals"' '  disposition: fix' '  summary: "목표 범위가 넓다"' '  edit_scope: "insert-after:#§2-goals"' '```' > "$d/critic-both.txt"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$d/critic-both.txt")" > "$d/prep.json"
  py docreview_route.py finalize --state-dir "$d" --recritic-skipped --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" 'd["adjudication_coerced"], [x["anchor"] for x in d["findings"]][0]')" "(2, '#2-goals')" "AC6: 앵커와 범위가 서로 다른 글자로 둘 다 § 를 가지면 강제는 둘"
  rm -rf "$d"
}
case_AC7_absorbed_ref_in_block_orders() {
  local d order X Y first second
  X='- ref: c1\n  category: placeholder\n  anchor: "#12-files-to-modify"\n  disposition: fix\n  summary: "c.py 가 목록에 없다"'
  Y='- ref: c1\n  category: ambiguity\n  anchor: "#2-goals"\n  disposition: fix\n  summary: "목표 B 가 두 가지로 읽힌다"'
  for order in XY YX; do
    d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC7: r1 실패"; return; }
    if [ "$order" = XY ]; then first="$X"; second="$Y"; else first="$Y"; second="$X"; fi
    printf '```docreview-layer1\n[]\n```\n```docreview-layer2\n%b\n```\n```docreview-layer2\n%b\n%b\n```\n' "$X" "$first" "$second" > "$d/critic-ord.txt"
    py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$d/critic-ord.txt")" > "$d/prep.json"
    py docreview_route.py finalize --state-dir "$d" --recritic-skipped --doc "$FX/design-sample.md" > "$d/fin.json"
    assert_eq "$(jget "$d/fin.json" 'any("duplicate_ref" in w for w in d["advisory"]), d["adjudication_held"] >= 1')" "(True, True)" "AC7 $order: 흡수된 항목과 같은 임시 번호를 쓰는 블록 안 항목은 순서와 무관하게 보류된다"
    rm -rf "$d"
  done
}
case_AC7_duplicate_ref_in_block_held() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC7: r1 실패"; return; }
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-dupref.txt")" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" '[i["summary"] for i in d["items"]]')" "['c.py 가 목록에 없다']" "AC7: 같은 임시 번호의 둘째 항목은 받지 않는다"
  py docreview_route.py finalize --state-dir "$d" --recritic-skipped --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" 'any("duplicate_ref" in w for w in d["advisory"]), d["adjudication_held"] >= 1')" "(True, True)" "AC7: 이유 이름이 경고에 들고 보류로 센다"
  rm -rf "$d"
}
case_detectors_absorb_fills_contradicts() {
  local d; d="$(r1_detectors 2 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC10: r1 실패"; return; }
  cp "$FX/critic-d1-blocks.txt" "$d/critic-1.txt"; cp "$FX/critic-d2-contra.txt" "$d/critic-2.txt"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$d/critic-1.txt" --critic "$d/critic-2.txt" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" '[i.get("contradicts") for i in d["items"] if i["summary"].startswith("넘김 절의 경로")][0]')" "D1.1" "AC39: 결정 반대 번호가 둘째 리뷰어에만 있어도 남은 지적이 이어받는다"
  rm -rf "$d"
}
case_detectors_at_ref_coerced() {
  local d; d="$(r1_detectors 2 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC10: r1 실패"; return; }
  cp "$FX/critic-d1-atref.txt" "$d/critic-1.txt"; cp "$FX/critic-d2-atref.txt" "$d/critic-2.txt"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$d/critic-1.txt" --critic "$d/critic-2.txt" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" '[i["blocks"] for i in d["items"] if i["summary"].startswith("넘김 절의 경로")][0] == [i["f"] for i in d["items"] if i["summary"].startswith("넘김 절에 이어")]')" "True" "AC10: 첫째 리뷰어가 둘째의 꼬리표를 흉내 내도 둘째의 질문은 제 고침을 계속 막는다"
  assert_eq "$(st_yaml "$d" 'len([e for e in st["pending_recritic"]["events"] if e[0]=="coerced" and e[1]=="ref"])')" "1" "AC10: ref 의 @ 는 바꾸고 센다"
  rm -rf "$d"
}
case_detectors_one_warning_per_partial_death() {
  local d; d="$(r1_detectors 3 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC11: r1 실패"; return; }
  local c1; c1="$(critic_now "$d" "$FX/critic-r1.txt")"; cp "$FX/critic-d2.txt" "$d/critic-2.txt"; cp "$FX/critic-broken.txt" "$d/critic-3.txt"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$c1" --critic "$d/critic-2.txt" --critic "$d/critic-3.txt" > "$d/prep.json"
  py docreview_route.py finalize --state-dir "$d" --recritic-skipped --doc "$FX/design-sample.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" 'len([w for w in d["advisory"] if "탐지 3 중" in w])')" "1" "AC11: 일부 사망은 라우팅 경고 한 줄"
  assert_eq "$(jget "$d/fin.json" 'len([w for w in d["advisory"] if "doc-critic#" in w])')" "0" "AC11: 같은 사실의 원장 문구가 둘째 경고로 나오지 않는다"
  local first; first="$(py docreview_state.py gate --state-dir "$d" --render | head -1)"
  assert_eq "$(printf '%s' "$first" | grep -c '보조 리뷰어')" "0" "AC11: 탐지 리뷰어를 보조라고 부르지 않는다"
  assert_eq "$(printf '%s' "$first" | grep -o '탐지 리뷰어' | wc -l | tr -d ' ')" "1" "AC11: 게이트 첫 줄의 탐지 경고는 한 번"
  rm -rf "$d"
}
case_detectors_single_layer2_reason_kept() {
  local d; d="$(r1_detectors 1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC10: r1 실패"; return; }
  printf '```docreview-layer1\n[]\n```\n```docreview-layer2\na: b\n```\n' > "$d/critic.txt"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$d/critic.txt" > "$d/prep.json"
  assert_eq "$(st_yaml "$d" '[e[2] for e in st["pending_recritic"]["events"] if e[0]=="uncountable"]')" "['block not a list']" "AC10: 탐지 하나일 때 층 2 사유는 예전 문구 그대로"
  rm -rf "$d"
}
case_detectors_stale_file_per_file() {
  local d; d="$(r1_detectors 2 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC10: r1 실패"; return; }
  cp "$FX/critic-d2.txt" "$d/critic-2.txt"; touch -t 200001010000 "$d/critic-2.txt"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-r1.txt")" --critic "$d/critic-2.txt" > "$d/prep.json"
  assert_eq "$(jget "$d/prep.json" 'd["degrade"]["detectors"]["dead_reasons"].get("2")')" "critic_predates_round" "AC10: 신선도는 파일마다 — 라운드 시작보다 오래된 둘째만 사망"
  rm -rf "$d"
}

# ── AC17 — 원장 요약값: 엔진 밖에서 고친 원장은 복구 길과 함께 멈춘다 ─────────────────
# 확인값이 생기기 전 버전이 쓴 원장을 흉내 낸다 — 확인값 줄과 시대 표지 파일을 함께 없앤다.
legacy_ledger() {   # legacy_ledger <state-dir>
  python3 -I -c 'import sys,re; p=sys.argv[1]; t=open(p,encoding="utf-8").read(); open(p,"w",encoding="utf-8").write(re.sub(r"^docreview_digest: .*\n","",t,count=1,flags=re.M))' "$1/docreview-state.md"
  rm -f "$1/docreview-digest-era"
}
case_AC17_digest_mismatch_stops() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_contains "$(head -3 "$d/docreview-state.md")" "docreview_digest:" "AC17: 엔진이 저장할 때 요약값을 쓴다"
  python3 -I -c 'import sys; p=sys.argv[1]; t=open(p,encoding="utf-8").read(); open(p,"w",encoding="utf-8").write(t.replace("round: 1","round: 7",1))' "$d/docreview-state.md"
  local err rc; err="$(py docreview_state.py gate --state-dir "$d" 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc" "1" "AC17: 상태만 바꾼 원장은 멈춘다"
  assert_contains "$err" '"reason": "ledger_corrupt"' "AC17: 사유 이름"
  assert_contains "$err" "1라운드부터 다시 리뷰" "AC17: 복구 길을 함께 낸다"
  assert_contains "$err" "$d/docreview-state.md" "AC17: 원장 경로를 낸다"
  err="$(py docreview_route.py finalize --state-dir "$d" --recritic-skipped --doc "$FX/design-sample.md" 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc $(printf '%s' "$err" | grep -c '"reason": "ledger_corrupt"')" "1 1" "AC17: 라우터도 같은 사유로 멈춘다"
  rm -rf "$d"
}
case_AC17_digest_covers_engine_lines_and_body() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  cp "$d/docreview-state.md" "$d/orig.md"
  python3 -I -c 'import sys; p=sys.argv[1]; t=open(p,encoding="utf-8").read(); assert "  engine_lines: []\n" in t; open(p,"w",encoding="utf-8").write(t.replace("  engine_lines: []\n","  engine_lines:\n  - aaaaaaaaaaaa\n",1))' "$d/docreview-state.md"
  local err rc; err="$(py docreview_state.py gate --state-dir "$d" 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc $(printf '%s' "$err" | grep -c '"reason": "ledger_corrupt"')" "1 1" "AC17: 엔진 줄 기록만 바꿔도 멈춘다"
  cp "$d/orig.md" "$d/docreview-state.md"
  printf -- '- r1: 손으로 덧붙인 줄\n' >> "$d/docreview-state.md"
  err="$(py docreview_state.py gate --state-dir "$d" 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc $(printf '%s' "$err" | grep -c '"reason": "ledger_corrupt"')" "1 1" "AC17: 본문 줄만 덧붙여도 멈춘다"
  cp "$d/orig.md" "$d/docreview-state.md"
  py docreview_state.py gate --state-dir "$d" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "0" "AC17 양성 대조: 엔진이 쓴 그대로면 통과한다"
  rm -rf "$d"
}
case_AC17_digest_backfill_disclosed_once() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  legacy_ledger "$d"
  py docreview_state.py gate --state-dir "$d" >/dev/null; local rc=$?
  assert_eq "$rc" "0" "AC17: 요약값 없는 기존 원장은 손상으로 보지 않는다"
  local s="$d/s2.json"; snap "$FX/design-sample.md" "$s"; put_snap "$d" "$s" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  assert_contains "$(py docreview_state.py gate --state-dir "$d" --render | sed -n 2p)" "원장 확인값을 이번에 채웠다" "AC17: 채운 라운드 머리에 한 번 공시"
  local s3="$d/s3.json"; snap "$FX/design-sample.md" "$s3"; put_snap "$d" "$s3" && py docreview_state.py begin-round --state-dir "$d" >/dev/null
  assert_not_contains "$(py docreview_state.py gate --state-dir "$d" --render | sed -n 2p)" "원장 확인값을 이번에 채웠다" "AC17: 다음 라운드엔 다시 말하지 않는다"
  rm -rf "$d"
}
case_AC17_digest_line_strip_stops() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  assert_eq "$([ -f "$d/docreview-digest-era" ] && echo yes)" "yes" "AC17: 처음 확인값을 쓰면 시대 표지 파일을 함께 둔다"
  python3 -I -c 'import sys,re; p=sys.argv[1]; t=open(p,encoding="utf-8").read(); t=re.sub(r"^docreview_digest: .*\n","",t,count=1,flags=re.M); open(p,"w",encoding="utf-8").write(t.replace("round: 1","round: 7",1))' "$d/docreview-state.md"
  local err rc; err="$(py docreview_state.py gate --state-dir "$d" 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc $(printf '%s' "$err" | grep -c '"reason": "ledger_corrupt"')" "1 1" "AC17: 확인값 줄을 지우고 상태를 바꿔도 읽기 전용 gate 가 멈춘다"
  rm -rf "$d"
}
case_AC17_era_marker_failure_disclosed() {
  local d s err rc; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  rm -f "$d/docreview-digest-era"
  s="$d.snap.json"; snap "$FX/design-sample.md" "$s"
  chmod 555 "$d"
  err=""; put_snap "$d" "$s" && err="$(py docreview_state.py begin-round --state-dir "$d" 2>&1 >/dev/null)"; rc=$?
  chmod 755 "$d"
  assert_eq "$rc" "0" "AC17: 표지 파일을 못 만들어도 원장 갱신은 계속된다"
  assert_contains "$err" "시대 표지 파일을 만들지 못했다" "AC17: 표지 파일을 만들지 못한 것을 한 줄로 알린다"
  assert_contains "$err" "$d/docreview-digest-era" "AC17: 그 줄이 표지 파일 경로를 댄다"
  assert_eq "$([ -e "$d/docreview-digest-era" ] && echo yes || echo no)" "no" "AC17: 전제 — 표지 파일은 실제로 만들어지지 않았다"
  rm -f "$s"; rm -rf "$d"
}
case_AC17_legacy_disclosed_on_every_load() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  legacy_ledger "$d"
  assert_contains "$(py docreview_state.py gate --state-dir "$d" --render | sed -n 2p)" "원장 확인값이 없다" "AC17: 확인값 없는 옛 원장은 저장 전 읽기 전용 gate 에서도 알린다"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" | python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("digest_missing"))')" "True" "AC17: gate JSON 에 digest_missing"
  assert_contains "$(py docreview_state.py gate --state-dir "$d" --render | sed -n 2p)" "원장 확인값이 없다" "AC17: 두 번째 읽기에서도 다시 알린다"
  rm -rf "$d"
}
case_AC17_misplaced_or_malformed_digest_stops() {
  local d err rc; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  rm -f "$d/docreview-digest-era"   # 시대 표지가 없어야 «확인값 줄 모양» 가지만 잰다
  cp "$d/docreview-state.md" "$d/orig.md"
  python3 -I -c 'import sys,re; p=sys.argv[1]; t=open(p,encoding="utf-8").read(); m=re.search(r"^docreview_digest: .*\n",t,re.M); t=t.replace(m.group(0),"",1).replace("\n---\n","\n"+m.group(0)+"---\n",1); open(p,"w",encoding="utf-8").write(t)' "$d/docreview-state.md"
  err="$(py docreview_state.py gate --state-dir "$d" 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc $(printf '%s' "$err" | grep -c '"reason": "ledger_corrupt"')" "1 1" "AC17: 확인값 줄이 첫 줄이 아니면 멈춘다"
  cp "$d/orig.md" "$d/docreview-state.md"
  python3 -I -c 'import sys,re; p=sys.argv[1]; t=open(p,encoding="utf-8").read(); open(p,"w",encoding="utf-8").write(re.sub(r"^(docreview_digest: )(.*)$",lambda m: m.group(1)+m.group(2).upper(),t,count=1,flags=re.M))' "$d/docreview-state.md"
  err="$(py docreview_state.py gate --state-dir "$d" 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc $(printf '%s' "$err" | grep -c '"reason": "ledger_corrupt"')" "1 1" "AC17: 대문자 16진수 확인값은 멈춘다"
  rm -rf "$d"
}

# ── AC38 · AC15 — 사람이 내린 결정 줄은 엔진 명령(log-decision)으로 쓴다 ─────────────────────
# 결정 기록 절은 울타리다 — 엔진이 쓴 줄만 지나간다. 사람이 내린 결정(기각 되돌림 · 재결정 · 재분해)을 손으로
# 덧붙이면 다음 라운드에 「허가 없이 바뀜」 결정으로 되돌아온다. log-decision 은 그 줄을 엔진이 쓰고 출처를 남긴다.
HB_LINE='B3 · 결정 · 2026-10-19 · 기각 되돌림 N18'
HB_QUOTE='N18 은 반영해 줘'
HB_FULL="- ${HB_LINE} — 「${HB_QUOTE}」"
log_dec() {   # log_dec <state-dir> <line> <quote> — 원장의 문서(doc.md)에 결정 줄 하나를 엔진으로 쓴다
  py docreview_state.py log-decision --state-dir "$1" --log-file "$1/doc.md" --line "$2" --quote "$3"
}
fin_frozen() {   # fin_frozen <state-dir> — 이번 라운드를 라우팅해 frozen_change 항목의 (앵커, 처분)을 낸다
  py docreview_route.py prepare-recritic --state-dir "$1" --critic "$(critic_now "$1" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$1" "$FX/codex-failed.yaml")" > "$1/prep.json" || { echo "prepare 실패"; return; }
  py docreview_route.py finalize --state-dir "$1" --recritic "$FX/recritic-missing.txt" --doc "$1/doc.md" > "$1/fin.json" || { echo "finalize 실패"; return; }
  jget "$1/fin.json" 'sorted((x["anchor"], x["disposition"]) for x in d["findings"] if x["category"]=="frozen_change")'
}
case_AC38_human_decision_via_engine() {
  local d rc
  d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "결정 줄 명령: init 실패"; return; }
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1"; br "$d" "$d/doc.md"
  log_dec "$d" "$HB_LINE" "$HB_QUOTE" >/dev/null; rc=$?
  assert_eq "$rc" "0" "결정 줄 명령: 열린 리뷰 사이에 사람이 내린 결정 줄을 엔진이 쓴다"
  assert_eq "$(grep -cxF -- "$HB_FULL" "$d/doc.md")" "1" "결정 줄 명령: 줄은 「- <줄> — 「<사용자 말>」」 꼴 한 줄이다"
  assert_eq "$(st_yaml "$d" '[(e["round"], e["heading"]) for e in st["engine_lines"]]')" "[(1, '## 결정 기록')]" "결정 줄 명령: 그 줄의 출처가 원장 엔진 줄 기록에 남는다"
  assert_eq "$(py docreview_state.py gate --state-dir "$d" >/dev/null 2>&1; echo $?)" "0" "결정 줄 명령: 쓴 뒤의 원장이 확인값 대조를 지난다(AC17 나)"
  assert_eq "$([ -f "$d/docreview-digest-era" ] && echo yes)" "yes" "결정 줄 명령: 시대 표지 파일이 그대로 있다"
  br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 2)" "([], [('#결정-기록', 'append-only')])" "결정 줄 명령: 다음 라운드 얼림 diff 에서 엔진 줄 덧붙이기로 지나간다"
  assert_eq "$(fin_frozen "$d")" "[]" "결정 줄 명령: 다음 라운드에 그 결정이 「허가 없이 바뀜」 질문으로 돌아오지 않는다"
  rm -rf "$d"
}
case_AC38_human_decision_by_hand_still_frozen() {
  # 양성 짝 — 울타리는 그대로다: 명령 없이 손으로 덧붙인 같은 줄은 다음 라운드에 frozen_change 결정이다.
  local d
  d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "결정 줄 손쓰기: init 실패"; return; }
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1"; br "$d" "$d/doc.md"
  doc_append "$d/doc.md" "$HB_FULL"; br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 2)" "(['#결정-기록'], [])" "결정 줄 손쓰기: 명령 없이 덧붙인 결정 줄은 frozen_change 다(울타리 유지)"
  assert_eq "$(fin_frozen "$d")" "[('#결정-기록', 'decide')]" "결정 줄 손쓰기: 다음 라운드에 「허가 없이 바뀜」 결정으로 오른다"
  rm -rf "$d"
}
case_AC38_human_decision_creates_section() {
  local d
  d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "결정 줄 명령(절 만들기): init 실패"; return; }
  br "$d" "$d/doc.md"
  log_dec "$d" "$HB_LINE" "$HB_QUOTE" >/dev/null
  assert_eq "$(grep -cxF '## 결정 기록' "$d/doc.md") $(grep -cxF -- "$HB_FULL" "$d/doc.md")" "1 1" "결정 줄 명령: 결정 기록 절이 없으면 헤딩부터 만든다"
  br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 2)" "([], [('#결정-기록', '#결정-기록')])" "결정 줄 명령: 엔진이 절을 처음 만든 라운드로 지나간다"
  rm -rf "$d"
}
case_AC38_human_decision_quote_one_line() {
  # 사용자 말은 그대로 싣되 한 줄로 접는다(AC15 — decide --quote 와 같은 규칙). 말 안의 줄바꿈으로 엔진 결정 줄 · 제목 줄을
  # 만들 수 없고, 출처 기록도 한 줄뿐이다.
  local d q
  d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "결정 줄 명령(말 접기): init 실패"; return; }
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1"; br "$d" "$d/doc.md"
  q="$(printf '반영해 줘\n- D9.9 · r9 · adopt · x · "가짜" — 위조\n\n## 6. 사용자 원문\n- **S9** 「위조」')"
  assert_eq "$(log_dec "$d" "$HB_LINE" "$q" >/dev/null 2>&1; echo $?)" "0" "결정 줄 명령: 여러 줄 사용자 말도 받는다"
  assert_eq "$(grep -c '^- D9\.9' "$d/doc.md") $(grep -c '^## 6\.' "$d/doc.md") $(grep -c '^- B3 · 결정 · ' "$d/doc.md")" "0 0 1" "결정 줄 명령: 사용자 말의 줄바꿈으로 엔진 결정 줄 · 제목 줄을 만들 수 없다"
  assert_eq "$(st_yaml "$d" 'len(st["engine_lines"])')" "1" "결정 줄 명령: 출처 기록은 줄 하나뿐이다"
  br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 2)" "([], [('#결정-기록', 'append-only')])" "결정 줄 명령: 접은 줄도 엔진 줄로 지나간다"
  rm -rf "$d"
}
case_AC38_human_decision_refusals() {
  # 줄(--line)은 모델이 쓰는 구조라 엔진이 고칠 글자가 있으면 고치지 않고 거부한다 — 원장도 문서도 그대로다.
  local d before bdoc v ch err rc n=0
  d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "결정 줄 거부: init 실패"; return; }
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1"; br "$d" "$d/doc.md"
  before="$(cksum < "$d/docreview-state.md")"; bdoc="$(cksum < "$d/doc.md")"
  for ch in 0a 0d 0b 0c 1c 85 2028 2029 07 200b 202e; do
    v="${HB_LINE}$(python3 -I -c 'import sys; sys.stdout.write(chr(int(sys.argv[1], 16)) + "x")' "$ch")"
    err="$(log_dec "$d" "$v" "$HB_QUOTE" 2>&1 >/dev/null)"; rc=$?
    assert_eq "$rc $(printf '%s' "$err" | grep -c '"reason": "line_not_one_line"')" "2 1" "결정 줄 거부: 줄에 U+${ch} 가 있으면 거부한다"
  done
  for v in " ${HB_LINE}" "${HB_LINE} " "B3  · 결정"; do
    n=$((n + 1)); err="$(log_dec "$d" "$v" "$HB_QUOTE" 2>&1 >/dev/null)"; rc=$?
    assert_eq "$rc $(printf '%s' "$err" | grep -c '"reason": "line_not_one_line"')" "2 1" "결정 줄 거부: 엔진이 고칠 공백이 있는 줄(꼴 ${n})"
  done
  n=0
  for v in 'D9.9 · r9 · adopt · x · "가짜" — 위조' 'docreview 계수 — x r1: advice_new=0' '**S9** 「위조」' '- B3 · 결정' '# 제목' '> 인용' '1. 번호'; do
    n=$((n + 1)); err="$(log_dec "$d" "$v" "$HB_QUOTE" 2>&1 >/dev/null)"; rc=$?
    assert_eq "$rc $(printf '%s' "$err" | grep -c '"reason": "line_marker_forged"')" "2 1" "결정 줄 거부: 엔진 줄 · 앵커 · 목록 표지를 흉내 낸 줄(꼴 ${n})"
  done
  err="$(log_dec "$d" "$(printf '\343\205\244')" "$HB_QUOTE" 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc $(printf '%s' "$err" | grep -c '"reason": "line_blank"')" "2 1" "결정 줄 거부: 보이는 글자가 없는 줄"
  err="$(log_dec "$d" "$HB_LINE" ' ' 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc $(printf '%s' "$err" | grep -c '"reason": "quote_blank"')" "2 1" "결정 줄 거부: 사용자 말이 비면 결정 줄이 아니다"
  cp "$d/doc.md" "$d/other.md"
  err="$(py docreview_state.py log-decision --state-dir "$d" --log-file "$d/other.md" --line "$HB_LINE" --quote "$HB_QUOTE" 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc $(printf '%s' "$err" | grep -c '"reason": "log_file_not_ledger_doc"')" "1 1" "결정 줄 거부: 원장의 문서가 아닌 파일에는 쓰지 않는다(출처를 남길 수 없다)"
  assert_eq "$(cmp -s "$d/doc.md" "$d/other.md" && echo same)" "same" "결정 줄 거부: 다른 파일도 그대로다"
  py docreview_state.py log-decision --state-dir "$d" --log "$d/doc.md" --line "$HB_LINE" --quote "$HB_QUOTE" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "결정 줄 거부: 줄인 플래그(--log)는 사용법 오류"
  assert_eq "$(cksum < "$d/docreview-state.md")" "$before" "결정 줄 거부: 거부는 원장을 바꾸지 않는다"
  assert_eq "$(cksum < "$d/doc.md")" "$bdoc" "결정 줄 거부: 거부는 문서를 바꾸지 않는다"
  rm -rf "$d"
  d="$(mktemp -d -t docreview-XXXXXX)"; cp "$FX/design-sample.md" "$d/doc.md"
  py docreview_state.py init --state-dir "$d" --doc "$d/doc.md" --profile "$PROF_QG/generic.md" >/dev/null; br "$d" "$d/doc.md"
  err="$(log_dec "$d" "$HB_LINE" "$HB_QUOTE" 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc $(printf '%s' "$err" | grep -c '"reason": "profile_decision_log_not_doc_section"')" "1 1" "결정 줄 거부: 결정 기록이 문서 절이 아닌 프로필"
  rm -rf "$d"
}
case_AC38_human_decision_no_ledger_baseline() {
  # 원장이 없을 때(리뷰를 열기 전 — init 앞) 손으로 쓴 결정 줄은 첫 리뷰의 기준선이다 — 다음 라운드에 frozen_change 로
  # 오르지 않는다. 결정 줄 펜스가 「원장 없음 → 손으로 쓴다」 로 보내는 길이 바로 이것이다.
  local d
  d="$(mktemp -d -t docreview-XXXXXX)" || { no "원장 없음 기준선: 임시 폴더 실패"; return; }
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1" "$HB_FULL"
  assert_eq "$([ -f "$d/docreview-state.md" ] && echo yes || echo no)" "no" "원장 없음 기준선: 결정 줄을 쓸 때 원장이 없다"
  py docreview_state.py init --state-dir "$d" --doc "$d/doc.md" --profile "$PROF_SD/design-doc.md" >/dev/null \
    || { no "원장 없음 기준선: init 실패"; rm -rf "$d"; return; }
  br "$d" "$d/doc.md"; br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 2)" "([], [])" "원장 없음 기준선: 원장이 생기기 전에 손으로 쓴 결정 줄은 기준선이다"
  assert_eq "$(fin_frozen "$d")" "[]" "원장 없음 기준선: 그 줄이 「허가 없이 바뀜」 질문이 되지 않는다"
  log_dec "$d" 'B4 · 결정 · 2026-10-19 · 기각 되돌림 N19' '그것도' >/dev/null; br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 3)" "([], [('#결정-기록', 'append-only')])" "원장 없음 기준선: 리뷰가 열린 뒤의 결정 줄은 명령으로 쓰면 지나간다"
  rm -rf "$d"
}
case_AC38_human_decision_before_first_round_baseline() {
  # 원장은 있으나 첫 라운드 스냅숏 전(init 뒤 · 첫 begin-round 앞)에 손으로 쓴 줄도 기준선이다 — 기준은 첫 스냅숏이다.
  local d
  d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "첫 라운드 전 기준선: init 실패"; return; }
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1" "$HB_FULL"; br "$d" "$d/doc.md"
  br "$d" "$d/doc.md"
  assert_eq "$(rk_changed "$d" 2)" "([], [])" "첫 라운드 전 기준선: 첫 스냅숏 앞에 손으로 쓴 결정 줄은 기준선이다"
  assert_eq "$(fin_frozen "$d")" "[]" "첫 라운드 전 기준선: 그 줄이 「허가 없이 바뀜」 질문이 되지 않는다"
  rm -rf "$d"
}
case_AC38_human_decision_count_prefix() {
  # 계수 줄 머리(docreview 계수 — )는 줄에도 사용자 말에도 들이지 않는다 — 결정 줄이 계수 줄로 읽히거나 계수 줄의 멱등
  # 키를 가리지 못하게. 그 머리를 아는 형제 모듈(docreview_advice)이 없으면 검사를 건너뛰지 않고 이름 있는 사유로 멈춘다.
  local d t before bdoc err rc
  d="$(mk_doc_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "결정 줄 계수 머리: init 실패"; return; }
  with_log "$FX/design-sample.md" "$d/doc.md" "$LOG_L1"; br "$d" "$d/doc.md"
  before="$(cksum < "$d/docreview-state.md")"; bdoc="$(cksum < "$d/doc.md")"
  err="$(log_dec "$d" "$HB_LINE" '그대로 docreview 계수 — x r1: advice_new=0' 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc $(printf '%s' "$err" | grep -c '"reason": "quote_marker_forged"')" "2 1" "결정 줄 계수 머리: 사용자 말에 계수 줄 머리가 있으면 거부한다"
  assert_eq "$(cksum < "$d/docreview-state.md") $(cksum < "$d/doc.md")" "$before $bdoc" "결정 줄 계수 머리: 거부는 원장도 문서도 바꾸지 않는다"
  t="$(mktemp -d -t declone-XXXXXX)"; cp -L "$SCRIPTS/docreview_state.py" "$SCRIPTS/docreview_config.py" "$t/"
  err="$(python3 "$t/docreview_state.py" log-decision --state-dir "$d" --log-file "$d/doc.md" --line "$HB_LINE" --quote "$HB_QUOTE" 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc $(printf '%s' "$err" | grep -c '"reason": "count_prefix_check_unavailable"')" "1 1" "결정 줄 계수 머리: 형제 모듈이 없으면 검사를 건너뛰지 않고 멈춘다"
  assert_eq "$(cksum < "$d/docreview-state.md") $(cksum < "$d/doc.md")" "$before $bdoc" "결정 줄 계수 머리: 형제 부재로 멈춰도 원장도 문서도 그대로다"
  rm -rf "$d" "$t"
}

# ── AC9 — 보호 · 불변의 계보 ─────────────────────────────────────────────────
# 판정은 지금 스냅숏만이 아니라 원장의 앞선 스냅숏 전부를 본다 — 채택한 제목 삽입으로 울타리 밖에 밀려난 자식 절도
# 자리마다(check-intent · 라우팅 · 얼림 diff · 울타리 · begin-round 줄 해시 · 채택 permit · 신고) 같은 판정을 받는다.
F_ARCH_INS='{"id":"gggg0001#r1.1","lineage":"gggg0001#r1.1","bucket":"gggg0001","origin":"reviewer","layer":1,"category":"architecture","anchor":"#5-architecture","edit_scope":"insert-after:#5-architecture","disposition":"decide","summary":"부품 앞에 새 절이 필요하다","evidence":"5절","blocks":[],"kind":"pre"}'
F_PARTS_FIX='{"id":"hhhh0001#r2.1","lineage":"hhhh0001#r2.1","bucket":"hhhh0001","origin":"reviewer","layer":2,"category":"ambiguity","anchor":"#51-parts","edit_scope":"#51-parts","disposition":"fix","summary":"부품 설명이 짧다","evidence":null,"blocks":[]}'
F_PARTS_DEC='{"id":"iiii0001#r2.1","lineage":"iiii0001#r2.1","bucket":"iiii0001","origin":"reviewer","layer":1,"category":"architecture","anchor":"#51-parts","edit_scope":"#51-parts","disposition":"decide","summary":"부품 설명을 바꾼다","evidence":"5.1절","blocks":[],"kind":"pre"}'
F_IMM_FIX='{"id":"jjjj0001#r3.1","lineage":"jjjj0001#r3.1","bucket":"jjjj0001","origin":"reviewer","layer":2,"category":"distortion","anchor":"#원문-부록","edit_scope":"#원문-부록","disposition":"fix","summary":"원문 한 줄을 다듬는다","evidence":null,"blocks":[]}'
F_IMM_PLAIN_DEC='{"id":"llll0001#r3.1","lineage":"llll0001#r3.1","bucket":"llll0001","origin":"reviewer","layer":2,"category":"distortion","anchor":"#원문-부록","edit_scope":"#원문-부록","disposition":"decide","summary":"부록 한 줄을 바꾼다","evidence":"S3","blocks":[],"kind":"pre"}'
F_IMM_DEC='{"id":"kkkk0001#r3.1","lineage":"kkkk0001#r3.1","bucket":"kkkk0001","origin":"auto","layer":2,"category":"distortion","anchor":"#6-사용자-원문","edit_scope":"#6-사용자-원문","disposition":"decide","summary":"원문 해석을 고친다","evidence":"S1","blocks":[],"kind":"pre","immutable":true}'
lineage_pushed_r2() {   # → state dir: 라운드 1 에 #5 뒤 삽입 결정을 채택했고, 라운드 2 에서 #51-parts 가 #6-inserted 밑으로 밀려났다
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || return 1
  seed_findings "$d" "[$F_ARCH_INS]" || return 1
  py docreview_state.py decide --state-dir "$d" --id 'gggg0001#r1.1' --choice adopt --quote '넣는다' >/dev/null || return 1
  next_round "$d" "$FX/design-sample-pushed.md" >/dev/null
  echo "$d"
}
case_lineage_protected_child_pushed_out() {
  local d out rc; d="$(lineage_pushed_r2)" || { no "AC9 밀려난 자식: 준비 실패"; return; }
  assert_eq "$(st_yaml "$d" '[s["parents"] for s in st["snapshots"]["2"]["sections"] if s["anchor"]=="#51-parts"]')" "[['#6-inserted']]" \
    "AC9 전제: 라운드 2 에서 #51-parts 는 #5-architecture 밑이 아니다"
  seed_findings "$d" "[$F_PARTS_FIX]"
  out="$(_ci 'hhhh0001#r2.1' --intent '#51-parts' --state-dir "$d")"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["reason"]')" "1 anchor_protected" "AC9: 울타리 밖으로 밀려난 자식 절도 check-intent 가 보호로 거부한다"
  assert_eq "$(gsum "$d" '"hhhh0001#r2.1" in d["escalated_fix"]')" "True" "AC9: 그 거부는 게이트의 escalated 에 든다"
  assert_eq "$(py docreview_anchor.py protected '#51-parts' --profile "$PROF_SD/design-doc.md" --snapshot "$d/s2.json" | jgets 'd["protected"]')" "False" \
    "AC9 대조: protected CLI 는 원장 없이 스냅숏만 본다(계보 없음)"
  assert_eq "$(py docreview_anchor.py protected '#51-parts' --profile "$PROF_SD/design-doc.md" --snapshot "$d/s1.json" | jgets 'd["protected"]')" "True" \
    "AC9 대조 양성 짝: 라운드 1 스냅숏에서는 보호다"
  rm -rf "$d"
}
case_lineage_routing_and_intent_agree() {
  local d c; d="$(lineage_pushed_r2)" || { no "AC9 라우팅: 준비 실패"; return; }
  c="$d/critic-lineage.txt"
  printf '%s\n' '```docreview-layer1' '[]' '```' '' '```docreview-layer2' '- ref: c1' '  category: ambiguity' \
    '  anchor: "#51-parts"' '  disposition: fix' '  summary: "부품 설명이 짧다"' '- ref: c2' '  category: placeholder' \
    '  anchor: "#12-files-to-modify"' '  disposition: fix' '  summary: "c.py 가 목록에 없다"' '```' > "$c"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$c" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic-skipped --doc "$FX/design-sample-pushed.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" '[(x["disposition"], x.get("promotion")) for x in d["findings"] if x["anchor"]=="#51-parts"]')" "[('decide', 'protected')]" \
    "AC9: 밀려난 자식 절의 fix 는 라우팅이 보호로 올린다(check-intent 와 같은 판정)"
  assert_eq "$(jget "$d/fin.json" '[(x["disposition"], x.get("promotion")) for x in d["findings"] if x["anchor"]=="#12-files-to-modify"]')" "[('fix', None)]" \
    "AC9 양성 짝: 보호 이력이 없는 절의 fix 는 그대로다"
  rm -rf "$d"
}
case_lineage_adopt_once_then_ask_again() {
  local d df; d="$(lineage_pushed_r2)" || { no "AC9 다시 묻기: 준비 실패"; return; }
  seed_findings "$d" "[$F_PARTS_DEC]"
  assert_eq "$(py docreview_state.py decide --state-dir "$d" --id 'iiii0001#r2.1' --choice adopt --quote '바꾼다' | jgets 'd["permit"]["round"], d["permit"]["apply_anchors"]')" "(3, ['#51-parts'])" \
    "AC9 전제: 라운드 2 의 채택이 라운드 3 permit 을 연다"
  df="$(next_round "$d" "$FX/design-sample-pushed-r3.md")"
  assert_eq "$(jget "$df" '"#51-parts" in [c["anchor"] for c in d["changed"]], [e["anchor"] for e in d["exempt_applied"]]')" "(False, ['#51-parts'])" \
    "AC9: 허가된 그 변경 하나는 얼림 diff 의 바뀜이 아니다"
  next_round "$d" "$FX/design-sample-pushed-r4.md" '라운드 4 를 연다' >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-empty.txt")" > "$d/prep4.json"
  py docreview_route.py finalize --state-dir "$d" --recritic-skipped --doc "$FX/design-sample-pushed-r4.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" '[(x["category"], x["layer"], x["disposition"]) for x in d["findings"] if x["anchor"]=="#51-parts"]')" "[('frozen_change', 1, 'decide')]" \
    "AC9: 다음 변경은 다시 묻는다 — 보호 이력이 이어져 층 1 질문이다"
  rm -rf "$d"
}
case_lineage_immutable_child_fenced() {
  # brief 프로필(`^6\.` 불변) — §6 의 하위 절이 앞에 끼운 `## 5.` 제목 밑으로 밀려난다. `## 5.` 는 fix_anchors 안이라
  # 지금 스냅숏만 보면 밀려난 절이 고칠 수 있는 절로 읽힌다.
  local d out rc did; d="$(mktemp -d -t docreview-XXXXXX)" || { no "AC9 불변: 임시 폴더 실패"; return; }
  python3 -I -c 'import sys
t = open(sys.argv[1], encoding="utf-8").read() + "\n### 원문 부록\n\n- **S3** 「셋째 말」\n"
open(sys.argv[2], "w", encoding="utf-8").write(t)
i = t.index("### 원문 부록")
open(sys.argv[3], "w", encoding="utf-8").write(t[:i] + "## 5. 끼움\n\n끼운 절.\n\n" + t[i:])' "$FX/brief-append-r1.md" "$d/r1.md" "$d/r2.md"
  py docreview_state.py init --state-dir "$d" --doc "$d/r1.md" --profile "$PROF_SD/brief.md" >/dev/null || { no "AC9 불변: init 실패"; rm -rf "$d"; return; }
  br "$d" "$d/r1.md"; br "$d" "$d/r2.md"; br "$d" "$d/r2.md"
  assert_eq "$(st_yaml "$d" '[s["parents"] for s in st["snapshots"]["2"]["sections"] if s["anchor"]=="#원문-부록"]')" "[['#brief', '#5-끼움']]" \
    "AC9 불변 전제: 라운드 2 에서 하위 절은 §6 밑이 아니다"
  assert_eq "$(st_yaml "$d" '[(s["anchor"], "line_hashes" in s, "item_marks" in s) for s in st["snapshots"]["2"]["sections"] if s["anchor"] in ("#원문-부록", "#5-끼움")]')" \
    "[('#5-끼움', False, False), ('#원문-부록', True, True)]" \
    "AC9 불변: begin-round 가 밀려난 불변 절의 줄 해시 · 항목 표지를 원장에 옮긴다(끼운 절은 아니다)"
  assert_eq "$(PYTHONPATH="$SCRIPTS" python3 "$FX/st_get.py" "$d/docreview-state.md" '(lambda S: sorted(x for x in S.round_fence(st, S.load_profile(st["profile"]), 3) if x in ("#원문-부록", "#5-끼움")))(__import__("docreview_state"))')" "['#원문-부록']" \
    "AC9 불변: 라운드 3 울타리는 스냅숏 2 · 3 어디서도 §6 밑이 아닌 그 절을 계속 담는다"
  seed_findings "$d" "[$F_IMM_FIX]"
  out="$(_ci 'jjjj0001#r3.1' --intent '#원문-부록' --state-dir "$d")"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["reason"]')" "1 anchor_immutable" "AC9 불변: check-intent 의 기록 검증도 계보로 불변이다"
  seed_findings "$d" "[$F_IMM_DEC]"
  assert_eq "$(py docreview_state.py decide --state-dir "$d" --id 'kkkk0001#r3.1' --choice adopt --quote '고친다' | jgets 'sorted(d["permit"]["apply_anchors"])')" "['#2-확정', '#5-끼움']" \
    "AC9 불변: 불변 절 결정의 채택 permit 은 밀려난 불변 절을 열지 않는다(fix_anchors 의 다른 절은 연다)"
  did="$(st_yaml "$d" 'st["decision_log"][-1]["decision_id"]')"
  out="$(py docreview_state.py declare-related --state-dir "$d" --decision "$did" --anchors '#원문-부록' 2>&1 >/dev/null)"
  assert_contains "$out" '"reason": "anchor_immutable"' "AC9 불변: 신고도 밀려난 불변 절을 묶지 못한다"
  out="$(py docreview_state.py declare-related --state-dir "$d" --decision "$did" --anchors '#5-끼움')"
  assert_eq "$(printf '%s' "$out" | jgets 'd["ok"]')" "True" "AC9 불변 양성 짝: 불변 이력이 없는 절은 신고로 묶인다"
  seed_findings "$d" "[$F_IMM_PLAIN_DEC]"
  out="$(py docreview_state.py decide --state-dir "$d" --id 'llll0001#r3.1' --choice adopt --quote '고친다' 2>&1 >/dev/null)"
  assert_contains "$out" '"why": "anchor_immutable"' "AC9 불변: 밀려난 불변 절을 범위로 둔 결정은 채택이 permit 을 열지 않는다"
  snap "$d/r2.md" "$d/s4.json"
  snap_edit "$d/s4.json" '[s.pop("line_hashes", None) for s in d["sections"] if s["anchor"] == "#원문-부록"]'
  assert_eq "$(snap_problem "$d" "$d/s4.json")" "('fence_line_hashes_missing', ['#원문-부록'])" \
    "AC9 불변: 밀려난 불변 절의 줄 해시를 뗀 스냅숏은 snapshot_problem 이 거절한다(계보로 불변)"
  # 손으로 심은 permit 이 밀려난 불변 절을 열어도 check-intent 의 permit 계약은 넘지 못한다
  PYTHONPATH="$SCRIPTS" python3 -c 'import sys; from docreview_state import load_state, save_state; d=sys.argv[1]; st=load_state(d); st["permits"]["D9.1"]={"kind":"apply","apply_anchors":["#원문-부록","#5-끼움"],"round":3,"finding_id":"jjjj0001#r3.1","consumed":False}; save_state(d, st, "fixture: 위조 permit")' "$d"
  out="$(_ci 'jjjj0001#r3.1' --intent '#원문-부록' --decision-id D9.1 --state-dir "$d")"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["reason"]')" "1 anchor_immutable" "AC9 불변: permit 계약도 밀려난 불변 절을 넘지 못한다"
  out="$(_ci 'jjjj0001#r3.1' --intent '#5-끼움' --decision-id D9.1 --state-dir "$d")"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["contract"]')" "0 permit" "AC9 불변 양성 짝: 같은 permit 의 다른 절은 지나간다"
  rm -rf "$d"
  # fix_anchors 에 드는 절이 밀려난 불변 절뿐이면 불변 결정의 채택은 열 permit 이 없다
  d="$(mktemp -d -t docreview-XXXXXX)" || { no "AC9 불변: 임시 폴더 실패"; return; }
  printf '%s\n' '# brief' '' '## 6. 사용자 원문' '' '- **S1** 「첫 말」' '' '### 2. 부록' '' '- **S2** 「둘째 말」' > "$d/r1.md"
  printf '%s\n' '# brief' '' '## 6. 사용자 원문' '' '- **S1** 「첫 말」' '' '## 7. 끼움' '' '끼운 절.' '' '### 2. 부록' '' '- **S2** 「둘째 말」' > "$d/r2.md"
  py docreview_state.py init --state-dir "$d" --doc "$d/r1.md" --profile "$PROF_SD/brief.md" >/dev/null || { no "AC9 불변: init 실패"; rm -rf "$d"; return; }
  br "$d" "$d/r1.md"; br "$d" "$d/r2.md"
  seed_findings "$d" "[$F_IMM_DEC]"
  out="$(py docreview_state.py decide --state-dir "$d" --id 'kkkk0001#r3.1' --choice adopt --quote '고친다' 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["reason"], d["why"]')" "1 ('edit_scope_refused', 'no_fix_anchor')" \
    "AC9 불변: 남은 fix 절이 밀려난 불변 절뿐이면 불변 결정의 채택을 받지 않는다"
  rm -rf "$d"
}

# 계보는 앵커로 잇는다 — 보호 절의 제목을 바꾸거나 절을 지우면 지금 스냅숏에 없는 옛 앵커가 보호 절의 변경으로 묻힌다.
lineage_r2_doc() {   # lineage_r2_doc <state-dir> — design-sample.md 에서 Goals 를 Outcomes 로 바꾸고 §1 · §3 을 지운 사본 → <state-dir>/r2.md
  python3 -I -c 'import re, sys
t = open(sys.argv[1], encoding="utf-8").read().replace("## 2. Goals", "## 2. Outcomes")
t = re.sub(r"## 1\. Context\n.*?(?=## 2\.)", "", t, flags=re.S)
t = re.sub(r"## 3\. Non-goals\n.*?(?=## 5\.)", "", t, flags=re.S)
open(sys.argv[2], "w", encoding="utf-8").write(t)' "$FX/design-sample.md" "$1/r2.md"
}
case_lineage_rename_and_delete_ask() {
  local d c; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")" || { no "AC9 이름 바꿈: 준비 실패"; return; }
  lineage_r2_doc "$d"
  next_round "$d" "$d/r2.md" >/dev/null
  assert_eq "$(st_yaml "$d" 'sorted(s["anchor"] for s in st["snapshots"]["2"]["sections"] if s["anchor"] in ("#1-context", "#2-goals", "#2-outcomes", "#3-non-goals"))')" "['#2-outcomes']" \
    "AC9 이름 바꿈 전제: 라운드 2 스냅숏에는 옛 앵커 셋이 없고 새 제목의 앵커만 있다"
  c="$d/critic-lineage.txt"
  printf '%s\n' '```docreview-layer1' '[]' '```' '' '```docreview-layer2' '- ref: c1' '  category: ambiguity' \
    '  anchor: "#3-non-goals"' '  disposition: fix' '  summary: "범위 밖 항목이 사라졌다"' '- ref: c2' '  category: ambiguity' \
    '  anchor: "#1-context"' '  disposition: fix' '  summary: "배경이 사라졌다"' '```' > "$c"
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$c" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic-skipped --doc "$d/r2.md" > "$d/fin.json"
  assert_eq "$(jget "$d/fin.json" 'sorted((x["anchor"], x["layer"]) for x in d["findings"] if x["category"] == "frozen_change")')" \
    "[('#1-context', 2), ('#2-goals', 1), ('#2-outcomes', 2), ('#3-non-goals', 1)]" \
    "AC9: 보호 절의 제목을 바꾸거나 절을 지우면 옛 앵커가 층 1 질문이다(보호 이력 없는 절은 층 2 · 새 제목은 보호 이력이 없다)"
  assert_eq "$(jget "$d/fin.json" 'sorted((x["anchor"], x["disposition"], x.get("promotion")) for x in d["findings"] if x["category"] == "ambiguity")')" \
    "[('#1-context', 'fix', None), ('#3-non-goals', 'decide', 'protected')]" \
    "AC9: 지워진 보호 절을 겨눈 fix 는 결정으로 오른다(보호 이력 없는 지워진 절의 fix 는 그대로)"
  rm -rf "$d"
}

# ── AC13 — 표 행(번호 대조 · 미룸 표) 손 편집의 허가 걸음: 절차가 가리키는 길이 실제로 닫히는지 ──
ac13_finalize_r2() {   # ac13_finalize_r2 <state-dir> [라운드 2 문서] — 라운드 2 를 열고 finalize → <state-dir>/fin.json
  local d="$1" doc="${2:-$FX/design-sample-r2.md}"
  next_round "$d" "$doc" >/dev/null
  py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-nolayer2.txt")" --codex "$(codex_now "$d" "$FX/codex-failed.yaml")" > "$d/prep2.json"
  py docreview_route.py finalize --state-dir "$d" --recritic "$FX/recritic-missing.txt" --doc "$doc" > "$d/fin.json"
}
case_AC13_table_row_with_adopted_decision() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
  local did; did="$(py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '고친다' | jgets 'd["decision_id"]')"
  py docreview_state.py declare-related --state-dir "$d" --decision "$did" --anchors '#2-goals' >/dev/null
  ac13_finalize_r2 "$d"
  assert_eq "$(jget "$d/fin.json" '[x["anchor"] for x in d["findings"] if x["category"] == "frozen_change"]')" "[]" "AC13: 채택 결정에 묶고 고친 절은 다음 라운드에 「허가 없이 바뀜」으로 돌아오지 않는다"
  assert_contains "$(py docreview_state.py gate --state-dir "$d" --render)" "이 결정 때문에 함께 바뀐 곳" "AC13: 묶은 절은 게이트의 「이 결정 때문에 함께 바뀐 곳」에 보인다"
  rm -rf "$d"
}
case_AC13_table_row_without_decision() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
  ac13_finalize_r2 "$d"
  assert_eq "$(jget "$d/fin.json" 'sorted(x["anchor"] for x in d["findings"] if x["category"] == "frozen_change")')" "['#12-files-to-modify', '#2-goals']" "AC13 대조: 채택 결정 없이 고친 절은 다음 라운드에 frozen_change 결정으로 돌아온다(절차가 사용자에게 알리는 사실)"
  rm -rf "$d"
}
# 표 행 자체 — 채택 결정(§12 를 고친다)에 `## 번호 대조` · `## 미룸` 표 행과 내용을 더할 새 절(insert-after)을 묶는다.
# 묶을 수 없는 것은 결정 기록과 프로필의 미룸 자리(`### Deferred to plan`)뿐이다 — `## 미룸` 은 사용자 문서의 보통 절이라 묶인다.
case_AC13_table_rows_bound_with_declare() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-tables.md")"; seed_findings "$d" "[$F_DEC]"
  local did; did="$(py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '고친다' | jgets 'd["decision_id"]')"
  local out rc=0; out="$(py docreview_state.py declare-related --state-dir "$d" --decision "$did" --anchors '#번호-대조' '#미룸' 'insert-after:#2-goals')" || rc=$?
  assert_eq "$rc $(printf '%s' "$out" | jgets 'd["related"]')" "0 ['#번호-대조', '#미룸', 'insert-after:#2-goals']" "AC13: 번호 대조 · 미룸 표 절과 내용을 더할 새 절(insert-after)은 채택 결정에 묶인다"
  local a err
  for a in '#deferred-to-plan' '#결정-기록'; do
    rc=0; err="$(py docreview_state.py declare-related --state-dir "$d" --decision "$did" --anchors "$a" 2>&1 >/dev/null)" || rc=$?
    assert_eq "$rc" "1" "AC13: 엔진 울타리 절은 묶지 못한다 — $a"
    assert_contains "$err" '"reason": "anchor_log_section"' "AC13: 엔진 울타리 절의 거부 사유 — $a"
  done
  ac13_finalize_r2 "$d" "$FX/design-tables-r2.md"
  assert_eq "$(jget "$d/fin.json" '[x["anchor"] for x in d["findings"] if x["category"] == "frozen_change"]')" "[]" "AC13: 묶고 고친 표 행은 다음 라운드에 「허가 없이 바뀜」으로 돌아오지 않는다"
  local g; g="$(py docreview_state.py gate --state-dir "$d" --render)"
  assert_contains "$g" "이 결정 때문에 함께 바뀐 곳 3개 ($did)" "AC13: 묶은 표 절 둘과 더한 절은 게이트의 「이 결정 때문에 함께 바뀐 곳」에 보인다"
  local x
  for x in '- 번호 대조 (#번호-대조)' '- 미룸 (#미룸)' '- 4. 되돌린 번호의 자리 (#4-되돌린-번호의-자리)'; do
    assert_contains "$g" "$x" "AC13: 게이트의 함께 바뀐 곳 목록 — $x"
  done
  rm -rf "$d"
}
case_AC13_table_rows_without_declare() {
  local d; d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-tables.md")"; seed_findings "$d" "[$F_DEC]"
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '고친다' >/dev/null
  ac13_finalize_r2 "$d" "$FX/design-tables-r2.md"
  assert_eq "$(jget "$d/fin.json" 'sorted(x["anchor"] for x in d["findings"] if x["category"] == "frozen_change")')" "['#4-되돌린-번호의-자리', '#미룸', '#번호-대조']" "AC13 대조: 같은 채택이라도 묶지 않고 고친 표 행 · 더한 절은 다음 라운드에 frozen_change 결정으로 돌아온다(채택한 §12 는 아니다)"
  rm -rf "$d"
}
