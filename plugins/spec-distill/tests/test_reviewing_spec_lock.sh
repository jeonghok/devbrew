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

# ── v0.19.0 harness-sid bridge 회귀 락 ────────────────────────────────────
# 윈도우 추출: ASCII-stable 구조 앵커로 각 호출 지점의 섹션만 잘라 grep(섹션 배치 증명).
step1_window()  { sed -n '/^## Steps$/,/^## Deterministic Routing Table/p' "$SKILL"; }
pause_window()  { sed -n '/^## Phase 5 Human Gate/,/^## Approve handoff sequence/p' "$SKILL"; }
appr_window()   { sed -n '/^## Approve handoff sequence/,/^## In-flight state migration/p' "$SKILL"; }

# AC8-a: Step 1 락 set 이 $harness_sid (NOT $session_id) — 자기 윈도우 안에서.
step1_window | grep -qF 'review_lock.py" set "$harness_sid' \
  && ! { step1_window | grep -qF 'review_lock.py" set "$session_id'; } \
  && note PASS "AC8-a: Step1 set uses \$harness_sid, not \$session_id" \
  || note FAIL "AC8-a: Step1 set not keyed to \$harness_sid"

# AC8-b: Phase 5 ④ pause 가 $harness_sid — pause 윈도우 안에서.
pause_window | grep -qF 'review_lock.py" pause "$harness_sid' \
  && ! { pause_window | grep -qF 'review_lock.py" pause "$session_id'; } \
  && note PASS "AC8-b: ④ pause uses \$harness_sid" \
  || note FAIL "AC8-b: ④ pause not keyed to \$harness_sid"

# AC8-c: Approve handoff 가 $harness_sid — approve 윈도우 안에서.
appr_window | grep -qF 'approve_handoff.sh" "$harness_sid' \
  && ! { appr_window | grep -qF 'approve_handoff.sh" "$session_id'; } \
  && note PASS "AC8-c: approve_handoff uses \$harness_sid" \
  || note FAIL "AC8-c: approve_handoff not keyed to \$harness_sid"

# AC8 teeth (POS/NEG discrimination — 명령-삭제/헤더-only mutation → red 증명).
POS=$(mktemp); NEG=$(mktemp)
printf '%s\n' 'noise' 'review_lock.py" set "$harness_sid" "$spec_path"' 'noise' > "$POS"
printf '%s\n' 'noise' '## Steps (header only, command removed)' 'noise' > "$NEG"
if grep -qF 'review_lock.py" set "$harness_sid' "$POS" \
   && ! grep -qF 'review_lock.py" set "$harness_sid' "$NEG"; then
  note PASS "AC8-teeth: harness_sid grep discriminates command-present vs header-only"
else
  note FAIL "AC8-teeth: grep failed to discriminate"
fi
rm -f "$POS" "$NEG"

# 강화된 count (round-3 advisory): 정확히 3개 명령이 "$harness_sid" "$spec_path" 로 끝남.
# 산문의 $harness_sid 언급은 이 접미 패턴에 매치 안 되므로 prose-immune·header-immune.
cnt=$(grep -cE '\$harness_sid" "\$spec_path"' "$SKILL")
[[ "$cnt" -eq 3 ]] \
  && note PASS "AC8-count: exactly 3 trio commands key \$harness_sid (got $cnt)" \
  || note FAIL "AC8-count: expected 3 harness_sid trio commands, got $cnt"

# AC12: Step 1 이 state_path.py session-id 로 read 를 해석(read==write 디렉토리) — Step1 윈도우.
step1_window | grep -qF 'state_path.py" session-id' \
  && note PASS "AC12: Step 1 resolves state via state_path.py session-id" \
  || note FAIL "AC12: Step 1 missing session-id read resolution"

# AC11: degradation exact-literal 두 개(grep -F, body-unique, header 아님).
grep -qF '리뷰 락 refresh skip (리뷰 강제 유지)' "$SKILL" \
  && note PASS "AC11-a: set degradation exact literal present" \
  || note FAIL "AC11-a: missing '리뷰 락 refresh skip (리뷰 강제 유지)'"
grep -qF '이 stop/approve는 기록되지 않음' "$SKILL" \
  && note PASS "AC11-b: pause/approve degradation exact literal present" \
  || note FAIL "AC11-b: missing '이 stop/approve는 기록되지 않음'"

# AC13: continuity non-collapse 가드 프로즈.
grep -qF 'continuity read collapse 금지' "$SKILL" \
  && note PASS "AC13: continuity non-collapse guard prose present" \
  || note FAIL "AC13: missing 'continuity read collapse 금지'"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
