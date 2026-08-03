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
# sed 의 범위 주소는 **종료 주소가 매칭되지 않으면 EOF 까지** 출력한다. 그러면 "같은
# 섹션 안에 있다"를 주장하는 락이 조용히 file-wide 존재 확인으로 바뀐다 — 측정:
# step-4 라벨을 한 토큰 rename 하면 step3 윈도우가 12줄 → 130줄(217줄 파일 중)로
# 늘어나는데 스위트는 GREEN 이었고, 이어서 advisory 를 kill-switch 섹션으로 옮겨도
# GREEN 이었다(공존 주장 완전 무효화).
#
# 기존 `[[ -z ]]` 가드는 **빈** 윈도우만 잡는다 — 한쪽만 보는 가드다. 그래서 종료
# 앵커의 존재를 먼저 확인하고, 없으면 **빈 출력**을 낸다. 새 보고 경로를 만들지 않고
# 이미 있는 빈-윈도우 FAIL 가드를 재사용하는 것이 요점이다(락이 늘면 락끼리 어긋난다).
# **존재 확인만으로는 부족하다.** sed 는 종료 주소를 시작 매치 **다음 줄부터** 찾으므로,
# 종료 앵커가 파일에 있어도 시작보다 **앞에** 있으면 범위는 그대로 EOF 까지 흐른다.
# 실측: step-3 블록을 routing-table 뒤로 옮기면 윈도우가 12줄 → 129줄이 되는데 앵커는
# 여전히 존재하므로 존재-검사는 통과하고 스위트는 GREEN 이었다(= 고쳤다고 믿은 그 구멍).
# 그래서 물어야 할 것은 "앵커가 있는가" 가 아니라 **"범위가 앵커에서 끝났는가"** 다 —
# 출력의 마지막 줄이 종료 앵커면 sed 는 거기서 멈춘 것이고, 아니면 EOF 까지 흐른 것이다.
# 이 술어는 앵커 부재도 함께 잡으므로(없으면 마지막 줄도 매치되지 않는다) 이전 검사를
# 포함한다. 새 보고 경로는 만들지 않는다 — 빈 출력으로 기존 FAIL 가드를 그대로 쓴다.
bounded_window() {  # $1=시작 정규식  $2=종료 정규식
  local out; out="$(sed -n "/$1/,/$2/p" "$SKILL")"
  [[ -n "$out" ]] || return 0
  grep -q "$2" <<<"$(tail -n1 <<<"$out")" || return 0
  printf '%s\n' "$out"
}

step1_window()  { bounded_window '^## Steps$' '^## Deterministic Routing Table'; }

# W (신규): Step 1 윈도우가 비어 있지 않다 — 빈 윈도우는 앵커(## Steps / ## Deterministic
# Routing Table 헤더)가 SKILL에서 사라졌다는 뜻이지 통과가 아니다.
w_out="$(step1_window)"
[[ -n "$w_out" ]] \
  && note PASS "W: Step 1 윈도우가 비어 있지 않다 (앵커 생존)" \
  || note FAIL "W: Step 1 윈도우가 비었다 — 구조 앵커 파손"

# S1 (전 AC12 그대로): Step 1 이 state_path.py session-id 로 read 를 해석
# (read==write 디렉토리 불변식 — 이게 깨지면 스킬이 훅과 다른 파일을 읽어
# arm-once 전체가 무의미해진다).
# herestring 으로 받는다 — 파이프면 `grep -q` 가 첫 매치에 종료하며 생산자에 SIGPIPE 를
# 보내고, `set -o pipefail` 이 그 141 을 파이프라인 실패로 표면화해 **매치했는데도 FAIL**
# 이 난다. 이 파일에서 파이프를 쓰던 유일한 검사였고, S5–S7 은 이미 herestring 이다.
grep -qF 'state_path.py" session-id' <<<"$w_out" \
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

