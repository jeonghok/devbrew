#!/usr/bin/env bash
# test_e2e_state.sh — scripts/e2e-state.sh (설계 v10 §4 · X1 · X2 · X4 · X5 · AC17 · AC18 · AC20 · AC20a · AC21).
#
# 각 케이스는 mktemp 아래 일회용 git 리포에서 돈다 — 라이브 리포의 워킹트리를 건드리지 않는다.
# 부팅 케이스가 띄우는 프로세스는 이름에 고유 표지(`$MARK`)를 실어, 정지 뒤 남은 것이 없는지를
# 프로세스 그룹이 아니라 **이름**으로 다시 센다(그룹 계수만 보면 그룹을 벗어난 자식을 못 본다).
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ES="$PLUGIN_ROOT/scripts/e2e-state.sh"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
unset DEVBREW_QUALITY_GATES_DISABLE DEVBREW_QUALITY_GATES_DISABLE_E2E DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST
MARK="300.$$"   # 띄우는 sleep 의 인자 — 프로세스 명령줄에 남는 고유 표지
TMPLIST="$(mktemp)"   # new_repo 가 $( ) 안에서 돌아도 새지 않게 파일로 적는다
cleanup() {
  pkill -f "$MARK" 2>/dev/null
  local d; while IFS= read -r d; do [ -n "$d" ] && rm -rf "$d"; done <"$TMPLIST"
  rm -f "$TMPLIST"
}
trap cleanup EXIT

new_repo() {   # stdout = 일회용 리포 경로(커밋 하나 · 추적 파일 a.txt · 무시 규칙 ignored/ · 기존 untracked u.txt)
  local d; d="$(cd "$(mktemp -d)" && pwd -P)"; printf '%s\n' "$d" >>"$TMPLIST"
  git -C "$d" init -q -b main
  printf 'a\n' >"$d/a.txt"; printf 'ignored/\n' >"$d/.gitignore"
  git -C "$d" add -A
  git -C "$d" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q -m init
  printf 'u1\n' >"$d/u.txt"
  mkdir -p "$d/.claude/quality-gates/sid12345"
  printf '%s\n' "$d"
}

fp() { (cd "$1" && bash "$ES" fingerprint --out "$2" >/dev/null); }
cmp_out() { (cd "$1" && bash "$ES" compare "$2" "$3"); }

# ── X2 · AC17 — 지문은 HEAD · 추적 파일 · 무시되지 않는 untracked 를 본다 ─────────────
case_X2_AC17_unchanged_is_same() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  fp "$d" "$s/b"; fp "$d" "$s/a"
  local out rc=0; out=$(cmp_out "$d" "$s/b" "$s/a") || rc=$?
  assert_eq "$rc" "0" "X2: 바뀐 것이 없으면 exit 0"
  assert_eq "$(printf '%s\n' "$out" | tail -n 1)" "same" "X2: 마지막 줄이 same"
}

case_X2_AC17_tracked_edit_invalidates() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  fp "$d" "$s/b"; printf 'changed\n' >>"$d/a.txt"; fp "$d" "$s/a"
  local out rc=0; out=$(cmp_out "$d" "$s/b" "$s/a") || rc=$?
  assert_eq "$rc" "1" "AC17: 추적 파일 변경은 exit 1"
  assert_grep "$out" '^changed: a\.txt$' "AC17: 바뀐 추적 파일이 경로로 나온다"
  assert_eq "$(printf '%s\n' "$out" | tail -n 1)" "changed: 1" "AC17: 마지막 줄이 changed: 1"
}

case_X2_AC17_head_move_invalidates() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  fp "$d" "$s/b"
  git -C "$d" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q --allow-empty -m moved
  fp "$d" "$s/a"
  local out rc=0; out=$(cmp_out "$d" "$s/b" "$s/a") || rc=$?
  assert_eq "$rc" "1" "AC17: HEAD 이동은 exit 1"
  assert_grep "$out" '^changed: HEAD \(' "AC17: HEAD 이동이 나온다"
}

