#!/usr/bin/env bash
# guards: shared/docreview/scripts/docreview_state.py shared/docreview/references/reviewing-document.md shared/tests/fixtures/docreview/golden/*.gate.txt
# AC41 — 게이트 렌더의 모든 줄에 괄호 밖 내부 기호(지적 id · AC 번호 · §)가 없다.
#
# 두 코퍼스를 잰다.
#  (1) 행마다 그 행 하나가 선 원장을 지어 돌린 렌더 — GATE_ROWS 열 행 전부 + 첫 줄을 바꾸는 상태
#      (탐지 리뷰어 일부 사망 · 「미검증」 · 경고 줄 · 정체 · 상한 · 추가 라운드 1단계 · 승인 준비).
#      기호 없는 요약을 가진 픽스처만 쓴다 — 요약에 § 가 있으면 사람 글이 아니라 리뷰어 글이라 못 잰다.
#  (2) 커밋된 골든 gate.txt 전부 — 여기는 리뷰어가 쓴 § 가 근거 줄에 있으므로 지적 id · AC 번호만 잰다.
# 괄호 지우기는 짝이 맞는 ( … ) 만 지운다. 「…」 는 지우지 않는다.
# 행마다 «실제로 섰는가» 양성 짝을 둔다(묶음 제목 줄) — 안 서면 그 행의 단언은 공허하다.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/scripts/docreview_state.py"; echo "shared/docreview/references/reviewing-document.md"; (cd "$(dirname "$0")/../.." && ls shared/tests/fixtures/docreview/golden/*.gate.txt); exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPTS="${SCRIPTS:-$REPO_ROOT/plugins/spec-distill/scripts}"
. "$HERE/fixtures/docreview/cases.sh"

outside_parens() { python3 -I -c '
import re, sys
for line in sys.stdin.read().split("\n"):
    prev = None
    while prev != line:
        prev = line
        line = re.sub(r"\([^()]*\)", "", line)
    print(line)
'; }
SYM_RE='[0-9a-f]{8}#r[0-9]+\.[0-9]+|(^|[^A-Za-z])AC[0-9]+|§'
IDAC_RE='[0-9a-f]{8}#r[0-9]+\.[0-9]+|(^|[^A-Za-z])AC[0-9]+'

# 계측기 양성 대조 — 괄호 밖 id 한 줄을 넣으면 잡고, 괄호 안이면 놓아준다.
probe="$(printf '%s\n' "- 이 답을 기다리는 수정: bbbb0001#r1.1" | outside_parens | grep -cE "$SYM_RE")"
assert_eq "$probe" "1" "AC41 계측기: 괄호 밖 id 는 잡힌다"
probe="$(printf '%s\n' "- 이 답을 기다리는 수정 1개 (bbbb0001#r1.1 · 기다리는 것 cccc0001#r1.1)" | outside_parens | grep -cE "$SYM_RE")"
assert_eq "$probe" "0" "AC41 계측기: 괄호 안 id 는 놓아준다"

check_render() {   # check_render <label> <dir> <needle>... — 렌더에 기호 없음 + 모든 needle 이 있다(양성 짝)
  local label="$1" d="$2"; shift 2
  local out leak n
  out="$(py docreview_state.py gate --state-dir "$d" --render)"
  [ "${FIRST_LINE_ONLY:-0}" = 1 ] && out="$(printf '%s\n' "$out" | head -1)"
  leak="$(printf '%s\n' "$out" | outside_parens | grep -nE "$SYM_RE" || true)"
  assert_eq "$leak" "" "AC41: [$label] 괄호 밖에 지적 id · AC 번호 · § 가 없다"
  for n in "$@"; do
    assert_contains "$out" "$n" "AC41 양성 짝: [$label] 렌더에 «${n}» 이 섰다"
  done
}

F_ASK_ONLY='{"id":"cccc0001#r1.1","lineage":"cccc0001#r1.1","bucket":"cccc0001","origin":"reviewer","layer":2,"category":"ambiguity","anchor":"#12-files-to-modify","edit_scope":"#12-files-to-modify","disposition":"ask","summary":"그냥 물어본다","evidence":null,"blocks":[]}'
F_ASK_NOFIX='{"id":"cccc0001#r1.1","lineage":"cccc0001#r1.1","bucket":"cccc0001","origin":"reviewer","layer":2,"category":"ambiguity","anchor":"#12-files-to-modify","edit_scope":"#12-files-to-modify","disposition":"ask","summary":"b.py 를 유지하나?","evidence":null,"blocks":["dddd0001#r1.1"]}'
D1='aaaa0001#r1.1'; D2='bbbb0001#r1.1'

# ── (1) 행마다 ──────────────────────────────────────────────────────────────
d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
check_render "open_decide" "$d" "정할 것 1개" "$D1"; rm -rf "$d"

d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
py docreview_state.py decide --state-dir "$d" --id "$D1" --choice adopt --quote '채택' >/dev/null
check_render "adopted" "$d" "고치기로 했고 반영 확인을 기다리는 것 1개"; rm -rf "$d"

d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
py docreview_state.py decide --state-dir "$d" --id "$D1" --choice adopt --quote '채택' >/dev/null
next_round "$d" "$FX/design-sample.md" >/dev/null
check_render "blocked_expired" "$d" "기한이 지나 막힌 결정 1개"
python3 "$FX/st_set_stale_pointer.py" "$d/docreview-state.md" "$D1" 'dddd9999#r9.9' '#12-files-to-modify'
check_render "superseded_expired" "$d" "다른 결정으로 넘어간 것 1개" "이어받은 것 dddd9999#r9.9"; rm -rf "$d"

d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
py docreview_state.py decide --state-dir "$d" --id "$D1" --choice hold --quote '나중에' >/dev/null
check_render "held_decide" "$d" "미뤄 둔 결정 1개"; rm -rf "$d"

d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
check_render "unapplied_fix" "$d" "아직 안 고친 곳 1개"
py docreview_state.py fix --state-dir "$d" --id "$D2" --event escalate --reason 'check-intent 거부' >/dev/null
check_render "escalated_fix" "$d" "고치려다 막힌 곳 1개"; rm -rf "$d"

d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
py docreview_state.py fix --state-dir "$d" --id "$D2" --event hold >/dev/null
check_render "held_fix" "$d" "질문의 답을 기다리는 수정 1개"; rm -rf "$d"

d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_ASK_NOFIX]"
check_render "blocking_ask_open" "$d" "수정의 전제가 되는 질문 1개" "이 답을 기다리는 수정 1개 (cccc0001#r1.1 · 기다리는 것 dddd0001#r1.1)"; rm -rf "$d"

d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_ASK_ONLY]"
check_render "ask_open" "$d" "답을 기다리는 질문 1개"; rm -rf "$d"

