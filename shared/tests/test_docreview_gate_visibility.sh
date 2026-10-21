#!/usr/bin/env bash
# guards: shared/docreview/scripts/docreview_state.py shared/tests/fixtures/docreview/**
#
# 「승인을 막는 상태는 반드시 게이트 본문에 보인다」— 그리고 그 반대인 「막지 않는다고
# 표에 적힌 상태는 정말로 막지 않는다」(양성 짝, Ruling 19).
#
# 코퍼스를 열거하지 않는다 — `gate-rows` 가 내는 표에서 두 코퍼스를 **도출**한다:
#   · 가시성 코퍼스 — `render` 가 null 이 아닌 모든 행(승인을 막든 안 막든, 표가 「이
#     상태는 게이트 본문에 보여야 한다」고 선언한 전부). 각 행마다 그 상태 하나만
#     살아 있는 state 를 만들어 `gate --render` 본문에 그 finding id 가 나오는지 본다.
#   · 차단 코퍼스 — `blocks` 가 true 인 모든 행. 그 상태 하나만 살아 있으면
#     `approval_ready` 가 False 인지 본다.
# 행 ↔ 픽스처 집합 등식은 **가시성** 코퍼스로 잰다 — 렌더러가 있는 행은 모두 도달
# 픽스처가 있어야 하고(차단 여부와 무관), 브리프 원안의 「차단 코퍼스로 등식」은 이
# 태스크가 고치려는 축(비차단이라 안 그려지는 다섯 — `held_decide`·`ask_open`·
# `held_fix`·`superseded_expired`·`blocking_ask_open`)을 스스로 못 본다(Ruling 18).
#
# 양성 짝(Ruling 19) — `blocks` 가 false 인 행마다 그 상태 하나만 살아 있을 때
# `approval_ready` 가 True 인지도 같이 본다. 이게 없으면 「안 막는다」는 부재 단언이라,
# 실제로는 막는 행이 표에 `blocks: false` 로 잘못 적혀도 위 차단 단언들이 전부
# 공허하게 통과한다 — 절반짜리 락이 이빨 있는 척한다.
#
# [Fix round 1 — C1/Ruling 26 정정] 이 문단은 원래 "새 차단 상태가 표에 추가되면 이
# 락이 그 행의 픽스처를 요구하므로 렌더를 빠뜨린 채 상태를 늘릴 수 없다"고 적었는데
# **거짓이었다** — 등식은 가시성 코퍼스(render != null)만 돈다. `blocks=True,
# render=None` 인 행을 표에 더하면 그 행은 애초에 가시성 코퍼스 밖이라 등식도 루프도
# 그 행을 아예 모른다 — 픽스처가 없어도 등식은 계속 통과한다(리뷰 실측: `GateRow(
# "applied_fix_blocks", "fixes", …, True, True, None)` 을 표에 더하자 이 락을 포함해
# 스위트 5개 전부 GREEN). 그 결함류(승인은 막는데 게이트 어디에도 안 그려진다)가 바로
# 이 태스크의 제목 그 자체다. 아래 「차단 ⊆ 가시성」 단언이 그 자리를 실제로 잰다 —
# 차단 코퍼스의 모든 행이 가시성 코퍼스 안에도 있는지(즉 렌더러를 갖는지)를 직접
# 확인한다. 표의 다섯 열(name·ledger·open·blocks·render) 자체가 흔들리는 것은 이
# 등식·포함관계 어느 쪽도 못 잡는다(같은 `gate-rows` 출력에서 기대값과 계산이 함께
# 움직이므로) — 그건 아래 「독립 증인」(Ruling 29)의 몫이다.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$REPO_ROOT/shared/tests/assert.sh"
SCRIPTS="$REPO_ROOT/plugins/spec-distill/scripts"   # 형제 import(adjudication.py)가 잡히는 호스트 경로
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/scripts/docreview_state.py"; bash "$(dirname "$0")/docreview_fixture_corpus.sh"; exit 0
fi
. "$REPO_ROOT/shared/tests/fixtures/docreview/cases.sh"
export PYTHONDONTWRITEBYTECODE=1