case_X2_AC17_existing_untracked_edit_invalidates() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  fp "$d" "$s/b"; printf 'u2\n' >"$d/u.txt"; fp "$d" "$s/a"
  local out rc=0; out=$(cmp_out "$d" "$s/b" "$s/a") || rc=$?
  assert_eq "$rc" "1" "AC17: 이미 있던 untracked 소스의 내용 변경은 exit 1"
  assert_grep "$out" '^changed: u\.txt$' "AC17: 그 untracked 경로가 나온다"
}

case_X2_untracked_add_and_delete_invalidate() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  fp "$d" "$s/b"; printf 'n\n' >"$d/new.txt"; rm -f "$d/u.txt"; fp "$d" "$s/a"
  local out; out=$(cmp_out "$d" "$s/b" "$s/a")
  assert_grep "$out" '^changed: new\.txt$' "X2: untracked 추가가 나온다"
  assert_grep "$out" '^changed: u\.txt$'   "X2: untracked 삭제가 나온다"
}

case_X2_ignored_and_own_namespace_do_not_invalidate() {
  # 양의 짝 — 무시된 파일과 qg 자신의 상태 폴더는 지문 밖이다(그렇지 않으면 매 걷기가 무효다).
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  fp "$d" "$s/b"
  mkdir -p "$d/ignored"; printf 'log\n' >"$d/ignored/app.log"; printf 'x\n' >"$s/evidence.tsv"
  fp "$d" "$s/a"
  local out rc=0; out=$(cmp_out "$d" "$s/b" "$s/a") || rc=$?
  assert_eq "$rc" "0" "X2: 무시된 파일 · .claude/quality-gates 쓰기는 무효가 아니다"
}

case_V8_malformed_fingerprint_is_not_same() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  fp "$d" "$s/b"; printf 'garbage\n' >"$s/a"
  local rc=0; cmp_out "$d" "$s/b" "$s/a" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "판독할 수 없는 지문은 same 이 아니라 exit 4"
}

# ── X5 · AC20 — kill switch 둘(+전역) 중 하나라도 켜지면 측정·실행 전에 exit 3 ─────────
case_X5_AC20_kill_switch_refuses_fingerprint_compare() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  fp "$d" "$s/b"
  local v rc
  for v in DEVBREW_QUALITY_GATES_DISABLE_E2E DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST DEVBREW_QUALITY_GATES_DISABLE; do
    rm -f "$s/x"
    rc=0; (cd "$d" && env "$v=1" bash "$ES" fingerprint --out "$s/x" >/dev/null 2>&1) || rc=$?
    assert_eq "$rc" "3" "X5: $v=1 이면 fingerprint 가 exit 3"
    [ ! -e "$s/x" ] && ok "X5: $v=1 이면 지문 파일이 생기지 않는다" || no "X5: $v=1 인데 지문 파일이 생겼다"
    rc=0; (cd "$d" && env "$v=1" bash "$ES" compare "$s/b" "$s/b" >/dev/null 2>&1) || rc=$?
    assert_eq "$rc" "3" "X5: $v=1 이면 compare 가 exit 3"
  done
}

case_X5_only_exact_one_disables() {
  # 양의 짝 — 전체 토큰 일치(E5). `1` 이 아닌 값은 끄지 않는다.
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  local rc=0; (cd "$d" && DEVBREW_QUALITY_GATES_DISABLE_E2E=true bash "$ES" fingerprint --out "$s/x" >/dev/null 2>&1) || rc=$?
  assert_eq "$rc" "0" "X5: DISABLE_E2E=true 는 끄지 않는다(1 만 끈다)"
}

