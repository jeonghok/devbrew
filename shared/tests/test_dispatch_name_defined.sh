#!/usr/bin/env bash
# guards: plugins/*/skills/**/*.md plugins/*/commands/**/*.md plugins/*/agents/*.md
#
# 백틱으로 불린 `<plugin>:<name>` 이 실재 정의를 갖는지 검사한다.
#
# 기존 dispatch 락과 «방향이 반대»다: 그쪽은 정의에서 출발해 호출을 찾고,
# 이쪽은 호출에서 출발해 정의를 찾는다. 지워진 정의를 가리키는 이름은 그쪽
# 방향에서 구조적으로 안 보인다.
#
# 백틱과 콜론을 «동시에» 요구한다. 산문 속 맨 영어 단어는 둘 다 없으므로
# 기존 락의 표기 필터와 겹치지 않는다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

TMPD="$(mktemp -d -t dispname-XXXXXX)" || exit 1
trap 'rm -rf "$TMPD"' EXIT

PYTHONDONTWRITEBYTECODE=1 python3 "$HERE/fixtures/adjudication/run_names.py" \
  "$REPO_ROOT" > "$TMPD/out.txt" 2>&1
OUT="$(cat "$TMPD/out.txt")"
note "$OUT"

note "── 판정기 자체 (fixture)"
assert_contains "$OUT" "fx_stale=1"  "지워진 이름을 잡는다"
assert_contains "$OUT" "fx_ok=0"     "실재하는 이름을 통과시킨다"
assert_contains "$OUT" "fx_prose=0"  "산문 속 맨 단어와 백틱 없는 콜론은 잡지 않는다 (기존 락의 실측 제약)"

note "── 정의 집합"
ndef="$(printf '%s\n' "$OUT" | sed -n 's/^defined=//p')"
if [ "${ndef:-0}" -gt 0 ] 2>/dev/null; then
  ok "정의 $ndef 개 (agent + skill + command)"
else
  no "정의 도출이 0 이다 — 락이 vacuous 하다"
fi

note "── 참조 코퍼스"
nref="$(printf '%s\n' "$OUT" | sed -n 's/^refs=//p')"
if [ "${nref:-0}" -gt 0 ] 2>/dev/null; then
  ok "참조 $nref 건"
else
  no "참조 도출이 0 이다 — 코퍼스 glob 이 깨졌으면 이 락의 단언이 전부 공허하다"
fi

note "── 존재하지 않는 정의를 가리키는 참조"
nd="$(printf '%s\n' "$OUT" | sed -n 's/^dangling=//p')"
assert_eq "$nd" "0" "모든 참조가 실재 정의를 가리킨다"
printf '%s\n' "$OUT" | sed -n 's/^  DANGLING //p' | while IFS= read -r l; do
  note "      매달림: $l"
done

finish
