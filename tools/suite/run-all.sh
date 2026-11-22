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
TIMING_WARNED=0
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
trap 'rm -f -- "$LIST"' EXIT

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
  s="$(python3 "$PEERS" --pid "$SELF_PID" --stamp 2>/dev/null)"
  now="${s%% *}"; n="${s#* }"
  case "$s" in *" "*) ;; *) now=""; n="?" ;; esac
  secs="?"
  if [ -n "$now" ] && [ -n "$T_PREV" ]; then
    secs="$(awk -v a="$now" -v b="$T_PREV" 'BEGIN{printf "%.3f", a-b}' 2>/dev/null)"
    [ -n "$secs" ] || secs="?"
  fi
  if ! { printf '%s\t%s\t%s\t%s\n' "$secs" "$1" "$2" "$n" >> "$TIMING"; } 2>/dev/null; then
    if [ "$TIMING_WARNED" -eq 0 ]; then
      TIMING_WARNED=1
      echo "run-all: 시간 기록 파일에 쓸 수 없다 — 기록하지 않는다: $TIMING" >&2
    fi
  fi
  T_PREV="$now"
}

if [ -n "$TIMING" ]; then
  s="$(python3 "$PEERS" --pid "$SELF_PID" --stamp 2>/dev/null)"
  case "$s" in *" "*) now="${s%% *}"; n="${s#* }" ;; *) now="?"; n="?" ;; esac
  if ! { printf 'start\t%s\t%s\t%s\n' "$now" "$n" "$TOP" >> "$TIMING"; } 2>/dev/null; then
    TIMING_WARNED=1
    echo "run-all: 시간 기록 파일에 쓸 수 없다 — 기록하지 않는다: $TIMING" >&2
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
    emit "$d" "$rc" "$out" '/^(FAIL|ERROR): /p'
    timing_mark py "$d"
  done
  for d in tools/*/; do
    d="${d%/}"
    ls "$d"/test_*.py >/dev/null 2>&1 || continue
    out="$(SUITE_TIMING_FILE="$TIMING" python3 "$RUNNER" "$d" 2>&1)"; rc=$?
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
  s="$(python3 "$PEERS" --pid "$SELF_PID" --stamp 2>/dev/null)"
  case "$s" in *" "*) now="${s%% *}"; n="${s#* }" ;; *) now="?"; n="?" ;; esac
  if ! { printf 'end\t%s\t%s\n' "$now" "$n" >> "$TIMING"; } 2>/dev/null; then
    echo "run-all: 시간 기록 파일에 쓸 수 없다 — 기록하지 않는다: $TIMING" >&2
  fi
fi
cat "$LIST"
[ -s "$LIST" ] && exit 1 || exit 0
