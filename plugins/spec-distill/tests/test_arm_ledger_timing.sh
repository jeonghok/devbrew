#!/usr/bin/env bash
# T6–T12 — 기록 시점·자기치유·G6 상한·훅 통합·check-born·fail-safe 배제 (v0.25.0).
set -u -o pipefail
source "$(dirname "$0")/arm_test_helpers.sh"
arm_work_init specdistill-armtiming

# --- T6: 리뷰가 진행 중인 문서는 다음 Stop 이 다시 강제하지 않는다 (지연 재소비 봉쇄) ---
# 성질은 §5.4 5단계 그대로다: 이미 착수된 리뷰를 나중의 Stop 이 뒤늦게 또 강제하면
# 그 라운드가 중복·절단된다. 그 상태를 표현하던 것이 예전엔 진입 strip 이었고 지금은
# dispatch 가 찍는 in-flight 표시다(A12).
#
# **양방향으로 잠근다.** "두 번째 Stop 이 조용하다"만 재면 훅이 그 뒤로 영영 침묵하는
# 구현도 통과한다. in-flight 를 걷어낸 뒤 다시 강제되는 것까지 재야 침묵의 원인이
# 그 표시임이 고정된다.
SID6=t6-inflight
REL6="docs/superpowers/specs/2026-08-01-t6-design.md"
new_doc "$REL6"
emit6a=$(run_stop "$SID6")
sf6="$(state_of "$SID6")"
# **첫 dispatch 직후에** 잰다. 마지막에 재면 emit6c 가 다시 찍은 표시를 보게 되어
# "첫 dispatch 가 표시를 남긴다"는 사실을 재지 못한다.
marked6=0; grep -qE "^  $REL6: 20[0-9][0-9]-" "$sf6" && marked6=1
emit6b=$(run_stop "$SID6")
run_ledger clear-inflight "$SID6" "$WORK/$REL6" >/dev/null 2>&1
emit6c=$(run_stop "$SID6")
if echo "$emit6a" | jq -e '.decision == "block"' >/dev/null 2>&1 \
  && [[ $marked6 -eq 1 ]] \
  && [[ -z "$emit6b" ]] \
  && echo "$emit6c" | jq -e '.decision == "block"' >/dev/null 2>&1; then
  note PASS "T6: 리뷰 진행 중 재-Stop → 무-emit, in-flight 해제 후엔 다시 강제"
else
  note FAIL "T6 실패: a='$emit6a' marked=$marked6 b='$emit6b' c='$emit6c' state=$(cat "$sf6")"
fi

# --- T7: verdict 가 기록된 문서는 이후 편집돼도 다시 강제되지 않는다 ---
# `mark-reviewed` 는 armed_paths 에 쓰면서 in-flight 표시를 **지운다**. 그래서 이
# 케이스의 침묵은 T6 의 in-flight 로 설명되지 않는다 — 원인이 armed_paths 하나로
# 좁혀진다. 그 배제를 실제로 재기 위해 in-flight 부재를 함께 단언한다.
SID7=t7-verdict
REL7="docs/superpowers/specs/2026-08-01-t7-design.md"
new_doc "$REL7"
run_stop "$SID7" >/dev/null
run_ledger mark-reviewed "$SID7" "$WORK/$REL7" >/dev/null 2>&1
sf7="$(state_of "$SID7")"
edit_doc "$REL7" 2
emit7=$(run_stop "$SID7")
if grep -q "^  - $REL7\$" "$sf7" \
  && ! grep -qE "^  $REL7: 20[0-9][0-9]-" "$sf7" \
  && [[ -z "$emit7" ]]; then
  note PASS "T7: mark-reviewed → armed_paths 기록 + 이후 편집 재dispatch 없음"
else
  note FAIL "T7 실패: emit='$emit7' state=$(cat "$sf7")"
fi

