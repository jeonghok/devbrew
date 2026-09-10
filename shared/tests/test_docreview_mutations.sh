#!/usr/bin/env bash
# guards: shared/docreview/scripts/*.py shared/tests/fixtures/docreview/**
#
# 변이 매트릭스 — 엔진 규칙을 하향으로 뒤집는 각 변이가 지정 케이스를 RED 로 만드는지 잰다.
# 행동 락(test_docreview_*.sh)이 GREEN 만 재는 것을 보완한다: GREEN 만 있는 락은 이빨이 없다.
#
# 방법: 스크립트 셋을 임시 디렉토리에 사본으로 두고(형제 adjudication.py 링크 포함), 그 사본을
# sed 로 변이한 뒤 cases.sh 의 한 케이스를 그 디렉토리로 돌린다. 케이스가 fail 하면(1건 이상 ✗)
# 그 변이는 «잡혔다». **양성 대조**: 변이 전 사본에서 같은 케이스가 GREEN 이어야 한다(계측기 검증).
#
# **케이스 작성 시 함정(Task 5·Task 8a 가 각각 실측) — 엄격 `d["key"]` 인덱싱은 이빨을 숨긴다.**
# 셀이 겨눈 규칙이 정확히 위반됐을 때, 그 위반이 어떤 키를 통째로 없애는 경우(예: 승격이
# 안 먹어 `promotion` 키 자체가 안 생김) 단언이 `d["key"]` 로 엄격 인덱싱하면 `KeyError` 로
# 죽는다 — `run_case` 의 traceback 검출기는 그 죽음을 규칙 위반(caught)이 아니라 **측정
# 불가**(unmeasurable, `classify_result` 참조)로 판정한다. 규칙이 실제로 깨졌는데도 판정은
# 「못 쟀다」로 나와 위반이 안 보이게 된다. 케이스 작성자는 그 값이 아예 사라질 수 있는
# 변이를 겨눌 때 `d["key"]` 대신 `d.get("key")` 를 써라 — 기대값이 구체적 리터럴(`"protected"`
# 같은)인 한 이 완화는 단언을 약화하지 않는다: 키가 없으면 `.get()` 은 `None` 을 내고,
# `None != "protected"` 는 여전히 RED 다. 약해지는 것은 크래시로부터의 «보호» 뿐, 판정의
# 엄격함이 아니다.
#
# **픽스처 헬퍼의 사각지대(Task 8b 이월 노트) — 시딩은 사본이 아니라 리포를 쓴다.**
# `st_set_reraise.py`·`st_set_stale_pointer.py`·`st_open_permit.py` 는 `load_state`/
# `save_state` 를 **리포의 `shared/docreview/scripts/`** 에서 import 한다(각 파일의
# `SCRIPTS_DIR = …parents[3] / "docreview" / "scripts"`). 매트릭스가 변이시키는 것은
# 임시 사본이므로, 이 헬퍼들이 픽스처를 «심는» 단계는 어떤 변이도 지나지 않는다.
# 지금은 무해하다 — 이 헬퍼를 쓰는 네 셀(`reraise_no_dedup`·`reraise_loss_uncounted`·
# `fwd_pointer_not_cleared`·`escalated_loss_uncounted`[Task 2, `st_set_escalated.py`
# 를 쓴다])은 전부 **엔진 술어**를 흔들고 그 술어는 사본에서 돈다.
# 그러나 훗날 상태 **직렬화기 자체**(`load_state`/`save_state`)를 겨눈 셀이 생기면,
# 이 헬퍼를 쓰는 케이스는 그 변이에 구조적으로 눈이 먼다 — 시딩이 pristine 직렬화기로
# 되기 때문이다. 그런 셀을 세우려면 먼저 헬퍼가 `$SCRIPTS`(사본)를 보게 바꿔야 한다.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  # `--emit-scanned` 의 계약은 **실제로 읽은** 경로다 — 선언에서 목록을 도출하면
  # 「락이 읽었다」의 증거가 아니라 선언의 자기 반복이다
  # (`test_guards_coverage_bidirectional.sh` 헤더). 이 매트릭스는 `golden/**` 과
  # `capture_finalize_golden.sh` 를 한 번도 안 읽으므로 그 일곱은 코퍼스 도출기가
  # 뺀다 — 근거와 형제 락들의 사정은 `docreview_fixture_corpus.sh` 헤더에.
  git ls-files -- 'shared/docreview/scripts/*.py'
  bash "$(dirname "$0")/docreview_fixture_corpus.sh"
  exit 0
fi
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

