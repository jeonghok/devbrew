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
# 한 케이스를 한 SCRIPTS 로 돌려 ✗ 개수를 센다.
run_case() {   # run_case <scripts-dir> <case-fn> → ✗ 개수
  ( set +u
    REPO_ROOT="$REPO_ROOT"; SCRIPTS="$1"
    . "$REPO_ROOT/shared/tests/assert.sh"; . "$REPO_ROOT/shared/tests/fixtures/docreview/cases.sh"
    "$2" >/dev/null 2>&1
    echo "$_ASSERT_FAIL"
  )
}
# 계측기 양성 대조 — 변이 없는 사본에서 케이스가 GREEN.
CLEAN="$BASE_MUT/clean"; mkclone "$CLEAN"
for c in case_T35_frozen_change_auto_decide case_T10_protected_decide case_T05_T06_reject case_T13_ids_distinct case_T08_defer_disallowed case_T37_cap_and_extra case_AC6_fix_contract; do
  f="$(run_case "$CLEAN" "$c")"
  [ "$f" = "0" ] && ok "양성대조: $c 는 변이 없는 사본에서 GREEN (계측기 정상)" || no "양성대조 실패: $c 가 clean 사본에서 이미 RED($f) — 계측기 고장"
done

# mut <이름> <케이스> <sed 프로그램…> — 사본을 변이하고 케이스가 RED 인지 본다.
mut() {
  local name="$1" case="$2"; shift 2
  local d="$BASE_MUT/$name"; mkclone "$d"
  "$@" "$d" || { no "변이 '$name': sed 적용 실패"; return; }
  local before after
  before="$(run_case "$CLEAN" "$case")"; after="$(run_case "$d" "$case")"
  if [ "$before" = "0" ] && [ "$after" != "0" ]; then
    ok "변이 '$name' → $case RED($after) (규칙에 이빨이 있다)"
  else
    no "변이 '$name' → $case 가 안 잡힘 (clean=$before, mutated=$after) — 락이 이 규칙을 안 잰다"
  fi
}
sed_route()  { sed -i.bak "$1" "$2/docreview_route.py"  && rm -f "$2/docreview_route.py.bak"; }
sed_anchor() { sed -i.bak "$1" "$2/docreview_anchor.py" && rm -f "$2/docreview_anchor.py.bak"; }
sed_state()  { sed -i.bak "$1" "$2/docreview_state.py"  && rm -f "$2/docreview_state.py.bak"; }

# ① 얼림 diff 비활성 — 사후 auto decide 를 안 만든다
mut freeze_off case_T35_frozen_change_auto_decide sed_route 's/for c in diff.get("changed", \[\]):/for c in []:/'
# ② 보호 부류 승격 제거 — fix 가 decide 로 안 올라간다
mut protected_off case_T10_protected_decide sed_route 's/elif cls\["protected"\] and d != "decide"/elif False and cls["protected"] and d != "decide"/'
# ③ reject 의 evidence 요구 제거 — evidence 없는 reject 도 유효
mut reject_no_evidence case_T05_T06_reject sed_route 's/if v.get("evidence"):/if True:/'
# ④ 상향을 하향 허용으로 뒤집기 — raise to=drop 이 먹힌다
mut raise_down case_T03_T04_raise sed_route 's/RANK\[to\] > RANK\[it\["disposition"\]\]/RANK[to] != RANK[it["disposition"]]/'
# ⑤ id 에서 라운드 제거 — 같은 bucket 이 라운드 넘어 충돌
mut id_no_round case_T13_ids_distinct sed_route 's/"%s#r%d.%d" % (b, n, k)/"%s#r1.%d" % (b, k)/'
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