# ── 행별 도달 픽스처 ────────────────────────────────────────────────────────
# `gv_reach_<행이름>` 은 「호출자가 만든 state 디렉토리(인자 `$1`)에 그 상태 하나만
# 살아 있는 원장을 짓고, 그 finding id 를 stdout 에 낸다」는 계약의 함수다. cases.sh 의
# `r1`·`route_r1`·`mk_state` 는 **자기 mktemp 로 새 디렉토리를 만들어 돌려준다** — 이
# 락의 루프는 반대로 디렉토리를 먼저 만들어 **넘겨준다**(그래야 `gate --state-dir "$d"`
# 가 같은 디렉토리를 본다). 그래서 그 셋을 그대로 못 쓰고, `init`+`begin-round` 만 하는
# 얇은 변형(`gv_r1`)을 이 락 안에 따로 둔다 — cases.sh 를 오염시키지 않는다(브리프
# 원문의 이유와 같다). `seed_findings`·`next_round`·저수준 CLI(`decide`·`fix`·`ask`)는
# 이미 명시 `--state-dir` 를 받으므로 그대로 재사용한다.
gv_r1() {   # gv_r1 <state-dir> <profile> <doc>
  py docreview_state.py init --state-dir "$1" --doc "$3" --profile "$2" >/dev/null || return 1
  # 파일명은 반드시 s1.json — `next_round()`(cases.sh) 가 다음 라운드에서
  # `$d/s$((n-1)).json` 로 이 파일을 도로 찾는다(r1() 과 같은 이름 계약).
  local s="$1/s1.json"; snap "$3" "$s"
  py docreview_state.py begin-round --state-dir "$1" --snapshot "$s" >/dev/null || return 1
}

gv_reach_open_decide() {
  local d="$1"
  gv_r1 "$d" "$PROF_SD/design-doc.md" "$FX/design-sample.md" || return 1
  seed_findings "$d" "[$F_DEC]" || return 1
  echo 'aaaa0001#r1.1'
}

gv_reach_adopted() {
  local d="$1"
  gv_r1 "$d" "$PROF_SD/design-doc.md" "$FX/design-sample.md" || return 1
  seed_findings "$d" "[$F_DEC]" || return 1
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' >/dev/null || return 1
  echo 'aaaa0001#r1.1'
}

gv_reach_blocked_expired() {
  local d="$1"
  gv_r1 "$d" "$PROF_SD/design-doc.md" "$FX/design-sample.md" || return 1
  seed_findings "$d" "[$F_DEC]" || return 1
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' >/dev/null || return 1
  next_round "$d" "$FX/design-sample.md" >/dev/null || return 1   # 변경 없음 → expired (superseded_by 없음, finalize 안 지남)
  echo 'aaaa0001#r1.1'
}

# superseded_expired 는 production 경로로는 `docreview_route.py finalize` 의 재상승
# 루프에서만 나고, 그 루프는 항상 새 open decide(후속)를 같이 만든다 — 「그 행 하나만
# 살아 있는」 상태를 finalize 로는 못 짓는다(후속이 곧 open_decide 행도 함께 켠다).
# `st_set_stale_pointer.py`(cases.sh 의 case_AC20_stale_pointer_cleared_on_reobserve 가
# 쓰는 같은 픽스처)로 만료 레코드에 `superseded_by` 만 직접 심어 격리한다.
gv_reach_superseded_expired() {
  local d="$1"
  gv_r1 "$d" "$PROF_SD/design-doc.md" "$FX/design-sample.md" || return 1
  seed_findings "$d" "[$F_DEC]" || return 1
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice adopt --quote '채택' >/dev/null || return 1
  next_round "$d" "$FX/design-sample.md" >/dev/null || return 1   # 변경 없음 → expired
  python3 "$FX/st_set_stale_pointer.py" "$d/docreview-state.md" 'aaaa0001#r1.1' 'zzzz9999#r9.9' '#12-files-to-modify' || return 1
  echo 'aaaa0001#r1.1'
}

