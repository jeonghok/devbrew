#!/usr/bin/env bash
# AC1 (v2.13.0) — Review gate floor 불변 mutation-teeth.
# floor(security-reviewer + adversarial)는 스코프 무관 항상 디스패치되어야 하고,
# 모델이 스코프 판단으로 뺄 수 없어야 한다. 정적 grep-lock + 실 SKILL의 복사본을
# 변이시켜 RED가 나는지(=이빨)로 증명. RED가 안 나는 락은 장식이다.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SKILL="$ROOT/plugins/quality-gates/skills/quality-pipeline/SKILL.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

TMP="$(mktemp -d)" || { echo "FAIL: mktemp"; exit 1; }
[ -n "$TMP" ] && [ -d "$TMP" ] || { echo "FAIL: TMP invalid"; exit 1; }
trap 'rm -rf "$TMP"' EXIT

# check_floor <skill-file> → exit 0 (GREEN, floor 불변식 성립) / 1 (RED)
check_floor() {
  local f="$1"
  # (i) floor "항상 디스패치" 선언(body-unique 리터럴).
  grep -qF '스코프 무관, 항상 디스패치' "$f" || return 1
  # (ii) 두 floor dispatch 블록 존재.
  grep -qF 'subagent_type: "quality-gates:security-reviewer"' "$f" || return 1
  grep -qF 'subagent_type: "quality-gates:adversarial"' "$f" || return 1
  return 0
}

expect() {  # expect <GREEN|RED> <file> <msg>
  local got
  if check_floor "$2"; then got=GREEN; else got=RED; fi
  assert_eq "$got" "$1" "$3 (want $1, got $got)"
}

echo "== 기준선: 실 SKILL은 floor 불변식 성립 =="
expect GREEN "$SKILL" "실 SKILL GREEN"

echo "== mutation: floor '항상 디스패치' 선언 삭제 → RED =="
grep -vF '스코프 무관, 항상 디스패치' "$SKILL" > "$TMP/m1.md"
expect RED "$TMP/m1.md" "floor always-선언 제거"

echo "== mutation: security-reviewer dispatch 제거 → RED =="
grep -vF 'subagent_type: "quality-gates:security-reviewer"' "$SKILL" > "$TMP/m2.md"
expect RED "$TMP/m2.md" "security-reviewer floor dispatch 제거"

echo "== mutation: adversarial dispatch 제거 → RED =="
grep -vF 'subagent_type: "quality-gates:adversarial"' "$SKILL" > "$TMP/m3.md"
expect RED "$TMP/m3.md" "adversarial floor dispatch 제거"

finish