# classify_result <bfail> <btb> <afail> <atb> → 판정 하나:
#   instrument_broken | unmeasurable | caught | no_teeth
# **판정 로직은 이 함수 하나에만 있다(R20)** — mut()(기대=caught)와 카나리아(기대=
# unmeasurable, 아래 ⑪)가 이 함수를 똑같이 거쳐 같은 분기를 통과한다. 「실패가 규칙에
# 귀속 가능할 것」(R19): 변이된 실행이 파이썬 traceback 을 내면(atb=1) 그 실패가
# «규칙 위반 탓»인지 «이 파일이 조금이라도 깨지면 죽는 것 탓»인지 밖에서 구별할 수
# 없다 — unmeasurable 로 판정하고 caught 로 세지 않는다.
classify_result() {
  if [ "$2" = "1" ] || [ "$1" != "0" ]; then echo "instrument_broken"; return; fi
  if [ "$4" = "1" ]; then echo "unmeasurable"; return; fi
  if [ "$3" != "0" ]; then echo "caught"; return; fi
  echo "no_teeth"
}
# _churn <clean-dir> <mut-dir> → 변이가 실제로 만든 diff 규모를 `<삭제줄>/<추가줄>` 로.
#
# **왜 삭제줄만 세지 않는가** 〔실측〕 — 셀 ⑨(protected_self_only)의 치환은 원본 줄을
# 그대로 남기고 그 뒤에 한 줄을 «끼운다». 삭제줄만 세면 그 셀은 0 이 되어 **완전
# 무동작(매치 0건)과 구별되지 않는다.** 삭제·추가를 쌍으로 선언하면 순수 삽입은
# `0/1`, 무동작은 `0/0` 으로 갈린다.
#
# **왜 총합이 아니라 쌍인가** — 쌍이 엄격히 더 변별적이고 비용이 같다. 한 치환이
# 죽었을 때 삭제와 추가가 우연히 같은 폭으로 줄어 총합이 겹칠 여지를 없앤다.
#
# 사본의 모든 `*.py` 를 훑는다 — 셀이 실수로 다른 파일까지 건드리면 그것도 잡힌다
# (형제 `adjudication.py` 는 사본에서도 리포로의 심볼릭 링크라 항상 0/0 이다).
_churn() {
  local del=0 add=0 f b nd na
  for f in "$1"/*.py; do
    b="$(basename "$f")"
    nd="$(diff "$1/$b" "$2/$b" 2>/dev/null | grep -c '^<')"
    na="$(diff "$1/$b" "$2/$b" 2>/dev/null | grep -c '^>')"
    del=$((del + nd)); add=$((add + na))
  done
  echo "$del/$add"
}
# ── 치환 앵커 소실 가드 (Task 8b fix round 1) ─────────────────────────────
# **`sed` 는 매치 0 건에도 0 을 낸다.** 그래서 분해·리팩터가 대상 줄의 «모양»을 바꾸면
# 셀이 아무것도 안 바꾸면서 판정만 계속 낸다. 실측된 세 결말이 전부 다르고, 뒤로 갈수록
# 나쁘다 〔Task 8b 실측 + 리뷰 실측〕:
#   · 전량 소실           → `no_teeth`      (매트릭스가 소리를 낸다 — 그나마 낫다)
#   · 다중 치환의 일부 소실 → `unmeasurable` (「크래시라 못 쟀다」로 원인이 한 겹 가려진다)
#   · 다중 치환의 «독립» 일부 소실 → **`caught`** (규칙의 절반만 재면서 이빨이 있다고
#     보고한다. `안 잡힘` grep 에도, unmeasurable 휴리스틱에도, 스위트 총합에도 안 보인다)
# 마지막 것을 리뷰가 `same_as_unknown_target_silent` 에서 실측했다: x 쪽 치환만 죽여도
# fail=1 pass=1 로 **판정이 `caught` 그대로**다.
#
# 그래서 **각 셀이 자기 변이의 diff 규모를 선언하고 계측기가 실제와 대조한다.** 불일치는
# 규칙 판정이 아니라 «계측기 고장»으로 낸다 — 고장 난 것이 계측기이기 때문이다.
# 「파일이 바뀌긴 했는가」만 보는 가드로는 부족하다: 그것은 전량 소실만 잡고 위의 둘째·
# 셋째를 놓친다. 규모는 바로 위 `_churn` 이 잰다.
#
# **선언값은 측정으로 «채우지» 않았다** — 31 셀 전부를 각자의 sed 프로그램에서 손으로
# 도출한 뒤(치환 개수 · 한 줄이 몇 줄로 늘어나는가) 측정과 대조했고 31/31 일치했다.
# 측정값을 그대로 베끼면 이미 반쯤 죽어 있는 셀의 고장 난 값을 정답으로 굳힌다.
# mut_expect <기대판정> <churn> <이름> <케이스> <sed 프로그램…> — 사본을 변이하고 classify_result
# 의 판정이 <기대판정> 과 일치하는지 본다. 생존 단언 수(apass)는 항상 메시지에 출력해
# 미래 독자가 변별력을 볼 수 있게 하되, 「생존 0」을 판정 기준으로 쓰지는 않는다(단언이
# 하나뿐인 케이스가 미래에 어떤 셀을 지목하면 오분류하기 때문 — 판정은 오직 classify_result
# 가 낸 문자열과의 일치 여부).
mut_expect() {
  local expected="$1"; shift
  local churn_want="$1"; shift
  local name="$1" case="$2"; shift 2
  local d="$BASE_MUT/$name"; mkclone "$d"
  "$@" "$d" || { no "변이 '$name': sed 적용 실패"; return; }
  # 앵커 소실 가드는 «판정보다 앞»이다 — 계측기가 고장 났으면 그 뒤의 판정은
  # 무엇이 나오든 규칙에 귀속할 수 없다(caught 조차도).
  local churn_got; churn_got="$(_churn "$CLEAN" "$d")"
  if [ "$churn_got" != "$churn_want" ]; then
    no "변이 '$name': 치환 앵커 소실 — 실제 churn $churn_got, 선언 $churn_want (규칙 판정이 아니라 «계측기 고장»: 이 셀의 sed 중 일부 또는 전부가 대상 코드를 못 찾았다. 코드가 움직였으면 셀을 재앵커하고 선언값을 갱신하라)"
    return
  fi
  local bfail bpass btb afail apass atb verdict desc
  _split3 "$(run_case "$CLEAN" "$case")"; bfail="$_f"; bpass="$_p"; btb="$_tb"
  _split3 "$(run_case "$d" "$case")";     afail="$_f"; apass="$_p"; atb="$_tb"
  verdict="$(classify_result "$bfail" "$btb" "$afail" "$atb")"
  case "$verdict" in
    instrument_broken)
      if [ "$btb" = "1" ]; then desc="계측기 고장 — 양성 대조(clean 사본) 자체가 traceback"
      else desc="계측기 고장 — 양성 대조 실패(clean=$bfail)"; fi ;;
    unmeasurable) desc="측정 불가 — 변이 실행이 traceback 을 냈다(RED($afail) 생존($apass), 규칙 귀속인지 크래시 귀속인지 구별 불가)" ;;
    caught)       desc="RED($afail) 생존($apass) (규칙에 이빨이 있다)" ;;
    no_teeth)     desc="안 잡힘(clean=$bfail, mutated=$afail) — 락이 이 규칙을 안 잰다" ;;
  esac
  if [ "$verdict" = "$expected" ]; then
    ok "변이 '$name' → $case $desc [churn $churn_got]"
  else
    no "변이 '$name' → $case 판정=$verdict 기대=$expected 불일치 — $desc"
  fi
}
mut() { mut_expect caught "$@"; }   # 기존 10셀의 계약: 변이는 항상 caught 를 기대한다.
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
# [Task 8b 재앵커] `cmd_finalize` 분해로 사후·이월 생성이 `_auto_decides()` 로 나가면서
# 그 함수의 누산기 이름이 `final` → `extra` 로 바뀌었다(호출부가 `final.extend(extra)`).
# 옛 치환 1·3 은 `final.append(` 를 겨눴다 — 치환 1 은 **매치 0 건으로 조용히 무동작**이
# 됐는데 치환 2·3 은 여전히 맞아서, 셀은 no_teeth 가 아니라 **정의되지 않은 `_fc` 참조로
# 크래시**해 unmeasurable 로 떨어졌다(실측). 「매치 0 건도 성공」의 변종 — 여러 치환 중
# 일부만 죽으면 판정이 「안 잡힘」이 아니라 「못 잼」으로 나와 원인이 더 가려진다.
# BEFORE: s/final\.append({"f": None, "layer": 1 if …/  ·  주입부 `final.append(_fc)`
# AFTER : s/extra\.append({"f": None, "layer": 1 if …/  ·  주입부 `extra.append(_fc)`
# 겨누는 규칙(사후 얼림 diff 항목이 실제로 decide 가 되는가)은 바뀌지 않았다.
# [Task 4 fix round 1 — 리뷰 I1 이후 정정, 두 겹] 주입부의 `_decision_view(_fc, a.doc)`
# 호출이 두 인자짜리였다 — I1 이 `_decision_view` 에 `st` 셋째 인자를 더하면서
# (`_decision_view(it, doc, st)`) 첫 겹은 `TypeError: missing 1 required positional
# argument: 'st'` 였다(실측) — `_auto_decides` 스코프에 이미 있는 `st` 를 그대로
# 넘겨 고친다. 둘째 겹은 그 아래: `_decision_view` 본문이 이제
# `_is_reraise_successor(st, it["id"])` 를 부르는데, 이 주입 지점(`_auto_decides`
# 안, `_resolve_ids_and_lineage` 가 id 를 매기기 «전»)에서는 `_fc` 에 `"id"` 키가
# 아직 없다 — 진짜 프로덕션 경로는 `_decision_view` 를 `_remap_blocks` 에서 id
# 배정 «후»에만 부르므로 이 상태에 닿지 않는다(이 셀의 주입만이 만드는 인공
# 상태). `_fc["id"]` 를 플레이스홀더로 먼저 채운 뒤 부른다 — `_resolve_ids_and_
# lineage` 가 뒤에서 어차피 진짜 id 로 덮어쓰므로(`_fc` 도 `final` 의 다른 항목과
# 똑같이 그 배정을 거친다) 무해하다. 줄이 하나 늘어 churn 은 3/5 → 3/6.
mut 3/6 freeze_off case_T35_frozen_change_auto_decide sed_route \
  's/extra\.append({"f": None, "layer": 1 if cls\["protected"\] else 2, "category": "frozen_change",/_fc = {"f": None, "layer": 1 if cls["protected"] else 2, "category": "frozen_change",/
s/"anchor": c\["anchor"\], "disposition": "decide",/"anchor": c["anchor"], "disposition": "fix",/
s/"prev_hash": c\.get("old_hash"), "immutable": cls\["immutable"\], "_source": "diff"})/"prev_hash": c.get("old_hash"), "immutable": cls["immutable"], "_source": "diff"}\
            _fc["id"] = "frozen-mut-placeholder"\
            _fc["decision_view"] = _decision_view(_fc, a.doc, st)\
            extra.append(_fc)/'
# ② 보호 부류 승격 제거 — fix 가 decide 로 안 올라간다.
# R19 이전엔 승격 분기 전체를 꺼(`elif False and ...`) `promotion`·`promoted_from` 키 자체가
# 생기지 않아 case_T10 의 첫 단언이 그 키를 직접 인덱싱하다 KeyError 로 죽었다(traceback 2,
# 생존 0/2). `promotion`·`promoted_from`·`origin` 은 그대로 기록하고(「보호로 분류는 됐다」)
# `disposition` 만 원래 값으로 남긴다(「승격은 실제로 안 먹었다」) — 값 불일치로 첫 단언이
# 깨끗이 깨진다. `decision_view` 는 disposition=="decide" 일 때만 채워지는 필드라 그대로
# 두면 둘째 단언이 또 KeyError 로 죽으므로, 승격이 안 먹었다는 사실 그대로(`auto: False`)
# 직접 채워 둘째 단언도 크래시 없이 깨끗이 깬다.
mut 1/1 protected_off case_T10_protected_decide sed_route \
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
mut 1/1 reject_no_evidence case_T05_T06_reject sed_route \
  's/L\.coerced("verdict", "reject", "confirm")/it["disposition"] = "drop"/'
# ④ 상향을 하향 허용으로 뒤집기 — raise to=drop 이 먹힌다
mut 1/1 raise_down case_T03_T04_raise sed_route 's/RANK\[to\] > RANK\[it\["disposition"\]\]/RANK[to] != RANK[it["disposition"]]/'
# ⑤ id 에서 라운드 제거 — 같은 bucket 이 라운드 넘어 충돌
mut 1/1 id_no_round case_T11_permit_keeps_disposition sed_route 's/"%s#r%d.%d" % (b, n, k)/"%s#r1.%d" % (b, k)/'
# ⑥ defer 예외 제거(불허 defer 를 fix 로) — AC10 위반
mut 1/1 defer_to_fix case_T08_defer_disallowed sed_route 's/if d == "defer":/if d == "defer" and False:/'
# ⑦ 상한 3 으로 — 라운드 4 가 승인 없이 돈다
mut 1/1 cap_three case_T37_cap_and_extra sed_state 's/^REREVIEW_CAP = 2$/REREVIEW_CAP = 3/'
# ⑧ check-intent 의 edit_scope 검사 제거 — 범위 밖도 통과
mut 1/1 intent_no_scope case_AC6_fix_contract sed_anchor 's/if intent != scope:/if False and intent != scope:/'
# ⑨ 보호 부류 캐스케이드 제거(자기 제목만) — 하위 절이 자유 편집
mut 0/1 protected_self_only case_anchor_protected_cascade sed_state 's/def _titles_of(sec, by_anchor):/def _titles_of(sec, by_anchor):\n    return [sec.get("title") or ""]  # MUT/'
# ⑩ same_as max 를 min 으로 — 낮은 처분이 남는다
mut 1/1 same_as_min case_T02_same_as_max sed_route 's/keep = max(live, key=lambda m: (RANK\[items\[m\]\["disposition"\]\], m))/keep = min(live, key=lambda m: (RANK[items[m]["disposition"]], m))/'
# ⑪ 카나리아 — 일부러 크래시하는 변이(R19 이전의 옛 셀 ③ sed 그대로). evidence 가드를
# 무조건 참으로 눌러도 그 안의 `v["evidence"]` 접근은 그대로 남아, evidence 키가 없는
# verdict 에서 KeyError 로 죽는다(R19 리뷰어 원 발견 그대로 재현). **기대 판정은
# unmeasurable 이다** — «잡혔다»가 아니라 «크래시라 못 잰다»가 옳은 판정이기 때문.
# 이 셀은 classify_result 를 나머지 열 개와 똑같이 거친다(자체 traceback 검사를 따로
# 갖지 않는다) — 그래서 classify_result 의 atb 분기를 지우면(양의 짝, 보고서 참조)
# 판정이 caught 로 바뀌어 기대(unmeasurable)와 어긋나 이 셀 자체가 RED 로 소리를
# 낸다. 미래에 엔진이 바뀌어 이 sed 가 더는 안 죽어도 같은 방식으로 소리 낸다(판정이
# caught 가 되어 기대 unmeasurable 과 불일치) — 조용히 멎지 않는다.
mut_expect unmeasurable 1/1 canary_crash case_T05_T06_reject sed_route 's/if v.get("evidence"):/if True:/'
# [Task 3 실행 노트, fix round 1 에서 정정] ⑫(expired_blocks_forever) 는 여기 있었다 —
# 만료의 차단 해제를 «후속 존재» 의 역방향 스캔으로 재던 시절의 셀이다. 그 술어 자체가
# 전방 포인터로 바뀌면서 대상 문장이 사라져 sed 가 매치 0 건으로 무동작(no_teeth
# 실측)이 됐고, 그 셀이 재던 케이스(T22b 의 「채택·적용하면 승인이 다시 열린다」 꼬리)도
# 함께 지워졌다(위 실행 노트). [정정] 그 꼬리가 재던 개념 — 의무 이행이 «승인 게이트를
# 여는가» — 은 case_AC20_reexpiry_blocks_again 이 재지 않는다(그 케이스는 approval_ready
# 를 한 번도 안 읽고, 결말도 여전히 열린 계보로 끝난다) — case_T21_permit_applied 끝에
# 단언 하나(adopted·blocked_expired 둘 다 빈 채 승인 게이트가 열림)를 더해 되살렸다.
# case_AC20_reexpiry_blocks_again 이 실제로 재는 것은 다른 개념 — 의무 이행이 «차단
# 술어에서 항목을 빼는가»(`blocked_expired` 에서 사라지는가) — 이고, 술어에서
# `and not d.get("superseded_by")` 만 지워보면(수동 확인) 그 케이스가 그대로 RED 로
# 죽는다. 그 경로의 각 걸음(포인터를 쓰는가·비우는가)은 아래 ⑯⑰ 이 하향으로 흔든다.
# 번호는 당겨 채우지 않는다(과거 커밋 인용의 자릿수 정합).
# ⑬ 예약 누적 → 대입 복원. 조기 반환 라운드의 예약이 다음 observe-diff 에 사라진다.
mut 1/1 reraise_overwrite case_AC21_reraise_accumulates sed_state \
  's/^    st\["reraise"\] = pending$/    st["reraise"] = reraise/'
# ⑭ dedup 제거 — 같은 계보의 예약이 라운드마다 쌓인다.
# 리뷰 R1(fix round 1) — 이 셀이 흔드는 상태(같은 finding_id 의 예약 두 번)는 지금 CLI
# 경로로는 도달 불가(dedup 코멘트·case_AC21_reraise_dedup 참조) — 이 셀은 그 defense-in-depth
# 가 실제로 작동함을 재는 것이지, 그 상태가 살아있는 위협임을 재는 것이 아니다.
mut 1/1 reraise_no_dedup case_AC21_reraise_dedup sed_state \
  's/^        if r0\["finding_id"\] in seen:$/        if False:/'
# ⑮ 미소비 예약을 다시 조용히 버린다 — 계수가 0 으로 굳는다.
mut 1/1 reraise_loss_uncounted case_AC21_unconsumed_counted sed_route \
  's/^            reraise_unconsumed += 1.*$/            pass/'
# ⑯ 전방 포인터 대입 삭제 → 후속이 생겨도 영구히 막는다.
mut 1/1 fwd_pointer_never_written case_AC20_reexpiry_blocks_again sed_route \
  's/^            d0\["superseded_by"\] = it\["id"\]$/            pass/'
# ⑰ 포인터 초기화 삭제 → 재만료를 낡은 포인터가 푼다(조용한 승인).
# [Task 3 실행 노트] 브리프 원안은 이 셀을 case_AC20_reexpiry_blocks_again 에 겨눴으나
# 실측 no_teeth(clean=0, mutated=0) — 그 케이스가 만드는 두 decides 레코드(gid·succ) 중
# 어느 쪽도 pop() 이 지우는 대상 상태(포인터가 이미 찍힌 레코드가 같은 id 로 새 permit
# 을 다시 받는 것)에 놓이지 않는다: gid 의 permit 은 포인터가 찍히기 «전»에 이미 소모되고,
# succ 는 애초에 포인터를 받은 적이 없다. sed 패턴 자체는 정확히 매치한다(수동 확인) —
# 대상을 case_AC20_stale_pointer_cleared_on_reobserve(픽스처로 그 조합을 강제하는 케이스)
# 로 바꾼다.
# [Task 8a 재앵커] 이 셀과 ㉒(decide_pointer_not_cleared)은 같은 리터럴
# `d.pop("superseded_by", None)` 을 겨누고 오직 **들여쓰기**(8-space `cmd_observe_diff`
# vs 4-space `cmd_decide`)로만 갈렸다 — 오늘은 각자 정확히 한 줄만 맞지만, 훗날 누가
# `cmd_decide` 의 pop 을 `if` 안으로 옮기면(들여쓰기가 8-space 로 바뀌면) 이 셀이 «두
# 줄 다» 맞고도 여전히 caught 를 내 다른 것을 재는 줄 모른다(헤더-satisfiable 류 함정,
# CLAUDE.md 「grep 락의 헤더-satisfiable 함정」). 이 줄에만 있는 꼬리 주석으로 재앵커해
# 들여쓰기가 바뀌어도 자기 줄만 계속 맞게 한다 — 실측: 재앵커 후에도 정확히 한 줄만
# 맞고(다른 pop 은 안 건드림) 판정은 여전히 caught.
mut 1/1 fwd_pointer_not_cleared case_AC20_stale_pointer_cleared_on_reobserve sed_state \
  's/d\.pop("superseded_by", None)   # 이 만료 인스턴스는 끝났다.*/pass/'
# ⑱ 술어를 역방향 supersedes 스캔으로 복원 — 이 셀이 「전방이냐 역방이냐」의 유일한 변별기다.
#    앞의 둘은 «막느냐 마느냐» 만 흔들고 방향을 구별하지 않는다.
# [Task 3 재앵커] 원래 이 셀은 `gate_summary` 가 `blocked_expired` 를 직접 열거하던 줄
# (`if d["state"] == "expired" and not d.get("superseded_by")`)을 겨눴다. Task 3 가
# 그 열거를 `GATE_ROWS` 표의 `blocked_expired` 행 하나로 옮기면서 그 술어는
# `lambda r: r["state"] == "expired" and not r.get("superseded_by")` 가 됐는데,
# `gate_bucket(st, row)` 는 `row.pred(r)` 를 **레코드만** 넘겨 부른다(`i`, 곧 finding
# id 는 그 술어 서명 안에 없다) — 원래 이 셀이 겨누던 「`i not in {...}` 역방향 스캔」은
# id 를 요구하므로 행 술어 자리에서는 더 이상 표현할 수 없다(브리프의 `pred(r)` 서명을
# verbatim 으로 유지한 결과다). 앵커가 사라져 churn 0/0 으로 계측기가 고장 신호를 냈다
# (실측 — 재앵커 전 전체 스윕에서 이 셀 하나만 RED). 같은 개념(전방 포인터 대 역방향
# 스캔)을 여전히 잴 수 있는 자리는 `gate_bucket` 자신이다 — id(`i`)와 `st["findings"]`
# 둘 다 이 함수 스코프에 있다. `blocked_expired` 행일 때만 역방향 스캔으로 바꿔치기해
# 원래 sed 와 같은 판정식(`i not in {supersedes 타겟들}`)을 재현한다 — 프로덕션
# `gate_bucket` 은 그대로다(사본에서만 바뀐다, 아래 sed 는 mkclone 된 임시 사본을 겨눈다).
# churn 은 손으로 5줄 치환(1 삭제/5 추가)으로 도출했지만 실측은 0/4 였다 — 치환문의
# 마지막 줄(`return sorted(...) if row.pred(r))`)이 원본과 바이트가 같아 diff 의 LCS 가
# 그 줄을 "안 바뀜"으로 보고 앞 네 줄만 삽입으로 셌다(이 파일의 ⑨ protected_self_only
# 가 이미 실측한 것과 같은 종류 — 순수 삽입은 실제 diff 기준으로 선언해야 한다). 아래
# 선언값은 손 도출이 아니라 이 실측을 그대로 반영한다.
mut 0/4 predicate_backward_scan case_AC20_nonobligation_successors_still_block sed_state \
  's/return sorted(i for i, r in st\[row\.ledger\]\.items() if row\.pred(r))/if row.name == "blocked_expired":\
        return sorted(i for i, r in st[row.ledger].items()\
                      if r["state"] == "expired"\
                      and i not in {f.get("supersedes") for f in st["findings"].values() if f.get("supersedes")})\
    return sorted(i for i, r in st[row.ledger].items() if row.pred(r))/'

# ── 만료 재결정 탈출구 (Task 4, AC22) ───────────────────────────────────────
# ⑲ 탈출구를 되돌린다 → expired 는 다시 열지 않는다(영구 차단, 후속이 끝내 안 생기면
#    사용자에게 길이 없다).
# [Task 4(2026-09-08-docreview-design-doc-site) 재앵커] 원래 대상 줄(`cmd_decide` 안의
# `if d["state"] not in ("open", "expired"):`, bracket 인덱싱)은 §6.4 한계 (a) 가
# 그 술어를 `decide_choices`(선택지 축의 정본) 하나로 모으면서 사라졌다.
# [Task 4 fix round 1 — 리뷰 I1 이후 재재앵커] 그 뒤 `.get()` 형태로 한 번 옮겨
# 살았던 자리(`decide_choices` 안의 `d.get("state") not in (...)`)도 I1 정정이
# 순수 부분을 `_decide_choices_for(state, is_successor)` 로 마저 가르면서 다시
# 사라졌다 — 원장 조회(`d.get(...)`)가 아니라 인자로 받은 `state` 를 직접 본다.
# 재앵커 대상은 그 순수 함수의 첫 줄이다.
mut 1/1 expired_redecide_refused case_AC22_expired_escape_hatch sed_state \
  's/if state not in ("open", "expired"):/if state != "open":/'
# ⑳ 만료의 「보류」 거부를 지운다 → 보류 한 번에 승인이 열린다(구멍) — 위 BEFORE 재현이
#    바로 이 변이가 실제로 만드는 상태다.
# [Task 4 fix round 1 — 리뷰 I1 이후 재재앵커] 같은 이유로 다시 옮겼다. `_decide_
# choices_for` 의 둘째 가드(`if state == "expired" or is_successor:`)가 지금 「보류
# 제외」를 정하는 자리인데, 이 셀은 **expired 쪽 절만** 지운다(`or is_successor`
# 는 남긴다) — 안 그러면 이 셀이 재상승 후속의 보류 거부(㊸ `reraise_successor_
# hold_allowed` 가 정확히 그쪽을 겨눈다)까지 함께 흔들어 두 결함이 한 셀에 뭉친다.
mut 1/1 expired_hold_allowed case_AC22_expired_escape_hatch sed_state \
  's/^    if state == "expired" or is_successor:$/    if is_successor:/'
# ㉑ 가드를 완전히 연다 — 음의 요구(rejected·held·applied·adopted 네 상태 모두 거부)는
#    넓히는 변이로만 잰다(좁히는 변이는 이 술어에 닿지 않는다). [리뷰 M5] adopted 는
#    이미 연 permit 이 관측 대기 중이라 재결정 대상이 아니다(설계 §6.4) — 넷 중 하나만
#    빠지면 재는 폭이 좁아지므로 네 상태 전부 case 에 있어야 한다.
# [Task 4 fix round 1 — 리뷰 I1 이후 재재앵커] ⑲와 같은 이유·같은 새 대상 줄.
mut 1/1 redecide_guard_widened case_AC22_nonexpired_states_still_refused sed_state \
  's/if state not in ("open", "expired"):/if False:/'
# ㉒ 재결정이 자기 자신의 낡은 포인터를 지우는 것(설계 §6.4 규칙②, 브리프에 없던 정정 —
#    Task 3 은 `cmd_observe_diff` 의 관측-시점 pop 하나만 구현했다)을 지운다. 4-space
#    들여쓰기로 앵커해 `cmd_observe_diff` 의 8-space pop(⑰ 이 잡는 그 줄)과 구별한다 —
#    둘 다 똑같이 `d.pop("superseded_by", None)` 라 들여쓰기가 유일한 변별기다.
#    `case_AC22_stale_pointer_cleared_via_redecide` 의 중간 단언(재결정 «직후», 다음
#    라운드 관측 전)만 이 pop 을 격리해서 잰다 — 그 관측-시점 pop 은 다음 라운드까지
#    기다려야 걸리므로 이 창을 못 잡는다.
mut 1/1 decide_pointer_not_cleared case_AC22_stale_pointer_cleared_via_redecide sed_state \
  's/^    d\.pop("superseded_by", None)$/    pass/'
# ㉓ [리뷰 I1] post 만료의 원복-경고 꼬리(§6.4 탈출구 마지막 문장)를 지운다 → 렌더가
#    「채택」을 원복 관측 생략의 뜻으로 밝히지 않는다. `case_AC22_expired_escape_hatch`
#    만으로는 안 잡힌다(F_DEC 는 kind="pre") — post 만료까지 실제로 걷는
#    `case_AC22_post_expiry_render_tail` 이 유일한 검출기다.
mut 1/1 post_tail_removed case_AC22_post_expiry_render_tail sed_state \
  's/ if d\.get("kind") == "post" else ""/ if False else ""/'

# ── check-intent 일반 fix 경로의 앵커 실재 검사 (Task 5, AC23) ─────────────
# ㉔ 일반 경로의 앵커 실재 검사 제거 — 슬러그 오타가 보호 검사를 건너뛴다.
# insert-after 분기도 문자 그대로 같은 줄(`if not cls["found"] and target != PREAMBLE:`)을
# 갖고 있어 순수 텍스트 sed 는 둘 다 잡는다(헤더-satisfiable 함정) — 바로 앞 줄인
# `return escalate("anchor_immutable")`(파일에 유일)에 앵커해 `n` 으로 그 다음 줄만
# 겨눈다(cell ② 와 같은 기법).
mut 1/1 general_anchor_unresolved_off case_AC23_general_fix_anchor_unresolved sed_anchor \
  '/return escalate("anchor_immutable")/{n;s/if not cls\["found"\] and target != PREAMBLE:/if False:/;}'

# ── `_permit_covers` 의 라운드 경계 (Task 6, AC24) ──────────────────────────
# ㉕ permit 의 라운드 경계 삭제 — 낡은 permit 이 영원히 보호 승격을 막는다.
mut 1/1 permit_round_unbounded case_AC24_stale_permit_does_not_cover sed_route \
  's/if int(p\["round"\]) == n and anchor in p\["apply_anchors"\]/if anchor in p["apply_anchors"]/'

# ── 재비판 verdict 어휘 밖 값의 강제 계수 (Task 7, AC27) ────────────────────
# ㉖ 어휘 밖 verdict 의 강제 계수 제거 — 다시 조용히 confirm 이 된다.
mut 1/1 unknown_verdict_silent case_AC27_unknown_verdict_coerced sed_route \
  's/^                L\.coerced("verdict", vd, "confirm")$/                pass/'

# ── Task 8a — `cmd_finalize` 분해 «전» 커버리지 공백 넷 + 불변식 하나 (AC26 절반) ──
# 이 매트릭스 열둘(스물여섯 셀)은 계보 해소의 2패스 순서 · `blocks` 재매핑(keep_of) ·
# `escalated` 이월 · bucket 충돌 계수 중 어느 것도 겨누지 않았다 — Task 8b 의 분해가
# 이 넷을 깨도 지금까지는 소리가 안 났다. 다섯째는 이 PR 의 fail-closed 설계가 서 있는
# 불변식(재상승 후속은 `items` 를 안 지난다)이다.
#
# ㉗ 계보 해소 2패스 순서 붕괴 — 명시 지목(supersedes)을 먼저 큐에서 비우는 패스를
#    지우면, 단일 패스가 f-순서(익명화 정렬)대로 돈다. 이 케이스의 두 회귀-round-2
#    finding("AC 가 여전히 하나뿐이다"·"명시 지목")은 sha1(summary) 정렬상 무지목 쪽이
#    f1(먼저), 명시 지목 쪽이 f2(나중) — 실측 확인. 단일 패스에서 f1 이 먼저 돌면
#    무지목 항목이 자동 연결로 큐(원본 finding 하나)를 선점해 명시 지목과 같은 계보를
#    받아버린다(T15 위반: "지목된 조상은 자동 연결에서 빠지고 남는 것은 새 계보").
mut 1/1 lineage_two_pass_collapsed case_T14_T15_lineage sed_route \
  's/if it\.get("supersedes"):/if False:  # MUT: two-pass collapsed/'
# ㉘ `blocks` 재매핑에서 `keep_of` 리다이렉트 제거 — same_as 로 흡수된 원본을 가리키던
#    blocks 가 생존자의 최종 id 로 안 따라가고 그냥 사라진다(하향: 소실이 계수도 없이
#    조용히 일어난다). case_T02_same_as_max 는 b.py 의 ask 가 c.py 항목(same_as 로
#    흡수됨)을 blocks 로 가리키는 실제 흡수-재매핑 경로다.
mut 1/1 blocks_keep_of_bypassed case_T02_same_as_max sed_route \
  's/r2 = keep_of\.get(r, r)/r2 = r/'
# ㉙ escalated 미도래 예약 소실 — 아직 자기 차례가 아닌 예약(`round >= n`)을 버려서
#    keep_esc 에 안 남긴다(하향: 「소비되지 않으면 다음으로 넘어간다」가 「소비되지
#    않으면 사라진다」가 된다). 자연 경로로 이 분기를 밟으려면 finalize 를 건너뛴
#    라운드가 있어야 한다(AC21 의 reraise 조기-반환과 같은 종류) — 기존 케이스 중
#    이걸 겨눈 것이 없어 case_escalated_round_mismatch_carries_over 를 새로 썼다.
# [Task 2 재앵커] 그 케이스는 `case_escalated_accumulates` 로 이름이 바뀌고 기대값의
# 뜻이 뒤집혔다(이월 → 누적) — 이 셀이 겨누는 규칙(아직 자기 차례가 아닌 예약을
# «버리지 않고 보존»하는가)은 조건이 `!= n - 1` 이든 `>= n` 이든 그대로다. sed 대상
# `keep_esc.append(e)` 도 문자 그대로 살아있다(뒤에 주석만 붙었다) — 케이스 이름만
# 갱신한다.
# [F-6 재리뷰 정정] 셀 이름·설명이 옛 `!= n - 1`("불일치") 어휘였다 — `>= n` 아래에서
# `keep_esc` 가 잡는 것은 "불일치"가 아니라 "아직 자기 차례가 아님"(round ≥ n)이다.
# 이름·설명을 그 어휘로 고친다. sed 프로그램·판정 대상·churn 은 무변경.
mut 1/1 escalated_not_due_dropped case_escalated_accumulates sed_route \
  's/keep_esc\.append(e)/pass/'
# ㉚ bucket 충돌 계수 문턱을 1→2 로 올린다 — 정확히 둘이 충돌하는 실측 사례(T13)의
#    공시가 0 으로 죽는다(하향: 진짜 충돌인데 안 보인다). `v > 1` 은 파일에 유일.
mut 1/1 bucket_conflict_threshold_raised case_T13_ids_distinct sed_route \
  's/if v > 1/if v > 2/'
# ㉛ 재상승 후속을 `items` 파이프라인으로 새게 한다 — `final.append(...)` 대신
#    `items[...] =` 로 저장하면, 그 시점엔 same_as·재비판 verdict 처리·분류 루프가
#    이미 다 끝난 뒤라(파일에서 그 셋은 전부 이 줄보다 앞선다) `items` 는 죽은
#    변수다: 아무도 다시 안 읽는다. 그래서 이 항목은 `final`(따라서 출력·
#    `record_findings`)에서 통째로 사라진다 — same_as/reject 가 «먹혀서» 깨지는 게
#    아니라 애초에 안 만들어진 것처럼 사라지는 하향 변이다. escalated 블록(같은
#    리터럴 `final.append({"f": None, "layer": f0["layer"], ...`)과 문자 그대로
#    같아 순수 텍스트 sed 는 헤더-satisfiable 함정에 걸린다 — 바로 앞의 재상승
#    전용 가드(`if not d0 or d0.get("state") != "expired":`)부터 이 줄까지만
#    range 로 좁혀 재상승 쪽 occurrence 하나만 잡는다(수동 확인: escalated 의
#    동일 리터럴은 range 밖이라 안 건드림).
# [Task 8b 재앵커] 분해로 이 블록이 `_auto_decides()` 안으로 갔다 — 그 함수에는 `items`
# 가 **아예 없다**(불변식이 위치가 아니라 스코프로 보장되게 된 것 자체가 분해의 성과다).
# 그래서 옛 RHS `items["_reraise_leaked"] = (…)` 는 NameError 를 내고, 옛 LHS
# `final.append(` 는 누산기 개명(`extra`)으로 매치 0 건이 되어 셀이 no_teeth 로 떨어졌다(실측).
# BEFORE: s/final\.append({"f": None,/items["_reraise_leaked"] = ({"f": None,/
# AFTER : s/extra\.append({"f": None,/_leaked = ({"f": None,/
# 겨누는 규칙과 하향의 «관측 결과»는 그대로다 — 후속 항목이 만들어지되 누산기에 안 들어가
# `final`·출력·`record_findings` 에서 통째로 사라진다. 바뀐 것은 그 죽은 싱크의 이름뿐이다
# (옛 이름 `items` 는 「지나면 안 되는 파이프라인」을 가리켰고, 지금은 그 파이프라인이
# 이 스코프에 존재하지 않아 이름으로 가리킬 대상이 없다).
mut 1/1 reraise_leaks_into_items case_reraise_successor_immune_to_recritic sed_route \
  '/if not d0 or d0\.get("state") != "expired":/,/"_source": "reraise"}/{
s/extra\.append({"f": None,/_leaked = ({"f": None,/
}'

# ── same_as 가 가리키는 대상이 union-find 의 `parent` 에 없을 때의 강제 계수 (Task 7b, AC7b) ──
# ㉜ union-find 의 y-not-in-parent(및 x-not-in-parent) 갈래에서 coerced 호출 둘을
#    지운다 — 병합만 조용히 스킵되고 다시 원장 어디에도 안 남는 Task 7b 이전 상태로
#    돌아간다(AC27 의 어휘 밖 verdict 와 같은 종류의 하향). 두 줄 다 이 파일에 유일.
mut 2/2 same_as_unknown_target_silent case_AC7b_unknown_same_as_target_coerced sed_route \
  's/^                L\.coerced("same_as", x, None)$/                pass/
s/^                L\.coerced("same_as", y, None)$/                pass/'

# ── escalated 예약 누적·dedup·미소비 계수 (Task 2) — 재상승(AC21, 위 ⑬⑭⑮)과 같은
# 규칙을 escalated 예약에도 적용한다. 번호는 파일 끝에 이어 붙인다(당겨 채우지
# 않는다, 위 ⑬ 앞 주석의 관례) — ㉙(escalated_not_due_dropped)이 겨누는 자리(아직
# 자기 차례가 아닌 예약을 보존하는가)는 이 태스크로도 안 바뀌어 그 자리 그대로
# 둔다(케이스 이름만 `case_escalated_accumulates` 로 갱신, 위 참조).
# ㉝ escalated 축적 조건을 옛 규칙(`!= n - 1`)으로 되돌린다 — Task 2 의 핵심 수정을
#    직접 흔든다. `>= n` → `!= n - 1` 이면 라운드 1 예약(이번 라운드 3 보다 두
#    라운드 전)이 다시 「직전 라운드가 아니다」로 판정돼 keep_esc 로 이월되고,
#    case 의 첫 단언(fid1·fid2 둘 다 소비된다)이 fid2 하나만 나와 깨진다.
mut 1/1 escalated_prev_round_only case_escalated_accumulates sed_route \
  's/if int(e\["round"\]) >= n:/if int(e["round"]) != n - 1:/'
# ㉞ escalated dedup(`esc_seen`) 제거 — 같은 finding_id 가 두 번 예약되면 후속도
#    두 번 생긴다(하향: 라운드당 하나여야 할 후속이 중복된다). 형제 ⑭
#    (reraise_no_dedup)와 같은 종류·같은 기법(가드를 `if False:` 로 눌러 매번
#    통과시킨다). [F-2/F-3 재리뷰 재앵커] 상태-생존 검사(F-3, Ruling 20)가 이
#    가드 위에 끼어들며 그 술어 자체는 문자 그대로 살아있다(`fid` 로 변수화됐을
#    뿐 — 재리뷰 전엔 `e["finding_id"]` 였다).
mut 1/1 escalated_no_dedup case_escalated_dedup sed_route \
  's/^        if fid in esc_seen:$/        if False:/'
# ㊱ escalated dedup 을 finding_id 대신 round 로 키잉한다(F-1, 리뷰의 M8 재현) —
#    같은 라운드의 «다른» finding 이 dedup 에 삼켜져 후속 없이 사라진다(하향:
#    dedup 의 키 축이 뒤바뀐다). 세 자리를 함께 바꿔야 내적 일관성이 깨지지
#    않는다(`esc_seen` 이 dict — fid 키 하나만 바꾸면 `esc_seen[fid]` 참조가
#    KeyError 로 크래시해 unmeasurable 로 떨어진다, 수동 확인) — 판정 자리
#    (`if fid in esc_seen`) · L.absorbed 의 `into=` 조회(`esc_seen[fid]`) · 대입
#    자리(`esc_seen[fid] = ...`) 셋 다 `int(e["round"])` 로 통일해야 크래시 없이
#    "라운드로 키잉" 그 자체만 겨눈다.
mut 3/3 escalated_dedup_keyed_by_round case_escalated_dedup sed_route \
  's/if fid in esc_seen:/if int(e["round"]) in esc_seen:/
s/esc_seen\[fid\]))/esc_seen[int(e["round"])]))/
s/esc_seen\[fid\] = int(e\["round"\])/esc_seen[int(e["round"])] = int(e["round"])/'
# ㊲ escalated 미소비 계수를 다시 조용히 버린다 — 계수가 0 으로 굳는다(형제 ⑮
#    reraise_loss_uncounted 와 같은 종류·같은 기법).
mut 1/1 escalated_loss_uncounted case_escalated_unconsumed_counted sed_route \
  's/^            esc_unconsumed += 1.*$/            pass/'
