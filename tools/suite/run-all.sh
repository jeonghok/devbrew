#!/usr/bin/env bash
# devbrew 전체 스위트 — 실패마다 `FAILED <파일>: <이름>` 한 줄, 하나라도 있으면 rc 1.
# 셸 테스트(실행 비트와 무관)의 「  ✗ 」 · 「  FAIL: 」 줄 · python unittest 의 FAIL: · ERROR: 줄 · node --test 의 not ok 줄.
# 실패 표시 줄 없이 rc≠0 인 파일 · 디렉토리는 `FAILED <대상>: rc <n>(실패 표시 줄 없음)`.
# 로드맵 frontmatter test_command 가 이것을 부른다(spec-distill merge_check). 스위트 둘을 같은 시각에 돌리지 않는다.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2
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

{
  while IFS= read -r f; do
    out="$(bash "$f" 2>&1 < /dev/null)"; rc=$?
    emit "$f" "$rc" "$out" 's/^ *(✗|FAIL:) //p'
  done < <(find shared/tests plugins/*/tests -name 'test_*.sh' -not -path '*/spike/*' -not -path '*/fixtures/*' | LC_ALL=C sort)
  for d in plugins/*/tests shared/tests; do
    [ -d "$d" ] || continue
    out="$(python3 "$RUNNER" "$d" 2>&1)"; rc=$?
    emit "$d" "$rc" "$out" '/^(FAIL|ERROR): /p'
  done
  for d in tools/*/; do
    d="${d%/}"
    ls "$d"/test_*.py >/dev/null 2>&1 || continue
    out="$(python3 "$RUNNER" "$d" 2>&1)"; rc=$?
    emit "$d" "$rc" "$out" '/^(FAIL|ERROR): /p'
  done
  for f in $(git ls-files 'plugins/*/tests/*.test.mjs'); do
    out="$(node --test --test-reporter=tap "$f" 2>&1)"; rc=$?
    emit "$f" "$rc" "$out" 's/^[[:space:]]*not ok( [0-9]+)?( - )?//p'
  done
} | LC_ALL=C sort > "$LIST"
cat "$LIST"
[ -s "$LIST" ] && exit 1 || exit 0
