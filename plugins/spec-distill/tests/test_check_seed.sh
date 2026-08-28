#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/check_seed.py
#
# 검사 넷이 **각자** 자기 픽스처를 잡는가. 픽스처를 검사당 하나로 나눈 이유: 한 픽스처에
# 위반 넷을 다 넣으면 검사 하나만 살아 있어도 rc≠0 이라 나머지 셋이 죽은 것을 못 잡는다
# («여럿이 함께 실패»는 변이 선택의 결함이다).
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
CHECK="$ROOT/plugins/spec-distill/scripts/check_seed.py"
FIX="$ROOT/plugins/spec-distill/tests/fixtures"

if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/scripts/check_seed.py"
  exit 0
fi

[ -f "$CHECK" ] || { no "check_seed.py 부재"; finish; exit $?; }

run_gate() {   # run_gate <seed> <audit> → rc
  PYTHONDONTWRITEBYTECODE=1 python3 "$CHECK" gate "$1" "$2" >/dev/null 2>&1
}

GOOD_AUDIT="$FIX/seed-one-sentence.audit.md"

# ── 각 위반 픽스처가 rc≠0 인가 (검사가 살아 있는가)
for pair in \
  "seed-has-answer-heading.md|답-슬롯 헤딩" \
  "seed-has-tag.md|태그" \
  "seed-has-url.md|URL"; do
  fx="${pair%%|*}"; label="${pair#*|}"
  run_gate "$FIX/$fx" "$GOOD_AUDIT"
  [ $? -ne 0 ] \
    && ok "검사 살아 있음: ${label} (${fx})" \
    || no "검사 죽음: ${label} 픽스처(${fx})가 통과한다"
done

# 원문 보존 — audit 쪽 «존재» 검사. 빈 원문 절은 막혀야 한다.
run_gate "$FIX/seed-one-sentence.md" "$FIX/seed-empty-verbatim.audit.md"
[ $? -ne 0 ] \
  && ok "검사 살아 있음: 원문 보존 (빈 §1 원문 절)" \
  || no "검사 죽음: audit 의 §1 원문이 비어도 통과한다"

# audit 경로 자체가 없으면 «확인 불가»이지 «통과»가 아니다.
PYTHONDONTWRITEBYTECODE=1 python3 "$CHECK" gate "$FIX/seed-one-sentence.md" >/dev/null 2>&1
[ $? -ne 0 ] \
  && ok "audit 경로 부재를 통과로 읽지 않는다 (indeterminate ≠ clean)" \
  || no "audit 경로 없이도 통과한다 — 원문 보존이 조용히 vacuous 해진다"

# ── 양성 대조: 위반 0 인 픽스처는 통과해야 한다. 없으면 위 넷은 «전부 막는 게이트»와
#    구별되지 않는다.
run_gate "$FIX/seed-one-sentence.md" "$GOOD_AUDIT"
[ $? -eq 0 ] \
  && ok "양성 대조: 깨끗한 seed 는 통과한다" \
  || no "양성 대조: 깨끗한 seed 가 막힌다 — 위 RED 들은 증거가 아니다"

finish