# ㊳ F-3 — fix 가 «지금도» escalated 상태인지 보는 검사를 지운다(Ruling 20). drop
#    된 fix 의 잔존 예약이 소비 창(누적 이후 무한대)에서 다시 decide 로 부활한다
#    (하향: 사용자가 이미 처분한 fix 가 다시 승인을 막는다).
mut 1/1 escalated_fix_liveness_removed case_escalated_dropped_fix_not_resurrected sed_route \
  's/if not fx0 or fx0\.get("state") != "escalated":/if False:/'

# ── 상태 축의 정본 표 (Task 3) ───────────────────────────────────────────────
# ㊴ `ask_open` 행의 `from_decide` 배제를 지운다 — `decide --choice hold` 가 심은
#    ask(교차 원장, 위 case_GR_held_decide_cross_ledger 의 「facts I verified myself
#    ①」)가 held_decide 행과 함께 ask_open 행에도 걸려 같은 항목이 게이트에 두 번
#    렌더된다(하향: 이중 표시 — fail-open 은 아니지만 표의 「한 상태 = 한 행」 불변식이
#    깨진다). churn 은 손으로 한 줄 치환(1 삭제/1 추가)으로 도출했다 — lambda 줄
#    전체를 갈아 끼우고 뒤 문법(줄바꿈·쉼표)은 안 건드리므로 손 도출과 실측이 갈릴
#    이유가 없다(⑱ 처럼 치환문이 원본과 바이트가 겹치는 자리가 없다).
mut 1/1 ask_open_ignores_from_decide case_GR_held_decide_cross_ledger sed_state \
  's/lambda r: not r\.get("answered") and not r\.get("blocks") and not r\.get("from_decide"),/lambda r: not r.get("answered") and not r.get("blocks"),/'