case_RF3_odd_path_names_are_reported() {
  # Review Focus 3 — 공백 · 한글 · 줄바꿈이 든 경로도 무효 판정과 경로 목록에 나온다.
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  printf 'x\n' >"$d/a b.txt"; printf 'x\n' >"$d/한글.txt"; printf 'x\n' >"$d/$(printf 'n\nl.txt')"
  fp "$d" "$s/b"
  printf 'y\n' >"$d/a b.txt"; printf 'y\n' >"$d/한글.txt"; printf 'y\n' >"$d/$(printf 'n\nl.txt')"
  fp "$d" "$s/a"
  local out rc=0; out=$(cmp_out "$d" "$s/b" "$s/a") || rc=$?
  assert_eq "$rc" "1" "RF3: 이상한 이름의 파일 변경도 무효다"
  assert_grep "$out" '^changed: a b\.txt$' "RF3: 공백 든 경로"
  assert_grep "$out" '^changed: 한글\.txt$' "RF3: 한글 경로"
  assert_eq "$(printf '%s\n' "$out" | tail -n 1)" "changed: 3" "RF3: 줄바꿈 든 경로까지 셋 다 센다"
}

# ── X1 · AC18 — 판정안은 증거표에서 코드가 낸다 ──────────────────────────────────────
prop() { local f; f="$(mktemp)"; printf '%s\n' "$f" >>"$TMPLIST"; printf '%b' "$1" >"$f"; bash "$ES" propose "$f"; }

case_X1_all_met_with_evidence_is_pass() {
  local out; out=$(prop '기대 상태\t판정\t증거\nPOST 201\t충족\tHTTP/1.0 201 Created\nGET 에 apple\t충족\t{"items": ["apple"]}\n')
  assert_eq "$(printf '%s\n' "$out" | tail -n 1)" "proposal: pass" "X1: 전부 충족이고 증거가 있으면 pass"
}

case_X1_AC18_met_without_evidence_is_unconfirmed() {
  local out; out=$(prop 'POST 201\t충족\tHTTP/1.0 201 Created\nGET 에 apple\t충족\t-\n')
  assert_grep "$out" '^coerced: 2 충족 → 미확인' "X1: 증거 없는 충족은 미확인으로 강제된다"
  assert_eq "$(printf '%s\n' "$out" | tail -n 1)" "proposal: 미확인" "AC18: 증거 인용 없는 기대 상태가 있고 불충족이 없으면 미확인"
}

case_X1_unmet_is_fail() {
  local out; out=$(prop 'POST 201\t불충족\tHTTP/1.0 400 Bad Request\nGET 에 apple\t충족\t\n')
  assert_eq "$(printf '%s\n' "$out" | tail -n 1)" "proposal: fail" "X1: 불충족이 하나라도 있으면 fail"
}

case_X1_empty_table_is_not_pass() {
  local out; out=$(prop '기대 상태\t판정\t증거\n')
  assert_eq "$(printf '%s\n' "$out" | tail -n 1)" "proposal: 미확인" "X1: 기대 상태가 없으면 pass 가 아니라 미확인"
}

case_V8_malformed_table_is_unreadable() {
  local rc=0; prop 'POST 201\t아마도\tx\n' >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "열거 밖 판정은 exit 4"
  rc=0; prop 'POST 201\t충족\n' >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "4" "칸 수가 셋이 아니면 exit 4"
}

case_X5_near_miss_values_do_not_disable() {
  # 음의 짝 — 전체 토큰 일치(E5): 공백이 붙은 `1 ` · `01` · `yes` 는 끄지 않는다.
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  local v rc
  for v in "1 " "01" "yes"; do
    rm -f "$s/x"
    rc=0; (cd "$d" && env "DEVBREW_QUALITY_GATES_DISABLE_E2E=$v" bash "$ES" fingerprint --out "$s/x" >/dev/null 2>&1) || rc=$?
    assert_eq "$rc" "0" "X5: DISABLE_E2E='$v' 는 끄지 않는다"
  done
}

