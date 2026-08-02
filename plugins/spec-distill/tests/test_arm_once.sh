#!/usr/bin/env bash
# T1·T2·T3 — arm-once 게이트 (v0.25.0 §5.1).
#
# 재는 것은 **pending 파일 쓰기 횟수가 아니라 dispatch emit 횟수**다(§10 T1). 두 번째
# 편집이 pending을 덮어쓰는 것은 §5.2가 명시한 의도된 동작이므로 "기록 1회"를 assert하면
# 설계와 모순되는 것을 재게 된다.
set -u -o pipefail
source "$(dirname "$0")/arm_test_helpers.sh"
arm_work_init specdistill-armonce

# --- T1: 리뷰가 완료된 뒤의 편집은 재arm 하지 않는다 (dispatch emit 1회) ---
# mark-reviewed가 시퀀스에 반드시 포함된다 — 그것이 T1(verdict 이후 재arm 없음)과
# T8(verdict 이전 재시도 있음)을 가르는 유일한 사건이다. 빼면 두 락이 같은 상태에
# 반대 결과를 요구해 하나는 반드시 실패한다.
SID1=t1-armonce
REL1="docs/superpowers/specs/2026-08-01-t1-design.md"
new_doc "$REL1"
run_validator "$REL1" "$SID1" >/dev/null
emit1=$(run_stop "$SID1")
run_ledger mark-reviewed "$SID1" "$WORK/$REL1" >/dev/null 2>&1
edit_doc "$REL1" 2
run_validator "$REL1" "$SID1" >/dev/null
emit2=$(run_stop "$SID1")
if echo "$emit1" | jq -e '.decision == "block"' >/dev/null 2>&1 && [[ -z "$emit2" ]]; then
  note PASS "T1: verdict 이후 편집은 재arm 없음 (dispatch emit 1회)"
else
  note FAIL "T1 실패: emit1='$emit1' emit2='$emit2' state=$(cat "$(state_of "$SID1")")"
fi

# --- T2: git이 아는 문서는 armed_paths가 비어 있어도 arm 하지 않는다 ---
SID2=t2-borned
REL2="docs/superpowers/specs/2026-08-01-t2-design.md"
new_doc "$REL2"
( cd "$WORK" && git add "$REL2" && git commit -q -m born ) || exit 1
out2=$(run_validator "$REL2" "$SID2")
sf2="$(state_of "$SID2")"
armed_empty=1
[[ -f "$sf2" ]] && grep -q '^armed_paths:' "$sf2" && armed_empty=0
if [[ $armed_empty -eq 1 ]] \
  && { [[ ! -f "$sf2" ]] || ! grep -q '^pending_review:' "$sf2"; } \
  && echo "$out2" | jq -e '.hookSpecificOutput.additionalContext | contains("git이 아는 문서")' >/dev/null 2>&1; then
  note PASS "T2: git-tracked 문서 → 원장이 비어도 arm 없음 + git 사유 advisory"
else
  note FAIL "T2 실패: out='$out2' state=$( [[ -f "$sf2" ]] && cat "$sf2" || echo '(없음)')"
fi

# --- T3: git 판정 실패는 arm 쪽으로 fail-open **하고** loud 하다 (양방향 락) ---
# 한 방향(arm 발생)만 잠그면 advisory 없이 조용히 arm해도 통과한다.
SID3=t3-nogit
REL3="docs/superpowers/specs/2026-08-01-t3-design.md"
new_doc "$REL3"
mkdir -p "$WORK/fakebin"
printf '#!/bin/sh\nexit 42\n' > "$WORK/fakebin/git"
chmod +x "$WORK/fakebin/git"
all3=$(run_validator_all "$REL3" "$SID3" "PATH=$WORK/fakebin:$PATH")
sf3="$(state_of "$SID3")"
if [[ -f "$sf3" ]] && grep -q '^pending_review:' "$sf3" \
  && grep -q 'exit=42' <<<"$all3"; then
  note PASS "T3: git 불능 → arm 발생(fail-open) + exit code 포함 loud advisory"
else
  note FAIL "T3 실패: out='$all3' state=$( [[ -f "$sf3" ]] && cat "$sf3" || echo '(없음)')"
fi

arm_summary