# ㊵ `escalated_fix` 행의 `blocks` 를 True→False 로 되돌린다 — 설계 §6.4 한계(c)
#    (escalate 된 fix 가 비차단) 그 자체로 회귀한다. `approval_ready` 는
#    `GATE_ROWS` 의 `blocks` 필드에서 도출되므로(`gate_summary`), 이 한 줄이
#    이 태스크가 실제로 고친 결함의 유일한 스위치다.
mut 1/1 escalated_fix_no_longer_blocks case_GR_escalated_fix_blocks_approval sed_state \
  's/lambda r: r\["state"\] == "escalated", True, True, "escalated_fix"/lambda r: r["state"] == "escalated", True, False, "escalated_fix"/'

# ── Fix round 1 (리뷰 대응) ──────────────────────────────────────────────────
# ㊶ M7 — `cmd_fix` 의 escalate 분기가 fx 레코드에 `escalate_reason` 을 남기는 줄을
#    지운다. `st["escalated"]` 소비 뒤(라운드 2, finalize 지남) `_rg_escalated_fix`
#    가 읽을 자리가 없어져 「사유 불명」으로 떨어진다 — 진짜 사유(anchor_protected)가
#    둘째 라운드부터 조용히 사라지는 회귀(M7 원 결함)를 그대로 재현한다.
mut 1/1 escalate_reason_not_carried case_GR_escalated_fix_reason_persists sed_state \
  's/^        fx\["escalate_reason"\] = reason$/        pass/'