# --- T8: verdict 없이 중단된 리뷰는 자기치유한다 (T7의 반례) ---
# 리뷰가 끝나지 않으면 재시도되는 것이 의도된 동작이다 — 재시도가 없으면 그 문서는
# 유일한 자동 리뷰 기회를 조용히 잃는다(under-review, Law 1 이 금지하는 방향).
#
# **치유의 계기가 바뀌었다.** 예전에는 "다음 편집"이었다 — 편집이 pending 을 다시
# 깔았기 때문이다. 지금 그 자리를 지키는 것은 in-flight 표시의 TTL 이다: 리뷰가
# crash 로 죽으면 표시가 남아 게이트를 닫는데, 만료가 그것을 되열고 그 위의 상한은
# `DISPATCH_ATTEMPT_CAP` 이 준다(`INFLIGHT_TTL_SEC` 의 계약). 그래서 이 케이스는
# 편집이 아니라 만료로 치유를 잰다. 성질은 같다: **중단된 리뷰가 그 문서의 자동
# 리뷰를 영구히 끄지 않는다.**
SID8=t8-selfheal
REL8="docs/superpowers/specs/2026-08-01-t8-design.md"
new_doc "$REL8"
emit8a=$(run_stop "$SID8")
# 그리고 verdict 없이 죽었다 — mark-reviewed 를 부르지 않는다. 표시만 남는다.
sf8="$(state_of "$SID8")"
inflight_left=0; grep -qE "^  $REL8: 20[0-9][0-9]-" "$sf8" && inflight_left=1
expire_inflight "$SID8"
edit_doc "$REL8" 2
emit8b=$(run_stop "$SID8")
if echo "$emit8a" | jq -e '.decision == "block"' >/dev/null 2>&1 \
  && [[ $inflight_left -eq 1 ]] \
  && echo "$emit8b" | jq -e '.decision == "block"' >/dev/null 2>&1 \
  && ! grep -q '^armed_paths:' "$sf8"; then
  note PASS "T8: verdict 없는 중단 → in-flight 만료 후 재dispatch (자기치유)"
else
  note FAIL "T8 실패: emit1='$emit8a' inflight=$inflight_left emit2='$emit8b' state=$(cat "$sf8")"
fi

# --- T9: G6 상한 (§5.2 상태기계) ---
# 3회차가 마지막 자동 dispatch이고 그 emit이 상한을 알리는 vehicle이다.
# 마지막 절의 성질: **상한에 닿은 문서는 다시 편집돼도 dispatch 되지 않는다.**
# 예전에는 validator 층이 pending 을 안 만드는 것으로 그 성질이 성립했고, 지금은
# dispatch 대상 선택이 `dispatch_attempts` 상한과 `armed_paths` 를 함께 보고 뺀다.
#
# 매 라운드 in-flight 를 만료시킨다 — 안 그러면 2·3회차가 A12 의 표시에 막혀
# G6 상한 자체에 닿지 못한다. 재는 축은 상한이지 in-flight 가 아니다(그쪽은 T6·T8).
SID9=t9-capped
REL9="docs/superpowers/specs/2026-08-01-t9-design.md"
new_doc "$REL9"
e1=""; e2=""; e3=""
for i in 1 2 3; do
  edit_doc "$REL9" "$i"
  expire_inflight "$SID9"
  case $i in
    1) e1=$(run_stop "$SID9") ;;
    2) e2=$(run_stop "$SID9") ;;
    3) e3=$(run_stop "$SID9") ;;
  esac
done
sf9="$(state_of "$SID9")"
cap_ok=1
echo "$e1" | jq -e '.decision == "block"' >/dev/null 2>&1 || cap_ok=0
echo "$e2" | jq -e '.decision == "block"' >/dev/null 2>&1 || cap_ok=0
echo "$e1" | jq -e '.reason | contains("3회 시도")' >/dev/null 2>&1 && cap_ok=0
echo "$e3" | jq -e '.decision == "block"' >/dev/null 2>&1 || cap_ok=0
echo "$e3" | jq -e '.reason | contains("3회 시도")' >/dev/null 2>&1 || cap_ok=0
grep -q "^  - $REL9\$" "$sf9" || cap_ok=0
grep -q "^  $REL9: 3\$" "$sf9" || cap_ok=0
# 상한 도달 이후의 편집: 문서는 여전히 dirty 라 발견되지만 선택에서 빠진다.
# in-flight 도 만료시켜, 침묵을 설명할 수 있는 것이 상한뿐이게 만든다.
edit_doc "$REL9" 4
expire_inflight "$SID9"
[[ -z "$(run_stop "$SID9")" ]] || cap_ok=0
if [[ $cap_ok -eq 1 ]]; then
  note PASS "T9: 3회차 emit에 상한 advisory + armed 기록, 상한 이후 편집은 무-dispatch"
else
  note FAIL "T9 실패: e1='$e1' e3='$e3' state=$(cat "$sf9")"
fi

# --- T10: Stop의 dispatch 단독으로는 원장을 쓰지 않는다 (훅 통합 지점) ---
# T7·T8은 arm_ledger CLI 의미만 재므로 mark_armed를 Stop과 skill 양쪽에서 부르는
# 잘못된 구현도 둘 다 통과한다. T10만이 그 구현을 RED로 만든다 — 산문이 아니라
# 실행으로 소유권을 고정한다.
SID10=t10-noarm
REL10="docs/superpowers/specs/2026-08-01-t10-design.md"
new_doc "$REL10"
run_validator "$REL10" "$SID10" >/dev/null
run_stop "$SID10" >/dev/null
sf10="$(state_of "$SID10")"
if ! grep -q '^armed_paths:' "$sf10" && grep -q "^  $REL10: 1\$" "$sf10"; then
  note PASS "T10: dispatch 단독(상한 미달) → armed_paths 비어 있음, attempts=1"