gv_reach_held_decide() {
  local d="$1"
  gv_r1 "$d" "$PROF_SD/design-doc.md" "$FX/design-sample.md" || return 1
  seed_findings "$d" "[$F_DEC]" || return 1
  py docreview_state.py decide --state-dir "$d" --id 'aaaa0001#r1.1' --choice hold --quote '나중에' >/dev/null || return 1
  echo 'aaaa0001#r1.1'
}

gv_reach_unapplied_fix() {
  local d="$1"
  gv_r1 "$d" "$PROF_SD/design-doc.md" "$FX/design-sample.md" || return 1
  seed_findings "$d" "[$F_FIX]" || return 1
  echo 'bbbb0001#r1.1'
}

# check-intent 를 거치지 않고 저수준 CLI 로 바로 escalate 한다 — Task 2 의 escalated
# 케이스들과 같은 수법(브리프 인터페이스 노트가 명시한 이유: check-intent 경유는 상태
# 가드를 갖지만 이 저수준 CLI 는 안 가져 격리하기 쉽다).
gv_reach_escalated_fix() {
  local d="$1"
  gv_r1 "$d" "$PROF_SD/design-doc.md" "$FX/design-sample.md" || return 1
  seed_findings "$d" "[$F_FIX]" || return 1
  py docreview_state.py fix --state-dir "$d" --id 'bbbb0001#r1.1' --event escalate --reason 'check-intent 거부' >/dev/null || return 1
  echo 'bbbb0001#r1.1'
}

# [Fix round 1 — I4 정정] 원래 이 둘은 **바이트 단위로 같은 state**(F_FIX+F_ASK)를
# 지어 「그 행 하나만 살아 있는 state」계약(위 「행별 도달 픽스처」 헤더)을 어겼다 —
# F_ASK 가 F_FIX 를 blocks 로 지목하므로 심는 순간 held_fix 행과 blocking_ask_open
# 행이 **항상 함께** 켜졌다. 리뷰 실측: `held_fix` 의 `blocks` 를 F→T 로 뒤집으면
# RED 가 `blocking_ask_open` 의 양성 짝 이름으로 뜨고(반대도 마찬가지) — 이빨은
# 있었지만 다음 독자를 엉뚱한 행으로 보냈다. 각자 격리한다.
gv_reach_held_fix() {
  local d="$1"
  gv_r1 "$d" "$PROF_SD/design-doc.md" "$FX/design-sample.md" || return 1
  seed_findings "$d" "[$F_FIX]" || return 1
  # 전제 ask 없이 저수준 CLI 로 바로 hold — blocking_ask_open 행을 안 켠다.
  py docreview_state.py fix --state-dir "$d" --id 'bbbb0001#r1.1' --event hold >/dev/null || return 1
  echo 'bbbb0001#r1.1'
}

# blocks 가 **아무 fix 도 안 심긴 id** 를 가리키는 ask — `record_findings` 의 hold
# 루프(`st["fixes"].get(b)` → None)가 아무것도 안 held 로 안 만들어 held_fix 행을
# 안 켠다. blocking_ask_open 의 술어(`not answered and bool(blocks)`)는 대상의
# 존재를 요구하지 않으므로 이것만으로 충분히 격리된다.
GV_F_ASK_BLOCKING_ONLY='{"id":"cccc0001#r1.1","lineage":"cccc0001#r1.1","bucket":"cccc0001","origin":"reviewer","layer":2,"category":"ambiguity","anchor":"#12-files-to-modify","edit_scope":"#12-files-to-modify","disposition":"ask","summary":"전제 fix 를 안 심어 격리한다","evidence":null,"blocks":["zzzz0001#r1.1"]}'
gv_reach_blocking_ask_open() {
  local d="$1"
  gv_r1 "$d" "$PROF_SD/design-doc.md" "$FX/design-sample.md" || return 1
  seed_findings "$d" "[$GV_F_ASK_BLOCKING_ONLY]" || return 1
  echo 'cccc0001#r1.1'
}