# ㊷ I2 — `_rg_escalated_fix` 의 렌더 문구에서 「drop 하면 이 차단이 풀린다」 힌트를
#    지운다. 코드(`cmd_fix` 의 drop 분기, 상태 가드 없음)는 그대로라 탈출구 자체는
#    여전히 동작하지만, 게이트 본문이 그 사실을 다시 감춘다 — I2 가 지적한 「승인이
#    다시 도달 가능한가를 렌더가 알려주지 않는다」결함으로 되돌린다.
mut 1/1 escalated_fix_no_drop_hint case_GR_escalated_fix_drop_clears_block sed_state \
  's/, drop 하면 이 차단이 풀린다)"$/)"/'

# ── 재상승 후속의 「보류」 (Task 4 of 2026-09-08-docreview-design-doc-site,
#    설계 §6.4 알려진 한계 (a)) ───────────────────────────────────────────────
# ㊸ 브리프 변이 ①. `_is_reraise_successor` 를 `return False` 로 눌러 「승계된
#    의무를 진 open」이라는 사실 자체를 지운다 — `decide_choices` 의 둘째 가드가
#    `d.get("state") == "expired" or False` 로 줄어 재상승 후속도 평범한 open 과
#    똑같이 「보류」를 받는다(구멍이 다시 열린다, 이 태스크가 닫으려던 바로 그것).
# churn 은 손으로 도출했다 — sed 가 앵커 줄(`def _is_reraise_successor...:`)을 «그대로
# 다시 낸 뒤» 새 줄 하나를 끼운다(⑨ protected_self_only 와 같은 기법). diff 의 LCS 는
# 안 바뀐 앵커 줄을 삽입 지점으로만 보므로 삭제 0·추가 1(1/2 가 아니다) — ⑨ 가 이미
# 실측으로 확정한 모양이다.
mut 0/1 reraise_successor_hold_allowed case_AC22b_reraise_successor_hold_refused sed_state \
  's/^def _is_reraise_successor(st, fid) -> bool:$/def _is_reraise_successor(st, fid) -> bool:\
    return False  # MUT/'