else
  note FAIL "T10 실패: state=$(cat "$sf10")"
fi

# --- T11: check-born 은 dangling in-scope 경로에서 crash 하지 않는다 ---
# 삭제되는 test_handoff_spec_path_validation.sh 가 잠그던 불변식의 승계처(§9).
DANGLE="docs/superpowers/specs/2026-08-01-does-not-exist-design.md"
out11=$(run_ledger_rc check-born "$WORK/$DANGLE"); rc11=$?
if [[ $rc11 -eq 1 ]] && grep -q '아직 git에 없다' <<<"$out11" \
  && ! grep -q 'Traceback' <<<"$out11"; then
  note PASS "T11: check-born dangling in-scope → rc=1 + 미커밋 advisory, 무-crash"
else
  note FAIL "T11 실패: rc=$rc11 out='$out11'"
fi

# --- T12: both-dead fail-safe 라운드는 원장에 기록하지 않는다 ---
# 두 층으로 잠근다. (a) skill이 keying하는 신호가 merge_review 출력에 실제로 존재하고,
# (b) SKILL.md의 mark-reviewed 지시가 그 배제 조건과 **같은 섹션 윈도우 안에** 있다.
# (a)만으로는 지시가 사라져도 통과하고, (b)만으로는 신호가 사라져 지시가 따를 수 없게
# 돼도 통과한다.
printf 'no status line here\n' > "$WORK/claude.txt"
printf '{"issue_history": []}\n' > "$WORK/hist.json"
mout=$(python3 "$MERGE" --claude-output "$WORK/claude.txt" \
         --codex-yaml /nonexistent --history "$WORK/hist.json" 2>/dev/null)
if grep -q '^claude_verdict_unrecoverable: true$' <<<"$mout" \
  && grep -q '^codex_degraded: true$' <<<"$mout" \
  && grep -q '^combined_verdict: needs_revise$' <<<"$mout"; then
  note PASS "T12a: both-dead가 combined_verdict를 내면서 두 degrade flag를 함께 emit"
else
  note FAIL "T12a 실패: merge_review out='$mout'"
fi

# 섹션 윈도우 — 헤더-satisfiable 회피를 위해 blockquote/헤더가 아닌 **본문 고유** 토큰을
# 윈도우 안에서 찾는다. 빈 윈도우는 앵커가 깨진 것이므로 FAIL(조용한 통과 금지).
#
# 맨 토큰 'mark-reviewed' 로는 부족하다 — 같은 윈도우 안 advisory 산문("…리뷰 완료
# 기록(mark-reviewed)을 남기지 못했다…")이 그 grep 을 혼자 만족시킨다. 그러면 정작
# load-bearing 한 명령 줄을 지워도, 다른 섹션으로 옮겨도 GREEN 이라 이 층이 주장하는
# **공존(co-location)** 을 전혀 재지 못한다. 명령형(`arm_ledger.py" mark-reviewed`)은
# 그 줄에만 있으므로 body-unique 하다.
# 네 번째 conjunct — **규칙 문장 자체**를 고정한다. 앞의 세 개는 두 *토큰* 의 공존만
# 재므로, 근거 산문을 남긴 채 명령형 리드인("예외 — …호출하지 않는다")만 지우면 GREEN
# 이었다(실측 확인). 그리고 규칙을 무르게 하는 현실적 변경은 정확히 그 모양이다 —
# 설명은 남기고 명령만 지운다. 이 문장이 없으면 아무도 리뷰하지 않은 both-dead 라운드가
# "리뷰됨"으로 원장에 박혀 그 문서는 영영 다시 arm 되지 않는다.
win="$(awk '/리뷰 완료 기록/{f=1} /^## /{f=0} f' "$SKILL")"
if [[ -n "$win" ]] \
  && grep -qF 'arm_ledger.py" mark-reviewed' <<<"$win" \
  && grep -q 'claude_verdict_unrecoverable' <<<"$win" \
  && grep -q 'codex_degraded' <<<"$win" \
  && grep -qF '호출하지 않는다' <<<"$win"; then
  note PASS "T12b: SKILL Step 3의 mark-reviewed 지시가 both-dead 배제 조건·금지 명령과 같은 블록"
else
  note FAIL "T12b 실패: window=$(wc -l <<<"$win")줄"
fi

arm_summary
