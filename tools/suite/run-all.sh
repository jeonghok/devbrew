#!/usr/bin/env bash
# devbrew 전체 스위트 — 실패마다 `FAILED <파일>: <이름>` 한 줄, 하나라도 있으면 rc 1.
# 셸 테스트(실행 비트와 무관)의 「  ✗ 」 줄 · python unittest 의 FAIL: · ERROR: 줄 · node --test 의 not ok 줄.
# 실패 표시 줄 없이 rc≠0 인 파일은 `FAILED <파일>: rc <n>(실패 표시 줄 없음)`.
# 로드맵 frontmatter test_command 가 이것을 부른다(spec-distill merge_check). 스위트 둘을 같은 시각에 돌리지 않는다.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2
LIST="$(mktemp "${TMPDIR:-/tmp}/run-all.XXXXXX")" || exit 2
trap 'rm -f -- "$LIST"' EXIT
{
  for f in plugins/*/tests/*.sh shared/tests/test_*.sh; do
    [ -f "$f" ] || continue
    out="$(bash "$f" 2>&1)"; rc=$?
    printf '%s\n' "$out" | sed -n 's/^  ✗ //p' | sed "s|^|FAILED $f: |"
    if [ "$rc" -ne 0 ] && ! printf '%s\n' "$out" | grep -q '^  ✗ '; then
      echo "FAILED $f: rc $rc(실패 표시 줄 없음)"
    fi
  done
  for d in plugins/*/tests shared/tests; do
    [ -d "$d" ] || continue
    python3 -m unittest discover -s "$d" -p 'test_*.py' 2>&1 | grep -E '^(FAIL|ERROR): ' | sed "s|^|FAILED $d: |"
  done
  for f in $(git ls-files 'plugins/*/tests/*.test.mjs'); do
    node --test --test-reporter=tap "$f" 2>&1 | grep -E '^[[:space:]]*not ok ' | sed "s|^[[:space:]]*|FAILED $f: |"
  done
} | LC_ALL=C sort > "$LIST"
cat "$LIST"
[ -s "$LIST" ] && exit 1 || exit 0