case_X2_exclusion_is_exactly_own_namespace() {
  # 제외 범위는 `.claude/quality-gates/` 하나뿐이다 — 이웃 폴더의 변경은 무효다.
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  local sub rc out
  for sub in ".claude/quality-gates-other" ".claude/other"; do
    fp "$d" "$s/b"
    mkdir -p "$d/$sub"; printf 'x\n' >"$d/$sub/x"
    fp "$d" "$s/a"
    rc=0; out=$(cmp_out "$d" "$s/b" "$s/a") || rc=$?
    assert_eq "$rc" "1" "X2: $sub 아래 변경은 무효다"
    assert_grep "$out" "^changed: $sub/x\$" "X2: $sub/x 가 경로 목록에 나온다"
    rm -rf "$d/$sub"
  done
  fp "$d" "$s/b"
  mkdir -p "$d/.claude/quality-gates/anything"; printf 'x\n' >"$d/.claude/quality-gates/anything/y"
  fp "$d" "$s/a"
  rc=0; cmp_out "$d" "$s/b" "$s/a" >/dev/null || rc=$?
  assert_eq "$rc" "0" "X2: .claude/quality-gates/<무엇이든> 아래 변경은 무효가 아니다"
}

# ── X4 · AC20a · AC21 — 띄운 프로세스는 모든 종료 경로에서 내린다 ─────────────────────
left() { pgrep -f "sleep $MARK" | wc -l | tr -d ' '; }

case_X4_AC21_stop_takes_down_whole_group() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  local cmd="(sleep $MARK) & bash -c 'sleep $MARK' & echo ready-$MARK; sleep $MARK"
  local out rc=0; out=$(cd "$d" && bash "$ES" boot --dir "$s" --cmd "$cmd" --ready-log "ready-$MARK" --timeout 10) || rc=$?
  assert_eq "$rc" "0" "X4: 준비 신호(로그 줄)가 오면 exit 0"
  assert_grep "$out" '^ready: pgid=[0-9]+' "X4: ready 줄이 pgid 를 싣는다"
  [ "$(left)" -ge 3 ] && ok "X4: 자식 · 손자 프로세스가 떠 있다(대조)" || no "X4: 대조 실패 — 띄운 프로세스가 $(left)개"
  out=$(bash "$ES" stop --dir "$s"); rc=$?
  assert_eq "$rc" "0" "AC21: stop exit 0"
  assert_grep "$out" '^stopped: pgid=' "AC21: stopped 줄"
  assert_eq "$(left)" "0" "AC21: 정지 뒤 띄운 프로세스가 하나도 남지 않는다"
  out=$(bash "$ES" stop --dir "$s")
  assert_eq "$out" "stopped: none" "X4: 두 번째 stop 은 stopped: none(멱등)"
}

case_AC20a_boot_exit_nonzero_is_boot_failed() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  local out rc=0; out=$(cd "$d" && bash "$ES" boot --dir "$s" --cmd "echo dying-$MARK; exit 7" --ready-port 1 --timeout 10) || rc=$?
  assert_eq "$rc" "4" "AC20a: 부팅 명령이 비0 이면 exit 4"
  assert_eq "$(printf '%s\n' "$out" | tail -n 1)" "boot-failed: exit-7" "AC20a: 마지막 줄 boot-failed: exit-7"
  assert_grep "$out" "dying-$MARK" "AC20a: 부팅 출력 끝부분이 증거로 나온다"
  [ ! -e "$s/e2e-app.pgid" ] && ok "AC21: 부팅 실패 뒤 pgid 파일이 없다" || no "AC21: 부팅 실패 뒤 pgid 파일이 남았다"
}

case_AC20a_AC21_boot_timeout_leaves_nothing() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  local out rc=0; out=$(cd "$d" && bash "$ES" boot --dir "$s" --cmd "sleep $MARK" --ready-log never-printed --timeout 1) || rc=$?
  assert_eq "$rc" "4" "AC20a: 준비 신호가 상한 안에 안 오면 exit 4"
  assert_eq "$(printf '%s\n' "$out" | tail -n 1)" "boot-failed: timeout-1s" "AC20a: 마지막 줄 boot-failed: timeout-1s"
  assert_eq "$(left)" "0" "AC21: 시간 초과 뒤 띄운 프로세스가 남지 않는다"
}

