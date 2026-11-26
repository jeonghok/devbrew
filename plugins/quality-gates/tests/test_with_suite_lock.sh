#!/usr/bin/env bash
# test_with_suite_lock.sh — 차등 테스트의 테스트 명령을 공유 스위트 잠금 아래 돌리는 감싸개(scripts/with-suite-lock.sh).
# 요구: docs/superpowers/specs/2026-11-24-qg-planted-text-suite-lock-design.md §4 · AC11 · AC12 · AC13 · AC14 · AC26.
# 잠금은 두 프로세스로 잰다 — 다른 프로세스가 쥔 잠금 앞에서 기다리지 않는지, 감싸개가 쥔 동안 다른 쪽이 기다리는지.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
W="$PLUGIN_ROOT/scripts/with-suite-lock.sh"
SL="$PLUGIN_ROOT/scripts/suite_lock.py"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"

T="$(mktemp -d)" && [ -d "$T" ] || { echo "mktemp 실패"; exit 1; }
HOLDER=""
cleanup() { [ -n "$HOLDER" ] && kill "$HOLDER" 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT

now() { python3 -c 'import time; print("%.3f" % time.time())'; }
ge() { python3 -c 'import sys; sys.exit(0 if float(sys.argv[1]) >= float(sys.argv[2]) else 1)' "$1" "$2"; }
lt() { python3 -c 'import sys; sys.exit(0 if float(sys.argv[1]) - float(sys.argv[2]) < float(sys.argv[3]) else 1)' "$1" "$2" "$3"; }
OVL_BUSY_HEAD='> [quality-gates] 차등 테스트가 다른 전체 테스트와 겹쳐 돈다 — 결과가 경합일 수 있다(잠금 주인: '
OVL_UNUSABLE='> [quality-gates] 차등 테스트가 다른 전체 테스트와 겹쳐 돈다 — 결과가 경합일 수 있다(잠금을 쓸 수 없었다).'
OVL_NOREC='> [quality-gates] 겹침 기록을 쓰지 못했다 — 결과 파일의 「## 차등 테스트」 에 겹침 줄이 빠진다.'

newrd() {   # newrd <이름> [잠금 폴더] — 세션 폴더를 만들고, 잠금 폴더를 주면 잠금 자리 파일을 쓴다
  local rd="$T/$1"; mkdir -p "$rd"
  [ -n "${2:-}" ] && printf '%s\n' "$2" > "$rd/suite-lock-path.txt"
  printf '%s' "$rd"
}
hold() {   # hold <잠금 폴더> <초> — 다른 프로세스가 잠금을 쥔다(주인 other-suite). 쥘 때까지 기다린다
  python3 "$SL" run --lock "$1" --owner other-suite --wait 0 -- sleep "$2" >/dev/null 2>&1 &
  HOLDER=$!
  local i=0
  while [ $i -lt 100 ]; do
    [ -f "$1/owner" ] && grep -q other-suite "$1/owner" 2>/dev/null && return 0
    sleep 0.1; i=$((i + 1))
  done
  return 1
}

case_free_lock_held_during_command() {   # AC12 — 비어 있으면 명령 동안 주인이 qg 인 잠금이 있고 끝나면 없다
  local lk="$T/locks1/lk" rd out rc
  mkdir -p "$T/locks1"; rd=$(newrd free "$lk")
  out=$("$W" "$rd" -- sh -c 'echo first; python3 "$1" show --lock "$2"; echo last' _ "$SL" "$lk" 2>"$T/free.err"); rc=$?
  assert_eq "$rc" "0" "free_lock_held_during_command: 명령의 종료 코드 0"
  assert_contains "$out" " quality-gates " "free_lock_held_during_command: 명령 안에서 본 잠금의 주인이 quality-gates 다"
  assert_contains "$out" "주인 프로세스가 돌고 있다" "free_lock_held_during_command: 명령 안에서 잠금이 바쁘다"
  assert_eq "$(printf '%s\n' "$out" | sed -n '1p;$p' | tr '\n' ' ')" "first last " "free_lock_held_during_command: 표준 출력은 명령의 것뿐이다(앞뒤로 잠금 줄이 없다)"
  assert_eq "$(printf '%s\n' "$out" | grep -c '^\[suite-lock\]')" "0" "free_lock_held_during_command: [suite-lock] 줄을 내지 않는다"
  assert_eq "$(python3 "$SL" show --lock "$lk")" "스위트 잠금: 비어 있음" "free_lock_held_during_command: 끝난 뒤 잠금이 비었다"
  [ ! -e "$rd/suite-overlap.txt" ] && ok "free_lock_held_during_command: 겹침 기록이 없다" || no "free_lock_held_during_command: 겹침 기록이 생겼다"
  assert_eq "$(cat "$T/free.err")" "" "free_lock_held_during_command: 표준 오류에 아무것도 없다(겹침 줄 없음)"
}

case_busy_runs_without_wait() {   # AC12 · AC13 — 잡혀 있으면 기다리지 않고 돌고, 겹침 기록 busy 한 줄 · 화면 줄 한 번
  local lk="$T/locks2/lk" rd out rc t0 t1 err2
  mkdir -p "$T/locks2"; rd=$(newrd busy "$lk")
  hold "$lk" 8 && ok "busy_runs_without_wait: 다른 프로세스가 잠금을 쥐었다" || { no "busy_runs_without_wait: 잠금을 쥐지 못했다"; return; }
  local owner; owner="$(cat "$lk/owner")"
  t0=$(now); out=$("$W" "$rd" -- sh -c 'echo ran; exit 4' 2>"$T/busy.err"); rc=$?; t1=$(now)
  assert_eq "$rc" "4" "busy_runs_without_wait: 명령의 종료 코드를 그대로 낸다"
  assert_eq "$out" "ran" "busy_runs_without_wait: 명령이 잠금 없이 돌았다"
  lt "$t1" "$t0" 3 && ok "busy_runs_without_wait: 기다리지 않았다($t0 → $t1)" || no "busy_runs_without_wait: 기다렸다($t0 → $t1)"
  grep -q other-suite "$lk/owner" 2>/dev/null && ok "busy_runs_without_wait: 감싸개가 끝났을 때 다른 쪽이 아직 쥐고 있다(기다린 게 아니다)" \
    || no "busy_runs_without_wait: 다른 쪽의 잠금이 이미 풀렸다"
  assert_eq "$(grep -c . "$rd/suite-overlap.txt" 2>/dev/null)" "1" "busy_runs_without_wait: 겹침 기록이 한 줄이다"
  local kind o at; IFS="$(printf '\t')" read -r kind o at < "$rd/suite-overlap.txt"
  assert_eq "$kind" "busy" "busy_runs_without_wait: 겹침 기록의 꼴이 busy 다"
  assert_eq "$o" "$owner" "busy_runs_without_wait: 겹침 기록의 주인이 잠금의 owner 그대로다"
  assert_grep "$at" '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$' "busy_runs_without_wait: 겹침 기록에 잡은 시각이 있다"
  assert_eq "$(cat "$T/busy.err")" "${OVL_BUSY_HEAD}${o} · ${at})." "busy_runs_without_wait: 화면 줄(표준 오류)이 정해진 꼴 한 줄이다"
  "$W" "$rd" -- true 2>"$T/busy2.err"
  assert_eq "$(grep -c . "$rd/suite-overlap.txt")" "2" "busy_runs_without_wait: 둘째 겹침도 기록에 덧붙인다"
  assert_eq "$(cat "$T/busy2.err")" "" "busy_runs_without_wait: 화면 줄은 한 실행에 한 번이다(기록이 이미 있으면 내지 않는다)"
  kill "$HOLDER" 2>/dev/null; wait "$HOLDER" 2>/dev/null; HOLDER=""
}

case_unusable_runs() {   # AC12 · AC26 — 잠금 자리에 잠금이 아닌 것이 있으면 명령은 돌고 unusable, 그 폴더는 그대로
  local lk="$T/locks3/lk" rd out rc
  mkdir -p "$lk"; printf 'keep\n' > "$lk/report.md"; rd=$(newrd unusable "$lk")
  out=$("$W" "$rd" -- sh -c 'echo ran; exit 0' 2>"$T/unusable.err"); rc=$?
  assert_eq "$rc" "0" "unusable_runs: 명령의 종료 코드 0"
  assert_eq "$out" "ran" "unusable_runs: 명령이 잠금 없이 돌았다"
  assert_eq "$(cat "$rd/suite-overlap.txt" 2>/dev/null)" "$(printf 'unusable\t-\t-')" "unusable_runs: 겹침 기록이 unusable 한 줄이다"
  assert_eq "$(cat "$T/unusable.err")" "$OVL_UNUSABLE" "unusable_runs: 화면 줄의 괄호 안이 「잠금을 쓸 수 없었다」 다"
  assert_eq "$(ls -A "$lk" | tr '\n' ' ')" "report.md " "unusable_runs: 그 폴더 안이 그대로다"
  assert_eq "$(cat "$lk/report.md")" "keep" "unusable_runs: 안의 파일 내용이 그대로다"
  # 잠금 자리 파일이 비었어도(잠금을 쓰라고 했는데 자리를 모른다) 잠금 없이 돌고 unusable 이다
  local rd2; rd2=$(newrd unusable-empty); : > "$rd2/suite-lock-path.txt"
  out=$("$W" "$rd2" -- sh -c 'echo ran2' 2>/dev/null)
  assert_eq "$out" "ran2" "unusable_runs: 잠금 자리 파일이 비어도 명령은 돈다"
  assert_eq "$(cut -f1 "$rd2/suite-overlap.txt" 2>/dev/null)" "unusable" "unusable_runs: 잠금 자리 파일이 비면 unusable"
}

case_rc_not_mixed() {   # AC12 — 명령의 75 · 3 이 잠금의 75 · 3 으로 읽히지 않는다
  local lk="$T/locks4/lk" rd want rc
  mkdir -p "$T/locks4"; rd=$(newrd rcmix "$lk")
  for want in 75 3 1 0 127; do
    "$W" "$rd" -- sh -c "exit $want" >/dev/null 2>"$T/rc.err"; rc=$?
    assert_eq "$rc" "$want" "rc_not_mixed: 명령이 exit $want → 감싸개도 $want"
  done
  "$W" "$rd" -- "$T/no-such-command" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "127" "rc_not_mixed: 없는 명령 → 127(잠금 아래서 돈 종료 코드)"
  [ ! -e "$rd/suite-overlap.txt" ] && ok "rc_not_mixed: 겹침 기록이 없다" || no "rc_not_mixed: 명령의 종료 코드를 잠금 실패로 읽어 겹침을 적었다"
  assert_eq "$(python3 "$SL" show --lock "$lk")" "스위트 잠금: 비어 있음" "rc_not_mixed: 끝난 뒤 잠금이 비었다"
}

case_other_waits_for_qg() {   # AC14 — 감싸개가 쥔 동안 다른 프로세스의 run --wait 는 기다렸다가 감싸개 명령이 끝난 뒤 잡는다
  local lk="$T/locks5/lk" rd wpid i
  mkdir -p "$T/locks5"; rd=$(newrd waits "$lk")
  "$W" "$rd" -- sh -c 'sleep 3; python3 -c "import time; print(\"%.3f\" % time.time())" > "$1"' _ "$T/qg-end" >/dev/null 2>&1 &
  wpid=$!
  i=0; while [ $i -lt 100 ] && ! grep -q quality-gates "$lk/owner" 2>/dev/null; do sleep 0.1; i=$((i + 1)); done
  grep -q quality-gates "$lk/owner" 2>/dev/null && ok "other_waits_for_qg: 감싸개가 잠금을 쥐었다" || { no "other_waits_for_qg: 감싸개가 잠금을 쥐지 않았다"; wait "$wpid"; return; }
  python3 "$SL" run --lock "$lk" --owner other --wait 30 -- python3 -c 'import sys, time; open(sys.argv[1], "w").write("%.3f" % time.time())' "$T/other-start" > "$T/other.out" 2>&1
  local orc=$?
  wait "$wpid"
  assert_eq "$orc" "0" "other_waits_for_qg: 다른 쪽이 결국 잡고 명령을 돌렸다"
  assert_contains "$(cat "$T/other.out")" "기다린다(줄)" "other_waits_for_qg: 다른 쪽이 줄을 섰다"
  if [ -s "$T/qg-end" ] && [ -s "$T/other-start" ] && ge "$(cat "$T/other-start")" "$(cat "$T/qg-end")"; then
    ok "other_waits_for_qg: 다른 쪽 명령의 시작($(cat "$T/other-start")) ≥ 감싸개 명령의 끝($(cat "$T/qg-end"))"
  else
    no "other_waits_for_qg: 다른 쪽이 감싸개 명령이 끝나기 전에 돌았다(시작 $(cat "$T/other-start" 2>/dev/null) · 끝 $(cat "$T/qg-end" 2>/dev/null))"
  fi
}

case_no_lock_file_exec() {   # AC11 — 잠금 자리 파일이 없으면 명령만 돌고 잠금 폴더가 생기지 않는다
  local rd out rc
  rd=$(newrd nolock)
  out=$("$W" "$rd" -- sh -c 'echo plain; exit 6' 2>"$T/nolock.err"); rc=$?
  assert_eq "$rc" "6" "no_lock_file_exec: 명령의 종료 코드를 그대로 낸다"
  assert_eq "$out" "plain" "no_lock_file_exec: 명령이 돌았다"
  assert_eq "$(cat "$T/nolock.err")" "" "no_lock_file_exec: 표준 오류에 아무것도 없다"
  [ ! -e "$rd/suite-overlap.txt" ] && ok "no_lock_file_exec: 겹침 기록이 없다" || no "no_lock_file_exec: 겹침 기록이 생겼다"
  assert_eq "$(ls -A "$rd" | grep -c .)" "0" "no_lock_file_exec: 세션 폴더에 아무것도 생기지 않았다"
  assert_eq "$(find "$T" -name owner -newer "$rd" | grep -c .)" "0" "no_lock_file_exec: 어디에도 잠금(owner)을 만들지 않았다"
}

case_lock_path_with_space() {   # Review Focus 3 — 공백 든 잠금 경로도 잡고 푼다
  local lk="$T/with space/suite lock" rd out rc
  mkdir -p "$T/with space"; rd=$(newrd "space rd" "$lk")
  out=$("$W" "$rd" -- python3 "$SL" show --lock "$lk" 2>"$T/space.err"); rc=$?
  assert_eq "$rc" "0" "lock_path_with_space: 종료 코드 0"
  assert_contains "$out" " quality-gates " "lock_path_with_space: 명령 동안 주인이 quality-gates 다"
  assert_eq "$(python3 "$SL" show --lock "$lk")" "스위트 잠금: 비어 있음" "lock_path_with_space: 끝난 뒤 비었다"
  [ ! -e "$rd/suite-overlap.txt" ] && ok "lock_path_with_space: 겹침 기록이 없다" || no "lock_path_with_space: 겹침 기록이 생겼다"
}

case_overlap_record_unwritable_noted() {   # 겹침 기록을 쓰지 못하면 결과 파일에 겹침 줄이 빠진다는 것을 표준 오류에 한 줄 알린다(판정 값은 없다)
  local lk="$T/locks6/lk" rd out rc err
  if [ "$(id -u)" = 0 ]; then ok "overlap_record_unwritable_noted: root 라 쓰기 막기를 잴 수 없어 건너뛴다"; return; fi
  mkdir -p "$lk"; printf 'keep\n' > "$lk/report.md"; rd=$(newrd unwritable "$lk")
  chmod a-w "$rd"
  out=$("$W" "$rd" -- sh -c 'echo ran; exit 5' 2>"$T/unwritable.err"); rc=$?
  chmod u+w "$rd"
  assert_eq "$rc" "5" "overlap_record_unwritable_noted: 명령의 종료 코드를 그대로 낸다"
  assert_eq "$out" "ran" "overlap_record_unwritable_noted: 명령이 잠금 없이 돌았다"
  [ ! -e "$rd/suite-overlap.txt" ] && ok "overlap_record_unwritable_noted: 겹침 기록이 생기지 않았다(쓰기가 실제로 막혔다)" \
    || no "overlap_record_unwritable_noted: 겹침 기록이 생겼다 — 쓰기 막기가 듣지 않아 아래 단언이 공허하다"
  err="$(cat "$T/unwritable.err")"
  assert_eq "$(printf '%s\n' "$err" | grep -cxF "$OVL_UNUSABLE")" "1" "overlap_record_unwritable_noted: 화면 겹침 줄은 그대로 한 번"
  assert_eq "$(printf '%s\n' "$err" | grep -cxF "$OVL_NOREC")" "1" "overlap_record_unwritable_noted: 결과 파일에 겹침 줄이 빠진다는 알림이 한 번"
  assert_eq "$(printf '%s\n' "$err" | grep -c .)" "2" "overlap_record_unwritable_noted: 표준 오류는 그 두 줄뿐이다(쓰기 실패의 셸 오류를 흘리지 않는다)"
  # 쓸 수 있으면 그 알림이 없다(양성 짝)
  "$W" "$rd" -- true 2>"$T/writable.err"
  assert_eq "$(grep -cF "$OVL_NOREC" "$T/writable.err")" "0" "overlap_record_unwritable_noted 짝: 기록을 쓸 수 있으면 그 알림이 없다"
}

for c in case_free_lock_held_during_command case_busy_runs_without_wait case_unusable_runs case_rc_not_mixed \
         case_other_waits_for_qg case_no_lock_file_exec case_lock_path_with_space case_overlap_record_unwritable_noted; do
  echo "== $c"; $c
done
finish