# ask_open 은 blocks 가 비고 from_decide 도 아닌 일반 ask 다 — F_ASK(cases.sh)는 blocks
# 가 있어(blocking_ask_open 전용) 못 쓰므로, 이 락 전용의 짧은 템플릿을 따로 둔다.
GV_F_ASK_PLAIN='{"id":"gggg0001#r1.1","lineage":"gggg0001#r1.1","bucket":"gggg0001","origin":"reviewer","layer":2,"category":"ambiguity","anchor":"#12-files-to-modify","edit_scope":"#12-files-to-modify","disposition":"ask","summary":"그냥 물어보기(비차단)","evidence":null,"blocks":[]}'
gv_reach_ask_open() {
  local d="$1"
  gv_r1 "$d" "$PROF_SD/design-doc.md" "$FX/design-sample.md" || return 1
  seed_findings "$d" "[$GV_F_ASK_PLAIN]" || return 1
  echo 'gggg0001#r1.1'
}

# ── 도출 ────────────────────────────────────────────────────────────────────
ROWS_JSON="$(py docreview_state.py gate-rows)"
RENDERED="$(printf '%s' "$ROWS_JSON" | jgets '" ".join(r["name"] for r in d if r["render"] is not None)')"
n_rendered="$(printf '%s\n' $RENDERED | grep -c . || true)"
# vacuity 하한 — 가시성 코퍼스가 8건에 못 미치면 아래 루프가 거의 아무것도 단언하지
# 않고 GREEN 이 될 수 있다(표가 통째로 비거나 렌더러가 대부분 지워진 상태).
[ "$n_rendered" -ge 8 ] \
  && ok "도출: 가시성 행 ${n_rendered}건 (하한 8)" \
  || no "도출: 가시성 행이 ${n_rendered}건이다 — 표 도출이 깨졌거나 렌더 대상 집합이 비었다. 아래 단언은 무의미하다"

BLOCKING="$(printf '%s' "$ROWS_JSON" | jgets '" ".join(r["name"] for r in d if r["blocks"])')"
n_block="$(printf '%s\n' $BLOCKING | grep -c . || true)"
[ "$n_block" -ge 4 ] \
  && ok "도출: 차단 행 ${n_block}건 (하한 4)" \
  || no "도출: 차단 행이 ${n_block}건이다 — 표 도출이 깨졌거나 차단 집합이 비었다. 아래 단언은 무의미하다"

# 행 ↔ 픽스처 집합 등식 — **가시성** 코퍼스로 잰다(Ruling 18). `blocks` 코퍼스로
# 재면 이 태스크가 고치려는 다섯 비차단 행(held_decide 등)이 등식 밖에 남아, 그
# 다섯의 렌더러를 전부 지워도 이 등식은 여전히 통과한다 — 이 락이 존재하는 이유
# 그 자체를 놓친다.
HAVE="$(declare -F | sed -n 's/^declare -f gv_reach_//p' | sort | tr '\n' ' ')"
assert_eq "$(printf '%s\n' $RENDERED | sort | tr '\n' ' ')" "$HAVE" \
  "등식: 표의 가시성 행 집합 = 이 락이 도달 픽스처를 가진 행 집합"