# S5 (전 AC8-c 승계): approve 창에서 `check-born` 이 **실제로 호출된다**.
# V9 는 'approve_handoff' 를 production 밖으로 밀어내는 *음의* 락이고, 음의 락은
# 대체물을 통째로 지워도 통과한다. 전신 AC8-c 는 approve 창 안의 배선을 잡고 있었으나
# 승계 없이 삭제됐다 — mutation 으로 확인된 구멍(이 줄을 지워도 shell 스위트 전부 green).
# 설계 §6 이 이 호출을 AP2 검증 앵커로 지정하므로 배선은 load-bearing 이다.
approve_window() { bounded_window '^## Approve handoff sequence' '^## In-flight state migration'; }
aw_out="$(approve_window)"
if [[ -z "$aw_out" ]]; then
  note FAIL "S5: approve 윈도우가 비었다 — 구조 앵커 파손(통과 아님)"
elif grep -qF 'arm_ledger.py" check-born' <<<"$aw_out"; then
  note PASS "S5: approve 창에서 check-born 이 호출된다 (전 AC8-c 승계)"
else
  note FAIL "S5: approve 창에 check-born 호출이 없다 — 미커밋 advisory 배선 소실"
fi

# S6/S7 (전 AC11-a·b 승계): degradation advisory 두 개가 살아 있다.
# "빈 harness_sid 는 조용히 skip 하지 않고 loud advisory 를 남긴다"는 계약은 리팩터를
# 살아남았지만(SKILL 에 두 곳) 그 락은 함께 삭제됐다 — 둘 다 mutation 으로 확인된 구멍.
# CLAUDE.md 의 graceful-degradation-with-loud-logging 요구이고, 조용한 degrade 는
# 문서가 리뷰 완료로 기록되지 않은 채 넘어간다는 뜻이다.
if [[ -z "$w_out" ]]; then
  note FAIL "S6: Step 1 윈도우가 비었다 — 앵커 파손"
elif grep -qF 'strip skip' <<<"$w_out"; then
  note PASS "S6: Step 1 빈 harness_sid → strip skip advisory 존재 (전 AC11-a)"
else
  note FAIL "S6: Step 1 strip-skip advisory 소실 — 조용한 degrade"
fi

# S7 은 섹션 윈도우 안에서 잰다 — file-wide grep 이면 리터럴이 SKILL 어디에 있든
# 통과해, advisory 를 기록 지점 밖으로 옮기는 변경을 못 잡는다(라벨은 "Step 3"라고
# 주장하면서). 리터럴 삭제 mutation 만으로는 두 설계를 구분할 수 없다.
step3_window() { bounded_window '^   \*\*리뷰 완료 기록 (v0\.25\.0)\*\*' '^4\. \*\*Apply routing table\*\*'; }
s3_out="$(step3_window)"
if [[ -z "$s3_out" ]]; then
  note FAIL "S7: Step 3 윈도우가 비었다 — 구조 앵커 파손(통과 아님)"
elif grep -qF '리뷰 완료 기록(mark-reviewed)을 남기지 못했다' <<<"$s3_out"; then
  note PASS "S7: Step 3 창 안에 mark-reviewed 미기록 advisory 존재 (전 AC11-b)"
else
  note FAIL "S7: Step 3 창에서 mark-reviewed 미기록 advisory 소실 — 조용한 degrade"
fi

# S8 (S3 의 in-file 음의 짝): S3 은 개수만 세므로, 올바른 `$harness_sid` 줄과 엉뚱한
# `$session_id` 줄이 함께 있어도 2 를 세어 통과한다. S4 는 heredoc 프로브에 대한
# *정규식 대조군*이지 검사 대상 파일의 속성이 아니다 — 전신 AC8-a/b 는 창 안에서
# `! grep ... "$session_id"` 를 걸고 있었다.
if grep -qE 'arm_ledger\.py" (strip-pending|mark-reviewed) "\$session_id' "$SKILL"; then
  note FAIL "S8: SKILL 안에 \$session_id 로 키잉된 arm_ledger 호출이 있다 — read==write 파손"
else
  note PASS "S8: SKILL 안에 \$session_id 로 키잉된 arm_ledger 호출이 없다 (S3 의 음의 짝)"
fi

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