# ㊹ 브리프 변이 ②(적응) — [Task 4 fix round 1 — 리뷰 I1 이후 갱신] Task 4 원 라운드
#    시점엔 `_decision_view` 가 `decide_choices` 를 전혀 안 썼다("되돌릴 것이 없다")
#    는 것이 사실이었다 — 지금은 아니다: I1 정정이 `_decision_view` 를
#    `_decide_choices_for`(선택지 로직의 순수 부분, `decide_choices` 가 원장을 읽어
#    부르는 바로 그 함수)로 잇는다. 그래서 이 셀은 이제 «render_gate 쪽» 결선
#    하나만 겨눈다 — `_rg_decide` 의 `decide_choices` 호출을 걷어내고
#    `_decision_view` 와 같은 모양의 상수 목록으로 되돌린다. `_decision_view` 자신의
#    결선은 아래 ㊺ 이 별도로 겨눈다(둘은 이제 다른 두 자리다).
mut 1/1 rg_decide_alternatives_hardcoded case_choices_offered_equal_accepted sed_state \
  's/alternatives = \[_CHOICE_LABEL\[c\] for c in decide_choices(st, fid)\]/alternatives = ["채택(적용)", "기각(원복)", "보류"]/'

# ── Task 4 fix round 1 (리뷰 I1·I2·I3·I4 — §6.4 한계 (a) 재검토) ───────────────
# ㊺ I1 — `_decision_view` 를 `_decide_choices_for` 에서 다시 끊는다(그 함수는 계산
#    은 여전히 하지만 결과를 안 쓴다). fin.json 의 decision_view.alternatives 가
#    재상승 후속에도 다시 상수 셋을 낸다 — 리뷰가 실측으로 잡은 바로 그 채널
#    (fin.json·state.md·골든)이 다시 샌다. `docreview_route.py` 를 겨눈다(그
#    파일에만 있는 자리 — `sed_route`).
mut 1/1 decision_view_unwired case_AC22b_reraise_successor_hold_refused sed_route \
  's/"alternatives": \[_CHOICE_LABEL\[c\] for c in choices\],/"alternatives": ["채택(적용)", "기각(원복)", "보류"],/'