# ── 차단 ⊆ 가시성 (C1/Ruling 26) ────────────────────────────────────────────
# 위 등식은 **가시성** 코퍼스가 픽스처를 다 가졌는지만 잰다 — `blocks=True,
# render=None` 인 행은 애초에 가시성 코퍼스 밖이라 등식이 그 행을 아예 모른다. 태스크
# 제목 그 자체(「막는 집합」과 「그리는 집합」의 차이가 공집합)는 이 포함관계로만 재진다
# — spec §6.4 원문("그 차이가 항상 공집합임을 락으로 걸어야 한다")을 문자 그대로
# 지킨다. 브리프 원안(차단 코퍼스로 등식)은 이 방향을 부작용으로 얻었다(차단 행이면
# 전부 등식에도 들어야 했으므로) — 룰링 18 이 등식의 코퍼스를 가시성으로 **교체**하며
# 이 방향을 같이 버렸다. 두 방향은 배타적이지 않으므로 등식은 그대로 두고 이 방향을
# 명시적으로 더한다.
for row in $BLOCKING; do
  case " $RENDERED " in
    *" $row "*) ok "포함: 차단 행 $row 는 렌더 대상이다(가시성 코퍼스 안)" ;;
    *)          no "포함: 차단 행 $row 에 렌더러가 없다 — 막는데 안 그린다(fail-open, C1)" ;;
  esac
done

# ── 독립 증인 — 표 자체의 드리프트 (I5/I6, Ruling 29) ───────────────────────
# 위 도출·등식·포함관계는 전부 `gate-rows` 출력**에서** 기대값을 만든다 — 표의 한
# 열(`open`·`blocks`)이 잘못 적혀도 기대값과 실제 계산이 **같은 표**에서 함께 나오므로
# 절대 못 어긋난다. 실측(리뷰): `adopted` 의 `blocks` 를 True→False 로, `superseded_
# expired` 의 `blocks` 를 False→True 로 뒤집어도 이 파일을 포함한 스위트 전체가
# GREEN 이었다 — `open` 열은 양방향 다 마찬가지였다. `cases.sh` 의 어떤 행동
# 케이스도 「비어 있지 않은 adopted」로 approval_ready 를 재지 않는다(T21 은 adopted
# 가 빈 상태만 잰다). 그래서 다섯 열 전부(name·ledger·open·blocks·render)를
# **리터럴로 여기 박아 두고** `gate-rows` 출력과 정확히 같은지 잰다 — 도출과 무관한
# 고정 증인이라 표의 어느 열이 흔들리든(추가·삭제·반전·이름 변경) 이 단언만은 따라
# 움직이지 않는다. 행을 늘리는 사람은 이 리스트도 손으로 고쳐야 한다 — 그 마찰이
# Ruling 29 의 의도다. 순서·들여쓰기가 달라도 비교는 `json.dumps(json.loads(...))`
# 로 정규화한 뒤 문자열로 하므로 공백 차이에 안 흔들린다(단, 리스트 원소 **순서**는
# 여전히 비교된다 — `GATE_ROWS` 는 순서가 있는 tuple 이고 `gate-rows` 가 그대로 낸다).
EXPECTED_ROWS='[
  {"name": "open_decide", "ledger": "decides", "open": true, "blocks": true, "render": "decide"},
  {"name": "adopted", "ledger": "decides", "open": true, "blocks": true, "render": "adopted"},
  {"name": "blocked_expired", "ledger": "decides", "open": true, "blocks": true, "render": "expired"},
  {"name": "superseded_expired", "ledger": "decides", "open": true, "blocks": false, "render": "superseded"},
  {"name": "held_decide", "ledger": "decides", "open": false, "blocks": false, "render": "held_decide"},
  {"name": "unapplied_fix", "ledger": "fixes", "open": true, "blocks": true, "render": "unapplied_fix"},
  {"name": "escalated_fix", "ledger": "fixes", "open": true, "blocks": true, "render": "escalated_fix"},
  {"name": "held_fix", "ledger": "fixes", "open": true, "blocks": false, "render": "held_fix"},
  {"name": "blocking_ask_open", "ledger": "asks", "open": true, "blocks": false, "render": "blocking_ask"},
  {"name": "ask_open", "ledger": "asks", "open": false, "blocks": false, "render": "ask_open"}
]'
_canon() { python3 -c 'import json,sys; print(json.dumps(json.loads(sys.stdin.read())))'; }
assert_eq "$(printf '%s' "$ROWS_JSON" | _canon)" "$(printf '%s' "$EXPECTED_ROWS" | _canon)" \
  "증인: gate-rows 출력이 이 락에 박아 둔 리터럴 기대 표와 정확히 같다(표 드리프트 감시, Ruling 29)"