# 결정 때문에 함께 고친 절(신고) — 두 행 종류. 결정 id(D1.1)도 괄호 안에만 둔다.
d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
py docreview_state.py decide --state-dir "$d" --id "$D1" --choice adopt --quote '채택' >/dev/null
py docreview_state.py declare-related --state-dir "$d" --decision D1.1 --anchors '#2-goals' '#3-non-goals' >/dev/null
next_round "$d" "$FX/design-sample-r2.md" >/dev/null
check_render "related_changed_unchanged" "$d" "이 결정 때문에 함께 바뀐 곳 1개 (D1.1)" "신고했지만 바뀌지 않은 곳 1개 (D1.1)"; rm -rf "$d"

# 고칠 범위가 기록 검증을 못 넘는 decide — 채택을 고를 수 없다는 줄(이유 · 사유 키 · 범위는 괄호 안)
d="$(mk_state "$FX/brief-append-r1.md" "$PROF_SD/brief.md")"; br "$d" "$FX/brief-append-r1.md"
seed_findings "$d" "[${F_BRIEF_NOIMM/EDIT_SCOPE/#6-사용자-원문}]"
check_render "adopt_unavailable" "$d" "정할 것 1개" "고친다(채택)는 고를 수 없다 — 고칠 범위가 바꾸면 안 되는 사용자 원문 절이다 (edit_scope_refused"; rm -rf "$d"

