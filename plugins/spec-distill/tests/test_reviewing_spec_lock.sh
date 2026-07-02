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

# AC14 teeth (genuine — NOT a `grep -v X | grep -q X` tautology, which passes for any
# file). Two independent proofs the AC2 lock has real teeth:
# (1) body-uniqueness: the pause command string appears exactly once, so it can't be
#     silently satisfied by a stray header/duplicate line. Remove the command line and
#     the count drops to 0 → AC2's grep -q reds. A count != 1 is itself a finding.
cnt=$(grep -c 'review_lock.py" pause' "$SKILL")
[[ "$cnt" -eq 1 ]] \
  && note PASS "AC14a: pause command body-unique (exactly 1 occurrence)" \
  || note FAIL "AC14a: expected exactly 1 pause-command occurrence, got $cnt"

# (2) discrimination control: the assertion pattern MATCHES a fixture that has the command
#     and does NOT match one where it was removed — proving the grep has real
#     discriminating power (a vacuous lock would behave identically on both fixtures).
POS=$(mktemp); NEG=$(mktemp)
printf '%s\n' 'noise before' \
  'python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/review_lock.py" pause "$session_id" "$spec_path"' \
  'noise after' > "$POS"
printf '%s\n' 'noise before' '# pause command removed' 'noise after' > "$NEG"
if grep -q 'review_lock.py" pause' "$POS" && ! grep -q 'review_lock.py" pause' "$NEG"; then
  note PASS "AC14b: assertion grep discriminates present vs absent (real teeth)"
else
  note FAIL "AC14b: assertion grep failed to discriminate present/absent fixtures"
fi
rm -f "$POS" "$NEG"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