# ── 열림 축의 «행동» 락 (M3) ────────────────────────────────────────────────
# 바로 위 증인은 `open` 열이 **적힌 대로인가**만 잰다 — 구조 대 구조다. 그 열이
# 무엇을 **하는가**는 이 파일의 어느 단언도 재지 않았고, 그래서 어느 행의 `open` 을
# 어느 방향으로 뒤집어도 스위트 전체가 GREEN 이었다(리뷰 실측). 증인 하나만 남으면
# 이 열의 유일한 방어선이 «표를 손으로 고치는 사람이 실수하지 않는 것»이 되는데, 그
# 표의 헤더는 행이 바뀌면 손으로 고치라고 **명시적으로 지시한다** — 지시받은 손질이
# 곧 방어선의 해제가 된다.
#
# `open` 은 `is_open` → `_refresh_open_lineages` → 라운드 원장의 「열린 계보」로
# 흐르고, 그 집합이 설계 §8.4 stagnation 술어의 **입력**이다(집합이 직전 라운드와
# 같고 진행 0 이면 승인 게이트가 즉시 열린다). 조용한 반전은 정체 감지를 바꾼다.
#
# 두 단언을 건다. 서로 **못 보는 것이 다르다**:
#
#  (A) **차단 ⟹ 열림.** 기대값을 `blocks` 열에서 **도출**한다 — `open` 열도, 위
#      증인 표도 읽지 않는다. 근거는 §8.4 의 「기각된 계보는 열린 집합에서 빠진다」다:
#      집합에서 빠지는 것은 **닫힌** 것이고, 승인을 막고 있는 항목은 닫히지 않았다.
#      그래서 `open` 을 뒤집고 증인 표까지 손으로 맞춰 GREEN 으로 되돌려도 이 단언은
#      그대로 RED 다. 대신 비차단 행(다섯)은 이 단언의 사정거리 밖이다.
#  (B) **행동 기대표.** 렌더되는 **모든** 행의 기대 «행동»을 리터럴로 박아 (A) 의
#      사정거리 밖인 비차단 행의 반전을 양방향으로 잡는다. 증인 표와 축이 다르다 —
#      저것은 표의 글자를, 이것은 그 글자가 만든 **원장 값**을 잰다. 행이 늘면 아래
#      등식이 이 표의 미기재를 RED 로 낸다(열거가 아니라 등식이라 조용히 못 빠진다).
_open_probe() {   # _open_probe <state-dir> <fid> → open | closed
  # 재구현하지 않는다 — production 의 `_refresh_open_lineages` 를 그대로 불러 그
  # 결과 집합에 이 finding 의 계보가 있는지 본다(원장에는 쓰지 않는다).
  python3 -c 'import sys
sys.path.insert(0, sys.argv[3])
from docreview_state import load_state, _refresh_open_lineages
st = load_state(sys.argv[1])
n = int(st["round"])
_refresh_open_lineages(st, n)
lin = st["findings"][sys.argv[2]]["lineage"]
print("open" if lin in st["rounds"][str(n)]["open_lineages"] else "closed")' "$1" "$2" "$SCRIPTS"
}

EXPECTED_OPEN='open_decide=open adopted=open blocked_expired=open superseded_expired=open
held_decide=closed unapplied_fix=open escalated_fix=open held_fix=open
blocking_ask_open=open ask_open=closed'
expected_open_for() {   # $1=행 이름 → open | closed | "" (미등재)
  local e
  for e in $EXPECTED_OPEN; do
    case "$e" in "$1="*) printf '%s' "${e#*=}"; return ;; esac
  done
}
EO_KEYS="$(printf '%s\n' $EXPECTED_OPEN | sed 's/=.*//' | sort | tr '\n' ' ')"
assert_eq "$EO_KEYS" "$(printf '%s\n' $RENDERED | sort | tr '\n' ' ')" \
  "등식: 행동 기대표의 행 집합 = 표의 가시성 행 집합 (행을 늘리는 사람은 이 표도 채워야 한다)"