# ㊻ I2 — `_is_reraise_successor` 의 대상 특정(`== fid`)을 존재 검사(`is not None`)
#    로 넓힌다. state 안 «어딘가»에 승계 포인터가 하나라도 있으면 «그 id 와 무관한»
#    모든 open decide 가 재상승 후속 취급을 받아 「보류」를 잃는다 — 이 태스크가
#    닫으려던 결함의 거울상(대상이 없어서 넓어지는 대신, 대상이 있어도 좁아지지
#    않는 방향으로 과대 적용). `case_choices_offered_equal_accepted` 의 I2 양성
#    짝(재상승 사슬과 공존하는 무관한 open 의 「보류」가 성공해야 한다)만이 이
#    축을 잰다 — choices_match 두 단언은 양쪽이 같은 `decide_choices` 에서 나와
#    이 변이 아래서도 서로 계속 같다(순환, 리뷰의 핵심 지적).
mut 1/1 reraise_successor_overbroad_targeting case_choices_offered_equal_accepted sed_state \
  's/return any(d\.get("superseded_by") == fid for d in st\["decides"\]\.values())/return any(d.get("superseded_by") is not None for d in st["decides"].values())/'
# ㊼ I3① — 새 사유 리터럴을 옛 사유 리터럴로 무너뜨린다("만료라서 못 한다"와
#    "승계 의무를 지고 있어서 못 한다"가 같은 문자열이 된다). `case_AC22b_
#    reraise_successor_hold_refused` 의 사유 단언(이 fix round 가 새로 더했다,
#    Ruling 32 — 전엔 JSON 을 버렸다)만이 이 축을 잰다.
mut 1/1 reraise_reason_collapsed_into_expired case_AC22b_reraise_successor_hold_refused sed_state \
  's/return fail("decide_hold_not_allowed_for_reraise_successor", id=a\.id)/return fail("decide_hold_not_allowed_for_expired", id=a.id)/'
# ㊽ I3② — 「보존한다」던 두 리터럴(`decide_not_open`·`decide_hold_not_allowed_for_
#    expired`)을 함께 개명한다. 브리프의 전제("기존 케이스가 그 문자열을 재고
#    있다")가 거짓이었다는 리뷰의 지적(Ruling 32) 그대로 — 이 라운드 전엔 실제로
#    아무 락도 이 둘을 안 쟀다. `case_decide_reason_literals_not_open_and_expired`
#    가 새로 잰다. 두 곳을 한 sed 로 함께 개명한다(같은 결함의 두 절반).
mut 2/2 decide_reason_literals_renamed case_decide_reason_literals_not_open_and_expired sed_state \
  's/fail("decide_not_open", id=a\.id, state=d\["state"\])/fail("MUT_not_open_reason", id=a.id, state=d["state"])/
s/fail("decide_hold_not_allowed_for_expired", id=a\.id)/fail("MUT_expired_reason", id=a.id)/'
# ㊾ I4 — `_rg_expired` 를 `decide_choices` 에서 다시 끊고 옛 하드코딩(리뷰가 실제로
#    보인 깨진 모양, 「보류」까지 낸다)으로 되돌린다. `choices_match_expired` 단언
#    (이 fix round 가 새로 더했다)만이 이 축을 잰다 — `dc_choices "$blocked"` 는
#    `decide_choices` 자체를 부르므로 렌더가 갈려도 못 본다(같은 순환 지적, I2 와
#    같은 종류).
mut 1/1 rg_expired_unwired_and_offers_hold case_choices_offered_equal_accepted sed_state \
  's/alt = " \/ "\.join(_CHOICE_LABEL\[c\] for c in decide_choices(st, fid))/alt = "채택 \/ 기각 \/ 보류"/'

