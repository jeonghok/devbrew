#!/usr/bin/env bash
# guards: shared/docreview/scripts/*.py shared/tests/fixtures/docreview/**
#
# 변이 매트릭스 — 엔진 규칙을 하향으로 뒤집는 각 변이가 지정 케이스를 RED 로 만드는지 잰다.
# 행동 락(test_docreview_*.sh)이 GREEN 만 재는 것을 보완한다: GREEN 만 있는 락은 이빨이 없다.
#
# 방법: 스크립트 셋을 임시 디렉토리에 사본으로 두고(형제 adjudication.py 링크 포함), 그 사본을
# sed 로 변이한 뒤 cases.sh 의 한 케이스를 그 디렉토리로 돌린다. 케이스가 fail 하면(1건 이상 ✗)
# 그 변이는 «잡혔다». **양성 대조**: 변이 전 사본에서 같은 케이스가 GREEN 이어야 한다(계측기 검증).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SRC="$REPO_ROOT/shared/docreview/scripts"
export PYTHONDONTWRITEBYTECODE=1
BASE_MUT="$(mktemp -d -t docreview-mut-XXXXXX)" || exit 1
trap 'rm -rf "$BASE_MUT"' EXIT

# 사본 디렉토리를 하나 만든다(형제 adjudication.py 링크 포함).
mkclone() {   # mkclone <dir>
  mkdir -p "$1"; cp "$SRC"/*.py "$1"/
  ln -sf "$REPO_ROOT/shared/adjudication/adjudication.py" "$1/adjudication.py"
}
# 한 케이스를 한 SCRIPTS 로 돌려 "✗개수 ✓개수 traceback유무(0|1)" 를 낸다.
# traceback 유무가 「측정 불가」 판정의 유일한 근거다 — stdout+stderr 를 합쳐 캡처해
# Python traceback 시그니처(스택의 첫 줄, 모든 CPython 버전에서 고정)를 찾는다.
# **R19 이전엔 이 함수가 `>/dev/null 2>&1` 로 stdout·stderr 를 전부 버려 엔진/헬퍼가
# 크래시해도 매트릭스 출력에 전혀 안 보였다** — 리뷰어가 셀 ③(reject_no_evidence)에서
# 잡은 결함이고, 오케스트레이터가 확대 측정해 ①·②도 같은 결함(traceback)이었음을 확인했다.
run_case() {   # run_case <scripts-dir> <case-fn> → "<fail> <pass> <traceback:0|1>"
  ( set +u
    REPO_ROOT="$REPO_ROOT"; SCRIPTS="$1"
    . "$REPO_ROOT/shared/tests/assert.sh"; . "$REPO_ROOT/shared/tests/fixtures/docreview/cases.sh"
    _out="$(mktemp -t docreview-runcase-XXXXXX)"
    "$2" >"$_out" 2>&1
    _tb=0
    grep -q '^Traceback (most recent call last):' "$_out" && _tb=1
    rm -f "$_out"
    echo "$_ASSERT_FAIL $_ASSERT_PASS $_tb"
  )
}
# run_case 의 "fail pass tb" 한 줄을 세 변수로 쪼갠다(외부 프로세스 없이 순수 파라미터
# 확장만 쓴다 — bash 3.2 호환, `<<<` here-string 불필요).
_split3() { _f="${1%% *}"; _r="${1#* }"; _p="${_r%% *}"; _tb="${_r#* }"; }

# 계측기 양성 대조 — 변이 없는 사본에서 케이스가 GREEN(그리고 traceback 없음).
CLEAN="$BASE_MUT/clean"; mkclone "$CLEAN"
for c in case_T35_frozen_change_auto_decide case_T10_protected_decide case_T05_T06_reject case_T11_permit_keeps_disposition case_T08_defer_disallowed case_T37_cap_and_extra case_AC6_fix_contract; do
  _split3 "$(run_case "$CLEAN" "$c")"
  if [ "$_tb" = "1" ]; then
    no "양성대조 실패: $c 가 clean 사본 실행 중 traceback — 계측기 고장(귀속 불가)"
  elif [ "$_f" = "0" ]; then
    ok "양성대조: $c 는 변이 없는 사본에서 GREEN (계측기 정상, 단언 $_p 건 생존)"
  else
    no "양성대조 실패: $c 가 clean 사본에서 이미 RED($_f) — 계측기 고장"
  fi
done

# mut <이름> <케이스> <sed 프로그램…> — 사본을 변이하고 케이스가 RED 인지 본다.
# **판정 조건에 「실패가 규칙에 귀속 가능할 것」이 들어간다(R19)**: 변이된 실행이
# 파이썬 traceback 을 내면 그 실패가 «규칙 위반 탓»인지 «이 파일이 조금이라도 깨지면
# 죽는 것 탓»인지 밖에서 구별할 수 없다 — 그런 셀은 「측정 불가」로 RED 고, `_ASSERT_FAIL`
# 이 몇이든 「잡혔다」로 세지 않는다. 생존 단언 수(`apass`)는 항상 메시지에 출력해
# 미래 독자가 변별력을 볼 수 있게 하되, 「생존 0」을 판정 기준으로 쓰지는 않는다
# (단언이 하나뿐인 케이스가 미래에 이 셀을 지목하면 오분류하기 때문 — 판정은 오직
# traceback 유무).
mut() {
  local name="$1" case="$2"; shift 2
  local d="$BASE_MUT/$name"; mkclone "$d"
  "$@" "$d" || { no "변이 '$name': sed 적용 실패"; return; }
  local bfail bpass btb afail apass atb
  _split3 "$(run_case "$CLEAN" "$case")"; bfail="$_f"; bpass="$_p"; btb="$_tb"
  _split3 "$(run_case "$d" "$case")";     afail="$_f"; apass="$_p"; atb="$_tb"
  if [ "$btb" = "1" ]; then
    no "변이 '$name': 양성 대조(clean 사본) 자체가 traceback — 계측기 고장, 측정 불가"
  elif [ "$bfail" != "0" ]; then
    no "변이 '$name' → $case 양성 대조 실패(clean=$bfail) — 계측기 고장"
  elif [ "$atb" = "1" ]; then
    no "변이 '$name' → $case 측정 불가 — 변이 실행이 traceback 을 냈다(RED($afail) 생존($apass) 이지만 규칙 귀속인지 크래시 귀속인지 구별 불가 — 「잡힘」으로 안 센다)"
  elif [ "$afail" != "0" ]; then
    ok "변이 '$name' → $case RED($afail) 생존($apass) (규칙에 이빨이 있다)"
  else
    no "변이 '$name' → $case 가 안 잡힘 (clean=$bfail, mutated=$afail) — 락이 이 규칙을 안 잰다"
  fi
}
sed_route()  { sed -i.bak "$1" "$2/docreview_route.py"  && rm -f "$2/docreview_route.py.bak"; }
sed_anchor() { sed -i.bak "$1" "$2/docreview_anchor.py" && rm -f "$2/docreview_anchor.py.bak"; }
sed_state()  { sed -i.bak "$1" "$2/docreview_state.py"  && rm -f "$2/docreview_state.py.bak"; }

# ① 얼림 diff 비활성 — 사후 auto decide 를 안 만든다.
# R19 이전엔 항목 자체를 안 만들어(`for c in []:`) case_T35 의 `[0]` 인덱싱 단언 3/4 이
# IndexError 로 죽었다(리뷰어 확대 측정: traceback 3, 생존 0/4). 항목은 그대로 만들되
# disposition 만 "decide"→"fix" 로 낮추고, disposition=="decide" 에서만 채워지는
# decision_view 를 그 자리에서 직접 채운다(같은 `_decision_view` 함수 재사용, `auto` 값도
# origin="auto" 그대로라 정확) — 그래서 evidence·decision_view 를 재는 단언 2~4 는 안
# 흔들리고, 규칙의 핵심(사후 항목이 실제로 decide 가 되는가)을 재는 단언 1 만 깨끗이 깨진다.
mut freeze_off case_T35_frozen_change_auto_decide sed_route \
  's/final\.append({"f": None, "layer": 1 if cls\["protected"\] else 2, "category": "frozen_change",/_fc = {"f": None, "layer": 1 if cls["protected"] else 2, "category": "frozen_change",/
s/"anchor": c\["anchor"\], "disposition": "decide",/"anchor": c["anchor"], "disposition": "fix",/
s/"prev_hash": c\.get("old_hash"), "immutable": cls\["immutable"\], "_source": "diff"})/"prev_hash": c.get("old_hash"), "immutable": cls["immutable"], "_source": "diff"}\
            _fc["decision_view"] = _decision_view(_fc, a.doc)\
            final.append(_fc)/'
# ② 보호 부류 승격 제거 — fix 가 decide 로 안 올라간다.
# R19 이전엔 승격 분기 전체를 꺼(`elif False and ...`) `promotion`·`promoted_from` 키 자체가
# 생기지 않아 case_T10 의 첫 단언이 그 키를 직접 인덱싱하다 KeyError 로 죽었다(traceback 2,
# 생존 0/2). `promotion`·`promoted_from`·`origin` 은 그대로 기록하고(「보호로 분류는 됐다」)
# `disposition` 만 원래 값으로 남긴다(「승격은 실제로 안 먹었다」) — 값 불일치로 첫 단언이
# 깨끗이 깨진다. `decision_view` 는 disposition=="decide" 일 때만 채워지는 필드라 그대로
# 두면 둘째 단언이 또 KeyError 로 죽으므로, 승격이 안 먹었다는 사실 그대로(`auto: False`)
# 직접 채워 둘째 단언도 크래시 없이 깨끗이 깬다.
mut protected_off case_T10_protected_decide sed_route \
  '/it\["promotion"\] = "protected"/{n;s/it\["disposition"\] = "decide"/it["decision_view"] = {"auto": False}  # MUT: promotion recorded but not applied/;}'
# ③ reject 의 evidence 요구 제거 — evidence 없는 reject 도 유효.
# R19 이전엔 가드를 `if True:` 로 눌러도 그 안의 `v["evidence"]` 접근은 그대로 남아, evidence
# 키가 아예 없는 verdict("AC 가 하나뿐이라")에서 KeyError 로 죽었다(리뷰어 원 발견 — 음성
# 대조로 확인: 무관한 구문 오류를 넣어도 같은 시그니처가 남). `v["evidence"]` 근처는 안
# 건드리고, evidence 없을 때의 else 분기(`L.coerced(...)`, 지금은 아무 효과 없는 로그 한
# 줄)를 `it["disposition"] = "drop"` 로 바꾼다 — reject 가 evidence 없이도 "먹혀서" 처분이
# 실제로 바뀌는 것을 재현하되, 항목을 findings 에서 제거하지는 않는다(제거하면
# case_T05_T06_reject 의 두 번째 단언이 쓰는 `fsum`(무조건 `[0]` 인덱싱)이 그 항목을 못
# 찾아 IndexError 로 다시 죽는다 — evidence 없는 reject 를 "진짜로" 유효화하는 어떤 sed 도
# 이 케이스에서는 이 크래시를 피할 수 없다는 것을 실측으로 확인했다, 아래 보고서 참조).
mut reject_no_evidence case_T05_T06_reject sed_route \
  's/L\.coerced("verdict", "reject", "confirm")/it["disposition"] = "drop"/'
# ④ 상향을 하향 허용으로 뒤집기 — raise to=drop 이 먹힌다
mut raise_down case_T03_T04_raise sed_route 's/RANK\[to\] > RANK\[it\["disposition"\]\]/RANK[to] != RANK[it["disposition"]]/'
# ⑤ id 에서 라운드 제거 — 같은 bucket 이 라운드 넘어 충돌
mut id_no_round case_T11_permit_keeps_disposition sed_route 's/"%s#r%d.%d" % (b, n, k)/"%s#r1.%d" % (b, k)/'
# ⑥ defer 예외 제거(불허 defer 를 fix 로) — AC10 위반
mut defer_to_fix case_T08_defer_disallowed sed_route 's/if d == "defer":/if d == "defer" and False:/'
# ⑦ 상한 3 으로 — 라운드 4 가 승인 없이 돈다
mut cap_three case_T37_cap_and_extra sed_state 's/^REREVIEW_CAP = 2$/REREVIEW_CAP = 3/'
# ⑧ check-intent 의 edit_scope 검사 제거 — 범위 밖도 통과
mut intent_no_scope case_AC6_fix_contract sed_anchor 's/if intent != scope:/if False and intent != scope:/'
# ⑨ 보호 부류 캐스케이드 제거(자기 제목만) — 하위 절이 자유 편집
mut protected_self_only case_anchor_protected_cascade sed_state 's/def _titles_of(sec, by_anchor):/def _titles_of(sec, by_anchor):\n    return [sec.get("title") or ""]  # MUT/'
# ⑩ same_as max 를 min 으로 — 낮은 처분이 남는다
mut same_as_min case_T02_same_as_max sed_route 's/keep = max(live, key=lambda m: (RANK\[items\[m\]\["disposition"\]\], m))/keep = min(live, key=lambda m: (RANK[items[m]["disposition"]], m))/'
finish