n_eo_closed="$(printf '%s\n' $EXPECTED_OPEN | grep -c '=closed$' || true)"
n_eo_open="$(printf '%s\n' $EXPECTED_OPEN | grep -c '=open$' || true)"
{ [ "$n_eo_closed" -ge 1 ] && [ "$n_eo_open" -ge 4 ]; } \
  && ok "도출: 행동 기대표에 열림 ${n_eo_open}건 · 닫힘 ${n_eo_closed}건 (양방향 하한 4·1)" \
  || no "도출: 행동 기대표가 한쪽으로 쏠렸다(열림 ${n_eo_open} · 닫힘 ${n_eo_closed}) — 한 방향은 공허하게 통과한다"

# ── 가시성 + 차단/양성 짝 ───────────────────────────────────────────────────
for row in $RENDERED; do
  d="$(mktemp -d -t gv-XXXXXX)"
  if [ -z "$d" ] || [ ! -d "$d" ]; then
    no "도달: $row — mktemp 실패로 임시 디렉토리를 못 만들었다(가드)"
    continue
  fi
  fid="$("gv_reach_$row" "$d")"
  if [ -z "$fid" ]; then
    no "도달: $row 픽스처가 실패했다(finding id 를 못 냈다)"
    rm -rf "$d"
    continue
  fi
  out="$(py docreview_state.py gate --state-dir "$d" --render)"
  case "$out" in
    *"$fid"*) ok "가시: 행 $row 의 항목 $fid 가 게이트 본문에 나온다" ;;
    *)        no "가시: 행 $row 의 항목 $fid 가 게이트 본문에 없다 — 표는 렌더 대상이라는데 실제로 안 보인다(fail-open)" ;;
  esac
  ar="$(py docreview_state.py gate --state-dir "$d" | jgets 'd["approval_ready"]')"
  case " $BLOCKING " in
    *" $row "*)
      # 차단 코퍼스 — 짝이 되는 양의 단언(이 상태가 실제로 막고 있는가)이 없으면
      # 「막는데 안 보인다」류 위 가시성 단언이 이 상태가 애초에 막지 않을 때도
      # 공허하게 무의미해질 수 있다.
      assert_eq "$ar" "False" "차단: 행 $row 하나만 살아 있으면 approval_ready 는 False" ;;
    *)
      # 양성 짝(Ruling 19) — 표가 `blocks: false` 라고 적은 행은 실제로도 안 막아야
      # 한다. 이게 없으면 실제로는 막는 행이 표에 거짓으로 `blocks: false` 라고
      # 적혀도 이 락은 못 잡는다(부재 단언에는 짝이 없으면 이빨이 없다).
      assert_eq "$ar" "True" "양성 짝: 행 $row(비차단) 하나만 살아 있으면 approval_ready 는 True" ;;
  esac
  # ── 열림 축 (M3) — 위 헤더의 (A)·(B) ──────────────────────────────────────
  op="$(_open_probe "$d" "$fid")"
  case " $BLOCKING " in
    *" $row "*)
      assert_eq "$op" "open" \
        "차단⟹열림: 행 $row 하나만 살아 있으면 그 계보가 열린 계보 집합에 있다 (기대는 blocks 열에서 도출 — open 열도 증인 표도 안 읽는다)" ;;
  esac
  exp_op="$(expected_open_for "$row")"
  if [ -z "$exp_op" ]; then
    no "행동: 행 $row 이 행동 기대표에 없다 — 위 등식이 이미 소리를 냈어야 한다(계측기 붕괴)"
  else
    assert_eq "$op" "$exp_op" \
      "행동: 행 $row 하나만 살아 있을 때 그 계보는 $exp_op (§8.4 stagnation 의 입력이 되는 원장 값)"
  fi
  rm -rf "$d"
done
finish