case_AC21_interrupted_boot_leaves_nothing() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  (cd "$d" && exec bash "$ES" boot --dir "$s" --cmd "sleep $MARK" --ready-log never-printed --timeout 30 >/dev/null 2>&1) &
  local bp=$!
  local i=0; while [ ! -s "$s/e2e-app.pgid" ] && [ "$i" -lt 25 ]; do sleep 0.2; i=$((i+1)); done
  sleep 0.5
  kill -TERM "$bp" 2>/dev/null; wait "$bp" 2>/dev/null
  sleep 1
  assert_eq "$(left)" "0" "AC21: 기다리는 중 boot 가 TERM 을 받아도 띄운 프로세스가 남지 않는다"
}

case_RF1_port_in_use_before_boot_is_boot_failed() {
  # Review Focus 1 — 부팅 전에 이미 열린 포트를 준비 신호로 읽으면 다른 앱을 걷고 pass 를 낸다.
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  local port; port=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
  python3 -c 'import socket, sys, time
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", int(sys.argv[1]))); s.listen(); time.sleep(float(sys.argv[2]))' "$port" "$MARK" &
  local squatter=$!
  sleep 0.5
  local out rc=0; out=$(cd "$d" && bash "$ES" boot --dir "$s" --cmd "touch '$d/booted'; sleep $MARK" --ready-port "$port" --timeout 5) || rc=$?
  assert_eq "$rc" "4" "RF1: 부팅 전에 이미 열린 포트는 exit 4"
  assert_grep "$out" '^boot-failed: port-in-use' "RF1: 사유가 port-in-use"
  [ ! -e "$d/booted" ] && ok "RF1: 부팅 명령을 실행하지 않았다" || no "RF1: 포트가 남의 것인데 부팅 명령을 실행했다"
  kill "$squatter" 2>/dev/null; wait "$squatter" 2>/dev/null
}

case_RF2_AC21_launcher_exiting_early_leaves_nothing() {
  # Review Focus 2 — 리더가 자식을 남기고 0 으로 먼저 끝나는 런처. 준비 신호 전 리더 종료는 부팅 실패이고,
  # 그룹에 남은 자식도 내린다.
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  local out rc=0; out=$(cd "$d" && bash "$ES" boot --dir "$s" --cmd "(sleep $MARK &) ; exit 0" --ready-log never-printed --timeout 5) || rc=$?
  assert_eq "$rc" "4" "RF2: 준비 신호 전에 리더가 끝나면 exit 4"
  assert_eq "$(printf '%s\n' "$out" | tail -n 1)" "boot-failed: exit-0" "RF2: 사유가 exit-0"
  sleep 0.5
  assert_eq "$(left)" "0" "RF2: 리더가 남긴 자식도 내려간다"
}

case_X4_stop_refuses_unsafe_pgid() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  printf '1 x\n' >"$s/e2e-app.pgid"
  local rc=0; bash "$ES" stop --dir "$s" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "5" "X4: pgid 1 로는 kill 하지 않는다(exit 5)"
}

setsid_victim() {   # 자기 그룹의 리더로 $MARK 표지 sleep 을 띄운다 — 전역 VICTIM 에 pid
  rm -f "$1.pid"
  python3 -c 'import os, sys
os.setsid()
open(sys.argv[2], "w").write(str(os.getpid()))
os.execvp("sleep", ["sleep", sys.argv[1]])' "$MARK" "$1.pid" >/dev/null 2>&1 &
  local i=0; while [ ! -s "$1.pid" ] && [ "$i" -lt 25 ]; do sleep 0.1; i=$((i+1)); done
  VICTIM=$(cat "$1.pid")
}

