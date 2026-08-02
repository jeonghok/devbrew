#!/usr/bin/env bash
# T6–T12 — 기록 시점·자기치유·G6 상한·훅 통합·check-born·fail-safe 배제 (v0.25.0).
set -u -o pipefail
source "$(dirname "$0")/arm_test_helpers.sh"
arm_work_init specdistill-armtiming

# --- T6: 진입 시 strip-pending 이 §5.4 5단계(지연 재소비)를 불가능하게 만든다 ---
# rewrite_state 실패를 주입할 필요가 없다 — pending이 남아 있는 상태를 픽스처로 만들고
# strip 전후의 Stop 동작 차이를 잰다.
SID6=t6-strip
REL6="docs/superpowers/specs/2026-08-01-t6-design.md"
new_doc "$REL6"
run_validator "$REL6" "$SID6" >/dev/null
sf6="$(state_of "$SID6")"
grep -q '^pending_review:' "$sf6" || note FAIL "T6 준비 실패: pending 미생성"
run_ledger strip-pending "$SID6" "$WORK/$REL6" >/dev/null 2>&1
emit6=$(run_stop "$SID6")
if [[ -z "$emit6" ]] && ! grep -q '^pending_review:' "$sf6"; then
  note PASS "T6: 진입 strip 이후 Stop 재발화 → 무-emit (지연 재소비 봉쇄)"
else
  note FAIL "T6 실패: emit='$emit6' state=$(cat "$sf6")"
fi

# --- T7: verdict 시 원장 기록 → 키 존재 + 이어지는 편집이 재arm 하지 않는다 ---
SID7=t7-verdict
REL7="docs/superpowers/specs/2026-08-01-t7-design.md"
new_doc "$REL7"
run_validator "$REL7" "$SID7" >/dev/null
run_stop "$SID7" >/dev/null
run_ledger mark-reviewed "$SID7" "$WORK/$REL7" >/dev/null 2>&1
sf7="$(state_of "$SID7")"
edit_doc "$REL7" 2
run_validator "$REL7" "$SID7" >/dev/null
emit7=$(run_stop "$SID7")
if grep -q "^  - $REL7\$" "$sf7" \
  && ! grep -q '^pending_review:' "$sf7" \
  && [[ -z "$emit7" ]]; then
  note PASS "T7: mark-reviewed → armed_paths 기록 + 이후 편집 재arm 없음"
else
  note FAIL "T7 실패: emit='$emit7' state=$(cat "$sf7")"
fi

# --- T8: verdict 없이 중단된 리뷰는 다음 편집에서 자기치유한다 (T7의 반례) ---
# 리뷰가 끝나지 않으면 재시도되는 것이 의도된 동작이다 — 재시도가 없으면 그 문서는
# 유일한 자동 리뷰 기회를 조용히 잃는다.
SID8=t8-selfheal
REL8="docs/superpowers/specs/2026-08-01-t8-design.md"
new_doc "$REL8"
run_validator "$REL8" "$SID8" >/dev/null
emit8a=$(run_stop "$SID8")
# 리뷰가 **시작은 했다** — skill Step 1 의 진입 strip 이 돌았다는 뜻이다. 이 한 줄이 없으면
# T8 은 "verdict 없는 dispatch 2회"를 잴 뿐 선언한 시나리오("중단된 리뷰의 자기치유")를
# 재지 못하고, Step 6 의 T8 mutation(기록을 진입 시점으로 되돌리기)이 픽스처에 **닿지
# 않아** GREEN 이 난다 — 도달 불가능한 mutation 은 이빨의 증거가 아니다.
run_ledger strip-pending "$SID8" "$WORK/$REL8" >/dev/null 2>&1
# 그리고 verdict 없이 죽었다 — mark-reviewed 를 부르지 않는다.
edit_doc "$REL8" 2
run_validator "$REL8" "$SID8" >/dev/null
emit8b=$(run_stop "$SID8")
sf8="$(state_of "$SID8")"
if echo "$emit8a" | jq -e '.decision == "block"' >/dev/null 2>&1 \
  && echo "$emit8b" | jq -e '.decision == "block"' >/dev/null 2>&1 \
  && ! grep -q '^armed_paths:' "$sf8"; then
  note PASS "T8: verdict 없는 중단 → 다음 편집이 재arm + 재dispatch (자기치유)"
else
  note FAIL "T8 실패: emit1='$emit8a' emit2='$emit8b' state=$(cat "$sf8")"
fi

# --- T9: G6 상한 (§5.2 상태기계) ---
# 3회차가 마지막 자동 dispatch이고 그 emit이 상한을 알리는 vehicle이다.
# "4회차가 억제된다"가 아니다 — 이후 편집은 validator 층에서 pending 자체가 안 생긴다.
SID9=t9-capped
REL9="docs/superpowers/specs/2026-08-01-t9-design.md"
new_doc "$REL9"
e1=""; e2=""; e3=""
for i in 1 2 3; do
  edit_doc "$REL9" "$i"
  run_validator "$REL9" "$SID9" >/dev/null
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
# 상한 도달 이후의 편집: pending 자체가 생기지 않고 Stop이 볼 것이 없다.
edit_doc "$REL9" 4
out9=$(run_validator "$REL9" "$SID9")
grep -q '^pending_review:' "$sf9" && cap_ok=0
echo "$out9" | jq -e '.systemMessage | contains("capped")' >/dev/null 2>&1 || cap_ok=0
[[ -z "$(run_stop "$SID9")" ]] || cap_ok=0
if [[ $cap_ok -eq 1 ]]; then
  note PASS "T9: 3회차 emit에 상한 advisory + armed 기록, 이후 편집은 pending 미생성"
else
  note FAIL "T9 실패: e1='$e1' e3='$e3' out4='$out9' state=$(cat "$sf9")"
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
win="$(awk '/리뷰 완료 기록/{f=1} /^## /{f=0} f' "$SKILL")"
if [[ -n "$win" ]] \
  && grep -q 'mark-reviewed' <<<"$win" \
  && grep -q 'claude_verdict_unrecoverable' <<<"$win" \
  && grep -q 'codex_degraded' <<<"$win"; then
  note PASS "T12b: SKILL Step 3의 mark-reviewed 지시가 both-dead 배제 조건과 같은 블록"
else
  note FAIL "T12b 실패: window=$(wc -l <<<"$win")줄"
fi

arm_summary
