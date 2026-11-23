#!/usr/bin/env bash
# devbrew 전체 스위트 — 실패마다 `FAILED <파일>: <이름>` 한 줄, 하나라도 있으면 rc 1.
# 셸 테스트(실행 비트와 무관)의 「  ✗ 」 · 「  FAIL: 」 줄 · python unittest 의 FAIL: · ERROR: 줄 · node --test 의 not ok 줄.
# 실패 표시 줄 없이 rc≠0 인 파일 · 디렉토리는 `FAILED <대상>: rc <n>(실패 표시 줄 없음)`.
# 로드맵 frontmatter test_command 가 이것을 부른다(spec-distill merge_check). 스위트 둘을 같은 시각에 돌리지 않는다.
# SUITE_TIMING_FILE=<절대 경로> 가 있으면 시작 · 대상마다 · 끝에 걸린 시간과 다른 스위트 수 줄을 덧붙인다(없으면 아무것도 쓰지 않는다).
# SUITE_ONLY_FAILED_FILE=<절대 경로> 가 있으면 그 목록(`<대상>: <이름>` 줄)의 대상만 돈다 — 목록을 읽지 못하면 알리고 전부 돈다. 두 변수는 테스트에게 물려주지 않는다.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2
TOP="$(pwd)"
SELF_PID=$$
PEERS="tools/suite/suite_peers.py"
TIMING="${SUITE_TIMING_FILE:-}"
unset SUITE_TIMING_FILE
ONLY="${SUITE_ONLY_FAILED_FILE:-}"
unset SUITE_ONLY_FAILED_FILE
ONLY_ON=""
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
trap 'rm -f -- "$LIST" "$LIST.warned" "$LIST.peers-warned" "$LIST.stamp-err" "$LIST.only"' EXIT

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

# only_kind <대상> — 러너가 내는 대상 꼴이면 그 종류(sh · py · node)를 내고, 아니면 아무것도 내지 않는다.
# 셸 shared/tests/…test_*.sh · plugins/<p>/tests/…test_*.sh, python shared/tests · plugins/<p>/tests · tools/<d>,
# node plugins/<p>/tests/…*.test.mjs. case 의 * 는 / 도 맞으므로 <p> · <d> 에 / 가 없는지 따로 본다.
only_kind() {
  local t="$1" p rest
  case "$t" in
    shared/tests) echo py; return 0 ;;
    shared/tests/*) rest="${t#shared/tests/}" ;;
    tools/*)
      p="${t#tools/}"
      case "$p" in ""|*/*) ;; *) echo py ;; esac
      return 0 ;;
    plugins/*/tests|plugins/*/tests/*)
      rest="${t#plugins/}"; p="${rest%%/*}"; rest="${rest#*/}"
      [ -n "$p" ] || return 0
      [ "$rest" = tests ] && { echo py; return 0; }
      [ "${rest#tests/}" != "$rest" ] || return 0
      rest="${rest#tests/}" ;;
    *) return 0 ;;
  esac
  case "${rest##*/}" in
    test_*.sh) echo sh ;;
    *.test.mjs) [ "${t#plugins/}" = "$t" ] || echo node ;;
  esac
  return 0
}

# only_present <종류> <대상> — 이 사본에서 반복문이 실제로 도는 대상인가.
only_present() {
  case "$2" in */./*|*/../*|*//*|plugins/.*|tools/.*) return 1 ;; esac
  case "$1" in
    sh) case "$2" in */spike/*|*/fixtures/*) return 1 ;; esac
        [ -e "$2" ] ;;
    py) case "$2" in
          tools/*) ls "$2"/test_*.py >/dev/null 2>&1 ;;
          *) [ -d "$2" ] ;;
        esac ;;
    node) git ls-files 'plugins/*/tests/*.test.mjs' | grep -qxF -- "$2" ;;
    *) return 1 ;;
  esac
}

# only_drop <까닭> <값> — 목록을 버리고 전부 돈다고 알린다.
only_drop() {
  printf 'run-all: 실패 목록을 읽지 못해 전부 돈다 — %s: %s\n' "$1" "$2" >&2
}

if [ -n "$ONLY" ]; then
  case "$ONLY" in
    /*)
      if ! o_raw="$(cat -- "$ONLY" 2>/dev/null)"; then
        only_drop "파일을 읽지 못했다" "$ONLY"
      else
        : > "$LIST.only"
        o_lines=0; o_sel=0; o_bad=""
        while IFS= read -r o_line; do
          [ -n "$o_line" ] || continue
          o_lines=$((o_lines+1))
          case "$o_line" in
            *": "*) o_t="${o_line%%: *}" ;;
            *) o_bad="$o_line"; break ;;
          esac
          o_kind="$(only_kind "$o_t")"
          [ -n "$o_kind" ] || { o_bad="$o_line"; break; }
          only_present "$o_kind" "$o_t" || continue
          grep -qxF -- "$o_t" "$LIST.only" && continue
          printf '%s\n' "$o_t" >> "$LIST.only"
          o_sel=$((o_sel+1))
        done <<< "$o_raw"
        if [ -n "$o_bad" ]; then
          only_drop "대상 경로 꼴이 아닌 줄이 있다" "$o_bad"
        elif [ "$o_lines" -eq 0 ]; then
          only_drop "읽을 줄이 없다" "$ONLY"
        else
          ONLY_ON=1
          echo "run-all: 일부만 돌았다 — 대상 ${o_sel}개(SUITE_ONLY_FAILED_FILE)" >&2
        fi
      fi ;;
    *) only_drop "절대 경로가 아니다" "$ONLY" ;;
  esac
fi

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
    [ -z "$ONLY_ON" ] || grep -qxF -- "$f" "$LIST.only" || continue
    out="$(bash "$f" 2>&1 < /dev/null)"; rc=$?
    emit "$f" "$rc" "$out" 's/^ *(✗|FAIL:) //p'
    timing_mark sh "$f"
  done < <(find shared/tests plugins/*/tests -name 'test_*.sh' -not -path '*/spike/*' -not -path '*/fixtures/*' | LC_ALL=C sort)
  for d in plugins/*/tests shared/tests; do
    [ -z "$ONLY_ON" ] || grep -qxF -- "$d" "$LIST.only" || continue
    [ -d "$d" ] || continue
    out="$(SUITE_TIMING_FILE="$TIMING" python3 "$RUNNER" "$d" 2>&1)"; rc=$?
    py_notes "$out"
    emit "$d" "$rc" "$out" '/^(FAIL|ERROR): /p'
    timing_mark py "$d"
  done
  for d in tools/*/; do
    d="${d%/}"
    [ -z "$ONLY_ON" ] || grep -qxF -- "$d" "$LIST.only" || continue
    ls "$d"/test_*.py >/dev/null 2>&1 || continue
    out="$(SUITE_TIMING_FILE="$TIMING" python3 "$RUNNER" "$d" 2>&1)"; rc=$?
    py_notes "$out"
    emit "$d" "$rc" "$out" '/^(FAIL|ERROR): /p'
    timing_mark py "$d"
  done
  for f in $(git ls-files 'plugins/*/tests/*.test.mjs'); do
    [ -z "$ONLY_ON" ] || grep -qxF -- "$f" "$LIST.only" || continue
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