# 옛 원장(결정 기록 절의 줄 기록 없음)의 첫 라운드 — 덧붙이기 검사를 못 했다는 공시
d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")"; log_docs "$d"; br "$d" "$d/r1.md"
PYTHONPATH="$SCRIPTS" python3 -c 'import sys; from docreview_state import load_state, save_state; d=sys.argv[1]; st=load_state(d); [s.pop("line_hashes", None) for s in st["snapshots"]["1"]["sections"]]; save_state(d, st, "fixture: 옛 원장")' "$d"
br "$d" "$d/r2a.md"
check_render "log_check_skipped" "$d" "결정 기록 · 미룬 항목 절이 덧붙이기만 됐는지 이번 라운드는 확인하지 못했다"; rm -rf "$d"

# 첫 줄을 바꾸는 상태
d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
check_render "approval_ready" "$d" "다음: 승인 게이트 — 진행 옵션을 고를 수 있다"; rm -rf "$d"

d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC,$F_FIX]"
next_round "$d" "$FX/design-sample.md" >/dev/null; next_round "$d" "$FX/design-sample.md" >/dev/null
check_render "cap_open" "$d" "열린 지적 2개" "「열린 지적 2개를 두고 진행」" "추가 라운드 1회 열기"; rm -rf "$d"

d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
next_round "$d" "$FX/design-sample.md" >/dev/null; next_round "$d" "$FX/design-sample.md" >/dev/null
check_render "cap_zero_open" "$d" "열린 지적 0개" "진행 옵션으로"; rm -rf "$d"

d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_FIX]"
next_round "$d" "$FX/design-sample.md" >/dev/null
seed_findings "$d" "[${F_FIX/bbbb0001#r1.1\"/bbbb0001#r2.1\"}]"
check_render "stagnation" "$d" "열린 지적 2개"; rm -rf "$d"

d="$(r1_detectors 3 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
cp "$FX/critic-d2.txt" "$d/critic-2.txt"; cp "$FX/critic-broken.txt" "$d/critic-3.txt"
py docreview_route.py prepare-recritic --state-dir "$d" --critic "$(critic_now "$d" "$FX/critic-r1.txt")" --critic "$d/critic-2.txt" --critic "$d/critic-3.txt" > "$d/prep.json"
py docreview_route.py finalize --state-dir "$d" --recritic-skipped --doc "$FX/design-sample.md" > "$d/fin.json"
FIRST_LINE_ONLY=1 check_render "detector_partial_death" "$d" "탐지 리뷰어 3명 중 1명이 결과를 내지 못했다"; rm -rf "$d"

d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
critic_dead_twice "$d"
FIRST_LINE_ONLY=1 check_render "unverified" "$d" "「미검증」 리뷰어(doc-critic)가 결과를 내지 못해"; rm -rf "$d"

d="$(route_r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
FIRST_LINE_ONLY=1 check_render "route_warnings" "$d" "경고 "; rm -rf "$d"

# ── (2) 커밋된 골든 gate.txt — id · AC 번호만(근거 줄에 리뷰어가 쓴 § 가 있다) ─────────────
GOLD="$HERE/fixtures/docreview/golden"
n_gold=0
for f in "$GOLD"/*.gate.txt; do
  [ -f "$f" ] || continue
  n_gold=$((n_gold + 1))
  leak="$(outside_parens < "$f" | grep -nE "$IDAC_RE" || true)"
  assert_eq "$leak" "" "AC41: 골든 $(basename "$f") 의 괄호 밖에 지적 id · AC 번호가 없다"
done
[ "$n_gold" -ge 5 ] && ok "AC41 양성 짝: 골든 gate.txt ${n_gold}건을 쟀다" || no "AC41: 골든 gate.txt 가 ${n_gold}건뿐이다 — 코퍼스가 비었다"

REF="$REPO_ROOT/shared/docreview/references/reviewing-document.md"
body="$(grep -vE '^#' "$REF")"
assert_contains "$body" "질문 · 선택지 이름에 AC 번호 · 지적 id · § 를 쓰지 않고 설명 괄호에만 쓴다" "AC41: 게이트 절 규칙 문장이 절차서 본문에 있다"
assert_contains "$body" "--extra-approval-source" "AC40: 절차서가 출처 플래그를 가르친다"
assert_contains "$body" "「고친다(채택)는 고를 수 없다」 줄이 붙은 결정은 그 선택지를 질문에 넣지 않는다" "AC38 3차: 절차서가 고를 수 없는 채택을 질문에서 빼라고 가르친다"
assert_not_contains "$body" "사용자 자신의 문구" "AC40: 옛 승인 문면이 절차서에 없다"
finish
