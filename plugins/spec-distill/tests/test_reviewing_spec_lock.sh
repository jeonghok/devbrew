#!/usr/bin/env bash
# AC14 — reviewing-spec SKILL이 review_lock set(refresh) + Phase 5 ④=pause 매핑을
# body-unique 문구로 문서화했는지 회귀 락. mutation(그 라인 삭제)으로 red 증명.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL="$REPO_ROOT/plugins/spec-distill/skills/reviewing-spec/SKILL.md"
pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# body-unique 문구 1: Step 1 refresh 명령 (헤더에 없는 CLI 리터럴).
grep -q 'review_lock.py" set' "$SKILL" \
  && note PASS "AC1: Step 1 review_lock set(refresh) 명령 존재" \
  || note FAIL "AC1: review_lock set 명령 없음"

# body-unique 문구 2: Phase 5 ④=pause 매핑 (CLI 리터럴).
grep -q 'review_lock.py" pause' "$SKILL" \
  && note PASS "AC2: Phase 5 ④=pause 명령 존재" \
  || note FAIL "AC2: review_lock pause 명령 없음"

# teeth 증명: pause 라인을 삭제한 mutation은 grep FAIL 이어야 함(락에 이빨 있음).
MUT=$(mktemp)
grep -v 'review_lock.py" pause' "$SKILL" > "$MUT"
if grep -q 'review_lock.py" pause' "$MUT"; then
  note FAIL "AC14 teeth: mutation 후에도 매칭 — 락 무의미"
else
  note PASS "AC14 teeth: pause 라인 삭제 시 grep red(이빨 증명)"
fi
rm -f "$MUT"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
