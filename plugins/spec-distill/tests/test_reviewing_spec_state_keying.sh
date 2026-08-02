#!/usr/bin/env bash
# state-keying 불변식 회귀 락 — read==write 디렉토리(harness sid) + continuity
# non-collapse 가드. 전신 test_reviewing_spec_lock.sh(AC1/AC2/AC14/AC8-a·b·c/AC11)의
# 대상(review_lock.py set/pause, approve_handoff harness_sid 배선)은 Task 6이
# SKILL을 arm_ledger 세 verb로 재배선하며 소멸했다. 그중 AC12·AC13 두 불변식은
# 락과 무관하게 아직 살아 있고, AC8-count는 대상이 소멸한 게 아니라 형태만
# 바뀌었다(3개 trio → strip-pending·mark-reviewed 2개; check-born은 sid를 안 받는다)
# — 내용이 살아 있는 불변식을 형태 변화 이유로 버리는 것은 삭제 스윕의 실패 모드다.
# 파일을 지우는 대신 좁혀서 승계한다.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL="$REPO_ROOT/plugins/spec-distill/skills/reviewing-spec/SKILL.md"
pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# 윈도우 추출: ASCII-stable 구조 앵커로 Step 1 섹션만 잘라 grep(섹션 배치 증명).
# step1_window 정의는 옛 test_reviewing_spec_lock.sh에서 그대로 옮긴 것 — 이미 이
# SKILL에 대해 동작하는 앵커를 재작성하지 않는다.
step1_window()  { sed -n '/^## Steps$/,/^## Deterministic Routing Table/p' "$SKILL"; }

# W (신규): Step 1 윈도우가 비어 있지 않다 — 빈 윈도우는 앵커(## Steps / ## Deterministic
# Routing Table 헤더)가 SKILL에서 사라졌다는 뜻이지 통과가 아니다.
w_out="$(step1_window)"
[[ -n "$w_out" ]] \
  && note PASS "W: Step 1 윈도우가 비어 있지 않다 (앵커 생존)" \
  || note FAIL "W: Step 1 윈도우가 비었다 — 구조 앵커 파손"

# S1 (전 AC12 그대로): Step 1 이 state_path.py session-id 로 read 를 해석
# (read==write 디렉토리 불변식 — 이게 깨지면 스킬이 훅과 다른 파일을 읽어
# arm-once 전체가 무의미해진다).
step1_window | grep -qF 'state_path.py" session-id' \
  && note PASS "S1: Step 1 resolves state via state_path.py session-id" \
  || note FAIL "S1: Step 1 missing session-id read resolution"

# S2 (전 AC13 그대로): continuity non-collapse 가드 프로즈 — rereview_count/
# issue_history를 harness sid로 collapse하지 말라는 지시. 깨지면 인터뷰-선행
# 플로우에서 re-review cap이 조용히 리셋된다.
grep -qF 'continuity read collapse 금지' "$SKILL" \
  && note PASS "S2: continuity non-collapse guard prose present" \
  || note FAIL "S2: missing 'continuity read collapse 금지'"

# S3 (전 AC8-count 승계 — 형태만 변경): "trio 명령이 전부 $harness_sid로 키잉된다"는
# 이제 arm_ledger.py의 strip-pending·mark-reviewed 두 verb로 표현된다
# (check-born은 sid 인자를 받지 않는다 — approve 시점 조회이지 세션 상태 write가 아님).
cnt=$(grep -cE 'arm_ledger\.py" (strip-pending|mark-reviewed) "\$harness_sid' "$SKILL")
[[ "$cnt" -eq 2 ]] \
  && note PASS "S3: exactly 2 arm_ledger trio commands key \$harness_sid (got $cnt)" \
  || note FAIL "S3: expected 2 harness_sid-keyed arm_ledger commands, got $cnt"

# S4 (신규 teeth): S3의 정규식이 "$session_id"를 쓴 가짜 줄을 배제한다 — S3이
# 존재만 재고 값을 구분 못 하는 위양성을 봉쇄. production 파일은 건드리지 않고
# heredoc 프로브 문자열 하나에 같은 grep을 돌려 0건인지만 본다.
probe=$(cat <<'EOF'
python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/arm_ledger.py" strip-pending "$session_id" "$spec_path"
EOF
)
probe_cnt=$(grep -cE 'arm_ledger\.py" (strip-pending|mark-reviewed) "\$harness_sid' <<<"$probe")
[[ "$probe_cnt" -eq 0 ]] \
  && note PASS "S4: S3 정규식이 \$session_id 가짜 줄을 배제한다 (real teeth)" \
  || note FAIL "S4: S3 정규식이 \$session_id 가짜 줄까지 매치했다 (got $probe_cnt) — 위양성"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