case_X4_stop_skips_reused_pid() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  setsid_victim "$d/v"
  printf '%s %s\n' "$VICTIM" "Thu Jan  1 00:00:00 1970" >"$s/e2e-app.pgid"
  local out; out=$(bash "$ES" stop --dir "$s")
  assert_grep "$out" '^stopped: none \(pid ' "X4: 시작 시각이 다르면 재사용된 pid 로 보고 죽이지 않는다"
  kill -0 "$VICTIM" 2>/dev/null && ok "X4: 무관한 프로세스가 살아 있다" || no "X4: 무관한 프로세스를 죽였다"
  kill "$VICTIM" 2>/dev/null
}

case_X4_stop_refuses_when_start_time_unknown() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  setsid_victim "$d/v"
  printf '%s\n' "$VICTIM" >"$s/e2e-app.pgid"
  local rc=0; bash "$ES" stop --dir "$s" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "5" "I2: 시작 시각 없는 기록은 살아 있는 리더를 죽이지 않고 exit 5"
  kill -0 "$VICTIM" 2>/dev/null && ok "I2: 프로세스가 살아 있다" || no "I2: 시작 시각을 모르는데 죽였다"
  [ -s "$s/e2e-app.pgid" ] && ok "I2: 기록이 남는다" || no "I2: 기록이 지워졌다"
  kill "$VICTIM" 2>/dev/null
}

case_X4_stop_refuses_unreadable_records() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345" v rc
  for v in "0 x" "-5 x" "01 x" "99999999999 x" "12345678 x"; do
    printf '%s\n' "$v" >"$s/e2e-app.pgid"; rc=0
    bash "$ES" stop --dir "$s" >/dev/null 2>&1 || rc=$?
    assert_eq "$rc" "5" "m7: 기록 '$v' 는 판독 불가(exit 5)"
  done
}

case_I1_m4_bad_timeout_and_port_refused_before_launch() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345" rc
  rc=0; (cd "$d" && DEVBREW_QUALITY_GATES_E2E_BOOT_TIMEOUT=09 bash "$ES" boot --dir "$s" --cmd "touch '$d/booted'" --ready-log x >/dev/null 2>&1) || rc=$?
  assert_eq "$rc" "2" "I1: 환경 변수 09 는 exit 2"
  rc=0; (cd "$d" && bash "$ES" boot --dir "$s" --cmd "touch '$d/booted'" --ready-log x --timeout 08 >/dev/null 2>&1) || rc=$?
  assert_eq "$rc" "2" "I1: --timeout 08 은 exit 2"
  rc=0; (cd "$d" && bash "$ES" boot --dir "$s" --cmd "touch '$d/booted'" --ready-port 70000 >/dev/null 2>&1) || rc=$?
  assert_eq "$rc" "2" "m4: --ready-port 70000 은 exit 2"
  rc=0; (cd "$d" && bash "$ES" boot --dir "$s" --cmd "touch '$d/booted'" --ready-port 0 >/dev/null 2>&1) || rc=$?
  assert_eq "$rc" "2" "m4: --ready-port 0 은 exit 2"
  [ ! -e "$d/booted" ] && [ ! -e "$s/e2e-app.pgid" ] && ok "I1: 아무것도 띄우지 않았고 기록도 없다" || no "I1: 잘못된 값인데 띄웠다"
}

case_X5_AC20_kill_switch_refuses_boot() {
  local d; d=$(new_repo); local s="$d/.claude/quality-gates/sid12345"
  local v rc
  for v in DEVBREW_QUALITY_GATES_DISABLE_E2E DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST DEVBREW_QUALITY_GATES_DISABLE; do
    rm -f "$d/booted"
    rc=0; (cd "$d" && env "$v=1" bash "$ES" boot --dir "$s" --cmd "touch '$d/booted'" --ready-port 1 >/dev/null 2>&1) || rc=$?
    assert_eq "$rc" "3" "X5: $v=1 이면 boot 가 exit 3"
    [ ! -e "$d/booted" ] && ok "X5: $v=1 이면 부팅 명령이 실행되지 않는다" || no "X5: $v=1 인데 부팅 명령이 실행됐다"
  done
}


for c in $(declare -F | awk '{print $3}' | grep '^case_'); do
  note "── $c"
  "$c"
done
finish
