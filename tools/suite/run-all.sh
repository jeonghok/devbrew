#!/usr/bin/env bash
# devbrew 전체 스위트 — 실패마다 `FAILED <파일>: <이름>` 한 줄, 하나라도 있으면 rc 1.
# 셸 테스트(실행 비트와 무관)의 「  ✗ 」 · 「  FAIL: 」 줄 · python unittest 의 FAIL: · ERROR: 줄 · node --test 의 not ok 줄.
# 실패 표시 줄 없이 rc≠0 인 파일 · 디렉토리는 `FAILED <대상>: rc <n>(실패 표시 줄 없음)`.
# 로드맵 frontmatter test_command 가 이것을 부른다(spec-distill merge_check). 스위트 둘을 같은 시각에 돌리지 않는다.
# SUITE_TIMING_FILE=<절대 경로> 가 있으면 시작 · 대상마다 · 끝에 걸린 시간과 다른 스위트 수 줄을 덧붙인다(없으면 아무것도 쓰지 않는다).
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2
TOP="$(pwd)"
SELF_PID=$$
PEERS="tools/suite/suite_peers.py"
TIMING="${SUITE_TIMING_FILE:-}"
unset SUITE_TIMING_FILE
T_PREV=""
if [ -n "$TIMING" ]; then
  case "$TIMING" in
    /*) { : >> "$TIMING"; } 2>/dev/null || {
          echo "run-all: 시간 기록 파일에 쓸 수 없다 — 기록하지 않는다: $TIMING" >&2
          TIMING=""
        } ;;
    *) echo "run-all: SUITE_TIMING_FILE 은 절대 경로여야 한다 — 기록하지 않는다: $TIMING" >&2
       TIMING="" ;;
  esac
fi
RUNNER="tools/suite/run_unittest_dir.py"
LIST="$(mktemp "${TMPDIR:-/tmp}/run-all.XXXXXX")" || exit 2
trap 'rm -f -- "$LIST" "$LIST.warned" "$LIST.peers-warned" "$LIST.stamp-err"' EXIT

# write_note — 기록 파일 쓰기 실패 알림. 바퀴마다 한 번(하위 셸을 넘도록 파일로 기억한다).
write_note() {
  [ -e "$LIST.warned" ] && return 0
  : > "$LIST.warned"
  echo "run-all: 시간 기록 파일에 쓸 수 없다 — 기록하지 않는다: $TIMING" >&2
}

# peers_note <stamp 종료 코드> — 다른 스위트 수를 못 센 까닭을 바퀴마다 한 번 알린다.
peers_note() {
  [ -e "$LIST.peers-warned" ] && return 0
  : > "$LIST.peers-warned"
  local why
  why="$(head -n 1 "$LIST.stamp-err" 2>/dev/null)"
  if [ -z "$why" ]; then
    if [ "$1" -ne 0 ]; then why="종료 코드 $1"; else why="출력이 없다"; fi
  fi
  echo "run-all: 다른 스위트 수를 세지 못했다 — $why" >&2
}

# stamp_read — 결과를 s 에 둔다. 세지 못했으면(`?` · 빈 출력 · 실패) 까닭을 알린다.
stamp_read() {
  local prc
  s="$(python3 "$PEERS" --pid "$SELF_PID" --stamp 2>"$LIST.stamp-err")"; prc=$?
  case "$s" in
    *" "*) [ "${s#* }" = "?" ] && peers_note "$prc" ;;
    *) peers_note "$prc" ;;
  esac
  return 0
}

# py_notes <출력> — 기록 변수가 있을 때 python 러너 알림 줄을 표준 오류로 옮긴다.
py_notes() {
  [ -n "$TIMING" ] || return 0
  printf '%s\n' "$1" | grep '^run_unittest_dir: ' >&2
  return 0
}

# emit <대상> <rc> <출력> <이름을 뽑는 sed -E 식>  — 이름 줄을 FAILED 로 내고, 없는데 rc≠0 이면 rc 줄을 낸다.
emit() {
  local target="$1" rc="$2" out="$3" expr="$4" names
  names="$(printf '%s\n' "$out" | sed -nE "$expr")"
  if [ -n "$names" ]; then
    printf '%s\n' "$names" | sed "s|^|FAILED $target: |"
  elif [ "$rc" -ne 0 ]; then
    echo "FAILED $target: rc $rc(실패 표시 줄 없음)"
  fi
}

# timing_mark <sh|py|node> <대상> — 앞 stamp 와의 차를 걸린 초로 대상 줄을 덧붙인다. 기록이 꺼져 있으면 바로 돌아간다.
timing_mark() {
  [ -n "$TIMING" ] || return 0
  local s now n secs
  stamp_read
  now="${s%% *}"; n="${s#* }"
  case "$s" in *" "*) ;; *) now=""; n="?" ;; esac
  secs="?"
  if [ -n "$now" ] && [ -n "$T_PREV" ]; then
    secs="$(awk -v a="$now" -v b="$T_PREV" 'BEGIN{printf "%.3f", a-b}' 2>/dev/null)"
    [ -n "$secs" ] || secs="?"
  fi
  if ! { printf '%s\t%s\t%s\t%s\n' "$secs" "$1" "$2" "$n" >> "$TIMING"; } 2>/dev/null; then
    write_note
  fi
  T_PREV="$now"
}

if [ -n "$TIMING" ]; then
  stamp_read
  case "$s" in *" "*) now="${s%% *}"; n="${s#* }" ;; *) now="?"; n="?" ;; esac
  if ! { printf 'start\t%s\t%s\t%s\n' "$now" "$n" "$TOP" >> "$TIMING"; } 2>/dev/null; then
    write_note
  fi
  T_PREV="$now"
  [ "$T_PREV" = "?" ] && T_PREV=""
fi

{
  while IFS= read -r f; do
    out="$(bash "$f" 2>&1 < /dev/null)"; rc=$?
    emit "$f" "$rc" "$out" 's/^ *(✗|FAIL:) //p'
    timing_mark sh "$f"
  done < <(find shared/tests plugins/*/tests -name 'test_*.sh' -not -path '*/spike/*' -not -path '*/fixtures/*' | LC_ALL=C sort)
  for d in plugins/*/tests shared/tests; do
    [ -d "$d" ] || continue
    out="$(SUITE_TIMING_FILE="$TIMING" python3 "$RUNNER" "$d" 2>&1)"; rc=$?
    py_notes "$out"
    emit "$d" "$rc" "$out" '/^(FAIL|ERROR): /p'
    timing_mark py "$d"
  done
  for d in tools/*/; do
    d="${d%/}"
    ls "$d"/test_*.py >/dev/null 2>&1 || continue
    out="$(SUITE_TIMING_FILE="$TIMING" python3 "$RUNNER" "$d" 2>&1)"; rc=$?
    py_notes "$out"
    emit "$d" "$rc" "$out" '/^(FAIL|ERROR): /p'
    timing_mark py "$d"
  done
  for f in $(git ls-files 'plugins/*/tests/*.test.mjs'); do
    out="$(node --test --test-reporter=tap "$f" 2>&1)"; rc=$?
    emit "$f" "$rc" "$out" 's/^[[:space:]]*not ok( [0-9]+)?( - )?//p'
    timing_mark node "$f"
  done
} | LC_ALL=C sort > "$LIST"
if [ -n "$TIMING" ]; then
  stamp_read
  case "$s" in *" "*) now="${s%% *}"; n="${s#* }" ;; *) now="?"; n="?" ;; esac
  if ! { printf 'end\t%s\t%s\n' "$now" "$n" >> "$TIMING"; } 2>/dev/null; then
    write_note
  fi
fi
cat "$LIST"
[ -s "$LIST" ] && exit 1 || exit 0
