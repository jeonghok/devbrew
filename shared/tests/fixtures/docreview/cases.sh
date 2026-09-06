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
  rm -f "$s"
}
# [Task 2+4 실행 노트] 이 케이스는 원래 여기서 brief.md
# 프로필(§6 immutable · §2 fix 가능 · §1 Goal 보호) 단언 3건으로 이어졌다. 그 프로필
# (`plugins/spec-distill/references/docreview-profiles/brief.md`)은 Task 3 산출물이고,
# 이번 실행은 Task 2 + Task 4 만 수행하며 "나머지 프로필 셋"을 미리 만들지 않는다는
# 오케스트레이터 지시를 받았다 — 그래서 그 3건은 여기서 뺐다(brief-sample.md 픽스처
# 자체는 Task 4 산출물이라 그대로 만들어 뒀다 — 이후 여러 Task 가 그것을 쓴다).
# Task 3 가 brief.md 를 만들 때 위 case_anchor_protected_cascade 함수의 `rm -f "$s"` 를
# 아래로 바꾸고 이어서 원문 그대로 붙일 것:
#   rm -f "$s"; s="$(mktemp -t sp-XXXXXX)"; snap "$FX/brief-sample.md" "$s"; p="$PROF_SD/brief.md"
#   assert_eq "$(py docreview_anchor.py protected '#6-사용자-원문' --profile "$p" --snapshot "$s" | jgets 'd["immutable"], d["fix_allowed"]')" "(True, False)" "protected: brief §6 은 immutable 이고 fix 불가"
#   assert_eq "$(py docreview_anchor.py protected '#2-제약' --profile "$p" --snapshot "$s" | jgets 'd["immutable"], d["fix_allowed"], d["protected"]')" "(False, True, False)" "protected: brief §2 는 fix 가능"
#   assert_eq "$(py docreview_anchor.py protected '#1-goal' --profile "$p" --snapshot "$s" | jgets 'd["protected"], d["fix_allowed"]')" "(True, False)" "protected: brief §1 Goal 은 보호 부류"
#   rm -f "$s"
case_anchor_refs() {
  assert_eq "$(py docreview_anchor.py refs '#12-files-to-modify' "$FX/design-sample.md" | jgets 'd["refs"], d["sections"]')" "(1, ['#5-architecture'])" "refs: Architecture 가 #12 를 링크로 인용한다 → 1"
}