# ── 재상승 후속의 kind·prev_hash 승계 (Task 5, 2026-09-08-docreview-design-doc-site,
#    설계 §6.4 알려진 한계 (b)) ── 표준 원 숫자(①…㊾)는 지난 태스크들에서 이미
#    ㊾(49)까지 다 썼다 — 이 유니코드 블록의 마지막 글자는 ㊿(50) 하나뿐이라
#    넷 중 첫째만 원 숫자를 받고 나머지 셋은 (51)·(52)·(53) 으로 이어 붙인다.
#
# ㊿ 재상승 후속의 kind 승계를 하드코딩 "pre" 로 되돌린다 — 원본이 post(얼림 diff
#    가 만든 사후 결정, 기각으로 원복 permit 이 열렸다가 미관측 만료)였는데 후속이
#    다시 "pre" 로 태어난다(§6.4 한계 (b) 그 자체 — 되돌리지 않은 얼림 위반의
#    「채택」이 해시 대조 없는 apply permit 을 열어 그대로 승인된다).
#    `case_AC22c_reraise_inherits_post_kind` 만이 이 축을 잰다 — [fix round 1] 이
#    케이스가 이제 셋(kind · 후속 자신의 렌더 꼬리 · 「채택 → 즉시 applied」)이라
#    셋 다 이 변이 하나로 무너진다(cmd_decide 의 post 분기 자체가 안 타고,
#    `_post_kind_notice` 도 kind!="post" 라 빈 문자열을 낸다) — 실측 RED(3).
mut 1/1 reraise_kind_hardcoded_pre case_AC22c_reraise_inherits_post_kind sed_route \
  's/"kind": d0\.get("kind"), "prev_hash": d0\.get("prev_hash"),/"kind": "pre", "prev_hash": d0.get("prev_hash"),/'
# (51) prev_hash 승계만 지운다(kind 승계는 그대로 둔다) — 후속이 post 로는 태어나되
#    원복 대상 해시를 잃는다. `case_AC22c_reraise_inherits_prev_hash` 만이 이 축을
#    잰다 — [fix round 1 — 리뷰 M1] 그 케이스 첫 단언(공허성 바닥, 원본 prev_hash 가
#    실제 hex 모양인지)은 이 변이가 안 건드리는 값이라 계속 GREEN, 둘째(등식)만
#    RED — 실측 RED(1) 생존(1). kind 는 안 건드렸으므로
#    `case_AC22c_reraise_inherits_post_kind` 의 세 단언은 이 변이에서 여전히
#    GREEN 이다(두 변이가 서로 가리지 않도록 브리프가 요구한 분리, Step 3).
mut 1/1 reraise_prev_hash_dropped case_AC22c_reraise_inherits_prev_hash sed_route \
  's/"kind": d0\.get("kind"), "prev_hash": d0\.get("prev_hash"),/"kind": d0.get("kind"),/'
# (52) 반대 방향 회귀 — kind 승계를 무조건 "post" 로 강제한다("pre" 원본까지도
#    "post" 로 과대 일반화). 브리프의 두 변이는 post 원본만 겨눴다 — `d0.get(
#    "kind")` 는 양방향 값을 다루는 식이라 이 반대쪽 실패 모드를
#    `case_AC22c_reraise_preserves_pre_kind` 가 새로 잰다. [fix round 1 — 리뷰 I2
#    정정] 이 케이스가 이 방향을 «처음 잡는» 락은 아니다 — 같은 변이가
#    `test_docreview_golden.sh`(case_T22 후속의 kind 가 pre→post 로 갈려 fin.json·
#    state.md 둘 다 어긋난다)와 `case_AC20_reexpiry_blocks_again`(post 후속은 채택
#    즉시 applied 라 그 케이스가 기대하는 재만료 자체가 안 일어나 RED(2))도 함께
#    무너뜨린다. 이 케이스가 유일하게 갖는 것은 **귀속**이다 — 골든 diff 도 AC20③
#    의 실패 메시지도 `kind` 를 한 글자도 언급하지 않는데, 이 셀만 `kind` 단언을
#    직접 겨눈다. 위험한 이유: "post" 로 잘못 태어나면 「채택」이 permit 없이
#    즉시 applied 로 끝나(`cmd_decide` 의 post 분기) 「그 편집이 실제로
#    관측됐는가」를 검증하는 pre 의 정상 계약을 건너뛴다.
mut 1/1 reraise_kind_hardcoded_post case_AC22c_reraise_preserves_pre_kind sed_route \
  's/"kind": d0\.get("kind"), "prev_hash": d0\.get("prev_hash"),/"kind": "post", "prev_hash": d0.get("prev_hash"),/'
# (53) [fix round 1 — 리뷰 I1] `_rg_decide` 에서 사후 고지 꼬리 호출(`_post_kind_
#    notice(d)`)을 빼 원판(꼬리가 `_rg_expired` 에만 있던 상태)으로 되돌린다 —
#    이 셀이 겨누는 것은 배선이다: 리터럴 자체가 죽는 축은 기존 ㊾ 이웃의
#    `post_tail_removed`(`_rg_expired`·`case_AC22_post_expiry_render_tail` 짝)가
#    이미 재고, 여기는 `_rg_decide` 가 그 헬퍼를 «부르는지» 를 잰다 — 헬퍼가
#    멀쩡해도 호출이 빠지면 재상승 후속이 open_decide 로 렌더되는 동안은 여전히
#    안 보인다(이 태스크가 닫으려던 바로 그 결함의 재발 형태).
#    `case_AC22c_reraise_inherits_post_kind` 의 렌더 꼬리 단언만 RED — kind·
#    즉시-applied 단언은 렌더 텍스트와 무관해 생존한다(실측 RED(1) 생존(2)).
mut 1/1 rg_decide_post_tail_unwired case_AC22c_reraise_inherits_post_kind sed_state \
  's/"\[decide%s\] %s — %s%s" % (" auto" if dv\.get("auto") else "", fid, f\.get("summary"), _post_kind_notice(d)),/"[decide%s] %s — %s" % (" auto" if dv.get("auto") else "", fid, f.get("summary")),/'
# (54) 상태 디렉토리의 문서 정체 — `init` 의 문서 비교를 끈다. 다른 문서의 원장을 조용히
#    이어받던 그 동작이다. 거부 셀만 RED 가 된다.
mut 1/1 init_doc_compare_off case_init_other_doc_refused sed_state \
  's/if not isinstance(have, str) or doc_identity(have) != doc_identity(a\.doc):/if False:/'
# (55) 반대 방향 — 정규화를 빼고 원문 문자열로 비교한다. 같은 문서를 심볼릭 링크나 '/./'
#    표기로 부르면 거부되는 거짓 양성이다. 도출(`state-dir-for`)은 여전히 정규화하므로 같은
#    디렉토리에 앉은 같은 문서를 `init` 이 거부하게 된다 — 비교와 도출이 같은 정규화를 써야
#    하는 이유를 양의 짝(`case_init_same_doc_idempotent`)이 잰다.
mut 1/1 init_doc_compare_raw case_init_same_doc_idempotent sed_state \
  's/doc_identity(have) != doc_identity(a\.doc)/have != a.doc/'
# (56) 프로필 비교를 끈다 — 같은 문서의 원장을 다른 프로필(허용 처분·앵커 규칙이 다르다)로
#    이어간다.
mut 1/1 init_profile_compare_off case_init_other_profile_refused sed_state \
  's/if not isinstance(have, str) or profile_identity(have) != profile_identity(a\.profile):/if False:/'
# (57) 도출에서 문서 경로를 뺀다 — 해시가 루트만의 함수가 되면 이름이 같은 다른 문서가 한
#    디렉토리를 나눠 쓴다. 이름표(stem)는 남아 파일 이름이 다른 문서끼리는 여전히 갈리므로
#    케이스는 이름이 같은 두 문서로 잰다.
mut 1/1 state_dir_for_doc_dropped case_state_dir_for_per_doc sed_state \
  's/digest = hashlib\.sha256(os\.fsencode(ident))\.hexdigest()\[:16\]/digest = hashlib.sha256(os.fsencode(str(root))).hexdigest()[:16]/'
finish
